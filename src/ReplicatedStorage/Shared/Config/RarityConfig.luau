--[[
	RarityConfig
	Ordered rarity tiers. Weight = base spawn weight on the main conveyor.
	Spawn odds are always computed from these numbers by Shared/Util/Odds so the
	odds shown to players are exactly the odds the server uses.

	RevealTier controls how dramatic the acquisition animation is:
		1 = simple card reveal, 2 = glow + sparkle, 3 = golden flash + camera,
		4 = screen effect + dramatic sequence, 5 = cinematic reveal
	Announce: "None" | "Server" (everyone in this server) | "Global" (all servers)
]]

local RarityConfig = {}

RarityConfig.Order = {
	"Common",
	"Uncommon",
	"Rare",
	"Epic",
	"Legendary",
	"Mythic",
	"Divine",
	"Secret",
	"Limited",
}

RarityConfig.Rarities = {
	Common = {
		Name = "Common",
		Tier = 1,
		Weight = 6000,
		Color = Color3.fromRGB(184, 194, 204),
		Gradient = { Color3.fromRGB(214, 222, 230), Color3.fromRGB(140, 150, 163) },
		StealTime = 3,
		CarryPenalty = 0,
		SellRatio = 0.5,
		RevealTier = 1,
		Announce = "None",
		ModelScale = 0.85,
	},
	Uncommon = {
		Name = "Uncommon",
		Tier = 2,
		Weight = 2500,
		Color = Color3.fromRGB(91, 212, 110),
		Gradient = { Color3.fromRGB(140, 240, 150), Color3.fromRGB(40, 160, 80) },
		StealTime = 4,
		CarryPenalty = 0,
		SellRatio = 0.5,
		RevealTier = 1,
		Announce = "None",
		ModelScale = 0.95,
	},
	Rare = {
		Name = "Rare",
		Tier = 3,
		Weight = 1000,
		Color = Color3.fromRGB(61, 155, 255),
		Gradient = { Color3.fromRGB(120, 200, 255), Color3.fromRGB(30, 90, 220) },
		StealTime = 5,
		CarryPenalty = 0.05,
		SellRatio = 0.5,
		RevealTier = 2,
		Announce = "None",
		ModelScale = 1.05,
	},
	Epic = {
		Name = "Epic",
		Tier = 4,
		Weight = 360,
		Color = Color3.fromRGB(177, 87, 255),
		Gradient = { Color3.fromRGB(215, 150, 255), Color3.fromRGB(110, 40, 210) },
		StealTime = 6.5,
		CarryPenalty = 0.1,
		SellRatio = 0.5,
		RevealTier = 2,
		Announce = "Server",
		ModelScale = 1.15,
	},
	Legendary = {
		Name = "Legendary",
		Tier = 5,
		Weight = 100,
		Color = Color3.fromRGB(255, 184, 46),
		Gradient = { Color3.fromRGB(255, 236, 140), Color3.fromRGB(240, 140, 20) },
		StealTime = 8,
		CarryPenalty = 0.15,
		SellRatio = 0.5,
		RevealTier = 3,
		Announce = "Server",
		ModelScale = 1.3,
	},
	Mythic = {
		Name = "Mythic",
		Tier = 6,
		Weight = 30,
		Color = Color3.fromRGB(255, 77, 109),
		Gradient = { Color3.fromRGB(255, 150, 170), Color3.fromRGB(200, 20, 80) },
		StealTime = 10,
		CarryPenalty = 0.2,
		SellRatio = 0.5,
		RevealTier = 4,
		Announce = "Server",
		ModelScale = 1.45,
	},
	Divine = {
		Name = "Divine",
		Tier = 7,
		Weight = 8,
		Color = Color3.fromRGB(127, 255, 244),
		Gradient = { Color3.fromRGB(255, 250, 200), Color3.fromRGB(100, 240, 255) },
		StealTime = 12,
		CarryPenalty = 0.25,
		SellRatio = 0.5,
		RevealTier = 4,
		Announce = "Global",
		ModelScale = 1.6,
	},
	Secret = {
		Name = "Secret",
		Tier = 8,
		Weight = 2,
		Color = Color3.fromRGB(30, 30, 40),
		Gradient = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(80, 120, 255) },
		Rainbow = true,
		StealTime = 15,
		CarryPenalty = 0.3,
		SellRatio = 0.5,
		RevealTier = 5,
		Announce = "Global",
		ModelScale = 1.75,
	},
	Limited = {
		Name = "Limited",
		Tier = 9,
		-- Limited collectibles only spawn while their event is running.
		-- The active event supplies the weight (EventConfig LimitedWeight).
		Weight = 0,
		Color = Color3.fromRGB(255, 122, 26),
		Gradient = { Color3.fromRGB(255, 200, 90), Color3.fromRGB(230, 70, 30) },
		StealTime = 11,
		CarryPenalty = 0.2,
		SellRatio = 0.5,
		RevealTier = 4,
		Announce = "Server",
		ModelScale = 1.4,
	},
}

-- Luck formula (see Odds.luau): each rarity above the lowest available rarity
-- has its weight multiplied by Luck ^ min(tierDistance * LuckExponentPerTier, MaxLuckExponent)
RarityConfig.LuckExponentPerTier = 0.5
RarityConfig.MaxLuckExponent = 2
RarityConfig.MaxLuck = 10

function RarityConfig.Get(name: string)
	return RarityConfig.Rarities[name]
end

function RarityConfig.Tier(name: string): number
	local r = RarityConfig.Rarities[name]
	return r and r.Tier or 0
end

function RarityConfig.IsAtLeast(name: string, minimum: string): boolean
	return RarityConfig.Tier(name) >= RarityConfig.Tier(minimum)
end

return RarityConfig
