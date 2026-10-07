--[[
	ConveyorService
	Spawns collectibles onto the conveyors and handles purchases.

	Movement is NOT simulated on the server: every item stores its spawn time,
	start point, direction and speed as attributes. Clients animate it locally
	(zero network traffic per frame) and the server computes the exact same
	position from the same formula when validating a purchase.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local ConveyorConfig = require(Config.ConveyorConfig)
local MapConfig = require(Config.MapConfig)
local RarityConfig = require(Config.RarityConfig)
local MutationConfig = require(Config.MutationConfig)
local Catalog = require(Shared.Catalog)
local Economy = require(Shared.Economy)
local Odds = require(Shared.Util.Odds)
local Format = require(Shared.Util.Format)
local CreatureBuilder = require(Shared.CreatureBuilder)
local CardBillboard = require(Shared.CardBillboard)

local Modules = script.Parent.Parent.Modules
local Registry = require(Modules.Registry)
local ActionBus = require(Modules.ActionBus)
local Log = require(Modules.Log)

local ConveyorService = {}

export type ConveyorItem = {
	Uid: string,
	Conveyor: string,
	Id: string,
	Mutation: string,
	Trait: string?,
	Price: number,
	SpawnTime: number,
	Start: Vector3,
	Direction: Vector3,
	Speed: number,
	Length: number,
	Model: Model,
}

local items: { [string]: ConveyorItem } = {}
local folders: { [string]: Folder } = {}
local rng = Random.new()

function ConveyorService:Init() end

function ConveyorService:SetMap(mapRefs)
	for name, refs in mapRefs.Conveyors do
		folders[name] = refs.Items
	end
end

function ConveyorService:Start()
	for _, name in ConveyorConfig.Order do
		local cfg = ConveyorConfig.Conveyors[name]
		if not folders[name] or not MapConfig.Conveyors[name] then
			continue
		end
		task.spawn(function()
			-- Pre-fill the belt so new servers don't start empty.
			local geo = MapConfig.Conveyors[name]
			local length = (geo.End - geo.Start).Magnitude
			local lifetime = length / cfg.Speed
			local prefill = math.floor(lifetime / cfg.SpawnInterval * 0.6)
			for i = prefill, 1, -1 do
				pcall(self.Spawn, self, name, nil, i * cfg.SpawnInterval)
			end
			while true do
				task.wait(cfg.SpawnInterval)
				local ok, err = pcall(self.Spawn, self, name, nil, 0)
				if not ok then
					Log.Error("Conveyor", "spawn failed: " .. tostring(err))
				end
			end
		end)
	end
	-- Expiry sweep
	task.spawn(function()
		while true do
			task.wait(1)
			local now = workspace:GetServerTimeNow()
			for uid, item in items do
				if (now - item.SpawnTime) * item.Speed >= item.Length then
					self:_remove(uid)
				end
			end
		end
	end)
end

function ConveyorService:_count(name: string): number
	local n = 0
	for _, item in items do
		if item.Conveyor == name then
			n += 1
		end
	end
	return n
end

function ConveyorService:ConveyorLuck(name: string): number
	local cfg = ConveyorConfig.Conveyors[name]
	return Registry.BoostService:ServerLuck() * cfg.LuckMultiplier
end

-- Spawns an item. `forced` = { Id, Mutation, Trait } (admin /spawn).
-- `age` pre-advances the item along the belt (used to pre-fill).
function ConveyorService:Spawn(name: string, forced: { Id: string, Mutation: string?, Trait: string? }?, age: number?)
	local cfg = ConveyorConfig.Conveyors[name]
	local geo = MapConfig.Conveyors[name]
	local folder = folders[name]
	if not cfg or not geo or not folder then
		return nil
	end
	if self:_count(name) >= cfg.MaxItems and not forced then
		return nil
	end
	local mods = Registry.EventService:GetModifiers()
	local luck = self:ConveyorLuck(name)
	local def
	local mutation
	local trait
	if forced then
		def = Catalog.Get(forced.Id)
		if not def then
			return nil
		end
		mutation = if MutationConfig.IsValid(forced.Mutation) then forced.Mutation else "Normal"
		trait = forced.Trait
	else
		def = Odds.RollCollectible({ Luck = luck, MinRarity = cfg.MinRarity, Modifiers = mods }, { ActiveEvents = mods.ActiveEvents }, rng)
		mutation = Odds.RollMutation(Odds.MutationChances(luck, mods), rng)
		trait = Odds.RollTrait(rng)
	end

	local startPos = geo.Start
	local direction = (geo.End - geo.Start).Unit
	local length = (geo.End - geo.Start).Magnitude
	local spawnTime = workspace:GetServerTimeNow() - (age or 0)
	local price = Economy.SpawnPrice(def.Id, mutation, trait)
	local uid = HttpService:GenerateGUID(false)

	local model = CreatureBuilder.Build(def.Id, { Mutation = mutation })
	model.Name = uid
	local startCF = CFrame.lookAt(startPos, startPos + direction)
	model:PivotTo(startCF + direction * math.min(length, (age or 0) * cfg.Speed))
	model:SetAttribute("Uid", uid)
	model:SetAttribute("Conveyor", name)
	model:SetAttribute("CollectibleId", def.Id)
	model:SetAttribute("Mutation", mutation)
	model:SetAttribute("Trait", trait or "")
	model:SetAttribute("Price", price)
	model:SetAttribute("Rarity", def.Rarity)
	model:SetAttribute("Start", startPos)
	model:SetAttribute("Direction", direction)
	model:SetAttribute("Speed", cfg.Speed)
	model:SetAttribute("SpawnTime", spawnTime)
	model:SetAttribute("Length", length)
	model:SetAttribute("RequiredRebirths", math.max(def.RequiredRebirths, cfg.RequiredRebirths))
	model:SetAttribute("Animation", def.Animation)
	CardBillboard.Attach(model, {
		Mode = "Conveyor",
		Id = def.Id,
		Mutation = mutation,
		Trait = trait,
		Price = price,
		Income = Economy.ItemIncome({ Uid = uid, Id = def.Id, Mutation = mutation, Trait = trait, Level = 1 }),
		RequiredRebirths = def.RequiredRebirths,
	})
	CollectionService:AddTag(model, "ConveyorItem")
	model.Parent = folder

	items[uid] = {
		Uid = uid,
		Conveyor = name,
		Id = def.Id,
		Mutation = mutation,
		Trait = trait,
		Price = price,
		SpawnTime = spawnTime,
		Start = startPos,
		Direction = direction,
		Speed = cfg.Speed,
		Length = length,
		Model = model,
	}

	-- Hype: tell the server when something special appears (not for pre-fill).
	local rarity = RarityConfig.Rarities[def.Rarity]
	if (age or 0) == 0 and rarity.Tier >= RarityConfig.Tier("Legendary") then
		local mutationText = if mutation ~= "Normal" then mutation .. " " else ""
		Registry.NetService:Announce(string.format("A %s %s%s just appeared on the %s!", string.upper(rarity.Name), mutationText, def.Name, cfg.Name), rarity.Color, "👀", def.Rarity)
	end
	return uid
end

function ConveyorService:_remove(uid: string)
	local item = items[uid]
	if not item then
		return
	end
	items[uid] = nil
	if item.Model then
		item.Model:Destroy()
	end
end

function ConveyorService:GetPosition(item: ConveyorItem, at: number?): Vector3
	local now = at or workspace:GetServerTimeNow()
	local travelled = math.clamp((now - item.SpawnTime) * item.Speed, 0, item.Length)
	return item.Start + item.Direction * travelled
end

function ConveyorService:GetItems(): { [string]: ConveyorItem }
	return items
end

function ConveyorService:Buy(player: Player, uid: any): (boolean, string?, any?)
	if type(uid) ~= "string" then
		Registry.AntiExploitService:Flag(player, "InvalidArgs", "BuyConveyor uid")
		return false, "Invalid item"
	end
	local item = items[uid]
	if not item then
		return false, "Too late — someone else got it!"
	end
	local data = Registry.DataService:Get(player)
	if not data then
		return false, "Not loaded"
	end
	local cfg = ConveyorConfig.Conveyors[item.Conveyor]
	local def = Catalog.Get(item.Id)
	if not def then
		return false, "Invalid item"
	end
	if data.Rebirths < cfg.RequiredRebirths then
		return false, string.format("The %s requires Rebirth %d", cfg.Name, cfg.RequiredRebirths)
	end
	if data.Rebirths < def.RequiredRebirths then
		return false, string.format("%s requires Rebirth %d to buy", def.Name, def.RequiredRebirths)
	end
	if Registry.StealService:IsThief(player) then
		return false, "You can't shop while stealing!"
	end

	-- Distance validation against the authoritative position (with latency slack).
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false, "No character"
	end
	local now = workspace:GetServerTimeNow()
	local posNow = self:GetPosition(item, now)
	local posBefore = self:GetPosition(item, now - 0.6)
	local limit = cfg.BuyRange + ConveyorConfig.LatencyTolerance
	local distance = math.min((root.Position - posNow).Magnitude, (root.Position - posBefore).Magnitude)
	if distance > limit then
		if distance > limit * 3 then
			Registry.AntiExploitService:Flag(player, "InvalidArgs", string.format("BuyConveyor from %.0f studs", distance))
		end
		return false, "Get closer to buy it!"
	end

	if not Registry.CollectibleService:HasSpace(player) then
		return false, "Your base is full! Upgrade it, or sell a critter."
	end
	if not Registry.EconomyService:SpendCash(player, item.Price, "Conveyor:" .. item.Id) then
		return false, string.format("You need %s (you have %s)", Format.Cash(item.Price), Format.Cash(data.Cash))
	end

	-- Claim the item before any yielding so nobody else can buy it.
	items[uid] = nil

	-- Personal luck bonus mutation roll (transparent; shown in the odds panel).
	local mutation = item.Mutation
	local bonus = false
	if mutation == "Normal" then
		local chance = Odds.BonusMutationRollChance(Registry.EconomyService:PersonalLuck(player))
		if chance > 0 and rng:NextNumber() < chance then
			local mods = Registry.EventService:GetModifiers()
			mutation = Odds.RollMutation(Odds.MutationChances(1, mods), rng)
			bonus = mutation ~= "Normal"
		end
	end

	local granted, err = Registry.CollectibleService:Grant(player, item.Id, {
		Mutation = mutation,
		Trait = item.Trait,
		Source = "Conveyor",
		TravelFrom = posNow,
		BonusMutation = bonus,
	})
	if item.Model then
		item.Model:Destroy()
	end
	if not granted then
		-- Should not happen (space was checked), but never take money for nothing.
		Registry.EconomyService:AddCash(player, item.Price, "Refund")
		return false, err or "Purchase failed"
	end

	data.Stats.Purchases += 1
	Registry.DataService:MarkDirty(player, "Stats")
	ActionBus.Fire(player, "Buy", 1, { Rarity = def.Rarity, Id = def.Id, Price = item.Price })

	local mods = Registry.EventService:GetModifiers()
	if (mods.EventTokensPerPurchase or 0) > 0 then
		Registry.EconomyService:AddEventTokens(player, mods.EventTokensPerPurchase)
	end
	Registry.NetService:Effect(player, "Purchase", { Price = item.Price })
	return true, nil, { Uid = granted.Uid, Bonus = bonus }
end

-- Admin helper: spawn a specific collectible at the start of a conveyor.
function ConveyorService:AdminSpawn(id: string, mutation: string?, trait: string?, conveyor: string?): string?
	return self:Spawn(conveyor or "Main", { Id = id, Mutation = mutation, Trait = trait }, 0)
end

function ConveyorService:ClearAll()
	for uid in items do
		self:_remove(uid)
	end
end

return ConveyorService
