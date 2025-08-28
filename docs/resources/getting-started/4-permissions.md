# Permissions

Setting up permissions and roles in Conch is really simple. In Conch, each role and permission is just a string. Users are given roles, and roles have a list of permissions that they are granted. 

## Basic Setup

In order to set the permissions a role grants, you can use `conch.set_role_permissions` when the server starts (in your server script, after `initiate_default_lifecycle()`):

```luau
-- Define what permissions each role has
conch.set_role_permissions("admin",
	"kick-player",
	"ban-player",
	"teleport-player"
)

conch.set_role_permissions("moderator", 
	"kick-player"
)

conch.set_role_permissions("vip",
	"use-capes",
	"use-server-command"
)
```

## Giving Roles to Players

Roles can then be granted to a user through the `conch.give_roles` function. You'll first need to obtain the user with `conch.get_user`.

```luau
-- Example: Give roles when players join
local function onPlayerAdded(player)
	local user = conch.get_user(player)
	
	-- Give specific roles based on player
	if player.Name == "YourUsername" then
		conch.give_roles(user, "admin")
	elseif player.Name == "ModeratorName" then
		conch.give_roles(user, "moderator")
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
```

This will now give players the appropriate roles, which give them the permissions to use specific commands.

## Command Permissions

It's important to register permissions for each command, as not doing so allows anyone to run that command, even if they just joined.

```luau
conch.register("kick", {
	description = "Kicks a player",
	permissions = { "kick-player" }, -- Only users with this permission can use it
	-- ... rest of command definition
})
```

The permissions you specify here must match what you've granted to roles using `set_role_permissions`.

## Super User

Conch has a special case for the `super-user`, which is a special role that should only be granted to only those you can trust. This role gives the user access to every permission that the developer has registered. When adding a command that allows users to give roles, please explicitly check that this role cannot be given.

```luau
-- Give super-user role for testing (grants ALL permissions)
conch.give_roles(user, "super-user")
```

## Complete Example

Here's how permissions typically work in a complete setup:

```luau
-- In your server script
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local conch = require(ReplicatedStorage.packages.conch)

conch.initiate_default_lifecycle()

-- 1. Define role permissions
conch.set_role_permissions("admin", "kick-player", "ban-player")
conch.set_role_permissions("mod", "kick-player")

-- 2. Register commands with permissions
conch.register("kick", {
	permissions = { "kick-player" }, -- Requires this permission
	-- ... command definition
})

-- 3. Give roles to players
local function onPlayerAdded(player)
	local user = conch.get_user(player)
	
	if player.Name == "YourUsername" then
		conch.give_roles(user, "admin") -- Can use kick command
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
```
