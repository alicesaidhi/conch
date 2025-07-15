local vide = require "../../roblox_packages/vide"

local create = vide.create

type Can<T> = T | () -> T
type ScreenGui = {
	read name: Can<string>?,
	read enabled: Can<boolean>?,
	read display_order: Can<number>?,

	[number]: unknown,
}

return function(props: ScreenGui)
	return create "ScreenGui" {
		Name = props.name,
		Enabled = props.enabled,
		DisplayOrder = props.display_order,

		unpack(props),
	}
end
