--!nonstrict
local background = require "./background"
local container = require "./container"
local flex = require "./flex"
local language = require "../../roblox_packages/language"
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
}

type Can<T> = T | () -> T
type Suggestion = {
	x: Can<number>?,
	y: Can<number>?,

	result: () -> language.AnalysisResult,
	suggestions: () -> { language.Suggestion },
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

	--stylua: ignore
	return container {
		x = props.x,
		y = props.y,
		w = 300,
		auto = "Y",
		anchor = { 0, 1 },
		zindex = 10000,

		flex():vertical("bottom"):column():gap(4),

		show(function() return #props.result().suggestions > 0 end, function()
			return background {
				ys = 1,
				w = 200,
				h = 0,
				anchor = { 0, 1 },

				auto = Enum.AutomaticSize.Y,

				transparency = 0,

				flex():vertical("bottom"):layout(),

				indexes(function()
					local tracked = {}
					for i = show_suggestions_from(), show_suggestions_from() + TOTAL_SUGGESTIONS - 1 do
						tracked[i - show_suggestions_from() + 1] =
							props.suggestions()[i]
					end
					return tracked
				end, function(suggestion, idx)
					return text {
						w = 200,
						h = 20,
						order = idx,

						text_size = 16,
						xalignment = Enum.TextXAlignment.Left,
						text = function() return suggestion().display end,
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

		show(function() return props.result().additional_info end, function()
			local result = function()
				return props.result().additional_info or {}
			end

			return background {
				w = 300,
				layout = 10,
				auto = Enum.AutomaticSize.Y,

				transparency = 0,

				flex(),

				background {
					w = 300, h = 24,
					
					flex()
						:column()
						:between("horizontal")
						:vertical "center",
					padding { x = 4 },

					text {
						text = function() return result().name or "" end,
						text_size = 20,
						weight = Enum.FontWeight.Bold,
					},

					text {
						text = function()
							return `{result().type}{if result().optional
								then "?"
								else ""}` or ""
						end,
						text_size = 18,
						weight = Enum.FontWeight.Light,
					},
				},

				text {
					padding { padding = 4 },
					w = 300,
					wrapped = true,
					text_size = 16,
					xalignment = Enum.TextXAlignment.Left,
					text = function()
						local analysis_result = props.result()
						return analysis_result.additional_info and analysis_result.additional_info.description or ""
					end,
				},
			}
		end)

	}
end
