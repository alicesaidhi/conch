local ast = require "../src/ast"
local astgen = require "./astgen"
local compare = require "./astcompare"
local display = require "./astdisplay"
local generate = require "./astgenerate"
local testkit = require "@vendor/testkit"

local t = testkit.test()

local function test_ast(input: ast.Ast)
	local s = display(input)
	local b = buffer.fromstring(s)
	-- print(s)
	local ok, output_result: ast.Output = pcall(ast.parse, b)
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

local function CASE_AST(name: string, block: ast.Block)
	local to_ast = astgen.to_ast(block)
	t.CASE(`{name}`)
	test_ast(to_ast)
end

local BINARY_OPERATORS: { ast.BinaryOperator } = {
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
		astgen.block {
			astgen.stat_command(
				astgen.var(astgen.varroot_global "meow", {}),
				{}
			),
		}
	)
	CASE_AST(
		"command and number",
		astgen.block {
			astgen.stat_command(
				astgen.var(astgen.varroot_global "meow", {}),
				{ astgen.expr_number(10) }
			),
		}
	)
	CASE_AST(
		"command and string",
		astgen.block {
			astgen.stat_command(
				astgen.var(astgen.varroot_global "meow", {}),
				{ astgen.expr_string "gdsakjl" }
			),
		}
	)
	CASE_AST(
		"command and identifer",
		astgen.block {
			astgen.stat_command(
				astgen.var(astgen.varroot_global "meow", {}),
				{ astgen.arg_ident "gdsakjl" }
			),
		}
	)
	CASE_AST(
		"command and boolean",
		astgen.block {
			astgen.stat_command(
				astgen.var(astgen.varroot_global "meow", {}),
				{ astgen.expr_boolean(true) }
			),
		}
	)
	CASE_AST(
		"command and arguments",
		astgen.block {
			astgen.stat_command(
				astgen.var(astgen.varroot_global "meow", {}),
				{ astgen.expr_number(10), astgen.expr_boolean(true) }
			),
		}
	)

	for _, operator in BINARY_OPERATORS do
		CASE_AST(
			"command and binary",
			astgen.block {
				astgen.stat_command(
					astgen.var(astgen.varroot_global "meow", {}),
					{
						astgen.expr_evaluate(
							astgen.expr_binary(
								astgen.expr_number(10),
								operator,
								astgen.expr_number(20)
							)
						),
					}
				),
			}
		)
	end

	CASE_AST(
		"edge case 1",
		astgen.block {
			astgen.stat_while(
				astgen.expr_boolean(true),
				astgen.block {
					astgen.stat_for(
						astgen.expr_string "meow",
						astgen.var(astgen.varroot_var "name", {
							astgen.varsuffix_expression_index(
								astgen.expr_lambda(
									astgen.function_body(
										{},
										astgen.block {
											astgen.stat_for(
												astgen.expr_boolean(true),
												astgen.expr_nil()
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
		astgen.block {
			astgen.stat_if(
				astgen.if_branch(
					astgen.var(astgen.varroot_var "meow", {}),
					astgen.block({}, astgen.lstat_break())
				)
			),
		}
	)

	CASE_AST(
		"edge case 3",
		astgen.block {
			astgen.stat_if(
				astgen.if_branch(
					astgen.var(astgen.varroot_var "meow", {}),
					astgen.block({}, astgen.lstat_break())
				),

				{
					astgen.if_else_branch(
						astgen.if_branch(
							astgen.var(astgen.varroot_var "meow", {}),
							astgen.block {
								astgen.stat_for(
									astgen.var(astgen.varroot_global "name", {}),
									astgen.expr_lambda(
										astgen.function_body(
											{ "arg1", "arg2" },
											astgen.block {}
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
		astgen.block {
			astgen.stat_command(astgen.var(astgen.varroot_var "name", {}), {}),
			astgen.stat_while(
				astgen.expr_boolean(true),
				astgen.block({}, astgen.lstat_break())
			),
		}
	)

	local s = (
		display(astgen.to_ast(astgen.block {
			astgen.stat_command(astgen.var(astgen.varroot_var "mraow", {}), {
				astgen.expr_table {
					astgen.tablefield_expressionkey(
						astgen.expr_string "meow",
						astgen.expr_vector(
							astgen.var(astgen.varroot_var "meow", {}),
							astgen.var(astgen.varroot_var "meow", {}),
							astgen.var(
								astgen.varroot_paren(astgen.expr_table {}),
								{}
							)
						)
					),
				},
			}),
		}))
	)

	CASE_AST(
		"edge case 5",
		astgen.block {
			astgen.stat_command(astgen.var(astgen.varroot_var "mraow", {}), {
				astgen.expr_table {
					astgen.tablefield_expressionkey(
						astgen.expr_string "meow",
						astgen.expr_vector(
							astgen.var(astgen.varroot_var "meow", {}),
							astgen.var(astgen.varroot_var "meow", {}),
							astgen.var(
								astgen.varroot_paren(astgen.expr_table {}),
								{}
							)
						)
					),
				},
			}),
		}
	)

	CASE_AST(
		"edge case 6",
		astgen.block {
			astgen.stat_for(
				astgen.expr_string "meow",
				astgen.expr_unary(
					"-",
					astgen.expr_vector(
						astgen.expr_number(0),
						astgen.expr_command(
							astgen.stat_command(
								astgen.var(astgen.varroot_var "mraow", {}),
								{}
							)
						),
						astgen.expr_vector(
							astgen.expr_number(0),
							astgen.expr_number(0),
							astgen.expr_number(0)
						)
					)
				)
			),
			astgen.stat_command(astgen.var(astgen.varroot_var "mraow", {}), {}),
			astgen.stat_assign(
				"meow",
				astgen.var(astgen.varroot_global "testing", {})
			),
		}
	)

	CASE_AST(
		"vector key",
		astgen.block {
			astgen.stat_command(astgen.var(astgen.varroot_var "mraow", {}), {
				astgen.expr_table {
					astgen.tablefield_expressionkey(
						astgen.expr_number(10),
						astgen.expr_number(10)
					),
					astgen.tablefield_nokey(
						astgen.expr_vector(
							astgen.expr_number(10),
							astgen.expr_number(10),
							astgen.expr_number(10)
						)
					),
				},
			}),
		}
	)
end)

t.TEST("ast fuzz testing", function()
	local ast = generate(1000)

	CASE_AST("fuzz", ast.block)
end)

t.FINISH()
