# Custom Commands

After setting up permissions, you'll probably need to setup commands. By default, Conch only comes with logging commands and the license. Setting up your own commands is incredibly easy though, on both the server and client.

## Prerequisites

Before registering commands, make sure you have:

1. **Completed the basic setup** - see [Setting Up](/resources/getting-started/3-setting-up)
2. **Called `conch.initiate_default_lifecycle()`** in your server script
3. **Set up permissions** for your commands (optional but recommended)

## Registering Commands

Commands should be registered in your **server script** (in ServerScriptService), **after** calling `initiate_default_lifecycle()`.

Let's create a simple `kick` command on the server to kick users out of the server. We can use `conch.register` to register a new command. This accepts a name, and then a table containing details about the command.

```luau
-- In your server script, after conch.initiate_default_lifecycle()
conch.register("kick", {

})
```

You'll need to pass the arguments that you want to pass to the command, the permissions necessary to execute the command and the callback to run when executing the command.

```luau
conch.register("kick", {
	permissions = { "kick-player" },
	arguments = function()
		return conch.args.player(), conch.args.string()
	end,

	callback = function(player, reason) -- typechecked!
		player:Kick(reason)
	end
})
```

We can also optionally add information to what the arguments and command actually entails by providing a description to the command and/or adding names and descriptions to each of the arguments!

```luau
conch.register("kick", {
	description = "Kicks the given player from the server",
	permissions = { "kick-player" },
	arguments = function()
		return
			conch.args.player("player", "The player that should be kicked from the server"),
			conch.args.string("reason", "The reason why the player has been kicked from the user.")
	end,

	callback = function(player, reason) -- typechecked!
		player:Kick(reason)
	end
})
```

With this setup, any player that has the `kick-player` permission will be able to run the `kick` command.

It's possible to also register commands quickly, by using the `conch.register_quick` function. This removes the ability to specify arguments which are useful for analysis, but is useful for when you need to quickly make a function accessible. You can pass the permissions required after the function.

```luau
conch.register_quick("kick", function(player_name, reason)
	local player = Players:FindFirstChild(player_name)
	if not player then error(`{player_name} is not a real player`) end
	player:Kick(reason)
end, "kick-player")
```

## Complete Working Example

Here's a complete server script that demonstrates command registration:

```luau
-- ServerScript in ServerScriptService
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local conch = require(ReplicatedStorage.packages.conch)

-- IMPORTANT: Initialize first
conch.initiate_default_lifecycle()

-- Set up permissions
conch.set_role_permissions("admin", "kick-player", "teleport-player")

-- Register commands AFTER initiate_default_lifecycle()
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

conch.register("tp", {
	description = "Teleports you to another player",
	permissions = { "teleport-player" },
	arguments = function()
		return conch.args.player("target", "Player to teleport to")
	end,
	callback = function(target)
		local context = conch.get_command_context()
		local executor = context.executor.player
		if executor then
			executor.Character.HumanoidRootPart.CFrame = target.Character.HumanoidRootPart.CFrame
		end
	end
})

-- Give permissions to players
local function onPlayerAdded(player)
	local user = conch.get_user(player)
	
	-- Give admin role to yourself (replace with your username)
	if player.Name == "YourUsernameHere" then
		conch.give_roles(user, "admin")
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
```

## Troubleshooting Commands

**Commands don't appear in console:**
- Ensure `conch.initiate_default_lifecycle()` is called before registering commands
- Check that you have the required permissions/roles
- Verify your server script is running

**"Access denied" when running commands:**
- Make sure you've given yourself the required permissions
- Try using `conch.give_roles(user, "super-user")` for testing

**Commands work in Studio but not in published games:**
- Double-check script locations (ServerScriptService for server commands)
- Ensure packages are properly synced/published
