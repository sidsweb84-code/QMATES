--[[
	PlayerService
	Join / leave orchestration and character management.

	Join pipeline (ordered, each step isolated with pcall):
		load data -> gamepasses -> collectibles -> base -> economy (offline cash)
		-> quests -> rewards -> cosmetics -> leaderboards -> tutorial -> spawn
	Leave pipeline: theft/trade cancellation and base release run as
	DataService BeforeRelease hooks, then data is saved with the lock released.

	Walk speed is computed here from: base speed, Fast Walker pass, Speed
	boost, carry penalty and stuns. Clients never set their own speed.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local GameConfig = require(Config.GameConfig)
local BoostConfig = require(Config.BoostConfig)
local MonetizationConfig = require(Config.MonetizationConfig)

local Modules = script.Parent.Parent.Modules
local Registry = require(Modules.Registry)
local Log = require(Modules.Log)

local PlayerService = {}

type Movement = { Carry: number, StunnedUntil: number }
local movement: { [Player]: Movement } = {}
local ready: { [Player]: boolean } = {}

local JOIN_STEPS = {
	"MonetizationService",
	"CollectibleService",
	"BaseService",
	"EconomyService",
	"QuestService",
	"RewardService",
	"CosmeticService",
	"LeaderboardService",
	"TutorialService",
	"AdminService",
}

local LEAVE_STEPS = {
	"TradeService",
	"StealService",
	"EconomyService",
	"LeaderboardService",
	"BaseService",
}

-- Uses LoadCharacterAsync where available, falling back to LoadCharacter.
local function loadCharacter(player: Player)
	local ok = pcall(function()
		(player :: any):LoadCharacterAsync()
	end)
	if not ok and player.Parent then
		pcall(function()
			(player :: any).LoadCharacter(player)
		end)
	end
end

local function getMovement(player: Player): Movement
	local m = movement[player]
	if not m then
		m = { Carry = 1, StunnedUntil = 0 }
		movement[player] = m
	end
	return m
end

function PlayerService:Init()
	Players.CharacterAutoLoads = false
	-- Leave hooks run before the final save (also during server shutdown).
	table.insert(Registry.DataService.BeforeRelease, function(player: Player)
		for _, name in LEAVE_STEPS do
			local service = Registry[name]
			if service and service.OnPlayerRemoving then
				local ok, err = pcall(service.OnPlayerRemoving, service, player)
				if not ok then
					Log.Error("Player", name .. ".OnPlayerRemoving failed: " .. tostring(err), player.UserId)
				end
			end
		end
	end)
end

function PlayerService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:_onPlayerAdded(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(self._onPlayerAdded, self, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		ready[player] = nil
		task.spawn(function()
			Registry.DataService:ReleaseAsync(player)
			movement[player] = nil
		end)
	end)
	-- Keep speeds in sync with boosts expiring etc.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				if ready[player] then
					self:UpdateMovement(player)
				end
			end
		end
	end)
end

function PlayerService:_onPlayerAdded(player: Player)
	local profile = Registry.DataService:LoadAsync(player)
	if not profile then
		if player.Parent then
			player:Kick("We couldn't load your data (Roblox data servers may be busy). Please rejoin in a minute.")
		end
		return
	end
	if player.Parent == nil then
		Registry.DataService:ReleaseAsync(player)
		return
	end
	for _, name in JOIN_STEPS do
		local service = Registry[name]
		if service and service.OnPlayerLoaded then
			local ok, err = pcall(service.OnPlayerLoaded, service, player)
			if not ok then
				Log.Error("Player", name .. ".OnPlayerLoaded failed: " .. tostring(err), player.UserId)
			end
		end
		if player.Parent == nil then
			return -- left or was kicked (e.g. no free base) during joining
		end
	end
	ready[player] = true
	player:SetAttribute("DataLoaded", true)
	player.CharacterAdded:Connect(function(character)
		self:_onCharacterAdded(player, character)
	end)
	loadCharacter(player)
end

function PlayerService:IsReady(player: Player): boolean
	return ready[player] == true
end

function PlayerService:_onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not humanoid or not root then
		return
	end
	Registry.AntiExploitService:MarkTeleport(player)
	local plot = Registry.BaseService:GetPlot(player)
	if plot then
		task.defer(function()
			if character.Parent then
				Registry.AntiExploitService:Teleport(player, Registry.BaseService:SpawnCFrame(plot))
			end
		end)
	end
	self:UpdateMovement(player)
	Registry.CosmeticService:ApplyToCharacter(player, character)
	humanoid.Died:Connect(function()
		task.delay(Players.RespawnTime, function()
			if player.Parent and player.Character == character then
				loadCharacter(player)
			end
		end)
	end)
end

---------------------------------------------------------------- movement
function PlayerService:SetCarryMultiplier(player: Player, multiplier: number)
	getMovement(player).Carry = multiplier
	self:UpdateMovement(player)
end

function PlayerService:Stun(player: Player, seconds: number)
	local m = getMovement(player)
	m.StunnedUntil = math.max(m.StunnedUntil, os.clock() + seconds)
	self:UpdateMovement(player)
	Registry.NetService:Effect(player, "Stunned", { Duration = seconds })
	task.delay(seconds + 0.05, function()
		if player.Parent then
			self:UpdateMovement(player)
		end
	end)
end

function PlayerService:IsStunned(player: Player): boolean
	return getMovement(player).StunnedUntil > os.clock()
end

function PlayerService:ComputeWalkSpeed(player: Player): number
	local m = getMovement(player)
	if m.StunnedUntil > os.clock() then
		return 0
	end
	local speed = GameConfig.Movement.BaseWalkSpeed
	local carrying = m.Carry < 1 or Registry.StealService:IsThief(player)
	if not carrying then
		if Registry.MonetizationService:OwnsPass(player, "FastWalk") then
			speed *= MonetizationConfig.Gamepasses.FastWalk.Perks.SpeedMultiplier
		end
		if Registry.BoostService:IsActive(player, "Speed") then
			speed *= BoostConfig.Personal.Speed.Multiplier
		end
	end
	return speed * m.Carry
end

function PlayerService:UpdateMovement(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local speed = self:ComputeWalkSpeed(player)
	if math.abs(humanoid.WalkSpeed - speed) > 0.01 then
		humanoid.WalkSpeed = speed
	end
	local jump = if self:IsStunned(player) then 0 else GameConfig.Movement.BaseJumpPower
	if humanoid.UseJumpPower and humanoid.JumpPower ~= jump then
		humanoid.JumpPower = jump
	end
end

return PlayerService
