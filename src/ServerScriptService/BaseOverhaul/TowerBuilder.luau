--!strict
-- TowerBuilder.luau
-- ModuleScript: Builds the centerpiece Black & Deep Red Colosseum/Renaissance Tower at the center of the map.
-- Features stacked slightly tapering rings, rows of dull-red glowing arched windows with mullions, crimson ledges,
-- cracked smoky ground with a faint red under-glow, swirling storm clouds, floating red embers,
-- and a grand non-functional entrance at the base ready to hook up later.

local TowerBuilder = {}

--============================================================================
-- CONFIGURATION TABLE
--============================================================================
TowerBuilder.Config = {
	-- Position & Overall Scale
	CenterPosition = Vector3.new(0, 16, 0), -- Sits at center of map (Y=16 matches Ring3_CenterBossAltar top)
	BaseDiameter = 186, -- 150 to 200 studs wide at the base
	TopDiameter = 112, -- Slight Renaissance/colosseum taper toward the top
	TowerHeight = 860, -- 800+ studs tall
	RingCount = 18, -- Number of stacked architectural tiers/floors
	WindowsPerRing = 20, -- Arched Renaissance windows around each ring circumference

	-- Cracked Smoky Base Ground
	CrackedGroundDiameter = 228,
	CrackedFissureCount = 12,

	-- Entrance Gate at Base
	EntranceOrientationYawDeg = 180, -- Faces South (-Z / Plot_1) by default
	EntranceWidth = 28,
	EntranceHeight = 38,

	-- Color Scheme & Materials
	BodyMaterial = Enum.Material.Basalt,
	BodyColor = Color3.fromRGB(32, 28, 34), -- Dark charcoal/black stone
	PillarMaterial = Enum.Material.Slate,
	PillarColor = Color3.fromRGB(48, 38, 46),
	TrimMaterial = Enum.Material.Granite,
	CrimsonTrimColor = Color3.fromRGB(145, 28, 38), -- Deep crimson trim
	WindowMaterial = Enum.Material.Neon,
	WindowGlowColor = Color3.fromRGB(130, 24, 32), -- Dull red glowing windows (not blinding neon)
	FissureGlowColor = Color3.fromRGB(195, 35, 42),

	-- Storm Clouds & Ember Particles
	CloudEmitterRingCount = 4,
	DarkCloudColor = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(32, 20, 24)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(54, 22, 28)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 14, 18)),
	}),
	EmberColor = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 115, 65)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(225, 38, 48)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(95, 16, 22)),
	}),
}

--============================================================================
-- HELPER FUNCTIONS
--============================================================================
local function makePart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local isDecorative = props.Decorative ~= false
	if isDecorative then
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = false
	else
		p.CanCollide = true
		p.CanTouch = false
		p.CanQuery = true
	end
	for k, v in pairs(props) do
		if k ~= "Decorative" and k ~= "Parent" and k ~= "Diameter" and k ~= "Height" and k ~= "Position" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end

local function makeCylinder(props: { [string]: any }): Part
	local p = makePart(props)
	p.Shape = Enum.PartType.Cylinder
	local pos: Vector3 = props.Position or Vector3.zero
	local height: number = props.Height or 1
	local diameter: number = props.Diameter or 4
	p.Size = Vector3.new(height, diameter, diameter)
	p.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	return p
end

--============================================================================
-- BUILDER
--============================================================================
function TowerBuilder.Build(parent: Instance?, customConfig: { [string]: any }?): Model
	local cfg = table.clone(TowerBuilder.Config)
	if customConfig then
		for k, v in pairs(customConfig) do
			(cfg :: any)[k] = v
		end
	end

	local towerModel = Instance.new("Model")
	towerModel.Name = "CentralCrimsonTower"

	local origin = cfg.CenterPosition
	local ringHeight = cfg.TowerHeight / cfg.RingCount

	-- 1. Cracked, Dark, Smoky Base Ground with Faint Red Glow from Below
	local baseGroundFolder = Instance.new("Folder")
	baseGroundFolder.Name = "CrackedSmokyBase"
	baseGroundFolder.Parent = towerModel

	local basePlinth = makeCylinder({
		Name = "CrackedGroundSlab",
		Diameter = cfg.CrackedGroundDiameter,
		Height = 2.0,
		Position = origin + Vector3.new(0, -0.6, 0),
		Material = Enum.Material.CrackedLava,
		Color = Color3.fromRGB(28, 18, 22),
		Decorative = false,
		Parent = baseGroundFolder,
	})
	towerModel.PrimaryPart = basePlinth

	-- Radiant Crimson Fissure Lines & Faint Red Under-Glow
	for i = 1, cfg.CrackedFissureCount do
		local angle = ((i - 1) / cfg.CrackedFissureCount) * (math.pi * 2)
		local r = cfg.BaseDiameter * 0.49
		local pos = origin + Vector3.new(math.cos(angle) * r, 0.35, math.sin(angle) * r)
		makePart({
			Name = string.format("CrimsonFissure_%d", i),
			Size = Vector3.new(2.0, 0.25, 44),
			CFrame = CFrame.new(pos) * CFrame.Angles(0, -angle + math.pi * 0.5, 0),
			Material = Enum.Material.Neon,
			Color = cfg.FissureGlowColor,
			Transparency = 0.35,
			Decorative = true,
			Parent = baseGroundFolder,
		})
	end

	local baseLightPart = makePart({
		Name = "BaseRedUnderGlow",
		Size = Vector3.new(4, 4, 4),
		CFrame = CFrame.new(origin + Vector3.new(0, 8, 0)),
		Transparency = 1,
		Decorative = true,
		Parent = baseGroundFolder,
	})
	local baseGlow = Instance.new("PointLight")
	baseGlow.Name = "AbyssalUnderGlow"
	baseGlow.Color = Color3.fromRGB(220, 42, 52)
	baseGlow.Brightness = 2.5
	baseGlow.Range = 60
	baseGlow.Shadows = false
	baseGlow.Parent = baseLightPart

	-- 2. Stacked Tapered Colosseum/Renaissance Rings
	local ringsFolder = Instance.new("Folder")
	ringsFolder.Name = "TowerRings"
	ringsFolder.Parent = towerModel

	for ringIdx = 1, cfg.RingCount do
		local t = (ringIdx - 1) / math.max(1, cfg.RingCount - 1)
		local diameter = cfg.BaseDiameter + (cfg.TopDiameter - cfg.BaseDiameter) * t
		local radius = diameter * 0.5
		local ringCenterY = origin.Y + (ringIdx - 0.5) * ringHeight
		local ringTopY = origin.Y + ringIdx * ringHeight

		-- Main Dark Charcoal Core Cylinder for this Floor
		makeCylinder({
			Name = string.format("TowerRingCore_%02d", ringIdx),
			Diameter = diameter,
			Height = ringHeight,
			Position = Vector3.new(origin.X, ringCenterY, origin.Z),
			Material = cfg.BodyMaterial,
			Color = cfg.BodyColor,
			Decorative = (ringIdx > 1),
			Parent = ringsFolder,
		})

		-- Prominent Crimson Cornice Ledge at the top of each ring
		makeCylinder({
			Name = string.format("TowerRingLedge_%02d", ringIdx),
			Diameter = diameter + 7.5,
			Height = 3.6,
			Position = Vector3.new(origin.X, ringTopY - 1.4, origin.Z),
			Material = cfg.TrimMaterial,
			Color = cfg.CrimsonTrimColor,
			Decorative = true,
			Parent = ringsFolder,
		})

		-- Secondary Stone Trim Band below the ledge
		makeCylinder({
			Name = string.format("TowerRingBand_%02d", ringIdx),
			Diameter = diameter + 4.5,
			Height = 2.4,
			Position = Vector3.new(origin.X, ringCenterY - ringHeight * 0.36, origin.Z),
			Material = cfg.PillarMaterial,
			Color = cfg.PillarColor,
			Decorative = true,
			Parent = ringsFolder,
		})

		-- Arched Glowing Windows, Mullions & Pilaster Columns around the Ring
		local windowH = ringHeight * 0.46
		local windowW = math.clamp((math.pi * diameter / cfg.WindowsPerRing) * 0.44, 5, 12)

		for wIdx = 1, cfg.WindowsPerRing do
			local angle = ((wIdx - 1) / cfg.WindowsPerRing) * (math.pi * 2)
			local ca, sa = math.cos(angle), math.sin(angle)
			local wPos = Vector3.new(origin.X + ca * (radius - 0.3), ringCenterY - 1.5, origin.Z + sa * (radius - 0.3))
			local lookCF = CFrame.lookAt(wPos, Vector3.new(origin.X + ca * (radius + 10), wPos.Y, origin.Z + sa * (radius + 10)))

			-- Dull-Red Glowing Window Pane
			makePart({
				Name = string.format("Window_%02d_%02d", ringIdx, wIdx),
				Size = Vector3.new(windowW, windowH, 1.6),
				CFrame = lookCF,
				Material = cfg.WindowMaterial,
				Color = cfg.WindowGlowColor,
				Transparency = 0.22,
				Decorative = true,
				Parent = ringsFolder,
			})

			-- Arched Window Crown
			local archPos = wPos + Vector3.new(0, windowH * 0.5, 0)
			makePart({
				Name = string.format("WindowArch_%02d_%02d", ringIdx, wIdx),
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.6, windowW, windowW),
				CFrame = CFrame.lookAt(archPos, archPos + lookCF.RightVector),
				Material = cfg.WindowMaterial,
				Color = cfg.WindowGlowColor,
				Transparency = 0.22,
				Decorative = true,
				Parent = ringsFolder,
			})

			-- Dark Stone Center Mullion Bar
			makePart({
				Name = string.format("WindowMullionV_%02d_%02d", ringIdx, wIdx),
				Size = Vector3.new(1.1, windowH + windowW * 0.45, 2.2),
				CFrame = lookCF * CFrame.new(0, windowW * 0.15, 0),
				Material = cfg.BodyMaterial,
				Color = cfg.BodyColor,
				Decorative = true,
				Parent = ringsFolder,
			})

			-- Pilaster Column between Windows
			local colAngle = angle + (math.pi / cfg.WindowsPerRing)
			local colPos = Vector3.new(
				origin.X + math.cos(colAngle) * (radius + 0.8),
				ringCenterY,
				origin.Z + math.sin(colAngle) * (radius + 0.8)
			)
			makePart({
				Name = string.format("Pilaster_%02d_%02d", ringIdx, wIdx),
				Size = Vector3.new(3.4, ringHeight - 3.2, 3.6),
				CFrame = CFrame.lookAt(colPos, Vector3.new(origin.X, colPos.Y, origin.Z)),
				Material = cfg.PillarMaterial,
				Color = cfg.PillarColor,
				Decorative = true,
				Parent = ringsFolder,
			})
		end

		if ringIdx % 6 == 0 then
			task.wait()
		end
	end

	-- 3. Large Non-Functional Entrance at the Base (Easy to hook up later)
	local entranceModel = Instance.new("Model")
	entranceModel.Name = "TowerBaseEntrance"
	entranceModel:SetAttribute("IsFunctional", false)
	entranceModel:SetAttribute("HookupNote", "Connect Touched or ProximityPrompt on EntrancePortalTrigger to activate later.")
	entranceModel.Parent = towerModel

	local entranceYaw = math.rad(cfg.EntranceOrientationYawDeg)
	local baseRadius = cfg.BaseDiameter * 0.5
	local gatePos = origin + Vector3.new(math.sin(entranceYaw) * (baseRadius + 2), cfg.EntranceHeight * 0.5, math.cos(entranceYaw) * (baseRadius + 2))
	local gateCF = CFrame.lookAt(gatePos, gatePos + Vector3.new(math.sin(entranceYaw), 0, math.cos(entranceYaw)))

	for _, signX in ipairs({ -1, 1 }) do
		makePart({
			Name = signX < 0 and "EntrancePillar_Left" or "EntrancePillar_Right",
			Size = Vector3.new(8, cfg.EntranceHeight + 6, 10),
			CFrame = gateCF * CFrame.new(signX * (cfg.EntranceWidth * 0.5 + 4), 3, 0),
			Material = cfg.PillarMaterial,
			Color = cfg.BodyColor,
			Decorative = false,
			Parent = entranceModel,
		})
	end
	makePart({
		Name = "EntranceCrimsonHeader",
		Size = Vector3.new(cfg.EntranceWidth + 20, 7, 12),
		CFrame = gateCF * CFrame.new(0, cfg.EntranceHeight * 0.5 + 3.5, 0),
		Material = cfg.TrimMaterial,
		Color = cfg.CrimsonTrimColor,
		Decorative = false,
		Parent = entranceModel,
	})

	local portalTrigger = makePart({
		Name = "EntrancePortalTrigger",
		Size = Vector3.new(cfg.EntranceWidth, cfg.EntranceHeight, 2.5),
		CFrame = gateCF,
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(95, 14, 22),
		Transparency = 0.15,
		Decorative = false,
		Parent = entranceModel,
	})
	entranceModel.PrimaryPart = portalTrigger

	-- 4. Swirling Dark Clouds & Floating Red Embers/Ash Particles
	local vfxFolder = Instance.new("Folder")
	vfxFolder.Name = "TowerStormVFX"
	vfxFolder.Parent = towerModel

	for i = 1, cfg.CloudEmitterRingCount do
		local hFrac = (i - 0.5) / cfg.CloudEmitterRingCount
		local emitterY = origin.Y + hFrac * (cfg.TowerHeight * 0.75)
		local emitterPart = makePart({
			Name = string.format("StormEmitterBand_%d", i),
			Size = Vector3.new(cfg.BaseDiameter * 0.85, 4, cfg.BaseDiameter * 0.85),
			CFrame = CFrame.new(origin.X, emitterY, origin.Z),
			Transparency = 1,
			Decorative = true,
			Parent = vfxFolder,
		})

		local darkClouds = Instance.new("ParticleEmitter")
		darkClouds.Name = "SwirlingDarkClouds"
		darkClouds.Texture = "rbxassetid://243660364"
		darkClouds.Color = cfg.DarkCloudColor
		darkClouds.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 1.0),
			NumberSequenceKeypoint.new(0.25, 0.35),
			NumberSequenceKeypoint.new(0.75, 0.45),
			NumberSequenceKeypoint.new(1.0, 1.0),
		})
		darkClouds.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 36),
			NumberSequenceKeypoint.new(0.5, 58),
			NumberSequenceKeypoint.new(1.0, 72),
		})
		darkClouds.Lifetime = NumberRange.new(8, 12)
		darkClouds.Rate = 8
		darkClouds.Speed = NumberRange.new(6, 12)
		darkClouds.SpreadAngle = Vector2.new(180, 15)
		darkClouds.Rotation = NumberRange.new(0, 360)
		darkClouds.RotSpeed = NumberRange.new(-22, 22)
		darkClouds.Parent = emitterPart

		local redEmbers = Instance.new("ParticleEmitter")
		redEmbers.Name = "RisingRedEmbers"
		redEmbers.Texture = "rbxassetid://241685484"
		redEmbers.Color = cfg.EmberColor
		redEmbers.LightEmission = 1.0
		redEmbers.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 0.2),
			NumberSequenceKeypoint.new(0.7, 0.1),
			NumberSequenceKeypoint.new(1.0, 1.0),
		})
		redEmbers.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 1.8),
			NumberSequenceKeypoint.new(0.5, 2.8),
			NumberSequenceKeypoint.new(1.0, 0.5),
		})
		redEmbers.Lifetime = NumberRange.new(5, 9)
		redEmbers.Rate = 12
		redEmbers.Speed = NumberRange.new(10, 22)
		redEmbers.SpreadAngle = Vector2.new(180, 35)
		redEmbers.Acceleration = Vector3.new(0, 6, 0)
		redEmbers.Parent = emitterPart
	end

 -- Ring2WidthMatch: widen horizontally while preserving tower height and taper.
 local arena = workspace:FindFirstChild("ArenaRings")
 local ring2 = arena and arena:FindFirstChild("Ring2_CorruptedGrove")
 local floor = ring2 and ring2:FindFirstChild("Ring2_Floor")
 local targetDiameter = if floor and floor:IsA("BasePart") then floor.Size.Y else 650
 local horizontalScale = targetDiameter / cfg.BaseDiameter
 local partCount = 0
 for _, part in towerModel:GetDescendants() do
  if part:IsA("BasePart") then
   local cf = part.CFrame
   local offset = cf.Position - origin
   local function axisScale(axis: Vector3): number
    return Vector3.new(axis.X * horizontalScale, axis.Y, axis.Z * horizontalScale).Magnitude
   end
   part.Size = Vector3.new(part.Size.X * axisScale(cf.RightVector), part.Size.Y * axisScale(cf.UpVector), part.Size.Z * axisScale(cf.LookVector))
   part.CFrame = CFrame.new(origin + Vector3.new(offset.X * horizontalScale, offset.Y, offset.Z * horizontalScale)) * cf.Rotation
   partCount += 1
   if partCount % 300 == 0 then task.wait() end
  end
 end

	if parent then
		towerModel.Parent = parent
	end

	return towerModel
end

return TowerBuilder
