local ast = require "./ast"

local function char(c: string): number return string.byte(c) :: number end

local function to_span(
	a: vector?,
	b: vector?,
	c: vector?,
	d: vector?,
	e: vector?,
	f: vector?,
	g: vector?,
	h: vector?
): vector
	return vector.create(
		a and a.x
			or b and b.x
			or c and c.x
			or d and d.x
			or e and e.x
			or f and f.x
			or g and g.x
			or h and h.x
			or 0,
		h and h.y
			or g and g.y
			or f and f.y
			or e and e.y
			or d and d.y
			or c and c.y
			or b and b.y
			or a and a.y
			or 0,
		a and a.z
			or b and b.z
			or c and c.z
			or d and d.z
			or e and e.z
			or f and f.z
			or g and g.z
			or h and h.z
			or 0
	)
end

export type Issue = {
	read why: string,
	read span: vector,
}

export type Output = { issues: { Issue }, result: ast.Ast? }

local function parse(input: buffer): Output
	local pos = 0
	local line = 0
	local len = buffer.len(input)
	local issues: { Issue } = {}

	local function peek(): number
		if pos == len then return 0 end
		return buffer.readu8(input, pos) :: any
	end

	local function peek_2(): number
		if pos + 1 >= len then return 0 end
		return buffer.readu8(input, pos + 1) :: any
	end

	local function bump() pos = math.min((pos + 1) :: any, len) end

	local function bump_any()
		if peek() == char "\n" then
			line += 1
		end

		bump()
		return peek()
	end

	local function throw(msg: string, span: vector)
		table.insert(issues, { why = `SyntaxError: {msg}`, span = span })
	end

	local function panic(msg: string?): never
		if msg then table.insert(issues, { why = msg, span = vector.zero }) end
		error {
			result = nil,
			issues = issues,
		}
	end

	local function eof(msg: string)
		if pos >= len then
			table.insert(
				issues,
				{ why = msg, span = vector.create(pos, pos, line) }
			)
			error({
				result = nil,
				issues = issues,
			}, 0)
		end
		return false
	end

	local function bump_peek()
		bump()
		return peek()
	end

	local function is_whitespace(c: number): boolean
		return c == char " " or c == char "\t" or c == char "\r"
	end

	local function is_digit(c: number): boolean
		return char "0" <= c and c <= char "9"
	end

	local function is_alpha(c: number): boolean
		return (char "a" <= c and c <= char "z")
			or (char "A" <= c and c <= char "Z")
			or c == char "@"
			or c == char "_"
	end

	local function string_backslash()
		local c = peek()

		if c == char "\r" then
			c = bump_peek()

			if c == char "\n" then
				bump()
				line += 1
			end
		elseif c == char "z" then
			bump()

			while is_whitespace(peek()) do
				bump_any()
			end
		else
			bump_any()
		end
	end

	local function quoted_string(): "string" | "error"
		local delim = peek()
		local c = bump_peek()

		while
			c ~= delim and not eof("expected string to be finished at", pos)
		do
			if c == 0 or c == char "\n" or c == char "\r" then
				return "error"
			elseif c == char "\\" then
				bump()
				string_backslash()
			else
				bump()
			end

			c = peek()
		end

		bump()
		return "string"
	end

	local function number(): "number" | "error"
		local start = pos
		local base = 10

		local c: number = peek()

		if c == char "0" then
			c = bump_peek()

			if c == char "x" or c == char "X" then
				c = bump_peek()
				base = 16
			elseif c == char "b" or c == char "B" then
				c = bump_peek()
				base = 2
			end
		end

		while is_digit(c) or c == char "." or c == char "_" do
			c = bump_peek()
		end

		if c == char "e" or c == char "E" then
			c = bump_peek()

			if c == char "+" or c == char "-" then c = bump_peek() end
		end

		while is_digit(c) or is_alpha(c :: any) or c == char "_" do
			c = bump_peek()
		end

		local text: string
		if base == 10 then
			text = buffer.readstring(input, start, pos - start) :: string
		else
			text =
				buffer.readstring(input, start + 2, pos - start - 2) :: string
		end

		text = string.gsub(text, "_", "")

		if tonumber(text, base) then
			return "number"
		else
			return "error"
		end
	end

	local function read_kind(): ast.TokenKindRest | ast.TokenKindText
		local c: number = peek()

		if c == 0 then return "eof" end

		if c == char "=" then
			bump()
			c = peek()
			if c == char "=" then
				bump()
				return "=="
			else
				return "="
			end
		elseif c == char "!" then
			bump()
			c = peek()

			if c == char "=" then
				bump()
				return "!="
			else
				return "!"
			end
		elseif c == char "~" then
			bump()
			c = peek()

			if c == char "=" then
				bump()
				return "~="
			else
				return "error"
			end
		elseif c == char ">" then
			bump()
			c = peek()

			if c == char "=" then
				bump()
				return ">="
			else
				return ">"
			end
		elseif c == char "<" then
			bump()
			c = peek()

			if c == char "=" then
				bump()
				return "<="
			else
				return "<"
			end
		elseif c == char "*" then
			bump()
			return "*"
		elseif c == char "/" then
			bump()
			c = peek()

			if c == char "/" then
				bump()
				return "//"
			else
				return "/"
			end
		elseif c == char "^" then
			bump()
			return "^"
		elseif c == char "%" then
			bump()
			return "%"
		elseif c == char "-" then
			bump()
			return "-"
		elseif c == char "+" then
			bump()
			return "+"
		elseif c == char "(" then
			bump()
			return "("
		elseif c == char ")" then
			bump()
			return ")"
		elseif c == char "$" then
			bump()
			return "$"
		elseif c == char "," then
			bump()
			return ","
		elseif c == char "&" then
			bump()
			return "&"
		elseif c == char "{" then
			bump()
			return "{"
		elseif c == char "}" then
			bump()
			return "}"
		elseif c == char "[" then
			bump()
			return "["
		elseif c == char "]" then
			bump()
			return "]"
		elseif c == char "|" then
			bump()
			return "|"
		elseif c == char "\n" then
			bump()
			return "\n"
		elseif c == char ";" then
			bump()
			return ";"
		elseif is_digit(c) then
			return number()
		elseif is_alpha(c) then
			local start = pos

			repeat
				c = bump_peek()
			until not (
					is_alpha(c :: number)
					or is_digit(c :: number)
					or c == char "-"
				)

			local value = buffer.readstring(input, start, pos - start)

			if value == "true" then
				return "true"
			elseif value == "false" then
				return "false"
			elseif value == "nil" then
				return "nil"
			elseif value == "if" then
				return "if"
			elseif value == "else" then
				return "else"
			elseif value == "elseif" then
				return "elseif"
			elseif value == "while" then
				return "while"
			elseif value == "for" then
				return "for"
			elseif value == "return" then
				return "return"
			elseif value == "break" then
				return "break"
			elseif value == "continue" then
				return "continue"
			elseif value == "and" then
				return "and"
			elseif value == "or" then
				return "or"
			end

			return "identifier"
		elseif c == char '"' or c == char "'" then
			return quoted_string()
		elseif c == char "." and is_digit(peek_2()) then
			return number()
		elseif c == char "." then
			bump()
			c = peek()

			if c == char "." then
				bump()
				return ".."
			else
				return "."
			end
		elseif is_whitespace(c) then
			bump()
			return "whitespace"
		end

		bump()
		return "error"
	end

	local function next_token()
		local start = pos
		local initial_line = line
		local kind = read_kind()

		while kind == "whitespace" or kind == "comment" do
			start = pos
			initial_line = line
			kind = read_kind()
		end

		if kind == "error" then
			throw(
				`could not parse {buffer.readstring(input, start, pos - start)} into a token`,
				vector.create(start, pos, initial_line)
			)
		end

		return {
			kind = kind,
			text = buffer.readstring(input, start, pos - start),
			span = vector.create(start, pos, initial_line),
		}
	end

	local current_token = next_token()
	local current_kind = current_token.kind
	local current_pos = current_token.span.x

	local lookahead_token = next_token()
	local lookahead_kind = lookahead_token.kind
	local lookahead_pos = lookahead_token.span.x

	local function consume()
		local old_token, old_kind = current_token, current_kind
		current_token, current_kind = lookahead_token, lookahead_kind
		current_pos = lookahead_pos
		lookahead_token = next_token()
		lookahead_kind = lookahead_token.kind
		lookahead_pos = lookahead_token.span.x
		return old_token, old_kind
	end

	local function skip_current()
		while current_kind == "\n" do
			consume()
		end
	end

	local function current_is(kind: ast.TokenKindText | ast.TokenKindRest)
		skip_current()

		return current_kind == kind
	end

	local function lookahead_is(kind: ast.TokenKindText | ast.TokenKindRest)
		while lookahead_kind == "\n" do
			lookahead_token = next_token()
			lookahead_kind = lookahead_token.kind
			lookahead_pos = lookahead_token.span.x
		end

		return lookahead_kind == kind
	end

	local function display(token: ast.Token): string
		local kind = token.kind

		if kind == "identifier" or kind == "number" or kind == "string" then
			return token.text
		elseif token.kind == "error" then
			return "error '" .. token.text .. "'"
		else
			return "'" .. kind .. "'"
		end
	end

	local function expected_but(kind: string): never
		throw(
			`expected {kind}, but got {display(current_token)} of {current_kind} instead`,
			current_token.span
		)
		consume()
		return nil :: never
	end

	local function expect<T>(
		kind: T & (ast.TokenKindText | ast.TokenKindRest)
	): ast.Token<T> | false
		if current_is(kind) then
			return consume() :: any
		else
			expected_but(kind :: any)
			return false
		end
	end

	local function expect_fatal<T>(
		kind: T & (
			ast.TokenKindText | ast.TokenKindRest
		)
	): ast.Token<T>
		if current_is(kind) then
			return consume() :: any
		else
			expected_but(display({ kind = kind } :: any))
			return panic()
		end
	end

	-- * parser

	local function is_delimiter()
		while current_kind == "\n" do
			consume()
		end

		return current_kind == "}"
			or current_kind == "]"
			or current_kind == ")"
			or current_kind == ";"
			or current_kind == "\n"
			or current_kind == "eof"
	end

	local parse_block_node: () -> ast.Block
	local parse_statement_node: () -> ast.Statement
	local parse_last_statement: () -> ast.LastStatement?
	local parse_simple_expression: () -> ast.SimpleExpression

	local parse_expression: () -> ast.Expression
	local parse_expression_command: () -> ast.Expression | ast.ExpressionCommand
	local parse_delimiter: <L, V, R>(L, R, fn: () -> V) -> false | ast.Delimited<L, V, R>

	local parse_function_body: () -> ast.FunctionBody?

	local parse_if_node: () -> ast.If
	local parse_while_node: () -> ast.While
	local parse_for_node: () -> ast.For
	local parse_assign: () -> ast.Assign
	local parse_command: () -> ast.Command

	local parse_table: () -> ast.ExpressionTable
	local parse_lambda: () -> ast.ExpressionLambda
	local parse_var: () -> ast.Var
	local parse_vector: () -> ast.ExpressionVector

	local function separated<T>(
		fn: () -> T,
		delimiter: ast.TokenKindRest?
	): ast.Separated<T>
		local values = {}

		while
			not is_delimiter() and not (delimiter and current_is(delimiter))
		do
			skip_current()

			local current_column = current_pos
			local current_line = line
			local value = fn()
			local separator = if current_is "," then expect "," else nil

			table.insert(values, {
				value = value,
				separator = separator,
				span = vector.create(
					current_column,
					separator and separator.span.y or current_column,
					current_line
				),
			})
		end

		return values
	end

	function parse_block_node(): ast.Block
		local start = current_pos
		local body = {}

		while not current_is "eof" and not is_delimiter() or current_is ";" do
			while current_kind == ";" do
				consume()
			end

			skip_current()

			if current_kind == "if" then
				table.insert(body, parse_if_node())
			elseif current_kind == "while" then
				table.insert(body, parse_while_node())
			elseif current_kind == "for" then
				table.insert(body, parse_for_node())
			elseif lookahead_kind == "=" then
				table.insert(body, parse_assign())
			elseif
				current_kind == "break"
				or current_kind == "return"
				or current_kind == "continue"
				or is_delimiter()
				or current_kind == "eof"
			then
				break
			elseif current_kind == "identifier" or current_kind == "$" then
				table.insert(body, parse_command())
			else
				expected_but "statement"
			end
		end

		return {
			body = body,
			last_statement = parse_last_statement(),
			span = vector.create(start, current_pos),
		}
	end

	function parse_statement_node(): ast.Statement
		if current_is "if" then
			return parse_if_node()
		elseif current_is "while" then
			return parse_while_node()
		elseif current_is "for" then
			return parse_for_node()
		elseif current_is "identifier" and lookahead_is "=" then
			return parse_assign()
		else
			return parse_command()
		end
	end

	function parse_last_statement(): ast.LastStatement?
		if current_is "continue" then
			local token = expect_fatal "continue"
			return {
				kind = "continue" :: "continue",
				token = token,
				span = token.span,
			}
		elseif current_is "break" then
			local token = expect_fatal "break"
			return {
				kind = "break" :: "break",
				token = token,
				span = token.span,
			}
		elseif current_is "return" then
			local token = expect_fatal "return"
			local values = separated(parse_expression_command)

			local node: ast.Return = {
				kind = "return" :: "return",
				token = token,
				values = values,
				span = token.span,
			}

			return node
		else
			return nil
		end
	end

	function parse_delimiter<L, R, V>(
		left: L & ast.TokenKind,
		right: R & ast.TokenKind,
		fn: () -> V
	): false | ast.Delimited<L, V, R>
		local token_left = expect(left)
		local value = fn()
		local token_right = expect(right)

		if not token_left then return false end

		return {
			left = token_left,
			value = value,
			right = token_right or nil,
		}
	end

	function parse_function_body(): ast.FunctionBody
		local arguments = parse_delimiter("|", "|", function()
			return separated(function() return expect "identifier" end, "|")
		end)

		local body = parse_delimiter("{", "}", parse_block_node)

		if not arguments then return panic "no arguments obtained" end

		return {
			arguments = arguments,
			block = body or nil,
			span = to_span(
				arguments and arguments.left.span,
				arguments and arguments.right and arguments.right.span,
				body and body.left and body.left.span or nil,
				body and body.right and body.right.span or nil
			),
		}
	end

	do
		local function parse_if_branch(): ast.IfBranch
			local condition =
				parse_delimiter("(", ")", parse_expression_command)
			local block = parse_delimiter("{", "}", parse_block_node)

			return {
				condition = condition or nil,
				block = block or nil,
				span = to_span(
					condition and condition.left and condition.left.span or nil,
					condition and condition.value and condition.value.span
						or nil,
					condition and condition.right and condition.right.span
						or nil,
					block and block.left and block.left.span or nil,
					block and block.value and block.value.span or nil,
					block and block.right and block.right.span or nil
				),
			}
		end

		local function parse_elseif_branch(): ast.ElseIfBranch
			local token = expect_fatal "elseif"
			local branch = parse_if_branch()

			return {
				ifelse = token,
				branch = branch,
				span = to_span(token.span, branch.span),
			}
		end

		function parse_if_node(): ast.If
			local if_token = expect_fatal "if"

			local first_branch = parse_if_branch()
			local branches: { ast.ElseIfBranch } = {}

			while current_is "elseif" do
				table.insert(branches, parse_elseif_branch())
			end

			local else_branch

			if current_is "else" then
				local else_token = expect_fatal "else"
				local block = parse_delimiter("{", "}", parse_block_node)

				else_branch = {
					token = else_token,
					block = block or nil,
					span = to_span(
						else_token.span,
						block and block.left and block.left.span or nil,
						block and block.value and block.value.span or nil,
						block and block.right and block.right.span or nil
					),
				}
			end

			return {
				kind = "if",
				token = if_token,

				first_branch = first_branch,
				branches = branches,

				else_branch = else_branch,

				span = to_span(
					if_token.span,
					first_branch.span,
					if #branches > 0 then branches[#branches].span else nil,
					else_branch and else_branch.span
				),
			}
		end
	end

	function parse_while_node(): ast.While
		local token = expect_fatal "while"
		local condition = parse_delimiter("(", ")", parse_expression_command)
		local block = parse_delimiter("{", "}", parse_block_node)

		return {
			kind = "while",
			token = token,
			condition = condition or nil,
			block = block or nil,
			span = to_span(
				token and token.span,
				condition and condition.left and condition.left.span or nil,
				condition and condition.value and condition.value.span or nil,
				condition and condition.right and condition.right.span or nil,
				block and block.left and block.left.span or nil,
				block and block.value and block.value.span or nil,
				block and block.right and block.right.span or nil
			),
		}
	end

	function parse_assign(): ast.Assign
		local name = expect_fatal "identifier"
		local equals = expect_fatal "="
		local expression = parse_expression_command()

		return {
			kind = "assign",
			identifier = name,
			equals = equals,
			value = expression or nil,
			span = to_span(
				name and name.span,
				equals and equals.span,
				expression and expression.span
			),
		}
	end

	function parse_for_node(): ast.For
		local token = expect_fatal "for"
		local condition = parse_delimiter("(", ")", parse_expression_command)
		local callback = parse_expression_command()

		return {
			kind = "for",
			token = token,
			expression = condition or nil,
			body = callback,
			span = to_span(
				token.span,
				condition and condition.left and condition.left.span or nil,
				condition and condition.value and condition.value.span or nil,
				condition and condition.right and condition.right.span or nil,
				callback and callback.span or nil
			),
		}
	end

	function parse_command(): ast.Command
		local var = parse_var()
		local arguments: { ast.SimpleExpression } = {}

		while
			current_kind ~= "\n"
			and not current_is "if"
			and not current_is "else"
			and not current_is "elseif"
			and not current_is "while"
			and not current_is "for"
			and not current_is "return"
			and not current_is "break"
			and not current_is "continue"
			and not is_delimiter()
			and not current_is ","
		do
			if current_is "identifier" and lookahead_kind ~= "." then
				local token = expect_fatal "identifier"
				table.insert(arguments, {
					kind = "string",
					token = token,
					span = token.span,
				})
			else
				table.insert(arguments, parse_simple_expression())
			end
		end

		return {
			kind = "command",
			var = var,
			arguments = arguments,
			span = to_span(
				var.span,
				if #arguments > 0 then arguments[#arguments].span else nil,
				if current_is "eof" then consume().span else nil
			),
		}
	end

	do
		local function parse_tablefield_nokey(): ast.TableFieldNoKey
			local expression = parse_expression_command()
			return {
				kind = "nokey",
				value = expression,
				span = expression and expression.span or vector.zero,
			}
		end

		local function parse_tablefield_namekey(): ast.TableFieldNameKey
			local name = expect_fatal "identifier"
			local equals = expect_fatal "="
			local value = parse_expression_command()

			return {
				kind = "name_key",
				name = name,
				equals = equals,
				value = value,
				span = to_span(name.span, equals.span, value and value.span),
			}
		end

		local function parse_tablefield_expressionkey(): ast.TableFieldExpressionKey | ast.TableFieldNoKey
			local left = expect_fatal "["
			local value = parse_expression_command()

			if current_is "]" and lookahead_is "=" then
				local right = expect_fatal "]"
				local key = {
					left = left,
					value = value,
					right = right,
				}

				local equals = expect "="
				local value = parse_expression_command()

				return {
					kind = "expression_key",
					key = key or nil,
					equals = equals or nil,
					value = value,

					span = to_span(
						key and key.left and key.left.span or nil,
						key and key.value and key.value.span or nil,
						key and key.right and key.right.span or nil,
						equals and equals.span or nil,
						value and value.span
					),
				}
			else -- nokey vector
				local first_separator = expect_fatal ","
				local values: ast.Separated<ast.Expression | ast.ExpressionCommand?> =
					{
						{
							value = value,
							separator = first_separator,
							span = to_span(
								value and value.span,
								first_separator.span
							),
						},
					}

				while not is_delimiter() do
					skip_current()

					local start = current_pos
					local expression = parse_expression_command()
					if not current_is "," then break end
					local separator = expect_fatal ","

					table.insert(values, {
						value = expression,
						separator = separator,
						span = vector.create(start, separator.span.y),
					})
				end

				local right = expect "]"
				local expression: ast.ExpressionVector = {
					kind = "vector",
					contents = {
						left = left,
						right = right or nil,
						value = values,
					},
					span = to_span(
						left.span,
						value and value.span or nil,
						values[#values] and values[#values].span or nil,
						right and right.span or nil
					),
				}

				local node: ast.TableFieldNoKey = {
					kind = "nokey",
					value = expression,
					span = expression.span,
				}

				return node
			end
		end

		local function parse_tablefield(): ast.TableField
			if current_is "identifier" and lookahead_is "=" then
				return parse_tablefield_namekey()
			elseif current_is "[" then
				return parse_tablefield_expressionkey()
			else
				return parse_tablefield_nokey()
			end
		end

		function parse_table(): ast.ExpressionTable
			local values = parse_delimiter(
				"{",
				"}",
				function() return separated(parse_tablefield) end
			)

			if not values then return panic "no table" end

			return {
				kind = "table",
				values = values,
				span = to_span(
					values.left and values.left.span,
					values.value and values.value[1] and values.value[1].span,
					values.value
						and values.value[#values.value]
						and values.value[#values.value].span,
					values.right and values.right.span
				),
			}
		end
	end

	do
		local function parse_unary_operator(): ast.Token<ast.UnaryOperator>?
			if current_kind == "-" or current_kind == "!" then
				return consume() :: any
			else
				return nil
			end
		end

		local function current_binary_operator(): ast.Token<ast.BinaryOperator>?
			if
				current_kind == "+"
				or current_kind == "-"
				or current_kind == "*"
				or current_kind == "/"
				or current_kind == "//"
				or current_kind == "%"
				or current_kind == "^"
				or current_kind == ".."
				or current_kind == "<"
				or current_kind == "<="
				or current_kind == ">"
				or current_kind == ">="
				or current_kind == "=="
				or current_kind == "~="
				or current_kind == "!="
				or current_kind == "and"
				or current_kind == "or"
			then
				return current_token :: any
			else
				return nil
			end
		end

		local function binary_operator_priority(
			op: ast.Token<
				ast.BinaryOperator
			>
		): (number, number)
			local kind = op.kind

			if kind == "+" or kind == "-" then
				return 6, 6
			elseif
				kind == "*"
				or kind == "/"
				or kind == "//"
				or kind == "%"
			then
				return 7, 7
			elseif kind == "^" then
				return 10, 9
			elseif kind == ".." then
				return 5, 4
			elseif kind == "==" or kind == "~=" or kind == "!=" then
				return 3, 3
			elseif
				kind == "<"
				or kind == "<="
				or kind == ">"
				or kind == ">="
			then
				return 3, 3
			elseif kind == "and" then
				return 2, 2
			elseif kind == "or" then
				return 1, 1
			else
				return panic(kind), 0
			end
		end

		function parse_simple_expression(): ast.Expression?
			local unary = parse_unary_operator()

			if unary then
				local righthandside = parse_expression(8)

				return {
					kind = "unary",
					operator = unary,
					value = righthandside,
					span = to_span(
						unary.span,
						righthandside and righthandside.span
					),
				}
			elseif current_is "error" then
				return expect_fatal "error"
			elseif current_is "(" then
				local expression =
					parse_delimiter("(", ")", parse_expression_command)

				assert(expression)

				local node: ast.ExpressionEvaluate = {
					kind = "evaluate",
					command = expression,
					span = to_span(
						expression and expression.left and expression.left.span,
						expression
							and expression.value
							and expression.value.span,
						expression
							and expression.right
							and expression.right.span
					),
				}

				return node
			elseif current_is "nil" then
				local token = expect_fatal "nil"
				local node: ast.ExpressionNil =
					{ kind = "nil", token = token, span = token.span }
				return node
			elseif current_is "false" or current_is "true" then
				local token: ast.Token<"false"> | ast.Token<"true"> =
					consume() :: any
				local node: ast.ExpressionBoolean =
					{ kind = "boolean", token = token, span = token.span }
				return node
			elseif current_is "number" then
				local token = expect_fatal "number"
				local node: ast.ExpressionNumber =
					{ kind = "number", token = token, span = token.span }
				return node
			elseif current_is "string" then
				local token = expect_fatal "string"
				local node: ast.ExpressionString =
					{ kind = "string", token = token, span = token.span }
				return node
			elseif current_is "{" then
				return parse_table()
			elseif current_is "|" then
				return parse_lambda()
			elseif current_is "$" or current_is "identifier" then
				return parse_var()
			elseif current_is "[" then
				return parse_vector()
			elseif current_is "&" then
				local token = expect_fatal "&"
				throw(
					"you are not allowed to run a command here due to ambiguous syntax. please wrap the command with ()",
					token.span
				)
				return expected_but(`expression`)
			elseif current_binary_operator() then
				throw(
					"you are not allowed to use binary operators here due to ambiguous syntax. please wrap the expression with ()",
					current_token.span
				)
				consume()
				return nil
			else
				return expected_but(`expression`)
			end
		end

		local function parse_simple_expression_command(): ast.Expression? | ast.ExpressionCommand
			if current_is "&" then
				local token = expect_fatal "&"

				local command = parse_command()
				local node: ast.ExpressionCommand = {
					kind = "command" :: "command",
					prefix = token,
					command = command,
					span = to_span(token.span, command and command.span),
				}

				return node
			else
				return parse_simple_expression()
			end
		end

		function parse_expression(limit: number?): ast.Expression
			limit = limit or 0

			local expr: ast.Expression?

			local unary_operator = parse_unary_operator()

			if unary_operator then
				local righthandside = parse_expression(8)

				expr = {
					kind = "unary",
					operator = unary_operator,
					value = righthandside,
					span = to_span(unary_operator.span, righthandside.span),
				}
			else
				expr = parse_simple_expression()
			end

			while true do
				local binop = current_binary_operator()

				if binop == nil then break end

				local left_priority, right_priority =
					binary_operator_priority(binop)

				if left_priority < limit then break end

				consume()

				local rhs = parse_expression(right_priority)
				if not expr then return panic "no left hand side" end

				expr = {
					kind = "binary",
					left = expr,
					operator = binop,
					right = rhs,
					span = to_span(
						expr and expr.span or nil,
						binop and binop.span or nil
					),
				}
			end

			if not expr then return panic "no expression" end
			return expr
		end

		function parse_expression_command(): ast.Expression? | ast.ExpressionCommand
			if current_is "&" then
				return parse_simple_expression_command()
			else
				return parse_expression()
			end
		end
	end

	function parse_lambda(): ast.ExpressionLambda
		local lambda = parse_function_body()

		return {
			kind = "lambda",
			span = lambda and lambda.span,
			body = lambda,
		}
	end

	function parse_vector(): ast.ExpressionVector
		local values = parse_delimiter(
			"[",
			"]",
			function() return separated(parse_expression_command) end
		)

		if not values then return panic "no values" end

		return {
			kind = "vector",
			contents = values,
			span = to_span(
				values.left and values.left.span,
				values.value and values.value[1] and values.value[1].span,
				values.value
					and values.value[#values.value]
					and values.value[#values.value].span,
				values.right and values.right.span
			),
		}
	end

	do
		local function parse_var_root(): ast.VarRoot
			if current_is "identifier" then
				local ident = expect_fatal "identifier"
				return {
					kind = "global",
					token = ident,
					span = ident.span,
				}
			elseif current_is "$" and lookahead_is "(" then
				local operator = expect_fatal "$"
				local expression =
					parse_delimiter("(", ")", parse_expression_command)
				if not expression then return panic "no expression" end

				return {
					kind = "paren",

					var = operator,
					node = expression,

					span = to_span(
						operator.span,
						expression.left and expression.left.span,
						expression.value and expression.value.span,
						expression.right and expression.right.span
					),
				}
			elseif current_is "$" then
				local operator = expect_fatal "$"
				local name = expect "identifier"
				return {
					kind = "name",
					var = operator,
					name = name or nil,
					span = to_span(operator.span, name and name.span or nil),
				}
			else
				throw(
					`could not parse into var. got {current_kind}`,
					current_token.span
				)
				return panic()
			end
		end

		local function parse_var_suffix(): ast.VarSuffix
			if current_is "." and lookahead_is "[" then
				local operator = expect_fatal "."
				local node = parse_delimiter("[", "]", parse_expression_command)
				if not node then return panic "unreachable" end

				return {
					kind = "expression_index",
					node = node,

					period = operator,
					span = to_span(
						node.left and node.left.span or nil,
						node.value and node.value.span or nil,
						node.right and node.right.span or nil
					),
				}
			elseif current_is "." then
				local operator = expect_fatal "."
				local name = expect "identifier"

				return {
					kind = "name_index",

					period = operator,
					name = name or nil,

					span = to_span(operator.span, name and name.span or nil),
				}
			else
				return panic "unreachable"
			end
		end

		function parse_var(): ast.Var
			local root = parse_var_root()
			local suffixes: { ast.VarSuffix } = {}

			while current_kind == "." do
				table.insert(suffixes, parse_var_suffix())
			end

			return {
				kind = "var",
				root = root,
				suffixes = suffixes,
				span = to_span(
					root.span,
					suffixes[#suffixes] and suffixes[#suffixes].span
				),
			}
		end
	end

	local result = { block = parse_block_node() }

	if #issues > 0 then
		error {
			result = result,
			issues = issues,
		}
	else
		return {
			result = result,
			issues = issues,
		}
	end
end

return parse
