local types = require "./types"

return {
	--- The local user of the client. When false, the client does not have an user
	--- associated with them and cannot run any commands.
	local_user = false :: types.UserPublic | false,
	--- Maps roles to an array of permissions.
	roles = {} :: { [types.Role]: { types.Permission } },

	--- Maps the user id to a User. This is used on the server to keep track of
	--- each player's user.
	users = {} :: { [string]: types.User },
	--- Stores the executing command for each thread, and information about it.
	command_context = {} :: { [thread]: types.CommandContext },
	--- Stores a continuation for a u32.
	continuations = {} :: { [number]: thread },
}
