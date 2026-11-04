-- Phase D support Regular specs. Bundled by run.ps1 after the module list; `nodes`, `register` and `require` come from the shim.
local SupportRules = require(nodes["ReplicatedStorage.Shared.Util.SupportRules"])
local CampRoster = require(nodes["ReplicatedStorage.Shared.Util.CampRoster"])
local Mobs = require(nodes["ReplicatedStorage.Shared.Config.MobCatalog"])
local Combat = require(nodes["ReplicatedStorage.Shared.Config.FirstBiomeCombat"])
local Floors = require(nodes["ReplicatedStorage.Shared.Config.TowerFloorConfig"])
local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end
local function unit(x: number, z: number, hp: number?, maxHp: number?, state: string?): any
	return { Position = { X = x, Z = z }, CurrentHP = hp or 100, MaxHP = maxHp or 100, State = state }
end

test("Every biome has one support with a kit, a fragile stat line and a kit cast before its bolt", function()
	local kits = { MEND = 0, WARD = 0, ROUSE = 0 }
	for _, biome in Mobs.Biomes do
		local entry = assert(Mobs.Get(biome.SupportEnemyId))
		assert(entry.Role == "REGULAR" and entry.BiomeId == biome.Id and SupportRules.Kits[entry.Support])
		assert(not table.find(biome.RegularEnemyIds, biome.SupportEnemyId), "A support must not be dealt as a fighter")
		kits[entry.Support] += 1
		local spec = assert(Combat.Get(biome.SupportEnemyId))
		assert(spec.Support == entry.Support and spec.MaxHP < 850 and spec.ATK < 18)
		assert(spec.Attacks[1].Shape == SupportRules.Kits[entry.Support].Shape and spec.Attacks[1].DamageMultiplier == 0)
		assert(spec.Attacks[2].Shape == "PROJECTILE" and spec.Attacks[2].DamageMultiplier > 0)
	end
	assert(kits.MEND > 0 and kits.WARD > 0 and kits.ROUSE > 0)
end)

test("Support stats come from the floor's Regular row even though supports are not in the placement manifest", function()
	for floorId = 1, 50 do
		local floor = assert(Floors.Get(floorId))
		local support = Mobs.Biomes[floor.BiomeIndex].SupportEnemyId
		assert(Floors.GetEnemyStats(floorId, support), "No stats for " .. support .. " on floor " .. floorId)
	end
	-- Still no borrowing across biomes.
	assert(Floors.GetEnemyStats(1, Mobs.Biomes[2].SupportEnemyId) == nil)
end)

test("MEND picks the most hurt ally in range and holds when nobody is hurt", function()
	local caster = unit(0, 0)
	local light, heavy, far = unit(5, 0, 80), unit(-5, 0, 30), unit(80, 0, 5)
	assert(SupportRules.PickTarget("MEND", caster, { light, heavy, far }, {}, 0) == heavy)
	assert(SupportRules.PickTarget("MEND", caster, { unit(5, 0, 100), unit(-5, 0, 97) }, {}, 0) == nil)
end)

test("WARD shields the unshielded ally nearest the squad", function()
	local caster = unit(0, 0)
	local front, back = unit(10, 0), unit(-10, 0)
	local squad = { { X = 25, Z = 0 } }
	assert(SupportRules.PickTarget("WARD", caster, { front, back }, squad, 0) == front)
	front.ShieldUntil = 5
	assert(SupportRules.PickTarget("WARD", caster, { front, back }, squad, 1) == back)
	assert(SupportRules.PickTarget("WARD", caster, { front, back }, squad, 6) == front)
end)

test("ROUSE fires on itself only once an ally inside the aura is fighting", function()
	local caster = unit(0, 0)
	assert(SupportRules.PickTarget("ROUSE", caster, { unit(5, 0, 100, 100, "IDLE") }, {}, 0) == nil)
	assert(SupportRules.PickTarget("ROUSE", caster, { unit(30, 0, 100, 100, "CHASE") }, {}, 0) == nil)
	assert(SupportRules.PickTarget("ROUSE", caster, { unit(5, 0, 100, 100, "CHASE") }, {}, 0) == caster)
end)

test("Effects: MEND heals up to max, WARD soaks then expires, ROUSE buffs then fades, Reset clears", function()
	local ally = unit(0, 0, 50, 1000)
	assert(SupportRules.Apply("MEND", ally, 0) == 120 and ally.CurrentHP == 170)
	ally.CurrentHP = 990
	SupportRules.Apply("MEND", ally, 0)
	assert(ally.CurrentHP == 1000)
	SupportRules.Apply("WARD", ally, 10)
	assert(ally.Shield == 150 and SupportRules.Shielded(ally, 11))
	assert(SupportRules.Absorb(ally, 100, 11) == 0 and ally.Shield == 50)
	assert(SupportRules.Absorb(ally, 100, 11) == 50 and ally.Shield == 0)
	SupportRules.Apply("WARD", ally, 20)
	assert(SupportRules.Absorb(ally, 100, 27) == 100, "An expired shield must not soak")
	SupportRules.Apply("ROUSE", ally, 30)
	assert(SupportRules.AtkMultiplier(ally, 31) == 1.25 and SupportRules.SpeedMultiplier(ally, 31) == 1.2)
	assert(SupportRules.AtkMultiplier(ally, 36) == 1)
	SupportRules.Apply("WARD", ally, 40)
	SupportRules.Reset(ally)
	assert(not SupportRules.Shielded(ally, 41) and not SupportRules.Roused(ally, 41))
end)

test("A support kites KiteGap behind its anchor, on the side away from the hero", function()
	local spot = SupportRules.KitePoint({ X = 0, Z = 0 }, { X = 10, Z = 0 })
	assert(math.abs(spot.X + SupportRules.KiteGap) < 1e-6 and math.abs(spot.Z) < 1e-6)
	local still = SupportRules.KitePoint({ X = 3, Z = 4 }, { X = 3, Z = 4 })
	assert(math.abs(still.Z - (4 + SupportRules.KiteGap)) < 1e-6)
end)

test("About half the camps field a support, never more than half of them", function()
	local camps = { "A", "B", "C", "D", "E", "F", "G" }
	local total = 0
	for seed = 1, 2000 do
		local chosen = CampRoster.AssignSupports(CampRoster.Rng(seed), camps)
		local n = 0
		for id in chosen do assert(table.find(camps, id)); n += 1 end
		assert(n <= 4)
		total += n
		-- A rerolled camp never pushes the floor over the cap.
		local full = { A = true, B = true, C = true, D = true }
		assert(CampRoster.RerollSupport(CampRoster.Rng(seed), "E", full, #camps) == false)
	end
	local average = total / 2000
	assert(average > 2 and average < 4, "Support share looks wrong: " .. average)
end)

print("Support tests: " .. passed .. " passed, 0 failed")
