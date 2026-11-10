--!strict
-- tests/relic-biome-config.spec.luau
-- Relic tiers and their biome skins: 4 base tiers carry the economy, 10 biomes reskin them (40 relics).

local RelicConfig = require(nodes["ReplicatedStorage.Shared.Config.RelicConfig"])
local TowerFloorConfig = require(nodes["ReplicatedStorage.Shared.Config.TowerFloorConfig"])
local MobCatalog = require(nodes["ReplicatedStorage.Shared.Config.MobCatalog"])

-- 1. The four base tiers hold the relic economy (GDD §5.5).
local BASE = { MANA_GEODE = 100, CURSED_URN = 300, ABYSSAL_CORE = 1000, CALAMITY_HEART = 5000 }
for tier, tierId in ipairs(RelicConfig.BaseTiers) do
	local spec = RelicConfig[tierId]
	assert(spec and spec.TierId == tierId and spec.BaseTierId == tierId and spec.BiomeTier == tier, tierId .. " base tier")
	assert(spec.Payout.Gems == BASE[tierId], tierId .. " gems")
	assert(spec.GemValue == spec.Payout.Gems and spec.GoldValue == spec.Payout.Gold, tierId .. " value fields")
end

-- 2. Every biome reskins all four tiers and copies every gameplay number from them.
local MECHANICS = { "Rarity", "WalkSpeedPenalty", "SpeedPenalty", "DisableJump", "DespawnSeconds", "InitialLockSeconds", "GoldValue", "GemValue" }
local seen = {}
local count = 0
assert(#RelicConfig.Biomes == 10, "10 biomes")
for biomeIndex, biome in ipairs(RelicConfig.Biomes) do
	assert(biome.Name == MobCatalog.Biomes[biomeIndex].DisplayName,
		string.format("Biome %d is named %s, the tower calls it %s", biomeIndex, biome.Name, MobCatalog.Biomes[biomeIndex].DisplayName))
	assert(biome.FloorRange[1] == (biomeIndex - 1) * 5 + 1 and biome.FloorRange[2] == biomeIndex * 5, "Biome floor range")
	assert(#biome.DropTable == 4, "4 relics per biome")
	for tier, itemId in ipairs(biome.DropTable) do
		assert(not seen[itemId], "Duplicate relic id " .. itemId)
		seen[itemId] = true
		count += 1
		local item = RelicConfig.Items[itemId]
		local base = RelicConfig[RelicConfig.BaseTiers[tier]]
		assert(item and RelicConfig[itemId] == item and RelicConfig.GetItem(itemId) == item, itemId .. " lookup")
		assert(item.TierId == itemId and item.BaseTierId == base.TierId, itemId .. " ids")
		assert(item.BiomeIndex == biomeIndex and item.BiomeTier == tier, itemId .. " biome and tier")
		for _, key in MECHANICS do
			assert(item[key] == base[key], string.format("%s.%s must match %s", itemId, key, base.TierId))
		end
		assert(item.Payout.Gems == base.Payout.Gems and item.Payout.Gold == base.Payout.Gold
			and item.Payout.PromotionStones == base.Payout.PromotionStones, itemId .. " payout follows its tier")
		assert(#item.DisplayName > 0 and #item.VisualDescription > 0 and item.Color ~= nil and item.Color ~= base.Color, itemId .. " skin")
		assert(item.DisplayName ~= base.DisplayName, itemId .. " has its own name")
	end
	assert(#RelicConfig.GetBiomeRelics(biomeIndex) == 4, "GetBiomeRelics")
end
assert(count == 40, "40 biome relics")

-- 3. Floors resolve to their biome, and only 1..50 do.
for floorId = 1, 50 do
	local biome = RelicConfig.GetBiomeForFloor(floorId)
	assert(biome and floorId >= biome.FloorRange[1] and floorId <= biome.FloorRange[2], "floor " .. floorId)
end
assert(RelicConfig.GetBiomeForFloor(0) == nil and RelicConfig.GetBiomeForFloor(51) == nil, "no biome outside 1..50")

-- 4. RollRelic returns the floor's skin of the rolled tier.
local frozen = RelicConfig.GetBiomeForFloor(17).DropTable
assert(TowerFloorConfig.RollRelic(17, "REGULAR", 0, 0.99) == frozen[1], "floor 17 Geode")
assert(TowerFloorConfig.RollRelic(17, "REGULAR", 0, 0.0) == frozen[2], "floor 17 regular top roll is an Urn")
assert(TowerFloorConfig.RollRelic(17, "ELITE", 0, 0.0) == frozen[3], "floor 17 Elite top roll is a Core")
assert(TowerFloorConfig.RollRelic(17, "BOSS", 0, 0.0) == frozen[4], "floor 17 boss top roll is a Heart")
for floorId = 1, 50 do
	local dropped = TowerFloorConfig.RollRelic(floorId, "REGULAR", 0, 0.99)
	assert(dropped == RelicConfig.GetBiomeForFloor(floorId).DropTable[1], "floor " .. floorId .. " baseline drop")
end

print("PASS Relic biome config: 4 tiers carry the economy, 40 biome skins copy them, drops follow the floor's biome")
