--!strict
-- ReplicatedStorage/Assets/HeroRig/HeroRigBuilder.luau
-- Builds a bare, neutral hero R15 rig from HeroRigSpec (hero-rig-rebuild-plan.md, Phase 1).
-- Every Motor6D rests at identity: C0/C1 are the joint's RigAttachment CFrames, which are
-- pure translations, so animation only ever writes Motor6D.Transform.

local HeroRigSpec = require(script.Parent:WaitForChild("HeroRigSpec"))

export type BuildOptions = {
	Name: string?,
	BodyType: HeroRigSpec.BodyTypeName?,
	SkinColor: Color3?,
	Pivot: CFrame?, -- HumanoidRootPart CFrame; defaults to the origin
	AnchorRoot: boolean?, -- anchor only the HumanoidRootPart (static previews, lineups)
}

local HeroRigBuilder = {}

HeroRigBuilder.RIG_VERSION = 1
HeroRigBuilder.DEFAULT_SKIN = Color3.fromRGB(255, 224, 196)

local function toVector3(v: HeroRigSpec.Vec3): Vector3
	return Vector3.new(v[1], v[2], v[3])
end

local function toRotation(degrees: HeroRigSpec.Vec3): CFrame
	return CFrame.Angles(math.rad(degrees[1]), math.rad(degrees[2]), math.rad(degrees[3]))
end

function HeroRigBuilder.Build(options: BuildOptions?): Model
	local opts: BuildOptions = options or {}
	local layout = HeroRigSpec.Layout(opts.BodyType)
	local pivot = opts.Pivot or CFrame.identity
	local skin = opts.SkinColor or HeroRigBuilder.DEFAULT_SKIN

	local model = Instance.new("Model")
	model.Name = opts.Name or "HeroRig"
	model:SetAttribute("HeroRigVersion", HeroRigBuilder.RIG_VERSION)
	model:SetAttribute("HeroBodyType", layout.BodyType)

	local parts: { [string]: Part } = {}
	for _, partName in HeroRigSpec.PART_NAMES do
		local spec = layout.Parts[partName]
		local part = Instance.new("Part")
		part.Name = partName
		part.Size = toVector3(spec.Size)
		part.CFrame = pivot * CFrame.new(toVector3(spec.Center))
		part.Color = skin
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.Anchored = false
		if partName == "HumanoidRootPart" then
			part.Transparency = 1
			part.CastShadow = false
			part.Anchored = opts.AnchorRoot == true
		end
		part.Parent = model
		parts[partName] = part
	end

	-- Attachments first, so each Motor6D can copy its pair.
	local attachmentsByPart: { [string]: { [string]: Attachment } } = {}
	for _, spec in layout.Attachments do
		local attachment = Instance.new("Attachment")
		attachment.Name = spec.Name
		attachment.CFrame = CFrame.new(toVector3(spec.Position)) * toRotation(spec.Rotation)
		attachment.Parent = parts[spec.Part]
		local byName = attachmentsByPart[spec.Part]
		if not byName then
			byName = {}
			attachmentsByPart[spec.Part] = byName
		end
		byName[spec.Name] = attachment
	end

	for _, joint in layout.Joints do
		local attachmentName = joint.Name .. "RigAttachment"
		local motor = Instance.new("Motor6D")
		motor.Name = joint.Name
		motor.Part0 = parts[joint.Part0]
		motor.Part1 = parts[joint.Part1]
		motor.C0 = attachmentsByPart[joint.Part0][attachmentName].CFrame
		motor.C1 = attachmentsByPart[joint.Part1][attachmentName].CFrame
		motor.Parent = parts[joint.Part1]
	end

	-- No Humanoid and no Animator: an Animator would overwrite Motor6D.Transform every
	-- frame. HeroAnimator (Phase 4) drives Transform directly on the client.
	local controller = Instance.new("AnimationController")
	controller.Name = "AnimController"
	controller.Parent = model

	model.PrimaryPart = parts.HumanoidRootPart
	return model
end

-- Joint name -> Motor6D for a built rig.
function HeroRigBuilder.GetJoints(model: Model): { [string]: Motor6D }
	local joints: { [string]: Motor6D } = {}
	for _, joint in HeroRigSpec.JOINTS do
		local part1 = model:FindFirstChild(joint.Part1)
		local motor = part1 and part1:FindFirstChild(joint.Name)
		if motor and motor:IsA("Motor6D") then
			joints[joint.Name] = motor
		end
	end
	return joints
end

-- Returns every joint to the rest pose.
function HeroRigBuilder.ResetPose(model: Model)
	for _, motor in HeroRigBuilder.GetJoints(model) do
		motor.Transform = CFrame.identity
	end
end

return table.freeze(HeroRigBuilder)
