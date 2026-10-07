--[[
	World
	All client-side world animation, in ONE render loop:
	- conveyor items (position computed from server attributes, no replication)
	- purchased critters walking home, idle animations near the camera
	- rainbow / glitch mutations, animated card gradients, belt chevrons
	- base sign countdowns, alarm lights, intruder highlights
	- collector pad auto-collect request, Elite Market gate
	Graphics settings control level of detail.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local MapConfig = require(Config.MapConfig)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)

local Sound = require(script.Parent.Sound)
local State = require(script.Parent.State)

local player = Players.LocalPlayer

local World = {}
World.Graphics = "High"
World.CardLabels = true

type Tracked = {
	Model: Model,
	Root: BasePart,
	Anim: string,
	Phase: number,
}

local conveyorItems: { [Model]: Tracked & { Start: Vector3, Dir: Vector3, Speed: number, SpawnTime: number, Length: number } } = {}
local creatures: { [Model]: Tracked & { Home: CFrame } } = {}
local gradients: { [UIGradient]: boolean } = {}
local chevrons: { [BasePart]: { Base: CFrame, Dir: Vector3, Spacing: number } } = {}
local floaters: { [BasePart]: { Base: CFrame, Phase: number } } = {}
local highlights: { [Model]: Highlight } = {}

local function hashPhase(text: string?): number
	local h = 0
	for i = 1, #(text or "") do
		h = (h * 31 + string.byte(text :: string, i)) % 1000
	end
	return h / 1000 * math.pi * 2
end

-- Idle animation offset for a given style.
local function idleOffset(style: string, t: number): CFrame
	if style == "Hop" then
		return CFrame.new(0, math.abs(math.sin(t * 3)) * 0.7, 0)
	elseif style == "Float" then
		return CFrame.new(0, 0.6 + math.sin(t * 1.6) * 0.35, 0)
	elseif style == "Sway" then
		return CFrame.new(0, math.sin(t * 2) * 0.15, 0) * CFrame.Angles(0, math.sin(t * 1.2) * 0.3, 0)
	elseif style == "Spin" then
		return CFrame.new(0, 0.4 + math.sin(t * 1.5) * 0.25, 0) * CFrame.Angles(0, t * 0.8, 0)
	elseif style == "Slither" then
		return CFrame.Angles(0, math.sin(t * 2) * 0.35, 0)
	end
	return CFrame.new(0, math.sin(t * 2) * 0.25, 0)
end

---------------------------------------------------------------- tracking
local function rootOf(model: Instance): BasePart?
	if not model:IsA("Model") then
		return nil
	end
	return model.PrimaryPart or model:FindFirstChild("Root") :: BasePart?
end

local function applyCardSetting(root: BasePart)
	local card = root:FindFirstChild("Card")
	if card and card:IsA("BillboardGui") then
		card.Enabled = World.CardLabels
	end
end

local function trackConveyor(model: Instance)
	local root = rootOf(model)
	if not root then
		return
	end
	local m = model :: Model
	conveyorItems[m] = {
		Model = m,
		Root = root,
		Anim = model:GetAttribute("Animation") or "Bob",
		Phase = hashPhase(tostring(model:GetAttribute("Uid"))),
		Start = model:GetAttribute("Start") or Vector3.zero,
		Dir = model:GetAttribute("Direction") or Vector3.xAxis,
		Speed = model:GetAttribute("Speed") or 7,
		SpawnTime = model:GetAttribute("SpawnTime") or 0,
		Length = model:GetAttribute("Length") or 300,
	}
	applyCardSetting(root)
end

local function trackCreature(model: Instance)
	local root = rootOf(model)
	if not root then
		return
	end
	local m = model :: Model
	creatures[m] = {
		Model = m,
		Root = root,
		Anim = model:GetAttribute("Animation") or "Bob",
		Phase = hashPhase(tostring(model:GetAttribute("Uid") or model.Name)),
		Home = model:GetAttribute("HomeCFrame") or root.CFrame,
	}
	applyCardSetting(root)
	if model:GetAttribute("TravelFrom") and model:GetAttribute("OwnerUserId") == player.UserId then
		Sound.Play("CardFlip", { Pitch = 1.4, MinInterval = 0.2 })
	end
end

local function untrack(model: Instance)
	conveyorItems[model :: Model] = nil
	creatures[model :: Model] = nil
end

---------------------------------------------------------------- per-frame
local function updateConveyor(now: number, t: number, camPos: Vector3)
	for model, item in conveyorItems do
		if not model.Parent then
			conveyorItems[model] = nil
			continue
		end
		local travelled = math.clamp((now - item.SpawnTime) * item.Speed, 0, item.Length)
		local pos = item.Start + item.Dir * travelled
		local cf = CFrame.lookAt(pos, pos + item.Dir)
		if World.Graphics ~= "Low" and (pos - camPos).Magnitude < 160 then
			cf *= idleOffset(item.Anim, t * 1.3 + item.Phase)
		end
		item.Root.CFrame = cf
	end
end

local function travelCFrame(model: Model, home: CFrame, now: number): CFrame?
	local start = model:GetAttribute("TravelStart")
	local duration = model:GetAttribute("TravelDuration")
	local from = model:GetAttribute("TravelFrom")
	if not start or not duration or not from or now >= start + duration then
		return nil
	end
	local entrance = model:GetAttribute("Entrance") or home.Position
	local a, b, c = from :: Vector3, entrance :: Vector3, home.Position
	local l1 = (b - a).Magnitude
	local l2 = (c - b).Magnitude
	local total = math.max(l1 + l2, 0.01)
	local d = math.clamp((now - start) / duration, 0, 1) * total
	local pos, dir
	if d <= l1 then
		pos = a:Lerp(b, if l1 > 0 then d / l1 else 1)
		dir = b - a
	else
		pos = b:Lerp(c, if l2 > 0 then (d - l1) / l2 else 1)
		dir = c - b
	end
	pos = Vector3.new(pos.X, math.max(pos.Y, c.Y), pos.Z)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	local cf = if flat.Magnitude > 0.01 then CFrame.lookAt(pos, pos + flat) else CFrame.new(pos) * home.Rotation
	return cf * CFrame.new(0, math.abs(math.sin(now * 9)) * 0.8, 0)
end

-- Idle animation level of detail: range (studs) and max animated per frame.
local IDLE_LOD = {
	High = { Range = 110, Budget = 45 },
	Medium = { Range = 70, Budget = 20 },
	Low = { Range = 0, Budget = 0 },
}

local function updateCreatures(now: number, t: number, camPos: Vector3)
	local lod = IDLE_LOD[World.Graphics] or IDLE_LOD.High
	local idleRange = lod.Range
	local budget = lod.Budget
	for model, creature in creatures do
		if not model.Parent then
			creatures[model] = nil
			continue
		end
		if model:GetAttribute("Carried") then
			continue
		end
		local traveling = travelCFrame(model, creature.Home, now)
		if traveling then
			creature.Root.CFrame = traveling
		elseif budget > 0 and (creature.Home.Position - camPos).Magnitude < idleRange then
			budget -= 1
			creature.Root.CFrame = creature.Home * idleOffset(creature.Anim, t + creature.Phase)
		elseif creature.Root.CFrame ~= creature.Home then
			creature.Root.CFrame = creature.Home
		end
	end
end

local function updateCosmetics(dt: number, t: number)
	for gradient in gradients do
		if gradient.Parent then
			gradient.Rotation = (gradient.Rotation + dt * 90) % 360
		else
			gradients[gradient] = nil
		end
	end
	for part, info in chevrons do
		local offset = (t * 7) % info.Spacing
		part.CFrame = info.Base + info.Dir * offset
	end
	for part, info in floaters do
		if part.Parent then
			part.CFrame = info.Base * CFrame.new(0, math.sin(t * 0.8 + info.Phase) * 1.5, 0) * CFrame.Angles(0, t * 0.4 + info.Phase, 0)
		else
			floaters[part] = nil
		end
	end
end

---------------------------------------------------------------- slower updates (10 Hz)
local lastSlow = 0
local glitchToggle = false

local function updateMutations(t: number, camPos: Vector3)
	glitchToggle = not glitchToggle
	for model, creature in creatures do
		if (creature.Home.Position - camPos).Magnitude > 120 then
			continue
		end
		if model:GetAttribute("Rainbow") then
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") then
					local hue = part:GetAttribute("Hue")
					if hue then
						part.Color = Color3.fromHSV((hue + t * 0.25) % 1, 0.75, 1)
					end
				end
			end
		elseif model:GetAttribute("Glitch") and World.Graphics ~= "Low" then
			for _, part in model:GetChildren() do
				if part:IsA("BasePart") and part.Name ~= "Root" and math.random() < 0.15 then
					part.LocalTransparencyModifier = if glitchToggle then 0.6 else 0
				end
			end
		end
	end
end

local function plotsFolder(): Instance?
	local w = Workspace:FindFirstChild("World")
	return w and w:FindFirstChild("Plots")
end

local function isInsidePlot(index: number, position: Vector3): boolean
	local origin = MapConfig.PlotOrigins[index]
	if not origin then
		return false
	end
	local p = origin:PointToObjectSpace(position)
	local minB, maxB = MapConfig.Plot.BoundsMin, MapConfig.Plot.BoundsMax
	return p.X >= minB.X and p.X <= maxB.X and p.Y >= minB.Y and p.Y <= maxB.Y and p.Z >= minB.Z and p.Z <= maxB.Z
end

local alarmPlaying = false
local lastCollect = 0

local function updatePlots(t: number)
	local folder = plotsFolder()
	if not folder then
		return
	end
	local now = workspace:GetServerTimeNow()
	local myIndex = player:GetAttribute("PlotIndex")
	local myTheft = false
	for _, plot in folder:GetChildren() do
		local status = plot:GetAttribute("Status")
		local sign = plot:FindFirstChild("Sign")
		local statusLabel = sign and sign:FindFirstChild("Gui") and (sign :: any).Gui.Frame:FindFirstChild("Status") :: TextLabel?
		if statusLabel and plot:GetAttribute("OwnerUserId") ~= 0 then
			if status == "Locked" then
				statusLabel.Text = "🔒 LOCKED " .. math.max(0, math.ceil((plot:GetAttribute("LockEndsAt") or 0) - now)) .. "s"
			elseif status == "Shielded" or status == "Protected" then
				local untilTime = plot:GetAttribute("ProtectedUntil") or 0
				statusLabel.Text = (if status == "Shielded" then "🛡️ SHIELD " else "🛡️ SAFE ") .. (if untilTime > now then Format.Clock(untilTime - now) else "")
			elseif status == "Theft" then
				statusLabel.Text = if math.floor(t * 4) % 2 == 0 then "🚨 THIEF!" else "🚨 ALARM!"
			end
		end
		-- Flash alarm lights for any base under attack.
		if status == "Theft" then
			local color = if math.floor(t * 6) % 2 == 0 then Color3.fromRGB(255, 40, 60) else Color3.fromRGB(255, 255, 255)
			for _, child in plot:GetChildren() do
				if child.Name == "SecurityLight" and child:IsA("BasePart") then
					child.Color = color
				end
			end
			if plot:GetAttribute("PlotIndex") == myIndex then
				myTheft = true
			end
		end
	end
	if myTheft and not alarmPlaying then
		alarmPlaying = true
		task.spawn(function()
			while alarmPlaying do
				Sound.Play("StealAlarm", { MinInterval = 0.5 })
				task.wait(0.9)
			end
		end)
	elseif not myTheft then
		alarmPlaying = false
	end

	-- Intruder highlights (Theft Detection level 2)
	local myPlot = myIndex and folder:FindFirstChild("Plot" .. myIndex)
	local highlightOn = myPlot and myPlot:GetAttribute("HighlightIntruders") == true
	for _, other in Players:GetPlayers() do
		if other ~= player and other.Character then
			local character = other.Character
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local inside = highlightOn and root and isInsidePlot(myIndex, root.Position)
			if inside and not highlights[character] then
				local h = Instance.new("Highlight")
				h.FillColor = Color3.fromRGB(255, 50, 70)
				h.OutlineColor = Color3.new(1, 1, 1)
				h.FillTransparency = 0.5
				h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				h.Adornee = character
				h.Parent = character
				highlights[character] = h
			elseif not inside and highlights[character] then
				highlights[character]:Destroy()
				highlights[character] = nil
			end
		end
	end
	for character, h in highlights do
		if not character.Parent then
			h:Destroy()
			highlights[character] = nil
		end
	end

	-- Collector pad: request a collect while standing on our pad.
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if myPlot and root and MapConfig.PlotOrigins[myIndex] then
		local pad = (MapConfig.PlotOrigins[myIndex] * CFrame.new(MapConfig.Plot.CollectPad)).Position
		local offset = root.Position - pad
		local uncollected = myPlot:GetAttribute("Uncollected") or 0
		if Vector3.new(offset.X, 0, offset.Z).Magnitude < 4.6 and math.abs(offset.Y) < 7 and uncollected >= 1 and os.clock() - lastCollect > 0.8 then
			lastCollect = os.clock()
			task.spawn(Net.Request, "CollectCash")
		end
	end
end

local function updateGate()
	for _, gate in CollectionService:GetTagged("EliteGate") do
		if gate:IsA("BasePart") then
			local allowed = (State.Data.Rebirths or 0) >= (gate:GetAttribute("RequiredRebirths") or 1)
			gate.CanCollide = not allowed
			gate.LocalTransparencyModifier = if allowed then 0.6 else 0
		end
	end
end

---------------------------------------------------------------- settings
function World.ApplyGraphics(level: string)
	World.Graphics = level
	for _, emitter in CollectionService:GetTagged("CreatureFX") do
		if emitter:IsA("ParticleEmitter") then
			emitter.Enabled = level ~= "Low"
		end
	end
end

function World.SetCardLabels(enabled: boolean)
	World.CardLabels = enabled
	for _, set in { conveyorItems, creatures } :: { any } do
		for _, tracked in set do
			applyCardSetting(tracked.Root)
		end
	end
end

---------------------------------------------------------------- start
local function watch(tag: string, onAdd: (Instance) -> (), onRemove: ((Instance) -> ())?)
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst)
		task.defer(onAdd, inst)
	end)
	if onRemove then
		CollectionService:GetInstanceRemovedSignal(tag):Connect(onRemove)
	end
	for _, inst in CollectionService:GetTagged(tag) do
		task.spawn(onAdd, inst)
	end
end

function World.Start()
	watch("ConveyorItem", trackConveyor, untrack)
	watch("BaseCreature", trackCreature, untrack)
	watch("ShowcaseCreature", trackCreature, untrack)
	watch("AnimatedGradient", function(inst)
		if inst:IsA("UIGradient") then
			gradients[inst] = true
		end
	end)
	watch("ConveyorChevron", function(inst)
		if inst:IsA("BasePart") then
			local parent = inst.Parent
			chevrons[inst] = {
				Base = inst:GetAttribute("BaseCFrame") or inst.CFrame,
				Dir = parent and parent:GetAttribute("Direction") or Vector3.xAxis,
				Spacing = parent and parent:GetAttribute("Spacing") or 12,
			}
		end
	end)
	watch("FloatingCard", function(inst)
		if inst:IsA("BasePart") then
			floaters[inst] = { Base = inst:GetAttribute("BaseCFrame") or inst.CFrame, Phase = math.random() * 6 }
		end
	end)
	watch("CreatureFX", function(inst)
		if inst:IsA("ParticleEmitter") then
			inst.Enabled = World.Graphics ~= "Low"
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		local now = workspace:GetServerTimeNow()
		local t = os.clock()
		local camPos = Workspace.CurrentCamera.CFrame.Position
		updateConveyor(now, t, camPos)
		updateCreatures(now, t, camPos)
		updateCosmetics(dt, t)
		if t - lastSlow > 0.1 then
			lastSlow = t
			updateMutations(t, camPos)
			updatePlots(t)
		end
	end)

	State.On("Rebirths", updateGate)
	task.spawn(function()
		while true do
			updateGate()
			task.wait(2)
		end
	end)
end

return World
