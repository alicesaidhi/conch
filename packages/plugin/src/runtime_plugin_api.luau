local plugin_api = require "./plugin_api"

local suitable_version =
	plugin_api.wait_for_first_api "alicesays_hallo/conch-ui"
local api = plugin_api.load(suitable_version)

return api :: {
	set_history: (history: { string }) -> (),
	get_history: () -> { string },
	add: (text: string) -> (),
	updated_history: plugin_api.Signal<{ string }>,
}
