local auto = require "./auto"
local pad = require "../components/core/pad"
local vide = require "../../roblox_packages/vide"

local effect = vide.effect
local read = vide.read

-- thank u cen

type Array<T> = { T }
type Can<T> = T | () -> T
type Child = Instance | Array<Child> | () -> Child

type FlexProperties = {
	direction: "column" | "row"?,
	sort: "order" | "name"?,
	justify: Can<
		"center" | "left" | "right" | "around" | "between" | "even" | "fill"
	>?,
	align: Can<
		"center" | "top" | "bottom" | "around" | "between" | "even" | "fill"
	>?,
	wrap: boolean?,
	pad: number?,
}

type SpecialProperties = {
	name: string?,
	--- width and height defined in pixels
	w: Can<number>?,
	h: Can<number>?,
	ratio: Can<number>?,
	aspectratio: {
		ratio: Can<number>?,
		type: "fit" | "scale"?,
		axis: "width" | "height"?,
	}?,
	--- width and height defined in scale
	ws: Can<number>?,
	hs: Can<number>?,
	--- width and height defined in pixels but scale is 1 (if not set)
	wr: Can<number>?,
	hr: Can<number>?,

	x: Can<number>?,
	y: Can<number>?,
	xs: Can<number>?,
	ys: Can<number>?,
	rot: Can<number>?,

	--- zindex
	z: Can<number>?,
	--- automatic size
	auto: Can<auto.Auto>?,
	--- the layout order
	order: Can<number>?,
	--- the anchor point
	anchor: Can<Array<number>>?,
	--- is it visible
	visible: (() -> boolean)?,
	-- padding properties
	pad: pad.Pad?,
	--- flex properties
	flex: FlexProperties?,
	--- specifies properties for flex item
	grow: number?,
	shrink: number?,
	align: "auto" | "start" | "end" | "center" | "stretch"?,
}

type function CombineTableAndSetIndexer(a: type, b: type, c: type)
	local t = {}

	for key, value in a:properties() do
		t[key] = value.read
	end

	if b.tag == "table" then
		for key, value in b:properties() do
			if t[key] then error(`Overlapping properties! {key:value()}`) end
			t[key] = value.read
		end
	end

	return types.newtable(
		t :: any,
		{ index = types.number, readresult = c, writeresult = c }
	)
end

local function component<Object, Properties>(
	constructor: (
		Properties,
		never
	) -> Instance
): (
	CombineTableAndSetIndexer<SpecialProperties, Properties, any>
) -> Instance
	local parent_ref: Instance?

	local parent_selector = vide.action(
		function(instance) parent_ref = instance end
	)

	return function(props: SpecialProperties)
		parent_ref = nil -- set to nil in case parent_selector is not used
		local instance = constructor(props, parent_selector :: any)
		local parent = parent_ref or instance
		parent_ref = nil -- set to nil for case constructor calls this function recursively

		local children = { unpack(props :: any) }
		vide.apply(parent)(children :: any)

		if props.name then instance.Name = props.name end
		if props.z then
			vide.effect(
				function() (instance :: GuiObject).ZIndex = vide.read(props.z) end
			)
		end
		if props.order then
			(instance :: GuiObject).LayoutOrder = if typeof(props.order)
					== "function"
				then 0
				else props.order
			if typeof(props.order) == "function" then
				vide.effect(
					function()
						(instance :: GuiObject).LayoutOrder = props.order()
					end
				)
			end
		end
		if props.anchor and typeof(props.anchor) == "table" then
			(instance :: GuiObject).AnchorPoint =
				Vector2.new(props.anchor[1], props.anchor[2])
		elseif props.anchor then
			vide.effect(
				function()
					(instance :: GuiObject).AnchorPoint =
						Vector2.new(props.anchor()[1], props.anchor()[2])
				end
			)
		end
		if props.visible then
			vide.effect(
				function() (instance :: GuiObject).Visible = props.visible() end
			)
		end

		local flex = props.flex
		if flex then
			local layout = parent:FindFirstChildWhichIsA "UIListLayout"
				or Instance.new "UIListLayout"
			layout.FillDirection = (flex.direction or "column") == "column"
					and Enum.FillDirection.Vertical
				or Enum.FillDirection.Horizontal
			layout.SortOrder = (flex.sort or "order") == "order"
					and Enum.SortOrder.LayoutOrder
				or Enum.SortOrder.Name
			layout.Wraps = if flex.wrap ~= nil then flex.wrap else false

			local padding = flex.pad
			if padding then
				vide.effect(
					function() layout.Padding = UDim.new(0, padding) end
				)
			end

			local justify = flex.justify or "center"

			effect(function()
				local justify = read(justify)
				if justify == "center" then
					layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
				elseif justify == "left" then
					layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
				elseif justify == "right" then
					layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
				elseif justify == "around" then
					layout.HorizontalFlex = Enum.UIFlexAlignment.SpaceAround
				elseif justify == "between" then
					layout.HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween
				elseif justify == "even" then
					layout.HorizontalFlex = Enum.UIFlexAlignment.SpaceEvenly
				elseif justify == "fill" then
					layout.HorizontalFlex = Enum.UIFlexAlignment.Fill
				end
			end)

			local align = flex.align or "center"

			effect(function()
				local align = read(align)

				if align == "center" then
					layout.VerticalAlignment = Enum.VerticalAlignment.Center
				elseif align == "top" then
					layout.VerticalAlignment = Enum.VerticalAlignment.Top
				elseif align == "bottom" then
					layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
				elseif align == "fill" then
					layout.VerticalFlex = Enum.UIFlexAlignment.Fill
				elseif align == "around" then
					layout.VerticalFlex = Enum.UIFlexAlignment.SpaceAround
				elseif align == "between" then
					layout.VerticalFlex = Enum.UIFlexAlignment.SpaceBetween
				elseif align == "even" then
					layout.VerticalFlex = Enum.UIFlexAlignment.SpaceEvenly
				end
			end)

			layout.Parent = parent
		end

		if props.align or props.grow or props.shrink then
			local item = vide.create("UIFlexItem" :: "UIFlexItem") {
				FlexMode = Enum.UIFlexMode.Custom,
				GrowRatio = props.grow,
				ShrinkRatio = props.shrink,
				ItemLineAlignment = if props.align == "auto"
					then Enum.ItemLineAlignment.Automatic
					elseif
						props.align == "center"
					then Enum.ItemLineAlignment.Center
					elseif props.align == "end" then Enum.ItemLineAlignment.End
					elseif
						props.align == "start"
					then Enum.ItemLineAlignment.Start
					elseif
						props.align == "stretch"
					then Enum.ItemLineAlignment.Stretch
					else nil,
			}

			item.Parent = instance
		end

		if props.pad then pad(props.pad).Parent = parent end

		if props.rot then
			vide.effect(
				function()
					(instance :: GuiObject).Rotation = vide.read(props.rot)
				end
			)
		end

		local w, h = props.w, props.h
		local ws, hs = props.ws, props.hs
		local wr, hr = props.wr, props.hr

		local w_given = w or ws or wr
		local h_given = h or hs or hr

		if props.auto then
			vide.effect(
				function()
					(instance :: GuiObject).AutomaticSize =
						auto(vide.read(props.auto))
				end
			)
		end

		if w_given or h_given then
			w = w or 0
			h = h or 0

			if not w_given then ws = 0 end
			if not h_given then hs = 0 end

			if wr then
				w = wr
				ws = ws or 1
			end
			if hr then
				h = hr
				hs = hs or 1
			end

			ws = ws or 0
			hs = hs or 0

			assert(w and h and ws and hs)

			vide.effect(function()
				local x = vide.read(w)
				local y = vide.read(h)

				local xs = vide.read(ws)
				local ys = vide.read(hs)

				if not x or not y or not xs or not ys then return end
				local size = UDim2.new(xs, x, ys, y);
				(instance :: GuiObject).Size = size
			end)
		end

		if props.aspectratio then
			vide.create("UIAspectRatioConstraint" :: "UIAspectRatioConstraint") {
				Parent = instance,

				AspectRatio = props.aspectratio.ratio,
				AspectType = if props.aspectratio.type == "fit"
					then Enum.AspectType.FitWithinMaxSize
					elseif
						props.aspectratio.type == "scale"
					then Enum.AspectType.ScaleWithParentSize
					else nil,
				DominantAxis = if props.aspectratio.axis == "width"
					then Enum.DominantAxis.Width
					elseif
						props.aspectratio.axis == "height"
					then Enum.DominantAxis.Height
					else nil,
			}
		elseif props.ratio then
			vide.create("UIAspectRatioConstraint" :: "UIAspectRatioConstraint") {
				Parent = instance,
				AspectRatio = props.ratio,
			}
		end

		local x, y = props.x, props.y
		local xs, ys = props.xs, props.ys

		local x_given = x or xs
		local y_given = y or ys

		if x_given or y_given then
			x = x or 0
			y = y or 0
			xs = xs or 0
			ys = ys or 0

			vide.effect(function()
				local x = vide.read(x)
				local y = vide.read(y)

				local xs = vide.read(xs)
				local ys = vide.read(ys)

				if not x or not y or not xs or not ys then return end
				local position = UDim2.new(xs, x, ys, y);
				(instance :: GuiObject).Position = position
			end)
		end

		return instance
	end
end

return component
