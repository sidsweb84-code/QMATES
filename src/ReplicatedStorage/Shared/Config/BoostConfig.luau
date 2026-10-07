--[[
	BoostConfig
	Temporary boosts. Personal boosts are saved (expiry = UTC timestamp);
	server boosts affect everyone in the server and are not saved.
	Buying a boost you already have extends it (up to MaxDuration).
]]

local BoostConfig = {}

BoostConfig.MaxDuration = 6 * 3600

BoostConfig.Personal = {
	Income = { Name = "2x Income", Icon = "💰", Multiplier = 2, Color = Color3.fromRGB(90, 220, 120),
		Description = "Doubles all income." },
	Luck = { Name = "2x Luck", Icon = "🍀", Multiplier = 2, Color = Color3.fromRGB(80, 200, 255),
		Description = "Doubles your personal luck (packs + bonus mutation rolls)." },
	Speed = { Name = "Speed", Icon = "👟", Multiplier = 1.3, Color = Color3.fromRGB(255, 200, 60),
		Description = "+30% walk speed (not while carrying a stolen critter)." },
	Protection = { Name = "Base Shield", Icon = "🛡️", Multiplier = 1, Color = Color3.fromRGB(150, 140, 255),
		Description = "Nobody can steal from your base while active." },
}

BoostConfig.Server = {
	ServerLuck = { Name = "Server Luck x2", Icon = "🌟", Multiplier = 2, Color = Color3.fromRGB(255, 220, 90),
		Description = "Doubles conveyor luck for everyone in the server." },
}

BoostConfig.Order = { "Income", "Luck", "Speed", "Protection" }

return BoostConfig
