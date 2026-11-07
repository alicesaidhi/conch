local vide = require "../../roblox_packages/vide"

local read = vide.read

export type Can<T> = T | () -> T
export type Auto = "x" | "y" | "xy" | ""

local AUTO_MAP = {
	x = Enum.AutomaticSize.X,
	y = Enum.AutomaticSize.Y,
	xy = Enum.AutomaticSize.XY,
	[""] = Enum.AutomaticSize.None,
}

return function(auto: Can<Auto>): Enum.AutomaticSize
	if typeof(read(auto)) == "string" then
		return AUTO_MAP[read(auto)]
	else
		return Enum.AutomaticSize.None
	end
end
