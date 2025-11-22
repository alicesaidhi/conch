local component = require "../../util/component"
local theme = require "../../theme"
local vide = require "../../../roblox_packages/vide"

local create = vide.create
local read = vide.read

type Can<T> = T | () -> T

local function find_weight(n: number): Enum.FontWeight
	for _, enum: EnumItem in Enum.FontWeight:GetEnumItems() do
		if math.abs(n - enum.Value) <= 50 then return enum :: any end
	end

	return Enum.FontWeight.Regular
end

return component(function(
	p: {
		-- text properties
		color: Can<Color3>?,
		transparency: Can<number>?,
		acc: boolean?,

		text: Can<string | number>,
		size: Can<number>?,
		font: Can<Font>?,
		truncate: "split" | "end"?,
		wraps: boolean?,

		xalign: "left" | "center" | "right"?,
		yalign: "top" | "center" | "bottom"?,

		rich: Can<boolean>?,
		weight: Can<number>?,
		italic: Can<boolean>?,

		-- stroke properties
		stroke: Can<Color3>?,
		stroke_transparency: Can<number>?,
		thickness: Can<number>?,
	},
	_
)
	return create("TextLabel" :: "TextLabel") {
		AutomaticSize = Enum.AutomaticSize.XY,
		AutoLocalize = false,

		BackgroundTransparency = 1,

		Text = p.text,
		TextColor3 = p.color or Color3.fromHex "fdfdfd",
		TextTransparency = p.transparency,
		TextSize = function() return math.round(read(p.size) or 24) end,
		TextTruncate = if p.truncate == "split"
			then Enum.TextTruncate.SplitWord
			elseif p.truncate == "end" then Enum.TextTruncate.AtEnd
			else Enum.TextTruncate.None,

		TextXAlignment = if p.xalign == "left"
			then Enum.TextXAlignment.Left
			elseif p.xalign == "center" then Enum.TextXAlignment.Center
			elseif p.xalign == "right" then Enum.TextXAlignment.Right
			else nil,
		TextYAlignment = if p.yalign == "top"
			then Enum.TextYAlignment.Top
			elseif p.yalign == "center" then Enum.TextYAlignment.Center
			elseif p.yalign == "bottom" then Enum.TextYAlignment.Bottom
			else nil,
		TextWrapped = p.wraps,

		RichText = p.rich,

		FontFace = function()
			local font = read(p.font or theme.font) :: Font
			return Font.new(
				font.Family,
				find_weight(read(p.weight or 400)),
				if read(p.italic) then Enum.FontStyle.Italic else font.Style
			)
		end,

		if p.stroke
			then create("UIStroke" :: "UIStroke") {
				Color = p.stroke,
				Thickness = p.thickness or 1,
				Transparency = p.stroke_transparency,
			}
			else nil,
	}
end)
