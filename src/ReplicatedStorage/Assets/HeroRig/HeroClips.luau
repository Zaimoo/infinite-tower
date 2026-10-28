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

-- AXE (right hand) --------------------------------------------------------------------------
do
	-- Haft resting up past the right shoulder.
	local rest = merge(STANCE, {
		RightShoulder = { 10, 0, 10 }, RightElbow = { 100, 0, 0 },
		LeftShoulder = { 6, 0, -6 }, LeftElbow = { 15, 0, 0 },
	})
	local windup = merge(ATTACK_STANCE, { Waist = { 8, 15, 0 }, RightShoulder = { 170, 0, 10 }, RightElbow = { 50, 0, 0 }, LeftShoulder = { 50, 0, -10 }, LeftElbow = { 60, 0, 0 } })
	local chop = merge(ATTACK_STANCE, { Waist = { -25, -10, 0 }, RightShoulder = { 45, 0, 0 }, RightElbow = { 5, 0, 0 }, LeftShoulder = { 30, 0, -10 }, LeftElbow = { 40, 0, 0 }, RootOffset = { 0, -0.25, 0 } })
	WeaponPoses.AXE = { Rest = rest, Windup = windup, Chop = chop }
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

-- TOME (left hand) --------------------------------------------------------------------------
do
	-- Book held open in front of the chest, right hand relaxed.
	local read = merge(STANCE, {
		Neck = { -10, 0, 0 },
		LeftShoulder = { 30, -15, -5 }, LeftElbow = { 70, 0, 0 },
		RightShoulder = { 8, 0, 8 }, RightElbow = { 20, 0, 0 },
	})
	local channel = merge(ATTACK_STANCE, { LeftShoulder = { 70, -10, -10 }, LeftElbow = { 40, 0, 0 }, RightShoulder = { 85, 0, 10 }, RightElbow = { 10, 0, 0 } })
	WeaponPoses.TOME = { Read = read, Channel = channel }
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
}

local function signature(duration: number, keys: { { any } }, markers: { [string]: number }): Clip
	local result = clip(duration, false, keys)
	result.Markers = markers
	return result
end

local Overrides: { [string]: { [string]: Clip } } = {}

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

-- Astrea (BOW): Constellation Judgment. She rises onto her toes, arches back and draws a long,
-- deliberate shot at the sky, then holds a wide follow-through.
do
	local p = WeaponPoses.BOW
	local regal = merge(p.SkyAim, { Waist = { 26, -6, 0 }, Neck = { 24, 6, 0 }, LeftHip = { 20, 0, -4 }, RightHip = { -12, 0, 4 }, LeftKnee = { -10, 0, 0 }, RightKnee = { -4, 0, 0 }, RootOffset = { 0, 0.18, 0 } })
	Overrides.hero_astrea = {
		AttackSkill = signature(1.1, {
			{ 0, p.Carry },
			{ 0.3, regal },
			{ 0.58, merge(regal, { RightShoulder = { 140, 20, -10 }, RightElbow = { 150, 0, 0 } }) },
			{ 0.7, merge(regal, { LeftShoulder = { 152, 0, 0 }, RightShoulder = { 105, 45, -60 }, RightElbow = { 60, 0, 0 } }) },
			{ 0.85, merge(regal, { LeftShoulder = { 130, 0, -20 }, RightShoulder = { 95, 40, -75 }, RightElbow = { 20, 0, 0 }, Waist = { 14, -6, 0 } }) },
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
-- arms flexed wide.
do
	local p = WeaponPoses.SWORD_SHIELD
	local roar = merge(ATTACK_STANCE, { Waist = { -16, 0, 0 }, Neck = { 10, 0, 0 }, LeftShoulder = { 70, 0, -60 }, LeftElbow = { 95, 0, 0 }, RightShoulder = { 70, 0, 60 }, RightElbow = { 95, 0, 0 }, RootOffset = { 0, -0.35, 0 } })
	Overrides.hero_ignis = {
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
-- from one knee.
do
	local p = WeaponPoses.SWORD_SHIELD
	local kneel = merge(p.Cut, { Waist = { -34, 0, 0 }, RightShoulder = { 45, 0, 5 }, RightElbow = { 10, 0, 0 }, LeftHip = { 70, 0, -8 }, LeftKnee = { -90, 0, 0 }, RightHip = { -10, 0, 8 }, RightKnee = { -100, 0, 0 }, LeftAnkle = { 20, 0, 0 }, RightAnkle = { 60, 0, 0 }, RootOffset = { 0, -0.85, 0 } })
	Overrides.hero_morrigan = {
		AttackSkill = signature(1.1, {
			{ 0, p.Guard },
			{ 0.35, merge(p.High, { Waist = { 14, 0, 0 }, RightShoulder = { 178, 0, 0 }, RightElbow = { 5, 0, 0 }, RootOffset = { 0, 0.15, 0 } }) },
			{ 0.6, kneel },
			{ 0.85, kneel },
			{ 1, p.Guard },
		}, { Release = 0.6 }),
	}
end

-- Han (DAGGERS): Relentless Blade Flurry. Four alternating cuts that build into a final double
-- slash.
do
	local p = WeaponPoses.DAGGERS
	local function cut(side: number, lean: number): Pose
		if side > 0 then
			return merge(p.Crouched, { Waist = { lean, -40, 0 }, RightShoulder = { 95, 0, -20 }, RightElbow = { 5, 0, 0 }, RightWrist = { -70, 0, 0 } })
		end
		return merge(p.Crouched, { Waist = { lean, 40, 0 }, LeftShoulder = { 95, 0, 20 }, LeftElbow = { 5, 0, 0 }, LeftWrist = { -70, 0, 0 } })
	end
	Overrides.hero_han = {
		AttackSkill = signature(1.0, {
			{ 0, p.Crouched },
			{ 0.15, cut(1, -6) },
			{ 0.3, cut(-1, -8) },
			{ 0.45, cut(1, -10) },
			{ 0.6, cut(-1, -12) },
			{ 0.8, merge(p.Crouched, { Waist = { -18, 0, 0 }, LeftShoulder = { 110, 0, 35 }, RightShoulder = { 110, 0, -35 }, LeftElbow = { 5, 0, 0 }, RightElbow = { 5, 0, 0 }, RootOffset = { 0, -0.35, -0.3 } }) },
			{ 1, p.Crouched },
		}, { Release = 0.8 }),
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
-- and down to rip the rift open.
do
	local p = WeaponPoses.DAGGERS
	local tear = merge(p.Crouched, { Waist = { -20, 0, 0 }, LeftShoulder = { 80, 0, -90 }, RightShoulder = { 80, 0, 90 }, LeftElbow = { 10, 0, 0 }, RightElbow = { 10, 0, 0 }, RootOffset = { 0, -0.4, 0 } })
	Overrides.hero_archon = {
		AttackSkill = signature(1.0, {
			{ 0, p.Crouched },
			{ 0.35, merge(STANCE, { Waist = { 12, 0, 0 }, Neck = { 15, 0, 0 }, LeftShoulder = { 170, 0, 20 }, RightShoulder = { 170, 0, -20 }, LeftElbow = { 40, 0, 0 }, RightElbow = { 40, 0, 0 }, RootOffset = { 0, 0.3, 0 } }) },
			{ 0.62, tear },
			{ 0.85, merge(tear, { Waist = { -16, 0, 0 } }) },
			{ 1, p.Crouched },
		}, { Release = 0.62 }),
	}
end

-- Catio (AXE): Resonance Tremor is an overhead strike into the ground; Crystalline Excavation
-- spins the axe round once before a two-handed slam.
do
	local p = WeaponPoses.AXE
	local slam = merge(p.Chop, { Waist = { -40, 0, 0 }, RightShoulder = { 30, 0, 0 }, LeftShoulder = { 35, 0, 10 }, LeftElbow = { 10, 0, 0 }, LeftHip = { 50, 0, -8 }, RightHip = { 10, 0, 8 }, LeftKnee = { -65, 0, 0 }, RightKnee = { -60, 0, 0 }, RootOffset = { 0, -0.6, 0 } })
	Overrides.hero_catio = {
		AttackSpecial = signature(0.9, {
			{ 0, p.Rest },
			{ 0.4, p.Windup },
			{ 0.65, merge(p.Chop, { Waist = { -32, 0, 0 }, LeftKnee = { -45, 0, 0 }, RightKnee = { -40, 0, 0 }, RootOffset = { 0, -0.45, 0 } }) },
			{ 1, p.Rest },
		}, { Release = 0.65 }),
		AttackSkill = signature(1.15, {
			{ 0, p.Rest },
			{ 0.22, merge(ATTACK_STANCE, { Waist = { 0, 60, 0 }, RightShoulder = { 90, 60, 20 }, RightElbow = { 20, 0, 0 }, LeftShoulder = { 60, 30, -10 }, LeftElbow = { 40, 0, 0 } }) },
			{ 0.42, merge(p.Windup, { Waist = { 18, 0, 0 }, RightShoulder = { 178, 0, 0 }, LeftShoulder = { 170, 0, -5 }, LeftElbow = { 50, 0, 0 }, RootOffset = { 0, 0.25, 0 } }) },
			{ 0.62, slam },
			{ 0.82, merge(slam, { Waist = { -34, 0, 0 } }) },
			{ 1, p.Rest },
		}, { Release = 0.62 }),
	}
end

-- Eolka (STAFF): Crimson Hellfire Pillar. Staff raised high in both hands, then driven forward
-- and down in a lunge.
do
	local p = WeaponPoses.STAFF
	local drive = merge(p.Cast, { Waist = { -22, 0, 0 }, RightShoulder = { 60, 0, 0 }, LeftShoulder = { 55, 0, 10 }, LeftElbow = { 15, 0, 0 }, LeftHip = { 45, 0, -6 }, LeftKnee = { -50, 0, 0 }, RightHip = { -20, 0, 6 }, RightKnee = { -25, 0, 0 }, RootOffset = { 0, -0.4, -0.25 } })
	Overrides.hero_eolka = {
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
-- then thrown forward to bring the star down.
do
	local p = WeaponPoses.STAFF
	Overrides.hero_solaris = {
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

-- Valeria (TOME): Sanctuary Miracle. Tome and hand lifted in blessing, then both arms opened
-- wide as the circle forms.
do
	local p = WeaponPoses.TOME
	local open = merge(ATTACK_STANCE, { Waist = { 10, 0, 0 }, Neck = { 12, 0, 0 }, LeftShoulder = { 110, 0, -70 }, LeftElbow = { 15, 0, 0 }, RightShoulder = { 110, 0, 70 }, RightElbow = { 15, 0, 0 } })
	Overrides.hero_valeria = {
		AttackSkill = signature(1.2, {
			{ 0, p.Read },
			{ 0.35, merge(p.Channel, { Neck = { 20, 0, 0 }, LeftShoulder = { 150, 0, -10 }, LeftElbow = { 20, 0, 0 }, RightShoulder = { 150, 0, 10 }, RightElbow = { 10, 0, 0 } }) },
			{ 0.65, open },
			{ 0.85, open },
			{ 1, p.Read },
		}, { Release = 0.65 }),
	}
end

HeroClips.ByWeapon = ByWeapon
HeroClips.Shared = Shared
HeroClips.Overrides = Overrides
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
