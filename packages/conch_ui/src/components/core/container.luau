local component = require "../../util/component"
local guistate = require "../../util/guistate"
local vide = require "../../../roblox_packages/vide"

type Can<T> = T | () -> T

return component(function(
	p: {
		-- frame properties
		color: Can<Color3>?,
		transparency: Can<number>?,
		scaling: boolean?,

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
	},
	_
)
	local properties: any = {}
	local tile_scale = p.tile_scale or 1

	if p.image then
		local has_tile_size = p.image.tw or p.image.th

		properties = {
			Image = p.image.src,
			ImageColor3 = p.color,
			ImageTransparency = p.transparency or 0,
			ScaleType = p.image.scale_type or Enum.ScaleType.Stretch,
			ResampleMode = if p.image.pixelated
				then Enum.ResamplerMode.Pixelated
				else Enum.ResamplerMode.Default,

			ImageRectOffset = p.image.rect_offset,
			ImageRectSize = p.image.rect_size,
			SliceCenter = p.image.slice_center,
			SliceScale = p.image.slice_scale,
			TileSize = if has_tile_size
				then function()
					return UDim2.fromOffset(
						math.max(
							vide.read(p.image.tw or 1)
								* vide.read(tile_scale)
								// 1,
							1
						),
						math.max(
							vide.read(p.image.th or 1)
								* vide.read(tile_scale)
								// 1,
							1
						)
					)
				end
				else UDim2.fromOffset(1, 1),
			BackgroundTransparency = 1,
			AutoLocalize = false,
			ClipsDescendants = p.clips,
		}
	else
		properties = {
			BackgroundColor3 = p.color,
			BorderSizePixel = 0,
			BackgroundTransparency = p.transparency or if p.color then 0 else 1,
			ClipsDescendants = p.clips,
		}
	end

	if p.sink ~= nil then properties.Active = p.sink end

	local interactable = p.clicked or p.hold or p.hover or p.input or p.wheel

	if interactable then
		table.insert(properties, {
			AutoButtonColor = false,

			guistate(p),
		})
	end

	if p.stroke then
		table.insert(
			properties,
			vide.create("UIStroke" :: "UIStroke") {
				Color = p.stroke,
				Transparency = p.stroke_transparency,
				Thickness = function() return vide.read(p.thickness or 1) end,
			}
		)
	end

	if p.corner then -- i dont get it but ok
		table.insert(
			properties :: { any },
			vide.create "UICorner" {
				CornerRadius = function()
					return UDim.new(0, vide.read(p.corner))
				end,
			} :: any
		)
	end

	local element = if vide.read(p.image) and interactable
		then "ImageButton"
		elseif vide.read(p.image) and not interactable then "ImageLabel"
		elseif interactable then "ImageButton"
		else "Frame"

	return (vide.create :: any)(element)(properties) :: Instance
end)
