--!nocheck
-- Tiny describe/it/expect framework for the offline runner.

local passed, failed = 0, 0
local failures = {}
local currentSpec = ""
local currentGroup = ""

function describe(name, fn)
	local previous = currentGroup
	currentGroup = name
	fn()
	currentGroup = previous
end

function it(name, fn)
	local ok, err = pcall(fn)
	local label = currentSpec .. " > " .. currentGroup .. " > " .. name
	if ok then
		passed += 1
	else
		failed += 1
		table.insert(failures, label .. "\n      " .. tostring(err))
	end
end

local function fmt(v)
	if type(v) == "string" then return string.format("%q", v) end
	return tostring(v)
end

function expect(actual)
	local e = {}
	function e.toBe(expected)
		if actual ~= expected then
			error(string.format("expected %s to be %s", fmt(actual), fmt(expected)), 2)
		end
	end
	function e.toBeTruthy()
		if not actual then error("expected truthy, got " .. fmt(actual), 2) end
	end
	function e.toBeFalsy()
		if actual then error("expected falsy, got " .. fmt(actual), 2) end
	end
	function e.toBeNear(expected, tolerance)
		if math.abs(actual - expected) > (tolerance or 1e-6) then
			error(string.format("expected %s to be near %s (±%s)", fmt(actual), fmt(expected), fmt(tolerance or 1e-6)), 2)
		end
	end
	function e.toBeGreaterThan(n)
		if not (actual > n) then error(string.format("expected %s > %s", fmt(actual), fmt(n)), 2) end
	end
	function e.toBeLessThan(n)
		if not (actual < n) then error(string.format("expected %s < %s", fmt(actual), fmt(n)), 2) end
	end
	function e.toBeAtLeast(n)
		if not (actual >= n) then error(string.format("expected %s >= %s", fmt(actual), fmt(n)), 2) end
	end
	function e.toBeAtMost(n)
		if not (actual <= n) then error(string.format("expected %s <= %s", fmt(actual), fmt(n)), 2) end
	end
	function e.toBeNil()
		if actual ~= nil then error("expected nil, got " .. fmt(actual), 2) end
	end
	function e.never()
		return nil
	end
	return e
end

function __runSpec(name, src)
	currentSpec = name
	currentGroup = ""
	local chunk, err = loadstring(src, "=" .. name)
	if not chunk then
		failed += 1
		table.insert(failures, name .. " failed to compile: " .. tostring(err))
		return
	end
	local ok, runErr = pcall(chunk)
	if not ok then
		failed += 1
		table.insert(failures, name .. " crashed: " .. tostring(runErr))
	end
end

function __finish()
	print(string.format("\n%d passed, %d failed", passed, failed))
	for _, f in failures do
		print("  FAIL " .. f)
	end
	if failed > 0 then
		error("tests failed")
	end
end
