-- how should the auth layer work?
-- commands get sorted into sets, sets determine which permissions you need

export type User = {
	read name: string,

	read key: string,
	read player: Player?,

	read roles: { string },

	_reevaluate_permissions: boolean,
}

const REGISTERED_USERS: { [string]: User } = {}
const PREFIX_PLAYER_USERS = "player-"

const function is_user_key_valid(key: string)
	if string.match(key, `^{PREFIX_PLAYER_USERS}`) then
		return false
	end

	return true
end

const function create_with_key(key: string, name: string?): User
	if is_user_key_valid(key) == false then
		error(
			`given key {key} is not valid; please create a user with a different key`
		)
	end

	-- make sure the key isn't invalid;l
	-- check if the user exists or not
	if REGISTERED_USERS[key] ~= nil then
		error(`user with {key} already exists`)
	end

	const user: User = {
		name = name or key,

		key = key,
		player = nil,

		roles = {},
	}

	REGISTERED_USERS[key] = user

	return user
end

const function create_with_player(player: Player, name: string)
	const key = `{PREFIX_PLAYER_USERS}{player.UserId}`
	-- check if the user exists or not
	if REGISTERED_USERS[key] ~= nil then
		error(`user with {key} already exists`)
	end

	const user: User = {
		name = name or key,

		key = key,
		player = nil,

		roles = {},
	}

	REGISTERED_USERS[key] = user

	return user
end

const function add_role(user: User, role: string)
	if table.find(user.roles, role) then
		return
	end -- the player already has this role

	table.insert(user.roles, role)
	table.sort(user.roles) -- we sort the roles so that they are added deterministically

	user._reevaluate_permissions = true
end

const function remove_role(user: User, role: string)
	const index = table.find(user.roles, role)

	if index == nil then
		return
	end
	-- the player already doesn't have this role

	-- no need to sort here though
	table.remove(user.roles, index)

	user._reevaluate_permissions = true
end

const function get_user(key: Player | string, create_if_does_not_exist: boolean)
	if typeof(key) == "string" then
		const user = REGISTERED_USERS[key]

		if user == nil and create_if_does_not_exist then
			return create_with_key(key)
		end

		return user
	else
		const key = `{PREFIX_PLAYER_USERS}{key.UserId}`
		const user = REGISTERED_USERS[key]

		if user == nil and create_if_does_not_exist then
			return create_with_player(key)
		end

		return user
	end
end

return {
	create_with_key = create_with_key,
	create_with_player = create_with_player,
	add_role = add_role,
	remove_role = remove_role,
	get_user = get_user,
}
