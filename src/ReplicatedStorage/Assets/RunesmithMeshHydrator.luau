--!strict
-- ReplicatedStorage/Assets/RunesmithMeshHydrator.luau
-- Shared loader/hydrator for the Blender-authored Runesmith's Anvil Sanctuary.
-- Resolves Studio-imported MeshParts under ReplicatedStorage.Assets.CustomFacilityMeshes.RunesmithSanctuary first,
-- then uploaded MeshIds in RunesmithMeshData, and falls back to building the exact Blender BMesh geometry via
-- AssetService:CreateEditableMesh() with client-side hydration.

local AssetService = game:GetService("AssetService")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunesmithMeshData = require(script.Parent:WaitForChild("RunesmithMeshData"))

local RunesmithMeshHydrator = {}

local uploadedMeshCache: { [string]: MeshPart } = {}
local editableMeshCache: { [string]: MeshPart } = {}
local editableMeshObjects: { [string]: EditableMesh } = {}

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

local function createFromEditableMesh(cacheKey: string, spec: RunesmithMeshData.PartMeshSpec): BasePart?
	local cached = editableMeshCache[cacheKey]
	if cached then
		return cached:Clone()
	end

	local ok, built = pcall(function(): MeshPart
		local verts, tris = RunesmithMeshData.GetGeometry(spec)
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

		local normX = table.create(vertCount, 0)
		local normY = table.create(vertCount, 0)
		local normZ = table.create(vertCount, 0)
		for i = 1, #tris, 3 do
			local i1, i2, i3 = tris[i], tris[i + 1], tris[i + 2]
			local p1, p2, p3 = vPos[i1], vPos[i2], vPos[i3]
			if p1 and p2 and p3 then
				local c = (p2 - p1):Cross(p3 - p1)
				normX[i1] += c.X; normY[i1] += c.Y; normZ[i1] += c.Z
				normX[i2] += c.X; normY[i2] += c.Y; normZ[i2] += c.Z
				normX[i3] += c.X; normY[i3] += c.Y; normZ[i3] += c.Z
			end
		end

		local nIds = table.create(vertCount)
		for idx = 1, vertCount do
			local nx, ny, nz = normX[idx], normY[idx], normZ[idx]
			local len = math.sqrt(nx * nx + ny * ny + nz * nz)
			local nVec = if len > 1e-6 then Vector3.new(nx / len, ny / len, nz / len) else Vector3.yAxis
			nIds[idx] = em:AddNormal(nVec)
		end

		for i = 1, #tris, 3 do
			local i1, i2, i3 = tris[i], tris[i + 1], tris[i + 2]
			local a, b, c = vIds[i1], vIds[i2], vIds[i3]
			if a and b and c then
				local triId = em:AddTriangle(a, b, c)
				local na, nb, nc = nIds[i1], nIds[i2], nIds[i3]
				if na and nb and nc then
					pcall(function()
						em:SetFaceNormals(triId, { na, nb, nc })
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

local function configureVisualPart(part: BasePart, spec: RunesmithMeshData.PartMeshSpec, scaleFactor: number)
	part.Name = spec.Name
	part.Size = spec.Size * scaleFactor
	part.Material = spec.Material
	part.Color = spec.Color
	part.Anchored = true
	part.PivotOffset = CFrame.identity
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	-- Physics collision is handled by explicit smooth ramp/deck/rim colliders in ReforgeService.
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = spec.Material ~= Enum.Material.Neon
end

local function findStudioTemplate(): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local custom = assets and assets:FindFirstChild("CustomFacilityMeshes")
	local model = custom and custom:FindFirstChild("RunesmithSanctuary")
	if model and model:IsA("Model") and model:FindFirstChildWhichIsA("MeshPart", true) then
		return model
	end
	return nil
end

local IMPORTER_FIX = CFrame.Angles(0, math.pi, 0)

-- Detects whether a Studio-imported FBX was rotated 180 deg around Y (Bridge_WalkwayDeck sits on -Z locally).
local function studioImporterRotationFix(byName: { [string]: MeshPart }): CFrame
	local bridge = byName.Bridge_WalkwayDeck
	local anvil = byName.Anvil_BasePlate or byName.Anvil_Body
	if bridge and anvil then
		if bridge.Position.Z - anvil.Position.Z > 4 or bridge:GetAttribute("ImporterFlipped") == true then
			return IMPORTER_FIX
		end
	end
	return CFrame.identity
end

function RunesmithMeshHydrator.BuildSanctuary(parent: Instance, origin: CFrame, scale: number?): { BasePart }
	local s = scale or 1
	local specs = RunesmithMeshData.Models.runesmith_sanctuary
	assert(specs, "Missing RunesmithMeshData.Models.runesmith_sanctuary")

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
	local studioRotFix = studioImporterRotationFix(byName)

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
			part = createFromEditableMesh("runesmith_sanctuary:" .. spec.Name, spec)
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
			p:SetAttribute("PendingBlenderRunesmithMesh", true)
			p:SetAttribute("RunesmithPartIndex", idx)
		end
		p.Parent = parent
		table.insert(created, p)
	end

	return created
end

-- Client-side hydration for any EditableMesh part that does not carry a replicated Roblox MeshId yet.
function RunesmithMeshHydrator.HydratePendingClientParts(root: Instance)
	local specs = RunesmithMeshData.Models.runesmith_sanctuary
	if not specs then
		return
	end
	for _, desc in root:GetDescendants() do
		if desc:IsA("BasePart") and desc:GetAttribute("PendingBlenderRunesmithMesh") == true then
			local partIdx = desc:GetAttribute("RunesmithPartIndex")
			local spec = if type(partIdx) == "number" then specs[partIdx] else nil
			if spec then
				local scaleFactor = if spec.Size.Y > 0.001 then desc.Size.Y / spec.Size.Y else 1
				local localMesh = createFromEditableMesh("runesmith_sanctuary:" .. spec.Name, spec)
				if localMesh and localMesh:IsA("MeshPart") then
					configureVisualPart(localMesh, spec, scaleFactor)
					localMesh.CFrame = desc.CFrame
					for _, child in desc:GetChildren() do
						child:Clone().Parent = localMesh
					end
					localMesh.Parent = desc.Parent
					desc.Transparency = 1
					desc.CanCollide = false
					desc:SetAttribute("PendingBlenderRunesmithMesh", false)
				end
			end
		end
	end
end

return RunesmithMeshHydrator
