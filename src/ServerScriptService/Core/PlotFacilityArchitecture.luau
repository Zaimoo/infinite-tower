--!strict
-- ServerScriptService/Core/PlotFacilityArchitecture.luau
-- Waiting Room Plot Island Redesign (Phase 2):
-- Builds high-detail gothic fortress courtyard facilities & registers standardized prefabs under
-- ReplicatedStorage.Assets.PlotFacilities with ground-level PrimaryPart and PromptAnchor attachments:
--   1. SummoningPortal    (Monumental Circular Stone Stargate with #22D3EE cyan runes & light beam)
--   2. LeaderboardBoard   (Recessed #0D0912 Obsidian Wall Board with #FACC15 gold neon trim)
--   3. MarketCluster      (4-Stall U-Shaped Merchant Bazaar with striped awnings, barrels, crates, warm lights)
--   4. SynthesisChamber   (Cylindrical Gothic Stone Rotunda with cyan barrier arch & #C084FC purple oculus plume)
--   5. BlacksmithForge    (Open-Air Stone Hearth & Chimney against Dividing Wall, anvil sparks, coal, trough)
--   6. TrainingArea       (28-Stud Circular Cobblestone Ring, split-rail fences, 4 straw dummies, bullseye target)
--   7. GuardpostOutskirts (Timber Palisade Watch-Post, slatted roof, stone-ringed campfire & log seating)
--   8. CommandPost        (War Banner & Architect's Table for Squad Management & Fortress Tree)

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

--============================================================================
-- 2.1 SUMMONING PORTAL (`SummoningPortal` — Wall-Mounted Gothic Corner Portal)
--============================================================================
function Arch.BuildSummoning(folder: Instance, centerCF: CFrame): Part
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

	-- Outward Volumetric God-Ray Beams spilling down the steps onto the courtyard floor (enabled when doors open)
	for rayIdx = 1, 4 do
		local spreadX = (rayIdx - 2.5) * 3.2
		local rayTarget = makeSocket("GodRayFloorSocket_" .. rayIdx, V(spreadX, 0.15, 10.2))
		local godRay = Instance.new("Beam")
		godRay.Name = "GodRayBeam_" .. rayIdx
		godRay.Attachment0 = centerVFXSocket
		godRay.Attachment1 = rayTarget
		godRay.Color = ColorSequence.new(zone4Vortex, zone3RuneGlow)
		godRay.LightEmission = 1
		godRay.LightInfluence = 0
		godRay.Width0 = 2.4
		godRay.Width1 = 5.8
		godRay.FaceCamera = true
		godRay.Enabled = false
		godRay.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 0.68),
			NumberSequenceKeypoint.new(0.6, 0.85),
			NumberSequenceKeypoint.new(1.0, 1.0),
		})
		godRay.Parent = primaryRoot
	end

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
function Arch.BuildMarket(folder: Instance, centerCF: CFrame): Part
	local model = Instance.new("Model")
	model.Name = "Building_Market"
	model.Parent = folder

	local woodDark = Color3.fromRGB(96, 64, 38)
	local woodLight = Color3.fromRGB(132, 92, 56)
	local stoneCurb = Color3.fromRGB(78, 82, 90)
	local warmGlow = Color3.fromRGB(255, 170, 75)

	-- Cobblestone Bazaar Apron
	part(
		model,
		"BazaarCobblePad",
		V(38, 0.3, 30),
		centerCF * CFrame.new(0, 0.15, 0),
		stoneCurb,
		Enum.Material.Cobblestone,
		false
	)

	-- Helper to build an individual market stall with custom awning stripes
	local function buildStall(stallName: string, stallCF: CFrame, stripeColorA: Color3, stripeColorB: Color3)
		-- Wooden counter
		part(model, stallName .. "_Counter", V(9.6, 3.2, 3.2), stallCF * CFrame.new(0, 1.6, 2.2), woodDark, Enum.Material.WoodPlanks, true)
		part(model, stallName .. "_CounterTop", V(10.2, 0.35, 3.6), stallCF * CFrame.new(0, 3.3, 2.2), woodLight, Enum.Material.Wood, false)

		-- 4 Corner Posts
		for _, sx in ipairs({ -4.5, 4.5 }) do
			for _, sz in ipairs({ -3.0, 3.0 }) do
				part(model, stallName .. "_Post", V(0.65, 9.2, 0.65), stallCF * CFrame.new(sx, 4.6, sz), woodDark, Enum.Material.Wood, false)
			end
		end

		-- Sloped Striped Awning (5 fabric panels)
		local awningCenter = stallCF * CFrame.new(0, 9.4, 0.2) * CFrame.Angles(math.rad(14), 0, 0)
		for s = -2, 2 do
			local col = (s % 2 == 0) and stripeColorA or stripeColorB
			part(
				model,
				stallName .. "_AwningStripe_" .. (s + 3),
				V(2.15, 0.45, 8.2),
				awningCenter * CFrame.new(s * 2.1, 0, 0),
				col,
				Enum.Material.Fabric,
				false
			)
		end

		-- Warm Interior PointLight (Color = (255, 170, 75), Range = 18)
		local lantern = sphere(
			model,
			stallName .. "_Lantern",
			1.1,
			stallCF * CFrame.new(0, 7.6, 0.8),
			warmGlow,
			Enum.Material.Neon
		)
		pointLight(lantern, warmGlow, 1.8, 18, false)

		-- Display goods on counter (colored fruit/relic crates)
		for g = -1, 1 do
			local crateCF = stallCF * CFrame.new(g * 2.8, 3.8, 2.2)
			part(model, stallName .. "_GoodsTray", V(2.1, 0.6, 2.0), crateCF, woodDark, Enum.Material.WoodPlanks, false)
			local goodColor = if g == -1
				then Color3.fromRGB(220, 65, 55)
				elseif g == 0 then Color3.fromRGB(245, 195, 55)
				else Color3.fromRGB(75, 185, 95)
			sphere(model, stallName .. "_RelicItem", 0.9, crateCF * CFrame.new(-0.4, 0.45, 0), goodColor, Enum.Material.SmoothPlastic)
			sphere(model, stallName .. "_RelicItem2", 0.85, crateCF * CFrame.new(0.45, 0.42, 0.2), goodColor, Enum.Material.SmoothPlastic)
		end

		-- Merchant wooden stool behind counter
		cylinder(model, stallName .. "_Stool", 0.9, 1.6, stallCF * CFrame.new(0, 0.8, -1.4), woodLight, Enum.Material.Wood, false)
	end

	-- 4 Market Stalls arranged in a gentle U-shape:
	-- 1 Red/Amber striped awning, 2 Tan canvas awnings, 1 Green/White striped awning
	buildStall(
		"Stall_RedAmber",
		centerCF * CFrame.new(-11.5, 0, -3.5) * CFrame.Angles(0, math.rad(28), 0),
		Color3.fromRGB(185, 38, 38),
		Color3.fromRGB(235, 168, 48)
	)
	buildStall(
		"Stall_TanLeft",
		centerCF * CFrame.new(-4.2, 0, -8.5) * CFrame.Angles(0, math.rad(8), 0),
		Color3.fromRGB(212, 192, 154),
		Color3.fromRGB(188, 166, 128)
	)
	buildStall(
		"Stall_TanRight",
		centerCF * CFrame.new(6.2, 0, -8.0) * CFrame.Angles(0, math.rad(-12), 0),
		Color3.fromRGB(212, 192, 154),
		Color3.fromRGB(192, 170, 132)
	)
	buildStall(
		"Stall_GreenWhite",
		centerCF * CFrame.new(12.5, 0, -1.5) * CFrame.Angles(0, math.rad(-38), 0),
		Color3.fromRGB(42, 128, 64),
		Color3.fromRGB(232, 232, 222)
	)

	-- 10 Surrounding Barrels & Open Fruit/Relic Crates
	local barrelOffsets = {
		V(-16.5, 0, 1.5),
		V(-15.0, 0, 4.2),
		V(-8.5, 0, -11.5),
		V(0.8, 0, -11.8),
		V(11.0, 0, -10.5),
		V(16.8, 0, 2.5),
		V(15.2, 0, 5.4),
		V(17.5, 0, 4.8),
	}
	for _, bo in ipairs(barrelOffsets) do
		addBarrel(model, centerCF * CFrame.new(bo), 0.95)
	end

	for idx, co in ipairs({ V(-13.5, 1.2, 6.2), V(13.5, 1.2, 7.0), V(1.5, 1.2, -5.5) }) do
		part(
			model,
			"MarketCrate_" .. idx,
			V(3.2, 2.4, 3.2),
			centerCF * CFrame.new(co) * CFrame.Angles(0, math.rad(idx * 25), 0),
			woodLight,
			Enum.Material.WoodPlanks,
			false
		)
	end

	local interactionPart = finalizeFacilityModel(model, centerCF, V(26, 2.5, 18), V(0, 3.5, 5.5))
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
function Arch.BuildBlacksmith(folder: Instance, centerCF: CFrame): Part
	local model = Instance.new("Model")
	model.Name = "Building_Blacksmith"
	model.Parent = folder

	local stoneDark   = Color3.fromRGB(78, 82, 92)    -- #4E525C Slate Stone
	local stoneAshlar = Color3.fromRGB(104, 109, 122) -- #686D7A Ashlar Trim & Quoins
	local roofSlate   = Color3.fromRGB(43, 48, 58)    -- #2B303A Dark Roof Shingle
	local woodTimber  = Color3.fromRGB(74, 50, 33)    -- #4A3221 Heavy Timber Framing
	local woodFloor   = Color3.fromRGB(98, 66, 40)    -- Warm Interior Workshop Planks
	local brickHearth = Color3.fromRGB(92, 53, 44)    -- #5C352C Hearth Brick
	local ironDark    = Color3.fromRGB(38, 41, 48)    -- #262930 Dark Wrought Iron
	local steelSilver = Color3.fromRGB(156, 163, 176) -- #9CA3B0 Steel Blades & Anvil Top
	local emberOrange = Color3.fromRGB(255, 122, 26)  -- #FF7A1A Glowing Forge Embers
	local quenchWater = Color3.fromRGB(44, 120, 184)  -- #2C78B8 Quench Water

	-- Helper to attach a roaring fire emitter + PointLight
	local function addForgeFire(parentPart: BasePart, lightRange: number, lightBright: number, flameSize: number, rate: number)
		pointLight(parentPart, emberOrange, lightBright, lightRange, true)
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

	-- 1. Check if imported Blender FBX Model exists in ReplicatedStorage.Assets.CustomFacilityMeshes.BlacksmithForge
	--    or ReplicatedStorage.Assets.PlotFacilities.BlacksmithForge (with MeshParts)
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	local customMeshes = assetsFolder and assetsFolder:FindFirstChild("CustomFacilityMeshes")
	local importedTemplate = customMeshes and customMeshes:FindFirstChild("BlacksmithForge")
	if not importedTemplate then
		local plotFacs = assetsFolder and assetsFolder:FindFirstChild("PlotFacilities")
		local candidate = plotFacs and plotFacs:FindFirstChild("BlacksmithForge")
		if candidate and candidate:FindFirstChildWhichIsA("MeshPart", true) then
			importedTemplate = candidate
		end
	end

	if importedTemplate and importedTemplate:IsA("Model") then
		local cloned = importedTemplate:Clone()
		cloned:PivotTo(centerCF)
		for _, desc in ipairs(cloned:GetDescendants()) do
			if desc:IsA("BasePart") then
				desc.Anchored = true
				desc.CanCollide = false
				if desc.Name == "Forge_StoneShell" and desc:IsA("MeshPart") then
					desc.Material = Enum.Material.Slate
					desc.Color = stoneDark
				elseif desc.Name == "Forge_RoofAndTimber" then
					desc.Material = Enum.Material.Slate
					desc.Color = roofSlate
				elseif desc.Name == "Forge_InteriorAnvilHearth" then
					desc.Material = Enum.Material.Metal
					desc.Color = ironDark
				elseif desc.Name == "Forge_ExteriorBraziersSign" then
					desc.Material = Enum.Material.Wood
					desc.Color = woodTimber
				end
			end
		end
		for _, ch in ipairs(cloned:GetChildren()) do
			ch.Parent = model
		end
		cloned:Destroy()

		-- Invisible solid collision shell for imported FBX so walls, roof, chimney, hearth & anvil are solid while doorway stays open
		local function colPart(cName: string, sz: Vector3, relCF: CFrame)
			local cp = part(model, cName, sz, centerCF * relCF, stoneDark, Enum.Material.Slate, true)
			cp.Transparency = 1
			return cp
		end
		colPart("Col_Foundation", V(27.0, 1.2, 28.5), CFrame.new(0, 0.6, -0.75))
		colPart("Col_BackWall", V(26.0, 22.0, 1.8), CFrame.new(0, 11.5, -14.2))
		for _, s in ipairs({ -1, 1 }) do
			colPart("Col_SideWall_" .. s, V(1.8, 12.0, 26.8), CFrame.new(s * 12.2, 7.1, -0.8))
			colPart("Col_LeanToWall_" .. s, V(1.4, 6.0, 21.6), CFrame.new(s * 15.2, 3.5, -0.5))
			colPart("Col_FrontFlank_" .. s, V(6.8, 12.5, 2.5), CFrame.new(s * 9.2, 7.2, 12.4))
			colPart("Col_ArchPillar_" .. s, V(3.2, 12.8, 3.2), CFrame.new(s * 6.8, 6.6, 13.4))
			local rPitch = math.atan2(10.9, 13.4)
			local sLen = math.sqrt(13.4 * 13.4 + 10.9 * 10.9)
			colPart("Col_RoofSlope_" .. s, V(sLen, 0.9, 30.2), CFrame.new(s * 6.7, 18.05, -0.5) * CFrame.Angles(0, 0, -s * rPitch))
			local lPitch = math.atan2(4.4, 5.0)
			colPart("Col_LeanRoof_" .. s, V(6.8, 0.7, 23.0), CFrame.new(s * 14.3, 8.4, -0.3) * CFrame.Angles(0, 0, -s * lPitch))
		end
		colPart("Col_FrontGable", V(13.6, 9.5, 2.0), CFrame.new(0, 18.2, 12.4))
		colPart("Col_Chimney", V(9.2, 16.0, 9.2), CFrame.new(0, 26.0, -5.5))
		colPart("Col_Hearth", V(11.6, 12.0, 6.2), CFrame.new(-0.8, 6.5, -10.2))
		colPart("Col_Anvil", V(4.4, 4.2, 3.6), CFrame.new(-0.5, 3.0, 1.8))
	else
		--====================================================================
		-- 2. PROCEDURAL ENTERABLE BLACKSMITH HOUSE (Exact match to Blender FBX)
		--    Footprint: 32 x 36 studs; Hollow Interior: 24 x 26 studs;
		--    Oversized Entry Arch: 11.2W x 13.0H studs (Walkable by R15 Avatars)
		--====================================================================
		-- 2A. Stepped Stone Foundation, Flagstone Entry & Wood-Plank Workshop Floor
		part(model, "FoundationMainSlab", V(27.0, 1.2, 28.5), centerCF * CFrame.new(0, 0.6, -0.75), stoneDark, Enum.Material.Slate, true)
		for ix = -3, 3 do
			for iz = 1, 4 do
				local col = ((ix + iz) % 2 == 0) and stoneAshlar or stoneDark
				part(model, "PorchFlagstone", V(2.6, 0.10, 2.6), centerCF * CFrame.new(ix * 2.75, 1.25, iz * 2.75), col, Enum.Material.Cobblestone, true)
			end
		end
		for pIdx = -5, 5 do
			part(model, "InteriorWoodPlank_" .. pIdx, V(1.9, 0.12, 16.0), centerCF * CFrame.new(pIdx * 2.0, 1.26, -4.5), woodFloor, Enum.Material.WoodPlanks, true)
		end

		-- Side Lean-To Stone Foundations & Curbs
		for _, s in ipairs({ -1, 1 }) do
			part(model, "LeanToFoundation", V(3.4, 1.4, 25.0), centerCF * CFrame.new(s * 14.5, 0.7, -0.5), stoneDark, Enum.Material.Slate, true)
			part(model, "LeanToBaseCurb", V(1.4, 0.7, 26.2), centerCF * CFrame.new(s * 15.8, 0.35, -0.5), stoneAshlar, Enum.Material.Cobblestone, true)
		end

		-- 3 Wide Front Stone Porch Steps & Sloped Cheek Buttresses (+Z = +13.0 to +17.8)
		for st = 0, 2 do
			local stepY = 0.22 + st * 0.36
			local stepZ = 16.8 - st * 1.35
			local stepW = 11.2 - st * 0.4
			part(model, "PorchStep_" .. (st + 1), V(stepW, 0.42, 1.55), centerCF * CFrame.new(0, stepY, stepZ), stoneAshlar, Enum.Material.Cobblestone, true)
		end
		for _, s in ipairs({ -1, 1 }) do
			part(model, "PorchCheekBlock", V(1.1, 1.1, 4.6), centerCF * CFrame.new(s * 6.0, 0.65, 15.4) * CFrame.Angles(math.rad(12), 0, 0), stoneAshlar, Enum.Material.Slate, true)
		end

		-- 2B. Hollowed Perimeter Stone Walls & Coursed Interior Masonry
		-- Back Wall (Z = -14.2) & Gable Wall
		part(model, "BackWallMain", V(26.0, 12.3, 1.8), centerCF * CFrame.new(0, 7.35, -14.2), stoneDark, Enum.Material.Cobblestone, true)
		wedge(model, "BackGableWallL", V(1.8, 9.8, 12.5), centerCF * CFrame.new(-6.25, 18.3, -14.2) * CFrame.Angles(0, math.pi * 0.5, 0), stoneDark, Enum.Material.Cobblestone, true)
		wedge(model, "BackGableWallR", V(1.8, 9.8, 12.5), centerCF * CFrame.new(6.25, 18.3, -14.2) * CFrame.Angles(0, -math.pi * 0.5, 0), stoneDark, Enum.Material.Cobblestone, true)

		-- Coursed Ashlar Stone Blocks on Interior Back Wall
		for rRow = 0, 5 do
			local ry = 2.0 + rRow * 1.45
			for cCol = -4, 4 do
				local stag = (rRow % 2 == 1) and 0.7 or 0.0
				local rxB = cCol * 2.2 + stag
				if math.abs(rxB) <= 10.8 then
					local bCol = ((rRow + cCol) % 2 == 0) and stoneAshlar or stoneDark
					part(model, "InteriorStoneCourse", V(2.05, 1.32, 0.35), centerCF * CFrame.new(rxB, ry, -13.15), bCol, Enum.Material.Slate, false)
				end
			end
		end

		-- Left & Right Main Hall Walls (X = +-12.2) & Side Lean-To Brick/Stone Walls (X = +-15.2)
		for _, s in ipairs({ -1, 1 }) do
			part(model, "SideHallWall", V(1.8, 11.8, 26.8), centerCF * CFrame.new(s * 12.2, 7.1, -0.8), stoneDark, Enum.Material.Cobblestone, true)
			part(model, "LeanToLowerStone", V(1.2, 2.2, 21.6), centerCF * CFrame.new(s * 15.2, 2.3, -0.5), stoneAshlar, Enum.Material.Slate, true)
			part(model, "LeanToUpperBrick", V(1.0, 3.0, 20.8), centerCF * CFrame.new(s * 15.1, 4.8, -0.5), brickHearth, Enum.Material.Brick, true)
			for _, cz in ipairs({ -11.2, 10.2 }) do
				for q = 0, 3 do
					part(model, "CornerQuoin", V(1.4, 0.95, 1.4), centerCF * CFrame.new(s * 15.3, 2.0 + q * 1.25, cz), stoneAshlar, Enum.Material.Slate, true)
				end
			end
			for _, pz in ipairs({ -10.2, 0.0, 9.8 }) do
				part(model, "LeanToTimberPost", V(0.95, 5.2, 0.95), centerCF * CFrame.new(s * 15.2, 3.8, pz), woodTimber, Enum.Material.Wood, true)
			end
		end

		-- 2C. Front Wall & Oversized Arched Entryway (Z = +12.2, Arch Opening 11.2W x 13.0H studs!)
		for _, s in ipairs({ -1, 1 }) do
			part(model, "FrontFlankWall", V(6.8, 12.0, 2.0), centerCF * CFrame.new(s * 9.2, 7.2, 12.2), stoneDark, Enum.Material.Cobblestone, true)
			part(model, "FrontBrickPanel", V(3.8, 4.4, 0.3), centerCF * CFrame.new(s * 9.8, 5.2, 13.25), brickHearth, Enum.Material.Brick, true)

			-- Tiered Ashlar Stone Buttress Pillars framing the Entry Arch (X = +-6.8, Z = +13.4)
			local px, pz = s * 6.8, 13.4
			part(model, "ArchPillarPlinth", V(3.2, 2.2, 3.2), centerCF * CFrame.new(px, 2.2, pz), stoneAshlar, Enum.Material.Slate, true)
			for tier = 0, 5 do
				local ty = 3.8 + tier * 1.45
				local tw = (tier % 2 == 0) and 2.6 or 2.4
				part(model, "ArchPillarCourse_" .. tier, V(tw, 1.32, tw), centerCF * CFrame.new(px, ty, pz), stoneAshlar, Enum.Material.Slate, true)
			end
			part(model, "ArchPillarMidBand", V(3.0, 0.75, 3.0), centerCF * CFrame.new(px, 7.4, pz), stoneAshlar, Enum.Material.Slate, true)
			part(model, "ArchPillarCapital", V(3.1, 0.95, 3.1), centerCF * CFrame.new(px, 12.6, pz), stoneAshlar, Enum.Material.Slate, true)
		end

		-- Pointed Stone Voussoir Archway (18 segments, non-collidable overhead so tall avatars never snag)
		local archSegs = 18
		local rIn, rOut, springY = 5.6, 7.1, 8.0
		for i = 0, archSegs - 1 do
			local a = math.pi * ((i + 0.5) / archSegs)
			local lift = 0.75 * math.sin(a)
			local rMid = (rIn + rOut) * 0.5
			local vx = math.cos(a) * rMid
			local vy = springY + math.sin(a) * rMid + lift
			local vCol = (i % 2 == 0) and stoneAshlar or stoneDark
			part(
				model,
				"ArchVoussoir_" .. (i + 1),
				V(1.5, 1.35, 3.1),
				centerCF * CFrame.new(vx, vy, 12.7) * CFrame.Angles(0, 0, a),
				vCol,
				Enum.Material.Slate,
				false
			)
		end
		part(model, "ArchKeystone", V(1.6, 2.1, 3.5), centerCF * CFrame.new(0, 14.3, 13.0), stoneAshlar, Enum.Material.Slate, false)

		-- Front Gable Brick Infill & Half-Timbered Truss (Y = 13.2 to 23.5, Z = +12.2..14.2)
		wedge(model, "FrontGableWallL", V(1.3, 9.8, 11.8), centerCF * CFrame.new(-5.9, 18.3, 12.1) * CFrame.Angles(0, math.pi * 0.5, 0), brickHearth, Enum.Material.Brick, true)
		wedge(model, "FrontGableWallR", V(1.3, 9.8, 11.8), centerCF * CFrame.new(5.9, 18.3, 12.1) * CFrame.Angles(0, -math.pi * 0.5, 0), brickHearth, Enum.Material.Brick, true)
		part(model, "GableTieBeam", V(15.6, 1.05, 1.15), centerCF * CFrame.new(0, 13.8, 13.6), woodTimber, Enum.Material.Wood, true)
		part(model, "GableKingPost", V(1.05, 8.6, 0.95), centerCF * CFrame.new(0, 18.5, 13.5), woodTimber, Enum.Material.Wood, true)
		local roofPitch = math.atan2(10.9, 13.4)
		for _, s in ipairs({ -1, 1 }) do
			part(model, "GableStrutInner", V(0.85, 5.6, 0.80), centerCF * CFrame.new(s * 2.4, 16.5, 13.45) * CFrame.Angles(0, 0, s * 0.62), woodTimber, Enum.Material.Wood, false)
			part(model, "GableStrutOuter", V(0.75, 3.8, 0.75), centerCF * CFrame.new(s * 4.8, 15.4, 13.45) * CFrame.Angles(0, 0, -s * 0.55), woodTimber, Enum.Material.Wood, false)
			part(model, "GableBargeboard", V(17.4, 1.15, 1.10), centerCF * CFrame.new(s * 6.8, 18.1, 14.2) * CFrame.Angles(0, 0, -s * roofPitch), woodTimber, Enum.Material.Wood, true)
			part(model, "BargeboardIronStrap", V(2.2, 1.35, 1.25), centerCF * CFrame.new(s * 10.6, 15.0, 14.25) * CFrame.Angles(0, 0, -s * roofPitch), ironDark, Enum.Material.Metal, false)
			part(model, "BargeboardRivet", V(0.35, 0.35, 0.25), centerCF * CFrame.new(s * 10.6, 15.0, 14.92), steelSilver, Enum.Material.Metal, false)
			part(model, "GableCorbelBlock", V(2.1, 1.8, 2.2), centerCF * CFrame.new(s * 13.2, 12.6, 14.2), stoneAshlar, Enum.Material.Slate, true)
		end
		part(model, "GableApexFinial", V(1.8, 1.6, 2.4), centerCF * CFrame.new(0, 24.4, 14.5), stoneAshlar, Enum.Material.Slate, true)

		-- Open Arched Wooden Door swung inward at 78 deg on Left Jamb (X = -5.4, Z = +11.8)
		local doorCF = centerCF * CFrame.new(-4.9, 5.8, 9.7) * CFrame.Angles(0, math.rad(-78), 0)
		part(model, "OpenWoodenDoor", V(4.4, 9.2, 0.48), doorCF, woodTimber, Enum.Material.WoodPlanks, true)
		for _, hy in ipairs({ -3.0, 0.0, 2.8 }) do
			part(model, "DoorIronStrap", V(4.0, 0.32, 0.58), doorCF * CFrame.new(0, hy, 0), ironDark, Enum.Material.Metal, false)
		end

		-- 2D. Steep Gabled Slate Roof, Shingle Courses, Cross-Gable Dormers & Side Lean-To Roofs
		local slopeLen = math.sqrt(13.4 * 13.4 + 10.9 * 10.9)
		for _, s in ipairs({ -1, 1 }) do
			local slopeCF = centerCF * CFrame.new(s * 6.7, 18.05, -0.5) * CFrame.Angles(0, 0, -s * roofPitch)
			part(model, "MainRoofSlope", V(slopeLen, 0.75, 30.2), slopeCF, roofSlate, Enum.Material.Slate, true)
			for r = 1, 7 do
				local u = (r - 4) / 3.5
				part(
					model,
					"RoofShingleCourse_" .. r,
					V(2.1, 0.25, 29.8),
					slopeCF * CFrame.new(u * (slopeLen * 0.44), 0.45, 0),
					(r % 2 == 0) and roofSlate or stoneDark,
					Enum.Material.Slate,
					false
				)
			end
			-- Lower Side Lean-To Shed Roofs
			local leanPitch = math.atan2(4.4, 5.0)
			local leanCF = centerCF * CFrame.new(s * 14.3, 8.4, -0.3) * CFrame.Angles(0, 0, -s * leanPitch)
			part(model, "LeanToRoofSlope", V(6.8, 0.55, 23.0), leanCF, roofSlate, Enum.Material.Slate, true)
		end
		for rSeg = 0, 7 do
			part(model, "RoofRidgeCoping_" .. rSeg, V(1.35, 0.95, 3.75), centerCF * CFrame.new(0, 24.35, -14.0 + rSeg * 3.9), stoneAshlar, Enum.Material.Slate, true)
		end

		-- Right Cross-Gable Wing & Dormer Windows
		part(model, "CrossGableWing", V(11.6, 5.8, 8.8), centerCF * CFrame.new(9.8, 17.5, -3.0), roofSlate, Enum.Material.Slate, true)
		part(model, "CrossGableRidgeCap", V(11.8, 0.85, 1.15), centerCF * CFrame.new(9.8, 21.8, -3.0), stoneAshlar, Enum.Material.Slate, true)
		part(model, "DormerWindowRight", V(3.6, 3.8, 2.8), centerCF * CFrame.new(10.2, 16.5, 1.8), woodTimber, Enum.Material.Wood, true)
		part(model, "DormerMullionRight", V(2.2, 2.6, 0.25), centerCF * CFrame.new(10.2, 16.5, 3.25), ironDark, Enum.Material.Metal, false)
		part(model, "DormerWindowUpper", V(2.8, 3.2, 3.2), centerCF * CFrame.new(3.2, 18.6, 5.8), woodTimber, Enum.Material.Wood, true)

		-- 2E. Central Tapered Cylindrical Stone Smokestack Tower with Crenellations (X = 0, Z = -5.5, Y = 18.5..33.8)
		part(model, "ChimneyBaseSaddle", V(9.6, 5.5, 9.6), centerCF * CFrame.new(0, 18.5, -5.5), stoneDark, Enum.Material.Slate, true)
		for cIdx = 0, 8 do
			local rCourse = 4.65 * (1.0 - 0.16 * (cIdx / 9))
			local yCourse = 21.0 + cIdx * 1.15
			local cCol = (cIdx % 2 == 0) and stoneAshlar or stoneDark
			cylinder(model, "ChimneyShaftCourse_" .. cIdx, rCourse, 1.08, centerCF * CFrame.new(0, yCourse, -5.5), cCol, Enum.Material.Cobblestone, true)
		end
		local crownY = 30.85
		cylinder(model, "ChimneyCorbelCollar", 4.35, 1.1, centerCF * CFrame.new(0, crownY + 0.3, -5.5), stoneAshlar, Enum.Material.Slate, true)
		cylinder(model, "ChimneyBrickBand", 4.48, 0.9, centerCF * CFrame.new(0, crownY + 1.35, -5.5), brickHearth, Enum.Material.Brick, true)
		for mIdx = 0, 7 do
			local ang = (mIdx / 8) * math.pi * 2
			local mx, mz = math.cos(ang) * 4.15, -5.5 + math.sin(ang) * 4.15
			part(
				model,
				"ChimneyMerlon_" .. mIdx,
				V(1.55, 1.45, 0.95),
				centerCF * CFrame.new(mx, crownY + 2.45, mz) * CFrame.Angles(0, -ang, 0),
				stoneAshlar,
				Enum.Material.Slate,
				true
			)
		end

		-- 2F. Interior Brick Hearth Firebox, Central Anvil on Timber Block, Sword Barrel & Quench Trough
		local hx = -0.8
		part(model, "HearthPlinth", V(11.6, 1.8, 6.2), centerCF * CFrame.new(hx, 2.1, -10.2), stoneAshlar, Enum.Material.Slate, true)
		for _, s in ipairs({ -1, 1 }) do
			part(model, "HearthPier", V(2.8, 4.8, 5.4), centerCF * CFrame.new(hx + s * 4.2, 5.4, -10.2), brickHearth, Enum.Material.Brick, true)
		end
		part(model, "HearthBackWall", V(6.0, 4.8, 1.8), centerCF * CFrame.new(hx, 5.4, -12.0), brickHearth, Enum.Material.Brick, true)
		part(model, "HearthLintel", V(11.2, 1.4, 5.8), centerCF * CFrame.new(hx, 8.2, -10.0), stoneAshlar, Enum.Material.Slate, true)
		part(model, "HearthHood", V(9.2, 5.2, 4.8), centerCF * CFrame.new(hx, 11.5, -10.0), stoneDark, Enum.Material.Slate, true)

		-- Central Iron Anvil on Heavy Banded Timber Block (X = -0.5, Z = +1.8 — clearly visible & walkable!)
		local ax, az = -0.5, 1.8
		part(model, "AnvilStonePedestal", V(4.4, 0.70, 3.6), centerCF * CFrame.new(ax, 1.55, az), stoneAshlar, Enum.Material.Slate, true)
		part(model, "AnvilTimberBlock", V(3.2, 1.55, 2.5), centerCF * CFrame.new(ax, 2.65, az), woodTimber, Enum.Material.Wood, true)
		part(model, "AnvilTimberBand", V(3.32, 0.24, 2.62), centerCF * CFrame.new(ax, 2.95, az), ironDark, Enum.Material.Metal, false)
		part(model, "AnvilBase", V(2.6, 0.50, 1.6), centerCF * CFrame.new(ax, 3.65, az), ironDark, Enum.Material.Metal, true)
		part(model, "AnvilWaist", V(1.8, 0.65, 1.15), centerCF * CFrame.new(ax, 4.15, az), ironDark, Enum.Material.Metal, true)
		part(model, "AnvilWorkingBody", V(3.4, 0.58, 1.45), centerCF * CFrame.new(ax, 4.72, az), ironDark, Enum.Material.Metal, true)
		part(model, "AnvilSteelFace", V(3.2, 0.08, 1.35), centerCF * CFrame.new(ax, 5.02, az), steelSilver, Enum.Material.Metal, true)
		wedge(model, "AnvilHorn", V(0.95, 0.52, 1.55), centerCF * CFrame.new(ax + 2.35, 4.75, az) * CFrame.Angles(0, math.pi * 0.5, math.pi), ironDark, Enum.Material.Metal, true)

		-- Interior Sword Barrel with 5 Fanned Swords next to Hearth (X = +2.6, Z = -6.8)
		local sbx, sbz = 2.6, -6.8
		cylinder(model, "InteriorSwordBarrel", 1.32, 3.0, centerCF * CFrame.new(sbx, 2.7, sbz), woodTimber, Enum.Material.WoodPlanks, true)
		for bIdx = 0, 4 do
			local ang = 0.36 - bIdx * 0.18
			local bxs = sbx + (bIdx - 2) * 0.38
			part(model, "BarrelSwordBlade_" .. bIdx, V(0.16, 3.8, 0.28), centerCF * CFrame.new(bxs, 5.4, sbz) * CFrame.Angles(0, 0, ang), steelSilver, Enum.Material.Metal, false)
			part(model, "BarrelSwordGuard_" .. bIdx, V(0.72, 0.16, 0.32), centerCF * CFrame.new(bxs - math.sin(ang) * 1.1, 6.4, sbz) * CFrame.Angles(0, 0, ang), ironDark, Enum.Material.Metal, false)
		end

		-- Interior Quenching Barrel, Secondary Ember Counter & Left Timber Workbench
		cylinder(model, "QuenchBarrel", 1.6, 2.4, centerCF * CFrame.new(4.8, 2.4, 1.2), woodTimber, Enum.Material.WoodPlanks, true)
		cylinder(model, "QuenchWaterDisc", 1.38, 0.25, centerCF * CFrame.new(4.8, 3.55, 1.2), quenchWater, Enum.Material.Glass, false)
		part(model, "SideForgeCounter", V(4.2, 2.8, 3.8), centerCF * CFrame.new(6.4, 2.6, -7.2), stoneAshlar, Enum.Material.Slate, true)
		part(model, "SideForgeEmbers", V(2.6, 0.65, 2.2), centerCF * CFrame.new(6.4, 4.2, -7.2), emberOrange, Enum.Material.Neon, false)
		part(model, "InteriorWorkbench", V(2.8, 0.45, 7.6), centerCF * CFrame.new(-8.6, 3.0, -3.0), woodFloor, Enum.Material.WoodPlanks, true)

		-- 2G. Exterior Hanging Shield & Anvil Sign on Right Timber Crane Beam, Flanking Braziers & Sword Rack
		part(model, "SignCraneBeam", V(11.6, 0.95, 0.95), centerCF * CFrame.new(17.2, 14.8, 1.5), woodTimber, Enum.Material.Wood, true)
		part(model, "SignCraneBrace", V(5.8, 0.75, 0.75), centerCF * CFrame.new(14.2, 12.6, 1.5) * CFrame.Angles(0, 0, 0.68), woodTimber, Enum.Material.Wood, true)
		for _, cxChain in ipairs({ 18.2, 21.4 }) do
			part(model, "SignChainLinks", V(0.22, 3.8, 0.22), centerCF * CFrame.new(cxChain, 12.4, 1.5), ironDark, Enum.Material.Metal, false)
		end
		part(model, "HangingShieldSign", V(4.6, 4.6, 0.45), centerCF * CFrame.new(19.8, 8.2, 1.5), woodTimber, Enum.Material.Wood, true)
		part(model, "ShieldSignTopBar", V(4.8, 0.38, 0.62), centerCF * CFrame.new(19.8, 10.4, 1.5), ironDark, Enum.Material.Metal, false)
		part(model, "ShieldAnvilEmblem", V(2.4, 0.85, 0.65), centerCF * CFrame.new(19.8, 7.8, 1.5), steelSilver, Enum.Material.Metal, false)

		for _, s in ipairs({ -1, 1 }) do
			local bx, bz = s * 7.4, 15.8
			part(model, "BrazierPedestalTier1", V(3.6, 0.90, 3.6), centerCF * CFrame.new(bx, 0.45, bz), stoneDark, Enum.Material.Slate, true)
			part(model, "BrazierPedestalTier2", V(2.8, 0.80, 2.8), centerCF * CFrame.new(bx, 1.25, bz), stoneAshlar, Enum.Material.Slate, true)
			cylinder(model, "BrazierIronBowl", 1.48, 1.0, centerCF * CFrame.new(bx, 2.15, bz), ironDark, Enum.Material.Metal, true)
		end
		addWeaponRack(model, centerCF * CFrame.new(10.6, 0.0, 13.8))
		addBarrel(model, centerCF * CFrame.new(14.8, 0.0, 11.8), 1.0)
		addBarrel(model, centerCF * CFrame.new(16.4, 0.0, 9.8), 0.9)
		addBarrel(model, centerCF * CFrame.new(-14.8, 0.0, 12.2), 0.95)
	end

	--========================================================================
	-- 3. DYNAMIC VFX EMITTERS, POINTLIGHTS & INTERACTION PROMPT ANCHOR
	--    Attached whether using imported Blender FBX or procedural parts!
	--========================================================================
	-- Hearth Fire & Warm Interior Glow
	local emberBed = part(
		model,
		"GlowingEmbers",
		V(5.0, 0.9, 3.4),
		centerCF * CFrame.new(-0.8, 3.35, -10.0),
		emberOrange,
		Enum.Material.Neon,
		false
	)
	addForgeFire(emberBed, 34, 3.2, 2.2, 24)

	-- Entrance Flanking Braziers Fire & Glow
	for _, s in ipairs({ -1, 1 }) do
		local brazierCore = sphere(
			model,
			if s < 0 then "BrazierFireLeft" else "BrazierFireRight",
			1.5,
			centerCF * CFrame.new(s * 7.4, 2.95, 15.8),
			emberOrange,
			Enum.Material.Neon
		)
		addForgeFire(brazierCore, 22, 2.2, 1.4, 16)
	end

	-- Chimney Top Fire Glow & Rising Dark Smoke Plume
	local chimneyFlue = cylinder(
		model,
		"ChimneySmokeAnchor",
		3.1,
		0.8,
		centerCF * CFrame.new(0, 32.3, -5.5),
		emberOrange,
		Enum.Material.Neon,
		false
	)
	pointLight(chimneyFlue, emberOrange, 2.4, 28, false)
	local smokeEmit = Instance.new("ParticleEmitter")
	smokeEmit.Name = "ChimneySmoke"
	smokeEmit.Texture = "rbxassetid://243660364"
	smokeEmit.Color = ColorSequence.new(Color3.fromRGB(58, 56, 62), Color3.fromRGB(28, 26, 32))
	smokeEmit.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2.8),
		NumberSequenceKeypoint.new(1, 8.5),
	})
	smokeEmit.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.38),
		NumberSequenceKeypoint.new(0.7, 0.62),
		NumberSequenceKeypoint.new(1, 1.0),
	})
	smokeEmit.Lifetime = NumberRange.new(2.8, 4.5)
	smokeEmit.Rate = 14
	smokeEmit.Speed = NumberRange.new(4.5, 8.0)
	smokeEmit.SpreadAngle = Vector2.new(18, 18)
	smokeEmit.Parent = chimneyFlue

	-- Anvil Spark Emitter on top of the central Anvil inside the Forge
	local anvilSparkAnchor = part(
		model,
		"AnvilFace",
		V(3.0, 0.2, 1.2),
		centerCF * CFrame.new(-0.5, 5.05, 1.8),
		steelSilver,
		Enum.Material.Metal,
		false
	)
	anvilSparkAnchor.Transparency = 1
	local sparkEmit = Instance.new("ParticleEmitter")
	sparkEmit.Name = "AnvilSparks"
	sparkEmit.Texture = "rbxassetid://243660364"
	sparkEmit.Color = ColorSequence.new(Color3.fromRGB(255, 240, 130), emberOrange)
	sparkEmit.LightEmission = 1
	sparkEmit.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	sparkEmit.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparkEmit.Lifetime = NumberRange.new(0.35, 0.65)
	sparkEmit.Rate = 8
	sparkEmit.Speed = NumberRange.new(7, 13)
	sparkEmit.SpreadAngle = Vector2.new(75, 75)
	sparkEmit.Acceleration = V(0, -28, 0)
	sparkEmit.Parent = anvilSparkAnchor

	-- Ground-level PrimaryRoot (hullSize.Y = 1.0 so CanCollide is false and avatars walk freely inside!)
	-- PromptAnchor positioned directly at the interior Anvil (-0.5, 4.5, 1.8)
	local interactionPart = finalizeFacilityModel(model, centerCF, V(28, 1.0, 30), V(-0.5, 4.5, 1.8))
	return interactionPart
end

--============================================================================
-- 2.6 TRAINING AREA (`TrainingArea` — Fenced Circular Cobblestone Combat Ring)
--============================================================================
function Arch.BuildTrainingGrounds(folder: Instance, centerCF: CFrame): Part
	local model = Instance.new("Model")
	model.Name = "Building_TrainingGrounds"
	model.Parent = folder

	local ringCobble = Color3.fromRGB(84, 82, 78)
	local ringCurb = Color3.fromRGB(56, 60, 68)
	local fenceWood = Color3.fromRGB(108, 74, 44)
	local strawColor = Color3.fromRGB(214, 182, 102)
	local postWood = Color3.fromRGB(88, 58, 34)

	-- Sunken/Bordered Circular Cobblestone Combat Ring (Diameter = 28 studs)
	cylinder(model, "TrainingRingBorder", 14.8, 0.45, centerCF * CFrame.new(0, 0.22, 0), ringCurb, Enum.Material.Slate, false)
	cylinder(model, "TrainingRingFloor", 13.8, 0.52, centerCF * CFrame.new(0, 0.26, 0), ringCobble, Enum.Material.Cobblestone, false)
	cylinder(model, "InnerSparringCircle", 8.5, 0.56, centerCF * CFrame.new(0, 0.28, 0), Color3.fromRGB(98, 94, 88), Enum.Material.Cobblestone, false)

	-- 4 Curved Wooden Split-Rail Fence Segments enclosing the ring (with open entry gaps)
	local fenceRadius = 14.2
	for quad = 1, 4 do
		local baseAngle = math.rad((quad - 1) * 90 + 45)
		for sub = -1, 1 do
			local a1 = baseAngle + math.rad(sub * 18 - 9)
			local a2 = baseAngle + math.rad(sub * 18 + 9)
			local p1 = V(math.cos(a1) * fenceRadius, 0, math.sin(a1) * fenceRadius)
			local p2 = V(math.cos(a2) * fenceRadius, 0, math.sin(a2) * fenceRadius)
			local mid = (p1 + p2) * 0.5
			local segLen = (p2 - p1).Magnitude
			local railCF = centerCF * CFrame.lookAt(mid, p2)

			part(model, "FencePost", V(0.65, 3.4, 0.65), centerCF * CFrame.new(p1 + V(0, 1.7, 0)), postWood, Enum.Material.Wood, false)
			if sub == 1 then
				part(model, "FencePostEnd", V(0.65, 3.4, 0.65), centerCF * CFrame.new(p2 + V(0, 1.7, 0)), postWood, Enum.Material.Wood, false)
			end
			part(model, "SplitRailTop", V(0.35, 0.4, segLen + 0.3), railCF * CFrame.new(0, 2.7, 0), fenceWood, Enum.Material.WoodPlanks, false)
			part(model, "SplitRailLow", V(0.35, 0.4, segLen + 0.3), railCF * CFrame.new(0, 1.4, 0), fenceWood, Enum.Material.WoodPlanks, false)
		end
	end

	-- 4 Wooden T-Posed Straw Training Dummies positioned around the inner perimeter
	local dummyAngles = { math.rad(35), math.rad(125), math.rad(215), math.rad(305) }
	for idx, dAngle in ipairs(dummyAngles) do
		local dPos = V(math.cos(dAngle) * 9.6, 0.5, math.sin(dAngle) * 9.6)
		local dummyCF = centerCF * CFrame.lookAt(dPos, V(0, 0.5, 0))

		cylinder(model, "DummyBase_" .. idx, 1.3, 0.35, dummyCF * CFrame.new(0, 0.18, 0), postWood, Enum.Material.Wood, false)
		cylinder(model, "TrainingDummy_" .. idx, 0.4, 5.6, dummyCF * CFrame.new(0, 2.8, 0), postWood, Enum.Material.Wood, false)
		part(model, "DummyCrossbar_" .. idx, V(3.8, 0.45, 0.45), dummyCF * CFrame.new(0, 4.1, 0), postWood, Enum.Material.Wood, false)
		cylinder(model, "DummyTorso_" .. idx, 0.95, 2.5, dummyCF * CFrame.new(0, 3.5, 0), strawColor, Enum.Material.Fabric, false)
		sphere(model, "DummyHead_" .. idx, 1.35, dummyCF * CFrame.new(0, 5.35, 0), strawColor, Enum.Material.Fabric)
		-- Target band across dummy chest
		cylinder(model, "DummyTargetBand_" .. idx, 0.98, 0.45, dummyCF * CFrame.new(0, 3.6, 0), Color3.fromRGB(190, 42, 42), Enum.Material.Fabric, false)
	end

	-- 1 Freestanding Circular Red-and-White Bullseye Target on the East (+Z) Side
	local targetCF = centerCF * CFrame.new(0, 0.5, 11.8) * CFrame.Angles(math.rad(-10), 0, 0)
	part(model, "BullseyeLegL", V(0.45, 5.2, 0.45), targetCF * CFrame.new(-1.2, 2.4, 0.4), postWood, Enum.Material.Wood, false)
	part(model, "BullseyeLegR", V(0.45, 5.2, 0.45), targetCF * CFrame.new(1.2, 2.4, 0.4), postWood, Enum.Material.Wood, false)
	local discCF = targetCF * CFrame.new(0, 3.6, 0) * CFrame.Angles(0, math.pi * 0.5, 0)
	cylinder(model, "BullseyeBack", 2.2, 0.35, discCF, strawColor, Enum.Material.Wood, false)
	cylinder(model, "BullseyeRedOuter", 1.9, 0.40, discCF, Color3.fromRGB(205, 40, 40), Enum.Material.SmoothPlastic, false)
	cylinder(model, "BullseyeWhiteMid", 1.3, 0.44, discCF, Color3.fromRGB(240, 240, 240), Enum.Material.SmoothPlastic, false)
	cylinder(model, "BullseyeRedCenter", 0.65, 0.48, discCF, Color3.fromRGB(215, 35, 35), Enum.Material.SmoothPlastic, false)

	-- Weapon Racks along the South-West edge
	addWeaponRack(model, centerCF * CFrame.new(-10.5, 0.4, -7.5) * CFrame.Angles(0, math.rad(45), 0))
	addWeaponRack(model, centerCF * CFrame.new(-12.2, 0.4, -2.0) * CFrame.Angles(0, math.rad(75), 0))

	-- Warm corner torch post for evening visibility
	local torchPost = part(model, "ArenaTorchPost", V(0.7, 7.5, 0.7), centerCF * CFrame.new(11.5, 3.75, -8.5), postWood, Enum.Material.Wood, false)
	local flame = sphere(model, "ArenaTorchFlame", 1.1, torchPost.CFrame * CFrame.new(0, 4.0, 0), Color3.fromRGB(255, 165, 65), Enum.Material.Neon)
	pointLight(flame, Color3.fromRGB(255, 165, 65), 1.8, 22, false)

	local interactionPart = finalizeFacilityModel(model, centerCF, V(4, 1.0, 4), V(0, 3.8, -11.5))
	return interactionPart
end

--============================================================================
-- 2.7 GUARDPOST OUTSKIRTS (`GuardpostOutskirts` — Palisade Watch & Campfire)
--============================================================================
function Arch.BuildGuardPost(folder: Instance, centerCF: CFrame): Part
	local model = Instance.new("Model")
	model.Name = "Building_GuardPost"
	model.Parent = folder

	local timberLog = Color3.fromRGB(94, 62, 36)
	local darkTimber = Color3.fromRGB(68, 44, 26)
	local stoneRing = Color3.fromRGB(82, 86, 94)
	local fireWarm = Color3.fromRGB(255, 145, 50)

	-- Timber Palisade Watch-Post with Slatted Wooden Roof
	local towerCF = centerCF * CFrame.new(8.5, 0, -3.5)
	part(model, "WatchBaseDeck", V(11.0, 1.2, 11.0), towerCF * CFrame.new(0, 0.6, 0), stoneRing, Enum.Material.Cobblestone, true)

	-- 4 Corner Log Pillars & Elevated Watch Deck
	for _, sx in ipairs({ -4.4, 4.4 }) do
		for _, sz in ipairs({ -4.4, 4.4 }) do
			cylinder(model, "WatchLogPillar", 0.65, 13.5, towerCF * CFrame.new(sx, 6.75, sz), darkTimber, Enum.Material.Wood, true)
		end
	end
	part(model, "WatchUpperPlatform", V(10.6, 0.7, 10.6), towerCF * CFrame.new(0, 7.6, 0), timberLog, Enum.Material.WoodPlanks, true)

	-- Palisade Log Parapet Rails
	for _, side in ipairs({
		{ Size = V(10.6, 2.6, 0.6), Offset = V(0, 9.2, -4.8) },
		{ Size = V(10.6, 2.6, 0.6), Offset = V(0, 9.2, 4.8) },
		{ Size = V(0.6, 2.6, 10.6), Offset = V(-4.8, 9.2, 0) },
		{ Size = V(0.6, 2.6, 10.6), Offset = V(4.8, 9.2, 0) },
	}) do
		part(model, "PalisadeRail", side.Size, towerCF * CFrame.new(side.Offset), timberLog, Enum.Material.WoodPlanks, false)
	end

	-- Slatted Wooden Gable Roof
	for s = -3, 3 do
		part(
			model,
			"SlattedRoofPlank_" .. (s + 4),
			V(12.2, 0.4, 1.55),
			towerCF * CFrame.new(0, 14.2 - math.abs(s) * 0.35, s * 1.65) * CFrame.Angles(math.rad(s * 5), 0, 0),
			(s % 2 == 0) and timberLog or darkTimber,
			Enum.Material.WoodPlanks,
			false
		)
	end

	-- Palisade Stakeholder Fence flanking the Watch-Post
	for p = 1, 7 do
		local px = -14.5 + (p - 1) * 2.1
		cylinder(model, "PalisadeStake_" .. p, 0.55, 6.2 + (p % 2) * 0.6, centerCF * CFrame.new(px, 3.1, -8.5), timberLog, Enum.Material.Wood, true)
	end

	-- Stone-Ringed Campfire & Log Seating
	local fireCenter = centerCF * CFrame.new(-4.5, 0, 2.5)
	for r = 1, 10 do
		local a = ((r - 1) / 10) * math.pi * 2
		part(
			model,
			"CampfireStone_" .. r,
			V(1.4, 0.9, 1.1),
			fireCenter * CFrame.new(math.cos(a) * 2.6, 0.45, math.sin(a) * 2.6) * CFrame.Angles(0, -a, 0),
			stoneRing,
			Enum.Material.Slate,
			false
		)
	end
	for l = 1, 3 do
		local a = math.rad(l * 60)
		cylinder(
			model,
			"CampfireLog_" .. l,
			0.38,
			3.8,
			fireCenter * CFrame.new(0, 0.5, 0) * CFrame.Angles(math.rad(78), a, 0),
			darkTimber,
			Enum.Material.Wood,
			false
		)
	end

	local fireCore = sphere(model, "CampfireFlameCore", 1.8, fireCenter * CFrame.new(0, 1.1, 0), fireWarm, Enum.Material.Neon)
	pointLight(fireCore, fireWarm, 2.5, 24, true)

	local campFireEmit = Instance.new("ParticleEmitter")
	campFireEmit.Name = "CampfireFlames"
	campFireEmit.Texture = "rbxassetid://243660364"
	campFireEmit.Color = ColorSequence.new(Color3.fromRGB(255, 225, 110), fireWarm)
	campFireEmit.LightEmission = 0.95
	campFireEmit.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.6),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	campFireEmit.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1.0),
	})
	campFireEmit.Lifetime = NumberRange.new(0.6, 1.1)
	campFireEmit.Rate = 18
	campFireEmit.Speed = NumberRange.new(2.5, 5.0)
	campFireEmit.Acceleration = V(0, 6, 0)
	campFireEmit.Parent = fireCore

	-- Log Seating Benches around the Campfire
	for _, bench in ipairs({
		{ Offset = V(-5.2, 0.65, 0), Yaw = 90 },
		{ Offset = V(0, 0.65, 5.2), Yaw = 0 },
	}) do
		local benchCF = fireCenter * CFrame.new(bench.Offset) * CFrame.Angles(0, math.rad(bench.Yaw), 0)
		part(model, "LogBenchSeat", V(5.2, 1.1, 1.3), benchCF, timberLog, Enum.Material.Wood, false)
	end

	local interactionPart = finalizeFacilityModel(model, centerCF, V(10, 2.0, 10), V(0, 3.8, 3.5))
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
	if existing and existing:GetAttribute("PrefabVersion") == 10 then
		return existing :: Folder
	end
	if existing then
		existing:Destroy()
	end

	local prefabs = Instance.new("Folder")
	prefabs.Name = "PlotFacilities"
	prefabs:SetAttribute("PrefabVersion", 10)
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
