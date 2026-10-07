--[[
	TestRunner — in-Studio integration tests.
	Run with the admin command /runtests (or set GameConfig.Testing.AutoRunInStudio).

	Tests run against the REAL services using the calling player. The player's
	data is snapshotted first and fully restored afterwards; persistence tests
	use an in-memory MockDataStore so nothing touches real DataStores.
	The stealing test needs a second player: in Studio pick "Server & Clients"
	(2 clients) in the dropdown next to Play (older Studio: Test > Clients and
	Servers > 2 Players).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local GameConfig = require(Config.GameConfig)
local StealConfig = require(Config.StealConfig)
local MonetizationConfig = require(Config.MonetizationConfig)
local Economy = require(Shared.Economy)
local Catalog = require(Shared.Catalog)
local TableUtil = require(Shared.Util.TableUtil)

local Modules = script.Parent.Parent.Modules
local Registry = require(Modules.Registry)
local ActionBus = require(Modules.ActionBus)
local DataSchema = require(Modules.DataSchema)
local MockDataStore = require(Modules.MockDataStore)

local TestRunner = {}

local function assertEq(a, b, msg: string?)
	if a ~= b then
		error(string.format("%sexpected %s, got %s", msg and (msg .. ": ") or "", tostring(b), tostring(a)), 2)
	end
end

local function assertTrue(v, msg: string?)
	if not v then
		error(msg or "expected true", 2)
	end
end

local function countInventory(data): number
	local n = 0
	for _ in data.Inventory do
		n += 1
	end
	return n
end

local function rootOf(player: Player): BasePart?
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function teleport(player: Player, position: Vector3)
	Registry.AntiExploitService:Teleport(player, CFrame.new(position))
	task.wait(0.15)
end

-- Fake player used to test persistence paths without kicking anyone.
local function fakePlayer(id: number)
	return { Name = "FakePlayer" .. id, DisplayName = "Fake", UserId = -id, Parent = nil, Kick = function() end } :: any
end

local tests: { { Name: string, Fn: (Player) -> () } } = {}
local function test(name: string, fn: (Player) -> ())
	table.insert(tests, { Name = name, Fn = fn })
end

---------------------------------------------------------------- tests
test("Joining: profile, plot, leaderstats", function(player)
	assertTrue(Registry.DataService:IsLoaded(player), "profile loaded")
	assertTrue(Registry.BaseService:GetPlot(player) ~= nil, "plot assigned")
	assertTrue(player:FindFirstChild("leaderstats") ~= nil, "leaderstats")
	assertEq(player:GetAttribute("DataLoaded"), true, "DataLoaded attribute")
end)

test("Saving and loading round-trip (mock store)", function(player)
	local profile = Registry.DataService:GetProfile(player) :: any
	local realStore, realMock = Registry.DataService.Store, Registry.DataService.UsingMock
	local store = MockDataStore.new()
	Registry.DataService:SetStore(store, true)
	local ok, err = pcall(function()
		profile.Data.Tokens = 4242
		assertTrue(Registry.DataService:SaveAsync(player, false), "save succeeded")
		local raw = store.Data[profile.Key]
		assertTrue(raw ~= nil, "data written")
		assertEq(raw.SessionLock and raw.SessionLock.JobId, game.JobId, "session lock written")
		local loaded = DataSchema.Prepare(raw)
		assertEq(loaded.Tokens, 4242, "tokens persisted")
		assertEq(countInventory(loaded), countInventory(profile.Data), "inventory persisted")
	end)
	Registry.DataService:SetStore(realStore, realMock)
	if not ok then
		error(err)
	end
end)

test("Save retries after transient DataStore errors", function(player)
	local realStore, realMock = Registry.DataService.Store, Registry.DataService.UsingMock
	local store = MockDataStore.new()
	store.FailNext = 1
	Registry.DataService:SetStore(store, true)
	local ok, err = pcall(function()
		assertTrue(Registry.DataService:SaveAsync(player, false), "save eventually succeeded")
		assertTrue(store.Calls >= 2, "retried")
	end)
	Registry.DataService:SetStore(realStore, realMock)
	if not ok then
		error(err)
	end
end)

test("Session locking: lost lock stops saving; stale lock is taken over", function()
	local realStore, realMock = Registry.DataService.Store, Registry.DataService.UsingMock
	local store = MockDataStore.new()
	Registry.DataService:SetStore(store, true)
	local cfg = GameConfig.Data
	local oldDelay, oldRetries = cfg.LoadRetryDelay, cfg.LoadRetries
	cfg.LoadRetryDelay, cfg.LoadRetries = 0.05, 3
	local fake = fakePlayer(1)
	local ok, err = pcall(function()
		-- Another server holds a FRESH lock: we only take it on the final attempt.
		local key = "Player_-1"
		store.Data[key] = { Cash = 5, SessionLock = { JobId = "OtherServer", Time = os.time() } }
		local acquired, raw = Registry.DataService:_acquire(key)
		assertTrue(acquired, "acquired after retries")
		assertEq(raw.SessionLock.JobId, game.JobId, "lock now ours")
		assertTrue(store.Calls >= 3, "retried while locked")

		-- A save after another server stole the lock must NOT overwrite.
		Registry.DataService.Profiles[fake] = {
			Player = fake, Key = key, Data = DataSchema.Template(), Session = {}, DirtyData = {}, DirtySession = {},
			Seq = 0, LastSave = 0, Saving = false, Released = false, Releasing = false, LockLost = false, IsNew = false, LoadedAt = 0,
		}
		store.Data[key].SessionLock = { JobId = "ThiefServer", Time = os.time() }
		store.Data[key].Cash = 777
		assertEq(Registry.DataService:SaveAsync(fake, false), false, "save refused")
		assertEq(store.Data[key].Cash, 777, "other server's data untouched")

		-- Release (leave / shutdown) clears our lock.
		store.Data[key].SessionLock = { JobId = game.JobId, Time = os.time() }
		Registry.DataService.Profiles[fake].LockLost = false
		Registry.DataService:ReleaseAsync(fake)
		assertEq(store.Data[key].SessionLock, nil, "lock released on leave")
		assertEq(Registry.DataService.Profiles[fake], nil, "profile forgotten")
	end)
	Registry.DataService.Profiles[fake] = nil
	cfg.LoadRetryDelay, cfg.LoadRetries = oldDelay, oldRetries
	Registry.DataService:SetStore(realStore, realMock)
	if not ok then
		error(err)
	end
end)

test("Purchasing from the conveyor (server-validated)", function(player)
	local data = Registry.DataService:Get(player) :: any
	Registry.EconomyService:AddCash(player, 10000000, "Admin")
	local uid = Registry.ConveyorService:AdminSpawn("zapkit", "Normal", nil, "Main")
	assertTrue(uid ~= nil, "spawned")
	local item = Registry.ConveyorService:GetItems()[uid :: string]
	local before = countInventory(data)
	local cashBefore = data.Cash

	-- Too far away
	teleport(player, Vector3.new(0, 5, 140))
	local okFar = Registry.ConveyorService:Buy(player, uid)
	assertEq(okFar, false, "far purchase rejected")

	-- Close enough
	teleport(player, Registry.ConveyorService:GetPosition(item) + Vector3.new(0, 3, 7))
	local ok, msg = Registry.ConveyorService:Buy(player, uid)
	assertTrue(ok, "purchase failed: " .. tostring(msg))
	assertEq(countInventory(data), before + 1, "item added")
	assertEq(data.Cash, cashBefore - item.Price, "cash deducted exactly")
	assertEq(Registry.ConveyorService:GetItems()[uid :: string], nil, "removed from conveyor")
	local again = Registry.ConveyorService:Buy(player, uid)
	assertEq(again, false, "cannot buy twice")
end)

test("Buying without enough cash is rejected", function(player)
	local data = Registry.DataService:Get(player) :: any
	data.Cash = 0
	local uid = Registry.ConveyorService:AdminSpawn("solarion", "Normal", nil, "Main")
	local item = Registry.ConveyorService:GetItems()[uid :: string]
	teleport(player, Registry.ConveyorService:GetPosition(item) + Vector3.new(0, 3, 7))
	local ok = Registry.ConveyorService:Buy(player, uid)
	assertEq(ok, false, "rejected")
	assertEq(data.Cash, 0, "cash unchanged")
end)

test("Collectibles generate money (central tick + collect pad)", function(player)
	local data = Registry.DataService:Get(player) :: any
	data.Upgrades.AutoCollect = 0
	Registry.CollectibleService:Grant(player, "infernox", { Source = "Test", Silent = true })
	local cps = Registry.EconomyService:ComputeCashPerSec(player)
	assertTrue(cps > 0, "cash per second > 0")
	data.Uncollected = 0
	task.wait(GameConfig.Income.TickInterval * 2.2)
	assertTrue(data.Uncollected > 0, "income accumulated on the pad")
	local cash = data.Cash
	local ok = Registry.EconomyService:Collect(player, true)
	assertTrue(ok, "collected")
	assertTrue(data.Cash > cash, "cash increased")
	assertEq(data.Uncollected, 0, "pad emptied")
end)

test("Money can be spent: base + security upgrades", function(player)
	local data = Registry.DataService:Get(player) :: any
	data.BaseLevel = 1
	data.Upgrades.Security = 0
	Registry.EconomyService:AddCash(player, 1e9, "Admin")
	local ok = Registry.UpgradeService:UpgradeBase(player)
	assertTrue(ok, "base upgraded")
	assertEq(data.BaseLevel, 2, "base level")
	assertEq(Registry.CollectibleService:Capacity(player), Economy.BaseSlots(2, 0) + (if Registry.MonetizationService:OwnsPass(player, "ExtraSlots") then 5 else 0), "capacity")
	local ok2 = Registry.UpgradeService:UpgradeTrack(player, "Security")
	assertTrue(ok2, "security upgraded")
	assertEq(data.Upgrades.Security, 1, "security level")
	local bad = Registry.UpgradeService:UpgradeTrack(player, "NotATrack")
	assertEq(bad, false, "invalid track rejected")
end)

test("Inventory: level up, favourite, storage, sell", function(player)
	local data = Registry.DataService:Get(player) :: any
	Registry.EconomyService:AddCash(player, 1e9, "Admin")
	local item = Registry.CollectibleService:Grant(player, "pyroclaw", { Source = "Test", Silent = true })
	assertTrue(item ~= nil, "granted")
	local uid = item.Uid
	assertTrue(Registry.CollectibleService:LevelUp(player, uid), "levelled")
	assertEq(data.Inventory[uid].Level, 2, "level 2")
	Registry.CollectibleService:ToggleLock(player, uid)
	assertEq(Registry.CollectibleService:Sell(player, uid), false, "favourites can't be sold")
	Registry.CollectibleService:ToggleLock(player, uid)
	if data.Inventory[uid].Slot > 0 then
		assertTrue(Registry.CollectibleService:Move(player, uid, "Storage"), "moved to storage")
		assertEq(data.Inventory[uid].Slot, 0, "in storage")
		assertTrue(Registry.CollectibleService:Move(player, uid, "Base"), "moved back")
	end
	local cash = data.Cash
	assertTrue(Registry.CollectibleService:Sell(player, uid), "sold")
	assertEq(data.Inventory[uid], nil, "removed")
	assertTrue(data.Cash > cash, "paid")
end)

test("Collectibles cannot be duplicated", function(player)
	local item = Registry.CollectibleService:Grant(player, "emberpup", { Source = "Test", Silent = true })
	assertTrue(item ~= nil, "granted")
	local result, err = Registry.CollectibleService:Transfer(player, player, item.Uid, "Test")
	assertEq(result, nil, "self-transfer refused")
	assertEq(err, "Duplicate item", "duplicate guard")
	local bogus = Registry.CollectibleService:Grant(player, "definitely_not_real", { Source = "Test" })
	assertEq(bogus, nil, "invalid collectible id refused")
end)

test("Money cannot be generated from bad input", function(player)
	local data = Registry.DataService:Get(player) :: any
	local cash = data.Cash
	assertEq(Registry.EconomyService:AddCash(player, 0 / 0, "Test"), false, "NaN refused")
	assertEq(Registry.EconomyService:AddCash(player, -100, "Test"), false, "negative refused")
	assertEq(Registry.EconomyService:SpendCash(player, -100, "Test"), false, "negative spend refused")
	assertEq(data.Cash, cash, "cash unchanged")
end)

test("Rate limiting blocks remote spam", function(player)
	local allowed = 0
	for _ = 1, 10 do
		if Registry.AntiExploitService:CheckRate(player, "Rebirth") then
			allowed += 1
		end
	end
	assertTrue(allowed <= 2, "at most burst allowed, got " .. allowed)
end)

test("Rebirth", function(player)
	local data = Registry.DataService:Get(player) :: any
	local before = data.Rebirths
	data.Cash = Economy.RebirthCost(before)
	Registry.CollectibleService:Grant(player, "emberpup", { Source = "Test", Silent = true })
	local ok, msg = Registry.RebirthService:Rebirth(player)
	assertTrue(ok, "rebirth failed: " .. tostring(msg))
	assertEq(data.Rebirths, before + 1, "rebirth count")
	assertEq(data.Cash, Economy.RebirthStartingCash(before + 1), "cash reset")
	assertTrue(countInventory(data) <= Economy.KeptCollectiblesAt(before + 1), "collectibles reset")
	data.Cash = 0
	assertEq(Registry.RebirthService:Rebirth(player), false, "can't rebirth without cash")
end)

test("Quests progress and can be claimed once", function(player)
	local data = Registry.DataService:Get(player) :: any
	Registry.QuestService:EnsureDay(player)
	local quest = data.Quests.Daily[1]
	assertTrue(quest ~= nil, "daily quests exist")
	quest.Claimed = false
	quest.Progress = quest.Target
	local tokens = data.Tokens
	assertTrue(Registry.QuestService:ClaimQuest(player, 1), "claimed")
	assertTrue(data.Tokens >= tokens, "rewarded")
	assertEq(Registry.QuestService:ClaimQuest(player, 1), false, "no double claim")
	local entry = data.Quests.Lifetime.Collector or { Progress = 0 }
	local progress = entry.Progress
	ActionBus.Fire(player, "Acquire", 3, { Rarity = "Common", Mutation = "Normal" })
	assertEq(data.Quests.Lifetime.Collector.Progress, progress + 3, "achievement progressed")
end)

test("Events can be activated and stopped", function()
	Registry.EventService:StartEvent("DoubleCash", 1)
	assertEq(Registry.EventService:GetModifiers().IncomeMultiplier >= 2, true, "income x2 active")
	assertTrue(Registry.EventService:IsActive("DoubleCash"), "active")
	Registry.EventService:StopEvent("DoubleCash")
	assertEq(Registry.EventService:IsActive("DoubleCash"), false, "stopped")
	Registry.EventService:ClearOverrides()
end)

test("Rare spawns: forced Secret + luck increases rare odds", function()
	local uid = Registry.ConveyorService:AdminSpawn("galaxitty", "Rainbow", "Jackpot", "Main")
	local item = Registry.ConveyorService:GetItems()[uid :: string]
	assertTrue(item ~= nil, "spawned")
	local def = Catalog.Get(item.Id)
	assertEq(def and def.Rarity, "Secret", "secret rarity")
	assertEq(item.Mutation, "Rainbow", "mutation kept")
	assertEq(item.Model:GetAttribute("Price"), Economy.SpawnPrice("galaxitty", "Rainbow", "Jackpot"), "price matches formula")
end)

test("Developer products use ProcessReceipt and never double-grant", function(player)
	local data = Registry.DataService:Get(player) :: any
	local realStore, realMock = Registry.DataService.Store, Registry.DataService.UsingMock
	Registry.DataService:SetStore(MockDataStore.new(), true)
	local ok, err = pcall(function()
		local cash = data.Cash
		local purchaseId = "TEST-RECEIPT-1"
		local granted = Registry.MonetizationService:SimulateProduct(player, "CashSmall", purchaseId)
		assertTrue(granted, "granted")
		assertTrue(data.Cash > cash, "cash added")
		assertTrue(data.Receipts[purchaseId] ~= nil, "receipt recorded")
		local afterFirst = data.Cash
		Registry.MonetizationService:SimulateProduct(player, "CashSmall", purchaseId)
		assertEq(data.Cash, afterFirst, "same receipt not granted twice")
	end)
	Registry.DataService:SetStore(realStore, realMock)
	if not ok then
		error(err)
	end
end)

test("Gamepasses apply and remove perks", function(player)
	local owned = Registry.MonetizationService:OwnsPass(player, "ExtraSlots")
	Registry.MonetizationService:SimulatePass(player, "ExtraSlots", false)
	local base = Registry.CollectibleService:Capacity(player)
	Registry.MonetizationService:SimulatePass(player, "ExtraSlots", true)
	assertEq(Registry.CollectibleService:Capacity(player), math.min(base + MonetizationConfig.Gamepasses.ExtraSlots.Perks.ExtraSlots, 36), "extra slots")
	Registry.MonetizationService:SimulatePass(player, "ExtraSlots", owned)
end)

test("Owners can defend: base lock blocks theft", function(player)
	local plot = Registry.BaseService:GetPlot(player) :: any
	plot.Locked = false
	plot.LockReadyAt = 0
	Registry.BaseService:TeleportHome(player)
	task.wait(0.2)
	local ok, msg = Registry.BaseService:Lock(player)
	assertTrue(ok, "lock failed: " .. tostring(msg))
	local protected = Registry.BaseService:IsProtected(player)
	assertTrue(protected, "locked base is protected")
	plot.LockEndsAt = os.time() - 1
	task.wait(0.4)
	assertEq(plot.Locked, false, "lock expires")
end)

test("Stealing end-to-end (needs a 2nd player)", function(player)
	local victim: Player? = nil
	for _, p in Players:GetPlayers() do
		if p ~= player and Registry.DataService:IsLoaded(p) then
			victim = p
		end
	end
	if not victim then
		error("SKIP: start a 2-player local server to run this test")
	end
	local v = victim :: Player
	local vData = Registry.DataService:Get(v) :: any
	local tData = Registry.DataService:Get(player) :: any
	local oldPlaytime = vData.Stats.Playtime
	vData.Stats.Playtime = StealConfig.NewPlayerProtection + 1
	Registry.StealService:ResetCooldowns()
	local vPlot = Registry.BaseService:GetPlot(v) :: any
	vPlot.Locked = false
	local item = Registry.CollectibleService:Grant(v, "emberpup", { Source = "Test", Silent = true })
	assertTrue(item and item.Slot > 0, "victim item placed")
	local slotPos = Registry.BaseService:SlotCFrame(vPlot, item.Slot).Position
	-- Keep the victim far away so they can't catch the thief.
	Registry.AntiExploitService:Teleport(v, CFrame.new(-280, 5, 0))
	teleport(player, slotPos + Vector3.new(0, 3, 4))
	local ok, msg = Registry.StealService:StartSteal(player, v.UserId, item.Uid)
	assertTrue(ok, "steal start failed: " .. tostring(msg))
	assertTrue(Registry.CollectibleService:IsBusy(v, item.Uid), "item busy during theft")
	local theft = Registry.StealService:GetTheft(player)
	theft.Duration = 0
	task.wait(0.4)
	assertEq(theft.Phase, "Carry", "carry phase")
	theft.MinCarryTime = 0
	Registry.BaseService:TeleportHome(player)
	task.wait(0.6)
	assertEq(Registry.StealService:IsThief(player), false, "theft finished")
	assertEq(vData.Inventory[item.Uid], nil, "removed from victim")
	assertTrue(tData.Inventory[item.Uid] ~= nil, "added to thief")
	vData.Stats.Playtime = oldPlaytime
	Registry.StealService:ResetCooldowns()
end)

---------------------------------------------------------------- runner
function TestRunner.Run(player: Player): { string }
	local profile = Registry.DataService:GetProfile(player)
	if not profile then
		return { "Player data not loaded" }
	end
	local snapshot = TableUtil.DeepCopy(profile.Data)
	local root = rootOf(player)
	local returnCF = root and root.CFrame
	local lines = { "=== Integration tests ===" }
	local passed, failed, skipped = 0, 0, 0
	for _, t in tests do
		local ok, err = pcall(t.Fn, player)
		if ok then
			passed += 1
			table.insert(lines, "✅ " .. t.Name)
		elseif string.find(tostring(err), "SKIP:", 1, true) then
			skipped += 1
			table.insert(lines, "⏭️ " .. t.Name .. " — " .. tostring(err))
		else
			failed += 1
			table.insert(lines, "❌ " .. t.Name .. " — " .. tostring(err))
		end
	end

	-- Restore the tester's original data and base.
	Registry.BaseService:ReleasePlot(player)
	profile.Data = snapshot
	for key in snapshot do
		Registry.DataService:MarkDirty(player, key)
	end
	Registry.BaseService:AssignPlot(player)
	Registry.EconomyService:Refresh(player)
	Registry.PlayerService:UpdateMovement(player)
	if returnCF then
		Registry.AntiExploitService:Teleport(player, returnCF)
	end
	table.insert(lines, string.format("=== %d passed, %d failed, %d skipped (your data was restored) ===", passed, failed, skipped))
	print(table.concat(lines, "\n"))
	return lines
end

return TestRunner
