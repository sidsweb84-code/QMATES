--[[
	ConveyorConfig
	Spawning rules for each conveyor. Geometry lives in MapConfig.Conveyors.

	LuckMultiplier stacks with server luck (events, Server Luck product, admin).
	MinRarity removes every rarity below it from that conveyor's odds.
]]

local ConveyorConfig = {}

ConveyorConfig.Conveyors = {
	Main = {
		Name = "Main Conveyor",
		SpawnInterval = 2.4,
		Speed = 7, -- studs per second
		MaxItems = 45,
		LuckMultiplier = 1,
		MinRarity = nil,
		RequiredRebirths = 0,
		BuyRange = 14,
	},
	Elite = {
		Name = "Elite Market",
		SpawnInterval = 6,
		Speed = 5,
		MaxItems = 20,
		LuckMultiplier = 2,
		MinRarity = "Rare",
		RequiredRebirths = 1,
		BuyRange = 14,
	},
}

ConveyorConfig.Order = { "Main", "Elite" }

-- Extra distance tolerance (studs) for latency when validating purchases.
ConveyorConfig.LatencyTolerance = 10

return ConveyorConfig
