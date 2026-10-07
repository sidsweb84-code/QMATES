--[[
	LoadingScreen
	Custom loading screen shown until the game is loaded AND the server has
	loaded this player's data (Player attribute "DataLoaded").
]]

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

local TITLE = "STEAL A CRITTER"
local TIPS = {
	"Tip: Rarer critters earn way more — but take longer to steal!",
	"Tip: Lock your base when a thief shows up. Get close to catch them!",
	"Tip: Mutations like Golden and Rainbow multiply income.",
	"Tip: Rebirth for a permanent income multiplier.",
	"Tip: All odds are shown in the Index → Odds tab.",
	"Tip: Stand on your gold collector pad to collect cash.",
}

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.ResetOnSpawn = false
gui.Parent = playerGui

local background = Instance.new("Frame")
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.fromRGB(18, 20, 44)
background.Parent = gui
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new(Color3.fromRGB(70, 60, 170), Color3.fromRGB(15, 15, 35))
gradient.Rotation = 90
gradient.Parent = background

local card = Instance.new("Frame")
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.42)
card.Size = UDim2.fromScale(0.12, 0.3)
card.BackgroundColor3 = Color3.new(1, 1, 1)
card.Parent = background
local ratio = Instance.new("UIAspectRatioConstraint")
ratio.AspectRatio = 0.72
ratio.Parent = card
local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0.08, 0)
cardCorner.Parent = card
local cardGradient = Instance.new("UIGradient")
cardGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
	ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 210, 70)),
	ColorSequenceKeypoint.new(0.66, Color3.fromRGB(90, 180, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 100, 255)),
})
cardGradient.Rotation = 45
cardGradient.Parent = card
local cardStroke = Instance.new("UIStroke")
cardStroke.Thickness = 4
cardStroke.Color = Color3.new(1, 1, 1)
cardStroke.Parent = card
local question = Instance.new("TextLabel")
question.BackgroundTransparency = 1
question.Size = UDim2.fromScale(1, 1)
question.Text = "?"
question.TextScaled = true
question.Font = Enum.Font.FredokaOne
question.TextColor3 = Color3.new(1, 1, 1)
question.Parent = card

local function label(text: string, y: number, height: number, font: Enum.Font, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = UDim2.fromScale(0.5, y)
	l.Size = UDim2.fromScale(0.8, height)
	l.Text = text
	l.TextScaled = true
	l.Font = font
	l.TextColor3 = color
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(10, 10, 30)
	stroke.Parent = l
	l.Parent = background
	return l
end

label(TITLE, 0.62, 0.09, Enum.Font.FredokaOne, Color3.fromRGB(255, 214, 90))
local status = label("Loading the critters...", 0.73, 0.04, Enum.Font.GothamBold, Color3.new(1, 1, 1))
local tip = label(TIPS[math.random(1, #TIPS)], 0.84, 0.035, Enum.Font.GothamMedium, Color3.fromRGB(190, 195, 235))

local start = os.clock()
local spin = RunService.RenderStepped:Connect(function(dt)
	card.Rotation = math.sin((os.clock() - start) * 2) * 8
	cardGradient.Rotation = (cardGradient.Rotation + dt * 90) % 360
end)

task.spawn(function()
	while gui.Parent do
		task.wait(3)
		tip.Text = TIPS[math.random(1, #TIPS)]
	end
end)

if not game:IsLoaded() then
	game.Loaded:Wait()
end
status.Text = "Loading your collection..."
local deadline = os.clock() + 45
while not player:GetAttribute("DataLoaded") and os.clock() < deadline do
	task.wait(0.2)
end
status.Text = "Let's go!"
task.wait(0.4)

local fade = TweenInfo.new(0.6)
for _, d in background:GetDescendants() do
	if d:IsA("TextLabel") then
		TweenService:Create(d, fade, { TextTransparency = 1 }):Play()
	elseif d:IsA("UIStroke") then
		TweenService:Create(d, fade, { Transparency = 1 }):Play()
	elseif d:IsA("Frame") then
		TweenService:Create(d, fade, { BackgroundTransparency = 1 }):Play()
	end
end
TweenService:Create(background, fade, { BackgroundTransparency = 1 }):Play()
task.wait(0.65)
spin:Disconnect()
gui:Destroy()
