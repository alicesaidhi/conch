local theme = require "../theme"
local vide = require "../../roblox_packages/vide"

local create = vide.create
local read = vide.read

type Can<T> = T | () -> T
type Background = {
	read w: Can<number>?,
	read h: Can<number>?,
	read x: Can<number>?,
	read y: Can<number>?,
	read xs: Can<number>?,
	read xy: Can<number>?,
	read anchor: Can<{ number }>?,
	read zindex: Can<number>?,
	read auto: Can<Enum.AutomaticSize | "X" | "Y" | "XY">?,
	read color: Can<Color3>?,
	read transparency: Can<number>?,
	read layout: Can<number>?,

	[number]: unknown,
}

return function(props: Background)
	return create "Frame" {
		Size = function()
			local w, h = read(props.w), read(props.h)
			return UDim2.new(
				if w then 0 else 1,
				w or 0,
				if h then 0 else 1,
				h or 0
			)
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

		BackgroundColor3 = props.color or theme.background,
		BackgroundTransparency = props.transparency
			or theme.background_transparency,

		unpack(props),
	}
end
