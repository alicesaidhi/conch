--!strict
local types = require("../roblox_packages/types")

type VMState = {
	locals: { string },
	upvalues: { { i: number, index: number } },
	instructions: { types.Instruction },
	up: VMState?,
}

local function DEFINE_LOCAL(state: VMState, key: string)
	table.insert(state.locals, key)
end

-- local function GET_VALUE_INDEX(state: VMState, key: string): (false | number, number)
--     local vm = state
--     local i = 0

--     while vm do
--         local index = table.find(vm.locals, key)
--         if index then return index, i end
--         i += 1
--         vm = state.up
--     end

--     return false, 0
-- end

local function compile(block: types.Block, vm_state: VMState): { types.Instruction }
	local instructions = vm_state.instructions
	local next_instruction = #instructions + 1
	local loop_begins_at: number | false = false

	local function INSERT(instruction: types.Instruction)
		instructions[next_instruction] = instruction
		next_instruction += 1
	end

	local function GET_VALUE(key: string)
		local index = table.find(vm_state.locals, key)
		if index then
			INSERT({ kind = "push_local", index = index })
		else
			INSERT({ kind = "push_global", name = key })
		end
	end

	local function SET_VALUE(key: string)
		local index = table.find(vm_state.locals, key)
		if index then
			INSERT({ kind = "set_local", index = index })
		else
			INSERT({ kind = "set_global", name = key })
		end
	end

	local compile_expression
	local compile_table
	local compile_command
	local compile_lambda
	local compile_var
	local compile_assignment
	local compile_last
	local compile_if
	local compile_for
	local compile_while
	local compile_block
	local compile_vector

	function compile_expression(e: types.Expression)
		--FIXME: Type unions don't properly evaluate state??
		local expression: types.Expression = e

		if expression.kind == "boolean" then
			INSERT({
				kind = "push_boolean",
				b = if expression.token.kind == "true" then true else false,
			})
		elseif expression.kind == "number" then
			local n_string = string.gsub(expression.token.text, "_", "")
			local base_prefix = string.sub(expression.token.text, 2)
			local radix = if base_prefix == "0b" then 2 elseif base_prefix == "0x" then 16 else 10
			local n = if radix ~= 10 then string.sub(n_string, 3) else n_string

			local value = tonumber(n, radix)

			if not value then
				error(`{expression.token.text} could not be converted into a number`, 0)
			end

			INSERT({
				kind = "push_number",
				n = value,
			})
		elseif expression.kind == "evaluate" then
			if expression.body.kind == "command" then
				compile_command(expression.body, 1)
			else
				compile_expression(expression.body)
			end
		elseif expression.kind == "lambda" then
			compile_lambda(expression.body)
		elseif expression.kind == "nil" then
			INSERT({ kind = "push_nil" })
		elseif expression.kind == "string" then
			INSERT({
				kind = "push_string",
				s = string.sub(expression.token.text, 2, -2),
			})
		elseif expression.kind == "table" then
			compile_table(expression.table)
		elseif expression.kind == "var" then
			compile_var(expression.var)
		elseif expression.kind == "vector" then
			compile_vector(expression)
		end
	end

	function compile_vector(vector: types.Expression_Vector)
		local x = vector.contents[1]
		local y = vector.contents[2]
		local z = vector.contents[3]

		if x then
			compile_expression(x)
		else
			INSERT({ kind = "push_number", n = 0 })
		end
		if y then
			compile_expression(y)
		else
			INSERT({ kind = "push_number", n = 0 })
		end
		if z then
			compile_expression(z)
		else
			INSERT({ kind = "push_number", n = 0 })
		end

		INSERT({
			kind = "push_vector",
		})
	end

	function compile_table(t: types.Table)
		INSERT({ kind = "push_table", alloc = 1 })

		local index = 1
		for _, field in t.fields do
			if field.kind == "exprkey" then
				compile_expression(field.key)
				compile_expression(field.value)
				INSERT({ kind = "set_table" })
			elseif field.kind == "namekey" then
				INSERT({ kind = "push_string", s = field.name.text })
				compile_expression(field.value)
				INSERT({ kind = "set_table" })
			elseif field.kind == "nokey" then
				INSERT({ kind = "push_number", n = index })
				compile_expression(field.value)
				INSERT({ kind = "set_table" })
				index += 1
			end
		end
	end

	function compile_command(cmd: types.Command, returns: number?)
		compile_var(cmd.prefix)
		for _, argument in cmd.arguments do
			compile_expression(argument)
		end

		INSERT({
			kind = "call",
			arguments = #cmd.arguments,
			results = returns or math.huge,
		})
	end

	function compile_lambda(lambda: types.FunctionBody)
		local state: VMState = {
			locals = {},
			upvalues = {},
			instructions = {},
			up = vm_state :: VMState?,
		}

		for i, argument in lambda.arguments do
			DEFINE_LOCAL(state, argument.text)
			table.insert(state.instructions, { kind = "set_local", index = i })
		end

		compile(lambda.block, state)
		INSERT({
			kind = "push_function",
			body = state.instructions,
			arguments = #lambda.arguments,
		})
	end

	function compile_var(var: types.Var)
		local prefix = var.prefix
		if prefix.kind == "global" then
			INSERT({ kind = "push_cmd", name = prefix.token.text })
		elseif prefix.kind == "name" then
			GET_VALUE(prefix.name.text)
		elseif prefix.kind == "paren" then
			if prefix.expr.kind == "command" then
				compile_command(prefix.expr)
			else
				compile_expression(prefix.expr)
			end
		end

		for _, suffix in var.suffixes do
			if suffix.kind == "exprindex" then
				if suffix.expr.kind == "command" then
					compile_command(suffix.expr, 1)
				else
					compile_expression(suffix.expr)
				end

				INSERT({ kind = "index" })
			elseif suffix.kind == "nameindex" then
				INSERT({ kind = "push_string", s = suffix.name.text })
				INSERT({ kind = "index" })
			end
		end
	end

	function compile_assignment(assignment: types.Stat_Assign)
		local key = assignment.left.text
		local expression = assignment.right

		if expression.kind == "command" then
			compile_command(expression)
		else
			compile_expression(expression)
		end
		INSERT({ kind = "set_global", name = key })
	end

	function compile_last(s: types.LastStatement)
		local statement = s
		if statement.kind == "return" then
			for _, value in statement.values do
				if value.kind == "command" then
					compile_command(value)
				else
					compile_expression(value)
				end
			end

			INSERT({ kind = "return" })
		elseif statement.kind == "break" then
			assert(loop_begins_at, "cannot use continue outside a loop")
			INSERT({ kind = "goto-pending", type = "break" })
		elseif statement.kind == "continue" then
			assert(loop_begins_at, "cannot use continue outside a loop")
			INSERT({ kind = "goto", to = loop_begins_at })
		else
			error(`unimplemented {statement.kind}`)
		end
	end

	function compile_if(stat: types.Stat_If)
		local start = next_instruction

		for _, condition in stat.ifs do
			local start_condition = next_instruction
			if condition.condition.kind == "command" then
				compile_command(condition.condition, 1)
			else
				compile_expression(condition.condition)
			end
			INSERT({ kind = "goto-pending", type = "next-if" })

			compile_block(condition.block)
			INSERT({ kind = "goto-pending", type = "if-end" })

			for i = next_instruction - 1, start_condition, -1 do
				local instruction = instructions[i]

				if instruction.kind == "goto-pending" and instruction.type == "next-if" then
					local jump_if: types.Instruction_If = { kind = "jump_if", to = next_instruction }
					instructions[i] = jump_if
				end
			end
		end

		if stat.fallback then
			compile_block(stat.fallback)
		end

		for i = next_instruction - 1, start, -1 do
			local instruction = instructions[i]

			if instruction.kind == "goto-pending" and instruction.type == "if-end" then
				instructions[i] = { kind = "goto", to = next_instruction }
			end
		end
	end

	function compile_for(stat: types.Stat_For)
		local arguments = #stat.call.arguments
		local previous_begins = loop_begins_at :: number

		if stat.expression.kind == "command" then
			compile_command(stat.expression, 1)
		else
			compile_expression(stat.expression)
		end

		INSERT({ kind = "turn-into-iterator" })
		SET_VALUE("--iterator")
		local start = next_instruction
		loop_begins_at = start

		GET_VALUE("--iterator")
		INSERT({ kind = "call", arguments = 0, results = math.max(1, arguments) })

		local instruction: types.Instruction_IfNotNil = { kind = "jump_if_not_nil", index = 1, to = 0 }
		INSERT(instruction)

		local block_start = next_instruction

		for i = #stat.call.arguments, 1, -1 do
			local argument = stat.call.arguments[i]
			SET_VALUE(argument.text)
		end
		INSERT({ kind = "reset" })

		compile_block(stat.call.block)

		INSERT({ kind = "goto", to = start })
		instruction.to = next_instruction

		for i = next_instruction - 1, block_start, -1 do
			local instruction = instructions[i]
			if instruction.kind == "goto-pending" and instruction.type == "break" then
				instructions[i] = { kind = "goto", to = next_instruction }
			end
		end

		loop_begins_at = previous_begins
	end

	function compile_while(stat: types.Stat_While)
		local start = next_instruction
		local previous_begins = loop_begins_at :: number
		loop_begins_at = start

		if stat.expression.kind == "command" then
			compile_command(stat.expression, 0)
		else
			compile_expression(stat.expression)
		end

		local instruction: types.Instruction_If = { kind = "jump_if", index = 1, to = 0 }
		INSERT(instruction)
		local block_start = next_instruction

		compile_block(stat.block)

		INSERT({ kind = "goto", to = start })
		instruction.to = next_instruction

		for i = next_instruction - 1, block_start, -1 do
			local instruction = instructions[i]
			if instruction.kind == "goto-pending" and instruction.type == "break" then
				instructions[i] = { kind = "goto", to = next_instruction }
			end
		end

		loop_begins_at = previous_begins
	end

	function compile_block(block: types.Block)
		for idx, statement in block.body do
			if statement.kind == "assign" then
				compile_assignment(statement, vm_state)
			elseif statement.kind == "command" then
				compile_command(
					statement,
					if not block.last_statement and idx == #block.body
						then 8000
						else 0
				)
			elseif statement.kind == "for" then
				compile_for(statement)
			elseif statement.kind == "if" then
				compile_if(statement)
			elseif statement.kind == "while" then
				compile_while(statement)
			else
				error(`not implemented {statement.kind}`)
			end
		end

		if block.last_statement then
			compile_last(block.last_statement)
		end
	end

	compile_block(block)

	return vm_state.instructions
end

return compile
