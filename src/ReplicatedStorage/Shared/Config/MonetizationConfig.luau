--[[
	MonetizationConfig
	THE ONLY place Robux product / gamepass IDs live.

	SETUP: create each Game Pass and Developer Product on the Creator Dashboard
	(Creations > your experience > Monetization), then paste its numeric ID into
	Id below. Id = 0 means "not configured": the item shows in the store as
	"Coming soon" and cannot be bought. PriceHint is display-only — the real
	price always comes from Roblox (MarketplaceService:GetProductInfo).

	Fairness rules followed here:
	- Robux never buys random rewards (no paid loot boxes).
	- Paid perks are boosts, convenience and cosmetics. Every gameplay system
	  (income, defence, collectibles) is fully reachable for free players.
	- FastWalk does not apply while carrying a stolen collectible.
]]

local MonetizationConfig = {}

MonetizationConfig.Gamepasses = {
	VIP = {
		Id = 0,
		Name = "VIP",
		Icon = "👑",
		PriceHint = 249,
		Description = "+10% income, +5 daily tokens, VIP name tag, gold trail and Royal base theme.",
		Perks = { IncomeMultiplier = 1.1, DailyTokenBonus = 5 },
	},
	ExtraSlots = {
		Id = 0,
		Name = "Extra Base Slots",
		Icon = "➕",
		PriceHint = 299,
		Description = "+5 permanent collectible slots in your base.",
		Perks = { ExtraSlots = 5 },
	},
	FastWalk = {
		Id = 0,
		Name = "Fast Walker",
		Icon = "👟",
		PriceHint = 99,
		Description = "+25% walk speed (disabled while carrying stolen critters).",
		Perks = { SpeedMultiplier = 1.25 },
	},
	CollectorVault = {
		Id = 0,
		Name = "Collector's Vault",
		Icon = "🗄️",
		PriceHint = 149,
		Description = "+20 storage space for critters you are not displaying.",
		Perks = { ExtraStorage = 20 },
	},
	PremiumNameTag = {
		Id = 0,
		Name = "Premium Name Tags",
		Icon = "🏷️",
		PriceHint = 99,
		Description = "Unlocks the animated LEGEND and Mythic Collector name tags.",
		Perks = {},
	},
	BaseEffects = {
		Id = 0,
		Name = "Base Effects Pack",
		Icon = "🎆",
		PriceHint = 149,
		Description = "Sparkles and Aurora particle effects for your base.",
		Perks = {},
	},
	ExclusiveCosmetics = {
		Id = 0,
		Name = "Exclusive Cosmetics",
		Icon = "💠",
		PriceHint = 199,
		Description = "Prism card frame and Galaxy trail.",
		Perks = {},
	},
}

MonetizationConfig.GamepassOrder = { "VIP", "ExtraSlots", "FastWalk", "CollectorVault", "PremiumNameTag", "BaseEffects", "ExclusiveCosmetics" }

-- Developer products. Rewards use the shared reward format (RewardConfig header).
-- Special Type "InstantCollect" collects your uncollected cash x2 (min Minutes of income).
MonetizationConfig.Products = {
	CashSmall = {
		Id = 0,
		Name = "Cash Pouch",
		Icon = "💵",
		PriceHint = 25,
		Description = "10 minutes of your income (min $5K).",
		Rewards = { { Type = "CashMinutes", Minutes = 10, Min = 5000 } },
	},
	CashMedium = {
		Id = 0,
		Name = "Cash Stack",
		Icon = "💰",
		PriceHint = 75,
		Description = "40 minutes of your income (min $25K).",
		Rewards = { { Type = "CashMinutes", Minutes = 40, Min = 25000 } },
	},
	CashLarge = {
		Id = 0,
		Name = "Cash Vault",
		Icon = "🏦",
		PriceHint = 199,
		Description = "2.5 hours of your income (min $150K).",
		Rewards = { { Type = "CashMinutes", Minutes = 150, Min = 150000 } },
	},
	IncomeBoost = {
		Id = 0,
		Name = "2x Income (15 min)",
		Icon = "📈",
		PriceHint = 49,
		Description = "Double income for 15 minutes.",
		Rewards = { { Type = "Boost", Boost = "Income", Duration = 900 } },
	},
	LuckBoost = {
		Id = 0,
		Name = "2x Luck (15 min)",
		Icon = "🍀",
		PriceHint = 49,
		Description = "Double personal luck for 15 minutes.",
		Rewards = { { Type = "Boost", Boost = "Luck", Duration = 900 } },
	},
	ServerLuck = {
		Id = 0,
		Name = "Server Luck x2 (15 min)",
		Icon = "🌟",
		PriceHint = 99,
		Description = "Doubles conveyor luck for EVERYONE in the server.",
		Rewards = { { Type = "ServerBoost", Boost = "ServerLuck", Duration = 900 } },
	},
	Protection = {
		Id = 0,
		Name = "Base Shield (10 min)",
		Icon = "🛡️",
		PriceHint = 39,
		Description = "Nobody can steal from you for 10 minutes.",
		Rewards = { { Type = "Boost", Boost = "Protection", Duration = 600 } },
	},
	InstantCollect = {
		Id = 0,
		Name = "Instant Collect x2",
		Icon = "🧲",
		PriceHint = 19,
		Description = "Collect your pad cash instantly with a 2x bonus (at least 10 minutes of income).",
		Rewards = { { Type = "InstantCollect", Minutes = 10 } },
	},
	EventTokens = {
		Id = 0,
		Name = "Event Token Bundle",
		Icon = "🎟️",
		PriceHint = 49,
		Description = "+150 event tokens for the Event Shop.",
		Rewards = { { Type = "EventTokens", Amount = 150 } },
	},
	CosmeticBundle = {
		Id = 0,
		Name = "Starter Style Bundle",
		Icon = "🎁",
		PriceHint = 99,
		Description = "Flame Trail, Neon card frame and Ocean base theme.",
		Rewards = {
			{ Type = "Cosmetic", Id = "Trail_Flame" },
			{ Type = "Cosmetic", Id = "Frame_Neon" },
			{ Type = "Cosmetic", Id = "Theme_Ocean" },
		},
	},
}

MonetizationConfig.ProductOrder = {
	"CashSmall", "CashMedium", "CashLarge", "IncomeBoost", "LuckBoost", "ServerLuck",
	"Protection", "InstantCollect", "EventTokens", "CosmeticBundle",
}

function MonetizationConfig.GetProductById(id: number): (string?, any)
	if id == 0 then
		return nil, nil
	end
	for key, product in MonetizationConfig.Products do
		if product.Id == id then
			return key, product
		end
	end
	return nil, nil
end

function MonetizationConfig.GetPassById(id: number): (string?, any)
	if id == 0 then
		return nil, nil
	end
	for key, pass in MonetizationConfig.Gamepasses do
		if pass.Id == id then
			return key, pass
		end
	end
	return nil, nil
end

return MonetizationConfig
