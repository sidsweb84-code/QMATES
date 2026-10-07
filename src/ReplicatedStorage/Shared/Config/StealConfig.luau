--[[
	StealConfig
	Every number used by the theft / defence systems.

	Flow: a thief holds "Steal" on a collectible in another base (GRAB phase,
	duration = Economy.StealDuration). Then they carry it home (CARRY phase)
	within CarryTimeLimit. The owner can catch them by getting within CatchRange.
]]

local StealConfig = {}

StealConfig.GrabRange = 13 -- thief must stay this close to the slot while grabbing
StealConfig.CatchRange = 8 -- owner within this distance of the thief = caught
StealConfig.CarryTimeLimit = 60
StealConfig.MaxStealTime = 30
StealConfig.CarryHeight = 4.5

StealConfig.PairCooldown = 120 -- same thief -> same victim
StealConfig.ThiefCooldown = 8 -- between any two theft attempts
StealConfig.FailStun = 1.5
StealConfig.FailCooldown = 15 -- after a failed attempt on the same victim

-- New players cannot be robbed until they have played this long in total.
StealConfig.NewPlayerProtection = 600

-- Base lock
StealConfig.LockCooldown = 20 -- after a lock ends before it can be used again

-- Anti-cheat sanity: the carry phase cannot finish faster than
-- distance / (walkspeed * this factor).
StealConfig.MinCarrySpeedFactor = 1.6

StealConfig.AnnounceMinRarity = "Epic"

return StealConfig
