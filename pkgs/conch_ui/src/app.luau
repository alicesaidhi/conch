local TextService = game:GetService "TextService"
local UserInputService = game:GetService "UserInputService"

local background = require "./components/background"
local conch = require "../roblox_packages/conch"
local corner = require "./components/corner"
local flex = require "./components/flex"
local gap = require "./components/gap"
local loading = require "./components/loading"
local padding = require "./components/padding"
local screen = require "./components/screen"
local state = require "./state"
local suggestion = require "./components/suggestion"
local text = require "./components/text"
local textbox = require "./components/textbox"
local theme = require "./theme"
local vide = require "../roblox_packages/vide"

local source = vide.source
local derive = vide.derive
local show = vide.show
local changed = vide.changed
local effect = vide.effect
local cleanup = vide.cleanup
local indexes = vide.indexes

local STARTUP_TEXT = [[
Conch 0.2.x
Copyright (c) alicesays_hallo - This project is licensed under MIT, you can view the included license with `license`]]

local history_n = 0
local history = {}

return function()
	local function output(values)
		local s = string.split(values.text, "\n")

		for idx, log in s do
			local logs = state.logs()
			table.insert(logs, 1, { kind = values.kind, text = log })
			table.remove(logs, 100)
			state.logs(logs)
		end
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
	local absolute_position = source(Vector2.zero)
	local pending = source()

	local input = derive(function()
		debug.profilebegin "this"
		if pending() then
			debug.profileend()
			return pending().src .. raw_text()
		else
			debug.profileend()
			return raw_text()
		end
	end)

	local syntax_error = derive(function()
		local status = conch.parse(input())
		return if status.status == "error" then status.why else nil
	end)

	local analysis = source(conch.analyze("", 0))
	local selected_suggestion = source(1)

	effect(
		function()
			selected_suggestion(
				math.clamp(
					selected_suggestion(),
					1,
					math.max(1, #analysis().suggestions)
				)
			)
		end
	)

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

	local before_text = derive(
		function() return string.sub(raw_text(), 1, cursor_position() - 1) end
	)

	local suggestion_position = source(vector.zero)

	local bounds = Instance.new "GetTextBoundsParams"
	bounds.Font = theme.font()
	bounds.RichText = false
	bounds.Size = 20
	bounds.Width = 100000

	effect(function()
		local t = before_text()
		bounds.Text = t
		task.spawn(function()
			local s = TextService:GetTextBoundsAsync(bounds)
			if t ~= before_text() then return end
			suggestion_position(s)
		end)
	end)

	local function autofill(text: string, span: vector, with: string)
		local before = string.sub(text, 1, span.x)
		local after = string.sub(text, span.y + 1, -1)

		task.defer(cursor_position, span.x + #with + 2)
		return before .. with .. " " .. after
	end

	cleanup(UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Down then
			if #analysis().suggestions == 0 then
				if history_n == 0 then history[history_n] = raw_text() end

				history_n = math.clamp(history_n - 1, 0, #history)
				raw_text(history[history_n] or "")
				cursor_position(#raw_text() + 1)
			else
				selected_suggestion(
					math.min(selected_suggestion() + 1, #analysis().suggestions)
				)
			end
		elseif input.KeyCode == Enum.KeyCode.Up then
			if #analysis().suggestions == 0 then
				if history_n == 0 then history[history_n] = raw_text() end

				history_n = math.clamp(history_n + 1, 0, #history)
				raw_text(history[history_n] or "")
				cursor_position(#raw_text() + 1)
			else
				selected_suggestion(math.max(1, selected_suggestion() - 1))
			end
		end
	end))

	local next_cursor_position = false
	return screen {
		name = "Command Executor",
		display_order = 100_000,
		enabled = state.opened,

		flex():fill("horizontal"):vertical "bottom",
		padding { padding = 12 },

		show(analysis, function()
			return vide.create "Folder" {
				suggestion {
					x = function()
						local t = string.split(before_text(), "\n")
						return 10 * #t[#t] + 10
					end,
					y = function()
						return suggestion_position().Y
							+ absolute_position().Y
							- 20
					end,
					selected = selected_suggestion,

					analyzing = function() return analysis().analyzing end,
					suggestions = function() return analysis().suggestions end,
				},
			}
		end),

		background {
			auto = "Y",

			flex(),
			corner(4),
			padding { y = 4 },

			indexes(function()
				local err = syntax_error()
				local result = table.clone(analysis() and analysis().logs or {})
				if err then
					table.insert(result, { kind = "error", text = err })
				end
				return result
			end, function(log, layout)
				return text {
					order = 0 - layout + 100,
					height = 20,

					text = function() return log().text end,
					text_size = 16,
					text_style = function() return log().kind end,
					xalignment = Enum.TextXAlignment.Left,

					padding { x = 8 },
				}
			end),

			indexes(state.logs, function(log: () -> conch.Log, layout: number)
				return text {
					height = 20,
					order = -layout - 1,

					text = function() return log().text end,
					text_size = 16,
					text_style = function() return log().kind end,
					xalignment = Enum.TextXAlignment.Left,

					padding { x = 8 },
				}
			end),
		},

		gap { height = 4 },

		background {
			auto = Enum.AutomaticSize.Y,
			corner(4),

			show(
				working,
				function()
					return loading {
						height = 18,
						speed = 6,
						text_size = 18,
						xalignment = Enum.TextXAlignment.Left,
					}
				end,
				function()
					return textbox {
						text = raw_text,
						update_text = function(text: string)
							local position = next_cursor_position
								or cursor_position()
							local at =
								string.sub(text, position - 1, position - 1)
							local suggestion = analysis().suggestions

							if at == "\t" and suggestion[1] then
								text = autofill(
									raw_text(),
									suggestion[selected_suggestion()].replace,
									suggestion[selected_suggestion()].with
								)
							end

							raw_text(text)
						end,
						placeholder = "Enter your command",
						text_size = 18,
						xalignment = Enum.TextXAlignment.Left,
						multiline = function()
							if pending() then
								local status = conch.parse(
									pending().src .. raw_text(),
									"yield"
								)
								return status.status == "pending"
							else
								local status = conch.parse(raw_text(), "yield")
								return status.status == "pending"
							end
						end,

						enter = function(value)
							history_n = 0
							table.insert(history, 1, value)
							raw_text ""
							state.focused(true)

							if pending() then
								pending(pending().append(value))
							else
								pending(conch.parse(value, true))
							end

							if pending().status ~= "pending" then
								working(true)
								pending(nil)
								conch.execute(value)
								working(false)
							end
						end,

						focused = state.focused,
						update_focused = state.focused,

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
									cursor_position(next_cursor_position)
									next_cursor_position = false
								end)
							end),
						},
					}
				end
			),

			padding { x = 8, y = 8 },
			flex():fill():vertical("center"):horizontal "left",

			changed("AbsolutePosition", absolute_position),
		},
	}
end
