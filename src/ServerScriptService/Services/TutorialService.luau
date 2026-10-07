--[[
	TutorialService
	Seven short onboarding steps, advanced by real gameplay actions:
		1 Claim your base      (Claim)
		2 Buy a critter        (Buy)
		3 Watch it walk home   (Arrive)
		4 Collect your cash    (Collect)
		5 Upgrade your base    (Upgrade)
		6 Try stealing         (StealAttempt)   — skippable (needs other players)
		7 Lock your base       (Lock)
	Any step can be skipped; the whole tutorial can be skipped too.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RewardConfig = require(Shared.Config.RewardConfig)

local Modules = script.Parent.Parent.Modules
local Registry = require(Modules.Registry)
local ActionBus = require(Modules.ActionBus)

local TutorialService = {}

TutorialService.Steps = {
	{ Key = "Claim", Action = "Claim" },
	{ Key = "Buy", Action = "Buy" },
	{ Key = "Arrive", Action = "Arrive" },
	{ Key = "Collect", Action = "Collect" },
	{ Key = "Upgrade", Action = "Upgrade" },
	{ Key = "Steal", Action = "StealAttempt" },
	{ Key = "Lock", Action = "Lock" },
}

function TutorialService:Init() end

function TutorialService:Start()
	ActionBus.Listen(function(player, action)
		local data = Registry.DataService:Get(player)
		if not data or data.Tutorial.Done then
			return
		end
		local step = self.Steps[data.Tutorial.Step]
		if step and step.Action == action then
			self:_advance(player, true)
		end
	end)
end

function TutorialService:_advance(player: Player, earned: boolean)
	local data = Registry.DataService:Get(player)
	if not data or data.Tutorial.Done then
		return
	end
	local step = self.Steps[data.Tutorial.Step]
	if earned and step then
		local rewards = RewardConfig.Tutorial.StepRewards[step.Key]
		if rewards then
			Registry.RewardService:Grant(player, rewards, "Tutorial")
		end
	end
	data.Tutorial.Step += 1
	if data.Tutorial.Step > #self.Steps then
		data.Tutorial.Done = true
		Registry.RewardService:GrantWithPopup(player, RewardConfig.Tutorial.Completion, "Tutorial", "Tutorial complete!", "🎓")
	end
	Registry.DataService:MarkDirty(player, "Tutorial")
	Registry.NetService:Effect(player, "TutorialStep", { Step = data.Tutorial.Step, Done = data.Tutorial.Done })
end

function TutorialService:Skip(player: Player, scope: any): (boolean, string?)
	local data = Registry.DataService:Get(player)
	if not data or data.Tutorial.Done then
		return false, nil
	end
	if scope == "All" then
		data.Tutorial.Step = #self.Steps + 1
		data.Tutorial.Done = true
		Registry.DataService:MarkDirty(player, "Tutorial")
		return true, "Tutorial skipped"
	end
	self:_advance(player, false)
	return true, nil
end

function TutorialService:OnPlayerLoaded(player: Player)
	local data = Registry.DataService:Get(player)
	if not data or data.Tutorial.Done then
		return
	end
	-- Returning players who already own collectibles skip the first steps.
	if data.Tutorial.Step <= 3 and next(data.Inventory) ~= nil then
		data.Tutorial.Step = math.max(data.Tutorial.Step, 4)
		Registry.DataService:MarkDirty(player, "Tutorial")
	end
end

return TutorialService
