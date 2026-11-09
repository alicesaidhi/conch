const users = require("./users")

export type Role = string
export type Permission = string

export type RoleArchetypeKey = string

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
