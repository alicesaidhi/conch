--!nonstrict
local types = require "../roblox_packages/types"

type VirtualMachine = types.VirtualMachine

local MAX_EXECUTION_TIME = 30

local function error_handler(msg: string) error(msg) end

local function LOG(...)
	return
	-- print(...)
end

local function create_vm()
	local start = os.clock()
	local locals = {}
	local globals = {}
	local commands = {}
	local stack = table.create(255)
	local instruction_at = 1
	local instruction_end = 0
	local n = 0

	local function PUSH(value: unknown)
		-- LOG("pushing value to stack", tostring(value), "now at", n + 1)
		stack[n + 1] = value
		n += 1
	end

	local function POP()
		-- LOG(`popping {n} from stack, popped {tostring(stack[n])}`)
		n -= 1
		return stack[n + 1]
	end

	local function POPN(amount: number)
		-- LOG(`popping {amount} elements from stack`)
		local top = n
		local bottom = n - amount + 1
		n -= amount
		return unpack(stack, bottom, top)
	end

	local function GET(at: number)
		if at < 0 then at = n + at + 1 end
		if at > n then return nil end
		return stack[at]
	end

	local function call_success(
		max: number,
		kind: string,
		ok: boolean,
		...: any
	)
		if not ok then error(`{table.concat({ ... }, " ")}`, 0) end

		for i = 1, math.min(max, select("#", ...)) do
			PUSH(select(i, ...))
		end
	end

	local function process(i: types.Instruction)
		if os.clock() > (start + MAX_EXECUTION_TIME) then
			error("reached execution time limit", 0)
		end
		-- task.wait()
		local instruction = i
		-- LOG("RUNNING", i.kind)
		if instruction.kind == "call" then
			local arguments = instruction.arguments
			local t = { POPN(arguments) }
			local fn = POP()
			-- LOG(arguments)
			call_success(instruction.results, typeof(fn), pcall(fn, unpack(t)))
		elseif instruction.kind == "goto" then
			instruction_at = instruction.to - 1
		elseif instruction.kind == "index" then
			local t, k = POPN(2)
			local ok, result = pcall(function() return t[k] end)

			if not ok then
				error(`attempt to index {typeof(t)} with {tostring(k)}`, 0)
			end

			PUSH(result)
		elseif instruction.kind == "jump_if" then
			local value = POP()
			if not value then
				instruction_at = instruction.to - 1
				n = 0
			end
		elseif instruction.kind == "jump_if_not_nil" then
			local value = GET(1)
			if value == nil then
				instruction_at = instruction.to - 1
				n = 0
			end
		elseif instruction.kind == "push_boolean" then
			PUSH(instruction.b)
		elseif instruction.kind == "push_cmd" then
			PUSH(commands[instruction.name])
		elseif instruction.kind == "push_function" then
			local body = instruction.body
			local function VM_FN(...)
				local state = {
					start = start,
					locals = locals,
					globals = globals,
					commands = commands,
					stack = stack,
					n = n,
					instruction_at = instruction_at,
					instruction_end = instruction_end,
				}

				-- LOG("stack at", n)
				local values = { ... }
				locals = {}
				start = os.clock()
				stack = values
				n = instruction.arguments
				-- LOG("starting with", n)
				instruction_at = 1
				instruction_end = #body

				while instruction_at <= instruction_end do
					-- LOG("stack size", n)
					process(body[instruction_at])
					instruction_at += 1
				end

				locals = state.locals
				globals = state.globals
				commands = state.commands
				stack = state.stack
				start = state.start
				n = state.n
				instruction_at = state.instruction_at
				instruction_end = state.instruction_end

				-- LOG("returning", n, table.concat(values, "1"))
				return unpack(values, 1, n)
			end

			PUSH(VM_FN)
		elseif instruction.kind == "push_global" then
			PUSH(globals[instruction.name])
		elseif instruction.kind == "push_vector" then
			local z = POP()
			local y = POP()
			local x = POP()

			PUSH(vector.create(x, y, z))
		elseif instruction.kind == "push_local" then
			PUSH(locals[instruction.index])
		elseif instruction.kind == "push_nil" then
			PUSH(nil)
		elseif instruction.kind == "push_number" then
			PUSH(instruction.n)
		elseif instruction.kind == "push_string" then
			-- LOG("pushing", instruction.s, "at", n + 1)
			PUSH(instruction.s)
		elseif instruction.kind == "push_table" then
			PUSH(table.create(instruction.alloc))
		elseif instruction.kind == "set_global" then
			globals[instruction.name] = POP()
		elseif instruction.kind == "set_local" then
			locals[instruction.index] = POP()
		elseif instruction.kind == "set_table" then
			local v, k = POP(), POP()
			local t = GET(n)
			t[k] = v
		elseif instruction.kind == "return" then
			LOG("stack", #stack, stack[1])
			instruction_at = instruction_end
		elseif instruction.kind == "reset" then
			n = 0
		elseif instruction.kind == "turn-into-iterator" then
			local value = POP()

			if typeof(value) == "table" then
				local default_iterator = pairs
				local mt = getmetatable(value)

				if typeof(mt) == "table" then
					default_iterator = mt.__iter or default_iterator
				end

				local fn = pairs(value)
				local previous = {}

				PUSH(function()
					local t = { fn(value, unpack(previous)) }
					previous = t
					return unpack(t)
				end)
			else
				PUSH(value)
			end
		end
	end

	local function run(instructions: { types.Instruction })
		start = os.clock()
		instruction_at = 1
		instruction_end = #instructions

		while instruction_at <= instruction_end do
			process(instructions[instruction_at])
			instruction_at += 1
		end

		local old_n = n
		n = 0
		return old_n, unpack(stack, 1, old_n)
	end

	start = os.clock()

	return {
		commands = commands,
		globals = globals,
		locals = locals,
		run = run,
	}
end

return create_vm
