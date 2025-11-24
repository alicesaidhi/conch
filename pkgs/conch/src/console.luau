local Players = game:GetService "Players"
local RunService = game:GetService "RunService"

local arguments = require "./arguments"
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

local console: types.Console = {
	vm = vm,
	commands = commands,
	output = print,
}

local function write_global(global: string, value: any)
	assert(not IS_SERVER, "cannot set global on server")
	assert(string.match(global, "^[A-z%-@_]*$"), `{global} is not a valid name`)
	language.set_command(vm, global, value)
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
		type = representation.type,
	})
end

local suspended_thread: thread?
local running_thread: thread?

local function execute(text: string)
	assert(suspended_thread == nil, "thread is already running!")
	suspended_thread = coroutine.running()

	console.output { kind = "info", text = `> {text}` }

	local finished = false
	task.spawn(function()
		running_thread = coroutine.running()
		local result = language.run(vm, text)

		if result.ok then
			for _, value in result.values or {} :: never do
				console.output { kind = "normal", text = tostring(value) }
			end
		else
			warn(table.concat(result.why, "\n"))
			console.output {
				kind = "error",
				text = table.concat(result.why, "\n"),
			}
		end

		if suspended_thread then coroutine.resume(suspended_thread) end
		finished = true
	end)

	if not finished then coroutine.yield() end

	running_thread = nil
	suspended_thread = nil
end

local function cancel()
	if suspended_thread and running_thread then
		task.cancel(running_thread)
		coroutine.resume(suspended_thread)

		running_thread = nil
		suspended_thread = nil
	end
end

local map_remove_info: { [types.CommandRepresentation]: language.TypeAnalysisInfo } =
	{}

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
		return value
	elseif type.kind == "literal" then
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

		if type.fields then
			for fieldkey, fieldvalue in type.fields do
				if fieldkey.value == nil then continue end

				local clone_value = rawget(value :: any, fieldkey.value)
				clone[fieldkey.value] =
					coerce_value_into_type(fieldvalue, clone_value)
			end
		end

		if type.indexer and type.value then
			for key, value in pairs(clone) do
				if language.matches_type(key, type.indexer, true) then
					clone[coerce_value_into_type(type.indexer, key)] =
						coerce_value_into_type(type.value, value)
				end
			end
		end
	elseif type.kind == "union" then
		for _, field in type.fields do
			if not language.matches_type(value, field, true) then continue end
			return coerce_value_into_type(field, value)
		end
	end
	return value
end

local function set_command_from_representation(
	info: types.CommandRepresentation
)
	if map_remove_info[info] then return end

	write_global(info.name, info.callback)

	commands[info.name] = info
	map_remove_info[info] =
		language.attach_info(vm, false, info.name, info.type)
end

local function unregister_command(info: types.CommandRepresentation)
	if not map_remove_info[info] then return end

	commands[info.name] = nil
	map_remove_info[info]:remove()
	map_remove_info[info] = nil
	write_global(info.name, nil)
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
		arguments: () -> T...,
		callback: (T...) -> ...any,
	}
)
	local args =
		{ info.arguments() } :: { language.CommandArgument | arguments.Overload }

	local callback = info.callback
	local type_information: language.Type =
		from_arguments_or_overload(name, info.description, args)

	local representation: types.CommandRepresentation = {
		name = name,
		description = info.description,
		permissions = info.permissions,

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

			local results =
				{ pcall(callback, unpack(custom, 1, select("#", ...))) }
			local ok = table.remove(results, 1)

			local context = state.command_context[coroutine.running()]

			after_run:fire {
				ok = ok,
				who = context and context.executor,
				command = name,
				arguments = custom,
				result = results,
			}

			if not ok then
				warn(unpack(results))
				error(results[2], 0)
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

local function analyze(src: string, where: number): language.AnalysisResult?
	return language.analyze(vm, src, where)
end

return {
	console = console,
	register_quick = register,
	register_command = register_command,
	replicate_to_player = replicate_to_player,
	execute = execute,
	cancel = cancel,
	analyze = analyze,
	write_global = write_global,
	after_command_run = after_run,

	set_command_from_representation = set_command_from_representation,
	unset_command_from_representation = unregister_command,
}
