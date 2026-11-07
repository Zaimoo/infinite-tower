--!strict
-- StarterPlayerScripts/Rendering/SynthesisDoorRuntime.client.luau
-- Client bootstrapper that initializes the Synthesis Chamber outward-opening double doors.

local SynthesisDoorController = require(script.Parent:WaitForChild("SynthesisDoorController"))
SynthesisDoorController.Init()
