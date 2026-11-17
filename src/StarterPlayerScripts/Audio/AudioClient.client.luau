--!strict
-- StarterPlayerScripts/Audio/AudioClient.client.luau
-- Client-side audio initialization runtime.
-- Boots AudioManager, preloads critical combat/UI sound assets, and initializes the background music engine.

local AudioManager = require(script.Parent:WaitForChild("AudioManager"))
local MusicController = require(script.Parent:WaitForChild("MusicController"))

-- Warm every combat and UI sound in the background (clicks and hits first) so first plays are on time.
AudioManager.PreloadAll()

-- Initialize music controller (silent at startup / Hub; plays Tower and Boss tracks in the Tower)
MusicController.Init()
