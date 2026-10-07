--[[
	Odds
	THE single source of truth for every random roll in the game. The server
	uses these functions to roll, and the client uses the very same functions
	to display odds — so displayed odds are always the real odds.

	Luck formula (public, shown in-game):
		For every available rarity above the lowest available rarity,
		weight *= Luck ^ min(tierDistance * 0.5, 2)
		(tierDistance = how many tiers above the lowest available rarity)
	Mutation chances are multiplied by Luck ^ 0.5.
]]

local Shared = script.Parent.Parent
local Config = Shared.Config
local RarityConfig = require(Config.RarityConfig)
local MutationConfig = require(Config.MutationConfig)
local TraitConfig = require(Config.TraitConfig)
local Catalog = require(Shared.Catalog)

export type Modifiers = {
	LuckMultiplier: number?,
	RarityWeightMultipliers: { [string]: number }?,
	MutationChanceMultipliers: { [string]: number }?,
	EnabledMutations: { [string]: number }?,
	LimitedWeight: number?,
	ActiveEvents: { [string]: boolean }?,
}

export type RarityParams = {
	Luck: number?,
	MinRarity: string?,
	BaseWeights: { [string]: number }?,
	Modifiers: Modifiers?,
}

local Odds = {}

local function clampLuck(luck: number?): number
	local l = luck or 1
	if l ~= l then
		l = 1
	end
	return math.clamp(l, 1, RarityConfig.MaxLuck)
end

function Odds.ClampLuck(luck: number?): number
	return clampLuck(luck)
end

-- Returns unnormalised weights per rarity (0 = unavailable).
function Odds.RarityWeights(params: RarityParams): { [string]: number }
	local luck = clampLuck(params.Luck)
	local mods: Modifiers = params.Modifiers or {}
	local minTier = params.MinRarity and RarityConfig.Tier(params.MinRarity) or 0
	local weights = {}

	-- First pass: base availability.
	local lowestTier = math.huge
	for _, name in RarityConfig.Order do
		local info = RarityConfig.Rarities[name]
		local w: number
		if params.BaseWeights then
			w = params.BaseWeights[name] or 0
		elseif name == "Limited" then
			w = mods.LimitedWeight or 0
		else
			w = info.Weight
		end
		if name ~= "Limited" and info.Tier < minTier then
			w = 0
		end
		if mods.RarityWeightMultipliers and mods.RarityWeightMultipliers[name] then
			w *= mods.RarityWeightMultipliers[name]
		end
		w = math.max(0, w)
		weights[name] = w
		if w > 0 and name ~= "Limited" and info.Tier < lowestTier then
			lowestTier = info.Tier
		end
	end

	-- Second pass: luck.
	if luck > 1 and lowestTier ~= math.huge then
		for _, name in RarityConfig.Order do
			if name == "Limited" then
				continue
			end
			local w = weights[name]
			if w > 0 then
				local distance = RarityConfig.Rarities[name].Tier - lowestTier
				if distance > 0 then
					local exponent = math.min(distance * RarityConfig.LuckExponentPerTier, RarityConfig.MaxLuckExponent)
					weights[name] = w * luck ^ exponent
				end
			end
		end
	end
	return weights
end

function Odds.Normalize(weights: { [string]: number }): { [string]: number }
	local total = 0
	for _, w in weights do
		total += w
	end
	local probabilities = {}
	for name, w in weights do
		probabilities[name] = if total > 0 then w / total else 0
	end
	return probabilities
end

function Odds.RarityProbabilities(params: RarityParams): { [string]: number }
	return Odds.Normalize(Odds.RarityWeights(params))
end

function Odds.RollRarity(params: RarityParams, rng: Random): string
	local weights = Odds.RarityWeights(params)
	local total = 0
	for _, name in RarityConfig.Order do
		total += weights[name]
	end
	if total <= 0 then
		return "Common"
	end
	local r = rng:NextNumber() * total
	local cumulative = 0
	for _, name in RarityConfig.Order do
		cumulative += weights[name]
		if r < cumulative then
			return name
		end
	end
	-- Floating point edge: return the last available rarity.
	for i = #RarityConfig.Order, 1, -1 do
		local name = RarityConfig.Order[i]
		if weights[name] > 0 then
			return name
		end
	end
	return "Common"
end

-- Probability of each mutation (including "Normal" = no mutation).
function Odds.MutationChances(luck: number?, mods: Modifiers?): { [string]: number }
	local l = clampLuck(luck)
	local m: Modifiers = mods or {}
	local luckFactor = l ^ MutationConfig.LuckExponent
	local chances = {}
	local total = 0
	for _, name in MutationConfig.Order do
		if name == "Normal" then
			continue
		end
		local info = MutationConfig.Mutations[name]
		local base = info.Chance
		if info.EventOnly then
			base = (m.EnabledMutations and m.EnabledMutations[name]) or 0
		end
		local multiplier = (m.MutationChanceMultipliers and m.MutationChanceMultipliers[name]) or 1
		local p = math.max(0, base * multiplier * luckFactor)
		chances[name] = p
		total += p
	end
	if total > MutationConfig.MaxTotalChance then
		local scale = MutationConfig.MaxTotalChance / total
		for name, p in chances do
			chances[name] = p * scale
		end
		total = MutationConfig.MaxTotalChance
	end
	chances.Normal = 1 - total
	return chances
end

function Odds.RollMutation(chances: { [string]: number }, rng: Random): string
	local r = rng:NextNumber()
	local cumulative = 0
	for _, name in MutationConfig.Order do
		if name == "Normal" then
			continue
		end
		cumulative += chances[name] or 0
		if r < cumulative then
			return name
		end
	end
	return "Normal"
end

-- Chance (0..1) that personal luck grants a bonus mutation roll on a Normal purchase.
function Odds.BonusMutationRollChance(personalLuck: number?): number
	local l = clampLuck(personalLuck)
	return math.clamp(MutationConfig.BonusRollFactor * (l - 1), 0, 1)
end

function Odds.TraitChances(): { [string]: number }
	local total = 0
	for _, name in TraitConfig.Order do
		total += TraitConfig.Traits[name].Weight
	end
	local chances = {}
	for _, name in TraitConfig.Order do
		chances[name] = TraitConfig.Chance * TraitConfig.Traits[name].Weight / total
	end
	return chances
end

function Odds.RollTrait(rng: Random): string?
	if rng:NextNumber() >= TraitConfig.Chance then
		return nil
	end
	local total = 0
	for _, name in TraitConfig.Order do
		total += TraitConfig.Traits[name].Weight
	end
	local r = rng:NextNumber() * total
	local cumulative = 0
	for _, name in TraitConfig.Order do
		cumulative += TraitConfig.Traits[name].Weight
		if r < cumulative then
			return name
		end
	end
	return TraitConfig.Order[#TraitConfig.Order]
end

export type PickOptions = {
	ActiveEvents: { [string]: boolean }?,
	MaxRequiredRebirths: number?, -- only collectibles you can own via this source
}

-- Candidates for a rarity given the options.
function Odds.Candidates(rarity: string, options: PickOptions?): { Catalog.Def }
	local opts: PickOptions = options or {}
	local list = {}
	for _, def in Catalog.ByRarity[rarity] or {} do
		if def.Limited then
			if not (def.Event and opts.ActiveEvents and opts.ActiveEvents[def.Event]) then
				continue
			end
		end
		if opts.MaxRequiredRebirths ~= nil and def.RequiredRebirths > opts.MaxRequiredRebirths then
			continue
		end
		table.insert(list, def)
	end
	return list
end

function Odds.PickCollectible(rarity: string, options: PickOptions?, rng: Random): Catalog.Def?
	local candidates = Odds.Candidates(rarity, options)
	if #candidates == 0 then
		return nil
	end
	local total = 0
	for _, def in candidates do
		total += def.Weight
	end
	local r = rng:NextNumber() * total
	local cumulative = 0
	for _, def in candidates do
		cumulative += def.Weight
		if r < cumulative then
			return def
		end
	end
	return candidates[#candidates]
end

-- Rolls a full collectible (rarity -> def). Re-rolls when a rarity has no
-- candidates (e.g. Limited with no event), so it always returns something.
function Odds.RollCollectible(params: RarityParams, options: PickOptions?, rng: Random): Catalog.Def
	for _ = 1, 8 do
		local rarity = Odds.RollRarity(params, rng)
		local def = Odds.PickCollectible(rarity, options, rng)
		if def then
			return def
		end
	end
	-- Fallback: walk down from the rolled weights to any available collectible.
	for _, name in RarityConfig.Order do
		local def = Odds.PickCollectible(name, options, rng)
		if def then
			return def
		end
	end
	return Catalog.All[1]
end

return Odds
