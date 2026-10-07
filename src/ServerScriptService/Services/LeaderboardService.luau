--[[
	LeaderboardService
	- Roblox leaderstats (Cash, Rebirths, Steals).
	- Global leaderboards via OrderedDataStores (written periodically, read on a
	  timer, replicated to clients as a JSON attribute, drawn on hub boards).
	- Server Showcase: the rarest critters currently in the server are displayed
	  on pedestals in the Collection Hall.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local GameConfig = require(Config.GameConfig)
local RarityConfig = require(Config.RarityConfig)
local Catalog = require(Shared.Catalog)
local Economy = require(Shared.Economy)
local Format = require(Shared.Util.Format)
local CreatureBuilder = require(Shared.CreatureBuilder)
local CardBillboard = require(Shared.CardBillboard)

local Modules = script.Parent.Parent.Modules
local Registry = require(Modules.Registry)
local Log = require(Modules.Log)

local LeaderboardService = {}

LeaderboardService.Stats = {
	{ Key = "CashPerSec", Name = "Cash / sec", Icon = "💸", Format = "PerSec" },
	{ Key = "Cash", Name = "Cash", Icon = "💰", Format = "Cash" },
	{ Key = "Rebirths", Name = "Rebirths", Icon = "♻️", Format = "Number" },
	{ Key = "Collection", Name = "Collection", Icon = "📖", Format = "Number" },
	{ Key = "Rare", Name = "Rare Finds", Icon = "🌟", Format = "Number" },
	{ Key = "Steals", Name = "Steals", Icon = "🦹", Format = "Number" },
	{ Key = "Playtime", Name = "Playtime", Icon = "⏰", Format = "Hours" },
}

local stores: { [string]: OrderedDataStore } = {}
local available = false
local nextWrite: { [Player]: number } = {}
local nameCache: { [number]: string } = {}
local globalBoards: { [string]: { any } } = {}
local boardFrames: { [string]: Frame } = {}
local showcaseCFrames: { CFrame } = {}
local showcaseFolder: Folder? = nil
local showcaseKey = ""

local function statValue(player: Player, key: string): number
	local data = Registry.DataService:Get(player)
	if not data then
		return 0
	end
	if key == "CashPerSec" then
		return Registry.EconomyService:GetCashPerSec(player)
	elseif key == "Cash" then
		return data.Cash
	elseif key == "Rebirths" then
		return data.Rebirths
	elseif key == "Collection" then
		return Registry.CollectibleService:CollectionCount(player)
	elseif key == "Rare" then
		return data.Stats.RareFinds
	elseif key == "Steals" then
		return data.Stats.Steals
	elseif key == "Playtime" then
		return data.Stats.Playtime
	end
	return 0
end
LeaderboardService.StatValue = statValue

local function formatValue(format: string, value: number): string
	if format == "PerSec" then
		return Format.PerSec(value)
	elseif format == "Cash" then
		return Format.Cash(value)
	elseif format == "Hours" then
		return string.format("%.1fh", value / 3600)
	end
	return Format.Abbreviate(value)
end

function LeaderboardService:Init()
	ReplicatedStorage:SetAttribute("GlobalBoards", "{}")
	local ok, err = pcall(function()
		for _, stat in self.Stats do
			stores[stat.Key] = DataStoreService:GetOrderedDataStore(GameConfig.Leaderboards.StorePrefix .. stat.Key)
		end
		-- Probe once so Studio without API access falls back cleanly.
		stores.Rebirths:GetSortedAsync(false, 1)
	end)
	available = ok
	if not ok then
		Log.Warn("Leaderboard", "Global leaderboards unavailable (" .. tostring(err) .. "); showing server boards only.")
	end
end

function LeaderboardService:SetMap(mapRefs)
	boardFrames = mapRefs.Boards
	showcaseFolder = mapRefs.ShowcaseFolder
	showcaseCFrames = Registry.MapBuilder.BuildShowcasePedestals(mapRefs.ShowcaseFolder, GameConfig.Showcase.Count)
end

function LeaderboardService:Start()
	-- leaderstats refresh
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				self:_updateLeaderstats(player)
				local now = os.clock()
				if available and nextWrite[player] and now >= nextWrite[player] then
					nextWrite[player] = now + GameConfig.Leaderboards.WriteInterval
					task.spawn(self._write, self, player)
				end
			end
		end
	end)
	-- global read + board drawing
	task.spawn(function()
		while true do
			pcall(self._refreshGlobal, self)
			self:_drawBoards()
			task.wait(GameConfig.Leaderboards.RefreshInterval)
		end
	end)
	-- server boards redraw more often when global data is unavailable
	task.spawn(function()
		while true do
			task.wait(15)
			if not available then
				self:_drawBoards()
			end
		end
	end)
	-- showcase
	task.spawn(function()
		while true do
			pcall(self._refreshShowcase, self)
			task.wait(GameConfig.Showcase.RefreshInterval)
		end
	end)
end

---------------------------------------------------------------- leaderstats
function LeaderboardService:OnPlayerLoaded(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local cash = Instance.new("StringValue")
	cash.Name = "Cash"
	cash.Parent = folder
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = folder
	local steals = Instance.new("IntValue")
	steals.Name = "Steals"
	steals.Parent = folder
	folder.Parent = player
	local data = Registry.DataService:Get(player)
	if data then
		player:SetAttribute("Rebirths", data.Rebirths)
		player:SetAttribute("Steals", data.Stats.Steals)
	end
	self:_updateLeaderstats(player)
	-- Stagger first writes across the interval.
	nextWrite[player] = os.clock() + math.random(30, GameConfig.Leaderboards.WriteInterval)
end

function LeaderboardService:_updateLeaderstats(player: Player)
	local data = Registry.DataService:Get(player)
	local folder = player:FindFirstChild("leaderstats")
	if not data or not folder then
		return
	end
	local cash = folder:FindFirstChild("Cash") :: StringValue?
	local rebirths = folder:FindFirstChild("Rebirths") :: IntValue?
	local steals = folder:FindFirstChild("Steals") :: IntValue?
	if cash then
		cash.Value = Format.Cash(data.Cash)
	end
	if rebirths then
		rebirths.Value = data.Rebirths
	end
	if steals then
		steals.Value = data.Stats.Steals
	end
	player:SetAttribute("Cash", data.Cash)
	player:SetAttribute("RareFinds", data.Stats.RareFinds)
end

function LeaderboardService:OnPlayerRemoving(player: Player)
	if available then
		self:_write(player)
	end
	nextWrite[player] = nil
end

---------------------------------------------------------------- global boards
function LeaderboardService:_write(player: Player)
	if player.UserId <= 0 then
		return -- Studio test players / fake test profiles
	end
	for _, stat in self.Stats do
		local store = stores[stat.Key]
		local value = math.floor(statValue(player, stat.Key))
		if store and value > 0 then
			local ok, err = pcall(store.SetAsync, store, tostring(player.UserId), value)
			if not ok then
				Log.Warn("Leaderboard", "write failed: " .. tostring(err))
				return
			end
		end
	end
end

local function nameFor(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	nameCache[userId] = if ok and name then name else ("Player " .. userId)
	return nameCache[userId]
end

function LeaderboardService:_refreshGlobal()
	if not available then
		return
	end
	local result = {}
	for _, stat in self.Stats do
		local store = stores[stat.Key]
		local ok, pages = pcall(store.GetSortedAsync, store, false, GameConfig.Leaderboards.TopCount)
		if ok and pages then
			local entries = {}
			for rank, entry in pages:GetCurrentPage() do
				local userId = tonumber(entry.key) or 0
				table.insert(entries, { Rank = rank, UserId = userId, Name = nameFor(userId), Value = entry.value })
			end
			result[stat.Key] = entries
		end
	end
	globalBoards = result
	ReplicatedStorage:SetAttribute("GlobalBoards", HttpService:JSONEncode(result))
end

function LeaderboardService:ServerBoard(key: string): { any }
	local entries = {}
	for _, player in Players:GetPlayers() do
		if Registry.DataService:IsLoaded(player) then
			table.insert(entries, { UserId = player.UserId, Name = player.DisplayName, Value = statValue(player, key) })
		end
	end
	table.sort(entries, function(a, b)
		return a.Value > b.Value
	end)
	for i, e in entries do
		e.Rank = i
	end
	return entries
end

function LeaderboardService:GetGlobal()
	return globalBoards
end

function LeaderboardService:_drawBoards()
	for statKey, frame in boardFrames do
		local stat
		for _, s in self.Stats do
			if s.Key == statKey then
				stat = s
			end
		end
		if not stat then
			continue
		end
		local entries = globalBoards[statKey]
		local scope = "GLOBAL"
		if not entries or #entries == 0 then
			entries = self:ServerBoard(statKey)
			scope = "SERVER"
		end
		local list = frame:FindFirstChild("List")
		if not list then
			local title = Instance.new("TextLabel")
			title.Name = "Title"
			title.BackgroundTransparency = 1
			title.Size = UDim2.fromScale(0.92, 0.13)
			title.Position = UDim2.fromScale(0.04, 0.03)
			title.Font = Enum.Font.FredokaOne
			title.TextScaled = true
			title.TextColor3 = Color3.fromRGB(255, 220, 100)
			title.Parent = frame
			local newList = Instance.new("Frame")
			newList.Name = "List"
			newList.BackgroundTransparency = 1
			newList.Size = UDim2.fromScale(0.92, 0.8)
			newList.Position = UDim2.fromScale(0.04, 0.18)
			newList.Parent = frame
			local layout = Instance.new("UIListLayout")
			layout.Padding = UDim.new(0.01, 0)
			layout.Parent = newList
			list = newList
		end
		local title = frame:FindFirstChild("Title") :: TextLabel
		title.Text = string.format("%s TOP %s — %s", stat.Icon, string.upper(stat.Name), scope)
		for _, child in (list :: Frame):GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		for i = 1, math.min(10, #entries) do
			local e = entries[i]
			local row = Instance.new("TextLabel")
			row.BackgroundTransparency = if i % 2 == 0 then 1 else 0.85
			row.BackgroundColor3 = Color3.new(1, 1, 1)
			row.Size = UDim2.fromScale(1, 0.09)
			row.Font = Enum.Font.GothamBold
			row.TextScaled = true
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.TextColor3 = if i == 1 then Color3.fromRGB(255, 215, 80) elseif i == 2 then Color3.fromRGB(220, 225, 240) elseif i == 3 then Color3.fromRGB(240, 160, 90) else Color3.new(1, 1, 1)
			row.Text = string.format("  #%d  %s  —  %s", i, e.Name, formatValue(stat.Format, e.Value))
			row.LayoutOrder = i
			row.Parent = list
		end
	end
end

---------------------------------------------------------------- showcase
function LeaderboardService:_refreshShowcase()
	if not showcaseFolder or #showcaseCFrames == 0 then
		return
	end
	local candidates = {}
	for _, player in Players:GetPlayers() do
		local data = Registry.DataService:Get(player)
		if data then
			for _, item in data.Inventory do
				if item.Slot > 0 then
					local def = Catalog.Get(item.Id)
					if def then
						table.insert(candidates, {
							Item = item,
							Owner = player,
							Tier = RarityConfig.Rarities[def.Rarity].Tier,
							Income = Economy.ItemIncome(item),
						})
					end
				end
			end
		end
	end
	table.sort(candidates, function(a, b)
		if a.Tier ~= b.Tier then
			return a.Tier > b.Tier
		end
		return a.Income > b.Income
	end)
	local keyParts = {}
	for i = 1, math.min(#candidates, #showcaseCFrames) do
		table.insert(keyParts, candidates[i].Item.Uid .. candidates[i].Item.Level)
	end
	local key = table.concat(keyParts, ",")
	if key == showcaseKey then
		return
	end
	showcaseKey = key
	for _, child in (showcaseFolder :: Folder):GetChildren() do
		if child:IsA("Model") and child:GetAttribute("Showcase") then
			child:Destroy()
		end
	end
	for i = 1, math.min(#candidates, #showcaseCFrames) do
		local entry = candidates[i]
		local model = CreatureBuilder.Build(entry.Item.Id, { Mutation = entry.Item.Mutation })
		model:SetAttribute("Showcase", true)
		model:SetAttribute("Animation", "Spin")
		model:SetAttribute("HomeCFrame", showcaseCFrames[i])
		model:PivotTo(showcaseCFrames[i])
		CardBillboard.Attach(model, {
			Mode = "Showcase",
			Id = entry.Item.Id,
			Mutation = entry.Item.Mutation,
			Trait = entry.Item.Trait,
			Level = entry.Item.Level,
			Serial = entry.Item.Serial,
			Income = entry.Income,
			OwnerName = entry.Owner.DisplayName,
		})
		CollectionService:AddTag(model, "ShowcaseCreature")
		model.Parent = showcaseFolder
	end
end

return LeaderboardService
