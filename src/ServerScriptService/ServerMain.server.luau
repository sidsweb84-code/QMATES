--[[
	ServerMain
	Boots the server: requires every service, builds the map, then runs
	Init (no cross-service calls) followed by Start (connections + loops).
	PlayerService starts last so players only load into a fully running game.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Only boot from ServerScriptService, never from a copy that is still inside
-- the installer model (StealPokemon_Installer.rbxm) sitting in Workspace.
if not script:IsDescendantOf(ServerScriptService) then
	warn("[StealCritters] Not installed yet: run the installer line in the Command Bar first (see README).")
	return
end

local Modules = script.Parent:WaitForChild("Modules")
local Services = script.Parent:WaitForChild("Services")
local Registry = require(Modules.Registry)
local Log = require(Modules.Log)

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))

Players.CharacterAutoLoads = false

local ORDER = {
	"NetService",
	"DataService",
	"AntiExploitService",
	"BoostService",
	"EventService",
	"EconomyService",
	"CollectibleService",
	"BaseService",
	"ConveyorService",
	"StealService",
	"UpgradeService",
	"RebirthService",
	"QuestService",
	"RewardService",
	"ShopService",
	"CosmeticService",
	"MonetizationService",
	"LeaderboardService",
	"TradeService",
	"TutorialService",
	"AdminService",
	"HandlerService",
	"PlayerService",
}

local startTime = os.clock()
Registry.MapBuilder = require(Services:WaitForChild("MapBuilder"))
for _, name in ORDER do
	Registry[name] = require(Services:WaitForChild(name))
end

for _, name in ORDER do
	local service = Registry[name]
	if service.Init then
		local ok, err = pcall(service.Init, service)
		if not ok then
			Log.Error("Boot", name .. ".Init failed: " .. tostring(err))
		end
	end
end

local map = Registry.MapBuilder.Build()
Registry.BaseService:SetMap(map)
Registry.ConveyorService:SetMap(map)
Registry.LeaderboardService:SetMap(map)
Registry.EventService:SetEventBoard(map.EventBoard)

for _, name in ORDER do
	local service = Registry[name]
	if service.Start then
		local ok, err = pcall(service.Start, service)
		if not ok then
			Log.Error("Boot", name .. ".Start failed: " .. tostring(err))
		end
	end
end

Log.Info("Boot", string.format("Server ready in %.2fs (v%s)", os.clock() - startTime, GameConfig.Version))
print(string.format("[StealCritters] Server ready in %.2fs", os.clock() - startTime))

-- Persist security/admin logs for later review (batched every 5 minutes).
if not RunService:IsStudio() then
	task.spawn(function()
		local ok, store = pcall(function()
			return DataStoreService:GetDataStore("StealCritters_AdminLogs_v1")
		end)
		if not ok then
			return
		end
		while true do
			task.wait(300)
			local pending = Log.TakePending()
			if #pending > 0 then
				local key = os.date("!%Y-%m-%d") :: string
				pcall(function()
					store:UpdateAsync(key, function(old)
						local list = if type(old) == "table" then old else {}
						for _, entry in pending do
							table.insert(list, string.format("%d|%s|%s|%s|%s", entry.Time, entry.Category, entry.Level, tostring(entry.UserId), entry.Message))
						end
						while #list > 2000 do
							table.remove(list, 1)
						end
						return list
					end)
				end)
			end
		end
	end)
end

-- Optional automatic integration tests in Studio.
if RunService:IsStudio() and GameConfig.Testing.AutoRunInStudio then
	task.spawn(function()
		local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
		while not Registry.PlayerService:IsReady(player) do
			task.wait(0.5)
		end
		task.wait(3)
		local runner = require(script.Parent:WaitForChild("Tests"):WaitForChild("TestRunner")) :: any
		local lines = runner.Run(player)
		print(table.concat(lines, "\n"))
	end)
end
