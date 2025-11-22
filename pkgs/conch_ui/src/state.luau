local conch = require "../roblox_packages/conch"
local output = require(script.Parent.output)
local vide = require "../roblox_packages/vide"

local source = vide.source

local logging_output = output.create_stream()
logging_output.max_line_length = 240

return {
	opened = source(false),
	focused = source(false),

	alignment = source("bottom" :: "bottom" | "top"),

	current_stream = source(logging_output),
	logs = logging_output,
}
