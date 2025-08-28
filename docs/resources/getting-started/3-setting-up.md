# Setting Up

This guide walks you through setting up Conch in your Roblox game, including where to place scripts and how to register your first commands.

## File Structure

Before we begin, make sure your packages are set up correctly:

```
ReplicatedStorage/
├── packages/
│   ├── conch/
│   └── ui/
```

You'll need two scripts:
- **Server Script** (in ServerScriptService) - handles command registration and server-side logic
- **Client Script** (in StarterPlayer/StarterPlayerScripts) - handles the UI and client-side functionality

## Server Setup

Create a **ServerScript** in `ServerScriptService` (e.g., `ConchSetup.server.luau`):

```luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Require Conch
local conch = require(ReplicatedStorage.packages.conch)

-- STEP 1: Initialize the default lifecycle
conch.initiate_default_lifecycle()

-- STEP 2: Set up permissions (optional but recommended)
conch.set_role_permissions("admin", "kick-player", "ban-player")
conch.set_role_permissions("moderator", "kick-player")

-- STEP 3: Register your commands AFTER initiate_default_lifecycle()
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

-- STEP 4: Give permissions to players when they join
local function onPlayerAdded(player)
	local user = conch.get_user(player)
	
	-- Example: Give admin role to specific players
	if player.Name == "YourUsername" then
		conch.give_roles(user, "admin")
	end
	
	-- Or give super-user role for testing (gives access to all commands)
	-- conch.give_roles(user, "super-user")
end

Players.PlayerAdded:Connect(onPlayerAdded)

-- Handle players already in the game
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
```

## Client Setup

Create a **LocalScript** in `StarterPlayer/StarterPlayerScripts` (e.g., `ConchClient.client.luau`):

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Require Conch packages
local conch = require(ReplicatedStorage.packages.conch)
local ui = require(ReplicatedStorage.packages.ui)

-- Initialize the default lifecycle
conch.initiate_default_lifecycle()

-- Bind the console to a key (F4 by default)
ui.bind_to(Enum.KeyCode.F4)
```

## Testing Your Setup

1. **Start your game** - both scripts should run automatically
2. **Press F4** (or your chosen hotkey) to open the console
3. **Type your command** - e.g., `kick PlayerName reason here`
4. **Check permissions** - make sure you've given yourself the required roles

## Troubleshooting

**Q: My commands don't appear in the console**
- Make sure you called `conch.initiate_default_lifecycle()` BEFORE registering commands
- Ensure you have the required permissions for the command
- Check that your server script is actually running

**Q: Console doesn't open when I press the key**
- Verify the client script is in StarterPlayerScripts
- Make sure both packages are correctly placed in ReplicatedStorage
- Try a different key binding

**Q: "Access denied" when running commands**
- You need to give yourself the required permission/role
- Use `conch.give_roles(user, "super-user")` for testing (gives all permissions)

**Q: Commands work in Studio but not in-game**
- Double-check that all scripts are in the correct locations
- Ensure packages are published/synced properly

## Next Steps

- Learn about [Permissions](/resources/getting-started/4-permissions) to control who can use which commands
- Read [Custom Commands](/resources/getting-started/5-custom-commands) for advanced command registration
