local Players = game:GetService "Players"

local console = require "./console"
local context = require "./context"
local language = require "../roblox_packages/language"
local types = require "./types"

local function noop(v: any) return v end

local function wrap_if_not(value)
	return if type(value) == "table" then value else { value }
end

local anyT = {
	convert = noop :: (any) -> any,

	analysis = {
		kind = "argument",
		optional = false,
		name = "any",
		type = "any",

		vararg = false,
	},
}

local stringT = {
	convert = tostring :: (string) -> string,

	analysis = {
		kind = "argument",
		optional = false,
		name = "string",
		type = "string",
	},
}

local stringsT = {
	convert = function(value)
		if typeof(value) == "table" then
			local copy = table.clone(value)
			for k, v in copy do
				copy[k] = tostring(v)
			end
			return copy
		else
			return { tostring(value) }
		end
	end,

	analysis = {
		kind = "argument",
		optional = false,
		name = "strings",
		type = "{ string }",
	},
}

local numberT = {
	convert = function(input)
		local n = tonumber(input)
		if n == nil then error(`{input} is not a valid number`) end
		return n
	end,

	analysis = {
		kind = "argument",
		optional = false,
		name = "number",
		type = "number",
	},
}

local numbersT = {
	convert = function(input)
		local input = wrap_if_not(input)
		local copy = {}
		for idx, value in input do
			local n = tonumber(input)
			if n == nil then error(`{input} is not a valid number`) end
			copy[idx] = n
		end
		return copy
	end,

	analysis = {
		kind = "argument",
		optional = false,
		vararg = false,
		name = "numbers",
		type = "{ number }",
	},
}

local booleanT = {
	convert = function(v: unknown)
		if typeof(v) == "boolean" then
			return v
		elseif typeof(v) == "number" and v > 0 then
			return true
		elseif typeof(v) == "number" and v <= 0 then
			return false
		else
			error(`{typeof(v)} is not a valid boolean`)
		end
	end,

	analysis = {
		kind = "argument",
		optional = false,
		vararg = false,
		name = "boolean",
		type = "boolean",

		suggestions = function()
			return {
				{ text = "true", display = "true" },
				{ text = "false", display = "false" },
			}
		end,
	},
}

local booleansT = {
	convert = function(value: unknown): { boolean }
		if typeof(value) == "table" then
			local copy = table.clone(value) :: { [any]: any }
			for k, v in copy do
				if typeof(v) == "boolean" then
					copy[k] = v
				elseif typeof(v) == "number" and v > 0 then
					copy[k] = true
				elseif typeof(v) == "number" and v <= 0 then
					copy[k] = false
				else
					error(`type {typeof(v)} of {k} is not a valid boolean`)
				end
			end
			return copy
		elseif typeof(value) == "boolean" then
			return { value }
		elseif typeof(value) == "number" and value > 0 then
			return { true }
		elseif typeof(value) == "number" and value <= 0 then
			return { false }
		else
			error(`{typeof(value)} is not a valid boolean`)
		end
	end,

	analysis = {
		kind = "argument",
		optional = false,
		vararg = false,
		name = "boolean",
		type = "{ boolean }",

		suggestions = function()
			return {
				{ text = "true", display = "true" },
				{ text = "false", display = "false" },
			}
		end,
	},
}

local tableT = {
	convert = noop,

	analysis = {
		kind = "argument",
		optional = false,
		name = "table",
		type = "table",
	},
}

local function into_vector(value: vector | Vector3 | { number }): vector
	if type(value) == "vector" then
		return value
	elseif typeof(value) == "table" then
		return vector.create(value[1] or 0, value[2] or 0, value[3] or 0)
	else
		error(`{value} is not valid`, 0)
	end
end

local vectorT = {
	convert = into_vector,

	analysis = {
		kind = "argument",
		optional = false,
		vararg = false,
		name = "vector",
		type = "vector",
	},
}
local vectorsT = {
	convert = function(
		value: vector | Vector3 | { vector | Vector3 | { number } }
	): { vector }
		if type(value) == "vector" then
			return { value }
		elseif typeof(value) == "table" then
			local t = {}
			for i, v in value do
				t[i] = into_vector(v)
			end
			return t
		else
			error(`{value} is not valid`, 0)
		end
	end,

	analysis = {
		kind = "argument",
		optional = false,
		vararg = false,
		name = "vector",
		type = "vector",
	},
}

--[=[
Generates a new enum that can be passed to conch.register_type. It maps each string in a table to a specific value.
]=]
local function enum_map<V>(
	map: { [string]: V },
	name: string?,
	description: string?
)
	return {
		convert = function(value): V
			local key = tostring(value)
			if map[key] == nil then error(`{key} is not valid`, 0) end
			return map[key]
		end,

		analysis = {
			kind = "argument",
			optional = false,
			vararg = false,
			name = name or "enum",
			description = description,
			type = name or "enum",
			suggestions = function()
				local suggestions = {}
				for key in map do
					table.insert(suggestions, { text = key, display = key })
				end
				return suggestions
			end,
		},
	}
end

--[=[
Generates a new enum that can be passed to conch.register_type
]=]
local function enum_new<T>(options: { T }, name: string?, description: string?)
	local map = {}

	for _, value in options do
		map[tostring(value)] = value
	end

	return enum_map(map, name, description)
end

local function convert_arg_to_player(
	arg: string | number | "@s" | Player
): Player
	local ctx = context.get_command_context()
	if arg == "@s" then
		return ctx and ctx.executor.player or error "not executed by a player"
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
end

local function convert_arg_to_players(
	arg: string | number | "@s" | "@a" | { any } | Player
)
	if arg == "@a" then
		return Players:GetPlayers()
	elseif typeof(arg) == "table" then
		local copy = table.clone(arg)

		for idx, plr in copy do
			copy[idx] = convert_arg_to_player(plr)
		end

		return copy
	else
		return { convert_arg_to_player(arg) }
	end
end

local playerT = {
	convert = function(player) return convert_arg_to_player(player) end,

	analysis = {
		kind = "argument",
		optional = false,
		vararg = false,
		name = "player",
		type = "Player",
		suggestions = function()
			local suggestions = {}

			for _, player in Players:GetPlayers() do
				table.insert(suggestions, {
					text = player.Name,
					display = `{player.DisplayName} (@{player.Name})`,
				})
			end

			return suggestions
		end,
	},
}

local playersT = {
	convert = function(players) return convert_arg_to_players(players) end,

	analysis = {
		kind = "argument",
		optional = false,
		name = "players",
		vararg = false,
		type = "players",
		suggestions = function(text: string)
			local suggestions = {}

			for _, player in Players:GetPlayers() do
				table.insert(suggestions, {
					text = player.Name,
					display = `{player.DisplayName} (@{player.Name})`,
				})
			end

			return suggestions
		end,
	},
}

local function convert_arg_to_userid(
	arg: string | number | Player | "@s"
): number
	local ctx = context.get_command_context()
	if arg == "@s" then
		return ctx and ctx.executor.player and ctx.executor.player.UserId
			or error "not executed by a player"
	elseif typeof(arg) == "number" then
		local ok, result = pcall(
			function() return Players:GetNameFromUserIdAsync(arg) end
		)

		if not ok and result:find "Unknown User" then
			error(`No user found with UserId {arg}`, 0)
		end

		return arg
	elseif typeof(arg) == "string" then
		local player = Players:FindFirstChild(arg)

		if not player then
			local ok, result = pcall(
				function() return Players:GetUserIdFromNameAsync(arg) end
			)

			if not ok and (result :: any):find "Unknown User" then
				error(`No user found with name {arg}`, 0)
			else
				error(`Could not fetch player name, try again later: {arg}`, 0)
			end

			return result
		end

		assert(player:IsA "Player")

		return player.UserId
	elseif typeof(arg) == "Instance" and arg:IsA "Player" then
		return arg.UserId
	else
		error(`unknown arg {arg}`, 0)
	end
end

local function convert_arg_to_userids(
	arg: string | number | "@s" | "@a" | { any }
)
	if arg == "@a" then arg = Players:GetPlayers() :: any end

	if typeof(arg) == "table" then
		local copy = {}

		for idx, plr in copy do
			copy[idx] = convert_arg_to_userid(plr)
		end

		return copy
	else
		return { convert_arg_to_userid(arg) }
	end
end

local useridT = {
	convert = function(player) return convert_arg_to_userid(player) end,

	analysis = {
		kind = "argument",
		optional = false,
		name = "userid",
		type = "number",
		vararg = false,
		suggestions = function()
			local suggestions = {}

			for _, player in Players:GetPlayers() do
				table.insert(suggestions, {
					text = player.Name,
					display = `{player.DisplayName} (@{player.Name})`,
				})
			end

			return suggestions
		end,
	},
}

local useridsT = {
	convert = function(players) return convert_arg_to_userids(players) end,

	analysis = {
		kind = "argument",
		optional = false,
		name = "userids",
		type = "{ number }",
		vararg = false,
		suggestions = function()
			local suggestions = {}

			for _, player in Players:GetPlayers() do
				print(player)
				table.insert(suggestions, {
					text = player.Name,
					display = `{player.DisplayName} (@{player.Name})`,
				})
			end

			return suggestions
		end,
	},
}

local color3T = {
	convert = function(color: Color3 | string | vector): Color3
		return if typeof(color) == "Color3"
			then color
			elseif typeof(color) == "string" then Color3.fromHex(color)
			elseif type(color) == "vector" then Color3.fromRGB(
				color.x,
				color.y,
				color.z
			)
			else error(`cannot convert {typeof(color)} into color3`, 0)
	end,

	analysis = {
		kind = "argument",
		optional = false,
		vararg = false,
		name = "Color3",
		type = "Color3",
	},
}

local color3sT = {
	convert = function(
		color: Color3 | string | vector | { Color3 | string | vector }
	): { Color3 }
		return if typeof(color) == "Color3"
			then color
			elseif typeof(color) == "string" then Color3.fromHex(color)
			elseif type(color) == "vector" then Color3.fromRGB(
				color.x,
				color.y,
				color.z
			)
			elseif typeof(color) == "table" then (function()
				local t = {}

				for idx, v in color do
					t[idx] = if typeof(v) == "Color3"
						then color
						elseif typeof(v) == "string" then Color3.fromHex(v)
						elseif type(v) == "vector" then Color3.fromRGB(
							v.x,
							v.y,
							v.z
						)
						else error(
							`cannot convert {typeof(color)} into color3`,
							0
						)
				end

				return t
			end)()
			else error(`cannot convert {typeof(color)} into color3`, 0)
	end,

	analysis = {
		kind = "argument",
		optional = false,
		vararg = false,
		name = "Color3",
		type = "Color3",
	},
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

local function parse_duration(text: string)
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

local durationT = {
	convert = function(n: number | string): number
		return if typeof(n) == "number" then n else parse_duration(n)
	end,

	analysis = {
		kind = "argument",
		optional = false,
		vararg = false,
		name = "duration",
		type = "number",

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
	},
}

local function generate_names_for_enum(enum: Enum)
	local map = {}

	for _, item: EnumItem in enum:GetEnumItems() do
		map[item.Name] = item
	end

	return enum_map(map, tostring(enum))
end

type G<T> = (name: string?, description: string?) -> T

local function variadic<T>(argument: T): ...T
	local a: language.AnalysisArgument = argument :: any
	assert(a.kind == "argument")
	a.vararg = true
	return a
end

local function optional<T>(argument: T): T | nil
	local a: language.AnalysisArgument = argument :: any
	a.optional = true
	return a
end

local function literal<T>(value: T, name: string?, description: string?): T
	return {
		kind = "literal",
		name = name or "",
		description = description or "",
		value = value,
		optional = false,
	} :: any
end

local function overload<T>(
	p: { { description: string, arguments: { any } } }
): ...any
	return {
		kind = "overload",
		overloads = p,
	} :: any
end

return {

	overload = overload,
	literal = literal,

	any = console.register_type("any", anyT) :: G<any>,
	string = console.register_type("string", stringT) :: G<string>,
	strings = console.register_type("strings", stringsT) :: G<{ string }>,
	number = console.register_type("number", numberT) :: G<number>,
	numbers = console.register_type("numbers", numbersT) :: G<{ number }>,
	boolean = console.register_type("boolean", booleanT) :: G<boolean>,
	booleans = console.register_type("booleans", booleansT) :: G<{ boolean }>,
	table = console.register_type("table", tableT) :: G<{}>,
	vector = console.register_type("vector", vectorT) :: G<vector>,
	vectors = console.register_type("vectors", vectorsT) :: G<{ vector }>,
	player = console.register_type("player", playerT) :: G<Player>,
	players = console.register_type("players", playersT) :: G<{ Player }>,

	userid = console.register_type("userid", useridT) :: G<number>,
	userids = console.register_type("userids", useridsT) :: G<{ number }>,

	color = console.register_type("color", color3T) :: G<Color3>,
	colors = console.register_type("colors", color3sT) :: G<{ Color3 }>,

	duration = console.register_type("duration", durationT) :: G<number>,

	userinput = console.register_type(
		"userinput",
		generate_names_for_enum(Enum.UserInputType)
	) :: G<Enum.UserInputType>,

	variadic = variadic,
	optional = optional,
	opt = optional,

	enum_new = enum_new,
	enum_map = enum_map,
}
