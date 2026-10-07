--[[
	QuestService
	Daily quests (deterministic per player per UTC day, free reroll) and
	lifetime achievement series. Driven entirely by server ActionBus events.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local QuestConfig = require(Config.QuestConfig)
local RarityConfig = require(Config.RarityConfig)
local RebirthConfig = require(Config.RebirthConfig)
local TimeUtil = require(Shared.Util.TimeUtil)
local Format = require(Shared.Util.Format)

local Modules = script.Parent.Parent.Modules
local Registry = require(Modules.Registry)
local ActionBus = require(Modules.ActionBus)

local QuestService = {}

local poolById = {}
for _, q in QuestConfig.DailyPool do
	poolById[q.Id] = q
end
local seriesById = {}
for _, a in QuestConfig.Achievements do
	seriesById[a.Id] = a
end

local function matches(def, ctx): boolean
	if def.MinRarity and RarityConfig.Tier(ctx.Rarity or "") < RarityConfig.Tier(def.MinRarity) then
		return false
	end
	if def.Mutated and (ctx.Mutation == nil or ctx.Mutation == "Normal") then
		return false
	end
	return true
end

local function scaledTarget(def, rebirths: number): number
	if def.Scale == "Rebirth" then
		return math.floor(def.Target * RebirthConfig.CostGrowth ^ rebirths)
	end
	return def.Target
end

local function questText(def, target: number): string
	local n = if def.Action == "Earn" then Format.Cash(target) else Format.Abbreviate(target)
	return (string.gsub(def.Text, "{n}", n))
end
QuestService.QuestText = questText

function QuestService:Init() end

function QuestService:Start()
	ActionBus.Listen(function(player, action, amount, ctx)
		self:_onAction(player, action, amount, ctx)
	end)
end

---------------------------------------------------------------- daily selection
function QuestService:_pickDaily(player: Player, day: number, exclude: { [string]: boolean }?): { any }
	local data = Registry.DataService:Get(player)
	local rebirths = data and data.Rebirths or 0
	local rng = Random.new(day * 7919 + player.UserId % 100000)
	local pool = table.clone(QuestConfig.DailyPool)
	local list = {}
	while #list < QuestConfig.DailyCount and #pool > 0 do
		local index = rng:NextInteger(1, #pool)
		local def = table.remove(pool, index)
		if not (exclude and exclude[def.Id]) then
			table.insert(list, { Id = def.Id, Progress = 0, Target = scaledTarget(def, rebirths), Claimed = false })
		end
	end
	return list
end

function QuestService:EnsureDay(player: Player)
	local data = Registry.DataService:Get(player)
	if not data then
		return
	end
	local today = TimeUtil.DayNumber()
	local valid = data.Quests.Day == today and #data.Quests.Daily == QuestConfig.DailyCount
	if valid then
		for _, q in data.Quests.Daily do
			if not poolById[q.Id] then
				valid = false
			end
		end
	end
	if not valid then
		data.Quests.Day = today
		data.Quests.Daily = self:_pickDaily(player, today)
		data.Quests.Rerolls = 0
		Registry.DataService:MarkDirty(player, "Quests")
	end
end

---------------------------------------------------------------- progress
function QuestService:_statValue(player: Player, stat: string): number
	local data = Registry.DataService:Get(player)
	if not data then
		return 0
	end
	if stat == "TotalEarned" then
		return data.TotalEarned
	elseif stat == "Rebirths" then
		return data.Rebirths
	elseif stat == "CollectionCount" then
		return Registry.CollectibleService:CollectionCount(player)
	elseif stat == "PlaytimeHours" then
		return math.floor(data.Stats.Playtime / 3600)
	end
	return 0
end

function QuestService:_syncStats(player: Player): boolean
	local data = Registry.DataService:Get(player)
	if not data then
		return false
	end
	local changed = false
	for _, series in QuestConfig.Achievements do
		if series.Stat then
			local entry = data.Quests.Lifetime[series.Id]
			if not entry then
				entry = { Progress = 0, Claimed = 0 }
				data.Quests.Lifetime[series.Id] = entry
			end
			local value = self:_statValue(player, series.Stat)
			if value ~= entry.Progress then
				local before = entry.Progress
				entry.Progress = value
				changed = true
				self:_notifyTier(player, series, before, value)
			end
		end
	end
	return changed
end

function QuestService:_notifyTier(player: Player, series, before: number, after: number)
	for _, tier in series.Tiers do
		if before < tier.Target and after >= tier.Target then
			Registry.NetService:Notify(player, string.format("%s Achievement ready: %s!", series.Icon, series.Name), "Reward")
			Registry.NetService:Effect(player, "QuestReady", {})
			break
		end
	end
end

function QuestService:_onAction(player: Player, action: string, amount: number, ctx)
	local data = Registry.DataService:Get(player)
	if not data then
		return
	end
	self:EnsureDay(player)
	local dirty = false
	for _, q in data.Quests.Daily do
		local def = poolById[q.Id]
		if def and not q.Claimed and def.Action == action and q.Progress < q.Target and matches(def, ctx) then
			q.Progress = math.min(q.Target, q.Progress + amount)
			dirty = true
			if q.Progress >= q.Target then
				Registry.NetService:Notify(player, "📜 Quest complete: " .. questText(def, q.Target) .. " — claim your reward!", "Reward")
				Registry.NetService:Effect(player, "QuestReady", {})
			end
		end
	end
	for _, series in QuestConfig.Achievements do
		if series.Action == action and matches(series, ctx) then
			local entry = data.Quests.Lifetime[series.Id]
			if not entry then
				entry = { Progress = 0, Claimed = 0 }
				data.Quests.Lifetime[series.Id] = entry
			end
			local before = entry.Progress
			entry.Progress += amount
			dirty = true
			self:_notifyTier(player, series, before, entry.Progress)
		end
	end
	if action == "Earn" or action == "Rebirth" or action == "Acquire" or action == "Playtime" then
		dirty = self:_syncStats(player) or dirty
	end
	if dirty then
		Registry.DataService:MarkDirty(player, "Quests")
	end
end

---------------------------------------------------------------- claims
function QuestService:ClaimQuest(player: Player, index: any): (boolean, string?)
	local data = Registry.DataService:Get(player)
	if not data or type(index) ~= "number" then
		return false, "Invalid quest"
	end
	self:EnsureDay(player)
	local q = data.Quests.Daily[index]
	local def = q and poolById[q.Id]
	if not q or not def then
		return false, "Invalid quest"
	end
	if q.Claimed then
		return false, "Already claimed"
	end
	if q.Progress < q.Target then
		return false, "Not finished yet"
	end
	q.Claimed = true
	Registry.DataService:MarkDirty(player, "Quests")
	Registry.RewardService:GrantWithPopup(player, def.Rewards, "Quest", "Quest complete!", "📜")
	Registry.NetService:Effect(player, "QuestClaimed", {})
	return true, nil
end

function QuestService:RerollQuest(player: Player, index: any): (boolean, string?)
	local data = Registry.DataService:Get(player)
	if not data or type(index) ~= "number" then
		return false, "Invalid quest"
	end
	self:EnsureDay(player)
	local q = data.Quests.Daily[index]
	if not q then
		return false, "Invalid quest"
	end
	if q.Claimed then
		return false, "Already completed"
	end
	if data.Quests.Rerolls >= QuestConfig.FreeRerollsPerDay then
		return false, "No rerolls left today"
	end
	local exclude = {}
	for _, existing in data.Quests.Daily do
		exclude[existing.Id] = true
	end
	local seed = TimeUtil.DayNumber() * 31 + data.Quests.Rerolls + 1
	local candidates = self:_pickDaily(player, seed, exclude)
	if #candidates == 0 then
		return false, "No other quests available"
	end
	data.Quests.Daily[index] = candidates[1]
	data.Quests.Rerolls += 1
	Registry.DataService:MarkDirty(player, "Quests")
	return true, "New quest!"
end

function QuestService:ClaimAchievement(player: Player, seriesId: any): (boolean, string?)
	local data = Registry.DataService:Get(player)
	local series = type(seriesId) == "string" and seriesById[seriesId] or nil
	if not data or not series then
		return false, "Invalid achievement"
	end
	self:_syncStats(player)
	local entry = data.Quests.Lifetime[series.Id] or { Progress = 0, Claimed = 0 }
	data.Quests.Lifetime[series.Id] = entry
	local tier = series.Tiers[entry.Claimed + 1]
	if not tier then
		return false, "All tiers complete!"
	end
	if entry.Progress < tier.Target then
		return false, "Not reached yet"
	end
	entry.Claimed += 1
	Registry.DataService:MarkDirty(player, "Quests")
	Registry.RewardService:GrantWithPopup(player, tier.Rewards, "Achievement", series.Icon .. " " .. series.Name .. " — Tier " .. entry.Claimed, "🏆")
	Registry.NetService:Effect(player, "QuestClaimed", {})
	return true, nil
end

function QuestService:OnPlayerLoaded(player: Player)
	self:EnsureDay(player)
	if self:_syncStats(player) then
		Registry.DataService:MarkDirty(player, "Quests")
	end
end

return QuestService
