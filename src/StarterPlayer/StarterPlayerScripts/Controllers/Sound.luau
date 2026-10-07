--[[
	Sound
	Client-side audio: every sound effect and music track plays locally so the
	player's SFX / Music settings are always respected. Missing / empty asset
	ids are simply silent.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local SoundConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SoundConfig"))

local Sound = {}

Sound.SFXEnabled = true
Sound.MusicEnabled = true

local folder = Instance.new("Folder")
folder.Name = "ClientSounds"
folder.Parent = SoundService

local templates: { [string]: Sound } = {}
local music: Sound? = nil
local lastPlayed: { [string]: number } = {}

local function template(name: string): Sound?
	if templates[name] then
		return templates[name]
	end
	local def = SoundConfig.Sounds[name]
	if not def or def.Id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = def.Id
	s.Volume = def.Volume or 0.5
	s.PlaybackSpeed = def.Pitch or 1
	s.Parent = folder
	templates[name] = s
	return s
end

export type PlayOptions = { Pitch: number?, Volume: number?, Position: Vector3?, MinInterval: number? }

function Sound.Play(name: string, options: PlayOptions?)
	if not Sound.SFXEnabled then
		return
	end
	local opts: PlayOptions = options or {}
	local now = os.clock()
	if (lastPlayed[name] or 0) + (opts.MinInterval or 0.03) > now then
		return
	end
	lastPlayed[name] = now
	local base = template(name)
	if not base then
		return
	end
	local s = base:Clone()
	if opts.Pitch then
		s.PlaybackSpeed = base.PlaybackSpeed * opts.Pitch
	end
	if opts.Volume then
		s.Volume = base.Volume * opts.Volume
	end
	if opts.Position then
		local holder = Instance.new("Part")
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.one * 0.2
		holder.Position = opts.Position
		holder.Parent = Workspace.CurrentCamera
		s.RollOffMaxDistance = 120
		s.Parent = holder
		s.Ended:Once(function()
			holder:Destroy()
		end)
		task.delay(10, function()
			if holder.Parent then
				holder:Destroy()
			end
		end)
	else
		s.Parent = folder
		s.Ended:Once(function()
			s:Destroy()
		end)
		task.delay(10, function()
			if s.Parent then
				s:Destroy()
			end
		end)
	end
	s:Play()
end

-- Plays a short sequence: { {Name, Delay, Pitch?, Volume?}, ... }
function Sound.Sequence(steps: { any })
	task.spawn(function()
		for _, step in steps do
			if step[2] and step[2] > 0 then
				task.wait(step[2])
			end
			Sound.Play(step[1], { Pitch = step[3], Volume = step[4], MinInterval = 0 })
		end
	end)
end

function Sound.SetSFX(enabled: boolean)
	Sound.SFXEnabled = enabled
end

function Sound.SetMusic(enabled: boolean, track: string?)
	Sound.MusicEnabled = enabled
	local def = SoundConfig.Music[track or "Main"]
	if not enabled or not def or def.Id == "" then
		if music then
			music:Stop()
		end
		return
	end
	local m = music
	if not m then
		local created = Instance.new("Sound")
		created.Name = "Music"
		created.Looped = true
		created.Parent = folder
		music = created
		m = created
	end
	assert(m, "music sound")
	if m.SoundId ~= def.Id then
		m.SoundId = def.Id
	end
	m.Volume = def.Volume or 0.25
	if not m.IsPlaying then
		m:Play()
	end
end

return Sound
