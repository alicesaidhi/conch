local ast = require "./optional_ast"
local types = require "../roblox_packages/types"

type LogKind = types.LogKind
type AnalysisSuggestion = types.AnalysisSuggestion
type AnalysisInformation = types.AnalysisInformation

type AnalysisCommandArgument = types.AnalysisCommandArgument
type AnalysisCommand = types.AnalysisCommand

export type FeedAnalysisOptions = {
	code: string,
	where: number,
	ast: ast.Block,

	variables: { [string]: any },
	commands: { AnalysisCommand },
}

type Node =
	| ast.Command
	| ast.Expression_Boolean
	| ast.Expression_Evaluate
	| ast.Expression_Identifier
	| ast.Expression_Lambda
	| ast.Expression_Lambda
	| ast.Expression_Nil
	| ast.Expression_Number
	| ast.Expression_String
	| ast.Expression_Table
	| ast.Expression_Var

local function generate_analysis_info(
	options: FeedAnalysisOptions
): AnalysisInformation
	-- return {
	--     at = options.where,
	--     text = "",
	--     logs = {},
	--     analyzing = {
	--         kind = "command",
	--         name = "string",
	--         description = "string | false",
	--     },
	--     suggestions = { {
	--         name = "example-suggestion",

	--         replace = vector.create(0, 5, 0),
	--         with = "mraow"
	--     } }
	-- }

	local LOGS = {}
	local where = options.where

	local function LOG(kind: LogKind, text: string)
		table.insert(LOGS, { kind = kind, text = text })
	end

	local function get_span(from: ast.Surrounded<
		{ span: vector }?,
		unknown?,
		unknown?
	>): vector
		local x, y
		if from.left then
			x = from.left.span.x
		elseif from.value then
			x = from.value.span.x
		else
			x = from.right.span.x
		end

		if from.right then
			y = from.right.span.y
		elseif from.value then
			y = from.value.span.y
		else
			y = from.left.span.y
		end

		return vector.create(x, y, 0)
	end

	local function get_text_token<T>(token: ast.Token<T>)
		local span = token.span
		local finish = where - span.x
		return string.sub(token.text, 1, finish)
	end

	local function position_relative(
		span: vector
	): "before" | "after" | "within"
		return if where >= span.x and where <= span.y
			then "within"
			elseif where < span.x then "before"
			else "after"
	end

	local processing = ast(options.code)
	local block

	local function no_suggestions(text: string)
		return {
			at = where,
			text = text,
			logs = LOGS,
			suggestions = {},
			ast = processing
				and processing.status == "finished"
				and processing.value,
		}
	end

	if processing.status == "error" then
		LOG("error", processing.why)
		return no_suggestions ""
	else
		block = processing.value
	end

	local process_if_stat
	local process_assignment
	local process_for
	local process_while
	local process_block
	local process_command
	local process_function
	local process_return
	local process_expression
	local process_expression_or_command
	-- local parse_if
	-- local parse_expression

	function process_command(
		stat: ast.Command,
		expressions_too: boolean?
	): AnalysisInformation
		local pos = position_relative(stat.prefix.span)
		if pos == "within" then
			return process_variable(stat.prefix, expressions_too)
		elseif pos == "after" then
			-- obtain the prefix
			local var = stat.prefix
			local prefix = var.prefix
			local command_info: AnalysisCommand

			if prefix.kind == "global" then
				for index, command in options.commands do
					if command.name ~= prefix.token.text then continue end
					command_info = command
					break
				end
			end

			if not command_info then return no_suggestions "" end

			local index = 1
			local span =
				vector.create(stat.prefix.span.y + 1, stat.prefix.span.y + 1)

			local arg_analyzed: AnalysisInformation = no_suggestions "" :: any
			for i, argument in stat.arguments do
				local relative_position = position_relative(argument.span)
				if relative_position == "within" then
					span = argument.span
					arg_analyzed =
						process_expression(argument) :: AnalysisInformation
					break
				elseif relative_position == "after" then
					span = vector.create(
						argument.span.y + 1,
						argument.span.y + 1,
						0
					)
					index += 1
				elseif relative_position == "before" then
					break
				end
			end

			local arg_info: (types.AnalysisCommandArgument | types.AnalysisCommandVariadic)? =
				command_info.arguments[index]

			if index > #command_info.arguments then
				arg_info = command_info.arguments[#command_info.arguments]

				if arg_info and arg_info.kind ~= "variadic" then
					if arg_analyzed.text ~= arg_analyzed.text:match "%s*" then
						LOG("warn", `no argument #{index}`)
					end
					return arg_analyzed
				end
			end

			if arg_info and arg_info.suggestion_generator then
				local generator = arg_info.suggestion_generator
				local text = arg_analyzed.text
				local suggestions = generator(text)

				for idx, name in suggestions do
					suggestions[idx] = {
						name = name,
						type = text,

						replace = span,
						with = name,
					}
				end

				table.move(
					suggestions,
					1,
					#suggestions,
					#arg_analyzed.suggestions + 1,
					arg_analyzed.suggestions
				)
			end

			arg_analyzed = arg_analyzed
			arg_analyzed.analyzing = arg_analyzed.analyzing or arg_info
			return arg_analyzed
		end

		return no_suggestions ""
	end

	function process_if(stat: ast.If)
		local conditional = stat.condition
		local relative = position_relative(get_span(conditional))

		if relative == "within" then
			return process_expression_or_command(conditional.value)
		end

		if stat.block then return process_block(stat.block.value) end
	end

	function parse_if_stat(stat: ast.Stat_If)
		for _, condition in stat.ifs do
			local pos = position_relative(condition.span)
			if pos == "before" then continue end
			if pos == "after" then break end
			return process_if(condition)
		end

		local fallback = stat.fallback
		if fallback and position_relative(get_span(fallback)) == "within" then
			return process_block(fallback.value)
		end
	end

	function process_function(expr: ast.FunctionBody)
		if not expr.block then return no_suggestions "" end
		if position_relative(get_span(expr.block)) == "within" then
			return process_block(expr.block.value)
		else
			return no_suggestions ""
		end
	end

	function process_var_prefix(var: ast.Var, expressions_too: boolean)
		local prefix = var.prefix
		local analyzing, text
		local suggestions: { AnalysisSuggestion } = {}

		if prefix.kind == "global" then
			text = get_text_token(prefix.token)

			if expressions_too and string.sub("true", 1, #text) == text then
				table.insert(suggestions, {
					name = "true",
					type = "true",

					replace = var.span,
					with = "true",
				})
			end

			if expressions_too and string.sub("false", 1, #text) == text then
				table.insert(suggestions, {
					name = "false",
					type = "false",

					replace = var.span,
					with = "false",
				})
			end

			if expressions_too and string.sub("nil", 1, #text) == text then
				table.insert(suggestions, {
					name = "nil",
					type = "nil",

					replace = var.span,
					with = "nil",
				})
			end

			if not expressions_too and string.sub("for", 1, #text) == text then
				table.insert(suggestions, {
					name = "for",
					type = "for",

					replace = var.span,
					with = "for",
				})
			end

			if not expressions_too and string.sub("if", 1, #text) == text then
				table.insert(suggestions, {
					name = "if",
					type = "if",

					replace = var.span,
					with = "if",
				})
			end

			if
				not expressions_too
				and string.sub("while", 1, #text) == text
			then
				table.insert(suggestions, {
					name = "while",
					type = "while",

					replace = var.span,
					with = "while",
				})
			end

			if not expressions_too and string.sub("else", 1, #text) == text then
				table.insert(suggestions, {
					name = "else",
					type = "else",

					replace = var.span,
					with = "else",
				})
			end

			for index, command in options.commands do
				local text = string.lower(text)
				local name = string.lower(command.name)

				if string.sub(name, 1, #text) ~= text then continue end
				if #text == #command.name then analyzing = command end

				table.insert(suggestions, {
					name = command.name,
					description = command.description,
					type = "Command",

					replace = var.span,
					with = command.name,
				})
			end
		elseif prefix.kind == "name" then
			text = prefix.name and prefix.name.text or ""

			for key, value in options.variables do
				local text = string.lower(text)
				local name = string.lower(key)

				if string.sub(name, 1, #text) ~= text then continue end
				if #text == #key then
					analyzing = {
						kind = "argument",
						name = key,
						type = typeof(value),
					}
				end

				table.insert(suggestions, {
					name = key,
					type = typeof(value),
					replace = prefix.name and prefix.name.span
						or vector.create(prefix.span.x + 1, prefix.span.y),
					with = key,
				})
			end
		elseif prefix.kind == "paren" then
			if prefix.expr.value then
				return process_expression_or_command(prefix.expr.value)
			end
		end

		return {
			at = where,
			text = text,
			logs = LOGS,
			ast = processing.value,

			analyzing = analyzing,
			suggestions = suggestions,
		}
	end

	function process_variable(var: ast.Var, expressions_too: boolean)
		if position_relative(var.prefix.span) == "within" then
			return process_var_prefix(var, expressions_too)
		end

		if var.prefix.kind == "paren" then return no_suggestions "" end
		if var.prefix.kind == "global" then return no_suggestions "" end

		local prefix: ast.VarRoot_Name = var.prefix
		local key = prefix.name and prefix.name.text

		if not key then return no_suggestions "" end

		local value = options.variables[key]
		local span = vector.create(var.span.x, 0)
		local text

		if value == nil then
			LOG("warn", `no defined variable named "{key}"`)
			return no_suggestions(key)
		end

		for idx, suffix in var.suffixes do
			if
				type(value) ~= "table"
				and type(value) ~= "userdata"
				and type(value) ~= "vector"
			then
				LOG(
					"warn",
					`probably can't index "{key}" which is a "{typeof(value)}"`
				)
			end

			if position_relative(suffix.span) ~= "within" then
				if suffix.kind == "nameindex" then
					local key = suffix.name and suffix.name.text
					if not key then return no_suggestions(key) end
					value = value[key]
					text = key
				else
					return no_suggestions ""
				end
				continue
			end

			if suffix.kind == "nameindex" then
				local key = suffix.name and suffix.name.text
				if not key then return no_suggestions(key) end
				text = key
				span = suffix.name and suffix.name.span
					or vector.create(suffix.span.x + 1, suffix.span.x + 1)
			elseif suffix.kind == "exprindex" then
				return no_suggestions ""
			end

			break
		end

		local suggestions = {}
		local analyzing

		if value[text] then
			local v = value[text]
			analyzing = {
				kind = "argument",
				name = text,
				type = typeof(v),
			}
		end

		if type(value) == "table" then
			for key, value in value do
				local text = string.lower(text)
				local name = string.lower(key)

				if string.sub(name, 1, #text) ~= text then continue end

				table.insert(suggestions, {
					name = key,
					with = key,
					type = typeof(value),
					replace = span,
				})
			end
		end

		return {
			at = where,
			text = text,
			logs = LOGS,
			analyzing = analyzing,

			suggestions = suggestions,
		}
	end

	function process_expression(expr: ast.Expression)
		local expr = expr
		if expr.kind == "lambda" then
			return process_function(expr.body)
		elseif expr.kind == "evaluate" then
			if
				position_relative(get_span(expr.body)) == "within"
				and expr.body.value
			then
				return process_expression_or_command(expr.body.value)
			end
		elseif expr.kind == "vector" then
			for idx, value in expr.contents.value do
				if position_relative(value.span) ~= "before" then
					return process_expression(value)
				end
			end
		elseif expr.kind == "identifier" then
			return no_suggestions(expr.token.text)
		elseif expr.kind == "string" then
			return no_suggestions(string.sub(expr.token.text, 2, -2))
		elseif expr.kind == "number" then
			return no_suggestions(expr.token.text)
		elseif expr.kind == "var" then
			return process_variable(expr.var, true)
		end

		return no_suggestions ""
	end

	function process_return(stat: ast.Last_Return)
		for index, value in stat.values do
			if position_relative(value.span) == "before" then continue end
			return process_expression_or_command(value)
		end
		return no_suggestions ""
	end

	function process_expression_or_command(expr: ast.ExpressionOrCommand)
		if expr.kind == "command" then
			return process_command(expr, true)
		else
			return process_expression(expr)
		end
	end

	function process_assignment(assign: ast.Stat_Assign)
		if not assign.right then return no_suggestions "" end
		if position_relative(assign.operator.span) == "before" then
			return no_suggestions ""
		end
		return process_expression_or_command(assign.right)
	end

	function process_while(stat: ast.Stat_While)
		if position_relative(get_span(stat.expression)) == "within" then
			return process_expression_or_command(stat.expression.value, true)
		end

		local block = stat.block
		if block and position_relative(get_span(block)) == "within" then
			return process_block(block.value)
		end

		return no_suggestions ""
	end

	function parse_for(stat: ast.Stat_For)
		if
			stat.expression
			and position_relative(get_span(stat.expression)) == "within"
		then
			if stat.expression.value == nil then return no_suggestions "" end
			return process_expression(stat.expression.value)
		end

		if stat.call then return process_function(stat.call) end
	end

	function process_block(block: ast.Block)
		local statement
		for i, stat in block.body do
			statement = stat
			local pos = position_relative(stat.span)
			if pos == "before" or (pos == "after" and i < #block.body) then
				continue
			end

			if statement == nil then return no_suggestions "" end

			return if statement.kind == "if"
				then parse_if_stat(statement)
				elseif statement.kind == "assign" then process_assignment(
					statement
				)
				elseif statement.kind == "command" then process_command(
					statement
				)
				elseif statement.kind == "return" then process_return(
					statement
				) -- parse_return(statement)
				elseif statement.kind == "for" then parse_for(statement)
				elseif statement.kind == "while" then process_while(
					statement
				)
				else no_suggestions ""
		end

		return no_suggestions ""
	end

	return process_block(block)
end

return {
	generate_analysis_info = generate_analysis_info,
}
