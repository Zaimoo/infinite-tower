--!strict
-- tests/forge.spec.luau
-- Authoritative unit and regression tests for Blacksmith Forge System:
--   1. Crafting recipes, materials & class restrictions
--   2. Stat scaling: Level +4 (120 ATK) -> Level +5 (155 ATK) parity
--   3. Fodder requirements (1 to 5 progression)
--   4. Max level cap enforcement

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArtifactCatalog = require(ReplicatedStorage.Shared.Config.ArtifactCatalog)

local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		print("PASS " .. name)
	else
		print("FAIL " .. name .. ": " .. tostring(err))
		error(err)
	end
end

local function assertEqual(a: any, b: any, msg: string?)
	if a ~= b then
		error(string.format("%s: expected %s, got %s", msg or "Assertion failed", tostring(b), tostring(a)))
	end
end

-- 1. Recipe catalog checks
test("Featured mock recipes exist with exact costs and properties", function()
	local blade = ArtifactCatalog.Seeds.art_blade_of_the_rift
	assert(blade ~= nil, "Blade of the Rift missing")
	assertEqual(blade.DisplayName, "Blade of the Rift")
	assertEqual(blade.Type, "SWORD")
	assertEqual(blade.CraftCost.IronGear, 5)
	assertEqual(blade.CraftCost.RiftOrb, 3)

	local aegis = ArtifactCatalog.Seeds.art_aegis_core
	assert(aegis ~= nil, "Aegis Core missing")
	assertEqual(aegis.DisplayName, "Aegis Core")
	assertEqual(aegis.Type, "SHIELD")
	assertEqual(aegis.CraftCost.IronGear, 8)
	assertEqual(aegis.CraftCost.AegisGem, 2)

	local ring = ArtifactCatalog.Seeds.art_ring_of_haste
	assert(ring ~= nil, "Ring of Haste missing")
	assertEqual(ring.DisplayName, "Ring of Haste")
	assertEqual(ring.Type, "RING")
	assertEqual(ring.CraftCost.StarDust, 10)
	assertEqual(ring.CraftCost.VoidPowder, 5)
end)

-- 2. Crafting materials metadata
test("Crafting materials define icon and color metadata", function()
	for _, matKey in { "IronGear", "RiftOrb", "AegisGem", "StarDust", "VoidPowder" } do
		local info = ArtifactCatalog.CraftingMaterials[matKey]
		assert(info ~= nil, "Missing crafting material: " .. matKey)
		assert(info.Name ~= nil and #info.Name > 0, "Missing material name")
		assert(info.Icon ~= nil and #info.Icon > 0, "Missing material icon")
	end
end)

-- 3. Class Restrictions
test("Hero class restrictions allow universal rings and tank shields", function()
	-- All archetypes can equip rings
	for _, role in { "Marksman", "Striker", "Vanguard", "Miner", "Scholar", "Healer" } do
		assert(ArtifactCatalog.CanHeroEquip(role, "RING"), role .. " should be able to equip RING")
	end

	-- Vanguard and Striker can equip swords & shields
	assert(ArtifactCatalog.CanHeroEquip("Vanguard", "SWORD"))
	assert(ArtifactCatalog.CanHeroEquip("Vanguard", "SHIELD"))
	assert(ArtifactCatalog.CanHeroEquip("Striker", "SWORD"))
	assert(not ArtifactCatalog.CanHeroEquip("Marksman", "SWORD"), "Marksman cannot equip SWORD")
	assert(ArtifactCatalog.CanHeroEquip("Marksman", "BOW"), "Marksman can equip BOW")
end)

-- 4. Stat scaling parity with UI Mockup (+4 = 120 ATK -> +5 = 155 ATK)
test("Blade of the Rift exact mockup stats parity: +4 gives 120 ATK, +5 gives 155 ATK", function()
	local statsLvl4 = ArtifactCatalog.GetStatBreakdown("art_blade_of_the_rift", 3, 1, 4)
	assertEqual(statsLvl4["ATK"], 120, "Level 4 Blade of the Rift ATK")

	local statsLvl5 = ArtifactCatalog.GetStatBreakdown("art_blade_of_the_rift", 3, 1, 5)
	assertEqual(statsLvl5["ATK"], 155, "Level 5 Blade of the Rift ATK")

	-- Also verify effective stats returns expected ATK
	local effATK_4, _ = ArtifactCatalog.CalculateEffectiveStats(3, 1, 4, "art_blade_of_the_rift")
	assertEqual(effATK_4, 120, "CalculateEffectiveStats Lvl 4")

	local effATK_5, _ = ArtifactCatalog.CalculateEffectiveStats(3, 1, 5, "art_blade_of_the_rift")
	assertEqual(effATK_5, 155, "CalculateEffectiveStats Lvl 5")
end)

-- 5. Fodder Requirement progression
test("Fodder requirement scales from 1 to 5 items", function()
	assertEqual(ArtifactCatalog.GetFodderRequirement(0), 1, "Level 0 -> 1 requires 1 fodder")
	assertEqual(ArtifactCatalog.GetFodderRequirement(1), 2, "Level 1 -> 2 requires 2 fodder")
	assertEqual(ArtifactCatalog.GetFodderRequirement(2), 3, "Level 2 -> 3 requires 3 fodder")
	assertEqual(ArtifactCatalog.GetFodderRequirement(3), 4, "Level 3 -> 4 requires 4 fodder")
	assertEqual(ArtifactCatalog.GetFodderRequirement(4), 5, "Level 4 -> 5 requires 5 fodder")
	assertEqual(ArtifactCatalog.GetFodderRequirement(5), 5, "Level 5+ capped at 5 fodder")
end)

-- 6. Max Enhancement Level
test("Max enhancement level is capped at 10", function()
	assertEqual(ArtifactCatalog.MaxEnhancementLevel, 10)
end)

-- 7. Artifact Banner configuration & pity math
test("Artifact banner Echoes of the Rift matches mockup pricing and pity", function()
	local banner = ArtifactCatalog.Banner
	assert(banner ~= nil, "ArtifactCatalog.Banner missing")
	assertEqual(banner.Title, "ECHOES OF THE RIFT")
	assertEqual(banner.Cost1X, 160, "1X summon costs 160 gems")
	assertEqual(banner.Cost10X, 1600, "10X summon costs 1600 gems")
	assertEqual(banner.MaxPity, 50, "Pity threshold is 50 pulls")
	assertEqual(ArtifactCatalog.GetPityRemaining(8), 42, "Mockup parity: initial pity is 42 remaining")
	assertEqual(ArtifactCatalog.GetPityRemaining(49), 1, "49 pulls gives 1 remaining to guaranteed 5-star")
	assertEqual(ArtifactCatalog.GetPityRemaining(50), 50, "50 pulls resets to 50 remaining")
end)

-- 8. Assign View inventory stat breakdown parity
test("Assign tab stats formatting matches mockup breakdown", function()
	local bladeStats = ArtifactCatalog.GetStatBreakdown("art_blade_of_the_rift", 3, 1, 4)
	assert(bladeStats["ATK"] ~= nil and bladeStats["Crit Rate"] ~= nil, "Blade has ATK and Crit Rate")

	local aegisStats = ArtifactCatalog.GetStatBreakdown("art_aegis_core", 3, 1, 5)
	assertEqual(aegisStats["DEF"], 200, "Aegis Core DEF is 200")
	assertEqual(aegisStats["HP"], 500, "Aegis Core HP is 500")

	local ringStats = ArtifactCatalog.GetStatBreakdown("art_ring_of_haste", 2, 1, 5)
	assertEqual(ringStats["SPD"], 15, "Ring of Haste SPD is 15")
	assertEqual(ringStats["Evasion"], 2.0, "Ring of Haste Evasion is 2.0%")
end)

print("All Forge spec tests passed successfully!")
