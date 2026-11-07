local RunService = game:GetService "RunService"
local UserInputService = game:GetService "UserInputService"

local vide = require "../../roblox_packages/vide"

local source = vide.source
local action = vide.action
local effect = vide.effect
local read = vide.read
local cleanup = vide.cleanup

type GuiState = {
	read enabled: (boolean | () -> boolean)?,
	read hover: ((boolean) -> ())?,
	read hold: ((boolean) -> ())?,
	read input: ((InputObject) -> ())?,
	read clicked: ((InputObject) -> ())?,
	read wheel: ((number) -> ())?,

	keycode: Enum.KeyCode?,
}

return function(p: GuiState)
	local enabled = p.enabled or source(true)
	local input_object = source(nil :: InputObject?)

	effect(function()
		if read(enabled) == false then
			if p.hover then p.hover(false) end
			if p.hold then p.hold(false) end
		end
	end)

	local function input_ended(input: InputObject)
		if not read(enabled) or input ~= input_object() then return end
		input_object(nil)
		if p.hold then p.hold(false) end
		if p.input then p.input(input) end
	end

	local function input_began(input: InputObject)
		if
			input.KeyCode ~= p.keycode
			and input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		if
			not read(enabled)
			or input.UserInputState ~= Enum.UserInputState.Begin
		then
			return
		end
		input_object(input)
		if p.hold then p.hold(true) end
		if p.input then p.input(input) end

		local connection: RBXScriptConnection
		connection = RunService.Heartbeat:Connect(function(dt)
			if p.input then p.input(input) end
			if input_object() ~= input then
				input_ended(input)
				connection:Disconnect()
			end
		end)
	end

	local function input_changed(input: InputObject)
		if not read(enabled) or input ~= input_object() then return end
		assert(p.input)
		p.input(input)
	end

	return action(function(instance)
		assert(instance:IsA "GuiButton", "instance has no input events")

		cleanup(instance.InputBegan:Connect(input_began))
		cleanup(instance.InputEnded:Connect(input_ended))
		cleanup(UserInputService.InputEnded:Connect(input_ended))
		effect(function() instance.Active = read(enabled) end)
		if p.clicked then
			local clicked = p.clicked
			cleanup(instance.Activated:Connect(clicked))

			if p.keycode then
				cleanup(UserInputService.InputBegan:Connect(function(input, gs)
					if gs then return end
					if input.KeyCode == p.keycode then clicked(input) end
				end))
			end
		end

		if p.input then
			cleanup(instance.InputChanged:Connect(input_changed))
		end

		if p.wheel then
			local wheel = p.wheel

			cleanup(
				instance.MouseWheelForward:Connect(function() wheel(-1) end)
			)
			cleanup(
				instance.MouseWheelBackward:Connect(function() wheel(1) end)
			)
		end

		if p.hover then
			local hover = p.hover
			cleanup(instance.MouseEnter:Connect(function()
				if read(enabled) == false then return end
				hover(true)
			end))
			cleanup(instance.MouseLeave:Connect(function()
				if read(enabled) == false then return end
				hover(false)
			end))
		end
	end)
end
