local ReplicatedStorage = game:GetService("ReplicatedStorage")

local vide = require(ReplicatedStorage.packages.vide)

local read = vide.read

type Can<T> = T | () -> T

local function conditional<T>(fn: unknown, a: T, b: T)
	return function()
		return if read(fn) then read(a) else read(b)
	end
end

return conditional
