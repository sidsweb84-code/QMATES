--!nocheck
local RS = game:GetService("ReplicatedStorage")
local Shared = RS.Shared
local Odds = require(Shared.Util.Odds)
local Economy = require(Shared.Economy)
local Format = require(Shared.Util.Format)
local Catalog = require(Shared.Catalog)
local RarityConfig = require(Shared.Config.RarityConfig)
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local ShopConfig = require(Shared.Config.ShopConfig)

local function sum(t)
	local s = 0
	for _, v in t do s += v end
	return s
end

describe("Odds", function()
	it("rarity probabilities sum to 1", function()
		for _, luck in { 1, 2, 5, 10 } do
			expect(sum(Odds.RarityProbabilities({ Luck = luck }))).toBeNear(1, 1e-9)
		end
	end)

	it("limited never spawns without an event", function()
		local p = Odds.RarityProbabilities({ Luck = 3 })
		expect(p.Limited).toBe(0)
	end)

	it("luck increases rarer odds more than common odds", function()
		local base = Odds.RarityProbabilities({ Luck = 1 })
		local lucky = Odds.RarityProbabilities({ Luck = 2 })
		expect(lucky.Common).toBeLessThan(base.Common)
		expect(lucky.Legendary / base.Legendary).toBeGreaterThan(lucky.Rare / base.Rare)
		expect(lucky.Secret).toBeGreaterThan(base.Secret)
	end)

	it("luck is clamped", function()
		local a = Odds.RarityProbabilities({ Luck = 10 })
		local b = Odds.RarityProbabilities({ Luck = 1e9 })
		expect(a.Secret).toBeNear(b.Secret, 1e-12)
		local c = Odds.RarityProbabilities({ Luck = 0 / 0 })
		expect(sum(c)).toBeNear(1, 1e-9)
	end)

	it("MinRarity removes lower tiers", function()
		local p = Odds.RarityProbabilities({ Luck = 1, MinRarity = "Rare" })
		expect(p.Common).toBe(0)
		expect(p.Uncommon).toBe(0)
		expect(p.Rare).toBeGreaterThan(0)
	end)

	it("pack odds use configured weights exactly at luck 1", function()
		local pack = ShopConfig.Packs.Starter
		local p = Odds.RarityProbabilities({ Luck = 1, BaseWeights = pack.Odds })
		expect(p.Common).toBeNear(0.70, 1e-9)
		expect(p.Uncommon).toBeNear(0.25, 1e-9)
		expect(p.Rare).toBeNear(0.05, 1e-9)
		expect(p.Epic).toBe(0)
	end)

	it("event multipliers and limited weight apply", function()
		local mods = { RarityWeightMultipliers = { Legendary = 3 }, LimitedWeight = 30 }
		local base = Odds.RarityWeights({ Luck = 1 })
		local boosted = Odds.RarityWeights({ Luck = 1, Modifiers = mods })
		expect(boosted.Legendary).toBeNear(base.Legendary * 3, 1e-9)
		expect(boosted.Limited).toBe(30)
	end)

	it("roll distribution matches displayed odds (statistical)", function()
		local rng = Random.new(42)
		local params = { Luck = 1 }
		local counts = {}
		local n = 200000
		for _ = 1, n do
			local r = Odds.RollRarity(params, rng)
			counts[r] = (counts[r] or 0) + 1
		end
		local p = Odds.RarityProbabilities(params)
		for _, name in { "Common", "Uncommon", "Rare", "Epic" } do
			expect((counts[name] or 0) / n).toBeNear(p[name], 0.01)
		end
	end)

	it("mutation chances sum to 1 and respect the cap", function()
		for _, luck in { 1, 4, 10 } do
			local c = Odds.MutationChances(luck, { MutationChanceMultipliers = { Rainbow = 1000, Shiny = 1000 } })
			expect(sum(c)).toBeNear(1, 1e-9)
			expect(c.Normal).toBeAtLeast(0.4 - 1e-9)
		end
	end)

	it("event-only mutations need an event", function()
		expect(Odds.MutationChances(1, {}).Cosmic).toBe(0)
		expect(Odds.MutationChances(1, { EnabledMutations = { Cosmic = 0.01 } }).Cosmic).toBeGreaterThan(0)
	end)

	it("bonus mutation roll chance scales with personal luck", function()
		expect(Odds.BonusMutationRollChance(1)).toBe(0)
		expect(Odds.BonusMutationRollChance(2)).toBeGreaterThan(0)
		expect(Odds.BonusMutationRollChance(1000)).toBeAtMost(1)
	end)

	it("trait chances sum to the configured trait chance", function()
		local TraitConfig = require(Shared.Config.TraitConfig)
		expect(sum(Odds.TraitChances())).toBeNear(TraitConfig.Chance, 1e-9)
	end)

	it("PickCollectible respects events and rebirth gating", function()
		local rng = Random.new(7)
		expect(Odds.PickCollectible("Limited", { ActiveEvents = {} }, rng)).toBeNil()
		local def = Odds.PickCollectible("Limited", { ActiveEvents = { Halloween = true } }, rng)
		expect(def ~= nil).toBe(true)
		expect(def.Event).toBe("Halloween")
		for _ = 1, 200 do
			local d = Odds.PickCollectible("Secret", { MaxRequiredRebirths = 0 }, rng)
			expect(d.RequiredRebirths).toBe(0)
		end
	end)

	it("RollCollectible always returns a valid collectible", function()
		local rng = Random.new(99)
		for _ = 1, 2000 do
			local def = Odds.RollCollectible({ Luck = 10, Modifiers = { LimitedWeight = 50 } }, { ActiveEvents = {} }, rng)
			expect(Catalog.IsValid(def.Id)).toBe(true)
			expect(def.Limited).toBe(false)
		end
	end)
end)

describe("Economy", function()
	local item = { Uid = "a", Id = "emberpup", Mutation = "Normal", Level = 1 }

	it("computes base income", function()
		expect(Economy.ItemIncome(item)).toBe(1)
	end)

	it("applies mutation, level and trait multipliers", function()
		local golden = { Uid = "b", Id = "emberpup", Mutation = "Golden", Level = 3, Trait = "Investor" }
		local expected = 1 * 4 * (1 + 2 * UpgradeConfig.CardLevels.IncomePerLevel) * 1.1
		expect(Economy.ItemIncome(golden)).toBeNear(expected, 1e-9)
	end)

	it("returns 0 income for unknown items", function()
		expect(Economy.ItemIncome({ Uid = "x", Id = "does_not_exist" })).toBe(0)
	end)

	it("sell value is below purchase value", function()
		local value = Economy.ItemValue(item)
		expect(Economy.SellValue(item)).toBeLessThan(value)
		expect(Economy.SellValue(item)).toBeGreaterThan(0)
	end)

	it("level up costs grow and stop at max level", function()
		local a = Economy.LevelUpCost({ Uid = "1", Id = "solarion", Level = 1 })
		local b = Economy.LevelUpCost({ Uid = "1", Id = "solarion", Level = 2 })
		expect(b).toBeGreaterThan(a)
		expect(Economy.LevelUpCost({ Uid = "1", Id = "solarion", Level = UpgradeConfig.CardLevels.MaxLevel })).toBeNil()
	end)

	it("level ups are net-positive investments over time but not instant", function()
		local it2 = { Uid = "1", Id = "solarion", Level = 1 }
		local cost = Economy.LevelUpCost(it2)
		local gain = Economy.ItemIncome({ Uid = "1", Id = "solarion", Level = 2 }) - Economy.ItemIncome(it2)
		local payback = cost / gain
		expect(payback).toBeGreaterThan(30)
		expect(payback).toBeLessThan(3600)
	end)

	it("steal duration scales with rarity and security, and is capped", function()
		local common = Economy.StealDuration({ Uid = "1", Id = "emberpup" }, 0)
		local legendary = Economy.StealDuration({ Uid = "1", Id = "solarion" }, 0)
		local secured = Economy.StealDuration({ Uid = "1", Id = "solarion" }, 5)
		expect(legendary).toBeGreaterThan(common)
		expect(secured).toBeGreaterThan(legendary)
		local maxed = Economy.StealDuration({ Uid = "1", Id = "omnicore", Mutation = "Glitched", Trait = "Guardian" }, 5)
		expect(maxed).toBeAtMost(30)
	end)

	it("guardian trait slows thieves", function()
		local a = Economy.StealDuration({ Uid = "1", Id = "pyroclaw" }, 0)
		local b = Economy.StealDuration({ Uid = "1", Id = "pyroclaw", Trait = "Guardian" }, 0)
		expect(b).toBeNear(a * 1.5, 1e-9)
	end)

	it("rebirth costs grow and multipliers increase linearly", function()
		expect(Economy.RebirthCost(0)).toBe(1000000)
		expect(Economy.RebirthCost(1)).toBeGreaterThan(Economy.RebirthCost(0))
		expect(Economy.RebirthMultiplier(0)).toBe(1)
		expect(Economy.RebirthMultiplier(1)).toBe(1.25)
		expect(Economy.RebirthMultiplier(2)).toBe(1.5)
		expect(Economy.KeptCollectiblesAt(0)).toBe(0)
		expect(Economy.KeptCollectiblesAt(3)).toBe(1)
		expect(Economy.KeptCollectiblesAt(12)).toBe(3)
	end)

	it("base slots follow the upgrade table and include gamepass slots", function()
		expect(Economy.BaseSlots(1, 0)).toBe(6)
		expect(Economy.BaseSlots(2, 0)).toBe(8)
		expect(Economy.BaseSlots(5, 0)).toBe(15)
		expect(Economy.BaseSlots(10, 5)).toBe(35)
		expect(Economy.BaseSlots(99, 99)).toBe(UpgradeConfig.PhysicalSlots)
	end)

	it("track helpers", function()
		expect(Economy.TrackMaxLevel("Security")).toBe(5)
		expect(Economy.TrackNextCost("Security", 0)).toBe(1000)
		expect(Economy.TrackNextCost("Security", 5)).toBeNil()
		expect(Economy.LockDuration(0)).toBe(45)
	end)

	it("total income applies multipliers", function()
		local items = { { Uid = "1", Id = "emberpup" }, { Uid = "2", Id = "zapkit" } }
		local total = Economy.TotalIncome(items, { Rebirths = 2, BoostMultiplier = 2 })
		expect(total).toBeNear((1 + 3) * 1.5 * 2, 1e-9)
	end)

	it("cash minutes uses the minimum", function()
		expect(Economy.CashMinutes(5, 0, 500)).toBe(500)
		expect(Economy.CashMinutes(5, 10, 500)).toBe(3000)
	end)
end)

describe("Format", function()
	it("abbreviates numbers", function()
		expect(Format.Abbreviate(0)).toBe("0")
		expect(Format.Abbreviate(999)).toBe("999")
		expect(Format.Abbreviate(1000)).toBe("1K")
		expect(Format.Abbreviate(1500)).toBe("1.5K")
		expect(Format.Abbreviate(1234567)).toBe("1.23M")
		expect(Format.Abbreviate(999999)).toBe("1M")
		expect(Format.Abbreviate(2.5e9)).toBe("2.5B")
		expect(Format.Abbreviate(-1500)).toBe("-1.5K")
		expect(Format.Abbreviate(0 / 0)).toBe("0")
		expect(Format.Abbreviate(12.5)).toBe("12.5")
	end)

	it("formats cash, time and percentages", function()
		expect(Format.Cash(2500)).toBe("$2.5K")
		expect(Format.PerSec(10)).toBe("$10/s")
		expect(Format.Time(65)).toBe("1m 05s")
		expect(Format.Time(3700)).toBe("1h 01m")
		expect(Format.Clock(125)).toBe("02:05")
		expect(Format.Percent(0.5)).toBe("50%")
		expect(Format.Percent(0.0002)).toBe("0.02%")
		expect(Format.Commas(1234567)).toBe("1,234,567")
		expect(Format.Commas(123)).toBe("123")
		expect(Format.Serial(42)).toBe("#0042")
	end)
end)
