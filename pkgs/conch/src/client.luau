--!strict
local Players = game:GetService "Players"

local arguments = require "./arguments"
local console = require "./console"
local language = require "../roblox_packages/language"
local net = require "./net"
local state = require "./state"
local types = require "./types"
local users = require "./user"

local LOCALPLAYER = Players.LocalPlayer

local invocation_id = 0

local function create_local_user(data: net.UserPacket)
	-- print('creating new local user')
	local self = users.create_user {
		name = data.name,
		player = LOCALPLAYER :: Player | false,
	}
	state.local_user = self
end

local function update_user_roles(data: net.UpdateUserRolesPacket)
	-- print("updating local user roles", data.roles)
	local user = state.users[data.id]
	assert(user, "local user does not exist")

	user.roles = data.roles

	if user ~= state.local_user then return end

	for _, command in state.local_commands do
		if
			users.has_permissions(
				user,
				unpack(command.representation.permissions or {})
			)
		then
			-- print(
			-- 	"setting command representation for",
			-- 	command.representation.name
			-- )
			console.set_command_from_representation(
				command.representation,
				command.arguments
			)
		else
			-- print(
			-- 	"removing command representation for",
			-- 	command.representation.name
			-- )
			console.unset_command_from_representation(command.representation)
		end
	end
end

local function update_role_permissions(data: net.UpdateRolePacket)
	-- print('updating user role permissions')
	state.roles[data.name] = data.permissions

	local user = state.local_user
	if not user then return end

	for _, command in state.local_commands do
		if
			users.has_permissions(
				user,
				unpack(command.representation.permissions or {})
			)
		then
			print(
				"setting command representation for",
				command.representation.name
			)
			console.set_command_from_representation(
				command.representation,
				command.arguments
			)
		else
			console.unset_command_from_representation(command.representation)
		end
	end
end

-- given a language type, fills al types automatically
local function fill_types(data: language.Type?)
	if not data then
		return
	elseif data.kind == "command" then
		for _, value in data.arguments do
			fill_types(value.type)
		end
	elseif data.kind == "function" then
		return
	elseif data.kind == "intersection" then
		for _, field in data.fields do
			fill_types(field)
		end
	elseif data.kind == "literal" then
		return
	elseif data.kind == "strange" then
		local type_data = arguments.get_strange_type(data.id)
		if type_data == nil then
			return warn(`{data.type} {data.id} is unregistered`)
		end

		-- forcefully overwrite the type; this is fine because replication deepclones
		(data :: any).match = type_data.match;
		(data :: any).suggestions = type_data.suggestions
	elseif data.kind == "table" then
		fill_types(data.indexer)
		fill_types(data.value)

		if data.fields then
			for key, value in data.fields do
				fill_types(key)
				fill_types(value)
			end
		end
	end
end

local function register_command(data: net.RegisterCommandPacket)
	-- warn("NEW SERVER COMMAND", data.name)
	fill_types(data.type)

	assert(data.type.kind == "command")

	console.register_command(data.name, {
		description = data.description,
		permissions = data.permissions,
		arguments = function() return unpack(data.type.arguments) end :: any,

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
