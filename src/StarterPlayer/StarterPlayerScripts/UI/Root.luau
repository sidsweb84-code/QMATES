--[[
	Root
	Creates the ScreenGuis and the responsive "virtual canvas".

	All UI is authored for a virtual resolution of about 1100x680. A UIScale
	scales the canvas to the real screen, and the canvas size is set to
	screen / scale so it always covers the safe area exactly. Phones, tablets,
	PCs and consoles therefore all get the same layout at a readable size.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)
local Signal = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Signal"))

local Root = {}

Root.UserScale = 1
Root.Scale = 1
Root.VirtualSize = Theme.DesignSize
Root.ScaleChanged = Signal.new()

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local function screenGui(name: string, order: number, ignoreInset: boolean): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = ignoreInset
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = order
	gui.ScreenInsets = if ignoreInset then Enum.ScreenInsets.None else Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = playerGui
	return gui
end

Root.Gui = screenGui("StealCrittersUI", 10, false)
Root.FXGui = screenGui("StealCrittersFX", 20, true)
Root.TopGui = screenGui("StealCrittersTop", 30, false)

local function canvas(parent: ScreenGui, name: string): (Frame, UIScale)
	local frame = UIKit.new("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	})
	local scale = UIKit.new("UIScale", { Name = "RootScale", Parent = frame })
	return frame, scale
end

Root.Canvas, Root.CanvasScale = canvas(Root.Gui, "Canvas")
Root.TopCanvas, Root.TopScale = canvas(Root.TopGui, "Canvas")

local function layer(name: string, z: number, parent: Instance?): Frame
	return UIKit.new("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z,
		Parent = parent or Root.Canvas,
	})
end

Root.HUD = layer("HUD", 1)
Root.Windows = layer("Windows", 5)
Root.Toasts = layer("Toasts", 8, Root.TopCanvas)
Root.Modal = layer("Modal", 9, Root.TopCanvas)

-- Full-screen effects layer (flashes, vignettes) is not scaled.
Root.FX = UIKit.new("Frame", { Name = "FX", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = Root.FXGui })

function Root.IsGamepad(): boolean
	return UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled
end

function Root.IsTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function Root.Recompute()
	local size = Root.Gui.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return
	end
	local design = Theme.DesignSize
	local scale = math.min(size.X / design.X, size.Y / design.Y)
	if Root.IsGamepad() or GuiService:IsTenFootInterface() then
		scale *= 1.1
	end
	scale = math.clamp(scale * Root.UserScale, 0.45, 1.6)
	Root.Scale = scale
	Root.VirtualSize = Vector2.new(size.X / scale, size.Y / scale)
	for _, pair in { { Root.Canvas, Root.CanvasScale }, { Root.TopCanvas, Root.TopScale } } do
		local frame, uiScale = pair[1], pair[2]
		frame.Size = UDim2.fromOffset(Root.VirtualSize.X, Root.VirtualSize.Y)
		uiScale.Scale = scale
	end
	Root.ScaleChanged:Fire(scale, Root.VirtualSize)
end

function Root.SetUserScale(name: string)
	Root.UserScale = if name == "Small" then 0.88 elseif name == "Large" then 1.15 else 1
	Root.Recompute()
end

Root.Gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(Root.Recompute)
UserInputService.LastInputTypeChanged:Connect(function()
	Root.Recompute()
end)
Root.Recompute()

return Root
