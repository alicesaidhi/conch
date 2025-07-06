--!strict

export type Span = vector

export type Separated<Node> = { Node }
export type Surrounded<T, L, R> = { left: Token<L>, right: Token<R>, value: T }

export type TokenKindText = | "identifier" | "number" | "string" | "error"

export type TokenKindRest =
	-- OPERATORS
	| "."
	| "="
	| "$"
	| ","
	-- BRACKETS
	| "("
	| ")"
	| "{"
	| "}"
	| "["
	| "]"
	| "|"
	-- KEYWORDS
	| "true"
	| "false"
	| "nil"
	| "if"
	| "else"
	| "while"
	| "for"
	| "return"
	| "break"
	| "continue"
	-- LINE ENDINGS
	| "\n"
	| ";"
	-- WHITESPACE
	| "eof"
	| "whitespace"
	| "comment"

export type TokenKind = TokenKindText | TokenKindRest

export type Token<T = TokenKind> = {
	kind: T,
	text: string,
	span: Span,
}

---

export type Expression_Nil = {
	read kind: "nil",
	read span: Span,
	read token: Token<"nil">,
}

export type Expression_Boolean = {
	read kind: "boolean",
	read span: Span,
	read token: Token<"true"> | Token<"false">,
}

export type Expression_Number = {
	read kind: "number",
	read span: Span,
	read token: Token<"number">,
}

export type Expression_String = {
	read kind: "string",
	read span: Span,
	read token: Token<"string">,
}

export type Expression_Identifier = {
	read kind: "identifier",
	read span: Span,
	read token: Token<"identifier">,
}

export type Expression_Table = {
	read kind: "table",
	read span: Span,
	read table: Table,
}

export type Expression_Lambda = {
	read kind: "lambda",
	read span: Span,
	read body: FunctionBody,
}

export type Expression_Evaluate = {
	read kind: "evaluate",
	read span: Span,
	read operator: Token<"$">,
	read body: Surrounded<ExpressionOrCommand, "(", ")"?>,
}

export type Expression_Var = {
	read kind: "var",
	read span: Span,
	read var: Var,
}

export type Expression_Vector = {
	read kind: "vector",
	read span: Span,
	read contents: Surrounded<{ Expression }, "[", "]"?>,
}

export type Expression =
	| Expression_Nil
	| Expression_Boolean
	| Expression_Number
	| Expression_String
	| Expression_Identifier
	| Expression_Table
	| Expression_Lambda
	| Expression_Evaluate
	| Expression_Var
	| Expression_Vector

export type VarRoot_Global = {
	read kind: "global",
	read span: Span,
	read token: Token<"identifier">,
}

export type VarRoot_Name = {
	read kind: "name",
	read span: Span,
	read operator: Token<"$">,
	read name: Token<"identifier">?,
}

export type VarRoot_Paren = {
	read kind: "paren",
	read span: Span,
	read operator: Token<"$">,
	read expr: Surrounded<ExpressionOrCommand?, "(", ")"?>,
}

export type VarRoot = | VarRoot_Global | VarRoot_Name | VarRoot_Paren

export type VarSuffix_NameIndex = {
	read kind: "nameindex",
	read span: Span,
	read operator: Token<".">,
	read name: Token<"identifier">?,
}

export type VarSuffix_ExprIndex = {
	read kind: "exprindex",
	read span: Span,
	read expr: Surrounded<ExpressionOrCommand?, "[", "]"?>,
}

export type VarSuffix = | VarSuffix_NameIndex | VarSuffix_ExprIndex

export type Var = {
	read prefix: VarRoot,
	read span: Span,
	read suffixes: { VarSuffix },
}

export type Command = {
	read kind: "command",
	read prefix: Var,
	read span: Span,
	read arguments: { Expression },
}

export type ExpressionOrCommand = | Command | Expression

export type TableField_NameKey = {
	read kind: "namekey",
	read span: Span,
	read name: Token<"identifier">,
	read operator: Token<"=">,
	read value: Expression?,
}

export type TableField_ExprKey = {
	read kind: "exprkey",
	read span: Span,
	read key: Surrounded<Expression?, "[", "]"?>,
	read operator: Token<"=">?,
	read value: Expression?,
}

export type TableField_NoKey = {
	read kind: "nokey",
	read span: Span,
	read value: Expression,
}

export type TableField =
	| TableField_ExprKey
	| TableField_NameKey
	| TableField_NoKey

export type Table = {
	read span: Span,
	read fields: Surrounded<Separated<TableField>, "{", "}"?>,
}

export type Stat_Assign = {
	read kind: "assignment",
	read span: Span,
	read operator: Token<"=">,
	read left: Token<"identifier">,
	read right: ExpressionOrCommand?,
}

export type FunctionBody = {
	read arguments: Surrounded<Separated<Token<"identifier">>, "|", "|"?>,
	read block: Surrounded<Block, "{", "}"?>?,
	read span: Span,
}

export type Last_Return = {
	read kind: "return",
	read span: Span,
	read keyword: Token<"return">,
	read values: Separated<ExpressionOrCommand>,
}

export type Last_Continue = {
	read kind: "continue",
	read keyword: Token<"continue">,
	read span: Span,
}

export type Last_Break = {
	read kind: "break",
	read keyword: Token<"break">,
	read span: Span,
}

export type LastStatement = | Last_Return | Last_Continue | Last_Break

export type If = {
	read elsekeyword: Token<"else">?,
	read keyword: Token<"if">,
	read condition: Surrounded<ExpressionOrCommand, "("?, ")"?>,
	read block: Surrounded<Block, "{"?, "}"?>,
	read span: Span,
}

export type Stat_If = {
	read kind: "if",
	read ifs: { If },

	read else_keyword: Token<"else">?,
	read fallback: Surrounded<Block, "{"?, "}"?>?,

	read span: Span,
}

export type Stat_While = {
	read kind: "while",
	read keyword: Token<"while">,
	read expression: Surrounded<ExpressionOrCommand, "("?, ")"?>,

	read block: Surrounded<Block, "{"?, "}"?>,
	read span: Span,
}

export type Stat_For = {
	read kind: "for",
	read keyword: Token<"for">,
	read expression: Surrounded<ExpressionOrCommand, "(", ")"?>?,

	read call: FunctionBody?,
	read span: Span,
}

export type Statement = | Stat_If | Stat_While | Stat_For | Stat_Assign | Command

export type Block = {
	read body: { Statement },
	read last_statement: LastStatement?,
	read span: Span,
}

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
			or c == char "_"
			or c == char "@"
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

		while not is_whitespace(c) and c ~= 0 do
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

		return "number" -- we do not care!!!!!
	end

	local function read_kind(): TokenKindRest | TokenKindText
		local c: number = peek()

		if c == 0 then return "eof" end

		if c == char "#" then
			bump_any()
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

		bump()
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

	local parse_expression: () -> Expression
	local parse_command: () -> Command
	local parse_block: () -> Block
	local parse_lambda: () -> Expression_Lambda
	local parse_expression_or_command: () -> ExpressionOrCommand
	local parse_var: () -> Var
	local parse_var_root: () -> VarRoot
	local parse_var_suffix: () -> VarSuffix
	local parse_var_suffixes: () -> { VarSuffix }
	local parse_function_body: () -> FunctionBody
	local parse_if: () -> Stat_If
	local parse_while: () -> Stat_While
	local parse_for: () -> Stat_For
	local parse_return: () -> Last_Return
	local parse_vector: () -> Expression_Vector

	function parse_var_root(): VarRoot
		-- print("root:", current_kind, current_token.text)
		if current_is "identifier" then
			-- print("global")
			local token = expect "identifier"
			return { kind = "global", span = token.span, token = token }
		elseif current_is "$" and lookahead_is "(" then
			local operator = expect "$"
			local left = expect "("

			if current_is "eof" or current_is ";" then
				return {
					kind = "paren",
					span = vector.create(operator.span.x, left.span.y, 0),
					expr = { left = left },
					operator = operator,
				} :: VarRoot_Paren
			else
				local expr = parse_expression_or_command()
				if current_is "}" then
					local right = expect "}"

					return {
						kind = "paren",
						span = vector.create(operator.span.x, right.span.y, 0),
						expr = { left = left, right = right, value = expr },
						operator = operator :: Token<"=">,
					} :: VarRoot_Paren
				else
					return {
						kind = "paren",
						span = vector.create(operator.span.x, expr.span.y, 0),
						expr = { left = left, value = expr },
						operator = operator,
					} :: VarRoot_Paren
				end
			end
		elseif current_is "$" then
			local operator = expect "$"

			if current_is "identifier" then
				local token = expect "identifier"

				return {
					kind = "name",
					span = vector.create(operator.span.x, token.span.y, 0),
					name = token,
					operator = operator,
				}
			else
				return {
					kind = "name",
					span = vector.create(operator.span.x, operator.span.y, 0),
					operator = operator,
				} :: VarRoot_Name
			end
		else
			return report(`expected identifier, got {display(lookahead_token)}`)
		end
	end

	function parse_var_suffix(): VarSuffix
		if current_is "." then
			local token = expect "."

			if current_is "identifier" == false then
				return {
					kind = "nameindex",
					span = vector.create(token.span.x, token.span.y, 0),
					operator = token,
				} :: VarSuffix_NameIndex
			end

			local identifier = expect "identifier"
			return {
				kind = "nameindex",
				span = vector.create(token.span.x, identifier.span.y, 0),
				operator = token,
				name = identifier,
			}
		elseif current_is "[" then
			local left = expect "["

			if current_kind == "eof" then
				return {
					kind = "exprindex",
					span = vector.create(left.span.x, left.span.y, 0),
					expr = { left = left },
				} :: VarSuffix_ExprIndex
			end

			local expr = parse_expression_or_command()

			if current_kind ~= "]" then
				return {
					kind = "exprindex",
					span = vector.create(left.span.x, expr.span.y, 0),
					expr = { left = left, value = expr },
				} :: VarSuffix_ExprIndex
			end
			local right = expect "]"

			return {
				kind = "exprindex",
				span = vector.create(left.span.x, right.span.y, 0),
				expr = { left = left, right = right, value = expr },
			} :: VarSuffix_ExprIndex
		else
			return report "invalid"
		end
	end

	function parse_var_suffixes(): { VarSuffix }
		local suffixes: { VarSuffix } = {}
		while current_is "." or current_is "[" do
			local suffix = parse_var_suffix()
			table.insert(suffixes, suffix)
		end
		return suffixes
	end

	function parse_var(): Var
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

	function parse_expression_or_command(): ExpressionOrCommand
		if current_is "identifier" then
			return parse_command()
		else
			return parse_expression()
		end
	end

	function parse_function_body(): FunctionBody
		local left = expect "|"

		local arguments = {}
		local first = true

		while not current_is "|" do
			if not first then expect "," end
			first = false

			if current_is "identifier" then
				table.insert(arguments, expect "identifier")
			else
				break
			end
		end

		local right = if current_is "|" then expect "|" else nil
		local block_left = if current_is "{" then expect "{" else nil
		local block = parse_block "}"
		local block_right = if current_is "}" then expect "}" else nil

		return {
			arguments = { left = left, right = right, value = arguments },
			block = if block_left
					or block
					or block_right
				then { left = block_left, right = block_right, value = block }
				else nil,

			span = vector.create(
				left.span.x,
				if block_right then block_right.span.y else block.span.y,
				0
			),
		} :: FunctionBody
	end

	function parse_lambda(): Expression_Lambda
		local body = parse_function_body()
		return {
			kind = "lambda",
			body = body,
			span = body.span,
		}
	end

	function parse_table(): Table
		local left = expect "{"

		local fields: { TableField } = {}
		local first = true

		while not current_is "}" do
			if not first then expect "," end
			-- print("token", current_token.text)
			first = false

			if current_is "identifier" and lookahead_is "=" then
				-- print("ident")
				local key = expect "identifier"
				local operator = expect "="

				if current_kind == "eof" then
					table.insert(fields, {
						kind = "namekey",
						span = vector.create(key.span.x, operator.span.y, 0),
						name = key,
						operator = operator,
					})
					break
				end

				local value = parse_expression()
				table.insert(
					fields,
					{ kind = "namekey", name = key, value = value }
				)
			elseif current_is "[" then
				local bleft = expect "["
				if current_kind == "eof" then
					table.insert(fields, {
						kind = "exprkey",
						span = vector.create(bleft.span.x, bleft.span.y, 0),
						key = { left = bleft },
					})
					break
				end

				local key = parse_expression()
				local bright = if current_is "]" then expect "]" else nil
				local operator = if current_is "=" then expect "=" else nil

				if current_kind == "eof" then
					table.insert(fields, {
						kind = "exprkey",
						span = vector.create(
							bleft.span.x,
							if operator
								then operator.span.y
								elseif bright then bright.span.y
								else key.span.y,
							0
						),
						key = { left = bleft, right = bright, value = key },
						operator = operator,
					})
					break
				end

				local value = parse_expression()
				table.insert(fields, {
					kind = "exprkey",
					span = vector.create(bleft.span.x, value.span.y, 0),
					key = { left = bleft, right = bright, value = key },
					operator = operator,
					value = value,
				})
			elseif current_kind == "eof" then
				break
			else
				local expr = parse_expression()
				table.insert(fields, { kind = "nokey", value = expr })
			end

			-- print(current_kind)
		end

		if current_is "}" then
			local right = expect "}"
			return {
				fields = { left = left, right = right, value = fields },
				span = vector.create(left.span.x, right.span.y, 0),
			} :: Table
		else
			local last = left.span.y

			if #fields > 0 then
				local field = fields[#fields]
				last = field.span.y
			end

			return {
				fields = { left = left, value = fields },
				span = vector.create(left.span.x, last, 0),
			} :: Table
		end
	end

	function parse_vector(): Expression_Vector
		local left = expect "["
		local min, max = left.span.x, left.span.y
		local contents = {}

		local n = 0

		while n < 3 and not current_is "]" do
			if current_is "eof" then break end
			if n ~= 0 and current_is "," then expect "," end
			if current_is "eof" then break end
			n += 1

			local expr = parse_expression()
			contents[n] = expr
			max = expr.span.y
		end

		local right = if current_is "]" then expect "]" else nil
		if right then max = right.span.y end

		return {
			kind = "vector",
			span = vector.create(min, max, 0),
			contents = {
				left = left,
				right = right,
				value = contents,
			},
		}
	end

	function parse_expression(): Expression
		if current_is "$" and lookahead_is "(" then
			-- nested call
			local operator = expect "$"
			local left = expect "("
			local expr: Expression | Command

			if current_is "$" or current_is "identifier" then
				expr = parse_command()
			elseif current_kind == "eof" then
				return {
					kind = "evaluate",
					body = { left = left },
					operator = operator,
					span = vector.create(operator.span.x, left.span.y, 0),
				} :: Expression_Evaluate
			else
				expr = parse_expression()
			end

			if current_is ")" then
				local right = expect ")"
				return {
					kind = "evaluate",
					body = { left = left, right = right, value = expr },
					operator = operator,
					span = vector.create(operator.span.x, right.span.y, 0),
				} :: Expression_Evaluate
			end

			return {
				kind = "evaluate",
				body = { left = left, value = expr },
				operator = operator,
				span = vector.create(operator.span.x, expr.span.y, 0),
			} :: Expression_Evaluate
		elseif current_is "$" and lookahead_is "identifier" then
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
				kind = "identifier",
				token = token,
				span = token.span,
			} :: Expression_Identifier
		elseif current_is "|" then
			-- lambda
			return parse_lambda()
		elseif current_is "{" then
			local t = parse_table()
			return { kind = "table", table = t, span = t.span }
		elseif current_is "[" then
			return parse_vector()
		else
			return report(`expected expression, got {current_kind}`)
		end
	end

	function parse_command(): Command
		-- print("starting command", current_kind, lookahead_kind, current_token.text, lookahead_token.text)
		local var = parse_var()
		local arguments: { Expression } = {}

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

	function parse_if(): Stat_If
		local conditionals: { If } = {}
		local first = true
		local finish = 0

		local else_keyword: Token<"else">?
		local else_block: Surrounded<Block, "{", "}">?

		while true do
			if first then
				first = false
				local keyword = expect "if"

				local leftp = if current_is "(" then expect "(" else nil
				local expression = if current_is "identifier"
					then parse_command()
					else parse_expression()
				local rightp = if current_is ")" then expect ")" else nil
				local leftb = if current_is "{" then expect "{" else nil
				local block: Block = parse_block "}"
				local rightb = if current_is "}" then expect "}" else nil

				table.insert(conditionals, {
					keyword = keyword,
					condition = {
						left = leftp,
						right = rightp,
						value = expression,
					},
					block = { left = leftb, right = rightb, value = block },
					span = vector.create(
						keyword.span.x,
						if rightb then rightb.span.y else block.span.y,
						0
					),
				})

				first = false
			elseif current_is "else" and lookahead_is "if" then
				local keyword_else = expect "else"
				local keyword = expect "if"

				local leftp = if current_is "(" then expect "(" else nil
				local expression = if current_is "identifier"
					then parse_command()
					else parse_expression()
				local rightp = if current_is ")" then expect ")" else nil
				local leftb = if current_is "{" then expect "{" else nil
				local block: Block = parse_block "}"
				local rightb = if current_is "}" then expect "}" else nil

				table.insert(conditionals, {
					elsekeyword = keyword_else,
					keyword = keyword,
					condition = {
						left = leftp,
						right = rightp,
						value = expression,
					},
					block = { left = leftb, right = rightb, value = block },
					span = vector.create(
						keyword_else.span.x,
						if rightb then rightb.span.y else block.span.y,
						0
					),
				})
			elseif current_is "else" then
				else_keyword = expect "else"
				local left = if current_is "{" then expect "{" else nil
				local block = parse_block "}"
				local right = if current_is "}" then expect "}" else nil
				else_block = { left = left, right = right, value = block }
				break
			else
				break
			end
		end

		return {
			kind = "if",
			ifs = conditionals,

			else_keyword = else_keyword,
			fallback = else_block,

			span = vector.create(
				conditionals[1].span.x,
				if else_block and else_block.right
					then else_block.right.span.y
					elseif else_block then else_block.value.span.y
					else conditionals[#conditionals].span.y,
				0
			),
		} :: Stat_If
	end

	function parse_while(): Stat_While
		local keyword = expect "while"
		local leftp = if current_is "(" then expect "(" else nil
		local expression = if current_is "identifier"
			then parse_command()
			else parse_expression()
		local rightp = if current_is ")" then expect ")" else nil

		local leftb = if current_is "{" then expect "{" else nil
		-- print("currently", current_kind, current_token.text, "next", lookahead_kind)
		local block = parse_block "}"
		local rightb = if current_is "}" then expect "}" else nil

		return {
			kind = "while",
			keyword = keyword,
			expression = { left = leftp, right = rightp, value = expression },

			block = { left = leftb, right = rightb, value = block },
			span = vector.create(
				keyword.span.x,
				if rightb then rightb.span.y else block.span.y,
				0
			),
		} :: Stat_While
	end

	function parse_for(): Stat_For
		local keyword = expect "for"
		local left = if current_is "(" then expect "(" else nil
		local expression = parse_expression_or_command()
		local right = if current_is ")" then expect ")" else nil
		local block = if current_is "|" then parse_function_body() else nil

		return {
			kind = "for",
			keyword = keyword,
			expression = { left = left, right = right, value = expression },
			call = block,
			span = vector.create(
				keyword.span.x,
				if block
					then block.span.y
					elseif right then right.span.y
					else expression.span.y,
				0
			),
		} :: Stat_For
	end

	function parse_return(): Last_Return
		local keyword = expect "return"
		local finish = keyword.span.y

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
			keyword = keyword,
			span = vector.create(keyword.span.x, finish, 0),
		}
	end

	function parse_block(delimiter: TokenKindRest, start: number?): Block
		local statements: { Statement } = {}
		local last_statement: LastStatement?
		local start = start or current_pos
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
				local op = expect "="
				local value = parse_expression_or_command()
				local statement = {
					kind = "assign",
					span = vector.create(key.span.x, value.span.y, 0),
					operator = op,
					left = key,
					right = value,
				}
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
				local keyword = expect "break"
				last_statement = {
					kind = "break" :: "break",
					span = keyword.span,
					keyword = keyword,
				}
			elseif current_is "continue" then
				local keyword = expect "continue"
				last_statement = {
					kind = "continue" :: "continue",
					span = keyword.span,
					keyword = keyword,
				}
			elseif current_is "identifier" or current_is "$" then
				table.insert(statements, parse_command())
			elseif current_is ";" then
				consume()
			elseif current_kind == "eof" then
				break
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
	value: Block,
} | {
	status: "error",
	src: string,
	why: string,
}

local function generate(src: string): Result
	local get_result

	function get_result(ok: boolean, result: any): Result
		if ok == false then
			return {
				status = "error",
				src = src,
				why = result,
			} :: any
		else
			return {
				status = "finished",
				src = src,
				value = result,
			} :: any
		end
	end

	local b = buffer.fromstring(src)
	local ok, err = pcall(parse, b)
	return get_result(ok, err)
end

generate "ban 3d"

return generate
