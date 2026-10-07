--[[
	State
	Read-only client mirror of the player's server data.
	- Hello: requests a full snapshot (retries until the server has our data).
	- Sync: applies sequenced patches; patches that arrive before the snapshot
	  are buffered, stale ones are dropped.
	UI code reads State.Data / State.Session and subscribes with State.On(key, fn).
	Nothing here is trusted by the server.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)

local State = {}

State.Data = {} :: { [string]: any }
State.Session = {} :: { [string]: any }
State.Server = {} :: { [string]: any }
State.Loaded = false
State.LoadedSignal = Signal.new()
State.ChangedSignal = Signal.new() -- (key, isSession)

local seq = 0
local buffered: { { Seq: number, Patch: any } } = {}
local listeners: { [string]: { (any) -> () } } = {}

local function emit(key: string, value: any, isSession: boolean)
	State.ChangedSignal:Fire(key, isSession)
	local list = listeners[key]
	if list then
		for _, fn in list do
			task.spawn(fn, value)
		end
	end
end

local function applyPatch(patch)
	for key, value in patch.Data or {} do
		State.Data[key] = value
		emit(key, value, false)
	end
	for key, value in patch.Session or {} do
		State.Session[key] = value
		emit(key, value, true)
	end
end

-- Subscribe to a data or session key. Fires immediately if already loaded.
function State.On(key: string, callback: (any) -> ())
	listeners[key] = listeners[key] or {}
	table.insert(listeners[key], callback)
	if State.Loaded then
		local value = State.Data[key]
		if value == nil then
			value = State.Session[key]
		end
		task.spawn(callback, value)
	end
	return function()
		local list = listeners[key]
		local index = list and table.find(list, callback)
		if index then
			table.remove(list, index)
		end
	end
end

function State.Get(key: string): any
	local value = State.Data[key]
	if value == nil then
		return State.Session[key]
	end
	return value
end

function State.Start()
	Net.GetSyncRemote().OnClientEvent:Connect(function(patchSeq: number, patch)
		if not State.Loaded then
			table.insert(buffered, { Seq = patchSeq, Patch = patch })
			return
		end
		if patchSeq <= seq then
			return
		end
		seq = patchSeq
		applyPatch(patch)
	end)

	task.spawn(function()
		while not State.Loaded do
			local response = Net.Request("Hello")
			if response.Ok and type(response.Data) == "table" then
				local snapshot = response.Data
				State.Data = snapshot.Data or {}
				State.Session = snapshot.Session or {}
				State.Server = snapshot.Server or {}
				seq = snapshot.Seq or 0
				State.Loaded = true
				table.sort(buffered, function(a, b)
					return a.Seq < b.Seq
				end)
				for _, entry in buffered do
					if entry.Seq > seq then
						seq = entry.Seq
						applyPatch(entry.Patch)
					end
				end
				table.clear(buffered)
				State.LoadedSignal:Fire()
				for key, value in State.Data do
					emit(key, value, false)
				end
				for key, value in State.Session do
					emit(key, value, true)
				end
				break
			end
			task.wait(1.5)
		end
	end)
end

function State.WaitForLoad()
	if not State.Loaded then
		State.LoadedSignal:Wait()
	end
end

return State
