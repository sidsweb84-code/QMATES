--[[
	UpgradeConfig
	All base / security upgrade levels and their costs (in Cash).
	Level 1 of each "Tracks" entry is the free starting level.
]]

local UpgradeConfig = {}

-- Base capacity: collectibles placed in base slots generate income.
UpgradeConfig.BaseLevels = {
	{ Slots = 6, Cost = 0 },
	{ Slots = 8, Cost = 2500 },
	{ Slots = 10, Cost = 20000 },
	{ Slots = 12, Cost = 150000 },
	{ Slots = 15, Cost = 1000000 },
	{ Slots = 18, Cost = 7500000 },
	{ Slots = 21, Cost = 50000000 },
	{ Slots = 24, Cost = 300000000 },
	{ Slots = 27, Cost = 2000000000 },
	{ Slots = 30, Cost = 12000000000 },
}

-- The base model always has this many physical slot pedestals (max level slots +
-- the Extra Slots gamepass). Keep >= last BaseLevels.Slots + ExtraSlots perk.
UpgradeConfig.PhysicalSlots = 36

-- Storage holds collectibles that are not placed (no income, cannot be stolen).
UpgradeConfig.Storage = {
	BaseCapacity = 10,
}

-- Card levelling (spend cash to raise a single card's income).
UpgradeConfig.CardLevels = {
	MaxLevel = 10,
	IncomePerLevel = 0.2, -- +20% base income per level above 1
	CostFactor = 0.35, -- first level-up costs 35% of the card's value
	CostGrowth = 1.55,
}

UpgradeConfig.Tracks = {
	Security = {
		Name = "Security System",
		Icon = "🔒",
		Description = "Longer base locks and slower thieves.",
		Levels = {
			{ Cost = 0, LockDuration = 45, StealTimeMultiplier = 1.0 },
			{ Cost = 1000, LockDuration = 60, StealTimeMultiplier = 1.1 },
			{ Cost = 25000, LockDuration = 75, StealTimeMultiplier = 1.2 },
			{ Cost = 400000, LockDuration = 90, StealTimeMultiplier = 1.3 },
			{ Cost = 6000000, LockDuration = 120, StealTimeMultiplier = 1.45 },
			{ Cost = 100000000, LockDuration = 150, StealTimeMultiplier = 1.6 },
		},
	},
	Alarm = {
		Name = "Theft Detection",
		Icon = "🚨",
		Description = "Know when intruders arrive.",
		Levels = {
			{ Cost = 0, Feature = "Alerts you when a theft starts" },
			{ Cost = 5000, Feature = "Alerts you when anyone enters your base" },
			{ Cost = 250000, Feature = "Highlights intruders through walls" },
		},
	},
	Traps = {
		Name = "Trap Floor",
		Icon = "⚡",
		Description = "Stun pads that zap thieves and make them drop loot.",
		Levels = {
			{ Cost = 0, Count = 0, StunDuration = 0 },
			{ Cost = 15000, Count = 2, StunDuration = 2 },
			{ Cost = 500000, Count = 4, StunDuration = 2.5 },
			{ Cost = 20000000, Count = 6, StunDuration = 3 },
		},
		RearmTime = 12,
		Radius = 3.5,
	},
	AntiSteal = {
		Name = "Anti-Steal Cooldown",
		Icon = "🛡️",
		Description = "Protection after someone robs you.",
		Levels = {
			{ Cost = 0, Protection = 30 },
			{ Cost = 10000, Protection = 60 },
			{ Cost = 750000, Protection = 90 },
			{ Cost = 30000000, Protection = 120 },
		},
	},
	AutoCollect = {
		Name = "Auto-Collector",
		Icon = "🧲",
		Description = "Income goes straight to your wallet — no pad needed.",
		Levels = {
			{ Cost = 0, Enabled = false },
			{ Cost = 75000, Enabled = true },
		},
	},
}

UpgradeConfig.TrackOrder = { "Security", "Alarm", "Traps", "AntiSteal", "AutoCollect" }

return UpgradeConfig
