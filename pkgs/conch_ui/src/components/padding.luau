local vide = require "../../roblox_packages/vide"

local create = vide.create

type Can<T> = T | () -> T
type Padding = {
	read padding: Can<number>?,
	read x: Can<number>?,
	read y: Can<number>?,
	read left: Can<number>?,
	read right: Can<number>?,
	read top: Can<number>?,
	read bottom: Can<number>?,
}

local function padding(props: Padding)
	local padding = props.padding or 0
	local x = props.x or padding
	local y = props.y or padding
	local left = props.left or x
	local right = props.right or x
	local top = props.top or y
	local bottom = props.bottom or y

	return create "UIPadding" {
		PaddingLeft = UDim.new(0, left),
		PaddingRight = UDim.new(0, right),
		PaddingTop = UDim.new(0, top),
		PaddingBottom = UDim.new(0, bottom),
	}
end

return padding
