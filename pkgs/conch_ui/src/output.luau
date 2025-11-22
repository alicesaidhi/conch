local theme = require "./theme"
export type Color = {
	kind: "color",
	color: Color3,
	line: number,
}

export type BGColor = {
	kind: "bgcolor",
	color: Color3,
	line: number,
}

export type Bold = {
	kind: "bold",
	line: number,
}

export type Italic = {
	kind: "italic",
	line: number,
}

export type Underline = {
	kind: "underline",
	line: number,
}

export type Strikethrough = {
	kind: "strikethrough",
	line: number,
}

export type Tag = | Color | BGColor | Bold | Italic | Underline | Strikethrough

export type Stream = {
	visible_lines: number, -- how many lines are visible
	max_line_length: number, -- stores how large a single line can be
	active_tags: { Tag }, -- stores any active tags for html processing

	chars_left: number, -- stores how many characters are left until the next line needs to be appended
	at: number,

	start_tags_per_line: { { Tag } },
	richtext_lines: { number },
	richtext: buffer,

	write: (Stream, buffer) -> (),

	getformatted: (Stream, from: number) -> string,
}

local ESCAPE_CHAR = string.byte "\27"
local NEWLINE = string.byte "\n"
local OPEN_BLOCKY_BRACKET = string.byte "["
local SEMICOLON = string.byte ";"

local function char(name: string) return string.byte(name) end

local function next_pow_of_2(x: number)
	assert(x > 0 and x <= 2 ^ 32)
	x -= 1
	x = bit32.bor(x, bit32.rshift(x, 1))
	x = bit32.bor(x, bit32.rshift(x, 2))
	x = bit32.bor(x, bit32.rshift(x, 4))
	x = bit32.bor(x, bit32.rshift(x, 8))
	x = bit32.bor(x, bit32.rshift(x, 16))
	return x + 1
end

local function BUFFER_RESIZE(b: buffer, size: number): buffer
	local b_new = buffer.create(next_pow_of_2(size))
	buffer.copy(b_new, 0, b)

	return b_new
end

local function RESIZE(b: buffer, size: number): buffer
	return if buffer.len(b) < size then BUFFER_RESIZE(b, size) else b
end

local FONT_STOP = buffer.fromstring "</font>"
local BOLD_STOP = buffer.fromstring "</b>"
local ITALICS_STOP = buffer.fromstring "</i>"
local UNDERLINE_STOP = buffer.fromstring "</u>"
local STRIKETHROUGH_STOP = buffer.fromstring "</s>"
local MARK_STOP = buffer.fromstring "</mark>"

local FONT_COLOR_START = buffer.fromstring '<font color="#'
local BOLD_START = buffer.fromstring "<b>"
local ITALICS_START = buffer.fromstring "<i>"
local UNDERLINE_START = buffer.fromstring "<u>"
local STRIKETHROUGH_START = buffer.fromstring "<s>"
local MARK_START = buffer.fromstring '<mark color="#'
local END_ARROW = char ">"

local ESCAPE_LIST = {
	[char(`<`)] = buffer.fromstring "&lt;",
	[char(`>`)] = buffer.fromstring "&gt;",
	[char(`"`)] = buffer.fromstring "&quot;",
	[char(`'`)] = buffer.fromstring "&apos;",
	[char "&"] = buffer.fromstring "&amp;",
}

local COLOR_PALETTE = theme.ansi_pallete

local MAX_SIZE = 24_000_000
local DELETE_SIZE = 1_000_000

local function write(self: Stream, input: buffer)
	local LINE_LENGTH = self.max_line_length
	local len_input = buffer.len(input)

	-- chars until newline
	local chars_left = self.chars_left

	local at = self.at
	local b = RESIZE(self.richtext, at + buffer.len(input))

	-- overwrite existing parts of the buffer if too large
	if at > MAX_SIZE then
		buffer.copy(b, 0, b, DELETE_SIZE, at - DELETE_SIZE)
		at -= DELETE_SIZE
	end

	local i = 0

	local function consume()
		i += 1
		return if i - 1 > len_input then 0 else buffer.readu8(input, i - 1)
	end

	local function peek()
		return if i > len_input then 0 else buffer.readu8(input, i)
	end

	local function is_escapecode_stop()
		return peek() == SEMICOLON
			or peek() == char "m"
			or i >= buffer.len(input)
	end

	local function append(input: buffer)
		b = RESIZE(b, at + buffer.len(input))
		buffer.copy(b, at, input, 0)
		at += buffer.len(input)
	end

	local function write_char(char: number)
		b = RESIZE(b, at + 1)
		buffer.writeu8(b, at, char)
		at += 1
	end

	local function pop_tag(tag: Tag)
		if tag.kind == "bgcolor" then
			append(MARK_STOP)
		elseif tag.kind == "bold" then
			append(BOLD_STOP)
		elseif tag.kind == "color" then
			append(FONT_STOP)
		elseif tag.kind == "italic" then
			append(ITALICS_STOP)
		elseif tag.kind == "strikethrough" then
			append(STRIKETHROUGH_STOP)
		elseif tag.kind == "underline" then
			append(UNDERLINE_STOP)
		end
	end

	local function append_tag(tag: Tag)
		if tag.kind == "bgcolor" then
			append(MARK_START)
			append(buffer.fromstring(tag.color:ToHex()))
			write_char(char '"')
			write_char(END_ARROW)
		elseif tag.kind == "bold" then
			append(BOLD_START)
		elseif tag.kind == "color" then
			append(FONT_COLOR_START)
			append(buffer.fromstring(tag.color:ToHex()))
			write_char(char '"')
			write_char(END_ARROW)
		elseif tag.kind == "italic" then
			append(ITALICS_START)
		elseif tag.kind == "strikethrough" then
			append(STRIKETHROUGH_START)
		elseif tag.kind == "underline" then
			append(UNDERLINE_START)
		end

		table.insert(self.active_tags, tag)
	end

	local function flush_tags()
		for i = #self.active_tags, 1, -1 do
			local tag = self.active_tags[i]
			pop_tag(tag)
		end
		table.clear(self.active_tags)
	end

	local function reset_tag(kind: index<Tag, "kind">)
		local insert_back = {}

		for _, tag in self.active_tags do
			pop_tag(tag)

			if kind == tag.kind then
				break
			else
				table.insert(insert_back, tag)
			end
		end

		for i = #insert_back, 1, -1 do
			append_tag(insert_back[i])
		end
	end

	while i < buffer.len(input) do
		local c = consume()

		if c == ESCAPE_CHAR and peek() == OPEN_BLOCKY_BRACKET then
			consume()

			while peek() ~= char "m" and i < buffer.len(input) do
				if peek() == SEMICOLON then consume() end

				local current = ""
				local from = i

				while not is_escapecode_stop() and i < buffer.len(input) do
					consume()
				end

				current = buffer.readstring(input, from, i - from)

				if current == "0" then -- reset all modes (styles and colors)
					flush_tags()
				elseif current == "1" then -- set bold
					append_tag { kind = "bold", line = #self.richtext_lines }
				elseif current == "2" then -- set dim/faint mode
					warn "todo: dim/faint mode"
				elseif current == "3" then -- set italic mode
					append_tag { kind = "italic", line = #self.richtext_lines }
				elseif current == "4" then -- set underline mode
					append_tag { kind = "underline", line = #self.richtext_lines }
				elseif current == "5" then -- set blinking mode
					warn "todo: blinking mode"
				elseif current == "7" then -- set inverse mode
					warn "todo: inverse mode"
				elseif current == "8" then -- set hidden/invis mode
					warn "todo: invis mode"
				elseif current == "9" then -- set striekthrough mode
					append_tag {
						kind = "strikethrough",
						line = #self.richtext_lines,
					}
					-- reset
				elseif current == "21" then -- reset bold
					reset_tag "bold"
				elseif current == "22" then -- reset dim/faint mode
					warn "todo: dim/faint mode"
				elseif current == "23" then -- reset italic mode
					reset_tag "italic"
				elseif current == "24" then -- reset underline mode
					reset_tag "underline"
				elseif current == "25" then -- reset blinking mode
					warn "todo: blinking mode"
				elseif current == "27" then -- reset inverse mode
					warn "todo: inverse mode"
				elseif current == "28" then -- reset hidden/invis mode
					warn "todo: invis mode"
				elseif current == "29" then -- reset striekthrough mode
					reset_tag "strikethrough"
				elseif current == "30" then -- foreground colors
					append_tag {
						kind = "color",
						color = COLOR_PALETTE[0],
						line = #self.richtext_lines,
					}
				elseif current == "31" then
					append_tag {
						kind = "color",
						color = COLOR_PALETTE[1],
						line = #self.richtext_lines,
					}
				elseif current == "32" then
					append_tag {
						kind = "color",
						color = COLOR_PALETTE[2],
						line = #self.richtext_lines,
					}
				elseif current == "33" then
					append_tag {
						kind = "color",
						color = COLOR_PALETTE[3],
						line = #self.richtext_lines,
					}
				elseif current == "34" then
					append_tag {
						kind = "color",
						color = COLOR_PALETTE[4],
						line = #self.richtext_lines,
					}
				elseif current == "35" then
					append_tag {
						kind = "color",
						color = COLOR_PALETTE[5],
						line = #self.richtext_lines,
					}
				elseif current == "36" then
					append_tag {
						kind = "color",
						color = COLOR_PALETTE[6],
						line = #self.richtext_lines,
					}
				elseif current == "37" then
					append_tag {
						kind = "color",
						color = COLOR_PALETTE[7],
						line = #self.richtext_lines,
					}
				elseif current == "38" then
					append_tag {
						kind = "color",
						color = COLOR_PALETTE[8],
						line = #self.richtext_lines,
					}
				elseif current == "39" then
					append_tag {
						kind = "color",
						color = COLOR_PALETTE[9],
						line = #self.richtext_lines,
					}
				elseif current == "310" then
					append_tag {
						kind = "color",
						color = COLOR_PALETTE[10],
						line = #self.richtext_lines,
					}
				elseif current == "311" then
					append_tag {
						kind = "color",
						color = COLOR_PALETTE[11],
						line = #self.richtext_lines,
					}
				elseif current == "312" then
					append_tag {
						kind = "color",
						color = COLOR_PALETTE[12],
						line = #self.richtext_lines,
					}
				elseif current == "313" then
					append_tag {
						kind = "color",
						color = COLOR_PALETTE[13],
						line = #self.richtext_lines,
					}
				elseif current == "314" then
					append_tag {
						kind = "color",
						color = COLOR_PALETTE[14],
						line = #self.richtext_lines,
					}
				elseif current == "315" then
					append_tag {
						kind = "color",
						color = COLOR_PALETTE[15],
						line = #self.richtext_lines,
					}
				elseif current == "40" then -- background colors
					append_tag {
						kind = "bgcolor",
						color = COLOR_PALETTE[0],
						line = #self.richtext_lines,
					}
				elseif current == "41" then
					append_tag {
						kind = "bgcolor",
						color = COLOR_PALETTE[1],
						line = #self.richtext_lines,
					}
				elseif current == "42" then
					append_tag {
						kind = "bgcolor",
						color = COLOR_PALETTE[2],
						line = #self.richtext_lines,
					}
				elseif current == "43" then
					append_tag {
						kind = "bgcolor",
						color = COLOR_PALETTE[3],
						line = #self.richtext_lines,
					}
				elseif current == "44" then
					append_tag {
						kind = "bgcolor",
						color = COLOR_PALETTE[4],
						line = #self.richtext_lines,
					}
				elseif current == "45" then
					append_tag {
						kind = "bgcolor",
						color = COLOR_PALETTE[5],
						line = #self.richtext_lines,
					}
				elseif current == "46" then
					append_tag {
						kind = "bgcolor",
						color = COLOR_PALETTE[6],
						line = #self.richtext_lines,
					}
				elseif current == "47" then
					append_tag {
						kind = "bgcolor",
						color = COLOR_PALETTE[7],
						line = #self.richtext_lines,
					}
				elseif current == "48" then
					append_tag {
						kind = "bgcolor",
						color = COLOR_PALETTE[8],
						line = #self.richtext_lines,
					}
				elseif current == "49" then
					append_tag {
						kind = "bgcolor",
						color = COLOR_PALETTE[9],
						line = #self.richtext_lines,
					}
				elseif current == "410" then
					append_tag {
						kind = "bgcolor",
						color = COLOR_PALETTE[10],
						line = #self.richtext_lines,
					}
				elseif current == "411" then
					append_tag {
						kind = "bgcolor",
						color = COLOR_PALETTE[11],
						line = #self.richtext_lines,
					}
				elseif current == "412" then
					append_tag {
						kind = "bgcolor",
						color = COLOR_PALETTE[12],
						line = #self.richtext_lines,
					}
				elseif current == "413" then
					append_tag {
						kind = "bgcolor",
						color = COLOR_PALETTE[13],
						line = #self.richtext_lines,
					}
				elseif current == "414" then
					append_tag {
						kind = "bgcolor",
						color = COLOR_PALETTE[14],
						line = #self.richtext_lines,
					}
				elseif current == "415" then
					append_tag {
						kind = "bgcolor",
						color = COLOR_PALETTE[15],
						line = #self.richtext_lines,
					}
				end
			end

			consume()
			continue
		else
			if chars_left == 0 or c == NEWLINE then
				table.insert(
					self.start_tags_per_line,
					table.clone(self.active_tags)
				)
				table.insert(self.richtext_lines, at)
				chars_left = LINE_LENGTH

				if c ~= NEWLINE then
					b = RESIZE(b, at + 1)
					buffer.writeu8(b, at, NEWLINE)
					at += 1
				end
			end

			b = RESIZE(b, at + 1)

			if ESCAPE_LIST[c] then
				append(ESCAPE_LIST[c])
			else
				buffer.writeu8(b, at, c)
				at += 1
			end

			if c ~= NEWLINE then
				chars_left -= 1
			end

			if c == char "\t" then
				chars_left = math.floor(chars_left / 4) * 4
			end
		end
	end

	self.at = at
	self.chars_left = chars_left
	self.richtext = b
end

local function view_from(self: Stream, line_from: number)
	local top_line = math.clamp(
		line_from - self.visible_lines + 1,
		0,
		math.max(1, #self.richtext_lines - self.visible_lines) + 1
	)
	local bottom_column = self.richtext_lines[line_from + 1] or self.at
	local top_column = self.richtext_lines[top_line] or 0

	local delta = bottom_column - top_column
	local b = buffer.create(next_pow_of_2(math.max(delta, 1)))
	local at = 0

	local function append(input: buffer)
		b = RESIZE(b, at + buffer.len(input))
		buffer.copy(b, at, input, 0)
		at += buffer.len(input)
	end

	local function write_char(char: number)
		b = RESIZE(b, at + 1)
		buffer.writeu8(b, at, char)
		at += 1
	end

	local function write_tag(tag: Tag)
		if tag.kind == "bgcolor" then
			append(MARK_START)
			append(buffer.fromstring(tag.color:ToHex()))
			write_char(char '"')
			write_char(END_ARROW)
		elseif tag.kind == "bold" then
			append(BOLD_START)
		elseif tag.kind == "color" then
			append(FONT_COLOR_START)
			append(buffer.fromstring(tag.color:ToHex()))
			write_char(char '"')
			write_char(END_ARROW)
		elseif tag.kind == "italic" then
			append(ITALICS_START)
		elseif tag.kind == "strikethrough" then
			append(STRIKETHROUGH_START)
		elseif tag.kind == "underline" then
			append(UNDERLINE_START)
		end
	end

	local function pop_tag(tag: Tag)
		if tag.kind == "bgcolor" then
			append(MARK_STOP)
		elseif tag.kind == "bold" then
			append(BOLD_STOP)
		elseif tag.kind == "color" then
			append(FONT_STOP)
		elseif tag.kind == "italic" then
			append(ITALICS_STOP)
		elseif tag.kind == "strikethrough" then
			append(STRIKETHROUGH_STOP)
		elseif tag.kind == "underline" then
			append(UNDERLINE_STOP)
		end
	end

	if self.start_tags_per_line[top_line] then
		for _, tag in self.start_tags_per_line[top_line] do
			write_tag(tag)
		end
	end

	b = RESIZE(b, at + delta)
	buffer.copy(b, at, self.richtext, top_column, delta)
	at += delta

	for i = #self.active_tags, 1, -1 do
		local active = self.active_tags[i]
		if active.line > bottom_column then break end
		pop_tag(active)
	end

	return buffer.readstring(b, 0, at)
end

local function create_stream(): Stream
	return {
		active_tags = {},
		at = 0,
		chars_left = 120,
		max_line_length = 120,
		richtext = buffer.create(0),
		richtext_lines = { 0 },
		start_tags_per_line = { {} },
		visible_lines = 160,

		write = write,
		getformatted = view_from,
	}
end

return {
	create_stream = create_stream,
	write = write,
	view_from = view_from,
}
