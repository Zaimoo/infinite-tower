--!strict
-- StarterPlayerScripts/Rendering/TowerAtmosphereRuntime.client.luau
-- Client bootstrapper that starts the Central Gothic Tower atmospheric VFX & light pulsing controller.

local TowerAtmosphereController = require(script.Parent:WaitForChild("TowerAtmosphereController"))
TowerAtmosphereController.Start()
