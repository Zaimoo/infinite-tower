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

	if not keepPreviews then
		folder:Destroy()
	end
	return { Passed = passed, Failed = #failures, Failures = failures }
end
