--!strict
-- StarterPlayerScripts/Audio/AudioManager.luau
-- Central client audio driver for Infinite Tower.
-- Provides 2D and 3D sound playback with:
-- - SoundCatalog lookup with fallbacks and default volumes
-- - Lead-in trimming: each pack file starts at its measured onset (SoundCatalog.Resolve), set as the
--   Sound's PlaybackRegion so it holds even before the asset has loaded
-- - Late-cue dropping: a short cue whose asset has not loaded within LATE_DROP_SECONDS is skipped
--   rather than heard out of sync; long stingers wait up to LONG_CUE_WAIT
-- - Pitch micro-jittering, per-sound cooldowns and a cap on overlapping copies (MaxVoices)
-- - Distance culling via SoundPool
-- - SettingsAudioEngine compatibility: OrigVolume plus an AudioCategory attribute that picks the
--   SFX, Music or Ambience slider
-- - Warm cache: PreloadAll keeps one silent, idle Sound per SFX file in SoundService.AudioWarmCache.
--   ContentProvider:PreloadAsync only downloads; a new Sound still takes ~0.6 s to decode its asset
--   unless another Sound holding that asset is alive, and the decode is dropped ~20 s after the last
--   holder goes. Holding all SFX files costs about 28 MB of sound memory and makes every play instant.
-- - Quiet join: no cue plays until the loading screen has faded (LocalPlayer ClientLoaded, or after
--   READY_FALLBACK_SECONDS), so UI hovers and world decoration never sound behind it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local IS_STUDIO = RunService:IsStudio()

local LATE_DROP_SECONDS = 0.25 -- a short cue still loading after this is dropped, not played late
local LONG_CUE_SECONDS = 2.5 -- cues longer than this (stingers, fanfares) may wait for their asset
local LONG_CUE_WAIT = 3
local DEFAULT_MAX_VOICES = 4 -- overlapping copies of one cue
local READY_FALLBACK_SECONDS = 30 -- play anyway if the loading screen never reports ClientLoaded
local REGION_END = 1e4 -- PlaybackRegion.Max past the asset's length stops at its natural end
local WARM_BATCH = 16 -- holders created per step, so PRELOAD_FIRST cues decode first
local WARM_BATCH_WAIT = 2 -- seconds to let a batch decode before starting the next

-- Warmed first: the cues heard in the first seconds of play and on every click.
local PRELOAD_FIRST = {
	"Click", "Hover", "WindowOpen", "TabSwitch", "Error", "ToastIn", "Reward",
	"HitLight", "HitHeavy", "HitCrit", "HitWeak", "HitSkill", "HitIncoming", "MobDeath",
	"SlashSword", "SlashDagger", "BowDraw", "AirWhoosh", "KatanaUnsheath", "SwordUnsheath",
	"MagicSpark", "LightningArc", "Heal", "AbilityActivation", "HeroSpawnLanding",
	"FloorTeleportTransition", "BiomeBannerReveal", "CoinClink",
}

local Shared = ReplicatedStorage:WaitForChild("Shared", 10)
local configFolder = if Shared then Shared:WaitForChild("Config", 10) else nil
local soundCatalogModule = if configFolder then configFolder:WaitForChild("SoundCatalog", 10) else nil
local SoundCatalog = if soundCatalogModule and soundCatalogModule:IsA("ModuleScript") then require(soundCatalogModule) else nil
local SoundPool = require(script.Parent:WaitForChild("SoundPool"))

local AudioManager = {}

local bootClock = os.clock()
local clientReady = false

-- True once the join loading screen has faded (ReplicatedFirst/LoadingScreen sets ClientLoaded).
local function isClientReady(): boolean
	if clientReady then
		return true
	end
	local player = Players.LocalPlayer
	if (player and player:GetAttribute("ClientLoaded") == true) or os.clock() - bootClock > READY_FALLBACK_SECONDS then
		clientReady = true
	end
	return clientReady
end

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

-- Content ID to play and the second to start at.
local function resolveDef(def: any): (string?, number)
	if not def then
		return nil, 0
	end
	local cat = getCatalog()
	if cat and cat.Resolve then
		return cat.Resolve(def, IS_STUDIO)
	end
	if type(def.Id) == "string" and def.Id ~= "" then
		return def.Id, def.TimeOffset or 0
	end
	return nil, 0
end

local lastPlayed: { [string]: number } = {}
local tempAnchorsFolder: Folder? = nil
local playbackSeq = 0
local activeTokens: { [Sound]: number } = {}
local activeFadeTweens: { [Sound]: Tween } = {}
local activeNames: { [Sound]: string } = {}
local endedConns: { [Sound]: RBXScriptConnection } = {}
local voices: { [string]: number } = {}
local warmFolder: Folder? = nil
local warmHolders: { [string]: Sound } = {}

-- Keeps the asset decoded for as long as the client runs (see the header).
local function warm(soundId: string)
	if soundId == "" or warmHolders[soundId] then
		return
	end
	if not (warmFolder and warmFolder.Parent) then
		local folder = Instance.new("Folder")
		folder.Name = "AudioWarmCache"
		folder.Parent = SoundService
		warmFolder = folder
	end
	local holder = Instance.new("Sound")
	holder.Name = "Warm"
	holder.SoundId = soundId
	holder.Volume = 0
	holder:SetAttribute("AudioCategory", "SFX")
	holder:SetAttribute("OrigVolume", 0)
	holder.Parent = warmFolder
	warmHolders[soundId] = holder
end

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
	local name = activeNames[sound]
	activeNames[sound] = nil
	if name then
		voices[name] = math.max(0, (voices[name] or 1) - 1)
	end
	local ended = endedConns[sound]
	if ended then
		ended:Disconnect()
		endedConns[sound] = nil
	end
	cancelFadeTween(sound)
	sound.TimePosition = 0
	sound.PlaybackSpeed = 1
	sound.Looped = false
	sound.PlaybackRegionsEnabled = false
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

-- Checks cooldown and voice cap, then takes a pooled Sound set up for `name`. The caller parents it
-- and hands it to `launch`.
local function prepare(name: string, pitchOverride: number?, volumeScale: number?): (Sound?, number, any)
	if not isClientReady() then
		return nil, 0, nil
	end
	local def = getDef(name)
	local soundId, startAt = resolveDef(def)
	if not def or not soundId or soundId == "" then
		return nil, 0, nil
	end

	local now = os.clock()
	if def.Cooldown and (now - (lastPlayed[name] or 0)) < def.Cooldown then
		return nil, 0, nil
	end
	local maxVoices = if type(def.MaxVoices) == "number" then def.MaxVoices else DEFAULT_MAX_VOICES
	if (voices[name] or 0) >= maxVoices then
		return nil, 0, nil
	end

	local sound = SoundPool.Acquire()
	if not sound then
		return nil, 0, nil
	end
	lastPlayed[name] = now
	voices[name] = (voices[name] or 0) + 1

	playbackSeq += 1
	local token = playbackSeq
	activeTokens[sound] = token
	activeNames[sound] = name

	local jitter = 0
	if def.PitchVariance and def.PitchVariance > 0 then
		jitter = (math.random() - 0.5) * 2 * def.PitchVariance
	end
	local targetPitch = (pitchOverride or def.Pitch or 1.0) + jitter
	local targetVolume = (def.Volume or 0.6) * (volumeScale or 1.0)

	sound.SoundId = soundId
	sound.PlaybackSpeed = math.clamp(targetPitch, 0.2, 3.0)
	sound.Looped = false
	sound.TimePosition = 0
	if startAt > 0 then
		sound.PlaybackRegionsEnabled = true
		sound.PlaybackRegion = NumberRange.new(startAt, REGION_END)
	else
		sound.PlaybackRegionsEnabled = false
	end
	sound:SetAttribute("AudioCategory", def.Category or "SFX")
	sound:SetAttribute("OrigVolume", targetVolume)
	sound.Volume = targetVolume

	return sound, token, def
end

-- Plays a prepared, parented Sound as soon as its asset is ready. A short cue that is not ready in
-- time is dropped, so a hit or a click is never heard after the moment it belonged to.
local function launch(sound: Sound, token: number, def: any, tempAnchor: Part?)
	local started = false
	local function begin()
		if started or activeTokens[sound] ~= token then
			return
		end
		started = true
		sound:Play()
		schedulePlaybackEnvelope(sound, token, def, tempAnchor)
	end

	endedConns[sound] = sound.Ended:Once(function()
		releasePooledSound(sound, token, tempAnchor)
	end)

	if sound.IsLoaded then
		begin()
		return
	end

	-- Cold asset: keep it decoding even if this play is dropped, so the next one is on time.
	warm(sound.SoundId)
	local maxDur = def.MaxDuration
	local isLong = type(maxDur) ~= "number" or maxDur > LONG_CUE_SECONDS
	local loadedConn = sound.Loaded:Once(begin)
	task.delay(if isLong then LONG_CUE_WAIT else LATE_DROP_SECONDS, function()
		loadedConn:Disconnect()
		if not started then
			releasePooledSound(sound, token, tempAnchor)
		end
	end)
end

--============================================================================
-- 2D AUDIO PLAYBACK (UI, Global Stingers, Warnings)
--============================================================================

function AudioManager.Play2D(name: string, pitchOverride: number?, volumeScale: number?): Sound?
	local sound, token, def = prepare(name, pitchOverride, volumeScale)
	if not sound then
		return nil
	end
	sound.Name = "Audio2D_" .. name
	sound.Parent = SoundService
	launch(sound, token, def, nil)
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
	local pos = if typeof(target) == "Vector3" then target else (target :: BasePart).Position
	if not SoundPool.IsAudible(pos) then
		return nil
	end

	local sound, token, def = prepare(name, pitchOverride, volumeScale)
	if not sound then
		return nil
	end
	sound.Name = "Audio3D_" .. name
	sound.RollOffMinDistance = def.RollOffMin or 10
	sound.RollOffMaxDistance = def.RollOffMax or 75

	local tempAnchor: Part? = nil
	if typeof(target) == "Vector3" then
		local anchor = Instance.new("Part")
		anchor.Name = "AudioAnchor_" .. name
		anchor.Size = Vector3.new(0.1, 0.1, 0.1)
		anchor.Position = target
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanTouch = false
		anchor.CanQuery = false
		anchor.Transparency = 1
		anchor.CastShadow = false
		anchor.Parent = getTempFolder()
		sound.Parent = anchor
		tempAnchor = anchor
	else
		sound.Parent = target
	end

	launch(sound, token, def, tempAnchor)
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

-- Warms every SFX file (each variant included) in the background, the PRELOAD_FIRST cues first, so
-- the first hit, click or skill of a session is not late. Music and ambience stream on demand.
function AudioManager.PreloadAll()
	task.spawn(function()
		local cat = getCatalog()
		if not cat or not cat.PlayableIds then
			return
		end
		local ids = cat.PlayableIds({ SFX = true }, IS_STUDIO, PRELOAD_FIRST)
		for first = 1, #ids, WARM_BATCH do
			local batch: { Sound } = {}
			for i = first, math.min(first + WARM_BATCH - 1, #ids) do
				warm(ids[i])
				local holder = warmHolders[ids[i]]
				if holder then
					table.insert(batch, holder)
				end
			end
			local t0 = os.clock()
			repeat
				task.wait(0.1)
				local pending = false
				for _, holder in batch do
					if holder.Parent and not holder.IsLoaded then
						pending = true
						break
					end
				end
			until not pending or os.clock() - t0 > WARM_BATCH_WAIT
		end
	end)
end

-- False while the join loading screen is still up; UI code without a catalog entry checks it too.
AudioManager.IsClientReady = isClientReady

-- Kept for older callers.
AudioManager.PreloadCritical = AudioManager.PreloadAll

return AudioManager
