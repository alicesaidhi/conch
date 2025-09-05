local analyze = require "@self/analysis"
local ast = require "@self/ast"
local treewalker = require "@self/treewalker"

export type LanguageVm = analyze.LanguageVm
export type TypeAnalysisInfo = analyze.TypeAnalysisInfo
export type SimpleValue = analyze.SimpleValue
export type Overload = analyze.Overload
export type Suggestion = analyze.Suggestion
export type Metadata = analyze.Metadata
export type AnalysisArgument = analyze.AnalysisArgument
export type AnalysisResult = analyze.AnalysisResult
export type AnalysisInputState = analyze.AnalysisInputState

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

local function attach_info(vm: LanguageVm, metadata: Metadata): TypeAnalysisInfo
	if metadata.is_var then
		vm.vars_metadata[metadata.key] = metadata
		return { remove = function() vm.vars_metadata[metadata.key] = nil end }
	else
		vm.global_metadata[metadata.key] = metadata
		return { remove = function() vm.global_metadata[metadata.key] = nil end }
	end
end

local function run(vm: LanguageVm, input: string): RunResult
	local b = buffer.fromstring(input)
	local ok, output: ast.Output = pcall(ast.parse, b)

	if not ok then
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

local language: LanguageInterface = {
	version = "0.3.1",

	create_vm = create_vm,

	set_command = set_command,
	set_variable = set_variable,

	attach_info = attach_info,

	run = run,
	analyze = analyze,
}

return language
