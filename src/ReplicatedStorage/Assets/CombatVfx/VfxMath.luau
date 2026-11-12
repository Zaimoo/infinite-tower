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

-- The Archer: Astrea's constellation (Constellation Judgment), a stylised Sagittarius. Stars are
-- { x, z } on a unit disc (+z is the top of the figure); Lines are pairs of star indices in the
-- order they are drawn, and every line starts from a star an earlier line has already reached,
-- so the figure traces itself like a pen. Stars are numbered so that neighbours fall in
-- different waves (star i falls in wave i mod waves) and each wave covers the whole area.
export type Figure = { Stars: { { number } }, Lines: { { number } } }

VfxMath.ARCHER = table.freeze({
	Stars = table.freeze({
		{ -0.62, -0.38 }, -- 1 the arrow's tip
		{ -0.30, -0.12 }, -- 2 the grip of the bow
		{ -0.24, -0.58 }, -- 3 the bow's lower limb
		{ -0.18, 0.28 }, -- 4 the bow's upper limb
		{ 0.18, 0.06 }, -- 5 the archer's chest
		{ 0.48, 0.18 }, -- 6 the shoulder
		{ 0.66, -0.18 }, -- 7 the hip
		{ 0.36, -0.46 }, -- 8 the waist
		{ -0.34, 0.66 }, -- 9 the head
		{ 0.40, 0.56 }, -- 10 the cloak
		{ 0.66, 0.50 }, -- 11
		{ 0.86, 0.30 }, -- 12
		{ 0.84, -0.44 }, -- 13 the hind leg
		{ 0.52, -0.80 }, -- 14
		{ 0.02, -0.88 }, -- 15 the fore leg
		{ -0.72, 0.20 }, -- 16 the crown
	}),
	Lines = table.freeze({
		{ 1, 2 }, { 2, 3 }, { 2, 4 }, { 4, 5 }, { 2, 5 }, { 5, 6 }, { 6, 7 }, { 7, 8 }, { 8, 5 },
		{ 3, 8 }, { 4, 9 }, { 9, 16 }, { 6, 10 }, { 10, 11 }, { 11, 12 }, { 7, 13 }, { 13, 14 }, { 8, 15 },
	}),
}) :: Figure

-- A figure's stars laid on the ground around `center`, scaled to `radius`, with the top of the
-- figure pointing along the horizontal direction `heading` (away from whoever cast it).
function VfxMath.FigurePoints(figure: Figure, center: Vector3, radius: number, heading: Vector3): { Vector3 }
	local flat = math.sqrt(heading.X * heading.X + heading.Z * heading.Z)
	local fx, fz = 0, -1
	if flat > 1e-4 then
		fx, fz = heading.X / flat, heading.Z / flat
	end
	-- Right of the heading: heading x up.
	local rx, rz = -fz, fx
	local points = table.create(#figure.Stars)
	for _, star in figure.Stars do
		local x, z = star[1] * radius, star[2] * radius
		table.insert(points, Vector3.new(center.X + rx * x + fx * z, center.Y, center.Z + rz * x + fz * z))
	end
	return points
end

-- How a figure traces itself over [startAt, endAt]: when each line starts drawing, how long a
-- line takes, and when each star lights (as the first line to touch it leaves or reaches it).
function VfxMath.FigureTrace(figure: Figure, startAt: number, endAt: number): ({ number }, number, { number })
	local lines = #figure.Lines
	local span = math.max(0.02, endAt - startAt)
	-- Lines overlap: each takes a little over two steps, and the last one ends at endAt.
	local lineSeconds = math.min(span, span / math.max(1, lines) * 2.2)
	local slot = if lines > 1 then (span - lineSeconds) / (lines - 1) else 0
	local lineStarts = table.create(lines)
	local starAt = table.create(#figure.Stars, startAt + span)
	for k, line in figure.Lines do
		local from = startAt + (k - 1) * slot
		table.insert(lineStarts, from)
		starAt[line[1]] = math.min(starAt[line[1]], from)
		starAt[line[2]] = math.min(starAt[line[2]], from + lineSeconds)
	end
	return lineStarts, lineSeconds, starAt
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
