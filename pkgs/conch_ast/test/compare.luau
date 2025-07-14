local ast = require "../src/ast"

local issues: { { why: string, a: unknown, b: unknown } } = {}

local function throw(msg: string, a: unknown, b: unknown)
	table.insert(issues, { why = msg, a = a, b = b })
end

type Compare<T> = (a: T, b: T) -> ()

local compare_function_body: Compare<ast.FunctionBody>

local compare_var_root: Compare<ast.VarRoot>
local compare_var: Compare<ast.Var>

local compare_tablefield: Compare<ast.TableField>
local compare_table: Compare<ast.ExpressionTable>
local compare_expression: Compare<ast.Expression>

local compare_return: Compare<ast.Return>
local compare_last_statement: Compare<ast.LastStatement>

local compare_if_branch: Compare<ast.IfBranch>
local compare_elseif_branch: Compare<ast.ElseIfBranch>

local compare_assign: Compare<ast.Assign>
local compare_command: Compare<ast.Command>
local compare_for: Compare<ast.For>
local compare_if: Compare<ast.If>
local compare_while: Compare<ast.While>
local compare_statement: Compare<ast.Statement>

local compare_block: Compare<ast.Block>

local function compare_token(a: ast.Token<any>, b: ast.Token<any>)
	if a.kind ~= b.kind then throw(`mismatching kinds`, a, b) end
	if a.text ~= b.text then throw(`mismatching text`, a.text, b.text) end
end

local function compare_delimited<T>(
	a: ast.Delimited<any, T, any>?,
	b: ast.Delimited<any, T, any>?,
	fn: (a: T, b: T) -> ()
)
	if not a or not b then return throw("missing delimited", a, b) end

	fn(a.value, b.value)
end

local function compare_separated<T>(
	a: ast.Separated<T>,
	b: ast.Separated<T>,
	fn: (a: T, b: T) -> ()
)
	local idx = math.max(#a, #b)

	for i = 1, idx do
		if type(a[idx].separator) ~= type(b[idx].separator) then
			throw("missing separator", a[idx].separator, b[idx].separator)
		end

		if a[idx] == nil or b[idx] == nil then
			throw("missing value", a[idx], b[idx])
			continue
		end

		fn(a[idx].value, b[idx].value)
	end
end

local function generate_separated<T>(fn: (a: T, b: T) -> ())
	return function(a: ast.Separated<T>, b: ast.Separated<T>)
		compare_separated(a, b, fn)
	end
end

function compare_function_body(a: ast.FunctionBody, b: ast.FunctionBody)
	compare_delimited(
		a.arguments,
		b.arguments,
		generate_separated(compare_token)
	)
	compare_delimited(a.block, b.block, compare_block)
end

function compare_var_root(a: ast.VarRoot, b: ast.VarRoot)
	if a.kind ~= b.kind then return throw("mismatched varroot kind", a, b) end

	if a.kind == "global" and b.kind == "global" then
		compare_token(a.token, b.token)
	elseif a.kind == "name" and b.kind == "name" then
		if a.name == nil or b.name == nil then
			return throw("missing name", a.name, b.name)
		end

		compare_token(a.name, b.name)
	elseif a.kind == "paren" and b.kind == "paren" then
		compare_delimited(a.node, b.node, compare_expression)
	else
		error(`unreachable - {a.kind} {b.kind}`)
	end
end

function compare_var_suffix(a: ast.VarSuffix, b: ast.VarSuffix)
	if a.kind ~= b.kind then
		return throw("mismatched var suffix kind", a, b)
	end

	if a.kind == "expression_index" and b.kind == "expression_index" then
		compare_delimited(a.node, b.node, compare_expression)
	elseif a.kind == "name_index" and b.kind == "name_index" then
		if a.name == nil or b.name == nil then
			return throw("missing name", a.name, b.name)
		end

		compare_token(a.name, b.name)
	else
		error(`unreachable - {a.kind} {b.kind}`)
	end
end

function compare_var(a: ast.Var, b: ast.Var)
	compare_var_root(a.root, b.root)

	local suffixes = math.max(#a.suffixes, #b.suffixes)

	for i = 1, suffixes do
		local suffix_a = a.suffixes[i]
		local suffix_b = b.suffixes[i]

		if suffix_a == nil or suffix_b == nil then
			throw("missing suffix", suffix_a, suffix_b)
			continue
		end

		compare_var_suffix(suffix_a, suffix_b)
	end
end

function compare_tablefield(a: ast.TableField, b: ast.TableField)
	if a.kind ~= b.kind then return throw("mismatched kind", a, b) end

	if a.kind == "expression_key" and b.kind == "expression_key" then
		compare_delimited(a.key, b.key, compare_expression)

		if a.value == nil or b.value == nil then
			return throw("no value", a.value, b.value)
		end

		compare_expression(a.value, b.value)
	elseif a.kind == "name_key" and b.kind == "name_key" then
		compare_token(a.name, b.name)

		if a.value == nil or b.value == nil then
			return throw("no value", a.value, b.value)
		end

		compare_expression(a.value, b.value)
	elseif a.kind == "nokey" and b.kind == "nokey" then
		if a.value == nil or b.value == nil then
			return throw("no expression", a.value, b.value)
		end

		compare_expression(a.value, b.value)
	else
		error(`unreachable - {a.kind} {b.kind}`)
	end
end

function compare_table(a: ast.ExpressionTable, b: ast.ExpressionTable)
	compare_delimited(
		a.values,
		b.values,
		generate_separated(compare_tablefield)
	)
end

function compare_expression(a: ast.Expression, b: ast.Expression)
	if a.kind ~= b.kind then throw(`mismatching kind`, a, b) end

	if a.kind == "binary" and b.kind == "binary" then
		compare_expression(a.left, b.left)
		compare_token(a.operator, b.operator)

		if not a.right or not b.right then
			throw("missing right hand side", a.right, b.right)
			return
		end

		compare_expression(a.right, b.right)
	elseif a.kind == "boolean" and b.kind == "boolean" then
		compare_token(a.token, b.token)
	elseif a.kind == "command" and b.kind == "command" then
		if not a.command or not b.command then
			return throw("missing command", a.command, b.command)
		end

		compare_command(a.command, b.command)
	elseif a.kind == "evaluate" and b.kind == "evaluate" then
		compare_delimited(a.command, b.command, compare_expression)
	elseif a.kind == "lambda" and b.kind == "lambda" then
		compare_function_body(a.body, b.body)
	elseif a.kind == "nil" and b.kind == "nil" then
	elseif a.kind == "number" and b.kind == "number" then
		compare_token(a.token, b.token)
	elseif a.kind == "string" and b.kind == "string" then
		compare_token(a.token, b.token)
	elseif a.kind == "table" and b.kind == "table" then
		compare_table(a, b)
	elseif a.kind == "unary" and b.kind == "unary" then
		compare_token(a.operator, b.operator)
		if not a.value or not b.value then
			return throw("missing value", a.value, b.value)
		end
		compare_expression(a.value, b.value)
	elseif a.kind == "var" and b.kind == "var" then
		compare_var(a, b)
	elseif a.kind == "vector" and b.kind == "vector" then
		compare_delimited(
			a.contents,
			b.contents,
			generate_separated(compare_expression)
		)
	else
		error(
			`unreachable - unsupported {a.kind} {b.kind} {b.token.kind} {b.span}`
		)
	end
end

function compare_return(a: ast.Return, b: ast.Return)
	compare_separated(a.values, b.values, compare_expression)
end

function compare_last_statement(a: ast.LastStatement, b: ast.LastStatement)
	if a.kind ~= b.kind then
		return throw("mismatching last statement kind", a, b)
	end

	if a.kind == "break" and b.kind == "break" then
		return
	elseif a.kind == "continue" and b.kind == "continue" then
		return
	elseif a.kind == "return" and b.kind == "return" then
		compare_return(a, b)
	end
end

function compare_if_branch(a: ast.IfBranch, b: ast.IfBranch)
	compare_delimited(a.condition, b.condition, compare_expression)
	compare_delimited(a.block, b.block, compare_block)
end

function compare_elseif_branch(a: ast.ElseIfBranch, b: ast.ElseIfBranch)
	compare_if_branch(a.branch, b.branch)
end

function compare_assign(a: ast.Assign, b: ast.Assign)
	compare_token(a.identifier, b.identifier)

	if not a.value or not b.value then return throw("missing value", a, b) end

	compare_expression(a.value, b.value)
end

function compare_command(a: ast.Command, b: ast.Command)
	compare_var(a.var, b.var)
	local args = math.max(#a.arguments, #b.arguments)

	for i = 1, args do
		local arg_a, arg_b = a.arguments[i], b.arguments[i]

		if arg_a == nil or arg_b == nil then
			throw(`missing argument`, arg_a, arg_b)
			continue
		end

		compare_expression(arg_a, arg_b)
	end
end

function compare_for(a: ast.For, b: ast.For)
	compare_delimited(a.expression, b.expression, compare_expression)
	if not a.body or not b.body then return throw("missing body", a, b) end
	compare_expression(a.body, b.body)
end

function compare_if(a: ast.If, b: ast.If)
	if type(a.branches) ~= type(b.branches) then
		throw("missing branches", a.branches, b.branches)
	end

	if type(a.else_branch) ~= type(b.else_branch) then
		throw("missing else branch", a.else_branch, b.else_branch)
	end

	compare_if_branch(a.first_branch, b.first_branch)

	if a.branches and b.branches then
		local total_branches = math.max(#a.branches, #b.branches)

		for i = 1, total_branches do
			local branch_a = a.branches[i]
			local branch_b = b.branches[i]

			if branch_a == nil or branch_b == nil then
				throw(`missing elseif branch`, branch_a, branch_b)
				continue
			end

			compare_elseif_branch(branch_a, branch_b)
		end
	end

	if a.else_branch and b.else_branch then
		compare_delimited(
			a.else_branch.block,
			b.else_branch.block,
			compare_block
		)
	end
end

function compare_while(a: ast.While, b: ast.While)
	compare_delimited(a.condition, b.condition, compare_expression)
	compare_delimited(a.block, b.block, compare_block)
end

function compare_statement(a: ast.Statement, b: ast.Statement)
	if a.kind ~= b.kind then
		return throw(
			`got mismatching statements: "{a.kind}" and "{b.kind}"`,
			a,
			b
		)
	end

	if a.kind == "assign" and b.kind == "assign" then
		compare_assign(a, b)
	elseif a.kind == "command" and b.kind == "command" then
		compare_command(a, b)
	elseif a.kind == "for" and b.kind == "for" then
		compare_for(a, b)
	elseif a.kind == "if" and b.kind == "if" then
		compare_if(a, b)
	elseif a.kind == "while" and b.kind == "while" then
		compare_while(a, b)
	else
		error(`unreachable - unsupported {a.kind} {b.kind}`)
	end
end

function compare_block(a: ast.Block, b: ast.Block)
	local total = math.max(#a.body, #b.body)

	for i = 1, total do
		local stat_a = a.body[i]
		local stat_b = b.body[i]

		if type(stat_a) ~= type(stat_b) then
			throw(`missing statement`, stat_a, stat_b)
		else
			compare_statement(stat_a, stat_b)
		end
	end

	if type(a.last_statement) ~= type(b.last_statement) then
		throw(
			`missing last statement:`,
			a.last_statement or a,
			b.last_statement or b
		)
	elseif a.last_statement and b.last_statement then
		compare_last_statement(a.last_statement, b.last_statement)
	end
end

local function compare_ast(a: ast.Ast, b: ast.Ast)
	issues = {}
	compare_block(a.block, b.block)
	return issues
end

return compare_ast
