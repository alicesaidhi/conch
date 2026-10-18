--[[
builds the npm packages for roblox-ts and publishes them

lune run release_npm            publishes to npm
lune run release_npm dry        runs pnpm publish --dry-run
lune run release_npm pack <dir> writes the tarballs to <dir> instead

each package is laid out as:

dist/
	roblox_packages/
		...one module per dependency
	src/
		...files
	init.luau
	lib.luau

]]

local fs = require "@lune/fs"
local process = require "@lune/process"
local serde = require "@lune/serde"

type PesdeToml = {
	name: string,
	version: string,
	target: { lib: string? },
	dependencies: {
		[string]: {
			workspace: string?,
			wally: string?,
			target: string?,
		},
	}?,
}

-- dependencies before the packages that use them
local PACKAGES = { "conch_language", "conch", "conch_ui" }

-- the folder inside the npm package that holds the dependency's luau
local ENTRY_FOLDER = { vide = "src" }

local mode = process.args[1]

local function npm_name(target: string): string
	local name = string.split(target, "/")[2]
	return (string.gsub(name, "_", "-"))
end

--[=[
The dependency is found the same way roblox-ts finds packages, by walking up
to the nearest node_modules. It does not go through the roblox-ts runtime, so
it works no matter how the package that needs it was loaded.
]=]
local function dependency_module(name: string): string
	local folder = ENTRY_FOLDER[name] or "dist"

	return table.concat({
		"local object = script",
		"repeat",
		`	local scope = object:FindFirstChild "node_modules"`,
		`	scope = scope and scope:FindFirstChild "@rbxts"`,
		`	local package = scope and scope:FindFirstChild "{name}"`,
		`	if package then return require(package:WaitForChild "{folder}") end`,
		"	object = object.Parent",
		"until object == nil",
		"",
		`error "could not find @rbxts/{name}"`,
		"",
	}, "\n")
end

local function build(path: string)
	local pesde_toml: PesdeToml =
		serde.decode("toml", fs.readFile(path .. "/pesde.toml"))
	local package_json =
		serde.decode("json", fs.readFile(path .. "/package.json"))

	assert(
		package_json.version == pesde_toml.version,
		`{path}: package.json is on {package_json.version} but pesde.toml is on {pesde_toml.version}`
	)

	local lib_path = assert(pesde_toml.target.lib, `{path}: no lib file`)
	local lib_file = fs.readFile(path .. "/" .. lib_path)

	local init_file = { "local main = require(script.lib)" }
	for value in string.gmatch(lib_file, "export type(%b  )= ") do
		table.insert(
			init_file,
			`export type{value}= main.{value:gsub("=[A-z%.]-", "")}`
		)
	end
	table.insert(init_file, "return main")

	fs.writeDir(path .. "/dist/roblox_packages")
	fs.copy(path .. "/src", path .. "/dist/src", true)
	fs.writeFile(path .. "/dist/lib.luau", `return require("./src")\n`)
	fs.writeFile(
		path .. "/dist/init.luau",
		table.concat(init_file, "\n") .. "\n"
	)

	for name, dependency in pesde_toml.dependencies or {} do
		if dependency.target and dependency.target ~= "roblox" then continue end
		local target = assert(
			dependency.workspace or dependency.wally,
			`bad dependency {name}`
		)

		fs.writeFile(
			path .. "/dist/roblox_packages/" .. name .. ".luau",
			dependency_module(npm_name(target))
		)
	end
end

local function publish(path: string)
	local args = { "publish", "--access=public", "--no-git-checks" }
	if mode == "dry" then
		table.insert(args, "--dry-run")
	elseif mode == "pack" then
		args =
			{ "pack", "--pack-destination", assert(process.args[2], "no dir") }
	end

	local status = process.spawn("pnpm", args, {
		cwd = path,
		shell = true,
		stdio = "inherit",
	})
	if not status.ok then error(`{path}: pnpm {args[1]} failed`) end
end

local ok, err = pcall(function()
	for _, package in PACKAGES do
		local path = "pkgs/" .. package
		print("building", path)
		build(path)
		publish(path)
	end
end)

for _, package in PACKAGES do
	pcall(fs.removeDir, "pkgs/" .. package .. "/dist")
end

if not ok then error(err, 0) end
