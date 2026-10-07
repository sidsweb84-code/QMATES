--[[
	ContentConfig
	Controls which creature content is shown.

	LEGAL NOTICE
	"Pokémon" and all Pokémon character names, artwork, models and audio are
	trademarks / copyrighted works of Nintendo, Creatures Inc. and GAME FREAK
	(The Pokémon Company). This project ships with ORIGINAL creatures only.

	Only set LicensedMode = true if you have written permission from the rights
	holder to use their names/assets on Roblox. Publishing a game titled or
	themed after a franchise you do not have rights to can lead to DMCA takedowns
	and moderation action on your account. This code cannot make unlicensed
	content safe to publish.
]]

local ContentConfig = {}

-- false = original creatures and the original game title (safe default).
-- true  = apply the overrides in Config/LicensedContent (requires a license).
ContentConfig.LicensedMode = false

ContentConfig.OriginalTitle = "STEAL A CRITTER"
ContentConfig.OriginalSubtitle = "Collect • Defend • Steal"
ContentConfig.CreatureNoun = "Critter"
ContentConfig.CreatureNounPlural = "Critters"

-- Title used only when LicensedMode = true.
ContentConfig.LicensedTitle = "STEAL POKÉMON"
ContentConfig.LicensedSubtitle = "Collect • Defend • Steal"
ContentConfig.LicensedCreatureNoun = "Pokémon"
ContentConfig.LicensedCreatureNounPlural = "Pokémon"

function ContentConfig.Title(): string
	return ContentConfig.LicensedMode and ContentConfig.LicensedTitle or ContentConfig.OriginalTitle
end

function ContentConfig.Subtitle(): string
	return ContentConfig.LicensedMode and ContentConfig.LicensedSubtitle or ContentConfig.OriginalSubtitle
end

function ContentConfig.Noun(plural: boolean?): string
	if ContentConfig.LicensedMode then
		return plural and ContentConfig.LicensedCreatureNounPlural or ContentConfig.LicensedCreatureNoun
	end
	return plural and ContentConfig.CreatureNounPlural or ContentConfig.CreatureNoun
end

return ContentConfig
