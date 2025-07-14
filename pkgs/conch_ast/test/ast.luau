local astp = require "../src/ast"

local span = vector.zero
local ast = {}

local function token<T>(value: T | astp.TokenKind, text: string?): astp.Token
	return {
		kind = value,
		text = text or value,
		span = span,
	}
end

local function delimit<L, R, V>(
	left: L | astp.TokenKindRest,
	right: R | astp.TokenKindRest,
	value: V
): astp.Delimited<L, V, R>
	return { left = token(left), right = token(right), value = value }
end

local function separate<T>(array: { T }): astp.Separated<T>
	local map = {}

	for idx, value in array do
		map[idx] = {
			value = value,
			separator = token ",",
			span = span,
		}
	end

	return map
end

function ast.if_branch(
	condition: astp.Expression | astp.ExpressionCommand,
	block: astp.Block
): astp.IfBranch
	return {
		condition = delimit("(", ")", condition),
		block = delimit("{", "}", block),
		span = span,
	}
end

function ast.if_else_branch(branch: astp.IfBranch)
	return {
		ifelse = token "elseif",
		branch = branch,
		span = span,
	}
end

function ast.else_branch(block: astp.Block): astp.ElseBranch
	return {
		token = token "else",
		block = delimit("{", "}", block),
		span = span,
	}
end

function ast.stat_if(
	if_branch: astp.IfBranch,
	branches: { astp.ElseIfBranch }?,
	else_branch: astp.ElseBranch?
): astp.If
	return {
		kind = "if",
		token = token "if",

		first_branch = if_branch,
		branches = branches or {},

		else_branch = else_branch,

		span = span,
	}
end

function ast.stat_while(
	condition: astp.Expression | astp.ExpressionCommand,
	block: astp.Block
): astp.While
	return {
		kind = "while",
		token = token "while",
		condition = delimit("(", ")", condition),
		block = delimit("{", "}", block),
		span = span,
	}
end

function ast.stat_for(
	expression: astp.Expression | astp.ExpressionCommand,
	fn: astp.Expression | astp.ExpressionCommand
): astp.For
	return {
		kind = "for",
		token = token "for",
		expression = delimit("(", ")", expression),
		body = fn,
		span = span,
	}
end

function ast.stat_command(
	var: astp.Var,
	arguments: { astp.SimpleExpression }
): astp.Command
	return {
		kind = "command",
		var = var,
		arguments = arguments,
		span = span,
	}
end

function ast.stat_assign(
	ident: string,
	value: astp.Expression | astp.ExpressionCommand
): astp.Assign
	return {
		kind = "assign",
		identifier = token("identifier", ident),
		equals = token "=",
		value = value,
		span = span,
	}
end

function ast.lstat_continue(): astp.Continue
	return {
		kind = "continue",
		token = token "continue",
		span = span,
	}
end

function ast.lstat_break(): astp.Break
	return {
		kind = "break",
		token = token "break",
		span = span,
	}
end

function ast.lstat_return(
	values: { astp.Expression | astp.ExpressionCommand? }
): astp.Return
	return {
		kind = "return",
		token = token "return",
		values = separate(values),
		span = span,
	}
end

function ast.block(
	statements: { astp.Statement },
	last: astp.LastStatement?
): astp.Block
	return {
		body = statements,
		last_statement = last,
		span = span,
	}
end

function ast.expr_table(values: { astp.TableField }): astp.ExpressionTable
	return {
		kind = "table",
		values = delimit("{", "}", separate(values)),
		span = span,
	}
end

function ast.tablefield_nokey(
	value: astp.Expression | astp.ExpressionCommand
): astp.TableFieldNoKey
	return {
		kind = "nokey",
		value = value,
		span = span,
	}
end

function ast.tablefield_expressionkey(
	key: astp.Expression | astp.ExpressionCommand,
	value: astp.Expression | astp.ExpressionCommand
): astp.TableFieldExpressionKey
	return {
		kind = "expression_key",

		key = delimit("[", "]", key),
		equals = token "=",
		value = value,

		span = span,
	}
end

function ast.tablefield_namekey(
	key: string,
	value: astp.Expression | astp.ExpressionCommand
): astp.TableFieldNameKey
	return {
		kind = "name_key",
		name = token("identifier", key),
		equals = token "=",
		value = value,
		span = span,
	}
end

function ast.var(root: astp.VarRoot, suffixes: { astp.VarSuffix }): astp.Var
	return {
		kind = "var",
		root = root,
		suffixes = suffixes,
		span = span,
	}
end

function ast.varsuffix_expression_index(
	expression: astp.Expression | astp.ExpressionCommand
): astp.VarSuffixExpressionIndex
	return {
		kind = "expression_index",
		span = span,
		period = token ".",
		node = delimit("[", "]", expression),
	}
end

function ast.varsuffix_name_index(name: string): astp.VarSuffixNameIndex
	return {
		kind = "name_index",
		span = span,
		period = token ".",
		name = token("identifier", name),
	}
end

function ast.varroot_paren(
	expression: astp.Expression | astp.ExpressionCommand
): astp.VarRootParen
	return {
		kind = "paren",
		span = span,
		var = token "$",
		node = delimit("(", ")", expression),
	}
end

function ast.varroot_var(name: string): astp.VarRootVariable
	return {
		kind = "name",
		var = token "$",
		name = token("identifier", name),
		span = span,
	}
end

function ast.varroot_global(name: string): astp.VarRootGlobal
	return {
		kind = "global",
		token = token("identifier", name),
		span = span,
	}
end

function ast.expr_command(command: astp.Command): astp.ExpressionCommand
	return {
		kind = "command",
		prefix = token "&",
		command = command,
		span = span,
	}
end

function ast.expr_evaluate(
	expression: astp.Expression | astp.ExpressionCommand
): astp.ExpressionEvaluate
	return {
		kind = "evaluate",
		command = delimit("(", ")", expression),
		span = span,
	}
end

function ast.expr_unary(
	operator: astp.UnaryOperator,
	expression: astp.Expression
): astp.ExpressionUnary
	return {
		kind = "unary",
		operator = token(operator),
		value = expression,
		span = span,
	}
end

function ast.expr_vector(
	x: astp.Expression | astp.ExpressionCommand?,
	y: astp.Expression | astp.ExpressionCommand?,
	z: astp.Expression | astp.ExpressionCommand?
): astp.ExpressionVector
	return {
		kind = "vector",
		contents = delimit("[", "]", separate { x, y, z }),
		span = span,
	}
end

function ast.function_body(
	arguments: { string },
	block: astp.Block
): astp.FunctionBody
	local args_identifiers: { astp.Token<"identifier"> | false } = {}

	for idx, arg in arguments do
		args_identifiers[idx] = token("identifier", arg)
	end

	return {
		arguments = delimit("|", "|", separate(args_identifiers)),
		block = delimit("{", "}", block),
		span = span,
	}
end

function ast.expr_lambda(body: astp.FunctionBody): astp.ExpressionLambda
	return {
		kind = "lambda",
		body = body,
		span = span,
	}
end

function ast.expr_string(input: string): astp.ExpressionString
	return {
		kind = "string",
		token = token("string", string.format("%q", input)),
		span = span,
	}
end

function ast.arg_ident(input: string): astp.ExpressionString
	return {
		kind = "string",
		token = token("identifier", input),
		span = span,
	}
end

function ast.expr_binary(
	left: astp.Expression,
	operator: astp.BinaryOperator,
	right: astp.Expression
): astp.ExpressionBinary
	return {
		kind = "binary",
		left = left,
		operator = token(operator),
		right = right,
		span = span,
	}
end

function ast.expr_number(n: number): astp.ExpressionNumber
	return {
		kind = "number",
		token = token("number", tostring(n)),
		span = span,
	}
end

function ast.expr_boolean(bool: boolean): astp.ExpressionBoolean
	local bool: "true" | "false" = tostring(bool) :: any
	return {
		kind = "boolean",
		token = token(bool),
		span = span,
	}
end

function ast.expr_nil(): astp.ExpressionNil
	return {
		kind = "nil",
		token = token "nil",
		span = span,
	}
end

function ast.to_ast(block: astp.Block): astp.Ast
	return {
		block = block,
	}
end

return ast
