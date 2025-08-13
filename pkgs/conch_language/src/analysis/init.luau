local ast = require "./ast"
local treewalker = require "./treewalker"
export type LanguageVm = {
	global_metadata: { [string]: Metadata },
	vars_metadata: { [string]: Metadata },

	state: treewalker.ExecutionState,
}
export type TypeAnalysisInfo = {
	remove: (TypeAnalysisInfo) -> (),
}

-- a value that can be evaluated by a basic treewalker
export type SimpleValue = | number | string | boolean

export type Overload = {
	read description: string?,
	read arguments: { AnalysisArgument },
}

export type Suggestion = {
	read text: string,
	read display: string,
}

export type Metadata = {
	read name: string,
	read description: string,
	read key: string,
	read is_var: boolean?,

	read overloads: { Overload },
}

export type AnalysisArgument = | {
	read kind: "literal",
	read name: string,
	read description: string?,

	read value: string | boolean,

	optional: boolean,
} | {
	read kind: "argument",
	read name: string,
	read description: string?,
	read type: string,
	unique_identifier: string,

	read suggestions: ((unknown) -> { Suggestion })?,

	optional: boolean,
	vararg: boolean,
}

export type AnalysisResult = {
	replace: vector,
	suggestions: { Suggestion },
	additional_info: {
		name: string,
		description: string,
		optional: boolean,
		type: string,
	}?,
	issues: { ast.Issue },
}

export type AnalysisInputState = {
	vars: { [string]: unknown },
	globals: { [string]: unknown },

	cursor: number,
	input: string,
	vm: LanguageVm,
	result: {
		replace: vector,
		suggestions: { Suggestion },
		additional_info: {
			name: string,
			description: string?,
			optional: boolean,
			type: string,
		}?,
	}?,
	issues: { ast.Issue },
}

--[=[
Communicates if the cursor is either after or before the node
]=]
local function span_cursor(
	state: AnalysisInputState,
	span: vector
): "before" | "within" | "after"
	return if state.cursor < span.x
		then "before"
		elseif state.cursor > span.y then "after"
		else "within"
end

local null = newproxy()
local slash_characters: { [string]: string } = {
	a = "\a",
	b = "\b",
	f = "\f",
	n = "\n",
	r = "\r",
	t = "\t",
	v = "\v",
	["\\"] = "\\",
	["'"] = "'",
	['"'] = '"',
}
--[=[
Converts tokens into a value
]=]
local function get_value<T>(token: ast.Token<ast.TokenKind>): unknown
	if token.kind == "number" then
		local n = tonumber(token.text)
		return n or null
	elseif token.kind == "string" then
		local text = string.sub(token.text, 2, -2)

		text = string.gsub(
			text,
			"\\([0-9][0-9]?[0-9]?)",
			function(value: string)
				local code = tonumber(value)
				assert(code)
				return string.char(code)
			end
		)

		for key, value in slash_characters do
			text = string.gsub(text, `\\{key}`, value)
		end

		return text
	elseif token.kind == "identifier" then
		return token.text
	elseif token.kind == "true" then
		return true
	elseif token.kind == "false" then
		return false
	elseif token.kind == "nil" then
		return nil
	else
		return null
	end
end

local function char(c: string) return string.byte(c) end

local function is_start_ident_char(c: number)
	return (char "a" <= c and c <= char "z")
		or (char "A" <= c and c <= char "Z")
		or c == char "@"
		or c == char "_"
end

local function is_digit_char(c: number): boolean
	return char "0" <= c and c <= char "9"
end

local function is_ident_char(c: number)
	return is_start_ident_char(c) or c == char "-" or is_digit_char(c)
end

local function is_identifier(input: string)
	if is_start_ident_char(string.byte(input, 1, 1)) then
		for i = 2, #input do
			if not is_ident_char(string.byte(input, i, i)) then return false end
		end
		return true
	else
		return false
	end
end

local function wrap_if_necessary(input: string)
	if is_identifier(input) then
		return input
	else
		return string.format("%q", input)
	end
end

local function evaluate_expression(
	node: ast.Expression | ast.ExpressionCommand
): ...unknown
	if node.kind == "boolean" then
		return get_value(node.token)
	elseif node.kind == "evaluate" then
		if not node.command.value then return null end
		return evaluate_expression(node.command.value)
	elseif node.kind == "nil" then
		return get_value(node.token)
	elseif node.kind == "number" then
		return get_value(node.token)
	elseif node.kind == "string" then
		return get_value(node.token)
	elseif node.kind == "unary" then
		if not node.value then return null end
		local value: any = evaluate_expression(node.value)

		if node.operator.kind == "!" then
			return not value
		elseif node.operator.kind == "-" then
			local ok, result = pcall(function() return -value end)
			return if ok then result else null
		else
			return null
		end
	else
		return null
	end
end

local autocomplete =
	ast.visit.create_visitor() :: ast.Visitor<AnalysisInputState>

function autocomplete.visit_var_root(state, node)
	if span_cursor(state, node.span) ~= "within" then return end
	local replace_span = node.span
	local suggestions: { Suggestion } = {}
	local additional_info

	if node.kind == "global" then
		for global in state.globals do
			if node.token.text == global then
				local command_metadata =
					state.vm.global_metadata[node.token.text]

				additional_info = {
					name = command_metadata.name,
					description = command_metadata.description,

					type = "",
					optional = false,
				}
			end

			table.insert(suggestions, {
				text = global,
				display = global,
			})
		end
	elseif node.kind == "name" then
		for var in state.vars do
			table.insert(suggestions, {
				text = `${var}`,
				display = `${var}`,
			})
		end
	end

	state.result = {
		replace = replace_span,
		suggestions = suggestions,
		additional_info = additional_info,
	}
end

-- responsible for adding additional autocomplete information
function autocomplete.visit_block(state, node)
	if span_cursor(state, node.span) ~= "within" then return end

	for _, statement in node.body do
		if statement.kind ~= "assign" then continue end
		state.vars[statement.identifier.text] = true
	end
end

-- adds additional autocomplete information for variables
function autocomplete.visit_expr_lambda(state, node)
	if span_cursor(state, node.span) ~= "within" then return end
	if not node.body.block or not node.body.block.value then return end
	if not node.body.arguments then return end
	if span_cursor(state, node.body.block.value.span) ~= "within" then
		return
	end

	for _, argument in node.body.arguments.value do
		local token = argument.value
		if not token then continue end
		state.vars[token.text] = true
	end
end

function autocomplete.visit_command(state, node)
	if span_cursor(state, node.span) ~= "within" then return end
	if span_cursor(state, node.var.span) ~= "after" then return end
	local root = node.var.root
	if #node.var.suffixes > 0 then return end
	local command_metadata
	local command_name

	if root.kind == "global" then
		command_metadata = state.vm.global_metadata[root.token.text]
		command_name = root.token.text
	end

	if command_metadata == nil then return end

	local acceptable_overloads: { Overload } =
		table.clone(command_metadata.overloads) :: any
	local last_acceptable_overloads: { Overload } =
		table.clone(command_metadata.overloads) :: any
	local current_argument_idx = 1
	local replace_span = vector.create(node.span.y, node.span.y)

	for idx, argument in node.arguments do
		if span_cursor(state, argument.span) == "before" then break end
		current_argument_idx = idx
		replace_span = argument.span

		-- evaluate expression to an limited extent
		local result = evaluate_expression(argument)
		-- evaluate argument
		for i = #acceptable_overloads, 1, -1 do
			local overload = acceptable_overloads[i]
			local arg_b = overload.arguments[idx]
			if not arg_b then continue end
			if arg_b.kind ~= "literal" then continue end
			if not arg_b then table.remove(acceptable_overloads, i) end
			-- determine if overload matches
			if result == null then continue end
			if arg_b.optional and result == nil then continue end
			if arg_b.value ~= result then
				table.remove(acceptable_overloads, i)
			end
		end

		if #acceptable_overloads > 0 then
			last_acceptable_overloads = acceptable_overloads
			acceptable_overloads = table.clone(acceptable_overloads)
		end
	end

	local last_argument = node.arguments[#node.arguments]

	if last_argument and span_cursor(state, last_argument.span) == "after" then
		current_argument_idx += 1
		replace_span = vector.create(replace_span.y + 1, replace_span.y + 1, 0)
	end

	if #acceptable_overloads == 0 then
		table.insert(state.issues, {
			why = `no overloads match command "{command_name}"`,
			span = node.span,
		})
		acceptable_overloads = last_acceptable_overloads
	end

	local suggestions: { Suggestion } = {}
	local argument_data: AnalysisArgument?
	local additional_data
	local map_already_seen_text = {}

	for _, overload: Overload in acceptable_overloads do
		local argument: AnalysisArgument =
			overload.arguments[current_argument_idx]
		argument_data = argument

		additional_data = if argument
				and argument_data.kind == "argument"
			then {
				name = argument_data.name,
				description = argument_data.description,
				type = argument_data.type,
				optional = argument_data.optional,
			}
			elseif argument and argument_data.kind == "literal" then {
				name = argument_data.name,
				description = argument_data.description,
				type = "literal",
				optional = argument_data.optional,
			}
			else nil

		if argument and argument.kind == "literal" then
			table.insert(suggestions, {
				text = argument.value,
				display = tostring(argument.value),
			})
		elseif argument then
			local value =
				string.sub(state.input, replace_span.x + 1, replace_span.y + 1)
			local received_suggestions = argument.suggestions
					and argument.suggestions(value)
				or {}

			for _, suggestion in received_suggestions do
				local key = `{suggestion.text}:{suggestion.display}`
				if map_already_seen_text[key] then continue end

				table.insert(suggestions, suggestion)
				map_already_seen_text[key] = true
			end
		end
	end

	assert(command_metadata) -- ???

	state.result = {
		replace = replace_span,
		suggestions = suggestions,
		additional_info = additional_data,
	}
end

-- it's quick to go to command, so we want to make it suggest other options like while, for, etc
function autocomplete.visit_stat_command_end(state, node)
	if not state.result then return end
	if span_cursor(state, node.var.root.span) ~= "within" then return end

	table.insert(state.result.suggestions, {
		text = "for",
		display = "for",
	})
	table.insert(state.result.suggestions, {
		text = "while",
		display = "while",
	})
end

return function(
	language_vm: LanguageVm,
	input: string,
	cursor: number
): AnalysisResult
	local _, node: ast.Output = pcall(ast.parse, (buffer.fromstring(input)))

	if not node.result then
		return {
			suggestions = {},
			replace = vector.zero,
			issues = node.issues,
		}
	end

	-- we create a mutable copy of the vm, where vars can be written to.
	-- this is to make improved autocomplete easy, without actually affecting the state.

	local input: AnalysisInputState = {
		vars = table.clone(language_vm.state.scope.vars),
		globals = table.clone(language_vm.state.globals),

		cursor = cursor,
		input = input,
		vm = language_vm,
		issues = node.issues,
	}

	ast.visit.visit_ast(autocomplete, input, node.result)

	if input.result and input.result.suggestions then
		for idx, suggestion in input.result.suggestions do
			(suggestion :: any).text = wrap_if_necessary(suggestion.text)
		end
	end

	return {
		replace = input.result and input.result.replace or vector.zero,
		suggestions = input.result and input.result.suggestions or {},
		additional_info = input.result and input.result.additional_info,

		issues = input.issues,
	}
end
