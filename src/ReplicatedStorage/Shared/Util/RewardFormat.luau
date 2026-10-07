--[[
	RewardFormat
	Human readable descriptions for the shared reward format.
]]

local Shared = script.Parent.Parent
local Config = Shared.Config
local BoostConfig = require(Config.BoostConfig)
local CosmeticConfig = require(Config.CosmeticConfig)
local ShopConfig = require(Config.ShopConfig)
local RarityConfig = require(Config.RarityConfig)
local Catalog = require(Shared.Catalog)
local Format = require(script.Parent.Format)

local RewardFormat = {}

function RewardFormat.Icon(reward): string
	local t = reward.Type
	if t == "Cash" or t == "CashMinutes" or t == "InstantCollect" then
		return "💰"
	elseif t == "Tokens" then
		return "🪙"
	elseif t == "EventTokens" then
		return "🎟️"
	elseif t == "Boost" then
		local b = BoostConfig.Personal[reward.Boost]
		return b and b.Icon or "⚡"
	elseif t == "ServerBoost" then
		local b = BoostConfig.Server[reward.Boost]
		return b and b.Icon or "🌟"
	elseif t == "Cosmetic" then
		return "🎨"
	elseif t == "Collectible" or t == "RandomCollectible" then
		return "🎴"
	elseif t == "Pack" then
		local p = ShopConfig.Packs[reward.Pack]
		return p and p.Icon or "🃏"
	end
	return "🎁"
end

-- cashPerSec is optional and used to preview CashMinutes amounts.
function RewardFormat.Describe(reward, cashPerSec: number?): string
	local t = reward.Type
	if t == "Cash" then
		return Format.Cash(reward.Amount)
	elseif t == "CashMinutes" then
		if cashPerSec then
			local amount = math.floor(math.max(reward.Min or 0, reward.Minutes * 60 * cashPerSec))
			return Format.Cash(amount)
		end
		return string.format("%d min of income", reward.Minutes)
	elseif t == "Tokens" then
		return string.format("%s Tokens", Format.Abbreviate(reward.Amount))
	elseif t == "EventTokens" then
		return string.format("%s Event Tokens", Format.Abbreviate(reward.Amount))
	elseif t == "Boost" then
		local b = BoostConfig.Personal[reward.Boost]
		return string.format("%s (%s)", b and b.Name or reward.Boost, Format.Time(reward.Duration))
	elseif t == "ServerBoost" then
		local b = BoostConfig.Server[reward.Boost]
		return string.format("%s (%s)", b and b.Name or reward.Boost, Format.Time(reward.Duration))
	elseif t == "Cosmetic" then
		local c = CosmeticConfig.Get(reward.Id)
		return c and c.Name or "Cosmetic"
	elseif t == "Collectible" then
		local def = Catalog.Get(reward.Id)
		local name = def and def.Name or "Critter"
		if reward.Mutation and reward.Mutation ~= "Normal" then
			name = reward.Mutation .. " " .. name
		end
		return name
	elseif t == "RandomCollectible" then
		local r = RarityConfig.Rarities[reward.Rarity]
		return string.format("Random %s Critter", r and r.Name or reward.Rarity)
	elseif t == "Pack" then
		local p = ShopConfig.Packs[reward.Pack]
		return p and ("Free " .. p.Name) or "Card Pack"
	elseif t == "InstantCollect" then
		return "Instant collect x2"
	end
	return "Reward"
end

function RewardFormat.DescribeList(rewards, cashPerSec: number?): string
	local parts = {}
	for _, reward in rewards or {} do
		table.insert(parts, RewardFormat.Icon(reward) .. " " .. RewardFormat.Describe(reward, cashPerSec))
	end
	return table.concat(parts, "  ")
end

return RewardFormat
