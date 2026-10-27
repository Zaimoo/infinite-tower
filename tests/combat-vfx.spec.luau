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
	local kinds = { ARROW = true, ASTRAL = true, BOLT = true, ORB = true }
	local projectileStyles = { SHOT = true, BOLT = true, VOLLEY = true, CHAIN = true, MEND = true, STORM = true }
	-- Each archetype's ultimate is drawn by one style, and its radius matches the kit.
	local skillStyle = { Marksman = "STORM", Vanguard = "BULWARK", Striker = "TEMPEST", Miner = "CRYSTALS", Scholar = "PILLAR", Healer = "SANCTUARY" }
	local function checkRecipe(name: string, recipe: any)
		assert(recipe.Palette and recipe.Palette.Primary and recipe.Palette.Secondary and recipe.Palette.Core, name .. " palette")
		for _, tier in { "Basic", "Special", "Skill" } do
			local r = recipe[tier]
			assert(r and Catalog.Styles[tier][r.Style], name .. " " .. tier .. " uses a known style")
			if projectileStyles[r.Style] then
				assert(kinds[r.Projectile], name .. " " .. tier .. " uses a known projectile")
			end
		end
		if recipe.Special.Style == "VOLLEY" then
			assert((recipe.Special.Count or 1) >= 1 and (recipe.Special.Pierce or 0) >= 0, name .. " special volley")
		end
		if recipe.Skill.Style == "STORM" then
			assert(recipe.Skill.SigilRadius and recipe.Skill.RainPerWave and recipe.Skill.FlareHeight, name .. " skill storm")
		end
	end
	local function checkRadius(name: string, recipe: any, archetype: string)
		local profile = Skills.GetSkillProfile(archetype)
		assert(recipe.Skill.Style == skillStyle[archetype], name .. " ultimate style matches " .. archetype)
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
	assert(heroes == 12, "all twelve heroes have VFX")
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

-- Quality budget (Phase 6) ---------------------------------------------------------------------
do
	local Q = require(nodes["ReplicatedStorage.Assets.CombatVfx.VfxQuality"])
	assert(Q.Parse("low") == "Low" and Q.Parse("MEDIUM") == "Medium" and Q.Parse(nil) == "High" and Q.Parse(5) == "High", "settings values parse")
	for i = 2, #Q.ORDER do
		local better, worse = Q.LEVELS[Q.ORDER[i - 1]], Q.LEVELS[Q.ORDER[i]]
		assert(worse.Detail < better.Detail and worse.MaxEffects < better.MaxEffects, Q.ORDER[i] .. " is cheaper than " .. Q.ORDER[i - 1])
	end

	-- Feeds `seconds` of frames lasting `dt`; returns whether the level changed along the way.
	local function run(state: any, seconds: number, dt: number): boolean
		local changed = false
		for _ = 1, math.floor(seconds / dt + 0.5) do
			changed = Q.Observe(state, dt) or changed
		end
		return changed
	end

	-- Slow frames step the level down one at a time after SLOW_HOLD seconds.
	local state = Q.New("High")
	assert(not run(state, 2, 1 / 20) and Q.Effective(state) == "High", "two slow seconds are tolerated")
	run(state, 2, 1 / 20)
	assert(Q.Effective(state) == "Medium", "sustained slow frames drop to Medium")
	run(state, 4, 1 / 20)
	assert(Q.Effective(state) == "Low", "and then to Low")
	run(state, 10, 1 / 20)
	assert(Q.Effective(state) == "Low", "never below Low")

	-- Fast frames climb back, one level per FAST_HOLD, never above the player's setting.
	Q.SetSetting(state, "Medium")
	run(state, 30, 1 / 60)
	assert(Q.Effective(state) == "Medium", "recovery stops at the setting")
	Q.SetSetting(state, "High")
	assert(Q.Effective(state) == "Medium", "raising the setting waits for fast frames")
	run(state, 10, 1 / 60)
	assert(Q.Effective(state) == "High", "fast frames restore High")

	-- Lowering the setting applies at once; hitches and bad frame times are ignored.
	Q.SetSetting(state, "Low")
	assert(Q.Effective(state) == "Low" and Q.Detail(state) == Q.LEVELS.Low.Detail and Q.MaxEffects(state) == Q.LEVELS.Low.MaxEffects, "a lower setting applies immediately")
	local frame = state.FrameTime
	assert(not Q.Observe(state, 5) and not Q.Observe(state, 0 / 0) and not Q.Observe(state, -1) and state.FrameTime == frame, "hitches and bad input are ignored")

	assert(Q.Scale(6, 1) == 6 and Q.Scale(6, 0.35) == 2 and Q.Scale(1, 0.1) == 1 and Q.Scale(0, 1) == 0, "count scaling keeps at least one")

	-- Roblox's graphics slider maps to a level, and the cheaper of the two choices wins.
	assert(Q.FromRobloxLevel(0) == "High" and Q.FromRobloxLevel(1) == "Low" and Q.FromRobloxLevel(3) == "Low", "Automatic is High; 1-3 are Low")
	assert(Q.FromRobloxLevel(4) == "Medium" and Q.FromRobloxLevel(6) == "Medium" and Q.FromRobloxLevel(7) == "High" and Q.FromRobloxLevel(10) == "High", "4-6 Medium, 7-10 High")
	assert(Q.Lower("High", "Low") == "Low" and Q.Lower("Medium", "High") == "Medium" and Q.Lower("Low", "Low") == "Low", "the cheaper level wins")
end

print("combat-vfx.spec: ok")
