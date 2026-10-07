--[[
	DataService
	Authoritative player data: loading, saving, session locking, versioning,
	validation and replication to the owning client.

	- Session lock: the profile key stores { JobId, Time }. Another server that
	  holds a fresh lock makes us wait and retry; a stale lock (crashed server)
	  is taken over. If our lock is stolen, we stop saving and kick the player
	  so two servers can never overwrite each other.
	- Saves use UpdateAsync with retries + exponential backoff.
	- Autosave every GameConfig.Data.AutosaveInterval; BindToClose saves all.
	- Studio without API access falls back to an in-memory MockDataStore.
	- Replication: services call MarkDirty(player, key) / SetSession(player, key, v);
	  dirty keys are batched to the client ~5 times per second.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local TableUtil = require(Shared.Util.TableUtil)
local Signal = require(Shared.Util.Signal)

local Modules = script.Parent.Parent.Modules
local DataSchema = require(Modules.DataSchema)
local MockDataStore = require(Modules.MockDataStore)
local Log = require(Modules.Log)
local Registry = require(Modules.Registry)

local DataService = {}

export type Profile = {
	Player: Player,
	Key: string,
	Data: { [string]: any },
	Session: { [string]: any },
	DirtyData: { [string]: boolean },
	DirtySession: { [string]: boolean },
	Seq: number,
	LastSave: number,
	Saving: boolean,
	Released: boolean,
	Releasing: boolean,
	LockLost: boolean,
	IsNew: boolean,
	LoadedAt: number,
}

DataService.Profiles = {} :: { [Player]: Profile }
DataService.Store = nil :: any
DataService.UsingMock = false
DataService.ShuttingDown = false
DataService.ProfileLoaded = Signal.new()
-- Callbacks run once right before a profile is released (leave / shutdown).
DataService.BeforeRelease = {} :: { (Player) -> () }

-- Keys never sent to the client.
local PRIVATE_KEYS = { SessionLock = true, Receipts = true, Flags = true, Orphaned = true }

local syncRemote: RemoteEvent
local loading: { [Player]: boolean } = {}

local function keyFor(userId: number): string
	return GameConfig.Data.KeyPrefix .. tostring(userId)
end

local function createStore()
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(GameConfig.Data.StoreName)
	end)
	if ok and store then
		local probeOk, err = pcall(function()
			return store:GetAsync("__probe")
		end)
		if probeOk then
			return store, false
		end
		if RunService:IsStudio() and GameConfig.Data.UseMockWhenUnavailable then
			warn("[DataService] DataStores unavailable in Studio (" .. tostring(err) .. "). "
				.. "Using an in-memory store: progress will NOT be saved. Enable 'Studio Access to API Services' to test saving.")
			return MockDataStore.new("PlayerData"), true
		end
		Log.Error("Data", "DataStore probe failed: " .. tostring(err))
		return store, false
	end
	warn("[DataService] Could not open DataStore; using in-memory store. Progress will NOT be saved.")
	return MockDataStore.new("PlayerData"), true
end

-- Allows tests to inject a different backend.
function DataService:SetStore(store, isMock: boolean?)
	self.Store = store
	self.UsingMock = isMock == true
end

function DataService:Init()
	local store, isMock = createStore()
	self:SetStore(store, isMock)
	syncRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Sync") :: RemoteEvent
end

function DataService:Start()
	-- Replication flush (~5Hz)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.2 then
			return
		end
		accumulator = 0
		for player, profile in self.Profiles do
			self:_flush(player, profile)
		end
	end)

	-- Autosave
	task.spawn(function()
		while true do
			task.wait(5)
			if self.ShuttingDown then
				break
			end
			for player, profile in self.Profiles do
				if not profile.Saving and not profile.Released and os.clock() - profile.LastSave >= GameConfig.Data.AutosaveInterval then
					task.spawn(function()
						self:SaveAsync(player, false)
					end)
					task.wait(0.25) -- spread load across the interval
				end
			end
		end
	end)

	game:BindToClose(function()
		self:_shutdown()
	end)
end

---------------------------------------------------------------- loading
-- Reads the profile while acquiring the session lock. Returns (ok, raw)
function DataService:_acquire(key: string): (boolean, any)
	local cfg = GameConfig.Data
	for attempt = 1, cfg.LoadRetries do
		local lockedBy: string? = nil
		local raw: any = nil
		local ok, err = pcall(function()
			self.Store:UpdateAsync(key, function(old)
				lockedBy = nil
				local now = os.time()
				if type(old) == "table" and type(old.SessionLock) == "table" then
					local lock = old.SessionLock
					local stale = now - (tonumber(lock.Time) or 0) > cfg.SessionLockTimeout
					if lock.JobId ~= game.JobId and not stale and attempt < cfg.LoadRetries then
						lockedBy = tostring(lock.JobId)
						return nil -- cancel the write; we'll retry
					end
				end
				local value = if type(old) == "table" then old else { __new = true }
				value.SessionLock = { JobId = game.JobId, Time = now }
				raw = value
				return value
			end)
		end)
		if ok and lockedBy == nil then
			return true, raw
		end
		if lockedBy then
			Log.Info("Data", string.format("%s is locked by server %s (attempt %d)", key, lockedBy, attempt))
		else
			Log.Warn("Data", string.format("Load attempt %d for %s failed: %s", attempt, key, tostring(err)))
		end
		task.wait(cfg.LoadRetryDelay)
	end
	return false, nil
end

function DataService:LoadAsync(player: Player): Profile?
	if self.Profiles[player] then
		return self.Profiles[player]
	end
	if loading[player] then
		return self:WaitForProfile(player, 60)
	end
	loading[player] = true
	local key = keyFor(player.UserId)
	local ok, raw = self:_acquire(key)
	loading[player] = nil
	if not ok then
		Log.Error("Data", "Failed to load data for " .. player.Name, player.UserId)
		return nil
	end

	local isNew = type(raw) ~= "table" or raw.__new == true
	local data, issues = DataSchema.Prepare(if isNew then nil else raw)
	if #issues > 0 then
		Log.Warn("Data", string.format("Repaired %d issue(s) in %s's data: %s", #issues, player.Name,
			table.concat(issues, "; ", 1, math.min(#issues, 5))), player.UserId)
		for _, issue in issues do
			if string.find(issue, "duplicate item", 1, true) then
				Registry.AntiExploitService:Flag(player, "DuplicateItem", issue)
			end
		end
	end
	if isNew or data.FirstJoin == 0 then
		data.FirstJoin = os.time()
	end
	data.Stats.Logins += 1

	local profile: Profile = {
		Player = player,
		Key = key,
		Data = data,
		Session = {},
		DirtyData = {},
		DirtySession = {},
		Seq = 0,
		LastSave = os.clock(),
		Saving = false,
		Released = false,
		Releasing = false,
		LockLost = false,
		IsNew = isNew,
		LoadedAt = os.clock(),
	}
	self.Profiles[player] = profile
	self.ProfileLoaded:Fire(player, data)
	Log.Info("Data", string.format("Loaded %s (new=%s, mock=%s)", player.Name, tostring(isNew), tostring(self.UsingMock)), player.UserId)
	return profile
end

function DataService:WaitForProfile(player: Player, timeout: number?): Profile?
	local deadline = os.clock() + (timeout or 30)
	while os.clock() < deadline do
		local profile = self.Profiles[player]
		if profile then
			return profile
		end
		if player.Parent == nil then
			return nil
		end
		task.wait(0.1)
	end
	return self.Profiles[player]
end

---------------------------------------------------------------- saving
-- Returns true when the data was written.
function DataService:SaveAsync(player: Player, release: boolean?): boolean
	local profile = self.Profiles[player]
	if not profile or profile.LockLost then
		return false
	end
	if profile.Released and not release then
		return false
	end
	local waited = 0
	while profile.Saving and waited < 30 do
		task.wait(0.1)
		waited += 0.1
	end
	profile.Saving = true

	local snapshot = TableUtil.DeepCopy(profile.Data)
	snapshot.LastSave = os.time()
	snapshot.LastOnline = os.time()
	snapshot.SessionLock = nil

	local cfg = GameConfig.Data
	local success = false
	for attempt = 1, cfg.SaveRetries do
		local lockLost = false
		local ok, err = pcall(function()
			self.Store:UpdateAsync(profile.Key, function(old)
				lockLost = false
				if type(old) == "table" and type(old.SessionLock) == "table" and old.SessionLock.JobId ~= game.JobId then
					lockLost = true
					return nil
				end
				local value = TableUtil.DeepCopy(snapshot)
				if not release then
					value.SessionLock = { JobId = game.JobId, Time = os.time() }
				end
				return value
			end)
		end)
		if ok and lockLost then
			profile.LockLost = true
			Log.Error("Data", "Session lock lost for " .. player.Name .. " (loaded in another server)", player.UserId)
			if player.Parent then
				player:Kick("Your data was loaded in another server. Please rejoin.")
			end
			break
		elseif ok then
			success = true
			break
		end
		Log.Warn("Data", string.format("Save attempt %d for %s failed: %s", attempt, player.Name, tostring(err)), player.UserId)
		if attempt < cfg.SaveRetries then
			task.wait(math.min(2 ^ attempt, 10))
		end
	end
	profile.Saving = false
	if success then
		profile.LastSave = os.clock()
	end
	return success
end

-- Runs release hooks, saves with the lock released and forgets the profile.
function DataService:ReleaseAsync(player: Player)
	local profile = self.Profiles[player]
	if not profile or profile.Releasing then
		return
	end
	profile.Releasing = true
	for _, hook in self.BeforeRelease do
		local ok, err = pcall(hook, player)
		if not ok then
			Log.Error("Data", "BeforeRelease hook failed: " .. tostring(err), player.UserId)
		end
	end
	profile.Released = true
	if not profile.LockLost then
		local saved = self:SaveAsync(player, true)
		if not saved then
			Log.Error("Data", "Final save FAILED for " .. player.Name, player.UserId)
		end
	end
	self.Profiles[player] = nil
end

function DataService:_shutdown()
	self.ShuttingDown = true
	local pending = 0
	for player in self.Profiles do
		pending += 1
		task.spawn(function()
			self:ReleaseAsync(player)
			pending -= 1
		end)
	end
	local start = os.clock()
	while pending > 0 and os.clock() - start < GameConfig.Data.ShutdownTimeout do
		task.wait(0.1)
	end
	if pending > 0 then
		Log.Error("Data", tostring(pending) .. " profile(s) did not finish saving before shutdown")
	end
end

---------------------------------------------------------------- access
function DataService:GetProfile(player: Player): Profile?
	local profile = self.Profiles[player]
	if profile and not profile.Released then
		return profile
	end
	return nil
end

function DataService:Get(player: Player): { [string]: any }?
	local profile = self:GetProfile(player)
	return profile and profile.Data or nil
end

function DataService:IsLoaded(player: Player): boolean
	return self:GetProfile(player) ~= nil
end

function DataService:MarkDirty(player: Player, key: string)
	local profile = self.Profiles[player]
	if profile then
		profile.DirtyData[key] = true
	end
end

function DataService:SetSession(player: Player, key: string, value: any)
	local profile = self.Profiles[player]
	if not profile then
		return
	end
	if profile.Session[key] ~= value or type(value) == "table" then
		profile.Session[key] = value
		profile.DirtySession[key] = true
	end
end

function DataService:GetSession(player: Player, key: string): any
	local profile = self.Profiles[player]
	return profile and profile.Session[key] or nil
end

-- Full snapshot for the client's initial sync.
function DataService:Snapshot(player: Player)
	local profile = self:GetProfile(player)
	if not profile then
		return nil
	end
	local data = {}
	for key, value in profile.Data do
		if not PRIVATE_KEYS[key] then
			data[key] = value
		end
	end
	return { Seq = profile.Seq, Data = data, Session = profile.Session }
end

function DataService:_flush(player: Player, profile: Profile)
	if next(profile.DirtyData) == nil and next(profile.DirtySession) == nil then
		return
	end
	local patch = { Data = {}, Session = {} }
	for key in profile.DirtyData do
		if not PRIVATE_KEYS[key] then
			patch.Data[key] = profile.Data[key]
		end
	end
	for key in profile.DirtySession do
		patch.Session[key] = profile.Session[key]
	end
	table.clear(profile.DirtyData)
	table.clear(profile.DirtySession)
	profile.Seq += 1
	if player.Parent then
		syncRemote:FireClient(player, profile.Seq, patch)
	end
end

-- Wipes a player's data (Studio-only admin tool).
function DataService:ResetData(player: Player)
	local profile = self:GetProfile(player)
	if not profile then
		return
	end
	local fresh = DataSchema.Template()
	fresh.FirstJoin = os.time()
	profile.Data = fresh
	for key in fresh do
		profile.DirtyData[key] = true
	end
end

function DataService:AllProfiles(): { [Player]: Profile }
	return self.Profiles
end

Players.PlayerRemoving:Connect(function(player)
	loading[player] = nil
end)

return DataService
