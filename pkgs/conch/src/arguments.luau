local Players = game:GetService "Players"

local context = require "./context"
local language = require "../roblox_packages/language"
local types = require "./types"

local function noop(v: unknown): any return v end

local function wrap_if_not(value)
	return if type(value) == "table" then value else { value }
end

local function obtain_type_name(type: language.Type)
	if type.kind == "command" then
		return "Command"
	elseif type.kind == "function" then
		return "Function"
	elseif type.kind == "intersection" then
		local fields = {}

		for _, t in type.fields do
			table.insert(fields, obtain_type_name(t))
		end

		return table.concat(fields, " & ")
	elseif type.kind == "literal" then
		return tostring(type.value)
	elseif type.kind == "strange" then
		return type.type
	elseif type.kind == "union" then
		local fields = {}

		for _, t in type.fields do
			table.insert(fields, obtain_type_name(t))
		end

		return table.concat(fields, " | ")
	elseif type.kind == "table" then
		local keys = {}

		if type.fields then
			for key, value in type.fields do
				table.insert(
					keys,
					`{obtain_type_name(key)} = {obtain_type_name(value)}`
				)
			end
		end

		if type.indexer and type.value then
			table.insert(
				keys,
				`[{obtain_type_name(type.indexer)}] = {obtain_type_name(
					type.value
				)}`
			)
		end

		return `\{ {table.concat(keys, ", ")} \}`
	end

	return "error"
end

local stored_types = {}

--[=[
Given a identifier, registers a strange type for it.

Strange types are a mechanism for conch to support types that do not normally
exist within conch as a runtime.
]=]
local function register_strange_type<T>(p: {
	read type: string,
	read id: string,

	read convert: ((unknown) -> T)?,

	read suggestions: language.Type | ((string) -> { language.Suggestion })?,
	read match: language.Type | ((unknown) -> boolean)?,
}): language.StrangeType
	local strange_type: language.StrangeType = {
		kind = "strange",
		type = p.type,
		id = p.id,

		convert = p.convert,

		suggestions = p.suggestions,
		match = p.match,
	}

	stored_types[p.id] = strange_type

	return strange_type
end

--[=[
Given an analysis type, turns it into a function that can be exported

This returns a table matching the CommandArgument type, which is not exposed.
It first attempts to auto-generate a name for the given type, but can be replaced
with a custom one if desirable.

note: it's atm not possible to typecheck this properly; please manually typecast it
]=]
local function wrap_type<T>(
	type: language.Type?,
	name: string?,
	description: string?
): types.TypeRegistrator<T>
	local default_name = type and obtain_type_name(type) or "unknown"

	local template = {
		kind = "argument",
		name = name or default_name,
		description = description or "",
		type = type,
		varargs = false,
	}

	return function(name: string?, description: string?)
		local copy = table.clone(template)

		copy.name = name or copy.name
		copy.description = description or copy.description

		return copy
	end
end

--[=[
Given a id, returns a strange type if registered.
]=]
local function get_strange_type(id: string): language.StrangeType?
	return stored_types[id]
end

--[=[
Given a list of dynamic options, generates an enum type.
]=]
local function generate_dynamic_options<K, V>(
	id: string,
	fn: () -> { [K]: V },
	name: string?,
	description: string?
): types.TypeRegistrator<V>
	local strange_type = register_strange_type {
		type = name or "enum",
		id = `__enum_{id}`,

		convert = function(key: unknown)
			local value = fn()[key]

			if value == nil then
				return error(
					`could not convert "{tostring(key)}" into a valid option`
				)
			else
				return value
			end
		end,
		match = function(key: unknown)
			local fn_key = next(fn())
			print(typeof(key), typeof(fn_key))

			if fn_key == nil then return false end
			return typeof(key) == typeof(fn_key)
		end,
		suggestions = function(v)
			local suggestions: { language.Suggestion } = {}

			for key, value in fn() do
				table.insert(suggestions, {
					text = key,
					display = key,
					kind = nil,
					metadata = nil,
				})
			end

			return suggestions
		end,
	}

	return wrap_type(strange_type, name, description)
end

--[=[
Given a key map, generates an enum type
]=]
local function enum_from_map<T>(
	id: string,
	t: { [string]: T },
	name: string?,
	description: string?
): types.TypeRegistrator<T>
	return generate_dynamic_options(
		id,
		function() return t end,
		name,
		description
	)
end

--[=[
Given a array, generates an enum type
]=]
local function enum_from_array<T>(
	id: string,
	t: { T },
	name: string?,
	description: string?
): types.TypeRegistrator<T>
	return generate_dynamic_options(id, function()
		local key_map = {}

		for _, value in t do
			key_map[value] = value
			key_map[tostring(value)] = value
		end

		return key_map
	end, name, description)
end

-- base types

local any_type = register_strange_type {
	type = "any",
	id = "__any_base",

	convert = nil,
	match = nil,
	suggestions = nil,
}

local number_type = register_strange_type {
	type = "number",
	id = "__number_base",

	convert = function(x: unknown)
		local value = tonumber(x)
		if not value then error(`could not convert "{x}" to a number`) end
		return value
	end,
	match = function(x: unknown) return type(x) == "number" end,

	suggestions = nil,
}

local string_type = register_strange_type {
	type = "string",
	id = "__string_base",

	convert = function(x: unknown)
		local value = tostring(x)
		if not value then error(`could not convert "{x}" to a string`) end
		return value
	end,
	match = function(x: unknown) return type(x) == "string" end,

	suggestions = nil,
}

local boolean_type = register_strange_type {
	type = "boolean",
	id = "__boolean_base",

	convert = function(x: unknown): boolean
		if typeof(x) == "number" then
			return x ~= 0
		elseif typeof(x) == "boolean" then
			return x
		else
			return not not x
		end
	end,
	match = function(x: unknown) return type(x) == "boolean" end,

	suggestions = function(): { language.Suggestion }
		return {
			{
				kind = "expression",
				text = "true",
				display = "true",
				metadata = nil,
			},
			{
				kind = "expression",
				text = "false",
				display = "false",
				metadata = nil,
			},
		}
	end,
}

local vector_type = register_strange_type {
	type = "vector",
	id = "__vector_base",

	convert = function(v: unknown): vector
		if type(v) == "vector" then
			return v
		elseif typeof(v) == "table" then
			local x, y, z = rawget(v, 1), rawget(v, 2), rawget(v, 3)

			if
				typeof(x) == "number"
				and typeof(y) == "number"
				and (typeof(z) == "number" or z == nil)
			then
				return vector.create(x or 0, y or 0, z or 0)
			end

			error(`could not convert "{typeof(v)}" into vector`)
		else
			error(`could not convert "{typeof(v)}" into vector`)
		end
	end,
	match = function(v: unknown)
		if type(v) == "vector" then
			return true
		elseif typeof(v) == "table" then
			local x, y, z = rawget(v, 1), rawget(v, 2), rawget(v, 3)

			if
				typeof(x) == "number"
				and typeof(y) == "number"
				and (typeof(z) == "number" or z == nil)
			then
				return true
			end
		end

		return false
	end,

	suggestions = function(): { language.Suggestion }
		return {
			{
				kind = "expression",
				text = "true",
				display = "true",
				metadata = nil,
			},
			{
				kind = "expression",
				text = "false",
				display = "false",
				metadata = nil,
			},
		}
	end,
}

local player_type = register_strange_type {
	type = "player",
	id = "__player_base",

	convert = function(arg: unknown): Player
		local ctx = context.get_command_context()
		if arg == "@s" then
			return ctx and ctx.executor.player
				or error "not executed by a player"
		elseif typeof(arg) == "number" then
			local player = assert(
				Players:GetPlayerByUserId(arg),
				`player with id {arg} is not in this server`
			)
			return player
		elseif typeof(arg) == "string" then
			local player = assert(
				Players:FindFirstChild(arg) :: Player,
				`player "{arg}" is not valid`
			)
			return player
		elseif typeof(arg) == "Instance" and arg:IsA "Player" then
			return arg
		else
			error(`unknown arg {arg}`)
		end
	end,

	match = function(arg: unknown): boolean
		if typeof(arg) == "number" then
			return true
		elseif typeof(arg) == "string" then
			return true
		elseif typeof(arg) == "Instance" and arg:IsA "Player" then
			return true
		else
			return false
		end
	end,

	suggestions = function(value): { language.Suggestion }
		local suggestions: { language.Suggestion } = {}
		print(value)

		table.insert(suggestions, {
			kind = nil,
			metadata = {
				name = "self",
				description = "Refers to yourself",
			},
			text = "@s",
			display = "@s (self)",
		})

		for _, player in Players:GetPlayers() do
			table.insert(suggestions, {
				kind = nil,
				metadata = nil,
				text = player.Name,
				display = `{player.DisplayName} (@{player.Name})`,
			})
		end

		return suggestions
	end,
}

-- pluralize

--[=[
Automatically converts a type into a plural form, optionally accepting
additional type information.
]=]
local function pluralize<T>(
	type: language.StrangeType,
	additional: {
		suggestions: language.Type | ((unknown) -> { language.Suggestion })?,
		match: ((unknown) -> boolean)?,
		convert: ((unknown) -> T)?,
	}?
): language.Type
	local additional_type

	local native_type = register_strange_type {
		type = `{type.type}s`,
		id = `__pluralize_{type.id}_native`,

		convert = if type.convert
			then function(value: unknown): unknown
				if typeof(value) == "table" then
					local copy = {}
					for idx, value in ipairs(value :: any) do
						copy[idx] = type.convert(value)
					end
					return copy
				else
					return { type.convert(value) }
				end
			end
			else nil,
		match = {
			kind = "union",
			fields = {
				type,
				{
					kind = "table",
					indexer = number_type,
					value = type,
				},
			},
		} :: language.UnionType,
		suggestions = {
			kind = "union",
			fields = {
				type,
				{
					kind = "table",
					indexer = number_type,
					value = type,
				},
			},
		} :: language.UnionType,
	}

	if additional then
		additional_type = register_strange_type {
			type = `{type.type}s`,
			id = `__pluralize_{type.id}`,

			convert = additional.convert,
			match = additional.match,
			suggestions = additional.suggestions,
		}
	end

	return if additional_type
		then {
			kind = "union",
			fields = {
				if additional_type then additional_type else nil :: any,
				native_type,
			},
		}
		else native_type
end

local numbers_type = pluralize(number_type)
local strings_type = pluralize(string_type)
local booleans_type = pluralize(boolean_type)
local vectors_type = pluralize(vector_type)

local players_type = pluralize(player_type, {
	convert = function(v: unknown)
		if v == "@a" then
			return Players:GetPlayers()
		else
			error(`could not convert "{typeof(v)}" into players`)
		end
	end,

	suggestions = function(v: unknown): { language.Suggestion }
		return {
			{
				kind = nil,
				metadata = {
					name = "all players",
					description = "Refers to all players in the server",
				},
				text = "@a",
				display = "@a (all)",
			},
		}
	end,

	match = function(v: unknown) return typeof(v) == "string" end,
})

-- modifiers

local function opt<T>(arg: T): T
	local type = arg :: language.CommandArgument

	return {
		kind = type.kind,
		name = type.name,
		description = type.description,
		type = {
			kind = "union" :: "union",
			fields = {
				{
					kind = "literal" :: "literal",
					value = nil,
				},
				type.type :: language.Type,
			},
		},
		varargs = type.varargs,
	}
end

local function variadic<T>(arg: T): ...T
	local type = arg :: language.CommandArgument

	return {
		kind = type.kind,
		name = type.name,
		description = type.description,
		type = type.type,
		varargs = true,
	}
end

type function GenStruct(t: type, indexer: type, value: type)
	if indexer.tag == "generic" or value.tag == "generic" then return t end
	t:setindexer(indexer, value)
	return t
end

--[=[
Given a table, creates a type that requires it to match the table
]=]
local function struct<T, Indexer, Value>(input: T, indexer: Indexer?, value: Value?): GenStruct<T, Indexer, Value>
	local fields: { [language.LiteralType]: language.Type } = {}

	for key: any, value: any in pairs(input) do
		if value.kind == "argument" then
			value = value.type
		end
		
		if key.kind == "argument" then
			key = key.type
		end
		
		fields[{
			kind = "literal",
			value = key
		} :: any] = value  :: any
	end
	
	local table_type: language.TableType = {
		kind = "table",
		
		fields = fields,
		indexer = if indexer and indexer.kind == "argument" then indexer.type else indexer,
		value = if value and value.kind == "argument" then value.type else indexer
	}

	return {
		kind = "argument",
		name = "table",
		description = "",

		type = table_type,
		varargs = false
	} :: any
end

local args = {
	any = wrap_type(any_type, "any"),
	number = wrap_type(number_type, "number"),
	string = wrap_type(string_type, "string"),
	boolean = wrap_type(boolean_type, "boolean"),
	vector = wrap_type(vector_type, "vector"),

	player = wrap_type(player_type, "player"),
	players = wrap_type(players_type, "players"),

	enum_from_array = enum_from_array,
	enum_from_map = enum_from_map,

	opt = opt,
	variadic = variadic,

	struct = struct
}

return {
	wrap_type = wrap_type,
	register_strange_type = register_strange_type,
	get_strange_type = get_strange_type,
	pluralize = pluralize,
	obtain_type_name = obtain_type_name,

	type = {
		any = any_type,
		number = number_type,
		string = string_type,
		boolean = boolean_type,
		vector = vector_type,
		player = player_type,

		numbers = numbers_type,
		strings = strings_type,
		booleans = booleans_type,
		vectors = vectors_type,
		players = players_type,
	},

	args = args,
}
