--!nocheck
-- Multiplayer: stealing, defending, traps, locks, cooldowns, trading, exploits, session locks.
Sim.BootServer()
local R = Sim.registry()
local StealConfig = require(Sim.find("ReplicatedStorage/Shared/Config/StealConfig"))

local function ok(res, what)
	Sim.assert(res.Ok, what .. " failed: " .. tostring(res.Message))
	return res
end
local function moveTo(player, position)
	R.AntiExploitService:MarkTeleport(player)
	Sim.MoveCharacter(player, position)
end
local function count(t)
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

-- A stale lock from a crashed server must not block loading forever; a fresh
-- lock from a live server makes us retry first.
local store = R.DataService.Store
store.Data["Player_2002"] = { Cash = 999, SessionLock = { JobId = "crashed-server", Time = os.time() - 100000 } }

local thief = Sim.AddPlayer(2001, "Thief")
local victim = Sim.AddPlayer(2002, "Victim")
Sim.Run(4)
local tData = R.DataService:Get(thief)
local vData = R.DataService:Get(victim)
Sim.assert(tData and vData, "both loaded")
Sim.assert(vData.Cash == 999, "stale-locked profile loaded with its data")
Sim.assert(store.Data["Player_2002"].SessionLock.JobId == game.JobId, "lock taken over")

local vPlot = R.BaseService:GetPlot(victim)
local tPlot = R.BaseService:GetPlot(thief)

-- New players are protected for a while
local critter = R.CollectibleService:Grant(victim, "pyroclaw", { Source = "Test", Silent = true })
Sim.Run(0.5)
local slotPos = R.BaseService:SlotCFrame(vPlot, critter.Slot).Position
moveTo(thief, slotPos + Vector3.new(0, 3, 3))
local protected = Sim.Invoke(thief, "StartSteal", victim.UserId, critter.Uid)
Sim.assert(not protected.Ok and string.find(protected.Message, "New player"), "new player protection: " .. tostring(protected.Message))
vData.Stats.Playtime = StealConfig.NewPlayerProtection + 10

-- Victim far away; invalid args rejected
moveTo(victim, Vector3.new(-280, 5, 0))
Sim.assert(not Sim.Invoke(thief, "StartSteal", "x", critter.Uid).Ok, "bad args")
Sim.assert(not Sim.Invoke(thief, "StartSteal", thief.UserId, critter.Uid).Ok, "can't steal own")
Sim.Run(3) -- let the StartSteal rate limit refill

---------------------------------------------------------------- successful steal
ok(Sim.Invoke(thief, "StartSteal", victim.UserId, critter.Uid), "start steal")
Sim.assert(R.StealService:IsThief(thief), "thief registered")
Sim.assert(vPlot.Refs.Model:GetAttribute("Status") ~= nil, "status attr")
Sim.Run(0.5)
Sim.assert(vPlot.Refs.Model:GetAttribute("Status") == "Theft", "victim base shows theft")
Sim.assert(#Sim.lastEvents(victim, "Steal") >= 1, "victim alerted")
Sim.assert(not Sim.Invoke(victim, "SellItem", critter.Uid).Ok, "victim can't sell item being stolen")
local duration = R.StealService:GetTheft(thief).Duration
Sim.Run(duration + 0.3)
local theft = R.StealService:GetTheft(thief)
Sim.assert(theft and theft.Phase == "Carry", "carrying")
Sim.assert(thief.Character.Humanoid.WalkSpeed < 16, "carry slows the thief")
Sim.assert(not Sim.Invoke(thief, "QuickTravel", "Home").Ok, "no teleporting while carrying")
-- Walk home over time (respecting the minimum carry time)
local home = R.BaseService:EntranceCFrame(tPlot).Position
local start = thief.Character.HumanoidRootPart.Position
local steps = 40
for i = 1, steps do
	local p = start:Lerp(home + (home - start).Unit * 15, i / steps)
	moveTo(thief, p + Vector3.new(0, 3, 0))
	Sim.Run(theft.MinCarryTime / steps + 0.1)
	if not R.StealService:IsThief(thief) then
		break
	end
end
Sim.Run(0.5)
Sim.assert(not R.StealService:IsThief(thief), "theft finished")
Sim.assert(vData.Inventory[critter.Uid] == nil, "removed from victim")
Sim.assert(tData.Inventory[critter.Uid] ~= nil, "same item now owned by thief (no duplicate)")
Sim.assert(tData.Stats.Steals == 1 and vData.Stats.TimesRobbed == 1, "stats")
Sim.assert(R.StealService:VictimProtectedUntil(victim) > os.time(), "victim anti-steal protection")

---------------------------------------------------------------- caught by the owner
R.StealService:ResetCooldowns()
local critter2 = R.CollectibleService:Grant(victim, "solarion", { Source = "Test", Silent = true })
Sim.Run(0.5)
local slot2 = R.BaseService:SlotCFrame(vPlot, critter2.Slot).Position
moveTo(thief, slot2 + Vector3.new(0, 3, 3))
moveTo(victim, Vector3.new(-280, 5, 0))
ok(Sim.Invoke(thief, "StartSteal", victim.UserId, critter2.Uid), "start steal 2")
Sim.Run(1)
moveTo(victim, slot2 + Vector3.new(2, 3, 4)) -- owner runs back
Sim.Run(0.5)
Sim.assert(not R.StealService:IsThief(thief), "thief caught")
Sim.assert(vData.Inventory[critter2.Uid] ~= nil, "victim keeps critter")
Sim.assert(vData.Stats.Catches == 1, "catch counted")
Sim.Run(3)
local thiefRoot = thief.Character.HumanoidRootPart.Position
Sim.assert(R.BaseService:IsInside(tPlot, thiefRoot), "caught thief sent home")
local cooldown = Sim.Invoke(thief, "StartSteal", victim.UserId, critter2.Uid)
Sim.assert(not cooldown.Ok, "fail cooldown applies")

---------------------------------------------------------------- traps
R.StealService:ResetCooldowns()
R.EconomyService:AddCash(victim, 1e8, "Admin")
for _ = 1, 3 do
	Sim.Run(0.4)
	ok(Sim.Invoke(victim, "UpgradeTrack", "Traps"), "traps")
end
local trap = R.BaseService:ActiveTraps(vPlot)[1]
Sim.assert(trap ~= nil, "trap active")
moveTo(victim, Vector3.new(-280, 5, 0))
moveTo(thief, slot2 + Vector3.new(0, 3, 3))
ok(Sim.Invoke(thief, "StartSteal", victim.UserId, critter2.Uid), "start steal 3")
Sim.Run(R.StealService:GetTheft(thief).Duration + 0.3)
Sim.assert(R.StealService:GetTheft(thief).Phase == "Carry", "carry 3")
moveTo(thief, trap.Position + Vector3.new(0, 3, 0))
Sim.Run(0.4)
Sim.assert(not R.StealService:IsThief(thief), "trap stopped the thief")
Sim.assert(R.PlayerService:IsStunned(thief), "thief stunned")
Sim.assert(vData.Inventory[critter2.Uid] ~= nil, "critter returned")
Sim.Run(4)

---------------------------------------------------------------- base lock
R.StealService:ResetCooldowns()
moveTo(victim, R.BaseService:SpawnCFrame(vPlot).Position)
moveTo(thief, slot2 + Vector3.new(0, 3, 3))
ok(Sim.Invoke(thief, "StartSteal", victim.UserId, critter2.Uid), "start steal 4")
Sim.Run(0.2)
moveTo(victim, R.BaseService:SpawnCFrame(vPlot).Position)
ok(Sim.Invoke(victim, "LockBase"), "victim locks")
Sim.assert(not R.StealService:IsThief(thief), "lock cancels grab")
Sim.Run(0.5)
Sim.assert(not R.BaseService:IsInside(vPlot, thief.Character.HumanoidRootPart.Position), "intruder ejected")
local blocked = Sim.Invoke(thief, "StartSteal", victim.UserId, critter2.Uid)
Sim.assert(not blocked.Ok, "locked base can't be robbed")

---------------------------------------------------------------- victim leaves mid-carry
local p3 = Sim.AddPlayer(2003, "Leaver")
Sim.Run(3)
local lData = R.DataService:Get(p3)
lData.Stats.Playtime = StealConfig.NewPlayerProtection + 10
local lPlot = R.BaseService:GetPlot(p3)
local lCritter = R.CollectibleService:Grant(p3, "zapkit", { Source = "Test", Silent = true })
Sim.Run(0.5)
R.StealService:ResetCooldowns()
moveTo(p3, Vector3.new(-280, 5, 0))
moveTo(thief, R.BaseService:SlotCFrame(lPlot, lCritter.Slot).Position + Vector3.new(0, 3, 3))
ok(Sim.Invoke(thief, "StartSteal", p3.UserId, lCritter.Uid), "start steal 5")
Sim.Run(R.StealService:GetTheft(thief).Duration + 0.3)
Sim.RemovePlayer(p3)
Sim.Run(3)
Sim.assert(not R.StealService:IsThief(thief), "theft cancelled when owner leaves")
Sim.assert(tData.Inventory[lCritter.Uid] == nil, "thief didn't get it")
local savedLeaver = store.Data["Player_2003"]
Sim.assert(savedLeaver and savedLeaver.Inventory[lCritter.Uid] ~= nil, "leaver kept the critter in saved data")

---------------------------------------------------------------- speed exploit
Sim.Run(3)
local root = thief.Character.HumanoidRootPart
local before = root.Position
Sim.Run(1)
Sim.MoveCharacter(thief, before + Vector3.new(300, 0, 0)) -- impossible jump without server teleport
Sim.Run(1)
Sim.assert((thief.Character.HumanoidRootPart.Position - before).Magnitude < 50, "speed hack rubber-banded")

---------------------------------------------------------------- trading
Sim.Run(12)
local tItem = next(tData.Inventory)
local vItem = critter2.Uid
ok(Sim.Invoke(thief, "TradeRequest", victim.UserId), "trade request")
ok(Sim.Invoke(victim, "TradeRespond", thief.UserId, true), "trade accept")
ok(Sim.Invoke(thief, "TradeSetItems", { tItem }), "thief offers")
ok(Sim.Invoke(victim, "TradeSetItems", { vItem }), "victim offers")
Sim.assert(not Sim.Invoke(victim, "TradeSetItems", { "fake" }).Ok, "can't offer what you don't own")
ok(Sim.Invoke(victim, "TradeSetItems", { vItem }), "victim offers again")
ok(Sim.Invoke(thief, "TradeReady", true), "thief ready")
ok(Sim.Invoke(victim, "TradeReady", true), "victim ready")
Sim.Run(4)
Sim.assert(tData.Inventory[vItem] ~= nil and vData.Inventory[tItem] ~= nil, "items swapped")
Sim.assert(tData.Inventory[tItem] == nil and vData.Inventory[vItem] == nil, "no duplicates after trade")

-- Integration suite with two players (includes the end-to-end steal test)
R.StealService:ResetCooldowns()
vData.Stats.Playtime = StealConfig.NewPlayerProtection + 10
local suite = Sim.Invoke(thief, "AdminCommand", "/runtests")
local failed = {}
for _, line in suite.Data do
	if string.find(line, "❌", 1, true) or string.find(line, "⏭️", 1, true) then
		table.insert(failed, line)
	end
end
Sim.assert(#failed == 0, "integration failures:\n" .. table.concat(failed, "\n"))
print(suite.Data[#suite.Data])
print("multiplayer ok; inventory sizes", count(tData.Inventory), count(vData.Inventory))
