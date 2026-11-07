--!strict
-- tests/inventory-capacity.spec.luau
-- Storage branch of the Fortress Tree and the hero/artifact backpack caps (InventoryCapacity).

local TreeConfig = require(nodes["ReplicatedStorage.Shared.Config.FortressTreeConfig"])
local FortressTree = require(nodes["ReplicatedStorage.Shared.Util.FortressTree"])
local InventoryCapacity = require(nodes["ReplicatedStorage.Shared.Util.InventoryCapacity"])

local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end

local function treeWith(level: number): any
	local tree = FortressTree.DefaultTree()
	for i = 1, level do tree.Nodes["st_" .. i] = true end
	return tree
end

test("base caps are 50 heroes and 50 artifacts", function()
	assert(InventoryCapacity.HeroCap(nil) == 50 and InventoryCapacity.ArtifactCap(nil) == 50, "base caps")
	local tree = FortressTree.DefaultTree()
	assert(InventoryCapacity.HeroCap(tree) == 50 and InventoryCapacity.ArtifactCap(tree) == 50, "default tree caps")
end)

test("Storage nodes alternate +25 heroes and +25 artifacts", function()
	local expected = { { 75, 50 }, { 75, 75 }, { 100, 75 }, { 100, 100 }, { 125, 100 }, { 125, 125 } }
	for level, caps in expected do
		local tree = treeWith(level)
		assert(InventoryCapacity.HeroCap(tree) == caps[1], "hero cap at Storage " .. level)
		assert(InventoryCapacity.ArtifactCap(tree) == caps[2], "artifact cap at Storage " .. level)
	end
end)

test("Storage nodes chain from the root with rising costs and floor gates", function()
	local previousGold, previousGate = 0, 0
	for level = 1, 6 do
		local node = TreeConfig.ById["st_" .. level]
		assert(node and node.Kind == "LEVEL" and node.Facility == TreeConfig.StorageFacility, "st_" .. level .. " exists")
		assert(node.Requires[1] == (if level == 1 then "root" else "st_" .. (level - 1)), "chain")
		assert(node.Gold > previousGold and node.FloorGate >= previousGate, "progression")
		previousGold, previousGate = node.Gold, node.FloorGate
	end
	local unlocks = { FortressTree = true }
	assert(not FortressTree.CanUnlock(FortressTree.DefaultTree(), "st_2", 1e9, 50, unlocks), "st_2 needs st_1")
	assert(FortressTree.CanUnlock(FortressTree.DefaultTree(), "st_1", 1e9, 0, unlocks), "st_1 buyable")
end)

test("a gap in owned Storage nodes stops the level count", function()
	local tree = treeWith(1)
	tree.Nodes.st_3 = true
	assert(InventoryCapacity.HeroCap(tree) == 75 and InventoryCapacity.ArtifactCap(tree) == 50, "gap ignored")
end)

test("facility workers are out of the backpack and the hero count", function()
	local profile = {
		Heroes = {
			a = { Assignment = "BENCHED" },
			b = { Assignment = "SQUAD_SLOT_1" },
			c = { Assignment = "FACILITY_MARKET" },
			d = { Assignment = "FACILITY_GUARD_POST" },
		},
		Artifacts = { x = {}, y = {} },
	}
	assert(InventoryCapacity.IsInFacility(profile.Heroes.c), "market worker is in a facility")
	assert(not InventoryCapacity.IsInFacility(profile.Heroes.b), "squad hero is not")
	assert(InventoryCapacity.HeroCount(profile) == 2, "only backpack heroes count")
	assert(InventoryCapacity.ArtifactCount(profile) == 2, "artifact count")
	profile.Heroes.c.Assignment = "BENCHED"
	assert(InventoryCapacity.HeroCount(profile) == 3, "unassigned hero returns to the count")
end)

print(string.format("inventory-capacity: %d passed", passed))
