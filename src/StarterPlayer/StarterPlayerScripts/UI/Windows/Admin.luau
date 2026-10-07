--[[
	Admin console — only shown to admins (server decides who is an admin and
	re-checks every command). Type commands or use the quick buttons.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local UIKit = require(UI.UIKit)

local C = Theme.Colors

local Window = {}
Window.Title = "Admin Console"
Window.Icon = "🛠️"
Window.Color = Color3.fromRGB(200, 50, 70)
Window.IsOpen = false

local output: ScrollingFrame? = nil
local input: TextBox
local lineCount = 0
local pending: { { Lines: { string }, Color: Color3? } } = {}

local function print(lines: { string }, color: Color3?)
	if not output then
		table.insert(pending, { Lines = lines, Color = color })
		return
	end
	local out = output :: ScrollingFrame
	for _, line in lines do
		lineCount += 1
		local label = UIKit.Label(out, line, { TextSize = 14, Font = Enum.Font.Code, Color = color or C.Text, Wrapped = true, AutoSize = true, LayoutOrder = lineCount })
		label.Size = UDim2.new(1, -8, 0, 0)
	end
	task.defer(function()
		out.CanvasPosition = Vector2.new(0, math.huge)
	end)
end

local function run(command: string)
	if command == "" then
		return
	end
	print({ "> " .. command }, C.Accent)
	local response = Net.Request("AdminCommand", command)
	if response.Ok then
		print(if type(response.Data) == "table" then response.Data else { "OK" })
	else
		print({ response.Message or "Failed" }, C.Danger)
	end
end

function Window.Build(body: Frame)
	local quick = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 84), Parent = body })
	local layout = UIKit.Grid(quick, Vector2.new(160, 38), Vector2.new(6, 6))
	layout.CellSize = UDim2.fromOffset(160, 38)
	local commands = {
		{ "Help", "/help" },
		{ "+$1M", "/givecash me 1m" },
		{ "+500 tokens", "/givetokens me 500" },
		{ "Spawn Secret", "/spawn galaxitty Rainbow Jackpot" },
		{ "Legendary Rush", "/event start LegendaryRush 10" },
		{ "Luck x5 (10m)", "/setluck 5 10" },
		{ "Recent logs", "/logs all 20" },
		{ "Run tests", "/runtests" },
		{ "Security report", "/report all" },
		{ "Reset cooldowns", "/resetcooldowns" },
	}
	for i, c in commands do
		UIKit.Button(quick, { Text = c[1], Style = "Secondary", TextSize = 14, LayoutOrder = i, OnClick = function()
			run(c[2])
		end })
	end
	UIKit.Panel(body, { Position = UDim2.fromOffset(0, 92), Size = UDim2.new(1, 0, 1, -146), Color = C.PanelDark, Radius = 10 })
	output = UIKit.Scroll(body, { Position = UDim2.fromOffset(0, 92), Size = UDim2.new(1, 0, 1, -146), Padding = 2 })
	input = UIKit.new("TextBox", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, -130, 0, 46),
		BackgroundColor3 = C.PanelLight,
		Text = "",
		PlaceholderText = "/givecash me 1m   ·   /giveitem me solarion Golden   ·   /event start Halloween 30",
		PlaceholderColor3 = C.Muted,
		TextColor3 = C.Text,
		TextSize = 16,
		Font = Enum.Font.Code,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Parent = body,
	})
	UIKit.Corner(input, 10)
	UIKit.Padding(input, 0, 10, 0, 10)
	input.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			run(input.Text)
			input.Text = ""
		end
	end)
	UIKit.Button(body, {
		Text = "Run",
		Style = "Danger",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		Size = UDim2.fromOffset(120, 46),
		OnClick = function()
			run(input.Text)
			input.Text = ""
		end,
	})
	for _, entry in pending do
		print(entry.Lines, entry.Color)
	end
	table.clear(pending)
end

-- Chat-typed admin commands send their output here even before the console is opened.
function Window.Init()
	Net.On(Net.Events.AdminOutput, function(lines)
		if type(lines) == "table" then
			print(lines)
		end
	end)
end

function Window.Open()
	Window.IsOpen = true
end

function Window.Close()
	Window.IsOpen = false
end

return Window
