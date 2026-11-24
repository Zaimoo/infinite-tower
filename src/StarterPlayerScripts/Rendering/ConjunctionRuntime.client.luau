--!strict
-- StarterPlayerScripts/Rendering/ConjunctionRuntime.client.luau
-- Client bootstrapper that starts the Astral Archives Conjunction ambience controller (Floors 41–45).

local Conjunction = require(script.Parent:WaitForChild("Conjunction"))
Conjunction.Start()
