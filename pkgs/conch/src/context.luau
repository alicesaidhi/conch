local state = require "./state"
local types = require "./types"

local function create_command_context(
	user: types.User,
	invocation_id: number | false
)
	assert(
		not state.command_context[coroutine.running()],
		"there is already a command context for this thread"
	)
	state.command_context[coroutine.running()] = {
		executor = user,
		invocation_id = invocation_id,
	}

	return function() state.command_context[coroutine.running()] = nil end
end

local function get_command_context(): types.CommandContext?
	return state.command_context[coroutine.running()]
end

return {
	create_command_context = create_command_context,
	get_command_context = get_command_context,
}
