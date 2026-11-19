--!strict
-- HubPathMeshData.luau
-- Aggregator for packed Blender cobblestone path & fantasy castle bridge geometry.

local HubPathMeshesFolder = script.Parent:WaitForChild("HubPathMeshes")

export type HubPathShard = {
	name: string,
	partName: string,
	material: string,
	color: { number },
	center: { number },
	size: { number },
	vb: { number },
	nb: { number },
	ub: { number },
	tb: { number },
	ntb: { number },
	uvtb: { number },
}

local shards: { HubPathShard } = require(HubPathMeshesFolder:WaitForChild("hub_cobble_paths")) :: { HubPathShard }

local byPartName: { [string]: HubPathShard } = {}
for _, shard in ipairs(shards) do
	byPartName[shard.partName] = shard
end

local meshIds: { [string]: string } = {
		["Hub_GateSpoke_1"] = "rbxassetid://106962389213737",
		["Hub_GateSpoke_2"] = "rbxassetid://139987270948906",
		["Hub_GateSpoke_3"] = "rbxassetid://120603868000249",
		["Hub_GateSpoke_4"] = "rbxassetid://116504468807023",
		["Hub_GateSpoke_5"] = "rbxassetid://135371697228307",
		["Hub_GateSpoke_6"] = "rbxassetid://120300368459961",
		["Hub_GateSpoke_7"] = "rbxassetid://119305298528379",
		["Hub_GateSpoke_8"] = "rbxassetid://124918670521400",
		["Hub_OverlookTerraceTop"] = "rbxassetid://88468847294378",
		["Hub_PilgrimsWay"] = "rbxassetid://94971171165999",
		["Hub_PlazaApronDeck"] = "rbxassetid://96774851182066",
		["Hub_PlotBridgeDeck"] = "rbxassetid://114374214933629",
		["Hub_PlotBridgeParapets"] = "rbxassetid://74759472766134",
		["Hub_PlotBridgeSpires"] = "rbxassetid://138985941124184",
		["Hub_SpurPath"] = "rbxassetid://133305419184203",
}

return {
	PartCount = #shards,
	Shards = shards,
	ByPartName = byPartName,
	MeshIds = meshIds,
}
