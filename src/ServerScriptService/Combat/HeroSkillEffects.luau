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
	-- Tower mobs: damage left after shields, and support cast interrupts (TowerEncounterRuntime:OnMobHit).
	Absorb: ((mob: any, amount: number) -> number)?,
	Taunt: ((mob: any, attacker: any, duration: number) -> ())?,
	-- Moves a mob towards `destination` along walkable ground, stopping at walls and ledges
	-- (HeroNavigation.Displace). Without it, pull effects deal their damage but move nobody
	-- (duels: heroes are never displaced).
	Pull: ((mob: any, destination: Vector3) -> ())?,
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
	if ctx.Absorb then
		amount = ctx.Absorb(mob, amount) -- tower shields soak first; a hit can interrupt a support's cast
	end
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

-- Bosses, raid bosses and floor Alphas hold their ground against pulls (vane-hero-plan.md §3).
local function pullable(mob: any): boolean
	if mob.Role == "BOSS" or mob.RaidBoss or mob.Dormant then
		return false
	end
	local enemyId = mob.EnemyId or mob.SpecId
	return not (type(enemyId) == "string" and string.sub(enemyId, 1, 6) == "alpha_")
end

-- EXECUTE (Rhyman's Headsman's Verdict): true when a skill kills `mob` outright. Raid bosses and
-- Biome Bosses are immune and take the skill's ordinary damage; floor Alphas share the BOSS role
-- but are executed like any other mob. Hero targets (duels) never reach this: only mobs do.
function HeroSkillEffects.Executes(skill: any, mob: any): boolean
	if not skill or skill.Effect ~= "EXECUTE" or not mob then
		return false
	end
	if mob.RaidBoss or mob.Dormant then
		return false
	end
	if mob.Role == "BOSS" then
		local enemyId = mob.EnemyId or mob.SpecId
		return type(enemyId) == "string" and string.sub(enemyId, 1, 6) == "alpha_"
	end
	return true
end

-- Where a pull of `studs` moves a mob at `from` towards `center`: straight in, never closer than
-- `core` studs (so a pack bunches around the centre instead of stacking on one point).
function HeroSkillEffects.PullDestination(from: Vector3, center: Vector3, studs: number, core: number): Vector3?
	local flat = Vector3.new(center.X - from.X, 0, center.Z - from.Z)
	local distance = flat.Magnitude
	local travel = math.min(studs, distance - core)
	if travel <= 0.05 then
		return nil
	end
	return from + flat.Unit * travel
end

-- Distance along and across the flat line from `origin` heading `direction` (a unit vector).
function HeroSkillEffects.LineOffset(origin: Vector3, direction: Vector3, point: Vector3): (number, number)
	local dx, dz = point.X - origin.X, point.Z - origin.Z
	local along = dx * direction.X + dz * direction.Z
	local across = math.abs(dx * direction.Z - dz * direction.X)
	return along, across
end

-- BEAM_LINE: a straight beam from the attacker through the target, `length` studs long and
-- `width` wide, that hits every other eligible mob on it.
local function beamLine(ctx: Context, hit: Hit, length: number, width: number, amount: number)
	local origin = hit.Attacker.Position
	local flat = Vector3.new(hit.Center.X - origin.X, 0, hit.Center.Z - origin.Z)
	if flat.Magnitude < 1e-3 then
		return
	end
	local direction = flat.Unit
	for _, mob in ctx.Mobs do
		if mob ~= hit.Primary and eligible(ctx, hit, mob) and math.abs(origin.Y - mob.Position.Y) <= Y_TOLERANCE then
			local along, across = HeroSkillEffects.LineOffset(origin, direction, mob.Position)
			if along >= 0 and along <= length and across <= width / 2 then
				damageMob(ctx, hit, mob, amount)
			end
		end
	end
end

-- SINGULARITY: one tick of a black hole at the centre. Every other eligible mob in the radius
-- takes its share of the splash, then every survivor in it (the primary too) is pulled inward.
local function singularity(ctx: Context, hit: Hit, skill: any, amount: number)
	local radius = skill.Radius or 16
	local studs = skill.PullStudsPerTick or 0
	local core = skill.CoreRadius or 3
	for _, mob in ctx.Mobs do
		if eligible(ctx, hit, mob) and near(mob, hit.Center, radius) then
			if mob ~= hit.Primary then
				damageMob(ctx, hit, mob, amount)
			end
			if ctx.Pull and studs > 0 and mob.IsAlive ~= false and (mob.CurrentHP or 1) > 0 and pullable(mob) then
				local destination = HeroSkillEffects.PullDestination(mob.Position, hit.Center, studs, core)
				if destination then
					ctx.Pull(mob, Vector3.new(destination.X, mob.Position.Y, destination.Z))
				end
			end
		end
	end
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

	-- Hero kits can name their own effect; everything else uses its archetype's.
	if skill.Effect == "SINGULARITY" then
		singularity(ctx, hit, skill, math.round(atk * mult * 0.6 * scale))
		return
	elseif skill.Effect == "EXECUTE" then
		return -- one target, no splash: the caller lands the blow (HeroSkillEffects.Executes)
	end

	if archetype == "Vanguard" then
		if not first then
			return
		end
		local barrier = math.round(attacker.MaxHP * (skill.BarrierPercent or 0.40))
		attacker.BarrierHP = barrier
		attacker.BarrierExpires = ctx.Now + (skill.Duration or 6.0)
		local tauntRadius = skill.Radius or 25.0
		local tauntDuration = skill.TauntDuration or 4.0
		for _, mob in ctx.Mobs do
			if eligible(ctx, hit, mob) and horizontal(attacker.Position, mob.Position) <= tauntRadius then
				mob.TargetNetId = attacker.NetId
				mob.TauntedByNetId = attacker.NetId
				mob.TauntExpires = ctx.Now + tauntDuration
				if ctx.Taunt then
					ctx.Taunt(mob, attacker, tauntDuration)
				end
			end
		end
		ctx.Broadcast(attacker, "BARRIER_APPLIED", attacker.Position, barrier, false, false)
	elseif archetype == "Healer" then
		if not first or not ctx.Squad then
			return
		end
		local healPct = skill.HealPercent or 0.35
		if skill.TargetLowestAlly then
			local lowest: any = nil
			local lowestPct = math.huge
			for _, ally in ctx.Squad do
				if ally.State ~= "COMA" and ally.CurrentHP > 0 then
					local pct = ally.CurrentHP / math.max(1, ally.MaxHP)
					if pct < lowestPct or (pct == lowestPct and lowest and ally.CurrentHP < lowest.CurrentHP) then
						lowestPct = pct
						lowest = ally
					end
				end
			end
			if lowest then
				local buffPct = skill.MaxHpBuffPercent or 0
				if buffPct > 0 then
					local baseMax = lowest.BaseMaxHP or lowest.MaxHP
					lowest.BaseMaxHP = baseMax
					local oldMax = lowest.MaxHP
					local newMax = math.round(baseMax * (1 + buffPct))
					lowest.MaxHP = newMax
					lowest.MaxHPBuffMult = 1 + buffPct
					lowest.MaxHPBuffExpires = ctx.Now + (skill.Duration or 8.0)
					if newMax > oldMax then
						lowest.CurrentHP = math.min(newMax, lowest.CurrentHP + (newMax - oldMax))
					end
				end
				healAlly(ctx, lowest, math.round(lowest.MaxHP * healPct), "HEAL_BURST")
			end
		else
			for _, ally in ctx.Squad do
				if ally.State ~= "COMA" and ally.CurrentHP > 0 then
					healAlly(ctx, ally, math.round(ally.MaxHP * healPct), "HEAL_BURST")
				end
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
	elseif archetype == "Berserker" then
		splash(ctx, hit, skill.Radius or 18.0, math.round(atk * mult * 0.5 * scale))
	end
end

-- Returns an extra multiplier for the primary hit (Striker's bonus crit).
local function resolveSpecial(ctx: Context, hit: Hit): number
	local attacker = hit.Attacker
	local special = hit.Profile.Special
	local archetype = attacker.Archetype
	local atk = hit.Impact.Atk

	if special.SecondaryEffect == "BEAM_LINE" then
		beamLine(ctx, hit, special.SecondaryParam or 36, special.BeamWidth or 4, math.round(atk * (special.BeamDamage or 0.8)))
		return 1
	elseif special.SecondaryEffect == "WHIRLWIND" then
		-- A spin: every other mob around the attacker, on every tick of the turn.
		local perTick = atk * (special.SpinDamage or 0.9) / math.max(1, hit.Impact.Ticks or 1)
		nearbyOthers(ctx, hit, attacker.Position, special.SecondaryParam or 9, math.huge, math.round(perTick))
		return 1
	end

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
	elseif archetype == "Berserker" then
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
