local ReplicatedStorage = game:GetService "ReplicatedStorage"

-- Require both conch packages
local conch = require(ReplicatedStorage.packages.conch)
local ui = require(ReplicatedStorage.packages.ui)

-- Initialize the lifecycle first
conch.initiate_default_lifecycle()

-- Register default commands (license, print, info, warn, error)
conch.register_default_commands()

-- Set up command execution logging
conch.on_command_run(function(result_context)
	print("user", result_context.who.name, "has executed command:", result_context.command)
end)

-- Bind the console to F4 key
ui.bind_to(Enum.KeyCode.F4)

print("Conch client mounted - Press F4 to open console")
