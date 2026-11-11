--!strict
-- StarterPlayerScripts/Audio/AudioManager.luau
-- Central client audio driver for Infinite Tower.
-- Provides high-performance 2D and 3D sound playback with:
-- - SoundCatalog lookup with fallbacks and default volumes
-- - Pitch micro-jittering to eliminate acoustic fatigue
-- - Per-sound spam throttling
-- - Distance culling via SoundPool
-- - Native compatibility with SettingsAudioEngine sliders (OrigVolume tracking)

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared", 10)
local configFolder = if Shared then Shared:WaitForChild("Config", 10) else nil
local soundCatalogModule = if configFolder then configFolder:WaitForChild("SoundCatalog", 10) else nil
local SoundCatalog = if soundCatalogModule and soundCatalogModule:IsA("ModuleScript") then require(soundCatalogModule) else nil
local SoundPool = require(script.Parent:WaitForChild("SoundPool"))

local AudioManager = {}

local function getDef(name: string)
	if not SoundCatalog then
		local cfg = if Shared then Shared:FindFirstChild("Config") else nil
		local sc = if cfg then cfg:FindFirstChild("SoundCatalog") else nil
		if sc and sc:IsA("ModuleScript") then
			SoundCatalog = require(sc)
		end
	end
	return if SoundCatalog then SoundCatalog.Get(name) else nil
end

local lastPlayed: { [string]: number } = {}
local tempAnchorsFolder: Folder? = nil

local function getTempFolder(): Folder
	if tempAnchorsFolder and tempAnchorsFolder.Parent then
		return tempAnchorsFolder
	end
	local f = Workspace:FindFirstChild("AudioTempAnchors")
	if not f then
		local newF = Instance.new("Folder")
		newF.Name = "AudioTempAnchors"
		newF.Parent = Workspace
		tempAnchorsFolder = newF
	else
		tempAnchorsFolder = f :: Folder
	end
	return tempAnchorsFolder :: Folder
end

--============================================================================
-- 2D AUDIO PLAYBACK (UI, Global Stingers, Warnings)
--============================================================================

function AudioManager.Play2D(name: string, pitchOverride: number?, volumeScale: number?): Sound?
	local def = getDef(name)
	if not def or def.Id == "" then return nil end

	local now = os.clock()
	if def.Cooldown and (now - (lastPlayed[name] or 0)) < def.Cooldown then
		return nil
	end
	lastPlayed[name] = now

	local sound = SoundPool.Acquire()
	if not sound then return nil end

	local jitter = 0
	if def.PitchVariance and def.PitchVariance > 0 then
		jitter = (math.random() - 0.5) * 2 * def.PitchVariance
	end
	local targetPitch = (pitchOverride or def.Pitch or 1.0) + jitter
	local targetVolume = (def.Volume or 0.6) * (volumeScale or 1.0)

	sound.SoundId = def.Id
	sound.PlaybackSpeed = math.clamp(targetPitch, 0.2, 3.0)
	sound.Volume = targetVolume
	sound:SetAttribute("OrigVolume", targetVolume)

	-- Parent to SoundService for clean 2D delivery
	sound.Parent = SoundService

	local conn: RBXScriptConnection? = nil
	conn = sound.Ended:Once(function()
		if conn then conn:Disconnect() end
		SoundPool.Release(sound)
	end)

	sound:Play()

	-- Safety timeout in case Ended fails to fire (e.g. streaming/client edge cases)
	task.delay(4, function()
		if sound.Parent and not sound.IsPlaying then
			SoundPool.Release(sound)
		end
	end)

	return sound
end

--============================================================================
-- 3D SPATIAL AUDIO PLAYBACK (Weapons, Hits, Kills, Impacts)
--============================================================================

function AudioManager.Play3D(
	name: string,
	target: Vector3 | BasePart,
	pitchOverride: number?,
	volumeScale: number?
): Sound?
	local def = getDef(name)
	if not def or def.Id == "" then return nil end

	local pos = if typeof(target) == "Vector3" then target else (target :: BasePart).Position
	if not SoundPool.IsAudible(pos) then
		return nil
	end

	local now = os.clock()
	if def.Cooldown and (now - (lastPlayed[name] or 0)) < def.Cooldown then
		return nil
	end
	lastPlayed[name] = now

	local sound = SoundPool.Acquire()
	if not sound then return nil end

	local jitter = 0
	if def.PitchVariance and def.PitchVariance > 0 then
		jitter = (math.random() - 0.5) * 2 * def.PitchVariance
	end
	local targetPitch = (pitchOverride or def.Pitch or 1.0) + jitter
	local targetVolume = (def.Volume or 0.6) * (volumeScale or 1.0)

	sound.SoundId = def.Id
	sound.PlaybackSpeed = math.clamp(targetPitch, 0.2, 3.0)
	sound.Volume = targetVolume
	sound.RollOffMinDistance = def.RollOffMin or 10
	sound.RollOffMaxDistance = def.RollOffMax or 75
	sound:SetAttribute("OrigVolume", targetVolume)

	local tempAnchor: Part? = nil
	if typeof(target) == "Vector3" then
		tempAnchor = Instance.new("Part")
		tempAnchor.Name = "AudioAnchor_" .. name
		tempAnchor.Size = Vector3.new(0.1, 0.1, 0.1)
		tempAnchor.Position = target
		tempAnchor.Anchored = true
		tempAnchor.CanCollide = false
		tempAnchor.CanTouch = false
		tempAnchor.CanQuery = false
		tempAnchor.Transparency = 1
		tempAnchor.CastShadow = false
		tempAnchor.Parent = getTempFolder()
		sound.Parent = tempAnchor
	else
		sound.Parent = target
	end

	local conn: RBXScriptConnection? = nil
	conn = sound.Ended:Once(function()
		if conn then conn:Disconnect() end
		SoundPool.Release(sound)
		if tempAnchor then
			tempAnchor:Destroy()
		end
	end)

	sound:Play()

	task.delay(4, function()
		if sound.Parent and not sound.IsPlaying then
			SoundPool.Release(sound)
			if tempAnchor then tempAnchor:Destroy() end
		end
	end)

	return sound
end

--============================================================================
-- PRELOADING
--============================================================================

function AudioManager.PreloadCritical()
	task.spawn(function()
		local criticalKeys = {
			"HitLight", "HitHeavy", "HitCrit", "HitSkill", "MobDeath",
			"SlashSword", "BowRelease", "Click", "Hover", "WhistleOverdrive", "WhistleRecall",
		}
		local soundsToPreload: { Sound } = {}
		for _, key in ipairs(criticalKeys) do
			local def = getDef(key)
			if def and def.Id ~= "" then
				local s = Instance.new("Sound")
				s.SoundId = def.Id
				table.insert(soundsToPreload, s)
			end
		end

		if #soundsToPreload > 0 then
			pcall(function()
				ContentProvider:PreloadAsync(soundsToPreload)
			end)
			for _, s in ipairs(soundsToPreload) do
				s:Destroy()
			end
		end
	end)
end

return AudioManager
