--!strict
-- The Colossus motion set (docs/mob-reanimation-plan.md §3.2, step 6) for the six colossus Biome Bosses and
-- the raid bosses' stand-in rigs: a wide, heavy stance, a slow deep-breathing idle that turns side to side, a
-- planted stomping walk, an awakening, a crash-forward death and boss attack styles. Two bosses key their
-- extra joints: the Spore Matriarch's morel crown rises for its signatures and awakening, and the Rift
-- Warden's tome shields swing in front on the windup. Built on Common.pose, like the biped sets.
local Common = require(game.ReplicatedStorage.Assets.EnemyClips.Common)

local with, crouch, add, rot = Common.with, Common.crouch, Common.add, Common.rot
local keys, attack, loop = Common.keys, Common.attack, Common.loop
local TAU = 2 * math.pi

local Colossi = {}

Colossi.Families = {
	STONE_COLOSSUS = true, FUNGAL_COLOSSUS = true, FORGE_COLOSSUS = true,
	GROVE_COLOSSUS = true, ARCANE_COLOSSUS = true, ROYAL_COLOSSUS = true,
}

local IDLE_SECONDS = 5.5
local SWING = 16
local REST: Common.PoseSpec = crouch({
	lean = 8, nod = -4,
	armL = { fwd = 10, out = 18 }, armR = { fwd = 10, out = 18 }, foreL = 15, foreR = 15,
	legL = { out = 5 }, legR = { out = 5 },
}, 0.25)

-- Extra-joint keys a boss's clips add on top (missing joints are ignored, so every colossus can share them).
local function crown(rise: number, tip: number): { [string]: CFrame }
	return { ExtraCrown = CFrame.new(0, rise, 0) * rot(tip, 0, 0) }
end
local function tomes(inward: number): { [string]: CFrame }
	-- TomeL sits outside the left forearm: Ry(-a) swings it to the front; TomeR mirrors it.
	return { ExtraTomeL = rot(0, -inward, 0), ExtraTomeR = rot(0, inward, 0) }
end
local function extras(c: { [string]: CFrame }?, t: { [string]: CFrame }?): { [string]: CFrame }
	local e: { [string]: CFrame } = {}
	for k, v in c or {} do e[k] = v end
	for k, v in t or {} do e[k] = v end
	return e
end
-- Rest with the keyed extras back in place, so a clip hands them back to their springs from rest.
local R0 = with(REST, { extra = extras(crown(0, 0), tomes(0)) })

local function idleClip()
	return loop(8, function(phase)
		local s, c = math.sin(TAU * phase), math.cos(TAU * phase)
		return add(REST, {
			bob = 0.08 * s, lean = 1.5 * s, nod = -2 * s, -- a slow, deep breath
			twist = 5 * math.sin(TAU * phase * 1), turn = 6 * math.sin(TAU * (phase - 0.1)), -- looks over its domain
			tilt = 1.5 * c,
			armL = { fwd = 2 * s, out = 2 * s }, armR = { fwd = 2 * s, out = 2 * s },
		})
	end)
end

local function walkClip()
	return loop(8, function(phase)
		local s, c = math.sin(TAU * phase), math.cos(TAU * phase)
		-- each footfall sinks the body (lowest at double support) and rolls it over the planted leg
		return add(REST, {
			lean = 4, bob = 0.16 * (math.abs(c) - 0.6),
			twist = 6 * s, turn = -3 * s, tilt = 7 * c,
			legL = { fwd = SWING * s }, legR = { fwd = -SWING * s },
			kneeL = 24 * math.max(0, c), kneeR = 24 * math.max(0, -c),
			armL = { fwd = -10 * s }, armR = { fwd = 10 * s },
		})
	end)
end

local function fidgets()
	local function shot(list: { { any } })
		local k = { { 0, REST } }
		for _, e in list do table.insert(k, { e[1], add(REST, e[2]) }) end
		table.insert(k, { 1, REST })
		return keys(k)
	end
	return {
		shot({ { 0.35, { twist = 18, turn = 25 } }, { 0.7, { twist = -14, turn = -20 } } }), -- surveys the room
		shot({ { 0.4, { lean = -8, nod = -15, armL = { fwd = 15, out = 20 }, armR = { fwd = 15, out = 20 }, bob = 0.1 } } }), -- rumbles a breath
	}
end

local function awakening()
	-- slumped dormant, heaves itself up, roars with arms flung wide, settles
	local slump = crouch(add(REST, { lean = 30, nod = 30, armL = { fwd = -5, out = -10 }, armR = { fwd = -5, out = -10 } }), 0.6)
	return keys({
		{ 0, with(slump, { extra = extras(crown(-0.2, 0), tomes(0)) }) },
		{ 0.45, with(crouch(add(REST, { lean = 12, nod = 12 }), 0.3), { extra = extras(crown(0, 0), tomes(10)) }) },
		{ 0.72, with(add(REST, { lean = -14, bob = 0.1, nod = -28, armL = { fwd = 45, out = 70 }, armR = { fwd = 45, out = 70 }, foreL = -10, foreR = -10 }), { extra = extras(crown(0.8, -8), tomes(35)) }) },
		{ 0.85, with(add(REST, { lean = -10, bob = 0.08, nod = -24, armL = { fwd = 40, out = 66 }, armR = { fwd = 40, out = 66 } }), { extra = extras(crown(0.7, -6), tomes(30)) }) },
		{ 1, R0 },
	})
end

local function deathClip()
	-- staggers back a step, drops to its knees, then crashes forward
	return keys({
		{ 0, REST },
		{ 0.2, add(REST, { lean = -12, nod = -20, twist = 10, armL = { fwd = -10, out = 30 }, armR = { fwd = 20, out = 35 } }) },
		{ 0.5, { planted = false, lean = 18, bob = -1.4, legL = { fwd = 75 }, legR = { fwd = 70 }, kneeL = 110, kneeR = 105, armL = { fwd = 0, out = 30 }, armR = { fwd = 0, out = 30 }, nod = 25 } },
		{ 0.65, { planted = false, lean = 32, bob = -1.6, legL = { fwd = 70 }, legR = { fwd = 70 }, kneeL = 110, kneeR = 110, armL = { fwd = 15, out = 30 }, armR = { fwd = 15, out = 30 }, nod = 30 } },
		{ 1, { planted = false, lean = 86, bob = -2.9, legL = { fwd = -5 }, legR = { fwd = 5 }, kneeL = 20, kneeR = 10, armL = { fwd = 35, out = 50 }, armR = { fwd = 30, out = 45 }, nod = 10 } },
	})
end

-- ------------------------------------------------------------------ attack styles (R0 in and out)
local Styles = {}

function Styles.Sweep() -- ARC: a huge backhanded sweep of the right arm
	local wind = with(add(REST, { twist = 45, lean = 2, armR = { fwd = 25, out = 75 }, foreR = -5, armL = { fwd = 30, out = -10 } }), { extra = tomes(40) })
	local hit = with(crouch(add(REST, { twist = -50, lean = 14, push = 0.3, armR = { fwd = 55, out = -40 }, foreR = -5, armL = { fwd = -10, out = 30 } }), 0.25), { extra = tomes(0) })
	return attack({ { 0, R0 }, { 0.5, wind }, { 0.74, add(wind, { twist = 6 }) }, { 0.82, hit }, { 0.92, add(hit, { twist = -6 }) }, { 1, R0 } }, 0.74, 0.82)
end

function Styles.Pound() -- TARGET_DISC: both fists overhead, then a lunging slam at the target
	local wind = with(add(REST, { lean = -14, bob = 0.15, nod = -15, armL = { fwd = 150, out = 8 }, armR = { fwd = 150, out = 8 }, foreL = -30, foreR = -30 }), { extra = extras(crown(0.6, -10), tomes(45)) })
	local hit = with(crouch(add(REST, { lean = 36, push = 0.6, nod = 16, armL = { fwd = 60, out = -8 }, armR = { fwd = 60, out = -8 }, foreL = -15, foreR = -15 }), 0.6), { extra = extras(crown(0, 6), tomes(0)) })
	return attack({ { 0, R0 }, { 0.55, wind }, { 0.74, add(wind, { armL = { fwd = 8 }, armR = { fwd = 8 } }) }, { 0.82, hit }, { 0.92, add(hit, { lean = -3 }) }, { 1, R0 } }, 0.74, 0.82)
end

function Styles.Quake() -- SELF_DISC: rears up, then drives both fists into the ground around it
	local rear = with(add(REST, { lean = -18, bob = 0.3, nod = -25, armL = { fwd = 120, out = 45 }, armR = { fwd = 120, out = 45 }, foreL = -20, foreR = -20 }), { extra = extras(crown(0.9, -12), tomes(30)) })
	local hit = with(crouch(add(REST, { lean = 40, nod = 20, armL = { fwd = 55, out = 30 }, armR = { fwd = 55, out = 30 }, foreL = -20, foreR = -20 }), 0.75), { extra = extras(crown(-0.1, 8), tomes(0)) })
	return attack({ { 0, R0 }, { 0.55, rear }, { 0.76, add(rear, { bob = 0.05, lean = -3 }) }, { 0.82, hit }, { 0.92, add(hit, { lean = -4 }) }, { 1, R0 } }, 0.76, 0.82)
end

function Styles.Hurl() -- PROJECTILE: heaves from behind its shoulder and hurls forward with both arms
	local wind = with(add(REST, { lean = -16, twist = 15, bob = 0.08, armL = { fwd = 150, out = 15 }, armR = { fwd = 155, out = 20 }, foreL = 20, foreR = 25 }), { extra = tomes(35) })
	local throw = with(crouch(add(REST, { lean = 24, twist = -10, push = 0.35, armL = { fwd = 85, out = 0 }, armR = { fwd = 90, out = 0 }, foreL = -20, foreR = -20 }), 0.3), { extra = tomes(0) })
	return attack({ { 0, R0 }, { 0.5, wind }, { 0.62, add(wind, { armL = { fwd = 10 }, armR = { fwd = 10 } }) }, { 0.7, throw }, { 0.85, add(throw, { lean = -6 }) }, { 1, R0 } }, 0.62, 0.7)
end

local BY_SHAPE: { [string]: string } = { ARC = "Sweep", TARGET_DISC = "Pound", SELF_DISC = "Quake", PROJECTILE = "Hurl" }

export type BuiltSet = {
	Name: string, Idle: any, Locomotion: any, HitReaction: any, Death: any, Awakening: any,
	Fidgets: { any }, IdleSeconds: number, StrideScale: number, Styles: { [string]: any },
}
local built: BuiltSet? = nil

function Colossi.Set(): BuiltSet
	if built then return built end
	local styles = {}
	for name, fn in Styles :: any do styles[name] = fn() end
	local b: BuiltSet = {
		Name = "Colossus",
		Idle = idleClip(), Locomotion = walkClip(), HitReaction = Common.Hit, Death = deathClip(), Awakening = awakening(),
		Fidgets = fidgets(), IdleSeconds = IDLE_SECONDS,
		StrideScale = math.sin(math.rad(SWING)) / math.sin(math.rad(24)),
		Styles = styles,
	}
	built = b
	return b
end

function Colossi.StyleFor(shape: string): string
	return BY_SHAPE[shape] or "Sweep"
end

return Colossi
