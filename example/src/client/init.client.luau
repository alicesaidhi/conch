local ReplicatedStorage = game:GetService "ReplicatedStorage"

local conch = require(ReplicatedStorage.packages.conch)
local ui = require(ReplicatedStorage.packages.ui)

ui.mount()
conch.after_command_run(function(result_context) end)
conch.register_default_commands()
conch.initiate_default_lifecycle()
ui.bind_to(Enum.KeyCode.F4)

print "mounted"
