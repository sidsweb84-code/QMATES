--[[
	Tutorial (client)
	Small, non-blocking onboarding card + a guidance beam and marker that
	point at the next objective. Progress is decided by the server.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapConfig = require(Shared.Config.MapConfig)
local Net = require(Shared.Net)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local UIKit = require(UI.UIKit)
local Root = require(UI.Root)
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)
local Effects = require(script.Parent.Effects)

local C = Theme.Colors
local player = Players.LocalPlayer

local Tutorial = {}
Tutorial.Enabled = true

local STEPS = {
	{ Title = "Claim your base", Text = "Stand on the glowing pad in your base and press the prompt to claim it." },
	{ Title = "Buy your first critter", Text = "Walk to the conveyor and buy a critter you can afford." },
	{ Title = "Place it", Text = "Watch your new critter walk home and take its pedestal!" },
	{ Title = "Collect your cash", Text = "Critters earn money every second. Step on the gold collector pad in your base." },
	{ Title = "Upgrade your base", Text = "Open the Shop ➜ Upgrades and buy any upgrade (more slots or security)." },
	{ Title = "Try stealing", Text = "Visit another player's base and hold the Steal prompt on a critter, then run home! (Skip if you're alone.)" },
	{ Title = "Protect your base", Text = "Press the red LOCK button near your entrance to keep thieves out." },
}

local card: Frame
local titleLabel: TextLabel
local textLabel: TextLabel
local stepLabel: TextLabel
local markerPart: BasePart? = nil
local beam: Beam? = nil

local function myPlotOrigin(): CFrame?
	local index = player:GetAttribute("PlotIndex")
	return index and MapConfig.PlotOrigins[index] or nil
end

local function nearestConveyorItem(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local world = Workspace:FindFirstChild("World")
	local conveyors = world and world:FindFirstChild("Conveyors")
	local main = conveyors and conveyors:FindFirstChild("Main")
	local items = main and main:FindFirstChild("Items")
	if not items or not root then
		return MapConfig.Conveyors.Main.Start:Lerp(MapConfig.Conveyors.Main.End, 0.5)
	end
	local best, bestDistance = nil, math.huge
	local cash = State.Data.Cash or 0
	for _, model in items:GetChildren() do
		if model:IsA("Model") and model.PrimaryPart and (model:GetAttribute("Price") or math.huge) <= cash then
			local d = (model.PrimaryPart.Position - root.Position).Magnitude
			if d < bestDistance then
				best, bestDistance = model.PrimaryPart.Position, d
			end
		end
	end
	return best or MapConfig.Conveyors.Main.Start:Lerp(MapConfig.Conveyors.Main.End, 0.5)
end

local function otherBase(): Vector3?
	local world = Workspace:FindFirstChild("World")
	local plots = world and world:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, plot in plots:GetChildren() do
		local owner = plot:GetAttribute("OwnerUserId")
		if owner and owner ~= 0 and owner ~= player.UserId then
			local origin = MapConfig.PlotOrigins[plot:GetAttribute("PlotIndex")]
			return origin and (origin * CFrame.new(0, 2, -MapConfig.Plot.Size.Z / 2 - 4)).Position
		end
	end
	return nil
end

local function targetFor(step: number): Vector3?
	local origin = myPlotOrigin()
	if step == 1 then
		return origin and (origin * CFrame.new(MapConfig.Plot.Spawn)).Position
	elseif step == 2 then
		return nearestConveyorItem()
	elseif step == 3 then
		return origin and (origin * CFrame.new(0, 2, 0)).Position
	elseif step == 4 then
		return origin and (origin * CFrame.new(MapConfig.Plot.CollectPad)).Position
	elseif step == 5 then
		return origin and (origin * CFrame.new(MapConfig.Plot.Terminals[1].Position)).Position
	elseif step == 6 then
		return otherBase()
	elseif step == 7 then
		return origin and (origin * CFrame.new(MapConfig.Plot.LockTerminal)).Position
	end
	return nil
end

local function ensureGuide()
	if markerPart then
		return
	end
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one * 0.2
	part.Parent = Workspace.CurrentCamera
	markerPart = part
	local gui = UIKit.new("BillboardGui", {
		Size = UDim2.fromOffset(90, 90),
		AlwaysOnTop = true,
		StudsOffset = Vector3.new(0, 6, 0),
		LightInfluence = 0,
		Adornee = part,
		Parent = part,
	})
	UIKit.Label(gui, "▼", { Size = UDim2.fromScale(1, 1), TextSize = 64, Font = Theme.Fonts.Title, XAlign = Enum.TextXAlignment.Center, Color = C.Accent, Stroke = 4 })
	local a1 = Instance.new("Attachment")
	a1.Parent = part
	local b = Instance.new("Beam")
	b.Attachment1 = a1
	b.Color = ColorSequence.new(C.Accent, Color3.fromRGB(255, 255, 255))
	b.Width0 = 0.6
	b.Width1 = 0.6
	b.FaceCamera = true
	b.LightEmission = 1
	b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.8) })
	b.Parent = part
	beam = b
end

local function clearGuide()
	if markerPart then
		markerPart:Destroy()
	end
	markerPart, beam = nil, nil
end

local function refresh()
	local tutorial = State.Data.Tutorial
	local settings = State.Data.Settings or {}
	if not tutorial or tutorial.Done or settings.ShowTutorial == false or not Tutorial.Enabled then
		card.Visible = false
		clearGuide()
		return
	end
	local step = STEPS[tutorial.Step]
	if not step then
		card.Visible = false
		clearGuide()
		return
	end
	card.Visible = true
	stepLabel.Text = string.format("GETTING STARTED  %d/%d", tutorial.Step, #STEPS)
	titleLabel.Text = step.Title
	textLabel.Text = step.Text
	UIKit.Pop(card, 0.06)
end

function Tutorial.Start()
	card = UIKit.Panel(Root.HUD, {
		Name = "Tutorial",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 110),
		Size = UDim2.fromOffset(300, 150),
		Color = C.Panel,
		StrokeColor = C.Accent,
		StrokeThickness = 3,
		Radius = 16,
		Visible = false,
	})
	stepLabel = UIKit.Label(card, "", { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 16), TextSize = 13, Color = C.Accent })
	titleLabel = UIKit.Label(card, "", { Position = UDim2.fromOffset(14, 24), Size = UDim2.new(1, -28, 0, 26), TextSize = 21, Font = Theme.Fonts.Title, Stroke = 2 })
	textLabel = UIKit.Label(card, "", { Position = UDim2.fromOffset(14, 52), Size = UDim2.new(1, -28, 0, 58), TextSize = 14, Wrapped = true, Color = C.SubText, YAlign = Enum.TextYAlignment.Top })
	UIKit.Button(card, {
		Text = "Skip step",
		Style = "Secondary",
		Position = UDim2.new(0, 14, 1, -38),
		Size = UDim2.fromOffset(120, 30),
		TextSize = 14,
		OnClick = function()
			Net.Request("TutorialSkip", "Step")
		end,
	})
	UIKit.Button(card, {
		Text = "Skip tutorial",
		Style = "Ghost",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 1, -38),
		Size = UDim2.fromOffset(130, 30),
		TextSize = 14,
		OnClick = function()
			Net.Request("TutorialSkip", "All")
		end,
	})

	State.On("Tutorial", function()
		refresh()
	end)
	State.On("Settings", function()
		refresh()
	end)
	Net.On(Net.Events.Effect, function(name)
		if name == "TutorialStep" then
			Sound.Play("QuestComplete")
			Effects.Confetti(20)
		end
	end)

	-- Guidance update
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.25 then
			return
		end
		accumulator = 0
		if not card.Visible then
			clearGuide()
			return
		end
		local target = targetFor(State.Data.Tutorial and State.Data.Tutorial.Step or 0)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not target or not root then
			clearGuide()
			return
		end
		ensureGuide()
		if markerPart then
			markerPart.Position = target
		end
		local a0 = root:FindFirstChild("TutorialAttachment") :: Attachment?
		if not a0 then
			a0 = Instance.new("Attachment")
			a0.Name = "TutorialAttachment"
			a0.Parent = root
		end
		if beam then
			beam.Attachment0 = a0
		end
	end)
end

return Tutorial
