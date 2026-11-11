--!strict
-- StarterPlayerScripts/Audio/AudioClient.client.luau
-- Client-side audio initialization runtime.
-- Boots AudioManager, preloads critical combat/UI sound assets, and initializes the background music engine.

local AudioManager = require(script.Parent:WaitForChild("AudioManager"))
local MusicController = require(script.Parent:WaitForChild("MusicController"))

-- Preload hot-path audio cues (swords, hits, whistles, clicks)
AudioManager.PreloadCritical()

-- Initialize background fantasy music
MusicController.Init()
