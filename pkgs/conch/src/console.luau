local Players = game:GetService "Players"
local RunService = game:GetService "RunService"

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

local types = {}

local function register_type<T>(
	type: string,
	data: types.ArgumentType<T>
): (name: string?, description: string?) -> T
	types[type] = data

	if data.analysis then
		assert(data.analysis.kind == "argument")
		data.analysis.unique_identifier = type
	end

	return function(name: string?, description: string?): T
		if data.analysis then
			assert(data.analysis.kind == "argument")

			return {
				kind = "argument",
				name = name or data.analysis.name,
				description = description or "",
				type = data.analysis.type,
				unique_identifier = type,

				suggestions = data.analysis.suggestions,

				optional = false,
				vararg = false,
			} :: any
		else
			return {
				kind = "argument",
				name = name or type,
				description = description or "",
				type = type,
				unique_identifier = type,

				suggestions = function() return {} end,

				optional = false,
				vararg = false,
			} :: any
		end
	end
end

local function write_global(global: string, value: any)
	assert(not IS_SERVER, "cannot set global on server")
	assert(string.match(global, "^[A-z%-@_]*$"), `{global} is not a valid name`)
	language.set_command(vm, global, value)
end

local function get_type(type: string) return types[type] end

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
		overloads = representation.information.overloads,
	})
end

local busy = false

local function execute(text: string)
	assert(not busy, "already executing!")

	console.output { kind = "info", text = `> {text}` }
	busy = true

	local result = language.run(vm, text)

	if result.ok then
		for _, value in result.values or {} :: never do
			console.output { kind = "normal", text = tostring(value) }
		end
	else
		console.output { kind = "error", text = table.concat(result.why, "\n") }
	end

	busy = false
end

local function determine_overload(overloads: { language.Overload }, ...: any)
	if #overloads == 1 then return overloads[1] end

	local acceptable_overloads: { language.Overload } =
		table.clone(overloads) :: any

	for idx = 1, select("#", ...) do
		local value = select(idx, ...)

		-- evaluate argument
		for i = #acceptable_overloads, 1, -1 do
			local overload = acceptable_overloads[i]
			local arg_b = overload.arguments[idx]
			if not arg_b then table.remove(acceptable_overloads, i) end
			-- determine if overload matches
			if arg_b.kind ~= "literal" then continue end
			if arg_b.optional and value == nil then continue end
			if arg_b.value ~= value then
				table.remove(acceptable_overloads, i)
			end
		end

		if #acceptable_overloads > 0 then
			acceptable_overloads = table.clone(acceptable_overloads)
		end
	end

	if #acceptable_overloads == 0 then
		error "no overload matches the given command"
	end

	return acceptable_overloads[1]
end

local function compute_overloads(
	description: string,
	arguments: {
		language.AnalysisArgument
		| types.Overload
	}
)
	local map_overload_convert: { [language.Overload]: { (any) -> any } } = {}
	local overloads: { language.Overload } = {}

	if arguments[1] and arguments[1].kind == "overload" then
		local overloads_arg = arguments[1]
		assert(overloads_arg.kind == "overload")

		for _, overload in overloads_arg.overloads do
			local overload_converts = {}
			local overload_args = {}

			for index, argument in overload.arguments do
				if argument.kind == "argument" then
					local data = get_type(argument.unique_identifier)
						or warn(
							`no argument of type "{argument.unique_identifier}" is registered`
						)
						or get_type "any"
					overload_converts[index] = data.convert

					if
						data.analysis
						and data.analysis.kind == "argument"
						and data.analysis.type ~= "any"
					then
						local copy = table.clone(data.analysis)
						assert(copy.kind == "argument")
						copy.vararg = argument.vararg
						copy.optional = argument.optional
						overload_args[index] = argument
					else
						overload_args[index] = argument
					end
				end
			end

			table.insert(overloads, overload)
			map_overload_convert[overload] = overload_converts
		end
	else
		local overload_converts = {}
		local analysis_arguments: { language.AnalysisArgument } = {}
		for index, argument in arguments do
			assert(
				argument.kind ~= "overload",
				"overloads must be the first argument"
			)

			if argument.kind == "argument" then
				local data = get_type(argument.unique_identifier)
					or warn(
						`no argument of type "{argument.type}" is registered`
					)
					or get_type "any"
				overload_converts[index] = data.convert

				if
					data.analysis
					and data.analysis.kind == "argument"
					and data.analysis.type ~= "any"
				then
					local copy = table.clone(data.analysis)
					assert(copy.kind == "argument")
					copy.vararg = argument.vararg
					copy.optional = argument.optional
					analysis_arguments[index] = argument
				else
					analysis_arguments[index] = argument
				end
			end
		end

		local overload = {
			description = description,
			arguments = analysis_arguments,
		}

		table.insert(overloads, overload)
		map_overload_convert[overload] = overload_converts
	end

	return map_overload_convert, overloads
end

local map_remove_info: { [types.CommandRepresentation]: () -> () } = {}
local function set_command_from_representation(
	info: types.CommandRepresentation,
	arguments: {
		language.AnalysisArgument
		| types.Overload
	}
)
	if map_remove_info[info] then return end

	local map_overload_convert, overloads =
		compute_overloads(info.description or "", arguments)

	write_global(info.name, function(...)
		-- determine which overload is the correct one
		local overload = determine_overload(overloads, ...)
		if not overload then error "could not match with an overload" end

		local custom = { ... }

		local variadic, last_index
		local converts = map_overload_convert[overload]
		for idx, argument in overload.arguments do
			if argument.kind == "argument" and argument.vararg then
				variadic = converts[idx]
				last_index = idx
				break
			elseif argument.optional and select(idx, ...) == nil then
				custom[idx] = nil
			elseif converts[idx] then
				custom[idx] = converts[idx]((select(idx, ...)))
			else
				custom[idx] = select(idx, ...)
			end
		end

		if variadic and last_index then
			for idx = last_index + 1, select("#", ...) do
				custom[idx] = variadic((select(idx, ...)))
			end
		end

		local results =
			{ pcall(info.callback, unpack(custom, 1, select("#", ...))) }
		local ok = table.remove(results, 1)

		local context = state.command_context[coroutine.running()]

		after_run:fire {
			ok = ok,
			who = context and context.executor,
			command = info.name,
			arguments = custom,
			result = results,
		}

		if not ok then error(results[2], 0) end

		return unpack(results)
	end)

	commands[info.name] = info
	map_remove_info[info] = language.attach_info(vm, {
		name = info.name,
		description = info.description or "",
		key = info.name,
		is_var = false,

		overloads = overloads,
	})
end

local function unregister_command(info: types.CommandRepresentation)
	if not map_remove_info[info] then return end

	commands[info.name] = nil
	map_remove_info[info].remove()
	map_remove_info[info] = nil
	write_global(info.name, nil)
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
	local arguments: { language.AnalysisArgument | types.Overload } = (
		{ info.arguments() }
		or {
			{
				kind = "argument",
				name = "...",
				description = "unspecified",

				suggestions = function() return {} end,

				type = "any",
				optional = false,
				vararg = true,
			},
		}
	) :: any

	local _, overloads = compute_overloads(info.description or "", arguments)

	local representation: types.CommandRepresentation = {
		name = name,
		description = info.description,
		permissions = info.permissions,

		information = {
			name = name,
			description = info.description or "",
			key = name,
			overloads = overloads,
		},

		callback = info.callback,
		dirty_replicate = true,
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
			set_command_from_representation(representation, arguments)
		end

		state.local_commands[name] = {
			representation = representation,
			arguments = arguments,
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
	analyze = analyze,
	write_global = write_global,
	after_command_run = after_run,

	register_type = register_type,
	get_type = get_type,

	set_command_from_representation = set_command_from_representation,
	unset_command_from_representation = unregister_command,
}
