--!strict
-- StarterPlayerScripts/Rendering/PortalEffectRuntime.client.luau
-- Client bootstrapper that starts the Gothic Summoning Portal state & VFX controller.

local PortalEffectController = require(script.Parent:WaitForChild("PortalEffectController"))
PortalEffectController.Start()
