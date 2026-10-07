--[[
	MapBuilder
	Generates the entire map from MapConfig at server start, so the place file
	needs no hand-built geometry. Returns references other services use.

	Interactables: parts tagged "Interactable" with attributes
		Interact = "Window" | "LockBase" | "ClaimBase"
		Window / Tab = which UI to open, Label = prompt text,
		PlotIndex = owning plot (base terminals), OwnerOnly = true/false
	The client builds the ProximityPrompts for these (see InteractionController).
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapConfig = require(Shared.Config.MapConfig)
local CosmeticConfig = require(Shared.Config.CosmeticConfig)
local ContentConfig = require(Shared.Config.ContentConfig)
local UpgradeConfig = require(Shared.Config.UpgradeConfig)

local MapBuilder = {}

local FONT_TITLE = Enum.Font.FredokaOne
local FONT_BODY = Enum.Font.GothamBold

---------------------------------------------------------------- primitives
type PartProps = {
	Name: string?,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3?,
	Material: Enum.Material?,
	Shape: Enum.PartType?,
	Transparency: number?,
	CanCollide: boolean?,
	Parent: Instance?,
	Reflectance: number?,
	CastShadow: boolean?,
}

local function part(props: PartProps): Part
	local p = Instance.new("Part")
	p.Name = props.Name or "Part"
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		p.Shape = props.Shape
	end
	p.Size = props.Size
	p.CFrame = props.CFrame
	p.Color = props.Color or Color3.fromRGB(200, 200, 200)
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Transparency = props.Transparency or 0
	p.Reflectance = props.Reflectance or 0
	p.CanCollide = if props.CanCollide == nil then true else props.CanCollide
	p.CastShadow = if props.CastShadow == nil then true else props.CastShadow
	p.Parent = props.Parent
	return p
end

-- Upright cylinder (Roblox cylinders run along X, so rotate onto Y).
local function cylinder(name: string, height: number, diameter: number, position: Vector3, color: Color3, material: Enum.Material?, parent: Instance?): Part
	return part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material,
		Parent = parent,
	})
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(radius, 0)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Parent = parent
end

local function textLabel(parent: Instance, props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = props.Font or FONT_TITLE
	label.TextColor3 = props.Color or Color3.new(1, 1, 1)
	label.Text = props.Text or ""
	label.Size = props.Size or UDim2.fromScale(1, 1)
	label.Position = props.Position or UDim2.new()
	label.Name = props.Name or "Label"
	if props.Stroke ~= false then
		stroke(label, props.StrokeColor or Color3.fromRGB(20, 20, 40), props.StrokeThickness or 2)
	end
	label.Parent = parent
	return label
end

-- A sign with a SurfaceGui on its front face (-Z). Returns part + gui frame.
local function sign(name: string, size: Vector3, cf: CFrame, color: Color3, parent: Instance, text: string?, textColor: Color3?): (Part, Frame)
	local board = part({ Name = name, Size = size, CFrame = cf, Color = Color3.fromRGB(30, 32, 52), Parent = parent })
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Gui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = board
	local frame = Instance.new("Frame")
	frame.Name = "Frame"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(28, 30, 54)
	frame.Parent = gui
	corner(frame, 0.08)
	stroke(frame, color, 6)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 190, 220))
	gradient.Rotation = 90
	gradient.Parent = frame
	if text then
		textLabel(frame, {
			Text = text,
			Color = textColor or color,
			Size = UDim2.fromScale(0.92, 0.8),
			Position = UDim2.fromScale(0.04, 0.1),
		})
	end
	return board, frame
end

local function tagInteractable(p: BasePart, attributes: { [string]: any })
	for k, v in attributes do
		p:SetAttribute(k, v)
	end
	CollectionService:AddTag(p, "Interactable")
end

local function floatingIcon(parent: BasePart, icon: string, label: string, color: Color3, offsetY: number)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Icon"
	billboard.Size = UDim2.fromScale(7, 4)
	billboard.StudsOffset = Vector3.new(0, offsetY, 0)
	billboard.MaxDistance = 140
	billboard.LightInfluence = 0
	billboard.AlwaysOnTop = false
	billboard.Parent = parent
	textLabel(billboard, { Text = icon, Size = UDim2.fromScale(1, 0.6), Stroke = false, Font = Enum.Font.GothamBold })
	textLabel(billboard, { Text = label, Size = UDim2.fromScale(1, 0.4), Position = UDim2.fromScale(0, 0.6), Color = color, StrokeThickness = 3 })
end

---------------------------------------------------------------- props
local function tree(position: Vector3, parent: Instance, scale: number?)
	local s = scale or 1
	cylinder("Trunk", 8 * s, 1.6 * s, position + Vector3.new(0, 4 * s, 0), Color3.fromRGB(120, 85, 60), Enum.Material.Wood, parent)
	local leaves = Color3.fromHSV(0.28 + math.random() * 0.08, 0.55, 0.75)
	for i = 0, 2 do
		part({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (7 - i * 1.6) * s,
			CFrame = CFrame.new(position + Vector3.new(0, (8 + i * 2.6) * s, 0)),
			Color = leaves,
			Material = Enum.Material.Grass,
			Parent = parent,
		})
	end
end

local function lamp(position: Vector3, parent: Instance, color: Color3?)
	cylinder("Pole", 10, 0.5, position + Vector3.new(0, 5, 0), Color3.fromRGB(60, 60, 80), Enum.Material.Metal, parent)
	local bulb = part({
		Name = "Bulb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.6,
		CFrame = CFrame.new(position + Vector3.new(0, 10.6, 0)),
		Color = color or Color3.fromRGB(255, 240, 200),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = parent,
	})
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 1.2
	light.Color = color or Color3.fromRGB(255, 230, 190)
	light.Parent = bulb
end

local function floatingCard(cf: CFrame, color: Color3, parent: Instance, text: string)
	local card = part({ Name = "FloatingCard", Size = Vector3.new(6, 8.4, 0.3), CFrame = cf, Color = Color3.new(1, 1, 1), CanCollide = false, Parent = parent })
	CollectionService:AddTag(card, "FloatingCard")
	card:SetAttribute("BaseCFrame", cf)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.LightInfluence = 0
		gui.Parent = card
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = color
		frame.Parent = gui
		corner(frame, 0.06)
		stroke(frame, Color3.new(1, 1, 1), 6)
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 190))
		gradient.Rotation = 45
		gradient.Parent = frame
		textLabel(frame, { Text = text, Size = UDim2.fromScale(0.9, 0.5), Position = UDim2.fromScale(0.05, 0.25), Font = Enum.Font.GothamBold })
	end
end

---------------------------------------------------------------- environment
local function buildLighting()
	local function ensure(className: string, name: string): Instance
		local existing = Lighting:FindFirstChild(name)
		if existing then
			return existing
		end
		local inst = Instance.new(className)
		inst.Name = name
		inst.Parent = Lighting
		return inst
	end
	local atmosphere = ensure("Atmosphere", "Atmosphere") :: Atmosphere
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(200, 215, 255)
	atmosphere.Decay = Color3.fromRGB(120, 130, 190)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.2
	local bloom = ensure("BloomEffect", "Bloom") :: BloomEffect
	bloom.Intensity = 0.45
	bloom.Size = 24
	bloom.Threshold = 1.4
	local cc = ensure("ColorCorrectionEffect", "Grade") :: ColorCorrectionEffect
	cc.Saturation = 0.15
	cc.Contrast = 0.06
	cc.Brightness = 0.02
	local rays = ensure("SunRaysEffect", "SunRays") :: SunRaysEffect
	rays.Intensity = 0.04
	rays.Spread = 0.6
end

local function buildGround(world: Folder)
	part({
		Name = "Ground",
		Size = MapConfig.GroundSize,
		CFrame = CFrame.new(MapConfig.GroundCenter),
		Color = Color3.fromRGB(126, 204, 112),
		Material = Enum.Material.Grass,
		Parent = world,
	})
	local pathColor = Color3.fromRGB(236, 230, 214)
	-- Walkways along both sides of the main conveyor.
	for _, z in { 15.5, -15.5 } do
		part({ Name = "Walkway", Size = Vector3.new(350, 0.2, 19), CFrame = CFrame.new(0, 0.1, z), Color = pathColor, Parent = world })
	end
	part({ Name = "ConveyorApron", Size = Vector3.new(370, 0.2, 12), CFrame = CFrame.new(0, 0.1, 0), Color = Color3.fromRGB(210, 205, 195), Parent = world })
	part({ Name = "HubPath", Size = Vector3.new(80, 0.2, 30), CFrame = CFrame.new(-215, 0.1, 0), Color = pathColor, Parent = world })
	part({ Name = "ElitePath", Size = Vector3.new(60, 0.2, 24), CFrame = CFrame.new(190, 0.1, 0), Color = pathColor, Parent = world })

	-- Invisible boundary
	local size = MapConfig.GroundSize
	local c = MapConfig.GroundCenter
	local h = 80
	for _, spec in {
		{ Vector3.new(size.X, h, 2), Vector3.new(c.X, h / 2, size.Z / 2) },
		{ Vector3.new(size.X, h, 2), Vector3.new(c.X, h / 2, -size.Z / 2) },
		{ Vector3.new(2, h, size.Z), Vector3.new(c.X + size.X / 2, h / 2, 0) },
		{ Vector3.new(2, h, size.Z), Vector3.new(c.X - size.X / 2, h / 2, 0) },
	} do
		part({ Name = "Boundary", Size = spec[1], CFrame = CFrame.new(spec[2]), Transparency = 1, Parent = world, CastShadow = false })
	end

	-- Scenery
	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery"
	scenery.Parent = world
	local rng = Random.new(2024)
	for x = -400, 360, 38 do
		for _, z in { -165, 165 } do
			tree(Vector3.new(x + rng:NextNumber(-8, 8), 0, z + rng:NextNumber(-6, 6)), scenery, rng:NextNumber(0.9, 1.3))
		end
	end
	for x = -150, 150, 50 do
		for _, z in { 24, -24 } do
			lamp(Vector3.new(x, 0, z), scenery)
		end
	end
	local cardColors = { Color3.fromRGB(255, 120, 120), Color3.fromRGB(120, 200, 255), Color3.fromRGB(255, 220, 90), Color3.fromRGB(190, 130, 255) }
	local cardTexts = { "★", "?", "✦", "♛" }
	for i, pos in { Vector3.new(-200, 22, 40), Vector3.new(-200, 26, -40), Vector3.new(200, 24, 120), Vector3.new(200, 22, -120) } do
		floatingCard(CFrame.new(pos) * CFrame.Angles(0, math.rad(i * 40), math.rad(8)), cardColors[i], scenery, cardTexts[i])
	end
end

---------------------------------------------------------------- conveyors
local function buildConveyor(name: string, world: Folder)
	local geo = MapConfig.Conveyors[name]
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = world

	local startPos = geo.Start
	local endPos = geo.End
	local length = (endPos - startPos).Magnitude
	local mid = (startPos + endPos) / 2
	local look = CFrame.lookAt(Vector3.new(mid.X, 0, mid.Z), Vector3.new(endPos.X, 0, endPos.Z))

	part({ Name = "Base", Size = Vector3.new(geo.Width + 4, geo.Height - 0.8, length), CFrame = look * CFrame.new(0, (geo.Height - 0.8) / 2, 0), Color = Color3.fromRGB(40, 42, 60), Parent = folder })
	local belt = part({ Name = "Belt", Size = Vector3.new(geo.Width, 0.8, length), CFrame = look * CFrame.new(0, geo.Height - 0.4, 0), Color = geo.Color, Material = Enum.Material.SmoothPlastic, Parent = folder })
	belt:SetAttribute("Conveyor", name)
	for _, side in { -1, 1 } do
		part({ Name = "Rail", Size = Vector3.new(1, 1.4, length), CFrame = look * CFrame.new(side * (geo.Width / 2 + 0.5), geo.Height + 0.2, 0), Color = geo.Accent, Material = Enum.Material.Neon, Parent = folder })
	end
	-- Chevrons (animated by the client along the belt direction)
	local chevrons = Instance.new("Folder")
	chevrons.Name = "Chevrons"
	chevrons.Parent = folder
	local spacing = 12
	for d = spacing / 2, length - spacing / 2, spacing do
		local cf = look * CFrame.new(0, geo.Height + 0.05, length / 2 - d)
		for _, side in { -1, 1 } do
			local chevron = part({
				Name = "Chevron",
				Size = Vector3.new(0.6, 0.1, 4),
				CFrame = cf * CFrame.new(side * 1.3, 0, 0) * CFrame.Angles(0, side * math.rad(40), 0),
				Color = geo.Accent,
				Material = Enum.Material.Neon,
				CanCollide = false,
				Transparency = 0.35,
				Parent = chevrons,
				CastShadow = false,
			})
			chevron:SetAttribute("BaseCFrame", chevron.CFrame)
			CollectionService:AddTag(chevron, "ConveyorChevron")
		end
	end
	chevrons:SetAttribute("Direction", (endPos - startPos).Unit)
	chevrons:SetAttribute("Spacing", spacing)

	-- Card portal (spawn) and recycler (end)
	local portalCF = CFrame.lookAt(startPos, endPos) * CFrame.new(0, 0, 4)
	for _, side in { -1, 1 } do
		part({ Name = "PortalPillar", Size = Vector3.new(2, 16, 2), CFrame = portalCF * CFrame.new(side * (geo.Width / 2 + 2), 8 - geo.Height, 0), Color = geo.Accent, Material = Enum.Material.Neon, Parent = folder })
	end
	part({ Name = "PortalTop", Size = Vector3.new(geo.Width + 6, 2, 2), CFrame = portalCF * CFrame.new(0, 16 - geo.Height, 0), Color = Color3.fromRGB(40, 42, 60), Parent = folder })
	local veil = part({ Name = "PortalVeil", Size = Vector3.new(geo.Width + 2, 12, 0.3), CFrame = portalCF * CFrame.new(0, 6, 1.2), Color = geo.Accent, Material = Enum.Material.ForceField, CanCollide = false, Parent = folder, CastShadow = false })
	veil.Transparency = 0.2
	local portalSign = sign("PortalSign", Vector3.new(geo.Width + 8, 4, 0.6), portalCF * CFrame.new(0, 19.5 - geo.Height, 0) * CFrame.Angles(0, math.pi, 0), geo.Accent, folder,
		if name == "Main" then "✨ CRITTER PORTAL ✨" else "👑 ELITE PORTAL 👑")
	portalSign.CanCollide = false

	local endCF = CFrame.lookAt(endPos, startPos) * CFrame.new(0, 0, 3)
	part({ Name = "Recycler", Size = Vector3.new(geo.Width + 4, 8, 4), CFrame = endCF * CFrame.new(0, 4 - geo.Height, 0), Color = Color3.fromRGB(50, 50, 70), Parent = folder })

	local items = Instance.new("Folder")
	items.Name = "Items"
	items.Parent = folder
	return { Folder = folder, Items = items, Belt = belt }
end

---------------------------------------------------------------- plots
export type SlotRefs = { Pedestal: Part, Rim: Part, CFrame: CFrame }
export type PlotRefs = {
	Index: number,
	Origin: CFrame,
	Model: Model,
	Floor: Part,
	Walls: { Part },
	Glass: { Part },
	Trims: { Part },
	Door: Part,
	Lights: { Part },
	Sign: Part,
	SignTitle: TextLabel,
	SignIncome: TextLabel,
	SignStatus: TextLabel,
	CollectPad: Part,
	LockButton: Part,
	Slots: { SlotRefs },
	Traps: { Part },
	Spawn: SpawnLocation,
	Creatures: Folder,
	EffectPart: Part,
}

local function buildPlot(index: number, origin: CFrame, plotsFolder: Folder): PlotRefs
	local cfg = MapConfig.Plot
	local theme = CosmeticConfig.Items.Theme_Default
	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("OwnerUserId", 0)
	model:SetAttribute("OwnerName", "")
	model.Parent = plotsFolder

	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end

	local floor = part({ Name = "Floor", Size = Vector3.new(cfg.Size.X, 1, cfg.Size.Z), CFrame = at(0, 0.5, 0), Color = theme.Floor, Parent = model })

	local walls, glass, trims = {}, {}, {}
	local halfX, halfZ = cfg.Size.X / 2, cfg.Size.Z / 2
	local t = cfg.WallThickness
	local solidH, glassH = 4, cfg.WallHeight - 4
	local function wall(size: Vector3, x: number, z: number)
		table.insert(walls, part({ Name = "Wall", Size = Vector3.new(size.X, solidH, size.Z), CFrame = at(x, 1 + solidH / 2, z), Color = theme.Wall, Parent = model }))
		local g = part({ Name = "Glass", Size = Vector3.new(size.X, glassH, size.Z), CFrame = at(x, 1 + solidH + glassH / 2, z), Color = Color3.fromRGB(200, 230, 255), Material = Enum.Material.Glass, Transparency = 0.65, Parent = model, CastShadow = false })
		table.insert(glass, g)
		table.insert(trims, part({ Name = "Trim", Size = Vector3.new(size.X + 0.2, 0.5, size.Z + 0.2), CFrame = at(x, 1 + cfg.WallHeight + 0.25, z), Color = theme.Trim, Material = Enum.Material.Neon, Parent = model }))
	end
	wall(Vector3.new(cfg.Size.X, 0, t), 0, halfZ - t / 2)
	wall(Vector3.new(t, 0, cfg.Size.Z), -halfX + t / 2, 0)
	wall(Vector3.new(t, 0, cfg.Size.Z), halfX - t / 2, 0)
	local gap = cfg.EntranceWidth / 2
	local segment = halfX - gap
	wall(Vector3.new(segment, 0, t), -(gap + segment / 2), -halfZ + t / 2)
	wall(Vector3.new(segment, 0, t), gap + segment / 2, -halfZ + t / 2)

	-- Entrance arch
	local pillarX = gap + 0.75
	for _, side in { -1, 1 } do
		table.insert(walls, part({ Name = "Pillar", Size = Vector3.new(2, 16, 2.5), CFrame = at(side * pillarX, 9, -halfZ + t / 2), Color = theme.Wall, Parent = model }))
	end
	part({ Name = "Beam", Size = Vector3.new(cfg.EntranceWidth + 3.5, 2, 2.5), CFrame = at(0, 16, -halfZ + t / 2), Color = Color3.fromRGB(40, 42, 64), Parent = model })
	local lights = {}
	for _, side in { -1, 1 } do
		table.insert(lights, part({ Name = "SecurityLight", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.8, CFrame = at(side * pillarX, 17.9, -halfZ + t / 2), Color = Color3.fromRGB(120, 255, 140), Material = Enum.Material.Neon, CanCollide = false, Parent = model }))
	end

	-- Owner sign
	local signPart, signFrame = sign("Sign", Vector3.new(24, 5, 0.6), at(0, 19.6, -halfZ + t / 2 - 0.6), Color3.fromRGB(255, 220, 90), model)
	signPart.CanCollide = false
	local signTitle = textLabel(signFrame, { Name = "Title", Text = "OPEN PLOT", Size = UDim2.fromScale(0.94, 0.48), Position = UDim2.fromScale(0.03, 0.04), Color = Color3.fromRGB(255, 230, 120) })
	local signIncome = textLabel(signFrame, { Name = "Income", Text = "", Size = UDim2.fromScale(0.5, 0.36), Position = UDim2.fromScale(0.03, 0.58), Color = Color3.fromRGB(140, 255, 160), Font = FONT_BODY })
	local signStatus = textLabel(signFrame, { Name = "Status", Text = "", Size = UDim2.fromScale(0.44, 0.36), Position = UDim2.fromScale(0.53, 0.58), Color = Color3.fromRGB(255, 255, 255), Font = FONT_BODY })

	-- Laser door (enabled while locked)
	local door = part({ Name = "LaserDoor", Size = Vector3.new(cfg.EntranceWidth, 14, 0.5), CFrame = at(0, 8, -halfZ + t / 2), Color = Color3.fromRGB(255, 60, 90), Material = Enum.Material.ForceField, Transparency = 1, CanCollide = false, Parent = model, CastShadow = false })

	-- Collector pad
	local padPos = cfg.CollectPad
	local collectPad = part({
		Name = "CollectPad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, 8, 8),
		CFrame = at(padPos.X, padPos.Y + 0.25, padPos.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 200, 60),
		Material = Enum.Material.Neon,
		Parent = model,
	})
	collectPad:SetAttribute("PlotIndex", index)
	CollectionService:AddTag(collectPad, "CollectPad")
	local padGui = Instance.new("BillboardGui")
	padGui.Name = "CashDisplay"
	padGui.Size = UDim2.fromScale(9, 3)
	padGui.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
	padGui.MaxDistance = 90
	padGui.LightInfluence = 0
	padGui.Parent = collectPad
	textLabel(padGui, { Name = "Title", Text = "💰 COLLECT", Size = UDim2.fromScale(1, 0.45), Color = Color3.fromRGB(255, 230, 120) })
	textLabel(padGui, { Name = "Amount", Text = "$0", Size = UDim2.fromScale(1, 0.55), Position = UDim2.fromScale(0, 0.45), Color = Color3.fromRGB(140, 255, 160) })

	-- Lock terminal
	local lockPos = cfg.LockTerminal
	part({ Name = "LockPedestal", Size = Vector3.new(3, 3.5, 2.4), CFrame = at(lockPos.X, 1 + 1.75, lockPos.Z), Color = Color3.fromRGB(40, 42, 64), Parent = model })
	local lockButton = part({
		Name = "LockButton",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 2.2, 2.2),
		CFrame = at(lockPos.X, 1 + 3.8, lockPos.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 80, 80),
		Material = Enum.Material.Neon,
		Parent = model,
	})
	tagInteractable(lockButton, { Interact = "LockBase", Label = "Lock Base", PlotIndex = index, OwnerOnly = true })
	floatingIcon(lockButton, "🔒", "LOCK", Color3.fromRGB(255, 120, 120), 3)

	-- Slots
	local slots: { SlotRefs } = {}
	for r, z in cfg.SlotRows do
		for c, x in cfg.SlotColumns do
			local slotIndex = (r - 1) * #cfg.SlotColumns + c
			local pedestal = cylinder("Pedestal" .. slotIndex, 0.8, cfg.PedestalRadius * 2, (at(x, 1.4, z)).Position, Color3.fromRGB(235, 238, 248), Enum.Material.SmoothPlastic, model)
			local rim = cylinder("Rim" .. slotIndex, 0.3, cfg.PedestalRadius * 2 + 0.6, (at(x, 1.15, z)).Position, Color3.fromRGB(120, 125, 150), Enum.Material.Neon, model)
			pedestal:SetAttribute("Slot", slotIndex)
			table.insert(slots, { Pedestal = pedestal, Rim = rim, CFrame = at(x, 1.8, z) })
		end
	end
	assert(#slots == UpgradeConfig.PhysicalSlots, "MapConfig slot grid must match UpgradeConfig.PhysicalSlots")

	-- Trap pads (hidden until purchased)
	local traps = {}
	for i, pos in cfg.Traps do
		local trap = part({
			Name = "Trap" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, 5, 5),
			CFrame = at(pos.X, 1.1, pos.Z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(80, 200, 255),
			Material = Enum.Material.Neon,
			Transparency = 1,
			CanCollide = false,
			Parent = model,
			CastShadow = false,
		})
		table.insert(traps, trap)
	end

	-- Spawn (also the "Claim Base" interaction point)
	local spawnPos = cfg.Spawn
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 0.4, 8)
	spawn.CFrame = at(spawnPos.X, spawnPos.Y + 0.2, spawnPos.Z)
	spawn.Color = Color3.fromRGB(120, 200, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.4
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Enabled = true
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = model
	for _, d in spawn:GetChildren() do
		if d:IsA("Decal") then
			d:Destroy()
		end
	end
	tagInteractable(spawn, { Interact = "ClaimBase", Label = "Claim Base", PlotIndex = index, OwnerOnly = true })

	-- Base terminals
	for _, terminal in cfg.Terminals do
		local p = terminal.Position
		part({ Name = terminal.Id .. "Stand", Size = Vector3.new(4, 4.2, 2.4), CFrame = at(p.X, 1 + 2.1, p.Z), Color = Color3.fromRGB(40, 42, 64), Parent = model })
		local screen, screenFrame = sign(terminal.Id .. "Screen", Vector3.new(3.8, 2.6, 0.3), at(p.X, 1 + 4.2 + 1.3, p.Z - 0.6), terminal.Color, model)
		textLabel(screenFrame, { Text = terminal.Icon .. "\n" .. terminal.Label, Size = UDim2.fromScale(0.9, 0.85), Position = UDim2.fromScale(0.05, 0.075), Color = terminal.Color })
		tagInteractable(screen, { Interact = "Window", Window = terminal.Window, Tab = terminal.Tab or "", Label = terminal.Label, PlotIndex = index, OwnerOnly = true })
	end

	local creatures = Instance.new("Folder")
	creatures.Name = "Creatures"
	creatures.Parent = model

	local effectPart = part({ Name = "EffectVolume", Size = Vector3.new(cfg.Size.X - 6, 1, cfg.Size.Z - 6), CFrame = at(0, 16, 0), Transparency = 1, CanCollide = false, Parent = model, CastShadow = false })
	effectPart.CanQuery = false
	effectPart.CanTouch = false

	model.PrimaryPart = floor
	return {
		Index = index,
		Origin = origin,
		Model = model,
		Floor = floor,
		Walls = walls,
		Glass = glass,
		Trims = trims,
		Door = door,
		Lights = lights,
		Sign = signPart,
		SignTitle = signTitle,
		SignIncome = signIncome,
		SignStatus = signStatus,
		CollectPad = collectPad,
		LockButton = lockButton,
		Slots = slots,
		Traps = traps,
		Spawn = spawn,
		Creatures = creatures,
		EffectPart = effectPart,
	}
end

---------------------------------------------------------------- hub
local function kiosk(def, parent: Instance)
	local base = def.Position
	local folder = Instance.new("Model")
	folder.Name = def.Id
	folder.Parent = parent
	cylinder("Platform", 0.6, 14, base + Vector3.new(0, 0.3, 0), Color3.fromRGB(240, 240, 250), Enum.Material.SmoothPlastic, folder)
	part({ Name = "Counter", Size = Vector3.new(8, 3.4, 3), CFrame = CFrame.new(base + Vector3.new(0, 2.3, 0)), Color = def.Color, Parent = folder })
	part({ Name = "CounterTop", Size = Vector3.new(8.6, 0.4, 3.6), CFrame = CFrame.new(base + Vector3.new(0, 4.2, 0)), Color = Color3.fromRGB(250, 250, 255), Parent = folder })
	for _, side in { -1, 1 } do
		part({ Name = "Post", Size = Vector3.new(0.6, 9, 0.6), CFrame = CFrame.new(base + Vector3.new(side * 3.8, 4.5, 1.2)), Color = Color3.fromRGB(250, 250, 255), Parent = folder })
	end
	local canopy = part({ Name = "Canopy", Size = Vector3.new(10, 0.8, 5), CFrame = CFrame.new(base + Vector3.new(0, 9.2, 0.4)), Color = def.Color, Material = Enum.Material.SmoothPlastic, Parent = folder })
	floatingIcon(canopy, def.Icon, def.Label, def.Color, 4.5)
	local counter = folder:FindFirstChild("Counter") :: BasePart
	tagInteractable(counter, { Interact = "Window", Window = def.Window, Tab = def.Tab or "", Label = def.Label, OwnerOnly = false })
end

local function buildHub(world: Folder)
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = world
	local center = MapConfig.Hub.Center

	cylinder("Plaza", 0.2, MapConfig.Hub.Radius * 2, center + Vector3.new(0, 0.1, 0), Color3.fromRGB(245, 240, 228), Enum.Material.SmoothPlastic, hub)
	cylinder("PlazaRing", 0.25, MapConfig.Hub.Radius * 2 - 6, center + Vector3.new(0, 0.12, 0), Color3.fromRGB(255, 214, 120), Enum.Material.SmoothPlastic, hub)
	cylinder("PlazaInner", 0.3, MapConfig.Hub.Radius * 2 - 10, center + Vector3.new(0, 0.14, 0), Color3.fromRGB(245, 240, 228), Enum.Material.SmoothPlastic, hub)

	-- Fountain with a giant floating title card
	cylinder("FountainRim", 1.6, 16, center + Vector3.new(0, 0.8, 0), Color3.fromRGB(220, 225, 240), Enum.Material.Marble, hub)
	local water = cylinder("FountainWater", 1.7, 14, center + Vector3.new(0, 0.85, 0), Color3.fromRGB(90, 190, 255), Enum.Material.Glass, hub)
	water.Transparency = 0.3
	floatingCard(CFrame.new(center + Vector3.new(0, 11, 0)), Color3.fromRGB(255, 196, 70), hub, ContentConfig.Title())

	-- Welcome arch facing the bases (east)
	local archX = -228
	for _, z in { -15, 15 } do
		part({ Name = "ArchPillar", Size = Vector3.new(2.5, 20, 2.5), CFrame = CFrame.new(archX, 10, z), Color = Color3.fromRGB(120, 140, 255), Parent = hub })
	end
	local archSign = sign("WelcomeSign", Vector3.new(34, 7, 1), CFrame.new(archX, 22, 0) * CFrame.Angles(0, -math.pi / 2, 0), Color3.fromRGB(255, 214, 90), hub,
		"🏙️ " .. ContentConfig.Title() .. " — HUB")
	archSign.CanCollide = true
	local backSign = sign("ArchBack", Vector3.new(34, 7, 1), CFrame.new(archX - 1.2, 22, 0) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(120, 220, 255), hub,
		"🏠 BASES & CONVEYOR →")
	backSign.CanCollide = true

	for _, def in MapConfig.Kiosks do
		kiosk(def, hub)
	end

	-- Shop hall roof
	local hall = MapConfig.ShopHall
	part({ Name = "ShopHallFloor", Size = Vector3.new(64, 0.4, 30), CFrame = CFrame.new(hall + Vector3.new(0, 0.2, 6)), Color = Color3.fromRGB(255, 236, 200), Parent = hub })
	sign("ShopHallSign", Vector3.new(30, 6, 1), CFrame.new(hall + Vector3.new(0, 16, -6)) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(255, 200, 70), hub, "🛒 SHOPPING HALL")

	-- Rebirth shrine
	local shrine = MapConfig.RebirthShrine
	cylinder("ShrineBase", 0.8, 30, shrine + Vector3.new(0, 0.4, 0), Color3.fromRGB(220, 255, 235), Enum.Material.Marble, hub)
	for i = 1, 6 do
		local angle = (i / 6) * math.pi * 2
		part({ Name = "ShrinePillar", Size = Vector3.new(1.6, 12, 1.6), CFrame = CFrame.new(shrine + Vector3.new(math.cos(angle) * 12, 6.8, math.sin(angle) * 12)), Color = Color3.fromRGB(120, 255, 170), Material = Enum.Material.Neon, Parent = hub })
	end
	sign("ShrineSign", Vector3.new(26, 5, 1), CFrame.new(shrine + Vector3.new(0, 16, 6)), Color3.fromRGB(120, 255, 170), hub, "♻️ REBIRTH SHRINE")

	-- Collection hall + showcase pedestals
	local show = MapConfig.Showcase
	part({ Name = "HallFloor", Size = Vector3.new(44, 0.5, 34), CFrame = CFrame.new(show.Center + Vector3.new(0, 0.25, -4)), Color = Color3.fromRGB(235, 225, 255), Parent = hub })
	sign("HallSign", Vector3.new(30, 5, 1), CFrame.new(show.Center + Vector3.new(0, 15, 10)), Color3.fromRGB(190, 150, 255), hub, "📖 COLLECTION HALL — SERVER SHOWCASE")

	-- Event stage
	local stage = MapConfig.EventStage
	part({ Name = "Stage", Size = Vector3.new(40, 2, 22), CFrame = CFrame.new(stage + Vector3.new(0, 1, -2)), Color = Color3.fromRGB(60, 40, 80), Parent = hub })
	local _, eventFrame = sign("EventBoard", Vector3.new(30, 9, 1), CFrame.new(stage + Vector3.new(0, 11, -10)) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(255, 140, 40), hub)
	textLabel(eventFrame, { Name = "EventTitle", Text = "🎪 EVENTS", Size = UDim2.fromScale(0.9, 0.45), Position = UDim2.fromScale(0.05, 0.05), Color = Color3.fromRGB(255, 200, 90) })
	textLabel(eventFrame, { Name = "EventText", Text = "No event right now", Size = UDim2.fromScale(0.9, 0.4), Position = UDim2.fromScale(0.05, 0.55), Color = Color3.new(1, 1, 1), Font = FONT_BODY })

	-- Leaderboard boards
	local boards = {}
	for _, def in MapConfig.Leaderboards do
		local boardCF = CFrame.lookAt(def.Position + Vector3.new(0, 10, 0), def.Position + Vector3.new(10, 10, 0))
		local board, frame = sign("Leaderboard_" .. def.Stat, Vector3.new(28, 18, 1), boardCF, Color3.fromRGB(255, 214, 90), hub)
		part({ Name = "BoardStand", Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(def.Position + Vector3.new(0, 1, 0)), Color = Color3.fromRGB(40, 42, 64), Parent = hub })
		board:SetAttribute("Stat", def.Stat)
		boards[def.Stat] = frame
	end

	-- Hub scenery
	for i = 0, 7 do
		local angle = (i / 8) * math.pi * 2
		lamp(center + Vector3.new(math.cos(angle) * 50, 0, math.sin(angle) * 50), hub, Color3.fromRGB(255, 220, 160))
	end
	return boards, eventFrame
end

---------------------------------------------------------------- elite area
local function buildElite(world: Folder)
	local area = Instance.new("Folder")
	area.Name = "EliteArea"
	area.Parent = world
	local minP, maxP = MapConfig.EliteArea.Min, MapConfig.EliteArea.Max
	local width = maxP.X - minP.X
	local depth = maxP.Z - minP.Z
	local center = (minP + maxP) / 2
	part({ Name = "EliteFloor", Size = Vector3.new(width, 0.4, depth), CFrame = CFrame.new(center.X, 0.2, center.Z), Color = Color3.fromRGB(60, 40, 90), Material = Enum.Material.SmoothPlastic, Parent = area })
	local wallColor = Color3.fromRGB(90, 60, 140)
	local h = 10
	part({ Name = "EliteWall", Size = Vector3.new(width, h, 2), CFrame = CFrame.new(center.X, h / 2, maxP.Z), Color = wallColor, Parent = area })
	part({ Name = "EliteWall", Size = Vector3.new(width, h, 2), CFrame = CFrame.new(center.X, h / 2, minP.Z), Color = wallColor, Parent = area })
	part({ Name = "EliteWall", Size = Vector3.new(2, h, depth), CFrame = CFrame.new(maxP.X, h / 2, center.Z), Color = wallColor, Parent = area })
	local gateHalf = MapConfig.EliteArea.GateWidth / 2
	local sideLen = depth / 2 - gateHalf
	for _, sideSign in { -1, 1 } do
		part({ Name = "EliteWall", Size = Vector3.new(2, h, sideLen), CFrame = CFrame.new(minP.X, h / 2, sideSign * (gateHalf + sideLen / 2)), Color = wallColor, Parent = area })
		part({ Name = "GatePillar", Size = Vector3.new(3, 18, 3), CFrame = CFrame.new(minP.X, 9, sideSign * (gateHalf + 1.5)), Color = Color3.fromRGB(255, 200, 70), Material = Enum.Material.Neon, Parent = area })
	end
	local gate = part({ Name = "EliteGate", Size = Vector3.new(1, 16, MapConfig.EliteArea.GateWidth), CFrame = CFrame.new(minP.X, 8, 0), Color = Color3.fromRGB(255, 200, 70), Material = Enum.Material.ForceField, Transparency = 0.3, Parent = area, CastShadow = false })
	gate:SetAttribute("RequiredRebirths", 1)
	CollectionService:AddTag(gate, "EliteGate")
	local gateSign = sign("GateSign", Vector3.new(26, 5, 1), CFrame.new(minP.X - 1, 20, 0) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(255, 200, 70), area, "👑 ELITE MARKET — REBIRTH 1+")
	gateSign.CanCollide = true
	for z = -80, 80, 40 do
		lamp(Vector3.new(minP.X + 20, 0, z), area, Color3.fromRGB(255, 200, 120))
		lamp(Vector3.new(maxP.X - 20, 0, z), area, Color3.fromRGB(255, 200, 120))
	end
	return gate
end

---------------------------------------------------------------- public
export type MapRefs = {
	World: Folder,
	Plots: { PlotRefs },
	Conveyors: { [string]: { Folder: Folder, Items: Folder, Belt: Part } },
	Boards: { [string]: Frame },
	EventBoard: Frame,
	EliteGate: Part,
	ShowcaseFolder: Folder,
}

function MapBuilder.Build(): MapRefs
	local existing = workspace:FindFirstChild("World")
	if existing then
		existing:Destroy()
	end
	local world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = workspace

	buildLighting()
	buildGround(world)

	local conveyorsFolder = Instance.new("Folder")
	conveyorsFolder.Name = "Conveyors"
	conveyorsFolder.Parent = world
	local conveyors = {}
	for name in MapConfig.Conveyors do
		conveyors[name] = buildConveyor(name, conveyorsFolder)
	end

	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = world
	local plots = {}
	for i, origin in MapConfig.PlotOrigins do
		plots[i] = buildPlot(i, origin, plotsFolder)
	end

	local boards, eventBoard = buildHub(world)
	local gate = buildElite(world)

	local showcase = Instance.new("Folder")
	showcase.Name = "Showcase"
	showcase.Parent = world

	return {
		World = world,
		Plots = plots,
		Conveyors = conveyors,
		Boards = boards,
		EventBoard = eventBoard,
		EliteGate = gate,
		ShowcaseFolder = showcase,
	}
end

-- Pedestal positions for the server showcase (top surface CFrames).
function MapBuilder.BuildShowcasePedestals(folder: Folder, count: number): { CFrame }
	local show = MapConfig.Showcase
	local result = {}
	for i = 1, count do
		local angle = math.rad(-150 + (i - 1) * (120 / math.max(1, count - 1)))
		local pos = show.Center + Vector3.new(math.cos(angle) * show.Radius, 0, math.sin(angle) * show.Radius)
		cylinder("ShowcasePedestal", 2, 6, pos + Vector3.new(0, 1, 0), Color3.fromRGB(250, 248, 255), Enum.Material.Marble, folder)
		cylinder("ShowcaseRim", 0.3, 6.6, pos + Vector3.new(0, 2.05, 0), Color3.fromRGB(190, 150, 255), Enum.Material.Neon, folder)
		table.insert(result, CFrame.lookAt(pos + Vector3.new(0, 2.2, 0), MapConfig.Showcase.Center + Vector3.new(0, 2.2, -30)))
	end
	return result
end

---------------------------------------------------------------- event decorations
function MapBuilder.BuildDecorations(kind: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Decor_" .. kind
	local rng = Random.new(#kind * 97)
	local walkSpots = {}
	for x = -160, 160, 32 do
		table.insert(walkSpots, Vector3.new(x + 8, 0, 23))
		table.insert(walkSpots, Vector3.new(x + 8, 0, -23))
	end
	for i = 0, 9 do
		local angle = (i / 10) * math.pi * 2
		table.insert(walkSpots, MapConfig.Hub.Center + Vector3.new(math.cos(angle) * 40, 0, math.sin(angle) * 40))
	end

	if kind == "Halloween" then
		for _, pos in walkSpots do
			local size = rng:NextNumber(2.2, 3.4)
			local pumpkin = part({ Name = "Pumpkin", Shape = Enum.PartType.Ball, Size = Vector3.one * size, CFrame = CFrame.new(pos + Vector3.new(0, size / 2, 0)), Color = Color3.fromRGB(255, 130, 20), Parent = folder })
			part({ Name = "Stem", Size = Vector3.new(0.4, 0.8, 0.4), CFrame = CFrame.new(pos + Vector3.new(0, size + 0.3, 0)), Color = Color3.fromRGB(60, 140, 40), Parent = folder })
			local glow = Instance.new("PointLight")
			glow.Color = Color3.fromRGB(255, 140, 40)
			glow.Range = 10
			glow.Brightness = 1.5
			glow.Parent = pumpkin
		end
		for i = 1, 14 do
			local bat = part({ Name = "Bat", Size = Vector3.new(3, 0.3, 1.2), CFrame = CFrame.new(rng:NextNumber(-300, 250), rng:NextNumber(25, 45), rng:NextNumber(-120, 120)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Color = Color3.fromRGB(20, 15, 30), CanCollide = false, Parent = folder })
			bat:SetAttribute("BaseCFrame", bat.CFrame)
			CollectionService:AddTag(bat, "FloatingCard")
			if i % 3 == 0 then
				bat.Material = Enum.Material.Neon
				bat.Color = Color3.fromRGB(140, 60, 220)
			end
		end
	elseif kind == "Winter" then
		for _, pos in walkSpots do
			part({ Name = "SnowBottom", Shape = Enum.PartType.Ball, Size = Vector3.one * 3.4, CFrame = CFrame.new(pos + Vector3.new(0, 1.7, 0)), Color = Color3.new(1, 1, 1), Parent = folder })
			part({ Name = "SnowTop", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.2, CFrame = CFrame.new(pos + Vector3.new(0, 4.1, 0)), Color = Color3.new(1, 1, 1), Parent = folder })
			part({ Name = "Hat", Size = Vector3.new(1.4, 1.2, 1.4), CFrame = CFrame.new(pos + Vector3.new(0, 5.6, 0)), Color = Color3.fromRGB(200, 30, 40), Parent = folder })
		end
		local snow = part({ Name = "SnowEmitter", Size = Vector3.new(500, 1, 300), CFrame = CFrame.new(-40, 70, 0), Transparency = 1, CanCollide = false, Parent = folder, CastShadow = false })
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Rate = 120
		emitter.Lifetime = NumberRange.new(10, 14)
		emitter.Speed = NumberRange.new(5, 8)
		emitter.EmissionDirection = Enum.NormalId.Bottom
		emitter.Size = NumberSequence.new(0.5)
		emitter.Color = ColorSequence.new(Color3.new(1, 1, 1))
		emitter.LightEmission = 0.5
		emitter:AddTag("CreatureFX")
		emitter.Parent = snow
	elseif kind == "Summer" then
		for i, pos in walkSpots do
			cylinder("UmbrellaPole", 9, 0.4, pos + Vector3.new(0, 4.5, 0), Color3.fromRGB(240, 240, 240), Enum.Material.SmoothPlastic, folder)
			local color = if i % 2 == 0 then Color3.fromRGB(255, 90, 90) else Color3.fromRGB(80, 200, 255)
			cylinder("Umbrella", 0.6, 9, pos + Vector3.new(0, 9, 0), color, Enum.Material.SmoothPlastic, folder)
		end
	elseif kind == "Sparkle" then
		for _, conveyorName in { "Main" } do
			local geo = MapConfig.Conveyors[conveyorName]
			local mid = (geo.Start + geo.End) / 2
			local sparkle = part({ Name = "SparkleVolume", Size = Vector3.new((geo.End - geo.Start).Magnitude, 1, 16), CFrame = CFrame.new(mid + Vector3.new(0, 10, 0)), Transparency = 1, CanCollide = false, Parent = folder, CastShadow = false })
			local emitter = Instance.new("ParticleEmitter")
			emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			emitter.Rate = 40
			emitter.Lifetime = NumberRange.new(2, 3)
			emitter.Speed = NumberRange.new(1, 3)
			emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
			emitter.Color = ColorSequence.new(Color3.fromRGB(255, 240, 150), Color3.fromRGB(150, 220, 255))
			emitter.LightEmission = 1
			emitter:AddTag("CreatureFX")
			emitter.Parent = sparkle
		end
	end
	return folder
end

return MapBuilder
