local Players = game:GetService "Players"
local RunService = game:GetService "RunService"

local ast = require "../luau_packages/ast"
local compiler = require "../luau_packages/compiler"
local create_vm = require "../luau_packages/vm"
local ctypes = require "../luau_packages/types"
local intel = require "../luau_packages/intel"
local net = require "./net"
local signal = require "./signal"
local state = require "./state"
local types = require "./types"
local user = require "./user"

local IS_SERVER = RunService:IsServer()

local vm_state = { locals = {}, upvalues = {}, instructions = {} }
local vm = create_vm() :: ctypes.VirtualMachine
local commands: { [string]: types.CommandRepresentation } = {}
local after_run = signal()

local console: types.Console = {
	vm = vm,
	commands = commands,
	output = print,
}

local types = {}

local function register_type(
	type: string,
	data: {
		convert: (any) -> any,
		analysis: ctypes.AnalysisCommandArgument
			| ctypes.AnalysisCommandVariadic,
	}
)
	types[type] = data
end

local function write_global(global: string, value: any)
	assert(state.local_user, "cannot set global on server")
	assert(string.match(global, "^[A-z%-@_]*$"), `{global} is not a valid name`)
	vm.globals[global] = value
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
		permissions = representation.permissions,
		arguments = representation.arguments,
	})
end

local busy = false

local function execute(text: string)
	local ast = ast(text, false)

	assert(ast.status ~= "pending", "unfinished block")
	assert(not busy, "already executing!")

	console.output { kind = "info", text = `> {ast.src}` }
	if ast.status == "error" then
		return console.output { kind = "error", text = ast.why }
	end
	busy = true

	local instructions = compiler(ast.value, vm_state)
	vm_state.instructions = {}

	local function on_complete(
		ok: boolean,
		result: number | string,
		...: unknown
	)
		if not ok then
			console.output { kind = "error", text = tostring(result) }
		end
	end

	on_complete(pcall(vm.run, instructions))
	busy = false
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
	local arguments: { types.Type } = (
		{ info.arguments() }
		or {
			{
				kind = "varargs",
				type = "any",
				name = "...",
				description = "unspecified",
			},
		}
	) :: any
	local analysis_arguments: { ctypes.AnalysisCommandArgument | ctypes.AnalysisCommandVariadic } =
		{}
	local converts: { (any) -> any } = {}

	for index, argument in arguments do
		local data = get_type(argument.type)
			or warn(`no argument of type "{argument.type}" is registered`)
			or get_type "any"
		local clone = table.clone(data.analysis)

		converts[index] = data.convert
		analysis_arguments[index] = {
			kind = if argument.kind == "varargs"
				then "variadic"
				else "argument",
			name = argument.name or clone.name,
			description = argument.description,
			type = clone.type,
			suggestion_generator = clone.suggestion_generator,
		}
	end

	local representation: types.CommandRepresentation = {
		name = name,
		permissions = info.permissions,
		arguments = arguments,
		type_info = {
			kind = "command",
			name = name,
			description = info.description,
			arguments = analysis_arguments,
		},

		callback = info.callback,
		dirty_replicate = true,
	}

	commands[name] = representation

	vm.commands[name] = function(...)
		local custom = { ... }

		local function move(from: number, ...)
			for i = 0, select("#", ...) - 1 do
				custom[i + from] = select(i + 1, ...)
			end
		end

		local variadic, last_index
		for idx, argument in arguments do
			if argument.variadic then
				variadic = converts[idx]
				last_index = idx
				break
			else
				custom[idx] = converts[idx]((select(idx, ...)))
			end
		end

		if variadic and last_index then
			for idx = last_index + 1, select("#", ...) do
				custom[idx] = variadic((select(idx, ...)))
			end
		end

		local results = { pcall(info.callback, unpack(custom)) }
		local ok = table.remove(results, 1)

		after_run:fire {
			ok = ok,
			command = name,
			arguments = custom,
			result = results,
		}

		if not ok then error(results[2]) end

		return unpack(results)
	end

	if IS_SERVER then
		for _, player in Players:GetPlayers() do
			-- print("replicating to player", player)
			replicate_to_player(player, representation)
		end
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

local function analyze(src: string, where: number): ctypes.AnalysisInformation
	local combined_variables = {}
	local analyze_commands = {}

	local index = 1
	for name, command in commands do
		analyze_commands[index] = command.type_info

		index += 1
	end

	for global, value in vm.globals do
		combined_variables[global] = value
	end

	for index, key in vm_state.locals do
		combined_variables[key] = vm.locals[index]
	end

	return intel.generate_analysis_info {
		code = src,
		where = where,

		variables = combined_variables,
		commands = analyze_commands,
	}
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

	ast = ast,
}
