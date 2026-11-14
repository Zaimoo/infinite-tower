--!strict
-- EnvironmentSpawner.luau
-- Integrates Blender-authored hyper-realistic tree, shrub, turf clump, root collar, and ground
-- MaterialVariant PBR assets from ReplicatedStorage.Assets.Environment.
-- Non-destructive before import: preserves existing procedural trees until Blender prefabs are
-- imported into Studio, then seamlessly swaps trees/shrubs, scatters 3D grass turf clumps, and
-- wires MaterialService MaterialVariants for Hub Meadow Grass, Medieval Cobble & Forest Earth.

local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnvironmentSpawner = {}

export type TextureIdSet = {
	ColorMap: string,
	NormalMap: string,
	RoughnessMap: string,
}

-- Optional pre-uploaded / fallback Texture IDs (populated if uploaded via Studio Asset Manager / MCP,
-- or automatically extracted live from imported GroundMaterialsKit SurfaceAppearance instances).
EnvironmentSpawner.DefaultGroundTextures = {
	MeadowGrass = {
		ColorMap = "rbxassetid://85539524323359",
		NormalMap = "rbxassetid://107154517231350",
		RoughnessMap = "rbxassetid://125381403052470",
	} :: TextureIdSet,
	MedievalCobble = {
		ColorMap = "rbxassetid://104460573136154",
		NormalMap = "rbxassetid://135184287474018",
		RoughnessMap = "rbxassetid://105148847003583",
	} :: TextureIdSet,
	ForestEarth = {
		ColorMap = "rbxassetid://94454359439434",
		NormalMap = "rbxassetid://110784451800881",
		RoughnessMap = "rbxassetid://103087013857397",
	} :: TextureIdSet,
}

local EXPECTED_HEIGHTS = {
	HeroOakTree = 17.0,
	HighlandPineTree = 20.6,
	SakuraBlossomTree = 13.0,
	WeepingWillowTree = 15.6,
	WildForestShrub = 2.9,
	GroundProp_MeadowTurfClump = 1.45,
	Ground_MossyRootCollar = 0.85,
}

local warnedEnvMissing = false

local function getEnvFolder(): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		return nil
	end
	local env = assets:FindFirstChild("Environment")
	if env then
		return env
	end
	return nil
end

local function findTemplate(name: string): Instance?
	local env = getEnvFolder()
	if env then
		local direct = env:FindFirstChild(name)
		if direct then
			return direct
		end
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets then
		local fallback = assets:FindFirstChild(name, true)
		if fallback then
			return fallback
		end
	end
	return nil
end

function EnvironmentSpawner.HasTemplate(name: string): boolean
	return findTemplate(name) ~= nil
end

function EnvironmentSpawner.HasAllTreeTemplates(): boolean
	return findTemplate("HeroOakTree") ~= nil
		and findTemplate("HighlandPineTree") ~= nil
		and findTemplate("SakuraBlossomTree") ~= nil
		and findTemplate("WeepingWillowTree") ~= nil
end

function EnvironmentSpawner.WarnIfMissingOnce()
	if not warnedEnvMissing and not EnvironmentSpawner.HasAllTreeTemplates() then
		warnedEnvMissing = true
		warn(
			"[BaseOverhaul] Optional Blender environment prefabs not yet imported under ReplicatedStorage.Assets.Environment; using procedural fallback."
		)
	end
end

local function extractKitTexture(partName: string): TextureIdSet?
	local kit = findTemplate("GroundMaterialsKit")
	local donor: Instance? = if kit then kit:FindFirstChild(partName, true) else findTemplate(partName)
	if not donor then
		return nil
	end
	local sa = if donor:IsA("SurfaceAppearance")
		then donor
		else donor:FindFirstChildWhichIsA("SurfaceAppearance", true)
	if not (sa and sa:IsA("SurfaceAppearance")) then
		return nil
	end
	if sa.ColorMap == "" and sa.NormalMap == "" and sa.RoughnessMap == "" then
		return nil
	end
	return {
		ColorMap = sa.ColorMap,
		NormalMap = sa.NormalMap,
		RoughnessMap = sa.RoughnessMap,
	}
end

local function upsertMaterialVariant(
	variantName: string,
	baseMaterial: Enum.Material,
	studsPerTile: number,
	pattern: Enum.MaterialPattern,
	textures: TextureIdSet?
): boolean
	if not textures or textures.ColorMap == "" then
		return false
	end
	local existing = MaterialService:FindFirstChild(variantName)
	if existing and existing:IsA("MaterialVariant") then
		pcall(function()
			existing.BaseMaterial = baseMaterial
			existing.StudsPerTile = studsPerTile
			existing.MaterialPattern = pattern
			existing.ColorMap = textures.ColorMap
			if textures.NormalMap ~= "" then
				existing.NormalMap = textures.NormalMap
			end
			if textures.RoughnessMap ~= "" then
				existing.RoughnessMap = textures.RoughnessMap
			end
		end)
		return true
	end

	local created: MaterialVariant? = nil
	local ok = pcall(function()
		if existing then
			existing:Destroy()
		end
		local mv = Instance.new("MaterialVariant")
		created = mv
		mv.Name = variantName
		mv.BaseMaterial = baseMaterial
		mv.StudsPerTile = studsPerTile
		mv.MaterialPattern = pattern
		mv.ColorMap = textures.ColorMap
		if textures.NormalMap ~= "" then
			mv.NormalMap = textures.NormalMap
		end
		if textures.RoughnessMap ~= "" then
			mv.RoughnessMap = textures.RoughnessMap
		end
		mv.Parent = MaterialService
	end)
	if not ok then
		if created and created.Parent then
			pcall(function()
				(created :: MaterialVariant):Destroy()
			end)
		end
		return false
	end
	return true
end

-- Creates/updates MaterialService variants from either imported GroundMaterialsKit or DefaultGroundTextures,
-- then applies them to matching terrain & path parts inside targetRoots without affecting small tree props.
function EnvironmentSpawner.ApplyGroundMaterials(targetRoots: { Instance }): boolean
	local grassTex = extractKitTexture("Ground_MeadowGrass") or EnvironmentSpawner.DefaultGroundTextures.MeadowGrass
	local cobbleTex = extractKitTexture("Ground_MedievalCobble") or EnvironmentSpawner.DefaultGroundTextures.MedievalCobble
	local earthTex = extractKitTexture("Ground_ForestEarth") or EnvironmentSpawner.DefaultGroundTextures.ForestEarth

	local hasGrass = upsertMaterialVariant(
		"HubMeadowGrass",
		Enum.Material.Grass,
		10,
		Enum.MaterialPattern.Organic,
		grassTex
	)
	local hasCobble = upsertMaterialVariant(
		"HubMedievalCobble",
		Enum.Material.Cobblestone,
		8,
		Enum.MaterialPattern.Regular,
		cobbleTex
	)
	local hasEarth = upsertMaterialVariant(
		"HubForestEarth",
		Enum.Material.Ground,
		10,
		Enum.MaterialPattern.Organic,
		earthTex
	)

	if not (hasGrass or hasCobble or hasEarth) then
		return false
	end

	for _, root in ipairs(targetRoots) do
		for _, desc in root:GetDescendants() do
			if not desc:IsA("BasePart") or desc:IsA("MeshPart") then
				continue
			end
			local n = desc.Name
			if
				n:find("Canopy", 1, true)
				or n:find("PineTier", 1, true)
				or n:find("PineBough", 1, true)
				or n == "PineTuft"
				or n == "PineApex"
				or n:find("Bush", 1, true)
				or n == "BedShrub"
				or n == "FlowerBed"
				or n == "BoulderMoss"
				or n:find("Willow", 1, true)
				or n == "LilyPad"
			then
				continue
			end

			local mat = desc.Material
			if hasGrass and (mat == Enum.Material.Grass or mat == Enum.Material.LeafyGrass) then
				desc.Material = Enum.Material.Grass
				desc.MaterialVariant = "HubMeadowGrass"
				-- Neutralize strong vertex color tint so PBR ground albedo reads crisply
				desc.Color = Color3.fromRGB(232, 238, 224)
			elseif hasCobble and mat == Enum.Material.Cobblestone then
				desc.MaterialVariant = "HubMedievalCobble"
				desc.Color = Color3.fromRGB(224, 224, 220)
			elseif hasEarth and mat == Enum.Material.Ground then
				desc.MaterialVariant = "HubForestEarth"
				desc.Color = Color3.fromRGB(228, 218, 206)
			end
		end
	end

	return true
end

local function wrapAsModel(cloned: Instance, name: string): Model
	if cloned:IsA("Model") then
		cloned.Name = name
		return cloned
	end
	local m = Instance.new("Model")
	m.Name = name
	if cloned:IsA("BasePart") then
		cloned.Parent = m
		m.PrimaryPart = cloned
	else
		for _, ch in cloned:GetChildren() do
			ch.Parent = m
		end
		cloned:Destroy()
	end
	return m
end

local function configureFoliageMeshPart(part: BasePart, isFoliage: boolean, isTurf: boolean, tintColor: Color3?)
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanTouch = false

	if isFoliage or isTurf then
		part.CanCollide = false
		part.CanQuery = false
		part.Massless = true
		part.CastShadow = not isTurf
		if part:IsA("MeshPart") then
			part.DoubleSided = true
		end
		part.Material = Enum.Material.Grass
	else
		part.CanCollide = not (part.Name:find("Collar", 1, true) ~= nil)
		part.CanQuery = part.CanCollide
		part.Massless = not part.CanCollide
		part.CastShadow = not (part.Name:find("Collar", 1, true) ~= nil)
		part.Material = if part.Name:find("Collar", 1, true) ~= nil
			then Enum.Material.Ground
			else Enum.Material.Wood
	end

	local sa = part:FindFirstChildWhichIsA("SurfaceAppearance", true)
	if sa and sa:IsA("SurfaceAppearance") then
		sa.AlphaMode = Enum.AlphaMode.Opaque
		if (isFoliage or isTurf) and tintColor then
			sa.Color = tintColor
		end
	elseif (isFoliage or isTurf) and tintColor then
		part.Color = tintColor
	end
end

local function spawnPrefabModel(
	templateName: string,
	parent: Instance,
	baseCFrame: CFrame,
	scale: number,
	yaw: number,
	expectedHeight: number?,
	tintColor: Color3?,
	embedDepth: number?
): Model?
	local template = findTemplate(templateName)
	if not template then
		return nil
	end

	local model = wrapAsModel(template:Clone(), templateName)
	model.PrimaryPart = nil

	local minX, maxX = math.huge, -math.huge
	local minY, maxY = math.huge, -math.huge
	local minZ, maxZ = math.huge, -math.huge
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") then
			-- Strip FBX importer PivotOffset rotations before ScaleTo/PivotTo so upright parts stay upright
			desc.PivotOffset = CFrame.identity
			local n = desc.Name
			local isFol = n:find("Foliage", 1, true) ~= nil
			local isTurf = n:find("Turf", 1, true) ~= nil
			configureFoliageMeshPart(desc, isFol, isTurf, tintColor)
			local half = desc.Size * 0.5
			local pMin = desc.Position - half
			local pMax = desc.Position + half
			minX = math.min(minX, pMin.X)
			maxX = math.max(maxX, pMax.X)
			minY = math.min(minY, pMin.Y)
			maxY = math.max(maxY, pMax.Y)
			minZ = math.min(minZ, pMin.Z)
			maxZ = math.max(maxZ, pMax.Z)
		end
	end

	if maxY > minY then
		model.WorldPivot = CFrame.new((minX + maxX) * 0.5, minY, (minZ + maxZ) * 0.5)
	else
		model.WorldPivot = CFrame.new(model:GetPivot().Position)
	end

	local rawHeight = if maxY > minY then (maxY - minY) else (expectedHeight or 10)
	local baseNorm = if expectedHeight and rawHeight > 0.1 then (expectedHeight / rawHeight) else 1
	local finalScale = math.clamp(baseNorm * scale, 0.05, 8.0)
	pcall(function()
		model:ScaleTo(finalScale)
	end)

	-- Recompute minY after ScaleTo relative to current model pivot
	local curPivot = model:GetPivot()
	local lowestOffset = math.huge
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") then
			local localBottom = (curPivot:Inverse() * desc.CFrame).Position.Y - desc.Size.Y * 0.5
			if localBottom < lowestOffset then
				lowestOffset = localBottom
			end
		end
	end
	if lowestOffset == math.huge then
		lowestOffset = 0
	end

	local sink = embedDepth or 0.18
	local worldCF = baseCFrame * CFrame.Angles(0, yaw, 0) * CFrame.new(0, -lowestOffset - sink, 0)
	model:PivotTo(worldCF)
	model:SetAttribute("BlenderEnvAsset", templateName)
	model.Parent = parent
	return model
end

function EnvironmentSpawner.SpawnRootCollar(parent: Instance, baseCFrame: CFrame, scale: number, yaw: number): BasePart?
	local collarTpl = findTemplate("Ground_MossyRootCollar")
	if not collarTpl then
		local kit = findTemplate("GroundMaterialsKit")
		collarTpl = if kit then kit:FindFirstChild("Ground_MossyRootCollar", true) else nil
	end
	if not (collarTpl and collarTpl:IsA("BasePart")) then
		return nil
	end
	local clone = collarTpl:Clone()
	configureFoliageMeshPart(clone, false, false, nil)
	clone.Size = clone.Size * scale
	clone.CFrame = baseCFrame * CFrame.Angles(0, yaw, 0) * CFrame.new(0, clone.Size.Y * 0.22, 0)
	clone:SetAttribute("BlenderEnvAsset", "Ground_MossyRootCollar")
	clone.Parent = parent
	return clone
end

function EnvironmentSpawner.SpawnTurfClump(
	parent: Instance,
	baseCFrame: CFrame,
	scale: number?,
	rng: Random?
): Model?
	local r = rng or Random.new()
	local s = (scale or 1) * r:NextNumber(0.78, 1.24)
	local yaw = r:NextNumber(0, math.tau)
	return spawnPrefabModel(
		"GroundProp_MeadowTurfClump",
		parent,
		baseCFrame,
		s,
		yaw,
		EXPECTED_HEIGHTS.GroundProp_MeadowTurfClump,
		nil,
		0.10
	)
end

export type PondPlacementSpec = {
	template: string,
	offset: Vector3,
	yaw: number,
	scale: number,
	modelName: string,
}

local HUB_POND_SPECS: { PondPlacementSpec } = {
	{
		template = "WaterfallBoulderPond",
		offset = Vector3.new(116, 0, -176),
		yaw = math.rad(147),
		scale = 1.0,
		modelName = "WaterfallBoulderPond",
	},
	{
		template = "RockeryKoiPond",
		offset = Vector3.new(-52, 0, 234),
		yaw = math.rad(-35),
		scale = 1.0,
		modelName = "RockeryKoiPond",
	},
	{
		template = "SteppingStreamPond",
		offset = Vector3.new(157, 0, 43),
		yaw = math.rad(-24),
		scale = 1.0,
		modelName = "SteppingStreamPond",
	},
}

function EnvironmentSpawner.GetHubPondSpecs(): { PondPlacementSpec }
	return HUB_POND_SPECS
end

local function configurePondPart(part: BasePart)
	part.Anchored = true
	part.PivotOffset = CFrame.identity
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	local cleanName = (part.Name:gsub("%.%d+$", ""))
	part.Name = cleanName

	local isSolid = (
		cleanName == "Pond_BridgeDeck"
		or cleanName == "Pond_BridgeRails"
		or cleanName == "Pond_Rocks"
		or cleanName == "Pond_Bed"
	)

	if isSolid then
		part.CanCollide = true
		part.CanQuery = true
		part.CanTouch = true
		part.CastShadow = true
		part.Material = Enum.Material.Slate
	else
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = (cleanName == "Pond_Flora")
		if cleanName == "Pond_Flora" then
			part.Material = Enum.Material.Grass
		else
			part.Material = Enum.Material.SmoothPlastic
		end
	end

	local sa = part:FindFirstChildWhichIsA("SurfaceAppearance", true)
	if sa and sa:IsA("SurfaceAppearance") then
		if cleanName == "Pond_Water" or cleanName == "Pond_Waterfall" then
			pcall(function()
				sa.AlphaMode = Enum.AlphaMode.Transparency
			end)
		else
			pcall(function()
				sa.AlphaMode = Enum.AlphaMode.Overlay
			end)
		end
	end
end

function EnvironmentSpawner.SpawnPond(
	templateName: string,
	parent: Instance,
	baseCFrame: CFrame,
	scale: number?,
	yaw: number?,
	modelName: string?
): Model?
	local template = findTemplate(templateName)
	if not template then
		return nil
	end

	local model = wrapAsModel(template:Clone(), modelName or templateName)
	model.PrimaryPart = nil

	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") then
			configurePondPart(desc)
		end
	end

	local finalScale = math.clamp(scale or 1.0, 0.25, 4.0)
	if math.abs(finalScale - 1.0) > 0.001 then
		pcall(function()
			model:ScaleTo(finalScale)
		end)
	end

	model:PivotTo(baseCFrame * CFrame.Angles(0, yaw or 0, 0))
	model:SetAttribute("BlenderEnvAsset", templateName)
	model.Parent = parent
	return model
end

local function scatterRootTurf(parent: Instance, baseCFrame: CFrame, radius: number, count: number, rng: Random)
	if not EnvironmentSpawner.HasTemplate("GroundProp_MeadowTurfClump") then
		return
	end
	for i = 1, count do
		local ang = (i / count) * math.tau + rng:NextNumber(-0.45, 0.45)
		local dist = rng:NextNumber(radius * 0.55, radius * 1.15)
		local offset = CFrame.new(math.cos(ang) * dist, 0, math.sin(ang) * dist)
		EnvironmentSpawner.SpawnTurfClump(parent, baseCFrame * offset, rng:NextNumber(0.75, 1.15), rng)
	end
end

function EnvironmentSpawner.SpawnOak(
	parent: Instance,
	baseCFrame: CFrame,
	scale: number?,
	rng: Random?
): Model?
	local r = rng or Random.new()
	local s = scale or r:NextNumber(0.92, 1.20)
	local yaw = r:NextNumber(0, math.tau)
	local m = spawnPrefabModel("HeroOakTree", parent, baseCFrame, s, yaw, EXPECTED_HEIGHTS.HeroOakTree, nil, 0.38)
	if m then
		EnvironmentSpawner.SpawnRootCollar(m, baseCFrame, s * 0.95, yaw)
		scatterRootTurf(m, baseCFrame, 3.2 * s, 3, r)
	end
	return m
end

function EnvironmentSpawner.SpawnPine(
	parent: Instance,
	baseCFrame: CFrame,
	scale: number?,
	rng: Random?
): Model?
	local r = rng or Random.new()
	local s = scale or r:NextNumber(0.88, 1.24)
	local yaw = r:NextNumber(0, math.tau)
	local m = spawnPrefabModel("HighlandPineTree", parent, baseCFrame, s, yaw, EXPECTED_HEIGHTS.HighlandPineTree, nil, 0.35)
	if m then
		EnvironmentSpawner.SpawnRootCollar(m, baseCFrame, s * 0.78, yaw)
		scatterRootTurf(m, baseCFrame, 2.6 * s, 2, r)
	end
	return m
end

function EnvironmentSpawner.SpawnSakura(
	parent: Instance,
	baseCFrame: CFrame,
	scale: number?,
	blossomColor: Color3?,
	rng: Random?
): Model?
	local r = rng or Random.new()
	local s = scale or r:NextNumber(0.90, 1.15)
	local yaw = r:NextNumber(0, math.tau)
	local tint = blossomColor or Color3.fromRGB(255, 186, 204)
	local m = spawnPrefabModel(
		"SakuraBlossomTree",
		parent,
		baseCFrame,
		s,
		yaw,
		EXPECTED_HEIGHTS.SakuraBlossomTree,
		tint,
		0.32
	)
	if m then
		EnvironmentSpawner.SpawnRootCollar(m, baseCFrame, s * 0.85, yaw)
		scatterRootTurf(m, baseCFrame, 2.8 * s, 3, r)
	end
	return m
end

function EnvironmentSpawner.SpawnWillow(
	parent: Instance,
	baseCFrame: CFrame,
	scale: number?,
	rng: Random?
): Model?
	local r = rng or Random.new()
	local s = scale or r:NextNumber(0.95, 1.25)
	local yaw = r:NextNumber(0, math.tau)
	local m = spawnPrefabModel(
		"WeepingWillowTree",
		parent,
		baseCFrame,
		s,
		yaw,
		EXPECTED_HEIGHTS.WeepingWillowTree,
		nil,
		0.28
	)
	if m then
		EnvironmentSpawner.SpawnRootCollar(m, baseCFrame, s * 0.92, yaw)
		scatterRootTurf(m, baseCFrame, 3.0 * s, 3, r)
	end
	return m
end

function EnvironmentSpawner.SpawnShrub(
	parent: Instance,
	baseCFrame: CFrame,
	scale: number?,
	rng: Random?
): Model?
	local r = rng or Random.new()
	local s = scale or r:NextNumber(0.85, 1.20)
	local yaw = r:NextNumber(0, math.tau)
	return spawnPrefabModel("WildForestShrub", parent, baseCFrame, s, yaw, EXPECTED_HEIGHTS.WildForestShrub, nil, 0.14)
end

local function isTreeCanopyName(name: string): boolean
	return name:find("OakCanopy_", 1, true) ~= nil
		or name:find("OakLimb_", 1, true) ~= nil
		or name:find("OakCanopyCluster_", 1, true) ~= nil
		or name:find("PineTier_", 1, true) ~= nil
		or name:find("BlossomCanopy_", 1, true) ~= nil
		or name:find("WillowCanopy_", 1, true) ~= nil
		or name:find("WillowFrond", 1, true) ~= nil
		or name:find("PineFoliage", 1, true) ~= nil
		or name:find("OakFoliage", 1, true) ~= nil
		or name:find("PineRoot", 1, true) ~= nil
		or name:find("PineTrunkUpper", 1, true) ~= nil
		or name:find("PineBoughDisk_", 1, true) ~= nil
		or name:find("PineTuft", 1, true) ~= nil
		or name:find("PineApex", 1, true) ~= nil
		or name:find("PineNeedle", 1, true) ~= nil
		or name:find("BushLobe", 1, true) ~= nil
		or name:find("BushBerry", 1, true) ~= nil
end

local function isOutskirtsPinePartName(name: string): boolean
	return name == "PineTrunkUpper"
		or name == "PineRoot"
		or name == "PineTuft"
		or name == "PineApex"
		or name:find("PineBoughDisk_", 1, true) ~= nil
end

local function getTrunkBaseAndScale(part: BasePart, kind: string): (Vector3, number)
	if part.Name == "PineTrunkLower" then
		-- Outskirts pines use a rotated cylinder whose Size.X is (trunkH * 0.58)
		local trunkH = part.Size.X / 0.58
		local basePos = part.Position - Vector3.new(0, trunkH * 0.28, 0)
		return basePos, math.clamp(trunkH / 18.0, 0.75, 1.40)
	elseif part.Name == "OakTrunk" and part:IsA("Part") and part.Shape == Enum.PartType.Cylinder then
		local trunkH = part.Size.X / 0.9
		local basePos = part.Position - Vector3.new(0, trunkH * 0.45, 0)
		return basePos, math.clamp(trunkH / 14.0, 0.85, 1.35)
	end
	local basePos = part.Position - Vector3.new(0, part.Size.Y * 0.5, 0)
	local scale = if kind == "Oak"
		then math.clamp(part.Size.Y / 9.0, 0.85, 1.30)
		elseif kind == "Pine" then math.clamp(part.Size.Y / 6.0, 0.85, 1.35)
		elseif kind == "Willow" then math.clamp(part.Size.Y / 11.0, 0.85, 1.45)
		else math.clamp(part.Size.Y / 7.0, 0.85, 1.20)
	return basePos, scale
end

-- Non-destructively upgrades any previously baked primitive trees/shrubs/grass in a Hub or
-- Plot tree container once the Blender assets are imported into ReplicatedStorage.Assets.Environment.
function EnvironmentSpawner.UpgradeExistingScene(roots: { Instance }): number
	local upgraded = 0
	local rng = Random.new(404)

	local hasOak = EnvironmentSpawner.HasTemplate("HeroOakTree")
	local hasPine = EnvironmentSpawner.HasTemplate("HighlandPineTree")
	local hasSakura = EnvironmentSpawner.HasTemplate("SakuraBlossomTree")
	local hasWillow = EnvironmentSpawner.HasTemplate("WeepingWillowTree")
	local hasShrub = EnvironmentSpawner.HasTemplate("WildForestShrub")

	if hasOak or hasPine or hasSakura or hasWillow or hasShrub then
		type Replacement = {
			parent: Instance,
			kind: string,
			cf: CFrame,
			scale: number,
			tint: Color3?,
			toDestroy: { Instance },
		}
		local replacements: { Replacement } = {}
		local claimed: { [Instance]: boolean } = {}

		for _, root in ipairs(roots) do
			local descs = root:GetDescendants()
			-- 1. Model-grouped wilderness trees/bushes from OutskirtsEnvironmentBuilder
			for _, desc in ipairs(descs) do
				if desc:IsA("Model") and desc:GetAttribute("BlenderEnvAsset") == nil then
					local n = desc.Name
					local kind: string? = nil
					if hasPine and n == "HighlandPine" then
						kind = "Pine"
					elseif hasOak and n == "WildernessOak" then
						kind = "Oak"
					elseif hasShrub and n == "WildBush" then
						kind = "Shrub"
					end
					if kind then
						local attrPos = desc:GetAttribute("EnvBasePos")
						local attrScale = desc:GetAttribute("EnvScale")
						local basePos: Vector3? = if typeof(attrPos) == "Vector3" then attrPos else nil
						local scale: number = if typeof(attrScale) == "number" then attrScale else 1.0
						if not basePos then
							local trunk = desc:FindFirstChild("PineTrunkLower")
								or desc:FindFirstChild("OakTrunk")
								or desc:FindFirstChild("BushLobe")
								or desc:FindFirstChildWhichIsA("BasePart")
							if trunk and trunk:IsA("BasePart") then
								if kind == "Shrub" and trunk.Name == "BushLobe" then
									basePos = trunk.Position - Vector3.new(0, trunk.Size.Y / 3.0, 0)
									scale = math.clamp(trunk.Size.Y / 3.6, 0.75, 1.35)
								else
									basePos, scale = getTrunkBaseAndScale(trunk, kind)
								end
							end
						end
						if basePos then
							table.insert(replacements, {
								parent = desc.Parent :: Instance,
								kind = kind,
								cf = CFrame.new(basePos),
								scale = scale,
								tint = nil,
								toDestroy = { desc },
							})
						end
					end
				end
			end

			-- 2a. OutskirtsEnvironmentBuilder flat HighlandPine parts: assign accessories to nearest PineTrunkLower
			if hasPine then
				local byParent: { [Instance]: { { part: BasePart, basePos: Vector3, rep: Replacement } } } = {}
				for _, desc in ipairs(descs) do
					if desc:IsA("BasePart") and desc.Parent and not desc.Parent:IsA("Model") and desc.Name == "PineTrunkLower" and not desc:FindFirstAncestor("BackgroundFloatingIslets") then
						local basePos, scale = getTrunkBaseAndScale(desc, "Pine")
						local rep: Replacement = {
							parent = desc.Parent,
							kind = "Pine",
							cf = CFrame.new(basePos),
							scale = scale,
							tint = nil,
							toDestroy = { desc },
						}
						claimed[desc] = true
						table.insert(replacements, rep)
						local list = byParent[desc.Parent]
						if not list then
							list = {}
							byParent[desc.Parent] = list
						end
						table.insert(list, { part = desc, basePos = basePos, rep = rep })
					end
				end
				for parentInst, trunks in pairs(byParent) do
					for _, sib in ipairs(parentInst:GetChildren()) do
						if not claimed[sib] and sib:IsA("BasePart") and isOutskirtsPinePartName(sib.Name) then
							local bestDistSq = 196 -- 14 studs max horizontal reach from nearest pine trunk
							local bestTrunk = nil
							for _, entry in ipairs(trunks) do
								local dx = sib.Position.X - entry.basePos.X
								local dz = sib.Position.Z - entry.basePos.Z
								local dy = sib.Position.Y - entry.basePos.Y
								local dSq = dx * dx + dz * dz
								if dSq < bestDistSq and dy >= -6 and dy <= 38 then
									bestDistSq = dSq
									bestTrunk = entry
								end
							end
							if bestTrunk then
								claimed[sib] = true
								table.insert(bestTrunk.rep.toDestroy, sib)
							end
						end
					end
				end
			end

			-- 2b. Flat part lists in CloisterBuilder (OakTrunk, PineTrunk, BlossomTrunk, BedShrub)
			--     and Outskirts flat BushLobe/BushBerry clusters
			for _, desc in ipairs(descs) do
				if not claimed[desc] and desc:IsA("BasePart") and desc.Parent and not desc.Parent:IsA("Model") and not desc:FindFirstAncestor("BackgroundFloatingIslets") then
					local n = desc.Name
					if
						(n == "OakTrunk" and hasOak)
						or (n == "PineTrunk" and hasPine)
						or (n == "BlossomTrunk" and hasSakura)
						or (n == "WillowTrunk" and hasWillow)
					then
						local kind = if n == "OakTrunk"
							then "Oak"
							elseif n == "PineTrunk" then "Pine"
							elseif n == "BlossomTrunk" then "Sakura"
							else "Willow"
						local basePos, scale = getTrunkBaseAndScale(desc, kind)
						local toDestroy: { Instance } = { desc }
						claimed[desc] = true
						local tint: Color3? = nil
						local maxReachSq = if n == "OakTrunk" and desc:IsA("Part") and desc.Shape == Enum.PartType.Cylinder
							then 225
							elseif kind == "Willow" then 121
							else 64
						for _, sib in desc.Parent:GetChildren() do
							if not claimed[sib] and sib ~= desc and sib:IsA("BasePart") and isTreeCanopyName(sib.Name) then
								local dx = sib.Position.X - basePos.X
								local dz = sib.Position.Z - basePos.Z
								local dy = sib.Position.Y - basePos.Y
								if (dx * dx + dz * dz) < maxReachSq and dy >= -4 and dy <= 34 then
									if kind == "Sakura" and not tint then
										tint = sib.Color
									end
									claimed[sib] = true
									table.insert(toDestroy, sib)
								end
							end
						end
						table.insert(replacements, {
							parent = desc.Parent,
							kind = kind,
							cf = CFrame.new(basePos),
							scale = scale,
							tint = tint,
							toDestroy = toDestroy,
						})
					elseif n == "BedShrub" and hasShrub then
						claimed[desc] = true
						local basePos = desc.Position - Vector3.new(0, desc.Size.Y * 0.21, 0)
						table.insert(replacements, {
							parent = desc.Parent,
							kind = "Shrub",
							cf = CFrame.new(basePos),
							scale = math.clamp(desc.Size.Y / 3.2, 0.8, 1.25),
							tint = nil,
							toDestroy = { desc },
						})
					elseif n == "BushLobe" and hasShrub then
						-- Cluster adjacent BushLobe / BushBerry parts belonging to one Outskirts bush
						local cluster: { BasePart } = { desc }
						claimed[desc] = true
						local queueIdx = 1
						local sibs = desc.Parent:GetChildren()
						while queueIdx <= #cluster do
							local cur = cluster[queueIdx]
							queueIdx += 1
							for _, sib in ipairs(sibs) do
								if not claimed[sib] and sib:IsA("BasePart") and (sib.Name == "BushLobe" or sib.Name == "BushBerry") then
									if (sib.Position - cur.Position).Magnitude <= 4.2 then
										claimed[sib] = true
										table.insert(cluster, sib)
									end
								end
							end
						end
						local mainLobe = desc
						for _, part in ipairs(cluster) do
							if part.Name == "BushLobe" and part.Size.Y > mainLobe.Size.Y then
								mainLobe = part
							end
						end
						local basePos = mainLobe.Position - Vector3.new(0, mainLobe.Size.Y / 3.0, 0)
						local toDestroy: { Instance } = {}
						for _, part in ipairs(cluster) do
							table.insert(toDestroy, part)
						end
						table.insert(replacements, {
							parent = desc.Parent,
							kind = "Shrub",
							cf = CFrame.new(basePos),
							scale = math.clamp(mainLobe.Size.Y / 3.6, 0.75, 1.35),
							tint = nil,
							toDestroy = toDestroy,
						})
					end
				end
			end
		end

		for _, rep in ipairs(replacements) do
			local spawned: Model? = nil
			if rep.kind == "Oak" then
				spawned = EnvironmentSpawner.SpawnOak(rep.parent, rep.cf, rep.scale, rng)
			elseif rep.kind == "Pine" then
				spawned = EnvironmentSpawner.SpawnPine(rep.parent, rep.cf, rep.scale, rng)
			elseif rep.kind == "Sakura" then
				spawned = EnvironmentSpawner.SpawnSakura(rep.parent, rep.cf, rep.scale, rep.tint, rng)
			elseif rep.kind == "Willow" then
				spawned = EnvironmentSpawner.SpawnWillow(rep.parent, rep.cf, rep.scale, rng)
			elseif rep.kind == "Shrub" then
				spawned = EnvironmentSpawner.SpawnShrub(rep.parent, rep.cf, rep.scale, rng)
			end
			if spawned then
				for _, oldInst in ipairs(rep.toDestroy) do
					if oldInst.Parent then
						oldInst:Destroy()
					end
				end
				upgraded += 1
			end
		end
	end

	local hasHeroPond = EnvironmentSpawner.HasTemplate("HeroBridgePond")
	if hasHeroPond then
		local LEGACY_POOL_PARTS: { [string]: boolean } = {
			PoolFloor = true,
			PoolWater = true,
			Coping = true,
			FootbridgeDecl = true,
			FootbridgeDeck = true,
			FootbridgeRamp = true,
			FootbridgeRail = true,
			FootbridgePost = true,
			SteppingStone = true,
			LilyPad = true,
			LilyFlower = true,
		}
		for _, root in ipairs(roots) do
			local commons = if root.Name == "MastersCommons"
				then root
				else root:FindFirstChild("MastersCommons", true)
			if commons then
				local surf = commons:FindFirstChild("CommonsSurface", true)
				local surfTopY = if surf and surf:IsA("BasePart")
					then (surf.Position.Y + surf.Size.Y * 0.5)
					else 12.0
				local poolFolder = commons:FindFirstChild("ReflectingPool")
				if poolFolder then
					local alreadyUpgraded = false
					for _, ch in poolFolder:GetChildren() do
						if ch:GetAttribute("BlenderEnvAsset") == "HeroBridgePond" then
							alreadyUpgraded = true
							break
						end
					end
					if not alreadyUpgraded then
						local centerPos: Vector3? = nil
						local waterPart = poolFolder:FindFirstChild("PoolWater") or poolFolder:FindFirstChild("PoolFloor")
						if waterPart and waterPart:IsA("BasePart") then
							centerPos = Vector3.new(waterPart.Position.X, surfTopY, waterPart.Position.Z)
						elseif surf and surf:IsA("BasePart") then
							centerPos = Vector3.new(surf.Position.X, surfTopY, surf.Position.Z - 160)
						end
						-- Destroy only primitive pool/bridge pieces, preserving upgraded WeepingWillowTrees
						for _, ch in poolFolder:GetChildren() do
							local isWillow = ch:GetAttribute("BlenderEnvAsset") == "WeepingWillowTree"
								or ch.Name:find("Willow", 1, true) ~= nil
							if not isWillow and (LEGACY_POOL_PARTS[ch.Name] or ch:GetAttribute("BlenderEnvAsset") == nil) then
								ch:Destroy()
							end
						end
						if centerPos then
							EnvironmentSpawner.SpawnPond("HeroBridgePond", poolFolder, CFrame.new(centerPos), 1.0, 0, "HeroBridgePond")
							upgraded += 1
						end
					end
				end
			end
		end
	end

	for _, root in ipairs(roots) do
		local commons = if root.Name == "MastersCommons"
			then root
			else root:FindFirstChild("MastersCommons", true)
		if commons then
			local surf = commons:FindFirstChild("CommonsSurface", true)
			if surf and surf:IsA("BasePart") then
				local surfTopY = surf.Position.Y + surf.Size.Y * 0.5
				local hubBase = Vector3.new(surf.Position.X, surfTopY, surf.Position.Z)
				local pondsFolder = commons:FindFirstChild("NaturalPonds")
				for _, spec in ipairs(HUB_POND_SPECS) do
					if EnvironmentSpawner.HasTemplate(spec.template) then
						local alreadyExists = false
						for _, desc in commons:GetDescendants() do
							if desc:GetAttribute("BlenderEnvAsset") == spec.template then
								alreadyExists = true
								break
							end
						end
						if not alreadyExists then
							if not pondsFolder then
								local nf = Instance.new("Folder")
								nf.Name = "NaturalPonds"
								nf.Parent = commons
								pondsFolder = nf
							end
							local pondCF = CFrame.new(hubBase + spec.offset)
							EnvironmentSpawner.SpawnPond(spec.template, pondsFolder :: Instance, pondCF, spec.scale, spec.yaw, spec.modelName)
							upgraded += 1
						end
					end
				end
			end
		end
	end

	EnvironmentSpawner.ApplyGroundMaterials(roots)

	if EnvironmentSpawner.HasTemplate("GroundProp_MeadowTurfClump") then
		for _, root in ipairs(roots) do
			local commons = if root.Name == "MastersCommons"
				then root
				else root:FindFirstChild("MastersCommons", true)
			if commons and commons:FindFirstChild("CloisterTurfScatter") == nil then
				local surf = commons:FindFirstChild("CommonsSurface", true)
				if surf and surf:IsA("BasePart") then
					local surfTopY = surf.Position.Y + surf.Size.Y * 0.5
					local scatterFolder = Instance.new("Folder")
					scatterFolder.Name = "CloisterTurfScatter"
					scatterFolder.Parent = commons
					local tRng = Random.new(909)
					for _, desc in commons:GetDescendants() do
						if desc:IsA("BasePart") and desc.Name == "GardenPath" then
							local pathLen = math.max(desc.Size.X, desc.Size.Z)
							local pathWid = math.min(desc.Size.X, desc.Size.Z)
							if pathLen > 14 and pathWid <= 24 then
								local alongX = desc.Size.X >= desc.Size.Z
								for k = 1, 3 do
									local sideSign = if (k % 2 == 0) then 1 else -1
									local along = tRng:NextNumber(-pathLen * 0.40, pathLen * 0.40)
									local lateral = sideSign * (pathWid * 0.5 + tRng:NextNumber(1.6, 5.2))
									local localOff = if alongX
										then Vector3.new(along, 0, lateral)
										else Vector3.new(lateral, 0, along)
									local wp = (desc.CFrame * CFrame.new(localOff)).Position
									local turfCF = CFrame.new(wp.X, surfTopY, wp.Z)
									EnvironmentSpawner.SpawnTurfClump(scatterFolder, turfCF, tRng:NextNumber(0.85, 1.20), tRng)
								end
							end
						end
					end
				end
			end
		end
	end

	return upgraded
end

return EnvironmentSpawner
