local RunService = game:GetService "RunService"

local interval = require "../util/interval"
local vide = require "../../roblox_packages/vide"

local t = 0
local steps = { "-", "/", "|", "\\" }

local value = vide.source(steps[1])

local accumulate = 0
RunService.Heartbeat:Connect(function(dt)
	accumulate += dt
	if accumulate > 0.25 then
		t += 1
		value(steps[t % 4 + 1])
		accumulate = 0
	end
end)

return value
