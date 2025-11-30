local RunService = game:GetService "RunService"
local UserInputService = game:GetService "UserInputService"

local background = require "./background"
local component = require "../../util/component"
local container = require "../core/container"
local interval = require "../../util/interval"
local state = require "../../state"
local text = require "../core/text"
local theme = require "../../theme"
local vide = require "../../../roblox_packages/vide"

local source = vide.source
local effect = vide.effect
local indexes = vide.indexes
local cleanup = vide.cleanup
local changed = vide.changed

return component(function(p: {
	errors: () -> { string },
})
	local output_line_position = source(0)
	local total_length = source(0)
	local visible_lines = source(0)
	local output_text = source ""

	local min = source(0)
	local max = source(0)

	effect(function()
		local stream = state.current_stream()
		output_line_position(
			math.clamp(
				output_line_position(),
				stream.visible_lines,
				math.max(stream.visible_lines + 1, #stream.richtext_lines)
			)
		)
	end)

	interval(0, function(dt)
		if not state.opened() then return nil end

		local stream = state.current_stream()
		stream.max_line_length = workspace.CurrentCamera.ViewportSize.X // 9
		stream.visible_lines = (
			(workspace.CurrentCamera.ViewportSize.Y * 0.8) / 16 - 2
		) // 1
		visible_lines(stream.visible_lines)

		min(stream.visible_lines)
		max(math.max(stream.visible_lines + 1, #stream.richtext_lines))

		if output_line_position() >= total_length() then
			output_line_position(#stream.richtext_lines)
		end

		total_length(#stream.richtext_lines)
		output_text(stream:getformatted(output_line_position()))

		return nil
	end)

	local scrollbar_position = function(): number
		return math.map(output_line_position(), min(), max(), 0, 1)
	end

	local hold = source(false)

	local scroll_pos = source(Vector2.zero)
	local scroll_size = source(Vector2.zero)
	local old_position: Vector2?

	interval(0, function()
		if not hold() then return nil end

		if
			not UserInputService:IsMouseButtonPressed(
				Enum.UserInputType.MouseButton1
			)
		then
			hold(false)
			return nil
		end

		local mouse = UserInputService:GetMouseLocation()

		if old_position == nil then
			local scaled_position = (mouse.Y - scroll_pos().Y) / scroll_size().Y
			local line_position = math.map(scaled_position, 0, 1, min(), max())
				// 1
			output_line_position(line_position)
			old_position = mouse
		else
			local leftover_size = 1 - total_length() / visible_lines()
			local unit_per_line = leftover_size
				/ (total_length() - min() - max())
			local delta = old_position - mouse
			local delta_scale = -delta.Y / scroll_size().Y

			local lines = math.round(delta_scale / unit_per_line)

			output_line_position(output_line_position() + lines)

			if lines ~= 0 then old_position = mouse end
		end

		return nil
	end)

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
				output_line_position(output_line_position() + n * 3)
			end,

			text {
				name = "OutputText",
				grow = 1,
				shrink = 1,
				auto = "y",

				xalign = "left",
				size = 16,
				weight = 500,

				rich = true,
				text = output_text,
			},

			container {
				name = "Scrollbar",
				w = 8,
				h = function() return visible_lines() * 16 end,

				visible = function() return total_length() > visible_lines() end,

				hold = function(holding)
					if holding then hold(true) end
				end,

				changed("AbsolutePosition", scroll_pos),
				changed("AbsoluteSize", scroll_size),

				container {
					name = "Scrollbar",

					w = 8,
					ys = scrollbar_position,
					anchor = function() return { 0, scrollbar_position() } end,
					hs = function() return visible_lines() / total_length() end,

					color = theme.background,

					hold = function(holding)
						if holding then
							hold(true)
							old_position = UserInputService:GetMouseLocation()
						end
					end,

					vide.create "UISizeConstraint" {
						MinSize = Vector2.new(0, 16),
					},
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
