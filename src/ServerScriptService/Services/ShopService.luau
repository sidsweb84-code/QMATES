--[[
	ShopService
	Card packs (cash, transparent odds), token boost shop, cosmetic shop and
	the event shop. Every price and item comes from ShopConfig / CosmeticConfig.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local ShopConfig = require(Config.ShopConfig)
local CosmeticConfig = require(Config.CosmeticConfig)
local BoostConfig = require(Config.BoostConfig)
local Catalog = require(Shared.Catalog)
local Odds = require(Shared.Util.Odds)
local Format = require(Shared.Util.Format)

local Modules = script.Parent.Parent.Modules
local Registry = require(Modules.Registry)
local ActionBus = require(Modules.ActionBus)

local ShopService = {}

local rng = Random.new()
local boostItems = {}
for _, item in ShopConfig.BoostItems do
	boostItems[item.Id] = item
end
local eventItems = {}
for _, item in ShopConfig.EventShop do
	eventItems[item.Id] = item
end

function ShopService:Init() end
function ShopService:Start() end

---------------------------------------------------------------- packs
function ShopService:OpenPack(player: Player, packId: any, free: boolean?): (boolean, string?, any?)
	local pack = type(packId) == "string" and ShopConfig.Packs[packId] or nil
	local data = Registry.DataService:Get(player)
	if not pack or not data then
		return false, "Unknown pack"
	end
	if (pack.RequiredRebirths or 0) > data.Rebirths then
		return false, string.format("%s requires Rebirth %d", pack.Name, pack.RequiredRebirths)
	end
	if not Registry.CollectibleService:HasSpace(player) then
		return false, "Your base and storage are full!"
	end
	if not free and not Registry.EconomyService:SpendCash(player, pack.Price, "Pack:" .. packId) then
		return false, "Need " .. Format.Cash(pack.Price)
	end
	local luck = Registry.EconomyService:PersonalLuck(player)
	local mods = Registry.EventService:GetModifiers()
	local def = Odds.RollCollectible({ Luck = luck, BaseWeights = pack.Odds }, { MaxRequiredRebirths = data.Rebirths }, rng)
	local mutation = Odds.RollMutation(Odds.MutationChances(luck, mods), rng)
	local trait = Odds.RollTrait(rng)
	local item, err = Registry.CollectibleService:Grant(player, def.Id, { Mutation = mutation, Trait = trait, Source = "Pack" })
	if not item then
		if not free then
			Registry.EconomyService:AddCash(player, pack.Price, "Refund")
		end
		return false, err
	end
	data.Stats.PacksOpened += 1
	Registry.DataService:MarkDirty(player, "Stats")
	ActionBus.Fire(player, "OpenPack", 1, { Pack = packId })
	Registry.NetService:Effect(player, "PackOpened", { Pack = packId })
	return true, nil, { Uid = item.Uid }
end

---------------------------------------------------------------- boosts
function ShopService:BuyBoost(player: Player, itemId: any): (boolean, string?)
	local item = type(itemId) == "string" and boostItems[itemId] or nil
	if not item then
		return false, "Unknown boost"
	end
	if not Registry.EconomyService:SpendTokens(player, item.Price) then
		return false, "Need " .. item.Price .. " tokens"
	end
	Registry.BoostService:Add(player, item.Boost, item.Duration)
	local info = BoostConfig.Personal[item.Boost]
	return true, string.format("%s %s active for %s!", info.Icon, info.Name, Format.Time(item.Duration))
end

---------------------------------------------------------------- cosmetics
function ShopService:BuyCosmetic(player: Player, id: any): (boolean, string?)
	local item = type(id) == "string" and CosmeticConfig.Items[id] or nil
	if not item then
		return false, "Unknown item"
	end
	if Registry.CosmeticService:Owns(player, id) then
		return false, "You already own this"
	end
	if item.Unlock.Type ~= "Tokens" then
		return false, "This item can't be bought with tokens"
	end
	if not Registry.EconomyService:SpendTokens(player, item.Unlock.Price) then
		return false, "Need " .. item.Unlock.Price .. " tokens"
	end
	Registry.CosmeticService:Grant(player, id)
	Registry.CosmeticService:Equip(player, id)
	return true, "Unlocked " .. item.Name .. "!"
end

---------------------------------------------------------------- event shop
function ShopService:BuyEventItem(player: Player, itemId: any): (boolean, string?)
	local item = type(itemId) == "string" and eventItems[itemId] or nil
	if not item then
		return false, "Unknown item"
	end
	local active = Registry.EventService:GetActive()
	if next(active) == nil then
		return false, "The Event Shop is closed — no event is running"
	end
	if item.Event and not active[item.Event] then
		return false, "Only available during its event"
	end
	-- Validate deliverability BEFORE taking currency.
	if item.Type == "Collectible" then
		if not Catalog.Get(item.CollectibleId) then
			return false, "Unavailable"
		end
		if not Registry.CollectibleService:HasSpace(player) then
			return false, "Your base and storage are full!"
		end
	elseif item.Type == "Cosmetic" then
		if Registry.CosmeticService:Owns(player, item.CosmeticId) then
			return false, "You already own this"
		end
	end
	if not Registry.EconomyService:SpendEventTokens(player, item.Price) then
		local currency = Registry.EventService:Currency()
		return false, string.format("Need %d %s", item.Price, currency.Name)
	end
	if item.Type == "Collectible" then
		Registry.CollectibleService:Grant(player, item.CollectibleId, { Source = "Event" })
	elseif item.Type == "Cosmetic" then
		Registry.CosmeticService:Grant(player, item.CosmeticId)
		Registry.CosmeticService:Equip(player, item.CosmeticId)
	elseif item.Type == "Boost" then
		Registry.BoostService:Add(player, item.Boost, item.Duration)
	end
	return true, "Purchased!"
end

return ShopService
