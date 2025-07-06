local theme = require "../theme"
local vide = require "../../roblox_packages/vide"

local create = vide.create
local read = vide.read :: (<T>(() -> T) -> T) & (<T>(T) -> T)

type Can<T> = T | () -> T
type Background = {
	read width: Can<number>?,
	read height: Can<number>?,
	read order: Can<number>?,

	read text: Can<string>,
	read weight: Can<Enum.FontWeight>?,
	read text_size: Can<number>?,
	read text_style: Can<"normal" | "info" | "warn" | "error">?,
	read xalignment: Can<Enum.TextXAlignment>?,
	read wrapped: Can<boolean>?,

	[number]: unknown,
}

return function(props: Background)
	return create "TextLabel" {
		Size = function()
			return UDim2.fromOffset(
				read(props.width) or 0,
				read(props.height) or 0
			)
		end,
		AutomaticSize = if props.width and props.height
			then nil
			elseif props.width then Enum.AutomaticSize.Y
			else Enum.AutomaticSize.X,

		Text = props.text,
		TextSize = props.text_size,
		TextColor3 = function()
			local style = props.text_style
			return if read(style) == "normal"
				then theme.text()
				elseif read(style) == "warn" then theme.text_warn()
				elseif read(style) == "error" then theme.text_error()
				elseif read(style) == "info" then theme.text_info()
				else theme.text()
		end,
		FontFace = function()
			local f: Font = theme.font()
			local weight = read(props.weight) or Enum.FontWeight.Regular
			return Font.new(f.Family, weight)
		end,
		TextWrapped = props.wrapped,
		TextXAlignment = props.xalignment,
		LayoutOrder = props.order,

		BackgroundTransparency = 1,

		unpack(props),
	}
end
