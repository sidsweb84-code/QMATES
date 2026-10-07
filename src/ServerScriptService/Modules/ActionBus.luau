--[[
	ActionBus
	Server-side event bus for gameplay actions. Gameplay services fire actions;
	quest, achievement and tutorial systems listen. Keeps services decoupled.

	ActionBus.Fire(player, "Acquire", 1, { Rarity = "Epic", Mutation = "Shiny" })
]]

local ActionBus = {}

type Listener = (player: Player, action: string, amount: number, context: { [string]: any }) -> ()

local listeners: { Listener } = {}

function ActionBus.Listen(callback: Listener)
	table.insert(listeners, callback)
end

function ActionBus.Fire(player: Player, action: string, amount: number?, context: { [string]: any }?)
	local ctx = context or {}
	local n = amount or 1
	for _, listener in listeners do
		local ok, err = pcall(listener, player, action, n, ctx)
		if not ok then
			warn("[ActionBus] listener error for " .. action .. ": " .. tostring(err))
		end
	end
end

return ActionBus
