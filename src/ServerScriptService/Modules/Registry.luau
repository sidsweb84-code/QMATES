--[[
	Registry
	Service locator. ServerMain fills this table with every service before
	calling Init/Start, so services can reach each other without circular
	requires: `Registry.DataService:Get(player)`.
]]

local Registry: { [string]: any } = {}

return Registry
