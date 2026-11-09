--!strict
-- Creature motion sets (docs/mob-reanimation-plan.md §3.2, step 7): Quadruped, Avian, Serpent and Multileg,
-- each with its own idle, gait, fidgets, hit, death and shape-picked attack styles, keying the extras the
-- re-export gave them (tails, jaws, beaks, tail fans, frills, elytra, shells, stings). The Storm Roc and
-- the Tidal Leviathan get awakenings.
--
-- Joint axes (checked on the templates; rigs face -Z, +X is the creature's right, a joint turns in its
-- parent's axes): a limb hanging down swings forward with Rx(+); a part pointing forward (jaw, beak) dips
-- with Rx(-); a part pointing back (tail, elytron) rises with Rx(-) and swings right with Ry(+). Bird wings
-- bind spread flat along ±X: Rz(-) raises the left wing and Ry(+) sweeps it back (the right one mirrors).
-- A crawler's left legs point -X: Rz(-) lifts one and Ry(-) swings it forward (the right side mirrors).
local Common = require(game.ReplicatedStorage.Assets.EnemyClips.Common)

local rot = Common.rot
local TAU = 2 * math.pi
local sin, cos, max = math.sin, math.cos, math.max

local Creatures = {}

Creatures.FamilySet = {
	QUADRUPED = "Quadruped",
	AVIAN = "Avian", GIANT_AVIAN = "Avian",
	SERPENT = "Serpent",
	CRAWLER = "Multileg", SIX_LEGGED_CRAWLER = "Multileg", INSECT = "Multileg", CRUSTACEAN = "Multileg", SCORPION = "Multileg",
}

type Spec = { [string]: any }

-- A looping clip sampled from fn(phase) at n keys, posed by the body's own pose function.
local function loop(pose: (Spec) -> Pose, n: number, fn: (number) -> Spec): { { any } }
	local out = {}
	for i = 0, n do
		table.insert(out, { i / n, pose(fn((i / n) % 1)) })
	end
	return out
end

-- Attack markers on frames already posed by a body's own pose function (Common.attack would re-pose them).
local function attack(frames: { { any } }, release: number, impact: number): { { any } }
	Common.Markers[frames] = { release, impact }
	return frames
end

type Pose = { [string]: CFrame }

-- Spec helpers shared by every body: numbers add, nested tables add field by field.
local function add(base: Spec, delta: Spec): Spec
	local r = table.clone(base)
	for k, v in delta do
		if type(v) == "number" then
			r[k] = (r[k] or 0) + v
		elseif type(v) == "table" then
			r[k] = add(if type(r[k]) == "table" then r[k] else {}, v)
		else
			r[k] = v
		end
	end
	return r
end

local function body(p: Spec): CFrame
	-- lean: nose/top tips forward (+); twist: faces right (+); tilt: rolls right (+)
	return CFrame.new(p.slide or 0, p.bob or 0, -(p.push or 0)) * rot(-(p.lean or 0), -(p.twist or 0), -(p.tilt or 0))
end

-- ------------------------------------------------------------------ Quadruped
-- fields: lean twist tilt bob push nod turn; front/hind = { L, R } leg swing (+ forward); elbowL/R, hockL/R
-- (+ lower leg back); tail = { lift, wag }; jaw (+ open). Legs counter the body so paws stay planted.
local function quad(p: Spec): Pose
	local lean, twist, tilt = p.lean or 0, p.twist or 0, p.tilt or 0
	local f, h = p.front or {}, p.hind or {}
	local t = p.tail or {}
	local o: Pose = {
		Body = body(p),
		Head = rot(-(p.nod or 0), -(p.turn or 0), 0),
		ArmL = rot(lean + (f.L or 0), twist, tilt), ArmR = rot(lean + (f.R or 0), twist, tilt),
		LegL = rot(lean + (h.L or 0), twist, tilt), LegR = rot(lean + (h.R or 0), twist, tilt),
		ForearmL = rot(-(p.elbowL or 0), 0, 0), ForearmR = rot(-(p.elbowR or 0), 0, 0),
		KneeL = rot(-(p.hockL or 0), 0, 0), KneeR = rot(-(p.hockR or 0), 0, 0),
		ExtraTail1 = rot(-(t.lift or 0), t.wag or 0, 0),
		ExtraTail2 = rot(-(t.lift or 0) * 0.6, (t.wag or 0) * 1.3, 0),
		ExtraJaw = rot(-(p.jaw or 0), 0, 0),
	}
	return o
end

local function qkeys(list: { { any } }): { { any } }
	local out = {}
	for _, k in list do table.insert(out, { k[1], quad(k[2]) }) end
	return out
end

local Q_REST: Spec = { lean = 0, nod = 4, tail = { lift = 5 } }
local Q_SWING = 22

local function quadruped()
	local idle = loop(quad, 8, function(ph)
		local s = sin(TAU * ph)
		return add(Q_REST, {
			bob = 0.04 * s, lean = 1 * s, -- breathing
			turn = 22 * sin(TAU * ph) * math.abs(sin(TAU * ph)), nod = 3 * cos(TAU * ph * 2), -- head scans
			tilt = 1.5 * sin(TAU * (ph + 0.25)), slide = 0.05 * sin(TAU * (ph + 0.25)), -- shifts its weight
			tail = { wag = 12 * sin(TAU * ph * 2) },
			jaw = 4 + 4 * max(0, s), -- panting
		})
	end)
	local walk = loop(quad, 8, function(ph)
		local s, c = sin(TAU * ph), cos(TAU * ph)
		-- diagonal trot: front-left with hind-right
		return add(Q_REST, {
			lean = 2, bob = 0.08 * math.abs(c) - 0.04, nod = -3 * math.abs(c) + 2, tilt = 2 * s,
			front = { L = Q_SWING * s, R = -Q_SWING * s }, hind = { L = -Q_SWING * s, R = Q_SWING * s },
			elbowL = 35 * max(0, c), elbowR = 35 * max(0, -c), hockL = 30 * max(0, -c), hockR = 30 * max(0, c),
			tail = { wag = 14 * s, lift = 4 },
			jaw = 6,
		})
	end)
	local function shot(list)
		local k = { { 0, Q_REST } }
		for _, e in list do table.insert(k, { e[1], add(Q_REST, e[2]) }) end
		table.insert(k, { 1, Q_REST })
		return qkeys(k)
	end
	local fidgets = {
		shot({ { 0.3, { nod = -18, turn = 30, tail = { lift = 15 } } }, { 0.65, { nod = -18, turn = 34, jaw = 10 } } }), -- sniffs the air
		shot({ { 0.25, { tilt = 6, twist = 6, nod = 10, turn = -20 } }, { 0.45, { tilt = -6, twist = -6, nod = 10, turn = 20 } }, { 0.65, { tilt = 4, twist = 4 } } }), -- shakes itself
	}
	local hit = qkeys({ { 0, {} }, { 0.2, { lean = -8, push = -0.15, nod = -12, tilt = 4, jaw = 15, tail = { lift = -10 } } }, { 1, {} } })
	local death = qkeys({
		{ 0, Q_REST },
		{ 0.25, add(Q_REST, { lean = -10, nod = -25, tilt = 6, jaw = 25, front = { L = 20, R = 10 } }) },
		{ 0.55, { planted = false, bob = -0.8, tilt = 20, lean = 4, nod = 10, front = { L = 50, R = 30 }, hind = { L = -30, R = -20 }, elbowL = 60, elbowR = 50, hockL = 50, hockR = 40, tail = { lift = -15 } } },
		{ 1, { bob = -1.3, tilt = 82, slide = 0.4, nod = 20, front = { L = 30, R = 50 }, hind = { L = -20, R = -40 }, elbowL = 20, elbowR = 30, hockL = 20, tail = { lift = -20, wag = 10 }, jaw = 20 } },
	})
	local styles = {}
	function styles.LungeBite() -- ARC: crouch back, lunge and snap
		local wind = add(Q_REST, { lean = 6, push = -0.35, bob = -0.2, nod = -8, hind = { L = 15, R = 15 }, hockL = 35, hockR = 35, front = { L = -10, R = -10 }, jaw = 20, tail = { lift = 15 } })
		local bite = add(Q_REST, { lean = 8, push = 0.6, nod = 12, twist = -8, front = { L = 20, R = 15 }, hind = { L = -20, R = -20 }, jaw = 0, tail = { lift = 20 } })
		return attack(qkeys({ { 0, Q_REST }, { 0.55, wind }, { 0.72, add(wind, { jaw = 15, bob = -0.05 }) }, { 0.8, add(bite, { jaw = 30 }) }, { 0.86, bite }, { 1, Q_REST } }), 0.72, 0.86)
	end
	function styles.Butt() -- ARC for horned rams: head down, then a ramming shove
		local wind = add(Q_REST, { lean = -6, push = -0.4, nod = -20, hind = { L = 12, R = 12 }, hockL = 25, hockR = 25 })
		local hit = add(Q_REST, { lean = 10, push = 0.7, nod = 30, turn = 10, front = { L = 15, R = 10 }, hind = { L = -20, R = -20 } })
		return attack(qkeys({ { 0, Q_REST }, { 0.55, wind }, { 0.74, add(wind, { nod = 10 }) }, { 0.82, hit }, { 0.9, add(hit, { nod = -6 }) }, { 1, Q_REST } }), 0.74, 0.82)
	end
	function styles.Pounce() -- TARGET_DISC: rears onto its haunches and leaps on the target
		local rear = add(Q_REST, { lean = -28, bob = 0.3, nod = -15, front = { L = 40, R = 35 }, elbowL = 60, elbowR = 55, hind = { L = 20, R = 20 }, hockL = 30, hockR = 30, jaw = 25, tail = { lift = 20 } })
		local land = add(Q_REST, { lean = 14, push = 0.9, bob = -0.3, nod = 15, front = { L = 25, R = 25 }, hind = { L = -35, R = -35 }, jaw = 0, tail = { lift = 25 } })
		return attack(qkeys({ { 0, Q_REST }, { 0.55, rear }, { 0.74, add(rear, { lean = -4 }) }, { 0.82, land }, { 0.9, add(land, { lean = -4, bob = 0.1 }) }, { 1, Q_REST } }), 0.74, 0.82)
	end
	function styles.HowlStomp() -- SELF_DISC: rears up howling, then stamps down with both forelegs
		local rear = add(Q_REST, { lean = -32, bob = 0.35, nod = -35, front = { L = 55, R = 50 }, elbowL = 70, elbowR = 70, hind = { L = 25, R = 25 }, hockL = 35, hockR = 35, jaw = 40, tail = { lift = 25 } })
		local stamp = add(Q_REST, { lean = 10, bob = -0.25, nod = 18, front = { L = -10, R = -10 }, hind = { L = -10, R = -10 }, jaw = 15, tail = { lift = 15 } })
		return attack(qkeys({ { 0, Q_REST }, { 0.55, rear }, { 0.76, add(rear, { nod = -5 }) }, { 0.82, stamp }, { 0.9, add(stamp, { bob = 0.08 }) }, { 1, Q_REST } }), 0.76, 0.82)
	end
	function styles.Spit() -- PROJECTILE: rears the head back, then spits
		local wind = add(Q_REST, { lean = -8, nod = -25, push = -0.15, jaw = 10 })
		local spit = add(Q_REST, { lean = 6, nod = 15, push = 0.25, jaw = 35 })
		return attack(qkeys({ { 0, Q_REST }, { 0.5, wind }, { 0.62, add(wind, { nod = -5 }) }, { 0.7, spit }, { 0.85, add(spit, { jaw = -20 }) }, { 1, Q_REST } }), 0.62, 0.7)
	end
	local built = {}
	for name, fn in styles do built[name] = fn() end
	return {
		Name = "Quadruped", Idle = idle, Locomotion = walk, HitReaction = hit, Death = death, Fidgets = fidgets,
		IdleSeconds = 3.6, Swing = Q_SWING, Group = 22, Styles = built,
		ByShape = { ARC = "LungeBite", TARGET_DISC = "Pounce", SELF_DISC = "HowlStomp", PROJECTILE = "Spit" },
	}
end

-- ------------------------------------------------------------------ Avian
-- Common.pose for the body, head and legs, plus wings = { raise, fold, fwd } (L/R), foldL/R for the outer
-- wing, beak (+ open), fan (+ spread up).
local function bird(p: Spec): Pose
	local o = Common.pose(p :: any)
	local wl, wr = p.wingL or {}, p.wingR or {}
	o.ArmL = rot(wl.pitch or 0, wl.fold or 0, -(wl.raise or 0))
	o.ArmR = rot(wr.pitch or 0, -(wr.fold or 0), wr.raise or 0)
	o.ForearmL = rot(0, wl.tip or 0, -(wl.tipRaise or 0))
	o.ForearmR = rot(0, -(wr.tip or 0), wr.tipRaise or 0)
	o.ExtraBeak = rot(-(p.beak or 0), 0, 0)
	o.ExtraTailFan = rot(-(p.fan or 0), p.fanWag or 0, 0)
	return o
end
local function bkeys(list: { { any } }): { { any } }
	local out = {}
	for _, k in list do table.insert(out, { k[1], bird(k[2]) }) end
	return out
end
local function wings(raise: number, fold: number, tip: number, pitch: number?, tipRaise: number?): Spec
	local w = { raise = raise, fold = fold, tip = tip, pitch = pitch or 0, tipRaise = tipRaise or 0 }
	return { wingL = w, wingR = table.clone(w) }
end

local B_FOLD = wings(-25, 70, 60)
local B_REST: Spec = add(Common.crouch({ lean = 6, nod = -6 }, 0.15), B_FOLD)
local B_SWING = 20

local function avian()
	local idle = loop(bird, 8, function(ph)
		local s = sin(TAU * ph)
		-- folded and still, the head darting between three looks
		local look = ({ 0, -26, 18, -8, 24, 0, -18, 10 })[math.floor(ph * 8) % 8 + 1]
		return add(B_REST, {
			bob = 0.04 * s, lean = 1.5 * s,
			turn = look, nod = 4 * sin(TAU * ph * 4),
			fan = 4 + 3 * s,
		})
	end)
	local walk = loop(bird, 8, function(ph)
		local s, c = sin(TAU * ph), cos(TAU * ph)
		-- hop-walk: each step lifts the body, wings half open for balance, the head pumps
		return add(B_REST, add(wings(10 + 12 * math.abs(c), -30, -25), {
			lean = 4, bob = 0.14 * math.abs(s), nod = -8 * math.abs(c) + 4, tilt = 3 * s,
			legL = { fwd = B_SWING * s }, legR = { fwd = -B_SWING * s },
			kneeL = 30 * max(0, c), kneeR = 30 * max(0, -c),
			fan = 6,
		}))
	end)
	local function shot(list)
		local k = { { 0, B_REST } }
		for _, e in list do table.insert(k, { e[1], add(B_REST, e[2]) }) end
		table.insert(k, { 1, B_REST })
		return bkeys(k)
	end
	local fidgets = {
		-- ruffles: half-spreads and shakes its wings, fans its tail
		shot({ { 0.3, add(wings(35, -45, -40), { bob = 0.1, fan = 20 }) }, { 0.45, add(wings(20, -30, -30), { fan = 10 }) }, { 0.6, add(wings(35, -45, -40), { fan = 20 }) } }),
		-- preens: dips the head under a wing
		shot({ { 0.35, { nod = 40, turn = -55, wingL = { raise = 15, fold = -20 } } }, { 0.7, { nod = 38, turn = -60, wingL = { raise = 15, fold = -20 }, beak = 10 } } }),
	}
	local hit = bkeys({ { 0, {} }, { 0.2, add(wings(20, -25, -20), { lean = -10, nod = -15, bob = 0.05, beak = 15, fan = 10 }) }, { 1, {} } })
	local death = bkeys({
		{ 0, B_REST },
		{ 0.25, add(B_REST, add(wings(55, -70, -60), { lean = -20, nod = -30, beak = 30, bob = 0.15 })) },
		{ 0.6, add(wings(-10, -40, -30), { planted = false, lean = 30, tilt = 25, bob = -1.2, legL = { fwd = 40 }, legR = { fwd = 30 }, kneeL = 60, kneeR = 50, nod = 20 }) },
		{ 1, add(wings(-15, -50, -40), { planted = false, lean = 50, tilt = 70, bob = -2.1, slide = 0.3, legL = { fwd = 30 }, legR = { fwd = 50 }, kneeL = 40, kneeR = 60, nod = 10, beak = 15 }) },
	})
	local styles = {}
	function styles.Rake() -- ARC: wings up, leaps and rakes with its talons
		local wind = add(B_REST, add(wings(60, -50, -40), { lean = -14, nod = -15, bob = 0.15, beak = 25, fan = 25, legL = { fwd = 10 }, legR = { fwd = 10 }, kneeL = 20, kneeR = 20 }))
		local rake = add(B_REST, add(wings(-10, -40, -30), { planted = false, lean = -20, push = 0.5, bob = 0.35, nod = 20, legL = { fwd = 55 }, legR = { fwd = 45 }, kneeL = 10, kneeR = 25, beak = 10, fan = 20 }))
		return attack(bkeys({ { 0, B_REST }, { 0.55, wind }, { 0.72, add(wind, { bob = 0.05 }) }, { 0.8, rake }, { 0.88, add(rake, { lean = 6 }) }, { 1, B_REST } }), 0.72, 0.8)
	end
	function styles.Dive() -- TARGET_DISC: rises with a great wingbeat, then dives beak-first
		local rise = add(B_REST, add(wings(70, -60, -50), { lean = -18, bob = 0.6, nod = -20, legL = { fwd = 15 }, legR = { fwd = 15 }, kneeL = 40, kneeR = 40, beak = 20, fan = 30 }))
		local dive = add(B_REST, add(wings(-20, 10, 10, 20), { lean = 35, push = 1.0, bob = -0.2, nod = 25, beak = 30, fan = 10 }))
		return attack(bkeys({ { 0, B_REST }, { 0.5, rise }, { 0.74, add(rise, wings(10, 0, 0)) }, { 0.82, dive }, { 0.9, add(dive, { beak = -25, lean = -6 }) }, { 1, B_REST } }), 0.74, 0.82)
	end
	function styles.WingBuffet() -- SELF_DISC: spreads wide and beats both wings down around it
		local up = add(B_REST, add(wings(75, -65, -55, 0, 20), { lean = -12, bob = 0.3, nod = -25, beak = 35, fan = 35 }))
		local beat = add(B_REST, add(wings(-35, -70, -60, 0, -15), { lean = 14, bob = -0.2, nod = 10, beak = 20, fan = 15 }))
		return attack(bkeys({ { 0, B_REST }, { 0.55, up }, { 0.76, add(up, wings(5, 0, 0)) }, { 0.82, beat }, { 0.9, add(beat, wings(10, 0, 0)) }, { 1, B_REST } }), 0.76, 0.82)
	end
	function styles.WingFlick() -- PROJECTILE: cocks one wing back and flicks a bolt from it
		local wind = add(B_REST, { lean = -6, twist = 25, nod = -10, wingR = { raise = 55, fold = 40, tip = 30 }, fan = 15 })
		local flick = add(B_REST, { lean = 8, twist = -15, nod = 8, wingR = { raise = 15, fold = -70, tip = -50 }, beak = 20, fan = 10 })
		return attack(bkeys({ { 0, B_REST }, { 0.5, wind }, { 0.62, add(wind, { twist = 5 }) }, { 0.7, flick }, { 0.85, add(flick, { twist = 5 }) }, { 1, B_REST } }), 0.62, 0.7)
	end
	function styles.Cry() -- support aura: head thrown back, wings held wide, calling out
		local call = add(B_REST, add(wings(45, -60, -50), { lean = -12, nod = -40, beak = 40, fan = 30, bob = 0.1 }))
		return attack(bkeys({ { 0, B_REST }, { 0.45, call }, { 0.6, add(call, { nod = -5, beak = 5 }) }, { 0.7, call }, { 0.85, add(call, { beak = -20 }) }, { 1, B_REST } }), 0.45, 0.6)
	end
	local awakening = bkeys({
		-- crouched, head tucked and wings wrapped; unfolds, rises and screeches with wings spread
		{ 0, add(Common.crouch({ lean = 25, nod = 45 }, 0.6), add(wings(-30, 85, 70), { fan = -5 })) },
		{ 0.4, add(Common.crouch({ lean = 10, nod = 10 }, 0.3), add(wings(10, 20, 20), { fan = 10 })) },
		{ 0.7, add(B_REST, add(wings(65, -70, -60, 0, 15), { lean = -16, bob = 0.3, nod = -38, beak = 45, fan = 40 })) },
		{ 0.85, add(B_REST, add(wings(55, -60, -50, 0, 10), { lean = -12, bob = 0.2, nod = -30, beak = 30, fan = 30 })) },
		{ 1, B_REST },
	})
	local built = {}
	for name, fn in styles do built[name] = fn() end
	return {
		Name = "Avian", Idle = idle, Locomotion = walk, HitReaction = hit, Death = death, Fidgets = fidgets, Awakening = awakening,
		IdleSeconds = 3.2, Swing = B_SWING, Group = 24, Styles = built,
		ByShape = { ARC = "Rake", TARGET_DISC = "Dive", SELF_DISC = "WingBuffet", PROJECTILE = "WingFlick", ALLY_AURA = "Cry" },
	}
end

-- ------------------------------------------------------------------ Serpent
-- The Leviathan's Body is its raised neck and trunk; its coils chain Body > LegR > KneeR and Body > LegL >
-- KneeL > ExtraTail1 > ExtraTail2 along the floor, and its arms are fins. fields: lean twist tilt bob push
-- nod turn; wave = { amp, phase } runs an S-wave down the coils; lift raises the coils' ends; finL/finR
-- (+ up); jaw (+ open); frill (+ flared).
local COILS = { "LegR", "KneeR", "LegL", "KneeL", "ExtraTail1", "ExtraTail2" }
local function serpent(p: Spec): Pose
	local o: Pose = {
		Body = body(p),
		Head = rot(-(p.nod or 0), -(p.turn or 0), p.roll or 0),
		ArmL = rot(p.finFwd or 0, 0, -(p.finL or 0)), ArmR = rot(p.finFwd or 0, 0, p.finR or 0),
		ForearmL = rot(0, 0, -(p.finL or 0) * 0.5), ForearmR = rot(0, 0, (p.finR or 0) * 0.5),
		ExtraJaw = rot(-(p.jaw or 0), 0, 0),
		ExtraFrill = rot(p.frill or 0, 0, 0),
	}
	local w = p.wave or {}
	local amp, ph = w.amp or 0, w.phase or 0
	-- coils sit on the floor: undo the trunk's turn so they stay put, then wave about the vertical
	local counter = rot(0, p.twist or 0, 0)
	for i, name in COILS do
		local yaw = amp * sin(TAU * (ph - i * 0.17))
		local cf = rot(-(p.lift or 0) * (i / #COILS), yaw, 0)
		o[name] = if name == "LegR" or name == "LegL" then counter * cf else cf
	end
	return o
end
local function skeys(list: { { any } }): { { any } }
	local out = {}
	for _, k in list do table.insert(out, { k[1], serpent(k[2]) }) end
	return out
end
local S_REST: Spec = { nod = 6, finL = 10, finR = 10, frill = 5 }

local function serpentSet()
	local idle = loop(serpent, 8, function(ph)
		local s = sin(TAU * ph)
		return add(S_REST, {
			bob = 0.12 * s, lean = 3 * s, -- coils rise and fall
			twist = 6 * sin(TAU * ph), tilt = 4 * sin(TAU * (ph + 0.3)), turn = -10 * sin(TAU * (ph - 0.15)), roll = -5 * sin(TAU * ph), -- head weaves
			wave = { amp = 4, phase = ph }, finL = 8 * s, finR = 8 * s, frill = 6 * s, jaw = 3 + 3 * s,
		})
	end)
	local walk = loop(serpent, 8, function(ph)
		local s = sin(TAU * ph)
		return add(S_REST, {
			lean = 6, twist = 10 * s, tilt = 4 * s, turn = -12 * s, slide = 0.25 * s,
			wave = { amp = 16, phase = ph }, finL = 15 * sin(TAU * ph * 2), finR = 15 * sin(TAU * ph * 2), frill = -10,
		})
	end)
	local function shot(list)
		local k = { { 0, S_REST } }
		for _, e in list do table.insert(k, { e[1], add(S_REST, e[2]) }) end
		table.insert(k, { 1, S_REST })
		return skeys(k)
	end
	local fidgets = {
		shot({ { 0.35, { lean = -8, nod = -25, jaw = 35, frill = 35, finL = 30, finR = 30 } }, { 0.65, { lean = -6, nod = -20, jaw = 25, frill = 30 } } }), -- flares and hisses
		shot({ { 0.3, { twist = 25, turn = 20, wave = { amp = 10, phase = 0.25 } } }, { 0.7, { twist = -25, turn = -20, wave = { amp = 10, phase = 0.75 } } } }), -- turns to look about
	}
	local hit = skeys({ { 0, {} }, { 0.2, { lean = -10, push = -0.3, nod = -15, tilt = 6, jaw = 20, frill = 20 } }, { 1, {} } })
	local death = skeys({
		{ 0, S_REST },
		{ 0.25, add(S_REST, { lean = -22, nod = -35, jaw = 45, frill = 40, twist = 15, finL = 40, finR = 40, wave = { amp = 20, phase = 0.3 } }) },
		{ 0.6, add(S_REST, { lean = 30, tilt = 20, bob = -1.5, nod = 20, jaw = 20, finL = -10, finR = 30, wave = { amp = 12, phase = 0.6 } }) },
		{ 1, { lean = 75, tilt = 35, bob = -3.5, push = 1.2, nod = 10, jaw = 25, frill = -10, finL = -20, finR = -10, wave = { amp = 6, phase = 0.9 } } },
	})
	local styles = {}
	function styles.CoilBite() -- ARC: draws back into an S and strikes
		local wind = add(S_REST, { lean = -16, push = -0.8, nod = -20, twist = 20, jaw = 25, frill = 30, wave = { amp = 12, phase = 0.2 } })
		local strike = add(S_REST, { lean = 30, push = 1.4, nod = 15, twist = -20, jaw = 50, frill = 20, wave = { amp = 8, phase = 0.5 } })
		return attack(skeys({ { 0, S_REST }, { 0.55, wind }, { 0.72, add(wind, { lean = -4 }) }, { 0.8, strike }, { 0.86, add(strike, { jaw = -50 }) }, { 1, S_REST } }), 0.72, 0.8)
	end
	function styles.RearStrike() -- TARGET_DISC: rears tall, then crashes down on the target
		local rear = add(S_REST, { lean = -25, bob = 1.0, nod = -30, jaw = 45, frill = 45, finL = 40, finR = 40, lift = 6 })
		local crash = add(S_REST, { lean = 50, push = 1.8, bob = -1.0, nod = 20, jaw = 15, frill = 10, finL = -15, finR = -15 })
		return attack(skeys({ { 0, S_REST }, { 0.55, rear }, { 0.74, add(rear, { bob = 0.2 }) }, { 0.82, crash }, { 0.9, add(crash, { lean = -6 }) }, { 1, S_REST } }), 0.74, 0.82)
	end
	function styles.CoilSlam() -- SELF_DISC: lifts its tail coils and slams them down with a roar
		local up = add(S_REST, { lean = -14, bob = 0.6, nod = -30, jaw = 55, frill = 50, finL = 50, finR = 50, lift = 20, wave = { amp = 10, phase = 0.4 } })
		local slam = add(S_REST, { lean = 18, bob = -0.5, nod = 10, jaw = 20, frill = 15, finL = -10, finR = -10, lift = -4, wave = { amp = 6, phase = 0.6 } })
		return attack(skeys({ { 0, S_REST }, { 0.55, up }, { 0.76, add(up, { lift = 4 }) }, { 0.82, slam }, { 0.9, add(slam, { bob = 0.15 }) }, { 1, S_REST } }), 0.76, 0.82)
	end
	function styles.Spit() -- PROJECTILE: rears the head back and spits
		local wind = add(S_REST, { lean = -14, nod = -25, jaw = 15, frill = 35 })
		local spit = add(S_REST, { lean = 14, nod = 12, push = 0.6, jaw = 50, frill = 20 })
		return attack(skeys({ { 0, S_REST }, { 0.5, wind }, { 0.62, add(wind, { nod = -5 }) }, { 0.7, spit }, { 0.85, add(spit, { jaw = -30 }) }, { 1, S_REST } }), 0.62, 0.7)
	end
	local awakening = skeys({
		-- head down on its coils; uncoils upward and roars with the frill flared
		{ 0, { lean = 55, bob = -2.5, push = 0.8, nod = 25, frill = -15, finL = -15, finR = -15 } },
		{ 0.4, add(S_REST, { lean = 20, bob = -0.8, nod = 10, wave = { amp = 14, phase = 0.3 } }) },
		{ 0.7, add(S_REST, { lean = -18, bob = 0.6, nod = -40, jaw = 60, frill = 55, finL = 50, finR = 50, wave = { amp = 10, phase = 0.6 } }) },
		{ 0.85, add(S_REST, { lean = -12, bob = 0.4, nod = -32, jaw = 45, frill = 45, finL = 40, finR = 40 }) },
		{ 1, S_REST },
	})
	local built = {}
	for name, fn in styles do built[name] = fn() end
	return {
		Name = "Serpent", Idle = idle, Locomotion = walk, HitReaction = hit, Death = death, Fidgets = fidgets, Awakening = awakening,
		IdleSeconds = 4.8, Swing = nil, Group = nil, Styles = built,
		ByShape = { ARC = "CoilBite", TARGET_DISC = "RearStrike", SELF_DISC = "CoilSlam", PROJECTILE = "Spit" },
	}
end

-- ------------------------------------------------------------------ Multileg
-- Legs are named Leg<side>_<n> / Knee<side>_<n> with side -1 (left) or 1 (right) and n = 1 front to 3 rear.
-- fields: lean twist tilt bob push nod turn; legs[side][n] = { swing (+ forward), lift (+ up), knee }; jaw
-- (+ open); tail = { curl (+ over the back towards the front), wag }; sting; elytra (+ open); shell.
local function crawler(p: Spec): Pose
	local o: Pose = {
		Body = body(p),
		Head = rot(-(p.nod or 0), -(p.turn or 0), 0),
		JawL = rot(0, p.jaw or 0, 0), JawR = rot(0, -(p.jaw or 0), 0),
	}
	local legs = p.legs or {}
	local splay = p.splay or 0
	for _, side in { -1, 1 } do
		local sideLegs = legs[side] or {}
		for n = 1, 3 do
			local l = sideLegs[n] or {}
			-- left legs point -X: Rz(-) lifts, Ry(-) swings forward; the right side mirrors
			o["Leg" .. side .. "_" .. n] = rot(0, side * (l.swing or 0), side * ((l.lift or 0) + splay))
			o["Knee" .. side .. "_" .. n] = rot(0, 0, -side * (l.knee or 0))
		end
	end
	local t = p.tail or {}
	local curl, wag = t.curl or 0, t.wag or 0
	for i = 1, 4 do o["ExtraTail" .. i] = rot(-curl * (0.6 + i * 0.15), wag * (i == 1 and 1 or 0.4), 0) end
	o.ExtraSting = rot(-(p.sting or 0), 0, 0)
	local e = p.elytra or 0
	o.ExtraElytraL = rot(-e, -e * 0.6, 0)
	o.ExtraElytraR = rot(-e, e * 0.6, 0)
	o.ExtraShell = CFrame.new(0, p.shell or 0, 0) * rot(-(p.shell or 0) * 40, 0, 0)
	return o
end
local function mkeys(list: { { any } }): { { any } }
	local out = {}
	for _, k in list do table.insert(out, { k[1], crawler(k[2]) }) end
	return out
end
local function allLegs(swing: number, lift: number, knee: number): { [number]: { { [string]: number } } }
	local t = {}
	for _, side in { -1, 1 } do
		t[side] = {}
		for n = 1, 3 do t[side][n] = { swing = swing, lift = lift, knee = knee } end
	end
	return t
end
local M_REST: Spec = { jaw = 5, tail = { curl = 0 } }
local M_SWING = 18

local function multileg()
	local idle = loop(crawler, 12, function(ph)
		local s = sin(TAU * ph)
		-- mandibles twitch; the legs tap one at a time around the body
		local legs = allLegs(0, 0, 0)
		local tapAt = math.floor(ph * 6) % 6
		local tapPh = (ph * 6) % 1
		local side, n = if tapAt % 2 == 0 then -1 else 1, tapAt // 2 + 1
		legs[side][n] = { lift = 14 * sin(math.pi * tapPh), knee = -8 * sin(math.pi * tapPh) }
		return add(M_REST, {
			bob = 0.03 * s, lean = 1 * s, turn = 6 * sin(TAU * ph * 2),
			jaw = 6 + 10 * max(0, sin(TAU * ph * 3)) ^ 4,
			legs = legs,
			tail = { curl = 4 * s, wag = 6 * sin(TAU * ph) },
		})
	end)
	local walk = loop(crawler, 8, function(ph)
		local s, c = sin(TAU * ph), cos(TAU * ph)
		-- alternating tripod: front and rear on one side step with the middle on the other
		local legs = {}
		for _, side in { -1, 1 } do
			legs[side] = {}
			for n = 1, 3 do
				local sign = side * (if n == 2 then -1 else 1)
				legs[side][n] = { swing = M_SWING * s * sign, lift = 16 * max(0, c * sign), knee = -10 * max(0, c * sign) }
			end
		end
		return add(M_REST, {
			bob = 0.06 * math.abs(c), twist = 3 * s, tilt = 2 * c, nod = -2 * math.abs(c),
			legs = legs, jaw = 8, tail = { curl = 3, wag = 8 * s },
		})
	end)
	local function shot(list)
		local k = { { 0, M_REST } }
		for _, e in list do table.insert(k, { e[1], add(M_REST, e[2]) }) end
		table.insert(k, { 1, M_REST })
		return mkeys(k)
	end
	local fidgets = {
		shot({ { 0.3, { lean = -6, nod = -12, jaw = 25, legs = { [-1] = { { lift = 30, swing = 15 } }, [1] = { { lift = 30, swing = 15 } } } } }, { 0.6, { lean = -4, nod = -8, jaw = 5, legs = { [-1] = { { lift = 25, swing = 10 } }, [1] = { { lift = 25, swing = 10 } } } } } }), -- rears and tastes the air
		shot({ { 0.3, { twist = 25, turn = 10, tail = { wag = 20 } } }, { 0.65, { twist = -20, turn = -10, tail = { wag = -15 } } } }), -- swivels about
	}
	local hit = mkeys({ { 0, {} }, { 0.2, { lean = -8, bob = 0.05, push = -0.15, nod = -10, jaw = 20, tilt = 5, legs = allLegs(0, 10, 0) } }, { 1, {} } })
	local death = mkeys({
		{ 0, M_REST },
		{ 0.25, add(M_REST, { lean = -10, bob = 0.15, jaw = 35, legs = allLegs(0, 25, -10), tail = { curl = 20 } }) },
		{ 0.6, { bob = -0.3, tilt = 20, jaw = 30, legs = allLegs(0, 45, 30), tail = { curl = -10 } } },
		-- flipped over, legs curled
		{ 1, { bob = -0.25, tilt = 170, slide = 0.2, jaw = 25, legs = allLegs(5, 60, 70), tail = { curl = -20, wag = 10 }, elytra = 15 } },
	})
	local styles = {}
	function styles.Snap() -- ARC: rears with mandibles wide, lunges and snaps them shut
		local wind = add(M_REST, { lean = -10, push = -0.25, nod = -12, jaw = 40, legs = { [-1] = { { lift = 25, swing = 15 } }, [1] = { { lift = 25, swing = 15 } } }, elytra = 10 })
		local snap = add(M_REST, { lean = 10, push = 0.5, nod = 10, jaw = -8, legs = allLegs(-10, 0, 0) })
		return attack(mkeys({ { 0, M_REST }, { 0.55, wind }, { 0.72, add(wind, { jaw = 5 }) }, { 0.8, snap }, { 0.88, add(snap, { jaw = 15 }) }, { 1, M_REST } }), 0.72, 0.8)
	end
	function styles.Pinch() -- ARC (scorpions): pincers spread and slam shut, tail cocked over
		local wind = add(M_REST, { lean = -6, push = -0.2, jaw = 45, tail = { curl = 15 }, sting = 10, twist = 10 })
		local pinch = add(M_REST, { lean = 6, push = 0.45, jaw = -10, tail = { curl = 10 }, twist = -10, legs = allLegs(-8, 0, 0) })
		return attack(mkeys({ { 0, M_REST }, { 0.55, wind }, { 0.72, add(wind, { jaw = 5 }) }, { 0.8, pinch }, { 0.88, add(pinch, { jaw = 10 }) }, { 1, M_REST } }), 0.72, 0.8)
	end
	function styles.TailStab() -- TARGET_DISC (scorpions): draws the sting back over the body and stabs it forward
		local wind = add(M_REST, { lean = 6, bob = -0.1, jaw = 30, tail = { curl = -12 }, sting = -25, legs = allLegs(0, -5, 0) })
		local stab = add(M_REST, { lean = 10, push = 0.4, jaw = 15, tail = { curl = 35 }, sting = 40 })
		return attack(mkeys({ { 0, M_REST }, { 0.55, wind }, { 0.74, add(wind, { tail = { curl = -4 } }) }, { 0.82, stab }, { 0.9, add(stab, { tail = { curl = -8 } }) }, { 1, M_REST } }), 0.74, 0.82)
	end
	function styles.Leap() -- TARGET_DISC: crouches, springs at the target with its legs flung forward
		local crouch = add(M_REST, { bob = -0.2, lean = 6, jaw = 30, legs = allLegs(0, -12, -15), elytra = 15, shell = 0.1 })
		local land = add(M_REST, { bob = 0.15, push = 0.9, lean = -6, jaw = -5, legs = allLegs(15, 25, 10), elytra = 35, shell = 0.25 })
		return attack(mkeys({ { 0, M_REST }, { 0.55, crouch }, { 0.74, add(crouch, { bob = -0.05 }) }, { 0.82, land }, { 0.9, add(land, { bob = -0.2, legs = allLegs(-15, -30, -10) }) }, { 1, M_REST } }), 0.74, 0.82)
	end
	function styles.Drum() -- SELF_DISC: rears on its back legs and drums its forelegs into the floor
		local front = function(lift: number, swing: number) return { [-1] = { { lift = lift, swing = swing }, { lift = lift * 0.6, swing = swing } }, [1] = { { lift = lift, swing = swing }, { lift = lift * 0.6, swing = swing } } } end
		local rear = add(M_REST, { lean = -18, bob = 0.3, jaw = 40, legs = front(45, 20), tail = { curl = 20 }, elytra = 25, shell = 0.2 })
		local drum = add(M_REST, { lean = 10, bob = -0.15, jaw = 10, legs = front(-15, 10), tail = { curl = 5 } })
		return attack(mkeys({ { 0, M_REST }, { 0.55, rear }, { 0.76, add(rear, { bob = 0.05 }) }, { 0.82, drum }, { 0.88, add(drum, { lean = -8, legs = front(25, 0) }) }, { 0.93, drum }, { 1, M_REST } }), 0.76, 0.82)
	end
	function styles.Spit() -- PROJECTILE
		local wind = add(M_REST, { lean = -12, nod = -10, jaw = 35, push = -0.15 })
		local spit = add(M_REST, { lean = 8, nod = 8, jaw = 45, push = 0.3 })
		return attack(mkeys({ { 0, M_REST }, { 0.5, wind }, { 0.62, add(wind, { jaw = 5 }) }, { 0.7, spit }, { 0.85, add(spit, { jaw = -30 }) }, { 1, M_REST } }), 0.62, 0.7)
	end
	local built = {}
	for name, fn in styles do built[name] = fn() end
	return {
		Name = "Multileg", Idle = idle, Locomotion = walk, HitReaction = hit, Death = death, Fidgets = fidgets,
		IdleSeconds = 2.8, Swing = M_SWING, Group = 18, Styles = built,
		ByShape = { ARC = "Snap", TARGET_DISC = "Leap", SELF_DISC = "Drum", PROJECTILE = "Spit" },
	}
end

-- ------------------------------------------------------------------ sets
local BUILDERS = { Quadruped = quadruped, Avian = avian, Serpent = serpentSet, Multileg = multileg }
local cache: { [string]: any } = {}

function Creatures.Set(name: string): any
	local s = cache[name]
	if not s then
		s = BUILDERS[name]()
		-- stride against the group's reference swing (EnemyAnimator.STRIDE); the serpent glides
		s.StrideScale = if s.Swing then sin(math.rad(s.Swing)) / sin(math.rad(s.Group)) else 1
		cache[name] = s
	end
	return s
end

-- Per-family and per-enemy style picks that differ from the set's shape table.
local FAMILY_SHAPE: { [string]: { [string]: string } } = {
	SCORPION = { ARC = "Pinch", TARGET_DISC = "TailStab" },
}
local OVERRIDES: { [string]: { [string]: string } } = {
	alpha_thunder_ram = { ARC = "Butt" }, elite_thunder_ram = { ARC = "Butt" },
}

function Creatures.StyleFor(setName: string, family: string, enemyId: string, shape: string): string
	local set = Creatures.Set(setName)
	local o = OVERRIDES[enemyId]
	if o and o[shape] then return o[shape] end
	local f = FAMILY_SHAPE[family]
	if f and f[shape] then return f[shape] end
	return set.ByShape[shape] or set.ByShape.ARC
end

return Creatures
