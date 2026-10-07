--[[
	Catalog
	Indexed, validated view of CollectibleConfig with licensed overrides applied.
	Everything (server + client) should read collectible definitions from here.
]]

local Config = script.Parent.Config
local CollectibleConfig = require(Config.CollectibleConfig)
local RarityConfig = require(Config.RarityConfig)
local ContentConfig = require(Config.ContentConfig)
local LicensedContent = require(Config.LicensedContent)

export type Def = {
	Id: string,
	Number: number,
	Name: string,
	Rarity: string,
	Price: number,
	Income: number,
	Element: string,
	Body: string,
	Colors: { Color3 },
	Animation: string,
	Description: string,
	StealDifficulty: number,
	Weight: number,
	RequiredRebirths: number,
	Event: string?,
	Cry: number,
	ImageId: string?,
	Model: string?,
	Limited: boolean,
}

local Catalog = {}

Catalog.All = {} :: { Def }
Catalog.ById = {} :: { [string]: Def }
Catalog.ByRarity = {} :: { [string]: { Def } }
Catalog.ByEvent = {} :: { [string]: { Def } }
Catalog.ByElement = {} :: { [string]: { Def } }
Catalog.Errors = {} :: { string }

local VALID_BODIES = {
	Blob = true, Quad = true, Bird = true, Serpent = true, Golem = true,
	Sprite = true, Dragon = true, Fish = true, Bug = true,
}
local VALID_ANIMATIONS = { Bob = true, Hop = true, Float = true, Sway = true, Spin = true, Slither = true }

for _, rarity in RarityConfig.Order do
	Catalog.ByRarity[rarity] = {}
end
for _, element in CollectibleConfig.ElementOrder do
	Catalog.ByElement[element] = {}
end

for index, raw in CollectibleConfig.List do
	local function fail(msg: string)
		table.insert(Catalog.Errors, string.format("Collectible #%d (%s): %s", index, tostring(raw.Id), msg))
	end
	if type(raw.Id) ~= "string" or raw.Id == "" then
		fail("missing Id")
		continue
	end
	if Catalog.ById[raw.Id] then
		fail("duplicate Id")
		continue
	end
	if not RarityConfig.Rarities[raw.Rarity] then
		fail("unknown rarity " .. tostring(raw.Rarity))
		continue
	end
	if not CollectibleConfig.Elements[raw.Element] then
		fail("unknown element " .. tostring(raw.Element))
		continue
	end
	if type(raw.Price) ~= "number" or raw.Price <= 0 or type(raw.Income) ~= "number" or raw.Income <= 0 then
		fail("Price and Income must be positive numbers")
		continue
	end
	if raw.Rarity == "Limited" and type(raw.Event) ~= "string" then
		fail("Limited collectibles need an Event")
	end

	local override = ContentConfig.LicensedMode and LicensedContent[raw.Id] or nil
	local def: Def = {
		Id = raw.Id,
		Number = index,
		Name = (override and override.Name) or raw.Name,
		Rarity = raw.Rarity,
		Price = raw.Price,
		Income = raw.Income,
		Element = raw.Element,
		Body = VALID_BODIES[raw.Body] and raw.Body or "Blob",
		Colors = raw.Colors or { Color3.new(1, 1, 1), Color3.new(0.8, 0.8, 0.8), Color3.new(0, 0, 0) },
		Animation = VALID_ANIMATIONS[raw.Animation] and raw.Animation or "Bob",
		Description = (override and override.Description) or raw.Description or "",
		StealDifficulty = raw.StealDifficulty or 1,
		Weight = raw.Weight or 1,
		RequiredRebirths = raw.RequiredRebirths or 0,
		Event = raw.Event,
		Cry = raw.Cry or 1,
		ImageId = override and override.ImageId or nil,
		Model = override and override.Model or nil,
		Limited = raw.Rarity == "Limited",
	}
	table.insert(Catalog.All, def)
	Catalog.ById[def.Id] = def
	table.insert(Catalog.ByRarity[def.Rarity], def)
	table.insert(Catalog.ByElement[def.Element], def)
	if def.Event then
		Catalog.ByEvent[def.Event] = Catalog.ByEvent[def.Event] or {}
		table.insert(Catalog.ByEvent[def.Event], def)
	end
end

-- Number of collectibles that count toward collection completion (non-limited).
Catalog.CompletionTotal = 0
for _, def in Catalog.All do
	if not def.Limited then
		Catalog.CompletionTotal += 1
	end
end

function Catalog.Get(id: any): Def?
	if type(id) ~= "string" then
		return nil
	end
	return Catalog.ById[id]
end

function Catalog.IsValid(id: any): boolean
	return type(id) == "string" and Catalog.ById[id] ~= nil
end

function Catalog.RarityInfo(id: string)
	local def = Catalog.ById[id]
	return def and RarityConfig.Rarities[def.Rarity] or nil
end

function Catalog.Element(id: string)
	local def = Catalog.ById[id]
	return def and CollectibleConfig.Elements[def.Element] or nil
end

return Catalog
