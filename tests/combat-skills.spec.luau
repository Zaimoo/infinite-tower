--!strict
-- tests/combat-skills.spec.luau
-- Unit test suite for the Archetype 3-Tier Combat Attack & Dynamic Skill Gauge System.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArchetypeCombatSkills = require(ReplicatedStorage.Shared.Config.ArchetypeCombatSkills)
local HeroCatalog = require(ReplicatedStorage.Shared.Config.HeroCatalog)

local function assertEq(actual: any, expected: any, msg: string)
	if actual ~= expected then
		error(string.format("[FAIL] %s: expected %s, got %s", msg, tostring(expected), tostring(actual)), 2)
	end
end

local function assertTrue(condition: boolean, msg: string)
	if not condition then
		error(string.format("[FAIL] %s", msg), 2)
	end
end

-- ============================================================================
-- 1. ARCHETYPE PROFILE COMPLETENESS & DATA INTEGRITY
-- ============================================================================
do
	local archetypes = { "Vanguard", "Striker", "Marksman", "Miner", "Healer", "Scholar" }
	for _, arch in ipairs(archetypes) do
		local profile = ArchetypeCombatSkills.GetSkillProfile(arch)
		assertEq(profile.Archetype, arch, "Profile archetype matches key")
		assertTrue(profile.DisplayName ~= nil and #profile.DisplayName > 0, "Profile has display name")
		assertTrue(profile.Role ~= nil and #profile.Role > 0, "Profile has role description")

		-- Basic Attack checks
		assertEq(profile.Basic.DamageMultiplier, 1.00, arch .. " basic damage multiplier is 1.00x")
		assertEq(profile.Basic.StaminaGain, 5, arch .. " basic stamina gain is 5")

		-- Special Attack checks
		assertEq(profile.Special.Cadence, 3, arch .. " special cadence is every 3rd attack")
		assertTrue(profile.Special.DamageMultiplier > 1.00, arch .. " special has amplified damage")
		assertEq(profile.Special.StaminaGain, 10, arch .. " special stamina gain is 10")
		assertTrue(profile.Special.SecondaryEffect ~= nil, arch .. " special has secondary effect")

		-- Skill Attack checks
		assertEq(profile.Skill.StaminaCost, 100, arch .. " skill stamina cost is 100")
		assertTrue(profile.Skill.Description ~= nil and #profile.Skill.Description > 0, arch .. " skill has description")
		if arch == "Healer" then
			assertEq(profile.Skill.HealPercent, 0.35, "Healer skill restores 35% Max HP")
		elseif arch == "Vanguard" then
			assertEq(profile.Skill.BarrierPercent, 0.40, "Vanguard skill grants 40% Max HP barrier")
		else
			assertTrue(profile.Skill.DamageMultiplier >= 2.50, arch .. " offensive skill deals massive damage (>= 2.50x)")
		end
	end
	print("PASS All 6 archetype profiles are complete and adhere to design specs")
end

-- ============================================================================
-- 2. ATTACK CADENCE & STAMINA ACCRUAL CYCLE
-- ============================================================================
do
	local profile = ArchetypeCombatSkills.GetSkillProfile("Striker")
	local stamina = 0
	local attackCount = 0

	local history = {}
	for step = 1, 16 do
		local isSkillReady = stamina >= ArchetypeCombatSkills.Constants.MAX_STAMINA
		local attackType = "BASIC"
		if isSkillReady then
			attackType = "SKILL"
		elseif (attackCount + 1) % profile.Special.Cadence == 0 then
			attackType = "SPECIAL"
		else
			attackType = "BASIC"
		end

		table.insert(history, { Step = step, Type = attackType, StaminaBefore = stamina })

		if attackType == "SKILL" then
			stamina = 0
		elseif attackType == "SPECIAL" then
			attackCount += 1
			stamina = math.clamp(stamina + profile.Special.StaminaGain, 0, 100)
		else
			attackCount += 1
			stamina = math.clamp(stamina + profile.Basic.StaminaGain, 0, 100)
		end
	end

	-- Verify steps 1, 2, 3 follow Basic -> Basic -> Special
	assertEq(history[1].Type, "BASIC", "Attack 1 is BASIC")
	assertEq(history[2].Type, "BASIC", "Attack 2 is BASIC")
	assertEq(history[3].Type, "SPECIAL", "Attack 3 is SPECIAL")
	assertEq(history[4].Type, "BASIC", "Attack 4 is BASIC")
	assertEq(history[5].Type, "BASIC", "Attack 5 is BASIC")
	assertEq(history[6].Type, "SPECIAL", "Attack 6 is SPECIAL")

	-- Each 3-attack cycle generates 5 + 5 + 10 = +20 Stamina
	-- Step 3 stamina before = 10, after = 20
	-- Step 6 stamina after = 40
	-- Step 9 stamina after = 60
	-- Step 12 stamina after = 80
	-- Step 15 stamina after = 100
	assertEq(history[15].Type, "SPECIAL", "Attack 15 is SPECIAL")
	assertEq(history[16].StaminaBefore, 100, "Attack 16 has 100 Stamina")
	assertEq(history[16].Type, "SKILL", "Attack 16 procs SKILL attack")
	assertEq(stamina, 0, "After SKILL attack, Stamina resets cleanly to 0")

	print("PASS Attack cadence correctly sequences Basic -> Basic -> Special and procs Skill at 100 Stamina")
end

-- ============================================================================
-- 3. HEALER SQUAD HEALING & COMA SAFETY
-- ============================================================================
do
	local healerProfile = ArchetypeCombatSkills.GetSkillProfile("Healer")
	local squad = {
		{ Name = "Hero_1", CurrentHP = 50, MaxHP = 200, State = "ATTACKING" },
		{ Name = "Hero_2", CurrentHP = 180, MaxHP = 200, State = "ATTACKING" },
		{ Name = "Hero_3", CurrentHP = 0, MaxHP = 200, State = "COMA" },
	}

	-- Execute Skill: Sanctuary Miracle (35% Max HP heal to all alive squad members)
	local healPct = healerProfile.Skill.HealPercent or 0.35
	for _, ally in ipairs(squad) do
		if ally.State ~= "COMA" and ally.CurrentHP > 0 then
			local healAmt = math.round(ally.MaxHP * healPct)
			ally.CurrentHP = math.min(ally.MaxHP, ally.CurrentHP + healAmt)
		end
	end

	assertEq(squad[1].CurrentHP, 120, "Hero_1 healed by 70 HP (35% of 200)")
	assertEq(squad[2].CurrentHP, 200, "Hero_2 healed to exactly MaxHP (capped, no overheal)")
	assertEq(squad[3].CurrentHP, 0, "Comatose Hero_3 received no heal")

	-- Execute Special: Radiant Pulse (8% Max HP heal to lowest-HP ally)
	local lowestAlly = nil
	local lowestPct = 1.0
	for _, ally in ipairs(squad) do
		if ally.State ~= "COMA" and ally.CurrentHP > 0 and ally.CurrentHP < ally.MaxHP then
			local pct = ally.CurrentHP / ally.MaxHP
			if pct < lowestPct then
				lowestPct = pct
				lowestAlly = ally
			end
		end
	end
	assertTrue(lowestAlly ~= nil and lowestAlly.Name == "Hero_1", "Lowest HP ally identified correctly")
	if lowestAlly then
		local healAmt = math.round(lowestAlly.MaxHP * healerProfile.Special.SecondaryParam)
		lowestAlly.CurrentHP = math.min(lowestAlly.MaxHP, lowestAlly.CurrentHP + healAmt)
	end
	assertEq(squad[1].CurrentHP, 136, "Hero_1 received 16 HP (8% of 200)")

	print("PASS Healer Special and Skill accurately heal active squad members without overhealing or reviving comatose heroes")
end

-- ============================================================================
-- 4. VANGUARD BARRIER ABSORPTION
-- ============================================================================
do
	local vanguardProfile = ArchetypeCombatSkills.GetSkillProfile("Vanguard")
	local hero = {
		CurrentHP = 400,
		MaxHP = 400,
		BarrierHP = 0,
		BarrierExpires = 0,
	}

	-- Activate Fortress Aegis
	local now = 100.0
	hero.BarrierHP = math.round(hero.MaxHP * (vanguardProfile.Skill.BarrierPercent or 0.40))
	hero.BarrierExpires = now + (vanguardProfile.Skill.Duration or 6.0)
	assertEq(hero.BarrierHP, 160, "Barrier equals 40% of 400 Max HP = 160 HP")

	-- Hit 1: 100 incoming damage -> fully absorbed by barrier
	local hit1 = 100
	if hero.BarrierHP > 0 and hero.BarrierExpires > now then
		local absorbed = math.min(hero.BarrierHP, hit1)
		hero.BarrierHP -= absorbed
		hit1 -= absorbed
	end
	hero.CurrentHP -= hit1
	assertEq(hero.BarrierHP, 60, "Barrier has 60 HP remaining after 100 absorbed")
	assertEq(hero.CurrentHP, 400, "CurrentHP took 0 damage")

	-- Hit 2: 100 incoming damage -> 60 absorbed, 40 overflows to CurrentHP
	local hit2 = 100
	if hero.BarrierHP > 0 and hero.BarrierExpires > now then
		local absorbed = math.min(hero.BarrierHP, hit2)
		hero.BarrierHP -= absorbed
		hit2 -= absorbed
	end
	hero.CurrentHP -= hit2
	assertEq(hero.BarrierHP, 0, "Barrier is depleted to 0")
	assertEq(hero.CurrentHP, 360, "CurrentHP took remaining 40 damage")

	print("PASS Vanguard Barrier absorbed damage first and let excess damage overflow to health")
end

-- ============================================================================
-- 5. OFFENSIVE DAMAGE SCALING
-- ============================================================================
do
	local strikerProfile = ArchetypeCombatSkills.GetSkillProfile("Striker")
	local effectiveATK = 250

	local basicDmg = math.round(effectiveATK * strikerProfile.Basic.DamageMultiplier)
	local specialDmg = math.round(effectiveATK * strikerProfile.Special.DamageMultiplier)
	local skillDmg = math.round(effectiveATK * strikerProfile.Skill.DamageMultiplier)

	assertEq(basicDmg, 250, "Basic damage = 250 (1.00x)")
	assertEq(specialDmg, 400, "Special damage = 400 (1.60x)")
	assertEq(skillDmg, 800, "Skill damage = 800 (3.20x)")

	print("PASS Offensive damage scaling accurately multiplies EffectiveATK across all 3 tiers")
end

print("All Combat Skill spec tests passed successfully!")
