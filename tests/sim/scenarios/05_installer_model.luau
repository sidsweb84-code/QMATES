--!nocheck
--@installer
-- Installs the game from build/StealPokemon_Installer.rbxm the way a developer
-- does in Studio (insert the model, run one command-bar line), then plays it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Lighting = game:GetService("Lighting")

---------------------------------------------------------------- a typical existing place
-- "Baseplate" template parts, a leftover from an older install, and the
-- developer's own (licensed) assets that must survive a reinstall.
Sim.newInstance("Part", "Baseplate").Parent = workspace
Sim.newInstance("SpawnLocation", "SpawnLocation").Parent = workspace
local oldShared = Sim.newInstance("Folder", "Shared")
oldShared.Parent = ReplicatedStorage
local myAssets = Sim.newInstance("Folder", "Assets")
myAssets.Parent = ReplicatedStorage
local myCreatures = Sim.newInstance("Folder", "Creatures")
myCreatures.Parent = myAssets
Sim.newInstance("Model", "MyLicensedModel").Parent = myCreatures
Players.CharacterAutoLoads = true -- template defaults
workspace.StreamingEnabled = true

local installer = workspace:FindFirstChild("StealPokemon_Installer")
Sim.assert(installer ~= nil, "installer model is in Workspace")
Sim.assert(installer.ServerScriptService.ServerMain.Enabled == false, "server entry script ships disabled")
Sim.assert(ServerScriptService:FindFirstChild("ServerMain") == nil, "nothing installed yet")

---------------------------------------------------------------- run the command-bar line
local install = require(installer.StealPokemon_Install)
-- The simulator is always "running"; the real installer refuses Play mode.
local okRunning, errRunning = pcall(install)
Sim.assert(not okRunning and string.find(tostring(errRunning), "Edit mode", 1, true), "refuses to install while playing: " .. tostring(errRunning))
Sim.assert(workspace:FindFirstChild("StealPokemon_Installer") == installer, "refusal leaves the installer untouched")

local report = install({ AllowWhileRunning = true })
print("installed:", table.concat(report.Installed, ", "))
print("backed up:", table.concat(report.BackedUp, ", "))

---------------------------------------------------------------- everything is where Rojo would put it
Sim.assert(workspace:FindFirstChild("StealPokemon_Installer") == nil, "installer removed itself")
Sim.assert(#report.Installed == 10, "installed 10 top-level items, got " .. #report.Installed)
Sim.assert(#report.SettingsSkipped == 0, "all settings applied: " .. table.concat(report.SettingsSkipped, ", "))

local main = ServerScriptService:FindFirstChild("ServerMain")
Sim.assert(main and main.ClassName == "Script" and main.Enabled == true, "ServerMain installed and enabled")
for _, name in { "Modules", "Services", "Tests" } do
	Sim.assert(ServerScriptService:FindFirstChild(name), "ServerScriptService." .. name)
end
local sps = StarterPlayer:FindFirstChildOfClass("StarterPlayerScripts")
for _, name in { "ClientMain", "Controllers", "UI" } do
	Sim.assert(sps:FindFirstChild(name), "StarterPlayerScripts." .. name)
end
Sim.assert(ReplicatedFirst:FindFirstChild("LoadingScreen"), "ReplicatedFirst.LoadingScreen")
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
Sim.assert(remotes and remotes:FindFirstChild("Request") and remotes:FindFirstChild("Event") and remotes:FindFirstChild("Sync"), "remotes")

-- Older copy backed up, not deleted; developer assets kept and completed.
local shared = ReplicatedStorage:FindFirstChild("Shared")
Sim.assert(shared ~= oldShared and shared:FindFirstChild("Net"), "fresh Shared installed")
local backup = report.Backup
Sim.assert(backup and backup.Parent == ServerStorage, "backup folder in ServerStorage")
Sim.assert(oldShared:IsDescendantOf(backup), "old Shared moved to backup")
Sim.assert(ReplicatedStorage:FindFirstChild("Assets") == myAssets, "existing Assets kept")
Sim.assert(myCreatures:FindFirstChild("MyLicensedModel"), "licensed model kept")
Sim.assert(myAssets:FindFirstChild("Sounds") and myAssets:FindFirstChild("Images"), "missing asset folders added")

-- Template parts moved out of the way of the generated map.
Sim.assert(workspace:FindFirstChild("Baseplate") == nil and workspace:FindFirstChild("SpawnLocation") == nil, "template parts removed from Workspace")
Sim.assert(backup.Workspace:FindFirstChild("Baseplate") and backup.Workspace:FindFirstChild("SpawnLocation"), "template parts kept in backup")

-- Place settings from default.project.json
Sim.assert(Players.CharacterAutoLoads == false, "CharacterAutoLoads off")
Sim.assert(Players.RespawnTime == 3, "RespawnTime")
Sim.assert(StarterPlayer.CameraMaxZoomDistance == 90, "camera zoom")
Sim.assert(Lighting.ClockTime == 14.5, "lighting")
Sim.assert(workspace.FallenPartsDestroyHeight == -100, "fall height")
Sim.assert(workspace.StreamingEnabled == false, "streaming off")

-- Running it twice is harmless.
local okAgain, errAgain = pcall(install, { AllowWhileRunning = true })
Sim.assert(not okAgain and string.find(tostring(errAgain), "Already installed", 1, true), "second run refused: " .. tostring(errAgain))

---------------------------------------------------------------- and the installed game plays
Sim.BootServer()
local R = Sim.registry()
Sim.assert(#workspace.World.Plots:GetChildren() == 8, "map generated")
local me = Sim.AddPlayer(5001, "Installer", true)
Sim.Run(3)
Sim.assert(me:GetAttribute("DataLoaded") == true, "player data loaded")
Sim.assert(me:GetAttribute("PlotIndex") ~= nil, "player got a base")
Sim.BootClient()
Sim.Run(6)
Sim.assert(me.PlayerGui:FindFirstChild("StealCrittersUI") ~= nil, "HUD shows")

R.EconomyService:AddCash(me, 1e6, "Admin")
local uid = R.ConveyorService:AdminSpawn("zapkit", "Normal", nil, "Main")
Sim.Run(0.5)
local item = R.ConveyorService:GetItems()[uid]
R.AntiExploitService:MarkTeleport(me)
Sim.MoveCharacter(me, R.ConveyorService:GetPosition(item) + Vector3.new(0, 3, 7))
Sim.Run(0.2)
local res = Sim.Invoke(me, "BuyConveyor", uid)
Sim.assert(res.Ok, "bought a critter after installing: " .. tostring(res.Message))
Sim.Run(8)
print("installer ok")
