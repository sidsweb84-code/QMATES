--[[
	Quests window — daily quests (with a free reroll) and achievements.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestConfig = require(Shared.Config.QuestConfig)
local Format = require(Shared.Util.Format)
local RewardFormat = require(Shared.Util.RewardFormat)
local TimeUtil = require(Shared.Util.TimeUtil)
local Net = require(Shared.Net)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local UIKit = require(UI.UIKit)
local Notifications = require(UI.Notifications)
local State = require(UI.Parent.Controllers.State)

local C = Theme.Colors

local Window = {}
Window.Title = "Quests"
Window.Icon = "📜"
Window.Color = Color3.fromRGB(150, 90, 240)
Window.IsOpen = false

local content: Frame
local tabs: UIKit.Tabs
local currentTab = "Daily"

local bars: { [string]: { Bar: any, Kind: string, Key: any } } = {}
local signature = ""

local poolById = {}
for _, q in QuestConfig.DailyPool do
	poolById[q.Id] = q
end

local function questText(def, target: number): string
	local n = if def.Action == "Earn" then Format.Cash(target) else Format.Abbreviate(target)
	return (string.gsub(def.Text, "{n}", n))
end

local function progressText(def, progress: number, target: number): string
	if def.Action == "Earn" then
		return Format.Cash(progress) .. " / " .. Format.Cash(target)
	end
	return Format.Abbreviate(math.floor(progress)) .. " / " .. Format.Abbreviate(target)
end

local function renderDaily()
	local quests = State.Data.Quests or {}
	local cps = State.Session.CashPerSec or 0
	local resetIn = TimeUtil.SecondsUntilNextDay(math.floor(workspace:GetServerTimeNow()))
	local rerollsLeft = QuestConfig.FreeRerollsPerDay - (quests.Rerolls or 0)
	UIKit.Label(content, string.format("New quests in %s  ·  Free rerolls left: %d", Format.Time(resetIn), math.max(0, rerollsLeft)), { Size = UDim2.new(1, 0, 0, 24), TextSize = 16, Color = C.SubText })
	local list = UIKit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 1, -32), Parent = content })
	UIKit.List(list, "Y", 10)
	for i, q in quests.Daily or {} do
		local def = poolById[q.Id]
		if not def then
			continue
		end
		local complete = q.Progress >= q.Target
		local row = UIKit.Panel(list, { Size = UDim2.new(1, 0, 0, 112), Color = C.PanelLight, Radius = 14, StrokeColor = if q.Claimed then C.Success elseif complete then C.Accent else C.Stroke, StrokeThickness = 2.5, LayoutOrder = i })
		UIKit.Label(row, questText(def, q.Target), { Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -230, 0, 28), TextSize = 21, Font = Theme.Fonts.Title, Stroke = 2 })
		UIKit.Label(row, "Rewards: " .. RewardFormat.DescribeList(def.Rewards, cps), { Position = UDim2.fromOffset(16, 40), Size = UDim2.new(1, -230, 0, 20), TextSize = 14, Color = C.Accent })
		local bar = UIKit.ProgressBar(row, { Position = UDim2.fromOffset(16, 68), Size = UDim2.new(1, -230, 0, 28), Color = if complete then C.Success else C.Blue })
		bar:Set(q.Progress / q.Target, progressText(def, q.Progress, q.Target))
		bars["d" .. i] = { Bar = bar, Kind = "Daily", Key = i }
		local claim = UIKit.Button(row, {
			Text = if q.Claimed then "✅ Claimed" elseif complete then "Claim!" else "In progress",
			Style = if complete and not q.Claimed then "Primary" else "Secondary",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, 12),
			Size = UDim2.fromOffset(190, 46),
			OnClick = function()
				Notifications.Result(Net.Request("ClaimQuest", i))
			end,
		})
		UIKit.SetButtonEnabled(claim, complete and not q.Claimed, "Secondary")
		if not q.Claimed and not complete and rerollsLeft > 0 then
			UIKit.Button(row, {
				Text = "🎲 Reroll",
				Style = "Ghost",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -14, 0, 64),
				Size = UDim2.fromOffset(190, 36),
				TextSize = 16,
				OnClick = function()
					Notifications.Result(Net.Request("RerollQuest", i))
				end,
			})
		end
	end
end

local function renderAchievements()
	local scroll = UIKit.Scroll(content, { Padding = 8 })
	local lifetime = (State.Data.Quests or {}).Lifetime or {}
	local cps = State.Session.CashPerSec or 0
	for i, series in QuestConfig.Achievements do
		local entry = lifetime[series.Id] or { Progress = 0, Claimed = 0 }
		local tier = series.Tiers[entry.Claimed + 1]
		local row = UIKit.Panel(scroll, { Size = UDim2.new(1, -6, 0, 96), Color = C.PanelLight, Radius = 14, StrokeColor = C.Stroke, LayoutOrder = i })
		UIKit.Label(row, series.Icon, { Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(56, 96), TextSize = 38, XAlign = Enum.TextXAlignment.Center })
		local tierText = if tier then string.format("Tier %d/%d", entry.Claimed + 1, #series.Tiers) else "COMPLETE"
		UIKit.Label(row, series.Name .. "  ·  " .. tierText, { Position = UDim2.fromOffset(70, 8), Size = UDim2.new(1, -290, 0, 26), TextSize = 20, Font = Theme.Fonts.Title, Stroke = 2 })
		if tier then
			local target = tier.Target
			local n = if series.Stat == "TotalEarned" then Format.Cash(target) else Format.Abbreviate(target)
			UIKit.Label(row, (string.gsub(series.Text, "{n}", n)) .. "  —  " .. RewardFormat.DescribeList(tier.Rewards, cps), { Position = UDim2.fromOffset(70, 34), Size = UDim2.new(1, -290, 0, 18), TextSize = 13, Color = C.SubText })
			local bar = UIKit.ProgressBar(row, { Position = UDim2.fromOffset(70, 58), Size = UDim2.new(1, -290, 0, 24), Color = C.Purple })
			local progressText = if series.Stat == "TotalEarned" then (Format.Cash(entry.Progress) .. " / " .. Format.Cash(target)) else (Format.Abbreviate(math.floor(entry.Progress)) .. " / " .. Format.Abbreviate(target))
			bar:Set(entry.Progress / target, progressText)
			bars["a" .. series.Id] = { Bar = bar, Kind = "Achievement", Key = series }
			local ready = entry.Progress >= target
			local button = UIKit.Button(row, {
				Text = if ready then "Claim!" else "Locked",
				Style = "Primary",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -14, 0.5, 0),
				Size = UDim2.fromOffset(190, 50),
				OnClick = function()
					Notifications.Result(Net.Request("ClaimAchievement", series.Id))
				end,
			})
			UIKit.SetButtonEnabled(button, ready)
		else
			UIKit.Label(row, "🏆 All tiers complete!", { Position = UDim2.fromOffset(70, 40), Size = UDim2.new(1, -90, 0, 24), TextSize = 17, Color = C.Success })
		end
	end
end

-- Changes only when something becomes claimable / claimed / rerolled.
local function computeSignature(): string
	local quests = State.Data.Quests or {}
	local parts = { currentTab, tostring(quests.Rerolls) }
	for _, q in quests.Daily or {} do
		table.insert(parts, q.Id .. tostring(q.Claimed) .. tostring(q.Progress >= q.Target))
	end
	for _, series in QuestConfig.Achievements do
		local entry = (quests.Lifetime or {})[series.Id] or { Progress = 0, Claimed = 0 }
		local tier = series.Tiers[entry.Claimed + 1]
		table.insert(parts, tostring(entry.Claimed) .. tostring(tier ~= nil and entry.Progress >= tier.Target))
	end
	return table.concat(parts, "|")
end

local function updateBars()
	local quests = State.Data.Quests or {}
	for _, ref in bars do
		if ref.Kind == "Daily" then
			local q = (quests.Daily or {})[ref.Key]
			local def = q and poolById[q.Id]
			if q and def then
				ref.Bar:Set(q.Progress / q.Target, progressText(def, q.Progress, q.Target))
			end
		else
			local series = ref.Key
			local entry = (quests.Lifetime or {})[series.Id] or { Progress = 0, Claimed = 0 }
			local tier = series.Tiers[entry.Claimed + 1]
			if tier then
				local text = if series.Stat == "TotalEarned" then (Format.Cash(entry.Progress) .. " / " .. Format.Cash(tier.Target)) else (Format.Abbreviate(math.floor(entry.Progress)) .. " / " .. Format.Abbreviate(tier.Target))
				ref.Bar:Set(entry.Progress / tier.Target, text)
			end
		end
	end
end

local function render()
	table.clear(bars)
	signature = computeSignature()
	UIKit.Clear(content)
	if currentTab == "Daily" then
		renderDaily()
	else
		renderAchievements()
	end
end

function Window.Build(body: Frame)
	tabs = UIKit.Tabs(body, {
		{ Id = "Daily", Text = "📅 Daily" },
		{ Id = "Achievements", Text = "🏆 Achievements" },
	}, function(id)
		currentTab = id
		render()
	end, { ButtonWidth = 170 })
	content = UIKit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 1, -50), Parent = body })
	State.On("Quests", function()
		if Window.IsOpen then
			if computeSignature() ~= signature then
				render()
			else
				updateBars()
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
