--!strict
-- ServerScriptService/Combat/HeroSkillEffects.luau
-- Secondary effects of a hero's Special and Skill (GDD 4.4, kit defaults), resolved when the
-- attack lands (docs/projectile-skill-vfx-plan.md, section 3). The primary hit stays in
-- CombatSimulation; this module only touches the entities handed to it through the context.
--
-- Multi-tick attacks (Ticks > 1) split splash damage evenly across the ticks. One-shot effects
-- (barrier, taunt, heals, defense shred) apply on the first tick only.

local HeroSkillEffects = {}

export type Context = {
	Mobs: { [number]: any },
	Squad: { [string]: any }?, -- the attacker's deployed heroes
	Now: number,
	Same: (any, any) -> boolean,
	IsCombatSafe: (any) -> boolean,
	Broadcast: (context: any, kind: string, position: Vector3, amount: number, overdrive: boolean, incoming: boolean) -> (),
	HandleMobDeath: (mob: any, owner: Player) -> (),
	-- Duels pass the opposing squad as Mobs and route hits through these instead.
	Eligible: ((target: any) -> boolean)?,
	Damage: ((target: any, amount: number) -> ())?,
}

-- What the caller knows about the attack. Impact (from HeroImpactQueue) carries FloorId and
-- RoomGeneration, so it doubles as the room context for Same and Broadcast.
export type Hit = {
	Impact: any,
	Attacker: any, -- SimHero
	Profile: any, -- ArchetypeSkillProfile
	Tier: "BASIC" | "SPECIAL" | "SKILL",
	Tick: number,
	Primary: any?, -- the mob targeted at decision time
	Center: Vector3, -- where area effects are centred
}

local Y_TOLERANCE = 15

local function horizontal(a: Vector3, b: Vector3): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function eligible(ctx: Context, hit: Hit, mob: any): boolean
	if ctx.Eligible then
		return ctx.Eligible(mob) and ctx.Same(hit.Impact, mob)
	end
	return mob.IsAlive and ctx.Same(hit.Impact, mob) and not ctx.IsCombatSafe(mob)
end

local function near(mob: any, center: Vector3, radius: number): boolean
	return math.abs(center.Y - mob.Position.Y) <= Y_TOLERANCE and horizontal(center, mob.Position) <= radius
end

local function damageMob(ctx: Context, hit: Hit, mob: any, amount: number)
	if ctx.Damage then
		ctx.Damage(mob, amount)
		return
	end
	local owner = hit.Attacker.Owner
	mob.CurrentHP = math.max(0, mob.CurrentHP - amount)
	mob.DamageLedger[owner.UserId] = (mob.DamageLedger[owner.UserId] or 0) + amount
	ctx.Broadcast(mob, "HIT_SPARK", mob.Position, amount, false, false)
	if mob.CurrentHP <= 0 then
		ctx.HandleMobDeath(mob, owner)
	end
end

local function healAlly(ctx: Context, ally: any, amount: number, kind: string)
	ally.CurrentHP = math.min(ally.MaxHP, ally.CurrentHP + amount)
	ctx.Broadcast(ally, kind, ally.Position, amount, false, false)
end

-- Splash to every other eligible mob around the centre.
local function splash(ctx: Context, hit: Hit, radius: number, amount: number)
	for _, mob in ctx.Mobs do
		if mob ~= hit.Primary and eligible(ctx, hit, mob) and near(mob, hit.Center, radius) then
			damageMob(ctx, hit, mob, amount)
		end
	end
end

-- Up to `limit` other eligible mobs around a point.
local function nearbyOthers(ctx: Context, hit: Hit, center: Vector3, radius: number, limit: number, amount: number)
	local count = 0
	for _, mob in ctx.Mobs do
		if mob ~= hit.Primary and eligible(ctx, hit, mob) and near(mob, center, radius) then
			damageMob(ctx, hit, mob, amount)
			count += 1
			if count >= limit then
				break
			end
		end
	end
end

local function resolveSkill(ctx: Context, hit: Hit, scale: number)
	local attacker = hit.Attacker
	local skill = hit.Profile.Skill
	local archetype = attacker.Archetype
	local atk = hit.Impact.Atk
	local mult = hit.Impact.DamageMult
	local first = hit.Tick == 1

	if archetype == "Vanguard" then
		if not first then
			return
		end
		local barrier = math.round(attacker.MaxHP * (skill.BarrierPercent or 0.40))
		attacker.BarrierHP = barrier
		attacker.BarrierExpires = ctx.Now + (skill.Duration or 6.0)
		local tauntRadius = skill.Radius or 25.0
		for _, mob in ctx.Mobs do
			if eligible(ctx, hit, mob) and horizontal(attacker.Position, mob.Position) <= tauntRadius then
				mob.TargetNetId = attacker.NetId
			end
		end
		ctx.Broadcast(attacker, "BARRIER_APPLIED", attacker.Position, barrier, false, false)
	elseif archetype == "Healer" then
		if not first or not ctx.Squad then
			return
		end
		local healPct = skill.HealPercent or 0.35
		for _, ally in ctx.Squad do
			if ally.State ~= "COMA" and ally.CurrentHP > 0 then
				healAlly(ctx, ally, math.round(ally.MaxHP * healPct), "HEAL_BURST")
			end
		end
	elseif archetype == "Marksman" then
		local radius = skill.Radius or 16.0
		local amount = math.round(atk * mult * 0.5 * scale)
		for _, mob in ctx.Mobs do
			if eligible(ctx, hit, mob) and near(mob, hit.Center, radius) then
				if first then
					mob.DefenseShredUntil = ctx.Now + (skill.Duration or 5.0)
				end
				if mob ~= hit.Primary then
					damageMob(ctx, hit, mob, amount)
				end
			end
		end
	elseif archetype == "Striker" then
		splash(ctx, hit, skill.Radius or 12.0, math.round(atk * mult * 0.5 * scale))
	elseif archetype == "Scholar" then
		splash(ctx, hit, skill.Radius or 20.0, math.round(atk * mult * 0.6 * scale))
	elseif archetype == "Miner" then
		splash(ctx, hit, skill.Radius or 18.0, math.round(atk * mult * 0.5 * scale))
	end
end

-- Returns an extra multiplier for the primary hit (Striker's bonus crit).
local function resolveSpecial(ctx: Context, hit: Hit): number
	local attacker = hit.Attacker
	local special = hit.Profile.Special
	local archetype = attacker.Archetype
	local atk = hit.Impact.Atk

	if archetype == "Healer" then
		if not ctx.Squad then
			return 1
		end
		local lowest: any = nil
		local lowestPct = 1.0
		for _, ally in ctx.Squad do
			if ally.State ~= "COMA" and ally.CurrentHP > 0 and ally.CurrentHP < ally.MaxHP then
				local pct = ally.CurrentHP / ally.MaxHP
				if pct < lowestPct then
					lowestPct = pct
					lowest = ally
				end
			end
		end
		if lowest then
			healAlly(ctx, lowest, math.round(lowest.MaxHP * special.SecondaryParam), "HEAL_SPARK")
		end
	elseif archetype == "Striker" then
		if math.random() < (special.SecondaryParam or 0.25) then
			return 1.50
		end
	elseif archetype == "Vanguard" then
		-- Front cleave around the Vanguard: up to 2 other mobs within 10 studs.
		nearbyOthers(ctx, hit, attacker.Position, 10, 2, math.round(atk * 0.50))
	elseif archetype == "Scholar" then
		-- Chain lightning: up to 2 other mobs within 14 studs of the target.
		nearbyOthers(ctx, hit, hit.Center, 14, 2, math.round(atk * 0.70))
	elseif archetype == "Miner" then
		-- Seismic slam: every other mob within 8 studs of the target.
		nearbyOthers(ctx, hit, hit.Center, 8, math.huge, math.round(atk * 0.50))
	elseif archetype == "Marksman" then
		-- Piercing volley: one more mob within the 32-stud line from the archer.
		nearbyOthers(ctx, hit, hit.Impact.Origin, special.SecondaryParam or 32, 1, math.round(atk * 0.75))
	end
	return 1
end

-- Applies the tier's secondary effects for one tick. Returns the extra primary-hit multiplier.
function HeroSkillEffects.Resolve(ctx: Context, hit: Hit): number
	if hit.Tier == "SKILL" then
		resolveSkill(ctx, hit, 1 / math.max(1, hit.Impact.Ticks or 1))
	elseif hit.Tier == "SPECIAL" then
		return resolveSpecial(ctx, hit)
	end
	return 1
end

return table.freeze(HeroSkillEffects)
