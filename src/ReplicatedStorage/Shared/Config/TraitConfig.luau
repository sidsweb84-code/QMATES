--[[
	TraitConfig
	Optional special traits a collectible can roll when it spawns.
]]

local TraitConfig = {}

-- Probability that a spawned collectible has any trait at all.
TraitConfig.Chance = 0.08

TraitConfig.Order = { "Investor", "Lucky", "Speedster", "Guardian", "Jackpot" }

TraitConfig.Traits = {
	Investor = {
		Name = "Investor",
		Icon = "💼",
		Weight = 30,
		Color = Color3.fromRGB(120, 230, 140),
		Description = "+10% income",
		IncomeMultiplier = 1.1,
		PriceMultiplier = 1.15,
	},
	Lucky = {
		Name = "Lucky",
		Icon = "🍀",
		Weight = 25,
		Color = Color3.fromRGB(90, 220, 120),
		Description = "+5% personal luck while placed in your base (max +25%)",
		LuckBonus = 0.05,
		PriceMultiplier = 1.15,
	},
	Speedster = {
		Name = "Speedster",
		Icon = "💨",
		Weight = 20,
		Color = Color3.fromRGB(120, 200, 255),
		Description = "Travels to your base 2x faster",
		TravelSpeedMultiplier = 2,
		PriceMultiplier = 1.05,
	},
	Guardian = {
		Name = "Guardian",
		Icon = "🛡️",
		Weight = 15,
		Color = Color3.fromRGB(255, 210, 90),
		Description = "+50% time needed to steal it",
		StealTimeMultiplier = 1.5,
		PriceMultiplier = 1.2,
	},
	Jackpot = {
		Name = "Jackpot",
		Icon = "🎰",
		Weight = 10,
		Color = Color3.fromRGB(255, 120, 200),
		Description = "Occasionally pays out 45 seconds of its income at once",
		JackpotChancePerSecond = 1 / 180,
		JackpotSeconds = 45,
		PriceMultiplier = 1.2,
	},
}

TraitConfig.MaxLuckBonus = 0.25

function TraitConfig.Get(name: string?)
	if name == nil or name == "" then
		return nil
	end
	return TraitConfig.Traits[name :: string]
end

function TraitConfig.IsValid(name: any): boolean
	return name == nil or name == "" or (type(name) == "string" and TraitConfig.Traits[name] ~= nil)
end

return TraitConfig
