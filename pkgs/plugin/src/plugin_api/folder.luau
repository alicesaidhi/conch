--!nocheck
local package_version = require "./package_version"
local semver = require "./semver"

local plugins_api_folder = game:FindFirstChild "plugins_api"

local function get_plugins_api_folder(): Folder
	if not plugins_api_folder then
		plugins_api_folder = Instance.new "Folder"
		plugins_api_folder.Name = "plugins_api"
		plugins_api_folder.Parent = game
	end

	return plugins_api_folder
end

local map = {}

local function obtain_plugins_api(
	name: string,
	version: {
		major: number,
		minor: number,
		patch: number,
	}
): Folder
	if map[name] then return map[name] end
	local f = Instance.new "Folder"

	f:SetAttribute("major-userfacing", version.major)
	f:SetAttribute("minor-userfacing", version.minor)
	f:SetAttribute("patch-userfacing", version.patch)

	f:SetAttribute("major-package", package_version.major)
	f:SetAttribute("minor-package", package_version.minor)
	f:SetAttribute("patch-package", package_version.patch)

	f:AddTag "api"

	f.Name = name
	f.Parent = get_plugins_api_folder()
	return f
end

local function find_plugins_api(name: string): {
	{
		folder: Folder,
		version: semver.Version,
		package_ver: semver.Version,
	}
}
	local meets = {}

	for _, folder in
		get_plugins_api_folder():QueryDescendants(`#{name} Folder .api`)
	do
		local version = {
			major = folder:GetAttribute "userfacing-major",
			minor = folder:GetAttribute "userfacing-minor",
			patch = folder:GetAttribute "userfacing-patch",
		}
		local package_version = {
			major = folder:GetAttribute "package-major",
			minor = folder:GetAttribute "package-minor",
			patch = folder:GetAttribute "package-patch",
		}

		table.insert(meets, {
			folder = folder,
			version = version,
			package_version = package_version,
		})
	end

	return meets
end

local function wait_for_first_api(name: string): {
	folder: Folder,
	version: semver.Version,
	package_ver: semver.Version,
}
	local folder = get_plugins_api_folder():WaitForChild(name, math.huge)

	local version = {
		major = folder:GetAttribute "userfacing-major",
		minor = folder:GetAttribute "userfacing-minor",
		patch = folder:GetAttribute "userfacing-patch",
	}
	local package_version = {
		major = folder:GetAttribute "package-major",
		minor = folder:GetAttribute "package-minor",
		patch = folder:GetAttribute "package-patch",
	}

	return {
		folder = folder,
		version = version,
		package_version = package_version,
	}
end

return {
	get_plugins_api_folder = get_plugins_api_folder,
	obtain_plugins_api = obtain_plugins_api,
	find_plugins_api = find_plugins_api,
	wait_for_first_api = wait_for_first_api,
}
