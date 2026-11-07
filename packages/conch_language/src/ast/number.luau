--[=[
Converts the text of a number token into a number, or nil if it isn't one.
Underscores are ignored and a `0x` or `0b` prefix picks the base.
]=]
local function to_number(text: string): number?
	local prefix = string.lower(string.sub(text, 1, 2))
	local base = if prefix == "0x" then 16 elseif prefix == "0b" then 2 else 10

	if base ~= 10 then text = string.sub(text, 3) end
	text = string.gsub(text, "_", "")

	return tonumber(text, base)
end

return to_number
