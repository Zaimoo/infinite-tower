--!strict
-- Pure squad positioning and target choice for the hero sim. No Roblox services and only
-- Vector3.new/.X/.Y/.Z, so specs run it under the CLI shim.
-- Goal: heroes read as a squad, not five copies of one script. They fan out around a target,
-- ranged heroes hold distance, the follow formation trails the Master's heading, and each hero
-- has its own small speed signature.
local SquadTactics = {}

SquadTactics.RANGED_MIN_RANGE = 12 -- AttackRange at or above this counts as a ranged hero
SquadTactics.MELEE_CROWD = 2 -- melee heroes per mob before the next one prefers another target
SquadTactics.CROWD_PENALTY = 12
SquadTactics.FOCUS_BONUS = 6 -- ranged heroes lean toward what the squad already fights
SquadTactics.THREAT_BONUS = 8 -- a mob on top of a squadmate gets peeled first
SquadTactics.COHESION_WEIGHT = .5 -- keeps the squad from splitting across camps
SquadTactics.ACCELERATION = 42 -- studs/s²
SquadTactics.DECELERATION = 70

-- Slot fan: 0, +40°, -40°, +80°, -80° around the approach bearing.
local FAN = { 0, 40, -40, 80, -80 }

-- Trailing arc behind the leader, in leader space (X right, Z back).
local FORMATION = {
	{ -3.5, 4.5 },
	{ 3.5, 4.5 },
	{ -6.5, 1.5 },
	{ 6.5, 1.5 },
	{ 0, 8 },
}

function SquadTactics.IsRanged(attackRange: number): boolean
	return attackRange >= SquadTactics.RANGED_MIN_RANGE
end

local function flatUnit(x: number, z: number): (number, number)
	local m = math.sqrt(x * x + z * z)
	if m < 1e-4 then return 0, -1 end
	return x / m, z / m
end

-- Where this hero should stand to hit `target`: on its own side of the target, fanned by slot so
-- squadmates surround it instead of stacking on one approach line.
function SquadTactics.EngagePoint(heroPos: Vector3, targetPos: Vector3, slotIndex: number, attackRange: number): Vector3
	local bx, bz = flatUnit(heroPos.X - targetPos.X, heroPos.Z - targetPos.Z)
	local angle = math.rad(FAN[((slotIndex - 1) % #FAN) + 1])
	local c, s = math.cos(angle), math.sin(angle)
	local dx, dz = bx * c - bz * s, bx * s + bz * c
	local radius = if SquadTactics.IsRanged(attackRange) then attackRange * .8 else math.max(2.5, attackRange * .7)
	return Vector3.new(targetPos.X + dx * radius, heroPos.Y, targetPos.Z + dz * radius)
end

-- Formation offset trailing a leader heading along (forwardX, forwardZ).
function SquadTactics.FormationOffset(slotIndex: number, forwardX: number, forwardZ: number): Vector3
	local fx, fz = flatUnit(forwardX, forwardZ)
	local rx, rz = -fz, fx -- right-hand perpendicular in XZ
	local slot = FORMATION[((slotIndex - 1) % #FORMATION) + 1]
	local right, back = slot[1], slot[2]
	return Vector3.new(rx * right - fx * back, 0, rz * right - fz * back)
end

-- Small per-hero speed signature (±4%), stable for a slot so the squad never moves in lockstep.
function SquadTactics.SpeedScale(slotIndex: number): number
	return 1 + (((slotIndex * 37) % 9) - 4) * .01
end

-- Eases a hero's speed toward the desired value instead of snapping between 0 and full speed.
function SquadTactics.Accelerate(current: number, desired: number, dt: number): number
	if desired >= current then
		return math.min(desired, current + SquadTactics.ACCELERATION * dt)
	end
	return math.max(desired, current - SquadTactics.DECELERATION * dt)
end

export type Candidate = {
	Id: number,
	Position: Vector3,
	MeleeEngaged: number, -- melee squadmates already on it (excluding this hero)
	Engaged: number, -- all squadmates already on it (excluding this hero)
	ThreatensAlly: boolean,
}

-- Lower score wins. Melee heroes spread once a mob is crowded; ranged heroes focus what the squad
-- fights; everyone peels mobs that are hitting a squadmate and stays near the squad centre.
function SquadTactics.Score(heroPos: Vector3, attackRange: number, candidate: Candidate, centre: Vector3?): number
	local dx, dz = candidate.Position.X - heroPos.X, candidate.Position.Z - heroPos.Z
	local score = math.sqrt(dx * dx + dz * dz)
	if SquadTactics.IsRanged(attackRange) then
		score -= math.min(candidate.Engaged, 3) * SquadTactics.FOCUS_BONUS
	elseif candidate.MeleeEngaged >= SquadTactics.MELEE_CROWD then
		score += (candidate.MeleeEngaged - SquadTactics.MELEE_CROWD + 1) * SquadTactics.CROWD_PENALTY
	end
	if candidate.ThreatensAlly then score -= SquadTactics.THREAT_BONUS end
	if centre then
		local cx, cz = candidate.Position.X - centre.X, candidate.Position.Z - centre.Z
		score += math.sqrt(cx * cx + cz * cz) * SquadTactics.COHESION_WEIGHT
	end
	return score
end

function SquadTactics.PickTarget(heroPos: Vector3, attackRange: number, candidates: { Candidate }, centre: Vector3?): number?
	local bestId, bestScore = nil, math.huge
	for _, candidate in candidates do
		local score = SquadTactics.Score(heroPos, attackRange, candidate, centre)
		if score < bestScore then bestId, bestScore = candidate.Id, score end
	end
	return bestId
end

return table.freeze(SquadTactics)
