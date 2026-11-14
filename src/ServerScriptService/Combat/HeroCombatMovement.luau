--!strict
-- ServerScriptService/Combat/HeroCombatMovement.luau
-- Where a hero wants to stand while it fights (GDD 4.5, Combat Movement). Pure: CombatSimulation
-- passes positions and telegraphs, validates the returned goal against the world and walks it
-- with HeroNavigation, so this module never touches geometry.
--
-- A hero in range of its target used to stand still. It now picks one manoeuvre at a time:
--   EVADE   leave an enemy telegraph (arc, disc or projectile lane) before it lands
--   KITE    a ranged hero backs away from a mob that closed in, staying inside its own range
--   FLANK   a melee hero takes its own slot on a ring round the target (Strikers go for the back)
--   SPREAD  a ranged hero sidesteps off an ally it is stacked on
-- Manoeuvres only run between a hero's own attacks (CombatSimulation holds it for the wind-up),
-- so they cost no attack speed and a telegraph is only dodged when the hero has time to leave it.

local HeroCombatMovement = {}

export type Kind = "EVADE" | "KITE" | "FLANK" | "SPREAD"
export type RingStyle = "BACK" | "GUARD" | "NEAREST"

export type Threat = {
	Shape: string, -- ARC | PROJECTILE | SELF_DISC | TARGET_DISC (AttackTimeline shapes)
	Origin: Vector3,
	Aim: Vector3,
	Yaw: number,
	Range: number,
	Radius: number,
	HalfArcCos: number?,
	TimeToImpact: number, -- seconds until the hit resolves
	Age: number, -- seconds since the wind-up started
}

export type Ally = {
	NetId: number,
	Position: Vector3,
	AttackRange: number,
	TargetNetId: number?,
}

export type Hostile = {
	NetId: number,
	Position: Vector3,
}

export type Input = {
	NetId: number,
	Position: Vector3,
	AttackRange: number,
	Archetype: string?,
	BaseSpeed: number,
	TargetNetId: number,
	TargetPosition: Vector3,
	TargetYaw: number?,
	TargetAimsAtHero: boolean?, -- the target is facing this hero, so it has no back to reach
	Allies: { Ally }?, -- standing squadmates, without the hero itself
	Hostiles: { Hostile }?, -- live mobs in the room
	Threats: { Threat }?,
	LeashCenter: Vector3?, -- free-following squads stay inside LeashRadius of the Master
	LeashRadius: number?,
	EvadeOnly: boolean?, -- skip positioning: the hero is busy or out of range
}

export type Plan = {
	Kind: Kind,
	Goal: Vector3,
	Speed: number,
	Deadline: number?, -- EVADE: seconds until the telegraph lands
}

export type Profile = {
	Evades: boolean,
	Ring: RingStyle,
}

-- Heroes with at least this much reach fight from range: they kite and spread instead of flanking.
HeroCombatMovement.RANGED_MIN_RANGE = 14.0
-- A telegraph is noticed this long after its wind-up starts.
HeroCombatMovement.EVADE_REACTION = 0.2
-- Studs of clearance past the edge of a telegraph.
HeroCombatMovement.EVADE_MARGIN = 1.6
-- Extra angle past an arc's edge, in radians.
HeroCombatMovement.EVADE_ARC_MARGIN = 0.22
-- Share of the time left that an escape may use; the rest covers a tick of latency.
HeroCombatMovement.EVADE_TIME_BUDGET = 0.85
HeroCombatMovement.EVADE_SPEED = 1.0
HeroCombatMovement.KITE_SPEED = 0.8
HeroCombatMovement.SHUFFLE_SPEED = 0.55
-- A ranged hero backs off when a mob is inside AttackRange * KITE_TRIGGER (clamped).
HeroCombatMovement.KITE_TRIGGER = 0.35
HeroCombatMovement.KITE_TRIGGER_MIN = 6.0
HeroCombatMovement.KITE_TRIGGER_MAX = 11.0
HeroCombatMovement.KITE_STEP = 8.0
-- Kiting and spreading never leave this share of the hero's own range.
HeroCombatMovement.RANGE_BAND = 0.9
-- Melee ring radius as a share of attack range, and the spacing kept along it.
HeroCombatMovement.RING_BAND = 0.8
HeroCombatMovement.MELEE_SPACING = 3.4
-- The most a hero walks round the ring in one manoeuvre, in radians.
HeroCombatMovement.RING_STEP = 0.9
HeroCombatMovement.RANGED_SPACING = 3.5
-- Goals closer than this are ignored, so heroes do not twitch.
HeroCombatMovement.DEADBAND = 1.25
HeroCombatMovement.MAX_HEIGHT_GAP = 11.0 -- AttackTimeline.Contains ignores targets further above or below

-- Vanguards and Berserkers hold their ground and take the hit; the rest step out of telegraphs.
local PROFILES: { [string]: Profile } = {
	Vanguard = { Evades = false, Ring = "GUARD" },
	Berserker = { Evades = false, Ring = "NEAREST" },
	Striker = { Evades = true, Ring = "BACK" },
	Marksman = { Evades = true, Ring = "NEAREST" },
	Scholar = { Evades = true, Ring = "NEAREST" },
	Healer = { Evades = true, Ring = "NEAREST" },
}
local DEFAULT_PROFILE: Profile = { Evades = true, Ring = "NEAREST" }

function HeroCombatMovement.Profile(archetype: string?): Profile
	return (archetype and PROFILES[archetype]) or DEFAULT_PROFILE
end

function HeroCombatMovement.IsRanged(attackRange: number): boolean
	return attackRange >= HeroCombatMovement.RANGED_MIN_RANGE
end

local function flat(a: Vector3, b: Vector3): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- Unit XZ direction from `from` to `to`, or nil when they share a column.
local function direction(from: Vector3, to: Vector3): Vector3?
	local dx, dz = to.X - from.X, to.Z - from.Z
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 0.01 then
		return nil
	end
	return Vector3.new(dx / length, 0, dz / length)
end

local function wrap(angle: number): number
	return (angle + math.pi) % (2 * math.pi) - math.pi
end

-- Yaw convention shared with the sim: facing = (-sin yaw, 0, -cos yaw).
local function facing(yaw: number): Vector3
	return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
end

local function bearing(v: Vector3): number
	return math.atan2(v.X, v.Z)
end

local function fromBearing(angle: number): Vector3
	return Vector3.new(math.sin(angle), 0, math.cos(angle))
end

-- A stable left/right choice per hero, so two heroes on one spot split instead of pairing up.
local function sideOf(netId: number): number
	return if netId % 2 == 0 then 1 else -1
end

local function segmentClosest(p: Vector3, a: Vector3, b: Vector3): Vector3
	local vx, vz = b.X - a.X, b.Z - a.Z
	local len2 = vx * vx + vz * vz
	if len2 < 0.0001 then
		return a
	end
	local t = math.clamp(((p.X - a.X) * vx + (p.Z - a.Z) * vz) / len2, 0, 1)
	return Vector3.new(a.X + vx * t, p.Y, a.Z + vz * t)
end

-- Whether `position` would be hit by the telegraph, grown by `margin` studs. Mirrors
-- AttackTimeline.Contains, which is what decides the hit when the wind-up ends.
function HeroCombatMovement.InDanger(threat: Threat, position: Vector3, margin: number?): boolean
	local pad = margin or 0
	if math.abs(threat.Origin.Y - position.Y) > HeroCombatMovement.MAX_HEIGHT_GAP then
		return false
	end
	if threat.Shape == "ARC" then
		local d = flat(threat.Origin, position)
		if d > threat.Range + pad then
			return false
		end
		if d < 0.01 then
			return true
		end
		local f = facing(threat.Yaw)
		local dot = ((position.X - threat.Origin.X) * f.X + (position.Z - threat.Origin.Z) * f.Z) / d
		local half = math.acos(math.clamp(threat.HalfArcCos or 0, -1, 1))
		-- Widen the arc by the angle the margin subtends at this distance.
		local widened = math.min(math.pi, half + (if pad > 0 then pad / math.max(d, 1) else 0))
		return dot >= math.cos(widened)
	elseif threat.Shape == "PROJECTILE" then
		return flat(position, segmentClosest(position, threat.Origin, threat.Aim)) <= threat.Radius + pad
	end
	return flat(threat.Aim, position) <= threat.Radius + pad
end

-- The nearest spot outside the telegraph, or nil when the hero is not inside it.
function HeroCombatMovement.EscapePoint(threat: Threat, position: Vector3, netId: number): Vector3?
	if not HeroCombatMovement.InDanger(threat, position, 0) then
		return nil
	end
	local margin = HeroCombatMovement.EVADE_MARGIN
	local side = sideOf(netId)
	if threat.Shape == "ARC" then
		local f = facing(threat.Yaw)
		-- Standing on the attacker: step out behind it.
		local out: Vector3 = direction(threat.Origin, position) or Vector3.new(-f.X, 0, -f.Z)
		local d = math.max(flat(threat.Origin, position), 2.5)
		local backOff = threat.Origin + out * (threat.Range + margin)
		local half = math.acos(math.clamp(threat.HalfArcCos or 0, -1, 1))
		local exit = half + HeroCombatMovement.EVADE_ARC_MARGIN
		if exit >= math.pi then
			return Vector3.new(backOff.X, position.Y, backOff.Z) -- nowhere to flank a full circle
		end
		-- Walk round the attacker to the nearer edge of its swing.
		local offset = wrap(bearing(out) - bearing(f))
		local turn = if math.abs(offset) < 0.02 then side else (if offset > 0 then 1 else -1)
		local flank = threat.Origin + fromBearing(bearing(f) + turn * exit) * d
		local chosen = if flat(position, flank) <= flat(position, backOff) then flank else backOff
		return Vector3.new(chosen.X, position.Y, chosen.Z)
	elseif threat.Shape == "PROJECTILE" then
		local closest = segmentClosest(position, threat.Origin, threat.Aim)
		local along: Vector3 = direction(threat.Origin, threat.Aim) or Vector3.new(0, 0, 1)
		-- On the lane's centre line there is no nearer side: split by hero.
		local out: Vector3 = direction(closest, position) or Vector3.new(-along.Z, 0, along.X) * side
		local goal = closest + out * (threat.Radius + margin)
		return Vector3.new(goal.X, position.Y, goal.Z)
	end
	local out: Vector3 = direction(threat.Aim, position) or fromBearing(netId * 2.399963) -- golden angle: spread a stack
	local goal = threat.Aim + out * (threat.Radius + margin)
	return Vector3.new(goal.X, position.Y, goal.Z)
end

-- The most urgent telegraph the hero stands in and can still walk out of.
local function planEvade(input: Input): Plan?
	local threats = input.Threats
	if not threats or #threats == 0 then
		return nil
	end
	local speed = input.BaseSpeed * HeroCombatMovement.EVADE_SPEED
	local best: Plan? = nil
	local bestTime = math.huge
	for _, threat in threats do
		if threat.TimeToImpact <= 0 or threat.Age < HeroCombatMovement.EVADE_REACTION or threat.TimeToImpact >= bestTime then
			continue
		end
		local goal = HeroCombatMovement.EscapePoint(threat, input.Position, input.NetId)
		if not goal then
			continue
		end
		-- An escape that cannot finish in time is not started: the hero keeps fighting instead.
		if flat(input.Position, goal) > speed * threat.TimeToImpact * HeroCombatMovement.EVADE_TIME_BUDGET then
			continue
		end
		-- Never dodge out of one telegraph into another.
		local safe = true
		for _, other in threats do
			if other ~= threat and other.TimeToImpact > 0 and HeroCombatMovement.InDanger(other, goal, 0) then
				safe = false
				break
			end
		end
		if safe then
			best = { Kind = "EVADE", Goal = goal, Speed = speed, Deadline = threat.TimeToImpact }
			bestTime = threat.TimeToImpact
		end
	end
	return best
end

local function insideLeash(input: Input, goal: Vector3): boolean
	if not input.LeashCenter or not input.LeashRadius then
		return true
	end
	-- A hero already outside the leash may still move back toward it.
	return flat(goal, input.LeashCenter) <= math.max(input.LeashRadius, flat(input.Position, input.LeashCenter) - 0.01)
end

local function planKite(input: Input): Plan?
	local hostiles = input.Hostiles
	if not hostiles then
		return nil
	end
	local trigger = math.clamp(input.AttackRange * HeroCombatMovement.KITE_TRIGGER,
		HeroCombatMovement.KITE_TRIGGER_MIN, HeroCombatMovement.KITE_TRIGGER_MAX)
	local nearest: Hostile? = nil
	local nearestDist = trigger
	for _, hostile in hostiles do
		if math.abs(hostile.Position.Y - input.Position.Y) > 6 then
			continue
		end
		local d = flat(hostile.Position, input.Position)
		if d < nearestDist then
			nearest, nearestDist = hostile, d
		end
	end
	if not nearest then
		return nil
	end
	local away: Vector3 = direction(nearest.Position, input.Position)
		or direction(input.TargetPosition, input.Position)
		or fromBearing(input.NetId * 2.399963)
	local step = math.min(HeroCombatMovement.KITE_STEP, trigger - nearestDist + 4)
	local goal = input.Position + away * step
	-- Backing off never costs the hero its own target.
	local band = input.AttackRange * HeroCombatMovement.RANGE_BAND
	if flat(goal, input.TargetPosition) > band then
		local out = direction(input.TargetPosition, goal)
		if not out then
			return nil
		end
		local clamped = input.TargetPosition + out * band
		goal = Vector3.new(clamped.X, input.Position.Y, clamped.Z)
	end
	if flat(goal, input.Position) < HeroCombatMovement.DEADBAND or not insideLeash(input, goal) then
		return nil
	end
	-- Only worth it when the mob ends up further away.
	if flat(goal, nearest.Position) <= nearestDist + 0.5 then
		return nil
	end
	return { Kind = "KITE", Goal = goal, Speed = input.BaseSpeed * HeroCombatMovement.KITE_SPEED }
end

local function planSpread(input: Input): Plan?
	local allies = input.Allies
	if not allies then
		return nil
	end
	local closest: Ally? = nil
	local closestDist = HeroCombatMovement.RANGED_SPACING
	for _, ally in allies do
		local d = flat(ally.Position, input.Position)
		if math.abs(ally.Position.Y - input.Position.Y) <= 4 and d < closestDist then
			closest, closestDist = ally, d
		end
	end
	if not closest then
		return nil
	end
	-- The lower NetId holds its spot, so a stacked pair does not both shuffle and re-collide.
	if input.NetId < closest.NetId then
		return nil
	end
	local toTarget: Vector3 = direction(input.Position, input.TargetPosition) or Vector3.new(0, 0, 1)
	local right = Vector3.new(-toTarget.Z, 0, toTarget.X)
	local offset = input.Position - closest.Position
	local lateral = offset.X * right.X + offset.Z * right.Z
	local side = if math.abs(lateral) < 0.05 then sideOf(input.NetId) else (if lateral > 0 then 1 else -1)
	local push = HeroCombatMovement.RANGED_SPACING - closestDist + HeroCombatMovement.DEADBAND
	local goal = input.Position + right * (side * push)
	if flat(goal, input.TargetPosition) > input.AttackRange * HeroCombatMovement.RANGE_BAND
		and flat(goal, input.TargetPosition) > flat(input.Position, input.TargetPosition) then
		return nil
	end
	if not insideLeash(input, goal) then
		return nil
	end
	return { Kind = "SPREAD", Goal = goal, Speed = input.BaseSpeed * HeroCombatMovement.SHUFFLE_SPEED }
end

-- The bearing (from the target) a melee hero wants on the ring, before spacing.
local function preferredBearing(input: Input, current: number, style: RingStyle): number
	if style == "BACK" and input.TargetYaw and not input.TargetAimsAtHero then
		local f = facing(input.TargetYaw)
		return bearing(Vector3.new(-f.X, 0, -f.Z))
	elseif style == "GUARD" and input.Allies then
		-- Stand between the target and the squad's ranged heroes.
		local sx, sz, count = 0, 0, 0
		for _, ally in input.Allies do
			if HeroCombatMovement.IsRanged(ally.AttackRange) then
				sx += ally.Position.X
				sz += ally.Position.Z
				count += 1
			end
		end
		if count > 0 then
			local toBackline = direction(input.TargetPosition, Vector3.new(sx / count, 0, sz / count))
			if toBackline then
				return bearing(toBackline)
			end
		end
	end
	return current
end

local function planFlank(input: Input, profile: Profile): Plan?
	local out = direction(input.TargetPosition, input.Position)
	local current = if out then bearing(out) else input.NetId * 2.399963
	local radius = math.clamp(input.AttackRange * HeroCombatMovement.RING_BAND, 2.5, math.max(2.5, input.AttackRange - 0.6))
	local wanted = preferredBearing(input, current, profile.Ring)
	-- Walk round the ring a bounded arc at a time, so a flank reads as circling, not a dash.
	local desired = current + math.clamp(wrap(wanted - current), -HeroCombatMovement.RING_STEP, HeroCombatMovement.RING_STEP)

	local gap = math.min(HeroCombatMovement.MELEE_SPACING / radius, math.pi / 3)
	local allies = input.Allies
	if allies then
		for _ = 1, 2 do
			for _, ally in allies do
				if ally.TargetNetId ~= input.TargetNetId or HeroCombatMovement.IsRanged(ally.AttackRange) then
					continue
				end
				if flat(ally.Position, input.TargetPosition) > ally.AttackRange + 2 then
					continue -- still on its way in: it takes a slot when it arrives
				end
				local allyOut = direction(input.TargetPosition, ally.Position)
				if not allyOut then
					continue
				end
				local allyBearing = bearing(allyOut)
				local diff = wrap(desired - allyBearing)
				if math.abs(diff) < gap then
					local turn = if math.abs(diff) < 0.01
						then (if input.NetId > ally.NetId then 1 else -1)
						else (if diff > 0 then 1 else -1)
					desired = allyBearing + turn * gap
				end
			end
		end
	end

	local spot = input.TargetPosition + fromBearing(desired) * radius
	local goal = Vector3.new(spot.X, input.Position.Y, spot.Z)
	if flat(goal, input.Position) < HeroCombatMovement.DEADBAND then
		return nil
	end
	return { Kind = "FLANK", Goal = goal, Speed = input.BaseSpeed * HeroCombatMovement.SHUFFLE_SPEED }
end

-- The manoeuvre a hero should start now, or nil to hold its ground.
function HeroCombatMovement.Plan(input: Input): Plan?
	local profile = HeroCombatMovement.Profile(input.Archetype)
	if profile.Evades then
		local evade = planEvade(input)
		if evade then
			return evade
		end
	end
	if input.EvadeOnly then
		return nil
	end
	if HeroCombatMovement.IsRanged(input.AttackRange) then
		return planKite(input) or planSpread(input)
	end
	return planFlank(input, profile)
end

return table.freeze(HeroCombatMovement)
