--[[
	DataSchema
	Player save format: defaults, versioned migrations and strict validation.
	Pure module (no Roblox services) so it is unit-tested offline.

	Rules for saved data:
	- Dictionaries ALWAYS use string keys (DataStores and remotes require it).
	- Numbers must be finite. Validation repairs anything malformed and reports it.
	- Bump Version and add a migration whenever the format changes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local GameConfig = require(Config.GameConfig)
local MutationConfig = require(Config.MutationConfig)
local TraitConfig = require(Config.TraitConfig)
local UpgradeConfig = require(Config.UpgradeConfig)
local BoostConfig = require(Config.BoostConfig)
local CosmeticConfig = require(Config.CosmeticConfig)
local MonetizationConfig = require(Config.MonetizationConfig)
local Catalog = require(Shared.Catalog)
local TableUtil = require(Shared.Util.TableUtil)

local DataSchema = {}

DataSchema.Version = 2

DataSchema.SettingsSpec = {
	Music = { Type = "boolean", Default = true },
	SFX = { Type = "boolean", Default = true },
	Graphics = { Type = "string", Default = "High", Options = { Low = true, Medium = true, High = true } },
	ReduceMotion = { Type = "boolean", Default = false },
	CardLabels = { Type = "boolean", Default = true },
	UIScale = { Type = "string", Default = "Normal", Options = { Small = true, Normal = true, Large = true } },
	ShowTutorial = { Type = "boolean", Default = true },
}

DataSchema.StatKeys = {
	"Purchases", "Steals", "StealsFailed", "TimesRobbed", "Catches", "Playtime", "PacksOpened",
	"Sold", "LevelUps", "RareFinds", "MutationFinds", "BestCashPerSec", "Logins", "Collected", "Rebirths",
}

function DataSchema.Template()
	local settings = {}
	for key, spec in DataSchema.SettingsSpec do
		settings[key] = spec.Default
	end
	local stats = {}
	for _, key in DataSchema.StatKeys do
		stats[key] = 0
	end
	local upgrades = {}
	for _, track in UpgradeConfig.TrackOrder do
		upgrades[track] = 0
	end
	return {
		Version = DataSchema.Version,
		Cash = GameConfig.StartingCash,
		Tokens = GameConfig.StartingTokens,
		EventTokens = 0,
		TotalEarned = 0,
		Uncollected = 0,
		Rebirths = 0,
		BaseLevel = 1,
		Upgrades = upgrades,
		Inventory = {}, -- [uid] = item
		Orphaned = {}, -- items whose collectible no longer exists in config (kept, not deleted)
		Collection = {}, -- [collectibleId] = { Count, Best, Mutations = {[m]=true}, First }
		CollectionClaimed = {}, -- ["25"] = true
		Quests = { Day = 0, Daily = {}, Rerolls = 0, Lifetime = {} },
		Daily = { LastDay = 0, Streak = 0 },
		Playtime = { Day = 0, Today = 0, Claimed = {} },
		Boosts = {}, -- [boostName] = expiry (unix)
		Cosmetics = { Owned = {}, Equipped = table.clone(CosmeticConfig.Defaults) },
		Stats = stats,
		Settings = settings,
		Tutorial = { Step = 1, Done = false },
		Gamepasses = {}, -- [passKey] = true (verified server-side)
		Receipts = {}, -- [purchaseId] = unix time (ProcessReceipt de-duplication)
		Flags = {},
		FirstJoin = 0,
		LastOnline = 0,
		LastCashPerSec = 0,
		LastSave = 0,
	}
end

-- Migrations: Migrations[n] upgrades data from version n to n + 1.
DataSchema.Migrations = {
	[1] = function(data)
		-- v1 -> v2: event tokens and UI scale settings were introduced.
		data.EventTokens = data.EventTokens or 0
		if type(data.Settings) == "table" and data.Settings.UIScale == nil then
			data.Settings.UIScale = "Normal"
		end
		return data
	end,
}

function DataSchema.Migrate(data): ({ [string]: any }, { number })
	local applied = {}
	local version = tonumber(data.Version) or 1
	while version < DataSchema.Version do
		local migration = DataSchema.Migrations[version]
		if migration then
			data = migration(data)
			table.insert(applied, version)
		end
		version += 1
	end
	data.Version = DataSchema.Version
	return data, applied
end

---------------------------------------------------------------- validation helpers
local function finite(n: any, default: number, min: number?, max: number?): number
	if not TableUtil.IsFiniteNumber(n) then
		return default
	end
	if min and n < min then
		return min
	end
	if max and n > max then
		return max
	end
	return n
end

local function int(n: any, default: number, min: number?, max: number?): number
	return math.floor(finite(n, default, min, max))
end

local function dict(t: any): { [any]: any }
	return if type(t) == "table" then t else {}
end

-- Returns (data, issues). Never errors on malformed input.
function DataSchema.Validate(raw: any): ({ [string]: any }, { string })
	local issues = {}
	local function issue(msg: string)
		table.insert(issues, msg)
	end
	local template = DataSchema.Template()
	local data = if type(raw) == "table" then raw else template
	if type(raw) ~= "table" then
		issue("data was not a table")
	end

	TableUtil.Reconcile(data, template)

	-- Currencies / counters
	for _, key in { "Cash", "Tokens", "EventTokens", "TotalEarned", "Uncollected", "LastCashPerSec" } do
		local before = data[key]
		data[key] = finite(before, template[key], 0)
		if data[key] ~= before then
			issue(key .. " repaired")
		end
	end
	data.Rebirths = int(data.Rebirths, 0, 0, 100000)
	data.BaseLevel = int(data.BaseLevel, 1, 1, #UpgradeConfig.BaseLevels)
	for _, key in { "FirstJoin", "LastOnline", "LastSave" } do
		data[key] = finite(data[key], 0, 0)
	end

	-- Upgrades
	local upgrades = dict(data.Upgrades)
	for _, track in UpgradeConfig.TrackOrder do
		local maxLevel = #UpgradeConfig.Tracks[track].Levels - 1
		upgrades[track] = int(upgrades[track], 0, 0, maxLevel)
	end
	for key in upgrades do
		if not UpgradeConfig.Tracks[key] then
			upgrades[key] = nil
		end
	end
	data.Upgrades = upgrades

	-- Inventory
	local inventory = {}
	local usedSlots = {}
	data.Orphaned = dict(data.Orphaned)
	for key, item in dict(data.Inventory) do
		if type(item) ~= "table" then
			issue("non-table inventory entry removed")
			continue
		end
		local uid = if type(item.Uid) == "string" and item.Uid ~= "" then item.Uid else key
		if type(uid) ~= "string" or uid == "" then
			issue("inventory entry without uid removed")
			continue
		end
		if inventory[uid] then
			issue("duplicate item " .. uid .. " removed")
			continue
		end
		if not Catalog.IsValid(item.Id) then
			issue("unknown collectible " .. tostring(item.Id) .. " moved to Orphaned")
			data.Orphaned[uid] = item
			continue
		end
		item.Uid = uid
		if not MutationConfig.IsValid(item.Mutation) then
			item.Mutation = "Normal"
		end
		if item.Trait == "" or not TraitConfig.IsValid(item.Trait) then
			item.Trait = nil
		end
		item.Level = int(item.Level, 1, 1, UpgradeConfig.CardLevels.MaxLevel)
		item.Serial = int(item.Serial, 0, 0)
		item.Slot = int(item.Slot, 0, 0, UpgradeConfig.PhysicalSlots)
		if item.Slot > 0 then
			if usedSlots[item.Slot] then
				issue("slot collision for " .. uid)
				item.Slot = 0
			else
				usedSlots[item.Slot] = true
			end
		end
		item.Locked = item.Locked == true
		item.Acquired = finite(item.Acquired, 0, 0)
		item.Source = if type(item.Source) == "string" then item.Source else "Unknown"
		item.FirstOwner = if type(item.FirstOwner) == "number" then item.FirstOwner else nil
		inventory[uid] = item
	end
	data.Inventory = inventory

	-- Collection
	local collection = {}
	for id, entry in dict(data.Collection) do
		if not Catalog.IsValid(id) or type(entry) ~= "table" then
			continue
		end
		local mutations = {}
		for m, v in dict(entry.Mutations) do
			if MutationConfig.IsValid(m) and v == true then
				mutations[m] = true
			end
		end
		collection[id] = {
			Count = int(entry.Count, 1, 0),
			Best = if MutationConfig.IsValid(entry.Best) then entry.Best else "Normal",
			Mutations = mutations,
			First = finite(entry.First, 0, 0),
		}
	end
	data.Collection = collection

	local claimed = {}
	for k, v in dict(data.CollectionClaimed) do
		if type(k) == "string" and v == true then
			claimed[k] = true
		end
	end
	data.CollectionClaimed = claimed

	-- Quests
	local quests = dict(data.Quests)
	quests.Day = int(quests.Day, 0, 0)
	quests.Rerolls = int(quests.Rerolls, 0, 0)
	local daily = {}
	for _, q in (if type(quests.Daily) == "table" then quests.Daily else {}) do
		if type(q) == "table" and type(q.Id) == "string" then
			table.insert(daily, {
				Id = q.Id,
				Progress = finite(q.Progress, 0, 0),
				Target = finite(q.Target, 1, 1),
				Claimed = q.Claimed == true,
			})
		end
	end
	quests.Daily = daily
	local lifetime = {}
	for id, entry in dict(quests.Lifetime) do
		if type(id) == "string" and type(entry) == "table" then
			lifetime[id] = { Progress = finite(entry.Progress, 0, 0), Claimed = int(entry.Claimed, 0, 0) }
		end
	end
	quests.Lifetime = lifetime
	data.Quests = quests

	-- Daily login / playtime
	local dailyLogin = dict(data.Daily)
	data.Daily = { LastDay = int(dailyLogin.LastDay, 0, 0), Streak = int(dailyLogin.Streak, 0, 0) }
	local playtime = dict(data.Playtime)
	local playClaimed = {}
	for k, v in dict(playtime.Claimed) do
		if type(k) == "string" and v == true then
			playClaimed[k] = true
		end
	end
	data.Playtime = { Day = int(playtime.Day, 0, 0), Today = finite(playtime.Today, 0, 0), Claimed = playClaimed }

	-- Boosts
	local boosts = {}
	for name, expiry in dict(data.Boosts) do
		if BoostConfig.Personal[name] and TableUtil.IsFiniteNumber(expiry) then
			boosts[name] = expiry
		end
	end
	data.Boosts = boosts

	-- Cosmetics
	local cosmetics = dict(data.Cosmetics)
	local owned = {}
	for id, v in dict(cosmetics.Owned) do
		if CosmeticConfig.Items[id] and v == true then
			owned[id] = true
		end
	end
	local equipped = {}
	local rawEquipped = dict(cosmetics.Equipped)
	for typeName, default in CosmeticConfig.Defaults do
		local id = rawEquipped[typeName]
		local item = CosmeticConfig.Get(id)
		if item and item.Type == typeName then
			equipped[typeName] = id
		else
			equipped[typeName] = default
		end
	end
	data.Cosmetics = { Owned = owned, Equipped = equipped }

	-- Stats
	local stats = dict(data.Stats)
	for _, key in DataSchema.StatKeys do
		stats[key] = finite(stats[key], 0, 0)
	end
	data.Stats = stats

	-- Settings (whitelist)
	local settings = {}
	local rawSettings = dict(data.Settings)
	for key, spec in DataSchema.SettingsSpec do
		local v = rawSettings[key]
		if type(v) == spec.Type and (not spec.Options or spec.Options[v]) then
			settings[key] = v
		else
			settings[key] = spec.Default
		end
	end
	data.Settings = settings

	-- Tutorial
	local tutorial = dict(data.Tutorial)
	data.Tutorial = { Step = int(tutorial.Step, 1, 1, 99), Done = tutorial.Done == true }

	-- Gamepasses cache
	local passes = {}
	for key, v in dict(data.Gamepasses) do
		if MonetizationConfig.Gamepasses[key] and v == true then
			passes[key] = true
		end
	end
	data.Gamepasses = passes

	-- Receipts
	local receipts = {}
	for id, t in dict(data.Receipts) do
		if type(id) == "string" and TableUtil.IsFiniteNumber(t) then
			receipts[id] = t
		end
	end
	data.Receipts = receipts

	data.Flags = dict(data.Flags)
	data.SessionLock = nil
	data.Version = DataSchema.Version
	return data, issues
end

-- Full pipeline for data read from storage (nil = new player).
function DataSchema.Prepare(raw: any): ({ [string]: any }, { string }, boolean)
	local isNew = raw == nil
	local data = if type(raw) == "table" then TableUtil.DeepCopy(raw) else DataSchema.Template()
	data = DataSchema.Migrate(data)
	local validated, issues = DataSchema.Validate(data)
	return validated, issues, isNew
end

-- Keeps only the most recent receipts.
function DataSchema.TrimReceipts(data, maxCount: number)
	local list = {}
	for id, t in data.Receipts do
		table.insert(list, { Id = id, T = t })
	end
	if #list <= maxCount then
		return
	end
	table.sort(list, function(a, b)
		return a.T > b.T
	end)
	local keep = {}
	for i = 1, maxCount do
		keep[list[i].Id] = list[i].T
	end
	data.Receipts = keep
end

return DataSchema
