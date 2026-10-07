--[[
	Players window — everyone in the server. Inspect their base and stats,
	teleport to visit their base, or send a trade / gift request.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Util.Format)
local Economy = require(Shared.Economy)
local Net = require(Shared.Net)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local UIKit = require(UI.UIKit)
local CardView = require(UI.CardView)
local Notifications = require(UI.Notifications)
local WindowManager = require(UI.WindowManager)

local C = Theme.Colors

local Window = {}
Window.Title = "Players"
Window.Icon = "👥"
Window.Color = Color3.fromRGB(60, 150, 240)
Window.IsOpen = false

local list: ScrollingFrame
local detail: Frame

local function visit(userId: number)
	local response = Net.Request("VisitBase", userId)
	if response.Ok then
		WindowManager.Close()
	else
		Notifications.Toast(response.Message or "Can't visit right now", "Error")
	end
end

local function inspect(userId: number)
	UIKit.Clear(detail)
	UIKit.Label(detail, "Loading...", { Size = UDim2.new(1, 0, 0, 30), TextSize = 18, Color = C.SubText })
	local response = Net.Request("InspectPlayer", userId)
	UIKit.Clear(detail)
	if not response.Ok or type(response.Data) ~= "table" then
		UIKit.Label(detail, response.Message or "Player not found", { Size = UDim2.new(1, 0, 0, 30), TextSize = 18, Color = C.Danger })
		return
	end
	local info = response.Data
	UIKit.Label(detail, info.Name, { Size = UDim2.new(1, 0, 0, 32), TextSize = 26, Font = Theme.Fonts.Title, Color = C.Accent, Stroke = 2 })
	UIKit.Label(detail, string.format("💸 %s   ♻️ Rebirth %d   📖 %d discovered   🦹 %d steals   🛡️ %d catches   🏠 Base Lv %d",
		Format.PerSec(info.CashPerSec or 0), info.Rebirths or 0, info.Collection or 0, info.Steals or 0, info.Catches or 0, info.BaseLevel or 1), {
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = 14,
		Color = C.SubText,
		Wrapped = true,
	})
	local buttons = UIKit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 78), Size = UDim2.new(1, 0, 0, 44), Parent = detail })
	UIKit.List(buttons, "X", 8)
	UIKit.Button(buttons, { Text = "🏠 Visit base", Style = "Blue", Size = UDim2.fromOffset(160, 44), TextSize = 17, LayoutOrder = 1, OnClick = function()
		visit(userId)
	end })
	UIKit.Button(buttons, { Text = "🤝 Trade", Style = "Success", Size = UDim2.fromOffset(140, 44), TextSize = 17, LayoutOrder = 2, OnClick = function()
		Notifications.Result(Net.Request("TradeRequest", userId))
	end })
	local grid = UIKit.Scroll(detail, { Position = UDim2.fromOffset(0, 130), Size = UDim2.new(1, 0, 1, -130), Layout = "Grid", CellSize = Vector2.new(96, 134), Padding = 8 })
	table.sort(info.Items, function(a, b)
		return Economy.ItemIncome(a) > Economy.ItemIncome(b)
	end)
	for i, item in info.Items do
		CardView.Create(grid, { Id = item.Id, Mutation = item.Mutation, Trait = item.Trait, Level = item.Level, Serial = item.Serial }, { LayoutOrder = i })
	end
	if #info.Items == 0 then
		UIKit.Label(grid, "No critters on display.", { TextSize = 16, Color = C.SubText, Size = UDim2.new(1, 0, 0, 30) })
	end
end

local function renderList()
	UIKit.Clear(list)
	local others = {}
	for _, p in Players:GetPlayers() do
		if p ~= Players.LocalPlayer then
			table.insert(others, p)
		end
	end
	table.sort(others, function(a, b)
		return (a:GetAttribute("CashPerSec") or 0) > (b:GetAttribute("CashPerSec") or 0)
	end)
	if #others == 0 then
		UIKit.Label(list, "You're the only one here right now. Invite friends to steal from... I mean, trade with!", { TextSize = 16, Color = C.SubText, Wrapped = true, Size = UDim2.new(1, -6, 0, 70) })
	end
	for i, p in others do
		local row = UIKit.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.PanelLight, Size = UDim2.new(1, -6, 0, 62), LayoutOrder = i, Selectable = true, Parent = list })
		UIKit.Corner(row, 12)
		UIKit.Stroke(row, C.Stroke, 2)
		local avatar = UIKit.new("ImageLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 7), Size = UDim2.fromOffset(48, 48), Parent = row })
		UIKit.Corner(avatar, 24)
		task.spawn(function()
			local ok, image = pcall(Players.GetUserThumbnailAsync, Players, p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
			if ok and avatar.Parent then
				avatar.Image = image
			end
		end)
		UIKit.Label(row, p.DisplayName, { Position = UDim2.fromOffset(64, 6), Size = UDim2.new(1, -72, 0, 24), TextSize = 18, Font = Theme.Fonts.Title, Stroke = 1 })
		UIKit.Label(row, string.format("%s · ♻️ %d", Format.PerSec(p:GetAttribute("CashPerSec") or 0), p:GetAttribute("Rebirths") or 0), { Position = UDim2.fromOffset(64, 32), Size = UDim2.new(1, -72, 0, 20), TextSize = 14, Color = C.Cash })
		row.Activated:Connect(function()
			inspect(p.UserId)
		end)
	end
end

function Window.Build(body: Frame)
	list = UIKit.Scroll(body, { Size = UDim2.new(0.34, 0, 1, 0), Padding = 6 })
	detail = UIKit.Panel(body, { Position = UDim2.new(0.36, 0, 0, 0), Size = UDim2.new(0.64, 0, 1, 0), Color = C.PanelDark, Radius = 14 })
	UIKit.Padding(detail, 12)
	Players.PlayerAdded:Connect(function()
		if Window.IsOpen then
			renderList()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		if Window.IsOpen then
			task.defer(renderList)
		end
	end)
end

function Window.Open(args)
	Window.IsOpen = true
	renderList()
	if args and args.UserId then
		inspect(args.UserId)
	else
		UIKit.Clear(detail)
		UIKit.Label(detail, "Pick a player to inspect their base.", { Size = UDim2.fromScale(1, 1), TextSize = 18, XAlign = Enum.TextXAlignment.Center, Color = C.SubText })
	end
end

function Window.Close()
	Window.IsOpen = false
end

return Window
