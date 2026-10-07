--[[
	CosmeticService
	Ownership + equipping of purely visual items, and applying them:
	trails and name tags on characters, card frames on collectible cards,
	themes and particle effects on bases.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CosmeticConfig = require(Shared.Config.CosmeticConfig)

local Modules = script.Parent.Parent.Modules
local Registry = require(Modules.Registry)

local CosmeticService = {}

function CosmeticService:Init() end
function CosmeticService:Start() end

function CosmeticService:Owns(player: Player, id: string): boolean
	local item = CosmeticConfig.Get(id)
	local data = Registry.DataService:Get(player)
	if not item or not data then
		return false
	end
	if item.Unlock.Type == "Default" then
		return true
	end
	if item.Unlock.Type == "Gamepass" and Registry.MonetizationService:OwnsPass(player, item.Unlock.Pass) then
		return true
	end
	return data.Cosmetics.Owned[id] == true
end

function CosmeticService:Grant(player: Player, id: string): boolean
	local item = CosmeticConfig.Get(id)
	local data = Registry.DataService:Get(player)
	if not item or not data then
		return false
	end
	if not data.Cosmetics.Owned[id] then
		data.Cosmetics.Owned[id] = true
		Registry.DataService:MarkDirty(player, "Cosmetics")
	end
	return true
end

-- id = "" with typeName unequips (back to the default).
function CosmeticService:Equip(player: Player, id: any, typeName: any?): (boolean, string?)
	local data = Registry.DataService:Get(player)
	if not data then
		return false, "Not loaded"
	end
	if id == "" and type(typeName) == "string" and CosmeticConfig.Defaults[typeName] ~= nil then
		data.Cosmetics.Equipped[typeName] = CosmeticConfig.Defaults[typeName]
		Registry.DataService:MarkDirty(player, "Cosmetics")
		self:_apply(player, typeName)
		return true, "Unequipped"
	end
	local item = type(id) == "string" and CosmeticConfig.Get(id) or nil
	if not item then
		return false, "Unknown item"
	end
	if not self:Owns(player, id) then
		return false, "You don't own this yet"
	end
	data.Cosmetics.Equipped[item.Type] = id
	Registry.DataService:MarkDirty(player, "Cosmetics")
	self:_apply(player, item.Type)
	return true, "Equipped " .. item.Name
end

function CosmeticService:_apply(player: Player, typeName: string)
	if typeName == "Trail" or typeName == "NameTag" then
		if player.Character then
			self:ApplyToCharacter(player, player.Character)
		end
	elseif typeName == "CardFrame" then
		Registry.BaseService:RefreshAllCards(player)
	elseif typeName == "BaseTheme" or typeName == "BaseEffect" then
		Registry.BaseService:ApplyCosmetics(player)
	end
end

-- Equipped gamepass cosmetics are lost if the pass can no longer be verified.
function CosmeticService:ValidateEquipped(player: Player)
	local data = Registry.DataService:Get(player)
	if not data then
		return
	end
	for typeName, id in data.Cosmetics.Equipped do
		if id ~= "" and not self:Owns(player, id) then
			data.Cosmetics.Equipped[typeName] = CosmeticConfig.Defaults[typeName]
			Registry.DataService:MarkDirty(player, "Cosmetics")
		end
	end
end

function CosmeticService:ApplyToCharacter(player: Player, character: Model)
	local data = Registry.DataService:Get(player)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local head = character:FindFirstChild("Head") :: BasePart?
	if not data or not root then
		return
	end

	-- Trail
	for _, name in { "CosmeticTrail", "TrailA0", "TrailA1" } do
		local old = root:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local trailItem = CosmeticConfig.Get(data.Cosmetics.Equipped.Trail)
	if trailItem and trailItem.Type == "Trail" then
		local a0 = Instance.new("Attachment")
		a0.Name = "TrailA0"
		a0.Position = Vector3.new(0, 0.8, 0)
		a0.Parent = root
		local a1 = Instance.new("Attachment")
		a1.Name = "TrailA1"
		a1.Position = Vector3.new(0, -0.8, 0)
		a1.Parent = root
		local trail = Instance.new("Trail")
		trail.Name = "CosmeticTrail"
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		local colors = trailItem.Colors
		local keypoints = {}
		for i, color in colors do
			table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / math.max(1, #colors - 1), color))
		end
		if #keypoints == 1 then
			table.insert(keypoints, ColorSequenceKeypoint.new(1, colors[1]))
		end
		trail.Color = ColorSequence.new(keypoints)
		trail.Lifetime = 0.6
		trail.LightEmission = 0.6
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.WidthScale = NumberSequence.new(1, 0)
		trail.Parent = root
	end

	-- Name tag
	if head then
		local old = head:FindFirstChild("NameTag")
		if old then
			old:Destroy()
		end
		local tagItem = CosmeticConfig.Get(data.Cosmetics.Equipped.NameTag) or CosmeticConfig.Items.NameTag_Rookie
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "NameTag"
		billboard.Size = UDim2.fromOffset(220, 56)
		billboard.StudsOffset = Vector3.new(0, 2.6, 0)
		billboard.MaxDistance = 80
		billboard.LightInfluence = 0
		billboard.Parent = head
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "PlayerName"
		nameLabel.BackgroundTransparency = 1
		nameLabel.Size = UDim2.fromScale(1, 0.55)
		nameLabel.Font = Enum.Font.FredokaOne
		nameLabel.TextScaled = true
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.Text = player.DisplayName
		local s1 = Instance.new("UIStroke")
		s1.Thickness = 2
		s1.Parent = nameLabel
		nameLabel.Parent = billboard
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Position = UDim2.fromScale(0, 0.55)
		title.Size = UDim2.fromScale(1, 0.45)
		title.Font = Enum.Font.GothamBold
		title.TextScaled = true
		title.TextColor3 = tagItem.Color or Color3.new(1, 1, 1)
		local rebirths = data.Rebirths
		title.Text = (tagItem.Text or tagItem.Name) .. (if rebirths > 0 then "  ♻" .. rebirths else "")
		local s2 = Instance.new("UIStroke")
		s2.Thickness = 2
		s2.Parent = title
		title.Parent = billboard
		if tagItem.Rainbow then
			local gradient = Instance.new("UIGradient")
			gradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 200, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 220, 80)),
			})
			gradient:AddTag("AnimatedGradient")
			gradient.Parent = title
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	end
end

function CosmeticService:OnPlayerLoaded(player: Player)
	self:ValidateEquipped(player)
end

return CosmeticService
