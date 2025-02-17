local Players = game:GetService "Players"
local RunService = game:GetService "RunService"

local arguments = require "./arguments"
local ast = require "../luau_packages/ast"
local bootstrap = require "./bootstrap"
local client = require "./client"
local console = require "./console"
local context = require "./context"
local net = require "./net"
local state = require "./state"
local types = require "./types"
local user = require "./user"

export type Log = types.Log
export type CommandContext = types.CommandContext

local IS_SERVER = RunService:IsServer()
local IS_CLIENT = RunService:IsClient()

local create_user = user.create_user
local disconnect_user = user.disconnect_user
local has_permissions = user.has_permissions
local create_command_context = context.create_command_context
local get_command_context = context.get_command_context

local function FOREACH<K, V>(t: { [K]: V }, fn: (value: V, key: K) -> ())
	for key, value in t do
		fn(value, key)
	end
end

local function set_role(role: types.Role, ...: types.Permission)
	state.roles[role] = { ... }

	if IS_SERVER then net.server.fire_update_role_perms(role, { ... }) end
end

local function initiate_user_replication(user: types.UserPublic)
	for _, command in console.console.commands do
		if not has_permissions(user, unpack(command.permissions)) then
			continue
		end

		net.server.fire_register_command(user.player, {
			name = command.name,
			permissions = command.permissions,
		})
	end
end

local function get_user(key: Player | string)
	if typeof(key) == "string" then
		local user_key = user.obtain_user_key(false, key)
		local self = state.users[user_key]

		return if not self
			then create_user { name = user_key, player = false }
			else self
	else
		local user_key = user.obtain_user_key(key, key.DisplayName)
		local self = state.users[user_key]

		if not self then
			local user = create_user { name = key.DisplayName, player = key }
			initiate_user_replication(user)
			return user
		else
			return self
		end
	end
end

local function disconnect_user_for_player(player: Player)
	local key = user.obtain_user_key(player, player.DisplayName)
	local self = state.users[key]

	if not self then return end

	disconnect_user(self)
end

local function invoke_server_command(
	player: Player,
	data: net.InvokeCommandPacket
)
	local user = get_user(player)
	local command = console.console.commands[data.name]

	local function fail()
		net.server.fire_failed_invoke_reply(player, data.invoke_id)
	end

	if not command or not user then return fail() end
	if not has_permissions(user, unpack(command.permissions)) then
		return fail()
	end

	local pop = create_command_context(user, data.invoke_id)

	local function handle(ok: boolean, ...: any)
		console.after_command_run:fire {
			ok = ok,
			command = data.name,
			arguments = data.args,
			result = { ... },
		}
		pop()
		if not ok then
			warn(...)
			return fail()
		end

		return net.server.fire_successful_invoke_reply(
			player,
			data.invoke_id,
			{ ... }
		)
	end

	return handle(pcall(command.callback, unpack(data.args)))
end

local function resend_new_commands(user: types.User)
	if not user.dirty then return end

	for _, cmd in console.console.commands do
		console.replicate_to_player(user.player, cmd)
	end

	user.dirty = false
end

local function initiate_default_lifecycle()
	if IS_CLIENT then
		-- print("connected events")
		net.client.init()

		net.client.on_command_registered(client.register_command)
		net.client.on_invoke_reply(client.receive_server_results)
		net.client.on_log_received(client.log)
		net.client.on_user_info_received(client.create_local_user)
		net.client.on_role_info_received(client.update_role_permissions)
		net.client.on_user_roles_update(client.update_user_roles)

		-- RunService.Heartbeat:Connect(zap.send_events)
	elseif IS_SERVER then
		net.server.init()

		-- print("initiated lifecycle")
		Players.PlayerAdded:Connect(get_user)
		Players.PlayerRemoving:Connect(disconnect_user_for_player)
		FOREACH(Players:GetPlayers(), get_user)
		FOREACH(
			Players:GetPlayers(),
			function(player) resend_new_commands(get_user(player)) end
		)

		net.server.on_command_invoke(invoke_server_command)

		-- RunService.Heartbeat:Connect(zap.send_events)
		RunService.Heartbeat:Connect(function()
			for _, user in state.users do
				resend_new_commands(user)
			end
		end)
	end
end

return {

	args = arguments,

	parse = ast,
	execute = function(text: string)
		local local_user = state.local_user
		assert(IS_CLIENT, "cannot run commands outside of the client")
		assert(local_user, "unable to run commands without a local user")

		local pop = create_command_context(local_user :: types.User, false)
		local ok, err = pcall(console.execute, text)
		if not ok then console.console.output { kind = "error", text = err } end
		pop()
	end,

	register_quick = console.register_quick,
	register = console.register_command,
	after_command_run = function(callback: (
		types.AfterCommandRunContext
	) -> () -> ())
		local connection =
			console.after_command_run:connect(callback :: (...any) -> ())
		return function() connection:disconnect() end
	end,

	initiate_default_lifecycle = initiate_default_lifecycle,
	has_permissions = user.has_permissions,
	set_role_permissions = set_role,

	give_roles = user.give_roles,
	remove_roles = user.remove_roles,
	get_user = get_user,

	set_var = console.write_global,

	get_command_context = get_command_context,

	register_type = console.register_type,

	log = function(kind: "warn" | "info" | "error" | "normal", text: string)
		if IS_SERVER then
			local context = state.command_context[coroutine.running()]
			if not context then return end
			local player = context.executor.player
			if not player then return end
			net.server.fire_log(player, { kind = kind, text = text })
		else
			console.console.output { kind = kind, text = text }
		end
	end,

	register_default_commands = bootstrap,

	console = console.console,
	analyze = console.analyze,

	_ = {

		create_user = user.create_user,
		disconnect_user = user.disconnect_user,
		create_local_user = function()
			local user = get_user "local"
			state.local_user = user
			return user
		end,
	},
}
