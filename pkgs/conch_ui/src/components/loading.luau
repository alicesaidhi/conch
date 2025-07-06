local theme = require "../theme"
local vide = require "../../roblox_packages/vide"

local create = vide.create
local source = vide.source
local cleanup = vide.cleanup
local read = vide.read

type Can<T> = T | () -> T
type Background = {
	read width: Can<number>?,
	read height: Can<number>?,
	read x: Can<number>?,
	read y: Can<number>?,
	read xs: Can<number>?,
	read xy: Can<number>?,
	read anchor: Can<{ number }>?,
	read zindex: Can<number>?,
	read auto: Can<Enum.AutomaticSize | "X" | "Y" | "XY">?,
	read color: Can<Color3>?,
	read layout: Can<number>?,

	read weight: Can<Enum.FontWeight>?,
	read text_size: Can<number>?,
	read text_style: Can<"normal" | "info" | "warn" | "error">?,
	read xalignment: Can<Enum.TextXAlignment>?,
	read speed: number,

	[number]: unknown,
}

local steps = { "-", "/", "|", "\\" }

return function(props: Background)
	local dt = source(0)
	local thread = task.spawn(function()
		while true do
			dt(dt() + task.wait())
		end
	end)

	cleanup(function() task.cancel(thread) end)

	return create "TextLabel" {
		Size = function()
			local width, height = read(props.width), read(props.height)
			return UDim2.new(0, width or 0, 0, height or 0)
		end,
		Position = function()
			return UDim2.new(
				read(props.xs) or 0,
				read(props.x) or 0,
				read(props.ys) or 0,
				read(props.y) or 0
			)
		end,
		AnchorPoint = if props.anchor
			then function()
				return Vector2.new(
					read(props.anchor)[1] or 0,
					read(props.anchor)[2] or 0
				)
			end
			else nil,
		AutomaticSize = props.auto,
		LayoutOrder = props.layout,

		BackgroundTransparency = 1,

		Text = function()
			return `{steps[(dt() * props.speed // 1) % 4 + 1]} - {dt() * 100 // 1 / 100}\ts`
		end,
		TextSize = props.text_size,
		TextColor3 = props.color or function()
			local style = props.text_style
			return if read(style) == "normal"
				then theme.text()
				elseif read(style) == "warn" then theme.text_warn()
				elseif read(style) == "error" then theme.text_error()
				elseif read(style) == "info" then theme.text_info()
				else theme.text()
		end,
		FontFace = function()
			local f: Font = theme.font()
			local weight = read(props.weight) or Enum.FontWeight.Regular
			return Font.new(f.Family, weight)
		end,
		TextWrapped = props.wrapped,
		TextXAlignment = props.xalignment,

		BackgroundTransparency = 1,

		unpack(props),
	}
end
