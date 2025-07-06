local vide = require "../../roblox_packages/vide"

local create = vide.create
local read = vide.read

type Can<T> = T | () -> T
type Container = {
	read width: Can<number>?,
	read height: Can<number>?,
	read x: Can<number>?,
	read y: Can<number>?,
	read xs: Can<number>?,
	read ys: Can<number>?,
	read anchor: Can<{ number }>?,
	read zindex: Can<number>?,
	read auto: Can<Enum.AutomaticSize | "X" | "Y" | "XY">?,
	read layout: Can<number>?,

	[number]: unknown,
}

return function(props: Container)
	return create "Frame" {
		Size = function()
			return UDim2.fromOffset(
				read(props.width) or 0,
				read(props.height) or 0
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
		ZIndex = props.zindex,

		BackgroundTransparency = 1,

		unpack(props),
	}
end
