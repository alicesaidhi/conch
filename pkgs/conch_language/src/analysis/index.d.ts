import { Issue } from "../ast";

export type Suggestion = {
	text: string,
	display: string,
}

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
	replace: vector,
	suggestions: Suggestion[],
	additional_info?: {
		name: string,
		description: string,
		optional: boolean,
		type: string,
	},
	issues: Issue[],
};