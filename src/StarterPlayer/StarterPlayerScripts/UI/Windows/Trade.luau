--[[
	Trade window — server-authoritative trading / gifting.
	Add up to 4 of your critters, both players press Ready, a short countdown
	runs, and any change resets Ready. Leave one side empty to gift.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Economy = require(Shared.Economy)
local Net = require(Shared.Net)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local UIKit = require(UI.UIKit)
local CardView = require(UI.CardView)
local Notifications = require(UI.Notifications)
local WindowManager = require(UI.WindowManager)
local State = require(UI.Parent.Controllers.State)

local C = Theme.Colors

local Window = {}
Window.Title = "Trade"
Window.Icon = "🤝"
Window.Color = Color3.fromRGB(40, 180, 120)
Window.IsOpen = false

local body: Frame
local tradeState: any = nil
local myOffer: { string } = {}

local function offerPanel(parent: Instance, title: string, items: { any }, ready: boolean, position: UDim2, mine: boolean)
	local panel = UIKit.Panel(parent, { Position = position, Size = UDim2.new(0.49, 0, 0, 220), Color = C.PanelDark, Radius = 14, StrokeColor = if ready then C.Success else C.Stroke, StrokeThickness = if ready then 3 else 2 })
	UIKit.Label(panel, title .. (if ready then "  ✅ READY" else ""), { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 26), TextSize = 19, Font = Theme.Fonts.Title, Color = if ready then C.Success else C.Text, Stroke = 1 })
	local row = UIKit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 38), Size = UDim2.new(1, -20, 1, -46), Parent = panel })
	UIKit.List(row, "X", 8)
	for i, item in items do
		CardView.Create(row, { Id = item.Id, Mutation = item.Mutation, Trait = item.Trait, Level = item.Level, Serial = item.Serial }, {
			Size = UDim2.fromOffset(96, 134),
			LayoutOrder = i,
			OnClick = if mine then function()
				local index = table.find(myOffer, item.Uid)
				if index then
					table.remove(myOffer, index)
					Notifications.Result(Net.Request("TradeSetItems", myOffer))
				end
			end else nil,
		})
	end
	if #items == 0 then
		UIKit.Label(row, if mine then "Click your critters below to offer them." else "Nothing offered (gift)", { Size = UDim2.new(1, 0, 1, 0), TextSize = 15, Color = C.Muted, Wrapped = true })
	end
end

local function render()
	UIKit.Clear(body)
	if not tradeState then
		UIKit.Label(body, "No active trade. Open the Players menu to send a request.", { Size = UDim2.fromScale(1, 1), TextSize = 18, XAlign = Enum.TextXAlignment.Center, Color = C.SubText })
		return
	end
	myOffer = {}
	for _, item in tradeState.MyOffer do
		table.insert(myOffer, item.Uid)
	end
	offerPanel(body, "Your offer", tradeState.MyOffer, tradeState.MyReady, UDim2.new(), true)
	offerPanel(body, tradeState.Partner.Name .. "'s offer", tradeState.TheirOffer, tradeState.TheirReady, UDim2.new(0.51, 0, 0, 0), false)

	local status = if tradeState.CountdownEndsAt then "Trading in a moment..." else "Both players must press Ready. Any change resets Ready."
	local statusLabel = UIKit.Label(body, status, { Position = UDim2.fromOffset(0, 226), Size = UDim2.new(0.6, 0, 0, 44), TextSize = 16, Color = C.SubText, Wrapped = true })
	UIKit.Button(body, {
		Text = if tradeState.MyReady then "Not ready" else "✅ Ready",
		Style = if tradeState.MyReady then "Secondary" else "Success",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -150, 0, 226),
		Size = UDim2.fromOffset(150, 44),
		OnClick = function()
			Notifications.Result(Net.Request("TradeReady", not tradeState.MyReady))
		end,
	})
	UIKit.Button(body, {
		Text = "Cancel",
		Style = "Danger",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 226),
		Size = UDim2.fromOffset(140, 44),
		OnClick = function()
			Net.Request("TradeCancel")
		end,
	})
	if tradeState.CountdownEndsAt then
		task.spawn(function()
			while statusLabel.Parent and tradeState and tradeState.CountdownEndsAt do
				local left = math.max(0, tradeState.CountdownEndsAt - workspace:GetServerTimeNow())
				statusLabel.Text = string.format("⏳ Trading in %.1fs — press Not ready to stop!", left)
				task.wait(0.1)
			end
		end)
	end

	UIKit.Label(body, "Your critters (favourites can't be traded):", { Position = UDim2.fromOffset(0, 278), Size = UDim2.new(1, 0, 0, 22), TextSize = 15, Color = C.SubText })
	local grid = UIKit.Scroll(body, { Position = UDim2.fromOffset(0, 302), Size = UDim2.new(1, 0, 1, -302), Layout = "Grid", CellSize = Vector2.new(86, 120), Padding = 6 })
	local items = {}
	for _, item in State.Data.Inventory or {} do
		if not item.Locked and not table.find(myOffer, item.Uid) then
			table.insert(items, item)
		end
	end
	table.sort(items, function(a, b)
		return Economy.ItemIncome(a) > Economy.ItemIncome(b)
	end)
	for i, item in items do
		CardView.Create(grid, { Id = item.Id, Mutation = item.Mutation, Trait = item.Trait, Level = item.Level, Serial = item.Serial }, {
			LayoutOrder = i,
			OnClick = function()
				if #myOffer >= GameConfig.Trading.MaxItemsPerSide then
					Notifications.Toast("You can offer up to " .. GameConfig.Trading.MaxItemsPerSide .. " critters", "Warning")
					return
				end
				local offer = table.clone(myOffer)
				table.insert(offer, item.Uid)
				Notifications.Result(Net.Request("TradeSetItems", offer))
			end,
		})
	end
end

function Window.Build(b: Frame)
	body = b
end

-- Network listeners must exist before the window is ever opened.
function Window.Init()
	Net.On(Net.Events.Trade, function(payload)
		if payload.State == "Request" then
			Notifications.Choice("Trade request", payload.From .. " wants to trade with you.", "Accept", "Decline", function(accept)
				local response = Net.Request("TradeRespond", payload.FromUserId, accept)
				if not response.Ok and response.Message then
					Notifications.Toast(response.Message, "Error")
				end
			end)
		elseif payload.State == "Update" then
			tradeState = payload
			if WindowManager.Current ~= "Trade" then
				WindowManager.Open("Trade")
			else
				render()
			end
		elseif payload.State == "Complete" or payload.State == "Closed" then
			tradeState = nil
			Notifications.Toast(payload.Reason or "Trade closed", if payload.State == "Complete" then "Success" else "Info")
			if WindowManager.Current == "Trade" then
				WindowManager.Close()
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
	if tradeState then
		Net.Request("TradeCancel")
		tradeState = nil
	end
end

return Window
