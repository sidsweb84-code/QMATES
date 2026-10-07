--[[
	MapConfig
	Layout of the procedurally generated map. Used by the server MapBuilder and
	by client systems (tutorial arrows, quick travel, conveyor animation).

	Plot local space: origin = centre of the plot floor at ground level,
	-Z = front (entrance, facing the conveyor), +Z = back wall.
]]

local MapConfig = {}

MapConfig.GroundCenter = Vector3.new(-20, -2, 0)
MapConfig.GroundSize = Vector3.new(800, 4, 360)

MapConfig.Plot = {
	Size = Vector3.new(70, 1, 90),
	FloorHeight = 1, -- top of floor above ground
	WallHeight = 11,
	WallThickness = 1.5,
	EntranceWidth = 18,
	Spawn = Vector3.new(0, 1, 36),
	CollectPad = Vector3.new(-21, 1, -36),
	LockTerminal = Vector3.new(21, 1, -37),
	Terminals = {
		{ Id = "Upgrades", Position = Vector3.new(-26, 1, 40), Label = "UPGRADES", Icon = "⬆️", Window = "Shop", Tab = "Upgrades", Color = Color3.fromRGB(90, 200, 255) },
		{ Id = "Security", Position = Vector3.new(-13, 1, 40), Label = "SECURITY", Icon = "🛡️", Window = "Shop", Tab = "Upgrades", Color = Color3.fromRGB(150, 140, 255) },
		{ Id = "Rebirth", Position = Vector3.new(13, 1, 40), Label = "REBIRTH", Icon = "♻️", Window = "Rebirth", Color = Color3.fromRGB(120, 255, 170) },
		{ Id = "Shop", Position = Vector3.new(26, 1, 40), Label = "SHOP", Icon = "🛒", Window = "Shop", Tab = "Packs", Color = Color3.fromRGB(255, 200, 70) },
	},
	SlotColumns = { -26, -15.6, -5.2, 5.2, 15.6, 26 },
	SlotRows = { -24, -14.5, -5, 4.5, 14, 23.5 },
	PedestalRadius = 3.2,
	Traps = {
		Vector3.new(-5, 1, -30.5),
		Vector3.new(5, 1, -30.5),
		Vector3.new(-16, 1, -30.5),
		Vector3.new(16, 1, -30.5),
		Vector3.new(-27, 1, -30.5),
		Vector3.new(27, 1, -30.5),
	},
	-- Bounds used for "is this player inside the base" checks (local space).
	BoundsMin = Vector3.new(-35, -6, -45),
	BoundsMax = Vector3.new(35, 40, 45),
}

-- Eight plots: four north of the conveyor, four south (rotated to face it).
local plotXs = { -120, -40, 40, 120 }
MapConfig.PlotOrigins = {}
for _, x in plotXs do
	table.insert(MapConfig.PlotOrigins, CFrame.new(x, 0, 70))
end
for _, x in plotXs do
	table.insert(MapConfig.PlotOrigins, CFrame.new(x, 0, -70) * CFrame.Angles(0, math.pi, 0))
end

MapConfig.Conveyors = {
	Main = {
		Start = Vector3.new(-175, 3, 0),
		End = Vector3.new(175, 3, 0),
		Width = 12,
		Height = 3, -- belt top above ground
		Color = Color3.fromRGB(60, 64, 90),
		Accent = Color3.fromRGB(110, 200, 255),
	},
	Elite = {
		Start = Vector3.new(290, 3, -72),
		End = Vector3.new(290, 3, 72),
		Width = 12,
		Height = 3,
		Color = Color3.fromRGB(70, 40, 90),
		Accent = Color3.fromRGB(255, 200, 70),
	},
}

MapConfig.Hub = {
	Center = Vector3.new(-280, 0, 0),
	Radius = 46,
	TeleportPoint = Vector3.new(-250, 3, 0),
}

MapConfig.EliteArea = {
	Min = Vector3.new(216, 0, -100),
	Max = Vector3.new(360, 40, 100),
	GateCenter = Vector3.new(216, 0, 0),
	GateWidth = 24,
}

-- Hub kiosks. Window/Tab tell the client which UI to open.
MapConfig.Kiosks = {
	{ Id = "MainShop", Position = Vector3.new(-270, 0, -88), Label = "CARD SHOP", Icon = "🛒", Window = "Shop", Tab = "Packs", Color = Color3.fromRGB(255, 200, 70) },
	{ Id = "BoostShop", Position = Vector3.new(-250, 0, -88), Label = "BOOSTS", Icon = "⚡", Window = "Shop", Tab = "Boosts", Color = Color3.fromRGB(90, 220, 255) },
	{ Id = "CosmeticShop", Position = Vector3.new(-230, 0, -88), Label = "COSMETICS", Icon = "🎨", Window = "Shop", Tab = "Cosmetics", Color = Color3.fromRGB(255, 120, 200) },
	{ Id = "EventShop", Position = Vector3.new(-330, 0, -86), Label = "EVENT SHOP", Icon = "🎟️", Window = "Shop", Tab = "Event", Color = Color3.fromRGB(255, 140, 40) },
	{ Id = "RebirthShrine", Position = Vector3.new(-250, 0, 86), Label = "REBIRTH", Icon = "♻️", Window = "Rebirth", Color = Color3.fromRGB(120, 255, 170) },
	{ Id = "IndexHall", Position = Vector3.new(-330, 0, 86), Label = "COLLECTION BOOK", Icon = "📖", Window = "Index", Color = Color3.fromRGB(180, 140, 255) },
	{ Id = "Leaderboards", Position = Vector3.new(-352, 0, 0), Label = "LEADERBOARDS", Icon = "🏆", Window = "Leaderboard", Color = Color3.fromRGB(255, 220, 90) },
	{ Id = "Rewards", Position = Vector3.new(-300, 0, -30), Label = "DAILY REWARDS", Icon = "🎁", Window = "Rewards", Color = Color3.fromRGB(255, 110, 110) },
	{ Id = "Quests", Position = Vector3.new(-300, 0, 30), Label = "QUESTS", Icon = "📜", Window = "Quests", Color = Color3.fromRGB(120, 220, 255) },
}

MapConfig.Leaderboards = {
	-- Physical boards in the hub (faces +X).
	{ Stat = "CashPerSec", Position = Vector3.new(-372, 0, -48) },
	{ Stat = "Rebirths", Position = Vector3.new(-372, 0, -16) },
	{ Stat = "Steals", Position = Vector3.new(-372, 0, 16) },
	{ Stat = "Collection", Position = Vector3.new(-372, 0, 48) },
}

MapConfig.Showcase = {
	Center = Vector3.new(-330, 0, 106),
	Radius = 14,
}

MapConfig.EventStage = Vector3.new(-330, 0, -104)
MapConfig.RebirthShrine = Vector3.new(-250, 0, 104)
MapConfig.ShopHall = Vector3.new(-250, 0, -104)

return MapConfig
