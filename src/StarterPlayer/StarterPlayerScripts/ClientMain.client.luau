--[[
	ClientMain
	Boots the client: data mirror, UI, world animation, interactions and all
	server event handlers. Every module is presentation only — the server is
	authoritative for everything that matters.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local MapConfig = require(Shared.Config.MapConfig)
local Format = require(Shared.Util.Format)

local Controllers = script.Parent:WaitForChild("Controllers")
local UI = script.Parent:WaitForChild("UI")
local Windows = UI:WaitForChild("Windows")

local player = Players.LocalPlayer

-- No tools in this game: hide the backpack bar.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local State = require(Controllers.State)
State.Start()

local Sound = require(Controllers.Sound)
local Effects = require(Controllers.Effects)
local Root = require(UI.Root)
local WindowManager = require(UI.WindowManager)
local Notifications = require(UI.Notifications)
local HUD = require(UI.HUD)
local Reveal = require(UI.Reveal)
local Interaction = require(Controllers.Interaction)
local World = require(Controllers.World)
local Steal = require(Controllers.Steal)
local Tutorial = require(Controllers.Tutorial)
local Input = require(Controllers.Input)

-- Windows
local windowModules = {
	Collection = require(Windows.Collection),
	Shop = require(Windows.Shop),
	Rebirth = require(Windows.Rebirth),
	Quests = require(Windows.Quests),
	Index = require(Windows.Index),
	Settings = require(Windows.Settings),
	Rewards = require(Windows.Rewards),
	Leaderboard = require(Windows.Leaderboard),
	Players = require(Windows.PlayersWindow),
	Trade = require(Windows.Trade),
	Admin = require(Windows.Admin),
}
for name, module in windowModules do
	WindowManager.Register(name, module)
	if module.Init then
		module.Init()
	end
end

---------------------------------------------------------------- settings
local function applySettings(settings)
	if type(settings) ~= "table" then
		return
	end
	Sound.SetSFX(settings.SFX ~= false)
	Sound.SetMusic(settings.Music ~= false)
	Effects.ReduceMotion = settings.ReduceMotion == true
	Effects.Graphics = settings.Graphics or "High"
	World.ApplyGraphics(settings.Graphics or "High")
	World.SetCardLabels(settings.CardLabels ~= false)
	Root.SetUserScale(settings.UIScale or "Normal")
	local low = settings.Graphics == "Low"
	for _, name in { "Bloom", "SunRays" } do
		local effect = Lighting:FindFirstChild(name)
		if effect and (effect:IsA("BloomEffect") or effect:IsA("SunRaysEffect")) then
			effect.Enabled = not low
		end
	end
end
windowModules.Settings.Apply = applySettings

---------------------------------------------------------------- start everything
HUD.Start()
Interaction.Start()
World.Start()
Steal.Start()
Tutorial.Start()
Input.Start()

State.On("Settings", applySettings)

---------------------------------------------------------------- server events
Net.On(Net.Events.Notify, function(text, kind, icon)
	Notifications.Toast(text, kind, icon)
end)

Net.On(Net.Events.Announce, function(text, color, icon, rarity)
	Notifications.Announce(text, color, icon, rarity)
end)

Net.On(Net.Events.Popup, function(title, lines, icon)
	Notifications.Popup(title, lines or {}, icon)
end)

Net.On(Net.Events.Reveal, function(data)
	Reveal.Show(data)
end)

local function myPadPosition(): Vector3?
	local index = player:GetAttribute("PlotIndex")
	local origin = index and MapConfig.PlotOrigins[index]
	return origin and (origin * CFrame.new(MapConfig.Plot.CollectPad)).Position or nil
end

local function myCreaturePosition(uid: string): Vector3?
	local world = workspace:FindFirstChild("World")
	local plots = world and world:FindFirstChild("Plots")
	local plot = plots and plots:FindFirstChild("Plot" .. tostring(player:GetAttribute("PlotIndex")))
	local creatures = plot and plot:FindFirstChild("Creatures")
	local model = creatures and creatures:FindFirstChild(uid)
	return model and (model :: Model):GetPivot().Position or nil
end

local effectHandlers: { [string]: (any) -> () } = {
	Purchase = function()
		Sound.Play("Purchase")
	end,
	CashCollected = function(payload)
		Sound.Play("CashCollect")
		local pad = myPadPosition()
		if pad then
			Effects.FloatingText(pad + Vector3.new(0, 3, 0), "+" .. Format.Cash(payload.Amount or 0))
		end
		HUD.FlyCash(nil, payload.Amount or 0)
	end,
	Jackpot = function(payload)
		Sound.Sequence({ { "Jackpot", 0 }, { "Jackpot", 0.12, 1.2 }, { "Jackpot", 0.24, 1.4 } })
		Effects.Confetti(30)
		local pos = myCreaturePosition(payload.Uid or "")
		if pos then
			Effects.FloatingText(pos + Vector3.new(0, 4, 0), "🎰 +" .. Format.Cash(payload.Amount or 0), Color3.fromRGB(255, 220, 80), 40)
		end
	end,
	LevelUp = function(payload)
		Sound.Play("Upgrade", { Pitch = 1.2 })
		local pos = myCreaturePosition(payload.Uid or "")
		if pos then
			Effects.FloatingText(pos + Vector3.new(0, 4, 0), "⬆ LEVEL " .. tostring(payload.Level), Color3.fromRGB(255, 230, 120))
		end
	end,
	Upgraded = function()
		Sound.Play("Upgrade")
		Effects.Confetti(25)
	end,
	BaseLocked = function()
		Sound.Play("Lock")
		Effects.Flash(Color3.fromRGB(90, 255, 140), 0.4, 0.7)
	end,
	Rebirth = function(payload)
		Sound.Sequence({ { "Rebirth", 0 }, { "RevealLegendary", 0.2, 0.8 }, { "RevealLegendary", 0.45, 1.2 } })
		Effects.Flash(Color3.fromRGB(120, 255, 170), 1.2, 0)
		Effects.Confetti(90)
		Effects.FovPunch(12, 1)
		WindowManager.Close()
		Notifications.Popup("REBIRTH " .. tostring(payload.Rebirths) .. "!", {
			"Permanent income: " .. Format.Multiplier(payload.Multiplier or 1),
			if (payload.Kept or 0) > 0 then ("You kept your best " .. payload.Kept .. " critter(s)!") else "A fresh start — with permanent bonuses!",
		}, "♻️")
	end,
	QuestReady = function()
		Sound.Play("QuestComplete")
	end,
	QuestClaimed = function()
		Sound.Play("Reward")
		Effects.Confetti(20)
	end,
	TrapZap = function(payload)
		if payload.Position then
			Effects.Zap(payload.Position)
			Sound.Play("Trap", { Position = payload.Position })
		end
	end,
	Stunned = function(payload)
		Effects.Flash(Color3.fromRGB(110, 200, 255), payload.Duration or 1.5, 0.5)
	end,
	IntruderAlert = function()
		Sound.Play("StealAlarm", { Pitch = 1.2 })
	end,
	BaseClaimed = function()
		Sound.Sequence({ { "Reward", 0 }, { "QuestComplete", 0.15 } })
		Effects.Confetti(50)
	end,
	PackOpened = function()
		Sound.Play("CardFlip", { Pitch = 0.8 })
	end,
}

Net.On(Net.Events.Effect, function(name, payload)
	local handler = effectHandlers[name]
	if handler then
		handler(payload or {})
	end
end)

-- Welcome: open daily rewards if claimable once data arrives.
State.LoadedSignal:Once(function()
	task.wait(2.5)
	HUD.UpdateBadges()
	local daily = State.Data.Daily
	local today = math.floor(math.floor(workspace:GetServerTimeNow()) / 86400)
	if daily and daily.LastDay ~= today and (State.Data.Tutorial and State.Data.Tutorial.Done) then
		WindowManager.Open("Rewards")
	end
end)
if State.Loaded then
	applySettings(State.Data.Settings)
end
