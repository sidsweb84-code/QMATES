--[[
	Index window — the collection book.
	Collection tab: "37 / 68 Collected", milestone rewards, rarity filter,
	discovered and undiscovered cards, details for each critter.
	Odds tab: the exact live odds for both conveyors, mutations, traits and
	what personal luck does. Same functions the server rolls with.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local RarityConfig = require(Config.RarityConfig)
local MutationConfig = require(Config.MutationConfig)
local TraitConfig = require(Config.TraitConfig)
local RewardConfig = require(Config.RewardConfig)
local ConveyorConfig = require(Config.ConveyorConfig)
local EventConfig = require(Config.EventConfig)
local BoostConfig = require(Config.BoostConfig)
local CollectibleConfig = require(Config.CollectibleConfig)
local Catalog = require(Shared.Catalog)
local Economy = require(Shared.Economy)
local Odds = require(Shared.Util.Odds)
local Format = require(Shared.Util.Format)
local RewardFormat = require(Shared.Util.RewardFormat)
local Net = require(Shared.Net)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local UIKit = require(UI.UIKit)
local CardView = require(UI.CardView)
local Notifications = require(UI.Notifications)
local State = require(UI.Parent.Controllers.State)

local C = Theme.Colors

local Window = {}
Window.Title = "Collection Book"
Window.Icon = "📖"
Window.Color = Color3.fromRGB(120, 90, 230)
Window.IsOpen = false

local content: Frame
local tabs: UIKit.Tabs
local currentTab = "Book"
local rarityFilter = "All"
local selectedId: string? = nil
local stopSpin: (() -> ())? = nil

local function discoveredCount(): number
	local n = 0
	for id in State.Data.Collection or {} do
		local def = Catalog.Get(id)
		if def and not def.Limited then
			n += 1
		end
	end
	return n
end

---------------------------------------------------------------- book
local function renderDetail(panel: Frame)
	if stopSpin then
		stopSpin()
		stopSpin = nil
	end
	UIKit.Clear(panel)
	local def = selectedId and Catalog.Get(selectedId)
	if not def then
		UIKit.Label(panel, "Select a card", { Size = UDim2.fromScale(1, 1), TextSize = 18, XAlign = Enum.TextXAlignment.Center, Color = C.SubText })
		return
	end
	local entry = (State.Data.Collection or {})[def.Id]
	local discovered = entry ~= nil
	local card = CardView.Create(panel, { Id = def.Id, Mutation = if entry then entry.Best else "Normal", Undiscovered = not discovered, Count = entry and entry.Count }, {
		Size = UDim2.fromOffset(150, 210),
		Position = UDim2.new(0.5, -75, 0, 0),
		Viewport = discovered,
	})
	local art = card:FindFirstChild("Art")
	local viewport = art and art:FindFirstChild("Viewport")
	local model = viewport and viewport:FindFirstChildOfClass("Model")
	if model then
		stopSpin = CardView.Spin(model)
	end
	local info = UIKit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 218), Size = UDim2.new(1, 0, 1, -218), Parent = panel })
	UIKit.List(info, "Y", 3)
	local rarity = RarityConfig.Rarities[def.Rarity]
	local element = CollectibleConfig.Elements[def.Element]
	local lines = {
		{ if discovered then def.Name else "???", 20, rarity.Color, Theme.Fonts.Title },
		{ rarity.Name .. " · " .. element.Icon .. " " .. element.Series, 14, C.SubText },
		{ if discovered then def.Description else "Not discovered yet. Keep collecting!", 13, C.Text },
		{ "Base income " .. Format.PerSec(def.Income) .. " · Price " .. Format.Cash(def.Price), 13, C.Cash },
		{ "Steal time " .. string.format("%.1fs", Economy.StealDuration({ Uid = "", Id = def.Id }, 0)) .. (if def.RequiredRebirths > 0 then (" · Rebirth " .. def.RequiredRebirths .. "+ to buy") else ""), 13, C.SubText },
	}
	if def.Limited then
		local ev = EventConfig.Events[def.Event or ""]
		table.insert(lines, { "Limited — appears during " .. (ev and (ev.Icon .. " " .. ev.Name) or "events"), 13, C.Event })
	end
	if entry then
		local found = {}
		for _, m in MutationConfig.Order do
			if entry.Mutations[m] then
				table.insert(found, MutationConfig.Mutations[m].Icon .. m)
			end
		end
		table.insert(lines, { "Found ×" .. entry.Count .. " · Mutations: " .. table.concat(found, " "), 13, C.Accent })
	end
	for i, line in lines do
		local label = UIKit.Label(info, line[1], { TextSize = line[2], Color = line[3], Font = line[4], Wrapped = true, AutoSize = true, LayoutOrder = i, Stroke = 1 })
		label.Size = UDim2.new(1, 0, 0, 0)
	end
end

local function renderBook()
	local discovered = discoveredCount()
	local total = Catalog.CompletionTotal
	local header = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 74), Parent = content })
	UIKit.Label(header, string.format("%d / %d Collected", discovered, total), { Size = UDim2.new(0.4, 0, 0, 32), TextSize = 28, Font = Theme.Fonts.Title, Color = C.Accent, Stroke = 2 })
	local bar = UIKit.ProgressBar(header, { Position = UDim2.fromOffset(0, 38), Size = UDim2.new(0.4, -10, 0, 26), Color = C.Purple })
	bar:Set(discovered / total, string.format("%d%%", math.floor(discovered / total * 100)))
	local milestones = UIKit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0.4, 0, 0, 0), Size = UDim2.new(0.6, 0, 0, 66), Parent = header })
	UIKit.List(milestones, "X", 8, Enum.HorizontalAlignment.Right)
	for i, m in RewardConfig.CollectionMilestones do
		local needed = math.ceil(total * m.Percent / 100)
		local claimed = (State.Data.CollectionClaimed or {})[tostring(m.Percent)] == true
		local ready = discovered >= needed and not claimed
		local button = UIKit.Button(milestones, {
			Text = if claimed then ("✅ " .. m.Percent .. "%") else ("🎁 " .. m.Percent .. "%"),
			Style = if ready then "Primary" else "Secondary",
			Size = UDim2.fromOffset(112, 60),
			TextSize = 18,
			LayoutOrder = i,
			OnClick = function()
				if ready then
					Notifications.Result(Net.Request("ClaimCollectionMilestone", m.Percent))
				else
					Notifications.Toast(string.format("%d%% (%d critters): %s", m.Percent, needed, RewardFormat.DescribeList(m.Rewards)), "Info")
				end
			end,
		})
		if claimed then
			UIKit.SetButtonEnabled(button, false)
		end
	end

	local filters = { { Id = "All", Text = "All" } }
	for _, r in RarityConfig.Order do
		table.insert(filters, { Id = r, Text = r })
	end
	local listArea = UIKit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 120), Size = UDim2.new(0.68, 0, 1, -120), Parent = content })
	local detail = UIKit.Panel(content, { Position = UDim2.new(0.7, 0, 0, 80), Size = UDim2.new(0.3, 0, 1, -80), Color = C.PanelDark, Radius = 14 })
	UIKit.Padding(detail, 10)
	local filterScroll = UIKit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(0.68, 0, 0, 38),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 3,
		Parent = content,
	})
	local filterTabs = UIKit.Tabs(filterScroll, filters, function(id)
		rarityFilter = id
		UIKit.Clear(listArea)
		local grid = UIKit.Scroll(listArea, { Layout = "Grid", CellSize = Vector2.new(96, 134), Padding = 8 })
		for i, def in Catalog.All do
			if rarityFilter ~= "All" and def.Rarity ~= rarityFilter then
				continue
			end
			local entry = (State.Data.Collection or {})[def.Id]
			CardView.Create(grid, { Id = def.Id, Mutation = if entry then entry.Best else "Normal", Undiscovered = entry == nil, Count = entry and entry.Count }, {
				LayoutOrder = i,
				OnClick = function()
					selectedId = def.Id
					renderDetail(detail)
				end,
			})
		end
	end, { Size = UDim2.new(0, 10 * 104, 1, 0), ButtonWidth = 96 })
	filterTabs:Select(rarityFilter)
	renderDetail(detail)
end

---------------------------------------------------------------- odds
local function eventModifiers()
	local merged = { IncomeMultiplier = 1, LuckMultiplier = 1, RarityWeightMultipliers = {}, MutationChanceMultipliers = {}, EnabledMutations = {}, LimitedWeight = 0, ActiveEvents = {} }
	local ok, list = pcall(HttpService.JSONDecode, HttpService, ReplicatedStorage:GetAttribute("ActiveEvents") or "[]")
	for _, e in (if ok then list else {}) do
		local def = EventConfig.Events[e.Id]
		if def then
			merged.ActiveEvents[e.Id] = true
			local m = def.Modifiers or {}
			merged.LuckMultiplier *= m.LuckMultiplier or 1
			for r, mult in m.RarityWeightMultipliers or {} do
				merged.RarityWeightMultipliers[r] = (merged.RarityWeightMultipliers[r] or 1) * mult
			end
			for mu, mult in m.MutationChanceMultipliers or {} do
				merged.MutationChanceMultipliers[mu] = (merged.MutationChanceMultipliers[mu] or 1) * mult
			end
			for _, mu in m.EnableMutations or {} do
				merged.EnabledMutations[mu] = math.max(merged.EnabledMutations[mu] or 0, (m.EnableMutationChance and m.EnableMutationChance[mu]) or 0.001)
			end
			merged.LimitedWeight += m.LimitedWeight or 0
		end
	end
	return merged
end

local function serverLuck(mods): number
	local now = workspace:GetServerTimeNow()
	local boost = if (ReplicatedStorage:GetAttribute("ServerLuckExpires") or 0) > now then BoostConfig.Server.ServerLuck.Multiplier else 1
	return boost * (ReplicatedStorage:GetAttribute("AdminLuck") or 1) * mods.LuckMultiplier
end

local function oddsColumn(parent: Instance, title: string, probabilities: { [string]: number }, order: { string }, colorFor: (string) -> Color3, labelFor: ((string) -> string)?)
	local column = UIKit.Panel(parent, { Size = UDim2.new(0, 260, 0, 0), Color = C.PanelLight, Radius = 14 })
	column.AutomaticSize = Enum.AutomaticSize.Y
	UIKit.Padding(column, 10)
	UIKit.List(column, "Y", 2)
	UIKit.Label(column, title, { TextSize = 18, Font = Theme.Fonts.Title, LayoutOrder = 0, Stroke = 1, Wrapped = true, AutoSize = true })
	for i, key in order do
		local p = probabilities[key] or 0
		if p > 0 then
			UIKit.Label(column, string.format("%s   %s  (%s)", labelFor and labelFor(key) or key, Format.Percent(p), Format.OneIn(p)), { TextSize = 14, Color = colorFor(key), LayoutOrder = i, Stroke = 1 })
		end
	end
	return column
end

local function renderOdds()
	local scroll = UIKit.Scroll(content, { Padding = 10 })
	local mods = eventModifiers()
	local luck = serverLuck(mods)
	local personal = State.Session.PersonalLuck or 1
	UIKit.Label(scroll, string.format("🌍 Server luck %s   ·   🍀 Your personal luck %s", Format.Multiplier(luck), Format.Multiplier(personal)), { TextSize = 18, Font = Theme.Fonts.Title, Stroke = 1, LayoutOrder = 0 })
	UIKit.Label(scroll, "How luck works: every rarity above the lowest available one gets its weight multiplied by Luck^(0.5 × tiers above, max 2). Mutation chances are multiplied by √Luck. Personal luck affects card packs and gives a bonus mutation roll when you buy a Normal critter. These are the exact formulas the server uses.", {
		TextSize = 13,
		Color = C.SubText,
		Wrapped = true,
		AutoSize = true,
		LayoutOrder = 1,
		Size = UDim2.new(1, -10, 0, 0),
	})
	local row = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = scroll })
	local layout = UIKit.List(row, "X", 10)
	layout.Wraps = true
	local rarityColor = function(r: string)
		return RarityConfig.Rarities[r].Color:Lerp(Color3.new(1, 1, 1), 0.25)
	end
	for _, name in ConveyorConfig.Order do
		local cfg = ConveyorConfig.Conveyors[name]
		local probabilities = Odds.RarityProbabilities({ Luck = luck * cfg.LuckMultiplier, MinRarity = cfg.MinRarity, Modifiers = mods })
		oddsColumn(row, string.format("%s (luck %s)", cfg.Name, Format.Multiplier(luck * cfg.LuckMultiplier)), probabilities, RarityConfig.Order, rarityColor)
	end
	local mutationChances = Odds.MutationChances(luck, mods)
	oddsColumn(row, "Mutations (conveyor)", mutationChances, MutationConfig.Order, function(m)
		return MutationConfig.Mutations[m].Color
	end, function(m)
		local info = MutationConfig.Mutations[m]
		return info.Icon .. " " .. m .. " x" .. info.IncomeMultiplier
	end)
	local traitChances = Odds.TraitChances()
	oddsColumn(row, "Traits (any spawn)", traitChances, TraitConfig.Order, function(t)
		return TraitConfig.Traits[t].Color
	end, function(t)
		return TraitConfig.Traits[t].Icon .. " " .. t
	end)
	local bonus = Odds.BonusMutationRollChance(personal)
	local normalChances = Odds.MutationChances(1, mods)
	local bonusTotal = bonus * (1 - (normalChances.Normal or 1))
	UIKit.Label(scroll, string.format("🎲 Your bonus mutation chance on Normal purchases: %s", Format.Percent(bonusTotal)), { TextSize = 16, Color = C.Accent, LayoutOrder = 3, Stroke = 1 })
	if next(mods.ActiveEvents) then
		local names = {}
		for id in mods.ActiveEvents do
			table.insert(names, EventConfig.Events[id].Icon .. " " .. EventConfig.Events[id].Name)
		end
		UIKit.Label(scroll, "Active events included above: " .. table.concat(names, ", "), { TextSize = 14, Color = C.Event, LayoutOrder = 4, Wrapped = true, AutoSize = true, Size = UDim2.new(1, -10, 0, 0) })
	end
end

local function render()
	if stopSpin then
		stopSpin()
		stopSpin = nil
	end
	UIKit.Clear(content)
	if currentTab == "Book" then
		renderBook()
	else
		renderOdds()
	end
end

function Window.Build(body: Frame)
	tabs = UIKit.Tabs(body, {
		{ Id = "Book", Text = "📖 Collection" },
		{ Id = "Odds", Text = "🎲 Odds" },
	}, function(id)
		currentTab = id
		render()
	end, { ButtonWidth = 160 })
	content = UIKit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 1, -50), Parent = body })
	for _, key in { "Collection", "CollectionClaimed" } do
		State.On(key, function()
			if Window.IsOpen and currentTab == "Book" then
				render()
			end
		end)
	end
end

function Window.Open(args)
	Window.IsOpen = true
	if args and args.Tab then
		currentTab = args.Tab
	end
	tabs:Select(currentTab)
end

function Window.Close()
	Window.IsOpen = false
	if stopSpin then
		stopSpin()
		stopSpin = nil
	end
end

return Window
