--!nocheck
-- A full single-player journey through every system, then leave / rejoin / shutdown.
Sim.BootServer()
local R = Sim.registry()
local MapConfig = require(Sim.find("ReplicatedStorage/Shared/Config/MapConfig"))
local Economy = require(Sim.find("ReplicatedStorage/Shared/Economy"))
local Catalog = require(Sim.find("ReplicatedStorage/Shared/Catalog"))

local function count(t)
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

local function ok(res, what)
	Sim.assert(res.Ok, what .. " failed: " .. tostring(res.Message))
	return res
end

local function moveTo(player, position)
	R.AntiExploitService:MarkTeleport(player)
	Sim.MoveCharacter(player, position)
end

local alice = Sim.AddPlayer(1001, "Alice")
Sim.Run(3)
local data = R.DataService:Get(alice)
local plot = R.BaseService:GetPlot(alice)
Sim.assert(data and plot, "loaded")

-- 1 Claim
ok(Sim.Invoke(alice, "ClaimBase"), "claim")
Sim.assert(data.Tutorial.Step == 2, "tutorial step 2, got " .. data.Tutorial.Step)

-- 2 Buy
local uid = R.ConveyorService:AdminSpawn("emberpup", "Normal", nil, "Main")
local item = R.ConveyorService:GetItems()[uid]
moveTo(alice, R.ConveyorService:GetPosition(item) + Vector3.new(0, 3, 7))
local far = Sim.Invoke(alice, "BuyConveyor", "not-a-real-uid")
Sim.assert(not far.Ok, "bogus uid rejected")
local cashBeforeBuy = data.Cash
ok(Sim.Invoke(alice, "BuyConveyor", uid), "buy")
Sim.assert(count(data.Inventory) == 1, "inventory 1")
Sim.assert(data.Cash == cashBeforeBuy - item.Price, "price deducted")
Sim.assert(data.Tutorial.Step == 3, "tutorial step 3")
Sim.assert(#Sim.lastEvents(alice, "Reveal") >= 1, "reveal sent")

-- 3 Arrive + income
Sim.Run(10)
Sim.assert(data.Tutorial.Step == 4, "tutorial step 4 (arrived), got " .. data.Tutorial.Step)
Sim.assert(data.Uncollected > 0, "income accumulating")

-- 4 Collect on the pad
local pad = (plot.Refs.Origin * CFrame.new(MapConfig.Plot.CollectPad)).Position
local farCollect = Sim.Invoke(alice, "CollectCash")
Sim.assert(not farCollect.Ok, "must stand on pad")
moveTo(alice, pad + Vector3.new(0, 3, 0))
local before = data.Cash
ok(Sim.Invoke(alice, "CollectCash"), "collect")
Sim.assert(data.Cash > before, "cash collected")
Sim.assert(data.Tutorial.Step == 5, "tutorial step 5")

-- 5 Upgrade
ok(Sim.Invoke(alice, "AdminCommand", "/givecash me 50m"), "admin cash")
ok(Sim.Invoke(alice, "UpgradeBase"), "upgrade base")
Sim.assert(data.BaseLevel == 2, "base level 2")
Sim.assert(data.Tutorial.Step == 6, "tutorial step 6")

-- 6 Skip steal step, 7 lock
ok(Sim.Invoke(alice, "TutorialSkip", "Step"), "skip step")
Sim.assert(data.Tutorial.Step == 7, "tutorial step 7")
moveTo(alice, R.BaseService:SpawnCFrame(plot).Position)
ok(Sim.Invoke(alice, "LockBase"), "lock")
Sim.assert(data.Tutorial.Done, "tutorial done")
Sim.assert(not Sim.Invoke(alice, "LockBase").Ok, "can't double lock")

-- Upgrade every security track to level 1
for _, track in { "Security", "Alarm", "Traps", "AntiSteal", "AutoCollect" } do
	Sim.Run(0.3)
	ok(Sim.Invoke(alice, "UpgradeTrack", track), "upgrade " .. track)
	Sim.assert(data.Upgrades[track] == 1, track .. " level 1")
end
Sim.assert(not Sim.Invoke(alice, "UpgradeTrack", "Hax").Ok, "bad track rejected")
-- Auto-collect: income now goes straight to cash
local cashBefore = data.Cash
Sim.Run(2)
Sim.assert(data.Cash > cashBefore and data.Uncollected == 0, "auto collect works")

-- Inventory operations
local ownedUid = next(data.Inventory)
ok(Sim.Invoke(alice, "LevelUpItem", ownedUid), "level up")
Sim.assert(data.Inventory[ownedUid].Level == 2, "level 2")
ok(Sim.Invoke(alice, "ToggleItemLock", ownedUid), "favourite")
Sim.assert(not Sim.Invoke(alice, "SellItem", ownedUid).Ok, "favourite can't be sold")
ok(Sim.Invoke(alice, "ToggleItemLock", ownedUid), "unfavourite")
ok(Sim.Invoke(alice, "MoveItem", ownedUid, "Storage"), "to storage")
Sim.assert(data.Inventory[ownedUid].Slot == 0, "in storage")
ok(Sim.Invoke(alice, "MoveItem", ownedUid, "Base"), "to base")
Sim.assert(data.Inventory[ownedUid].Slot > 0, "in base")
ok(Sim.Invoke(alice, "SellItem", ownedUid), "sell")
Sim.assert(data.Inventory[ownedUid] == nil, "sold")

-- Packs (transparent odds, cash only)
ok(Sim.Invoke(alice, "BuyPack", "Starter"), "starter pack")
ok(Sim.Invoke(alice, "BuyPack", "Booster"), "booster pack")
Sim.assert(not Sim.Invoke(alice, "BuyPack", "Elite").Ok, "elite pack gated by rebirth")
Sim.assert(count(data.Inventory) == 2, "two pack critters")

-- Tokens: boosts and cosmetics
ok(Sim.Invoke(alice, "AdminCommand", "/givetokens me 1000"), "tokens")
ok(Sim.Invoke(alice, "BuyBoost", "boost_luck_10"), "luck boost")
Sim.assert(R.BoostService:IsActive(alice, "Luck"), "luck boost active")
ok(Sim.Invoke(alice, "BuyCosmetic", "Trail_Sparkle"), "buy trail")
Sim.assert(data.Cosmetics.Equipped.Trail == "Trail_Sparkle", "trail equipped")
Sim.assert(alice.Character.HumanoidRootPart:FindFirstChild("CosmeticTrail") ~= nil, "trail applied to character")
Sim.assert(not Sim.Invoke(alice, "EquipCosmetic", "Trail_Galaxy").Ok, "can't equip unowned gamepass cosmetic")
ok(Sim.Invoke(alice, "BuyCosmetic", "Theme_Ocean"), "buy theme")
Sim.assert(plot.Refs.Floor.Color == require(Sim.find("ReplicatedStorage/Shared/Config/CosmeticConfig")).Items.Theme_Ocean.Floor, "theme applied")

-- Daily reward
ok(Sim.Invoke(alice, "ClaimDaily"), "daily")
Sim.assert(not Sim.Invoke(alice, "ClaimDaily").Ok, "no double daily")
Sim.assert(data.Daily.Streak == 1, "streak 1")

-- Playtime milestone (5 minutes)
Sim.assert(not Sim.Invoke(alice, "ClaimPlaytime", 1).Ok, "playtime not reached yet")
Sim.Run(300, 0.25)
ok(Sim.Invoke(alice, "ClaimPlaytime", 1), "playtime 5m")

-- Quests: force-complete first daily quest
R.QuestService:EnsureDay(alice)
local q = data.Quests.Daily[1]
q.Progress = q.Target
ok(Sim.Invoke(alice, "ClaimQuest", 1), "claim quest")
Sim.assert(not Sim.Invoke(alice, "ClaimQuest", 1).Ok, "no double claim")
ok(Sim.Invoke(alice, "RerollQuest", 2), "reroll")
Sim.assert(not Sim.Invoke(alice, "RerollQuest", 3).Ok, "only one free reroll")

-- Collection milestone 25%: discover enough distinct critters
local needed = math.ceil(Catalog.CompletionTotal * 0.25)
local given = 0
for _, def in Catalog.All do
	if not def.Limited and not data.Collection[def.Id] and given < needed then
		R.CollectibleService:Grant(alice, def.Id, { Source = "Test", Silent = true })
		given += 1
		-- keep space free
		for itemUid, it in data.Inventory do
			if it.Slot == 0 then
				R.CollectibleService:Remove(alice, itemUid)
			end
		end
	end
end
ok(Sim.Invoke(alice, "ClaimCollectionMilestone", 25), "collection milestone")
Sim.assert(not Sim.Invoke(alice, "ClaimCollectionMilestone", 50).Ok, "50% not reached")
-- Achievement (Discoverer tier 1)
ok(Sim.Invoke(alice, "ClaimAchievement", "Discoverer"), "achievement")

-- Events
ok(Sim.Invoke(alice, "AdminCommand", "/event start DoubleCash 1"), "event start")
Sim.assert(R.EventService:GetModifiers().IncomeMultiplier >= 2, "double cash active")
Sim.Run(1)
ok(Sim.Invoke(alice, "AdminCommand", "/event stop DoubleCash"), "event stop")
Sim.assert(not R.EventService:IsActive("DoubleCash"), "stopped")

-- Event shop (Halloween is active on the simulated date)
Sim.assert(R.EventService:IsActive("Halloween"), "halloween seasonal event active")
data.EventTokens = 500
ok(Sim.Invoke(alice, "BuyEventItem", "ev_trail_spooky"), "event shop cosmetic")
ok(Sim.Invoke(alice, "BuyEventItem", "ev_gourdghast"), "event shop collectible")
Sim.assert(not Sim.Invoke(alice, "BuyEventItem", "ev_frostbell").Ok, "winter item unavailable")

-- Admin spawn + rare announcement + luck
ok(Sim.Invoke(alice, "AdminCommand", "/spawn galaxitty Rainbow"), "admin spawn secret")
ok(Sim.Invoke(alice, "AdminCommand", "/setluck 3 5"), "setluck")
Sim.assert(R.BoostService:ServerLuck() >= 3, "server luck applied")

-- Rebirth
data.Cash = Economy.RebirthCost(data.Rebirths)
ok(Sim.Invoke(alice, "Rebirth"), "rebirth")
Sim.assert(data.Rebirths == 1, "rebirth 1")
Sim.assert(data.Cosmetics.Owned.Trail_Reborn, "rebirth milestone reward")
ok(Sim.Invoke(alice, "QuickTravel", "Elite"), "elite unlocked")
Sim.Run(7)
ok(Sim.Invoke(alice, "QuickTravel", "Home"), "home travel")

-- Settings
ok(Sim.Invoke(alice, "SaveSettings", { Graphics = "Low", Evil = true, Music = "nope" }), "settings")
Sim.assert(data.Settings.Graphics == "Low" and data.Settings.Evil == nil and data.Settings.Music == true, "settings validated")

-- Social endpoints
ok(Sim.Invoke(alice, "InspectPlayer", alice.UserId), "inspect")
ok(Sim.Invoke(alice, "GetLeaderboards"), "leaderboards")

-- Monetization (Studio simulation path runs the real ProcessReceipt)
local cash = data.Cash
ok(Sim.Invoke(alice, "AdminCommand", "/testproduct CashSmall"), "dev product")
Sim.assert(data.Cash > cash, "product granted cash")
local capacity = R.CollectibleService:Capacity(alice)
ok(Sim.Invoke(alice, "AdminCommand", "/testpass ExtraSlots"), "gamepass")
Sim.assert(R.CollectibleService:Capacity(alice) == capacity + 5, "extra slots applied")
ok(Sim.Invoke(alice, "AdminCommand", "/testproduct ServerLuck"), "server luck product")

-- Spam protection
local blocked = 0
for _ = 1, 6 do
	local r = Sim.Invoke(alice, "Rebirth")
	if r.Message == "Slow down!" then
		blocked += 1
	end
end
Sim.assert(blocked >= 4, "rate limit kicks in")
local unknown = Sim.Invoke(alice, "DefinitelyNotAnAction")
Sim.assert(not unknown.Ok, "unknown action rejected")

-- In-game integration suite
local suite = Sim.Invoke(alice, "AdminCommand", "/runtests")
Sim.assert(suite.Ok, "runtests ran")
local failedTests = {}
for _, line in suite.Data do
	if string.find(line, "❌", 1, true) then
		table.insert(failedTests, line)
	end
end
Sim.assert(#failedTests == 0, "integration tests failed:\n" .. table.concat(failedTests, "\n"))
print(suite.Data[#suite.Data])

-- The test runner restores a snapshot (a new table), so fetch it again.
data = R.DataService:Get(alice)

-- Leave: data is saved with the session lock released
local savedCash = data.Cash
local savedRebirths = data.Rebirths
Sim.RemovePlayer(alice)
Sim.Run(3)
local store = Sim.dataStores["StealCritters_PlayerData_v1"]
local saved = store.Data["Player_1001"]
Sim.assert(saved ~= nil, "saved on leave")
Sim.assert(saved.SessionLock == nil, "lock released on leave")
Sim.assert(saved.Rebirths == savedRebirths, "rebirths persisted")
Sim.assert(math.abs(saved.Cash - savedCash) < 1e-6 or saved.Cash >= savedCash, "cash persisted")

-- Pretend she was away for 100 hours earning 100/s: offline earnings pay
-- 15% of that, capped at 8 hours.
saved.LastOnline = os.time() - 100 * 3600
saved.LastCashPerSec = 100
local cashBeforeRejoin = saved.Cash

-- Rejoin: same progress loads
local alice2 = Sim.AddPlayer(1001, "Alice")
Sim.Run(3)
local data2 = R.DataService:Get(alice2)
Sim.assert(data2 and data2.Rebirths == savedRebirths, "rebirths loaded")
local offlinePay = 100 * 8 * 3600 * 0.15
Sim.assert(data2.Cash >= cashBeforeRejoin + offlinePay, "offline earnings paid")
Sim.assert(data2.Cash < cashBeforeRejoin + offlinePay * 1.5, "offline earnings capped at 8h")
Sim.assert(data2.Cosmetics.Owned.Trail_Sparkle, "cosmetics loaded")
Sim.assert(data2.Stats.Logins >= 2, "login counted")

-- Shutdown saves everyone and releases locks
data2.Tokens = 777
Sim.Shutdown()
Sim.Run(1)
Sim.assert(store.Data["Player_1001"].Tokens == 777, "shutdown save")
Sim.assert(store.Data["Player_1001"].SessionLock == nil, "lock released on shutdown")
print("journey ok")
