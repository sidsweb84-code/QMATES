--[[
	Format
	Number / time formatting helpers shared by server and client.
]]

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local function trimZeros(s: string): string
	if string.find(s, "%.") then
		s = string.gsub(s, "0+$", "")
		s = string.gsub(s, "%.$", "")
	end
	return s
end

function Format.Abbreviate(n: number, decimals: number?): string
	if type(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge then
		return "0"
	end
	local negative = n < 0
	local value = math.abs(n)
	local result: string
	if value < 1000 then
		if value == math.floor(value) then
			result = tostring(math.floor(value))
		else
			result = trimZeros(string.format("%.1f", value))
		end
	else
		local index = math.floor(math.log10(value) / 3)
		index = math.clamp(index, 1, #SUFFIXES - 1)
		local scaled = value / 10 ^ (index * 3)
		local d = decimals or (if scaled < 10 then 2 elseif scaled < 100 then 1 else 0)
		local text = string.format("%." .. tostring(d) .. "f", scaled)
		if tonumber(text) and (tonumber(text) :: number) >= 1000 and index < #SUFFIXES - 1 then
			index += 1
			scaled = value / 10 ^ (index * 3)
			text = string.format("%." .. tostring(decimals or 2) .. "f", scaled)
		end
		result = trimZeros(text) .. SUFFIXES[index + 1]
	end
	return (negative and "-" or "") .. result
end

function Format.Cash(n: number): string
	return "$" .. Format.Abbreviate(n)
end

function Format.PerSec(n: number): string
	return "$" .. Format.Abbreviate(n) .. "/s"
end

function Format.Commas(n: number): string
	local s = tostring(math.floor(math.abs(n)))
	local formatted = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1,")))
	if string.sub(formatted, 1, 1) == "," then
		formatted = string.sub(formatted, 2)
	end
	return (n < 0 and "-" or "") .. formatted
end

-- "1h 05m", "4m 20s", "12s"
function Format.Time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local d = math.floor(seconds / 86400)
	local h = math.floor((seconds % 86400) / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	if d > 0 then
		return string.format("%dd %02dh", d, h)
	elseif h > 0 then
		return string.format("%dh %02dm", h, m)
	elseif m > 0 then
		return string.format("%dm %02ds", m, s)
	end
	return string.format("%ds", s)
end

-- "04:20"
function Format.Clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	if m >= 60 then
		return string.format("%d:%02d:%02d", math.floor(m / 60), m % 60, s)
	end
	return string.format("%02d:%02d", m, s)
end

-- Probability (0..1) -> readable percentage, handling tiny values.
function Format.Percent(p: number): string
	local pct = p * 100
	if pct <= 0 then
		return "0%"
	elseif pct >= 10 then
		return trimZeros(string.format("%.1f", pct)) .. "%"
	elseif pct >= 1 then
		return trimZeros(string.format("%.2f", pct)) .. "%"
	elseif pct >= 0.01 then
		return trimZeros(string.format("%.3f", pct)) .. "%"
	elseif pct >= 0.0001 then
		return trimZeros(string.format("%.5f", pct)) .. "%"
	end
	return "<0.0001%"
end

-- 1 in N style odds
function Format.OneIn(p: number): string
	if p <= 0 then
		return "—"
	end
	return "1 in " .. Format.Abbreviate(math.max(1, math.floor(1 / p + 0.5)))
end

function Format.Multiplier(x: number): string
	return "x" .. trimZeros(string.format("%.2f", x))
end

function Format.Ordinal(n: number): string
	local suffix = "th"
	local lastTwo = n % 100
	if lastTwo < 11 or lastTwo > 13 then
		local last = n % 10
		if last == 1 then
			suffix = "st"
		elseif last == 2 then
			suffix = "nd"
		elseif last == 3 then
			suffix = "rd"
		end
	end
	return tostring(n) .. suffix
end

function Format.Serial(n: number): string
	if not n or n <= 0 then
		return "#----"
	end
	return string.format("#%04d", n)
end

function Format.Number(n: number): string
	return string.format("No.%03d", n)
end

return Format
