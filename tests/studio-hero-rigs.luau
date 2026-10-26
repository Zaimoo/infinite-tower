-- Run in a Studio playtest (Server DataModel) after syncing src with Rojo. Through Studio
-- MCP, wrap this file's body and call it: `return (function() <file> end)()(true)`.
-- Builds every hero body type with HeroRigBuilder and checks the rig contract against the
-- live engine (hero-rig-rebuild-plan.md, Phase 1). Changes nothing outside
-- workspace.HeroRigPreviews, which is only kept when keepPreviews is true.
return function(keepPreviews: boolean?)
	local RunService = game:GetService("RunService")
	local HeroRig = game.ReplicatedStorage.Assets.HeroRig
	local Spec = require(HeroRig.HeroRigSpec)
	local Builder = require(HeroRig.HeroRigBuilder)

	local passed, failures = 0, {}
	local function check(condition: boolean, message: string)
		if condition then
			passed += 1
		else
			table.insert(failures, message)
		end
	end
	local function isIdentityRotation(cf: CFrame): boolean
		local _, angle = cf.Rotation:ToAxisAngle()
		return math.abs(angle) < 1e-4
	end
	local function settle()
		-- Motor6D.Transform is applied to part CFrames during the simulation step.
		RunService.Heartbeat:Wait()
		RunService.Heartbeat:Wait()
	end

	local folder = workspace:FindFirstChild("HeroRigPreviews")
	if folder then folder:Destroy() end
	folder = Instance.new("Folder")
	folder.Name = "HeroRigPreviews"
	folder.Parent = workspace

	local origin = Vector3.new(0, 1500, 40)
	for index, bodyType in { "Slim", "Standard", "Heavy" } do
		local pivot = CFrame.new(origin + Vector3.new((index - 2) * 5, Spec.GROUND_OFFSET, 0))
		local rig = Builder.Build({ Name = "HeroRig_" .. bodyType, BodyType = bodyType, Pivot = pivot, AnchorRoot = true })
		rig.Parent = folder
		settle()
		local label = bodyType .. ": "
		local root = rig.PrimaryPart :: BasePart

		-- Structure ---------------------------------------------------------------
		local partCount, scripts = 0, 0
		for _, d in rig:GetDescendants() do
			if d:IsA("BasePart") then partCount += 1 end
			if d:IsA("LuaSourceContainer") then scripts += 1 end
		end
		check(partCount == #Spec.PART_NAMES, label .. "has " .. #Spec.PART_NAMES .. " parts (got " .. partCount .. ")")
		check(scripts == 0, label .. "contains no scripts")
		check(root ~= nil and root.Name == "HumanoidRootPart", label .. "PrimaryPart is HumanoidRootPart")
		check(rig:FindFirstChildOfClass("Humanoid") == nil, label .. "has no Humanoid")
		check(rig:FindFirstChildWhichIsA("Animator", true) == nil, label .. "has no Animator")
		check(rig:FindFirstChild("AnimController") ~= nil, label .. "has AnimController")
		check(rig:GetAttribute("HeroBodyType") == bodyType, label .. "HeroBodyType attribute")

		local joints = Builder.GetJoints(rig)
		for _, joint in Spec.JOINTS do
			local motor = joints[joint.Name]
			check(motor ~= nil, label .. joint.Name .. " exists")
			if motor then
				check(motor.Parent and motor.Parent.Name == joint.Part1, label .. joint.Name .. " is parented to " .. joint.Part1)
				check(motor.Part0 and motor.Part0.Name == joint.Part0, label .. joint.Name .. " Part0 is " .. joint.Part0)
				check(isIdentityRotation(motor.C0) and isIdentityRotation(motor.C1), label .. joint.Name .. " C0/C1 carry no rotation")
				local a0 = motor.Part0 and motor.Part0:FindFirstChild(joint.Name .. "RigAttachment")
				local a1 = motor.Part1 and motor.Part1:FindFirstChild(joint.Name .. "RigAttachment")
				check(a0 ~= nil and a1 ~= nil and (a0.WorldPosition - a1.WorldPosition).Magnitude < 1e-3, label .. joint.Name .. " rig attachments meet")
			end
		end

		-- Ground contract -----------------------------------------------------------
		local lowest = math.huge
		for _, footName in { "LeftFoot", "RightFoot" } do
			local foot = rig:FindFirstChild(footName) :: BasePart
			lowest = math.min(lowest, foot.Position.Y - foot.Size.Y / 2)
		end
		check(math.abs((root.Position.Y - lowest) - Spec.GROUND_OFFSET) < 1e-3, label .. "root sits GROUND_OFFSET above the soles")

		-- Axis convention against the live engine ---------------------------------
		for _, axis in Spec.AxisChecks do
			Builder.ResetPose(rig)
			settle()
			local part = rig:FindFirstChild(axis.Part) :: BasePart
			local before = root.CFrame:PointToObjectSpace(part.Position)
			joints[axis.Joint].Transform = CFrame.Angles(math.rad(axis.Rotation[1]), math.rad(axis.Rotation[2]), math.rad(axis.Rotation[3]))
			settle()
			local delta = root.CFrame:PointToObjectSpace(part.Position) - before
			local expected = Vector3.new(axis.Direction[1], axis.Direction[2], axis.Direction[3])
			local dot = if delta.Magnitude > 0.05 then delta.Unit:Dot(expected) else 0
			check(dot > 0.7, string.format("%s%s (%d,%d,%d) moves %s as documented (dot %.2f)", label, axis.Joint, axis.Rotation[1], axis.Rotation[2], axis.Rotation[3], axis.Part, dot))
		end

		-- Grip orientation: at rest the grip looks down the arm with up toward the thumb
		-- (forward); with the arm raised forward it looks forward with up vertical.
		Builder.ResetPose(rig)
		settle()
		for _, side in { "Left", "Right" } do
			local hand = rig:FindFirstChild(side .. "Hand") :: BasePart
			local grip = hand:FindFirstChild(side .. "GripAttachment") :: Attachment
			local look = root.CFrame:VectorToObjectSpace(grip.WorldCFrame.LookVector)
			local up = root.CFrame:VectorToObjectSpace(grip.WorldCFrame.UpVector)
			check(look:Dot(Vector3.new(0, -1, 0)) > 0.99, label .. side .. " grip looks down the arm at rest")
			check(up:Dot(Vector3.new(0, 0, -1)) > 0.99, label .. side .. " grip up points forward at rest")
			joints[side .. "Shoulder"].Transform = CFrame.Angles(math.rad(90), 0, 0)
			settle()
			look = root.CFrame:VectorToObjectSpace(grip.WorldCFrame.LookVector)
			up = root.CFrame:VectorToObjectSpace(grip.WorldCFrame.UpVector)
			check(look:Dot(Vector3.new(0, 0, -1)) > 0.99, label .. side .. " grip looks forward with the arm raised")
			check(up:Dot(Vector3.new(0, 1, 0)) > 0.99, label .. side .. " grip up is vertical with the arm raised")
			Builder.ResetPose(rig)
			settle()
		end
	end

	-- Weapon sockets (Phase 2) -------------------------------------------------------
	local Sockets = require(HeroRig.HeroSockets)
	local Weapons = require(game.ReplicatedStorage.Assets.WeaponModelBuilder)
	local builders = {
		weapon_bow = Weapons.BuildBow,
		weapon_sword_shield = Weapons.BuildSwordShield,
		weapon_daggers = Weapons.BuildDaggers,
		weapon_axe = Weapons.BuildAxe,
		weapon_staff = Weapons.BuildStaff,
		weapon_tome = Weapons.BuildTome,
	}
	local function angleBetween(a: CFrame, b: CFrame): number
		local _, angle = (a.Rotation:Inverse() * b.Rotation):ToAxisAngle()
		return math.deg(math.abs(angle))
	end

	local weaponTypes = { "BOW", "SWORD_SHIELD", "DAGGERS", "AXE", "STAFF", "TOME" }
	for index, weaponType in weaponTypes do
		local label = weaponType .. ": "
		local pivot = CFrame.new(origin + Vector3.new((index - 3.5) * 5, Spec.GROUND_OFFSET, 15))
		local rig = Builder.Build({ Name = "HeroRig_" .. weaponType, Pivot = pivot, AnchorRoot = true })
		rig.Parent = folder
		local root = rig.PrimaryPart :: BasePart
		local joints = Builder.GetJoints(rig)
		local weapon = Sockets.Equip(rig, builders[Sockets.PREFABS[weaponType]](), weaponType)
		settle()

		check(weapon.Parent == rig and weapon.Name == "EquippedWeapon", label .. "parented as EquippedWeapon")
		check(rig:GetAttribute("EquippedWeaponType") == weaponType, label .. "EquippedWeaponType attribute")
		local anchored = 0
		for _, d in weapon:GetDescendants() do
			if d:IsA("BasePart") and d.Anchored then anchored += 1 end
		end
		check(anchored == 0, label .. "no anchored weapon parts")

		-- Each weapon attachment coincides with its rig attachment.
		for _, socket in Sockets.SOCKETS[weaponType] do
			local assembly = if socket.Assembly then weapon:FindFirstChild(socket.Assembly) :: Model else weapon
			local weaponAttachment = (assembly.PrimaryPart :: BasePart):FindFirstChild(socket.WeaponAttachment) :: Attachment
			local rigAttachment = (rig:FindFirstChild(socket.RigPart) :: BasePart):FindFirstChild(socket.RigAttachment) :: Attachment
			local gap = (weaponAttachment.WorldPosition - rigAttachment.WorldPosition).Magnitude
			local turn = angleBetween(weaponAttachment.WorldCFrame, rigAttachment.WorldCFrame)
			check(gap < 0.05, string.format("%s%s meets %s.%s (gap %.3f)", label, socket.WeaponAttachment, socket.RigPart, socket.RigAttachment, gap))
			check(turn < 2, string.format("%s%s aligns with %s.%s (%.1f deg)", label, socket.WeaponAttachment, socket.RigPart, socket.RigAttachment, turn))
		end

		local function rootDir(v: Vector3): Vector3
			return root.CFrame:VectorToObjectSpace(v).Unit
		end
		if weaponType == "BOW" then
			-- Arm raised forward: stave vertical, nocked arrow pointing at the target.
			joints.LeftShoulder.Transform = CFrame.Angles(math.rad(90), 0, 0)
			settle()
			local handle = weapon.PrimaryPart :: BasePart
			local stave = rootDir((handle:FindFirstChild("TipUpper") :: Attachment).WorldPosition - (handle:FindFirstChild("TipLower") :: Attachment).WorldPosition)
			local shaft = weapon:FindFirstChild("ArrowShaft", true) :: BasePart
			local arrow = rootDir(shaft.CFrame.LookVector)
			check(stave:Dot(Vector3.yAxis) > 0.985, string.format("%sstave vertical with the arm raised (dot %.3f)", label, stave:Dot(Vector3.yAxis)))
			check(arrow:Dot(-Vector3.zAxis) > 0.985, string.format("%sarrow points forward with the arm raised (dot %.3f)", label, arrow:Dot(-Vector3.zAxis)))
			local nock = (handle:FindFirstChild("Nock") :: Attachment).WorldPosition
			local tail = shaft.Position - shaft.CFrame.LookVector * shaft.Size.Z / 2
			check((tail - nock).Magnitude < 0.05, label .. "arrow nock sits on the string")
			Builder.ResetPose(rig)
		elseif weaponType == "SWORD_SHIELD" then
			-- Forearm raised forward (elbow 90): blade points up.
			joints.RightElbow.Transform = CFrame.Angles(math.rad(90), 0, 0)
			settle()
			local grip = (weapon.PrimaryPart :: BasePart):FindFirstChild("Grip") :: Attachment
			check(rootDir(grip.WorldCFrame.UpVector):Dot(Vector3.yAxis) > 0.985, label .. "blade points up with the forearm raised")
			Builder.ResetPose(rig)
			settle()
			-- Shield on the outer face of the left forearm, face out, long axis vertical.
			local face = weapon:FindFirstChild("ShieldFace", true) :: BasePart
			local forearm = rig:FindFirstChild("LeftLowerArm") :: BasePart
			check(rootDir(-face.CFrame.RightVector):Dot(-Vector3.xAxis) > 0.985, label .. "shield face looks outward")
			check(rootDir(face.CFrame.UpVector):Dot(Vector3.yAxis) > 0.985, label .. "shield long axis is vertical at rest")
			local faceX = root.CFrame:PointToObjectSpace(face.Position).X
			local armX = root.CFrame:PointToObjectSpace(forearm.Position).X
			check(faceX < armX - forearm.Size.X / 2, label .. "shield sits outside the forearm")
		elseif weaponType == "DAGGERS" then
			-- ReverseGrip turns the blades to run back along the forearm.
			local reversed = builders.weapon_daggers()
			reversed:SetAttribute("ReverseGrip", true)
			Sockets.Equip(rig, reversed, weaponType)
			settle()
			local grip = (reversed.PrimaryPart :: BasePart):FindFirstChild("Grip") :: Attachment
			check(rootDir(grip.WorldCFrame.UpVector):Dot(Vector3.zAxis) > 0.985, label .. "reverse grip points the blade backward at rest")
			check(#rig:GetChildren() > 0 and rig:FindFirstChild("EquippedWeapon") == reversed, label .. "re-equip replaces the previous weapon")
		elseif weaponType == "AXE" then
			local hand = rig:FindFirstChild("RightHand") :: BasePart
			local pommel = weapon:FindFirstChild("Pommel", true) :: BasePart
			local head = weapon:FindFirstChild("HeadCollar", true) :: BasePart
			check((hand.Position - pommel.Position).Magnitude < (hand.Position - head.Position).Magnitude, label .. "held near the butt of the haft")
		end
	end

	-- Unequip clears the weapon.
	local probe = folder:FindFirstChild("HeroRig_STAFF") :: Model
	Sockets.Unequip(probe)
	check(probe:FindFirstChild("EquippedWeapon") == nil and probe:GetAttribute("EquippedWeaponType") == nil, "Unequip removes the weapon")
	Sockets.Equip(probe, builders.weapon_staff(), "STAFF")

	-- Costumes (Phase 3) -------------------------------------------------------------
	local Registry = require(HeroRig.HeroRegistry)
	local Costumes = require(HeroRig.HeroCostumes)
	local Catalog = require(game.ReplicatedStorage.Shared.Config.HeroCatalog)
	local Artifacts = require(game.ReplicatedStorage.Shared.Config.ArtifactCatalog)
	for index, costume in Costumes.List do
		local heroId = costume.HeroId
		local label = heroId .. ": "
		for armed = 0, 1 do
			local pivot = CFrame.new(origin + Vector3.new((index - 6.5) * 6, Spec.GROUND_OFFSET, 30 + armed * 10))
			local rig = Registry.Build(heroId, pivot)
			rig.Name = heroId .. (if armed == 1 then "_armed" else "")
			;(rig.PrimaryPart :: BasePart).Anchored = true
			rig.Parent = folder
			if armed == 1 then
				local weaponType = Artifacts.ArchetypeWeaponType[Catalog.Seeds[heroId].Archetype]
				Sockets.Equip(rig, builders[Sockets.PREFABS[weaponType]](), weaponType)
				continue
			end
			settle()

			local parts, meshes, scripts, decals = 0, 0, 0, 0
			for _, d in rig:GetDescendants() do
				if d:IsA("BasePart") then parts += 1 end
				if d:IsA("MeshPart") or d:IsA("SpecialMesh") then meshes += 1 end
				if d:IsA("LuaSourceContainer") then scripts += 1 end
				if d:IsA("Decal") or d:IsA("Texture") then decals += 1 end
			end
			check(parts <= Costumes.PART_BUDGET, string.format("%s%d parts within budget %d", label, parts, Costumes.PART_BUDGET))
			check(parts == #Spec.PART_NAMES + #costume.Pieces, label .. "one Part per costume piece")
			check(meshes == 0 and scripts == 0, label .. "no meshes or scripts")
			check(decals <= 1, label .. "only the face decal")
			check(rig:GetAttribute("HeroId") == heroId, label .. "HeroId attribute")

			-- Every piece is held by exactly one explicit Weld to the bone it is parented to.
			local pieces = {}
			for _, d in rig:GetDescendants() do
				if d:IsA("BasePart") and d:GetAttribute("CostumePiece") then
					local welds, constraints = 0, 0
					for _, j in d:GetChildren() do
						if j:IsA("Weld") then welds += 1 end
						if j:IsA("WeldConstraint") then constraints += 1 end
					end
					local weld = d:FindFirstChildOfClass("Weld")
					check(welds == 1 and constraints == 0 and weld ~= nil and weld.Part0 == d.Parent and weld.Part1 == d, label .. d.Name .. " has one Weld to its bone")
					table.insert(pieces, { Part = d, Offset = (d.Parent :: BasePart).CFrame:ToObjectSpace(d.CFrame) })
				end
			end
			check(#pieces == #costume.Pieces, label .. "every costume piece was built")

			-- Pieces stay rigid with their bone in a pose.
			local joints = Builder.GetJoints(rig)
			joints.LeftShoulder.Transform = CFrame.Angles(math.rad(70), 0, math.rad(-20))
			joints.RightElbow.Transform = CFrame.Angles(math.rad(80), 0, 0)
			joints.Neck.Transform = CFrame.Angles(0, math.rad(30), 0)
			joints.LeftKnee.Transform = CFrame.Angles(math.rad(-50), 0, 0)
			settle()
			local drift = 0
			for _, p in pieces do
				local now = (p.Part.Parent :: BasePart).CFrame:ToObjectSpace(p.Part.CFrame)
				drift = math.max(drift, (now.Position - p.Offset.Position).Magnitude)
			end
			check(drift < 1e-3, string.format("%spieces stay attached in a pose (max drift %.4f)", label, drift))
			Builder.ResetPose(rig)
		end
	end

	for _, m in folder:GetChildren() do
		if m:IsA("Model") then
			m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		end
	end
	if not keepPreviews then
		folder:Destroy()
	end
	return { Passed = passed, Failed = #failures, Failures = failures }
end
