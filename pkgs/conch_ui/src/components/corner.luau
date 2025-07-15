local vide = require "../../roblox_packages/vide"

local create = vide.create

return function(px: number)
	return create "UICorner" {
		CornerRadius = UDim.new(0, px),
	}
end
