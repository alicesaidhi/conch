local background = require "./background"
local container = require "./container"
local flex = require "./flex"
local padding = require "./padding"
local text = require "./text"
local vide = require "../../roblox_packages/vide"

local show = vide.show
local indexes = vide.indexes
local source = vide.source
local effect = vide.effect

local TOTAL_SUGGESTIONS = 10

export type AnalysisSuggestion = {
	name: string,
	type: string,

	replace: vector,
	with: string,
}

export type AnalysisCommandArgument = {
	kind: "argument",
	name: string,
	optional: boolean,
	description: string | false,
	type: string | false,
	enum: { string } | false,
}

export type AnalysisCommand = {
	kind: "command",
	name: string,
	description: string | false,
	arguments: { AnalysisCommandArgument },
}

type Can<T> = T | () -> T
type Suggestion = {
	x: Can<number>?,
	y: Can<number>?,

	analyzing: () -> AnalysisCommand | AnalysisCommandArgument?,
	suggestions: () -> { AnalysisSuggestion },
	selected: () -> number,
}

return function(props: Suggestion)
	local show_suggestions_from = source(props.selected())

	effect(function()
		local selected = props.selected()
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

	return container {
		x = props.x,
		y = props.y,
		width = 300,
		auto = "Y",
		anchor = { 0, 1 },
		zindex = 10000,

		flex():column():gap(4):vertical "bottom",

		show(props.analyzing, function()
			local analyzed = function()
				return props.analyzing()
					or {
						kind = "",
						name = "",
						description = "",
						optional = false,
					}
			end

			return background {
				width = 300,
				layout = 10,
				auto = Enum.AutomaticSize.Y,

				{ BackgroundTransparency = 0 },

				flex(),

				background {
					height = 24,
					width = 300,
					flex():column():between("horizontal"):vertical "center",
					padding { x = 4 },

					text {
						text = function()
							return if analyzed().kind == "variadic"
								then "..."
								else analyzed().name or ""
						end,
						text_size = 20,
						weight = Enum.FontWeight.Bold,
					},

					text {
						text = function()
							return `{analyzed().type}{if analyzed().optional
								then "?"
								else ""}` or ""
						end,
						text_size = 18,
						weight = Enum.FontWeight.Light,
					},
				},

				text {
					padding { padding = 4 },
					width = 300,
					wrapped = true,
					text_size = 16,
					xalignment = Enum.TextXAlignment.Left,
					text = function() return analyzed().description or "" end,
				},
			}
		end),

		show(function() return props.suggestions()[1] ~= nil end, function()
			return background {
				ys = 1,
				width = 200,
				height = 0,
				anchor = { 0, 1 },

				auto = Enum.AutomaticSize.Y,

				{ BackgroundTransparency = 0 },

				flex():vertical "bottom",

				indexes(function()
					local suggestions = props.suggestions()

					table.sort(
						suggestions,
						function(a, b) return a.name < b.name end
					)

					local tracked = {}
					for i = show_suggestions_from(), show_suggestions_from() + TOTAL_SUGGESTIONS - 1 do
						tracked[i - show_suggestions_from() + 1] =
							suggestions[i]
					end
					return tracked
				end, function(suggestion, idx)
					return text {
						width = 200,
						height = 20,
						order = idx,

						text_size = 16,
						xalignment = Enum.TextXAlignment.Left,
						text = function() return suggestion().name end,
						text_style = function()
							return if idx
									== props.selected()
										- show_suggestions_from()
										+ 1
								then "info"
								else "normal"
						end,

						padding { left = 4 },
					}
				end),
			}
		end),
	}
end
