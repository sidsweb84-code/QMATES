--[[
	UIKit
	Small component library used by every interface. All sizes are in
	"virtual pixels" (see UI/Root) so layouts scale to phones, tablets,
	PCs and TVs. Buttons have hover / press animations, click sounds and
	a custom gamepad selection highlight.
]]

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Sound = require(script.Parent.Parent.Controllers.Sound)

local UIKit = {}

local C = Theme.Colors

function UIKit.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			else
				(inst :: any)[k] = v
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function UIKit.Corner(parent: Instance, radius: number?): UICorner
	return UIKit.new("UICorner", { CornerRadius = UDim.new(0, radius or Theme.Radius), Parent = parent })
end

function UIKit.Stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?): UIStroke
	return UIKit.new("UIStroke", {
		Color = color or C.Stroke,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function UIKit.TextStroke(parent: Instance, thickness: number?, color: Color3?): UIStroke
	return UIKit.new("UIStroke", {
		Color = color or Color3.fromRGB(10, 10, 25),
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Parent = parent,
	})
end

function UIKit.Padding(parent: Instance, top: number, right: number?, bottom: number?, left: number?): UIPadding
	return UIKit.new("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, right or top),
		PaddingBottom = UDim.new(0, bottom or top),
		PaddingLeft = UDim.new(0, left or right or top),
		Parent = parent,
	})
end

function UIKit.Gradient(parent: Instance, colors: { Color3 }, rotation: number?): UIGradient
	local keypoints = {}
	for i, color in colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / math.max(1, #colors - 1), color))
	end
	if #keypoints == 1 then
		table.insert(keypoints, ColorSequenceKeypoint.new(1, colors[1]))
	end
	return UIKit.new("UIGradient", { Color = ColorSequence.new(keypoints), Rotation = rotation or 90, Parent = parent })
end

function UIKit.List(parent: Instance, direction: string?, padding: number?, hAlign: Enum.HorizontalAlignment?, vAlign: Enum.VerticalAlignment?): UIListLayout
	return UIKit.new("UIListLayout", {
		FillDirection = if direction == "X" then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding or 8),
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

function UIKit.Grid(parent: Instance, cellSize: Vector2, padding: Vector2?): UIGridLayout
	return UIKit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(cellSize.X, cellSize.Y),
		CellPadding = UDim2.fromOffset((padding or Vector2.new(10, 10)).X, (padding or Vector2.new(10, 10)).Y),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Parent = parent,
	})
end

export type LabelProps = {
	Name: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	TextSize: number?,
	Font: Enum.Font?,
	Color: Color3?,
	XAlign: Enum.TextXAlignment?,
	YAlign: Enum.TextYAlignment?,
	Wrapped: boolean?,
	Scaled: boolean?,
	LayoutOrder: number?,
	Stroke: number?,
	RichText: boolean?,
	AutoSize: boolean?,
}

function UIKit.Label(parent: Instance?, text: string, props: LabelProps?): TextLabel
	local p: LabelProps = props or {}
	local label = UIKit.new("TextLabel", {
		Name = p.Name or "Label",
		BackgroundTransparency = 1,
		Size = p.Size or UDim2.new(1, 0, 0, (p.TextSize or 18) + 6),
		Position = p.Position or UDim2.new(),
		AnchorPoint = p.AnchorPoint or Vector2.zero,
		Text = text,
		TextSize = p.TextSize or 18,
		Font = p.Font or Theme.Fonts.Body,
		TextColor3 = p.Color or C.Text,
		TextXAlignment = p.XAlign or Enum.TextXAlignment.Left,
		TextYAlignment = p.YAlign or Enum.TextYAlignment.Center,
		TextWrapped = p.Wrapped == true,
		TextScaled = p.Scaled == true,
		RichText = p.RichText == true,
		LayoutOrder = p.LayoutOrder or 0,
		AutomaticSize = if p.AutoSize then Enum.AutomaticSize.Y else Enum.AutomaticSize.None,
		Parent = parent,
	})
	if p.Stroke and p.Stroke > 0 then
		UIKit.TextStroke(label, p.Stroke)
	end
	if p.Scaled then
		UIKit.new("UITextSizeConstraint", { MaxTextSize = p.TextSize or 48, MinTextSize = 8, Parent = label })
	end
	return label
end

export type PanelProps = {
	Name: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Color: Color3?,
	Transparency: number?,
	Radius: number?,
	StrokeColor: Color3?,
	StrokeThickness: number?,
	LayoutOrder: number?,
	ClipsDescendants: boolean?,
	Visible: boolean?,
	ZIndex: number?,
}

function UIKit.Panel(parent: Instance?, props: PanelProps?): Frame
	local p: PanelProps = props or {}
	local frame = UIKit.new("Frame", {
		Name = p.Name or "Panel",
		Size = p.Size or UDim2.fromScale(1, 1),
		Position = p.Position or UDim2.new(),
		AnchorPoint = p.AnchorPoint or Vector2.zero,
		BackgroundColor3 = p.Color or C.Panel,
		BackgroundTransparency = p.Transparency or 0,
		LayoutOrder = p.LayoutOrder or 0,
		ClipsDescendants = p.ClipsDescendants == true,
		Visible = p.Visible ~= false,
		ZIndex = p.ZIndex or 1,
		Parent = parent,
	})
	if (p.Radius or Theme.Radius) > 0 then
		UIKit.Corner(frame, p.Radius or Theme.Radius)
	end
	if p.StrokeColor or p.StrokeThickness then
		UIKit.Stroke(frame, p.StrokeColor or C.Stroke, p.StrokeThickness or 2)
	end
	return frame
end

function UIKit.Tween(inst: Instance, duration: number, props: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local tween = TweenService:Create(inst, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

local function getScale(inst: Instance): UIScale
	local scale = inst:FindFirstChild("AnimScale") :: UIScale?
	if not scale then
		scale = UIKit.new("UIScale", { Name = "AnimScale", Scale = 1, Parent = inst })
	end
	return scale :: UIScale
end

function UIKit.Pop(inst: Instance, amount: number?)
	local scale = getScale(inst)
	scale.Scale = 1 + (amount or 0.12)
	UIKit.Tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Selection highlight shown when navigating with a gamepad.
local selectionTemplate = UIKit.new("Frame", {
	Name = "Selection",
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 8, 1, 8),
	Position = UDim2.fromOffset(-4, -4),
})
UIKit.Corner(selectionTemplate, Theme.Radius + 4)
UIKit.Stroke(selectionTemplate, C.Accent, 3)

export type ButtonProps = {
	Name: string?,
	Text: string?,
	Icon: string?,
	Style: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	TextSize: number?,
	LayoutOrder: number?,
	OnClick: (() -> ())?,
	Radius: number?,
	Font: Enum.Font?,
	Silent: boolean?,
}

function UIKit.Button(parent: Instance?, props: ButtonProps): TextButton
	local styleName = props.Style or "Primary"
	local style = Theme.ButtonStyles[styleName] or Theme.ButtonStyles.Primary
	local button = UIKit.new("TextButton", {
		Name = props.Name or "Button",
		Size = props.Size or UDim2.fromOffset(160, 48),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = props.LayoutOrder or 0,
		Selectable = true,
		SelectionImageObject = selectionTemplate,
		Parent = parent,
	})
	button:SetAttribute("Style", styleName)
	UIKit.Corner(button, props.Radius or 12)
	local gradient = UIKit.Gradient(button, { style[1], style[2] }, 90)
	gradient.Name = "StyleGradient"
	local stroke = UIKit.Stroke(button, style[3], 2.5)
	stroke.Name = "StyleStroke"
	local text = props.Text or ""
	if props.Icon and props.Icon ~= "" then
		text = if text ~= "" then props.Icon .. "  " .. text else props.Icon
	end
	local label = UIKit.Label(button, text, {
		Name = "Label",
		Size = UDim2.new(1, -12, 1, 0),
		Position = UDim2.fromOffset(6, 0),
		TextSize = props.TextSize or 20,
		Font = props.Font or Theme.Fonts.Title,
		XAlign = Enum.TextXAlignment.Center,
		Stroke = 2,
	})
	label.TextTruncate = Enum.TextTruncate.AtEnd
	local scale = getScale(button)

	button.MouseEnter:Connect(function()
		if button:GetAttribute("Disabled") then
			return
		end
		UIKit.Tween(scale, 0.12, { Scale = 1.05 })
		if not props.Silent then
			Sound.Play("UIHover", { MinInterval = 0.06 })
		end
	end)
	button.MouseLeave:Connect(function()
		UIKit.Tween(scale, 0.12, { Scale = 1 })
	end)
	button.SelectionGained:Connect(function()
		UIKit.Tween(scale, 0.12, { Scale = 1.05 })
	end)
	button.SelectionLost:Connect(function()
		UIKit.Tween(scale, 0.12, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		if not button:GetAttribute("Disabled") then
			UIKit.Tween(scale, 0.08, { Scale = 0.93 })
		end
	end)
	button.MouseButton1Up:Connect(function()
		UIKit.Tween(scale, 0.15, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	button.Activated:Connect(function()
		if button:GetAttribute("Disabled") then
			Sound.Play("Error")
			return
		end
		if not props.Silent then
			Sound.Play("UIClick")
		end
		if props.OnClick then
			props.OnClick()
		end
	end)
	return button
end

function UIKit.SetButtonText(button: GuiObject, text: string)
	local label = button:FindFirstChild("Label") :: TextLabel?
	if label then
		label.Text = text
	end
end

function UIKit.SetButtonStyle(button: GuiObject, styleName: string)
	local style = Theme.ButtonStyles[styleName]
	if not style or button:GetAttribute("Style") == styleName then
		return
	end
	button:SetAttribute("Style", styleName)
	local gradient = button:FindFirstChild("StyleGradient") :: UIGradient?
	local stroke = button:FindFirstChild("StyleStroke") :: UIStroke?
	if gradient then
		gradient.Color = ColorSequence.new(style[1], style[2])
	end
	if stroke then
		stroke.Color = style[3]
	end
end

function UIKit.SetButtonEnabled(button: GuiObject, enabled: boolean, disabledStyle: string?)
	button:SetAttribute("Disabled", not enabled)
	if not enabled then
		if not button:GetAttribute("EnabledStyle") then
			button:SetAttribute("EnabledStyle", button:GetAttribute("Style"))
		end
		UIKit.SetButtonStyle(button, disabledStyle or "Secondary")
	elseif button:GetAttribute("EnabledStyle") then
		UIKit.SetButtonStyle(button, tostring(button:GetAttribute("EnabledStyle")))
		button:SetAttribute("EnabledStyle", nil)
	end
end

export type ProgressBar = {
	Frame: Frame,
	Fill: Frame,
	Label: TextLabel,
	Set: (self: ProgressBar, alpha: number, text: string?, animate: boolean?) -> (),
}

function UIKit.ProgressBar(parent: Instance?, props: { Size: UDim2?, Position: UDim2?, AnchorPoint: Vector2?, Color: Color3?, TextSize: number?, LayoutOrder: number? }?): ProgressBar
	local p = props or {}
	local frame = UIKit.Panel(parent, {
		Name = "ProgressBar",
		Size = p.Size or UDim2.new(1, 0, 0, 24),
		Position = p.Position,
		AnchorPoint = p.AnchorPoint,
		Color = C.PanelDark,
		Radius = 10,
		StrokeColor = C.Stroke,
		LayoutOrder = p.LayoutOrder,
		ClipsDescendants = true,
	})
	local fill = UIKit.Panel(frame, { Name = "Fill", Size = UDim2.fromScale(0, 1), Color = Color3.new(1, 1, 1), Radius = 10 })
	local color = p.Color or C.Success
	UIKit.Gradient(fill, { color:Lerp(Color3.new(1, 1, 1), 0.25), color }, 90)
	local label = UIKit.Label(frame, "", {
		Size = UDim2.fromScale(1, 1),
		TextSize = p.TextSize or 15,
		XAlign = Enum.TextXAlignment.Center,
		Stroke = 2,
	})
	label.ZIndex = 3
	local bar = { Frame = frame, Fill = fill, Label = label } :: any
	function bar:Set(alpha: number, text: string?, animate: boolean?)
		local a = math.clamp(alpha, 0, 1)
		if animate then
			UIKit.Tween(self.Fill, 0.3, { Size = UDim2.fromScale(a, 1) })
		else
			self.Fill.Size = UDim2.fromScale(a, 1)
		end
		if text then
			self.Label.Text = text
		end
	end
	return bar
end

export type Tabs = { Buttons: { [string]: TextButton }, Selected: string?, Select: (self: Tabs, id: string) -> () }

function UIKit.Tabs(parent: Instance, tabs: { { Id: string, Text: string } }, onSelect: (string) -> (), props: { Size: UDim2?, Position: UDim2?, ButtonWidth: number? }?): Tabs
	local p = props or {}
	local bar = UIKit.new("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = p.Size or UDim2.new(1, 0, 0, 40),
		Position = p.Position or UDim2.new(),
		Parent = parent,
	})
	UIKit.List(bar, "X", 8)
	local object = { Buttons = {}, Selected = nil } :: any
	for i, tab in tabs do
		local button = UIKit.Button(bar, {
			Name = tab.Id,
			Text = tab.Text,
			Style = "Ghost",
			Size = UDim2.new(0, p.ButtonWidth or 120, 1, 0),
			TextSize = 17,
			LayoutOrder = i,
			OnClick = function()
				object:Select(tab.Id)
			end,
		})
		object.Buttons[tab.Id] = button
	end
	function object:Select(id: string)
		self.Selected = id
		for tabId, button in self.Buttons do
			UIKit.SetButtonStyle(button, if tabId == id then "Blue" else "Ghost")
		end
		onSelect(id)
	end
	return object
end

function UIKit.Scroll(parent: Instance?, props: { Size: UDim2?, Position: UDim2?, Layout: string?, CellSize: Vector2?, Padding: number?, Name: string? }?): ScrollingFrame
	local p = props or {}
	local scroll = UIKit.new("ScrollingFrame", {
		Name = p.Name or "Scroll",
		Size = p.Size or UDim2.fromScale(1, 1),
		Position = p.Position or UDim2.new(),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.StrokeLight,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Selectable = false,
		Parent = parent,
	})
	if p.Layout == "Grid" then
		UIKit.Grid(scroll, p.CellSize or Vector2.new(150, 210), Vector2.new(p.Padding or 10, p.Padding or 10))
	else
		UIKit.List(scroll, "Y", p.Padding or 8)
	end
	UIKit.Padding(scroll, 4, 10, 10, 4)
	return scroll
end

-- Removes all children except layout helpers.
function UIKit.Clear(parent: Instance)
	for _, child in parent:GetChildren() do
		if not (child:IsA("UIListLayout") or child:IsA("UIGridLayout") or child:IsA("UIPadding") or child:IsA("UICorner") or child:IsA("UIStroke") or child:IsA("UIGradient") or child:IsA("UIScale")) then
			child:Destroy()
		end
	end
end

-- Small rounded "chip" with text.
function UIKit.Chip(parent: Instance?, text: string, color: Color3, props: { Size: UDim2?, Position: UDim2?, AnchorPoint: Vector2?, TextSize: number?, LayoutOrder: number? }?): Frame
	local p = props or {}
	local chip = UIKit.Panel(parent, {
		Name = "Chip",
		Size = p.Size or UDim2.fromOffset(110, 26),
		Position = p.Position,
		AnchorPoint = p.AnchorPoint,
		Color = color,
		Radius = 13,
		LayoutOrder = p.LayoutOrder,
	})
	UIKit.Label(chip, text, { Size = UDim2.fromScale(1, 1), TextSize = p.TextSize or 14, XAlign = Enum.TextXAlignment.Center, Stroke = 1.5 })
	return chip
end

return UIKit
