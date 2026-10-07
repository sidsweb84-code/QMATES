--[[
	RateLimiter
	Per-player token buckets keyed by action name.
]]

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type Bucket = { Tokens: number, Last: number }

function RateLimiter.new(clock: (() -> number)?)
	return setmetatable({ _buckets = {}, _clock = clock or os.clock }, RateLimiter)
end

-- Returns true if the action is allowed (consumes one token).
function RateLimiter:Check(key: any, action: string, rate: number, burst: number): boolean
	local now = self._clock()
	local perKey = self._buckets[key]
	if not perKey then
		perKey = {}
		self._buckets[key] = perKey
	end
	local bucket: Bucket? = perKey[action]
	if not bucket then
		bucket = { Tokens = burst, Last = now }
		perKey[action] = bucket
	end
	local b = bucket :: Bucket
	b.Tokens = math.min(burst, b.Tokens + (now - b.Last) * rate)
	b.Last = now
	if b.Tokens >= 1 then
		b.Tokens -= 1
		return true
	end
	return false
end

function RateLimiter:Clear(key: any)
	self._buckets[key] = nil
end

return RateLimiter
