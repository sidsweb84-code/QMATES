--[[
	Notifications
	Toasts (right side), rarity announcements (top centre), reward popups and
	confirmation dialogs. Everything queues so nothing overlaps.
]]

local GuiService = game:GetService("GuiService")

local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)
local Root = require(script.Parent.Root)
local Sound = require(script.Parent.Parent.Controllers.Sound)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RarityConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("RarityConfig"))

local C = Theme.Colors

local Notifications = {}

local KIND_COLORS = {
	Success = C.Success,
	Error = C.Danger,
	Warning = C.Warning,
	Info = C.Blue,
	Reward = C.Accent,
}
local KIND_ICONS = { Success = "✅", Error = "⛔", Warning = "⚠️", Info = "💬", Reward = "🎁" }

---------------------------------------------------------------- toasts
local toastHolder = UIKit.new("Frame", {
	Name = "ToastHolder",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 270),
	Size = UDim2.new(0, 330, 1, -390),
	Parent = Root.Toasts,
})
local toastLayout = UIKit.List(toastHolder, "Y", 8, Enum.HorizontalAlignment.Right)
toastLayout.VerticalAlignment = Enum.VerticalAlignment.Top

local toastCount = 0

function Notifications.Toast(text: string, kind: string?, icon: string?)
	local k = kind or "Info"
	local color = KIND_COLORS[k] or C.Blue
	toastCount += 1
	local toast = UIKit.Panel(toastHolder, {
		Name = "Toast",
		Size = UDim2.fromOffset(330, 52),
		Color = C.Panel,
		StrokeColor = color,
		StrokeThickness = 2.5,
		LayoutOrder = toastCount,
		Radius = 12,
	})
	toast.AutomaticSize = Enum.AutomaticSize.Y
	toast.BackgroundTransparency = 0.05
	local accent = UIKit.Panel(toast, { Size = UDim2.new(0, 6, 1, -12), Position = UDim2.fromOffset(6, 6), Color = color, Radius = 3 })
	accent.Name = "Accent"
	UIKit.Padding(toast, 8, 12, 8, 20)
	local label = UIKit.Label(toast, (icon or KIND_ICONS[k] or "") .. "  " .. text, {
		Size = UDim2.new(1, 0, 0, 0),
		TextSize = 16,
		Wrapped = true,
		AutoSize = true,
		Stroke = 1,
	})
	label.Position = UDim2.fromOffset(4, 0)
	local scale = UIKit.new("UIScale", { Scale = 0.6, Parent = toast })
	UIKit.Tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	if k == "Error" then
		Sound.Play("Error")
	else
		Sound.Play("Notify", { MinInterval = 0.2 })
	end
	-- Keep at most 5
	local toasts = {}
	for _, child in toastHolder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	if #toasts > 5 then
		table.sort(toasts, function(a, b)
			return (a :: Frame).LayoutOrder < (b :: Frame).LayoutOrder
		end)
		toasts[1]:Destroy()
	end
	task.delay(if k == "Error" then 4.5 else 3.5, function()
		if toast.Parent then
			UIKit.Tween(scale, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			task.wait(0.26)
			toast:Destroy()
		end
	end)
end

---------------------------------------------------------------- announcements
local announceQueue: { any } = {}
local announcing = false

local banner = UIKit.Panel(Root.Toasts, {
	Name = "Announcement",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 148),
	Size = UDim2.fromOffset(620, 48),
	Color = C.PanelDark,
	StrokeColor = C.Accent,
	StrokeThickness = 3,
	Radius = 24,
	Visible = false,
})
banner.BackgroundTransparency = 0.1
local bannerGradient = UIKit.Gradient(banner, { Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 220) }, 90)
local bannerLabel = UIKit.Label(banner, "", { Size = UDim2.new(1, -24, 1, 0), Position = UDim2.fromOffset(12, 0), TextSize = 19, Font = Theme.Fonts.Title, XAlign = Enum.TextXAlignment.Center, Stroke = 2 })
local bannerScale = UIKit.new("UIScale", { Parent = banner })

local function nextAnnouncement()
	if announcing or #announceQueue == 0 then
		return
	end
	announcing = true
	local entry = table.remove(announceQueue, 1)
	local color = entry.Color or C.Accent
	local stroke = banner:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = color
	end
	bannerGradient.Color = ColorSequence.new(Color3.new(1, 1, 1), color:Lerp(Color3.new(0, 0, 0), 0.2))
	bannerLabel.Text = entry.Text
	bannerLabel.TextColor3 = Color3.new(1, 1, 1)
	banner.Visible = true
	bannerScale.Scale = 0.5
	UIKit.Tween(bannerScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	local rarity = entry.Rarity and RarityConfig.Rarities[entry.Rarity]
	if rarity and rarity.Tier >= 5 then
		Sound.Play("RevealRare", { Pitch = 0.9 })
	end
	task.delay(if #announceQueue > 2 then 2.5 else 4.2, function()
		UIKit.Tween(bannerScale, 0.2, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.wait(0.22)
		banner.Visible = false
		announcing = false
		nextAnnouncement()
	end)
end

function Notifications.Announce(text: string, color: Color3?, icon: string?, rarity: string?)
	if #announceQueue > 6 then
		table.remove(announceQueue, 1)
	end
	table.insert(announceQueue, { Text = (icon and (icon .. " ") or "") .. text, Color = color, Rarity = rarity })
	nextAnnouncement()
end

---------------------------------------------------------------- modal popups
local modalQueue: { () -> () } = {}
local modalOpen = false

local dim = UIKit.new("TextButton", {
	Name = "Dim",
	Text = "",
	AutoButtonColor = false,
	BackgroundColor3 = C.Backdrop,
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	Selectable = false,
	Parent = Root.Modal,
})

local function closeModal(card: Frame)
	local scale = card:FindFirstChildOfClass("UIScale")
	if scale then
		UIKit.Tween(scale, 0.18, { Scale = 0.7 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	end
	UIKit.Tween(dim, 0.18, { BackgroundTransparency = 1 })
	task.wait(0.19)
	card:Destroy()
	dim.Visible = false
	modalOpen = false
	GuiService.SelectedObject = nil
	local nextModal = table.remove(modalQueue, 1)
	if nextModal then
		nextModal()
	end
end

local function openModal(build: (card: Frame, close: () -> ()) -> GuiObject?)
	local function show()
		modalOpen = true
		dim.Visible = true
		UIKit.Tween(dim, 0.2, { BackgroundTransparency = 0.45 })
		local card = UIKit.Panel(Root.Modal, {
			Name = "ModalCard",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(440, 300),
			Color = C.Panel,
			StrokeColor = C.Accent,
			StrokeThickness = 3,
			Radius = 18,
		})
		card.ZIndex = 2
		UIKit.Gradient(card, { Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 230) }, 90)
		local scale = UIKit.new("UIScale", { Scale = 0.6, Parent = card })
		UIKit.Tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		local first = build(card, function()
			task.spawn(closeModal, card)
		end)
		if first and Root.IsGamepad() then
			GuiService.SelectedObject = first
		end
	end
	if modalOpen then
		table.insert(modalQueue, show)
	else
		show()
	end
end

function Notifications.Popup(title: string, lines: { string }, icon: string?)
	Sound.Play("Reward")
	openModal(function(card, close)
		UIKit.Label(card, (icon or "🎁"), { Size = UDim2.new(1, 0, 0, 56), Position = UDim2.fromOffset(0, 10), TextSize = 46, XAlign = Enum.TextXAlignment.Center })
		UIKit.Label(card, title, { Size = UDim2.new(1, -30, 0, 34), Position = UDim2.fromOffset(15, 66), TextSize = 28, Font = Theme.Fonts.Title, XAlign = Enum.TextXAlignment.Center, Color = C.Accent, Stroke = 2 })
		local list = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -40, 0, 0), Position = UDim2.fromOffset(20, 106), AutomaticSize = Enum.AutomaticSize.Y, Parent = card })
		UIKit.List(list, "Y", 4, Enum.HorizontalAlignment.Center)
		for i, line in lines do
			UIKit.Label(list, line, { Size = UDim2.new(1, 0, 0, 0), TextSize = 18, XAlign = Enum.TextXAlignment.Center, Wrapped = true, AutoSize = true, LayoutOrder = i, Stroke = 1 })
		end
		local height = 106 + math.max(1, #lines) * 28 + 90
		card.Size = UDim2.fromOffset(440, math.clamp(height, 220, 520))
		return UIKit.Button(card, {
			Text = "Awesome!",
			Style = "Primary",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -16),
			Size = UDim2.fromOffset(200, 50),
			OnClick = close,
		})
	end)
end

function Notifications.Confirm(title: string, text: string, confirmText: string, onConfirm: () -> (), style: string?)
	openModal(function(card, close)
		UIKit.Label(card, title, { Size = UDim2.new(1, -30, 0, 38), Position = UDim2.fromOffset(15, 16), TextSize = 28, Font = Theme.Fonts.Title, XAlign = Enum.TextXAlignment.Center, Color = C.Accent, Stroke = 2 })
		UIKit.Label(card, text, { Size = UDim2.new(1, -40, 0, 150), Position = UDim2.fromOffset(20, 60), TextSize = 18, XAlign = Enum.TextXAlignment.Center, YAlign = Enum.TextYAlignment.Top, Wrapped = true, Color = C.SubText })
		UIKit.Button(card, {
			Text = "Cancel",
			Style = "Secondary",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(0.5, -8, 1, -18),
			Size = UDim2.fromOffset(170, 50),
			OnClick = close,
		})
		return UIKit.Button(card, {
			Text = confirmText,
			Style = style or "Success",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0.5, 8, 1, -18),
			Size = UDim2.fromOffset(170, 50),
			OnClick = function()
				close()
				onConfirm()
			end,
		})
	end)
end

-- Two-choice prompt (e.g. trade requests). onChoice(true|false)
function Notifications.Choice(title: string, text: string, yesText: string, noText: string, onChoice: (boolean) -> ())
	openModal(function(card, close)
		UIKit.Label(card, title, { Size = UDim2.new(1, -30, 0, 38), Position = UDim2.fromOffset(15, 16), TextSize = 28, Font = Theme.Fonts.Title, XAlign = Enum.TextXAlignment.Center, Color = C.Accent, Stroke = 2 })
		UIKit.Label(card, text, { Size = UDim2.new(1, -40, 0, 150), Position = UDim2.fromOffset(20, 60), TextSize = 18, XAlign = Enum.TextXAlignment.Center, YAlign = Enum.TextYAlignment.Top, Wrapped = true, Color = C.SubText })
		UIKit.Button(card, {
			Text = noText,
			Style = "Danger",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(0.5, -8, 1, -18),
			Size = UDim2.fromOffset(170, 50),
			OnClick = function()
				close()
				onChoice(false)
			end,
		})
		return UIKit.Button(card, {
			Text = yesText,
			Style = "Success",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0.5, 8, 1, -18),
			Size = UDim2.fromOffset(170, 50),
			OnClick = function()
				close()
				onChoice(true)
			end,
		})
	end)
end

-- Convenience: show a request result as a toast.
function Notifications.Result(response, successText: string?)
	if response.Ok then
		if response.Message or successText then
			Notifications.Toast(response.Message or successText or "", "Success")
		end
	elseif response.Message then
		Notifications.Toast(response.Message, "Error")
	end
end

return Notifications
