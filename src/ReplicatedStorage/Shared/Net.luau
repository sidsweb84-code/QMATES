--[[
	Net
	Network contract between client and server.

	Client -> Server:  Remotes.Request (RemoteFunction), multiplexed by action name.
	                   Every action has a server-side rate limit defined here.
	Server -> Client:  Remotes.Event (RemoteEvent), multiplexed by event name.
	                   Remotes.Sync (RemoteEvent) carries player data patches.

	The server NEVER trusts arguments: each handler validates types and values.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

-- Rate limits: token bucket with Burst capacity refilled at Rate per second.
Net.Actions = {
	Hello = { Rate = 0.5, Burst = 3 },
	BuyConveyor = { Rate = 4, Burst = 6 },
	CollectCash = { Rate = 3, Burst = 4 },
	LockBase = { Rate = 1, Burst = 2 },
	ClaimBase = { Rate = 1, Burst = 2 },
	StartSteal = { Rate = 1, Burst = 3 },
	CancelSteal = { Rate = 2, Burst = 3 },
	UpgradeBase = { Rate = 3, Burst = 6 },
	UpgradeTrack = { Rate = 3, Burst = 6 },
	LevelUpItem = { Rate = 4, Burst = 8 },
	SellItem = { Rate = 4, Burst = 8 },
	ToggleItemLock = { Rate = 4, Burst = 8 },
	MoveItem = { Rate = 4, Burst = 8 },
	Rebirth = { Rate = 0.5, Burst = 1 },
	ClaimDaily = { Rate = 1, Burst = 2 },
	ClaimPlaytime = { Rate = 2, Burst = 4 },
	ClaimQuest = { Rate = 2, Burst = 4 },
	RerollQuest = { Rate = 1, Burst = 2 },
	ClaimAchievement = { Rate = 2, Burst = 6 },
	ClaimCollectionMilestone = { Rate = 2, Burst = 4 },
	BuyPack = { Rate = 2, Burst = 3 },
	BuyBoost = { Rate = 2, Burst = 3 },
	BuyCosmetic = { Rate = 2, Burst = 3 },
	EquipCosmetic = { Rate = 3, Burst = 6 },
	BuyEventItem = { Rate = 2, Burst = 3 },
	SaveSettings = { Rate = 1, Burst = 3 },
	TutorialSkip = { Rate = 1, Burst = 2 },
	QuickTravel = { Rate = 1, Burst = 2 },
	VisitBase = { Rate = 1, Burst = 2 },
	InspectPlayer = { Rate = 2, Burst = 4 },
	GetLeaderboards = { Rate = 0.5, Burst = 3 },
	TradeRequest = { Rate = 0.5, Burst = 2 },
	TradeRespond = { Rate = 1, Burst = 3 },
	TradeSetItems = { Rate = 4, Burst = 8 },
	TradeReady = { Rate = 2, Burst = 4 },
	TradeCancel = { Rate = 1, Burst = 3 },
	AdminCommand = { Rate = 3, Burst = 6 },
}

-- Server -> client event names.
Net.Events = {
	Notify = "Notify", -- (text, kind, icon?)
	Reveal = "Reveal", -- (revealData)
	Announce = "Announce", -- (text, color, icon?, rarity?)
	Effect = "Effect", -- (effectName, payload)
	Steal = "Steal", -- (state)
	Trade = "Trade", -- (state)
	Tutorial = "Tutorial", -- (step)
	Popup = "Popup", -- (title, lines, icon)
	AdminOutput = "AdminOutput", -- (lines)
}

local remotesFolder: Folder? = nil

local function getRemotes(): Folder
	local cached = remotesFolder
	if cached then
		return cached
	end
	local folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
	remotesFolder = folder
	return folder
end

function Net.GetRequestRemote(): RemoteFunction
	return getRemotes():WaitForChild("Request") :: RemoteFunction
end

function Net.GetEventRemote(): RemoteEvent
	return getRemotes():WaitForChild("Event") :: RemoteEvent
end

function Net.GetSyncRemote(): RemoteEvent
	return getRemotes():WaitForChild("Sync") :: RemoteEvent
end

---------------------------------------------------------------- client API
export type Response = { Ok: boolean, Message: string?, Data: any? }

local listeners: { [string]: { (...any) -> () } } = {}
local listening = false

-- Invoke a server action. Always returns a Response table (never errors).
function Net.Request(action: string, ...: any): Response
	assert(RunService:IsClient(), "Net.Request is client-only")
	local remote = Net.GetRequestRemote()
	local ok, result = pcall(remote.InvokeServer, remote, action, ...)
	if not ok then
		return { Ok = false, Message = "Connection problem — please try again." }
	end
	if type(result) ~= "table" then
		return { Ok = false, Message = "No response" }
	end
	return result
end

-- Subscribe to a server event (client).
function Net.On(eventName: string, callback: (...any) -> ())
	assert(RunService:IsClient(), "Net.On is client-only")
	listeners[eventName] = listeners[eventName] or {}
	table.insert(listeners[eventName], callback)
	if not listening then
		listening = true
		Net.GetEventRemote().OnClientEvent:Connect(function(name, ...)
			local list = listeners[name]
			if list then
				for _, fn in list do
					task.spawn(fn, ...)
				end
			end
		end)
	end
end

return Net
