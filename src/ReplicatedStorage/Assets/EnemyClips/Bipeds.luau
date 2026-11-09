--!strict
-- Biped motion sets (docs/mob-reanimation-plan.md §3.2, step 5): LightBiped, WarriorBiped, HeavyBiped and
-- Rooted. Each set has a rest stance, an idle loop, a walk loop, two fidgets, a death and its attack styles
-- (§3.3), all built from Common.pose so the signs read as what you see. Clips are built once per set and
-- shared by every enemy in it.
local Common = require(game.ReplicatedStorage.Assets.EnemyClips.Common)

local pose, with, crouch, rot = Common.pose, Common.with, Common.crouch, Common.rot
local keys, attack, loop = Common.keys, Common.attack, Common.loop
local TAU = 2 * math.pi

local Bipeds = {}

-- Families -> set (CatalogFamily or RigFamily from FirstBiomeCombat).
Bipeds.FamilySet = {
	SMALL_BIPED = "LightBiped", CASTER_BIPED = "LightBiped", FUNGAL_BIPED = "LightBiped",
	WEAPON_BIPED = "WarriorBiped", ARMORED_BIPED = "WarriorBiped", ROYAL_BIPED = "WarriorBiped",
	HEAVY_BIPED = "HeavyBiped",
	ROOTED_BIPED = "Rooted", TREANT = "Rooted",
}

type Walk = { swing: number, knee: number, bob: number, arm: number, twist: number, tilt: number, lean: number }
type SetDef = { Rest: Common.PoseSpec, Drop: number, IdleSeconds: number, Breath: number, Walk: Walk }

local DEFS: { [string]: SetDef } = {
	-- light, quick, hands busy
	LightBiped = {
		Rest = { lean = 4, armL = { fwd = 10, out = 10 }, armR = { fwd = 10, out = 10 }, foreL = 30, foreR = 30 },
		Drop = 0.05, IdleSeconds = 2.6, Breath = 0.05,
		Walk = { swing = 26, knee = 42, bob = 0.09, arm = 26, twist = 6, tilt = 2, lean = 6 },
	},
	-- guarded: weapon arm (right) held ready, off arm (left) up as a shield
	WarriorBiped = {
		Rest = { lean = 3, armR = { fwd = 28, out = 8 }, foreR = 50, armL = { fwd = 22, out = 12 }, foreL = 62 },
		Drop = 0.12, IdleSeconds = 3.4, Breath = 0.04,
		Walk = { swing = 22, knee = 36, bob = 0.06, arm = 8, twist = 5, tilt = 2.5, lean = 5 },
	},
	-- hunched brute, knuckles low
	HeavyBiped = {
		Rest = { lean = 13, nod = -9, armL = { fwd = 14, out = 20 }, armR = { fwd = 14, out = 20 }, foreL = 22, foreR = 22 },
		Drop = 0.22, IdleSeconds = 4.2, Breath = 0.06,
		Walk = { swing = 18, knee = 30, bob = 0.1, arm = 16, twist = 9, tilt = 6, lean = 6 },
	},
	-- creaking, plant-like: shuffle and sway
	Rooted = {
		Rest = { lean = 3, armL = { fwd = 6, out = 14 }, armR = { fwd = 6, out = 14 }, foreL = 18, foreR = 18 },
		Drop = 0.04, IdleSeconds = 4.6, Breath = 0.03,
		Walk = { swing = 12, knee = 14, bob = 0.03, arm = 10, twist = 3, tilt = 7, lean = 5 },
	},
}

-- The stance every clip of a set starts and ends on.
local function restOf(def: SetDef): Common.PoseSpec
	return crouch(def.Rest, def.Drop)
end

local function add(base: Common.PoseSpec, delta: Common.PoseSpec): Common.PoseSpec
	-- Add numeric fields of delta onto base (limbs field by field); extras pass through.
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

-- ------------------------------------------------------------------ loops
local function idleClip(name: string, def: SetDef)
	local rest = restOf(def)
	return loop(8, function(phase)
		local s, c = math.sin(TAU * phase), math.cos(TAU * phase)
		local d: Common.PoseSpec = {
			bob = def.Breath * s, lean = 1.2 * s, nod = -1.5 * s,
			armL = { fwd = 2.5 * s, out = 1.5 * s }, armR = { fwd = 2.5 * s, out = 1.5 * s },
		}
		if name == "HeavyBiped" then
			d.twist = 2.5 * c -- shoulders roll
			d.tilt = 1.5 * s
		elseif name == "Rooted" then
			d.tilt = 3.5 * s -- sways like a branch, head lagging behind
			d.turn = 3 * math.sin(TAU * (phase - 0.15))
			d.lean = 2 * c
		elseif name == "LightBiped" then
			d.armL = { fwd = 4 * c, out = 3 * s } -- hands drift
			d.armR = { fwd = -4 * c, out = 3 * s }
		else
			d.tilt = 1.2 * c -- weight shifts foot to foot
		end
		return add(rest, d)
	end)
end

local function walkClip(def: SetDef)
	local rest = restOf(def)
	local w = def.Walk
	return loop(8, function(phase)
		local s, c = math.sin(TAU * phase), math.cos(TAU * phase)
		-- left leg forward at phase 0.25; each leg is lifted (knee bent) while it swings forward
		return add(rest, {
			lean = w.lean,
			bob = w.bob * (math.abs(c) - 0.5),
			twist = w.twist * s, turn = -w.twist * 0.5 * s,
			tilt = w.tilt * c,
			legL = { fwd = w.swing * s }, legR = { fwd = -w.swing * s },
			kneeL = w.knee * math.max(0, c), kneeR = w.knee * math.max(0, -c),
			armL = { fwd = -w.arm * s }, armR = { fwd = w.arm * s },
		})
	end)
end

-- ------------------------------------------------------------------ fidgets (played every 6–14 s while idle)
local function fidgets(name: string, def: SetDef)
	local R = restOf(def)
	local function shot(list: { { any } })
		local k = { { 0, R } }
		for _, e in list do table.insert(k, { e[1], add(R, e[2]) }) end
		table.insert(k, { 1, R })
		return keys(k)
	end
	if name == "WarriorBiped" then
		return {
			shot({ { 0.3, { armR = { fwd = 40, out = 15 }, foreR = 30, twist = 12, turn = 15 } }, { 0.6, { armR = { fwd = 25, out = -10 }, foreR = -20, twist = -6, turn = 10 } } }), -- tests the weapon
			shot({ { 0.35, { tilt = 6, slide = 0.12, turn = -20 } }, { 0.7, { tilt = -4, slide = -0.08, turn = 18 } } }), -- shifts weight, looks round
		}
	elseif name == "HeavyBiped" then
		return {
			shot({ { 0.3, { turn = 22, nod = 10 } }, { 0.55, { turn = -22, nod = 10 } }, { 0.75, { nod = -6 } } }), -- cracks its neck
			shot({ { 0.35, { twist = 14, armL = { fwd = 20, out = 15 }, armR = { fwd = -10 }, lean = 4 } }, { 0.7, { twist = -10, lean = -3 } } }), -- rolls its shoulders
		}
	elseif name == "Rooted" then
		return {
			shot({ { 0.4, { tilt = 10, turn = -10 } }, { 0.75, { tilt = -7, turn = 8 } } }), -- creaks side to side
			shot({ { 0.45, { lean = -10, armL = { fwd = 70, out = 25 }, armR = { fwd = 70, out = 25 }, nod = -15 } } }), -- stretches up
		}
	end
	return {
		shot({ { 0.3, { turn = 35, nod = -5 } }, { 0.65, { turn = -30, nod = 5 } } }), -- glances round
		shot({ { 0.4, { armL = { fwd = 25, out = 20 }, armR = { fwd = 25, out = 20 }, foreL = 20, foreR = 20, bob = 0.06 } } }), -- shrugs
	}
end

-- ------------------------------------------------------------------ deaths (planted = false: the body falls)
local function deathClip(name: string, def: SetDef)
	local R = restOf(def)
	if name == "LightBiped" then -- crumples forward onto its face
		return keys({
			{ 0, R },
			{ 0.25, crouch(with(R, { lean = 16, nod = 12, armL = { fwd = -15, out = 15 }, armR = { fwd = -15, out = 15 } }), 0.5) },
			{ 0.6, { planted = false, lean = 50, bob = -1.7, legL = { fwd = -10 }, legR = { fwd = -20 }, kneeL = 70, kneeR = 60, armL = { fwd = 40, out = 20 }, armR = { fwd = 40, out = 20 } } },
			{ 1, { planted = false, lean = 84, bob = -3.0, nod = 15, armL = { fwd = 60, out = 30 }, armR = { fwd = 55, out = 20 }, kneeL = 15, kneeR = 25 } },
		})
	elseif name == "HeavyBiped" then -- drops to its knees, then falls forward
		return keys({
			{ 0, R },
			{ 0.35, { planted = false, lean = 15, bob = -1.4, legL = { fwd = 75 }, legR = { fwd = 70 }, kneeL = 110, kneeR = 105, armL = { fwd = 5, out = 25 }, armR = { fwd = 5, out = 25 }, nod = 20 } },
			{ 0.55, { planted = false, lean = 30, bob = -1.6, legL = { fwd = 70 }, legR = { fwd = 70 }, kneeL = 110, kneeR = 110, armL = { fwd = 20, out = 25 }, armR = { fwd = 20, out = 25 }, nod = 25 } },
			{ 1, { planted = false, lean = 86, bob = -2.9, legL = { fwd = -5 }, legR = { fwd = 5 }, kneeL = 20, kneeR = 10, armL = { fwd = 30, out = 45 }, armR = { fwd = 25, out = 40 }, nod = 10 } },
		})
	elseif name == "Rooted" then -- wilts slowly over onto its side
		return keys({
			{ 0, R },
			{ 0.4, with(R, { tilt = 18, lean = 10, bob = -0.3, nod = 20, armL = { fwd = -5, out = 5 }, armR = { fwd = -5, out = 30 } }) },
			{ 1, { planted = false, tilt = 84, lean = 6, bob = -2.9, nod = 15, armL = { fwd = 10, out = 60 }, armR = { fwd = 20, out = 10 }, kneeL = 20, kneeR = 30 } },
		})
	end
	-- WarriorBiped: buckles, then topples onto its back
	return keys({
		{ 0, R },
		{ 0.2, crouch(with(R, { lean = -10, nod = -20, armL = { fwd = -10, out = 30 }, armR = { fwd = -10, out = 30 } }), 0.3) },
		{ 0.55, { planted = false, lean = -55, bob = -1.8, legL = { fwd = 40 }, legR = { fwd = 30 }, kneeL = 35, kneeR = 25, armL = { fwd = 20, out = 50 }, armR = { fwd = 20, out = 50 }, nod = -15 } },
		{ 1, { planted = false, lean = -86, bob = -3.0, legL = { fwd = 5 }, legR = { fwd = -5 }, kneeL = 10, kneeR = 15, armL = { fwd = -20, out = 70 }, armR = { fwd = -10, out = 65 }, nod = -10 } },
	})
end

-- ------------------------------------------------------------------ attack styles
-- Each returns frames with Release/Impact markers. R is the set's rest stance.
local Styles = {}

function Styles.Slash(R: Common.PoseSpec)
	local wind = add(R, { twist = 30, lean = -6, armR = { fwd = 100, out = 40 }, foreR = 10, armL = { fwd = 10, out = 15 } })
	return attack({
		{ 0, R },
		{ 0.45, wind },
		{ 0.72, add(wind, { twist = 6, armR = { fwd = 20 } }) },
		{ 0.8, crouch(add(R, { twist = -35, lean = 12, push = 0.25, armR = { fwd = 15, out = -45 }, foreR = -40, armL = { fwd = -10, out = 10 } }), 0.15) },
		{ 0.9, crouch(add(R, { twist = -40, lean = 10, push = 0.25, armR = { fwd = 0, out = -50 }, foreR = -45 }), 0.12) },
		{ 1, R },
	}, 0.72, 0.8)
end

function Styles.Thrust(R: Common.PoseSpec)
	local wind = add(R, { twist = 20, lean = -5, armR = { fwd = -45, out = 10 }, foreR = 50 })
	return attack({
		{ 0, R },
		{ 0.5, wind },
		{ 0.7, add(wind, { twist = 5, armR = { fwd = -5 } }) },
		{ 0.8, crouch(add(R, { twist = -15, lean = 15, push = 0.55, armR = { fwd = 55 }, foreR = -50, legR = { fwd = -15 }, legL = { fwd = 15 } }), 0.2) },
		{ 0.9, crouch(add(R, { twist = -12, lean = 12, push = 0.5, armR = { fwd = 50 }, foreR = -48 }), 0.18) },
		{ 1, R },
	}, 0.7, 0.8)
end

function Styles.Overhead(R: Common.PoseSpec)
	local wind = add(R, { lean = -11, bob = 0.15, armL = { fwd = 140, out = -2 }, armR = { fwd = 135, out = -2 }, foreL = -30, foreR = -20, nod = -10 })
	return attack({
		{ 0, R },
		{ 0.55, wind },
		{ 0.74, add(wind, { lean = -3, armL = { fwd = 10 }, armR = { fwd = 10 } }) },
		{ 0.82, crouch(add(R, { lean = 26, push = 0.45, nod = 12, armL = { fwd = 30, out = -10 }, armR = { fwd = 30, out = -10 }, foreL = -20, foreR = -20 }), 0.35) },
		{ 0.92, crouch(add(R, { lean = 22, push = 0.45, nod = 10, armL = { fwd = 25 }, armR = { fwd = 25 } }), 0.32) },
		{ 1, R },
	}, 0.74, 0.82)
end

function Styles.Chop(R: Common.PoseSpec)
	local wind = add(R, { lean = -9, twist = 12, armR = { fwd = 145, out = 10 }, foreR = -10, armL = { fwd = 15, out = 20 } })
	return attack({
		{ 0, R },
		{ 0.55, wind },
		{ 0.74, add(wind, { armR = { fwd = 12 }, lean = -3 }) },
		{ 0.82, crouch(add(R, { lean = 24, twist = -6, push = 0.35, armR = { fwd = 35, out = -10 }, foreR = -25 }), 0.3) },
		{ 0.92, crouch(add(R, { lean = 20, push = 0.35, armR = { fwd = 28 } }), 0.27) },
		{ 1, R },
	}, 0.74, 0.82)
end

function Styles.Stomp(R: Common.PoseSpec)
	local lift = add(R, { lean = -6, tilt = -7, bob = 0.12, legR = { fwd = 55 }, kneeR = 75, armL = { fwd = 15, out = 45 }, armR = { fwd = 15, out = 45 } })
	return attack({
		{ 0, R },
		{ 0.55, lift },
		{ 0.76, add(lift, { legR = { fwd = 8 }, bob = 0.04 }) },
		{ 0.82, crouch(add(R, { lean = 12, tilt = 2, legR = { fwd = 8 }, kneeR = 5, armL = { fwd = 5, out = 30 }, armR = { fwd = 5, out = 30 } }), 0.4) },
		{ 0.92, crouch(add(R, { lean = 9, armL = { out = 25 }, armR = { out = 25 } }), 0.32) },
		{ 1, R },
	}, 0.76, 0.82)
end

function Styles.Pound(R: Common.PoseSpec)
	local wind = add(R, { lean = -12, bob = 0.12, armL = { fwd = 150, out = 10 }, armR = { fwd = 150, out = 10 }, foreL = -40, foreR = -40, nod = -12 })
	return attack({
		{ 0, R },
		{ 0.55, wind },
		{ 0.74, add(wind, { armL = { fwd = 8 }, armR = { fwd = 8 } }) },
		{ 0.82, crouch(add(R, { lean = 34, push = 0.3, nod = 14, armL = { fwd = 55, out = -5 }, armR = { fwd = 55, out = -5 }, foreL = -20, foreR = -20 }), 0.5) },
		{ 0.92, crouch(add(R, { lean = 30, push = 0.3, nod = 12, armL = { fwd = 50 }, armR = { fwd = 50 } }), 0.46) },
		{ 1, R },
	}, 0.74, 0.82)
end

function Styles.Backhand(R: Common.PoseSpec, chain: boolean?)
	local wind = add(R, { twist = 40, lean = 4, armR = { fwd = 30, out = 70 }, foreR = 10, armL = { fwd = 30, out = -15 } })
	local hit = crouch(add(R, { twist = -45, lean = 16, push = 0.3, armR = { fwd = 55, out = -45 }, foreR = -10, armL = { fwd = -10, out = 25 } }), 0.25)
	if chain then -- the chain trails the swing, then whips round past it
		wind = with(wind, { extra = { ExtraChain1 = rot(10, 0, 40), ExtraChain2 = rot(0, 0, 25), ExtraChain3 = rot(0, 0, 15) } })
		hit = with(hit, { extra = { ExtraChain1 = rot(-10, 0, -50), ExtraChain2 = rot(0, 0, -35), ExtraChain3 = rot(0, 0, -25) } })
	end
	local rest = if chain then with(R, { extra = { ExtraChain1 = CFrame.identity, ExtraChain2 = CFrame.identity, ExtraChain3 = CFrame.identity } }) else R
	return attack({
		{ 0, rest },
		{ 0.5, wind },
		{ 0.74, add(wind, { twist = 6 }) },
		{ 0.82, hit },
		{ 0.92, add(hit, { twist = -5 }) },
		{ 1, rest },
	}, 0.74, 0.82)
end

function Styles.Whip(R: Common.PoseSpec)
	local function whip(a: number, b: number, c: number)
		return { ExtraWhip1 = rot(a, 0, 0), ExtraWhip2 = rot(b, 0, 0), ExtraWhip3 = rot(c, 0, 0) }
	end
	local rest = with(R, { extra = whip(0, 0, 0) })
	local wind = add(R, { twist = 22, lean = -6, armR = { fwd = 120, out = 30 }, foreR = 0, extra = whip(-70, -45, -30) })
	return attack({
		{ 0, rest },
		{ 0.5, wind },
		{ 0.72, with(add(wind, { armR = { fwd = 15 } }), { extra = whip(-85, -55, -40) }) },
		{ 0.8, crouch(add(R, { twist = -25, lean = 14, push = 0.2, armR = { fwd = 35, out = -10 }, foreR = -20, extra = whip(30, 40, 35) }), 0.15) },
		{ 0.88, crouch(add(R, { twist = -22, lean = 11, push = 0.2, armR = { fwd = 30 }, extra = whip(55, 65, 55) }), 0.12) },
		{ 1, rest },
	}, 0.72, 0.8)
end

function Styles.Piston(R: Common.PoseSpec)
	-- the Forge Construct's chop, with its piston firing the hammer head as it lands
	local function piston(d: number) return { ExtraPiston = CFrame.new(0, -d, 0) } end
	local rest = with(R, { extra = piston(0) })
	local wind = add(R, { lean = -8, twist = 10, armR = { fwd = 140, out = 10 }, foreR = -10, extra = piston(0) })
	return attack({
		{ 0, rest },
		{ 0.55, wind },
		{ 0.74, add(wind, { armR = { fwd = 10 } }) },
		{ 0.8, crouch(add(R, { lean = 22, twist = -6, push = 0.3, armR = { fwd = 35, out = -10 }, foreR = -25, extra = piston(0.15) }), 0.28) },
		{ 0.85, crouch(add(R, { lean = 22, push = 0.3, armR = { fwd = 33 }, foreR = -25, extra = piston(0.6) }), 0.28) },
		{ 0.94, crouch(add(R, { lean = 18, push = 0.3, armR = { fwd = 28 }, extra = piston(0.1) }), 0.24) },
		{ 1, rest },
	}, 0.74, 0.8)
end

function Styles.Bolt(R: Common.PoseSpec)
	local gather = add(R, { lean = -6, bob = 0.05, armL = { fwd = 45, out = -18 }, armR = { fwd = 45, out = -18 }, foreL = 60, foreR = 60 })
	return attack({
		{ 0, R },
		{ 0.5, gather },
		{ 0.62, add(gather, { lean = -2, armL = { fwd = 8 }, armR = { fwd = 8 } }) },
		{ 0.68, add(R, { lean = 12, push = 0.2, armL = { fwd = 75, out = -12 }, armR = { fwd = 75, out = -12 }, foreL = -25, foreR = -25 }) },
		{ 0.85, add(R, { lean = 8, push = 0.15, armL = { fwd = 60 }, armR = { fwd = 60 }, foreL = -15, foreR = -15 }) },
		{ 1, R },
	}, 0.62, 0.68)
end

function Styles.Throw(R: Common.PoseSpec)
	local wind = add(R, { twist = 32, lean = -8, armR = { fwd = -55, out = 25 }, foreR = 40, armL = { fwd = 45, out = 5 } })
	return attack({
		{ 0, R },
		{ 0.5, wind },
		{ 0.62, add(wind, { twist = 6, armR = { fwd = -10 } }) },
		{ 0.7, crouch(add(R, { twist = -28, lean = 15, push = 0.25, armR = { fwd = 100, out = -10 }, foreR = -40, armL = { fwd = -15 } }), 0.15) },
		{ 0.85, crouch(add(R, { twist = -20, lean = 10, push = 0.2, armR = { fwd = 50, out = -15 }, foreR = -20 }), 0.1) },
		{ 1, R },
	}, 0.62, 0.7)
end

function Styles.Channel(R: Common.PoseSpec, bellows: boolean?)
	local up = add(R, { lean = -6, bob = 0.12, nod = -18, armL = { fwd = 95, out = 30 }, armR = { fwd = 95, out = 30 }, foreL = -20, foreR = -20 })
	local function pump(a: number): Common.PoseSpec
		return if bellows then { extra = { ExtraBellows = rot(a, 0, 0) } } else {}
	end
	return attack({
		{ 0, with(R, pump(0)) },
		{ 0.25, with(up, pump(14)) },
		{ 0.4, with(add(up, { armL = { fwd = 8, out = 6 }, armR = { fwd = 8, out = 6 }, bob = 0.03 }), pump(-6)) },
		{ 0.55, with(up, pump(14)) },
		{ 0.7, with(add(up, { armL = { fwd = 8, out = 6 }, armR = { fwd = 8, out = 6 }, bob = 0.03 }), pump(-6)) },
		{ 0.78, with(up, pump(12)) },
		{ 0.86, with(add(up, { armL = { fwd = 20, out = 15 }, armR = { fwd = 20, out = 15 }, bob = 0.06, nod = -6 }), pump(-10)) },
		{ 1, with(R, pump(0)) },
	}, 0.78, 0.86)
end

function Styles.RootBurst(R: Common.PoseSpec)
	local wind = add(R, { lean = -9, bob = 0.06, armL = { fwd = 140, out = 20 }, armR = { fwd = 140, out = 20 }, foreL = -15, foreR = -15, nod = -15 })
	return attack({
		{ 0, R },
		{ 0.55, wind },
		{ 0.74, add(wind, { armL = { fwd = 10 }, armR = { fwd = 10 } }) },
		{ 0.82, crouch(add(R, { lean = 40, nod = 15, armL = { fwd = 15, out = 5 }, armR = { fwd = 15, out = 5 }, foreL = -10, foreR = -10 }), 0.45) },
		{ 0.94, crouch(add(R, { lean = 35, nod = 12, armL = { fwd = 12 }, armR = { fwd = 12 } }), 0.4) },
		{ 1, R },
	}, 0.74, 0.82)
end

function Styles.Uproot(R: Common.PoseSpec)
	local heave = add(R, { lean = -8, bob = 0.25, armL = { fwd = 100, out = 55 }, armR = { fwd = 100, out = 55 }, nod = -20 })
	return attack({
		{ 0, R },
		{ 0.55, heave },
		{ 0.74, add(heave, { bob = 0.06 }) },
		{ 0.82, crouch(add(R, { lean = 10, armL = { fwd = 5, out = 70 }, armR = { fwd = 5, out = 70 }, nod = 10 }), 0.5) },
		{ 0.92, crouch(add(R, { lean = 8, armL = { out = 60 }, armR = { out = 60 } }), 0.42) },
		{ 1, R },
	}, 0.74, 0.82)
end

-- Which style plays a move: by set and shape, then per-enemy overrides.
local BY_SHAPE: { [string]: { [string]: string } } = {
	LightBiped = { ARC = "Slash", TARGET_DISC = "Overhead", SELF_DISC = "Stomp", PROJECTILE = "Bolt", ALLY_BEAM = "Channel", ALLY_AURA = "Channel" },
	WarriorBiped = { ARC = "Slash", TARGET_DISC = "Overhead", SELF_DISC = "Stomp", PROJECTILE = "Throw", ALLY_BEAM = "Channel", ALLY_AURA = "Channel" },
	HeavyBiped = { ARC = "Backhand", TARGET_DISC = "Pound", SELF_DISC = "Stomp", PROJECTILE = "Throw", ALLY_BEAM = "Channel", ALLY_AURA = "Channel" },
	Rooted = { ARC = "Whip", TARGET_DISC = "RootBurst", SELF_DISC = "Uproot", PROJECTILE = "Throw", ALLY_BEAM = "Channel", ALLY_AURA = "Channel" },
}
-- "<enemyId>" or "<enemyId>:<shape>" -> style. Alphas share their Elite's overrides.
local OVERRIDES: { [string]: string } = {
	mob_rime_sentry = "Thrust", -- spear
	mob_forge_construct = "Piston", -- piston hammer
	mob_cinder_imp = "Slash",
	["mob_bellows_imp:ALLY_AURA"] = "ChannelBellows",
	["mob_bellows_imp:PROJECTILE"] = "Throw",
	["mob_sporecap_chanter:PROJECTILE"] = "Throw", -- flings spores from the censer hand
	["elite_throne_executioner:ARC"] = "Chop", -- the axe
	["elite_molten_taskmaster:ARC"] = "ChainLash",
}

-- ------------------------------------------------------------------ built sets
export type BuiltSet = {
	Name: string, Rest: Common.PoseSpec, Idle: any, Locomotion: any, HitReaction: any, Death: any,
	Fidgets: { any }, IdleSeconds: number, StrideScale: number, Styles: { [string]: any },
}
local built: { [string]: BuiltSet } = {}

function Bipeds.Set(name: string): BuiltSet
	local b = built[name]
	if b then return b end
	local def = assert(DEFS[name], "unknown biped set " .. name)
	local R = restOf(def)
	local styles = {}
	for _, style in { "Slash", "Thrust", "Overhead", "Chop", "Stomp", "Pound", "Backhand", "Whip", "Piston", "Bolt", "Throw", "Channel", "RootBurst", "Uproot" } do
		styles[style] = (Styles :: any)[style](R)
	end
	styles.ChainLash = Styles.Backhand(R, true)
	styles.ChannelBellows = Styles.Channel(R, true)
	b = {
		Name = name, Rest = R,
		Idle = idleClip(name, def), Locomotion = walkClip(def), HitReaction = Common.Hit, Death = deathClip(name, def),
		Fidgets = fidgets(name, def), IdleSeconds = def.IdleSeconds,
		StrideScale = math.sin(math.rad(def.Walk.swing)) / math.sin(math.rad(24)),
		Styles = styles,
	}
	built[name] = b
	return b
end

-- The style name for one of an enemy's moves.
function Bipeds.StyleFor(setName: string, enemyId: string, shape: string): string
	local base = string.gsub(enemyId, "^alpha_", "elite_")
	return OVERRIDES[enemyId .. ":" .. shape] or OVERRIDES[base .. ":" .. shape] or OVERRIDES[enemyId] or OVERRIDES[base]
		or BY_SHAPE[setName][shape] or "Slash"
end

return Bipeds
