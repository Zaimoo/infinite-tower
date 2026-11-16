--!strict
-- ReplicatedStorage/Assets/HeroRig/HeroClips.luau
-- Keyframed hero poses (hero-rig-rebuild-plan.md, Phase 4). Native data in the style of
-- TowerEnemyClips: no uploaded animation IDs. Rotations are degrees in the HeroRigSpec axis
-- convention (shoulder/hip +X forward, elbow +X flex, knee -X flex, waist/neck -X lean
-- forward, +Y turn left). A joint missing from a pose is at rest.
--
-- With the hand grip rule, an arm's shoulder pitch plus elbow pitch sets how far a held
-- weapon's head is tipped up from "pointing forward": 90 degrees stands a sword or staff
-- upright, and an arm raised straight forward stands a bow vertical with the arrow ahead.
--
-- Lookup order for a state: Overrides[heroId] -> ByWeapon[weaponType] -> Shared.

export type Pose = { [string]: { number } } -- joint -> {rx, ry, rz}; "RootOffset" -> {x, y, z}
-- Linear: the blend into this key is linear instead of eased, so a run of keys moves at a
-- steady rate (a full-body spin through several Root keys) instead of pausing on each one.
export type Key = { T: number, Pose: Pose, Linear: boolean? }
export type Draw = { Set: number, Full: number, Anchor: { number }? }
export type Clip = {
	Duration: number, -- seconds at speed 1 (attacks are rescaled to the attack interval)
	Looped: boolean,
	Keys: { Key },
	Markers: { [string]: number }?, -- event name -> fraction of the clip (see RELEASE_MARKERS)
	-- Bow attacks: when the draw hand takes the string (Set) and when it reaches full draw
	-- (Full), as fractions of the clip, and optionally where it anchors (Anchor: Head space, as
	-- fractions of the head's size). HeroAnimator's procedural draw (SolveBowDraw) reads it;
	-- clips without it use DRAW_DEFAULT (fractions of the Release) and the chin anchor.
	Draw: Draw?,
}

local HeroClips = {}

HeroClips.WEAPON_TYPES = table.freeze({ "UNARMED", "BOW", "SWORD_SHIELD", "DAGGERS", "AXE", "STAFF", "TOME" })
HeroClips.WEAPON_STATES = table.freeze({ "Idle", "Move", "AttackBasic", "AttackSpecial", "AttackSkill" })
HeroClips.SHARED_STATES = table.freeze({
	"Hit",
	"Coma",
	"Carry",
	"Sleep",
	"Labor",
	"MarketHawker",
	"MarketStock",
	"MarketCarry",
	"MarketAppraiser",
	"MarketLedger",
	"TrainingKata",
	"TrainingCoach",
	"Victory", -- a duel's winners, through its outro (B2); every weapon has its own, this is the fallback
})
HeroClips.LOCOMOTION_STATES = table.freeze({
	Victory = true,
	Idle = true,
	Move = true,
	Coma = true,
	Carry = true,
	Sleep = true,
	Labor = true,
	MarketHawker = true,
	MarketStock = true,
	MarketCarry = true,
	MarketAppraiser = true,
	MarketLedger = true,
	TrainingKata = true,
	TrainingCoach = true,
})

-- Joints an action may drive while the hero is moving (legs keep walking).
HeroClips.UPPER_BODY = table.freeze({
	Waist = true, Neck = true,
	LeftShoulder = true, LeftElbow = true, LeftWrist = true,
	RightShoulder = true, RightElbow = true, RightWrist = true,
})

local function merge(base: Pose, overrides: Pose?): Pose
	local result: Pose = table.clone(base)
	if overrides then
		for joint, value in overrides do
			result[joint] = value
		end
	end
	return result
end

local function clip(duration: number, looped: boolean, keys: { { any } }): Clip
	local list: { Key } = {}
	for _, k in keys do
		table.insert(list, { T = k[1], Pose = k[2], Linear = if k[3] == true then true else nil })
	end
	return { Duration = duration, Looped = looped, Keys = list }
end

-- Idle with a slow breath: the stance, then the stance with a slightly raised chest.
local function breathe(stance: Pose, duration: number?): Clip
	local inhale = merge(stance, {})
	local waist = stance.Waist or { 0, 0, 0 }
	inhale.Waist = { waist[1] + 1.5, waist[2], waist[3] }
	local neck = stance.Neck or { 0, 0, 0 }
	inhale.Neck = { neck[1] - 1, neck[2], neck[3] }
	return clip(duration or 3.2, true, { { 0, stance }, { 0.5, inhale }, { 1, stance } })
end

-- Magical levitation hover idle: gentle bobbing levitation wave on the chest, arm, and floating grimoire.
local function floatIdle(stance: Pose, duration: number?): Clip
	local dur = duration or 3.2
	local crest = merge(stance, {
		Waist = { (stance.Waist and stance.Waist[1] or 0) + 1.8, stance.Waist and stance.Waist[2] or 0, stance.Waist and stance.Waist[3] or 0 },
		Neck = { (stance.Neck and stance.Neck[1] or 0) - 1.2, stance.Neck and stance.Neck[2] or 0, stance.Neck and stance.Neck[3] or 0 },
		LeftShoulder = { (stance.LeftShoulder and stance.LeftShoulder[1] or 0) + 5.0, stance.LeftShoulder and stance.LeftShoulder[2] or 0, stance.LeftShoulder and stance.LeftShoulder[3] or 0 },
		LeftElbow = { (stance.LeftElbow and stance.LeftElbow[1] or 0) - 6.0, stance.LeftElbow and stance.LeftElbow[2] or 0, stance.LeftElbow and stance.LeftElbow[3] or 0 },
		LeftWrist = { (stance.LeftWrist and stance.LeftWrist[1] or 0) + 6.0, stance.LeftWrist and stance.LeftWrist[2] or 0, (stance.LeftWrist and stance.LeftWrist[3] or 0) - 6.8 },
	})
	local trough = merge(stance, {
		Waist = { (stance.Waist and stance.Waist[1] or 0) - 1.2, stance.Waist and stance.Waist[2] or 0, stance.Waist and stance.Waist[3] or 0 },
		Neck = { (stance.Neck and stance.Neck[1] or 0) + 0.8, stance.Neck and stance.Neck[2] or 0, stance.Neck and stance.Neck[3] or 0 },
		LeftShoulder = { (stance.LeftShoulder and stance.LeftShoulder[1] or 0) - 4.0, stance.LeftShoulder and stance.LeftShoulder[2] or 0, stance.LeftShoulder and stance.LeftShoulder[3] or 0 },
		LeftElbow = { (stance.LeftElbow and stance.LeftElbow[1] or 0) + 4.5, stance.LeftElbow and stance.LeftElbow[2] or 0, stance.LeftElbow and stance.LeftElbow[3] or 0 },
		LeftWrist = { (stance.LeftWrist and stance.LeftWrist[1] or 0) - 4.5, stance.LeftWrist and stance.LeftWrist[2] or 0, (stance.LeftWrist and stance.LeftWrist[3] or 0) + 5.2 },
	})
	return clip(dur, true, {
		{ 0, stance },
		{ 0.30, crest },
		{ 0.70, trough },
		{ 1, stance },
	})
end

-- Adds `delta` to a joint of `pose` (missing joints count as zero).
local function nudge(pose: Pose, joint: string, delta: { number })
	local v = pose[joint] or { 0, 0, 0 }
	pose[joint] = { v[1] + delta[1], v[2] + delta[2], v[3] + delta[3] }
end

-- Upper-body motion over a stride, added on top of whatever the hero carries: the torso
-- twists against the legs (the shoulder opposite the forward foot comes round), rolls a little
-- toward the planted side and leans into each landing; the head turns back against the twist
-- so it stays on the way ahead; the arms sway a few degrees opposite the legs. `s` is +1 with
-- the left foot forward, -1 with the right, 0 when passing. Small enough that a held weapon
-- only rides along with the body.
local function strideUpperBody(pose: Pose, s: number)
	nudge(pose, "Waist", { -1.5 * math.abs(s), 7 * s, 2 * s })
	nudge(pose, "Neck", { 0, -5 * s, -1.5 * s })
	nudge(pose, "RightShoulder", { 4 * s, 0, 0 })
	nudge(pose, "LeftShoulder", { -4 * s, 0, 0 })
end

-- How a weapon walks (docs/first-session-and-social-plan.md A8). Every field is optional.
--   Stride  hip swing each way (deg)           Lift   extra knee bend of the leg swinging through
--   Bob     root rise and fall (studs)          Lean   waist pitch held all cycle (negative: forward)
--   Crouch  extra knee bend on both legs (a low, prowling walk)
--   Twist   scales the torso's counter-twist against the legs (strideUpperBody)
export type Gait = { Stride: number?, Lift: number?, Bob: number?, Lean: number?, Crouch: number?, Twist: number? }

-- Walk cycle, sampled from smooth curves at eight points and played at a steady rate between them,
-- so the stride never pauses on a key: each leg swings through with its knee lifting and its foot
-- flexing, the root is lowest just after each foot lands and highest as the legs pass, and the
-- upper body moves with the stride over its carry pose (strideUpperBody). With armSwing, free arms
-- swing that far instead.
local function walk(carry: Pose, armSwing: number?, gait: Gait?): Clip
	local swing = armSwing or 0
	local g: Gait = gait or {}
	local stride, lift, bob = g.Stride or 28, g.Lift or 30, g.Bob or 0.06
	local lean, crouch, twist = g.Lean or 0, g.Crouch or 0, g.Twist or 1
	local SAMPLES = 8
	local function step(i: number): Pose
		local a = 2 * math.pi * i / SAMPLES
		local c = math.cos(a) -- +1: left foot forward, -1: right foot forward
		local leftSwing = math.max(0, -math.sin(a)) -- the left leg travelling forward
		local rightSwing = math.max(0, math.sin(a))
		local p = merge(carry, {
			LeftHip = { stride * c + crouch * 0.6, 0, -2 }, RightHip = { -stride * c + crouch * 0.6, 0, 2 },
			LeftKnee = { -7 - crouch - lift * leftSwing, 0, 0 }, RightKnee = { -7 - crouch - lift * rightSwing, 0, 0 },
			LeftAnkle = { 2 + 12 * leftSwing + crouch * 0.4, 0, 0 }, RightAnkle = { 2 + 12 * rightSwing + crouch * 0.4, 0, 0 },
			RootOffset = { 0, 0.02 - crouch * 0.008 - bob * math.cos(2 * a), 0 },
		})
		strideUpperBody(p, c * twist)
		if lean ~= 0 then nudge(p, "Waist", { lean, 0, 0 }) end
		if swing ~= 0 then
			p.LeftShoulder = { -swing * c, 0, 0 }
			p.RightShoulder = { swing * c, 0, 0 }
		end
		return p
	end
	local first = step(0)
	local keys: { { any } } = { { 0, first } }
	for i = 1, SAMPLES - 1 do
		table.insert(keys, { i / SAMPLES, step(i), true })
	end
	table.insert(keys, { 1, first, true }) -- the loop closes exactly on its first pose
	return clip(0.7, true, keys)
end

-- A looping victory cheer over `pose`: the raised arm pumps, the chest lifts and the hero bobs up
-- onto the toes. `joint` is the shoulder that pumps (the weapon arm).
local function cheer(pose: Pose, joint: string): Clip
	local pumped = merge(pose, {})
	nudge(pumped, joint, { 10, 0, 0 })
	nudge(pumped, "Waist", { 4, 0, 0 })
	nudge(pumped, "Neck", { 4, 0, 0 })
	local root = pose.RootOffset or { 0, 0, 0 }
	pumped.RootOffset = { root[1], root[2] + 0.12, root[3] }
	return clip(1.1, true, { { 0, pose }, { 0.45, pumped }, { 1, pose } })
end

-- Base stance shared by most weapon idles: soft knees, weight slightly forward.
local STANCE: Pose = {
	LeftHip = { 6, 0, -3 }, RightHip = { -4, 0, 3 },
	LeftKnee = { -8, 0, 0 }, RightKnee = { -6, 0, 0 },
	LeftAnkle = { 2, 0, 0 }, RightAnkle = { 10, 0, 0 },
}
local ATTACK_STANCE: Pose = merge(STANCE, {
	LeftHip = { 18, 0, -6 }, RightHip = { -14, 0, 6 },
	LeftKnee = { -22, 0, 0 }, RightKnee = { -18, 0, 0 },
	LeftAnkle = { 4, 0, 0 }, RightAnkle = { 30, 0, 0 },
	RootOffset = { 0, -0.12, 0 },
})

local ByWeapon: { [string]: { [string]: Clip } } = {}
-- Each weapon's key poses, so hero overrides can build signature clips from them.
local WeaponPoses: { [string]: { [string]: Pose } } = {}

-- UNARMED ---------------------------------------------------------------------------------
do
	local idle = merge(STANCE, {
		LeftShoulder = { 4, 0, -5 }, RightShoulder = { 4, 0, 5 },
		LeftElbow = { 12, 0, 0 }, RightElbow = { 12, 0, 0 },
	})
	local guard = merge(ATTACK_STANCE, {
		LeftShoulder = { 60, 0, -10 }, LeftElbow = { 95, 0, 0 },
		RightShoulder = { 45, 0, 10 }, RightElbow = { 110, 0, 0 },
	})
	local fistUp = merge(STANCE, { Waist = { 4, 0, 0 }, Neck = { 8, 0, 0 }, RightShoulder = { 160, 0, 14 }, RightElbow = { 30, 0, 0 }, LeftShoulder = { 10, 0, -10 }, LeftElbow = { 40, 0, 0 } })
	ByWeapon.UNARMED = {
		Victory = cheer(fistUp, "RightShoulder"),
		Idle = breathe(idle),
		Move = walk(idle, 24),
		AttackBasic = clip(0.5, false, {
			{ 0, guard },
			{ 0.35, merge(guard, { Waist = { -4, -20, 0 }, RightShoulder = { 85, 0, -8 }, RightElbow = { 5, 0, 0 } }) },
			{ 1, guard },
		}),
		AttackSpecial = clip(0.7, false, {
			{ 0, guard },
			{ 0.25, merge(guard, { Waist = { 0, 25, 0 }, RightShoulder = { 30, 0, 40 }, RightElbow = { 90, 0, 0 } }) },
			{ 0.55, merge(guard, { Waist = { -6, -30, 0 }, RightShoulder = { 90, 0, -20 }, RightElbow = { 20, 0, 0 } }) },
			{ 1, guard },
		}),
		AttackSkill = clip(0.9, false, {
			{ 0, guard },
			{ 0.3, merge(guard, { Waist = { 10, 0, 0 }, LeftShoulder = { 160, 0, -15 }, RightShoulder = { 160, 0, 15 }, LeftElbow = { 20, 0, 0 }, RightElbow = { 20, 0, 0 } }) },
			{ 0.6, merge(guard, { Waist = { -25, 0, 0 }, LeftShoulder = { 60, 0, -10 }, RightShoulder = { 60, 0, 10 }, LeftElbow = { 10, 0, 0 }, RightElbow = { 10, 0, 0 }, RootOffset = { 0, -0.35, 0 } }) },
			{ 1, guard },
		}),
	}
end

-- BOW (bow in the left hand) ----------------------------------------------------------------
do
	-- Walking carry: stave canted ~30 deg forward, arrow pointing forward and down.
	local carry = merge(STANCE, {
		Waist = { -2, -8, 0 }, Neck = { 0, 8, 0 },
		LeftShoulder = { 10, 0, -10 }, LeftElbow = { 50, 0, 0 },
		RightShoulder = { 14, 10, -14 }, RightElbow = { 45, 0, 0 },
	})
	-- Square-on aim poses (arm straight forward: stave vertical, arrow at the target). The
	-- marksman heroes' signature clips are built from these (Overrides below), so they stay as
	-- they were; the shared clips use the side-on archer's stance further down.
	local aim = merge(ATTACK_STANCE, {
		Waist = { -2, -10, 0 }, Neck = { 0, 10, 0 },
		LeftShoulder = { 90, 0, 0 }, LeftElbow = { 0, 0, 0 },
		RightShoulder = { 90, 22, 0 }, RightElbow = { 30, 0, 0 },
	})
	local drawn = merge(aim, { RightShoulder = { 88, 28, -10 }, RightElbow = { 145, 0, 0 } })
	local release = merge(aim, { LeftShoulder = { 96, 0, 0 }, RightShoulder = { 70, 40, -30 }, RightElbow = { 120, 0, 0 } })
	local crouch: Pose = { LeftHip = { 40, 0, -8 }, RightHip = { -10, 0, 8 }, LeftKnee = { -55, 0, 0 }, RightKnee = { -70, 0, 0 }, LeftAnkle = { 15, 0, 0 }, RightAnkle = { 60, 0, 0 }, RootOffset = { 0, -0.55, 0 } }
	local skyAim = merge(aim, { Waist = { 18, -10, 0 }, Neck = { 15, 10, 0 }, LeftShoulder = { 140, 0, 0 }, RightShoulder = { 138, 14, 0 } })

	-- The archer's stance (solved in Studio against the rig and a mesh bow, then checked by
	-- eye). The whole body turns side-on with Root (-50) and Waist (-32), so the bow shoulder
	-- points at the target; the head turns back to look down the arrow. The bow arm is straight
	-- out at shoulder height with the stave upright and a slight cant; the draw hand anchors
	-- under the chin with its elbow high and behind, in line with the arrow. The draw hand's
	-- angles here are where it rests between keys: during an attack HeroAnimator.SolveBowDraw
	-- puts it on the string and pulls it back along the arrow (the Draw timings), and
	-- HeroBowString bends the string and carries the arrow with it.
	local archerLegs: Pose = {
		LeftHip = { 8, 0, -10 }, RightHip = { -6, 0, 10 },
		LeftKnee = { -12, 0, 0 }, RightKnee = { -10, 0, 0 },
		LeftAnkle = { 4, 0, 10 }, RightAnkle = { 16, 0, -10 },
		RootOffset = { 0, -0.1, 0 },
	}
	local sideOn: Pose = merge(archerLegs, {
		Root = { 0, -50, 0 }, Waist = { 2, -32, 0 }, Neck = { -3, 82, 0 },
		LeftShoulder = { 88, -2, -80 }, LeftElbow = { 1, 0, 0 }, LeftWrist = { -4, -5, -2 },
	})
	-- Set: the bow comes up on the target with the bow arm still bent and the chest still square,
	-- so the draw hand can take the resting string (these rigs' shoulders are wide for their
	-- arms: side-on, the string at arm's length is out of the draw hand's reach). From Set to
	-- Anchor the archer pushes the bow out and coils side-on while drawing.
	-- Anchor: full draw at the chin. Loose: the hand flies back past the ear off the string; the
	-- bow arm rides the kick.
	local set = merge(sideOn, {
		Waist = { 2, 38, 0 }, Neck = { -2, 13, 0 },
		LeftShoulder = { 77, -23, 13 }, LeftElbow = { 45, 0, 0 }, LeftWrist = { -30, 12, -29 },
		RightShoulder = { -49, 6, -139 }, RightElbow = { 62, 0, 0 },
	})
	local anchor = merge(sideOn, { RightShoulder = { -125, 57, -90 }, RightElbow = { 90, 0, 0 } })
	local loose = merge(sideOn, { LeftShoulder = { 91, -2, -80 }, RightShoulder = { 141, 81, -36 }, RightElbow = { 119, 0, 0 } })
	local looseHeld = merge(loose, { Waist = { 0, -32, 0 }, LeftShoulder = { 89, -2, -80 }, RightElbow = { 112, 0, 0 } })
	-- The same stance shooting 50 deg up: leaning back, chin up.
	local skyOn: Pose = merge(archerLegs, {
		Root = { 0, -50, 0 }, Waist = { 14, -30, 0 }, Neck = { 19, 72, 0 },
		LeftShoulder = { 120, -47, -50 }, LeftElbow = { 0, 0, 0 }, LeftWrist = { -16, -25, -6 },
	})
	local skySet = merge(skyOn, {
		Waist = { 14, 27, 0 }, Neck = { 14, 19, 0 },
		LeftShoulder = { 115, -46, 6 }, LeftElbow = { 45, 0, 0 }, LeftWrist = { -35, 12, -24 },
		RightShoulder = { 75, -7, -54 }, RightElbow = { 62, 0, 0 },
	})
	local skyAnchor = merge(skyOn, { RightShoulder = { -155, 60, -80 }, RightElbow = { 91, 0, 0 } })
	local skyLoose = merge(skyOn, { RightShoulder = { 121, 77, -39 }, RightElbow = { 121, 0, 0 } })
	-- Ready (idle): turned a third of the way, bow low in front and canted, arrow nocked and
	-- pointing at the ground ahead, the draw hand resting on the string.
	local ready: Pose = {
		Root = { 0, -30, 0 }, Waist = { 2, -10, 0 }, Neck = { -12, 40, 0 },
		LeftShoulder = { 2, -1, -8 }, LeftElbow = { 60, 0, 0 }, LeftWrist = { -12, -7, -22 },
		RightShoulder = { 120, 48, -92 }, RightElbow = { 15, 0, 0 },
		LeftHip = { 6, 0, -6 }, RightHip = { -4, 0, 6 },
		LeftKnee = { -10, 0, 0 }, RightKnee = { -8, 0, 0 },
		LeftAnkle = { 2, 0, 6 }, RightAnkle = { 12, 0, -6 },
		RootOffset = { 0, -0.06, 0 },
	}
	-- Kneeling: the crouch's legs under the side-on body.
	local kneel: Pose = merge(crouch, {})
	WeaponPoses.BOW = {
		Carry = carry, Aim = aim, Drawn = drawn, Release = release, Crouch = crouch, SkyAim = skyAim,
		Ready = ready, Set = set, Anchor = anchor, Loose = loose, SkySet = skySet, SkyAnchor = skyAnchor, SkyLoose = skyLoose,
	}
	local bowUp = merge(STANCE, { Waist = { 4, -6, 0 }, Neck = { 8, 6, 0 }, LeftShoulder = { 158, 0, -8 }, LeftElbow = { 12, 0, 0 }, RightShoulder = { 20, 0, 18 }, RightElbow = { 40, 0, 0 } })
	local function attack(duration: number, keys: { { any } }, draw: Draw): Clip
		local result = clip(duration, false, keys)
		result.Draw = draw
		return result
	end
	ByWeapon.BOW = {
		Victory = cheer(bowUp, "LeftShoulder"),
		Idle = breathe(ready),
		-- A light scout's walk: long, easy strides, leaning a little into them.
		Move = walk(carry, nil, { Stride = 26, Lean = -3 }),
		-- Basic: turn side-on raising the bow with the hand on the string, draw to the chin,
		-- loose (the hand flies back past the ear), hold the follow-through, settle.
		AttackBasic = attack(0.8, {
			{ 0, ready },
			{ 0.22, set },
			{ 0.6, anchor },
			{ 0.72, loose, true },
			{ 0.86, looseHeld },
			{ 1, ready },
		}, { Set = 0.22, Full = 0.6 }),
		-- Special: drop to a kneel side-on with the bow up (Charge), a long full draw that
		-- creeps deeper while the shot gathers, loose and hold low, rise.
		AttackSpecial = attack(0.95, {
			{ 0, ready },
			{ 0.18, merge(set, kneel) },
			{ 0.48, merge(anchor, kneel) },
			{ 0.7, merge(merge(anchor, kneel), { Waist = { 4, -35, 0 }, RootOffset = { 0, -0.6, 0.04 } }) },
			{ 0.78, merge(merge(loose, kneel), { RootOffset = { 0, -0.52, 0.1 } }), true },
			{ 0.88, merge(looseHeld, kneel) },
			{ 1, ready },
		}, { Set = 0.18, Full = 0.48 }),
		-- Skill: sink low over the bow to gather (Charge), spring up onto the toes into the
		-- sky stance, a long held draw at the sky, then loose with a recoil that rocks the
		-- archer back.
		AttackSkill = attack(1.1, {
			{ 0, ready },
			{ 0.2, merge(merge(sideOn, crouch), {
				Waist = { -10, -32, 0 }, Neck = { -10, 80, 0 },
				LeftShoulder = { 55, -2, -80 }, LeftElbow = { 20, 0, 0 },
				RightShoulder = { 60, 0, 40 }, RightElbow = { 60, 0, 0 },
				RootOffset = { 0, -0.5, 0 },
			}) },
			{ 0.42, merge(skySet, { RootOffset = { 0, 0.12, 0 } }) },
			{ 0.64, merge(skyAnchor, { RootOffset = { 0, 0.14, 0 } }) },
			{ 0.72, merge(skyLoose, { Waist = { 20, -30, 0 }, RootOffset = { 0, 0.04, 0.12 } }), true },
			{ 0.86, merge(skyLoose, { Waist = { 16, -30, 0 }, RightElbow = { 112, 0, 0 }, RootOffset = { 0, 0, 0.08 } }) },
			{ 1, ready },
		}, { Set = 0.42, Full = 0.64 }),
	}
end

-- SWORD_SHIELD (sword right hand, shield strapped to the left forearm) ------------------------
do
	-- Sword raised 45 deg in front; shield arm across the body at waist height.
	local guard = merge(STANCE, {
		LeftShoulder = { 25, -20, -8 }, LeftElbow = { 70, 0, 0 },
		RightShoulder = { 15, 0, 8 }, RightElbow = { 30, 0, 0 },
	})
	local high = merge(ATTACK_STANCE, { Waist = { 4, 20, 0 }, RightShoulder = { 165, 0, 15 }, RightElbow = { 40, 0, 0 }, LeftShoulder = { 40, -25, -10 }, LeftElbow = { 80, 0, 0 } })
	local cut = merge(ATTACK_STANCE, { Waist = { -14, -25, 0 }, RightShoulder = { 55, -20, -5 }, RightElbow = { 10, 0, 0 }, LeftShoulder = { 20, -10, -15 }, LeftElbow = { 60, 0, 0 } })
	local bash = merge(ATTACK_STANCE, { Waist = { -8, -30, 0 }, LeftShoulder = { 85, 25, -5 }, LeftElbow = { 20, 0, 0 }, RightShoulder = { 20, 0, 25 }, RightElbow = { 60, 0, 0 } })
	WeaponPoses.SWORD_SHIELD = { Guard = guard, High = high, Cut = cut, Bash = bash }
	-- Basic: rock back with the sword cocked high, bring it over the shoulder, then step into a
	-- diagonal cut that drives the front knee down, follow through, and recover behind the shield.
	local coil = merge(high, { Waist = { 8, 32, 0 }, Neck = { -4, -24, 0 }, RightShoulder = { 160, 10, 24 }, RightElbow = { 55, 0, 0 }, RootOffset = { 0, -0.05, 0.08 } })
	local overhand = merge(ATTACK_STANCE, { Waist = { -4, 8, 0 }, Neck = { 0, -6, 0 }, RightShoulder = { 122, -10, 10 }, RightElbow = { 25, 0, 0 }, LeftShoulder = { 30, -15, -12 }, LeftElbow = { 70, 0, 0 } })
	local lunge = merge(cut, {
		Waist = { -20, -32, 0 }, Neck = { 10, 22, 0 }, RightShoulder = { 48, -26, -8 }, RightElbow = { 6, 0, 0 },
		LeftHip = { 34, 0, -6 }, LeftKnee = { -40, 0, 0 }, RightHip = { -22, 0, 6 }, RootOffset = { 0, -0.3, -0.12 },
	})
	local followThrough = merge(lunge, { Waist = { -16, -28, 0 }, RightShoulder = { 40, -22, -6 }, RootOffset = { 0, -0.24, -0.08 } })
	local swordUp = merge(STANCE, { Waist = { 4, 8, 0 }, Neck = { 8, -6, 0 }, RightShoulder = { 165, 0, 10 }, RightElbow = { 12, 0, 0 }, LeftShoulder = { 30, -25, -10 }, LeftElbow = { 75, 0, 0 } })
	ByWeapon.SWORD_SHIELD = {
		Victory = cheer(swordUp, "RightShoulder"),
		Idle = breathe(guard),
		-- A guarded march: shorter steps, shield held, weight forward.
		Move = walk(guard, nil, { Stride = 24, Lift = 26, Lean = -4, Bob = 0.05 }),
		AttackBasic = clip(0.75, false, { { 0, guard }, { 0.32, coil }, { 0.52, overhand, true }, { 0.62, lunge, true }, { 0.78, followThrough }, { 1, guard } }),
		-- Special: wind the shield arm back with the whole torso, sink onto the back leg, then
		-- drive forward off it into a lunging shield bash that carries past the target, and
		-- recover behind the shield.
		AttackSpecial = clip(0.85, false, {
			{ 0, guard },
			{ 0.2, merge(guard, { Waist = { 4, 26, 0 }, Neck = { 0, -18, 0 }, LeftShoulder = { 38, -42, -10 }, LeftElbow = { 102, 0, 0 }, RootOffset = { 0, -0.08, 0.06 } }) },
			{ 0.45, merge(ATTACK_STANCE, { Waist = { 8, 36, 0 }, Neck = { -2, -26, 0 }, LeftShoulder = { 30, -55, -12 }, LeftElbow = { 115, 0, 0 }, RightShoulder = { 25, 0, 20 }, RightElbow = { 60, 0, 0 }, RightHip = { -20, 0, 6 }, RightKnee = { -30, 0, 0 }, RootOffset = { 0, -0.2, 0.12 } }) },
			{ 0.6, merge(bash, { Waist = { -12, -34, 0 }, Neck = { 8, 24, 0 }, LeftShoulder = { 90, 28, -5 }, LeftElbow = { 14, 0, 0 }, LeftHip = { 34, 0, -6 }, LeftKnee = { -40, 0, 0 }, RightHip = { -22, 0, 6 }, RootOffset = { 0, -0.3, -0.16 } }), true },
			{ 0.72, merge(bash, { Waist = { -16, -38, 0 }, Neck = { 10, 26, 0 }, LeftShoulder = { 92, 30, -5 }, LeftElbow = { 10, 0, 0 }, LeftHip = { 36, 0, -6 }, LeftKnee = { -44, 0, 0 }, RightHip = { -24, 0, 6 }, RootOffset = { 0, -0.34, -0.2 } }) },
			{ 0.86, merge(guard, { Waist = { -4, -8, 0 }, RootOffset = { 0, -0.1, -0.06 } }) },
			{ 1, guard },
		}),
		-- Skill: crouch and gather, rise onto the toes with the sword straight up (the light
		-- gathers there), then drop through a full-body overhead strike into the ground, hold it,
		-- and stand.
		AttackSkill = clip(1.1, false, {
			{ 0, guard },
			{ 0.18, merge(guard, { Waist = { -14, 10, 0 }, LeftKnee = { -40, 0, 0 }, RightKnee = { -36, 0, 0 }, LeftHip = { 26, 0, -6 }, RightHip = { 18, 0, 6 }, RootOffset = { 0, -0.4, 0 } }) },
			{ 0.42, merge(high, { Waist = { 14, 0, 0 }, Neck = { 10, 0, 0 }, RightShoulder = { 178, 0, 4 }, RightElbow = { 8, 0, 0 }, RootOffset = { 0, 0.2, 0 } }) },
			{ 0.52, merge(high, { Waist = { 18, 0, 0 }, Neck = { 12, 0, 0 }, RightShoulder = { 178, 0, 2 }, RightElbow = { 14, 0, 0 }, RootOffset = { 0, 0.24, 0.06 } }) },
			{ 0.62, merge(cut, { Waist = { -32, 0, 0 }, Neck = { 16, 0, 0 }, RightShoulder = { 38, 0, 0 }, RightElbow = { 6, 0, 0 }, RootOffset = { 0, -0.5, -0.1 }, LeftKnee = { -55, 0, 0 }, RightKnee = { -48, 0, 0 }, LeftHip = { 42, 0, -6 }, RightHip = { 12, 0, 6 } }), true },
			{ 0.8, merge(cut, { Waist = { -28, 0, 0 }, Neck = { 14, 0, 0 }, RightShoulder = { 42, 0, 0 }, RootOffset = { 0, -0.46, -0.08 }, LeftKnee = { -52, 0, 0 }, RightKnee = { -45, 0, 0 }, LeftHip = { 40, 0, -6 }, RightHip = { 10, 0, 6 } }) },
			{ 1, guard },
		}),
	}
end

-- DAGGERS (both hands) ----------------------------------------------------------------------
do
	local ready = merge(STANCE, {
		LeftShoulder = { 12, 0, -10 }, LeftElbow = { 70, 0, 0 }, LeftWrist = { -30, 0, 0 },
		RightShoulder = { 12, 0, 10 }, RightElbow = { 70, 0, 0 }, RightWrist = { -30, 0, 0 },
	})
	local crouched = merge(ready, ATTACK_STANCE)
	WeaponPoses.DAGGERS = { Ready = ready, Crouched = crouched }
	-- Basic: a coiled one-two. Each blade is drawn back by the hip with the torso wound the other
	-- way, then the torso unwinds into a lunging stab while the other blade guards the chest.
	local coilRight = merge(crouched, { Waist = { -2, 22, 0 }, Neck = { 0, -16, 0 }, RightShoulder = { 25, 10, 10 }, RightElbow = { 120, 0, 0 }, RightWrist = { -40, 0, 0 } })
	local stabRight = merge(crouched, {
		Waist = { -10, -24, 0 }, Neck = { 4, 18, 0 }, RightShoulder = { 92, -4, -6 }, RightElbow = { 4, 0, 0 }, RightWrist = { -85, 0, 0 },
		LeftShoulder = { 30, 0, -14 }, LeftElbow = { 95, 0, 0 }, RootOffset = { 0, -0.2, -0.14 },
	})
	local coilLeft = merge(crouched, { Waist = { -4, -20, 0 }, Neck = { 0, 14, 0 }, LeftShoulder = { 25, -10, -10 }, LeftElbow = { 120, 0, 0 }, LeftWrist = { -40, 0, 0 }, RootOffset = { 0, -0.12, -0.06 } })
	local stabLeft = merge(crouched, {
		Waist = { -10, 24, 0 }, Neck = { 4, -18, 0 }, LeftShoulder = { 92, 4, 6 }, LeftElbow = { 4, 0, 0 }, LeftWrist = { -85, 0, 0 },
		RightShoulder = { 30, 0, 14 }, RightElbow = { 95, 0, 0 }, RootOffset = { 0, -0.2, -0.14 },
	})
	local bladesUp = merge(STANCE, { Waist = { 4, 0, 0 }, Neck = { 8, 0, 0 }, LeftShoulder = { 150, 0, -28 }, LeftElbow = { 25, 0, 0 }, RightShoulder = { 150, 0, 28 }, RightElbow = { 25, 0, 0 } })
	ByWeapon.DAGGERS = {
		Victory = cheer(bladesUp, "RightShoulder"),
		Idle = breathe(ready, 2.6),
		-- A low prowl: knees bent, chest forward, the torso twisting with each step.
		Move = walk(ready, nil, { Stride = 30, Lift = 34, Crouch = 12, Lean = -9, Bob = 0.04, Twist = 1.3 }),
		AttackBasic = clip(0.55, false, {
			{ 0, crouched },
			{ 0.14, coilRight },
			{ 0.3, stabRight, true },
			{ 0.58, coilLeft },
			{ 0.75, stabLeft, true },
			{ 1, crouched },
		}),
		-- Special: blades crossed low at the chest, a hop up throwing both overhead and wide (the
		-- Charge glints), then both rip down across each other in an X as the body drops forward.
		AttackSpecial = clip(0.7, false, {
			{ 0, crouched },
			{ 0.15, merge(crouched, { Waist = { 6, 0, 0 }, LeftShoulder = { 40, 30, 20 }, RightShoulder = { 40, -30, -20 }, LeftElbow = { 110, 0, 0 }, RightElbow = { 110, 0, 0 }, RootOffset = { 0, -0.28, 0 } }) },
			{ 0.42, merge(crouched, { Waist = { 12, 0, 0 }, Neck = { 8, 0, 0 }, LeftShoulder = { 150, 0, -42 }, RightShoulder = { 150, 0, 42 }, LeftElbow = { 18, 0, 0 }, RightElbow = { 18, 0, 0 }, RootOffset = { 0, 0.1, 0.04 } }) },
			{ 0.6, merge(crouched, { Waist = { -18, 0, 0 }, Neck = { 10, 0, 0 }, LeftShoulder = { 55, 0, 34 }, RightShoulder = { 55, 0, -34 }, LeftElbow = { 8, 0, 0 }, RightElbow = { 8, 0, 0 }, RootOffset = { 0, -0.34, -0.16 } }), true },
			{ 0.74, merge(crouched, { Waist = { -20, 0, 0 }, Neck = { 10, 0, 0 }, LeftShoulder = { 45, 0, 40 }, RightShoulder = { 45, 0, -40 }, LeftElbow = { 10, 0, 0 }, RightElbow = { 10, 0, 0 }, RootOffset = { 0, -0.36, -0.18 } }) },
			{ 1, crouched },
		}),
		-- Skill: a gathering crouch, then a flurry of three body-turning slashes, each one lunging,
		-- into a final two-blade thrust that ends low.
		AttackSkill = clip(1.0, false, {
			{ 0, crouched },
			{ 0.1, merge(crouched, { Waist = { 4, 0, 0 }, LeftShoulder = { 30, 20, 10 }, RightShoulder = { 30, -20, -10 }, LeftElbow = { 115, 0, 0 }, RightElbow = { 115, 0, 0 }, RootOffset = { 0, -0.3, 0 } }) },
			{ 0.24, merge(crouched, { Waist = { -10, -40, 0 }, Neck = { 4, 26, 0 }, RightShoulder = { 92, 22, 0 }, RightElbow = { 8, 0, 0 }, RootOffset = { 0, -0.2, -0.1 } }), true },
			{ 0.42, merge(crouched, { Waist = { -10, 40, 0 }, Neck = { 4, -26, 0 }, LeftShoulder = { 92, -22, 0 }, LeftElbow = { 8, 0, 0 }, RootOffset = { 0, -0.2, -0.14 } }), true },
			{ 0.6, merge(crouched, { Waist = { -10, -40, 0 }, Neck = { 4, 26, 0 }, RightShoulder = { 92, 22, 0 }, RightElbow = { 8, 0, 0 }, RootOffset = { 0, -0.22, -0.16 } }), true },
			{ 0.7, merge(crouched, { Waist = { 4, 0, 0 }, LeftShoulder = { 40, 10, 20 }, RightShoulder = { 40, -10, -20 }, LeftElbow = { 120, 0, 0 }, RightElbow = { 120, 0, 0 }, RootOffset = { 0, -0.1, 0 } }) },
			{ 0.8, merge(crouched, { Waist = { -18, 0, 0 }, LeftShoulder = { 100, 0, 20 }, RightShoulder = { 100, 0, -20 }, LeftElbow = { 4, 0, 0 }, RightElbow = { 4, 0, 0 }, RootOffset = { 0, -0.36, -0.18 } }), true },
			{ 0.9, merge(crouched, { Waist = { -16, 0, 0 }, LeftShoulder = { 96, 0, 22 }, RightShoulder = { 96, 0, -22 }, LeftElbow = { 6, 0, 0 }, RightElbow = { 6, 0, 0 }, RootOffset = { 0, -0.34, -0.16 } }) },
			{ 1, crouched },
		}),
	}
end

-- AXE (two-handed greataxe) -----------------------------------------------------------------
-- The right hand is welded high on the haft; the left closes on the weapon's OffhandGrip, 1.7
-- studs towards the butt. HeroAnimator.SolveOffhand re-solves the left arm every frame, so the
-- left-arm numbers below are only the baked answer for a Standard body (static poses, tests).
-- Both hands only reach the haft when it runs across the chest from the left hip out to the
-- right, so every pose keeps it there in torso space and the waist aims the swing: turned left
-- (+Y) the head comes round to the front, turned right it is drawn back.
do
	local function arms(right: { { number } }, left: { { number } }): Pose
		return {
			RightShoulder = right[1], RightElbow = right[2], RightWrist = right[3],
			LeftShoulder = left[1], LeftElbow = left[2], LeftWrist = left[3],
		}
	end
	-- Port arms: butt at the left hip, head up past the right shoulder.
	local port = arms({ { 11, 9, -60 }, { 92, 0, 0 }, { -11, 4, 33 } }, { { -13, -42, -17 }, { 84, 0, 0 }, { 0, -24, 0 } })
	-- Hauled back over the right shoulder, left hand in front of the chest.
	local cocked = arms({ { 96, 26, -60 }, { 103, 0, 0 }, { -35, -11, 35 } }, { { 18, -38, -4 }, { 109, 0, 0 }, { 0, -39, 0 } })
	-- End of a chop: arms driven out, edge down, head below the hands.
	local driven = arms({ { 12, -20, -35 }, { 47, 0, 0 }, { -35, -54, 35 } }, { { -15, -45, -17 }, { 108, 0, 0 }, { 0, -136, 0 } })
	-- Level and drawn back on the right, edge leading.
	local drawn = arms({ { -21, 6, -52 }, { 114, 0, 0 }, { 7, -32, -4 } }, { { 22, -40, 1 }, { 77, 0, 0 }, { 0, -70, 0 } })
	-- Level and swung through to the front.
	local through = arms({ { 4, -23, -52 }, { 63, 0, 0 }, { -33, -20, -27 } }, { { -21, -44, -21 }, { 110, 0, 0 }, { 0, -91, 0 } })
	-- Both hands overhead, head straight up.
	local overhead = arms({ { 164, -5, -43 }, { 3, 0, 0 }, { -35, -46, 35 } }, { { 51, -37, 23 }, { 109, 0, 0 }, { 0, -30, 0 } })
	-- Head buried in the floor.
	local buried = arms({ { 8, -41, -40 }, { 22, 0, 0 }, { -33, -43, 33 } }, { { -5, -47, -9 }, { 111, 0, 0 }, { 0, -154, 0 } })

	local rest = merge(merge(STANCE, port), { Waist = { -2, 18, 0 }, Neck = { 0, -16, 0 } })
	local windup = merge(merge(ATTACK_STANCE, cocked), { Waist = { 8, -24, 0 }, Neck = { -4, 20, 0 } })
	local chop = merge(merge(ATTACK_STANCE, driven), { Waist = { -22, 55, 0 }, Neck = { 12, -42, 0 }, RootOffset = { 0, -0.25, 0 } })
	local sweepBack = merge(merge(ATTACK_STANCE, drawn), { Waist = { 0, -42, 0 }, Neck = { 0, 34, 0 } })
	local sweepThrough = merge(merge(ATTACK_STANCE, through), { Waist = { -8, 62, 0 }, Neck = { 4, -46, 0 }, RootOffset = { 0, -0.18, 0 } })
	local high = merge(merge(ATTACK_STANCE, overhead), { Waist = { 12, 8, 0 }, Neck = { -6, -6, 0 }, RootOffset = { 0, 0.2, 0 } })
	local slam = merge(merge(ATTACK_STANCE, buried), {
		Waist = { -36, 50, 0 }, Neck = { 22, -40, 0 }, RootOffset = { 0, -0.55, 0 },
		LeftKnee = { -60, 0, 0 }, RightKnee = { -55, 0, 0 }, LeftHip = { 45, 0, -6 }, RightHip = { 10, 0, 6 },
	})
	WeaponPoses.AXE = { Rest = rest, Windup = windup, Chop = chop, SweepBack = sweepBack, SweepThrough = sweepThrough, High = high, Slam = slam }
	-- Basic beats only change the waist, legs and root: the arms keep their baked haft grips.
	local settle = merge(rest, { Waist = { -6, 12, 0 }, LeftHip = { 12, 0, -4 }, LeftKnee = { -20, 0, 0 }, RightKnee = { -16, 0, 0 }, RootOffset = { 0, -0.16, 0 } })
	local rise = merge(windup, { Waist = { 12, -30, 0 }, Neck = { -6, 24, 0 }, LeftKnee = { -10, 0, 0 }, RightKnee = { -8, 0, 0 }, RootOffset = { 0, 0.08, 0.06 } })
	local strike = merge(chop, { Waist = { -28, 60, 0 }, LeftHip = { 30, 0, -6 }, LeftKnee = { -38, 0, 0 }, RightKnee = { -30, 0, 0 }, RootOffset = { 0, -0.38, -0.1 } })
	local recoil = merge(chop, { Waist = { -20, 52, 0 }, RootOffset = { 0, -0.22, -0.06 } })
	local axeUp = merge(merge(STANCE, overhead), { Waist = { 8, 8, 0 }, Neck = { -2, -6, 0 } })
	ByWeapon.AXE = {
		-- The arms keep the baked overhead haft grip, so only the chest and bob move.
		Victory = clip(1.1, true, { { 0, axeUp }, { 0.45, merge(axeUp, { Waist = { 12, 8, 0 }, RootOffset = { 0, 0.12, 0 } }) }, { 1, axeUp } }),
		Idle = breathe(rest),
		-- A heavy walk: shorter strides, a deeper bob, the weapon's weight keeping the torso square.
		Move = walk(rest, nil, { Stride = 24, Lift = 28, Bob = 0.09, Lean = -5, Twist = 0.7 }),
		-- Overhand chop: sink, then rise onto the toes hauling it back over the shoulder, then the
		-- whole body drops through the chop and bounces off the impact.
		AttackBasic = clip(0.85, false, { { 0, rest }, { 0.16, settle }, { 0.45, rise }, { 0.65, strike, true }, { 0.8, recoil }, { 1, rest } }),
		-- Level sweep: sink and wind the torso far back on the right (the Charge builds), then
		-- unwind through a flat sweep that drags the body round past the front, and settle.
		AttackSpecial = clip(0.9, false, {
			{ 0, rest },
			{ 0.2, merge(sweepBack, { Waist = { 4, -30, 0 }, LeftKnee = { -26, 0, 0 }, RightKnee = { -22, 0, 0 }, RootOffset = { 0, -0.2, 0.04 } }) },
			{ 0.48, merge(sweepBack, { Waist = { 6, -52, 0 }, Neck = { -2, 40, 0 }, RightHip = { -20, 0, 6 }, RightKnee = { -30, 0, 0 }, RootOffset = { 0, -0.14, 0.1 } }) },
			{ 0.68, merge(sweepThrough, { Waist = { -12, 70, 0 }, Neck = { 6, -50, 0 }, LeftHip = { 30, 0, -6 }, LeftKnee = { -38, 0, 0 }, RootOffset = { 0, -0.3, -0.12 } }), true },
			{ 0.8, merge(sweepThrough, { Waist = { -8, 76, 0 }, Neck = { 4, -54, 0 }, LeftHip = { 28, 0, -6 }, LeftKnee = { -34, 0, 0 }, RootOffset = { 0, -0.26, -0.1 } }) },
			{ 1, rest },
		}),
		-- Skill: drop low, then haul the axe overhead rising onto the toes, hang at the top, and
		-- slam it into the floor with the whole body, bouncing once off the impact.
		AttackSkill = clip(1.15, false, {
			{ 0, rest },
			{ 0.18, merge(settle, { Waist = { -10, 14, 0 }, LeftKnee = { -34, 0, 0 }, RightKnee = { -30, 0, 0 }, RootOffset = { 0, -0.32, 0 } }) },
			{ 0.42, merge(high, { Waist = { 16, 8, 0 }, RootOffset = { 0, 0.28, 0.04 } }) },
			{ 0.52, merge(high, { Waist = { 20, 8, 0 }, Neck = { -8, -6, 0 }, RootOffset = { 0, 0.32, 0.06 } }) },
			{ 0.62, merge(slam, { RootOffset = { 0, -0.62, -0.1 } }), true },
			{ 0.74, merge(slam, { Waist = { -32, 50, 0 }, RootOffset = { 0, -0.5, -0.08 } }) },
			{ 0.86, merge(slam, { Waist = { -26, 48, 0 }, RootOffset = { 0, -0.42, -0.06 } }) },
			{ 1, rest },
		}),
	}
end

-- STAFF (right hand) ------------------------------------------------------------------------
do
	-- Staff upright beside the body, hand at waist height.
	local stand = merge(STANCE, {
		RightShoulder = { 18, 0, 12 }, RightElbow = { 72, 0, 0 },
		LeftShoulder = { 6, 0, -6 }, LeftElbow = { 18, 0, 0 },
	})
	local cast = merge(ATTACK_STANCE, { Waist = { -4, -10, 0 }, RightShoulder = { 90, 0, 0 }, RightElbow = { 0, 0, 0 }, LeftShoulder = { 70, 0, -20 }, LeftElbow = { 20, 0, 0 } })
	local raised = merge(ATTACK_STANCE, { Waist = { 10, 0, 0 }, Neck = { 12, 0, 0 }, RightShoulder = { 165, 0, 10 }, RightElbow = { 10, 0, 0 }, LeftShoulder = { 120, 0, -30 }, LeftElbow = { 15, 0, 0 } })
	WeaponPoses.STAFF = { Stand = stand, Cast = cast, Raised = raised }
	-- Basic: draw the staff up and back while the off-hand gathers at the chest, then lunge and
	-- thrust both forward together, hold the cast, and recover.
	local gather = merge(ATTACK_STANCE, {
		Waist = { 6, 22, 0 }, Neck = { -2, -18, 0 }, RightShoulder = { 130, 20, 20 }, RightElbow = { 55, 0, 0 },
		LeftShoulder = { 50, 30, -10 }, LeftElbow = { 100, 0, 0 }, RootOffset = { 0, -0.06, 0.06 },
	})
	local thrust = merge(cast, {
		Waist = { -12, -16, 0 }, Neck = { 6, 12, 0 }, RightShoulder = { 96, -4, 0 }, RightElbow = { 0, 0, 0 },
		LeftShoulder = { 82, 0, -16 }, LeftElbow = { 8, 0, 0 }, RootOffset = { 0, -0.18, -0.1 },
	})
	local castHeld = merge(thrust, { Waist = { -9, -12, 0 }, RightShoulder = { 92, 0, 0 }, LeftShoulder = { 72, 0, -18 }, LeftElbow = { 16, 0, 0 }, RootOffset = { 0, -0.14, -0.07 } })
	local staffUp = merge(STANCE, { Waist = { 6, 0, 0 }, Neck = { 10, 0, 0 }, RightShoulder = { 165, 0, 10 }, RightElbow = { 10, 0, 0 }, LeftShoulder = { 20, 0, -18 }, LeftElbow = { 30, 0, 0 } })
	ByWeapon.STAFF = {
		Victory = cheer(staffUp, "RightShoulder"),
		Idle = breathe(stand),
		-- A measured walk.
		Move = walk(stand, nil, { Stride = 25, Lift = 28, Lean = -2, Bob = 0.05 }),
		AttackBasic = clip(0.8, false, { { 0, stand }, { 0.32, gather }, { 0.62, thrust, true }, { 0.8, castHeld }, { 1, stand } }),
		-- Special: gather the staff back (the Charge glow starts), sweep it up overhead leaning
		-- back, then stab it forward at the target with a lunge, hold the cast, recover.
		AttackSpecial = clip(0.9, false, {
			{ 0, stand },
			{ 0.2, gather },
			{ 0.45, raised },
			{ 0.56, merge(raised, { Waist = { 16, 4, 0 }, Neck = { 14, 0, 0 }, RightShoulder = { 172, 6, 12 }, RootOffset = { 0, 0.06, 0.06 } }) },
			{ 0.65, merge(thrust, { Waist = { -14, -14, 0 }, RootOffset = { 0, -0.22, -0.14 } }), true },
			{ 0.8, castHeld },
			{ 1, stand },
		}),
		-- Skill: crouch gathering power, rise onto the toes with both arms climbing overhead,
		-- arch back at the top and thrust the staff skyward as the pillar is called, then hold.
		AttackSkill = clip(1.2, false, {
			{ 0, stand },
			{ 0.15, merge(gather, { Waist = { -10, 14, 0 }, LeftKnee = { -34, 0, 0 }, RightKnee = { -30, 0, 0 }, RootOffset = { 0, -0.3, 0 } }) },
			{ 0.4, merge(raised, { LeftShoulder = { 165, 0, -10 }, RootOffset = { 0, 0.1, 0 } }) },
			{ 0.6, merge(raised, { Waist = { 20, 0, 0 }, Neck = { 18, 0, 0 }, RightShoulder = { 172, 0, 4 }, LeftShoulder = { 170, 0, -4 }, RootOffset = { 0, 0.18, 0 } }) },
			{ 0.7, merge(raised, { Waist = { 12, 0, 0 }, Neck = { 14, 0, 0 }, RightShoulder = { 178, 0, 0 }, RightElbow = { 0, 0, 0 }, LeftShoulder = { 176, 0, 0 }, RootOffset = { 0, 0.22, 0 } }), true },
			{ 0.86, merge(raised, { Waist = { 14, 0, 0 }, RightShoulder = { 175, 0, 0 }, LeftShoulder = { 172, 0, 0 }, RootOffset = { 0, 0.14, 0 } }) },
			{ 1, stand },
		}),
	}
end

-- TOME (floating open book above left hand, right off-hand orb casting) --------------------
do
	-- Healer Stance: open grimoire levitates above the upturned, open left palm at mid-chest.
	-- Right hand relaxed in casting readiness.
	local read = merge(STANCE, {
		Waist = { -2, 6, 0 },
		Neck = { -8, 8, 2 },
		LeftShoulder = { 32, -14, -8 }, -- arm extended forward presenting floating grimoire
		LeftElbow = { 58, 0, 0 },
		LeftWrist = { 173.2, 75.7, -171.4 }, -- palm flat, fully open, facing skyward beneath floating grimoire
		RightShoulder = { 6, 0, 8 },
		RightElbow = { 16, 0, 0 },
		RightWrist = { 0, 0, 0 },
	})
	-- Channel: left hand keeps floating tome steady; right hand pulls back gathering orb energy
	local gather = merge(ATTACK_STANCE, {
		Waist = { 0, 16, 0 },
		Neck = { 0, -6, 0 },
		LeftShoulder = { 35, -10, -6 },
		LeftElbow = { 60, 0, 0 },
		LeftWrist = { -138.0, 74.6, 133.9 },
		RightShoulder = { 32, 18, 22 },
		RightElbow = { 85, 0, 0 },
		RightWrist = { 15, 0, 0 },
	})
	-- Release: right off-hand thrusts open palm forward towards the enemy, releasing the orb
	local release = merge(ATTACK_STANCE, {
		Waist = { -6, -14, 0 },
		Neck = { 2, 8, 0 },
		LeftShoulder = { 33, -12, -6 },
		LeftElbow = { 58, 0, 0 },
		LeftWrist = { 116.8, 66.3, -113.9 },
		RightShoulder = { 92, -6, 4 },
		RightElbow = { 10, 0, 0 },
		RightWrist = { -15, 0, 0 },
	})
	local followThrough = merge(ATTACK_STANCE, {
		Waist = { -4, -8, 0 },
		LeftShoulder = { 33, -12, -6 },
		LeftElbow = { 58, 0, 0 },
		LeftWrist = { 126.2, 71.3, -124.6 },
		RightShoulder = { 75, 0, 12 },
		RightElbow = { 25, 0, 0 },
	})

	WeaponPoses.TOME = { Read = read, Channel = gather, Release = release }
	-- Basic: wind the casting hand further back with the torso, then push the orb out with a
	-- small step in, and ease back to reading.
	local wind = merge(gather, { Waist = { 2, 24, 0 }, Neck = { -2, -12, 0 }, RightShoulder = { 28, 30, 30 }, RightElbow = { 105, 0, 0 }, RootOffset = { 0, -0.04, 0.05 } })
	local push = merge(release, { Waist = { -8, -18, 0 }, RightShoulder = { 96, -8, 2 }, RightElbow = { 4, 0, 0 }, RootOffset = { 0, -0.12, -0.08 } })
	local tomeUp = merge(read, { Waist = { 4, 6, 0 }, Neck = { 6, 8, 2 }, RightShoulder = { 158, 0, 22 }, RightElbow = { 20, 0, 0 }, RightWrist = { 0, 0, 0 } })
	ByWeapon.TOME = {
		Victory = cheer(tomeUp, "RightShoulder"),
		Idle = floatIdle(read, 3.2),
		-- A gliding walk: short steps, little bob, the tome steady.
		Move = walk(read, nil, { Stride = 22, Lift = 24, Bob = 0.04 }),
		AttackBasic = clip(0.8, false, {
			{ 0, read },
			{ 0.3, wind },
			{ 0.55, push, true },
			{ 0.72, followThrough },
			{ 1, read },
		}),
		-- Special: the casting hand circles back with the torso (the Charge glow gathers), rears
		-- further, then pushes out with a step in and holds before easing back to reading.
		AttackSpecial = clip(0.95, false, {
			{ 0, read },
			{ 0.16, merge(gather, { Waist = { 2, 14, 0 }, RightShoulder = { 40, 20, 26 }, RightElbow = { 90, 0, 0 } }) },
			{ 0.42, merge(gather, { LeftShoulder = { 42, -6, -10 }, RightShoulder = { 62, 28, 42 }, RightElbow = { 100, 0, 0 }, Waist = { 6, 26, 0 }, Neck = { -2, -12, 0 }, RootOffset = { 0, -0.04, 0.06 } }) },
			{ 0.65, merge(release, { RightShoulder = { 104, -8, 0 }, RightElbow = { 4, 0, 0 }, Waist = { -10, -20, 0 }, RootOffset = { 0, -0.12, -0.1 } }), true },
			{ 0.8, merge(followThrough, { Waist = { -6, -12, 0 }, RootOffset = { 0, -0.08, -0.06 } }) },
			{ 1, read },
		}),
		AttackSkill = clip(1.2, false, {
			{ 0, read },
			{ 0.35, merge(gather, { LeftShoulder = { 135, 0, -15 }, LeftElbow = { 15, 0, 0 }, RightShoulder = { 135, 0, 15 }, RightElbow = { 15, 0, 0 }, Waist = { 12, 0, 0 }, Neck = { 18, 0, 0 } }) },
			{ 0.65, merge(ATTACK_STANCE, { LeftShoulder = { 110, 0, -65 }, LeftElbow = { 12, 0, 0 }, RightShoulder = { 110, 0, 65 }, RightElbow = { 12, 0, 0 }, Waist = { -8, 0, 0 }, RootOffset = { 0, -0.15, 0 } }) },
			{ 0.85, merge(ATTACK_STANCE, { LeftShoulder = { 70, 0, -35 }, RightShoulder = { 70, 0, 35 }, Waist = { -2, 0, 0 } }) },
			{ 1, read },
		}),
	}
end

-- Shared states -----------------------------------------------------------------------------
local Shared: { [string]: Clip } = {
	-- Weapon sets have their own Victory; this is the fallback for anything else.
	Victory = cheer(merge(STANCE, { Waist = { 4, 0, 0 }, Neck = { 8, 0, 0 }, RightShoulder = { 160, 0, 14 }, RightElbow = { 30, 0, 0 } }), "RightShoulder"),
	Hit = clip(0.35, false, {
		{ 0, {} },
		{ 0.3, { Waist = { 14, 0, 0 }, Neck = { 12, 0, 0 }, LeftShoulder = { -10, 0, -25 }, RightShoulder = { -10, 0, 25 }, RootOffset = { 0, 0, 0.15 } } },
		{ 1, {} },
	}),
	-- Collapsed on the knees, slumped forward.
	Coma = clip(2.4, true, {
		{ 0, { Waist = { -35, 0, 0 }, Neck = { -30, 0, 0 }, LeftHip = { 90, 0, -10 }, RightHip = { 90, 0, 10 }, LeftKnee = { -120, 0, 0 }, RightKnee = { -120, 0, 0 }, LeftAnkle = { 30, 0, 0 }, RightAnkle = { 30, 0, 0 }, LeftShoulder = { 20, 0, -10 }, RightShoulder = { 20, 0, 10 }, RootOffset = { 0, -1.35, 0 } } },
		{ 0.5, { Waist = { -38, 0, 0 }, Neck = { -32, 0, 0 }, LeftHip = { 90, 0, -10 }, RightHip = { 90, 0, 10 }, LeftKnee = { -120, 0, 0 }, RightKnee = { -120, 0, 0 }, LeftAnkle = { 30, 0, 0 }, RightAnkle = { 30, 0, 0 }, LeftShoulder = { 18, 0, -10 }, RightShoulder = { 18, 0, 10 }, RootOffset = { 0, -1.38, 0 } } },
		{ 1, { Waist = { -35, 0, 0 }, Neck = { -30, 0, 0 }, LeftHip = { 90, 0, -10 }, RightHip = { 90, 0, 10 }, LeftKnee = { -120, 0, 0 }, RightKnee = { -120, 0, 0 }, LeftAnkle = { 30, 0, 0 }, RightAnkle = { 30, 0, 0 }, LeftShoulder = { 20, 0, -10 }, RightShoulder = { 20, 0, 10 }, RootOffset = { 0, -1.35, 0 } } },
	}),
	-- Loot hauled overhead with both hands (replaces HoldingAnimationController's arm override).
	Carry = clip(1.0, true, {
		{ 0, merge(STANCE, { LeftShoulder = { 165, 0, -8 }, RightShoulder = { 165, 0, 8 }, LeftElbow = { 25, 0, 0 }, RightElbow = { 25, 0, 0 } }) },
		{ 1, merge(STANCE, { LeftShoulder = { 165, 0, -8 }, RightShoulder = { 165, 0, 8 }, LeftElbow = { 25, 0, 0 }, RightElbow = { 25, 0, 0 } }) },
	}),
	-- Lying on the back (the root tips the whole body); the bed supplies the surface.
	Sleep = clip(4.0, true, {
		{ 0, { Root = { 90, 0, 0 }, RootOffset = { 0, -2.4, 0 }, LeftShoulder = { 10, 0, -10 }, RightShoulder = { 10, 0, 10 }, Neck = { -6, 0, 0 } } },
		{ 0.5, { Root = { 90, 0, 0 }, RootOffset = { 0, -2.4, 0 }, LeftShoulder = { 10, 0, -10 }, RightShoulder = { 10, 0, 10 }, Neck = { -6, 0, 0 }, Waist = { 2, 0, 0 } } },
		{ 1, { Root = { 90, 0, 0 }, RootOffset = { 0, -2.4, 0 }, LeftShoulder = { 10, 0, -10 }, RightShoulder = { 10, 0, 10 }, Neck = { -6, 0, 0 } } },
	}),
	-- Facility work: two-handed hammering in front of the body.
	Labor = clip(0.9, true, {
		{ 0, merge(STANCE, { Waist = { -10, 0, 0 }, RightShoulder = { 130, 0, 0 }, RightElbow = { 60, 0, 0 }, LeftShoulder = { 120, 0, 0 }, LeftElbow = { 70, 0, 0 } }) },
		{ 0.5, merge(STANCE, { Waist = { -22, 0, 0 }, RightShoulder = { 55, 0, 0 }, RightElbow = { 20, 0, 0 }, LeftShoulder = { 50, 0, 0 }, LeftElbow = { 25, 0, 0 } }) },
		{ 1, merge(STANCE, { Waist = { -10, 0, 0 }, RightShoulder = { 130, 0, 0 }, RightElbow = { 60, 0, 0 }, LeftShoulder = { 120, 0, 0 }, LeftElbow = { 70, 0, 0 } }) },
	}),
	-- Market Slot 1 (Bazaar Hawker): beckons shoppers and sweeps across counter wares.
	MarketHawker = (function(): Clip
		local hawkerBase = merge(STANCE, {
			Waist = { -4, 8, 0 }, Neck = { 2, -6, 0 },
			LeftShoulder = { 28, -12, -10 }, LeftElbow = { 65, 0, 0 },
			RightShoulder = { 35, 10, 12 }, RightElbow = { 55, 0, 0 },
		})
		return clip(2.6, true, {
			{ 0, hawkerBase },
			{ 0.28, merge(STANCE, {
				Waist = { 4, -14, 0 }, Neck = { 6, -12, 0 },
				LeftShoulder = { 95, -22, -8 }, LeftElbow = { 115, 0, 0 },
				RightShoulder = { 138, 12, 24 }, RightElbow = { 25, 0, 0 },
				RootOffset = { 0, 0.05, 0 },
			}) },
			{ 0.56, merge(STANCE, {
				Waist = { -10, 12, 0 }, Neck = { -4, 10, 0 },
				LeftShoulder = { 68, -28, -22 }, LeftElbow = { 20, 0, 0 },
				RightShoulder = { 72, 26, 22 }, RightElbow = { 18, 0, 0 },
				RootOffset = { 0, -0.04, 0 },
			}) },
			{ 0.80, merge(STANCE, {
				Waist = { -6, -6, 0 }, Neck = { -8, -4, 0 },
				LeftShoulder = { 22, -10, -12 }, LeftElbow = { 70, 0, 0 },
				RightShoulder = { 62, -14, 16 }, RightElbow = { 35, 0, 0 },
			}) },
			{ 1, hawkerBase },
		})
	end)(),
	-- Market Slot 2 (Crate Stockist): scoops bundles, lifts onto the counter, straightens stack.
	MarketStock = (function(): Clip
		local stockBase = merge(STANCE, {
			Waist = { -8, 0, 0 }, Neck = { -8, 0, 0 },
			LeftShoulder = { 46, -10, -8 }, LeftElbow = { 62, 0, 0 },
			RightShoulder = { 46, 10, 8 }, RightElbow = { 62, 0, 0 },
		})
		return clip(2.2, true, {
			{ 0, stockBase },
			{ 0.25, merge(STANCE, {
				Waist = { -22, -8, 0 }, Neck = { -14, -6, 0 },
				LeftHip = { 24, 0, -4 }, RightHip = { 18, 0, 4 },
				LeftKnee = { -34, 0, 0 }, RightKnee = { -30, 0, 0 },
				LeftShoulder = { 58, -6, -6 }, LeftElbow = { 40, 0, 0 },
				RightShoulder = { 58, 6, 6 }, RightElbow = { 40, 0, 0 },
				RootOffset = { 0, -0.26, 0 },
			}) },
			{ 0.55, merge(STANCE, {
				Waist = { -6, 6, 0 }, Neck = { -4, 6, 0 },
				LeftShoulder = { 84, -8, -10 }, LeftElbow = { 28, 0, 0 },
				RightShoulder = { 86, 8, 10 }, RightElbow = { 24, 0, 0 },
				RootOffset = { 0, 0.03, 0 },
			}) },
			{ 0.78, merge(STANCE, {
				Waist = { -12, 10, 0 }, Neck = { -10, 8, 0 },
				LeftShoulder = { 64, -18, -12 }, LeftElbow = { 48, 0, 0 },
				RightShoulder = { 70, -10, 14 }, RightElbow = { 44, 0, 0 },
			}) },
			{ 1, stockBase },
		})
	end)(),
	-- Market Slot 2 hauling walk: chest-height two-handed crate carry with walking legs.
	MarketCarry = walk(merge(STANCE, {
		Waist = { -6, 0, 0 }, Neck = { -4, 0, 0 },
		LeftShoulder = { 82, -16, -6 }, LeftElbow = { 62, 0, 0 },
		RightShoulder = { 82, 16, 6 }, RightElbow = { 62, 0, 0 },
	})),
	-- Market Slot 3 (Relic Appraiser): lifts artifact toward the light, examines, polishes.
	MarketAppraiser = (function(): Clip
		local appraiseBase = merge(STANCE, {
			Waist = { -4, -6, 0 }, Neck = { -10, 8, 0 },
			LeftShoulder = { 48, -16, -8 }, LeftElbow = { 78, 0, 0 },
			RightShoulder = { 34, 14, 10 }, RightElbow = { 68, 0, 0 },
		})
		return clip(3.0, true, {
			{ 0, appraiseBase },
			{ 0.30, merge(STANCE, {
				Waist = { 4, -10, 0 }, Neck = { 8, 14, -8 },
				LeftShoulder = { 92, -14, -6 }, LeftElbow = { 62, 0, 0 },
				RightShoulder = { 42, 12, 12 }, RightElbow = { 82, 0, 0 },
				RootOffset = { 0, 0.03, 0 },
			}) },
			{ 0.62, merge(STANCE, {
				Waist = { -8, 4, 0 }, Neck = { -14, 4, 6 },
				LeftShoulder = { 56, -18, -8 }, LeftElbow = { 74, 0, 0 },
				RightShoulder = { 66, 22, -6 }, RightElbow = { 72, 0, 0 },
			}) },
			{ 0.84, merge(STANCE, {
				Waist = { -2, -4, 0 }, Neck = { -18, 6, 0 },
				LeftShoulder = { 50, -16, -8 }, LeftElbow = { 76, 0, 0 },
				RightShoulder = { 38, 16, 8 }, RightElbow = { 64, 0, 0 },
			}) },
			{ 1, appraiseBase },
		})
	end)(),
	-- Market Slot 4 (Quartermaster Ledger): holds open book in left arm, tallies & scribes.
	MarketLedger = (function(): Clip
		local ledgerBase = merge(STANCE, {
			Waist = { -6, -4, 0 }, Neck = { -14, 6, 0 },
			LeftShoulder = { 38, -18, -6 }, LeftElbow = { 82, 0, 0 },
			RightShoulder = { 44, 18, -4 }, RightElbow = { 76, 0, 0 },
		})
		return clip(2.7, true, {
			{ 0, ledgerBase },
			{ 0.24, merge(STANCE, {
				Waist = { 2, 10, 0 }, Neck = { 4, 14, 0 },
				LeftShoulder = { 36, -18, -6 }, LeftElbow = { 84, 0, 0 },
				RightShoulder = { 78, -6, 10 }, RightElbow = { 28, 0, 0 },
			}) },
			{ 0.52, merge(STANCE, {
				Waist = { -8, -6, 0 }, Neck = { -16, 8, 0 },
				LeftShoulder = { 40, -18, -6 }, LeftElbow = { 80, 0, 0 },
				RightShoulder = { 52, 26, -10 }, RightElbow = { 86, 0, 0 },
			}) },
			{ 0.74, merge(STANCE, {
				Waist = { -8, -2, 0 }, Neck = { -16, 2, 0 },
				LeftShoulder = { 40, -18, -6 }, LeftElbow = { 80, 0, 0 },
				RightShoulder = { 48, 12, 2 }, RightElbow = { 78, 0, 0 },
			}) },
			{ 1, ledgerBase },
		})
	end)(),
	-- Training Slot 3 (Martial Kata): horse-stance ward, lunging strike, crescent overhead block.
	TrainingKata = (function(): Clip
		local kataBase = merge(ATTACK_STANCE, {
			Waist = { -4, -12, 0 }, Neck = { 0, 12, 0 },
			LeftShoulder = { 54, -14, -12 }, LeftElbow = { 78, 0, 0 },
			RightShoulder = { 38, 12, 14 }, RightElbow = { 92, 0, 0 },
		})
		return clip(2.8, true, {
			{ 0, kataBase },
			{ 0.25, merge(ATTACK_STANCE, {
				Waist = { -8, 22, 0 }, Neck = { -2, -18, 0 },
				LeftHip = { 28, 0, -14 }, RightHip = { 24, 0, 14 },
				LeftKnee = { -44, 0, 0 }, RightKnee = { -42, 0, 0 },
				LeftAnkle = { 16, 0, 0 }, RightAnkle = { 16, 0, 0 },
				LeftShoulder = { 76, -24, -18 }, LeftElbow = { 42, 0, 0 },
				RightShoulder = { 24, 20, 22 }, RightElbow = { 105, 0, 0 },
				RootOffset = { 0, -0.32, 0 },
			}) },
			{ 0.55, merge(ATTACK_STANCE, {
				Waist = { -16, -26, 0 }, Neck = { 4, 22, 0 },
				LeftHip = { 36, 0, -8 }, RightHip = { -18, 0, 8 },
				LeftKnee = { -46, 0, 0 }, RightKnee = { -16, 0, 0 },
				LeftAnkle = { 12, 0, 0 }, RightAnkle = { 28, 0, 0 },
				LeftShoulder = { 28, -10, -20 }, LeftElbow = { 88, 0, 0 },
				RightShoulder = { 92, -8, -4 }, RightElbow = { 8, 0, 0 },
				RootOffset = { 0, -0.24, -0.18 },
			}) },
			{ 0.80, merge(ATTACK_STANCE, {
				Waist = { 6, 8, 0 }, Neck = { 6, -6, 0 },
				LeftHip = { 16, 0, -6 }, RightHip = { -10, 0, 6 },
				LeftKnee = { -20, 0, 0 }, RightKnee = { -18, 0, 0 },
				LeftAnkle = { 6, 0, 0 }, RightAnkle = { 20, 0, 0 },
				LeftShoulder = { 138, 0, -18 }, LeftElbow = { 34, 0, 0 },
				RightShoulder = { 68, 16, 18 }, RightElbow = { 56, 0, 0 },
				RootOffset = { 0, -0.06, 0 },
			}) },
			{ 1, kataBase },
		})
	end)(),
	-- Training Slot 4 (Drill Sergeant): points cadence, surveys sparring circle, rallies fist-to-palm.
	TrainingCoach = (function(): Clip
		local coachBase = merge(STANCE, {
			Waist = { 4, -8, 0 }, Neck = { 2, 10, 0 },
			LeftShoulder = { -8, 12, -16 }, LeftElbow = { 58, 0, 0 },
			RightShoulder = { 22, 8, 12 }, RightElbow = { 64, 0, 0 },
		})
		return clip(2.5, true, {
			{ 0, coachBase },
			{ 0.28, merge(STANCE, {
				Waist = { -4, -18, 0 }, Neck = { 2, 16, 0 },
				LeftShoulder = { -10, 14, -18 }, LeftElbow = { 62, 0, 0 },
				RightShoulder = { 94, -6, 6 }, RightElbow = { 6, 0, 0 },
				RootOffset = { 0, 0.04, 0 },
			}) },
			{ 0.56, merge(STANCE, {
				Waist = { 4, 16, 0 }, Neck = { 4, -14, 0 },
				LeftShoulder = { 46, -12, -10 }, LeftElbow = { 68, 0, 0 },
				RightShoulder = { 62, 18, 14 }, RightElbow = { 52, 0, 0 },
			}) },
			{ 0.78, merge(STANCE, {
				Waist = { -6, 0, 0 }, Neck = { -4, 0, 0 },
				LeftShoulder = { 58, -22, -6 }, LeftElbow = { 76, 0, 0 },
				RightShoulder = { 60, 22, 6 }, RightElbow = { 78, 0, 0 },
				RootOffset = { 0, -0.04, 0 },
			}) },
			{ 1, coachBase },
		})
	end)(),
}

-- Attack markers -----------------------------------------------------------------------------
-- Release: the fraction of an attack clip where the blow lands (melee) or the projectile leaves
-- the weapon (ranged). HeroActionTiming reads it on the server to schedule the hit and on the
-- client to time the effect, so the two cannot drift. Nock: the bow arrow is back on the string.
-- A hero override's attack clip sets its own Markers, and may add Charge: a cosmetic,
-- client-only cue before Release where wind-up VFX start (SkillVfx.PlayCharge). The server
-- ignores it.
local RELEASE_MARKERS: { [string]: { [string]: number } } = {
	UNARMED = { AttackBasic = 0.35, AttackSpecial = 0.55, AttackSkill = 0.6 },
	BOW = { AttackBasic = 0.72, AttackSpecial = 0.78, AttackSkill = 0.72 },
	SWORD_SHIELD = { AttackBasic = 0.62, AttackSpecial = 0.6, AttackSkill = 0.62 },
	DAGGERS = { AttackBasic = 0.3, AttackSpecial = 0.6, AttackSkill = 0.8 },
	AXE = { AttackBasic = 0.65, AttackSpecial = 0.68, AttackSkill = 0.62 },
	STAFF = { AttackBasic = 0.62, AttackSpecial = 0.65, AttackSkill = 0.7 },
	TOME = { AttackBasic = 0.55, AttackSpecial = 0.65, AttackSkill = 0.65 },
}
-- Charge: where the weapon Special and Skill clips' wind-up starts (their anticipation key), so
-- the shared styles' wind-up VFX (SkillVfx chargers) play for every hero using these clips.
local CHARGE_MARKERS: { [string]: { [string]: number } } = {
	BOW = { AttackSpecial = 0.18, AttackSkill = 0.2 },
	SWORD_SHIELD = { AttackSpecial = 0.2, AttackSkill = 0.18 },
	DAGGERS = { AttackSpecial = 0.15, AttackSkill = 0.1 },
	AXE = { AttackSpecial = 0.2, AttackSkill = 0.18 },
	STAFF = { AttackSpecial = 0.2, AttackSkill = 0.15 },
	TOME = { AttackSpecial = 0.16, AttackSkill = 0.12 },
}
local BOW_NOCK = 0.9
for weaponType, releases in RELEASE_MARKERS do
	for state, release in releases do
		local attack = ByWeapon[weaponType][state]
		attack.Markers = if weaponType == "BOW" then { Release = release, Nock = BOW_NOCK } else { Release = release }
		local charges = CHARGE_MARKERS[weaponType]
		local charge = charges and charges[state]
		if charge then (attack.Markers :: any).Charge = charge end
	end
end

-- Per-hero signature overrides --------------------------------------------------------------
-- Each hero's ultimate (and a few specials) gets its own clip, built from its weapon's poses
-- (WeaponPoses). Overrides only apply while the hero holds that weapon (OVERRIDE_WEAPON), so
-- an unarmed hero falls back to the UNARMED set on both server and client. Every attack
-- override sets its own Markers; Release is where the server lands the hit.
local OVERRIDE_WEAPON: { [string]: string } = {
	hero_han = "DAGGERS",
	hero_aaron = "SWORD_SHIELD",
	hero_catio = "AXE",
	hero_valeria = "TOME",
	hero_ignis = "SWORD_SHIELD",
	hero_jenna = "BOW",
	hero_velkist = "DAGGERS",
	hero_eolka = "STAFF",
	hero_morrigan = "SWORD_SHIELD",
	hero_archon = "DAGGERS",
	hero_solaris = "STAFF",
	hero_astrea = "BOW",
	hero_edis = "DAGGERS",
	hero_gide = "AXE",
	hero_rhyman = "AXE",
	hero_shurn = "STAFF",
	hero_diran = "TOME",
	hero_vane = "STAFF",
	hero_aeli = "BOW",
	hero_isabelle = "BOW",
	hero_nyx = "DAGGERS",
	hero_caspian = "SWORD_SHIELD",
	hero_seraphine = "STAFF",
	hero_rook = "AXE",
}

-- `draw` (bow clips): when the draw hand takes the string and reaches full draw (Clip.Draw).
local function signature(duration: number, keys: { { any } }, markers: { [string]: number }, draw: Draw?): Clip
	local result = clip(duration, false, keys)
	result.Markers = markers
	result.Draw = draw
	return result
end

local Overrides: { [string]: { [string]: Clip } } = {}
-- A second clip a hero alternates with for a state (HeroAnimator plays them in turn; only
-- AttackBasic so far). Cosmetic: the server times the hit from the main clip's Release, so an
-- alternate must share it (tests).
local Alternates: { [string]: { [string]: Clip } } = {}

-- Jenna (BOW): Wind-Step Shot kit. Idle is the Wind-Scout ready stance; Sylphid Arrow Storm
-- is a backward wind-step leap that looses the flare arrow skyward at the top of the jump.
do
	local p = WeaponPoses.BOW
	local tuck: Pose = { LeftHip = { 35, 0, -6 }, RightHip = { 10, 0, 6 }, LeftKnee = { -70, 0, 0 }, RightKnee = { -45, 0, 0 }, LeftAnkle = { 20, 0, 0 }, RightAnkle = { 15, 0, 0 } }
	local airborne = merge(merge(p.SkyAim, tuck), { RootOffset = { 0, 0.4, 0.35 } })
	Overrides.hero_jenna = {
		Idle = breathe({
			Waist = { -3, -18, 0 }, Neck = { 0, 16, 0 },
			LeftShoulder = { 10, 0, -10 }, LeftElbow = { 50, 0, 0 },
			RightShoulder = { 14, 10, -18 }, RightElbow = { 48, 0, 0 },
			LeftHip = { 10, -4, -4 }, LeftKnee = { -16, 0, 0 }, LeftAnkle = { 6, 0, 0 },
			RightHip = { -8, 6, 5 }, RightKnee = { -12, 0, 0 }, RightAnkle = { 20, 0, 0 },
		}, 3.6),
		AttackSkill = signature(1.1, {
			{ 0, p.Carry },
			{ 0.18, merge(merge(p.Aim, p.Crouch), { Waist = { -12, -20, 0 } }) },
			{ 0.42, airborne },
			{ 0.62, merge(airborne, { RightShoulder = { 136, 26, -10 }, RightElbow = { 145, 0, 0 } }) },
			{ 0.72, merge(airborne, { LeftShoulder = { 150, 0, 0 }, RightShoulder = { 110, 45, -35 }, RightElbow = { 115, 0, 0 }, RootOffset = { 0, 0.3, 0.4 } }) },
			{ 0.86, merge(merge(p.Release, p.Crouch), { Waist = { -14, -10, 0 } }) },
			{ 1, p.Carry },
		}, { Release = 0.72, Nock = 0.92 }, { Set = 0.18, Full = 0.62 }),
	}
end

-- Astrea (BOW): her full kit, from her second reference art.
-- Idle: poised mid-draw. The bow is held low and forward in the left hand, canted on the
-- diagonal; the right hand rests at the string by her chest with an arrow nocked; her waist is
-- turned so the bow shoulder leads, her chin turned towards the target, her weight on the right
-- leg with the left knee softly in.
-- Astral Arrow (Basic): a quick, elegant draw from that stance and a release whose draw hand
-- flows back and out in a flourish.
-- Nebula Piercer (Special): she steps into a wide archer's stance side-on and takes a long full
-- draw. From Charge she holds it and gathers the shot: she sinks lower, the draw creeps back
-- past her ear and the bow trembles under the load. The release snaps the bow arm up and kicks
-- her back half a step; she rides the recoil out and settles.
-- Constellation Judgment (Skill): she coils against the turn, then pirouettes a full circle on
-- her left foot with her arms flung wide (Charge, the spin is four Root keys blended at a
-- steady rate), lands in a planted stance already raising the bow, draws to the sky arched
-- back and looses. She holds the follow-through watching the arrow, raises her right hand to
-- the stars as the constellation draws, and sweeps it down at the target to call them.
do
	local p = WeaponPoses.BOW
	local legs: Pose = {
		LeftHip = { 6, -4, -3 }, LeftKnee = { -10, 0, 0 }, LeftAnkle = { 4, 0, 3 },
		RightHip = { -8, 4, 5 }, RightKnee = { -6, 0, 0 }, RightAnkle = { 14, 0, -5 },
		RootOffset = { 0, -0.04, 0 },
	}
	local poised: Pose = merge(legs, {
		Waist = { 0, -8, 1 }, Neck = { -2, 8, -2 },
		LeftShoulder = { -8, 0, -20 }, LeftElbow = { 18, 0, 0 }, LeftWrist = { 0, 0, -14 },
		RightShoulder = { 4, -14, 54 }, RightElbow = { 44, 0, 0 }, RightWrist = { -18, 0, 14 },
	})

	-- Astral Arrow: a dancer's archer. Fully side-on and upright with the chest lifted and the
	-- chin raised, her front foot pointed at the target and her weight on the back leg; a high
	-- anchor at the corner of her mouth; the loose flows back and out wide.
	local astralLegs: Pose = {
		LeftHip = { 4, -20, -8 }, LeftKnee = { -2, 0, 0 }, LeftAnkle = { 20, 0, 4 },
		RightHip = { -4, 10, 6 }, RightKnee = { -14, 0, 0 }, RightAnkle = { 12, 0, -6 },
		RootOffset = { 0, -0.06, 0 },
	}
	local astral: Pose = merge(astralLegs, { Root = { 0, -60, 0 }, Waist = { 4, -25, 0 }, Neck = { 34, 84, -38 },
		LeftShoulder = { 95, -8, -81 }, LeftElbow = { 0, 0, 0 }, LeftWrist = { -10, -6, -4 } })
	local aim = merge(astral, { Waist = { 4, 43, 0 }, Neck = { 4, 17, -5 },
		LeftShoulder = { 80, -21, 13 }, LeftElbow = { 50, 0, 0 }, LeftWrist = { -37, 16, -32 },
		RightShoulder = { -51, 20, -147 }, RightElbow = { 62, 0, 0 } })
	local drawn = merge(astral, { RightShoulder = { -134, 63, -82 }, RightElbow = { 84, 0, 0 } })
	local flourish = merge(astral, { RightShoulder = { 66, 70, 46 }, RightElbow = { 96, 0, 0 } })
	local settle = merge(flourish, { Neck = { 20, 80, -20 }, LeftShoulder = { 82, -8, -81 }, LeftElbow = { 12, 0, 0 }, RightElbow = { 70, 0, 0 } })

	-- Nebula Piercer: a wide, low side-on stance, the bow level over the front knee; the long
	-- draw goes deeper than her Basic, back past her jaw, and creeps while the shot gathers.
	local wide: Pose = {
		LeftHip = { 30, -10, -14 }, LeftKnee = { -40, 0, 0 }, LeftAnkle = { 10, 0, 12 },
		RightHip = { -20, 10, 14 }, RightKnee = { -14, 0, 0 }, RightAnkle = { 28, 0, -12 },
		RootOffset = { 0, -0.3, 0 },
	}
	local nebula: Pose = merge(wide, { Root = { 0, -70, 0 }, Waist = { -4, -22, 0 }, Neck = { 4, 90, 0 },
		LeftShoulder = { 97, -4, -93 }, LeftElbow = { 0, 0, 0 }, LeftWrist = { -5, -3, 1 } })
	local sideOn = merge(nebula, { Waist = { -4, 54, 0 }, Neck = { -1, 16, 4 },
		LeftShoulder = { 71, -12, 16 }, LeftElbow = { 50, 0, 0 }, LeftWrist = { -26, 10, -34 },
		RightShoulder = { -51, 11, -141 }, RightElbow = { 62, 0, 0 } })
	local fullDraw = merge(nebula, { RightShoulder = { 153, 84, -11 }, RightElbow = { 130, 0, 0 } })
	-- The held charge: lower, with a tremor in the bow arm between the keys.
	local gather = merge(fullDraw, { Waist = { -6, -24, 0 }, RootOffset = { 0, -0.38, 0 } })
	local tremble = merge(gather, { Waist = { -5, -23, 2 }, LeftShoulder = { 95, -4, -91 } })
	local peak = merge(gather, { Waist = { -8, -26, 0 }, LeftShoulder = { 98, -4, -94 }, RootOffset = { 0, -0.42, 0 } })
	local strain = merge(peak, { Waist = { -7, -25, -2 }, LeftShoulder = { 96, -4, -92 } })
	local recoil = merge(nebula, {
		Waist = { 4, -20, 0 }, LeftShoulder = { 106, -4, -93 },
		RightShoulder = { 23, 26, 80 }, RightElbow = { 140, 0, 0 },
		RootOffset = { 0, -0.26, 0.25 },
	})
	local kick = merge(recoil, { Waist = { 9, -18, 0 }, LeftShoulder = { 118, -4, -93 }, RootOffset = { 0, -0.2, 0.4 } })
	local recover = merge(recoil, { LeftShoulder = { 78, -4, -93 }, LeftElbow = { 18, 0, 0 }, RightElbow = { 90, 0, 0 }, RootOffset = { 0, -0.16, 0.15 } })

	-- Constellation Judgment
	local coil: Pose = {
		Root = { 0, -25, 0 },
		Waist = { -8, -30, 0 }, Neck = { 0, 24, 0 },
		LeftShoulder = { 40, 0, -20 }, LeftElbow = { 60, 0, 0 },
		RightShoulder = { 20, 0, 30 }, RightElbow = { 50, 0, 0 },
		LeftHip = { 25, 0, -6 }, LeftKnee = { -40, 0, 0 }, LeftAnkle = { 12, 0, 0 },
		RightHip = { 5, 0, 6 }, RightKnee = { -35, 0, 0 }, RightAnkle = { 20, 0, 0 },
		RootOffset = { 0, -0.35, 0 },
	}
	-- Up on the left toes, right foot tucked to the knee, arms carried wide by the turn.
	local pirouette: Pose = {
		Waist = { 4, 25, 0 }, Neck = { -4, 30, 0 },
		LeftShoulder = { 25, 0, -80 }, LeftElbow = { 8, 0, 0 },
		RightShoulder = { 25, 0, 75 }, RightElbow = { 15, 0, 0 },
		LeftHip = { 2, 0, -2 }, LeftKnee = { -4, 0, 0 }, LeftAnkle = { 25, 0, 0 },
		RightHip = { 35, 0, 14 }, RightKnee = { -85, 0, 0 }, RightAnkle = { 30, 0, 0 },
		RootOffset = { 0, 0.18, 0 },
	}
	-- A full turn to the left. Each key is under 180 degrees from the last, so the blend
	-- always takes the short way round and the turn never doubles back.
	local spinA = merge(pirouette, { Root = { 0, 100, 0 } })
	local spinB = merge(pirouette, { Root = { 0, -140, 0 }, Waist = { 6, 18, 0 }, LeftShoulder = { 60, 0, -70 }, RightShoulder = { 50, 0, 65 }, RootOffset = { 0, 0.26, 0 } })
	local spinC = merge(pirouette, { Root = { 0, -30, 0 }, Waist = { 10, 8, 0 }, Neck = { 4, 16, 0 }, LeftShoulder = { 110, 0, -30 }, RightShoulder = { 80, 10, 30 }, RightElbow = { 40, 0, 0 }, RightHip = { 20, 0, 12 }, RightKnee = { -50, 0, 0 }, RootOffset = { 0, 0.12, 0 } })
	-- She lands planted and side-on, arched back with the bow raised 60 degrees to the stars.
	local skyLegs: Pose = {
		LeftHip = { 26, -8, -10 }, LeftKnee = { -30, 0, 0 }, LeftAnkle = { 4, 0, 8 },
		RightHip = { -18, 8, 10 }, RightKnee = { -14, 0, 0 }, RightAnkle = { 24, 0, -8 },
		RootOffset = { 0, -0.22, 0 },
	}
	local starward: Pose = merge(skyLegs, { Root = { 0, -40, 0 }, Waist = { 22, -20, 0 }, Neck = { 39, 43, -40 },
		LeftShoulder = { 116, -54, -27 }, LeftElbow = { 14, 0, 0 }, LeftWrist = { -24, 7, -11 } })
	local land = merge(starward, { Waist = { 22, 12, 0 }, Neck = { 29, 16, -25 },
		LeftShoulder = { 121, -39, 10 }, LeftElbow = { 42, 0, 0 }, LeftWrist = { -33, 11, -24 },
		RightShoulder = { 82, -6, -52 }, RightElbow = { 63, 0, 0 } })
	local skyDraw = merge(starward, { RightShoulder = { 85, 37, -65 }, RightElbow = { 103, 0, 0 } })
	local skyHold = merge(skyDraw, { Waist = { 26, -20, 0 }, RootOffset = { 0, -0.18, 0 } })
	local loose = merge(starward, { Waist = { 26, -18, 0 }, RightShoulder = { 4, 54, 32 }, RightElbow = { 130, 0, 0 }, RootOffset = { 0, -0.14, 0.06 } })
	local watch = merge(loose, { Waist = { 20, -16, 0 }, LeftShoulder = { 120, -54, -27 }, RightElbow = { 110, 0, 0 }, RootOffset = { 0, -0.12, 0 } })
	local command: Pose = {
		Waist = { 10, -6, 0 }, Neck = { 18, 6, 0 },
		LeftShoulder = { 60, 0, -24 }, LeftElbow = { 20, 0, 0 },
		RightShoulder = { 165, 0, 12 }, RightElbow = { 8, 0, 0 },
		LeftHip = { 8, -4, -4 }, LeftKnee = { -8, 0, 0 }, LeftAnkle = { 4, 0, 0 },
		RightHip = { -6, 0, 5 }, RightKnee = { -4, 0, 0 }, RightAnkle = { 8, 0, 0 },
		RootOffset = { 0, 0.05, 0 },
	}
	local judgment: Pose = {
		Waist = { -10, -12, 0 }, Neck = { -6, 10, 0 },
		LeftShoulder = { 30, 0, -40 }, LeftElbow = { 15, 0, 0 },
		RightShoulder = { 70, -10, 10 }, RightElbow = { 5, 0, 0 },
		LeftHip = { 24, 0, -8 }, LeftKnee = { -26, 0, 0 }, LeftAnkle = { 4, 0, 0 },
		RightHip = { -16, 0, 8 }, RightKnee = { -10, 0, 0 }, RightAnkle = { 20, 0, 0 },
		RootOffset = { 0, -0.15, 0 },
	}

	Overrides.hero_astrea = {
		Idle = breathe(poised, 3.6),
		AttackBasic = signature(0.8, {
			{ 0, poised },
			{ 0.22, aim },
			{ 0.55, drawn },
			{ 0.68, flourish },
			{ 0.84, settle },
			{ 1, poised },
		}, { Release = 0.68, Nock = 0.92 }, { Set = 0.22, Full = 0.55, Anchor = { 0.12, -0.22, -0.45 } }),
		-- Played over her 0.7 s attack interval, so the draw is quick and the charge takes more
		-- than half the clip (Charge to Release).
		AttackSpecial = signature(0.8, {
			{ 0, poised },
			{ 0.1, sideOn },
			{ 0.22, fullDraw },
			{ 0.36, gather },
			{ 0.46, tremble },
			{ 0.56, peak },
			{ 0.64, strain },
			{ 0.71, peak },
			{ 0.74, recoil },
			{ 0.8, kick },
			{ 0.9, recover },
			{ 1, poised },
		}, { Charge = 0.22, Release = 0.74, Nock = 0.94 }, { Set = 0.1, Full = 0.24, Anchor = { 0.1, -0.35, 0.1 } }),
		AttackSkill = signature(1.4, {
			{ 0, poised },
			{ 0.07, coil },
			{ 0.15, spinA, true },
			{ 0.23, spinB, true },
			{ 0.31, spinC, true },
			{ 0.36, land, true },
			{ 0.46, skyDraw },
			{ 0.53, skyHold },
			{ 0.56, loose },
			{ 0.68, watch },
			{ 0.8, command },
			{ 0.91, judgment },
			{ 1, poised },
		}, { Charge = 0.07, Release = 0.56, Nock = 0.95 }, { Set = 0.38, Full = 0.48 }),
	}
end

-- Aeli (BOW): idle is a poised ranger's stance: an upright waist, narrow feet with her weight on
-- the left leg and the right knee turned slightly in, the bow held out to her left at chest
-- height (shoulder + elbow pitch near 90 keeps the stave upright), the right hand forward at
-- the string as if calling the wind to the arrow, chin a little down. Canopy's Wrath drops her
-- to one knee with the bow raised to the sky; she draws, looses the seed-arrow straight up,
-- holds a wide follow-through and rises.
-- Leafwind Arrow (Basic) keeps her narrow ranger's feet: a quick snap to the aim, a short draw,
-- and on the loose her draw hand opens out and up past her shoulder like a leaf on the wind.
-- Thornbriar Volley (Special, a shot that pierces a line) is a power shot: she steps her left
-- foot through and drops side-on, holds a long full draw, then looses with her whole body
-- thrusting after the arrow and holds the line it flew down.
do
	local p = WeaponPoses.BOW
	local kneel: Pose = { LeftHip = { 70, 0, -6 }, RightHip = { -20, 0, 6 }, LeftKnee = { -80, 0, 0 }, RightKnee = { -95, 0, 0 }, LeftAnkle = { 10, 0, 0 }, RightAnkle = { 70, 0, 0 }, RootOffset = { 0, -0.75, 0 } }
	local ranger: Pose = {
		Waist = { 0, -8, 2 }, Neck = { -4, 10, -2 },
		LeftShoulder = { 72, 0, -22 }, LeftElbow = { 14, 0, 0 },
		RightShoulder = { 55, 18, 0 }, RightElbow = { 68, 0, 0 },
		LeftHip = { 2, 0, -3 }, LeftKnee = { -4, 0, 0 }, LeftAnkle = { 2, 0, 3 },
		RightHip = { 8, -8, 2 }, RightKnee = { -14, 0, 0 }, RightAnkle = { 6, 0, -2 },
		RootOffset = { 0, -0.04, 0 },
	}
	-- Leafwind Arrow: an elven ranger's shot. Narrow feet as in her stance, leaning into the shot
	-- side-on, the bow canted 15 degrees and drawn high to her cheekbone with her head tipped down
	-- the arrow; on the loose the hand opens and rises up and away like a leaf on the wind.
	local rangerLegs: Pose = {
		LeftHip = { 6, -10, -4 }, LeftKnee = { -6, 0, 0 }, LeftAnkle = { 2, 0, 4 },
		RightHip = { -2, 6, 4 }, RightKnee = { -16, 0, 0 }, RightAnkle = { 10, 0, -4 },
		RootOffset = { 0, -0.05, 0 },
	}
	local leafwind: Pose = merge(rangerLegs, { Root = { 0, -45, 0 }, Waist = { -6, -30, 2 }, Neck = { 23, 74, -30 },
		LeftShoulder = { 105, -21, -60 }, LeftElbow = { 0, 0, 0 }, LeftWrist = { -21, -14, -13 } })
	local snapAim = merge(leafwind, { Waist = { -6, 26, 2 }, Neck = { 5, 20, -12 },
		LeftShoulder = { 96, -29, 12 }, LeftElbow = { 45, 0, 0 }, LeftWrist = { -44, 16, -30 },
		RightShoulder = { -45, 27, -153 }, RightElbow = { 62, 0, 0 } })
	local shortDraw = merge(leafwind, { RightShoulder = { -114, 73, -94 }, RightElbow = { 83, 0, 0 } })
	local leafLoose = merge(leafwind, { RightShoulder = { 18, 85, 125 }, RightElbow = { 66, 0, 0 } })
	-- The open hand keeps rising after the loose.
	local leafHeld = merge(leafLoose, { Waist = { -4, -30, 2 }, RightShoulder = { -88, 67, -125 }, RightElbow = { 15, 0, 0 } })
	-- Thornbriar Volley: left foot through into a deep braced lunge, a square, uncanted power
	-- draw back past her jaw with the arrow laid down the line, then her whole body thrusts after
	-- the arrow.
	local braced: Pose = {
		LeftHip = { 50, 0, -12 }, LeftKnee = { -58, 0, 0 }, LeftAnkle = { 10, 0, 0 },
		RightHip = { -28, 0, 12 }, RightKnee = { -12, 0, 0 }, RightAnkle = { 30, 0, 0 },
		RootOffset = { 0, -0.4, -0.14 },
	}
	local thorn: Pose = merge(braced, { Root = { 0, -55, 0 }, Waist = { -10, -30, 0 }, Neck = { 27, 84, -18 },
		LeftShoulder = { 105, -5, -82 }, LeftElbow = { 0, 0, 0 }, LeftWrist = { -5, -5, -3 } })
	local stepIn = merge(thorn, { Waist = { -10, 40, 0 }, Neck = { 3, 16, 8 },
		LeftShoulder = { 73, -11, 17 }, LeftElbow = { 50, 0, 0 }, LeftWrist = { -24, 12, -34 },
		RightShoulder = { -47, 9, -139 }, RightElbow = { 62, 0, 0 } })
	local heavyDraw = merge(thorn, { RightShoulder = { 114, 85, 40 }, RightElbow = { 135, 0, 0 } })
	local thornLoose = merge(thorn, {
		Waist = { -20, -28, 0 }, LeftShoulder = { 100, -5, -82 },
		RightShoulder = { 37, 28, 76 }, RightElbow = { 152, 0, 0 }, RootOffset = { 0, -0.46, -0.32 },
	})
	local thornHeld = merge(thornLoose, { Waist = { -18, -28, 0 }, RightElbow = { 140, 0, 0 }, RootOffset = { 0, -0.44, -0.3 } })
	-- Canopy's Wrath: down on one knee side-on, the bow raised nearly straight up for the seed-arrow.
	local canopy: Pose = merge(kneel, { Root = { 0, -50, 0 }, Waist = { 16, -25, 0 }, Neck = { 40, 31, -40 },
		LeftShoulder = { 145, -76, -12 }, LeftElbow = { 15, 0, 0 }, LeftWrist = { -29, 6, -9 } })
	local canopySet = merge(canopy, { Waist = { 16, -5, 0 }, Neck = { 40, 20, -40 },
		LeftShoulder = { 98, -103, -55 }, LeftElbow = { 24, 0, 0 }, LeftWrist = { -45, 39, -1 },
		RightShoulder = { 119, 15, -30 }, RightElbow = { 60, 0, 0 } })
	local canopyDraw = merge(canopy, { RightShoulder = { 90, 40, -56 }, RightElbow = { 108, 0, 0 } })
	local canopyLoose = merge(canopy, { Waist = { 20, -25, 0 }, RightShoulder = { 18, 50, 19 }, RightElbow = { 106, 0, 0 } })
	local canopyRise = merge(canopyLoose, {
		Waist = { 10, -20, 0 }, LeftShoulder = { 120, -60, -20 }, RightElbow = { 80, 0, 0 },
		LeftHip = { 35, 0, -6 }, RightHip = { -5, 0, 6 }, LeftKnee = { -40, 0, 0 }, RightKnee = { -50, 0, 0 },
		LeftAnkle = { 6, 0, 0 }, RightAnkle = { 30, 0, 0 }, RootOffset = { 0, -0.38, 0 },
	})
	Overrides.hero_aeli = {
		Idle = breathe(ranger, 3.6),
		-- Release and Nock match the shared bow clips, so her hits land on the same beat.
		AttackBasic = signature(0.8, {
			{ 0, ranger },
			{ 0.22, snapAim },
			{ 0.6, shortDraw },
			{ 0.72, leafLoose, true },
			{ 0.88, leafHeld },
			{ 1, ranger },
		}, { Release = 0.72, Nock = 0.9 }, { Set = 0.22, Full = 0.6, Anchor = { 0.15, -0.05, -0.45 } }),
		AttackSpecial = signature(0.95, {
			{ 0, ranger },
			{ 0.2, stepIn },
			{ 0.62, heavyDraw },
			{ 0.78, thornLoose, true },
			{ 0.9, thornHeld },
			{ 1, ranger },
		}, { Release = 0.78, Nock = 0.9 }, { Set = 0.2, Full = 0.62, Anchor = { 0.1, -0.35, 0.15 } }),
		AttackSkill = signature(1.1, {
			{ 0, p.Carry },
			{ 0.28, canopySet },
			{ 0.56, canopyDraw },
			{ 0.7, canopyLoose, true },
			{ 0.86, canopyRise },
			{ 1, p.Carry },
		}, { Release = 0.7, Nock = 0.92 }, { Set = 0.28, Full = 0.56 }),
	}
end

-- Aaron (SWORD_SHIELD): Fortress Bulwark. Sword and shield lifted, then the shield is planted
-- in a wide, braced stance. Idle is a wary crouch: shield raised in front, sword held low with
-- the blade angled down and forward.
do
	local p = WeaponPoses.SWORD_SHIELD
	local braced: Pose = { LeftHip = { 45, 0, -14 }, RightHip = { -20, 0, 14 }, LeftKnee = { -55, 0, 0 }, RightKnee = { -40, 0, 0 }, LeftAnkle = { 10, 0, 0 }, RightAnkle = { 30, 0, 0 }, RootOffset = { 0, -0.55, 0 } }
	local planted = merge(braced, { Waist = { -16, -10, 0 }, LeftShoulder = { 70, 15, -10 }, LeftElbow = { 25, 0, 0 }, RightShoulder = { 120, 0, 25 }, RightElbow = { 30, 0, 0 } })
	local wary: Pose = {
		Waist = { -4, -10, 0 }, Neck = { 2, 8, 0 },
		LeftShoulder = { 45, -30, -10 }, LeftElbow = { 85, 0, 0 },
		RightShoulder = { 15, 0, 12 }, RightElbow = { 25, 0, 0 }, RightWrist = { -75, 0, 0 },
		LeftHip = { 10, 0, -10 }, LeftKnee = { -22, 0, 0 }, LeftAnkle = { 12, 0, 10 },
		RightHip = { 4, 0, 10 }, RightKnee = { -18, 0, 0 }, RightAnkle = { 10, 0, -10 },
		RootOffset = { 0, -0.15, 0 },
	}
	Overrides.hero_aaron = {
		Idle = breathe(wary, 3.2),
		AttackSkill = signature(1.1, {
			{ 0, p.Guard },
			{ 0.35, merge(p.High, { LeftShoulder = { 100, 10, -10 }, LeftElbow = { 30, 0, 0 }, RootOffset = { 0, 0.2, 0 } }) },
			{ 0.6, planted },
			{ 0.82, merge(planted, { Waist = { -12, -10, 0 } }) },
			{ 1, p.Guard },
		}, { Release = 0.6 }),
	}
end

-- Ignis (SWORD_SHIELD): Infernal Juggernaut. Chest thrown back, then a forward roar with both
-- arms flexed wide. Idle is his cocky brawler stance: feet wide, left fist thrust forward (the
-- shield on that forearm leading), sword held low at his right side.
do
	local p = WeaponPoses.SWORD_SHIELD
	local roar = merge(ATTACK_STANCE, { Waist = { -16, 0, 0 }, Neck = { 10, 0, 0 }, LeftShoulder = { 70, 0, -60 }, LeftElbow = { 95, 0, 0 }, RightShoulder = { 70, 0, 60 }, RightElbow = { 95, 0, 0 }, RootOffset = { 0, -0.35, 0 } })
	local brawler: Pose = {
		Waist = { -4, -12, 0 }, Neck = { 0, 10, 3 },
		LeftShoulder = { 72, 0, -8 }, LeftElbow = { 22, 0, 0 },
		RightShoulder = { 10, 0, 12 }, RightElbow = { 35, 0, 0 }, RightWrist = { -60, 0, 0 },
		LeftHip = { 14, 0, -10 }, LeftKnee = { -18, 0, 0 }, LeftAnkle = { 4, 0, 10 },
		RightHip = { -6, 0, 12 }, RightKnee = { -14, 0, 0 }, RightAnkle = { 18, 0, -12 },
		RootOffset = { 0, -0.14, 0 },
	}
	Overrides.hero_ignis = {
		Idle = breathe(brawler, 3.0),
		AttackSkill = signature(1.1, {
			{ 0, p.Guard },
			{ 0.3, merge(STANCE, { Waist = { 20, 0, 0 }, Neck = { 20, 0, 0 }, LeftShoulder = { -30, 0, -40 }, LeftElbow = { 60, 0, 0 }, RightShoulder = { -30, 0, 40 }, RightElbow = { 60, 0, 0 } }) },
			{ 0.55, roar },
			{ 0.8, merge(roar, { Waist = { -12, 0, 0 } }) },
			{ 1, p.Guard },
		}, { Release = 0.55 }),
	}
end

-- Morrigan (SWORD_SHIELD): Obsidian Bastion. Sword raised overhead, then driven into the ground
-- from one knee. Idle is a stoic, planted guard: shield up in front, sword held low with the
-- blade angled down and forward.
do
	local p = WeaponPoses.SWORD_SHIELD
	local kneel = merge(p.Cut, { Waist = { -34, 0, 0 }, RightShoulder = { 45, 0, 5 }, RightElbow = { 10, 0, 0 }, LeftHip = { 70, 0, -8 }, LeftKnee = { -90, 0, 0 }, RightHip = { -10, 0, 8 }, RightKnee = { -100, 0, 0 }, LeftAnkle = { 20, 0, 0 }, RightAnkle = { 60, 0, 0 }, RootOffset = { 0, -0.85, 0 } })
	local planted: Pose = {
		Waist = { 0, -6, 0 }, Neck = { -2, 4, 0 },
		LeftShoulder = { 50, -30, -12 }, LeftElbow = { 80, 0, 0 },
		RightShoulder = { 20, 0, 14 }, RightElbow = { 30, 0, 0 }, RightWrist = { -85, 0, 0 },
		LeftHip = { 6, 0, -8 }, LeftKnee = { -12, 0, 0 }, LeftAnkle = { 6, 0, 8 },
		RightHip = { 2, 0, 8 }, RightKnee = { -10, 0, 0 }, RightAnkle = { 8, 0, -8 },
		RootOffset = { 0, -0.1, 0 },
	}
	Overrides.hero_morrigan = {
		Idle = breathe(planted, 3.6),
		AttackSkill = signature(1.1, {
			{ 0, p.Guard },
			{ 0.35, merge(p.High, { Waist = { 14, 0, 0 }, RightShoulder = { 178, 0, 0 }, RightElbow = { 5, 0, 0 }, RootOffset = { 0, 0.15, 0 } }) },
			{ 0.6, kneel },
			{ 0.85, kneel },
			{ 1, p.Guard },
		}, { Release = 0.6 }),
	}
end

-- Han (DAGGERS). He holds both daggers reversed (HeroSockets.HERO_GRIPS: an assassin's ice-pick
-- grip, the blades running back along his forearms), so every pose here is his own. With a
-- reversed grip a blade points back when its arm's shoulder + elbow + wrist pitch is 0, down at
-- 90 and forward at 180 (less the waist's lean); a wrist of -90 lays it along the forearm.
-- Idle: an assassin's low crouch, left foot forward and weight sunk, leaning in with his head up;
-- the lead (left) blade raised before his chin along the forearm, the rear blade trailing out low
-- at his right side. He settles a little lower and rises as he breathes.
-- Move: a sprint, leaning in with the knees driving, the arms pumping close to his sides and the
-- reversed blades tucked back along his forearms.
-- Gloam Cut (Basic): he winds the lead arm across his body, lunges and hooks it out wide (the
-- hit), then follows with a rising backhand of the rear blade. It alternates with a full spinning
-- cut: he winds left, then spins right through a whole turn with both blades flung out wide.
-- Nightfall Fangs (Special): he sinks, springs into a tucked front flip (Charge: the leap streak),
-- comes out of it with both fists high, and drives both blades down into the target (the hit),
-- pulls them up and stabs again (the kit's second blow), then rises.
-- Abyssal Wake (Skill): both blades crossed low before his chest (Charge: the wake's circle closes
-- in), he coils, then flashes from point to point round the circle, low and high in turn, cutting
-- through it with every flash (SkillVfx WAKE draws him there, with trails and afterimages), and
-- flashes home into a low crouch.
-- The flip and the spins are Root keys under 180 degrees apart, so they turn the long way round.
do
	local stalk: Pose = {
		Waist = { -24, -20, 0 }, Neck = { 18, 18, 0 },
		LeftShoulder = { 55, 0, -30 }, LeftElbow = { 95, 0, 0 }, LeftWrist = { -65, 0, 0 },
		RightShoulder = { 0, 0, 55 }, RightElbow = { 30, 0, 0 }, RightWrist = { -40, 0, 0 },
		LeftHip = { 40, 0, -14 }, LeftKnee = { -75, 0, 0 }, LeftAnkle = { 35, 0, 14 },
		RightHip = { -20, 0, 18 }, RightKnee = { -28, 0, 0 }, RightAnkle = { 48, 0, -18 },
		RootOffset = { 0, -0.52, 0 },
	}
	local settle = merge(stalk, {
		Waist = { -26, -22, 0 }, Neck = { 19, 20, 0 },
		LeftWrist = { -55, 0, 0 }, RightShoulder = { 2, 0, 58 }, RightWrist = { -48, 0, 0 },
		LeftKnee = { -79, 0, 0 }, RightKnee = { -31, 0, 0 }, RootOffset = { 0, -0.56, 0 },
	})
	-- The sprint, sampled at eight points round the stride like walk() and played at a steady rate.
	-- `a` runs once round the cycle; c = cos(a) is +1 with the left foot forward, -1 with the right.
	-- The leg swinging forward folds its heel up and drives the knee; the arms pump against the
	-- legs, close to his sides with the elbows bent and the wrists turned so the reversed blades lie
	-- back along the forearms; the torso leans in and twists with the stride, the head stays level,
	-- and he is lowest as each foot lands and rides up over the straight standing leg.
	local function sprintPose(a: number): Pose
		local c = math.cos(a)
		local leftSwing = math.max(0, -math.sin(a)) -- the left leg travelling forward
		local rightSwing = math.max(0, math.sin(a))
		local function leg(hip: number, swing: number): ({ number }, { number }, { number })
			local knee = -18 - 88 * swing
			return { hip, 0, 0 }, { knee, 0, 0 }, { math.clamp(-(hip + knee) * 0.5 + 18 * swing, -20, 45), 0, 0 }
		end
		local lh, lk, la = leg(10 + 40 * c, leftSwing)
		local rh, rk, ra = leg(10 - 40 * c, rightSwing)
		lh[3], rh[3] = -3, 3
		return {
			Waist = { -20 - 2 * math.abs(c), 10 * c, 2 * c }, Neck = { 14, -9 * c, -2 * c },
			LeftShoulder = { 12 - 42 * c, 0, -8 }, LeftElbow = { 95 + 12 * c, 0, 0 }, LeftWrist = { -90, 0, 0 },
			RightShoulder = { 12 + 42 * c, 0, 8 }, RightElbow = { 95 - 12 * c, 0, 0 }, RightWrist = { -90, 0, 0 },
			LeftHip = lh, LeftKnee = lk, LeftAnkle = la,
			RightHip = rh, RightKnee = rk, RightAnkle = ra,
			RootOffset = { 0, -0.16 - 0.2 * math.cos(2 * a), 0 },
		}
	end
	local function sprint(duration: number): Clip
		local SAMPLES = 8
		local keys: { { any } } = { { 0, sprintPose(0) } }
		for i = 1, SAMPLES - 1 do
			table.insert(keys, { i / SAMPLES, sprintPose(2 * math.pi * i / SAMPLES), true })
		end
		table.insert(keys, { 1, sprintPose(0), true })
		return clip(duration, true, keys)
	end
	-- Both arms flung out wide to the sides, and both wrapped across the chest.
	local wide: Pose = {
		LeftShoulder = { 90, 0, -85 }, LeftElbow = { 8, 0, 0 }, LeftWrist = { -10, 0, 0 },
		RightShoulder = { 90, 0, 85 }, RightElbow = { 8, 0, 0 }, RightWrist = { -10, 0, 0 },
	}
	local wrapped: Pose = {
		LeftShoulder = { 60, 0, 30 }, LeftElbow = { 110, 0, 0 }, LeftWrist = { -60, 0, 0 },
		RightShoulder = { 60, 0, -30 }, RightElbow = { 110, 0, 0 }, RightWrist = { -60, 0, 0 },
	}

	-- Gloam Cut
	local lungeLegs: Pose = {
		LeftHip = { 62, 0, -12 }, LeftKnee = { -88, 0, 0 }, LeftAnkle = { 26, 0, 12 },
		RightHip = { -38, 0, 16 }, RightKnee = { -18, 0, 0 }, RightAnkle = { 56, 0, -16 },
	}
	local windUp = merge(stalk, {
		Waist = { -16, -55, 0 }, Neck = { 12, 45, 0 },
		LeftShoulder = { 70, 0, 40 }, LeftElbow = { 105, 0, 0 }, LeftWrist = { -40, 0, 0 },
		RightShoulder = { -30, 0, 40 }, RightElbow = { 55, 0, 0 }, RightWrist = { -60, 0, 0 },
		RootOffset = { 0, -0.56, 0.15 },
	})
	local hook = merge(merge(stalk, lungeLegs), {
		Waist = { -26, 42, 0 }, Neck = { 16, -34, 0 },
		LeftShoulder = { 85, 0, -80 }, LeftElbow = { 12, 0, 0 }, LeftWrist = { -20, 0, 0 },
		RightShoulder = { 45, 0, 25 }, RightElbow = { 105, 0, 0 }, RightWrist = { -50, 0, 0 },
		RootOffset = { 0, -0.78, -0.85 },
	})
	local rising = merge(merge(stalk, lungeLegs), {
		Waist = { -6, -32, 0 }, Neck = { 6, 26, 0 },
		LeftShoulder = { 35, 0, -60 }, LeftElbow = { 45, 0, 0 }, LeftWrist = { -40, 0, 0 },
		RightShoulder = { 160, 0, 25 }, RightElbow = { 18, 0, 0 }, RightWrist = { -30, 0, 0 },
		RootOffset = { 0, -0.82, -0.95 },
	})
	local spinWind = merge(merge(stalk, wrapped), { Waist = { -18, 30, 0 }, Neck = { 12, -24, 0 }, RootOffset = { 0, -0.6, 0.1 } })
	local spinning = merge(merge(stalk, wide), { Waist = { -14, 0, 0 }, Neck = { 10, 0, 0 } })
	local spunLow = merge(merge(merge(stalk, lungeLegs), wrapped), { Waist = { -28, 0, 0 }, Neck = { 20, 0, 0 }, RootOffset = { 0, -0.78, -0.8 } })

	-- Nightfall Fangs
	local sink = merge(stalk, {
		Waist = { -30, 0, 0 }, Neck = { 24, 0, 0 },
		LeftShoulder = { -50, 0, -20 }, LeftElbow = { 20, 0, 0 }, LeftWrist = { -30, 0, 0 },
		RightShoulder = { -50, 0, 20 }, RightElbow = { 20, 0, 0 }, RightWrist = { -30, 0, 0 },
		LeftHip = { 70, 0, -10 }, LeftKnee = { -110, 0, 0 }, LeftAnkle = { 40, 0, 10 },
		RightHip = { 50, 0, 10 }, RightKnee = { -110, 0, 0 }, RightAnkle = { 60, 0, -10 },
		RootOffset = { 0, -1.0, 0.2 },
	})
	local launch = merge(stalk, {
		Waist = { 8, 0, 0 }, Neck = { -6, 0, 0 },
		LeftShoulder = { 165, 0, -15 }, LeftElbow = { 15, 0, 0 }, LeftWrist = { 0, 0, 0 },
		RightShoulder = { 165, 0, 15 }, RightElbow = { 15, 0, 0 }, RightWrist = { 0, 0, 0 },
		LeftHip = { 20, 0, -4 }, LeftKnee = { -30, 0, 0 }, LeftAnkle = { 10, 0, 4 },
		RightHip = { -14, 0, 4 }, RightKnee = { -10, 0, 0 }, RightAnkle = { 30, 0, -4 },
		RootOffset = { 0, 1.1, -0.3 },
	})
	local tuck = merge(stalk, {
		Waist = { -40, 0, 0 }, Neck = { 20, 0, 0 },
		LeftShoulder = { 70, 0, 10 }, LeftElbow = { 120, 0, 0 }, LeftWrist = { -20, 0, 0 },
		RightShoulder = { 70, 0, -10 }, RightElbow = { 120, 0, 0 }, RightWrist = { -20, 0, 0 },
		LeftHip = { 120, 0, -8 }, LeftKnee = { -130, 0, 0 }, LeftAnkle = { 30, 0, 8 },
		RightHip = { 115, 0, 8 }, RightKnee = { -130, 0, 0 }, RightAnkle = { 30, 0, -8 },
	})
	local raised = merge(stalk, {
		Waist = { 10, 0, 0 }, Neck = { 6, 0, 0 },
		LeftShoulder = { 170, 0, -8 }, LeftElbow = { 40, 0, 0 }, LeftWrist = { -60, 0, 0 },
		RightShoulder = { 170, 0, 8 }, RightElbow = { 40, 0, 0 }, RightWrist = { -60, 0, 0 },
		LeftHip = { 40, 0, -8 }, LeftKnee = { -60, 0, 0 }, LeftAnkle = { 20, 0, 8 },
		RightHip = { 10, 0, 8 }, RightKnee = { -40, 0, 0 }, RightAnkle = { 30, 0, -8 },
		RootOffset = { 0, 1.2, -1.2 },
	})
	local plunge = merge(stalk, {
		Waist = { -40, 0, 0 }, Neck = { 26, 0, 0 },
		LeftShoulder = { 50, 0, 14 }, LeftElbow = { 15, 0, 0 }, LeftWrist = { 65, 0, 0 },
		RightShoulder = { 50, 0, -14 }, RightElbow = { 15, 0, 0 }, RightWrist = { 65, 0, 0 },
		LeftHip = { 80, 0, -10 }, LeftKnee = { -100, 0, 0 }, LeftAnkle = { 20, 0, 10 },
		RightHip = { -10, 0, 12 }, RightKnee = { -95, 0, 0 }, RightAnkle = { 60, 0, -12 },
		RootOffset = { 0, -1.07, -1.4 },
	})
	local pull = merge(plunge, {
		Waist = { -32, 0, 0 }, LeftShoulder = { 80, 0, 14 }, LeftElbow = { 50, 0, 0 },
		RightShoulder = { 80, 0, -14 }, RightElbow = { 50, 0, 0 }, RootOffset = { 0, -1.0, -1.4 },
	})

	-- Abyssal Wake. The clip runs over the kit's 1.3s cast; the flashes start at Release (0.3) and
	-- come every 0.09s, one per damage tick, so flash k is at (0.39 + 0.09 * (k - 1)) / 1.3. SkillVfx
	-- (WAKE) draws him at each flash point, low and high in turn; the clip only poses him there.
	-- Every flash pose is a leaping cut, so it reads on the ground or in the air: the low flashes
	-- cut wide one way and the other, the high ones come in tucked with both blades overhead and
	-- swing them down on the way to the next.
	local crossed = merge(merge(stalk, wrapped), {
		Waist = { -30, 0, 0 }, Neck = { 24, 0, 0 },
		LeftHip = { 60, 0, -12 }, LeftKnee = { -100, 0, 0 }, LeftAnkle = { 40, 0, 12 },
		RightHip = { -10, 0, 16 }, RightKnee = { -70, 0, 0 }, RightAnkle = { 60, 0, -16 },
		RootOffset = { 0, -0.85, 0.35 },
	})
	local coiled = merge(crossed, { Waist = { -36, 0, 0 }, LeftKnee = { -110, 0, 0 }, RightKnee = { -85, 0, 0 }, RootOffset = { 0, -1.0, 0.45 } })
	local leapLeft: Pose = {
		LeftHip = { 75, 0, -10 }, LeftKnee = { -110, 0, 0 }, LeftAnkle = { 30, 0, 10 },
		RightHip = { -35, 0, 12 }, RightKnee = { -55, 0, 0 }, RightAnkle = { 40, 0, -12 },
	}
	local leapRight: Pose = {
		RightHip = { 75, 0, 10 }, RightKnee = { -110, 0, 0 }, RightAnkle = { 30, 0, -10 },
		LeftHip = { -35, 0, -12 }, LeftKnee = { -55, 0, 0 }, LeftAnkle = { 40, 0, 12 },
	}
	local tucked: Pose = {
		LeftHip = { 100, 0, -8 }, LeftKnee = { -125, 0, 0 }, LeftAnkle = { 30, 0, 8 },
		RightHip = { 95, 0, 8 }, RightKnee = { -125, 0, 0 }, RightAnkle = { 30, 0, -8 },
	}
	-- The left blade swept out wide, the right drawn across his chest; and the mirror of it.
	local cutLeft = merge(merge(stalk, leapLeft), {
		Waist = { -18, 40, 0 }, Neck = { 10, -32, 0 },
		LeftShoulder = { 90, 0, -85 }, LeftElbow = { 8, 0, 0 }, LeftWrist = { -10, 0, 0 },
		RightShoulder = { 70, 0, -35 }, RightElbow = { 70, 0, 0 }, RightWrist = { -60, 0, 0 },
		RootOffset = { 0, 0, 0 },
	})
	local cutRight = merge(merge(stalk, leapRight), {
		Waist = { -18, -40, 0 }, Neck = { 10, 32, 0 },
		RightShoulder = { 90, 0, 85 }, RightElbow = { 8, 0, 0 }, RightWrist = { -10, 0, 0 },
		LeftShoulder = { 70, 0, 35 }, LeftElbow = { 70, 0, 0 }, LeftWrist = { -60, 0, 0 },
		RootOffset = { 0, 0, 0 },
	})
	local overhead = merge(merge(stalk, tucked), {
		Waist = { 8, 0, 0 }, Neck = { 0, 0, 0 },
		LeftShoulder = { 170, 0, -12 }, LeftElbow = { 30, 0, 0 }, LeftWrist = { -60, 0, 0 },
		RightShoulder = { 170, 0, 12 }, RightElbow = { 30, 0, 0 }, RightWrist = { -60, 0, 0 },
		RootOffset = { 0, 0, 0 },
	})
	local landed = merge(crossed, { Waist = { -34, 0, 0 }, RootOffset = { 0, -0.95, 0.2 } })

	Overrides.hero_han = {
		Idle = clip(2.6, true, { { 0, stalk }, { 0.5, settle }, { 1, stalk } }),
		Move = sprint(0.56),
		AttackBasic = signature(0.85, {
			{ 0, stalk },
			{ 0.18, windUp },
			{ 0.36, hook },
			{ 0.52, rising },
			{ 0.7, merge(rising, { Waist = { -10, -36, 0 }, RootOffset = { 0, -0.82, -0.9 } }) },
			{ 1, stalk },
		}, { Release = 0.36 }),
		AttackSpecial = signature(0.85, {
			{ 0, stalk },
			{ 0.14, sink },
			{ 0.23, launch },
			{ 0.32, merge(tuck, { Root = { -120, 0, 0 }, RootOffset = { 0, 2.2, -0.7 } }), true },
			{ 0.42, merge(tuck, { Root = { 120, 0, 0 }, RootOffset = { 0, 2.3, -1.0 } }), true },
			{ 0.52, merge(raised, { Root = { 0, 0, 0 } }), true },
			{ 0.62, plunge, true },
			{ 0.68, pull },
			{ 0.74, plunge, true },
			{ 0.88, merge(plunge, { Waist = { -30, 0, 0 }, RootOffset = { 0, -0.97, -1.3 } }) },
			{ 1, stalk },
		}, { Charge = 0.14, Release = 0.62 }),
		AttackSkill = signature(1.3, {
			{ 0, stalk },
			{ 0.12, crossed },
			{ 0.24, coiled },
			{ 0.3, cutLeft }, -- flash 1, low
			{ 0.369, merge(overhead, { Root = { -20, 0, 25 } }) }, -- flash 2, high
			{ 0.438, cutRight },
			{ 0.508, merge(overhead, { Root = { -20, 0, -25 } }) },
			{ 0.577, cutLeft },
			{ 0.646, merge(overhead, { Root = { -20, 0, 25 } }) },
			{ 0.715, cutRight },
			{ 0.785, merge(overhead, { Root = { -30, 0, 0 } }) }, -- flash 8, high
			{ 0.854, landed }, -- back home
			{ 0.93, merge(crossed, { Waist = { -26, 0, 0 } }) },
			{ 1, stalk },
		}, { Charge = 0.05, Release = 0.3 }),
	}
	-- The spinning cut lands on the same Release as the hook.
	Alternates.hero_han = {
		AttackBasic = signature(0.85, {
			{ 0, stalk },
			{ 0.16, spinWind },
			{ 0.26, merge(spinning, { Root = { 0, -120, 0 }, RootOffset = { 0, -0.5, -0.4 } }), true },
			{ 0.36, merge(spinning, { Root = { 0, 120, 0 }, RootOffset = { 0, -0.5, -0.7 } }), true },
			{ 0.48, merge(spunLow, { Root = { 0, 0, 0 } }), true },
			{ 0.7, merge(spunLow, { Waist = { -24, 0, 0 }, RootOffset = { 0, -0.78, -0.7 } }) },
			{ 1, stalk },
		}, { Release = 0.36 }),
	}
end

-- Velkist (DAGGERS): Shadow Rend is a dash-through cross cut; Phantom Lotus Execution sweeps both
-- blades outward like opening petals after a lunge. Idle is his showboating stance: feet planted
-- wide, arms held out from his sides with the blades tipped up and out, head cocked.
do
	local p = WeaponPoses.DAGGERS
	local coiled = merge(p.Crouched, { Waist = { 10, 0, 0 }, LeftShoulder = { -40, 0, -30 }, RightShoulder = { -40, 0, 30 }, LeftElbow = { 30, 0, 0 }, RightElbow = { 30, 0, 0 }, RootOffset = { 0, -0.4, 0.2 } })
	local lunge = merge(p.Crouched, { Waist = { -30, 0, 0 }, LeftShoulder = { -20, 0, -20 }, RightShoulder = { -20, 0, 20 }, LeftHip = { 50, 0, -6 }, LeftKnee = { -50, 0, 0 }, RightHip = { -30, 0, 6 }, RightKnee = { -20, 0, 0 }, RootOffset = { 0, -0.3, -0.6 } })
	local showboat: Pose = {
		Waist = { -3, 0, 0 }, Neck = { -5, -8, 6 },
		LeftShoulder = { 18, 0, -38 }, LeftElbow = { 62, 0, 0 }, LeftWrist = { -10, 0, 0 },
		RightShoulder = { 18, 0, 38 }, RightElbow = { 62, 0, 0 }, RightWrist = { -10, 0, 0 },
		LeftHip = { 6, 0, -13 }, LeftKnee = { -16, 0, 0 }, LeftAnkle = { 10, 0, 13 },
		RightHip = { 6, 0, 13 }, RightKnee = { -16, 0, 0 }, RightAnkle = { 10, 0, -13 },
		RootOffset = { 0, -0.12, 0 },
	}
	Overrides.hero_velkist = {
		Idle = breathe(showboat, 3.0),
		AttackSpecial = signature(0.75, {
			{ 0, p.Crouched },
			{ 0.3, coiled },
			{ 0.55, merge(lunge, { LeftShoulder = { 100, 0, 45 }, RightShoulder = { 100, 0, -45 }, LeftElbow = { 5, 0, 0 }, RightElbow = { 5, 0, 0 } }) },
			{ 0.8, merge(lunge, { RootOffset = { 0, -0.25, -0.4 } }) },
			{ 1, p.Crouched },
		}, { Release = 0.55 }),
		AttackSkill = signature(1.0, {
			{ 0, p.Crouched },
			{ 0.25, coiled },
			{ 0.5, lunge },
			{ 0.7, merge(lunge, { Waist = { -14, 0, 0 }, LeftShoulder = { 100, 0, -70 }, RightShoulder = { 100, 0, 70 }, LeftElbow = { 5, 0, 0 }, RightElbow = { 5, 0, 0 } }) },
			{ 0.85, merge(lunge, { Waist = { -10, 0, 0 }, LeftShoulder = { 80, 0, -85 }, RightShoulder = { 80, 0, 85 } }) },
			{ 1, p.Crouched },
		}, { Release = 0.7 }),
	}
end

-- Sovereign Archon (DAGGERS): Dimensional Cataclysm. Blades crossed overhead, then torn apart
-- and down to rip the rift open. Idle is a low, wide predator's crouch: leaning in, both
-- daggers held out at his sides pointing forward.
do
	local p = WeaponPoses.DAGGERS
	local tear = merge(p.Crouched, { Waist = { -20, 0, 0 }, LeftShoulder = { 80, 0, -90 }, RightShoulder = { 80, 0, 90 }, LeftElbow = { 10, 0, 0 }, RightElbow = { 10, 0, 0 }, RootOffset = { 0, -0.4, 0 } })
	local prowl: Pose = {
		Waist = { -8, 0, 0 }, Neck = { 4, 0, 0 },
		LeftShoulder = { 25, 0, -40 }, LeftElbow = { 50, 0, 0 }, LeftWrist = { -70, 0, 0 },
		RightShoulder = { 25, 0, 40 }, RightElbow = { 50, 0, 0 }, RightWrist = { -70, 0, 0 },
		LeftHip = { 12, 0, -16 }, LeftKnee = { -35, 0, 0 }, LeftAnkle = { 22, 0, 16 },
		RightHip = { 10, 0, 16 }, RightKnee = { -32, 0, 0 }, RightAnkle = { 20, 0, -16 },
		RootOffset = { 0, -0.32, 0 },
	}
	Overrides.hero_archon = {
		Idle = breathe(prowl, 2.8),
		AttackSkill = signature(1.0, {
			{ 0, p.Crouched },
			{ 0.35, merge(STANCE, { Waist = { 12, 0, 0 }, Neck = { 15, 0, 0 }, LeftShoulder = { 170, 0, 20 }, RightShoulder = { 170, 0, -20 }, LeftElbow = { 40, 0, 0 }, RightElbow = { 40, 0, 0 }, RootOffset = { 0, 0.3, 0 } }) },
			{ 0.62, tear },
			{ 0.85, merge(tear, { Waist = { -16, 0, 0 } }) },
			{ 1, p.Crouched },
		}, { Release = 0.62 }),
	}
end

-- Edis (DAGGERS): Umbral Crosscut raises both blades crossed, then rips them down and apart in
-- an X. Midnight Requiem coils low with the blades crossed at her chest, then spins them out wide
-- through the crowd and settles into a low follow-through. Idle is her aloof guard from the art:
-- weight on the back leg with the front knee turned in, waist turned a little away, head turned
-- back towards the enemy, both daggers held low and out at her sides with the blades angled down.
do
	local p = WeaponPoses.DAGGERS
	local crossed = merge(STANCE, { Waist = { 8, 0, 0 }, LeftShoulder = { 150, 0, 25 }, RightShoulder = { 150, 0, -25 }, LeftElbow = { 30, 0, 0 }, RightElbow = { 30, 0, 0 }, RootOffset = { 0, 0.1, 0 } })
	local rip = merge(p.Crouched, { Waist = { -22, 0, 0 }, LeftShoulder = { 40, 0, -60 }, RightShoulder = { 40, 0, 60 }, LeftElbow = { 10, 0, 0 }, RightElbow = { 10, 0, 0 }, RootOffset = { 0, -0.35, 0 } })
	local coil = merge(p.Crouched, { Waist = { -10, 50, 0 }, LeftShoulder = { 80, 0, 40 }, RightShoulder = { 80, 0, -40 }, LeftElbow = { 70, 0, 0 }, RightElbow = { 70, 0, 0 }, RootOffset = { 0, -0.4, 0 } })
	local fling = merge(p.Crouched, { Waist = { -14, -60, 0 }, LeftShoulder = { 90, 0, -85 }, RightShoulder = { 90, 0, 85 }, LeftElbow = { 5, 0, 0 }, RightElbow = { 5, 0, 0 }, RootOffset = { 0, -0.3, 0 } })
	local aloof: Pose = {
		Waist = { -4, -12, 0 }, Neck = { -3, 14, 2 },
		LeftShoulder = { 18, 0, -30 }, LeftElbow = { 45, 0, 0 }, LeftWrist = { -60, 0, 0 },
		RightShoulder = { 14, 0, 26 }, RightElbow = { 40, 0, 0 }, RightWrist = { -60, 0, 0 },
		LeftHip = { 12, 4, -5 }, LeftKnee = { -18, 0, 0 }, LeftAnkle = { 6, 0, 5 },
		RightHip = { -4, 0, 7 }, RightKnee = { -10, 0, 0 }, RightAnkle = { 14, 0, -7 },
		RootOffset = { 0, -0.08, 0 },
	}
	Overrides.hero_edis = {
		Idle = breathe(aloof, 3.4),
		AttackSpecial = signature(0.75, {
			{ 0, p.Crouched },
			{ 0.3, crossed },
			{ 0.55, rip },
			{ 0.8, merge(rip, { Waist = { -16, 0, 0 } }) },
			{ 1, p.Crouched },
		}, { Release = 0.55 }),
		AttackSkill = signature(1.0, {
			{ 0, p.Crouched },
			{ 0.3, coil },
			{ 0.55, merge(fling, { Waist = { -12, 0, 0 } }) },
			{ 0.7, fling },
			{ 0.85, merge(fling, { Waist = { -20, -30, 0 }, RootOffset = { 0, -0.45, 0 } }) },
			{ 1, p.Crouched },
		}, { Release = 0.55 }),
	}
end

-- Catio (AXE): Resonance Tremor is an overhand strike sunk into the ground; Crystalline
-- Excavation winds the greataxe round once before a two-handed slam. Idle is an inquisitor's
-- composure, to match his ceremonial mantle: upright and still, chest lifted, chin raised, feet
-- close with his weight settled on the back leg, the greataxe held at port arms like a mace of
-- office, breathing slowly. Only the torso, head and legs differ from the shared rest, so the
-- arms keep their baked haft grip.
do
	local p = WeaponPoses.AXE
	local inquisitor = merge(p.Rest, {
		Waist = { 3, 10, 0 }, Neck = { 11, -8, 0 },
		LeftHip = { 2, 0, -4 }, LeftKnee = { -3, 0, 0 }, LeftAnkle = { 1, 0, 4 },
		RightHip = { -6, 0, 6 }, RightKnee = { -6, 0, 0 }, RightAnkle = { 6, 0, -6 },
		RootOffset = { 0, -0.02, 0 },
	})
	Overrides.hero_catio = {
		Idle = breathe(inquisitor, 4.2),
		AttackSpecial = signature(0.9, {
			{ 0, p.Rest },
			{ 0.4, p.Windup },
			{ 0.65, merge(p.Chop, { Waist = { -30, 55, 0 }, LeftKnee = { -45, 0, 0 }, RightKnee = { -40, 0, 0 }, RootOffset = { 0, -0.45, 0 } }) },
			{ 0.82, merge(p.Chop, { Waist = { -26, 52, 0 }, LeftKnee = { -40, 0, 0 }, RightKnee = { -36, 0, 0 }, RootOffset = { 0, -0.4, 0 } }) },
			{ 1, p.Rest },
		}, { Release = 0.65 }),
		AttackSkill = signature(1.15, {
			{ 0, p.Rest },
			{ 0.22, merge(p.SweepBack, { Waist = { 0, -60, 0 }, Neck = { 0, 44, 0 } }) },
			{ 0.42, merge(p.High, { Waist = { 16, 6, 0 }, RootOffset = { 0, 0.25, 0 } }) },
			{ 0.62, p.Slam },
			{ 0.82, merge(p.Slam, { Waist = { -32, 48, 0 } }) },
			{ 1, p.Rest },
		}, { Release = 0.62 }),
	}
end

-- Gide (AXE): Bedrock Sundering hauls the greataxe far back before a heavy diagonal chop;
-- Tunnelbreaker Fault raises it overhead in both hands and drives it into the floor. Idle is his
-- planted veteran stance: feet wide, knees set, the greataxe held across his chest at port arms.
-- Ironvein Chop (Basic) is a miner's stroke, short and vertical where Bedrock Sundering is a
-- long diagonal: he sinks, lifts the axe straight overhead without hauling it back, drops it
-- into the vein in front of him, then wrenches his torso round as if prying the ore loose.
do
	local p = WeaponPoses.AXE
	local sunder = merge(p.Chop, { Waist = { -28, 66, 0 }, Neck = { 14, -50, 0 }, LeftKnee = { -42, 0, 0 }, RightKnee = { -36, 0, 0 }, RootOffset = { 0, -0.4, 0 } })
	local faultSlam = merge(p.Slam, { Waist = { -40, 50, 0 }, LeftHip = { 52, 0, -10 }, RightHip = { 12, 0, 10 }, LeftKnee = { -68, 0, 0 }, RightKnee = { -62, 0, 0 }, RootOffset = { 0, -0.62, 0 } })
	local veteran = merge(p.Rest, {
		Waist = { -3, 14, 0 }, Neck = { -3, -12, 0 },
		LeftHip = { 8, 0, -13 }, LeftKnee = { -18, 0, 0 }, LeftAnkle = { 10, 0, 13 },
		RightHip = { 6, 0, 13 }, RightKnee = { -16, 0, 0 }, RightAnkle = { 10, 0, -13 },
		RootOffset = { 0, -0.14, 0 },
	})
	local veteranLegs: Pose = {
		LeftHip = veteran.LeftHip, LeftKnee = veteran.LeftKnee, LeftAnkle = veteran.LeftAnkle,
		RightHip = veteran.RightHip, RightKnee = veteran.RightKnee, RightAnkle = veteran.RightAnkle,
	}
	local sink = merge(veteran, { Waist = { -6, 10, 0 }, LeftKnee = { -28, 0, 0 }, RightKnee = { -26, 0, 0 }, RootOffset = { 0, -0.26, 0 } })
	local lift = merge(merge(p.High, veteranLegs), { Waist = { 10, 14, 0 }, Neck = { -4, -10, 0 }, RootOffset = { 0, -0.06, 0.04 } })
	local intoVein = merge(p.Chop, {
		Waist = { -30, 40, 0 }, Neck = { 16, -30, 0 },
		LeftHip = { 30, 0, -13 }, LeftKnee = { -40, 0, 0 }, RightHip = { 4, 0, 13 }, RightKnee = { -30, 0, 0 },
		RootOffset = { 0, -0.36, -0.08 },
	})
	local pry = merge(intoVein, { Waist = { -24, 60, 0 }, Neck = { 12, -46, 0 }, RootOffset = { 0, -0.3, -0.04 } })
	Overrides.hero_gide = {
		Idle = breathe(veteran, 3.2),
		-- Release matches the shared axe Basic, so the hit lands on the same beat.
		AttackBasic = signature(0.85, {
			{ 0, veteran },
			{ 0.18, sink },
			{ 0.42, lift },
			{ 0.65, intoVein, true },
			{ 0.8, pry },
			{ 1, veteran },
		}, { Release = 0.65 }),
		AttackSpecial = signature(0.9, {
			{ 0, p.Rest },
			{ 0.38, merge(p.Windup, { Waist = { 10, -36, 0 }, Neck = { -4, 30, 0 } }) },
			{ 0.65, sunder },
			{ 0.84, merge(sunder, { Waist = { -24, 60, 0 } }) },
			{ 1, p.Rest },
		}, { Release = 0.65 }),
		AttackSkill = signature(1.15, {
			{ 0, p.Rest },
			{ 0.36, merge(p.High, { Waist = { 16, 8, 0 }, RootOffset = { 0, 0.22, 0 } }) },
			{ 0.62, faultSlam },
			{ 0.84, merge(faultSlam, { Waist = { -36, 48, 0 } }) },
			{ 1, p.Rest },
		}, { Release = 0.62 }),
	}
end

-- Rhyman (AXE): his full signature set.
-- Idle: a low, wide brawler's stance from his reference art, the greataxe at port arms across
-- his chest, weight sunk into the front leg, chin tipped and head cocked.
-- Reaver's Whirl (Special): he coils the axe back on his right, then whips a full turn to the
-- left with it held level at arm's length (four Root keys blended at a steady rate), and
-- brakes in the follow-through of the sweep. Release is where the edge first comes round; the
-- three damage ticks land through the turn.
-- Headsman's Verdict (Skill): he drops into a deep crouch, leaps with the axe hauled overhead
-- and his back arched, hangs at the top, then falls forward onto the target and buries the
-- head in the floor (Release). He holds the blow, then wrenches the axe free.
do
	local p = WeaponPoses.AXE
	local brawler = merge(p.Rest, {
		Waist = { -6, 16, 0 }, Neck = { 2, -14, 4 },
		LeftHip = { 14, 0, -16 }, LeftKnee = { -26, 0, 0 }, LeftAnkle = { 12, 0, 16 },
		RightHip = { 4, 0, 15 }, RightKnee = { -20, 0, 0 }, RightAnkle = { 14, 0, -15 },
		RootOffset = { 0, -0.22, 0 },
	})

	-- Reaver's Whirl
	local low: Pose = {
		LeftHip = { 22, 0, -14 }, LeftKnee = { -38, 0, 0 }, LeftAnkle = { 14, 0, 14 },
		RightHip = { -8, 0, 14 }, RightKnee = { -34, 0, 0 }, RightAnkle = { 30, 0, -14 },
		RootOffset = { 0, -0.34, 0 },
	}
	local coil = merge(merge(p.SweepBack, low), { Waist = { 4, -58, 0 }, Neck = { 0, 44, 0 }, Root = { 0, -20, 0 } })
	-- The axe held level and out, the body leaning into the turn. Each Root key is under 180
	-- degrees from the last, so the blend always goes the short way round.
	local whirl = merge(merge(p.SweepThrough, low), { Waist = { -6, 26, 0 }, Neck = { 2, -12, 0 } })
	local whirlA = merge(whirl, { Root = { 0, 110, 0 } })
	local whirlB = merge(whirl, { Root = { 0, -130, 0 }, Waist = { -8, 34, 0 }, RootOffset = { 0, -0.28, 0 } })
	local whirlC = merge(whirl, { Root = { 0, -20, 0 }, Waist = { -8, 46, 0 } })
	local brake = merge(merge(p.SweepThrough, low), { Waist = { -10, 68, 0 }, Neck = { 4, -50, 0 } })

	-- Headsman's Verdict
	local crouch = merge(p.Windup, {
		Waist = { -14, -20, 0 }, Neck = { 10, 16, 0 },
		LeftHip = { 62, 0, -10 }, LeftKnee = { -84, 0, 0 }, LeftAnkle = { 22, 0, 10 },
		RightHip = { 40, 0, 10 }, RightKnee = { -88, 0, 0 }, RightAnkle = { 44, 0, -10 },
		RootOffset = { 0, -0.85, 0 },
	})
	local tucked: Pose = {
		LeftHip = { 50, 0, -8 }, LeftKnee = { -70, 0, 0 }, LeftAnkle = { 20, 0, 0 },
		RightHip = { 12, 0, 8 }, RightKnee = { -96, 0, 0 }, RightAnkle = { 30, 0, 0 },
	}
	local leap = merge(merge(p.High, tucked), { Waist = { 16, 8, 0 }, Neck = { -4, -6, 0 }, RootOffset = { 0, 2.5, -0.2 } })
	local apex = merge(merge(p.High, tucked), { Waist = { 24, 10, 0 }, Neck = { -12, -8, 0 }, LeftHip = { 62, 0, -8 }, RootOffset = { 0, 3.4, -0.5 } })
	local fall = merge(merge(p.Chop, tucked), { Waist = { -6, 40, 0 }, Neck = { 10, -32, 0 }, LeftHip = { 34, 0, -8 }, LeftKnee = { -40, 0, 0 }, RightKnee = { -70, 0, 0 }, RootOffset = { 0, 1.5, -0.95 } })
	local verdict = merge(p.Slam, {
		Waist = { -42, 50, 0 }, Neck = { 24, -40, 0 },
		LeftHip = { 56, 0, -10 }, LeftKnee = { -72, 0, 0 }, RightHip = { 12, 0, 10 }, RightKnee = { -66, 0, 0 },
		RootOffset = { 0, -0.66, -1.1 },
	})
	local wrench = merge(p.Rest, {
		Waist = { -10, 30, 0 }, Neck = { 4, -24, 0 },
		LeftHip = { 20, 0, -8 }, LeftKnee = { -28, 0, 0 }, RightHip = { -4, 0, 8 }, RightKnee = { -22, 0, 0 },
		RootOffset = { 0, -0.25, -0.5 },
	})

	Overrides.hero_rhyman = {
		Idle = breathe(brawler, 3.0),
		AttackSpecial = signature(1.0, {
			{ 0, p.Rest },
			{ 0.18, coil },
			{ 0.3, whirlA, true },
			{ 0.4, whirlB, true },
			{ 0.5, whirlC, true },
			{ 0.56, brake, true },
			{ 0.74, merge(brake, { Waist = { -8, 62, 0 } }) },
			{ 1, p.Rest },
		}, { Charge = 0.12, Release = 0.3 }),
		AttackSkill = signature(1.3, {
			{ 0, p.Rest },
			{ 0.14, crouch },
			{ 0.3, leap },
			{ 0.44, apex },
			{ 0.54, fall },
			{ 0.6, verdict },
			{ 0.8, merge(verdict, { Waist = { -38, 48, 0 } }) },
			{ 0.92, wrench },
			{ 1, p.Rest },
		}, { Charge = 0.1, Release = 0.6 }),
	}
end

-- Eolka (STAFF): Crimson Hellfire Pillar. Staff raised high in both hands, then driven forward
-- and down in a lunge. Idle is her poised stance: feet apart, staff held upright out at her
-- right side (the wrist rolls it upright beside her hip), left arm loose, a slight turn and a
-- knowing tilt of the head.
do
	local p = WeaponPoses.STAFF
	local drive = merge(p.Cast, { Waist = { -22, 0, 0 }, RightShoulder = { 60, 0, 0 }, LeftShoulder = { 55, 0, 10 }, LeftElbow = { 15, 0, 0 }, LeftHip = { 45, 0, -6 }, LeftKnee = { -50, 0, 0 }, RightHip = { -20, 0, 6 }, RightKnee = { -25, 0, 0 }, RootOffset = { 0, -0.4, -0.25 } })
	local poised: Pose = {
		Waist = { -2, 8, 0 }, Neck = { -3, -6, 4 },
		RightShoulder = { 10, 0, 28 }, RightElbow = { 35, 0, 0 }, RightWrist = { 45, -35, 0 },
		LeftShoulder = { 8, 0, -18 }, LeftElbow = { 20, 0, 0 },
		LeftHip = { 4, 0, -10 }, LeftKnee = { -10, 0, 0 }, LeftAnkle = { 6, 0, 10 },
		RightHip = { 4, 0, 10 }, RightKnee = { -10, 0, 0 }, RightAnkle = { 6, 0, -10 },
		RootOffset = { 0, -0.08, 0 },
	}
	Overrides.hero_eolka = {
		Idle = breathe(poised, 3.4),
		AttackSkill = signature(1.2, {
			{ 0, p.Stand },
			{ 0.4, merge(p.Raised, { LeftShoulder = { 170, 0, -5 }, LeftElbow = { 30, 0, 0 }, RootOffset = { 0, 0.2, 0 } }) },
			{ 0.7, drive },
			{ 0.85, drive },
			{ 1, p.Stand },
		}, { Release = 0.7 }),
	}
end

-- Solaris (STAFF): Supernova Starfall. Arms spread to gather the sky, brought together overhead,
-- then thrown forward to bring the star down. Idle is her serene stance: staff upright beside
-- her right hip (the arm angles measured for Eolka's idle), left hand held palm-up in front of
-- her as if cradling a sun.
do
	local p = WeaponPoses.STAFF
	local sunward: Pose = {
		Waist = { 0, 6, 0 }, Neck = { -4, -4, 0 },
		RightShoulder = { 10, 0, 28 }, RightElbow = { 35, 0, 0 }, RightWrist = { 45, -35, 0 },
		LeftShoulder = { 30, 0, -6 }, LeftElbow = { 80, 0, 0 }, LeftWrist = { 0, 0, 0 },
		LeftHip = { 2, 0, -6 }, LeftKnee = { -6, 0, 0 }, LeftAnkle = { 4, 0, 6 },
		RightHip = { 2, 0, 6 }, RightKnee = { -6, 0, 0 }, RightAnkle = { 4, 0, -6 },
		RootOffset = { 0, -0.04, 0 },
	}
	Overrides.hero_solaris = {
		Idle = breathe(sunward, 3.6),
		AttackSkill = signature(1.2, {
			{ 0, p.Stand },
			{ 0.35, merge(ATTACK_STANCE, { Waist = { 18, 0, 0 }, Neck = { 25, 0, 0 }, LeftShoulder = { 150, 0, -60 }, RightShoulder = { 150, 0, 60 }, LeftElbow = { 10, 0, 0 }, RightElbow = { 10, 0, 0 } }) },
			{ 0.6, merge(ATTACK_STANCE, { Waist = { 14, 0, 0 }, Neck = { 20, 0, 0 }, LeftShoulder = { 175, 0, -5 }, RightShoulder = { 175, 0, 5 }, LeftElbow = { 15, 0, 0 }, RightElbow = { 15, 0, 0 }, RootOffset = { 0, 0.15, 0 } }) },
			{ 0.72, merge(ATTACK_STANCE, { Waist = { -15, 0, 0 }, LeftShoulder = { 100, 0, -5 }, RightShoulder = { 100, 0, 5 }, LeftElbow = { 5, 0, 0 }, RightElbow = { 5, 0, 0 }, RootOffset = { 0, -0.2, 0 } }) },
			{ 0.88, merge(ATTACK_STANCE, { Waist = { -10, 0, 0 }, LeftShoulder = { 85, 0, -15 }, RightShoulder = { 85, 0, 15 } }) },
			{ 1, p.Stand },
		}, { Release = 0.72 }),
	}
end

-- Shurn (STAFF): Arcing Hearthbolt thrusts the crystal-bound branch staff forward while his left
-- hand channels a spark; Dawnstone Convergence raises the staff high overhead and drives it down
-- to call the radiant pillar. Idle is his grounded scholar stance from the reference art: wide
-- planted feet, staff held upright out at his right side, left hand raised open in front of him
-- channeling golden embers.
do
	local p = WeaponPoses.STAFF
	local hearthThrust = merge(p.Cast, { Waist = { -16, -12, 0 }, RightShoulder = { 78, -8, 12 }, RightElbow = { 16, 0, 0 }, LeftShoulder = { 52, 10, -18 }, LeftElbow = { 48, 0, 0 }, LeftKnee = { -26, 0, 0 }, RightKnee = { -22, 0, 0 }, RootOffset = { 0, -0.22, -0.15 } })
	local convergence = merge(p.Cast, { Waist = { -24, 0, 0 }, RightShoulder = { 56, 0, 4 }, LeftShoulder = { 62, 0, -12 }, LeftElbow = { 22, 0, 0 }, LeftHip = { 42, 0, -8 }, LeftKnee = { -48, 0, 0 }, RightHip = { -18, 0, 8 }, RightKnee = { -24, 0, 0 }, RootOffset = { 0, -0.38, -0.22 } })
	local channeler: Pose = {
		Waist = { -2, -4, 0 }, Neck = { -2, 4, 0 },
		RightShoulder = { 10, 0, 28 }, RightElbow = { 35, 0, 0 }, RightWrist = { 45, -35, 0 },
		LeftShoulder = { 28, 0, -20 }, LeftElbow = { 68, 0, 0 }, LeftWrist = { -10, 0, 0 },
		LeftHip = { 6, 0, -12 }, LeftKnee = { -14, 0, 0 }, LeftAnkle = { 8, 0, 12 },
		RightHip = { 6, 0, 12 }, RightKnee = { -14, 0, 0 }, RightAnkle = { 8, 0, -12 },
		RootOffset = { 0, -0.12, 0 },
	}
	Overrides.hero_shurn = {
		Idle = breathe(channeler, 3.3),
		AttackSpecial = signature(0.95, {
			{ 0, p.Stand },
			{ 0.35, merge(p.Raised, { Waist = { 8, 14, 0 }, LeftShoulder = { 44, -14, -22 }, LeftElbow = { 62, 0, 0 } }) },
			{ 0.65, hearthThrust },
			{ 0.85, merge(hearthThrust, { Waist = { -12, -8, 0 } }) },
			{ 1, p.Stand },
		}, { Release = 0.65 }),
		AttackSkill = signature(1.2, {
			{ 0, p.Stand },
			{ 0.38, merge(p.Raised, { Waist = { 14, 0, 0 }, RightShoulder = { 172, 0, 6 }, LeftShoulder = { 164, 0, -10 }, LeftElbow = { 28, 0, 0 }, RootOffset = { 0, 0.2, 0 } }) },
			{ 0.68, convergence },
			{ 0.86, merge(convergence, { Waist = { -20, 0, 0 } }) },
			{ 1, p.Stand },
		}, { Release = 0.68 }),
	}
end

-- Vane (STAFF), docs/vane-spell-animations-plan.md §3. Null Bolt flicks from the left hand.
-- Singularity Lance turns side-on and sights down the levelled staff like a rifle, the left hand
-- guiding the shaft, then recoils as the beam fires. Event Horizon reaches out with an open hand,
-- clenches it to crush space into the black hole, holds it, twists the fist, lets go and pushes
-- up his glasses. Idle is his calculating stance
-- from the reference art: upright, chin a little down, staff upright beside his right hip, left
-- hand held forward and out, palm up, presenting a spell matrix.
do
	local p = WeaponPoses.STAFF
	local calculating: Pose = {
		Waist = { 0, 4, 0 }, Neck = { -4, 6, 3 },
		RightShoulder = { 10, 0, 28 }, RightElbow = { 35, 0, 0 }, RightWrist = { 45, -35, 0 },
		LeftShoulder = { 48, 0, -30 }, LeftElbow = { 55, 0, 0 }, LeftWrist = { 0, 0, 0 },
		LeftHip = { 2, 0, -8 }, LeftKnee = { -6, 0, 0 }, LeftAnkle = { 4, 0, 8 },
		RightHip = { 2, 0, 8 }, RightKnee = { -6, 0, 0 }, RightAnkle = { 4, 0, -8 },
		RootOffset = { 0, -0.05, 0 },
	}
	-- Null Bolt, "The Dismissal" (docs/vane-spell-animations-plan.md §3.1): a two-finger flick of
	-- the left hand while the staff stays planted. Slow cock, a creeping late anticipation, a
	-- snap on Release, a small overshoot, then a moving hold with the hand still out. `ready` is
	-- the staff stand with his idle hand a little forward, so Idle hands off without a pop.
	local ready = merge(p.Stand, { LeftShoulder = { 30, 0, -18 }, LeftElbow = { 50, 0, 0 } })
	local cocked = merge(ready, { Waist = { 0, 10, 0 }, Neck = { -2, -6, 0 }, LeftShoulder = { 38, -20, -12 }, LeftElbow = { 108, 0, 0 }, LeftWrist = { -40, 0, 0 } })
	local creep = merge(cocked, { LeftElbow = { 114, 0, 0 }, LeftWrist = { -48, 0, 0 } })
	local flick = merge(ready, { Waist = { -4, -8, 0 }, LeftShoulder = { 82, 10, -12 }, LeftElbow = { 18, 0, 0 }, LeftWrist = { 35, 0, 0 } })
	local overshoot = merge(flick, { LeftElbow = { 10, 0, 0 }, LeftWrist = { 45, 0, 0 } })
	local lingering = merge(flick, { LeftShoulder = { 76, 8, -12 }, LeftElbow = { 22, 0, 0 }, LeftWrist = { 15, 0, 0 } })
	-- Singularity Lance, "Sightline" (§3.2). Side-on, left foot forward; the right wrist tips the
	-- staff from upright to level along the sightline, and the left hand aims two fingers beside
	-- it. Arm angles solved against the rig in Studio (staff level and dead ahead at `sighted`).
	local sideOn: Pose = { LeftHip = { 14, 0, -6 }, RightHip = { -10, 0, 6 }, LeftKnee = { -16, 0, 0 }, RightKnee = { -12, 0, 0 }, LeftAnkle = { 4, 0, 0 }, RightAnkle = { 14, 0, 0 } }
	local turnIn = merge(merge(ready, sideOn), { Waist = { -2, -14, 0 }, Neck = { -4, 12, 0 }, RightShoulder = { 50, 5, 8 }, RightElbow = { 40, 0, 0 }, RightWrist = { -50, 5, 0 }, LeftShoulder = { 70, -25, 25 }, LeftElbow = { 60, 0, 0 } })
	local sighted = merge(turnIn, { Waist = { -6, -12, 0 }, Neck = { -8, 12, 0 }, RightShoulder = { 70, 15, 6 }, RightElbow = { 40, 0, 0 }, RightWrist = { -100, 10, 0 }, LeftShoulder = { 95, -40, 40 }, LeftElbow = { 55, 0, 0 }, RootOffset = { 0, -0.12, 0 } })
	local pressing = merge(sighted, { Waist = { -8, -12, 0 }, RightShoulder = { 72, 15, 6 } })
	local recoil = merge(sighted, { Waist = { 6, -8, 0 }, RightShoulder = { 86, 15, 6 }, RightWrist = { -85, 10, 0 }, LeftShoulder = { 88, -35, 35 }, LeftElbow = { 65, 0, 0 }, RootOffset = { 0, -0.08, 0.14 } })
	local dismiss = merge(merge(ready, sideOn), { Waist = { 0, -10, 0 }, Neck = { -4, 10, 0 }, RightShoulder = { 40, -6, 10 }, RightElbow = { 45, 0, 0 }, RightWrist = { -10, 0, 0 }, LeftShoulder = { 40, 10, -24 }, LeftElbow = { 55, 0, 0 }, LeftWrist = { 0, 0, -30 } })

	-- Event Horizon, "The Crush" (§3.3). Gather wide, reach high to the target palm-out, crush
	-- down and clench on Release, hold with a micro-tremor while the staff tip points at the
	-- hole, twist the fist, let go, push up the glasses. Left-arm angles for the reach, crush and
	-- glasses push are solved against the rig in Studio (the hand stops in front of the lenses).
	local gather = merge(ready, { Waist = { 4, 8, 0 }, RightShoulder = { 12, 0, 24 }, RightElbow = { 40, 0, 0 }, LeftShoulder = { 60, 0, -70 }, LeftElbow = { 10, 0, 0 }, LeftWrist = { 0, 0, -20 }, RootOffset = { 0, -0.05, 0.08 } })
	local reach = merge(ATTACK_STANCE, { Waist = { -4, -6, 0 }, Neck = { 6, 0, 0 }, RightShoulder = { 100, 0, 14 }, RightElbow = { 0, 0, 0 }, LeftShoulder = { 130, -35, 20 }, LeftElbow = { 5, 0, 0 }, LeftWrist = { -30, 0, 0 } })
	local strain = merge(reach, { LeftShoulder = { 132, -35, 20 }, LeftWrist = { -34, 0, 0 } })
	local crush = merge(reach, { Waist = { -10, -4, 0 }, Neck = { -4, 0, 0 }, LeftShoulder = { 55, -20, 20 }, LeftElbow = { 65, 0, 0 }, LeftWrist = { 40, 0, 0 }, RightShoulder = { 88, 0, 10 }, RightElbow = { 5, 0, 0 }, RightWrist = { -45, 0, 0 }, RootOffset = { 0, -0.12, 0 } })
	local settle = merge(crush, { Waist = { -12, -4, 0 }, LeftElbow = { 70, 0, 0 } })
	local tremorA = merge(settle, { LeftShoulder = { 56.5, -20, 20 }, LeftWrist = { 41.5, 0, 0 } })
	local tremorB = merge(settle, { LeftShoulder = { 53.5, -20, 20 }, LeftWrist = { 38.5, 0, 0 } })
	local twist = merge(settle, { LeftElbow = { 75, 0, 0 }, LeftWrist = { 40, 0, -55 } })
	local letGo = merge(ready, { LeftShoulder = { 35, 0, -15 }, LeftElbow = { 70, 0, 0 } })
	local glasses = merge(ready, { Neck = { -6, 4, 0 }, LeftShoulder = { 110, -40, 30 }, LeftElbow = { 70, 0, 0 }, LeftWrist = { -20, 0, 0 } })

	Overrides.hero_vane = {
		Idle = breathe(calculating, 3.6),
		AttackBasic = signature(1.0, {
			{ 0, ready },
			{ 0.2, cocked },
			{ 0.45, creep },
			{ 0.52, flick },
			{ 0.58, overshoot },
			{ 0.8, lingering },
			{ 1, ready },
		}, { Charge = 0.2, Release = 0.52 }),
		AttackSpecial = signature(1.0, {
			{ 0, ready },
			{ 0.2, turnIn },
			{ 0.4, sighted },
			{ 0.52, pressing },
			{ 0.55, pressing }, -- the body locks on the shot
			{ 0.6, recoil },
			{ 0.75, dismiss },
			{ 0.88, merge(ready, { Waist = { 0, -3, 0 } }) },
			{ 1, ready },
		}, { Charge = 0.2, Release = 0.55 }),
		AttackSkill = signature(1.4, {
			{ 0, ready },
			{ 0.15, gather },
			{ 0.38, reach },
			{ 0.46, strain },
			{ 0.5, crush },
			{ 0.54, settle },
			{ 0.62, tremorA },
			{ 0.68, tremorB },
			{ 0.74, settle },
			{ 0.8, twist },
			{ 0.85, letGo },
			{ 0.9, glasses },
			{ 0.95, glasses }, -- a beat on the bridge of the glasses
			{ 1, ready },
		}, { Charge = 0.15, Release = 0.5 }),
	}
end

-- Valeria (TOME): Sanctuary Miracle. Tome hovers above open upturned left palm, right hand gestures.
-- Idle retains her characteristic poise: floating grimoire above palm, thoughtful head tilt, relaxed posture.
do
	local p = WeaponPoses.TOME
	local open = merge(ATTACK_STANCE, { Waist = { 10, 0, 0 }, Neck = { 12, 0, 0 }, LeftShoulder = { 110, 0, -70 }, LeftElbow = { 15, 0, 0 }, LeftWrist = { -105.0, 20.0, 60.0 }, RightShoulder = { 110, 0, 70 }, RightElbow = { 15, 0, 0 } })
	local reading = merge(STANCE, {
		Waist = { -2, 10, 0 }, Neck = { -8, 12, 3 },
		LeftShoulder = { 34, -16, -10 }, LeftElbow = { 58, 0, 0 }, LeftWrist = { -174.5, 72.6, 174.6 },
		RightShoulder = { 4, 0, 6 }, RightElbow = { 12, 0, 0 },
	})
	Overrides.hero_valeria = {
		Idle = floatIdle(reading, 3.4),
		AttackSkill = signature(1.2, {
			{ 0, p.Read },
			{ 0.35, merge(p.Channel, { Neck = { 20, 0, 0 }, LeftShoulder = { 150, 0, -10 }, LeftElbow = { 20, 0, 0 }, LeftWrist = { -110.0, 80.0, 20.0 }, RightShoulder = { 150, 0, 10 }, RightElbow = { 10, 0, 0 } }) },
			{ 0.65, open },
			{ 0.85, open },
			{ 1, p.Read },
		}, { Release = 0.65 }),
	}
end

-- Diran (TOME): Compass Mend extends a warding palm forward while the floating grimoire flares;
-- Vitality Covenant lifts the tome high with his left hand while his right hand calls down the
-- emerald-and-gold vitality seal over the lowest-HP ally. Idle is his grounded battle-cleric
-- stance from the reference art: wide planted feet, open grimoire hovering above his upturned
-- palm, free arm braced low at his side.
do
	local p = WeaponPoses.TOME
	local compassMend = merge(p.Release, { Waist = { -14, -8, 0 }, LeftShoulder = { 62, -12, -16 }, LeftElbow = { 44, 0, 0 }, LeftWrist = { -168.0, 74.0, 172.0 }, RightShoulder = { 86, 6, 10 }, RightElbow = { 14, 0, 0 }, LeftKnee = { -22, 0, 0 }, RightKnee = { -18, 0, 0 }, RootOffset = { 0, -0.18, -0.1 } })
	local covenant = merge(ATTACK_STANCE, { Waist = { 12, 0, 0 }, Neck = { 14, 0, 0 }, LeftShoulder = { 122, 0, -45 }, LeftElbow = { 22, 0, 0 }, LeftWrist = { -112.0, 32.0, 52.0 }, RightShoulder = { 136, 0, 38 }, RightElbow = { 18, 0, 0 }, RootOffset = { 0, 0.08, 0 } })
	local cleric: Pose = {
		Waist = { -2, -6, 0 }, Neck = { -3, 6, 0 },
		LeftShoulder = { 36, -12, -18 }, LeftElbow = { 62, 0, 0 }, LeftWrist = { -174.5, 72.6, 174.6 },
		RightShoulder = { 14, 0, 20 }, RightElbow = { 34, 0, 0 }, RightWrist = { -8, 0, 0 },
		LeftHip = { 6, 0, -12 }, LeftKnee = { -16, 0, 0 }, LeftAnkle = { 10, 0, 12 },
		RightHip = { 6, 0, 12 }, RightKnee = { -16, 0, 0 }, RightAnkle = { 10, 0, -12 },
		RootOffset = { 0, -0.12, 0 },
	}
	Overrides.hero_diran = {
		Idle = floatIdle(cleric, 3.2),
		AttackSpecial = signature(0.95, {
			{ 0, p.Read },
			{ 0.35, merge(p.Channel, { Waist = { 6, 10, 0 }, RightShoulder = { 54, 18, 24 }, RightElbow = { 64, 0, 0 } }) },
			{ 0.65, compassMend },
			{ 0.85, merge(compassMend, { Waist = { -10, -4, 0 } }) },
			{ 1, p.Read },
		}, { Release = 0.65 }),
		AttackSkill = signature(1.2, {
			{ 0, p.Read },
			{ 0.35, merge(p.Channel, { Waist = { 8, 0, 0 }, Neck = { 18, 0, 0 }, LeftShoulder = { 146, 0, -14 }, LeftElbow = { 24, 0, 0 }, LeftWrist = { -110.0, 76.0, 24.0 }, RightShoulder = { 148, 0, 14 }, RightElbow = { 16, 0, 0 } }) },
			{ 0.65, covenant },
			{ 0.85, covenant },
			{ 1, p.Read },
		}, { Release = 0.65 }),
	}
end

-- THE GILDED MIRROR (docs/gilded-mirror-plan.md §5): signature idles and full kits (Basic, Special,
-- Skill) built from the weapon key poses.

-- Isabelle (BOW), from her reference art: an upright, mid-stride stance with the bow held low in
-- her left hand, the draw hand loose at her side and her head turned a little to her left; her
-- walk keeps that upper body.
-- Her attacks are her own, not the generic bow set (a LeftWrist Y turn cants the bow sideways):
--   Glint Shot: a quick snap shot with the bow canted, head tilted to the monocle.
--   Ricochet: she turns away, drops low and pivots back into a flat, sideways shot.
--   Twin Reflection: a step back into a long, rising draw held while the arrow glows, then a
--   release with a small hop and the draw hand sweeping wide as the arrow splits.
do
	local p = WeaponPoses.BOW
	local poised = merge(p.Carry, { Waist = { 0, 6, 0 }, Neck = { 0, 12, 0 },
		LeftShoulder = { 18, 0, -6 }, LeftElbow = { 14, 0, 0 },
		RightShoulder = { -4, 0, 9 }, RightElbow = { 12, 0, 0 },
		LeftHip = { -8, 0, -3 }, RightHip = { 14, 0, 3 }, LeftKnee = { -4, 0, 0 }, RightKnee = { -14, 0, 0 },
		RootOffset = { 0, -0.04, 0 } })
	-- Glint Shot: a huntress's snap shot from a low, stalking crouch, side-on, the bow canted
	-- 35 degrees and her head tipped over the arrow to sight down it, anchored at her jaw; the
	-- draw hand snaps straight back off the string.
	local stalk: Pose = {
		LeftHip = { 20, -6, -6 }, LeftKnee = { -24, 0, 0 }, LeftAnkle = { 6, 0, 4 },
		RightHip = { -10, 6, 6 }, RightKnee = { -22, 0, 0 }, RightAnkle = { 22, 0, -4 },
		RootOffset = { 0, -0.18, 0 },
	}
	local glint: Pose = merge(stalk, { Root = { 0, -40, 0 }, Waist = { -12, -28, 0 }, Neck = { 24, 67, -34 },
		LeftShoulder = { 93, -24, -59 }, LeftElbow = { 0, 0, 0 }, LeftWrist = { -16, -16, -9 } })
	local glintSet = merge(glint, { Waist = { -12, 26, 0 }, Neck = { 10, 15, -15 },
		LeftShoulder = { 92, -42, 6 }, LeftElbow = { 48, 0, 0 }, LeftWrist = { -45, 13, -22 },
		RightShoulder = { -40, 9, -141 }, RightElbow = { 62, 0, 0 } })
	local glintDraw = merge(glint, { RightShoulder = { -97, 66, -108 }, RightElbow = { 91, 0, 0 } })
	local glintLoose = merge(glint, { Waist = { -10, -26, 0 }, RightShoulder = { 70, 79, 42 }, RightElbow = { 111, 0, 0 } })
	-- Ricochet: she turns away, drops into a deep crouch and pivots back side-on with the bow
	-- laid almost flat and her head tipped right over it.
	local turnAway = merge(p.Carry, { Waist = { 0, 40, 0 }, Neck = { 0, -10, 0 } })
	local ricochet: Pose = merge(p.Crouch, { Root = { 0, -60, 0 }, Waist = { -14, -20, 0 }, Neck = { 20, 79, -40 },
		LeftShoulder = { 41, -16, -95 }, LeftElbow = { 9, 0, 0 }, LeftWrist = { -12, -12, 5 } })
	local ricochetSet = merge(ricochet, { Waist = { -14, 53, 0 }, Neck = { 7, 8, -24 },
		LeftShoulder = { 82, -81, -15 }, LeftElbow = { 45, 0, 0 }, LeftWrist = { -45, 18, -4 },
		RightShoulder = { -27, -12, -119 }, RightElbow = { 59, 0, 0 } })
	local ricochetDraw = merge(ricochet, { RightShoulder = { -124, 64, -92 }, RightElbow = { 102, 0, 0 } })
	local ricochetLoose = merge(ricochet, { Waist = { -10, -20, 0 }, RightShoulder = { 21, 71, 79 }, RightElbow = { 117, 0, 0 } })
	-- Twin Reflection: a step back into a tall stance, a long rising draw held at 25 degrees
	-- while the arrow glows, a release with a small hop and the draw hand sweeping wide.
	local stepBack: Pose = {
		LeftHip = { 14, -6, -8 }, LeftKnee = { -8, 0, 0 }, LeftAnkle = { 4, 0, 6 },
		RightHip = { -16, 6, 8 }, RightKnee = { -10, 0, 0 }, RightAnkle = { 20, 0, -6 },
		RootOffset = { 0, 0.05, 0.25 },
	}
	local twin: Pose = merge(stepBack, { Root = { 0, -55, 0 }, Waist = { 10, -28, 0 }, Neck = { 35, 77, -40 },
		LeftShoulder = { 96, -29, -75 }, LeftElbow = { 0, 0, 0 }, LeftWrist = { -11, -16, -4 } })
	local twinSet = merge(twin, { Waist = { 10, 36, 0 }, Neck = { 10, 18, -12 },
		LeftShoulder = { 67, -80, -37 }, LeftElbow = { 50, 0, 0 }, LeftWrist = { -44, 55, -16 },
		RightShoulder = { -36, 4, -136 }, RightElbow = { 60, 0, 0 } })
	local rise = merge(twin, { RightShoulder = { 174, 56, -73 }, RightElbow = { 91, 0, 0 } })
	local hop = merge(twin, { Waist = { 6, -24, 0 }, RightShoulder = { 55, 67, 28 }, RightElbow = { 92, 0, 0 }, RootOffset = { 0, 0.3, 0.25 } })
	local sweep = merge(twin, { Waist = { 2, -20, 0 }, LeftShoulder = { 88, -29, -75 }, RightShoulder = { -133, 59, -127 }, RightElbow = { 15, 0, 0 }, RootOffset = { 0, 0.1, 0.25 } })
	Overrides.hero_isabelle = {
		Idle = breathe(poised, 3.4),
		Move = walk(poised), -- her stance's upper body (bow low, draw hand loose) over walking legs
		AttackBasic = signature(0.7, {
			{ 0, p.Carry },
			{ 0.25, glintSet },
			{ 0.5, glintDraw },
			{ 0.58, glintLoose, true },
			{ 0.74, glintLoose },
			{ 1, p.Carry },
		}, { Release = 0.58, Nock = 0.85 }, { Set = 0.25, Full = 0.5, Anchor = { 0.1, -0.3, -0.45 } }),
		AttackSpecial = signature(0.95, {
			{ 0, p.Carry },
			{ 0.28, turnAway }, -- turns away
			{ 0.5, ricochetSet }, -- pivots back low, bow flat
			{ 0.66, ricochetDraw },
			{ 0.74, ricochetLoose, true },
			{ 0.86, ricochetLoose },
			{ 1, p.Carry },
		}, { Release = 0.74, Nock = 0.9 }, { Set = 0.5, Full = 0.66, Anchor = { 0.05, -0.42, -0.3 } }),
		AttackSkill = signature(1.5, {
			{ 0, p.Carry },
			{ 0.2, twinSet }, -- a step back
			{ 0.4, rise },
			{ 0.62, merge(rise, { Waist = { 14, -30, 0 } }) }, -- the arrow glows while she holds the draw
			{ 0.68, hop, true }, -- release with a hop
			{ 0.82, sweep },
			{ 1, p.Carry },
		}, { Charge = 0.2, Release = 0.68, Nock = 0.9 }, { Set = 0.2, Full = 0.4 }),
	}
end

-- Nyx (DAGGERS). She has her own grip (HeroSockets.HERO_GRIPS): the right dagger held forward
-- (blade out past the thumb, upright when the forearm points forward) and the left reversed
-- along the forearm, so her poses are her own rather than the shared reverse-grip set.
-- Idle, from the user's pose reference: a wide guard, right foot forward and body turned a
-- little to her left, the forward blade held across her chest in the right hand and the reversed
-- blade low by her left hip. Her walk carries the same guard over the walking legs.
-- Gilt Cut: an overhead diagonal cut with the forward blade, then a backhand sweep of the
-- reversed one. Mirror Step: she gathers low and blinks behind the target (leaving a glass
-- clone in her place, SkillVfx MIRROR_STEP), thrusts with the reversed blade held across as a
-- guard, then recovers as she blinks back. Shatterdance: the
-- forward blade upright before her face crossed by the reversed one, held while the mirror
-- clones cut, then both slashed out as the last one shatters.
do
	local p = WeaponPoses.DAGGERS
	local ready = merge(p.Crouched, { Waist = { -6, 0, 0 },
		RightShoulder = { 60, 0, 15 }, RightElbow = { 30, 0, 0 }, RightWrist = { 0, 0, 0 },
		LeftShoulder = { 50, 0, -15 }, LeftElbow = { 80, 0, 0 }, LeftWrist = { 0, 0, 0 } })
	local guardArms: Pose = { Waist = { -4, 14, 0 }, Neck = { -6, -12, 0 },
		-- Upper arm turned in so the forearm lies across the chest; the wrist angles the blade
		-- down and out to her right (measured in Studio).
		RightShoulder = { 40, 45, 0 }, RightElbow = { 90, 0, 0 }, RightWrist = { 110, 0, 0 },
		LeftShoulder = { 15, 0, -14 }, LeftElbow = { 35, 0, 0 }, LeftWrist = { 0, 0, 0 } }
	local guard = merge(guardArms, {
		LeftHip = { -6, 0, -16 }, LeftKnee = { -18, 0, 0 }, LeftAnkle = { 14, 0, 16 },
		RightHip = { 10, 0, 14 }, RightKnee = { -16, 0, 0 }, RightAnkle = { 2, 0, -14 },
		RootOffset = { 0, -0.22, 0 } })
	local kneel = merge(p.Crouched, { Waist = { -20, 0, 0 }, LeftHip = { 80, 0, 0 }, LeftKnee = { -90, 0, 0 }, RightHip = { -10, 0, 0 }, RightKnee = { -100, 0, 0 },
		RightShoulder = { 40, 0, 20 }, RightElbow = { 60, 0, 0 }, LeftShoulder = { 40, 0, -20 }, LeftElbow = { 90, 0, 0 }, RootOffset = { 0, -0.6, 0 } })
	local thrust = merge(p.Crouched, { Waist = { -24, 0, 0 }, RightShoulder = { 95, 0, 0 }, RightElbow = { 0, 0, 0 }, RightWrist = { -90, 0, 0 },
		LeftShoulder = { 70, 0, -30 }, LeftElbow = { 100, 0, 0 }, LeftWrist = { 0, 0, 0 } })
	local summon = merge(p.Crouched, { Waist = { -6, 0, 0 }, Neck = { 6, 0, 0 },
		RightShoulder = { 95, 0, 10 }, RightElbow = { 0, 0, 0 }, RightWrist = { 0, 0, 0 },
		LeftShoulder = { 80, 0, 30 }, LeftElbow = { 70, 0, 0 }, LeftWrist = { 0, 0, 0 }, RootOffset = { 0, -0.25, 0 } })
	local flingOut = merge(p.Crouched, { Waist = { -14, 0, 0 }, RightShoulder = { 70, 0, 70 }, RightElbow = { 10, 0, 0 }, RightWrist = { -60, 0, 0 },
		LeftShoulder = { 70, 0, -70 }, LeftElbow = { 10, 0, 0 }, LeftWrist = { 0, 0, 0 }, RootOffset = { 0, -0.3, 0 } })
	Overrides.hero_nyx = {
		Idle = breathe(guard, 3.0),
		Move = walk(guardArms),
		AttackBasic = signature(0.65, {
			{ 0, ready },
			{ 0.22, merge(ready, { Waist = { 0, 20, 0 }, RightShoulder = { 150, 0, 30 }, RightElbow = { 40, 0, 0 }, RightWrist = { -40, 0, 0 } }) }, -- forward blade high
			{ 0.38, merge(ready, { Waist = { -10, -20, 0 }, RightShoulder = { 40, 0, -25 }, RightElbow = { 10, 0, 0 }, RightWrist = { -60, 0, 0 } }) }, -- diagonal cut
			{ 0.5, merge(ready, { Waist = { -8, -24, 0 }, RightShoulder = { 40, 0, -25 }, RightElbow = { 10, 0, 0 }, RightWrist = { -60, 0, 0 },
				LeftShoulder = { 80, 0, 40 }, LeftElbow = { 60, 0, 0 } }) }, -- reversed blade drawn across
			{ 0.62, merge(ready, { Waist = { -8, 20, 0 }, RightShoulder = { 40, 0, 10 }, RightElbow = { 40, 0, 0 },
				LeftShoulder = { 80, 0, -75 }, LeftElbow = { 10, 0, 0 } }) }, -- backhand sweep
			{ 1, ready },
		}, { Release = 0.38 }),
		AttackSpecial = signature(1.0, {
			{ 0, ready },
			{ 0.28, merge(kneel, { RootOffset = { 0, -0.5, 0 } }) }, -- gathers low, then blinks out
			{ 0.36, merge(ready, { Waist = { -12, 0, 0 } }) }, -- appears behind the target
			{ 0.48, merge(thrust, { RootOffset = { 0, -0.2, -0.5 } }) }, -- the thrust
			{ 0.72, merge(thrust, { RootOffset = { 0, -0.2, -0.45 } }) },
			{ 0.82, ready }, -- blinks back home
			{ 1, ready },
		}, { Charge = 0.3, Release = 0.48 }),
		AttackSkill = signature(1.4, {
			{ 0, ready },
			{ 0.12, summon }, -- blades crossed before her face: the clones appear
			{ 0.3, merge(summon, { Waist = { -10, 0, 0 }, RootOffset = { 0, -0.3, 0 } }) },
			{ 0.78, merge(summon, { Waist = { -12, 0, 0 }, RootOffset = { 0, -0.32, 0 } }) }, -- holds while they cut
			{ 0.88, flingOut }, -- slashes both out as the last one shatters
			{ 1, ready },
		}, { Charge = 0.12, Release = 0.3 }),
	}
end

-- Caspian (SWORD_SHIELD). Idle, from his reference art: standing tall with his feet apart, the
-- sword hanging low in his right hand with the blade angled down across his front, and the
-- shield at his left side; his walk keeps the same arms. Gilt Edge: a diagonal slash: he turns
-- right with the sword cocked high over his right shoulder, then turns into the strike and
-- sweeps the blade down across his body to low on his left, and follows through. Polished Bash: he turns away, pulling the shield back,
-- then steps in and drives it forward (the shield flashes like a mirror). Looking-Glass
-- Bulwark: he plants the shield in front of him and raises the sword overhead as the glass wall
-- rises.
do
	local p = WeaponPoses.SWORD_SHIELD
	local arms: Pose = { Waist = { 0, 6, 0 }, Neck = { 2, -4, 0 },
		-- Measured in Studio: the upper arm turned in angles the low blade across his front, and
		-- the shield arm turned (Y -60) shows the shield's face forward at his side.
		RightShoulder = { 12, 35, 12 }, RightElbow = { 20, 0, 0 }, RightWrist = { -70, 0, 0 },
		LeftShoulder = { 10, -60, -12 }, LeftElbow = { 25, 0, 0 } }
	local stand = merge(arms, { LeftHip = { 2, 0, -8 }, LeftKnee = { -6, 0, 0 }, LeftAnkle = { 2, 0, 8 },
		RightHip = { -2, 0, 8 }, RightKnee = { -6, 0, 0 }, RightAnkle = { 4, 0, -8 }, RootOffset = { 0, -0.05, 0 } })
	local planted = merge(p.Bash, { Waist = { -16, -10, 0 }, LeftShoulder = { 60, 10, -5 }, RootOffset = { 0, -0.3, 0 },
		LeftKnee = { -40, 0, 0 }, RightKnee = { -35, 0, 0 }, LeftHip = { 30, 0, -6 } })
	local raised = merge(planted, { RightShoulder = { 175, 0, 5 }, RightElbow = { 10, 0, 0 }, Neck = { 12, 0, 0 } })
	Overrides.hero_caspian = {
		Idle = breathe(stand, 3.6),
		Move = walk(arms),
		AttackBasic = signature(0.8, {
			{ 0, stand },
			{ 0.3, merge(stand, { Waist = { 6, -30, 0 }, Neck = { 2, 20, 0 },
				RightShoulder = { 150, 0, 45 }, RightElbow = { 95, 0, 0 }, RightWrist = { 0, 0, 0 } }) }, -- cocked high over his right shoulder
			{ 0.48, merge(stand, { Waist = { -12, 25, 0 }, Neck = { 0, -15, 0 },
				RightShoulder = { 72, 0, -18 }, RightElbow = { 5, 0, 0 }, RightWrist = { -95, 0, 0 },
				LeftHip = { 18, 0, -8 }, LeftKnee = { -20, 0, 0 }, RightHip = { -12, 0, 8 }, RightKnee = { -16, 0, 0 },
				RootOffset = { 0, -0.1, -0.3 } }) }, -- the cut, down across the body
			{ 0.64, merge(stand, { Waist = { -14, 35, 0 }, Neck = { 0, -20, 0 },
				RightShoulder = { 40, 0, -40 }, RightElbow = { 10, 0, 0 }, RightWrist = { -80, 0, 0 },
				LeftHip = { 18, 0, -8 }, LeftKnee = { -20, 0, 0 }, RightHip = { -12, 0, 8 }, RightKnee = { -16, 0, 0 },
				RootOffset = { 0, -0.1, -0.3 } }) }, -- follow-through, blade low on his left
			{ 1, stand },
		}, { Release = 0.48 }),
		AttackSpecial = signature(0.9, {
			{ 0, stand },
			{ 0.35, merge(p.Guard, { Waist = { 4, 30, 0 }, LeftShoulder = { 40, -40, -10 }, LeftElbow = { 100, 0, 0 } }) }, -- shield pulled back
			{ 0.58, merge(p.Bash, { RootOffset = { 0, -0.1, -0.6 } }) }, -- steps in and drives it forward
			{ 0.78, merge(p.Bash, { RootOffset = { 0, -0.1, -0.5 } }) },
			{ 1, stand },
		}, { Release = 0.58 }),
		AttackSkill = signature(1.2, {
			{ 0, stand },
			{ 0.3, planted }, -- plants the shield
			{ 0.55, raised }, -- raises the sword as the wall rises
			{ 0.85, raised },
			{ 1, stand },
		}, { Release = 0.55 }),
	}
end

-- Seraphine (STAFF), from her reference art: she floats, always. Every clip lifts her root
-- HOVER studs off the floor, with her legs hanging loose under the robe.
-- Idle: the staff upright in her right hand, the free hand raised palm up before her chest (where
-- the art's grimoire floats), head tilted down a little, bobbing slowly up and down.
-- Move: no steps; she flies, leaning forward with her legs trailing behind, the staff carried
-- ahead in her right hand and her left arm swept back, still bobbing (the user's flying-wizard
-- reference). Shard Bolt: a one-handed point with the staff as a halo shard flies. Refraction:
-- she draws the staff back while the halo shards fly to its tip and join into a prism (Charge),
-- then thrusts it forward to launch it (Release). Hall of Mirrors: the staff held overhead in
-- both hands while she turns a slow half circle and the crystals fire.
do
	local p = WeaponPoses.STAFF
	local HOVER, BOB = 0.9, 0.18
	-- Legs hanging loose under the robe while she floats.
	local DANGLE: Pose = {
		LeftHip = { 10, 0, -2 }, RightHip = { -2, 0, 2 },
		LeftKnee = { -18, 0, 0 }, RightKnee = { -30, 0, 0 },
		LeftAnkle = { 20, 0, 0 }, RightAnkle = { 20, 0, 0 },
	}
	-- Lifts every key of a clip HOVER studs (keeping any RootOffset it has), plus a bob of `amp`
	-- studs over one sine cycle across the clip, and lets the legs hang. Ends where it starts, so
	-- loops stay seamless.
	local function floating(c: Clip, amp: number): Clip
		for _, k in c.Keys do
			local pose = merge(k.Pose, DANGLE)
			local ro = k.Pose.RootOffset or { 0, 0, 0 }
			local wave = if k.T <= 0 or k.T >= 1 then 0 else math.sin(2 * math.pi * k.T)
			pose.RootOffset = { ro[1], ro[2] + HOVER + amp * wave, ro[3] }
			k.Pose = pose
		end
		return c
	end
	local regent = merge(p.Stand, { Neck = { -4, 0, 0 }, LeftShoulder = { 40, -10, -20 }, LeftElbow = { 60, 0, 0 }, LeftWrist = { -174.5, 72.6, 174.6 } })
	-- Flying: the whole body leans forward (Root -X tilts toward -Z), the head lifts (+X) to look
	-- ahead, the legs trail gracefully behind, the staff arm reaches ahead and the free arm sweeps back.
	local fly = merge(regent, {
		Root = { -22, 0, 0 }, Waist = { -4, 0, 0 }, Neck = { 20, 0, 0 },
		RightShoulder = { 68, 0, 14 }, RightElbow = { 30, 0, 0 }, RightWrist = { -45, 0, 0 }, -- staff tipped ahead
		LeftShoulder = { -22, 0, -16 }, LeftElbow = { 20, 0, 0 }, LeftWrist = { 0, 0, 0 },
	})
	local flyLegs: Pose = {
		LeftHip = { -10, 0, -3 }, RightHip = { -2, 0, 3 },
		LeftKnee = { -28, 0, 0 }, RightKnee = { -16, 0, 0 },
		LeftAnkle = { 25, 0, 0 }, RightAnkle = { 25, 0, 0 },
	}
	local overhead = merge(ATTACK_STANCE, {
		Waist = { 8, 0, 0 }, Neck = { 12, 0, 0 }, RootOffset = { 0, 0.15, 0 },
		RightShoulder = { 160, 0, -14 }, RightElbow = { 14, 0, 0 }, RightWrist = { 45, 100, -10 },
		LeftShoulder = { 154, -10, 16 }, LeftElbow = { 27, 0, 0 }, LeftWrist = { 45, -100, 10 },
	})
	local drawBack = merge(p.Stand, { Waist = { 6, 30, 0 }, RightShoulder = { 60, 0, 40 }, RightElbow = { 70, 0, 0 },
		LeftShoulder = { 60, 0, -30 }, LeftElbow = { 40, 0, 0 } })
	local thrust = merge(p.Cast, { Waist = { -12, -10, 0 }, RightShoulder = { 95, 0, 0 }, RootOffset = { 0, -0.05, -0.3 } })
	-- The flight loop: the arms sway a little against the bob; the legs trail throughout.
	local flyNeck = fly.Neck or { 0, 0, 0 }
	local function flight(sway: number): Pose
		return merge(fly, {
			RightShoulder = { 68 + 4 * sway, 0, 14 }, LeftShoulder = { -22 - 6 * sway, 0, -16 },
			Waist = { -4 - 2 * sway, 5 * sway, 3 * sway }, -- the torso sways and rolls with the bob
			Neck = { flyNeck[1] + 1.5 * sway, flyNeck[2] - 4 * sway, flyNeck[3] - 2 * sway }, -- the head stays on the way ahead
		})
	end
	local move = floating(clip(1.6, true, {
		{ 0, flight(0) }, { 0.25, flight(1) }, { 0.5, flight(0) }, { 0.75, flight(-1) }, { 1, flight(0) },
	}), BOB)
	for _, k in move.Keys do
		k.Pose = merge(k.Pose, flyLegs) -- trailing legs instead of hanging ones
	end
	Overrides.hero_seraphine = {
		Idle = floating(floatIdle(regent, 3.0), BOB),
		Move = move,
		AttackBasic = floating(signature(0.8, {
			{ 0, p.Stand },
			{ 0.4, p.Cast },
			{ 0.6, merge(p.Cast, { RightShoulder = { 98, 0, 0 } }) },
			{ 1, p.Stand },
		}, { Release = 0.6 }), 0),
		AttackSpecial = floating(signature(1.2, {
			{ 0, p.Stand },
			{ 0.2, drawBack }, -- the three halo shards fly to the tip and join into a prism
			{ 0.5, merge(drawBack, { Waist = { 8, 36, 0 } }) },
			{ 0.62, thrust },
			{ 0.82, thrust },
			{ 1, p.Stand },
		}, { Charge = 0.2, Release = 0.62 }), 0),
		AttackSkill = floating(signature(1.4, {
			{ 0, p.Stand },
			{ 0.25, overhead },
			{ 0.5, merge(overhead, { Waist = { 8, 60, 0 } }) },
			{ 0.75, merge(overhead, { Waist = { 8, -60, 0 } }) },
			{ 0.9, overhead },
			{ 1, p.Stand },
		}, { Charge = 0.25, Release = 0.5 }), 0),
	}
end

-- Rook (AXE): from his reference art (Heavy fur mantle, crossed chest medallions, rose skull
-- belt). A wide, low two-handed guard: feet planted far apart with the knees bent deep, leaning
-- a little into it, the right hand choked up under the axe head low in front of his right
-- thigh with the blade hanging down, and the haft rising diagonally across his body to the left
-- hand at his left hip (solved onto OffhandGrip by HeroAnimator). Both hands stay on the haft
-- when he walks and swings. His attacks are whole-body moves (docs/gilded-mirror-plan.md 5.5):
-- Gilt Cleave alternates a forehand sweep and a rising backhand (Alternates); Last Stand is a
-- leaping chop; Gilded Frenzy is a leap slam into four full whirlwind spins and a roar. The
-- leaps and spins are root motion only; the server position never moves.
-- Gilded Frenzy: a jump, a two-handed slam, then one spin with the axe.
do
	local p = WeaponPoses.AXE
	-- Measured in Studio against the art (the left arm is the offhand solver's): the right wrist
	-- was searched so the axe head hangs at his right thigh with the blade's face forward and the
	-- off-hand grip lands in front of his left hip.
	local carry: Pose = {
		LeftHip = { 20, 0, -26 }, RightHip = { -6, 0, 26 },
		LeftKnee = { -34, 0, 0 }, RightKnee = { -30, 0, 0 },
		LeftAnkle = { 14, 0, 26 }, RightAnkle = { 24, 0, -26 },
		RootOffset = { 0, -0.35, 0 },
		Waist = { -8, 10, 0 }, Neck = { -6, -8, 0 },
		RightShoulder = { 25, -20, -15 }, RightElbow = { 20, 0, 0 }, RightWrist = { -180, -120, -150 },
	}
	-- A heavy, rolling stride that keeps the two-handed guard. Each step has four beats: heel
	-- strike (front leg reaching, toes up; back leg pushing off on its toes), the weight dropping
	-- onto the front knee, passing (the stance leg under him, the other knee lifted through) and
	-- the push into the next step. Above the waist: the torso twists against the legs (the
	-- shoulder opposite the forward foot comes round), rolls toward the stance leg and dips on
	-- each landing; the head stays on the target; the axe arm sways with the twist; the hips
	-- shift over the planted foot. The left arm follows the haft (offhand solver).
	local function rookWalk(): Clip
		-- side: +1 = left foot forward, -1 = right foot forward. beat: "strike" | "load" | "pass" | "push".
		local function step(side: number, beat: string): Pose
			local front = if side > 0 then "Left" else "Right"
			local back = if side > 0 then "Right" else "Left"
			local out = if side > 0 then 1 else -1 -- -out is the front leg's outward hip Z (Left splays negative)
			local legs: Pose = {}
			local twist, dip, roll, lift, lean = 0, 0, 0, 0, -6
			if beat == "strike" then
				legs[front .. "Hip"] = { 32, 0, -10 * out }; legs[front .. "Knee"] = { -8, 0, 0 }; legs[front .. "Ankle"] = { -14, 0, 10 * out }
				legs[back .. "Hip"] = { -22, 0, 10 * out }; legs[back .. "Knee"] = { -24, 0, 0 }; legs[back .. "Ankle"] = { 22, 0, -10 * out }
				twist, dip, roll, lean = 9, -0.06, 2, -8
			elseif beat == "load" then
				legs[front .. "Hip"] = { 24, 0, -10 * out }; legs[front .. "Knee"] = { -26, 0, 0 }; legs[front .. "Ankle"] = { 4, 0, 10 * out }
				legs[back .. "Hip"] = { -16, 0, 10 * out }; legs[back .. "Knee"] = { -40, 0, 0 }; legs[back .. "Ankle"] = { 30, 0, -10 * out }
				twist, dip, roll, lean = 6, -0.16, 4, -11
			elseif beat == "pass" then
				-- The front leg is now under him; the back leg swings through with the knee high.
				legs[front .. "Hip"] = { 2, 0, -8 * out }; legs[front .. "Knee"] = { -12, 0, 0 }; legs[front .. "Ankle"] = { 6, 0, 8 * out }
				legs[back .. "Hip"] = { 30, 0, 6 * out }; legs[back .. "Knee"] = { -62, 0, 0 }; legs[back .. "Ankle"] = { -6, 0, -6 * out }
				twist, dip, roll, lift, lean = 0, 0.04, 3, 1, -5
			else -- "push": the stance leg drives back onto its toes as the swing leg reaches ahead
				legs[front .. "Hip"] = { -14, 0, -8 * out }; legs[front .. "Knee"] = { -14, 0, 0 }; legs[front .. "Ankle"] = { 18, 0, 8 * out }
				legs[back .. "Hip"] = { 26, 0, 8 * out }; legs[back .. "Knee"] = { -28, 0, 0 }; legs[back .. "Ankle"] = { -8, 0, -8 * out }
				twist, dip, roll, lift, lean = -4, 0.0, 1, 0, -6
			end
			local yaw = twist * side -- left foot forward: torso turns left (+Y)
			return merge(merge(carry, legs), {
				Waist = { lean, 10 + yaw, roll * -out },
				Neck = { -6 - dip * 20, -8 - yaw * 0.8, -roll * -out * 0.6 }, -- the head stays level and on the target
				RightShoulder = { 25 + yaw * 0.6 + lift * 3, -20, -15 }, -- the axe sways with the twist
				RightElbow = { 20 - dip * 30, 0, 0 },
				RootOffset = { 0.08 * -out * (if beat == "pass" then 1 else 0.6), -0.35 + dip, 0 },
			})
		end
		local keys = {}
		local beats = { "strike", "load", "pass", "push" }
		for i, side in { 1, -1 } do
			for j, beat in beats do
				table.insert(keys, { ((i - 1) * 4 + (j - 1)) / 8, step(side, beat) })
			end
		end
		table.insert(keys, { 1, keys[1][2] })
		return clip(0.95, true, keys)
	end
	-- Legs for the swings: a long step forward with the left foot (forehand) or the right (backhand).
	local stepLeft: Pose = { LeftHip = { 42, 0, -10 }, LeftKnee = { -44, 0, 0 }, LeftAnkle = { 4, 0, 10 },
		RightHip = { -22, 0, 12 }, RightKnee = { -22, 0, 0 }, RightAnkle = { 28, 0, -12 } }
	local stepRight: Pose = { RightHip = { 40, 0, 10 }, RightKnee = { -42, 0, 0 }, RightAnkle = { 4, 0, -10 },
		LeftHip = { -20, 0, -12 }, LeftKnee = { -22, 0, 0 }, LeftAnkle = { 28, 0, 12 } }
	local loadBack: Pose = { LeftHip = { 14, 0, -18 }, LeftKnee = { -18, 0, 0 }, LeftAnkle = { 4, 0, 18 },
		RightHip = { -4, 0, 20 }, RightKnee = { -46, 0, 0 }, RightAnkle = { 26, 0, -20 } }
	local crouch: Pose = { LeftHip = { 62, 0, -14 }, LeftKnee = { -96, 0, 0 }, LeftAnkle = { 34, 0, 14 },
		RightHip = { 48, 0, 14 }, RightKnee = { -100, 0, 0 }, RightAnkle = { 50, 0, -14 } }
	local tuck: Pose = { LeftHip = { 55, 0, -8 }, LeftKnee = { -95, 0, 0 }, LeftAnkle = { 20, 0, 8 },
		RightHip = { 22, 0, 8 }, RightKnee = { -70, 0, 0 }, RightAnkle = { 20, 0, -8 } }
	local wide: Pose = { LeftHip = { 18, 0, -26 }, LeftKnee = { -38, 0, 0 }, LeftAnkle = { 14, 0, 26 },
		RightHip = { -6, 0, 26 }, RightKnee = { -34, 0, 0 }, RightAnkle = { 24, 0, -26 } }
	local function with(base: Pose, legs: Pose, extra: Pose): Pose
		return merge(merge(base, legs), extra)
	end

	-- Gilt Cleave, forehand: haul the axe back over the right shoulder with the torso wound away
	-- and the weight on the right leg, then a long step in with the left as the whole body whips
	-- through a flat 160-degree sweep; the momentum carries him round a quarter turn.
	local forehand = signature(0.9, {
		{ 0, carry },
		{ 0.32, with(p.SweepBack, loadBack, { Waist = { 4, -70, 0 }, Neck = { -2, 58, 0 }, RootOffset = { 0, -0.38, 0.25 } }) },
		{ 0.6, with(p.SweepThrough, stepLeft, { Waist = { -12, 72, 0 }, Neck = { 6, -56, 0 }, RootOffset = { 0, -0.48, -0.7 } }) },
		{ 0.78, with(p.SweepThrough, stepLeft, { Root = { 0, 28, 0 }, Waist = { -16, 88, 0 }, Neck = { 8, -60, 0 }, RootOffset = { 0, -0.5, -0.8 } }) },
		{ 1, carry },
	}, { Release = 0.6 })
	-- Gilt Cleave, backhand: the axe swung across to his left and loaded low, then dragged back
	-- in a rising diagonal as he steps through with the right foot, finishing high over his
	-- right shoulder. Same Release as the forehand (the server times the hit from it).
	local backhand = signature(0.9, {
		{ 0, carry },
		{ 0.3, with(p.SweepThrough, loadBack, { Waist = { -14, 82, 0 }, Neck = { 4, -58, 0 }, RootOffset = { 0, -0.42, 0.1 } }) },
		{ 0.6, with(p.SweepBack, stepRight, { Waist = { 6, -24, 0 }, Neck = { -4, 20, 0 }, RootOffset = { 0, -0.4, -0.65 } }) },
		{ 0.8, with(p.Windup, stepRight, { Root = { 0, -22, 0 }, Waist = { 12, -58, 0 }, Neck = { -8, 44, 0 }, RootOffset = { 0, -0.2, -0.75 } }) },
		{ 1, carry },
	}, { Release = 0.6 })

	-- Last Stand: a deep crouch with the axe dragged behind (Charge), a spring about 4.5 studs up
	-- and toward the target with the axe swung up behind his head as he roars, then down into
	-- the ground as he lands on bent knees (Release), and a backward heave to wrench it free.
	local airborne = with(p.High, tuck, { Waist = { 16, 0, 0 }, Neck = { -30, 0, 0 } })
	local lastStand = signature(1.3, {
		{ 0, carry },
		{ 0.2, with(p.SweepBack, crouch, { Waist = { -28, -40, 0 }, Neck = { -24, 30, 0 }, RootOffset = { 0, -1.0, 0.25 } }) },
		{ 0.34, merge(airborne, { RootOffset = { 0, 3.2, -0.9 } }) },
		{ 0.46, merge(airborne, { RootOffset = { 0, 4.5, -1.6 } }) }, -- the roar at the top
		{ 0.6, merge(p.Slam, { RootOffset = { 0, -0.65, -2.1 } }) },
		{ 0.78, merge(p.Slam, { RootOffset = { 0, -0.7, -2.1 } }) },
		{ 0.9, with(p.Windup, wide, { Waist = { 18, -20, 0 }, Neck = { -6, 10, 0 }, RootOffset = { 0, -0.3, -1.2 } }) },
		{ 1, carry },
	}, { Charge = 0.2, Release = 0.6 })

	-- Gilded Frenzy (2.4 s, ticks 0.3 s apart from Release): a crouch, a leap about 6 studs
	-- straight up with the axe overhead, the slam at 0.36 (the first tick), then four full spins
	-- (one per tick, the axe held out at arm's length, edging forward), the axe flung wide and an
	-- overhead roar as the frenzy takes hold.
	local frenzyKeys = {
		{ 0, carry },
		{ 0.1, with(carry, crouch, { Waist = { -24, 0, 0 }, Neck = { -18, 0, 0 }, RootOffset = { 0, -1.0, 0 } }) },
		{ 0.2, with(p.High, tuck, { Waist = { 14, 0, 0 }, Neck = { -20, 0, 0 }, RootOffset = { 0, 5.4, -0.2 } }) },
		{ 0.29, with(p.High, tuck, { Waist = { 20, 0, 0 }, Neck = { -26, 0, 0 }, RootOffset = { 0, 6.0, -0.4 } }) },
		{ 0.36, merge(p.Slam, { RootOffset = { 0, -0.65, -0.5 } }) },
		{ 0.4, merge(p.Slam, { RootOffset = { 0, -0.6, -0.5 } }) },
	}
	-- The whirlwind: Root turns steadily (Linear keys every quarter turn) from 0.42 to 0.86, so a
	-- full turn spans one tick (0.125 of the clip); he edges forward through it.
	local spinFrom, spinTo, quarters = 0.42, 0.86, 16
	for q = 0, quarters do
		local t = spinFrom + (spinTo - spinFrom) * q / quarters
		local turn = (q * 90) % 360
		local pose = with(p.SweepThrough, wide, {
			Root = { 0, if turn > 180 then turn - 360 else turn, 0 }, -- kept within +-180 (same facing)
			Waist = { -10, 40, 0 }, Neck = { 4, -30, 0 },
			RootOffset = { 0, -0.45, -0.5 - 0.6 * q / quarters },
		})
		table.insert(frenzyKeys, { t, pose, q > 0 })
	end
	table.insert(frenzyKeys, { 0.9, with(p.SweepThrough, wide, { Waist = { -8, 95, 0 }, Neck = { 6, -60, 0 }, RootOffset = { 0, -0.4, -1.1 } }) })
	table.insert(frenzyKeys, { 0.95, with(p.High, wide, { Waist = { 18, 0, 0 }, Neck = { -32, 0, 0 }, RootOffset = { 0, -0.2, -1.1 } }) }) -- the roar
	table.insert(frenzyKeys, { 1, carry })

	Overrides.hero_rook = {
		Idle = breathe(carry, 2.8),
		Move = rookWalk(),
		AttackBasic = forehand,
		AttackSpecial = lastStand,
		AttackSkill = signature(2.4, frenzyKeys, { Charge = 0.1, Release = 0.36 }),
	}
	Alternates.hero_rook = { AttackBasic = backhand }
end

HeroClips.ByWeapon = ByWeapon
HeroClips.Shared = Shared
HeroClips.Overrides = Overrides
HeroClips.Alternates = Alternates

-- The alternate clip for a state, under the same weapon rule as overrides, or nil.
function HeroClips.Alternate(heroId: string?, weaponType: string?, state: string): Clip?
	local set = heroId and Alternates[heroId]
	if set and set[state] and OVERRIDE_WEAPON[heroId :: string] == weaponType then
		return set[state]
	end
	return nil
end
HeroClips.OverrideWeapon = OVERRIDE_WEAPON

-- Resolves a state for a hero and weapon type, or nil when no clip exists. A hero override
-- only applies while the hero holds its signature weapon.
function HeroClips.Get(heroId: string?, weaponType: string?, state: string): Clip?
	if state == "SkillWindup" then
		return HeroClips.Windup(heroId, weaponType)
	end
	local override = heroId and Overrides[heroId]
	if override and override[state] and OVERRIDE_WEAPON[heroId :: string] == weaponType then
		return override[state]
	end
	local set = ByWeapon[weaponType or "UNARMED"] or ByWeapon.UNARMED
	return set[state] or Shared[state] or ByWeapon.UNARMED[state]
end

-- The Skill wind-up, the opening WINDUP_SECONDS of every Skill (GDD §4.4): the hero sinks into a
-- crouch with its upper body in its own Skill's anticipation pose (the last key before the clip's
-- Release), then pulses there, gathering power, and the Skill's own clip follows. The server adds
-- this time to every Skill's cast (HeroActionTiming.WithSkillWindup), so the strike still lines up.
-- Built from each hero's clips, so every hero and weapon has one and every grip is one already
-- authored. Only the upper body is borrowed: legs, root rotation and root drift come from the
-- idle stance, so a Skill that leaps or spins still winds up standing and facing ahead.
HeroClips.WINDUP_STATE = "SkillWindup"
HeroClips.WINDUP_SECONDS = 0.8
local WINDUP_CROUCH, WINDUP_SURGE = 20, 27 -- knee bend (deg), split over hip and ankle as `walk` does
local WINDUP_TWIST = 75 -- the borrowed waist turn is capped at this, either way
local windups: { [string]: Clip } = {}

local function anticipation(skill: Clip): Pose
	local release = HeroClips.Marker(skill, "Release", 0.5)
	local chosen = skill.Keys[1].Pose
	for _, key in skill.Keys do
		if key.T > 0 and key.T < release - 0.01 then
			chosen = key.Pose
		end
	end
	return chosen
end

local function windupPose(stance: Pose, upper: Pose, crouch: number, pulse: number): Pose
	local pose: Pose = {}
	for joint, value in stance do
		if joint ~= "Root" and joint ~= "RootOffset" and not HeroClips.UPPER_BODY[joint] then
			pose[joint] = value
		end
	end
	for joint in HeroClips.UPPER_BODY do
		local value = upper[joint]
		if value then pose[joint] = value end
	end
	local waist = pose.Waist or { 0, 0, 0 }
	pose.Waist = { waist[1] + 3 * pulse, math.clamp(waist[2], -WINDUP_TWIST, WINDUP_TWIST), waist[3] }
	nudge(pose, "Neck", { -3 * pulse, 0, 0 })
	for _, side in { "Left", "Right" } do
		nudge(pose, side .. "Hip", { crouch * 0.6, 0, 0 })
		nudge(pose, side .. "Knee", { -crouch, 0, 0 })
		nudge(pose, side .. "Ankle", { crouch * 0.4, 0, 0 })
	end
	local root = stance.RootOffset or { 0, 0, 0 }
	pose.RootOffset = { root[1], root[2] - crouch * 0.008, root[3] }
	return pose
end

function HeroClips.Windup(heroId: string?, weaponType: string?): Clip?
	local cacheKey = `{heroId or "-"}|{weaponType or "UNARMED"}`
	local cached = windups[cacheKey]
	if cached then return cached end
	local skill = HeroClips.Get(heroId, weaponType, "AttackSkill")
	local idle = HeroClips.Get(heroId, weaponType, "Idle")
	if not skill or not idle or #skill.Keys == 0 or #idle.Keys == 0 then return nil end
	local stance = idle.Keys[1].Pose
	local upper = anticipation(skill)
	local gather = windupPose(stance, upper, WINDUP_CROUCH, 0)
	local surge = windupPose(stance, upper, WINDUP_SURGE, 1)
	-- Sink in over the first 0.2 s, then pulse, quickening as the charge builds, and rise out of it
	-- in the last few frames as the Skill's own clip takes over.
	local keys: { { any } } = { { 0, stance }, { 0.25, gather } }
	local t, step, high = 0.25, 0.13, true
	while t + step < 0.9 do
		t += step
		table.insert(keys, { t, if high then surge else gather })
		high = not high
		step *= 0.92
	end
	table.insert(keys, { 0.95, surge })
	table.insert(keys, { 1, stance })
	local result = clip(HeroClips.WINDUP_SECONDS, false, keys)
	windups[cacheKey] = result
	return result
end

-- A clip's marker as a fraction of its length, or the fallback when the clip has none.
function HeroClips.Marker(clip: Clip?, name: string, fallback: number): number
	local markers = clip and clip.Markers
	local value = markers and markers[name]
	return if value then value else fallback
end

-- A bow attack's draw: when the hand takes the string (set), reaches full draw (full) and lets go
-- (release), as clip fractions. Clips without a Draw table take the string at DRAW_DEFAULT.Set
-- and reach full draw at DRAW_DEFAULT.Full of the way to their Release.
HeroClips.DRAW_DEFAULT = table.freeze({ Set = 0.3, Full = 0.85 })
function HeroClips.DrawTiming(clip: Clip): (number, number, number)
	local release = HeroClips.Marker(clip, "Release", 0.7)
	local draw = clip.Draw
	local set = if draw then draw.Set else release * HeroClips.DRAW_DEFAULT.Set
	local full = if draw then draw.Full else release * HeroClips.DRAW_DEFAULT.Full
	set = math.clamp(set, 0.01, release)
	full = math.clamp(full, set, release)
	return set, full, release
end

-- Names of the clip's markers with from < fraction <= to, in clip order. HeroAnimator calls this
-- each frame with the action's previous and current fraction.
function HeroClips.MarkersBetween(clip: Clip, from: number, to: number): { string }
	local due: { string } = {}
	local markers = clip.Markers
	if not markers then
		return due
	end
	for name, fraction in markers do
		if fraction > from and fraction <= to then
			table.insert(due, name)
		end
	end
	table.sort(due, function(a, b)
		return markers[a] < markers[b]
	end)
	return due
end

return table.freeze(HeroClips)
