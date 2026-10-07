--[[
	CardView
	Trading-card UI used in the collection, index, shop, trade and reveal
	screens. Shows artwork (3D ViewportFrame preview, licensed ImageId, or the
	element emblem), rarity, name, income, level, mutation, trait and serial.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local RarityConfig = require(Config.RarityConfig)
local MutationConfig = require(Config.MutationConfig)
local TraitConfig = require(Config.TraitConfig)
local CollectibleConfig = require(Config.CollectibleConfig)
local CosmeticConfig = require(Config.CosmeticConfig)
local Catalog = require(Shared.Catalog)
local Economy = require(Shared.Economy)
local Format = require(Shared.Util.Format)
local CreatureBuilder = require(Shared.CreatureBuilder)
local CardBillboard = require(Shared.CardBillboard)

local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)

local CardView = {}

export type Info = {
	Id: string,
	Mutation: string?,
	Trait: string?,
	Level: number?,
	Serial: number?,
	Income: number?,
	Price: number?,
	Count: number?,
	Undiscovered: boolean?,
	FrameId: string?,
	Stored: boolean?,
	Locked: boolean?,
	Badge: string?,
	Subtitle: string?,
}

export type Props = {
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Viewport: boolean?,
	OnClick: (() -> ())?,
	Name: string?,
}

local function scaledLabel(parent: Instance, text: string, position: UDim2, size: UDim2, color: Color3, font: Enum.Font?, maxSize: number?, align: Enum.TextXAlignment?): TextLabel
	local label = UIKit.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = position,
		Size = size,
		Text = text,
		TextColor3 = color,
		Font = font or Theme.Fonts.Body,
		TextScaled = true,
		TextXAlignment = align or Enum.TextXAlignment.Center,
		Parent = parent,
	})
	UIKit.new("UITextSizeConstraint", { MaxTextSize = maxSize or 40, MinTextSize = 6, Parent = label })
	UIKit.TextStroke(label, 1.5)
	return label
end

local function chip(parent: Instance, text: string, color: Color3, position: UDim2, size: UDim2, anchor: Vector2?)
	local frame = UIKit.new("Frame", {
		BackgroundColor3 = color,
		Position = position,
		Size = size,
		AnchorPoint = anchor or Vector2.zero,
		Parent = parent,
	})
	UIKit.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = frame })
	scaledLabel(frame, text, UDim2.fromScale(0.06, 0.1), UDim2.fromScale(0.88, 0.8), Color3.new(1, 1, 1), Theme.Fonts.Body, 16)
	return frame
end

-- Builds a ViewportFrame showing the creature. Returns (viewport, model).
function CardView.Viewport(parent: Instance, id: string, mutation: string?): (ViewportFrame, Model)
	local viewport = UIKit.new("ViewportFrame", {
		Name = "Viewport",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(170, 170, 190),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-1, -1.5, 1),
		Parent = parent,
	})
	local model = CreatureBuilder.Build(id, { Mutation = mutation, Effects = false })
	model.Parent = viewport
	local cf, size = model:GetBoundingBox()
	local radius = size.Magnitude / 2
	local camera = Instance.new("Camera")
	camera.FieldOfView = 38
	local distance = radius / math.tan(math.rad(19)) * 1.02
	camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(radius * 0.45, radius * 0.25, -distance), cf.Position)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return viewport, model
end

-- Slowly rotates a viewport model (used on detail cards). Returns a stop function.
function CardView.Spin(model: Model): () -> ()
	local pivot = model:GetPivot()
	local angle = 0
	local connection = RunService.RenderStepped:Connect(function(dt)
		if not model.Parent then
			return
		end
		angle += dt * 0.8
		model:PivotTo(pivot * CFrame.Angles(0, angle, 0))
	end)
	return function()
		connection:Disconnect()
	end
end

function CardView.Create(parent: Instance?, info: Info, props: Props?): GuiObject
	local p: Props = props or {}
	local def = Catalog.Get(info.Id)
	local rarityName = def and def.Rarity or "Common"
	local rarity = RarityConfig.Rarities[rarityName]
	local element = def and CollectibleConfig.Elements[def.Element]
	local mutation = MutationConfig.Mutations[info.Mutation or "Normal"] or MutationConfig.Mutations.Normal
	local trait = TraitConfig.Get(info.Trait)
	local frameCosmetic = CosmeticConfig.Get(info.FrameId) or CosmeticConfig.Items.Frame_Classic
	local hidden = info.Undiscovered == true

	local card: GuiObject
	if p.OnClick then
		local button = UIKit.new("TextButton", { Text = "", AutoButtonColor = false, Selectable = true })
		local scale = UIKit.new("UIScale", { Name = "AnimScale", Parent = button })
		button.MouseEnter:Connect(function()
			UIKit.Tween(scale, 0.12, { Scale = 1.05 })
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
		button.Activated:Connect(function()
			(p.OnClick :: () -> ())()
		end)
		card = button
	else
		card = UIKit.new("Frame", {})
	end
	card.Name = p.Name or "Card"
	card.Size = p.Size or UDim2.fromOffset(150, 210)
	card.Position = p.Position or UDim2.new()
	card.AnchorPoint = p.AnchorPoint or Vector2.zero
	card.LayoutOrder = p.LayoutOrder or 0
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	UIKit.new("UICorner", { CornerRadius = UDim.new(0.07, 0), Parent = card })
	local gradient = UIKit.new("UIGradient", { Rotation = 90, Parent = card })
	if hidden then
		gradient.Color = ColorSequence.new(Color3.fromRGB(60, 62, 90), Color3.fromRGB(30, 32, 52))
	elseif rarity.Rainbow then
		gradient.Color = CardBillboard.RainbowSequence
		gradient.Rotation = 45
		CollectionService:AddTag(gradient, "AnimatedGradient")
	else
		gradient.Color = ColorSequence.new(rarity.Gradient[1], rarity.Gradient[2])
	end
	local stroke = UIKit.Stroke(card, Color3.new(1, 1, 1), 3)
	local strokeGradient = UIKit.new("UIGradient", { Rotation = 45, Parent = stroke })
	if frameCosmetic.Rainbow then
		strokeGradient.Color = CardBillboard.RainbowSequence
		CollectionService:AddTag(strokeGradient, "AnimatedGradient")
	else
		strokeGradient.Color = ColorSequence.new(frameCosmetic.Colors[1], frameCosmetic.Colors[2])
	end

	scaledLabel(card, string.upper(rarity.Name), UDim2.fromScale(0.06, 0.015), UDim2.fromScale(0.88, 0.085), Color3.new(1, 1, 1), Theme.Fonts.Title, 18)

	-- Artwork
	local art = UIKit.new("Frame", {
		Name = "Art",
		BackgroundColor3 = Color3.fromRGB(20, 22, 44),
		Position = UDim2.fromScale(0.06, 0.11),
		Size = UDim2.fromScale(0.88, 0.5),
		ClipsDescendants = true,
		Parent = card,
	})
	UIKit.new("UICorner", { CornerRadius = UDim.new(0.08, 0), Parent = art })
	local elementColor = element and element.Color or Color3.fromRGB(120, 120, 160)
	UIKit.Gradient(art, { elementColor:Lerp(Color3.new(1, 1, 1), 0.15), elementColor:Lerp(Color3.new(0, 0, 0), 0.65) }, 120)
	if hidden then
		scaledLabel(art, "?", UDim2.fromScale(0.1, 0.1), UDim2.fromScale(0.8, 0.8), Color3.fromRGB(150, 150, 190), Theme.Fonts.Title, 90)
	elseif def and def.ImageId then
		UIKit.new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = def.ImageId, ScaleType = Enum.ScaleType.Fit, Parent = art })
	elseif p.Viewport and def then
		CardView.Viewport(art, def.Id, info.Mutation)
	else
		scaledLabel(art, element and element.Icon or "★", UDim2.fromScale(0.15, 0.08), UDim2.fromScale(0.7, 0.62), Color3.new(1, 1, 1), Theme.Fonts.Body, 80)
		scaledLabel(art, def and string.sub(def.Name, 1, 1) or "?", UDim2.fromScale(0.3, 0.68), UDim2.fromScale(0.4, 0.28), Color3.new(1, 1, 1), Theme.Fonts.Title, 36)
	end
	if not hidden and mutation.Tier > 0 then
		chip(art, mutation.Icon .. " " .. string.upper(mutation.Name), mutation.Color:Lerp(Color3.new(0, 0, 0), 0.35), UDim2.fromScale(0.04, 0.96), UDim2.fromScale(0.62, 0.17), Vector2.new(0, 1))
	end
	if not hidden and trait then
		chip(art, trait.Icon, trait.Color:Lerp(Color3.new(0, 0, 0), 0.4), UDim2.fromScale(0.96, 0.96), UDim2.fromScale(0.22, 0.17), Vector2.new(1, 1))
	end
	if not hidden and info.Level and info.Level > 1 then
		chip(art, "Lv" .. info.Level, Color3.fromRGB(40, 40, 70), UDim2.fromScale(0.96, 0.04), UDim2.fromScale(0.32, 0.16), Vector2.new(1, 0))
	end
	if info.Locked then
		chip(art, "⭐", Color3.fromRGB(200, 150, 20), UDim2.fromScale(0.04, 0.04), UDim2.fromScale(0.2, 0.16))
	end
	if info.Stored then
		chip(art, "📦", Color3.fromRGB(80, 80, 110), UDim2.fromScale(if info.Locked then 0.26 else 0.04, 0.04), UDim2.fromScale(0.2, 0.16))
	end
	if info.Badge then
		chip(card, info.Badge, Color3.fromRGB(230, 50, 80), UDim2.fromScale(0.98, 0.0), UDim2.fromScale(0.4, 0.09), Vector2.new(1, 0.3))
	end

	-- Text
	scaledLabel(card, if hidden then "???" else (def and def.Name or "Unknown"), UDim2.fromScale(0.05, 0.625), UDim2.fromScale(0.9, 0.11), Color3.new(1, 1, 1), Theme.Fonts.Title, 26)
	local line: string
	local lineColor = Theme.Colors.Cash
	if hidden then
		line = def and (def.Element .. " • " .. rarity.Name) or ""
		lineColor = Color3.fromRGB(200, 200, 230)
	elseif info.Subtitle then
		line = info.Subtitle
		lineColor = Color3.fromRGB(255, 240, 180)
	elseif info.Price then
		line = Format.Cash(info.Price)
	else
		local income = info.Income or Economy.ItemIncome({ Uid = "", Id = info.Id, Mutation = info.Mutation, Trait = info.Trait, Level = info.Level })
		line = "+" .. Format.PerSec(income)
	end
	scaledLabel(card, line, UDim2.fromScale(0.05, 0.745), UDim2.fromScale(0.9, 0.1), lineColor, Theme.Fonts.Body, 20)
	local footerLeft = Format.Number(def and def.Number or 0)
	local footerRight = if info.Count then ("x" .. info.Count) elseif info.Serial and info.Serial > 0 then Format.Serial(info.Serial) else ""
	scaledLabel(card, footerLeft, UDim2.fromScale(0.06, 0.875), UDim2.fromScale(0.44, 0.08), Color3.fromRGB(235, 235, 245), Theme.Fonts.Regular, 14, Enum.TextXAlignment.Left)
	scaledLabel(card, footerRight, UDim2.fromScale(0.5, 0.875), UDim2.fromScale(0.44, 0.08), Color3.fromRGB(235, 235, 245), Theme.Fonts.Regular, 14, Enum.TextXAlignment.Right)

	card.Parent = parent
	return card
end

return CardView
