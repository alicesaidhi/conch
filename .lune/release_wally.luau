local fs = require "@lune/fs"
local process = require "@lune/process"
local serde = require "@lune/serde"

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

--[[
needs to do the following:

pesde in roblox:

roblox_packages/
src/
	...files

wally in roblox:

...packages
src/
	...files

map packages in roblox in a way so that:

...packages
lib/
	roblox_packages/
	src/
		...files
	init.luau

]]

local scanned_tomls: { [string]: PesdeToml } = {}

local function fix(name: string) return string.gsub(name, "_", "-") end

-- local map_pesde = {}
-- for _, dependency in fs.readDir "pkgs" do
-- 	if dependency:match "_foreign_" then
-- 		fs.removeDir(`pkgs/{dependency}`)
-- 	else
-- 		local pesde: PesdeToml =
-- 			serde.decode("toml", fs.readFile(`pkgs/{dependency}/pesde.toml`))
-- 		local name = string.match(pesde.name, ".-/(.*)")
-- 		map_pesde[name] = dependency

-- 		pcall(fs.removeDir, `pkgs/{dependency}/roblox_packages`)
-- 	end
-- end

local function generate_wally_release_files(path: string)
	local file = fs.readFile(path .. "/pesde.toml")
	local pesde_toml: PesdeToml = serde.decode("toml", file)
	if pesde_toml.private then return end

	-- release on pesde first
	process.spawn("pesde", { "publish --yes" }, {
		cwd = path,
		env = {},
		shell = true,
	})

	local lib_file_path = pesde_toml.target.lib

	assert(lib_file_path, "no lib file, cannot make wally release")

	local lib_file = fs.readFile(path .. "/" .. lib_file_path)

	local lib_file_src: string
	do
		local lib_file_path_without = string.gsub(lib_file_path, ".luau", "")
		local init_file = {
			`local main = require("./{lib_file_path_without:gsub("/init$", "")}")`,
		}

		for value in string.gmatch(lib_file, "export type(%b  )= ") do
			table.insert(
				init_file,
				`export type{value}= main.{value:gsub("=[A-z%.]-", "")}`
			)
		end

		table.insert(init_file, "return main")
		lib_file_src = table.concat(init_file, "\n")
	end

	local init_file_src: string
	do
		local init_file = {
			`local main = require(script.lib)`,
		}

		for value in string.gmatch(lib_file, "export type(%b  )= ") do
			table.insert(
				init_file,
				`export type{value}= main.{value:gsub("=[A-z%.]-", "")}`
			)
		end

		table.insert(init_file, "return main")
		init_file_src = table.concat(init_file, "\n")
	end

	local roblox_packages: { [string]: string } = {}
	do
		local dependencies = pesde_toml.dependencies
		if dependencies then
			for name, dependency in dependencies do
				local realm = dependency.target or pesde_toml.target.environment
				if realm ~= "roblox" then continue end
				print(path .. "/roblox_packages/" .. name .. ".luau")
				local file =
					fs.readFile(path .. "/roblox_packages/" .. name .. ".luau")
				local package_file = {
					`local main = require(script.Parent.Parent.Parent["{name}"])`,
				}

				for value in string.gmatch(file, "export type (.-) = module.") do
					local export_without_default =
						string.gsub(value, "=.->", ">")
					table.insert(
						package_file,
						`export type {value} = main.{export_without_default}`
					)
				end

				table.insert(package_file, "return main")
				roblox_packages[name] = table.concat(package_file, "\n")
			end
		end
	end

	-- local luau_packages: { [string]: string } = {}
	-- do
	-- 	local dependencies = pesde_toml.dependencies
	-- 	if dependencies then
	-- 		for name, dependency in dependencies do
	-- 			local realm = dependency.target or pesde_toml.target.environment
	-- 			if realm ~= "luau" then continue end
	-- 			local file =
	-- 				fs.readFile(path .. "/luau_packages/" .. name .. ".luau")
	-- 			local package_file = {
	-- 				`local main = require(script.Parent.Parent.Parent["{name}"])`,
	-- 			}

	-- 			for value in string.gmatch(file, "export type (.-) = module.") do
	-- 				local export_without_default =
	-- 					string.gsub(value, "=.->", ">")
	-- 				table.insert(
	-- 					package_file,
	-- 					`export type {value} = main.{export_without_default}`
	-- 				)
	-- 			end

	-- 			table.insert(package_file, "return main")
	-- 			luau_packages[name] = table.concat(package_file, "\n")
	-- 		end
	-- 	end
	-- end

	local wally_toml = {}
	do
		wally_toml.package = {
			name = string.gsub(pesde_toml.name, "_", "-"),
			description = pesde_toml.description,
			version = pesde_toml.version,
			license = pesde_toml.license,
			authors = pesde_toml.authors,
			registry = "https://github.com/UpliftGames/wally-index",
			realm = "shared",
			repository = pesde_toml.repository,
			include = { "/dist" },
			exclude = {
				"pesde.toml",
				"pesde.lock",
				"src",
				"roblox_packages",
				"luau_packages",
				"**/stories",
			},
		}

		local dependencies = {}
		if pesde_toml.dependencies then
			for name, dependency in pesde_toml.dependencies do
				if dependency.wally then
					dependencies[name] =
						`{dependency.wally}@{dependency.version}`
				elseif dependency.name then
					error "pesde dependency detected"
				elseif dependency.workspace then
					local dependency_toml = scanned_tomls[dependency.workspace]
					assert(
						dependency_toml,
						`unable to find toml for {dependency.workspace}`
					)
					dependencies[name] =
						`{fix(dependency.workspace)}@{dependency_toml.version}`
				elseif dependency.repo then
					error "git dependency detected"
				end
			end
		end

		wally_toml.dependencies = dependencies
	end

	-- fs.removeDir(path .. "/dist")
	-- fs.removeFile(path .. "/default.project.json")
	-- fs.removeFile(path .. "/wally.toml")

	fs.writeDir(path .. "/dist")
	fs.writeDir(path .. "/dist/roblox_packages")
	fs.writeDir(path .. "/dist/luau_packages")

	for name, package in roblox_packages do
		fs.writeFile(
			path .. "/dist/roblox_packages/" .. name .. ".luau",
			package
		)
	end

	-- for name, package in luau_packages do
	-- 	fs.writeFile(path .. "/dist/luau_packages/" .. name .. ".luau", package)
	-- end

	fs.copy(path .. "/src", path .. "/dist/src", true)
	fs.writeFile(path .. "/dist/lib.luau", lib_file_src)
	fs.writeFile(path .. "/dist/init.luau", init_file_src)

	local package_name = string.split(pesde_toml.name, "/")[2]
	fs.writeFile(
		path .. "/default.project.json",
		`\{\n\t"name": "{fix(package_name)}",\n\t"tree": \{\n\t\t"$path": "dist"\n\t}\n}`
	)

	fs.writeFile(path .. "/wally.toml", serde.encode("toml", wally_toml, true))
end

local function link_npm_files(path: string)
	local file = fs.readFile(path .. "/pesde.toml")
	local pesde_toml: PesdeToml = serde.decode("toml", file)
	if pesde_toml.private then return end

	-- release on pesde first
	process.spawn("pesde", { "publish --yes" }, {
		cwd = path,
		env = {},
		shell = true,
	})

	local lib_file_path = pesde_toml.target.lib

	assert(lib_file_path, "no lib file, cannot make wally release")
	print(path .. "/" .. lib_file_path)
	local lib_file = fs.readFile(path .. "/" .. lib_file_path)

	local lib_file_src: string
	do
		local lib_file_path_without = string.gsub(lib_file_path, ".luau", "")
		local init_file = {
			`local main = require("./{lib_file_path_without:gsub("/init$", "")}")`,
		}

		table.insert(init_file, "return main")
		lib_file_src = table.concat(init_file, "\n")
	end

	local init_file_src: string
	do
		local init_file = {
			`local main = require(script.lib)`,
		}

		for value in string.gmatch(lib_file, "export type(%b  )= ") do
			table.insert(
				init_file,
				`export type{value}= main.{value:gsub("=[A-z%.]-", "")}`
			)
		end

		table.insert(init_file, "return main")
		init_file_src = table.concat(init_file, "\n")
	end

	local roblox_packages: { [string]: string } = {}
	do
		local dependencies = pesde_toml.dependencies
		if dependencies then
			for name, dependency in dependencies do
				local realm = dependency.target or pesde_toml.target.environment
				if realm ~= "roblox" then continue end
				local target = dependency.workspace or dependency.wally
				assert(target, "could not get dependency target")

				local split = string.split(target, "/")[2]
				local s = split:gsub("_", "-")

				local package_file = {
					`local TS = _G[script.Parent.Parent.lib]`,
					`return TS.import(script.Parent.Parent.lib, TS.getModule(script.Parent.Parent.lib, "@rbxts", "{s}").{if s
							== "vide"
						then "src"
						else "dist"})`,
				}

				roblox_packages[name] = table.concat(package_file, "\n")
			end
		end
	end

	-- local luau_packages: { [string]: string } = {}
	-- do
	-- 	local dependencies = pesde_toml.dependencies
	-- 	if dependencies then
	-- 		for name, dependency in dependencies do
	-- 			local realm = dependency.target or pesde_toml.target.environment
	-- 			if realm ~= "luau" then continue end
	-- 			local file =
	-- 				fs.readFile(path .. "/luau_packages/" .. name .. ".luau")
	-- 			local package_file = {
	-- 				`local main = require(script.Parent.Parent.Parent["{name}"])`,
	-- 			}

	-- 			for value in string.gmatch(file, "export type (.-) = module.") do
	-- 				local export_without_default =
	-- 					string.gsub(value, "=.->", ">")
	-- 				table.insert(
	-- 					package_file,
	-- 					`export type {value} = main.{export_without_default}`
	-- 				)
	-- 			end

	-- 			table.insert(package_file, "return main")
	-- 			luau_packages[name] = table.concat(package_file, "\n")
	-- 		end
	-- 	end
	-- end

	-- fs.removeDir(path .. "/dist")
	-- fs.removeFile(path .. "/default.project.json")
	-- fs.removeFile(path .. "/wally.toml")

	fs.writeDir(path .. "/dist")
	fs.writeDir(path .. "/dist/roblox_packages")
	fs.writeDir(path .. "/dist/luau_packages")

	for name, package in roblox_packages do
		fs.writeFile(
			path .. "/dist/roblox_packages/" .. name .. ".luau",
			package
		)
	end

	-- for name, package in luau_packages do
	-- 	fs.writeFile(path .. "/dist/luau_packages/" .. name .. ".luau", package)
	-- end

	fs.copy(path .. "/src", path .. "/dist/src", true)
	fs.writeFile(path .. "/dist/lib.luau", lib_file_src)
	fs.writeFile(path .. "/dist/init.luau", init_file_src)

	local package_name = string.split(pesde_toml.name, "/")[2]
	fs.writeFile(
		path .. "/default.project.json",
		`\{\n\t"name": "{fix(package_name)}",\n\t"tree": \{\n\t\t"$path": "dist"\n\t}\n}`
	)

	-- fs.writeFile(path .. "/wally.toml", serde.encode("toml", wally_toml, true))
end

type SortItem = {
	name: string,
	path: string,
	dependencies: { [string]: PesdeDependency }?,
}

local function get_order()
	local packages = fs.readDir "./pkgs"
	local package_dependencies: { SortItem } = {}
	local mapped: { [string]: PesdeToml } = {}

	for index, package in packages do
		if package:find "_foreign" then continue end
		local path = "./pkgs/" .. package
		local file = fs.readFile(path .. "/pesde.toml")
		local pesde_toml: PesdeToml = serde.decode("toml", file)

		mapped[pesde_toml.name] = pesde_toml
		package_dependencies[index] = {
			name = pesde_toml.name,
			path = path,
			dependencies = pesde_toml.dependencies,
		}
	end

	-- check if a relies on b
	local function flatten_dependencies(
		dependencies: { [string]: PesdeDependency }
	)
		local flat = {}

		for name, dependency in dependencies do
			if dependency.workspace then
				local toml = mapped[dependency.workspace]
				if toml.dependencies == nil then continue end
				for name in flatten_dependencies(toml.dependencies) do
					flat[name] = true
				end
			elseif not dependency.wally then
				error(`bad dependency {name}`)
			end

			flat[dependency.workspace or dependency.wally] = true
		end

		return flat
	end

	local function relies_on(a: SortItem, b: SortItem)
		if a.dependencies == nil then return false end
		local flattened = flatten_dependencies(a.dependencies)
		return flattened[b.name] or false
	end

	table.sort(package_dependencies, function(a: SortItem, b: SortItem)
		if a.dependencies == nil and b.dependencies == nil then
			return a.name > b.name
		end
		if a.dependencies == nil then return true end
		if b.dependencies == nil then return false end

		if relies_on(a, b) then return false end
		if relies_on(b, a) then return true end

		return a.name > b.name
	end)

	local order = {}

	for index, item in package_dependencies do
		order[index] = item.path
	end

	return order
end

local function cleanup_files(path: string)
	if fs.isDir(path .. "/dist") == false then return end

	pcall(fs.removeDir, path .. "/dist")
	pcall(fs.removeFile, path .. "/wally.toml")
	pcall(fs.removeFile, path .. "/default.project.json")
end

for _, path in get_order() do
	local file = fs.readFile(path .. "/pesde.toml")
	local pesde_toml: PesdeToml = serde.decode("toml", file)
	scanned_tomls[pesde_toml.name] = pesde_toml
end

process.spawn("pesde", { "i" })

for _, path in get_order() do
	print("Generating release for", path)
	generate_wally_release_files(path)
	local status = process.spawn("wally", { "publish" }, {
		cwd = path,
		env = {},
		shell = true,
	})
	cleanup_files(path)
	if status.ok == false then error(status.stderr) end

	-- link_npm_files(path)
	-- local status = process.spawn("pnpm", { "publish", "--access=public" }, {
	-- 	cwd = path,
	-- 	env = {},
	-- 	shell = true,
	-- })
	cleanup_files(path)
end
