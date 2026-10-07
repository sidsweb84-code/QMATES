--[[
	Collection window ("My Cards")
	Every critter you own: placed (earning) and in storage. Select one to see
	it in 3D and level it up, sell it, favourite it or move it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local MutationConfig = require(Config.MutationConfig)
local TraitConfig = require(Config.TraitConfig)
local UpgradeConfig = require(Config.UpgradeConfig)
local RarityConfig = require(Config.RarityConfig)
local Catalog = require(Shared.Catalog)
local Economy = require(Shared.Economy)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local UIKit = require(UI.UIKit)
local CardView = require(UI.CardView)
local Notifications = require(UI.Notifications)
local State = require(UI.Parent.Controllers.State)

local C = Theme.Colors

local Window = {}
Window.Title = "My Cards"
Window.Icon = "🎴"
Window.Color = Color3.fromRGB(70, 140, 255)
Window.IsOpen = false

local statsLabel: TextLabel
local grid: ScrollingFrame
local detail: Frame
local filter = "All"
local selectedUid: string? = nil
local stopSpin: (() -> ())? = nil
local filterTabs: UIKit.Tabs

local function sortedItems(): { any }
	local list = {}
	for _, item in State.Data.Inventory or {} do
		if filter == "All" or (filter == "Base" and item.Slot > 0) or (filter == "Storage" and item.Slot == 0) then
			table.insert(list, item)
		end
	end
	table.sort(list, function(a, b)
		if (a.Slot > 0) ~= (b.Slot > 0) then
			return a.Slot > 0
		end
		return Economy.ItemIncome(a) > Economy.ItemIncome(b)
	end)
	return list
end

local function request(action: string, ...)
	local response = Net.Request(action, ...)
	Notifications.Result(response)
	return response
end

local function renderDetail()
	if stopSpin then
		stopSpin()
		stopSpin = nil
	end
	UIKit.Clear(detail)
	local item = selectedUid and State.Data.Inventory and State.Data.Inventory[selectedUid]
	if not item then
		UIKit.Label(detail, "Select a card to see its details.", { Size = UDim2.fromScale(1, 1), TextSize = 18, XAlign = Enum.TextXAlignment.Center, Wrapped = true, Color = C.SubText })
		return
	end
	local def = Catalog.Get(item.Id)
	local frameId = State.Data.Cosmetics and State.Data.Cosmetics.Equipped.CardFrame
	local card = CardView.Create(detail, {
		Id = item.Id,
		Mutation = item.Mutation,
		Trait = item.Trait,
		Level = item.Level,
		Serial = item.Serial,
		FrameId = frameId,
		Locked = item.Locked,
		Stored = item.Slot == 0,
	}, { Size = UDim2.fromOffset(170, 238), Position = UDim2.fromOffset(0, 0), Viewport = true })
	local art = card:FindFirstChild("Art")
	local viewport = art and art:FindFirstChild("Viewport")
	local model = viewport and viewport:FindFirstChildOfClass("Model")
	if model then
		stopSpin = CardView.Spin(model)
	end

	local info = UIKit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(182, 0), Size = UDim2.new(1, -182, 0, 238), Parent = detail })
	UIKit.List(info, "Y", 3)
	local mutation = MutationConfig.Mutations[item.Mutation] or MutationConfig.Mutations.Normal
	local trait = TraitConfig.Get(item.Trait)
	local rarity = def and RarityConfig.Rarities[def.Rarity]
	local lines = {
		{ (def and def.Name or "?"), Theme.Fonts.Title, 22, rarity and rarity.Color or C.Text },
		{ (rarity and rarity.Name or "") .. " • " .. (def and def.Element or ""), Theme.Fonts.Body, 15, C.SubText },
		{ "💸 " .. Format.PerSec(Economy.ItemIncome(item)) .. " base income", Theme.Fonts.Body, 16, C.Cash },
		{ "⭐ Level " .. item.Level .. " / " .. UpgradeConfig.CardLevels.MaxLevel, Theme.Fonts.Body, 15, C.Text },
		{ if mutation.Tier > 0 then (mutation.Icon .. " " .. mutation.Name .. " (x" .. mutation.IncomeMultiplier .. ")") else "No mutation", Theme.Fonts.Body, 15, mutation.Color },
		{ if trait then (trait.Icon .. " " .. trait.Name .. ": " .. trait.Description) else "No trait", Theme.Fonts.Regular, 14, if trait then trait.Color else C.Muted },
		{ "🏷️ Value " .. Format.Cash(Economy.ItemValue(item)) .. " · Sells for " .. Format.Cash(Economy.SellValue(item)), Theme.Fonts.Regular, 14, C.SubText },
		{ "🔢 Serial " .. Format.Serial(item.Serial) .. " · From: " .. tostring(item.Source), Theme.Fonts.Regular, 14, C.SubText },
		{ if item.Slot > 0 then ("🏠 On pedestal #" .. item.Slot) else "📦 In storage (not earning)", Theme.Fonts.Body, 14, if item.Slot > 0 then C.Success else C.Warning },
	}
	for i, line in lines do
		local label = UIKit.Label(info, line[1], { TextSize = line[3], Font = line[2], Color = line[4], LayoutOrder = i, Wrapped = true, AutoSize = true, Stroke = 1 })
		label.Size = UDim2.new(1, 0, 0, 0)
	end

	local buttons = UIKit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 248), Size = UDim2.new(1, 0, 1, -248), Parent = detail })
	local layout = UIKit.Grid(buttons, Vector2.new(170, 46), Vector2.new(8, 8))
	layout.CellSize = UDim2.new(0.5, -4, 0, 46)
	local cost = Economy.LevelUpCost(item)
	local levelButton = UIKit.Button(buttons, {
		Text = if cost then ("⬆ Level up " .. Format.Cash(cost)) else "MAX LEVEL",
		Style = "Success",
		TextSize = 16,
		LayoutOrder = 1,
		OnClick = function()
			request("LevelUpItem", item.Uid)
		end,
	})
	UIKit.SetButtonEnabled(levelButton, cost ~= nil and (State.Data.Cash or 0) >= cost)
	local sellButton = UIKit.Button(buttons, {
		Text = "💰 Sell " .. Format.Cash(Economy.SellValue(item)),
		Style = "Danger",
		TextSize = 16,
		LayoutOrder = 2,
		OnClick = function()
			Notifications.Confirm("Sell " .. (def and def.Name or "critter") .. "?", "You'll receive " .. Format.Cash(Economy.SellValue(item)) .. ". This can't be undone.", "Sell", function()
				local response = request("SellItem", item.Uid)
				if response.Ok then
					selectedUid = nil
				end
			end, "Danger")
		end,
	})
	UIKit.SetButtonEnabled(sellButton, not item.Locked)
	UIKit.Button(buttons, {
		Text = if item.Locked then "☆ Unfavourite" else "⭐ Favourite",
		Style = "Primary",
		TextSize = 16,
		LayoutOrder = 3,
		OnClick = function()
			request("ToggleItemLock", item.Uid)
		end,
	})
	UIKit.Button(buttons, {
		Text = if item.Slot > 0 then "📦 To storage" else "🏠 Place in base",
		Style = "Blue",
		TextSize = 16,
		LayoutOrder = 4,
		OnClick = function()
			request("MoveItem", item.Uid, if item.Slot > 0 then "Storage" else "Base")
		end,
	})
end

local function renderGrid()
	UIKit.Clear(grid)
	local items = sortedItems()
	local frameId = State.Data.Cosmetics and State.Data.Cosmetics.Equipped.CardFrame
	for i, item in items do
		CardView.Create(grid, {
			Id = item.Id,
			Mutation = item.Mutation,
			Trait = item.Trait,
			Level = item.Level,
			Serial = item.Serial,
			FrameId = frameId,
			Locked = item.Locked,
			Stored = item.Slot == 0,
		}, {
			LayoutOrder = i,
			OnClick = function()
				selectedUid = item.Uid
				renderDetail()
			end,
		})
	end
	if #items == 0 then
		UIKit.Label(grid, "No critters here yet — buy some from the conveyor!", { TextSize = 18, Color = C.SubText, Size = UDim2.new(1, 0, 0, 60), Wrapped = true })
	end
	local placed, stored = 0, 0
	for _, item in State.Data.Inventory or {} do
		if item.Slot > 0 then
			placed += 1
		else
			stored += 1
		end
	end
	statsLabel.Text = string.format("🏠 Base %d/%d   📦 Storage %d/%d   💸 %s", placed, State.Session.Capacity or 0, stored, State.Session.StorageCapacity or 0, Format.PerSec(State.Session.CashPerSec or 0))
end

function Window.Build(body: Frame)
	statsLabel = UIKit.Label(body, "", { Size = UDim2.new(0.6, 0, 0, 30), TextSize = 17, Stroke = 1 })
	filterTabs = UIKit.Tabs(body, {
		{ Id = "All", Text = "All" },
		{ Id = "Base", Text = "Base" },
		{ Id = "Storage", Text = "Storage" },
	}, function(id)
		filter = id
		renderGrid()
	end, { Position = UDim2.new(0.6, 0, 0, -2), Size = UDim2.new(0.4, 0, 0, 34), ButtonWidth = 100 })
	grid = UIKit.Scroll(body, { Position = UDim2.fromOffset(0, 40), Size = UDim2.new(0.56, 0, 1, -40), Layout = "Grid", CellSize = Vector2.new(112, 157), Padding = 8 })
	detail = UIKit.Panel(body, { Position = UDim2.new(0.58, 0, 0, 40), Size = UDim2.new(0.42, 0, 1, -40), Color = C.PanelDark, Radius = 14 })
	UIKit.Padding(detail, 10)
	State.On("Inventory", function()
		if Window.IsOpen then
			renderGrid()
			renderDetail()
		end
	end)
	State.On("Cash", function()
		if Window.IsOpen and selectedUid then
			-- Keep the level-up button's affordability current.
			local item = State.Data.Inventory and State.Data.Inventory[selectedUid]
			if item then
				local cost = Economy.LevelUpCost(item)
				for _, d in detail:GetDescendants() do
					if d:IsA("TextButton") and d.LayoutOrder == 1 then
						UIKit.SetButtonEnabled(d, cost ~= nil and (State.Data.Cash or 0) >= cost)
					end
				end
			end
		end
	end)
end

function Window.Open(args)
	Window.IsOpen = true
	if args and args.Uid then
		selectedUid = args.Uid
		filter = "All"
	end
	filterTabs:Select(filter)
	renderDetail()
end

function Window.Close()
	Window.IsOpen = false
	if stopSpin then
		stopSpin()
		stopSpin = nil
	end
end

return Window
