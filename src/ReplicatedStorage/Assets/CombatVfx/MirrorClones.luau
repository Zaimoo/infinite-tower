--!strict
-- ReplicatedStorage/Assets/CombatVfx/MirrorClones.luau
-- Glass copies of a rendered hero rig for skill effects (Nyx's Shatterdance: "five mirror clones
-- slash inward in turn"). A clone is the hero's own model (costume, hair, weapon) with its
-- scripts, humanoid, tags and effects stripped, every part anchored and turned into tinted glass
-- under a Highlight outline. It is posed with HeroAnimator.ApplyStaticPose and moved with
-- PivotTo. Cosmetic and client-only.

local CollectionService = game:GetService("CollectionService")

local HeroRig = script.Parent.Parent:WaitForChild("HeroRig")
local HeroAnimator = require(HeroRig:WaitForChild("HeroAnimator"))

local MirrorClones = {}

-- Classes removed from a clone: anything that runs code, simulates, makes sound or emits.
local STRIP = table.freeze({
	Humanoid = true, AnimationController = true, Animator = true, Script = true, LocalScript = true,
	BillboardGui = true, SurfaceGui = true, Sound = true, ParticleEmitter = true, Beam = true,
	Trail = true, Highlight = true, ProximityPrompt = true, ClickDetector = true,
})

export type Clone = {
	Model: Model,
	-- Places the clone at `frame` (its pivot, the rig's root) in `pose` (HeroAnimator.Sample).
	Pose: (frame: CFrame, pose: { [string]: CFrame }) -> (),
	-- Moves the clone without re-posing it.
	Move: (frame: CFrame) -> (),
	-- 0 = fully shown, 1 = gone.
	Fade: (amount: number) -> (),
	Destroy: () -> (),
}

-- The Model ancestor (below `root`) whose PrimaryPart carries this weapon part, if any.
local function assemblyPrimary(part: BasePart, root: Instance): BasePart?
	local node: Instance? = part.Parent
	while node and node ~= root do
		if node:IsA("Model") and node.PrimaryPart then
			return node.PrimaryPart
		end
		node = node.Parent
	end
	return nil
end

function MirrorClones.Make(rig: Model, parent: Instance, tint: Color3, rim: Color3): Clone?
	local archivable = rig.Archivable
	rig.Archivable = true
	local ok, made = pcall(rig.Clone, rig)
	rig.Archivable = archivable
	if not ok or not made then
		return nil
	end
	local model = made :: Model
	model.Name = "MirrorClone"
	for name in model:GetAttributes() do
		model:SetAttribute(name, nil)
	end

	local doomed = {}
	for _, d in model:GetDescendants() do
		if STRIP[d.ClassName] then
			table.insert(doomed, d)
		end
	end
	for _, d in doomed do
		d:Destroy()
	end

	-- Weapon parts hang off their assembly's primary with WeldConstraints, which anchored posing
	-- ignores: remember each one's offset now, while the rig still holds it correctly.
	local weapon = model:FindFirstChild("EquippedWeapon")
	local followers: { { Part: BasePart, Primary: BasePart, Offset: CFrame } } = {}
	local parts: { { Part: BasePart, Base: number } } = {}
	local decals: { { Decal: Decal, Base: number } } = {}
	for _, d in model:GetDescendants() do
		for _, tag in CollectionService:GetTags(d) do
			CollectionService:RemoveTag(d, tag)
		end
		if d:IsA("BasePart") then
			if weapon and d:IsDescendantOf(weapon) then
				local primary = assemblyPrimary(d, model)
				if primary and primary ~= d then
					table.insert(followers, { Part = d, Primary = primary, Offset = primary.CFrame:ToObjectSpace(d.CFrame) })
				end
			end
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			if d.Transparency < 1 then
				d.Material = Enum.Material.Glass
				d.Color = d.Color:Lerp(tint, 0.6)
				table.insert(parts, { Part = d, Base = math.max(d.Transparency, 0.3) })
			end
		elseif d:IsA("Decal") then
			table.insert(decals, { Decal = d, Base = math.max(d.Transparency, 0.35) })
		end
	end
	for _, tag in CollectionService:GetTags(model) do
		CollectionService:RemoveTag(model, tag)
	end

	local highlight = Instance.new("Highlight")
	highlight.FillColor = tint
	highlight.OutlineColor = rim
	highlight.FillTransparency = 0.55
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model

	local function follow()
		for _, f in followers do
			f.Part.CFrame = f.Primary.CFrame * f.Offset
		end
	end

	local clone: Clone
	clone = {
		Model = model,
		Pose = function(frame: CFrame, pose: { [string]: CFrame })
			model:PivotTo(frame)
			HeroAnimator.ApplyStaticPose(model, pose)
			follow()
		end,
		Move = function(frame: CFrame)
			model:PivotTo(frame)
		end,
		Fade = function(amount: number)
			local a = math.clamp(amount, 0, 1)
			for _, p in parts do
				p.Part.Transparency = p.Base + (1 - p.Base) * a
			end
			for _, d in decals do
				d.Decal.Transparency = d.Base + (1 - d.Base) * a
			end
			highlight.FillTransparency = 0.55 + 0.45 * a
			highlight.OutlineTransparency = a
		end,
		Destroy = function()
			model:Destroy()
		end,
	}
	clone.Fade(1)
	model.Parent = parent
	return clone
end

return table.freeze(MirrorClones)
