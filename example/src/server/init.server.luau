local Players = game:GetService "Players"
local ReplicatedStorage = game:GetService "ReplicatedStorage"

local conch = require(ReplicatedStorage.packages.conch)

conch.initiate_default_lifecycle()

conch.register_quick("meow", function()
	conch.log("normal", "mraooow")
	return true
end)

conch.register("test", {
	description = nil :: string?,
	permissions = { "command" },
	arguments = function() return conch.args.player() end,

	callback = function(player) end :: (Player) -> ...any,
})

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
