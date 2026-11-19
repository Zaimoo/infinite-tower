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

-- Strong references so Roblox does not GC EditableMeshes backing live MeshParts.
local activeEditableMeshes: { [Instance]: any } = {}
local activeTemplateMeshes: { [string]: any } = {}

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

local function applyBridgeSurfaceStyle(part: BasePart, name: string?)
	if name then
		part.Name = name
	end
	part.Material = Enum.Material.Cobblestone
	part.MaterialVariant = ""
	part.Color = COBBLE_COLOR
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
	applyBridgeSurfaceStyle(meshPart, displayName or shard.name)
	meshPart.Size = Vector3.new(shard.size[1], shard.size[2], shard.size[3])
	meshPart.CFrame = worldCF
	meshPart:SetAttribute("HubPathShard", shard.partName)
	meshPart.Destroying:Connect(function()
		activeEditableMeshes[meshPart] = nil
	end)
	meshPart.Parent = parent
	return meshPart
end

local function cloneImportedTemplatePart(template: Instance, partName: string, targetCF: CFrame, displayName: string?, parent: Instance): MeshPart?
	local found = template:FindFirstChild(partName, true)
	if not found or not found:IsA("MeshPart") then
		return nil
	end
	local clone = found:Clone()
	clone:ClearAllChildren()
	applyBridgeSurfaceStyle(clone, displayName or partName)
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
				-- Skip if already serialized with valid mesh geometry (Edit-mode bake or published asset)
				if desc.MeshSize.Magnitude > 0.05 then
					activeEditableMeshes[desc] = true
					applyBridgeSurfaceStyle(desc)
					continue
				end
				if template then
					local found = template:FindFirstChild(shardName, true)
					if found and found:IsA("MeshPart") then
						desc:ApplyMesh(found)
						applyBridgeSurfaceStyle(desc)
						hydrated += 1
						continue
					end
				end
				local shard = HubPathMeshData.ByPartName[shardName]
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
							applyBridgeSurfaceStyle(desc)
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
		if shard.partName == "Hub_PlotBridgeDeck" then
			-- Cache an invisible baked bridge template inside HubCobblePaths in Edit mode
			-- so BridgeBuilder.Build() can clone it at runtime when FBX is not yet imported.
			if not template and isEditMode() then
				local bakedBridge = createHydratedMeshPartFromShard(shard, originCF * CFrame.new(0, -25, 0), "_BakedBridgeTemplate", model)
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
				placed = cloneImportedTemplatePart(template, shard.partName, targetCF, shard.name, model)
			end
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

function HubPathMeshHydrator.BuildPlotBridgeDeck(parent: Instance, bridgeCF: CFrame, bridgeName: string?): BasePart?
	local shard = HubPathMeshData.ByPartName["Hub_PlotBridgeDeck"]
	if not shard then
		return nil
	end

	local visualName = if bridgeName then (bridgeName .. "_CobbleMesh") else "Hub_PlotBridgeDeck"
	local template = getStudioImportTemplate()
	if template then
		local found = template:FindFirstChild("Hub_PlotBridgeDeck", true)
		if found and found:IsA("MeshPart") then
			local corrCF = computeTemplateCorrectionCF(template)
			local templatePivot = if template:IsA("Model") then template:GetPivot() else CFrame.identity
			local relCF = corrCF * templatePivot:ToObjectSpace(found.CFrame)
			local targetCF = bridgeCF * relCF.Rotation * CFrame.new(0, relCF.Position.Y, 0)
			return cloneImportedTemplatePart(template, "Hub_PlotBridgeDeck", targetCF, visualName, parent)
		end
	end

	local ctr = shard.center
	local created = createHydratedMeshPartFromShard(shard, bridgeCF * CFrame.new(ctr[1], ctr[2], ctr[3]), visualName, parent)
	if created then
		return created
	end

	-- Runtime fallback before FBX import: clone the baked Edit-mode template kept in MastersCommons.HubCobblePaths
	local bog = Workspace:FindFirstChild("BaseOverhaulGeometry")
	local mc = bog and bog:FindFirstChild("MastersCommons")
	local hcp = mc and mc:FindFirstChild("HubCobblePaths")
	local bakedTemplate = hcp and hcp:FindFirstChild("_BakedBridgeTemplate")
	if bakedTemplate and bakedTemplate:IsA("MeshPart") then
		local clone = bakedTemplate:Clone()
		clone:ClearAllChildren()
		clone.Transparency = 0
		applyBridgeSurfaceStyle(clone, visualName)
		clone.CFrame = bridgeCF * CFrame.new(ctr[1], ctr[2], ctr[3])
		clone.Parent = parent
		return clone
	end

	return nil
end

return HubPathMeshHydrator
