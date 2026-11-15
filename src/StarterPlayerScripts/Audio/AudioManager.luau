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
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local IS_STUDIO = RunService:IsStudio()

local Shared = ReplicatedStorage:WaitForChild("Shared", 10)
local configFolder = if Shared then Shared:WaitForChild("Config", 10) else nil
local soundCatalogModule = if configFolder then configFolder:WaitForChild("SoundCatalog", 10) else nil
local SoundCatalog = if soundCatalogModule and soundCatalogModule:IsA("ModuleScript") then require(soundCatalogModule) else nil
local SoundPool = require(script.Parent:WaitForChild("SoundPool"))

local AudioManager = {}

local function getCatalog()
	if not SoundCatalog then
		local cfg = if Shared then Shared:FindFirstChild("Config") else nil
		local sc = if cfg then cfg:FindFirstChild("SoundCatalog") else nil
		if sc and sc:IsA("ModuleScript") then
			SoundCatalog = require(sc)
		end
	end
	return SoundCatalog
end

local function getDef(name: string)
	local cat = getCatalog()
	return if cat then cat.Get(name) else nil
end

local function resolveDefId(def: any): string?
	if not def then
		return nil
	end
	local cat = getCatalog()
	if cat and cat.ResolveId then
		return cat.ResolveId(def, IS_STUDIO)
	end
	if type(def.Id) == "string" and def.Id ~= "" then
		return def.Id
	end
	return nil
end

local lastPlayed: { [string]: number } = {}
local tempAnchorsFolder: Folder? = nil
local playbackSeq = 0
local activeTokens: { [Sound]: number } = {}
local activeFadeTweens: { [Sound]: Tween } = {}

local function cancelFadeTween(sound: Sound)
	local tw = activeFadeTweens[sound]
	if tw then
		tw:Cancel()
		activeFadeTweens[sound] = nil
	end
end

local function releasePooledSound(sound: Sound, token: number, tempAnchor: Part?)
	if activeTokens[sound] ~= token then
		return
	end
	activeTokens[sound] = nil
	cancelFadeTween(sound)
	sound.TimePosition = 0
	sound.PlaybackSpeed = 1
	sound.Looped = false
	sound.RollOffMinDistance = 10
	sound.RollOffMaxDistance = 75
	SoundPool.Release(sound)
	if tempAnchor and tempAnchor.Parent then
		tempAnchor:Destroy()
	end
end

local function schedulePlaybackEnvelope(sound: Sound, token: number, def: any, tempAnchor: Part?)
	local maxDur = def.MaxDuration
	local fadeOut = if type(def.FadeOutSeconds) == "number" then def.FadeOutSeconds else 0.18
	if type(maxDur) == "number" and maxDur > 0 then
		local clampedFade = math.clamp(fadeOut, 0, maxDur * 0.5)
		local fadeDelay = math.max(0.02, maxDur - clampedFade)
		task.delay(fadeDelay, function()
			if activeTokens[sound] ~= token or not sound.Parent then
				return
			end
			if clampedFade > 0.03 and sound.IsPlaying then
				cancelFadeTween(sound)
				local tw = TweenService:Create(
					sound,
					TweenInfo.new(clampedFade, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Volume = 0 }
				)
				activeFadeTweens[sound] = tw
				tw:Play()
			end
			task.delay(clampedFade + 0.04, function()
				releasePooledSound(sound, token, tempAnchor)
			end)
		end)
	end

	local safetyTimeout = if type(maxDur) == "number" and maxDur > 0 then (maxDur + 3) else 6
	task.delay(safetyTimeout, function()
		if activeTokens[sound] == token then
			releasePooledSound(sound, token, tempAnchor)
		end
	end)
end

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
	local soundId = resolveDefId(def)
	if not def or not soundId or soundId == "" then return nil end

	local now = os.clock()
	if def.Cooldown and (now - (lastPlayed[name] or 0)) < def.Cooldown then
		return nil
	end
	lastPlayed[name] = now

	local sound = SoundPool.Acquire()
	if not sound then return nil end

	playbackSeq += 1
	local token = playbackSeq
	activeTokens[sound] = token

	local jitter = 0
	if def.PitchVariance and def.PitchVariance > 0 then
		jitter = (math.random() - 0.5) * 2 * def.PitchVariance
	end
	local targetPitch = (pitchOverride or def.Pitch or 1.0) + jitter
	local targetVolume = (def.Volume or 0.6) * (volumeScale or 1.0)

	sound.Name = "Audio2D_" .. name
	sound.SoundId = soundId
	sound.PlaybackSpeed = math.clamp(targetPitch, 0.2, 3.0)
	sound.TimePosition = def.TimeOffset or 0
	sound.Looped = false
	sound:SetAttribute("OrigVolume", targetVolume)
	sound.Volume = targetVolume

	-- Parent to SoundService for clean 2D delivery
	sound.Parent = SoundService

	local conn: RBXScriptConnection? = nil
	conn = sound.Ended:Once(function()
		if conn then conn:Disconnect() end
		releasePooledSound(sound, token, nil)
	end)

	sound:Play()
	schedulePlaybackEnvelope(sound, token, def, nil)

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
	local soundId = resolveDefId(def)
	if not def or not soundId or soundId == "" then return nil end

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

	playbackSeq += 1
	local token = playbackSeq
	activeTokens[sound] = token

	local jitter = 0
	if def.PitchVariance and def.PitchVariance > 0 then
		jitter = (math.random() - 0.5) * 2 * def.PitchVariance
	end
	local targetPitch = (pitchOverride or def.Pitch or 1.0) + jitter
	local targetVolume = (def.Volume or 0.6) * (volumeScale or 1.0)

	sound.Name = "Audio3D_" .. name
	sound.SoundId = soundId
	sound.PlaybackSpeed = math.clamp(targetPitch, 0.2, 3.0)
	sound.TimePosition = def.TimeOffset or 0
	sound.Looped = false
	sound.RollOffMinDistance = def.RollOffMin or 10
	sound.RollOffMaxDistance = def.RollOffMax or 75
	sound:SetAttribute("OrigVolume", targetVolume)
	sound.Volume = targetVolume

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
		releasePooledSound(sound, token, tempAnchor)
	end)

	sound:Play()
	schedulePlaybackEnvelope(sound, token, def, tempAnchor)

	return sound
end

function AudioManager.PlayDelayed3D(
	delaySeconds: number,
	name: string,
	target: Vector3 | BasePart,
	pitchOverride: number?,
	volumeScale: number?
)
	if delaySeconds <= 0.01 then
		AudioManager.Play3D(name, target, pitchOverride, volumeScale)
		return
	end
	task.delay(delaySeconds, function()
		if typeof(target) ~= "Vector3" and not (target :: BasePart).Parent then
			return
		end
		AudioManager.Play3D(name, target, pitchOverride, volumeScale)
	end)
end

--============================================================================
-- PRELOADING
--============================================================================

function AudioManager.PreloadCritical()
	task.spawn(function()
		local criticalKeys = {
			"HitLight", "HitHeavy", "HitCrit", "HitSkill", "MobDeath",
			"SlashSword", "SlashDagger", "BowDraw", "BowRelease",
			"KatanaUnsheath", "MagicSpark", "LightningArc", "Heal",
			"Click", "Hover", "WindowOpen", "Error",
			"WhistleOverdrive", "WhistleRecall",
		}
		local soundsToPreload: { Sound } = {}
		for _, key in ipairs(criticalKeys) do
			local def = getDef(key)
			local soundId = resolveDefId(def)
			if soundId and soundId ~= "" then
				local s = Instance.new("Sound")
				s.SoundId = soundId
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
