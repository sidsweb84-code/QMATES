--!nocheck
--[[
	Headless Roblox runtime simulator for end-to-end tests.

	Implements enough of the engine (instances, attributes, tags, signals, a
	cooperative task scheduler with a virtual clock, Players/characters,
	RemoteFunction/RemoteEvent loopback, DataStores, Marketplace, tweens,
	JSON, datatypes) to boot the real server AND client scripts in one VM
	and drive them through gameplay scenarios. Physics and rendering are not
	simulated.
]]

Sim = {}
Sim.clock = 0
Sim.epoch = 1791374400 -- 2026-10-07 UTC (Halloween season active)
Sim.errors = {}
Sim.kicks = {}
Sim.closeHandlers = {}
Sim.isStudio = true
Sim.localPlayer = nil
Sim.dataStores = {}
Sim.orderedStores = {}
Sim.ownedPasses = {}
Sim.clientEvents = {} -- [player] = { {name, args...} }

local realOs = os
local realDate = os.date
local realTime = os.time
local realTypeof = typeof

-- The CLI's os table is read-only, so replace it with a virtual-clock version.
os = setmetatable({
	clock = function()
		return Sim.clock
	end,
	time = function(t)
		if t then
			return realTime(t)
		end
		return math.floor(Sim.epoch + Sim.clock)
	end,
	date = function(fmt, t)
		return realDate(fmt, t or math.floor(Sim.epoch + Sim.clock))
	end,
}, { __index = realOs })
function tick()
	return Sim.epoch + Sim.clock
end
function time()
	return Sim.clock
end
function elapsedTime()
	return Sim.clock
end

function typeof(v)
	local mt = getmetatable(v)
	if type(mt) == "table" and rawget(mt, "__type") then
		return rawget(mt, "__type")
	end
	return realTypeof(v)
end

function warn(...)
	local parts = {}
	for i = 1, select("#", ...) do
		table.insert(parts, tostring(select(i, ...)))
	end
	local msg = table.concat(parts, " ")
	if Sim.verbose then
		print("[warn] " .. msg)
	end
	Sim.warnings = Sim.warnings or {}
	table.insert(Sim.warnings, msg)
end

---------------------------------------------------------------- scheduler
local waiting = {}
local deferred = {}

local function report(co, err)
	local trace = debug.traceback(co, tostring(err))
	table.insert(Sim.errors, trace)
	print("[SIM ERROR] " .. trace)
end

local function resume(co, ...)
	if coroutine.status(co) ~= "suspended" then
		return
	end
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		report(co, err)
	end
end
Sim.resume = resume

task = {}
function task.spawn(f, ...)
	if type(f) == "thread" then
		resume(f, ...)
		return f
	end
	local co = coroutine.create(f)
	resume(co, ...)
	return co
end
function task.defer(f, ...)
	local co = if type(f) == "thread" then f else coroutine.create(f)
	table.insert(deferred, { co, table.pack(...) })
	return co
end
function task.delay(t, f, ...)
	local co = if type(f) == "thread" then f else coroutine.create(f)
	table.insert(waiting, { co = co, wake = Sim.clock + (t or 0), args = table.pack(...) })
	return co
end
function task.wait(t)
	local co = coroutine.running()
	table.insert(waiting, { co = co, wake = Sim.clock + math.max(t or 0, 1 / 60), start = Sim.clock })
	return coroutine.yield()
end
function task.cancel(co)
	for i = #waiting, 1, -1 do
		if waiting[i].co == co then
			table.remove(waiting, i)
		end
	end
	for i = #deferred, 1, -1 do
		if deferred[i][1] == co then
			table.remove(deferred, i)
		end
	end
end
function task.synchronize() end
function task.desynchronize() end
wait = task.wait
spawn = task.spawn
delay = task.delay

---------------------------------------------------------------- signals
local SignalMeta = {}
SignalMeta.__index = SignalMeta
local function newSignal()
	return setmetatable({ _conns = {} }, SignalMeta)
end
Sim.newSignal = newSignal
function SignalMeta:Connect(fn)
	local c = { Connected = true, fn = fn }
	function c:Disconnect()
		self.Connected = false
	end
	c.disconnect = c.Disconnect
	table.insert(self._conns, c)
	return c
end
SignalMeta.connect = SignalMeta.Connect
function SignalMeta:Once(fn)
	local c
	c = self:Connect(function(...)
		c:Disconnect()
		fn(...)
	end)
	return c
end
function SignalMeta:Fire(...)
	for _, c in table.clone(self._conns) do
		if c.Connected then
			task.spawn(c.fn, ...)
		end
	end
end
function SignalMeta:Wait()
	local co = coroutine.running()
	self:Once(function(...)
		task.spawn(co, ...)
	end)
	return coroutine.yield()
end

---------------------------------------------------------------- datatypes
local function makeType(name)
	return { __type = name }
end

-- Vector3
local V3 = makeType("Vector3")
Vector3 = {}
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
end
Vector3.new = v3
Vector3.zero = v3(0, 0, 0)
Vector3.one = v3(1, 1, 1)
Vector3.xAxis = v3(1, 0, 0)
Vector3.yAxis = v3(0, 1, 0)
Vector3.zAxis = v3(0, 0, 1)
V3.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
V3.__mul = function(a, b)
	if type(a) == "number" then return v3(b.X * a, b.Y * a, b.Z * a) end
	if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then return v3(a.X / b, a.Y / b, a.Z / b) end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V3.__tostring = function(a) return string.format("%g, %g, %g", a.X, a.Y, a.Z) end
V3.__index = function(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X ^ 2 + self.Y ^ 2 + self.Z ^ 2)
	elseif key == "Unit" then
		local m = math.sqrt(self.X ^ 2 + self.Y ^ 2 + self.Z ^ 2)
		return if m > 0 then v3(self.X / m, self.Y / m, self.Z / m) else v3(0, 0, 0)
	elseif key == "Dot" then
		return function(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
	elseif key == "Cross" then
		return function(a, b) return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
	elseif key == "Lerp" then
		return function(a, b, t) return a + (b - a) * t end
	elseif key == "Abs" then
		return function(a) return v3(math.abs(a.X), math.abs(a.Y), math.abs(a.Z)) end
	end
	return nil
end

-- Vector2
local V2 = makeType("Vector2")
Vector2 = {}
local function v2(x, y)
	return setmetatable({ X = x or 0, Y = y or 0 }, V2)
end
Vector2.new = v2
Vector2.zero = v2(0, 0)
Vector2.one = v2(1, 1)
V2.__add = function(a, b) return v2(a.X + b.X, a.Y + b.Y) end
V2.__sub = function(a, b) return v2(a.X - b.X, a.Y - b.Y) end
V2.__mul = function(a, b)
	if type(a) == "number" then return v2(b.X * a, b.Y * a) end
	if type(b) == "number" then return v2(a.X * b, a.Y * b) end
	return v2(a.X * b.X, a.Y * b.Y)
end
V2.__div = function(a, b)
	if type(b) == "number" then return v2(a.X / b, a.Y / b) end
	return v2(a.X / b.X, a.Y / b.Y)
end
V2.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
V2.__index = function(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X ^ 2 + self.Y ^ 2)
	end
	return nil
end

-- CFrame
local CF = makeType("CFrame")
CFrame = {}
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
local function cf(p, m)
	return setmetatable({ _p = p, _m = m or { 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, CF)
end
function CFrame.new(x, y, z, ...)
	if type(x) == "table" then
		if y ~= nil and typeof(y) == "Vector3" then
			return CFrame.lookAt(x, y)
		end
		return cf(x)
	end
	return cf(v3(x or 0, y or 0, z or 0))
end
function CFrame.Angles(rx, ry, rz)
	local cx, sx = math.cos(rx), math.sin(rx)
	local cy, sy = math.cos(ry), math.sin(ry)
	local cz, sz = math.cos(rz), math.sin(rz)
	local mx = { 1, 0, 0, 0, cx, -sx, 0, sx, cx }
	local my = { cy, 0, sy, 0, 1, 0, -sy, 0, cy }
	local mz = { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }
	return cf(v3(0, 0, 0), matMul(matMul(mx, my), mz))
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
function CFrame.lookAt(at, target, up)
	local forward = (target - at)
	if forward.Magnitude < 1e-9 then
		return cf(at)
	end
	forward = forward.Unit
	local upv = up or v3(0, 1, 0)
	local right = forward:Cross(upv)
	if right.Magnitude < 1e-6 then
		right = forward:Cross(v3(0, 0, 1))
	end
	right = right.Unit
	local realUp = right:Cross(forward)
	-- columns: right, up, -forward
	return cf(at, { right.X, realUp.X, -forward.X, right.Y, realUp.Y, -forward.Y, right.Z, realUp.Z, -forward.Z })
end
CFrame.identity = cf(v3(0, 0, 0))
CF.__mul = function(a, b)
	if getmetatable(b) == CF then
		return cf(matVec(a._m, b._p) + a._p, matMul(a._m, b._m))
	end
	return matVec(a._m, b) + a._p
end
CF.__add = function(a, b)
	return cf(a._p + b, a._m)
end
CF.__sub = function(a, b)
	return cf(a._p - b, a._m)
end
CF.__eq = function(a, b)
	if a._p ~= b._p then
		return false
	end
	for i = 1, 9 do
		if math.abs(a._m[i] - b._m[i]) > 1e-9 then
			return false
		end
	end
	return true
end
local function inverse(c)
	local m = c._m
	local t = { m[1], m[4], m[7], m[2], m[5], m[8], m[3], m[6], m[9] }
	return cf(matVec(t, -c._p), t)
end
CF.__index = function(self, key)
	if key == "Position" or key == "p" then
		return self._p
	elseif key == "X" then
		return self._p.X
	elseif key == "Y" then
		return self._p.Y
	elseif key == "Z" then
		return self._p.Z
	elseif key == "Rotation" then
		return cf(v3(0, 0, 0), self._m)
	elseif key == "LookVector" then
		return v3(-self._m[3], -self._m[6], -self._m[9])
	elseif key == "RightVector" then
		return v3(self._m[1], self._m[4], self._m[7])
	elseif key == "UpVector" then
		return v3(self._m[2], self._m[5], self._m[8])
	elseif key == "Inverse" then
		return inverse
	elseif key == "PointToWorldSpace" then
		return function(c, v) return c * v end
	elseif key == "PointToObjectSpace" then
		return function(c, v) return inverse(c) * v end
	elseif key == "ToWorldSpace" then
		return function(c, o) return c * o end
	elseif key == "ToObjectSpace" then
		return function(c, o) return inverse(c) * o end
	elseif key == "Lerp" then
		return function(a, b, t) return cf(a._p:Lerp(b._p, t), b._m) end
	end
	return nil
end

-- Color3
local C3 = makeType("Color3")
C3.__index = C3
Color3 = {}
function Color3.new(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3)
end
function Color3.fromRGB(r, g, b)
	return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
end
function Color3.fromHex(hex)
	hex = string.gsub(hex, "#", "")
	return Color3.fromRGB(tonumber(string.sub(hex, 1, 2), 16), tonumber(string.sub(hex, 3, 4), 16), tonumber(string.sub(hex, 5, 6), 16))
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
function C3:ToHSV()
	local r, g, b = self.R, self.G, self.B
	local max, min = math.max(r, g, b), math.min(r, g, b)
	local h, s, v = 0, 0, max
	local d = max - min
	s = if max == 0 then 0 else d / max
	if max ~= min then
		if max == r then
			h = (g - b) / d + (if g < b then 6 else 0)
		elseif max == g then
			h = (b - r) / d + 2
		else
			h = (r - g) / d + 4
		end
		h /= 6
	end
	return h, s, v
end
function C3:Lerp(o, a)
	return Color3.new(self.R + (o.R - self.R) * a, self.G + (o.G - self.G) * a, self.B + (o.B - self.B) * a)
end
C3.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end

-- UDim / UDim2
local UD = makeType("UDim")
UD.__index = UD
UDim = {}
function UDim.new(s, o)
	return setmetatable({ Scale = s or 0, Offset = o or 0 }, UD)
end
local UD2 = makeType("UDim2")
UD2.__index = UD2
UDim2 = {}
function UDim2.new(xs, xo, ys, yo)
	if type(xs) == "table" then
		return setmetatable({ X = xs, Y = xo, Width = xs, Height = xo }, UD2)
	end
	local x, y = UDim.new(xs, xo), UDim.new(ys, yo)
	return setmetatable({ X = x, Y = y, Width = x, Height = y }, UD2)
end
function UDim2.fromScale(x, y)
	return UDim2.new(x, 0, y, 0)
end
function UDim2.fromOffset(x, y)
	return UDim2.new(0, x, 0, y)
end
UD2.__add = function(a, b)
	return UDim2.new(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset)
end

-- Misc value types
local function simpleType(name)
	local meta = makeType(name)
	meta.__index = meta
	return meta
end
local CSMeta = simpleType("ColorSequence")
ColorSequence = {
	new = function(a, b)
		if type(a) == "table" and getmetatable(a) ~= C3 then
			return setmetatable({ Keypoints = a }, CSMeta)
		end
		return setmetatable({ Keypoints = { { Time = 0, Value = a }, { Time = 1, Value = b or a } } }, CSMeta)
	end,
}
ColorSequenceKeypoint = { new = function(t, v) return { Time = t, Value = v } end }
local NSMeta = simpleType("NumberSequence")
NumberSequence = {
	new = function(a, b)
		if type(a) == "table" then
			return setmetatable({ Keypoints = a }, NSMeta)
		end
		return setmetatable({ Keypoints = { { Time = 0, Value = a }, { Time = 1, Value = b or a } } }, NSMeta)
	end,
}
NumberSequenceKeypoint = { new = function(t, v, e) return { Time = t, Value = v, Envelope = e or 0 } end }
local NRMeta = simpleType("NumberRange")
NumberRange = { new = function(a, b) return setmetatable({ Min = a, Max = b or a }, NRMeta) end }
local TIMeta = simpleType("TweenInfo")
TweenInfo = {
	new = function(t, style, dir, repeatCount, reverses, delayTime)
		return setmetatable({ Time = t or 1, EasingStyle = style, EasingDirection = dir, RepeatCount = repeatCount or 0, Reverses = reverses, DelayTime = delayTime or 0 }, TIMeta)
	end,
}
Rect = { new = function(...) return { ... } end }
PhysicalProperties = { new = function(...) return { ... } end }
Ray = { new = function(o, d) return { Origin = o, Direction = d } end }
Font = {
	new = function(family, weight, style) return { Family = family, Weight = weight, Style = style } end,
	fromEnum = function(e) return { Family = tostring(e), Weight = nil } end,
}
DateTime = { now = function() return { UnixTimestamp = os.time(), UnixTimestampMillis = os.time() * 1000 } end }

-- Random (xorshift32)
local RandomMeta = makeType("Random")
RandomMeta.__index = RandomMeta
Random = {}
local seedCounter = 1234567
function Random.new(seed)
	seedCounter += 7919
	local s = math.floor(seed or seedCounter) % 4294967296
	if s == 0 then
		s = 2463534242
	end
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

-- Enum
local enumValue = 0
local EnumItemMeta = makeType("EnumItem")
EnumItemMeta.__index = EnumItemMeta
EnumItemMeta.__tostring = function(self) return "Enum." .. self.EnumType .. "." .. self.Name end
Enum = setmetatable({}, {
	__index = function(t, enumType)
		local items = setmetatable({}, {
			__index = function(t2, name)
				if name == "GetEnumItems" then
					return function() return {} end
				end
				enumValue += 1
				local item = setmetatable({ Name = name, EnumType = enumType, Value = enumValue }, EnumItemMeta)
				if enumType == "RenderPriority" then
					item.Value = 200
				end
				rawset(t2, name, item)
				return item
			end,
		})
		rawset(t, enumType, items)
		return items
	end,
})

---------------------------------------------------------------- JSON
local function encodeJSON(v)
	local t = type(v)
	if t == "nil" then
		return "null"
	elseif t == "boolean" then
		return tostring(v)
	elseif t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then
			error("JSON cannot encode non-finite number")
		end
		if v == math.floor(v) and math.abs(v) < 1e15 then
			return string.format("%d", v)
		end
		return string.format("%.17g", v)
	elseif t == "string" then
		return '"' .. string.gsub(v, '[%c"\\]', function(c)
			local map = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
			return map[c] or string.format("\\u%04x", string.byte(c))
		end) .. '"'
	elseif t == "table" then
		if #v > 0 or next(v) == nil then
			local parts = {}
			for _, x in ipairs(v) do
				table.insert(parts, encodeJSON(x))
			end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local parts = {}
		for k, x in v do
			table.insert(parts, encodeJSON(tostring(k)) .. ":" .. encodeJSON(x))
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	error("JSON cannot encode " .. t)
end

local function decodeJSON(s)
	local pos = 1
	local function skip()
		pos = string.find(s, "[^%s]", pos) or (#s + 1)
	end
	local parse
	local function parseString()
		pos += 1
		local out = {}
		while true do
			local c = string.sub(s, pos, pos)
			if c == '"' then
				pos += 1
				return table.concat(out)
			elseif c == "\\" then
				local n = string.sub(s, pos + 1, pos + 1)
				local map = { n = "\n", r = "\r", t = "\t", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
				if n == "u" then
					table.insert(out, utf8.char(tonumber(string.sub(s, pos + 2, pos + 5), 16)))
					pos += 6
				else
					table.insert(out, map[n] or n)
					pos += 2
				end
			else
				table.insert(out, c)
				pos += 1
			end
		end
	end
	function parse()
		skip()
		local c = string.sub(s, pos, pos)
		if c == "{" then
			pos += 1
			local obj = {}
			skip()
			if string.sub(s, pos, pos) == "}" then
				pos += 1
				return obj
			end
			while true do
				skip()
				local key = parseString()
				skip()
				pos += 1 -- :
				obj[key] = parse()
				skip()
				local d = string.sub(s, pos, pos)
				pos += 1
				if d == "}" then
					return obj
				end
			end
		elseif c == "[" then
			pos += 1
			local arr = {}
			skip()
			if string.sub(s, pos, pos) == "]" then
				pos += 1
				return arr
			end
			while true do
				table.insert(arr, parse())
				skip()
				local d = string.sub(s, pos, pos)
				pos += 1
				if d == "]" then
					return arr
				end
			end
		elseif c == '"' then
			return parseString()
		elseif string.sub(s, pos, pos + 3) == "true" then
			pos += 4
			return true
		elseif string.sub(s, pos, pos + 4) == "false" then
			pos += 5
			return false
		elseif string.sub(s, pos, pos + 3) == "null" then
			pos += 4
			return nil
		else
			local num = string.match(s, "^-?[%d%.eE+-]+", pos)
			pos += #num
			return tonumber(num)
		end
	end
	return parse()
end
Sim.encodeJSON = encodeJSON
Sim.decodeJSON = decodeJSON

---------------------------------------------------------------- instances
local CLASS_PARENTS = {
	Part = "BasePart", WedgePart = "BasePart", CornerWedgePart = "BasePart", MeshPart = "BasePart", TrussPart = "BasePart",
	SpawnLocation = "Part", BasePart = "PVInstance", Model = "PVInstance", Workspace = "Model", PVInstance = "Instance",
	Frame = "GuiObject", ScrollingFrame = "GuiObject", ViewportFrame = "GuiObject", TextLabel = "GuiObject", ImageLabel = "GuiObject",
	TextBox = "GuiObject", TextButton = "GuiButton", ImageButton = "GuiButton", GuiButton = "GuiObject", GuiObject = "GuiBase2d",
	ScreenGui = "LayerCollector", BillboardGui = "LayerCollector", SurfaceGui = "LayerCollector", LayerCollector = "GuiBase2d",
	GuiBase2d = "Instance", Script = "BaseScript", LocalScript = "BaseScript", BaseScript = "LuaSourceContainer",
	ModuleScript = "LuaSourceContainer", LuaSourceContainer = "Instance", BloomEffect = "PostEffect", BlurEffect = "PostEffect",
	SunRaysEffect = "PostEffect", ColorCorrectionEffect = "PostEffect", PostEffect = "Instance", PointLight = "Light", Light = "Instance",
	UIListLayout = "UIGridStyleLayout", UIGridLayout = "UIGridStyleLayout", UIGridStyleLayout = "UILayout", UILayout = "UIComponent",
	UICorner = "UIComponent", UIStroke = "UIComponent", UIGradient = "UIComponent", UIPadding = "UIComponent", UIScale = "UIComponent",
	UITextSizeConstraint = "UIConstraint", UISizeConstraint = "UIConstraint", UIAspectRatioConstraint = "UIConstraint",
	UIConstraint = "UIComponent", UIComponent = "Instance", StringValue = "ValueBase", IntValue = "ValueBase", NumberValue = "ValueBase",
	ValueBase = "Instance", WeldConstraint = "Instance", RemoteEvent = "Instance", RemoteFunction = "Instance",
}

local DEFAULTS = {
	BasePart = { Anchored = false, CanCollide = true, CanTouch = true, CanQuery = true, Transparency = 0, Reflectance = 0, Massless = false, LocalTransparencyModifier = 0, CastShadow = true },
	GuiObject = { Visible = true, BackgroundTransparency = 0, Rotation = 0, LayoutOrder = 0, ZIndex = 1, Selectable = false, Active = false, TextTransparency = 0, TextSize = 14, AnchorPoint = nil },
	LayerCollector = { Enabled = true, ResetOnSpawn = true, DisplayOrder = 0 },
	UIScale = { Scale = 1 },
	UIGradient = { Rotation = 0 },
	UIStroke = { Thickness = 1, Transparency = 0 },
	Humanoid = { Health = 100, MaxHealth = 100, WalkSpeed = 16, JumpPower = 50, UseJumpPower = true, Sit = false },
	Sound = { Volume = 0.5, PlaybackSpeed = 1, IsPlaying = false, SoundId = "", Looped = false },
	Camera = { FieldOfView = 70 },
	ProximityPrompt = { Enabled = true, HoldDuration = 0, MaxActivationDistance = 10 },
	ParticleEmitter = { Enabled = true },
	BlurEffect = { Size = 0, Enabled = true },
	ColorCorrectionEffect = { Enabled = true, Saturation = 0, Contrast = 0, Brightness = 0 },
	Player = { AccountAge = 30 },
}

local EVENT_NAMES = {
	Changed = true, ChildAdded = true, ChildRemoved = true, Destroying = true, AncestryChanged = true, DescendantAdded = true,
	Touched = true, TouchEnded = true, Activated = true, MouseButton1Click = true, MouseButton1Down = true, MouseButton1Up = true,
	MouseEnter = true, MouseLeave = true, SelectionGained = true, SelectionLost = true, InputBegan = true, InputEnded = true,
	InputChanged = true, FocusLost = true, Focused = true, Triggered = true, TriggerEnded = true, PromptShown = true, PromptHidden = true,
	PromptButtonHoldBegan = true, PromptButtonHoldEnded = true, Died = true, HealthChanged = true, CharacterAdded = true,
	CharacterRemoving = true, Chatted = true, Ended = true, Played = true, Completed = true, OnServerEvent = true, OnClientEvent = true,
	Heartbeat = true, RenderStepped = true, Stepped = true, PlayerAdded = true, PlayerRemoving = true, Loaded = true,
	MouseButton2Click = true, StateChanged = true, Running = true,
}

local InstanceMeta = { __type = "Instance" }
local Methods = {}
local allInstances = setmetatable({}, { __mode = "k" })
local tagIndex = {} -- [tag] = { [inst] = true }
local tagAdded = {}
local tagRemoved = {}
local nextDebugId = 0

local function isA(className, target)
	local c = className
	while c do
		if c == target then
			return true
		end
		c = CLASS_PARENTS[c]
	end
	return target == "Instance"
end

local function defaultFor(className, key)
	local c = className
	while c do
		local d = DEFAULTS[c]
		if d and d[key] ~= nil then
			return d[key]
		end
		c = CLASS_PARENTS[c]
	end
	return nil
end

local function getSignal(self, name)
	local events = rawget(self, "_events")
	if not events[name] then
		events[name] = newSignal()
	end
	return events[name]
end

local function fireProp(self, key)
	local sigs = rawget(self, "_propSignals")
	if sigs[key] then
		sigs[key]:Fire()
	end
	local events = rawget(self, "_events")
	if events.Changed then
		events.Changed:Fire(key)
	end
end

local function partCFrame(self)
	local props = rawget(self, "_props")
	return props.CFrame or CFrame.new()
end

InstanceMeta.__index = function(self, key)
	local props = rawget(self, "_props")
	-- Service-specific functions (e.g. CollectionService:AddTag) win over generic methods.
	local own = props[key]
	if type(own) == "function" then
		return own
	end
	local method = Methods[key]
	if method then
		return method
	end
	local className = props.ClassName
	if key == "Parent" then
		return rawget(self, "_parent")
	elseif key == "Position" and isA(className, "BasePart") then
		return partCFrame(self).Position
	elseif key == "Orientation" and isA(className, "BasePart") then
		return Vector3.zero
	elseif key == "AbsoluteSize" then
		if className == "ScreenGui" then
			return Vector2.new(1280, 720)
		end
		return props.AbsoluteSize or Vector2.new(100, 40)
	elseif key == "AbsolutePosition" then
		return props.AbsolutePosition or Vector2.new(0, 0)
	end
	local v = props[key]
	if v ~= nil then
		return v
	end
	if EVENT_NAMES[key] then
		return getSignal(self, key)
	end
	local child = rawget(self, "_childByName")[key]
	if child then
		return child
	end
	return defaultFor(className, key)
end

local function setParent(self, newParent)
	local old = rawget(self, "_parent")
	if old == newParent then
		return
	end
	if rawget(self, "_destroyed") and newParent ~= nil then
		error("The Parent property of " .. tostring(self.Name) .. " is locked")
	end
	if old then
		local list = rawget(old, "_children")
		local idx = table.find(list, self)
		if idx then
			table.remove(list, idx)
		end
		local byName = rawget(old, "_childByName")
		if byName[self.Name] == self then
			byName[self.Name] = nil
			for _, c in list do
				if c.Name == self.Name then
					byName[self.Name] = c
					break
				end
			end
		end
		local events = rawget(old, "_events")
		if events.ChildRemoved then
			events.ChildRemoved:Fire(self)
		end
	end
	rawset(self, "_parent", newParent)
	if newParent then
		table.insert(rawget(newParent, "_children"), self)
		local byName = rawget(newParent, "_childByName")
		if byName[self.Name] == nil then
			byName[self.Name] = self
		end
		local events = rawget(newParent, "_events")
		if events.ChildAdded then
			events.ChildAdded:Fire(self)
		end
	end
	local events = rawget(self, "_events")
	if events.AncestryChanged then
		events.AncestryChanged:Fire(self, newParent)
	end
end

InstanceMeta.__newindex = function(self, key, value)
	if key == "Parent" then
		setParent(self, value)
		fireProp(self, "Parent")
		return
	end
	local props = rawget(self, "_props")
	if key == "Name" then
		local parent = rawget(self, "_parent")
		local oldName = props.Name
		props.Name = value
		if parent then
			local byName = rawget(parent, "_childByName")
			if byName[oldName] == self then
				byName[oldName] = nil
			end
			if byName[value] == nil then
				byName[value] = self
			end
		end
		fireProp(self, key)
		return
	end
	if key == "Position" and isA(props.ClassName, "BasePart") then
		local current = partCFrame(self)
		props.CFrame = CFrame.new(value) * current.Rotation
		fireProp(self, "CFrame")
		return
	end
	if key == "ClassName" then
		error("ClassName is read-only")
	end
	props[key] = value
	fireProp(self, key)
end

InstanceMeta.__tostring = function(self)
	return rawget(self, "_props").Name
end

local function newInstance(className, name)
	nextDebugId += 1
	local inst = setmetatable({
		_props = { ClassName = className, Name = name or className },
		_parent = nil,
		_children = {},
		_childByName = {},
		_events = {},
		_propSignals = {},
		_attributes = {},
		_attrSignals = {},
		_tags = {},
		_id = nextDebugId,
	}, InstanceMeta)
	allInstances[inst] = true
	if isA(className, "BasePart") then
		rawget(inst, "_props").CFrame = CFrame.new()
		rawget(inst, "_props").Size = Vector3.new(4, 1, 2)
		rawget(inst, "_props").Color = Color3.fromRGB(163, 162, 165)
	elseif isA(className, "GuiObject") then
		rawget(inst, "_props").Size = UDim2.new(0, 100, 0, 100)
		rawget(inst, "_props").Position = UDim2.new()
	end
	return inst
end
Sim.newInstance = newInstance

Instance = {}
function Instance.new(className, parent)
	local inst = newInstance(className)
	if className == "Humanoid" then
		rawget(inst, "_props").Health = 100
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Methods:IsA(className)
	return isA(rawget(self, "_props").ClassName, className)
end
function Methods:FindFirstChild(name, recursive)
	local direct = rawget(self, "_childByName")[name]
	if direct or not recursive then
		return direct
	end
	for _, c in rawget(self, "_children") do
		local found = c:FindFirstChild(name, true)
		if found then
			return found
		end
	end
	return nil
end
function Methods:FindFirstChildOfClass(className)
	for _, c in rawget(self, "_children") do
		if c.ClassName == className then
			return c
		end
	end
	return nil
end
function Methods:FindFirstChildWhichIsA(className, recursive)
	for _, c in rawget(self, "_children") do
		if c:IsA(className) then
			return c
		end
		if recursive then
			local found = c:FindFirstChildWhichIsA(className, true)
			if found then
				return found
			end
		end
	end
	return nil
end
function Methods:FindFirstAncestorOfClass(className)
	local p = rawget(self, "_parent")
	while p do
		if p.ClassName == className then
			return p
		end
		p = rawget(p, "_parent")
	end
	return nil
end
function Methods:WaitForChild(name, timeout)
	local found = self:FindFirstChild(name)
	if found then
		return found
	end
	local deadline = Sim.clock + (timeout or 15)
	while Sim.clock < deadline do
		task.wait(0.05)
		found = self:FindFirstChild(name)
		if found then
			return found
		end
	end
	if timeout then
		return nil
	end
	error("Infinite yield on WaitForChild(" .. tostring(name) .. ") under " .. self:GetFullName())
end
function Methods:GetChildren()
	return table.clone(rawget(self, "_children"))
end
function Methods:GetDescendants()
	local out = {}
	local function walk(inst)
		for _, c in rawget(inst, "_children") do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function Methods:IsDescendantOf(ancestor)
	local p = rawget(self, "_parent")
	while p do
		if p == ancestor then
			return true
		end
		p = rawget(p, "_parent")
	end
	return false
end
function Methods:GetFullName()
	local parts = {}
	local p = self
	while p and p ~= Sim.game do
		table.insert(parts, 1, p.Name)
		p = rawget(p, "_parent")
	end
	return table.concat(parts, ".")
end
function Methods:Destroy()
	if rawget(self, "_destroyed") then
		return
	end
	local events = rawget(self, "_events")
	if events.Destroying then
		events.Destroying:Fire()
	end
	for _, c in table.clone(rawget(self, "_children")) do
		c:Destroy()
	end
	for tag in rawget(self, "_tags") do
		self:RemoveTag(tag)
	end
	setParent(self, nil)
	rawset(self, "_destroyed", true)
end
function Methods:ClearAllChildren()
	for _, c in table.clone(rawget(self, "_children")) do
		c:Destroy()
	end
end
function Methods:Clone()
	local copy = newInstance(self.ClassName, self.Name)
	for k, v in rawget(self, "_props") do
		rawget(copy, "_props")[k] = v
	end
	for k, v in rawget(self, "_attributes") do
		rawget(copy, "_attributes")[k] = v
	end
	for _, c in rawget(self, "_children") do
		c:Clone().Parent = copy
	end
	for tag in rawget(self, "_tags") do
		copy:AddTag(tag)
	end
	return copy
end
function Methods:SetAttribute(name, value)
	local attrs = rawget(self, "_attributes")
	if attrs[name] == value then
		return
	end
	attrs[name] = value
	local sig = rawget(self, "_attrSignals")[name]
	if sig then
		sig:Fire()
	end
	local events = rawget(self, "_events")
	if events.AttributeChanged then
		events.AttributeChanged:Fire(name)
	end
end
function Methods:GetAttribute(name)
	return rawget(self, "_attributes")[name]
end
function Methods:GetAttributes()
	return table.clone(rawget(self, "_attributes"))
end
function Methods:GetAttributeChangedSignal(name)
	local sigs = rawget(self, "_attrSignals")
	if not sigs[name] then
		sigs[name] = newSignal()
	end
	return sigs[name]
end
function Methods:GetPropertyChangedSignal(name)
	local sigs = rawget(self, "_propSignals")
	if not sigs[name] then
		sigs[name] = newSignal()
	end
	return sigs[name]
end
function Methods:AddTag(tag)
	local tags = rawget(self, "_tags")
	if tags[tag] then
		return
	end
	tags[tag] = true
	tagIndex[tag] = tagIndex[tag] or {}
	tagIndex[tag][self] = true
	if tagAdded[tag] then
		tagAdded[tag]:Fire(self)
	end
end
function Methods:RemoveTag(tag)
	local tags = rawget(self, "_tags")
	if not tags[tag] then
		return
	end
	tags[tag] = nil
	if tagIndex[tag] then
		tagIndex[tag][self] = nil
	end
	if tagRemoved[tag] then
		tagRemoved[tag]:Fire(self)
	end
end
function Methods:HasTag(tag)
	return rawget(self, "_tags")[tag] == true
end
function Methods:GetTags()
	local out = {}
	for t in rawget(self, "_tags") do
		table.insert(out, t)
	end
	return out
end

-- PVInstance / Model
local function descendantParts(inst)
	local list = {}
	if inst:IsA("BasePart") then
		table.insert(list, inst)
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end
function Methods:GetPivot()
	if self:IsA("BasePart") then
		return partCFrame(self)
	end
	local primary = rawget(self, "_props").PrimaryPart
	if primary then
		return partCFrame(primary)
	end
	local parts = descendantParts(self)
	if #parts > 0 then
		return CFrame.new(partCFrame(parts[1]).Position)
	end
	return rawget(self, "_props").WorldPivot or CFrame.new()
end
function Methods:PivotTo(target)
	local current = self:GetPivot()
	local delta = target * current:Inverse()
	for _, p in descendantParts(self) do
		local props = rawget(p, "_props")
		props.CFrame = delta * (props.CFrame or CFrame.new())
		fireProp(p, "CFrame")
	end
	if not self:IsA("BasePart") and not rawget(self, "_props").PrimaryPart then
		rawget(self, "_props").WorldPivot = target
	end
end
function Methods:SetPrimaryPartCFrame(target)
	self:PivotTo(target)
end
function Methods:GetBoundingBox()
	local parts = descendantParts(self)
	if #parts == 0 then
		return CFrame.new(), Vector3.zero
	end
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in parts do
		local pos = partCFrame(p).Position
		local half = (rawget(p, "_props").Size or Vector3.one) / 2
		minV = Vector3.new(math.min(minV.X, pos.X - half.X), math.min(minV.Y, pos.Y - half.Y), math.min(minV.Z, pos.Z - half.Z))
		maxV = Vector3.new(math.max(maxV.X, pos.X + half.X), math.max(maxV.Y, pos.Y + half.Y), math.max(maxV.Z, pos.Z + half.Z))
	end
	return CFrame.new((minV + maxV) / 2), maxV - minV
end
function Methods:GetExtentsSize()
	local _, size = self:GetBoundingBox()
	return size
end
function Methods:ScaleTo() end
function Methods:SetNetworkOwner() end
function Methods:GetMass()
	return 1
end

-- Sounds / prompts / tweens / misc engine methods
function Methods:Play()
	rawget(self, "_props").IsPlaying = true
	task.delay(0.5, function()
		rawget(self, "_props").IsPlaying = false
		local events = rawget(self, "_events")
		if events.Ended then
			events.Ended:Fire()
		end
	end)
end
function Methods:Stop()
	rawget(self, "_props").IsPlaying = false
end
function Methods:InputHoldBegin()
	local events = rawget(self, "_events")
	if events.Triggered then
		events.Triggered:Fire(Sim.localPlayer)
	end
end
function Methods:InputHoldEnd() end
function Methods:Kick(message)
	table.insert(Sim.kicks, { Player = self, Message = message })
	Sim.RemovePlayer(self)
end
function Methods:LoadCharacterAsync()
	Sim.SpawnCharacter(self)
end
function Methods:LoadCharacter()
	Sim.SpawnCharacter(self)
end
function Methods:GetRankInGroup()
	return 0
end
function Methods:GetRankInGroupAsync()
	return 0
end
function Methods:IsInGroup()
	return false
end
function Methods:FireClient(player, ...)
	Sim.deliverClient(self, player, table.pack(...))
end
function Methods:FireAllClients(...)
	local args = table.pack(...)
	for _, p in Sim.Players:GetPlayers() do
		Sim.deliverClient(self, p, args)
	end
end
function Methods:FireServer(...)
	local events = rawget(self, "_events")
	if events.OnServerEvent then
		events.OnServerEvent:Fire(Sim.localPlayer, ...)
	end
end
function Methods:InvokeServer(...)
	local handler = rawget(self, "_props").OnServerInvoke
	if not handler then
		error("OnServerInvoke not set")
	end
	return handler(Sim.localPlayer, ...)
end
function Methods:CaptureFocus() end
function Methods:ReleaseFocus() end
function Methods:TweenPosition() end
function Methods:TweenSize() end
function Methods:BreakJoints() end
function Methods:ChangeState() end
function Methods:MoveTo(pos)
	local root = rawget(self, "_parent") and rawget(self, "_parent"):FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(pos)
	end
end

function Sim.deliverClient(remote, player, args)
	Sim.clientEvents[player] = Sim.clientEvents[player] or {}
	local log = Sim.clientEvents[player]
	table.insert(log, { Remote = remote.Name, Args = args })
	if #log > 400 then
		table.remove(log, 1)
	end
	if player == Sim.localPlayer then
		local events = rawget(remote, "_events")
		if events.OnClientEvent then
			events.OnClientEvent:Fire(table.unpack(args, 1, args.n))
		end
	end
end

---------------------------------------------------------------- services
local game = newInstance("DataModel", "Game")
Sim.game = game
rawget(game, "_props").JobId = "sim-job-1"
rawget(game, "_props").PlaceId = 12345
rawget(game, "_props").CreatorId = 0
rawget(game, "_props").CreatorType = Enum.CreatorType.User

local services = {}
local function service(name, className)
	local s = newInstance(className or name, name)
	s.Parent = game
	services[name] = s
	return s
end

function Methods:GetService(name)
	if self ~= game then
		error("GetService on non-DataModel")
	end
	local s = services[name]
	if not s then
		s = service(name)
	end
	return s
end
Methods.FindService = Methods.GetService
function Methods:IsLoaded()
	return true
end
function Methods:BindToClose(fn)
	table.insert(Sim.closeHandlers, fn)
end
function Methods:GetServerTimeNow()
	return Sim.epoch + Sim.clock
end

-- Workspace
local Workspace = service("Workspace", "Workspace")
workspace = Workspace
local camera = newInstance("Camera", "Camera")
rawget(camera, "_props").CFrame = CFrame.new(0, 20, 20)
rawget(camera, "_props").ViewportSize = Vector2.new(1280, 720)
camera.Parent = Workspace
rawget(Workspace, "_props").CurrentCamera = camera

-- RunService
local RunService = service("RunService")
RunService.IsStudio = function()
	return Sim.isStudio
end
-- Server and client scripts share one VM in the simulator.
RunService.IsServer = function()
	return true
end
RunService.IsClient = function()
	return true
end
RunService.IsRunning = function()
	return true
end
local renderSteps = {}
RunService.BindToRenderStep = function(_, name, priority, fn)
	renderSteps[name] = fn
end
RunService.UnbindFromRenderStep = function(_, name)
	renderSteps[name] = nil
end

-- Players
local Players = service("Players")
Sim.Players = Players
rawget(Players, "_props").RespawnTime = 3
rawget(Players, "_props").CharacterAutoLoads = true
Players.GetPlayers = function(self)
	local out = {}
	for _, c in rawget(self, "_children") do
		if c.ClassName == "Player" then
			table.insert(out, c)
		end
	end
	return out
end
Players.GetPlayerByUserId = function(self, id)
	for _, p in self:GetPlayers() do
		if p.UserId == id then
			return p
		end
	end
	return nil
end
Players.GetPlayerFromCharacter = function(self, character)
	for _, p in self:GetPlayers() do
		if p.Character == character then
			return p
		end
	end
	return nil
end
Players.GetUserThumbnailAsync = function(_, id)
	return "rbxthumb://type=AvatarHeadShot&id=" .. tostring(id), true
end
Players.GetNameFromUserIdAsync = function(_, id)
	return "User" .. tostring(id)
end

-- Collection
local CollectionService = service("CollectionService")
CollectionService.AddTag = function(_, inst, tag)
	inst:AddTag(tag)
end
CollectionService.RemoveTag = function(_, inst, tag)
	inst:RemoveTag(tag)
end
CollectionService.HasTag = function(_, inst, tag)
	return inst:HasTag(tag)
end
CollectionService.GetTagged = function(_, tag)
	local out = {}
	for inst in tagIndex[tag] or {} do
		table.insert(out, inst)
	end
	return out
end
CollectionService.GetInstanceAddedSignal = function(_, tag)
	tagAdded[tag] = tagAdded[tag] or newSignal()
	return tagAdded[tag]
end
CollectionService.GetInstanceRemovedSignal = function(_, tag)
	tagRemoved[tag] = tagRemoved[tag] or newSignal()
	return tagRemoved[tag]
end

-- Tweens
local TweenService = service("TweenService")
TweenService.Create = function(_, inst, info, goal)
	local tween = { Completed = newSignal(), PlaybackState = Enum.PlaybackState.Begin }
	function tween:Play()
		for k, v in goal do
			inst[k] = v
		end
		task.delay((info and info.Time) or 0, function()
			tween.Completed:Fire(Enum.PlaybackState.Completed)
		end)
	end
	function tween:Cancel() end
	function tween:Pause() end
	function tween:Destroy() end
	return tween
end
TweenService.GetValue = function(_, alpha)
	return alpha
end

-- HTTP
local HttpService = service("HttpService")
local guidCounter = 0
HttpService.GenerateGUID = function(_, braces)
	guidCounter += 1
	local s = string.format("%08X-%04X-4%03X-8%03X-%012X", guidCounter, guidCounter % 65536, guidCounter % 4096, (guidCounter * 7) % 4096, guidCounter * 2654435761 % 281474976710656)
	return if braces == false then s else "{" .. s .. "}"
end
HttpService.JSONEncode = function(_, v)
	return encodeJSON(v)
end
HttpService.JSONDecode = function(_, s)
	return decodeJSON(s)
end

-- DataStores
local function storeObject(name)
	local store = { Name = name, Data = {}, Calls = 0, FailNext = 0 }
	local function copy(v)
		if type(v) ~= "table" then
			return v
		end
		-- Round-trip through JSON to emulate DataStore serialisation rules.
		return decodeJSON(encodeJSON(v))
	end
	local function maybeFail()
		store.Calls += 1
		task.wait(0.05)
		if store.FailNext > 0 then
			store.FailNext -= 1
			error("DataStore request failed (simulated)")
		end
	end
	function store:GetAsync(key)
		maybeFail()
		return copy(self.Data[key])
	end
	function store:SetAsync(key, value)
		maybeFail()
		self.Data[key] = copy(value)
	end
	function store:UpdateAsync(key, fn)
		maybeFail()
		local result = fn(copy(self.Data[key]))
		if result ~= nil then
			self.Data[key] = copy(result)
		end
		return copy(self.Data[key])
	end
	function store:IncrementAsync(key, delta)
		maybeFail()
		self.Data[key] = (tonumber(self.Data[key]) or 0) + (delta or 1)
		return self.Data[key]
	end
	function store:RemoveAsync(key)
		maybeFail()
		local old = self.Data[key]
		self.Data[key] = nil
		return old
	end
	function store:GetSortedAsync(ascending, pageSize)
		maybeFail()
		local list = {}
		for k, v in self.Data do
			table.insert(list, { key = k, value = v })
		end
		table.sort(list, function(a, b)
			if ascending then
				return a.value < b.value
			end
			return a.value > b.value
		end)
		local page = {}
		for i = 1, math.min(pageSize or 10, #list) do
			page[i] = list[i]
		end
		return { GetCurrentPage = function() return page end, IsFinished = true }
	end
	return store
end
local DataStoreService = service("DataStoreService")
DataStoreService.GetDataStore = function(_, name)
	Sim.dataStores[name] = Sim.dataStores[name] or storeObject(name)
	return Sim.dataStores[name]
end
DataStoreService.GetOrderedDataStore = function(_, name)
	Sim.orderedStores[name] = Sim.orderedStores[name] or storeObject(name)
	return Sim.orderedStores[name]
end
DataStoreService.GetRequestBudgetForRequestType = function()
	return 100
end

-- Marketplace / messaging / text / groups
local MarketplaceService = service("MarketplaceService")
rawget(MarketplaceService, "_props").PromptGamePassPurchaseFinished = newSignal()
rawget(MarketplaceService, "_props").PromptProductPurchaseFinished = newSignal()
MarketplaceService.UserOwnsGamePassAsync = function(_, userId, passId)
	return Sim.ownedPasses[tostring(userId) .. ":" .. tostring(passId)] == true
end
MarketplaceService.PromptGamePassPurchase = function() end
MarketplaceService.PromptProductPurchase = function() end
MarketplaceService.GetProductInfo = function(_, id)
	return { PriceInRobux = 99, Name = "Product " .. tostring(id) }
end
local MessagingService = service("MessagingService")
MessagingService.SubscribeAsync = function()
	return { Disconnect = function() end }
end
MessagingService.PublishAsync = function() end
local TextService = service("TextService")
TextService.FilterStringAsync = function(_, text)
	return {
		GetNonChatStringForBroadcastAsync = function()
			return text
		end,
		GetNonChatStringForUserAsync = function()
			return text
		end,
	}
end
local GroupService = service("GroupService")
GroupService.GetGroupsAsync = function()
	return {}
end

-- Client-side services
local UserInputService = service("UserInputService")
rawget(UserInputService, "_props").KeyboardEnabled = true
rawget(UserInputService, "_props").TouchEnabled = false
rawget(UserInputService, "_props").GamepadEnabled = false
rawget(UserInputService, "_props").LastInputTypeChanged = newSignal()
UserInputService.GetStringForKeyCode = function(_, key)
	return key.Name
end
UserInputService.GetLastInputType = function()
	return Enum.UserInputType.Keyboard
end
local ContextActionService = service("ContextActionService")
Sim.boundActions = {}
ContextActionService.BindAction = function(_, name, fn)
	Sim.boundActions[name] = fn
end
ContextActionService.UnbindAction = function(_, name)
	Sim.boundActions[name] = nil
end
local GuiService = service("GuiService")
GuiService.IsTenFootInterface = function()
	return false
end
GuiService.GetGuiInset = function()
	return Vector2.new(0, 36), Vector2.new(0, 0)
end
service("ProximityPromptService")
local StarterGui = service("StarterGui")
StarterGui.SetCoreGuiEnabled = function() end
StarterGui.SetCore = function() end
local ReplicatedFirst = service("ReplicatedFirst")
ReplicatedFirst.RemoveDefaultLoadingScreen = function() end
service("ReplicatedStorage")
service("ServerScriptService")
service("ServerStorage")
service("Lighting")
service("SoundService")
service("StarterPlayer")
service("TextChatService")
service("Teams")
service("Debris").AddItem = function(_, inst, t)
	task.delay(t or 10, function()
		inst:Destroy()
	end)
end

---------------------------------------------------------------- players & characters
function Sim.AddPlayer(userId, name, isLocal)
	local player = newInstance("Player", name)
	local props = rawget(player, "_props")
	props.UserId = userId
	props.DisplayName = name
	props.AccountAge = 30
	props.Character = nil
	local playerGui = newInstance("PlayerGui", "PlayerGui")
	playerGui.Parent = player
	if isLocal then
		Sim.localPlayer = player
		rawget(Players, "_props").LocalPlayer = player
	end
	player.Parent = Players
	Players.PlayerAdded:Fire(player)
	return player
end

function Sim.RemovePlayer(player)
	if rawget(player, "_parent") ~= Players then
		return
	end
	Players.PlayerRemoving:Fire(player)
	Sim.resumeOnly(0)
	if player.Character then
		player.Character:Destroy()
	end
	player.Parent = nil
end

function Sim.SpawnCharacter(player)
	local old = player.Character
	if old then
		old:Destroy()
	end
	local character = newInstance("Model", player.Name)
	local root = newInstance("Part", "HumanoidRootPart")
	root.Size = Vector3.new(2, 2, 1)
	local spawnCF = CFrame.new(0, 5, 0)
	local spawnLocation = player.RespawnLocation
	if spawnLocation then
		spawnCF = spawnLocation.CFrame + Vector3.new(0, 3, 0)
	end
	root.CFrame = spawnCF
	root.Parent = character
	local head = newInstance("Part", "Head")
	head.CFrame = spawnCF + Vector3.new(0, 1.5, 0)
	head.Parent = character
	local humanoid = newInstance("Humanoid", "Humanoid")
	humanoid.Parent = character
	character.PrimaryPart = root
	rawget(player, "_props").Character = character
	character.Parent = workspace
	player.CharacterAdded:Fire(character)
	return character
end

function Sim.MoveCharacter(player, position)
	local character = player.Character
	if character then
		character:PivotTo(CFrame.new(position))
	end
end

function Sim.KillCharacter(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = 0
		humanoid.Died:Fire()
	end
end

---------------------------------------------------------------- stepping
local tagSignalsFlushed = true
function Sim.resumeOnly(dt)
	local d = deferred
	deferred = {}
	for _, e in d do
		resume(e[1], table.unpack(e[2], 1, e[2].n))
	end
	local due, remaining = {}, {}
	for _, w in waiting do
		if w.wake <= Sim.clock + 1e-9 then
			table.insert(due, w)
		else
			table.insert(remaining, w)
		end
	end
	waiting = remaining
	table.sort(due, function(a, b)
		return a.wake < b.wake
	end)
	for _, w in due do
		if w.args then
			resume(w.co, table.unpack(w.args, 1, w.args.n))
		else
			resume(w.co, Sim.clock - (w.start or Sim.clock))
		end
	end
	local _ = dt
end

function Sim.Step(dt)
	dt = dt or 1 / 30
	Sim.clock += dt
	Sim.resumeOnly(dt)
	RunService.Heartbeat:Fire(dt)
	RunService.Stepped:Fire(Sim.clock, dt)
	if Sim.localPlayer then
		RunService.RenderStepped:Fire(dt)
		for _, fn in renderSteps do
			local ok, err = pcall(fn, dt)
			if not ok then
				table.insert(Sim.errors, "RenderStep: " .. tostring(err))
			end
		end
	end
	Sim.resumeOnly(0)
end

function Sim.Run(seconds, dt)
	local stepSize = dt or 1 / 20
	local target = Sim.clock + seconds
	while Sim.clock < target - 1e-9 do
		Sim.Step(math.min(stepSize, target - Sim.clock))
	end
end

-- Runs fn inside a coroutine and steps the simulation until it returns.
function Sim.Await(fn, timeout)
	local done, results = false, nil
	task.spawn(function()
		results = table.pack(fn())
		done = true
	end)
	local deadline = Sim.clock + (timeout or 30)
	while not done and Sim.clock < deadline do
		Sim.Step(1 / 20)
	end
	if not done then
		error("Sim.Await timed out")
	end
	return table.unpack(results, 1, results.n)
end

-- Invokes a server action as a client would (through the real RemoteFunction).
function Sim.Invoke(player, action, ...)
	local args = table.pack(...)
	local remote = Sim.game:GetService("ReplicatedStorage"):FindFirstChild("Remotes"):FindFirstChild("Request")
	return Sim.Await(function()
		return remote.OnServerInvoke(player, action, table.unpack(args, 1, args.n))
	end)
end

function Sim.Shutdown()
	for _, fn in Sim.closeHandlers do
		Sim.Await(fn, 60)
	end
end

-- Expose the DataModel as the global `game` for loaded scripts.
getfenv(0).game = Sim.game
