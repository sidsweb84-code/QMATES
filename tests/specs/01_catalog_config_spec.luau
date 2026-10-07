--!nocheck
local RS = game:GetService("ReplicatedStorage")
local Shared = RS.Shared
local Catalog = require(Shared.Catalog)
local Config = Shared.Config
local RarityConfig = require(Config.RarityConfig)
local MutationConfig = require(Config.MutationConfig)
local CosmeticConfig = require(Config.CosmeticConfig)
local QuestConfig = require(Config.QuestConfig)
local RewardConfig = require(Config.RewardConfig)
local RebirthConfig = require(Config.RebirthConfig)
local ShopConfig = require(Config.ShopConfig)
local MonetizationConfig = require(Config.MonetizationConfig)
local EventConfig = require(Config.EventConfig)
local UpgradeConfig = require(Config.UpgradeConfig)
local BoostConfig = require(Config.BoostConfig)
local MapConfig = require(Config.MapConfig)
local ConveyorConfig = require(Config.ConveyorConfig)

-- Validate any reward list against configs.
local function checkRewards(rewards, where)
	assert(type(rewards) == "table", where .. ": rewards must be a table")
	for i, r in rewards do
		local label = where .. " reward " .. i
		if r.Type == "Cash" or r.Type == "Tokens" or r.Type == "EventTokens" then
			assert(type(r.Amount) == "number" and r.Amount > 0, label .. " needs Amount")
		elseif r.Type == "CashMinutes" then
			assert(type(r.Minutes) == "number", label .. " needs Minutes")
		elseif r.Type == "Boost" then
			assert(BoostConfig.Personal[r.Boost], label .. " unknown boost " .. tostring(r.Boost))
			assert(type(r.Duration) == "number", label .. " needs Duration")
		elseif r.Type == "ServerBoost" then
			assert(BoostConfig.Server[r.Boost], label .. " unknown server boost " .. tostring(r.Boost))
		elseif r.Type == "Cosmetic" then
			assert(CosmeticConfig.Items[r.Id], label .. " unknown cosmetic " .. tostring(r.Id))
		elseif r.Type == "Collectible" then
			assert(Catalog.Get(r.Id), label .. " unknown collectible " .. tostring(r.Id))
		elseif r.Type == "RandomCollectible" then
			assert(RarityConfig.Rarities[r.Rarity], label .. " unknown rarity " .. tostring(r.Rarity))
		elseif r.Type == "Pack" then
			assert(ShopConfig.Packs[r.Pack], label .. " unknown pack " .. tostring(r.Pack))
		elseif r.Type == "InstantCollect" then
			assert(type(r.Minutes) == "number", label .. " needs Minutes")
		else
			error(label .. " unknown reward type " .. tostring(r.Type))
		end
	end
end

describe("Catalog", function()
	it("has no configuration errors", function()
		if #Catalog.Errors > 0 then
			error(table.concat(Catalog.Errors, "\n"))
		end
	end)

	it("has a large catalogue with every rarity represented", function()
		expect(#Catalog.All).toBeAtLeast(70)
		for _, rarity in RarityConfig.Order do
			expect(#Catalog.ByRarity[rarity]).toBeGreaterThan(0)
		end
	end)

	it("assigns sequential collection numbers", function()
		for i, def in Catalog.All do
			expect(def.Number).toBe(i)
		end
	end)

	it("has income and price that never decrease across rarity tiers", function()
		local previousMax = 0
		for _, rarity in RarityConfig.Order do
			if rarity == "Limited" then continue end
			local minIncome = math.huge
			local maxIncome = 0
			for _, def in Catalog.ByRarity[rarity] do
				minIncome = math.min(minIncome, def.Income)
				maxIncome = math.max(maxIncome, def.Income)
			end
			expect(minIncome).toBeAtLeast(previousMax)
			previousMax = maxIncome
		end
	end)

	it("gives every limited collectible an existing event", function()
		for _, def in Catalog.ByRarity.Limited do
			expect(EventConfig.Events[def.Event] ~= nil).toBe(true)
		end
	end)

	it("payback time grows with rarity (progression stays meaningful)", function()
		local previous = 0
		for _, rarity in RarityConfig.Order do
			if rarity == "Limited" then continue end
			local total = 0
			for _, def in Catalog.ByRarity[rarity] do
				total += def.Price / def.Income
			end
			local avg = total / #Catalog.ByRarity[rarity]
			expect(avg).toBeGreaterThan(previous)
			previous = avg
		end
	end)
end)

describe("Config cross references", function()
	it("quest rewards are valid", function()
		for _, q in QuestConfig.DailyPool do
			checkRewards(q.Rewards, "daily " .. q.Id)
		end
		for _, a in QuestConfig.Achievements do
			for i, tier in a.Tiers do
				checkRewards(tier.Rewards, "achievement " .. a.Id .. " tier " .. i)
			end
		end
	end)

	it("daily, playtime, collection and tutorial rewards are valid", function()
		for day, rewards in RewardConfig.Daily do
			checkRewards(rewards, "daily day " .. day)
		end
		for _, p in RewardConfig.Playtime do
			checkRewards(p.Rewards, "playtime " .. p.Minutes)
		end
		for _, m in RewardConfig.CollectionMilestones do
			checkRewards(m.Rewards, "collection " .. m.Percent)
		end
		for step, rewards in RewardConfig.Tutorial.StepRewards do
			checkRewards(rewards, "tutorial " .. step)
		end
		checkRewards(RewardConfig.Tutorial.Completion, "tutorial completion")
	end)

	it("rebirth milestones and products reference real items", function()
		for key, rewards in RebirthConfig.Milestones do
			expect(type(key)).toBe("string")
			checkRewards(rewards, "rebirth " .. key)
		end
		for key, product in MonetizationConfig.Products do
			checkRewards(product.Rewards, "product " .. key)
		end
	end)

	it("cosmetic unlocks reference real gamepasses", function()
		for id, item in CosmeticConfig.Items do
			expect(CosmeticConfig.TypeInfo[item.Type] ~= nil).toBe(true)
			if item.Unlock.Type == "Gamepass" then
				assert(MonetizationConfig.Gamepasses[item.Unlock.Pass], id .. " references unknown pass")
			end
		end
		for typeName, default in CosmeticConfig.Defaults do
			if default ~= "" then
				expect(CosmeticConfig.Items[default].Type).toBe(typeName)
			end
		end
	end)

	it("event shop items reference real content", function()
		for _, item in ShopConfig.EventShop do
			if item.Event then
				assert(EventConfig.Events[item.Event], item.Id .. " unknown event")
			end
			if item.Type == "Collectible" then
				assert(Catalog.Get(item.CollectibleId), item.Id .. " unknown collectible")
			elseif item.Type == "Cosmetic" then
				assert(CosmeticConfig.Items[item.CosmeticId], item.Id .. " unknown cosmetic")
				expect(CosmeticConfig.Items[item.CosmeticId].Unlock.Type).toBe("Event")
			elseif item.Type == "Boost" then
				assert(BoostConfig.Personal[item.Boost], item.Id .. " unknown boost")
			end
		end
	end)

	it("pack odds only use known rarities", function()
		for id, pack in ShopConfig.Packs do
			for rarity in pack.Odds do
				assert(RarityConfig.Rarities[rarity], id .. " unknown rarity " .. rarity)
			end
		end
	end)

	it("mutation multipliers increase with tier", function()
		local previous = 0
		for _, name in MutationConfig.Order do
			local m = MutationConfig.Mutations[name]
			expect(m.IncomeMultiplier).toBeGreaterThan(previous)
			previous = m.IncomeMultiplier
			expect(m.PriceMultiplier).toBeAtMost(m.IncomeMultiplier)
		end
	end)

	it("base slots fit on the physical pedestals", function()
		local maxSlots = UpgradeConfig.BaseLevels[#UpgradeConfig.BaseLevels].Slots
		local extra = MonetizationConfig.Gamepasses.ExtraSlots.Perks.ExtraSlots
		expect(UpgradeConfig.PhysicalSlots).toBeAtLeast(maxSlots + extra)
		expect(#MapConfig.Plot.SlotColumns * #MapConfig.Plot.SlotRows).toBe(UpgradeConfig.PhysicalSlots)
	end)

	it("has a plot for every player", function()
		local GameConfig = require(Config.GameConfig)
		expect(#MapConfig.PlotOrigins).toBe(GameConfig.MaxPlayers)
	end)

	it("every conveyor has geometry", function()
		for _, name in ConveyorConfig.Order do
			assert(MapConfig.Conveyors[name], "missing geometry for " .. name)
		end
	end)

	it("monetization IDs are unique when configured", function()
		local seen = {}
		for key, p in MonetizationConfig.Products do
			if p.Id ~= 0 then
				assert(not seen[p.Id], "duplicate product id " .. key)
				seen[p.Id] = true
			end
		end
	end)

	it("event modifiers reference real rarities and mutations", function()
		for id, ev in EventConfig.Events do
			local m = ev.Modifiers or {}
			for r in m.RarityWeightMultipliers or {} do
				assert(RarityConfig.Rarities[r], id .. " bad rarity " .. r)
			end
			for mu in m.MutationChanceMultipliers or {} do
				assert(MutationConfig.Mutations[mu], id .. " bad mutation " .. mu)
			end
		end
		for _, entry in EventConfig.Schedule.Rotation.Pool do
			assert(EventConfig.Events[entry], "rotation references unknown event " .. entry)
		end
		for _, s in EventConfig.Schedule.Seasonal do
			assert(EventConfig.Events[s.Event], "seasonal references unknown event " .. s.Event)
		end
	end)
end)
