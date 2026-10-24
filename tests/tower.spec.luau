-- Part 1/4 data & content completeness gate. Executes shipped modules.
local Floors = require(nodes["ReplicatedStorage.Shared.Config.TowerFloorConfig"])
local Mobs = require(nodes["ReplicatedStorage.Shared.Config.MobCatalog"])
local Combat = require(nodes["ReplicatedStorage.Shared.Config.FirstBiomeCombat"])
local Clips = require(nodes["ReplicatedStorage.Assets.TowerEnemyClips"])
local Heroes = require(nodes["ReplicatedStorage.Shared.Config.HeroCatalog"])
local Stats = require(nodes["ReplicatedStorage.Shared.Util.StatFormulas"])
local passed, failed = 0, 0
local function test(name, callback)
	local ok, err = pcall(callback)
	if ok then passed += 1; print("PASS " .. name)
	else failed += 1; print("FAIL " .. name .. ": " .. tostring(err)) end
end
local function count(value)
	local n = 0
	for _ in pairs(value) do n += 1 end
	return n
end
local function finiteNonnegative(value)
	assert(type(value) == "number" and value == value and value >= 0 and value < math.huge, "Invalid numeric scaling")
end

test("Exactly 50 immediately available floors form ten complete groups", function()
	assert(Floors.FloorCount == 50 and count(Floors.Floors) == 50)
	assert(#Mobs.Biomes == 10 and count(Mobs.Biomes) == 10)
	assert(Floors.Get(0) == nil and Floors.HubFloorId == 0)
	local groups, names, biomeIds = {}, {}, {}
	for index, biome in ipairs(Mobs.Biomes) do
		assert(not biomeIds[biome.Id]); biomeIds[biome.Id] = true
		for id = (index - 1) * 5 + 1, index * 5 do
			local floor = assert(Floors.Get(id))
			assert(floor.Id == id and floor.BiomeIndex == index and floor.BiomeId == biome.Id)
			assert(floor.BiomeDisplayName == biome.DisplayName)
			assert(floor.IndexInBiome == (id - 1) % 5 + 1)
			assert(floor.Unlocked == true and floor.UnlockRequirement == nil)
			assert(#floor.DisplayName > 0 and not names[floor.DisplayName]); names[floor.DisplayName] = true
			groups[biome.Id] = (groups[biome.Id] or 0) + 1
		end
	end
	assert(count(groups) == 10)
	for _, size in pairs(groups) do assert(size == 5) end
end)

test("Each floor has unique declared layout/environment IDs with honest content status", function()
	assert(count(Floors.Layouts) == 50 and count(Floors.Environments) == 50)
	local layouts, environments = {}, {}
	for _, floor in pairs(Floors.Floors) do
		assert(string.match(floor.LayoutId, "^[a-z][a-z0-9_]+$"))
		assert(string.match(floor.EnvironmentVariantId, "^[a-z][a-z0-9_]+$"))
		assert(not layouts[floor.LayoutId] and not environments[floor.EnvironmentVariantId])
		layouts[floor.LayoutId] = true; environments[floor.EnvironmentVariantId] = true
		local layout = assert(Floors.Layouts[floor.LayoutId])
		local environment = assert(Floors.Environments[floor.EnvironmentVariantId])
		assert(layout.FloorId == floor.Id and environment.FloorId == floor.Id)
		assert(layout.BiomeId == floor.BiomeId and environment.BiomeId == floor.BiomeId)
		assert(layout.Status == "LOCAL_AUTHORED_PROTOTYPE" and environment.Status == "LOCAL_AUTHORED_PROTOTYPE" and floor.ContentStatus == "LOCAL_AUTHORED_PROTOTYPE")
		assert((layout.VariantKind == "BOSS_ARENA") == (floor.Id % 5 == 0))
	end
end)

test("Ten unique bosses occur only on multiples of five; encounters reference their biome", function()
	local bosses = {}
	for id = 1, 50 do
		local floor = Floors.Get(id)
		local biome = Mobs.Biomes[math.ceil(id / 5)]
		local bossCount, seen = 0, {}
		for _, encounter in ipairs(floor.Encounters) do
			local enemy = assert(Mobs.Get(encounter.EnemyId), "Unknown enemy reference")
			assert(enemy.BiomeId == floor.BiomeId and not seen[enemy.Id]); seen[enemy.Id] = true
			assert(encounter.Count > 0 and encounter.Count % 1 == 0)
			if enemy.Role == "BOSS" then
				bossCount += encounter.Count
				assert(enemy.Id == floor.BossEnemyId and enemy.Id == biome.BossEnemyId)
			end
		end
		assert(seen[biome.RegularEnemyIds[1]] and seen[biome.RegularEnemyIds[2]])
		if id % 5 == 0 then
			assert(bossCount == 1 and floor.BossEnemyId == biome.BossEnemyId and not bosses[floor.BossEnemyId])
			bosses[floor.BossEnemyId] = true
		else assert(bossCount == 0 and floor.BossEnemyId == nil) end
	end
	assert(count(bosses) == 10)
end)

test("Manifest covers 40 enemies with local authored rigs/clips and no fabricated uploaded IDs", function()
	assert(count(Mobs.Entries) == 40)
	local roleCounts, referenced = { REGULAR = 0, ELITE = 0, BOSS = 0 }, {}
	for _, biome in ipairs(Mobs.Biomes) do
		assert(#biome.RegularEnemyIds == 2)
		for _, id in ipairs({ biome.RegularEnemyIds[1], biome.RegularEnemyIds[2], biome.EliteEnemyId, biome.BossEnemyId }) do
			assert(not referenced[id]); referenced[id] = true
			assert(Mobs.Get(id).BiomeId == biome.Id)
		end
	end
	for id, enemy in pairs(Mobs.Entries) do
		assert(id == enemy.Id and referenced[id])
		roleCounts[enemy.Role] += 1
		for _, asset in ipairs({ enemy.Model, enemy.Rig, enemy.Source, enemy.Effects }) do
			assert(asset.Status == "LOCAL_AUTHORED_UNVERIFIED" and asset.AssetId == nil)
		end
		assert(enemy.Audio.Status == "MISSING" and enemy.Audio.AssetId == nil)
		assert(enemy.Bounds.Status == "LOCAL_AUTHORED_UNVERIFIED" and #enemy.Anatomy.Description > 0)
		assert(#enemy.Anatomy.LocomotionMode > 0 and enemy.Rig.Pivot.Status == "LOCAL_AUTHORED_UNVERIFIED" and enemy.Rig.FloorContact.Status == "LOCAL_AUTHORED_UNVERIFIED")
		assert(enemy.Source.PlannedModelSourcePath and enemy.Source.PlannedAnimationSourcePath)
		for _, axis in ipairs({ "Width", "Height", "Depth" }) do finiteNonnegative(enemy.Bounds[axis]); assert(enemy.Bounds[axis] > 0) end
		for _, slot in ipairs({ "Idle", "Locomotion", "BasicAttack", "HitReaction", "Death" }) do
			assert(enemy.Animations[slot].Status == "LOCAL_AUTHORED_UNVERIFIED")
		end
		for slot, animation in pairs(enemy.Animations) do
			assert(animation.Status == "LOCAL_AUTHORED_UNVERIFIED" and animation.AnimationId == nil)
			assert(Clips[id] and Clips[id][slot], "Missing authored clip for " .. id .. "." .. slot)
		end
		assert(Combat.Get(id), "Missing executable combat entry for " .. id)
	end
	assert(roleCounts.REGULAR == 20 and roleCounts.ELITE == 10 and roleCounts.BOSS == 10)
end)

test("Authored attack contract has anticipation, one server impact, recovery and cancellation", function()
	local ids = {}
	for _, enemy in pairs(Mobs.Entries) do
		assert(#enemy.Attacks == (if enemy.Role == "BOSS" then 3 elseif enemy.Role == "ELITE" then 2 else 1))
		for _, attack in ipairs(enemy.Attacks) do
			assert(not ids[attack.Id]); ids[attack.Id] = true
			assert(enemy.Animations[attack.AnimationKey].Status == "LOCAL_AUTHORED_UNVERIFIED")
			for _, key in ipairs({ "Windup", "ReleaseTime", "ImpactTime", "TravelDuration", "Recovery", "Duration" }) do finiteNonnegative(attack[key]) end
			assert(attack.Windup > 0 and attack.Recovery > 0)
			assert(attack.ReleaseTime == attack.Windup and attack.ImpactTime == attack.ReleaseTime + attack.TravelDuration)
			assert(attack.Duration == attack.ImpactTime + attack.Recovery)
			if attack.Kind == "PROJECTILE" then assert(attack.TravelDuration > 0) end
			assert(string.match(attack.ImpactRule, "^SERVER_.*SAME_FLOOR_ONCE$"))
			assert(attack.CancelOnDeath and attack.CancelOnContextChange)
			assert(attack.Effects.Status == "LOCAL_AUTHORED_UNVERIFIED" and attack.Audio.Status == "MISSING")
			assert(attack.Gameplay.Status == "LOCAL_AUTHORED_UNVERIFIED" and #attack.Gameplay.RequiredFields > 0)
		end
	end
end)

test("Invalid destinations and absent encounter IDs fail without coercion or boundary wrap", function()
	for _, value in ipairs({ -math.huge, -1, 0, .5, 1.5, 50.1, 51, math.huge, 0 / 0, "1", true, {} }) do
		assert(not Floors.IsFloorId(value) and Floors.Get(value) == nil)
	end
	assert(Floors.Get(nil) == nil and Floors.GetAdjacent(1, -1) == nil and Floors.GetAdjacent(50, 1) == nil)
	assert(Floors.GetAdjacent(1, 1).Id == 2 and Floors.GetAdjacent(50, -1).Id == 49)
	assert(Floors.GetAdjacent(5, 0) == nil and Floors.GetAdjacent(5, "1") == nil)
	assert(Floors.GetEnemyStats(1, "missing") == nil and Floors.GetEnemyStats(1, nil) == nil)
	assert(Floors.GetEnemyStats(1, Mobs.Biomes[2].RegularEnemyIds[1]) == nil)
	assert(Floors.GetEnemyStats(1, Mobs.Biomes[1].BossEnemyId) == nil)
end)

test("Every floor stat is finite/nonnegative and each role progresses monotonically", function()
	local previous = {}
	for id = 1, 50 do
		local floor = Floors.Get(id)
		for _, values in ipairs({ floor.Difficulty, floor.Rewards }) do for _, value in pairs(values) do finiteNonnegative(value) end end
		for _, encounter in ipairs(floor.Encounters) do
			local stats = assert(Floors.GetEnemyStats(id, encounter.EnemyId))
			local role = Mobs.Get(encounter.EnemyId).Role
			for key, value in pairs(stats) do
				finiteNonnegative(value); assert(value > 0 and value % 1 == 0)
				if previous[role] then assert(value >= previous[role][key], "Scaling regressed for " .. role .. "." .. key) end
			end
			previous[role] = stats
		end
	end
end)

test("Catalog data cannot be changed by a consumer", function()
	assert(table.isfrozen(Floors) and table.isfrozen(Mobs))
	assert(not pcall(function() Floors.Floors[1].Unlocked = false end))
	assert(not pcall(function() Floors.Floors[1].Encounters[1].Count = 1000 end))
	assert(not pcall(function() Mobs.Biomes[1].RegularEnemyIds[1] = "missing" end))
	assert(not pcall(function() Mobs.Get(Mobs.Biomes[1].BossEnemyId).Animations.Death.Status = "APPROVED" end))
end)

test("Provisional balance is measured against current starter formulas, not claimed playtested", function()
	local totalDPS = 0
	for _, starter in ipairs({ { Id = "hero_han", Quality = 1.05, HP = 315, ATK = 63, DPS = 63 }, { Id = "hero_jenna", Quality = 1, HP = 210, ATK = 51, DPS = 63.8 } }) do
		local seed = Heroes.Seeds[starter.Id]
		local atk, hp, dps = Stats.GetEffectiveCombatStats({ TemplateId = starter.Id, Level = 1, QualityScalar = starter.Quality, BaseATK = seed.NativeATK, BaseHP = seed.NativeHP, Archetype = seed.Archetype, AttackInterval = seed.AttackInterval, CurrentStamina = 100 }, false, false, { Star = 1, Rarity = 1 })
		assert(atk == starter.ATK and hp == starter.HP and dps == starter.DPS)
		totalDPS += dps
	end
	assert(math.abs(totalDPS - 126.8) < .001)
	for _, id in ipairs({ 1, 5, 25, 50 }) do
		local floor = Floors.Get(id)
		local enemyId = floor.BossEnemyId or floor.Encounters[1].EnemyId
		local values = Floors.GetEnemyStats(id, enemyId)
		print(string.format("PROVISIONAL floor=%d enemy=%s hp=%d atk=%d gold=%d xp=%d starter_formula_seconds=%.1f", id, enemyId, values.MaxHP, values.ATK, values.GoldReward, values.XPReward, values.MaxHP / totalDPS))
	end
	assert(Floors.BalanceStatus == "PROVISIONAL_NOT_PLAYTESTED")
end)

print(string.format("Tower foundation tests: %d passed, %d failed", passed, failed))
if failed > 0 then error(tostring(failed) .. " tower foundation test(s) failed") end
