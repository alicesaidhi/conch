local TextService = game:GetService "TextService"
local UserInputService = game:GetService "UserInputService"

local background = require "./background"
local component = require "../../util/component"
local conch = require "../../../roblox_packages/conch"
local interval = require "../../util/interval"
local language = require "../../../roblox_packages/language"
local loading = require "../../util/loading"
local screen = require "../core/screen"
local state = require "../../state"
local suggestion = require "./suggestion"
local text = require "../core/text"
local textbox = require "../core/textbox"
local theme = require "../../theme"
local vide = require "../../../roblox_packages/vide"

local changed = vide.changed
local derive = vide.derive
local source = vide.source
local show = vide.show
local effect = vide.effect
local cleanup = vide.cleanup

local TOTAL_SUGGESTIONS = 10

local history_n = 0
local history = {}

return component(function(p: {
	working: () -> boolean,
	filtered_suggestions: () -> { language.Suggestion },
	analysis: () -> language.AnalysisResult,

	update_text: (string) -> (),
	update_cursor: (number) -> (),
	execute: () -> (),
})
	local show_suggestions_from = source(0)
	local absolute_position = source(Vector2.zero)

	local raw_text = source ""
	local selected_suggestion = source(1)
	effect(function() p.update_text(raw_text()) end)

	local cursor_position = source(0)
	local next_cursor_position: false | number = false

	effect(
		function()
			selected_suggestion(
				math.clamp(
					selected_suggestion(),
					1,
					math.max(1, #p.analysis().suggestions)
				)
			)
		end
	)

	local before_text = derive(
		function() return string.sub(raw_text(), 1, cursor_position() - 1) end
	)

	local suggestion_position = source(Vector2.zero)

	effect(function() p.update_cursor(cursor_position()) end)

	effect(function()
		local bounds = Instance.new "GetTextBoundsParams"
		bounds.Font = theme.font()
		bounds.RichText = false
		bounds.Size = 19
		bounds.Width = 100000

		local t = before_text()
		local total_newlines = 0
		local from = 1

		for n in string.gmatch(t, "\n()") do
			total_newlines += 1
			from = n
		end

		bounds.Text = string.rep("\n", total_newlines) .. string.sub(t, from)
		task.spawn(function()
			local s = TextService:GetTextBoundsAsync(bounds)
			if t ~= before_text() then return end
			suggestion_position(s)
		end)
	end)

	effect(function()
		local selected = selected_suggestion()
		local min, max =
			show_suggestions_from(),
			show_suggestions_from() + TOTAL_SUGGESTIONS - 1

		if selected > max then
			local delta = selected - max
			show_suggestions_from(show_suggestions_from() + delta)
		elseif selected < min then
			local delta = selected - min
			show_suggestions_from(show_suggestions_from() + delta)
		end
	end)

	local function autofill(text: string, span: vector, with: string)
		local before = string.sub(text, 1, span.x)
		local after = string.sub(text, span.y + 1, -1)

		task.defer(cursor_position, span.x + #with + 2)
		return before .. with .. " " .. after
	end

	cleanup(UserInputService.InputBegan:Connect(function(input)
		if not state.opened() then return end

		local analysis_result = p.analysis()

		if input.KeyCode == Enum.KeyCode.Down then
			if #analysis_result.suggestions == 0 then
				if history_n == 0 then history[history_n] = raw_text() end

				history_n = math.clamp(history_n - 1, 0, #history)
				raw_text(history[history_n] or "")
				cursor_position(#raw_text() + 1)
			else
				selected_suggestion(
					math.min(
						selected_suggestion() + 1,
						#analysis_result.suggestions
					)
				)
			end
		elseif input.KeyCode == Enum.KeyCode.Up then
			if #analysis_result.suggestions == 0 then
				if history_n == 0 then history[history_n] = raw_text() end

				history_n = math.clamp(history_n + 1, 0, #history)
				raw_text(history[history_n] or "")
				cursor_position(#raw_text() + 1)
			else
				selected_suggestion(math.max(1, selected_suggestion() - 1))
			end
		elseif
			input.KeyCode == Enum.KeyCode.C
			and input:IsModifierKeyDown(Enum.ModifierKey.Ctrl)
		then
			conch.cancel()
		elseif input.KeyCode == Enum.KeyCode.Return then
			state.focused(true)
		end
	end))

	return background {
		name = "Executor",

		ws = 1,
		h = 20,
		auto = "y",
		corner = 4,

		pad = { p = 8 },
		flex = { justify = "left" },

		changed("AbsolutePosition", absolute_position),

		show(p.analysis, function()
			return screen {
				name = "Suggestion",
				display_order = 1e9,

				suggestion {
					x = function()
						local t = string.split(before_text(), "\n")
						return 9 * #t[#t] + 32
					end,
					y = function()
						return suggestion_position().Y + absolute_position().Y
					end,
					selected = selected_suggestion,
					show_suggestions_from = show_suggestions_from,

					suggestions = p.filtered_suggestions,
					result = p.analysis,
				},
			}
		end),

		show(p.working, function()
			local total = 0
			local duration = interval(0, function(t: number)
				total += t
				return total
			end)

			return text {
				h = 20,

				size = 18,
				text = function()
					return `{loading()} - {string.format("%0.3f", duration())}s - Ctrl-C to cancel`
				end,
			}
		end, function()
			return textbox {
				ws = 1,
				auto = "",
				h = 20,

				text = raw_text,
				update_text = function(text: string)
					local position = next_cursor_position or cursor_position()
					local at = string.sub(text, position - 1, position - 1)
					local suggestions = p.filtered_suggestions()
					local selected_suggestion =
						suggestions[selected_suggestion()]

					if at == "\t" and selected_suggestion then
						text = autofill(
							raw_text(),
							p.analysis().replace,
							selected_suggestion.text
						)
					end

					raw_text(text)
				end,
				placeholder = "Enter your command",
				size = 18,
				xalign = "left",
				multiline = interval(
					0,
					function()
						return #p.analysis().issues > 0
							or UserInputService:IsKeyDown(
								Enum.KeyCode.LeftShift
							)
					end
				),

				enter = function(value)
					history_n = 0
					table.insert(history, 1, value)

					p.execute(value)
					state.focused(true)
					raw_text ""
					task.delay(0, raw_text, "")
				end,

				focused = state.focused,
				update_focused = state.focused,

				changed("Text", p.update_text),

				{
					CursorPosition = cursor_position,
					changed("CursorPosition", function(new)
						-- note: reimplement deferred behavior so that this doesn't freak out in immediate mode.
						if next_cursor_position then
							next_cursor_position = new
							return
						end

						next_cursor_position = new
						task.defer(function()
							if next_cursor_position == false then return end

							cursor_position(next_cursor_position)
							next_cursor_position = false
						end)
					end),
				},
			}
		end),
	}
end)
