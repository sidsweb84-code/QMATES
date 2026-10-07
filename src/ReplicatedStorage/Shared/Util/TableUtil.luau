--[[
	TableUtil
]]

local TableUtil = {}

function TableUtil.DeepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value :: any do
		copy[TableUtil.DeepCopy(k)] = TableUtil.DeepCopy(v)
	end
	return (copy :: any) :: T
end

function TableUtil.Count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

function TableUtil.Keys(t: { [any]: any }): { any }
	local keys = {}
	for k in t do
		table.insert(keys, k)
	end
	return keys
end

-- Fills in missing keys of target from template (recursively). Returns target.
function TableUtil.Reconcile(target: { [any]: any }, template: { [any]: any }): { [any]: any }
	for k, v in template do
		if target[k] == nil then
			target[k] = TableUtil.DeepCopy(v)
		elseif type(v) == "table" and type(target[k]) == "table" then
			-- Only recurse into dictionaries that act as structured records
			-- (non-empty templates). Empty template tables are containers.
			if next(v) ~= nil then
				TableUtil.Reconcile(target[k], v)
			end
		end
	end
	return target
end

function TableUtil.IsFiniteNumber(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

function TableUtil.Shuffle<T>(list: { T }, rng: Random?): { T }
	local random = rng or Random.new()
	for i = #list, 2, -1 do
		local j = random:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

return TableUtil
