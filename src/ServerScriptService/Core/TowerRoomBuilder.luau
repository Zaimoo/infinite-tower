--!strict
-- Part 2/4 Tower Room Builder: constructs all 50 playable floors across 10 biomes
-- and 5 architectural layout variants per biome while preserving safe arrival,
-- camera enclosure, flat combat navigation, and travel pedestals.
local Config = require(game.ReplicatedStorage.Shared.Config.TowerFloorConfig)
local Builder = {}

type BiomeTheme = {
	GroundColor: Color3,
	WallColor: Color3,
	TrimColor: Color3,
	AccentColor: Color3,
	LightColor: Color3,
	GroundMaterial: Enum.Material,
	WallMaterial: Enum.Material,
	TrimMaterial: Enum.Material,
	PropKind: string,
}

local Themes: { [string]: BiomeTheme } = {
	verdant_ruins = {
		GroundColor = Color3.fromRGB(54, 66, 56),
		WallColor = Color3.fromRGB(44, 52, 46),
		TrimColor = Color3.fromRGB(96, 114, 98),
		AccentColor = Color3.fromRGB(72, 128, 58),
		LightColor = Color3.fromRGB(165, 240, 145),
		GroundMaterial = Enum.Material.Slate,
		WallMaterial = Enum.Material.Cobblestone,
		TrimMaterial = Enum.Material.Slate,
		PropKind = "RUIN_PILLAR",
	},
	fungal_hollow = {
		GroundColor = Color3.fromRGB(46, 36, 58),
		WallColor = Color3.fromRGB(36, 28, 48),
		TrimColor = Color3.fromRGB(88, 66, 112),
		AccentColor = Color3.fromRGB(64, 175, 162),
		LightColor = Color3.fromRGB(115, 255, 225),
		GroundMaterial = Enum.Material.Slate,
		WallMaterial = Enum.Material.Slate,
		TrimMaterial = Enum.Material.SmoothPlastic,
		PropKind = "GIANT_MUSHROOM",
	},
	sunken_sanctuary = {
		GroundColor = Color3.fromRGB(34, 58, 72),
		WallColor = Color3.fromRGB(28, 46, 58),
		TrimColor = Color3.fromRGB(78, 122, 138),
		AccentColor = Color3.fromRGB(212, 104, 94),
		LightColor = Color3.fromRGB(110, 225, 255),
		GroundMaterial = Enum.Material.Slate,
		WallMaterial = Enum.Material.Brick,
		TrimMaterial = Enum.Material.Marble,
		PropKind = "CORAL_SPIRE",
	},
	ashen_dunes = {
		GroundColor = Color3.fromRGB(98, 76, 54),
		WallColor = Color3.fromRGB(78, 58, 42),
		TrimColor = Color3.fromRGB(154, 118, 78),
		AccentColor = Color3.fromRGB(210, 155, 75),
		LightColor = Color3.fromRGB(255, 185, 95),
		GroundMaterial = Enum.Material.Sandstone,
		WallMaterial = Enum.Material.Sandstone,
		TrimMaterial = Enum.Material.Granite,
		PropKind = "OBELISK",
	},
	frozen_citadel = {
		GroundColor = Color3.fromRGB(62, 84, 110),
		WallColor = Color3.fromRGB(48, 66, 88),
		TrimColor = Color3.fromRGB(145, 188, 225),
		AccentColor = Color3.fromRGB(185, 230, 255),
		LightColor = Color3.fromRGB(145, 235, 255),
		GroundMaterial = Enum.Material.Slate,
		WallMaterial = Enum.Material.Brick,
		TrimMaterial = Enum.Material.Ice,
		PropKind = "ICE_CRYSTAL",
	},
	thunder_highlands = {
		GroundColor = Color3.fromRGB(52, 56, 76),
		WallColor = Color3.fromRGB(40, 44, 62),
		TrimColor = Color3.fromRGB(104, 112, 148),
		AccentColor = Color3.fromRGB(225, 195, 88),
		LightColor = Color3.fromRGB(255, 230, 120),
		GroundMaterial = Enum.Material.Slate,
		WallMaterial = Enum.Material.Granite,
		TrimMaterial = Enum.Material.Metal,
		PropKind = "STORM_COIL",
	},
	infernal_foundry = {
		GroundColor = Color3.fromRGB(44, 34, 36),
		WallColor = Color3.fromRGB(34, 26, 28),
		TrimColor = Color3.fromRGB(88, 56, 52),
		AccentColor = Color3.fromRGB(215, 95, 42),
		LightColor = Color3.fromRGB(255, 130, 55),
		GroundMaterial = Enum.Material.Basalt,
		WallMaterial = Enum.Material.Metal,
		TrimMaterial = Enum.Material.DiamondPlate,
		PropKind = "FURNACE_STACK",
	},
	corrupted_grove = {
		GroundColor = Color3.fromRGB(44, 34, 46),
		WallColor = Color3.fromRGB(34, 26, 36),
		TrimColor = Color3.fromRGB(84, 58, 78),
		AccentColor = Color3.fromRGB(158, 68, 142),
		LightColor = Color3.fromRGB(220, 110, 250),
		GroundMaterial = Enum.Material.Slate,
		WallMaterial = Enum.Material.Wood,
		TrimMaterial = Enum.Material.Wood,
		PropKind = "BLIGHT_TREE",
	},
	astral_archives = {
		GroundColor = Color3.fromRGB(38, 42, 72),
		WallColor = Color3.fromRGB(28, 32, 56),
		TrimColor = Color3.fromRGB(92, 102, 164),
		AccentColor = Color3.fromRGB(225, 196, 118),
		LightColor = Color3.fromRGB(165, 215, 255),
		GroundMaterial = Enum.Material.Marble,
		WallMaterial = Enum.Material.Slate,
		TrimMaterial = Enum.Material.Marble,
		PropKind = "ARCHIVE_STACK",
	},
	abyssal_throne = {
		GroundColor = Color3.fromRGB(32, 22, 32),
		WallColor = Color3.fromRGB(24, 16, 26),
		TrimColor = Color3.fromRGB(82, 32, 48),
		AccentColor = Color3.fromRGB(185, 38, 64),
		LightColor = Color3.fromRGB(255, 82, 108),
		GroundMaterial = Enum.Material.Basalt,
		WallMaterial = Enum.Material.Metal,
		TrimMaterial = Enum.Material.Marble,
		PropKind = "THRONE_SPIRE",
	},
}

function Builder.Origin(id: number): Vector3
	if id == 0 then return Vector3.zero end
	return Vector3.new(12000 + ((id - 1) % 10) * 1800, 1000, 12000 + math.floor((id - 1) / 10) * 1800)
end

local function part(parent: Instance, name: string, size: Vector3, pos: Vector3, color: Color3, mat: Enum.Material?, canCollide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = pos
	p.Anchored = true
	p.CanCollide = if canCollide ~= nil then canCollide else true
	p.Material = mat or Enum.Material.Slate
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function buildBiomeProp(parent: Instance, theme: BiomeTheme, basePos: Vector3, heightScale: number)
	local h = 18 * heightScale
	local kind = theme.PropKind
	if kind == "GIANT_MUSHROOM" then
		part(parent, "FungalStalk", Vector3.new(4.5, h, 4.5), basePos + Vector3.new(0, h * 0.5, 0), theme.TrimColor, theme.TrimMaterial)
		local cap = part(parent, "FungalCap", Vector3.new(3.5, 13 * heightScale, 13 * heightScale), basePos + Vector3.new(0, h + 1, 0), theme.AccentColor, Enum.Material.SmoothPlastic, false)
		cap.Shape = Enum.PartType.Cylinder
		cap.CFrame = CFrame.new(basePos + Vector3.new(0, h + 1, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		part(parent, "SporeGlow", Vector3.new(5, 0.6, 5), basePos + Vector3.new(0, h - 0.6, 0), theme.LightColor, Enum.Material.Neon, false)
	elseif kind == "ICE_CRYSTAL" or kind == "CORAL_SPIRE" then
		part(parent, "SpireBase", Vector3.new(7, 3, 7), basePos + Vector3.new(0, 1.5, 0), theme.TrimColor, theme.TrimMaterial)
		part(parent, "CrystalShaft", Vector3.new(4.5, h, 4.5), basePos + Vector3.new(0, h * 0.5 + 2, 0), theme.AccentColor, theme.TrimMaterial)
		part(parent, "CrystalTip", Vector3.new(2.4, 4.5, 2.4), basePos + Vector3.new(0, h + 4, 0), theme.LightColor, Enum.Material.Neon, false)
	elseif kind == "STORM_COIL" or kind == "FURNACE_STACK" then
		part(parent, "IndustrialPillar", Vector3.new(6.5, h, 6.5), basePos + Vector3.new(0, h * 0.5, 0), theme.TrimColor, theme.TrimMaterial)
		part(parent, "EnergyRing1", Vector3.new(8.2, 1.2, 8.2), basePos + Vector3.new(0, h * 0.45, 0), theme.LightColor, Enum.Material.Neon, false)
		part(parent, "EnergyRing2", Vector3.new(8.2, 1.2, 8.2), basePos + Vector3.new(0, h * 0.8, 0), theme.LightColor, Enum.Material.Neon, false)
	elseif kind == "BLIGHT_TREE" then
		part(parent, "TwistedTrunk", Vector3.new(5.5, h, 5.5), basePos + Vector3.new(0, h * 0.5, 0), theme.TrimColor, Enum.Material.Wood)
		part(parent, "BlightCanopy", Vector3.new(12 * heightScale, 4, 12 * heightScale), basePos + Vector3.new(0, h + 1.5, 0), theme.AccentColor, Enum.Material.Slate, false)
		part(parent, "HeartrotNode", Vector3.new(2.2, 2.2, 2.2), basePos + Vector3.new(0, h * 0.55, 0), theme.LightColor, Enum.Material.Neon, false)
	else
		part(parent, "PillarBase", Vector3.new(8, 3, 8), basePos + Vector3.new(0, 1.5, 0), theme.TrimColor, theme.TrimMaterial)
		part(parent, "PillarShaft", Vector3.new(5.5, h, 5.5), basePos + Vector3.new(0, h * 0.5 + 1.5, 0), theme.TrimColor, theme.TrimMaterial)
		part(parent, "PillarCap", Vector3.new(8.5, 2.5, 8.5), basePos + Vector3.new(0, h + 3, 0), theme.AccentColor, theme.TrimMaterial)
		part(parent, "PillarRune", Vector3.new(6.2, 1.4, 6.2), basePos + Vector3.new(0, h * 0.6, 0), theme.LightColor, Enum.Material.Neon, false)
	end
end

function Builder.Build(id: number, generation: number): any
	assert(Config.IsFloorId(id))
	local floorSpec = assert(Config.Get(id))
	local theme = Themes[floorSpec.BiomeId] or Themes.verdant_ruins
	local origin = Builder.Origin(id)
	local idx = floorSpec.IndexInBiome

	local model = Instance.new("Model")
	model.Name = string.format("Floor_%02d", id)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model:SetAttribute("FloorId", id)
	model:SetAttribute("RoomGeneration", generation)
	model:SetAttribute("BiomeId", floorSpec.BiomeId)
	model:SetAttribute("LayoutId", floorSpec.LayoutId)
	model:SetAttribute("EnvironmentVariantId", floorSpec.EnvironmentVariantId)
	model:SetAttribute("VariantKind", floorSpec.VariantKind)
	model:SetAttribute("ContentStatus", "LOCAL_AUTHORED_PROTOTYPE")
	model:SetAttribute("EncountersEnabled", false)

	-- Room envelope (camera-isolated 248x84x248 chamber)
	part(model, "Ground", Vector3.new(248, 4, 248), origin - Vector3.new(0, 2, 0), theme.GroundColor, theme.GroundMaterial)
	for _, s in { -1, 1 } do
		part(model, "WallX", Vector3.new(6, 84, 248), origin + Vector3.new(s * 124, 40, 0), theme.WallColor, theme.WallMaterial)
		part(model, "WallZ", Vector3.new(248, 84, 6), origin + Vector3.new(0, 40, s * 124), theme.WallColor, theme.WallMaterial)
		part(model, "WallTrimX", Vector3.new(2, 6, 240), origin + Vector3.new(s * 120, 3, 0), theme.TrimColor, theme.TrimMaterial)
	end
	part(model, "OpaqueCeiling", Vector3.new(254, 6, 254), origin + Vector3.new(0, 84, 0), theme.WallColor, theme.WallMaterial)

	-- Flush non-colliding walkway inlay from SafeArrival to Combat Court
	part(model, "SanctumWalkway", Vector3.new(26, 0.12, 130), origin + Vector3.new(0, 0.04, 10), theme.TrimColor, theme.TrimMaterial, false)

	-- SafeArrival platform & arrival lighting
	local landing = part(model, "SafeArrival", Vector3.new(70, .2, 42), origin + Vector3.new(0, .1, 90), Color3.fromRGB(45, 100, 115), Enum.Material.Marble)
	local light = Instance.new("PointLight")
	light.Range = 60
	light.Brightness = 2.6
	light.Color = theme.LightColor
	light.Parent = landing

	for _, pos in { Vector3.new(-65, 22, -45), Vector3.new(65, 22, -45), Vector3.new(-65, 22, 25), Vector3.new(65, 22, 25), Vector3.new(0, 26, -15) } do
		local lamp = part(model, "BiomeLantern", Vector3.new(2.5, 2.5, 2.5), origin + pos, theme.LightColor, Enum.Material.Neon, false)
		local l = Instance.new("PointLight")
		l.Range = 95
		l.Brightness = 1.8
		l.Color = theme.LightColor
		l.Parent = lamp
	end

	-- Variant-specific architecture outside the central combat navigation lane
	local scaleBoost = 1 + (idx - 1) * 0.08
	if idx == 1 then
		-- INTRODUCTION: Entry gateway framing the threshold + 4 perimeter columns
		for _, side in { -1, 1 } do
			buildBiomeProp(model, theme, origin + Vector3.new(side * 54, 0, 38), scaleBoost)
			buildBiomeProp(model, theme, origin + Vector3.new(side * 65, 0, -20), scaleBoost)
		end
		part(model, "ThresholdArch", Vector3.new(114, 4, 6), origin + Vector3.new(0, 22, 38), theme.TrimColor, theme.TrimMaterial)
		if id == 1 then
			for _, x in { -65, 65 } do
				part(model, "RuinsFixture", Vector3.new(12, 18, 12), origin + Vector3.new(x, 9, -20), theme.TrimColor, theme.TrimMaterial)
			end
		end
	elseif idx == 2 then
		-- EXPANDED_ENCOUNTER: 6 colonnade pillars + lateral gallery beams
		for _, side in { -1, 1 } do
			for _, z in { 28, -8, -44 } do
				buildBiomeProp(model, theme, origin + Vector3.new(side * 62, 0, z), scaleBoost)
			end
			part(model, "GalleryBeam", Vector3.new(5, 3, 84), origin + Vector3.new(side * 62, 21, -8), theme.TrimColor, theme.TrimMaterial)
		end
	elseif idx == 3 then
		-- TERRAIN_VARIATION: Flush elemental channels + 6 staggered monoliths
		for _, side in { -1, 1 } do
			part(model, "ElementalChannel", Vector3.new(10, 0.14, 110), origin + Vector3.new(side * 38, 0.05, -12), theme.LightColor, Enum.Material.Neon, false)
			for _, z in { 24, -14, -50 } do
				buildBiomeProp(model, theme, origin + Vector3.new(side * 58, 0, z), scaleBoost * 1.08)
			end
		end
		local ring = part(model, "ArenaCenterInlay", Vector3.new(0.14, 34, 34), origin + Vector3.new(0, 0.05, -14), theme.AccentColor, theme.TrimMaterial, false)
		ring.Shape = Enum.PartType.Cylinder
		ring.CFrame = CFrame.new(origin + Vector3.new(0, 0.05, -14)) * CFrame.Angles(0, 0, math.pi / 2)
	elseif idx == 4 then
		-- ELITE_STRONGHOLD: Twin gatehouse bastions + fortified perimeter buttresses
		for _, side in { -1, 1 } do
			part(model, "BastionTower", Vector3.new(14, 28, 14), origin + Vector3.new(side * 54, 14, 30), theme.TrimColor, theme.TrimMaterial)
			part(model, "BastionCrest", Vector3.new(16, 3, 16), origin + Vector3.new(side * 54, 29, 30), theme.AccentColor, theme.TrimMaterial)
			buildBiomeProp(model, theme, origin + Vector3.new(side * 60, 0, -16), scaleBoost * 1.12)
			buildBiomeProp(model, theme, origin + Vector3.new(side * 56, 0, -52), scaleBoost * 1.15)
		end
		part(model, "StrongholdInlay", Vector3.new(64, 0.15, 28), origin + Vector3.new(0, 0.06, -44), theme.AccentColor, theme.TrimMaterial, false)
	else
		-- BOSS_ARENA (Floors 5, 10, ..., 50): Ceremonial boss dais, 8 temple columns, and apex backdrop monument
		part(model, "BossDaisFixture", Vector3.new(60, 0.3, 60), origin + Vector3.new(0, 0.12, -54), theme.AccentColor, theme.TrimMaterial, false)
		local bossRing = part(model, "BossRunicRing", Vector3.new(0.18, 46, 46), origin + Vector3.new(0, 0.14, -54), theme.LightColor, Enum.Material.Neon, false)
		bossRing.Shape = Enum.PartType.Cylinder
		bossRing.CFrame = CFrame.new(origin + Vector3.new(0, 0.14, -54)) * CFrame.Angles(0, 0, math.pi / 2)
		for _, side in { -1, 1 } do
			for _, z in { 26, -2, -30, -58 } do
				buildBiomeProp(model, theme, origin + Vector3.new(side * 64, 0, z), 1.35)
			end
		end
		part(model, "SanctumBackdrop", Vector3.new(44, 36, 10), origin + Vector3.new(0, 18, -94), theme.TrimColor, theme.TrimMaterial)
		part(model, "SanctumCore", Vector3.new(12, 22, 2), origin + Vector3.new(0, 20, -88), theme.LightColor, Enum.Material.Neon, false)
		if id == 50 then
			for _, x in { -60, 60 } do
				part(model, "ThroneProbeFixture", Vector3.new(16, 30, 16), origin + Vector3.new(x, 15, -55), theme.TrimColor, theme.TrimMaterial)
			end
		end
	end

	-- Travel pedestals in the Arrival Safe Zone
	for i, action in { "PREVIOUS", "NEXT", "SELECTOR", "HUB" } do
		local p = part(model, action, Vector3.new(10, 7, 4), origin + Vector3.new((i - 2.5) * 17, 3.5, 111), Color3.fromRGB(105, 34, 51), Enum.Material.Marble)
		local prompt = Instance.new("ProximityPrompt")
		local actionText = if action == "PREVIOUS" then "Previous Floor"
			elseif action == "NEXT" then "Next Floor"
			elseif action == "SELECTOR" then "Choose Floor"
			elseif action == "HUB" then "Return to Hub"
			else action
		local objectText = if action == "PREVIOUS" then string.format("Floor %d", id - 1)
			elseif action == "NEXT" then string.format("Floor %d", id + 1)
			elseif action == "SELECTOR" or action == "HUB" then "Infinite Tower"
			else "Tower travel"
		prompt.ActionText = actionText
		prompt.ObjectText = objectText
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.F
		prompt:SetAttribute("TowerAction", action)
		prompt.Enabled = not ((action == "PREVIOUS" and id == 1) or (action == "NEXT" and id == 50))
		prompt.Parent = p

		local bg = Instance.new("BillboardGui")
		bg.Name = "PedestalLabel"
		bg.Size = UDim2.fromOffset(130, 28)
		bg.StudsOffset = Vector3.new(0, 4.5, 0)
		bg.AlwaysOnTop = false
		bg.MaxDistance = 50
		bg.Parent = p
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.BackgroundTransparency = 0.3
		lbl.BackgroundColor3 = Color3.fromRGB(24, 20, 30)
		lbl.TextColor3 = Color3.fromRGB(245, 235, 225)
		lbl.Font = Enum.Font.GothamBold
		lbl.TextSize = 13
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = lbl
		if action == "PREVIOUS" and id == 1 then
			lbl.Text = "Floor 1 (Lowest)"
			lbl.TextColor3 = Color3.fromRGB(140, 130, 130)
		elseif action == "NEXT" and id == 50 then
			lbl.Text = "Floor 50 (Apex)"
			lbl.TextColor3 = Color3.fromRGB(140, 130, 130)
		elseif action == "PREVIOUS" then
			lbl.Text = string.format("◀ Floor %d", id - 1)
		elseif action == "NEXT" then
			lbl.Text = string.format("Floor %d ▶", id + 1)
		elseif action == "SELECTOR" then
			lbl.Text = "Choose Floor"
		elseif action == "HUB" then
			lbl.Text = "Return to Hub"
		end
		lbl.Parent = bg
	end

	local sign = Instance.new("SurfaceGui")
	sign.Face = Enum.NormalId.Back
	sign.CanvasSize = Vector2.new(1000, 220)
	sign.Parent = model:FindFirstChild("WallZ")
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = string.format(
		"FLOOR %d · %s\n%s · %s",
		id,
		floorSpec.DisplayName,
		string.upper(floorSpec.BiomeDisplayName),
		string.gsub(floorSpec.VariantKind, "_", " ")
	)
	label.Parent = sign

	local folder = workspace:FindFirstChild("TowerRooms") or Instance.new("Folder")
	folder.Name = "TowerRooms"
	folder.Parent = workspace
	model.Parent = folder

	return {
		FloorId = id,
		RoomGeneration = generation,
		Origin = origin,
		Model = model,
		Arrival = CFrame.new(origin + Vector3.new(0, 3.5, 90)),
		Bounds = { Min = Vector3.new(-120, -4, -120), Max = Vector3.new(120, 78, 120) },
		Zones = {
			{
				ZoneId = "ARRIVAL",
				FloorId = id,
				RoomGeneration = generation,
				LocalPolygonXZ = {
					Vector2.new(-40, 65),
					Vector2.new(40, 65),
					Vector2.new(40, 118),
					Vector2.new(-40, 118),
				},
				MinY = -1,
				MaxY = 15,
				CombatSafe = true,
				CanBankCargo = false,
				CanRecoverWipe = false,
			},
		},
	}
end

return Builder
