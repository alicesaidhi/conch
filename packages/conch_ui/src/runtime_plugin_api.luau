local plugin_api = require("./plugin_api")
local state = require("./state")

local private = {}
local public = {}

local MAX_SIZE_HISTORY = 500

function public.set_history(history: { string })
	state.history = history
	private.fire_history(state.history)
end

function public.get_history()
	return state.history
end

function public.add(text: string)
	local idx = table.find(state.history, text)
	if idx then
		table.remove(state.history, idx)
	end

	table.insert(state.history, 1, text)

	if #state.history > MAX_SIZE_HISTORY then
		table.remove(state.history)
	end

	private.fire_history(state.history)
end

public.updated_history, private.fire_history = plugin_api.get_signal<<({ string })>>()

return public