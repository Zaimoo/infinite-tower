--!strict
-- ReplicatedStorage/Assets/CombatVfx/SkillVfx.luau
-- Plays a hero attack's visuals from its HERO_CUE (docs/projectile-skill-vfx-plan.md, section 6).
-- EntityRenderer calls Play at the attack clip's Release marker. Every flight lands at the cue's
-- release + travel time, the server time at which the server applies the hit, so the arrow and
-- the damage number arrive together. Phase 3 covers bow heroes (SkillVfxCatalog).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArchetypeCombatSkills = require(Shared:WaitForChild("Config"):WaitForChild("ArchetypeCombatSkills"))
local SkillVfxCatalog = require(Shared:WaitForChild("Config"):WaitForChild("SkillVfxCatalog"))
local HeroActionTiming = require(Shared:WaitForChild("Util"):WaitForChild("HeroActionTiming"))
local VfxMath = require(script.Parent:WaitForChild("VfxMath"))
local VfxPool = require(script.Parent:WaitForChild("VfxPool"))
local VfxPrimitives = require(script.Parent:WaitForChild("VfxPrimitives"))
local ProjectileVfx = require(script.Parent:WaitForChild("ProjectileVfx"))

local SkillVfx = {}

local TIERS = table.freeze({ "BASIC", "SPECIAL", "SKILL" })
local RAIN_FALL_SECONDS = 0.28
local SIGIL_LINGER = 0.45

export type PlayArgs = {
	HeroId: string?,
	WeaponType: string?,
	Cue: any, -- TowerProtocol.DecodeHeroCue result
	Origin: Vector3, -- where the projectile leaves the weapon (the bow's Nock)
	Target: () -> Vector3, -- live target position, or the cue's aim when the target is gone
	Now: number, -- server time
	Shake: ((magnitude: number) -> ())?, -- set only for the local player's own heroes
}

type Projectile = {
	Kind: string,
	Build: () -> Model,
	Prepare: (Model) -> (),
}

local function projectile(recipe: SkillVfxCatalog.TierRecipe, palette: SkillVfxCatalog.Palette, scale: number?): Projectile
	local key, build = ProjectileVfx.Key(recipe.Projectile, scale or recipe.Scale)
	return {
		Kind = key,
		Build = build,
		Prepare = function(model: Model)
			ProjectileVfx.Paint(model, recipe.Projectile, palette, recipe.Trail)
		end,
	}
end

local function fly(pool: VfxPool.VfxPool, body: Projectile, from: Vector3, to: () -> Vector3, startAt: number, endAt: number, lift: number, onArrive: ((Vector3) -> ())?)
	VfxPrimitives.Flight(pool, {
		Kind = body.Kind,
		Build = body.Build,
		Prepare = body.Prepare,
		From = from,
		To = to,
		StartAt = startAt,
		EndAt = endAt,
		Lift = lift,
		OnArrive = onArrive,
	})
end

local function fixed(point: Vector3): () -> Vector3
	return function(): Vector3
		return point
	end
end

local function playBasic(pool: VfxPool.VfxPool, args: PlayArgs, recipe: SkillVfxCatalog.TierRecipe, palette: SkillVfxCatalog.Palette, startAt: number, arriveAt: number)
	local cue = args.Cue
	local body = projectile(recipe, palette)
	fly(pool, body, args.Origin, args.Target, startAt, arriveAt, VfxMath.ArcLift(args.Origin, cue.Aim, recipe.Arc), function(at: Vector3)
		VfxPrimitives.Burst(pool, at, palette.Core, recipe.Impact or 1.6, arriveAt)
	end)
end

-- A volley: the centre arrow hits the target and carries on (pierce); the others fan out past it.
local function playSpecial(pool: VfxPool.VfxPool, args: PlayArgs, recipe: SkillVfxCatalog.TierRecipe, palette: SkillVfxCatalog.Palette, startAt: number, arriveAt: number)
	local cue = args.Cue
	local origin = args.Origin
	local body = projectile(recipe, palette)
	local flightTime = math.max(0.05, arriveAt - startAt)
	local distance = math.max(1, VfxMath.Distance(origin, cue.Aim))
	local speed = distance / flightTime
	local pierce = recipe.Pierce or 0

	fly(pool, body, origin, args.Target, startAt, arriveAt, VfxMath.ArcLift(origin, cue.Aim, recipe.Arc), function(at: Vector3)
		VfxPrimitives.Burst(pool, at, palette.Core, recipe.Impact or 2.4, arriveAt)
		if pierce > 0 then
			local exit = VfxMath.Extend(origin, at, pierce)
			fly(pool, body, at, fixed(exit), arriveAt, arriveAt + pierce / speed, 0, nil)
		end
	end)

	if recipe.Rings then
		local direction = cue.Aim - origin
		for _, f in { 0.3, 0.6, 0.9 } do
			VfxPrimitives.FlightRing(pool, VfxMath.Lerp(origin, cue.Aim, f), direction, 0.55 * (recipe.Scale or 1), palette.Secondary, startAt + f * flightTime)
		end
	end

	local count = recipe.Count or 1
	local spread = recipe.Spread or 6
	local sideEnd = startAt + flightTime * (distance + pierce) / distance
	for i = 1, count - 1 do
		local side = if i % 2 == 1 then 1 else -1
		local degrees = side * spread * math.ceil(i / 2)
		local tip = VfxMath.Fan(origin, cue.Aim, degrees, pierce)
		fly(pool, projectile(recipe, palette, (recipe.Scale or 1) * 0.85), origin, fixed(tip), startAt, sideEnd, 0, nil)
	end
end

-- Arrow storm: a flare climbs from the bow, a sigil opens over the aim point, then one wave of
-- arrows falls per server damage tick.
local function playSkill(pool: VfxPool.VfxPool, args: PlayArgs, recipe: SkillVfxCatalog.TierRecipe, palette: SkillVfxCatalog.Palette, startAt: number, arriveAt: number)
	local cue = args.Cue
	local origin = args.Origin
	local aim: Vector3 = cue.Aim
	local archetype = args.WeaponType and SkillVfxCatalog.WeaponArchetype[args.WeaponType]
	local profile = ArchetypeCombatSkills.GetSkillProfile(args.HeroId, archetype)
	local ticks, gap = HeroActionTiming.Ticks(profile.Skill)
	local waves = VfxMath.WaveTimes(arriveAt, ticks, gap)
	local lastWave = waves[#waves]
	local radius = recipe.SigilRadius or 16

	local flareTop = origin + Vector3.new(0, recipe.FlareHeight or 26, 0)
	fly(pool, projectile(recipe, palette, (recipe.Scale or 1) * 1.15), origin, fixed(flareTop), startAt, arriveAt, 0, function(at: Vector3)
		VfxPrimitives.Burst(pool, at, palette.Secondary, 3, arriveAt, 0.35)
	end)
	VfxPrimitives.Sigil(pool, aim, radius, palette, startAt, lastWave + SIGIL_LINGER)

	local perWave = recipe.RainPerWave or 4
	local height = recipe.RainHeight or 30
	local body = projectile(recipe, palette)
	local seedBase = (cue.NetId % 97) * 0.37
	for k, waveAt in waves do
		for _, point in VfxMath.RainPoints(aim, radius, perWave, seedBase + k * 1.7) do
			local from = point + Vector3.new(1.5, height, 1)
			fly(pool, body, from, fixed(point), waveAt - RAIN_FALL_SECONDS, waveAt, 0, function(at: Vector3)
				VfxPrimitives.Burst(pool, at, palette.Primary, recipe.Impact or 2, waveAt, 0.2)
			end)
		end
	end

	local shake = args.Shake
	if shake and recipe.Shake then
		local magnitude = recipe.Shake
		VfxPrimitives.At(pool, waves[1], function()
			shake(magnitude)
		end)
	end
end

local PLAYERS = table.freeze({ BASIC = playBasic, SPECIAL = playSpecial, SKILL = playSkill })

-- Plays the cue's attack. Returns false when this hero has no recipe, the shot already landed,
-- or the whole effect is too far from the camera.
function SkillVfx.Play(pool: VfxPool.VfxPool, args: PlayArgs): boolean
	local cue = args.Cue
	local tier = TIERS[cue.Tier]
	local recipe, palette = SkillVfxCatalog.Get(args.HeroId, args.WeaponType, tier or "")
	if not tier or not recipe or not palette or not ProjectileVfx.Has(recipe.Projectile) then
		return false
	end
	local releaseAt, arriveAt = VfxMath.FlightWindow(cue)
	if args.Now >= arriveAt or not pool:Visible(args.Origin, cue.Aim) then
		return false
	end
	PLAYERS[tier](pool, args, recipe, palette, math.max(releaseAt, args.Now), arriveAt)
	return true
end

return table.freeze(SkillVfx)
