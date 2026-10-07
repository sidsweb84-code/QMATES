--!nocheck
-- Boots the server, joins one player and checks the core join pipeline.
Sim.BootServer()
local Registry = Sim.registry()
Sim.assert(Registry.DataService ~= nil, "services registered")
Sim.assert(workspace:FindFirstChild("World") ~= nil, "map built")
Sim.assert(#workspace.World.Plots:GetChildren() == 8, "8 plots built")

local alice = Sim.AddPlayer(1001, "Alice")
Sim.Run(3)
Sim.assert(alice:GetAttribute("DataLoaded") == true, "data loaded")
Sim.assert(alice:GetAttribute("PlotIndex") ~= nil, "plot assigned")
Sim.assert(alice.Character ~= nil, "character spawned")
Sim.assert(alice:FindFirstChild("leaderstats") ~= nil, "leaderstats")

local hello = Sim.Invoke(alice, "Hello")
Sim.assert(hello.Ok, "hello ok: " .. tostring(hello.Message))
Sim.assert(hello.Data.Data.Cash ~= nil, "snapshot has cash")
Sim.assert(hello.Data.Data.Receipts == nil, "private keys not replicated")

-- Conveyor is populated
Sim.Run(3)
local items = Registry.ConveyorService:GetItems()
local n = 0
for _ in items do
	n += 1
end
Sim.assert(n > 5, "conveyor has items: " .. n)
print("boot ok, conveyor items:", n)

-- Server full: every base taken -> the extra player is sent away cleanly and
-- their profile is released (saved, lock cleared) rather than left locked.
for i = 2, 8 do
	Sim.AddPlayer(1000 + i, "Filler" .. i)
end
Sim.Run(4)
local extra = Sim.AddPlayer(1009, "Extra")
Sim.Run(4)
local kickedExtra = false
for _, k in Sim.kicks do
	if k.Player == extra and string.find(k.Message, "full") then
		kickedExtra = true
	end
end
Sim.assert(kickedExtra, "9th player is told the server is full")
Sim.assert(Registry.DataService:Get(extra) == nil, "extra player's profile released")
local saved = Registry.DataService.Store.Data["Player_1009"]
Sim.assert(saved and (saved.SessionLock == nil or saved.SessionLock.JobId == nil), "extra player's session lock cleared")
print("server-full handling ok")
