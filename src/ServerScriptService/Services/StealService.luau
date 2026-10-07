--[[
	StealService
	Server-authoritative stealing.

	1. GRAB  — thief starts a steal on a collectible in another (unprotected)
	           base and must stay within GrabRange for the steal duration
	           (rarity, mutation, Guardian trait and the victim's Security
	           upgrade make it longer). The owner is alerted immediately.
	2. CARRY — the critter is welded above the thief's head; the thief is
	           slowed by its rarity and must reach their own base before
	           CarryTimeLimit.
	Success transfers the SAME item record to the thief (no duplication).
	Failure (owner catches the thief, trap, lock, death, timeout, leaving)
	returns the critter to its slot; caught/trapped thieves are stunned and
	sent home.

	The client only ever *requests* a steal; every check happens here.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local StealConfig = require(Config.StealConfig)
local RarityConfig = require(Config.RarityConfig)
local UpgradeConfig = require(Config.UpgradeConfig)
local Catalog = require(Shared.Catalog)
local Economy = require(Shared.Economy)
local Net = require(Shared.Net)

local Modules = script.Parent.Parent.Modules
local Registry = require(Modules.Registry)
local ActionBus = require(Modules.ActionBus)
local Log = require(Modules.Log)

local StealService = {}

type Theft = {
	Thief: Player,
	Victim: Player,
	Uid: string,
	Item: any,
	Name: string,
	Rarity: string,
	Phase: string, -- "Grab" | "Carry"
	StartedAt: number,
	Duration: number,
	CarryStartedAt: number,
	CarryDeadline: number,
	MinCarryTime: number,
	Model: Model?,
	SlotPosition: Vector3,
	VictimPlot: any,
	ThiefPlot: any,
}

local thefts: { [Player]: Theft } = {}
local pairCooldowns: { [string]: number } = {}
local failCooldowns: { [string]: number } = {}
local thiefCooldowns: { [Player]: number } = {}
local victimProtection: { [number]: number } = {}
local trapRearm: { [string]: number } = {}

local carriedFolder: Folder

local function pairKey(thief: Player, victim: Player): string
	return tostring(thief.UserId) .. ":" .. tostring(victim.UserId)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function horizontalDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function fireSteal(player: Player, payload)
	Registry.NetService:Fire(player, Net.Events.Steal, payload)
end

function StealService:Init()
	carriedFolder = Instance.new("Folder")
	carriedFolder.Name = "CarriedCritters"
	carriedFolder.Parent = workspace
end

function StealService:Start()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		if next(thefts) == nil then
			return
		end
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		accumulator = 0
		for thief, theft in thefts do
			local ok, err = pcall(self._update, self, thief, theft)
			if not ok then
				Log.Error("Steal", "update failed: " .. tostring(err))
				self:FailTheft(thief, "Theft interrupted")
			end
		end
	end)
end

---------------------------------------------------------------- queries
function StealService:IsThief(player: Player): boolean
	return thefts[player] ~= nil
end

function StealService:GetTheft(player: Player)
	return thefts[player]
end

function StealService:IsItemBeingStolen(victim: Player, uid: string): boolean
	for _, theft in thefts do
		if theft.Victim == victim and theft.Uid == uid then
			return true
		end
	end
	return false
end

function StealService:IsPlotUnderTheft(plotState): boolean
	for _, theft in thefts do
		if theft.VictimPlot == plotState then
			return true
		end
	end
	return false
end

function StealService:IsVictim(player: Player): boolean
	for _, theft in thefts do
		if theft.Victim == player then
			return true
		end
	end
	return false
end

function StealService:VictimProtectedUntil(victim: Player): number
	return victimProtection[victim.UserId] or 0
end

---------------------------------------------------------------- start
function StealService:StartSteal(thief: Player, ownerUserId: any, uid: any): (boolean, string?)
	if type(ownerUserId) ~= "number" or type(uid) ~= "string" then
		Registry.AntiExploitService:Flag(thief, "InvalidArgs", "StartSteal args")
		return false, "Invalid request"
	end
	local victim = Players:GetPlayerByUserId(ownerUserId)
	if not victim or victim == thief then
		return false, "You can't steal that"
	end
	local thiefData = Registry.DataService:Get(thief)
	local victimData = Registry.DataService:Get(victim)
	if not thiefData or not victimData then
		return false, "Player is still loading"
	end
	if thefts[thief] then
		return false, "You're already stealing something!"
	end
	local now = os.time()
	if (thiefCooldowns[thief] or 0) > os.clock() then
		return false, "Catch your breath first..."
	end
	local key = pairKey(thief, victim)
	if (pairCooldowns[key] or 0) > now then
		return false, string.format("You robbed %s recently — wait %ds", victim.DisplayName, pairCooldowns[key] - now)
	end
	if (failCooldowns[key] or 0) > now then
		return false, string.format("%s is on alert — wait %ds", victim.DisplayName, failCooldowns[key] - now)
	end
	local protected, reason = Registry.BaseService:IsProtected(victim)
	if protected then
		return false, reason
	end
	local item = victimData.Inventory[uid]
	if not item or item.Slot <= 0 then
		return false, "That critter isn't available"
	end
	if Registry.BaseService:IsInTransit(victim, uid) then
		return false, "Wait until it reaches its pedestal"
	end
	if self:IsItemBeingStolen(victim, uid) then
		return false, "Someone else is already stealing it!"
	end
	if not Registry.CollectibleService:HasSpace(thief) then
		return false, "Your base and storage are full"
	end
	local victimPlot = Registry.BaseService:GetPlot(victim)
	local thiefPlot = Registry.BaseService:GetPlot(thief)
	if not victimPlot or not thiefPlot then
		return false, "Base unavailable"
	end
	local root = rootOf(thief)
	local humanoid = thief.Character and thief.Character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return false, "You need to be alive"
	end
	if Registry.PlayerService:IsStunned(thief) then
		return false, "You're stunned!"
	end
	local slotPosition = Registry.BaseService:SlotCFrame(victimPlot, item.Slot).Position
	if horizontalDistance(root.Position, slotPosition) > StealConfig.GrabRange or not Registry.BaseService:IsInside(victimPlot, root.Position) then
		return false, "Get closer to steal it"
	end

	local def = Catalog.Get(item.Id)
	local duration = Economy.StealDuration(item, victimData.Upgrades.Security)
	local theft: Theft = {
		Thief = thief,
		Victim = victim,
		Uid = uid,
		Item = item,
		Name = def and def.Name or "Critter",
		Rarity = def and def.Rarity or "Common",
		Phase = "Grab",
		StartedAt = os.clock(),
		Duration = duration,
		CarryStartedAt = 0,
		CarryDeadline = 0,
		MinCarryTime = 0,
		Model = nil,
		SlotPosition = slotPosition,
		VictimPlot = victimPlot,
		ThiefPlot = thiefPlot,
	}
	thefts[thief] = theft
	local model = Registry.BaseService:GetItemModel(victim, uid)
	if model then
		model:SetAttribute("BeingStolen", true)
	end

	fireSteal(thief, {
		State = "Grab",
		Uid = uid,
		Name = theft.Name,
		Rarity = theft.Rarity,
		Duration = duration,
		EndsAt = workspace:GetServerTimeNow() + duration,
		Victim = victim.DisplayName,
	})
	fireSteal(victim, {
		State = "Alert",
		Phase = "Grab",
		Thief = thief.DisplayName,
		ThiefUserId = thief.UserId,
		Name = theft.Name,
		Rarity = theft.Rarity,
		Uid = uid,
	})
	Registry.NetService:Notify(victim, string.format("🚨 %s is stealing your %s! Run back and catch them!", thief.DisplayName, theft.Name), "Error")
	Registry.BaseService:UpdateStatus(victim)
	ActionBus.Fire(thief, "StealAttempt", 1, { Victim = victim.UserId })
	Log.Info("Steal", string.format("%s started stealing %s from %s (%.1fs)", thief.Name, uid, victim.Name, duration), thief.UserId)
	return true, nil
end

function StealService:CancelSteal(thief: Player): (boolean, string?)
	if not thefts[thief] then
		return false, nil
	end
	self:FailTheft(thief, "You gave up the steal")
	return true, nil
end

---------------------------------------------------------------- update
function StealService:_checkCatch(theft: Theft, thiefRoot: BasePart): boolean
	local victimRoot = rootOf(theft.Victim)
	local victimHumanoid = theft.Victim.Character and theft.Victim.Character:FindFirstChildOfClass("Humanoid")
	if victimRoot and victimHumanoid and victimHumanoid.Health > 0 then
		if (victimRoot.Position - thiefRoot.Position).Magnitude <= StealConfig.CatchRange then
			self:FailTheft(theft.Thief, "🛡️ " .. theft.Victim.DisplayName .. " caught you!", { Caught = true })
			return true
		end
	end
	return false
end

function StealService:_checkTraps(theft: Theft, thiefRoot: BasePart): boolean
	local plot = theft.VictimPlot
	if not Registry.BaseService:IsInside(plot, thiefRoot.Position) then
		return false
	end
	local victimData = Registry.DataService:Get(theft.Victim)
	if not victimData then
		return false
	end
	local trapInfo = Economy.TrackLevelInfo("Traps", victimData.Upgrades.Traps)
	if trapInfo.Count <= 0 then
		return false
	end
	local radius = UpgradeConfig.Tracks.Traps.Radius
	for i, trap in Registry.BaseService:ActiveTraps(plot) do
		local key = tostring(plot.Index) .. ":" .. tostring(i)
		if (trapRearm[key] or 0) <= os.clock() and horizontalDistance(trap.Position, thiefRoot.Position) <= radius then
			trapRearm[key] = os.clock() + UpgradeConfig.Tracks.Traps.RearmTime
			Registry.NetService:EffectAll("TrapZap", { Position = trap.Position })
			self:FailTheft(theft.Thief, "⚡ You stepped on a trap!", { Trap = true, Stun = trapInfo.StunDuration })
			return true
		end
	end
	return false
end

function StealService:_update(thief: Player, theft: Theft)
	if thief.Parent == nil then
		self:FailTheft(thief, "Thief left", { Silent = true })
		return
	end
	if theft.Victim.Parent == nil then
		self:FailTheft(thief, "The owner left the game")
		return
	end
	local character = thief.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = rootOf(thief)
	if not humanoid or not root or humanoid.Health <= 0 then
		self:FailTheft(thief, "You were knocked out!")
		return
	end
	local victimData = Registry.DataService:Get(theft.Victim)
	if not victimData or victimData.Inventory[theft.Uid] ~= theft.Item then
		self:FailTheft(thief, "The critter is gone")
		return
	end

	if self:_checkCatch(theft, root) or self:_checkTraps(theft, root) then
		return
	end

	local now = os.clock()
	if theft.Phase == "Grab" then
		if theft.VictimPlot.Locked then
			self:FailTheft(thief, "🔒 The base was locked!")
			return
		end
		if horizontalDistance(root.Position, theft.SlotPosition) > StealConfig.GrabRange + 2 then
			self:FailTheft(thief, "You moved away — steal cancelled")
			return
		end
		if now - theft.StartedAt >= theft.Duration then
			self:_beginCarry(theft, root)
		end
	else
		if now > theft.CarryDeadline then
			self:FailTheft(thief, "⏰ Too slow! The critter ran home.")
			return
		end
		if Registry.BaseService:IsInside(theft.ThiefPlot, root.Position) then
			if now - theft.CarryStartedAt < theft.MinCarryTime then
				Registry.AntiExploitService:Flag(thief, "StealTooFast", string.format("%.1fs < %.1fs", now - theft.CarryStartedAt, theft.MinCarryTime))
				self:FailTheft(thief, "Theft failed")
				return
			end
			self:_succeed(theft)
		end
	end
end

function StealService:_beginCarry(theft: Theft, thiefRoot: BasePart)
	local model = Registry.BaseService:DetachItemModel(theft.Victim, theft.Uid)
	if not model or not model.PrimaryPart then
		self:FailTheft(theft.Thief, "The critter escaped")
		return
	end
	local root = model.PrimaryPart :: BasePart
	model:SetAttribute("Carried", true)
	model:SetAttribute("CarriedBy", theft.Thief.UserId)
	model:SetAttribute("BeingStolen", true)
	root.Anchored = false
	model:PivotTo(thiefRoot.CFrame * CFrame.new(0, StealConfig.CarryHeight, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Name = "CarryWeld"
	weld.Part0 = thiefRoot
	weld.Part1 = root
	weld.Parent = root
	model.Parent = carriedFolder
	theft.Model = model
	theft.Phase = "Carry"
	theft.CarryStartedAt = os.clock()
	theft.CarryDeadline = os.clock() + StealConfig.CarryTimeLimit

	Registry.PlayerService:SetCarryMultiplier(theft.Thief, Economy.CarrySpeedMultiplier(theft.Item))
	local humanoid = theft.Thief.Character and theft.Thief.Character:FindFirstChildOfClass("Humanoid")
	local speed = humanoid and humanoid.WalkSpeed or 16
	local home = Registry.BaseService:EntranceCFrame(theft.ThiefPlot).Position
	theft.MinCarryTime = horizontalDistance(thiefRoot.Position, home) / (math.max(speed, 1) * StealConfig.MinCarrySpeedFactor)

	fireSteal(theft.Thief, {
		State = "Carry",
		Uid = theft.Uid,
		Name = theft.Name,
		Rarity = theft.Rarity,
		Deadline = workspace:GetServerTimeNow() + StealConfig.CarryTimeLimit,
		Home = home,
	})
	fireSteal(theft.Victim, {
		State = "Alert",
		Phase = "Carry",
		Thief = theft.Thief.DisplayName,
		ThiefUserId = theft.Thief.UserId,
		Name = theft.Name,
		Rarity = theft.Rarity,
		Uid = theft.Uid,
	})
	Registry.NetService:Notify(theft.Victim, string.format("🏃 %s grabbed your %s! Chase them down!", theft.Thief.DisplayName, theft.Name), "Error")
end

function StealService:_succeed(theft: Theft)
	local thief, victim = theft.Thief, theft.Victim
	thefts[thief] = nil
	local item, err = Registry.CollectibleService:Transfer(victim, thief, theft.Uid, "Steal", { Silent = false })
	if theft.Model then
		theft.Model:Destroy()
	end
	Registry.PlayerService:SetCarryMultiplier(thief, 1)
	if not item then
		-- Could not transfer (e.g. no space): put it back.
		Log.Warn("Steal", "transfer failed: " .. tostring(err))
		local stillOwned = Registry.DataService:Get(victim)
		if stillOwned and stillOwned.Inventory[theft.Uid] then
			Registry.BaseService:SpawnItemModel(victim, stillOwned.Inventory[theft.Uid], nil)
		end
		fireSteal(thief, { State = "Fail", Reason = err or "Steal failed" })
		fireSteal(victim, { State = "AlertEnd", Result = "Failed" })
		Registry.BaseService:UpdateStatus(victim)
		return
	end

	local now = os.time()
	pairCooldowns[pairKey(thief, victim)] = now + StealConfig.PairCooldown
	thiefCooldowns[thief] = os.clock() + StealConfig.ThiefCooldown
	local victimData = Registry.DataService:Get(victim)
	local thiefData = Registry.DataService:Get(thief)
	if victimData then
		local protection = Economy.TrackLevelInfo("AntiSteal", victimData.Upgrades.AntiSteal).Protection
		victimProtection[victim.UserId] = now + protection
		victimData.Stats.TimesRobbed += 1
		Registry.DataService:MarkDirty(victim, "Stats")
	end
	if thiefData then
		thiefData.Stats.Steals += 1
		Registry.DataService:MarkDirty(thief, "Stats")
		thief:SetAttribute("Steals", thiefData.Stats.Steals)
	end
	ActionBus.Fire(thief, "Steal", 1, { Rarity = theft.Rarity, Victim = victim.UserId })

	fireSteal(thief, { State = "Success", Name = theft.Name, Rarity = theft.Rarity, Victim = victim.DisplayName })
	fireSteal(victim, { State = "AlertEnd", Result = "Stolen", Thief = thief.DisplayName, Name = theft.Name })
	Registry.NetService:Notify(victim, string.format("💔 %s stole your %s! You're protected for a little while.", thief.DisplayName, theft.Name), "Error")
	local rarity = RarityConfig.Rarities[theft.Rarity]
	if rarity.Tier >= RarityConfig.Tier(StealConfig.AnnounceMinRarity) then
		Registry.NetService:Announce(string.format("🦹 %s stole a %s %s from %s!", thief.DisplayName, string.upper(rarity.Name), theft.Name, victim.DisplayName), rarity.Color, "🦹", theft.Rarity)
	end
	Registry.BaseService:UpdateStatus(victim)
	Log.Info("Steal", string.format("%s stole %s from %s", thief.Name, theft.Uid, victim.Name), thief.UserId)
end

---------------------------------------------------------------- failure
export type FailOptions = { Caught: boolean?, Trap: boolean?, Stun: number?, Silent: boolean? }

function StealService:FailTheft(thief: Player, reason: string, options: FailOptions?)
	local theft = thefts[thief]
	if not theft then
		return
	end
	local opts: FailOptions = options or {}
	thefts[thief] = nil
	local victim = theft.Victim

	-- Return the critter to its pedestal.
	if theft.Model then
		if victim.Parent and Registry.DataService:Get(victim) then
			Registry.BaseService:ReattachItemModel(victim, theft.Uid, theft.Model)
		else
			theft.Model:Destroy()
		end
	end
	local model = Registry.BaseService:GetItemModel(victim, theft.Uid)
	if model then
		model:SetAttribute("BeingStolen", false)
	end

	Registry.PlayerService:SetCarryMultiplier(thief, 1)
	if thief.Parent then
		failCooldowns[pairKey(thief, victim)] = os.time() + StealConfig.FailCooldown
		thiefCooldowns[thief] = os.clock() + StealConfig.ThiefCooldown
		local thiefData = Registry.DataService:Get(thief)
		if thiefData then
			thiefData.Stats.StealsFailed += 1
			Registry.DataService:MarkDirty(thief, "Stats")
		end
		if not opts.Silent then
			fireSteal(thief, { State = "Fail", Reason = reason, Caught = opts.Caught == true, Trap = opts.Trap == true })
		end
		if opts.Caught or opts.Trap then
			Registry.PlayerService:Stun(thief, opts.Stun or StealConfig.FailStun)
			task.delay(opts.Stun or StealConfig.FailStun, function()
				if thief.Parent and not thefts[thief] then
					Registry.BaseService:TeleportHome(thief)
				end
			end)
		end
	end

	if victim.Parent then
		fireSteal(victim, { State = "AlertEnd", Result = if opts.Caught then "Caught" elseif opts.Trap then "Trapped" else "Failed", Thief = thief.DisplayName, Name = theft.Name })
		if opts.Caught then
			local victimData = Registry.DataService:Get(victim)
			if victimData then
				victimData.Stats.Catches += 1
				Registry.DataService:MarkDirty(victim, "Stats")
			end
			ActionBus.Fire(victim, "Catch", 1, { Thief = thief.UserId })
			Registry.NetService:Notify(victim, "🛡️ You caught " .. thief.DisplayName .. "! Your " .. theft.Name .. " is safe.", "Success")
		elseif opts.Trap then
			Registry.NetService:Notify(victim, "⚡ Your trap zapped " .. thief.DisplayName .. "!", "Success")
		elseif not opts.Silent then
			Registry.NetService:Notify(victim, "Your " .. theft.Name .. " is safe — the thief gave up.", "Info")
		end
		Registry.BaseService:UpdateStatus(victim)
	end
	Log.Info("Steal", string.format("%s failed to steal from %s: %s", thief.Name, victim.Name, reason), thief.UserId)
end

---------------------------------------------------------------- hooks
function StealService:OnBaseLocked(plotState)
	for thief, theft in thefts do
		if theft.VictimPlot == plotState then
			local root = rootOf(thief)
			if theft.Phase == "Grab" or (root and Registry.BaseService:IsInside(plotState, root.Position)) then
				self:FailTheft(thief, "🔒 The laser door slammed shut!")
			end
		end
	end
end

function StealService:OnPlayerRemoving(player: Player)
	if thefts[player] then
		self:FailTheft(player, "Thief left", { Silent = true })
	end
	for thief, theft in thefts do
		if theft.Victim == player then
			self:FailTheft(thief, "The owner left the game")
		end
	end
	thiefCooldowns[player] = nil
end

-- Admin / tests: wipe cooldowns.
function StealService:ResetCooldowns()
	table.clear(pairCooldowns)
	table.clear(failCooldowns)
	table.clear(thiefCooldowns)
	table.clear(victimProtection)
end

return StealService
