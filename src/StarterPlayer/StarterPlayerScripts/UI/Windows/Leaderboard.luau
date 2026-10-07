--[[
	Leaderboard window — server (live) and global (all servers) rankings for
	cash/sec, cash, rebirths, collection, rare finds, steals and playtime.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Util.Format)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local UIKit = require(UI.UIKit)

local C = Theme.Colors

local Window = {}
Window.Title = "Leaderboards"
Window.Icon = "🏆"
Window.Color = Color3.fromRGB(230, 170, 30)
Window.IsOpen = false

local STATS = {
	{ Key = "CashPerSec", Name = "Cash/sec", Attribute = "CashPerSec", Format = "PerSec" },
	{ Key = "Cash", Name = "Cash", Attribute = "Cash", Format = "Cash" },
	{ Key = "Rebirths", Name = "Rebirths", Attribute = "Rebirths" },
	{ Key = "Collection", Name = "Collection", Attribute = "CollectionCount" },
	{ Key = "Rare", Name = "Rare Finds", Attribute = "RareFinds" },
	{ Key = "Steals", Name = "Steals", Attribute = "Steals" },
	{ Key = "Playtime", Name = "Playtime", Attribute = "Playtime", Format = "Hours" },
}

local list: ScrollingFrame
local scopeButton: TextButton
local currentStat = "CashPerSec"
local scope = "Server"

local function formatValue(stat, value: number): string
	if stat.Format == "PerSec" then
		return Format.PerSec(value)
	elseif stat.Format == "Cash" then
		return Format.Cash(value)
	elseif stat.Format == "Hours" then
		return string.format("%.1fh", value / 3600)
	end
	return Format.Abbreviate(value)
end

local function statByKey(key: string)
	for _, s in STATS do
		if s.Key == key then
			return s
		end
	end
	return STATS[1]
end

local function render()
	UIKit.Clear(list)
	local stat = statByKey(currentStat)
	local entries = {}
	if scope == "Server" then
		for _, p in Players:GetPlayers() do
			table.insert(entries, { Name = p.DisplayName, UserId = p.UserId, Value = p:GetAttribute(stat.Attribute) or 0 })
		end
		table.sort(entries, function(a, b)
			return a.Value > b.Value
		end)
	else
		local ok, boards = pcall(HttpService.JSONDecode, HttpService, ReplicatedStorage:GetAttribute("GlobalBoards") or "{}")
		entries = if ok and type(boards) == "table" and boards[stat.Key] then boards[stat.Key] else {}
	end
	if #entries == 0 then
		UIKit.Label(list, if scope == "Global" then "Global leaderboards update every few minutes (unavailable in Studio without API access)." else "No players yet.", { TextSize = 17, Color = C.SubText, Wrapped = true, Size = UDim2.new(1, 0, 0, 60) })
	end
	for i, entry in entries do
		local me = entry.UserId == Players.LocalPlayer.UserId
		local row = UIKit.Panel(list, { Size = UDim2.new(1, -6, 0, 50), Color = if me then C.PanelHover else C.PanelLight, Radius = 12, LayoutOrder = i, StrokeColor = if i == 1 then C.Accent elseif me then C.Blue else nil })
		local medal = if i == 1 then "🥇" elseif i == 2 then "🥈" elseif i == 3 then "🥉" else ("#" .. i)
		UIKit.Label(row, medal, { Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(56, 50), TextSize = 22, Font = Theme.Fonts.Title, XAlign = Enum.TextXAlignment.Center })
		local avatar = UIKit.new("ImageLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(70, 5), Size = UDim2.fromOffset(40, 40), Parent = row })
		UIKit.Corner(avatar, 20)
		if entry.UserId and entry.UserId > 0 then
			task.spawn(function()
				local okThumb, image = pcall(Players.GetUserThumbnailAsync, Players, entry.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
				if okThumb and avatar.Parent then
					avatar.Image = image
				end
			end)
		end
		UIKit.Label(row, entry.Name or "?", { Position = UDim2.fromOffset(120, 0), Size = UDim2.new(1, -330, 1, 0), TextSize = 19, Font = Theme.Fonts.Title, Stroke = 1 })
		UIKit.Label(row, formatValue(stat, entry.Value or 0), { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 0), Size = UDim2.fromOffset(200, 50), TextSize = 19, Font = Theme.Fonts.Title, Color = C.Cash, XAlign = Enum.TextXAlignment.Right, Stroke = 1 })
	end
end

function Window.Build(body: Frame)
	local tabDefs = {}
	for _, s in STATS do
		table.insert(tabDefs, { Id = s.Key, Text = s.Name })
	end
	local tabScroll = UIKit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -150, 0, 44),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 3,
		Parent = body,
	})
	local tabs = UIKit.Tabs(tabScroll, tabDefs, function(id)
		currentStat = id
		render()
	end, { Size = UDim2.new(0, #STATS * 128, 0, 38), ButtonWidth = 120 })
	scopeButton = UIKit.Button(body, {
		Text = "🌍 Global",
		Style = "Purple",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(140, 38),
		TextSize = 17,
		OnClick = function()
			scope = if scope == "Server" then "Global" else "Server"
			UIKit.SetButtonText(scopeButton, if scope == "Server" then "🌍 Global" else "🖥️ Server")
			render()
		end,
	})
	list = UIKit.Scroll(body, { Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 1, -52), Padding = 6 })
	tabs:Select(currentStat)
end

function Window.Open()
	Window.IsOpen = true
	render()
end

function Window.Close()
	Window.IsOpen = false
end

return Window
