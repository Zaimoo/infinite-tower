--!strict
-- Shared pose vocabulary for tower enemy clips (docs/mob-reanimation-plan.md §3.2).
--
-- Rigs face -Z with +X on the enemy's right (EnemyRigFactory). Every joint rotates about its pivot in its
-- parent's axes, so raw CFrame signs are easy to get backwards. Clips are authored through `pose` instead,
-- whose fields are named for what you see (all angles in degrees, translations in reference-hip studs):
--   lean     body tips forward (+) / back (-)          twist   shoulders turn to the enemy's right (+)
--   tilt     body rolls to the right (+)               bob     body rises (+) / drops (-)
--   push     body slides forward (+)                   slide   body slides right (+)
--   nod      head looks down (+)                       turn    head turns right (+)
--   armL/armR = { fwd, out, roll }: arm swings forward/up (+), away from the body (+), rolls
--   foreL/foreR   elbow bends, forearm swinging forward (+)
--   legL/legR  = { fwd, out }: thigh swings forward (+), away from the body (+)
--   kneeL/kneeR   knee bends, shin swinging back (+)
--   extra = { [jointName] = CFrame } for Extra* joints, passed through as written
-- The legs counter the body's lean, twist and tilt, so feet stay planted unless a clip moves them on purpose.
local Common = {}

local rad = math.rad

local function rot(x: number, y: number, z: number): CFrame
	return CFrame.Angles(rad(x), rad(y), rad(z))
end
Common.rot = rot

export type Limb = { fwd: number?, out: number?, roll: number? }
export type PoseSpec = {
	lean: number?, twist: number?, tilt: number?, bob: number?, push: number?, slide: number?,
	nod: number?, turn: number?,
	armL: Limb?, armR: Limb?, foreL: number?, foreR: number?,
	legL: Limb?, legR: Limb?, kneeL: number?, kneeR: number?,
	planted: boolean?, -- default true: legs counter the body
	extra: { [string]: CFrame }?,
}

-- Hanging limb pointing down -Y: Rx(+a) swings its tip to -Z (forward), Rz(+a) swings it to +X (right).
local function limb(fwd: number, outRight: number, roll: number): CFrame
	return rot(fwd, roll, outRight)
end

function Common.pose(p: PoseSpec): { [string]: CFrame }
	local lean, twist, tilt = p.lean or 0, p.twist or 0, p.tilt or 0
	local planted = p.planted ~= false
	local out: { [string]: CFrame } = {}
	-- Body: Rx(-lean) tips the top forward (-Z); Ry(-twist) turns the face right; Rz(-tilt) rolls the top right.
	out.Body = CFrame.new(p.slide or 0, p.bob or 0, -(p.push or 0)) * rot(-lean, -twist, -tilt)
	-- Head: Rx(-nod) points the face down; Ry(-turn) turns it right.
	out.Head = rot(-(p.nod or 0), -(p.turn or 0), 0)
	local aL, aR = p.armL or {}, p.armR or {}
	out.ArmL = limb(aL.fwd or 0, -(aL.out or 0), aL.roll or 0)
	out.ArmR = limb(aR.fwd or 0, aR.out or 0, -(aR.roll or 0))
	out.ForearmL = rot(p.foreL or 0, 0, 0)
	out.ForearmR = rot(p.foreR or 0, 0, 0)
	-- Legs inherit the body's turn; when planted they cancel it (Rx(+lean) undoes Rx(-lean) on a hanging leg).
	local cl, ct, cr = if planted then lean else 0, if planted then twist else 0, if planted then tilt else 0
	local lL, lR = p.legL or {}, p.legR or {}
	out.LegL = rot(cl + (lL.fwd or 0), ct, cr - (lL.out or 0))
	out.LegR = rot(cl + (lR.fwd or 0), ct, cr + (lR.out or 0))
	-- Knee: Rx(-bend) swings the shin back.
	out.KneeL = rot(-(p.kneeL or 0), 0, 0)
	out.KneeR = rot(-(p.kneeR or 0), 0, 0)
	if p.extra then
		for name, cf in p.extra do out[name] = cf end
	end
	return out
end

-- Merge pose specs: fields of `over` replace `base`; limb tables merge field by field; extras merge.
function Common.with(base: PoseSpec, over: PoseSpec): PoseSpec
	local r: any = table.clone(base :: any)
	for k, v in over :: any do
		if type(v) == "table" and type(r[k]) == "table" and k ~= "extra" then
			local m = table.clone(r[k])
			for kk, vv in v do m[kk] = vv end
			r[k] = m
		elseif k == "extra" and type(r.extra) == "table" then
			local m = table.clone(r.extra)
			for kk, vv in v do m[kk] = vv end
			r.extra = m
		else
			r[k] = v
		end
	end
	return r
end

-- Add the numeric fields of `delta` onto `base` (limb tables field by field); extras pass through.
function Common.add(base: PoseSpec, delta: PoseSpec): PoseSpec
	local r: any = table.clone(base :: any)
	for k, v in delta :: any do
		if type(v) == "number" then
			r[k] = (r[k] or 0) + v
		elseif type(v) == "table" and k ~= "extra" then
			local m = table.clone(r[k] or {})
			for kk, vv in v do m[kk] = (m[kk] or 0) + vv end
			r[k] = m
		else
			r[k] = v
		end
	end
	return r
end

-- A dropped crouch: lower the body by `drop` (reference studs; the hip is 3.5) and bend the knees so the feet
-- stay on the floor. Thigh forward by a and shin back by 2a shortens a 3.5-stud leg by 3.5 * (1 - cos a).
Common.REFERENCE_HIP = 3.5
function Common.crouch(spec: PoseSpec, drop: number): PoseSpec
	local a = math.deg(math.acos(math.clamp(1 - drop / Common.REFERENCE_HIP, -1, 1)))
	return Common.with(spec, {
		bob = (spec.bob or 0) - drop,
		legL = { fwd = ((spec.legL or {}).fwd or 0) + a }, legR = { fwd = ((spec.legR or {}).fwd or 0) + a },
		kneeL = (spec.kneeL or 0) + 2 * a, kneeR = (spec.kneeR or 0) + 2 * a,
	})
end

-- ------------------------------------------------------------------ clips
-- Attack markers (plan §3.3): Release = the strike starts, Impact = contact or launch. TowerEnemyClips.MarkersFor
-- reads this table for clips built here.
Common.Markers = setmetatable({}, { __mode = "k" }) :: { [any]: { number } }

export type Frames = { { any } }

-- Keys from { t, PoseSpec } pairs.
function Common.keys(list: { { any } }): Frames
	local out: Frames = {}
	for _, k in list do table.insert(out, { k[1], Common.pose(k[2]) }) end
	return out
end

-- An attack clip with its markers.
function Common.attack(list: { { any } }, release: number, impact: number): Frames
	local frames = Common.keys(list)
	Common.Markers[frames] = { release, impact }
	return frames
end

-- A looping clip sampled from fn(phase 0..1) -> PoseSpec at n evenly spaced keys (the last equals the first).
function Common.loop(n: number, fn: (number) -> PoseSpec): Frames
	local out: Frames = {}
	for i = 0, n do
		local phase = i / n
		table.insert(out, { phase, Common.pose(fn(phase % 1)) })
	end
	return out
end

-- Hit flinch, authored as a delta from the identity pose (EnemyAnimator adds it on top of whatever plays).
Common.Hit = Common.keys({
	{ 0, {} },
	{ 0.2, { lean = -9, twist = 6, bob = -0.05, nod = -10, armL = { fwd = -10, out = 10 }, armR = { fwd = -8, out = 12 }, foreL = 15, foreR = 15 } },
	{ 1, {} },
})

return Common
