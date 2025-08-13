local ReplicatedStorage = game:GetService "ReplicatedStorage"

local conch = require(ReplicatedStorage.packages.conch)
local ui = require(ReplicatedStorage.packages.ui)

conch.on_command_run(function(result_context)
	print("user", result_context.who.name, "has executed command on server:", result_context)
end)
conch.register_default_commands()
conch.initiate_default_lifecycle()
ui.bind_to(Enum.KeyCode.F4)

print "mounted"
