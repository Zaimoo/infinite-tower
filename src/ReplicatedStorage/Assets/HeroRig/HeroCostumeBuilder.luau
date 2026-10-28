--!strict
-- ReplicatedStorage/Assets/HeroRig/HeroCostumeBuilder.luau
-- Dresses a bare hero rig from HeroCostumes data (hero-rig-rebuild-plan.md, Phase 3).
-- Body parts are recoloured; every costume piece is a Part/WedgePart welded to exactly one
-- bone with an explicit Weld (C0 = piece placement in bone space), so it follows that bone
-- in any pose. No scripts or asset IDs are created apart from the face decal and the
-- allow-listed FileMeshes in HeroCostumes.MESHES (anime hair).

local HeroRigSpec = require(script.Parent:WaitForChild("HeroRigSpec"))
local HeroCostumeMath = require(script.Parent:WaitForChild("HeroCostumeMath"))
local HeroCostumes = require(script.Parent:WaitForChild("HeroCostumes"))

local HeroCostumeBuilder = {}

local function toColor(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function toCFrame(position: { number }, m: { number }): CFrame
	return CFrame.new(position[1], position[2], position[3], m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9])
end

local SHAPES: { [string]: Enum.PartType } = {
	Block = Enum.PartType.Block,
	Ball = Enum.PartType.Ball,
	Cylinder = Enum.PartType.Cylinder,
}

-- Applies a costume to a rig built by HeroRigBuilder with the costume's body type.
function HeroCostumeBuilder.Apply(rig: Model, costume: HeroCostumes.Costume)
	local layout = HeroRigSpec.Layout(costume.BodyType)

	for partName, rgb in HeroCostumes.BodyColors(costume) do
		local part = rig:FindFirstChild(partName)
		if part and part:IsA("BasePart") and partName ~= "HumanoidRootPart" then
			part.Color = toColor(rgb)
		end
	end

	local head = rig:FindFirstChild("Head")
	if head and costume.Face then
		local face = Instance.new("Decal")
		face.Name = "face"
		face.Face = Enum.NormalId.Front
		face.Texture = costume.Face
		face.Parent = head
	end

	for _, entry in HeroCostumeMath.Resolve(costume.Pieces, layout) do
		local piece = entry.Piece
		local bone = rig:FindFirstChild(piece.Bone)
		assert(bone and bone:IsA("BasePart"), `Costume {costume.HeroId}: missing bone {piece.Bone}`)

		local part: BasePart
		if piece.Shape == "Wedge" then
			part = Instance.new("WedgePart")
		else
			local block = Instance.new("Part")
			block.Shape = SHAPES[piece.Shape or "Block"] or Enum.PartType.Block
			part = block
		end
		part.Name = piece.Name
		part.Size = Vector3.new(entry.Size[1], entry.Size[2], entry.Size[3])
		part.Color = toColor(piece.Color)
		part.Material = (Enum.Material :: any)[piece.Material or "SmoothPlastic"]
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.Anchored = false
		part.CastShadow = false
		local meshScale = entry.MeshScale
		if piece.Mesh and meshScale then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.FileMesh
			mesh.MeshId = piece.Mesh.MeshId
			mesh.TextureId = piece.Mesh.TextureId or ""
			mesh.Scale = Vector3.new(meshScale[1], meshScale[2], meshScale[3])
			mesh.Parent = part
		end

		local placement = toCFrame(entry.Position, entry.Rotation)
		part.CFrame = bone.CFrame * placement
		local weld = Instance.new("Weld")
		weld.Name = "CostumeWeld"
		weld.Part0 = bone
		weld.Part1 = part
		weld.C0 = placement
		weld.Parent = part
		part:SetAttribute("CostumePiece", true)
		part.Parent = bone
	end

	rig:SetAttribute("HeroId", costume.HeroId)
end

return table.freeze(HeroCostumeBuilder)
