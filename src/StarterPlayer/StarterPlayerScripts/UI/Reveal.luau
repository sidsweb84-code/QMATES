--[[
	Reveal
	Acquisition animations, escalating with rarity (RarityConfig.RevealTier):
		1  simple card slide-in
		2  centre pop + glow rays + sparkles
		3  golden flash, card flip, camera emphasis (Legendary)
		4  darkened screen, shaking card, colour grade, dramatic sound (Mythic/Divine/Limited)
		5  cinematic: letterbox, heartbeat, silhouette, shatter, rainbow (Secret)
	Mutations, NEW discoveries, bonus mutations and steals are called out.
	Reveals queue up and can be skipped with a click / tap / A button.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local RarityConfig = require(Config.RarityConfig)
local MutationConfig = require(Config.MutationConfig)
local Catalog = require(Shared.Catalog)
local Format = require(Shared.Util.Format)
local CardBillboard = require(Shared.CardBillboard)

local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)
local Root = require(script.Parent.Root)
local CardView = require(script.Parent.CardView)
local Sound = require(script.Parent.Parent.Controllers.Sound)
local Effects = require(script.Parent.Parent.Controllers.Effects)
local State = require(script.Parent.Parent.Controllers.State)

local Reveal = {}

local queue: { any } = {}
local playing = false
local skipRequested = false

local layer = UIKit.new("Frame", {
	Name = "Reveal",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 30,
	Parent = Root.TopCanvas,
})

local darkness = UIKit.new("Frame", {
	Name = "Darkness",
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	Parent = Root.FX,
})
local topBar = UIKit.new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), Parent = Root.FX })
local bottomBar = UIKit.new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 0), Parent = Root.FX })

local function waitSkippable(seconds: number): boolean
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		if skipRequested then
			return true
		end
		RunService.RenderStepped:Wait()
	end
	return skipRequested
end

local function makeRays(color: Color3, rainbow: boolean, speed: number): (Frame, () -> ())
	local center = Root.VirtualSize / 2
	local holder = UIKit.new("Frame", {
		Name = "Rays",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(center.X, center.Y - 20),
		Size = UDim2.fromOffset(900, 900),
		ZIndex = 31,
		Parent = layer,
	})
	for i = 0, 11 do
		local ray = UIKit.new("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.55,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 46, 1, 0),
			Rotation = i * 15,
			ZIndex = 31,
			Parent = holder,
		})
		local gradient = UIKit.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.1),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = ray,
		})
		gradient.Color = if rainbow then CardBillboard.RainbowSequence else ColorSequence.new(color, color:Lerp(Color3.new(1, 1, 1), 0.5))
	end
	local scale = UIKit.new("UIScale", { Scale = 0.3, Parent = holder })
	UIKit.Tween(scale, 0.6, { Scale = 1 }, Enum.EasingStyle.Back)
	local connection = RunService.RenderStepped:Connect(function(dt)
		holder.Rotation += dt * speed
	end)
	return holder, function()
		connection:Disconnect()
		UIKit.Tween(scale, 0.3, { Scale = 0 })
		task.delay(0.32, function()
			holder:Destroy()
		end)
	end
end

local function headline(text: string, color: Color3, y: number, size: number, rainbow: boolean?): TextLabel
	local label = UIKit.Label(layer, text, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, y),
		Size = UDim2.fromOffset(700, size + 10),
		TextSize = size,
		Font = Theme.Fonts.Title,
		Color = color,
		XAlign = Enum.TextXAlignment.Center,
		Stroke = 4,
	})
	label.ZIndex = 35
	if rainbow then
		local gradient = UIKit.new("UIGradient", { Color = CardBillboard.RainbowSequence, Parent = label })
		gradient:AddTag("AnimatedGradient")
	end
	local scale = UIKit.new("UIScale", { Scale = 0.2, Parent = label })
	UIKit.Tween(scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	return label
end

local function cardBack(rarity, size: Vector2): Frame
	local back = UIKit.Panel(nil, { Size = UDim2.fromOffset(size.X, size.Y), Color = Color3.new(1, 1, 1), Radius = 16 })
	if rarity.Rainbow then
		local g = UIKit.new("UIGradient", { Color = CardBillboard.RainbowSequence, Rotation = 45, Parent = back })
		g:AddTag("AnimatedGradient")
	else
		UIKit.Gradient(back, { rarity.Gradient[1], rarity.Gradient[2] }, 45)
	end
	UIKit.Stroke(back, Color3.new(1, 1, 1), 4)
	local inner = UIKit.Panel(back, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.82, 0.86), Color = Color3.fromRGB(20, 22, 44), Radius = 12 })
	UIKit.Label(inner, "?", { Size = UDim2.fromScale(1, 1), TextSize = 100, Font = Theme.Fonts.Title, XAlign = Enum.TextXAlignment.Center, Color = rarity.Color:Lerp(Color3.new(1, 1, 1), 0.4), Stroke = 4 })
	return back
end

local function flip(holder: Frame, width: number, height: number, duration: number)
	UIKit.Tween(holder, duration / 2, { Size = UDim2.fromOffset(0, height) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Wait()
	UIKit.Tween(holder, duration / 2, { Size = UDim2.fromOffset(width, height) }, Enum.EasingStyle.Back)
end

local function play(data)
	local item = data.Item
	local def = Catalog.Get(item.Id)
	if not def then
		return
	end
	skipRequested = false
	local rarity = RarityConfig.Rarities[def.Rarity]
	local mutation = MutationConfig.Mutations[item.Mutation or "Normal"]
	local tier = rarity.RevealTier
	-- Mutations bump the drama a little.
	if mutation and mutation.Tier >= 4 then
		tier = math.min(5, tier + 1)
	end
	if Effects.Graphics == "Low" and tier > 3 then
		tier = 3
	end
	local frameId = State.Data.Cosmetics and State.Data.Cosmetics.Equipped and State.Data.Cosmetics.Equipped.CardFrame
	local info = {
		Id = item.Id,
		Mutation = item.Mutation,
		Trait = item.Trait,
		Level = item.Level,
		Serial = item.Serial,
		Income = data.Income,
		FrameId = frameId,
		Badge = if data.IsNew then "NEW!" else nil,
	}
	local sourceText = if data.Source == "Steal" then "🦹 STOLEN!"
		elseif data.Source == "Pack" then "🃏 From a card pack"
		elseif data.Source == "Trade" then "🤝 From a trade"
		elseif data.Source == "Conveyor" then "🛒 Purchased"
		else "🎁 Reward"
	local mutationText = if mutation and mutation.Tier > 0 then (mutation.Icon .. " " .. string.upper(mutation.Name) .. " x" .. mutation.IncomeMultiplier) else nil

	---------------------------------------------------------------- tier 1
	if tier <= 1 then
		local v = Root.VirtualSize
		local card = CardView.Create(layer, info, { Size = UDim2.fromOffset(150, 210), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromOffset(v.X + 200, v.Y * 0.58) })
		card.ZIndex = 32
		Sound.Play("CardFlip")
		Sound.Play("RevealCommon")
		UIKit.Tween(card, 0.35, { Position = UDim2.fromOffset(v.X - 24, v.Y * 0.58) }, Enum.EasingStyle.Back)
		local caption = UIKit.Label(layer, (if data.IsNew then "✨ NEW! " else "") .. def.Name .. (if mutationText then ("  " .. mutationText) else ""), {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromOffset(v.X - 24, v.Y * 0.58 + 112),
			Size = UDim2.fromOffset(300, 24),
			TextSize = 18,
			XAlign = Enum.TextXAlignment.Right,
			Stroke = 2,
		})
		task.wait(1.7)
		UIKit.Tween(card, 0.3, { Position = UDim2.fromOffset(v.X + 200, v.Y * 0.58) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		UIKit.Tween(caption, 0.3, { TextTransparency = 1 })
		task.wait(0.32)
		card:Destroy()
		caption:Destroy()
		return
	end

	---------------------------------------------------------------- tiers 2-5
	local width, height = 230, 322
	if tier >= 4 then
		width, height = 260, 364
	end
	local stopRays: (() -> ())? = nil
	local labels: { Instance } = {}

	if tier >= 5 then
		Sound.Play("RevealWhoosh", { Pitch = 0.6 })
		UIKit.Tween(topBar, 0.6, { Size = UDim2.new(1, 0, 0.12, 0) })
		UIKit.Tween(bottomBar, 0.6, { Size = UDim2.new(1, 0, 0.12, 0) })
		Effects.Blur(14, 4.5)
	end
	if tier >= 4 then
		darkness.Visible = true
		UIKit.Tween(darkness, 0.5, { BackgroundTransparency = if tier >= 5 then 0.08 else 0.35 })
		Effects.Tint(rarity.Color:Lerp(Color3.new(1, 1, 1), 0.5), -0.2, if tier >= 5 then 4.5 else 3.2)
	elseif tier >= 2 then
		darkness.Visible = true
		UIKit.Tween(darkness, 0.3, { BackgroundTransparency = 0.6 })
	end

	local holder = UIKit.new("Frame", {
		Name = "CardHolder",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -10),
		Size = UDim2.fromOffset(width, height),
		ClipsDescendants = false,
		ZIndex = 33,
		Parent = layer,
	})
	local holderScale = UIKit.new("UIScale", { Scale = 0.2, Parent = holder })
	local back = cardBack(rarity, Vector2.new(width, height))
	back.Size = UDim2.fromScale(1, 1)
	back.Parent = holder
	UIKit.Tween(holderScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	Sound.Play("CardFlip", { Pitch = 0.9 })

	local skipped = false
	if tier >= 5 then
		-- Heartbeat build-up with a pulsing silhouette.
		for beat = 1, 3 do
			Sound.Play("RevealSecret", { Pitch = 0.45 + beat * 0.08, MinInterval = 0 })
			UIKit.Tween(holderScale, 0.12, { Scale = 1.08 }).Completed:Wait()
			UIKit.Tween(holderScale, 0.25, { Scale = 1 })
			Effects.Shake(0.6 * beat, 0.3)
			if waitSkippable(0.55) then
				skipped = true
				break
			end
		end
	elseif tier >= 4 then
		Sound.Play("RevealMythic")
		local start = os.clock()
		while os.clock() - start < 1.1 and not skipRequested do
			holder.Rotation = math.sin((os.clock() - start) * 40) * 4
			RunService.RenderStepped:Wait()
		end
		holder.Rotation = 0
		Effects.Shake(1.4, 0.6)
	elseif tier >= 3 then
		Sound.Play("RevealWhoosh")
		skipped = waitSkippable(0.5)
	else
		skipped = waitSkippable(0.25)
	end

	-- Flip to the front
	if tier >= 3 then
		Effects.Flash(if tier >= 5 then Color3.new(1, 1, 1) else rarity.Color:Lerp(Color3.new(1, 1, 1), 0.4), if tier >= 4 then 0.9 else 0.6, 0.05)
		Effects.FovPunch(if tier >= 5 then 14 else 8, 0.8)
	end
	flip(holder, width, height, 0.3)
	back:Destroy()
	local front = CardView.Create(holder, info, { Size = UDim2.fromScale(1, 1), Viewport = true })
	front.ZIndex = 34
	local viewport = front:FindFirstChild("Art") and (front :: any).Art:FindFirstChild("Viewport")
	local stopSpin: (() -> ())? = nil
	if viewport then
		local model = viewport:FindFirstChildOfClass("Model")
		if model then
			stopSpin = CardView.Spin(model)
		end
	end

	stopRays = select(2, makeRays(rarity.Color, rarity.Rainbow == true, if tier >= 4 then 40 else 15))
	local center = Root.VirtualSize / 2
	Effects.Burst(layer, Vector2.new(center.X, center.Y - 10), rarity.Color, if tier >= 4 then 36 else 18, if tier >= 4 then 360 else 240)
	if tier >= 3 then
		Sound.Play(if tier >= 5 then "RevealSecret" elseif tier >= 4 then "RevealMythic" else "RevealLegendary", { Pitch = if tier >= 4 then 1.6 else 1 })
		Sound.Play("RevealLegendary", { Pitch = 1.25 })
		Effects.Confetti(if tier >= 4 then 60 else 30)
	else
		Sound.Play("RevealRare")
	end

	local title = string.upper(rarity.Name) .. (if tier >= 5 then "!!!" elseif tier >= 3 then "!" else "")
	table.insert(labels, headline(title, rarity.Color:Lerp(Color3.new(1, 1, 1), 0.2), -height / 2 - 52, if tier >= 4 then 64 else 48, rarity.Rainbow))
	local subParts = {}
	if data.IsNew then
		table.insert(subParts, "✨ NEW DISCOVERY")
	end
	if mutationText then
		table.insert(subParts, mutationText .. (if data.BonusMutation then " (luck bonus!)" else ""))
	end
	table.insert(labels, headline(def.Name .. "  •  +" .. Format.PerSec(data.Income or 0), Color3.new(1, 1, 1), height / 2 + 30, 30))
	if #subParts > 0 then
		table.insert(labels, headline(table.concat(subParts, "   "), Color3.fromRGB(255, 235, 140), height / 2 + 66, 22))
	end
	local sourceLine = sourceText .. (if data.Stored then "  •  Base full — sent to storage 📦" else "")
	table.insert(labels, headline(sourceLine, Color3.fromRGB(200, 205, 235), height / 2 + 96, 18))
	local hint = headline("Click to continue", Color3.fromRGB(170, 175, 210), height / 2 + 128, 15)
	table.insert(labels, hint)

	if not skipped then
		waitSkippable(if tier >= 5 then 3.6 elseif tier >= 4 then 3 elseif tier >= 3 then 2.6 else 1.9)
	end

	-- Outro
	if stopRays then
		stopRays()
	end
	if stopSpin then
		stopSpin()
	end
	UIKit.Tween(holderScale, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	for _, label in labels do
		UIKit.Tween(label :: TextLabel, 0.25, { TextTransparency = 1 })
	end
	UIKit.Tween(darkness, 0.3, { BackgroundTransparency = 1 })
	UIKit.Tween(topBar, 0.4, { Size = UDim2.new(1, 0, 0, 0) })
	UIKit.Tween(bottomBar, 0.4, { Size = UDim2.new(1, 0, 0, 0) })
	task.wait(0.32)
	holder:Destroy()
	for _, label in labels do
		label:Destroy()
	end
	darkness.Visible = false
end

local function pump()
	if playing then
		return
	end
	playing = true
	task.spawn(function()
		while #queue > 0 do
			local data = table.remove(queue, 1)
			local ok, err = pcall(play, data)
			if not ok then
				warn("[Reveal] " .. tostring(err))
			end
		end
		playing = false
	end)
end

function Reveal.Show(data)
	-- Collapse big queues of commons so players aren't stuck watching.
	if #queue >= 4 then
		local def = data.Item and Catalog.Get(data.Item.Id)
		if def and RarityConfig.Rarities[def.Rarity].RevealTier <= 1 then
			return
		end
	end
	table.insert(queue, data)
	pump()
end

UserInputService.InputBegan:Connect(function(input)
	if not playing then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA then
		skipRequested = true
	end
end)

return Reveal
