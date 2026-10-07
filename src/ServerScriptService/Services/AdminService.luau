--[[
	AdminService
	Server-side, permission-protected admin commands. Admins are configured in
	Modules/AdminConfig (server-only). Commands can be typed in chat ("/cmd")
	or in the in-game Admin Console (visible only to admins). Every command is
	re-checked on the server and logged.
]]

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local MutationConfig = require(Config.MutationConfig)
local TraitConfig = require(Config.TraitConfig)
local EventConfig = require(Config.EventConfig)
local BoostConfig = require(Config.BoostConfig)
local MapConfig = require(Config.MapConfig)
local Catalog = require(Shared.Catalog)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)

local Modules = script.Parent.Parent.Modules
local Registry = require(Modules.Registry)
local AdminConfig = require(Modules.AdminConfig)
local Log = require(Modules.Log)

local AdminService = {}

local admins: { [Player]: boolean } = {}

type CommandFn = (admin: Player, args: { string }) -> { string }
type Command = { Usage: string, Description: string, Run: CommandFn }

local commands: { [string]: Command } = {}

local function isAdminUser(player: Player): boolean
	if table.find(AdminConfig.UserIds, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User and game.CreatorId == player.UserId and game.CreatorId ~= 0 then
		return true
	end
	if RunService:IsStudio() and AdminConfig.StudioEveryoneIsAdmin then
		return true
	end
	if AdminConfig.Group.Id ~= 0 then
		local ok, groups = pcall(GroupService.GetGroupsAsync, GroupService, player.UserId)
		if ok and type(groups) == "table" then
			for _, group in groups do
				if group.Id == AdminConfig.Group.Id and (group.Rank or 0) >= AdminConfig.Group.MinRank then
					return true
				end
			end
		end
	end
	return false
end

-- "me", "all", or a case-insensitive prefix of a Name / DisplayName.
local function findPlayers(admin: Player, query: string?): { Player }
	if not query or query == "" or query == "me" then
		return { admin }
	end
	local q = string.lower(query)
	if q == "all" then
		return Players:GetPlayers()
	end
	if q == "others" then
		local list = {}
		for _, p in Players:GetPlayers() do
			if p ~= admin then
				table.insert(list, p)
			end
		end
		return list
	end
	for _, p in Players:GetPlayers() do
		if string.lower(p.Name) == q or string.lower(p.DisplayName) == q then
			return { p }
		end
	end
	for _, p in Players:GetPlayers() do
		if string.sub(string.lower(p.Name), 1, #q) == q or string.sub(string.lower(p.DisplayName), 1, #q) == q then
			return { p }
		end
	end
	return {}
end

local function parseNumber(text: string?): number?
	if not text then
		return nil
	end
	local n = tonumber(text)
	if n then
		return n
	end
	-- Accept 1.5k / 2m / 3b / 4t
	local num, suffix = string.match(string.lower(text), "^([%d%.]+)([kmbt])$")
	local mult = { k = 1e3, m = 1e6, b = 1e9, t = 1e12 }
	if num and suffix and tonumber(num) then
		return (tonumber(num) :: number) * mult[suffix]
	end
	return nil
end

local function register(name: string, usage: string, description: string, run: CommandFn)
	commands[name] = { Usage = usage, Description = description, Run = run }
end

---------------------------------------------------------------- commands
register("help", "/help", "List commands", function()
	local lines = {}
	local names = {}
	for name in commands do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in names do
		local c = commands[name]
		table.insert(lines, c.Usage .. " — " .. c.Description)
	end
	return lines
end)

register("givecash", "/givecash <player|me|all> <amount>", "Give cash (supports 1.5m, 2b...)", function(admin, args)
	local amount = parseNumber(args[2])
	if not amount or amount <= 0 then
		return { "Invalid amount" }
	end
	local lines = {}
	for _, p in findPlayers(admin, args[1]) do
		Registry.EconomyService:AddCash(p, amount, "Admin")
		table.insert(lines, "Gave " .. Format.Cash(amount) .. " to " .. p.Name)
	end
	return if #lines > 0 then lines else { "No player matched" }
end)

register("givetokens", "/givetokens <player> <amount>", "Give tokens", function(admin, args)
	local amount = parseNumber(args[2])
	if not amount or amount <= 0 then
		return { "Invalid amount" }
	end
	local lines = {}
	for _, p in findPlayers(admin, args[1]) do
		Registry.EconomyService:AddTokens(p, amount)
		table.insert(lines, "Gave " .. amount .. " tokens to " .. p.Name)
	end
	return lines
end)

register("giveitem", "/giveitem <player> <collectibleId> [mutation] [trait]", "Give a collectible", function(admin, args)
	local id = args[2] and string.lower(args[2])
	if not Catalog.Get(id) then
		return { "Unknown collectible id. Example ids: emberpup, solarion, galaxitty" }
	end
	local mutation = args[3] or "Normal"
	if not MutationConfig.IsValid(mutation) then
		return { "Unknown mutation. Options: " .. table.concat(MutationConfig.Order, ", ") }
	end
	local trait = args[4]
	if trait and not TraitConfig.Traits[trait] then
		return { "Unknown trait. Options: " .. table.concat(TraitConfig.Order, ", ") }
	end
	local lines = {}
	for _, p in findPlayers(admin, args[1]) do
		local item, err = Registry.CollectibleService:Grant(p, id :: string, { Mutation = mutation, Trait = trait, Source = "Admin" })
		table.insert(lines, if item then ("Gave " .. id .. " to " .. p.Name) else ("Failed for " .. p.Name .. ": " .. tostring(err)))
	end
	return lines
end)

register("spawn", "/spawn <collectibleId> [mutation] [trait] [Main|Elite]", "Spawn a collectible on a conveyor", function(_admin, args)
	local id = args[1] and string.lower(args[1])
	if not Catalog.Get(id) then
		return { "Unknown collectible id" }
	end
	local mutation = args[2] or "Normal"
	if not MutationConfig.IsValid(mutation) then
		return { "Unknown mutation" }
	end
	local trait = if args[3] and TraitConfig.Traits[args[3]] then args[3] else nil
	local conveyor = if args[4] == "Elite" then "Elite" else "Main"
	local uid = Registry.ConveyorService:AdminSpawn(id :: string, mutation, trait, conveyor)
	return { if uid then ("Spawned " .. mutation .. " " .. tostring(id) .. " on " .. conveyor) else "Spawn failed" }
end)

register("event", "/event <start|stop|list|clear> [EventId] [minutes]", "Control events", function(_admin, args)
	local action = args[1] and string.lower(args[1]) or "list"
	if action == "list" then
		local lines = { "Events:" }
		for id, def in EventConfig.Events do
			table.insert(lines, string.format("%s %s%s", def.Icon, id, if Registry.EventService:IsActive(id) then " (ACTIVE)" else ""))
		end
		return lines
	elseif action == "start" then
		local _, msg = Registry.EventService:StartEvent(args[2] or "", parseNumber(args[3]) or 15)
		return { msg }
	elseif action == "stop" then
		local _, msg = Registry.EventService:StopEvent(args[2] or "")
		return { msg }
	elseif action == "clear" then
		Registry.EventService:ClearOverrides()
		return { "Cleared admin event overrides" }
	end
	return { "Usage: /event <start|stop|list|clear> [EventId] [minutes]" }
end)

register("setluck", "/setluck <multiplier> [minutes]", "Server conveyor luck multiplier", function(_admin, args)
	local mult = parseNumber(args[1])
	if not mult or mult <= 0 or mult > 100 then
		return { "Multiplier must be between 0 and 100" }
	end
	local minutes = parseNumber(args[2]) or 15
	Registry.BoostService:SetAdminMultiplier("Luck", mult, minutes * 60)
	Registry.NetService:Announce(string.format("🍀 An admin set server luck to x%s for %d minutes!", tostring(mult), minutes), Color3.fromRGB(90, 220, 120), "🍀")
	return { "Server luck x" .. mult .. " for " .. minutes .. "m" }
end)

register("setincome", "/setincome <multiplier> [minutes]", "Server income multiplier", function(_admin, args)
	local mult = parseNumber(args[1])
	if not mult or mult <= 0 or mult > 100 then
		return { "Multiplier must be between 0 and 100" }
	end
	local minutes = parseNumber(args[2]) or 15
	Registry.BoostService:SetAdminMultiplier("Income", mult, minutes * 60)
	Registry.NetService:Announce(string.format("💸 An admin set server income to x%s for %d minutes!", tostring(mult), minutes), Color3.fromRGB(90, 220, 120), "💸")
	return { "Server income x" .. mult .. " for " .. minutes .. "m" }
end)

register("announce", "/announce <message>", "Server-wide announcement (filtered)", function(admin, args)
	local text = table.concat(args, " ")
	if text == "" then
		return { "Empty message" }
	end
	local ok, filtered = pcall(function()
		local result = TextService:FilterStringAsync(text, admin.UserId)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		return { "Text filtering failed: " .. tostring(filtered) }
	end
	Registry.NetService:Announce("📢 " .. filtered, Color3.fromRGB(255, 220, 90), "📢")
	return { "Announced" }
end)

register("kick", "/kick <player> [reason]", "Kick a player", function(admin, args)
	local targets = findPlayers(admin, args[1])
	if #targets ~= 1 or targets[1] == admin then
		return { "Specify one other player" }
	end
	local reason = table.concat(args, " ", 2)
	targets[1]:Kick(if reason ~= "" then reason else "Kicked by an admin")
	return { "Kicked " .. targets[1].Name }
end)

register("teleport", "/teleport <player> [targetPlayer|hub|elite|base]", "Teleport a player", function(admin, args)
	local players = findPlayers(admin, args[1])
	local destination = args[2] and string.lower(args[2]) or nil
	local lines = {}
	for _, p in players do
		if destination == nil or destination == "base" then
			Registry.BaseService:TeleportHome(p)
		elseif destination == "hub" then
			Registry.AntiExploitService:Teleport(p, CFrame.new(MapConfig.Hub.TeleportPoint))
		elseif destination == "elite" then
			Registry.AntiExploitService:Teleport(p, CFrame.new(MapConfig.EliteArea.GateCenter + Vector3.new(20, 4, 0)))
		else
			local target = findPlayers(admin, destination)[1]
			local root = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root then
				return { "Target not found" }
			end
			Registry.AntiExploitService:Teleport(p, root.CFrame * CFrame.new(0, 0, 4))
		end
		table.insert(lines, "Teleported " .. p.Name)
	end
	return lines
end)

register("tp", "/tp <player> [target]", "Alias of /teleport", function(admin, args)
	return commands.teleport.Run(admin, args)
end)

register("boost", "/boost <player> <Income|Luck|Speed|Protection> <seconds>", "Give a personal boost", function(admin, args)
	local name = args[2]
	local seconds = parseNumber(args[3]) or 600
	if not name or not BoostConfig.Personal[name] then
		return { "Unknown boost" }
	end
	local lines = {}
	for _, p in findPlayers(admin, args[1]) do
		Registry.BoostService:Add(p, name, seconds)
		table.insert(lines, "Boosted " .. p.Name)
	end
	return lines
end)

register("setrebirths", "/setrebirths <player> <n>", "Set rebirth count", function(admin, args)
	local n = parseNumber(args[2])
	if not n or n < 0 then
		return { "Invalid number" }
	end
	local lines = {}
	for _, p in findPlayers(admin, args[1]) do
		local data = Registry.DataService:Get(p)
		if data then
			data.Rebirths = math.floor(n)
			Registry.DataService:MarkDirty(p, "Rebirths")
			p:SetAttribute("Rebirths", data.Rebirths)
			Registry.EconomyService:Refresh(p)
			table.insert(lines, p.Name .. " rebirths = " .. data.Rebirths)
		end
	end
	return lines
end)

register("logs", "/logs [category] [count]", "Show recent server logs", function(_admin, args)
	local count = parseNumber(args[2]) or 20
	local category = if args[1] and args[1] ~= "all" then args[1] else nil
	local lines = Log.Recent(math.clamp(count, 1, 80), category)
	return if #lines > 0 then lines else { "No log entries" }
end)

register("report", "/report <player>", "Anti-exploit suspicion report", function(admin, args)
	local lines = {}
	for _, p in findPlayers(admin, args[1] or "all") do
		table.insert(lines, Registry.AntiExploitService:GetReport(p))
	end
	return lines
end)

register("save", "/save <player>", "Force-save player data", function(admin, args)
	local lines = {}
	for _, p in findPlayers(admin, args[1]) do
		table.insert(lines, p.Name .. ": " .. (if Registry.DataService:SaveAsync(p, false) then "saved" else "SAVE FAILED"))
	end
	return lines
end)

register("resetcooldowns", "/resetcooldowns", "Clear all steal cooldowns", function()
	Registry.StealService:ResetCooldowns()
	return { "Steal cooldowns cleared" }
end)

register("resetdata", "/resetdata <player>", "[Studio] Wipe a player's data", function(admin, args)
	local lines = {}
	for _, p in findPlayers(admin, args[1]) do
		Registry.BaseService:ReleasePlot(p)
		Registry.DataService:ResetData(p)
		Registry.BaseService:AssignPlot(p)
		Registry.EconomyService:Refresh(p)
		table.insert(lines, "Reset " .. p.Name)
	end
	return lines
end)

register("testproduct", "/testproduct <ProductKey>", "[Studio] Simulate a developer product purchase", function(admin, args)
	local ok, msg = Registry.MonetizationService:SimulateProduct(admin, args[1] or "")
	return { (if ok then "Granted: " else "Failed: ") .. msg }
end)

register("testpass", "/testpass <PassKey> [off]", "[Studio] Simulate owning a gamepass", function(admin, args)
	local ok, msg = Registry.MonetizationService:SimulatePass(admin, args[1] or "", args[2] ~= "off")
	return { (if ok then "" else "Failed: ") .. msg }
end)

register("runtests", "/runtests", "Run the in-Studio integration test suite", function(admin)
	local runner = script.Parent.Parent:FindFirstChild("Tests")
	local module = runner and runner:FindFirstChild("TestRunner")
	if not module then
		return { "TestRunner not found" }
	end
	return (require(module :: ModuleScript) :: any).Run(admin)
end)

---------------------------------------------------------------- execution
function AdminService:IsAdmin(player: Player): boolean
	return admins[player] == true
end

function AdminService:Execute(player: Player, text: any): (boolean, string?, any?)
	if not self:IsAdmin(player) then
		Registry.AntiExploitService:Flag(player, "InvalidArgs", "non-admin used admin command")
		return false, "You are not an admin"
	end
	if type(text) ~= "string" or #text > 500 then
		return false, "Invalid command"
	end
	local trimmed = string.gsub(text, "^%s*/?", "")
	local parts = string.split(trimmed, " ")
	local args = {}
	for _, p in parts do
		if p ~= "" then
			table.insert(args, p)
		end
	end
	local name = table.remove(args, 1)
	local command = name and commands[string.lower(name)]
	if not command then
		return false, "Unknown command. Type /help"
	end
	local lowerName = string.lower(name :: string)
	if AdminConfig.StudioOnlyCommands[lowerName] and not RunService:IsStudio() then
		return false, "That command only works in Studio"
	end
	Log.Info("Admin", player.Name .. " ran: " .. text, player.UserId)
	local ok, result = pcall(command.Run, player, args)
	if not ok then
		Log.Error("Admin", "command failed: " .. tostring(result), player.UserId)
		return false, "Command error: " .. tostring(result)
	end
	return true, nil, result
end

function AdminService:Init() end

function AdminService:Start() end

function AdminService:OnPlayerLoaded(player: Player)
	admins[player] = isAdminUser(player)
	player:SetAttribute("IsAdmin", admins[player])
	if admins[player] then
		player.Chatted:Connect(function(message)
			if string.sub(message, 1, 1) == "/" then
				local name = string.match(message, "^/(%w+)")
				if name and commands[string.lower(name)] then
					local ok, msg, lines = self:Execute(player, message)
					Registry.NetService:Fire(player, Net.Events.AdminOutput, if ok then lines else { msg })
				end
			end
		end)
	end
end

Players.PlayerRemoving:Connect(function(player)
	admins[player] = nil
end)

return AdminService
