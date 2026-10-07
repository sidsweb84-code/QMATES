--[[
	RewardService
	- Grant(): applies any list of rewards in the shared reward format.
	- Daily login streak (7-day cycle, UTC days).
	- Playtime tracking + daily playtime milestones.
	- Collection book milestones.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local RewardConfig = require(Config.RewardConfig)
local MonetizationConfig = require(Config.MonetizationConfig)
local Catalog = require(Shared.Catalog)
local Economy = require(Shared.Economy)
local Odds = require(Shared.Util.Odds)
local RewardFormat = require(Shared.Util.RewardFormat)
local TimeUtil = require(Shared.Util.TimeUtil)

local Modules = script.Parent.Parent.Modules
local Registry = require(Modules.Registry)
local ActionBus = require(Modules.ActionBus)
local Log = require(Modules.Log)

local RewardService = {}

local rng = Random.new()

function RewardService:Init() end

function RewardService:Start()
	-- Playtime accounting (centralised, every 10 seconds).
	task.spawn(function()
		local step = 10
		while true do
			task.wait(step)
			for _, player in Players:GetPlayers() do
				local data = Registry.DataService:Get(player)
				if data and Registry.PlayerService:IsReady(player) then
					self:_resetPlaytimeDay(player)
					data.Playtime.Today += step
					data.Stats.Playtime += step
					Registry.DataService:MarkDirty(player, "Playtime")
					Registry.DataService:MarkDirty(player, "Stats")
					player:SetAttribute("Playtime", data.Stats.Playtime)
					-- Fire "Playtime" in whole minutes.
					local minutesBefore = math.floor((data.Stats.Playtime - step) / 60)
					local minutesNow = math.floor(data.Stats.Playtime / 60)
					if minutesNow > minutesBefore then
						ActionBus.Fire(player, "Playtime", minutesNow - minutesBefore, {})
					end
				end
			end
		end
	end)
end

---------------------------------------------------------------- granting
-- multiplier scales cash/token amounts (daily streak week bonus).
function RewardService:Grant(player: Player, rewards, source: string, multiplier: number?): { string }
	local lines = {}
	local data = Registry.DataService:Get(player)
	if not data or type(rewards) ~= "table" then
		return lines
	end
	local mult = multiplier or 1
	local cps = Registry.EconomyService:GetCashPerSec(player)
	for _, reward in rewards do
		local ok, err = pcall(function()
			local t = reward.Type
			if t == "Cash" then
				local amount = math.floor(reward.Amount * mult)
				Registry.EconomyService:AddCash(player, amount, if source == "Product" then "Product" else "Reward")
				table.insert(lines, "💰 " .. RewardFormat.Describe({ Type = "Cash", Amount = amount }))
			elseif t == "CashMinutes" then
				local amount = math.floor(Economy.CashMinutes(reward.Minutes, cps, reward.Min) * mult)
				Registry.EconomyService:AddCash(player, amount, if source == "Product" then "Product" else "Reward")
				table.insert(lines, "💰 " .. RewardFormat.Describe({ Type = "Cash", Amount = amount }))
			elseif t == "Tokens" then
				local amount = math.floor(reward.Amount * mult)
				Registry.EconomyService:AddTokens(player, amount)
				table.insert(lines, "🪙 " .. RewardFormat.Describe({ Type = "Tokens", Amount = amount }))
			elseif t == "EventTokens" then
				Registry.EconomyService:AddEventTokens(player, reward.Amount)
				table.insert(lines, "🎟️ " .. RewardFormat.Describe(reward))
			elseif t == "Boost" then
				Registry.BoostService:Add(player, reward.Boost, reward.Duration)
				table.insert(lines, RewardFormat.Icon(reward) .. " " .. RewardFormat.Describe(reward))
			elseif t == "ServerBoost" then
				Registry.BoostService:AddServer(reward.Boost, reward.Duration, player)
				table.insert(lines, RewardFormat.Icon(reward) .. " " .. RewardFormat.Describe(reward))
			elseif t == "Cosmetic" then
				Registry.CosmeticService:Grant(player, reward.Id)
				table.insert(lines, "🎨 " .. RewardFormat.Describe(reward))
			elseif t == "Collectible" then
				local item = Registry.CollectibleService:Grant(player, reward.Id, { Mutation = reward.Mutation, Source = source })
				if item then
					table.insert(lines, "🎴 " .. RewardFormat.Describe(reward))
				else
					local def = Catalog.Get(reward.Id)
					local value = def and math.floor(def.Price * 0.5) or 0
					Registry.EconomyService:AddCash(player, value, "Reward")
					table.insert(lines, "💰 No space — converted to $" .. tostring(value))
				end
			elseif t == "RandomCollectible" then
				local def = Odds.PickCollectible(reward.Rarity, { MaxRequiredRebirths = data.Rebirths }, rng)
				if def then
					local mutation = Odds.RollMutation(Odds.MutationChances(Registry.EconomyService:PersonalLuck(player), Registry.EventService:GetModifiers()), rng)
					local item = Registry.CollectibleService:Grant(player, def.Id, { Mutation = mutation, Source = source })
					if item then
						table.insert(lines, "🎴 " .. def.Name)
					else
						local value = math.floor(def.Price * 0.5)
						Registry.EconomyService:AddCash(player, value, "Reward")
						table.insert(lines, "💰 No space — converted to $" .. tostring(value))
					end
				end
			elseif t == "Pack" then
				local okPack, msg = Registry.ShopService:OpenPack(player, reward.Pack, true)
				table.insert(lines, if okPack then "🃏 " .. RewardFormat.Describe(reward) else ("🃏 " .. tostring(msg)))
			elseif t == "InstantCollect" then
				local amount = math.max(data.Uncollected, Economy.CashMinutes(reward.Minutes or 10, cps, 0)) * 2
				data.Uncollected = 0
				Registry.DataService:MarkDirty(player, "Uncollected")
				Registry.EconomyService:AddCash(player, amount, "Product")
				table.insert(lines, "🧲 " .. RewardFormat.Describe({ Type = "Cash", Amount = amount }))
			else
				error("unknown reward type " .. tostring(t))
			end
		end)
		if not ok then
			Log.Error("Reward", string.format("Failed to grant %s reward to %s: %s", tostring(reward.Type), player.Name, tostring(err)), player.UserId)
		end
	end
	return lines
end

-- Grant + show a popup summary.
function RewardService:GrantWithPopup(player: Player, rewards, source: string, title: string, icon: string?, multiplier: number?)
	local lines = self:Grant(player, rewards, source, multiplier)
	if #lines > 0 then
		Registry.NetService:Fire(player, "Popup", title, lines, icon or "🎁")
	end
	return lines
end

---------------------------------------------------------------- daily login
function RewardService:DailyStatus(player: Player)
	local data = Registry.DataService:Get(player)
	if not data then
		return nil
	end
	local today = TimeUtil.DayNumber()
	local claimedToday = data.Daily.LastDay == today
	local continues = data.Daily.LastDay == today - 1
	local nextStreak = if claimedToday then data.Daily.Streak elseif continues then data.Daily.Streak + 1 else 1
	return {
		ClaimedToday = claimedToday,
		NextStreak = nextStreak,
		NextDayIndex = ((nextStreak - 1) % #RewardConfig.Daily) + 1,
	}
end

function RewardService:ClaimDaily(player: Player): (boolean, string?)
	local data = Registry.DataService:Get(player)
	local status = self:DailyStatus(player)
	if not data or not status then
		return false, "Not loaded"
	end
	if status.ClaimedToday then
		return false, "Come back tomorrow! (" .. math.floor(TimeUtil.SecondsUntilNextDay() / 3600) .. "h left)"
	end
	data.Daily.LastDay = TimeUtil.DayNumber()
	data.Daily.Streak = status.NextStreak
	Registry.DataService:MarkDirty(player, "Daily")
	local week = math.floor((status.NextStreak - 1) / #RewardConfig.Daily)
	local multiplier = 1 + math.min(week * RewardConfig.StreakWeekBonus, RewardConfig.MaxWeekBonus)
	local rewards = table.clone(RewardConfig.Daily[status.NextDayIndex])
	if Registry.MonetizationService:OwnsPass(player, "VIP") then
		table.insert(rewards, { Type = "Tokens", Amount = MonetizationConfig.Gamepasses.VIP.Perks.DailyTokenBonus })
	end
	self:GrantWithPopup(player, rewards, "Daily", string.format("Day %d reward!", status.NextStreak), "📅", multiplier)
	return true, nil
end

---------------------------------------------------------------- playtime
function RewardService:_resetPlaytimeDay(player: Player)
	local data = Registry.DataService:Get(player)
	if not data then
		return
	end
	local today = TimeUtil.DayNumber()
	if data.Playtime.Day ~= today then
		data.Playtime.Day = today
		data.Playtime.Today = 0
		data.Playtime.Claimed = {}
		Registry.DataService:MarkDirty(player, "Playtime")
	end
end

function RewardService:ClaimPlaytime(player: Player, index: any): (boolean, string?)
	if type(index) ~= "number" or index ~= math.floor(index) then
		return false, "Invalid reward"
	end
	local milestone = RewardConfig.Playtime[index]
	local data = Registry.DataService:Get(player)
	if not milestone or not data then
		return false, "Invalid reward"
	end
	self:_resetPlaytimeDay(player)
	local key = tostring(milestone.Minutes)
	if data.Playtime.Claimed[key] then
		return false, "Already claimed"
	end
	if data.Playtime.Today < milestone.Minutes * 60 then
		return false, "Keep playing to unlock this reward"
	end
	data.Playtime.Claimed[key] = true
	Registry.DataService:MarkDirty(player, "Playtime")
	self:GrantWithPopup(player, milestone.Rewards, "Playtime", string.format("%d minute reward!", milestone.Minutes), "⏰")
	return true, nil
end

---------------------------------------------------------------- collection milestones
function RewardService:ClaimCollectionMilestone(player: Player, percent: any): (boolean, string?)
	if type(percent) ~= "number" then
		return false, "Invalid milestone"
	end
	local data = Registry.DataService:Get(player)
	local milestone = nil
	for _, m in RewardConfig.CollectionMilestones do
		if m.Percent == percent then
			milestone = m
		end
	end
	if not data or not milestone then
		return false, "Invalid milestone"
	end
	local key = tostring(milestone.Percent)
	if data.CollectionClaimed[key] then
		return false, "Already claimed"
	end
	local count = Registry.CollectibleService:CollectionCount(player)
	local needed = math.ceil(Catalog.CompletionTotal * milestone.Percent / 100)
	if count < needed then
		return false, string.format("Discover %d critters first (%d/%d)", needed, count, needed)
	end
	data.CollectionClaimed[key] = true
	Registry.DataService:MarkDirty(player, "CollectionClaimed")
	self:GrantWithPopup(player, milestone.Rewards, "Collection", string.format("%d%% collection reward!", milestone.Percent), "📖")
	return true, nil
end

function RewardService:OnPlayerLoaded(player: Player)
	self:_resetPlaytimeDay(player)
	local data = Registry.DataService:Get(player)
	if data then
		player:SetAttribute("Playtime", data.Stats.Playtime)
	end
end

return RewardService
