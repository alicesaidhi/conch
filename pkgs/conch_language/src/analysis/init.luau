local ast = require "./ast"
local treewalker = require "./treewalker"

export type Metadata = {
	read name: string,
	read description: string,
}
export type LanguageVm = {
	global_metadata: { [string]: Type },
	vars_metadata: { [string]: Type },

	state: treewalker.ExecutionState,
}
export type TypeAnalysisInfo = {
	remove: (TypeAnalysisInfo) -> (),
}

-- a value that can be evaluated by a basic treewalker
export type SimpleValue = | number | string | boolean

export type Suggestion = {
	read kind: "expression" | "assign"?,
	read replace: vector?,
	read text: string,
	read display: string,
	read metadata: Metadata?,
}

--[=[
A literal type matches only the exact value
]=]
export type LiteralType = {
	read kind: "literal",
	read value: string | boolean | number | nil,
}

--[=[
External; this is a strange type that does not match any existing type.
]=]
export type StrangeType = {
	read kind: "strange",

	read type: string,
	read id: string,
	read convert: ((unknown) -> unknown)?,

	read suggestions: Type | ((string) -> { Suggestion })?,
	read match: Type | ((unknown) -> boolean)?,
	read exact_match: Type | ((unknown) -> boolean)?,
}

--[=[
An union of types
]=]
export type UnionType = {
	read kind: "union",
	read fields: { Type },
}

--[=[
An intersection of types
]=]
export type IntersectionType = {
	read kind: "intersection",
	read fields: { Type },
}

export type TableType = {
	read kind: "table",

	read fields_metadata: {
		[LiteralType]: {
			read description: string?,
		},
	}?,

	read fields: { [LiteralType]: Type }?,

	read indexer: Type?,
	read value: Type?,
}

export type FunctionType = {
	read kind: "function",

	read argument_names: { string },
}

export type CommandArgument = {
	read kind: "argument",

	read name: string,
	read description: string,

	read type: Type?,
	read varargs: boolean,
}

export type CommandType = {
	read kind: "command",

	read name: string,
	read description: string?,

	read arguments: { CommandArgument },
}

export type Type =
	| LiteralType
	| TableType
	| StrangeType
	| FunctionType
	| CommandType
	| IntersectionType
	| UnionType

export type Result = {
	replace: vector,
	suggestions: { Suggestion },
	issues: { ast.Issue },
	additional_info: {
		name: string,
		description: string?,
		type: string,
	}?,
}

export type InputState = {
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
			type: string,
		}?,
	}?,
	issues: { ast.Issue },
}

--[=[
Communicates if the cursor is either after or before the node
]=]
local function span_cursor(
	state: InputState,
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
				if not code or code > 255 then return value end
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

local function wrap_if_necessary(input: Suggestion)
	if input.kind == "expression" then
		return input.text
	elseif input.kind == "assign" and is_identifier(input.text) then
		return `{input.text} =`
	elseif input.kind == "assign" then
		return `[{string.format("%q", input.text)}] =`
	elseif is_identifier(input.text) then
		return input.text
	else
		return string.format("%q", input.text)
	end
end

local function evaluate_expression(
	node: ast.Expression | ast.ExpressionCommand?
): ...unknown
	if not node then
		return nil
	elseif node.kind == "boolean" then
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
	elseif node.kind == "table" then
		local t = {}

		local idx = 1
		for _, element in node.values.value do
			local item = element.value

			if item.kind == "expression_key" then
				local key = evaluate_expression(item.key and item.key.value)
				local value = evaluate_expression(item.value)

				if key then t[key] = value end
			elseif item.kind == "name_key" then
				local key = item.name.text
				local value = evaluate_expression(item.value)

				t[key] = value
			elseif item.kind == "nokey" then
				local value = evaluate_expression(item.value)

				t[idx] = value
				idx += 1
			end
		end

		return t
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

local autocomplete = ast.visit.create_visitor() :: ast.Visitor<InputState>

local function get_metadata_for(node: Type): Metadata?
	if node.kind == "intersection" then
		return get_metadata_for(node.fields[1])
	elseif node.kind == "union" then
		return get_metadata_for(node.fields[1])
	elseif node.kind == "command" then
		return {
			name = node.name,
			description = node.description or "",
		}
	else
		return nil
	end
end

function autocomplete.visit_var_root(state, node)
	if span_cursor(state, node.span) ~= "within" then return end
	local replace_span = node.span
	local suggestions: { Suggestion } = {}

	if node.kind == "global" then
		for global in state.globals do
			table.insert(suggestions, {
				kind = "expression" :: "expression",
				text = global,
				display = global,
				metadata = get_metadata_for(state.vm.global_metadata[global]),
			})
		end
	elseif node.kind == "name" then
		for var in state.vars do
			table.insert(suggestions, {
				kind = "expression" :: "expression",
				text = `${var}`,
				display = `${var}`,
				metadata = nil,
			})
		end
	end

	state.result = {
		replace = replace_span,
		suggestions = suggestions,
	}
end

-- responsible for adding additional autocomplete information
function autocomplete.visit_block(state, node)
	if span_cursor(state, node.span) ~= "within" then return end

	for _, statement in node.body do
		if statement.kind ~= "assign" then continue end
		state.vars[statement.identifier.text] = evaluate_expression(
			statement.value
		) or newproxy()
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

local function get_focused_argument(
	state: InputState,
	node: ast.Command
): number
	local current_command_argument = 1

	-- obtains the current focused argument
	for idx, argument in node.arguments do
		if span_cursor(state, argument.span) == "within" then
			current_command_argument = idx
			break
		elseif span_cursor(state, argument.span) == "after" then
			current_command_argument = idx + 1
		end
	end

	return current_command_argument
end

local function from_fields_matching_literal(
	type: TableType,
	value: unknown
): LiteralType?
	if type.fields == nil then return nil end
	for literal in type.fields do
		if literal.value == value then return literal end
	end
	return nil
end

local function from_description_match_literal(
	type: TableType,
	value: unknown
): LiteralType?
	if type.fields_metadata == nil then return nil end
	for literal in type.fields_metadata do
		if literal.value == value then return literal end
	end
	return nil
end

local function get_type_name(type: Type?)
	if not type then
		return "unknown"
	elseif type.kind == "literal" then
		return `{type.value}`
	elseif type.kind == "strange" then
		return type.type
	else
		return type.kind
	end
end

-- using an evaluated value, check if it matches the given type
local function match_eval_value(
	value: unknown,
	type: Type,
	exact: boolean?
): Type?
	if type.kind == "literal" then
		return if value == type.value then type else nil
	elseif type.kind == "command" or type.kind == "function" then
		return if typeof(value) == "function" then type else nil
	elseif type.kind == "strange" then
		local match_fn = if exact
			then type.exact_match or type.match
			else type.match

		if match_fn then
			if typeof(match_fn) == "table" then
				return if match_eval_value(value, match_fn, exact)
					then type
					else nil
			else
				return if match_fn(value) then type else nil
			end
		else
			return type
		end
	elseif type.kind == "intersection" then
		for _, field in type.fields do
			if not match_eval_value(value, field, exact) then return nil end
		end

		return type
	elseif type.kind == "union" then
		local matching = {}

		for _, field in type.fields do
			if match_eval_value(value, field, exact) then
				table.insert(matching, type)
			end
		end

		if #matching > 0 then
			return {
				kind = "union",
				fields = matching,
			}
		end

		return nil
	elseif type.kind == "table" then
		local map_keys = {}

		if type.fields then
			for type_key, type_value in type.fields do
				local ok, result = pcall(rawget, value, type_key.value :: any)
				if not ok then return nil end
				if not match_eval_value(result, type_value, exact) then
					return nil
				end
				if type_key.value then map_keys[type_key.value] = value end
			end
		end

		-- check if indexer and such matches
		if typeof(value) == "table" and (type.indexer or type.value) then
			for key, value in pairs(value) do
				local mapped_type = map_keys[key :: any]
				if mapped_type then continue end -- mapped types already pass; if they don't then they wouldve exited early.
				if
					type.indexer
					and not match_eval_value(key, type.indexer, exact)
				then
					return nil
				end
				if
					type.value
					and not match_eval_value(value, type.value, exact)
				then
					return nil
				end
			end
		end

		return type
	end

	return type
end

-- using a value which has not been evaluated, matches the given type.
local function match(
	state: InputState,
	node: ast.Expression | ast.ExpressionCommand?,
	type: Type,
	exact: boolean?
): Type?
	if not node then
		return nil
	elseif node.kind == "var" then
		local root

		if node.root.kind == "global" then
			root = state.globals[node.root.token.text]
		elseif node.root.kind == "name" and node.root.name then
			root = state.vars[node.root.name.text]
		elseif node.root.kind == "paren" and node.root.node.value then
			root = evaluate_expression(node.root.node.value)
		end

		if not root then return nil end

		local var = root

		for _, suffix in node.suffixes do
			if suffix.kind == "expression_index" then
				local key = evaluate_expression(suffix.node.value)
				local ok, result = pcall(rawget, var, key :: any)
				if not ok then return nil end
				var = result
			elseif suffix.kind == "name_index" and suffix.name then
				local key = suffix.name.text
				local ok, result = pcall(rawget, var, key :: any)
				if not ok then return nil end
				var = result
			end
		end

		return match_eval_value(var, type, exact)
	elseif type.kind == "command" then
		return if node.kind == "command" then type else nil
	elseif type.kind == "function" then
		return if node.kind == "lambda" then type else nil
	elseif type.kind == "intersection" then
		for _, field in type.fields do
			if not match(state, node, field, exact) then return nil end
		end

		return type
	elseif type.kind == "union" then
		local matching = {}

		for _, field in type.fields do
			if match(state, node, field, exact) then
				table.insert(matching, field)
			end
		end

		if #matching > 0 then
			return {
				kind = "union",
				fields = matching,
			}
		end

		return nil
	elseif type.kind == "strange" and typeof(type.match) == "table" then
		return if match(state, node, type.match, exact) then type else nil
	elseif
		type.kind == "strange"
		or type.kind == "literal"
		or type.kind == "table"
	then
		return match_eval_value(evaluate_expression(node), type, exact)
	end

	return nil
end

--- assumes that state.result.suggestions exist
local function fill_suggestions(
	state: InputState,
	node: ast.Expression | ast.ExpressionCommand?,
	type: Type
)
	assert(state.result, "result does not exist")

	if type.kind == "literal" then
		table.insert(state.result.suggestions, {
			kind = "expression" :: "expression",
			metadata = nil,
			text = tostring(type.value),
			display = tostring(type.value),
		})
	elseif type.kind == "strange" then
		if typeof(type.suggestions) == "function" then
			local value = node
				and string.sub(state.input, node.span.x + 1, node.span.y + 1)
			local suggestions = type.suggestions(value or "")

			table.move(
				suggestions,
				1,
				#suggestions,
				#state.result.suggestions + 1,
				state.result.suggestions
			)
		elseif typeof(type.suggestions) == "table" then
			fill_suggestions(state, node, type.suggestions)
		end
	elseif type.kind == "table" then
		if not node then return end
		if node.kind ~= "table" then return end

		local elements = node.values.value
		local item_idx = 1 -- refers to item idx in node, not type
		local total_nokeys = 0 -- amount of no keys that have been seen

		for idx, item in elements do
			if item.value.kind == "nokey" then
				total_nokeys += 1
			end

			if span_cursor(state, item.span) == "before" then
				item_idx = idx + 1
			elseif span_cursor(state, item.span) == "within" then
				item_idx = idx
				break
			elseif span_cursor(state, item.span) == "after" then
				item_idx = idx
			end
		end

		local item = elements[item_idx]

		-- no node that matched an index was found, so resort to a number key.
		if not item then
			-- +1 because we start from 0 and no matching elemenmt was found
			local field = from_fields_matching_literal(type, total_nokeys + 1)

			if field == nil or type.fields == nil then return end
			fill_suggestions(state, item, type.fields[field])
			return
		end

		-- node that matches item was found!
		local element = item.value
		local key_value
		local is_editing_key = false
		local is_editing_value = false
		local keyexpression

		if element.kind == "name_key" then
			key_value = element.name.text
			is_editing_key = span_cursor(state, element.name.span) == "within"
			is_editing_value = span_cursor(state, element.equals.span)
					== "within"
				or span_cursor(state, element.equals.span) == "after"

			state.result.replace = element.value and element.value.span
				or vector.create(state.cursor, state.cursor)
		elseif element.kind == "expression_key" and element.key then
			key_value = evaluate_expression(element.key.value)
			local span = vector.create(
				element.key.left.span.x,
				element.key.right and element.key.right.span.y
					or element.key.value and element.key.value.span.y
					or element.key.left.span.x,
				0
			)

			is_editing_key = span_cursor(state, span) == "within"
			is_editing_value = element.equals
				and span_cursor(state, element.equals.span) == "after"
			keyexpression = if element.key.value
					and element.key.value.kind ~= "error"
				then element.key.value
				else nil
		elseif element.kind == "nokey" then
			key_value = total_nokeys

			state.result.replace = element.span
			is_editing_key = true
			is_editing_value = if type.indexer
				then match_eval_value(key_value, type.indexer)
				else false
		end

		-- when editing key, make sure to fill out suggestions from the table keys / indexer
		if is_editing_key then
			state.result.replace = if element.kind == "expression_key"
					and element.key
				then element.key
						and element.key.value
						and element.key.value.span
					or vector.create(
						element.key.left.span.x,
						element.key.left.span.x
					)
				elseif element.kind == "name_key" then element.name.span
				elseif element.kind == "nokey" then element.span
				else state.result.replace

			if type.fields then
				for key in type.fields do
					table.insert(state.result.suggestions, {
						kind = "assign",
						metadata = nil,
						text = key.value,
						display = key.value,
					})
				end
			end

			if type.indexer then
				fill_suggestions(state, keyexpression :: any, type.indexer)
			end
		end

		local element_type_literal =
			from_fields_matching_literal(type, key_value)
		local element_description_literal =
			from_description_match_literal(type, key_value)
		local element_type = element_type_literal
			and type.fields
			and type.fields[element_type_literal]
		local element_description = element_description_literal
			and type.fields_metadata
			and type.fields_metadata[element_description_literal]

		if element_description then
			state.result.additional_info = {
				name = `{key_value}`,
				description = element_description.description,
				type = get_type_name(element_type),
			}
		end

		if not element_type and type.indexer and type.value then
			if match_eval_value(key_value, type.indexer) then
				element_type = type.value
			end
		end

		if is_editing_value and element_type then
			state.result.replace = if element.kind == "expression_key"
					and element.value
				then element.value.span
				elseif
					element.kind == "name_key" and element.value
				then element.value.span
				elseif element.kind == "nokey" then element.span
				else state.result.replace

			fill_suggestions(state, element.value, element_type)
		end
	elseif type.kind == "union" then
		local possible_types = match(state, node, type)
		if possible_types == nil then possible_types = type end
		assert(possible_types and possible_types.kind == "union", "bad value?")

		for _, field in possible_types.fields do
			assert(field ~= type)

			fill_suggestions(state, node, field)
		end
	elseif type.kind == "intersection" then
		for _, field in type.fields do
			fill_suggestions(state, node, field)
		end
	end
end

local function complete_function(
	state: InputState,
	node: ast.Command,
	type: FunctionType
)
	local current_argument_idx = get_focused_argument(state, node)
	local arg_node = node.arguments[current_argument_idx]
	local arg_type = type.argument_names[current_argument_idx]

	if not arg_type then return end

	state.result = {
		replace = arg_node.span,
		suggestions = {},
		additional_info = {
			name = arg_type,
			type = "unknown",
		},
	}
end

local function complete_command(
	state: InputState,
	node: ast.Command,
	type: CommandType
)
	local current_argument_idx = get_focused_argument(state, node)
	local arg_node = node.arguments[current_argument_idx]
	local arg_type = type.arguments[current_argument_idx]

	-- in case of varargs, set it to the varargs node.
	if
		current_argument_idx > #type.arguments
		and #type.arguments ~= 0
		and type.arguments[#type.arguments].varargs
	then
		arg_type = type.arguments[#type.arguments]
	end

	if not arg_type then return end

	local suggestions: { Suggestion } = state.result
			and state.result.suggestions
		or {}

	state.result = {
		replace = arg_node and arg_node.span
			or vector.create(state.cursor, state.cursor, 0),
		suggestions = suggestions,
		additional_info = {
			name = arg_type.name,
			description = arg_type.description,
			type = if arg_type.type then arg_type.type.kind else "unknown",
		},
	}

	if arg_type.type then fill_suggestions(state, arg_node, arg_type.type) end
end

-- given nested intersection, returns an array with no intersections
local function normalize_intersections(output: { Type }, type: IntersectionType)
	for _, field in type.fields do
		if field.kind == "intersection" then
			normalize_intersections(output, field)
		else
			table.insert(output, field)
		end
	end

	return output
end

local function swap_pop(t: { [number]: any }, idx: number)
	t[idx] = t[#t]
	t[#t] = nil
end

-- given an intersection of commands, checks which command matches
-- ignores any types that are not a command
local function choose_command(
	state: InputState,
	node: ast.Command,
	type: IntersectionType
)
	local original = {}
	local possible_commands: { CommandType } = {}

	for idx, value in normalize_intersections({}, type) do
		if value.kind ~= "command" then continue end
		table.insert(possible_commands, value)
		table.insert(original, value)
	end

	for i = #possible_commands, 1, -1 do
		local cmd = possible_commands[i]
		local last_argument = cmd.arguments[#cmd.arguments]
		local is_vararg = if last_argument then last_argument.varargs else false

		if not is_vararg and #cmd.arguments < #node.arguments then
			swap_pop(possible_commands, i)
			continue
		end

		local bad = false

		for j, arg in node.arguments do
			local arg_type = cmd.arguments[j]

			if #cmd.arguments < j and is_vararg then
				arg_type = last_argument
			end

			if
				not arg_type
				or arg_type.type
					and not match(state, arg, arg_type.type, true)
			then
				bad = true
				break
			end
		end

		if bad then
			swap_pop(possible_commands, i)
			continue
		end
	end

	if #possible_commands == 0 then
		table.insert(
			state.issues,
			{ why = "no command matches the given type", span = node.span }
		)
		possible_commands = original
	end

	for _, command in possible_commands do
		complete_command(state, node, command)
	end
end

function autocomplete.visit_command(state, node)
	if span_cursor(state, node.span) ~= "within" then return end
	if span_cursor(state, node.var.span) ~= "after" then return end
	local root = node.var.root
	if #node.var.suffixes > 0 then return end
	local command_type: Type
	local command_name: string

	if root.kind == "global" then
		command_name = root.token.text
		command_type = state.vm.global_metadata[command_name]
	end

	if command_type == nil then return end

	-- commands support either a function type, command type or intersection type.
	if command_type.kind == "function" then
		complete_function(state, node, command_type)
	elseif command_type.kind == "command" then
		complete_command(state, node, command_type)
	elseif command_type.kind == "intersection" then
		choose_command(state, node, command_type)
	else
		table.insert(state.issues, {
			why = `(this is a implementation issue) expected command type, got {command_type.kind}`,
			span = node.span,
		})
	end
end

-- it's quick to go to command, so we want to make it suggest other options like while, for, etc
function autocomplete.visit_stat_command_end(state, node)
	if not state.result then return end
	if span_cursor(state, node.var.root.span) ~= "within" then return end

	table.insert(state.result.suggestions, {
		kind = nil,
		metadata = nil,
		text = "for",
		display = "for",
	})
	table.insert(state.result.suggestions, {
		kind = nil,
		metadata = nil,
		text = "while",
		display = "while",
	})
end

return {
	analyze = function(
		language_vm: LanguageVm,
		input: string,
		cursor: number
	): Result
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

		local state: InputState = {
			vars = table.clone(language_vm.state.scope.vars),
			globals = table.clone(language_vm.state.globals),

			cursor = cursor,
			input = input,
			vm = language_vm,
			issues = node.issues,
		}

		ast.visit.visit_ast(autocomplete, state, node.result)

		--todo: suggestion deduplication
		if state.result and state.result.suggestions then
			local suggestions = {}
			local deduplicate = {}

			for idx, suggestion in state.result.suggestions do
				(suggestion :: any).text = wrap_if_necessary(suggestion)
				deduplicate[suggestion.display] = suggestion
			end

			for _, suggestion in deduplicate do
				table.insert(suggestions, suggestion)
			end

			state.result.suggestions = suggestions
		end

		return {
			replace = state.result and state.result.replace or vector.zero,
			suggestions = state.result and state.result.suggestions or {},
			additional_info = state.result and state.result.additional_info,

			issues = state.issues,
		}
	end,

	matches_type = match_eval_value,
}
