--[[
	RewardConfig
	Daily login streak, playtime milestones, collection milestones and tutorial.

	Shared reward format (used by quests, products, events, ...):
		{ Type = "Cash", Amount = 500 }
		{ Type = "CashMinutes", Minutes = 5, Min = 500 }   -- N minutes of your current cash/sec (at least Min)
		{ Type = "Tokens", Amount = 10 }
		{ Type = "EventTokens", Amount = 10 }
		{ Type = "Boost", Boost = "Luck" | "Income" | "Speed" | "Protection", Duration = 600 }
		{ Type = "ServerBoost", Boost = "ServerLuck", Duration = 900 }
		{ Type = "Cosmetic", Id = "Trail_Sparkle" }
		{ Type = "Collectible", Id = "emberpup", Mutation = "Shiny"? }
		{ Type = "RandomCollectible", Rarity = "Epic" }     -- random non-limited collectible of that rarity
		{ Type = "Pack", Pack = "Booster" }                -- free card pack opening
]]

local RewardConfig = {}

-- 7-day streak. Missing more than one full UTC day resets the streak to day 1.
-- After day 7 the cycle repeats with +StreakWeekBonus per completed week (capped).
RewardConfig.Daily = {
	{ { Type = "CashMinutes", Minutes = 5, Min = 500 }, { Type = "Tokens", Amount = 5 } },
	{ { Type = "CashMinutes", Minutes = 10, Min = 2500 }, { Type = "Tokens", Amount = 10 } },
	{ { Type = "Boost", Boost = "Luck", Duration = 600 }, { Type = "Tokens", Amount = 15 } },
	{ { Type = "CashMinutes", Minutes = 20, Min = 10000 }, { Type = "Tokens", Amount = 20 } },
	{ { Type = "Boost", Boost = "Income", Duration = 900 }, { Type = "Tokens", Amount = 30 } },
	{ { Type = "CashMinutes", Minutes = 30, Min = 50000 }, { Type = "Tokens", Amount = 40 } },
	{ { Type = "Pack", Pack = "Booster" }, { Type = "Tokens", Amount = 75 }, { Type = "Cosmetic", Id = "Trail_Sparkle" } },
}
RewardConfig.StreakWeekBonus = 0.25 -- +25% tokens/cash per completed week
RewardConfig.MaxWeekBonus = 1.0

-- Playtime milestones reset every UTC day.
RewardConfig.Playtime = {
	{ Minutes = 5, Rewards = { { Type = "CashMinutes", Minutes = 2, Min = 200 } } },
	{ Minutes = 15, Rewards = { { Type = "Tokens", Amount = 5 } } },
	{ Minutes = 30, Rewards = { { Type = "Boost", Boost = "Luck", Duration = 300 }, { Type = "Tokens", Amount = 5 } } },
	{ Minutes = 60, Rewards = { { Type = "CashMinutes", Minutes = 10, Min = 2000 }, { Type = "Tokens", Amount = 10 } } },
	{ Minutes = 120, Rewards = { { Type = "Boost", Boost = "Income", Duration = 600 }, { Type = "Tokens", Amount = 15 } } },
	{ Minutes = 240, Rewards = { { Type = "RandomCollectible", Rarity = "Epic" }, { Type = "Tokens", Amount = 25 } } },
	{ Minutes = 360, Rewards = { { Type = "Pack", Pack = "Premium" }, { Type = "Tokens", Amount = 40 } } },
}

-- Collection book milestones (percent of non-limited catalogue discovered).
RewardConfig.CollectionMilestones = {
	{ Percent = 25, Rewards = { { Type = "Tokens", Amount = 50 }, { Type = "Cosmetic", Id = "Frame_Holo" } } },
	{ Percent = 50, Rewards = { { Type = "Tokens", Amount = 120 }, { Type = "Boost", Boost = "Luck", Duration = 1800 } } },
	{ Percent = 75, Rewards = { { Type = "Tokens", Amount = 250 }, { Type = "Cosmetic", Id = "Trail_Prism" } } },
	{ Percent = 100, Rewards = { { Type = "Tokens", Amount = 600 }, { Type = "Cosmetic", Id = "Frame_Completionist" }, { Type = "Cosmetic", Id = "NameTag_Completionist" } } },
}

RewardConfig.Tutorial = {
	StepRewards = {
		Claim = { { Type = "Cash", Amount = 50 } },
		Buy = { { Type = "Tokens", Amount = 5 } },
		Upgrade = { { Type = "Tokens", Amount = 5 } },
	},
	Completion = { { Type = "Tokens", Amount = 25 }, { Type = "Boost", Boost = "Luck", Duration = 600 } },
}

return RewardConfig
