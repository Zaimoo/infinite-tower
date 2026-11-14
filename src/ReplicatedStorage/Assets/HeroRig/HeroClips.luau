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
export type Clip = {
	Duration: number, -- seconds at speed 1 (attacks are rescaled to the attack interval)
	Looped: boolean,
	Keys: { Key },
	Markers: { [string]: number }?, -- event name -> fraction of the clip (see RELEASE_MARKERS)
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
})
HeroClips.LOCOMOTION_STATES = table.freeze({
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
	nudge(pose, "Waist", { if s == 0 then 0 else -1.5, 7 * s, 2 * s })
	nudge(pose, "Neck", { 0, -5 * s, -1.5 * s })
	nudge(pose, "RightShoulder", { 4 * s, 0, 0 })
	nudge(pose, "LeftShoulder", { -4 * s, 0, 0 })
end

-- Walk cycle: legs swing, the root bobs, and the upper body moves with the stride over its
-- carry pose (strideUpperBody). With armSwing, free arms swing that far instead.
local function walk(carry: Pose, armSwing: number?): Clip
	local swing = armSwing or 0
	local function step(phase: number): Pose
		local s = if phase == 0 then 1 elseif phase == 1 then -1 else 0
		local p = merge(carry, {
			LeftHip = { 28 * s, 0, 0 }, RightHip = { -28 * s, 0, 0 },
			LeftKnee = { if s < 0 then -35 else -8, 0, 0 }, RightKnee = { if s > 0 then -35 else -8, 0, 0 },
			LeftAnkle = { if s < 0 then 12 else 0, 0, 0 }, RightAnkle = { if s > 0 then 12 else 0, 0, 0 },
			RootOffset = { 0, if s == 0 then 0.08 else -0.04, 0 },
		})
		strideUpperBody(p, s)
		if swing ~= 0 then
			p.LeftShoulder = { -swing * s, 0, 0 }
			p.RightShoulder = { swing * s, 0, 0 }
		end
		return p
	end
	return clip(0.7, true, { { 0, step(0) }, { 0.25, step(0.5) }, { 0.5, step(1) }, { 0.75, step(0.5) }, { 1, step(0) } })
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
	ByWeapon.UNARMED = {
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
	-- Low ready carry: stave canted ~30 deg forward, arrow pointing forward and down.
	local carry = merge(STANCE, {
		Waist = { -2, -8, 0 }, Neck = { 0, 8, 0 },
		LeftShoulder = { 10, 0, -10 }, LeftElbow = { 50, 0, 0 },
		RightShoulder = { 14, 10, -14 }, RightElbow = { 45, 0, 0 },
	})
	-- Arm straight forward: stave vertical, arrow at the target. Draw hand back at the cheek.
	-- The archer's body turn lives in the waist; a shoulder yaw after the 90 deg pitch would
	-- roll the bow off vertical.
	local aim = merge(ATTACK_STANCE, {
		Waist = { -2, -10, 0 }, Neck = { 0, 10, 0 },
		LeftShoulder = { 90, 0, 0 }, LeftElbow = { 0, 0, 0 },
		RightShoulder = { 90, 22, 0 }, RightElbow = { 30, 0, 0 },
	})
	local drawn = merge(aim, { RightShoulder = { 88, 28, -10 }, RightElbow = { 145, 0, 0 } })
	local release = merge(aim, { LeftShoulder = { 96, 0, 0 }, RightShoulder = { 70, 40, -30 }, RightElbow = { 120, 0, 0 } })
	local crouch: Pose = { LeftHip = { 40, 0, -8 }, RightHip = { -10, 0, 8 }, LeftKnee = { -55, 0, 0 }, RightKnee = { -70, 0, 0 }, LeftAnkle = { 15, 0, 0 }, RightAnkle = { 60, 0, 0 }, RootOffset = { 0, -0.55, 0 } }
	local skyAim = merge(aim, { Waist = { 18, -10, 0 }, Neck = { 15, 10, 0 }, LeftShoulder = { 140, 0, 0 }, RightShoulder = { 138, 14, 0 } })
	WeaponPoses.BOW = { Carry = carry, Aim = aim, Drawn = drawn, Release = release, Crouch = crouch, SkyAim = skyAim }
	ByWeapon.BOW = {
		Idle = breathe(carry),
		Move = walk(carry),
		AttackBasic = clip(0.8, false, { { 0, carry }, { 0.3, aim }, { 0.62, drawn }, { 0.72, release }, { 1, carry } }),
		AttackSpecial = clip(0.95, false, {
			{ 0, carry },
			{ 0.3, merge(aim, crouch) },
			{ 0.66, merge(merge(drawn, crouch), { Waist = { -10, -18, 0 } }) },
			{ 0.78, merge(merge(release, crouch), { Waist = { 8, -18, 0 } }) },
			{ 1, carry },
		}),
		AttackSkill = clip(1.1, false, {
			{ 0, carry },
			{ 0.35, skyAim },
			{ 0.6, merge(skyAim, { RightShoulder = { 136, 26, -10 }, RightElbow = { 145, 0, 0 } }) },
			{ 0.72, merge(skyAim, { LeftShoulder = { 148, 0, 0 }, RightShoulder = { 115, 40, -30 }, RightElbow = { 120, 0, 0 } }) },
			{ 1, carry },
		}),
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
	ByWeapon.SWORD_SHIELD = {
		Idle = breathe(guard),
		Move = walk(guard),
		AttackBasic = clip(0.75, false, { { 0, guard }, { 0.4, high }, { 0.62, cut }, { 1, guard } }),
		AttackSpecial = clip(0.85, false, {
			{ 0, guard },
			{ 0.35, merge(guard, { Waist = { 4, 25, 0 }, LeftShoulder = { 40, -40, -10 }, LeftElbow = { 100, 0, 0 } }) },
			{ 0.6, bash },
			{ 1, guard },
		}),
		AttackSkill = clip(1.1, false, {
			{ 0, guard },
			{ 0.35, merge(high, { Waist = { 12, 0, 0 }, RightShoulder = { 175, 0, 5 }, RootOffset = { 0, 0.15, 0 } }) },
			{ 0.62, merge(cut, { Waist = { -30, 0, 0 }, RightShoulder = { 40, 0, 0 }, RootOffset = { 0, -0.45, 0 }, LeftKnee = { -50, 0, 0 }, RightKnee = { -45, 0, 0 }, LeftHip = { 40, 0, -6 }, RightHip = { 10, 0, 6 } }) },
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
	ByWeapon.DAGGERS = {
		Idle = breathe(ready, 2.6),
		Move = walk(ready),
		AttackBasic = clip(0.55, false, {
			{ 0, crouched },
			{ 0.3, merge(crouched, { Waist = { -6, -18, 0 }, RightShoulder = { 85, 0, -5 }, RightElbow = { 10, 0, 0 }, RightWrist = { -80, 0, 0 } }) },
			{ 0.55, crouched },
			{ 0.75, merge(crouched, { Waist = { -6, 18, 0 }, LeftShoulder = { 85, 0, 5 }, LeftElbow = { 10, 0, 0 }, LeftWrist = { -80, 0, 0 } }) },
			{ 1, crouched },
		}),
		AttackSpecial = clip(0.7, false, {
			{ 0, crouched },
			{ 0.35, merge(crouched, { LeftShoulder = { 140, 0, -40 }, RightShoulder = { 140, 0, 40 }, LeftElbow = { 20, 0, 0 }, RightElbow = { 20, 0, 0 } }) },
			{ 0.6, merge(crouched, { Waist = { -12, 0, 0 }, LeftShoulder = { 60, 0, 30 }, RightShoulder = { 60, 0, -30 }, LeftElbow = { 10, 0, 0 }, RightElbow = { 10, 0, 0 } }) },
			{ 1, crouched },
		}),
		AttackSkill = clip(1.0, false, {
			{ 0, crouched },
			{ 0.2, merge(crouched, { Waist = { -8, -35, 0 }, RightShoulder = { 90, 20, 0 }, RightElbow = { 10, 0, 0 } }) },
			{ 0.4, merge(crouched, { Waist = { -8, 35, 0 }, LeftShoulder = { 90, -20, 0 }, LeftElbow = { 10, 0, 0 } }) },
			{ 0.6, merge(crouched, { Waist = { -8, -35, 0 }, RightShoulder = { 90, 20, 0 }, RightElbow = { 10, 0, 0 } }) },
			{ 0.8, merge(crouched, { Waist = { -15, 0, 0 }, LeftShoulder = { 100, 0, 20 }, RightShoulder = { 100, 0, -20 }, LeftElbow = { 5, 0, 0 }, RightElbow = { 5, 0, 0 }, RootOffset = { 0, -0.3, 0 } }) },
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
	ByWeapon.AXE = {
		Idle = breathe(rest),
		Move = walk(rest),
		-- Overhand chop: haul it back over the shoulder, then the whole torso drives it down.
		AttackBasic = clip(0.85, false, { { 0, rest }, { 0.45, windup }, { 0.65, chop }, { 0.8, chop }, { 1, rest } }),
		-- Level sweep: drawn back on the right, swung flat through the front.
		AttackSpecial = clip(0.9, false, { { 0, rest }, { 0.4, sweepBack }, { 0.68, sweepThrough }, { 0.82, sweepThrough }, { 1, rest } }),
		-- Both hands overhead, then buried in the floor.
		AttackSkill = clip(1.15, false, { { 0, rest }, { 0.4, high }, { 0.62, slam }, { 0.84, slam }, { 1, rest } }),
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
	ByWeapon.STAFF = {
		Idle = breathe(stand),
		Move = walk(stand),
		AttackBasic = clip(0.8, false, { { 0, stand }, { 0.45, cast }, { 0.62, merge(cast, { RightShoulder = { 96, 0, 0 } }) }, { 1, stand } }),
		AttackSpecial = clip(0.9, false, { { 0, stand }, { 0.45, raised }, { 0.65, merge(cast, { Waist = { -12, 0, 0 } }) }, { 1, stand } }),
		AttackSkill = clip(1.2, false, {
			{ 0, stand },
			{ 0.4, merge(raised, { LeftShoulder = { 165, 0, -10 }, RootOffset = { 0, 0.1, 0 } }) },
			{ 0.7, merge(raised, { Waist = { 16, 0, 0 }, RightShoulder = { 175, 0, 0 }, LeftShoulder = { 175, 0, 0 } }) },
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
	ByWeapon.TOME = {
		Idle = floatIdle(read, 3.2),
		Move = walk(read),
		AttackBasic = clip(0.8, false, {
			{ 0, read },
			{ 0.28, gather },
			{ 0.55, release },
			{ 0.72, followThrough },
			{ 1, read },
		}),
		AttackSpecial = clip(0.95, false, {
			{ 0, read },
			{ 0.32, merge(gather, { LeftShoulder = { 42, -6, -10 }, RightShoulder = { 65, 24, 38 }, RightElbow = { 95, 0, 0 }, Waist = { 4, 22, 0 } }) },
			{ 0.65, merge(release, { RightShoulder = { 102, -8, 0 }, RightElbow = { 6, 0, 0 }, Waist = { -8, -18, 0 }, RootOffset = { 0, -0.06, -0.04 } }) },
			{ 0.82, followThrough },
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
local BOW_NOCK = 0.9
for weaponType, releases in RELEASE_MARKERS do
	for state, release in releases do
		local attack = ByWeapon[weaponType][state]
		attack.Markers = if weaponType == "BOW" then { Release = release, Nock = BOW_NOCK } else { Release = release }
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

local function signature(duration: number, keys: { { any } }, markers: { [string]: number }): Clip
	local result = clip(duration, false, keys)
	result.Markers = markers
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
		}, { Release = 0.72, Nock = 0.92 }),
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
		LeftHip = { 8, -6, -2 }, LeftKnee = { -14, 0, 0 }, LeftAnkle = { 6, 0, 2 },
		RightHip = { -4, 0, 5 }, RightKnee = { -4, 0, 0 }, RightAnkle = { 8, 0, -5 },
		RootOffset = { 0, -0.04, 0 },
	}
	local poised: Pose = merge(legs, {
		Waist = { 0, -12, 2 }, Neck = { -3, 14, -3 },
		LeftShoulder = { 42, 0, -14 }, LeftElbow = { 14, 0, 0 }, LeftWrist = { 0, 0, -18 },
		RightShoulder = { 30, 30, 0 }, RightElbow = { 100, 0, 0 },
	})

	-- Astral Arrow
	local aim = merge(merge(p.Aim, legs), { Waist = { -2, -16, 0 }, Neck = { 0, 16, 0 } })
	local drawn = merge(merge(p.Drawn, legs), { Waist = { -4, -18, 0 }, Neck = { 0, 18, 0 } })
	local flourish = merge(merge(p.Release, legs), { Waist = { 2, -14, 0 }, Neck = { 0, 14, 0 }, RightShoulder = { 68, 48, -40 }, RightElbow = { 110, 0, 0 } })
	local settle = merge(flourish, { LeftShoulder = { 80, 0, -6 }, RightShoulder = { 40, 40, -50 }, RightElbow = { 60, 0, 0 } })

	-- Nebula Piercer
	local wide: Pose = {
		LeftHip = { 30, -10, -10 }, LeftKnee = { -30, 0, 0 }, LeftAnkle = { 4, 0, 10 },
		RightHip = { -22, 10, 12 }, RightKnee = { -12, 0, 0 }, RightAnkle = { 30, 0, -12 },
		RootOffset = { 0, -0.22, 0 },
	}
	local sideOn = merge(merge(p.Aim, wide), { Waist = { -6, -28, 0 }, Neck = { 2, 26, 0 } })
	local fullDraw = merge(merge(p.Drawn, wide), { Waist = { -10, -32, 0 }, Neck = { 4, 30, 0 }, RightShoulder = { 86, 30, -14 }, RightElbow = { 150, 0, 0 } })
	-- The held charge: deeper, further back, with a tremor between the keys.
	local gather = merge(fullDraw, { Waist = { -12, -34, 0 }, LeftShoulder = { 92, 0, 0 }, RightElbow = { 152, 0, 0 }, RootOffset = { 0, -0.3, 0 } })
	local tremble = merge(gather, { Waist = { -10, -32, 2 }, Neck = { 6, 31, 0 }, LeftShoulder = { 89, 0, 2 }, RightShoulder = { 87, 32, -15 } })
	local peak = merge(gather, { Waist = { -15, -37, 0 }, Neck = { 4, 34, 0 }, LeftShoulder = { 93, 0, -1 }, RightShoulder = { 84, 35, -18 }, RightElbow = { 156, 0, 0 }, RootOffset = { 0, -0.35, 0 } })
	local strain = merge(peak, { Waist = { -13, -36, -2 }, LeftShoulder = { 90, 0, 1 } })
	local recoil = merge(merge(p.Release, wide), {
		Waist = { 6, -22, 0 }, Neck = { 0, 22, 0 },
		LeftShoulder = { 100, 0, 0 }, RightShoulder = { 60, 50, -50 }, RightElbow = { 100, 0, 0 },
		RootOffset = { 0, -0.18, 0.25 },
	})
	local kick = merge(recoil, { Waist = { 11, -18, 0 }, Neck = { -4, 20, 0 }, LeftShoulder = { 114, 0, 0 }, RightShoulder = { 46, 54, -62 }, RightElbow = { 70, 0, 0 }, RootOffset = { 0, -0.14, 0.4 } })
	local recover = merge(recoil, { LeftShoulder = { 70, 0, -8 }, RightShoulder = { 30, 30, -30 }, RightElbow = { 60, 0, 0 }, RootOffset = { 0, -0.12, 0.15 } })

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
	local land = merge(p.SkyAim, {
		Waist = { 14, -10, 0 }, Neck = { 14, 10, 0 },
		LeftHip = { 26, -8, -10 }, LeftKnee = { -30, 0, 0 }, LeftAnkle = { 4, 0, 8 },
		RightHip = { -18, 8, 10 }, RightKnee = { -14, 0, 0 }, RightAnkle = { 24, 0, -8 },
		RootOffset = { 0, -0.22, 0 },
	})
	local skyDraw = merge(land, { Waist = { 22, -10, 0 }, Neck = { 22, 10, 0 }, RightShoulder = { 140, 20, -10 }, RightElbow = { 150, 0, 0 }, RootOffset = { 0, -0.12, 0 } })
	local skyHold = merge(skyDraw, { Waist = { 26, -12, 0 }, LeftShoulder = { 144, 0, 0 }, RightElbow = { 154, 0, 0 }, RootOffset = { 0, -0.08, 0 } })
	local loose = merge(skyHold, { Waist = { 28, -8, 0 }, LeftShoulder = { 156, 0, 0 }, RightShoulder = { 110, 45, -60 }, RightElbow = { 60, 0, 0 }, RootOffset = { 0, 0.06, 0 } })
	local watch = merge(loose, { Waist = { 20, -8, 0 }, Neck = { 26, 8, 0 }, LeftShoulder = { 150, 0, -6 }, RightShoulder = { 70, 30, -70 }, RightElbow = { 30, 0, 0 }, RootOffset = { 0, 0, 0 } })
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
		}, { Release = 0.68, Nock = 0.92 }),
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
		}, { Charge = 0.22, Release = 0.74, Nock = 0.94 }),
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
		}, { Charge = 0.07, Release = 0.56, Nock = 0.95 }),
	}
end

-- Aeli (BOW): idle is a poised ranger's stance: an upright waist, narrow feet with her weight on
-- the left leg and the right knee turned slightly in, the bow held out to her left at chest
-- height (shoulder + elbow pitch near 90 keeps the stave upright), the right hand forward at
-- the string as if calling the wind to the arrow, chin a little down. Canopy's Wrath drops her
-- to one knee with the bow raised to the sky; she draws, looses the seed-arrow straight up,
-- holds a wide follow-through and rises. Basic and Special use the bow clips.
do
	local p = WeaponPoses.BOW
	local kneel: Pose = { LeftHip = { 70, 0, -6 }, RightHip = { -20, 0, 6 }, LeftKnee = { -80, 0, 0 }, RightKnee = { -95, 0, 0 }, LeftAnkle = { 10, 0, 0 }, RightAnkle = { 70, 0, 0 }, RootOffset = { 0, -0.75, 0 } }
	local skyKneel = merge(merge(p.SkyAim, kneel), { Waist = { 20, -10, 0 }, Neck = { 18, 10, 0 } })
	local ranger: Pose = {
		Waist = { 0, -8, 2 }, Neck = { -4, 10, -2 },
		LeftShoulder = { 72, 0, -22 }, LeftElbow = { 14, 0, 0 },
		RightShoulder = { 55, 18, 0 }, RightElbow = { 68, 0, 0 },
		LeftHip = { 2, 0, -3 }, LeftKnee = { -4, 0, 0 }, LeftAnkle = { 2, 0, 3 },
		RightHip = { 8, -8, 2 }, RightKnee = { -14, 0, 0 }, RightAnkle = { 6, 0, -2 },
		RootOffset = { 0, -0.04, 0 },
	}
	Overrides.hero_aeli = {
		Idle = breathe(ranger, 3.6),
		AttackSkill = signature(1.1, {
			{ 0, p.Carry },
			{ 0.28, skyKneel },
			{ 0.56, merge(skyKneel, { RightShoulder = { 138, 18, -10 }, RightElbow = { 148, 0, 0 } }) },
			{ 0.7, merge(skyKneel, { LeftShoulder = { 150, 0, 0 }, RightShoulder = { 105, 45, -55 }, RightElbow = { 60, 0, 0 } }) },
			{ 0.86, merge(merge(p.Release, p.Crouch), { Waist = { 8, -10, 0 }, LeftShoulder = { 128, 0, -18 } }) },
			{ 1, p.Carry },
		}, { Release = 0.7, Nock = 0.92 }),
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

-- Han (DAGGERS).
-- Nightfall Fangs (Special): he sinks into a crouch, leaps, and comes down on the target with both
-- daggers reversed, points down. A blade points straight down when its arm's shoulder, elbow and
-- wrist pitch add up to 270 degrees minus the waist's pitch (measured in Studio: a forward lean of
-- -34 needs 304), so the wrists turn as the arms fall and the points stay down from the top of the
-- jump to the landing. A wrist past 180 is written as its negative equivalent (216 is -144).
-- Abyssal Wake (Skill): he coils with both blades chambered at his left hip, dashes through the
-- target with a wide cut, skids to a stop with his back to it while the wake of slashes he left
-- behind keeps cutting (the kit's five waves), then springs back to his place.
do
	local p = WeaponPoses.DAGGERS
	-- Special
	local sink = merge(p.Crouched, {
		Waist = { -16, 0, 0 }, Neck = { 12, 0, 0 },
		LeftShoulder = { -40, 0, -14 }, RightShoulder = { -40, 0, 14 }, LeftElbow = { 35, 0, 0 }, RightElbow = { 35, 0, 0 },
		LeftWrist = { 20, 0, 0 }, RightWrist = { 20, 0, 0 },
		LeftHip = { 48, 0, -8 }, RightHip = { 30, 0, 8 }, LeftKnee = { -75, 0, 0 }, RightKnee = { -80, 0, 0 },
		LeftAnkle = { 26, 0, 0 }, RightAnkle = { 48, 0, 0 }, RootOffset = { 0, -0.6, 0.1 },
	})
	local apex = merge(p.Crouched, {
		Waist = { 14, 0, 0 }, Neck = { -16, 0, 0 },
		LeftShoulder = { 166, 0, -10 }, RightShoulder = { 166, 0, 10 }, LeftElbow = { 26, 0, 0 }, RightElbow = { 26, 0, 0 },
		LeftWrist = { 64, 0, 0 }, RightWrist = { 64, 0, 0 },
		LeftHip = { 62, 0, -6 }, RightHip = { 18, 0, 6 }, LeftKnee = { -85, 0, 0 }, RightKnee = { -100, 0, 0 },
		LeftAnkle = { 20, 0, 0 }, RightAnkle = { 30, 0, 0 }, RootOffset = { 0, 1.9, -0.5 },
	})
	local falling = merge(apex, {
		Waist = { -10, 0, 0 }, Neck = { -4, 0, 0 },
		LeftShoulder = { 118, 0, -4 }, RightShoulder = { 118, 0, 4 }, LeftWrist = { 136, 0, 0 }, RightWrist = { 136, 0, 0 },
		LeftHip = { 50, 0, -6 }, RightHip = { 0, 0, 6 }, LeftKnee = { -55, 0, 0 }, RightKnee = { -70, 0, 0 },
		RootOffset = { 0, 0.95, -0.95 },
	})
	local plunge = merge(p.Crouched, {
		Waist = { -34, 0, 0 }, Neck = { 20, 0, 0 },
		LeftShoulder = { 60, 0, 12 }, RightShoulder = { 60, 0, -12 }, LeftElbow = { 28, 0, 0 }, RightElbow = { 28, 0, 0 },
		LeftWrist = { -144, 0, 0 }, RightWrist = { -144, 0, 0 },
		LeftHip = { 66, 0, -8 }, RightHip = { -28, 0, 8 }, LeftKnee = { -70, 0, 0 }, RightKnee = { -55, 0, 0 },
		LeftAnkle = { 12, 0, 0 }, RightAnkle = { 42, 0, 0 }, RootOffset = { 0, -0.74, -1.25 },
	})
	-- Skill
	local chambered = merge(p.Crouched, {
		Waist = { -14, 52, 0 }, Neck = { 4, -40, 0 },
		RightShoulder = { 52, 0, -58 }, RightElbow = { 82, 0, 0 }, RightWrist = { -20, 0, 0 },
		LeftShoulder = { -32, 0, -18 }, LeftElbow = { 58, 0, 0 }, LeftWrist = { -40, 0, 0 },
		LeftHip = { 38, 0, -8 }, RightHip = { -30, 0, 10 }, LeftKnee = { -58, 0, 0 }, RightKnee = { -42, 0, 0 },
		LeftAnkle = { 14, 0, 0 }, RightAnkle = { 44, 0, 0 }, RootOffset = { 0, -0.4, 0.45 },
	})
	local dashing = merge(chambered, {
		Waist = { -40, 30, 0 }, Neck = { 30, -22, 0 },
		LeftHip = { 78, 0, -6 }, RightHip = { -52, 0, 8 }, LeftKnee = { -48, 0, 0 }, RightKnee = { -20, 0, 0 },
		LeftAnkle = { 0, 0, 0 }, RightAnkle = { 50, 0, 0 }, RootOffset = { 0, -0.95, -3.2 },
	})
	local cutThrough = merge(p.Crouched, {
		Waist = { -26, -58, 0 }, Neck = { 14, 40, 0 },
		RightShoulder = { 84, 0, 78 }, RightElbow = { 8, 0, 0 }, RightWrist = { -12, 0, 0 },
		LeftShoulder = { 58, 0, -72 }, LeftElbow = { 10, 0, 0 }, LeftWrist = { -12, 0, 0 },
		LeftHip = { -30, 0, -10 }, RightHip = { 64, 0, 8 }, LeftKnee = { -30, 0, 0 }, RightKnee = { -62, 0, 0 },
		LeftAnkle = { 40, 0, 0 }, RightAnkle = { 8, 0, 0 }, RootOffset = { 0, -0.72, -6.2 },
	})
	local skid = merge(cutThrough, {
		Waist = { -20, -72, 0 }, Neck = { 6, 58, 0 },
		RightShoulder = { 30, 0, 98 }, RightElbow = { 12, 0, 0 }, RightWrist = { -30, 0, 0 },
		LeftShoulder = { 16, 0, -50 }, LeftElbow = { 40, 0, 0 }, LeftWrist = { -50, 0, 0 },
		LeftHip = { -38, 0, -12 }, RightHip = { 72, 0, 10 }, LeftKnee = { -38, 0, 0 }, RightKnee = { -78, 0, 0 },
		RootOffset = { 0, -0.88, -6.9 },
	})
	local springBack = merge(p.Crouched, {
		Waist = { 6, -20, 0 }, Neck = { -4, 14, 0 },
		LeftHip = { 30, 0, -6 }, RightHip = { 20, 0, 6 }, LeftKnee = { -50, 0, 0 }, RightKnee = { -60, 0, 0 },
		RootOffset = { 0, 0.55, -3.0 },
	})
	Overrides.hero_han = {
		AttackSpecial = signature(0.85, {
			{ 0, p.Crouched },
			{ 0.17, sink },
			{ 0.42, apex },
			{ 0.53, falling },
			{ 0.62, plunge },
			{ 0.8, merge(plunge, { Waist = { -30, 0, 0 }, LeftWrist = { -148, 0, 0 }, RightWrist = { -148, 0, 0 }, RootOffset = { 0, -0.66, -1.15 } }) },
			{ 1, p.Crouched },
		}, { Release = 0.62 }),
		AttackSkill = signature(1.0, {
			{ 0, p.Crouched },
			{ 0.16, chambered },
			{ 0.3, dashing },
			{ 0.4, cutThrough },
			{ 0.56, skid },
			{ 0.8, merge(skid, { Waist = { -16, -76, 0 }, RootOffset = { 0, -0.84, -6.9 } }) },
			{ 0.92, springBack },
			{ 1, p.Crouched },
		}, { Release = 0.4 }),
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
-- Excavation winds the greataxe round once before a two-handed slam.
do
	local p = WeaponPoses.AXE
	Overrides.hero_catio = {
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
	Overrides.hero_gide = {
		Idle = breathe(veteran, 3.2),
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
	local snap: Pose = { LeftWrist = { 0, 35, 0 }, Waist = { -4, -18, 0 }, Neck = { -6, 8, 6 } }
	local flat: Pose = { LeftWrist = { 0, 80, 0 }, Waist = { -8, -32, 0 }, Neck = { 0, 22, 0 } }
	local rise = merge(p.Drawn, { Waist = { 10, -24, 0 }, Neck = { 8, 10, 0 }, LeftShoulder = { 110, 0, 0 },
		RightShoulder = { 108, 28, -10 }, RootOffset = { 0, 0.05, 0.25 } })
	Overrides.hero_isabelle = {
		Idle = breathe(poised, 3.4),
		Move = walk(poised), -- her stance's upper body (bow low, draw hand loose) over walking legs
		AttackBasic = signature(0.7, {
			{ 0, p.Carry },
			{ 0.25, merge(p.Aim, snap) },
			{ 0.5, merge(p.Drawn, snap) },
			{ 0.58, merge(p.Release, merge(snap, { Waist = { 0, -12, 0 }, RightShoulder = { 60, 50, -40 } })) },
			{ 1, p.Carry },
		}, { Release = 0.58, Nock = 0.85 }),
		AttackSpecial = signature(0.95, {
			{ 0, p.Carry },
			{ 0.28, merge(p.Carry, { Waist = { 0, 40, 0 }, Neck = { 0, -10, 0 } }) }, -- turns away
			{ 0.5, merge(merge(p.Aim, p.Crouch), flat) }, -- pivots back low, bow flat
			{ 0.66, merge(merge(p.Drawn, p.Crouch), flat) },
			{ 0.74, merge(merge(p.Release, p.Crouch), merge(flat, { Waist = { 4, -20, 0 } })) },
			{ 1, p.Carry },
		}, { Release = 0.74, Nock = 0.9 }),
		AttackSkill = signature(1.5, {
			{ 0, p.Carry },
			{ 0.2, merge(p.Aim, { Waist = { 4, -20, 0 }, RootOffset = { 0, 0, 0.3 } }) }, -- a step back
			{ 0.4, rise },
			{ 0.62, merge(rise, { Waist = { 12, -26, 0 } }) }, -- the arrow glows while she holds the draw
			{ 0.68, merge(p.Release, { Waist = { 6, -10, 0 }, LeftShoulder = { 100, 0, 0 }, RightShoulder = { 95, 70, -60 },
				RightElbow = { 20, 0, 0 }, RootOffset = { 0, 0.3, 0 } }) }, -- release with a hop
			{ 0.82, merge(p.Release, { Waist = { 0, 10, 0 }, RightShoulder = { 40, 80, -70 }, RightElbow = { 10, 0, 0 }, RootOffset = { 0, 0.1, 0 } }) },
			{ 1, p.Carry },
		}, { Charge = 0.2, Release = 0.68, Nock = 0.9 }),
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
	local override = heroId and Overrides[heroId]
	if override and override[state] and OVERRIDE_WEAPON[heroId :: string] == weaponType then
		return override[state]
	end
	local set = ByWeapon[weaponType or "UNARMED"] or ByWeapon.UNARMED
	return set[state] or Shared[state] or ByWeapon.UNARMED[state]
end

-- A clip's marker as a fraction of its length, or the fallback when the clip has none.
function HeroClips.Marker(clip: Clip?, name: string, fallback: number): number
	local markers = clip and clip.Markers
	local value = markers and markers[name]
	return if value then value else fallback
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
