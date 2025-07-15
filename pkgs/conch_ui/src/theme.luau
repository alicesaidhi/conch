local vide = require "../roblox_packages/vide"

local source = vide.source

return {

	background = source(Color3.fromHex "#0d181b"),
	background_transparency = source(0.2),
	stroke = source(Color3.fromHex "2e5053"),

	text = source(Color3.fromHex "#eeeeee"),
	text_error = source(Color3.fromHex "#f76b6e"),
	text_info = source(Color3.fromHex "#56a6e4"),
	text_warn = source(Color3.fromHex "#e8b736"),
	text_transparency = source(0.5),
	font = source(Font.fromId(16658246179)),
}
