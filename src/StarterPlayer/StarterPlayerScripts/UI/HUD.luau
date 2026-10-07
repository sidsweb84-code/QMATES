--[[
	HUD
	Top-left: player card · Top-centre: cash + cash/sec, boosts, live events
	Top-right: tokens / event tokens · Left: quick buttons · Bottom: main nav.
	Badges highlight anything claimable.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local BoostConfig = require(Config.BoostConfig)
local EventConfig = require(Config.EventConfig)
local RewardConfig = require(Config.RewardConfig)
local QuestConfig = require(Config.QuestConfig)
local Economy = require(Shared.Economy)
local Catalog = require(Shared.Catalog)
local Format = require(Shared.Util.Format)
local TimeUtil = require(Shared.Util.TimeUtil)
local Net = require(Shared.Net)

local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)
local Root = require(script.Parent.Root)
local WindowManager = require(script.Parent.WindowManager)
local Notifications = require(script.Parent.Notifications)
local State = require(script.Parent.Parent.Controllers.State)

local C = Theme.Colors
local player = Players.LocalPlayer

local HUD = {}
HUD.Buttons = {} :: { [string]: GuiObject }

local badges: { [string]: Frame } = {}

local function addBadge(button: GuiObject, name: string)
	local badge = UIKit.Panel(button, {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(26, 26),
		Color = C.Danger,
		Radius = 13,
		StrokeColor = Color3.new(1, 1, 1),
		StrokeThickness = 2,
		Visible = false,
		ZIndex = 5,
	})
	local label = UIKit.Label(badge, "!", { Size = UDim2.fromScale(1, 1), TextSize = 15, XAlign = Enum.TextXAlignment.Center, Font = Theme.Fonts.Title })
	label.ZIndex = 6
	badges[name] = badge
end

function HUD.SetBadge(name: string, count: number)
	local badge = badges[name]
	if not badge then
		return
	end
	local wasVisible = badge.Visible
	badge.Visible = count > 0
	local label = badge:FindFirstChildOfClass("TextLabel")
	if label then
		label.Text = if count > 9 then "9+" elseif count > 0 then tostring(count) else ""
	end
	if count > 0 and not wasVisible then
		UIKit.Pop(badge, 0.5)
	end
end

---------------------------------------------------------------- top bar
local cashLabel: TextLabel
local cpsLabel: TextLabel
local tokensLabel: TextLabel
local eventTokensPill: Frame
local eventTokensLabel: TextLabel
local boostRow: Frame
local eventRow: Frame
local rebirthLabel: TextLabel
local luckLabel: TextLabel
local displayedCash = 0
local targetCash = 0

local function buildTop()
	-- Player card
	local card = UIKit.Panel(Root.HUD, {
		Name = "PlayerCard",
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.fromOffset(290, 76),
		Color = C.Panel,
		StrokeColor = C.Stroke,
		Radius = 16,
	})
	card.BackgroundTransparency = 0.08
	local avatarFrame = UIKit.Panel(card, { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(60, 60), Color = C.PanelLight, Radius = 30, StrokeColor = C.Accent, StrokeThickness = 2 })
	local avatar = UIKit.new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = avatarFrame })
	UIKit.Corner(avatar, 30)
	task.spawn(function()
		local ok, image = pcall(Players.GetUserThumbnailAsync, Players, player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		if ok then
			avatar.Image = image
		end
	end)
	UIKit.Label(card, player.DisplayName, { Position = UDim2.fromOffset(78, 6), Size = UDim2.new(1, -86, 0, 26), TextSize = 21, Font = Theme.Fonts.Title, Stroke = 2 })
	rebirthLabel = UIKit.Label(card, "♻️ Rebirth 0", { Position = UDim2.fromOffset(78, 32), Size = UDim2.new(1, -86, 0, 18), TextSize = 14, Color = Color3.fromRGB(140, 255, 190) })
	luckLabel = UIKit.Label(card, "🍀 Luck x1", { Position = UDim2.fromOffset(78, 50), Size = UDim2.new(1, -86, 0, 18), TextSize = 14, Color = C.SubText })

	-- Cash pill
	local cash = UIKit.Panel(Root.HUD, {
		Name = "Cash",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(330, 70),
		Color = C.Panel,
		StrokeColor = C.Cash,
		StrokeThickness = 3,
		Radius = 22,
	})
	cash.BackgroundTransparency = 0.05
	UIKit.Gradient(cash, { Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 200, 220) }, 90)
	UIKit.Label(cash, "💰", { Position = UDim2.fromOffset(12, 0), Size = UDim2.fromOffset(46, 70), TextSize = 36, XAlign = Enum.TextXAlignment.Center })
	cashLabel = UIKit.Label(cash, "$0", { Name = "Amount", Position = UDim2.fromOffset(62, 6), Size = UDim2.new(1, -74, 0, 38), TextSize = 34, Font = Theme.Fonts.Title, Color = C.Cash, Stroke = 3 })
	cpsLabel = UIKit.Label(cash, "+$0/s", { Name = "PerSec", Position = UDim2.fromOffset(64, 44), Size = UDim2.new(1, -74, 0, 20), TextSize = 16, Color = Color3.fromRGB(220, 255, 220), Stroke = 2 })
	HUD.CashPill = cash

	boostRow = UIKit.new("Frame", {
		Name = "Boosts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 84),
		Size = UDim2.fromOffset(520, 28),
		BackgroundTransparency = 1,
		Parent = Root.HUD,
	})
	UIKit.List(boostRow, "X", 6, Enum.HorizontalAlignment.Center)
	eventRow = UIKit.new("Frame", {
		Name = "Events",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 116),
		Size = UDim2.fromOffset(620, 28),
		BackgroundTransparency = 1,
		Parent = Root.HUD,
	})
	UIKit.List(eventRow, "X", 6, Enum.HorizontalAlignment.Center)

	-- Tokens
	local tokens = UIKit.Panel(Root.HUD, {
		Name = "Tokens",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(170, 46),
		Color = C.Panel,
		StrokeColor = C.Token,
		StrokeThickness = 2.5,
		Radius = 18,
	})
	UIKit.Label(tokens, "🪙", { Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(34, 46), TextSize = 26, XAlign = Enum.TextXAlignment.Center })
	tokensLabel = UIKit.Label(tokens, "0", { Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -54, 1, 0), TextSize = 26, Font = Theme.Fonts.Title, Color = C.Token, Stroke = 2 })
	eventTokensPill = UIKit.Panel(Root.HUD, {
		Name = "EventTokens",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 62),
		Size = UDim2.fromOffset(170, 40),
		Color = C.Panel,
		StrokeColor = C.Event,
		StrokeThickness = 2,
		Radius = 16,
		Visible = false,
	})
	eventTokensLabel = UIKit.Label(eventTokensPill, "🎟️ 0", { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), TextSize = 20, Font = Theme.Fonts.Title, Color = C.Event, Stroke = 2, XAlign = Enum.TextXAlignment.Center })
end

---------------------------------------------------------------- buttons
local function navButton(parent: Instance, name: string, icon: string, label: string, color: string, order: number, size: number, onClick: () -> ()): TextButton
	local button = UIKit.Button(parent, {
		Name = name,
		Text = "",
		Style = color,
		Size = UDim2.fromOffset(size, size),
		LayoutOrder = order,
		Radius = 18,
		OnClick = onClick,
	})
	local iconLabel = button:FindFirstChild("Label") :: TextLabel
	iconLabel.Text = icon
	iconLabel.TextSize = size * 0.42
	iconLabel.Size = UDim2.new(1, 0, 0.72, 0)
	iconLabel.Position = UDim2.new()
	iconLabel.Font = Theme.Fonts.Body
	UIKit.Label(button, label, {
		Name = "Caption",
		Position = UDim2.new(0, 0, 0.66, 0),
		Size = UDim2.new(1, 0, 0.3, 0),
		TextSize = math.floor(size * 0.17),
		Font = Theme.Fonts.Title,
		XAlign = Enum.TextXAlignment.Center,
		Stroke = 2,
	})
	addBadge(button, name)
	HUD.Buttons[name] = button
	return button
end

local function buildNav()
	local nav = UIKit.new("Frame", {
		Name = "BottomNav",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(600, 90),
		BackgroundTransparency = 1,
		Parent = Root.HUD,
	})
	UIKit.List(nav, "X", 12, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom)
	local items = {
		{ "Collection", "🎴", "Cards", "Blue" },
		{ "Shop", "🛒", "Shop", "Primary" },
		{ "Rebirth", "♻️", "Rebirth", "Success" },
		{ "Quests", "📜", "Quests", "Purple" },
		{ "Index", "📖", "Index", "Blue" },
		{ "Settings", "⚙️", "Settings", "Secondary" },
	}
	for i, item in items do
		navButton(nav, item[1], item[2], item[3], item[4], i, 84, function()
			WindowManager.Toggle(item[1])
		end)
	end
	HUD.Nav = nav

	-- Two compact columns under the player card: stays clear of the mobile
	-- thumbstick (bottom-left) and the jump button (bottom-right).
	local side = UIKit.new("Frame", {
		Name = "SideButtons",
		Position = UDim2.fromOffset(12, 96),
		Size = UDim2.fromOffset(140, 300),
		BackgroundTransparency = 1,
		Parent = Root.HUD,
	})
	UIKit.Grid(side, Vector2.new(62, 62), Vector2.new(8, 8))
	local function travel(target: string)
		return function()
			local response = Net.Request("QuickTravel", target)
			if not response.Ok then
				Notifications.Toast(response.Message or "Can't travel right now", "Error")
			end
		end
	end
	navButton(side, "Rewards", "🎁", "Rewards", "Danger", 1, 62, function()
		WindowManager.Toggle("Rewards")
	end)
	navButton(side, "Leaderboard", "🏆", "Ranks", "Primary", 2, 62, function()
		WindowManager.Toggle("Leaderboard")
	end)
	navButton(side, "Players", "👥", "Players", "Blue", 3, 62, function()
		WindowManager.Toggle("Players")
	end)
	navButton(side, "Store", "💎", "Store", "Purple", 4, 62, function()
		WindowManager.Open("Shop", { Tab = "Robux" })
	end)
	navButton(side, "Home", "🏠", "Base", "Success", 5, 62, travel("Home"))
	navButton(side, "Hub", "🏙️", "Hub", "Secondary", 6, 62, travel("Hub"))
	local elite = navButton(side, "Elite", "👑", "Elite", "Primary", 7, 62, travel("Elite"))
	elite.Visible = false
	local admin = navButton(side, "Admin", "🛠️", "Admin", "Danger", 8, 62, function()
		WindowManager.Toggle("Admin")
	end)
	admin.Visible = false
end

---------------------------------------------------------------- dynamic rows
local function activeEvents(): { any }
	local ok, list = pcall(HttpService.JSONDecode, HttpService, ReplicatedStorage:GetAttribute("ActiveEvents") or "[]")
	return if ok and type(list) == "table" then list else {}
end
HUD.ActiveEvents = activeEvents

local function rebuildBoosts()
	UIKit.Clear(boostRow)
	local now = workspace:GetServerTimeNow()
	local boosts = State.Data.Boosts or {}
	local order = 0
	for _, name in BoostConfig.Order do
		local expiry = boosts[name]
		if expiry and expiry > now then
			order += 1
			local info = BoostConfig.Personal[name]
			UIKit.Chip(boostRow, info.Icon .. " " .. Format.Clock(expiry - now), info.Color:Lerp(Color3.new(0, 0, 0), 0.35), { Size = UDim2.fromOffset(96, 26), LayoutOrder = order })
		end
	end
	local serverLuck = ReplicatedStorage:GetAttribute("ServerLuckExpires") or 0
	if serverLuck > now then
		order += 1
		UIKit.Chip(boostRow, "🌟 Server x2 " .. Format.Clock(serverLuck - now), Color3.fromRGB(160, 120, 20), { Size = UDim2.fromOffset(150, 26), LayoutOrder = order })
	end
	for _, key in { "Luck", "Income" } do
		local mult = ReplicatedStorage:GetAttribute("Admin" .. key) or 1
		if mult ~= 1 then
			order += 1
			UIKit.Chip(boostRow, "🛠️ " .. key .. " x" .. tostring(mult), Color3.fromRGB(150, 40, 60), { Size = UDim2.fromOffset(130, 26), LayoutOrder = order })
		end
	end
end

local eventChips: { [string]: TextButton } = {}

local function rebuildEvents()
	local now = workspace:GetServerTimeNow()
	local events = activeEvents()
	local anyCurrency = nil
	local seen = {}
	for i, entry in events do
		local def = EventConfig.Events[entry.Id]
		if def then
			seen[entry.Id] = true
			if def.Currency and not anyCurrency then
				anyCurrency = def.Currency
			end
			local chipButton = eventChips[entry.Id]
			if not chipButton then
				chipButton = UIKit.Button(eventRow, {
					Text = "",
					Style = "Ghost",
					Size = UDim2.fromOffset(250, 28),
					TextSize = 14,
					Silent = true,
					OnClick = function()
						WindowManager.Open("Shop", { Tab = "Event" })
					end,
				})
				local stroke = chipButton:FindFirstChild("StyleStroke") :: UIStroke?
				if stroke then
					stroke.Color = def.Color
				end
				eventChips[entry.Id] = chipButton
			end
			chipButton.LayoutOrder = i
			UIKit.SetButtonText(chipButton, string.format("%s %s · %s", def.Icon, def.Name, Format.Time(math.max(0, entry.EndsAt - now))))
		end
	end
	for id, chipButton in eventChips do
		if not seen[id] then
			chipButton:Destroy()
			eventChips[id] = nil
		end
	end
	eventTokensPill.Visible = #events > 0 or (State.Data.EventTokens or 0) > 0
	local currency = anyCurrency or EventConfig.DefaultCurrency
	eventTokensLabel.Text = currency.Icon .. " " .. Format.Abbreviate(State.Data.EventTokens or 0)
end

---------------------------------------------------------------- badges
function HUD.UpdateBadges()
	local data = State.Data
	if not data.Quests then
		return
	end
	-- Quests
	local questCount = 0
	for _, q in data.Quests.Daily or {} do
		if not q.Claimed and q.Progress >= q.Target then
			questCount += 1
		end
	end
	for _, series in QuestConfig.Achievements do
		local entry = data.Quests.Lifetime and data.Quests.Lifetime[series.Id]
		local tier = series.Tiers[(entry and entry.Claimed or 0) + 1]
		if entry and tier and entry.Progress >= tier.Target then
			questCount += 1
		end
	end
	HUD.SetBadge("Quests", questCount)
	-- Rebirth
	HUD.SetBadge("Rebirth", if (data.Cash or 0) >= Economy.RebirthCost(data.Rebirths or 0) then 1 else 0)
	-- Rewards
	local rewards = 0
	local today = TimeUtil.DayNumber(math.floor(workspace:GetServerTimeNow()))
	if data.Daily and data.Daily.LastDay ~= today then
		rewards += 1
	end
	local playtime = data.Playtime or {}
	for _, milestone in RewardConfig.Playtime do
		if playtime.Day == today and not (playtime.Claimed or {})[tostring(milestone.Minutes)] and (playtime.Today or 0) >= milestone.Minutes * 60 then
			rewards += 1
		end
	end
	HUD.SetBadge("Rewards", rewards)
	-- Index milestones
	local discovered = 0
	for id in data.Collection or {} do
		local def = Catalog.Get(id)
		if def and not def.Limited then
			discovered += 1
		end
	end
	local milestones = 0
	for _, m in RewardConfig.CollectionMilestones do
		if not (data.CollectionClaimed or {})[tostring(m.Percent)] and discovered >= math.ceil(Catalog.CompletionTotal * m.Percent / 100) then
			milestones += 1
		end
	end
	HUD.SetBadge("Index", milestones)
end

---------------------------------------------------------------- start
function HUD.Start()
	buildTop()
	buildNav()

	State.On("Cash", function(value)
		targetCash = value or 0
		HUD.UpdateBadges()
	end)
	State.On("CashPerSec", function(value)
		cpsLabel.Text = "+" .. Format.PerSec(value or 0)
	end)
	State.On("Tokens", function(value)
		tokensLabel.Text = Format.Abbreviate(value or 0)
		UIKit.Pop(tokensLabel.Parent :: GuiObject, 0.08)
	end)
	State.On("EventTokens", function()
		rebuildEvents()
	end)
	State.On("Rebirths", function(value)
		rebirthLabel.Text = "♻️ Rebirth " .. tostring(value or 0) .. "  ·  " .. Format.Multiplier(Economy.RebirthMultiplier(value or 0)) .. " income"
		HUD.Buttons.Elite.Visible = (value or 0) >= 1
		HUD.UpdateBadges()
	end)
	State.On("PersonalLuck", function(value)
		luckLabel.Text = "🍀 Luck " .. Format.Multiplier(value or 1)
	end)
	for _, key in { "Quests", "Daily", "Playtime", "Collection", "CollectionClaimed" } do
		State.On(key, function()
			HUD.UpdateBadges()
		end)
	end
	State.On("Boosts", rebuildBoosts)
	State.LoadedSignal:Connect(function()
		HUD.Buttons.Admin.Visible = State.Server.IsAdmin == true
		if State.Server.UsingMockData then
			Notifications.Toast("Studio: DataStores unavailable — progress won't save. Enable API access in Game Settings.", "Warning")
		end
	end)
	if State.Loaded then
		HUD.Buttons.Admin.Visible = State.Server.IsAdmin == true
	end
	ReplicatedStorage:GetAttributeChangedSignal("ActiveEvents"):Connect(rebuildEvents)

	-- Smooth cash counter (satisfying count-up)
	RunService.RenderStepped:Connect(function(dt)
		if math.abs(displayedCash - targetCash) < 0.5 then
			if displayedCash ~= targetCash then
				displayedCash = targetCash
				cashLabel.Text = Format.Cash(displayedCash)
			end
			return
		end
		local increasing = targetCash > displayedCash
		displayedCash += (targetCash - displayedCash) * math.min(1, dt * 8)
		cashLabel.Text = Format.Cash(displayedCash)
		cashLabel.TextColor3 = if increasing then C.Cash else Color3.fromRGB(255, 160, 160)
	end)

	-- Timers
	task.spawn(function()
		while true do
			rebuildBoosts()
			rebuildEvents()
			HUD.UpdateBadges()
			task.wait(1)
		end
	end)
end

-- Flies coins from a screen point to the cash counter.
function HUD.FlyCash(fromScreen: Vector2?, amount: number)
	local canvas = Root.Canvas
	local target = HUD.CashPill
	if not target then
		return
	end
	local virtualFrom = if fromScreen then fromScreen / Root.Scale else Root.VirtualSize / 2 + Vector2.new(0, 120)
	local targetPos = (target.AbsolutePosition + target.AbsoluteSize / 2 - Root.Canvas.AbsolutePosition) / Root.Scale
	for i = 1, math.clamp(math.floor(math.log10(math.max(amount, 10)) * 2), 3, 12) do
		local coin = UIKit.Label(canvas, "🪙", {
			Size = UDim2.fromOffset(30, 30),
			Position = UDim2.fromOffset(virtualFrom.X + math.random(-40, 40), virtualFrom.Y + math.random(-30, 30)),
			AnchorPoint = Vector2.new(0.5, 0.5),
			TextSize = 26,
			XAlign = Enum.TextXAlignment.Center,
		})
		coin.ZIndex = 20
		task.delay(i * 0.04, function()
			local tween = UIKit.Tween(coin, 0.55, { Position = UDim2.fromOffset(targetPos.X, targetPos.Y), TextTransparency = 0.3 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tween.Completed:Wait()
			coin:Destroy()
		end)
	end
	task.delay(0.6, function()
		UIKit.Pop(target, 0.12)
	end)
end

return HUD
