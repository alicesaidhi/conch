local analysis = require "../src/analysis"
local ast = require "../src/ast"
local astgen = require "./astgen"
local compare = require "./astcompare"
local display = require "./astdisplay"
local generate = require "./astgenerate"
local language = require "../src"
local testkit = require "@vendor/testkit"
local treewalker = require "../src/treewalker"

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

	CASE_AST(
		"tablefield",
		astgen.block {
			astgen.stat_command(astgen.var(astgen.varroot_var "mraow", {}), {
				astgen.expr_table {
					astgen.tablefield_expressionkey(
						astgen.expr_number(1),
						astgen.expr_number(1)
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

local function CASE_TREE(p: {
	name: string,
	input: string,
	match: { unknown } | (fn: (...any) -> boolean) -> (),
})
	t.CASE(p.name)

	local input = p.input
	local state = treewalker.create_state()
	local outputs = {}

	state.globals.meow = function(...) outputs = { ... } end
	state.globals.range = function(start: number, stop: number, step: number)
		step = step or 1
		local i = start - step
		return function(): any
			if i >= stop then return nil end
			i += step
			return i
		end
	end
	state.globals.ping = function(...) return "pong", ... end
	state.globals.error = error

	local buffer_input = buffer.fromstring(input)
	local ok, parsed: ast.Output = pcall(ast.parse, buffer_input)

	if not ok then
		local msgs = {}
		for _, issue in parsed.issues do
			print(issue.span, issue.why)
			table.insert(
				msgs,
				`{issue.why} at {issue.span.x}:{issue.span.y}:{issue.span.z}`
			)
		end
		error(table.concat(msgs, "\n"))
	end

	local result = treewalker.execute(state, parsed.result)
	if not result.ok then error(result.err) end

	if type(p.match) == "function" then
		t.CHECK((p.match :: any)(unpack(outputs)))
	else
		t.CHECK(#outputs == #p.match)

		for idx, a in p.match do
			local b = outputs[idx]
			-- if typeof(a) == "table" then
			-- 	print "a"
			-- 	table.foreach(a, print)
			-- end

			-- if typeof(b) == "table" then
			-- 	print "b"
			-- 	table.foreach(b, print)
			-- end

			local eq = testkit.deq(a, b)
			t.CHECK(eq)

			if not eq then print(a, b) end
		end
	end
end

t.TEST("treewalker", function()
	CASE_TREE {
		name = "expression nil",
		input = "meow nil",
		match = { nil },
	}

	CASE_TREE {
		name = "expression false",
		input = "meow false",
		match = { false },
	}

	CASE_TREE {
		name = "expression true",
		input = "meow true",
		match = { true },
	}

	CASE_TREE {
		name = "expression number",
		input = "meow 1234",
		match = { 1234 },
	}

	CASE_TREE {
		name = "expression evaluate",
		input = "meow (1)",
		match = { 1 },
	}

	CASE_TREE {
		name = "expression binary",
		input = "meow (1 + 1)",
		match = { 2 },
	}

	CASE_TREE {
		name = "expression string",
		input = "meow 'mrow'",
		match = { "mrow" },
	}

	CASE_TREE {
		name = "expression string + escape characters",
		input = "meow 'mrow\\n\\10'",
		match = { "mrow\n\10" },
	}

	CASE_TREE {
		name = "expression lambdas",
		input = "meow |x| { return $x }",
		match = function(fn) return fn(10) == 10 end,
	}

	CASE_TREE {
		name = "expression vector",
		input = "meow [1, 2]",
		match = { vector.create(1, 2) },
	}

	CASE_TREE {
		name = "expression unary -",
		input = "meow -1",
		match = { -1 },
	}

	CASE_TREE {
		name = "expression unary !",
		input = "meow !false",
		match = { true },
	}

	CASE_TREE {
		name = "expression command",
		input = "meow (&ping 12)",
		match = { "pong", 12 },
	}

	CASE_TREE {
		name = "expression table",
		input = "meow { field = { meow = true }, true, [2] = false }\z",
		match = { { field = { meow = true }, true, [2] = false } },
	}

	CASE_TREE {
		name = "expression var",
		input = "var = 1; meow $var",
		match = { 1 },
	}

	CASE_TREE {
		name = "expression var index",
		input = "var = { field = 1 }; meow $var.field",
		match = { 1 },
	}

	CASE_TREE {
		name = "expression var expression",
		input = "var = { field = 1 }; meow $var.['field']",
		match = { 1 },
	}

	CASE_TREE {
		name = "expression var expression",
		input = "var = { field = 1 }; meow $var.['field']",
		match = { 1 },
	}

	CASE_TREE {
		name = "command",
		input = 'meow 12345 { "yes", "yes", [1] = "no" } false',
		match = { 12345, { "yes", "yes", [1] = "no" }, false },
	}

	CASE_TREE {
		name = "lambda command",
		input = "var = |value| { meow ($value + 1) }\n\z
		$var 1",
		match = { 2 },
	}

	CASE_TREE {
		name = "var command",
		input = "var = { value = |value| { meow ($value + 1) } }\n\z
		$var.value 1",
		match = { 2 },
	}

	CASE_TREE {
		name = "var command",
		input = "var = { value = |value| { meow ($value + 1) } }\n\z
		$var.['value'] 1",
		match = { 2 },
	}

	CASE_TREE {
		name = "return value",
		input = "var = |value| { return $value + 1 }\n\z
		meow (&$var 1)",
		match = { 2 },
	}

	CASE_TREE {
		name = "if statement",
		input = "var = 1\n\z
		if ($var == 1) { meow 2 }",
		match = { 2 },
	}

	CASE_TREE {
		name = "if and else statement",
		input = "var = 2\n\z
		if ($var == 1) { meow 2 } else { meow 3 }",
		match = { 3 },
	}

	CASE_TREE {
		name = "if and else statement",
		input = "var = 2\n\z
		if ($var == 1) { meow 2 } else { meow 3 }",
		match = { 3 },
	}

	CASE_TREE {
		name = "if and elseif statements",
		input = [[
var = 3

if ($var == 1) {
	meow false
} elseif ($var == 2) {
	meow true
} elseif ($var == 3) {
	meow false
} elseif ($var == 4) {
	meow true
} elseif ($var == 5) {
	meow false
} elseif ($var == 6) {
	meow true
} elseif ($var == 7) {
	meow false
} elseif ($var == 8) {
	meow true
}

]],
		match = { false },
	}

	CASE_TREE {
		name = "for loop",
		input = "n = 0\n\z
		for (&range 1 10) |i| { n = ($n + 1) }\n\z
		meow $n",
		match = { 10 },
	}

	CASE_TREE {
		name = "for loop break",
		input = "n = 0\n\z
		for (&range 1 10) |i| { if ($i > 5) { break } n = $n + 1 }\n\z
		meow $n",
		match = { 5 },
	}

	CASE_TREE {
		name = "for loop continue",
		input = "n = 0\n\z
		for (&range 1 10) |i| { if ($i == 5) { continue } n = $n + 1 }\n\z
		meow $n",
		match = { 9 },
	}

	CASE_TREE {
		name = "for loop table",
		input = "n = 0\n\z
		for ({ 1, 2, 3 }) |key, value| { n = ($n + $value) }\n\z
		meow $n",
		match = { 6 },
	}

	CASE_TREE {
		name = "while loop",
		input = "n = 0\n\z
		while ($n < 10) { n = ($n + 1) }\n\z
		meow $n",
		match = { 10 },
	}

	CASE_TREE {
		name = "pemdas",
		input = "n = 1 + 1 * 4\n\z
		meow $n",
		match = { 5 },
	}

	CASE_TREE {
		name = "error",
		input = "oop value",
		match = {},
	}
end)

--todo: write tests for analysis but im lazy
local vm = language.create_vm()
vm.global_metadata.command = {
	name = "command",
	description = "test command",
	key = "command",
	overloads = {
		{
			arguments = {
				{
					name = "test1",
					description = "test",
					type = "test",
					kind = "argument",
					optional = false,
					vararg = false,
					unique_identifier = "",
					suggestions = nil,
				},

				{
					name = "test2",
					description = "test",
					type = "test",
					kind = "argument",
					optional = false,
					vararg = false,
					unique_identifier = "",
					suggestions = nil,
				},
			},
		},
	},
}
testkit.print(analysis(vm, "command t ", 10))

t.FINISH()
