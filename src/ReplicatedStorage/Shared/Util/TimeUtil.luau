--[[
	TimeUtil
	UTC day helpers used for daily quests, streaks and playtime resets.
]]

local TimeUtil = {}

TimeUtil.DaySeconds = 86400

function TimeUtil.Now(): number
	return os.time()
end

-- Integer day number since the Unix epoch (UTC).
function TimeUtil.DayNumber(timestamp: number?): number
	return math.floor((timestamp or os.time()) / TimeUtil.DaySeconds)
end

function TimeUtil.SecondsUntilNextDay(timestamp: number?): number
	local t = timestamp or os.time()
	return TimeUtil.DaySeconds - (t % TimeUtil.DaySeconds)
end

-- 1 = Sunday ... 7 = Saturday (UTC)
function TimeUtil.Weekday(timestamp: number?): number
	local date = os.date("!*t", timestamp or os.time())
	return (date :: any).wday
end

function TimeUtil.IsWeekend(timestamp: number?): boolean
	local wday = TimeUtil.Weekday(timestamp)
	return wday == 1 or wday == 7
end

-- Month/day comparison helper that supports ranges crossing new year.
function TimeUtil.InDateRange(timestamp: number?, startMonth: number, startDay: number, endMonth: number, endDay: number): boolean
	local date = os.date("!*t", timestamp or os.time()) :: any
	local current = date.month * 100 + date.day
	local startKey = startMonth * 100 + startDay
	local endKey = endMonth * 100 + endDay
	if startKey <= endKey then
		return current >= startKey and current <= endKey
	end
	return current >= startKey or current <= endKey
end

-- Deterministic hash of an integer (used for globally consistent rotations).
function TimeUtil.Hash(n: number): number
	local x = (n * 2654435761) % 4294967296
	x = (x + 0x9E3779B9) % 4294967296
	x = (x * 40503) % 4294967296
	return x
end

return TimeUtil
