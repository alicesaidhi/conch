--!strict
local RunService = game:GetService "RunService"

local constants = require "./constants"
local net = require "./net"
local state = require "./state"
local types = require "./types"

local IS_SERVER = RunService:IsServer()

local function obtain_user_key(player: Player | false, name: string?)
	return if player then `player-{player.UserId}` else `server-{name}`
end

local function create_user(options: {
	name: string,
	player: Player | false,
}): types.UserPublic
	local user = {
		id = obtain_user_key(options.player, options.name),
		name = options.name,
		player = options.player,

		disconnected = false,
		dirty = false,
		roles = {},
	}

	if IS_SERVER and user.player then
		net.server.fire_create_user(user.player, user.id, user.name)
	end

	state.users[user.id] = user

	return user
end

local function has_permissions(user: types.UserPublic, ...: types.Permission)
	-- print("checking if", user.name, "with roles", user.roles, "has permission to run", ...)
	local permissions_necessary = { ... }

	for _, role in user.roles do
		if constants.ADMIN_ROLE == role then return true end
		local permissions = state.roles[role]
		if not permissions then continue end
		for _, permission in state.roles[role] do
			local index = table.find(permissions_necessary, permission)
			if not index then continue end
			table.remove(permissions_necessary, index)
			if #permissions_necessary == 0 then return true end
		end
	end

	return false
end

local function disconnect_user(user: types.UserPublic)
	local self = user :: types.User
	if self.disconnected == true then return end

	self.disconnected = true
	state.users[self.id] = nil
end

local function give_roles(user: types.UserPublic, ...: types.Role)
	if user.disconnected then return end
	local self = user :: types.User
	local new_roles: { string } = {}

	for i = 1, select("#", ...) do
		local role = select(i, ...)
		if table.find(new_roles, role) then continue end
		table.insert(new_roles, role)
	end

	for _, role in self.roles do
		if table.find(new_roles, role) then continue end
		table.insert(new_roles, role)
	end

	self.roles = new_roles

	if IS_SERVER and self.player then
		self.dirty = true
		net.server.fire_update_user_roles(
			self.player,
			{ id = self.id, roles = new_roles }
		)
	end
end

local function remove_roles(user: types.UserPublic, ...: types.Role)
	if user.disconnected then return end
	local self = user :: types.User
	local new_roles = table.clone(self.roles)
	local removing = { ... }

	for i = #new_roles, 1, -1 do
		if not table.find(removing, new_roles[i]) then continue end
		new_roles[i] = new_roles[#new_roles]
		new_roles[#new_roles] = nil
	end

	self.roles = new_roles

	if RunService:IsServer() and self.player then
		self.dirty = true
		net.server.fire_update_user_roles(
			self.player,
			{ id = self.id, roles = new_roles }
		)
	end
end

return {
	obtain_user_key = obtain_user_key,
	create_user = create_user,
	disconnect_user = disconnect_user,
	has_permissions = has_permissions,

	give_roles = give_roles,
	remove_roles = remove_roles,
}
