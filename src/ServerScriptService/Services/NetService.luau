--[[
	NetService
	Server side of the network contract (Shared/Net).
	- Dispatches Remotes.Request to registered handlers.
	- Enforces per-action rate limits and catches handler errors.
	- Provides helpers to fire events, notifications and announcements.

	Handlers return (ok: boolean, message: string?, data: any?).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MessagingService = game:GetService("MessagingService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local GameConfig = require(Shared.Config.GameConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local MutationConfig = require(Shared.Config.MutationConfig)
local Catalog = require(Shared.Catalog)

local Modules = script.Parent.Parent.Modules
local Registry = require(Modules.Registry)
local Log = require(Modules.Log)

local NetService = {}

type Handler = (player: Player, ...any) -> (boolean?, any?, any?)

local handlers: { [string]: Handler } = {}
local requestRemote: RemoteFunction
local eventRemote: RemoteEvent

-- Actions allowed before the player's data has loaded.
local PRE_LOAD_ACTIONS = { Hello = true }

function NetService:Handle(action: string, handler: Handler)
	assert(Net.Actions[action], "Unknown action " .. action .. " (add it to Net.Actions)")
	assert(handlers[action] == nil, "Duplicate handler for " .. action)
	handlers[action] = handler
end

function NetService:HasHandler(action: string): boolean
	return handlers[action] ~= nil
end

local function dispatch(player: Player, action: any, ...): any
	if type(action) ~= "string" or Net.Actions[action] == nil or handlers[action] == nil then
		Registry.AntiExploitService:Flag(player, "InvalidArgs", "unknown action " .. tostring(action))
		return { Ok = false, Message = "Unknown request" }
	end
	if not Registry.AntiExploitService:CheckRate(player, action) then
		return { Ok = false, Message = "Slow down!" }
	end
	if not PRE_LOAD_ACTIONS[action] and not Registry.DataService:IsLoaded(player) then
		return { Ok = false, Message = "Still loading your data..." }
	end
	local results = table.pack(pcall(handlers[action], player, ...))
	if not results[1] then
		Log.Error("Net", string.format("%s failed for %s: %s", action, player.Name, tostring(results[2])), player.UserId)
		return { Ok = false, Message = "Something went wrong. Please try again." }
	end
	return { Ok = results[2] == true, Message = results[3], Data = results[4] }
end

function NetService:Init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	requestRemote = remotes:WaitForChild("Request") :: RemoteFunction
	eventRemote = remotes:WaitForChild("Event") :: RemoteEvent
	requestRemote.OnServerInvoke = dispatch
	-- Clients never fire these RemoteEvents; anything they send is ignored.
	eventRemote.OnServerEvent:Connect(function(player)
		Registry.AntiExploitService:Flag(player, "InvalidArgs", "fired server-only Event remote")
	end)
	local sync = remotes:WaitForChild("Sync") :: RemoteEvent
	sync.OnServerEvent:Connect(function(player)
		Registry.AntiExploitService:Flag(player, "InvalidArgs", "fired server-only Sync remote")
	end)
end

function NetService:Start()
	if GameConfig.Announcements.CrossServerEnabled and not RunService:IsStudio() then
		task.spawn(function()
			local ok, err = pcall(function()
				MessagingService:SubscribeAsync(GameConfig.Announcements.CrossServerTopic, function(message)
					local payload = message.Data
					if type(payload) ~= "table" or payload.JobId == game.JobId then
						return
					end
					if type(payload.Text) == "string" and #payload.Text < 200 then
						NetService:FireAll(Net.Events.Announce, "🌍 " .. payload.Text, nil, "🌍", payload.Rarity)
					end
				end)
			end)
			if not ok then
				Log.Warn("Net", "Cross-server announcements unavailable: " .. tostring(err))
			end
		end)
	end
end

function NetService:Fire(player: Player, eventName: string, ...: any)
	if typeof(player) == "Instance" and player.Parent then
		eventRemote:FireClient(player, eventName, ...)
	end
end

function NetService:FireAll(eventName: string, ...: any)
	eventRemote:FireAllClients(eventName, ...)
end

function NetService:FireOthers(except: Player, eventName: string, ...: any)
	for _, p in Players:GetPlayers() do
		if p ~= except then
			eventRemote:FireClient(p, eventName, ...)
		end
	end
end

-- kind: "Success" | "Error" | "Info" | "Warning" | "Reward"
function NetService:Notify(player: Player, text: string, kind: string?, icon: string?)
	self:Fire(player, Net.Events.Notify, text, kind or "Info", icon)
end

function NetService:NotifyAll(text: string, kind: string?, icon: string?)
	self:FireAll(Net.Events.Notify, text, kind or "Info", icon)
end

function NetService:Announce(text: string, color: Color3?, icon: string?, rarity: string?)
	self:FireAll(Net.Events.Announce, text, color, icon, rarity)
end

function NetService:Effect(player: Player, effectName: string, payload: any?)
	self:Fire(player, Net.Events.Effect, effectName, payload)
end

function NetService:EffectAll(effectName: string, payload: any?)
	self:FireAll(Net.Events.Effect, effectName, payload)
end

-- Announces a rare acquisition according to the rarity's Announce setting.
function NetService:AnnounceAcquisition(player: Player, item, verb: string?)
	local def = Catalog.Get(item.Id)
	if not def then
		return
	end
	local rarity = RarityConfig.Rarities[def.Rarity]
	local mutation = MutationConfig.Mutations[item.Mutation or "Normal"]
	local mutationText = (mutation and mutation.Tier > 0) and (item.Mutation .. " ") or ""
	-- Mutated items announce one level more eagerly.
	local announce = rarity.Announce
	if announce == "None" and mutation and mutation.Tier >= 4 then
		announce = "Server"
	end
	if announce == "None" then
		return
	end
	local text = string.format("%s %s a %s %s%s!", player.DisplayName, verb or "found", string.upper(rarity.Name), mutationText, def.Name)
	self:Announce(text, rarity.Color, "✨", def.Rarity)
	if announce == "Global" and GameConfig.Announcements.CrossServerEnabled and not RunService:IsStudio() then
		task.spawn(function()
			pcall(function()
				MessagingService:PublishAsync(GameConfig.Announcements.CrossServerTopic, {
					JobId = game.JobId,
					Text = text,
					Rarity = def.Rarity,
				})
			end)
		end)
	end
end

return NetService
