--[[
	RebirthService
	Prestige: trade cash + placed/stored collectibles for a permanent income
	multiplier, luck bonus, tokens, unlocks (Elite Market, gated critters,
	packs) and milestone cosmetics. Your best collectibles are kept at higher
	rebirth counts (RebirthConfig.KeepBestCollectibles).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RebirthConfig = require(Shared.Config.RebirthConfig)
local Economy = require(Shared.Economy)
local Format = require(Shared.Util.Format)

local Modules = script.Parent.Parent.Modules
local Registry = require(Modules.Registry)
local ActionBus = require(Modules.ActionBus)
local Log = require(Modules.Log)

local RebirthService = {}

function RebirthService:Init() end
function RebirthService:Start() end

function RebirthService:CanRebirth(player: Player): (boolean, string?)
	local data = Registry.DataService:Get(player)
	if not data then
		return false, "Not loaded"
	end
	local cost = Economy.RebirthCost(data.Rebirths)
	if data.Cash < cost then
		return false, string.format("You need %s cash to rebirth", Format.Cash(cost))
	end
	if Registry.StealService:IsThief(player) then
		return false, "Finish your steal first"
	end
	if Registry.StealService:IsVictim(player) then
		return false, "Someone is stealing from you — deal with them first!"
	end
	if Registry.TradeService:IsTrading(player) then
		return false, "Finish your trade first"
	end
	return true, nil
end

function RebirthService:Rebirth(player: Player): (boolean, string?)
	local ok, reason = self:CanRebirth(player)
	if not ok then
		return false, reason
	end
	local data = Registry.DataService:Get(player) :: any
	local newCount = data.Rebirths + 1

	-- Decide which collectibles survive (best income first).
	local keepCount = Economy.KeptCollectiblesAt(newCount)
	local all = {}
	for _, item in data.Inventory do
		table.insert(all, item)
	end
	table.sort(all, function(a, b)
		return Economy.ItemIncome(a) > Economy.ItemIncome(b)
	end)
	local keep: { [string]: boolean } = {}
	for i = 1, math.min(keepCount, #all) do
		keep[all[i].Uid] = true
	end

	if RebirthConfig.Reset.Collectibles then
		for _, item in all do
			if not keep[item.Uid] then
				Registry.CollectibleService:Remove(player, item.Uid)
			end
		end
	end
	if RebirthConfig.Reset.Cash then
		data.Cash = Economy.RebirthStartingCash(newCount)
		Registry.DataService:MarkDirty(player, "Cash")
	end
	if RebirthConfig.Reset.Uncollected then
		data.Uncollected = 0
		Registry.DataService:MarkDirty(player, "Uncollected")
	end
	if RebirthConfig.Reset.BaseLevel then
		data.BaseLevel = 1
		Registry.DataService:MarkDirty(player, "BaseLevel")
	end
	if RebirthConfig.Reset.Upgrades then
		for track in data.Upgrades do
			data.Upgrades[track] = 0
		end
		Registry.DataService:MarkDirty(player, "Upgrades")
	end

	data.Rebirths = newCount
	data.Stats.Rebirths = newCount
	Registry.DataService:MarkDirty(player, "Rebirths")
	Registry.DataService:MarkDirty(player, "Stats")
	player:SetAttribute("Rebirths", newCount)

	Registry.EconomyService:AddTokens(player, Economy.RebirthTokens(newCount))
	local milestone = RebirthConfig.Milestones[tostring(newCount)]
	if milestone then
		Registry.RewardService:Grant(player, milestone, "Rebirth " .. newCount)
	end

	Registry.CollectibleService:NormalizeSlots(player)
	Registry.BaseService:RefreshSlots(player)
	Registry.BaseService:UpdateTraps(player)
	Registry.EconomyService:Refresh(player)
	ActionBus.Fire(player, "Rebirth", 1, { Rebirths = newCount })
	Registry.NetService:Effect(player, "Rebirth", {
		Rebirths = newCount,
		Multiplier = Economy.RebirthMultiplier(newCount),
		Kept = keepCount,
	})
	Registry.NetService:Announce(string.format("♻️ %s reached Rebirth %d!", player.DisplayName, newCount), Color3.fromRGB(120, 255, 170), "♻️")
	Log.Info("Rebirth", string.format("%s -> rebirth %d", player.Name, newCount), player.UserId)
	task.spawn(function()
		Registry.DataService:SaveAsync(player, false)
	end)
	return true, string.format("Rebirth %d! Income is now %s", newCount, Format.Multiplier(Economy.RebirthMultiplier(newCount)))
end

return RebirthService
