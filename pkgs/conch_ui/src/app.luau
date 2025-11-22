--!nonstrict
local conch = require "../roblox_packages/conch"
local console_output = require "./components/ui/console_output"
local container = require "./components/core/container"
local executor = require "./components/ui/executor"
local language = require "../roblox_packages/language"
local levenshtein_distance = require "./levenshtein_distance"
local screen = require "./components/core/screen"
local state = require "./state"
local vide = require "../roblox_packages/vide"

local source = vide.source
local derive = vide.derive
local effect = vide.effect

local STARTUP_TEXT = `\z
conch-ui 0.4.0\tconch-language {language.version}\tconch {conch.version}`

local NEWLINE = buffer.create(1)
buffer.writeu8(NEWLINE, 0, string.byte "\n")

return function()
	local function output(value: conch.Log)
		if state.logs.at > 0 then state.logs:write(NEWLINE) end
		if value.kind == "error" then
			value.text = `\27[1;48;310mERR\27[0;38m {value.text}\27[0m`
		elseif value.kind == "warn" then
			value.text = `\27[1;43;310mWRN\27[0;33m {value.text}\27[0m`
		elseif value.kind == "info" then
			value.text = `\27[1;46;310mINF\27[0;36m {value.text}\27[0m`
		end

		state.logs:write(buffer.fromstring(value.text))
	end

	conch.console.output = output

	for _, s in string.split(STARTUP_TEXT, "\n") do
		output { kind = "normal", text = s }
	end

	output {
		kind = "warn",
		text = "If you got here accidentally, run the `close-ui` command to close this UI.",
	}

	conch.register("clear", {
		description = "Clears the console.",
		permissions = {},
		arguments = function() end,
		callback = function() state.logs {} end,
	})

	conch.register("close-ui", {
		description = "Close the CLI",
		permissions = {},
		arguments = function() end,
		callback = function()
			state.opened(false)
			state.focused(false)
		end,
	})

	local raw_text = source ""
	local working = source(false)
	local cursor_position = source(0)

	local analysis = source(conch.analyze("", 0))

	local deferred = false
	effect(function()
		raw_text()
		cursor_position()
		if deferred then return end
		deferred = true

		task.defer(function()
			deferred = false
			analysis(conch.analyze(raw_text(), cursor_position() - 1))
		end)
	end)

	local filtered_suggestions = derive(function()
		local analysis_result = analysis()
		local suggestions = analysis_result and analysis_result.suggestions
		if not suggestions then return {} end

		local filtered_suggestions = {}
		local input = string.lower(
			string.sub(
				raw_text(),
				analysis_result.replace.x + 1,
				cursor_position() - 1
			)
		)

		input = string.gsub(input, `"(.*)"`, "%1", 1)
		input = string.gsub(input, `'(.*)'`, "%1", 1)

		for _, suggestion in suggestions do
			if
				not string.find(
					suggestion.display,
					string.gsub(input, "^%s", ""),
					0,
					true
				)
			then
				continue
			end

			local score =
				levenshtein_distance(input, string.lower(suggestion.display))
			if score == -math.huge then continue end
			table.insert(
				filtered_suggestions,
				{ suggestion = suggestion, score = score }
			)
		end

		table.sort(
			filtered_suggestions,
			function(a, b) return a.score < b.score end
		)

		local new_suggestions = {}

		for idx, suggestion in filtered_suggestions do
			table.insert(new_suggestions, suggestion.suggestion)
		end

		return new_suggestions
	end)

	return screen {
		name = "Command Executor",
		display_order = 100_000,
		enabled = state.opened,

		container {
			ws = 1,
			hs = 1,

			flex = { justify = "fill", align = state.alignment },
			pad = { p = 12 },

			console_output {
				ws = 1,
				auto = "y",
				order = function()
					return if state.alignment() == "bottom" then 1 else -1
				end,

				errors = function()
					local issues = analysis().issues
					local texts = {}

					for _, issue in issues do
						table.insert(
							texts,
							`{issue.why} at {issue.span.x}:{issue.span.y}:{issue.span.z}`
						)
					end

					return texts
				end,
			},

			container {
				h = 4,
				order = function()
					return if state.alignment() == "bottom" then 2 else -2
				end,
			},

			executor {
				ws = 1,
				order = function()
					return if state.alignment() == "bottom" then 3 else -3
				end,

				working = working,
				filtered_suggestions = filtered_suggestions,
				analysis = analysis,
				update_cursor = cursor_position,

				update_text = raw_text,
				execute = function(text)
					working(true)
					local ok, err = pcall(conch.execute, text)
					working(false)
				end,
			},
		},
	}
end
