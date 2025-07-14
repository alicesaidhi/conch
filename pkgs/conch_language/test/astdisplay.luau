local ast = require "../src/ast"

local buf = buffer.create(1024)
local pos = 0
local tbs = 0
local enable_newlines = true
local line_length = 0

local function write_str(str: string)
	local old_size = buffer.len(buf)

	if pos + #str >= old_size then
		local new_size = old_size + old_size / 2
		while pos + #str >= new_size do
			new_size = new_size + new_size / 2
		end

		local new_buf = buffer.create(new_size)
		buffer.copy(new_buf, 0, buf, 0, pos)
		buf = new_buf
	end

	buffer.writestring(buf, pos, str, #str)
	pos += #str
	line_length += #str
end

local function char(c: string): number return (string.byte(c)) end

local function write_char(char: number)
	local old_size = buffer.len(buf)

	if pos + 1 >= old_size then
		local new_size = old_size + old_size / 2
		while pos + 1 >= new_size do
			new_size = new_size + new_size / 2
		end

		local new_buf = buffer.create(new_size)
		buffer.copy(new_buf, 0, buf, 0, pos)
		buf = new_buf
	end

	buffer.writeu8(buf, pos, char)
	line_length += 1
	pos += 1
end

export type Displayable = unknown -- number | string | boolean | { [Displayable]: Displayable }

local function write_line()
	if enable_newlines then
		write_char(char "\n")
		write_str(string.rep("\t", tbs))
	else
		write_char(char " ")
	end
end

local function display_token(token: ast.Token<ast.TokenKind>)
	write_str(token.text)

	if
		token.kind == "and"
		or token.kind == "or"
		or token.kind == "break"
		or token.kind == "continue"
		or token.kind == "else"
		or token.kind == "elseif"
		or token.kind == "true"
		or token.kind == "false"
		or token.kind == "nil"
		or token.kind == "if"
		or token.kind == "while"
		or token.kind == "else"
		or token.kind == "for"
		or token.kind == "return"
		or token.kind == "break"
		or token.kind == "number"
	then
		write_char(char " ")
	end
end

-- * actual display

local display_delimited
local display_separated
local generate_separated

local display_function_body

local display_var_root
local display_var

local display_tablefield
local display_table
local display_expression

local display_break
local display_continue
local display_return
local display_last_statement

local display_if_branch
local display_elseif_branch
local display_else_branch

local display_assign
local display_command
local display_for
local display_if
local display_while
local display_statement

local display_block

function display_delimited<T>(delimit: ast.Delimited<any, T, any>?, fn: (T) -> ())
	assert(delimit)
	assert(delimit.left)
	assert(delimit.value)
	assert(delimit.right)

	tbs += 1
	display_token(delimit.left)
	write_line()
	fn(delimit.value)
	tbs -= 1
	write_line()
	display_token(delimit.right)
end

function display_separated<T>(separated: ast.Separated<T>, fn: (T) -> ())
	for _, value in separated do
		fn(value.value)
		if value.separator then display_token(value.separator) end
		write_line()
	end
end

function generate_separated<T>(fn: (T) -> ()): (separated: ast.Separated<T>) -> ()
	return function(separated) display_separated(separated, fn) end
end

--#region expressions

function display_function_body(value: ast.FunctionBody)
	display_delimited(value.arguments, generate_separated(display_token))
	display_delimited(value.block, display_block)
end

function display_tablefield(value: ast.TableField)
	if value.kind == "expression_key" then
		assert(value.equals)
		assert(value.value)
		display_delimited(value.key, display_expression)
		display_token(value.equals)
		display_expression(value.value)
	elseif value.kind == "name_key" then
		assert(value.value)
		display_token(value.name)
		display_token(value.equals)
		display_expression(value.value)
	elseif value.kind == "nokey" then
		assert(value.value)
		display_expression(value.value)
	end
end

function display_table(value: ast.ExpressionTable)
	display_delimited(value.values, generate_separated(display_tablefield))
end

function display_var_root(root: ast.VarRoot)
	if root.kind == "global" then
		display_token(root.token)
	elseif root.kind == "name" then
		assert(root.name)
		display_token(root.var)
		display_token(root.name)
	elseif root.kind == "paren" then
		display_token(root.var)
		display_delimited(root.node, display_expression)
	end
end

function display_var_suffix(suffix: ast.VarSuffix)
	if suffix.kind == "expression_index" then
		display_token(suffix.period)
		display_delimited(suffix.node, display_expression)
	elseif suffix.kind == "name_index" then
		assert(suffix.name)
		display_token(suffix.period)
		display_token(suffix.name)
	end
end

function display_var(var: ast.Var)
	display_var_root(var.root)
	for _, suffix in var.suffixes do
		display_var_suffix(suffix)
	end
	write_char(char " ")
end

function display_expression(expr: ast.Expression | ast.ExpressionCommand)
	if expr.kind == "binary" then
		assert(expr.right)
		display_expression(expr.left)
		display_token(expr.operator)
		display_expression(expr.right)
	elseif expr.kind == "boolean" then
		display_token(expr.token)
	elseif expr.kind == "command" then
		write_char(char "&")
		assert(expr.command)
		display_command(expr.command)
	elseif expr.kind == "evaluate" then
		display_delimited(expr.command, display_expression)
	elseif expr.kind == "lambda" then
		display_function_body(expr.body)
	elseif expr.kind == "nil" then
		display_token(expr.token)
	elseif expr.kind == "number" then
		display_token(expr.token)
	elseif expr.kind == "string" then
		display_token(expr.token)
	elseif expr.kind == "table" then
		display_table(expr)
	elseif expr.kind == "unary" then
		assert(expr.value)
		display_token(expr.operator)
		display_expression(expr.value)
	elseif expr.kind == "var" then
		display_var(expr)
	elseif expr.kind == "vector" then
		display_delimited(expr.contents, generate_separated(display_expression))
	end
end

--#endregion
--#region last statements

function display_break(stat: ast.Break) display_token(stat.token) end

function display_continue(stat: ast.Continue) display_token(stat.token) end

function display_return(stat: ast.Return)
	display_token(stat.token)
	display_separated(stat.values, display_expression)
end

function display_last_statement(stat: ast.LastStatement)
	write_line()
	if stat.kind == "break" then
		display_break(stat)
	elseif stat.kind == "continue" then
		display_continue(stat)
	elseif stat.kind == "return" then
		display_return(stat)
	end
end

--#endregion
--#region IF BRANCHES
function display_else_branch(branch: ast.ElseBranch)
	display_token(branch.token)
	display_delimited(branch.block, display_block)
end

function display_elseif_branch(branch: ast.ElseIfBranch)
	display_token(branch.ifelse)
	display_if_branch(branch.branch)
end

function display_if_branch(branch: ast.IfBranch)
	display_delimited(branch.condition, display_expression)
	display_delimited(branch.block, display_block)
end
--#endregion
--#region statements
function display_while(stat: ast.While)
	display_token(stat.token)
	display_delimited(stat.condition, display_expression)
	display_delimited(stat.block, display_block)
end

function display_if(stat: ast.If)
	display_token(stat.token)
	display_if_branch(stat.first_branch)

	if stat.branches then
		for _, branch in stat.branches do
			display_elseif_branch(branch)
		end
	end

	if stat.else_branch then display_else_branch(stat.else_branch) end
end

function display_for(stat: ast.For)
	assert(stat.body)
	display_token(stat.token)
	display_delimited(stat.expression, display_expression)
	display_expression(stat.body)
end

function display_command(stat: ast.Command)
	display_var(stat.var)
	for _, argument in stat.arguments do
		display_expression(argument)
		write_char(char " ")
	end
end

function display_assign(stat: ast.Assign)
	assert(stat.value)
	display_token(stat.identifier)
	display_token(stat.equals)
	display_expression(stat.value)
end

function display_statement(statement: ast.Statement)
	if statement.kind == "assign" then
		display_assign(statement)
	elseif statement.kind == "command" then
		display_command(statement)
	elseif statement.kind == "for" then
		display_for(statement)
	elseif statement.kind == "if" then
		display_if(statement)
	elseif statement.kind == "while" then
		display_while(statement)
	end
end
--#endregion

function display_block(block: ast.Block)
	write_line()
	for _, statement in block.body do
		display_statement(statement)
		write_line()
	end
	if not block.last_statement then return end
	display_last_statement(block.last_statement)
end

return function(ast: ast.Ast): string
	pos = 0
	tbs = 0

	display_block(ast.block)

	return buffer.readstring(buf, 0, pos)
end
