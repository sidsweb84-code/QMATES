--[[
	HandlerService
	Binds every client request (Shared/Net.Actions) to the service that owns it.
	Handlers validate argument types; services validate game rules.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local GameConfig = require(Config.GameConfig)
local MapConfig = require(Config.MapConfig)
local RebirthConfig = require(Config.RebirthConfig)
local Net = require(Shared.Net)

local Modules = script.Parent.Parent.Modules
local Registry = require(Modules.Registry)
local DataSchema = require(Modules.DataSchema)

local HandlerService = {}

local travelCooldowns: { [Player]: number } = {}

function HandlerService:Init() end

function HandlerService:Start()
	local NetService = Registry.NetService

	NetService:Handle("Hello", function(player)
		local profile = Registry.DataService:WaitForProfile(player, 25)
		if not profile then
			return false, "Still loading"
		end
		local snapshot = Registry.DataService:Snapshot(player)
		snapshot.Server = {
			IsAdmin = Registry.AdminService:IsAdmin(player),
			IsStudio = RunService:IsStudio(),
			UsingMockData = Registry.DataService.UsingMock,
			Version = GameConfig.Version,
		}
		return true, nil, snapshot
	end)

	-- Economy / base
	NetService:Handle("BuyConveyor", function(player, uid)
		return Registry.ConveyorService:Buy(player, uid)
	end)
	NetService:Handle("CollectCash", function(player)
		return Registry.EconomyService:Collect(player, false)
	end)
	NetService:Handle("LockBase", function(player)
		return Registry.BaseService:Lock(player)
	end)
	NetService:Handle("ClaimBase", function(player)
		return Registry.BaseService:Claim(player)
	end)
	NetService:Handle("UpgradeBase", function(player)
		return Registry.UpgradeService:UpgradeBase(player)
	end)
	NetService:Handle("UpgradeTrack", function(player, track)
		return Registry.UpgradeService:UpgradeTrack(player, track)
	end)

	-- Stealing
	NetService:Handle("StartSteal", function(player, ownerUserId, uid)
		return Registry.StealService:StartSteal(player, ownerUserId, uid)
	end)
	NetService:Handle("CancelSteal", function(player)
		return Registry.StealService:CancelSteal(player)
	end)

	-- Collectibles
	NetService:Handle("LevelUpItem", function(player, uid)
		return Registry.CollectibleService:LevelUp(player, uid)
	end)
	NetService:Handle("SellItem", function(player, uid)
		return Registry.CollectibleService:Sell(player, uid)
	end)
	NetService:Handle("ToggleItemLock", function(player, uid)
		return Registry.CollectibleService:ToggleLock(player, uid)
	end)
	NetService:Handle("MoveItem", function(player, uid, target)
		return Registry.CollectibleService:Move(player, uid, target)
	end)

	-- Progression
	NetService:Handle("Rebirth", function(player)
		return Registry.RebirthService:Rebirth(player)
	end)
	NetService:Handle("ClaimDaily", function(player)
		return Registry.RewardService:ClaimDaily(player)
	end)
	NetService:Handle("ClaimPlaytime", function(player, index)
		return Registry.RewardService:ClaimPlaytime(player, index)
	end)
	NetService:Handle("ClaimQuest", function(player, index)
		return Registry.QuestService:ClaimQuest(player, index)
	end)
	NetService:Handle("RerollQuest", function(player, index)
		return Registry.QuestService:RerollQuest(player, index)
	end)
	NetService:Handle("ClaimAchievement", function(player, id)
		return Registry.QuestService:ClaimAchievement(player, id)
	end)
	NetService:Handle("ClaimCollectionMilestone", function(player, percent)
		return Registry.RewardService:ClaimCollectionMilestone(player, percent)
	end)

	-- Shops
	NetService:Handle("BuyPack", function(player, packId)
		return Registry.ShopService:OpenPack(player, packId, false)
	end)
	NetService:Handle("BuyBoost", function(player, itemId)
		return Registry.ShopService:BuyBoost(player, itemId)
	end)
	NetService:Handle("BuyCosmetic", function(player, id)
		return Registry.ShopService:BuyCosmetic(player, id)
	end)
	NetService:Handle("EquipCosmetic", function(player, id, typeName)
		return Registry.CosmeticService:Equip(player, id, typeName)
	end)
	NetService:Handle("BuyEventItem", function(player, itemId)
		return Registry.ShopService:BuyEventItem(player, itemId)
	end)

	-- Settings / tutorial
	NetService:Handle("SaveSettings", function(player, settings)
		if type(settings) ~= "table" then
			return false, "Invalid settings"
		end
		local data = Registry.DataService:Get(player)
		if not data then
			return false, "Not loaded"
		end
		for key, value in settings do
			local spec = DataSchema.SettingsSpec[key]
			if spec and type(value) == spec.Type and (not spec.Options or spec.Options[value]) then
				data.Settings[key] = value
			end
		end
		Registry.DataService:MarkDirty(player, "Settings")
		return true, nil
	end)
	NetService:Handle("TutorialSkip", function(player, scope)
		return Registry.TutorialService:Skip(player, scope)
	end)

	-- Travel / social
	NetService:Handle("QuickTravel", function(player, target)
		if Registry.StealService:IsThief(player) then
			return false, "You can't teleport while stealing!"
		end
		if (travelCooldowns[player] or 0) > os.clock() then
			return false, "Teleport recharging..."
		end
		local data = Registry.DataService:Get(player)
		if target == "Home" then
			Registry.BaseService:TeleportHome(player)
		elseif target == "Hub" then
			Registry.AntiExploitService:Teleport(player, CFrame.new(MapConfig.Hub.TeleportPoint) * CFrame.Angles(0, -math.pi / 2, 0))
		elseif target == "Elite" then
			if not data or data.Rebirths < RebirthConfig.Areas.EliteMarket.RequiredRebirths then
				return false, "The Elite Market unlocks at Rebirth " .. RebirthConfig.Areas.EliteMarket.RequiredRebirths
			end
			Registry.AntiExploitService:Teleport(player, CFrame.new(MapConfig.EliteArea.GateCenter + Vector3.new(24, 4, 0)))
		else
			return false, "Unknown destination"
		end
		travelCooldowns[player] = os.clock() + GameConfig.QuickTravel.Cooldown
		return true, nil
	end)

	NetService:Handle("VisitBase", function(player, userId)
		if type(userId) ~= "number" then
			return false, "Invalid player"
		end
		if Registry.StealService:IsThief(player) then
			return false, "You can't teleport while stealing!"
		end
		if (travelCooldowns[player] or 0) > os.clock() then
			return false, "Teleport recharging..."
		end
		local plot = Registry.BaseService:GetPlotByUserId(userId)
		if not plot then
			return false, "That player has no base"
		end
		Registry.BaseService:TeleportToEntrance(player, plot)
		travelCooldowns[player] = os.clock() + GameConfig.Visit.Cooldown
		return true, nil
	end)

	NetService:Handle("InspectPlayer", function(_player, userId)
		if type(userId) ~= "number" then
			return false, "Invalid player"
		end
		local target = Players:GetPlayerByUserId(userId)
		local data = target and Registry.DataService:Get(target)
		if not target or not data then
			return false, "Player not found"
		end
		local items = {}
		for _, item in data.Inventory do
			if item.Slot > 0 then
				table.insert(items, { Uid = item.Uid, Id = item.Id, Mutation = item.Mutation, Trait = item.Trait, Level = item.Level, Serial = item.Serial })
			end
		end
		return true, nil, {
			Name = target.DisplayName,
			UserId = target.UserId,
			Rebirths = data.Rebirths,
			CashPerSec = Registry.EconomyService:GetCashPerSec(target),
			Collection = Registry.CollectibleService:CollectionCount(target),
			Steals = data.Stats.Steals,
			Catches = data.Stats.Catches,
			Playtime = data.Stats.Playtime,
			BaseLevel = data.BaseLevel,
			NameTag = data.Cosmetics.Equipped.NameTag,
			Items = items,
		}
	end)

	NetService:Handle("GetLeaderboards", function()
		return true, nil, { Global = Registry.LeaderboardService:GetGlobal() }
	end)

	-- Trading
	NetService:Handle("TradeRequest", function(player, userId)
		return Registry.TradeService:Request(player, userId)
	end)
	NetService:Handle("TradeRespond", function(player, fromUserId, accept)
		return Registry.TradeService:Respond(player, fromUserId, accept)
	end)
	NetService:Handle("TradeSetItems", function(player, uids)
		return Registry.TradeService:SetItems(player, uids)
	end)
	NetService:Handle("TradeReady", function(player, ready)
		return Registry.TradeService:SetReady(player, ready)
	end)
	NetService:Handle("TradeCancel", function(player)
		return Registry.TradeService:Cancel(player)
	end)

	-- Admin
	NetService:Handle("AdminCommand", function(player, text)
		return Registry.AdminService:Execute(player, text)
	end)

	-- Every declared action must have a handler.
	for action in Net.Actions do
		assert(Registry.NetService:HasHandler(action), "Missing handler for action " .. action)
	end

	Players.PlayerRemoving:Connect(function(player)
		travelCooldowns[player] = nil
	end)
end

return HandlerService
