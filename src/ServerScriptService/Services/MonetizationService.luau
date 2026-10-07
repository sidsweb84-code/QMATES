--[[
	MonetizationService
	Gamepasses and developer products through Roblox's official
	MarketplaceService APIs. All IDs live in MonetizationConfig.

	ProcessReceipt follows Roblox's recommended pattern:
	1. Wait for the buyer's data; if unavailable -> NotProcessedYet (Roblox retries).
	2. If the PurchaseId is already in the profile -> PurchaseGranted (no double grant).
	3. Grant, record the PurchaseId, SAVE. Only report PurchaseGranted after the
	   save succeeds; otherwise NotProcessedYet. The in-memory receipt record
	   prevents a double grant if Roblox retries during the same session.
]]

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)

local Modules = script.Parent.Parent.Modules
local Registry = require(Modules.Registry)
local DataSchema = require(Modules.DataSchema)
local Log = require(Modules.Log)

local MonetizationService = {}

function MonetizationService:Init()
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		return self:_processReceipt(receiptInfo)
	end
end

function MonetizationService:Start()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local key = MonetizationConfig.GetPassById(passId)
		if key then
			self:_setPass(player, key, true)
			Registry.NetService:Notify(player, "Thank you! " .. MonetizationConfig.Gamepasses[key].Name .. " unlocked.", "Success", "💎")
		end
	end)
end

---------------------------------------------------------------- gamepasses
function MonetizationService:OwnsPass(player: Player, key: string): boolean
	local data = Registry.DataService:Get(player)
	return data ~= nil and data.Gamepasses[key] == true
end

function MonetizationService:_setPass(player: Player, key: string, owned: boolean)
	local data = Registry.DataService:Get(player)
	if not data then
		return
	end
	local before = data.Gamepasses[key] == true
	data.Gamepasses[key] = if owned then true else nil
	Registry.DataService:MarkDirty(player, "Gamepasses")
	self:_syncSession(player)
	if before ~= owned then
		self:_applyPerks(player)
	end
end

function MonetizationService:_syncSession(player: Player)
	local data = Registry.DataService:Get(player)
	if not data then
		return
	end
	local owned = {}
	for key in data.Gamepasses do
		owned[key] = true
	end
	Registry.DataService:SetSession(player, "Passes", owned)
	player:SetAttribute("VIP", owned.VIP == true)
end

function MonetizationService:_applyPerks(player: Player)
	Registry.CollectibleService:NormalizeSlots(player)
	Registry.BaseService:RefreshSlots(player)
	Registry.DataService:SetSession(player, "Capacity", Registry.CollectibleService:Capacity(player))
	Registry.DataService:SetSession(player, "StorageCapacity", Registry.CollectibleService:StorageCapacity(player))
	Registry.PlayerService:UpdateMovement(player)
	Registry.EconomyService:Refresh(player)
	Registry.CosmeticService:ValidateEquipped(player)
	if player.Character then
		Registry.CosmeticService:ApplyToCharacter(player, player.Character)
	end
	Registry.BaseService:ApplyCosmetics(player)
end

function MonetizationService:OnPlayerLoaded(player: Player)
	for key, pass in MonetizationConfig.Gamepasses do
		if pass.Id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
			if ok then
				local data = Registry.DataService:Get(player)
				if data then
					data.Gamepasses[key] = if owns then true else nil
				end
			else
				-- Keep the cached value if Roblox is unreachable.
				Log.Warn("Monetization", "Gamepass check failed for " .. key .. ": " .. tostring(owns), player.UserId)
			end
		end
	end
	Registry.DataService:MarkDirty(player, "Gamepasses")
	self:_syncSession(player)
	Registry.DataService:SetSession(player, "Capacity", Registry.CollectibleService:Capacity(player))
	Registry.DataService:SetSession(player, "StorageCapacity", Registry.CollectibleService:StorageCapacity(player))
end

---------------------------------------------------------------- products
function MonetizationService:_grantProduct(player: Player, key: string, product)
	local lines = Registry.RewardService:Grant(player, product.Rewards, "Product")
	Registry.NetService:Fire(player, "Popup", "Thank you for your purchase!", lines, product.Icon or "💎")
	Log.Info("Purchase", string.format("%s bought %s", player.Name, key), player.UserId)
end

function MonetizationService:_processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = Registry.DataService:WaitForProfile(player, 15)
	if not profile or profile.Released then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = profile.Data
	local purchaseId = tostring(receiptInfo.PurchaseId)
	if data.Receipts[purchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local key, product = MonetizationConfig.GetProductById(receiptInfo.ProductId)
	if not key or not product then
		Log.Error("Purchase", "Unknown product id " .. tostring(receiptInfo.ProductId), player.UserId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, err = pcall(self._grantProduct, self, player, key, product)
	if not ok then
		Log.Error("Purchase", "Grant failed: " .. tostring(err), player.UserId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	data.Receipts[purchaseId] = os.time()
	DataSchema.TrimReceipts(data, GameConfig.Data.MaxReceiptHistory)
	if Registry.DataService:SaveAsync(player, false) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

---------------------------------------------------------------- Studio testing
-- Runs the real ProcessReceipt path with a fake receipt (Studio only).
function MonetizationService:SimulateProduct(player: Player, key: string, purchaseId: string?): (boolean, string)
	if not RunService:IsStudio() then
		return false, "Studio only"
	end
	local product = MonetizationConfig.Products[key]
	if not product then
		return false, "Unknown product " .. tostring(key)
	end
	-- Temporarily give unconfigured products a fake id so lookup succeeds.
	local fakeId = if product.Id ~= 0 then product.Id else -(#key + 1000)
	local originalId = product.Id
	product.Id = fakeId
	local decision = self:_processReceipt({
		PlayerId = player.UserId,
		ProductId = fakeId,
		PurchaseId = purchaseId or ("STUDIO-" .. HttpService:GenerateGUID(false)),
		CurrencySpent = 0,
		CurrencyType = Enum.CurrencyType.Robux,
		PlaceIdWherePurchased = game.PlaceId,
	})
	product.Id = originalId
	return decision == Enum.ProductPurchaseDecision.PurchaseGranted, tostring(decision)
end

function MonetizationService:SimulatePass(player: Player, key: string, owned: boolean?): (boolean, string)
	if not RunService:IsStudio() then
		return false, "Studio only"
	end
	if not MonetizationConfig.Gamepasses[key] then
		return false, "Unknown pass " .. tostring(key)
	end
	self:_setPass(player, key, owned ~= false)
	return true, key .. (if owned ~= false then " granted" else " removed")
end

return MonetizationService
