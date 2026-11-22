--!strict
-- ReplicatedStorage/Assets/GroupChestMeshHydrator.luau
-- Shared loader/hydrator for the Blender-authored Group Chest station.
-- Resolves Studio-imported MeshParts under ReplicatedStorage.Assets.CustomFacilityMeshes.GroupChest first,
-- then uploaded MeshIds in GroupChestMeshData, and falls back to building the exact Blender BMesh geometry via
-- AssetService:CreateEditableMesh() with client-side hydration.

local AssetService = game:GetService("AssetService")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GroupChestMeshData = require(script.Parent:WaitForChild("GroupChestMeshData"))

local GroupChestMeshHydrator = {}

local uploadedMeshCache: { [string]: MeshPart } = {}
local editableMeshCache: { [string]: MeshPart } = {}
local editableMeshObjects: { [string]: EditableMesh } = {}

local IMPORTER_FIX = CFrame.Angles(0, math.pi, 0)

local function createFromUploadedId(meshId: string): MeshPart?
	local cached = uploadedMeshCache[meshId]
	if cached then
		return cached:Clone()
	end

	local ok, mp = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromUri(meshId))
	end)
	if ok and mp and mp:IsA("MeshPart") then
		uploadedMeshCache[meshId] = mp
		return mp:Clone()
	end

	local ok2, mp2 = pcall(function()
		return InsertService:CreateMeshPartAsync(meshId, Enum.CollisionFidelity.Default, Enum.RenderFidelity.Automatic)
	end)
	if ok2 and mp2 and mp2:IsA("MeshPart") then
		uploadedMeshCache[meshId] = mp2
		return mp2:Clone()
	end
	return nil
end

local function createFromEditableMesh(cacheKey: string, spec: GroupChestMeshData.PartMeshSpec): BasePart?
	local cached = editableMeshCache[cacheKey]
	if cached then
		return cached:Clone()
	end

	local ok, built = pcall(function(): MeshPart
		local verts, tris = GroupChestMeshData.GetGeometry(spec)
		local em = AssetService:CreateEditableMesh()
		local vertCount = #verts // 3
		local vPos = table.create(vertCount)
		local vIds = table.create(vertCount)
		for idx = 1, vertCount do
			local base = (idx - 1) * 3
			local pos = Vector3.new(verts[base + 1], verts[base + 2], verts[base + 3])
			vPos[idx] = pos
			vIds[idx] = em:AddVertex(pos)
		end

		local isFaceted = (spec.Material == Enum.Material.Glass or spec.Material == Enum.Material.Neon)
		local triCount = #tris // 3
		local faceNormals = table.create(triCount)
		local vertTris: { { number } } = table.create(vertCount)
		for idx = 1, vertCount do
			vertTris[idx] = {}
		end

		for t = 1, triCount do
			local base = (t - 1) * 3
			local i1, i2, i3 = tris[base + 1], tris[base + 2], tris[base + 3]
			local p1, p2, p3 = vPos[i1], vPos[i2], vPos[i3]
			local fn = Vector3.yAxis
			if p1 and p2 and p3 then
				local c = (p2 - p1):Cross(p3 - p1)
				if c.Magnitude > 1e-8 then
					fn = c.Unit
				end
				table.insert(vertTris[i1], t)
				table.insert(vertTris[i2], t)
				table.insert(vertTris[i3], t)
			end
			faceNormals[t] = fn
		end

		for t = 1, triCount do
			local base = (t - 1) * 3
			local i1, i2, i3 = tris[base + 1], tris[base + 2], tris[base + 3]
			local a, b, c = vIds[i1], vIds[i2], vIds[i3]
			if a and b and c then
				local triId = em:AddTriangle(a, b, c)
				local fn = faceNormals[t]
				if isFaceted then
					local nId = em:AddNormal(fn)
					pcall(function()
						em:SetFaceNormals(triId, { nId, nId, nId })
					end)
				else
					local nCorners = table.create(3)
					local cornerVerts = { i1, i2, i3 }
					for k = 1, 3 do
						local sum = Vector3.zero
						for _, otherT in vertTris[cornerVerts[k]] do
							local ofn = faceNormals[otherT]
							if fn:Dot(ofn) >= 0.866 then
								sum += ofn
							end
						end
						local nVec = if sum.Magnitude > 1e-6 then sum.Unit else fn
						nCorners[k] = em:AddNormal(nVec)
					end
					pcall(function()
						em:SetFaceNormals(triId, nCorners)
					end)
				end
			end
		end

		local mp = AssetService:CreateMeshPartAsync(Content.fromObject(em))
		-- Keep the EditableMesh alive: destroying it while referenced by Content.fromObject(em) clears the mesh visuals.
		editableMeshObjects[cacheKey] = em
		return mp
	end)

	if ok and built then
		editableMeshCache[cacheKey] = built
		return built:Clone()
	end
	return nil
end

local function configureVisualPart(part: BasePart, spec: GroupChestMeshData.PartMeshSpec, scaleFactor: number)
	local transparency = spec.Transparency or 0
	part.Name = spec.Name
	part.Size = spec.Size * scaleFactor
	part.Material = spec.Material
	part.Color = spec.Color
	part.Transparency = transparency
	part.Anchored = true
	part.PivotOffset = CFrame.identity
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = (spec.Material ~= Enum.Material.Neon and transparency < 0.1)
end

local function findStudioTemplate(): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local custom = assets and assets:FindFirstChild("CustomFacilityMeshes")
	local model = custom and custom:FindFirstChild("GroupChest")
	if model and model:IsA("Model") and model:FindFirstChildWhichIsA("MeshPart", true) then
		return model
	end
	return nil
end

-- Detects whether a Studio-imported FBX was rotated 180 deg around Y (Lid_FrontClasp sits on -Z locally).
local function studioImporterRotationFix(studioTemplate: Model?, byName: { [string]: MeshPart }): CFrame
	if studioTemplate and studioTemplate:GetAttribute("ImporterFlipped") == true then
		return IMPORTER_FIX
	end
	local clasp = byName.Lid_FrontClasp or byName.Lid_ApexDiamond
	local plinth = byName.Base_GoldPlinth or byName.Base_CornerPillars
	if clasp and plinth then
		if clasp.Position.Z - plinth.Position.Z > 0.5 or clasp:GetAttribute("ImporterFlipped") == true then
			return IMPORTER_FIX
		end
	end
	return CFrame.identity
end

-- Builds the Group Chest visual hierarchy (BaseGroup, LidGroup, GlitchShards) under `parent` at `origin`.
function GroupChestMeshHydrator.BuildChest(parent: Instance, origin: CFrame, scale: number?): { BasePart }
	local s = scale or 1
	local specs = GroupChestMeshData.Models.group_chest
	assert(specs, "Missing GroupChestMeshData.Models.group_chest")

	local baseGroup = Instance.new("Model")
	baseGroup.Name = "BaseGroup"
	baseGroup.Parent = parent

	local lidGroup = Instance.new("Model")
	lidGroup.Name = "LidGroup"
	local closedPivot = origin * CFrame.new(GroupChestMeshData.HingePivot * s)
	lidGroup.WorldPivot = closedPivot
	lidGroup:SetAttribute("ClosedPivot", closedPivot)
	lidGroup.Parent = parent

	local glitchShards = Instance.new("Folder")
	glitchShards.Name = "GlitchShards"
	glitchShards.Parent = parent

	local created: { BasePart } = {}
	local studioTemplate = findStudioTemplate()
	local byName: { [string]: MeshPart } = {}
	if studioTemplate then
		for _, d in studioTemplate:GetDescendants() do
			if d:IsA("MeshPart") then
				local clean = string.gsub(d.Name, "%.%d+$", "")
				byName[clean] = d
			end
		end
	end
	local studioRotFix = studioImporterRotationFix(studioTemplate, byName)

	local shardIdx = 0
	for idx, spec in ipairs(specs) do
		local part: BasePart? = nil
		local usedEditable = false
		local localRot = CFrame.identity

		local studioPart = byName[spec.Name]
		if studioPart then
			part = studioPart:Clone()
			localRot = studioRotFix
		elseif type(spec.MeshId) == "string" and spec.MeshId ~= "" then
			part = createFromUploadedId(spec.MeshId)
			if part then
				localRot = IMPORTER_FIX
			end
		end

		if not part then
			part = createFromEditableMesh("group_chest:" .. spec.Name, spec)
			usedEditable = part ~= nil
		end

		if not part then
			part = Instance.new("Part")
			usedEditable = true
		end

		local p = part :: BasePart
		configureVisualPart(p, spec, s)
		p.CFrame = origin * CFrame.new(spec.Offset * s) * localRot
		if usedEditable then
			p:SetAttribute("PendingBlenderGroupChestMesh", true)
			p:SetAttribute("GroupChestPartIndex", idx)
		end

		if spec.SubCollection == "ChestBase" then
			p.Parent = baseGroup
		elseif spec.SubCollection == "ChestLid" then
			p.Parent = lidGroup
		elseif spec.SubCollection == "ChestGlitch" then
			shardIdx += 1
			p:SetAttribute("BaseOffset", spec.Offset * s)
			p:SetAttribute("ShardIndex", shardIdx)
			p.Parent = glitchShards
		else
			p.Parent = parent
		end
		table.insert(created, p)
	end

	-- Reassert hinge WorldPivot after parenting all lid sub-parts.
	lidGroup.WorldPivot = closedPivot
	lidGroup:SetAttribute("ClosedPivot", closedPivot)

	return created
end

-- Client-side hydration for any EditableMesh part that does not carry a replicated Roblox MeshId yet.
function GroupChestMeshHydrator.HydratePendingClientParts(root: Instance)
	local specs = GroupChestMeshData.Models.group_chest
	if not specs then
		return
	end
	for _, desc in root:GetDescendants() do
		if desc:IsA("BasePart") and desc:GetAttribute("PendingBlenderGroupChestMesh") == true then
			local partIdx = desc:GetAttribute("GroupChestPartIndex")
			local spec = if type(partIdx) == "number" then specs[partIdx] else nil
			if spec then
				local scaleFactor = if spec.Size.Y > 0.001 then desc.Size.Y / spec.Size.Y else 1
				local localMesh = createFromEditableMesh("group_chest:" .. spec.Name, spec)
				if localMesh and localMesh:IsA("MeshPart") then
					configureVisualPart(localMesh, spec, scaleFactor)
					localMesh.Size = desc.Size
					localMesh.CFrame = desc.CFrame
					local baseOffset = desc:GetAttribute("BaseOffset")
					if baseOffset ~= nil then
						localMesh:SetAttribute("BaseOffset", baseOffset)
					end
					local shardIndex = desc:GetAttribute("ShardIndex")
					if shardIndex ~= nil then
						localMesh:SetAttribute("ShardIndex", shardIndex)
					end
					for _, child in desc:GetChildren() do
						child:Clone().Parent = localMesh
					end
					localMesh.Parent = desc.Parent
					desc.Name = "__Replaced_" .. desc.Name
					desc:SetAttribute("PendingBlenderGroupChestMesh", false)
					desc:SetAttribute("ReplacedByHydratedMesh", true)
					desc.Transparency = 1
					desc.CanCollide = false
					desc.CanQuery = false
					desc.CanTouch = false
					desc.CastShadow = false
				end
			end
		end
	end
end

return GroupChestMeshHydrator
