--[[
	RebirthConfig
	Prestige system. Rebirthing resets your cash and placed collectibles in
	exchange for permanent multipliers, unlocks and rewards.
]]

local RebirthConfig = {}

RebirthConfig.BaseCost = 1000000 -- cash needed for the first rebirth
RebirthConfig.CostGrowth = 3.2 -- each rebirth costs CostGrowth x the previous

RebirthConfig.IncomePerRebirth = 0.25 -- Rebirth 1 = 1.25x, Rebirth 2 = 1.5x ...
RebirthConfig.LuckPerRebirth = 0.05 -- +5% personal luck per rebirth
RebirthConfig.MaxLuckBonus = 1.0

RebirthConfig.TokenReward = { Base = 25, PerRebirth = 10 }
RebirthConfig.StartingCash = { Base = 100, PerRebirth = 1000 }

-- What a rebirth resets. Base level and security upgrades are kept.
RebirthConfig.Reset = {
	Cash = true,
	Uncollected = true,
	Collectibles = true,
	BaseLevel = false,
	Upgrades = false,
}

-- Rebirth milestones that let you keep your best collectibles (by income).
RebirthConfig.KeepBestCollectibles = {
	{ Rebirths = 3, Count = 1 },
	{ Rebirths = 6, Count = 2 },
	{ Rebirths = 10, Count = 3 },
}

-- Areas unlocked by rebirths (checked server-side).
RebirthConfig.Areas = {
	EliteMarket = { Name = "Elite Market", RequiredRebirths = 1 },
}

-- One-off rewards granted when you reach a rebirth count (string keys!).
RebirthConfig.Milestones = {
	["1"] = { { Type = "Cosmetic", Id = "Trail_Reborn" }, { Type = "Tokens", Amount = 25 } },
	["2"] = { { Type = "Cosmetic", Id = "Frame_Reborn" } },
	["3"] = { { Type = "Cosmetic", Id = "Theme_Galaxy" } },
	["5"] = { { Type = "Cosmetic", Id = "NameTag_Reborn" }, { Type = "Tokens", Amount = 100 } },
	["10"] = { { Type = "Cosmetic", Id = "Effect_Starfall" }, { Type = "Tokens", Amount = 250 } },
}

return RebirthConfig
