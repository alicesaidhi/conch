local component = require "../../util/component"
local theme = require "../../theme"
local vide = require "../../../roblox_packages/vide"

local create = vide.create
local source = vide.source
local read = vide.read
local changed = vide.changed
local action = vide.action
local effect = vide.effect

local function find_weight(n: number): Enum.FontWeight
	for _, enum: EnumItem in Enum.FontWeight:GetEnumItems() do
		if math.abs(n - enum.Value) <= 50 then return enum :: any end
	end

	return Enum.FontWeight.Regular
end

type Can<T> = T | () -> T
return component(function(
	p: {
		-- text properties
		read color: Can<Color3>?,
		read transparency: Can<number>?,
		read acc: boolean?,

		read text: Can<string | number>,
		read size: Can<number>?,
		read font: Can<Font>?,
		read truncate: "split" | "end"?,
		read wraps: boolean?,

		read xalign: "left" | "center" | "right"?,
		read yalign: "top" | "center" | "bottom"?,

		read weight: Can<number>?,
		read italic: Can<boolean>?,

		read multiline: Can<boolean>?,
		read editable: Can<boolean>?,
		read rich: boolean?,

		read placeholder: Can<string>?,
		read update_text: ((string) -> ())?,
		read update_focused: ((boolean) -> ())?,
		read enter: ((string) -> ())?,
		read focused: Can<boolean>?,

		-- stroke properties
		read stroke: Can<Color3>?,
		read stroke_transparency: Can<number>?,
		read thickness: Can<number>?,
	},
	children
)
	local raw_text = source ""
	return create("TextBox" :: "TextBox") {
		AutomaticSize = Enum.AutomaticSize.XY,
		AutoLocalize = false,

		BackgroundTransparency = 1,

		Text = p.text,
		TextColor3 = p.color or theme.text,
		PlaceholderColor3 = theme.select_color "subtext1",
		TextTransparency = p.transparency,
		PlaceholderText = p.placeholder,
		TextSize = function() return math.round(read(p.size or 16)) end,
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

		FontFace = function()
			local font = read(p.font or theme.font) :: Font
			return Font.new(
				font.Family,
				find_weight(read(p.weight or 500)),
				if read(p.italic) then Enum.FontStyle.Italic else font.Style
			)
		end,

		if p.update_text then changed("Text", p.update_text) else nil,
		changed("Text", raw_text),

		TextEditable = p.editable,
		RichText = p.rich,
		MultiLine = p.multiline,

		Focused = function()
			if not p.update_focused then return end
			p.update_focused(true)
		end,

		FocusLost = function(enter)
			if p.update_focused then p.update_focused(false) end
			if not enter then return end
			if not p.focused then return end
			p.enter(raw_text())
		end,

		if p.stroke
			then create("UIStroke" :: "UIStroke") {
				Color = p.stroke,
				Thickness = p.thickness or 1,
				Transparency = p.stroke_transparency,
			}
			else nil,

		action(function(textbox: TextBox)
			effect(function()
				local value = read(p.focused)
				if textbox:IsFocused() == value then return end
				task.delay(0, function()
					if value then
						textbox:CaptureFocus()
					else
						textbox:ReleaseFocus(false)
					end
				end)
			end)
		end),
	}
end)
