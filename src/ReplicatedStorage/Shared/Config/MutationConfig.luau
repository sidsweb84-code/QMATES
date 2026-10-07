--[[
	MutationConfig
	Mutations multiply a collectible's income (and its price/sell value).
	Chance = base probability that a freshly spawned collectible has this mutation.
	Luck raises mutation chances by Luck ^ LuckExponent (see Odds.luau).
	EventOnly mutations have Chance 0 and are enabled by an event modifier.
]]

local MutationConfig = {}

MutationConfig.Order = {
	"Normal",
	"Shiny",
	"Golden",
	"Dark",
	"Holographic",
	"Rainbow",
	"Glitched",
	"Cosmic",
}

MutationConfig.Mutations = {
	Normal = {
		Name = "Normal",
		Tier = 0,
		IncomeMultiplier = 1,
		PriceMultiplier = 1,
		Chance = 0,
		Color = Color3.fromRGB(230, 230, 230),
		Icon = "",
	},
	Shiny = {
		Name = "Shiny",
		Tier = 1,
		IncomeMultiplier = 2,
		PriceMultiplier = 1.75,
		Chance = 0.04,
		Color = Color3.fromRGB(255, 245, 160),
		Icon = "✨",
	},
	Golden = {
		Name = "Golden",
		Tier = 2,
		IncomeMultiplier = 4,
		PriceMultiplier = 3.4,
		Chance = 0.02,
		Color = Color3.fromRGB(255, 200, 50),
		Icon = "🥇",
	},
	Dark = {
		Name = "Dark",
		Tier = 3,
		IncomeMultiplier = 6,
		PriceMultiplier = 5,
		Chance = 0.01,
		Color = Color3.fromRGB(140, 70, 220),
		Icon = "🌑",
	},
	Holographic = {
		Name = "Holographic",
		Tier = 4,
		IncomeMultiplier = 8,
		PriceMultiplier = 6.5,
		Chance = 0.005,
		Color = Color3.fromRGB(120, 255, 240),
		Icon = "💠",
	},
	Rainbow = {
		Name = "Rainbow",
		Tier = 5,
		IncomeMultiplier = 12,
		PriceMultiplier = 9.5,
		Chance = 0.0025,
		Color = Color3.fromRGB(255, 120, 200),
		Icon = "🌈",
	},
	Glitched = {
		Name = "Glitched",
		Tier = 6,
		IncomeMultiplier = 25,
		PriceMultiplier = 19,
		Chance = 0.0006,
		Color = Color3.fromRGB(0, 255, 140),
		Icon = "👾",
	},
	Cosmic = {
		Name = "Cosmic",
		Tier = 7,
		IncomeMultiplier = 40,
		PriceMultiplier = 30,
		Chance = 0,
		EventOnly = true,
		Color = Color3.fromRGB(110, 90, 255),
		Icon = "🌌",
	},
}

MutationConfig.LuckExponent = 0.5
-- Hard cap on the combined chance of rolling any mutation.
MutationConfig.MaxTotalChance = 0.6

-- Personal luck gives a *bonus* mutation roll when you buy a Normal collectible:
-- chance = BonusRollFactor * (PersonalLuck - 1) * (normal mutation odds).
MutationConfig.BonusRollFactor = 0.5

function MutationConfig.Get(name: string)
	return MutationConfig.Mutations[name]
end

function MutationConfig.IsValid(name: any): boolean
	return type(name) == "string" and MutationConfig.Mutations[name] ~= nil
end

return MutationConfig
