local ReplicatedStorage = game:GetService "ReplicatedStorage"
local RunService = game:GetService "RunService"

export type UpdateRolePacket = {
	name: string,

	permissions: { string },
}

export type UserPacket = {
	name: string,
	id: string,
}

export type UpdateUserRolesPacket = { id: string, roles: { string } }

export type RegisterCommandPacket = {
	name: string,
	description: string,
	permissions: { string },
	arguments: {
		{
			kind: "varargs" | "arg",
			optional: boolean,
			type: string,
			name: string,
			description: string,
		}
	},
}

export type InvokeCommandPacket = {
	name: string,
	invoke_id: number,

	args: { unknown },
}

export type InvokeReplyPacket = {
	status: "ok",
	invoke_id: number,
	results: { unknown },
} | {
	status: "err",
	invoke_id: number,
}

export type LogPacket = {
	kind: "info" | "normal" | "warn" | "error",
	text: string,
}

export type RemoteIndex = {
	invoke_server_command: RemoteEvent,
	create_user: RemoteEvent,
	update_user_roles: RemoteEvent,
	update_role_permissions: RemoteEvent,
	register_command: RemoteEvent,
	log: RemoteEvent,
	log_command: RemoteEvent,
}

export type LogExecutionPacket = string

local run_context: "server" | "client" = if RunService:IsServer()
	then "server"
	else "client"

local function assert_run_context(context: "server" | "client")
	assert(
		run_context == context,
		`expected run context {context} but got {run_context}`
	)
end

local remotes: RemoteIndex

local net = {
	client = {
		initialized = false,
	},
	server = {
		initialized = false,
	},
}

function net.server.init()
	assert_run_context "server"

	local conch_folder = Instance.new "Folder"
	conch_folder.Name = "conch_networking"
	conch_folder.Parent = ReplicatedStorage

	local function remote(name: string): RemoteEvent
		local inst = Instance.new "RemoteEvent"
		inst.Name = name
		inst.Parent = conch_folder

		return inst
	end

	local remote_index: RemoteIndex = {
		invoke_server_command = remote "invoke_server_command",
		create_user = remote "create_user",
		update_user_roles = remote "update_user_roles",
		update_role_permissions = remote "update_role_permissions",
		register_command = remote "register_command",
		log = remote "log",
		log_command = remote "log_command",
	}

	remotes = remote_index

	net.server.initialized = true
end

function net.client.init()
	assert_run_context "client"

	local conch_folder = ReplicatedStorage:WaitForChild "conch_networking"

	local function remote(name: string): RemoteEvent
		return conch_folder:WaitForChild(name) :: RemoteEvent
	end

	local remote_index: RemoteIndex = {
		invoke_server_command = remote "invoke_server_command",
		create_user = remote "create_user",
		update_user_roles = remote "update_user_roles",
		update_role_permissions = remote "update_role_permissions",
		register_command = remote "register_command",
		log = remote "log",
		log_command = remote "log_command",
	}

	remotes = remote_index

	net.client.initialized = true
end

function net.client.on_user_roles_update(
	callback: (
		info: UpdateUserRolesPacket
	) -> ()
)
	assert(net.client.initialized, "client not initialized")
	assert_run_context "client"

	remotes.update_user_roles.OnClientEvent:Connect(callback :: any)
end

function net.client.on_command_registered(callback: (
	info: RegisterCommandPacket
) -> ())
	assert(net.client.initialized, "client not initialized")
	assert_run_context "client"

	remotes.register_command.OnClientEvent:Connect(callback :: any)
end

function net.client.on_role_info_received(
	callback: (info: UpdateRolePacket) -> ()
)
	assert(net.client.initialized, "client not initialized")
	assert_run_context "client"

	remotes.update_role_permissions.OnClientEvent:Connect(callback :: any)
end

function net.client.on_user_info_received(callback: (info: UserPacket) -> ())
	assert(net.client.initialized, "client not initialized")
	assert_run_context "client"

	remotes.create_user.OnClientEvent:Connect(callback :: any)
end

function net.client.on_log_received(callback: (info: LogPacket) -> ())
	assert(net.client.initialized, "client not initialized")
	assert_run_context "client"

	remotes.log.OnClientEvent:Connect(callback :: any)
end

function net.client.invoke_command(
	invoke_id: number,
	name: string,
	args: { unknown }
)
	assert(net.client.initialized, "client not initialized")
	assert_run_context "client"

	local invoke_command_packet: InvokeCommandPacket = {
		invoke_id = invoke_id,
		name = name,
		args = args,
	}

	remotes.invoke_server_command:FireServer(invoke_command_packet)
end

function net.client.on_invoke_reply(callback: (info: InvokeReplyPacket) -> ())
	assert(net.client.initialized, "client not initialized")
	assert_run_context "client"

	remotes.invoke_server_command.OnClientEvent:Connect(callback :: any)
end

function net.client.fire_log_command(src: string)
	assert(net.client.initialized, "client not initialized")
	assert_run_context "client"

	remotes.log_command:FireServer(src)
end

function net.server.on_log_command(fn: (Player, log: string) -> ())
	assert(net.server.initialized, "server not initialized")
	assert_run_context "server"

	return remotes.log_command.OnServerEvent:Connect(fn :: any)
end

function net.server.fire_log(player: Player, info: LogPacket)
	assert(net.server.initialized, "server not initialized")
	assert_run_context "server"

	remotes.log:FireClient(player, info)
end

function net.server.fire_register_command(
	player: Player,
	info: RegisterCommandPacket
)
	assert(net.server.initialized, "server not initialized")
	assert_run_context "server"

	remotes.register_command:FireClient(player, info)
end

function net.server.on_command_invoke(callback: (
	player: Player,
	command_invoke: InvokeCommandPacket
) -> ())
	assert(net.server.initialized, "server not initialized")
	assert_run_context "server"

	remotes.invoke_server_command.OnServerEvent:Connect(callback :: any)
end

function net.server.fire_successful_invoke_reply(
	player: Player,
	invoke_id: number,
	results: { unknown }
)
	assert(net.server.initialized, "server not initialized")
	assert_run_context "server"

	local invoke_reply_packet: InvokeReplyPacket = {
		status = "ok",
		invoke_id = invoke_id,
		results = results,
	}

	remotes.invoke_server_command:FireClient(player, invoke_reply_packet)
end

function net.server.fire_failed_invoke_reply(player: Player, invoke_id: number)
	assert(net.server.initialized, "server not initialized")
	assert_run_context "server"

	local invoke_reply_packet: InvokeReplyPacket = {
		status = "err",
		invoke_id = invoke_id,
	}

	remotes.invoke_server_command:FireClient(player, invoke_reply_packet)
end

function net.server.fire_create_user(player: Player, id: string, name: string)
	assert(net.server.initialized, "server not initialized")
	assert_run_context "server"

	local user_packet: UserPacket = {
		name = name,
		id = id,
	}

	remotes.create_user:FireClient(player, user_packet)
end

function net.server.fire_update_user_roles(
	player: Player,
	info: UpdateUserRolesPacket
)
	assert(net.server.initialized, "server not initialized")
	assert_run_context "server"

	remotes.update_user_roles:FireClient(player, info)
end

function net.server.fire_update_role_perms(
	role: string,
	permissions: { string }
)
	assert(net.server.initialized, "server not initialized")
	assert_run_context "server"

	local role_packet: UpdateRolePacket = {
		name = role,
		permissions = permissions,
	}

	remotes.update_role_permissions:FireAllClients(role_packet)
end

return net
