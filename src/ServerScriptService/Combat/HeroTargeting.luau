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
HeroTargeting.HYSTERESIS_MARGIN = 12.0
HeroTargeting.TIE_BREAKER_MARGIN = 4.0
HeroTargeting.VERTICAL_PENALTY = 2.5

export type Context = {
	MasterPos: Vector3,
	Assigned: boolean, -- squad assigned to a floor: heroes roam up to Leash studs from the anchor
	Leash: number,
	Now: number?,
	RouteCost: ((from: Vector3, to: Vector3) -> number)?,
	FocusedTargetNetId: number?,
	SquadAnchorPos: Vector3?,
	TieBreakerMargin: number?,
	IsFocusOverride: boolean?,
}

local function rejected(hero: any, netId: number, mob: any, ctx: Context): boolean
	local entry = hero.NavigationRejectedTargets and hero.NavigationRejectedTargets[netId]
	if not entry or not ctx.Now then return false end
	return ctx.Now < entry.Until and entry.Generation == (mob.EntityGeneration or 0)
		and entry.FloorId == mob.FloorId and entry.RoomGeneration == mob.RoomGeneration
end

local function flat(a: Vector3, b: Vector3): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

function HeroTargeting.WeightedDistance(from: Vector3, to: Vector3): number
	local dx, dz = to.X - from.X, to.Z - from.Z
	local dy = to.Y - from.Y
	return math.sqrt(dx * dx + dz * dz) + math.abs(dy) * HeroTargeting.VERTICAL_PENALTY
end

local function entityOrder(mob: any, netId: number): number
	if mob then
		local id = mob.EntityId or mob.SpawnOrder or mob.EnemyId
		if id and type(id) == "number" then
			return id
		end
	end
	return netId
end

local function measureDistance(hero: any, mob: any, ctx: Context): number
	if ctx.Assigned then
		return if ctx.RouteCost then ctx.RouteCost(hero.Position, mob.Position) else HeroTargeting.WeightedDistance(hero.Position, mob.Position)
	end
	local anchor = ctx.SquadAnchorPos or ctx.MasterPos
	local anchorDist = HeroTargeting.WeightedDistance(anchor, mob.Position)
	local heroWeighted = HeroTargeting.WeightedDistance(hero.Position, mob.Position)
	return if ctx.SquadAnchorPos then anchorDist else math.min(anchorDist, heroWeighted)
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

-- The nearest mob the hero should pick up now, or nil. Ties go to lowest EntityId/SpawnOrder/NetId.
-- Optional maxDistanceThreshold supports Target Lock Hysteresis (anti-thrashing).
function HeroTargeting.Acquire(
	hero: any,
	mobs: { [number]: any },
	ctx: Context,
	eligible: (hero: any, mob: any) -> boolean,
	maxDistanceThreshold: number?,
	allowedSet: { [number]: boolean }?
): number?
	if not ctx.Assigned and flat(hero.Position, ctx.MasterPos) > HeroTargeting.HERO_TETHER then
		return nil
	end
	local bestId: number?, bestDist = nil, (maxDistanceThreshold or math.huge)
	local tieMargin = ctx.TieBreakerMargin or 0.1
	local maxHeroHeight = if ctx.Assigned then HeroTargeting.MAX_MASTER_HEIGHT_GAP else HeroTargeting.MAX_HERO_HEIGHT_GAP

	for netId, mob in pairs(mobs) do
		if allowedSet and not allowedSet[netId] then
			continue
		end
		if rejected(hero, netId, mob, ctx) or not eligible(hero, mob) or math.abs(mob.Position.Y - hero.Position.Y) >= maxHeroHeight then
			continue
		end
		local heroDist = flat(hero.Position, mob.Position)
		if ctx.Assigned then
			if math.abs(mob.Position.Y - ctx.MasterPos.Y) >= HeroTargeting.MAX_MASTER_HEIGHT_GAP or heroDist > ctx.Leash then continue end
		else
			local masterDist = flat(ctx.MasterPos, mob.Position)
			if masterDist > HeroTargeting.MASTER_ACQUIRE_RADIUS and heroDist > hero.AttackRange then continue end
		end
		local dist = measureDistance(hero, mob, ctx)

		if not bestId then
			if dist <= bestDist then
				bestId, bestDist = netId, dist
			end
		else
			local diff = dist - bestDist
			if diff < -tieMargin then
				bestId, bestDist = netId, dist
			elseif math.abs(diff) <= tieMargin then
				local orderNew = entityOrder(mob, netId)
				local bestMob = mobs[bestId]
				local orderBest = entityOrder(bestMob, bestId)
				if orderNew < orderBest or (orderNew == orderBest and dist < bestDist) then
					bestId, bestDist = netId, dist
				end
			end
		end
	end
	return bestId
end

-- Keeps TargetNetId, TargetId and State consistent at the end of target selection. A hero holding a live
-- target never stays in FOLLOW_MASTER, and a hero without one never keeps a cached NetId: camp
-- mobs keep their NetId across respawns, so a stale id would otherwise come back "alive".
function HeroTargeting.Settle(hero: any, hasTarget: boolean)
	if hasTarget then
		if hero.State == "FOLLOW_MASTER" then hero.State = "MOVE_TO_TARGET" end
	else
		hero.TargetNetId = nil
		hero.TargetId = nil
		if hero.State ~= "COMA" then hero.State = "FOLLOW_MASTER" end
	end
end

-- One tick of target choice for a hero, applied to hero.TargetNetId/TargetId/State. Returns the mob to fight.
-- Order:
-- 1. Master Focus Target overrides immediately.
-- 2. Target Lock Hysteresis: keep held auto-aggro target unless it dies/despawns/leaves leash,
--    or a competing mob is at least 12 studs closer (hysteresis margin).
-- 3. Otherwise (unless pacified), join squad assist target, or pick nearest mob using elevation-weighted distance.
function HeroTargeting.Select(
	hero: any,
	mobs: { [number]: any },
	ctx: Context,
	eligible: (hero: any, mob: any) -> boolean,
	pacified: boolean,
	assist: { number }?
): any?
	local function usable(netId: number?): any?
		local mob = if netId then mobs[netId] else nil
		if mob and not rejected(hero, netId :: number, mob, ctx) and eligible(hero, mob) and HeroTargeting.CanEngage(hero, mob, ctx) then return mob end
		return nil
	end

	if pacified then
		HeroTargeting.Settle(hero, false)
		return nil
	end

	-- 1. Master Focus Target override ([Click / Tap])
	if ctx.FocusedTargetNetId then
		local focused = usable(ctx.FocusedTargetNetId)
		if focused then
			hero.TargetNetId = ctx.FocusedTargetNetId
			hero.TargetId = ctx.FocusedTargetNetId
			hero.IsFocusTarget = true
			HeroTargeting.Settle(hero, true)
			return focused
		end
	end

	local currentId = hero.TargetId or hero.TargetNetId
	local currentTarget = usable(currentId)

	local firstAssistId: number? = nil
	local firstAssistMob: any? = nil
	local assistAllowed: { [number]: boolean }? = nil
	local committedCampId: string? = nil
	if assist and #assist > 0 then
		for _, netId in assist do
			local rawMob = mobs[netId]
			if not committedCampId and rawMob and rawMob.CampId and eligible(hero, rawMob) then
				committedCampId = rawMob.CampId
			end
			local m = usable(netId)
			if m then
				if not firstAssistId then
					firstAssistId = netId
					firstAssistMob = m
					assistAllowed = {}
				end
				(assistAllowed :: { [number]: boolean })[netId] = true
			end
		end
		if firstAssistMob and firstAssistMob.CampId and assistAllowed then
			for netId, m in pairs(mobs) do
				if m and m.CampId == firstAssistMob.CampId and usable(netId) then
					assistAllowed[netId] = true
				end
			end
		end
	end
	if currentTarget and ctx.Assigned and committedCampId and currentTarget.CampId ~= committedCampId and not firstAssistId then
		currentTarget = nil
	end

	-- 2. Target Lock Hysteresis (Anti-Thrashing):
	if currentTarget then
		-- Explicit Master Focus Target maintains lock without hysteresis
		if hero.IsFocusTarget and (not ctx.FocusedTargetNetId or ctx.FocusedTargetNetId == currentId) then
			hero.TargetNetId = currentId
			hero.TargetId = currentId
			HeroTargeting.Settle(hero, true)
			return currentTarget
		end

		-- When squad assist / camp commitment is active, never split off to another camp
		if assistAllowed and firstAssistId and firstAssistMob then
			if not assistAllowed[currentId :: number] then
				hero.TargetNetId = firstAssistId
				hero.TargetId = firstAssistId
				hero.IsFocusTarget = false
				HeroTargeting.Settle(hero, true)
				return firstAssistMob
			end
			if ctx.Assigned and currentId == firstAssistId then
				hero.TargetNetId = currentId
				hero.TargetId = currentId
				HeroTargeting.Settle(hero, true)
				return currentTarget
			end
		end

		-- Competing mob must be at least 12 studs closer (hysteresis margin) using the same distance metric
		local currentDist = measureDistance(hero, currentTarget, ctx)
		local betterNetId = HeroTargeting.Acquire(hero, mobs, ctx, eligible, currentDist - HeroTargeting.HYSTERESIS_MARGIN, assistAllowed)
		if betterNetId and betterNetId ~= currentId then
			local betterTarget = usable(betterNetId)
			if betterTarget then
				hero.TargetNetId = betterNetId
				hero.TargetId = betterNetId
				hero.IsFocusTarget = false
				HeroTargeting.Settle(hero, true)
				return betterTarget
			end
		end

		-- No competing mob is 12 studs closer: keep current target
		hero.TargetNetId = currentId
		hero.TargetId = currentId
		HeroTargeting.Settle(hero, true)
		return currentTarget
	end

	-- 3. Current target is nil or no longer usable (died / despawned / left leash)
	hero.IsFocusTarget = false
	local target = nil

	-- Squad assist targets (anchored squad commitment)
	if firstAssistId and firstAssistMob then
		target = firstAssistMob
		hero.TargetNetId = firstAssistId
		hero.TargetId = firstAssistId
	end

	-- Acquire new target using elevation-weighted distance and deterministic tie-breaking
	if not target and not (ctx.Assigned and committedCampId ~= nil) then
		local netId = HeroTargeting.Acquire(hero, mobs, ctx, eligible, nil)
		target = usable(netId)
		if target then
			hero.TargetNetId = netId
			hero.TargetId = netId
		end
	end

	HeroTargeting.Settle(hero, target ~= nil)
	return target
end

return table.freeze(HeroTargeting)