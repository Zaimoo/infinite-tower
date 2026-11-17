--!strict
-- StarterPlayerScripts/Audio/MusicController.luau
-- Seamless dual-player background music & biome ambience crossfader for Infinite Tower.
-- Manages:
-- - Hub Sanctuary music vs Tower Biome tracks (Biomes 1-10) + Duel/Raid themes
-- - Secondary biome ambience loop layer synced to SG_Ambience
-- - Milestone Boss battle themes
-- - Victory and Defeat stingers with dynamic music ducking
-- - Smooth volume crossfading via TweenService
-- - Synchronized with SettingsAudioEngine via SoundGroups (SG_Music, SG_Ambience) and OrigVolume tagging

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local IS_STUDIO = RunService:IsStudio()

local Shared = ReplicatedStorage:WaitForChild("Shared", 10)
local configFolder = if Shared then Shared:WaitForChild("Config", 10) else nil
local soundCatalogModule = if configFolder then configFolder:WaitForChild("SoundCatalog", 10) else nil
local SoundCatalog = if soundCatalogModule and soundCatalogModule:IsA("ModuleScript") then require(soundCatalogModule) else nil

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

-- Content ID to play and the second to start at (the track's silent intro is skipped).
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

-- Starts (and, for looped players, loops) from `startAt`. PlaybackRegion holds before the asset has
-- loaded, unlike TimePosition, and its Min is also where a loop restarts.
local function setStart(sound: Sound, startAt: number)
	sound.TimePosition = 0
	if startAt > 0 then
		sound.PlaybackRegionsEnabled = true
		sound.PlaybackRegion = NumberRange.new(startAt, 1e5)
	else
		sound.PlaybackRegionsEnabled = false
	end
end

local function getBiomeMusicKey(biomeIndex: number): string
	local cat = getCatalog()
	return if cat then cat.GetBiomeMusicKey(biomeIndex) else "Biome1_Verdant"
end

local function getBiomeAmbienceKey(biomeIndex: number): string?
	local cat = getCatalog()
	if cat and cat.GetBiomeAmbienceKey then
		return cat.GetBiomeAmbienceKey(biomeIndex)
	end
	return nil
end

type ChannelState = {
	namePrefix: string,
	category: "Music" | "Ambience",
	getGroup: () -> SoundGroup,
	activeIndex: number,
	activeKey: string,
	players: { Sound },
	tokens: { number },
	tweens: { Tween? },
}

local MusicController = {}
local isInitialized = false

local function getOrCreateSoundGroup(primaryName: string, legacyName: string, defaultVolume: number): SoundGroup
	local sg = SoundService:FindFirstChild(primaryName)
	if sg and sg:IsA("SoundGroup") then
		return sg
	end
	local fallback = SoundService:FindFirstChild(legacyName)
	if fallback and fallback:IsA("SoundGroup") then
		return fallback
	end
	local newGroup = Instance.new("SoundGroup")
	newGroup.Name = primaryName
	newGroup.Volume = defaultVolume
	newGroup.Parent = SoundService
	return newGroup
end

local function getMusicGroup(): SoundGroup
	return getOrCreateSoundGroup("SG_Music", "Music", 0.55)
end

local function getAmbienceGroup(): SoundGroup
	return getOrCreateSoundGroup("SG_Ambience", "Ambience", 0.50)
end

local function createChannel(namePrefix: string, category: "Music" | "Ambience", getGroup: () -> SoundGroup): ChannelState
	return {
		namePrefix = namePrefix,
		category = category,
		getGroup = getGroup,
		activeIndex = 1,
		activeKey = "",
		players = {},
		tokens = { 0, 0 },
		tweens = { nil, nil },
	}
end

local musicChannel = createChannel("MusicPlayer_", "Music", getMusicGroup)
local ambienceChannel = createChannel("AmbiencePlayer_", "Ambience", getAmbienceGroup)

local function cancelChannelTween(channel: ChannelState, index: number)
	local tw = channel.tweens[index]
	if tw then
		tw:Cancel()
		channel.tweens[index] = nil
	end
end

local function tweenChannelVolume(channel: ChannelState, index: number, player: Sound, info: TweenInfo, targetVolume: number)
	cancelChannelTween(channel, index)
	local tw = TweenService:Create(player, info, { Volume = targetVolume })
	channel.tweens[index] = tw
	tw:Play()
end

local function initChannelPlayers(channel: ChannelState)
	local sg = channel.getGroup()
	for i = 1, 2 do
		local s = Instance.new("Sound")
		s.Name = channel.namePrefix .. tostring(i)
		s.Looped = true
		s.Volume = 0
		s:SetAttribute("AudioCategory", channel.category)
		s.SoundGroup = sg
		s.Parent = SoundService
		channel.players[i] = s
	end
end

local function stopChannel(channel: ChannelState, duration: number?)
	channel.activeKey = ""

	local fadeTime = duration or 2.0
	for index, player in ipairs(channel.players) do
		cancelChannelTween(channel, index)
		channel.tokens[index] += 1
		local stopToken = channel.tokens[index]

		if player.IsPlaying then
			if fadeTime <= 0 then
				player.Volume = 0
				player:Stop()
			else
				tweenChannelVolume(
					channel,
					index,
					player,
					TweenInfo.new(fadeTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
					0
				)
				task.delay(fadeTime + 0.05, function()
					if channel.tokens[index] == stopToken then
						player:Stop()
					end
				end)
			end
		end
	end
end

local function crossfadeChannel(channel: ChannelState, trackKey: string, duration: number?)
	if not channel.players[1] or not channel.players[2] then
		return
	end

	local activePlayer = channel.players[channel.activeIndex]
	if trackKey == channel.activeKey and activePlayer and activePlayer.IsPlaying then
		return
	end

	local def = getDef(trackKey)
	local soundId, startAt = resolveDef(def)
	if not def or not soundId or soundId == "" then
		stopChannel(channel, duration)
		return
	end

	local fadeTime = duration or 2.0
	local prevIndex = channel.activeIndex
	local nextIndex = if channel.activeIndex == 1 then 2 else 1
	local curPlayer = channel.players[prevIndex]
	local nextPlayer = channel.players[nextIndex]

	channel.activeKey = trackKey
	channel.activeIndex = nextIndex
	channel.tokens[nextIndex] += 1

	local targetVol = def.Volume or 0.5
	nextPlayer.SoundId = soundId
	nextPlayer.PlaybackSpeed = def.Pitch or 1.0
	setStart(nextPlayer, startAt)
	nextPlayer:SetAttribute("OrigVolume", targetVol)
	nextPlayer.Volume = 0
	nextPlayer:Play()

	tweenChannelVolume(
		channel,
		nextIndex,
		nextPlayer,
		TweenInfo.new(fadeTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		targetVol
	)

	if curPlayer and curPlayer.IsPlaying then
		channel.tokens[prevIndex] += 1
		local fadeToken = channel.tokens[prevIndex]
		tweenChannelVolume(
			channel,
			prevIndex,
			curPlayer,
			TweenInfo.new(fadeTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			0
		)
		task.delay(fadeTime + 0.05, function()
			if channel.tokens[prevIndex] == fadeToken then
				curPlayer:Stop()
			end
		end)
	end
end

function MusicController.Stop(duration: number?)
	stopChannel(musicChannel, duration)
end

function MusicController.CrossfadeTo(trackKey: string, duration: number?)
	crossfadeChannel(musicChannel, trackKey, duration)
end

function MusicController.StopAmbience(duration: number?)
	stopChannel(ambienceChannel, duration)
end

function MusicController.CrossfadeAmbienceTo(trackKey: string, duration: number?)
	crossfadeChannel(ambienceChannel, trackKey, duration)
end

function MusicController.PlayDuelMusic()
	MusicController.CrossfadeTo("DuelArenaTheme", 1.2)
	MusicController.StopAmbience(1.0)
end

function MusicController.PlayRaidMusic()
	MusicController.CrossfadeTo("RaidBossTheme", 1.5)
	MusicController.CrossfadeAmbienceTo("AmbienceMechaWarfare", 2.0)
end

function MusicController.PlaySanctuaryHubMusic()
	MusicController.CrossfadeTo("SanctuaryHubTheme", 2.0)
end

function MusicController.PlayForFloor(floorId: number?)
	if type(floorId) ~= "number" or floorId <= 0 then
		-- Floor 0 is Hub Cloister Commons: stay silent in the Hub
		MusicController.Stop(2.5)
		MusicController.StopAmbience(2.0)
		return
	end

	if floorId == 60 then
		MusicController.PlayRaidMusic()
		return
	end

	-- 50 Floors across 10 Biomes (5 floors per biome)
	local biomeIndex = math.clamp(math.floor((floorId - 1) / 5) + 1, 1, 10)
	local isBossFloor = (floorId % 5 == 0)

	if isBossFloor then
		MusicController.CrossfadeTo("BossBattleTheme", 1.8)
	else
		local trackKey = getBiomeMusicKey(biomeIndex)
		MusicController.CrossfadeTo(trackKey, 2.2)
	end

	local ambKey = getBiomeAmbienceKey(biomeIndex)
	if ambKey then
		MusicController.CrossfadeAmbienceTo(ambKey, 2.5)
	else
		MusicController.StopAmbience(2.0)
	end
end

-- Temporarily ducks the current music, plays a stinger sound (e.g. Victory / Defeat),
-- then smoothly restores the BGM volume.
function MusicController.PlayStinger(stingerKey: string, duckDuration: number?)
	local def = getDef(stingerKey)
	local soundId, startAt = resolveDef(def)
	if not def or not soundId or soundId == "" then return end

	local stingerPlayerIndex = musicChannel.activeIndex
	local stingerTrackKey = musicChannel.activeKey
	local stingerToken = musicChannel.tokens[stingerPlayerIndex]
	local curPlayer = musicChannel.players[stingerPlayerIndex]
	local origVol = (curPlayer and curPlayer:GetAttribute("OrigVolume")) or 0.5
	local dur = duckDuration or (def.MaxDuration or 4.0)
	local restored = false

	-- Duck music by 65%
	if curPlayer and curPlayer.IsPlaying and stingerTrackKey ~= "" then
		tweenChannelVolume(musicChannel, stingerPlayerIndex, curPlayer, TweenInfo.new(0.3, Enum.EasingStyle.Quad), origVol * 0.35)
	end

	local function restoreMusic()
		if restored then return end
		restored = true
		if
			curPlayer
			and curPlayer.IsPlaying
			and musicChannel.activeIndex == stingerPlayerIndex
			and musicChannel.activeKey == stingerTrackKey
			and musicChannel.tokens[stingerPlayerIndex] == stingerToken
		then
			tweenChannelVolume(musicChannel, stingerPlayerIndex, curPlayer, TweenInfo.new(1.2, Enum.EasingStyle.Quad), origVol)
		end
	end

	local stinger = Instance.new("Sound")
	stinger.Name = "Stinger_" .. stingerKey
	stinger.SoundId = soundId
	stinger.PlaybackSpeed = def.Pitch or 1.0
	setStart(stinger, startAt)
	stinger:SetAttribute("AudioCategory", "Music")
	stinger.SoundGroup = getMusicGroup()
	local stingerVol = def.Volume or 0.8
	stinger:SetAttribute("OrigVolume", stingerVol)
	stinger.Volume = stingerVol
	stinger.Parent = SoundService
	stinger:Play()

	stinger.Ended:Once(function()
		stinger:Destroy()
		restoreMusic()
	end)

	-- Fallback / MaxDuration envelope
	task.delay(dur, function()
		if stinger.Parent then stinger:Destroy() end
		restoreMusic()
	end)
end

function MusicController.Init()
	if isInitialized then return end
	isInitialized = true

	initChannelPlayers(musicChannel)
	initChannelPlayers(ambienceChannel)

	-- Listen to Tower Floor / Travel context
	task.spawn(function()
		local Remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
		if not Remotes then return end
		local tower = Remotes:WaitForChild("TowerRemotes", 15)
		if not tower then return end
		local context = tower:WaitForChild("Context", 15)
		if context and context:IsA("RemoteEvent") then
			context.OnClientEvent:Connect(function(c: any)
				if type(c) ~= "table" then return end
				MusicController.PlayForFloor(c.FloorId)
			end)
		end
	end)
end

return MusicController
