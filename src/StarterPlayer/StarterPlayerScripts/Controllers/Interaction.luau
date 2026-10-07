--[[
	Interaction
	Creates every ProximityPrompt locally (so each player only sees prompts
	that make sense for them) and renders them with a custom card-styled UI
	that works with keyboard, gamepad and touch.

	Prompts only REQUEST actions; the server validates distance, ownership,
	cash, cooldowns, etc.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local RarityConfig = require(Config.RarityConfig)
local MutationConfig = require(Config.MutationConfig)
local Catalog = require(Shared.Catalog)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local UIKit = require(UI.UIKit)
local WindowManager = require(UI.WindowManager)
local Notifications = require(UI.Notifications)
local Sound = require(script.Parent.Sound)
local State = require(script.Parent.State)

local C = Theme.Colors
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Interaction = {}
Interaction.IsStealing = false

type PromptInfo = { Kind: string, Target: Instance, Prompt: ProximityPrompt }
local prompts: { [ProximityPrompt]: PromptInfo } = {}

---------------------------------------------------------------- custom prompt UI
local GAMEPAD_NAMES = {
	[Enum.KeyCode.ButtonX] = "X",
	[Enum.KeyCode.ButtonY] = "Y",
	[Enum.KeyCode.ButtonA] = "A",
	[Enum.KeyCode.ButtonB] = "B",
}

local function render(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	local adornee = prompt.Parent
	if not adornee then
		return
	end
	local info = prompts[prompt]
	local accent = if info and info.Kind == "Steal" then C.Danger elseif info and info.Kind == "Buy" then C.Cash else C.Accent

	local gui = UIKit.new("BillboardGui", {
		Name = "PromptUI",
		AlwaysOnTop = true,
		Size = UDim2.fromOffset(250, 72),
		StudsOffset = Vector3.new(0, 1.2, 0),
		Adornee = adornee,
		ResetOnSpawn = false,
		Active = true,
		LightInfluence = 0,
		Parent = playerGui,
	})
	local pill = UIKit.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.PanelDark,
		BackgroundTransparency = 0.08,
		Size = UDim2.new(1, 0, 0, 58),
		Parent = gui,
	})
	UIKit.Corner(pill, 16)
	UIKit.Stroke(pill, accent, 2.5)
	local key = UIKit.Panel(pill, { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(42, 42), Color = accent, Radius = 12 })
	local keyText = if inputType == Enum.ProximityPromptInputType.Gamepad then (GAMEPAD_NAMES[prompt.GamepadKeyCode] or "X")
		elseif inputType == Enum.ProximityPromptInputType.Touch then "👆"
		else prompt.KeyboardKeyCode.Name
	UIKit.Label(key, keyText, { Size = UDim2.fromScale(1, 1), TextSize = 22, Font = Theme.Fonts.Title, XAlign = Enum.TextXAlignment.Center, Color = C.PanelDark })
	UIKit.Label(pill, prompt.ActionText, { Position = UDim2.fromOffset(58, 6), Size = UDim2.new(1, -66, 0, 26), TextSize = 21, Font = Theme.Fonts.Title, Stroke = 2 })
	UIKit.Label(pill, prompt.ObjectText, { Position = UDim2.fromOffset(58, 31), Size = UDim2.new(1, -66, 0, 20), TextSize = 14, Color = C.SubText })
	local bar = UIKit.Panel(gui, { Position = UDim2.new(0, 12, 0, 62), Size = UDim2.new(1, -24, 0, 6), Color = C.PanelDark, Radius = 3, Visible = prompt.HoldDuration > 0 })
	local fill = UIKit.Panel(bar, { Size = UDim2.fromScale(0, 1), Color = accent, Radius = 3 })
	local scale = UIKit.new("UIScale", { Scale = 0.6, Parent = pill })
	UIKit.Tween(scale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)

	local connections = {}
	local holdTween: Tween? = nil
	table.insert(connections, prompt.PromptButtonHoldBegan:Connect(function()
		fill.Size = UDim2.fromScale(0, 1)
		holdTween = UIKit.Tween(fill, prompt.HoldDuration, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Linear)
	end))
	table.insert(connections, prompt.PromptButtonHoldEnded:Connect(function()
		if holdTween then
			holdTween:Cancel()
		end
		fill.Size = UDim2.fromScale(0, 1)
	end))
	table.insert(connections, prompt.Triggered:Connect(function()
		scale.Scale = 1.15
		UIKit.Tween(scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	end))
	-- Touch / click support for custom prompts.
	table.insert(connections, pill.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			prompt:InputHoldBegin()
		end
	end))
	table.insert(connections, pill.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			prompt:InputHoldEnd()
		end
	end))
	prompt.PromptHidden:Once(function()
		for _, c in connections do
			c:Disconnect()
		end
		gui:Destroy()
	end)
end

---------------------------------------------------------------- prompt factory
local function makePrompt(parent: Instance, kind: string, action: string, object: string, distance: number, hold: number?): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt_" .. kind
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.MaxActivationDistance = distance
	prompt.HoldDuration = hold or 0
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OneGlobally
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = parent
	prompts[prompt] = { Kind = kind, Target = parent, Prompt = prompt }
	prompt.Destroying:Connect(function()
		prompts[prompt] = nil
	end)
	return prompt
end

local function myPlot(): number
	return player:GetAttribute("PlotIndex") or 0
end

local function plotModel(index: number): Model?
	local world = workspace:FindFirstChild("World")
	local plots = world and world:FindFirstChild("Plots")
	return plots and plots:FindFirstChild("Plot" .. index) :: Model?
end

---------------------------------------------------------------- interactables
local function setupInteractable(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local kind = part:GetAttribute("Interact")
	local label = tostring(part:GetAttribute("Label") or "")
	if kind == "Window" then
		local prompt = makePrompt(part, "Window", "Open", label, 10)
		prompt.Triggered:Connect(function()
			local tab = part:GetAttribute("Tab")
			WindowManager.Open(tostring(part:GetAttribute("Window")), { Tab = if tab ~= "" then tab else nil })
		end)
	elseif kind == "LockBase" then
		local prompt = makePrompt(part, "Lock", "Lock Base", "Keeps thieves out", 10)
		prompt.Triggered:Connect(function()
			local response = Net.Request("LockBase")
			Notifications.Result(response)
		end)
	elseif kind == "ClaimBase" then
		local prompt = makePrompt(part, "Claim", "Claim Base", "This plot is yours!", 12)
		prompt.Triggered:Connect(function()
			local response = Net.Request("ClaimBase")
			Notifications.Result(response)
		end)
	end
end

local function updateInteractable(info: PromptInfo)
	local part = info.Target
	local plotIndex = part:GetAttribute("PlotIndex")
	local enabled = true
	if part:GetAttribute("OwnerOnly") and plotIndex and plotIndex ~= myPlot() then
		enabled = false
	end
	if info.Kind == "Claim" then
		local model = plotModel(plotIndex or 0)
		enabled = enabled and model ~= nil and model:GetAttribute("Claimed") == false
	end
	info.Prompt.Enabled = enabled
end

---------------------------------------------------------------- conveyor items
local function describe(model: Instance): string
	local def = Catalog.Get(model:GetAttribute("CollectibleId"))
	if not def then
		return "Critter"
	end
	local mutation = model:GetAttribute("Mutation")
	local m = MutationConfig.Mutations[mutation or "Normal"]
	local prefix = if m and m.Tier > 0 then (m.Icon .. " " .. mutation .. " ") else ""
	return prefix .. def.Name .. " • " .. RarityConfig.Rarities[def.Rarity].Name
end

local function setupConveyorItem(model: Instance)
	local root = (model :: Model).PrimaryPart or model:FindFirstChild("Root")
	if not root then
		return
	end
	local price = model:GetAttribute("Price") or 0
	local prompt = makePrompt(root, "Buy", "Buy " .. Format.Cash(price), describe(model), 13)
	prompt.Triggered:Connect(function()
		local required = model:GetAttribute("RequiredRebirths") or 0
		if (State.Data.Rebirths or 0) < required then
			Notifications.Toast("Requires Rebirth " .. required .. " to buy", "Error")
			return
		end
		local response = Net.Request("BuyConveyor", model:GetAttribute("Uid"))
		if not response.Ok then
			Notifications.Toast(response.Message or "Can't buy that", "Error")
		end
	end)
end

local function updateConveyorPrompt(info: PromptInfo)
	local model = info.Target.Parent
	if not model then
		return
	end
	local price = model:GetAttribute("Price") or 0
	local required = model:GetAttribute("RequiredRebirths") or 0
	if (State.Data.Rebirths or 0) < required then
		info.Prompt.ActionText = "🔒 Rebirth " .. required
	elseif (State.Data.Cash or 0) < price then
		info.Prompt.ActionText = "Need " .. Format.Cash(price)
	else
		info.Prompt.ActionText = "Buy " .. Format.Cash(price)
	end
end

---------------------------------------------------------------- base creatures
local function setupCreature(model: Instance)
	local root = (model :: Model).PrimaryPart or model:FindFirstChild("Root")
	if not root then
		return
	end
	local ownerId = model:GetAttribute("OwnerUserId")
	if ownerId == player.UserId then
		local prompt = makePrompt(root, "Manage", "Manage", describe(model), 8)
		prompt.Triggered:Connect(function()
			WindowManager.Open("Collection", { Uid = model:GetAttribute("Uid") })
		end)
	else
		local prompt = makePrompt(root, "Steal", "Steal", describe(model), 11, 0.35)
		prompt.Triggered:Connect(function()
			local response = Net.Request("StartSteal", ownerId, model:GetAttribute("Uid"))
			if not response.Ok then
				Notifications.Toast(response.Message or "Can't steal that", "Error")
			end
		end)
	end
end

local function updateStealPrompt(info: PromptInfo)
	local model = info.Target.Parent :: Instance?
	if not model then
		return
	end
	local plot = plotModel(model:GetAttribute("PlotIndex") or 0)
	local status = plot and plot:GetAttribute("Status") or "Open"
	local travelEnd = (model:GetAttribute("TravelStart") or 0) + (model:GetAttribute("TravelDuration") or 0)
	local traveling = workspace:GetServerTimeNow() < travelEnd
	local available = status == "Open" and not model:GetAttribute("BeingStolen") and not traveling and not Interaction.IsStealing
	info.Prompt.Enabled = available
end

---------------------------------------------------------------- start
local function watchTag(tag: string, setup: (Instance) -> ())
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst)
		task.defer(setup, inst)
	end)
	for _, inst in CollectionService:GetTagged(tag) do
		task.spawn(setup, inst)
	end
end

function Interaction.Start()
	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style == Enum.ProximityPromptStyle.Custom and prompts[prompt] then
			render(prompt, inputType)
			Sound.Play("UIHover", { Pitch = 0.8, MinInterval = 0.15 })
		end
	end)
	watchTag("Interactable", setupInteractable)
	watchTag("ConveyorItem", setupConveyorItem)
	watchTag("BaseCreature", setupCreature)

	task.spawn(function()
		while true do
			task.wait(0.4)
			for _, info in prompts do
				if info.Prompt.Parent then
					if info.Kind == "Steal" then
						updateStealPrompt(info)
					elseif info.Kind == "Buy" then
						updateConveyorPrompt(info)
					elseif info.Kind == "Window" or info.Kind == "Lock" or info.Kind == "Claim" then
						updateInteractable(info)
					end
				end
			end
		end
	end)
end

return Interaction
