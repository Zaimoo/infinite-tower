-- tests/combat-vfx.spec.luau
-- Combat VFX geometry, timing and catalog (docs/projectile-skill-vfx-plan.md, Phase 3). The
-- instance-building modules (VfxPool, VfxPrimitives, ProjectileVfx, SkillVfx) need Studio.
local M = require(nodes["ReplicatedStorage.Assets.CombatVfx.VfxMath"])
local Catalog = require(nodes["ReplicatedStorage.Shared.Config.SkillVfxCatalog"])
local Skills = require(nodes["ReplicatedStorage.Shared.Config.ArchetypeCombatSkills"])
local Timing = require(nodes["ReplicatedStorage.Shared.Util.HeroActionTiming"])
local Clips = require(nodes["ReplicatedStorage.Assets.HeroRig.HeroClips"])

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
	local kinds = { ARROW = true, ASTRAL = true, BOLT = true, ORB = true, VOID = true, STARBOLT = true }
	local origins = { CHEST = true, LEFT_HAND = true, STAFF_TIP = true, NOCK = true }
	local impactStyles = { BURST = true, IMPLODE = true }
	local projectileStyles = { SHOT = true, BOLT = true, VOLLEY = true, CHAIN = true, MEND = true, STORM = true, PIERCER = true, CONSTELLATION = true, RICOCHET = true, TWIN = true }
	-- Each archetype's ultimate is drawn by one style, and its radius matches the kit.
	local skillStyle = { Marksman = "STORM", Vanguard = "BULWARK", Striker = "TEMPEST", Berserker = "CRYSTALS", Scholar = "PILLAR", Healer = "SANCTUARY" }
	-- A hero may draw its ultimate with its own style instead of its archetype's.
	local heroSkillStyle = { hero_han = "WAKE", hero_vane = "SINGULARITY", hero_astrea = "CONSTELLATION", hero_rhyman = "EXECUTE", hero_seraphine = "CRYSTALS", hero_isabelle = "TWIN" }
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
	assert(heroes == 24, "all twenty-four heroes have VFX")
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

-- Rhyman: Reaver's Whirl is drawn over the server's WHIRLWIND reach and ticks, and his spin is
-- one full turn that starts at the release; Headsman's Verdict lands on the slam.
do
	local rhyman = Skills.GetSkillProfile("hero_rhyman", "Berserker")
	local recipe = Catalog.Heroes.hero_rhyman
	assert(recipe.Special.Style == "WHIRL" and recipe.Skill.Style == "EXECUTE", "Rhyman has his own Special and Skill styles")
	assert(rhyman.Special.SecondaryEffect == "WHIRLWIND" and rhyman.Skill.Effect == "EXECUTE", "Rhyman's kit names his effects")
	near(recipe.Special.Radius, rhyman.Special.SecondaryParam, "the whirl is drawn over the spin's reach")
	local ticks, gap = Timing.Ticks(rhyman.Special)
	assert(ticks == 3 and gap > 0, "the spin lands in three cuts")
	local spin = Clips.Get("hero_rhyman", "AXE", "AttackSpecial")
	local turned, yaw, lastSpinKey = 0, 0, 0
	for _, key in spin.Keys do
		local root = key.Pose.Root
		local nextYaw = if root then root[2] else 0
		local step = (nextYaw - yaw + 180) % 360 - 180
		turned += step
		yaw = nextYaw
		if root then
			lastSpinKey = key.T
		end
	end
	near(turned, 360, "Reaver's Whirl spins one full turn")
	local release = Clips.Marker(spin, "Release", -1)
	local special = Timing.For("hero_rhyman", "AXE", "SPECIAL", rhyman.Special, 1.0, 5)
	assert(lastSpinKey > release, "the spin is still turning when the first cut lands")
	assert(lastSpinKey * special.CastSeconds >= special.ImpactSeconds + (ticks - 1) * gap - 0.1, "the cuts land during the turn")

	local skill = Timing.For("hero_rhyman", "AXE", "SKILL", rhyman.Skill, 1.0, 5)
	near(skill.CastSeconds, 1.3, "Headsman's Verdict holds him for the leap")
	near(skill.ReleaseSeconds, 1.3 * 0.6, "the blow lands on the slam")
	near(skill.TravelSeconds, 0, "a melee blow has no travel")
	local leapClip = Clips.Get("hero_rhyman", "AXE", "AttackSkill")
	local peak = 0
	for _, key in leapClip.Keys do
		local offset = key.Pose.RootOffset
		if offset and key.T < Clips.Marker(leapClip, "Release", -1) then
			peak = math.max(peak, offset[2])
		end
	end
	assert(peak >= 2.5, "he leaves the ground before the blow")
end

-- Astrea: Nebula Piercer is one charged star-bolt off the nock; Constellation Judgment draws the
-- Archer over the target, then drops one star per bolt in a wave per server tick.
do
	local astrea = Skills.GetSkillProfile("hero_astrea", "Marksman")
	local recipe = Catalog.Heroes.hero_astrea
	assert(recipe.Special.Style == "PIERCER" and recipe.Special.Projectile == "STARBOLT" and recipe.Special.Origin == "NOCK", "Nebula Piercer is a star-bolt from the nock")
	assert((recipe.Special.Pierce or 0) > 0 and (recipe.Special.Linger or 0) > 0, "Nebula Piercer pierces and leaves a ribbon")
	assert(recipe.Palette.Accent ~= nil, "Astrea's palette has its nebula indigo")
	local special = Timing.For("hero_astrea", "BOW", "SPECIAL", astrea.Special, 0.7, 28)
	near(special.CastSeconds, 0.7, "Nebula Piercer plays over her attack interval")
	local clip = Clips.Get("hero_astrea", "BOW", "AttackSpecial")
	local charge, release = Clips.Marker(clip, "Charge", -1), Clips.Marker(clip, "Release", -1)
	assert(charge > 0 and release - charge >= 0.5, "Nebula Piercer charges for at least half the clip")

	local skill = Timing.For("hero_astrea", "BOW", "SKILL", astrea.Skill, 0.7, 28)
	near(skill.CastSeconds, 1.4, "Constellation Judgment holds her for the spin and the sky shot")
	near(skill.ReleaseSeconds, 1.4 * 0.56, "the sky shot leaves after the spin")
	near(skill.TravelSeconds, 0.9, "the constellation has time to draw before the first stars fall")
	near(recipe.Skill.Radius, astrea.Skill.Radius, "constellation radius matches the kit")

	-- The spin: Root keys that add up to one full turn, each under 180 degrees from the last,
	-- finished before the release.
	local skillClip = Clips.Get("hero_astrea", "BOW", "AttackSkill")
	local turned, yaw, spunBy = 0, 0, 0
	for _, key in skillClip.Keys do
		local root = key.Pose.Root
		local nextYaw = if root then root[2] else 0
		local step = (nextYaw - yaw + 180) % 360 - 180
		assert(math.abs(step) < 180, "spin keys take the short way round")
		turned += step
		yaw = nextYaw
		if root then
			spunBy = key.T
		end
	end
	near(turned, 360, "Constellation Judgment spins one full turn")
	assert(spunBy < Clips.Marker(skillClip, "Release", -1), "the spin ends before the shot")

	-- The figure: every star inside the unit disc, every line between two stars and starting
	-- from one already drawn, and every star on a line.
	local figure = M.ARCHER
	local ticks, gap = Timing.Ticks(astrea.Skill)
	local waves = M.WaveTimes(skill.ImpactSeconds, ticks, gap)
	assert(#figure.Stars % #waves == 0, "each wave drops the same number of stars")
	local reached = { [figure.Lines[1][1]] = true }
	for k, line in figure.Lines do
		assert(figure.Stars[line[1]] and figure.Stars[line[2]] and line[1] ~= line[2], "line " .. k .. " joins two stars")
		assert(reached[line[1]], "line " .. k .. " starts from a star already drawn")
		reached[line[2]] = true
	end
	for i, star in figure.Stars do
		assert(star[1] * star[1] + star[2] * star[2] <= 1, "star " .. i .. " is inside the disc")
		assert(reached[i], "star " .. i .. " is on a line")
	end
	local center = Vector3.new(40, 3, -10)
	local points = M.FigurePoints(figure, center, 14.4, Vector3.new(0, 0, -1))
	assert(#points == #figure.Stars, "one point per star")
	for _, point in points do
		assert(M.Horizontal(center, point) <= 14.4 + 1e-6, "stars land inside the skill radius")
		near(point.Y, 3, "stars are laid at aim height")
	end
	near(points[9].Z, -10 - figure.Stars[9][2] * 14.4, "the top of the figure points along the heading", 1e-4)
	near(points[9].X, 40 + figure.Stars[9][1] * 14.4, "the figure is not mirrored", 1e-4)
	local turnedPoints = M.FigurePoints(figure, center, 14.4, Vector3.new(1, 0, 0))
	near(turnedPoints[9].X, 40 + figure.Stars[9][2] * 14.4, "the figure turns with the heading", 1e-4)

	-- The trace: every line finishes by the end, and a star is lit before any line leaves it.
	local lineStarts, lineSeconds, starAt = M.FigureTrace(figure, 10, 10.4)
	near(lineStarts[1], 10, "the trace starts on time")
	near(lineStarts[#lineStarts] + lineSeconds, 10.4, "the last line finishes on time")
	for k, line in figure.Lines do
		assert(starAt[line[1]] <= lineStarts[k] + 1e-9, "line " .. k .. " leaves a lit star")
		assert(starAt[line[2]] <= lineStarts[k] + lineSeconds + 1e-9, "line " .. k .. " reaches a lit star")
	end
	local _, hurried = M.FigureTrace(figure, 10, 10)
	assert(hurried > 0, "a late cue still draws")
end

print("combat-vfx.spec: ok")
