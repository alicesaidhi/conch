local runtime_plugin_api = require "@self/runtime_plugin_api"

local save_key = if game.GameId == 0
	then `local:{game.Name}`
	else `place:{game.PlaceId}`

runtime_plugin_api.updated_history:Connect(
	function(strings) plugin:SetSetting(save_key, strings) end
)

runtime_plugin_api.set_history(plugin:GetSetting(save_key) or {})
