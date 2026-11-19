--!strict
-- tests/runesmith-sanctuary.spec.luau
-- Verifies Blender-exported Runesmith Sanctuary geometry shards, bounds, materials,
-- and HubLayout chasm/bridge spatial parity.

local HubLayout = require(nodes["ReplicatedStorage.Shared.Config.HubLayout"])
local RunesmithMeshData = require(nodes["ReplicatedStorage.Assets.RunesmithMeshData"])

local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end

test("RunesmithMeshData exposes all 21 sanctuary sub-meshes across all 5 collections", function()
	local specs = RunesmithMeshData.Models.runesmith_sanctuary
	assert(type(specs) == "table" and #specs == 21, "expected 21 sanctuary mesh parts, got " .. tostring(specs and #specs))

	local byName: { [string]: RunesmithMeshData.PartMeshSpec } = {}
	local subCols: { [string]: number } = {}
	for _, s in specs do
		byName[s.Name] = s
		subCols[s.SubCollection] = (subCols[s.SubCollection] or 0) + 1
	end

	for _, requiredCol in { "RunesmithAnvil", "FloatingPlatform", "FloatingRingsAndChains", "SanctuaryBridge", "ChasmRim" } do
		assert((subCols[requiredCol] or 0) > 0, "missing sub-collection: " .. requiredCol)
	end
	for _, requiredPart in {
		"Anvil_BasePlate",
		"Anvil_Body",
		"Anvil_MoltenCore",
		"Anvil_SideRunes",
		"Anvil_TopSigil",
		"Platform_TopFlagstones",
		"Platform_RockSpire",
		"Ring_LowerStone",
		"Ring_LowerRunes",
		"Ring_UpperStone",
		"Ring_UpperRunes",
		"Bridge_WalkwayDeck",
		"Bridge_StoneAbutments",
		"Bridge_IronLattice",
		"Bridge_CanopyRings",
		"Hub_ChasmWall",
	} do
		assert(byName[requiredPart] ~= nil, "missing part: " .. requiredPart)
	end
end)

test("Every Runesmith sanctuary shard decodes valid vertex & triangle buffers within Roblox MeshPart limits", function()
	local specs = RunesmithMeshData.Models.runesmith_sanctuary
	for _, spec in specs do
		local verts, tris = RunesmithMeshData.GetGeometry(spec)
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

test("Sanctuary bridge, elevated platform, and chasm rim align with HubLayout.ReforgeStation", function()
	local specs = RunesmithMeshData.Models.runesmith_sanctuary
	local byName: { [string]: RunesmithMeshData.PartMeshSpec } = {}
	for _, s in specs do
		byName[s.Name] = s
	end

	local ref = HubLayout.ReforgeStation
	local anvil = byName.Anvil_BasePlate
	local deck = byName.Bridge_WalkwayDeck
	local chasm = byName.Hub_ChasmWall

	assert(anvil.Offset.Y - anvil.Size.Y * 0.5 >= ref.PlatformElevation, "anvil sits atop the elevated floating platform")
	assert(deck.Offset.Z < -ref.PlatformRadius, "bridge spans out along -Z toward Wayfinder Dais")
	assert(math.abs(chasm.Size.X * 0.5 - ref.HoleRadius) < 4, "chasm wall matches HubLayout.ReforgeStation.HoleRadius")
end)

print(string.format("runesmith-sanctuary: %d passed", passed))
