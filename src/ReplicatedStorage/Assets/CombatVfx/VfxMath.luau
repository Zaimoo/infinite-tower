--!strict
-- ReplicatedStorage/Assets/CombatVfx/VfxMath.luau
-- Pure geometry and timing for combat VFX (docs/projectile-skill-vfx-plan.md, section 6). No
-- instances, so the test suite can check it. Times are server time (GetServerTimeNow()), the
-- clock the HERO_CUE is stamped with, so a projectile lands when the server lands the hit.

local VfxMath = {}

local function lerp(a: Vector3, b: Vector3, t: number): Vector3
	return Vector3.new(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t)
end
VfxMath.Lerp = lerp

function VfxMath.Horizontal(a: Vector3, b: Vector3): number
	local dx, dz = b.X - a.X, b.Z - a.Z
	return math.sqrt(dx * dx + dz * dz)
end

function VfxMath.Distance(a: Vector3, b: Vector3): number
	local dx, dy, dz = b.X - a.X, b.Y - a.Y, b.Z - a.Z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Mid-flight lift for an arc: `arcPer10` studs per 10 studs of horizontal distance.
function VfxMath.ArcLift(p0: Vector3, p1: Vector3, arcPer10: number?): number
	return VfxMath.Horizontal(p0, p1) * (arcPer10 or 0) / 10
end

-- A point on a parabolic flight from p0 to p1 at alpha (0..1), lifted by `lift` at mid-flight.
function VfxMath.ArcPoint(p0: Vector3, p1: Vector3, alpha: number, lift: number): Vector3
	local a = math.clamp(alpha, 0, 1)
	local point = lerp(p0, p1, a)
	return Vector3.new(point.X, point.Y + lift * 4 * a * (1 - a), point.Z)
end

-- The point `extra` studs beyond p1 along the p0 -> p1 line (a piercing arrow's exit).
function VfxMath.Extend(p0: Vector3, p1: Vector3, extra: number): Vector3
	local length = VfxMath.Distance(p0, p1)
	if length < 1e-4 then
		return p1
	end
	return lerp(p0, p1, (length + extra) / length)
end

-- The p1 of a fanned arrow: p0 -> p1 turned `degrees` about the vertical, carried `extra` further.
function VfxMath.Fan(p0: Vector3, p1: Vector3, degrees: number, extra: number): Vector3
	local tip = VfxMath.Extend(p0, p1, extra)
	local dx, dz = tip.X - p0.X, tip.Z - p0.Z
	local r = math.rad(degrees)
	local c, s = math.cos(r), math.sin(r)
	return Vector3.new(p0.X + dx * c - dz * s, tip.Y, p0.Z + dx * s + dz * c)
end

-- `count` landing points spread evenly over a disc (a sunflower spiral turned by `seed`).
function VfxMath.RainPoints(center: Vector3, radius: number, count: number, seed: number): { Vector3 }
	local points = table.create(count)
	for i = 1, count do
		local r = radius * 0.9 * math.sqrt((i - 0.5) / count)
		local angle = seed + i * 2.399963 -- golden angle
		table.insert(points, Vector3.new(center.X + math.cos(angle) * r, center.Y, center.Z + math.sin(angle) * r))
	end
	return points
end

-- Server times at which each damage tick lands.
function VfxMath.WaveTimes(impactAt: number, ticks: number, gap: number): { number }
	local times = table.create(ticks)
	for i = 1, math.max(1, ticks) do
		table.insert(times, impactAt + (i - 1) * gap)
	end
	return times
end

-- When a cue's projectile leaves the weapon and when it lands, in server time.
function VfxMath.FlightWindow(cue: any): (number, number)
	local release = cue.StartServerTime + cue.ReleaseSeconds
	return release, release + cue.TravelSeconds
end

-- Fraction of a [startAt, endAt] window reached at `now`, clamped to 0..1.
function VfxMath.Progress(startAt: number, endAt: number, now: number): number
	if endAt <= startAt then
		return if now >= endAt then 1 else 0
	end
	return math.clamp((now - startAt) / (endAt - startAt), 0, 1)
end

return table.freeze(VfxMath)
