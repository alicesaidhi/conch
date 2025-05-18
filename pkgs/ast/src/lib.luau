--!strict
local types = require "../roblox_packages/types"

export type TokenKindText = types.TokenKindText
export type TokenKindRest = types.TokenKindRest
export type Token<T = TokenKindRest | TokenKindText> = types.Token<T>

local function char(c: string): number return string.byte(c) :: number end

--[=[
    Lexes the given input into tokens
]=]
local function parse(input: buffer, can_yield: boolean?)
	local pos = 0
	local line = 0
	local len = buffer.len(input)

	local function peek(): number
		if pos == len then return 0 end
		return buffer.readu8(input, pos) :: any
	end

	local function bump() pos = math.min((pos + 1) :: any, len) end

	local function bump_any()
		if peek() == char "\n" then
			line += 1
		end

		bump()
		return peek()
	end

	local function eof(msg: string)
		if pos >= len then error(msg, 0) end
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

		while c ~= delim and not eof "unterminated string" do
			if c == 0 or c == char "\n" or c == char "\r" then
				has_error = true
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
		local has_sign = false

		if c == char "-" then
			c = bump_peek()
			has_sign = true
		end

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
			text = buffer.readstring(
				input,
				start + 2 + if has_sign then 1 else 0,
				pos - start - 2 - if has_sign then 1 else 0
			) :: string
		end

		text = string.gsub(text, "_", "")

		if tonumber(text, base) then
			return "number"
		else
			has_error = true
			return "error"
		end
	end

	local function read_kind(): TokenKindRest | TokenKindText
		local c: number = peek()

		if c == 0 then return "eof" end

		if c == char "#" then
			while c ~= char "\n" and c ~= 0 do
				c = bump_any()
			end
			return read_kind()
		elseif is_whitespace(c) then
			bump()
			return "whitespace"
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
			elseif value == "return" then
				return "return"
			elseif value == "for" then
				return "for"
			elseif value == "while" then
				return "while"
			elseif value == "if" then
				return "if"
			elseif value == "else" then
				return "else"
			elseif value == "break" then
				return "break"
			elseif value == "continue" then
				return "continue"
			end

			return "identifier"
		elseif is_digit(c :: number) or c == char "-" then
			return number()
		elseif c == char '"' then
			return quoted_string()
		elseif c == char "'" then
			return quoted_string()
		elseif c == char "." then
			c = peek()

			if is_digit(c) then
				pos -= 1
				return number()
			else
				bump()
				return "."
			end
		elseif c == char "=" then
			bump()

			if peek() == char "=" then
				return "=="
			else
				return "="
			end
		elseif c == char "~" then
			bump()

			if peek() == char "=" then
				return "~="
			else
				has_error = true
				return "error"
			end
		elseif c == char ">" then
			bump()

			if peek() == char "=" then
				return ">="
			else
				return ">"
			end
		elseif c == char "<" then
			bump()

			if peek() == char "=" then
				return "<="
			else
				return "<"
			end
		elseif c == char "$" then
			bump()
			return "$"
		elseif c == char "(" then
			bump()
			return "("
		elseif c == char ")" then
			bump()
			return ")"
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
		elseif c == char "," then
			bump()
			return ","
		elseif is_whitespace(c) then
			bump()
			return read_kind()
		end

		error(`no symbol matching {string.char(c)}`, 0)
		return "error"
	end

	local function next_token()
		local start = pos
		local kind = read_kind()

		while kind == "whitespace" or kind == "comment" do
			start = pos
			kind = read_kind()
		end

		return {
			kind = kind,
			text = buffer.readstring(input, start, pos - start),
			span = vector.create(start, pos, 0),
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

	local function current_is(kind: TokenKindText | TokenKindRest)
		while current_kind == "\n" do
			consume()
		end

		return current_kind == kind
	end

	local function lookahead_is(kind: TokenKindText | TokenKindRest)
		while lookahead_kind == "\n" do
			lookahead_token = next_token()
			lookahead_kind = lookahead_token.kind
		end

		return lookahead_kind == kind
	end

	local function yield()
		if can_yield then
			local b = coroutine.yield()
			assert(typeof(b) == "buffer")
			input = b
			len = buffer.len(b)

			current_token = next_token()
			current_kind = current_token.kind
			lookahead_token = next_token()
			lookahead_kind = lookahead_token.kind
		end
	end

	local function display(token: Token): string
		local kind = token.kind

		if kind == "identifier" or kind == "number" or kind == "string" then
			return kind
		elseif token.kind == "error" then
			return "error '" .. token.text .. "'"
		else
			return "'" .. kind .. "'"
		end
	end

	local function report(message: string, span: vector?): never
		local report = {
			message = message,
			span = span or current_token.span,
		}

		error(`{report.message} from {report.span.x} to {report.span.y}`, 0)
	end

	local function expect_failure(
		kind: TokenKindText | TokenKindRest
	): never
		return report(
			`expected {display({ kind = kind } :: any)}, but got {display(
				current_token
			)} of {current_kind} instead`
		)
	end

	local function expect<T>(kind: T & (TokenKindText | TokenKindRest)): Token<T>
		if current_is(kind) then
			return consume() :: any
		elseif current_kind == "eof" and can_yield then
			yield()
			return if current_is(kind) then consume() else expect_failure(kind)
		else
			return expect_failure(kind)
		end
	end

	local parse_expression: () -> types.Expression
	local parse_command: () -> types.Command
	local parse_block: () -> types.Block
	local parse_lambda: () -> types.Expression_Lambda
	local parse_expression_or_command: () -> types.ExpressionOrCommand
	local parse_var: () -> types.Var
	local parse_var_root: () -> types.VarRoot
	local parse_var_suffix: () -> types.VarSuffix
	local parse_var_suffixes: () -> { types.VarSuffix }
	local parse_function_body: () -> types.FunctionBody
	local parse_if: () -> types.Stat_If
	local parse_while: () -> types.Stat_While
	local parse_for: () -> types.Stat_For
	local parse_return: () -> types.Last_Return

	function parse_var_root(): types.VarRoot
		-- print("root:", current_kind, current_token.text)
		if current_is "identifier" then
			-- print("global")
			local token = expect "identifier"
			return { kind = "global", span = token.span, token = token }
		elseif current_is "$" and lookahead_is "identifier" then
			local start = expect "$"
			local token = expect "identifier"
			return {
				kind = "name",
				span = vector.create(start.span.x, token.span.y, 0),
				name = token,
			}
		elseif current_is "$" and lookahead_is "(" then
			local start = expect "$"
			expect "("
			local expr = parse_expression_or_command()
			local finish = expect ")"
			return {
				kind = "paren",
				span = vector.create(start.span.x, finish.span.y, 0),
				expr = expr,
			}
		else
			return report(`expected identifier, got {display(lookahead_token)}`)
		end
	end

	function parse_var_suffix(): types.VarSuffix
		if current_is "." then
			local token = expect "."
			local identifier = expect "identifier"
			return {
				kind = "nameindex",
				span = vector.create(token.span.x, identifier.span.y, 0),
				name = identifier,
			}
		elseif current_is "[" then
			local left = expect "["
			local expr = parse_expression_or_command()
			local right = expect "]"
			return {
				kind = "exprindex",
				span = vector.create(left.span.x, right.span.y, 0),
				expr = expr,
			}
		else
			return report "invalid"
		end
	end

	function parse_var_suffixes(): { types.VarSuffix }
		local suffixes: { types.VarSuffix } = {}
		while current_is "." or current_is "[" do
			local suffix = parse_var_suffix()
			table.insert(suffixes, suffix)
		end
		return suffixes
	end

	function parse_var(): types.Var
		local root = parse_var_root()
		local suffixes = if root.kind ~= "global"
			then parse_var_suffixes()
			else {} :: never

		local start = root.span.x
		local finish = if #suffixes > 0
			then suffixes[#suffixes].span.y
			else root.span.y

		return {
			span = vector.create(start, finish, 0),
			prefix = root,
			suffixes = suffixes,
		}
	end

	function parse_expression_or_command(): types.ExpressionOrCommand
		if current_is "identifier" then
			return parse_command()
		elseif current_kind == "eof" and can_yield then
			yield()
			return parse_expression_or_command()
		else
			return parse_expression()
		end
	end

	function parse_function_body(): types.FunctionBody
		local start = expect("|").span.x

		local arguments = {}
		local first = true

		while not current_is "|" do
			if current_kind == "eof" and can_yield then
				yield()
				continue
			end
			if not first then expect "," end
			table.insert(arguments, expect "identifier")
			first = false
		end

		expect "|"
		expect "{"

		local block = parse_block "}"

		local finish = expect("}").span.y
		return {
			span = vector.create(start, finish, 0),
			arguments = arguments,
			block = block,
		}
	end

	function parse_lambda(): types.Expression_Lambda
		local body = parse_function_body()
		return {
			kind = "lambda",
			body = body,
			span = body.span,
		}
	end

	function parse_table(): types.Table
		local start = expect("{").span.x

		local fields: { types.TableField } = {}
		local first = true

		while not current_is "}" do
			if not first then expect "," end
			-- print("token", current_token.text)
			first = false

			if current_is "identifier" and lookahead_is "=" then
				-- print("ident")
				local key = expect "identifier"
				expect "="
				local value = parse_expression()
				table.insert(
					fields,
					{ kind = "namekey", name = key, value = value }
				)
			elseif current_is "[" then
				expect "["
				local key = parse_expression()
				expect "]"
				expect "="
				local value = parse_expression()
				table.insert(
					fields,
					{ kind = "exprkey", key = key, value = value }
				)
			else
				local expr = parse_expression()

				table.insert(fields, { kind = "nokey", value = expr })
			end

			-- print(current_kind)
		end

		local finish = expect("}").span.y
		return { fields = fields, span = vector.create(start, finish, 0) }
	end

	function parse_vector(): types.Expression_Vector
		local from = expect "["

		local values = {}

		local n = 0
		while n < 3 and not current_is "]" do
			if n ~= 0 then expect "," end
			n += 1

			local expression = parse_expression()
			values[n] = expression
		end

		local upto = expect "]"

		return {
			kind = "vector",
			span = vector.create(from.span.x, upto.span.y, 0),
			contents = values,
		}
	end

	function parse_expression(): types.Expression
		if current_is "$" and lookahead_is "(" then
			-- nested call
			local start = expect("$").span.x
			local expr
			if lookahead_is "$" or lookahead_is "identifier" then
				expect "("
				expr = parse_command()
			else
				expect "("
				expr = parse_expression()
			end
			local finish = expect(")").span.y
			return {
				kind = "evaluate",
				body = expr,
				span = vector.create(start, finish, 0),
			} :: any
		elseif current_is "$" then
			-- variable
			local var = parse_var()
			return { kind = "var", var = var, span = var.span }
		elseif current_is "string" then
			-- string
			local str = expect "string"
			return {
				kind = "string" :: "string",
				token = str,
				span = str.span,
			}
		elseif current_is "number" then
			-- number
			local n = expect "number"
			return {
				kind = "number" :: "number",
				token = n,
				span = n.span,
			}
		elseif current_is "true" then
			-- boolean
			local b = expect "true"
			return {
				kind = "boolean" :: "boolean",
				token = b,
				span = b.span,
			}
		elseif current_is "false" then
			local f = expect "false"
			return {
				kind = "boolean" :: "boolean",
				token = f,
				span = f.span,
			}
		elseif current_is "identifier" then
			local token = expect "identifier"
			return {
				kind = "string",
				token = {
					kind = "string",
					text = `"{token.text}"`,
					span = token.span,
				} :: Token<"string">,
				span = token.span,
			} :: any
		elseif current_is "|" then
			-- lambda
			return parse_lambda()
		elseif current_is "{" then
			local t = parse_table()
			return { kind = "table", table = t, span = t.span }
		elseif current_is "[" then
			return parse_vector()
		elseif current_kind == "eof" and can_yield then
			yield()
			return parse_expression()
		else
			return report(`expected expression, got {current_kind}`)
		end
	end

	function parse_command(): types.Command
		-- print("starting command", current_kind, lookahead_kind, current_token.text, lookahead_token.text)
		local var = parse_var()
		local arguments: { types.Expression } = {}

		while
			current_kind ~= "\n"
			and (
				current_is "$"
				or current_is "string"
				or current_is "number"
				or current_is "true"
				or current_is "false"
				or current_is "identifier"
				or current_is "{"
				or current_is "|"
				or current_is "["
			)
		do
			local expression = parse_expression()
			table.insert(arguments, expression)
		end

		local finish = if #arguments > 0
			then arguments[#arguments].span.y
			else var.span.y

		return {
			kind = "command",
			prefix = var,
			arguments = arguments,
			span = vector.create(var.span.x, finish, 0),
		}
	end

	function parse_if(): types.Stat_If
		local start = expect("if").span.x
		local conditionals: { types.If } = {}
		local else_block: types.Block?
		local first = true
		local finish = 0

		while true do
			if first then
				expect "("
				local expression = if current_is "identifier"
					then parse_command()
					else parse_expression()
				expect ")"
				expect "{"
				local block = parse_block "}"
				finish = expect("}").span.y

				table.insert(
					conditionals,
					{ condition = expression, block = block }
				)

				first = false
			elseif current_is "else" and lookahead_is "if" then
				expect "else"
				expect "if"

				expect "("
				local expression = if current_is "identifier"
					then parse_command()
					else parse_expression()
				expect ")"
				expect "{"
				local block = parse_block "}"
				finish = expect("}").span.y

				table.insert(
					conditionals,
					{ condition = expression, block = block }
				)
			elseif current_is "else" then
				expect "else"
				expect "{"
				else_block = parse_block "}"
				finish = expect("}").span.y
				break
			else
				break
			end
		end

		return {
			kind = "if",
			ifs = conditionals,
			fallback = else_block,
			span = vector.create(start, finish, 0),
		}
	end

	function parse_while(): types.Stat_While
		local start = expect("while").span.x
		expect "("
		local expression = if current_is "identifier"
			then parse_command()
			else parse_expression()
		expect ")"

		expect "{"
		-- print("currently", current_kind, current_token.text, "next", lookahead_kind)
		local block = parse_block "}"
		local finish = expect("}").span.y

		return {
			kind = "while",
			expression = expression,
			block = block,
			span = vector.create(start, finish, 0),
		}
	end

	function parse_for(): types.Stat_For
		local start = expect("for").span.x
		expect "("
		local expression = parse_expression_or_command()
		expect ")"
		local block = parse_function_body()

		return {
			kind = "for",
			expression = expression,
			call = block,
			span = vector.create(start, block.span.y, 0),
		}
	end

	function parse_return(): types.Last_Return
		local span = expect("return").span
		local start = span.x
		local finish = span.y

		local values = {}

		while current_kind ~= "}" and current_kind ~= "eof" do
			if #values > 0 then expect "," end
			local expr = parse_expression()
			table.insert(values, expr)
			finish = expr.span.y
		end

		return {
			kind = "return",
			values = values,
			span = vector.create(start, finish, 0),
		}
	end

	function parse_block(
		delimiter: types.TokenKindRest,
		start: number?
	): types.Block
		local statements: { types.Statement } = {}
		local last_statement: types.LastStatement?
		local start = start or 0
		local finish = start
		-- print("starting with", current_kind, current_token.text, "next", lookahead_kind, lookahead_token.text)
		-- print("getting next")
		while current_kind ~= delimiter do
			-- print("getting next", current_kind)
			-- print(current_kind, lookahead_kind)
			if last_statement then
				report "expected to finish after last statement"
			end

			if current_is "identifier" and lookahead_is "=" then
				-- print("assign")
				local key = expect "identifier"
				expect "="
				local value = parse_expression_or_command()
				local statement = { kind = "assign", left = key, right = value }
				table.insert(statements, statement)
			elseif current_is "if" then
				table.insert(statements, parse_if())
			elseif current_is "while" then
				table.insert(statements, parse_while())
			elseif current_is "for" then
				table.insert(statements, parse_for())
			elseif current_is "return" then
				last_statement = parse_return()
			elseif current_is "break" then
				local span = expect("break").span
				last_statement = { kind = "break" :: "break", span = span }
			elseif current_is "continue" then
				local span = expect "continue"
				last_statement =
					{ kind = "continue" :: "continue", span = span }
			elseif current_is "identifier" or current_is "$" then
				table.insert(statements, parse_command())
			elseif current_is ";" then
				consume()
			elseif
				current_kind == "eof"
				and delimiter ~= "eof"
				and can_yield
			then
				yield()
			elseif current_kind == delimiter then
				finish = current_pos
				break
			else
				report(`cannot parse {current_kind}`)
			end

			finish = current_pos
		end

		return {
			span = vector.create(start, finish, 0),
			body = statements,
			last_statement = last_statement,
		}
	end

	return parse_block "eof"
end

export type Result = {
	status: "finished",
	src: string,
	value: types.Block,
} | {
	status: "pending",
	src: string,
	append: (new: string) -> Result,
	set: (new: string) -> Result,
} | {
	status: "error",
	src: string,
	why: string,
}

local function generate(input: string, yield: boolean?): Result
	local value = input
	local thread = coroutine.create(parse)
	local get_result

	local function append(src: string)
		value ..= src
		local b = buffer.fromstring(value)
		return get_result(coroutine.resume(thread, b, yield))
	end

	local function overwrite(src: string)
		value = src
		local b = buffer.fromstring(src)
		return get_result(coroutine.resume(thread, b, yield))
	end

	function get_result(ok: boolean, result: any): Result
		if coroutine.status(thread) == "suspended" then
			return {
				status = "pending",
				src = value,
				append = append,
				set = overwrite,
			} :: any
		elseif ok == false then
			return {
				status = "error",
				src = value,
				why = result,
			} :: any
		elseif coroutine.status(thread) == "dead" then
			return {
				status = "finished",
				src = value,
				value = result,
			} :: any
		else
			error "?"
		end
	end

	return overwrite(input)
end

return generate
