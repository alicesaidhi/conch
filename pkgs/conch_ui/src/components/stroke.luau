local theme = require "../theme"
local vide = require "../../roblox_packages/vide"

local create = vide.create

type Can<T> = T | () -> T
type Stroke = {
	read thickness: Can<number>,

	[number]: unknown,
}

return function(props: Stroke)
	return create "UIStroke" {
		Thickness = props.thickness,
		Color = theme.stroke,

		unpack(props),
	}
end
