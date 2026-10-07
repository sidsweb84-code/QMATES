--!nocheck
-- Boots the client for a local player and exercises the whole UI.
Sim.BootServer()
local R = Sim.registry()
local StealConfig = require(Sim.find("ReplicatedStorage/Shared/Config/StealConfig"))
local RarityConfig = require(Sim.find("ReplicatedStorage/Shared/Config/RarityConfig"))
local Catalog = require(Sim.find("ReplicatedStorage/Shared/Catalog"))

local me = Sim.AddPlayer(3001, "Tester", true)
Sim.Run(3)
Sim.BootClient()
Sim.Run(6)

local UI = Sim.find("StarterPlayer/StarterPlayerScripts/UI")
local WindowManager = require(UI.WindowManager)
local Reveal = require(UI.Reveal)
local Notifications = require(UI.Notifications)
local State = require(Sim.find("StarterPlayer/StarterPlayerScripts/Controllers/State"))

Sim.assert(State.Loaded, "client state loaded")
Sim.assert(me.PlayerGui:FindFirstChild("StealCrittersUI") ~= nil, "HUD gui created")
Sim.assert(me.PlayerGui:FindFirstChild("LoadingScreen") == nil, "loading screen dismissed")
local data = R.DataService:Get(me)

local function descendantsOfClass(root, className)
	local out = {}
	for _, d in root:GetDescendants() do
		if d.ClassName == className then
			table.insert(out, d)
		end
	end
	return out
end

local function labelText(button)
	local label = button:FindFirstChild("Label")
	return label and label.Text or ""
end

-- Client state mirrors server data
Sim.assert(State.Data.Cash == data.Cash, "cash mirrored")
R.EconomyService:AddCash(me, 12345, "Admin")
Sim.Run(0.5)
Sim.assert(State.Data.Cash == data.Cash, "cash patch applied")

---------------------------------------------------------------- buy through the real prompt
R.EconomyService:AddCash(me, 1e6, "Admin")
local uid = R.ConveyorService:AdminSpawn("zapkit", "Golden", "Lucky", "Main")
Sim.Run(0.5)
local item = R.ConveyorService:GetItems()[uid]
local prompt = item.Model.Root:FindFirstChild("Prompt_Buy")
Sim.assert(prompt ~= nil, "client created a buy prompt")
R.AntiExploitService:MarkTeleport(me)
Sim.MoveCharacter(me, R.ConveyorService:GetPosition(item) + Vector3.new(0, 3, 7))
game:GetService("ProximityPromptService").PromptShown:Fire(prompt, Enum.ProximityPromptInputType.Keyboard)
Sim.Run(0.2)
prompt.Triggered:Fire(me)
Sim.Run(1)
local owned = 0
for _ in data.Inventory do
	owned += 1
end
Sim.assert(owned == 1, "purchase through prompt")
prompt.PromptHidden:Fire()
Sim.Run(8) -- reveal + walk home

---------------------------------------------------------------- reveal tiers
for _, rarity in RarityConfig.Order do
	local def = Catalog.ByRarity[rarity][1]
	Reveal.Show({ Item = { Uid = "x" .. rarity, Id = def.Id, Mutation = if rarity == "Epic" then "Rainbow" else "Normal", Level = 1, Serial = 7 }, IsNew = true, Source = "Conveyor", Income = def.Income })
end
Sim.Run(40)

---------------------------------------------------------------- notifications
Notifications.Toast("hello", "Success")
Notifications.Announce("A LEGENDARY appeared!", Color3.new(1, 1, 0), "👀", "Legendary")
Notifications.Popup("Popup", { "line 1", "line 2" }, "🎁")
Sim.Run(1)
for _, b in descendantsOfClass(me.PlayerGui.StealCrittersTop, "TextButton") do
	b.Activated:Fire()
end
Sim.Run(6)

---------------------------------------------------------------- every window, every tab, every button
R.EconomyService:AddCash(me, 1e9, "Admin")
R.EconomyService:AddTokens(me, 5000)
R.CollectibleService:Grant(me, "solarion", { Source = "Test", Silent = true })
R.CollectibleService:Grant(me, "galaxitty", { Mutation = "Rainbow", Trait = "Jackpot", Source = "Test", Silent = true })
Sim.Run(1)

local windows = {
	{ "Collection", { {} } },
	{ "Shop", { { Tab = "Packs" }, { Tab = "Upgrades" }, { Tab = "Boosts" }, { Tab = "Cosmetics" }, { Tab = "Event" }, { Tab = "Robux" } } },
	{ "Rebirth", { {} } },
	{ "Quests", { { Tab = "Daily" }, { Tab = "Achievements" } } },
	{ "Index", { { Tab = "Book" }, { Tab = "Odds" } } },
	{ "Settings", { {} } },
	{ "Rewards", { {} } },
	{ "Leaderboard", { {} } },
	{ "Players", { {} } },
	{ "Admin", { {} } },
}
local clicked = 0
local skip = { Close = true }
for _, entry in windows do
	for _, args in entry[2] do
		WindowManager.Open(entry[1], args)
		Sim.Run(0.4)
		local shell = me.PlayerGui.StealCrittersUI.Canvas.Windows:FindFirstChild(entry[1] .. "Window")
		Sim.assert(shell and shell.Visible, entry[1] .. " window visible")
		-- Click every button once (fuzz): nothing may throw.
		local buttons = descendantsOfClass(shell, "TextButton")
		for _, b in buttons do
			if not skip[b.Name] and b.Parent and labelText(b) ~= "♻️ REBIRTH" then
				b.Activated:Fire()
				clicked += 1
				Sim.Run(0.05)
			end
		end
		Sim.Run(0.5)
		-- Dismiss any modal that opened
		for _ = 1, 4 do
			for _, b in descendantsOfClass(me.PlayerGui.StealCrittersTop, "TextButton") do
				if b.Parent then
					b.Activated:Fire()
				end
			end
			Sim.Run(0.4)
		end
	end
end
WindowManager.Close()
Sim.Run(1)
print("clicked buttons:", clicked)
Sim.assert(clicked > 50, "fuzzed many buttons")

-- Collection window focused on a specific card
local anyUid = next(data.Inventory)
WindowManager.Open("Collection", { Uid = anyUid })
Sim.Run(0.5)
WindowManager.Close()

---------------------------------------------------------------- HUD buttons
for _, b in descendantsOfClass(me.PlayerGui.StealCrittersUI.Canvas.HUD, "TextButton") do
	if b.Parent then
		b.Activated:Fire()
		Sim.Run(0.3)
		WindowManager.Close()
	end
end
Sim.Run(7)

---------------------------------------------------------------- steal UI (local player is the victim, then the thief)
local other = Sim.AddPlayer(3002, "Other")
Sim.Run(3)
local oData = R.DataService:Get(other)
data = R.DataService:Get(me) -- the fuzz ran /runtests, which restores a snapshot table
R.CollectibleService:Grant(me, "rockhorn", { Source = "Test", Silent = true })
Sim.Run(0.5)
data.Stats.Playtime = StealConfig.NewPlayerProtection + 10
oData.Stats.Playtime = StealConfig.NewPlayerProtection + 10
local myPlot = R.BaseService:GetPlot(me)
local target
for u, it in data.Inventory do
	if it.Slot > 0 and not R.BaseService:IsInTransit(me, u) then
		target = it
	end
end
Sim.assert(target ~= nil, "have a placed critter")
local plotState = R.BaseService:GetPlot(me)
plotState.Locked = false
R.AntiExploitService:MarkTeleport(me)
Sim.MoveCharacter(me, Vector3.new(-280, 5, 0))
R.AntiExploitService:MarkTeleport(other)
Sim.MoveCharacter(other, R.BaseService:SlotCFrame(myPlot, target.Slot).Position + Vector3.new(0, 3, 3))
Sim.Run(0.2)
local res = Sim.Invoke(other, "StartSteal", me.UserId, target.Uid)
Sim.assert(res.Ok, "other steals from me: " .. tostring(res.Message))
Sim.Run(R.StealService:GetTheft(other).Duration + 1)
local alert = me.PlayerGui.StealCrittersUI.Canvas.HUD:FindFirstChild("TheftAlert")
Sim.assert(alert and alert.Visible, "victim alert shown")
R.AntiExploitService:MarkTeleport(me)
Sim.MoveCharacter(me, other.Character.HumanoidRootPart.Position)
Sim.Run(1)
Sim.assert(not alert.Visible, "alert cleared after catch")

-- Local player steals
R.StealService:ResetCooldowns()
local oPlot = R.BaseService:GetPlot(other)
local victimItem = R.CollectibleService:Grant(other, "emberpup", { Source = "Test", Silent = true })
Sim.Run(0.5)
R.AntiExploitService:MarkTeleport(other)
Sim.MoveCharacter(other, Vector3.new(-280, 5, 0))
R.AntiExploitService:MarkTeleport(me)
Sim.MoveCharacter(me, R.BaseService:SlotCFrame(oPlot, victimItem.Slot).Position + Vector3.new(0, 3, 3))
Sim.Run(0.5)
local creature = oPlot.Refs.Creatures:FindFirstChild(victimItem.Uid)
local stealPrompt = creature and creature.Root:FindFirstChild("Prompt_Steal")
Sim.assert(stealPrompt ~= nil, "client created a steal prompt on the other base")
game:GetService("ProximityPromptService").PromptShown:Fire(stealPrompt, Enum.ProximityPromptInputType.Touch)
Sim.Run(0.2)
stealPrompt.Triggered:Fire(me)
Sim.Run(R.StealService:GetTheft(me).Duration + 0.5)
local panel = me.PlayerGui.StealCrittersUI.Canvas.HUD:FindFirstChild("StealPanel")
Sim.assert(panel and panel.Visible, "thief panel shown")
-- cancel via UI button
for _, b in descendantsOfClass(panel, "TextButton") do
	b.Activated:Fire()
end
Sim.Run(1)
Sim.assert(not R.StealService:IsThief(me), "cancelled from UI")

---------------------------------------------------------------- trade request UI
Sim.Run(12)
res = Sim.Invoke(other, "TradeRequest", me.UserId)
Sim.assert(res.Ok, "trade request: " .. tostring(res.Message))
Sim.Run(0.5)
-- Earlier popups may still be queued ahead of the request; dismiss them first.
local accept
for _ = 1, 10 do
	for _, b in descendantsOfClass(me.PlayerGui.StealCrittersTop, "TextButton") do
		if labelText(b) == "Accept" then
			accept = b
		end
	end
	if accept then
		break
	end
	for _, b in descendantsOfClass(me.PlayerGui.StealCrittersTop, "TextButton") do
		if labelText(b) == "Awesome!" then
			b.Activated:Fire()
		end
	end
	Sim.Run(0.5)
end
Sim.assert(accept ~= nil, "trade request modal")
accept.Activated:Fire()
Sim.Run(1)
Sim.assert(WindowManager.Current == "Trade", "trade window opened")
local tradeShell = me.PlayerGui.StealCrittersUI.Canvas.Windows.TradeWindow
for _, b in descendantsOfClass(tradeShell, "TextButton") do
	if b.Parent and b.Name ~= "Close" then
		b.Activated:Fire()
		Sim.Run(0.3)
	end
end
WindowManager.Close()
Sim.Run(2)
Sim.assert(not R.TradeService:IsTrading(me), "closing the window cancels the trade")

---------------------------------------------------------------- settings applied on the client
Sim.Invoke(me, "SaveSettings", { Graphics = "Low", UIScale = "Large", SFX = false })
Sim.Run(1)
local Sound = require(Sim.find("StarterPlayer/StarterPlayerScripts/Controllers/Sound"))
Sim.assert(Sound.SFXEnabled == false, "sfx setting applied")

-- Rebirth effect + event changes on the client
data.Cash = 1e12
Sim.Invoke(me, "Rebirth")
Sim.Invoke(me, "AdminCommand", "/event start LegendaryRush 1")
Sim.Run(70)
print("client ui ok")
