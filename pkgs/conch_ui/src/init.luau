local Players = game:GetService "Players"
local TextChatService = game:GetService "TextChatService"
local UserInputService = game:GetService "UserInputService"

local app = require "@self/app"
local conch = require "./roblox_packages/conch"
local plugin_api = require "@self/plugin_api"
local runtime_plugin_api = require "@self/runtime_plugin_api"
local state = require "@self/state"
local theme = require "@self/theme"
local version = require "@self/api_version"
local vide = require "./roblox_packages/vide"

local mounted = false
local opened, focused = state.opened, state.focused

local function mount()
	if mounted then return end
	mounted = true
	return vide.mount(app, Players.LocalPlayer:WaitForChild "PlayerGui")
end

local function bind_to(input: Enum.KeyCode | Enum.UserInputType)
	mount()
	UserInputService.InputBegan:Connect(function(input_object)
		if
			input_object.KeyCode ~= input
			and input_object.UserInputType ~= input
		then
			return
		end
		opened(not opened())
		focused(opened())
	end)
end

local function bind_to_chat(primary: string, secondary: string?)
	mount()

	local command = Instance.new "TextChatCommand"
	command.Name = "Conch"
	command.PrimaryAlias = primary
	command.SecondaryAlias = secondary or ""
	command.Triggered:Connect(function()
		opened(true)
		focused(true)
	end)
	command.Parent = TextChatService
end

local function on_history_changed(callback: (history: { string }) -> ())
	local listeners: { ({ string }) -> () } =
		runtime_plugin_api.updated_history :: any
	local function listener(history: { string }) task.spawn(callback, history) end
	table.insert(listeners, listener)

	return function()
		local index = table.find(listeners, listener)
		if index then table.remove(listeners, index) end
	end
end

plugin_api.expose(version, "alicesays_hallo/conch-ui", runtime_plugin_api)

return {
	alignment = state.alignment,
	theme = theme,
	focused = state.focused,

	app = app,
	mount = mount,
	opened = opened,

	bind_to = bind_to,
	bind_to_chat = bind_to_chat,

	get_history = runtime_plugin_api.get_history,
	set_history = runtime_plugin_api.set_history,
	on_history_changed = on_history_changed,

	conch = conch,
}
