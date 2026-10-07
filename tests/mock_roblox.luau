--!nocheck
-- Minimal Roblox runtime mock for running pure-logic modules in the standalone
-- Luau CLI. Only what the shared/pure modules touch is implemented.

local realTypeof = typeof

------------------------------------------------------------------ typeof
function typeof(v)
	local mt = getmetatable(v)
	if type(mt) == "table" and rawget(mt, "__type") then
		return rawget(mt, "__type")
	end
	return realTypeof(v)
end

------------------------------------------------------------------ Color3
local Color3Meta = { __type = "Color3" }
Color3Meta.__index = Color3Meta
Color3 = {}
function Color3.new(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3Meta)
end
function Color3.fromRGB(r, g, b)
	return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
end
function Color3.fromHex(hex)
	hex = string.gsub(hex, "#", "")
	local r = tonumber(string.sub(hex, 1, 2), 16)
	local g = tonumber(string.sub(hex, 3, 4), 16)
	local b = tonumber(string.sub(hex, 5, 6), 16)
	assert(r and g and b, "bad hex " .. hex)
	return Color3.fromRGB(r, g, b)
end
function Color3.fromHSV(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	i = i % 6
	if i == 0 then return Color3.new(v, t, p) end
	if i == 1 then return Color3.new(q, v, p) end
	if i == 2 then return Color3.new(p, v, t) end
	if i == 3 then return Color3.new(p, q, v) end
	if i == 4 then return Color3.new(t, p, v) end
	return Color3.new(v, p, q)
end
function Color3Meta:ToHSV()
	local r, g, b = self.R, self.G, self.B
	local max, min = math.max(r, g, b), math.min(r, g, b)
	local h, s, v = 0, 0, max
	local d = max - min
	s = max == 0 and 0 or d / max
	if max ~= min then
		if max == r then
			h = (g - b) / d + (g < b and 6 or 0)
		elseif max == g then
			h = (b - r) / d + 2
		else
			h = (r - g) / d + 4
		end
		h /= 6
	end
	return h, s, v
end
function Color3Meta:Lerp(other, a)
	return Color3.new(self.R + (other.R - self.R) * a, self.G + (other.G - self.G) * a, self.B + (other.B - self.B) * a)
end

------------------------------------------------------------------ Vector3
local Vector3Meta = { __type = "Vector3" }
Vector3 = {}
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3Meta)
end
Vector3.new = v3
Vector3.zero = v3(0, 0, 0)
Vector3.one = v3(1, 1, 1)
Vector3.xAxis = v3(1, 0, 0)
Vector3.yAxis = v3(0, 1, 0)
Vector3.zAxis = v3(0, 0, 1)
Vector3Meta.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
Vector3Meta.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
Vector3Meta.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
Vector3Meta.__mul = function(a, b)
	if type(a) == "number" then return v3(b.X * a, b.Y * a, b.Z * a) end
	if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vector3Meta.__div = function(a, b)
	if type(b) == "number" then return v3(a.X / b, a.Y / b, a.Z / b) end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
Vector3Meta.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
Vector3Meta.__tostring = function(a) return string.format("%g, %g, %g", a.X, a.Y, a.Z) end
Vector3Meta.__index = function(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
	elseif key == "Unit" then
		local m = math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
		return m > 0 and v3(self.X / m, self.Y / m, self.Z / m) or v3(0, 0, 0)
	elseif key == "Dot" then
		return function(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
	elseif key == "Cross" then
		return function(a, b) return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
	elseif key == "Lerp" then
		return function(a, b, t) return a + (b - a) * t end
	end
	return nil
end

------------------------------------------------------------------ CFrame (position + 3x3 rotation)
local CFrameMeta = { __type = "CFrame" }
CFrame = {}
local function cf(px, py, pz, m)
	return setmetatable({ _p = v3(px, py, pz), _m = m or { 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, CFrameMeta)
end
local function matMul(a, b)
	local r = {}
	for i = 0, 2 do
		for j = 0, 2 do
			local s = 0
			for k = 0, 2 do
				s += a[i * 3 + k + 1] * b[k * 3 + j + 1]
			end
			r[i * 3 + j + 1] = s
		end
	end
	return r
end
local function matVec(m, v)
	return v3(m[1] * v.X + m[2] * v.Y + m[3] * v.Z, m[4] * v.X + m[5] * v.Y + m[6] * v.Z, m[7] * v.X + m[8] * v.Y + m[9] * v.Z)
end
function CFrame.new(x, y, z)
	if type(x) == "table" then
		return cf(x.X, x.Y, x.Z)
	end
	return cf(x or 0, y or 0, z or 0)
end
function CFrame.Angles(rx, ry, rz)
	local cx, sx = math.cos(rx), math.sin(rx)
	local cy, sy = math.cos(ry), math.sin(ry)
	local cz, sz = math.cos(rz), math.sin(rz)
	local mx = { 1, 0, 0, 0, cx, -sx, 0, sx, cx }
	local my = { cy, 0, sy, 0, 1, 0, -sy, 0, cy }
	local mz = { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }
	return cf(0, 0, 0, matMul(matMul(mx, my), mz))
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
CFrame.identity = cf(0, 0, 0)
CFrameMeta.__mul = function(a, b)
	if getmetatable(b) == CFrameMeta then
		local p = matVec(a._m, b._p) + a._p
		return cf(p.X, p.Y, p.Z, matMul(a._m, b._m))
	end
	return matVec(a._m, b) + a._p
end
CFrameMeta.__index = function(self, key)
	if key == "Position" or key == "p" then
		return self._p
	elseif key == "X" then return self._p.X
	elseif key == "Y" then return self._p.Y
	elseif key == "Z" then return self._p.Z
	elseif key == "Rotation" then
		return cf(0, 0, 0, self._m)
	elseif key == "LookVector" then
		return v3(-self._m[3], -self._m[6], -self._m[9])
	elseif key == "Inverse" then
		return function(c)
			local m = c._m
			local t = { m[1], m[4], m[7], m[2], m[5], m[8], m[3], m[6], m[9] }
			local p = matVec(t, -c._p)
			return cf(p.X, p.Y, p.Z, t)
		end
	elseif key == "PointToWorldSpace" then
		return function(c, v) return c * v end
	elseif key == "PointToObjectSpace" then
		return function(c, v) return c:Inverse() * v end
	end
	return nil
end

------------------------------------------------------------------ Random (xorshift32)
local RandomMeta = { __type = "Random" }
RandomMeta.__index = RandomMeta
Random = {}
local seedCounter = 1234567
function Random.new(seed)
	seedCounter += 7919
	local s = math.floor(seed or seedCounter) % 4294967296
	if s == 0 then s = 2463534242 end
	return setmetatable({ _s = s }, RandomMeta)
end
function RandomMeta:_next()
	local x = self._s
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	self._s = x
	return x
end
function RandomMeta:NextNumber(a, b)
	local u = self:_next() / 4294967296
	if a and b then
		return a + (b - a) * u
	end
	return u
end
function RandomMeta:NextInteger(a, b)
	return a + math.floor(self:NextNumber() * (b - a + 1))
end

------------------------------------------------------------------ Enum
Enum = setmetatable({}, {
	__index = function(t, enumType)
		local items = setmetatable({}, {
			__index = function(t2, name)
				local item = { Name = name, EnumType = enumType }
				rawset(t2, name, item)
				return item
			end,
		})
		rawset(t, enumType, items)
		return items
	end,
})

------------------------------------------------------------------ misc globals
ColorSequence = { new = function(...) return { ... } end }
NumberSequence = { new = function(...) return { ... } end }
NumberSequenceKeypoint = { new = function(...) return { ... } end }
NumberRange = { new = function(...) return { ... } end }
UDim2 = { new = function(...) return { ... } end, fromScale = function(...) return { ... } end, fromOffset = function(...) return { ... } end }
Vector2 = { new = function(x, y) return { X = x, Y = y } end }

function warn(...)
	print("[warn]", ...)
end

task = {
	spawn = function(f, ...)
		local co = coroutine.create(f)
		local ok, err = coroutine.resume(co, ...)
		if not ok then error(err) end
		return co
	end,
	defer = function(f, ...) return task.spawn(f, ...) end,
	delay = function() end,
	wait = function() return 0 end,
	cancel = function() end,
}

function tick() return os.clock() end

Instance = {
	new = function(className)
		error("Instance.new(" .. tostring(className) .. ") is not available in offline tests")
	end,
}

------------------------------------------------------------------ DataModel tree of ModuleScripts
local nodes = {}
local sources = {}
local cache = {}

local NodeMeta = {}
local function makeNode(path, name, parent)
	local node = setmetatable({ __path = path, __name = name, __parent = parent, __children = {} }, NodeMeta)
	nodes[path] = node
	return node
end

NodeMeta.__index = function(self, key)
	if key == "Name" then return rawget(self, "__name") end
	if key == "Parent" then return rawget(self, "__parent") end
	if key == "FindFirstChild" then
		return function(s, n) return rawget(s, "__children")[n] end
	end
	if key == "WaitForChild" then
		return function(s, n)
			local c = rawget(s, "__children")[n]
			assert(c, "WaitForChild: " .. tostring(n) .. " missing under " .. rawget(s, "__path"))
			return c
		end
	end
	if key == "GetChildren" then
		return function(s)
			local list = {}
			for _, c in rawget(s, "__children") do table.insert(list, c) end
			return list
		end
	end
	if key == "IsA" then return function() return false end end
	if key == "GetAttribute" then return function() return nil end end
	local child = rawget(self, "__children")[key]
	if child then return child end
	error(string.format("%s is not a valid member of %s", tostring(key), rawget(self, "__path")), 2)
end

local root = makeNode("", "game", nil)
local function ensureNode(path)
	if nodes[path] then return nodes[path] end
	local parentPath, name = string.match(path, "^(.*)/([^/]+)$")
	if not parentPath then
		parentPath, name = "", path
	end
	local parent = ensureNode(parentPath)
	local node = makeNode(path, name, parent)
	rawget(parent, "__children")[name] = node
	return node
end

function __registerModule(path, src)
	ensureNode(path)
	sources[path] = src
end

local RunServiceMock = {
	IsStudio = function() return true end,
	IsServer = function() return true end,
	IsClient = function() return false end,
}

local guidCounter = 0
local HttpServiceMock = {
	GenerateGUID = function(_, braces)
		guidCounter += 1
		return string.format("%08x-0000-4000-8000-%012x", guidCounter, guidCounter)
	end,
}

local services = {
	RunService = RunServiceMock,
	HttpService = HttpServiceMock,
}

game = setmetatable({ JobId = "offline-test", PlaceId = 0 }, {
	__index = function(_, key)
		if key == "GetService" then
			return function(_, name)
				return services[name] or ensureNode(name)
			end
		end
		return rawget(root, "__children")[key]
	end,
})
workspace = {}

local loading = {}
function require(node)
	local path = rawget(node, "__path")
	assert(path, "require expects a module node")
	if cache[path] ~= nil then return cache[path] end
	assert(not loading[path], "circular require: " .. path)
	local src = sources[path]
	assert(src, "no module source for " .. path)
	loading[path] = true
	local chunk, err = loadstring("local script, require, game = ...\n" .. src, "=" .. path)
	if not chunk then error("compile error in " .. path .. ": " .. tostring(err)) end
	local result = chunk(node, require, game)
	loading[path] = nil
	cache[path] = result
	return result
end
