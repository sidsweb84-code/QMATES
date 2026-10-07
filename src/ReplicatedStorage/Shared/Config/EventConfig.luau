--[[
	EventConfig
	Modular events. Add a new entry to Events and (optionally) schedule it.

	Modifiers (all optional, multiplied together when several events overlap):
		IncomeMultiplier            number
		LuckMultiplier              number (conveyor + personal luck)
		RarityWeightMultipliers     { [rarity] = number }
		MutationChanceMultipliers   { [mutation] = number }
		EnableMutations             { "Cosmic" }        -- turns on EventOnly mutations
		EnableMutationChance        { Cosmic = 0.001 }  -- base chance used while enabled
		LimitedWeight               number  -- spawn weight for this event's Limited collectibles
		EventTokensPerPurchase      number  -- event tokens earned per conveyor purchase
	Decorations: "Halloween" | "Winter" | "Summer" | "Sparkle" | nil (built by EventService)
	Lighting: optional { ClockTime, FogEnd, FogColor, Ambient }
	Currency: display name/icon for event tokens while this event is active
]]

local EventConfig = {}

EventConfig.Events = {
	DoubleCash = {
		Name = "Double Cash",
		Icon = "💸",
		Color = Color3.fromRGB(80, 220, 120),
		Description = "All income is doubled!",
		Modifiers = { IncomeMultiplier = 2 },
	},
	LuckyHour = {
		Name = "Lucky Hour",
		Icon = "🍀",
		Color = Color3.fromRGB(60, 200, 90),
		Description = "Luck x2 for everyone — and Clovercub can appear!",
		Modifiers = { LuckMultiplier = 2, LimitedWeight = 25, EventTokensPerPurchase = 1 },
		Decorations = "Sparkle",
	},
	LegendaryRush = {
		Name = "Legendary Rush",
		Icon = "👑",
		Color = Color3.fromRGB(255, 190, 40),
		Description = "Legendary and better critters spawn 3x more often!",
		Modifiers = { RarityWeightMultipliers = { Legendary = 3, Mythic = 3, Divine = 2, Secret = 2 } },
		Decorations = "Sparkle",
	},
	RainbowEvent = {
		Name = "Rainbow Rain",
		Icon = "🌈",
		Color = Color3.fromRGB(255, 120, 220),
		Description = "Rainbow mutations are 5x more common!",
		Modifiers = { MutationChanceMultipliers = { Rainbow = 5, Holographic = 2 } },
		Decorations = "Sparkle",
	},
	ShinyWeekend = {
		Name = "Shiny Weekend",
		Icon = "✨",
		Color = Color3.fromRGB(255, 240, 120),
		Description = "Shiny mutations are 3x more common all weekend!",
		Modifiers = { MutationChanceMultipliers = { Shiny = 3, Golden = 1.5 } },
	},
	Halloween = {
		Name = "Halloween Haunt",
		Icon = "🎃",
		Color = Color3.fromRGB(255, 120, 20),
		Description = "Spooky Limited critters roam the conveyor. Earn Candy for the Event Shop!",
		Modifiers = {
			LimitedWeight = 30,
			MutationChanceMultipliers = { Dark = 2 },
			EventTokensPerPurchase = 1,
		},
		Decorations = "Halloween",
		Lighting = { ClockTime = 18.2, FogEnd = 900, FogColor = Color3.fromRGB(70, 40, 90) },
		Currency = { Name = "Candy", Icon = "🍬" },
	},
	Winter = {
		Name = "Winter Wonderland",
		Icon = "❄️",
		Color = Color3.fromRGB(150, 220, 255),
		Description = "Frosty Limited critters and snowfall. Earn Snowflakes for the Event Shop!",
		Modifiers = { LimitedWeight = 30, EventTokensPerPurchase = 1 },
		Decorations = "Winter",
		Lighting = { ClockTime = 15, FogEnd = 1200, FogColor = Color3.fromRGB(220, 235, 255) },
		Currency = { Name = "Snowflakes", Icon = "❄️" },
	},
	Summer = {
		Name = "Summer Splash",
		Icon = "🏖️",
		Color = Color3.fromRGB(255, 210, 60),
		Description = "Sunny Limited critters and +25% income. Earn Shells for the Event Shop!",
		Modifiers = { LimitedWeight = 30, IncomeMultiplier = 1.25, EventTokensPerPurchase = 1 },
		Decorations = "Summer",
		Lighting = { ClockTime = 13 },
		Currency = { Name = "Shells", Icon = "🐚" },
	},
	Celebration = {
		Name = "Grand Celebration",
		Icon = "🎉",
		Color = Color3.fromRGB(255, 80, 160),
		Description = "Cosmic mutations unlocked and Confettix appears! (admin-triggered)",
		Modifiers = {
			LimitedWeight = 20,
			EnableMutations = { "Cosmic" },
			EnableMutationChance = { Cosmic = 0.0015 },
			LuckMultiplier = 1.5,
			EventTokensPerPurchase = 2,
		},
		Decorations = "Sparkle",
		Currency = { Name = "Confetti", Icon = "🎊" },
	},
}

-- Automatic schedule. All servers compute the same schedule from UTC time,
-- so rotating events are effectively global.
EventConfig.Schedule = {
	Rotation = {
		Enabled = true,
		Period = 1800, -- a rotating event starts every 30 minutes...
		Duration = 600, -- ...and lasts 10 minutes
		Pool = { "DoubleCash", "LuckyHour", "LegendaryRush", "RainbowEvent" },
	},
	Weekend = {
		Enabled = true,
		Event = "ShinyWeekend", -- Saturday + Sunday (UTC)
	},
	Seasonal = {
		{ Event = "Halloween", StartMonth = 10, StartDay = 1, EndMonth = 11, EndDay = 2 },
		{ Event = "Winter", StartMonth = 12, StartDay = 1, EndMonth = 1, EndDay = 6 },
		{ Event = "Summer", StartMonth = 6, StartDay = 21, EndMonth = 8, EndDay = 31 },
	},
}

EventConfig.DefaultCurrency = { Name = "Event Tokens", Icon = "🎟️" }

return EventConfig
