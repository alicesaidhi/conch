local ast = require "./ast"
local compare = require "./compare"
local display = require "./display"
local generate = require "./generate"
local parse = require "../src/ast"
local testkit = require "@vendor/testkit"

local t = testkit.test()

local function test_ast(input: parse.Ast)
	local s = display(input)
	local b = buffer.fromstring(s)
	-- print(s)
	local ok, output_result: parse.Output = pcall(parse, b)
	local issues_concat = {}

	if not ok then
		-- print(s)
		error(output_result)

		for _, issue in output_result.issues do
			table.insert(issues_concat, `{issue.why} at {issue.span}`)
		end

		error(table.concat(issues_concat, "\n"))
	end

	for _, issue in compare(input, output_result.result) do
		table.insert(issues_concat, issue.why)
	end

	t.CHECK(#issues_concat == 0)

	if #issues_concat > 0 then
		testkit.print(input)
		testkit.print(output_result.result)
		error(table.concat(issues_concat, "\n"))
	end
end

local function CASE_AST(name: string, block: parse.Block)
	local to_ast = ast.to_ast(block)
	t.CASE(`{name}`)
	test_ast(to_ast)
end

local BINARY_OPERATORS: { parse.BinaryOperator } = {
	"==",
	"!=",
	"~=",
	">",
	"<",
	">=",
	"<=",
	-- arithmetic
	"*",
	"/",
	"-",
	"+",
	"//",
	"^",
	"%",
	"..",
	-- ternary
	"and",
	"or",
}

t.TEST("basic expression and command parsing", function()
	CASE_AST(
		"command",
		ast.block {
			ast.stat_command(ast.var(ast.varroot_global "meow", {}), {}),
		}
	)
	CASE_AST(
		"command and number",
		ast.block {
			ast.stat_command(
				ast.var(ast.varroot_global "meow", {}),
				{ ast.expr_number(10) }
			),
		}
	)
	CASE_AST(
		"command and string",
		ast.block {
			ast.stat_command(
				ast.var(ast.varroot_global "meow", {}),
				{ ast.expr_string "gdsakjl" }
			),
		}
	)
	CASE_AST(
		"command and identifer",
		ast.block {
			ast.stat_command(
				ast.var(ast.varroot_global "meow", {}),
				{ ast.arg_ident "gdsakjl" }
			),
		}
	)
	CASE_AST(
		"command and boolean",
		ast.block {
			ast.stat_command(
				ast.var(ast.varroot_global "meow", {}),
				{ ast.expr_boolean(true) }
			),
		}
	)
	CASE_AST(
		"command and arguments",
		ast.block {
			ast.stat_command(
				ast.var(ast.varroot_global "meow", {}),
				{ ast.expr_number(10), ast.expr_boolean(true) }
			),
		}
	)

	for _, operator in BINARY_OPERATORS do
		CASE_AST(
			"command and binary",
			ast.block {
				ast.stat_command(ast.var(ast.varroot_global "meow", {}), {
					ast.expr_evaluate(
						ast.expr_binary(
							ast.expr_number(10),
							operator,
							ast.expr_number(20)
						)
					),
				}),
			}
		)
	end

	CASE_AST(
		"edge case 1",
		ast.block {
			ast.stat_while(
				ast.expr_boolean(true),
				ast.block {
					ast.stat_for(
						ast.expr_string "meow",
						ast.var(ast.varroot_var "name", {
							ast.varsuffix_expression_index(
								ast.expr_lambda(
									ast.function_body(
										{},
										ast.block {
											ast.stat_for(
												ast.expr_boolean(true),
												ast.expr_nil()
											),
										}
									)
								)
							),
						})
					),
				}
			),
		}
	)

	CASE_AST(
		"edge case 2",
		ast.block {
			ast.stat_if(
				ast.if_branch(
					ast.var(ast.varroot_var "meow", {}),
					ast.block({}, ast.lstat_break())
				)
			),
		}
	)

	CASE_AST(
		"edge case 3",
		ast.block {
			ast.stat_if(
				ast.if_branch(
					ast.var(ast.varroot_var "meow", {}),
					ast.block({}, ast.lstat_break())
				),

				{
					ast.if_else_branch(
						ast.if_branch(
							ast.var(ast.varroot_var "meow", {}),
							ast.block {
								ast.stat_for(
									ast.var(ast.varroot_global "name", {}),
									ast.expr_lambda(
										ast.function_body(
											{ "arg1", "arg2" },
											ast.block {}
										)
									)
								),
							}
						)
					),
				}
			),
		}
	)

	CASE_AST(
		"edge case 4",
		ast.block {
			ast.stat_command(ast.var(ast.varroot_var "name", {}), {}),
			ast.stat_while(
				ast.expr_boolean(true),
				ast.block({}, ast.lstat_break())
			),
		}
	)

	local s = (
		display(ast.to_ast(ast.block {
			ast.stat_command(ast.var(ast.varroot_var "mraow", {}), {
				ast.expr_table {
					ast.tablefield_expressionkey(
						ast.expr_string "meow",
						ast.expr_vector(
							ast.var(ast.varroot_var "meow", {}),
							ast.var(ast.varroot_var "meow", {}),
							ast.var(ast.varroot_paren(ast.expr_table {}), {})
						)
					),
				},
			}),
		}))
	)

	CASE_AST(
		"edge case 5",
		ast.block {
			ast.stat_command(ast.var(ast.varroot_var "mraow", {}), {
				ast.expr_table {
					ast.tablefield_expressionkey(
						ast.expr_string "meow",
						ast.expr_vector(
							ast.var(ast.varroot_var "meow", {}),
							ast.var(ast.varroot_var "meow", {}),
							ast.var(ast.varroot_paren(ast.expr_table {}), {})
						)
					),
				},
			}),
		}
	)

	CASE_AST(
		"edge case 6",
		ast.block {
			ast.stat_for(
				ast.expr_string "meow",
				ast.expr_unary(
					"-",
					ast.expr_vector(
						ast.expr_number(0),
						ast.expr_command(
							ast.stat_command(
								ast.var(ast.varroot_var "mraow", {}),
								{}
							)
						),
						ast.expr_vector(
							ast.expr_number(0),
							ast.expr_number(0),
							ast.expr_number(0)
						)
					)
				)
			),
			ast.stat_command(ast.var(ast.varroot_var "mraow", {}), {}),
			ast.stat_assign("meow", ast.var(ast.varroot_global "testing", {})),
		}
	)

	CASE_AST(
		"vector key",
		ast.block {
			ast.stat_command(ast.var(ast.varroot_var "mraow", {}), {
				ast.expr_table {
					ast.tablefield_expressionkey(
						ast.expr_number(10),
						ast.expr_number(10)
					),
					ast.tablefield_nokey(
						ast.expr_vector(
							ast.expr_number(10),
							ast.expr_number(10),
							ast.expr_number(10)
						)
					),
				},
			}),
		}
	)
end)

t.TEST("fuzz", function()
	for i = 1, 1000 do
		local ast = generate(3)

		-- print(
		-- 	string.sub(display(ast), 0, 293)
		-- 		.. testkit.color.red(string.sub(display(ast), 294, 400))
		-- )

		CASE_AST("fuzz", ast.block)
	end
end)

t.FINISH()
