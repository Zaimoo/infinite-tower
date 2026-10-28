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

-- 7. Costumes (Phase 3) ---------------------------------------------------------
do
	local HeroCostumes = require(ReplicatedStorage.Assets.HeroRig.HeroCostumes)
	local HeroCatalog = require(ReplicatedStorage.Shared.Config.HeroCatalog)

	check(#HeroCostumes.List == 12, "12 hero costumes")
	for heroId in HeroCatalog.Seeds do
		check(HeroCostumes.ById[heroId] ~= nil, `costume exists for {heroId}`)
	end
	for _, c in HeroCostumes.List do
		check(HeroCatalog.Seeds[c.HeroId] ~= nil, `{c.HeroId} is a catalog hero`)
		local problems = HeroCostumes.Lint(c)
		check(#problems == 0, `{c.HeroId} costume lints clean:\n  ` .. table.concat(problems, "\n  "))
		local colors = HeroCostumes.BodyColors(c)
		for _, partName in HeroRigSpec.PART_NAMES do
			if partName ~= "HumanoidRootPart" then
				check(colors[partName] ~= nil, `{c.HeroId} colours {partName}`)
			end
		end
	end

	-- The lint catches the original Jenna problem (a cuff that wraps the hand) and
	-- accepts the same piece once it is marked Loose. The probe carries no other pieces, so a
	-- costume at the part budget cannot add a budget problem to the count.
	local base = HeroCostumes.ById.hero_han
	local function variant(extra: { [string]: any }): any
		local pieces = {}
		local cuff: any = { Name = "BadCuff", Bone = "LeftLowerArm", Size = { 1.05, 0.6, 1.05 }, Position = { 0, -0.6, 0 }, Color = { 1, 1, 1 } }
		for k, v in extra do
			cuff[k] = v
		end
		table.insert(pieces, cuff)
		return { HeroId = "lint_probe", BodyType = "Standard", Colors = base.Colors, Pieces = pieces }
	end
	local flagged = HeroCostumes.Lint(variant({}))
	check(#flagged == 1 and string.find(flagged[1], "LeftHand", 1, true) ~= nil, "lint flags a cuff overlapping the hand")
	check(#HeroCostumes.Lint(variant({ Loose = true })) == 0, "lint accepts the cuff when marked Loose")
	check(#HeroCostumes.Lint(variant({ RelativeTo = "Missing" })) == 1, "lint reports a bad RelativeTo")

	-- Mesh pieces: only allow-listed meshes, with the texture they ship with.
	local listedMesh, listedTexture = next(HeroCostumes.MESHES)
	check(listedMesh ~= nil, "at least one mesh is allow-listed")
	local function meshProbe(mesh: any): any
		return variant({ Loose = true, Mesh = mesh })
	end
	check(#HeroCostumes.Lint(meshProbe({ MeshId = listedMesh, TextureId = listedTexture, Scale = { 1, 1, 1 } })) == 0, "lint accepts a listed mesh")
	check(#HeroCostumes.Lint(meshProbe({ MeshId = "rbxassetid://1", Scale = { 1, 1, 1 } })) == 1, "lint rejects an unlisted mesh")
	check(#HeroCostumes.Lint(meshProbe({ MeshId = listedMesh, TextureId = "rbxassetid://1", Scale = { 1, 1, 1 } })) == 1, "lint rejects a swapped texture")
	local hanHair = false
	for _, p in HeroCostumes.ById.hero_han.Pieces do
		if p.Mesh and HeroCostumes.MESHES[p.Mesh.MeshId] then
			hanHair = true
		end
	end
	check(hanHair, "Han wears the allow-listed anime hair mesh")

	-- Head pieces are authored for HEAD_AUTHORED_SIZE and scale uniformly with the real head.
	local HeroCostumeMath = require(ReplicatedStorage.Assets.HeroRig.HeroCostumeMath)
	local hanLayout = HeroRigSpec.Layout(HeroCostumes.ById.hero_han.BodyType)
	local k = hanLayout.Parts.Head.Size[2] / HeroRigSpec.HEAD_AUTHORED_SIZE
	for _, entry in HeroCostumeMath.Resolve(HeroCostumes.ById.hero_han.Pieces, hanLayout) do
		local p = entry.Piece
		if p.Mesh then
			check(entry.MeshScale ~= nil and near(entry.MeshScale[2], p.Mesh.Scale[2] * k), `{p.Name} mesh scales with the head`)
			check(near(entry.Position[2], p.Position[2] * k) and near(entry.Size[1], p.Size[1] * k), `{p.Name} placement scales with the head`)
		end
	end
	check(HeroCostumes.ById.hero_han.Face ~= HeroCostumes.DEFAULT_FACE, "Han has an anime face, not the default")
end

-- 8. Clips (Phase 4) --------------------------------------------------------------
do
	local HeroClips = require(ReplicatedStorage.Assets.HeroRig.HeroClips)
	local HeroCostumes = require(ReplicatedStorage.Assets.HeroRig.HeroCostumes)
	local ArtifactCatalog = require(ReplicatedStorage.Shared.Config.ArtifactCatalog)

	local jointNames: { [string]: boolean } = { RootOffset = true }
	for _, joint in HeroRigSpec.JOINTS do
		jointNames[joint.Name] = true
	end

	local function samePose(a: { [string]: { number } }, b: { [string]: { number } }): boolean
		for joint, value in a do
			local other = b[joint]
			if not other or not sameVec(value, other) then return false end
		end
		for joint in b do
			if not a[joint] then return false end
		end
		return true
	end

	local function checkClip(label: string, clip: any, looped: boolean)
		check(type(clip) == "table" and clip.Duration > 0, label .. " has a positive duration")
		check(clip.Looped == looped, label .. (if looped then " loops" else " plays once"))
		local keys = clip.Keys
		check(#keys >= 2, label .. " has at least two keys")
		check(keys[1].T == 0 and keys[#keys].T == 1, label .. " keys span 0..1")
		for i = 2, #keys do
			check(keys[i].T > keys[i - 1].T, `{label} key {i} time increases`)
		end
		for i, key in keys do
			for joint, value in key.Pose do
				check(jointNames[joint] == true, `{label} key {i} joint {joint} is a rig joint`)
				check(#value == 3, `{label} key {i} {joint} has three components`)
				if joint ~= "RootOffset" then
					for _, component in value do
						check(math.abs(component) <= 180, `{label} key {i} {joint} rotation within 180 deg`)
					end
				end
				if string.find(joint, "Knee") then
					check(value[1] <= 5, `{label} key {i} {joint} only bends backward`)
				end
				if string.find(joint, "Elbow") then
					check(value[1] >= -5, `{label} key {i} {joint} does not hyperextend`)
				end
			end
		end
		-- Loops are seamless and actions return to where they started.
		check(samePose(keys[1].Pose, keys[#keys].Pose), label .. " ends on its starting pose")
	end

	for _, weaponType in HeroClips.WEAPON_TYPES do
		local set = HeroClips.ByWeapon[weaponType]
		check(set ~= nil, `clips exist for {weaponType}`)
		for _, state in HeroClips.WEAPON_STATES do
			check(set[state] ~= nil, `{weaponType} has {state}`)
			checkClip(`{weaponType}.{state}`, set[state], state == "Idle" or state == "Move")
		end
	end
	for _, state in HeroClips.SHARED_STATES do
		check(HeroClips.Shared[state] ~= nil, `shared {state} exists`)
		checkClip(`Shared.{state}`, HeroClips.Shared[state], HeroClips.LOCOMOTION_STATES[state] == true)
	end
	for _, weaponType in ArtifactCatalog.ArchetypeWeaponType do
		check(HeroClips.ByWeapon[weaponType] ~= nil, `catalog weapon type {weaponType} has clips`)
	end
	for heroId, states in HeroClips.Overrides do
		check(HeroCostumes.ById[heroId] ~= nil, `override {heroId} is a hero`)
		for state, clip in states do
			check(table.find(HeroClips.WEAPON_STATES, state) ~= nil or table.find(HeroClips.SHARED_STATES, state) ~= nil, `override {heroId}.{state} is a known state`)
			checkClip(`Overrides.{heroId}.{state}`, clip, HeroClips.LOCOMOTION_STATES[state] == true)
		end
	end

	-- Lookup order: hero override -> weapon type -> shared -> unarmed.
	check(HeroClips.Get("hero_jenna", "BOW", "Idle") == HeroClips.Overrides.hero_jenna.Idle, "hero override wins")
	check(HeroClips.Get("hero_astrea", "BOW", "Idle") == HeroClips.ByWeapon.BOW.Idle, "weapon clip for heroes without an override")
	check(HeroClips.Get(nil, "BOW", "Hit") == HeroClips.Shared.Hit, "shared state fallback")
	check(HeroClips.Get(nil, "NOT_A_WEAPON", "AttackBasic") == HeroClips.ByWeapon.UNARMED.AttackBasic, "unknown weapon falls back to UNARMED")
	check(HeroClips.Get(nil, nil, "Idle") == HeroClips.ByWeapon.UNARMED.Idle, "no weapon uses UNARMED")

	-- Signature attacks (projectile-skill-vfx-plan.md, Phase 4): every hero has its own ultimate,
	-- each attack override carries a Release marker, and overrides only apply with the hero's weapon.
	for heroId in HeroCostumes.ById do
		local weapon = HeroClips.OverrideWeapon[heroId]
		check(weapon ~= nil and HeroClips.ByWeapon[weapon] ~= nil, `{heroId} has a signature weapon`)
		local skill = HeroClips.Overrides[heroId] and HeroClips.Overrides[heroId].AttackSkill
		check(skill ~= nil, `{heroId} has a signature AttackSkill`)
		check(HeroClips.Get(heroId, weapon, "AttackSkill") == skill, `{heroId} resolves its signature AttackSkill`)
		check(HeroClips.Get(heroId, "UNARMED", "AttackSkill") == HeroClips.ByWeapon.UNARMED.AttackSkill, `{heroId} unarmed falls back to UNARMED`)
	end
	for heroId, states in HeroClips.Overrides do
		for state, clip in states do
			if string.sub(state, 1, 6) == "Attack" then
				local release = HeroClips.Marker(clip, "Release", -1)
				check(release > 0 and release < 1, `Overrides.{heroId}.{state} has a Release marker`)
				if HeroClips.OverrideWeapon[heroId] == "BOW" then
					check(HeroClips.Marker(clip, "Nock", -1) > release, `Overrides.{heroId}.{state} re-nocks after release`)
				end
			end
		end
	end
	check(HeroClips.Get("hero_velkist", "DAGGERS", "AttackSpecial") == HeroClips.Overrides.hero_velkist.AttackSpecial, "Velkist's Shadow Rend override")
	check(HeroClips.Get("hero_catio", "AXE", "AttackSpecial") == HeroClips.Overrides.hero_catio.AttackSpecial, "Catio's Resonance Tremor override")
	check(HeroClips.Get("hero_han", "DAGGERS", "AttackSpecial") == HeroClips.ByWeapon.DAGGERS.AttackSpecial, "other specials use the weapon clip")
end

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

	-- Every catalog artifact resolves to a known prefab of its own weapon type (Phase 5).
	local knownPrefabs: { [string]: boolean } = {}
	for _, prefab in HeroSockets.PREFABS do
		knownPrefabs[prefab] = true
	end
	for artifactId, seed in ArtifactCatalog.Seeds do
		local prefab, weaponType = HeroSockets.ResolvePrefab(artifactId, nil, ArtifactCatalog.Seeds)
		check(weaponType == seed.Type, `{artifactId} resolves to its own type {seed.Type}`)
		check(prefab ~= nil and knownPrefabs[prefab] == true, `{artifactId} resolves to a built prefab ({tostring(prefab)})`)
	end
	check(select(1, HeroSockets.ResolvePrefab(nil, "BOW", ArtifactCatalog.Seeds)) == "weapon_bow", "type-only resolves to the type prefab")
	check(select(2, HeroSockets.ResolvePrefab("", "", ArtifactCatalog.Seeds)) == nil, "empty ids resolve to nothing")
	check(select(2, HeroSockets.ResolvePrefab(nil, "RING", ArtifactCatalog.Seeds)) == nil, "unknown weapon types resolve to nothing")

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
