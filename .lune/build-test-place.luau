--[[
disgusting code for ci

]]

local fs = require "@lune/fs"
local process = require "@lune/process"
local serde = require "@lune/serde"

local map_pesde = {}
for _, dependency in fs.readDir "pkgs" do
	if dependency:match "_foreign_" then
		fs.removeDir(`pkgs/{dependency}`)
	else
		local pesde: PesdeToml =
			serde.decode("toml", fs.readFile(`pkgs/{dependency}/pesde.toml`))
		local name = string.match(pesde.name, ".-/(.*)")
		map_pesde[name] = dependency

		pcall(fs.removeDir, `pkgs/{dependency}/roblox_packages`)
	end
end

print "installing"
process.spawn("pesde", { "i" }, { stdio = "forward" })
print "finished installing"

type PesdeOverride = { name: string, version: string }
type PesdePatch = { [string]: string }
type PesdeDependency = | {
	name: string,
	wally: nil,
	version: string,
	index: string?,
	target: string?,
	repo: nil,
	rev: nil,
	path: nil,
	workspace: nil,
} | {
	name: nil,
	wally: string,
	version: string,
	index: string?,
	target: nil,
	repo: nil,
	rev: nil,
	path: nil,
	workspace: nil,
} | {
	name: nil,
	wally: nil,
	version: nil,
	index: nil,
	target: nil,
	repo: string,
	rev: string,
	path: string?,
	workspace: nil,
} | {
	name: nil,
	wally: nil,
	version: string,
	index: nil,
	target: nil,
	repo: nil,
	rev: nil,
	path: nil,
	workspace: string,
}

type PesdeToml = {
	name: string,
	version: string,
	description: string?,
	license: string?,
	authors: { string }?,
	repository: string?,
	private: boolean?,
	includes: { string }?,
	pesde_version: string?,
	workspace_members: { string }?,

	target: {
		environment: "roblox" | "roblox_server",
		lib: string?,
		build_files: { string }?,
	} | {
		environment: "luau" | "lune",
		lib: string?,
		bin: string?,
		scripts: { [string]: string }?,
	},

	scripts: {
		roblox_sync_config_generator: string?,
		sourcemap_generator: string?,
		[string]: string,
	}?,

	indices: {
		default: string,
		[string]: string,
	}?,

	wally_indices: {
		default: string,
		[string]: string,
	}?,

	overrides: { [string]: PesdeOverride }?,
	patches: { [string]: PesdePatch }?,

	place: {
		shared: string,
		server: string,
	}?,

	dependencies: { [string]: PesdeDependency }?,
	peer_dependencies: { [string]: PesdeDependency }?,
	dev_dependencies: { [string]: PesdeDependency }?,
}

for _, child in fs.readDir "pkgs" do
	if not fs.isDir(`pkgs/{child}/roblox_packages`) then continue end

	for _, dependency in fs.readDir(`pkgs/{child}/roblox_packages/.pesde/`) do
		local pesde_name = string.match(dependency, ".-%+(.*)")
		-- local wally_name = string.match(dependency, ".-_(.-)@")

		if pesde_name and map_pesde[pesde_name] then continue end

		if fs.isDir(`pkgs/_foreign_{dependency}`) then continue end
		fs.copy(
			`pkgs/{child}/roblox_packages/.pesde/{dependency}`,
			`pkgs/_foreign_{dependency}`
		)
		if not pesde_name then continue end

		for _, version in fs.readDir(`pkgs/_foreign_{dependency}`) do
			if
				not fs.isDir(
					`pkgs/_foreign_{dependency}/{version}/{pesde_name}/roblox_packages`
				)
			then
				continue
			end
			for _, roblox_package in
				fs.readDir(
					`pkgs/_foreign_{dependency}/{version}/{pesde_name}/roblox_packages`
				)
			do
				if roblox_package == ".pesde" then continue end
				local file = fs.readFile(
					`pkgs/_foreign_{dependency}/{version}/{pesde_name}/roblox_packages/{roblox_package}`
				)
				fs.removeFile(
					`pkgs/_foreign_{dependency}/{version}/{pesde_name}/roblox_packages/{roblox_package}`
				)
				local new = string.gsub(
					file,
					`script.Parent.Parent.Parent.Parent.Parent%["`,
					`script.Parent.Parent.Parent["_foreign_`
				)
				fs.writeFile(
					`pkgs/_foreign_{dependency}/{version}/{pesde_name}/roblox_packages/{roblox_package}`,
					new
				)
			end
		end
	end

	for _, version in fs.readDir(`pkgs/{child}`) do
		for _, roblox_package in fs.readDir(`pkgs/{child}/roblox_packages`) do
			if roblox_package == ".pesde" then
				fs.removeDir(`pkgs/{child}/roblox_packages/.pesde`)
				continue
			end

			local file =
				fs.readFile(`pkgs/{child}/roblox_packages/{roblox_package}`)
			local pesde_name =
				string.match(file, `script.Parent%["%.pesde"%]%[".-%+(.-)"`)
			-- local wally_name = string.match(file, `script.Parent%["%.pesde"%]%[".-_(.-)@`)

			if map_pesde[pesde_name] then
				local new = string.gsub(
					file,
					`script.Parent%[".pesde"%]%["alicesaidhi%+(.-)"%]%[.-%]`,
					function(match: string, pattern: string)
						return `script.Parent.Parent.Parent`
					end
				)
				fs.removeFile(`pkgs/{child}/roblox_packages/{roblox_package}`)
				print(`pkgs/{child}/roblox_packages/{roblox_package}`)
				fs.writeFile(
					`pkgs/{child}/roblox_packages/{roblox_package}`,
					new
				)
			else
				local new = string.gsub(
					file,
					`script.Parent%[".pesde"%]%["`,
					`script.Parent.Parent.Parent["_foreign_`
				)
				fs.removeFile(`pkgs/{child}/roblox_packages/{roblox_package}`)
				fs.writeFile(
					`pkgs/{child}/roblox_packages/{roblox_package}`,
					new
				)
			end
		end
	end
end
