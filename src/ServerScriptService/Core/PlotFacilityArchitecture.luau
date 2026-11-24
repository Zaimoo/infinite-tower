--!strict
-- ServerScriptService/Core/PlotFacilityArchitecture.luau
-- Waiting Room Plot Island Redesign (Phase 2):
-- Builds high-detail gothic fortress courtyard facilities & registers standardized prefabs under
-- ReplicatedStorage.Assets.PlotFacilities with ground-level PrimaryPart and PromptAnchor attachments:
--   1. SummoningPortal    (Monumental Circular Stone Stargate with #22D3EE cyan runes & light beam)
--   2. LeaderboardBoard   (Recessed #0D0912 Obsidian Wall Board with #FACC15 gold neon trim)
--   3. MarketCluster      (3-Stall Curved Merchant Bazaar with Striped/Draped Awnings, Flagstones, Clutter & Lanterns)
--   4. SynthesisChamber   (Cylindrical Gothic Stone Rotunda with cyan barrier arch & #C084FC purple oculus plume)
--   5. BlacksmithForge    (Open-Air Stone Hearth & Chimney against Dividing Wall, anvil sparks, coal, trough)
--   6. TrainingArea       (Polygonal Split-Rail Courtyard with V-Gable Archway, 5 Dummies & 2 Bullseyes)
--   7. GuardpostOutskirts (Timber Palisade Watch-Post, slatted roof, stone-ringed campfire & log seating)
--   8. CommandPost        (War Banner & Architect's Table for Squad Management & Fortress Tree)

local AssetService = game:GetService("AssetService")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SynthesisChamberBuilder = require(script.Parent:WaitForChild("SynthesisChamberBuilder"))

local Arch = {}

local V = Vector3.new

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	canCollide: boolean?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	local collide = if canCollide ~= nil then canCollide else false
	p.CanCollide = collide
	p.CanTouch = false
	p.CanQuery = collide
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function wedge(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	canCollide: boolean?
): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = material or Enum.Material.SmoothPlastic
	w.Anchored = true
	local collide = if canCollide ~= nil then canCollide else false
	w.CanCollide = collide
	w.CanTouch = false
	w.CanQuery = collide
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Parent = parent
	return w
end

local function cylinder(
	parent: Instance,
	name: string,
	radius: number,
	height: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	canCollide: boolean?
): Part
	local p = part(
		parent,
		name,
		V(height, radius * 2, radius * 2),
		cf * CFrame.Angles(0, 0, math.pi / 2),
		color,
		material,
		canCollide
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function sphere(
	parent: Instance,
	name: string,
	diameter: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = part(parent, name, V(diameter, diameter, diameter), cf, color, material, false)
	p.Shape = Enum.PartType.Ball
	return p
end

local function pointLight(parent: Instance, color: Color3, brightness: number, range: number, shadows: boolean?): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = if shadows ~= nil then shadows else false
	l.Parent = parent
	return l
end

local function addBarrel(parent: Instance, cf: CFrame, scale: number?)
	local s = scale or 1
	local body = cylinder(
		parent,
		"WoodenBarrel",
		1.35 * s,
		3.2 * s,
		cf * CFrame.new(0, 1.6 * s, 0),
		Color3.fromRGB(112, 76, 46),
		Enum.Material.WoodPlanks,
		true
	)
	for _, dy in ipairs({ -0.9 * s, 0.9 * s }) do
		cylinder(
			parent,
			"BarrelHoop",
			1.42 * s,
			0.25 * s,
			cf * CFrame.new(0, 1.6 * s + dy, 0),
			Color3.fromRGB(42, 44, 50),
			Enum.Material.Metal,
			false
		)
	end
	return body
end

local function addWeaponRack(parent: Instance, cf: CFrame)
	local wood = Color3.fromRGB(98, 66, 40)
	local iron = Color3.fromRGB(168, 174, 186)
	local darkIron = Color3.fromRGB(48, 52, 60)
	for _, sx in ipairs({ -2.4, 2.4 }) do
		part(parent, "RackUpright", V(0.5, 4.6, 0.5), cf * CFrame.new(sx, 2.3, 0), wood, Enum.Material.Wood, true)
		part(parent, "RackFoot", V(0.6, 0.4, 2.2), cf * CFrame.new(sx, 0.2, 0), wood, Enum.Material.Wood, true)
	end
	part(parent, "RackCrossbarTop", V(5.4, 0.4, 0.5), cf * CFrame.new(0, 3.8, 0), wood, Enum.Material.Wood, true)
	part(parent, "RackCrossbarLow", V(5.4, 0.4, 0.5), cf * CFrame.new(0, 1.4, 0), wood, Enum.Material.Wood, true)
	for i = -2, 2 do
		local x = i * 0.95
		part(
			parent,
			"RackBlade_" .. i,
			V(0.22, 4.0, 0.45),
			cf * CFrame.new(x, 2.6, 0.15) * CFrame.Angles(math.rad(-8), 0, 0),
			iron,
			Enum.Material.Metal,
			false
		)
		part(
			parent,
			"RackGuard_" .. i,
			V(0.9, 0.22, 0.35),
			cf * CFrame.new(x, 1.2, 0.25),
			darkIron,
			Enum.Material.Metal,
			false
		)
	end
end

local function finalizeFacilityModel(
	model: Model,
	centerCF: CFrame,
	hullSize: Vector3,
	promptOffset: Vector3
): (Part, Attachment)
	-- Ground-level PrimaryPart for standardized pivot & clean collision hull
	local root = part(
		model,
		"PrimaryRoot",
		V(hullSize.X, math.max(1, hullSize.Y), hullSize.Z),
		centerCF * CFrame.new(0, math.max(0.5, hullSize.Y * 0.5), 0),
		Color3.fromRGB(60, 62, 68),
		Enum.Material.SmoothPlastic,
		hullSize.Y > 1.5
	)
	root.Transparency = 1
	model.PrimaryPart = root

	local promptAnchor = Instance.new("Attachment")
	promptAnchor.Name = "PromptAnchor"
	promptAnchor.Position = promptOffset
	promptAnchor.Parent = root

	local interactionPart = part(
		model,
		"FacilityInteraction",
		V(2, 2, 2),
		centerCF * CFrame.new(promptOffset),
		Color3.new(1, 1, 1),
		Enum.Material.SmoothPlastic,
		false
	)
	interactionPart.Transparency = 1

	return interactionPart, promptAnchor
end

type BundledMeshSpec = {
	Name: string,
	MeshId: string,
	Size: Vector3,
	Pos: Vector3,
	PivotOffset: Vector3,
	ColorMap: string,
	NormalMap: string,
	RoughnessMap: string,
	CastShadow: boolean,
}

local buildingMeshTemplates: { [string]: boolean } = {}

local function createMeshPartFromId(meshId: string): MeshPart?
	local ok, res = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromUri(meshId))
	end)
	if ok and res and res:IsA("MeshPart") then
		return res
	end
	ok, res = pcall(function()
		return (AssetService :: any):CreateMeshPartAsync(meshId)
	end)
	if ok and res and res:IsA("MeshPart") then
		return res
	end
	ok, res = pcall(function()
		return InsertService:CreateMeshPartAsync(meshId, Enum.CollisionFidelity.Default, Enum.RenderFidelity.Automatic)
	end)
	if ok and res and res:IsA("MeshPart") then
		return res
	end
	return nil
end

local function alignTemplateToSpecGround(templateModel: Model, specs: { BundledMeshSpec })
	local refSpec = specs[1]
	if not refSpec then
		return
	end
	local refPart = templateModel:FindFirstChild(refSpec.Name, true)
	if not (refPart and refPart:IsA("BasePart")) then
		return
	end
	local pivotY = templateModel:GetPivot().Position.Y
	local deltaY = refSpec.Pos.Y - (refPart.Position.Y - pivotY)
	if math.abs(deltaY) <= 0.05 then
		return
	end
	local offset = Vector3.new(0, deltaY, 0)
	for _, desc in ipairs(templateModel:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.CFrame = desc.CFrame + offset
		end
	end
end

local function isFacilityPrefabAligned(templateModel: Model, specs: { BundledMeshSpec }): boolean
	local refSpec = specs[1]
	if not refSpec then
		return true
	end
	local refPart = templateModel:FindFirstChild(refSpec.Name, true)
	if not (refPart and refPart:IsA("BasePart")) then
		return false
	end
	local root = templateModel:FindFirstChild("PrimaryRoot")
	local groundY = if root and root:IsA("BasePart")
		then root.Position.Y - root.Size.Y * 0.5
		else templateModel:GetPivot().Position.Y
	return math.abs(refSpec.Pos.Y - (refPart.Position.Y - groundY)) <= 0.05
end

local function resolveBundledMeshTemplate(templateName: string, specs: { BundledMeshSpec }): Model?
	local function findValidTemplate(): Model?
		local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
		local customMeshes = assetsFolder and assetsFolder:FindFirstChild("CustomFacilityMeshes")
		local imported = customMeshes and customMeshes:FindFirstChild(templateName)
		if imported and imported:IsA("Model") and imported:FindFirstChildWhichIsA("MeshPart", true) then
			-- Normalize older sunken imports in-place (preserving CFrame.identity pivot semantics).
			if not imported:FindFirstChild("PrimaryRoot") then
				alignTemplateToSpecGround(imported, specs)
			end
			return imported
		end
		local plotFacs = assetsFolder and assetsFolder:FindFirstChild("PlotFacilities")
		local candidate = plotFacs and plotFacs:FindFirstChild(templateName)
		if candidate and candidate:IsA("Model") and candidate:FindFirstChildWhichIsA("MeshPart", true) then
			if isFacilityPrefabAligned(candidate, specs) then
				return candidate
			end
		end
		return nil
	end

	while buildingMeshTemplates[templateName] do
		task.wait()
	end
	local existing = findValidTemplate()
	if existing then
		return existing
	end

	-- Self-healing fallback: reconstruct and cache all Blender MeshParts from uploaded AssetIds
	-- so facilities stay visible even if CustomFacilityMeshes was stripped or unsynced.
	buildingMeshTemplates[templateName] = true
	local ok, built = pcall(function(): Model?
		local templateModel = Instance.new("Model")
		templateModel.Name = templateName
		templateModel.WorldPivot = CFrame.identity

		local remaining = #specs
		local createdCount = 0
		local meshRot = CFrame.Angles(0, math.pi, 0)
		local neutralTint = Color3.fromRGB(163, 162, 165)

		for _, spec in ipairs(specs) do
			task.spawn(function()
				local mp = createMeshPartFromId(spec.MeshId)
				if mp then
					mp.Name = spec.Name
					mp.Size = spec.Size
					mp.CFrame = CFrame.new(spec.Pos) * meshRot
					mp.PivotOffset = CFrame.new(spec.PivotOffset)
					mp.Color = neutralTint
					mp.Material = Enum.Material.Plastic
					mp.Anchored = true
					mp.CanCollide = false
					mp.CanTouch = false
					mp.CanQuery = false
					mp.CastShadow = spec.CastShadow

					local sa = Instance.new("SurfaceAppearance")
					sa.ColorMap = spec.ColorMap
					sa.NormalMap = spec.NormalMap
					sa.RoughnessMap = spec.RoughnessMap
					sa.AlphaMode = Enum.AlphaMode.Overlay
					sa.Parent = mp

					mp.Parent = templateModel
					createdCount += 1
				end
				remaining -= 1
			end)
		end

		while remaining > 0 do
			task.wait()
		end

		if createdCount == 0 then
			templateModel:Destroy()
			return nil
		end

		local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
		if not assetsFolder then
			local newAssets = Instance.new("Folder")
			newAssets.Name = "Assets"
			newAssets.Parent = ReplicatedStorage
			assetsFolder = newAssets
		end
		local customMeshes = assetsFolder:FindFirstChild("CustomFacilityMeshes")
		if not customMeshes then
			local newCustom = Instance.new("Folder")
			newCustom.Name = "CustomFacilityMeshes"
			newCustom.Parent = assetsFolder
			customMeshes = newCustom
		end
		templateModel.Parent = customMeshes
		return templateModel
	end)
	buildingMeshTemplates[templateName] = nil

	return if ok then built else nil
end

local function instantiateBundledMeshes(
	templateName: string,
	specs: { BundledMeshSpec },
	model: Model,
	centerCF: CFrame
): boolean
	local castShadowByName: { [string]: boolean } = {}
	for _, spec in ipairs(specs) do
		castShadowByName[spec.Name] = spec.CastShadow
	end

	local importedTemplate = resolveBundledMeshTemplate(templateName, specs)
	if not importedTemplate then
		return false
	end

	local cloned = importedTemplate:Clone()
	cloned:PivotTo(centerCF)
	for _, desc in ipairs(cloned:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Anchored = true
			desc.CanCollide = false
			desc.CanTouch = false
			desc.CanQuery = false
			desc.CastShadow = castShadowByName[desc.Name] ~= false
		end
	end
	for _, ch in ipairs(cloned:GetChildren()) do
		if not ch:IsA("PackageLink") then
			ch.Parent = model
		end
	end
	cloned:Destroy()
	return true
end

--============================================================================
-- 2.1 SUMMONING PORTAL (`SummoningPortal` — Wall-Mounted Gothic Corner Portal)
--============================================================================
function Arch.BuildSummoning(folder: Instance, centerCF: CFrame): Part
	local AssetService = game:GetService("AssetService")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local model = Instance.new("Model")
	model.Name = "Building_Summoning"
	model:SetAttribute("PortalState", "Closed")
	model.Parent = folder

	-- 4 Material Zones (Step 4)
	local zone1Slate    = Color3.fromRGB(24, 21, 29)   -- #18151D Deep weathered slate-stone
	local zone1Ashlar   = Color3.fromRGB(36, 32, 44)   -- Highlighted ashlar block courses
	local zone2Obsidian = Color3.fromRGB(44, 37, 56)   -- #2C2538 Aged dark-bronze/obsidian relief
	local zone3RuneGlow = Color3.fromRGB(34, 211, 238) -- #22D3EE Closed state seam & rune inlays
	local zone4Vortex   = Color3.fromRGB(0, 229, 255)  -- #00E5FF Intense electric cyan vortex & conduits
	local deepAstral    = Color3.fromRGB(13, 71, 161)  -- #0D47A1 Deep vortex outer gradient

	-- Check if imported Blender FBX MeshParts exist in ReplicatedStorage.Assets.CustomFacilityMeshes.SummoningPortal
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	local customMeshes = assetsFolder and assetsFolder:FindFirstChild("CustomFacilityMeshes")
	local importedTemplate = customMeshes and customMeshes:FindFirstChild("SummoningPortal")

	if importedTemplate and importedTemplate:IsA("Model") then
		local clonedMeshModel = importedTemplate:Clone()
		-- Imported FBX has front along -Z and rear corner wedge along +Z; rotate 180 deg so Front is +Z (facing Plot Center)
		clonedMeshModel:PivotTo(centerCF * CFrame.Angles(0, math.pi, 0))

		local frameMesh = clonedMeshModel:FindFirstChild("Portal_Frame_StaticMesh", true)
		local doorsGroup = clonedMeshModel:FindFirstChild("Portal_Doors_ClosedMesh", true)
		local vortexMesh = clonedMeshModel:FindFirstChild("Portal_Active_VortexMesh", true)

		if doorsGroup then
			doorsGroup.Parent = model
			for _, leafInfo in ipairs({
				{ Name = "Portal_Door_Left", IsLeft = true, HingeX = -5.5 },
				{ Name = "Portal_Door_Right", IsLeft = false, HingeX = 5.5 },
			}) do
				local leaf = doorsGroup:FindFirstChild(leafInfo.Name, true)
				if leaf and leaf:IsA("BasePart") then
					leaf.Anchored = true
					leaf.CanCollide = false
					leaf.Material = Enum.Material.Metal
					leaf.Color = zone2Obsidian

					local closedCF = leaf.CFrame
					local hingeCF = centerCF * CFrame.new(leafInfo.HingeX, closedCF.Position.Y - centerCF.Position.Y, 3.6)
					local relToHinge = hingeCF:ToObjectSpace(closedCF)
					-- Swing outwards (+Z toward courtyard): Left door (-X hinge, dx>0) uses -80 deg, Right door (+X hinge, dx<0) uses +80 deg
					local openAngle = math.rad(if leafInfo.IsLeft then -80 else 80)
					local openCF = (hingeCF * CFrame.Angles(0, openAngle, 0)) * relToHinge

					leaf:SetAttribute("ClosedCFrame", closedCF)
					leaf:SetAttribute("OpenCFrame", openCF)
					leaf:SetAttribute("HingeCFrame", hingeCF)
					leaf:SetAttribute("OpenAngleRad", openAngle)
				end
			end
			-- Glowing vertical center seam between the closed MeshPart doors
			part(doorsGroup, "CenterSeamNeon", V(0.18, 18.8, 1.12), centerCF * CFrame.new(0, 11.4, 3.70), zone4Vortex, Enum.Material.Neon, false)
		end

		if vortexMesh and vortexMesh:IsA("BasePart") then
			vortexMesh.Anchored = true
			vortexMesh.CanCollide = false
			vortexMesh.Material = Enum.Material.Neon
			vortexMesh.Color = zone4Vortex
			vortexMesh.Transparency = 0.12
			vortexMesh.Parent = model
		end

		if frameMesh and frameMesh:IsA("BasePart") then
			frameMesh.Anchored = true
			frameMesh.CanCollide = true
			frameMesh.Material = Enum.Material.Slate
			frameMesh.Color = zone1Ashlar
			frameMesh.Parent = model
		end

		clonedMeshModel:Destroy()

		-- Add Neon Rune Inlays, Floor Conduits & Light-Tight Backing Shield around the imported 3D MeshParts
		local inlaysGroup = Instance.new("Folder")
		inlaysGroup.Name = "Portal_Neon_Inlays"
		inlaysGroup.Parent = model

		-- Light-tight dark backing shield behind the vortex so players never see behind the corner wall
		part(inlaysGroup, "BackingWallShield", V(13.2, 20.2, 0.50), centerCF * CFrame.new(0, 11.6, -2.35), zone1Slate, Enum.Material.Slate, false)

		-- Central Astral Core & Crackling Lightning Ribbons inside the vortex recess
		local vortexCenterCF = centerCF * CFrame.new(0, 11.4, -1.05)
		local eyeCore = sphere(
			inlaysGroup,
			"PortalEyeCore",
			3.8,
			vortexCenterCF * CFrame.new(0, 0, 0.25),
			Color3.fromRGB(224, 248, 255),
			Enum.Material.Neon
		)
		eyeCore.Transparency = 0.15
		for b = 1, 8 do
			local angle = ((b - 1) / 8) * math.pi * 2 + 0.35
			local rx = math.cos(angle) * 3.4
			local ry = math.sin(angle) * 5.8
			part(
				inlaysGroup,
				"VortexLightningArc_" .. b,
				V(0.18, 4.2, 0.18),
				vortexCenterCF * CFrame.new(rx, ry, 0.35) * CFrame.Angles(0, 0, angle + 0.65),
				zone4Vortex,
				Enum.Material.Neon,
				false
			)
		end

		-- Step & Side Floor Neon Conduits
		for step = 1, 3 do
			local idx = step - 1
			local stepH = 0.62
			local cy = (idx + 0.5) * stepH
			local cz = 8.8 - idx * 1.45
			local sw = 13.6 - idx * 0.6
			part(inlaysGroup, "StepRuneConduit_" .. step, V(sw - 1.2, 0.14, 0.14), centerCF * CFrame.new(0, cy + 0.18, cz + 0.86), zone4Vortex, Enum.Material.Neon, false)
		end
		for _, sideSign in ipairs({ -1, 1 }) do
			local conduitCF = centerCF * CFrame.new(sideSign * 8.4, 0.35, 7.4) * CFrame.Angles(0, sideSign * 0.28, 0)
			part(inlaysGroup, "SideConduitGlow", V(0.85, 0.18, 4.0), conduitCF * CFrame.new(0, 0.38, 0), zone4Vortex, Enum.Material.Neon, false)
			part(inlaysGroup, "PilasterRuneStrip", V(0.44, 9.8, 0.28), centerCF * CFrame.new(sideSign * 6.45, 8.2, 4.72), zone3RuneGlow, Enum.Material.Neon, false)
			part(inlaysGroup, "SpandrelRune", V(1.4, 1.0, 0.26), centerCF * CFrame.new(sideSign * 8.2, 22.1, 4.95), zone3RuneGlow, Enum.Material.Neon, false)
		end
		for i = 1, 8 do
			local a = -0.60 + ((i - 0.5) / 8) * 1.20
			local r = 10.15
			part(
				inlaysGroup,
				"ThresholdRuneArc_" .. i,
				V(1.55, 0.16, 0.55),
				centerCF * CFrame.new(math.sin(a) * r, 0.08, math.cos(a) * r) * CFrame.Angles(0, a, 0),
				zone4Vortex,
				Enum.Material.Neon,
				false
			)
		end
		for i = 1, 16 do
			local t = (i - 0.5) / 16
			local isRight = t <= 0.5
			local u = if isRight then (t * 2.0) else ((1.0 - t) * 2.0)
			local angle = u * (math.pi * 0.5)
			local signX = if isRight then 1 else -1
			local innerX = signX * 5.5 * (math.cos(angle) ^ 0.82)
			local innerY = 13.5 + (21.2 - 13.5) * (math.sin(angle) ^ 0.92)
			local outerX = signX * 9.4 * (math.cos(angle) ^ 0.82)
			local outerY = 13.5 + (24.2 - 13.5) * (math.sin(angle) ^ 0.92)
			local roll = math.atan2(outerY - innerY, outerX - innerX)
			part(
				inlaysGroup,
				"ArchRuneTrim_" .. i,
				V(0.45, 1.75, 0.55),
				centerCF * CFrame.new(innerX * 1.08, innerY + 0.35, 4.82) * CFrame.Angles(0, 0, roll),
				zone3RuneGlow,
				Enum.Material.Neon,
				false
			)
		end
		part(inlaysGroup, "KeystoneRuneGem", V(1.1, 2.1, 0.42), centerCF * CFrame.new(0, 22.5, 5.42), zone3RuneGlow, Enum.Material.Neon, false)
		part(inlaysGroup, "TopFriezeRuneStrip", V(18.0, 0.28, 0.26), centerCF * CFrame.new(0, 24.3, 5.10), zone3RuneGlow, Enum.Material.Neon, false)
	else
		-- Sub-Mesh 1 Container: Portal_Frame_StaticMesh (Procedural Fallback)
		local frameGroup = Instance.new("Model")
		frameGroup.Name = "Portal_Frame_StaticMesh"
		frameGroup.Parent = model

		-- 1A. Stepped Pedestal Plinth & Glowing Cyan Floor Conduits (Y = 0.0 to 2.0)
		part(frameGroup, "PlinthTier1", V(24.0, 1.1, 13.8), centerCF * CFrame.new(0, 0.55, 0.4), zone1Slate, Enum.Material.Slate, true)
		local plinthTop = part(frameGroup, "PlinthTier2", V(21.6, 1.0, 11.8), centerCF * CFrame.new(0, 1.50, 0.2), zone1Ashlar, Enum.Material.Slate, true)
		frameGroup.PrimaryPart = plinthTop

		-- 3 Front Approach Steps (+Z facing Courtyard & Path_FountainToPortal)
		for step = 1, 3 do
			local idx = step - 1
			local stepH = 0.62
			local cy = (idx + 0.5) * stepH
			local cz = 8.8 - idx * 1.45
			local sw = 13.6 - idx * 0.6
			part(frameGroup, "PortalStep_" .. step, V(sw, stepH, 1.65), centerCF * CFrame.new(0, cy, cz), zone1Ashlar, Enum.Material.Cobblestone, true)
			part(frameGroup, "StepRuneConduit_" .. step, V(sw - 1.2, 0.14, 0.12), centerCF * CFrame.new(0, cy + 0.12, cz + 0.84), zone4Vortex, Enum.Material.Neon, false)
		end

		-- Side Light-Channel Conduits connecting floor paths to portal base
		for _, sideSign in ipairs({ -1, 1 }) do
			local conduitCF = centerCF * CFrame.new(sideSign * 8.4, 0.35, 7.4) * CFrame.Angles(0, sideSign * 0.28, 0)
			part(frameGroup, "SideConduitCurb", V(2.2, 0.70, 4.2), conduitCF, zone2Obsidian, Enum.Material.Slate, false)
			part(frameGroup, "SideConduitGlow", V(0.85, 0.16, 4.0), conduitCF * CFrame.new(0, 0.36, 0), zone4Vortex, Enum.Material.Neon, false)
			part(frameGroup, "PlinthLateralRune", V(0.65, 0.14, 4.8), centerCF * CFrame.new(sideSign * 7.8, 2.04, 3.8), zone4Vortex, Enum.Material.Neon, false)
		end

		-- Threshold Runic Floor Arc in front of bottom step
		for i = 1, 8 do
			local a = -0.60 + ((i - 0.5) / 8) * 1.20
			local r = 10.05
			part(
				frameGroup,
				"ThresholdRuneArc_" .. i,
				V(1.55, 0.16, 0.55),
				centerCF * CFrame.new(math.sin(a) * r, 0.08, math.cos(a) * r) * CFrame.Angles(0, a, 0),
				zone4Vortex,
				Enum.Material.Neon,
				false
			)
		end

		-- 1B. Flush Corner / Wall-Hugging Rear Masonry Housing (Z = -7.2 to -2.1)
		part(frameGroup, "RearWallHousing", V(22.8, 24.5, 2.2), centerCF * CFrame.new(0, 12.25, -3.1), zone1Slate, Enum.Material.Slate, true)
		part(frameGroup, "RearCornerWedgePlug", V(14.0, 24.0, 3.4), centerCF * CFrame.new(0, 12.0, -5.6), zone1Slate, Enum.Material.Slate, true)

		-- 1C. Towering Gothic Buttress Piers, Engaged Columns & Coursed Ashlar Stonework (H = 26.5 studs)
		for _, sideSign in ipairs({ -1, 1 }) do
			local pierX = sideSign * 8.35
			part(frameGroup, "GothicPierMain", V(5.5, 22.0, 7.0), centerCF * CFrame.new(pierX, 13.0, 1.3), zone1Slate, Enum.Material.Slate, true)
			part(frameGroup, "GothicPierPlinth", V(6.3, 3.2, 7.4), centerCF * CFrame.new(pierX, 3.6, 1.6), zone2Obsidian, Enum.Material.Slate, true)
			part(frameGroup, "GothicPierImpost", V(6.2, 1.1, 7.3), centerCF * CFrame.new(pierX, 13.6, 1.6), zone2Obsidian, Enum.Material.Slate, false)
			part(frameGroup, "GothicPierCap", V(3.4, 1.4, 7.0), centerCF * CFrame.new(sideSign * 9.6, 24.4, 1.5), zone2Obsidian, Enum.Material.Slate, false)

			-- Engaged Outer Gothic Column
			local colX = sideSign * 10.65
			part(frameGroup, "EngagedColPedestal", V(2.4, 3.6, 2.4), centerCF * CFrame.new(colX, 3.8, 4.65), zone2Obsidian, Enum.Material.Slate, false)
			cylinder(frameGroup, "EngagedColLower", 0.92, 7.6, centerCF * CFrame.new(colX, 9.4, 4.65), zone2Obsidian, Enum.Material.Slate, false)
			cylinder(frameGroup, "EngagedColCapital", 1.22, 1.1, centerCF * CFrame.new(colX, 13.75, 4.65), zone2Obsidian, Enum.Material.Slate, false)
			cylinder(frameGroup, "EngagedColUpper", 0.80, 9.3, centerCF * CFrame.new(colX, 18.95, 4.65), zone2Obsidian, Enum.Material.Slate, false)

			-- Recessed Vertical Rune Inlay Channel & Carved Glyphs
			local runeX = sideSign * 6.45
			part(frameGroup, "PilasterRuneStrip", V(0.44, 9.8, 0.25), centerCF * CFrame.new(runeX, 8.2, 4.65), zone3RuneGlow, Enum.Material.Neon, false)
			for rIdx = 1, 7 do
				local ry = 3.6 + (rIdx - 1) * 1.48
				part(frameGroup, "PilasterRuneBar_" .. rIdx, V(0.72, 0.20, 0.30), centerCF * CFrame.new(runeX, ry, 4.74), zone2Obsidian, Enum.Material.Slate, false)
			end

			-- Weathered Coursed Ashlar Stone Relief Blocks
			for course = 1, 10 do
				local cy = 3.0 + (course - 1) * 2.05
				local xShift = if course % 2 == 0 then 0.35 else -0.35
				local bx = sideSign * (8.8 + xShift * 0.45)
				part(frameGroup, "AshlarBlock_" .. course, V(2.6, 0.88, 0.45), centerCF * CFrame.new(bx, cy, 4.60), zone1Ashlar, Enum.Material.Slate, false)
			end

			-- Spandrel Gothic Tracery Medallions
			local spX = sideSign * 8.2
			part(frameGroup, "SpandrelFrame", V(3.2, 2.2, 0.35), centerCF * CFrame.new(spX, 22.1, 4.78), zone2Obsidian, Enum.Material.Slate, false)
			part(frameGroup, "SpandrelRune", V(1.4, 1.0, 0.22), centerCF * CFrame.new(spX, 22.1, 4.92), zone3RuneGlow, Enum.Material.Neon, false)
		end

		-- 1D. Pointed Gothic Arch Voussoirs, Inner Soffit Vault & Apex Keystone (Y = 13.5 to 24.2)
		local archSegments = 16
		for i = 1, archSegments do
			local t = (i - 0.5) / archSegments
			local isRight = t <= 0.5
			local u = if isRight then (t * 2.0) else ((1.0 - t) * 2.0)
			local angle = u * (math.pi * 0.5)
			local signX = if isRight then 1 else -1

			local innerX = signX * 5.5 * (math.cos(angle) ^ 0.82)
			local innerY = 13.5 + (21.2 - 13.5) * (math.sin(angle) ^ 0.92)
			local outerX = signX * 9.4 * (math.cos(angle) ^ 0.82)
			local outerY = 13.5 + (24.2 - 13.5) * (math.sin(angle) ^ 0.92)

			local midX = (innerX + outerX) * 0.5
			local midY = (innerY + outerY) * 0.5
			local roll = math.atan2(outerY - innerY, outerX - innerX)
			local blockCol = if i % 2 == 0 then zone2Obsidian else zone1Ashlar

			part(
				frameGroup,
				"ArchVoussoir_" .. i,
				V(3.8, 1.85, 6.8),
				centerCF * CFrame.new(midX, midY, 1.4) * CFrame.Angles(0, 0, roll),
				blockCol,
				Enum.Material.Slate,
				false
			)
			part(
				frameGroup,
				"ArchRuneTrim_" .. i,
				V(0.45, 1.75, 0.52),
				centerCF * CFrame.new(innerX * 1.08, innerY + 0.35, 4.78) * CFrame.Angles(0, 0, roll),
				zone3RuneGlow,
				Enum.Material.Neon,
				false
			)
		end

		-- Apex Keystone & Top Peaked Gothic Pediment (Y = 22.6 to 26.5)
		part(frameGroup, "ArchKeystone", V(2.8, 3.4, 4.4), centerCF * CFrame.new(0, 22.6, 3.2), zone2Obsidian, Enum.Material.Slate, false)
		part(frameGroup, "KeystoneRuneGem", V(1.1, 2.1, 0.38), centerCF * CFrame.new(0, 22.5, 5.38), zone3RuneGlow, Enum.Material.Neon, false)
		part(frameGroup, "TopEntablatureBeam", V(22.4, 1.4, 7.2), centerCF * CFrame.new(0, 24.3, 1.4), zone1Slate, Enum.Material.Slate, false)
		part(frameGroup, "TopFriezeRuneStrip", V(18.0, 0.28, 0.22), centerCF * CFrame.new(0, 24.3, 5.05), zone3RuneGlow, Enum.Material.Neon, false)
		part(frameGroup, "PedimentCrown", V(14.0, 1.6, 6.6), centerCF * CFrame.new(0, 25.7, 1.6), zone2Obsidian, Enum.Material.Slate, false)

		--========================================================================
		-- Sub-Mesh 2: Portal_Doors_ClosedMesh (Hinged Left & Right Winged Doors)
		--========================================================================
		local doorsGroup = Instance.new("Model")
		doorsGroup.Name = "Portal_Doors_ClosedMesh"
		doorsGroup.Parent = model

		local function buildWingedDoorLeaf(leafName: string, isLeft: boolean): Model
			local leafModel = Instance.new("Model")
			leafModel.Name = leafName
			leafModel.Parent = doorsGroup

			local sign = if isLeft then 1 else -1 -- Direction from hinge toward center seam
			local hingeWorldCF = centerCF * CFrame.new(if isLeft then -5.5 else 5.5, 2.0, 3.6)

			local hingeRoot = part(leafModel, "HingePivot", V(0.5, 18.0, 0.68), hingeWorldCF * CFrame.new(0, 9.0, 0), zone2Obsidian, Enum.Material.Slate, false)
			hingeRoot.Transparency = 1
			leafModel.PrimaryPart = hingeRoot

			-- Store Closed and Open (80 deg outward swing) CFrames for TweenService in PortalEffectController
			local openAngle = math.rad(if isLeft then -80 else 80)
			leafModel:SetAttribute("ClosedCFrame", hingeRoot.CFrame)
			leafModel:SetAttribute("OpenCFrame", hingeWorldCF * CFrame.Angles(0, openAngle, 0) * CFrame.new(0, 9.0, 0))

			-- Arched Door Slab Strips
			local doorW = 5.44
			local strips = 4
			for s = 1, strips do
				local u = (s - 0.5) / strips
				local stripW = doorW / strips + 0.05
				local lx = sign * (u * doorW)
				local wx = if isLeft then (-5.5 + u * doorW) else (5.5 - u * doorW)
				local ratio = math.clamp(math.abs(wx) / 5.5, 0, 1)
				local archAngle = math.acos(ratio ^ (1 / 0.82))
				local stripH = (13.5 + (21.2 - 13.5) * (math.sin(archAngle) ^ 0.92)) - 2.0 - 0.15

				part(
					leafModel,
					"DoorSlab_" .. s,
					V(stripW, stripH, 0.68),
					hingeWorldCF * CFrame.new(lx, stripH * 0.5, 0),
					zone2Obsidian,
					Enum.Material.Slate,
					true
				)
			end

			-- Glowing Vertical Center Seam Edge & Astragal Moulding
			local seamX = sign * (doorW - 0.07)
			part(leafModel, "CenterSeamNeon", V(0.14, 18.8, 0.82), hingeWorldCF * CFrame.new(seamX, 9.4, 0), zone4Vortex, Enum.Material.Neon, false)
			part(leafModel, "CenterAstragalRune", V(0.22, 18.4, 0.22), hingeWorldCF * CFrame.new(sign * (doorW - 0.24), 9.2, 0.36), zone3RuneGlow, Enum.Material.Neon, false)

			-- 3 Tiers of Sculpted Angelic / Seraph Wing Filigree + Glowing Cyan Fissures (image_88350b.jpg)
			for tierIdx, tierBaseY in ipairs({ 1.4, 6.2, 11.4 }) do
				for f = 1, 5 do
					local ft = (f - 1) / 4
					local midX = sign * (doorW * (0.72 - ft * 0.12))
					local midY = tierBaseY + ft * 3.8 + 1.1
					local tiltZ = sign * math.rad(34 - ft * 8)

					local featherCF = hingeWorldCF * CFrame.new(midX, midY, 0.38) * CFrame.Angles(0, 0, tiltZ)
					part(
						leafModel,
						string.format("WingFeather_T%d_%d", tierIdx, f),
						V(3.2, 0.38, 0.28),
						featherCF,
						zone2Obsidian,
						Enum.Material.Metal,
						false
					)
					part(
						leafModel,
						string.format("WingFissure_T%d_%d", tierIdx, f),
						V(2.9, 0.12, 0.20),
						featherCF * CFrame.new(0, -0.22, -0.02),
						zone3RuneGlow,
						Enum.Material.Neon,
						false
					)
				end
			end

			return leafModel
		end

		buildWingedDoorLeaf("Portal_Door_Left", true)
		buildWingedDoorLeaf("Portal_Door_Right", false)

		--========================================================================
		-- Sub-Mesh 3: Portal_Active_VortexMesh (Swirling Vortex + Backing Shield)
		--========================================================================
		local vortexGroup = Instance.new("Model")
		vortexGroup.Name = "Portal_Active_VortexMesh"
		vortexGroup.Parent = model

		local vortexCenterCF = centerCF * CFrame.new(0, 11.4, -1.55)

		-- Light-Tight Dark Backing Wall Shield (Z = -2.15, prevents seeing behind castle wall)
		part(vortexGroup, "BackingWallShield", V(12.6, 19.8, 0.45), centerCF * CFrame.new(0, 11.4, -2.05), zone1Slate, Enum.Material.Slate, false)

		-- Central Swirling Portal Disc & Core
		local portalDisc = part(
			vortexGroup,
			"PortalVortexDisc",
			V(0.55, 18.2, 10.8),
			vortexCenterCF * CFrame.Angles(0, math.pi * 0.5, 0),
			deepAstral,
			Enum.Material.Neon,
			false
		)
		portalDisc.Transparency = 0.12
		vortexGroup.PrimaryPart = portalDisc

		local innerCore = part(
			vortexGroup,
			"PortalInnerCore",
			V(0.70, 13.6, 7.8),
			vortexCenterCF * CFrame.Angles(0, math.pi * 0.5, 0),
			zone4Vortex,
			Enum.Material.Neon,
			false
		)
		innerCore.Transparency = 0.18

		local eyeCore = sphere(
			vortexGroup,
			"PortalEyeCore",
			3.8,
			vortexCenterCF * CFrame.new(0, 0, 0.25),
			Color3.fromRGB(224, 248, 255),
			Enum.Material.Neon
		)
		eyeCore.Transparency = 0.15

		-- 8 Crackling 3D Lightning Arc Ribbons inside the vortex recess
		for b = 1, 8 do
			local angle = ((b - 1) / 8) * math.pi * 2 + 0.35
			local rx = math.cos(angle) * 3.4
			local ry = math.sin(angle) * 5.8
			part(
				vortexGroup,
				"VortexLightningArc_" .. b,
				V(0.18, 4.2, 0.18),
				vortexCenterCF * CFrame.new(rx, ry, 0.35) * CFrame.Angles(0, 0, angle + 0.65),
				zone4Vortex,
				Enum.Material.Neon,
				false
			)
		end
	end

	--========================================================================
	-- Standard Sockets & VFX Instances (Step 3)
	--========================================================================
	local interactionPart, promptAnchor = finalizeFacilityModel(model, centerCF, V(21.6, 2.0, 11.8), V(0, 2.0, 6.0))
	local primaryRoot = model.PrimaryPart :: Part

	local function makeSocket(name: string, localOffset: Vector3): Attachment
		local att = Instance.new("Attachment")
		att.Name = name
		att.Position = localOffset - V(0, 1.0, 0) -- Relative to PrimaryRoot center at Y = 1.0
		att.Parent = primaryRoot
		return att
	end

	local centerVFXSocket  = makeSocket("CenterVFXSocket", V(0, 11.5, 1.2))
	local _wallBackAnchor  = makeSocket("WallBackAnchor", V(0, 12.0, 0.0))
	promptAnchor.Position  = V(0, 1.0, 6.0) -- World (0, 2.0, 6.0) relative to centerCF

	-- PointLight on CenterVFXSocket
	local portalLight = pointLight(centerVFXSocket, zone4Vortex, 2.4, 38, true)
	portalLight.Name = "PortalPointLight"

	-- Swirling Vortex ParticleEmitter
	local swirlEmitter = Instance.new("ParticleEmitter")
	swirlEmitter.Name = "PortalVortexParticles"
	swirlEmitter.Texture = "rbxassetid://243660364"
	swirlEmitter.Color = ColorSequence.new(Color3.fromRGB(220, 250, 255), zone4Vortex)
	swirlEmitter.LightEmission = 1
	swirlEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2.5),
		NumberSequenceKeypoint.new(0.5, 6.0),
		NumberSequenceKeypoint.new(1, 1.4),
	})
	swirlEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.65),
		NumberSequenceKeypoint.new(0.4, 0.22),
		NumberSequenceKeypoint.new(1, 1),
	})
	swirlEmitter.Lifetime = NumberRange.new(1.2, 2.0)
	swirlEmitter.Rate = 28
	swirlEmitter.Speed = NumberRange.new(1.5, 4.5)
	swirlEmitter.RotSpeed = NumberRange.new(55, 110)
	swirlEmitter.SpreadAngle = Vector2.new(35, 35)
	swirlEmitter.Parent = centerVFXSocket

	-- Outward God-Ray Beams removed to eliminate intersecting white light shafts across courtyard/abyss

	return interactionPart
end

--============================================================================
-- 2.2 LEADERBOARD (Replaced by ground-based AvxsedPlaytimeWS)
--============================================================================
function Arch.BuildLeaderboard(folder: Instance, centerCF: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "Building_Leaderboard"
	model.Parent = folder
	return model
end

--============================================================================
-- 2.3 MARKET CLUSTER (`MarketCluster` — 4-Stall Merchant Bazaar)
--============================================================================
local MB_GROUND_CM = "rbxassetid://113914176453341"
local MB_GROUND_NM = "rbxassetid://123858544123055"
local MB_GROUND_RM = "rbxassetid://116192881674411"
local MB_PROPS_CM = "rbxassetid://138033743603856"
local MB_PROPS_NM = "rbxassetid://125626595855578"
local MB_PROPS_RM = "rbxassetid://109367096016299"

local MARKET_BAZAAR_MESHES: { BundledMeshSpec } = {
	{ Name = "Bazaar_FlagstonePath", MeshId = "rbxassetid://120654218023852", Size = V(36.2106, 0.1128, 25.6074), Pos = V(-0.0754, 0.0314, 1.0763), PivotOffset = V(-0.0754, -0.0314, 1.0763), ColorMap = MB_GROUND_CM, NormalMap = MB_GROUND_NM, RoughnessMap = MB_GROUND_RM, CastShadow = false },
	{ Name = "Bazaar_GrassTufts", MeshId = "rbxassetid://134746546712747", Size = V(31.1276, 1.3751, 16.2294), Pos = V(-0.5799, 0.6676, 3.3078), PivotOffset = V(-0.5799, -0.6676, 3.3078), ColorMap = MB_GROUND_CM, NormalMap = MB_GROUND_NM, RoughnessMap = MB_GROUND_RM, CastShadow = false },
	{ Name = "Stall_TimberFrame", MeshId = "rbxassetid://94835237518558", Size = V(34.7483, 11.1800, 14.1258), Pos = V(-0.1164, 5.5900, -4.3771), PivotOffset = V(-0.1164, -5.5900, -4.3771), ColorMap = MB_PROPS_CM, NormalMap = MB_PROPS_NM, RoughnessMap = MB_PROPS_RM, CastShadow = true },
	{ Name = "Stall_Counters", MeshId = "rbxassetid://108082766428988", Size = V(31.1441, 3.4800, 10.3771), Pos = V(0.0159, 1.7400, -2.7232), PivotOffset = V(0.0159, -1.7400, -2.7232), ColorMap = MB_PROPS_CM, NormalMap = MB_PROPS_NM, RoughnessMap = MB_PROPS_RM, CastShadow = true },
	{ Name = "Awning_Left_RedYellow", MeshId = "rbxassetid://100646726815798", Size = V(12.6421, 3.4000, 9.0359), Pos = V(-10.8776, 9.3500, -4.0898), PivotOffset = V(-10.8776, -9.3500, -4.0898), ColorMap = MB_PROPS_CM, NormalMap = MB_PROPS_NM, RoughnessMap = MB_PROPS_RM, CastShadow = true },
	{ Name = "Awning_Center_Tan", MeshId = "rbxassetid://116621867088318", Size = V(13.2248, 3.3500, 7.1166), Pos = V(0.9180, 10.1050, -8.1162), PivotOffset = V(0.9180, -10.1050, -8.1162), ColorMap = MB_PROPS_CM, NormalMap = MB_PROPS_NM, RoughnessMap = MB_PROPS_RM, CastShadow = true },
	{ Name = "Awning_Right_GreenWhite", MeshId = "rbxassetid://102136386214882", Size = V(12.4687, 3.4000, 10.3968), Pos = V(11.5315, 9.3500, -1.8696), PivotOffset = V(11.5315, -9.3500, -1.8696), ColorMap = MB_PROPS_CM, NormalMap = MB_PROPS_NM, RoughnessMap = MB_PROPS_RM, CastShadow = true },
	{ Name = "Sign_HangingBoard", MeshId = "rbxassetid://97980584183874", Size = V(2.5356, 2.4750, 0.9304), Pos = V(-16.9800, 7.6125, -0.0200), PivotOffset = V(0.0000, 1.2375, 0.0000), ColorMap = MB_PROPS_CM, NormalMap = MB_PROPS_NM, RoughnessMap = MB_PROPS_RM, CastShadow = true },
	{ Name = "Bazaar_Props_Clutter", MeshId = "rbxassetid://84470033674241", Size = V(34.7280, 3.7940, 16.0324), Pos = V(-1.1000, 1.8440, -2.8478), PivotOffset = V(-1.1000, -1.8440, -2.8478), ColorMap = MB_PROPS_CM, NormalMap = MB_PROPS_NM, RoughnessMap = MB_PROPS_RM, CastShadow = true },
	{ Name = "Lantern_Housing_1", MeshId = "rbxassetid://95196063236877", Size = V(0.4808, 1.0700, 0.4808), Pos = V(-5.8500, 6.7150, -2.5400), PivotOffset = V(0.0000, 0.5350, 0.0000), ColorMap = MB_PROPS_CM, NormalMap = MB_PROPS_NM, RoughnessMap = MB_PROPS_RM, CastShadow = true },
	{ Name = "Lantern_Housing_2", MeshId = "rbxassetid://70695528803700", Size = V(0.4808, 1.0700, 0.4808), Pos = V(0.8100, 7.1150, -5.0500), PivotOffset = V(0.0000, 0.5350, 0.0000), ColorMap = MB_PROPS_CM, NormalMap = MB_PROPS_NM, RoughnessMap = MB_PROPS_RM, CastShadow = true },
	{ Name = "Lantern_Housing_3", MeshId = "rbxassetid://98025089646022", Size = V(0.4808, 1.0700, 0.4808), Pos = V(6.5300, 6.7150, -1.3100), PivotOffset = V(0.0000, 0.5350, 0.0000), ColorMap = MB_PROPS_CM, NormalMap = MB_PROPS_NM, RoughnessMap = MB_PROPS_RM, CastShadow = true },
}

function Arch.BuildMarket(folder: Instance, centerCF: CFrame): Part
	local model = Instance.new("Model")
	model.Name = "Building_Market"
	model.Parent = folder

	if not instantiateBundledMeshes("MarketCluster", MARKET_BAZAAR_MESHES, model, centerCF) then
		warn("[PlotFacilityArchitecture] Failed to load MarketCluster MeshParts")
	end

	-- Attach hinge pivot marker to the left merchant sign
	local signBoard = model:FindFirstChild("Sign_HangingBoard")
	if signBoard and signBoard:IsA("BasePart") then
		local signPivot = Instance.new("Attachment")
		signPivot.Name = "HangingSign_Pivot"
		signPivot.Position = V(0, 1.2375, 0)
		signPivot.Parent = signBoard
	end

	-- Attach warm amber lantern PointLights & subtle ember sparkles inside each swinging lantern mesh
	local warmGold = Color3.fromRGB(245, 158, 11)
	local emberColor = ColorSequence.new(Color3.fromRGB(255, 204, 102), Color3.fromRGB(245, 158, 11))
	for i = 1, 3 do
		local lantern = model:FindFirstChild("Lantern_Housing_" .. i)
		if lantern and lantern:IsA("BasePart") then
			local att = Instance.new("Attachment")
			att.Name = "LanternLight_" .. i
			att.Position = V(0, -0.18, 0)
			att.Parent = lantern

			local pl = Instance.new("PointLight")
			pl.Name = "LanternPointLight"
			pl.Color = warmGold
			pl.Brightness = 1.15
			pl.Range = 18
			pl.Shadows = false
			pl.Parent = att

			local ember = Instance.new("ParticleEmitter")
			ember.Name = "LanternEmber"
			ember.Color = emberColor
			ember.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.09),
				NumberSequenceKeypoint.new(1, 0),
			})
			ember.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.25),
				NumberSequenceKeypoint.new(1, 1),
			})
			ember.Lifetime = NumberRange.new(1.0, 1.8)
			ember.Rate = 1.5
			ember.Speed = NumberRange.new(0.4, 0.9)
			ember.SpreadAngle = Vector2.new(35, 35)
			ember.EmissionDirection = Enum.NormalId.Top
			ember.LightEmission = 0.85
			ember.Parent = att
		end
	end

	-- Solid box colliders for the 3 counters, crate/barrel/sack clusters, 12 timber corner posts,
	-- and 3 sloped awning roofs so players can climb and stand on top of the market without phasing through,
	-- while flagstones, open courtyard plaza, and rear trader lane stay 100% passable.
	local colColor = Color3.fromRGB(92, 86, 78)
	local function addMarketCollider(name: string, size: Vector3, localCF: CFrame)
		local existingCol = model:FindFirstChild(name)
		if existingCol then
			existingCol:Destroy()
		end
		local cp = part(
			model,
			name,
			size,
			centerCF * localCF,
			colColor,
			Enum.Material.Wood,
			true
		)
		cp.Transparency = 1
		cp.CastShadow = false
		cp.CanTouch = false
		cp.CanQuery = false
	end

	local marketColliders = {
		{ Name = "CounterCollider_Left", Pos = V(-10.50, 1.65, -2.69), Size = V(9.8, 3.30, 2.25), YawDeg = 15 },
		{ Name = "CounterCollider_Center", Pos = V(0.87, 1.65, -6.60), Size = V(11.2, 3.30, 2.25), YawDeg = -2 },
		{ Name = "CounterCollider_Right", Pos = V(10.94, 1.65, -0.66), Size = V(9.2, 3.30, 2.25), YawDeg = -26 },
		{ Name = "ClutterCollider_Left", Pos = V(-15.80, 1.35, -1.20), Size = V(3.6, 2.70, 5.60), YawDeg = 15 },
		{ Name = "ClutterCollider_Right", Pos = V(13.50, 1.35, 3.00), Size = V(4.6, 2.70, 4.40), YawDeg = -26 },
		{ Name = "ClutterCollider_CenterCrate", Pos = V(5.20, 0.88, -4.30), Size = V(2.25, 1.76, 1.65), YawDeg = -12 },
		{ Name = "ClutterCollider_CenterSack", Pos = V(-3.10, 0.82, -4.20), Size = V(1.55, 1.64, 1.55), YawDeg = 18 },
		{ Name = "ClutterCollider_RearBarrel", Pos = V(6.00, 1.22, -9.80), Size = V(1.90, 2.45, 1.90), YawDeg = 0 },
	}
	for _, col in ipairs(marketColliders) do
		addMarketCollider(
			col.Name,
			col.Size,
			CFrame.new(col.Pos) * CFrame.Angles(0, math.rad(col.YawDeg), 0)
		)
	end

	-- Stall-local colliders: sloped awning roofs, timber corner posts, and front display crates
	local stallDefs = {
		{
			Tag = "Left",
			BaseCF = CFrame.new(-10.8, 0, -3.8) * CFrame.Angles(0, math.rad(15), 0),
			AwningPos = V(0, 9.52, -0.35),
			AwningSize = V(11.4, 0.48, 6.80),
			AwningPitchDeg = 23.3,
			PostX = 5.00,
			FrontZ = 2.15,
			FrontH = 8.20,
			RearZ = -2.95,
			RearH = 10.55,
			PostThick = 0.56,
		},
		{
			Tag = "Center",
			BaseCF = CFrame.new(0.9, 0, -7.6) * CFrame.Angles(0, math.rad(-2), 0),
			AwningPos = V(0, 10.18, -0.55),
			AwningSize = V(13.0, 0.52, 7.10),
			AwningPitchDeg = 22.0,
			PostX = 5.80,
			FrontZ = 2.10,
			FrontH = 8.70,
			RearZ = -3.35,
			RearH = 11.15,
			PostThick = 0.58,
		},
		{
			Tag = "Right",
			BaseCF = CFrame.new(11.4, 0, -1.6) * CFrame.Angles(0, math.rad(-26), 0),
			AwningPos = V(0, 9.52, -0.35),
			AwningSize = V(10.8, 0.48, 6.80),
			AwningPitchDeg = 23.3,
			PostX = 4.75,
			FrontZ = 2.05,
			FrontH = 8.15,
			RearZ = -2.80,
			RearH = 10.45,
			PostThick = 0.56,
		},
	}
	for _, st in ipairs(stallDefs) do
		addMarketCollider(
			"AwningCollider_" .. st.Tag,
			st.AwningSize,
			st.BaseCF * CFrame.new(st.AwningPos) * CFrame.Angles(math.rad(st.AwningPitchDeg), 0, 0)
		)
		for _, side in ipairs({ { Suffix = "L", Sign = -1 }, { Suffix = "R", Sign = 1 } }) do
			local sx = side.Sign * st.PostX
			addMarketCollider(
				string.format("PostCollider_%s_Front_%s", st.Tag, side.Suffix),
				V(st.PostThick, st.FrontH, st.PostThick),
				st.BaseCF * CFrame.new(sx, st.FrontH * 0.5, st.FrontZ)
			)
			addMarketCollider(
				string.format("PostCollider_%s_Rear_%s", st.Tag, side.Suffix),
				V(st.PostThick, st.RearH, st.PostThick),
				st.BaseCF * CFrame.new(sx, st.RearH * 0.5, st.RearZ)
			)
		end
	end
	-- Front fruit display crates in front of the Right stall
	local rightBaseCF = CFrame.new(11.4, 0, -1.6) * CFrame.Angles(0, math.rad(-26), 0)
	addMarketCollider(
		"ClutterCollider_RightFruitCrates",
		V(4.20, 1.44, 1.75),
		rightBaseCF * CFrame.new(-1.35, 0.72, 2.85)
	)

	-- Keep PrimaryRoot hullSize.Y <= 1.5 so PrimaryRoot stays non-colliding while PromptAnchor & TraderSpots sit cleanly
	local interactionPart = finalizeFacilityModel(model, centerCF, V(4, 1.0, 4), V(0, 3.1, 6.2))
	local root = model.PrimaryPart
	if root then
		local traderSpots = {
			{ Name = "TraderSpot_1", Pos = V(-11.20, -0.44, -5.30), YawDeg = 15 },
			{ Name = "TraderSpot_2", Pos = V(0.95, -0.44, -9.15), YawDeg = -2 },
			{ Name = "TraderSpot_3", Pos = V(12.08, -0.44, -2.99), YawDeg = -26 },
		}
		for _, spot in ipairs(traderSpots) do
			local att = Instance.new("Attachment")
			att.Name = spot.Name
			att.CFrame = CFrame.new(spot.Pos) * CFrame.Angles(0, math.rad(spot.YawDeg), 0)
			att.Parent = root
		end
	end

	return interactionPart
end

--============================================================================
-- 2.4 SYNTHESIS CHAMBER (`SynthesisChamber` — Enterable Gothic Rotunda / The Pit)
--============================================================================
function Arch.BuildThePit(folder: Instance, centerCF: CFrame): Part
	local _, interactionPart = SynthesisChamberBuilder.Build(folder, centerCF)
	return interactionPart
end

--============================================================================
-- 2.5 BLACKSMITH FORGE (`BlacksmithForge` — Enterable Medieval-Gothic Blacksmith House)
--============================================================================
-- 2.5 OPEN FORGE (`BlacksmithForge` — Open-Air Smelter, Master Anvil & 6 Artifact Pedestals)
--============================================================================
-- Uniform 3 x 2 pedestal gallery (7.75 studs horizontal spacing, 10.0 studs row-to-row depth)
-- so 6.2-stud world-space billboards and 5.8-stud buy prompts stay cleanly separated and readable.
local PEDESTAL_OFFSETS: { Vector3 } = {
	V(-0.5, 0, 6.6),   -- Pedestal 1 (Starter, front-left)
	V(7.25, 0, 6.6),   -- Pedestal 2 (fp_1, front-center)
	V(15.0, 0, 6.6),   -- Pedestal 3 (fp_2, front-right)
	V(-0.5, 0, -3.4),  -- Pedestal 4 (fp_3, back-left)
	V(7.25, 0, -3.4),  -- Pedestal 5 (fp_4, back-center)
	V(15.0, 0, -3.4),  -- Pedestal 6 (fp_5, back-right)
}

function Arch.BuildBlacksmith(folder: Instance, centerCF: CFrame): Part
	local model = Instance.new("Model")
	model.Name = "Building_Blacksmith"
	model:SetAttribute("OpenForge", true)
	model.Parent = folder

	local stoneDark   = Color3.fromRGB(72, 76, 88)    -- #484C58 Slate Stone
	local stoneAshlar = Color3.fromRGB(104, 109, 122) -- #686D7A Ashlar Trim & Plinths
	local obsidianPad = Color3.fromRGB(26, 22, 34)    -- #1A1622 Pedestal Cushion
	local roofSlate   = Color3.fromRGB(43, 48, 58)    -- #2B303A Smelter Canopy Shingle
	local woodTimber  = Color3.fromRGB(74, 50, 33)    -- #4A3221 Heavy Timber Framing
	local woodFloor   = Color3.fromRGB(98, 66, 40)    -- Workbench Planks
	local brickHearth = Color3.fromRGB(92, 53, 44)    -- #5C352C Smelter Brick
	local ironDark    = Color3.fromRGB(38, 41, 48)    -- #262930 Wrought Iron
	local steelSilver = Color3.fromRGB(162, 170, 184) -- #A2AAB8 Polished Anvil Steel
	local bronzeTrim  = Color3.fromRGB(186, 138, 68)  -- #BA8A44 Gilded Forge Trim
	local emberOrange = Color3.fromRGB(255, 122, 26)  -- #FF7A1A Molten Forge Embers
	local moltenGold  = Color3.fromRGB(255, 196, 68)  -- #FFC444 Smelter Pour Glow
	local quenchWater = Color3.fromRGB(44, 120, 184)  -- #2C78B8 Quench Water

	local function addForgeFire(parentPart: BasePart, lightRange: number, lightBright: number, flameSize: number, rate: number)
		pointLight(parentPart, emberOrange, lightBright, lightRange, false)
		local fireEmit = Instance.new("ParticleEmitter")
		fireEmit.Name = "ForgeFlames"
		fireEmit.Texture = "rbxassetid://243660364"
		fireEmit.Color = ColorSequence.new(Color3.fromRGB(255, 225, 95), emberOrange)
		fireEmit.LightEmission = 0.95
		fireEmit.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, flameSize),
			NumberSequenceKeypoint.new(0.6, flameSize * 0.65),
			NumberSequenceKeypoint.new(1, 0.2),
		})
		fireEmit.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.12),
			NumberSequenceKeypoint.new(1, 1.0),
		})
		fireEmit.Lifetime = NumberRange.new(0.45, 0.85)
		fireEmit.Rate = rate
		fireEmit.Speed = NumberRange.new(2.5, 5.5)
		fireEmit.Acceleration = V(0, 8, 0)
		fireEmit.Parent = parentPart
	end

	-- Optional imported Blender OpenForge shell (never loads legacy enclosed BlacksmithForge house)
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	local customMeshes = assetsFolder and assetsFolder:FindFirstChild("CustomFacilityMeshes")
	local importedOpenForge = customMeshes and customMeshes:FindFirstChild("OpenForge")

	if importedOpenForge and importedOpenForge:IsA("Model") and importedOpenForge:FindFirstChildWhichIsA("MeshPart", true) then
		local cloned = importedOpenForge:Clone()
		cloned:PivotTo(centerCF)
		for _, desc in ipairs(cloned:GetDescendants()) do
			if desc:IsA("BasePart") then
				desc.Anchored = true
				desc.CanCollide = false
				desc.CanTouch = false
				desc.CanQuery = false
			end
		end
		for _, ch in ipairs(cloned:GetChildren()) do
			if not ch:IsA("PackageLink") then
				ch.Parent = model
			end
		end
		cloned:Destroy()
		part(model, "Col_TerraceSlab", V(37.0, 0.45, 27.0), centerCF * CFrame.new(0, 0.225, 0), stoneDark, Enum.Material.Slate, true).Transparency = 1
		part(model, "Col_SmelterHull", V(10.8, 10.0, 5.8), centerCF * CFrame.new(-10.5, 5.2, -9.2), stoneDark, Enum.Material.Slate, true).Transparency = 1
		part(model, "Col_AnvilHull", V(4.2, 4.2, 3.2), centerCF * CFrame.new(-10.5, 2.5, 4.8), ironDark, Enum.Material.Metal, true).Transparency = 1
	else
		--====================================================================
		-- 1. OPEN-AIR STONE TERRACE & REAR SMELTER SHELTER CANOPY (38 x 28)
		--    Zero front/side walls so players walk freely between Smelter,
		--    Anvil and all 6 3D Artifact Pedestals with clear sightlines!
		--====================================================================
		part(model, "TerraceMainSlab", V(36.0, 0.44, 26.0), centerCF * CFrame.new(0, 0.22, 0), stoneDark, Enum.Material.Slate, true)
		part(model, "TerraceFrontStep", V(36.0, 0.24, 1.6), centerCF * CFrame.new(0, 0.12, 13.8), stoneAshlar, Enum.Material.Cobblestone, true)
		for _, sx in ipairs({ -1, 1 }) do
			part(model, "TerraceSideCurb_" .. sx, V(1.0, 0.62, 26.0), centerCF * CFrame.new(sx * 18.5, 0.31, 0), stoneAshlar, Enum.Material.Cobblestone, true)
		end
		part(model, "TerraceBackRetainingWall", V(38.0, 3.6, 1.6), centerCF * CFrame.new(0, 1.8, -13.8), stoneDark, Enum.Material.Cobblestone, true)
		part(model, "TerraceBackCoping", V(38.4, 0.44, 2.0), centerCF * CFrame.new(0, 3.82, -13.8), stoneAshlar, Enum.Material.Slate, true)

		-- Checkerboard Courtyard Flagstones cleanly elevated above TerraceMainSlab (top 0.44 -> tiles 0.45..0.53)
		for ix = -5, 5 do
			for iz = -3, 3 do
				local col = ((ix + iz) % 2 == 0) and stoneAshlar or stoneDark
				part(model, "TerraceFlagstone", V(3.0, 0.08, 3.4), centerCF * CFrame.new(ix * 3.2, 0.49, iz * 3.6), col, Enum.Material.Cobblestone, false)
			end
		end

		-- Open-Sided Timber & Slate Shelter Canopy ONLY over Rear Smelter Bay (X = -17.2..-4.6, Z = -12.6..-5.4)
		for _, px in ipairs({ -17.2, -4.6 }) do
			for _, pz in ipairs({ -12.6, -5.4 }) do
				part(model, "CanopyPlinth", V(1.7, 1.32, 1.7), centerCF * CFrame.new(px, 1.19, pz), stoneAshlar, Enum.Material.Slate, true)
				part(model, "CanopyPost", V(1.05, 9.05, 1.05), centerCF * CFrame.new(px, 6.38, pz), woodTimber, Enum.Material.Wood, true)
			end
			part(model, "CanopyTieBeam", V(1.1, 0.95, 8.6), centerCF * CFrame.new(px, 11.4, -9.0), woodTimber, Enum.Material.Wood, false)
		end
		part(model, "CanopyFrontLintel", V(11.4, 0.95, 1.05), centerCF * CFrame.new(-10.9, 11.4, -5.4), woodTimber, Enum.Material.Wood, false)
		local canopyCF = centerCF * CFrame.new(-10.9, 12.65, -9.2) * CFrame.Angles(math.rad(14), 0, 0)
		part(model, "CanopyRoofDeck", V(15.2, 0.55, 10.2), canopyCF, roofSlate, Enum.Material.Slate, true)
		for r = -2, 2 do
			part(model, "CanopyShingle_" .. r, V(15.0, 0.20, 1.75), canopyCF * CFrame.new(0, 0.38, r * 1.9), (r % 2 == 0) and roofSlate or stoneDark, Enum.Material.Slate, false)
		end

		--====================================================================
		-- 2. ZONE A: BLAST SMELTER (`SmelterStation` at X = -10.5, Z = -9.2)
		--====================================================================
		local sx, sz = -10.5, -9.2
		part(model, "SmelterPlinth", V(10.8, 1.72, 5.8), centerCF * CFrame.new(sx, 1.39, sz), stoneAshlar, Enum.Material.Slate, true)
		for _, side in ipairs({ -1, 1 }) do
			part(model, "SmelterPier", V(2.5, 5.2, 5.2), centerCF * CFrame.new(sx + side * 3.8, 4.85, sz), brickHearth, Enum.Material.Brick, true)
			part(model, "SmelterIronBand", V(2.65, 0.35, 5.35), centerCF * CFrame.new(sx + side * 3.8, 6.2, sz), ironDark, Enum.Material.Metal, false)
		end
		part(model, "SmelterBackWall", V(5.0, 5.2, 1.8), centerCF * CFrame.new(sx, 4.85, sz - 1.9), brickHearth, Enum.Material.Brick, true)
		part(model, "SmelterLintel", V(10.6, 1.3, 5.5), centerCF * CFrame.new(sx, 8.10, sz), stoneAshlar, Enum.Material.Slate, true)
		part(model, "SmelterBronzeCrest", V(4.6, 0.55, 0.35), centerCF * CFrame.new(sx, 8.05, sz + 2.85), bronzeTrim, Enum.Material.Metal, false)
		part(model, "SmelterHood", V(8.4, 4.6, 4.4), centerCF * CFrame.new(sx, 11.0, sz - 0.2), stoneDark, Enum.Material.Slate, true)

		-- Tapered Stone Smokestack Flue rising through Canopy
		for cIdx = 0, 5 do
			local rCourse = 2.8 * (1.0 - 0.14 * (cIdx / 6))
			local yCourse = 13.8 + cIdx * 1.35
			cylinder(model, "SmelterChimney_" .. cIdx, rCourse, 1.3, centerCF * CFrame.new(sx, yCourse, sz - 0.4), (cIdx % 2 == 0) and stoneAshlar or stoneDark, Enum.Material.Cobblestone, true)
		end
		cylinder(model, "SmelterChimneyCrown", 2.65, 0.85, centerCF * CFrame.new(sx, 21.8, sz - 0.4), stoneAshlar, Enum.Material.Slate, true)

		-- Molten Pour Spout & Ingot Mold Trough in front of Smelter
		part(model, "SmelterSpoutBasin", V(3.2, 1.2, 1.8), centerCF * CFrame.new(sx, 2.35, sz + 3.1), ironDark, Enum.Material.Metal, true)
		part(model, "SmelterMoltenStream", V(1.1, 0.25, 2.4), centerCF * CFrame.new(sx, 2.98, sz + 2.5), moltenGold, Enum.Material.Neon, false)
		part(model, "SmelterIngotMold", V(2.2, 0.55, 1.1), centerCF * CFrame.new(sx, 2.0, sz + 4.1), ironDark, Enum.Material.Metal, false)
		part(model, "SmelterGlowIngot", V(1.6, 0.18, 0.65), centerCF * CFrame.new(sx, 2.32, sz + 4.1), emberOrange, Enum.Material.Neon, false)

		-- Articulated Bellows & Tuyere Pipe beside Smelter
		part(model, "SmelterBellowsFrame", V(2.6, 2.2, 3.4), centerCF * CFrame.new(sx - 6.1, 2.4, sz + 0.4) * CFrame.Angles(0, math.rad(16), 0), woodTimber, Enum.Material.Wood, true)
		cylinder(model, "SmelterTuyerePipe", 0.28, 2.4, centerCF * CFrame.new(sx - 4.8, 2.6, sz + 0.2) * CFrame.Angles(0, 0, math.rad(90)), ironDark, Enum.Material.Metal, false)

		--====================================================================
		-- 3. ZONE B: MASTER ANVIL (`AnvilStation` at X = -11.5, Z = +5.2)
		--====================================================================
		local ax, az = -11.5, 5.2
		cylinder(model, "AnvilStonePlinth", 2.6, 0.65, centerCF * CFrame.new(ax, 0.78, az), stoneAshlar, Enum.Material.Slate, true)
		cylinder(model, "AnvilOakBlock", 1.75, 1.65, centerCF * CFrame.new(ax, 1.92, az), woodTimber, Enum.Material.Wood, true)
		cylinder(model, "AnvilIronHoopTop", 1.82, 0.22, centerCF * CFrame.new(ax, 2.45, az), ironDark, Enum.Material.Metal, false)
		cylinder(model, "AnvilIronHoopLow", 1.82, 0.22, centerCF * CFrame.new(ax, 1.38, az), ironDark, Enum.Material.Metal, false)
		part(model, "AnvilBase", V(2.8, 0.52, 1.7), centerCF * CFrame.new(ax, 3.00, az), ironDark, Enum.Material.Metal, true)
		part(model, "AnvilWaist", V(1.9, 0.68, 1.2), centerCF * CFrame.new(ax, 3.58, az), ironDark, Enum.Material.Metal, true)
		part(model, "AnvilWorkingBody", V(3.6, 0.62, 1.52), centerCF * CFrame.new(ax, 4.20, az), ironDark, Enum.Material.Metal, true)
		part(model, "AnvilSteelFace", V(3.4, 0.10, 1.42), centerCF * CFrame.new(ax, 4.55, az), steelSilver, Enum.Material.Metal, true)
		part(model, "AnvilGoldFiligree", V(2.04, 0.22, 1.32), centerCF * CFrame.new(ax, 3.58, az), bronzeTrim, Enum.Material.Metal, false)
		wedge(model, "AnvilHorn", V(1.0, 0.56, 1.65), centerCF * CFrame.new(ax + 2.63, 4.22, az) * CFrame.Angles(0, math.pi * 0.5, math.pi), steelSilver, Enum.Material.Metal, true)

		-- Resting Forge Hammer atop Anvil Face
		local hamCF = centerCF * CFrame.new(ax - 0.5, 4.76, az + 0.12) * CFrame.Angles(0, math.rad(28), 0)
		part(model, "AnvilHammerShaft", V(1.8, 0.18, 0.18), hamCF, woodTimber, Enum.Material.Wood, false)
		part(model, "AnvilHammerHead", V(0.48, 0.42, 0.92), hamCF * CFrame.new(0.72, 0.08, 0), steelSilver, Enum.Material.Metal, false)

		-- Rear-Right Workshop Props (clear of Pedestal Gallery)
		cylinder(model, "QuenchBarrel", 1.45, 2.4, centerCF * CFrame.new(-5.8, 1.65, -10.4), woodTimber, Enum.Material.WoodPlanks, true)
		cylinder(model, "QuenchWaterDisc", 1.25, 0.22, centerCF * CFrame.new(-5.8, 2.78, -10.4), quenchWater, Enum.Material.Glass, false)
		addWeaponRack(model, centerCF * CFrame.new(6.8, 0.53, -11.4))
		part(model, "ForgeToolBench", V(6.4, 0.42, 2.6), centerCF * CFrame.new(13.6, 2.45, -11.2), woodFloor, Enum.Material.WoodPlanks, true)
		for _, lx in ipairs({ 11.0, 16.2 }) do
			part(model, "BenchLeg", V(0.45, 2.0, 2.2), centerCF * CFrame.new(lx, 1.45, -11.2), woodTimber, Enum.Material.Wood, true)
		end
		addBarrel(model, centerCF * CFrame.new(16.8, 0.53, -9.2), 0.92)

		-- Front Terrace Flanking Braziers (resting cleanly above terrace flagstones)
		for _, side in ipairs({ -1, 1 }) do
			local bx, bz = side * 16.5, 11.4
			part(model, "BrazierPlinth", V(2.8, 0.92, 2.8), centerCF * CFrame.new(bx, 0.99, bz), stoneAshlar, Enum.Material.Slate, true)
			cylinder(model, "BrazierBowl", 1.30, 0.88, centerCF * CFrame.new(bx, 1.89, bz), ironDark, Enum.Material.Metal, true)
		end
	end

	--========================================================================
	-- 4. ZONE C: 6 ARTIFACT DISPLAY PEDESTALS (`Pedestals/Pedestal_1..6`)
	--========================================================================
	local pedestalsFolder = Instance.new("Folder")
	pedestalsFolder.Name = "Pedestals"
	pedestalsFolder.Parent = model

	for idx, relOffset in ipairs(PEDESTAL_OFFSETS) do
		local pedCF = centerCF * CFrame.new(relOffset)
		local pedModel = Instance.new("Model")
		pedModel.Name = "Pedestal_" .. idx
		pedModel:SetAttribute("SlotIndex", idx)
		pedModel:SetAttribute("Unlocked", idx == 1)
		pedModel:SetAttribute("TemplateId", "")
		pedModel:SetAttribute("Cost", 0)
		pedModel:SetAttribute("RollSeq", 0)

		local pedRoot = part(pedModel, "PedestalRoot", V(3.0, 3.1, 3.0), pedCF * CFrame.new(0, 2.08, 0), stoneDark, Enum.Material.Slate, idx == 1)
		pedRoot.Transparency = 1
		pedModel.PrimaryPart = pedRoot

		-- Strictly stacked Y layers with zero coplanar overlap (base starts cleanly at flagstone top 0.53):
		--   PedestalBase: 0.53..1.08, Column: 1.08..2.98, Collar: 2.74..2.96 (wider radius),
		--   PedestalCap: 2.98..3.40, RuneRing: 3.40..3.48 (glowing outer rim), PedestalPad: 3.48..3.60 (raised dark cushion)
		local base = part(pedModel, "PedestalBase", V(3.2, 0.55, 3.2), pedCF * CFrame.new(0, 0.805, 0), stoneDark, Enum.Material.Slate, false)
		local col = cylinder(pedModel, "PedestalColumn", 1.05, 1.90, pedCF * CFrame.new(0, 2.03, 0), stoneAshlar, Enum.Material.Slate, false)
		local trim = cylinder(pedModel, "PedestalBronzeCollar", 1.15, 0.22, pedCF * CFrame.new(0, 2.85, 0), bronzeTrim, Enum.Material.Metal, false)
		local cap = part(pedModel, "PedestalCap", V(2.85, 0.42, 2.85), pedCF * CFrame.new(0, 3.19, 0), stoneAshlar, Enum.Material.Slate, false)
		local ring = cylinder(pedModel, "RuneRing", 1.28, 0.08, pedCF * CFrame.new(0, 3.44, 0), bronzeTrim, Enum.Material.Neon, false)
		local pad = cylinder(pedModel, "PedestalPad", 1.04, 0.12, pedCF * CFrame.new(0, 3.54, 0), obsidianPad, Enum.Material.SmoothPlastic, false)

		if idx > 1 then
			for _, p in ipairs({ base, col, trim, cap, pad, ring }) do
				p.Transparency = 1
			end
		end

		local displayAtt = Instance.new("Attachment")
		displayAtt.Name = "DisplayAnchor"
		displayAtt.Position = V(0, 3.7, 0) -- 5.78 studs above terrace ground
		displayAtt.Parent = pedRoot

		local promptAtt = Instance.new("Attachment")
		promptAtt.Name = "PromptAnchor"
		promptAtt.Position = V(0, 1.6, 0)
		promptAtt.Parent = pedRoot

		pedModel.Parent = pedestalsFolder
	end

	--========================================================================
	-- 5. DYNAMIC VFX, CLICKABLE ANVIL & SMELTER INTERACTION ANCHORS
	--========================================================================
	local emberBed = part(model, "GlowingEmbers", V(4.6, 0.8, 3.0), centerCF * CFrame.new(-10.5, 2.75, -9.0), emberOrange, Enum.Material.Neon, false)
	addForgeFire(emberBed, 30, 2.8, 2.0, 22)

	for _, side in ipairs({ -1, 1 }) do
		local brazierCore = sphere(
			model,
			if side < 0 then "BrazierFireLeft" else "BrazierFireRight",
			1.20,
			centerCF * CFrame.new(side * 16.5, 2.48, 11.4),
			emberOrange,
			Enum.Material.Neon
		)
		addForgeFire(brazierCore, 20, 2.0, 1.25, 14)
	end

	local chimneyFlue = cylinder(model, "ChimneySmokeAnchor", 1.9, 0.6, centerCF * CFrame.new(-10.5, 22.1, -9.6), emberOrange, Enum.Material.Neon, false)
	pointLight(chimneyFlue, emberOrange, 2.0, 24, false)

	local anvilSparkAnchor = part(model, "AnvilFace", V(3.2, 0.2, 1.3), centerCF * CFrame.new(-11.5, 4.62, 5.2), steelSilver, Enum.Material.Metal, false)
	anvilSparkAnchor.Transparency = 1
	local sparkEmit = Instance.new("ParticleEmitter")
	sparkEmit.Name = "AnvilSparks"
	sparkEmit.Texture = "rbxassetid://243660364"
	sparkEmit.Color = ColorSequence.new(Color3.fromRGB(255, 240, 130), emberOrange)
	sparkEmit.LightEmission = 1
	sparkEmit.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.32),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	sparkEmit.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparkEmit.Lifetime = NumberRange.new(0.32, 0.60)
	sparkEmit.Rate = 6
	sparkEmit.Speed = NumberRange.new(6, 12)
	sparkEmit.SpreadAngle = Vector2.new(75, 75)
	sparkEmit.Acceleration = V(0, -28, 0)
	sparkEmit.Parent = anvilSparkAnchor

	local strikeBurst = sparkEmit:Clone()
	strikeBurst.Name = "AnvilStrikeBurst"
	strikeBurst.Rate = 0
	strikeBurst.Speed = NumberRange.new(14, 26)
	strikeBurst.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.52),
		NumberSequenceKeypoint.new(1, 0.06),
	})
	strikeBurst.Parent = anvilSparkAnchor

	-- Anvil Prompt Anchor + Direct Click Hitbox (both trigger free Forge rerolls!)
	local anvilInteract = part(model, "AnvilInteraction", V(2, 2, 2), centerCF * CFrame.new(-11.5, 4.6, 5.2), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, false)
	anvilInteract.Transparency = 1

	local anvilClickBox = part(model, "AnvilClickBox", V(4.8, 4.6, 3.6), centerCF * CFrame.new(-11.5, 2.8, 5.2), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, false)
	anvilClickBox.Transparency = 1
	anvilClickBox.CanQuery = true
	local clickDetector = Instance.new("ClickDetector")
	clickDetector.Name = "AnvilClickDetector"
	clickDetector.MaxActivationDistance = 24
	clickDetector.Parent = anvilClickBox

	-- PrimaryRoot + Smelter FacilityInteraction (`BlacksmithPrompt` opens Smelter Artifacts & Upgrade UI)
	local interactionPart = finalizeFacilityModel(model, centerCF, V(38, 1.0, 28), V(-10.5, 4.2, -5.0))
	return interactionPart
end

--============================================================================
-- 2.6 TRAINING AREA (`TrainingArea` — Fenced Polygonal Cobblestone Combat Ring)
--============================================================================
local TG_PROPS_CM = "rbxassetid://108825920828981"
local TG_PROPS_NM = "rbxassetid://103410370581370"
local TG_PROPS_RM = "rbxassetid://116703552811362"
local TG_FLOOR_CM = "rbxassetid://113479401976759"
local TG_FLOOR_NM = "rbxassetid://128264443006045"
local TG_FLOOR_RM = "rbxassetid://86555471679808"

local TRAINING_GROUND_MESHES: { BundledMeshSpec } = {
	{ Name = "Arena_Floor", MeshId = "rbxassetid://107205650672236", Size = V(48.500000, 0.080008, 40.750000), Pos = V(0, 0.040000, 7.575134), PivotOffset = V(0, -0.0400, 7.5750), ColorMap = TG_FLOOR_CM, NormalMap = TG_FLOOR_NM, RoughnessMap = TG_FLOOR_RM, CastShadow = false },
	{ Name = "Entrance_Archway", MeshId = "rbxassetid://86958939031314", Size = V(13.612968, 11.690001, 4.458000), Pos = V(0, 5.845001, -12.028931), PivotOffset = V(0, -5.8450, -12.0290), ColorMap = TG_PROPS_CM, NormalMap = TG_PROPS_NM, RoughnessMap = TG_PROPS_RM, CastShadow = true },
	{ Name = "Perimeter_Fence", MeshId = "rbxassetid://133116725826364", Size = V(48.079998, 3.200007, 39.980000), Pos = V(0, 1.599998, 7.750061), PivotOffset = V(0, -1.6000, 7.7500), ColorMap = TG_PROPS_CM, NormalMap = TG_PROPS_NM, RoughnessMap = TG_PROPS_RM, CastShadow = true },
	{ Name = "Training_Props", MeshId = "rbxassetid://101080363217091", Size = V(44.995201, 5.732375, 36.785378), Pos = V(0, 2.841270, 5.185791), PivotOffset = V(0, -2.8413, 5.1857), ColorMap = TG_PROPS_CM, NormalMap = TG_PROPS_NM, RoughnessMap = TG_PROPS_RM, CastShadow = true },
	{ Name = "Dummy_1_Base", MeshId = "rbxassetid://99125394433707", Size = V(2.299000, 1.190000, 2.299000), Pos = V(-8.500000, 0.675000, -1.500000), PivotOffset = V(0, -0.5950, 0), ColorMap = TG_PROPS_CM, NormalMap = TG_PROPS_NM, RoughnessMap = TG_PROPS_RM, CastShadow = true },
	{ Name = "Dummy_1_Body", MeshId = "rbxassetid://86192274983173", Size = V(1.955179, 4.465000, 2.852854), Pos = V(-8.500000, 3.457500, -1.500000), PivotOffset = V(0, -2.2275, 0), ColorMap = TG_PROPS_CM, NormalMap = TG_PROPS_NM, RoughnessMap = TG_PROPS_RM, CastShadow = true },
	{ Name = "Dummy_2_Base", MeshId = "rbxassetid://140129259261171", Size = V(2.360000, 1.190000, 2.360000), Pos = V(0, 0.674999, 2.000000), PivotOffset = V(0, -0.5950, 0), ColorMap = TG_PROPS_CM, NormalMap = TG_PROPS_NM, RoughnessMap = TG_PROPS_RM, CastShadow = true },
	{ Name = "Dummy_2_Body", MeshId = "rbxassetid://117182456500032", Size = V(3.150000, 4.465000, 1.673859), Pos = V(0, 3.457500, 2.000000), PivotOffset = V(0, -2.2275, 0), ColorMap = TG_PROPS_CM, NormalMap = TG_PROPS_NM, RoughnessMap = TG_PROPS_RM, CastShadow = true },
	{ Name = "Dummy_3_Base", MeshId = "rbxassetid://132106594732171", Size = V(2.299000, 1.190000, 2.299000), Pos = V(8.500000, 0.675000, -1.500000), PivotOffset = V(0, -0.5950, 0), ColorMap = TG_PROPS_CM, NormalMap = TG_PROPS_NM, RoughnessMap = TG_PROPS_RM, CastShadow = true },
	{ Name = "Dummy_3_Body", MeshId = "rbxassetid://87751998200386", Size = V(1.955179, 4.465000, 2.852854), Pos = V(8.500000, 3.457500, -1.500000), PivotOffset = V(0, -2.2275, 0), ColorMap = TG_PROPS_CM, NormalMap = TG_PROPS_NM, RoughnessMap = TG_PROPS_RM, CastShadow = true },
	{ Name = "Dummy_4_Base", MeshId = "rbxassetid://74666535097921", Size = V(2.242216, 1.190000, 2.242216), Pos = V(-6.200000, 0.675000, 11.200000), PivotOffset = V(0, -0.5950, 0), ColorMap = TG_PROPS_CM, NormalMap = TG_PROPS_NM, RoughnessMap = TG_PROPS_RM, CastShadow = true },
	{ Name = "Dummy_4_Body", MeshId = "rbxassetid://113994151162337", Size = V(2.964515, 4.465000, 1.739178), Pos = V(-6.200000, 3.457500, 11.200000), PivotOffset = V(0, -2.2275, 0), ColorMap = TG_PROPS_CM, NormalMap = TG_PROPS_NM, RoughnessMap = TG_PROPS_RM, CastShadow = true },
	{ Name = "Dummy_5_Base", MeshId = "rbxassetid://123098187620011", Size = V(2.242216, 1.190000, 2.242216), Pos = V(6.200000, 0.675000, 11.200000), PivotOffset = V(0, -0.5950, 0), ColorMap = TG_PROPS_CM, NormalMap = TG_PROPS_NM, RoughnessMap = TG_PROPS_RM, CastShadow = true },
	{ Name = "Dummy_5_Body", MeshId = "rbxassetid://77160486416462", Size = V(2.964515, 4.465000, 1.739178), Pos = V(6.200000, 3.457500, 11.200000), PivotOffset = V(0, -2.2275, 0), ColorMap = TG_PROPS_CM, NormalMap = TG_PROPS_NM, RoughnessMap = TG_PROPS_RM, CastShadow = true },
}

function Arch.BuildTrainingGrounds(folder: Instance, centerCF: CFrame): Part
	local model = Instance.new("Model")
	model.Name = "Building_TrainingGrounds"
	model.Parent = folder

	if not instantiateBundledMeshes("TrainingArea", TRAINING_GROUND_MESHES, model, centerCF) then
		warn("[PlotFacilityArchitecture] Failed to load TrainingGrounds MeshParts")
	end

	-- Invisible solid collision hull for V-gable archway stone piers & 8 perimeter fence spans
	-- (central 8.0x6.2 doorway opening stays 100% passable from Path_TrainingArea)
	local colColor = Color3.fromRGB(92, 86, 78)
	local function addCollider(cName: string, sz: Vector3, relCF: CFrame)
		local cp = part(model, cName, sz, centerCF * relCF, colColor, Enum.Material.Wood, true)
		cp.Transparency = 1
		cp.CastShadow = false
		return cp
	end

	addCollider("ArchPierCollider_L", V(2.2, 6.8, 2.4), CFrame.new(5.0, 3.4, -12.0))
	addCollider("ArchPierCollider_R", V(2.2, 6.8, 2.4), CFrame.new(-5.0, 3.4, -12.0))
	addCollider("ArchHeaderCollider", V(12.4, 5.0, 2.4), CFrame.new(0, 8.9, -12.0))

	local fenceVertices = {
		V(5.0, 0, -12.0),
		V(16.0, 0, -9.5),
		V(23.8, 0, 2.5),
		V(12.0, 0, 18.5),
		V(0.0, 0, 27.5),
		V(-12.0, 0, 18.5),
		V(-23.8, 0, 2.5),
		V(-16.0, 0, -9.5),
		V(-5.0, 0, -12.0),
	}
	for i = 1, #fenceVertices - 1 do
		local a = fenceVertices[i]
		local b = fenceVertices[i + 1]
		local p1 = V(a.X, 1.8, a.Z)
		local p2 = V(b.X, 1.8, b.Z)
		local mid = (p1 + p2) * 0.5
		local segLen = (p2 - p1).Magnitude + 0.4
		addCollider("FenceCollider_" .. i, V(0.85, 3.6, segLen), CFrame.lookAt(mid, p2))
	end

	-- Subtle warm evening bounce lights at gable entrance and courtyard center (non-colliding invisible emitters)
	local archLightHost = part(model, "ArchLanternLightHost", V(0.4, 0.4, 0.4), centerCF * CFrame.new(0, 5.6, -11.8), colColor, Enum.Material.SmoothPlastic, false)
	archLightHost.Transparency = 1
	archLightHost.CanQuery = false
	pointLight(archLightHost, Color3.fromRGB(255, 185, 105), 0.9, 22, false)

	local arenaLightHost = part(model, "ArenaAmbientLightHost", V(0.4, 0.4, 0.4), centerCF * CFrame.new(0, 5.2, 2.5), colColor, Enum.Material.SmoothPlastic, false)
	arenaLightHost.Transparency = 1
	arenaLightHost.CanQuery = false
	pointLight(arenaLightHost, Color3.fromRGB(255, 200, 130), 0.7, 28, false)

	local interactionPart = finalizeFacilityModel(model, centerCF, V(4, 1.0, 4), V(0, 3.8, -11.5))
	return interactionPart
end

--============================================================================
-- 2.7 GUARDPOST OUTSKIRTS (`GuardpostOutskirts` — Watch Tower, Campfire & Fence)
--============================================================================
local GP_GROUND_CM = "rbxassetid://83407987265427"
local GP_GROUND_NM = "rbxassetid://76071562517147"
local GP_GROUND_RM = "rbxassetid://101783415919888"
local GP_PROPS_CM = "rbxassetid://76221190618895"
local GP_PROPS_NM = "rbxassetid://126518725174381"
local GP_PROPS_RM = "rbxassetid://114591375821153"

local GUARDPOST_OUTSKIRTS_MESHES: { BundledMeshSpec } = {
	{ Name = "GuardTower_CobblePad", MeshId = "rbxassetid://70780784796261", Size = V(12.6563, 1.3460, 12.6121), Pos = V(16.6867, 0.6730, -14.2553), PivotOffset = V(16.6867, -0.6730, -14.2553), ColorMap = GP_GROUND_CM, NormalMap = GP_GROUND_NM, RoughnessMap = GP_GROUND_RM, CastShadow = false },
	{ Name = "GuardTower_Structure", MeshId = "rbxassetid://94962682973717", Size = V(12.3770, 17.4903, 13.2736), Pos = V(16.5000, 8.7503, -14.0517), PivotOffset = V(16.5000, -8.7503, -14.0517), ColorMap = GP_PROPS_CM, NormalMap = GP_PROPS_NM, RoughnessMap = GP_PROPS_RM, CastShadow = true },
	{ Name = "GuardTower_Roof", MeshId = "rbxassetid://92789248062540", Size = V(10.5261, 4.0905, 10.2756), Pos = V(16.5000, 16.0248, -14.5000), PivotOffset = V(16.5000, -16.0248, -14.5000), ColorMap = GP_PROPS_CM, NormalMap = GP_PROPS_NM, RoughnessMap = GP_PROPS_RM, CastShadow = true },
	{ Name = "GuardTower_Props", MeshId = "rbxassetid://117458340250669", Size = V(8.0746, 11.3226, 13.2277), Pos = V(14.3302, 5.6387, -14.8373), PivotOffset = V(14.3302, -5.6387, -14.8373), ColorMap = GP_PROPS_CM, NormalMap = GP_PROPS_NM, RoughnessMap = GP_PROPS_RM, CastShadow = true },
	{ Name = "Campfire_StoneHearth", MeshId = "rbxassetid://110052336686192", Size = V(6.2031, 0.8191, 6.2499), Pos = V(-14.1897, 0.4196, -6.4306), PivotOffset = V(-14.1897, -0.4196, -6.4306), ColorMap = GP_GROUND_CM, NormalMap = GP_GROUND_NM, RoughnessMap = GP_GROUND_RM, CastShadow = false },
	{ Name = "Campfire_Area", MeshId = "rbxassetid://140525333251753", Size = V(13.3646, 2.7893, 12.0661), Pos = V(-13.8378, 1.1553, -6.6107), PivotOffset = V(-13.8378, -1.1553, -6.6107), ColorMap = GP_PROPS_CM, NormalMap = GP_PROPS_NM, RoughnessMap = GP_PROPS_RM, CastShadow = true },
	{ Name = "Outskirts_Fence", MeshId = "rbxassetid://99231170039569", Size = V(30.4008, 4.4655, 14.8666), Pos = V(-19.5393, 2.2182, 6.3059), PivotOffset = V(-19.5393, -2.2182, 6.3059), ColorMap = GP_PROPS_CM, NormalMap = GP_PROPS_NM, RoughnessMap = GP_PROPS_RM, CastShadow = true },
}

local function buildGuardPostProceduralFallback(model: Model, centerCF: CFrame, fireCenter: CFrame)
	local timberLog = Color3.fromRGB(94, 62, 36)
	local darkTimber = Color3.fromRGB(68, 44, 26)
	local stoneRing = Color3.fromRGB(82, 86, 94)

	local towerCF = centerCF * CFrame.new(16.5, 0, -14.5) * CFrame.Angles(0, math.rad(-82), 0)
	part(model, "WatchBaseDeck", V(12.0, 1.0, 12.0), towerCF * CFrame.new(0, 0.5, 0), stoneRing, Enum.Material.Cobblestone, true)
	for _, sx in ipairs({ -4.2, 4.2 }) do
		for _, sz in ipairs({ -4.2, 4.2 }) do
			cylinder(model, "WatchLogPillar", 0.65, 13.5, towerCF * CFrame.new(sx, 6.75, sz), darkTimber, Enum.Material.Wood, true)
		end
	end
	part(model, "WatchUpperPlatform", V(10.2, 0.7, 10.2), towerCF * CFrame.new(0, 7.6, 0), timberLog, Enum.Material.WoodPlanks, true)
	part(model, "WatchGableHut", V(8.2, 5.2, 7.6), towerCF * CFrame.new(0, 10.6, 0), darkTimber, Enum.Material.WoodPlanks, true)

	for r = 1, 10 do
		local a = ((r - 1) / 10) * math.pi * 2
		part(
			model,
			"CampfireStone_" .. r,
			V(1.3, 0.85, 1.0),
			fireCenter * CFrame.new(math.cos(a) * 2.1, 0.42, math.sin(a) * 2.1) * CFrame.Angles(0, -a, 0),
			stoneRing,
			Enum.Material.Slate,
			false
		)
	end
end

function Arch.BuildGuardPost(folder: Instance, centerCF: CFrame): Part
	local model = Instance.new("Model")
	model.Name = "Building_GuardPost"
	model.Parent = folder

	local fireWarm = Color3.fromRGB(255, 152, 56)
	local fireCenter = centerCF * CFrame.new(-14.0, 0, -6.5)

	if not instantiateBundledMeshes("GuardpostOutskirts", GUARDPOST_OUTSKIRTS_MESHES, model, centerCF) then
		warn("[PlotFacilityArchitecture] Failed to load GuardpostOutskirts MeshParts; using procedural fallback")
		buildGuardPostProceduralFallback(model, centerCF, fireCenter)
	end

	-- Invisible solid collision hulls (tower structure/props, campfire pit, 3 felled log benches, 4 fence spans)
	local colColor = Color3.fromRGB(92, 86, 78)
	local function addCollider(cName: string, sz: Vector3, relCF: CFrame)
		local cp = part(model, cName, sz, centerCF * relCF, colColor, Enum.Material.Wood, true)
		cp.Transparency = 1
		cp.CastShadow = false
		return cp
	end

	addCollider(
		"TowerBaseCollider",
		V(10.6, 16.5, 10.6),
		CFrame.new(16.5, 8.25, -14.5) * CFrame.Angles(0, math.rad(-82), 0)
	)
	addCollider("CampfireCollider", V(4.2, 2.2, 4.2), CFrame.new(-14.0, 1.1, -6.5))

	for idx, logSpec in ipairs({
		{ dx = -2.6, dz = -3.7, len = 6.0, rad = 0.86 },
		{ dx = -3.2, dz = 3.2, len = 5.8, rad = 0.85 },
		{ dx = 3.4, dz = 3.0, len = 5.6, rad = 0.84 },
	}) do
		local yaw = math.atan2(-logSpec.dz, logSpec.dx)
		addCollider(
			"LogBenchCollider_" .. idx,
			V(logSpec.rad * 2.0, logSpec.rad * 1.85, logSpec.len),
			CFrame.new(-14.0 + logSpec.dx, logSpec.rad * 0.9, -6.5 + logSpec.dz) * CFrame.Angles(0, yaw, 0)
		)
	end

	local fenceSegments = {
		{ a = V(-34.2, 1.7, 1.5), b = V(-31.2, 1.7, 2.1), h = 3.4, w = 0.9 },
		{ a = V(-31.2, 1.7, 2.1), b = V(-28.0, 1.7, 3.2), h = 3.4, w = 0.9 },
		{ a = V(-28.0, 1.7, 3.2), b = V(-24.0, 1.7, 5.0), h = 3.4, w = 0.9 },
		{ a = V(-24.0, 1.7, 5.0), b = V(-18.5, 1.7, 8.1), h = 3.4, w = 0.9 },
		{ a = V(-18.5, 1.7, 8.1), b = V(-15.8, 1.7, 9.7), h = 3.4, w = 0.9 },
		{ a = V(-15.8, 1.7, 9.7), b = V(-13.2, 1.7, 10.4), h = 3.4, w = 0.9 },
		{ a = V(-13.2, 1.7, 10.4), b = V(-9.8, 1.7, 12.6), h = 3.4, w = 0.9 },
		{ a = V(-9.8, 1.7, 12.6), b = V(-7.0, 1.7, 13.2), h = 3.4, w = 0.9 },
		{ a = V(-7.0, 1.7, 13.2), b = V(-6.5, 1.7, 10.3), h = 3.4, w = 0.9 },
		{ a = V(-6.5, 1.7, 10.3), b = V(-6.2, 1.7, 7.0), h = 3.4, w = 0.9 },
		{ a = V(-6.2, 1.7, 7.0), b = V(-5.7, 1.7, 3.5), h = 3.4, w = 0.9 },
		{ a = V(-5.7, 1.7, 3.5), b = V(-4.9, 1.7, -0.6), h = 3.4, w = 0.9 },
	}
	for idx, seg in ipairs(fenceSegments) do
		local mid = (seg.a + seg.b) * 0.5
		local segLen = (seg.b - seg.a).Magnitude + 0.6
		addCollider("FenceCollider_" .. idx, V(seg.w, seg.h, segLen), CFrame.lookAt(mid, seg.b))
	end

	-- Hanging Watchtower Lantern Flame & Warm Evening PointLight
	local lanternHost = part(
		model,
		"TowerLanternLightHost",
		V(0.54, 0.78, 0.54),
		centerCF * CFrame.new(12.80, 12.15, -9.59),
		Color3.fromRGB(255, 200, 92),
		Enum.Material.Neon,
		false
	)
	lanternHost.Transparency = 0.15
	lanternHost.CanTouch = false
	lanternHost.CanQuery = false
	lanternHost.CastShadow = false
	pointLight(lanternHost, Color3.fromRGB(255, 180, 78), 2.4, 24, true)

	-- Crackling Campfire Core, Flames & Rising Embers
	local fireCore = sphere(model, "CampfireFlameCore", 0.85, fireCenter * CFrame.new(0, 0.72, 0), Color3.fromRGB(255, 118, 28), Enum.Material.Neon)
	fireCore.Transparency = 0.35
	fireCore.CanTouch = false
	fireCore.CanQuery = false
	fireCore.CastShadow = false
	pointLight(fireCore, fireWarm, 2.8, 28, true)

	local campFireEmit = Instance.new("ParticleEmitter")
	campFireEmit.Name = "CampfireFlames"
	campFireEmit.Texture = "rbxassetid://243660364"
	campFireEmit.Color = ColorSequence.new(Color3.fromRGB(255, 228, 118), fireWarm)
	campFireEmit.LightEmission = 0.95
	campFireEmit.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.55),
		NumberSequenceKeypoint.new(0.6, 0.95),
		NumberSequenceKeypoint.new(1, 0.18),
	})
	campFireEmit.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(1, 1.0),
	})
	campFireEmit.Lifetime = NumberRange.new(0.55, 1.05)
	campFireEmit.Rate = 22
	campFireEmit.Speed = NumberRange.new(2.6, 5.2)
	campFireEmit.SpreadAngle = Vector2.new(18, 18)
	campFireEmit.Acceleration = V(0, 6.5, 0)
	campFireEmit.Parent = fireCore

	local sparksEmit = Instance.new("ParticleEmitter")
	sparksEmit.Name = "CampfireSparks"
	sparksEmit.Texture = "rbxassetid://243660364"
	sparksEmit.Color = ColorSequence.new(Color3.fromRGB(255, 240, 160), Color3.fromRGB(255, 130, 35))
	sparksEmit.LightEmission = 1
	sparksEmit.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.20),
		NumberSequenceKeypoint.new(1, 0.03),
	})
	sparksEmit.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.8, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparksEmit.Lifetime = NumberRange.new(1.0, 1.9)
	sparksEmit.Rate = 10
	sparksEmit.Speed = NumberRange.new(3.5, 6.5)
	sparksEmit.SpreadAngle = Vector2.new(32, 32)
	sparksEmit.Acceleration = V(0, 3.0, 0)
	sparksEmit.Parent = fireCore

	local interactionPart = finalizeFacilityModel(model, centerCF, V(4, 1.0, 4), V(3.5, 3.8, -12.0))
	local roofLabelPos = (centerCF * CFrame.new(16.5, 20.3, -14.5)).Position
	interactionPart:SetAttribute("BillboardStudsOffset", roofLabelPos - interactionPart.Position)
	return interactionPart
end

--============================================================================
-- 2.8 COMMAND POST (War Banner & Architect's Table for Squad & Fortress Tree)
--============================================================================
function Arch.BuildCommandPost(
	folder: Instance,
	bannerCF: CFrame,
	tableCF: CFrame
): { SquadBanner: Part, ArchitectTable: Part }
	local model = Instance.new("Model")
	model.Name = "Building_CommandPost"
	model.Parent = folder

	local stoneBase = Color3.fromRGB(64, 68, 78)
	local goldTrim = Color3.fromRGB(235, 190, 68)
	local crimsonFabric = Color3.fromRGB(155, 28, 34)
	local woodOak = Color3.fromRGB(98, 66, 40)

	-- 1. War Banner (`Facility_SquadManagement`)
	cylinder(model, "WarBannerPedestal", 3.6, 1.2, bannerCF * CFrame.new(0, 0.6, 0), stoneBase, Enum.Material.Slate, true)
	local pole = cylinder(model, "WarBannerMast", 0.35, 13.5, bannerCF * CFrame.new(0, 7.2, 0), goldTrim, Enum.Material.Metal, true)
	part(model, "WarBannerCrossbar", V(5.2, 0.35, 0.35), bannerCF * CFrame.new(0, 12.6, 0), goldTrim, Enum.Material.Metal, false)
	local cloth = part(
		model,
		"WarBannerCloth",
		V(4.2, 8.2, 0.25),
		bannerCF * CFrame.new(0, 8.2, 0),
		crimsonFabric,
		Enum.Material.Fabric,
		false
	)
	part(model, "WarBannerCrest", V(2.2, 5.4, 0.32), bannerCF * CFrame.new(0, 8.4, 0), goldTrim, Enum.Material.Neon, false)
	pointLight(cloth, goldTrim, 1.4, 16, false)

	local bannerAnchor = part(model, "SquadBannerAnchor", V(2, 2, 2), bannerCF * CFrame.new(0, 3.8, 0), stoneBase, Enum.Material.SmoothPlastic, false)
	bannerAnchor.Transparency = 1
	model.PrimaryPart = pole

	-- 2. Architect's Table (`Facility_ArchitectTable` — Fortress Tree)
	cylinder(model, "ArchitectDais", 5.2, 0.8, tableCF * CFrame.new(0, 0.4, 0), stoneBase, Enum.Material.Slate, true)
	part(model, "ArchitectTablePedestal", V(5.6, 2.8, 3.8), tableCF * CFrame.new(0, 2.0, 0), woodOak, Enum.Material.Wood, true)
	local tableTop = part(model, "ArchitectTableTop", V(6.6, 0.5, 4.6), tableCF * CFrame.new(0, 3.6, 0), stoneBase, Enum.Material.Marble, true)
	part(
		model,
		"BlueprintMap",
		V(5.2, 0.12, 3.4),
		tableCF * CFrame.new(0, 3.9, 0),
		Color3.fromRGB(56, 189, 248),
		Enum.Material.Neon,
		false
	).Transparency = 0.25
	pointLight(tableTop, Color3.fromRGB(56, 189, 248), 1.5, 18, false)

	local tableAnchor = part(model, "ArchitectTableAnchor", V(2, 2, 2), tableCF * CFrame.new(0, 3.8, 0), stoneBase, Enum.Material.SmoothPlastic, false)
	tableAnchor.Transparency = 1

	return {
		SquadBanner = bannerAnchor,
		ArchitectTable = tableAnchor,
	}
end

--============================================================================
-- 2.9 REGISTER PREFABS IN `ReplicatedStorage.Assets.PlotFacilities`
--============================================================================
function Arch.EnsureFacilityPrefabs(): Folder
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	if not assetsFolder then
		local f = Instance.new("Folder")
		f.Name = "Assets"
		f.Parent = ReplicatedStorage
		assetsFolder = f
	end

	local existing = assetsFolder:FindFirstChild("PlotFacilities")
	if existing and existing:GetAttribute("PrefabVersion") == 32 then
		return existing :: Folder
	end
	if existing then
		existing:Destroy()
	end

	local prefabs = Instance.new("Folder")
	prefabs.Name = "PlotFacilities"
	prefabs:SetAttribute("PrefabVersion", 32)
	prefabs.Parent = assetsFolder

	local tempHolder = Instance.new("Folder")

	Arch.BuildSummoning(tempHolder, CFrame.identity)
	local summonModel = tempHolder:FindFirstChild("Building_Summoning")
	if summonModel then
		summonModel.Name = "SummoningPortal"
		summonModel.Parent = prefabs
	end

	Arch.BuildMarket(tempHolder, CFrame.identity)
	local marketModel = tempHolder:FindFirstChild("Building_Market")
	if marketModel then
		marketModel.Name = "MarketCluster"
		marketModel.Parent = prefabs
	end

	Arch.BuildThePit(tempHolder, CFrame.identity)
	local pitModel = tempHolder:FindFirstChild("Building_ThePit")
	if pitModel then
		pitModel.Name = "SynthesisChamber"
		pitModel.Parent = prefabs
	end

	Arch.BuildBlacksmith(tempHolder, CFrame.identity)
	local forgeModel = tempHolder:FindFirstChild("Building_Blacksmith")
	if forgeModel then
		forgeModel.Name = "BlacksmithForge"
		forgeModel.Parent = prefabs
	end

	Arch.BuildTrainingGrounds(tempHolder, CFrame.identity)
	local trainingModel = tempHolder:FindFirstChild("Building_TrainingGrounds")
	if trainingModel then
		trainingModel.Name = "TrainingArea"
		trainingModel.Parent = prefabs
	end

	Arch.BuildGuardPost(tempHolder, CFrame.identity)
	local gpModel = tempHolder:FindFirstChild("Building_GuardPost")
	if gpModel then
		gpModel.Name = "GuardpostOutskirts"
		gpModel.Parent = prefabs
	end

	tempHolder:Destroy()
	return prefabs
end

return Arch
