--[[
	BaseService
	Owns the eight player bases (plots): assignment, collectible models on the
	slot pedestals, lock / laser door, intruder ejection, alarms, status lights,
	themes and particle effects.

	Plot model attributes (read by clients):
		OwnerUserId, OwnerName, Status ("Open"|"Locked"|"Shielded"|"Protected"|"Theft"),
		LockEndsAt, LockReadyAt, Uncollected, CashPerSec, HighlightIntruders, Claimed
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local MapConfig = require(Config.MapConfig)
local GameConfig = require(Config.GameConfig)
local StealConfig = require(Config.StealConfig)
local RarityConfig = require(Config.RarityConfig)
local CosmeticConfig = require(Config.CosmeticConfig)
local TraitConfig = require(Config.TraitConfig)
local Catalog = require(Shared.Catalog)
local Economy = require(Shared.Economy)
local CreatureBuilder = require(Shared.CreatureBuilder)
local CardBillboard = require(Shared.CardBillboard)
local Format = require(Shared.Util.Format)

local Modules = script.Parent.Parent.Modules
local Registry = require(Modules.Registry)
local ActionBus = require(Modules.ActionBus)
local Log = require(Modules.Log)

local BaseService = {}

export type PlotState = {
	Index: number,
	Refs: any,
	Owner: Player?,
	OwnerId: number,
	Locked: boolean,
	LockEndsAt: number,
	LockReadyAt: number,
	Models: { [string]: Model },
	Transit: { [string]: number },
	IntruderNotified: { [Player]: number },
	Status: string,
}

BaseService.Plots = {} :: { PlotState }
local plotByPlayer: { [Player]: PlotState } = {}

local STATUS_COLORS = {
	Open = Color3.fromRGB(255, 220, 90),
	Locked = Color3.fromRGB(90, 255, 140),
	Shielded = Color3.fromRGB(150, 140, 255),
	Protected = Color3.fromRGB(120, 200, 255),
	Theft = Color3.fromRGB(255, 50, 70),
}

local STATUS_TEXT = {
	Open = "🔓 OPEN",
	Locked = "🔒 LOCKED",
	Shielded = "🛡️ SHIELDED",
	Protected = "🛡️ PROTECTED",
	Theft = "🚨 THIEF!",
}

function BaseService:Init() end

function BaseService:SetMap(mapRefs)
	for i, refs in mapRefs.Plots do
		self.Plots[i] = {
			Index = i,
			Refs = refs,
			Owner = nil,
			OwnerId = 0,
			Locked = false,
			LockEndsAt = 0,
			LockReadyAt = 0,
			Models = {},
			Transit = {},
			IntruderNotified = {},
			Status = "Open",
		}
		refs.Model:SetAttribute("Status", "Open")
		refs.Model:SetAttribute("LockEndsAt", 0)
		refs.Model:SetAttribute("LockReadyAt", 0)
		refs.Model:SetAttribute("Uncollected", 0)
		refs.Model:SetAttribute("Claimed", false)
		self:_applyThemeToPlot(self.Plots[i], CosmeticConfig.Defaults.BaseTheme)
		self:_showVacant(self.Plots[i])
	end
end

function BaseService:Start()
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, state in self.Plots do
				if state.Owner then
					local ok, err = pcall(self._updatePlot, self, state)
					if not ok then
						Log.Error("Base", "plot update failed: " .. tostring(err))
					end
				end
			end
		end
	end)
end

---------------------------------------------------------------- lookup
function BaseService:GetPlot(player: Player): PlotState?
	return plotByPlayer[player]
end

function BaseService:GetPlotByIndex(index: number): PlotState?
	return self.Plots[index]
end

function BaseService:GetPlotByUserId(userId: number): PlotState?
	for _, state in self.Plots do
		if state.OwnerId == userId and state.Owner then
			return state
		end
	end
	return nil
end

function BaseService:SlotCFrame(state: PlotState, slot: number): CFrame
	return state.Refs.Slots[slot].CFrame
end

function BaseService:IsInside(state: PlotState, position: Vector3): boolean
	local localPos = state.Refs.Origin:PointToObjectSpace(position)
	local minB, maxB = MapConfig.Plot.BoundsMin, MapConfig.Plot.BoundsMax
	return localPos.X >= minB.X and localPos.X <= maxB.X
		and localPos.Y >= minB.Y and localPos.Y <= maxB.Y
		and localPos.Z >= minB.Z and localPos.Z <= maxB.Z
end

function BaseService:PlotContaining(position: Vector3): PlotState?
	for _, state in self.Plots do
		if self:IsInside(state, position) then
			return state
		end
	end
	return nil
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function BaseService:IsPlayerInOwnBase(player: Player): boolean
	local state = plotByPlayer[player]
	local root = rootOf(player)
	return state ~= nil and root ~= nil and self:IsInside(state, root.Position)
end

function BaseService:EntranceCFrame(state: PlotState): CFrame
	local halfZ = MapConfig.Plot.Size.Z / 2
	return state.Refs.Origin * CFrame.new(0, 4, -halfZ - 9) * CFrame.Angles(0, math.pi, 0)
end

function BaseService:SpawnCFrame(state: PlotState): CFrame
	return state.Refs.Origin * CFrame.new(MapConfig.Plot.Spawn + Vector3.new(0, 4, 0))
end

---------------------------------------------------------------- assignment
function BaseService:AssignPlot(player: Player): PlotState?
	if plotByPlayer[player] then
		return plotByPlayer[player]
	end
	local chosen: PlotState? = nil
	for _, state in self.Plots do
		if state.Owner == nil then
			chosen = state
			break
		end
	end
	if not chosen then
		Log.Warn("Base", "No free plot for " .. player.Name .. " (server full)")
		return nil
	end
	local state = chosen :: PlotState
	state.Owner = player
	state.OwnerId = player.UserId
	state.Locked = false
	state.LockEndsAt = 0
	state.LockReadyAt = 0
	plotByPlayer[player] = state

	local model = state.Refs.Model
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("OwnerName", player.DisplayName)
	local data = Registry.DataService:Get(player)
	model:SetAttribute("Claimed", data ~= nil and data.Tutorial.Step > 1)
	player:SetAttribute("PlotIndex", state.Index)
	player.RespawnLocation = state.Refs.Spawn
	Registry.DataService:SetSession(player, "PlotIndex", state.Index)

	self:ApplyCosmetics(player)
	self:RefreshSlots(player)
	self:SpawnAllModels(player)
	self:UpdateTraps(player)
	self:_setDoor(state, false)
	self:_updateSign(state)
	self:UpdateStatus(player)
	Log.Info("Base", string.format("Assigned plot %d to %s", state.Index, player.Name), player.UserId)
	return state
end

function BaseService:_showVacant(state: PlotState)
	local refs = state.Refs
	refs.SignTitle.Text = "OPEN PLOT"
	refs.SignIncome.Text = ""
	refs.SignStatus.Text = "Waiting for a player"
	for _, light in refs.Lights do
		light.Color = Color3.fromRGB(150, 150, 170)
	end
	for _, slot in refs.Slots do
		slot.Pedestal.Transparency = 0.6
		slot.Rim.Color = Color3.fromRGB(110, 110, 130)
		slot.Rim.Transparency = 0.6
	end
	for _, trap in refs.Traps do
		trap.Transparency = 1
	end
	local pad = refs.CollectPad:FindFirstChild("CashDisplay")
	if pad then
		(pad:FindFirstChild("Amount") :: TextLabel).Text = "$0"
	end
end

function BaseService:ReleasePlot(player: Player)
	local state = plotByPlayer[player]
	if not state then
		return
	end
	plotByPlayer[player] = nil
	for uid, model in state.Models do
		model:Destroy()
		state.Models[uid] = nil
	end
	table.clear(state.Transit)
	table.clear(state.IntruderNotified)
	state.Owner = nil
	state.OwnerId = 0
	state.Locked = false
	local model = state.Refs.Model
	model:SetAttribute("OwnerUserId", 0)
	model:SetAttribute("OwnerName", "")
	model:SetAttribute("Status", "Open")
	model:SetAttribute("Claimed", false)
	model:SetAttribute("HighlightIntruders", false)
	self:_setDoor(state, false)
	self:_applyThemeToPlot(state, CosmeticConfig.Defaults.BaseTheme)
	self:_applyEffectToPlot(state, "Effect_None")
	self:_showVacant(state)
end

function BaseService:OnPlayerLoaded(player: Player)
	if not self:AssignPlot(player) then
		-- More players than plots: the place's server size is set above
		-- GameConfig.MaxPlayers. Data is released (and saved) on removal.
		player:Kick("This server is full. Please join another server!")
	end
end

function BaseService:OnPlayerRemoving(player: Player)
	self:ReleasePlot(player)
end

---------------------------------------------------------------- slots & models
function BaseService:RefreshSlots(player: Player)
	local state = plotByPlayer[player]
	if not state then
		return
	end
	local capacity = Registry.CollectibleService:Capacity(player)
	local occupied: { [number]: string } = {}
	local data = Registry.DataService:Get(player)
	if data then
		for _, item in data.Inventory do
			if item.Slot > 0 then
				local def = Catalog.Get(item.Id)
				occupied[item.Slot] = def and def.Rarity or "Common"
			end
		end
	end
	for i, slot in state.Refs.Slots do
		if i <= capacity then
			slot.Pedestal.Transparency = 0
			slot.Pedestal.Color = Color3.fromRGB(240, 242, 250)
			slot.Rim.Transparency = 0
			local rarity = occupied[i]
			slot.Rim.Color = if rarity then RarityConfig.Rarities[rarity].Color else Color3.fromRGB(150, 160, 190)
		elseif i <= capacity + 3 then
			-- Next few locked slots are visible as a hint to upgrade.
			slot.Pedestal.Transparency = 0.55
			slot.Pedestal.Color = Color3.fromRGB(70, 70, 90)
			slot.Rim.Transparency = 0.6
			slot.Rim.Color = Color3.fromRGB(255, 90, 90)
		else
			slot.Pedestal.Transparency = 0.85
			slot.Pedestal.Color = Color3.fromRGB(70, 70, 90)
			slot.Rim.Transparency = 1
		end
	end
	state.Refs.Model:SetAttribute("Capacity", capacity)
end

local function travelDuration(from: Vector3, to: Vector3, item): number
	local cfg = GameConfig.Travel
	local duration = (from - to).Magnitude / cfg.StudsPerSecond
	local trait = TraitConfig.Get(item.Trait)
	if trait and trait.TravelSpeedMultiplier then
		duration /= trait.TravelSpeedMultiplier
	end
	return math.clamp(duration, cfg.MinDuration, cfg.MaxDuration)
end

function BaseService:_cardInfo(player: Player, item)
	local data = Registry.DataService:Get(player)
	return {
		Mode = "Base",
		Id = item.Id,
		Mutation = item.Mutation,
		Trait = item.Trait,
		Level = item.Level,
		Serial = item.Serial,
		Income = Economy.ItemIncome(item),
		OwnerName = player.DisplayName,
		FrameId = data and data.Cosmetics.Equipped.CardFrame or nil,
	}
end

function BaseService:SpawnItemModel(player: Player, item, travelFrom: Vector3?): Model?
	local state = plotByPlayer[player]
	if not state or item.Slot <= 0 or not state.Refs.Slots[item.Slot] then
		return nil
	end
	local existing = state.Models[item.Uid]
	if existing then
		existing:Destroy()
	end
	local def = Catalog.Get(item.Id)
	local model = CreatureBuilder.Build(item.Id, { Mutation = item.Mutation })
	model.Name = item.Uid
	local home = self:SlotCFrame(state, item.Slot)
	model:PivotTo(home)
	model:SetAttribute("Uid", item.Uid)
	model:SetAttribute("CollectibleId", item.Id)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("PlotIndex", state.Index)
	model:SetAttribute("Slot", item.Slot)
	model:SetAttribute("Mutation", item.Mutation)
	model:SetAttribute("Trait", item.Trait or "")
	model:SetAttribute("Level", item.Level)
	model:SetAttribute("Income", Economy.ItemIncome(item))
	model:SetAttribute("Rarity", def and def.Rarity or "Common")
	model:SetAttribute("Animation", def and def.Animation or "Bob")
	model:SetAttribute("HomeCFrame", home)
	if travelFrom then
		local duration = travelDuration(travelFrom, home.Position, item)
		model:SetAttribute("TravelFrom", travelFrom)
		model:SetAttribute("TravelStart", workspace:GetServerTimeNow())
		model:SetAttribute("TravelDuration", duration)
		model:SetAttribute("Entrance", self:EntranceCFrame(state).Position)
		state.Transit[item.Uid] = os.clock() + duration
	end
	CardBillboard.Attach(model, self:_cardInfo(player, item))
	CollectionService:AddTag(model, "BaseCreature")
	model.Parent = state.Refs.Creatures
	state.Models[item.Uid] = model
	return model
end

function BaseService:SpawnAllModels(player: Player)
	local data = Registry.DataService:Get(player)
	if not data then
		return
	end
	for _, item in data.Inventory do
		if item.Slot > 0 then
			self:SpawnItemModel(player, item, nil)
		end
	end
end

function BaseService:DespawnItemModel(player: Player, uid: string)
	local state = plotByPlayer[player]
	if not state then
		return
	end
	local model = state.Models[uid]
	if model then
		model:Destroy()
		state.Models[uid] = nil
	end
	state.Transit[uid] = nil
end

function BaseService:GetItemModel(player: Player, uid: string): Model?
	local state = plotByPlayer[player]
	return state and state.Models[uid] or nil
end

-- Hands a model to the theft system (it stays out of the slot while carried).
function BaseService:DetachItemModel(player: Player, uid: string): Model?
	local state = plotByPlayer[player]
	if not state then
		return nil
	end
	local model = state.Models[uid]
	state.Models[uid] = nil
	return model
end

-- Puts a model back on its slot (failed theft).
function BaseService:ReattachItemModel(player: Player, uid: string, model: Model)
	local state = plotByPlayer[player]
	local data = Registry.DataService:Get(player)
	local item = data and data.Inventory[uid]
	if not state or not item or item.Slot <= 0 then
		model:Destroy()
		return
	end
	local root = model.PrimaryPart
	if root then
		for _, d in root:GetChildren() do
			if d:IsA("WeldConstraint") and d.Name == "CarryWeld" then
				d:Destroy()
			end
		end
		root.Anchored = true
	end
	model:PivotTo(self:SlotCFrame(state, item.Slot))
	model:SetAttribute("Carried", false)
	model.Parent = state.Refs.Creatures
	state.Models[uid] = model
end

function BaseService:RefreshItemModel(player: Player, item)
	local model = self:GetItemModel(player, item.Uid)
	if not model then
		return
	end
	model:SetAttribute("Level", item.Level)
	model:SetAttribute("Income", Economy.ItemIncome(item))
	CardBillboard.Attach(model, self:_cardInfo(player, item))
end

function BaseService:RefreshAllCards(player: Player)
	local data = Registry.DataService:Get(player)
	if not data then
		return
	end
	for _, item in data.Inventory do
		if item.Slot > 0 then
			self:RefreshItemModel(player, item)
		end
	end
end

function BaseService:IsInTransit(player: Player, uid: string): boolean
	local state = plotByPlayer[player]
	if not state then
		return false
	end
	local endsAt = state.Transit[uid]
	return endsAt ~= nil and endsAt > os.clock()
end

---------------------------------------------------------------- lock & protection
function BaseService:_setDoor(state: PlotState, on: boolean)
	local door = state.Refs.Door
	door.Transparency = if on then 0.35 else 1
	door.CanCollide = on
end

function BaseService:Lock(player: Player): (boolean, string?)
	local state = plotByPlayer[player]
	if not state then
		return false, "You don't have a base"
	end
	if not self:IsPlayerInOwnBase(player) then
		return false, "You must be in your base to lock it"
	end
	local now = os.time()
	if state.Locked then
		return false, string.format("Already locked (%ds left)", state.LockEndsAt - now)
	end
	if now < state.LockReadyAt then
		return false, string.format("Lock recharging: %ds", state.LockReadyAt - now)
	end
	local data = Registry.DataService:Get(player)
	local duration = Economy.LockDuration(data and data.Upgrades.Security or 0)
	state.Locked = true
	state.LockEndsAt = now + duration
	state.Refs.Model:SetAttribute("LockEndsAt", state.LockEndsAt)
	self:_setDoor(state, true)
	Registry.StealService:OnBaseLocked(state)
	self:_ejectIntruders(state)
	self:UpdateStatus(player)
	ActionBus.Fire(player, "Lock", 1, {})
	Registry.NetService:Effect(player, "BaseLocked", { Duration = duration })
	return true, string.format("Base locked for %ds!", duration)
end

function BaseService:_unlock(state: PlotState)
	state.Locked = false
	state.LockReadyAt = os.time() + StealConfig.LockCooldown
	state.Refs.Model:SetAttribute("LockReadyAt", state.LockReadyAt)
	self:_setDoor(state, false)
	if state.Owner then
		Registry.NetService:Notify(state.Owner, "🔓 Your base lock ended. Lock again in " .. StealConfig.LockCooldown .. "s.", "Warning")
		self:UpdateStatus(state.Owner)
	end
end

-- Applies an admin/product shield lock without the cooldown rules.
function BaseService:ForceLock(player: Player, duration: number)
	local state = plotByPlayer[player]
	if not state then
		return
	end
	state.Locked = true
	state.LockEndsAt = math.max(state.LockEndsAt, os.time() + duration)
	state.Refs.Model:SetAttribute("LockEndsAt", state.LockEndsAt)
	self:_setDoor(state, true)
	Registry.StealService:OnBaseLocked(state)
	self:_ejectIntruders(state)
	self:UpdateStatus(player)
end

function BaseService:IsLocked(state: PlotState): boolean
	return state.Locked
end

-- Returns (protected, reason) for a potential theft victim.
function BaseService:IsProtected(victim: Player): (boolean, string?)
	local state = plotByPlayer[victim]
	local data = Registry.DataService:Get(victim)
	if not state or not data then
		return true, "Unavailable"
	end
	if state.Locked then
		return true, "This base is locked"
	end
	if Registry.BoostService:IsActive(victim, "Protection") then
		return true, "This base is shielded"
	end
	if data.Stats.Playtime < StealConfig.NewPlayerProtection then
		return true, "New player protection is active"
	end
	if Registry.StealService:VictimProtectedUntil(victim) > os.time() then
		return true, "This player was just robbed — they're protected"
	end
	return false, nil
end

function BaseService:_ejectIntruders(state: PlotState)
	for _, other in Players:GetPlayers() do
		if other ~= state.Owner then
			local root = rootOf(other)
			if root and self:IsInside(state, root.Position) then
				Registry.AntiExploitService:Teleport(other, self:EntranceCFrame(state))
				Registry.NetService:Notify(other, "🔒 That base is locked!", "Warning")
			end
		end
	end
end

function BaseService:UpdateStatus(player: Player)
	local state = plotByPlayer[player]
	if not state then
		return
	end
	local status = "Open"
	if Registry.StealService:IsPlotUnderTheft(state) then
		status = "Theft"
	elseif state.Locked then
		status = "Locked"
	elseif Registry.BoostService:IsActive(player, "Protection") then
		status = "Shielded"
	else
		local protected = self:IsProtected(player)
		if protected then
			status = "Protected"
		end
	end
	state.Refs.Model:SetAttribute("ProtectedUntil", math.max(
		Registry.StealService:VictimProtectedUntil(player),
		(Registry.DataService:Get(player) or { Boosts = {} }).Boosts.Protection or 0
	))
	if status ~= state.Status then
		state.Status = status
		state.Refs.Model:SetAttribute("Status", status)
		for _, light in state.Refs.Lights do
			light.Color = STATUS_COLORS[status]
		end
		state.Refs.SignStatus.Text = STATUS_TEXT[status]
		state.Refs.SignStatus.TextColor3 = STATUS_COLORS[status]
	end
end

function BaseService:_updateSign(state: PlotState)
	local owner = state.Owner
	if not owner then
		return
	end
	state.Refs.SignTitle.Text = string.upper(owner.DisplayName) .. "'S BASE"
	state.Refs.SignIncome.Text = Format.PerSec(Registry.EconomyService:GetCashPerSec(owner))
end

function BaseService:SetUncollectedDisplay(player: Player, amount: number)
	local state = plotByPlayer[player]
	if not state then
		return
	end
	local model = state.Refs.Model
	model:SetAttribute("Uncollected", amount)
	model:SetAttribute("CashPerSec", Registry.EconomyService:GetCashPerSec(player))
	local display = state.Refs.CollectPad:FindFirstChild("CashDisplay")
	local label = display and display:FindFirstChild("Amount") :: TextLabel?
	if label then
		local data = Registry.DataService:Get(player)
		label.Text = if data and data.Upgrades.AutoCollect >= 1 then "AUTO 🧲" else Format.Cash(amount)
	end
	self:_updateSign(state)
end

---------------------------------------------------------------- periodic update
function BaseService:_updatePlot(state: PlotState)
	local owner = state.Owner :: Player
	local now = os.time()
	if state.Locked then
		if now >= state.LockEndsAt then
			self:_unlock(state)
		else
			self:_ejectIntruders(state)
		end
	end
	for uid, endsAt in state.Transit do
		if endsAt <= os.clock() then
			state.Transit[uid] = nil
			ActionBus.Fire(owner, "Arrive", 1, { Uid = uid })
		end
	end

	-- Alarm / theft detection upgrades
	local data = Registry.DataService:Get(owner)
	local alarmLevel = data and data.Upgrades.Alarm or 0
	state.Refs.Model:SetAttribute("HighlightIntruders", alarmLevel >= 2)
	if alarmLevel >= 1 then
		for _, other in Players:GetPlayers() do
			if other ~= owner then
				local root = rootOf(other)
				if root and self:IsInside(state, root.Position) then
					local last = state.IntruderNotified[other] or 0
					if os.clock() - last > 20 then
						state.IntruderNotified[other] = os.clock()
						Registry.NetService:Notify(owner, "👀 " .. other.DisplayName .. " entered your base!", "Warning")
						Registry.NetService:Effect(owner, "IntruderAlert", { Name = other.DisplayName })
					end
				end
			end
		end
	end
	self:UpdateStatus(owner)
end

---------------------------------------------------------------- traps
function BaseService:UpdateTraps(player: Player)
	local state = plotByPlayer[player]
	local data = Registry.DataService:Get(player)
	if not state or not data then
		return
	end
	local count = Economy.TrackLevelInfo("Traps", data.Upgrades.Traps).Count
	for i, trap in state.Refs.Traps do
		trap.Transparency = if i <= count then 0.25 else 1
		trap:SetAttribute("Active", i <= count)
	end
end

function BaseService:ActiveTraps(state: PlotState): { BasePart }
	local list = {}
	for _, trap in state.Refs.Traps do
		if trap:GetAttribute("Active") then
			table.insert(list, trap)
		end
	end
	return list
end

---------------------------------------------------------------- cosmetics
function BaseService:_applyThemeToPlot(state: PlotState, themeId: string)
	local theme = CosmeticConfig.Get(themeId) or CosmeticConfig.Items.Theme_Default
	local refs = state.Refs
	refs.Floor.Color = theme.Floor
	for _, wall in refs.Walls do
		wall.Color = theme.Wall
	end
	for _, trim in refs.Trims do
		trim.Color = theme.Trim
	end
end

function BaseService:_applyEffectToPlot(state: PlotState, effectId: string)
	local effectPart = state.Refs.EffectPart
	local existing = effectPart:FindFirstChild("BaseEffect")
	if existing then
		existing:Destroy()
	end
	local effect = CosmeticConfig.Get(effectId)
	if not effect or effectId == "Effect_None" then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "BaseEffect"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(effect.Color or Color3.new(1, 1, 1))
	emitter.Rate = effect.Rate or 6
	emitter.Speed = NumberRange.new(effect.Speed or 1)
	emitter.Lifetime = NumberRange.new(4, 7)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, effect.Size or 0.4), NumberSequenceKeypoint.new(1, 0) })
	emitter.LightEmission = 1
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.SpreadAngle = Vector2.new(15, 15)
	emitter:AddTag("CreatureFX")
	emitter.Parent = effectPart
end

function BaseService:ApplyCosmetics(player: Player)
	local state = plotByPlayer[player]
	local data = Registry.DataService:Get(player)
	if not state or not data then
		return
	end
	self:_applyThemeToPlot(state, data.Cosmetics.Equipped.BaseTheme)
	self:_applyEffectToPlot(state, data.Cosmetics.Equipped.BaseEffect)
end

---------------------------------------------------------------- travel & claim
function BaseService:TeleportHome(player: Player): boolean
	local state = plotByPlayer[player]
	if not state then
		return false
	end
	Registry.AntiExploitService:Teleport(player, self:SpawnCFrame(state))
	return true
end

function BaseService:TeleportToEntrance(player: Player, state: PlotState)
	Registry.AntiExploitService:Teleport(player, self:EntranceCFrame(state) * CFrame.Angles(0, math.pi, 0))
end

function BaseService:Claim(player: Player): (boolean, string?)
	local state = plotByPlayer[player]
	if not state then
		return false, "No base assigned"
	end
	local root = rootOf(player)
	if not root or not self:IsInside(state, root.Position) then
		return false, "Walk to your base first"
	end
	state.Refs.Model:SetAttribute("Claimed", true)
	ActionBus.Fire(player, "Claim", 1, {})
	Registry.NetService:Effect(player, "BaseClaimed", { Plot = state.Index })
	return true, "This base is yours! 🏠"
end

return BaseService
