local Players = game:GetService "Players"
local ReplicatedStorage = game:GetService "ReplicatedStorage"

local conch = require(ReplicatedStorage.packages.conch)

-- IMPORTANT: Initialize the lifecycle FIRST
conch.initiate_default_lifecycle()

-- Set up permissions for different roles
conch.set_role_permissions("admin", "kick-player", "teleport-player")
conch.set_role_permissions("moderator", "kick-player")

-- Register a simple command using register_quick
conch.register_quick("meow", function()
	conch.log("normal", "mraooow")
	return true
end)

-- Register a more complex command with proper arguments and permissions
conch.register("kick", {
	description = "Kicks the given player from the server",
	permissions = { "kick-player" },
	arguments = function()
		return
			conch.args.player("player", "The player to kick"),
			conch.args.string("reason", "Reason for kick")
	end,
	callback = function(player, reason)
		player:Kick(reason)
	end
})

-- Example teleport command
conch.register("tp", {
	description = "Teleports you to another player",
	permissions = { "teleport-player" },
	arguments = function()
		return conch.args.player("target", "Player to teleport to")
	end,
	callback = function(target)
		local context = conch.get_command_context()
		local executor = context.executor.player
		if executor and executor.Character and target.Character then
			executor.Character.HumanoidRootPart.CFrame = target.Character.HumanoidRootPart.CFrame
		end
	end
})

-- Example command with no permissions (anyone can use)
conch.register("ping", {
	description = "Responds with pong",
	permissions = {}, -- No permissions required
	arguments = function() return end,
	callback = function()
		conch.log("normal", "Pong!")
	end
})

-- Log when commands are executed
conch.on_execution(
	function(who, what) print("user", who, "has executed", what) end
)

conch.on_command_run(
	function(result_context)
		print(
			"user",
			result_context.who.name,
			"has executed command on server:",
			result_context
		)
	end
)

local function playeradded(player: Player)
	local user = conch.get_user(player)

	conch.give_roles(user, "super-user")
end

Players.PlayerAdded:Connect(playeradded)
for _, player in Players:GetPlayers() do
	playeradded(player)
end
