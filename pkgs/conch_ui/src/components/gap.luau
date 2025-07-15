local vide = require "../../roblox_packages/vide"

local create = vide.create
local read = vide.read

type Can<T> = T | () -> T
type Gap = {
	read w: Can<number>?,
	read h: Can<number>?,

	[number]: unknown,
}

return function(props: Gap)
	return create "Frame" {
		Name = "gap",
		Size = function()
			return UDim2.fromOffset(read(props.w) or 0, read(props.h) or 0)
		end,

		BackgroundTransparency = 1,

		unpack(props),
	}
end
