--[[
	Steal (client)
	Thief: grab progress bar, then a carry countdown with a glowing beam
	pointing home. Victim: flashing alarm banner and a beam to the thief.
	Purely presentation — the server decides everything.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RarityConfig = require(Shared.Config.RarityConfig)
local Net = require(Shared.Net)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local UIKit = require(UI.UIKit)
local Root = require(UI.Root)
local Notifications = require(UI.Notifications)
local Sound = require(script.Parent.Sound)
local Effects = require(script.Parent.Effects)
local Interaction = require(script.Parent.Interaction)

local C = Theme.Colors
local player = Players.LocalPlayer

local Steal = {}

local panel: Frame
local titleLabel: TextLabel
local bar: UIKit.ProgressBar
local cancelButton: TextButton
local alert: Frame
local alertLabel: TextLabel

local mode: string? = nil -- "Grab" | "Carry"
local endsAt = 0
local startedAt = 0
local beam: Beam? = nil
local beamTargetPart: BasePart? = nil
local alertActive = false
local alertThief: number? = nil

local function clearBeam()
	if beam then
		beam:Destroy()
		beam = nil
	end
	if beamTargetPart then
		beamTargetPart:Destroy()
		beamTargetPart = nil
	end
end

local function beamTo(color: Color3)
	clearBeam()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local a0 = root:FindFirstChild("GuideAttachment") :: Attachment?
	if not a0 then
		a0 = Instance.new("Attachment")
		a0.Name = "GuideAttachment"
		a0.Parent = root
	end
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one * 0.2
	holder.Parent = Workspace.CurrentCamera
	beamTargetPart = holder
	local a1 = Instance.new("Attachment")
	a1.Parent = holder
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Color = ColorSequence.new(color)
	b.Width0 = 1.2
	b.Width1 = 1.2
	b.FaceCamera = true
	b.LightEmission = 1
	b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.6) })
	b.Parent = holder
	beam = b
end

local function showPanel(color: Color3)
	panel.Visible = true
	local stroke = panel:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = color
	end
	UIKit.Pop(panel, 0.15)
end

local function hidePanel()
	panel.Visible = false
	mode = nil
	Interaction.IsStealing = false
	clearBeam()
end

local function onSteal(payload)
	local state = payload.State
	if state == "Grab" then
		mode = "Grab"
		Interaction.IsStealing = true
		startedAt = workspace:GetServerTimeNow()
		endsAt = payload.EndsAt
		local rarity = RarityConfig.Rarities[payload.Rarity]
		titleLabel.Text = "🦹 Stealing " .. payload.Name .. " from " .. payload.Victim .. "..."
		titleLabel.TextColor3 = rarity and rarity.Color:Lerp(Color3.new(1, 1, 1), 0.3) or C.Text
		cancelButton.Visible = true
		showPanel(C.Warning)
		Sound.Play("StealStart")
	elseif state == "Carry" then
		mode = "Carry"
		Interaction.IsStealing = true
		startedAt = workspace:GetServerTimeNow()
		endsAt = payload.Deadline
		titleLabel.Text = "🏃 RUN HOME with " .. payload.Name .. "!"
		titleLabel.TextColor3 = C.Accent
		cancelButton.Visible = true
		showPanel(C.Danger)
		beamTo(Color3.fromRGB(255, 220, 90))
		if beamTargetPart and payload.Home then
			beamTargetPart.Position = payload.Home + Vector3.new(0, 3, 0)
		end
		Effects.FovPunch(6, 0.5)
		Sound.Play("RevealWhoosh", { Pitch = 1.3 })
	elseif state == "Success" then
		hidePanel()
		Sound.Sequence({ { "StealSuccess", 0 }, { "StealSuccess", 0.15, 1.25 }, { "RevealLegendary", 0.3, 1.1 } })
		Effects.Confetti(40)
		Notifications.Toast("🦹 You stole " .. payload.Name .. " from " .. payload.Victim .. "!", "Success")
	elseif state == "Fail" then
		hidePanel()
		Sound.Play(if payload.Caught or payload.Trap then "Caught" else "StealFail")
		if payload.Caught or payload.Trap then
			Effects.Shake(2, 0.5)
			Effects.Flash(Color3.fromRGB(255, 60, 60), 0.6, 0.4)
		end
		Notifications.Toast(payload.Reason or "Steal failed", "Error")
	elseif state == "Alert" then
		alertActive = true
		alertThief = payload.ThiefUserId
		alert.Visible = true
		alertLabel.Text = if payload.Phase == "Carry"
			then string.format("🏃 %s is running off with your %s! Catch them!", payload.Thief, payload.Name)
			else string.format("🚨 %s is stealing your %s! Get back to your base!", payload.Thief, payload.Name)
		UIKit.Pop(alert, 0.2)
		Effects.Flash(Color3.fromRGB(255, 40, 60), 0.5, 0.55)
		beamTo(Color3.fromRGB(255, 60, 80))
	elseif state == "AlertEnd" then
		alertActive = false
		alertThief = nil
		alert.Visible = false
		clearBeam()
		if payload.Result == "Caught" or payload.Result == "Trapped" then
			Sound.Play("Caught")
			Effects.Confetti(25)
		elseif payload.Result == "Stolen" then
			Sound.Play("StealFail", { Pitch = 0.8 })
		end
	end
end

function Steal.Start()
	panel = UIKit.Panel(Root.HUD, {
		Name = "StealPanel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -116),
		Size = UDim2.fromOffset(470, 92),
		Color = C.PanelDark,
		StrokeColor = C.Danger,
		StrokeThickness = 3,
		Radius = 18,
		Visible = false,
	})
	titleLabel = UIKit.Label(panel, "", { Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -80, 0, 30), TextSize = 21, Font = Theme.Fonts.Title, Stroke = 2 })
	bar = UIKit.ProgressBar(panel, { Position = UDim2.fromOffset(16, 46), Size = UDim2.new(1, -86, 0, 30), Color = C.Warning, TextSize = 16 })
	cancelButton = UIKit.Button(panel, {
		Text = "✕",
		Style = "Danger",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(50, 50),
		OnClick = function()
			Net.Request("CancelSteal")
		end,
	})

	alert = UIKit.Panel(Root.HUD, {
		Name = "TheftAlert",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 204),
		Size = UDim2.fromOffset(600, 56),
		Color = C.DangerDark,
		StrokeColor = Color3.new(1, 1, 1),
		StrokeThickness = 3,
		Radius = 18,
		Visible = false,
	})
	alertLabel = UIKit.Label(alert, "", { Size = UDim2.new(1, -24, 1, 0), Position = UDim2.fromOffset(12, 0), TextSize = 20, Font = Theme.Fonts.Title, XAlign = Enum.TextXAlignment.Center, Stroke = 2, Wrapped = true })

	Net.On(Net.Events.Steal, onSteal)

	RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		if mode then
			local total = math.max(endsAt - startedAt, 0.01)
			local remaining = math.max(0, endsAt - now)
			if mode == "Grab" then
				bar:Set(1 - remaining / total, string.format("Grabbing... %.1fs", remaining))
			else
				bar:Set(remaining / total, string.format("⏰ %.0fs left — get to your base!", remaining))
			end
		end
		if alertActive then
			alert.BackgroundColor3 = if math.floor(os.clock() * 4) % 2 == 0 then C.DangerDark else Color3.fromRGB(120, 10, 30)
			-- Point the victim's beam at the thief.
			local thief = alertThief and Players:GetPlayerByUserId(alertThief)
			local thiefRoot = thief and thief.Character and thief.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if thiefRoot and beamTargetPart then
				beamTargetPart.Position = thiefRoot.Position
			end
		end
	end)

	player.CharacterAdded:Connect(function()
		if mode then
			hidePanel()
		end
	end)
end

return Steal
