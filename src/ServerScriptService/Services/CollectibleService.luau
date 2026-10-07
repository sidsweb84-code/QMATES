--[[
	CollectibleService
	Every change to a player's collectibles goes through here:
	granting (with reveal + announcements), removal, transfers between players
	(steals / trades), selling, levelling, favourite-locking, base <-> storage
	moves, collection-book records and global serial numbers.

	Item invariants (also enforced by DataSchema on load):
	- Uid is unique (GUID) and equals its Inventory key.
	- Slot > 0 means placed in the base (earns income, can be stolen);
	  Slot = 0 means storage. No two items share a slot.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local RarityConfig = require(Config.RarityConfig)
local MutationConfig = require(Config.MutationConfig)
local TraitConfig = require(Config.TraitConfig)
local MonetizationConfig = require(Config.MonetizationConfig)
local Catalog = require(Shared.Catalog)
local Economy = require(Shared.Economy)
local Format = require(Shared.Util.Format)

local Modules = script.Parent.Parent.Modules
local Registry = require(Modules.Registry)
local ActionBus = require(Modules.ActionBus)
local Log = require(Modules.Log)

local CollectibleService = {}

local serialStore = nil
local localSerials: { [string]: number } = {}

function CollectibleService:Init()
	if #Catalog.Errors > 0 then
		for _, err in Catalog.Errors do
			Log.Error("Catalog", err)
		end
	end
	if not RunService:IsStudio() then
		local ok, store = pcall(function()
			return DataStoreService:GetDataStore("StealCritters_Serials_v1")
		end)
		if ok then
			serialStore = store
		end
	end
end

function CollectibleService:Start() end

---------------------------------------------------------------- capacity
function CollectibleService:Capacity(player: Player): number
	local data = Registry.DataService:Get(player)
	if not data then
		return 0
	end
	local extra = if Registry.MonetizationService:OwnsPass(player, "ExtraSlots")
		then MonetizationConfig.Gamepasses.ExtraSlots.Perks.ExtraSlots
		else 0
	return Economy.BaseSlots(data.BaseLevel, extra)
end

function CollectibleService:StorageCapacity(player: Player): number
	local extra = if Registry.MonetizationService:OwnsPass(player, "CollectorVault")
		then MonetizationConfig.Gamepasses.CollectorVault.Perks.ExtraStorage
		else 0
	return Economy.StorageCapacity(extra)
end

function CollectibleService:Counts(player: Player): (number, number)
	local data = Registry.DataService:Get(player)
	local placed, stored = 0, 0
	if data then
		for _, item in data.Inventory do
			if item.Slot > 0 then
				placed += 1
			else
				stored += 1
			end
		end
	end
	return placed, stored
end

function CollectibleService:FindFreeSlot(player: Player): number?
	local data = Registry.DataService:Get(player)
	if not data then
		return nil
	end
	local used = {}
	for _, item in data.Inventory do
		if item.Slot > 0 then
			used[item.Slot] = true
		end
	end
	for slot = 1, self:Capacity(player) do
		if not used[slot] then
			return slot
		end
	end
	return nil
end

function CollectibleService:HasSpace(player: Player): boolean
	if self:FindFreeSlot(player) then
		return true
	end
	local _, stored = self:Counts(player)
	return stored < self:StorageCapacity(player)
end

function CollectibleService:PlacedItems(player: Player): { any }
	local data = Registry.DataService:Get(player)
	local list = {}
	if data then
		for _, item in data.Inventory do
			if item.Slot > 0 then
				table.insert(list, item)
			end
		end
	end
	return list
end

function CollectibleService:GetItem(player: Player, uid: any)
	if type(uid) ~= "string" then
		return nil
	end
	local data = Registry.DataService:Get(player)
	return data and data.Inventory[uid] or nil
end

-- Items that are moving, being stolen or offered in a trade can't be changed.
function CollectibleService:IsBusy(player: Player, uid: string): (boolean, string?)
	if Registry.StealService:IsItemBeingStolen(player, uid) then
		return true, "This critter is being stolen!"
	end
	if Registry.BaseService:IsInTransit(player, uid) then
		return true, "Wait for it to arrive at your base"
	end
	if Registry.TradeService:IsItemInTrade(player, uid) then
		return true, "This critter is in a trade"
	end
	return false, nil
end

-- After load / capacity changes: items in slots beyond capacity go to storage.
function CollectibleService:NormalizeSlots(player: Player)
	local data = Registry.DataService:Get(player)
	if not data then
		return
	end
	local capacity = self:Capacity(player)
	local changed = false
	for _, item in data.Inventory do
		if item.Slot > capacity then
			item.Slot = 0
			changed = true
		end
	end
	if changed then
		Registry.DataService:MarkDirty(player, "Inventory")
	end
end

---------------------------------------------------------------- collection book
function CollectibleService:RecordCollection(player: Player, item): boolean
	local data = Registry.DataService:Get(player)
	if not data then
		return false
	end
	local entry = data.Collection[item.Id]
	local isNew = entry == nil
	if not entry then
		entry = { Count = 0, Best = "Normal", Mutations = {}, First = os.time() }
		data.Collection[item.Id] = entry
	end
	entry.Count += 1
	entry.Mutations[item.Mutation] = true
	local best = MutationConfig.Mutations[entry.Best]
	local current = MutationConfig.Mutations[item.Mutation]
	if current and best and current.Tier > best.Tier then
		entry.Best = item.Mutation
	end
	Registry.DataService:MarkDirty(player, "Collection")
	player:SetAttribute("CollectionCount", self:CollectionCount(player))
	return isNew
end

function CollectibleService:CollectionCount(player: Player): number
	local data = Registry.DataService:Get(player)
	if not data then
		return 0
	end
	local n = 0
	for id in data.Collection do
		local def = Catalog.Get(id)
		if def and not def.Limited then
			n += 1
		end
	end
	return n
end

---------------------------------------------------------------- serials
function CollectibleService:_assignSerial(player: Player, item)
	task.spawn(function()
		local serial: number? = nil
		if serialStore then
			local budget = 0
			pcall(function()
				budget = DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.SetIncrementAsync)
			end)
			if budget > 20 then
				local ok, result = pcall(function()
					return serialStore:IncrementAsync(item.Id, 1)
				end)
				if ok and type(result) == "number" then
					serial = result
				end
			end
		end
		if not serial then
			localSerials[item.Id] = (localSerials[item.Id] or 0) + 1
			serial = localSerials[item.Id]
		end
		-- The item may have changed hands meanwhile; update wherever it is.
		item.Serial = serial
		local data = Registry.DataService:Get(player)
		if data and data.Inventory[item.Uid] == item then
			Registry.DataService:MarkDirty(player, "Inventory")
			Registry.BaseService:RefreshItemModel(player, item)
		end
	end)
end

---------------------------------------------------------------- grant / remove
export type GrantOptions = {
	Mutation: string?,
	Trait: string?,
	Level: number?,
	Source: string?,
	TravelFrom: Vector3?,
	Silent: boolean?,
	BonusMutation: boolean?,
	Serial: number?,
	FirstOwner: number?,
}

-- Creates a brand-new collectible for a player. Returns (item?, error?)
function CollectibleService:Grant(player: Player, id: string, options: GrantOptions?)
	local opts: GrantOptions = options or {}
	local data = Registry.DataService:Get(player)
	local def = Catalog.Get(id)
	if not data then
		return nil, "Not loaded"
	end
	if not def then
		Registry.AntiExploitService:Flag(player, "InvalidCollectible", tostring(id))
		return nil, "Unknown collectible"
	end
	local slot = self:FindFreeSlot(player)
	if not slot then
		local _, stored = self:Counts(player)
		if stored >= self:StorageCapacity(player) then
			return nil, "Your base and storage are full! Sell or upgrade."
		end
		slot = 0
	end
	local mutation = if MutationConfig.IsValid(opts.Mutation) then opts.Mutation :: string else "Normal"
	local trait = if opts.Trait and TraitConfig.Traits[opts.Trait] then opts.Trait else nil
	local item = {
		Uid = HttpService:GenerateGUID(false),
		Id = id,
		Mutation = mutation,
		Trait = trait,
		Level = math.clamp(math.floor(opts.Level or 1), 1, 10),
		Serial = opts.Serial or 0,
		Slot = slot,
		Locked = false,
		Acquired = os.time(),
		Source = opts.Source or "Unknown",
		FirstOwner = opts.FirstOwner or player.UserId,
	}
	data.Inventory[item.Uid] = item
	Registry.DataService:MarkDirty(player, "Inventory")
	local isNew = self:RecordCollection(player, item)
	if item.Serial == 0 then
		self:_assignSerial(player, item)
	end
	if slot > 0 then
		Registry.BaseService:SpawnItemModel(player, item, opts.TravelFrom)
	end
	Registry.BaseService:RefreshSlots(player)

	local rarity = RarityConfig.Rarities[def.Rarity]
	if rarity.Tier >= RarityConfig.Tier("Legendary") then
		data.Stats.RareFinds += 1
	end
	if mutation ~= "Normal" then
		data.Stats.MutationFinds += 1
	end
	Registry.DataService:MarkDirty(player, "Stats")

	if not opts.Silent then
		Registry.NetService:Fire(player, "Reveal", {
			Item = item,
			IsNew = isNew,
			Source = item.Source,
			Income = Economy.ItemIncome(item),
			Stored = slot == 0,
			BonusMutation = opts.BonusMutation == true,
		})
		Registry.NetService:AnnounceAcquisition(player, item, if item.Source == "Steal" then "stole" else "found")
	end
	ActionBus.Fire(player, "Acquire", 1, { Rarity = def.Rarity, Mutation = mutation, Id = id, Source = item.Source })
	Registry.EconomyService:Refresh(player)
	Log.Info("Collectible", string.format("%s got %s %s (%s) via %s", player.Name, mutation, def.Name, item.Uid, item.Source), player.UserId)
	return item, nil
end

-- Removes an item from a player's data and world. Returns the removed item.
function CollectibleService:Remove(player: Player, uid: string)
	local data = Registry.DataService:Get(player)
	local item = data and data.Inventory[uid]
	if not item then
		return nil
	end
	data.Inventory[uid] = nil
	Registry.DataService:MarkDirty(player, "Inventory")
	Registry.BaseService:DespawnItemModel(player, uid)
	Registry.BaseService:RefreshSlots(player)
	Registry.EconomyService:Refresh(player)
	return item
end

--[[
	Atomically moves an existing item from one player to another (steal, trade,
	gift). The SAME item record (Uid, serial, mutation, level) moves; nothing is
	created, so duplication is impossible. Both profiles are saved right away.
]]
function CollectibleService:Transfer(from: Player, to: Player, uid: string, source: string, options: { Silent: boolean?, TravelFrom: Vector3? }?)
	local opts = options or {}
	local fromData = Registry.DataService:Get(from)
	local toData = Registry.DataService:Get(to)
	if not fromData or not toData then
		return nil, "Player data unavailable"
	end
	local item = fromData.Inventory[uid]
	if not item then
		return nil, "Item no longer exists"
	end
	if toData.Inventory[uid] then
		Log.Security(string.format("Transfer would duplicate %s (%s -> %s)", uid, from.Name, to.Name))
		return nil, "Duplicate item"
	end
	local slot = self:FindFreeSlot(to)
	if not slot then
		local _, stored = self:Counts(to)
		if stored >= self:StorageCapacity(to) then
			return nil, to.DisplayName .. " has no space"
		end
		slot = 0
	end
	-- Remove from source
	fromData.Inventory[uid] = nil
	Registry.DataService:MarkDirty(from, "Inventory")
	Registry.BaseService:DespawnItemModel(from, uid)
	Registry.BaseService:RefreshSlots(from)
	Registry.EconomyService:Refresh(from)
	-- Add to target
	item.Slot = slot
	item.Locked = false
	item.Source = source
	item.Acquired = os.time()
	toData.Inventory[uid] = item
	Registry.DataService:MarkDirty(to, "Inventory")
	local isNew = self:RecordCollection(to, item)
	if slot > 0 then
		Registry.BaseService:SpawnItemModel(to, item, opts.TravelFrom)
	end
	Registry.BaseService:RefreshSlots(to)
	Registry.EconomyService:Refresh(to)

	local def = Catalog.Get(item.Id)
	if not opts.Silent then
		Registry.NetService:Fire(to, "Reveal", {
			Item = item,
			IsNew = isNew,
			Source = source,
			Income = Economy.ItemIncome(item),
			Stored = slot == 0,
		})
	end
	ActionBus.Fire(to, "Acquire", 1, { Rarity = def and def.Rarity or "Common", Mutation = item.Mutation, Id = item.Id, Source = source })
	Log.Info("Transfer", string.format("%s -> %s : %s (%s) via %s", from.Name, to.Name, item.Id, uid, source))
	-- Persist both sides immediately to minimise any window for loss/dupes.
	task.spawn(function()
		Registry.DataService:SaveAsync(from, false)
	end)
	task.spawn(function()
		Registry.DataService:SaveAsync(to, false)
	end)
	return item, nil
end

-- Atomic multi-item exchange used by trading. Validates everything first,
-- then detaches all outgoing items from both sides before attaching, so
-- full bases can still swap 1-for-1.
function CollectibleService:Swap(a: Player, aUids: { string }, b: Player, bUids: { string }): (boolean, string?)
	local aData = Registry.DataService:Get(a)
	local bData = Registry.DataService:Get(b)
	if not aData or not bData then
		return false, "Player data unavailable"
	end
	local function validate(player: Player, data, uids: { string }): (boolean, string?)
		for _, uid in uids do
			local item = data.Inventory[uid]
			if not item or item.Locked then
				return false, "An offered critter is no longer available"
			end
			if Registry.StealService:IsItemBeingStolen(player, uid) or Registry.BaseService:IsInTransit(player, uid) then
				return false, "An offered critter is busy"
			end
		end
		return true, nil
	end
	local okA, errA = validate(a, aData, aUids)
	if not okA then
		return false, errA
	end
	local okB, errB = validate(b, bData, bUids)
	if not okB then
		return false, errB
	end
	local function freeAfter(player: Player, outgoing: number): number
		local placed, stored = self:Counts(player)
		return self:Capacity(player) + self:StorageCapacity(player) - (placed + stored - outgoing)
	end
	if freeAfter(a, #aUids) < #bUids then
		return false, a.DisplayName .. " doesn't have enough space"
	end
	if freeAfter(b, #bUids) < #aUids then
		return false, b.DisplayName .. " doesn't have enough space"
	end

	local function detach(player: Player, data, uids: { string }): { any }
		local list = {}
		for _, uid in uids do
			local item = data.Inventory[uid]
			data.Inventory[uid] = nil
			Registry.BaseService:DespawnItemModel(player, uid)
			table.insert(list, item)
		end
		return list
	end
	local function attach(player: Player, data, items: { any })
		for _, item in items do
			item.Slot = self:FindFreeSlot(player) or 0
			item.Locked = false
			item.Source = "Trade"
			item.Acquired = os.time()
			data.Inventory[item.Uid] = item
			self:RecordCollection(player, item)
			if item.Slot > 0 then
				Registry.BaseService:SpawnItemModel(player, item, nil)
			end
		end
	end
	local fromA = detach(a, aData, aUids)
	local fromB = detach(b, bData, bUids)
	attach(b, bData, fromA)
	attach(a, aData, fromB)
	for _, player in { a, b } do
		Registry.DataService:MarkDirty(player, "Inventory")
		Registry.BaseService:RefreshSlots(player)
		Registry.EconomyService:Refresh(player)
		task.spawn(function()
			Registry.DataService:SaveAsync(player, false)
		end)
	end
	return true, nil
end

---------------------------------------------------------------- player actions
function CollectibleService:Sell(player: Player, uid: any): (boolean, string?)
	local item = self:GetItem(player, uid)
	if not item then
		return false, "Critter not found"
	end
	if item.Locked then
		return false, "Unlock (unfavourite) it before selling"
	end
	local busy, why = self:IsBusy(player, item.Uid)
	if busy then
		return false, why
	end
	local value = Economy.SellValue(item)
	self:Remove(player, item.Uid)
	Registry.EconomyService:AddCash(player, value, "Sell")
	local data = Registry.DataService:Get(player)
	if data then
		data.Stats.Sold += 1
		Registry.DataService:MarkDirty(player, "Stats")
	end
	ActionBus.Fire(player, "Sell", 1, { Id = item.Id })
	local def = Catalog.Get(item.Id)
	return true, string.format("Sold %s for %s", def and def.Name or "critter", Format.Cash(value))
end

function CollectibleService:LevelUp(player: Player, uid: any): (boolean, string?)
	local item = self:GetItem(player, uid)
	if not item then
		return false, "Critter not found"
	end
	local busy, why = self:IsBusy(player, item.Uid)
	if busy then
		return false, why
	end
	local cost = Economy.LevelUpCost(item)
	if not cost then
		return false, "Already max level"
	end
	if not Registry.EconomyService:SpendCash(player, cost, "LevelUp") then
		return false, "Need " .. Format.Cash(cost)
	end
	item.Level += 1
	local data = Registry.DataService:Get(player)
	if data then
		data.Stats.LevelUps += 1
		Registry.DataService:MarkDirty(player, "Stats")
	end
	Registry.DataService:MarkDirty(player, "Inventory")
	Registry.BaseService:RefreshItemModel(player, item)
	Registry.EconomyService:Refresh(player)
	ActionBus.Fire(player, "LevelUp", 1, { Id = item.Id, Level = item.Level })
	Registry.NetService:Effect(player, "LevelUp", { Uid = item.Uid, Level = item.Level })
	return true, "Level " .. item.Level .. "!"
end

function CollectibleService:ToggleLock(player: Player, uid: any): (boolean, string?)
	local item = self:GetItem(player, uid)
	if not item then
		return false, "Critter not found"
	end
	item.Locked = not item.Locked
	Registry.DataService:MarkDirty(player, "Inventory")
	return true, if item.Locked then "Favourited — it can't be sold or traded" else "Unfavourited"
end

function CollectibleService:Move(player: Player, uid: any, target: any): (boolean, string?)
	local item = self:GetItem(player, uid)
	if not item then
		return false, "Critter not found"
	end
	local busy, why = self:IsBusy(player, item.Uid)
	if busy then
		return false, why
	end
	if target == "Storage" then
		if item.Slot == 0 then
			return false, "Already in storage"
		end
		local _, stored = self:Counts(player)
		if stored >= self:StorageCapacity(player) then
			return false, "Storage is full"
		end
		Registry.BaseService:DespawnItemModel(player, item.Uid)
		item.Slot = 0
	elseif target == "Base" then
		if item.Slot > 0 then
			return false, "Already in your base"
		end
		local slot = self:FindFreeSlot(player)
		if not slot then
			return false, "No free base slots — upgrade your base!"
		end
		item.Slot = slot
		Registry.BaseService:SpawnItemModel(player, item, nil)
	else
		Registry.AntiExploitService:Flag(player, "InvalidArgs", "Move target " .. tostring(target))
		return false, "Invalid target"
	end
	Registry.DataService:MarkDirty(player, "Inventory")
	Registry.BaseService:RefreshSlots(player)
	Registry.EconomyService:Refresh(player)
	return true, if target == "Base" then "Placed in your base" else "Moved to storage"
end

function CollectibleService:OnPlayerLoaded(player: Player)
	self:NormalizeSlots(player)
	player:SetAttribute("CollectionCount", self:CollectionCount(player))
end

return CollectibleService
