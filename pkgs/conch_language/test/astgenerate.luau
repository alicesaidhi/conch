local ast = require "./astgen"
local astt = require "../src/ast"

local LAST_STATEMENT_CHANCE = 0.5
local BRANCH_CHANCE = 0.8
local ELSE_BRANCH_CHANCE = 0.5
local ARGUMENT_CHANCE = 0.9
local IDENTIFIER_CHANCE = 0.4
local RETURN_VALUE_CHANCE = 0.5
local TABLEFIELD_CHANCE = 0.6
local SUFFIX_CHANCE = 0.6
local FN_ARGUMENT_CHANCE = 0.5

local total_statements_left = 0
local total_depth_left = 0

type Generate<T> = () -> T

local VALID_IDENTIFIER =
	string.split("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_@", "")
local UNARY_OPERATORS: { astt.UnaryOperator } = { "-", "!" }

local function biased_random(max: number)
	if max == 0 then return 0 end
	local min = 1
	return math.floor(
		math.abs(math.random() - math.random()) * (1 + max - min) + min
	)
end

local function unreachable(): never error "unreachable" end

local generate_identifier: Generate<string>
local generate_string: Generate<string>
local generate_number: Generate<number>

local generate_function_body: Generate<astt.FunctionBody>

local generate_var_root: Generate<astt.VarRoot>
local generate_var_suffix: Generate<astt.VarSuffix>
local generate_var: Generate<astt.Var>

local generate_unary: Generate<astt.ExpressionUnary>
local generate_tablefield: Generate<astt.TableField>
local generate_table: Generate<astt.ExpressionTable>
local generate_expression: Generate<astt.Expression>
local generate_expression_command: Generate<astt.Expression | astt.ExpressionCommand>

local generate_return: Generate<astt.Return>
local generate_last_statement: Generate<astt.LastStatement>

local generate_if_branch: Generate<astt.IfBranch>
local generate_elseif_branch: Generate<astt.ElseIfBranch>

local generate_assign: Generate<astt.Assign>
local generate_command: Generate<astt.Command>
local generate_for: Generate<astt.For>
local generate_if: Generate<astt.If>
local generate_while: Generate<astt.While>
local generate_statement: Generate<astt.Statement>

local generate_block: (n: number) -> astt.Block

function generate_identifier(): string
	local s = buffer.create(math.random(2, 8))
	buffer.writeu8(s, 0, (string.byte "A"))

	for i = 1, buffer.len(s) - 1 do
		local n = string.byte(VALID_IDENTIFIER[math.random(#VALID_IDENTIFIER)])
		buffer.writeu8(s, i, n)
	end

	return buffer.tostring(s)
end

function generate_string(): string
	local s = buffer.create(math.random(8))

	for i = 0, buffer.len(s) - 1 do
		buffer.writeu8(s, i, math.random(0, 255))
	end

	return buffer.tostring(s)
end

function generate_number(): number return math.random() * 10000 end

function generate_function_body(): astt.FunctionBody
	local arguments = {}

	while math.random() < FN_ARGUMENT_CHANCE do
		table.insert(arguments, generate_identifier())
	end

	return ast.function_body(
		arguments,
		generate_block(biased_random(total_statements_left))
	)
end

function generate_var_root(): astt.VarRoot
	local n = math.random(3)

	if n == 1 then
		return ast.varroot_global(generate_identifier())
	elseif n == 2 then
		return ast.varroot_paren(generate_expression_command())
	elseif n == 3 then
		return ast.varroot_var(generate_identifier())
	else
		error "unreachable"
	end
end

function generate_var_suffix(): astt.VarSuffix
	local n = math.random(2)

	if n == 1 then
		return ast.varsuffix_expression_index(generate_expression_command())
	elseif n == 2 then
		return ast.varsuffix_name_index(generate_identifier())
	else
		error "unreachable"
	end
end

function generate_var(): astt.Var
	local suffixes = {}

	while math.random() < SUFFIX_CHANCE and total_depth_left >= 0 do
		table.insert(suffixes, generate_var_suffix())
	end

	return ast.var(generate_var_root(), suffixes)
end

function generate_unary(): astt.ExpressionUnary
	local expr = generate_expression()

	while expr.kind == "unary" do
		expr = generate_expression()
	end

	return ast.expr_unary(UNARY_OPERATORS[math.random(#UNARY_OPERATORS)], expr)
end

function generate_tablefield(): astt.TableField
	local n = math.random(3)

	if n == 1 then
		return ast.tablefield_namekey(
			generate_identifier(),
			generate_expression_command()
		)
	elseif n == 2 then
		return ast.tablefield_expressionkey(
			generate_expression_command(),
			generate_expression_command()
		)
	elseif n == 3 then
		return ast.tablefield_nokey(generate_expression_command())
	else
		error "unreachable"
	end
end

function generate_table(): astt.ExpressionTable
	total_depth_left -= 1
	local fields = {}

	while math.random() < TABLEFIELD_CHANCE and total_depth_left >= 0 do
		table.insert(fields, generate_tablefield())
	end

	total_depth_left += 1
	return ast.expr_table(fields)
end

local function generate_vector(): astt.ExpressionVector
	total_depth_left -= 1
	local x = generate_expression_command()
	local y = generate_expression_command()
	local z = generate_expression_command()
	total_depth_left += 1

	return ast.expr_vector(x, y, z)
end

local function _generate_expression(
	command: boolean?
): astt.Expression | astt.ExpressionCommand
	if total_depth_left <= 0 then return ast.expr_number(10) end

	local n = math.random(if command then 11 else 10)

	if n == 1 then
		return ast.expr_nil()
	elseif n == 2 then
		return ast.expr_boolean(math.random() > 0.5)
	elseif n == 3 then
		return ast.expr_number(generate_number())
	elseif n == 4 then
		return ast.expr_string(generate_string())
	elseif n == 5 then
		return generate_table()
	elseif n == 6 then
		return ast.expr_lambda(generate_function_body())
	elseif n == 7 then
		return ast.expr_evaluate(generate_expression_command())
	elseif n == 8 then
		return generate_var()
	elseif n == 9 then
		return generate_unary()
	elseif n == 10 then
		return generate_vector()
	elseif n == 11 then
		return ast.expr_command(generate_command())
	else
		--todo: test binaryn odes
		error "unreachable"
	end
end

local function generate_expression_novar(): astt.Expression
	local n = math.random(9)

	if n == 1 then
		return ast.expr_nil()
	elseif n == 2 then
		return ast.expr_boolean(math.random() > 0.5)
	elseif n == 3 then
		return ast.expr_number(generate_number())
	elseif n == 4 then
		return ast.expr_string(generate_string())
	elseif n == 5 then
		return generate_table()
	elseif n == 6 then
		return ast.expr_lambda(generate_function_body())
	elseif n == 7 then
		return ast.expr_evaluate(generate_expression_command())
	elseif n == 8 then
		return generate_unary()
	elseif n == 9 then
		return generate_vector()
	else
		--todo: test binaryn odes
		error "unreachable"
	end
end

generate_expression = function() return _generate_expression(false) end :: () -> astt.Expression

generate_expression_command = function() return _generate_expression(true) end :: () -> astt.ExpressionCommand | astt.Expression

function generate_return(): astt.Return
	local values = {}

	while math.random() < RETURN_VALUE_CHANCE do
		table.insert(values, generate_expression_command())
	end

	return ast.lstat_return(values)
end

function generate_last_statement(): astt.LastStatement
	local n = math.random(3)

	if n == 1 then
		return ast.lstat_break()
	elseif n == 2 then
		return ast.lstat_continue()
	elseif n == 3 then
		return generate_return()
	else
		error "unreachable"
	end
end

function generate_if_branch(): astt.IfBranch
	return ast.if_branch(
		generate_expression_command(),
		generate_block(biased_random(total_statements_left))
	)
end

function generate_elseif_branch(): astt.ElseIfBranch
	return ast.if_else_branch(generate_if_branch())
end

function generate_assign(): astt.Assign
	local name = generate_identifier()
	local value = generate_expression_command()

	return ast.stat_assign(name, value)
end

function generate_command(): astt.Command
	local arguments = {}

	while math.random() < ARGUMENT_CHANCE do
		if math.random() < IDENTIFIER_CHANCE then
			table.insert(arguments, ast.arg_ident(generate_identifier()))
		else
			table.insert(arguments, generate_expression_novar())
		end
	end

	return ast.stat_command(generate_var(), arguments)
end

function generate_for(): astt.For
	return ast.stat_for(
		generate_expression_command(),
		generate_expression_command()
	)
end

function generate_if(): astt.If
	local branches = {}
	local should_else = math.random() < ELSE_BRANCH_CHANCE

	while math.random() < BRANCH_CHANCE do
		table.insert(branches, generate_elseif_branch())
	end

	local first_branch = generate_if_branch()
	local else_branch = if should_else
		then ast.else_branch(
			generate_block(biased_random(total_statements_left))
		)
		else nil

	return ast.stat_if(first_branch, branches, else_branch)
end

function generate_while(): astt.While
	return ast.stat_while(
		generate_expression_command(),
		generate_block(biased_random(total_statements_left))
	)
end

function generate_statement(): astt.Statement
	local n = math.random(5)

	if n == 1 then
		return generate_assign()
	elseif n == 2 then
		return generate_command()
	elseif n == 3 then
		return generate_for()
	elseif n == 4 then
		return generate_if()
	elseif n == 5 then
		return generate_while()
	else
		return unreachable()
	end
end

function generate_block(n: number?)
	total_depth_left -= 1

	local statements_left = n or total_statements_left
	local should_last = math.random() < LAST_STATEMENT_CHANCE
	local statements: { astt.Statement } = {}

	while statements_left > 0 and total_depth_left >= 0 do
		statements_left -= 1
		total_statements_left -= 1
		table.insert(statements, generate_statement())
	end

	local last_statement = if should_last
		then generate_last_statement()
		else nil

	total_depth_left += 1
	return ast.block(statements, last_statement)
end

local seed = 0
local function generate_ast(n: number): astt.Ast
	math.randomseed(seed)
	seed += 1

	total_statements_left = n
	total_depth_left = 3
	return {
		block = generate_block(),
	}
end

return generate_ast
