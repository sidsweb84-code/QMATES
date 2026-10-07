--[[
	CreatureBuilder
	Builds a creature Model procedurally from primitive parts, so the game has
	visuals with zero external assets. Used by the server (world models) and the
	client (ViewportFrame previews on cards).

	REPLACING VISUALS: put a Model named after the collectible Id (or the
	LicensedContent "Model" name) in ReplicatedStorage.Assets.Creatures and it
	is used instead of the procedural body. Its parts are welded to a generated
	Root automatically.

	Model contract (both procedural and custom):
		Model.PrimaryPart = "Root" (anchored, invisible, at the creature's feet)
		every other BasePart is unanchored, massless, non-colliding, welded to Root
		Model attribute "Height" = approximate height in studs
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = script.Parent
local Config = Shared.Config
local RarityConfig = require(Config.RarityConfig)
local Catalog = require(Shared.Catalog)

local CreatureBuilder = {}

local WHITE = Color3.new(1, 1, 1)
local DARK = Color3.fromRGB(25, 25, 35)
local PARTICLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

type Ctx = {
	Model: Model,
	Root: BasePart,
	Scale: number,
	Colors: { Color3 },
	Material: Enum.Material,
	Parts: { BasePart },
}

local function scaledCF(ctx: Ctx, cf: CFrame): CFrame
	return CFrame.new(cf.Position * ctx.Scale) * cf.Rotation
end

local function finishPart(ctx: Ctx, part: BasePart, name: string, color: Color3, paint: string, material: Enum.Material?)
	part.Name = name
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Color = color
	part.Material = material or ctx.Material
	part:SetAttribute("Paint", paint)
	part.Parent = ctx.Model
	table.insert(ctx.Parts, part)
end

local function paintColor(ctx: Ctx, paint: string): Color3
	if paint == "P" then
		return ctx.Colors[1]
	elseif paint == "S" then
		return ctx.Colors[2]
	elseif paint == "A" then
		return ctx.Colors[3]
	end
	return WHITE
end

-- Sphere (uniform)
local function ball(ctx: Ctx, name: string, diameter: number, position: Vector3, paint: string, material: Enum.Material?, colorOverride: Color3?): BasePart
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * diameter * ctx.Scale
	part.CFrame = CFrame.new(position * ctx.Scale)
	finishPart(ctx, part, name, colorOverride or paintColor(ctx, paint), paint, material)
	return part
end

-- Ellipsoid (sphere mesh stretched to the part size)
local function ellipsoid(ctx: Ctx, name: string, size: Vector3, cf: CFrame, paint: string, material: Enum.Material?): BasePart
	local part = Instance.new("Part")
	part.Size = size * ctx.Scale
	part.CFrame = scaledCF(ctx, cf)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	finishPart(ctx, part, name, paintColor(ctx, paint), paint, material)
	return part
end

local function block(ctx: Ctx, name: string, size: Vector3, cf: CFrame, paint: string, material: Enum.Material?): BasePart
	local part = Instance.new("Part")
	part.Size = size * ctx.Scale
	part.CFrame = scaledCF(ctx, cf)
	finishPart(ctx, part, name, paintColor(ctx, paint), paint, material)
	return part
end

-- Cylinder standing upright (length along Y).
local function cylinder(ctx: Ctx, name: string, length: number, diameter: number, cf: CFrame, paint: string, material: Enum.Material?): BasePart
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(length, diameter, diameter) * ctx.Scale
	part.CFrame = scaledCF(ctx, cf * CFrame.Angles(0, 0, math.rad(90)))
	finishPart(ctx, part, name, paintColor(ctx, paint), paint, material)
	return part
end

-- Triangular prism "spike" (two wedges back to back), apex pointing +Y.
local function spike(ctx: Ctx, name: string, size: Vector3, cf: CFrame, paint: string, material: Enum.Material?)
	local half = Vector3.new(size.X, size.Y, size.Z / 2)
	local front = Instance.new("WedgePart")
	front.Size = half * ctx.Scale
	front.CFrame = scaledCF(ctx, cf * CFrame.new(0, 0, -size.Z / 4))
	finishPart(ctx, front, name, paintColor(ctx, paint), paint, material)
	local back = Instance.new("WedgePart")
	back.Size = half * ctx.Scale
	back.CFrame = scaledCF(ctx, cf * CFrame.new(0, 0, size.Z / 4) * CFrame.Angles(0, math.pi, 0))
	finishPart(ctx, back, name, paintColor(ctx, paint), paint, material)
end

local function wedge(ctx: Ctx, name: string, size: Vector3, cf: CFrame, paint: string, material: Enum.Material?): BasePart
	local part = Instance.new("WedgePart")
	part.Size = size * ctx.Scale
	part.CFrame = scaledCF(ctx, cf)
	finishPart(ctx, part, name, paintColor(ctx, paint), paint, material)
	return part
end

local function eyes(ctx: Ctx, center: Vector3, spacing: number, size: number)
	for _, side in { -1, 1 } do
		local p = center + Vector3.new(side * spacing, 0, 0)
		ball(ctx, "Eye", size, p, "Eye", Enum.Material.SmoothPlastic, WHITE)
		ball(ctx, "Pupil", size * 0.58, p + Vector3.new(0, -size * 0.02, -size * 0.3), "Pupil", Enum.Material.SmoothPlastic, DARK)
		ball(ctx, "Shine", size * 0.2, p + Vector3.new(size * 0.12, size * 0.14, -size * 0.52), "Eye", Enum.Material.Neon, WHITE)
	end
end

---------------------------------------------------------------- body plans
type Anchors = { Head: CFrame, Back: CFrame, Tail: CFrame, Height: number }

local Bodies = {}

function Bodies.Blob(ctx: Ctx): Anchors
	ellipsoid(ctx, "Body", Vector3.new(3.2, 2.8, 3.0), CFrame.new(0, 1.4, 0), "P")
	ellipsoid(ctx, "Belly", Vector3.new(2.1, 1.7, 0.7), CFrame.new(0, 1.15, -1.2), "S")
	for _, side in { -1, 1 } do
		ellipsoid(ctx, "Foot", Vector3.new(0.9, 0.5, 1.1), CFrame.new(side * 0.8, 0.25, -0.5), "S")
	end
	eyes(ctx, Vector3.new(0, 1.95, -1.32), 0.48, 0.62)
	return { Head = CFrame.new(0, 2.7, 0), Back = CFrame.new(0, 2.2, 0.8), Tail = CFrame.new(0, 1.0, 1.5), Height = 2.9 }
end

function Bodies.Quad(ctx: Ctx): Anchors
	ellipsoid(ctx, "Torso", Vector3.new(2.2, 1.7, 3.2), CFrame.new(0, 1.7, 0.25), "P")
	ellipsoid(ctx, "Chest", Vector3.new(1.4, 1.1, 0.8), CFrame.new(0, 1.55, -1.2), "S")
	for _, x in { -0.7, 0.7 } do
		for _, z in { -0.75, 1.15 } do
			cylinder(ctx, "Leg", 1.15, 0.6, CFrame.new(x, 0.58, z), "S")
		end
	end
	ball(ctx, "Head", 2.0, Vector3.new(0, 2.75, -1.45), "P")
	ellipsoid(ctx, "Snout", Vector3.new(1.0, 0.7, 0.8), CFrame.new(0, 2.45, -2.35), "S")
	ball(ctx, "Nose", 0.28, Vector3.new(0, 2.62, -2.76), "Pupil", Enum.Material.SmoothPlastic, DARK)
	for _, side in { -1, 1 } do
		spike(ctx, "Ear", Vector3.new(0.45, 0.95, 0.55), CFrame.new(side * 0.62, 3.95, -1.35) * CFrame.Angles(0, 0, -side * 0.25), "A")
	end
	ellipsoid(ctx, "Tail", Vector3.new(0.55, 0.55, 1.7), CFrame.new(0, 2.15, 2.15) * CFrame.Angles(math.rad(-30), 0, 0), "P")
	eyes(ctx, Vector3.new(0, 2.98, -2.28), 0.42, 0.5)
	return { Head = CFrame.new(0, 3.75, -1.45), Back = CFrame.new(0, 2.55, 0.45), Tail = CFrame.new(0, 2.6, 2.85), Height = 4.0 }
end

function Bodies.Bird(ctx: Ctx): Anchors
	ellipsoid(ctx, "Body", Vector3.new(2.2, 2.4, 2.3), CFrame.new(0, 1.9, 0), "P")
	ellipsoid(ctx, "Belly", Vector3.new(1.5, 1.6, 0.6), CFrame.new(0, 1.7, -0.95), "S")
	ball(ctx, "Head", 1.65, Vector3.new(0, 3.4, -0.35), "P")
	wedge(ctx, "Beak", Vector3.new(0.45, 0.4, 0.75), CFrame.new(0, 3.25, -1.45), "A")
	for _, side in { -1, 1 } do
		ellipsoid(ctx, "Wing", Vector3.new(0.4, 1.7, 2.1), CFrame.new(side * 1.2, 2.1, 0.15) * CFrame.Angles(0, 0, side * math.rad(18)), "S")
		cylinder(ctx, "Leg", 0.75, 0.25, CFrame.new(side * 0.42, 0.38, 0), "A")
	end
	wedge(ctx, "TailFan", Vector3.new(1.3, 0.35, 1.3), CFrame.new(0, 1.35, 1.45) * CFrame.Angles(0, math.pi, 0), "S")
	eyes(ctx, Vector3.new(0, 3.55, -1.06), 0.36, 0.48)
	return { Head = CFrame.new(0, 4.15, -0.35), Back = CFrame.new(0, 2.8, 0.6), Tail = CFrame.new(0, 1.4, 2.0), Height = 4.3 }
end

function Bodies.Serpent(ctx: Ctx): Anchors
	ball(ctx, "TailTip", 0.7, Vector3.new(0, 0.4, 2.55), "S")
	ball(ctx, "Segment", 1.15, Vector3.new(0.35, 0.65, 1.75), "P")
	ball(ctx, "Segment", 1.4, Vector3.new(0.55, 1.0, 0.7), "S")
	ball(ctx, "Segment", 1.5, Vector3.new(0.05, 1.55, -0.25), "P")
	ball(ctx, "Segment", 1.4, Vector3.new(-0.25, 2.3, -0.9), "S")
	ellipsoid(ctx, "Head", Vector3.new(1.7, 1.45, 2.0), CFrame.new(0, 3.2, -1.45), "P")
	ellipsoid(ctx, "Jaw", Vector3.new(1.3, 0.6, 1.4), CFrame.new(0, 2.75, -1.85), "S")
	for _, side in { -1, 1 } do
		spike(ctx, "Horn", Vector3.new(0.3, 1.0, 0.5), CFrame.new(side * 0.5, 4.05, -1.2) * CFrame.Angles(math.rad(-25), 0, -side * 0.2), "A")
	end
	eyes(ctx, Vector3.new(0, 3.42, -2.3), 0.45, 0.46)
	return { Head = CFrame.new(0, 3.95, -1.45), Back = CFrame.new(0, 2.1, 0.0), Tail = CFrame.new(0, 0.6, 2.7), Height = 4.2 }
end

function Bodies.Golem(ctx: Ctx): Anchors
	block(ctx, "Torso", Vector3.new(2.4, 2.2, 1.6), CFrame.new(0, 2.3, 0), "P")
	block(ctx, "Head", Vector3.new(1.6, 1.3, 1.4), CFrame.new(0, 4.05, -0.1), "P")
	for _, side in { -1, 1 } do
		block(ctx, "Arm", Vector3.new(0.8, 1.9, 0.85), CFrame.new(side * 1.65, 2.15, 0) * CFrame.Angles(0, 0, side * 0.08), "S")
		block(ctx, "Leg", Vector3.new(0.85, 1.2, 0.95), CFrame.new(side * 0.6, 0.6, 0), "S")
	end
	ball(ctx, "Core", 0.65, Vector3.new(0, 2.55, -0.8), "A", Enum.Material.Neon)
	eyes(ctx, Vector3.new(0, 4.15, -0.84), 0.36, 0.42)
	return { Head = CFrame.new(0, 4.7, -0.1), Back = CFrame.new(0, 3.2, 0.85), Tail = CFrame.new(0, 1.6, 0.9), Height = 4.8 }
end

function Bodies.Sprite(ctx: Ctx): Anchors
	ball(ctx, "Body", 1.9, Vector3.new(0, 2.6, 0), "P")
	ellipsoid(ctx, "Belly", Vector3.new(1.2, 1.0, 0.5), CFrame.new(0, 2.35, -0.72), "S")
	for _, side in { -1, 1 } do
		local wing = ellipsoid(ctx, "Wing", Vector3.new(0.15, 1.5, 1.05), CFrame.new(side * 1.0, 2.95, 0.45) * CFrame.Angles(0, side * math.rad(25), side * math.rad(-20)), "A", Enum.Material.Glass)
		wing.Transparency = 0.25
	end
	local halo = cylinder(ctx, "Halo", 0.12, 1.5, CFrame.new(0, 3.95, 0), "A", Enum.Material.Neon)
	halo.Transparency = 0.35
	ellipsoid(ctx, "Wisp", Vector3.new(0.5, 0.5, 1.1), CFrame.new(0, 2.05, 0.95) * CFrame.Angles(math.rad(30), 0, 0), "P")
	eyes(ctx, Vector3.new(0, 2.78, -0.84), 0.34, 0.44)
	return { Head = CFrame.new(0, 3.55, 0), Back = CFrame.new(0, 2.8, 0.8), Tail = CFrame.new(0, 2.0, 1.3), Height = 4.1 }
end

function Bodies.Dragon(ctx: Ctx): Anchors
	ellipsoid(ctx, "Torso", Vector3.new(2.6, 2.0, 3.6), CFrame.new(0, 2.0, 0.3), "P")
	ellipsoid(ctx, "Belly", Vector3.new(1.7, 1.3, 2.6), CFrame.new(0, 1.55, 0.1), "S")
	for _, x in { -0.85, 0.85 } do
		for _, z in { -0.8, 1.3 } do
			cylinder(ctx, "Leg", 1.3, 0.75, CFrame.new(x, 0.65, z), "P")
		end
	end
	ellipsoid(ctx, "Neck", Vector3.new(0.95, 1.7, 0.95), CFrame.new(0, 3.05, -1.35) * CFrame.Angles(math.rad(-25), 0, 0), "P")
	ellipsoid(ctx, "Head", Vector3.new(1.55, 1.35, 2.0), CFrame.new(0, 3.95, -2.0), "P")
	ellipsoid(ctx, "Snout", Vector3.new(1.1, 0.7, 1.0), CFrame.new(0, 3.7, -2.85), "S")
	for _, side in { -1, 1 } do
		spike(ctx, "Horn", Vector3.new(0.3, 1.0, 0.5), CFrame.new(side * 0.45, 4.75, -1.7) * CFrame.Angles(math.rad(-30), 0, -side * 0.15), "A")
		local wingPart = wedge(ctx, "Wing", Vector3.new(0.2, 1.9, 2.5), CFrame.new(side * 1.55, 3.3, 0.5) * CFrame.Angles(0, 0, -side * math.rad(40)) * CFrame.Angles(0, math.pi, 0), "S")
		wingPart.Transparency = 0.05
	end
	ellipsoid(ctx, "Tail", Vector3.new(0.75, 0.75, 2.5), CFrame.new(0, 1.65, 2.7) * CFrame.Angles(math.rad(15), 0, 0), "P")
	spike(ctx, "TailSpike", Vector3.new(0.3, 0.7, 0.6), CFrame.new(0, 1.65, 4.0), "A")
	for i = 0, 2 do
		spike(ctx, "BackSpike", Vector3.new(0.25, 0.55, 0.5), CFrame.new(0, 3.0, -0.4 + i * 0.75), "A")
	end
	eyes(ctx, Vector3.new(0, 4.18, -2.86), 0.45, 0.44)
	return { Head = CFrame.new(0, 4.65, -2.0), Back = CFrame.new(0, 3.05, 0.7), Tail = CFrame.new(0, 1.6, 4.1), Height = 5.0 }
end

function Bodies.Fish(ctx: Ctx): Anchors
	ellipsoid(ctx, "Body", Vector3.new(1.7, 2.0, 3.0), CFrame.new(0, 2.4, 0), "P")
	ellipsoid(ctx, "Belly", Vector3.new(1.2, 1.0, 2.0), CFrame.new(0, 1.95, -0.2), "S")
	wedge(ctx, "TailFin", Vector3.new(0.2, 1.7, 1.3), CFrame.new(0, 2.4, 1.95) * CFrame.Angles(0, math.pi, 0), "A")
	wedge(ctx, "DorsalFin", Vector3.new(0.2, 0.9, 1.3), CFrame.new(0, 3.55, 0.2) * CFrame.Angles(0, math.pi, 0), "A")
	for _, side in { -1, 1 } do
		ellipsoid(ctx, "Fin", Vector3.new(0.15, 0.65, 0.95), CFrame.new(side * 0.88, 2.05, -0.15) * CFrame.Angles(0, 0, side * math.rad(30)), "A")
	end
	eyes(ctx, Vector3.new(0, 2.78, -1.12), 0.52, 0.48)
	return { Head = CFrame.new(0, 3.4, -0.8), Back = CFrame.new(0, 3.3, 0.3), Tail = CFrame.new(0, 2.4, 2.4), Height = 3.7 }
end

function Bodies.Bug(ctx: Ctx): Anchors
	ellipsoid(ctx, "Abdomen", Vector3.new(1.8, 1.4, 2.2), CFrame.new(0, 1.3, 1.0), "P")
	ball(ctx, "Thorax", 1.3, Vector3.new(0, 1.4, -0.4), "S")
	ball(ctx, "Head", 1.35, Vector3.new(0, 1.85, -1.45), "P")
	for _, side in { -1, 1 } do
		for i, z in { -0.7, -0.1, 0.5 } do
			cylinder(ctx, "Leg", 1.3, 0.15, CFrame.new(side * 0.85, 0.6, z) * CFrame.Angles(0, 0, side * math.rad(35 + i * 5)), "A")
		end
		cylinder(ctx, "Antenna", 1.0, 0.1, CFrame.new(side * 0.32, 2.75, -1.6) * CFrame.Angles(math.rad(-20), 0, -side * math.rad(20)), "S")
		ball(ctx, "AntennaTip", 0.3, Vector3.new(side * 0.5, 3.25, -1.8), "A", Enum.Material.Neon)
		local wing = ellipsoid(ctx, "Wing", Vector3.new(0.1, 1.3, 1.9), CFrame.new(side * 0.65, 2.15, 0.6) * CFrame.Angles(0, side * math.rad(10), side * math.rad(-30)), "A", Enum.Material.Glass)
		wing.Transparency = 0.35
	end
	eyes(ctx, Vector3.new(0, 2.0, -2.02), 0.36, 0.52)
	return { Head = CFrame.new(0, 2.55, -1.45), Back = CFrame.new(0, 2.0, 0.8), Tail = CFrame.new(0, 1.2, 2.15), Height = 3.3 }
end

---------------------------------------------------------------- element features
local Features = {}

function Features.Flame(ctx: Ctx, a: Anchors)
	for i, x in { -0.32, 0, 0.32 } do
		local h = if i == 2 then 1.1 else 0.75
		spike(ctx, "Flame", Vector3.new(0.3, h, 0.45), a.Head * CFrame.new(x, h / 2, 0), "A", Enum.Material.Neon)
	end
	ball(ctx, "TailFlame", 0.75, a.Tail.Position, "A", Enum.Material.Neon)
end

function Features.Aqua(ctx: Ctx, a: Anchors)
	wedge(ctx, "Fin", Vector3.new(0.2, 0.8, 1.1), a.Back * CFrame.new(0, 0.4, 0) * CFrame.Angles(0, math.pi, 0), "A")
	ball(ctx, "Droplet", 0.45, (a.Head * CFrame.new(0, 0.35, 0)).Position, "A", Enum.Material.Glass)
end

function Features.Leaf(ctx: Ctx, a: Anchors)
	for _, side in { -1, 1 } do
		ellipsoid(ctx, "Leaf", Vector3.new(0.15, 0.55, 1.1), a.Head * CFrame.new(side * 0.25, 0.35, 0) * CFrame.Angles(math.rad(-35), 0, side * math.rad(35)), "A")
	end
	cylinder(ctx, "Stem", 0.45, 0.12, a.Head * CFrame.new(0, 0.22, 0), "A")
end

function Features.Volt(ctx: Ctx, a: Anchors)
	spike(ctx, "Bolt", Vector3.new(0.25, 0.9, 0.5), a.Tail * CFrame.new(0, 0.45, 0) * CFrame.Angles(math.rad(-30), 0, 0), "A", Enum.Material.Neon)
	ball(ctx, "Spark", 0.35, (a.Head * CFrame.new(0.5, 0.3, 0)).Position, "A", Enum.Material.Neon)
end

function Features.Frost(ctx: Ctx, a: Anchors)
	for i = -1, 1 do
		spike(ctx, "Crystal", Vector3.new(0.3, 0.8 + (i == 0 and 0.35 or 0), 0.4), a.Back * CFrame.new(i * 0.4, 0.4, 0), "A", Enum.Material.Ice)
	end
end

function Features.Stone(ctx: Ctx, a: Anchors)
	block(ctx, "Rock", Vector3.new(0.7, 0.55, 0.7), a.Back * CFrame.new(-0.3, 0.2, 0) * CFrame.Angles(0.3, 0.5, 0.2), "S", Enum.Material.Slate)
	block(ctx, "Rock", Vector3.new(0.5, 0.45, 0.5), a.Back * CFrame.new(0.35, 0.15, 0.3) * CFrame.Angles(0.5, 0.2, 0.4), "S", Enum.Material.Slate)
end

function Features.Sky(ctx: Ctx, a: Anchors)
	for i, offset in { Vector3.new(-0.45, 0.2, 0.2), Vector3.new(0.45, 0.25, 0.1), Vector3.new(0, 0.35, 0.4) } do
		ball(ctx, "Cloud", 0.6 + i * 0.08, (a.Back * CFrame.new(offset)).Position, "Fixed", Enum.Material.SmoothPlastic, WHITE)
	end
end

function Features.Mystic(ctx: Ctx, a: Anchors)
	ball(ctx, "Orb", 0.5, (a.Head * CFrame.new(0, 0.9, 0)).Position, "A", Enum.Material.Neon)
	local ring = cylinder(ctx, "Ring", 0.08, 1.2, a.Head * CFrame.new(0, 0.9, 0), "A", Enum.Material.Neon)
	ring.Transparency = 0.5
end

function Features.Shadow(ctx: Ctx, a: Anchors)
	ellipsoid(ctx, "Wisp", Vector3.new(0.4, 0.4, 1.2), a.Tail * CFrame.Angles(math.rad(25), 0, 0), "A", Enum.Material.Neon)
	for _, part in ctx.Parts do
		if part.Name == "Pupil" then
			part.Color = ctx.Colors[3]
			part.Material = Enum.Material.Neon
		end
	end
end

function Features.Metal(ctx: Ctx, a: Anchors)
	cylinder(ctx, "Antenna", 0.8, 0.12, a.Head * CFrame.new(0, 0.4, 0), "S", Enum.Material.Metal)
	ball(ctx, "AntennaTip", 0.35, (a.Head * CFrame.new(0, 0.85, 0)).Position, "A", Enum.Material.Neon)
end

function Features.Toxic(ctx: Ctx, a: Anchors)
	for i, offset in { Vector3.new(-0.3, 0, -0.2), Vector3.new(0.35, -0.1, 0.1), Vector3.new(0, 0.1, 0.35) } do
		ball(ctx, "Bubble", 0.3 + i * 0.07, (a.Back * CFrame.new(offset)).Position, "A", Enum.Material.Glass)
	end
end

function Features.Cosmic(ctx: Ctx, a: Anchors)
	local ring = cylinder(ctx, "StarRing", 0.06, a.Height * 0.9, CFrame.new(0, a.Height * 0.55, 0) * CFrame.Angles(math.rad(15), 0, math.rad(10)), "A", Enum.Material.Neon)
	ring.Transparency = 0.6
	ball(ctx, "Star", 0.3, (a.Head * CFrame.new(0.6, 0.6, 0)).Position, "Fixed", Enum.Material.Neon, WHITE)
	ball(ctx, "Star", 0.22, (a.Back * CFrame.new(-0.7, 0.5, 0)).Position, "Fixed", Enum.Material.Neon, WHITE)
end

---------------------------------------------------------------- mutations
local function shiftHue(color: Color3, amount: number, satBoost: number?, valueMul: number?): Color3
	local h, s, v = color:ToHSV()
	return Color3.fromHSV((h + amount) % 1, math.clamp(s + (satBoost or 0), 0, 1), math.clamp(v * (valueMul or 1), 0, 1))
end

local function addEmitter(root: BasePart, color: Color3, rate: number, size: number, speed: number?)
	local attachment = Instance.new("Attachment")
	attachment.Name = "FXAttachment"
	attachment.Parent = root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "MutationFX"
	emitter.Texture = PARTICLE_TEXTURE
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(0.8, 1.6)
	emitter.Speed = NumberRange.new(speed or 1.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new(0.2)
	emitter:AddTag("CreatureFX")
	emitter.Parent = attachment
end

local Mutations = {}

function Mutations.Shiny(ctx: Ctx, fx: boolean)
	for _, part in ctx.Parts do
		local paint = part:GetAttribute("Paint")
		if paint == "P" or paint == "S" or paint == "A" then
			part.Color = shiftHue(part.Color, 0.14, 0.15, 1.08)
		end
	end
	if fx then
		addEmitter(ctx.Root, Color3.fromRGB(255, 255, 220), 4, 0.5 * ctx.Scale)
	end
end

function Mutations.Golden(ctx: Ctx, fx: boolean)
	local gold = { P = Color3.fromRGB(255, 200, 50), S = Color3.fromRGB(255, 230, 130), A = Color3.fromRGB(255, 160, 20) }
	for _, part in ctx.Parts do
		local paint = part:GetAttribute("Paint")
		local c = gold[paint]
		if c then
			part.Color = c
			if part.Material ~= Enum.Material.Neon and part.Material ~= Enum.Material.Glass then
				part.Material = Enum.Material.Metal
				part.Reflectance = 0.15
			end
		end
	end
	if fx then
		addEmitter(ctx.Root, Color3.fromRGB(255, 220, 90), 5, 0.55 * ctx.Scale)
	end
end

function Mutations.Dark(ctx: Ctx, fx: boolean)
	for _, part in ctx.Parts do
		local paint = part:GetAttribute("Paint")
		if paint == "P" or paint == "S" then
			part.Color = shiftHue(part.Color, 0.72, 0.2, 0.3)
		elseif paint == "A" or part.Name == "Pupil" then
			part.Color = Color3.fromRGB(190, 70, 255)
			part.Material = Enum.Material.Neon
		end
	end
	if fx then
		addEmitter(ctx.Root, Color3.fromRGB(120, 40, 200), 6, 0.7 * ctx.Scale, 1)
	end
end

function Mutations.Holographic(ctx: Ctx, fx: boolean)
	local palette = { Color3.fromRGB(120, 255, 240), Color3.fromRGB(255, 140, 240), Color3.fromRGB(160, 170, 255) }
	local i = 0
	for _, part in ctx.Parts do
		local paint = part:GetAttribute("Paint")
		if paint == "P" or paint == "S" or paint == "A" then
			i += 1
			part.Color = palette[(i % #palette) + 1]
			part.Material = Enum.Material.ForceField
		end
	end
	if fx then
		addEmitter(ctx.Root, Color3.fromRGB(150, 255, 255), 4, 0.5 * ctx.Scale)
	end
end

function Mutations.Rainbow(ctx: Ctx, fx: boolean)
	local i = 0
	for _, part in ctx.Parts do
		local paint = part:GetAttribute("Paint")
		if paint == "P" or paint == "S" or paint == "A" then
			i += 1
			local hue = (i * 0.13) % 1
			part.Color = Color3.fromHSV(hue, 0.75, 1)
			part:SetAttribute("Hue", hue)
		end
	end
	ctx.Model:SetAttribute("Rainbow", true)
	if fx then
		addEmitter(ctx.Root, Color3.fromRGB(255, 255, 255), 6, 0.55 * ctx.Scale)
	end
end

function Mutations.Glitched(ctx: Ctx, fx: boolean)
	local palette = { Color3.fromRGB(0, 255, 140), Color3.fromRGB(255, 0, 200), Color3.fromRGB(20, 20, 30) }
	local i = 0
	for _, part in ctx.Parts do
		local paint = part:GetAttribute("Paint")
		if paint == "P" or paint == "S" or paint == "A" then
			i += 1
			part.Color = palette[(i % #palette) + 1]
			if i % 2 == 0 then
				part.Material = Enum.Material.Neon
			end
		end
	end
	ctx.Model:SetAttribute("Glitch", true)
	if fx then
		addEmitter(ctx.Root, Color3.fromRGB(0, 255, 140), 8, 0.4 * ctx.Scale, 3)
	end
end

function Mutations.Cosmic(ctx: Ctx, fx: boolean)
	for _, part in ctx.Parts do
		local paint = part:GetAttribute("Paint")
		if paint == "P" then
			part.Color = Color3.fromRGB(25, 20, 70)
		elseif paint == "S" then
			part.Color = Color3.fromRGB(80, 50, 180)
		elseif paint == "A" then
			part.Color = Color3.fromRGB(150, 220, 255)
			part.Material = Enum.Material.Neon
		end
	end
	if fx then
		addEmitter(ctx.Root, Color3.fromRGB(200, 220, 255), 10, 0.45 * ctx.Scale, 2)
	end
end

---------------------------------------------------------------- build
local function elementMaterial(element: string): Enum.Material
	if element == "Stone" then
		return Enum.Material.Slate
	elseif element == "Metal" then
		return Enum.Material.Metal
	elseif element == "Frost" then
		return Enum.Material.Glacier
	end
	return Enum.Material.SmoothPlastic
end

local function weldAll(ctx: Ctx)
	for _, part in ctx.Parts do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = ctx.Root
		weld.Part1 = part
		weld.Parent = part
	end
end

local function makeRoot(model: Model, scale: number): BasePart
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(2, 0.2, 2) * scale
	root.CFrame = CFrame.new()
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Massless = true
	root.Parent = model
	model.PrimaryPart = root
	return root
end

local function buildCustom(template: Model, scale: number): Model
	local model = template:Clone()
	local _, size = model:GetBoundingBox()
	local pivot = model:GetPivot()
	-- Root at the bottom centre of the bounding box.
	local root = makeRoot(model, scale)
	root.CFrame = CFrame.new(pivot.Position - Vector3.new(0, size.Y / 2, 0)) * pivot.Rotation
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = d
			weld.Parent = d
		end
	end
	model:SetAttribute("Height", size.Y)
	return model
end

export type BuildOptions = {
	Mutation: string?,
	Scale: number?,
	Effects: boolean?, -- particle effects (default true)
}

function CreatureBuilder.Build(id: string, options: BuildOptions?): Model
	local opts: BuildOptions = options or {}
	local def = Catalog.Get(id)
	local rarity = def and RarityConfig.Rarities[def.Rarity]
	local scale = ((rarity and rarity.ModelScale) or 1) * (opts.Scale or 1)
	local fx = opts.Effects ~= false

	-- Custom/licensed model override.
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local creatures = assets and assets:FindFirstChild("Creatures")
	if creatures and def then
		local template = creatures:FindFirstChild(def.Model or def.Id)
		if template and template:IsA("Model") then
			local custom = buildCustom(template, scale)
			custom.Name = def.Id
			return custom
		end
	end

	local model = Instance.new("Model")
	model.Name = def and def.Id or "Unknown"
	local root = makeRoot(model, scale)
	local ctx: Ctx = {
		Model = model,
		Root = root,
		Scale = scale,
		Colors = def and def.Colors or { Color3.new(0.8, 0.8, 0.8), Color3.new(1, 1, 1), Color3.new(0.3, 0.3, 0.3) },
		Material = def and elementMaterial(def.Element) or Enum.Material.SmoothPlastic,
		Parts = {},
	}

	local bodyBuilder = Bodies[def and def.Body or "Blob"] or Bodies.Blob
	local anchors: Anchors = bodyBuilder(ctx)
	local feature = def and Features[def.Element]
	if feature then
		feature(ctx, anchors)
	end

	local mutation = opts.Mutation
	if mutation and Mutations[mutation] then
		Mutations[mutation](ctx, fx)
	end

	-- Legendary+ creatures get a soft glow.
	if fx and rarity and rarity.Tier >= 5 then
		local light = Instance.new("PointLight")
		light.Color = rarity.Color
		light.Range = 8 * scale
		light.Brightness = 1.2
		light.Shadows = false
		light.Parent = root
	end

	weldAll(ctx)
	model:SetAttribute("Height", anchors.Height * scale)
	return model
end

return CreatureBuilder
