local Players = game:GetService "Players"
local RunService = game:GetService "RunService"

local arguments = require "@self/arguments"
local bootstrap = require "@self/bootstrap"
local client = require "@self/client"
local console = require "@self/console"
local constants = require "@self/constants"
local context = require "@self/context"
local language = require "./roblox_packages/language"
local net = require "@self/net"
local state = require "@self/state"
local types = require "@self/types"
local user = require "@self/user"

export type Log = types.Log
export type CommandContext = types.CommandContext
export type Stream = types.Stream
export type CommandArgument = language.CommandArgument
export type Suggestion = language.Suggestion

local IS_SERVER = RunService:IsServer()
local IS_CLIENT = RunService:IsClient()

local create_user = user.create_user
local disconnect_user = user.disconnect_user
local has_permissions = user.has_permissions
local create_command_context = context.create_command_context
local get_command_context = context.get_command_context

local limits: types.Limits = {}

-- keyed by user, so the entries go away together with the user
local invoke_buckets: { [types.User]: { tokens: number, at: number } } = {}
local last_runs: { [types.User]: { [string]: number } } = {}
setmetatable(invoke_buckets, { __mode = "k" })
setmetatable(last_runs, { __mode = "k" })

-- players that left, so a late get_user doesn't store a user for them again
local departed: { [Player]: true } = {}
setmetatable(departed, { __mode = "k" })

--[=[
Takes one invoke from the user's token bucket, which refills at
max_invokes_per_second. Returns false when the bucket is empty.
]=]
local function take_invoke(user: types.User): boolean
	local rate = limits.max_invokes_per_second
	if not rate then return true end

	local capacity = math.max(rate, 1)
	local now = os.clock()
	local bucket = invoke_buckets[user] or { tokens = capacity, at = now }
	invoke_buckets[user] = bucket

	bucket.tokens = math.min(capacity, bucket.tokens + (now - bucket.at) * rate)
	bucket.at = now

	if bucket.tokens < 1 then return false end
	bucket.tokens -= 1
	return true
end

--[=[
Returns how many seconds are left on the command's cooldown for the user.
When none are left, the cooldown starts again.
]=]
local function use_cooldown(
	user: types.User,
	command: types.CommandRepresentation
): number
	local cooldown = command.cooldown
	if not cooldown then return 0 end

	local runs: { [string]: number } = last_runs[user] or {}
	last_runs[user] = runs

	local now = os.clock()
	local last = runs[command.name]
	if last and now - last < cooldown then return cooldown - (now - last) end

	runs[command.name] = now
	return 0
end

local function FOREACH<K, V>(t: { [K]: V }, fn: (value: V, key: K) -> ())
	for key, value in t do
		fn(value, key)
	end
end

local function set_role(role: types.Role, ...: types.Permission)
	state.roles[role] = { ... }

	if IS_SERVER then net.server.fire_update_role_perms(role, { ... }) end
end

local function initiate_user_replication(user: types.User)
	if not user.player then return end

	for _, command in console.console.commands do
		if not has_permissions(user, unpack(command.permissions)) then
			continue
		end

		net.server.fire_register_command(user.player, {
			name = command.name,
			description = command.description,
			permissions = command.permissions,
			aliases = command.aliases,
			group = command.group,
			type = command.type,
		})
	end
end

local function get_user(key: Player | string)
	if typeof(key) == "string" then
		local user_key = user.obtain_user_key(false, key)
		local self = state.users[user_key]

		return if not self
			then create_user { name = key, player = false }
			else self
	else
		local user_key = user.obtain_user_key(key, key.DisplayName)
		local self = state.users[user_key]

		if self and self.player == key then return self end

		if departed[key] then
			return {
				id = user_key,
				name = key.DisplayName,
				player = key,

				disconnected = true,
				dirty = false,
				roles = {},
			}
		end

		-- left over from an earlier Player with the same UserId
		if self then disconnect_user(self) end

		local user = create_user { name = key.DisplayName, player = key }
		initiate_user_replication(user)
		return user
	end
end

local function invoke_server_command(
	player: Player,
	data: net.InvokeCommandPacket
)
	if
		typeof(data) ~= "table"
		or typeof(data.name) ~= "string"
		or typeof(data.invoke_id) ~= "number"
		or typeof(data.args) ~= "table"
	then
		return player:Kick()
	end

	local user = get_user(player)
	local command = console.console.commands[data.name]

	local function fail(why: string?)
		net.server.fire_failed_invoke_reply(player, data.invoke_id, why)
	end

	if not command or not user then return fail() end
	if not has_permissions(user, unpack(command.permissions)) then
		return fail()
	end
	if not take_invoke(user) then
		return fail "you are running commands too quickly"
	end

	local remaining = use_cooldown(user, command)
	if remaining > 0 then
		return fail(`{command.name} is on cooldown for {math.ceil(remaining)}s`)
	end

	local pop = create_command_context(user, data.invoke_id)

	local function handle(ok: boolean, ...: any)
		pop()
		if not ok then
			-- a before_run hook gives its reason for the executor to read
			local denied = console.get_denied_reason((...))
			if denied then return fail(denied) end

			warn(...)
			return fail(
				if has_permissions(user, constants.FULL_OUTPUT_PERMISSION)
					then tostring((...))
					else nil
			)
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
	if not user.player then return end

	for _, cmd in console.console.commands do
		console.replicate_to_player(user.player, cmd)
	end

	user.dirty = false
end

local already_ready = {}
local function on_ready(player: Player)
	if already_ready[player] then return end

	already_ready[player] = true
	local user = get_user(player)
	user.dirty = true

	net.server.fire_create_user(player, user.id, user.name)

	for role, permissions in state.roles do
		net.server.fire_update_role_perms_to(player, role, permissions)
	end

	net.server.fire_update_user_roles(player, {
		id = user.id,
		roles = user.roles,
	})

	resend_new_commands(get_user(player))
end

local function disconnect_user_for_player(player: Player)
	departed[player] = true
	already_ready[player] = nil

	local key = user.obtain_user_key(player, player.DisplayName)
	local self = state.users[key]

	if not self or self.player ~= player then return end

	disconnect_user(self)
end

local function initiate_default_lifecycle()
	if IS_CLIENT then
		-- print("connected events")
		net.client.init()

		net.client.on_command_registered(client.register_command)
		net.client.on_command_unregistered(client.unregister_command)
		net.client.on_invoke_reply(client.receive_server_results)
		net.client.on_log_received(client.log)
		net.client.on_user_info_received(client.create_local_user)
		net.client.on_role_info_received(client.update_role_permissions)
		net.client.on_user_roles_update(client.update_user_roles)

		net.client.fire_ready()
		-- RunService.Heartbeat:Connect(zap.send_events)
	elseif IS_SERVER then
		net.server.init()

		-- print("initiated lifecycle")
		Players.PlayerAdded:Connect(get_user :: any)
		Players.PlayerRemoving:Connect(disconnect_user_for_player)
		FOREACH(Players:GetPlayers(), get_user :: any)
		FOREACH(
			Players:GetPlayers(),
			function(player) resend_new_commands(get_user(player)) end
		)

		net.server.on_ready(on_ready)
		net.server.on_command_invoke(invoke_server_command)

		-- RunService.Heartbeat:Connect(zap.send_events)
		RunService.PostSimulation:Connect(function()
			for _, user in state.users do
				resend_new_commands(user)
			end
		end)
	end
end

return {

	version = "0.4.0",

	args = arguments.args,
	get_strange_type = arguments.get_strange_type,
	register_strange_type = arguments.register_strange_type,
	pluralize_type = arguments.pluralize,
	wrap_type = arguments.wrap_type,

	execute = function(text: string)
		local local_user = state.local_user
		assert(IS_CLIENT, "cannot run commands outside of the client")
		assert(local_user, "unable to run commands without a local user")

		if IS_CLIENT then net.client.fire_log_command(text) end

		local pop = create_command_context(local_user :: types.User, false)
		local ok, err = pcall(console.execute, text)
		if not ok then console.console.output { kind = "error", text = err } end
		pop()
	end,

	cancel = console.cancel,

	register_quick = console.register_quick,
	register = console.register_command,
	unregister = console.unregister,

	on_execution = function(callback: (Player: Player, src: string) -> ())
		local connection = net.server.on_log_command(function(player, log)
			if typeof(log) ~= "string" then return player:Kick() end

			local max_length = limits.max_input_length
			if max_length and #log > max_length then return end

			callback(player, log)
		end)

		return function() connection:Disconnect() end
	end,
	on_command_run = function(callback: (types.AfterCommandRunContext) -> ())
		local connection =
			console.after_command_run:connect(callback :: (...any) -> ())
		return function() connection:disconnect() end
	end,
	before_run = console.before_run,

	initiate_default_lifecycle = initiate_default_lifecycle,
	has_permissions = user.has_permissions,
	set_role_permissions = set_role,
	set_limits = function(new_limits: types.Limits)
		limits = table.clone(new_limits)
	end,

	give_roles = user.give_roles,
	remove_roles = user.remove_roles,
	get_user = get_user,

	set_var = console.write_global,

	get_command_context = get_command_context,

	log = function(
		kind: "warn" | "info" | "error" | "normal" | "success",
		text: string
	)
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

	log_to = function(
		player: Player,
		kind: "warn" | "info" | "error" | "normal" | "success",
		text: string
	)
		if IS_SERVER then
			net.server.fire_log(player, { kind = kind, text = text })
		elseif Players.LocalPlayer == player then
			console.console.output { kind = kind, text = text }
		end
	end,

	register_default_commands = bootstrap,

	console = console.console,
	analyze = console.analyze,

	_ = {
		type = arguments.type,

		create_user = user.create_user,
		disconnect_user = user.disconnect_user,
		create_local_user = function()
			local user = get_user "local"
			state.local_user = user
			return user
		end,
	},
}
