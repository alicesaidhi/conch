local catppuccin = require "./catppuccin"
local vide = require "../roblox_packages/vide"

local source = vide.source

local selected_theme = source(catppuccin.moccha)

local function select_color(key: keyof<typeof(catppuccin.frappe)>): () -> Color3
	return function() return (selected_theme() :: any)[key] end
end

return {
	selected = selected_theme,
	select_color = select_color,

	ansi_pallete = {
		[0] = Color3.fromHex "#000000",
		[1] = catppuccin.latte.red,
		[2] = catppuccin.latte.green,
		[3] = catppuccin.latte.yellow,
		[4] = catppuccin.latte.blue,
		[5] = catppuccin.latte.mauve,
		[6] = catppuccin.latte.sky,
		[7] = catppuccin.latte.base,
		[8] = catppuccin.moccha.red,
		[9] = catppuccin.moccha.green,
		[10] = catppuccin.moccha.base,
		[11] = catppuccin.moccha.yellow,
		[12] = catppuccin.moccha.blue,
		[13] = catppuccin.moccha.mauve,
		[14] = catppuccin.moccha.sky,
		[15] = Color3.fromHex "ffffff",
	},

	background = select_color "base",
	background_transparency = source(0.1),
	-- stroke = source(Color3.fromHex "2e5053"),

	text = select_color "text",
	text_error = select_color "red",
	text_info = select_color "blue",
	text_warn = select_color "peach",
	font = source(Font.fromId(16658246179)),
}
