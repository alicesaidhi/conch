import { Issue } from "../ast";

export type Metadata = {
	name: string,
	description: string,
	type: string
}

type SimpleValue = number | string | boolean

export type Suggestion = {
	kind?: "expression" | "assign",
	replace: vector,
	text: string,
	display: string,
	metadata?: Metadata
}

export type LiteralType = {
	kind: "literal",
	value: SimpleValue | undefined
}

export type StrangeType = {
	kind: "strange",

	type: string,
	id: string,
	convert?: ((input: unknown) => unknown),

	suggestions?: Type | ((text: string) => Suggestion[]),
	match?: Type | ((item: unknown) => boolean),
	exact_match?: Type | ((item: unknown) => boolean)
}

export type UnionType = {
	kind: "union",
	fields: Type[]
}

export type IntersectionType = {
	kind: "intersection",
	fields: Type[]
}

export type TableType = {
	kind: "table",

	fields_metadata?: Map<LiteralType, { description: string }>,
	fields?: Map<LiteralType, Type>,
	indexer?: Type,
	value: Type
}

export type FunctionType = {
	kind: "function",
	argument_namess: string[]
}

export type CommandArgument = {
	kind: "argument",
	name: string,
	description: string,
	type?: Type,
	varargs: boolean
}
export type CommandType = {
	kind: "command",
	name: string,
	description?: string,
	arguments: CommandArgument[]
}

export type Type = | LiteralType | TableType | StrangeType | FunctionType | CommandType | IntersectionType | UnionType

export type AnalysisArgument = {
	kind: "literal",
	name: string,
	description?: string,
	value: string | boolean,
	optional: boolean,
} | {
	kind: "argument",
	name: string,
	description?: string,
	type: string,
	unique_identifier: string,

	suggestions?: (text: string) => Suggestion[],

	optional: boolean,
	vararg: boolean,
}

export type AnalysisResult = {
	result?: {
		replace: vector,
		suggestions: Suggestion[],
		additional_info?: {
			name: string,
			description: string,
			optional: boolean,
			type: string,
		},
	},
	issues: Issue[],
};