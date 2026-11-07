const fs = require "@std/fs"
const path = require "@std/path"
const toml = require "@vendor/toml"

export type GitDependency = {
	remote: string,
	branch: string,
	commit: string,
	from_path: string?,
}
export type PathDependency = {
	from_path: string,
	remote: nil,
	branch: nil,
	commit: nil,
}

export type Dependency = GitDependency | PathDependency

export type Identity =
	{
		name: string,
		monorepo: false?,
		entry_point: string | false,

		dependency: { [string]: Dependency },
	}
	| {
		name: string,
		monorepo: true,

		-- location of all the packages
		packages: string,
	}

const manifest = {}

function manifest.read(location: path.Pathlike)
	const file_contents = fs.readFileToString(location)
	const configuration = toml.deserialize(file_contents)

	-- guarantee it to be empty just because it's a real pain in the fucking ass for it to be nullable
	if not configuration.dependency then configuration.dependency = {} end

	return manifest.validate(configuration)
end

function manifest.get_pkg_manifest(dependency: string): Identity
	return manifest.read(path.parse(`pkgs/_index/{dependency}/ayapkg.toml`))
end

function manifest.validate(input: any): Identity
	assert(type(input) == "table", "input must be a table")

	for _, value in input.dependency do
		if value.from_path then
			assert(type(value.from_path) == "string", "from_path")
			assert(type(value.commit) == "nil", "commit")
			assert(type(value.remote) == "nil", "remote")
			assert(type(value.branch) == "nil", "branch")
		else
			assert(type(value.commit) == "string", "commit")
			assert(type(value.remote) == "string", "remote")
			assert(type(value.branch) == "string", "branch")
			assert(type(value.from_path) == "nil", "from_path")
		end
	end

	return input
end

function manifest.write(input: Identity, loc: path.Path)
	fs.writeStringToFile(loc, toml.serialize(input :: any))
end

return manifest
