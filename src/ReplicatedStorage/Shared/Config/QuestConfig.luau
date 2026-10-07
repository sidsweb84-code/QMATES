--[[
	QuestConfig
	Daily quests (3 chosen per UTC day from DailyPool) and lifetime achievement
	series. Progress is driven by server "actions" (see server ActionBus):

		Acquire   any collectible gained (buy, pack, steal, reward)  ctx: Rarity, Mutation
		Buy       bought from a conveyor
		Earn      cash earned (amount)
		Collect   collected cash from the collector pad
		Steal     successful steal
		Catch     caught a thief in your base
		LevelUp   levelled up a collectible
		Sell      sold a collectible
		OpenPack  opened a card pack
		Lock      locked your base
		Playtime  minutes played
		Upgrade   bought a base/security upgrade
		Rebirth   rebirthed

	Filters: MinRarity = "Legendary" (ctx.Rarity must be >= that tier)
	         Mutated = true (ctx.Mutation must not be "Normal")
	Scale = "Rebirth": Target is multiplied by RebirthConfig.CostGrowth ^ rebirths
	Rewards use the shared reward format (see RewardConfig header).
]]

local QuestConfig = {}

QuestConfig.DailyCount = 3
QuestConfig.FreeRerollsPerDay = 1

QuestConfig.DailyPool = {
	{ Id = "d_acquire10", Action = "Acquire", Target = 10, Text = "Collect {n} critters",
		Rewards = { { Type = "Tokens", Amount = 15 }, { Type = "CashMinutes", Minutes = 5, Min = 500 } } },
	{ Id = "d_earn", Action = "Earn", Target = 50000, Scale = "Rebirth", Text = "Earn {n} cash",
		Rewards = { { Type = "Tokens", Amount = 20 } } },
	{ Id = "d_steal3", Action = "Steal", Target = 3, Text = "Successfully steal {n} critters",
		Rewards = { { Type = "Tokens", Amount = 25 }, { Type = "Boost", Boost = "Luck", Duration = 300 } } },
	{ Id = "d_play30", Action = "Playtime", Target = 30, Text = "Play for {n} minutes",
		Rewards = { { Type = "Tokens", Amount = 15 }, { Type = "Boost", Boost = "Income", Duration = 300 } } },
	{ Id = "d_legendary", Action = "Acquire", Target = 1, MinRarity = "Legendary", Text = "Discover a Legendary or better",
		Rewards = { { Type = "Tokens", Amount = 30 } } },
	{ Id = "d_collect15", Action = "Collect", Target = 15, Text = "Collect cash from your pad {n} times",
		Rewards = { { Type = "Tokens", Amount = 10 }, { Type = "CashMinutes", Minutes = 3, Min = 300 } } },
	{ Id = "d_catch1", Action = "Catch", Target = 1, Text = "Catch a thief in your base",
		Rewards = { { Type = "Tokens", Amount = 20 } } },
	{ Id = "d_levelup3", Action = "LevelUp", Target = 3, Text = "Level up critters {n} times",
		Rewards = { { Type = "Tokens", Amount = 15 } } },
	{ Id = "d_pack2", Action = "OpenPack", Target = 2, Text = "Open {n} card packs",
		Rewards = { { Type = "Tokens", Amount = 15 } } },
	{ Id = "d_lock3", Action = "Lock", Target = 3, Text = "Lock your base {n} times",
		Rewards = { { Type = "Tokens", Amount = 10 } } },
	{ Id = "d_mutated", Action = "Acquire", Target = 1, Mutated = true, Text = "Get a mutated critter",
		Rewards = { { Type = "Tokens", Amount = 20 } } },
	{ Id = "d_rare5", Action = "Acquire", Target = 5, MinRarity = "Rare", Text = "Collect {n} Rare-or-better critters",
		Rewards = { { Type = "Tokens", Amount = 20 }, { Type = "CashMinutes", Minutes = 5, Min = 1000 } } },
}

--[[
	Achievements: each series has increasing tiers. Progress either accumulates
	from an Action (with optional filters) or reads a Stat directly:
		Stat = "TotalEarned" | "Rebirths" | "CollectionCount" | "PlaytimeHours"
]]
QuestConfig.Achievements = {
	{ Id = "Collector", Name = "Collector", Icon = "🎴", Action = "Acquire", Text = "Collect {n} critters",
		Tiers = {
			{ Target = 10, Rewards = { { Type = "Tokens", Amount = 10 } } },
			{ Target = 50, Rewards = { { Type = "Tokens", Amount = 25 } } },
			{ Target = 200, Rewards = { { Type = "Tokens", Amount = 60 } } },
			{ Target = 1000, Rewards = { { Type = "Tokens", Amount = 150 }, { Type = "Cosmetic", Id = "NameTag_Collector" } } },
		} },
	{ Id = "Tycoon", Name = "Tycoon", Icon = "💰", Stat = "TotalEarned", Text = "Earn {n} cash in total",
		Tiers = {
			{ Target = 10000, Rewards = { { Type = "Tokens", Amount = 10 } } },
			{ Target = 1000000, Rewards = { { Type = "Tokens", Amount = 30 } } },
			{ Target = 100000000, Rewards = { { Type = "Tokens", Amount = 75 } } },
			{ Target = 10000000000, Rewards = { { Type = "Tokens", Amount = 200 }, { Type = "Cosmetic", Id = "NameTag_Tycoon" } } },
		} },
	{ Id = "MasterThief", Name = "Master Thief", Icon = "🦹", Action = "Steal", Text = "Steal {n} critters",
		Tiers = {
			{ Target = 1, Rewards = { { Type = "Tokens", Amount = 10 } } },
			{ Target = 10, Rewards = { { Type = "Tokens", Amount = 30 } } },
			{ Target = 50, Rewards = { { Type = "Tokens", Amount = 80 }, { Type = "Cosmetic", Id = "NameTag_Thief" } } },
			{ Target = 250, Rewards = { { Type = "Tokens", Amount = 200 } } },
		} },
	{ Id = "Guardian", Name = "Guardian", Icon = "🛡️", Action = "Catch", Text = "Catch {n} thieves",
		Tiers = {
			{ Target = 1, Rewards = { { Type = "Tokens", Amount = 10 } } },
			{ Target = 10, Rewards = { { Type = "Tokens", Amount = 30 } } },
			{ Target = 50, Rewards = { { Type = "Tokens", Amount = 100 }, { Type = "Cosmetic", Id = "NameTag_Guardian" } } },
		} },
	{ Id = "Dedicated", Name = "Dedicated", Icon = "⏰", Stat = "PlaytimeHours", Text = "Play for {n} hours",
		Tiers = {
			{ Target = 1, Rewards = { { Type = "Tokens", Amount = 15 } } },
			{ Target = 10, Rewards = { { Type = "Tokens", Amount = 50 } } },
			{ Target = 50, Rewards = { { Type = "Tokens", Amount = 150 } } },
		} },
	{ Id = "Reborn", Name = "Reborn", Icon = "♻️", Stat = "Rebirths", Text = "Rebirth {n} times",
		Tiers = {
			{ Target = 1, Rewards = { { Type = "Tokens", Amount = 20 } } },
			{ Target = 5, Rewards = { { Type = "Tokens", Amount = 75 } } },
			{ Target = 10, Rewards = { { Type = "Tokens", Amount = 150 } } },
			{ Target = 25, Rewards = { { Type = "Tokens", Amount = 400 } } },
		} },
	{ Id = "Discoverer", Name = "Discoverer", Icon = "📖", Stat = "CollectionCount", Text = "Discover {n} different critters",
		Tiers = {
			{ Target = 10, Rewards = { { Type = "Tokens", Amount = 15 } } },
			{ Target = 25, Rewards = { { Type = "Tokens", Amount = 40 } } },
			{ Target = 50, Rewards = { { Type = "Tokens", Amount = 100 } } },
		} },
	{ Id = "Lucky", Name = "Lucky Star", Icon = "🌟", Action = "Acquire", MinRarity = "Legendary", Text = "Get {n} Legendary-or-better critters",
		Tiers = {
			{ Target = 1, Rewards = { { Type = "Tokens", Amount = 15 } } },
			{ Target = 10, Rewards = { { Type = "Tokens", Amount = 50 } } },
			{ Target = 50, Rewards = { { Type = "Tokens", Amount = 150 } } },
		} },
	{ Id = "MutationHunter", Name = "Mutation Hunter", Icon = "🧬", Action = "Acquire", Mutated = true, Text = "Get {n} mutated critters",
		Tiers = {
			{ Target = 1, Rewards = { { Type = "Tokens", Amount = 10 } } },
			{ Target = 25, Rewards = { { Type = "Tokens", Amount = 50 } } },
			{ Target = 100, Rewards = { { Type = "Tokens", Amount = 150 } } },
		} },
}

return QuestConfig
