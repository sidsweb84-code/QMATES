--[[
	Signal
	Lightweight signal implementation (no BindableEvents, no instance churn).
]]

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

function Connection.new(signal, callback)
	return setmetatable({ Connected = true, _signal = signal, _callback = callback }, Connection)
end

function Connection:Disconnect()
	if not self.Connected then
		return
	end
	self.Connected = false
	local list = self._signal._connections
	local index = table.find(list, self)
	if index then
		table.remove(list, index)
	end
end

function Signal.new()
	return setmetatable({ _connections = {} }, Signal)
end

function Signal:Connect(callback: (...any) -> ())
	local connection = Connection.new(self, callback)
	table.insert(self._connections, connection)
	return connection
end

function Signal:Once(callback: (...any) -> ())
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		callback(...)
	end)
	return connection
end

function Signal:Fire(...: any)
	-- Copy so listeners can disconnect while firing.
	local snapshot = table.clone(self._connections)
	for _, connection in snapshot do
		if connection.Connected then
			task.spawn(connection._callback, ...)
		end
	end
end

-- Fires synchronously (no task.spawn). Errors propagate to the caller.
function Signal:FireSync(...: any)
	local snapshot = table.clone(self._connections)
	for _, connection in snapshot do
		if connection.Connected then
			connection._callback(...)
		end
	end
end

function Signal:Wait(): ...any
	local thread = coroutine.running()
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:DisconnectAll()
	for _, connection in table.clone(self._connections) do
		connection.Connected = false
	end
	table.clear(self._connections)
end

return Signal
