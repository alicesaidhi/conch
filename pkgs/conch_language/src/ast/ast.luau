export type Span = vector

export type Token<T = TokenKind> = {
	read kind: T,
	read text: string,
	read span: Span,
}

export type TokenKindText = "identifier" | "string" | "number" | "error"

export type BinaryOperator =
	-- operators
	| "=="
	| "!="
	| "~="
	| ">"
	| "<"
	| ">="
	| "<="
	-- arithmetic
	| "*"
	| "/"
	| "-"
	| "+"
	| "//"
	| "^"
	| "%"
	| ".."
	-- ternary
	| "and"
	| "or"

export type UnaryOperator = | "-" | "!"

export type TokenKindRest =
	| BinaryOperator
	| UnaryOperator
	-- symbols
	| "&"
	| "="
	| "("
	| ")"
	| "$"
	| ","
	| "{"
	| "}"
	| "["
	| "]"
	| "|"
	| "."
	-- keywords
	| "true"
	| "false"
	| "nil"
	| "if"
	| "else"
	| "elseif"
	| "while"
	| "for"
	| "return"
	| "break"
	| "continue"
	-- line endings
	| "\n"
	| ";"
	-- whitespace
	| "eof"
	| "whitespace"
	| "comment"

export type TokenKind = TokenKindRest | TokenKindText

export type Separated<T> = {
	{
		value: T,
		separator: Token<",">?,
		span: Span,
	}
}

export type Delimited<LEFT, VALUE, RIGHT> = {
	read left: Token<LEFT>,
	read value: VALUE,
	read right: Token<RIGHT>?,
}

export type ExpressionNil = {
	read kind: "nil",
	read token: Token<"nil">,
	read span: Span,
}

export type ExpressionBoolean = {
	read kind: "boolean",
	read token: Token<"true"> | Token<"false">,
	read span: Span,
}

export type ExpressionNumber = {
	read kind: "number",
	read token: Token<"number">,
	read span: Span,
}

export type ExpressionBinary = {
	read kind: "binary",
	read left: Expression,
	read operator: Token<BinaryOperator>,
	read right: Expression?,
	read span: Span,
}

export type ExpressionString = {
	read kind: "string",
	read token: Token<"string"> | Token<"identifier">,
	read span: Span,
}

export type ExpressionLambda = {
	read kind: "lambda",
	read span: Span,
	read body: FunctionBody,
}

export type FunctionBody = {
	read arguments: Delimited<
		"|",
		Separated<Token<"identifier"> | false>,
		"|"
	>,
	read block: Delimited<"{", Block, "}">?,
	read span: Span,
}

export type ExpressionVector = {
	read kind: "vector",
	read contents: Delimited<
		"[",
		Separated<Expression? | ExpressionCommand>,
		"]"
	>,
	read span: Span,
}

export type ExpressionUnary = {
	read kind: "unary",
	read operator: Token<UnaryOperator>,
	read value: Expression?,
	read span: Span,
}

export type ExpressionEvaluate = {
	read kind: "evaluate",
	read command: Delimited<"(", Expression? | ExpressionCommand, ")">,
	read span: Span,
}

export type Command = {
	read kind: "command",
	read span: Span,
	read var: Var,
	read arguments: { SimpleExpression },
}

export type ExpressionCommand = {
	read kind: "command",
	read prefix: Token<"&">,
	read command: Command?,
	read span: Span,
}

export type SimpleExpression =
	| ExpressionNil
	| ExpressionBoolean
	| ExpressionNumber
	| ExpressionString
	| ExpressionTable
	| ExpressionLambda
	| ExpressionEvaluate
	| Var
	| ExpressionUnary
	| ExpressionVector
	| Token<"error">

export type Expression = | SimpleExpression | ExpressionBinary

export type VarRootGlobal = {
	read kind: "global",
	read token: Token<"identifier">,
	read span: Span,
}

export type VarRootVariable = {
	read kind: "name",
	read span: Span,
	read var: Token<"$">,
	read name: Token<"identifier">?,
}

export type VarRootParen = {
	read kind: "paren",
	read span: Span,
	read var: Token<"$">,
	read node: Delimited<"(", Expression | ExpressionCommand?, ")">,
}

export type VarRoot = | VarRootGlobal | VarRootVariable | VarRootParen

export type VarSuffixNameIndex = {
	read kind: "name_index",
	read span: Span,
	read period: Token<".">,
	read name: Token<"identifier">?,
}

export type VarSuffixExpressionIndex = {
	read kind: "expression_index",
	read span: Span,
	read period: Token<".">,
	read node: Delimited<"[", Expression? | ExpressionCommand, "]">,
}

export type VarSuffix = | VarSuffixNameIndex | VarSuffixExpressionIndex

export type Var = {
	read kind: "var",
	read root: VarRoot,
	read suffixes: { VarSuffix },
	read span: Span,
}

export type TableFieldNameKey = {
	read kind: "name_key",
	read name: Token<"identifier">,
	read equals: Token<"=">,
	read value: Expression | ExpressionCommand?,
	read span: Span,
}

export type TableFieldExpressionKey = {
	read kind: "expression_key",

	read key: Delimited<"[", Expression | ExpressionCommand?, "]">?,
	read equals: Token<"=">?,
	read value: Expression | ExpressionCommand?,

	read span: Span,
}
export type TableFieldNoKey = {
	read kind: "nokey",
	read value: Expression | ExpressionCommand?,

	read span: Span,
}

export type TableField =
	| TableFieldNoKey
	| TableFieldExpressionKey
	| TableFieldNameKey

export type ExpressionTable = {
	read kind: "table",
	read values: Delimited<"{", Separated<TableField>, "}">,
	read span: Span,
}

export type Continue = {
	read kind: "continue",
	read token: Token<"continue">,
	read span: Span,
}

export type Break = {
	read kind: "break",
	read token: Token<"break">,
	read span: Span,
}
export type Return = {
	read kind: "return",
	read token: Token<"return">,
	read values: Separated<Expression? | ExpressionCommand>,
	read span: Span,
}

export type LastStatement = | Continue | Break | Return

export type IfBranch = {
	read condition: Delimited<"(", (Expression | ExpressionCommand)?, ")">?,
	read block: Delimited<"{", Block, "}">?,
	read span: Span,
}

export type ElseIfBranch = {
	read ifelse: Token<"elseif">,
	read branch: IfBranch,
	read span: Span,
}

export type ElseBranch = {
	read token: Token<"else">,
	read block: Delimited<"{", Block, "}">?,
	read span: Span,
}

export type Assign = {
	read kind: "assign",
	read identifier: Token<"identifier">,
	read equals: Token<"=">,
	read value: Expression | ExpressionCommand?,
	read span: Span,
}

export type If = {
	read kind: "if",
	read token: Token<"if">,

	read first_branch: IfBranch,
	read branches: { ElseIfBranch },

	read else_branch: ElseBranch?,

	read span: Span,
}

export type While = {
	read kind: "while",
	read token: Token<"while">,
	read condition: Delimited<"(", (Expression | ExpressionCommand)?, ")">?,
	read block: Delimited<"{", Block, "}">?,
	read span: Span,
}

export type For = {
	read kind: "for",
	read token: Token<"for">,
	read expression: Delimited<"(", (Expression | ExpressionCommand)?, ")">?,
	read body: Expression | ExpressionCommand?,
	read span: Span,
}

export type Statement = | If | While | For | Command | Assign

export type Block = {
	read body: { Statement },
	read last_statement: LastStatement?,
	read span: Span,
}

export type Ast = {
	block: Block,
}

return {}
