import { Issue } from "../ast";

export type Metadata = {
	name: string,
	description: string,
	type: string,
	alias_of?: string,
	aliases?: string[]
}

export type SimpleValue = number | string | boolean

export type Suggestion = {
	kind?: "expression" | "assign",
	replace?: vector,
	text: string,
	display: string,
	metadata?: Metadata,
	alias_of?: string
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

	fields_metadata?: Map<LiteralType, { description?: string }>,
	fields?: Map<LiteralType, Type>,
	indexer?: Type,
	value?: Type
}

export type FunctionType = {
	kind: "function",
	argument_names: string[]
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

export type AnalysisResult = {
	replace: vector,
	suggestions: Suggestion[],
	issues: Issue[],
	additional_info?: {
		name: string,
		description?: string,
		type: string,
	},
};

export type TypeAnalysisInfo = {
	remove(): void,
}

export type Scope = {
	up?: Scope,
	root: boolean,
	vars: Record<string, unknown>,
}

export type ExecutionState = {
	globals: Record<string, unknown>,
	scope: Scope,
}

export type LanguageVm = {
	global_metadata: Record<string, Type>,
	vars_metadata: Record<string, Type>,

	state: ExecutionState,
}

export type RunResult =
	| { ok: true, values?: unknown[] }
	| { ok: false, why: string[] }
