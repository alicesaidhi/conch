--!nonstrict

local background = require "./background"
local component = require "../../util/component"
local container = require "../core/container"
local language = require "../../../roblox_packages/language"
local state = require "../../state"
local text = require "../core/text"
local theme = require "../../theme"
local vide = require "../../../roblox_packages/vide"

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

return component(function(
	p: {
		x: Can<number>?,
		y: Can<number>?,

		result: () -> language.AnalysisResult,
		suggestions: () -> { language.Suggestion },
		selected: () -> number,
	},
	_
)
	local show_suggestions_from = source(p.selected())

	effect(function()
		local selected = p.selected()
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

	local anchor = function()
		return if state.alignment() == "top" then { 0, 0 } else { 0, 1 }
	end

	--stylua: ignore
	return container {
		w = 300,
		auto = "y",
		anchor = anchor,
		z = 10000,

		thickness = 0,
		corner = 4,

		flex = { direction = "row", justify = "left", align = "bottom", pad = 4 },

		show(function() return #p.result().suggestions > 0 end, function()
			return background {
				w = 300,
				anchor = { 0, 1 },
				flex = { justify = "left", align = "bottom" },

				transparency = 0,
				auto = "y",

				indexes(function()
					local tracked = {}
					for i = show_suggestions_from(), show_suggestions_from() + TOTAL_SUGGESTIONS - 1 do
						tracked[i - show_suggestions_from() + 1] =
							p.suggestions()[i]
					end
					return tracked
				end, function(suggestion, idx: number)
					return container {
						ws = 1,
						h = 20,

						order = idx,
						
						color = Color3.fromHex("ffffff"),
						transparency = function()
							return if idx == p.selected() then 0.8 else 1
						end,

						text {
							ws = 1,
							h = 20,
							pad = { l = 4 },

							size = 16,
							xalign = "left",
							text = function() return suggestion().display end
						}
					}
				end),
			}
		end),

		show(function() return p.result().additional_info end, function()
			local result = function()
				return p.result().additional_info or {}
			end

			return background {
				w = 300,
				order = 10,
				auto = "y",
				flex = {},
				anchor = { 0, 1 },

				transparency = 0,

				container {
					w = 300, h = 24,
					flex = { direction = "row", justify = "between" },
					pad = { x = 4 },
					
					text {
						text = function() return result().name or "" end,
						size = 20,
						weight = 700,
					},

					text {
						text = function()
							return `{result().type}{if result().optional
								then "?"
								else ""}` or ""
						end,
						size = 18,
						weight = 400,
					},
				},

				text {
					w = 300,
					pad = { p = 4 },
					wraps = true,
					size = 16,
					xalign = "left",
					
					color = theme.background,

					text = function()
						local analysis_result = p.result()
						return analysis_result.additional_info and analysis_result.additional_info.description or ""
					end,
				},
			}
		end)

	}
end)
