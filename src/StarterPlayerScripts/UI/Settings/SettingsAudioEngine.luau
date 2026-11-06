--!strict
-- StarterPlayerScripts/UI/Settings/SettingsAudioEngine.luau
-- Universal audio management engine for Infinite Towers.
-- Implements dual-layer enforcement:
-- 1. Master SoundGroups in SoundService (SG_SFX, SG_Music, SG_Ambience)
-- 2. Direct 3D sound volume scaling across Workspace (including center plaza fountain)
--    with OrigVolume caching and deferred-safe property change listeners.

local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")

local SettingsAudioEngine = {}

-- Current channel volume states (0.0 to 1.0)
local currentSoundVolume = 0.80
local currentMusicVolume = 0.55
local currentAmbienceVolume = 0.60

local currentMuteSFX = false
local currentMuteMusic = false
local currentMuteAmbience = false

local trackedSounds: { [Sound]: { origVolume: number, category: string, conn: RBXScriptConnection? } } = {}
local isInitialized = false

-- Keywords for categorization
local AMBIENCE_KEYWORDS = {
	"fountain", "water", "ambience", "ambient", "wind", "fire", "torch",
	"campfire", "portal", "vortex", "pit", "cauldron", "forge", "rain",
	"weather", "hum", "stream",
}

local MUSIC_KEYWORDS = {
	"music", "bgm", "theme", "soundtrack", "bossmusic",
}

local CHARACTER_SOUNDS = {
	running = true, climbing = true, swimming = true,
	jumping = true, landing = true, splash = true,
	freefalling = true, died = true, gettingup = true,
}

local function getSoundGroup(name: string): SoundGroup
	local found = SoundService:FindFirstChild(name)
	if found and found:IsA("SoundGroup") then
		return found
	end
	local sg = Instance.new("SoundGroup")
	sg.Name = name
	sg.Parent = SoundService
	return sg
end

local function getSoundCategory(sound: Sound): string
	local lowerName = string.lower(sound.Name)

	-- Humanoid character movement sounds are SFX
	if CHARACTER_SOUNDS[lowerName] then
		return "SFX"
	end
	local modelAncestor = sound:FindFirstAncestorOfClass("Model")
	if modelAncestor and modelAncestor:FindFirstChildOfClass("Humanoid") then
		return "SFX"
	end

	local textToSearch = lowerName
	local cur: Instance? = sound.Parent
	while cur and cur ~= game do
		textToSearch ..= " " .. string.lower(cur.Name)
		cur = cur.Parent
	end

	for _, kw in ipairs(MUSIC_KEYWORDS) do
		if string.find(textToSearch, kw, 1, true) then
			return "Music"
		end
	end

	for _, kw in ipairs(AMBIENCE_KEYWORDS) do
		if string.find(textToSearch, kw, 1, true) then
			return "Ambience"
		end
	end

	-- Looped 3D sound in workspace that is not explicitly music is ambient (e.g. fountain, forge fire)
	if sound.Looped and sound:IsDescendantOf(workspace) then
		return "Ambience"
	end

	-- Looped sound directly in SoundService without music tag
	if sound.Looped and sound:IsDescendantOf(SoundService) then
		return "Music"
	end

	return "SFX"
end

local function applyVolumeToSound(sound: Sound)
	local origVol = sound:GetAttribute("OrigVolume")
	if typeof(origVol) ~= "number" then
		origVol = if sound.Volume > 0 then sound.Volume else 0.5
		sound:SetAttribute("OrigVolume", origVol)
	end

	local category = getSoundCategory(sound)
	local channelVol = currentSoundVolume
	local isMuted = currentMuteSFX

	if category == "Music" then
		channelVol = currentMusicVolume
		isMuted = currentMuteMusic
	elseif category == "Ambience" then
		channelVol = currentAmbienceVolume
		isMuted = currentMuteAmbience
	end

	local targetVol = origVol * channelVol * (if isMuted then 0 else 1)
	sound:SetAttribute("LastEngineVolume", targetVol)
	sound.Volume = targetVol
end

function SettingsAudioEngine.registerAndSyncSound(sound: Sound)
	if not sound:IsA("Sound") then return end
	if trackedSounds[sound] then
		applyVolumeToSound(sound)
		return
	end

	-- Record original volume attribute
	local origVol = sound:GetAttribute("OrigVolume")
	if typeof(origVol) ~= "number" then
		origVol = if sound.Volume > 0 then sound.Volume else 0.5
		sound:SetAttribute("OrigVolume", origVol)
	end

	local category = getSoundCategory(sound)

	-- Assign SoundGroup
	if category == "Ambience" then
		sound.SoundGroup = getSoundGroup("SG_Ambience")
	elseif category == "Music" then
		sound.SoundGroup = getSoundGroup("SG_Music")
	else
		sound.SoundGroup = getSoundGroup("SG_SFX")
	end

	local conn: RBXScriptConnection? = nil
	conn = sound:GetPropertyChangedSignal("Volume"):Connect(function()
		local lastEngineVol = sound:GetAttribute("LastEngineVolume")
		if typeof(lastEngineVol) == "number" and math.abs(sound.Volume - lastEngineVol) < 0.001 then
			return
		end
		if sound.Volume > 0 then
			sound:SetAttribute("OrigVolume", sound.Volume)
			applyVolumeToSound(sound)
		end
	end)

	local cleanupConn: RBXScriptConnection? = nil
	cleanupConn = sound.Destroying:Connect(function()
		if conn then conn:Disconnect() end
		if cleanupConn then cleanupConn:Disconnect() end
		trackedSounds[sound] = nil
	end)

	trackedSounds[sound] = {
		origVolume = origVol,
		category = category,
		conn = conn,
	}

	applyVolumeToSound(sound)
end

function SettingsAudioEngine.updateVolumes(
	soundVol: number,
	musicVol: number,
	ambVol: number,
	muteSFX: boolean,
	muteMusic: boolean,
	muteAmb: boolean
)
	currentSoundVolume = math.clamp(soundVol, 0, 1)
	currentMusicVolume = math.clamp(musicVol, 0, 1)
	currentAmbienceVolume = math.clamp(ambVol, 0, 1)

	currentMuteSFX = muteSFX
	currentMuteMusic = muteMusic
	currentMuteAmbience = muteAmb

	-- Update SoundGroups
	local sgSFX = getSoundGroup("SG_SFX")
	local sgMusic = getSoundGroup("SG_Music")
	local sgAmbience = getSoundGroup("SG_Ambience")

	sgSFX.Volume = if currentMuteSFX then 0 else currentSoundVolume
	sgMusic.Volume = if currentMuteMusic then 0 else currentMusicVolume
	sgAmbience.Volume = if currentMuteAmbience then 0 else currentAmbienceVolume

	-- Also update legacy SoundGroups if present
	local oldSFX = SoundService:FindFirstChild("SFX")
	if oldSFX and oldSFX:IsA("SoundGroup") and oldSFX ~= sgSFX then
		oldSFX.Volume = if currentMuteSFX then 0 else currentSoundVolume
	end
	local oldMusic = SoundService:FindFirstChild("Music")
	if oldMusic and oldMusic:IsA("SoundGroup") and oldMusic ~= sgMusic then
		oldMusic.Volume = if currentMuteMusic then 0 else currentMusicVolume
	end
	local oldAmb = SoundService:FindFirstChild("Ambience")
	if oldAmb and oldAmb:IsA("SoundGroup") and oldAmb ~= sgAmbience then
		oldAmb.Volume = if currentMuteAmbience then 0 else currentAmbienceVolume
	end

	-- Dual enforcement: directly re-apply to all tracked sounds
	for sound, _ in pairs(trackedSounds) do
		if sound.Parent then
			applyVolumeToSound(sound)
		else
			trackedSounds[sound] = nil
		end
	end

	-- Scan workspace sounds to ensure 100% coverage of dynamic 3D sounds
	for _, desc in ipairs(workspace:GetDescendants()) do
		if desc:IsA("Sound") then
			applyVolumeToSound(desc)
		end
	end
end

function SettingsAudioEngine.init()
	if isInitialized then return end
	isInitialized = true

	-- Ensure Master SoundGroups
	local sgSFX = getSoundGroup("SG_SFX")
	local sgMusic = getSoundGroup("SG_Music")
	local sgAmbience = getSoundGroup("SG_Ambience")

	sgSFX.Volume = currentSoundVolume
	sgMusic.Volume = currentMusicVolume
	sgAmbience.Volume = currentAmbienceVolume

	-- Scan existing sounds in Workspace, SoundService, and LocalPlayer PlayerGui
	local function scan(container: Instance)
		for _, desc in ipairs(container:GetDescendants()) do
			if desc:IsA("Sound") then
				SettingsAudioEngine.registerAndSyncSound(desc)
			end
		end
	end

	scan(workspace)
	scan(SoundService)

	local localPlayer = Players.LocalPlayer
	if localPlayer then
		local playerGui = localPlayer:FindFirstChild("PlayerGui")
		if playerGui then
			scan(playerGui)
			playerGui.DescendantAdded:Connect(function(desc)
				if desc:IsA("Sound") then
					SettingsAudioEngine.registerAndSyncSound(desc)
				end
			end)
		else
			localPlayer.ChildAdded:Connect(function(child)
				if child.Name == "PlayerGui" then
					scan(child)
					child.DescendantAdded:Connect(function(desc)
						if desc:IsA("Sound") then
							SettingsAudioEngine.registerAndSyncSound(desc)
						end
					end)
				end
			end)
		end
	end

	workspace.DescendantAdded:Connect(function(desc)
		if desc:IsA("Sound") then
			SettingsAudioEngine.registerAndSyncSound(desc)
		end
	end)

	SoundService.DescendantAdded:Connect(function(desc)
		if desc:IsA("Sound") then
			SettingsAudioEngine.registerAndSyncSound(desc)
		end
	end)
end

return SettingsAudioEngine
