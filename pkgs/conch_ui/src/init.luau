local Players = game:GetService "Players"
local UserInputService = game:GetService "UserInputService"

local app = require "@self/app"
local conch = require "./roblox_packages/conch"
local state = require "@self/state"
local theme = require "@self/theme"
local vide = require "./roblox_packages/vide"

local mounted = false
local opened, focused = state.opened, state.focused

local function mount()
	if mounted then return end
	mounted = true
	return vide.mount(app, Players.LocalPlayer:WaitForChild "PlayerGui")
end

local function bind_to(input: Enum.KeyCode | Enum.UserInputType)
	mount()
	UserInputService.InputBegan:Connect(function(input_object)
		if
			input_object.KeyCode ~= input
			and input_object.UserInputType ~= input
		then
			return
		end
		opened(not opened())
		focused(opened())
	end)
end

return {
	alignment = state.alignment,
	theme = theme,
	focused = state.focused,

	app = app,
	mount = mount,
	opened = opened,

	bind_to = bind_to,

	conch = conch,
}
