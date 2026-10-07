--[[
	UpgradeService
	Base capacity and security upgrade purchases (UpgradeConfig).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local Economy = require(Shared.Economy)
local Format = require(Shared.Util.Format)

local Modules = script.Parent.Parent.Modules
local Registry = require(Modules.Registry)
local ActionBus = require(Modules.ActionBus)

local UpgradeService = {}

function UpgradeService:Init() end
function UpgradeService:Start() end

function UpgradeService:UpgradeBase(player: Player): (boolean, string?)
	local data = Registry.DataService:Get(player)
	if not data then
		return false, "Not loaded"
	end
	local cost = Economy.NextBaseLevelCost(data.BaseLevel)
	if not cost then
		return false, "Your base is fully upgraded!"
	end
	if not Registry.EconomyService:SpendCash(player, cost, "BaseLevel") then
		return false, "Need " .. Format.Cash(cost)
	end
	data.BaseLevel += 1
	Registry.DataService:MarkDirty(player, "BaseLevel")
	Registry.BaseService:RefreshSlots(player)
	Registry.DataService:SetSession(player, "Capacity", Registry.CollectibleService:Capacity(player))
	ActionBus.Fire(player, "Upgrade", 1, { Track = "Base", Level = data.BaseLevel })
	Registry.NetService:Effect(player, "Upgraded", { Track = "Base", Level = data.BaseLevel })
	local slots = UpgradeConfig.BaseLevels[data.BaseLevel].Slots
	return true, string.format("Base level %d — %d slots!", data.BaseLevel, slots)
end

function UpgradeService:UpgradeTrack(player: Player, track: any): (boolean, string?)
	if type(track) ~= "string" or not UpgradeConfig.Tracks[track] then
		Registry.AntiExploitService:Flag(player, "InvalidArgs", "UpgradeTrack " .. tostring(track))
		return false, "Unknown upgrade"
	end
	local data = Registry.DataService:Get(player)
	if not data then
		return false, "Not loaded"
	end
	local level = data.Upgrades[track]
	local cost = Economy.TrackNextCost(track, level)
	if not cost then
		return false, "Already maxed!"
	end
	if not Registry.EconomyService:SpendCash(player, cost, "Upgrade:" .. track) then
		return false, "Need " .. Format.Cash(cost)
	end
	data.Upgrades[track] = level + 1
	Registry.DataService:MarkDirty(player, "Upgrades")
	if track == "Traps" then
		Registry.BaseService:UpdateTraps(player)
	elseif track == "AutoCollect" then
		-- Pay out anything already on the pad.
		Registry.EconomyService:Collect(player, true)
	end
	ActionBus.Fire(player, "Upgrade", 1, { Track = track, Level = level + 1 })
	Registry.NetService:Effect(player, "Upgraded", { Track = track, Level = level + 1 })
	return true, string.format("%s upgraded to level %d!", UpgradeConfig.Tracks[track].Name, level + 1)
end

return UpgradeService
