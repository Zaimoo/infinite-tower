--!strict
-- StarterPlayerScripts/Rendering/FountainVFXRuntime.client.luau
-- Client bootstrapper that starts the Central Gothic Goddess Fountain UV water scroller & VFX controller.

local FountainVFXController = require(script.Parent:WaitForChild("FountainVFXController"))
FountainVFXController.Start()
