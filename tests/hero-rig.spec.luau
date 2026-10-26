--!strict
-- tests/hero-rig.spec.luau
-- Offline checks for HeroRigSpec (hero-rig-rebuild-plan.md, Phase 1): skeleton structure,
-- ground contract, symmetry, required sockets, and the joint axis convention.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HeroRigSpec = require(ReplicatedStorage.Assets.HeroRig.HeroRigSpec)

local EPS = 1e-6
local passed = 0

local function check(condition: boolean, message: string)
	if not condition then
		error("[FAIL] " .. message, 2)
	end
	passed += 1
end

local function near(a: number, b: number): boolean
	return math.abs(a - b) <= EPS
end

local function sameVec(a: { number }, b: { number }): boolean
	return near(a[1], b[1]) and near(a[2], b[2]) and near(a[3], b[3])
end

-- Point inside (or on the surface of) a part's box, root space, rest pose.
local function insideBox(point: { number }, part: { Size: { number }, Center: { number } }): boolean
	for i = 1, 3 do
		if math.abs(point[i] - part.Center[i]) > part.Size[i] / 2 + EPS then
			return false
		end
	end
	return true
end

-- Rotation by CFrame.Angles(rx, ry, rz) = Rx * Ry * Rz, applied to a vector.
local function rotate(vec: { number }, degrees: { number }): { number }
	local rx, ry, rz = math.rad(degrees[1]), math.rad(degrees[2]), math.rad(degrees[3])
	local x, y, z = vec[1], vec[2], vec[3]
	-- Rz
	x, y = x * math.cos(rz) - y * math.sin(rz), x * math.sin(rz) + y * math.cos(rz)
	-- Ry
	x, z = x * math.cos(ry) + z * math.sin(ry), -x * math.sin(ry) + z * math.cos(ry)
	-- Rx
	y, z = y * math.cos(rx) - z * math.sin(rx), y * math.sin(rx) + z * math.cos(rx)
	return { x, y, z }
end

local bodyTypes = { "Slim", "Standard", "Heavy" }
local layouts = {}
for _, bodyType in bodyTypes do
	layouts[bodyType] = HeroRigSpec.Layout(bodyType :: any)
end

-- 1. Skeleton structure -------------------------------------------------------
do
	check(#HeroRigSpec.PART_NAMES == 16, "16 rig parts")
	check(#HeroRigSpec.JOINTS == 15, "15 joints")
	local partIndex: { [string]: number } = {}
	for i, name in HeroRigSpec.PART_NAMES do
		partIndex[name] = i
	end
	local parentCount: { [string]: number } = {}
	local seen: { [string]: boolean } = { HumanoidRootPart = true }
	for _, joint in HeroRigSpec.JOINTS do
		check(partIndex[joint.Part0] ~= nil and partIndex[joint.Part1] ~= nil, joint.Name .. " connects known parts")
		check(seen[joint.Part0] == true, joint.Name .. " Part0 is already in the tree (build order)")
		seen[joint.Part1] = true
		parentCount[joint.Part1] = (parentCount[joint.Part1] or 0) + 1
	end
	for _, name in HeroRigSpec.PART_NAMES do
		if name ~= "HumanoidRootPart" then
			check(parentCount[name] == 1, name .. " is driven by exactly one joint")
		end
	end
end

-- 2. Ground contract, height and joint placement per body type ----------------
for _, bodyType in bodyTypes do
	local layout = layouts[bodyType]
	check(layout.BodyType == bodyType, bodyType .. " layout reports its body type")

	local lowest = math.huge
	for _, part in layout.Parts do
		lowest = math.min(lowest, part.Center[2] - part.Size[2] / 2)
	end
	check(near(lowest, -HeroRigSpec.GROUND_OFFSET), bodyType .. " soles sit GROUND_OFFSET below the root")
	check(near(layout.Height, layouts.Standard.Height), bodyType .. " height matches Standard")

	for _, joint in layout.Joints do
		-- The pivot lies on Part1. Shoulders pivot on the arm's own axis beside the torso,
		-- so Part0 only has to be within half of Part1's width of the pivot.
		local part0 = layout.Parts[joint.Part0]
		local part1 = layout.Parts[joint.Part1]
		local reach = math.max(part1.Size[1], part1.Size[3]) / 2
		local inflated = { Size = { part0.Size[1] + 2 * reach, part0.Size[2], part0.Size[3] + 2 * reach }, Center = part0.Center }
		check(insideBox(joint.Position, part1), `{bodyType} {joint.Name} pivot lies on {joint.Part1}`)
		check(insideBox(joint.Position, inflated), `{bodyType} {joint.Name} pivot is adjacent to {joint.Part0}`)
	end

	-- Rig attachments are pure translations that land on the joint pivot.
	local byPart: { [string]: { [string]: any } } = {}
	for _, attachment in layout.Attachments do
		byPart[attachment.Part] = byPart[attachment.Part] or {}
		check(byPart[attachment.Part][attachment.Name] == nil, `{bodyType} attachment {attachment.Part}.{attachment.Name} is unique`)
		byPart[attachment.Part][attachment.Name] = attachment
	end
	for _, joint in layout.Joints do
		local name = joint.Name .. "RigAttachment"
		for _, partName in { joint.Part0, joint.Part1 } do
			local attachment = byPart[partName] and byPart[partName][name]
			check(attachment ~= nil, `{bodyType} {partName}.{name} exists`)
			local center = layout.Parts[partName].Center
			local world = { center[1] + attachment.Position[1], center[2] + attachment.Position[2], center[3] + attachment.Position[3] }
			check(sameVec(world, joint.Position), `{bodyType} {partName}.{name} sits on the joint pivot`)
			check(sameVec(attachment.Rotation, { 0, 0, 0 }), `{bodyType} {partName}.{name} has no rotation`)
		end
	end

	-- Required equipment and costume sockets.
	local required = {
		{ "RightHand", "RightGripAttachment" },
		{ "LeftHand", "LeftGripAttachment" },
		{ "RightHand", "DrawAttachment" },
		{ "LeftLowerArm", "ShieldMountAttachment" },
		{ "UpperTorso", "BackSheathAttachment" },
		{ "LowerTorso", "HipSheathAttachment" },
		{ "Head", "HatAttachment" },
		{ "Head", "HairAttachment" },
		{ "Head", "FaceFrontAttachment" },
		{ "UpperTorso", "CarryAttachment" },
	}
	for _, pair in required do
		check(byPart[pair[1]] ~= nil and byPart[pair[1]][pair[2]] ~= nil, `{bodyType} has {pair[1]}.{pair[2]}`)
	end
	for _, hand in { "RightHand", "LeftHand" } do
		local grip = byPart[hand][hand == "RightHand" and "RightGripAttachment" or "LeftGripAttachment"]
		check(sameVec(grip.Rotation, HeroRigSpec.GRIP_ROTATION), `{bodyType} {hand} grip uses GRIP_ROTATION`)
		check(insideBox({
			layout.Parts[hand].Center[1] + grip.Position[1],
			layout.Parts[hand].Center[2] + grip.Position[2],
			layout.Parts[hand].Center[3] + grip.Position[3],
		}, layout.Parts[hand]), `{bodyType} {hand} grip sits inside the fist`)
	end

	-- Left/right symmetry.
	for name, part in layout.Parts do
		local mirrorName = if string.sub(name, 1, 4) == "Left" then "Right" .. string.sub(name, 5) else nil
		if mirrorName then
			local mirror = layout.Parts[mirrorName]
			check(mirror ~= nil, `{bodyType} {name} has mirror {mirrorName}`)
			check(sameVec(part.Size, mirror.Size), `{bodyType} {name} size mirrors {mirrorName}`)
			check(sameVec({ -part.Center[1], part.Center[2], part.Center[3] }, mirror.Center), `{bodyType} {name} center mirrors {mirrorName}`)
		end
	end

	-- Limbs do not intersect the torso or each other in the rest pose.
	local torso = layout.Parts.UpperTorso
	local arm = layout.Parts.LeftUpperArm
	check(math.abs(arm.Center[1]) - arm.Size[1] / 2 >= torso.Size[1] / 2 - EPS, `{bodyType} arms clear the torso`)
	local leg = layout.Parts.LeftUpperLeg
	check(math.abs(leg.Center[1]) - leg.Size[1] / 2 >= -EPS, `{bodyType} legs do not overlap each other`)
end

-- 3. Hands are identical across body types ------------------------------------
for _, bodyType in bodyTypes do
	for _, hand in { "LeftHand", "RightHand" } do
		check(sameVec(layouts[bodyType].Parts[hand].Size, HeroRigSpec.HAND_SIZE), `{bodyType} {hand} uses HAND_SIZE`)
	end
end

-- 4. Axis convention ------------------------------------------------------------
-- Rotating a joint swings everything below it about the pivot; the checked part's
-- center must move in the documented direction.
for _, bodyType in bodyTypes do
	local layout = layouts[bodyType]
	local pivots: { [string]: { number } } = {}
	for _, joint in layout.Joints do
		pivots[joint.Name] = joint.Position
	end
	for _, axis in HeroRigSpec.AxisChecks do
		local pivot = pivots[axis.Joint]
		local center = layout.Parts[axis.Part].Center
		local offset = { center[1] - pivot[1], center[2] - pivot[2], center[3] - pivot[3] }
		local moved = rotate(offset, axis.Rotation)
		local d = { moved[1] - offset[1], moved[2] - offset[2], moved[3] - offset[3] }
		local length = math.sqrt(d[1] ^ 2 + d[2] ^ 2 + d[3] ^ 2)
		check(length > 0.05, `{bodyType} {axis.Joint} rotation moves {axis.Part}`)
		local dot = (d[1] * axis.Direction[1] + d[2] * axis.Direction[2] + d[3] * axis.Direction[3]) / length
		check(dot > 0.7, `{bodyType} {axis.Joint} {axis.Rotation[1]},{axis.Rotation[2]},{axis.Rotation[3]} moves {axis.Part} as documented (dot {string.format("%.2f", dot)})`)
	end
end

-- 5. Unknown body types are rejected ------------------------------------------
check(not pcall(HeroRigSpec.Layout, "Giant" :: any), "unknown body type errors")

-- 6. Weapon sockets (Phase 2) ---------------------------------------------------
-- Every catalog weapon type has a prefab and sockets, and every socket lands on an
-- attachment the rig spec actually builds, on every body type.
do
	local HeroSockets = require(ReplicatedStorage.Assets.HeroRig.HeroSockets)
	local ArtifactCatalog = require(ReplicatedStorage.Shared.Config.ArtifactCatalog)

	local catalogTypes: { [string]: boolean } = {}
	for _, weaponType in ArtifactCatalog.ArchetypeWeaponType do
		catalogTypes[weaponType] = true
	end
	for weaponType in catalogTypes do
		check(HeroSockets.SOCKETS[weaponType] ~= nil, `sockets defined for {weaponType}`)
		check(HeroSockets.PREFABS[weaponType] ~= nil, `prefab mapped for {weaponType}`)
	end

	for _, bodyType in bodyTypes do
		local byPart: { [string]: { [string]: boolean } } = {}
		for _, attachment in layouts[bodyType].Attachments do
			byPart[attachment.Part] = byPart[attachment.Part] or {}
			byPart[attachment.Part][attachment.Name] = true
		end
		for weaponType, sockets in HeroSockets.SOCKETS do
			check(#sockets >= 1, `{weaponType} has at least one socket`)
			local usedRigAttachments: { [string]: boolean } = {}
			for _, socket in sockets do
				check(byPart[socket.RigPart] ~= nil and byPart[socket.RigPart][socket.RigAttachment] == true, `{bodyType} {weaponType} socket {socket.RigPart}.{socket.RigAttachment} exists on the rig`)
				local key = socket.RigPart .. "." .. socket.RigAttachment
				check(not usedRigAttachments[key], `{weaponType} uses {key} once`)
				usedRigAttachments[key] = true
			end
		end
	end
end

print(`Hero rig spec tests: {passed} passed, 0 failed`)
