local analyze = require "../pkgs/analysis/src/lib"
local ast = require "../pkgs/ast/src/lib"
local compiler = require "../pkgs/compiler/src/lib"
local testkit = require "./testkit"
local vm = require "../pkgs/vm/src/lib"

local block

local value = ast "while (false) { print test }"
local vm_state = {}

if value.status == "finished" then
	local virtual = vm()

	virtual.commands.print = print
	virtual.commands.pairs = function(value: { [any]: any })
		local fn = pairs(value)
		local key

		return function()
			local next_key, next_value = fn(value, key)
			key = next_key
			return next_key, next_value
		end
	end

	virtual.commands.ipairs = function(value: { [any]: any })
		local fn = ipairs(value)
		local key = 0

		return function()
			if key == nil then return nil end
			local next_key, next_value = fn(value, key)
			print("the next key is", next_key)
			key = next_key
			print("and the next value will be", next_key)
			return next_key, next_value
		end
	end

	local instructions =
		compiler(value.value, { instructions = {}, locals = {}, upvalues = {} })

	testkit.print(instructions)
	print "starting"
	virtual.run(instructions)
	print "finished"
end

-- if status.status == "finished" then
--     local block = status.value
--     testkit.print(block)
--     -- local instructions = compiler(block, { instructions = {}, locals = {}, upvalues = {} })
--     -- testkit.print(instructions)
--     -- local virtual_machine = vm()
--     -- virtual_machine.commands.sub = function(a, b)
--     --     return a - b
--     -- end
--     -- virtual_machine.commands.mul = function(a, b)
--     --     return a * b
--     -- end
--     -- virtual_machine.commands.print = print
--     -- virtual_machine.commands["os-clock"] = os.clock

--     -- virtual_machine.run(instructions)

-- end
