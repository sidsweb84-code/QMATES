--[[
	Shop window
	Tabs: Packs (cash, exact odds shown) · Upgrades · Boosts (tokens) ·
	Cosmetics (tokens / rewards / gamepasses) · Event shop · Robux store.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local ShopConfig = require(Config.ShopConfig)
local UpgradeConfig = require(Config.UpgradeConfig)
local BoostConfig = require(Config.BoostConfig)
local CosmeticConfig = require(Config.CosmeticConfig)
local MonetizationConfig = require(Config.MonetizationConfig)
local RarityConfig = require(Config.RarityConfig)
local EventConfig = require(Config.EventConfig)
local Catalog = require(Shared.Catalog)
local Economy = require(Shared.Economy)
local Odds = require(Shared.Util.Odds)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local UIKit = require(UI.UIKit)
local CardView = require(UI.CardView)
local Notifications = require(UI.Notifications)
local HUD = require(UI.HUD)
local State = require(UI.Parent.Controllers.State)

local C = Theme.Colors
local player = Players.LocalPlayer

local Window = {}
Window.Title = "Shop"
Window.Icon = "🛒"
Window.Color = Color3.fromRGB(240, 160, 30)
Window.IsOpen = false

local content: Frame
local tabs: UIKit.Tabs
local currentTab = "Packs"
local cosmeticType = "Trail"
local priceCache: { [string]: string } = {}
-- Buttons whose enabled state depends on cash (updated without re-rendering).
local cashButtons: { { Button: GuiObject, Cost: number, Allowed: boolean } } = {}

local function request(action: string, ...)
	local response = Net.Request(action, ...)
	Notifications.Result(response)
	return response
end

local function row(parent: Instance, order: number, height: number?): Frame
	local frame = UIKit.Panel(parent, { Size = UDim2.new(1, -6, 0, height or 86), Color = C.PanelLight, Radius = 14, LayoutOrder = order, StrokeColor = C.Stroke })
	return frame
end

---------------------------------------------------------------- packs
local function renderPacks()
	local scroll = UIKit.Scroll(content, { Layout = "Grid", CellSize = Vector2.new(258, 300), Padding = 12 })
	local luck = State.Session.PersonalLuck or 1
	local rebirths = State.Data.Rebirths or 0
	for i, id in ShopConfig.PackOrder do
		local pack = ShopConfig.Packs[id]
		local cell = UIKit.Panel(scroll, { Color = C.PanelLight, Radius = 16, StrokeColor = pack.Color, StrokeThickness = 3, LayoutOrder = i })
		UIKit.Gradient(cell, { pack.Color:Lerp(Color3.new(1, 1, 1), 0.2), pack.Color:Lerp(Color3.new(0, 0, 0), 0.6) }, 90)
		UIKit.Label(cell, pack.Icon, { Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 52), TextSize = 46, XAlign = Enum.TextXAlignment.Center })
		UIKit.Label(cell, pack.Name, { Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 0, 28), TextSize = 22, Font = Theme.Fonts.Title, XAlign = Enum.TextXAlignment.Center, Stroke = 2 })
		local oddsFrame = UIKit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 90), Size = UDim2.new(1, -28, 0, 140), Parent = cell })
		UIKit.List(oddsFrame, "Y", 1)
		local probabilities = Odds.RarityProbabilities({ Luck = luck, BaseWeights = pack.Odds })
		local order = 0
		for _, rarityName in RarityConfig.Order do
			local p = probabilities[rarityName]
			if p and p > 0 then
				order += 1
				local rarity = RarityConfig.Rarities[rarityName]
				UIKit.Label(oddsFrame, string.format("%s  %s", rarity.Name, Format.Percent(p)), { TextSize = 14, Color = rarity.Color:Lerp(Color3.new(1, 1, 1), 0.3), LayoutOrder = order, Stroke = 1, Size = UDim2.new(1, 0, 0, 18) })
			end
		end
		local locked = (pack.RequiredRebirths or 0) > rebirths
		local button = UIKit.Button(cell, {
			Text = if locked then ("🔒 Rebirth " .. pack.RequiredRebirths) else ("Open " .. Format.Cash(pack.Price)),
			Style = "Success",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -12),
			Size = UDim2.new(1, -28, 0, 46),
			TextSize = 18,
			OnClick = function()
				request("BuyPack", id)
			end,
		})
		UIKit.SetButtonEnabled(button, not locked and (State.Data.Cash or 0) >= pack.Price)
		table.insert(cashButtons, { Button = button, Cost = pack.Price, Allowed = not locked })
	end
	UIKit.Label(scroll, "", { LayoutOrder = 99, Size = UDim2.fromOffset(1, 1) })
	local note = UIKit.Label(content, string.format("Odds include your personal luck (%s). Luck multiplies higher rarities more — the numbers shown are exact.", Format.Multiplier(luck)), {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 13,
		Color = C.SubText,
	})
	scroll.Size = UDim2.new(1, 0, 1, -24)
	note.ZIndex = 2
end

---------------------------------------------------------------- upgrades
local function trackEffect(track: string, level: number): string
	local info = Economy.TrackLevelInfo(track, level)
	if not info then
		return ""
	end
	if track == "Security" then
		return string.format("Lock %ds · thieves x%.2f slower", info.LockDuration, info.StealTimeMultiplier)
	elseif track == "Alarm" then
		return info.Feature
	elseif track == "Traps" then
		return if info.Count > 0 then string.format("%d traps · %.1fs stun", info.Count, info.StunDuration) else "No traps"
	elseif track == "AntiSteal" then
		return string.format("%ds protection after a robbery", info.Protection)
	elseif track == "AutoCollect" then
		return if info.Enabled then "Income goes straight to your wallet" else "Collect manually on your pad"
	end
	return ""
end

local function renderUpgrades()
	local scroll = UIKit.Scroll(content, { Padding = 8 })
	local data = State.Data
	local cash = data.Cash or 0
	-- Base capacity
	local baseRow = row(scroll, 0)
	local level = data.BaseLevel or 1
	local nextCost = Economy.NextBaseLevelCost(level)
	local extra = if State.Session.Passes and State.Session.Passes.ExtraSlots then MonetizationConfig.Gamepasses.ExtraSlots.Perks.ExtraSlots else 0
	UIKit.Label(baseRow, "🏠", { Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(56, 86), TextSize = 40, XAlign = Enum.TextXAlignment.Center })
	UIKit.Label(baseRow, string.format("Base Capacity  (Level %d/%d)", level, #UpgradeConfig.BaseLevels), { Position = UDim2.fromOffset(72, 10), Size = UDim2.new(1, -280, 0, 26), TextSize = 20, Font = Theme.Fonts.Title, Stroke = 2 })
	UIKit.Label(baseRow, string.format("%d slots%s", Economy.BaseSlots(level, extra), if nextCost then (" → " .. Economy.BaseSlots(level + 1, extra) .. " slots") else " (max)"), { Position = UDim2.fromOffset(72, 40), Size = UDim2.new(1, -280, 0, 20), TextSize = 15, Color = C.SubText })
	local baseButton = UIKit.Button(baseRow, {
		Text = if nextCost then Format.Cash(nextCost) else "MAXED",
		Style = "Success",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(180, 50),
		OnClick = function()
			request("UpgradeBase")
		end,
	})
	UIKit.SetButtonEnabled(baseButton, nextCost ~= nil and cash >= nextCost)
	table.insert(cashButtons, { Button = baseButton, Cost = nextCost or math.huge, Allowed = nextCost ~= nil })

	for i, track in UpgradeConfig.TrackOrder do
		local def = UpgradeConfig.Tracks[track]
		local current = (data.Upgrades and data.Upgrades[track]) or 0
		local maxLevel = Economy.TrackMaxLevel(track)
		local cost = Economy.TrackNextCost(track, current)
		local r = row(scroll, i)
		UIKit.Label(r, def.Icon, { Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(56, 86), TextSize = 38, XAlign = Enum.TextXAlignment.Center })
		UIKit.Label(r, string.format("%s  (Level %d/%d)", def.Name, current, maxLevel), { Position = UDim2.fromOffset(72, 8), Size = UDim2.new(1, -280, 0, 26), TextSize = 20, Font = Theme.Fonts.Title, Stroke = 2 })
		UIKit.Label(r, def.Description, { Position = UDim2.fromOffset(72, 34), Size = UDim2.new(1, -280, 0, 18), TextSize = 14, Color = C.SubText })
		UIKit.Label(r, "Now: " .. trackEffect(track, current) .. (if cost then ("   ➜   " .. trackEffect(track, current + 1)) else ""), { Position = UDim2.fromOffset(72, 54), Size = UDim2.new(1, -280, 0, 20), TextSize = 14, Color = C.Cash, Wrapped = true })
		local button = UIKit.Button(r, {
			Text = if cost then Format.Cash(cost) else "MAXED",
			Style = "Success",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(180, 50),
			OnClick = function()
				request("UpgradeTrack", track)
			end,
		})
		UIKit.SetButtonEnabled(button, cost ~= nil and cash >= cost)
		table.insert(cashButtons, { Button = button, Cost = cost or math.huge, Allowed = cost ~= nil })
	end
end

---------------------------------------------------------------- boosts
local function renderBoosts()
	local scroll = UIKit.Scroll(content, { Layout = "Grid", CellSize = Vector2.new(258, 150), Padding = 12 })
	local tokens = State.Data.Tokens or 0
	local now = workspace:GetServerTimeNow()
	for i, item in ShopConfig.BoostItems do
		local info = BoostConfig.Personal[item.Boost]
		local cell = UIKit.Panel(scroll, { Color = C.PanelLight, Radius = 16, StrokeColor = info.Color, StrokeThickness = 2.5, LayoutOrder = i })
		UIKit.Label(cell, info.Icon .. " " .. info.Name, { Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 28), TextSize = 21, Font = Theme.Fonts.Title, Stroke = 2 })
		UIKit.Label(cell, info.Description, { Position = UDim2.fromOffset(14, 40), Size = UDim2.new(1, -28, 0, 36), TextSize = 13, Color = C.SubText, Wrapped = true, YAlign = Enum.TextYAlignment.Top })
		local remaining = math.max(0, ((State.Data.Boosts or {})[item.Boost] or 0) - now)
		UIKit.Label(cell, "Duration " .. Format.Time(item.Duration) .. (if remaining > 0 then ("  ·  active " .. Format.Clock(remaining)) else ""), { Position = UDim2.fromOffset(14, 76), Size = UDim2.new(1, -28, 0, 18), TextSize = 13, Color = if remaining > 0 then C.Success else C.Muted })
		local button = UIKit.Button(cell, {
			Text = "🪙 " .. item.Price,
			Style = "Primary",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.new(1, -28, 0, 40),
			OnClick = function()
				request("BuyBoost", item.Id)
			end,
		})
		UIKit.SetButtonEnabled(button, tokens >= item.Price)
	end
end

---------------------------------------------------------------- cosmetics
local function ownsCosmetic(id: string, item): boolean
	if item.Unlock.Type == "Default" then
		return true
	end
	if item.Unlock.Type == "Gamepass" and State.Session.Passes and State.Session.Passes[item.Unlock.Pass] then
		return true
	end
	return (State.Data.Cosmetics and State.Data.Cosmetics.Owned[id]) == true
end

local function renderCosmetics()
	local typeTabs = {}
	for _, typeName in CosmeticConfig.Types do
		local info = CosmeticConfig.TypeInfo[typeName]
		table.insert(typeTabs, { Id = typeName, Text = info.Icon .. " " .. info.Name })
	end
	local scroll
	local tabBar = UIKit.Tabs(content, typeTabs, function(id)
		cosmeticType = id
		if scroll then
			scroll:Destroy()
		end
		scroll = UIKit.Scroll(content, { Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -44), Layout = "Grid", CellSize = Vector2.new(196, 150), Padding = 10 })
		local ids = {}
		for itemId, item in CosmeticConfig.Items do
			if item.Type == id then
				table.insert(ids, itemId)
			end
		end
		table.sort(ids, function(a, b)
			local pa = CosmeticConfig.Items[a].Unlock.Price or 0
			local pb = CosmeticConfig.Items[b].Unlock.Price or 0
			if pa ~= pb then
				return pa < pb
			end
			return a < b
		end)
		local equipped = State.Data.Cosmetics and State.Data.Cosmetics.Equipped[id]
		for i, itemId in ids do
			local item = CosmeticConfig.Items[itemId]
			local owned = ownsCosmetic(itemId, item)
			local isEquipped = equipped == itemId
			local cell = UIKit.Panel(scroll, { Color = C.PanelLight, Radius = 14, StrokeColor = if isEquipped then C.Success else C.Stroke, StrokeThickness = if isEquipped then 3 else 2, LayoutOrder = i })
			local swatch = UIKit.Panel(cell, { Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 40), Color = Color3.new(1, 1, 1), Radius = 10 })
			local colors = item.Colors or { item.Color or item.Wall or C.Stroke, item.Trim or item.Color or C.StrokeLight }
			UIKit.Gradient(swatch, colors, 0)
			if item.Type == "NameTag" then
				UIKit.Label(swatch, item.Text or item.Name, { Size = UDim2.fromScale(1, 1), TextSize = 18, Font = Theme.Fonts.Title, Color = item.Color or C.Text, XAlign = Enum.TextXAlignment.Center, Stroke = 2 })
				swatch.BackgroundColor3 = C.PanelDark
			end
			UIKit.Label(cell, item.Name, { Position = UDim2.fromOffset(10, 54), Size = UDim2.new(1, -20, 0, 22), TextSize = 17, Font = Theme.Fonts.Title, Stroke = 1 })
			local hint = if owned then (if isEquipped then "Equipped" else "Owned")
				elseif item.Unlock.Type == "Tokens" then ("🪙 " .. item.Unlock.Price .. " tokens")
				elseif item.Unlock.Type == "Gamepass" then ("💎 " .. (MonetizationConfig.Gamepasses[item.Unlock.Pass] and MonetizationConfig.Gamepasses[item.Unlock.Pass].Name or "Gamepass"))
				else ("🔒 " .. (item.Hint or "Reward"))
			UIKit.Label(cell, hint, { Position = UDim2.fromOffset(10, 76), Size = UDim2.new(1, -20, 0, 18), TextSize = 13, Color = if owned then C.Success else C.SubText })
			local buttonText, style, enabled
			if isEquipped then
				buttonText, style, enabled = (if CosmeticConfig.Defaults[id] == itemId then "Default" else "Unequip"), "Secondary", CosmeticConfig.Defaults[id] ~= itemId
			elseif owned then
				buttonText, style, enabled = "Equip", "Blue", true
			elseif item.Unlock.Type == "Tokens" then
				buttonText, style, enabled = "Buy", "Primary", (State.Data.Tokens or 0) >= item.Unlock.Price
			elseif item.Unlock.Type == "Gamepass" then
				buttonText, style, enabled = "Store", "Purple", true
			else
				buttonText, style, enabled = "Locked", "Secondary", false
			end
			local button = UIKit.Button(cell, {
				Text = buttonText,
				Style = style,
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -8),
				Size = UDim2.new(1, -20, 0, 38),
				TextSize = 17,
				OnClick = function()
					if isEquipped then
						request("EquipCosmetic", "", id)
					elseif owned then
						request("EquipCosmetic", itemId)
					elseif item.Unlock.Type == "Tokens" then
						request("BuyCosmetic", itemId)
					elseif item.Unlock.Type == "Gamepass" then
						tabs:Select("Robux")
					end
				end,
			})
			UIKit.SetButtonEnabled(button, enabled)
		end
	end, { Size = UDim2.new(1, 0, 0, 36), ButtonWidth = 158 })
	tabBar:Select(cosmeticType)
end

---------------------------------------------------------------- event shop
local function renderEvent()
	local events = HUD.ActiveEvents()
	local active = {}
	local currency = EventConfig.DefaultCurrency
	for _, e in events do
		active[e.Id] = true
		local def = EventConfig.Events[e.Id]
		if def and def.Currency then
			currency = def.Currency
		end
	end
	if #events == 0 then
		local secondsToNext = EventConfig.Schedule.Rotation.Period - (math.floor(workspace:GetServerTimeNow()) % EventConfig.Schedule.Rotation.Period)
		UIKit.Label(content, "🎪 No event is running right now.\nThe next rotating event starts in " .. Format.Time(secondsToNext) .. ".", {
			Size = UDim2.fromScale(1, 1),
			TextSize = 22,
			Font = Theme.Fonts.Title,
			XAlign = Enum.TextXAlignment.Center,
			Wrapped = true,
			Color = C.SubText,
		})
		return
	end
	UIKit.Label(content, string.format("%s You have %s %s · earn more by buying critters during events!", currency.Icon, Format.Abbreviate(State.Data.EventTokens or 0), currency.Name), { Size = UDim2.new(1, 0, 0, 26), TextSize = 17, Color = C.Event, Stroke = 1 })
	local scroll = UIKit.Scroll(content, { Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 1, -32), Layout = "Grid", CellSize = Vector2.new(196, 260), Padding = 10 })
	local order = 0
	for _, item in ShopConfig.EventShop do
		if item.Event and not active[item.Event] then
			continue
		end
		order += 1
		local cell = UIKit.Panel(scroll, { Color = C.PanelLight, Radius = 14, StrokeColor = C.Event, StrokeThickness = 2, LayoutOrder = order })
		local title, subtitle = "?", ""
		if item.Type == "Collectible" then
			CardView.Create(cell, { Id = item.CollectibleId, Mutation = "Normal" }, { Size = UDim2.fromOffset(110, 154), Position = UDim2.new(0.5, -55, 0, 8) })
			local def = Catalog.Get(item.CollectibleId)
			title = def and def.Name or "?"
			subtitle = "Limited critter"
		elseif item.Type == "Cosmetic" then
			local cosmetic = CosmeticConfig.Items[item.CosmeticId]
			title = cosmetic.Name
			subtitle = CosmeticConfig.TypeInfo[cosmetic.Type].Name
			UIKit.Label(cell, CosmeticConfig.TypeInfo[cosmetic.Type].Icon, { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 90), TextSize = 70, XAlign = Enum.TextXAlignment.Center })
		elseif item.Type == "Boost" then
			local info = BoostConfig.Personal[item.Boost]
			title = info.Name .. " " .. Format.Time(item.Duration)
			subtitle = "Boost"
			UIKit.Label(cell, info.Icon, { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 90), TextSize = 70, XAlign = Enum.TextXAlignment.Center })
		end
		UIKit.Label(cell, title, { Position = UDim2.fromOffset(8, 166), Size = UDim2.new(1, -16, 0, 22), TextSize = 17, Font = Theme.Fonts.Title, XAlign = Enum.TextXAlignment.Center, Stroke = 1 })
		UIKit.Label(cell, subtitle, { Position = UDim2.fromOffset(8, 188), Size = UDim2.new(1, -16, 0, 16), TextSize = 13, Color = C.SubText, XAlign = Enum.TextXAlignment.Center })
		local button = UIKit.Button(cell, {
			Text = currency.Icon .. " " .. item.Price,
			Style = "Primary",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -20, 0, 38),
			OnClick = function()
				request("BuyEventItem", item.Id)
			end,
		})
		UIKit.SetButtonEnabled(button, (State.Data.EventTokens or 0) >= item.Price)
	end
end

---------------------------------------------------------------- robux
local function fetchPrice(key: string, id: number, infoType: Enum.InfoType, label: TextLabel)
	local cacheKey = key .. ":" .. id
	if priceCache[cacheKey] then
		label.Text = priceCache[cacheKey]
		return
	end
	task.spawn(function()
		local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, infoType)
		if ok and info and info.PriceInRobux then
			priceCache[cacheKey] = "R$ " .. tostring(info.PriceInRobux)
			if label.Parent then
				label.Text = priceCache[cacheKey]
			end
		end
	end)
end

local function storeCell(parent: Instance, order: number, icon: string, name: string, description: string, id: number, owned: boolean, priceHint: number, onBuy: () -> ()): Frame
	local cell = UIKit.Panel(parent, { Color = C.PanelLight, Radius = 14, StrokeColor = C.Purple, StrokeThickness = 2, LayoutOrder = order })
	UIKit.Label(cell, icon, { Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(48, 48), TextSize = 36, XAlign = Enum.TextXAlignment.Center })
	UIKit.Label(cell, name, { Position = UDim2.fromOffset(64, 10), Size = UDim2.new(1, -72, 0, 24), TextSize = 18, Font = Theme.Fonts.Title, Stroke = 1 })
	UIKit.Label(cell, description, { Position = UDim2.fromOffset(12, 58), Size = UDim2.new(1, -24, 0, 58), TextSize = 13, Color = C.SubText, Wrapped = true, YAlign = Enum.TextYAlignment.Top })
	local priceLabel = UIKit.Label(cell, if id == 0 then "Coming soon" else ("~R$ " .. priceHint), { Position = UDim2.fromOffset(64, 34), Size = UDim2.new(1, -72, 0, 18), TextSize = 14, Color = C.Purple })
	local button = UIKit.Button(cell, {
		Text = if owned then "✅ Owned" elseif id == 0 then "Not set up" else "Buy",
		Style = "Purple",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -20, 0, 38),
		TextSize = 17,
		OnClick = onBuy,
	})
	UIKit.SetButtonEnabled(button, not owned and id ~= 0)
	return cell, priceLabel
end

local function renderRobux()
	local scroll = UIKit.Scroll(content, { Padding = 10 })
	UIKit.Label(scroll, "💎 Gamepasses — permanent perks", { TextSize = 20, Font = Theme.Fonts.Title, LayoutOrder = 1, Stroke = 2 })
	local passGrid = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = scroll })
	UIKit.Grid(passGrid, Vector2.new(260, 168), Vector2.new(10, 10))
	for i, key in MonetizationConfig.GamepassOrder do
		local pass = MonetizationConfig.Gamepasses[key]
		local owned = State.Session.Passes and State.Session.Passes[key] == true
		local _, priceLabel = storeCell(passGrid, i, pass.Icon, pass.Name, pass.Description, pass.Id, owned, pass.PriceHint, function()
			MarketplaceService:PromptGamePassPurchase(player, pass.Id)
		end)
		if pass.Id ~= 0 then
			fetchPrice("pass", pass.Id, Enum.InfoType.GamePass, priceLabel)
		end
	end
	UIKit.Label(scroll, "⚡ Boosts & bundles", { TextSize = 20, Font = Theme.Fonts.Title, LayoutOrder = 3, Stroke = 2 })
	local productGrid = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 4, Parent = scroll })
	UIKit.Grid(productGrid, Vector2.new(260, 168), Vector2.new(10, 10))
	for i, key in MonetizationConfig.ProductOrder do
		local product = MonetizationConfig.Products[key]
		local _, priceLabel = storeCell(productGrid, i, product.Icon, product.Name, product.Description, product.Id, false, product.PriceHint, function()
			MarketplaceService:PromptProductPurchase(player, product.Id)
		end)
		if product.Id ~= 0 then
			fetchPrice("product", product.Id, Enum.InfoType.Product, priceLabel)
		end
	end
	UIKit.Label(scroll, "Robux never buys random rewards. All gameplay is available to free players.", { TextSize = 13, Color = C.Muted, LayoutOrder = 5, Wrapped = true })
end

---------------------------------------------------------------- frame
local renderers = {
	Packs = renderPacks,
	Upgrades = renderUpgrades,
	Boosts = renderBoosts,
	Cosmetics = renderCosmetics,
	Event = renderEvent,
	Robux = renderRobux,
}

local function render()
	table.clear(cashButtons)
	UIKit.Clear(content)
	local renderer = renderers[currentTab]
	if renderer then
		renderer()
	end
end

function Window.Build(body: Frame)
	tabs = UIKit.Tabs(body, {
		{ Id = "Packs", Text = "🃏 Packs" },
		{ Id = "Upgrades", Text = "⬆️ Upgrades" },
		{ Id = "Boosts", Text = "⚡ Boosts" },
		{ Id = "Cosmetics", Text = "🎨 Cosmetics" },
		{ Id = "Event", Text = "🎟️ Event" },
		{ Id = "Robux", Text = "💎 Robux" },
	}, function(id)
		currentTab = id
		render()
	end, { ButtonWidth = 128 })
	content = UIKit.new("Frame", { Name = "Content", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 1, -50), Parent = body })
	local function refreshIfOpen()
		if Window.IsOpen and currentTab ~= "Robux" then
			render()
		end
	end
	for _, key in { "Upgrades", "BaseLevel", "Boosts", "Cosmetics", "Tokens", "EventTokens", "Rebirths", "Passes" } do
		State.On(key, refreshIfOpen)
	end
	-- Cash changes every second: just refresh affordability, never rebuild.
	State.On("Cash", function(cash)
		if Window.IsOpen then
			for _, entry in cashButtons do
				UIKit.SetButtonEnabled(entry.Button, entry.Allowed and (cash or 0) >= entry.Cost)
			end
		end
	end)
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
end

return Window
