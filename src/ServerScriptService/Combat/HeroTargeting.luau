--!strict
-- ServerScriptService/Combat/HeroTargeting.luau
-- PvE target choice for squad heroes (GDD 4.5, Hero Auto-Targeting). Pure: CombatSimulation passes the
-- Master's ground position and an `eligible` check (alive, same room, outside safe zones), and
-- calls this every 5 Hz tick for every hero that is not pacified or downed.

local HeroTargeting = {}

-- Free-following squads fight around the Master: mobs within 28 studs of the Master are acquired,
-- a fight is dropped once its mob is 30 studs from the Master or the hero 35 studs from the Master.
-- A mob inside the hero's own attack range always counts, so a respawn next to the squad is hit.
HeroTargeting.MASTER_ACQUIRE_RADIUS = 28.0
HeroTargeting.MASTER_DROP_RADIUS = 30.0
HeroTargeting.HERO_TETHER = 35.0
HeroTargeting.MAX_HERO_HEIGHT_GAP = 30.0
HeroTargeting.MAX_MASTER_HEIGHT_GAP = 35.0

export type Context = {
	MasterPos: Vector3,
	Assigned: boolean, -- squad assigned to a floor: heroes roam up to Leash studs from the anchor
	Leash: number,
}

local function flat(a: Vector3, b: Vector3): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- Whether a hero may keep fighting `mob` (or start to).
function HeroTargeting.CanEngage(hero: any, mob: any, ctx: Context): boolean
	if ctx.Assigned then
		return flat(ctx.MasterPos, mob.Position) <= ctx.Leash
	end
	if flat(hero.Position, ctx.MasterPos) > HeroTargeting.HERO_TETHER then
		return false
	end
	return flat(ctx.MasterPos, mob.Position) <= HeroTargeting.MASTER_DROP_RADIUS
		or flat(hero.Position, mob.Position) <= hero.AttackRange
end

-- The nearest mob the hero should pick up now, or nil. Ties go to the lower NetId.
function HeroTargeting.Acquire(hero: any, mobs: { [number]: any }, ctx: Context, eligible: (hero: any, mob: any) -> boolean): number?
	if not ctx.Assigned and flat(hero.Position, ctx.MasterPos) > HeroTargeting.HERO_TETHER then
		return nil
	end
	local bestId: number?, bestDist = nil, math.huge
	for netId, mob in pairs(mobs) do
		if not eligible(hero, mob) or math.abs(mob.Position.Y - hero.Position.Y) >= HeroTargeting.MAX_HERO_HEIGHT_GAP then
			continue
		end
		local heroDist = flat(hero.Position, mob.Position)
		local dist: number
		if ctx.Assigned then
			if math.abs(mob.Position.Y - ctx.MasterPos.Y) >= HeroTargeting.MAX_MASTER_HEIGHT_GAP or heroDist > ctx.Leash then continue end
			dist = heroDist
		else
			local masterDist = flat(ctx.MasterPos, mob.Position)
			if masterDist > HeroTargeting.MASTER_ACQUIRE_RADIUS and heroDist > hero.AttackRange then continue end
			dist = math.min(masterDist, heroDist)
		end
		if dist < bestDist or (dist == bestDist and bestId ~= nil and netId < bestId) then
			bestId, bestDist = netId, dist
		end
	end
	return bestId
end

-- Keeps TargetNetId and State consistent at the end of target selection. A hero holding a live
-- target never stays in FOLLOW_MASTER, and a hero without one never keeps a cached NetId: camp
-- mobs keep their NetId across respawns, so a stale id would otherwise come back "alive".
function HeroTargeting.Settle(hero: any, hasTarget: boolean)
	if hasTarget then
		if hero.State == "FOLLOW_MASTER" then hero.State = "MOVE_TO_TARGET" end
	else
		hero.TargetNetId = nil
		if hero.State ~= "COMA" then hero.State = "FOLLOW_MASTER" end
	end
end

-- One tick of target choice for a hero, applied to hero.TargetNetId/State. Returns the mob to fight.
-- Order: keep the held target while it is eligible and engageable; otherwise (unless pacified)
-- join a squadmate's target from `assist`, then pick the nearest mob in range. Runs every tick, so
-- an idle hero picks up a mob that respawns or walks into range on the next tick.
function HeroTargeting.Select(hero: any, mobs: { [number]: any }, ctx: Context, eligible: (hero: any, mob: any) -> boolean, pacified: boolean, assist: { number }?): any?
	local function usable(netId: number?): any?
		local mob = if netId then mobs[netId] else nil
		if mob and eligible(hero, mob) and HeroTargeting.CanEngage(hero, mob, ctx) then return mob end
		return nil
	end
	local target = if pacified then nil else usable(hero.TargetNetId)
	if not target and not pacified then
		for _, netId in assist or {} do
			target = usable(netId)
			if target then hero.TargetNetId = netId; break end
		end
		if not target then
			local netId = HeroTargeting.Acquire(hero, mobs, ctx, eligible)
			target = usable(netId)
			if target then hero.TargetNetId = netId end
		end
	end
	HeroTargeting.Settle(hero, target ~= nil)
	return target
end

return table.freeze(HeroTargeting)
