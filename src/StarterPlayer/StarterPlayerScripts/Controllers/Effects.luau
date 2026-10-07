--[[
	Effects
	Client-only juice: camera shake / FOV punch, screen flashes and tints,
	floating world text, UI particle bursts and confetti. Respects the
	Reduce Motion and Graphics settings.
]]

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Root = require(script.Parent.Parent.UI.Root)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local Effects = {}

Effects.ReduceMotion = false
Effects.Graphics = "High"

local camera = Workspace.CurrentCamera
local shakeIntensity = 0
local shakeUntil = 0
local baseFov = 70
local fovTween: Tween? = nil

local colorCorrection = Instance.new("ColorCorrectionEffect")
colorCorrection.Name = "ClientRevealGrade"
colorCorrection.Enabled = false
colorCorrection.Parent = Lighting
local blur = Instance.new("BlurEffect")
blur.Name = "ClientRevealBlur"
blur.Size = 0
blur.Enabled = false
blur.Parent = Lighting

RunService:BindToRenderStep("StealCrittersShake", Enum.RenderPriority.Camera.Value + 1, function()
	if shakeIntensity <= 0 or os.clock() > shakeUntil then
		return
	end
	local remaining = (shakeUntil - os.clock())
	local i = shakeIntensity * math.min(1, remaining * 3)
	local offset = CFrame.Angles(math.rad((math.random() - 0.5) * i), math.rad((math.random() - 0.5) * i), 0)
	camera = Workspace.CurrentCamera
	camera.CFrame = camera.CFrame * offset
end)

function Effects.Shake(intensity: number, duration: number)
	if Effects.ReduceMotion then
		return
	end
	shakeIntensity = math.max(shakeIntensity * (if os.clock() < shakeUntil then 1 else 0), intensity)
	shakeUntil = os.clock() + duration
end

function Effects.FovPunch(amount: number, duration: number)
	if Effects.ReduceMotion then
		return
	end
	camera = Workspace.CurrentCamera
	if fovTween then
		fovTween:Cancel()
	end
	camera.FieldOfView = baseFov - amount
	fovTween = UIKit.Tween(camera, duration, { FieldOfView = baseFov }, Enum.EasingStyle.Back)
end

function Effects.Flash(color: Color3, duration: number, startTransparency: number?)
	local flash = UIKit.new("Frame", {
		BackgroundColor3 = color,
		BackgroundTransparency = startTransparency or 0.15,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
		Parent = Root.FX,
	})
	local tween = UIKit.Tween(flash, duration, { BackgroundTransparency = 1 })
	tween.Completed:Once(function()
		flash:Destroy()
	end)
end

function Effects.Tint(tint: Color3, saturation: number, duration: number)
	colorCorrection.Enabled = true
	colorCorrection.TintColor = tint
	colorCorrection.Saturation = saturation
	colorCorrection.Contrast = 0.1
	task.delay(duration, function()
		UIKit.Tween(colorCorrection, 0.6, { TintColor = Color3.new(1, 1, 1), Saturation = 0, Contrast = 0 })
		task.wait(0.65)
		colorCorrection.Enabled = false
	end)
end

function Effects.Blur(size: number, duration: number)
	blur.Enabled = true
	UIKit.Tween(blur, 0.3, { Size = size })
	task.delay(duration, function()
		UIKit.Tween(blur, 0.4, { Size = 0 })
		task.wait(0.45)
		blur.Enabled = false
	end)
end

-- Floating text above a world position (e.g. "+$1.2K" over the collector pad).
function Effects.FloatingText(position: Vector3, text: string, color: Color3?, size: number?)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.Position = position
	anchor.Parent = Workspace.CurrentCamera
	local gui = UIKit.new("BillboardGui", {
		Size = UDim2.fromOffset(240, 60),
		AlwaysOnTop = true,
		LightInfluence = 0,
		StudsOffset = Vector3.new(0, 2, 0),
		Adornee = anchor,
		Parent = anchor,
	})
	local label = UIKit.Label(gui, text, {
		Size = UDim2.fromScale(1, 1),
		TextSize = size or 34,
		Font = Enum.Font.FredokaOne,
		Color = color or Color3.fromRGB(130, 255, 150),
		XAlign = Enum.TextXAlignment.Center,
		Stroke = 3,
	})
	UIKit.Tween(gui, 1.4, { StudsOffset = Vector3.new(0, 7, 0) }, Enum.EasingStyle.Quad)
	task.delay(0.7, function()
		UIKit.Tween(label, 0.7, { TextTransparency = 1 })
	end)
	task.delay(1.45, function()
		anchor:Destroy()
	end)
end

-- UI particle burst in the scaled overlay (virtual coordinates).
function Effects.Burst(parent: Instance, center: Vector2, color: Color3, count: number?, distance: number?)
	if Effects.Graphics == "Low" then
		count = math.min(count or 16, 6)
	end
	for _ = 1, count or 16 do
		local size = math.random(6, 14)
		local dot = UIKit.new("Frame", {
			BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), math.random() * 0.5),
			Size = UDim2.fromOffset(size, size),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(center.X, center.Y),
			ZIndex = 40,
			Parent = parent,
		})
		UIKit.Corner(dot, size)
		local angle = math.random() * math.pi * 2
		local d = (distance or 220) * (0.5 + math.random() * 0.6)
		local tween = UIKit.Tween(dot, 0.7 + math.random() * 0.4, {
			Position = UDim2.fromOffset(center.X + math.cos(angle) * d, center.Y + math.sin(angle) * d),
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(2, 2),
		}, Enum.EasingStyle.Quad)
		tween.Completed:Once(function()
			dot:Destroy()
		end)
	end
end

function Effects.Confetti(count: number?)
	if Effects.Graphics == "Low" then
		return
	end
	local width = Root.VirtualSize.X
	local colors = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 210, 70), Color3.fromRGB(90, 220, 120), Color3.fromRGB(90, 170, 255), Color3.fromRGB(200, 110, 255) }
	for _ = 1, count or 40 do
		local piece = UIKit.new("Frame", {
			BackgroundColor3 = colors[math.random(1, #colors)],
			Size = UDim2.fromOffset(math.random(6, 12), math.random(10, 18)),
			Position = UDim2.fromOffset(math.random(0, math.floor(width)), -30),
			Rotation = math.random(0, 360),
			ZIndex = 45,
			Parent = Root.TopCanvas,
		})
		local tween = UIKit.Tween(piece, 1.6 + math.random() * 1.2, {
			Position = UDim2.fromOffset(piece.Position.X.Offset + math.random(-120, 120), Root.VirtualSize.Y + 40),
			Rotation = piece.Rotation + math.random(-360, 360),
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween.Completed:Once(function()
			piece:Destroy()
		end)
	end
end

-- World-space zap ring (traps).
function Effects.Zap(position: Vector3, color: Color3?)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Ball
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = color or Color3.fromRGB(110, 220, 255)
	ring.Size = Vector3.one
	ring.Position = position + Vector3.new(0, 1, 0)
	ring.Parent = Workspace.CurrentCamera
	UIKit.Tween(ring, 0.45, { Size = Vector3.one * 12, Transparency = 1 })
	task.delay(0.5, function()
		ring:Destroy()
	end)
end

return Effects
