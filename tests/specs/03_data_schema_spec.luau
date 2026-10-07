--!nocheck
local SSS = game:GetService("ServerScriptService")
local DataSchema = require(SSS.Modules.DataSchema)
local RateLimiter = require(SSS.Modules.RateLimiter)
local MockDataStore = require(SSS.Modules.MockDataStore)

local function count(t)
	local n = 0
	for _ in t do n += 1 end
	return n
end

describe("DataSchema", function()
	it("template validates cleanly", function()
		local data, issues = DataSchema.Validate(DataSchema.Template())
		expect(#issues).toBe(0)
		expect(data.Version).toBe(DataSchema.Version)
	end)

	it("prepares new players from nil", function()
		local data, issues, isNew = DataSchema.Prepare(nil)
		expect(isNew).toBe(true)
		expect(#issues).toBe(0)
		expect(data.Cash).toBeGreaterThan(0)
		expect(data.BaseLevel).toBe(1)
	end)

	it("migrates v1 data", function()
		local v1 = DataSchema.Template()
		v1.Version = 1
		v1.EventTokens = nil
		v1.Settings.UIScale = nil
		local data = DataSchema.Prepare(v1)
		expect(data.Version).toBe(DataSchema.Version)
		expect(data.EventTokens).toBe(0)
		expect(data.Settings.UIScale).toBe("Normal")
	end)

	it("repairs corrupted numbers", function()
		local raw = DataSchema.Template()
		raw.Cash = 0 / 0
		raw.Tokens = -50
		raw.TotalEarned = math.huge
		raw.BaseLevel = 999
		raw.Rebirths = "lots"
		local data, issues = DataSchema.Validate(raw)
		expect(data.Cash).toBe(DataSchema.Template().Cash)
		expect(data.Tokens).toBe(0)
		expect(data.TotalEarned).toBe(0)
		expect(data.BaseLevel).toBeAtMost(10)
		expect(data.Rebirths).toBe(0)
		expect(#issues).toBeGreaterThan(0)
	end)

	it("sanitises inventory items", function()
		local raw = DataSchema.Template()
		raw.Inventory = {
			a = { Uid = "a", Id = "emberpup", Mutation = "Bogus", Level = 99, Slot = 1, Trait = "Nope" },
			b = { Uid = "b", Id = "emberpup", Slot = 1 }, -- slot collision
			c = { Uid = "c", Id = "not_a_real_critter", Slot = 2 }, -- unknown id
			d = "garbage",
			e = { Id = "zapkit", Slot = 3 }, -- uid from key
		}
		local data = DataSchema.Validate(raw)
		expect(data.Inventory.a.Mutation).toBe("Normal")
		expect(data.Inventory.a.Level).toBe(10)
		expect(data.Inventory.a.Trait).toBeNil()
		local slots = { data.Inventory.a.Slot, data.Inventory.b.Slot }
		expect(slots[1] ~= slots[2] or slots[1] == 0).toBe(true)
		expect(data.Inventory.c).toBeNil()
		expect(data.Orphaned.c ~= nil).toBe(true)
		expect(data.Inventory.d).toBeNil()
		expect(data.Inventory.e.Uid).toBe("e")
	end)

	it("never keeps duplicate items under different keys", function()
		local raw = DataSchema.Template()
		raw.Inventory = {
			x = { Uid = "same", Id = "emberpup", Slot = 1 },
			y = { Uid = "same", Id = "emberpup", Slot = 2 },
		}
		local data, issues = DataSchema.Validate(raw)
		expect(count(data.Inventory)).toBe(1)
		local found = false
		for _, i in issues do
			if string.find(i, "duplicate", 1, true) then found = true end
		end
		expect(found).toBe(true)
	end)

	it("whitelists settings and cosmetics", function()
		local raw = DataSchema.Template()
		raw.Settings = { Music = "yes", Graphics = "Ultra", Evil = true, SFX = false }
		raw.Cosmetics = { Owned = { Trail_Flame = true, Fake = true }, Equipped = { Trail = "Fake", NameTag = "Trail_Flame" } }
		local data = DataSchema.Validate(raw)
		expect(data.Settings.Music).toBe(true)
		expect(data.Settings.Graphics).toBe("High")
		expect(data.Settings.SFX).toBe(false)
		expect(data.Settings.Evil).toBeNil()
		expect(data.Cosmetics.Owned.Fake).toBeNil()
		expect(data.Cosmetics.Owned.Trail_Flame).toBe(true)
		expect(data.Cosmetics.Equipped.Trail).toBe("")
		expect(data.Cosmetics.Equipped.NameTag).toBe("NameTag_Rookie")
	end)

	it("drops invalid boosts, passes and session locks", function()
		local raw = DataSchema.Template()
		raw.Boosts = { Income = 123, Hacked = 999, Luck = "soon" }
		raw.Gamepasses = { VIP = true, FreeRobux = true }
		raw.SessionLock = { JobId = "x", Time = 1 }
		local data = DataSchema.Validate(raw)
		expect(data.Boosts.Income).toBe(123)
		expect(data.Boosts.Hacked).toBeNil()
		expect(data.Boosts.Luck).toBeNil()
		expect(data.Gamepasses.VIP).toBe(true)
		expect(data.Gamepasses.FreeRobux).toBeNil()
		expect(data.SessionLock).toBeNil()
	end)

	it("only uses string keys in dictionaries (DataStore/remote safe)", function()
		local data = DataSchema.Validate(DataSchema.Template())
		data.CollectionClaimed["25"] = true
		data.Playtime.Claimed["5"] = true
		local function check(t, path)
			local isArray = #t > 0
			for k, v in t do
				if not isArray then
					assert(type(k) == "string", path .. " has non-string key " .. tostring(k))
				end
				if type(v) == "table" then
					check(v, path .. "." .. tostring(k))
				end
			end
		end
		check(data, "Data")
	end)

	it("trims receipt history to the newest entries", function()
		local data = DataSchema.Template()
		for i = 1, 100 do
			data.Receipts["p" .. i] = i
		end
		DataSchema.TrimReceipts(data, 10)
		expect(count(data.Receipts)).toBe(10)
		expect(data.Receipts.p100).toBe(100)
		expect(data.Receipts.p1).toBeNil()
	end)
end)

describe("RateLimiter", function()
	it("allows bursts then blocks until refilled", function()
		local now = 0
		local limiter = RateLimiter.new(function() return now end)
		for _ = 1, 3 do
			expect(limiter:Check("p", "a", 1, 3)).toBe(true)
		end
		expect(limiter:Check("p", "a", 1, 3)).toBe(false)
		now = 1.1
		expect(limiter:Check("p", "a", 1, 3)).toBe(true)
		expect(limiter:Check("p", "a", 1, 3)).toBe(false)
		-- other keys/actions are independent
		expect(limiter:Check("q", "a", 1, 3)).toBe(true)
		expect(limiter:Check("p", "b", 1, 3)).toBe(true)
	end)
end)

describe("MockDataStore", function()
	it("supports UpdateAsync cancel and failure injection", function()
		local store = MockDataStore.new()
		store:SetAsync("k", { v = 1 })
		store:UpdateAsync("k", function() return nil end)
		expect(store:GetAsync("k").v).toBe(1)
		store:UpdateAsync("k", function(old) old.v += 1 return old end)
		expect(store:GetAsync("k").v).toBe(2)
		store.FailNext = 1
		local ok = pcall(store.GetAsync, store, "k")
		expect(ok).toBe(false)
		expect(store:GetAsync("k").v).toBe(2)
		-- returned values are copies
		local copy = store:GetAsync("k")
		copy.v = 99
		expect(store:GetAsync("k").v).toBe(2)
	end)
end)
