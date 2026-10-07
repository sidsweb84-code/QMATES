--[[
	BoostService
	Personal boosts (saved as UTC expiry timestamps), server-wide boosts and
	admin multipliers (/setluck, /setincome). Server-wide values replicate to
	clients through ReplicatedStorage attributes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BoostConfig = require(Shared.Config.BoostConfig)

local Modules = script.Parent.Parent.Modules
local Registry = require(Modules.Registry)
local Log = require(Modules.Log)

local BoostService = {}

local serverBoosts: { [string]: number } = {} -- [name] = expiry
local adminMultipliers: { [string]: { Multiplier: number, Expires: number } } = {}

function BoostService:Init()
	ReplicatedStorage:SetAttribute("ServerLuckExpires", 0)
	ReplicatedStorage:SetAttribute("AdminLuck", 1)
	ReplicatedStorage:SetAttribute("AdminIncome", 1)
end

function BoostService:Start()
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.time()
			for name, info in adminMultipliers do
				if info.Expires <= now then
					adminMultipliers[name] = nil
					ReplicatedStorage:SetAttribute("Admin" .. name, 1)
					Registry.NetService:NotifyAll("Admin " .. string.lower(name) .. " multiplier ended", "Info")
				end
			end
		end
	end)
end

---------------------------------------------------------------- personal
function BoostService:Add(player: Player, name: string, duration: number): boolean
	local data = Registry.DataService:Get(player)
	if not data or not BoostConfig.Personal[name] or type(duration) ~= "number" or duration <= 0 then
		return false
	end
	local now = os.time()
	local current = math.max(data.Boosts[name] or 0, now)
	data.Boosts[name] = math.min(current + duration, now + BoostConfig.MaxDuration)
	Registry.DataService:MarkDirty(player, "Boosts")
	Registry.EconomyService:Refresh(player)
	Registry.PlayerService:UpdateMovement(player)
	if name == "Protection" then
		Registry.BaseService:UpdateStatus(player)
	end
	Log.Info("Boost", string.format("%s +%ds %s", player.Name, duration, name), player.UserId)
	return true
end

function BoostService:IsActive(player: Player, name: string): boolean
	local data = Registry.DataService:Get(player)
	return data ~= nil and (data.Boosts[name] or 0) > os.time()
end

function BoostService:Remaining(player: Player, name: string): number
	local data = Registry.DataService:Get(player)
	if not data then
		return 0
	end
	return math.max(0, (data.Boosts[name] or 0) - os.time())
end

---------------------------------------------------------------- server-wide
function BoostService:AddServer(name: string, duration: number, sourcePlayer: Player?): boolean
	local info = BoostConfig.Server[name]
	if not info then
		return false
	end
	local now = os.time()
	local current = math.max(serverBoosts[name] or 0, now)
	serverBoosts[name] = math.min(current + duration, now + BoostConfig.MaxDuration)
	ReplicatedStorage:SetAttribute(name .. "Expires", serverBoosts[name])
	Registry.NetService:Announce(string.format("%s activated %s for everyone!", sourcePlayer and sourcePlayer.DisplayName or "Someone", info.Name), info.Color, info.Icon)
	return true
end

function BoostService:ServerMultiplier(name: string): number
	local info = BoostConfig.Server[name]
	if info and (serverBoosts[name] or 0) > os.time() then
		return info.Multiplier
	end
	return 1
end

---------------------------------------------------------------- admin
function BoostService:SetAdminMultiplier(name: string, multiplier: number, duration: number)
	if multiplier == 1 then
		adminMultipliers[name] = nil
	else
		adminMultipliers[name] = { Multiplier = multiplier, Expires = os.time() + duration }
	end
	ReplicatedStorage:SetAttribute("Admin" .. name, multiplier)
end

function BoostService:AdminMultiplier(name: string): number
	local info = adminMultipliers[name]
	if info and info.Expires > os.time() then
		return info.Multiplier
	end
	return 1
end

-- Luck used by conveyors: server boost x admin x event.
function BoostService:ServerLuck(): number
	local mods = Registry.EventService:GetModifiers()
	return self:ServerMultiplier("ServerLuck") * self:AdminMultiplier("Luck") * (mods.LuckMultiplier or 1)
end

return BoostService
