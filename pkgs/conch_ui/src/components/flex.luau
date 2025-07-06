local vide = require "../../roblox_packages/vide"

local create = vide.create

return function()
	local list: UIListLayout = create "UIListLayout" {}
	local t = { list }
	local mt = {}

	function mt:row()
		list.FillDirection = Enum.FillDirection.Vertical
		return self
	end

	function mt:column()
		list.FillDirection = Enum.FillDirection.Horizontal
		return self
	end

	function mt:layout()
		list.SortOrder = Enum.SortOrder.LayoutOrder
		return self
	end

	function mt:name()
		list.SortOrder = Enum.SortOrder.Name
		return self
	end

	function mt:none(direction: "horizontal" | "vertical"?)
		if direction ~= "vertical" then
			list.HorizontalFlex = Enum.UIFlexAlignment.None
		end
		if direction ~= "horizontal" then
			list.VerticalFlex = Enum.UIFlexAlignment.None
		end
		return self
	end

	function mt:even(direction: "horizontal" | "vertical"?)
		if direction ~= "vertical" then
			list.HorizontalFlex = Enum.UIFlexAlignment.SpaceEvenly
		end
		if direction ~= "horizontal" then
			list.VerticalFlex = Enum.UIFlexAlignment.SpaceEvenly
		end
		return self
	end

	function mt:around(direction: "horizontal" | "vertical"?)
		if direction ~= "vertical" then
			list.HorizontalFlex = Enum.UIFlexAlignment.SpaceAround
		end
		if direction ~= "horizontal" then
			list.VerticalFlex = Enum.UIFlexAlignment.SpaceAround
		end
		return self
	end

	function mt:between(direction: "horizontal" | "vertical"?)
		if direction ~= "vertical" then
			list.HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween
		end
		if direction ~= "horizontal" then
			list.VerticalFlex = Enum.UIFlexAlignment.SpaceBetween
		end
		return self
	end

	function mt:fill(direction: "horizontal" | "vertical")
		if direction ~= "vertical" then
			list.HorizontalFlex = Enum.UIFlexAlignment.Fill
		end
		if direction ~= "horizontal" then
			list.VerticalFlex = Enum.UIFlexAlignment.Fill
		end
		return self
	end

	function mt:horizontal(align: "left" | "right" | "center")
		list.HorizontalAlignment = if align == "left"
			then Enum.HorizontalAlignment.Left
			elseif align == "right" then Enum.HorizontalAlignment.Right
			else Enum.HorizontalAlignment.Center
		return self
	end

	function mt:vertical(align: "top" | "bottom" | "center")
		list.VerticalAlignment = if align == "top"
			then Enum.VerticalAlignment.Top
			elseif align == "bottom" then Enum.VerticalAlignment.Bottom
			else Enum.VerticalAlignment.Center
		return self
	end

	function mt:gap(px: number)
		list.Padding = UDim.new(0, px)
		return self
	end

	return setmetatable(t, { __index = mt })
end
