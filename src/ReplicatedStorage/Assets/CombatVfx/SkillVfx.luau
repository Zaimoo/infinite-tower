--!strict
-- ReplicatedStorage/Assets/CombatVfx/SkillVfx.luau
-- Plays a hero attack's visuals from its HERO_CUE (docs/projectile-skill-vfx-plan.md, section 6).
-- EntityRenderer calls Play at the attack clip's Release marker. Impacts land at the cue's
-- release + travel time, the server time at which the server applies the hit, so effects and
-- damage numbers arrive together. The tier recipe's Style (SkillVfxCatalog) picks the player.

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
-- Melee blows land on their release frame, which is when Play runs; accept a cue this late.
local LATE_GRACE = 0.2
-- Secondary hits (chains, splash) reach the client a moment after the impact.
local HIT_LOOKUP_DELAY = 0.2
-- Size of every crescent slash, on top of the recipe's Scale (one knob for all melee cuts).
local SLASH_SIZE = 1.7

export type PlayArgs = {
	HeroId: string?,
	WeaponType: string?,
	Cue: any, -- TowerProtocol.DecodeHeroCue result
	Origin: Vector3, -- where a projectile leaves the weapon (the bow's Nock, else the chest)
	-- Live position of a named cast point (a recipe's Origin, e.g. "LEFT_HAND"), or nil when
	-- the rig has none; the effect then uses Origin.
	OriginOf: ((name: string) -> Vector3?)?,
	Target: () -> Vector3, -- live target body centre, or the cue's aim when the target is gone
	-- Ground-level positions (the server's entity positions are at the feet, like Cue.Aim):
	Self: (() -> Vector3)?, -- the attacker's feet
	Allies: (() -> { Vector3 })?, -- the attacker's squad (healing effects)
	-- Positions the server reported hits ("HIT") or heals ("HEAL") at, near `center`, since `since`.
	RecentHits: ((kind: string, center: Vector3, radius: number, since: number) -> { Vector3 })?,
	-- TWIN: live body centre of the second target the server picked when the attack started
	-- (its TWIN_MARK), or nil when there is none.
	Twin: (() -> Vector3?)?,
	Now: number, -- server time
	Shake: ((magnitude: number) -> ())?, -- set only for the local player's own heroes
}

type Recipe = SkillVfxCatalog.TierRecipe
type Palette = SkillVfxCatalog.Palette
type Context = {
	Pool: VfxPool.VfxPool,
	Args: PlayArgs,
	Recipe: Recipe,
	Palette: Palette,
	StartAt: number, -- when the effect may begin (release, or now if that has passed)
	ArriveAt: number, -- server impact time
}

type Projectile = {
	Kind: string,
	Build: () -> Model,
	Prepare: (Model) -> (),
}

local function projectile(recipe: Recipe, palette: Palette, scale: number?): Projectile
	local kind = recipe.Projectile or "ARROW"
	local key, build = ProjectileVfx.Key(kind, scale or recipe.Scale)
	return {
		Kind = key,
		Build = build,
		Prepare = function(model: Model)
			ProjectileVfx.Paint(model, kind, palette, recipe.Trail)
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

-- Body height above a ground-level position.
local function chest(point: Vector3): Vector3
	return point + Vector3.new(0, 2, 0)
end

-- Horizontal direction from the attacker to the target (the way the blow travels).
local function heading(ctx: Context): Vector3
	local from = if ctx.Args.Self then ctx.Args.Self() else ctx.Args.Origin
	local delta = ctx.Args.Cue.Aim - from
	local flat = Vector3.new(delta.X, 0, delta.Z)
	return if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
end

-- A slash frame on the target, facing back at the attacker and rolled for a diagonal cut.
local function slashFrame(ctx: Context, at: Vector3, roll: number): CFrame
	return CFrame.lookAt(at, at - heading(ctx)) * CFrame.Angles(0, 0, math.rad(roll))
end

local function shake(ctx: Context, at: number)
	local callback = ctx.Args.Shake
	local magnitude = ctx.Recipe.Shake
	if callback and magnitude then
		VfxPrimitives.At(ctx.Pool, at, function()
			callback(magnitude)
		end)
	end
end

-- Runs `fn` with the server's reported hit positions once they have arrived.
local function afterHits(ctx: Context, kind: string, center: () -> Vector3, radius: number, fn: ({ Vector3 }) -> ())
	local lookup = ctx.Args.RecentHits
	if not lookup then
		return
	end
	local since = ctx.ArriveAt - 0.1
	VfxPrimitives.At(ctx.Pool, ctx.ArriveAt + HIT_LOOKUP_DELAY, function()
		fn(lookup(kind, center(), radius, since))
	end)
end

-- Where this recipe's projectile leaves the hero: its named Origin if the rig has one, else
-- the default (the bow's nock, else the chest).
local function originOf(args: PlayArgs, recipe: Recipe): Vector3
	local name = recipe.Origin
	if name and name ~= "CHEST" and args.OriginOf then
		local point = args.OriginOf(name)
		if point then
			return point
		end
	end
	return args.Origin
end

-- Basic -------------------------------------------------------------------------------------

local IMPLODE_SECONDS = 0.14

-- SHOT / BOLT: one projectile to the target, bursting on arrival. ImpactStyle IMPLODE swallows
-- the hit instead: a pinpoint flash, a sphere collapsing onto it, then a small burst.
local function playProjectile(ctx: Context)
	local args, recipe, palette, pool = ctx.Args, ctx.Recipe, ctx.Palette, ctx.Pool
	local from = originOf(args, recipe)
	local impact = recipe.Impact or 1.6
	fly(pool, projectile(recipe, palette), from, args.Target, ctx.StartAt, ctx.ArriveAt, VfxMath.ArcLift(from, args.Cue.Aim, recipe.Arc), function(at: Vector3)
		if recipe.ImpactStyle == "IMPLODE" then
			VfxPrimitives.Burst(pool, at, palette.Core, impact * 0.35, ctx.ArriveAt, 0.08)
			VfxPrimitives.Implode(pool, at, palette.Primary, impact * 1.3, ctx.ArriveAt, IMPLODE_SECONDS)
			VfxPrimitives.Burst(pool, at, palette.Core, impact, ctx.ArriveAt + IMPLODE_SECONDS, 0.15)
		else
			VfxPrimitives.Burst(pool, at, palette.Core, impact, ctx.ArriveAt)
		end
	end)
end

-- SLASH: a crescent across the target as the blow lands.
local function playSlash(ctx: Context)
	local at = ctx.Args.Target()
	local scale = ctx.Recipe.Scale or 1
	local roll = if ctx.Args.Cue.NetId % 2 == 0 then 25 else -25
	VfxPrimitives.SlashArc(ctx.Pool, slashFrame(ctx, at, roll), 2.2 * scale * SLASH_SIZE, ctx.Palette.Primary, ctx.ArriveAt)
	VfxPrimitives.Burst(ctx.Pool, at, ctx.Palette.Core, ctx.Recipe.Impact or 1.4, ctx.ArriveAt + 0.05, 0.18)
end

-- Special -----------------------------------------------------------------------------------

-- VOLLEY: the centre arrow hits the target and carries on (pierce); the others fan out past it.
local function playVolley(ctx: Context)
	local args, recipe, palette, pool = ctx.Args, ctx.Recipe, ctx.Palette, ctx.Pool
	local cue = args.Cue
	local origin = args.Origin
	local startAt, arriveAt = ctx.StartAt, ctx.ArriveAt
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

-- The deep colour a palette's nebula cools to: its Accent, else a darkened Primary.
local function nebula(palette: Palette): Color3
	return palette.Accent or palette.Primary:Lerp(Color3.new(0.1, 0.05, 0.3), 0.55)
end

-- PIERCER: one heavy bolt. It cracks off the bow through two shock rings, punches through the
-- target and carries on, and leaves a two-tone ribbon along its whole path that spreads and
-- fades after it has gone (Astrea's Nebula Piercer).
local function playPiercer(ctx: Context)
	local args, recipe, palette, pool = ctx.Args, ctx.Recipe, ctx.Palette, ctx.Pool
	local cue = args.Cue
	local origin = originOf(args, recipe)
	local startAt, arriveAt = ctx.StartAt, ctx.ArriveAt
	local scale = recipe.Scale or 1
	local impact = recipe.Impact or 3
	local pierce = recipe.Pierce or 0
	local body = projectile(recipe, palette)
	local flightTime = math.max(0.05, arriveAt - startAt)
	local aimed = args.Target()
	local distance = math.max(1, VfxMath.Distance(origin, aimed))
	local speed = distance / flightTime
	local exit = VfxMath.Extend(origin, aimed, pierce)
	local exitAt = arriveAt + pierce / speed
	local direction = aimed - origin
	local seed = cue.NetId % 17

	-- Muzzle: a flash, a star glint and two rings thrown forward off the string.
	VfxPrimitives.Burst(pool, origin, palette.Core, 1.5 * scale, startAt, 0.14)
	VfxPrimitives.Flare(pool, fixed(origin), 3 * scale, palette.Secondary, startAt, 0.2)
	if direction.Magnitude > 1e-3 then
		local unit = direction.Unit
		VfxPrimitives.FlightRing(pool, origin + unit * 0.8, unit, 0.9 * scale, palette.Core, startAt)
		VfxPrimitives.FlightRing(pool, origin + unit * 2, unit, 1.5 * scale, palette.Primary, startAt + 0.05)
		if recipe.Rings then
			for _, f in { 0.4, 0.75 } do
				VfxPrimitives.FlightRing(pool, VfxMath.Lerp(origin, aimed, f), unit, 0.6 * scale, palette.Secondary, startAt + f * flightTime)
			end
		end
	end

	fly(pool, body, origin, args.Target, startAt, arriveAt, VfxMath.ArcLift(origin, cue.Aim, recipe.Arc), function(at: Vector3)
		VfxPrimitives.Burst(pool, at, palette.Core, impact, arriveAt, 0.18)
		VfxPrimitives.Burst(pool, at, palette.Primary, impact * 1.6, arriveAt + 0.03, 0.38)
		VfxPrimitives.Flare(pool, fixed(at), impact * 2.2, palette.Secondary, arriveAt, 0.24)
		VfxPrimitives.FlightRing(pool, at, direction, impact * 0.75, palette.Secondary, arriveAt)
		if pierce > 0 then
			fly(pool, body, at, fixed(exit), arriveAt, exitAt, 0, function(tail: Vector3)
				VfxPrimitives.Burst(pool, tail, palette.Primary, impact * 0.6, exitAt, 0.2)
			end)
		end
	end)

	-- The nebula: a wide violet wake and a thin bright thread inside it.
	local width = recipe.Width or 1.1
	local linger = recipe.Linger or 0.7
	VfxPrimitives.Ribbon(pool, { From = origin, To = exit, StartAt = startAt, EndAt = exitAt, Width = width, Inner = palette.Primary, Outer = nebula(palette), Linger = linger, Seed = seed })
	VfxPrimitives.Ribbon(pool, { From = origin, To = exit, StartAt = startAt, EndAt = exitAt, Width = width * 0.3, Inner = palette.Core, Outer = palette.Secondary, Linger = linger * 0.6, Seed = seed + 4.2 })

	-- Everything else the server says the bolt went through flashes as it passes.
	local mid = VfxMath.Lerp(origin, exit, 0.5)
	local reach = VfxMath.Distance(origin, exit) / 2 + 3
	afterHits(ctx, "HIT", fixed(mid), reach, function(points: { Vector3 })
		local now = arriveAt + HIT_LOOKUP_DELAY
		for i, point in points do
			if i > 6 then
				break
			end
			local hit = chest(point)
			if VfxMath.Distance(hit, aimed) > 2 then
				VfxPrimitives.Burst(pool, hit, palette.Primary, impact * 0.7, now, 0.2)
				VfxPrimitives.Flare(pool, fixed(hit), impact * 1.2, palette.Secondary, now, 0.18)
			end
		end
	end)
	shake(ctx, arriveAt)
end

-- WHIRL: a full-circle spin. On each server damage tick a pair of crescents sweeps a third of
-- the way round the attacker (so three ticks close the circle), a shockwave rolls out to the
-- spin's reach on the first and last, and every mob the server reports hit flashes (Rhyman's
-- Reaver's Whirl). It follows the attacker, who may still be sliding into range.
local function playWhirl(ctx: Context)
	local pool, recipe, palette, args = ctx.Pool, ctx.Recipe, ctx.Palette, ctx.Args
	local self = args.Self or function(): Vector3
		return args.Origin - Vector3.new(0, 2, 0)
	end
	local radius = recipe.Radius or 9
	local scale = recipe.Scale or 1
	local archetype = args.WeaponType and SkillVfxCatalog.WeaponArchetype[args.WeaponType]
	local profile = ArchetypeCombatSkills.GetSkillProfile(args.HeroId, archetype)
	local ticks, gap = HeroActionTiming.Ticks(profile.Special)
	local waves = VfxMath.WaveTimes(ctx.ArriveAt, ticks, if gap > 0 then gap else 0.1)
	local first, last = waves[1], waves[#waves]
	local yaw = VfxPrimitives.Yaw(heading(ctx))
	local turn = math.pi * 2 / #waves
	local feet = self()
	for k, at in waves do
		-- The spin turns left, so each tick's crescent starts where the last one ended.
		local facing = yaw + (k - 0.5) * turn - math.pi / 2
		local waist = CFrame.new(feet + Vector3.new(0, 2.2, 0)) * CFrame.Angles(0, facing, math.rad(if k % 2 == 0 then 5 else -5))
		VfxPrimitives.SlashArc(pool, waist, radius * 0.72 * scale, palette.Primary, at - 0.05, 0.34)
		VfxPrimitives.SlashArc(pool, waist * CFrame.new(0, 0.25, 0), radius * 0.5 * scale, palette.Core, at - 0.03, 0.26)
		VfxPrimitives.SlashArc(pool, waist * CFrame.new(0, -0.5, 0), radius * 0.9 * scale, palette.Secondary, at, 0.42)
	end
	VfxPrimitives.Ring(pool, { Center = feet, From = 1.5, To = radius, Color = palette.Primary, StartAt = first, EndAt = first + 0.4, Width = 0.8 })
	VfxPrimitives.Ring(pool, { Center = feet, From = radius * 0.4, To = radius * 1.05, Color = palette.Core, StartAt = last, EndAt = last + 0.35, Width = 0.5 })
	VfxPrimitives.Disc(pool, { CFrame = CFrame.new(feet + Vector3.new(0, 0.15, 0)) * VfxPrimitives.FLAT, Radius = radius, Color = palette.Secondary, StartAt = first - 0.05, EndAt = last + 0.3, Grow = 0.3, Transparency = 0.6 })
	VfxPrimitives.Motes(pool, feet + Vector3.new(0, 0.6, 0), palette.Secondary, first, 5, 0.6)

	local lookup = args.RecentHits
	if lookup then
		for k, at in waves do
			VfxPrimitives.At(pool, at + HIT_LOOKUP_DELAY, function()
				local now = at + HIT_LOOKUP_DELAY
				for i, point in lookup("HIT", feet, radius + 3, at - 0.1) do
					if i > 6 then
						break
					end
					local body = chest(point)
					local away = body - (feet + Vector3.new(0, 2, 0))
					local frame = if away.Magnitude > 0.5 then CFrame.lookAt(body, body + away) else CFrame.new(body)
					VfxPrimitives.SlashArc(pool, frame * CFrame.Angles(0, 0, math.rad(if (i + k) % 2 == 0 then 20 else -20)), 1.6 * SLASH_SIZE, palette.Core, now, 0.22)
					VfxPrimitives.Burst(pool, body, palette.Primary, recipe.Impact or 2, now, 0.18)
				end
			end)
		end
	end
	shake(ctx, first)
end

-- CLEAVE: a wide slash and a shockwave cone sweeping out in front of the Vanguard.
local function playCleave(ctx: Context)
	local pool, recipe, palette = ctx.Pool, ctx.Recipe, ctx.Palette
	local at = ctx.Args.Target()
	local from = if ctx.Args.Self then ctx.Args.Self() else ctx.Args.Origin
	local scale = recipe.Scale or 1
	VfxPrimitives.SlashArc(pool, slashFrame(ctx, at, 0), 2.8 * scale * SLASH_SIZE, palette.Primary, ctx.ArriveAt, 0.38)
	VfxPrimitives.Ring(pool, { Center = from, From = 1.5, To = recipe.Radius or 10, Color = palette.Secondary, StartAt = ctx.ArriveAt, EndAt = ctx.ArriveAt + 0.4, Arc = 110, Facing = VfxPrimitives.Yaw(heading(ctx)), Width = 0.9 })
	VfxPrimitives.Burst(pool, at, palette.Core, recipe.Impact or 2.2, ctx.ArriveAt + 0.04, 0.22)
end

-- CROSS: two crescents crossing on the target, the second a beat after the first.
local function playCross(ctx: Context)
	local pool, recipe, palette = ctx.Pool, ctx.Recipe, ctx.Palette
	local at = ctx.Args.Target()
	local scale = recipe.Scale or 1
	VfxPrimitives.SlashArc(pool, slashFrame(ctx, at, 40), 2.4 * scale * SLASH_SIZE, palette.Primary, ctx.ArriveAt - 0.06)
	VfxPrimitives.SlashArc(pool, slashFrame(ctx, at, -40), 2.4 * scale * SLASH_SIZE, palette.Secondary, ctx.ArriveAt + 0.04)
	VfxPrimitives.Burst(pool, at, palette.Core, recipe.Impact or 1.8, ctx.ArriveAt + 0.06, 0.2)
end

-- PLUNGE: two near-vertical crescents falling on the target side by side, one per damage tick,
-- with a puff of smoke rolling out along the ground where the blades land.
local function playPlunge(ctx: Context)
	local pool, recipe, palette, args = ctx.Pool, ctx.Recipe, ctx.Palette, ctx.Args
	local at = args.Target()
	local ground = args.Cue.Aim
	local scale = recipe.Scale or 1
	local archetype = args.WeaponType and SkillVfxCatalog.WeaponArchetype[args.WeaponType]
	local profile = ArchetypeCombatSkills.GetSkillProfile(args.HeroId, archetype)
	local ticks, gap = HeroActionTiming.Ticks(profile.Special)
	local side = heading(ctx):Cross(Vector3.yAxis)
	for k, hitAt in VfxMath.WaveTimes(ctx.ArriveAt, math.max(2, ticks), if gap > 0 then gap else 0.08) do
		local sign = if k % 2 == 1 then -1 else 1
		local frame = slashFrame(ctx, at + side * (0.55 * sign * scale) + Vector3.new(0, 0.6, 0), 90 + 10 * sign)
		VfxPrimitives.SlashArc(pool, frame, 2.3 * scale * SLASH_SIZE, if k % 2 == 1 then palette.Primary else palette.Core, hitAt - 0.05, 0.3)
		VfxPrimitives.SlashArc(pool, frame * CFrame.new(0, 0, 0.25), 2.6 * scale * SLASH_SIZE, palette.Secondary, hitAt - 0.02, 0.42)
	end
	local radius = recipe.Radius or 4
	VfxPrimitives.Ring(pool, { Center = ground, From = 0.6, To = radius, Color = palette.Secondary, StartAt = ctx.ArriveAt, EndAt = ctx.ArriveAt + 0.45, Width = 1.1 })
	VfxPrimitives.Ring(pool, { Center = ground, From = 0.3, To = radius * 0.7, Color = palette.Primary, StartAt = ctx.ArriveAt + 0.05, EndAt = ctx.ArriveAt + 0.4, Width = 0.35 })
	VfxPrimitives.Motes(pool, ground + Vector3.new(0, 0.8, 0), palette.Secondary, ctx.ArriveAt, 6, 0.7)
	VfxPrimitives.Burst(pool, at, palette.Core, recipe.Impact or 2, ctx.ArriveAt + 0.03, 0.2)
end

-- TREMOR: a ground shockwave from the target with a few spikes of rock and crystal.
local function playTremor(ctx: Context)
	local pool, recipe, palette = ctx.Pool, ctx.Recipe, ctx.Palette
	local center: Vector3 = ctx.Args.Cue.Aim
	local radius = recipe.Radius or 8
	VfxPrimitives.Ring(pool, { Center = center, From = 1, To = radius, Color = palette.Primary, StartAt = ctx.ArriveAt, EndAt = ctx.ArriveAt + 0.45, Width = 1.0 })
	VfxPrimitives.Disc(pool, { CFrame = CFrame.new(center + Vector3.new(0, 0.15, 0)) * VfxPrimitives.FLAT, Radius = radius * 0.6, Color = palette.Secondary, StartAt = ctx.ArriveAt, EndAt = ctx.ArriveAt + 0.5, Grow = 0.2, Transparency = 0.5 })
	for i = 1, recipe.Spikes or 3 do
		local angle = i / (recipe.Spikes or 3) * math.pi * 2 + ctx.Args.Cue.NetId
		local base = center + Vector3.new(math.cos(angle) * radius * 0.35, 0, math.sin(angle) * radius * 0.35)
		VfxPrimitives.Spike(pool, base, 2.2, palette.Primary, ctx.ArriveAt + 0.03 * i, 0.25, i)
	end
	VfxPrimitives.Burst(pool, center + Vector3.new(0, 1, 0), palette.Core, recipe.Impact or 2.4, ctx.ArriveAt, 0.25)
end

-- CHAIN: a bolt to the target, then lightning to each enemy the server chained to.
local function playChain(ctx: Context)
	local pool, recipe, palette = ctx.Pool, ctx.Recipe, ctx.Palette
	playProjectile(ctx)
	local target = ctx.Args.Target
	afterHits(ctx, "HIT", target, recipe.Radius or 14, function(points: { Vector3 })
		local from = target()
		local now = ctx.ArriveAt + HIT_LOOKUP_DELAY
		local drawn = 0
		for i, point in points do
			if VfxMath.Distance(point, from) > 1 and drawn < 3 then
				drawn += 1
				VfxPrimitives.Beam(pool, from, point + Vector3.new(0, 1.5, 0), palette.Secondary, now, 0.3, i + ctx.Args.Cue.NetId)
				VfxPrimitives.Burst(pool, point + Vector3.new(0, 1.5, 0), palette.Core, (recipe.Impact or 2) * 0.7, now, 0.2)
			end
		end
	end)
end

-- A ring of light lying flat on the ground under `point` (a landing shockwave).
local function groundRing(pool: VfxPool.VfxPool, point: Vector3, radius: number, color: Color3, at: number, duration: number)
	local ground = CFrame.new(point.X, point.Y - 1.8, point.Z) * CFrame.Angles(0, 0, math.pi / 2)
	VfxPrimitives.Disc(pool, { CFrame = ground, Radius = radius, Color = color, StartAt = at, EndAt = at + duration, Grow = 0.15, Transparency = 0.3 })
end

-- A bright, layered hit: a big burst, a gold glint, a ground shockwave and rising sparks.
local function bigHit(pool: VfxPool.VfxPool, palette: Palette, point: Vector3, size: number, at: number)
	VfxPrimitives.Burst(pool, point, palette.Primary, size * 1.3, at, 0.4)
	VfxPrimitives.Burst(pool, point, palette.Core, size * 0.7, at, 0.25)
	VfxPrimitives.Flare(pool, fixed(point), size * 1.7, palette.Secondary, at, 0.4)
	groundRing(pool, point, size * 1.1, palette.Primary, at, 0.55)
	VfxPrimitives.Motes(pool, point, palette.Secondary, at, 8, 0.6)
end

-- RICOCHET: the arrow strikes the target with a big gilt glint and shockwave, then bounces on to
-- each enemy the server carried the hit to (Isabelle's Ricochet): a full-size arrow trailing a
-- glowing crimson wake from the target to each, nearest first, up to Bounces, landing in a flash.
local function playRicochet(ctx: Context)
	local pool, recipe, palette = ctx.Pool, ctx.Recipe, ctx.Palette
	local impact = recipe.Impact or 2.4
	playProjectile(ctx)
	local target = ctx.Args.Target
	VfxPrimitives.Flare(pool, target, impact * 2.2, palette.Secondary, ctx.ArriveAt, 0.35)
	VfxPrimitives.Burst(pool, target(), palette.Core, impact * 1.4, ctx.ArriveAt, 0.35)
	afterHits(ctx, "HIT", target, recipe.Radius or 14, function(points: { Vector3 })
		local from = target()
		local now = ctx.ArriveAt + HIT_LOOKUP_DELAY
		local others = {}
		for _, point in points do
			if VfxMath.Distance(point, from) > 1.5 then
				table.insert(others, point)
			end
		end
		table.sort(others, function(a: Vector3, b: Vector3): boolean
			return VfxMath.Distance(a, from) < VfxMath.Distance(b, from)
		end)
		local body = projectile(recipe, palette, (recipe.Scale or 1) * 1.15)
		for i = 1, math.min(#others, recipe.Bounces or 1) do
			local point = others[i] + Vector3.new(0, 1.5, 0)
			local travel = math.clamp(VfxMath.Distance(from, point) / 40, 0.2, 0.4)
			-- The deflection: a glass ring on the target, facing the way the arrow leaves.
			VfxPrimitives.FlightRing(pool, from, point - from, 2.2, palette.Secondary, now)
			VfxPrimitives.Ribbon(pool, { From = from, To = point, StartAt = now, EndAt = now + travel, Width = 0.7,
				Inner = palette.Primary, Outer = palette.Accent or palette.Secondary, Linger = 0.6, Seed = ctx.Args.Cue.NetId + i })
			fly(pool, body, from, fixed(point), now, now + travel, 1.2, function(at: Vector3)
				bigHit(pool, palette, at, impact, now + travel)
			end)
		end
	end)
end

-- MEND: a bolt to the enemy, then motes of light rising from whoever the server healed.
local function playMend(ctx: Context)
	local pool, palette = ctx.Pool, ctx.Palette
	playProjectile(ctx)
	local self = ctx.Args.Self or function(): Vector3
		return ctx.Args.Origin
	end
	afterHits(ctx, "HEAL", self, 40, function(points: { Vector3 })
		local now = ctx.ArriveAt + HIT_LOOKUP_DELAY
		for _, point in points do
			VfxPrimitives.Motes(pool, point + Vector3.new(0, 1, 0), palette.Secondary, now, 6)
			VfxPrimitives.Burst(pool, point + Vector3.new(0, 1.5, 0), palette.Secondary, 2.2, now, 0.3)
		end
	end)
end

-- Skill -------------------------------------------------------------------------------------

-- STORM: a flare climbs from the bow, a sigil opens over the aim point, then one wave of arrows
-- falls per server damage tick.
local function playStorm(ctx: Context)
	local args, recipe, palette, pool = ctx.Args, ctx.Recipe, ctx.Palette, ctx.Pool
	local cue = args.Cue
	local origin = args.Origin
	local aim: Vector3 = cue.Aim
	local archetype = args.WeaponType and SkillVfxCatalog.WeaponArchetype[args.WeaponType]
	local profile = ArchetypeCombatSkills.GetSkillProfile(args.HeroId, archetype)
	local ticks, gap = HeroActionTiming.Ticks(profile.Skill)
	local waves = VfxMath.WaveTimes(ctx.ArriveAt, ticks, gap)
	local lastWave = waves[#waves]
	local radius = recipe.SigilRadius or 16

	local flareTop = origin + Vector3.new(0, recipe.FlareHeight or 26, 0)
	fly(pool, projectile(recipe, palette, (recipe.Scale or 1) * 1.15), origin, fixed(flareTop), ctx.StartAt, ctx.ArriveAt, 0, function(at: Vector3)
		VfxPrimitives.Burst(pool, at, palette.Secondary, 3, ctx.ArriveAt, 0.35)
	end)
	VfxPrimitives.Sigil(pool, aim, radius, palette, ctx.StartAt, lastWave + SIGIL_LINGER)

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
	shake(ctx, waves[1])
end

-- TWIN: one large glowing arrow leaves the bow. Ahead of it a gilt mirror pane forms in the air;
-- the arrow strikes it in a big gold flash and a spray of sparks, and splits in two. One half
-- flies on into the target, the other to the second target the server picked (or, for a lone
-- target, arcing over and into the same one), each trailing a crimson wake, and both land
-- together in bright hits while the pane lingers and fades (Isabelle's Twin Reflection).
local MIRROR_FORM = 0.25 -- the pane appears this long before the arrow reaches it
local MIRROR_LINGER = 0.7 -- and stays this long after the split

local function playTwin(ctx: Context)
	local args, recipe, palette, pool = ctx.Args, ctx.Recipe, ctx.Palette, ctx.Pool
	local origin = originOf(args, recipe)
	local startAt, arriveAt = ctx.StartAt, ctx.ArriveAt
	local split = recipe.Split or 0.42
	local splitAt = startAt + (arriveAt - startAt) * split
	local aim = args.Target()
	local splitPoint = origin:Lerp(aim, split) + Vector3.new(0, 1, 0)
	local impact = recipe.Impact or 3
	local lead = projectile(recipe, palette, (recipe.Scale or 1) * 1.6)
	local half = projectile(recipe, palette, (recipe.Scale or 1) * 1.25)
	local twin = args.Twin and args.Twin()
	local lone = twin == nil or VfxMath.Distance(twin :: Vector3, aim) < 2
	local function secondTo(): Vector3
		local live = args.Twin and args.Twin()
		return if live then live else args.Target()
	end

	-- The mirror pane: a glass disc facing along the flight inside a wider gilt rim.
	local direction = aim - origin
	if direction.Magnitude > 1e-3 then
		local frame = CFrame.lookAt(splitPoint, splitPoint + direction) * CFrame.Angles(0, math.pi / 2, 0)
		local formAt = math.max(startAt, splitAt - MIRROR_FORM)
		VfxPrimitives.Disc(pool, { CFrame = frame, Radius = 4.2, Color = palette.Secondary, StartAt = formAt, EndAt = splitAt + MIRROR_LINGER, Grow = 0.1, Transparency = 0.45 })
		VfxPrimitives.Disc(pool, { CFrame = frame * CFrame.new(0.05, 0, 0), Radius = 3.4, Color = palette.Accent or palette.Core, StartAt = formAt, EndAt = splitAt + MIRROR_LINGER, Grow = 0.1, Transparency = 0.25 })
	end

	fly(pool, lead, origin, fixed(splitPoint), startAt, splitAt, 0.2, function(at: Vector3)
		-- The split: a big gold flash, a white core flash, a shockwave ring and a spray of sparks.
		VfxPrimitives.Flare(pool, fixed(at), 10, palette.Secondary, splitAt, 0.55)
		VfxPrimitives.Flare(pool, fixed(at), 6, palette.Core, splitAt, 0.35)
		VfxPrimitives.Burst(pool, at, palette.Core, impact * 1.4, splitAt, 0.4)
		VfxPrimitives.Burst(pool, at, palette.Primary, impact * 2, splitAt + 0.05, 0.5)
		VfxPrimitives.FlightRing(pool, at, direction, 5, palette.Secondary, splitAt)
		VfxPrimitives.Motes(pool, at, palette.Secondary, splitAt, 16, 0.8)
		VfxPrimitives.Motes(pool, at, palette.Core, splitAt, 10, 0.6)
		local function land(point: Vector3)
			bigHit(pool, palette, point, impact, arriveAt)
		end
		local seed = args.Cue.NetId
		VfxPrimitives.Ribbon(pool, { From = at, To = aim, StartAt = splitAt, EndAt = arriveAt, Width = 0.9,
			Inner = palette.Primary, Outer = palette.Secondary, Linger = 0.7, Seed = seed })
		fly(pool, half, at, args.Target, splitAt, arriveAt, 0.4, land)
		local second = secondTo()
		if not lone then
			VfxPrimitives.Ribbon(pool, { From = at, To = second, StartAt = splitAt, EndAt = arriveAt, Width = 0.9,
				Inner = palette.Primary, Outer = palette.Secondary, Linger = 0.7, Seed = seed + 3 })
		end
		fly(pool, half, at, if lone then args.Target else secondTo, splitAt, arriveAt, if lone then 4 else 1.4, land)
	end)
	shake(ctx, splitAt)
	shake(ctx, arriveAt)
end

local STAR_FALL_SECONDS = 0.24
-- The figure is finished this long before its first stars fall, so it reads whole for a beat.
local FIGURE_HOLD = 0.1

-- CONSTELLATION: an arrow is loosed into the sky and bursts; over the aim point a constellation
-- then draws itself star by star and line by line, and once it is whole its stars fall as
-- bolts, one wave per server damage tick, each landing under where it hung (Astrea's
-- Constellation Judgment). The last wave closes with a shockwave over the whole area.
local function playConstellation(ctx: Context)
	local args, recipe, palette, pool = ctx.Args, ctx.Recipe, ctx.Palette, ctx.Pool
	local cue = args.Cue
	local origin = originOf(args, recipe)
	local aim: Vector3 = cue.Aim
	local radius = recipe.Radius or 16
	local height = recipe.RainHeight or 20
	local archetype = args.WeaponType and SkillVfxCatalog.WeaponArchetype[args.WeaponType]
	local profile = ArchetypeCombatSkills.GetSkillProfile(args.HeroId, archetype)
	local ticks, gap = HeroActionTiming.Ticks(profile.Skill)
	local waves = VfxMath.WaveTimes(ctx.ArriveAt, ticks, gap)
	local first, last = waves[1], waves[#waves]
	local startAt = ctx.StartAt
	local towards = heading(ctx)
	local sky = aim + Vector3.new(0, height, 0)
	local figure = VfxMath.ARCHER

	-- The shot: straight up off the bow, leaning a little towards the target, and gone in a flash.
	local window = math.max(0.1, first - STAR_FALL_SECONDS - startAt)
	local flareAt = startAt + math.min(0.16, window * 0.3)
	local flareHeight = recipe.FlareHeight or 30
	local flareTop = origin + Vector3.new(0, flareHeight, 0) + towards * (flareHeight * 0.2)
	fly(pool, projectile(recipe, palette, (recipe.Scale or 1) * 1.3), origin, fixed(flareTop), startAt, flareAt, 0, function(at: Vector3)
		VfxPrimitives.Burst(pool, at, palette.Core, 3.5, flareAt, 0.3)
		VfxPrimitives.Flare(pool, fixed(at), 7, palette.Secondary, flareAt, 0.3)
	end)
	VfxPrimitives.Burst(pool, origin, palette.Core, 1.4, startAt, 0.14)
	VfxPrimitives.Disc(pool, { CFrame = CFrame.new(origin + Vector3.new(0, 1.2, 0)) * VfxPrimitives.FLAT, Radius = 1.4, Color = palette.Secondary, StartAt = startAt, EndAt = startAt + 0.35, Grow = 0.3, Transparency = 0.25 })

	-- The sky answers: a glint where the figure will hang, then it draws itself.
	local drawnAt = math.max(flareAt + 0.05, first - STAR_FALL_SECONDS - FIGURE_HOLD)
	local lineStarts, lineSeconds, starAt = VfxMath.FigureTrace(figure, flareAt, drawnAt)
	local ground = VfxMath.FigurePoints(figure, aim, radius * 0.9, towards)
	local stars = table.create(#ground)
	local dropAt = table.create(#ground)
	local landAt = table.create(#ground)
	for i, point in ground do
		local wave = waves[(i - 1) % #waves + 1]
		-- Stars of one wave land a few hundredths apart, so a wave patters instead of clapping.
		local land = wave + ((i * 7) % 5) * 0.012
		table.insert(stars, point + Vector3.new(0, height, 0))
		table.insert(landAt, land)
		table.insert(dropAt, land - STAR_FALL_SECONDS)
	end
	local endAt = last + SIGIL_LINGER
	VfxPrimitives.Flare(pool, fixed(sky), radius * 0.9, palette.Core, flareAt, 0.3)
	VfxPrimitives.Disc(pool, { CFrame = CFrame.new(sky - Vector3.new(0, 0.4, 0)) * VfxPrimitives.FLAT, Radius = radius, Color = nebula(palette), StartAt = flareAt, EndAt = endAt, Grow = 0.15, Transparency = 0.72 })
	VfxPrimitives.Constellation(pool, { Stars = stars, Lines = figure.Lines, LineStarts = lineStarts, LineSeconds = lineSeconds, StarAt = starAt, DropAt = dropAt, EndAt = endAt, StarSize = 1.1, Palette = palette })

	-- The ground under it: the area marked by a rim of light while the stars are overhead.
	VfxPrimitives.Ring(pool, { Center = aim, From = 1, To = radius, Color = palette.Secondary, StartAt = flareAt, EndAt = flareAt + 0.35, Width = 0.5 })
	VfxPrimitives.Ring(pool, { Center = aim, From = radius * 0.97, To = radius, Color = palette.Primary, StartAt = flareAt + 0.3, EndAt = endAt, Width = 0.35 })
	VfxPrimitives.Disc(pool, { CFrame = CFrame.new(aim + Vector3.new(0, 0.15, 0)) * VfxPrimitives.FLAT, Radius = radius, Color = palette.Primary, StartAt = flareAt, EndAt = endAt, Grow = 0.2, Transparency = 0.7 })

	-- The fall. A bolt lands a little past the point under its star, so it never drops dead
	-- vertical (a projectile has no heading to face straight down).
	local body = projectile(recipe, palette)
	local impact = recipe.Impact or 2.4
	local slant = towards * 1.6
	for i, point in ground do
		local land = landAt[i]
		fly(pool, body, stars[i], fixed(point + slant), dropAt[i], land, 0, function(at: Vector3)
			VfxPrimitives.Burst(pool, at + Vector3.new(0, 0.6, 0), palette.Core, impact, land, 0.16)
			VfxPrimitives.Burst(pool, at + Vector3.new(0, 0.6, 0), palette.Primary, impact * 1.5, land + 0.02, 0.3)
			VfxPrimitives.Ring(pool, { Center = at, From = 0.4, To = impact * 1.2, Color = palette.Secondary, StartAt = land, EndAt = land + 0.3, Width = 0.3 })
		end)
	end
	for _, wave in waves do
		VfxPrimitives.Motes(pool, aim + Vector3.new(0, 0.8, 0), palette.Secondary, wave, 3, 0.6)
	end

	-- The verdict: the empty sky flashes and a shockwave closes the area on the last wave.
	VfxPrimitives.Flare(pool, fixed(chest(aim)), radius * 0.7, palette.Core, last, 0.3)
	VfxPrimitives.Ring(pool, { Center = aim, From = radius * 0.3, To = radius * 1.08, Color = palette.Core, StartAt = last, EndAt = last + 0.4, Width = 0.9 })
	shake(ctx, first)
	local callback, magnitude = args.Shake, recipe.Shake
	if callback and magnitude then
		VfxPrimitives.At(pool, last, function()
			callback(magnitude * 0.7)
		end)
	end
end

-- EXECUTE: one blow from above. A blade of light drops along the axe's path onto the target,
-- two tall crescents cut it top to bottom, the ground cracks in a line past it and a crater of
-- dark dust lingers (Rhyman's Headsman's Verdict). One target: nothing else is touched.
local function playExecute(ctx: Context)
	local pool, recipe, palette, args = ctx.Pool, ctx.Recipe, ctx.Palette, ctx.Args
	local at = ctx.ArriveAt
	local body = args.Target()
	local ground = Vector3.new(body.X, args.Cue.Aim.Y, body.Z)
	local towards = heading(ctx)
	local radius = recipe.Radius or 4
	local scale = recipe.Scale or 1
	local height = recipe.PillarHeight or 16
	local impact = recipe.Impact or 4.5
	local linger = recipe.Linger or 0.9
	local accent = palette.Accent or palette.Core

	-- The blade: from above and a little behind (the axe's own arc, and never dead vertical).
	local top = ground + Vector3.new(0, height, 0) - towards * (height * 0.14)
	VfxPrimitives.Lance(pool, top, ground, 1.5 * scale, palette, at - 0.05, 0.05, 0.07, 0.32)
	VfxPrimitives.Beam(pool, top, ground, accent, at, 0.2, args.Cue.NetId % 11)

	-- The cut: two tall crescents down through the target, a hair apart.
	local cut = slashFrame(ctx, body + Vector3.new(0, 1.2, 0), 90)
	VfxPrimitives.SlashArc(pool, cut, 3.4 * scale * SLASH_SIZE, palette.Core, at - 0.04, 0.34)
	VfxPrimitives.SlashArc(pool, cut * CFrame.new(0, 0, 0.3), 3.9 * scale * SLASH_SIZE, palette.Primary, at - 0.01, 0.46)
	VfxPrimitives.SlashArc(pool, cut * CFrame.new(0, 0, 0.6), 4.3 * scale * SLASH_SIZE, palette.Secondary, at + 0.02, 0.6)
	VfxPrimitives.Burst(pool, body, palette.Core, impact, at, 0.16)
	VfxPrimitives.Burst(pool, body, palette.Primary, impact * 1.7, at + 0.03, 0.4)
	VfxPrimitives.Flare(pool, fixed(body), impact * 2.6, accent, at, 0.26)

	-- The ground: a shockwave, a crater of dark dust, and a crack running on past the target.
	VfxPrimitives.Ring(pool, { Center = ground, From = 0.6, To = radius * 1.6, Color = palette.Primary, StartAt = at, EndAt = at + 0.4, Width = 1.1 })
	VfxPrimitives.Ring(pool, { Center = ground, From = 0.3, To = radius, Color = palette.Core, StartAt = at + 0.05, EndAt = at + 0.35, Width = 0.4 })
	VfxPrimitives.Disc(pool, { CFrame = CFrame.new(ground + Vector3.new(0, 0.15, 0)) * VfxPrimitives.FLAT, Radius = radius, Color = palette.Secondary, StartAt = at, EndAt = at + linger, Grow = 0.3, Transparency = 0.35 })
	local crackFrom = ground - towards * 1.5 + Vector3.new(0, 0.3, 0)
	local crackTo = ground + towards * (radius * 2.2) + Vector3.new(0, 0.3, 0)
	VfxPrimitives.Beam(pool, crackFrom, crackTo, palette.Primary, at, linger * 0.7, args.Cue.NetId % 7 + 2)
	VfxPrimitives.Beam(pool, crackFrom, crackTo, palette.Core, at + 0.02, linger * 0.4, args.Cue.NetId % 5 + 6)
	for i = 1, 3 do
		local along = ground + towards * (radius * 0.55 * i)
		VfxPrimitives.Spike(pool, along, 1.4 + 0.5 * (i % 2), palette.Secondary, at + 0.04 * i, linger * 0.5, i + args.Cue.NetId % 9)
	end
	VfxPrimitives.Motes(pool, ground + Vector3.new(0, 0.8, 0), palette.Secondary, at, 8, 0.8)
	shake(ctx, at)
end

-- BULWARK: a barrier shell around the Vanguard for the barrier's duration, and a taunt
-- shockwave rolling out to the taunt radius.
local function playBulwark(ctx: Context)
	local pool, recipe, palette = ctx.Pool, ctx.Recipe, ctx.Palette
	local self = ctx.Args.Self or function(): Vector3
		return ctx.Args.Origin
	end
	local at = ctx.ArriveAt
	VfxPrimitives.Shell(pool, function(): Vector3
		return chest(self())
	end, 3.6, palette.Secondary, at, at + (recipe.Linger or 6))
	VfxPrimitives.Ring(pool, { Center = self(), From = 2, To = recipe.Radius or 25, Color = palette.Primary, StartAt = at, EndAt = at + 0.7, Width = 1.2 })
	VfxPrimitives.Ring(pool, { Center = self(), From = 1, To = (recipe.Radius or 25) * 0.6, Color = palette.Secondary, StartAt = at + 0.12, EndAt = at + 0.8, Width = 0.7 })
	VfxPrimitives.Burst(pool, chest(self()), palette.Core, recipe.Impact or 3, at, 0.3)
	shake(ctx, at)
end

-- TEMPEST: a storm of crescents around the target and a shockwave over the skill radius.
-- With Implode, a sphere first collapses into the target (a rift tearing open).
local function playTempest(ctx: Context)
	local pool, recipe, palette = ctx.Pool, ctx.Recipe, ctx.Palette
	local center = ctx.Args.Cue.Aim
	local radius = recipe.Radius or 12
	local at = ctx.ArriveAt
	if recipe.Implode then
		VfxPrimitives.Shell(pool, fixed(center + Vector3.new(0, 1.5, 0)), 5, palette.Secondary, ctx.StartAt, at)
	end
	local slashes = recipe.Slashes or 6
	for i = 1, slashes do
		local angle = (i / slashes) * math.pi * 2
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius * 0.3
		local frame = CFrame.new(center + offset + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, angle, math.rad(if i % 2 == 0 then 35 else -35))
		VfxPrimitives.SlashArc(pool, frame, radius * 0.3 * SLASH_SIZE, if i % 2 == 0 then palette.Primary else palette.Secondary, at - 0.25 + i * (0.25 / slashes), 0.35)
	end
	VfxPrimitives.Ring(pool, { Center = center, From = 1, To = radius, Color = palette.Primary, StartAt = at, EndAt = at + 0.45, Width = 0.9 })
	VfxPrimitives.Burst(pool, center + Vector3.new(0, 1.5, 0), palette.Core, recipe.Impact or 3, at, 0.3)
	shake(ctx, at)
end

-- WAKE: a dash streak from the attacker through the target, then a smoky circle over the skill
-- radius that keeps cutting: one wave of crescents inside it per server damage tick.
local function playWake(ctx: Context)
	local pool, recipe, palette, args = ctx.Pool, ctx.Recipe, ctx.Palette, ctx.Args
	local center: Vector3 = args.Cue.Aim
	local radius = recipe.Radius or 12
	local archetype = args.WeaponType and SkillVfxCatalog.WeaponArchetype[args.WeaponType]
	local profile = ArchetypeCombatSkills.GetSkillProfile(args.HeroId, archetype)
	local ticks, gap = HeroActionTiming.Ticks(profile.Skill)
	local waves = VfxMath.WaveTimes(ctx.ArriveAt, ticks, gap)
	local first, last = waves[1], waves[#waves]
	local linger = recipe.Linger or 0.35
	local up = Vector3.new(0, 1.6, 0)

	-- The dash: twin streaks along his path and one long cut across the target as he passes.
	local from = if args.Self then args.Self() else args.Origin
	local dir = heading(ctx)
	local exit = center + dir * math.min(radius * 0.6, 7)
	VfxPrimitives.Beam(pool, from + up, exit + up, palette.Primary, first - 0.1, 0.3, args.Cue.NetId % 13)
	VfxPrimitives.Beam(pool, from + up * 0.6, exit + up * 0.6, palette.Secondary, first - 0.1, 0.45, args.Cue.NetId % 7 + 3)
	VfxPrimitives.SlashArc(pool, CFrame.lookAt(center + up, center + up - dir) * CFrame.Angles(0, 0, math.rad(8)), radius * 0.42 * SLASH_SIZE, palette.Core, first - 0.04, 0.36)

	-- The wake: a dark disc with a blue rim, held until the last wave has landed.
	local ground = CFrame.new(center + Vector3.new(0, 0.15, 0)) * VfxPrimitives.FLAT
	VfxPrimitives.Disc(pool, { CFrame = ground, Radius = radius, Color = palette.Secondary, StartAt = first - 0.05, EndAt = last + linger, Grow = 0.25, Transparency = 0.3 })
	VfxPrimitives.Ring(pool, { Center = center, From = 1, To = radius, Color = palette.Primary, StartAt = first, EndAt = first + 0.3, Width = 0.5 })
	VfxPrimitives.Ring(pool, { Center = center, From = radius * 0.96, To = radius, Color = palette.Primary, StartAt = first + 0.28, EndAt = last + linger, Width = 0.35 })

	local perWave = recipe.Slashes or 5
	local seedBase = (args.Cue.NetId % 89) * 0.41
	for k, waveAt in waves do
		for i, point in VfxMath.RainPoints(center, radius * 0.92, perWave, seedBase + k * 2.1) do
			local yaw = seedBase + k * 1.3 + i * 2.4
			local roll = math.rad(if (i + k) % 2 == 0 then 38 else -38)
			local frame = CFrame.new(point + up) * CFrame.Angles(0, yaw, roll)
			local size = radius * (0.2 + 0.05 * ((i + k) % 3)) * SLASH_SIZE
			VfxPrimitives.SlashArc(pool, frame, size, if (i + k) % 3 == 0 then palette.Core else palette.Primary, waveAt - 0.04 + i * 0.012, 0.3)
			VfxPrimitives.SlashArc(pool, frame * CFrame.new(0, -0.1, 0.2), size * 1.12, palette.Secondary, waveAt + i * 0.012, 0.4)
		end
		VfxPrimitives.Motes(pool, center + Vector3.new(0, 0.6, 0), palette.Secondary, waveAt, 4, 0.6)
	end
	VfxPrimitives.Burst(pool, center + up, palette.Core, recipe.Impact or 3, first, 0.25)
	VfxPrimitives.Ring(pool, { Center = center, From = radius * 0.4, To = radius * 1.05, Color = palette.Core, StartAt = last, EndAt = last + linger, Width = 0.6 })
	shake(ctx, first)
end

-- CRYSTALS: a cluster of crystal spikes at the centre, then one under each enemy the server hit.
local function playCrystals(ctx: Context)
	local pool, recipe, palette = ctx.Pool, ctx.Recipe, ctx.Palette
	local center: Vector3 = ctx.Args.Cue.Aim
	local radius = recipe.Radius or 18
	local hold = recipe.Linger or 1.2
	local at = ctx.ArriveAt
	local count = recipe.Spikes or 5
	VfxPrimitives.Spike(pool, center, 5, palette.Primary, at, hold, 0)
	for i = 1, count - 1 do
		local angle = i / (count - 1) * math.pi * 2
		VfxPrimitives.Spike(pool, center + Vector3.new(math.cos(angle) * 1.6, 0, math.sin(angle) * 1.6), 3.2, palette.Primary, at + 0.04 * i, hold, i)
	end
	VfxPrimitives.Ring(pool, { Center = center, From = 1, To = radius, Color = palette.Secondary, StartAt = at, EndAt = at + 0.5, Width = 1.0 })
	afterHits(ctx, "HIT", fixed(ctx.Args.Cue.Aim), radius, function(points: { Vector3 })
		local now = at + HIT_LOOKUP_DELAY
		for i, point in points do
			if i > 10 then
				break
			end
			VfxPrimitives.Spike(pool, point, 3.6, palette.Primary, now + 0.03 * i, hold * 0.8, i + 7)
		end
	end)
	shake(ctx, at)
end

-- PILLAR: a column of fire or light reaches down onto the aim point, bursts, and leaves burning
-- ground for the skill's linger time.
local function playPillar(ctx: Context)
	local pool, recipe, palette = ctx.Pool, ctx.Recipe, ctx.Palette
	local center: Vector3 = ctx.Args.Cue.Aim
	local radius = recipe.Radius or 20
	local at = ctx.ArriveAt
	local linger = recipe.Linger or 3
	VfxPrimitives.Disc(pool, { CFrame = CFrame.new(center + Vector3.new(0, 0.15, 0)) * VfxPrimitives.FLAT, Radius = radius * 0.4, Color = palette.Secondary, StartAt = ctx.StartAt, EndAt = at, Grow = 0.3, Transparency = 0.55 })
	VfxPrimitives.Pillar(pool, center, radius * 0.18, recipe.PillarHeight or 40, palette.Primary, ctx.StartAt, at, 0.5)
	VfxPrimitives.Burst(pool, center + Vector3.new(0, 2, 0), palette.Core, recipe.Impact or 4, at, 0.35)
	VfxPrimitives.Ring(pool, { Center = center, From = 2, To = radius, Color = palette.Secondary, StartAt = at, EndAt = at + 0.55, Width = 1.2 })
	VfxPrimitives.Disc(pool, { CFrame = CFrame.new(center + Vector3.new(0, 0.2, 0)) * VfxPrimitives.FLAT, Radius = radius * 0.8, Color = palette.Primary, StartAt = at, EndAt = at + linger, Grow = 0.4, Transparency = 0.5 })
	shake(ctx, at)
end

-- SANCTUARY: a healing circle around the healer and a column of light on every squad hero.
local function playSanctuary(ctx: Context)
	local pool, recipe, palette = ctx.Pool, ctx.Recipe, ctx.Palette
	local self = ctx.Args.Self or function(): Vector3
		return ctx.Args.Origin
	end
	local center = self()
	local radius = recipe.Radius or 25
	local at = ctx.ArriveAt
	local linger = recipe.Linger or 1.2
	VfxPrimitives.Sigil(pool, center, radius, palette, ctx.StartAt, at + linger)
	VfxPrimitives.Ring(pool, { Center = center, From = 1, To = radius, Color = palette.Secondary, StartAt = at, EndAt = at + 0.6, Width = 1.0 })
	local allies = if ctx.Args.Allies then ctx.Args.Allies() else { self() }
	for _, ally in allies do
		VfxPrimitives.Pillar(pool, ally, 1.2, recipe.PillarHeight or 14, palette.Secondary, at, at + 0.15, linger)
		VfxPrimitives.Motes(pool, chest(ally), palette.Primary, at + 0.1, 8, 1.0)
	end
end

-- Vane (docs/vane-spell-animations-plan.md §3) -----------------------------------------------

local UP = Vector3.new(0, 2, 0)
local STREAKS_PER_WAVE = 8

-- Unit direction and far end of a BEAM: from the attacker's feet through the target, `length`
-- studs, flat (the server's BEAM_LINE segment, HeroSkillEffects).
function SkillVfx.BeamLine(feet: Vector3, target: Vector3, length: number): (Vector3, Vector3)
	local flat = Vector3.new(target.X - feet.X, 0, target.Z - feet.Z)
	local direction = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
	return direction, feet + direction * length
end

-- BEAM: an instant straight laser off the staff tip, through the target and out to the kit's
-- length. A muzzle shockwave, jagged arcs wrapping the core, a swallowed hit on every mob the
-- server reports along it (rippling outward with distance) and a fading afterimage.
local function playBeam(ctx: Context)
	local pool, recipe, palette, args = ctx.Pool, ctx.Recipe, ctx.Palette, ctx.Args
	local at = ctx.ArriveAt
	local feet = if args.Self then args.Self() else args.Origin - UP
	local length = recipe.Length or 36
	local width = recipe.Width or 4
	local direction, far = SkillVfx.BeamLine(feet, args.Target(), length)
	local muzzle = originOf(args, recipe)
	local tail = far + UP
	VfxPrimitives.Lance(pool, muzzle, tail, width * 0.55, palette, at, 0.06, 0.08, recipe.Linger or 0.3)
	VfxPrimitives.Beam(pool, muzzle, tail, palette.Primary, at, 0.22, args.Cue.NetId % 13)
	VfxPrimitives.Beam(pool, muzzle, tail, palette.Accent or palette.Core, at + 0.03, 0.18, args.Cue.NetId % 7 + 5)
	VfxPrimitives.Burst(pool, muzzle, palette.Core, 1.4, at, 0.12)
	VfxPrimitives.FlightRing(pool, muzzle + direction * 0.6, direction, 1.2, palette.Core, at)
	VfxPrimitives.FlightRing(pool, muzzle + direction * 1.4, direction, 2.0, palette.Primary, at + 0.08)
	-- Afterimage: motes drift off the line as it thins.
	for i = 1, 6 do
		local point = feet + direction * (length * (i - 0.5) / 6) + UP * 0.8
		VfxPrimitives.Motes(pool, point, palette.Primary, at + 0.1 + i * 0.01, 1, 0.45)
	end
	local mid = feet + direction * (length / 2)
	afterHits(ctx, "HIT", fixed(mid), length / 2 + width, function(points: { Vector3 })
		local now = at + HIT_LOOKUP_DELAY
		for i, point in points do
			if i > 10 then
				break
			end
			local dx, dz = point.X - feet.X, point.Z - feet.Z
			local along = dx * direction.X + dz * direction.Z
			local across = math.abs(dx * direction.Z - dz * direction.X)
			if along >= -1 and along <= length + 1 and across <= width then
				local hitAt = now + along * 0.004
				local body = point + UP
				VfxPrimitives.Implode(pool, body, palette.Primary, (recipe.Impact or 2) * 1.2, hitAt, 0.12)
				VfxPrimitives.Burst(pool, body, palette.Core, recipe.Impact or 2, hitAt + 0.12, 0.14)
			end
		end
	end)
	shake(ctx, at)
end

-- SINGULARITY: a black hole floating over the aim point for the skill's ticks. It is born on
-- the first tick (a flash, an inward fold of space, the event sphere and its gold accretion
-- ring), breathes on every tick while the server's hits streak towards it, and collapses on the
-- last: shrink, a beat of nothing, then the burst.
local function playSingularity(ctx: Context)
	local pool, recipe, palette, args = ctx.Pool, ctx.Recipe, ctx.Palette, ctx.Args
	local center: Vector3 = args.Cue.Aim
	local hole = center + Vector3.new(0, 3, 0)
	local radius = recipe.Radius or 16
	local core = recipe.Core or 2.6
	local linger = recipe.Linger or 0.4
	local archetype = args.WeaponType and SkillVfxCatalog.WeaponArchetype[args.WeaponType]
	local profile = ArchetypeCombatSkills.GetSkillProfile(args.HeroId, archetype)
	local ticks, gap = HeroActionTiming.Ticks(profile.Skill)
	local waves = VfxMath.WaveTimes(ctx.ArriveAt, ticks, gap)
	local first, last = waves[1], waves[#waves]
	local shrinkAt, burstAt = last, last + 0.17
	local accent = palette.Accent or palette.Core

	-- The event sphere: grows in 0.15 s, swells 12% for 0.1 s on each tick, shrinks to a point.
	local function sphere(scale: number): (number) -> number
		return function(now: number): number
			local grow = VfxMath.Progress(first, first + 0.15, now)
			local shrink = 1 - VfxMath.Progress(shrinkAt, shrinkAt + 0.12, now)
			local breath = 0
			for _, wave in waves do
				local since = now - wave
				if since >= 0 and since < 0.1 then
					breath = math.max(breath, 0.12 * (1 - since / 0.1))
				end
			end
			return core * scale * grow * shrink * (1 + breath)
		end
	end
	local holeAt = fixed(hole)
	VfxPrimitives.Burst(pool, hole, palette.Core, core * 0.6, first, 0.1)
	VfxPrimitives.Orb(pool, { Center = holeAt, Diameter = sphere(1), Color = palette.Secondary, StartAt = first, EndAt = shrinkAt + 0.12 })
	VfxPrimitives.Orb(pool, { Center = holeAt, Diameter = sphere(1.25), Color = palette.Primary, Neon = true, Transparency = 0.6, StartAt = first, EndAt = shrinkAt + 0.12 })
	VfxPrimitives.Accretion(pool, { Center = hole, Radius = core * 1.15, Tilt = math.rad(18), Inner = palette.Primary, Outer = accent, StartAt = first, EndAt = shrinkAt + 0.12, Spin = 1.2, Pulses = waves })
	-- Space folds in: a ring runs from the edge to the core, and the floor darkens under it.
	VfxPrimitives.Ring(pool, { Center = center, From = radius, To = core, Color = palette.Primary, StartAt = first, EndAt = first + 0.3, Width = 0.9 })
	local ground = CFrame.new(center + Vector3.new(0, 0.15, 0)) * VfxPrimitives.FLAT
	VfxPrimitives.Disc(pool, { CFrame = ground, Radius = radius, Color = palette.Secondary, StartAt = first - 0.05, EndAt = burstAt + linger, Grow = 0.6, Transparency = 0.35 })
	VfxPrimitives.Ring(pool, { Center = center, From = radius * 0.97, To = radius, Color = palette.Primary, StartAt = first + 0.2, EndAt = burstAt, Width = 0.35 })
	local callback = args.Shake
	local magnitude = recipe.Shake
	if callback and magnitude then
		VfxPrimitives.At(pool, first, function()
			callback(magnitude * 0.6)
		end)
	end

	-- Each tick: debris drawn in from the rim, and a streak from every mob it hit to the hole.
	local lookup = args.RecentHits
	for k, wave in waves do
		VfxPrimitives.Converge(pool, holeAt, if k % 2 == 0 then accent else palette.Primary, radius * 0.75, 5, wave, wave + gap * 0.9, k * 1.7 + args.Cue.NetId % 5)
		if lookup then
			VfxPrimitives.At(pool, wave + HIT_LOOKUP_DELAY, function()
				for i, point in lookup("HIT", center, radius + 2, wave - 0.1) do
					if i > STREAKS_PER_WAVE then
						break
					end
					local now = wave + HIT_LOOKUP_DELAY
					VfxPrimitives.Beam(pool, point + UP, hole, palette.Primary, now, 0.22, i + k * 3)
					VfxPrimitives.Burst(pool, point + UP, palette.Core, 0.9, now, 0.12)
				end
			end)
		end
	end

	-- Collapse.
	VfxPrimitives.Burst(pool, hole, palette.Core, recipe.Impact or 5, burstAt, 0.3)
	VfxPrimitives.Ring(pool, { Center = center, From = 1, To = radius * 1.1, Color = palette.Core, StartAt = burstAt, EndAt = burstAt + 0.45, Width = 1.2 })
	VfxPrimitives.Motes(pool, hole, palette.Primary, burstAt, 10, 0.6)
	shake(ctx, burstAt)
end

local PLAYERS: { [string]: (Context) -> () } = {
	SHOT = playProjectile,
	BOLT = playProjectile,
	SLASH = playSlash,
	VOLLEY = playVolley,
	PIERCER = playPiercer,
	WHIRL = playWhirl,
	CLEAVE = playCleave,
	CROSS = playCross,
	PLUNGE = playPlunge,
	BEAM = playBeam,
	TREMOR = playTremor,
	CHAIN = playChain,
	RICOCHET = playRicochet,
	TWIN = playTwin,
	MEND = playMend,
	STORM = playStorm,
	CONSTELLATION = playConstellation,
	EXECUTE = playExecute,
	BULWARK = playBulwark,
	TEMPEST = playTempest,
	WAKE = playWake,
	CRYSTALS = playCrystals,
	PILLAR = playPillar,
	SANCTUARY = playSanctuary,
	SINGULARITY = playSingularity,
}
SkillVfx.Styles = table.freeze(table.clone(PLAYERS))

-- Charge (wind-up) ----------------------------------------------------------------------------
-- Played at an attack clip's Charge marker, before Release. Every charge effect ends at the
-- release time, so an interrupted cast leaves nothing behind. Cosmetic only.

type ChargeContext = {
	Pool: VfxPool.VfxPool,
	Args: PlayArgs,
	Recipe: Recipe,
	Palette: Palette,
	StartAt: number, -- now
	ReleaseAt: number, -- server release time
}

-- BOLT from the left hand: a glyph spins up in front of the palm, facing the target, while
-- motes are drawn into it; it pops as the bolt leaves.
local function chargeGlyph(ctx: ChargeContext): boolean
	local args, recipe, palette, pool = ctx.Args, ctx.Recipe, ctx.Palette, ctx.Pool
	if recipe.Origin ~= "LEFT_HAND" or not args.OriginOf or not args.OriginOf("LEFT_HAND") then
		return false
	end
	local function hand(): Vector3
		return originOf(args, recipe)
	end
	local function frame(): CFrame
		local at = hand()
		local target = args.Target()
		local delta = target - at
		return if delta.Magnitude > 1e-3 then CFrame.lookAt(at, target) else CFrame.new(at)
	end
	local scale = recipe.Scale or 1
	VfxPrimitives.Glyph(pool, frame, 0.45 * scale, palette, ctx.StartAt, ctx.ReleaseAt)
	VfxPrimitives.Converge(pool, hand, palette.Core, 1.5, 3, ctx.StartAt, ctx.ReleaseAt, args.Cue.NetId % 11)
	VfxPrimitives.Burst(pool, hand(), palette.Core, 0.6 * scale, ctx.ReleaseAt, 0.12)
	return true
end

-- BEAM off the staff tip: motes stream into the tip, a dark well grows there inside a bright
-- rim, and a gold glint flashes just before it fires (the tell).
local function chargeTip(ctx: ChargeContext): boolean
	local args, recipe, palette, pool = ctx.Args, ctx.Recipe, ctx.Palette, ctx.Pool
	local function tip(): Vector3
		return originOf(args, recipe)
	end
	local from, to = ctx.StartAt, ctx.ReleaseAt
	local function well(scale: number): (number) -> number
		return function(now: number): number
			return 0.6 * scale * VfxMath.Progress(from, to, now)
		end
	end
	VfxPrimitives.Converge(pool, tip, palette.Primary, 3, 8, from, to, args.Cue.NetId % 9)
	VfxPrimitives.Orb(pool, { Center = tip, Diameter = well(1), Color = palette.Secondary, StartAt = from, EndAt = to })
	VfxPrimitives.Orb(pool, { Center = tip, Diameter = well(1.35), Color = palette.Core, Neon = true, Transparency = 0.7, StartAt = from, EndAt = to })
	VfxPrimitives.Flare(pool, tip, 2.2, palette.Accent or palette.Core, math.max(from, to - 0.1), 0.16)
	return true
end

-- SINGULARITY: at the aim point, the edge of the area closes in, motes spiral to where the hole
-- will open and the floor dims; with Tether, a thin line flickers from the caster's left hand.
local function chargeWell(ctx: ChargeContext): boolean
	local args, recipe, palette, pool = ctx.Args, ctx.Recipe, ctx.Palette, ctx.Pool
	local center: Vector3 = args.Cue.Aim
	local hole = center + Vector3.new(0, 3, 0)
	local radius = recipe.Radius or 16
	local from, to = ctx.StartAt, ctx.ReleaseAt
	VfxPrimitives.Ring(pool, { Center = center, From = radius, To = 1, Color = palette.Primary, StartAt = from, EndAt = to, Width = 0.8 })
	VfxPrimitives.Converge(pool, fixed(hole), palette.Primary, radius * 0.6, 12, from, to, args.Cue.NetId % 7)
	VfxPrimitives.Disc(pool, { CFrame = CFrame.new(center + Vector3.new(0, 0.12, 0)) * VfxPrimitives.FLAT, Radius = radius * 0.8, Color = palette.Secondary, StartAt = from, EndAt = to + 0.05, Grow = 0.3, Transparency = 0.5 })
	local originFn = args.OriginOf
	if recipe.Tether and originFn then
		local hand = originFn("LEFT_HAND")
		if hand then
			local span = to - from
			for i = 0, 2 do
				VfxPrimitives.Beam(pool, hand, hole, palette.Primary, from + span * (0.2 + 0.27 * i), span * 0.3, i + 2)
			end
		end
	end
	return true
end

-- PIERCER on a drawn bow: starlight is pulled into the arrow. Motes stream to the nock, a core
-- of light swells there inside a trembling violet shell, a star glyph spins up in front of the
-- bow facing the target, the ground under the archer draws in, and a glint flashes on the
-- arrow just before it leaves (the tell).
local function chargeBolt(ctx: ChargeContext): boolean
	local args, recipe, palette, pool = ctx.Args, ctx.Recipe, ctx.Palette, ctx.Pool
	local function nock(): Vector3
		return originOf(args, recipe)
	end
	local from, to = ctx.StartAt, ctx.ReleaseAt
	local span = to - from
	local scale = recipe.Scale or 1
	local seed = args.Cue.NetId % 11
	local function swell(size: number, tremble: number): (number) -> number
		return function(now: number): number
			local grown = VfxMath.Progress(from, to, now)
			return size * scale * grown * (1 + tremble * grown * math.sin(now * 46))
		end
	end
	VfxPrimitives.Converge(pool, nock, palette.Primary, 3.4, 8, from, to, seed)
	VfxPrimitives.Converge(pool, nock, palette.Secondary, 2.2, 4, from + span * 0.3, to, seed + 3)
	VfxPrimitives.Orb(pool, { Center = nock, Diameter = swell(0.55, 0), Color = palette.Core, Neon = true, StartAt = from, EndAt = to })
	VfxPrimitives.Orb(pool, { Center = nock, Diameter = swell(1.2, 0.14), Color = palette.Primary, Neon = true, Transparency = 0.6, StartAt = from, EndAt = to })
	VfxPrimitives.Glyph(pool, function(): CFrame
		local at = nock()
		local delta = args.Target() - at
		if delta.Magnitude < 1e-3 then
			return CFrame.new(at)
		end
		return CFrame.lookAt(at + delta.Unit * 1.4, at + delta.Unit * 2.4)
	end, 1.15 * scale, palette, from, to)
	if args.Self then
		VfxPrimitives.Ring(pool, { Center = args.Self(), From = 5, To = 0.8, Color = palette.Primary, StartAt = from, EndAt = to, Width = 0.45 })
	end
	VfxPrimitives.Flare(pool, nock, 2.8 * scale, palette.Secondary, math.max(from, to - 0.1), 0.18)
	return true
end

-- CONSTELLATION during the spin: two crescents of starlight sweep round the archer, one behind
-- the other, a ring rolls out from her feet, and motes gather on the bow for the shot.
local function chargeStars(ctx: ChargeContext): boolean
	local args, recipe, palette, pool = ctx.Args, ctx.Recipe, ctx.Palette, ctx.Pool
	local from, to = ctx.StartAt, ctx.ReleaseAt
	local span = to - from
	local feet = if args.Self then args.Self() else args.Origin - Vector3.new(0, 2, 0)
	local yaw = VfxPrimitives.Yaw(args.Cue.Aim - feet)
	local waist = CFrame.new(feet + Vector3.new(0, 2.3, 0)) * CFrame.Angles(0, yaw, 0)
	local sweep = math.min(0.34, span * 0.55)
	VfxPrimitives.SlashArc(pool, waist * CFrame.Angles(0, math.pi / 2, math.rad(8)), 3.4, palette.Primary, from, sweep)
	VfxPrimitives.SlashArc(pool, waist * CFrame.Angles(0, -math.pi / 2, math.rad(-8)), 3.8, palette.Secondary, from + sweep * 0.4, sweep)
	VfxPrimitives.SlashArc(pool, waist * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, math.pi / 2, math.rad(-6)), 3, palette.Core, from + sweep * 0.8, sweep * 0.8)
	VfxPrimitives.Ring(pool, { Center = feet, From = 1, To = 6, Color = palette.Primary, StartAt = from, EndAt = from + sweep * 1.4, Width = 0.5 })
	VfxPrimitives.Motes(pool, feet + Vector3.new(0, 1, 0), palette.Secondary, from + sweep * 0.5, 6, 0.6)
	VfxPrimitives.Converge(pool, function(): Vector3
		return originOf(args, recipe)
	end, palette.Secondary, 3, 8, from + span * 0.45, to, args.Cue.NetId % 13)
	return true
end

-- WHIRL while he coils: the ground draws in round his feet and dust lifts.
local function chargeWhirl(ctx: ChargeContext): boolean
	local args, recipe, palette, pool = ctx.Args, ctx.Recipe, ctx.Palette, ctx.Pool
	local feet = if args.Self then args.Self() else args.Origin - Vector3.new(0, 2, 0)
	VfxPrimitives.Ring(pool, { Center = feet, From = (recipe.Radius or 9) * 0.6, To = 1.2, Color = palette.Primary, StartAt = ctx.StartAt, EndAt = ctx.ReleaseAt, Width = 0.5 })
	VfxPrimitives.Motes(pool, feet + Vector3.new(0, 0.6, 0), palette.Secondary, ctx.StartAt, 4, math.max(0.2, ctx.ReleaseAt - ctx.StartAt))
	return true
end

-- EXECUTE through the crouch and the leap: dust kicks out from under him as he leaves the
-- ground, and the target is marked: a ring closes on it and a thin line of light stands over
-- it, with a glint at the top just before the blow (the tell).
local function chargeExecute(ctx: ChargeContext): boolean
	local args, recipe, palette, pool = ctx.Args, ctx.Recipe, ctx.Palette, ctx.Pool
	local from, to = ctx.StartAt, ctx.ReleaseAt
	local span = to - from
	local feet = if args.Self then args.Self() else args.Origin - Vector3.new(0, 2, 0)
	local radius = recipe.Radius or 4
	local height = recipe.PillarHeight or 16
	local accent = palette.Accent or palette.Core
	local leapAt = from + span * 0.3
	VfxPrimitives.Ring(pool, { Center = feet, From = 3.5, To = 0.8, Color = palette.Secondary, StartAt = from, EndAt = leapAt, Width = 0.5 })
	VfxPrimitives.Ring(pool, { Center = feet, From = 0.8, To = 5, Color = palette.Primary, StartAt = leapAt, EndAt = leapAt + 0.35, Width = 0.7 })
	VfxPrimitives.Motes(pool, feet + Vector3.new(0, 0.6, 0), palette.Secondary, leapAt, 6, 0.6)
	local function mark(): Vector3
		local body = args.Target()
		return Vector3.new(body.X, args.Cue.Aim.Y, body.Z)
	end
	local marked = mark()
	VfxPrimitives.Ring(pool, { Center = marked, From = radius * 1.6, To = 0.8, Color = palette.Primary, StartAt = from, EndAt = to, Width = 0.45 })
	VfxPrimitives.Disc(pool, { CFrame = CFrame.new(marked + Vector3.new(0, 0.12, 0)) * VfxPrimitives.FLAT, Radius = radius, Color = palette.Secondary, StartAt = from, EndAt = to + 0.05, Grow = 0.4, Transparency = 0.55 })
	VfxPrimitives.Pillar(pool, marked, 0.12, height, accent, leapAt, to, 0.05)
	VfxPrimitives.Flare(pool, function(): Vector3
		return mark() + Vector3.new(0, height, 0)
	end, 5, accent, math.max(from, to - 0.14), 0.2)
	return true
end

local CHARGERS: { [string]: (ChargeContext) -> boolean } = {
	WHIRL = chargeWhirl,
	EXECUTE = chargeExecute,
	BOLT = chargeGlyph,
	PIERCER = chargeBolt,
	CONSTELLATION = chargeStars,
	BEAM = chargeTip,
	TWIN = chargeTip, -- the held, glowing draw
	SINGULARITY = chargeWell,
}
SkillVfx.Chargers = table.freeze(table.clone(CHARGERS))

-- Plays the wind-up for the cue's attack, if its style has one. Returns false when there is
-- nothing to play or release has already passed.
function SkillVfx.PlayCharge(pool: VfxPool.VfxPool, args: PlayArgs): boolean
	local cue = args.Cue
	local tier = TIERS[cue.Tier]
	local recipe, palette = SkillVfxCatalog.Get(args.HeroId, args.WeaponType, tier or "")
	if not tier or not recipe or not palette then
		return false
	end
	local charger = CHARGERS[recipe.Style]
	local releaseAt = VfxMath.FlightWindow(cue)
	if not charger or args.Now >= releaseAt or not pool:Visible(args.Origin) then
		return false
	end
	return charger({
		Pool = pool,
		Args = args,
		Recipe = recipe,
		Palette = palette,
		StartAt = args.Now,
		ReleaseAt = releaseAt,
	})
end

-- Plays the cue's attack. Returns false when this hero has no recipe, the hit already landed,
-- or the whole effect is too far from the camera.
function SkillVfx.Play(pool: VfxPool.VfxPool, args: PlayArgs): boolean
	local cue = args.Cue
	local tier = TIERS[cue.Tier]
	local recipe, palette = SkillVfxCatalog.Get(args.HeroId, args.WeaponType, tier or "")
	if not tier or not recipe or not palette then
		return false
	end
	local player = PLAYERS[recipe.Style]
	if not player or (recipe.Projectile and not ProjectileVfx.Has(recipe.Projectile)) then
		return false
	end
	local releaseAt, arriveAt = VfxMath.FlightWindow(cue)
	if args.Now > arriveAt + LATE_GRACE or not pool:Visible(args.Origin, cue.Aim) then
		return false
	end
	player({
		Pool = pool,
		Args = args,
		Recipe = recipe,
		Palette = palette,
		StartAt = math.max(releaseAt, args.Now),
		ArriveAt = arriveAt,
	})
	return true
end

return table.freeze(SkillVfx)
