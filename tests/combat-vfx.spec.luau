-- tests/combat-vfx.spec.luau
-- Combat VFX geometry, timing and catalog (docs/projectile-skill-vfx-plan.md, Phase 3). The
-- instance-building modules (VfxPool, VfxPrimitives, ProjectileVfx, SkillVfx) need Studio.
local M = require(nodes["ReplicatedStorage.Assets.CombatVfx.VfxMath"])
local Catalog = require(nodes["ReplicatedStorage.Shared.Config.SkillVfxCatalog"])
local Skills = require(nodes["ReplicatedStorage.Shared.Config.ArchetypeCombatSkills"])
local Timing = require(nodes["ReplicatedStorage.Shared.Util.HeroActionTiming"])

local function near(a: number, b: number, msg: string, eps: number?)
	assert(math.abs(a - b) < (eps or 1e-6), msg .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
end

-- Flight paths ---------------------------------------------------------------------------
do
	local p0, p1 = Vector3.new(0, 2, 0), Vector3.new(20, 4, 0)
	local lift = M.ArcLift(p0, p1, 0.35)
	near(lift, 0.7, "arc lift scales with horizontal distance")
	local start, mid, finish = M.ArcPoint(p0, p1, 0, lift), M.ArcPoint(p0, p1, 0.5, lift), M.ArcPoint(p0, p1, 1, lift)
	near(start.X, 0, "arc starts at p0");near(start.Y, 2, "arc starts at p0 height")
	near(finish.X, 20, "arc ends at p1");near(finish.Y, 4, "arc ends at p1 height")
	near(mid.Y, 3 + lift, "arc peaks at mid-flight")
	near(M.ArcPoint(p0, p1, 2, lift).X, 20, "alpha clamps past the end")

	local exit = M.Extend(p0, p1, 10)
	near(M.Distance(p0, exit), M.Distance(p0, p1) + 10, "pierce exit is 10 studs past the target")
	near(M.Extend(p0, p0, 5).X, 0, "zero-length extend stays put")

	local fanTip = M.Fan(Vector3.new(0, 0, 0), Vector3.new(0, 0, -20), 90, 0)
	near(fanTip.X, 20, "fan turns about the vertical", 1e-4);near(fanTip.Z, 0, "fan turns about the vertical (z)", 1e-4)
	near(M.Horizontal(Vector3.new(0, 0, 0), M.Fan(Vector3.new(0, 0, 0), Vector3.new(0, 0, -20), 7, 12)), 32, "fanned arrow flies the pierce length", 1e-4)
end

-- Rain and waves ---------------------------------------------------------------------------
do
	local center = Vector3.new(100, 5, -40)
	local points = M.RainPoints(center, 16, 5, 1.3)
	assert(#points == 5, "rain point count")
	for i, p in points do
		assert(M.Horizontal(center, p) <= 16 * 0.9 + 1e-6, "rain lands inside the sigil")
		near(p.Y, 5, "rain lands at aim height")
		for j = i + 1, #points do
			assert(M.Horizontal(p, points[j]) > 0.5, "rain points are spread out")
		end
	end
	local again = M.RainPoints(center, 16, 5, 1.3)
	near(again[3].X, points[3].X, "rain points are deterministic for a seed")

	local marksman = Skills.GetSkillProfile("hero_jenna", "Marksman")
	local ticks, gap = Timing.Ticks(marksman.Skill)
	local waves = M.WaveTimes(10, ticks, gap)
	assert(#waves == 4, "one rain wave per damage tick")
	near(waves[1], 10, "first wave at impact");near(waves[4], 10.45, "last wave three gaps later")
	assert(#M.WaveTimes(10, 0, 0) == 1, "at least one wave")
end

-- Cue timing matches the server's impact time ---------------------------------------------
do
	local marksman = Skills.GetSkillProfile("hero_jenna", "Marksman")
	local t = Timing.For("hero_jenna", "BOW", "BASIC", marksman.Basic, 0.8, 19)
	local cue = { StartServerTime = 500, ReleaseSeconds = t.ReleaseSeconds, TravelSeconds = t.TravelSeconds }
	local releaseAt, arriveAt = M.FlightWindow(cue)
	near(releaseAt, 500 + t.ReleaseSeconds, "flight leaves at release")
	near(arriveAt, 500 + t.ImpactSeconds, "flight lands at the server impact")
	near(M.Progress(1, 2, 0.5), 0, "progress before start");near(M.Progress(1, 2, 1.5), 0.5, "progress mid");near(M.Progress(1, 2, 3), 1, "progress after end")
	near(M.Progress(2, 2, 2), 1, "zero-length window completes at its time")
end

-- Catalog -------------------------------------------------------------------------------------
do
	local kinds = { ARROW = true, ASTRAL = true, BOLT = true, ORB = true, VOID = true }
	local origins = { CHEST = true, LEFT_HAND = true, STAFF_TIP = true }
	local impactStyles = { BURST = true, IMPLODE = true }
	local projectileStyles = { SHOT = true, BOLT = true, VOLLEY = true, CHAIN = true, MEND = true, STORM = true }
	-- Each archetype's ultimate is drawn by one style, and its radius matches the kit.
	local skillStyle = { Marksman = "STORM", Vanguard = "BULWARK", Striker = "TEMPEST", Berserker = "CRYSTALS", Scholar = "PILLAR", Healer = "SANCTUARY" }
	-- A hero may draw its ultimate with its own style instead of its archetype's.
	local heroSkillStyle = { hero_han = "WAKE", hero_vane = "SINGULARITY" }
	local function checkRecipe(name: string, recipe: any)
		assert(recipe.Palette and recipe.Palette.Primary and recipe.Palette.Secondary and recipe.Palette.Core, name .. " palette")
		for _, tier in { "Basic", "Special", "Skill" } do
			local r = recipe[tier]
			assert(r and Catalog.Styles[tier][r.Style], name .. " " .. tier .. " uses a known style")
			if projectileStyles[r.Style] then
				assert(kinds[r.Projectile], name .. " " .. tier .. " uses a known projectile")
			end
			assert(r.Origin == nil or origins[r.Origin], name .. " " .. tier .. " uses a known cast origin")
			assert(r.ImpactStyle == nil or impactStyles[r.ImpactStyle], name .. " " .. tier .. " uses a known impact style")
		end
		if recipe.Special.Style == "VOLLEY" then
			assert((recipe.Special.Count or 1) >= 1 and (recipe.Special.Pierce or 0) >= 0, name .. " special volley")
		end
		if recipe.Skill.Style == "STORM" then
			assert(recipe.Skill.SigilRadius and recipe.Skill.RainPerWave and recipe.Skill.FlareHeight, name .. " skill storm")
		end
	end
	local function checkRadius(name: string, recipe: any, archetype: string)
		-- The hero's own kit (weapon names fall back to the archetype's).
		local profile = Skills.GetSkillProfile(name, archetype)
		assert(recipe.Skill.Style == (heroSkillStyle[name] or skillStyle[archetype]), name .. " ultimate style matches " .. archetype)
		local radius = if recipe.Skill.Style == "STORM" then recipe.Skill.SigilRadius else recipe.Skill.Radius
		near(radius, profile.Skill.Radius, name .. " ultimate radius matches the kit")
	end
	local heroes = 0
	for heroId, profile in Skills.HeroProfiles do
		local recipe = Catalog.Heroes[heroId]
		assert(recipe, heroId .. " has VFX")
		heroes += 1
		checkRecipe(heroId, recipe)
		checkRadius(heroId, recipe, profile.Archetype)
	end
	assert(heroes == 18, "all eighteen heroes have VFX")
	for heroId in Catalog.Heroes do
		assert(Skills.HeroProfiles[heroId], heroId .. " is a hero with a kit")
	end
	for weaponType, archetype in Catalog.WeaponArchetype do
		local recipe = Catalog.Weapons[weaponType]
		assert(recipe, weaponType .. " has fallback VFX")
		checkRecipe(weaponType, recipe)
		checkRadius(weaponType, recipe, archetype)
	end

	local recipe, palette = Catalog.Get("hero_jenna", "BOW", "SPECIAL")
	assert(recipe == Catalog.Heroes.hero_jenna.Special and palette == Catalog.Heroes.hero_jenna.Palette, "hero recipe wins")
	recipe = Catalog.Get("hero_unknown", "BOW", "BASIC")
	assert(recipe == Catalog.Weapons.BOW.Basic, "weapon fallback")
	assert(Catalog.Get("hero_unknown", "AXE", "SKILL") == Catalog.Weapons.AXE.Skill, "melee weapon fallback")
	assert(Catalog.Get(nil, "UNARMED", "BASIC") == nil, "unarmed has no recipe")
	assert(Catalog.Get("hero_jenna", "BOW", "NOT_A_TIER") == nil, "unknown tier")
end

-- Vane's Null Bolt (docs/vane-spell-animations-plan.md §3.1): flicked from the left hand, its
-- own clip releases at 0.52 of the 1.0 s cast, with the glyph charge starting before it.
do
	local vane = Skills.GetSkillProfile("hero_vane", "Scholar")
	local t = Timing.For("hero_vane", "STAFF", "BASIC", vane.Basic, 1.0, 21)
	near(t.CastSeconds, 1.0, "Null Bolt plays over the attack interval")
	near(t.ReleaseSeconds, 0.52, "Null Bolt leaves the hand on the flick")
	near(t.ImpactSeconds, 0.52 + 21 / vane.Basic.ProjectileSpeed, "Null Bolt lands after its flight")
	local basic = Catalog.Heroes.hero_vane.Basic
	assert(basic.Origin == "LEFT_HAND" and basic.Projectile == "VOID" and basic.ImpactStyle == "IMPLODE", "Null Bolt is a void bolt from the left hand")
	assert(Catalog.Heroes.hero_vane.Palette.Accent ~= nil, "Vane's palette has its gold accent")

	-- Singularity Lance: an instant beam whose drawn length and width are the server's line.
	local special = Catalog.Heroes.hero_vane.Special
	assert(special.Style == "BEAM", "Singularity Lance draws a beam")
	near(special.Length, vane.Special.SecondaryParam, "beam length matches BEAM_LINE")
	near(special.Width, vane.Special.BeamWidth, "beam width matches BEAM_LINE")
	local lance = Timing.For("hero_vane", "STAFF", "SPECIAL", vane.Special, 1.0, 25)
	near(lance.ReleaseSeconds, 0.55, "the beam fires on the locked frame")
	near(lance.TravelSeconds, 0, "the beam is instant at any range")

	-- Event Horizon: the hole opens on the clench and pulses once per server tick.
	local skill = Timing.For("hero_vane", "STAFF", "SKILL", vane.Skill, 1.0, 25)
	near(skill.CastSeconds, 1.4, "Event Horizon holds Vane for the crush and the glasses push")
	near(skill.ReleaseSeconds, 0.7, "the hole opens on the clench")
	near(skill.TravelSeconds, 0, "no fall time: the hole forms in place")
	local ticks, gap = Timing.Ticks(vane.Skill)
	local waves = M.WaveTimes(skill.ImpactSeconds, ticks, gap)
	assert(#waves == 8, "eight pulses")
	near(waves[8] - waves[1], 3.5, "pulses span 3.5 s")
	near(Catalog.Heroes.hero_vane.Skill.Radius, vane.Skill.Radius, "hole radius matches the kit")
end

print("combat-vfx.spec: ok")
