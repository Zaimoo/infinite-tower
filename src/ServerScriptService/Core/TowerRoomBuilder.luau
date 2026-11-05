--!strict
-- Part 2/4 Tower Room Builder: constructs all 50 playable floors across 10 biomes
-- and 5 architectural layout variants per biome while preserving safe arrival,
-- camera enclosure, multi-tier traversal, sanctuary extraction, and travel pedestals.
local Config = require(game.ReplicatedStorage.Shared.Config.TowerFloorConfig)
local Layout = require(game.ReplicatedStorage.Shared.Config.TowerLayout)
local BiomeAssets = require(script.Parent.TowerBiomeAssets)
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
local WalkwayExemptKinds = { BridgeCurb = true, RampArch = true }
local WalkwayExemptNames = { BasinCentralCauseway = true, BasinCausewayInlay = true }
local WalkwayEdgeTrim = { TerraceMasonryBand = true, TerraceSideBand = true }
function Builder.WalkwayHitTest(model: Instance, origin: Vector3, index: number): (BasePart) -> boolean
	local boxes = {}
	for _, lane in Layout.Lanes(index) do
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

function Builder.Build(id: number, generation: number): any
	assert(Config.IsFloorId(id))
	local floorSpec = assert(Config.Get(id))
	local theme = Themes[floorSpec.BiomeId] or Themes.verdant_ruins
	local origin = Builder.Origin(id)
	local idx = floorSpec.IndexInBiome
	local layout = Layout.Get(idx)
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

	-- Base sub-floor and sky/cavern enclosure
	part(model, "Ground", Vector3.new(width, 4, depth), origin + Vector3.new(0, layout.Bottom - 6, 0), theme.SubFloorColor, theme.GroundMaterial)
	for _, side in { -1, 1 } do
		part(model, "WallX", Vector3.new(6, height + 16, depth + 12), origin + Vector3.new(side * (width / 2 + 3), height / 2 - 8, 0), theme.WallColor, theme.WallMaterial)
		part(model, "WallZ", Vector3.new(width, height + 16, 6), origin + Vector3.new(0, height / 2 - 8, side * (depth / 2 + 3)), theme.WallColor, theme.WallMaterial)
	end
	-- Vaulted ceiling with natural environmental skylight aperture (allows sunlight & sunrays to enter)
	local openW = width * 0.54
	local openD = depth * 0.54
	local borderX = (width - openW) / 2
	local borderZ = (depth - openD) / 2

	for _, sz in { -1, 1 } do
		local ceilZ = decor(model, "VaultCeilingZ", Vector3.new(width + 12, 6, borderZ + 8), origin + Vector3.new(0, height + 3, sz * (depth / 2 - borderZ / 2)), theme.WallColor, theme.WallMaterial)
		ceilZ.CastShadow = false
	end
	for _, sx in { -1, 1 } do
		local ceilX = decor(model, "VaultCeilingX", Vector3.new(borderX + 8, 6, openD), origin + Vector3.new(sx * (width / 2 - borderX / 2), height + 3, 0), theme.WallColor, theme.WallMaterial)
		ceilX.CastShadow = false
	end
	for _, sz in { -1, 1 } do
		decor(model, "SkylightRimZ", Vector3.new(openW + 12, 3.5, 4), origin + Vector3.new(0, height + 1, sz * (openD / 2)), theme.TrimColor, theme.TrimMaterial)
	end
	for _, sx in { -1, 1 } do
		decor(model, "SkylightRimX", Vector3.new(4, 3.5, openD + 12), origin + Vector3.new(sx * (openW / 2), height + 1, 0), theme.TrimColor, theme.TrimMaterial)
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
		if name ~= "Sanctuary" and name ~= "Basin" then
			decor(model, "TerraceCenterMosaic", Vector3.new(terrace.Width * 0.62, 0.12, terrace.Depth * 0.62), topCenter + Vector3.new(0, 0.08, 0), theme.TrimColor, theme.TrimMaterial)
			decor(model, "TerraceInnerField", Vector3.new(terrace.Width * 0.52, 0.14, terrace.Depth * 0.52), topCenter + Vector3.new(0, 0.16, 0), theme.GroundColor, theme.GroundMaterial)
		end

		if name ~= "Sanctuary" then
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
	local function landing(pad: any, id: string)
		local a=origin+Vector3.new(pad.AX,pad.AY,pad.AZ)
		local b=origin+Vector3.new(pad.BX,pad.BY,pad.BZ)
		local p=part(model,"TraversalLanding",Vector3.new(pad.Width,2,(b-a).Magnitude),(a+b)/2,theme.TrimColor,theme.TrimMaterial)
		-- Top sits 0.05 above the terrace/ramp planes so coplanar faces never z-fight at joins.
		p.CFrame=CFrame.lookAt((a+b)/2,b)*CFrame.new(0,-0.95,0)
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
		landing(link.LandingA,link.Id)
		landing(link.LandingB,link.Id)

		if link.From == "Crossing" and link.To == "Apex" then
			local steps = math.max(1, math.ceil(math.abs(delta.Y)))
			for step = 1, steps do
				local t = (step - 0.5) / steps
				local top = a.Y + delta.Y * step / steps
				local center = a + flat * t
				local tread = part(
					model,
					"GrandStairTread",
					Vector3.new(link.Width, 2, flat.Magnitude / steps + 0.15),
					Vector3.new(center.X, top - 1, center.Z),
					theme.TrimColor,
					theme.TrimMaterial
				)
				tread.CFrame = CFrame.lookAt(tread.Position, tread.Position + flat)
				structure(tread,link.Id)
				local runner = decor(model, "GrandStairRunner", Vector3.new(link.Width * 0.36, 0.12, flat.Magnitude / steps + 0.2), Vector3.new(center.X, top + 0.08, center.Z), theme.AccentColor, theme.TrimMaterial)
				runner.CFrame = CFrame.lookAt(runner.Position, runner.Position + flat)
			end
		else
			local ramp = part(model, "TraversalRamp", Vector3.new(link.Width, 2, delta.Magnitude), mid, theme.TrimColor, theme.TrimMaterial)
			ramp.CFrame = CFrame.lookAt(mid, b) * CFrame.new(0, -1, 0)
			structure(ramp,link.Id)
			local inlay = decor(model, "RampPathInlay", Vector3.new(link.Width * 0.55, 0.12, delta.Magnitude), mid, theme.AccentColor, theme.GroundMaterial)
			inlay.CFrame = CFrame.lookAt(mid, b) * CFrame.new(0, 0.08, 0)
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
			local ramp = part(model, "BasinReturnRamp", Vector3.new(link.Width, 2, (b - a).Magnitude), (a + b) / 2, theme.GroundColor, theme.GroundMaterial)
			ramp.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, -1, 0)
			structure(ramp,link.Id)
			landing(link.LandingA,link.Id)
			landing(link.LandingB,link.Id)
	end

	BiomeAssets.Build(model, origin, floorSpec.BiomeId, idx, layout, theme)

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
		decor(model, "SanctuarySideWall", Vector3.new(2.5, 4.5, safe.Depth - 8), origin + Vector3.new(side * (halfW - 1), 10.2, safe.Z), theme.TrimColor, theme.TrimMaterial)
	end

	-- Phase H: a glowing square traces the ARRIVAL zone exactly (the Sanctuary's footprint), on a darker
	-- trim band, with a gap in the front edge for the exit, framed by two small pylons.
	local rimY = safe.Y + 0.18
	local glowColor = theme.LightColor
	local bandColor = theme.TrimColor:Lerp(Color3.new(0, 0, 0), 0.45)
	local function rim(name: string, size: Vector3, at: Vector3)
		decor(model, name .. "Band", Vector3.new(size.X + (if size.X > size.Z then 1.2 else 1.2), 0.25, size.Z + (if size.Z > size.X then 1.2 else 1.2)), origin + at - Vector3.new(0, 0.06, 0), bandColor, theme.TrimMaterial)
		decor(model, name, size, origin + at, glowColor, Enum.Material.Neon, 0.1)
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
			local at = Vector3.new(sx * halfW, safe.Y, safe.Z + sz * halfD)
			decor(model, "SanctuaryBeaconPylon", Vector3.new(3, 4, 3), origin + at + Vector3.new(0, 2, 0), theme.TrimColor, theme.TrimMaterial)
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
 for _,placement in Layout.Placements(require(game.ReplicatedStorage.Shared.Config.MobCatalog).Biomes[math.ceil(id/5)],idx) do
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
