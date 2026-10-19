import type { AnalysisResult, LanguageVm, RunResult, Type, TypeAnalysisInfo } from "./analysis"

export * from "./analysis"
export * from "./ast"

/**
 * The version of conch-language.
 */
export const version: string;
/**
 * Creates a new vm to run code in.
 */
export function create_vm(): LanguageVm;
/**
 * Sets a global in the vm, which is how commands are added.
 */
export function set_command(vm: LanguageVm, key: string, value: unknown): void;
/**
 * Sets a variable in the root scope of the vm.
 */
export function set_variable(vm: LanguageVm, key: string, value: unknown): void;
/**
 * Attaches type information to a global or a variable, which is used for autocomplete and type matching.
 */
export function attach_info(vm: LanguageVm, is_var: boolean, key: string, value: Type): TypeAnalysisInfo;
/**
 * Parses and runs the given input in the vm.
 */
export function run(vm: LanguageVm, input: string): RunResult;
/**
 * Analyzes the given input and returns the issues and suggestions for the given cursor position.
 */
export function analyze(vm: LanguageVm, input: string, cursor: number): AnalysisResult;
/**
 * Returns the type the value matched with, or undefined when it doesn't match.
 */
export function matches_type(value: unknown, type: Type, exact?: boolean): Type | undefined;

type Display = (node: unknown) => string;

/**
 * Turns parsed nodes back into source code.
 */
export const display: {
	readonly display_assign: Display,
	readonly display_block: Display,
	readonly display_break: Display,
	readonly display_command: Display,
	readonly display_continue: Display,
	readonly display_delimited: Display,
	readonly display_else_branch: Display,
	readonly display_elseif_branch: Display,
	readonly display_expression: Display,
	readonly display_for: Display,
	readonly display_function_body: Display,
	readonly display_if: Display,
	readonly display_if_branch: Display,
	readonly display_last_statement: Display,
	readonly display_return: Display,
	readonly display_separated: Display,
	readonly display_statement: Display,
	readonly display_table: Display,
	readonly display_tablefield: Display,
	readonly display_token: Display,
	readonly display_var: Display,
	readonly display_var_root: Display,
	readonly display_var_suffix: Display,
	readonly display_while: Display,
};
