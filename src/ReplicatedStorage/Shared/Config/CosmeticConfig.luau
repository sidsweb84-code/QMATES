--[[
	CosmeticConfig
	Purely visual items. Nothing here affects income, luck or stealing.

	Types: Trail | NameTag | CardFrame | BaseTheme | BaseEffect
	Unlock:
		{ Type = "Default" }                          owned by everyone
		{ Type = "Tokens", Price = 50 }               buy in the Cosmetic Shop
		{ Type = "Gamepass", Pass = "VIP" }           owned with a gamepass
		{ Type = "Reward" }                           granted by achievements / rebirths / collection
		{ Type = "Event" }                            sold in the Event Shop (see ShopConfig.EventShop)
]]

local C = Color3.fromRGB

local CosmeticConfig = {}

CosmeticConfig.Types = { "Trail", "NameTag", "CardFrame", "BaseTheme", "BaseEffect" }

CosmeticConfig.TypeInfo = {
	Trail = { Name = "Trails", Icon = "🌠" },
	NameTag = { Name = "Name Tags", Icon = "🏷️" },
	CardFrame = { Name = "Card Frames", Icon = "🖼️" },
	BaseTheme = { Name = "Base Themes", Icon = "🏠" },
	BaseEffect = { Name = "Base Effects", Icon = "🎆" },
}

CosmeticConfig.Defaults = {
	Trail = "",
	NameTag = "NameTag_Rookie",
	CardFrame = "Frame_Classic",
	BaseTheme = "Theme_Default",
	BaseEffect = "Effect_None",
}

CosmeticConfig.Items = {
	------------------------------------------------------------------ TRAILS
	Trail_Sparkle = { Type = "Trail", Name = "Sparkle Trail", Colors = { C(255, 255, 255), C(255, 240, 150) },
		Unlock = { Type = "Tokens", Price = 50 } },
	Trail_Flame = { Type = "Trail", Name = "Flame Trail", Colors = { C(255, 230, 80), C(255, 90, 20) },
		Unlock = { Type = "Tokens", Price = 100 } },
	Trail_Aqua = { Type = "Trail", Name = "Tide Trail", Colors = { C(150, 240, 255), C(20, 120, 255) },
		Unlock = { Type = "Tokens", Price = 100 } },
	Trail_Rainbow = { Type = "Trail", Name = "Rainbow Trail",
		Colors = { C(255, 70, 70), C(255, 200, 60), C(80, 230, 100), C(60, 160, 255), C(190, 90, 255) },
		Unlock = { Type = "Tokens", Price = 300 } },
	Trail_Prism = { Type = "Trail", Name = "Prism Trail", Colors = { C(120, 255, 240), C(255, 120, 230), C(255, 255, 255) },
		Unlock = { Type = "Reward" }, Hint = "Reach 75% collection" },
	Trail_Reborn = { Type = "Trail", Name = "Reborn Aura", Colors = { C(120, 255, 170), C(40, 200, 255) },
		Unlock = { Type = "Reward" }, Hint = "Rebirth once" },
	Trail_VIP = { Type = "Trail", Name = "VIP Gold Trail", Colors = { C(255, 245, 170), C(255, 180, 20) },
		Unlock = { Type = "Gamepass", Pass = "VIP" } },
	Trail_Galaxy = { Type = "Trail", Name = "Galaxy Trail", Colors = { C(40, 20, 120), C(160, 80, 255), C(255, 255, 255) },
		Unlock = { Type = "Gamepass", Pass = "ExclusiveCosmetics" } },
	Trail_Spooky = { Type = "Trail", Name = "Spooky Trail", Colors = { C(255, 120, 0), C(120, 0, 200) },
		Unlock = { Type = "Event" }, Hint = "Halloween Event Shop" },
	Trail_Snow = { Type = "Trail", Name = "Snowy Trail", Colors = { C(255, 255, 255), C(170, 220, 255) },
		Unlock = { Type = "Event" }, Hint = "Winter Event Shop" },
	Trail_Sunny = { Type = "Trail", Name = "Sunny Trail", Colors = { C(255, 240, 90), C(255, 120, 160) },
		Unlock = { Type = "Event" }, Hint = "Summer Event Shop" },

	------------------------------------------------------------------ NAME TAGS
	NameTag_Rookie = { Type = "NameTag", Name = "Rookie", Text = "Rookie", Color = C(200, 210, 225),
		Unlock = { Type = "Default" } },
	NameTag_Rich = { Type = "NameTag", Name = "High Roller", Text = "High Roller", Color = C(120, 255, 140),
		Unlock = { Type = "Tokens", Price = 200 } },
	NameTag_Collector = { Type = "NameTag", Name = "Collector", Text = "Collector", Color = C(120, 200, 255),
		Unlock = { Type = "Reward" }, Hint = "Collector achievement (tier 4)" },
	NameTag_Tycoon = { Type = "NameTag", Name = "Tycoon", Text = "Tycoon", Color = C(255, 215, 80),
		Unlock = { Type = "Reward" }, Hint = "Tycoon achievement (tier 4)" },
	NameTag_Thief = { Type = "NameTag", Name = "Master Thief", Text = "Master Thief", Color = C(255, 90, 90),
		Unlock = { Type = "Reward" }, Hint = "Master Thief achievement (tier 3)" },
	NameTag_Guardian = { Type = "NameTag", Name = "Guardian", Text = "Guardian", Color = C(150, 140, 255),
		Unlock = { Type = "Reward" }, Hint = "Guardian achievement (tier 3)" },
	NameTag_Reborn = { Type = "NameTag", Name = "Reborn", Text = "♻ Reborn", Color = C(120, 255, 200),
		Unlock = { Type = "Reward" }, Hint = "Reach 5 rebirths" },
	NameTag_Completionist = { Type = "NameTag", Name = "Completionist", Text = "★ Completionist", Color = C(255, 240, 120),
		Unlock = { Type = "Reward" }, Hint = "Complete the collection" },
	NameTag_VIP = { Type = "NameTag", Name = "VIP", Text = "👑 VIP", Color = C(255, 205, 60),
		Unlock = { Type = "Gamepass", Pass = "VIP" } },
	NameTag_Legend = { Type = "NameTag", Name = "Legend", Text = "LEGEND", Color = C(255, 255, 255), Rainbow = true,
		Unlock = { Type = "Gamepass", Pass = "PremiumNameTag" } },
	NameTag_Mythic = { Type = "NameTag", Name = "Mythic Collector", Text = "Mythic Collector", Color = C(255, 90, 140),
		Unlock = { Type = "Gamepass", Pass = "PremiumNameTag" } },
	NameTag_Spooky = { Type = "NameTag", Name = "Spooky", Text = "🎃 Spooky", Color = C(255, 140, 30),
		Unlock = { Type = "Event" }, Hint = "Halloween Event Shop" },

	------------------------------------------------------------------ CARD FRAMES
	Frame_Classic = { Type = "CardFrame", Name = "Classic", Colors = { C(255, 255, 255), C(200, 205, 215) },
		Unlock = { Type = "Default" } },
	Frame_Neon = { Type = "CardFrame", Name = "Neon", Colors = { C(0, 255, 200), C(255, 0, 200) },
		Unlock = { Type = "Tokens", Price = 250 } },
	Frame_Gold = { Type = "CardFrame", Name = "Gold Leaf", Colors = { C(255, 245, 170), C(220, 150, 20) },
		Unlock = { Type = "Tokens", Price = 400 } },
	Frame_Holo = { Type = "CardFrame", Name = "Holo Silver", Colors = { C(220, 255, 255), C(255, 200, 255) },
		Unlock = { Type = "Reward" }, Hint = "Reach 25% collection" },
	Frame_Reborn = { Type = "CardFrame", Name = "Reborn", Colors = { C(120, 255, 170), C(40, 160, 255) },
		Unlock = { Type = "Reward" }, Hint = "Reach 2 rebirths" },
	Frame_Completionist = { Type = "CardFrame", Name = "Completionist", Colors = { C(255, 240, 120), C(255, 90, 200) },
		Unlock = { Type = "Reward" }, Hint = "Complete the collection" },
	Frame_Prism = { Type = "CardFrame", Name = "Prism", Colors = { C(255, 80, 80), C(80, 160, 255) }, Rainbow = true,
		Unlock = { Type = "Gamepass", Pass = "ExclusiveCosmetics" } },
	Frame_Spooky = { Type = "CardFrame", Name = "Haunted", Colors = { C(255, 120, 0), C(60, 0, 90) },
		Unlock = { Type = "Event" }, Hint = "Halloween Event Shop" },
	Frame_Frost = { Type = "CardFrame", Name = "Frostbite", Colors = { C(255, 255, 255), C(100, 190, 255) },
		Unlock = { Type = "Event" }, Hint = "Winter Event Shop" },

	------------------------------------------------------------------ BASE THEMES
	Theme_Default = { Type = "BaseTheme", Name = "Classic", Floor = C(236, 240, 247), Wall = C(120, 140, 220), Trim = C(255, 210, 90),
		Unlock = { Type = "Default" } },
	Theme_Ocean = { Type = "BaseTheme", Name = "Ocean", Floor = C(200, 240, 255), Wall = C(30, 140, 220), Trim = C(120, 255, 240),
		Unlock = { Type = "Tokens", Price = 150 } },
	Theme_Forest = { Type = "BaseTheme", Name = "Forest", Floor = C(210, 240, 190), Wall = C(70, 140, 70), Trim = C(255, 220, 120),
		Unlock = { Type = "Tokens", Price = 150 } },
	Theme_Volcano = { Type = "BaseTheme", Name = "Volcano", Floor = C(70, 50, 50), Wall = C(40, 30, 30), Trim = C(255, 90, 20),
		Unlock = { Type = "Tokens", Price = 250 } },
	Theme_Candy = { Type = "BaseTheme", Name = "Candy", Floor = C(255, 225, 240), Wall = C(255, 130, 190), Trim = C(140, 230, 255),
		Unlock = { Type = "Tokens", Price = 250 } },
	Theme_Galaxy = { Type = "BaseTheme", Name = "Galaxy", Floor = C(30, 25, 60), Wall = C(70, 40, 150), Trim = C(140, 220, 255),
		Unlock = { Type = "Reward" }, Hint = "Reach 3 rebirths" },
	Theme_Royal = { Type = "BaseTheme", Name = "Royal", Floor = C(250, 240, 220), Wall = C(120, 30, 60), Trim = C(255, 210, 60),
		Unlock = { Type = "Gamepass", Pass = "VIP" } },
	Theme_Haunted = { Type = "BaseTheme", Name = "Haunted", Floor = C(50, 40, 60), Wall = C(30, 20, 40), Trim = C(255, 120, 0),
		Unlock = { Type = "Event" }, Hint = "Halloween Event Shop" },

	------------------------------------------------------------------ BASE EFFECTS
	Effect_None = { Type = "BaseEffect", Name = "None", Unlock = { Type = "Default" } },
	Effect_Fireflies = { Type = "BaseEffect", Name = "Fireflies", Color = C(220, 255, 120), Rate = 6, Speed = 1, Size = 0.35,
		Unlock = { Type = "Tokens", Price = 200 } },
	Effect_Embers = { Type = "BaseEffect", Name = "Embers", Color = C(255, 130, 40), Rate = 8, Speed = 3, Size = 0.3,
		Unlock = { Type = "Tokens", Price = 200 } },
	Effect_Sparkles = { Type = "BaseEffect", Name = "Sparkles", Color = C(255, 255, 255), Rate = 10, Speed = 1.5, Size = 0.4,
		Unlock = { Type = "Gamepass", Pass = "BaseEffects" } },
	Effect_Aurora = { Type = "BaseEffect", Name = "Aurora", Color = C(120, 255, 220), Rate = 5, Speed = 0.6, Size = 1.4,
		Unlock = { Type = "Gamepass", Pass = "BaseEffects" } },
	Effect_Starfall = { Type = "BaseEffect", Name = "Starfall", Color = C(255, 240, 160), Rate = 8, Speed = 6, Size = 0.5,
		Unlock = { Type = "Reward" }, Hint = "Reach 10 rebirths" },
	Effect_Snowfall = { Type = "BaseEffect", Name = "Snowfall", Color = C(255, 255, 255), Rate = 14, Speed = 4, Size = 0.35,
		Unlock = { Type = "Event" }, Hint = "Winter Event Shop" },
	Effect_Spooky = { Type = "BaseEffect", Name = "Ghost Lights", Color = C(170, 90, 255), Rate = 6, Speed = 1, Size = 0.7,
		Unlock = { Type = "Event" }, Hint = "Halloween Event Shop" },
}

function CosmeticConfig.Get(id: string?)
	if id == nil or id == "" then
		return nil
	end
	return CosmeticConfig.Items[id :: string]
end

return CosmeticConfig
