--[[
	EconomyService
	The only code that changes Cash / Tokens / EventTokens.
	- One centralised income tick for all players (no per-collectible loops).
	- Income accumulates on the base collector pad (or goes straight to the
	  wallet with the Auto-Collector upgrade).
	- Jackpot trait payouts, offline earnings, personal luck calculation.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local GameConfig = require(Config.GameConfig)
local TraitConfig = require(Config.TraitConfig)
local BoostConfig = require(Config.BoostConfig)
local MonetizationConfig = require(Config.MonetizationConfig)
local MapConfig = require(Config.MapConfig)
local Economy = require(Shared.Economy)
local Format = require(Shared.Util.Format)
local TableUtil = require(Shared.Util.TableUtil)

local Modules = script.Parent.Parent.Modules
local Registry = require(Modules.Registry)
local ActionBus = require(Modules.ActionBus)
local Log = require(Modules.Log)

local EconomyService = {}

-- Reasons that count toward TotalEarned and "Earn" quests.
local EARNED_REASONS = { Income = true, Jackpot = true, Offline = true, Sell = true, Reward = true, Quest = true }

local rng = Random.new()

function EconomyService:Init() end

function EconomyService:Start()
	task.spawn(function()
		while true do
			task.wait(GameConfig.Income.TickInterval)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(self._tick, self, player)
				if not ok then
					Log.Error("Economy", "tick error: " .. tostring(err), player.UserId)
				end
			end
		end
	end)
end

---------------------------------------------------------------- currencies
local function validAmount(amount: any): boolean
	return TableUtil.IsFiniteNumber(amount) and amount > 0
end

function EconomyService:AddCash(player: Player, amount: number, reason: string): boolean
	local data = Registry.DataService:Get(player)
	if not data or not validAmount(amount) then
		return false
	end
	amount = math.floor(amount * 100 + 0.5) / 100
	data.Cash += amount
	if EARNED_REASONS[reason] then
		data.TotalEarned += amount
		ActionBus.Fire(player, "Earn", amount, { Reason = reason })
	end
	Registry.DataService:MarkDirty(player, "Cash")
	Registry.DataService:MarkDirty(player, "TotalEarned")
	Registry.AntiExploitService:AuditCash(player, amount, reason, self:GetCashPerSec(player))
	return true
end

function EconomyService:SpendCash(player: Player, amount: number, reason: string): boolean
	local data = Registry.DataService:Get(player)
	if not data or not TableUtil.IsFiniteNumber(amount) or amount < 0 then
		return false
	end
	if data.Cash < amount then
		return false
	end
	data.Cash -= amount
	Registry.DataService:MarkDirty(player, "Cash")
	Log.Info("Economy", string.format("%s spent %s on %s", player.Name, Format.Cash(amount), reason), player.UserId)
	return true
end

function EconomyService:CanAfford(player: Player, amount: number): boolean
	local data = Registry.DataService:Get(player)
	return data ~= nil and data.Cash >= amount
end

local function addCurrency(player: Player, key: string, amount: number): boolean
	local data = Registry.DataService:Get(player)
	if not data or not validAmount(amount) then
		return false
	end
	data[key] += math.floor(amount)
	Registry.DataService:MarkDirty(player, key)
	return true
end

local function spendCurrency(player: Player, key: string, amount: number): boolean
	local data = Registry.DataService:Get(player)
	if not data or not TableUtil.IsFiniteNumber(amount) or amount < 0 or data[key] < amount then
		return false
	end
	data[key] -= amount
	Registry.DataService:MarkDirty(player, key)
	return true
end

function EconomyService:AddTokens(player: Player, amount: number): boolean
	return addCurrency(player, "Tokens", amount)
end

function EconomyService:SpendTokens(player: Player, amount: number): boolean
	return spendCurrency(player, "Tokens", amount)
end

function EconomyService:AddEventTokens(player: Player, amount: number): boolean
	return addCurrency(player, "EventTokens", amount)
end

function EconomyService:SpendEventTokens(player: Player, amount: number): boolean
	return spendCurrency(player, "EventTokens", amount)
end

---------------------------------------------------------------- multipliers
function EconomyService:HasPass(player: Player, key: string): boolean
	return Registry.MonetizationService:OwnsPass(player, key)
end

function EconomyService:IncomeMultiplier(player: Player): number
	local data = Registry.DataService:Get(player)
	if not data then
		return 1
	end
	local boost = if Registry.BoostService:IsActive(player, "Income") then BoostConfig.Personal.Income.Multiplier else 1
	local pass = if self:HasPass(player, "VIP") then MonetizationConfig.Gamepasses.VIP.Perks.IncomeMultiplier else 1
	local mods = Registry.EventService:GetModifiers()
	return Economy.Multiplier({
		Rebirths = data.Rebirths,
		BoostMultiplier = boost,
		PassMultiplier = pass,
		EventMultiplier = mods.IncomeMultiplier or 1,
		ServerMultiplier = Registry.BoostService:AdminMultiplier("Income"),
	})
end

function EconomyService:ComputeCashPerSec(player: Player): number
	local items = Registry.CollectibleService:PlacedItems(player)
	local base = 0
	for _, item in items do
		base += Economy.ItemIncome(item)
	end
	return base * self:IncomeMultiplier(player)
end

function EconomyService:GetCashPerSec(player: Player): number
	return Registry.DataService:GetSession(player, "CashPerSec") or 0
end

-- Personal luck: rebirth bonus + Lucky traits + VIP, x boost, x event luck.
function EconomyService:PersonalLuck(player: Player): number
	local data = Registry.DataService:Get(player)
	if not data then
		return 1
	end
	local traitBonus = 0
	for _, item in Registry.CollectibleService:PlacedItems(player) do
		local trait = TraitConfig.Get(item.Trait)
		if trait and trait.LuckBonus then
			traitBonus += trait.LuckBonus
		end
	end
	traitBonus = math.min(traitBonus, TraitConfig.MaxLuckBonus)
	local luck = 1 + Economy.RebirthLuckBonus(data.Rebirths) + traitBonus
	if Registry.BoostService:IsActive(player, "Luck") then
		luck *= BoostConfig.Personal.Luck.Multiplier
	end
	local mods = Registry.EventService:GetModifiers()
	luck *= mods.LuckMultiplier or 1
	return luck
end

-- Recomputes and replicates derived values right away (used after changes).
function EconomyService:Refresh(player: Player)
	local data = Registry.DataService:Get(player)
	if not data then
		return
	end
	local cps = self:ComputeCashPerSec(player)
	Registry.DataService:SetSession(player, "CashPerSec", cps)
	Registry.DataService:SetSession(player, "PersonalLuck", self:PersonalLuck(player))
	Registry.DataService:SetSession(player, "IncomeMultiplier", self:IncomeMultiplier(player))
	player:SetAttribute("CashPerSec", cps)
	if cps > data.Stats.BestCashPerSec then
		data.Stats.BestCashPerSec = cps
		Registry.DataService:MarkDirty(player, "Stats")
	end
	return cps
end

---------------------------------------------------------------- tick
function EconomyService:_tick(player: Player)
	local data = Registry.DataService:Get(player)
	if not data then
		return
	end
	local cps = self:Refresh(player) or 0
	local dt = GameConfig.Income.TickInterval
	local earned = cps * dt
	if earned > 0 then
		if data.Upgrades.AutoCollect >= 1 then
			self:AddCash(player, earned, "Income")
		else
			data.Uncollected += earned
			Registry.DataService:MarkDirty(player, "Uncollected")
		end
	end
	Registry.BaseService:SetUncollectedDisplay(player, data.Uncollected)

	-- Jackpot trait: occasional burst payouts
	local multiplier = nil
	for _, item in Registry.CollectibleService:PlacedItems(player) do
		local trait = TraitConfig.Get(item.Trait)
		if trait and trait.JackpotChancePerSecond and rng:NextNumber() < trait.JackpotChancePerSecond * dt then
			multiplier = multiplier or self:IncomeMultiplier(player)
			local payout = Economy.ItemIncome(item) * multiplier * trait.JackpotSeconds
			if self:AddCash(player, payout, "Jackpot") then
				Registry.NetService:Effect(player, "Jackpot", { Uid = item.Uid, Amount = payout })
				Registry.NetService:Notify(player, "🎰 JACKPOT! +" .. Format.Cash(payout), "Reward")
			end
		end
	end
end

-- Collect the pad. Validated: owner must be standing near their own pad.
function EconomyService:Collect(player: Player, skipDistanceCheck: boolean?): (boolean, string?, any?)
	local data = Registry.DataService:Get(player)
	if not data then
		return false, "Not loaded"
	end
	if not skipDistanceCheck then
		local plot = Registry.BaseService:GetPlot(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not plot or not root then
			return false, "Go to your base to collect"
		end
		local padWorld = (plot.Refs.Origin * CFrame.new(MapConfig.Plot.CollectPad)).Position
		local offset = root.Position - padWorld
		if Vector3.new(offset.X, 0, offset.Z).Magnitude > 7 or math.abs(offset.Y) > 8 then
			return false, "Stand on your collector pad"
		end
	end
	local amount = data.Uncollected
	if amount < 1 then
		return false, nil
	end
	data.Uncollected = 0
	Registry.DataService:MarkDirty(player, "Uncollected")
	self:AddCash(player, amount, "Income")
	data.Stats.Collected += 1
	Registry.DataService:MarkDirty(player, "Stats")
	Registry.BaseService:SetUncollectedDisplay(player, 0)
	ActionBus.Fire(player, "Collect", 1, { Amount = amount })
	Registry.NetService:Effect(player, "CashCollected", { Amount = amount })
	return true, nil, { Amount = amount }
end

---------------------------------------------------------------- lifecycle
function EconomyService:OnPlayerLoaded(player: Player)
	local data = Registry.DataService:Get(player)
	if not data then
		return
	end
	self:Refresh(player)
	local offline = GameConfig.Income.OfflineEarnings
	if offline.Enabled and data.LastOnline > 0 then
		local away = os.time() - data.LastOnline
		if away >= offline.MinSecondsAway then
			local seconds = math.min(away, offline.MaxSeconds)
			local amount = math.floor(data.LastCashPerSec * seconds * offline.Rate)
			if amount > 0 then
				self:AddCash(player, amount, "Offline")
				task.delay(4, function()
					Registry.NetService:Fire(player, "Popup", "Welcome back!", {
						string.format("You were away for %s.", Format.Time(away)),
						string.format("Your critters earned %s while you were gone!", Format.Cash(amount)),
						string.format("(%d%% offline rate, up to %s)", offline.Rate * 100, Format.Time(offline.MaxSeconds)),
					}, "💤")
				end)
			end
		end
	end
end

function EconomyService:OnPlayerRemoving(player: Player)
	local data = Registry.DataService:Get(player)
	if data then
		data.LastCashPerSec = self:GetCashPerSec(player)
		data.LastOnline = os.time()
	end
end

return EconomyService
