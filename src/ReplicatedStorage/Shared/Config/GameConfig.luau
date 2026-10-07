--[[
	GameConfig
	Global, game-wide tuning values. Every system reads its numbers from a config
	module so balancing never requires touching gameplay code.
]]

local GameConfig = {}

GameConfig.Version = "1.0.0"

-- Keep this in sync with the place's "Max Players" (server size) setting and
-- with the number of bases in MapConfig.PlotOrigins (8). A player who joins
-- when every base is taken is sent back with a "server full" message.
GameConfig.MaxPlayers = 8

GameConfig.StartingCash = 100
GameConfig.StartingTokens = 10

GameConfig.Data = {
	-- Changing StoreName starts every player from scratch. Bump only for a full wipe.
	StoreName = "StealCritters_PlayerData_v1",
	KeyPrefix = "Player_",
	AutosaveInterval = 60, -- seconds between automatic saves per player
	-- A session lock is considered stale (crashed server) once it has not been
	-- refreshed for this many seconds. Autosave refreshes it.
	SessionLockTimeout = 360,
	LoadRetries = 6,
	LoadRetryDelay = 5,
	SaveRetries = 4,
	-- In Studio, when "Enable Studio Access to API Services" is off, fall back to
	-- an in-memory store so the game stays playable (progress is NOT kept).
	UseMockWhenUnavailable = true,
	MaxReceiptHistory = 60,
	ShutdownTimeout = 25,
}

GameConfig.Income = {
	TickInterval = 1, -- centralised income tick (seconds)
	OfflineEarnings = {
		Enabled = true,
		Rate = 0.15, -- 15% of the cash/sec you had when you left
		MaxSeconds = 8 * 3600,
		MinSecondsAway = 120,
	},
}

GameConfig.Movement = {
	BaseWalkSpeed = 16,
	BaseJumpPower = 50,
}

GameConfig.Travel = {
	-- Purchased collectibles walk from the conveyor to the buyer's base.
	StudsPerSecond = 38,
	MinDuration = 2,
	MaxDuration = 9,
}

GameConfig.QuickTravel = {
	Cooldown = 6, -- HUD "Home" / "Hub" teleport buttons
}

GameConfig.Visit = {
	Cooldown = 10,
}

GameConfig.Trading = {
	Enabled = true,
	MaxItemsPerSide = 4,
	RequestCooldown = 10,
	RequestTimeout = 30,
	ConfirmCountdown = 3,
	MinAccountAgeDays = 3, -- reduces alt-account abuse
}

GameConfig.Announcements = {
	CrossServerTopic = "StealCritters_RareFinds",
	CrossServerEnabled = true,
}

GameConfig.Leaderboards = {
	StorePrefix = "StealCritters_LB_v1_",
	RefreshInterval = 150, -- seconds between global leaderboard reads
	WriteInterval = 180, -- seconds between writes per player
	TopCount = 10,
}

GameConfig.Showcase = {
	RefreshInterval = 30,
	Count = 6,
}

GameConfig.Testing = {
	-- Runs the in-Studio integration test suite automatically on server start.
	-- You can also run it at any time with the admin command /runtests.
	AutoRunInStudio = false,
}

return GameConfig
