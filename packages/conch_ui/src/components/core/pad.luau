local vide = require "../../../roblox_packages/vide"

local create = vide.create
local read = vide.read

type Can<T> = T | () -> T
export type Pad = {

	l: Can<number>?,
	t: Can<number>?,
	b: Can<number>?,
	r: Can<number>?,

	ls: Can<number>?,
	ts: Can<number>?,
	bs: Can<number>?,
	rs: Can<number>?,

	x: Can<number>?,
	y: Can<number>?,

	xs: Can<number>?,
	ys: Can<number>?,

	p: Can<number>?,

	ps: Can<number>?,
}

return function(props: Pad)
	local p = props.p or 0
	local x = props.x or p
	local y = props.y or p

	local l = props.l or x
	local t = props.t or y
	local b = props.b or y
	local r = props.r or x

	local ps = props.ps or 0
	local xs = props.xs or ps
	local ys = props.ys or ps

	local ls = props.ls or xs
	local ts = props.ts or ys
	local bs = props.bs or ys
	local rs = props.rs or xs

	return create("UIPadding" :: "UIPadding") {
		PaddingLeft = function() return UDim.new(read(ls), read(l)) end,
		PaddingRight = function() return UDim.new(read(rs), read(r)) end,
		PaddingTop = function() return UDim.new(read(ts), read(t)) end,
		PaddingBottom = function() return UDim.new(read(bs), read(b)) end,
	}
end
