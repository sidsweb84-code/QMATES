--[[
	TradeService
	Optional player-to-player trading (also used for gifting: offer items on
	one side only). Fully server-authoritative:
	- Both players must accept the request, then both press Ready.
	- A short countdown follows; ANY change resets both Ready flags.
	- At execution everything is re-validated, then CollectibleService:Swap
	  moves the exact item records atomically. Items can't be duplicated.
	- Favourited (locked) items, items being stolen or travelling can't be traded.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)

local Modules = script.Parent.Parent.Modules
local Registry = require(Modules.Registry)
local Log = require(Modules.Log)

local TradeService = {}

type Trade = {
	A: Player,
	B: Player,
	Offers: { [Player]: { string } },
	Ready: { [Player]: boolean },
	CountdownEndsAt: number?,
}

local trades: { [Player]: Trade } = {}
local requests: { [Player]: { From: Player, At: number } } = {}
local lastRequest: { [Player]: number } = {}

local function partnerOf(trade: Trade, player: Player): Player
	return if trade.A == player then trade.B else trade.A
end

local function publicItems(player: Player, uids: { string }): { any }
	local data = Registry.DataService:Get(player)
	local list = {}
	if data then
		for _, uid in uids do
			local item = data.Inventory[uid]
			if item then
				table.insert(list, { Uid = item.Uid, Id = item.Id, Mutation = item.Mutation, Trait = item.Trait, Level = item.Level, Serial = item.Serial })
			end
		end
	end
	return list
end

function TradeService:_broadcast(trade: Trade)
	for _, player in { trade.A, trade.B } do
		local partner = partnerOf(trade, player)
		Registry.NetService:Fire(player, Net.Events.Trade, {
			State = "Update",
			Partner = { Name = partner.DisplayName, UserId = partner.UserId },
			MyOffer = publicItems(player, trade.Offers[player]),
			TheirOffer = publicItems(partner, trade.Offers[partner]),
			MyReady = trade.Ready[player] == true,
			TheirReady = trade.Ready[partner] == true,
			CountdownEndsAt = if trade.CountdownEndsAt then workspace:GetServerTimeNow() + (trade.CountdownEndsAt - os.clock()) else nil,
		})
	end
end

function TradeService:Init() end

function TradeService:Start()
	RunService.Heartbeat:Connect(function()
		for player, trade in trades do
			if trade.A == player and trade.CountdownEndsAt and os.clock() >= trade.CountdownEndsAt then
				trade.CountdownEndsAt = nil
				task.spawn(self._execute, self, trade)
			end
		end
	end)
end

---------------------------------------------------------------- queries
function TradeService:IsTrading(player: Player): boolean
	return trades[player] ~= nil
end

function TradeService:IsItemInTrade(player: Player, uid: string): boolean
	local trade = trades[player]
	return trade ~= nil and table.find(trade.Offers[player], uid) ~= nil
end

---------------------------------------------------------------- requests
function TradeService:Request(player: Player, targetUserId: any): (boolean, string?)
	if not GameConfig.Trading.Enabled then
		return false, "Trading is disabled"
	end
	if type(targetUserId) ~= "number" then
		return false, "Invalid player"
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == player or not Registry.DataService:IsLoaded(target) then
		return false, "That player isn't available"
	end
	if trades[player] or trades[target] then
		return false, "One of you is already trading"
	end
	if (lastRequest[player] or 0) + GameConfig.Trading.RequestCooldown > os.clock() then
		return false, "Wait a moment before sending another request"
	end
	if player.AccountAge < GameConfig.Trading.MinAccountAgeDays and not RunService:IsStudio() then
		return false, string.format("Your account must be %d days old to trade", GameConfig.Trading.MinAccountAgeDays)
	end
	lastRequest[player] = os.clock()
	requests[target] = { From = player, At = os.clock() }
	Registry.NetService:Fire(target, Net.Events.Trade, { State = "Request", From = player.DisplayName, FromUserId = player.UserId })
	return true, "Trade request sent to " .. target.DisplayName
end

function TradeService:Respond(player: Player, fromUserId: any, accept: any): (boolean, string?)
	local request = requests[player]
	if not request or request.From.UserId ~= fromUserId then
		return false, "That request expired"
	end
	requests[player] = nil
	local from = request.From
	if os.clock() - request.At > GameConfig.Trading.RequestTimeout or from.Parent == nil then
		return false, "That request expired"
	end
	if accept ~= true then
		Registry.NetService:Notify(from, player.DisplayName .. " declined your trade.", "Info")
		return true, nil
	end
	if trades[player] or trades[from] then
		return false, "One of you is already trading"
	end
	if player.AccountAge < GameConfig.Trading.MinAccountAgeDays and not RunService:IsStudio() then
		return false, string.format("Your account must be %d days old to trade", GameConfig.Trading.MinAccountAgeDays)
	end
	local trade: Trade = { A = from, B = player, Offers = { [from] = {}, [player] = {} }, Ready = {}, CountdownEndsAt = nil }
	trades[from] = trade
	trades[player] = trade
	self:_broadcast(trade)
	return true, nil
end

---------------------------------------------------------------- editing
function TradeService:SetItems(player: Player, uids: any): (boolean, string?)
	local trade = trades[player]
	if not trade then
		return false, "You're not trading"
	end
	if type(uids) ~= "table" or #uids > GameConfig.Trading.MaxItemsPerSide then
		return false, "Too many items"
	end
	local data = Registry.DataService:Get(player)
	if not data then
		return false, "Not loaded"
	end
	local clean = {}
	local seen = {}
	for _, uid in uids do
		if type(uid) ~= "string" or seen[uid] then
			Registry.AntiExploitService:Flag(player, "InvalidArgs", "TradeSetItems")
			return false, "Invalid items"
		end
		seen[uid] = true
		local item = data.Inventory[uid]
		if not item then
			return false, "You don't own that"
		end
		if item.Locked then
			return false, "Unfavourite a critter before trading it"
		end
		if Registry.StealService:IsItemBeingStolen(player, uid) or Registry.BaseService:IsInTransit(player, uid) then
			return false, "That critter is busy"
		end
		table.insert(clean, uid)
	end
	trade.Offers[player] = clean
	trade.Ready = {}
	trade.CountdownEndsAt = nil
	self:_broadcast(trade)
	return true, nil
end

function TradeService:SetReady(player: Player, ready: any): (boolean, string?)
	local trade = trades[player]
	if not trade then
		return false, "You're not trading"
	end
	trade.Ready[player] = ready == true
	if trade.Ready[trade.A] and trade.Ready[trade.B] then
		if #trade.Offers[trade.A] == 0 and #trade.Offers[trade.B] == 0 then
			trade.Ready = {}
			self:_broadcast(trade)
			return false, "Add at least one critter"
		end
		trade.CountdownEndsAt = os.clock() + GameConfig.Trading.ConfirmCountdown
	else
		trade.CountdownEndsAt = nil
	end
	self:_broadcast(trade)
	return true, nil
end

function TradeService:Cancel(player: Player, reason: string?): (boolean, string?)
	local trade = trades[player]
	if not trade then
		requests[player] = nil
		return false, nil
	end
	trades[trade.A] = nil
	trades[trade.B] = nil
	for _, p in { trade.A, trade.B } do
		if p.Parent then
			Registry.NetService:Fire(p, Net.Events.Trade, { State = "Closed", Reason = reason or (player.DisplayName .. " cancelled the trade") })
		end
	end
	return true, nil
end

---------------------------------------------------------------- execution
function TradeService:_execute(trade: Trade)
	if trades[trade.A] ~= trade or trades[trade.B] ~= trade then
		return
	end
	if not (trade.Ready[trade.A] and trade.Ready[trade.B]) then
		return
	end
	trades[trade.A] = nil
	trades[trade.B] = nil
	local ok, err = Registry.CollectibleService:Swap(trade.A, trade.Offers[trade.A], trade.B, trade.Offers[trade.B])
	for _, p in { trade.A, trade.B } do
		if p.Parent then
			Registry.NetService:Fire(p, Net.Events.Trade, {
				State = if ok then "Complete" else "Closed",
				Reason = if ok then "Trade complete!" else ("Trade failed: " .. tostring(err)),
			})
		end
	end
	Log.Info("Trade", string.format("%s <-> %s : %s (%s)", trade.A.Name, trade.B.Name, ok and "OK" or "FAILED", tostring(err)))
end

function TradeService:OnPlayerRemoving(player: Player)
	if trades[player] then
		self:Cancel(player, player.DisplayName .. " left the game")
	end
	requests[player] = nil
	lastRequest[player] = nil
end

return TradeService
