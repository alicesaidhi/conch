const users = require("./users")

export type Role = string
export type Permission = string

export type RoleArchetypeKey = string

export type AuthHook = (
	user: User,
	required_permissions: { Permission }
) -> string?

const PERMISSION_CALLBACK_HOOKS: { AuthHook } = {}

const SUPER_USER: Role = "super-user"
const SAVE_STATE: Role = "save-state"

const VIEW_FULL_SERVER_LOGS: Permission = "view-full-server-logs"
const ANYONE_CAN_EXECUTE: Permission = "anyone-can-execute"
const UNBOUNDED: Permission = "unbounded-rate-limits"

-- the permission system is optimized specifically for the case where there's few
-- unique combinations of roles within a single server.
const ROLE_PERMISSIONS: { [Role]: { Permission } } = {}
const ROLE_SET_ARCHETYPES: { [{ Role }]: { [Permission]: true } } = setmetatable(
	{},
	{ __mode = "k" } -- we automatically gc archetypes we don't need
)

const function eq_tables<K, V>(a: { [K]: V }, b: { [K]: V })
	if #a ~= #b then
		return false
	end

	for k, v in a do
		if b[k] ~= v then
			return false
		end
	end

	return true
end

const function find_archetype(roles: { Role }): { Role }?
	for archetype, permissions in ROLE_SET_ARCHETYPES do
		-- check if archetypes are similar
		if #roles ~= #archetype then
			continue
		end

		if eq_tables(archetype, roles) == false then
			continue
		end

		return archetype
	end

	return nil
end

const function rebuild_archetype(archetype: { Role }): { [Permission]: true }
	const permissions = {}

	for _, role in archetype do
		const role_permissions = ROLE_PERMISSIONS[role]

		if role_permissions == nil then
			continue
		end

		for _, permission in role_permissions do
			permissions[permission] = true
		end
	end

	ROLE_SET_ARCHETYPES[archetype] = permissions
	return permissions
end

const function update_archetypes_with_role(role: Role)
	for archetype, permissions in ROLE_SET_ARCHETYPES do -- rebuild the table
		if table.find(archetype, role) then
			rebuild_archetype(archetype)
		end
	end
end

const function set_permissions(role: Role, permissions: { Permission })
	ROLE_PERMISSIONS[role] = permissions
	update_archetypes_with_role(role)
end

const function get_permissions_for_role(role: Role): { Permission }?
	return ROLE_PERMISSIONS[role]
end

const function get_permissions_for_roles(
	roles: { Role }
): { [Permission]: true }
	const clone_of_roles = table.clone(roles)
	table.sort(clone_of_roles)

	const archetype = find_archetype(clone_of_roles)

	if archetype == nil then
		-- this must be the first archetype
		return rebuild_archetype(clone_of_roles)
	else
		return ROLE_SET_ARCHETYPES[archetype]
	end
end

const function has_permissions(roles: { Role }, permissions: { Permission })
	const perms_roles_have = get_permissions_for_roles(roles)
	for _, permission in permissions do
		if perms_roles_have[permission] ~= true then
			return false
		end
	end

	return true
end

const function determine_permissions(
	user: users.User,
	permissions: { Permission }
): (boolean, string)
	for _, hook in PERMISSION_CALLBACK_HOOKS do
		const why = hook(user, permissions)

		if why ~= nil then
			return false, why
		end
	end

	return true
end

const function hook_before_run(callback)
	table.insert(PERMISSION_CALLBACK_HOOKS, callback)
end

const function check_user_permissions(
	user: users.User,
	required: { Permission }
)
	const permissions = get_permissions_for_roles(user.roles)
	const missing = {}

	for _, permission in required do
		if permissions[permission] ~= true then
			table.insert(missing, permission)
		end
	end

	return if #missing == 0
		then nil
		else `missing the following required permissions: {table.concat(
			missing,
			", "
		)}`
end

hook_before_run(check_user_permissions)

return {
	set_permissions = set_permissions,
	get_permissions_for_role = get_permissions_for_role,
	get_permissions_for_roles = get_permissions_for_roles,
	hook_before_run = hook_before_run,
	has_permissions = has_permissions,

	SUPER_USER = SUPER_USER,
	VIEW_FULL_SERVER_LOGS = VIEW_FULL_SERVER_LOGS,
	ANYONE_CAN_EXECUTE = ANYONE_CAN_EXECUTE,
	UNBOUNDED = UNBOUNDED,
	SAVE_STATE = SAVE_STATE,
}
