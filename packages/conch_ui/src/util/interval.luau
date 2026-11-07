local RunService = game:GetService "RunService"

local vide = require "../../roblox_packages/vide"

local cleanup = vide.cleanup

return function<T>(t: number, fn: (number) -> T): () -> T
	local value = vide.source(fn(0))
	local accumulate = 0

	cleanup(RunService.Heartbeat:Connect(function(dt)
		accumulate += dt
		if accumulate > t then
			value(fn(accumulate))
			accumulate = 0
		end
	end))

	return value
end
