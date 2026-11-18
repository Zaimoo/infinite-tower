--!strict
-- Part 2/4 Tower Room Builder: constructs all 50 playable floors across 10 biomes
-- and 5 architectural layout variants per biome while preserving safe arrival,
-- camera enclosure, multi-tier traversal, sanctuary extraction, and travel pedestals.
local Config = require(game.ReplicatedStorage.Shared.Config.TowerFloorConfig)
local Layout = require(game.ReplicatedStorage.Shared.Config.TowerLayout)
local BiomeAssets = require(script.Parent.TowerBiomeAssets)
local KitProps = require(script.Parent.TowerKitProps)
local TowerTerrain = require(script.Parent.TowerTerrain)
local StaticGeometry = require(script.Parent.StaticGeometry)
local PropClearance = require(script.Parent.TowerPropClearance)
local PortalKit = require(script.Parent.TowerPortalKit)
local PortalAssets = require(game.ReplicatedStorage.Shared.Config.TowerPortalAssets)
local Builder = {}

export type BiomeTheme = {
	GroundColor: Color3,
	SubFloorColor: Color3,
	CliffColor: Color3,
	WallColor: Color3,
	SkyColor: Color3,
	HorizonColor: Color3,
	TrimColor: Color3,
	AccentColor: Color3,
	LightColor: Color3,
	LiquidColor: Color3,
	GroundMaterial: Enum.Material,
	CliffMaterial: Enum.Material,
	WallMaterial: Enum.Material,
	TrimMaterial: Enum.Material,
	PropKind: string,
}

local Themes: { [string]: BiomeTheme } = {
	verdant_ruins = {
		GroundColor = Color3.fromRGB(64, 88, 58),
		SubFloorColor = Color3.fromRGB(34, 58, 48),
		CliffColor = Color3.fromRGB(72, 82, 68),
		WallColor = Color3.fromRGB(98, 142, 128),
		SkyColor = Color3.fromRGB(152, 198, 184),
		HorizonColor = Color3.fromRGB(245, 220, 155),
		TrimColor = Color3.fromRGB(132, 138, 118),
		AccentColor = Color3.fromRGB(82, 148, 66),
		LightColor = Color3.fromRGB(255, 232, 165),
		LiquidColor = Color3.fromRGB(38, 158, 132),
		GroundMaterial = Enum.Material.Cobblestone,
		CliffMaterial = Enum.Material.Rock,
		WallMaterial = Enum.Material.SmoothPlastic,
		TrimMaterial = Enum.Material.Slate,
		PropKind = "RUIN_PILLAR",
	},
	fungal_hollow = {
		GroundColor = Color3.fromRGB(46, 40, 66),
		SubFloorColor = Color3.fromRGB(24, 22, 42),
		CliffColor = Color3.fromRGB(38, 32, 58),
		WallColor = Color3.fromRGB(24, 28, 52),
		SkyColor = Color3.fromRGB(30, 42, 74),
		HorizonColor = Color3.fromRGB(85, 195, 235),
		TrimColor = Color3.fromRGB(92, 78, 124),
		AccentColor = Color3.fromRGB(118, 78, 215),
		LightColor = Color3.fromRGB(95, 245, 235),
		LiquidColor = Color3.fromRGB(36, 128, 168),
		GroundMaterial = Enum.Material.Cobblestone,
		CliffMaterial = Enum.Material.Slate,
		WallMaterial = Enum.Material.Slate,
		TrimMaterial = Enum.Material.Rock,
		PropKind = "GIANT_MUSHROOM",
	},
	ashen_dunes = {
		GroundColor = Color3.fromRGB(52, 44, 42),
		SubFloorColor = Color3.fromRGB(34, 28, 28),
		CliffColor = Color3.fromRGB(30, 24, 26),
		WallColor = Color3.fromRGB(84, 38, 30),
		SkyColor = Color3.fromRGB(112, 46, 32),
		HorizonColor = Color3.fromRGB(255, 135, 55),
		TrimColor = Color3.fromRGB(114, 88, 70),
		AccentColor = Color3.fromRGB(245, 115, 42),
		LightColor = Color3.fromRGB(255, 165, 75),
		LiquidColor = Color3.fromRGB(255, 92, 24),
		GroundMaterial = Enum.Material.Sand,
		CliffMaterial = Enum.Material.Basalt,
		WallMaterial = Enum.Material.SmoothPlastic,
		TrimMaterial = Enum.Material.Sandstone,
		PropKind = "OBELISK",
	},
	frozen_citadel = {
		GroundColor = Color3.fromRGB(78, 104, 134),
		SubFloorColor = Color3.fromRGB(44, 68, 98),
		CliffColor = Color3.fromRGB(58, 82, 112),
		WallColor = Color3.fromRGB(42, 62, 92),
		SkyColor = Color3.fromRGB(52, 82, 122),
		HorizonColor = Color3.fromRGB(145, 235, 255),
		TrimColor = Color3.fromRGB(165, 208, 238),
		AccentColor = Color3.fromRGB(115, 225, 255),
		LightColor = Color3.fromRGB(155, 240, 255),
		LiquidColor = Color3.fromRGB(115, 205, 238),
		GroundMaterial = Enum.Material.Slate,
		CliffMaterial = Enum.Material.Glacier,
		WallMaterial = Enum.Material.SmoothPlastic,
		TrimMaterial = Enum.Material.Ice,
		PropKind = "ICE_CRYSTAL",
	},
	infernal_foundry = {
		GroundColor = Color3.fromRGB(44, 34, 36),
		SubFloorColor = Color3.fromRGB(26, 18, 20),
		CliffColor = Color3.fromRGB(34, 24, 26),
		WallColor = Color3.fromRGB(42, 20, 18),
		SkyColor = Color3.fromRGB(48, 22, 18),
		HorizonColor = Color3.fromRGB(255, 115, 35),
		TrimColor = Color3.fromRGB(74, 54, 52),
		AccentColor = Color3.fromRGB(255, 108, 32),
		LightColor = Color3.fromRGB(255, 145, 55),
		LiquidColor = Color3.fromRGB(255, 98, 18),
		GroundMaterial = Enum.Material.Basalt,
		CliffMaterial = Enum.Material.Basalt,
		WallMaterial = Enum.Material.Slate,
		TrimMaterial = Enum.Material.Metal,
		PropKind = "FURNACE_STACK",
	},
	thunder_highlands = {
		GroundColor = Color3.fromRGB(62, 74, 66),
		SubFloorColor = Color3.fromRGB(44, 50, 66),
		CliffColor = Color3.fromRGB(74, 78, 88),
		WallColor = Color3.fromRGB(42, 46, 76),
		SkyColor = Color3.fromRGB(48, 52, 88),
		HorizonColor = Color3.fromRGB(155, 145, 255),
		TrimColor = Color3.fromRGB(112, 118, 136),
		AccentColor = Color3.fromRGB(125, 165, 255),
		LightColor = Color3.fromRGB(165, 195, 255),
		LiquidColor = Color3.fromRGB(215, 225, 245),
		GroundMaterial = Enum.Material.Cobblestone,
		CliffMaterial = Enum.Material.Rock,
		WallMaterial = Enum.Material.SmoothPlastic,
		TrimMaterial = Enum.Material.Slate,
		PropKind = "STORM_COIL",
	},
	corrupted_grove = {
		GroundColor = Color3.fromRGB(46, 32, 50),
		SubFloorColor = Color3.fromRGB(28, 18, 34),
		CliffColor = Color3.fromRGB(36, 24, 40),
		WallColor = Color3.fromRGB(48, 22, 46),
		SkyColor = Color3.fromRGB(64, 28, 60),
		HorizonColor = Color3.fromRGB(235, 85, 185),
		TrimColor = Color3.fromRGB(88, 64, 92),
		AccentColor = Color3.fromRGB(215, 62, 165),
		LightColor = Color3.fromRGB(245, 95, 205),
		LiquidColor = Color3.fromRGB(115, 36, 108),
		GroundMaterial = Enum.Material.Slate,
		CliffMaterial = Enum.Material.Rock,
		WallMaterial = Enum.Material.SmoothPlastic,
		TrimMaterial = Enum.Material.Cobblestone,
		PropKind = "BLIGHT_TREE",
	},
	sunken_sanctuary = {
		GroundColor = Color3.fromRGB(154, 178, 172),
		SubFloorColor = Color3.fromRGB(34, 92, 112),
		CliffColor = Color3.fromRGB(118, 148, 146),
		WallColor = Color3.fromRGB(32, 108, 132),
		SkyColor = Color3.fromRGB(48, 152, 178),
		HorizonColor = Color3.fromRGB(145, 245, 255),
		TrimColor = Color3.fromRGB(198, 206, 190),
		AccentColor = Color3.fromRGB(235, 188, 92),
		LightColor = Color3.fromRGB(125, 238, 255),
		LiquidColor = Color3.fromRGB(42, 182, 204),
		GroundMaterial = Enum.Material.Limestone,
		CliffMaterial = Enum.Material.Sandstone,
		WallMaterial = Enum.Material.SmoothPlastic,
		TrimMaterial = Enum.Material.Marble,
		PropKind = "CORAL_SPIRE",
	},
	astral_archives = {
		GroundColor = Color3.fromRGB(196, 204, 222),
		SubFloorColor = Color3.fromRGB(24, 28, 58),
		CliffColor = Color3.fromRGB(42, 48, 86),
		WallColor = Color3.fromRGB(20, 24, 52),
		SkyColor = Color3.fromRGB(26, 30, 68),
		HorizonColor = Color3.fromRGB(145, 165, 255),
		TrimColor = Color3.fromRGB(212, 176, 96),
		AccentColor = Color3.fromRGB(235, 198, 112),
		LightColor = Color3.fromRGB(165, 215, 255),
		LiquidColor = Color3.fromRGB(78, 122, 232),
		GroundMaterial = Enum.Material.Marble,
		CliffMaterial = Enum.Material.Marble,
		WallMaterial = Enum.Material.SmoothPlastic,
		TrimMaterial = Enum.Material.Metal,
		PropKind = "ARCHIVE_STACK",
	},
	abyssal_throne = {
		GroundColor = Color3.fromRGB(32, 26, 40),
		SubFloorColor = Color3.fromRGB(16, 22, 32),
		CliffColor = Color3.fromRGB(22, 18, 30),
		WallColor = Color3.fromRGB(18, 14, 28),
		SkyColor = Color3.fromRGB(22, 18, 36),
		HorizonColor = Color3.fromRGB(155, 95, 245),
		TrimColor = Color3.fromRGB(162, 136, 86),
		AccentColor = Color3.fromRGB(152, 88, 235),
		LightColor = Color3.fromRGB(95, 228, 242),
		LiquidColor = Color3.fromRGB(48, 178, 196),
		GroundMaterial = Enum.Material.Basalt,
		CliffMaterial = Enum.Material.Basalt,
		WallMaterial = Enum.Material.SmoothPlastic,
		TrimMaterial = Enum.Material.Marble,
		PropKind = "THRONE_SPIRE",
	},
}

-- A biome's theme (for the boss portals, which CombatSimulation builds after a boss falls).
function Builder.Theme(biomeId: string): BiomeTheme
	return Themes[biomeId] or Themes.verdant_ruins
end

function Builder.Origin(id: number): Vector3
	if id == 0 then return Vector3.zero end
	return Vector3.new(12000 + ((id - 1) % 10) * 2400, 1000, 12000 + math.floor((id - 1) / 10) * 2400)
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

local function decor(parent: Instance, name: string, size: Vector3, pos: Vector3, color: Color3, mat: Enum.Material?, transparency: number?): Part
	local solid = name == "BridgeCurb" or name == "SanctuarySideWall"
		or name == "TerraceRockOutcrop" or name == "TerraceCornerPedestal"
		or name == "TerraceMasonryBand" or name == "TerraceSideBand"
		or name == "TerracePlinthX" or name == "TerracePlinthZ" or name == "ViaductPier"
		or name == "BridgeHandrail" or name == "BridgeMidRail" or name == "BridgeNewelPost"
		or name == "BridgeNewelCap" or name == "BridgeRailPost" or name == "BridgeSideGirder"
		or name == "BridgeLakePier"
 local p = part(parent, name, size, pos, color, mat, solid)
 p.CanQuery = solid
 p:SetAttribute("SolidScenery", solid)
	p.CanTouch = false
	p.CastShadow = false
	if transparency then p.Transparency = transparency end
	return p
end

-- A compound decor piece (see TowerPropClearance): its parts are cleared together, never one by one.
local function propGroup(parent: Instance, kind: string): Model
	local prop = Instance.new("Model")
	prop.Name = kind
	prop:SetAttribute("PropKind", kind)
	prop.Parent = parent
	return prop
end

-- Hit test for scenery standing on a walkway (TowerLayout.Lanes: ramps, stairs, landing pads, the Basin
-- causeway and the Sanctuary exit). It judges biome scenery and corner decor; the walkway structure
-- itself (terraces, ramps, curbs, inlays), ramp arches and faint light shafts are exempt.
local WalkwayExemptKinds = { BridgeCurb = true, RampArch = true, GlassArchSpan = true, PortcullisGate = true, KitCaravanseraiSkylight = true, ElderForearmGuard = true, ElderUpperArmGuard = true }
local WalkwayExemptNames = { BasinCentralCauseway = true, BasinCausewayInlay = true }
local WalkwayEdgeTrim = { TerraceMasonryBand = true, TerraceSideBand = true }
function Builder.WalkwayHitTest(model: Instance, origin: Vector3, index: number): (BasePart) -> boolean
	local boxes = {}
	for _, lane in Layout.Lanes(index, model:GetAttribute("FloorId")) do
		local a = origin + Vector3.new(lane.AX, lane.AY, lane.AZ)
		local b = origin + Vector3.new(lane.BX, lane.BY, lane.BZ)
		local frame = CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, (lane.Above - lane.Below) / 2, 0)
		table.insert(boxes, { CFrame = frame, Size = Vector3.new(lane.HalfWidth * 2, lane.Below + lane.Above, (b - a).Magnitude) })
	end
	local kit = model:FindFirstChild("BiomeAssets")
	return function(part: BasePart): boolean
		if part.Transparency >= 0.85 or WalkwayExemptNames[part.Name] then
			return false
		end
		local unit = PropClearance.UnitOf(part, model)
		if unit == part then
			-- A loose part: only biome scenery, never the room's own floors, ramps and trim.
			if not (kit and part:IsDescendantOf(kit)) and not WalkwayEdgeTrim[part.Name] then
				return false
			end
		elseif WalkwayExemptKinds[unit:GetAttribute("PropKind")] then
			return false
		end
		for _, box in boxes do
			if PropClearance.BoxesOverlap(part.CFrame, part.Size, box.CFrame, box.Size) then
				return true
			end
		end
		return false
	end
end

-- Removes a floor's terrain (TowerFloorService calls this when the room retires).
function Builder.ClearTerrain(id: number)
	local floorSpec = Config.Get(id)
	if floorSpec then
		TowerTerrain.Clear(Builder.Origin(id), Layout.Get(floorSpec.IndexInBiome, id))
	end
end

function Builder.Build(id: number, generation: number): any
	assert(Config.IsFloorId(id))
	local floorSpec = assert(Config.Get(id))
	local theme = Themes[floorSpec.BiomeId] or Themes.verdant_ruins
	local origin = Builder.Origin(id)
	local idx = floorSpec.IndexInBiome
	local layout = Layout.Get(idx, id)
	local safe = layout.Sanctuary

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

	local width, depth, height = layout.Width, layout.Depth, layout.Height
	model:SetAttribute("Width", width)
	model:SetAttribute("Depth", depth)
	model:SetAttribute("Height", height)
	model:SetAttribute("CampCount", #layout.Camps)
	-- Natural floors (GDD §3.3): with the Tower Biome Kit imported, every floor gets its own voxel terrain
	-- (TowerTerrain) and an ecosystem of kit props; terraces and ramps lose their masonry trim, curbs and
	-- viaduct piers, since the terrain's plateaus and land bridges carry them.
	local natural = KitProps.Ready()
	model:SetAttribute("Natural", natural)

	-- Base sub-floor and sky/cavern enclosure
	local ground = part(model, "Ground", Vector3.new(width, 4, depth), origin + Vector3.new(0, layout.Bottom - 6, 0), theme.SubFloorColor, theme.GroundMaterial)
	if natural then
		-- The terrain is the visible chasm floor; the slab stays as the catch under it.
		ground.Transparency = 1
	end
	for _, side in { -1, 1 } do
		part(model, "WallX", Vector3.new(6, height + 16, depth + 12), origin + Vector3.new(side * (width / 2 + 3), height / 2 - 8, 0), theme.WallColor, theme.WallMaterial)
		part(model, "WallZ", Vector3.new(width, height + 16, 6), origin + Vector3.new(0, height / 2 - 8, side * (depth / 2 + 3)), theme.WallColor, theme.WallMaterial)
	end
	local isDirectTerrainLayout = function(l: any): boolean
		return l.DirectTerrain == true
	end
	local function isArchitecturalDeck(l: any, platformName: string?): boolean
		local map = l.Decks
		return map ~= nil and platformName ~= nil and map[platformName] == true
	end
	local function isSuspendedLink(l: any, linkId: string): boolean
		local map = l.Suspended and l.Suspended.Links
		return map ~= nil and map[linkId] == true
	end
	local function disableTerrainProxyPart(p: BasePart)
		p.Transparency = 1
		p.CastShadow = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
	end

	-- Vaulted ceiling with natural environmental skylight aperture (allows sunlight & sunrays to enter)
	local skyFraction = if isDirectTerrainLayout(layout) then 0.82 else 0.54
	local openW = width * skyFraction
	local openD = depth * skyFraction
	local borderX = (width - openW) / 2
	local borderZ = (depth - openD) / 2

	for _, sz in { -1, 1 } do
		local ceilZ = decor(model, "VaultCeilingZ", Vector3.new(width + 12, 6, borderZ + 8), origin + Vector3.new(0, height + 3, sz * (depth / 2 - borderZ / 2)), theme.WallColor, theme.WallMaterial)
		ceilZ.CastShadow = false
	end
	for _, sx in { -1, 1 } do
		local ceilX = decor(model, "VaultCeilingX", Vector3.new(borderX + 8, 5.7, openD), origin + Vector3.new(sx * (width / 2 - borderX / 2), height + 3.05, 0), theme.WallColor, theme.WallMaterial)
		ceilX.CastShadow = false
	end
	for _, sz in { -1, 1 } do
		decor(model, "SkylightRimZ", Vector3.new(openW + 12, 3.5, 4), origin + Vector3.new(0, height + 1, sz * (openD / 2)), theme.TrimColor, theme.TrimMaterial)
	end
	for _, sx in { -1, 1 } do
		decor(model, "SkylightRimX", Vector3.new(4, 3.3, openD + 12), origin + Vector3.new(sx * (openW / 2), height + 1.15, 0), theme.TrimColor, theme.TrimMaterial)
	end

	-- High-altitude natural skylight light source (casts soft sunlight/skylight down across the room)
	local sunShaft = Instance.new("Part")
	sunShaft.Name = "NaturalSkylightShaft"
	sunShaft.Size = Vector3.new(openW * 0.7, 2, openD * 0.7)
	sunShaft.Position = origin + Vector3.new(0, height + 8, -depth * 0.05)
	sunShaft.Anchored = true
	sunShaft.CanCollide = false
	sunShaft.CanQuery = false
	sunShaft.CanTouch = false
	sunShaft.Transparency = 1
	sunShaft.Parent = model

	local naturalSpot = Instance.new("SpotLight")
	naturalSpot.Name = "NaturalSkylightSpot"
	naturalSpot.Face = Enum.NormalId.Bottom
	naturalSpot.Angle = 82
	naturalSpot.Range = height + 45
	naturalSpot.Brightness = 1.4
	naturalSpot.Color = theme.LightColor:Lerp(Color3.fromRGB(255, 245, 225), 0.45)
	naturalSpot.Shadows = false
	naturalSpot.Parent = sunShaft

	local isNatural = floorSpec.BiomeId == "verdant_ruins"
		or floorSpec.BiomeId == "fungal_hollow"
		or floorSpec.BiomeId == "ashen_dunes"
		or floorSpec.BiomeId == "thunder_highlands"
		or floorSpec.BiomeId == "corrupted_grove"

	local groundPalette = TowerTerrain.Palettes[floorSpec.BiomeId]
	local naturalGrassColor = if natural and floorSpec.BiomeId == "verdant_ruins"
		then Color3.fromRGB(68, 118, 52)
		elseif natural and groundPalette and TowerTerrain.MaterialColors[groundPalette.Ground]
		then TowerTerrain.MaterialColors[groundPalette.Ground]
		else theme.GroundColor
	local solmereLimestone = Color3.fromRGB(186, 180, 158)
	local flagstone = Color3.fromRGB(176, 170, 148)
	local flagstoneDark = Color3.fromRGB(138, 134, 114)
	local varrashSandstone = Color3.fromRGB(186, 156, 114)
	local varrashBasalt = Color3.fromRGB(78, 72, 74)
	local moss = Color3.fromRGB(86, 132, 58)
	local stumpWoodColor = Color3.fromRGB(134, 96, 58)
	local rootBarkColor = Color3.fromRGB(88, 66, 46)
	local rootBarkDark = Color3.fromRGB(64, 48, 34)
	local rootSapColor = Color3.fromRGB(150, 235, 120)
	local obsidianDark = Color3.fromRGB(26, 22, 28)
	local obsidianStairA = Color3.fromRGB(24, 20, 26)
	local obsidianStairB = Color3.fromRGB(34, 28, 36)
	local amberGlassCol = Color3.fromRGB(238, 142, 42)
	local amberInlayCol = Color3.fromRGB(218, 128, 36)
	local glacierIceCol = Color3.fromRGB(152, 206, 234)
	local glacierSnowCol = Color3.fromRGB(228, 238, 248)
	local glacierDeepCol = Color3.fromRGB(102, 162, 198)
	local whiteguardGranite = Color3.fromRGB(116, 128, 142)
	local whiteguardGraniteDark = Color3.fromRGB(86, 98, 112)
	local whiteguardIron = Color3.fromRGB(54, 62, 74)

	local MASONRY_STYLES: { [string]: { [string]: any } } = {
		ORGANIC = {
			DeckKind = "ORGANIC",
			LandingProxy = true,
			BridgeKind = "ORGANIC_ROOT",
			RootStair = true,
		},
		FORTRESS = {
			DeckKind = "FORTRESS",
			LandingColor = solmereLimestone,
			LandingMaterial = Enum.Material.Limestone,
			LandingStacked = true,
			LandingStoneUnderside = true,
			RampYOffset = -0.99,
			BridgeKind = "SOLMERE_ARCH",
		},
		VARRASH_DECK = {
			DeckKind = "VARRASH_DECK",
			LandingColor = varrashSandstone,
			LandingMaterial = Enum.Material.Sandstone,
			LandingStacked = true,
		},
		VARRASH_GLASS = {
			DeckKind = "VARRASH_GLASS",
			LandingColor = Color3.fromRGB(28, 24, 30),
			LandingMaterial = Enum.Material.Slate,
			LandingStacked = true,
			BridgeKind = "OBSIDIAN_GLASS",
			StairColorA = obsidianStairA,
			StairColorB = obsidianStairB,
			StairMatA = Enum.Material.Glass,
			StairMatB = Enum.Material.Basalt,
			StairAmberInlay = amberInlayCol,
			StairUnder = true,
			StairUnderHeight = 2.2,
			StairUnderY = -2.1,
			StairUnderVeins = true,
			CurbColor = Color3.fromRGB(32, 26, 34),
			CurbMaterial = Enum.Material.Slate,
			CurbCapColor = Color3.fromRGB(236, 138, 40),
			CurbCapMaterial = Enum.Material.Glass,
			CurbCapTransparency = 0.25,
		},
		VARRASH_FORTRESS = {
			DeckKind = "VARRASH_FORTRESS",
			LandingProxy = true,
			BridgeKind = "FORTRESS_CAUSEWAY",
			CurbColor = varrashSandstone,
			CurbMaterial = Enum.Material.Sandstone,
			CurbMode = "FORTRESS_MERLON",
		},
		VARRASH_DAIS = {
			DeckKind = "VARRASH_DAIS",
			LandingProxy = true,
			BridgeKind = "FORTRESS_CAUSEWAY",
			StairUnder = true,
			StairUnderHeight = 3.2,
			StairUnderY = -2.6,
			CurbColor = varrashSandstone,
			CurbMaterial = Enum.Material.Sandstone,
			CurbMode = "FORTRESS_MERLON",
		},
		GLACIER_SLAB = {
			DeckKind = "GLACIER_SLAB",
			LandingProxy = true,
			BridgeKind = "GLACIER_SLAB",
			CurbColor = whiteguardGranite,
			CurbMaterial = Enum.Material.Slate,
			CurbMode = "WHITEGUARD_BRIDGE",
		},
	}

	local PATH_STYLES: { [string]: { [string]: any } } = {
		SOLMERE = {
			VisibleCurb = true,
			CurbColor = flagstoneDark,
			CurbMaterial = Enum.Material.Limestone,
			CurbCapColor = moss,
			CurbCapMaterial = Enum.Material.Grass,
			LandingColor = solmereLimestone,
			LandingMaterial = Enum.Material.Limestone,
			StairColorA = flagstone,
			StairColorB = flagstoneDark,
			StairMatA = Enum.Material.Limestone,
			StairMatB = Enum.Material.Limestone,
			GrassStepLipColorA = flagstoneDark,
			GrassStepLipColorB = flagstoneDark,
			GrassStepLipMatA = Enum.Material.Limestone,
			GrassStepLipMatB = Enum.Material.Limestone,
			GrassStepLipWBase = 0.26,
			GrassStepLipWStep = 0.04,
			GrassStepLipWMod = 7,
			GrassStepLipH = 0.45,
			GrassStepLipY = 0.06,
			SolidCauseway = true,
			ShowVaultLanterns = true,
		},
		VARRASH = {
			VisibleCurb = true,
			CurbColor = varrashSandstone,
			CurbMaterial = Enum.Material.Sandstone,
			CurbCapColor = Color3.fromRGB(175, 95, 65),
			CurbCapMaterial = Enum.Material.Sand,
			LandingColor = varrashSandstone,
			LandingMaterial = Enum.Material.Sandstone,
			StairColorA = varrashSandstone,
			StairColorB = varrashBasalt,
			StairMatA = Enum.Material.Sandstone,
			StairMatB = Enum.Material.Slate,
			GrassStepLipColorA = Color3.fromRGB(134, 118, 96),
			GrassStepLipColorB = varrashSandstone,
			GrassStepLipMatA = Enum.Material.Slate,
			GrassStepLipMatB = Enum.Material.Sandstone,
			GrassStepLipWBase = 0.34,
			GrassStepLipWStep = 0.05,
			GrassStepLipWMod = 5,
			GrassStepLipH = 0.28,
			GrassStepLipY = 0.02,
			SolidRampColor = varrashSandstone,
			SolidRampMat = Enum.Material.Sandstone,
			SolidLipColorA = varrashBasalt,
			SolidLipColorB = varrashSandstone,
			SolidLipMatA = Enum.Material.Slate,
			SolidLipMatB = Enum.Material.Sandstone,
			SolidLipStep = 3.4,
			AllowRootStair = false,
			ShowVaultLanterns = false,
		},
		WHITEGUARD = {
			VisibleCurb = true,
			CurbColor = whiteguardGranite,
			CurbMaterial = Enum.Material.Slate,
			CurbCapColor = whiteguardIron,
			CurbCapMaterial = Enum.Material.Metal,
			LandingColor = whiteguardGranite,
			LandingMaterial = Enum.Material.Slate,
			StairColorA = whiteguardGranite,
			StairColorB = Color3.fromRGB(168, 212, 238),
			StairMatA = Enum.Material.Slate,
			StairMatB = Enum.Material.Ice,
			GrassStepLipColorA = whiteguardGranite,
			GrassStepLipColorB = whiteguardGraniteDark,
			GrassStepLipMatA = Enum.Material.Slate,
			GrassStepLipMatB = Enum.Material.Granite,
			GrassStepLipWBase = 0.34,
			GrassStepLipWStep = 0.05,
			GrassStepLipWMod = 5,
			GrassStepLipH = 0.24,
			GrassStepLipY = 0.02,
			SolidRampColor = whiteguardGranite,
			SolidRampMat = Enum.Material.Slate,
			SolidLipColorA = whiteguardGraniteDark,
			SolidLipColorB = glacierSnowCol,
			SolidLipMatA = Enum.Material.Granite,
			SolidLipMatB = Enum.Material.Snow,
			SolidLipStep = 3.4,
			AllowRootStair = false,
			ShowVaultLanterns = false,
		},
	}

	local masonryStyle = if layout.Masonry then MASONRY_STYLES[layout.Masonry] else nil
	local pathStyle = if natural and layout.PathStyle then PATH_STYLES[layout.PathStyle] else nil

	local function rootCylinder(name: string, p0: Vector3, p1: Vector3, diameter: number, col: Color3, mat: Enum.Material?, solid: boolean?)
		local d = p1 - p0
		local len = math.max(0.1, d.Magnitude)
		local midPt = (p0 + p1) / 2
		local p = if solid
			then part(model, name, Vector3.new(len + diameter * 0.45, diameter, diameter), midPt, col, mat or Enum.Material.Wood, true)
			else decor(model, name, Vector3.new(len + diameter * 0.45, diameter, diameter), midPt, col, mat or Enum.Material.Wood)
		if solid then
			p.CanQuery = true
			p.CanTouch = false
		end
		p.Shape = Enum.PartType.Cylinder
		p.CFrame = CFrame.lookAt(midPt, p1) * CFrame.Angles(0, math.pi / 2, 0)
		return p
	end

	local function flatDisc(name: string, pos: Vector3, diameter: number, thickness: number, col: Color3, mat: Enum.Material, solid: boolean?)
		local p = if solid
			then part(model, name, Vector3.new(thickness, diameter, diameter), pos, col, mat, true)
			else decor(model, name, Vector3.new(thickness, diameter, diameter), pos, col, mat)
		if solid then
			p.CanQuery = true
			p.CanTouch = false
		end
		p.Shape = Enum.PartType.Cylinder
		p.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)
		return p
	end

	for name, terrace in layout.Platforms do
		local thickness = terrace.Y - layout.Bottom + 4
		local slab = part(
			model,
			if name == "Sanctuary" then "SafeArrival" else name,
			Vector3.new(terrace.Width, thickness, terrace.Depth),
			origin + Vector3.new(terrace.X, terrace.Y - thickness / 2, terrace.Z),
			theme.GroundColor,
			theme.GroundMaterial
		)
		slab:SetAttribute("SurfaceY", terrace.Y)
		slab:SetAttribute("TerraceId", name)

		local topCenter = origin + Vector3.new(terrace.X, terrace.Y, terrace.Z)
		if natural then
			-- A natural plateau (including the Sanctuary spawn glade): matches the biome's Terrain ground;
			-- architectural bridge/viaduct decks keep collision on slab while Floor 3 pads dress as organic root/stump forms.
			local deckKind = masonryStyle and masonryStyle.DeckKind
			if isArchitecturalDeck(layout, name) then
				if deckKind == "ORGANIC" then
					slab.Size = Vector3.new(terrace.Width, 2.6, terrace.Depth)
					slab.Position = origin + Vector3.new(terrace.X, terrace.Y - 1.3, terrace.Z)
					disableTerrainProxyPart(slab)
					slab.CanCollide = true
					slab.CanQuery = true

					local deepBottom = origin.Y + layout.Bottom - 7 -- -11 local (embedded below -7.6 riverbed)
					if name == "EastGallery" then
						-- Hollow Stump: SOLID round tree trunk wall descending below riverbed so nothing phases through
						local stumpH = (origin.Y + terrace.Y) - deepBottom
						local stumpDia = math.min(terrace.Width, terrace.Depth) + 6
						flatDisc("HollowStumpTrunk", Vector3.new(topCenter.X, topCenter.Y - stumpH / 2 - 0.04, topCenter.Z), stumpDia, stumpH, rootBarkColor, Enum.Material.Wood, true)
						for rIdx, ringW in { 0.86, 0.64, 0.42, 0.22 } do
							flatDisc(
								"StumpGrowthRing",
								topCenter + Vector3.new(0, 0.01 + rIdx * 0.035, 0),
								stumpDia * ringW,
								0.10,
								if rIdx % 2 == 0 then stumpWoodColor:Lerp(Color3.new(1, 1, 1), 0.14) else rootBarkDark:Lerp(stumpWoodColor, 0.55),
								Enum.Material.Wood
							)
						end
						-- Solid flared bark buttress ribs anchored deep inside the trunk wall all the way into the riverbed
						for k = 0, 9 do
							local ang = k * (math.pi * 2 / 10) + 0.2
							local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
							local knee = Vector3.new(topCenter.X + dir.X * (stumpDia * 0.46), topCenter.Y - stumpH * 0.48, topCenter.Z + dir.Z * (stumpDia * 0.46))
							local topAnchor = Vector3.new(topCenter.X + dir.X * (stumpDia * 0.34), topCenter.Y - 1.5, topCenter.Z + dir.Z * (stumpDia * 0.34))
							local footAnchor = Vector3.new(topCenter.X + dir.X * (stumpDia * 0.62), deepBottom, topCenter.Z + dir.Z * (stumpDia * 0.62))
							local ribCol = if k % 2 == 0 then rootBarkColor else rootBarkDark
							rootCylinder("StumpBarkRib", topAnchor, knee, 9.0 + (k % 3) * 1.4, ribCol, Enum.Material.Wood, true)
							rootCylinder("StumpBarkRib", knee, footAnchor, 8.2 + (k % 3) * 1.2, ribCol, Enum.Material.Wood, true)
							if k % 2 == 0 then
								flatDisc("StumpMossTuft", topCenter + dir * (stumpDia * 0.41) - Vector3.new(0, 0.25, 0), 10 + (k % 3) * 2, 1.0, moss, Enum.Material.LeafyGrass)
							end
						end
					else
						-- The Knot & Root Perch: SOLID rounded mossy stone/root island core + overlapping scalloped lobes
						local coreDia = math.min(terrace.Width, terrace.Depth) * 0.98
						if name == "WestGallery" then
							-- Root Perch sits atop a solid gorge cliff/root pedestal down to the riverbed (no phasing underneath)
							local perchH = (origin.Y + terrace.Y) - deepBottom
							flatDisc("RootIslandCore", Vector3.new(topCenter.X, topCenter.Y - perchH / 2 - 0.04, topCenter.Z), coreDia * 0.96, perchH, theme.CliffColor, theme.CliffMaterial, true)
						else
							flatDisc("RootIslandCore", topCenter - Vector3.new(0, 2.2, 0), coreDia, 4.3, flagstoneDark, Enum.Material.Limestone, true)
						end
						local lobes = 8
						for k = 0, lobes - 1 do
							local ang = k * (math.pi * 2 / lobes) + (terrace.X * 0.03)
							local rx = math.cos(ang) * (terrace.Width * 0.34)
							local rz = math.sin(ang) * (terrace.Depth * 0.32)
							local lobeDia = 24 + ((k * 7) % 9)
							local lobePos = topCenter + Vector3.new(rx, -1.68 - (k % 4) * 0.14, rz)
							flatDisc("RootIslandLobe", lobePos, lobeDia, 3.0, if k % 2 == 0 then moss else solmereLimestone, if k % 2 == 0 then Enum.Material.LeafyGrass else Enum.Material.Limestone, true)
							-- Curved braided Heartroot rim ribs gripping the lobe edges & anchored directly into the solid core
							local nextAng = (k + 1) * (math.pi * 2 / lobes) + (terrace.X * 0.03)
							local p0 = topCenter + Vector3.new(math.cos(ang) * (terrace.Width * 0.42), -1.1, math.sin(ang) * (terrace.Depth * 0.40))
							local p1 = topCenter + Vector3.new(math.cos(nextAng) * (terrace.Width * 0.42), -1.1, math.sin(nextAng) * (terrace.Depth * 0.40))
							rootCylinder("RootIslandRimCable", p0, p1, 3.6 + (k % 2) * 0.8, if k % 2 == 0 then rootBarkColor else rootBarkDark, Enum.Material.Wood)
							-- Articulated support roots growing directly out of the solid core down into the riverbed
							local topRoot = topCenter + Vector3.new(rx * 0.72, -1.5, rz * 0.72)
							local midRoot = Vector3.new(topCenter.X + rx * 1.15, origin.Y + (terrace.Y + layout.Bottom) * 0.45, topCenter.Z + rz * 1.15)
							local botRoot = Vector3.new(topCenter.X + rx * 1.48, deepBottom, topCenter.Z + rz * 1.48)
							rootCylinder("RootIslandUnderRib", topRoot, midRoot, 4.4, rootBarkColor, Enum.Material.Wood, true)
							rootCylinder("RootIslandUnderRib", midRoot, botRoot, 5.0, rootBarkDark, Enum.Material.Wood, true)
							if k % 2 == 0 then
								rootCylinder("KnotUnderSapVein", midRoot, topRoot - Vector3.new(0, 0.5, 0), 0.65, rootSapColor, Enum.Material.Neon)
							end
						end
						-- Scatter flat irregular stone pavers staggered vertically across the island top (no coplanar shimmer)
						for k = 1, 7 do
							local ang = k * 2.35
							local rad = 8 + (k * 5) % 18
							local pPos = topCenter + Vector3.new(math.cos(ang) * rad, 0.04 + k * 0.035, math.sin(ang) * rad)
							local paver = decor(model, "RootIslandFlagstone", Vector3.new(8 + (k % 3) * 2.5, 0.14, 6.5 + ((k + 1) % 3) * 2), pPos, if k % 2 == 0 then flagstone else flagstoneDark, Enum.Material.Limestone)
							paver.CFrame = CFrame.new(pPos) * CFrame.Angles(0, ang * 0.7, 0)
						end
					end
				elseif deckKind == "FORTRESS" then
					-- Floors 4-5 limestone terraces: solid weathered masonry plinth down into moat/cenote bed
					-- dressed with irregular flagstone inlays, verdigris belt & moss cushions (plus sun-disc medallions on F5).
					local deepBottom = origin.Y + layout.Bottom - 7
					local wallH = (origin.Y + terrace.Y) - deepBottom
					slab.Size = Vector3.new(terrace.Width, wallH, terrace.Depth)
					slab.Position = Vector3.new(topCenter.X, topCenter.Y - wallH / 2, topCenter.Z)
					slab.Color = solmereLimestone
					slab.Material = Enum.Material.Limestone
					-- Verdigris ashlar collar (X strips trimmed cleanly inside Z strips so corners never z-fight)
					for _, sz in { -1, 1 } do
						decor(model, "BastionVerdigrisTrim", Vector3.new(terrace.Width + 1.3, 1.4, 1.25), topCenter + Vector3.new(0, -1.8, sz * (terrace.Depth / 2 + 0.05)), theme.AccentColor, Enum.Material.Slate)
					end
					for _, sx in { -1, 1 } do
						decor(model, "BastionVerdigrisTrim", Vector3.new(1.25, 1.4, math.max(1, terrace.Depth - 1.3)), topCenter + Vector3.new(sx * (terrace.Width / 2 + 0.05), -1.8, 0), theme.AccentColor, Enum.Material.Slate)
						for _, sz in { -1, 1 } do
							local cp = Vector3.new(topCenter.X + sx * (terrace.Width / 2 - 2.3), topCenter.Y - wallH / 2 - 0.16, topCenter.Z + sz * (terrace.Depth / 2 - 2.3))
							local cornerPier = part(model, "BastionCornerPier", Vector3.new(6.4, wallH - 0.16, 6.4), cp, flagstoneDark, Enum.Material.Limestone, true)
							cornerPier.CanQuery = true
							cornerPier.CanTouch = false
						end
					end
					if layout.SunMedallions then
						-- Carved Solmere sun-disc medallions inset cleanly above TraversalLanding layers (top +0.16 / +0.22 / +0.28)
						local sunDia = math.min(terrace.Width, terrace.Depth) * (if name == "Apex" then 0.40 else 0.32)
						flatDisc("CenoteSunMedallion", topCenter + Vector3.new(0, 0.14, 0), sunDia, 0.10, Color3.fromRGB(204, 166, 82), Enum.Material.Cobblestone)
						flatDisc("CenoteSunInlay", topCenter + Vector3.new(0, 0.20, 0), sunDia * 0.72, 0.10, theme.AccentColor, Enum.Material.Slate)
						flatDisc("CenoteSunCore", topCenter + Vector3.new(0, 0.26, 0), sunDia * 0.24, 0.10, rootSapColor, Enum.Material.Neon)
					end
					-- Scattered weathered flagstones & moss edge beds spaced out cleanly around the medallion and above landings
					for k = 1, 6 do
						local ang = k * 2.1 + terrace.X * 0.02
						local rx = math.cos(ang) * (terrace.Width * 0.33)
						local rz = math.sin(ang) * (terrace.Depth * 0.31)
						local pPos = topCenter + Vector3.new(rx, 0.16 + k * 0.04, rz)
						local paver = decor(model, "BastionFlagstone", Vector3.new(8 + (k % 3) * 2.4, 0.10, 6.5 + ((k + 1) % 3) * 1.6), pPos, if k % 2 == 0 then flagstone else flagstoneDark, Enum.Material.Limestone)
						paver.CFrame = CFrame.new(pPos) * CFrame.Angles(0, math.rad((k * 19) % 24 - 12), 0)
						if k % 2 == 1 then
							local mPos = topCenter + Vector3.new(rx * 1.18, 0.24 + k * 0.04, rz * 1.18)
							decor(model, "BastionMossPatch", Vector3.new(8.5, 0.10, 6.8), mPos, moss, Enum.Material.LeafyGrass)
						end
					end
				elseif deckKind == "VARRASH_DECK" then
					-- Buried Caravanserai inn roof: solid sandstone deck projecting out of the desert slope with flush skylight grilles.
					local deepBottom = origin.Y + layout.Bottom - 7
					local wallH = (origin.Y + terrace.Y) - deepBottom
					slab.Size = Vector3.new(terrace.Width, wallH, terrace.Depth)
					slab.Position = Vector3.new(topCenter.X, topCenter.Y - wallH / 2, topCenter.Z)
					slab.Color = varrashSandstone
					slab.Material = Enum.Material.Sandstone
					for _, sz in { -1, 1 } do
						decor(model, "CaravanseraiCorniceZ", Vector3.new(terrace.Width + 2.4, 2.2, 2.0), topCenter + Vector3.new(0, -1.28, sz * (terrace.Depth / 2 + 0.35)), Color3.fromRGB(168, 138, 102), Enum.Material.Sandstone)
						for px = -1, 1 do
							decor(model, "CaravanseraiButtress", Vector3.new(3.6, wallH - 2.4, 2.8), origin + Vector3.new(terrace.X + px * (terrace.Width * 0.32), topCenter.Y - wallH / 2 - 1.2, terrace.Z + sz * (terrace.Depth / 2 + 0.4)), Color3.fromRGB(132, 114, 92), Enum.Material.Slate)
						end
					end
					for _, sx in { -1, 1 } do
						decor(model, "CaravanseraiCorniceX", Vector3.new(2.0, 2.2, math.max(1, terrace.Depth - 2.4)), topCenter + Vector3.new(sx * (terrace.Width / 2 + 0.35), -1.34, 0), Color3.fromRGB(168, 138, 102), Enum.Material.Sandstone)
					end
					if name == "Crossing" then
						-- Two bronze-and-sandstone roof skylight grates set flush atop Caravanserai Roof (non-colliding inlay above Slab).
						local resolveSkylight = KitProps.Resolver(floorSpec.BiomeId, theme)
						for sIdx, sxOff in { -15, 15 } do
							local skyPos = topCenter + Vector3.new(sxOff, 0.04, -2)
							if KitProps.Has("CaravanseraiSkylight") then
								KitProps.Place(model, "CaravanseraiSkylight", CFrame.new(skyPos) * CFrame.new(0, -1.22, 0), Vector3.one * 0.92, resolveSkylight, {
									TRIM = { Color = varrashSandstone, Material = Enum.Material.Sandstone },
									METAL = { Color = Color3.fromRGB(64, 54, 48), Material = Enum.Material.Metal },
									STONE = { Color = Color3.fromRGB(36, 30, 32), Material = Enum.Material.Basalt },
									GLOW = { Color = Color3.fromRGB(255, 155, 65), Material = Enum.Material.Neon },
								})
							else
								decor(model, "CaravanseraiSkylightRim" .. sIdx, Vector3.new(11.0, 0.14, 11.0), skyPos + Vector3.new(0, 0.04, 0), varrashSandstone, Enum.Material.Sandstone)
								decor(model, "CaravanseraiSkylightWell" .. sIdx, Vector3.new(8.2, 0.14, 8.2), skyPos + Vector3.new(0, 0.10, 0), Color3.fromRGB(48, 36, 30), Enum.Material.Basalt)
								for g = -2, 2 do
									decor(model, "CaravanseraiSkylightBar", Vector3.new(0.28, 0.12, 8.4), skyPos + Vector3.new(g * 1.5, 0.18, 0), Color3.fromRGB(64, 54, 48), Enum.Material.Metal)
									decor(model, "CaravanseraiSkylightBarX", Vector3.new(8.4, 0.12, 0.28), skyPos + Vector3.new(0, 0.22, g * 1.5), Color3.fromRGB(64, 54, 48), Enum.Material.Metal)
								end
							end
						end
					end
				elseif deckKind == "VARRASH_GLASS" then
					-- Suspended fused obsidian & amber-glass span deck (open ravine chasm visible underneath).
					local obsidian = Color3.fromRGB(26, 22, 28)
					local obsidianEdge = Color3.fromRGB(40, 34, 42)
					local amberGlass = Color3.fromRGB(242, 146, 44)
					local amberCore = Color3.fromRGB(218, 124, 34)
					slab.Size = Vector3.new(terrace.Width, 3.0, terrace.Depth)
					slab.Position = Vector3.new(topCenter.X, topCenter.Y - 1.5, topCenter.Z)
					slab.Color = obsidian
					slab.Material = Enum.Material.Slate
					decor(model, "GlassArchKeel", Vector3.new(terrace.Width - 6, 2.2, math.max(8, terrace.Depth * 0.52)), topCenter + Vector3.new(0, -4.1, 0), obsidianEdge, Enum.Material.Basalt)
					for _, sz in { -1, 1 } do
						decor(model, "GlassArchAmberVeinZ", Vector3.new(terrace.Width - 2, 1.1, 1.2), topCenter + Vector3.new(0, -2.2, sz * (terrace.Depth / 2 - 0.1)), amberGlass, Enum.Material.Glass, 0.22)
						decor(model, "GlassArchGlowSeamZ", Vector3.new(terrace.Width - 10, 0.45, 0.45), topCenter + Vector3.new(0, -3.5, sz * (terrace.Depth * 0.24)), amberCore, Enum.Material.Neon)
					end
					for _, sx in { -1, 1 } do
						decor(model, "GlassArchAmberVeinX", Vector3.new(1.2, 1.1, math.max(1, terrace.Depth - 3.0)), topCenter + Vector3.new(sx * (terrace.Width / 2 - 0.1), -2.2, 0), amberGlass, Enum.Material.Glass, 0.22)
					end
					-- Surface vitrified amber-glass fissure inlays across Crossing deck (staggered well above slab/landings at +0.16)
					for gIdx = -1, 1, 2 do
						decor(model, "GlassDeckInlay", Vector3.new(terrace.Width * 0.68, 0.10, 1.1), topCenter + Vector3.new(0, 0.16, gIdx * 10), amberGlass, Enum.Material.Glass, 0.2)
					end
				elseif deckKind == "VARRASH_FORTRESS" then
					-- Sunscar Fortress (Floor 14): Crossing & Apex bridge the central Sunscar lava fissure atop flanking
					-- basalt cliff piers, with natural rock bolsters & weathered sandstone outcrops softening their rims.
					local deepBottom = origin.Y + layout.Bottom - 7
					local wallH = (origin.Y + terrace.Y) - deepBottom
					local fortBasalt = Color3.fromRGB(48, 42, 46)
					local sandStoneDark = Color3.fromRGB(154, 128, 96)
					local deckThick = 3.2
					if name == "Apex" then
						-- Leave a central 22x22 viewport cut out of the sandstone floor, bridged by solid dark glass over the Ember Vein tap.
						slab.Transparency = 1
						slab.Size = Vector3.new(terrace.Width, deckThick, terrace.Depth)
						slab.Position = Vector3.new(topCenter.X, topCenter.Y - deckThick / 2, topCenter.Z)
						local win = 22
						local sideW = (terrace.Width - win) * 0.5
						local wingZ = (terrace.Depth - win) * 0.5
						for _, sx in { -1, 1 } do
							decor(model, "VarrashThroneDeckSide", Vector3.new(sideW, deckThick, terrace.Depth), topCenter + Vector3.new(sx * (win * 0.5 + sideW * 0.5), -deckThick / 2, 0), varrashSandstone, Enum.Material.Sandstone)
						end
						for _, sz in { -1, 1 } do
							decor(model, "VarrashThroneDeckSpan", Vector3.new(win, deckThick, wingZ), topCenter + Vector3.new(0, -deckThick / 2, sz * (win * 0.5 + wingZ * 0.5)), varrashSandstone, Enum.Material.Sandstone)
						end
						local glassWell = decor(model, "SunscarThroneGlassFloor", Vector3.new(win, 0.45, win), topCenter + Vector3.new(0, -0.25, 0), Color3.fromRGB(218, 128, 42), Enum.Material.Glass, 0.35)
						glassWell.CanCollide = false
						-- Vein tap core glowing beneath the glass floor well inside the basalt vault arch
						decor(model, "EmberVeinTapCore", Vector3.new(10, 1.4, 10), topCenter + Vector3.new(0, -3.2, 0), Color3.fromRGB(255, 118, 32), Enum.Material.Neon)
						decor(model, "EmberVeinTapFrame", Vector3.new(win + 2.0, 0.3, 1.4), topCenter + Vector3.new(0, -0.02, win / 2 + 0.5), fortBasalt, Enum.Material.Basalt)
						decor(model, "EmberVeinTapFrame", Vector3.new(win + 2.0, 0.3, 1.4), topCenter + Vector3.new(0, -0.02, -(win / 2 + 0.5)), fortBasalt, Enum.Material.Basalt)
					else
						slab.Size = Vector3.new(terrace.Width, deckThick, terrace.Depth)
						slab.Position = Vector3.new(topCenter.X, topCenter.Y - deckThick / 2, topCenter.Z)
						slab.Color = varrashSandstone
						slab.Material = Enum.Material.Sandstone
					end
					-- Flanking basalt vault piers outside the central X = [-22..+22] Sunscar fissure
					local pierXOff = if name == "Apex" then 40 else 27
					local pierW = if name == "Apex" then 24 else 18
					for _, sx in { -1, 1 } do
						local cp = Vector3.new(topCenter.X + sx * pierXOff, topCenter.Y - wallH / 2 - 0.16, topCenter.Z)
						local pier = part(model, "SunscarVaultPier", Vector3.new(pierW, wallH - 0.16, terrace.Depth - 4), cp, fortBasalt, Enum.Material.Basalt, true)
						pier.CanQuery = true
						pier.CanTouch = false
					end
					-- Organic battered basalt rock outcrops hugging corners so bridge decks read as cliff-carved masonry
					for _, sx in { -1, 1 } do
						for _, sz in { -1, 1 } do
							local outPos = Vector3.new(topCenter.X + sx * (terrace.Width * 0.48), topCenter.Y - wallH * 0.48 - 1.2, topCenter.Z + sz * (terrace.Depth * 0.44))
							local boulder = decor(model, "BastionCliffOutcrop", Vector3.new(12, wallH * 0.92, 13), outPos, fortBasalt, Enum.Material.Basalt)
							boulder.CFrame = CFrame.new(outPos) * CFrame.Angles(math.rad(sx * 4), math.rad((sx * 17 + sz * 23)), math.rad(sz * 4))
							local capPos = topCenter + Vector3.new(sx * (terrace.Width * 0.46), -0.45, sz * (terrace.Depth * 0.45))
							local capStone = decor(model, "BastionRimStone", Vector3.new(11, 2.2, 11), capPos, sandStoneDark, Enum.Material.Sandstone)
							capStone.CFrame = CFrame.new(capPos) * CFrame.Angles(0, math.rad(sx * 22 + sz * 15), 0)
						end
					end
					for k = 1, 7 do
						local ang = k * 1.9 + terrace.X * 0.02
						local rx = math.cos(ang) * (terrace.Width * 0.34)
						local rz = math.sin(ang) * (terrace.Depth * 0.32)
						local pPos = topCenter + Vector3.new(rx, 0.16 + k * 0.03, rz)
						local paver = decor(model, "VarrashFortressFlagstone", Vector3.new(8.5 + (k % 3) * 2.2, 0.10, 6.5 + ((k + 1) % 3) * 1.6), pPos, if k % 2 == 0 then varrashSandstone else sandStoneDark, Enum.Material.Sandstone)
						paver.CFrame = CFrame.new(pPos) * CFrame.Angles(0, math.rad((k * 19) % 24 - 12), 0)
					end
				elseif deckKind == "VARRASH_DAIS" then
					-- Colossus Dais (Floor 15): Crossing = Elder's Chest over lava lake (with open circular heart-cage well),
					-- Apex = 140x110 stepped sandstone Boss Dais ringed by battered basalt cliff bolsters & hexagonal basalt columns.
					local deepBottom = origin.Y + layout.Bottom - 7
					local wallH = (origin.Y + terrace.Y) - deepBottom
					local fortBasalt = Color3.fromRGB(44, 38, 42)
					local sandStoneDark = Color3.fromRGB(152, 126, 94)
					local deckThick = 3.2
					slab.Size = Vector3.new(terrace.Width, deckThick, terrace.Depth)
					slab.Position = Vector3.new(topCenter.X, topCenter.Y - deckThick / 2, topCenter.Z)
					if name == "Crossing" then
						-- Elder's Chest plate with central sunken heart-cage cavity glowing over the caldera lava
						slab.Transparency = 1
						local well = 18
						local sideW = (terrace.Width - well) * 0.5
						local wingZ = (terrace.Depth - well) * 0.5
						for _, sx in { -1, 1 } do
							decor(model, "ElderChestDeckSide", Vector3.new(sideW, deckThick, terrace.Depth), topCenter + Vector3.new(sx * (well * 0.5 + sideW * 0.5), -deckThick / 2, 0), varrashSandstone, Enum.Material.Sandstone)
						end
						for _, sz in { -1, 1 } do
							decor(model, "ElderChestDeckSpan", Vector3.new(well, deckThick, wingZ), topCenter + Vector3.new(0, -deckThick / 2, sz * (well * 0.5 + wingZ * 0.5)), varrashSandstone, Enum.Material.Sandstone)
						end
						flatDisc("ElderHeartRim", topCenter + Vector3.new(0, 0.08, 0), well + 5.5, 0.25, fortBasalt, Enum.Material.Basalt)
						flatDisc("ElderHeartGlass", topCenter + Vector3.new(0, -0.25, 0), well + 1.0, 0.35, Color3.fromRGB(224, 118, 34), Enum.Material.Glass, false)
						decor(model, "ElderHeartCageCore", Vector3.new(10, 1.8, 10), topCenter + Vector3.new(0, -4.0, 0), Color3.fromRGB(255, 108, 28), Enum.Material.Neon)
						-- Flanking basalt support piers anchored into the caldera floor
						for _, sx in { -1, 1 } do
							local cp = Vector3.new(topCenter.X + sx * 24, topCenter.Y - wallH / 2 - 0.16, topCenter.Z)
							local pier = part(model, "ElderChestPier", Vector3.new(16, wallH - 0.16, terrace.Depth - 6), cp, fortBasalt, Enum.Material.Basalt, true)
							pier.CanQuery = true
							pier.CanTouch = false
						end
					else
						-- Apex (Colossus Dais): solid flat sandstone arena floor with weathered ceremonial disc rings
						slab.Color = varrashSandstone
						slab.Material = Enum.Material.Sandstone
						flatDisc("ColossusDaisOuterRing", topCenter + Vector3.new(0, 0.06, 0), math.min(terrace.Width, terrace.Depth) * 0.88, 0.10, sandStoneDark, Enum.Material.Sandstone)
						flatDisc("ColossusDaisEmberSeam", topCenter + Vector3.new(0, 0.11, 0), math.min(terrace.Width, terrace.Depth) * 0.62, 0.08, Color3.fromRGB(168, 92, 62), Enum.Material.Slate)
						flatDisc("ColossusDaisCenterDisc", topCenter + Vector3.new(0, 0.15, 0), math.min(terrace.Width, terrace.Depth) * 0.56, 0.08, varrashSandstone, Enum.Material.Sandstone)
						for _, sx in { -1, 1 } do
							local cp = Vector3.new(topCenter.X + sx * 44, topCenter.Y - wallH / 2 - 0.16, topCenter.Z)
							local pier = part(model, "DaisSupportPier", Vector3.new(30, wallH - 0.16, terrace.Depth - 10), cp, fortBasalt, Enum.Material.Basalt, true)
							pier.CanQuery = true
							pier.CanTouch = false
						end
					end
					-- Rugged battered basalt cliff outcrops hugging corners so stone platforms blend naturally into caldera rock
					for _, sx in { -1, 1 } do
						for _, sz in { -1, 1 } do
							local outPos = Vector3.new(topCenter.X + sx * (terrace.Width * 0.47), topCenter.Y - wallH * 0.48 - 1.2, topCenter.Z + sz * (terrace.Depth * 0.43))
							local boulder = decor(model, "BastionCliffOutcrop", Vector3.new(13, wallH * 0.92, 14), outPos, fortBasalt, Enum.Material.Basalt)
							boulder.CFrame = CFrame.new(outPos) * CFrame.Angles(math.rad(sx * 4), math.rad(sx * 19 + sz * 21), math.rad(sz * 4))
							local capPos = topCenter + Vector3.new(sx * (terrace.Width * 0.46), -0.45, sz * (terrace.Depth * 0.44))
							local capStone = decor(model, "BastionRimStone", Vector3.new(12, 2.2, 12), capPos, sandStoneDark, Enum.Material.Sandstone)
							capStone.CFrame = CFrame.new(capPos) * CFrame.Angles(0, math.rad(sx * 24 + sz * 16), 0)
						end
					end
					for k = 1, 7 do
						local ang = k * 1.9 + terrace.X * 0.02
						local rx = math.cos(ang) * (terrace.Width * 0.34)
						local rz = math.sin(ang) * (terrace.Depth * 0.32)
						local pPos = topCenter + Vector3.new(rx, 0.19 + k * 0.03, rz)
						local paver = decor(model, "VarrashFortressFlagstone", Vector3.new(8.5 + (k % 3) * 2.2, 0.10, 6.5 + ((k + 1) % 3) * 1.6), pPos, if k % 2 == 0 then varrashSandstone else sandStoneDark, Enum.Material.Sandstone)
						paver.CFrame = CFrame.new(pPos) * CFrame.Angles(0, math.rad((k * 19) % 24 - 12), 0)
					end
				elseif deckKind == "GLACIER_SLAB" then
					-- Jagged lake ice floe slabs (Floor 16 & Frozen Iceway): snow-packed walking cap over translucent glacier keel
					local deepBottom = origin.Y + layout.Bottom - 5
					local wallH = math.max(3.5, (origin.Y + terrace.Y) - deepBottom)
					slab.Size = Vector3.new(terrace.Width, wallH, terrace.Depth)
					slab.Position = Vector3.new(topCenter.X, topCenter.Y - wallH / 2, topCenter.Z)
					slab.Color = glacierIceCol
					slab.Material = Enum.Material.Glacier
					local snowCap = decor(model, "GlacierFloeSnowCap", Vector3.new(terrace.Width - 2.6, 0.45, terrace.Depth - 2.6), topCenter + Vector3.new(0, -0.18, 0), glacierSnowCol, Enum.Material.Snow)
					snowCap.CFrame = CFrame.new(topCenter + Vector3.new(0, -0.18, 0))
					for _, sz in { -1, 1 } do
						decor(model, "GlacierSlabIceRimZ", Vector3.new(terrace.Width + 2.2, 1.8, 2.4), topCenter + Vector3.new(0, -1.6, sz * (terrace.Depth / 2 + 0.2)), glacierDeepCol, Enum.Material.Ice, 0.15)
					end
					for _, sx in { -1, 1 } do
						decor(model, "GlacierSlabIceRimX", Vector3.new(2.4, 1.8, math.max(1, terrace.Depth - 2.2)), topCenter + Vector3.new(sx * (terrace.Width / 2 + 0.2), -1.6, 0), glacierDeepCol, Enum.Material.Ice, 0.15)
					end
				else
					slab.Color = solmereLimestone
					slab.Material = Enum.Material.Limestone
				end
				continue
			end
			slab.Color = naturalGrassColor
			if groundPalette then slab.Material = groundPalette.Ground end
			if isDirectTerrainLayout(layout) then
				-- Players and heroes walk directly on the sculpted Terrain surface; keep the invisible slab non-colliding
				-- so characters never float above slight voxel contour dips.
				disableTerrainProxyPart(slab)
			end
			if name ~= "Sanctuary" then
				continue
			end
		end
		if name ~= "Sanctuary" and name ~= "Basin" then
			decor(model, "TerraceCenterMosaic", Vector3.new(terrace.Width * 0.62, 0.12, terrace.Depth * 0.62), topCenter + Vector3.new(0, 0.08, 0), theme.TrimColor, theme.TrimMaterial)
			decor(model, "TerraceInnerField", Vector3.new(terrace.Width * 0.52, 0.14, terrace.Depth * 0.52), topCenter + Vector3.new(0, 0.16, 0), theme.GroundColor, theme.GroundMaterial)
		end

		if name ~= "Sanctuary" or not natural then
			for _, side in { -1, 1 } do
				decor(model, "TerraceMasonryBand", Vector3.new(terrace.Width + 2, 1.6, 2.2), topCenter + Vector3.new(0, -0.6, side * (terrace.Depth / 2)), theme.TrimColor, theme.TrimMaterial)
				decor(model, "TerraceSideBand", Vector3.new(2.2, 1.6, math.max(1, terrace.Depth - 2.5)), topCenter + Vector3.new(side * (terrace.Width / 2), -0.6, 0), theme.TrimColor, theme.TrimMaterial)
				if thickness > 5 then
					decor(model, "TerracePlinthZ", Vector3.new(terrace.Width + 6, thickness * 0.65, 4), origin + Vector3.new(terrace.X, layout.Bottom + thickness * 0.32 - 2, terrace.Z + side * (terrace.Depth / 2 + 1)), theme.CliffColor, theme.CliffMaterial)
					decor(model, "TerracePlinthX", Vector3.new(4, thickness * 0.65, math.max(1, terrace.Depth - 2.5)), origin + Vector3.new(terrace.X + side * (terrace.Width / 2 + 1), layout.Bottom + thickness * 0.32 - 2, terrace.Z), theme.CliffColor, theme.CliffMaterial)
				end
			end
		end

		if name ~= "Sanctuary" then
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local corner = topCenter + Vector3.new(sx * (terrace.Width / 2 - 4), 0, sz * (terrace.Depth / 2 - 4))
					if isNatural then
						local outcrop = propGroup(model, "TerraceOutcrop")
						decor(outcrop, "TerraceRockOutcrop", Vector3.new(7, 5, 7), corner + Vector3.new(0, 2.5, 0), theme.CliffColor, theme.CliffMaterial)
						local flora = decor(outcrop, "TerraceGlowFlora", Vector3.new(2.5, 3.2, 2.5), corner + Vector3.new(0, 5.5, 0), theme.LightColor, Enum.Material.SmoothPlastic, 0.15)
						local pl = Instance.new("PointLight")
						pl.Name = "TerraceCornerLight"
						pl.Color = theme.LightColor
						pl.Brightness = 0.65
						pl.Range = 26
						pl.Shadows = false
						pl.Parent = flora
					else
						local pedestal = propGroup(model, "TerraceBrazier")
						decor(pedestal, "TerraceCornerPedestal", Vector3.new(5, 8, 5), corner + Vector3.new(0, 4, 0), theme.TrimColor, theme.TrimMaterial)
						local brazier = decor(pedestal, "TerraceCornerBrazier", Vector3.new(3, 2.5, 3), corner + Vector3.new(0, 9, 0), theme.LightColor, Enum.Material.SmoothPlastic, 0.1)
						local pl = Instance.new("PointLight")
						pl.Name = "TerraceCornerLight"
						pl.Color = theme.LightColor
						pl.Brightness = 0.65
						pl.Range = 26
						pl.Shadows = false
						pl.Parent = brazier
					end
				end
			end
		end
	end

	local function structure(p: BasePart, id: string)
		p:SetAttribute("NavigationStructure",true)
		p:SetAttribute("ConnectorId",id)
	end
	-- Solmere paths (a hand-authored floor's PathStyle, TowerLayout): on a natural floor the ramps are pale
	-- flagstone causeways with step lips, moss along the edges and visible mossy kerbs, the grand stairs are
	-- limestone, and the landings take the terrace's own ground so they don't read as tiles laid on the grass.
	local grassyPaths = natural and isDirectTerrainLayout(layout)
	local landingLayerByTerrace: { [string]: number } = {}
	local function landing(pad: any, id: string, terraceName: string?)
		local a=origin+Vector3.new(pad.AX,pad.AY,pad.AZ)
		local b=origin+Vector3.new(pad.BX,pad.BY,pad.BZ)
		local p=part(model,"TraversalLanding",Vector3.new(pad.Width,2,(b-a).Magnitude),(a+b)/2,theme.TrimColor,theme.TrimMaterial)
		-- Landing tops sit 0.08 above terrace planes (ramps 0.04) so coplanar faces never z-fight at joins.
		p.CFrame=CFrame.lookAt((a+b)/2,b)*CFrame.new(0,-0.92,0)
		if isArchitecturalDeck(layout, terraceName) then
			if masonryStyle and masonryStyle.LandingProxy then
				-- Keep landing collider solid & flush atop organic/fortress decks without showing protruding rectangles.
				disableTerrainProxyPart(p)
				p.CanCollide = true
				p.CanQuery = true
			else
				p.Color = (masonryStyle and masonryStyle.LandingColor) or (pathStyle and pathStyle.LandingColor) or solmereLimestone
				p.Material = (masonryStyle and masonryStyle.LandingMaterial) or (pathStyle and pathStyle.LandingMaterial) or Enum.Material.Limestone
				if masonryStyle and masonryStyle.LandingStacked then
					-- Stack multiple landings on the same terrace by +0.03 so overlapping landings never z-fight,
					-- and start at +0.05 above TraversalRamp (+0.01) and Slab (0.00) and below medallions/flagstones (+0.14+).
					local tKey = terraceName or ""
					local layer = landingLayerByTerrace[tKey] or 0
					landingLayerByTerrace[tKey] = layer + 1
					local topOff = -0.95 + layer * 0.03 -- height 2: top = +0.05, +0.08, +0.11...
					p.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, topOff, 0)
					if masonryStyle.LandingStoneUnderside then
						local under = decor(model, "LandingStoneUnderside", Vector3.new(pad.Width - 1.6, 1.4, math.max(1, (b - a).Magnitude - 1.0)), (a + b) / 2, flagstoneDark, Enum.Material.Limestone)
						under.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, topOff - 1.75, 0)
					end
				end
			end
		elseif natural then
			p.Color = naturalGrassColor
			if groundPalette then p.Material = groundPalette.Ground end
			if grassyPaths then
				disableTerrainProxyPart(p)
			end
		end
		structure(p,id)
	end
	for _, link in layout.Links do
		local a = origin + Vector3.new(link.AX, link.AY, link.AZ)
		local b = origin + Vector3.new(link.BX, link.BY, link.BZ)
		local delta = b - a
		local mid = (a + b) / 2
		local flat = Vector3.new(delta.X, 0, delta.Z)
		local flatUnit = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
		local right = Vector3.new(-flatUnit.Z, 0, flatUnit.X)
		landing(link.LandingA,link.Id,link.From)
		landing(link.LandingB,link.Id,link.To)

		if link.Kind == "STAIRS" then
			local steps = math.max(1, math.ceil(math.abs(delta.Y)))
			local suspended = isSuspendedLink(layout, link.Id)
			local rootStair = suspended and (not pathStyle or pathStyle.AllowRootStair ~= false)
			local stairInlayCol = masonryStyle and masonryStyle.StairAmberInlay
			for step = 1, steps do
				local t = (step - 0.5) / steps
				local top = a.Y + delta.Y * step / steps
				local center = a + flat * t
				local baseTreadW = if rootStair then link.Width * (0.84 + 0.14 * math.sin(step * 1.15)) else link.Width
				local treadW = baseTreadW - (step % 2) * 0.08
				local treadCol = if masonryStyle and masonryStyle.StairColorA
					then (if step % 2 == 0 then masonryStyle.StairColorA else masonryStyle.StairColorB)
					elseif pathStyle
					then (if step % 2 == 0 then pathStyle.StairColorA else pathStyle.StairColorB)
					else theme.TrimColor
				local treadMat = if masonryStyle and masonryStyle.StairMatA
					then (if step % 2 == 0 then masonryStyle.StairMatA else masonryStyle.StairMatB)
					elseif pathStyle
					then (if step % 2 == 0 then pathStyle.StairMatA else pathStyle.StairMatB)
					else theme.TrimMaterial
				local tread = part(
					model,
					"GrandStairTread",
					Vector3.new(treadW, 2, flat.Magnitude / steps + 0.18),
					Vector3.new(center.X, top - 1, center.Z),
					treadCol,
					treadMat
				)
				tread.CFrame = CFrame.lookAt(tread.Position, tread.Position + flat) * (if rootStair then CFrame.Angles(0, math.rad(math.sin(step * 1.7) * 2.5), 0) else CFrame.identity)
				structure(tread,link.Id)
				if stairInlayCol and step % 2 == 1 then
					local inlay = decor(model, "GlassStairAmberInlay", Vector3.new(treadW * 0.72, 0.08, 0.42), Vector3.new(center.X, top + 0.05, center.Z), stairInlayCol, Enum.Material.Neon)
					inlay.CFrame = CFrame.lookAt(inlay.Position, inlay.Position + flat) * CFrame.new(0, 0, -0.35)
				end
				if natural then continue end
				local runner = decor(model, "GrandStairRunner", Vector3.new(link.Width * 0.36, 0.12, flat.Magnitude / steps + 0.2), Vector3.new(center.X, top + 0.08, center.Z), theme.AccentColor, theme.TrimMaterial)
				runner.CFrame = CFrame.lookAt(runner.Position, runner.Position + flat)
			end
			if suspended and masonryStyle and masonryStyle.StairUnder then
				-- Stringer keel underneath suspended stairs (obsidian on F13, basalt on F15 trade-road cut)
				local underStair = decor(model, "GlassStairUnderside", Vector3.new(link.Width - 3.0, masonryStyle.StairUnderHeight, math.max(1, delta.Magnitude - 1.0)), mid, obsidianStairA, Enum.Material.Basalt)
				underStair.CFrame = CFrame.lookAt(mid, b) * CFrame.new(0, masonryStyle.StairUnderY, 0)
				if masonryStyle.StairUnderVeins then
					for _, side in { -1, 1 } do
						local seam = decor(model, "GlassStairSideVein", Vector3.new(0.5, 0.65, math.max(1, delta.Magnitude - 2.0)), mid + right * (side * (link.Width * 0.44)), amberInlayCol, Enum.Material.Glass, 0.2)
						seam.CFrame = CFrame.lookAt(seam.Position, seam.Position + delta) * CFrame.new(0, -1.35, 0)
					end
				end
			end
			if rootStair then
				-- Braided Heartroot trunks climbing both sides across landings & hugging underneath the root-cut stairs
				local landA = origin + Vector3.new(link.LandingA.AX, link.LandingA.AY, link.LandingA.AZ)
				local landB = origin + Vector3.new(link.LandingB.BX, link.LandingB.BY, link.LandingB.BZ)
				local stairStart = a:Lerp(landA, 0.55)
				local stairEnd = b:Lerp(landB, 0.55)
				local stairSegs = 6
				for _, side in { -1, 1 } do
					local prevPt = stairStart + right * (side * (link.Width * 0.48)) - Vector3.new(0, 2.2, 0)
					for k = 1, stairSegs do
						local t = k / stairSegs
						local isEnd = k == stairSegs
						local sway = math.sin(t * math.pi * 2.2) * 1.5 * side
						local lift = if isEnd then -2.2 else math.sin(t * math.pi) * 0.8 - 0.8
						local nextPt = stairStart:Lerp(stairEnd, t) + right * (side * (link.Width * 0.48) + sway) + Vector3.new(0, lift, 0)
						rootCylinder("StairRootCable", prevPt, nextPt, 3.2 - t * 0.4, if (k + (if side > 0 then 1 else 0)) % 2 == 0 then rootBarkColor else rootBarkDark, Enum.Material.Wood)
						if k % 2 == 1 and not isEnd then
							flatDisc("StairRootMoss", nextPt + Vector3.new(0, 1.3, 0), 4.8, 0.8, moss, Enum.Material.LeafyGrass)
						end
						prevPt = nextPt
					end
				end
				rootCylinder("RootBridgeSapVein", a - Vector3.new(0, 2.2, 0), b - Vector3.new(0, 2.2, 0), 0.75, rootSapColor, Enum.Material.Neon)
			end
		else
			local ramp = part(model, "TraversalRamp", Vector3.new(link.Width, 2, delta.Magnitude), mid, theme.TrimColor, theme.TrimMaterial)
			ramp.CFrame = CFrame.lookAt(mid, b) * CFrame.new(0, if masonryStyle and masonryStyle.RampYOffset then masonryStyle.RampYOffset else -0.96, 0)
			structure(ramp,link.Id)
			local bridgeKind = masonryStyle and masonryStyle.BridgeKind
			if isSuspendedLink(layout, link.Id) and bridgeKind == "SOLMERE_ARCH" then
				-- Floors 4-5 Solmere mossy limestone bridges across the moat/cenote:
				-- solid weathered stone deck continuing cleanly onto both landings, with bank abutments, flagstones & hanging vines.
				ramp.Color = solmereLimestone
				ramp.Material = Enum.Material.Limestone
				local landA = origin + Vector3.new(link.LandingA.AX, link.LandingA.AY, link.LandingA.AZ)
				-- Anchor moat bridges leaving the grassy Outer Ward / Cenote Rim bank (From == "Basin") on a solid battered stone abutment down into the moat/cenote bed
				if link.From == "Basin" then
					local deepBottom = origin.Y + layout.Bottom - 7
					local abutH = math.max(6, a.Y - deepBottom - 0.2)
					local abutAt = a:Lerp(landA, 0.28)
					local abut = part(model, "BridgeBankAbutment", Vector3.new(link.Width + 3.2, abutH, 10), Vector3.new(abutAt.X, a.Y - abutH / 2 - 0.25, abutAt.Z), flagstoneDark, Enum.Material.Limestone)
					abut.CFrame = CFrame.lookAt(Vector3.new(abutAt.X, a.Y - abutH / 2 - 0.25, abutAt.Z), Vector3.new(b.X, a.Y - abutH / 2 - 0.25, b.Z))
					abut.CanQuery = true
					abut.CanTouch = false
				end
				local underRamp = decor(model, "BridgeStoneUnderside", Vector3.new(link.Width - 2.4, 1.3, math.max(1, delta.Magnitude - 1.2)), mid, flagstoneDark, Enum.Material.Limestone)
				underRamp.CFrame = CFrame.lookAt(mid, b) * CFrame.new(0, -2.68, 0)
				-- Place bridge flagstones strictly along the inclined deck [0.08..0.92] well above TraversalRamp & Landing layers (+0.20)
				local stoneA = a:Lerp(b, 0.08)
				local stoneB = a:Lerp(b, 0.92)
				local fullStoneLen = (stoneB - stoneA).Magnitude
				local stones = math.max(3, math.floor((fullStoneLen - 2) / 4.2))
				for i = 1, stones do
					local t = (i - 0.5) / stones
					local stagger = math.sin(i * 1.7) * 1.4
					local at = stoneA:Lerp(stoneB, t) + right * stagger
					local stoneW = link.Width * (0.46 + ((i * 5) % 4) * 0.05)
					local stone = decor(model, "RampStepLip", Vector3.new(stoneW, 0.14, 3.0), at, if i % 2 == 0 then flagstone else flagstoneDark, Enum.Material.Limestone)
					stone.CFrame = CFrame.lookAt(at, at + (stoneB - stoneA)) * CFrame.new(0, 0.21 + (i % 2) * 0.03, 0) * CFrame.Angles(0, math.rad(((i * 17) % 12) - 6), 0)
				end
				-- Coiling strangler vine cables & hanging tendrils along bridge shoulders
				local segs = math.clamp(math.floor(delta.Magnitude / 18), 2, 5)
				for _, side in { -1, 1 } do
					local prevPt = a + right * (side * (link.Width * 0.45)) - Vector3.new(0, 0.4, 0)
					for k = 1, segs do
						local t = k / segs
						local nextPt = a:Lerp(b, t) + right * (side * (link.Width * 0.45) + math.sin(t * math.pi * 2) * 0.7) + Vector3.new(0, math.sin(t * math.pi) * 0.6 - 0.4, 0)
						rootCylinder("BridgeVineRail", prevPt, nextPt, 1.4, rootBarkDark, Enum.Material.Wood)
						if k < segs then
							rootCylinder("HangingRootTendril", nextPt, nextPt + right * (side * 1.2) - Vector3.new(0, 5.5 + (k % 2) * 2.5, 0), 0.55, moss, Enum.Material.Grass)
						end
						prevPt = nextPt
					end
				end
			elseif isSuspendedLink(layout, link.Id) and bridgeKind == "FORTRESS_CAUSEWAY" then
				-- Floor 14 Sunscar Fortress bridges: weathered sandstone causeways with natural sand/stone blending,
				-- subtle staggered paving (no harsh stripes), and battered basalt piers beside the lava, never in it.
				local fortBasalt = Color3.fromRGB(48, 42, 46)
				local stoneWarm = Color3.fromRGB(174, 144, 106)
				local stoneMuted = Color3.fromRGB(156, 128, 94)
				local driftSandCol = Color3.fromRGB(154, 136, 108)
				ramp.Color = varrashSandstone
				ramp.Material = Enum.Material.Sandstone
				if link.From == "Basin" then
					local deepBottom = origin.Y + layout.Bottom - 7
					local abutH = math.max(6, a.Y - deepBottom - 0.15)
					local abutAt = a:Lerp(b, 0.45)
					local abut = part(model, "BridgeBankAbutment", Vector3.new(link.Width - 1.5, abutH, 11), Vector3.new(abutAt.X, a.Y - abutH / 2 - 0.35, abutAt.Z), fortBasalt, Enum.Material.Basalt)
					abut.CFrame = CFrame.lookAt(Vector3.new(abutAt.X, a.Y - abutH / 2 - 0.35, abutAt.Z), Vector3.new(b.X, a.Y - abutH / 2 - 0.35, b.Z))
					abut.CanQuery = true
					abut.CanTouch = false
					-- Angled basalt outcrop boulders blending the south abutment shoulders into Ashmarket sand
					for _, side in { -1, 1 } do
						local shoulderPos = a:Lerp(b, 0.22) + right * (side * (link.Width * 0.54)) + Vector3.new(0, -1.6, 0)
						local boulder = decor(model, "BridgeMouthBoulder", Vector3.new(6.2, 4.4, 8.5), shoulderPos, fortBasalt, Enum.Material.Basalt)
						boulder.CFrame = CFrame.lookAt(shoulderPos, shoulderPos + flat) * CFrame.Angles(math.rad(-8), math.rad(side * 22), math.rad(side * -14))
					end
				end
				if link.Id == "WestGallery_EastGallery" then
					-- Scar Bridge piers: rise from chasm bedrock outside the X = [-22..+22] Sunscar lava channel (around X = +-46 & +-86).
					local deepBottom = origin.Y + layout.Bottom - 7
					for _, frac in { 0.16, 0.31, 0.69, 0.84 } do
						local pAt = a:Lerp(b, frac)
						local pH = math.max(6, pAt.Y - deepBottom - 1.5)
						local pier = part(model, "ScarBridgeBasaltPier", Vector3.new(link.Width - 1.5, pH, 9.5), Vector3.new(pAt.X, pAt.Y - pH / 2 - 1.6, pAt.Z), fortBasalt, Enum.Material.Basalt)
						pier.CFrame = CFrame.lookAt(pier.Position, pier.Position + flat)
						pier.CanQuery = true
						pier.CanTouch = false
					end
				end
				local underRamp = decor(model, "BridgeStoneUnderside", Vector3.new(link.Width - 1.8, 2.8, math.max(1, delta.Magnitude - 1.0)), mid, fortBasalt, Enum.Material.Basalt)
				underRamp.CFrame = CFrame.lookAt(mid, b) * CFrame.new(0, -3.15, 0)
				local stoneA = a:Lerp(b, 0.06)
				local stoneB = a:Lerp(b, 0.94)
				local stones = math.max(3, math.floor(((stoneB - stoneA).Magnitude - 2) / 5.4))
				for i = 1, stones do
					local t = (i - 0.5) / stones
					local stagger = math.sin(i * 2.1 + delta.X * 0.03) * 2.4
					local at = stoneA:Lerp(stoneB, t) + right * stagger
					local stoneW = link.Width * (0.30 + ((i * 5) % 4) * 0.04)
					local stone = decor(model, "RampStepLip", Vector3.new(stoneW, 0.10, 3.6), at, if i % 2 == 0 then stoneWarm else stoneMuted, Enum.Material.Sandstone)
					stone.CFrame = CFrame.lookAt(at, at + (stoneB - stoneA)) * CFrame.new(0, 0.09 + (i % 3) * 0.025, 0) * CFrame.Angles(0, math.rad(((i * 23) % 16) - 8), 0)
				end
			elseif isSuspendedLink(layout, link.Id) and bridgeKind == "OBSIDIAN_GLASS" then
				-- Floor 13 ravine-spanning fused black obsidian & amber-glass arch bridge: solid surface over open chasm.
				local obsidian = Color3.fromRGB(26, 22, 28)
				local amberGlass = Color3.fromRGB(238, 142, 42)
				ramp.Color = obsidian
				ramp.Material = Enum.Material.Slate
				local underRamp = decor(model, "BridgeGlassUnderside", Vector3.new(link.Width - 2.6, 2.0, math.max(1, delta.Magnitude - 1.0)), mid, varrashBasalt, Enum.Material.Basalt)
				underRamp.CFrame = CFrame.lookAt(mid, b) * CFrame.new(0, -2.55, 0)
				for _, side in { -1, 1 } do
					local vein = decor(model, "BridgeAmberVein", Vector3.new(0.65, 0.65, math.max(1, delta.Magnitude - 2.0)), mid + right * (side * (link.Width * 0.44)), amberGlass, Enum.Material.Glass, 0.22)
					vein.CFrame = CFrame.lookAt(vein.Position, vein.Position + delta) * CFrame.new(0, -1.55, 0)
				end
				local stoneA = a:Lerp(b, 0.08)
				local stoneB = a:Lerp(b, 0.92)
				local stones = math.max(3, math.floor(((stoneB - stoneA).Magnitude - 2) / 5.5))
				for i = 1, stones do
					local t = (i - 0.5) / stones
					local at = stoneA:Lerp(stoneB, t)
					local band = decor(model, "RampStepLip", Vector3.new(link.Width * 0.58, 0.10, 0.65), at, if i % 2 == 0 then amberGlass else varrashBasalt, if i % 2 == 0 then Enum.Material.Glass else Enum.Material.Slate, if i % 2 == 0 then 0.2 else nil)
					band.CFrame = CFrame.lookAt(at, at + (stoneB - stoneA)) * CFrame.new(0, 0.08 + (i % 2) * 0.03, 0)
				end
			elseif isSuspendedLink(layout, link.Id) and bridgeKind == "GLACIER_SLAB" then
				-- Alpine timber-and-granite frost bridge over the frozen lake (plank deck, stone girders, lake piers)
				local bridgeWoodA = Color3.fromRGB(102, 80, 62)
				local bridgeWoodB = Color3.fromRGB(86, 66, 52)
				local deepBottom = origin.Y + layout.Bottom - 5
				ramp.Color = bridgeWoodA
				ramp.Material = Enum.Material.Wood
				for _, side in { -1, 1 } do
					local beamAt = mid + right * (side * (link.Width * 0.43))
					local girder = decor(model, "BridgeSideGirder", Vector3.new(1.8, 1.9, math.max(1, delta.Magnitude - 0.5)), beamAt, whiteguardGranite, Enum.Material.Slate)
					girder.CFrame = CFrame.lookAt(beamAt, beamAt + delta) * CFrame.new(0, -1.95, 0)
				end
				local pierFracs = if delta.Magnitude > 58 then { 0.24, 0.50, 0.76 } else { 0.28, 0.72 }
				for _, frac in pierFracs do
					local pt = a:Lerp(b, frac)
					local pierH = math.max(2.5, pt.Y - deepBottom - 1.2)
					for _, side in { -1, 1 } do
						local pierPos = pt + right * (side * (link.Width * 0.42)) - Vector3.new(0, pierH * 0.5 + 1.2, 0)
						decor(model, "BridgeLakePier", Vector3.new(2.5, pierH, 2.5), pierPos, whiteguardGranite, Enum.Material.Slate)
					end
				end
				local stoneA = a:Lerp(b, 0.05)
				local stoneB = a:Lerp(b, 0.95)
				local planks = math.max(4, math.floor(((stoneB - stoneA).Magnitude - 1) / 6.2))
				for i = 1, planks do
					local t = (i - 0.5) / planks
					local at = stoneA:Lerp(stoneB, t)
					local plank = decor(model, "BridgePlankSleeper", Vector3.new(link.Width + 0.6, 0.14, 2.6), at, if i % 2 == 0 then bridgeWoodA else bridgeWoodB, Enum.Material.Wood)
					plank.CFrame = CFrame.lookAt(at, at + (stoneB - stoneA)) * CFrame.new(0, 0.06 + (i % 2) * 0.015, 0)
				end
			elseif isSuspendedLink(layout, link.Id) then
				-- Floor 3 Gorge-spanning Heartroot bridge: invisible flat collider slab wrapped in densely braided curved
				-- Heartroot cables spanning INTO LandingA and LandingB so bridge roots connect seamlessly into
				-- both banks and round stump/island pads (zero floating cut ends).
				disableTerrainProxyPart(ramp)
				ramp.CanCollide = true
				ramp.CanQuery = true

				local landA = origin + Vector3.new(link.LandingA.AX, link.LandingA.AY, link.LandingA.AZ)
				local landB = origin + Vector3.new(link.LandingB.BX, link.LandingB.BY, link.LandingB.BZ)
				local spanStart = a:Lerp(landA, 0.95)
				local spanEnd = b:Lerp(landB, 0.95)

				local segs = math.clamp(math.floor(delta.Magnitude / 15), 3, 6)
				local strands = {
					{ off = -10.5, yOff = -1.7, dia = 4.6, wave = 1.5, matCol = rootBarkDark },
					{ off = -5.2, yOff = -2.0, dia = 5.4, wave = -1.3, matCol = rootBarkColor },
					{ off = 0.0, yOff = -2.2, dia = 5.8, wave = 1.2, matCol = rootBarkColor },
					{ off = 5.2, yOff = -2.0, dia = 5.4, wave = 1.4, matCol = rootBarkDark },
					{ off = 10.5, yOff = -1.7, dia = 4.6, wave = -1.5, matCol = rootBarkColor },
					{ off = -(link.Width * 0.46), yOff = 0.4, dia = 3.0, wave = 1.3, matCol = rootBarkDark },
					{ off = (link.Width * 0.46), yOff = 0.4, dia = 3.0, wave = -1.3, matCol = rootBarkDark },
				}
				for sIdx, st in strands do
					-- Root cable anchors down inside LandingA, arches smoothly across [a..b], and plunges inside LandingB
					local prevPt = spanStart + right * (st.off * 0.85) + Vector3.new(0, st.yOff - 2.4, 0)
					local joinA = a + right * st.off + Vector3.new(0, st.yOff, 0)
					rootCylinder("RootBridgeCable", prevPt, joinA, st.dia * 1.05, st.matCol, Enum.Material.Wood)
					prevPt = joinA
					for k = 1, segs do
						local t = k / segs
						local endTaper = math.sin(t * math.pi)
						local sway = math.sin(t * math.pi * 2.4 + sIdx) * st.wave * endTaper
						local sag = if st.yOff < -1 then -math.sin(t * math.pi) * 0.5 else math.sin(t * math.pi * 1.5) * 0.5
						local nextPt = a:Lerp(b, t) + right * (st.off + sway) + Vector3.new(0, st.yOff + sag, 0)
						rootCylinder("RootBridgeCable", prevPt, nextPt, st.dia, st.matCol, Enum.Material.Wood)
						prevPt = nextPt
					end
					local joinEnd = spanEnd + right * (st.off * 0.85) + Vector3.new(0, st.yOff - 2.4, 0)
					rootCylinder("RootBridgeCable", prevPt, joinEnd, st.dia * 1.05, st.matCol, Enum.Material.Wood)
				end
				-- Braided cross-bind ribs, moss pads, and hanging gorge tendrils
				for k = 1, segs - 1 do
					local t = k / segs
					local pt = a:Lerp(b, t)
					rootCylinder("RootCrossRib", pt - right * (link.Width * 0.42) - Vector3.new(0, 1.55, 0), pt + right * (link.Width * 0.42) - Vector3.new(0, 1.55, 0), 2.8, rootBarkDark, Enum.Material.Wood)
					local side = if k % 2 == 0 then 1 else -1
					local edgePt = pt + right * (side * (link.Width * 0.45))
					flatDisc("BridgeRootMoss", edgePt + Vector3.new(0, 0.5, 0), 4.8 + (k % 2), 0.9, moss, Enum.Material.LeafyGrass)
					rootCylinder("HangingRootTendril", edgePt - Vector3.new(0, 1.0, 0), edgePt + right * (side * 1.6) - Vector3.new(0, 6.5 + (k % 3) * 2.5, 0), 0.75, rootBarkDark, Enum.Material.Wood)
				end
				-- Glowing underside sap vein curving under the root bridge
				local prevSap = a - Vector3.new(0, 3.6, 0)
				for k = 1, 3 do
					local t = k / 3
					local nextSap = a:Lerp(b, t) + right * (math.sin(t * math.pi * 2) * 2.2) - Vector3.new(0, 3.6 + math.sin(t * math.pi) * 1.0, 0)
					rootCylinder("RootBridgeSapVein", prevSap, nextSap, 0.72, rootSapColor, Enum.Material.Neon)
					prevSap = nextSap
				end
				-- Irregular weathered Solmere flagstones staying strictly along the root bridge deck above stump/island rims
				local stoneA = a:Lerp(b, 0.08)
				local stoneB = a:Lerp(b, 0.92)
				local fullStoneLen = (stoneB - stoneA).Magnitude
				local stones = math.max(3, math.floor((fullStoneLen - 2) / 4.2))
				for i = 1, stones do
					local t = (i - 0.5) / stones
					local stagger = math.sin(i * 1.9) * 1.5
					local at = stoneA:Lerp(stoneB, t) + right * stagger
					local stoneW = link.Width * (0.36 + ((i * 7) % 4) * 0.05)
					local stone = decor(model, "RampStepLip", Vector3.new(stoneW, 0.16, 3.0), at, if i % 2 == 0 then flagstone else flagstoneDark, Enum.Material.Limestone)
					stone.CFrame = CFrame.lookAt(at, at + (stoneB - stoneA)) * CFrame.new(0, 0.15 + (i % 2) * 0.03, 0) * CFrame.Angles(0, math.rad(((i * 23) % 18) - 9), 0)
				end
			elseif grassyPaths then
				ramp.Color = naturalGrassColor
				if groundPalette then ramp.Material = groundPalette.Ground end
				disableTerrainProxyPart(ramp)
				local length = delta.Magnitude
				local stones = math.max(1, math.floor((length - 4) / 5.2))
				local wBase = (pathStyle and pathStyle.GrassStepLipWBase) or 0.26
				local wStep = (pathStyle and pathStyle.GrassStepLipWStep) or 0.04
				local wMod = (pathStyle and pathStyle.GrassStepLipWMod) or 7
				local lipH = (pathStyle and pathStyle.GrassStepLipH) or 0.45
				local lipY = (pathStyle and pathStyle.GrassStepLipY) or 0.06
				for i = 1, stones do
					local stagger = if i % 2 == 0 then 1.4 else -1.4
					local at = a:Lerp(b, (i - 0.5) / stones) + right * stagger
					local stoneW = link.Width * (wBase + ((i * wMod) % 3) * wStep)
					local lipCol = if pathStyle then (if i % 2 == 0 then pathStyle.GrassStepLipColorA else pathStyle.GrassStepLipColorB) else flagstoneDark
					local lipMat = if pathStyle then (if i % 2 == 0 then pathStyle.GrassStepLipMatA else pathStyle.GrassStepLipMatB) else Enum.Material.Limestone
					local stone = decor(model, "RampStepLip", Vector3.new(stoneW, lipH, 2.5), at, lipCol, lipMat)
					stone.CFrame = CFrame.lookAt(at, at + delta) * CFrame.new(0, lipY, 0) * CFrame.Angles(0, math.rad(((i * 19) % 14) - 7), 0)
				end
			elseif pathStyle and pathStyle.SolidRampColor then
				ramp.Color = pathStyle.SolidRampColor
				ramp.Material = pathStyle.SolidRampMat
				local length = delta.Magnitude
				local lips = math.max(1, math.floor((length - 4) / (pathStyle.SolidLipStep or 3.4)))
				for i = 1, lips do
					local at = a:Lerp(b, (i - 0.5) / lips)
					local lip = decor(model, "RampStepLip", Vector3.new(link.Width - 5.5, 0.16, 0.7), at, if i % 2 == 0 then pathStyle.SolidLipColorA else pathStyle.SolidLipColorB, if i % 2 == 0 then pathStyle.SolidLipMatA else pathStyle.SolidLipMatB)
					lip.CFrame = CFrame.lookAt(at, at + delta) * CFrame.new(0, 0.07, 0)
				end
			elseif pathStyle and pathStyle.SolidCauseway then
				ramp.Color = flagstone
				ramp.Material = Enum.Material.Cobblestone
				-- Step lips every few studs (flush trim, walked over, never collide) read as a stepped causeway,
				-- and moss creeps in along both edges.
				local length = delta.Magnitude
				local lips = math.max(1, math.floor((length - 4) / 3.2))
				for i = 1, lips do
					local at = a:Lerp(b, (i - 0.5) / lips)
					local lip = decor(model, "RampStepLip", Vector3.new(link.Width - 5.5, 0.16, 0.7), at, flagstoneDark, Enum.Material.Limestone)
					lip.CFrame = CFrame.lookAt(at, at + delta) * CFrame.new(0, 0.07, 0)
				end
				for _, side in { -1, 1 } do
					local edgeAt = mid + right * (side * (link.Width / 2 - 3.1))
					local mossEdge = decor(model, "RampMossEdge", Vector3.new(1.8, 0.2, math.max(1, length - 3)), edgeAt, moss, Enum.Material.Grass)
					mossEdge.CFrame = CFrame.lookAt(edgeAt, edgeAt + delta) * CFrame.new(0, 0.08, 0)
				end
			elseif natural then
				ramp.Color = naturalGrassColor
				if groundPalette then ramp.Material = groundPalette.Ground end
			else
				local inlay = decor(model, "RampPathInlay", Vector3.new(link.Width * 0.55, 0.12, delta.Magnitude), mid, theme.AccentColor, theme.GroundMaterial)
				inlay.CFrame = CFrame.lookAt(mid, b) * CFrame.new(0, 0.14, 0)
			end
		end
		-- Natural floors: a trodden path over a land bridge, with no lanterns or viaduct piers. The curbs stay,
		-- invisible, so heroes keep the same railing they always had. Floor 3 bridges dress curbless with organic root rails.
		if natural then
			local visibleCurb = (pathStyle ~= nil and pathStyle.VisibleCurb == true) and (isSuspendedLink(layout, link.Id) or not grassyPaths)
			local curbLen = math.max(1, delta.Magnitude - 4)
			local curbCol = if not visibleCurb then theme.TrimColor elseif masonryStyle and masonryStyle.CurbColor then masonryStyle.CurbColor else pathStyle.CurbColor
			local curbMat = if not visibleCurb then theme.TrimMaterial elseif masonryStyle and masonryStyle.CurbMaterial then masonryStyle.CurbMaterial else pathStyle.CurbMaterial
			local curbMode = if not visibleCurb then "NONE" elseif masonryStyle and masonryStyle.CurbMode then masonryStyle.CurbMode else "CAP_STRIP"
			for _, side in { -1, 1 } do
				local curbOffset = right * (side * (link.Width / 2 - 1.02))
				local curbGroup = propGroup(model, "BridgeCurb")
				local curb = decor(curbGroup, "BridgeCurb", Vector3.new(2.3, 2.6, curbLen), mid + curbOffset, curbCol, curbMat, if visibleCurb then nil else 1)
				curb.CFrame = CFrame.lookAt(mid + curbOffset, b + curbOffset) * CFrame.new(0, -0.35, 0)
				if visibleCurb then
					if curbMode == "FORTRESS_MERLON" then
						-- Natural weathered sandstone parapet cap plus spaced fortress merlon stones
						local cap = decor(curbGroup, "BridgeSandCap", Vector3.new(2.5, 0.45, math.max(1, curbLen - 1)), mid + curbOffset, Color3.fromRGB(142, 118, 90), Enum.Material.Sandstone)
						cap.CFrame = CFrame.lookAt(mid + curbOffset, b + curbOffset) * CFrame.new(0, 1.15, 0)
						local posts = math.max(2, math.floor(curbLen / 24))
						for pIdx = 1, posts do
							local pt = a:Lerp(b, pIdx / (posts + 1)) + curbOffset
							local merlon = decor(curbGroup, "BridgeFortressMerlon", Vector3.new(2.7, 1.8, 3.6), pt, Color3.fromRGB(168, 138, 100), Enum.Material.Sandstone)
							merlon.CFrame = CFrame.lookAt(pt, b + curbOffset) * CFrame.new(0, 1.4, 0)
						end
					elseif curbMode == "WHITEGUARD_BRIDGE" then
						-- Granite parapet curb with carved end newels, intermediate timber posts, and dual wooden guardrails
						curb.Size = Vector3.new(1.6, 1.5, curbLen)
						curb.CFrame = CFrame.lookAt(mid + curbOffset, b + curbOffset) * CFrame.new(0, -0.05, 0)
						local bridgeWood = Color3.fromRGB(92, 72, 56)
						local railLen = math.max(1, curbLen - 1.2)
						local railTop = decor(curbGroup, "BridgeHandrail", Vector3.new(0.85, 0.65, railLen), mid + curbOffset, bridgeWood, Enum.Material.Wood)
						railTop.CFrame = CFrame.lookAt(mid + curbOffset, b + curbOffset) * CFrame.new(0, 3.05, 0)
						local railMid = decor(curbGroup, "BridgeMidRail", Vector3.new(0.6, 0.45, railLen), mid + curbOffset, bridgeWood, Enum.Material.Wood)
						railMid.CFrame = CFrame.lookAt(mid + curbOffset, b + curbOffset) * CFrame.new(0, 1.75, 0)
						for _, endT in { 0.04, 0.96 } do
							local np = a:Lerp(b, endT) + curbOffset
							local newel = decor(curbGroup, "BridgeNewelPost", Vector3.new(2.4, 4.6, 2.4), np, whiteguardGranite, Enum.Material.Slate)
							newel.CFrame = CFrame.lookAt(np, b + curbOffset) * CFrame.new(0, 1.8, 0)
							local cap = decor(curbGroup, "BridgeNewelCap", Vector3.new(2.8, 0.6, 2.8), np, glacierIceCol, Enum.Material.Ice, 0.1)
							cap.CFrame = CFrame.lookAt(np, b + curbOffset) * CFrame.new(0, 4.35, 0)
						end
						local posts = math.max(1, math.floor(curbLen / 20))
						for pIdx = 1, posts do
							local pt = a:Lerp(b, pIdx / (posts + 1)) + curbOffset
							local post = decor(curbGroup, "BridgeRailPost", Vector3.new(1.1, 3.6, 1.1), pt, bridgeWood, Enum.Material.Wood)
							post.CFrame = CFrame.lookAt(pt, b + curbOffset) * CFrame.new(0, 1.65, 0)
						end
					else
						local capCol = (masonryStyle and masonryStyle.CurbCapColor) or pathStyle.CurbCapColor
						local capMat = (masonryStyle and masonryStyle.CurbCapMaterial) or pathStyle.CurbCapMaterial
						local capTrans = masonryStyle and masonryStyle.CurbCapTransparency
						local cap = decor(curbGroup, "BridgeKerbMoss", Vector3.new(2.5, 0.5, math.max(1, curbLen - 1)), mid + curbOffset, capCol, capMat, capTrans)
						cap.CFrame = CFrame.lookAt(mid + curbOffset, b + curbOffset) * CFrame.new(0, 1.25, 0)
					end
				end
			end
			continue
		end

		for _, side in { -1, 1 } do
			-- On the ramp's edge (not beside it, where nothing holds it up).
			local curbOffset = right * (side * (link.Width / 2 - 1.1))
			local curbGroup = propGroup(model, "BridgeCurb")
			local curb = decor(curbGroup, "BridgeCurb", Vector3.new(2.2, 2.6, math.max(1,delta.Magnitude-4)), mid + curbOffset, theme.TrimColor, theme.TrimMaterial)
			curb.CFrame = CFrame.lookAt(mid + curbOffset, b + curbOffset) * CFrame.new(0, -0.4, 0)
			local glowStrip = decor(curbGroup, "BridgeRuneStrip", Vector3.new(0.45, 0.35, delta.Magnitude - 4), mid + curbOffset, theme.LightColor, Enum.Material.SmoothPlastic, 0.3)
			glowStrip.CFrame = CFrame.lookAt(mid + curbOffset, b + curbOffset) * CFrame.new(0, 0.95, 0)
		end
		for _, frac in { 0.18, 0.82 } do
			local pt = a:Lerp(b, frac)
			for _, side in { -1, 1 } do
				local lampPos = pt + right * (side * (link.Width / 2 - 1.1)) + Vector3.new(0, 1.8, 0)
				local lamp = decor(model, "RampPostLantern", Vector3.new(1.4, 2.2, 1.4), lampPos, theme.LightColor, Enum.Material.SmoothPlastic, 0.15)
				local pl = Instance.new("PointLight")
				pl.Color = theme.LightColor
				pl.Range = 22
				pl.Brightness = 0.55
				pl.Shadows = false
				pl.Parent = lamp
			end
		end
		for _, frac in { 0.28, 0.72 } do
			local pt = a:Lerp(b, frac)
			local pierH = math.max(2, (pt.Y - origin.Y) - layout.Bottom)
			for _, side in { -1, 1 } do
				local pierPos = pt + right * (side * (link.Width / 2 - 2.5)) - Vector3.new(0, pierH / 2 + 1.5, 0)
				decor(model, "ViaductPier", Vector3.new(4.5, pierH, 5.5), pierPos, theme.CliffColor, theme.CliffMaterial)
			end
		end
	end

	for _, link in layout.ReturnLinks do
			local a = origin + Vector3.new(link.AX,link.AY,link.AZ)
			local b = origin + Vector3.new(link.BX,link.BY,link.BZ)
			local ramp = part(model, "BasinReturnRamp", Vector3.new(link.Width, 2, (b - a).Magnitude), (a + b) / 2, if natural then naturalGrassColor else theme.GroundColor, if natural and groundPalette then groundPalette.Ground else theme.GroundMaterial)
			ramp.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, -1, 0)
			if grassyPaths then
				disableTerrainProxyPart(ramp)
				local rDelta = b - a
				local rFlat = Vector3.new(rDelta.X, 0, rDelta.Z)
				local rRight = Vector3.new(-rFlat.Unit.Z, 0, rFlat.Unit.X)
				local stones = math.max(1, math.floor((rDelta.Magnitude - 4) / 5.5))
				for i = 1, stones do
					local stagger = if i % 2 == 0 then 1.4 else -1.4
					local at = a:Lerp(b, (i - 0.5) / stones) + rRight * stagger
					local stone = decor(model, "RampStepLip", Vector3.new(link.Width * 0.34, 0.28, 2.4), at, if pathStyle and pathStyle.ShowVaultLanterns == false then Color3.fromRGB(134, 118, 96) else flagstoneDark, if pathStyle and pathStyle.ShowVaultLanterns == false then Enum.Material.Slate else Enum.Material.Limestone)
					stone.CFrame = CFrame.lookAt(at, at + rDelta) * CFrame.new(0, 0.06, 0)
				end
			end
			structure(ramp,link.Id)
			landing(link.LandingA,link.Id,link.From)
			landing(link.LandingB,link.Id,link.To)
	end

	local field = if natural then TowerTerrain.Build(origin, layout, floorSpec.BiomeId, id) else nil
	if not natural then
		-- A floor built before the kit was imported may have left terrain behind.
		TowerTerrain.Clear(origin, layout)
	end
	BiomeAssets.Build(model, origin, floorSpec.BiomeId, idx, layout, theme, field)

	if not pathStyle or pathStyle.ShowVaultLanterns ~= false then
		for x = -width / 2 + 50, width / 2 - 40, 100 do
			for z = -depth / 2 + 50, depth / 2 - 40, 100 do
				local lamp = decor(model, "VaultLantern", Vector3.new(1, 1, 1), origin + Vector3.new(x, 42, z), theme.LightColor, Enum.Material.SmoothPlastic, 1)
				local light = Instance.new("PointLight")
				light.Range = 60
				light.Brightness = 0.55
				light.Color = theme.LightColor
				light.Shadows = false
				light.Parent = lamp
			end
		end
	end

	-- Sanctuary Arrival Gateway Braziers (welcoming illumination framing safe zone threshold)
	for _, side in { -1, 1 } do
		local torchPos = origin + Vector3.new(side * 24, safe.Y + 3.5, safe.Z - 26)
		decor(model, "ArrivalPortalBrazierPlinth", Vector3.new(3.5, 5.5, 3.5), torchPos, theme.TrimColor, theme.TrimMaterial)
		local flame = decor(model, "ArrivalPortalFlame", Vector3.new(2.2, 2.6, 2.2), torchPos + Vector3.new(0, 3.8, 0), theme.LightColor, Enum.Material.SmoothPlastic, 0.1)
		local pl = Instance.new("PointLight")
		pl.Color = theme.LightColor
		pl.Range = 32
		pl.Brightness = 0.85
		pl.Shadows = false
		pl.Parent = flame
	end

	local landing = model:FindFirstChild("SafeArrival") :: BasePart
	local light = Instance.new("PointLight")
	light.Color = theme.LightColor
	light.Range = 28
	light.Brightness = 0.5
	light.Parent = landing

	-- Loot and relics bank automatically anywhere inside the Sanctuary (CombatSimulation / RelicService
	-- check the ARRIVAL zone's CanBankCargo), so the floor needs no altar or pad in the middle.
	local halfW, halfD = safe.Width / 2, safe.Depth / 2

	for _, side in { -1, 1 } do
		part(model, "SanctuaryPillar", Vector3.new(6, 36, 6), origin + Vector3.new(side * (halfW - 2), 26, safe.Z - halfD + 3), theme.TrimColor, theme.TrimMaterial)
		decor(model, "SanctuaryPillarCap", Vector3.new(8, 3, 8), origin + Vector3.new(side * (halfW - 2), 45, safe.Z - halfD + 3), theme.AccentColor, theme.TrimMaterial)
		decor(model, "SanctuaryPillarLantern", Vector3.new(3, 4.5, 3), origin + Vector3.new(side * (halfW - 2), 48.5, safe.Z - halfD + 3), theme.LightColor, Enum.Material.SmoothPlastic, 0.1)
		decor(model, "SanctuarySideWall", Vector3.new(2.5, 4.5, safe.Depth - 8), origin + Vector3.new(side * (halfW - 1), 10.2, safe.Z), theme.TrimColor, theme.TrimMaterial, if natural then 1 else nil)
	end

	-- Phase H: a glowing square traces the ARRIVAL zone exactly (the Sanctuary's footprint), on a darker
	-- trim band, with a gap in the front edge for the exit, framed by two small pylons.
	local rimY = safe.Y + 0.18
	local glowColor = theme.LightColor
	local bandColor = if natural then moss else theme.TrimColor:Lerp(Color3.new(0, 0, 0), 0.45)
	local bandMat = if natural then Enum.Material.Grass else theme.TrimMaterial
	local rimTrans = if grassyPaths then 1 elseif natural then 0.72 else 0.1
	local bandTrans = if grassyPaths then 1 else nil
	local function rim(name: string, size: Vector3, at: Vector3)
		decor(model, name .. "Band", Vector3.new(size.X + 1.2, 0.25, size.Z + 1.2), origin + at - Vector3.new(0, 0.06, 0), bandColor, bandMat, bandTrans)
		decor(model, name, size, origin + at, glowColor, Enum.Material.Neon, rimTrans)
	end
	for _, side in { -1, 1 } do
		rim("SanctuaryRimSide", Vector3.new(1.2, 0.35, safe.Depth), Vector3.new(side * halfW, rimY, safe.Z))
		rim("SanctuaryRimBack", Vector3.new(halfW, 0.35, 1.2), Vector3.new(side * halfW / 2, rimY, safe.Z + halfD))
		rim("SanctuaryRimFront", Vector3.new(halfW - 18, 0.35, 1.2), Vector3.new(side * (halfW + 18) / 2, rimY, safe.Z - halfD))
		decor(model, "SanctuaryGatePylon", Vector3.new(2.2, 3.2, 2.2), origin + Vector3.new(side * 18, safe.Y + 1.6, safe.Z - halfD), theme.TrimColor, theme.TrimMaterial)
		decor(model, "SanctuaryGateGem", Vector3.new(1.4, 1.4, 1.4), origin + Vector3.new(side * 18, safe.Y + 3.9, safe.Z - halfD), glowColor, Enum.Material.Neon, 0.1)
	end
	-- Corner beacons: a pylon with a crystal cap and a faint light column up to the skylight, so the
	-- Sanctuary can be found from anywhere on the floor.
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local frontOffset = if sz < 0 then Vector3.new(sx * 1.6, 0, -1.6) else Vector3.zero
			local at = Vector3.new(sx * halfW, safe.Y, safe.Z + sz * halfD) + frontOffset
			decor(model, "SanctuaryBeaconPylon", Vector3.new(2.8, 3.9, 2.8), origin + at + Vector3.new(0, 1.95, 0), theme.TrimColor, theme.TrimMaterial)
			local crystal = decor(model, "SanctuaryBeaconCrystal", Vector3.new(1.8, 2.6, 1.8), origin + at + Vector3.new(0, 5.3, 0), glowColor, Enum.Material.Neon, 0.05)
			crystal.CFrame *= CFrame.Angles(0, math.rad(45), 0)
			local light = Instance.new("PointLight")
			light.Color, light.Range, light.Brightness = glowColor, 18, 1
			light.Parent = crystal
			local columnHeight = height - safe.Y - 6
			local column = decor(model, "SanctuaryBeaconColumn", Vector3.new(1.5, columnHeight, 1.5), origin + at + Vector3.new(0, 6.6 + columnHeight / 2, 0), glowColor, Enum.Material.SmoothPlastic, 0.75)
			column.CastShadow = false
		end
	end
	local labelAnchor = decor(model, "SanctuaryLabelAnchor", Vector3.new(1, 1, 1), origin + Vector3.new(0, safe.Y + 9, safe.Z - halfD), glowColor, Enum.Material.SmoothPlastic, 1)
	local sanctuaryLabel = Instance.new("BillboardGui")
	sanctuaryLabel.Name = "SanctuaryLabel"
	sanctuaryLabel.Size = UDim2.fromOffset(190, 34)
	sanctuaryLabel.MaxDistance = 160
	sanctuaryLabel.LightInfluence = 0
	sanctuaryLabel.Parent = labelAnchor
	local sanctuaryText = Instance.new("TextLabel")
	sanctuaryText.Size = UDim2.fromScale(1, 1)
	sanctuaryText.BackgroundTransparency = 1
	sanctuaryText.Font = Enum.Font.GothamBold
	sanctuaryText.TextScaled = true
	sanctuaryText.TextColor3 = glowColor
	sanctuaryText.TextStrokeTransparency = 0.4
	sanctuaryText.Text = "SANCTUARY"
	sanctuaryText.Parent = sanctuaryLabel

	-- Phase H: the four travel stations are portals (TowerPortalKit). Each keeps its trigger named for its
	-- action and its prompt's TowerAction attribute, so TowerController is unchanged.
	local portalStone, portalGold = PortalKit.Palette(theme)
	local portalGlow = {
		PREVIOUS = theme.LightColor:Lerp(Color3.new(0, 0, 0), 0.4),
		NEXT = theme.LightColor,
		SELECTOR = Color3.fromRGB(255, 214, 120),
		HUB = Color3.fromRGB(240, 244, 255),
	}
	for i, action in { "PREVIOUS", "NEXT", "SELECTOR", "HUB" } do
		local pedX = (i - 2.5) * PortalAssets.SanctuarySpacing
		local dormant = (action == "PREVIOUS" and id == 1) or (action == "NEXT" and id == 50)
		local _, p = PortalKit.Build(model, CFrame.new(origin + Vector3.new(pedX, safe.Y, safe.Z + 20)), {
			Name = "TravelPortal_" .. action,
			TriggerName = action,
			Scale = PortalAssets.SanctuaryScale,
			Glow = portalGlow[action],
			Stone = portalStone,
			Gold = portalGold,
			StoneMaterial = theme.TrimMaterial,
			Dormant = dormant,
		})
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
		bg.StudsOffset = Vector3.new(0, 6.5 * PortalAssets.SanctuaryScale / 0.8, 0)
		bg.AlwaysOnTop = false
		bg.MaxDistance = 50
		bg.Parent = p
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(1, 1)
		-- No plate: outlined text only.
		lbl.BackgroundTransparency = 1
		lbl.TextColor3 = Color3.fromRGB(245, 235, 225)
		lbl.Font = Enum.Font.GothamBold
		lbl.TextSize = 15
		lbl.TextStrokeColor3 = Color3.fromRGB(10, 6, 14)
		lbl.TextStrokeTransparency = 0
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
	local plaque = decor(model, "FloorTitlePlaque", Vector3.new(96, 14, 1), origin + Vector3.new(0, height - 18, -depth / 2 + 8), theme.CliffColor, theme.TrimMaterial, 0.25)
	sign.Parent = plaque
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


 -- Keep solid scenery out of the authored walking lanes and enemy camps.
 -- Previously these props overlapped ramps but were ghosts; omit conflicting
 -- pieces now that their visible surfaces have real collision.
 local clearancePoints = {}
 for _,link in layout.Links do
  local a = Vector3.new(link.AX,link.AY,link.AZ)
  local b = Vector3.new(link.BX,link.BY,link.BZ)
  for step=0,math.ceil((b-a).Magnitude/3) do
   table.insert(clearancePoints,origin+a:Lerp(b,step/math.ceil((b-a).Magnitude/3))+Vector3.new(0,2.5,0))
  end
 end
 for _,placement in Layout.Placements(require(game.ReplicatedStorage.Shared.Config.MobCatalog).Biomes[math.ceil(id/5)],idx,id) do
  table.insert(clearancePoints,origin+Vector3.new(placement.X,placement.Y+2.5,placement.Z))
 end
 -- A solid part in the way removes its whole prop (TowerPropClearance), so nothing is left floating.
 local function inLane(p: BasePart): boolean
  if not p:GetAttribute("SolidScenery") then return false end
  for _,point in clearancePoints do
   local at = p.CFrame:PointToObjectSpace(point)
   local half = p.Size/2 + Vector3.new(3,2,3)
   if math.abs(at.X)<half.X and math.abs(at.Y)<half.Y and math.abs(at.Z)<half.Z then
    return true
   end
  end
  return false
 end
 -- Scenery standing on a walkway goes too (whole), solid or not: the ramps and paths stay clear.
 local onWalkway = Builder.WalkwayHitTest(model, origin, idx)
 local function blocksLane(p: BasePart): boolean
  return inLane(p) or onWalkway(p)
 end
 local laneCleared = PropClearance.Apply(model, blocksLane)

	local folder = workspace:FindFirstChild("TowerRooms") or Instance.new("Folder")
	folder.Name = "TowerRooms"
	folder.Parent = workspace
	local existing = folder:FindFirstChild(model.Name)
	if existing then
		existing:Destroy()
	end
	model.Parent = folder

	-- No prop floats: lower anything hovering onto the support under it (settling raycasts, so the room
	-- is in the Workspace now). A lowered prop can land in a camp or lane, so clear both again after.
	local lowered, dropped = PropClearance.Settle(model, BiomeAssets.AirborneKinds, 1.5, 80)
	local kit = model:FindFirstChild("BiomeAssets")
	if kit then
		kit:SetAttribute("PropsClearedForCamps", (kit:GetAttribute("PropsClearedForCamps") or 0) + PropClearance.Apply(kit, BiomeAssets.CampHitTest(origin, layout)))
	end
	laneCleared += PropClearance.Apply(model, blocksLane)
	model:SetAttribute("PropsClearedForLanes", laneCleared)
	model:SetAttribute("PropsLowered", lowered)
	model:SetAttribute("PropsDroppedUnsupported", dropped)
	-- After settling: the settle raycasts and lane checks are done, so trim engine work on the scenery.
	StaticGeometry.Apply(model)

	return {
		FloorId = id,
		RoomGeneration = generation,
		Origin = origin,
		Model = model,
		Arrival = CFrame.new(origin + Vector3.new(0, 11.5, safe.Z - 12)),
		Bounds = { Min = Vector3.new(-width / 2, -16, -depth / 2), Max = Vector3.new(width / 2, height + 24, depth / 2) },
		Zones = {
			{
				ZoneId = "ARRIVAL",
				FloorId = id,
				RoomGeneration = generation,
				LocalPolygonXZ = {
					Vector2.new(-safe.Width / 2, safe.Z - safe.Depth / 2),
					Vector2.new(safe.Width / 2, safe.Z - safe.Depth / 2),
					Vector2.new(safe.Width / 2, safe.Z + safe.Depth / 2),
					Vector2.new(-safe.Width / 2, safe.Z + safe.Depth / 2),
				},
				MinY = 7,
				MaxY = 23,
				CombatSafe = true,
				CanBankCargo = true,
				CanRecoverWipe = true,
			},
		},
	}
end

return Builder
