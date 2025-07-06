--!nonstrict
--[[
Bootstraps some basic functions onto the command line.
]]

local RunService = game:GetService "RunService"

local arg = require "./arguments"
local console = require "./console"
local state = require "./state"
local types = require "./types"

local IS_CLIENT = RunService:IsClient()

local LICENSE = [[MIT License

Copyright (c) 2025 alicesays_hallo

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.]]

local function output(t: types.Log) console.console.output(t) end

local function concat(...: string)
	local t = { ... }
	for i, v in t do
		t[i] = tostring(v)
	end
	return table.concat(t, " ")
end

local function print(...)
	local text = concat(...)
	output { kind = "normal", text = text }
end

local function error(...)
	local text = concat(...)
	error(text, 0)
end

local function warn(...)
	local text = concat(...)
	output { kind = "warn", text = text }
end

local function info(...)
	local text = concat(...)
	output { kind = "info", text = text }
end

if IS_CLIENT then
	console.register_command("license", {
		description = "Outputs the license to the console.",
		permissions = {},
		arguments = function() end,
		callback = function()
			for _, s in string.split(LICENSE, "\n") do
				output { kind = "normal", text = s }
			end
		end,
	})
end

return function()
	local function internal()
		print(
			`CONCH INTERNAL INFORMATION - {if RunService:IsClient()
				then "CLIENT"
				elseif RunService:IsServer() then "SERVER"
				else "?"}`
		)
		print ""
		print "REGISTERED ROLES:"
		for role, perms in state.roles do
			print(`[{role}]: {table.concat(perms, ", ")}`)
		end
		print ""
		print "REGISTERED COMMANDS"
	end

	local function set(t: any, key: any, value: any) t[key] = value end

	-- print("registering commands")
	if IS_CLIENT then
		console.register_command("print", {
			permissions = {},
			description = "Converts the given arguments into a string and sends it to the output",
			arguments = function()
				return arg.variadic(arg.any("any", "Arguments to output"))
			end,
			callback = print,
		})

		console.register_command("sleep", {
			description = "Waits for a given amount of time before continuing execution",
			arguments = function()
				return arg.number("time", "The amount of time to sleep for")
			end,
			callback = task.wait,
		})

		console.register_command("pairs", {
			description = "Iterates over a table",
			arguments = function()
				return arg.table("t", "Table to iterate over")
			end,
			callback = function(value: { [any]: any })
				local fn = pairs(value)
				local key

				return function()
					local next_key, next_value = fn(value, key)
					key = next_key
					return next_key, next_value
				end
			end,
		})

		console.register_command("ipairs", {
			description = "Iterates over an array",
			arguments = function()
				return arg.table("t", "Table to iterate over")
			end,
			callback = function(value: { [any]: any })
				local fn = ipairs(value)
				local key = 0

				return function()
					local next_key, next_value = fn(value, key)
					key = next_key
					return next_key, next_value
				end
			end,
		})

		console.register_quick("error", error)
		console.register_quick("warn", warn)
		console.register_quick("info", info)
		console.register_command("set", {
			permissions = {},
			description = "Attempts to set the given key and value onto the given object",
			arguments = function()
				return arg.any("object", "the object to set"),
					arg.any("key", "key of the object"),
					arg.any("value", "the value to set it to")
			end,
			callback = set,
		})
	end
end
