--!strict
-- tests/relic-biome-config.spec.luau
-- Verification suite for 10-Biome, 40-Relic Configuration

local RelicConfig = require(nodes["ReplicatedStorage.Shared.RelicConfig"])
local ConfigRelicConfig = require(nodes["ReplicatedStorage.Shared.Config.RelicConfig"])

-- 1. Ensure Shared.RelicConfig and Shared.Config.RelicConfig refer to the same unified data
assert(RelicConfig == ConfigRelicConfig, "Both RelicConfig paths must resolve to the identical module")

-- 2. Validate all 10 Biomes
assert(type(RelicConfig.Biomes) == "table", "RelicConfig.Biomes must be a table")
local expectedBiomes = {
	[1] = { Name = "Verdant Ruins", Min = 1, Max = 5 },
	[2] = { Name = "Fungal Hollow", Min = 6, Max = 10 },
	[3] = { Name = "Ashen Dunes", Min = 11, Max = 15 },
	[4] = { Name = "Frozen Citadel", Min = 16, Max = 20 },
	[5] = { Name = "Thunder Spire", Min = 21, Max = 25 },
	[6] = { Name = "Molten Forge-Vaults", Min = 26, Max = 30 },
	[7] = { Name = "Necrotic Crypts", Min = 31, Max = 35 },
	[8] = { Name = "Aetherial Spire", Min = 36, Max = 40 },
	[9] = { Name = "Abyssal Depths", Min = 41, Max = 45 },
	[10] = { Name = "Celestial Apex", Min = 46, Max = 50 },
}

local totalBiomes = 0
local totalRelicsInBiomes = 0
local seenItemIds = {}

for biomeIndex = 1, 10 do
	local biome = RelicConfig.Biomes[biomeIndex]
	local exp = expectedBiomes[biomeIndex]
	assert(biome ~= nil, string.format("Missing Biome [%d]", biomeIndex))
	assert(biome.Name == exp.Name, string.format("Biome [%d] Name mismatch: got %s, expected %s", biomeIndex, biome.Name, exp.Name))
	assert(biome.FloorRange[1] == exp.Min and biome.FloorRange[2] == exp.Max, string.format("Biome [%d] FloorRange mismatch", biomeIndex))
	assert(#biome.DropTable == 4, string.format("Biome [%d] must contain exactly 4 relics in DropTable, found %d", biomeIndex, #biome.DropTable))
	totalBiomes += 1

	for tierIdx, itemId in ipairs(biome.DropTable) do
		assert(type(itemId) == "string" and #itemId > 0, "Invalid item ID string in drop table")
		assert(not seenItemIds[itemId], "Duplicate relic ID across biomes: " .. itemId)
		seenItemIds[itemId] = true
		totalRelicsInBiomes += 1

		local item = RelicConfig.Items[itemId]
		assert(item ~= nil, string.format("Item ID %s from Biome %d not found in RelicConfig.Items", itemId, biomeIndex))
		assert(item.BiomeIndex == biomeIndex, string.format("Item %s BiomeIndex mismatch", itemId))
		assert(item.BiomeTier == tierIdx, string.format("Item %s BiomeTier mismatch", itemId))
		assert(type(item.DisplayName) == "string" and #item.DisplayName > 0, "Item missing DisplayName: " .. itemId)
		assert(type(item.Rarity) == "string" and #item.Rarity > 0, "Item missing Rarity: " .. itemId)
		assert(type(item.SpeedPenalty) == "number" and item.SpeedPenalty > 0 and item.SpeedPenalty < 1, "Invalid SpeedPenalty for " .. itemId)
		assert(item.WalkSpeedPenalty == item.SpeedPenalty, "WalkSpeedPenalty must match SpeedPenalty for " .. itemId)
		assert(type(item.GoldValue) == "number" and item.GoldValue > 0, "Invalid GoldValue for " .. itemId)
		assert(type(item.GemValue) == "number" and item.GemValue > 0, "Invalid GemValue for " .. itemId)
		assert(item.Payout ~= nil and item.Payout.Gold == item.GoldValue and item.Payout.Gems == item.GemValue, "Payout mismatch for " .. itemId)
		assert(type(item.VisualDescription) == "string" and #item.VisualDescription > 0, "Missing VisualDescription for " .. itemId)
		assert(type(item.ModelAsset) == "string", "Missing ModelAsset for " .. itemId)

		-- Verify direct top-level access RelicConfig[itemId]
		assert(RelicConfig[itemId] == item, "RelicConfig[itemId] top-level access failed for " .. itemId)
	end
end

assert(totalBiomes == 10, "Expected 10 biomes")
assert(totalRelicsInBiomes == 40, "Expected 40 relics across 10 biomes")

-- 3. Verify Helper functions
for f = 1, 50 do
	local b = RelicConfig.GetBiomeForFloor(f)
	assert(b ~= nil, "GetBiomeForFloor failed for floor " .. f)
	assert(f >= b.FloorRange[1] and f <= b.FloorRange[2], "Floor out of range for floor " .. f)
end
assert(RelicConfig.GetBiomeForFloor(0) == nil, "Floor 0 should not resolve to a biome")
assert(RelicConfig.GetBiomeForFloor(51) == nil, "Floor 51 should not resolve to a biome")

for itemId, item in pairs(RelicConfig.Items) do
	assert(RelicConfig.GetItem(itemId) == item, "GetItem failed for " .. itemId)
end

for bIdx = 1, 10 do
	local relics = RelicConfig.GetBiomeRelics(bIdx)
	assert(#relics == 4, "GetBiomeRelics must return 4 items for biome " .. bIdx)
end

-- 4. Verify Backward Compatibility
assert(RelicConfig.MANA_GEODE ~= nil and RelicConfig.MANA_GEODE.Payout.Gems == 100, "Legacy MANA_GEODE gems")
assert(RelicConfig.CURSED_URN ~= nil and RelicConfig.CURSED_URN.Payout.Gems == 300, "Legacy CURSED_URN gems")
assert(RelicConfig.ABYSSAL_CORE ~= nil and RelicConfig.ABYSSAL_CORE.Payout.Gems == 1000, "Legacy ABYSSAL_CORE gems")
assert(RelicConfig.CALAMITY_HEART ~= nil and RelicConfig.CALAMITY_HEART.Payout.Gems == 5000, "Legacy CALAMITY_HEART gems")

-- 5. Verify Biome Drop Integration with TowerFloorConfig
local TowerFloorConfig = require(nodes["ReplicatedStorage.Shared.Config.TowerFloorConfig"])

-- Floor 17 (Frozen Citadel) must drop Frozen Citadel relics, NEVER Mana Geode
local f17Shard = TowerFloorConfig.RollRelic(17, "REGULAR", 0, 0.99)
assert(f17Shard == "RimefrostCrystalShard", "Floor 17 baseline shard must be RimefrostCrystalShard, got: " .. tostring(f17Shard))
assert(f17Shard ~= "MANA_GEODE", "Floor 17 must not drop MANA_GEODE")

local f17Urn = TowerFloorConfig.RollRelic(17, "REGULAR", 0, 0.0)
assert(f17Urn == "GlacialUrn", "Floor 17 regular top drop must be GlacialUrn, got: " .. tostring(f17Urn))

local f17Elite = TowerFloorConfig.RollRelic(17, "ELITE", 0, 0.0)
assert(f17Elite == "BorealValkyrieIdol", "Floor 17 elite top drop must be BorealValkyrieIdol, got: " .. tostring(f17Elite))

local f17Boss = TowerFloorConfig.RollRelic(17, "BOSS", 0, 0.0)
assert(f17Boss == "PermafrostCore", "Floor 17 boss drop must be PermafrostCore, got: " .. tostring(f17Boss))

-- Across all floors 1..50, baseline drops must be the biome's Tier 1 Shard and never Mana Geode
for floor = 1, 50 do
	local dropped = TowerFloorConfig.RollRelic(floor, "REGULAR", 0, 0.99)
	local biome = RelicConfig.GetBiomeForFloor(floor)
	assert(dropped == biome.DropTable[1], string.format("Floor %d dropped %s, expected %s", floor, tostring(dropped), biome.DropTable[1]))
	assert(dropped ~= "MANA_GEODE", string.format("Floor %d must never drop MANA_GEODE", floor))
end

print("PASS Relic biome config: all 10 biomes, 40 relics, helpers, Floor 17 Frozen Citadel drops, and backward compatibility verified")
