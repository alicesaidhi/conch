--!strict
local types = require "./types"

local function create_signal<T...>(): types.Signal<T...>
	local connections: { types.Connection } = {}
	local signal = {}

	function signal:connect(fn: (T...) -> ())
		local disconnected = false
		local self = { callback = fn }

		local function disconnect()
			if disconnected then return end

			disconnected = true
			self.disconnected = true

			local location = table.find(connections, self)
			if not location then return end
			table.remove(connections, location)
		end

		self.disconnect = disconnect
		table.insert(connections, self)

		return self
	end

	function signal:fire(...: T...)
		for _, connection in connections do
			connection.callback(...)
		end
	end

	return signal :: any
end

return create_signal
