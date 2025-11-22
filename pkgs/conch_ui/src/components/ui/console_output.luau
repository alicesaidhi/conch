local RunService = game:GetService "RunService"

local background = require "./background"
local component = require "../../util/component"
local container = require "../core/container"
local state = require "../../state"
local text = require "../core/text"
local theme = require "../../theme"
local vide = require "../../../roblox_packages/vide"

local source = vide.source
local indexes = vide.indexes
local cleanup = vide.cleanup

return component(function(p: {
	errors: () -> { string },
})
	local output_line_position = source(0)
	local total_length = source(0)
	local visible_lines = source(0)
	local output_text = source ""

	cleanup(RunService.Heartbeat:Connect(function(dt)
		if not state.opened() then return end

		local stream = state.current_stream()
		stream.visible_lines = (workspace.CurrentCamera.ViewportSize.Y / 20 - 2)
			// 1
		visible_lines(stream.visible_lines)

		output_line_position(
			math.clamp(
				output_line_position(),
				stream.visible_lines,
				math.max(stream.visible_lines + 1, #stream.richtext_lines)
			)
		)

		if output_line_position() >= total_length() then
			output_line_position(#stream.richtext_lines)
		end

		total_length(#stream.richtext_lines)
		output_text(stream:getformatted(output_line_position()))
	end))

	return background {
		name = "Output",

		ws = 1,
		auto = "y",
		pad = { p = 4 },
		corner = 4,

		flex = { justify = "left" },

		container {
			name = "Output",

			ws = 1,
			auto = "y",
			flex = { direction = "row", align = "bottom" },

			sink = true,
			enabled = true,

			wheel = function(n: number)
				print "scroll"
				output_line_position(output_line_position() + n * 3)
			end,

			text {
				name = "OutputText",
				grow = 1,
				shrink = 1,
				auto = "y",

				xalign = "left",
				size = 16,

				rich = true,
				text = output_text,
			},

			container {
				name = "Scrollbar",
				w = 8,
				hs = 0,

				color = Color3.new(),

				visible = function() return total_length() > visible_lines() end,

				container {
					name = "Scrollbar",

					w = 8,
					hs = function() return total_length() / visible_lines() end,
				},
			},
		},

		container {
			name = "Problems",
			ws = 1,
			auto = "y",

			flex = { justify = "left" },

			indexes(
				p.errors,
				function(error)
					return text {
						ws = 1,
						auto = "y",

						xalign = "left",
						wraps = true,
						text = error,
						size = 16,

						color = theme.text_error,
					}
				end
			),
		},
	}
end)
