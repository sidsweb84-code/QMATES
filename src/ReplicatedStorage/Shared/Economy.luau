--[[
	Economy
	Pure formulas (no side effects) for prices, income, steal times, rebirths
	and capacities. Server uses them for authoritative values; client uses them
	for display. Unit-tested offline (tests/).
]]

local Shared = script.Parent
local Config = Shared.Config
local RarityConfig = require(Config.RarityConfig)
local MutationConfig = require(Config.MutationConfig)
local TraitConfig = require(Config.TraitConfig)
local UpgradeConfig = require(Config.UpgradeConfig)
local RebirthConfig = require(Config.RebirthConfig)
local StealConfig = require(Config.StealConfig)
local Catalog = require(Shared.Catalog)

export type Item = {
	Uid: string,
	Id: string,
	Mutation: string?,
	Trait: string?,
	Level: number?,
	Serial: number?,
	Slot: number?,
	Locked: boolean?,
	Acquired: number?,
	Source: string?,
}

local Economy = {}

local function mutationInfo(name: string?)
	return MutationConfig.Mutations[name or "Normal"] or MutationConfig.Mutations.Normal
end

function Economy.LevelMultiplier(level: number?): number
	local lv = math.clamp(math.floor(level or 1), 1, UpgradeConfig.CardLevels.MaxLevel)
	return 1 + (lv - 1) * UpgradeConfig.CardLevels.IncomePerLevel
end

-- Income per second of a single collectible (before player-wide multipliers).
function Economy.ItemIncome(item: Item): number
	local def = Catalog.Get(item.Id)
	if not def then
		return 0
	end
	local income = def.Income * mutationInfo(item.Mutation).IncomeMultiplier * Economy.LevelMultiplier(item.Level)
	local trait = TraitConfig.Get(item.Trait)
	if trait and trait.IncomeMultiplier then
		income *= trait.IncomeMultiplier
	end
	return income
end

-- Price of a collectible on a conveyor.
function Economy.SpawnPrice(id: string, mutation: string?, trait: string?): number
	local def = Catalog.Get(id)
	if not def then
		return math.huge
	end
	local price = def.Price * mutationInfo(mutation).PriceMultiplier
	local traitInfo = TraitConfig.Get(trait)
	if traitInfo and traitInfo.PriceMultiplier then
		price *= traitInfo.PriceMultiplier
	end
	return math.floor(price + 0.5)
end

-- Cash invested into an item: purchase value + level-ups.
function Economy.ItemValue(item: Item): number
	local value = Economy.SpawnPrice(item.Id, item.Mutation, item.Trait)
	local level = math.floor(item.Level or 1)
	for lv = 1, level - 1 do
		value += Economy.LevelUpCostAt(item, lv)
	end
	return value
end

function Economy.SellValue(item: Item): number
	local def = Catalog.Get(item.Id)
	if not def then
		return 0
	end
	local ratio = RarityConfig.Rarities[def.Rarity].SellRatio
	return math.floor(Economy.ItemValue(item) * ratio)
end

-- Cost to go from `level` to `level + 1`.
function Economy.LevelUpCostAt(item: Item, level: number): number
	local base = Economy.SpawnPrice(item.Id, item.Mutation, item.Trait)
	local cfg = UpgradeConfig.CardLevels
	return math.floor(base * cfg.CostFactor * cfg.CostGrowth ^ (level - 1) + 0.5)
end

function Economy.LevelUpCost(item: Item): number?
	local level = math.floor(item.Level or 1)
	if level >= UpgradeConfig.CardLevels.MaxLevel then
		return nil
	end
	return Economy.LevelUpCostAt(item, level)
end

-- Seconds needed to grab this item out of a base with the given security level.
function Economy.StealDuration(item: Item, securityLevel: number?): number
	local def = Catalog.Get(item.Id)
	if not def then
		return StealConfig.MaxStealTime
	end
	local base = RarityConfig.Rarities[def.Rarity].StealTime
	local duration = base * def.StealDifficulty
	-- Each mutation tier adds 5%.
	duration *= 1 + mutationInfo(item.Mutation).Tier * 0.05
	local trait = TraitConfig.Get(item.Trait)
	if trait and trait.StealTimeMultiplier then
		duration *= trait.StealTimeMultiplier
	end
	local levels = UpgradeConfig.Tracks.Security.Levels
	local sec = levels[math.clamp((securityLevel or 0) + 1, 1, #levels)]
	duration *= sec.StealTimeMultiplier
	return math.clamp(duration, 1, StealConfig.MaxStealTime)
end

-- Walk speed multiplier while carrying this item (e.g. 0.85).
function Economy.CarrySpeedMultiplier(item: Item): number
	local def = Catalog.Get(item.Id)
	if not def then
		return 1
	end
	return 1 - RarityConfig.Rarities[def.Rarity].CarryPenalty
end

function Economy.RebirthCost(rebirths: number): number
	return math.floor(RebirthConfig.BaseCost * RebirthConfig.CostGrowth ^ rebirths + 0.5)
end

function Economy.RebirthMultiplier(rebirths: number): number
	return 1 + rebirths * RebirthConfig.IncomePerRebirth
end

function Economy.RebirthLuckBonus(rebirths: number): number
	return math.min(rebirths * RebirthConfig.LuckPerRebirth, RebirthConfig.MaxLuckBonus)
end

function Economy.RebirthTokens(newRebirthCount: number): number
	return RebirthConfig.TokenReward.Base + RebirthConfig.TokenReward.PerRebirth * newRebirthCount
end

function Economy.RebirthStartingCash(newRebirthCount: number): number
	return RebirthConfig.StartingCash.Base + RebirthConfig.StartingCash.PerRebirth * newRebirthCount
end

function Economy.KeptCollectiblesAt(rebirths: number): number
	local count = 0
	for _, entry in RebirthConfig.KeepBestCollectibles do
		if rebirths >= entry.Rebirths then
			count = math.max(count, entry.Count)
		end
	end
	return count
end

function Economy.BaseSlots(baseLevel: number, extraSlots: number?): number
	local levels = UpgradeConfig.BaseLevels
	local level = levels[math.clamp(math.floor(baseLevel), 1, #levels)]
	return math.min(level.Slots + (extraSlots or 0), UpgradeConfig.PhysicalSlots)
end

function Economy.NextBaseLevelCost(baseLevel: number): number?
	local nextLevel = UpgradeConfig.BaseLevels[baseLevel + 1]
	return nextLevel and nextLevel.Cost or nil
end

function Economy.StorageCapacity(extraStorage: number?): number
	return UpgradeConfig.Storage.BaseCapacity + (extraStorage or 0)
end

function Economy.TrackLevelInfo(track: string, level: number)
	local trackInfo = UpgradeConfig.Tracks[track]
	if not trackInfo then
		return nil
	end
	return trackInfo.Levels[math.clamp(level + 1, 1, #trackInfo.Levels)]
end

function Economy.TrackNextCost(track: string, level: number): number?
	local trackInfo = UpgradeConfig.Tracks[track]
	if not trackInfo then
		return nil
	end
	local nextLevel = trackInfo.Levels[level + 2]
	return nextLevel and nextLevel.Cost or nil
end

function Economy.TrackMaxLevel(track: string): number
	local trackInfo = UpgradeConfig.Tracks[track]
	return trackInfo and (#trackInfo.Levels - 1) or 0
end

function Economy.LockDuration(securityLevel: number): number
	return Economy.TrackLevelInfo("Security", securityLevel).LockDuration
end

-- "N minutes of income" rewards.
function Economy.CashMinutes(minutes: number, cashPerSec: number, minimum: number?): number
	return math.floor(math.max(minimum or 0, minutes * 60 * math.max(0, cashPerSec)))
end

-- Total income per second for a set of placed items and player-wide multipliers.
export type IncomeContext = {
	Rebirths: number,
	BoostMultiplier: number?,
	PassMultiplier: number?,
	EventMultiplier: number?,
	ServerMultiplier: number?,
}

function Economy.Multiplier(ctx: IncomeContext): number
	return Economy.RebirthMultiplier(ctx.Rebirths)
		* (ctx.BoostMultiplier or 1)
		* (ctx.PassMultiplier or 1)
		* (ctx.EventMultiplier or 1)
		* (ctx.ServerMultiplier or 1)
end

function Economy.TotalIncome(items: { Item }, ctx: IncomeContext): number
	local sum = 0
	for _, item in items do
		sum += Economy.ItemIncome(item)
	end
	return sum * Economy.Multiplier(ctx)
end

return Economy
