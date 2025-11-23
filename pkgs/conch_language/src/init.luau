local analyze = require "@self/analysis"
local ast = require "@self/ast"
local treewalker = require "@self/treewalker"

export type LanguageVm = analyze.LanguageVm
export type TypeAnalysisInfo = analyze.TypeAnalysisInfo

export type SimpleValue = analyze.SimpleValue
export type Suggestion = analyze.Suggestion
export type Metadata = analyze.Metadata
export type Type = analyze.Type
export type LiteralType = analyze.LiteralType
export type StrangeType = analyze.StrangeType
export type UnionType = analyze.UnionType
export type IntersectionType = analyze.IntersectionType
export type TableType = analyze.TableType
export type FunctionType = analyze.FunctionType
export type CommandType = analyze.CommandType
export type CommandArgument = analyze.CommandArgument
export type AnalysisResult = analyze.Result
export type InputState = analyze.InputState

-----

export type RunResult =
	| { ok: true, values: { unknown }? }
	| { ok: false, why: { string } }

export type LanguageInterface = {
	version: string,

	create_vm: () -> LanguageVm,
	set_command: (LanguageVm, key: string, value: unknown) -> (),
	set_variable: (LanguageVm, key: string, value: unknown) -> (),

	-- attaches info about a certain value
	attach_info: (LanguageVm, Metadata) -> TypeAnalysisInfo,

	run: (LanguageVm, input: string) -> RunResult,

	analyze: (
		LanguageVm,
		input: string,
		cursor: number
	) -> AnalysisResult?,
}

local function create_vm(): LanguageVm
	return {
		global_metadata = {},
		vars_metadata = {},

		state = treewalker.create_state(),
	}
end

local function set_command(vm: LanguageVm, key: string, value: unknown)
	vm.state.globals[key] = value
end

local function set_variable(vm: LanguageVm, key: string, value: unknown)
	vm.state.scope.vars[key] = value
end

local function attach_info(
	vm: LanguageVm,
	is_var: boolean,
	key: string,
	value: Type
): TypeAnalysisInfo
	if is_var then
		vm.vars_metadata[key] = value
		return { remove = function() vm.vars_metadata[key] = nil end }
	else
		vm.global_metadata[key] = value
		return { remove = function() vm.global_metadata[key] = nil end }
	end
end

local function run(vm: LanguageVm, input: string): RunResult
	local b = buffer.fromstring(input)
	local ok, output: ast.Output = pcall(ast.parse, b)

	if not ok or not output.result then
		local why = {}

		for _, issue in output.issues do
			table.insert(
				why,
				`{issue.why} at {issue.span.x}:{issue.span.y}:{issue.span.z}`
			)
		end

		return { ok = false, why = why }
	end

	local result = treewalker.execute(vm.state, output.result)

	if result.ok then
		return result
	else
		return { ok = false, why = { result.err } }
	end
end

local language = {
	version = "0.4.0-rc.0",

	create_vm = create_vm,

	set_command = set_command,
	set_variable = set_variable,

	attach_info = attach_info,

	run = run,
	analyze = analyze.analyze,
	matches_type = analyze.matches_type,
}

return language
