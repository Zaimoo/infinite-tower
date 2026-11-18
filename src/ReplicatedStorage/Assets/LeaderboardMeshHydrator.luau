--!strict
-- ReplicatedStorage/Assets/LeaderboardMeshHydrator.luau
-- Shared loader/hydrator for Blender-authored leaderboard monuments.
-- Resolves Studio-imported models under ReplicatedStorage.Assets.CustomFacilityMeshes first,
-- then uploaded MeshIds in LeaderboardMeshData, and falls back to building the exact
-- Blender BMesh geometry via AssetService:CreateEditableMesh().

local AssetService = game:GetService("AssetService")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LeaderboardMeshData = require(script.Parent:WaitForChild("LeaderboardMeshData"))

local LeaderboardMeshHydrator = {}

local IMPORTER_FIX = CFrame.Angles(0, math.pi, 0)
local uploadedMeshCache: { [string]: MeshPart } = {}
local editableMeshCache: { [string]: MeshPart } = {}

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

local function createFromEditableMesh(cacheKey: string, spec: LeaderboardMeshData.PartMeshSpec): BasePart?
	local cached = editableMeshCache[cacheKey]
	if cached then
		return cached:Clone()
	end

	local ok, built = pcall(function(): MeshPart
		local verts, tris = LeaderboardMeshData.GetGeometry(spec)
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
		pcall(function()
			em:Destroy()
		end)
		return mp
	end)

	if ok and built then
		editableMeshCache[cacheKey] = built
		return built:Clone()
	end
	return nil
end

local function configurePartProps(part: BasePart, spec: LeaderboardMeshData.PartMeshSpec, scaleFactor: number?)
	local s = scaleFactor or 1
	part.Name = spec.Name
	part.Size = spec.Size * s
	part.Material = spec.Material
	part.Color = spec.Color
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	local collidable = spec.Collidable
	part.CanCollide = collidable
	part.CanQuery = collidable
	part.CanTouch = false
	part.CastShadow = collidable
	if not collidable then
		part.Massless = true
	end
end

local function findStudioTemplate(studioModelName: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local custom = assets and assets:FindFirstChild("CustomFacilityMeshes")
	local model = custom and custom:FindFirstChild(studioModelName)
	if model and model:IsA("Model") and model:FindFirstChildWhichIsA("MeshPart", true) then
		return model
	end
	return nil
end

function LeaderboardMeshHydrator.BuildMonument(parent: Instance, modelKey: string, studioModelName: string): { BasePart }
	local specs = LeaderboardMeshData.Models[modelKey]
	assert(specs, "Missing LeaderboardMeshData.Models entry: " .. tostring(modelKey))

	local created: { BasePart } = {}
	local studioTemplate = findStudioTemplate(studioModelName)
	local byName: { [string]: MeshPart } = {}
	if studioTemplate then
		for _, d in studioTemplate:GetDescendants() do
			if d:IsA("MeshPart") then
				local clean = string.gsub(d.Name, "%.%d+$", "")
				byName[clean] = d
			end
		end
	end

	for idx, spec in ipairs(specs) do
		local part: BasePart? = nil
		local usedEditable = false
		local needsImporterFlip = false

		local studioPart = byName[spec.Name]
		if studioPart then
			part = studioPart:Clone()
			needsImporterFlip = true
		elseif type(spec.MeshId) == "string" and spec.MeshId ~= "" then
			part = createFromUploadedId(spec.MeshId)
			needsImporterFlip = true
		end

		if not part then
			part = createFromEditableMesh(modelKey .. ":" .. spec.Name, spec)
			usedEditable = part ~= nil
		end

		if not part then
			part = Instance.new("Part")
			usedEditable = true
		end

		local p = part :: BasePart
		configurePartProps(p, spec, 1)
		p.CFrame = if needsImporterFlip then CFrame.new(spec.Offset) * IMPORTER_FIX else CFrame.new(spec.Offset)
		if usedEditable then
			-- Marks EditableMesh parts so clients hydrate client-local MeshContent when MeshId is not yet uploaded.
			p:SetAttribute("PendingBlenderMesh", true)
			p:SetAttribute("BlenderModelKey", modelKey)
			p:SetAttribute("BlenderPartIndex", idx)
		end
		p.Parent = parent
		table.insert(created, p)
	end

	return created
end

-- Client-side hydration for any EditableMesh part that does not carry a replicated Roblox MeshId yet.
function LeaderboardMeshHydrator.HydratePendingClientParts(root: Instance)
	for _, desc in root:GetDescendants() do
		if desc:IsA("BasePart") and desc:GetAttribute("PendingBlenderMesh") == true then
			local modelKey = desc:GetAttribute("BlenderModelKey")
			local partIdx = desc:GetAttribute("BlenderPartIndex")
			if type(modelKey) == "string" and type(partIdx) == "number" then
				local specs = LeaderboardMeshData.Models[modelKey]
				local spec = specs and specs[partIdx]
				if spec then
					local scaleFactor = if spec.Size.Y > 0.001 then desc.Size.Y / spec.Size.Y else 1
					local localMesh = createFromEditableMesh(modelKey .. ":" .. spec.Name, spec)
					if localMesh and localMesh:IsA("MeshPart") then
						configurePartProps(localMesh, spec, scaleFactor)
						localMesh.CFrame = desc.CFrame
						for _, child in desc:GetChildren() do
							child:Clone().Parent = localMesh
						end
						localMesh.Parent = desc.Parent
						desc.Transparency = 1
						desc.CanCollide = false
						desc:SetAttribute("PendingBlenderMesh", false)
					end
				end
			end
		end
	end
end

return LeaderboardMeshHydrator
