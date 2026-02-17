local Players = game:GetService "Players"

local context = require "./context"
local language = require "../roblox_packages/language"
local types = require "./types"

local function noop(v: unknown): any return v end

local function wrap_if_not(value)
	return if type(value) == "table" then value else { value }
end

local function normalize_type(type: language.Type | language.CommandArgument)
	if type.kind == "argument" then
		return type.type
	else
		return type
	end
end

local function obtain_type_name(type: language.Type | language.CommandArgument)
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
	elseif type.kind == "argument" then
		return type.name
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
	read exact_match: language.Type | ((unknown) -> boolean)?,
}): language.StrangeType
	local strange_type: language.StrangeType = {
		kind = "strange",
		type = p.type,
		id = p.id,

		convert = p.convert,

		suggestions = p.suggestions,
		match = p.match,
		exact_match = p.exact_match,
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
					`could not convert "{tostring(key)}" into a valid option, expected something like {(next(
						fn()
					))}`
				)
			else
				return value
			end
		end,
		match = function(key: unknown)
			local fn_key = next(fn())

			if fn_key == nil then return false end
			return typeof(key) == typeof(fn_key)
		end,
		suggestions = function(v)
			local suggestions: { language.Suggestion } = {}

			for key, value in fn() do
				table.insert(suggestions, {
					text = tostring(key),
					display = tostring(key),
					kind = nil,
					metadata = nil,
				})
			end

			return suggestions
		end,
		exact_match = function(key) return fn()[key] ~= nil end,
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
	exact_match = nil,
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
	exact_match = nil,

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
	exact_match = nil,

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
	exact_match = nil,

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
	exact_match = nil,

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
	exact_match = function(arg: unknown): boolean
		if arg == "@s" then
			return true
		elseif typeof(arg) == "number" then
			return Players:GetPlayerByUserId(arg) ~= nil
		elseif typeof(arg) == "string" then
			return Players:FindFirstChild(arg) ~= nil
		elseif typeof(arg) == "Instance" and arg:IsA "Player" then
			return true
		else
			return false
		end
	end,

	suggestions = function(value): { language.Suggestion }
		local suggestions: { language.Suggestion } = {}

		table.insert(suggestions, {
			kind = nil,
			metadata = {
				name = "self",
				description = "Refers to yourself",
				type = "player"
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

local userid_type = register_strange_type {
	type = "userid",
	id = "__userid_base",
	convert = function(arg: unknown)
		local ctx = context.get_command_context()
		if arg == "@s" then
			return ctx and ctx.executor.player and ctx.executor.player.UserId
				or error "not executed by a player"
		elseif typeof(arg) == "number" then
			return arg
		elseif typeof(arg) == "string" then
			local player = Players:FindFirstChild(arg) :: Player?
			local userid = if player
				then player.UserId
				else Players:GetUserIdFromNameAsync(arg)
			return userid
		elseif typeof(arg) == "Instance" and arg:IsA "Player" then
			return arg.UserId
		else
			error(`unknown arg {arg}`)
		end
	end,

	match = function(n: unknown)
		return typeof(n) == "number"
			or typeof(n) == "Instance" and n:IsA "Player"
			or typeof(n) == "string"
	end,
	exact_match = function(arg: unknown): boolean
		if arg == "@s" then
			return true
		elseif typeof(arg) == "number" then
			return true
		elseif typeof(arg) == "string" then
			return true -- sorry we are not checking
		elseif typeof(arg) == "Instance" and arg:IsA "Player" then
			return true
		else
			return false
		end
	end,

	suggestions = function(value): { language.Suggestion }
		local suggestions: { language.Suggestion } = {}

		table.insert(suggestions, {
			kind = nil,
			metadata = {
				name = "self",
				description = "Refers to yourself",
				type = "player"
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

local color_type = register_strange_type {
	type = "Color3",
	id = "__color3_base",
	convert = function(value: unknown)
		return if type(value) == "vector"
			then Color3.fromRGB(value.x, value.y, value.z)
			elseif typeof(value) == "string" then Color3.fromHex(value)
			elseif
				typeof(value) == "table"
				and typeof(value[1]) == "number"
				and typeof(value[2]) == "number"
				and typeof(value[3]) == "number"
			then Color3.fromRGB(value.x, value.y, value.z)
			else error(`could not convert "{typeof(value)}" into Color3`)
	end,

	match = function(t: unknown)
		return if type(t) == "vector"
			then true
			elseif typeof(t) == "string" then true
			elseif typeof(t) == "table" and typeof(t[1]) == "number" and typeof(
				t[2]
			) == "number" and typeof(t[3]) == "number" then true
			else false
	end,
	exact_match = nil,

	suggestions = nil,
}

local DURATION_TIMES: { [string]: number } = {
	ms = 1e-3,
	milisecond = 1e-3,
	miliseconds = 1e-3,

	s = 1,
	sec = 1,
	second = 1,
	seconds = 1,

	min = 60,
	minute = 60,
	minutes = 60,

	hr = 60 * 60,
	hour = 60 * 60,
	hours = 60 * 60,

	d = 60 * 60 * 24,
	day = 60 * 60 * 24,
	days = 60 * 60 * 24,

	wk = 60 * 60 * 24 * 7,
	week = 60 * 60 * 24 * 7,
	weeks = 60 * 60 * 24 * 7,

	mo = 60 * 60 * 24 * 30,
	month = 60 * 60 * 24 * 30,
	months = 60 * 60 * 24 * 30,

	y = 60 * 60 * 24 * 365,
	yr = 60 * 60 * 24 * 365,
	year = 60 * 60 * 24 * 365,
	years = 60 * 60 * 24 * 365,
}

local function parse_duration(text: unknown)
	if typeof(text) ~= "string" then error "cannot parse non string" end

	local words = string.split(text, " ")
	local n = 0

	for _, word in words do
		local duration_string, suffix = string.match(word, `(.-)[%s]?([A-z]+)$`)
		if duration_string and suffix then
			local mul = DURATION_TIMES[suffix]
			if not mul then error(`"{mul}" is not a valid suffix`, 0) end
			local duration = tonumber(duration_string)
			if not duration then
				error(`could not convert "{word}" into a duration`, 0)
			end
			n += duration * mul
		else
			local duration = tonumber(word)
			if not duration then
				error(`could not convert "{word}" into a duration`, 0)
			end
			n += duration
		end
	end

	return n
end

local duration_type = register_strange_type {
	type = "number",
	id = "__duration_base",

	convert = function(n: unknown): number
		return if typeof(n) == "number" then n else parse_duration(n)
	end,

	match = function(value)
		return typeof(value) == "string" or typeof(value) == "number"
	end,

	suggestions = function(text: string)
		local words = string.split(text:gsub(`"(.*)"`, "%1"), " ")
		local last_word = words[#words] or "1"

		local suggestions: { language.Suggestion } = {}
		local the_rest = table.concat(words, " ", 1, #words - 1)
		local before, suffix = string.match(last_word, "(.-)([A-z]+)$")

		if suffix then
			for example_suffix in DURATION_TIMES do
				table.insert(suggestions, {
					text = `{before}{example_suffix}`,
					display = `{before}{example_suffix}`,
				})
			end
		else
			for example_suffix in DURATION_TIMES do
				table.insert(suggestions, {
					text = `{last_word}{example_suffix}`,
					display = `{last_word}{example_suffix}`,
				})
			end
		end

		the_rest = if #the_rest > 0 then `{the_rest} ` else the_rest
		for idx, s in suggestions do
			suggestions[idx] = {
				text = `{the_rest}{s.text}`,
				display = `{the_rest}{s.display}`,
			}
		end

		return suggestions
	end,
	exact_match = nil,
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
		match: language.Type | ((unknown) -> boolean)?,
		exact_match: language.Type | ((unknown) -> boolean)?,
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
		exact_match = nil,
	}

	if additional then
		additional_type = register_strange_type {
			type = `{type.type}s`,
			id = `__pluralize_{type.id}`,

			convert = additional.convert,
			match = additional.match,
			suggestions = additional.suggestions,
			exact_match = additional.exact_match,
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
		elseif v == "@o" then
			local ctx = context.get_command_context()
			if not ctx or not ctx.executor.player then return Players:GetPlayers() end

			local players = Players:GetPlayers()
			table.remove(players, table.find(players, ctx.executor.player))
			return players
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
					type = "players"
				},
				text = "@a",
				display = "@a (all)",
			},
			{
				kind = nil,
				metadata = {
					name = "other players",
					description = "Refers to all players except you in the server",
					type = "players"
				},
				text = "@o",
				display = "@o (others)",
			},
		}
	end,

	match = function(v: unknown) return typeof(v) == "string" end,
	exact_match = function(v: unknown) return v == "@a" or v == "@o" end,
})

local userids_type = pluralize(userid_type, {
	convert = function(v: unknown)
		if v == "@a" then
			local players = Players:GetPlayers()
			local users = {}

			for _, user in players do
				table.insert(users, user.UserId)
			end

			return users
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
					type = "players"
				},
				text = "@a",
				display = "@a (all)",
			},
		}
	end,

	match = function(v: unknown) return typeof(v) == "string" end,
	exact_match = function(v: unknown) return v == "@a" end,
})

local colors_type = pluralize(color_type)

-- modifiers

local function literal<T>(value: T): T
	return {
		kind = "literal",
		value = value,
	}
end

local function opt<T>(arg: T): T
	local type = arg :: language.CommandArgument

	return {
		kind = "argument",
		name = type.name or obtain_type_name(type),
		description = type.description or obtain_type_name(type),
		type = {
			kind = "union" :: "union",
			fields = {
				{
					kind = "literal" :: "literal",
					value = nil,
				},
				type.type or type :: language.Type,
			},
		},
		varargs = type.varargs,
	}
end

local function variadic<T>(arg: T): ...T
	local type = arg :: language.CommandArgument

	return {
		kind = "argument",
		name = type.name or obtain_type_name(type),
		description = type.description or obtain_type_name(type),
		type = type.type or type,
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
local function struct<T, Indexer, Value>(
	input: T,
	indexer: Indexer?,
	value: Value?
): GenStruct<T, Indexer, Value>
	local fields: { [language.LiteralType]: language.Type } = {}

	for key: any, value: any in pairs(input) do
		if value.kind == "argument" then value = value.type end

		if key.kind == "argument" then key = key.type end

		fields[{
			kind = "literal",
			value = key,
		} :: any] = value :: any
	end

	local table_type: language.TableType = {
		kind = "table",

		fields = fields,
		indexer = if indexer and indexer.kind == "argument"
			then indexer.type
			else indexer,
		value = if value and value.kind == "argument"
			then value.type
			else indexer,
	}

	return table_type
end

local union = function(...)
	local fields = { ... }

	for i, field in fields do
		fields[i] = normalize_type(field)
	end

	return {
		kind = "union",
		fields = fields,
	}
end :: & (<A>(A) -> A) & (<A, B>(A, B) -> A | B) & (<A, B, C>(A, B, C) -> A | B | C) & (<A, B, C, D>(A, B, C, D) -> A | B | C | D) & (<A, B, C, D, E>(
	A,
	B,
	C,
	D,
	E
) -> A | B | C | D | E)

local intersect = function<T...>(...: T...)
	local fields = { ... }

	for i, field in fields do
		fields[i] = normalize_type(field)
	end

	return {
		kind = "intersect",
		fields = fields,
	}
end :: & (<A>(A) -> A) & (<A, B>(A, B) -> A & B) & (<A, B, C>(A, B, C) -> A & B & C) & (<A, B, C, D>(A, B, C, D) -> A & B & C & D) & (<A, B, C, D, E>(
	A,
	B,
	C,
	D,
	E
) -> A & B & C & D & E)

export type Overload = {
	kind: "overload",
	overloads: { { any } },
}

local function overload<T>(p: { { any } }): ...any
	return {
		kind = "overload",
		overloads = p,
	}
end

local args = {
	any = wrap_type(any_type, "any") :: types.TypeRegistrator<any>,
	number = wrap_type(number_type, "number") :: types.TypeRegistrator<number>,
	string = wrap_type(string_type, "string") :: types.TypeRegistrator<string>,
	boolean = wrap_type(boolean_type, "boolean") :: types.TypeRegistrator<boolean>,
	vector = wrap_type(vector_type, "vector") :: types.TypeRegistrator<vector>,

	color = wrap_type(color_type, "Color3") :: types.TypeRegistrator<Color3>,
	colors = wrap_type(colors_type, "Color3s") :: types.TypeRegistrator<{Color3}>,

	userid = wrap_type(userid_type, "UserId") :: types.TypeRegistrator<number>,
	userids = wrap_type(userids_type, "UserIds") :: types.TypeRegistrator<{number}>,

	duration = wrap_type(duration_type, "duration") :: types.TypeRegistrator<number>,

	player = wrap_type(player_type, "player") :: types.TypeRegistrator<Player>,
	players = wrap_type(players_type, "players") :: types.TypeRegistrator<{Player}>,
	
	numbers = wrap_type(numbers_type, "numbers") :: types.TypeRegistrator<{number}>,
	strings = wrap_type(strings_type, "strings") :: types.TypeRegistrator<{string}>,
	booleans = wrap_type(booleans_type, "booleans") :: types.TypeRegistrator<{boolean}>,
	vectors = wrap_type(vectors_type, "vectors") :: types.TypeRegistrator<{vector}>,

	enum_from_array = enum_from_array,
	enum_from_map = enum_from_map,

	opt = opt,
	variadic = variadic,

	struct = struct,

	literal = literal,

	union = union,
	intersect = intersect,

	overload = overload,

	dynamic = generate_dynamic_options
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

		color = color_type,
		colors = colors_type,

		userid = userid_type,
		userids = userids_type,

		duration = duration_type,

		numbers = numbers_type,
		strings = strings_type,
		booleans = booleans_type,
		vectors = vectors_type,
		players = players_type,
	},

	args = args,
}
