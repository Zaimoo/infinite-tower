--!strict
-- HubPathMeshHydrator.luau
-- Builds and hydrates the Hub's cobblestone path network and plot bridge decks
-- matching the Runesmith Sanctuary Bridge_WalkwayDeck stone material, scale=0.25 UVs,
-- and raised 0.56-wide +0.38-proud beveled side curbs.
--
-- Resolution order per piece:
-- 1. Pre-imported MeshPart inside ReplicatedStorage.Assets.Environment.HubCobblePaths (or Assets.HubCobblePaths)
-- 2. Published rbxassetid:// mesh map in HubPathMeshData (when set)
-- 3. Procedural EditableMesh rebuilt from packed Blender shards (with normals + box UVs)

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local HubPathMeshData = require(script.Parent:WaitForChild("HubPathMeshData"))

export type HubPathShard = HubPathMeshData.HubPathShard

local HubPathMeshHydrator = {}

local COBBLE_COLOR = Color3.fromRGB(116, 112, 98)

local PLOT_BRIDGE_PARTS = {
	{ shard = "Hub_PlotBridgeDeck", suffix = "_CobbleMesh" },
	{ shard = "Hub_PlotBridgeParapets", suffix = "_GothicParapets" },
	{ shard = "Hub_PlotBridgeSpires", suffix = "_HangingSpires" },
}

local PLOT_BRIDGE_SHARD_SET: { [string]: boolean } = {}
for _, entry in ipairs(PLOT_BRIDGE_PARTS) do
	PLOT_BRIDGE_SHARD_SET[entry.shard] = true
end

local MATERIAL_BY_NAME: { [string]: Enum.Material } = {
	Cobblestone = Enum.Material.Cobblestone,
	Slate = Enum.Material.Slate,
	Grass = Enum.Material.Grass,
	Rock = Enum.Material.Rock,
}

-- Strong references so Roblox does not GC EditableMeshes backing live MeshParts.
local activeEditableMeshes: { [Instance]: any } = {}
local activeTemplateMeshes: { [string]: any } = {}
local publishedTemplateCache: { [string]: MeshPart } = {}
local IMPORTER_FIX = CFrame.Angles(0, math.pi, 0)

local function isEditMode(): boolean
	return RunService:IsStudio() and not RunService:IsRunning()
end

local function getStudioImportTemplate(): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		return nil
	end
	local env = assets:FindFirstChild("Environment")
	if env then
		local inEnv = env:FindFirstChild("HubCobblePaths")
		if inEnv then
			return inEnv
		end
	end
	return assets:FindFirstChild("HubCobblePaths")
end

local function computeTemplateCorrectionCF(template: Instance): CFrame
	if not template:IsA("Model") then
		return CFrame.identity
	end
	local pilgrims = template:FindFirstChild("Hub_PilgrimsWay", true)
	if not pilgrims or not pilgrims:IsA("BasePart") then
		return CFrame.identity
	end
	local relPos = template:GetPivot():PointToObjectSpace(pilgrims.Position)
	if relPos.Z > 80 then
		return CFrame.identity
	elseif relPos.Z < -80 then
		return CFrame.Angles(0, math.pi, 0)
	elseif relPos.X > 80 then
		return CFrame.Angles(0, math.pi * 0.5, 0)
	elseif relPos.X < -80 then
		return CFrame.Angles(0, -math.pi * 0.5, 0)
	end
	return CFrame.identity
end

local function applyBridgeSurfaceStyle(part: BasePart, shard: HubPathShard?, name: string?)
	if name then
		part.Name = name
	end
	if shard then
		part.Material = MATERIAL_BY_NAME[shard.material] or Enum.Material.Cobblestone
		local c = shard.color
		part.Color = Color3.fromRGB(c[1], c[2], c[3])
	else
		part.Material = Enum.Material.Cobblestone
		part.Color = COBBLE_COLOR
	end
	part.MaterialVariant = ""
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = true
	part.Massless = true
end

local function buildEditableMeshFromShard(shard: HubPathShard): any?
	local cached = activeTemplateMeshes[shard.partName]
	if cached then
		return cached
	end
	if not isEditMode() then
		return nil
	end

	local ok, em = pcall(function()
		return AssetService:CreateEditableMesh()
	end)
	if not ok or not em then
		return nil
	end

	local vb = shard.vb
	local vertIds = table.create(#vb // 3)
	for i = 1, #vb, 3 do
		vertIds[#vertIds + 1] = em:AddVertex(Vector3.new(vb[i], vb[i + 1], vb[i + 2]))
	end

	local nb = shard.nb
	local normIds = table.create(#nb // 3)
	for i = 1, #nb, 3 do
		normIds[#normIds + 1] = em:AddNormal(Vector3.new(nb[i], nb[i + 1], nb[i + 2]))
	end

	local ub = shard.ub
	local uvIds = table.create(#ub // 2)
	for i = 1, #ub, 2 do
		uvIds[#uvIds + 1] = em:AddUV(Vector2.new(ub[i], ub[i + 1]))
	end

	local tb = shard.tb
	local ntb = shard.ntb
	local uvtb = shard.uvtb
	for i = 1, #tb, 3 do
		local v0 = vertIds[tb[i]]
		local v1 = vertIds[tb[i + 1]]
		local v2 = vertIds[tb[i + 2]]
		if v0 and v1 and v2 and v0 ~= v1 and v1 ~= v2 and v0 ~= v2 then
			local faceOk, faceId = pcall(function()
				return em:AddTriangle(v0, v1, v2)
			end)
			if faceOk and faceId then
				local n0 = normIds[ntb[i]]
				local n1 = normIds[ntb[i + 1]]
				local n2 = normIds[ntb[i + 2]]
				if n0 and n1 and n2 then
					pcall(function()
						em:SetFaceNormals(faceId, { n0, n1, n2 })
					end)
				end
				local uv0 = uvIds[uvtb[i]]
				local uv1 = uvIds[uvtb[i + 1]]
				local uv2 = uvIds[uvtb[i + 2]]
				if uv0 and uv1 and uv2 then
					pcall(function()
						em:SetFaceUVs(faceId, { uv0, uv1, uv2 })
					end)
				end
			end
		end
	end

	activeTemplateMeshes[shard.partName] = em
	return em
end

local function createHydratedMeshPartFromShard(shard: HubPathShard, worldCF: CFrame, displayName: string?, parent: Instance): BasePart?
	local em = buildEditableMeshFromShard(shard)
	if not em then
		return nil
	end

	local ok, meshPart = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromObject(em))
	end)
	if not ok or not meshPart or not meshPart:IsA("MeshPart") then
		return nil
	end

	activeEditableMeshes[meshPart] = em
	applyBridgeSurfaceStyle(meshPart, shard, displayName or shard.name)
	meshPart.Size = Vector3.new(shard.size[1], shard.size[2], shard.size[3])
	meshPart.CFrame = worldCF
	meshPart:SetAttribute("HubPathShard", shard.partName)
	meshPart.Destroying:Connect(function()
		activeEditableMeshes[meshPart] = nil
	end)
	meshPart.Parent = parent
	return meshPart
end

local function clonePublishedMeshPart(shard: HubPathShard, worldCF: CFrame, displayName: string?, parent: Instance): MeshPart?
	local meshIds = HubPathMeshData.MeshIds
	local meshId = if meshIds then meshIds[shard.partName] else nil
	if not meshId or meshId == "" then
		return nil
	end

	local cached = publishedTemplateCache[shard.partName]
	if not cached then
		local ok, created = pcall(function()
			return AssetService:CreateMeshPartAsync(Content.fromUri(meshId))
		end)
		if ok and created and created:IsA("MeshPart") then
			cached = created
			publishedTemplateCache[shard.partName] = cached
		end
	end
	if not cached then
		return nil
	end

	local clone = cached:Clone()
	clone:ClearAllChildren()
	applyBridgeSurfaceStyle(clone, shard, displayName or shard.name)
	clone.Size = Vector3.new(shard.size[1], shard.size[2], shard.size[3])
	clone.CFrame = worldCF * IMPORTER_FIX
	clone.Parent = parent
	return clone
end

local function cloneImportedTemplatePart(template: Instance, partName: string, shard: HubPathShard?, targetCF: CFrame, displayName: string?, parent: Instance): MeshPart?
	local found = template:FindFirstChild(partName, true)
	if not found or not found:IsA("MeshPart") then
		return nil
	end
	local clone = found:Clone()
	clone:ClearAllChildren()
	applyBridgeSurfaceStyle(clone, shard, displayName or partName)
	clone.CFrame = targetCF
	clone.Parent = parent
	return clone
end

function HubPathMeshHydrator.HydratePendingClientParts(root: Instance): number
	local hydrated = 0
	local template = getStudioImportTemplate()
	for _, desc in root:GetDescendants() do
		if desc:IsA("MeshPart") then
			local shardName = desc:GetAttribute("HubPathShard")
			if typeof(shardName) == "string" and shardName ~= "" then
				local shard = HubPathMeshData.ByPartName[shardName]
				-- Skip if already serialized with valid mesh geometry (Edit-mode bake or published asset)
				if desc.MeshSize.Magnitude > 0.05 then
					activeEditableMeshes[desc] = true
					applyBridgeSurfaceStyle(desc, shard)
					continue
				end
				if template then
					local found = template:FindFirstChild(shardName, true)
					if found and found:IsA("MeshPart") then
						desc:ApplyMesh(found)
						applyBridgeSurfaceStyle(desc, shard)
						hydrated += 1
						continue
					end
				end
				if shard and isEditMode() then
					local em = buildEditableMeshFromShard(shard)
					if em then
						local ok = pcall(function()
							local replacement = AssetService:CreateMeshPartAsync(Content.fromObject(em))
							if replacement and replacement:IsA("MeshPart") then
								desc:ApplyMesh(replacement)
								replacement:Destroy()
							end
						end)
						if ok then
							activeEditableMeshes[desc] = em
							applyBridgeSurfaceStyle(desc, shard)
							hydrated += 1
						end
					end
				end
			end
		end
	end
	return hydrated
end

function HubPathMeshHydrator.BuildHubPaths(parent: Instance, originCF: CFrame): Model
	local existing = parent:FindFirstChild("HubCobblePaths")
	if existing then
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "HubCobblePaths"

	local template = getStudioImportTemplate()
	local corrCF = if template then computeTemplateCorrectionCF(template) else CFrame.identity
	local templatePivot = if template and template:IsA("Model") then template:GetPivot() else CFrame.identity

	for _, shard in ipairs(HubPathMeshData.Shards) do
		if PLOT_BRIDGE_SHARD_SET[shard.partName] then
			-- Cache invisible baked bridge templates inside HubCobblePaths in Edit mode
			-- so BridgeBuilder.Build() can clone them at runtime before FBX import.
			if not template and isEditMode() then
				local bakedBridge = createHydratedMeshPartFromShard(shard, originCF * CFrame.new(0, -30, 0), "_Baked_" .. shard.partName, model)
				if bakedBridge then
					bakedBridge.Transparency = 1
					bakedBridge.CastShadow = false
				end
			end
			continue
		end

		local placed: BasePart? = nil
		if template then
			local found = template:FindFirstChild(shard.partName, true)
			if found and found:IsA("MeshPart") then
				local targetCF = originCF * corrCF * templatePivot:ToObjectSpace(found.CFrame)
				placed = cloneImportedTemplatePart(template, shard.partName, shard, targetCF, shard.name, model)
			end
		end

		if not placed then
			local ctr = shard.center
			local worldCF = originCF * CFrame.new(ctr[1], ctr[2], ctr[3])
			placed = clonePublishedMeshPart(shard, worldCF, shard.name, model)
		end

		if not placed then
			local ctr = shard.center
			local worldCF = originCF * CFrame.new(ctr[1], ctr[2], ctr[3])
			placed = createHydratedMeshPartFromShard(shard, worldCF, shard.name, model)
		end
	end

	model.Parent = parent
	return model
end

function HubPathMeshHydrator.BuildPlotBridgeDeck(parent: Instance, bridgeCF: CFrame, bridgeName: string?): (BasePart?, boolean)
	local baseName = bridgeName or "Hub_PlotBridge"
	local template = getStudioImportTemplate()
	local corrCF = if template then computeTemplateCorrectionCF(template) else CFrame.identity
	local templatePivot = if template and template:IsA("Model") then template:GetPivot() else CFrame.identity

	local bog = Workspace:FindFirstChild("BaseOverhaulGeometry")
	local mc = bog and bog:FindFirstChild("MastersCommons")
	local hcp = mc and mc:FindFirstChild("HubCobblePaths")

	local primaryDeck: BasePart? = nil
	local hasParapets = false

	for _, entry in ipairs(PLOT_BRIDGE_PARTS) do
		local shard = HubPathMeshData.ByPartName[entry.shard]
		if not shard then
			continue
		end

		local visualName = baseName .. entry.suffix
		local placed: BasePart? = nil

		if template then
			local found = template:FindFirstChild(entry.shard, true)
			if found and found:IsA("MeshPart") then
				local relCF = corrCF * templatePivot:ToObjectSpace(found.CFrame)
				local targetCF = bridgeCF * relCF
				placed = cloneImportedTemplatePart(template, entry.shard, shard, targetCF, visualName, parent)
			end
		end

		if not placed then
			local ctr = shard.center
			placed = clonePublishedMeshPart(shard, bridgeCF * CFrame.new(ctr[1], ctr[2], ctr[3]), visualName, parent)
		end

		if not placed then
			local ctr = shard.center
			placed = createHydratedMeshPartFromShard(shard, bridgeCF * CFrame.new(ctr[1], ctr[2], ctr[3]), visualName, parent)
		end

		if not placed and hcp then
			local bakedTemplate = hcp:FindFirstChild("_Baked_" .. entry.shard)
			if bakedTemplate and bakedTemplate:IsA("MeshPart") then
				local ctr = shard.center
				local clone = bakedTemplate:Clone()
				clone:ClearAllChildren()
				clone.Transparency = 0
				applyBridgeSurfaceStyle(clone, shard, visualName)
				clone.CFrame = bridgeCF * CFrame.new(ctr[1], ctr[2], ctr[3])
				clone.Parent = parent
				placed = clone
			end
		end

		if placed then
			if entry.shard == "Hub_PlotBridgeDeck" then
				primaryDeck = placed
			elseif entry.shard == "Hub_PlotBridgeParapets" then
				hasParapets = true
			end
		end
	end

	return primaryDeck, hasParapets
end

return HubPathMeshHydrator
