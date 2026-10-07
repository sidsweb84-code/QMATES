--[[
	Settings window — music, SFX, graphics quality, reduce motion, card labels,
	UI size, tutorial. Saved to your profile on the server (validated).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local ContentConfig = require(Shared.Config.ContentConfig)
local Net = require(Shared.Net)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local UIKit = require(UI.UIKit)
local State = require(UI.Parent.Controllers.State)

local C = Theme.Colors

local Window = {}
Window.Title = "Settings"
Window.Icon = "⚙️"
Window.Color = Color3.fromRGB(90, 100, 160)
Window.IsOpen = false

-- Set by ClientMain: applies settings locally.
Window.Apply = function(_settings) end

local body: ScrollingFrame

local function save(key: string, value: any)
	local settings = table.clone(State.Data.Settings or {})
	settings[key] = value
	State.Data.Settings = settings
	Window.Apply(settings)
	task.spawn(Net.Request, "SaveSettings", { [key] = value })
end

local function rowFrame(order: number, title: string, description: string): Frame
	local row = UIKit.Panel(body, { Size = UDim2.new(1, -6, 0, 64), Color = C.PanelLight, Radius = 12, LayoutOrder = order })
	UIKit.Label(row, title, { Position = UDim2.fromOffset(16, 8), Size = UDim2.new(0.6, 0, 0, 26), TextSize = 19, Font = Theme.Fonts.Title, Stroke = 1 })
	UIKit.Label(row, description, { Position = UDim2.fromOffset(16, 34), Size = UDim2.new(0.6, 0, 0, 20), TextSize = 13, Color = C.SubText })
	return row
end

local function toggle(order: number, key: string, title: string, description: string)
	local row = rowFrame(order, title, description)
	local value = (State.Data.Settings or {})[key]
	UIKit.Button(row, {
		Text = if value then "ON" else "OFF",
		Style = if value then "Success" else "Secondary",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(120, 44),
		OnClick = function()
			save(key, not (State.Data.Settings or {})[key])
			Window.Open()
		end,
	})
end

local function choice(order: number, key: string, title: string, description: string, options: { string })
	local row = rowFrame(order, title, description)
	local holder = UIKit.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(#options * 106, 44), Parent = row })
	UIKit.List(holder, "X", 6, Enum.HorizontalAlignment.Right)
	local current = (State.Data.Settings or {})[key]
	for i, option in options do
		UIKit.Button(holder, {
			Text = option,
			Style = if current == option then "Blue" else "Ghost",
			Size = UDim2.fromOffset(100, 44),
			TextSize = 16,
			LayoutOrder = i,
			OnClick = function()
				save(key, option)
				Window.Open()
			end,
		})
	end
end

function Window.Build(b: Frame)
	body = UIKit.Scroll(b, { Padding = 8 })
end

function Window.Open()
	Window.IsOpen = true
	UIKit.Clear(body)
	toggle(1, "Music", "🎵 Music", "Background music (add a track in SoundConfig)")
	toggle(2, "SFX", "🔊 Sound effects", "Purchases, reveals, alarms and UI sounds")
	choice(3, "Graphics", "✨ Graphics", "Low disables particles and idle animations", { "Low", "Medium", "High" })
	toggle(4, "ReduceMotion", "🌀 Reduce motion", "Disables camera shake and FOV punches")
	toggle(5, "CardLabels", "🎴 Floating cards", "Show card labels above critters in the world")
	choice(6, "UIScale", "🔍 Interface size", "Make menus smaller or larger", { "Small", "Normal", "Large" })
	toggle(7, "ShowTutorial", "🎓 Tutorial tips", "Show the getting-started panel")
	local footer = UIKit.Panel(body, { Size = UDim2.new(1, -6, 0, 96), Color = C.PanelDark, Radius = 12, LayoutOrder = 10 })
	UIKit.Padding(footer, 10)
	local mock = if State.Server.UsingMockData then "\n⚠️ Studio test mode: DataStores unavailable, progress is NOT saved." else ""
	UIKit.Label(footer, string.format("%s v%s · All creatures are original characters.%s", ContentConfig.Title(), GameConfig.Version, mock), {
		Size = UDim2.fromScale(1, 1),
		TextSize = 13,
		Color = C.Muted,
		Wrapped = true,
		YAlign = Enum.TextYAlignment.Top,
	})
end

function Window.Close()
	Window.IsOpen = false
end

return Window
