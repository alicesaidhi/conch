local theme = require "../theme"
local vide = require "../../roblox_packages/vide"

local create = vide.create
local source = vide.source
local effect = vide.effect
local changed = vide.changed
local read = vide.read :: (<T>(() -> T) -> T) & (<T>(T) -> T)

type Can<T> = T | () -> T
type Background = {
	read width: Can<number>?,
	read height: Can<number>?,

	read text: Can<string>,
	read text_size: Can<number>?,
	read placeholder: Can<string>?,
	read focused: Can<boolean>?,
	read xalignment: Can<Enum.TextXAlignment>?,
	read multiline: Can<boolean>?,
	read editable: Can<boolean>?,

	read update_text: ((string) -> ())?,
	read update_focused: ((boolean) -> ())?,
	read enter: (string) -> (),

	[number]: unknown,
}

return function(props: Background)
	local raw_text = source ""
	local textbox: TextBox = create "TextBox" {
		Size = function()
			return UDim2.fromOffset(
				read(props.width) or 0,
				read(props.height) or 0
			)
		end,
		AutomaticSize = Enum.AutomaticSize.XY,

		Text = props.text,
		PlaceholderText = props.placeholder,
		TextSize = props.text_size or 16,
		TextColor3 = theme.text,
		TextXAlignment = props.xalignment,
		MultiLine = props.multiline,
		FontFace = theme.font,

		BackgroundTransparency = 1,

		if props.update_text then changed("Text", props.update_text) else nil,
		changed("Text", raw_text),

		Focused = function()
			if not props.update_focused then return end
			props.update_focused(true)
		end,

		FocusLost = function(enter)
			if props.update_focused then props.update_focused(false) end
			if not enter then return end
			if not props.focused then return end
			props.enter(raw_text())
		end,

		unpack(props),
	}

	effect(function()
		local value = read(props.focused)
		if textbox:IsFocused() == value then return end
		task.defer(function()
			if value then
				textbox:CaptureFocus()
			else
				textbox:ReleaseFocus(false)
			end
		end)
	end)

	return textbox
end
