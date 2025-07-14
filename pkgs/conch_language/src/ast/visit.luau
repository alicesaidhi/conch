local ast = require "./ast"

export type Visitor<State> = {
	visit_block: (State, ast.Block) -> (),
	visit_block_end: (State, ast.Block) -> (),
	visit_token: (State, ast.Token<ast.TokenKind>) -> (),
	visit_fn_argument: (State, ast.Token<ast.TokenKind>) -> (),

	visit_command: (State, ast.Command) -> (),
	visit_command_end: (State, ast.Command) -> (),

	visit_statement: (State, ast.Statement) -> (),
	visit_statement_end: (State, ast.Statement) -> (),
	visit_stat_for: (State, ast.For) -> (),
	visit_stat_for_end: (State, ast.For) -> (),
	visit_stat_while: (State, ast.While) -> (),
	visit_stat_while_end: (State, ast.While) -> (),
	visit_stat_if: (State, ast.If) -> (),
	visit_stat_if_end: (State, ast.If) -> (),
	visit_stat_assign: (State, ast.Assign) -> (),
	visit_stat_assign_end: (State, ast.Assign) -> (),
	visit_stat_command: (State, ast.Command) -> (),
	visit_stat_command_end: (State, ast.Command) -> (),

	visit_if_branch: (State, ast.IfBranch) -> (),
	visit_if_branch_end: (State, ast.IfBranch) -> (),
	visit_elseif_branch: (State, ast.ElseIfBranch) -> (),
	visit_elseif_branch_end: (State, ast.ElseIfBranch) -> (),
	visit_else_branch: (State, ast.ElseBranch) -> (),
	visit_else_branch_end: (State, ast.ElseBranch) -> (),

	visit_last_statement: (State, ast.LastStatement) -> (),
	visit_last_statement_end: (State, ast.LastStatement) -> (),
	visit_return: (State, ast.Return) -> (),
	visit_return_end: (State, ast.Return) -> (),
	visit_break: (State, ast.Break) -> (),
	visit_break_end: (State, ast.Break) -> (),
	visit_continue: (State, ast.Continue) -> (),
	visit_continue_end: (State, ast.Continue) -> (),

	visit_table: (State, ast.ExpressionTable) -> (),
	visit_table_end: (State, ast.ExpressionTable) -> (),
	visit_tablefield: (State, ast.TableField) -> (),
	visit_tablefield_end: (State, ast.TableField) -> (),
	visit_tablefield_nokey: (State, ast.TableFieldNoKey) -> (),
	visit_tablefield_nokey_end: (State, ast.TableFieldNoKey) -> (),
	visit_tablefield_namekey: (State, ast.TableFieldNameKey) -> (),
	visit_tablefield_namekey_end: (State, ast.TableFieldNameKey) -> (),
	visit_tablefield_exprkey: (State, ast.TableFieldExpressionKey) -> (),
	visit_tablefield_exprkey_end: (State, ast.TableFieldExpressionKey) -> (),

	visit_var: (State, ast.Var) -> (),
	visit_var_end: (State, ast.Var) -> (),
	visit_var_suffix: (State, ast.VarSuffix) -> (),
	visit_var_suffix_end: (State, ast.VarSuffix) -> (),
	visit_var_suffix_expression: (State, ast.VarSuffixExpressionIndex) -> (),
	visit_var_suffix_expression_end: (
		State,
		ast.VarSuffixExpressionIndex
	) -> (),
	visit_var_suffix_name: (State, ast.VarSuffixNameIndex) -> (),
	visit_var_suffix_name_end: (State, ast.VarSuffixNameIndex) -> (),
	visit_var_root: (State, ast.VarRoot) -> (),
	visit_var_root_end: (State, ast.VarRoot) -> (),
	visit_var_root_paren: (State, ast.VarRootParen) -> (),
	visit_var_root_paren_end: (State, ast.VarRootParen) -> (),
	visit_var_root_variable: (State, ast.VarRootVariable) -> (),
	visit_var_root_variable_end: (State, ast.VarRootVariable) -> (),
	visit_var_root_global: (State, ast.VarRootGlobal) -> (),
	visit_var_root_global_end: (State, ast.VarRootGlobal) -> (),

	visit_expression: (State, ast.Expression | ast.ExpressionCommand) -> (),
	visit_expression_end: (State, ast.Expression | ast.ExpressionCommand) -> (),
	visit_expr_command: (State, ast.ExpressionCommand) -> (),
	visit_expr_command_end: (State, ast.ExpressionCommand) -> (),
	visit_expr_evaluate: (State, ast.ExpressionEvaluate) -> (),
	visit_expr_evaluate_end: (State, ast.ExpressionEvaluate) -> (),
	visit_expr_unary: (State, ast.ExpressionUnary) -> (),
	visit_expr_unary_end: (State, ast.ExpressionUnary) -> (),
	visit_expr_vector: (State, ast.ExpressionVector) -> (),
	visit_expr_vector_end: (State, ast.ExpressionVector) -> (),
	visit_expr_lambda: (State, ast.ExpressionLambda) -> (),
	visit_expr_lambda_end: (State, ast.ExpressionLambda) -> (),
	visit_expr_string: (State, ast.ExpressionString) -> (),
	visit_expr_string_end: (State, ast.ExpressionString) -> (),
	visit_expr_binary: (State, ast.ExpressionBinary) -> (),
	visit_expr_binary_end: (State, ast.ExpressionBinary) -> (),
	visit_expr_number: (State, ast.ExpressionNumber) -> (),
	visit_expr_number_end: (State, ast.ExpressionNumber) -> (),
	visit_expr_boolean: (State, ast.ExpressionBoolean) -> (),
	visit_expr_boolean_end: (State, ast.ExpressionBoolean) -> (),
	visit_expr_var: (State, ast.Var) -> (),
	visit_expr_var_end: (State, ast.Var) -> (),
	visit_expr_nil: (State, ast.ExpressionNil) -> (),
	visit_expr_nil_end: (State, ast.ExpressionNil) -> (),
}

local function create_visitor<State>(): Visitor<State>
	local noop: any = function() end

	return {
		visit_block = noop,
		visit_block_end = noop,
		visit_token = noop,
		visit_fn_argument = noop,

		visit_command = noop,
		visit_command_end = noop,

		visit_statement = noop,
		visit_statement_end = noop,
		visit_stat_for = noop,
		visit_stat_for_end = noop,
		visit_stat_while = noop,
		visit_stat_while_end = noop,
		visit_stat_if = noop,
		visit_stat_if_end = noop,
		visit_stat_assign = noop,
		visit_stat_assign_end = noop,
		visit_stat_command = noop,
		visit_stat_command_end = noop,

		visit_if_branch = noop,
		visit_if_branch_end = noop,
		visit_elseif_branch = noop,
		visit_elseif_branch_end = noop,
		visit_else_branch = noop,
		visit_else_branch_end = noop,

		visit_last_statement = noop,
		visit_last_statement_end = noop,
		visit_return = noop,
		visit_return_end = noop,
		visit_break = noop,
		visit_break_end = noop,
		visit_continue = noop,
		visit_continue_end = noop,

		visit_table = noop,
		visit_table_end = noop,
		visit_tablefield = noop,
		visit_tablefield_end = noop,
		visit_tablefield_nokey = noop,
		visit_tablefield_nokey_end = noop,
		visit_tablefield_namekey = noop,
		visit_tablefield_namekey_end = noop,
		visit_tablefield_exprkey = noop,
		visit_tablefield_exprkey_end = noop,

		visit_var = noop,
		visit_var_end = noop,
		visit_var_suffix = noop,
		visit_var_suffix_end = noop,
		visit_var_suffix_expression = noop,
		visit_var_suffix_expression_end = noop,
		visit_var_suffix_name = noop,
		visit_var_suffix_name_end = noop,
		visit_var_root = noop,
		visit_var_root_end = noop,
		visit_var_root_paren = noop,
		visit_var_root_paren_end = noop,
		visit_var_root_variable = noop,
		visit_var_root_variable_end = noop,
		visit_var_root_global = noop,
		visit_var_root_global_end = noop,

		visit_expression = noop,
		visit_expression_end = noop,
		visit_expr_command = noop,
		visit_expr_command_end = noop,
		visit_expr_evaluate = noop,
		visit_expr_evaluate_end = noop,
		visit_expr_unary = noop,
		visit_expr_unary_end = noop,
		visit_expr_vector = noop,
		visit_expr_vector_end = noop,
		visit_expr_lambda = noop,
		visit_expr_lambda_end = noop,
		visit_expr_string = noop,
		visit_expr_string_end = noop,
		visit_expr_binary = noop,
		visit_expr_binary_end = noop,
		visit_expr_number = noop,
		visit_expr_number_end = noop,
		visit_expr_boolean = noop,
		visit_expr_boolean_end = noop,
		visit_expr_var = noop,
		visit_expr_var_end = noop,
		visit_expr_nil = noop,
		visit_expr_nil_end = noop,
	}
end

local visit_command: <State>(visitor: Visitor<State>, state: State, node: ast.Command) -> ()
local visit_var: <State>(visitor: Visitor<State>, state: State, node: ast.Var) -> ()
local visit_expr: <State>(
	visitor: Visitor<State>,
	state: State,
	node: ast.Expression | ast.ExpressionCommand
) -> ()
local visit_last_stat: <State>(
	visitor: Visitor<State>,
	state: State,
	node: ast.LastStatement
) -> ()
local visit_stat: <State>(
	visitor: Visitor<State>,
	state: State,
	node: ast.Statement
) -> ()
local visit_block: <State>(visitor: Visitor<State>, state: State, node: ast.Block) -> ()

local function visit_token<State>(
	visitor: Visitor<State>,
	state: State,
	token: ast.Token
)
	visitor.visit_token(state, token)
end

local function visit_delimited<State, T>(
	visitor: Visitor<State>,
	state: State,
	fn: (Visitor<State>, State, T) -> (),
	delimited: ast.Delimited<
		ast.TokenKind,
		T,
		ast.TokenKind
	>
)
	visit_token(visitor, state, delimited.left)

	if delimited.value then fn(visitor, state, delimited.value) end

	if delimited.right then visit_token(visitor, state, delimited.right) end
end

local function visit_separated<State, T>(
	visitor: Visitor<State>,
	state: State,
	fn: (Visitor<State>, State, T) -> (),
	separated: ast.Separated<T>
)
	for _, node in separated do
		fn(visitor, state, node.value)
		if node.separator then visit_token(visitor, state, node.separator) end
	end
end

local function gen_separated<State, T>(fn: (Visitor<State>, State, T) -> ())
	return function(
		visitor: Visitor<State>,
		state: State,
		separated: ast.Separated<T>
	)
		visit_separated(visitor, state, fn, separated)
	end
end

local function visit_argument<State>(
	visitor: Visitor<State>,
	state: State,
	token: ast.Token
)
	visitor.visit_fn_argument(visitor, state)
	visit_token(visitor, state, token)
end

local function visit_tablefield<State>(
	visitor: Visitor<State>,
	state: State,
	token: ast.TableField
)
	visitor.visit_tablefield(state, token)

	if token.kind == "expression_key" then
		visitor.visit_tablefield_exprkey(state, token)

		if token.key then
			visit_delimited(visitor, state, visit_expr, token.key)
		end

		if token.equals then visit_token(visitor, state, token.equals) end

		if token.value then visit_expr(visitor, state, token.value) end

		visitor.visit_tablefield_exprkey_end(state, token)
	elseif token.kind == "name_key" then
		visitor.visit_tablefield_namekey(state, token)

		visit_token(visitor, state, token.name)
		visit_token(visitor, state, token.equals)

		if token.value then visit_expr(visitor, state, token.value) end

		visitor.visit_tablefield_namekey_end(state, token)
	elseif token.kind == "nokey" then
		visitor.visit_tablefield_nokey(state, token)

		if token.value then visit_expr(visitor, state, token.value) end

		visitor.visit_tablefield_nokey_end(state, token)
	end

	visitor.visit_tablefield_end(state, token)
end

function visit_var<State>(visitor: Visitor<State>, state: State, node: ast.Var)
	visitor.visit_var(state, node)

	visitor.visit_var_root(state, node.root)
	if node.root.kind == "global" then
		visitor.visit_var_root_global(state, node.root)
		visit_token(visitor, state, node.root.token)
		visitor.visit_var_root_global_end(state, node.root)
	elseif node.root.kind == "name" then
		visitor.visit_var_root_variable(state, node.root)

		visit_token(visitor, state, node.root.var)
		if node.root.name then visit_token(visitor, state, node.root.name) end

		visitor.visit_var_root_variable_end(state, node.root)
	elseif node.root.kind == "paren" then
		visitor.visit_var_root_paren(state, node.root)

		visit_token(visitor, state, node.root.var)
		visit_delimited(visitor, state, visit_expr, node.root.node)

		visitor.visit_var_root_paren_end(state, node.root)
	end
	visitor.visit_var_root_end(state, node.root)

	for _, suffix in node.suffixes do
		visitor.visit_var_suffix(state, suffix)
		if suffix.kind == "expression_index" then
			visitor.visit_var_suffix_expression(state, suffix)

			visit_token(visitor, state, suffix.period)
			visit_delimited(visitor, state, visit_expr, suffix.node)

			visitor.visit_var_suffix_expression_end(state, suffix)
		elseif suffix.kind == "name_index" then
			visitor.visit_var_suffix_name(state, suffix)

			visit_token(visitor, state, suffix.period)
			if suffix.name then visit_token(visitor, state, suffix.name) end

			visitor.visit_var_suffix_name_end(state, suffix)
		end
		visitor.visit_var_suffix_end(state, suffix)
	end

	visitor.visit_var_end(state, node)
end

function visit_expr<State>(
	visitor: Visitor<State>,
	state: State,
	node: ast.Expression | ast.ExpressionCommand
)
	visitor.visit_expression(state, node)

	if node.kind == "binary" then
		visitor.visit_expr_binary(state, node)

		visit_expr(visitor, state, node.left)
		visit_token(visitor, state, node.operator)
		if node.right then visit_expr(visitor, state, node.right) end

		visitor.visit_expr_binary_end(state, node)
	elseif node.kind == "boolean" then
		visitor.visit_expr_boolean(state, node)

		visit_token(visitor, state, node.token)

		visitor.visit_expr_boolean_end(state, node)
	elseif node.kind == "evaluate" then
		visitor.visit_expr_evaluate(state, node)

		visit_delimited(visitor, state, visit_expr, node.command)

		visitor.visit_expr_evaluate_end(state, node)
	elseif node.kind == "lambda" then
		visitor.visit_expr_lambda(state, node)

		visit_delimited(
			visitor,
			state,
			gen_separated(visit_argument),
			node.body.arguments
		)

		if node.body.block then
			visit_delimited(visitor, state, visit_block, node.body.block)
		end

		visitor.visit_expr_lambda_end(state, node)
	elseif node.kind == "nil" then
		visitor.visit_expr_nil(state, node)

		visit_token(visitor, state, node.token)

		visitor.visit_expr_nil_end(state, node)
	elseif node.kind == "number" then
		visitor.visit_expr_number(state, node)

		visit_token(visitor, state, node.token)

		visitor.visit_expr_number_end(state, node)
	elseif node.kind == "string" then
		visitor.visit_expr_string(state, node)

		visit_token(visitor, state, node.token)

		visitor.visit_expr_string_end(state, node)
	elseif node.kind == "table" then
		visitor.visit_table(state, node)

		visit_delimited(
			visitor,
			state,
			gen_separated(visit_tablefield),
			node.values
		)

		visitor.visit_table_end(state, node)
	elseif node.kind == "unary" then
		visitor.visit_expr_unary(state, node)

		visit_token(visitor, state, node.operator)
		if node.value then visit_expr(visitor, state, node.value) end

		visitor.visit_expr_unary_end(state, node)
	elseif node.kind == "command" then
		visitor.visit_expr_command(state, node)

		visitor.visit_token(state, node.prefix)
		if node.command then visitor.visit_command(state, node.command) end

		visitor.visit_expr_command_end(state, node)
	elseif node.kind == "var" then
		visitor.visit_expr_var(state, node)
		visit_var(visitor, state, node)
		visitor.visit_expr_var_end(state, node)
	elseif node.kind == "vector" then
		visitor.visit_expr_vector(state, node)

		visit_delimited(
			visitor,
			state,
			gen_separated(visit_expr),
			node.contents
		)

		visitor.visit_expr_vector_end(state, node)
	end

	visitor.visit_expression_end(state, node)
end

function visit_command<State>(visitor: Visitor<State>, state: State, node: ast.Command)
	visitor.visit_command(state, node)

	visit_var(visitor, state, node.var)

	for _, argument in node.arguments do
		visit_expr(visitor, state, argument)
	end

	visitor.visit_command_end(state, node)
end

local function visit_if_branch<State>(
	visitor: Visitor<State>,
	state: State,
	node: ast.IfBranch
)
	visitor.visit_if_branch(state, node)

	visitor.visit_if_branch_end(state, node)
end

function visit_stat<State>(visitor: Visitor<State>, state: State, node: ast.Statement)
	visitor.visit_statement(state, node)

	if node.kind == "assign" then
		visitor.visit_stat_assign(state, node)

		visitor.visit_token(state, node.identifier)
		visitor.visit_token(state, node.equals)
		if node.value then visit_expr(visitor, state, node.value) end

		visitor.visit_stat_assign_end(state, node)
	elseif node.kind == "command" then
		visitor.visit_stat_command(state, node)
		visit_command(visitor, state, node)
		visitor.visit_stat_command_end(state, node)
	elseif node.kind == "for" then
		visitor.visit_stat_for(state, node)

		visitor.visit_token(state, node.token)
		if node.expression then
			visit_delimited(visitor, state, visit_expr, node.expression)
		end

		if node.body then visit_expr(visitor, state, node.body) end

		visitor.visit_stat_for_end(state, node)
	elseif node.kind == "if" then
		visitor.visit_stat_if(state, node)

		visitor.visit_token(state, node.token)

		if node.first_branch then
			visit_if_branch(visitor, state, node.first_branch)
		end

		for _, branch in node.branches do
			visitor.visit_elseif_branch(state, branch)
			visitor.visit_token(state, branch.ifelse)
			visit_if_branch(visitor, state, branch.branch)
			visitor.visit_elseif_branch_end(state, branch)
		end

		if node.else_branch then
			visitor.visit_else_branch(state, node.else_branch)
			visitor.visit_token(state, node.else_branch.token)

			if node.else_branch.block then
				visit_delimited(
					visitor,
					state,
					visit_block,
					node.else_branch.block
				)
			end

			visitor.visit_else_branch_end(state, node.else_branch)
		end

		visitor.visit_stat_if_end(state, node)
	elseif node.kind == "while" then
		visitor.visit_stat_while(state, node)

		visitor.visit_token(state, node.token)

		if node.condition then
			visit_delimited(visitor, state, visit_expr, node.condition)
		end

		if node.block then
			visit_delimited(visitor, state, visit_block, node.block)
		end

		visitor.visit_stat_while_end(state, node)
	end

	visitor.visit_statement_end(state, node)
end

function visit_last_stat<State>(
	visitor: Visitor<State>,
	state: State,
	node: ast.LastStatement
)
	visitor.visit_last_statement(state, node)

	if node.kind == "break" then
		visitor.visit_break(state, node)

		visit_token(visitor, state, node.token)

		visitor.visit_break_end(state, node)
	elseif node.kind == "continue" then
		visitor.visit_continue(state, node)

		visit_token(visitor, state, node.token)

		visitor.visit_continue_end(state, node)
	elseif node.kind == "return" then
		visitor.visit_return(state, node)

		visit_token(visitor, state, node.token)
		visit_separated(visitor, state, visit_expr, node.values)

		visitor.visit_return_end(state, node)
	end

	visitor.visit_last_statement_end(state, node)
end

function visit_block<State>(visitor: Visitor<State>, state: State, node: ast.Block)
	visitor.visit_block(state, node)

	for _, statement in node.body do
		visit_stat(visitor, state, statement)
	end

	if node.last_statement then
		visit_last_stat(visitor, state, node.last_statement)
	end

	visitor.visit_block_end(state, node)
end

local function visit_ast<State>(
	visitor: Visitor<State>,
	state: State,
	node: ast.Ast
)
	visit_block(visitor, state, node.block)
end

return {
	visit_block = visit_block,
	visit_ast = visit_ast,
	create_visitor = create_visitor,
}
