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
	Target: () -> Vector3, -- live target body centre, or the cue's aim when the target is gone
	-- Ground-level positions (the server's entity positions are at the feet, like Cue.Aim):
	Self: (() -> Vector3)?, -- the attacker's feet
	Allies: (() -> { Vector3 })?, -- the attacker's squad (healing effects)
	-- Positions the server reported hits ("HIT") or heals ("HEAL") at, near `center`, since `since`.
	RecentHits: ((kind: string, center: Vector3, radius: number, since: number) -> { Vector3 })?,
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

-- Basic -------------------------------------------------------------------------------------

-- SHOT / BOLT: one projectile to the target, bursting on arrival.
local function playProjectile(ctx: Context)
	local args, recipe, palette = ctx.Args, ctx.Recipe, ctx.Palette
	fly(ctx.Pool, projectile(recipe, palette), args.Origin, args.Target, ctx.StartAt, ctx.ArriveAt, VfxMath.ArcLift(args.Origin, args.Cue.Aim, recipe.Arc), function(at: Vector3)
		VfxPrimitives.Burst(ctx.Pool, at, palette.Core, recipe.Impact or 1.6, ctx.ArriveAt)
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

local PLAYERS: { [string]: (Context) -> () } = {
	SHOT = playProjectile,
	BOLT = playProjectile,
	SLASH = playSlash,
	VOLLEY = playVolley,
	CLEAVE = playCleave,
	CROSS = playCross,
	TREMOR = playTremor,
	CHAIN = playChain,
	MEND = playMend,
	STORM = playStorm,
	BULWARK = playBulwark,
	TEMPEST = playTempest,
	CRYSTALS = playCrystals,
	PILLAR = playPillar,
	SANCTUARY = playSanctuary,
}
SkillVfx.Styles = table.freeze(table.clone(PLAYERS))

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
