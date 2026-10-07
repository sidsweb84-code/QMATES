--[[
	ShopConfig
	Card packs (cash), token boost shop and event shop.
	Card pack odds are displayed in the shop exactly as configured here, and are
	modified only by your personal luck using the same public formula as the
	conveyor (Shared/Util/Odds). Packs are never sold for Robux.
]]

local ShopConfig = {}

ShopConfig.PackOrder = { "Starter", "Booster", "Premium", "Elite", "Mythic" }

ShopConfig.Packs = {
	Starter = {
		Name = "Starter Pack",
		Icon = "🃏",
		Price = 500,
		Color = Color3.fromRGB(150, 210, 255),
		Odds = { Common = 70, Uncommon = 25, Rare = 5 },
	},
	Booster = {
		Name = "Booster Pack",
		Icon = "🎴",
		Price = 20000,
		Color = Color3.fromRGB(140, 255, 160),
		Odds = { Uncommon = 45, Rare = 38, Epic = 15, Legendary = 2 },
	},
	Premium = {
		Name = "Premium Pack",
		Icon = "💎",
		Price = 400000,
		Color = Color3.fromRGB(200, 140, 255),
		Odds = { Rare = 35, Epic = 42, Legendary = 19, Mythic = 4 },
	},
	Elite = {
		Name = "Elite Pack",
		Icon = "👑",
		Price = 6000000,
		Color = Color3.fromRGB(255, 200, 70),
		RequiredRebirths = 1,
		Odds = { Epic = 30, Legendary = 45, Mythic = 20, Divine = 4.6, Secret = 0.4 },
	},
	Mythic = {
		Name = "Mythic Pack",
		Icon = "🌌",
		Price = 30000000,
		Color = Color3.fromRGB(255, 90, 150),
		RequiredRebirths = 3,
		Odds = { Legendary = 40, Mythic = 40, Divine = 17, Secret = 3 },
	},
}

-- Token boost shop.
ShopConfig.BoostItems = {
	{ Id = "boost_income_10", Boost = "Income", Duration = 600, Price = 40 },
	{ Id = "boost_income_30", Boost = "Income", Duration = 1800, Price = 100 },
	{ Id = "boost_luck_10", Boost = "Luck", Duration = 600, Price = 40 },
	{ Id = "boost_luck_30", Boost = "Luck", Duration = 1800, Price = 100 },
	{ Id = "boost_speed_10", Boost = "Speed", Duration = 600, Price = 20 },
	{ Id = "boost_protect_5", Boost = "Protection", Duration = 300, Price = 60 },
}

-- Event shop. Items with an Event field are only sold while that event runs;
-- items without one are sold during any event. Price is in event tokens.
ShopConfig.EventShop = {
	{ Id = "ev_gourdghast", Event = "Halloween", Type = "Collectible", CollectibleId = "gourdghast", Price = 120 },
	{ Id = "ev_hexwhisker", Event = "Halloween", Type = "Collectible", CollectibleId = "hexwhisker", Price = 600 },
	{ Id = "ev_trail_spooky", Event = "Halloween", Type = "Cosmetic", CosmeticId = "Trail_Spooky", Price = 80 },
	{ Id = "ev_frame_spooky", Event = "Halloween", Type = "Cosmetic", CosmeticId = "Frame_Spooky", Price = 100 },
	{ Id = "ev_tag_spooky", Event = "Halloween", Type = "Cosmetic", CosmeticId = "NameTag_Spooky", Price = 60 },
	{ Id = "ev_theme_haunted", Event = "Halloween", Type = "Cosmetic", CosmeticId = "Theme_Haunted", Price = 150 },
	{ Id = "ev_effect_spooky", Event = "Halloween", Type = "Cosmetic", CosmeticId = "Effect_Spooky", Price = 150 },

	{ Id = "ev_frostbell", Event = "Winter", Type = "Collectible", CollectibleId = "frostbell", Price = 120 },
	{ Id = "ev_jinglehorn", Event = "Winter", Type = "Collectible", CollectibleId = "jinglehorn", Price = 600 },
	{ Id = "ev_trail_snow", Event = "Winter", Type = "Cosmetic", CosmeticId = "Trail_Snow", Price = 80 },
	{ Id = "ev_frame_frost", Event = "Winter", Type = "Cosmetic", CosmeticId = "Frame_Frost", Price = 100 },
	{ Id = "ev_effect_snow", Event = "Winter", Type = "Cosmetic", CosmeticId = "Effect_Snowfall", Price = 150 },

	{ Id = "ev_sunsplash", Event = "Summer", Type = "Collectible", CollectibleId = "sunsplash", Price = 120 },
	{ Id = "ev_trail_sunny", Event = "Summer", Type = "Cosmetic", CosmeticId = "Trail_Sunny", Price = 80 },

	{ Id = "ev_clovercub", Event = "LuckyHour", Type = "Collectible", CollectibleId = "clovercub", Price = 40 },
	{ Id = "ev_confettix", Event = "Celebration", Type = "Collectible", CollectibleId = "confettix", Price = 800 },

	{ Id = "ev_luck_15", Type = "Boost", Boost = "Luck", Duration = 900, Price = 30 },
	{ Id = "ev_income_15", Type = "Boost", Boost = "Income", Duration = 900, Price = 30 },
}

return ShopConfig
