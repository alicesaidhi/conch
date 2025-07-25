local ast = require "./ast"

type Node = {
	read span: vector,
}

export type Scope = {
	up: Scope?,
	root: true,
	vars: { [string]: unknown },
} | {
	up: Scope,
	root: false,
	vars: { [string]: unknown },
}

export type Trace = | {
	read fn: (...any) -> (),
	read fn_name: string?,
	read origin: "luau",
} | {
	read fn: (...any) -> (),
	read fn_name: string?,
	read origin: "conch",
	read line: number,
}

export type ExecutionState = {
	globals: { [string]: unknown },
	trace: { Trace },
	scope: Scope,
	last_statement: { scope: Scope, node: ast.LastStatement }?,
}

type Expression = ast.Expression | ast.ExpressionCommand

export type ExecutionResult = {
	ok: true,
	values: nil | { unknown },
} | {
	ok: false,
	err: string,
}

local using_machine: { [thread]: ExecutionState } = setmetatable(
	{},
	{ __mode = "k" }
)
local conch_functions: { [string]: string | true } = setmetatable(
	{},
	{ __mode = "k" }
)

local PATTERN_REMOVE_TRACE = "^.+:%d+:%s*"

--[=[
Obtains a stack trace for the called function, which can be used to help
fix errors with commands
]=]
local function get_stack_trace_info(trace: Trace)
	local fn_name = trace.fn_name

	if not fn_name and trace.fn then
		local name, script, line = debug.info(trace.fn, "nsl")
		fn_name = if name ~= "" then `function {name}` else `{script}:{line}`
	else
		fn_name = `function {fn_name}`
	end

	if trace.origin == "conch" then
		return `{trace.origin}:{trace.line} {fn_name}`
	elseif trace.fn then
		return `{trace.origin} {fn_name}`
	else
		return ``
	end
end

local function push_conch_trace(
	state: ExecutionState,
	fn: (...any) -> (),
	fn_name: string?,
	line: number
)
	table.insert(
		state.trace,
		{ fn = fn, fn_name = fn_name, origin = "conch", line = line }
	)
end

local function push_luau_trace(
	state: ExecutionState,
	fn: (...any) -> (),
	fn_name: string?,
	line: number
)
	table.insert(state.trace, { fn = fn, fn_name = fn_name, origin = "luau" })
end

local function pop_trace(state: ExecutionState) table.remove(state.trace) end

local function reset_state(state: ExecutionState)
	table.clear(state.trace)

	while not state.scope.root do
		state.scope = state.scope.up
	end
end

--[=[
Throws an error and stops further execution of the node.
Resets the state back to the highest scope.
]=]
local function throw(state: ExecutionState, node: Node, why: string): never
	local stack_trace = {}

	for i = #state.trace, 1, -1 do
		table.insert(stack_trace, get_stack_trace_info(state.trace[i]))
	end

	reset_state(state)

	error(
		`{why} at {node.span.x}:{node.span.y}\n{table.concat(stack_trace, "\n")}`,
		0
	)
end

local evaluate_expression: (state: ExecutionState, Expression) -> ...unknown
local visit_block: (state: ExecutionState, ast.Block) -> ()
-- local evaluate_command: (state: ExecutionState, node: ast.Command) -> ...unknown

local function read_variable(
	state: ExecutionState,
	var: string
): (Scope?, unknown)
	local active = state.scope

	while active do
		local value = active.vars[var]
		if value then return active, value end
		active = active.up
	end

	return nil, nil
end

local function write_variable(state: ExecutionState, var: string, new: unknown)
	local scope = read_variable(state, var) or state.scope
	scope.vars[var] = new
end

-- proxy functions for operations so that in the case of an error it'll throw the state
-- but not the actual execution
local function index<Object, Key>(
	state: ExecutionState,
	node: Node,
	object: Object,
	key: Key
): unknown
	local ok, value = pcall(function() return (object :: any)[key] end)

	if not ok then
		throw(state, node, `could not index {typeof(object)} with {key}`)
	end
	return value
end

local function call(state: ExecutionState, node: Node, fn: any, ...: any)
	if conch_functions[fn] then
		local name = conch_functions[fn]
		push_conch_trace(
			state,
			fn,
			if name == true then nil else name,
			node.span.z
		)
		local result = table.pack(fn(...))
		pop_trace(state)
		return result
	end

	local ok, values = pcall(function(...) return table.pack(fn(...)) end, ...)

	push_luau_trace(state, fn, nil, node.span.z)
	if not ok then
		throw(state, node, (`{values}`):gsub(PATTERN_REMOVE_TRACE, ""))
	end
	pop_trace(state)

	return values
end

local slash_characters: { [string]: string } = {
	a = "\a",
	b = "\b",
	f = "\f",
	n = "\n",
	r = "\r",
	t = "\t",
	v = "\v",
	["\\"] = "\\",
	["'"] = "'",
	['"'] = '"',
}

--[=[
Converts tokens into a value
]=]
local function get_value<T>(
	state: ExecutionState,
	token: ast.Token<ast.TokenKind>
): unknown
	if token.kind == "number" then
		local n = tonumber(token.text)
		if not n then
			return throw(state, token, `{n} is not a valid number`)
		end
		return n
	elseif token.kind == "string" then
		local text = string.sub(token.text, 2, -2)

		text = string.gsub(
			text,
			"\\([0-9][0-9]?[0-9]?)",
			function(value: string)
				local code = tonumber(value)
				assert(code)
				return string.char(code)
			end
		)

		for key, value in slash_characters do
			text = string.gsub(text, `\\{key}`, value)
		end

		return text
	elseif token.kind == "identifier" then
		return token.text
	elseif token.kind == "true" then
		return true
	elseif token.kind == "false" then
		return false
	elseif token.kind == "nil" then
		return nil
	else
		return throw(state, token, "could not get value")
	end
end

-- *

--[=[
Evaluates a Var node, reading from the appropriate scopes until it gets an answer.
]=]
local function evaluate_var(state: ExecutionState, node: ast.Var): unknown
	local root = node.root
	local _, value

	if root.kind == "global" then
		value = state.globals[root.token.text]
	elseif root.kind == "name" then
		if not root.name then
			return throw(state, node, `no root name token`)
		end
		_, value = read_variable(state, root.name.text)
	elseif root.kind == "paren" then
		local expression = root.node.value
		if not expression then
			return throw(state, root, `missing expression`)
		end

		value = evaluate_expression(state, expression)
	end

	for _, suffix in node.suffixes do
		if suffix.kind == "expression_index" then
			local key = suffix.node.value
			if not key then
				return throw(state, suffix, "missing expression")
			end

			value = index(state, node, value, evaluate_expression(state, key))
		elseif suffix.kind == "name_index" then
			if not suffix.name then
				return throw(state, suffix, "missing expression")
			end

			value = index(state, node, value, get_value(state, suffix.name))
		end
	end

	return value
end

local function evaluate_command(
	state: ExecutionState,
	node: ast.Command
): { n: number, [number]: unknown }
	local arguments = {}

	for idx, argument in node.arguments do
		table.move(
			{ evaluate_expression(state, argument) },
			1,
			8000,
			idx,
			arguments
		)
	end

	local command = evaluate_var(state, node.var)

	return call(state, node, command, unpack(arguments))
end

local function evaluate_table(
	state: ExecutionState,
	node: ast.ExpressionTable
): { [any]: any }
	local t = {}
	local idx = 1

	for _, field in node.values.value do
		local token = field.value

		if token.kind == "expression_key" then
			if not token.key then return throw(state, field, "no key") end
			if not token.key.value then return throw(state, field, "no key") end
			if not token.value then return throw(state, field, "no value") end
			local key = evaluate_expression(state, token.key.value)
			local value = evaluate_expression(state, token.value)

			t[key] = value
		elseif token.kind == "name_key" then
			if not token.value then return throw(state, field, "no value") end
			t[token.name.text] = evaluate_expression(state, token.value)
		elseif token.kind == "nokey" then
			if not token.value then return throw(state, field, "no value") end
			t[idx] = evaluate_expression(state, token.value)
			idx += 1
		end
	end

	return t
end

local function wrap_op(
	state: ExecutionState,
	node: Node,
	op: string,
	a: any,
	b: any,
	fn: (a: any, b: any) -> unknown
): unknown
	local ok, result = pcall(fn, a, b)

	if ok then
		return result
	else
		return throw(
			state,
			node,
			`attempt to {op} on {typeof(a)} and {typeof(b)}`
		)
	end
end

local function evaluate_binary(
	state: ExecutionState,
	node: ast.ExpressionBinary
): unknown
	if not node.left then
		return throw(state, node, "missing lhs expression")
	end
	if not node.right then
		return throw(state, node, "missing rhs expression")
	end
	local left: any = evaluate_expression(state, node.left)
	local right: any = evaluate_expression(state, node.right)
	local operator = node.operator.kind

	if operator == "!=" then
		return wrap_op(
			state,
			node,
			"compare !=",
			left,
			right,
			function(a, b) return a ~= b end
		)
	elseif operator == "%" then
		return wrap_op(
			state,
			node,
			"get modulo of",
			left,
			right,
			function(a, b) return a % b end
		)
	elseif operator == "*" then
		return wrap_op(
			state,
			node,
			"multiply",
			left,
			right,
			function(a, b) return a * b end
		)
	elseif operator == "+" then
		return wrap_op(
			state,
			node,
			"add",
			left,
			right,
			function(a, b) return a + b end
		)
	elseif operator == "-" then
		return wrap_op(
			state,
			node,
			"subtract",
			left,
			right,
			function(a, b) return a - b end
		)
	elseif operator == ".." then
		return wrap_op(
			state,
			node,
			"concatenate",
			left,
			right,
			function(a, b) return a .. b end
		)
	elseif operator == "/" then
		return wrap_op(
			state,
			node,
			"divide",
			left,
			right,
			function(a, b) return a / b end
		)
	elseif operator == "//" then
		return wrap_op(
			state,
			node,
			"idivide",
			left,
			right,
			function(a, b) return a // b end
		)
	elseif operator == "<" then
		return wrap_op(
			state,
			node,
			"compare <",
			left,
			right,
			function(a, b) return a < b end
		)
	elseif operator == "<=" then
		return wrap_op(
			state,
			node,
			"compare <=",
			left,
			right,
			function(a, b) return a <= b end
		)
	elseif operator == "==" then
		return wrap_op(
			state,
			node,
			"compare ==",
			left,
			right,
			function(a, b) return a == b end
		)
	elseif operator == ">" then
		return wrap_op(
			state,
			node,
			"compare >",
			left,
			right,
			function(a, b) return a > b end
		)
	elseif operator == ">=" then
		return wrap_op(
			state,
			node,
			"compare >=",
			left,
			right,
			function(a, b) return a >= b end
		)
	elseif operator == "^" then
		return wrap_op(
			state,
			node,
			"get the power",
			left,
			right,
			function(a, b) return a ^ b end
		)
	elseif operator == "and" then
		return left and right
	elseif operator == "or" then
		return left or right
	elseif operator == "~=" then
		return wrap_op(
			state,
			node,
			"compare ~=",
			left,
			right,
			function(a, b) return a ~= b end
		)
	else
		return throw(state, node, `unsupported operator {operator}`)
	end
end

local function evaluate_unary(
	state: ExecutionState,
	node: ast.ExpressionUnary
): unknown
	if not node.value then return throw(state, node, "missing expression") end
	local value: any = evaluate_expression(state, node.value)

	if node.operator.kind == "!" then
		return not value
	elseif node.operator.kind == "-" then
		return -value
	else
		return throw(state, node, `unsupported operator {node.operator}`)
	end
end

local function evaluate_lambda(
	state: ExecutionState,
	node: ast.ExpressionLambda
)
	local original_scope = {
		vars = state.scope.vars,
		root = true,
		up = state.scope.up,
	}

	local function conch_guest_fn(...: any): ...unknown
		local scope: Scope = {
			vars = original_scope.vars,
			up = original_scope.up,
			root = true :: true,
		}

		for i, arg in node.body.arguments.value do
			local value = select(i, ...)
			if not arg.value then continue end
			scope.vars[arg.value.text] = value
		end

		if not node.body.block then return throw(state, node, "no block") end

		local calling_machine = using_machine[coroutine.running()]
		local state: ExecutionState = {
			trace = calling_machine and calling_machine.trace or {},
			scope = scope,
			globals = state.globals,
			return_state = nil,
		}

		visit_block(state, node.body.block.value)

		if state.last_statement then
			local lstat = state.last_statement.node

			if lstat.kind ~= "return" then
				if calling_machine then
					calling_machine.last_statement =
						{ scope = scope, node = lstat }
				end
				return
			end

			local values = {}

			for idx, value in lstat.values do
				local node = value.value
				if not node then continue end
				values[idx] = evaluate_expression(state, node)
			end

			return unpack(values, 1, #lstat.values)
		end

		return
	end

	conch_functions[conch_guest_fn] = true
	return conch_guest_fn
end

function evaluate_expression(
	state: ExecutionState,
	node: ast.Expression | ast.ExpressionCommand
): ...unknown
	if node.kind == "binary" then
		return evaluate_binary(state, node)
	elseif node.kind == "boolean" then
		return get_value(state, node.token)
	elseif node.kind == "command" then
		if not node.command then
			return throw(state, node, "missing command")
		end
		local result = evaluate_command(state, node.command)
		return unpack(result, 1, result.n)
	elseif node.kind == "evaluate" then
		if not node.command.value then
			return throw(state, node, "no expression within evaluate")
		end
		return evaluate_expression(state, node.command.value)
	elseif node.kind == "lambda" then
		return evaluate_lambda(state, node)
	elseif node.kind == "nil" then
		return nil
	elseif node.kind == "number" then
		return get_value(state, node.token)
	elseif node.kind == "string" then
		return get_value(state, node.token)
	elseif node.kind == "table" then
		return evaluate_table(state, node)
	elseif node.kind == "unary" then
		return evaluate_unary(state, node)
	elseif node.kind == "var" then
		return evaluate_var(state, node)
	elseif node.kind == "vector" then
		local contents = node.contents.value

		local x = contents[1] and contents[1].value
		local y = contents[2] and contents[2].value
		local z = contents[3] and contents[3].value

		return vector.create(
			if x then evaluate_expression(state, x) :: number else 0,
			if y then evaluate_expression(state, y) :: number else 0,
			if z then evaluate_expression(state, z) :: number else 0
		)
	else
		return throw(state, node, `could not evaluate {node.kind}`)
	end
end

---- tree walker

local function visit_stat_command(state: ExecutionState, node: ast.Command)
	evaluate_command(state, node)
end

local function visit_stat_for(state: ExecutionState, node: ast.For): unknown
	local value_node = node.expression and node.expression.value
	local body_node = node.body

	if not value_node then return throw(state, node, "missing expression") end
	local value: any = evaluate_expression(state, value_node)

	if not body_node then return throw(state, node, "missing body") end
	local body = evaluate_expression(state, body_node)

	push_conch_trace(state, body :: any, nil, node.span.z)
	--stylua: ignore
	for a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z in value do
		call(state, node, body, a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z)
		local lstat = state.last_statement

		if lstat and lstat.node.kind == "break" then
			state.last_statement = nil
			break
		elseif lstat and lstat.node.kind == "continue" then
			state.last_statement = nil
		elseif lstat and lstat.node.kind == "return" then
			break
		end
	end
	pop_trace(state)

	return nil
end

local function visit_stat_while(state: ExecutionState, node: ast.While): unknown
	local condition_node = node.condition and node.condition.value
	local body_node = node.block and node.block.value

	if not condition_node then
		return throw(state, node, "missing condition")
	end
	if not body_node then return throw(state, node, "missing body") end

	while evaluate_expression(state, condition_node) do
		visit_block(state, body_node)

		local lstat = state.last_statement

		if lstat and lstat.node.kind == "break" then
			state.last_statement = nil
			break
		elseif lstat and lstat.node.kind == "continue" then
			state.last_statement = nil
		elseif lstat and lstat.node.kind == "return" then
			break
		end
	end

	return nil
end

local function visit_stat_assign(
	state: ExecutionState,
	node: ast.Assign
): unknown
	if not node.value then return throw(state, node, "missing value") end

	local key = node.identifier.text
	local value = evaluate_expression(state, node.value)

	if typeof(value) and conch_functions[value] then
		conch_functions[value] = key
	end

	write_variable(state, key, value)
	return nil
end

local function visit_stat_if(state: ExecutionState, node: ast.If)
	local function evaluate_branch(branch: ast.IfBranch): boolean
		local condition = branch.condition and branch.condition.value
		local body = branch.block and branch.block.value
		if not condition then return throw(state, node, "missing condition") end
		if not body then return throw(state, node, "missing body") end

		if evaluate_expression(state, condition) then
			visit_block(state, body)
			return true
		end

		return false
	end

	if evaluate_branch(node.first_branch) then return end

	for _, branch in node.branches do
		if evaluate_branch(branch.branch) then return end
	end

	if node.else_branch then
		if not node.else_branch.block then return end
		visit_block(state, node.else_branch.block.value)
	end
end

local function visit_lstat(state: ExecutionState, node: ast.LastStatement)
	state.last_statement = { node = node, scope = state.scope }
end

function visit_block(state: ExecutionState, node: ast.Block)
	state.scope = {
		up = state.scope,
		root = false :: false,
		vars = {},
	}

	for _, stat in node.body do
		if stat.kind == "assign" then
			visit_stat_assign(state, stat)
		elseif stat.kind == "command" then
			visit_stat_command(state, stat)
		elseif stat.kind == "for" then
			visit_stat_for(state, stat)
		elseif stat.kind == "if" then
			visit_stat_if(state, stat)
		elseif stat.kind == "while" then
			visit_stat_while(state, stat)
		end

		if state.last_statement then break end
	end

	if node.last_statement then visit_lstat(state, node.last_statement) end

	if not state.scope.up then return end
	state.scope = state.scope.up
end

local function create_state(): ExecutionState
	local state: ExecutionState = {
		trace = {},
		globals = {},
		last_statement = nil,
		scope = {
			vars = {},
			root = true :: true,
			up = nil,
		} :: Scope,
	}

	return state
end

local function execute(state: ExecutionState, ast: ast.Ast): ExecutionResult
	local ok, err = pcall(visit_block, state, ast.block)

	if not ok then
		reset_state(state)
		return {
			ok = false,
			err = err:gsub(PATTERN_REMOVE_TRACE, "") :: string,
		}
	end

	local result_ok = {
		ok = true,
		values = nil :: nil | { unknown },
	}

	local lstat = state.last_statement
	state.last_statement = nil

	if not lstat then return result_ok end
	if lstat.node.kind ~= "return" then return result_ok end

	result_ok.values = table.create(#lstat.node.values, nil :: unknown)
	assert(result_ok.values)

	for idx, value in lstat.node.values do
		if not value.value then continue end

		ok, err = pcall(evaluate_expression, state, value.value)
		if not ok then
			reset_state(state)
			return { ok = false, err = err:gsub(PATTERN_REMOVE_TRACE, "") }
		end
		result_ok.values[idx] = err
	end

	return result_ok
end

return {

	create_state = create_state,

	execute = function(state: ExecutionState, ast: ast.Ast)
		using_machine[coroutine.running()] = state
		local result = execute(state, ast)
		using_machine[coroutine.running()] = nil
		return result
	end,
}
