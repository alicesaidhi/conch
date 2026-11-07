local component = require "../../util/component"
local container = require "../core/container"
local theme = require "../../theme"

type Can<T> = T | () -> T
return component(
	function(
		p: {
			-- frame properties
			color: Can<Color3>?,
			transparency: Can<number>?,

			-- stroke properties
			stroke: Can<Color3>?,
			stroke_transparency: Can<number>?,
			thickness: Can<number>?,

			-- corner properties
			corner: Can<number>?,

			-- image properties
			image: {
				src: Can<Content | string>,
				rect_offset: Can<Vector2>?,
				rect_size: Can<Vector2>?,

				pixelated: Can<boolean>?,
				slice_center: Can<Rect>?,
				slice_scale: Can<number>?,
				tw: Can<number>?,
				th: Can<number>?,
				scale_type: Can<Enum.ScaleType>?,
			}?,
			tile_scale: Can<number>?,

			-- general properties
			clips: Can<boolean>?,

			-- input properties
			keycode: Enum.KeyCode?,
			sink: Can<boolean>?,
			enabled: Can<boolean>?,
			hover: ((boolean) -> ())?,
			hold: ((boolean) -> ())?,
			input: ((InputObject) -> ())?,
			clicked: ((InputObject) -> ())?,
			wheel: ((number) -> ())?,

			[any]: any,
		}
	)
		return container {
			color = p.color or theme.background,
			transparency = p.transparency or theme.background_transparency,

			stroke = p.stroke,
			stroke_transparency = p.stroke_transparency,
			thickness = p.thickness,

			corner = p.corner,

			image = p.image,
			tile_scale = p.tile_scale,

			clips = p.clips,
			keycode = p.keycode,
			sink = p.sink,
			enabled = p.enabled,
			hover = p.hover,
			hold = p.hold,
			input = p.input,
			clicked = p.clicked,
			wheel = p.wheel,

			unpack(p),
		}
	end
)
