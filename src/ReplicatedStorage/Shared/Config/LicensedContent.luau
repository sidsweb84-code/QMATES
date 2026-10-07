--[[
	LicensedContent
	Optional per-collectible overrides that are applied ONLY when
	ContentConfig.LicensedMode = true. Use this if (and only if) you have a
	license to use another franchise's characters.

	Keys are collectible Ids from CollectibleConfig. Every field is optional:
		Name      replacement display name
		ImageId   "rbxassetid://..." card artwork YOU uploaded under your license
		Model     name of a Model you placed in ReplicatedStorage.Assets.Creatures
		          (it replaces the procedural model; it must contain a PrimaryPart)
		Description replacement flavour text

	Do NOT scrape or rip artwork/models/audio from websites, games or card scans.
	Upload only assets you own or are licensed to use.

	Example structure (commented out on purpose — this project has no license):

	return {
		zapkit = { Name = "Pikachu", ImageId = "rbxassetid://0", Model = "Pikachu" },
		solarion = { Name = "Charizard", ImageId = "rbxassetid://0" },
		chronowyrm = { Name = "Mewtwo" },
		twinklet = { Name = "Mew" },
		voidmaw = { Name = "Rayquaza" },
		nightprowl = { Name = "Lucario" },
		shadeling = { Name = "Gengar" },
		frostbun = { Name = "Eevee" },
		tidalisk = { Name = "Greninja" },
		umbrafang = { Name = "Garchomp" },
		aetherwing = { Name = "Dragonite" },
	}
]]

local LicensedContent: { [string]: { Name: string?, ImageId: string?, Model: string?, Description: string? } } = {}

return LicensedContent
