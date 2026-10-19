local Players = game:GetService "Players"
local RunService = game:GetService "RunService"

local arguments = require "./arguments"
local context = require "./context"
local language = require "../roblox_packages/language"
local net = require "./net"
local signal = require "./signal"
local state = require "./state"
local types = require "./types"
local user = require "./user"

local IS_SERVER = RunService:IsServer()

local vm = language.create_vm()
local commands: { [string]: types.CommandRepresentation } = {}
local after_run = signal()
local before_run_hooks: { (types.BeforeRunContext) -> string? } = {}

-- raised when a before_run hook blocks a command, so the server can tell it
-- apart from an error in the callback
local denied_mt = {
	__tostring = function(self) return self.why end,
}

local function deny(why: string): never
	error(setmetatable({ why = why }, denied_mt), 0)
end

local console: types.Console = {
	vm = vm,
	commands = commands,
	output = print,
}

local function is_valid_name(name: string): boolean
	return string.match(name, "^[%w_@:%-]+$") ~= nil
end

local function write_global(global: string, value: any)
	assert(not IS_SERVER, "cannot set global on server")
	assert(is_valid_name(global), `'{global}' is not a valid name`)
	language.set_command(vm, global, value)
end

-- maps every command name and alias to the name of the command that owns it
local name_owners: { [string]: string } = {}

--[=[
Releases the name and aliases claimed by a command.
]=]
local function release_names(name: string)
	for claimed, owner in name_owners do
		if owner == name then name_owners[claimed] = nil end
	end
end

--[=[
Validates the name and aliases of a command before anything is registered,
and claims them for the command. Returns a deduplicated copy of the aliases.
]=]
local function claim_names(name: string, aliases: { string }?): { string }
	assert(is_valid_name(name), `{name} is not a valid name`)

	local owner = name_owners[name]
	assert(
		owner == nil or owner == name,
		`'{name}' is already used as an alias of '{owner}'`
	)

	local seen = { [name] = true }
	local result = {}

	for _, alias in aliases or {} do
		assert(
			is_valid_name(alias),
			`alias '{alias}' of '{name}' is not a valid name`
		)
		if seen[alias] then continue end

		local alias_owner = name_owners[alias]
		assert(
			alias_owner == nil or alias_owner == name,
			`alias '{alias}' of '{name}' is already used by '{alias_owner}'`
		)

		seen[alias] = true
		table.insert(result, alias)
	end

	-- release names from a previous registration of this command
	release_names(name)

	name_owners[name] = name
	for _, alias in result do
		name_owners[alias] = name
	end

	return result
end

local function replicate_to_player(
	player: Player,
	representation: types.CommandRepresentation
)
	local key = user.obtain_user_key(player)
	local player_user = state.users[key]

	if not player_user then return end
	if
		not user.has_permissions(
			player_user,
			unpack(representation.permissions)
		)
	then
		return
	end

	net.server.fire_register_command(player, {
		name = representation.name,
		description = representation.description,
		permissions = representation.permissions,
		aliases = representation.aliases,
		group = representation.group,
		type = representation.type,
	})
end

local suspended_thread: thread?
local running_thread: thread?

local function noop() end

local function execute(text: string)
	assert(suspended_thread == nil, "thread is already running!")
	suspended_thread = coroutine.running()

	console.output { kind = "info", text = `> {text}` }

	local finished = false
	local ctx = context.get_command_context()
	task.spawn(function()
		local pop = if ctx
			then context.create_command_context(ctx.executor, ctx.invocation_id)
			else noop
		running_thread = coroutine.running()
		local result = language.run(vm, text)

		if result.ok then
			for _, value in ipairs(result.values or {} :: never) do
				console.output { kind = "normal", text = tostring(value) }
			end
		else
			warn(table.concat(result.why, "\n"))
			console.output {
				kind = "error",
				text = table.concat(result.why, "\n"),
			}
		end

		pop()
		if suspended_thread then coroutine.resume(suspended_thread) end
		finished = true
	end)

	if not finished then coroutine.yield() end

	running_thread = nil
	suspended_thread = nil
end

local function cancel()
	if suspended_thread and running_thread then
		state.command_context[running_thread] = nil
		task.cancel(running_thread)
		coroutine.resume(suspended_thread)

		running_thread = nil
		suspended_thread = nil
	end
end

local map_remove_info: {
	[types.CommandRepresentation]: { language.TypeAnalysisInfo },
} = {}

--[=[
Determines which command is the valid overload to use in the case the command
is overloaded
]=]
local function determine_cmd_type(type: language.Type, ...: unknown)
	assert(
		type.kind == "intersection" or type.kind == "command",
		"not a command"
	)

	if type.kind == "intersection" then
		local options: { language.CommandType } = {}
		for i, field in type.fields do
			assert(
				field.kind == "command",
				`cannot determine overload with type {field.kind}`
			)
			local bad = false

			for j, argument in field.arguments do
				if
					argument.type
					and not language.matches_type(
						select(j, ...),
						argument.type,
						true
					)
				then
					bad = true
					break
				end
			end

			if bad then continue end
			table.insert(options, field)
		end

		if #options > 1 then
			error(
				`could not determine valid overload for {options[1].name}, consider separating the command or introducing a literal to differentiate by?`
			)
		end
		if #options == 0 then
			error(
				`could not determine valid overload for {type.fields[1].name}, no options matched`
			)
		end

		return options[1]
	elseif type.kind == "command" then
		return type
	end

	error "no valid command; unreachable?"
end

local function display_value(value: unknown): string
	return if typeof(value) == "string"
		then string.format("%q", value)
		else tostring(value)
end

--[=[
Explores the given type until it finds an appropriate conversion function for
the given value.
]=]
local function coerce_value_into_type(
	type: language.Type,
	value: unknown
): unknown
	if type.kind == "command" then
		return value
	elseif type.kind == "function" then
		return value
	elseif type.kind == "intersection" then
		-- every part has to accept the value
		for _, field in type.fields do
			coerce_value_into_type(field, value)
		end
		return value
	elseif type.kind == "literal" then
		if value ~= type.value then
			error(
				`expected {display_value(type.value)}, got {display_value(value)}`,
				0
			)
		end
		return value
	elseif type.kind == "strange" then
		if type.convert then
			return type.convert(value)
		else
			return value
		end
	elseif type.kind == "table" then
		assert(
			typeof(value) == "table",
			`not a table, should match table type but got {typeof(value)}`
		)
		local clone = {}
		local declared = {}

		if type.fields then
			for fieldkey, fieldvalue in type.fields do
				if fieldkey.value == nil then continue end

				local clone_value = rawget(value :: any, fieldkey.value)
				declared[fieldkey.value] = true
				clone[fieldkey.value] =
					coerce_value_into_type(fieldvalue, clone_value)
			end
		end

		for key, field_value in pairs(value :: any) do
			if declared[key] then continue end

			local clone_key = if type.indexer
				then coerce_value_into_type(type.indexer, key)
				else key
			clone[clone_key] = if type.value
				then coerce_value_into_type(type.value, field_value)
				else field_value
		end

		return clone
	elseif type.kind == "union" then
		for _, field in type.fields do
			if not language.matches_type(value, field, true) then continue end
			return coerce_value_into_type(field, value)
		end

		-- matching only looks at the luau type, so "5" still converts to a number
		local reason
		local names: { string } = {}
		for _, field in type.fields do
			local ok, result = pcall(coerce_value_into_type, field, value)
			if ok then return result end

			-- the error of a member the value looks like explains it best
			if reason == nil and language.matches_type(value, field) then
				reason = result
			end
			table.insert(names, arguments.obtain_type_name(field))
		end

		if reason then error(reason, 0) end

		local expected = table.concat(names, " | ")
		error(`could not convert {display_value(value)} into {expected}`, 0)
	end
	return value
end

local function unregister_command(info: types.CommandRepresentation)
	if not map_remove_info[info] then return end

  commands[info.name] = nil
	for _, analysis_info in map_remove_info[info] do
		analysis_info:remove()
	end
	map_remove_info[info] = nil
	write_global(info.name, nil)

	for _, alias in info.aliases do
		write_global(alias, nil)
	end
end

local function set_command_from_representation(
	info: types.CommandRepresentation
)
	if map_remove_info[info] then return end

	local previous = commands[info.name]
	if previous then unregister_command(previous) end
	local infos = {}

	write_global(info.name, info.callback)
	table.insert(infos, language.attach_info(vm, false, info.name, info.type))

	for _, alias in info.aliases do
		write_global(alias, info.callback)
		table.insert(infos, language.attach_info(vm, false, alias, info.type))
	end

	commands[info.name] = info
	map_remove_info[info] = infos
end

local function fix_arguments(args: { language.CommandArgument })
	for idx, argument in args do
		if argument.kind ~= "argument" and argument.kind ~= "overload" then
			local arg_name = arguments.obtain_type_name(argument)
			args[idx] = {
				kind = "argument",
				name = arg_name,
				description = arg_name,
				type = argument,
				varargs = false,
			}
		end
	end
end

local function from_arguments_or_overload(
	name: string,
	description: string?,
	args: {
		language.CommandArgument
		| arguments.Overload
		| language.IntersectionType
	}
): language.Type
	local first = args[1]
	if first and first.kind == "overload" then
		local overloads: { language.CommandType } = {}

		for _, overload in first.overloads do
			fix_arguments(overload)
			table.insert(overloads, {
				kind = "command" :: "command",
				name = name,
				description = description or "",
				arguments = overload,
			})
		end

		return {
			kind = "intersection",
			fields = overloads,
		}
	elseif
		#args == 1
		and first
		and first.kind == "intersection"
		-- args.intersect also builds an intersection, but of argument types
		and first.fields[1]
		and first.fields[1].kind == "command"
	then
		for i, command in first.fields do
			assert(
				command.kind == "command",
				`expected command, got {command.kind}`
			)
			fix_arguments(command.arguments)
		end

		return first
	else
		fix_arguments(args)
		return {
			kind = "command",

			name = name,
			description = description or "",

			arguments = args :: { language.CommandArgument },
		}
	end
end

local function register_command<T...>(
	name: string,
	info: {
		permissions: { types.Permission },
		description: string?,
		aliases: { string }?,
		group: string?,
		guards: { (types.BeforeRunContext) -> string? }?,
		cooldown: number?,
		arguments: () -> T...,
		callback: (T...) -> ...any,
	}
)
	local args =
		{ info.arguments() } :: { language.CommandArgument | arguments.Overload }

	local callback = info.callback
	local guards = info.guards or {}
	local type_information: language.Type =
		from_arguments_or_overload(name, info.description, args)
	local aliases = claim_names(name, info.aliases)

	local representation: types.CommandRepresentation = {
		name = name,
		description = info.description,
		permissions = info.permissions,
		aliases = aliases,
		group = info.group,
		cooldown = info.cooldown,

		type = type_information,

		dirty_replicate = true,
		callback = function(...)
			-- determine which overload is the correct one
			local overload = determine_cmd_type(type_information, ...)
			if not overload then error "could not match with an overload" end

			local custom = { ... }
			local vararg_converter

			for i = 1, select("#", ...) do
				local value = custom[i]
				local type = overload.arguments[i]

				if
					type == nil
					and vararg_converter
					and i > #overload.arguments
				then
					type = vararg_converter
				end

				if not type or not type.type then continue end

				if type.varargs and i == #overload.arguments then
					vararg_converter = type
				end

				custom[i] = coerce_value_into_type(type.type, value)
			end

			local context = state.command_context[coroutine.running()]
			local run_context: types.BeforeRunContext = {
				who = context and context.executor,
				command = name,
				arguments = custom,
			}

			for _, hook in before_run_hooks do
				local why = hook(run_context)
				if why then deny(why) end
			end

			for _, guard in guards do
				local why = guard(run_context)
				if why then deny(why) end
			end

			local results =
				{ pcall(callback, unpack(custom, 1, select("#", ...))) }
			local ok = table.remove(results, 1)

			after_run:fire {
				ok = ok,
				who = context and context.executor,
				command = name,
				arguments = custom,
				result = results,
			}

			if not ok then
				warn(unpack(results))
				error(results[1], 0)
			end

			return unpack(results)
		end,
	}

	if IS_SERVER then
		for _, player in Players:GetPlayers() do
			-- print("replicating to player", player)
			replicate_to_player(player, representation)
		end
		commands[name] = representation
	end

	if not IS_SERVER then
		-- tear down a previous registration so its globals and aliases don't linger
		local previous = state.local_commands[name]
		if previous then unregister_command(previous.representation) end

		if
			state.local_user
			and user.has_permissions(state.local_user, unpack(info.permissions))
		then
			set_command_from_representation(representation, args)
		end

		state.local_commands[name] = {
			representation = representation,
			arguments = args,
		}
	end

	return representation
end

local function register(name: string, fn: (...any) -> ...any, ...: string)
	register_command(name, {
		name = name,
		callback = fn,
		arguments = function() end :: any,
		permissions = { ... },
	})
end

--[=[
Removes a command and its aliases. On the server, the command is removed from
every client as well.
]=]
local function unregister(name: string)
	if IS_SERVER then
		if not commands[name] then return end
		commands[name] = nil

		-- every client, since one that lost the permission still keeps the
		-- command and would add it back once it gets the permission again
		if net.server.initialized then
			net.server.fire_unregister_command { name = name }
		end
	else
		local command = state.local_commands[name]
		if not command then return end

		unregister_command(command.representation)
		state.local_commands[name] = nil
	end

	release_names(name)
end

--[=[
Adds a hook that runs before every command registered by this host, after the
arguments are converted. Returning a string blocks the command and shows the
string to the executor. Returns a function that removes the hook.
]=]
local function before_run(hook: (types.BeforeRunContext) -> string?)
	table.insert(before_run_hooks, hook)

	return function()
		local index = table.find(before_run_hooks, hook)
		if index then table.remove(before_run_hooks, index) end
	end
end

--[=[
Returns the reason when the error was raised by a before_run hook.
]=]
local function get_denied_reason(err: unknown): string?
	if typeof(err) == "table" and getmetatable(err :: any) == denied_mt then
		return (err :: any).why
	end
	return nil
end

local function analyze(src: string, where: number): language.AnalysisResult?
	return language.analyze(vm, src, where)
end

return {
	console = console,
	register_quick = register,
	register_command = register_command,
	unregister = unregister,
	replicate_to_player = replicate_to_player,
	execute = execute,
	cancel = cancel,
	analyze = analyze,
	write_global = write_global,
	after_command_run = after_run,
	before_run = before_run,
	get_denied_reason = get_denied_reason,

	set_command_from_representation = set_command_from_representation,
	unset_command_from_representation = unregister_command,
}
