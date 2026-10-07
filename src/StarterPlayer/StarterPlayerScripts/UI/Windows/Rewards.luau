--[[
	Rewards window — 7-day login streak and daily playtime milestones.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RewardConfig = require(Shared.Config.RewardConfig)
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
Window.Title = "Rewards"
Window.Icon = "🎁"
Window.Color = Color3.fromRGB(230, 70, 90)
Window.IsOpen = false

local body: Frame
local playtimeBars: { { Bar: any, Minutes: number } } = {}

local function now(): number
	return math.floor(workspace:GetServerTimeNow())
end

local function render()
	UIKit.Clear(body)
	table.clear(playtimeBars)
	local data = State.Data
	local today = TimeUtil.DayNumber(now())
	local daily = data.Daily or { LastDay = 0, Streak = 0 }
	local claimedToday = daily.LastDay == today
	local continues = daily.LastDay == today - 1
	local nextStreak = if claimedToday then daily.Streak elseif continues then daily.Streak + 1 else 1
	local dayIndex = ((nextStreak - 1) % #RewardConfig.Daily) + 1
	local cps = State.Session.CashPerSec or 0

	UIKit.Label(body, string.format("📅 Daily streak: %d day%s", daily.Streak, if daily.Streak == 1 then "" else "s"), { Size = UDim2.new(1, 0, 0, 30), TextSize = 24, Font = Theme.Fonts.Title, Color = C.Accent, Stroke = 2 })
	local strip = UIKit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 0, 150), Parent = body })
	local layout = UIKit.List(strip, "X", 8, Enum.HorizontalAlignment.Center)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	for day, rewards in RewardConfig.Daily do
		local isNext = day == dayIndex
		local past = day < dayIndex or (claimedToday and day == dayIndex)
		local tile = UIKit.Panel(strip, {
			Size = UDim2.fromOffset(108, 146),
			Color = if isNext and not claimedToday then C.PanelHover else C.PanelLight,
			StrokeColor = if past then C.Success elseif isNext then C.Accent else C.Stroke,
			StrokeThickness = if isNext then 3 else 2,
			Radius = 14,
			LayoutOrder = day,
		})
		UIKit.Label(tile, "Day " .. day, { Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 24), TextSize = 19, Font = Theme.Fonts.Title, XAlign = Enum.TextXAlignment.Center, Stroke = 1 })
		UIKit.Label(tile, if past then "✅" else RewardFormat.Icon(rewards[1]), { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 40), TextSize = 32, XAlign = Enum.TextXAlignment.Center })
		local lines = {}
		for _, reward in rewards do
			table.insert(lines, RewardFormat.Describe(reward, cps))
		end
		UIKit.Label(tile, table.concat(lines, "\n"), { Position = UDim2.fromOffset(4, 72), Size = UDim2.new(1, -8, 0, 70), TextSize = 12, Color = C.SubText, XAlign = Enum.TextXAlignment.Center, YAlign = Enum.TextYAlignment.Top, Wrapped = true })
	end
	local claimButton = UIKit.Button(body, {
		Text = if claimedToday then ("Next reward in " .. Format.Time(TimeUtil.SecondsUntilNextDay(now()))) else ("🎁 Claim Day " .. nextStreak),
		Style = "Primary",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 192),
		Size = UDim2.fromOffset(320, 50),
		OnClick = function()
			Notifications.Result(Net.Request("ClaimDaily"))
		end,
	})
	UIKit.SetButtonEnabled(claimButton, not claimedToday)

	UIKit.Label(body, "⏰ Playtime rewards (reset daily)", { Position = UDim2.fromOffset(0, 254), Size = UDim2.new(1, 0, 0, 28), TextSize = 21, Font = Theme.Fonts.Title, Stroke = 2 })
	local list = UIKit.Scroll(body, { Position = UDim2.fromOffset(0, 286), Size = UDim2.new(1, 0, 1, -286), Padding = 6 })
	local playtime = data.Playtime or {}
	local played = if playtime.Day == today then (playtime.Today or 0) else 0
	for i, milestone in RewardConfig.Playtime do
		local claimed = playtime.Day == today and (playtime.Claimed or {})[tostring(milestone.Minutes)] == true
		local ready = played >= milestone.Minutes * 60
		local row = UIKit.Panel(list, { Size = UDim2.new(1, -6, 0, 56), Color = C.PanelLight, Radius = 12, LayoutOrder = i, StrokeColor = if claimed then C.Success elseif ready then C.Accent else C.Stroke })
		UIKit.Label(row, (if milestone.Minutes >= 60 then (milestone.Minutes / 60 .. "h") else (milestone.Minutes .. "m")), { Position = UDim2.fromOffset(12, 0), Size = UDim2.fromOffset(60, 56), TextSize = 22, Font = Theme.Fonts.Title, Stroke = 1 })
		UIKit.Label(row, RewardFormat.DescribeList(milestone.Rewards, cps), { Position = UDim2.fromOffset(78, 6), Size = UDim2.new(1, -300, 0, 20), TextSize = 14, Color = C.Accent })
		local bar = UIKit.ProgressBar(row, { Position = UDim2.fromOffset(78, 30), Size = UDim2.new(1, -300, 0, 18), Color = C.Blue, TextSize = 12 })
		bar:Set(played / (milestone.Minutes * 60), Format.Time(math.min(played, milestone.Minutes * 60)) .. " / " .. Format.Time(milestone.Minutes * 60))
		table.insert(playtimeBars, { Bar = bar, Minutes = milestone.Minutes })
		local button = UIKit.Button(row, {
			Text = if claimed then "✅ Claimed" elseif ready then "Claim!" else "Keep playing",
			Style = if ready and not claimed then "Primary" else "Secondary",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(200, 42),
			TextSize = 17,
			OnClick = function()
				Notifications.Result(Net.Request("ClaimPlaytime", i))
			end,
		})
		UIKit.SetButtonEnabled(button, ready and not claimed, "Secondary")
	end
end

function Window.Build(b: Frame)
	body = b
	for _, key in { "Daily" } do
		State.On(key, function()
			if Window.IsOpen then
				render()
			end
		end)
	end
	-- Playtime updates every 10s: re-render only when a milestone state flips.
	local lastSignature = ""
	State.On("Playtime", function(playtime)
		if not Window.IsOpen or not playtime then
			return
		end
		local parts = {}
		for _, m in RewardConfig.Playtime do
			table.insert(parts, tostring((playtime.Claimed or {})[tostring(m.Minutes)]) .. tostring((playtime.Today or 0) >= m.Minutes * 60))
		end
		local signature = table.concat(parts, ",")
		if signature ~= lastSignature then
			lastSignature = signature
			render()
		else
			for _, ref in playtimeBars do
				local total = ref.Minutes * 60
				ref.Bar:Set((playtime.Today or 0) / total, Format.Time(math.min(playtime.Today or 0, total)) .. " / " .. Format.Time(total))
			end
		end
	end)
end

function Window.Open()
	Window.IsOpen = true
	render()
end

function Window.Close()
	Window.IsOpen = false
end

return Window
