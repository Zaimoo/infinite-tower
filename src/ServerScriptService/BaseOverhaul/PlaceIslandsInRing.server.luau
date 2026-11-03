--!strict
-- PlaceIslandsInRing.server.luau
-- Server entry for the Central Hub: builds (or reuses baked) hub geometry via HubOverhaul,
-- wires the runtime-only listeners, then lays the bridges and the Pilgrim's Causeway.

local BaseOverhaulFolder = script.Parent
local HubOverhaul = require(BaseOverhaulFolder:WaitForChild("HubOverhaul"))
local BridgeBuilder = require(BaseOverhaulFolder:WaitForChild("BridgeBuilder"))

local container, rebuilt = HubOverhaul.Build(false)
HubOverhaul.StartRuntime(container, rebuilt)
BridgeBuilder.Build()
