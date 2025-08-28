# Troubleshooting

Common issues and solutions when setting up and using Conch.

## Commands Not Appearing

**Problem:** Commands I registered don't show up in the console.

**Solutions:**
1. **Check initialization order** - Make sure you call `conch.initiate_default_lifecycle()` BEFORE registering commands:
   ```luau
   -- ✅ Correct order
   conch.initiate_default_lifecycle()
   conch.register("mycommand", { ... })
   
   -- ❌ Wrong order
   conch.register("mycommand", { ... })
   conch.initiate_default_lifecycle()
   ```

2. **Verify permissions** - Commands only appear if you have the required permissions:
   ```luau
   -- Give yourself admin permissions for testing
   local user = conch.get_user(Players.LocalPlayer)
   conch.give_roles(user, "super-user") -- Gives access to all commands
   ```

3. **Check script location** - Commands should be registered in a **ServerScript** in **ServerScriptService**

4. **Ensure packages are loaded** - Verify that conch packages are in ReplicatedStorage and accessible

## Console Not Opening

**Problem:** Pressing F4 (or your hotkey) doesn't open the console.

**Solutions:**
1. **Check client script location** - The client script must be in `StarterPlayer/StarterPlayerScripts`

2. **Verify UI package** - Make sure `conch_ui` is required and `bind_to` is called:
   ```luau
   local ui = require(ReplicatedStorage.packages.conch_ui)
   ui.bind_to(Enum.KeyCode.F4)
   ```

3. **Try a different key** - Some keys might be blocked by Roblox:
   ```luau
   ui.bind_to(Enum.KeyCode.F3) -- Try F3 instead
   ```

## Access Denied Errors

**Problem:** Getting "Access denied" when trying to run commands.

**Solutions:**
1. **Give yourself permissions** - You need the required role/permissions:
   ```luau
   local user = conch.get_user(player)
   conch.give_roles(user, "admin") -- Or whatever role has the permission
   ```

2. **Use super-user for testing** - This role bypasses all permission checks:
   ```luau
   conch.give_roles(user, "super-user")
   ```

3. **Check permission names** - Make sure command permissions match your roles:
   ```luau
   -- Command requires "kick-player" permission
   conch.register("kick", {
       permissions = { "kick-player" },
       -- ...
   })
   
   -- Role must have that permission
   conch.set_role_permissions("admin", "kick-player")
   ```

## Commands Work in Studio But Not in Game

**Problem:** Everything works in Roblox Studio but fails in published games.

**Solutions:**
1. **Check script locations** - Ensure scripts are in the correct services:
   - Server commands: `ServerScriptService`
   - Client setup: `StarterPlayer/StarterPlayerScripts`

2. **Verify package locations** - Packages should be in `ReplicatedStorage` so both client and server can access them

3. **Review permissions** - Make sure permission assignment logic works for all players, not just in Studio

## Server Commands Not Working

**Problem:** Commands run but don't seem to do anything on the server.

**Solutions:**
1. **Check script context** - Server commands must be registered in server scripts:
   ```luau
   -- This should be in a ServerScript, not LocalScript
   conch.register("kick", {
       callback = function(player, reason)
           player:Kick(reason) -- Server-side action
       end
   })
   ```

2. **Use command context** - Access the executing player with `get_command_context()`:
   ```luau
   callback = function(target)
       local context = conch.get_command_context()
       local executor = context.executor.player
       -- executor is the player who ran the command
   end
   ```

## Package Import Errors

**Problem:** Can't require conch packages or getting "not found" errors.

**Solutions:**
1. **Check package location** - Packages should be accessible to both client and server:
   ```
   ReplicatedStorage/
   ├── packages/
   │   ├── conch/
   │   └── conch_ui/
   ```

2. **Use correct require path**:
   ```luau
   local conch = require(ReplicatedStorage.packages.conch)
   local ui = require(ReplicatedStorage.packages.conch_ui)
   ```

3. **Wait for packages** (if needed):
   ```luau
   local packages = ReplicatedStorage:WaitForChild("packages")
   local conch = require(packages:WaitForChild("conch"))
   ```

## Still Having Issues?

1. **Check the example** - Look at the complete working example in [Custom Commands](/resources/getting-started/5-custom-commands#complete-working-example)

2. **Review setup guide** - Make sure you followed all steps in [Setting Up](/resources/getting-started/3-setting-up)

3. **Join the community** - Ask for help on the project's GitHub discussions or issues page

4. **Enable debugging** - Add print statements to verify your scripts are running:
   ```luau
   print("Conch server script loaded!")
   conch.initiate_default_lifecycle()
   print("Lifecycle initiated!")
   ```