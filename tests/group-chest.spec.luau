--!strict
-- tests/group-chest.spec.luau
-- Verifies Blender-exported Group Chest geometry shards, sub-collections, hinge pivot, and MeshPart budgets.

local GroupChestMeshData = require(nodes["ReplicatedStorage.Assets.GroupChestMeshData"])

local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end

test("GroupChestMeshData exposes all 18 parts across ChestBase (6), ChestLid (6), and ChestGlitch (6)", function()
	local specs = GroupChestMeshData.Models.group_chest
	assert(type(specs) == "table" and #specs == 18, "expected 18 group_chest mesh parts, got " .. tostring(specs and #specs))

	local byName: { [string]: GroupChestMeshData.PartMeshSpec } = {}
	local subCols: { [string]: number } = {}
	for _, s in specs do
		byName[s.Name] = s
		subCols[s.SubCollection] = (subCols[s.SubCollection] or 0) + 1
	end

	assert(subCols.ChestBase == 6, "expected 6 ChestBase parts, got " .. tostring(subCols.ChestBase))
	assert(subCols.ChestLid == 6, "expected 6 ChestLid parts, got " .. tostring(subCols.ChestLid))
	assert(subCols.ChestGlitch == 6, "expected 6 ChestGlitch parts, got " .. tostring(subCols.ChestGlitch))

	for _, requiredPart in {
		"Base_GoldPlinth",
		"Base_CornerPillars",
		"Base_CrystalWalls",
		"Base_InnerGlitchCore",
		"Base_LockEscutcheon",
		"Base_DiamondGems",
		"Lid_GoldArches",
		"Lid_CrystalDome",
		"Lid_InnerCore",
		"Lid_CrownMount",
		"Lid_ApexDiamond",
		"Lid_FrontClasp",
		"Glitch_Shard_1",
		"Glitch_Shard_2",
		"Glitch_Shard_3",
		"Glitch_Shard_4",
		"Glitch_Shard_5",
		"Glitch_Shard_6",
	} do
		assert(byName[requiredPart] ~= nil, "missing part: " .. requiredPart)
	end
end)

test("GroupChestMeshData exposes a valid HingePivot at the back lip of the chest base", function()
	local pivot = GroupChestMeshData.HingePivot
	assert(pivot ~= nil, "HingePivot must be defined")
	assert(pivot.Y > 0 and pivot.Z > 0, "HingePivot must sit above ground on the +Z hinge back edge")
end)

test("Every Group Chest shard decodes valid vertex & triangle buffers within Roblox MeshPart limits", function()
	local specs = GroupChestMeshData.Models.group_chest
	for _, spec in specs do
		local verts, tris = GroupChestMeshData.GetGeometry(spec)
		assert(#verts >= 9 and #verts % 3 == 0, spec.Name .. " has invalid vertex buffer")
		assert(#tris >= 3 and #tris % 3 == 0, spec.Name .. " has invalid triangle buffer")
		local triCount = #tris // 3
		assert(triCount <= 9500, string.format("%s exceeds triangle budget (%d)", spec.Name, triCount))
		local vertCount = #verts // 3
		for i = 1, #tris do
			local idx = tris[i]
			assert(idx >= 1 and idx <= vertCount, string.format("%s index out of range: %d", spec.Name, idx))
		end
		assert(spec.Size.X > 0 and spec.Size.Y > 0 and spec.Size.Z > 0, spec.Name .. " size must be positive")
	end
end)

print(string.format("group-chest: %d passed", passed))
