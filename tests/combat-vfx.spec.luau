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
	local kinds = { ARROW = true, ASTRAL = true }
	local function checkRecipe(name: string, recipe: any)
		assert(recipe.Palette and recipe.Palette.Primary and recipe.Palette.Secondary and recipe.Palette.Core, name .. " palette")
		for _, tier in { "Basic", "Special", "Skill" } do
			local r = recipe[tier]
			assert(r and kinds[r.Projectile], name .. " " .. tier .. " uses a known projectile")
		end
		assert((recipe.Special.Count or 1) >= 1 and (recipe.Special.Pierce or 0) >= 0, name .. " special volley")
		assert(recipe.Skill.SigilRadius and recipe.Skill.RainPerWave and recipe.Skill.FlareHeight, name .. " skill storm")
	end
	for heroId, recipe in Catalog.Heroes do
		checkRecipe(heroId, recipe)
		local profile = Skills.HeroProfiles[heroId]
		assert(profile and profile.Archetype == "Marksman", heroId .. " is a bow hero with a kit")
		near(recipe.Skill.SigilRadius, profile.Skill.Radius, heroId .. " sigil matches the skill radius")
	end
	for weaponType, recipe in Catalog.Weapons do
		checkRecipe(weaponType, recipe)
		assert(Catalog.WeaponArchetype[weaponType], weaponType .. " maps to an archetype")
	end

	local recipe, palette = Catalog.Get("hero_jenna", "BOW", "SPECIAL")
	assert(recipe == Catalog.Heroes.hero_jenna.Special and palette == Catalog.Heroes.hero_jenna.Palette, "hero recipe wins")
	recipe = Catalog.Get("hero_unknown", "BOW", "BASIC")
	assert(recipe == Catalog.Weapons.BOW.Basic, "weapon fallback")
	assert(Catalog.Get("hero_unknown", "AXE", "BASIC") == nil, "no recipe for melee yet")
	assert(Catalog.Get("hero_jenna", "BOW", "NOT_A_TIER") == nil, "unknown tier")
end

print("combat-vfx.spec: ok")
