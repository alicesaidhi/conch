--!strict
local Players = game:GetService "Players"

local console = require "./console"
local net = require "./net"
local state = require "./state"
local types = require "./types"
local user = require "./user"

local LOCALPLAYER = Players.LocalPlayer

local invocation_id = 0

local function create_local_user(data: net.UserPacket)
	-- print('creating new local user')
	local self = user.create_user {
		name = data.name,
		player = LOCALPLAYER :: Player | false,
	}
	state.local_user = self
end

local function update_user_roles(data: net.UpdateUserRolesPacket)
	-- print('updating local user roles')
	local user = state.users[data.id]
	assert(user, "local user does not exist")

	user.roles = data.roles
end

local function update_role_permissions(data: net.UpdateRolePacket)
	-- print('updating user role permissions')
	state.roles[data.name] = data.permissions
end

local function register_command(data: net.RegisterCommandPacket)
	-- warn("NEW SERVER COMMAND", data.name)
	console.register_command(data.name, {
		description = data.description :: string?,
		permissions = data.permissions,
		arguments = function() return unpack(data.arguments) end :: any,

		callback = function(...)
			local thread = coroutine.running()
			invocation_id += 1
			state.continuations[invocation_id] = thread

			net.client.invoke_command(invocation_id, data.name, { ... })

			-- print("waiting for function to finish", data.name)
			local reply = (coroutine.yield()) :: net.InvokeReplyPacket
			-- print("resuming function")

			if reply.status == "ok" then
				-- print("unpacking with", data.results)
				return unpack(reply.results)
			else
				error "something went wrong on the server"
			end
		end,
	})
end

local function receive_server_results(data: net.InvokeReplyPacket)
	local thread = state.continuations[data.invoke_id]
	if not thread then return end
	-- print('received result for', data)
	state.continuations[data.invoke_id] = nil
	task.spawn(thread, data)
end

local function log(data: types.Log) console.console.output(data) end

return {
	create_local_user = create_local_user,
	update_user_roles = update_user_roles,
	update_role_permissions = update_role_permissions,
	register_command = register_command,
	receive_server_results = receive_server_results,
	log = log,
}
