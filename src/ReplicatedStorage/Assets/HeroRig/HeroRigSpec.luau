--!strict
-- ReplicatedStorage/Assets/HeroRig/HeroRigSpec.luau
-- Single source of truth for the hero R15 skeleton (hero-rig-rebuild-plan.md, Phase 1).
-- Pure data and math: no Instances, Vector3 or CFrame, so it also loads in the offline
-- Luau test runner. HeroRigBuilder turns a layout into a Model.
--
-- Coordinates are in studs, relative to the HumanoidRootPart center in the rest pose,
-- facing -Z (Roblox forward). The soles of the feet sit GROUND_OFFSET below the root.
--
-- Axis convention for Motor6D.Transform rotations (joint-local, rest pose = identity):
--   Shoulder / hip  +X  swing the limb forward
--   Elbow           +X  bend the forearm forward (flex)
--   Knee            -X  bend the shin backward (flex)
--   Waist / neck    -X  lean forward / look down;  +Y  turn left
--   Left shoulder / hip  -Z  raise outward;  right shoulder / hip  +Z  raise outward
-- HeroRigSpec.AxisChecks encodes these so tests can verify them on a built rig.

export type Vec3 = { number }
export type BodyTypeName = "Slim" | "Standard" | "Heavy"

export type PartLayout = {
	Size: Vec3,
	Center: Vec3,
}

export type JointLayout = {
	Name: string,
	Part0: string,
	Part1: string,
	Position: Vec3, -- joint pivot, root space
}

export type AttachmentLayout = {
	Name: string,
	Part: string,
	Position: Vec3, -- part space
	Rotation: Vec3, -- degrees, applied as CFrame.Angles(rx, ry, rz)
}

export type Layout = {
	BodyType: BodyTypeName,
	Parts: { [string]: PartLayout },
	Joints: { JointLayout },
	Attachments: { AttachmentLayout },
	Height: number,
}

export type AxisCheck = {
	Joint: string,
	Rotation: Vec3, -- degrees
	Part: string, -- part whose center must move
	Direction: Vec3, -- expected unit direction of that movement, root space
}

local HeroRigSpec = {}

-- HumanoidRootPart center height above the soles. EntityRenderer and
-- ArtPackVisuals.Attach place hero roots at ground + 3.0.
HeroRigSpec.GROUND_OFFSET = 3.0

HeroRigSpec.PART_NAMES = table.freeze({
	"HumanoidRootPart",
	"LowerTorso",
	"UpperTorso",
	"Head",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
})

-- Build order: every Part0 is created before its Part1.
HeroRigSpec.JOINTS = table.freeze({
	table.freeze({ Name = "Root", Part0 = "HumanoidRootPart", Part1 = "LowerTorso" }),
	table.freeze({ Name = "Waist", Part0 = "LowerTorso", Part1 = "UpperTorso" }),
	table.freeze({ Name = "Neck", Part0 = "UpperTorso", Part1 = "Head" }),
	table.freeze({ Name = "LeftShoulder", Part0 = "UpperTorso", Part1 = "LeftUpperArm" }),
	table.freeze({ Name = "LeftElbow", Part0 = "LeftUpperArm", Part1 = "LeftLowerArm" }),
	table.freeze({ Name = "LeftWrist", Part0 = "LeftLowerArm", Part1 = "LeftHand" }),
	table.freeze({ Name = "RightShoulder", Part0 = "UpperTorso", Part1 = "RightUpperArm" }),
	table.freeze({ Name = "RightElbow", Part0 = "RightUpperArm", Part1 = "RightLowerArm" }),
	table.freeze({ Name = "RightWrist", Part0 = "RightLowerArm", Part1 = "RightHand" }),
	table.freeze({ Name = "LeftHip", Part0 = "LowerTorso", Part1 = "LeftUpperLeg" }),
	table.freeze({ Name = "LeftKnee", Part0 = "LeftUpperLeg", Part1 = "LeftLowerLeg" }),
	table.freeze({ Name = "LeftAnkle", Part0 = "LeftLowerLeg", Part1 = "LeftFoot" }),
	table.freeze({ Name = "RightHip", Part0 = "LowerTorso", Part1 = "RightUpperLeg" }),
	table.freeze({ Name = "RightKnee", Part0 = "RightUpperLeg", Part1 = "RightLowerLeg" }),
	table.freeze({ Name = "RightAnkle", Part0 = "RightLowerLeg", Part1 = "RightFoot" }),
})

-- Heights are shared by every body type so clips, weapon reach and the ground contract
-- stay identical; body types only change widths and depths.
local HEIGHTS = table.freeze({
	Foot = 0.3,
	LowerLeg = 1.2,
	UpperLeg = 1.2,
	LowerTorso = 0.4,
	UpperTorso = 1.6,
	Head = 1.4, -- slightly oversized (stylised) so the head reads against the bulky torsos
	UpperArm = 1.15,
	LowerArm = 1.05,
	Hand = 0.3,
	ShoulderDrop = 0.1, -- shoulder pivot sits this far below the top of UpperTorso
})

-- Head size that costume pieces on the Head (hair, hoods, hats, hair meshes) are authored
-- for. HeroCostumeMath scales those pieces uniformly by HEIGHTS.Head / HEAD_AUTHORED_SIZE,
-- so the head can be resized without re-authoring every costume.
HeroRigSpec.HEAD_AUTHORED_SIZE = 1.2

-- Hands are the same on every body type so every weapon grip fits every hero.
HeroRigSpec.HAND_SIZE = table.freeze({ 1.0, HEIGHTS.Hand, 1.0 })

type BodyDims = {
	TorsoWidth: number,
	TorsoDepth: number,
	LimbWidth: number, -- arm and leg X/Z
	HeadSize: number,
}

HeroRigSpec.BODY_TYPES = table.freeze({
	Slim = table.freeze({ TorsoWidth = 1.8, TorsoDepth = 0.9, LimbWidth = 0.85, HeadSize = HEIGHTS.Head }),
	Standard = table.freeze({ TorsoWidth = 2.0, TorsoDepth = 1.0, LimbWidth = 1.0, HeadSize = HEIGHTS.Head }),
	Heavy = table.freeze({ TorsoWidth = 2.3, TorsoDepth = 1.2, LimbWidth = 1.15, HeadSize = HEIGHTS.Head }),
} :: { [string]: BodyDims })

-- Weapon grips (plan section 3): the attachment's UpVector runs along the knuckle line
-- toward the thumb (hand -Z) and its LookVector points down the forearm line (hand -Y).
-- A weapon's own Grip attachment uses the same rule, so equipping is one Weld whose
-- C0/C1 are the two attachment CFrames.
HeroRigSpec.GRIP_ROTATION = table.freeze({ -90, 0, 0 })

-- Expected movement for each convention rule, checked by tests/studio-hero-rigs.luau.
HeroRigSpec.AxisChecks = table.freeze({
	{ Joint = "LeftShoulder", Rotation = { 60, 0, 0 }, Part = "LeftHand", Direction = { 0, 0, -1 } },
	{ Joint = "RightShoulder", Rotation = { 60, 0, 0 }, Part = "RightHand", Direction = { 0, 0, -1 } },
	{ Joint = "LeftHip", Rotation = { 45, 0, 0 }, Part = "LeftFoot", Direction = { 0, 0, -1 } },
	{ Joint = "RightHip", Rotation = { 45, 0, 0 }, Part = "RightFoot", Direction = { 0, 0, -1 } },
	{ Joint = "LeftElbow", Rotation = { 60, 0, 0 }, Part = "LeftHand", Direction = { 0, 0, -1 } },
	{ Joint = "RightElbow", Rotation = { 60, 0, 0 }, Part = "RightHand", Direction = { 0, 0, -1 } },
	{ Joint = "LeftKnee", Rotation = { -60, 0, 0 }, Part = "LeftFoot", Direction = { 0, 0, 1 } },
	{ Joint = "RightKnee", Rotation = { -60, 0, 0 }, Part = "RightFoot", Direction = { 0, 0, 1 } },
	{ Joint = "Waist", Rotation = { -30, 0, 0 }, Part = "Head", Direction = { 0, 0, -1 } },
	{ Joint = "Waist", Rotation = { 0, 30, 0 }, Part = "RightUpperArm", Direction = { 0, 0, -1 } },
	{ Joint = "LeftShoulder", Rotation = { 0, 0, -60 }, Part = "LeftHand", Direction = { -1, 0, 0 } },
	{ Joint = "RightShoulder", Rotation = { 0, 0, 60 }, Part = "RightHand", Direction = { 1, 0, 0 } },
	{ Joint = "LeftHip", Rotation = { 0, 0, -30 }, Part = "LeftFoot", Direction = { -1, 0, 0 } },
	{ Joint = "RightHip", Rotation = { 0, 0, 30 }, Part = "RightFoot", Direction = { 1, 0, 0 } },
} :: { AxisCheck })

local function v(x: number, y: number, z: number): Vec3
	return { x, y, z }
end

local function sub(a: Vec3, b: Vec3): Vec3
	return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
end

-- Rest-pose layout for a body type. Parts are stacked from the soles (y = -GROUND_OFFSET)
-- upward so every joint pivot sits on the boundary between its two parts.
function HeroRigSpec.Layout(bodyTypeName: BodyTypeName?): Layout
	local name: BodyTypeName = bodyTypeName or "Standard"
	local dims = HeroRigSpec.BODY_TYPES[name]
	assert(dims, `Unknown hero body type: {name}`)

	local H = HEIGHTS
	local sole = -HeroRigSpec.GROUND_OFFSET
	local ankleY = sole + H.Foot
	local kneeY = ankleY + H.LowerLeg
	local hipY = kneeY + H.UpperLeg
	local waistY = hipY + H.LowerTorso
	local neckY = waistY + H.UpperTorso
	local shoulderY = neckY - H.ShoulderDrop
	local elbowY = shoulderY - H.UpperArm
	local wristY = elbowY - H.LowerArm

	local tw, td, lw = dims.TorsoWidth, dims.TorsoDepth, dims.LimbWidth
	local hipX = lw / 2
	local armX = tw / 2 + lw / 2

	local parts: { [string]: PartLayout } = {}
	local function part(partName: string, size: Vec3, center: Vec3)
		parts[partName] = { Size = size, Center = center }
	end

	part("HumanoidRootPart", v(tw, 2, td), v(0, 0, 0))
	part("LowerTorso", v(tw, H.LowerTorso, td), v(0, hipY + H.LowerTorso / 2, 0))
	part("UpperTorso", v(tw, H.UpperTorso, td), v(0, waistY + H.UpperTorso / 2, 0))
	part("Head", v(dims.HeadSize, H.Head, dims.HeadSize), v(0, neckY + H.Head / 2, 0))
	for _, side in { { Prefix = "Left", Sign = -1 }, { Prefix = "Right", Sign = 1 } } do
		local prefix, sign = side.Prefix, side.Sign
		part(prefix .. "UpperArm", v(lw, H.UpperArm, lw), v(sign * armX, shoulderY - H.UpperArm / 2, 0))
		part(prefix .. "LowerArm", v(lw, H.LowerArm, lw), v(sign * armX, elbowY - H.LowerArm / 2, 0))
		part(prefix .. "Hand", table.clone(HeroRigSpec.HAND_SIZE), v(sign * armX, wristY - H.Hand / 2, 0))
		part(prefix .. "UpperLeg", v(lw, H.UpperLeg, lw), v(sign * hipX, hipY - H.UpperLeg / 2, 0))
		part(prefix .. "LowerLeg", v(lw, H.LowerLeg, lw), v(sign * hipX, kneeY - H.LowerLeg / 2, 0))
		part(prefix .. "Foot", v(lw, H.Foot, lw), v(sign * hipX, sole + H.Foot / 2, 0))
	end

	local jointPositions: { [string]: Vec3 } = {
		Root = v(0, hipY + H.LowerTorso / 2, 0), -- LowerTorso center
		Waist = v(0, waistY, 0),
		Neck = v(0, neckY, 0),
		LeftShoulder = v(-armX, shoulderY, 0),
		LeftElbow = v(-armX, elbowY, 0),
		LeftWrist = v(-armX, wristY, 0),
		RightShoulder = v(armX, shoulderY, 0),
		RightElbow = v(armX, elbowY, 0),
		RightWrist = v(armX, wristY, 0),
		LeftHip = v(-hipX, hipY, 0),
		LeftKnee = v(-hipX, kneeY, 0),
		LeftAnkle = v(-hipX, ankleY, 0),
		RightHip = v(hipX, hipY, 0),
		RightKnee = v(hipX, kneeY, 0),
		RightAnkle = v(hipX, ankleY, 0),
	}

	local joints: { JointLayout } = {}
	local attachments: { AttachmentLayout } = {}
	local function attach(attName: string, partName: string, position: Vec3, rotation: Vec3?)
		table.insert(attachments, { Name = attName, Part = partName, Position = position, Rotation = rotation or v(0, 0, 0) })
	end

	for _, j in HeroRigSpec.JOINTS do
		local pos = jointPositions[j.Name]
		table.insert(joints, { Name = j.Name, Part0 = j.Part0, Part1 = j.Part1, Position = pos })
		-- Rig attachments: pure translations, so Motor6D C0/C1 carry no rotation.
		attach(j.Name .. "RigAttachment", j.Part0, sub(pos, parts[j.Part0].Center))
		attach(j.Name .. "RigAttachment", j.Part1, sub(pos, parts[j.Part1].Center))
	end

	-- Equipment and costume sockets (plan section 1).
	local handDrop = -0.05 -- fist center, slightly toward the fingers
	attach("RightGripAttachment", "RightHand", v(0, handDrop, 0), table.clone(HeroRigSpec.GRIP_ROTATION))
	attach("LeftGripAttachment", "LeftHand", v(0, handDrop, 0), table.clone(HeroRigSpec.GRIP_ROTATION))
	attach("DrawAttachment", "RightHand", v(0, -H.Hand / 2, 0))
	-- Outer face of the left forearm; LookVector points outward (-X), UpVector up the arm.
	attach("ShieldMountAttachment", "LeftLowerArm", v(-lw / 2, 0, 0), v(0, 90, 0))
	attach("BackSheathAttachment", "UpperTorso", v(0, 0, td / 2 + 0.1), v(0, 0, -35))
	-- Left hip, pointing down (UpVector = -Y).
	attach("HipSheathAttachment", "LowerTorso", v(-tw / 2 - 0.05, 0, 0), v(180, 0, 0))
	attach("HatAttachment", "Head", v(0, H.Head / 2, 0))
	attach("HairAttachment", "Head", v(0, H.Head / 2, 0))
	attach("FaceFrontAttachment", "Head", v(0, 0, -dims.HeadSize / 2))
	attach("CarryAttachment", "UpperTorso", v(0, H.UpperTorso / 2 + H.Head + 0.6, 0))

	local top = neckY + H.Head
	return {
		BodyType = name,
		Parts = parts,
		Joints = joints,
		Attachments = attachments,
		Height = top - sole,
	}
end

return table.freeze(HeroRigSpec)
