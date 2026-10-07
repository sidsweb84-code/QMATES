--[[
	CardBillboard
	The floating trading-card display above every creature in the world.
	Shows rarity, name, element, mutation, trait, income, level and serial
	(base / showcase mode) or price (conveyor mode).
]]

local CollectionService = game:GetService("CollectionService")

local Shared = script.Parent
local Config = Shared.Config
local RarityConfig = require(Config.RarityConfig)
local MutationConfig = require(Config.MutationConfig)
local TraitConfig = require(Config.TraitConfig)
local CollectibleConfig = require(Config.CollectibleConfig)
local CosmeticConfig = require(Config.CosmeticConfig)
local Catalog = require(Shared.Catalog)
local Format = require(Shared.Util.Format)

local CardBillboard = {}

local TITLE_FONT = Enum.Font.FredokaOne
local BODY_FONT = Enum.Font.GothamBold

export type Info = {
	Mode: string, -- "Conveyor" | "Base" | "Showcase"
	Id: string,
	Mutation: string?,
	Trait: string?,
	Level: number?,
	Serial: number?,
	Price: number?,
	Income: number?,
	OwnerName: string?,
	FrameId: string?,
	RequiredRebirths: number?,
}

CardBillboard.RainbowSequence = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 200, 60)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(90, 230, 110)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(70, 170, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(180, 90, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 80, 80)),
})

local function label(parent: Instance, name: string, text: string, size: UDim2, position: UDim2, color: Color3, font: Enum.Font?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.Text = text
	l.TextColor3 = color
	l.TextScaled = true
	l.Font = font or BODY_FONT
	local s = Instance.new("UIStroke")
	s.Thickness = 1.5
	s.Color = Color3.fromRGB(15, 15, 30)
	s.Parent = l
	l.Parent = parent
	return l
end

local function pill(parent: Instance, name: string, text: string, color: Color3, size: UDim2, position: UDim2): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = 0.1
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	label(frame, "Text", text, UDim2.fromScale(0.9, 0.8), UDim2.fromScale(0.05, 0.1), Color3.new(1, 1, 1))
	frame.Parent = parent
	return frame
end

function CardBillboard.Build(info: Info, height: number): BillboardGui
	local def = Catalog.Get(info.Id)
	local rarityName = def and def.Rarity or "Common"
	local rarity = RarityConfig.Rarities[rarityName]
	local element = def and CollectibleConfig.Elements[def.Element]
	local mutation = MutationConfig.Mutations[info.Mutation or "Normal"] or MutationConfig.Mutations.Normal
	local trait = TraitConfig.Get(info.Trait)
	local frameCosmetic = CosmeticConfig.Get(info.FrameId) or CosmeticConfig.Items.Frame_Classic

	local gui = Instance.new("BillboardGui")
	gui.Name = "Card"
	gui.Size = UDim2.fromScale(4.6, 5.6)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height + 3.4, 0)
	gui.MaxDistance = if info.Mode == "Conveyor" then 75 elseif info.Mode == "Showcase" then 90 else 48
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.ResetOnSpawn = false
	gui:SetAttribute("CardMode", info.Mode)

	local card = Instance.new("Frame")
	card.Name = "Frame"
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	card.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.08, 0)
	corner.Parent = card
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	if rarity.Rainbow then
		gradient.Color = CardBillboard.RainbowSequence
		gradient.Rotation = 45
		CollectionService:AddTag(gradient, "AnimatedGradient")
	else
		gradient.Color = ColorSequence.new(rarity.Gradient[1], rarity.Gradient[2])
	end
	gradient.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.new(1, 1, 1)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = card
	local strokeGradient = Instance.new("UIGradient")
	if frameCosmetic.Rainbow then
		strokeGradient.Color = CardBillboard.RainbowSequence
		CollectionService:AddTag(strokeGradient, "AnimatedGradient")
	else
		local colors = frameCosmetic.Colors or { Color3.new(1, 1, 1), Color3.new(0.8, 0.8, 0.8) }
		strokeGradient.Color = ColorSequence.new(colors[1], colors[2])
	end
	strokeGradient.Rotation = 45
	strokeGradient.Parent = stroke

	-- Inner dark panel
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.Size = UDim2.fromScale(0.9, 0.7)
	inner.Position = UDim2.fromScale(0.05, 0.25)
	inner.BackgroundColor3 = Color3.fromRGB(22, 24, 44)
	inner.BackgroundTransparency = 0.15
	inner.Parent = card
	local innerCorner = Instance.new("UICorner")
	innerCorner.CornerRadius = UDim.new(0.08, 0)
	innerCorner.Parent = inner

	label(card, "Rarity", string.upper(rarity.Name), UDim2.fromScale(0.9, 0.1), UDim2.fromScale(0.05, 0.02), Color3.new(1, 1, 1), TITLE_FONT)
	label(card, "Name", def and def.Name or "???", UDim2.fromScale(0.9, 0.12), UDim2.fromScale(0.05, 0.12), Color3.new(1, 1, 1), TITLE_FONT)

	local elementIcon = element and element.Icon or ""
	label(inner, "Element", elementIcon .. " " .. (def and def.Element or ""), UDim2.fromScale(0.9, 0.13), UDim2.fromScale(0.05, 0.03), element and element.Color or Color3.new(1, 1, 1))

	if mutation.Tier > 0 then
		pill(inner, "Mutation", mutation.Icon .. " " .. string.upper(mutation.Name), mutation.Color:Lerp(Color3.new(0, 0, 0), 0.35), UDim2.fromScale(0.9, 0.14), UDim2.fromScale(0.05, 0.18))
	end

	if info.Mode == "Conveyor" then
		label(inner, "Value", Format.Cash(info.Price or 0), UDim2.fromScale(0.94, 0.26), UDim2.fromScale(0.03, 0.36), Color3.fromRGB(140, 255, 150), TITLE_FONT)
		label(inner, "Income", "+" .. Format.PerSec(info.Income or 0), UDim2.fromScale(0.9, 0.14), UDim2.fromScale(0.05, 0.63), Color3.fromRGB(255, 230, 120))
		if (info.RequiredRebirths or 0) > 0 then
			label(inner, "Gate", "♻️ Rebirth " .. tostring(info.RequiredRebirths) .. "+", UDim2.fromScale(0.9, 0.13), UDim2.fromScale(0.05, 0.8), Color3.fromRGB(255, 140, 140))
		elseif trait then
			label(inner, "Trait", trait.Icon .. " " .. trait.Name, UDim2.fromScale(0.9, 0.13), UDim2.fromScale(0.05, 0.8), trait.Color)
		end
	else
		label(inner, "Value", "+" .. Format.PerSec(info.Income or 0), UDim2.fromScale(0.94, 0.24), UDim2.fromScale(0.03, 0.36), Color3.fromRGB(140, 255, 150), TITLE_FONT)
		label(inner, "Level", "Lv " .. tostring(info.Level or 1), UDim2.fromScale(0.42, 0.13), UDim2.fromScale(0.05, 0.63), Color3.fromRGB(255, 230, 120))
		label(inner, "Serial", Format.Serial(info.Serial or 0), UDim2.fromScale(0.48, 0.13), UDim2.fromScale(0.47, 0.63), Color3.fromRGB(200, 205, 230))
		if trait then
			label(inner, "Trait", trait.Icon .. " " .. trait.Name, UDim2.fromScale(0.9, 0.13), UDim2.fromScale(0.05, 0.8), trait.Color)
		elseif info.OwnerName then
			label(inner, "Owner", info.OwnerName, UDim2.fromScale(0.9, 0.13), UDim2.fromScale(0.05, 0.8), Color3.fromRGB(200, 205, 230))
		end
	end

	label(card, "Number", Format.Number(def and def.Number or 0), UDim2.fromScale(0.5, 0.05), UDim2.fromScale(0.45, 0.945), Color3.fromRGB(230, 230, 240))
	return gui
end

-- Rebuilds the card in place (after level up / serial assignment).
function CardBillboard.Attach(model: Model, info: Info): BillboardGui
	local root = model.PrimaryPart or model:FindFirstChild("Root")
	local existing = root and root:FindFirstChild("Card")
	if existing then
		existing:Destroy()
	end
	local height = model:GetAttribute("Height") or 4
	local gui = CardBillboard.Build(info, height)
	gui.Parent = root
	return gui
end

return CardBillboard
