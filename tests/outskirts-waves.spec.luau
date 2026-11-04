-- Outskirts Guard Post wave defense unit tests.
-- Bundled by tests/run.ps1 after the module list; `nodes`, `register` and `require` come from the shim.
local OutskirtsRules = require(nodes["ReplicatedStorage.Shared.Util.OutskirtsRules"])
local TowerFloorConfig = require(nodes["ReplicatedStorage.Shared.Config.TowerFloorConfig"])
local MobCatalog = require(nodes["ReplicatedStorage.Shared.Config.MobCatalog"])
local FirstBiomeCombat = require(nodes["ReplicatedStorage.Shared.Config.FirstBiomeCombat"])
local TowerEnemyClips = require(nodes["ReplicatedStorage.Assets.TowerEnemyClips"])

local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end

local function inBounds(p: any, label: string)
	local b = OutskirtsRules.Bounds
	assert(
		p.X >= b.MinX and p.X <= b.MaxX and p.Z >= b.MinZ and p.Z <= b.MaxZ,
		string.format("%s out of OutskirtsGrounds bounds: (%.1f, %.1f)", label, p.X, p.Z)
	)
end

test("ResolveFrontierFloor maps progression across Floor 0 -> 1, Floor 5 -> 6, Floor 15 -> 16, and Floor 50 cap", function()
	local f0 = OutskirtsRules.ResolveFrontierInfo(0, 1)
	assert(f0.FloorId == 1 and f0.BiomeId == "verdant_ruins", "New save should resolve to Floor 1 verdant_ruins")

	local f5 = OutskirtsRules.ResolveFrontierInfo(5, 6)
	assert(f5.FloorId == 6 and f5.BiomeId == "fungal_hollow", "Cleared Floor 5 should advance frontier to Floor 6 fungal_hollow")

	local f15 = OutskirtsRules.ResolveFrontierInfo(15, 16)
	assert(f15.FloorId == 16 and f15.BiomeId == "frozen_citadel", "Cleared Floor 15 should advance frontier to Floor 16 frozen_citadel")

	local f50 = OutskirtsRules.ResolveFrontierInfo(50, 51)
	assert(f50.FloorId == 50 and f50.BiomeId == "abyssal_throne", "Cleared Floor 50 should cap at Floor 50 abyssal_throne")
end)

test("Every floor 1..50 resolves valid biome enemies, combat specs, and animation clips without spawning giant Biome Bosses", function()
	for floorId = 1, TowerFloorConfig.FloorCount do
		local floor = assert(TowerFloorConfig.Get(floorId))
		local info = OutskirtsRules.ResolveFrontierInfo(floorId - 1, floorId)
		assert(info.FloorId == floorId and info.BiomeId == floor.BiomeId)
		assert(MobCatalog.Get(info.PreviewEnemyId) ~= nil, "Missing preview enemy in MobCatalog: " .. info.PreviewEnemyId)
		assert(FirstBiomeCombat.Get(info.PreviewEnemyId) ~= nil, "Missing preview enemy in FirstBiomeCombat: " .. info.PreviewEnemyId)
		assert(TowerEnemyClips[info.PreviewEnemyId] ~= nil, "Missing preview enemy clips: " .. info.PreviewEnemyId)

		for waveIdx = 1, 4 do
			local roster = OutskirtsRules.ResolveWaveRoster(floorId, 3, 2, waveIdx)
			assert(#roster >= 3 and #roster <= 6, "Wave size out of bounds on floor " .. floorId)

			local anyBuildingTarget = false
			for _, entry in ipairs(roster) do
				local cat = MobCatalog.Get(entry.EnemyId)
				local spec = FirstBiomeCombat.Get(entry.EnemyId)
				local clips = TowerEnemyClips[entry.EnemyId]
				assert(cat ~= nil, "Missing MobCatalog entry: " .. entry.EnemyId)
				assert(spec ~= nil, "Missing FirstBiomeCombat entry: " .. entry.EnemyId)
				assert(clips ~= nil, "Missing TowerEnemyClips entry: " .. entry.EnemyId)
				assert(cat.BiomeId == floor.BiomeId, "Wave enemy biome mismatch on floor " .. floorId)
				assert(cat.Role ~= "BOSS", "Full 22-stud Biome Bosses should not spawn in Outskirts waves: " .. entry.EnemyId)
				assert(clips.Idle and clips.Locomotion and clips.BasicAttack and clips.HitReaction and clips.Death)
				assert(entry.LaneIndex >= 1 and entry.LaneIndex <= #OutskirtsRules.SpawnLanes)
				assert(entry.HitsToDefeat >= 3 and entry.HitsToDefeat <= 6)
				if entry.TargetsBuildingFirst then
					anyBuildingTarget = true
				end
			end
			assert(anyBuildingTarget, "Each wave should include at least one raider targeting Building_GuardPost")

			if floor.IndexInBiome == 4 then
				assert(roster[1].Role == "ELITE", "4th floor of biome should lead with an Elite")
			elseif floor.IndexInBiome == 5 then
				assert(roster[1].Role == "ALPHA", "5th floor of biome should lead with the gilded Biome Alpha")
			end
		end
	end
end)

test("All Outskirts gatehouse, defender, trail, campfire, and treeline spawn waypoints stay inside OutskirtsGrounds", function()
	inBounds(OutskirtsRules.GuardPostCenter, "GuardPostCenter")
	for i, wp in ipairs(OutskirtsRules.GatehouseRunIn) do
		inBounds(wp, "GatehouseRunIn[" .. i .. "]")
	end
	for i, wp in ipairs(OutskirtsRules.BuildingAttackTargets) do
		inBounds(wp, "BuildingAttackTargets[" .. i .. "]")
	end
	for i, wp in ipairs(OutskirtsRules.CampfireRestSlots) do
		inBounds(wp, "CampfireRestSlots[" .. i .. "]")
	end
	for i, slot in ipairs(OutskirtsRules.DefenderSlots) do
		inBounds(slot.Rally, "DefenderSlots[" .. i .. "].Rally")
		inBounds(OutskirtsRules.TrailPoint(slot.PatrolMinX), "PatrolMin[" .. i .. "]")
		inBounds(OutskirtsRules.TrailPoint(slot.PatrolMaxX), "PatrolMax[" .. i .. "]")
	end
	for i, lane in ipairs(OutskirtsRules.SpawnLanes) do
		inBounds(lane.Spawn, "SpawnLane[" .. i .. "].Spawn")
		inBounds(lane.Mid, "SpawnLane[" .. i .. "].Mid")
		inBounds(lane.BuildingTarget, "SpawnLane[" .. i .. "].BuildingTarget")
		assert(lane.Spawn.Z > lane.Mid.Z and lane.Mid.Z > lane.BuildingTarget.Z, "Spawn lane must march north from treeline to Guard Post")
	end
end)

print("Outskirts wave tests: " .. passed .. " passed, 0 failed")
