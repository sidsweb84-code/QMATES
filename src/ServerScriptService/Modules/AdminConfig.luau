--[[
	AdminConfig  (SERVER ONLY — lives in ServerScriptService, never replicated)

	Add the Roblox UserIds of people allowed to run admin commands.
	Optionally grant admin to a group rank.
	In Studio, the place owner / every Studio tester is an admin when
	StudioEveryoneIsAdmin is true (handy for testing; has no effect live).
]]

local AdminConfig = {}

AdminConfig.UserIds = {
	-- 123456789, -- your UserId here
}

AdminConfig.Group = {
	Id = 0, -- 0 = disabled
	MinRank = 254,
}

AdminConfig.StudioEveryoneIsAdmin = true

-- Commands that are only allowed inside Studio (destructive testing tools).
AdminConfig.StudioOnlyCommands = {
	resetdata = true,
	testproduct = true,
	testpass = true,
	runtests = false,
}

return AdminConfig
