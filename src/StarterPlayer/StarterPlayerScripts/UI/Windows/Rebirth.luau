--[[
	Rebirth window — shows exactly what you gain, what resets and what you keep.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local RebirthConfig = require(Config.RebirthConfig)
local Catalog = require(Shared.Catalog)
local Economy = require(Shared.Economy)
local Format = require(Shared.Util.Format)
local RewardFormat = require(Shared.Util.RewardFormat)
local Net = require(Shared.Net)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local UIKit = require(UI.UIKit)
local Notifications = require(UI.Notifications)
local State = require(UI.Parent.Controllers.State)

local C = Theme.Colors

local Window = {}
Window.Title = "Rebirth"
Window.Icon = "♻️"
Window.Color = Color3.fromRGB(40, 190, 110)
Window.IsOpen = false

local body: Frame
local progressBar: any = nil
local rebirthButton: GuiObject? = nil

local function render()
	UIKit.Clear(body)
	local data = State.Data
	local rebirths = data.Rebirths or 0
	local nextCount = rebirths + 1
	local cost = Economy.RebirthCost(rebirths)
	local cash = data.Cash or 0

	local left = UIKit.Panel(body, { Size = UDim2.new(0.48, 0, 1, 0), Color = C.PanelDark, Radius = 16 })
	UIKit.Padding(left, 16)
	UIKit.List(left, "Y", 8)
	UIKit.Label(left, "Rebirth " .. rebirths .. "  ➜  " .. nextCount, { TextSize = 32, Font = Theme.Fonts.Title, Color = C.Success, LayoutOrder = 1, Stroke = 2, Size = UDim2.new(1, 0, 0, 40) })
	UIKit.Label(left, string.format("💸 Income %s  ➜  %s", Format.Multiplier(Economy.RebirthMultiplier(rebirths)), Format.Multiplier(Economy.RebirthMultiplier(nextCount))), { TextSize = 19, LayoutOrder = 2, Color = C.Cash })
	UIKit.Label(left, string.format("🍀 Luck bonus +%d%%  ➜  +%d%%", Economy.RebirthLuckBonus(rebirths) * 100, Economy.RebirthLuckBonus(nextCount) * 100), { TextSize = 19, LayoutOrder = 3, Color = C.Blue })
	UIKit.Label(left, string.format("🪙 +%d tokens  ·  start with %s", Economy.RebirthTokens(nextCount), Format.Cash(Economy.RebirthStartingCash(nextCount))), { TextSize = 17, LayoutOrder = 4, Color = C.Token })
	local bar = UIKit.ProgressBar(left, { Size = UDim2.new(1, 0, 0, 34), Color = C.Success, LayoutOrder = 5, TextSize = 17 })
	bar:Set(cash / cost, Format.Cash(cash) .. " / " .. Format.Cash(cost))
	progressBar = bar
	local kept = Economy.KeptCollectiblesAt(nextCount)
	UIKit.Label(left, "Resets: cash and your critters" .. (if kept > 0 then (" (you KEEP your best " .. kept .. ")") else "") .. ".\nKeeps: base level, security upgrades, tokens, cosmetics, collection book and stats.", {
		TextSize = 15,
		LayoutOrder = 6,
		Color = C.SubText,
		Wrapped = true,
		AutoSize = true,
		Size = UDim2.new(1, 0, 0, 0),
	})
	local button = UIKit.Button(left, {
		Text = "♻️ REBIRTH",
		Style = "Success",
		Size = UDim2.new(1, 0, 0, 60),
		TextSize = 28,
		LayoutOrder = 7,
		OnClick = function()
			Notifications.Confirm("Rebirth?", string.format("You'll reset your cash and critters%s for a permanent %s income multiplier.", if kept > 0 then (" (keeping your best " .. kept .. ")") else "", Format.Multiplier(Economy.RebirthMultiplier(nextCount))), "Rebirth!", function()
				Notifications.Result(Net.Request("Rebirth"))
			end)
		end,
	})
	UIKit.SetButtonEnabled(button, cash >= cost)
	rebirthButton = button

	local right = UIKit.Panel(body, { Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, 0, 1, 0), Color = C.PanelDark, Radius = 16 })
	UIKit.Padding(right, 14)
	local scroll = UIKit.Scroll(right, { Padding = 6 })
	UIKit.Label(scroll, "🔓 Unlocks & milestones", { TextSize = 21, Font = Theme.Fonts.Title, LayoutOrder = 0, Stroke = 2 })
	local entries = {}
	for _, area in RebirthConfig.Areas do
		table.insert(entries, { Rebirths = area.RequiredRebirths, Text = "👑 " .. area.Name .. " (better conveyor)" })
	end
	for _, def in Catalog.All do
		if def.RequiredRebirths > 0 then
			table.insert(entries, { Rebirths = def.RequiredRebirths, Text = "🎴 Can buy " .. def.Name .. " (" .. def.Rarity .. ")" })
		end
	end
	for key, rewards in RebirthConfig.Milestones do
		table.insert(entries, { Rebirths = tonumber(key) or 0, Text = "🎁 " .. RewardFormat.DescribeList(rewards) })
	end
	for _, entry in RebirthConfig.KeepBestCollectibles do
		table.insert(entries, { Rebirths = entry.Rebirths, Text = "💎 Keep your best " .. entry.Count .. " critter(s) when rebirthing" })
	end
	table.sort(entries, function(a, b)
		return a.Rebirths < b.Rebirths
	end)
	for i, entry in entries do
		local done = rebirths >= entry.Rebirths
		local label = UIKit.Label(scroll, string.format("%s R%d — %s", if done then "✅" else "▫️", entry.Rebirths, entry.Text), {
			TextSize = 15,
			LayoutOrder = i,
			Color = if done then C.Success else C.Text,
			Wrapped = true,
			AutoSize = true,
		})
		label.Size = UDim2.new(1, -8, 0, 0)
	end
end

function Window.Build(b: Frame)
	body = b
	State.On("Rebirths", function()
		if Window.IsOpen then
			render()
		end
	end)
	State.On("Cash", function(cash)
		if Window.IsOpen and progressBar and rebirthButton then
			local cost = Economy.RebirthCost(State.Data.Rebirths or 0)
			progressBar:Set((cash or 0) / cost, Format.Cash(cash or 0) .. " / " .. Format.Cash(cost))
			UIKit.SetButtonEnabled(rebirthButton, (cash or 0) >= cost)
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
