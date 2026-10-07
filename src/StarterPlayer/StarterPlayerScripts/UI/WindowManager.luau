--[[
	WindowManager
	Opens / closes the main menus with animations. One window at a time.
	Each window module exports: Title, Icon, Color, Build(body, shell), Open(args), Close()
	Escape (keyboard) / B (gamepad) closes the current window.
]]

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")

local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)
local Root = require(script.Parent.Root)
local Sound = require(script.Parent.Parent.Controllers.Sound)
local Signal = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Signal"))

local C = Theme.Colors

local WindowManager = {}

WindowManager.Current = nil :: string?
WindowManager.Changed = Signal.new()

type Entry = { Module: any, Shell: Frame, Body: Frame, Built: boolean, Scale: UIScale }
local windows: { [string]: Entry } = {}

local dim = UIKit.new("TextButton", {
	Name = "Dim",
	Text = "",
	AutoButtonColor = false,
	BackgroundColor3 = C.Backdrop,
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	Selectable = false,
	Parent = Root.Windows,
})

local function windowSize(): UDim2
	local v = Root.VirtualSize
	return UDim2.fromOffset(math.min(860, v.X - 40), math.min(570, v.Y - 150))
end

function WindowManager.Register(name: string, module)
	local shell = UIKit.Panel(Root.Windows, {
		Name = name .. "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -20),
		Size = windowSize(),
		Color = C.Panel,
		StrokeColor = module.Color or C.Stroke,
		StrokeThickness = 3,
		Radius = 20,
		Visible = false,
		ZIndex = 2,
	})
	UIKit.Gradient(shell, { Color3.fromRGB(255, 255, 255), Color3.fromRGB(205, 205, 230) }, 90)
	local scale = UIKit.new("UIScale", { Parent = shell })

	-- Header
	local header = UIKit.Panel(shell, { Name = "Header", Size = UDim2.new(1, 0, 0, 60), Color = module.Color or C.PanelLight, Radius = 20 })
	UIKit.Gradient(header, { (module.Color or C.PanelLight):Lerp(Color3.new(1, 1, 1), 0.15), (module.Color or C.PanelLight):Lerp(Color3.new(0, 0, 0), 0.35) }, 90)
	UIKit.new("Frame", { -- square off the header's bottom corners
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -2),
		Size = UDim2.new(1, 0, 0, 2),
		Parent = header,
	})
	UIKit.Label(header, (module.Icon or "") .. "  " .. (module.Title or name), {
		Name = "Title",
		Size = UDim2.new(1, -90, 1, 0),
		Position = UDim2.fromOffset(20, 0),
		TextSize = 30,
		Font = Theme.Fonts.Title,
		Stroke = 3,
	})
	UIKit.Button(header, {
		Name = "Close",
		Text = "✕",
		Style = "Danger",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(44, 44),
		TextSize = 24,
		OnClick = function()
			WindowManager.Close()
		end,
	})

	local body = UIKit.new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 72),
		Size = UDim2.new(1, -32, 1, -86),
		Parent = shell,
	})
	windows[name] = { Module = module, Shell = shell, Body = body, Built = false, Scale = scale }
end

local function firstSelectable(root: Instance): GuiObject?
	for _, d in root:GetDescendants() do
		if d:IsA("GuiButton") and d.Selectable and d.Visible and d.Name ~= "Close" then
			return d
		end
	end
	return nil
end

function WindowManager.Open(name: string, args: any?)
	local entry = windows[name]
	if not entry then
		return
	end
	if WindowManager.Current and WindowManager.Current ~= name then
		WindowManager.Close(true)
	end
	if not entry.Built then
		entry.Built = true
		local ok, err = pcall(entry.Module.Build, entry.Body, entry.Shell)
		if not ok then
			warn("[WindowManager] Build failed for " .. name .. ": " .. tostring(err))
		end
	end
	entry.Shell.Size = windowSize()
	local wasOpen = WindowManager.Current == name
	WindowManager.Current = name
	dim.Visible = true
	UIKit.Tween(dim, 0.2, { BackgroundTransparency = 0.55 })
	entry.Shell.Visible = true
	if not wasOpen then
		entry.Scale.Scale = 0.82
		UIKit.Tween(entry.Scale, 0.32, { Scale = 1 }, Enum.EasingStyle.Back)
		Sound.Play("WindowOpen")
	end
	if entry.Module.Open then
		local ok, err = pcall(entry.Module.Open, args)
		if not ok then
			warn("[WindowManager] Open failed for " .. name .. ": " .. tostring(err))
		end
	end
	if Root.IsGamepad() then
		task.defer(function()
			GuiService.SelectedObject = firstSelectable(entry.Shell)
		end)
	end
	WindowManager.Changed:Fire(name)
end

function WindowManager.Close(instant: boolean?)
	local name = WindowManager.Current
	if not name then
		return
	end
	local entry = windows[name]
	WindowManager.Current = nil
	if entry.Module.Close then
		pcall(entry.Module.Close)
	end
	if instant then
		entry.Shell.Visible = false
	else
		Sound.Play("WindowClose")
		UIKit.Tween(entry.Scale, 0.18, { Scale = 0.85 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		UIKit.Tween(dim, 0.18, { BackgroundTransparency = 1 })
		task.delay(0.18, function()
			if WindowManager.Current ~= name then
				entry.Shell.Visible = false
				if WindowManager.Current == nil then
					dim.Visible = false
				end
			end
		end)
	end
	GuiService.SelectedObject = nil
	WindowManager.Changed:Fire(nil)
end

function WindowManager.Toggle(name: string, args: any?)
	if WindowManager.Current == name then
		WindowManager.Close()
	else
		WindowManager.Open(name, args)
	end
end

function WindowManager.IsOpen(name: string): boolean
	return WindowManager.Current == name
end

-- Re-run the current window's Open() (used when data changes while open).
function WindowManager.Refresh(name: string)
	if WindowManager.Current == name then
		local entry = windows[name]
		if entry and entry.Module.Open then
			pcall(entry.Module.Open, nil)
		end
	end
end

dim.Activated:Connect(function()
	WindowManager.Close()
end)

Root.ScaleChanged:Connect(function()
	for _, entry in windows do
		entry.Shell.Size = windowSize()
	end
end)

ContextActionService:BindAction("CloseWindow", function(_, state)
	if state == Enum.UserInputState.Begin and WindowManager.Current then
		WindowManager.Close()
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.ButtonB)

return WindowManager
