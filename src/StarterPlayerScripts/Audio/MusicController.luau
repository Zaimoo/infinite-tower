--!strict
-- StarterPlayerScripts/Audio/MusicController.luau
-- Seamless dual-player background fantasy music crossfader for Infinite Tower.
-- Manages:
-- - Hub Sanctuary music vs Tower Biome tracks (Biomes 1-10)
-- - Milestone Boss battle themes
-- - Victory and Defeat stingers with dynamic music ducking
-- - Smooth volume crossfading via TweenService
-- - Synchronized with SettingsAudioEngine via SoundGroup SG_Music and OrigVolume tagging

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared", 10)
local configFolder = if Shared then Shared:WaitForChild("Config", 10) else nil
local soundCatalogModule = if configFolder then configFolder:WaitForChild("SoundCatalog", 10) else nil
local SoundCatalog = if soundCatalogModule and soundCatalogModule:IsA("ModuleScript") then require(soundCatalogModule) else nil

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

local function getBiomeMusicKey(biomeIndex: number): string
	if not SoundCatalog then
		local cfg = if Shared then Shared:FindFirstChild("Config") else nil
		local sc = if cfg then cfg:FindFirstChild("SoundCatalog") else nil
		if sc and sc:IsA("ModuleScript") then
			SoundCatalog = require(sc)
		end
	end
	return if SoundCatalog then SoundCatalog.GetBiomeMusicKey(biomeIndex) else "Biome1_Verdant"
end

local MusicController = {}

local activePlayerIndex = 1
local players: { Sound } = {}
local playerTokens: { number } = { 0, 0 }
local activeTweens: { Tween? } = { nil, nil }
local activeTrackKey = ""
local isInitialized = false

local function cancelPlayerTween(index: number)
	local tw = activeTweens[index]
	if tw then
		tw:Cancel()
		activeTweens[index] = nil
	end
end

local function tweenPlayerVolume(index: number, player: Sound, info: TweenInfo, targetVolume: number)
	cancelPlayerTween(index)
	local tw = TweenService:Create(player, info, { Volume = targetVolume })
	activeTweens[index] = tw
	tw:Play()
end

local function getMusicGroup(): SoundGroup
	local sg = SoundService:FindFirstChild("SG_Music")
	if sg and sg:IsA("SoundGroup") then
		return sg
	end
	local fallback = SoundService:FindFirstChild("Music")
	if fallback and fallback:IsA("SoundGroup") then
		return fallback
	end
	local newGroup = Instance.new("SoundGroup")
	newGroup.Name = "SG_Music"
	newGroup.Volume = 0.55
	newGroup.Parent = SoundService
	return newGroup
end

local function createMusicPlayer(index: number): Sound
	local s = Instance.new("Sound")
	s.Name = "MusicPlayer_" .. index
	s.Looped = true
	s.Volume = 0
	s.SoundGroup = getMusicGroup()
	s.Parent = SoundService
	return s
end

function MusicController.Stop(duration: number?)
	activeTrackKey = ""

	local fadeTime = duration or 2.0
	for index, player in ipairs(players) do
		cancelPlayerTween(index)
		playerTokens[index] += 1
		local stopToken = playerTokens[index]

		if player.IsPlaying then
			if fadeTime <= 0 then
				player.Volume = 0
				player:Stop()
			else
				tweenPlayerVolume(
					index,
					player,
					TweenInfo.new(fadeTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
					0
				)
				task.delay(fadeTime + 0.05, function()
					if playerTokens[index] == stopToken then
						player:Stop()
					end
				end)
			end
		end
	end
end

function MusicController.CrossfadeTo(trackKey: string, duration: number?)
	if not players[1] or not players[2] then
		return
	end

	if trackKey == activeTrackKey and players[activePlayerIndex] and players[activePlayerIndex].IsPlaying then
		return
	end

	local def = getDef(trackKey)
	if not def or def.Id == "" then
		MusicController.Stop(duration)
		return
	end

	local fadeTime = duration or 2.0
	local prevIndex = activePlayerIndex
	local nextIndex = if activePlayerIndex == 1 then 2 else 1
	local curPlayer = players[prevIndex]
	local nextPlayer = players[nextIndex]

	activeTrackKey = trackKey
	activePlayerIndex = nextIndex
	playerTokens[nextIndex] += 1

	-- Prepare next player
	nextPlayer.SoundId = def.Id
	nextPlayer.PlaybackSpeed = def.Pitch or 1.0
	nextPlayer.Volume = 0
	nextPlayer:SetAttribute("OrigVolume", def.Volume or 0.5)
	nextPlayer:Play()

	local targetVol = def.Volume or 0.5
	tweenPlayerVolume(
		nextIndex,
		nextPlayer,
		TweenInfo.new(fadeTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		targetVol
	)

	-- Fade out current player
	if curPlayer and curPlayer.IsPlaying then
		playerTokens[prevIndex] += 1
		local fadeToken = playerTokens[prevIndex]
		tweenPlayerVolume(
			prevIndex,
			curPlayer,
			TweenInfo.new(fadeTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			0
		)
		task.delay(fadeTime + 0.05, function()
			if playerTokens[prevIndex] == fadeToken then
				curPlayer:Stop()
			end
		end)
	end
end

-- Temporarily ducks the current music, plays a stinger sound (e.g. Victory / Defeat),
-- then smoothly restores the BGM volume.
function MusicController.PlayStinger(stingerKey: string, duckDuration: number?)
	local def = getDef(stingerKey)
	if not def or def.Id == "" then return end

	local stingerPlayerIndex = activePlayerIndex
	local stingerTrackKey = activeTrackKey
	local stingerToken = playerTokens[stingerPlayerIndex]
	local curPlayer = players[stingerPlayerIndex]
	local origVol = (curPlayer and curPlayer:GetAttribute("OrigVolume")) or 0.5
	local dur = duckDuration or 4.0
	local restored = false

	-- Duck music by 65%
	if curPlayer and curPlayer.IsPlaying and stingerTrackKey ~= "" then
		tweenPlayerVolume(stingerPlayerIndex, curPlayer, TweenInfo.new(0.3, Enum.EasingStyle.Quad), origVol * 0.35)
	end

	local function restoreMusic()
		if restored then return end
		restored = true
		if
			curPlayer
			and curPlayer.IsPlaying
			and activePlayerIndex == stingerPlayerIndex
			and activeTrackKey == stingerTrackKey
			and playerTokens[stingerPlayerIndex] == stingerToken
		then
			tweenPlayerVolume(stingerPlayerIndex, curPlayer, TweenInfo.new(1.2, Enum.EasingStyle.Quad), origVol)
		end
	end

	local stinger = Instance.new("Sound")
	stinger.Name = "Stinger_" .. stingerKey
	stinger.SoundId = def.Id
	stinger.Volume = def.Volume or 0.8
	stinger.PlaybackSpeed = def.Pitch or 1.0
	stinger.SoundGroup = getMusicGroup()
	stinger:SetAttribute("OrigVolume", def.Volume or 0.8)
	stinger.Parent = SoundService
	stinger:Play()

	stinger.Ended:Once(function()
		stinger:Destroy()
		restoreMusic()
	end)

	-- Fallback timeout
	task.delay(dur, function()
		if stinger.Parent then stinger:Destroy() end
		restoreMusic()
	end)
end

function MusicController.Init()
	if isInitialized then return end
	isInitialized = true

	players[1] = createMusicPlayer(1)
	players[2] = createMusicPlayer(2)

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
				local floorId = c.FloorId
				if type(floorId) ~= "number" or floorId <= 0 then
					-- Floor 0 is Hub Cloister Commons: stay silent in the Hub
					MusicController.Stop(2.5)
				else
					-- 50 Floors across 10 Biomes (5 floors per biome)
					local biomeIndex = math.clamp(math.floor((floorId - 1) / 5) + 1, 1, 10)
					local isBossFloor = (floorId % 5 == 0)

					if isBossFloor then
						MusicController.CrossfadeTo("BossBattleTheme", 1.8)
					else
						local trackKey = getBiomeMusicKey(biomeIndex)
						MusicController.CrossfadeTo(trackKey, 2.2)
					end
				end
			end)
		end
	end)
end

return MusicController
