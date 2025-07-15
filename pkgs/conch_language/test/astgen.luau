local ast = require "../src/ast/ast"

local span = vector.zero
local astgen = {}

local function token<T>(value: T | ast.TokenKind, text: string?): ast.Token
	return {
		kind = value,
		text = text or value,
		span = span,
	}
end

local function delimit<L, R, V>(
	left: L | ast.TokenKindRest,
	right: R | ast.TokenKindRest,
	value: V
): ast.Delimited<L, V, R>
	return { left = token(left), right = token(right), value = value }
end

local function separate<T>(array: { T }): ast.Separated<T>
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

function astgen.if_branch(
	condition: ast.Expression | ast.ExpressionCommand,
	block: ast.Block
): ast.IfBranch
	return {
		condition = delimit("(", ")", condition),
		block = delimit("{", "}", block),
		span = span,
	}
end

function astgen.if_else_branch(branch: ast.IfBranch)
	return {
		ifelse = token "elseif",
		branch = branch,
		span = span,
	}
end

function astgen.else_branch(block: ast.Block): ast.ElseBranch
	return {
		token = token "else",
		block = delimit("{", "}", block),
		span = span,
	}
end

function astgen.stat_if(
	if_branch: ast.IfBranch,
	branches: { ast.ElseIfBranch }?,
	else_branch: ast.ElseBranch?
): ast.If
	return {
		kind = "if",
		token = token "if",

		first_branch = if_branch,
		branches = branches or {},

		else_branch = else_branch,

		span = span,
	}
end

function astgen.stat_while(
	condition: ast.Expression | ast.ExpressionCommand,
	block: ast.Block
): ast.While
	return {
		kind = "while",
		token = token "while",
		condition = delimit("(", ")", condition),
		block = delimit("{", "}", block),
		span = span,
	}
end

function astgen.stat_for(
	expression: ast.Expression | ast.ExpressionCommand,
	fn: ast.Expression | ast.ExpressionCommand
): ast.For
	return {
		kind = "for",
		token = token "for",
		expression = delimit("(", ")", expression),
		body = fn,
		span = span,
	}
end

function astgen.stat_command(
	var: ast.Var,
	arguments: { ast.SimpleExpression }
): ast.Command
	return {
		kind = "command",
		var = var,
		arguments = arguments,
		span = span,
	}
end

function astgen.stat_assign(
	ident: string,
	value: ast.Expression | ast.ExpressionCommand
): ast.Assign
	return {
		kind = "assign",
		identifier = token("identifier", ident),
		equals = token "=",
		value = value,
		span = span,
	}
end

function astgen.lstat_continue(): ast.Continue
	return {
		kind = "continue",
		token = token "continue",
		span = span,
	}
end

function astgen.lstat_break(): ast.Break
	return {
		kind = "break",
		token = token "break",
		span = span,
	}
end

function astgen.lstat_return(
	values: { ast.Expression | ast.ExpressionCommand? }
): ast.Return
	return {
		kind = "return",
		token = token "return",
		values = separate(values),
		span = span,
	}
end

function astgen.block(
	statements: { ast.Statement },
	last: ast.LastStatement?
): ast.Block
	return {
		body = statements,
		last_statement = last,
		span = span,
	}
end

function astgen.expr_table(values: { ast.TableField }): ast.ExpressionTable
	return {
		kind = "table",
		values = delimit("{", "}", separate(values)),
		span = span,
	}
end

function astgen.tablefield_nokey(
	value: ast.Expression | ast.ExpressionCommand
): ast.TableFieldNoKey
	return {
		kind = "nokey",
		value = value,
		span = span,
	}
end

function astgen.tablefield_expressionkey(
	key: ast.Expression | ast.ExpressionCommand,
	value: ast.Expression | ast.ExpressionCommand
): ast.TableFieldExpressionKey
	return {
		kind = "expression_key",

		key = delimit("[", "]", key),
		equals = token "=",
		value = value,

		span = span,
	}
end

function astgen.tablefield_namekey(
	key: string,
	value: ast.Expression | ast.ExpressionCommand
): ast.TableFieldNameKey
	return {
		kind = "name_key",
		name = token("identifier", key),
		equals = token "=",
		value = value,
		span = span,
	}
end

function astgen.var(root: ast.VarRoot, suffixes: { ast.VarSuffix }): ast.Var
	return {
		kind = "var",
		root = root,
		suffixes = suffixes,
		span = span,
	}
end

function astgen.varsuffix_expression_index(
	expression: ast.Expression | ast.ExpressionCommand
): ast.VarSuffixExpressionIndex
	return {
		kind = "expression_index",
		span = span,
		period = token ".",
		node = delimit("[", "]", expression),
	}
end

function astgen.varsuffix_name_index(name: string): ast.VarSuffixNameIndex
	return {
		kind = "name_index",
		span = span,
		period = token ".",
		name = token("identifier", name),
	}
end

function astgen.varroot_paren(
	expression: ast.Expression | ast.ExpressionCommand
): ast.VarRootParen
	return {
		kind = "paren",
		span = span,
		var = token "$",
		node = delimit("(", ")", expression),
	}
end

function astgen.varroot_var(name: string): ast.VarRootVariable
	return {
		kind = "name",
		var = token "$",
		name = token("identifier", name),
		span = span,
	}
end

function astgen.varroot_global(name: string): ast.VarRootGlobal
	return {
		kind = "global",
		token = token("identifier", name),
		span = span,
	}
end

function astgen.expr_command(command: ast.Command): ast.ExpressionCommand
	return {
		kind = "command",
		prefix = token "&",
		command = command,
		span = span,
	}
end

function astgen.expr_evaluate(
	expression: ast.Expression | ast.ExpressionCommand
): ast.ExpressionEvaluate
	return {
		kind = "evaluate",
		command = delimit("(", ")", expression),
		span = span,
	}
end

function astgen.expr_unary(
	operator: ast.UnaryOperator,
	expression: ast.Expression
): ast.ExpressionUnary
	return {
		kind = "unary",
		operator = token(operator),
		value = expression,
		span = span,
	}
end

function astgen.expr_vector(
	x: ast.Expression | ast.ExpressionCommand?,
	y: ast.Expression | ast.ExpressionCommand?,
	z: ast.Expression | ast.ExpressionCommand?
): ast.ExpressionVector
	return {
		kind = "vector",
		contents = delimit("[", "]", separate { x, y, z }),
		span = span,
	}
end

function astgen.function_body(
	arguments: { string },
	block: ast.Block
): ast.FunctionBody
	local args_identifiers: { ast.Token<"identifier"> | false } = {}

	for idx, arg in arguments do
		args_identifiers[idx] = token("identifier", arg)
	end

	return {
		arguments = delimit("|", "|", separate(args_identifiers)),
		block = delimit("{", "}", block),
		span = span,
	}
end

function astgen.expr_lambda(body: ast.FunctionBody): ast.ExpressionLambda
	return {
		kind = "lambda",
		body = body,
		span = span,
	}
end

function astgen.expr_string(input: string): ast.ExpressionString
	return {
		kind = "string",
		token = token("string", string.format("%q", input)),
		span = span,
	}
end

function astgen.arg_ident(input: string): ast.ExpressionString
	return {
		kind = "string",
		token = token("identifier", input),
		span = span,
	}
end

function astgen.expr_binary(
	left: ast.Expression,
	operator: ast.BinaryOperator,
	right: ast.Expression
): ast.ExpressionBinary
	return {
		kind = "binary",
		left = left,
		operator = token(operator),
		right = right,
		span = span,
	}
end

function astgen.expr_number(n: number): ast.ExpressionNumber
	return {
		kind = "number",
		token = token("number", tostring(n)),
		span = span,
	}
end

function astgen.expr_boolean(bool: boolean): ast.ExpressionBoolean
	local bool: "true" | "false" = tostring(bool) :: any
	return {
		kind = "boolean",
		token = token(bool),
		span = span,
	}
end

function astgen.expr_nil(): ast.ExpressionNil
	return {
		kind = "nil",
		token = token "nil",
		span = span,
	}
end

function astgen.to_ast(block: ast.Block): ast.Ast
	return {
		block = block,
	}
end

return astgen
