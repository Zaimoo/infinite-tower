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
local WalkwayExemptKinds = { BridgeCurb = true, RampArch = true, HollinStile = true, GlassArchSpan = true, PortcullisGate = true, KitCaravanseraiSkylight = true, ElderForearmGuard = true, ElderUpperArmGuard = true }
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
	if layout.Authored == "fungal:9" then
		-- Floor 9 (Rotcap Keep): replace default cyan accents with sickly yellow-green rot mixed into violet.
		theme = table.clone(theme)
		theme.LightColor = Color3.fromRGB(182, 245, 74)
		theme.AccentColor = Color3.fromRGB(138, 72, 224)
		theme.LiquidColor = Color3.fromRGB(128, 196, 58)
		theme.HorizonColor = Color3.fromRGB(172, 232, 84)
	end
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

	-- Hand-authored floors whose terraces and ramps are the terrain itself (TowerLayout `Terrain.Direct`):
	-- natural terraces, landings and ramps keep their parts only as invisible, non-colliding proxies, while
	-- built decks (`Terrain.Decks`) stay solid, visible masonry (TowerTerrain keeps a voxel under them).
	local td = layout.Terrain
	local direct = natural and td ~= nil and td.Direct == true
	local deckIds = if direct then td.Decks or {} else {}
	local deckThickness = if direct then td.DeckThickness or {} else {}
	-- Round decks (`Terrain.RoundDecks`: a cap top) and hung walkways (`Terrain.Bridges`: rope and plank).
	local roundDecks = if direct then td.RoundDecks or {} else {}
	local hungLinks = if direct then td.Bridges or {} else {}
	local plank = Color3.fromRGB(104, 80, 62)
	local plankDark = Color3.fromRGB(70, 54, 44)
	local rope = Color3.fromRGB(150, 128, 96)
	local capTop = Color3.fromRGB(98, 60, 176)
	local proxy = disableTerrainProxyPart
	-- Velmari masonry (Fungal Hollow's lamp-masons): indigo slate decks and stairs, violet cobble.
	local velmari = natural and layout.PathStyle == "VELMARI"
	-- Hollin work (Corrupted Grove's grove-wardens): mossy fieldstone treads and pavers, per-deck looks
	-- (`Terrain.DeckLooks`), and hung walkways that can be a fallen log instead of planks (`Terrain.BridgeStyles`).
	local hollin = natural and layout.PathStyle == "HOLLIN"
	local deckLooks = if direct then td.DeckLooks or {} else {}
	local bridgeStyles = if direct then td.BridgeStyles or {} else {}
	local fieldstone = Color3.fromRGB(112, 104, 90)
	local fieldstoneDark = Color3.fromRGB(78, 72, 64)
	local logBark = Color3.fromRGB(62, 48, 40)
	local logWood = Color3.fromRGB(128, 98, 70)
	local matriarchHollow = layout.Authored == "fungal:10"
	local webCable = Color3.fromRGB(218, 206, 242)
	local slateIndigo = Color3.fromRGB(62, 56, 94)
	local slateDark = Color3.fromRGB(42, 38, 66)

	-- Vaulted ceiling with natural environmental skylight aperture (allows sunlight & sunrays to enter)
	local skyFraction = if isDirectTerrainLayout(layout) then 0.82 else 0.54
	local openW = width * skyFraction
	local openD = depth * skyFraction
	local borderX = (width - openW) / 2
	local borderZ = (depth - openD) / 2
	local sky = layout.Skylight
	if sky then
		-- A closed cavern vault pierced by one round oculus (an authored floor's Skylight). Four slabs leave
		-- a square hole round it and a ring of blocks rounds the hole off; the oculus rim carries the hanging
		-- roots (TowerBiomeAssets), and the shaft below is the floor's only daylight.
		local r = sky.Radius
		local x0, x1, z0, z1 = -width / 2 - 6, width / 2 + 6, -depth / 2 - 6, depth / 2 + 6
		local function vault(name: string, ax: number, bx: number, az: number, bz: number)
			if bx - ax > 0.5 and bz - az > 0.5 then
				-- Casts shadows: underground, daylight only comes in through the oculus.
				local slab = decor(model, name, Vector3.new(bx - ax, 6, bz - az), origin + Vector3.new((ax + bx) / 2, height + 3, (az + bz) / 2), theme.WallColor, theme.WallMaterial)
				slab.CastShadow = true
			end
		end
		vault("VaultCeilingZ", x0, x1, z0, sky.Z - r)
		vault("VaultCeilingZ", x0, x1, sky.Z + r, z1)
		vault("VaultCeilingX", x0, sky.X - r, sky.Z - r, sky.Z + r)
		vault("VaultCeilingX", sky.X + r, x1, sky.Z - r, sky.Z + r)
		local segments = 20
		for i = 0, segments - 1 do
			local a = (i + 0.5) * math.pi * 2 / segments
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local centre = origin + Vector3.new(sky.X, height + 3, sky.Z) + dir * (r + 13)
			local block = decor(model, "VaultOculusRing", Vector3.new(2 * math.pi * (r + 26) / segments * 1.15, 6, 26), centre, theme.WallColor, theme.WallMaterial)
			block.CFrame = CFrame.lookAt(centre, centre + dir)
			block.CastShadow = true
			local rimAt = origin + Vector3.new(sky.X, height - 0.5, sky.Z) + dir * (r + 1.5)
			local rim = decor(model, "OculusRim", Vector3.new(2 * math.pi * r / segments * 1.12, 3, 4), rimAt, theme.CliffColor, theme.CliffMaterial)
			rim.CFrame = CFrame.lookAt(rimAt, rimAt + dir)
		end
	else
		-- Vaulted ceiling with natural environmental skylight aperture (allows sunlight & sunrays to enter)
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
	end

	-- High-altitude natural skylight light source (casts soft sunlight/skylight down across the room)
	local sunShaft = Instance.new("Part")
	sunShaft.Name = "NaturalSkylightShaft"
	sunShaft.Size = Vector3.new(openW * 0.7, 2, openD * 0.7)
	sunShaft.Position = origin + if sky then Vector3.new(sky.X, height + 8, sky.Z) else Vector3.new(0, height + 8, -depth * 0.05)
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
	if sky then
		-- The oculus: a narrower, paler shaft straight down onto the floor beneath it.
		naturalSpot.Angle = 48
		naturalSpot.Brightness = 2.2
		naturalSpot.Color = if layout.Authored == "fungal:9" then Color3.fromRGB(186, 245, 92)
			elseif layout.Authored == "infernal:2" then Color3.fromRGB(255, 214, 160) -- smoky daylight through the hall's oculus
			else Color3.fromRGB(176, 238, 255)
	end
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
	-- Sootwright (Infernal Foundry) iron, soot brick, brass and rail timber.
	local sootIron = Color3.fromRGB(70, 64, 64)
	local sootIronDark = Color3.fromRGB(44, 40, 42)
	local sootBrick = Color3.fromRGB(92, 56, 46)
	local sootBrickDark = Color3.fromRGB(62, 40, 36)
	local sootBrass = Color3.fromRGB(150, 112, 58)
	local sootRust = Color3.fromRGB(112, 62, 40)
	local railTimber = Color3.fromRGB(58, 44, 36)
	local railSteel = Color3.fromRGB(128, 122, 118)

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
		WHITEGUARD = {
			CurbColor = whiteguardGranite,
			CurbMaterial = Enum.Material.Slate,
			CurbCapColor = whiteguardIron,
			CurbCapMaterial = Enum.Material.Metal,
			StairColorA = whiteguardGranite,
			StairColorB = Color3.fromRGB(168, 212, 238),
			StairMatA = Enum.Material.Slate,
			StairMatB = Enum.Material.Ice,
		},
		WHITEGUARD_FORTRESS = {
			DeckKind = "WHITEGUARD_FORTRESS",
			LandingProxy = true,
			BridgeKind = "WHITEGUARD_VIADUCT",
			CurbColor = whiteguardGranite,
			CurbMaterial = Enum.Material.Slate,
			CurbMode = "WHITEGUARD_MERLON",
			StairColorA = whiteguardGranite,
			StairColorB = Color3.fromRGB(168, 212, 238),
			StairMatA = Enum.Material.Slate,
			StairMatB = Enum.Material.Ice,
		},
		THRONE_HALL = {
			DeckKind = "THRONE_HALL",
			LandingProxy = true,
			BridgeKind = "WHITEGUARD_VIADUCT",
			StairUnder = true,
			StairUnderHeight = 3.2,
			StairUnderY = -2.6,
			CurbColor = whiteguardGranite,
			CurbMaterial = Enum.Material.Slate,
			CurbMode = "WHITEGUARD_MERLON",
			StairColorA = whiteguardGranite,
			StairColorB = Color3.fromRGB(168, 212, 238),
			StairMatA = Enum.Material.Slate,
			StairMatB = Enum.Material.Ice,
		},
		-- Floor 21 (Sootwright): riveted diamond-plate decks on soot-brick plinths, an iron gantry under a
		-- suspended deck, girder bridges with rails, and iron stair treads with brass nosing.
		FOUNDRY_IRON = {
			DeckKind = "FOUNDRY_IRON",
			-- Landings stay flush, invisible colliders: the deck (and the turntable laid on it) shows through.
			LandingProxy = true,
			BridgeKind = "FOUNDRY_GIRDER",
			CurbColor = sootIronDark,
			CurbMaterial = Enum.Material.Metal,
			CurbMode = "FOUNDRY_RAIL",
			StairColorA = sootIron,
			StairColorB = sootIronDark,
			StairMatA = Enum.Material.DiamondPlate,
			StairMatB = Enum.Material.Metal,
			StairNosing = sootBrass,
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
			GrassStepLipWBase = 0.44,
			GrassStepLipWStep = 0.06,
			GrassStepLipWMod = 5,
			GrassStepLipH = 0.30,
			GrassStepLipY = 0.03,
			GrassTrailKerbs = true,
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
		-- Floor 21 (Sootwright): every earthen ramp is a rail spur, timber sleepers laid across it under a
		-- pair of steel rails (RailInlay); kerbs are riveted iron.
		SOOTWRIGHT = {
			VisibleCurb = true,
			CurbColor = sootIronDark,
			CurbMaterial = Enum.Material.Metal,
			CurbCapColor = sootBrass,
			CurbCapMaterial = Enum.Material.Metal,
			LandingColor = sootIron,
			LandingMaterial = Enum.Material.DiamondPlate,
			StairColorA = sootIron,
			StairColorB = sootIronDark,
			StairMatA = Enum.Material.DiamondPlate,
			StairMatB = Enum.Material.Metal,
			GrassStepLipColorA = railTimber,
			GrassStepLipColorB = Color3.fromRGB(46, 36, 32),
			GrassStepLipMatA = Enum.Material.Wood,
			GrassStepLipMatB = Enum.Material.Wood,
			GrassStepLipWBase = 0.42,
			GrassStepLipWStep = 0.03,
			GrassStepLipWMod = 1,
			GrassStepLipH = 0.4,
			GrassStepLipY = 0.04,
			GrassStepLipStep = 3.6,
			GrassStepLipStagger = 0,
			RailInlay = true,
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
		if direct and deckIds[name] then
			-- Built masonry: a solid, visible deck (thin over water when the floor says so, e.g. a bridge).
			local t = deckThickness[name]
			if roundDecks[name] then
				-- A cap top: a disc through the terrace's corners (it covers the whole terrace), its rim, gills and
				-- stem dressed by TowerBiomeAssets.
				local diameter = math.sqrt(terrace.Width ^ 2 + terrace.Depth ^ 2) + 2
				local thick = t or 3
				slab.Shape = Enum.PartType.Cylinder
				slab.Size = Vector3.new(thick, diameter, diameter)
				slab.CFrame = CFrame.new(topCenter - Vector3.new(0, thick / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
				slab.Color = capTop
				slab.Material = Enum.Material.SmoothPlastic
				continue
			end
			if t then
				slab.Size = Vector3.new(terrace.Width, t, terrace.Depth)
				slab.Position = topCenter - Vector3.new(0, t / 2, 0)
			end
			if velmari and name ~= "Sanctuary" then
				slab.Color = slateIndigo
				slab.Material = Enum.Material.Slate
			end
			local look = deckLooks[name] or (if hollin and name == "Sanctuary" then { Color = fieldstone, Material = Enum.Material.Slate } else nil)
			if look then
				slab.Color = look.Color
				slab.Material = look.Material
			end
			continue
		elseif direct then
			-- Natural ground: the terrain is the walking surface; the part only keeps the terrace's metadata.
			proxy(slab)
			continue
		end
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
				elseif deckKind == "WHITEGUARD_FORTRESS" or deckKind == "THRONE_HALL" then
					-- Floors 19-20 Whiteguard Keep / Frostbound Throne Cathedral: blue-grey granite courses extending into chasm + corner piers + flagstones + Nave/Dais Ward-Star medallion
					local deepBottom = origin.Y + layout.Bottom - 7
					local wallH = math.max(4, (origin.Y + terrace.Y) - deepBottom)
					slab.Size = Vector3.new(terrace.Width, wallH, terrace.Depth)
					slab.Position = Vector3.new(topCenter.X, topCenter.Y - wallH / 2, topCenter.Z)
					slab.Color = whiteguardGranite
					slab.Material = Enum.Material.Slate
					for _, sz in { -1, 1 } do
						decor(model, "WhiteguardCorniceZ", Vector3.new(terrace.Width + 1.8, 2.0, 1.8), topCenter + Vector3.new(0, -1.6, sz * (terrace.Depth / 2 + 0.15)), whiteguardIron, Enum.Material.Metal)
					end
					for _, sx in { -1, 1 } do
						decor(model, "WhiteguardCorniceX", Vector3.new(1.8, 2.0, math.max(1, terrace.Depth - 1.4)), topCenter + Vector3.new(sx * (terrace.Width / 2 + 0.15), -1.6, 0), whiteguardIron, Enum.Material.Metal)
						for _, sz in { -1, 1 } do
							local cp = Vector3.new(topCenter.X + sx * (terrace.Width / 2 - 2.4), topCenter.Y - wallH / 2 - 0.16, topCenter.Z + sz * (terrace.Depth / 2 - 2.4))
							local cornerPier = part(model, "WhiteguardCornerPier", Vector3.new(6.8, wallH - 0.16, 6.8), cp, whiteguardGraniteDark, Enum.Material.Slate, true)
							cornerPier.CanQuery = true
							cornerPier.CanTouch = false
						end
					end
					if deckKind == "THRONE_HALL" and (name == "Crossing" or name == "Apex") then
						local medDia = math.min(terrace.Width, terrace.Depth) * (if name == "Apex" then 0.56 else 0.52)
						flatDisc("ThroneWardRing", topCenter + Vector3.new(0, 0.05, 0), medDia, 0.08, whiteguardGraniteDark, Enum.Material.Slate)
						flatDisc("ThroneWardFrostDisc", topCenter + Vector3.new(0, 0.08, 0), medDia * 0.84, 0.08, Color3.fromRGB(162, 208, 236), Enum.Material.Ice)
						flatDisc("ThroneWardInnerCore", topCenter + Vector3.new(0, 0.11, 0), medDia * 0.72, 0.08, whiteguardGranite, Enum.Material.Slate)
						for rIdx = 0, 2 do
							local starBar = decor(model, "ThroneWardStarRay", Vector3.new(medDia * 0.76, 0.09, 2.2), topCenter + Vector3.new(0, 0.13, 0), Color3.fromRGB(196, 228, 248), Enum.Material.Ice)
							starBar.CFrame = CFrame.new(topCenter + Vector3.new(0, 0.13, 0)) * CFrame.Angles(0, math.rad(rIdx * 60), 0)
						end
					end
					for k = 1, 7 do
						local ang = k * 2.0 + terrace.X * 0.02
						local rx = math.cos(ang) * (terrace.Width * 0.34)
						local rz = math.sin(ang) * (terrace.Depth * 0.32)
						local pPos = topCenter + Vector3.new(rx, 0.12 + k * 0.025, rz)
						local paver = decor(model, "WhiteguardFlagstone", Vector3.new(8.5 + (k % 3) * 2.0, 0.10, 6.5 + ((k + 1) % 3) * 1.5), pPos, if k % 2 == 0 then whiteguardGranite else whiteguardGraniteDark, Enum.Material.Slate)
						paver.CFrame = CFrame.new(pPos) * CFrame.Angles(0, math.rad((k * 19) % 24 - 12), 0)
					end
				elseif deckKind == "FOUNDRY_IRON" then
					-- Floor 21 Sootwright decks: a diamond-plate iron top with a riveted cornice. A grounded deck stands
					-- on a soot-brick plinth into the yard; a suspended one (the Ore Crusher) on an iron gantry.
					local suspendedDeck = layout.Suspended and layout.Suspended.Platforms and layout.Suspended.Platforms[name]
					local deepBottom = origin.Y + layout.Bottom - 7
					local fullH = math.max(4, (origin.Y + terrace.Y) - deepBottom)
					local slabH = if suspendedDeck then 3.2 else fullH
					slab.Size = Vector3.new(terrace.Width, slabH, terrace.Depth)
					slab.Position = Vector3.new(topCenter.X, topCenter.Y - slabH / 2, topCenter.Z)
					slab.Color = sootIron
					slab.Material = Enum.Material.DiamondPlate
					-- Riveted iron cornice round the top edge, brass rivet heads every few studs.
					for _, sz in { -1, 1 } do
						decor(model, "FoundryCorniceZ", Vector3.new(terrace.Width + 1.6, 1.6, 1.4), topCenter + Vector3.new(0, -0.95, sz * (terrace.Depth / 2 + 0.2)), sootIronDark, Enum.Material.Metal)
					end
					for _, sx in { -1, 1 } do
						decor(model, "FoundryCorniceX", Vector3.new(1.4, 1.6, math.max(1, terrace.Depth - 1.2)), topCenter + Vector3.new(sx * (terrace.Width / 2 + 0.2), -0.95, 0), sootIronDark, Enum.Material.Metal)
					end
					local function rivets(ax: number, az: number, bx: number, bz: number, ox: number, oz: number)
						local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
						local count = math.max(2, math.floor(len / 7))
						for r = 0, count do
							local t = r / count
							local at = topCenter + Vector3.new(ax + (bx - ax) * t + ox, -0.95, az + (bz - az) * t + oz)
							decor(model, "FoundryRivet", Vector3.new(0.7, 0.7, 0.7), at, sootBrass, Enum.Material.Metal).Shape = Enum.PartType.Ball
						end
					end
					rivets(-terrace.Width / 2, terrace.Depth / 2, terrace.Width / 2, terrace.Depth / 2, 0, 0.95)
					rivets(-terrace.Width / 2, -terrace.Depth / 2, terrace.Width / 2, -terrace.Depth / 2, 0, -0.95)
					rivets(-terrace.Width / 2, -terrace.Depth / 2, -terrace.Width / 2, terrace.Depth / 2, -0.95, 0)
					rivets(terrace.Width / 2, -terrace.Depth / 2, terrace.Width / 2, terrace.Depth / 2, 0.95, 0)
					local stoneDeck = suspendedDeck and layout.StonePiers ~= nil and layout.StonePiers[name] == true
					if stoneDeck then
						-- Floor 23's causeway: soot-brick piers with basalt cutwaters rising from the lava under a deep
						-- brick spandrel, iron bands at the top.
						local pierTop = topCenter.Y - slabH
						decor(model, "CausewaySpandrelZ", Vector3.new(terrace.Width - 2, 5, terrace.Depth - 2), Vector3.new(topCenter.X, pierTop - 2.5, topCenter.Z), sootBrickDark, Enum.Material.Brick)
						local rows = math.max(2, math.floor(terrace.Depth / 34) + 1)
						for iz = 0, rows - 1 do
							local cz = topCenter.Z - terrace.Depth / 2 + 8 + (terrace.Depth - 16) * iz / (rows - 1)
							for _, sx in { -1, 1 } do
								local cx = topCenter.X + sx * (terrace.Width / 2 - 8)
								local h = (pierTop - 5) - deepBottom
								local pier = part(model, "CausewayPier", Vector3.new(11, h, 11), Vector3.new(cx, deepBottom + h / 2, cz), sootBrick, Enum.Material.Brick, true)
								pier.CanQuery = true
								pier.CanTouch = false
								decor(model, "CausewayCutwater", Vector3.new(13, 6, 13), Vector3.new(cx, deepBottom + 6, cz), Color3.fromRGB(40, 36, 38), Enum.Material.Basalt)
								decor(model, "CausewayPierBand", Vector3.new(11.6, 1.2, 11.6), Vector3.new(cx, pierTop - 6, cz), sootIronDark, Enum.Material.Metal)
							end
						end
					elseif suspendedDeck then
						-- The gantry: solid iron columns down to the yard with cross-bracing and deep edge girders.
						local colH = (topCenter.Y - slabH) - deepBottom
						local cols: { Vector3 } = {}
						local nx = math.max(2, math.floor(terrace.Width / 22) + 1)
						local nz = math.max(2, math.floor(terrace.Depth / 22) + 1)
						for ix = 0, nx - 1 do
							for iz = 0, nz - 1 do
								if ix == 0 or iz == 0 or ix == nx - 1 or iz == nz - 1 then
									local cx = topCenter.X - terrace.Width / 2 + 3 + (terrace.Width - 6) * ix / (nx - 1)
									local cz = topCenter.Z - terrace.Depth / 2 + 3 + (terrace.Depth - 6) * iz / (nz - 1)
									local colPos = Vector3.new(cx, deepBottom + colH / 2, cz)
									local col = part(model, "FoundryGantryColumn", Vector3.new(3, colH, 3), colPos, sootIronDark, Enum.Material.Metal, true)
									col.CanQuery = true
									col.CanTouch = false
									decor(model, "FoundryGantryFoot", Vector3.new(5, 1.6, 5), Vector3.new(cx, deepBottom + 4.2, cz), sootBrickDark, Enum.Material.Brick)
									table.insert(cols, colPos)
								end
							end
						end
						for _, sz in { -1, 1 } do
							decor(model, "FoundryGantryGirderZ", Vector3.new(terrace.Width, 3.4, 1.6), topCenter + Vector3.new(0, -slabH - 1.7, sz * (terrace.Depth / 2 - 3)), sootIronDark, Enum.Material.Metal)
						end
						for _, sx in { -1, 1 } do
							decor(model, "FoundryGantryGirderX", Vector3.new(1.6, 3.4, terrace.Depth), topCenter + Vector3.new(sx * (terrace.Width / 2 - 3), -slabH - 1.7, 0), sootIronDark, Enum.Material.Metal)
						end
						-- X-bracing between neighbouring edge columns (two tiers).
						for i, c in cols do
							for j = i + 1, #cols do
								local o = cols[j]
								local gap = Vector3.new(o.X - c.X, 0, o.Z - c.Z).Magnitude
								if gap > 1 and gap < 26 and (math.abs(o.X - c.X) < 0.5 or math.abs(o.Z - c.Z) < 0.5) then
									for tier = 0, 1 do
										local y0 = deepBottom + 6 + tier * (colH - 8) * 0.5
										local y1 = y0 + (colH - 8) * 0.5
										for _, flip in { 0, 1 } do
											local p0 = Vector3.new(c.X, if flip == 0 then y0 else y1, c.Z)
											local p1 = Vector3.new(o.X, if flip == 0 then y1 else y0, o.Z)
											local brace = decor(model, "FoundryGantryBrace", Vector3.new(0.7, 0.7, (p1 - p0).Magnitude), (p0 + p1) / 2, sootIronDark, Enum.Material.Metal)
											brace.CFrame = CFrame.lookAt((p0 + p1) / 2, p1)
										end
									end
								end
							end
						end
					else
						-- Soot-brick plinth skirts below the cornice, with iron corner posts.
						for _, sz in { -1, 1 } do
							decor(model, "FoundryBrickSkirtZ", Vector3.new(terrace.Width + 0.6, fullH - 1.8, 0.8), Vector3.new(topCenter.X, deepBottom + (fullH - 1.8) / 2, topCenter.Z + sz * (terrace.Depth / 2 + 0.2)), sootBrick, Enum.Material.Brick)
						end
						for _, sx in { -1, 1 } do
							decor(model, "FoundryBrickSkirtX", Vector3.new(0.8, fullH - 1.8, terrace.Depth - 0.2), Vector3.new(topCenter.X + sx * (terrace.Width / 2 + 0.2), deepBottom + (fullH - 1.8) / 2, topCenter.Z), sootBrick, Enum.Material.Brick)
							for _, sz in { -1, 1 } do
								local cp = Vector3.new(topCenter.X + sx * (terrace.Width / 2 - 1.6), deepBottom + (fullH - 0.2) / 2, topCenter.Z + sz * (terrace.Depth / 2 - 1.6))
								local corner = part(model, "FoundryCornerPost", Vector3.new(4.2, fullH - 0.2, 4.2), cp, sootIronDark, Enum.Material.Metal, true)
								corner.CanQuery = true
								corner.CanTouch = false
							end
						end
					end
					local function flatRail(name: string, p0: Vector3, p1: Vector3, width: number, height: number, col: Color3, mat: Enum.Material)
						local railPart = decor(model, name, Vector3.new(width, height, math.max(0.2, (p1 - p0).Magnitude)), (p0 + p1) / 2, col, mat)
						railPart.CFrame = CFrame.lookAt((p0 + p1) / 2, p1)
						return railPart
					end
					if name == "Crossing" and layout.Authored == "infernal:2" then
						-- Floor 22's Crane Trolley: crane rails across the deck along the girder, hatch plates, and under
						-- the deck the twin winch drums and the hook block hanging toward the yard (all decor, never solid).
						for _, side in { -1, 1 } do
							flatRail("TrolleyCraneRail", topCenter + Vector3.new(-terrace.Width / 2 + 1, 0.2, side * 2.6), topCenter + Vector3.new(terrace.Width / 2 - 1, 0.2, side * 2.6), 0.45, 0.32, railSteel, Enum.Material.Metal)
							decor(model, "TrolleyHatchPlate", Vector3.new(14, 0.1, 9), topCenter + Vector3.new(side * 22, 0.07, -terrace.Depth / 2 + 8), sootIronDark, Enum.Material.DiamondPlate)
						end
						local under = topCenter.Y - slabH
						for _, side in { -1, 1 } do
							local drum = decor(model, "TrolleyWinchDrum", Vector3.new(24, 7, 7), Vector3.new(topCenter.X + side * 15, under - 4.2, topCenter.Z), sootIron, Enum.Material.Metal)
							drum.Shape = Enum.PartType.Cylinder
							for _, ex in { -12.4, 12.4 } do
								local flange = decor(model, "TrolleyDrumFlange", Vector3.new(0.8, 9, 9), Vector3.new(topCenter.X + side * 15 + ex, under - 4.2, topCenter.Z), sootIronDark, Enum.Material.Metal)
								flange.Shape = Enum.PartType.Cylinder
							end
						end
						-- The hook block: ropes down from the drums to a sheave block and a brass hook over the yard.
						local hookTop = under - 8
						local hookY = math.max(origin.Y + layout.Bottom + 1, hookTop - 10)
						for _, side in { -1, 1 } do
							flatRail("TrolleyHookRope", Vector3.new(topCenter.X + side * 1.2, hookTop + 2, topCenter.Z), Vector3.new(topCenter.X + side * 1.2, hookY + 3, topCenter.Z), 0.35, 0.35, railSteel, Enum.Material.Metal)
						end
						decor(model, "TrolleyHookBlock", Vector3.new(4, 3.4, 3), Vector3.new(topCenter.X, hookY + 2, topCenter.Z), sootIronDark, Enum.Material.Metal)
						decor(model, "TrolleyHook", Vector3.new(1.2, 2.6, 1.2), Vector3.new(topCenter.X, hookY - 0.4, topCenter.Z), sootBrass, Enum.Material.Metal)
					elseif layout.StonePiers ~= nil and layout.StonePiers[name] == true then
						-- A causeway deck: the rail line runs straight up it, north-south, sleepers and all.
						for _, side in { -1, 1 } do
							flatRail("CausewayRail", topCenter + Vector3.new(side * 2.6, 0.2, terrace.Depth / 2 - 1), topCenter + Vector3.new(side * 2.6, 0.2, -terrace.Depth / 2 + 1), 0.45, 0.32, railSteel, Enum.Material.Metal)
						end
						for k = 1, math.floor(terrace.Depth / 3.2) - 1 do
							decor(model, "CausewaySleeper", Vector3.new(9, 0.16, 1.4), topCenter + Vector3.new(0, 0.18, -terrace.Depth / 2 + k * 3.2), railTimber, Enum.Material.Wood)
						end
					elseif name == "Crossing" and layout.Authored == "infernal:1" then
						-- The Great Turntable: a sunken brick pit ring, the iron ring rail, and the turntable bridge
						-- laid north-south with its rails and sleepers (flush deck markings, walked over).
						local r = math.min(terrace.Width, terrace.Depth) * 0.46
						flatDisc("TurntablePitRing", topCenter + Vector3.new(0, 0.05, 0), r * 2 + 4, 0.1, sootBrickDark, Enum.Material.Brick)
						flatDisc("TurntablePitFloor", topCenter + Vector3.new(0, 0.08, 0), r * 2 - 2, 0.1, Color3.fromRGB(40, 34, 34), Enum.Material.Basalt)
						local segs = 36
						for k = 0, segs - 1 do
							local a0, a1 = k / segs * math.pi * 2, (k + 1) / segs * math.pi * 2
							local p0 = topCenter + Vector3.new(math.cos(a0) * (r - 3), 0.2, math.sin(a0) * (r - 3))
							local p1 = topCenter + Vector3.new(math.cos(a1) * (r - 3), 0.2, math.sin(a1) * (r - 3))
							flatRail("TurntableRingRail", p0, p1, 0.6, 0.3, railSteel, Enum.Material.Metal)
						end
						flatRail("TurntableBridgeDeck", topCenter + Vector3.new(0, 0.12, r), topCenter + Vector3.new(0, 0.12, -r), 12, 0.1, sootIronDark, Enum.Material.DiamondPlate)
						for _, side in { -1, 1 } do
							flatRail("TurntableBridgeGirder", topCenter + Vector3.new(side * 6.4, 0.3, r), topCenter + Vector3.new(side * 6.4, 0.3, -r), 0.9, 0.5, sootRust, Enum.Material.Metal)
							flatRail("TurntableBridgeRail", topCenter + Vector3.new(side * 2.6, 0.3, r - 1), topCenter + Vector3.new(side * 2.6, 0.3, -r + 1), 0.45, 0.32, railSteel, Enum.Material.Metal)
						end
						for k = 1, math.floor(r * 2 / 3.2) - 1 do
							local z = -r + k * 3.2
							decor(model, "TurntableSleeper", Vector3.new(9, 0.16, 1.4), topCenter + Vector3.new(0, 0.2, z), railTimber, Enum.Material.Wood)
						end
						-- The pivot boss and its hammer-ring inlay.
						flatDisc("TurntablePivot", topCenter + Vector3.new(0, 0.26, 0), 5, 0.12, sootBrass, Enum.Material.Metal)
					elseif name == "Weighbridge" then
						-- The scale plate, framed in brass, its rails running straight across it.
						decor(model, "WeighbridgeScalePlate", Vector3.new(terrace.Width - 14, 0.1, terrace.Depth - 6), topCenter + Vector3.new(0, 0.07, 0), Color3.fromRGB(86, 78, 74), Enum.Material.DiamondPlate)
						for _, sx in { -1, 1 } do
							decor(model, "WeighbridgeBrassFrame", Vector3.new(0.6, 0.12, terrace.Depth - 5), topCenter + Vector3.new(sx * (terrace.Width / 2 - 7), 0.1, 0), sootBrass, Enum.Material.Metal)
						end
						for _, sz in { -1, 1 } do
							decor(model, "WeighbridgeBrassFrame", Vector3.new(terrace.Width - 13, 0.12, 0.6), topCenter + Vector3.new(0, 0.1, sz * (terrace.Depth / 2 - 3)), sootBrass, Enum.Material.Metal)
						end
					elseif name == "CoalBunker" or name == "OreCrusher" then
						-- Hazard-striped loading edge and a siding of rail across the deck.
						for k = 0, 9 do
							decor(model, "FoundryHazardStripe", Vector3.new(2.2, 0.08, 1.2), topCenter + Vector3.new(-terrace.Width / 2 + 5 + k * 3.2, 0.06, -terrace.Depth / 2 + 2.6), if k % 2 == 0 then Color3.fromRGB(178, 132, 42) else sootIronDark, Enum.Material.Metal)
						end
						-- The Coal Bunker's siding runs under its hopper chutes (TowerSetPieces), the crusher's past its chute.
						local sidingZ = if name == "CoalBunker" then -18 else terrace.Depth * 0.2
						for _, side in { -1, 1 } do
							flatRail("DeckSidingRail", topCenter + Vector3.new(-terrace.Width / 2 + 4, 0.2, side * 2.6 + sidingZ), topCenter + Vector3.new(terrace.Width / 2 - 4, 0.2, side * 2.6 + sidingZ), 0.45, 0.32, railSteel, Enum.Material.Metal)
						end
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
	local function landingOutsideTerrace(pad: any, terraceName: string?): boolean
		local t = if terraceName then layout.Platforms[terraceName] else nil
		if not t then
			return true
		end
		local dx, dz = pad.BX - pad.AX, pad.BZ - pad.AZ
		local len = math.max(math.sqrt(dx * dx + dz * dz), 1e-4)
		local rx, rz = -dz / len, dx / len
		local hw = pad.Width / 2 - 0.5
		for _, pt in { { pad.AX, pad.AZ }, { pad.BX, pad.BZ } } do
			for _, side in { -1, 1 } do
				local cx = pt[1] + rx * side * hw
				local cz = pt[2] + rz * side * hw
				if math.abs(cx - t.X) > t.Width / 2 + 0.25 or math.abs(cz - t.Z) > t.Depth / 2 + 0.25 then
					return true
				end
			end
		end
		return false
	end
	local function landing(pad: any, id: string, terraceName: string?)
		local a=origin+Vector3.new(pad.AX,pad.AY,pad.AZ)
		local b=origin+Vector3.new(pad.BX,pad.BY,pad.BZ)
		local p=part(model,"TraversalLanding",Vector3.new(pad.Width,2,(b-a).Magnitude),(a+b)/2,theme.TrimColor,theme.TrimMaterial)
		-- Landing tops sit 0.08 above terrace planes (ramps 0.04) so coplanar faces never z-fight at joins.
		p.CFrame=CFrame.lookAt((a+b)/2,b)*CFrame.new(0,-0.92,0)
		local isFoundryBridgehead = layout.Masonry == "FOUNDRY_IRON"
			and (isSuspendedLink(layout, id) or isArchitecturalDeck(layout, terraceName))
			and (not isArchitecturalDeck(layout, terraceName) or landingOutsideTerrace(pad, terraceName))
		if direct then
			-- On a deck the landing is part of the masonry (solid, the deck's colour); elsewhere it is terrain.
			-- A hung walkway's landings are its own planks, run out onto the terrace it reaches.
			if hungLinks[id] then
				if matriarchHollow then
					p.Color, p.Material = slateIndigo, Enum.Material.Slate
				elseif bridgeStyles[id] == "LOG" then
					-- A fallen log's ends: its root plate and its crown, dressed by the log itself; the landing
					-- underfoot stays solid but unseen.
					proxy(p)
					p.CanCollide = true
					p.CanQuery = true
				else
					p.Color, p.Material = plank, Enum.Material.WoodPlanks
				end
			elseif terraceName and deckIds[terraceName] then
				local deck = model:FindFirstChild(if terraceName == "Sanctuary" then "SafeArrival" else terraceName) :: BasePart?
				if deck then p.Color, p.Material = deck.Color, deck.Material end
			else
				proxy(p)
			end
		elseif isFoundryBridgehead then
			-- Exposed FOUNDRY_IRON bridgehead apron: a diagonal bridge or chasm span's landing extends past the
			-- terrace edge (or lands onto a terrain terrace where voxel ground stops short of the suspended link).
			-- Keep it solid, visible diamond-plate with a dark-iron underside flange so every bridge joins flush.
			p.Color = sootIron
			p.Material = Enum.Material.DiamondPlate
			p.CanCollide = true
			p.CanQuery = true
			p.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, -0.98, 0)
			local keel = decor(model, "FoundryLandingKeel", Vector3.new(pad.Width + 0.8, 1.8, (b - a).Magnitude + 0.4), (a + b) / 2, sootIronDark, Enum.Material.Metal)
			keel.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, -2.05, 0)
		elseif isArchitecturalDeck(layout, terraceName) then
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
				local treadCol = if velmari then (if step % 2 == 0 then slateIndigo else slateDark)
					elseif hollin then (if step % 2 == 0 then fieldstone else fieldstoneDark)
					elseif masonryStyle and masonryStyle.StairColorA
					then (if step % 2 == 0 then masonryStyle.StairColorA else masonryStyle.StairColorB)
					elseif pathStyle
					then (if step % 2 == 0 then pathStyle.StairColorA else pathStyle.StairColorB)
					else theme.TrimColor
				local treadMat = if velmari or hollin then Enum.Material.Slate
					elseif masonryStyle and masonryStyle.StairMatA
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
				if masonryStyle and masonryStyle.StairNosing then
					-- Brass nosing along each tread's front edge (Sootwright iron stairs).
					local nosing = decor(model, "StairBrassNosing", Vector3.new(treadW - 1.2, 0.22, 0.55), Vector3.new(center.X, top + 0.02, center.Z), masonryStyle.StairNosing, Enum.Material.Metal)
					nosing.CFrame = CFrame.lookAt(nosing.Position, nosing.Position + flat) * CFrame.new(0, 0, (flat.Magnitude / steps) * 0.5 - 0.3)
				end
				if stairInlayCol and step % 2 == 1 then
					local inlay = decor(model, "GlassStairAmberInlay", Vector3.new(treadW * 0.72, 0.08, 0.42), Vector3.new(center.X, top + 0.05, center.Z), stairInlayCol, Enum.Material.Neon)
					inlay.CFrame = CFrame.lookAt(inlay.Position, inlay.Position + flat) * CFrame.new(0, 0, -0.35)
				end
				if natural then continue end
				local runner = decor(model, "GrandStairRunner", Vector3.new(link.Width * 0.36, 0.12, flat.Magnitude / steps + 0.2), Vector3.new(center.X, top + 0.08, center.Z), theme.AccentColor, theme.TrimMaterial)
				runner.CFrame = CFrame.lookAt(runner.Position, runner.Position + flat)
			end
			if suspended and masonryStyle and masonryStyle.StairUnder then
				-- Stringer keel underneath suspended stairs (granite on F20 royal stair, obsidian/basalt on F13/F15)
				local underCol = if layout.Masonry == "THRONE_HALL" then whiteguardGraniteDark else obsidianStairA
				local underMat = if layout.Masonry == "THRONE_HALL" then Enum.Material.Slate else Enum.Material.Basalt
				local underStair = decor(model, "GlassStairUnderside", Vector3.new(link.Width - 3.0, masonryStyle.StairUnderHeight, math.max(1, delta.Magnitude - 1.0)), mid, underCol, underMat)
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
			if hungLinks[link.Id] and bridgeStyles[link.Id] == "LOG" then
				-- Floor 31's Fallen-Log Ford: a colossal fallen trunk laid across the brook with a split limb
				-- beside it, so the whole walkway's width stands on wood. The ramp stays as the solid, unseen
				-- walking surface; the logs are dressing (no collision, no queries).
				ramp.Transparency = 1
				local trunkR, limbR = 10.5, 5.5
				local function log(name: string, offset: Vector3, r: number, overhang: number)
					local axis = delta.Unit
					local p0, p1 = a - axis * overhang + offset, b + axis * overhang + offset
					local trunk = decor(model, name, Vector3.new((p1 - p0).Magnitude, r * 2, r * 2), (p0 + p1) / 2, logBark, Enum.Material.Wood)
					trunk.Shape = Enum.PartType.Cylinder
					trunk.CFrame = CFrame.lookAt((p0 + p1) / 2, p1) * CFrame.Angles(0, math.pi / 2, 0)
					return trunk
				end
				log("FordLogTrunk", right * -3.5 - Vector3.new(0, trunkR - 0.15, 0), trunkR, 6)
				log("FordLogLimb", right * 9.6 - Vector3.new(0, limbR + 0.05, 0), limbR, 1)
				-- The trunk's top is worn flat where the wardens walked: a strip of pale heartwood.
				local worn = decor(model, "FordLogWornTop", Vector3.new(link.Width - 9, 0.2, delta.Magnitude), mid - right * 1.5, logWood, Enum.Material.Wood)
				worn.CFrame = CFrame.lookAt(mid - right * 1.5, b - right * 1.5) * CFrame.new(0, 0.02, 0)
				-- The root plate and broken crown stand off the lanes as set pieces (TowerSetPieces/CorruptedGrove).
			elseif hungLinks[link.Id] then
				-- Floor 10: Velmari silk-and-slate web spans; Floor 8: Lampkeeper rope-and-plank walkways.
				ramp.Color = if matriarchHollow then slateIndigo else plank
				ramp.Material = if matriarchHollow then Enum.Material.Slate else Enum.Material.WoodPlanks
				local length = delta.Magnitude
				local boards = math.max(1, math.floor((length - 2) / 3.4))
				for i = 1, boards do
					local at = a:Lerp(b, (i - 0.5) / boards)
					local board = decor(model, "RampStepLip", Vector3.new(link.Width - 2, 0.18, 0.9), at, if matriarchHollow then slateDark else plankDark, if matriarchHollow then Enum.Material.Slate else Enum.Material.WoodPlanks)
					board.CFrame = CFrame.lookAt(at, at + delta) * CFrame.new(0, 0.07, 0)
				end
			elseif direct then
				-- An earthen ramp: the terrain is the path (TowerTerrain paints its trodden trail). Flush slate
				-- pavers laid down its spine, staggered, read as the masons' old stepping stones.
				proxy(ramp)
				local length = delta.Magnitude
				local stones = math.max(1, math.floor((length - 4) / 5.2))
				for i = 1, stones do
					local stagger = if i % 2 == 0 then 1.4 else -1.4
					local at = a:Lerp(b, (i - 0.5) / stones) + right * stagger
					local stoneW = link.Width * (0.26 + ((i * 7) % 3) * 0.04)
					local stone = decor(model, "RampStepLip", Vector3.new(stoneW, 0.45, 2.2), at,
						if velmari then (if i % 2 == 0 then slateIndigo else slateDark)
							elseif hollin then (if i % 2 == 0 then fieldstone else fieldstoneDark)
							else flagstoneDark,
						if velmari or hollin then Enum.Material.Slate else Enum.Material.Limestone)
					stone.CFrame = CFrame.lookAt(at, at + delta) * CFrame.new(0, 0.06, 0) * CFrame.Angles(0, math.rad(((i * 19) % 14) - 7), 0)
				end
			elseif isSuspendedLink(layout, link.Id) and bridgeKind == "SOLMERE_ARCH" then
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
			elseif isSuspendedLink(layout, link.Id) and bridgeKind == "WHITEGUARD_VIADUCT" then
				-- Floor 19 monumental arched stone viaduct over the frozen gorge: twin outer stone piers,
				-- gothic arch haunches, overhanging stone corbels, hanging icicle eaves, and flagstone deck.
				ramp.Color = whiteguardGranite
				ramp.Material = Enum.Material.Slate
				local deepBottom = origin.Y + layout.Bottom - 8
				local spanLen = math.max(1, delta.Magnitude - 1.0)
				local underRamp = decor(model, "BridgeStoneUnderside", Vector3.new(link.Width - 2.0, 3.2, spanLen), mid, whiteguardGraniteDark, Enum.Material.Slate)
				underRamp.CFrame = CFrame.lookAt(mid, b) * CFrame.new(0, -3.3, 0)
				local pierFracs = if delta.Magnitude > 92 then { 0.20, 0.50, 0.80 } elseif delta.Magnitude > 54 then { 0.26, 0.74 } else { 0.50 }
				local pierHalf = link.Width * 0.36
				for _, frac in pierFracs do
					local pAt = a:Lerp(b, frac)
					local pH = math.max(8, pAt.Y - deepBottom - 1.6)
					local pierDir = CFrame.lookAt(Vector3.zero, flat)
					for _, side in { -1, 1 } do
						local colPos = Vector3.new(pAt.X, pAt.Y - pH / 2 - 2.2, pAt.Z) + right * (side * pierHalf)
						local col = part(model, "ViaductStonePier", Vector3.new(5.6, pH, 9.6), colPos, whiteguardGraniteDark, Enum.Material.Slate)
						col.CFrame = CFrame.new(colPos) * pierDir
						col.CanQuery = true
						col.CanTouch = false
						local haunchPos = Vector3.new(pAt.X, pAt.Y - 7.4, pAt.Z) + right * (side * (pierHalf * 0.55))
						local haunch = decor(model, "ViaductArchHaunch", Vector3.new(link.Width * 0.44, 3.6, 8.2), haunchPos, whiteguardGranite, Enum.Material.Slate)
						haunch.CFrame = CFrame.new(haunchPos) * pierDir * CFrame.Angles(0, 0, -side * math.rad(28))
					end
					local archBeamPos = Vector3.new(pAt.X, pAt.Y - 4.4, pAt.Z)
					local archBeam = decor(model, "ViaductArchSpan", Vector3.new(link.Width - 1.2, 3.2, 9.2), archBeamPos, whiteguardGranite, Enum.Material.Slate)
					archBeam.CFrame = CFrame.new(archBeamPos) * pierDir
					local ic = decor(model, "BridgeEaveIcicle", Vector3.new(1.5, 5.2, 1.5), archBeamPos + right * (link.Width * 0.48) - Vector3.new(0, 4.2, 0), Color3.fromRGB(148, 212, 246), Enum.Material.Ice, 0.14)
					ic.CFrame = CFrame.new(ic.Position) * pierDir
				end
				local corbels = math.max(2, math.floor(spanLen / 24))
				for cIdx = 1, corbels do
					local t = cIdx / (corbels + 1)
					local cAt = a:Lerp(b, t)
					for _, side in { -1, 1 } do
						local cPos = cAt + right * (side * (link.Width * 0.46)) - Vector3.new(0, 2.2, 0)
						local corbel = decor(model, "BridgeCorbel", Vector3.new(2.2, 2.8, 2.6), cPos, whiteguardGraniteDark, Enum.Material.Slate)
						corbel.CFrame = CFrame.lookAt(cPos, cPos + flat)
						if cIdx % 2 == 1 then
							local ic = decor(model, "BridgeEaveIcicle", Vector3.new(1.1, 3.8 + (cIdx % 3), 1.1), cPos - Vector3.new(0, 3.0, 0), Color3.fromRGB(148, 212, 246), Enum.Material.Ice, 0.16)
							ic.CFrame = CFrame.lookAt(ic.Position, ic.Position + flat)
						end
					end
				end
				local stoneA = a:Lerp(b, 0.05)
				local stoneB = a:Lerp(b, 0.95)
				local stones = math.max(3, math.floor(((stoneB - stoneA).Magnitude - 2) / 5.6))
				for i = 1, stones do
					local t = (i - 0.5) / stones
					local stagger = math.sin(i * 1.9 + delta.X * 0.03) * 2.2
					local at = stoneA:Lerp(stoneB, t) + right * stagger
					local stoneW = link.Width * (0.40 + ((i * 5) % 4) * 0.05)
					local stone = decor(model, "RampStepLip", Vector3.new(stoneW, 0.16, 3.8), at, if i % 2 == 0 then whiteguardGranite else whiteguardGraniteDark, Enum.Material.Slate)
					stone.CFrame = CFrame.lookAt(at, at + (stoneB - stoneA)) * CFrame.new(0, 0.10 + (i % 3) * 0.02, 0) * CFrame.Angles(0, math.rad(((i * 19) % 14) - 7), 0)
				end
			elseif isSuspendedLink(layout, link.Id) and bridgeKind == "GLACIER_SLAB" then
				-- Alpine timber-and-granite frost bridge over the frozen lake (plank deck, stone girders, lake piers, flush pad approaches)
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
				-- Extend wooden approach decks across LandingA and LandingB cleanly onto both pads
				local landAEnd = origin + Vector3.new(link.LandingA.AX, link.LandingA.AY, link.LandingA.AZ)
				local landBEnd = origin + Vector3.new(link.LandingB.BX, link.LandingB.BY, link.LandingB.BZ)
				for _, span in { { a:Lerp(landAEnd, 0.72), a }, { b, b:Lerp(landBEnd, 0.72) } } do
					local p0, p1 = span[1], span[2]
					local appDelta = p1 - p0
					local appLen = appDelta.Magnitude
					if appLen > 0.5 then
						local appMid = (p0 + p1) * 0.5
						local appDeck = decor(model, "BridgeApproachDeck", Vector3.new(link.Width, 1.9, appLen + 0.8), appMid, bridgeWoodA, Enum.Material.Wood)
						appDeck.CFrame = CFrame.lookAt(appMid, p1) * CFrame.new(0, -0.86, 0)
						for _, t in { 0.32, 0.68 } do
							local pt = p0:Lerp(p1, t)
							local plank = decor(model, "BridgePlankSleeper", Vector3.new(link.Width + 0.6, 0.14, 2.6), pt, if t < 0.5 then bridgeWoodB else bridgeWoodA, Enum.Material.Wood)
							plank.CFrame = CFrame.lookAt(pt, p1) * CFrame.new(0, 0.10, 0)
						end
					end
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
			elseif isSuspendedLink(layout, link.Id) and bridgeKind == "FOUNDRY_GIRDER" then
				-- Floor 21 Sootwright girder spur: a diamond-plate deck on two lattice side girders, rails and
				-- sleepers down its spine, and iron trestles (solid) braced down to the yard.
				local deepBottom = origin.Y + layout.Bottom - 5
				local length = delta.Magnitude
				ramp.Color = sootIron
				ramp.Material = Enum.Material.DiamondPlate
				local function strut(name: string, p0: Vector3, p1: Vector3, thick: number, col: Color3, mat: Enum.Material)
					local sp = decor(model, name, Vector3.new(thick, thick, math.max(0.2, (p1 - p0).Magnitude)), (p0 + p1) / 2, col, mat)
					sp.CFrame = CFrame.lookAt((p0 + p1) / 2, p1)
					return sp
				end
				local down = Vector3.new(0, -1, 0)
				-- A crane girder span (layout.GirderSpans, Floor 22) hangs free between its nodes: a deeper box
				-- girder with cross-bracing underneath and no trestles.
				local freeSpan = layout.GirderSpans ~= nil and layout.GirderSpans[link.Id] == true
				local chordDepth = if freeSpan then 8.5 else 5.6
				for _, side in { -1, 1 } do
					local edge = right * (side * (link.Width * 0.47))
					-- Top and bottom chords, then the lattice web zig-zagging between them.
					strut("BridgeSideGirder", a + edge + down * 1.4, b + edge + down * 1.4, 1.5, sootIronDark, Enum.Material.Metal)
					strut("FoundryGirderChord", a + edge + down * chordDepth, b + edge + down * chordDepth, if freeSpan then 1.5 else 1.1, sootIronDark, Enum.Material.Metal)
					local bays = math.max(3, math.floor(length / 6))
					for k = 0, bays - 1 do
						local t0, t1 = k / bays, (k + 1) / bays
						local hi0, lo1 = a:Lerp(b, t0) + edge + down * 1.6, a:Lerp(b, t1) + edge + down * (chordDepth - 0.2)
						if k % 2 == 1 then
							hi0, lo1 = a:Lerp(b, t0) + edge + down * (chordDepth - 0.2), a:Lerp(b, t1) + edge + down * 1.6
						end
						strut("FoundryGirderWeb", hi0, lo1, 0.6, sootRust, Enum.Material.Metal)
					end
				end
				if freeSpan then
					local bays = math.max(2, math.floor(length / 8))
					for k = 0, bays do
						local at = a:Lerp(b, k / bays) + down * chordDepth
						strut("FoundryGirderTie", at - right * (link.Width * 0.47), at + right * (link.Width * 0.47), 0.8, sootIronDark, Enum.Material.Metal)
					end
				end
				-- Rails and sleepers along the spur.
				local sleepers = math.max(3, math.floor((length - 2) / 3.2))
				for i = 1, sleepers do
					local at = a:Lerp(b, (i - 0.5) / sleepers)
					local sl = decor(model, "BridgePlankSleeper", Vector3.new(9, 0.16, 1.4), at, railTimber, Enum.Material.Wood)
					sl.CFrame = CFrame.lookAt(at, at + delta) * CFrame.new(0, 0.1, 0)
				end
				for _, side in { -1, 1 } do
					local r0, r1 = a + right * (side * 2.6), b + right * (side * 2.6)
					local railPart = decor(model, "RampRailInlay", Vector3.new(0.45, 0.32, math.max(1, length - 1)), (r0 + r1) / 2, railSteel, Enum.Material.Metal)
					railPart.CFrame = CFrame.lookAt((r0 + r1) / 2, r1) * CFrame.new(0, 0.28, 0)
				end
				local stoneSpan = layout.StonePiers ~= nil and layout.StonePiers[link.Id] == true
				if stoneSpan then
					-- A soot-brick causeway span: broad piers out of the lava and twin pipe runs along both parapets.
					local spanFracs = if length > 40 then { 0.3, 0.7 } else { 0.5 }
					for _, frac in spanFracs do
						local pt = a:Lerp(b, frac)
						local h = math.max(2.5, (pt.Y - 6) - deepBottom)
						local pier = decor(model, "ViaductPier", Vector3.new(link.Width - 4, h, 8), Vector3.new(pt.X, deepBottom + h / 2, pt.Z), sootBrick, Enum.Material.Brick)
						pier.CFrame = CFrame.lookAt(pier.Position, pier.Position + flat) * CFrame.Angles(0, 0, 0)
						local cut = decor(model, "CausewayCutwater", Vector3.new(link.Width, 6, 10), Vector3.new(pt.X, deepBottom + 6, pt.Z), Color3.fromRGB(40, 36, 38), Enum.Material.Basalt)
						cut.CFrame = CFrame.lookAt(cut.Position, cut.Position + flat)
					end
					for _, side in { -1, 1 } do
						for _, off in { 0, 1.7 } do
							local pa = a + right * (side * (link.Width / 2 + 1.2 + off)) + Vector3.new(0, -0.6, 0)
							local pb = b + right * (side * (link.Width / 2 + 1.2 + off)) + Vector3.new(0, -0.6, 0)
							local pipe = decor(model, "CausewayPipeRun", Vector3.new(1.4, 1.4, (pb - pa).Magnitude), (pa + pb) / 2, if off == 0 then sootIron else sootRust, Enum.Material.Metal)
							pipe.CFrame = CFrame.lookAt((pa + pb) / 2, pb)
						end
					end
				end
				-- Trestles: paired columns with an X-brace between them (none under a free crane span or a stone span).
				local fracs = if freeSpan or stoneSpan then {} elseif length > 58 then { 0.22, 0.5, 0.78 } else { 0.3, 0.7 }
				for _, frac in fracs do
					local pt = a:Lerp(b, frac)
					local legTop = pt.Y - 5.6
					local legH = math.max(2.5, legTop - deepBottom)
					local feet = {}
					for _, side in { -1, 1 } do
						local legPos = pt + right * (side * (link.Width * 0.42))
						decor(model, "ViaductPier", Vector3.new(2.6, legH, 2.6), Vector3.new(legPos.X, deepBottom + legH / 2, legPos.Z), sootIronDark, Enum.Material.Metal)
						decor(model, "FoundryGantryFoot", Vector3.new(4.4, 1.6, 4.4), Vector3.new(legPos.X, deepBottom + 3.2, legPos.Z), sootBrickDark, Enum.Material.Brick)
						table.insert(feet, legPos)
					end
					if legH > 6 then
						local l, r = feet[1], feet[2]
						strut("FoundryTrestleBrace", Vector3.new(l.X, deepBottom + 4, l.Z), Vector3.new(r.X, legTop - 0.5, r.Z), 0.7, sootRust, Enum.Material.Metal)
						strut("FoundryTrestleBrace", Vector3.new(r.X, deepBottom + 4, r.Z), Vector3.new(l.X, legTop - 0.5, l.Z), 0.7, sootRust, Enum.Material.Metal)
					end
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
				local stones = math.max(1, math.floor((length - 4) / ((pathStyle and pathStyle.GrassStepLipStep) or 5.2)))
				local staggerBy = (pathStyle and pathStyle.GrassStepLipStagger) or 1.4
				local wBase = (pathStyle and pathStyle.GrassStepLipWBase) or 0.26
				local wStep = (pathStyle and pathStyle.GrassStepLipWStep) or 0.04
				local wMod = (pathStyle and pathStyle.GrassStepLipWMod) or 7
				local lipH = (pathStyle and pathStyle.GrassStepLipH) or 0.45
				local lipY = (pathStyle and pathStyle.GrassStepLipY) or 0.06
				local railed = pathStyle ~= nil and pathStyle.RailInlay == true
				for i = 1, stones do
					local stagger = if i % 2 == 0 then staggerBy else -staggerBy
					local at = a:Lerp(b, (i - 0.5) / stones) + right * stagger
					local stoneW = link.Width * (wBase + ((i * wMod) % 3) * wStep)
					local lipCol = if pathStyle then (if i % 2 == 0 then pathStyle.GrassStepLipColorA else pathStyle.GrassStepLipColorB) else flagstoneDark
					local lipMat = if pathStyle then (if i % 2 == 0 then pathStyle.GrassStepLipMatA else pathStyle.GrassStepLipMatB) else Enum.Material.Limestone
					local stone = decor(model, "RampStepLip", Vector3.new(stoneW, lipH, if railed then 1.6 else 2.9), at, lipCol, lipMat)
					-- Sleepers lie square across the spur; stepping stones are laid a little askew.
					local skew = if railed then ((i * 7) % 5 - 2) * 0.6 else ((i * 19) % 14) - 7
					stone.CFrame = CFrame.lookAt(at, at + delta) * CFrame.new(0, lipY, 0) * CFrame.Angles(0, math.rad(skew), 0)
				end
				if railed then
					-- A pair of steel rails down the spur's spine, on the sleepers (flush trim, never collides).
					for _, side in { -1, 1 } do
						local railAt = mid + right * (side * 2.6)
						local rail = decor(model, "RampRailInlay", Vector3.new(0.45, 0.32, math.max(1, length - 2)), railAt, railSteel, Enum.Material.Metal)
						rail.CFrame = CFrame.lookAt(railAt, railAt + delta) * CFrame.new(0, lipY + lipH * 0.5 + 0.12, 0)
					end
				end
				if pathStyle and pathStyle.GrassTrailKerbs then
					local kerbs = math.max(2, math.floor(length / 16))
					for kIdx = 1, kerbs do
						local kt = (kIdx - 0.5) / kerbs
						local side = if kIdx % 2 == 0 then 1 else -1
						local kAt = a:Lerp(b, kt) + right * (side * (link.Width * 0.45))
						local kerb = decor(model, "RampTrailKerb", Vector3.new(2.4, 1.4, 4.2), kAt, whiteguardGraniteDark, Enum.Material.Slate)
						kerb.CFrame = CFrame.lookAt(kAt, kAt + delta) * CFrame.new(0, 0.45, 0)
						local snowTop = decor(model, "RampTrailKerbSnow", Vector3.new(2.2, 0.45, 3.8), kAt, glacierSnowCol, Enum.Material.Snow)
						snowTop.CFrame = CFrame.lookAt(kAt, kAt + delta) * CFrame.new(0, 1.25, 0)
					end
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
				if hungLinks[link.Id] and bridgeStyles[link.Id] == "HEDGE" then
					-- Floor 33's hedge-walled maze bridges: low thorny hawthorn hedges (5.4 studs tall, <= 9 so the
					-- camera reads the maze from above) laced with glowing violet-magenta briar veins, outside UsableWidth.
					local hedgeOffset = right * (side * (link.Width / 2 - 0.55))
					local hedgeCol = Color3.fromRGB(48, 56, 62)
					local briarCol = Color3.fromRGB(204, 58, 236)
					local hedge = decor(curbGroup, "BridgeHedgeWall", Vector3.new(2.2, 5.4, curbLen), mid + hedgeOffset + Vector3.new(0, 2.5, 0), hedgeCol, Enum.Material.Grass)
					hedge.CFrame = CFrame.lookAt(mid + hedgeOffset, b + hedgeOffset) * CFrame.new(0, 2.5, 0)
					local vine = decor(curbGroup, "BridgeHedgeBriar", Vector3.new(2.45, 0.55, curbLen * 0.94), mid + hedgeOffset + Vector3.new(0, 4.3, 0), briarCol, Enum.Material.Neon)
					vine.CFrame = CFrame.lookAt(mid + hedgeOffset, b + hedgeOffset) * CFrame.new(0, 4.3, 0)
					local posts = math.max(2, math.floor(delta.Magnitude / 14) + 1)
					for i = 0, posts - 1 do
						local at = a:Lerp(b, i / (posts - 1)) + hedgeOffset
						local post = decor(curbGroup, "BridgeHedgePost", Vector3.new(0.75, 5.8, 0.75), at + Vector3.new(0, 2.7, 0), plankDark, Enum.Material.Wood)
						post.CFrame = CFrame.lookAt(post.Position, post.Position + flat)
					end
				elseif hungLinks[link.Id] and bridgeStyles[link.Id] == "BRANCH" then
					-- Floor 34's tree-to-tree branch bridges over the rot bog: gnarled timber handrails, taut rope
					-- lanyards and glowing violet-magenta sap tendrils strictly outside UsableWidth.
					local railOffset = right * (side * (link.Width / 2 - 0.55))
					local branchBark = Color3.fromRGB(54, 34, 62)
					local sapGlow = Color3.fromRGB(218, 66, 246)
					for idx, h in { 1.7, 3.6 } do
						local r0, r1 = a + railOffset + Vector3.new(0, h, 0), b + railOffset + Vector3.new(0, h, 0)
						local railPart = decor(curbGroup, "BridgeBranchRail", Vector3.new(if idx == 2 then 0.65 else 0.32, if idx == 2 then 0.65 else 0.32, (r1 - r0).Magnitude), (r0 + r1) / 2, if idx == 2 then branchBark else rope, if idx == 2 then Enum.Material.Wood else Enum.Material.Fabric)
						railPart.CFrame = CFrame.lookAt((r0 + r1) / 2, r1)
					end
					local sapLine = decor(curbGroup, "BridgeBranchSap", Vector3.new(0.32, 0.32, curbLen * 0.92), mid + railOffset + Vector3.new(0, 3.95, 0), sapGlow, Enum.Material.Neon)
					sapLine.CFrame = CFrame.lookAt(mid + railOffset, b + railOffset) * CFrame.new(0, 3.95, 0)
					local posts = math.max(2, math.floor(delta.Magnitude / 13) + 1)
					for i = 0, posts - 1 do
						local at = a:Lerp(b, i / (posts - 1)) + railOffset
						local post = decor(curbGroup, "BridgeBranchPost", Vector3.new(0.85, 4.8, 0.85), at + Vector3.new(0, 2.2, 0), branchBark, Enum.Material.Wood)
						post.CFrame = CFrame.lookAt(post.Position, post.Position + flat)
					end
				elseif hungLinks[link.Id] and bridgeStyles[link.Id] == "ROOT" then
					-- Floor 35's colossal root-burl walkways over the sap mire: gnarled blackened root-bark curbs
					-- with pulsing violet-magenta heartrot seams strictly outside UsableWidth.
					local rootOffset = right * (side * (link.Width / 2 - 0.5))
					local rootBark = Color3.fromRGB(46, 24, 56)
					local rootGlow = Color3.fromRGB(234, 62, 252)
					local rail = decor(curbGroup, "BridgeRootCurb", Vector3.new(2.1, 3.0, curbLen), mid + rootOffset + Vector3.new(0, 1.3, 0), rootBark, Enum.Material.Wood)
					rail.CFrame = CFrame.lookAt(mid + rootOffset, b + rootOffset) * CFrame.new(0, 1.3, 0)
					local vein = decor(curbGroup, "BridgeRootVein", Vector3.new(2.35, 0.55, curbLen * 0.94), mid + rootOffset + Vector3.new(0, 2.35, 0), rootGlow, Enum.Material.Neon)
					vein.CFrame = CFrame.lookAt(mid + rootOffset, b + rootOffset) * CFrame.new(0, 2.35, 0)
				elseif hungLinks[link.Id] and bridgeStyles[link.Id] ~= "LOG" then
					-- Silk web cables (Floor 10) or rope rails on posts (part of the curb prop, so walkway clearance leaves them).
					local railOffset = right * (side * (link.Width / 2 - 0.6))
					for _, h in { 1.6, 3.4 } do
						local r0, r1 = a + railOffset + Vector3.new(0, h, 0), b + railOffset + Vector3.new(0, h, 0)
						local railPart = decor(curbGroup, "BridgeRopeRail", Vector3.new(0.3, 0.3, (r1 - r0).Magnitude), (r0 + r1) / 2, if matriarchHollow then webCable else rope, Enum.Material.Fabric)
						railPart.CFrame = CFrame.lookAt((r0 + r1) / 2, r1)
					end
					local posts = math.max(2, math.floor(delta.Magnitude / 12) + 1)
					for i = 0, posts - 1 do
						local at = a:Lerp(b, i / (posts - 1)) + railOffset
						local post = decor(curbGroup, "BridgeRopePost", Vector3.new(0.7, 4.2, 0.7), at + Vector3.new(0, 1.9, 0), if matriarchHollow then slateDark else plankDark, if matriarchHollow then Enum.Material.Slate else Enum.Material.Wood)
						post.CFrame = CFrame.lookAt(post.Position, post.Position + flat)
					end
				end
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
					elseif curbMode == "WHITEGUARD_MERLON" then
						-- Snow-capped Whiteguard granite viaduct parapet & tall battlement merlons
						local cap = decor(curbGroup, "BridgeSnowCap", Vector3.new(2.7, 0.55, math.max(1, curbLen - 1)), mid + curbOffset, glacierSnowCol, Enum.Material.Snow)
						cap.CFrame = CFrame.lookAt(mid + curbOffset, b + curbOffset) * CFrame.new(0, 1.20, 0)
						local posts = math.max(2, math.floor(curbLen / 18))
						for pIdx = 1, posts do
							local pt = a:Lerp(b, pIdx / (posts + 1)) + curbOffset
							local merlon = decor(curbGroup, "BridgeFortressMerlon", Vector3.new(3.0, 2.6, 4.2), pt, whiteguardGraniteDark, Enum.Material.Slate)
							merlon.CFrame = CFrame.lookAt(pt, b + curbOffset) * CFrame.new(0, 1.85, 0)
							local msnow = decor(curbGroup, "BridgeMerlonSnow", Vector3.new(2.8, 0.65, 4.0), pt, glacierSnowCol, Enum.Material.Snow)
							msnow.CFrame = CFrame.lookAt(pt, b + curbOffset) * CFrame.new(0, 3.35, 0)
						end
					elseif curbMode == "WHITEGUARD_BRIDGE" then
						-- Granite parapet curb extending across both approaches with carved newel bollards at pad entries
						curb.Size = Vector3.new(1.6, 1.5, math.max(1, delta.Magnitude))
						curb.CFrame = CFrame.lookAt(mid + curbOffset, b + curbOffset) * CFrame.new(0, -0.05, 0)
						local bridgeWood = Color3.fromRGB(92, 72, 56)
						local railLen = math.max(1, delta.Magnitude)
						local railTop = decor(curbGroup, "BridgeHandrail", Vector3.new(0.85, 0.65, railLen), mid + curbOffset, bridgeWood, Enum.Material.Wood)
						railTop.CFrame = CFrame.lookAt(mid + curbOffset, b + curbOffset) * CFrame.new(0, 3.05, 0)
						local railMid = decor(curbGroup, "BridgeMidRail", Vector3.new(0.6, 0.45, railLen), mid + curbOffset, bridgeWood, Enum.Material.Wood)
						railMid.CFrame = CFrame.lookAt(mid + curbOffset, b + curbOffset) * CFrame.new(0, 1.75, 0)
						-- Continue curb sills & top handrail out to the pad thresholds and anchor granite newel bollards there
						local landAEnd = origin + Vector3.new(link.LandingA.AX, link.LandingA.AY, link.LandingA.AZ)
						local landBEnd = origin + Vector3.new(link.LandingB.BX, link.LandingB.BY, link.LandingB.BZ)
						local enterA, enterB = a:Lerp(landAEnd, 0.72), b:Lerp(landBEnd, 0.72)
						for _, span in { { enterA, a, enterA }, { b, enterB, enterB } } do
							local p0, p1, bollardAt = span[1], span[2], span[3]
							local sDelta = p1 - p0
							local sLen = sDelta.Magnitude
							if sLen > 0.5 then
								local sMid = (p0 + p1) * 0.5 + curbOffset
								local appCurb = decor(curbGroup, "BridgeCurb", Vector3.new(1.6, 1.5, sLen + 0.5), sMid, whiteguardGranite, Enum.Material.Slate)
								appCurb.CFrame = CFrame.lookAt(sMid, p1 + curbOffset) * CFrame.new(0, -0.05, 0)
								local appRail = decor(curbGroup, "BridgeHandrail", Vector3.new(0.85, 0.65, sLen + 0.4), sMid, bridgeWood, Enum.Material.Wood)
								appRail.CFrame = CFrame.lookAt(sMid, p1 + curbOffset) * CFrame.new(0, 3.05, 0)
							end
							local np = bollardAt + curbOffset
							local newel = decor(curbGroup, "BridgeNewelPost", Vector3.new(2.4, 4.6, 2.4), np, whiteguardGranite, Enum.Material.Slate)
							newel.CFrame = CFrame.lookAt(np, np + flat) * CFrame.new(0, 1.8, 0)
							local cap = decor(curbGroup, "BridgeNewelCap", Vector3.new(2.8, 0.6, 2.8), np, glacierIceCol, Enum.Material.Ice, 0.1)
							cap.CFrame = CFrame.lookAt(np, np + flat) * CFrame.new(0, 4.35, 0)
						end
						for _, hingePt in { a, b } do
							local hp = hingePt + curbOffset
							local post = decor(curbGroup, "BridgeRailPost", Vector3.new(1.2, 3.6, 1.2), hp, bridgeWood, Enum.Material.Wood)
							post.CFrame = CFrame.lookAt(hp, hp + flat) * CFrame.new(0, 1.65, 0)
						end
						local posts = math.max(1, math.floor(curbLen / 20))
						for pIdx = 1, posts do
							local pt = a:Lerp(b, pIdx / (posts + 1)) + curbOffset
							local post = decor(curbGroup, "BridgeRailPost", Vector3.new(1.1, 3.6, 1.1), pt, bridgeWood, Enum.Material.Wood)
							post.CFrame = CFrame.lookAt(pt, b + curbOffset) * CFrame.new(0, 1.65, 0)
						end
					elseif curbMode == "FOUNDRY_RAIL" then
						-- Sootwright iron handrail: a low riveted kerb, a top rail and a mid rail on posts.
						curb.Size = Vector3.new(1.4, 1.2, curbLen)
						curb.CFrame = CFrame.lookAt(mid + curbOffset, b + curbOffset) * CFrame.new(0, 0.2, 0)
						local railLen = math.max(1, delta.Magnitude - 2)
						local top = decor(curbGroup, "BridgeHandrail", Vector3.new(0.6, 0.6, railLen), mid + curbOffset, sootIronDark, Enum.Material.Metal)
						top.CFrame = CFrame.lookAt(mid + curbOffset, b + curbOffset) * CFrame.new(0, 3.4, 0)
						local midRail = decor(curbGroup, "BridgeMidRail", Vector3.new(0.4, 0.4, railLen), mid + curbOffset, sootRust, Enum.Material.Metal)
						midRail.CFrame = CFrame.lookAt(mid + curbOffset, b + curbOffset) * CFrame.new(0, 2.0, 0)
						local posts = math.max(2, math.floor(railLen / 8) + 1)
						for pIdx = 0, posts - 1 do
							local pt = a:Lerp(b, 0.02 + 0.96 * pIdx / (posts - 1)) + curbOffset
							local post = decor(curbGroup, "BridgeRailPost", Vector3.new(0.7, 3.4, 0.7), pt, sootIronDark, Enum.Material.Metal)
							post.CFrame = CFrame.lookAt(pt, b + curbOffset) * CFrame.new(0, 1.9, 0)
							local knob = decor(curbGroup, "BridgeNewelCap", Vector3.new(0.9, 0.5, 0.9), pt, sootBrass, Enum.Material.Metal)
							knob.CFrame = CFrame.lookAt(pt, b + curbOffset) * CFrame.new(0, 3.85, 0)
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

	-- Fill lanterns under the vault; a closed cavern with an oculus (Skylight) keeps fewer, so its own glows
	-- carry the light and the floor stays within its light budget.
	local rotKeep = layout.Authored == "fungal:9"
	local heartHollow = layout.Authored == "fungal:10"
	local lanternStep = if rotKeep then 260 elseif heartHollow then 280 elseif sky then (if math.max(width, depth) > 540 then 185 else 150) else 100
	local lanternIdx = 0
	-- Open-sky Hollin floors light themselves with their own lanterns (TowerSetPieces/CorruptedGrove).
	if (not pathStyle or pathStyle.ShowVaultLanterns ~= false) and not hollin then
		for x = -width / 2 + 50, width / 2 - 40, lanternStep do
			for z = -depth / 2 + 50, depth / 2 - 40, lanternStep do
				lanternIdx += 1
				local lightColor = if rotKeep
					then (if lanternIdx % 2 == 1 then theme.LightColor else Color3.fromRGB(152, 82, 238))
					elseif heartHollow
					then (if lanternIdx % 2 == 1 then Color3.fromRGB(196, 82, 245) else Color3.fromRGB(96, 238, 255))
					else theme.LightColor
				local lamp = decor(model, "VaultLantern", Vector3.new(1, 1, 1), origin + Vector3.new(x, 42, z), lightColor, Enum.Material.SmoothPlastic, 1)
				local light = Instance.new("PointLight")
				light.Range = if rotKeep or heartHollow then 68 else 60
				light.Brightness = if rotKeep then 0.75 elseif heartHollow then 0.7 else 0.55
				light.Color = lightColor
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
