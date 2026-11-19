--!strict
-- HubPathMeshData.luau
-- Aggregator for packed Blender cobblestone path geometry.

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

return {
	PartCount = #shards,
	Shards = shards,
	ByPartName = byPartName,
}
