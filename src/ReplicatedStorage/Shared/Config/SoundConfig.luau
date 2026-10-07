--[[
	SoundConfig
	PLACEHOLDER AUDIO. Every sound below points at a sound file that ships with
	the Roblox client (rbxasset://sounds/...) so the game makes noise out of the
	box without any copyrighted audio.

	TO REPLACE: upload your own (or properly licensed) audio on the Creator
	Dashboard and paste "rbxassetid://<id>" into Id. Pitch/Volume are optional.
	An empty Id simply plays nothing — the game never errors on missing audio.
]]

local SoundConfig = {}

SoundConfig.Sounds = {
	-- UI
	UIClick = { Id = "rbxasset://sounds/button.wav", Volume = 0.35, Pitch = 1.1 },
	UIHover = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.15, Pitch = 1.4 },
	WindowOpen = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.3, Pitch = 1.3 },
	WindowClose = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.25, Pitch = 0.9 },
	Notify = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.3, Pitch = 1.2 },
	Error = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.4, Pitch = 0.6 },

	-- Economy ("cash register" placeholder)
	Purchase = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5, Pitch = 1.5 },
	CashCollect = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.45, Pitch = 1.8 },
	Upgrade = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5, Pitch = 1.0 },
	Jackpot = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, Pitch = 2.2 },

	-- Reveals (played layered/pitched by the reveal sequence)
	CardFlip = { Id = "rbxasset://sounds/snap.wav", Volume = 0.5, Pitch = 1.0 },
	RevealCommon = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.4, Pitch = 1.3 },
	RevealRare = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5, Pitch = 1.7 },
	RevealLegendary = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.65, Pitch = 2.1 },
	RevealWhoosh = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.6, Pitch = 0.7 },
	RevealMythic = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.7, Pitch = 0.8 },
	RevealSecret = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.8, Pitch = 0.55 },

	-- Stealing / defence
	StealStart = { Id = "rbxasset://sounds/unsheath.wav", Volume = 0.5, Pitch = 1.0 },
	StealAlarm = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.7, Pitch = 0.75 },
	StealSuccess = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, Pitch = 1.6 },
	StealFail = { Id = "rbxasset://sounds/collide.wav", Volume = 0.6, Pitch = 0.8 },
	Caught = { Id = "rbxasset://sounds/collide.wav", Volume = 0.7, Pitch = 1.2 },
	Trap = { Id = "rbxasset://sounds/collide.wav", Volume = 0.8, Pitch = 0.5 },
	Lock = { Id = "rbxasset://sounds/snap.wav", Volume = 0.6, Pitch = 0.7 },

	-- Progression
	Rebirth = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.7, Pitch = 0.5 },
	QuestComplete = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5, Pitch = 1.35 },
	Reward = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5, Pitch = 1.25 },
}

-- Background music. PLACEHOLDER: no music ships with this project.
-- Add an "rbxassetid://..." you own or licensed to enable it.
SoundConfig.Music = {
	Main = { Id = "", Volume = 0.25 },
	Event = { Id = "", Volume = 0.25 },
}

return SoundConfig
