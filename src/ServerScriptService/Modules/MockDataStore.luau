--[[
	MockDataStore
	In-memory stand-in for a GlobalDataStore. Used automatically when DataStores
	are unavailable (Studio without API access) and by the integration tests,
	which can also inject failures to test retry logic.
]]

local MockDataStore = {}
MockDataStore.__index = MockDataStore

local function deepCopy(v)
	if type(v) ~= "table" then
		return v
	end
	local t = {}
	for k, x in v do
		t[k] = deepCopy(x)
	end
	return t
end

function MockDataStore.new(name: string?)
	return setmetatable({
		Name = name or "Mock",
		Data = {},
		FailNext = 0, -- number of upcoming calls that should error
		Calls = 0,
	}, MockDataStore)
end

function MockDataStore:_maybeFail()
	self.Calls += 1
	if self.FailNext > 0 then
		self.FailNext -= 1
		error("MockDataStore: simulated failure")
	end
end

function MockDataStore:GetAsync(key: string)
	self:_maybeFail()
	return deepCopy(self.Data[key])
end

function MockDataStore:SetAsync(key: string, value: any)
	self:_maybeFail()
	self.Data[key] = deepCopy(value)
end

function MockDataStore:UpdateAsync(key: string, transform: (any) -> any)
	self:_maybeFail()
	local current = deepCopy(self.Data[key])
	local result = transform(current)
	if result ~= nil then
		self.Data[key] = deepCopy(result)
	end
	return deepCopy(self.Data[key])
end

function MockDataStore:RemoveAsync(key: string)
	self:_maybeFail()
	local old = self.Data[key]
	self.Data[key] = nil
	return old
end

function MockDataStore:IncrementAsync(key: string, delta: number?)
	self:_maybeFail()
	self.Data[key] = (tonumber(self.Data[key]) or 0) + (delta or 1)
	return self.Data[key]
end

return MockDataStore
