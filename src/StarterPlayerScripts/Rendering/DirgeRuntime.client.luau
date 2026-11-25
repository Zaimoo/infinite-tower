--!strict
-- StarterPlayerScripts/Rendering/DirgeRuntime.client.luau
-- Client bootstrapper that starts the Abyssal Throne Dirge ambience controller (Floors 46–50).

local Dirge = require(script.Parent:WaitForChild("Dirge"))
Dirge.Start()
