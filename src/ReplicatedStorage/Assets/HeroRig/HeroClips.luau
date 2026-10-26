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
export type Key = { T: number, Pose: Pose }
export type Clip = {
	Duration: number, -- seconds at speed 1 (attacks are rescaled to the attack interval)
	Looped: boolean,
	Keys: { Key },
	Markers: { [string]: number }?, -- event name -> fraction of the clip (see RELEASE_MARKERS)
}

local HeroClips = {}

HeroClips.WEAPON_TYPES = table.freeze({ "UNARMED", "BOW", "SWORD_SHIELD", "DAGGERS", "AXE", "STAFF", "TOME" })
HeroClips.WEAPON_STATES = table.freeze({ "Idle", "Move", "AttackBasic", "AttackSpecial", "AttackSkill" })
HeroClips.SHARED_STATES = table.freeze({ "Hit", "Coma", "Carry", "Sleep", "Labor" })
HeroClips.LOCOMOTION_STATES = table.freeze({ Idle = true, Move = true, Coma = true, Carry = true, Sleep = true, Labor = true })

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
		table.insert(list, { T = k[1], Pose = k[2] })
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

-- Walk cycle: legs swing, the root bobs, the upper body keeps its carry pose.
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

-- AXE (right hand) --------------------------------------------------------------------------
do
	-- Haft resting up past the right shoulder.
	local rest = merge(STANCE, {
		RightShoulder = { 10, 0, 10 }, RightElbow = { 100, 0, 0 },
		LeftShoulder = { 6, 0, -6 }, LeftElbow = { 15, 0, 0 },
	})
	local windup = merge(ATTACK_STANCE, { Waist = { 8, 15, 0 }, RightShoulder = { 170, 0, 10 }, RightElbow = { 50, 0, 0 }, LeftShoulder = { 50, 0, -10 }, LeftElbow = { 60, 0, 0 } })
	local chop = merge(ATTACK_STANCE, { Waist = { -25, -10, 0 }, RightShoulder = { 45, 0, 0 }, RightElbow = { 5, 0, 0 }, LeftShoulder = { 30, 0, -10 }, LeftElbow = { 40, 0, 0 }, RootOffset = { 0, -0.25, 0 } })
	ByWeapon.AXE = {
		Idle = breathe(rest),
		Move = walk(rest),
		AttackBasic = clip(0.85, false, { { 0, rest }, { 0.45, windup }, { 0.65, chop }, { 1, rest } }),
		AttackSpecial = clip(0.9, false, {
			{ 0, rest },
			{ 0.4, merge(ATTACK_STANCE, { Waist = { 0, 45, 0 }, RightShoulder = { 90, 50, 20 }, RightElbow = { 30, 0, 0 } }) },
			{ 0.68, merge(ATTACK_STANCE, { Waist = { -6, -45, 0 }, RightShoulder = { 90, -40, 0 }, RightElbow = { 10, 0, 0 } }) },
			{ 1, rest },
		}),
		AttackSkill = clip(1.15, false, {
			{ 0, rest },
			{ 0.4, merge(windup, { Waist = { 15, 0, 0 }, RightShoulder = { 178, 0, 0 }, RootOffset = { 0, 0.2, 0 } }) },
			{ 0.62, merge(chop, { Waist = { -38, 0, 0 }, RightShoulder = { 30, 0, 0 }, RootOffset = { 0, -0.55, 0 }, LeftKnee = { -60, 0, 0 }, RightKnee = { -55, 0, 0 }, LeftHip = { 45, 0, -6 }, RightHip = { 10, 0, 6 } }) },
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

-- TOME (left hand) --------------------------------------------------------------------------
do
	-- Book held open in front of the chest, right hand relaxed.
	local read = merge(STANCE, {
		Neck = { -10, 0, 0 },
		LeftShoulder = { 30, -15, -5 }, LeftElbow = { 70, 0, 0 },
		RightShoulder = { 8, 0, 8 }, RightElbow = { 20, 0, 0 },
	})
	local channel = merge(ATTACK_STANCE, { LeftShoulder = { 70, -10, -10 }, LeftElbow = { 40, 0, 0 }, RightShoulder = { 85, 0, 10 }, RightElbow = { 10, 0, 0 } })
	ByWeapon.TOME = {
		Idle = breathe(read),
		Move = walk(read),
		AttackBasic = clip(0.8, false, { { 0, read }, { 0.45, channel }, { 0.65, merge(channel, { RightShoulder = { 92, 0, 10 }, Waist = { -6, 0, 0 } }) }, { 1, read } }),
		AttackSpecial = clip(0.9, false, {
			{ 0, read },
			{ 0.45, merge(channel, { RightShoulder = { 60, 0, 60 }, RightElbow = { 10, 0, 0 } }) },
			{ 0.7, merge(channel, { RightShoulder = { 100, 0, 0 }, Waist = { -8, 0, 0 } }) },
			{ 1, read },
		}),
		AttackSkill = clip(1.2, false, {
			{ 0, read },
			{ 0.4, merge(channel, { LeftShoulder = { 160, 0, -10 }, LeftElbow = { 10, 0, 0 }, Waist = { 12, 0, 0 }, Neck = { 15, 0, 0 } }) },
			{ 0.7, merge(channel, { LeftShoulder = { 165, 0, -10 }, RightShoulder = { 165, 0, 10 }, LeftElbow = { 10, 0, 0 }, Waist = { 15, 0, 0 } }) },
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
}

-- Attack markers -----------------------------------------------------------------------------
-- Release: the fraction of an attack clip where the blow lands (melee) or the projectile leaves
-- the weapon (ranged). HeroActionTiming reads it on the server to schedule the hit and on the
-- client to time the effect, so the two cannot drift. Nock: the bow arrow is back on the string.
-- A hero override's attack clip sets its own Markers.
local RELEASE_MARKERS: { [string]: { [string]: number } } = {
	UNARMED = { AttackBasic = 0.35, AttackSpecial = 0.55, AttackSkill = 0.6 },
	BOW = { AttackBasic = 0.72, AttackSpecial = 0.78, AttackSkill = 0.72 },
	SWORD_SHIELD = { AttackBasic = 0.62, AttackSpecial = 0.6, AttackSkill = 0.62 },
	DAGGERS = { AttackBasic = 0.3, AttackSpecial = 0.6, AttackSkill = 0.8 },
	AXE = { AttackBasic = 0.65, AttackSpecial = 0.68, AttackSkill = 0.62 },
	STAFF = { AttackBasic = 0.62, AttackSpecial = 0.65, AttackSkill = 0.7 },
	TOME = { AttackBasic = 0.65, AttackSpecial = 0.7, AttackSkill = 0.7 },
}
local BOW_NOCK = 0.9
for weaponType, releases in RELEASE_MARKERS do
	for state, release in releases do
		local attack = ByWeapon[weaponType][state]
		attack.Markers = if weaponType == "BOW" then { Release = release, Nock = BOW_NOCK } else { Release = release }
	end
end

-- Per-hero signature overrides --------------------------------------------------------------
local Overrides: { [string]: { [string]: Clip } } = {
	-- Jenna's Wind-Scout ready stance: contrapposto, front foot forward, bow in a low carry.
	hero_jenna = {
		Idle = breathe({
			Waist = { -3, -18, 0 }, Neck = { 0, 16, 0 },
			LeftShoulder = { 10, 0, -10 }, LeftElbow = { 50, 0, 0 },
			RightShoulder = { 14, 10, -18 }, RightElbow = { 48, 0, 0 },
			LeftHip = { 10, -4, -4 }, LeftKnee = { -16, 0, 0 }, LeftAnkle = { 6, 0, 0 },
			RightHip = { -8, 6, 5 }, RightKnee = { -12, 0, 0 }, RightAnkle = { 20, 0, 0 },
		}, 3.6),
	},
}

HeroClips.ByWeapon = ByWeapon
HeroClips.Shared = Shared
HeroClips.Overrides = Overrides

-- Resolves a state for a hero and weapon type, or nil when no clip exists.
function HeroClips.Get(heroId: string?, weaponType: string?, state: string): Clip?
	local override = heroId and Overrides[heroId]
	if override and override[state] then
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
