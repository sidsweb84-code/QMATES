--[[
	EventService (the EventManager)
	Decides which events are active, merges their modifiers, applies map
	decorations/lighting and replicates the state to clients.

	Sources of active events (all optional, see EventConfig.Schedule):
	- Rotation: deterministic from UTC time, so every server agrees.
	- Weekend: Saturday + Sunday UTC.
	- Seasonal: calendar date ranges.
	- Admin: /event start <Id> [minutes] and /event stop <Id>.

	Adding an event = add an entry to EventConfig.Events (+ schedule it).
]]

local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EventConfig = require(Shared.Config.EventConfig)
local TimeUtil = require(Shared.Util.TimeUtil)
local Signal = require(Shared.Util.Signal)
local Format = require(Shared.Util.Format)

local Modules = script.Parent.Parent.Modules
local Registry = require(Modules.Registry)
local Log = require(Modules.Log)

local EventService = {}

export type ActiveEvent = { Id: string, EndsAt: number, Source: string }

EventService.Changed = Signal.new()

local active: { [string]: ActiveEvent } = {}
local forced: { [string]: number } = {} -- admin-started: [id] = endsAt
local suppressed: { [string]: number } = {} -- admin-stopped: [id] = until
local modifiers = { IncomeMultiplier = 1, LuckMultiplier = 1, ActiveEvents = {} }
local decorations: { [string]: Instance } = {}
local defaultLighting: { [string]: any } = {}
local eventBoard: Frame? = nil

local function endOfDate(month: number, day: number): number
	local now = os.date("!*t") :: any
	local year = now.year
	if month < now.month then
		year += 1
	end
	-- os.time interprets the table as local time; Roblox servers run in UTC.
	return os.time({ year = year, month = month, day = day, hour = 23, min = 59, sec = 59 })
end

local function computeScheduled(now: number): { [string]: ActiveEvent }
	local result: { [string]: ActiveEvent } = {}
	local schedule = EventConfig.Schedule

	local rotation = schedule.Rotation
	if rotation.Enabled and #rotation.Pool > 0 then
		local slot = math.floor(now / rotation.Period)
		local offset = now % rotation.Period
		if offset < rotation.Duration then
			local id = rotation.Pool[(TimeUtil.Hash(slot) % #rotation.Pool) + 1]
			result[id] = { Id = id, EndsAt = slot * rotation.Period + rotation.Duration, Source = "Rotation" }
		end
	end

	if schedule.Weekend.Enabled and TimeUtil.IsWeekend(now) then
		local wday = TimeUtil.Weekday(now) -- 7 = Saturday, 1 = Sunday
		local daysLeft = if wday == 7 then 2 else 1
		local endsAt = (TimeUtil.DayNumber(now) + daysLeft) * TimeUtil.DaySeconds
		result[schedule.Weekend.Event] = { Id = schedule.Weekend.Event, EndsAt = endsAt, Source = "Weekend" }
	end

	for _, season in schedule.Seasonal do
		if TimeUtil.InDateRange(now, season.StartMonth, season.StartDay, season.EndMonth, season.EndDay) then
			result[season.Event] = { Id = season.Event, EndsAt = endOfDate(season.EndMonth, season.EndDay), Source = "Seasonal" }
		end
	end
	return result
end

local function mergeModifiers(events: { [string]: ActiveEvent })
	local merged = {
		IncomeMultiplier = 1,
		LuckMultiplier = 1,
		RarityWeightMultipliers = {},
		MutationChanceMultipliers = {},
		EnabledMutations = {},
		LimitedWeight = 0,
		EventTokensPerPurchase = 0,
		ActiveEvents = {},
	}
	for id in events do
		local def = EventConfig.Events[id]
		if not def then
			continue
		end
		merged.ActiveEvents[id] = true
		local m = def.Modifiers or {}
		merged.IncomeMultiplier *= m.IncomeMultiplier or 1
		merged.LuckMultiplier *= m.LuckMultiplier or 1
		for rarity, mult in m.RarityWeightMultipliers or {} do
			merged.RarityWeightMultipliers[rarity] = (merged.RarityWeightMultipliers[rarity] or 1) * mult
		end
		for mutation, mult in m.MutationChanceMultipliers or {} do
			merged.MutationChanceMultipliers[mutation] = (merged.MutationChanceMultipliers[mutation] or 1) * mult
		end
		for _, mutation in m.EnableMutations or {} do
			local chance = (m.EnableMutationChance and m.EnableMutationChance[mutation]) or 0.001
			merged.EnabledMutations[mutation] = math.max(merged.EnabledMutations[mutation] or 0, chance)
		end
		merged.LimitedWeight += m.LimitedWeight or 0
		merged.EventTokensPerPurchase += m.EventTokensPerPurchase or 0
	end
	return merged
end

function EventService:Init()
	for _, key in { "ClockTime", "FogEnd", "FogColor", "Ambient" } do
		defaultLighting[key] = (Lighting :: any)[key]
	end
	ReplicatedStorage:SetAttribute("ActiveEvents", "[]")
end

function EventService:SetEventBoard(frame: Frame)
	eventBoard = frame
end

function EventService:Start()
	self:Refresh()
	task.spawn(function()
		while true do
			task.wait(5)
			local ok, err = pcall(self.Refresh, self)
			if not ok then
				Log.Error("Event", "refresh failed: " .. tostring(err))
			end
		end
	end)
end

function EventService:Refresh()
	local now = os.time()
	local nextActive = computeScheduled(now)
	for id, endsAt in forced do
		if endsAt > now then
			nextActive[id] = { Id = id, EndsAt = endsAt, Source = "Admin" }
		else
			forced[id] = nil
		end
	end
	for id, untilTime in suppressed do
		if untilTime > now then
			nextActive[id] = nil
		else
			suppressed[id] = nil
		end
	end

	-- Detect changes
	local changed = false
	for id, info in nextActive do
		if not active[id] or active[id].EndsAt ~= info.EndsAt then
			changed = true
			if not active[id] then
				local def = EventConfig.Events[id]
				if def then
					Registry.NetService:Announce(string.format("%s %s has started! %s", def.Icon, def.Name, def.Description), def.Color, def.Icon)
					Log.Info("Event", "started " .. id .. " (" .. info.Source .. ")")
				end
			end
		end
	end
	for id in active do
		if not nextActive[id] then
			changed = true
			local def = EventConfig.Events[id]
			if def then
				Registry.NetService:Announce(def.Icon .. " " .. def.Name .. " has ended.", def.Color, def.Icon)
			end
		end
	end
	if not changed then
		return
	end

	active = nextActive
	modifiers = mergeModifiers(active)
	self:_applyWorld()

	local list = {}
	for id, info in active do
		table.insert(list, { Id = id, EndsAt = info.EndsAt, Source = info.Source })
	end
	ReplicatedStorage:SetAttribute("ActiveEvents", HttpService:JSONEncode(list))
	self.Changed:Fire(active)
	for _, player in game:GetService("Players"):GetPlayers() do
		Registry.EconomyService:Refresh(player)
	end
end

function EventService:_applyWorld()
	-- Decorations
	local wanted: { [string]: boolean } = {}
	for id in active do
		local def = EventConfig.Events[id]
		if def and def.Decorations then
			wanted[def.Decorations] = true
		end
	end
	for kind, folder in decorations do
		if not wanted[kind] then
			folder:Destroy()
			decorations[kind] = nil
		end
	end
	for kind in wanted do
		if not decorations[kind] then
			local folder = Registry.MapBuilder.BuildDecorations(kind)
			local world = workspace:FindFirstChild("World")
			folder.Parent = world or workspace
			decorations[kind] = folder
		end
	end

	-- Lighting: first active event with Lighting wins.
	local lightingOverride = nil
	for id in active do
		local def = EventConfig.Events[id]
		if def and def.Lighting then
			lightingOverride = def.Lighting
			break
		end
	end
	for key, value in defaultLighting do
		local target = if lightingOverride and lightingOverride[key] ~= nil then lightingOverride[key] else value
		pcall(function()
			(Lighting :: any)[key] = target
		end)
	end

	-- Event board in the hub
	if eventBoard then
		local title = eventBoard:FindFirstChild("EventTitle") :: TextLabel?
		local text = eventBoard:FindFirstChild("EventText") :: TextLabel?
		local names = {}
		for id, info in active do
			local def = EventConfig.Events[id]
			if def then
				table.insert(names, string.format("%s %s (%s)", def.Icon, def.Name, Format.Time(info.EndsAt - os.time())))
			end
		end
		if title then
			title.Text = if #names > 0 then "🎪 LIVE EVENTS" else "🎪 EVENTS"
		end
		if text then
			text.Text = if #names > 0 then table.concat(names, "  •  ") else "Next event starts soon — check back!"
		end
	end
end

function EventService:GetModifiers()
	return modifiers
end

function EventService:GetActive(): { [string]: ActiveEvent }
	return active
end

function EventService:IsActive(id: string): boolean
	return active[id] ~= nil
end

-- Event currency display info (first active event with a custom currency).
function EventService:Currency()
	for id in active do
		local def = EventConfig.Events[id]
		if def and def.Currency then
			return def.Currency
		end
	end
	return EventConfig.DefaultCurrency
end

function EventService:StartEvent(id: string, minutes: number): (boolean, string)
	if not EventConfig.Events[id] then
		return false, "Unknown event " .. tostring(id)
	end
	forced[id] = os.time() + math.floor(minutes * 60)
	suppressed[id] = nil
	self:Refresh()
	return true, "Started " .. id .. " for " .. tostring(minutes) .. " minutes"
end

function EventService:StopEvent(id: string): (boolean, string)
	if not EventConfig.Events[id] then
		return false, "Unknown event " .. tostring(id)
	end
	forced[id] = nil
	suppressed[id] = os.time() + 24 * 3600
	self:Refresh()
	return true, "Stopped " .. id
end

function EventService:ClearOverrides()
	table.clear(forced)
	table.clear(suppressed)
	self:Refresh()
end

return EventService
