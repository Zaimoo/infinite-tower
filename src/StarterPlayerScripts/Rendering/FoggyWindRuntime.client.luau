--!strict
-- StarterPlayerScripts/Rendering/FoggyWindRuntime.client.luau
-- Client runtime bootstrapper for Foggy & Windy Weather effects.

local FoggyWindController = require(script.Parent:WaitForChild("FoggyWindController"))
FoggyWindController.Start()
