--!strict
-- Reference-guided, high-detail procedural environment & architectural kits for all 10 biomes.
-- Every decorative part has CanCollide=false, CanQuery=false, CanTouch=false so it never
-- obstructs HeroNavigation raycasts, pathfinding, or grounded mob spawn checks.
-- Once the Tower Biome Kit (Blender meshes, ServerStorage.TowerBiomeKit) is imported, the trees, spires,
-- arches, statues, mushrooms, cliffs, islands and clutter are drawn with its sculpted meshes instead; the
-- part-built versions below stay as the fallback. Solid pieces keep their part as an invisible collider.
local PropClearance = require(script.Parent.TowerPropClearance)
local KitProps = require(script.Parent.TowerKitProps)
local TowerLayout = require(game.ReplicatedStorage.Shared.Config.TowerLayout)
local Kit = require(game.ReplicatedStorage.Shared.Config.TowerBiomeKit)
local InfernalSetPieces = require(script.Parent.TowerSetPieces.InfernalFoundry)
local InfernalFloor24 = require(script.Parent.TowerSetPieces.InfernalFloor24)
local InfernalFloor25 = require(script.Parent.TowerSetPieces.InfernalFloor25)
local CorruptedSetPieces = require(script.Parent.TowerSetPieces.CorruptedGrove)
local CorruptedFloor32 = require(script.Parent.TowerSetPieces.CorruptedFloor32)
local Assets = {}
local V = Vector3.new
local rgb = Color3.fromRGB
local gold = rgb(218, 178, 88)
local darkGold = rgb(168, 132, 58)

local CampExemptKinds = { RampArch = true, HollinStile = true, GlassArchSpan = true, PortcullisGate = true }

-- True when a part reaches into an enemy camp. Mobs are grounded by raycasting downward, so props
-- overlapping a camp obstruct navigation and embed mobs. Used as a TowerPropClearance hit test.
function Assets.CampHitTest(origin: Vector3, layout: any): (BasePart) -> boolean
	local campOffsets = { { 0, 0 }, { -18, 12 }, { 18, 12 }, { -12, -16 }, { 12, -16 } }
	return function(inst: BasePart): boolean
		local p: Instance? = inst
		while p do
			local kind = p:GetAttribute("PropKind")
			if typeof(kind) == "string" and CampExemptKinds[kind] then
				return false
			end
			p = p.Parent
		end
		local instPos = inst.Position
		local half = inst.Size * 0.5
		for _, camp in layout.Camps do
			local campCenter = origin + V(camp.X, camp.Y, camp.Z)
			-- Vertical overlap: camp ground level - 2 up to camp ground level + 22
			if (instPos.Y - half.Y) <= (campCenter.Y + 22) and (instPos.Y + half.Y) >= (campCenter.Y - 2) then
				-- The part centre is within 34 studs of the camp centre
				local cdx = instPos.X - campCenter.X
				local cdz = instPos.Z - campCenter.Z
				if cdx * cdx + cdz * cdz <= 34 * 34 then
					return true
				end
				-- Or the part's box reaches a mob slot
				for slot = 1, math.min(camp.Size, #campOffsets) do
					local o = campOffsets[slot]
					local lp = inst.CFrame:PointToObjectSpace(campCenter + V(o[1], 2, o[2]))
					if math.abs(lp.X) <= half.X + 7 and math.abs(lp.Y) <= half.Y + 6 and math.abs(lp.Z) <= half.Z + 7 then
						return true
					end
				end
			end
		end
		return false
	end
end

-- Prop kinds that hang in the air by design (rings, chains, gears, sky pieces); the settle pass skips them.
Assets.AirborneKinds = table.freeze({
	Ring = true, Chain = true, Cogwheel = true, Orrery = true, Eclipse = true, CavernSkylight = true, CeilingRoots = true,
	GalaxyPortal = true, LotusPortal = true, CorruptionCrescent = true, AirborneVineCable = true,
	-- Floor 31's wicker lanterns hang from trees, the stile and the lean-to (TowerSetPieces/CorruptedGrove).
	WoodcuttersLantern = true, LastGreenLantern = true, CopseLantern = true, StileLantern = true,
	-- Floor 32's orchard lanterns hang from the Orchard Gate, Grafters' Yard and cooperage shed.
	OrchardGateLantern = true, YardLantern = true, VatsLantern = true,
})

-- field: the floor's TowerTerrain field on a natural floor (the kit imported), else nil.
function Assets.Build(parent: Instance, origin: Vector3, biome: string, index: number, layout: any, theme: any, field: any?)
	local kit = Instance.new("Model")
	kit.Name = "BiomeAssets"
	kit:SetAttribute("BiomeId", biome)
	kit:SetAttribute("Variant", index)

	local w, d, h = layout.Width, layout.Depth, layout.Height
	-- Props stand on real ground: the chasm floor is the top of the Ground slab, 4 studs below
	-- layout.Bottom (TowerRoomBuilder). The elemental sea surface sits at layout.Bottom itself.
	local seaLevel = layout.Bottom
	local bottom = layout.Bottom - 4
	local scale = 0.85 + index * 0.09
	-- Authored Corrupted Grove floors (31-35) build their own set pieces (TowerSetPieces/CorruptedGrove) and
	-- skip the biome's generic thorn arches, corruption dais and citadel wings.
	local corruptedFloor = type(layout.Authored) == "string" and string.sub(layout.Authored, 1, 10) == "corrupted:"
	local accent = theme.LightColor
	local cliffColor = theme.CliffColor or theme.WallColor
	local cliffMat = theme.CliffMaterial or Enum.Material.Rock
	local liquidColor = theme.LiquidColor or accent

	-- Tower Biome Kit: only when every template is imported, so a floor never mixes meshes and parts.
	local biomeKit = Kit.Biomes[biome]
	local kitOn = biomeKit ~= nil and KitProps.Ready()
	-- Natural floor: terrain carries the chasm, cliffs, islands and seas, and the kit is scattered over it as
	-- an ecosystem (section 7) instead of the part-built rows and clutter beds.
	local natural = kitOn and field ~= nil
	kit:SetAttribute("Natural", natural)
	local baseResolve = KitProps.Resolver(biome, theme)
	local resolveRole = if layout.Authored == "fungal:9"
		then function(role: string)
			if role == "GLOW" then
				return rgb(182, 245, 74), Enum.Material.Neon, 0
			elseif role == "BULB" then
				return rgb(212, 255, 96), Enum.Material.Neon, 0
			elseif role == "CAP" then
				return rgb(96, 48, 172), Enum.Material.SmoothPlastic, 0
			elseif role == "ACCENT" then
				return rgb(142, 76, 224), Enum.Material.Slate, 0
			elseif role == "MOSS" then
				return rgb(76, 62, 118), Enum.Material.Grass, 0
			elseif role == "CRYSTAL" then
				return rgb(174, 242, 88), Enum.Material.Glass, 0.2
			elseif role == "ALT" then
				return rgb(208, 226, 172), Enum.Material.SmoothPlastic, 0
			end
			return baseResolve(role)
		end
		elseif layout.Authored == "fungal:10"
		then function(role: string)
			if role == "GLOW" then
				return rgb(96, 245, 255), Enum.Material.Neon, 0
			elseif role == "BULB" then
				return rgb(224, 132, 255), Enum.Material.Neon, 0
			elseif role == "CAP" then
				return rgb(92, 44, 182), Enum.Material.SmoothPlastic, 0
			elseif role == "STEM" then
				return rgb(214, 204, 236), Enum.Material.SmoothPlastic, 0
			elseif role == "MOSS" then
				return rgb(68, 48, 112), Enum.Material.Grass, 0
			elseif role == "CRYSTAL" then
				return rgb(110, 242, 255), Enum.Material.Glass, 0.2
			elseif role == "STONE" then
				return rgb(96, 74, 138), Enum.Material.Cobblestone, 0
			elseif role == "TRIM" then
				return rgb(62, 56, 94), Enum.Material.Slate, 0
			elseif role == "ACCENT" then
				return rgb(164, 78, 238), Enum.Material.Slate, 0
			end
			return baseResolve(role)
		end
		else baseResolve
	kit:SetAttribute("KitMeshes", kitOn)
	-- Boxes (cliffs, ledges, islands) that get a kit rock fitted over them once the floor is built.
	local KIT_CLIFF = { "CliffRockA", "CliffRockB" }
	local KIT_SHELF = { "ChasmIsland" }
	local kitDress: { [string]: { string } } = {
		PerimeterSkyPeak = KIT_CLIFF, CornerHorizonMassif = KIT_CLIFF, CornerMidBastion = KIT_CLIFF,
		NorthHorizonPeak = KIT_CLIFF, NorthCitadelWingCliff = KIT_CLIFF, StormPeakCrag = KIT_CLIFF,
		InteriorObsidianCrag = KIT_CLIFF, VolcanoCalderaSlope = KIT_CLIFF,
		-- Flat-topped: landmarks stand on these.
		PerimeterCliffBase = KIT_SHELF, PerimeterCliffLedge = KIT_SHELF, NorthHorizonFoothill = KIT_SHELF,
		InteriorChasmIslandBase = KIT_SHELF, ApexShelfMassif = KIT_SHELF,
	}
	local pendingDress: { BasePart } = {}

	-- Every compound prop (tree, spire, arch, clutter cluster, island and what stands on it) is its own
	-- Model tagged PropKind, so clearance removes a prop whole and never leaves floating pieces behind.
	-- A group opened inside another group joins it: whatever stands on a support goes with that support.
	local currentParent: Instance = kit
	local function group(kind: string, build: () -> ())
		if currentParent ~= kit then
			build()
			return
		end
		local prop = Instance.new("Model")
		prop.Name = kind
		prop:SetAttribute("PropKind", kind)
		currentParent = prop
		build()
		currentParent = kit
		prop.Parent = kit
	end

	local function block(name: string, size: Vector3, pos: Vector3, color: Color3?, material: Enum.Material?, shape: Enum.PartType?, trans: number?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Position = origin + pos
		p.Anchored = true
		-- Structural scenery and physical props participate in collision & queries; liquids, flush ground markings, and misty VFX stay non-solid.
		local solid = name:find("Cliff") or name:find("Wall") or name:find("Island")
			or name:find("Crag") or name:find("Bastion") or name:find("Massif")
			or name:find("HorizonPeak") or name:find("HorizonFoothill") or name:find("SkyPeak")
			or name:find("ArchPier") or name:find("Monolith") or name:find("Obelisk")
			or name:find("TempleTier") or name:find("CitadelKeep") or name:find("AltarDais")
			or name:find("Throne") or name == "SpirePlinth" or name == "SpireShaft"
			or name == "SpireUpperTier" or name == "LibraryPilaster"
		local isLiquid = name:find("Liquid") or name:find("Water")
			or name:find("Lava") or name:find("Sea") or name:find("Pool")
			or name:find("River") or name:find("Stream") or name:find("CrucibleLava")
			or name:find("Shoal") or name:find("BubbleGlow") or name:find("CraterMagma")
			or (not name:find("Rimefall") and (name:find("Fall") or name:find("Cascade")))
		local isNonSolidFx = name:find("Track") or name:find("Rut")
			or name:find("HoleRing") or name:find("HoleWater")
			or name:find("Aurora") or name:find("LightShaft") or name:find("Sunbeam")
			or name:find("Foam") or name:find("Mist") or name:find("GlowSeam")
			or name:find("Vein") or name:find("Silhouette")
			or (trans ~= nil and trans >= 0.45)
		p.CanCollide = (not isLiquid) and (not isNonSolidFx)
		p.CanTouch = false
		p.CanQuery = p.CanCollide
		p:SetAttribute("SolidScenery", solid ~= nil)
		p.CastShadow = false
		p.Color = color or theme.TrimColor
		p.Material = material or theme.TrimMaterial
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if shape then p.Shape = shape end
		if trans then p.Transparency = trans end
		-- Bloom safeguard for liquid blocks: liquid surfaces (water, lava, falls, pools, rivers, mist)
		-- must NEVER have Neon material so bloom does NOT trigger on liquid blocks.
		if isLiquid and not name:find("Rimefall") then
			if p.Material == Enum.Material.Neon then
				p.Material = Enum.Material.SmoothPlastic
			end
			p.Transparency = math.clamp(p.Transparency, 0.15, 0.65)
		elseif kitOn and kitDress[name] then
			table.insert(pendingDress, p)
		elseif p.Material == Enum.Material.Neon then
			-- Bloom control for non-liquid surfaces: large Neon surfaces (sunbeams, portals, auroras)
			-- blow out the screen, so render them as translucent plastic; small Neon accents are dimmed slightly.
			local largest = math.max(size.X, size.Y, size.Z)
			if largest > 8 then
				p.Material = Enum.Material.SmoothPlastic
				p.Transparency = math.max(p.Transparency, 0.35)
			else
				p.Color = p.Color:Lerp(Color3.new(0, 0, 0), 0.25)
			end
		end
		p.Parent = currentParent
		return p
	end

	local function wedge(name: string, size: Vector3, cf: CFrame, color: Color3?, material: Enum.Material?, trans: number?): WedgePart
		local p = Instance.new("WedgePart")
		p.Name = name
		p.Size = size
		p.CFrame = CFrame.new(origin) * cf
		p.Anchored = true
		p.CanCollide = (trans == nil or trans < 0.45)
		p.CanTouch = false
		p.CanQuery = p.CanCollide
		p.CastShadow = false
		p.Color = color or cliffColor
		p.Material = material or cliffMat
		if trans then p.Transparency = trans end
		p.Parent = currentParent
		return p
	end

	-- Places a kit template at a room-local CFrame (origin = footprint centre on the ground, front +Z).
	-- A number scales uniformly (times the template's RefScale); a Vector3 scales per axis.
	local function kitAt(name: string, cf: CFrame, scale: Vector3 | number, override: KitProps.Override?): Model?
		local s: Vector3 = if typeof(scale) == "number" then Vector3.one * (scale * (Kit.RefScale[name] or 1)) else scale
		return KitProps.Place(currentParent, name, CFrame.new(origin) * cf, s, resolveRole, override)
	end
	-- A stable yaw per spot, so repeated props don't all face the same way.
	local function yawAt(at: Vector3): number
		return math.rad((at.X * 12.9898 + at.Z * 78.233) % 360)
	end
	-- Turns a part into an invisible collider/support for the kit mesh drawn over it.
	local function ghost(p: BasePart)
		p.Transparency = 1
		p.CastShadow = false
		p:SetAttribute("KitCollider", true)
	end

	local function beam(name: string, a: Vector3, b: Vector3, thickness: number, color: Color3?, material: Enum.Material?, trans: number?): Part
		local delta = b - a
		local len = delta.Magnitude
		if len < 0.05 then len = 0.05 end
		local p = block(name, V(thickness, thickness, len), (a + b) / 2, color, material, nil, trans)
		p.CFrame = CFrame.lookAt(origin + (a + b) / 2, origin + b)
		return p
	end

	local function cyl(name: string, at: Vector3, radius: number, height: number, color: Color3?, material: Enum.Material?, trans: number?): Part
		local p = block(name, V(height, radius * 2, radius * 2), at, color, material, Enum.PartType.Cylinder, trans)
		p.CFrame = CFrame.new(origin + at) * CFrame.Angles(0, 0, math.pi / 2)
		return p
	end

	local function orb(name: string, at: Vector3, size: Vector3, color: Color3?, material: Enum.Material?, trans: number?): Part
		if math.abs(size.X - size.Y) > 0.05 or math.abs(size.Y - size.Z) > 0.05 then
			local p = block(name, size, at, color, material, Enum.PartType.Block, trans)
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
			return p
		end
		return block(name, size, at, color, material, Enum.PartType.Ball, trans)
	end

	local function pointLight(partInst: Instance, color: Color3, brightness: number, range: number)
		local l = Instance.new("PointLight")
		l.Color = color
		l.Brightness = brightness * 0.5
		l.Range = range * 0.75
		l.Shadows = false
		l.Parent = partInst
	end

	local function ring(name: string, at: Vector3, radius: number, thickness: number, color: Color3, mat: Enum.Material?, tilt: CFrame?, startAngle: number?, endAngle: number?, segCount: number?)
		group("Ring", function()
			local cf = CFrame.new(at) * (tilt or CFrame.identity)
			local sAng, eAng = startAngle or 0, endAngle or math.pi * 2
			local segments = segCount or (if name == "IronChainLink" then 6 else 18)
			for i = 0, segments - 1 do
				local a = sAng + (eAng - sAng) * i / segments
				local b = sAng + (eAng - sAng) * (i + 1) / segments
				beam(
					name,
					cf:PointToWorldSpace(V(math.cos(a) * radius, math.sin(a) * radius, if i % 2 == 1 then 0.03 else 0)),
					cf:PointToWorldSpace(V(math.cos(b) * radius, math.sin(b) * radius, if i % 2 == 1 then 0.03 else 0)),
					if i % 2 == 1 then thickness * 0.94 else thickness,
					color,
					mat or Enum.Material.Metal
				)
			end
		end)
	end

	local function arch(at: Vector3, span: number, pierH: number, depthSize: number, color: Color3?, mat: Enum.Material?, rotY: number?)
		if kitOn then
			-- Kit arch: a plinth and stacked masonry courses per pier (tiled, so tall ramp-arch piers keep
			-- their proportions) under a crown scaled to the span. The piers stay solid as hidden colliders.
			group("Arch", function()
				local cf = CFrame.new(at) * CFrame.Angles(0, rotY or 0, 0)
				local trim = { TRIM = { Color = color or theme.TrimColor, Material = mat or theme.TrimMaterial } }
				local kd = depthSize / 6.5
				local baseH = KitProps.Size("ArchPierBase").Y
				local segH = KitProps.Size("ArchPierSegment").Y
				local rise = math.max(pierH - baseH, 1)
				local courses = math.max(1, math.round(rise / segH))
				for _, s in { -1, 1 } do
					local pier = block("ArchPier", V(depthSize * 0.85, pierH, depthSize), V(0, 0, 0), color, mat)
					pier.CFrame = CFrame.new(origin) * cf * CFrame.new(s * span / 2, pierH / 2, 0)
					ghost(pier)
					local foot = cf * CFrame.new(s * span / 2, 0, 0)
					kitAt("ArchPierBase", foot, V(kd, 1, kd), trim)
					for c = 1, courses do
						kitAt("ArchPierSegment", foot * CFrame.new(0, baseH + (c - 1) * rise / courses, 0), V(kd, rise / courses / segH, kd), trim)
					end
				end
				kitAt("ArchCrown", cf * CFrame.new(0, pierH, 0), V(span / 24, span / 24, kd), trim)
			end)
			return
		end
		group("Arch", function()
			local c = color or theme.TrimColor
			local m = mat or theme.TrimMaterial
			local cf = CFrame.new(at) * CFrame.Angles(0, rotY or 0, 0)
			for _, s in { -1, 1 } do
				local pierPos = cf:PointToWorldSpace(V(s * span / 2, pierH / 2, 0))
				local pier = block("ArchPier", V(depthSize * 0.85, pierH, depthSize), pierPos, c, m)
				pier.CFrame = CFrame.new(origin) * cf * CFrame.new(s * span / 2, pierH / 2, 0)
				local base = block("ArchPierBase", V(depthSize * 1.15, 3.5, depthSize * 1.25), V(0, 0, 0), c, m)
				base.CFrame = CFrame.new(origin) * cf * CFrame.new(s * span / 2, 1.75, 0)
				local cap = block("ArchPierCap", V(depthSize * 1.2, 2.5, depthSize * 1.3), V(0, 0, 0), theme.AccentColor, m)
				cap.CFrame = CFrame.new(origin) * cf * CFrame.new(s * span / 2, pierH, 0)
			end
			for i = 0, 8 do
				local ang = math.pi * i / 8
				local vx = math.cos(ang) * (span / 2)
				local vy = pierH + math.sin(ang) * (span * 0.38)
				local vPart = block("ArchVoussoir", V(span * 0.19, depthSize * 0.65, depthSize), V(0, 0, 0), c, m)
				vPart.CFrame = CFrame.new(origin) * cf * CFrame.new(vx, vy, 0) * CFrame.Angles(0, 0, ang - math.pi / 2)
			end
		end)
	end

	local function waterfall(at: Vector3, fallWidth: number, fallHeight: number, color: Color3, rotY: number?)
		group("Waterfall", function()
			local cf = CFrame.new(at) * CFrame.Angles(0, rotY or 0, 0)
			local main = block("CascadingFall", V(fallWidth, fallHeight, 2.4), V(0, 0, 0), color, Enum.Material.SmoothPlastic, nil, 0.45)
			main.CFrame = CFrame.new(origin) * cf * CFrame.new(0, fallHeight / 2, 0)
			local core = block("FallFoamCore", V(fallWidth * 0.5, math.max(1, fallHeight - 0.6), 1.4), V(0, 0, 0), rgb(215, 230, 240), Enum.Material.SmoothPlastic, nil, 0.65)
			core.CFrame = CFrame.new(origin) * cf * CFrame.new(0, fallHeight / 2 + 0.15, 0.75)
			local mist = orb("FallSplashMist", cf:PointToWorldSpace(V(0, 2, 1.5)), V(fallWidth * 0.85, 3.5, 4.5), rgb(210, 230, 245), Enum.Material.SmoothPlastic, 0.88)
			pointLight(mist, color, 0.15, 14)
		end)
	end

	local function spire(at: Vector3, height: number, widthBase: number, color: Color3, glow: Color3, isCrystal: boolean?)
		if kitOn and biomeKit then
			group("Spire", function()
				-- The shaft and plinth stay solid as hidden colliders.
				ghost(block("SpirePlinth", V(widthBase * 1.45, 5, widthBase * 1.45), at + V(0, 2.5, 0), color))
				ghost(block("SpireShaft", V(widthBase, height, widthBase), at + V(0, height / 2 + 3, 0), color))
				local o = {
					TRIM = { Color = color, Material = theme.TrimMaterial },
					GLOW = { Color = glow },
					STONE = if isCrystal then nil else { Color = color },
				}
				if isCrystal then
					kitAt("CrystalSpire", CFrame.new(at) * CFrame.Angles(0, yawAt(at), 0), V(widthBase / 11, height / 32, widthBase / 11), { CRYSTAL = { Color = color } })
				else
					local name = biomeKit.Spire
					local refH = if name == "ObsidianSpire" then 42 elseif name == "FurnaceStack" then 40 else 40
					local refW = if name == "ObsidianSpire" then 12 elseif name == "FurnaceStack" then 13 else 10
					kitAt(name, CFrame.new(at) * CFrame.Angles(0, yawAt(at), 0), V(widthBase / refW, height / refH, widthBase / refW), o)
				end
			end)
			return
		end
		group("Spire", function()
			local mat = if isCrystal then Enum.Material.Ice else theme.TrimMaterial
			block("SpirePlinth", V(widthBase * 1.45, 5, widthBase * 1.45), at + V(0, 2.5, 0), color, mat)
			block("SpireShaft", V(widthBase, height, widthBase), at + V(0, height / 2 + 3, 0), color, mat, nil, if isCrystal then 0.16 else nil)
			block("SpireUpperTier", V(widthBase * 0.72, height * 0.45, widthBase * 0.72), at + V(0, height * 0.95, 0), color, mat, nil, if isCrystal then 0.14 else nil)
			for _, rot in { 0, math.pi / 2, math.pi, math.pi * 1.5 } do
				wedge(
					"SpirePeakFacet",
					V(widthBase * 0.72, height * 0.32, widthBase * 0.36),
					CFrame.new(at + V(0, height * 1.18 + height * 0.16, 0)) * CFrame.Angles(0, rot, 0) * CFrame.new(0, 0, -widthBase * 0.18),
					if isCrystal then glow else color,
					if isCrystal then Enum.Material.Neon else mat,
					if isCrystal then 0.18 else nil
				)
			end
			for _, s in { -1, 1 } do
				block("SpireRuneX", V(0.5, height * 0.72, 1.6), at + V(s * (widthBase * 0.52), height * 0.55, 0), glow, Enum.Material.Neon, nil, 0.12)
				block("SpireRuneZ", V(1.6, height * 0.72, 0.5), at + V(0, height * 0.55, s * (widthBase * 0.52)), glow, Enum.Material.Neon, nil, 0.12)
			end
		end)
	end

	local function mushroom(at: Vector3, mScale: number, corrupted: boolean)
		local rotKeep = layout.Authored == "fungal:9"
		local heartHollow = layout.Authored == "fungal:10"
		if kitOn then
			group("Mushroom", function()
				kitAt("GiantMushroom", CFrame.new(at) * CFrame.Angles(0, yawAt(at), 0), mScale, if corrupted
					then { CAP = { Color = rgb(138, 36, 118) }, GLOW = { Color = rgb(235, 75, 185) } }
					elseif rotKeep
					then { CAP = { Color = rgb(96, 48, 172) }, GLOW = { Color = rgb(182, 245, 74) }, BULB = { Color = rgb(212, 255, 96) } }
					elseif heartHollow
					then { CAP = { Color = rgb(92, 44, 182) }, GLOW = { Color = rgb(96, 245, 255) }, BULB = { Color = rgb(224, 132, 255) }, STEM = { Color = rgb(214, 204, 236) } }
					else { CAP = { Color = rgb(68, 48, 168) }, GLOW = { Color = rgb(95, 245, 235) } })
			end)
			return
		end
		group("Mushroom", function()
			local stemH = 30 * mScale
			local capR = 24 * mScale
			local capColor = if corrupted then rgb(138, 36, 118) elseif rotKeep then rgb(96, 48, 172) elseif heartHollow then rgb(92, 44, 182) else rgb(68, 48, 168)
			local spotColor = if corrupted then rgb(255, 95, 195) elseif rotKeep then rgb(212, 255, 96) elseif heartHollow then rgb(224, 132, 255) else rgb(115, 225, 255)
			local gillColor = if corrupted then rgb(235, 75, 185) elseif rotKeep then rgb(182, 245, 74) elseif heartHollow then rgb(96, 245, 255) else rgb(95, 245, 235)
			local tiltX = (at.X > 0 and -1 or 1) * 4 * mScale
			local mid = at + V(tiltX * 0.5, stemH * 0.5, 0)
			local top = at + V(tiltX, stemH, 0)
			beam("MushroomStemLower", at, mid, 5.5 * mScale, rgb(145, 142, 175), Enum.Material.SmoothPlastic)
			beam("MushroomStemUpper", mid, top, 4.0 * mScale, rgb(165, 162, 195), Enum.Material.SmoothPlastic)
			cyl("MushroomStemRing", mid + V(0, 2 * mScale, 0), 4.5 * mScale, 1.3 * mScale, gillColor, Enum.Material.Neon, 0.25)
			orb("MushroomCapDome", top + V(0, 2 * mScale, 0), V(capR * 2, 12 * mScale, capR * 2), capColor, Enum.Material.SmoothPlastic)
			orb("MushroomCapApex", top + V(0, 6 * mScale, 0), V(capR * 1.18, 7.5 * mScale, capR * 1.18), capColor, Enum.Material.SmoothPlastic)
			cyl("LuminousGills", top - V(0, 0.5 * mScale, 0), capR * 0.88, 1.5 * mScale, gillColor, Enum.Material.Neon, 0.12)
			for k = 1, 8 do
				local a = k * math.pi / 4
				local spotAt = top + V(math.cos(a) * capR * 0.58, 5.2 * mScale, math.sin(a) * capR * 0.58)
				orb("BioluminescentSpot", spotAt, V(3.4 * mScale, 1.5 * mScale, 3.4 * mScale), spotColor, Enum.Material.Neon, 0.1)
				local tendrilTop = top + V(math.cos(a) * capR * 0.72, -1 * mScale, math.sin(a) * capR * 0.72)
				local tLen = (7 + (k % 3) * 4) * mScale
				beam("HangingTendril", tendrilTop, tendrilTop - V(0, tLen, 0), 0.5 * mScale, gillColor, Enum.Material.Neon, 0.2)
				orb("TendrilSporeBulb", tendrilTop - V(0, tLen, 0), V(1.4 * mScale, 1.9 * mScale, 1.4 * mScale), spotColor, Enum.Material.Neon, 0.1)
			end
		end)
	end

	local function tree(at: Vector3, tScale: number, corrupted: boolean, dead: boolean)
		if kitOn and biomeKit then
			group("Tree", function()
				local name = if corrupted then "BlightTree" elseif dead then "DeadTree" else biomeKit.Tree
				-- The ruin tree's foliage stays green wherever it grows (the Verdant head, Corrupted fallbacks).
				local o = if name == "BanyanTree" and biome ~= "verdant_ruins"
					then { FOLIAGE = { Color = rgb(54, 122, 60), Material = Enum.Material.Grass }, WOOD = { Color = rgb(82, 64, 46) } }
					else nil
				kitAt(name, CFrame.new(at) * CFrame.Angles(0, yawAt(at), 0), tScale, o)
			end)
			return
		end
		group("Tree", function()
			local wood = if corrupted then rgb(28, 20, 34) elseif dead then rgb(42, 34, 32) else rgb(78, 62, 44)
			local leaf1 = rgb(36, 98, 48)
			local leaf2 = rgb(54, 126, 62)
			local hTrunk = 40 * tScale
			local lean = V((at.X > 0 and -1 or 1) * 4.5 * tScale, hTrunk, 2 * tScale)
			local top = at + lean
			beam("AncientTrunk", at, top, 9.0 * tScale, wood, Enum.Material.Wood)
			for k = 1, 5 do
				local a = k * math.pi * 2 / 5 + 0.3
				local rootEnd = at + V(math.cos(a) * 17 * tScale, 0, math.sin(a) * 17 * tScale)
				beam("ButtressRoot", at + V(0, 7.5 * tScale, 0), rootEnd, 3.4 * tScale, wood, Enum.Material.Wood)
				local branchEnd = top + V(math.cos(a) * 22 * tScale, (8 + (k % 2) * 5) * tScale, math.sin(a) * 22 * tScale)
				beam("CanopyBough", top - V(0, 5 * tScale, 0), branchEnd, 4.0 * tScale, wood, Enum.Material.Wood)
				if not dead and not corrupted then
					orb("FoliageCluster", branchEnd + V(0, 3 * tScale, 0), V(32 * tScale, 15 * tScale, 30 * tScale), if k % 2 == 0 then leaf1 else leaf2, Enum.Material.Grass)
					beam("HangingJungleVine", branchEnd, branchEnd - V(0, 28 * tScale, 0), 0.75 * tScale, leaf2, Enum.Material.Grass)
				elseif corrupted then
					local barkStart = at + V(math.cos(a) * 4.6 * tScale, 3 * tScale, math.sin(a) * 4.6 * tScale)
					local barkEnd = top + V(math.cos(a) * 4.2 * tScale, -2 * tScale, math.sin(a) * 4.2 * tScale)
					beam("CrimsonBarkFissure", barkStart, barkEnd, 0.85 * tScale, rgb(255, 55, 165), Enum.Material.Neon)
					orb("CorruptedCanopyWisp", branchEnd, V(26 * tScale, 11 * tScale, 24 * tScale), rgb(95, 28, 88), Enum.Material.Slate, 0.15)
				end
			end
			if not dead and not corrupted then
				orb("MainCanopyCrown", top + V(0, 15 * tScale, 0), V(46 * tScale, 18 * tScale, 44 * tScale), leaf1, Enum.Material.Grass)
			end
		end)
	end

	local function statue(at: Vector3, sScale: number, kind: string, faceSignX: number?)
		if kitOn then
			group("Statue", function()
				local rotY = if faceSignX then (faceSignX > 0 and -math.pi / 2 or math.pi / 2) else 0
				local name = if kind == "LionGuardian" then "LionGuardian" elseif kind == "TridentKing" then "RobedStatueTrident" else "RobedStatueStaff"
				kitAt(name, CFrame.new(at) * CFrame.Angles(0, rotY, 0), sScale, { GLOW = { Color = accent } })
			end)
			return
		end
		group("Statue", function()
			local c = theme.TrimColor
			local rotY = if faceSignX then (faceSignX > 0 and -math.pi / 2 or math.pi / 2) else 0
			local cf = CFrame.new(at) * CFrame.Angles(0, rotY, 0)
			local function sBlock(name: string, sz: Vector3, localPos: Vector3, col: Color3?, mat: Enum.Material?)
				local p = block(name, sz * sScale, V(0, 0, 0), col or c, mat or theme.TrimMaterial)
				p.CFrame = CFrame.new(origin) * cf * CFrame.new(localPos * sScale)
				return p
			end
			local function sOrb(name: string, sz: Vector3, localPos: Vector3, col: Color3?, mat: Enum.Material?)
				local p = orb(name, V(0, 0, 0), sz * sScale, col or c, mat or theme.TrimMaterial)
				p.CFrame = CFrame.new(origin) * cf * CFrame.new(localPos * sScale)
				return p
			end
			sBlock(kind .. "Plinth1", V(22, 4, 22), V(0, 2, 0))
			sBlock(kind .. "Plinth2", V(18, 4, 18), V(0, 6, 0), theme.AccentColor)
			if kind == "LionGuardian" then
				sOrb("LionHaunch", V(14, 18, 18), V(0, 16, -2), c, Enum.Material.Slate)
				sBlock("LionChest", V(13, 16, 12), V(0, 20, 4), c, Enum.Material.Slate)
				sOrb("LionMane", V(18, 18, 14), V(0, 29, 4), theme.AccentColor, Enum.Material.Slate)
				sBlock("LionSnout", V(9, 7, 9), V(0, 28, 11), c)
				for _, s in { -1, 1 } do
					sBlock("LionForeleg", V(4.5, 14, 4.5), V(s * 4.8, 14, 8), c)
					sBlock("LionPaw", V(5.5, 3.5, 7), V(s * 4.8, 9, 10), c)
					sOrb("LionEye", V(1.6, 1.6, 1.6), V(s * 2.8, 30.5, 13.5), accent, Enum.Material.Neon)
				end
			else
				sBlock("StatueRobeLower", V(14, 18, 11), V(0, 17, 0))
				sBlock("StatueTorso", V(15, 15, 10), V(0, 31, 0))
				sBlock("StatueShoulders", V(19, 5, 11), V(0, 38, 0), theme.AccentColor)
				sOrb("StatueHead", V(10, 12, 10), V(0, 46, 0))
				sBlock("StatueCrown", V(11, 4, 11), V(0, 52, 0), gold, Enum.Material.Metal)
				for _, s in { -1, 1 } do
					sBlock("StatueArm", V(4.5, 15, 4.5), V(s * 10, 32, 3))
					sOrb("StatueEye", V(1.4, 1.4, 1.4), V(s * 2.4, 46.5, 4.6), accent, Enum.Material.Neon)
				end
				local staffPos = cf:PointToWorldSpace(V(11 * sScale, 28 * sScale, 6 * sScale))
				beam("CeremonialWeaponShaft", staffPos - V(0, 22 * sScale, 0), staffPos + V(0, 28 * sScale, 0), 1.8 * sScale, gold, Enum.Material.Metal)
				if kind == "TridentKing" then
					sBlock("PoseidonBeard", V(8, 8, 5), V(0, 41, 4))
					for _, dx in { -3.5, 0, 3.5 } do
						local prongBase = staffPos + V(dx * sScale, 26 * sScale, 0)
						beam("TridentProng", prongBase, prongBase + V(0, 9 * sScale, 0), 1.2 * sScale, accent, Enum.Material.Neon)
					end
				else
					orb("GoddessStaffOrb", staffPos + V(0, 30 * sScale, 0), V(6 * sScale, 6 * sScale, 6 * sScale), accent, Enum.Material.Neon)
				end
			end
		end)
	end

	local function libraryWing(at: Vector3, wingWidth: number, wingHeight: number, rotY: number)
		group("LibraryWing", function()
			local cf = CFrame.new(at) * CFrame.Angles(0, rotY, 0)
			local woodDark = rgb(36, 26, 48)
			local back = block("LibraryCaseWall", V(wingWidth, wingHeight, 8), V(0, 0, 0), woodDark, Enum.Material.Wood)
			back.CFrame = CFrame.new(origin) * cf * CFrame.new(0, wingHeight / 2, 0)
			local cornice = block("LibraryGoldCornice", V(wingWidth + 4, 3.5, 11), V(0, 0, 0), gold, Enum.Material.Metal)
			cornice.CFrame = CFrame.new(origin) * cf * CFrame.new(0, wingHeight + 1.5, 1)
			local stories = math.max(2, math.floor(wingHeight / 14))
			for row = 1, stories do
				local sy = (row - 0.5) * (wingHeight / stories)
				local shelf = block("GiltBookshelf", V(wingWidth - 2, 1.2, 10), V(0, 0, 0), gold, Enum.Material.Metal)
				shelf.CFrame = CFrame.new(origin) * cf * CFrame.new(0, sy - 4, 1)
				for col = -3, 3 do
					local tomeColor = if (row + col) % 3 == 0 then gold elseif (row + col) % 2 == 0 then rgb(75, 165, 255) else rgb(255, 210, 125)
					local tome = block("IlluminatedTomeCluster", V(wingWidth * 0.09, 6.5, 3.5), V(0, 0, 0), tomeColor, if (row + col) % 2 == 0 then Enum.Material.Neon else Enum.Material.SmoothPlastic, nil, 0.1)
					tome.CFrame = CFrame.new(origin) * cf * CFrame.new(col * (wingWidth * 0.12), sy, 3.5)
				end
			end
			for _, s in { -1, 1 } do
				local pil = block("LibraryPilaster", V(4.5, wingHeight + 2, 10), V(0, 0, 0), gold, Enum.Material.Metal)
				pil.CFrame = CFrame.new(origin) * cf * CFrame.new(s * (wingWidth * 0.46), wingHeight / 2, 1)
				local banner = block("CelestialBanner", V(6, wingHeight * 0.68, 0.6), V(0, 0, 0), rgb(28, 52, 138), Enum.Material.Fabric)
				banner.CFrame = CFrame.new(origin) * cf * CFrame.new(s * (wingWidth * 0.46), wingHeight * 0.52, 6.2)
				local emblem = orb("BannerSunEmblem", V(0, 0, 0), V(3.8, 3.8, 1.2), gold, Enum.Material.Neon)
				emblem.CFrame = CFrame.new(origin) * cf * CFrame.new(s * (wingWidth * 0.46), wingHeight * 0.58, 6.5)
			end
		end)
	end

	local function cogwheel(at: Vector3, radius: number, tilt: CFrame?)
		group("Cogwheel", function()
			local cf = CFrame.new(at) * (tilt or CFrame.identity)
			local metalDark = rgb(58, 46, 48)
			ring("CeilingCogRim", at, radius, 3.2, metalDark, Enum.Material.Metal, tilt, 0, math.pi * 2, 20)
			ring("CeilingCogInnerRim", at, radius * 0.45, 2.4, darkGold, Enum.Material.Metal, tilt, 0, math.pi * 2, 12)
			for k = 1, 12 do
				local a = k * math.pi / 6
				local tip = cf:PointToWorldSpace(V(math.cos(a) * radius, math.sin(a) * radius, 0))
				beam("CogSpoke", at, tip, 2.2, metalDark, Enum.Material.Metal)
				local tooth = block("CogTooth", V(4.5, 6.5, 4.5), tip, metalDark, Enum.Material.Metal)
				tooth.CFrame = CFrame.new(origin) * cf * CFrame.new(math.cos(a) * (radius + 2.5), math.sin(a) * (radius + 2.5), 0) * CFrame.Angles(0, 0, a - math.pi / 2)
			end
		end)
	end

	local function chain(a: Vector3, b: Vector3, linkRadius: number?)
		group("Chain", function()
			local r = linkRadius or 2.2
			local steps = 14
			for k = 0, steps do
				local at = a:Lerp(b, k / steps)
				ring("IronChainLink", at, r, 1.1, rgb(64, 66, 76), Enum.Material.Metal, CFrame.Angles(0, if k % 2 == 0 then 0 else math.pi / 2, 0), 0, math.pi * 2, 6)
			end
		end)
	end

	local function populateLandmark(at: Vector3, lScale: number, variantSeed: number, signX: number)
		if biome == "verdant_ruins" then
			tree(at, 1.05 * lScale, false, false)
			if variantSeed % 2 == 0 then
				arch(at + V(-signX * 10, 0, 8), 24 * lScale, 22 * lScale, 6.5, theme.TrimColor, theme.TrimMaterial, math.pi / 4 * signX)
			else
				spire(at + V(-signX * 8, 0, -6), 28 * lScale, 9 * lScale, gold, accent, false)
			end
		elseif biome == "fungal_hollow" then
			mushroom(at, 1.15 * lScale, false)
			mushroom(at + V(-signX * 12, -2, 10), 0.68 * lScale, false)
		elseif biome == "ashen_dunes" then
			local crag = block("InteriorObsidianCrag", V(16 * lScale, 42 * lScale, 18 * lScale), at + V(0, 18 * lScale, 0), rgb(28, 22, 24), Enum.Material.Basalt)
			crag.CFrame *= CFrame.Angles(0.18, 0, signX * 0.32)
			-- With the kit the crag is dressed in rock columns; the flat fissure strips would float off it.
			if not kitOn then
			local fissure1 = block("CragMagmaFissureFront", V(1.6 * lScale, 34 * lScale, 1.2), V(0, 0, 0), rgb(255, 115, 28), Enum.Material.Neon)
			fissure1.CFrame = crag.CFrame * CFrame.new(0, 2 * lScale, 9.1 * lScale)
			local fissure2 = block("CragMagmaFissureSide", V(1.2, 32 * lScale, 1.6 * lScale), V(0, 0, 0), rgb(255, 135, 38), Enum.Material.Neon)
			fissure2.CFrame = crag.CFrame * CFrame.new(-signX * 8.1 * lScale, 2 * lScale, 0)
			end
			spire(at + V(-signX * 10 * lScale, 0, 8 * lScale), 32 * lScale, 8.5 * lScale, theme.TrimColor, rgb(255, 125, 35), false)
			if variantSeed % 2 == 1 then
				arch(at + V(-signX * 8, 0, 12), 24 * lScale, 20 * lScale, 6.5, theme.TrimColor, Enum.Material.Sandstone, 0.3 * signX)
			else
				tree(at + V(signX * 8, 0, -8), 0.75 * lScale, false, true)
			end
		elseif biome == "frozen_citadel" then
			spire(at, 44 * lScale, 11 * lScale, rgb(135, 210, 248), accent, true)
			if kitOn then
				-- A snow-laden pine beside the ice spire.
				group("Pine", function()
					local pineAt = at + V(-signX * 13 * lScale, 0, 9 * lScale)
					kitAt("PineTree", CFrame.new(pineAt) * CFrame.Angles(0, yawAt(pineAt), 0), 0.95 * lScale)
				end)
			else
				spire(at + V(-signX * 10, -2, 9), 28 * lScale, 7.5 * lScale, rgb(155, 225, 255), accent, true)
			end
		elseif biome == "infernal_foundry" then
			spire(at, 46 * lScale, 13 * lScale, rgb(40, 30, 32), rgb(255, 108, 28), false)
			arch(at + V(-signX * 10, 0, 0), 24 * lScale, 22 * lScale, 7.5, theme.TrimColor, Enum.Material.Metal, math.pi / 2)
		elseif biome == "thunder_highlands" then
			if kitOn and variantSeed % 2 == 0 then
				-- Wind-bent highland pines.
				group("Pine", function()
					kitAt("PineTree", CFrame.new(at) * CFrame.Angles(0, yawAt(at), 0), 1.05 * lScale)
					local twin = at + V(-signX * 11 * lScale, 0, 7 * lScale)
					kitAt("PineTree", CFrame.new(twin) * CFrame.Angles(0, yawAt(twin), 0), 0.75 * lScale)
				end)
			elseif variantSeed % 2 == 0 then
				cyl("InteriorHighlandTower", at + V(0, 18 * lScale, 0), 10 * lScale, 36 * lScale, theme.TrimColor, Enum.Material.Cobblestone)
				cyl("InteriorTowerCrown", at + V(0, 37 * lScale, 0), 11.5 * lScale, 4 * lScale, theme.TrimColor, Enum.Material.Cobblestone)
			else
				spire(at, 40 * lScale, 10 * lScale, theme.TrimColor, accent, false)
			end
		elseif biome == "corrupted_grove" then
			tree(at, 1.12 * lScale, true, false)
			mushroom(at + V(-signX * 11, 0, 9), 0.55 * lScale, true)
		elseif biome == "sunken_sanctuary" then
			arch(at, 26 * lScale, 24 * lScale, 7.5, theme.TrimColor, Enum.Material.Marble, math.pi / 3 * signX)
			spire(at + V(signX * 8, 0, -8), 34 * lScale, 9 * lScale, theme.TrimColor, accent, false)
		elseif biome == "astral_archives" then
			libraryWing(at, 34 * lScale, 42 * lScale, if signX > 0 then -math.pi / 2.4 else math.pi / 2.4)
		elseif biome == "abyssal_throne" then
			spire(at, 50 * lScale, 12 * lScale, rgb(24, 18, 34), accent, false)
		end
	end

	-- =========================================================================
	-- 1. FULL SUB-FLOOR ELEMENTAL SEA (Water / Lava / Clouds / Nebula / Abyss)
	-- =========================================================================
	local isLava = biome == "infernal_foundry" or biome == "ashen_dunes"
	local isCloud = biome == "thunder_highlands"
	local isCosmic = biome == "astral_archives"
	local isAbyss = biome == "abyssal_throne"

	if seaLevel < 0 and not natural then
		local basinSurface = block(
			"ElementalBasinSea",
			V(w - 12, 0.6, d - 12),
			V(0, seaLevel - 0.5, 0),
			liquidColor,
			Enum.Material.SmoothPlastic,
			nil,
			if isLava then 0.15 elseif isCloud then 0.20 else 0.35
		)
		basinSurface.Reflectance = if isLava or isCloud then 0 else 0.15

		for _, s in { -1, 1 } do
			for k = 1, 5 do
				local cz = -d * 0.36 + k * (d * 0.14)
				local cx = s * (w * 0.38 + (k % 2) * 16)
				if isCloud then
					orb("ValleyCloudBank", V(cx, seaLevel + 1, cz), V(52, 10, 48), rgb(232, 238, 252), Enum.Material.SmoothPlastic, 0.2)
				elseif isLava then
					block("BasaltSlagIsland", V(22, 2.5, 20), V(cx, seaLevel + 0.6, cz), cliffColor, Enum.Material.Basalt)
					orb("MoltenBubbleGlow", V(cx + s * 6, seaLevel + 0.3, cz - 4), V(8, 1.2, 8), rgb(255, 175, 55), Enum.Material.SmoothPlastic, 0.15)
				elseif isCosmic then
					orb("CosmicNebulaCloud", V(cx, seaLevel + 1, cz), V(48, 8, 44), rgb(88, 64, 175), Enum.Material.SmoothPlastic, 0.65)
				elseif isAbyss then
					orb("AbyssalTealMist", V(cx, seaLevel + 1, cz), V(48, 8, 44), rgb(52, 215, 228), Enum.Material.SmoothPlastic, 0.70)
					spire(V(cx, bottom, cz), 21 + (k % 3) * 4, 6, cliffColor, accent, false)
				else
					cyl("SubmergedShoal", V(cx, seaLevel + 0.2, cz), 14, 1.2, theme.TrimColor, theme.GroundMaterial)
					orb("BioluminescentPoolFlora", V(cx, seaLevel + 1.2, cz), V(4, 3, 4), accent, Enum.Material.SmoothPlastic, 0.2)
				end
			end
		end
	end

	-- =========================================================================
	-- 2. FULL-HEIGHT 360° PERIMETER CLIFF RANGES, CORNER MASSIFS & NORTH HORIZON
	-- =========================================================================
	-- (Natural floors: the terrain's mountain walls stand here instead.)
	if not natural then
	-- Hide all 4 outer room corners (NW, NE, SW, SE) with full-height mountain/citadel massifs
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local cornerAt = V(sx * (w / 2 - 26), bottom, sz * (d / 2 - 26))
			block("CornerHorizonMassif", V(68, h - bottom + 6, 68), cornerAt + V(0, (h - bottom) / 2, 0), cliffColor, cliffMat)
			block("CornerMidBastion", V(52, (h - bottom) * 0.68, 52), cornerAt + V(-sx * 16, (h - bottom) * 0.34, -sz * 16), theme.TrimColor, theme.TrimMaterial)
			waterfall(cornerAt + V(-sx * 28, 0, -sz * 28), 14, (h - bottom) * 0.58, liquidColor, if sx > 0 then -math.pi * 0.75 else math.pi * 0.75)
		end
	end

	-- Full-height panoramic North Horizon Range spanning the entire North wall behind the Apex
	for k = -4, 4 do
		if math.abs(k) >= 2 then
			local nx = k * (w * 0.105)
			local nz = -d / 2 + 20
			local peakH = h - bottom - (math.abs(k) % 2) * 14
			group("HorizonPeak", function()
				block("NorthHorizonPeak", V(w * 0.13, peakH, 38), V(nx, bottom + peakH / 2, nz), cliffColor, cliffMat)
				block("NorthHorizonFoothill", V(w * 0.11, peakH * 0.56, 28), V(nx, bottom + peakH * 0.28, nz + 18), theme.GroundColor, theme.GroundMaterial)
				if math.abs(k) == 3 then
					waterfall(V(nx, bottom, nz + 30), 13, peakH * 0.54, liquidColor, 0)
				end
				-- On the foothill shelf in front of the peak (the peak face ends at nz + 19), not inside the rock.
				populateLandmark(V(nx, bottom + peakH * 0.56, nz + 26), 0.9 * scale, math.abs(k), if k > 0 then 1 else -1)
			end)
		end
	end

	-- West & East Full-Height Perimeter Cliffs, Upper Sky Ridges & Waterfalls
	local sideCount = 6 + index
	for _, s in { -1, 1 } do
		for k = 1, sideCount do
			local frac = (k - 0.5) / sideCount
			local zPos = -d * 0.42 + frac * (d * 0.82)
			local lowerH = (56 + ((k * 19) % 26)) * scale
			local upperH = h - bottom + 4
			local xEdge = s * (w / 2 - 18)

			group("PerimeterCliff", function()
				-- Full-height outer backdrop massif reaching ceiling (prevents flat wall plane exposure)
				block("PerimeterSkyPeak", V(28, upperH, d / sideCount + 18), V(xEdge + s * 4, bottom + upperH / 2, zPos), cliffColor, cliffMat)
				-- Stepped mid cliff & lower terrace ledge protruding into the room
				block("PerimeterCliffBase", V(38, lowerH, d / sideCount + 12), V(xEdge - s * 8, bottom + lowerH / 2, zPos), cliffColor, cliffMat)
				block("PerimeterCliffLedge", V(28, lowerH * 0.62, d / sideCount + 4), V(xEdge - s * 20, bottom + lowerH * 0.31, zPos + 4), theme.GroundColor, theme.GroundMaterial)
				-- The kit rocks already slope; the wedge would poke through them.
				if not kitOn then wedge(
					"PerimeterCliffSlope",
					V(d / sideCount + 4, lowerH * 0.42, 20),
					CFrame.new(xEdge - s * 22, bottom + lowerH * 0.78, zPos) * CFrame.Angles(0, if s > 0 then -math.pi / 2 else math.pi / 2, 0),
					cliffColor,
					cliffMat
				) end

				if k % 2 == 0 then
					waterfall(V(xEdge - s * 26, bottom, zPos), 12, lowerH * 0.62, liquidColor, if s > 0 then -math.pi / 2 else math.pi / 2)
				end

				-- Ridge props stand on the exposed top of the cliff base, between the sky peak face
				-- (xEdge - 10) and the base's inner edge (xEdge - 27).
				populateLandmark(V(xEdge - s * 19, bottom + lowerH, zPos), 0.7 * scale, k, s)
			end)
			local floorAt = V(xEdge - s * 32, bottom, zPos)
			if k % 2 == 1 then
				populateLandmark(floorAt, 0.85 * scale, k + 1, s)
			end
		end
	end

	end -- not natural (perimeter)

	-- =========================================================================
	-- 3. INTERIOR CHASM ISLANDS & OVERHEAD BRIDGE ARCHES (FILLS MIDGROUND VIEW!)
	-- =========================================================================
	local safe = layout.Sanctuary
	local basin = layout.Platforms.Basin
	local westGal = layout.Platforms.WestGallery
	local crossing = layout.Platforms.Crossing
	local apex = layout.Platforms.Apex

	-- Overhead Monumental Archways / Canopies / Ribs spanning across the central spine ramps, at each ramp's
	-- middle and turned square to it (a floor's own layout can angle its ramps).
	local function spineMid(from: string, to: string): (Vector3, number)
		for _, link in layout.Links do
			if link.From == from and link.To == to then
				local dx, dz = link.BX - link.AX, link.BZ - link.AZ
				return V((link.AX + link.BX) / 2, (link.AY + link.BY) / 2, (link.AZ + link.BZ) / 2), math.atan2(dx, dz)
			end
		end
		return V(0, 0, 0), 0
	end
	local ramp1Mid, ramp1Yaw = spineMid("Sanctuary", "Basin")
	local ramp2Mid, ramp2Yaw = spineMid("Basin", "Crossing")
	local stairMid, stairYaw = spineMid("Crossing", "Apex")

	-- The piers rise from the chasm floor beside the ramp; the crown stays at its old height above the ramp.
	-- Tagged RampArch: it straddles the walkway on purpose, so walkway clearance leaves it alone.
	local function rampArch(mid: Vector3, yaw: number, span: number, rise: number, depthSize: number, color: Color3)
		group("RampArch", function()
			arch(V(mid.X, bottom, mid.Z), span, rise + (mid.Y - 2 - bottom), depthSize, color, theme.TrimMaterial, yaw)
		end)
	end
	-- A hand-authored floor can arch its paths with something of its own (Floor 1: a canopy of giant trees;
	-- Floors 4-5: ruined Solmere arches spanning the spine ramps and ceremonial stairs).
	if not layout.Authored or layout.Authored == "verdant:4" or layout.Authored == "verdant:5" then
		local archMatColor = if layout.Authored then rgb(196, 190, 168) else theme.TrimColor
		rampArch(ramp1Mid, ramp1Yaw, 40, 28 * scale, 8, archMatColor)
		rampArch(ramp2Mid, ramp2Yaw, 38, 30 * scale, 8, archMatColor)
		rampArch(stairMid, stairYaw, 42, 34 * scale, 9, gold)
	end

	if biome == "corrupted_grove" and not corruptedFloor then
		for _, at in { { ramp1Mid, ramp1Yaw }, { ramp2Mid, ramp2Yaw }, { stairMid, stairYaw } } do
			ring("PathwayThornArch", at[1] + V(0, 8, 0), 28 * scale, 3.2, rgb(24, 16, 28), Enum.Material.Wood, CFrame.Angles(0, at[2], 0), 0.15, math.pi - 0.15, 12)
		end
	end

	-- 3 Pairs of Towering Interior Chasm Islands right between the Central Spine and Side Galleries
	local innerIslands = {
		{ X = 68, Z = (safe.Z + basin.Z) * 0.5 + 8, H = 18, Scale = 1.08 }, -- Foreground Chasm Island
		{ X = 64, Z = crossing.Z + 44, H = 22, Scale = 1.18 },              -- Lower Midground Chasm Island
		{ X = 62, Z = (crossing.Z + apex.Z) * 0.5, H = 28, Scale = 1.25 },  -- Upper Grand-Stair Chasm Island
	}

	-- Islands keep off every walkway (TowerLayout.Lanes): each one tries its authored spot first, then
	-- steps outward or along the room until its footprint is clear, and is left out if nothing fits.
	local lanes = TowerLayout.Lanes(index, parent:GetAttribute("FloorId"))
	local function footprintClear(x: number, z: number, halfX: number, halfZ: number): boolean
		local radius = math.sqrt(halfX * halfX + halfZ * halfZ)
		for _, lane in lanes do
			local dx, dz = lane.BX - lane.AX, lane.BZ - lane.AZ
			local lengthSq = math.max(dx * dx + dz * dz, 1e-6)
			local t = math.clamp(((x - lane.AX) * dx + (z - lane.AZ) * dz) / lengthSq, 0, 1)
			local px, pz = lane.AX + dx * t - x, lane.AZ + dz * t - z
			if px * px + pz * pz < (lane.HalfWidth + radius) ^ 2 then
				return false
			end
		end
		return true
	end

	for idxIsland, isl in innerIslands do
		if natural then break end -- the terrain has its own knolls and plateaus
		for _, s in { -1, 1 } do
			local islX: number?, islZ: number = nil, isl.Z
			for _, dz in { 0, 12, -12, 24, -24 } do
				for _, step in { 0, 8, 16, 24, 32, 40, 48 } do
					if footprintClear(s * (isl.X + step), isl.Z + dz, 16 * scale, 17 * scale) then
						islX, islZ = s * (isl.X + step), isl.Z + dz
						break
					end
				end
				if islX then break end
			end
			if not islX then continue end
			local islPos = V(islX, bottom, islZ)
			local islH = isl.H * scale - bottom
			-- Stepped rocky/masonry island rising out of the chasm right beside the central path. The island,
			-- its waterfall and the landmark on its crown are one prop, so they are cleared together.
			group("ChasmIsland", function()
				block("InteriorChasmIslandBase", V(32 * scale, islH, 34 * scale), islPos + V(0, islH / 2, 0), cliffColor, cliffMat)
				block("InteriorChasmIslandCrown", V(26 * scale, 4, 28 * scale), islPos + V(0, islH + 1, 0), theme.GroundColor, theme.GroundMaterial)
				-- On the island's outer face, away from the central ramps.
				waterfall(islPos + V(s * 14 * scale, 0, 0), 8 * scale, islH, liquidColor, if s > 0 then math.pi / 2 else -math.pi / 2)
				-- Capped so tree roots (17 x scale) stay on the 26 x scale crown instead of hanging in the air.
				populateLandmark(islPos + V(0, islH + 3, 0), math.min(isl.Scale, 0.72) * scale, idxIsland, s)
			end)
		end
	end

	-- Foreground & Midground Lantern / Brazier Colonnades, Basin Courtyard Gardens & Gallery Flanking Structures
	-- Central causeway runner & curbing across the wide Basin terrace
	if not natural then
		block("BasinCentralCauseway", V(34, 0.14, basin.Depth - 4), V(0, basin.Y + 0.04, basin.Z), theme.TrimColor, theme.TrimMaterial)
		block("BasinCausewayInlay", V(20, 0.18, basin.Depth - 8), V(0, basin.Y + 0.06, basin.Z), theme.AccentColor, theme.GroundMaterial)
	end

	for _, s in { -1, 1 } do
		-- This side's own gallery (a floor's layout moves each side on its own).
		local gal = if s < 0 then layout.Platforms.WestGallery else layout.Platforms.EastGallery
		if not natural then
		-- Sunken elemental pools / magma trenches / cloud basins on the lateral margins of the Basin courtyard
		local poolPos = V(s * (basin.Width * 0.44), basin.Y + 0.06, basin.Z)
		group("BasinPool", function()
			block("BasinWingPoolFrame", V(basin.Width * 0.10, 0.8, basin.Depth * 0.68), poolPos, theme.TrimColor, theme.TrimMaterial)
			block(
				"BasinWingElementalPool",
				V(basin.Width * 0.08, 0.9, basin.Depth * 0.62),
				poolPos + V(0, 0.06, 0),
				liquidColor,
				Enum.Material.SmoothPlastic,
				nil,
				0.25
			)
		end)

		-- Courtyard Landmarks at the lateral margins of the Basin terrace (framing the open courtyard). They sit
		-- beyond the ends of the wing pools (which cover basin.Z +/- 0.34 x depth), not in the water.
		populateLandmark(V(s * (basin.Width * 0.44), basin.Y, basin.Z + basin.Depth * 0.42), 0.92 * scale, 1, s)
		populateLandmark(V(s * (basin.Width * 0.44), basin.Y, basin.Z - basin.Depth * 0.42), 1.08 * scale, 2, s)

		local lampPos = V(s * 22, basin.Y, basin.Z + basin.Depth * 0.44)
		group("Lantern", function()
			block("ApproachLanternPost", V(3, 8, 3), lampPos + V(0, 4, 0), theme.TrimColor, theme.TrimMaterial)
			local flame = orb("ApproachLanternGlow", lampPos + V(0, 9.5, 0), V(2.6, 3.6, 2.6), if biome == "fungal_hollow" then rgb(255, 195, 95) elseif biome == "abyssal_throne" then rgb(175, 85, 255) else accent, Enum.Material.SmoothPlastic, 0.1)
			pointLight(flame, flame.Color, 0.45, 28)
		end)

		-- Beyond the gallery edge there is no terrace, so these stand on the chasm floor.
		local galOuter = V(gal.X + s * (gal.Width * 0.5 + 14), bottom, gal.Z)
		arch(galOuter, 38 * scale, 28 * scale, 9, theme.TrimColor, theme.TrimMaterial, math.pi / 2)
		populateLandmark(galOuter + V(s * 8, 0, -24), 1.15 * scale, 1, s)
		populateLandmark(galOuter + V(s * 8, 0, 24), 1.1 * scale, 2, s)
		end -- not natural (basin and gallery dressing)

		if biome == "fungal_hollow" and not natural then
			for v = 1, 4 do
				beam("MyceliumVein", V(gal.X, bottom + 1, gal.Z - 25 + v * 12), V(gal.X - s * 28, gal.Y, gal.Z - 18 + v * 10), 0.8, accent, Enum.Material.Neon, 0.12)
			end
		elseif biome == "astral_archives" then
			local pedAt = V(crossing.X + s * (crossing.Width * 0.5 + 12), crossing.Y, crossing.Z + 12)
			group("Lectern", function()
				block("GrimoireLectern", V(5, 6, 5), pedAt + V(0, 3, 0), theme.GroundColor, Enum.Material.Marble)
				block("OpenStarGrimoire", V(4.5, 0.8, 3.2), pedAt + V(0, 6.5, 0), gold, Enum.Material.Neon)
				ring("BrassArmillaryOuter", pedAt + V(0, 13, 0), 6.5, 0.65, gold, Enum.Material.Metal, CFrame.Angles(0.4, 0.3, 0), 0, math.pi * 2, 14)
				ring("BrassArmillaryInner", pedAt + V(0, 13, 0), 4.8, 0.55, gold, Enum.Material.Metal, CFrame.Angles(-0.5, 1.1, 0), 0, math.pi * 2, 12)
				orb("ArmillaryCore", pedAt + V(0, 13, 0), V(2.4, 2.4, 2.4), accent, Enum.Material.Neon)
			end)
		elseif biome == "abyssal_throne" then
			local obAt = V(crossing.X + s * (crossing.Width * 0.5 + 22), bottom, crossing.Z - 12)
			group("ChainedSpire", function()
				spire(obAt, 62 * scale, 14, rgb(22, 18, 30), accent, false)
				chain(obAt + V(0, 52 * scale, 0), V(apex.X + s * 28, apex.Y + 28, apex.Z))
			end)
		end
	end

	-- =========================================================================
	-- 4. BIOME-SPECIFIC FOREGROUND / MIDGROUND ICONIC GUARDIANS & MONUMENTS
	-- =========================================================================
	if biome == "verdant_ruins" then
		-- Authored Floors 2, 4, and 5 replace the generic foreground head/lion with their own pieces.
		if layout.Authored ~= "verdant:2" and layout.Authored ~= "verdant:4" and layout.Authored ~= "verdant:5" then
			-- Left foreground: Giant Ancient Carved Stone Deity Head nestled in banyan roots (from Verdant Ruins.png)
			local headPos = V(-basin.Width * 0.36, basin.Y, basin.Z - 6)
			group("CarvedHead", function()
				orb("AncientCarvedHead", headPos + V(0, 17 * scale, 0), V(26 * scale, 34 * scale, 24 * scale), theme.TrimColor, Enum.Material.Slate)
				cyl("CarvedHeaddressTier1", headPos + V(0, 31 * scale, 0), 12 * scale, 5 * scale, theme.AccentColor, Enum.Material.Cobblestone)
				cyl("CarvedHeaddressCrown", headPos + V(0, 36 * scale, 0), 7.5 * scale, 6.5 * scale, gold, Enum.Material.Cobblestone)
				block("CarvedNoseBridge", V(4.2 * scale, 11 * scale, 5.5 * scale), headPos + V(4.5 * scale, 17 * scale, 9.5 * scale), theme.TrimColor, Enum.Material.Slate)
				for _, s in { -1, 1 } do
					block("SereneEyeLid", V(5.8 * scale, 1.8 * scale, 3.2 * scale), headPos + V(5.5 * scale, 20 * scale, (2 + s * 4.8) * scale), cliffColor, Enum.Material.Slate)
				end
				tree(headPos + V(-14 * scale, 0, -10 * scale), 1.25 * scale, false, false)
			end)

			-- Right foreground: Seated Stone Lion Guardian on mossy plinth (from Verdant Ruins.png)
			statue(V(basin.Width * 0.36, basin.Y, basin.Z - 6), 1.3 * scale, "LionGuardian", 1)
		end
		if layout.Authored ~= "verdant:4" and layout.Authored ~= "verdant:5" then
			for _, s in { -1, 1 } do
				statue(V(apex.X + s * (apex.Width * 0.5 + 18), apex.Y - 2, apex.Z + 18), 1.25 * scale, "LionGuardian", s)
			end
		end

	elseif biome == "sunken_sanctuary" then
		-- Twin Colossal Flanking Statues: Robed Goddess with Staff (West) & Poseidon King with Trident (East)
		local eastGal = layout.Platforms.EastGallery
		statue(V(westGal.X + 12, westGal.Y, westGal.Z - 18), 1.45 * scale, "StaffGoddess", -1)
		statue(V(eastGal.X - 12, eastGal.Y, eastGal.Z - 18), 1.45 * scale, "TridentKing", 1)

	elseif biome == "thunder_highlands" then
		-- West Ridge: Circular Stone Henge Portal Ring struck by vertical lightning (from Thunder Highlands.jpeg)
		local hengeAt = V(westGal.X - 10, westGal.Y, westGal.Z - 10)
		group("StormHenge", function()
			ring("StormHengeOuterRing", hengeAt + V(0, 26 * scale, 0), 21 * scale, 4.5 * scale, theme.TrimColor, Enum.Material.Rock, nil, 0, math.pi * 2, 16)
			ring("StormHengeInnerRing", hengeAt + V(0, 26 * scale, 0), 12 * scale, 2.6 * scale, accent, Enum.Material.Neon, nil, 0, math.pi * 2, 12)
			for _, s in { -1, 1 } do
				block("HengeMonolithPier", V(7.5 * scale, 28 * scale, 7.5 * scale), hengeAt + V(s * 14 * scale, 14 * scale, 0), theme.TrimColor, Enum.Material.Rock)
				block("HengeFlankingObelisk", V(6.5 * scale, 22 * scale, 6.5 * scale), hengeAt + V(s * 28 * scale, 11 * scale, 4), cliffColor, Enum.Material.Rock)
			end
			beam("HengeLightningStrike", hengeAt + V(0, 4 * scale, 0), hengeAt + V(4, h - 8, -6), 2.0, accent, Enum.Material.Neon)
		end)
	end

	-- =========================================================================
	-- 4b. HAND-AUTHORED FLOOR SET PIECES (TowerLayout AUTHORED)
	-- =========================================================================
	-- Floor 1, Overgrown Threshold: the Solmere's front door. Their motif is the carved sun disc; the
	-- Heartroot's sap (emerald-gold) is what still glows. Pieces stand clear of every walkway and camp.
	-- Ground the authored pieces claim (x, z, radius): the natural ecosystem (section 7) grows around them.
	local reservedSpots: { { number } } = {}
	if layout.Authored == "verdant:1" or layout.Authored == "verdant:2" or layout.Authored == "verdant:3" or layout.Authored == "verdant:4" or layout.Authored == "verdant:5" then
		local sap = rgb(150, 235, 120)
		local limestone = rgb(196, 190, 168)
		local verdigris = rgb(92, 150, 128)
		local bark = rgb(82, 64, 46)
		local barkDark = rgb(62, 48, 36)
		local vine = rgb(54, 122, 60)
		-- A carved sun disc facing +Z (toward the Sanctuary): rim ring, eight rays and a glowing core.
		local function sunDisc(name: string, at: Vector3, radius: number, tilt: CFrame?, glow: boolean)
			local face = CFrame.new(at) * (tilt or CFrame.identity)
			ring(name .. "Rim", at, radius, math.max(0.6, radius * 0.16), gold, Enum.Material.Cobblestone, tilt, 0, math.pi * 2, 14)
			for k = 0, 7 do
				local a = k * math.pi / 4
				local rayZ = -math.max(0.18, radius * 0.12)
				beam(name .. "Ray", face:PointToWorldSpace(V(math.cos(a) * radius * 1.15, math.sin(a) * radius * 1.15, rayZ)),
					face:PointToWorldSpace(V(math.cos(a) * radius * 1.62, math.sin(a) * radius * 1.62, rayZ)), math.max(0.45, radius * 0.15), verdigris, Enum.Material.Slate)
			end
			local core = cyl(name .. "Core", at, radius * 0.55, math.max(0.4, radius * 0.12), if glow then sap else gold, if glow then Enum.Material.Neon else Enum.Material.Cobblestone)
			core.CFrame = CFrame.new(origin) * face * CFrame.Angles(0, math.pi / 2, 0)
			return core
		end
		-- Glow-lilies: low emerald blooms the Bloom Tenders keep (they open at night).
		local function lilies(at: Vector3, count: number)
			for k = 1, count do
				local a = k * 2.4
				local p = at + V(math.cos(a) * (1 + k * 0.6), 0, math.sin(a) * (1 + k * 0.6))
				cyl("GlowLilyPad", p + V(0, 0.15, 0), 1.3, 0.3, rgb(46, 112, 58), Enum.Material.Grass)
				orb("GlowLilyBloom", p + V(0, 0.8, 0), V(0.9, 0.9, 0.9), sap, Enum.Material.Neon)
			end
		end
		local function limb(name: string, a: Vector3, b: Vector3, diameter: number, color: Color3): Part
			local p = block(name, V(math.max(0.1, (b - a).Magnitude), diameter, diameter), (a + b) / 2, color, Enum.Material.Wood, Enum.PartType.Cylinder)
			p.CFrame = CFrame.lookAt(origin + (a + b) / 2, origin + b) * CFrame.Angles(0, math.pi / 2, 0)
			return p
		end
		local function groundAt(x: number, z: number): number
			for _, t in layout.Platforms do
				if math.abs(x - t.X) <= t.Width / 2 and math.abs(z - t.Z) <= t.Depth / 2 then
					return t.Y
				end
			end
			return if field then math.max(field.Sample(x, z), bottom) else bottom
		end
		local LOWEST_HANG = 38
		local function canopy(at: Vector3, s: number)
			if kitOn and biomeKit then
				local crown = kitAt(biomeKit.Tree, CFrame.new(at) * CFrame.Angles(0, yawAt(at), 0), s)
				if not crown then
					return
				end
				local leaves: BasePart? = nil
				for _, p in crown:GetDescendants() do
					if p:IsA("BasePart") then
						if ((p:GetAttribute("Role") :: string?) or p.Name) == "FOLIAGE" and not leaves then
							leaves = p
						else
							p:Destroy()
						end
					end
				end
				if not leaves then
					crown:Destroy()
					return
				end
				local target = origin + at
				local low = leaves.Position.Y - leaves.Size.Y / 2
				local wantLow = math.max(target.Y - leaves.Size.Y * 0.3, origin.Y + LOWEST_HANG - 4)
				crown:PivotTo(crown:GetPivot() + V(target.X - leaves.Position.X, wantLow - low, target.Z - leaves.Position.Z))
				return
			end
			local leaf1, leaf2 = rgb(36, 98, 48), rgb(54, 126, 62)
			local lift = math.max(0, LOWEST_HANG - 4 - (at.Y - 4 * s))
			orb("CanopyLeaves", at + V(0, 5 * s + lift, 0), V(34 * s, 16 * s, 30 * s), leaf1, Enum.Material.Grass)
			orb("CanopyLeaves", at + V(9 * s, 10 * s + lift, -6 * s), V(24 * s, 12 * s, 22 * s), leaf2, Enum.Material.Grass)
			orb("CanopyLeaves", at + V(-8 * s, 9 * s + lift, 7 * s), V(22 * s, 11 * s, 24 * s), leaf2, Enum.Material.Grass)
		end
		-- boughs: { yaw in degrees (0 = north/-Z, 90 = east), reach, rise }
		local function giant(x: number, z: number, height: number, boughs: { { number } })
			if not footprintClear(x, z, 16, 16) then
				return
			end
			table.insert(reservedSpots, { x, z, 30 })
			local gy = groundAt(x, z)
			local base = V(x, gy - 0.5, z)
			group("HeartrootGiant", function()
				if natural then
					currentParent:SetAttribute("OnTerrain", true)
				end
				for k = 0, 4 do
					local a = k * math.pi * 2 / 5 + x * 0.013
					limb("HeartrootButtress", base + V(math.cos(a) * 3, 13, math.sin(a) * 3), V(x + math.cos(a) * 15, gy, z + math.sin(a) * 15), 4.2, barkDark)
				end
				local lean = V(math.sin(x * 0.07) * 3, 0, math.cos(z * 0.05) * 3)
				local p2 = base + V(0, height * 0.42, 0) + lean * 0.5
				local p3 = base + V(0, height * 0.78, 0) + lean
				local top = base + V(0, height, 0) + lean * 1.2
				limb("HeartrootTrunk", base, p2 + V(0, 1, 0), 15, bark)
				limb("HeartrootTrunk", p2, p3 + V(0, 1, 0), 12.5, bark)
				limb("HeartrootTrunk", p3, top, 10, bark)
				beam("HeartrootSapVein", base + V(0, 3, 7.4), p2 + lean * 0.1 + V(0, 0, 6.2), 0.55, sap, Enum.Material.Neon, 0.25)
				for _, b in boughs do
					local yaw = math.rad(b[1])
					local dir = V(math.sin(yaw), 0, -math.cos(yaw))
					local from = p3 + dir * 3
					local elbow = from + dir * (b[2] * 0.55) + V(0, b[3], 0)
					local tip = from + dir * b[2] + V(0, b[3] - 5, 0)
					limb("HeartrootBough", from, elbow, 6.5, bark)
					limb("HeartrootBough", elbow, tip, 4.5, bark)
					canopy(tip, 0.8 * scale)
					for j = 1, 2 do
						local hangTop = from:Lerp(tip, 0.3 + j * 0.25) - V(0, 2, 0)
						local hangLow = math.max(LOWEST_HANG, hangTop.Y - 10 - j * 4)
						if hangTop.Y - hangLow > 3 then
							beam("HeartrootAerialRoot", hangTop, V(hangTop.X, hangLow, hangTop.Z), 0.7, vine, Enum.Material.Grass)
						end
					end
				end
				canopy(top + V(0, 3, 0), 1.0 * scale)
			end)
		end

	if layout.Authored == "verdant:1" then

		-- The Dawn Gate: a cracked sun-gate on the back half of the summit, framing the boss portals and the
		-- temple behind them. The west half of the lintel still stands with the sun disc hanging askew from it;
		-- the east half lies broken on the terrace. Its piers stand outside the portal lanes.
		local gateZ = apex.Z - apex.Depth / 2 + 12
		local pierX, pierH = 37, 30 * scale
		group("DawnGate", function()
			for _, s in { -1, 1 } do
				block("DawnGateArchPier", V(8, pierH, 8), V(apex.X + s * pierX, apex.Y + pierH / 2, gateZ), limestone, Enum.Material.Limestone)
				block("DawnGatePierCap", V(10, 2, 10), V(apex.X + s * pierX, apex.Y + pierH + 1, gateZ), gold, Enum.Material.Cobblestone)
				beam("DawnGateIvy", V(apex.X + s * (pierX + 4.2), apex.Y + 0.5, gateZ + 2), V(apex.X + s * (pierX + 3.6), apex.Y + pierH - 3, gateZ + 3), 0.8, rgb(54, 126, 62), Enum.Material.Grass)
			end
			-- Intact west half of the lintel, cracked off just past the centre.
			block("DawnGateLintel", V(pierX + 8, 5, 9), V(apex.X - pierX / 2 + 2, apex.Y + pierH + 4.5, gateZ), limestone, Enum.Material.Limestone)
			local discAt = V(apex.X + 3, apex.Y + pierH - 6, gateZ + 1)
			local core = sunDisc("DawnGateSun", discAt, 7 * scale, CFrame.Angles(0, 0, math.rad(-14)), true)
			pointLight(core, sap, 1.2, 40)
			beam("DawnGateSunChain", V(apex.X + 1, apex.Y + pierH + 2, gateZ), discAt + V(0, 7 * scale, 0), 0.6, rgb(70, 74, 68), Enum.Material.Metal)
		end)
		group("FallenLintel", function()
			-- The broken east half, tipped onto the terrace beside its pier.
			-- Lying along the terrace's east edge, clear of the summit camp and the Ascend portal's lane.
			local at = V(apex.X + apex.Width / 2 - 8, apex.Y + 2.5, gateZ + 16)
			local p = block("DawnGateFallenLintel", V(20, 5, 9), at, limestone, Enum.Material.Limestone)
			p.CFrame = CFrame.new(origin + at) * CFrame.Angles(0, math.rad(84), math.rad(5))
		end)
		-- A shaft of dawn light through the crack, onto the summit.
		beam("JungleSunbeam", V(apex.X + 30, h - 4, gateZ - 30), V(apex.X + 4, apex.Y + 1, apex.Z - 6), 12, rgb(250, 222, 150), Enum.Material.SmoothPlastic, 0.9)

		-- Sun-disc stelae down both edges of the Processional Avenue, discs facing the pilgrims coming up from
		-- the Sanctuary; the northmost pair still glows. They stand just outside the avenue's landing lanes
		-- (21 studs either side of its centre), so nothing hangs inward; any that would stand on a walkway
		-- (the east glade's path joins the avenue) is left out.
		for _, s in { -1, 1 } do
			for k = -1, 1 do
				local at = V(crossing.X + s * (crossing.Width / 2 - 2.5), crossing.Y, crossing.Z + k * 30)
				if footprintClear(at.X, at.Z, 1.8, 1.2) then
					group("Stela", function()
						block("SolmereStela", V(3.6, 13 * scale, 2.4), at + V(0, 6.5 * scale, 0), limestone, Enum.Material.Limestone)
						block("StelaMossCap", V(3.6, 0.8, 2.4), at + V(0, 13 * scale + 0.4, 0), rgb(70, 120, 66), Enum.Material.Grass)
						sunDisc("StelaSun", at + V(0, 10 * scale, 1.56), 1.1, nil, k == -1)
					end)
				end
			end
		end

		-- Two stelae that fell into the fern beds of the Pilgrim Hollow, either side of the causeway.
		for _, s in { -1, 1 } do
			local at = V(s * 62, basin.Y, basin.Z + 14)
			if footprintClear(at.X, at.Z, 7, 7) then
				group("FallenStela", function()
					local p = block("SolmereStelaFallen", V(3.6, 2.4, 13 * scale), at + V(0, 1.2, 0), limestone, Enum.Material.Limestone)
					p.CFrame = CFrame.new(origin + at + V(0, 1.2, 0)) * CFrame.Angles(0, math.rad(s * 28), 0)
					if not natural then
						block("FernBed", V(10, 0.4, 14), at + V(s * 2, 0.2, 1), rgb(52, 110, 54), Enum.Material.Grass)
					end
					lilies(at + V(-s * 5, 0, -4), 4)
				end)
			end
		end

		-- Shrine Glade: three small sun shrines along the west glade's outer edge, past its camp.
		local westGlade = layout.Platforms.WestGallery
		for k = -1, 1 do
			local at = V(westGlade.X - westGlade.Width / 2 + 6, westGlade.Y, westGlade.Z + k * 22)
			if footprintClear(at.X, at.Z, 3, 3) then
				group("SunShrine", function()
					block("SunShrinePlinth", V(5, 1.2, 5), at + V(0, 0.6, 0), limestone, Enum.Material.Limestone)
					block("SunShrinePost", V(2.4, 6, 2.4), at + V(0, 4.2, 0), limestone, Enum.Material.Limestone)
					sunDisc("SunShrineDisc", at + V(0, 8.6, 0), 1.8, CFrame.Angles(0, math.pi / 2, 0), k == 0)
					-- Lilies on the outer side: inward they would fall inside the camp's 34-stud clearance.
					lilies(at + V(-2.5, 0, 3), 3)
				end)
			end
		end

		-- Banyan Well: a Solmere well on the east glade with a banyan grown over it.
		local eastGlade = layout.Platforms.EastGallery
		local wellAt = V(eastGlade.X + eastGlade.Width / 2 - 12, eastGlade.Y, eastGlade.Z - eastGlade.Depth / 2 + 14)
		if footprintClear(wellAt.X, wellAt.Z, 7, 7) then
			group("BanyanWell", function()
				cyl("SolmereWellRim", wellAt + V(0, 1.6, 0), 5, 3.2, limestone, Enum.Material.Limestone)
				cyl("SolmereWellWater", wellAt + V(0, 2.9, 0), 4.1, 0.4, rgb(60, 120, 110), Enum.Material.Glass, 0.2)
				orb("WellSapGlow", wellAt + V(0, 3.2, 0), V(2, 0.6, 2), sap, Enum.Material.Neon, 0.3)
				for k = 1, 4 do
					local a = k * math.pi / 2 + 0.4
					beam("WellRoot", wellAt + V(math.cos(a) * 9, 0.6, math.sin(a) * 9), wellAt + V(math.cos(a) * 4.6, 3.4, math.sin(a) * 4.6), 1.4, rgb(78, 62, 44), Enum.Material.Wood)
				end
				tree(wellAt + V(-4, 0, -4), 0.7 * scale, false, false)
			end)
		end

		-- The Heartroot's giants: six colossal figs whose trunks stand off every walkway and whose boughs arch
		-- over the paths high above heads, so the climb runs through a green tunnel: a pair over the arrival and
		-- the Pilgrim Hollow, one either side of the avenue, and a pair framing the Dawn Gate. Boughs leave the
		-- trunk above every lane (walk surface + 14) and camp band (camp + 22); each tip carries a banyan crown
		-- (the kit mesh on a natural floor), and aerial roots hang no lower than 38 studs.
		-- Over the arrival: boughs reach in over the Hollow, the arrival ramp and the Sanctuary's edge.
		for _, s in { -1, 1 } do
			giant(s * 120, 126, 56, { { -s * 90, 78, 10 }, { -s * 58, 80, 14 }, { -s * 128, 66, 6 } })
		end
		-- Either side of the avenue: one between it and the Shrine Glade, one between the stairs and the Banyan Well.
		giant(-50, -30, 58, { { 90, 52, 12 }, { 32, 58, 14 }, { 200, 50, 8 }, { -100, 44, 10 } })
		giant(50, -82, 60, { { -90, 54, 12 }, { -150, 54, 10 }, { 60, 44, 12 }, { 165, 48, 8 } })
		-- Framing the Dawn Gate: boughs over the summit and behind the gate.
		for _, s in { -1, 1 } do
			giant(s * 100, -128, 64, { { -s * 90, 68, 12 }, { -s * 40, 60, 14 }, { -s * 140, 54, 10 } })
		end
	elseif layout.Authored == "verdant:2" then
		local aqNorth = layout.Platforms.AqueductNorth
		local eastGal = layout.Platforms.EastGallery
		local mossCol = rgb(86, 132, 58)
		local waterCol = rgb(52, 148, 136)
		local f2Override: KitProps.Override = {
			TRIM = { Color = limestone, Material = Enum.Material.Limestone },
			ACCENT = { Color = verdigris, Material = Enum.Material.Slate },
			GOLD = { Color = gold, Material = Enum.Material.Cobblestone },
			GLOW = { Color = sap, Material = Enum.Material.Neon },
			MOSS = { Color = mossCol, Material = Enum.Material.Grass },
			WOOD = { Color = bark, Material = Enum.Material.Wood },
			FOLIAGE = { Color = vine, Material = Enum.Material.Grass },
		}

		local function cascade(at: Vector3, fallWidth: number, fallHeight: number, rotY: number?)
			group("Waterfall", function()
				local cf = CFrame.new(at) * CFrame.Angles(0, rotY or 0, 0)
				local main = block("CascadingFall", V(fallWidth, fallHeight, 2.2), V(0, 0, 0), liquidColor, Enum.Material.SmoothPlastic, nil, 0.42)
				main.CFrame = CFrame.new(origin) * cf * CFrame.new(0, fallHeight / 2, 0)
				local core = block("FallFoamCore", V(fallWidth * 0.5, math.max(1, fallHeight - 0.6), 1.3), V(0, 0, 0), rgb(225, 240, 248), Enum.Material.SmoothPlastic, nil, 0.6)
				core.CFrame = CFrame.new(origin) * cf * CFrame.new(0, fallHeight / 2 + 0.15, 0.75)
				orb("FallSplashMist", cf:PointToWorldSpace(V(0, 1.8, 1.6)), V(fallWidth * 0.9, 3.2, 4.5), rgb(220, 238, 246), Enum.Material.SmoothPlastic, 0.86)
			end)
		end

		local function balustrade(at: Vector3, rotY: number)
			if not footprintClear(at.X, at.Z, 8.5, 2) then return end
			group("Balustrade", function()
				if natural then currentParent:SetAttribute("OnTerrain", true) end
				if KitProps.Has("SolmereBalustrade") then
					kitAt("SolmereBalustrade", CFrame.new(at) * CFrame.Angles(0, rotY, 0), 1, f2Override)
					return
				end
				local cf = CFrame.new(at) * CFrame.Angles(0, rotY, 0)
				local function bPart(n: string, sz: Vector3, off: Vector3, col: Color3, mat: Enum.Material)
					local p = block(n, sz, V(0, 0, 0), col, mat)
					p.CFrame = CFrame.new(origin) * cf * CFrame.new(off)
					return p
				end
				bPart("BalustradeCurb", V(15.6, 0.9, 2.4), V(0, 0.45, 0), limestone, Enum.Material.Limestone)
				bPart("BalustradeRail", V(15.2, 0.8, 2.2), V(0, 4.15, 0), limestone, Enum.Material.Limestone)
				for _, bx in { -3.8, 0, 3.8 } do
					bPart("Baluster", V(1.0, 2.9, 1.0), V(bx, 2.3, 0), limestone, Enum.Material.Limestone)
				end
				for _, sx in { -1, 1 } do
					bPart("BalustradePost", V(2.2, 4.8, 2.6), V(sx * 7.1, 2.4, 0), limestone, Enum.Material.Limestone)
					bPart("BalustradePostBand", V(2.4, 0.6, 2.8), V(sx * 7.1, 4.1, 0), verdigris, Enum.Material.Slate)
				end
			end)
		end

		local function brokenSpan(at: Vector3, deckY: number, rotY: number)
			if not footprintClear(at.X, at.Z, 10, 6) then return end
			table.insert(reservedSpots, { at.X, at.Z, 16 })
			group("BrokenAqueductSpan", function()
				if natural then currentParent:SetAttribute("OnTerrain", true) end
				if KitProps.Has("AqueductBrokenSpan") then
					local scaleY = (deckY - bottom) / 14
					kitAt("AqueductBrokenSpan", CFrame.new(at) * CFrame.Angles(0, rotY, 0), V(1.25, scaleY, 1.05), f2Override)
					return
				end
				local cf = CFrame.new(at) * CFrame.Angles(0, rotY, 0)
				local hSpan = deckY - bottom
				local function sPart(n: string, sz: Vector3, off: Vector3, col: Color3, mat: Enum.Material)
					local p = block(n, sz, V(0, 0, 0), col, mat)
					p.CFrame = CFrame.new(origin) * cf * CFrame.new(off)
					return p
				end
				for _, sx in { -1, 1 } do
					sPart("AqueductSpanPier", V(5.2, hSpan, 5.4), V(sx * 11.2, hSpan / 2, 2.0), limestone, Enum.Material.Limestone)
					sPart("AqueductChannelWall", V(2.4, 3.6, 12.0), V(sx * 12.2, hSpan + 1.8, 0.0), limestone, Enum.Material.Limestone)
					sPart("AqueductFrieze", V(3.0, 1.4, 12.2), V(sx * 12.2, hSpan - 0.3, 0.0), verdigris, Enum.Material.Slate)
				end
				sPart("AqueductChannelDeck", V(26.4, 2.0, 11.0), V(0, hSpan - 1.0, 0.5), limestone, Enum.Material.Limestone)
				sPart("AqueductJaggedTip", V(14.0, 1.8, 5.0), V(-4.2, hSpan - 1.1, -5.2), limestone, Enum.Material.Limestone)
				sPart("AqueductMossCap", V(9.0, 0.9, 4.0), V(-3.8, hSpan + 0.1, -4.8), mossCol, Enum.Material.Grass)
			end)
		end

		-- 1. Broken Aqueduct viaduct: piers below camp clearance under AqueductSouth and AqueductNorth,
		-- snapped spans overhanging the gap, waterfalls pouring into the Reed Pond, and SE arches.
		for _, deck in { crossing, aqNorth } do
			for _, sx in { -1, 1 } do
				local pierX = deck.X + sx * (deck.Width / 2 + 2.8)
				local pierH = (deck.Y - 2.35) - bottom
				for _, sz in { -1, 1 } do
					local pierZ = deck.Z + sz * (deck.Depth * 0.28)
					if footprintClear(pierX, pierZ, 3, 4) then
						group("AqueductCornice", function()
							if natural then currentParent:SetAttribute("OnTerrain", true) end
							block("AqueductSubPier", V(5.2, pierH, 7), V(pierX, bottom + pierH / 2, pierZ), limestone, Enum.Material.Limestone)
							block("AqueductVerdigrisFrieze", V(2.6, 1.6, 12), V(pierX, deck.Y - 2.75, pierZ), verdigris, Enum.Material.Slate)
						end)
					end
				end
			end
		end
		-- Balustrades along clear edges of AqueductSouth and AqueductNorth.
		balustrade(V(crossing.X - crossing.Width / 2 + 2.2, crossing.Y, crossing.Z - 4), math.pi / 2)
		balustrade(V(crossing.X + crossing.Width / 2 - 2.2, crossing.Y, crossing.Z - 4), -math.pi / 2)
		balustrade(V(aqNorth.X - aqNorth.Width / 2 + 2.2, aqNorth.Y, aqNorth.Z + 4), math.pi / 2)

		-- The snapped gap between AqueductSouth (Z = -30) and AqueductNorth (Z = -68): clear of Crossing's 34-stud camp.
		brokenSpan(V(crossing.X, bottom, -41), crossing.Y, math.pi)
		brokenSpan(V(aqNorth.X, bottom, -57), aqNorth.Y, 0)
		cascade(V(aqNorth.X, bottom, -51), 14, aqNorth.Y - bottom + 0.5, 0)
		cascade(V(crossing.X - 4, bottom, -46), 8, crossing.Y - bottom + 0.5, math.pi)

		-- SE approach aqueduct arches continuing the diagonal toward the south-east cliff.
		for _, pt in { { 56, 38 }, { 80, 64 } } do
			if footprintClear(pt[1], pt[2], 14, 10) then
				table.insert(reservedSpots, { pt[1], pt[2], 16 })
				arch(V(pt[1], bottom, pt[2]), 24, 14, 7.5, limestone, Enum.Material.Limestone, math.rad(-42))
			end
		end

		-- 2. The Mill Ruin & Giant Waterwheel in the open mill-race pool south of MillRuin.
		local wheelAt = V(144, bottom, 16)
		if footprintClear(wheelAt.X, wheelAt.Z, 10, 10) then
			table.insert(reservedSpots, { wheelAt.X, wheelAt.Z, 22 })
			group("Waterwheel", function()
				if natural then currentParent:SetAttribute("OnTerrain", true) end
				if KitProps.Has("Waterwheel") then
					kitAt("Waterwheel", CFrame.new(wheelAt) * CFrame.Angles(0, math.rad(-128), 0), 1.12, f2Override)
				else
					local cf = CFrame.new(wheelAt) * CFrame.Angles(0, math.rad(-128), 0)
					local wCenter = cf:PointToWorldSpace(V(0, 14, 0))
					ring("WaterwheelRimOuter", wCenter, 12.5, 1.3, bark, Enum.Material.Wood, CFrame.Angles(0, math.rad(-128), 0), 0, math.pi * 2, 12)
					ring("WaterwheelRimInner", wCenter, 9.6, 0.9, barkDark, Enum.Material.Wood, CFrame.Angles(0, math.rad(-128), 0), 0, math.pi * 2, 12)
					for k = 1, 4 do
						local a = k * math.pi / 4
						local dSpoke = cf:VectorToWorldSpace(V(math.cos(a) * 12, math.sin(a) * 12, 0))
						limb("WaterwheelSpoke", wCenter - dSpoke, wCenter + dSpoke, 1.2, bark)
					end
					local wall = block("MillCradleWall", V(18, 16, 4.5), V(0, 0, 0), limestone, Enum.Material.Limestone)
					wall.CFrame = CFrame.new(origin) * cf * CFrame.new(0, 8, 4.5)
				end
			end)
		end
		balustrade(V(eastGal.X + eastGal.Width / 2 - 2.2, eastGal.Y, eastGal.Z + 12), -math.pi / 2)

		-- 3. Cistern Plaza balustrades and fallen fluted column.
		balustrade(V(westGal.X - westGal.Width / 2 + 2.2, westGal.Y, westGal.Z - 12), math.pi / 2)
		balustrade(V(westGal.X - westGal.Width / 2 + 2.2, westGal.Y, westGal.Z + 14), math.pi / 2)
		local colAt = V(westGal.X - westGal.Width / 2 + 12, westGal.Y, westGal.Z + westGal.Depth / 2 - 8)
		if footprintClear(colAt.X, colAt.Z, 6, 4) then
			group("FallenStela", function()
				local p = block("FallenCisternColumn", V(3.2, 3.2, 12), colAt + V(0, 1.6, 0), limestone, Enum.Material.Limestone, Enum.PartType.Cylinder)
				p.CFrame = CFrame.new(origin + colAt + V(0, 1.6, 0)) * CFrame.Angles(0, math.rad(34), math.pi / 2)
				lilies(colAt + V(-4, 0, -4), 3)
			end)
		end

		-- 4. Reed Pond clusters, water-lilies, stepping stones, and Mill Pond shore grazing scars.
		local function reedCluster(at: Vector3, s: number)
			if not footprintClear(at.X, at.Z, 4 * s, 4 * s) then return end
			group("ReedCluster", function()
				if natural then currentParent:SetAttribute("OnTerrain", true) end
				if KitProps.Has("ReedPondCluster") then
					kitAt("ReedPondCluster", CFrame.new(at) * CFrame.Angles(0, yawAt(at), 0), s, f2Override)
					return
				end
				for k = 1, 3 do
					local a = k * 2.1 + yawAt(at)
					local base = at + V(math.cos(a) * 1.2 * s, 0, math.sin(a) * 1.2 * s)
					beam("PondReed", base, base + V(math.cos(a) * 0.7 * s, (4.4 + (k % 2)) * s, math.sin(a) * 0.7 * s), 0.26 * s, vine, Enum.Material.Grass)
				end
				cyl("PondLilyPad", at + V(1.4 * s, 0.2, 1.0 * s), 1.6 * s, 0.25, rgb(46, 112, 58), Enum.Material.Grass)
				orb("PondLilyBloom", at + V(1.4 * s, 0.7, 1.0 * s), V(0.9 * s, 0.8 * s, 0.9 * s), sap, Enum.Material.Neon)
			end)
		end
		for _, spot in {
			{ -42, 34, 1.1 }, { -14, 42, 1.05 }, { 32, 34, 1.0 }, { -52, 4, 1.2 },
			{ -38, -24, 1.1 }, { -8, -46, 1.2 }, { 34, -46, 1.1 }, { -90, -76, 1.0 },
			{ 132, 22, 1.1 }, { 160, -4, 1.05 },
		} do
			reedCluster(V(spot[1], bottom + 2.6, spot[2]), spot[3])
		end
		-- Stepping stones across the shallow west reed pond cove (cosmetic, off-lane).
		group("PondSteppingStones", function()
			if natural then currentParent:SetAttribute("OnTerrain", true) end
			for i = 0, 5 do
				local t = i / 5
				local sx = -48 + t * 34
				local sz = 16 + math.sin(t * math.pi) * 8
				if footprintClear(sx, sz, 2.5, 2.5) then
					cyl("PondSteppingStone", V(sx, bottom + 2.4, sz), 2.1 + (i % 2) * 0.4, 3.8, limestone, Enum.Material.Limestone)
				end
			end
		end)
		-- Moss Crawler grazing scars & glow-lily beds on the Mill Pond off-lane margins.
		for _, sx in { -1, 1 } do
			local bed = V(sx * 144, basin.Y, basin.Z + 22)
			if footprintClear(bed.X, bed.Z, 6, 6) then
				group("ShoreLilyBed", function()
					block("GrazingScarStone", V(7, 0.16, 3.2), bed + V(-sx * 8, 0.08, -6), limestone, Enum.Material.Limestone)
					lilies(bed, 4)
				end)
			end
		end

		-- 5. Heartroot feeder giants on open chasm ground wrapping the broken aqueduct gap and framing the pond & mill.
		giant(-28, -50, 56, { { 85, 58, 12 }, { 30, 54, 14 }, { 160, 48, 8 } })
		giant(66, -70, 56, { { -95, 56, 12 }, { -145, 50, 10 }, { 40, 46, 10 } })
		giant(-128, 60, 52, { { 55, 56, 12 }, { 10, 50, 12 }, { 115, 52, 8 } })
		giant(116, 72, 52, { { -55, 54, 12 }, { -115, 52, 10 }, { 10, 46, 10 } })
		-- Visible Heartroot feeder roots coiling into the pond beside the snapped aqueduct pier.
		group("AqueductFeederRoots", function()
			if natural then currentParent:SetAttribute("OnTerrain", true) end
			for _, pair in {
				{ V(-22, bottom + 1, -46), V(4, aqNorth.Y - 1, -68) },
				{ V(-20, bottom + 0.5, -42), V(4, crossing.Y - 1, -30) },
				{ V(58, bottom + 1, -68), V(28, aqNorth.Y - 2, -68) },
			} do
				if footprintClear((pair[1].X + pair[2].X) / 2, (pair[1].Z + pair[2].Z) / 2, 4, 4) then
					limb("HeartrootFeederRoot", pair[1], pair[2], 2.2, barkDark)
				end
			end
		end)
	elseif layout.Authored == "verdant:3" then
		local westGal = layout.Platforms.WestGallery
		local eastGal = layout.Platforms.EastGallery
		local mossCol = rgb(86, 132, 58)
		local f3Override: KitProps.Override = {
			TRIM = { Color = limestone, Material = Enum.Material.Limestone },
			ACCENT = { Color = verdigris, Material = Enum.Material.Slate },
			GOLD = { Color = gold, Material = Enum.Material.Cobblestone },
			GLOW = { Color = sap, Material = Enum.Material.Neon },
			MOSS = { Color = mossCol, Material = Enum.Material.Grass },
			WOOD = { Color = bark, Material = Enum.Material.Wood },
			FOLIAGE = { Color = vine, Material = Enum.Material.Grass },
		}

		local function canyonWaterfall(at: Vector3, fallWidth: number, fallHeight: number, rotY: number)
			group("Waterfall", function()
				local cf = CFrame.new(at) * CFrame.Angles(0, rotY, 0)
				local main = block("CascadingFall", V(fallWidth, fallHeight, 2.6), V(0, 0, 0), liquidColor, Enum.Material.SmoothPlastic, nil, 0.36)
				main.CFrame = CFrame.new(origin) * cf * CFrame.new(0, fallHeight / 2, 0)
				local core = block("FallFoamCore", V(fallWidth * 0.52, math.max(1, fallHeight - 0.8), 1.5), V(0, 0, 0), rgb(225, 240, 248), Enum.Material.SmoothPlastic, nil, 0.54)
				core.CFrame = CFrame.new(origin) * cf * CFrame.new(0, fallHeight / 2 + 0.15, 0.85)
				local mist = block("FallPoolFoam", V(fallWidth * 1.25, 1.4, 9.5), V(0, 0, 0), rgb(225, 242, 246), Enum.Material.SmoothPlastic, nil, 0.55)
				mist.CFrame = CFrame.new(origin) * cf * CFrame.new(0, 2.2, 4.2)
			end)
		end

		local function fernAt(at: Vector3, s: number)
			if not footprintClear(at.X, at.Z, 4.5 * s, 4.5 * s) then return end
			group("FernCluster", function()
				if natural then currentParent:SetAttribute("OnTerrain", true) end
				if KitProps.Has("FernCluster") then
					kitAt("FernCluster", CFrame.new(at) * CFrame.Angles(0, yawAt(at), 0), s, f3Override)
					return
				end
				for k = 1, 5 do
					local a = k * (math.pi * 2 / 5) + yawAt(at)
					local tip = at + V(math.cos(a) * 4.4 * s, 2.1 * s, math.sin(a) * 4.4 * s)
					limb("FernFrond", at + V(0, 0.5, 0), tip, 0.9 * s, vine)
				end
			end)
		end

		local function lanternAt(at: Vector3, rotY: number, emitLight: boolean)
			if not footprintClear(at.X, at.Z, 2.4, 2.4) then return end
			group("RootKnotLantern", function()
				if KitProps.Has("RootKnotLantern") then
					kitAt("RootKnotLantern", CFrame.new(at) * CFrame.Angles(0, rotY, 0), 0.9, f3Override)
				else
					block("LanternPlinth", V(2.8, 1.0, 2.8), at + V(0, 0.5, 0), limestone, Enum.Material.Limestone)
					block("LanternPost", V(1.6, 4.4, 1.6), at + V(0, 3.2, 0), limestone, Enum.Material.Limestone)
					local bulb = orb("LanternGlow", at + V(0, 6.2, 0), V(1.4, 1.6, 1.4), sap, Enum.Material.Neon)
					if emitLight then pointLight(bulb, sap, 0.75, 22) end
				end
			end)
		end

		-- 1. West Gorge Waterfall (40-stud wide canyon cascade facing east/south away from every ramp).
		canyonWaterfall(V(-192, bottom, -78), 38, 48, math.rad(118))

		-- 2. Sweeping West Root Arch in the upper-west gorge in front of the cliff waterfall (matches left art).
		local archAt = V(-156, bottom + 2, -82)
		table.insert(reservedSpots, { archAt.X, archAt.Z, 24 })
		group("RootBridgeArch", function()
			if natural then currentParent:SetAttribute("OnTerrain", true) end
			if KitProps.Has("RootBridgeArch") then
				kitAt("RootBridgeArch", CFrame.new(archAt) * CFrame.Angles(0, math.rad(16), 0), V(1.32, 1.38, 1.25), f3Override)
			else
				arch(archAt, 56, 28, 7.5, bark, Enum.Material.Wood, math.rad(16))
			end
		end)
		-- 3. Gorge-cliff root tendrils & Solmere bridge trail lanterns. (Pad under-roots are anchored directly
		-- inside each solid island/stump core in TowerRoomBuilder so nothing disconnects or floats.)
		for _, curve in {
			{ V(-44, apex.Y - 3, apex.Z + 22), V(-64, 5, -92), V(-78, bottom - 3, -54) },
			{ V(44, apex.Y - 3, apex.Z + 22), V(66, 5, -90), V(82, bottom - 3, -50) },
			{ V(-46, basin.Y - 2, basin.Z - 40), V(-58, -3, 38), V(-72, bottom - 3, 12) },
			{ V(46, basin.Y - 2, basin.Z - 40), V(58, -3, 36), V(74, bottom - 3, 10) },
			{ V(-124, basin.Y - 2, basin.Z - 38), V(-132, -2, 34), V(-120, bottom - 3, 4) },
			{ V(124, basin.Y - 2, basin.Z - 38), V(134, -2, 32), V(122, bottom - 3, 2) },
		} do
			group("GorgeRootTendril", function()
				if natural then currentParent:SetAttribute("OnTerrain", true) end
				limb("GorgeRootArc", curve[1], curve[2], 3.8, bark)
				limb("GorgeRootArc", curve[2], curve[3], 4.6, barkDark)
				beam("GorgeRootSap", curve[2], curve[3] + V(0, 2, 0), 0.5, sap, Enum.Material.Neon, 0.25)
			end)
		end
		-- Iconic RootKnotLanterns framing The Knot's outer stair corners (>34 from camp) & Fern Bank root bridge entry.
		for _, spot in {
			{ crossing.X - 28, crossing.Y, crossing.Z + 24, 0.2, true },
			{ crossing.X + 28, crossing.Y, crossing.Z + 24, -0.2, false },
			{ crossing.X - 28, crossing.Y, crossing.Z - 24, 2.9, true },
			{ crossing.X + 28, crossing.Y, crossing.Z - 24, -2.9, false },
			{ -24, basin.Y, basin.Z - basin.Depth / 2 + 6, 0.1, false },
			{ 24, basin.Y, basin.Z - basin.Depth / 2 + 6, -0.1, false },
		} do
			lanternAt(V(spot[1], spot[2], spot[3]), spot[4], spot[5])
		end

		-- 4. Hollow Stump (EastGallery): outer crescent jagged bark rim (solid trunk & buttresses live in TowerRoomBuilder).
		local stumpRimAt = V(eastGal.X + 34, eastGal.Y - 11, eastGal.Z - 14)
		table.insert(reservedSpots, { stumpRimAt.X, stumpRimAt.Z, 26 })
		group("HollowStumpRim", function()
			if natural then currentParent:SetAttribute("OnTerrain", true) end
			if KitProps.Has("HollowStumpRim") then
				kitAt("HollowStumpRim", CFrame.new(stumpRimAt) * CFrame.Angles(0, math.rad(-122), 0), 0.78, f3Override)
			else
				for k = -3, 3 do
					local a = math.rad(k * 20 - 25)
					local px = eastGal.X + math.cos(a) * 46
					local pz = eastGal.Z + math.sin(a) * 40
					local sh = 14 + (3 - math.abs(k)) * 3.5
					block("HollowStumpBarkStave", V(8, sh, 7), V(px, eastGal.Y + sh / 2 - 4, pz), barkDark, Enum.Material.Wood)
				end
			end
		end)

		-- 5. Weathered Solmere stela & lush FernCluster carpet along Fern Bank and riverbanks.
		for _, spot in {
			{ -58, basin.Y, basin.Z - 26, 1.35 }, { 58, basin.Y, basin.Z - 26, 1.3 },
			{ -92, basin.Y, basin.Z - 38, 1.2 }, { 92, basin.Y, basin.Z - 38, 1.25 },
			{ -40, basin.Y, basin.Z - 46, 1.25 }, { 40, basin.Y, basin.Z - 46, 1.25 },
			{ -155, basin.Y, basin.Z + 18, 1.4 }, { 155, basin.Y, basin.Z + 18, 1.35 },
			{ -46, apex.Y, apex.Z - 14, 1.3 }, { 46, apex.Y, apex.Z - 14, 1.3 },
			{ -44, apex.Y, apex.Z + 26, 1.15 }, { 44, apex.Y, apex.Z + 26, 1.15 },
		} do
			fernAt(V(spot[1], spot[2], spot[3]), spot[4])
		end
		-- Fallen weathered sun-disc stela on Fern Bank's south-west edge (seen left foreground in Floor 3 art).
		if footprintClear(-34, basin.Z + 32, 6, 5) then
			group("FallenStela", function()
				local at = V(-34, basin.Y, basin.Z + 32)
				local p = block("SolmereStelaFallen", V(3.4, 2.2, 11 * scale), at + V(0, 1.0, 0), limestone, Enum.Material.Limestone)
				p.CFrame = CFrame.new(origin + at + V(0, 1.0, 0)) * CFrame.Angles(math.rad(-12), math.rad(38), 0)
				lilies(at + V(6, 0, -4), 3)
			end)
		end

		-- 6. Glow-lily rafts drifting along the gorge river (y = bottom + 3.2 water surface).
		for _, spot in {
			{ -68, -44 }, { -42, -32 }, { 38, -48 }, { 64, -30 }, { -126, -64 }, { 96, -54 },
		} do
			if footprintClear(spot[1], spot[2], 5, 5) then
				group("RiverLilyRaft", function()
					if natural then currentParent:SetAttribute("OnTerrain", true) end
					lilies(V(spot[1], bottom + 3.1, spot[2]), 3)
				end)
			end
		end

		-- 7. Flank Heartroot canyon giants framing the gorge without crowding walkways or river middle.
		giant(-196, 48, 62, { { 65, 64, 14 }, { 15, 56, 12 }, { 125, 48, 8 } })
		giant(198, 44, 60, { { -65, 62, 14 }, { -15, 54, 12 }, { -120, 48, 8 } })
		giant(-120, -172, 66, { { 75, 64, 14 }, { 125, 56, 12 }, { 25, 52, 10 } })
		giant(120, -172, 66, { { -75, 64, 14 }, { -125, 56, 12 }, { -25, 52, 10 } })
	elseif layout.Authored == "verdant:4" then
		local westGal = layout.Platforms.WestGallery
		local eastGal = layout.Platforms.EastGallery
		local bastionW = layout.Platforms.WestBastion
		local bastionE = layout.Platforms.EastBastion
		local mossCol = rgb(86, 132, 58)
		local f4Override: KitProps.Override = {
			TRIM = { Color = limestone, Material = Enum.Material.Limestone },
			ACCENT = { Color = verdigris, Material = Enum.Material.Slate },
			GOLD = { Color = gold, Material = Enum.Material.Cobblestone },
			GLOW = { Color = sap, Material = Enum.Material.Neon },
			MOSS = { Color = mossCol, Material = Enum.Material.Grass },
			WOOD = { Color = bark, Material = Enum.Material.Wood },
		}

		-- 1. Breached Gatehouse Arch astride Crossing's north stair exit plus fortress bridge arches across the wings & wall-walks.
		local gateAt = V(crossing.X, crossing.Y, crossing.Z - crossing.Depth / 2 - 10)
		group("RampArch", function()
			if KitProps.Has("GatehouseArch") then
				kitAt("GatehouseArch", CFrame.new(gateAt), 1.08, f4Override)
			else
				for _, s in { -1, 1 } do
					block("GatehousePier", V(12, 26, 12), gateAt + V(s * 23, 13, 0), limestone, Enum.Material.Limestone)
					sunDisc("GatehouseSunDisc", gateAt + V(s * 23, 14.5, 6.4), 2.6, nil, false)
				end
				block("GatehouseLintel", V(56, 5.5, 11), gateAt + V(0, 24.5, 0), limestone, Enum.Material.Limestone)
				limb("GatehouseStranglerFig", gateAt + V(19, 0, 5), gateAt + V(14, 26, 4), 2.8, bark)
			end
		end)
		for _, pair in {
			{ "Crossing", "WestGallery", 38, 24 },
			{ "Crossing", "EastGallery", 38, 24 },
			{ "WestGallery", "WestBastion", 38, 24 },
			{ "EastGallery", "EastBastion", 38, 24 },
		} do
			local wMid, wYaw = spineMid(pair[1], pair[2])
			if wMid.Magnitude > 0 then
				rampArch(wMid, wYaw, pair[3], pair[4] * scale, 7.5, limestone)
			end
		end

		-- Twin crouching Vinebound Guardian statues flanking the front corner piers of the Gatehouse & Keep perimeter.
		for _, sx in { -1, 1 } do
			local gAt = V(sx * 30, crossing.Y, crossing.Z + 24)
			if footprintClear(gAt.X, gAt.Z, 4.5, 4.5) then
				group("VineboundGuardian", function()
					if KitProps.Has("VineboundGuardian") then
						kitAt("VineboundGuardian", CFrame.new(gAt) * CFrame.Angles(0, math.rad(-sx * 16), 0), 1.05, f4Override)
					else
						block("GuardianPlinth", V(9, 1.8, 9), gAt + V(0, 0.9, 0), limestone, Enum.Material.Limestone)
						block("GuardianBody", V(7, 9, 6), gAt + V(0, 6.2, 0), limestone, Enum.Material.Limestone)
						orb("GuardianCore", gAt + V(0, 8, 3.1), V(1.6, 1.6, 0.8), sap, Enum.Material.Neon)
					end
				end)
			end
			local keepGuardAt = V(sx * 82, apex.Y - 2, apex.Z - 24)
			if footprintClear(keepGuardAt.X, keepGuardAt.Z, 5, 5) then
				group("VineboundGuardian", function()
					if KitProps.Has("VineboundGuardian") then
						kitAt("VineboundGuardian", CFrame.new(keepGuardAt) * CFrame.Angles(0, math.rad(-sx * 24), 0), 1.25, f4Override)
					end
				end)
			end
		end

		-- 2. Grand multi-tier Castle Curtain Walls surrounding the Gatehouse, Inner Ward, Keep flanks & perimeter.
		for idxW, wall in {
			{ x = -70, y = crossing.Y + 4, z = -10, yaw = 0.14, sx = 1.65, sy = 1.85 },
			{ x = -106, y = crossing.Y + 5, z = -32, yaw = -0.18, sx = 1.65, sy = 1.85 },
			{ x = 70, y = crossing.Y + 4, z = -20, yaw = -0.14, sx = 1.65, sy = 1.85 },
			{ x = 106, y = crossing.Y + 5, z = -32, yaw = 0.18, sx = 1.65, sy = 1.85 },
			{ x = -88, y = bastionW.Y, z = -98, yaw = 0.28, sx = 1.60, sy = 1.75 },
			{ x = 88, y = bastionE.Y, z = -106, yaw = -0.28, sx = 1.60, sy = 1.75 },
			{ x = -96, y = apex.Y - 4, z = -228, yaw = -0.18, sx = 1.65, sy = 1.75 },
			{ x = 96, y = apex.Y - 4, z = -228, yaw = 0.18, sx = 1.65, sy = 1.75 },
			{ x = -228, y = westGal.Y + 2, z = -68, yaw = math.pi / 2, sx = 1.75, sy = 1.95 },
			{ x = 228, y = eastGal.Y + 2, z = -76, yaw = -math.pi / 2, sx = 1.75, sy = 1.95 },
		} do
			local checkHalfX = if math.abs(wall.yaw) > 1.0 then 6 else 22
			local checkHalfZ = if math.abs(wall.yaw) > 1.0 then 22 else 6
			if footprintClear(wall.x, wall.z, checkHalfX, checkHalfZ) then
				table.insert(reservedSpots, { wall.x, wall.z, 26 })
				group("CurtainWallRuins", function()
					if natural then currentParent:SetAttribute("OnTerrain", true) end
					-- Tall battered limestone castle foundation plinth descending solidly into moat bed (bottom = -8)
					local plinthH = wall.y - bottom + 1.5 - (idxW % 2) * 0.2
					local plinth = block("CurtainWallPlinth", V(31 * wall.sx, plinthH, 9.5 + (idxW % 2) * 0.3), V(wall.x, (wall.y + bottom) / 2 - (idxW % 2) * 0.1, wall.z), limestone, Enum.Material.Limestone)
					plinth.CFrame = CFrame.new(origin + V(wall.x, (wall.y + bottom) / 2, wall.z)) * CFrame.Angles(0, wall.yaw, 0)
					if KitProps.Has("CurtainWallRuins") then
						kitAt("CurtainWallRuins", CFrame.new(V(wall.x, wall.y, wall.z)) * CFrame.Angles(0, wall.yaw, 0), V(wall.sx, wall.sy, 1.45), f4Override)
					else
						local wallBody = block("CurtainWallBody", V(30 * wall.sx, 16 * wall.sy, 6.5), V(wall.x, wall.y + 8 * wall.sy, wall.z), limestone, Enum.Material.Limestone)
						wallBody.CFrame = CFrame.new(origin + V(wall.x, wall.y + 8 * wall.sy, wall.z)) * CFrame.Angles(0, wall.yaw, 0)
					end
				end)
			end
		end

		-- 3. Grander Vinebound Bastion Towers beside West & East Towers plus flanking northern corner turrets.
		local wTowerAt = V(bastionW.X - bastionW.Width / 2 - 12, bottom, bastionW.Z - 6)
		local eTowerAt = V(bastionE.X + bastionE.Width / 2 + 12, bottom, bastionE.Z - 6)
		table.insert(reservedSpots, { wTowerAt.X, wTowerAt.Z, 22 })
		table.insert(reservedSpots, { eTowerAt.X, eTowerAt.Z, 22 })
		for idxT, specT in {
			{ at = wTowerAt, lean = 0, scaleXZ = 1.45, scaleY = 1.75 },
			{ at = eTowerAt, lean = math.rad(-5.5), scaleXZ = 1.45, scaleY = 1.70 },
			{ at = V(-222, bottom, -188), lean = 0.02, scaleXZ = 1.05, scaleY = 1.32 },
			{ at = V(222, bottom, -194), lean = -0.04, scaleXZ = 1.05, scaleY = 1.28 },
		} do
			if footprintClear(specT.at.X, specT.at.Z, 12, 12) then
				table.insert(reservedSpots, { specT.at.X, specT.at.Z, 18 })
				group("VineboundTower", function()
					if natural then currentParent:SetAttribute("OnTerrain", true) end
					if KitProps.Has("VineboundTower") then
						kitAt("VineboundTower", CFrame.new(specT.at) * CFrame.Angles(0, idxT * 1.1, specT.lean), V(specT.scaleXZ, specT.scaleY, specT.scaleXZ), f4Override)
					else
						local towerBody = cyl("BastionWatchtower", specT.at + V(0, 34, 0), 12, 68, limestone, Enum.Material.Limestone)
						towerBody.CFrame = CFrame.new(origin + specT.at + V(0, 34, 0)) * CFrame.Angles(0, 0, math.pi / 2 + specT.lean)
					end
				end)
			end
		end
		-- Overhead vine cables slung high between the towers and the Inner Keep (above Y + 34, never blocking cams/lanes).
		for _, cable in {
			{ wTowerAt + V(12, 72, 0), V(-24, apex.Y + 46, apex.Z - apex.Depth / 2 - 10) },
			{ eTowerAt + V(-12, 68, 0), V(24, apex.Y + 46, apex.Z - apex.Depth / 2 - 10) },
		} do
			group("AirborneVineCable", function()
				currentParent:SetAttribute("OnTerrain", true)
				local midCable = (cable[1] + cable[2]) * 0.5 - V(0, 6, 0)
				limb("HighVineCable", cable[1], midCable, 1.8, bark)
				limb("HighVineCable", midCable, cable[2], 1.8, barkDark)
			end)
		end

		-- 4. Sculpted Solmere Ruins: Barracks spear rack & broken colonnade, Sun Shrine sculpted SunDiscShrine, broken inner marsh arches & balustrades.
		local rackAt = V(westGal.X - 36, westGal.Y, westGal.Z - 32)
		if footprintClear(rackAt.X, rackAt.Z, 2.5, 5) then
			group("BarracksSpearRack", function()
				block("SpearRackFrame", V(2.4, 5.5, 10), rackAt + V(0, 2.75, 0), barkDark, Enum.Material.Wood)
				for sIdx = -1, 1 do
					limb("MossyStoneSpear", rackAt + V(1.6, 0.2, sIdx * 3), rackAt + V(-0.4, 7.2, sIdx * 3), 0.55, limestone)
				end
			end)
		end
		local wRuinsAt = V(westGal.X - 36, westGal.Y, westGal.Z - 16)
		if footprintClear(wRuinsAt.X, wRuinsAt.Z, 6, 9) then
			group("BarracksRuinedSpan", function()
				if KitProps.Has("AqueductBrokenSpan") then
					kitAt("AqueductBrokenSpan", CFrame.new(wRuinsAt) * CFrame.Angles(0, math.pi / 2, 0), 0.85, f4Override)
				elseif KitProps.Has("RuinRubble") then
					kitAt("RuinRubble", CFrame.new(wRuinsAt), 1.1, f4Override)
				end
			end)
		end
		local shrineAt = V(eastGal.X + 36, eastGal.Y, eastGal.Z - 26)
		if footprintClear(shrineAt.X, shrineAt.Z, 5, 5) then
			group("SunDiscShrine", function()
				if KitProps.Has("SunDiscShrine") then
					kitAt("SunDiscShrine", CFrame.new(shrineAt) * CFrame.Angles(0, -math.pi / 2, 0), 0.62, f4Override)
				else
					block("AltarPlinth", V(5.5, 3.2, 6.5), shrineAt + V(0, 1.6, 0), limestone, Enum.Material.Limestone)
					sunDisc("CrackedAltarSun", shrineAt + V(0, 6.2, 0), 2.1, CFrame.Angles(0, -math.pi / 2, math.rad(12)), true)
				end
			end)
		end
		local eRuinsAt = V(eastGal.X + 36, eastGal.Y, eastGal.Z - 4)
		if footprintClear(eRuinsAt.X, eRuinsAt.Z, 6, 8) then
			group("SunShrineRuinedSpan", function()
				if KitProps.Has("AqueductBrokenSpan") then
					kitAt("AqueductBrokenSpan", CFrame.new(eRuinsAt) * CFrame.Angles(0, -math.pi / 2, 0), 0.82, f4Override)
				end
			end)
		end

		-- Crumbling vaulted Solmere ruin arches standing in the Inner Marsh & Outer Ward edges
		for _, span in {
			{ x = -68, y = bottom, z = -56, yaw = 0.35, s = 1.35 },
			{ x = 68, y = bottom, z = -62, yaw = -0.35, s = 1.35 },
			{ x = -74, y = basin.Y, z = 152, yaw = 0.22, s = 1.05 },
			{ x = 74, y = basin.Y, z = 152, yaw = -0.22, s = 1.05 },
		} do
			if footprintClear(span.x, span.z, 12, 8) then
				table.insert(reservedSpots, { span.x, span.z, 16 })
				group("RuinedCastleVault", function()
					if natural then currentParent:SetAttribute("OnTerrain", true) end
					if KitProps.Has("AqueductBrokenSpan") then
						kitAt("AqueductBrokenSpan", CFrame.new(V(span.x, span.y, span.z)) * CFrame.Angles(0, span.yaw, 0), span.s, f4Override)
					end
				end)
			end
		end

		-- Carved Solmere balustrades along clear Outer Ward marsh edges
		for _, bal in {
			{ -144, basin.Y, 110, 0 }, { 144, basin.Y, 110, 0 },
			{ -54, basin.Y, 200, 0 }, { 54, basin.Y, 200, 0 },
		} do
			if footprintClear(bal[1], bal[3], 8, 2) and KitProps.Has("SolmereBalustrade") then
				group("SolmereBalustrade", function()
					kitAt("SolmereBalustrade", CFrame.new(V(bal[1], bal[2], bal[3])) * CFrame.Angles(0, bal[4], 0), 1.0, f4Override)
				end)
			end
		end

		-- 5. Marsh reeds, lily pads & sculpted ruin rubble / stone urn / fern clusters in the Outer Ward green moat.
		for _, spot in {
			{ -48, bottom + 3.2, 72 }, { 48, bottom + 3.2, 72 }, { -138, bottom + 3.2, 72 },
			{ 138, bottom + 3.2, 72 }, { -88, bottom + 3.2, -50 }, { 88, bottom + 3.2, -50 },
		} do
			if footprintClear(spot[1], spot[3], 4, 4) then
				group("MoatReedRaft", function()
					if natural then currentParent:SetAttribute("OnTerrain", true) end
					if KitProps.Has("ReedPondCluster") then
						kitAt("ReedPondCluster", CFrame.new(V(spot[1], spot[2] - 0.4, spot[3])) * CFrame.Angles(0, spot[1], 0), 1.15, f4Override)
					else
						lilies(V(spot[1], spot[2], spot[3]), 4)
					end
				end)
			end
		end
		for idxR, spot in {
			{ -52, basin.Y, 174, 0.4 }, { 52, basin.Y, 174, -0.5 },
			{ -162, basin.Y, 192, 0.8 }, { 162, basin.Y, 192, -0.7 },
		} do
			if footprintClear(spot[1], spot[3], 5, 5) then
				group("ToppledWallRubble", function()
					local rAt = V(spot[1], spot[2], spot[3])
					if KitProps.Has("RuinRubble") then
						kitAt("RuinRubble", CFrame.new(rAt) * CFrame.Angles(0, spot[4], 0), 1.25, f4Override)
						if KitProps.Has("StoneUrn") and idxR % 2 == 1 then
							kitAt("StoneUrn", CFrame.new(rAt + V(4.2, 0, 1.8)), 0.85, f4Override)
						end
						if KitProps.Has("FernCluster") then
							kitAt("FernCluster", CFrame.new(rAt + V(-3.5, 0, -2.5)), 0.9, f4Override)
						end
					else
						local p = block("MoatFallenBlock", V(8, 3.5, 5), rAt + V(0, 1.5, 0), limestone, Enum.Material.Limestone)
						p.CFrame = CFrame.new(origin + rAt + V(0, 1.5, 0)) * CFrame.Angles(0.1, spot[4], 0.14)
					end
				end)
			end
		end

		-- 6. Perimeter vine-draped Heartroot giants outside return ramps & colossal background trees behind Inner Keep.
		giant(-238, 84, 62, { { 65, 56, 12 }, { 15, 50, 10 } })
		giant(238, 84, 62, { { -65, 56, 12 }, { -15, 50, 10 } })
		giant(-62, -246, 82, { { 70, 68, 16 }, { 125, 58, 12 }, { 25, 56, 14 } })
		giant(62, -246, 76, { { -70, 64, 15 }, { -120, 56, 12 }, { -25, 52, 12 } })
	elseif layout.Authored == "verdant:5" then
		local bastionW = layout.Platforms.WestBastion
		local bastionE = layout.Platforms.EastBastion
		local eastGal = layout.Platforms.EastGallery
		local mossCol = rgb(82, 134, 62)
		local f5Override: KitProps.Override = {
			TRIM = { Color = limestone, Material = Enum.Material.Limestone },
			ACCENT = { Color = verdigris, Material = Enum.Material.Slate },
			GOLD = { Color = gold, Material = Enum.Material.Cobblestone },
			GLOW = { Color = sap, Material = Enum.Material.Neon },
			MOSS = { Color = mossCol, Material = Enum.Material.Grass },
			FOLIAGE = { Color = rgb(44, 108, 56), Material = Enum.Material.Grass },
			WOOD = { Color = bark, Material = Enum.Material.Wood },
		}

		-- 1. Flanking Two-Tier Solmere Colonnade Galleries framing West/East Terrace & NW/NE Tiers around the Cenote.
		for _, wing in {
			{ x = -240, y = westGal.Y, z = westGal.Z, yaw = math.pi / 2, sy = 1.25 },
			{ x = 240, y = eastGal.Y, z = eastGal.Z, yaw = -math.pi / 2, sy = 1.25 },
			{ x = -228, y = bastionW.Y, z = bastionW.Z, yaw = math.pi / 2 - 0.16, sy = 1.32 },
			{ x = 228, y = bastionE.Y, z = bastionE.Z, yaw = -math.pi / 2 + 0.16, sy = 1.32 },
		} do
			if footprintClear(wing.x, wing.z, 8, 22) then
				table.insert(reservedSpots, { wing.x, wing.z, 24 })
				group("SolmereColonnadeWing", function()
					if natural then currentParent:SetAttribute("OnTerrain", true) end
					local plinthH = wing.y - bottom + 1.5
					local plinth = block("ColonnadeWingPlinth", V(56, plinthH, 16), V(wing.x, (wing.y + bottom) / 2, wing.z), limestone, Enum.Material.Limestone)
					plinth.CFrame = CFrame.new(origin + V(wing.x, (wing.y + bottom) / 2, wing.z)) * CFrame.Angles(0, wing.yaw, 0)
					if KitProps.Has("SolmereColonnadeWing") then
						kitAt("SolmereColonnadeWing", CFrame.new(V(wing.x, wing.y, wing.z)) * CFrame.Angles(0, wing.yaw, 0), V(1.15, wing.sy, 1.15), f5Override)
					else
						local body = block("ColonnadeWingWall", V(54, 28, 12), V(wing.x, wing.y + 14, wing.z), limestone, Enum.Material.Limestone)
						body.CFrame = CFrame.new(origin + V(wing.x, wing.y + 14, wing.z)) * CFrame.Angles(0, wing.yaw, 0)
					end
				end)
			end
		end

		-- 2. Four Stepped Amphitheatre Waterfall Spillways pouring from the court walls down into the misty Cenote pool.
		for _, fall in {
			{ x = -102, y = bottom + 2, z = -84, yaw = -math.pi * 0.42 },
			{ x = 102, y = bottom + 2, z = -88, yaw = math.pi * 0.42 },
			{ x = -104, y = bottom + 2, z = 16, yaw = -math.pi * 0.56 },
			{ x = 104, y = bottom + 2, z = 10, yaw = math.pi * 0.56 },
		} do
			if footprintClear(fall.x, fall.z, 10, 10) then
				table.insert(reservedSpots, { fall.x, fall.z, 16 })
				group("CenoteCascadeSpillway", function()
					if natural then currentParent:SetAttribute("OnTerrain", true) end
					if KitProps.Has("CenoteCascadeSpillway") then
						kitAt("CenoteCascadeSpillway", CFrame.new(V(fall.x, fall.y - 2, fall.z)) * CFrame.Angles(0, fall.yaw, 0), 1.15, f5Override)
					else
						block("SpillwayChute", V(18, 24, 14), V(fall.x, fall.y + 10, fall.z), limestone, Enum.Material.Limestone)
					end
					waterfall(V(fall.x - math.sin(fall.yaw) * 10, bottom, fall.z - math.cos(fall.yaw) * 10), 12, 26, liquidColor, fall.yaw)
				end)
			end
		end

		-- 3. Crumbling vaulted Solmere arches rising out of the misty cenote lagoon flanking Sunbridge.
		for _, span in {
			{ x = -62, y = bottom, z = -74, yaw = 0.25, s = 1.35 },
			{ x = 62, y = bottom, z = -74, yaw = -0.25, s = 1.35 },
		} do
			if footprintClear(span.x, span.z, 10, 8) and KitProps.Has("AqueductBrokenSpan") then
				table.insert(reservedSpots, { span.x, span.z, 15 })
				group("CenoteRuinedVault", function()
					if natural then currentParent:SetAttribute("OnTerrain", true) end
					kitAt("AqueductBrokenSpan", CFrame.new(V(span.x, span.y, span.z)) * CFrame.Angles(0, span.yaw, 0), span.s, f5Override)
				end)
			end
		end

		-- 4. Carved Solmere balustrades framing Cenote Rim shores & south overlook.
		for _, bal in {
			{ -148, basin.Y, 128 }, { 148, basin.Y, 128 },
			{ -56, basin.Y, 212 }, { 56, basin.Y, 212 },
		} do
			if footprintClear(bal[1], bal[3], 8, 2) and KitProps.Has("SolmereBalustrade") then
				group("SolmereBalustrade", function()
					kitAt("SolmereBalustrade", CFrame.new(V(bal[1], bal[2], bal[3])), 1.0, f5Override)
				end)
			end
		end

		-- 5. Open Luminous Glow-Lily Clusters (emerald & gold dusk blooms) on Cenote Rim and shimmering cenote water edges.
		for idxL, spot in {
			{ -48, basin.Y, 188, 1.2 }, { 48, basin.Y, 188, 1.2 },
			{ -168, basin.Y, 196, 1.15 }, { 168, basin.Y, 196, 1.15 },
			{ -54, bottom + 3.0, 82, 1.25 }, { 54, bottom + 3.0, 82, 1.25 },
			{ -56, bottom + 3.0, -24, 1.25 }, { 56, bottom + 3.0, -24, 1.25 },
		} do
			if footprintClear(spot[1], spot[3], 4, 4) then
				group("GlowLilyCluster", function()
					if natural then currentParent:SetAttribute("OnTerrain", true) end
					if KitProps.Has("GlowLilyCluster") then
						local model = kitAt("GlowLilyCluster", CFrame.new(V(spot[1], spot[2] - 0.15, spot[3])) * CFrame.Angles(0, idxL * 1.3, 0), spot[4], f5Override)
						if model and idxL <= 4 then
							local anchor = model:FindFirstChildWhichIsA("BasePart")
							if anchor then
								pointLight(anchor, if idxL % 2 == 0 then rgb(255, 224, 130) else sap, 1.1, 22)
							end
						end
					else
						lilies(V(spot[1], spot[2], spot[3]), 4)
					end
				end)
			end
		end

		-- 6. Perimeter Heartroot Giants framing Cenote Rim outside the return ramps.
		giant(-254, 118, 66, { { 65, 58, 12 }, { 12, 52, 10 } })
		giant(254, 118, 66, { { -65, 58, 12 }, { -12, 52, 10 } })
	end
	end

	-- Floor 11, Cinder Gate (ashen:1): searing sunlit Varrash frontier modeled after media_1794989586079_d62a0199.jpg:
	-- flanking sandstone parapet steps on Sun-Bleached Steps, amber-caged VarrashWaystones lining the tracks,
	-- half-buried Varrash caravan wagon on the Sleeping Dune windward slope, banded TollHouseRuins + nomad
	-- Ash Raider tents on the west, tapered WatchKilnTower on the east, amber crystal clusters & dead snags.
	if layout.Authored == "ashen:1" then
		local vSand = rgb(188, 158, 116)
		local vTerra = rgb(175, 95, 65)
		local vBasalt = rgb(44, 38, 40)
		local vIron = rgb(58, 52, 56)
		local vAmber = rgb(255, 162, 62)
		local vCrystal = rgb(255, 126, 36)
		local vWood = rgb(142, 118, 92)
		local vDeadWood = rgb(186, 174, 156)
		local vCanvas = rgb(104, 108, 112)
		local vDriftSand = rgb(122, 110, 96)

		local function ashenGroundAt(x: number, z: number): number
			for _, t in layout.Platforms do
				if math.abs(x - t.X) <= t.Width / 2 and math.abs(z - t.Z) <= t.Depth / 2 then
					return t.Y
				end
			end
			return if field then math.max(field.Sample(x, z), bottom) else bottom
		end

		local f11Override = {
			TRIM = { Color = vSand, Material = Enum.Material.Sandstone },
			ALT = { Color = vTerra, Material = Enum.Material.Slate },
			STONE = { Color = vBasalt, Material = Enum.Material.Basalt },
			METAL = { Color = vIron, Material = Enum.Material.Metal },
			GLOW = { Color = vAmber, Material = Enum.Material.Neon },
			ACCENT = { Color = vCrystal, Material = Enum.Material.Slate },
			WOOD = { Color = vWood, Material = Enum.Material.Wood },
			FOLIAGE = { Color = vCanvas, Material = Enum.Material.Fabric },
			MOSS = { Color = vDriftSand, Material = Enum.Material.Sand },
		}

		-- 1. Foreground Sanctuary framing: stepped banded sandstone retaining parapets & dark basalt flagstones
		group("SanctuaryVarrashSteps", function()
			currentParent:SetAttribute("OnTerrain", true)
			for _, s in { -1, 1 } do
				for step = 0, 2 do
					local px = s * (30 + step * 11)
					local pz = 121 + step * 5
					local py = ashenGroundAt(px, pz)
					local hWall = 3.6 + step * 1.4
					block("ForegroundParapetBase", V(11.5, hWall, 4.6), V(px, py + hWall * 0.5 - 1.2, pz), vBasalt, Enum.Material.Basalt)
					block("ForegroundParapetCap", V(12.2, 1.3, 5.2), V(px, py + hWall - 0.65, pz), vSand, Enum.Material.Sandstone)
				end
			end
			for k = -3, 3 do
				local px = k * 7.2
				local pz = 123 + ((math.abs(k) * 3) % 5)
				local py = ashenGroundAt(px, pz)
				local paver = block("ForegroundBasaltPaver", V(5.4 + (math.abs(k) % 2) * 1.1, 0.35, 4.4), V(px, py + 0.08 + (k % 2) * 0.04, pz), if k % 2 == 0 then vBasalt else rgb(68, 62, 64), Enum.Material.Slate)
				paver.CanCollide = false
			end
		end)

		-- 2. VarrashWaystone caravan trail markers lining central and wing approaches (clear of lanes)
		local waystoneSpots = {
			{ -26, 98, true }, { 26, 98, true },
			{ -26, 72, false }, { 26, 72, false },
			{ -22, 16, false }, { 22, 16, false },
			{ -92, 24, false }, { -66, -124, true },
			{ 92, 14, false }, { 66, -124, true },
		}
		for _, ws in waystoneSpots do
			local wx, wz, lit = ws[1], ws[2], ws[3]
			if not footprintClear(wx, wz, 2.5, 2.5) then
				continue
			end
			local wy = ashenGroundAt(wx, wz)
			table.insert(reservedSpots, { wx, wz, 10 })
			group("VarrashWaystone", function()
				currentParent:SetAttribute("OnTerrain", true)
				if KitProps.Has("VarrashWaystone") then
					local mdl = kitAt("VarrashWaystone", CFrame.new(wx, wy - 0.1, wz), 1.05 * scale, f11Override)
					if lit and mdl then
						local anchor = mdl:FindFirstChildWhichIsA("BasePart")
						if anchor then pointLight(anchor, vAmber, 0.75, 24) end
					end
				else
					block("WaystoneFoot", V(3.8, 1.2, 3.8), V(wx, wy + 0.5, wz), vBasalt, Enum.Material.Basalt)
					block("WaystoneShaft", V(2.7, 2.6, 2.7), V(wx, wy + 2.4, wz), vSand, Enum.Material.Sandstone)
					block("WaystoneBand", V(2.5, 1.4, 2.5), V(wx, wy + 4.4, wz), vTerra, Enum.Material.Slate)
					block("WaystoneCap", V(3.2, 1.0, 3.2), V(wx, wy + 5.6, wz), vSand, Enum.Material.Sandstone)
					block("WaystoneCollar", V(2.6, 0.4, 2.6), V(wx, wy + 6.3, wz), vIron, Enum.Material.Metal)
					for _, csx in { -1, 1 } do
						for _, csz in { -1, 1 } do
							local bar = block("WaystoneCageBar", V(0.24, 2.5, 0.24), V(wx + csx * 0.95, wy + 7.75, wz + csz * 0.95), vIron, Enum.Material.Metal)
							bar.CanCollide = false
						end
					end
					block("WaystoneFinial", V(2.2, 0.55, 2.2), V(wx, wy + 9.28, wz), vIron, Enum.Material.Metal)
					local ember = orb("WaystoneFlame", V(wx, wy + 7.6, wz), V(1.2, 1.9, 1.2), vAmber, Enum.Material.Neon)
					if lit then pointLight(ember, vAmber, 0.85, 26) end
				end
			end)
		end

		-- 2b. Central Dune Crest landmark: Varrash DuneWaystationRuins (Compass medallion, north Wayfinder Brazier
		-- Obelisk & parapet, ruined banded colonnade bays, sun-canopy sails & spilled supply crates).
		-- Every part stays north of LandingB (Z <= -18.5) or outside its X span (|X| >= 21.3) so PropClearance keeps it intact.
		local crestX, crestY, crestZ = crossing.X, crossing.Y, crossing.Z
		group("DuneWaystationRuins", function()
			currentParent:SetAttribute("OnTerrain", true)
			-- Inset Varrash Sun-Compass floor medallion in northern Dune Crest courtyard (Z = -28, R = 7.2 -> north of Z = -17)
			local compZ = crestZ - 8.5
			local compY = crestY + 0.05
			local cOut = cyl("DuneCompassOuter", V(crestX, compY, compZ), 7.2, 0.12, vSand, Enum.Material.Sandstone)
			local cRing = cyl("DuneCompassRing", V(crestX, compY + 0.05, compZ), 4.9, 0.12, vTerra, Enum.Material.Slate)
			local cHub = cyl("DuneCompassHub", V(crestX, compY + 0.10, compZ), 1.9, 0.12, vBasalt, Enum.Material.Basalt)
			local rEW = block("DuneCompassRayEW", V(13.0, 0.10, 1.1), V(crestX, compY + 0.08, compZ), vSand, Enum.Material.Sandstone)
			local rNS = block("DuneCompassRayNS", V(1.1, 0.10, 13.0), V(crestX, compY + 0.12, compZ), vSand, Enum.Material.Sandstone)
			for _, fp in { cOut, cRing, cHub, rEW, rNS } do
				fp.CanCollide = false
			end

			-- North rim Wayfinder Brazier Obelisk & stepped retaining parapet overlooking Sleeping Dune & Cinder Gate
			local northZ = crestZ - 18.5
			block("WayfinderPlinth", V(8.6, 1.8, 6.6), V(crestX, crestY + 0.9, northZ), vBasalt, Enum.Material.Basalt)
			block("WayfinderTier", V(6.8, 1.4, 5.4), V(crestX, crestY + 2.5, northZ), vSand, Enum.Material.Sandstone)
			block("WayfinderObeliskLower", V(3.6, 4.8, 3.6), V(crestX, crestY + 5.6, northZ), vTerra, Enum.Material.Slate)
			block("WayfinderObeliskUpper", V(2.8, 5.2, 2.8), V(crestX, crestY + 10.6, northZ), vSand, Enum.Material.Sandstone)
			block("WayfinderBrazierBowl", V(3.6, 1.2, 3.6), V(crestX, crestY + 13.7, northZ), vIron, Enum.Material.Metal)
			local wfCore = orb("WayfinderBrazierFlame", V(crestX, crestY + 15.1, northZ), V(2.2, 2.5, 2.2), vAmber, Enum.Material.Neon)
			pointLight(wfCore, vAmber, 1.25, 38)
			local dust = Instance.new("ParticleEmitter")
			dust.Name = "DuneCrestSandHaze"
			dust.Color = ColorSequence.new(rgb(235, 198, 138))
			dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 6.0) })
			dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.92), NumberSequenceKeypoint.new(0.4, 0.78), NumberSequenceKeypoint.new(1, 1) })
			dust.Lifetime = NumberRange.new(2.5, 4.2)
			dust.Rate = 4
			dust.Speed = NumberRange.new(4, 9)
			dust.EmissionDirection = Enum.NormalId.Right
			dust.Parent = wfCore
			for _, ps in { -1, 1 } do
				block("WaystationNorthWallBase", V(10.0, 2.4, 2.6), V(crestX + ps * 10.6, crestY + 1.2, northZ), vBasalt, Enum.Material.Basalt)
				block("WaystationNorthWallMid", V(9.8, 1.8, 2.4), V(crestX + ps * 10.6, crestY + 3.3, northZ), vTerra, Enum.Material.Slate)
				block("WaystationNorthWallCap", V(10.2, 0.9, 2.8), V(crestX + ps * 10.6, crestY + 4.65, northZ), vSand, Enum.Material.Sandstone)
			end

			-- Flanking Banded Colonnade Pillars on terrace rim (|X| = 23.0 > 21.0 LandingB HW) & overhead sun-canopy sails (Z <= -19)
			for _, ps in { -1, 1 } do
				for _, pzOff in { -18.5, -2.5, 11.5 } do
					local px = crestX + ps * 23.0
					local pz = crestZ + pzOff
					local tall = not (ps < 0 and pzOff < -10)
					block("WaystationColFoot", V(3.2, 1.4, 3.2), V(px, crestY + 0.7, pz), vBasalt, Enum.Material.Basalt)
					block("WaystationColDrum1", V(2.4, 3.8, 2.4), V(px, crestY + 3.3, pz), vSand, Enum.Material.Sandstone)
					block("WaystationColDrum2", V(2.3, 2.8, 2.3), V(px, crestY + 6.6, pz), vTerra, Enum.Material.Slate)
					if tall then
						block("WaystationColDrum3", V(2.3, 3.6, 2.3), V(px, crestY + 9.8, pz), vSand, Enum.Material.Sandstone)
						block("WaystationColCap", V(3.0, 1.2, 3.0), V(px, crestY + 12.2, pz), vSand, Enum.Material.Sandstone)
					end
				end
			end
			block("WaystationEastLintel", V(2.6, 2.0, 32.0), V(crestX + 23.0, crestY + 13.8, crestZ - 3.5), vSand, Enum.Material.Sandstone)
			local sailE = block("WaystationSunSailEast", V(10.0, 0.35, 17.0), V(crestX + 18.2, crestY + 12.6, crestZ - 10.0), vCanvas, Enum.Material.Fabric)
			sailE.CFrame = CFrame.new(origin + V(crestX + 18.2, crestY + 12.6, crestZ - 10.0)) * CFrame.Angles(0, 0, math.rad(14))
			sailE.CanCollide = false
			local sailW = block("WaystationSunSailWest", V(7.5, 0.35, 12.0), V(crestX - 18.8, crestY + 11.6, crestZ - 9.0), rgb(162, 114, 72), Enum.Material.Fabric)
			sailW.CFrame = CFrame.new(origin + V(crestX - 18.8, crestY + 11.6, crestZ - 9.0)) * CFrame.Angles(math.rad(-8), 0, math.rad(-16))
			sailW.CanCollide = false

			-- Supply crates & terracotta amphorae tucked strictly north of Z = -18.5
			for _, st in { { -16.5, -14.5, 0.25 }, { 16.5, -13.5, -0.35 }, { -18.5, -2.5, 0.4 }, { 18.5, -2.5, -0.2 } } do
				local sx, sz, srot = crestX + st[1], crestZ + st[2], st[3]
				local cr = block("WaystationSupplyCrate", V(2.8, 2.2, 2.6), V(sx, crestY + 1.1, sz), vWood, Enum.Material.Wood)
				cr.CFrame = CFrame.new(origin + V(sx, crestY + 1.1, sz)) * CFrame.Angles(0, srot, 0)
				cyl("WaystationAmphora", V(sx + (if st[1] > 0 then -2.2 else 2.2), crestY + 1.3, sz - 0.8), 1.3, 2.6, vTerra, Enum.Material.Slate)
			end
		end)

		-- 2c. Mid-Basin Shattered Ruin Archway & Tilted Sandstone Monoliths in lane-verified open desert pockets
		for _, cand in { { 52, -14 }, { 56, -24 }, { 48, 4 }, { 68, -28 }, { -52, -20 } } do
			local ax, az = cand[1], cand[2]
			if footprintClear(ax, az, 10, 6) then
				local ay = ashenGroundAt(ax, az)
				table.insert(reservedSpots, { ax, az, 16 })
				group("BrokenMidArch", function()
					currentParent:SetAttribute("OnTerrain", true)
					local acf = CFrame.new(origin + V(ax, ay - 0.6, az)) * CFrame.Angles(0, math.rad(-28), 0)
					for _, ps in { -1, 1 } do
						local hPier = if ps < 0 then 14.5 else 9.5
						local pb = block("MidArchPierBase", V(4.2, 3.2, 4.2), V(ax, ay, az), vBasalt, Enum.Material.Basalt)
						pb.CFrame = acf * CFrame.new(ps * 7.5, 1.6, 0)
						local ps1 = block("MidArchPierMid", V(3.4, hPier, 3.4), V(ax, ay, az), if ps < 0 then vSand else vTerra, Enum.Material.Sandstone)
						ps1.CFrame = acf * CFrame.new(ps * 7.5, 3.2 + hPier * 0.5, 0)
					end
					local lintel = block("MidArchBrokenLintel", V(12.0, 2.4, 3.4), V(ax, ay, az), vTerra, Enum.Material.Slate)
					lintel.CFrame = acf * CFrame.new(-2.8, 19.0, 0) * CFrame.Angles(0, 0, math.rad(-14))
					local fallen = block("MidArchFallenVoussoir", V(6.0, 2.2, 3.2), V(ax, ay, az), vSand, Enum.Material.Sandstone)
					fallen.CFrame = acf * CFrame.new(3.8, 1.1, 3.0) * CFrame.Angles(math.rad(12), math.rad(25), math.rad(18))
				end)
				break
			end
		end

		local placedObs = 0
		for _, ob in {
			{ -52, -16, 14, -10 }, { 56, -78, -12, 16 }, { -4, -92, 10, -14 },
			{ 44, -68, -14, 12 }, { -56, 4, 15, -12 }, { 42, 8, -12, 14 },
		} do
			if placedObs >= 3 then break end
			local ox, oz, tiltX, tiltZ = ob[1], ob[2], ob[3], ob[4]
			if footprintClear(ox, oz, 4.5, 4.5) then
				placedObs += 1
				local oy = ashenGroundAt(ox, oz)
				table.insert(reservedSpots, { ox, oz, 10 })
				group("TiltedSandstoneMonolith", function()
					currentParent:SetAttribute("OnTerrain", true)
					local ocf = CFrame.new(origin + V(ox, oy - 0.8, oz)) * CFrame.Angles(math.rad(tiltX), math.rad(ox), math.rad(tiltZ))
					local b1 = block("ObeliskFooting", V(4.8, 3.0, 4.8), V(ox, oy, oz), vBasalt, Enum.Material.Basalt)
					b1.CFrame = ocf * CFrame.new(0, 1.5, 0)
					local b2 = block("ObeliskShaft", V(3.6, 10.5, 3.6), V(ox, oy, oz), vSand, Enum.Material.Sandstone)
					b2.CFrame = ocf * CFrame.new(0, 8.2, 0)
					local b3 = block("ObeliskBand", V(3.3, 2.4, 3.3), V(ox, oy, oz), vTerra, Enum.Material.Slate)
					b3.CFrame = ocf * CFrame.new(0, 14.2, 0)
				end)
			end
		end

		-- Midground supply crate stashes flanking Ash Flats -> Dune Crest
		for _, cs in { { -30, 26 }, { 30, 26 }, { -32, 54 }, { 32, 54 } } do
			local cx, cz = cs[1], cs[2]
			if footprintClear(cx, cz, 3.5, 3.5) then
				local cy = ashenGroundAt(cx, cz)
				table.insert(reservedSpots, { cx, cz, 7 })
				group("CaravanSupplyStash", function()
					currentParent:SetAttribute("OnTerrain", true)
					local c1 = block("CaravanCrateA", V(3.2, 2.4, 2.8), V(cx, cy + 1.0, cz), vWood, Enum.Material.Wood)
					c1.CFrame = CFrame.new(origin + V(cx, cy + 1.0, cz)) * CFrame.Angles(0, math.rad(cx * 2), 0)
					local c2 = block("CaravanCrateB", V(2.2, 2.0, 2.2), V(cx + 2.0, cy + 0.9, cz - 1.4), vTerra, Enum.Material.Slate)
					c2.CFrame = CFrame.new(origin + V(cx + 2.0, cy + 0.9, cz - 1.4)) * CFrame.Angles(0, math.rad(-25), 0)
				end)
			end
		end

		-- 3. Sleeping Dune Wreck: BuriedVarrash Caravan Wagon pitched into the windward west sand slope
		local wagX, wagZ = -38, -44
		if footprintClear(wagX, wagZ, 10, 10) then
			local wagY = ashenGroundAt(wagX, wagZ)
			table.insert(reservedSpots, { wagX, wagZ, 22 })
			group("BuriedWagon", function()
				currentParent:SetAttribute("OnTerrain", true)
				local wagCf = CFrame.new(origin + V(wagX, wagY + 0.8, wagZ)) * CFrame.Angles(0, math.rad(-38), 0)
				if KitProps.Has("BuriedWagon") then
					kitAt("BuriedWagon", CFrame.new(wagX, wagY - 0.2, wagZ) * CFrame.Angles(0, math.rad(-38), 0), 1.25 * scale, f11Override)
				else
					local tiltCf = wagCf * CFrame.Angles(math.rad(10), 0, math.rad(-15))
					local bed = block("WagonBed", V(8.5, 1.4, 15.5), wagCf.Position, vWood, Enum.Material.Wood)
					bed.CFrame = tiltCf
					for _, side in { -1, 1 } do
						local rail = block("WagonSideRail", V(0.7, 2.6, 15.0), wagCf.Position, vWood, Enum.Material.Wood)
						rail.CFrame = tiltCf * CFrame.new(side * 3.9, 1.8, 0)
						for _, wz in { -4.5, 4.5 } do
							local wh = cyl("WagonWheel", wagCf.Position, 2.6, 0.7, vIron, Enum.Material.Metal)
							wh.CFrame = tiltCf * CFrame.new(side * 4.6, -0.4, wz) * CFrame.Angles(0, math.pi / 2, 0)
						end
					end
					for i = -2, 2 do
						local hoop = block("WagonCanvasHoops", V(8.4, 5.2, 0.65), wagCf.Position, vWood, Enum.Material.Wood)
						hoop.CFrame = tiltCf * CFrame.new(0, 4.2, i * 3.4)
					end
					local top = orb("WagonCanvasRoof", wagCf.Position, V(8.8, 5.8, 15.2), vCanvas, Enum.Material.Fabric)
					top.CFrame = tiltCf * CFrame.new(0, 5.4, 0)
					local spilled = block("WagonSpilledCrate", V(3.0, 2.2, 2.6), wagCf.Position, vWood, Enum.Material.Wood)
					spilled.CFrame = wagCf * CFrame.new(-4.8, -0.4, 8.8) * CFrame.Angles(0.2, 0.5, 0.1)
				end
			end)
		end

		-- 4. West Midground: TollHouseRuins + Nomad Ash Raider TarpCamp (outside WEST_GALLERY camp & lanes)
		local tollX, tollZ = -148, 28
		if footprintClear(tollX, tollZ, 22, 18) then
			local tollY = ashenGroundAt(tollX, tollZ)
			table.insert(reservedSpots, { tollX, tollZ, 30 })
			group("TollHouseRuins", function()
				currentParent:SetAttribute("OnTerrain", true)
				local tollCf = CFrame.new(tollX, tollY - 0.2, tollZ) * CFrame.Angles(0, math.rad(22), 0)
				if KitProps.Has("TollHouseRuins") then
					kitAt("TollHouseRuins", tollCf, 1.15 * scale, f11Override)
				else
					for _, side in { -1, 1 } do
						local wPart = block("TollWall", V(36, 4.5, 3), tollCf.Position + V(0, 2.25, side * 12), vBasalt, Enum.Material.Basalt)
						wPart.CFrame = tollCf * CFrame.new(0, 2.25, side * 12)
						local bPart = block("TollWallBand", V(36, 4.5, 3), tollCf.Position + V(0, 6.75, side * 12), vTerra, Enum.Material.Slate)
						bPart.CFrame = tollCf * CFrame.new(0, 6.75, side * 12)
						local cPart = block("TollWallCrest", V(32, 3.6, 3), tollCf.Position + V(0, 10.8, side * 12), vSand, Enum.Material.Sandstone)
						cPart.CFrame = tollCf * CFrame.new(0, 10.8, side * 12)
					end
				end
			end)
		end

		for tIdx, tc in { { -168, -22, 1.0, 25 }, { -170, 4, 0.85, -18 } } do
			local tx, tz, ts, tyaw = tc[1], tc[2], tc[3], tc[4]
			local ty = ashenGroundAt(tx, tz)
			table.insert(reservedSpots, { tx, tz, 14 })
			group("AshRaiderTarpTent" .. tIdx, function()
				currentParent:SetAttribute("OnTerrain", true)
				local tcf = CFrame.new(tx, ty + 0.2, tz) * CFrame.Angles(0, math.rad(tyaw), 0)
				for _, side in { -1, 1 } do
					local roof = block("TarpPitch", V(9.5 * ts, 0.45, 13.0 * ts), V(tx, ty + 3.5, tz), vCanvas, Enum.Material.Fabric)
					roof.CFrame = tcf * CFrame.new(side * 3.35 * ts, 3.8 * ts + (if side > 0 then 0.08 else 0), 0) * CFrame.Angles(0, 0, math.rad(side * -32))
					local pole = cyl("TentPole", V(tx, ty, tz), 0.35, 6.8 * ts, vWood, Enum.Material.Wood)
					pole.CFrame = tcf * CFrame.new(0, 3.4 * ts, side * 5.8 * ts)
				end
			end)
		end

		-- 5. East Midground: WatchKilnTower overlooking Ash Flats & Watch Kiln terrace
		local kilnX, kilnZ = 160, -24
		if footprintClear(kilnX, kilnZ, 16, 16) then
			local kilnY = ashenGroundAt(kilnX, kilnZ)
			table.insert(reservedSpots, { kilnX, kilnZ, 26 })
			group("WatchKilnTower", function()
				currentParent:SetAttribute("OnTerrain", true)
				local kilnCf = CFrame.new(kilnX, kilnY - 2.6, kilnZ) * CFrame.Angles(0, math.rad(-140), 0)
				if KitProps.Has("WatchKilnTower") then
					local mdl = kitAt("WatchKilnTower", kilnCf, 1.25 * scale, f11Override)
					if mdl then
						local anchor = mdl:FindFirstChildWhichIsA("BasePart")
						if anchor then pointLight(anchor, vAmber, 1.15, 38) end
					end
				else
					cyl("KilnBase", V(kilnX, kilnY + 1.5, kilnZ), 11, 10, vBasalt, Enum.Material.Basalt)
					cyl("KilnDrum", V(kilnX, kilnY + 11.5, kilnZ), 9.5, 12, vSand, Enum.Material.Sandstone)
					cyl("KilnBand", V(kilnX, kilnY + 12.5, kilnZ), 9.9, 2.6, vTerra, Enum.Material.Slate)
					local emberTop = orb("KilnSignalGlow", V(kilnX, kilnY + 25.5, kilnZ), V(3.2, 2.4, 3.2), vAmber, Enum.Material.Neon)
					pointLight(emberTop, vAmber, 1.15, 38)
				end
			end)
		end

		-- 6. Glowing Ember Crystal Clusters & Sun-Bleached Dead Desert Snags
		local crystalSpots = {
			{ -46, 114, 1.0 }, { 42, 116, 0.9 },
			{ -122, 42, 1.15 }, { -128, 12, 0.9 },
			{ -18, 42, 0.85 }, { 24, 38, 0.95 },
			{ 132, -8, 1.05 }, { -88, -62, 1.1 },
		}
		for cIdx, cs in crystalSpots do
			local cx, cz, csc = cs[1], cs[2], cs[3]
			if footprintClear(cx, cz, 5, 5) then
				local cy = ashenGroundAt(cx, cz)
				table.insert(reservedSpots, { cx, cz, 6 })
				group("EmberCrystalPatch", function()
					currentParent:SetAttribute("OnTerrain", true)
					for sh = 1, 3 do
						local ang = (cIdx * 1.7 + sh * 2.1)
						local shH = (3.8 + sh * 1.4) * csc
						local shPos = V(cx + math.cos(ang) * (1.2 * csc), cy + shH * 0.45, cz + math.sin(ang) * (1.2 * csc))
						local shard = block("EmberCrystalShard", V(1.3 * csc, shH, 1.3 * csc), shPos, vCrystal, Enum.Material.Glass, nil, 0.15)
						shard.CFrame = CFrame.new(origin + shPos) * CFrame.Angles(math.rad((sh - 2) * 18), ang, math.rad((sh - 1) * 14))
					end
				end)
			end
		end

		for _, snag in { { 172, 16, 0.95 }, { -168, -66, 0.9 }, { 132, -118, 0.85 } } do
			local sx, sz, ss = snag[1], snag[2], snag[3]
			local sy = ashenGroundAt(sx, sz)
			table.insert(reservedSpots, { sx, sz, 12 })
			group("BleachedDesertSnag", function()
				currentParent:SetAttribute("OnTerrain", true)
				if KitProps.Has("DeadTree") then
					kitAt("DeadTree", CFrame.new(sx, sy - 0.5, sz) * CFrame.Angles(0, math.rad(sx), 0), ss, { WOOD = { Color = vDeadWood, Material = Enum.Material.Wood } })
				else
					beam("DeadSnagTrunk", V(sx, sy, sz), V(sx + 2, sy + 20 * ss, sz - 1), 2.8 * ss, vDeadWood, Enum.Material.Wood)
					beam("DeadSnagLimbA", V(sx + 1.5, sy + 13 * ss, sz - 0.5), V(sx - 6, sy + 23 * ss, sz + 3), 1.4 * ss, vDeadWood, Enum.Material.Wood)
				end
			end)
		end
	elseif layout.Authored == "ashen:2" then
		-- Floor 12, Buried Caravan (ashen:2): foreground Wagon Circle with Ash Raider tarps & campfire,
		-- colossal fossil Sand-StriderRibs straddling EastGallery -> Crossing ramp + SandStriderSkull beside it,
		-- collapsed SpiceVaultRuins pouring saffron & crimson spice piles on the west bluff, cacti & dust devils.
		local vSand = rgb(188, 158, 116)
		local vBone = rgb(214, 200, 174)
		local vBoneDark = rgb(142, 128, 108)
		local vTerra = rgb(175, 95, 65)
		local vBasalt = rgb(44, 38, 40)
		local vIron = rgb(58, 52, 56)
		local vAmber = rgb(255, 162, 62)
		local vWood = rgb(124, 96, 68)
		local vDeadWood = rgb(194, 182, 164)
		local vCanvas = rgb(118, 114, 106)
		local vDriftSand = rgb(154, 136, 108)
		local vCrimson = rgb(178, 38, 34)
		local vSaffron = rgb(232, 176, 36)
		local vCactus = rgb(78, 112, 54)

		local function f12GroundAt(x: number, z: number): number
			for _, t in layout.Platforms do
				if math.abs(x - t.X) <= t.Width / 2 and math.abs(z - t.Z) <= t.Depth / 2 then
					return t.Y
				end
			end
			return if field then math.max(field.Sample(x, z), bottom) else bottom
		end
		local function f12MinGroundAt(x: number, z: number, halfSpan: number): number
			local lo = f12GroundAt(x, z)
			for _, ox in { -halfSpan, 0, halfSpan } do
				for _, oz in { -halfSpan, 0, halfSpan } do
					lo = math.min(lo, f12GroundAt(x + ox, z + oz))
				end
			end
			return lo
		end

		local f12Override = {
			TRIM = { Color = vSand, Material = Enum.Material.Sandstone },
			ALT = { Color = vTerra, Material = Enum.Material.Slate },
			STONE = { Color = vBasalt, Material = Enum.Material.Basalt },
			METAL = { Color = vIron, Material = Enum.Material.Metal },
			GLOW = { Color = vAmber, Material = Enum.Material.Neon },
			WOOD = { Color = vWood, Material = Enum.Material.Wood },
			FOLIAGE = { Color = vCanvas, Material = Enum.Material.Fabric },
			MOSS = { Color = vDriftSand, Material = Enum.Material.Sand },
			GOLD = { Color = vSaffron, Material = Enum.Material.Sand },
			CORAL = { Color = vCrimson, Material = Enum.Material.Sand },
		}

		-- 1. Colossal Sand-Strider Fossil Ribcage straddling EastGallery -> Crossing ramp (tagged RampArch so WalkwayHitTest exempts it)
		-- Scaled 1.68x and seated deep (ribMid.Y - 13.5) so both banks bury solidly into the sand below while the spine clears the ramp cleanly overhead.
		local ribMid, ribYaw = spineMid("EastGallery", "Crossing")
		table.insert(reservedSpots, { ribMid.X, ribMid.Z, 38 })
		group("RampArch", function()
			currentParent:SetAttribute("OnTerrain", true)
			local ribCf = CFrame.new(ribMid.X, ribMid.Y - 13.5, ribMid.Z) * CFrame.Angles(0, ribYaw, 0)
			if KitProps.Has("SandStriderRibs") then
				kitAt("SandStriderRibs", ribCf, 1.68 * scale, {
					TRIM = { Color = vBone, Material = Enum.Material.Limestone },
					STONE = { Color = vBoneDark, Material = Enum.Material.Slate },
					MOSS = { Color = vDriftSand, Material = Enum.Material.Sand },
				})
			else
				for r = -3, 3 do
					local offZ = r * 9.0
					local arcH = 44 - math.abs(r) * 1.4
					local segCf = ribCf * CFrame.new(0, 0, offZ)
					for _, ps in { -1, 1 } do
						local foot = segCf * CFrame.new(ps * 26.0, -1, 0)
						local crown = segCf * CFrame.new(ps * 2.8, arcH, 0)
						beam("StriderRibArch", foot.Position, crown.Position, 3.2, vBone, Enum.Material.Limestone)
					end
				end
			end
		end)

		-- Colossal Sand-Strider Skull partially buried in the eastern dune flank beside Strider's Ribs
		for _, sk in { { 142, -58, -142 }, { 108, -56, -138 }, { 48, 36, -38 }, { 184, 38, -148 } } do
			local skX, skZ, skYaw = sk[1], sk[2], sk[3]
			if footprintClear(skX, skZ, 14, 14) then
				local skY = f12MinGroundAt(skX, skZ, 16)
				table.insert(reservedSpots, { skX, skZ, 30 })
				group("SandStriderSkull", function()
					currentParent:SetAttribute("OnTerrain", true)
					local skCf = CFrame.new(skX, skY - 1.8, skZ) * CFrame.Angles(math.rad(5), math.rad(skYaw), math.rad(-4))
					if KitProps.Has("SandStriderSkull") then
						kitAt("SandStriderSkull", skCf, 1.85 * scale, {
							TRIM = { Color = vBone, Material = Enum.Material.Limestone },
							STONE = { Color = vBasalt, Material = Enum.Material.Basalt },
							MOSS = { Color = vDriftSand, Material = Enum.Material.Sand },
						})
					else
						orb("StriderCranium", skCf.Position + V(0, 9, 0), V(26, 18, 36), vBone, Enum.Material.Limestone)
						orb("StriderSnout", skCf.Position + V(-9, 6, 13), V(14, 10, 22), vBone, Enum.Material.Limestone)
					end
				end)
				break
			end
		end

		-- 2. Wagon Circle defensive ring of Varrash wagons, awnings, campfire & spilled barrels (Basin)
		local wagonSpots = {
			{ -52, 138, 24 }, { 52, 136, -26 },
			{ -58, 84, 142 }, { -156, 84, 88 },
		}
		for _, ws in wagonSpots do
			local wx, wz, wyaw = ws[1], ws[2], ws[3]
			if footprintClear(wx, wz, 9, 9) then
				local wy = f12MinGroundAt(wx, wz, 10)
				table.insert(reservedSpots, { wx, wz, 16 })
				group("DesertCaravanWagon", function()
					currentParent:SetAttribute("OnTerrain", true)
					local wcf = CFrame.new(wx, wy - 0.6, wz) * CFrame.Angles(0, math.rad(wyaw), 0)
					if KitProps.Has("DesertCaravanWagon") then
						kitAt("DesertCaravanWagon", wcf, 1.12 * scale, f12Override)
					else
						local bed = block("CaravanWagonBed", V(7.5, 2.2, 14.0), V(wx, wy + 2.4, wz), vWood, Enum.Material.Wood)
						bed.CFrame = CFrame.new(origin + V(wx, wy + 2.4, wz)) * CFrame.Angles(0, math.rad(wyaw), 0)
						local awning = block("CaravanWagonTarp", V(8.0, 0.4, 13.0), V(wx, wy + 6.4, wz), vCanvas, Enum.Material.Fabric)
						awning.CFrame = CFrame.new(origin + V(wx, wy + 6.4, wz)) * CFrame.Angles(0, math.rad(wyaw), math.rad(-14))
					end
				end)
			end
		end

		-- Nomad Campfire pit + Ash Raider tarp tent inside west-center Wagon Circle (outside BasinCauseway & BASIN_WEST camp)
		local cfX, cfZ = -52, 112
		if footprintClear(cfX, cfZ, 8, 8) then
			local cfY = f12MinGroundAt(cfX, cfZ, 3)
			table.insert(reservedSpots, { cfX, cfZ, 12 })
			group("WagonCircleCampfire", function()
				currentParent:SetAttribute("OnTerrain", true)
				for k = 1, 7 do
					local a = k * (math.pi * 2 / 7)
					block("CampfireStone", V(1.6, 1.1, 1.4), V(cfX + math.cos(a) * 3.2, cfY + 0.45, cfZ + math.sin(a) * 3.2), vBasalt, Enum.Material.Basalt)
				end
				local fireGlow = orb("CampfireEmbers", V(cfX, cfY + 0.85, cfZ), V(2.8, 1.4, 2.8), vAmber, Enum.Material.Neon)
				pointLight(fireGlow, vAmber, 1.3, 36)
				local smoke = Instance.new("ParticleEmitter")
				smoke.Name = "CampfireSmoke"
				smoke.Color = ColorSequence.new(rgb(215, 168, 118))
				smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 5.2) })
				smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.72), NumberSequenceKeypoint.new(1, 1) })
				smoke.Lifetime = NumberRange.new(2.0, 3.6)
				smoke.Rate = 5
				smoke.Speed = NumberRange.new(3, 6)
				smoke.Parent = fireGlow
			end)
		end

		-- 3. Collapsed Spice Vault & Burst Crimson/Saffron Spice Urns on the western cliff overlook (WestGallery)
		local svX, svZ = -164, -120
		if footprintClear(svX, svZ, 16, 12) then
			local svY = f12MinGroundAt(svX, svZ, 12)
			table.insert(reservedSpots, { svX, svZ, 26 })
			group("SpiceVaultRuins", function()
				currentParent:SetAttribute("OnTerrain", true)
				local svCf = CFrame.new(svX, svY - 0.6, svZ) * CFrame.Angles(0, math.rad(36), 0)
				-- Battered stone foundation plinth extending below sand/bedrock so sloped cliff edges never hover
				local plinthH = math.max(4, (svY - bottom) + 3)
				local plinth = block("SpiceVaultFoundation", V(38, plinthH, 26), V(svX, svY - plinthH * 0.5, svZ), vBasalt, Enum.Material.Basalt)
				plinth.CFrame = CFrame.new(origin + V(svX, svY - plinthH * 0.5, svZ)) * CFrame.Angles(0, math.rad(36), 0)
				if KitProps.Has("SpiceVaultRuins") then
					kitAt("SpiceVaultRuins", svCf, 1.18 * scale, f12Override)
				else
					block("SpiceVaultWall", V(30, 13, 3.5), svCf.Position + V(0, 6.5, 0), vSand, Enum.Material.Sandstone)
					orb("SpiceSpillCrimson", svCf.Position + V(-4, 0.6, 8), V(9, 1.8, 9), vCrimson, Enum.Material.Sand)
					orb("SpiceSpillSaffron", svCf.Position + V(6, 0.6, 9), V(8, 1.6, 8), vSaffron, Enum.Material.Sand)
				end
			end)
		end

		-- Additional foreground spice spill clusters flanking WestGallery approach
		for spIdx, sp in { { -146, -34, true }, { -168, -42, false } } do
			local sx, sz, isRed = sp[1], sp[2], sp[3]
			if footprintClear(sx, sz, 6, 6) then
				local sy = f12MinGroundAt(sx, sz, 5)
				table.insert(reservedSpots, { sx, sz, 10 })
				group("BurstSpiceUrn" .. spIdx, function()
					currentParent:SetAttribute("OnTerrain", true)
					local urn = orb("ToppledSpiceAmphora", V(sx, sy + 1.2, sz), V(4.2, 4.2, 6.2), vTerra, Enum.Material.Slate)
					urn.CFrame = CFrame.new(origin + V(sx, sy + 1.2, sz)) * CFrame.Angles(math.rad(72), math.rad(sx), 0)
					orb("SpicePowderPile", V(sx + 2.8, sy + 0.1, sz + 3.2), V(8.5, 2.4, 7.5), if isRed then vCrimson else vSaffron, Enum.Material.Sand)
				end)
			end
		end

		-- 4. Swirling Desert Dust Devils + Green Saguaro Desert Cacti & Pale Dead Snags
		for dIdx, dd in { { -88, -16, 1.0 }, { 172, -116, 1.15 } } do
			local dx, dz, ds = dd[1], dd[2], dd[3]
			local dy = f12MinGroundAt(dx, dz, 6)
			table.insert(reservedSpots, { dx, dz, 14 })
			group("SandstormDustDevil" .. dIdx, function()
				currentParent:SetAttribute("OnTerrain", true)
				local funnel = cyl("DustDevilFunnel", V(dx, dy + 24 * ds - 2, dz), 5.5 * ds, 54 * ds, rgb(224, 188, 138), Enum.Material.SmoothPlastic, 0.88)
				local emitter = Instance.new("ParticleEmitter")
				emitter.Name = "GlasswindSandSwirl"
				emitter.Color = ColorSequence.new(rgb(232, 194, 142))
				emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6 * ds), NumberSequenceKeypoint.new(1, 16 * ds) })
				emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.90), NumberSequenceKeypoint.new(0.45, 0.72), NumberSequenceKeypoint.new(1, 1) })
				emitter.Lifetime = NumberRange.new(2.2, 3.8)
				emitter.Rate = 6
				emitter.Speed = NumberRange.new(8, 16)
				emitter.RotSpeed = NumberRange.new(-90, 90)
				emitter.Parent = funnel
			end)
		end

		for _, cac in { { 146, 152, 1.0 }, { 166, 114, 1.15 }, { -162, 142, 0.9 } } do
			local cx, cz, cs = cac[1], cac[2], cac[3]
			if footprintClear(cx, cz, 4, 4) then
				local cy = f12MinGroundAt(cx, cz, 3)
				table.insert(reservedSpots, { cx, cz, 7 })
				group("SaguaroCactusCluster", function()
					currentParent:SetAttribute("OnTerrain", true)
					cyl("CactusTrunk", V(cx, cy + 4.0 * cs, cz), 1.05 * cs, 10.5 * cs, vCactus, Enum.Material.Grass)
					for _, ps in { -1, 1 } do
						local hOff = if ps < 0 then 3.0 * cs else 4.6 * cs
						local arm = block("CactusArmH", V(3.0 * cs, 1.3 * cs, 1.3 * cs), V(cx + ps * 1.8 * cs, cy + hOff, cz), vCactus, Enum.Material.Grass)
						arm.CanCollide = false
						cyl("CactusArmV", V(cx + ps * 3.1 * cs, cy + hOff + 2.0 * cs, cz), 0.72 * cs, 4.2 * cs, vCactus, Enum.Material.Grass)
					end
				end)
			end
		end

		for _, snag in { { -162, 22, 0.95 }, { 174, -46, 0.9 }, { -122, -162, 0.85 } } do
			local sx, sz, ss = snag[1], snag[2], snag[3]
			local sy = f12MinGroundAt(sx, sz, 6)
			table.insert(reservedSpots, { sx, sz, 12 })
			group("BleachedDesertSnag", function()
				currentParent:SetAttribute("OnTerrain", true)
				if KitProps.Has("DeadTree") then
					kitAt("DeadTree", CFrame.new(sx, sy - 0.8, sz) * CFrame.Angles(0, math.rad(sx), 0), ss, { WOOD = { Color = vDeadWood, Material = Enum.Material.Wood } })
				else
					beam("DeadSnagTrunk", V(sx, sy - 0.5, sz), V(sx + 2, sy + 20 * ss, sz - 1), 2.8 * ss, vDeadWood, Enum.Material.Wood)
				end
			end)
		end
	elseif layout.Authored == "ashen:3" then
		-- Floor 13, Glasswind Ravine (ashen:3): colossal fused obsidian & amber GlassArchSpan over the chasm,
		-- crystalline FulguriteClusters on the east cliff rim and ravine bottom, distant RavineHorizonSpire,
		-- west-cliff Sandfall cascade, dark glass overhangs, Ash Raider east camp ruins & orange-blooming cacti.
		local obsidian = rgb(24, 20, 26)
		local obsidianRock = rgb(36, 30, 36)
		local vAmber = rgb(248, 148, 44)
		local vCrystalWhite = rgb(232, 224, 212)
		local vSand = rgb(186, 154, 114)
		local vTerra = rgb(168, 92, 62)
		local vWood = rgb(118, 90, 62)
		local vCanvas = rgb(116, 112, 104)
		local vCactus = rgb(72, 108, 52)
		local vBloom = rgb(244, 128, 36)
		local vDrift = rgb(154, 136, 108)

		local function f13GroundAt(x: number, z: number): number
			for _, t in layout.Platforms do
				if t.Id ~= "Crossing" and math.abs(x - t.X) <= t.Width / 2 and math.abs(z - t.Z) <= t.Depth / 2 then
					return t.Y
				end
			end
			return if field then math.max(field.Sample(x, z), bottom) else bottom
		end
		local function f13MinGroundAt(x: number, z: number, halfSpan: number): number
			local lo = f13GroundAt(x, z)
			for _, ox in { -halfSpan, 0, halfSpan } do
				for _, oz in { -halfSpan, 0, halfSpan } do
					lo = math.min(lo, f13GroundAt(x + ox, z + oz))
				end
			end
			return lo
		end

		-- 1. Colossal Vitrified Obsidian & Amber-Glass Arch spanning diagonally across the ravine above Crossing
		local cross = layout.Platforms.Crossing
		table.insert(reservedSpots, { cross.X, cross.Z, 48 })
		group("GlassArchSpan", function()
			currentParent:SetAttribute("OnTerrain", true)
			local archYaw = math.rad(48)
			local archBaseY = bottom - 2.0
			local archCf = CFrame.new(cross.X, archBaseY, cross.Z) * CFrame.Angles(0, archYaw, 0)
			-- Solid basalt foundation piers under both diagonal arch legs down to chasm bedrock
			for legIdx, side in { -1, 1 } do
				local legPos = archCf * CFrame.new(side * 56 * scale, 4, 0)
				local foot = block("GlassArchFooting", V(22, 12, 22), legPos.Position, obsidianRock, Enum.Material.Basalt)
				if legIdx == 1 and currentParent:IsA("Model") then
					currentParent.PrimaryPart = foot
				end
			end
			if KitProps.Has("GlassArchSpan") then
				kitAt("GlassArchSpan", archCf, 1.42 * scale, {
					STONE = { Color = obsidianRock, Material = Enum.Material.Basalt },
					CRYSTAL = { Color = vAmber, Material = Enum.Material.Glass },
					GLOW = { Color = rgb(208, 118, 34), Material = Enum.Material.Neon },
				})
			else
				for _, side in { -1, 1 } do
					local foot = archCf * CFrame.new(side * 58 * scale, 0, 0)
					local hip = archCf * CFrame.new(side * 42 * scale, 46 * scale, 0)
					local peak = archCf * CFrame.new(0, 74 * scale, 0)
					beam("GlassArchLimb", foot.Position, hip.Position, 12 * scale, obsidianRock, Enum.Material.Basalt)
					beam("GlassArchCrown", hip.Position, peak.Position, 11 * scale, obsidianRock, Enum.Material.Basalt)
					beam("GlassArchCore", foot.Position:Lerp(hip.Position, 0.35), peak.Position - V(0, 5 * scale, 0), 5.2 * scale, vAmber, Enum.Material.Glass, 0.22)
				end
			end
		end)

		-- 2. Fulgurite Crystal Clusters: bold organ-pipe crystal clusters along East Ledge lip & Ravine floor
		local fulgSpots = {
			{ 96, -18, 1.65, 22 },
			{ 82, -104, 1.70, -35 },
			{ 96, -94, 1.55, 58 },
			{ -14, 34, 1.80, 15 },
			{ 20, -14, 1.60, -48 },
			{ -40, -124, 1.65, 72 },
			{ 40, -124, 1.60, -62 },
		}
		for _, fc in fulgSpots do
			local fx, fz, fs, fyaw = fc[1], fc[2], fc[3], fc[4]
			if footprintClear(fx, fz, 7, 7) then
				local fy = f13MinGroundAt(fx, fz, 6)
				table.insert(reservedSpots, { fx, fz, 12 })
				group("FulguriteCluster", function()
					currentParent:SetAttribute("OnTerrain", true)
					local fcf = CFrame.new(fx, fy - 0.6, fz) * CFrame.Angles(0, math.rad(fyaw), 0)
					if KitProps.Has("FulguriteCluster") then
						kitAt("FulguriteCluster", fcf, fs * scale, {
							CRYSTAL = { Color = vCrystalWhite, Material = Enum.Material.Glass },
							STONE = { Color = obsidianRock, Material = Enum.Material.Basalt },
							GLOW = { Color = vAmber, Material = Enum.Material.Neon },
						})
					else
						block("FulguriteBase", V(11 * fs, 2.2, 11 * fs), fcf.Position + V(0, 0.5, 0), obsidianRock, Enum.Material.Basalt)
						for sp = 1, 5 do
							local ang = sp * 1.25
							local rad = (sp % 2 == 0) and 2.8 * fs or 1.4 * fs
							local spH = (7 + (sp * 2.3) % 7) * fs
							cyl("FulguritePipe", fcf.Position + V(math.cos(ang) * rad, spH * 0.5, math.sin(ang) * rad), 0.9 * fs, spH, vCrystalWhite, Enum.Material.Glass, 0.2)
						end
					end
				end)
			end
		end

		-- Ravine bottom glittering obsidian/amber fulgurite shard beds & subtle canyon mist
		for rIdx, sh in { { -6, 14 }, { 14, -42 }, { -16, -64 }, { 8, -104 }, { -4, 48 } } do
			local rx, rz = sh[1], sh[2]
			local ry = f13MinGroundAt(rx, rz, 4)
			group("RavineFloorShards", function()
				currentParent:SetAttribute("OnTerrain", true)
				for sIdx = 1, 4 do
					local ang = rIdx * 1.3 + sIdx * 1.55
					local sp = V(rx + math.cos(ang) * (3 + sIdx * 1.4), ry - 0.2 + 1.1, rz + math.sin(ang) * (3 + sIdx * 1.4))
					local shard = block("FulguriteRavineShard", V(0.9, 2.8, 1.4), sp, if sIdx % 2 == 0 then vCrystalWhite else vAmber, Enum.Material.Glass, nil, 0.2)
					shard.CFrame = CFrame.new(origin + sp) * CFrame.Angles(math.rad(28), ang, math.rad(18))
				end
				if rIdx <= 3 then
					local mistHost = block("RavineMistEmitter", V(12, 2, 12), V(rx, ry + 1.5, rz), obsidian, Enum.Material.SmoothPlastic, nil, 1)
					mistHost.CanCollide = false
					mistHost.CanQuery = false
					local mist = Instance.new("ParticleEmitter")
					mist.Name = "RavineGlasswindMist"
					mist.Color = ColorSequence.new(rgb(208, 188, 174))
					mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 8), NumberSequenceKeypoint.new(1, 22) })
					mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.92), NumberSequenceKeypoint.new(0.45, 0.78), NumberSequenceKeypoint.new(1, 1) })
					mist.Lifetime = NumberRange.new(3.0, 5.0)
					mist.Rate = 3
					mist.Speed = NumberRange.new(2, 5)
					mist.Parent = mistHost
				end
			end)
		end

		-- 3. Prominent NE Dusk Horizon Beacon Tower (RavineHorizonSpire) rising cleanly atop East Ledge ridge
		local spX, spZ = 174, -150
		local spY = math.max(f13GroundAt(spX, spZ), 12)
		table.insert(reservedSpots, { spX, spZ, 18 })
		group("RavineHorizonSpire", function()
			currentParent:SetAttribute("OnTerrain", true)
			local spCf = CFrame.new(spX, spY - 1.5, spZ) * CFrame.Angles(0, math.rad(-25), 0)
			local plinthH = math.max(12, (spY - bottom) + 6)
			block("HorizonSpireFooting", V(30, plinthH, 30), V(spX, spY - plinthH * 0.5, spZ), obsidianRock, Enum.Material.Basalt)
			if KitProps.Has("RavineHorizonSpire") then
				kitAt("RavineHorizonSpire", spCf, 1.55 * scale, {
					TRIM = { Color = vSand, Material = Enum.Material.Sandstone },
					ALT = { Color = vTerra, Material = Enum.Material.Slate },
					STONE = { Color = obsidianRock, Material = Enum.Material.Basalt },
					GLOW = { Color = vAmber, Material = Enum.Material.Neon },
				})
			else
				cyl("SpireShaft", V(spX, spY + 26 * scale, spZ), 7 * scale, 56 * scale, vSand, Enum.Material.Sandstone)
				cyl("SpireCap", V(spX, spY + 58 * scale, spZ), 4.5 * scale, 12 * scale, vTerra, Enum.Material.Slate)
			end
		end)

		-- 4. One Sandfall Cascade pouring down the visible NW canyon cliff wall toward the ravine
		local sfX, sfZ = -168, -112
		local sfBotY = f13MinGroundAt(sfX + 24, sfZ + 12, 5)
		group("RavineSandfall", function()
			currentParent:SetAttribute("OnTerrain", true)
			local sfTop = V(sfX, 56, sfZ)
			local sfBot = V(sfX + 28, sfBotY - 1.0, sfZ + 14)
			beam("SandfallCascadeStream", sfTop, sfBot, 12.0, vSand, Enum.Material.SmoothPlastic, 0.22)
			beam("SandfallMistCore", sfTop + V(1, 0, 1), sfBot + V(1, 1, 1), 7.0, rgb(228, 194, 148), Enum.Material.SmoothPlastic, 0.38)
			local footCone = orb("SandfallPlungeMound", sfBot, V(26, 7.5, 22), vDrift, Enum.Material.Sand)
			local sfEmit = Instance.new("ParticleEmitter")
			sfEmit.Name = "SandfallDustPlume"
			sfEmit.Color = ColorSequence.new(rgb(220, 184, 134))
			sfEmit.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 16) })
			sfEmit.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.78), NumberSequenceKeypoint.new(1, 1) })
			sfEmit.Lifetime = NumberRange.new(1.6, 2.8)
			sfEmit.Rate = 5
			sfEmit.Speed = NumberRange.new(4, 9)
			sfEmit.Parent = footCone
		end)

		-- 5. Cliff-buttress Obsidian & Amber-Glass Arch Overhangs rising from bedrock beside West Ledge
		for ohIdx, ohZ in { -68, -28, 12 } do
			group("WestLedgeGlassOverhang", function()
				currentParent:SetAttribute("OnTerrain", true)
				local shelfY = 38 + (ohIdx % 2) * 3
				local buttressH = shelfY - bottom + 2
				block("ObsidianCliffButtress", V(30, buttressH, 24), V(-208, bottom + buttressH * 0.5 - 1, ohZ), obsidianRock, Enum.Material.Basalt)
				local rockEave = block("ObsidianOverhangSlab", V(36, 7, 22), V(-192, shelfY, ohZ), obsidianRock, Enum.Material.Basalt)
				rockEave.CFrame = CFrame.new(origin + V(-192, shelfY, ohZ)) * CFrame.Angles(0, math.rad((ohIdx - 2) * 6), math.rad(-10))
				local glassVein = block("ObsidianOverhangGlass", V(30, 2.4, 18), V(-190, shelfY - 3.6, ohZ), vAmber, Enum.Material.Glass, nil, 0.25)
				glassVein.CFrame = rockEave.CFrame * CFrame.new(2, -3.8, 0)
			end)
		end

		-- 6. Elevated East-Bank Ash Raider Camp Shelf (Tarp Tents, Broken Ruin & Campfire at Y+5) + Foreground Cacti
		for tIdx, tc in { { 188, -22, 1.05, -24 }, { 188, -88, 0.95, 18 } } do
			local tx, tz, ts, tyaw = tc[1], tc[2], tc[3], tc[4]
			if footprintClear(tx, tz, 9, 9) then
				local benchY = 5.0
				table.insert(reservedSpots, { tx, tz, 15 })
				group("AshRaiderTarpTent" .. tIdx, function()
					currentParent:SetAttribute("OnTerrain", true)
					local shelfH = benchY - bottom + 2
					block("EastCampCliffShelf", V(30, shelfH, 30), V(tx, benchY - shelfH * 0.5, tz), obsidianRock, Enum.Material.Basalt)
					local tcf = CFrame.new(origin + V(tx, benchY - 0.1, tz)) * CFrame.Angles(0, math.rad(tyaw), 0)
					for _, side in { -1, 1 } do
						local roof = block("TarpPitch", V(9.5 * ts, 0.45, 13.0 * ts), V(tx, benchY + 3.5, tz), vCanvas, Enum.Material.Fabric)
						roof.CFrame = tcf * CFrame.new(side * 3.35 * ts, 3.8 * ts + (if side > 0 then 0.08 else 0), 0) * CFrame.Angles(0, 0, math.rad(side * -32))
						local pole = cyl("TentPole", V(tx, benchY, tz), 0.35, 7.2 * ts, vWood, Enum.Material.Wood)
						pole.CFrame = tcf * CFrame.new(0, 3.3 * ts, side * 5.8 * ts)
					end
					if tIdx == 1 then
						local ember = orb("RavineCampfireEmber", V(tx - 8, benchY + 0.6, tz + 6), V(2.4, 1.2, 2.4), vAmber, Enum.Material.Neon)
						pointLight(ember, vAmber, 1.1, 32)
					end
				end)
			end
		end

		for _, cc in { { -82, 68, 1.55 }, { 82, 68, 1.55 }, { -126, 48, 1.50 }, { 132, 48, 1.50 } } do
			local cx, cz, cs = cc[1], cc[2], cc[3]
			if footprintClear(cx, cz, 6, 6) then
				local cy = f13MinGroundAt(cx, cz, 5)
				table.insert(reservedSpots, { cx, cz, 9 })
				group("GlassCactusCluster", function()
					currentParent:SetAttribute("OnTerrain", true)
					local ccf = CFrame.new(cx, cy - 0.2, cz) * CFrame.Angles(0, math.rad(cx * 3), 0)
					if KitProps.Has("GlassCactusCluster") then
						kitAt("GlassCactusCluster", ccf, cs * scale, {
							FOLIAGE = { Color = vCactus, Material = Enum.Material.Grass },
							ALT = { Color = vBloom, Material = Enum.Material.SmoothPlastic },
							STONE = { Color = obsidianRock, Material = Enum.Material.Basalt },
							MOSS = { Color = vDrift, Material = Enum.Material.Sand },
						})
					else
						cyl("CactusColumn", V(cx, cy + 3.2 * cs, cz), 1.3 * cs, 7.2 * cs, vCactus, Enum.Material.Grass)
						orb("CactusBloom", V(cx, cy + 7.0 * cs, cz), V(1.6 * cs, 1.1 * cs, 1.6 * cs), vBloom, Enum.Material.SmoothPlastic)
					end
				end)
			end
		end
	elseif layout.Authored == "ashen:4" then
		-- Floor 14, Sunscar Fortress (ashen:4): night kiln stronghold split down the middle by the Sunscar
		-- lava fissure, entered solely through PortcullisGate at Kiln Gate, flanked by West KilnTower,
		-- East SignalLensTower, Ashmarket bazaar stalls, dry fountain, and broken amber-glass shards.
		local fBasalt = rgb(44, 38, 42)
		local fSand = rgb(182, 152, 112)
		local fTerra = rgb(166, 92, 62)
		local fIron = rgb(62, 54, 58)
		local fAmber = rgb(252, 146, 44)
		local fMagma = rgb(255, 108, 28)
		local fAshCloth = rgb(108, 102, 96)
		local fWood = rgb(86, 64, 48)
		local fShard = rgb(244, 152, 52)

		local function f14GroundAt(x: number, z: number): number
			for _, t in layout.Platforms do
				if (not layout.Suspended or not layout.Suspended.Platforms[t.Id]) and math.abs(x - t.X) <= t.Width / 2 and math.abs(z - t.Z) <= t.Depth / 2 then
					return t.Y
				end
			end
			return if field then math.max(field.Sample(x, z), bottom) else bottom
		end
		local function f14MinGroundAt(x: number, z: number, halfSpan: number): number
			local lo = f14GroundAt(x, z)
			for _, ox in { -halfSpan, 0, halfSpan } do
				for _, oz in { -halfSpan, 0, halfSpan } do
					lo = math.min(lo, f14GroundAt(x + ox, z + oz))
				end
			end
			return lo
		end

		local f14Override = {
			STONE = { Color = fBasalt, Material = Enum.Material.Basalt },
			TRIM = { Color = fSand, Material = Enum.Material.Sandstone },
			ALT = { Color = fTerra, Material = Enum.Material.Slate },
			METAL = { Color = fIron, Material = Enum.Material.Metal },
			GLOW = { Color = fAmber, Material = Enum.Material.Neon },
			CRYSTAL = { Color = fShard, Material = Enum.Material.Glass },
			WOOD = { Color = fWood, Material = Enum.Material.Wood },
			FOLIAGE = { Color = fAshCloth, Material = Enum.Material.Fabric },
		}

		-- 1. The Sunscar: glowing Neon lava fissure seams along the X = 0 CrackedLava trench (Neon/Bloom, 0 extra lights)
		local lavaTopY = (field and field.LiquidLevel or -4.8) + 0.14
		group("SunscarLavaSeam", function()
			currentParent:SetAttribute("OnTerrain", true)
			local segs = 12
			local prevPt = V(0, lavaTopY, -210)
			for k = 1, segs do
				local t = k / segs
				local nz = -210 + t * 268 -- -210 (Throne) to +58 (Kiln Gate moat)
				local nx = math.sin(nz * 0.045) * 4.5
				local nextPt = V(nx, lavaTopY, nz)
				local seam = beam("SunscarMagmaVein", prevPt, nextPt, 2.8, fMagma, Enum.Material.Neon)
				if k % 4 == 2 then
					local em = Instance.new("ParticleEmitter")
					em.Name = "SunscarRisingEmbers"
					em.Color = ColorSequence.new(rgb(255, 152, 48), rgb(255, 72, 24))
					em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0.1) })
					em.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
					em.Lifetime = NumberRange.new(1.8, 3.2)
					em.Rate = 5
					em.Speed = NumberRange.new(6, 12)
					em.Parent = seam
				end
				prevPt = nextPt
			end
		end)

		-- 2. Kiln Gate Portcullis Barbican spanning Crossing's southern approach (Walkway & Camp exempt)
		local cross = layout.Platforms.Crossing
		table.insert(reservedSpots, { cross.X, cross.Z + 12, 32 })
		group("PortcullisGate", function()
			currentParent:SetAttribute("OnTerrain", true)
			local gateCf = CFrame.new(cross.X, cross.Y - 0.5, cross.Z + 16)
			local gs = 1.05 * scale
			for _, side in { -1, 1 } do
				local pierH = (cross.Y - bottom) + 3.0
				block("PortcullisGatePierBase", V(18, pierH, 22), V(cross.X + side * 28.5 * gs, cross.Y - pierH * 0.5, cross.Z + 16), fBasalt, Enum.Material.Basalt)
				-- Stepped barbican wing walls connecting the gate piers cleanly into the front curtain walls
				local wingX = cross.X + side * 53
				local wingZ = cross.Z + 22
				block("BarbicanWingBase", V(28, pierH + 2, 10), V(wingX, cross.Y - pierH * 0.5 + 1.0, wingZ), fBasalt, Enum.Material.Basalt)
				block("BarbicanWingWall", V(28, 22, 8.5), V(wingX, cross.Y + 11.5, wingZ), fSand, Enum.Material.Sandstone)
				block("BarbicanWingParapet", V(29, 2.4, 9.5), V(wingX, cross.Y + 23.0, wingZ), fTerra, Enum.Material.Slate)
			end
			if KitProps.Has("PortcullisGate") then
				kitAt("PortcullisGate", gateCf, gs, f14Override)
			else
				for _, side in { -1, 1 } do
					block("BarbicanTower", V(14 * gs, 40 * gs, 18 * gs), gateCf.Position + V(side * 28 * gs, 20 * gs, 0), fSand, Enum.Material.Sandstone)
				end
				block("BarbicanLintel", V(44 * gs, 10 * gs, 14 * gs), gateCf.Position + V(0, 32 * gs, 0), fSand, Enum.Material.Sandstone)
			end
		end)

		-- 3. Bottle-shaped West Kiln Tower behind WestBastion & Amber Signal Lens Tower behind EastBastion
		local wk = layout.Platforms.WestBastion
		local wkX, wkZ = wk.X - 14, wk.Z - wk.Depth / 2 - 16
		table.insert(reservedSpots, { wkX, wkZ, 24 })
		group("KilnTower", function()
			currentParent:SetAttribute("OnTerrain", true)
			local pierH = (wk.Y - bottom) + 4
			block("KilnFoundationPier", V(36, pierH, 36), V(wkX, wk.Y - pierH * 0.5, wkZ), fBasalt, Enum.Material.Basalt)
			local kcf = CFrame.new(wkX, wk.Y - 0.6, wkZ) * CFrame.Angles(0, math.rad(16), 0)
			if KitProps.Has("KilnTower") then
				local mdl = kitAt("KilnTower", kcf, 1.32 * scale, f14Override)
				if mdl then
					local glowPart = mdl:FindFirstChild("GLOW") or mdl:FindFirstChildWhichIsA("BasePart")
					if glowPart then
						pointLight(glowPart, fAmber, 1.6, 54)
						local smoke = Instance.new("ParticleEmitter")
						smoke.Name = "KilnCrownEmbers"
						smoke.Color = ColorSequence.new(rgb(255, 142, 46), rgb(82, 68, 64))
						smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 14) })
						smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
						smoke.Lifetime = NumberRange.new(2.2, 3.8)
						smoke.Rate = 4
						smoke.Speed = NumberRange.new(6, 12)
						smoke.Parent = glowPart
					end
				end
			else
				cyl("BottleKilnBase", V(wkX, wk.Y + 12 * scale, wkZ), 14 * scale, 26 * scale, fBasalt, Enum.Material.Basalt)
				cyl("BottleKilnNeck", V(wkX, wk.Y + 40 * scale, wkZ), 7 * scale, 34 * scale, fSand, Enum.Material.Sandstone)
				local mouth = orb("KilnCrownGlow", V(wkX, wk.Y + 58 * scale, wkZ), V(7, 3, 7), fAmber, Enum.Material.Neon)
				pointLight(mouth, fAmber, 1.6, 54)
			end
		end)

		local eb = layout.Platforms.EastBastion
		local ebX, ebZ = eb.X + 14, eb.Z - eb.Depth / 2 - 16
		table.insert(reservedSpots, { ebX, ebZ, 24 })
		group("SignalLensTower", function()
			currentParent:SetAttribute("OnTerrain", true)
			local pierH = (eb.Y - bottom) + 4
			block("SignalFoundationPier", V(36, pierH, 36), V(ebX, eb.Y - pierH * 0.5, ebZ), fBasalt, Enum.Material.Basalt)
			local scf = CFrame.new(ebX, eb.Y - 0.6, ebZ) * CFrame.Angles(0, math.rad(-26), 0)
			if KitProps.Has("SignalLensTower") then
				local mdl = kitAt("SignalLensTower", scf, 1.32 * scale, f14Override)
				if mdl then
					local anchor = mdl:FindFirstChild("GLOW") or mdl:FindFirstChildWhichIsA("BasePart")
					if anchor then pointLight(anchor, fAmber, 1.6, 58) end
				end
			else
				cyl("SignalBastionShaft", V(ebX, eb.Y + 26 * scale, ebZ), 10 * scale, 52 * scale, fSand, Enum.Material.Sandstone)
				local lens = orb("SignalLensOrb", V(ebX, eb.Y + 60 * scale, ebZ), V(9, 9, 4), fAmber, Enum.Material.Neon)
				pointLight(lens, fAmber, 1.6, 58)
			end
		end)

		-- 4. Ashmarket lower-town bazaar stalls, dry ash fountain & broken amber-glass shards (Basin + Galleries)
		for _, st in { { -56, 122, 22 }, { 56, 122, -24 }, { -56, 174, 152 }, { 56, 174, -154 } } do
			local sx, sz, syaw = st[1], st[2], st[3]
			if footprintClear(sx, sz, 9, 7) then
				local sy = f14MinGroundAt(sx, sz, 7)
				table.insert(reservedSpots, { sx, sz, 12 })
				group("AshmarketStall", function()
					currentParent:SetAttribute("OnTerrain", true)
					local stCf = CFrame.new(sx, sy - 0.3, sz) * CFrame.Angles(0, math.rad(syaw), 0)
					if KitProps.Has("AshmarketStall") then
						kitAt("AshmarketStall", stCf, 1.15 * scale, f14Override)
					else
						block("StallCounter", V(13, 3.2, 4), stCf.Position + V(0, 1.6, 0), fSand, Enum.Material.Sandstone)
						block("StallAwning", V(15, 0.4, 9), stCf.Position + V(0, 9.5, 0), fAshCloth, Enum.Material.Fabric)
					end
				end)
			end
		end

		local fnX, fnZ = -56, 148
		if footprintClear(fnX, fnZ, 9, 9) then
			local fnY = f14MinGroundAt(fnX, fnZ, 7)
			table.insert(reservedSpots, { fnX, fnZ, 12 })
			group("DryAshFountain", function()
				currentParent:SetAttribute("OnTerrain", true)
				cyl("DryFountainBasin", V(fnX, fnY + 0.8, fnZ), 7.8, 2.2, fSand, Enum.Material.Sandstone)
				cyl("DryFountainAshCore", V(fnX, fnY + 1.3, fnZ), 6.0, 1.6, fAshCloth, Enum.Material.Sand)
				cyl("DryFountainSpire", V(fnX, fnY + 4.2, fnZ), 1.6, 7.2, fBasalt, Enum.Material.Basalt)
			end)
		end

		for bIdx, bs in { { 56, 148 }, { -126, 108 }, { 126, 108 }, { -96, -26 }, { 96, -34 }, { -42, 46 } } do
			local bx, bz = bs[1], bs[2]
			if footprintClear(bx, bz, 5, 5) then
				local by = f14MinGroundAt(bx, bz, 4)
				table.insert(reservedSpots, { bx, bz, 7 })
				group("BrokenAmberGlassShards", function()
					currentParent:SetAttribute("OnTerrain", true)
					for k = 1, 4 do
						local a = bIdx * 1.4 + k * 1.5
						local p = V(bx + math.cos(a) * (1.8 + k * 0.7), by + 1.0, bz + math.sin(a) * (1.8 + k * 0.7))
						local sh = block("AmberGlassShard", V(0.85, 3.0 + (k % 2), 1.4), p, fShard, Enum.Material.Glass, nil, 0.22)
						sh.CFrame = CFrame.new(origin + p) * CFrame.Angles(math.rad(28), a, math.rad(16))
					end
				end)
			end
		end

		-- 6. Surrounding Fortress Curtain Walls & Watchtowers framing the Sunscar Citadel
		local f14WallOverride = {
			TRIM = { Color = fSand, Material = Enum.Material.Sandstone },
			ACCENT = { Color = fTerra, Material = Enum.Material.Slate },
			MOSS = { Color = fBasalt, Material = Enum.Material.Basalt },
			WOOD = { Color = fTerra, Material = Enum.Material.Slate },
		}
		local wallScale = 1.45 * scale
		local wallW = 32.1 * wallScale
		local wallD = 7.673 * wallScale
		local curtainPlacements = {
			-- South barbican curtain wings connecting PortcullisGate wings to front watchtowers
			{ -96, 72, 0.08, 4.5, 1.45 },
			{ 96, 72, -0.08, 4.5, 1.45 },
			-- North citadel corner & backdrop walls framing Sunscar Throne
			{ -158, -228, -0.52, 15.0, 1.45 },
			{ 158, -230, 0.52, 15.0, 1.45 },
			{ -98, -244, -0.14, 17.5, 1.45 },
			{ 98, -246, 0.14, 17.5, 1.45 },
		}
		for _, cw in curtainPlacements do
			local wx, wz, wyaw, minY, mult = cw[1], cw[2], cw[3], cw[4], cw[5]
			local ws = mult * scale
			local cwW = 32.1 * ws
			local cwD = 7.673 * ws
			local halfX = math.abs(math.cos(wyaw)) * (cwW * 0.42) + math.abs(math.sin(wyaw)) * (cwD * 0.48)
			local halfZ = math.abs(math.sin(wyaw)) * (cwW * 0.42) + math.abs(math.cos(wyaw)) * (cwD * 0.48)
			if footprintClear(wx, wz, math.max(halfX, 7), math.max(halfZ, 7)) then
				local wy = math.max(f14GroundAt(wx, wz) - 0.6, minY)
				table.insert(reservedSpots, { wx, wz, 14 })
				group("VarrashCurtainWall", function()
					currentParent:SetAttribute("OnTerrain", true)
					local plinthH = (wy - bottom) + 2.2
					local plinth = block(
						"CurtainWallPlinth",
						V(cwW * 0.96, plinthH, cwD * 1.08),
						V(wx, wy - plinthH * 0.5 + 0.8, wz),
						fBasalt,
						Enum.Material.Basalt
					)
					plinth.CFrame = CFrame.new(origin + V(wx, wy - plinthH * 0.5 + 0.8, wz)) * CFrame.Angles(0, wyaw, 0)
					if KitProps.Has("CurtainWallRuins") then
						kitAt("CurtainWallRuins", CFrame.new(wx, wy, wz) * CFrame.Angles(0, wyaw, 0), ws, f14WallOverride)
					else
						local wallBlk = block("CurtainWallCore", V(cwW * 0.9, 26, cwD * 0.8), V(wx, wy + 13, wz), fSand, Enum.Material.Sandstone)
						wallBlk.CFrame = CFrame.new(origin + V(wx, wy + 13, wz)) * CFrame.Angles(0, wyaw, 0)
					end
				end)
			end
		end

		-- Outer plateau & mid-flank CurtainWallRuins replacing boxy block walls along the West/East perimeter
		local flankRuins = {
			{ -194, -78, math.pi * 0.5, 9.0, 0.92 },
			{ 194, -84, -math.pi * 0.5, 9.0, 0.92 },
			{ -198, -150, math.pi * 0.5, 13.5, 1.32 },
			{ 198, -160, -math.pi * 0.5, 15.5, 1.32 },
		}
		for _, cw in flankRuins do
			local wx, wz, wyaw, minY, mult = cw[1], cw[2], cw[3], cw[4], cw[5]
			local ws = mult * scale
			local cwW = 32.1 * ws
			local cwD = 7.673 * ws
			local wy = math.max(f14GroundAt(wx, wz) - 0.6, minY)
			table.insert(reservedSpots, { wx, wz, 14 })
			group("VarrashCurtainWall", function()
				currentParent:SetAttribute("OnTerrain", true)
				local plinthH = (wy - bottom) + 2.2
				local plinth = block(
					"CurtainWallPlinth",
					V(cwW * 0.96, plinthH, cwD * 1.08),
					V(wx, wy - plinthH * 0.5 + 0.8, wz),
					fBasalt,
					Enum.Material.Basalt
				)
				plinth.CFrame = CFrame.new(origin + V(wx, wy - plinthH * 0.5 + 0.8, wz)) * CFrame.Angles(0, wyaw, 0)
				if KitProps.Has("CurtainWallRuins") then
					kitAt("CurtainWallRuins", CFrame.new(wx, wy, wz) * CFrame.Angles(0, wyaw, 0), ws, f14WallOverride)
				else
					local wallBlk = block("CurtainWallCore", V(cwW * 0.9, 26, cwD * 0.8), V(wx, wy + 13, wz), fSand, Enum.Material.Sandstone)
					wallBlk.CFrame = CFrame.new(origin + V(wx, wy + 13, wz)) * CFrame.Angles(0, wyaw, 0)
				end
			end)
		end

		local towerPlacements = {
			-- Twin front gatehouse corner towers flanking the front barbican walls
			{ -134, 66, 5.5, 34, true },
			{ 134, 66, 5.5, 34, true },
			-- Mid-flank chasm watchtowers bracketing the West & East gap walls
			{ -194, -56, 8.5, 34, false },
			{ 194, -62, 8.5, 34, false },
			{ -194, -100, 10.5, 36, false },
			{ 194, -106, 10.5, 36, false },
			-- North citadel flanking towers beside the north curtain walls
			{ -128, -236, 16.5, 38, false },
			{ 128, -240, 16.5, 38, false },
		}
		for _, tw in towerPlacements do
			local tx, tz, minY, towerH, lit = tw[1], tw[2], tw[3], tw[4], tw[5]
			if footprintClear(tx, tz, 6.5, 6.5) then
				local ty = math.max(f14GroundAt(tx, tz) - 0.5, minY)
				table.insert(reservedSpots, { tx, tz, 13 })
				group("VarrashBastionTower", function()
					currentParent:SetAttribute("OnTerrain", true)
					local plinthH = (ty - bottom) + 4.5
					block("VarrashTowerPlinth", V(19.5, plinthH, 19.5), V(tx, ty - plinthH * 0.5 + 2.0, tz), fBasalt, Enum.Material.Basalt)
					local shaft = block("VarrashTowerShaft", V(14.5, towerH, 14.5), V(tx, ty + towerH * 0.5 + 1.5, tz), fSand, Enum.Material.Sandstone)
					block("VarrashTowerBand", V(15.6, 2.6, 15.6), V(tx, ty + towerH - 3.5, tz), fTerra, Enum.Material.Slate)
					block("VarrashTowerCornice", V(17.8, 2.8, 17.8), V(tx, ty + towerH + 2.2, tz), fBasalt, Enum.Material.Basalt)
					for _, mx in { -6.4, 6.4 } do
						for _, mz in { -6.4, 6.4 } do
							block("VarrashTowerMerlon", V(4.6, 4.2, 4.6), V(tx + mx, ty + towerH + 5.2, tz + mz), fSand, Enum.Material.Sandstone)
						end
					end
					local slit = block("VarrashTowerSlit", V(1.1, 7.2, 15.1), V(tx, ty + towerH * 0.62 + 1.5, tz), fAmber, Enum.Material.Neon)
					if lit then
						pointLight(shaft, fAmber, 1.2, 38)
					else
						slit.Material = Enum.Material.Neon
					end
				end)
			end
		end
	elseif layout.Authored == "ashen:5" then
		-- Floor 15, Colossus Dais (ashen:5): Cinderhold's volcanic caldera over a cracked-lava lake.
		-- The fallen Elder Colossus lies diagonally across the caldera: Fallen Hand -> forearm -> Elder's Chest
		-- -> upper arm -> Shoulder on the west, with Broken Shield & Fallen Crown + Head on the east.
		local cBasalt = rgb(40, 34, 38)
		local cSand = rgb(176, 146, 108)
		local cTerra = rgb(164, 86, 56)
		local cBronze = rgb(78, 62, 54)
		local cMagma = rgb(255, 114, 34)
		local cEmber = rgb(255, 148, 48)
		local cCloth = rgb(146, 134, 122)

		local function f15GroundAt(x: number, z: number): number
			for _, plat in layout.Platforms do
				if math.abs(x - plat.X) <= plat.Width * 0.5 + 4 and math.abs(z - plat.Z) <= plat.Depth * 0.5 + 4 then
					return plat.Y
				end
			end
			return if field then math.max(field.Sample(x, z), bottom) else bottom
		end

		local cOverride = {
			STONE = { Color = cBasalt, Material = Enum.Material.Basalt },
			TRIM = { Color = cSand, Material = Enum.Material.Sandstone },
			ALT = { Color = cTerra, Material = Enum.Material.Slate },
			METAL = { Color = cBronze, Material = Enum.Material.Metal },
			GLOW = { Color = cMagma, Material = Enum.Material.Neon },
		}

		-- 1. Cracked-lava Caldera Lake magma web & cliff lava-falls pouring into the caldera
		local lavaTopY = (field and field.LiquidLevel or -6.8) + 0.14
		group("CalderaLavaSeams", function()
			currentParent:SetAttribute("OnTerrain", true)
			for laneIdx, xs in { -112, -38, 36, 110 } do
				local prevPt = V(xs * 0.72, lavaTopY, -172)
				for k = 1, 5 do
					local t = k / 5
					local nz = -172 + t * 260
					local nx = xs * (0.78 + 0.22 * math.sin(t * math.pi)) + math.sin(nz * 0.045 + laneIdx * 1.3) * 14
					local nextPt = V(nx, lavaTopY, nz)
					local seam = beam("CalderaMagmaCrack", prevPt, nextPt, if k % 2 == 0 then 3.4 else 2.4, cMagma, Enum.Material.Neon)
					if laneIdx == 36 and (k == 2 or k == 4) then
						local em = Instance.new("ParticleEmitter")
						em.Name = "CalderaRisingEmbers"
						em.Color = ColorSequence.new(rgb(255, 152, 48), rgb(255, 64, 20))
						em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0.15) })
						em.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
						em.Lifetime = NumberRange.new(2.0, 3.6)
						em.Rate = 5
						em.Speed = NumberRange.new(7, 14)
						em.Parent = seam
					end
					if k == 2 or k == 4 then
						local fork = nextPt + V((if laneIdx < 0 then 1 else -1) * 20, 0, 12)
						beam("CalderaMagmaFork", nextPt, fork, 1.8, cEmber, Enum.Material.Neon)
					end
					prevPt = nextPt
				end
			end
		end)
		-- Separate lava-fall groups pouring off caldera shore cliffs into the lake
		for _, lf in {
			{ -104, 10, -158, -88, lavaTopY, -142 },
			{ 108, 10, -148, 90, lavaTopY, -132 },
			{ -114, 4, 38, -92, lavaTopY, 38 },
			{ 116, 4, 34, 94, lavaTopY, 34 },
		} do
			group("CalderaLavaFall", function()
				currentParent:SetAttribute("OnTerrain", true)
				local topP = V(lf[1], lf[2], lf[3])
				local botP = V(lf[4], lf[5], lf[6])
				beam("CalderaLavaFall", topP, botP, 4.2, cMagma, Enum.Material.Neon)
				cyl("LavaFallSplash", botP, 8.5, 0.6, cEmber, Enum.Material.Neon)
			end)
		end

		-- 1b. Colossal Ash-Dragon Corpse half-submerged in the middle of the molten caldera lake
		local drX, drZ = 52, 34
		local drY = lavaTopY - 0.35
		table.insert(reservedSpots, { drX, drZ, 28 })
		group("CalderaDragonCorpse", function()
			currentParent:SetAttribute("OnTerrain", true)
			local dcf = CFrame.new(drX, drY, drZ) * CFrame.Angles(0, -0.52, 0)
			if KitProps.Has("CalderaDragonCorpse") then
				local mdl = kitAt("CalderaDragonCorpse", dcf, 0.72 * scale, {
					STONE = { Color = cBasalt, Material = Enum.Material.Basalt },
					TRIM = { Color = rgb(196, 182, 162), Material = Enum.Material.Sandstone },
					GLOW = { Color = cMagma, Material = Enum.Material.Neon },
				})
				local glowPart = mdl and (mdl:FindFirstChild("GLOW") or mdl:FindFirstChildWhichIsA("BasePart"))
				if glowPart then
					pointLight(glowPart, cMagma, 1.8, 58)
				end
			else
				local boneCol = rgb(198, 184, 164)
				local darkBone = rgb(134, 122, 110)
				local crust = cyl("DragonMagmaCrust", V(drX, lavaTopY - 1.2, drZ), 26, 3.6, cBasalt, Enum.Material.Basalt)
				crust.CFrame = CFrame.new(origin) * dcf * CFrame.new(0, -0.8, 0)
				local heartPool = cyl("DragonHeartLavaPool", V(drX, drY + 0.5, drZ), 13, 0.8, cMagma, Enum.Material.Neon)
				heartPool.CFrame = CFrame.new(origin) * dcf * CFrame.new(0, 0.6, 2)
				pointLight(heartPool, cMagma, 1.8, 58)
				local dEm = Instance.new("ParticleEmitter")
				dEm.Name = "DragonCorpseEmbers"
				dEm.Color = ColorSequence.new(rgb(255, 168, 58), rgb(255, 68, 22))
				dEm.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0.15) })
				dEm.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
				dEm.Lifetime = NumberRange.new(2.0, 3.8)
				dEm.Rate = 6
				dEm.Speed = NumberRange.new(8, 16)
				dEm.Parent = heartPool

				-- Horned Dragon Skull angled toward Ashmarket (+Z local in dcf)
				local headPos = dcf:PointToWorldSpace(V(-2, 5.5, 24))
				local skull = block("DragonSkullCranium", V(12, 7.5, 14), headPos, boneCol, Enum.Material.Sandstone)
				skull.CFrame = CFrame.new(origin + headPos) * CFrame.Angles(math.rad(14), -0.52, math.rad(-10))
				local snoutPos = dcf:PointToWorldSpace(V(-3, 4.2, 34))
				local snout = block("DragonSkullSnout", V(7.5, 5.0, 13), snoutPos, boneCol, Enum.Material.Sandstone)
				snout.CFrame = CFrame.new(origin + snoutPos) * CFrame.Angles(math.rad(16), -0.52, math.rad(-10))
				for _, side in { -1, 1 } do
					local hPos = dcf:PointToWorldSpace(V(-2 + side * 6.5, 9.5, 16))
					local horn = block("DragonObsidianHorn", V(2.4, 3.2, 16), hPos, cBasalt, Enum.Material.Basalt)
					horn.CFrame = CFrame.new(origin + hPos) * CFrame.Angles(math.rad(-26), -0.52 + side * 0.25, 0)
					local eyePos = dcf:PointToWorldSpace(V(-2 + side * 4.4, 6.4, 24))
					orb("DragonEmberEye", eyePos, V(2.2, 1.8, 2.2), cMagma, Enum.Material.Neon)
				end

				-- Sinuous vertebrae spine + 5 pairs of colossal ribcage arches + 2 skeletal wing spars
				for sIdx = 1, 7 do
					local u = (sIdx - 1) / 6
					local spLocal = V(math.sin(u * math.pi * 1.4) * 7, 3.5 + math.sin(u * math.pi) * 6.5, 16 - u * 44)
					local spWorld = dcf:PointToWorldSpace(spLocal)
					local vert = block("DragonVertebra", V(5.2 - u * 1.8, 5.0 - u * 1.6, 7.0), spWorld, darkBone, Enum.Material.Sandstone)
					vert.CFrame = CFrame.new(origin + spWorld) * CFrame.Angles(0, -0.52 + math.cos(u * 4) * 0.25, 0)
				end
				for rIdx = 1, 5 do
					local rz = 12 - (rIdx - 1) * 5.8
					local span = 12 + math.sin((rIdx / 5) * math.pi) * 5.5
					local ribH = 12 + math.sin((rIdx / 5) * math.pi) * 4.5
					for _, side in { -1, 1 } do
						local rMid = dcf:PointToWorldSpace(V(side * (span * 0.55), ribH * 0.45, rz))
						local rib = block("DragonRibBone", V(2.2, ribH, 2.4), rMid, boneCol, Enum.Material.Sandstone)
						rib.CFrame = CFrame.new(origin + rMid) * CFrame.Angles(0, -0.52, math.rad(side * 28))
					end
				end
				for _, wg in { { -1, 21, 14 }, { 1, 15, 7 } } do
					local side, wy, wz = wg[1], wg[2], wg[3]
					local wMid = dcf:PointToWorldSpace(V(side * 16, wy * 0.6, wz - 6))
					local spar = block("DragonWingSpar", V(2.2, 2.2, 28), wMid, darkBone, Enum.Material.Sandstone)
					spar.CFrame = CFrame.new(origin + wMid) * CFrame.Angles(math.rad(-28), -0.52 + side * 0.72, 0)
					local wTip = dcf:PointToWorldSpace(V(side * 26, wy * 0.35, wz - 16))
					local fingerSpar = block("DragonWingFinger", V(1.4, 1.4, 22), wTip, cBasalt, Enum.Material.Basalt)
					fingerSpar.CFrame = CFrame.new(origin + wTip) * CFrame.Angles(math.rad(18), -0.52 + side * 0.95, 0)
				end
			end
		end)

		-- 2. Fallen Hand: Giant open stone hand rising out of the foreground-west molten lake beside Crossing
		local handX, handZ = -60, 40
		table.insert(reservedSpots, { handX, handZ, 30 })
		group("ElderHandFingers", function()
			currentParent:SetAttribute("OnTerrain", true)
			local hy = lavaTopY + 1.0
			local plinthH = (hy - bottom) + 3.5
			block("ElderHandWristPlinth", V(30, plinthH, 48), V(handX, hy - plinthH * 0.5 + 1.2, handZ), cBasalt, Enum.Material.Basalt)
			local hcf = CFrame.new(handX, hy - 0.5, handZ) * CFrame.Angles(0, -math.pi * 0.65, 0)
			if KitProps.Has("ElderHandFingers") then
				kitAt("ElderHandFingers", hcf, 1.12 * scale, cOverride)
			else
				for fIdx = -2, 2 do
					local ang = fIdx * 0.24
					local fx = math.sin(ang) * 20
					local fz = -math.cos(ang) * 8
					local fh = if fIdx == 0 then 32 else if math.abs(fIdx) == 1 then 28 else 22
					local fp = hcf:PointToWorldSpace(V(fx, fh * 0.36, fz))
					local finger = block("ElderStoneFinger", V(7.2, fh * 0.72, 7.4), fp, cSand, Enum.Material.Sandstone)
					finger.CFrame = CFrame.new(origin + fp) * CFrame.Angles(math.rad(-14), -math.pi * 0.62 + ang * 0.4, 0)
					local tipP = hcf:PointToWorldSpace(V(fx * 0.92, fh * 0.82, fz - 3.6))
					local tip = block("ElderFingerTip", V(6.0, fh * 0.38, 6.2), tipP, cBasalt, Enum.Material.Basalt)
					tip.CFrame = CFrame.new(origin + tipP) * CFrame.Angles(math.rad(-42), -math.pi * 0.62 + ang * 0.4, 0)
				end
			end
		end)

		-- 3. Forearm & Upper Arm stone ridge armor cradling WestGallery->Crossing and Crossing->WestBastion undersides
		local armPairs = {
			{ layout.Platforms.WestGallery, layout.Platforms.Crossing, "ElderForearmGuard" },
			{ layout.Platforms.Crossing, layout.Platforms.WestBastion, "ElderUpperArmGuard" },
		}
		for _, ap in armPairs do
			local pA, pB, kindName = ap[1], ap[2], ap[3]
			group(kindName, function()
				currentParent:SetAttribute("OnTerrain", true)
				local aPt = V(pA.X, pA.Y, pA.Z)
				local bPt = V(pB.X, pB.Y, pB.Z)
				local dir = (bPt - aPt)
				local yaw = math.atan2(dir.X, dir.Z)
				for _, frac in { 0.32, 0.50, 0.68 } do
					local mid = aPt:Lerp(bPt, frac)
					local cuff = block("ColossusArmBracer", V(38, 5.2, 13.5), mid - V(0, 4.6, 0), if frac == 0.50 then cTerra else cSand, Enum.Material.Sandstone)
					cuff.CFrame = CFrame.new(origin + mid - V(0, 4.6, 0)) * CFrame.Angles(0, yaw, 0)
					local pierH = math.max(4, mid.Y - bottom - 4.4)
					local pier = block("ColossusArmPier", V(26, pierH, 12), V(mid.X, mid.Y - 4.6 - pierH * 0.5, mid.Z), cBasalt, Enum.Material.Basalt)
					pier.CFrame = CFrame.new(origin + V(mid.X, mid.Y - 4.6 - pierH * 0.5, mid.Z)) * CFrame.Angles(0, yaw, 0)
				end
			end)
		end

		-- 4. Elder's Chest Ribs (-30, 10, -40): colossal curved rib buttresses framing Crossing's open east flank
		local cross = layout.Platforms.Crossing
		group("ElderChestRibs", function()
			currentParent:SetAttribute("OnTerrain", true)
			for _, rzOff in { -15, 0, 15 } do
				local rx = cross.X + cross.Width * 0.5 + 10
				local rz = cross.Z + rzOff
				local ribH = (cross.Y - bottom) + 20
				local rib = block("ElderChestRibPillar", V(9.5, ribH, 9.0), V(rx, cross.Y - ribH * 0.5 + 14.0, rz), cSand, Enum.Material.Sandstone)
				rib.CFrame = CFrame.new(origin + V(rx, cross.Y - ribH * 0.5 + 14.0, rz)) * CFrame.Angles(0, 0, math.rad(20))
			end
		end)

		-- 5. Broken Shield: massive tilted circular shield rising out of the mid-east molten lake
		local shX, shZ = 100, -48
		table.insert(reservedSpots, { shX, shZ, 30 })
		group("ElderShieldRim", function()
			currentParent:SetAttribute("OnTerrain", true)
			local sy = lavaTopY + 1.0
			local plinthH = (sy - bottom) + 3.5
			block("ElderShieldCradle", V(30, plinthH, 40), V(shX, sy - plinthH * 0.5 + 1.2, shZ), cBasalt, Enum.Material.Basalt)
			local scf = CFrame.new(shX, sy - 0.5, shZ) * CFrame.Angles(0, -math.pi * 0.25, 0)
			if KitProps.Has("ElderShieldRim") then
				local mdl = kitAt("ElderShieldRim", scf, 1.34 * scale, cOverride)
				if mdl then
					local glowPart = mdl:FindFirstChild("GLOW") or mdl:FindFirstChildWhichIsA("BasePart")
					if glowPart then pointLight(glowPart, cMagma, 1.4, 48) end
				end
			else
				for _, sSide in { -1, 1 } do
					local halfD = cyl("ElderShieldDisc", V(shX, sy + 12, shZ), 26, 4.4, cSand, Enum.Material.Sandstone)
					halfD.CFrame = CFrame.new(origin) * scf * CFrame.new(sSide * 2.6, 12.5, sSide * 0.8) * CFrame.Angles(math.rad(56), 0, math.rad(sSide * -6))
				end
				local boss = cyl("ElderShieldBoss", V(shX, sy + 12, shZ), 7.2, 6.2, cBronze, Enum.Material.Metal)
				boss.CFrame = CFrame.new(origin) * scf * CFrame.new(0, 12.8, -2.0) * CFrame.Angles(math.rad(56), 0, 0)
				local seam = block("ElderShieldCrackGlow", V(2.4, 34, 5.4), V(shX, sy + 12, shZ), cMagma, Enum.Material.Neon)
				seam.CFrame = CFrame.new(origin) * scf * CFrame.new(0, 12.5, 0) * CFrame.Angles(math.rad(-34), 0, 0)
			end
		end)

		-- 6. Shoulder Pauldron & Basalt Column Ring towering on the upper-left ridge beside Apex Dais
		local spX, spZ = -114, -242
		table.insert(reservedSpots, { spX, spZ, 28 })
		group("ElderShoulderPauldron", function()
			currentParent:SetAttribute("OnTerrain", true)
			local spy = 18
			local plinthH = (spy - bottom) + 4.0
			block("ShoulderCradle", V(32, plinthH, 40), V(spX, spy - plinthH * 0.5 + 1.5, spZ), cBasalt, Enum.Material.Basalt)
			local spcf = CFrame.new(spX, spy - 0.5, spZ) * CFrame.Angles(0, -math.pi * 0.34, 0)
			if KitProps.Has("ElderShoulderPauldron") then
				kitAt("ElderShoulderPauldron", spcf, 1.36 * scale, cOverride)
			else
				local dome = orb("ShoulderPauldronDome", V(spX + 3, spy + 13, spZ), V(32, 24, 36), cSand, Enum.Material.Sandstone)
				dome.CFrame = CFrame.new(origin + V(spX + 3, spy + 13, spZ)) * CFrame.Angles(0, -math.pi * 0.34, math.rad(16))
				for cIdx = -2, 2 do
					local colH = 34 + ((math.abs(cIdx) + 1) % 3) * 12
					cyl("ShoulderBasaltCol", V(spX - 10 + cIdx * 3.5, spy + colH * 0.5, spZ + cIdx * 8), 4.4, colH, cBasalt, Enum.Material.Basalt)
				end
			end
		end)

		-- 7. Elder Colossus Head (upper-right caldera overlooking lake) & Fallen Crown (upper-right ridge beside Apex Dais)
		local crX, crZ = 126, -266
		local hdX, hdZ = 76, -110
		table.insert(reservedSpots, { crX, crZ, 28 })
		table.insert(reservedSpots, { hdX, hdZ, 26 })
		group("ElderCrownRing", function()
			currentParent:SetAttribute("OnTerrain", true)
			local cry = 18
			local plinthH = (cry - bottom) + 4.0
			block("CrownCradle", V(34, plinthH, 42), V(crX, cry - plinthH * 0.5 + 1.2, crZ), cBasalt, Enum.Material.Basalt)
			local crcf = CFrame.new(crX, cry - 0.5, crZ) * CFrame.Angles(0, math.pi * 0.28, 0)
			if KitProps.Has("ElderCrownRing") then
				kitAt("ElderCrownRing", crcf, 1.34 * scale, cOverride)
			else
				for k = -3, 3 do
					local sp = crcf:PointToWorldSpace(V(k * 8.5, 13 + (k % 2) * 4, -math.abs(k) * 2.5))
					block("CrownSpike", V(5.8, 26 + (k % 2) * 6, 5.8), sp, cSand, Enum.Material.Sandstone)
				end
			end
		end)
		group("ElderColossusHead", function()
			currentParent:SetAttribute("OnTerrain", true)
			local hdy = lavaTopY + 6.0
			local plinthH = (hdy - bottom) + 3.5
			block("HeadRubbleCradle", V(28, plinthH, 30), V(hdX, hdy - plinthH * 0.5 + 1.2, hdZ), cBasalt, Enum.Material.Basalt)
			local hdcf = CFrame.new(hdX, hdy - 0.4, hdZ) * CFrame.Angles(0, math.pi * 0.18, 0)
			if KitProps.Has("ElderColossusHead") then
				local mdl = kitAt("ElderColossusHead", hdcf, 1.36 * scale, cOverride)
				if mdl then
					local glowPart = mdl:FindFirstChild("GLOW") or mdl:FindFirstChildWhichIsA("BasePart")
					if glowPart then pointLight(glowPart, cEmber, 1.0, 38) end
				end
			else
				local headBlk = block("FallenColossusCranium", V(26, 20, 30), V(hdX, hdy + 10, hdZ), cSand, Enum.Material.Sandstone)
				headBlk.CFrame = CFrame.new(origin) * hdcf * CFrame.new(0, 10, 0) * CFrame.Angles(math.rad(-22), 0, math.rad(18))
			end
		end)

		-- 8. Hexagonal Basalt Column Clusters ringing the Colossus Dais flanks & Ash Caldera Foreground
		local dais = layout.Platforms.Apex
		for _, bc in {
			{ dais.X - 78, dais.Z - 4, 22, 34 },
			{ dais.X + 78, dais.Z - 4, 22, 34 },
			{ dais.X - 78, dais.Z - 38, 24, 42 },
			{ dais.X + 78, dais.Z - 38, 24, 42 },
		} do
			local cx, cz, baseY, colBaseH = bc[1], bc[2], bc[3], bc[4]
			table.insert(reservedSpots, { cx, cz, 14 })
			group("DaisBasaltColumns", function()
				currentParent:SetAttribute("OnTerrain", true)
				for k = 0, 3 do
					local a = k * 1.55 + cx * 0.05
					local ox = math.cos(a) * 4.8
					local oz = math.sin(a) * 4.8
					local ch = colBaseH + (k % 3) * 8 + (baseY - bottom)
					cyl("DaisHexColumn", V(cx + ox, bottom + ch * 0.5 - 1, cz + oz), 3.8 + (k % 2) * 0.8, ch, cBasalt, Enum.Material.Basalt)
				end
			end)
		end

		-- Foreground Basin Ash Raider outpost tents, ember shrines & wrecked caravan wagons along Caldera Floor
		for idxF, fg in { { -46, 178, 0.35 }, { 46, 178, -0.42 } } do
			local fx, fz, fyaw = fg[1], fg[2], fg[3]
			if footprintClear(fx, fz, 10, 10) then
				local fy = f15GroundAt(fx, fz)
				table.insert(reservedSpots, { fx, fz, 14 })
				group("CalderaOutpostCamp", function()
					currentParent:SetAttribute("OnTerrain", true)
					local tarp = block("OutpostAshTarp", V(13, 0.5, 10), V(fx, fy + 5.2, fz), cCloth, Enum.Material.Fabric)
					tarp.CFrame = CFrame.new(origin + V(fx, fy + 5.2, fz)) * CFrame.Angles(math.rad(16), fyaw, 0)
					for _, side in { -1, 1 } do
						block("OutpostPole", V(0.7, 6.2, 0.7), V(fx + side * 5.0, fy + 2.8, fz), cBronze, Enum.Material.Wood)
					end
					local fireCore = orb("CalderaCampEmber", V(fx + 2.5, fy + 0.6, fz + 7), V(2.4, 1.2, 2.4), cEmber, Enum.Material.Neon)
					pointLight(fireCore, cEmber, 0.9, 26)
					-- Buried charred caravan wagon wreck behind the camp
					local wx, wz = fx + (if idxF == 1 then -12 else 12), fz + 12
					local wy = f15GroundAt(wx, wz)
					local bed = block("WreckedWagonBed", V(8.0, 2.2, 11.0), V(wx, wy + 1.4, wz), cBronze, Enum.Material.Wood)
					bed.CFrame = CFrame.new(origin + V(wx, wy + 1.4, wz)) * CFrame.Angles(math.rad(10), fyaw + 0.4, math.rad(-8))
					cyl("WreckedWagonWheel", V(wx + 4.2, wy + 1.8, wz + 2), 2.4, 0.8, cBasalt, Enum.Material.Wood)
				end)
			end
		end
		-- Sealed-Flame Varrash Ember Shrines guiding the shore & framing the north rim of Colossus Dais
		for _, sh in { { -34, 0, 108, true }, { 34, 0, 108, true }, { -56, 28, -264, false }, { 56, 28, -264, false } } do
			local sx, sy, sz, lit = sh[1], sh[2], sh[3], sh[4]
			if footprintClear(sx, sz, 6, 6) then
				local groundY = math.min(f15GroundAt(sx, sz), sy)
				table.insert(reservedSpots, { sx, sz, 10 })
				group("VarrashEmberShrine", function()
					currentParent:SetAttribute("OnTerrain", true)
					local baseBot = math.max(bottom, groundY - 4)
					local plinthH = (groundY - baseBot) + 3.0
					block("ShrineBasaltBase", V(7.5, plinthH, 7.5), V(sx, groundY - plinthH * 0.5 + 1.2, sz), cBasalt, Enum.Material.Basalt)
					block("ShrineSandstoneShaft", V(4.6, 8.5, 4.6), V(sx, groundY + 5.2, sz), cSand, Enum.Material.Sandstone)
					block("ShrineBronzeCage", V(5.6, 3.6, 5.6), V(sx, groundY + 10.6, sz), cBronze, Enum.Material.Metal)
					local flame = orb("ShrineEmberFlame", V(sx, groundY + 11.2, sz), V(3.0, 4.2, 3.0), cMagma, Enum.Material.Neon)
					if lit then
						pointLight(flame, cMagma, 1.1, 34)
					end
				end)
			end
		end
	elseif biome == "frozen_citadel" and layout.Authored == "frozen:1" then
		-- Floor 16, Rimefall Approach: natural winter lakeside & ice floes below the frozen Rimefall.
		local cGranite = rgb(104, 118, 134)
		local cGraniteDark = rgb(74, 86, 100)
		local cSnow = rgb(232, 242, 252)
		local cGlacier = rgb(146, 206, 238)
		local cTimber = rgb(92, 74, 60)
		local cWarmGlow = rgb(255, 206, 128)
		local cRimeBlue = rgb(142, 224, 255)
		local lakeY = if field then field.LiquidLevel + 2.0 else 0.8
		local groundAt16 = function(x: number, z: number): number
			for _, plat in layout.Platforms do
				if math.abs(x - plat.X) <= plat.Width * 0.5 + 4 and math.abs(z - plat.Z) <= plat.Depth * 0.5 + 4 then
					return plat.Y
				end
			end
			return if field then math.max(field.Height(x, z) + 2.0, bottom) else bottom
		end
		table.insert(reservedSpots, { 24, -198, 42 })
		table.insert(reservedSpots, { -30, -194, 34 })
		-- Keep the middle-right snowfield corridor clear of trees blocking BASIN_EAST (right side of Sanctuary spawn)
		table.insert(reservedSpots, { 54, 92, 46 })
		table.insert(reservedSpots, { 86, 86, 34 })
		local f16Override = {
			STONE = { Color = cGranite, Material = Enum.Material.Slate },
			MOSS = { Color = cSnow, Material = Enum.Material.Snow },
			CRYSTAL = { Color = cGlacier, Material = Enum.Material.Ice, Transparency = 0.1 },
			GLOW = { Color = cRimeBlue, Material = Enum.Material.Neon },
			WOOD = { Color = cTimber, Material = Enum.Material.Wood },
			TRIM = { Color = rgb(196, 206, 218), Material = Enum.Material.Slate },
			ALT = { Color = rgb(118, 124, 132), Material = Enum.Material.Fabric },
			METAL = { Color = rgb(54, 62, 74), Material = Enum.Material.Metal },
		}

		-- 1. Foreground Ward-Star Shield Waymarker planted in Snowfield (-28, 0, 100) + curving sledge tracks
		local shX, shZ = -28, 100
		table.insert(reservedSpots, { shX, shZ, 12 })
		group("WardStarShieldMarker", function()
			currentParent:SetAttribute("OnTerrain", true)
			local sy = groundAt16(shX, shZ)
			local scf = CFrame.new(shX, sy - 0.35, shZ) * CFrame.Angles(0, 0.32, 0)
			if KitProps.Has("WardStarShieldMarker") then
				kitAt("WardStarShieldMarker", scf, 1.05 * scale, f16Override)
			else
				block("WardStarShieldMound", V(9.5, 2.2, 6.2), V(shX, sy + 0.5, shZ), cSnow, Enum.Material.Snow)
				local shieldBaseCF = CFrame.new(origin + V(shX, sy + 4.3, shZ)) * CFrame.Angles(math.rad(-14), 0.32, math.rad(9))
				local slab = block("WardStarShieldSlab", V(5.8, 6.8, 1.0), V(shX, sy + 4.3, shZ), cGranite, Enum.Material.Slate)
				slab.CFrame = shieldBaseCF
				local rim = block("WardStarShieldRim", V(6.4, 7.4, 0.55), V(shX, sy + 4.3, shZ), cGlacier, Enum.Material.Ice)
				rim.CFrame = shieldBaseCF * CFrame.new(0, 0, -0.15)
				for _, armAngle in { 0, math.rad(60), math.rad(-60) } do
					local arm = block("WardStarEmblemArm", V(4.2, 0.65, 0.45), V(shX, sy + 4.5, shZ), cRimeBlue, Enum.Material.Ice)
					arm.CFrame = shieldBaseCF * CFrame.new(0, 0.3, 0.52) * CFrame.Angles(0, 0, armAngle)
				end
			end
		end)
		group("SnowfieldSledgeTracks", function()
			currentParent:SetAttribute("OnTerrain", true)
			for seg = 1, 5 do
				local t = (seg - 0.5) / 5
				local tx = -42 - t * 34
				local tz = 122 - math.sin(t * 1.4) * 20
				local ty = groundAt16(tx, tz) - 0.12
				for _, rut in { -1.5, 1.5 } do
					local rPart = block("SledgeTrackRut", V(0.45, 0.14, 7.6), V(tx + rut, ty, tz), rgb(176, 198, 218), Enum.Material.Glacier)
					rPart.CFrame = CFrame.new(origin + V(tx + rut, ty, tz)) * CFrame.Angles(0, math.rad(34), 0)
				end
			end
		end)

		local sanct = layout.Platforms.Sanctuary
		local sanctX = if sanct then sanct.X else 0
		local sanctZ = if sanct then sanct.Z else 166

		-- 2. Hunters' Lodge on the open west shoreline facing Sanctuary (-130, ly, 34)
		local lodgeX, lodgeZ = -130, 34
		table.insert(reservedSpots, { lodgeX, lodgeZ, 26 })
		group("HuntersLodge", function()
			currentParent:SetAttribute("OnTerrain", true)
			local ly = math.max(groundAt16(lodgeX, lodgeZ) - 1.2, layout.Platforms.WestGallery.Y - 2.6)
			local lodgeYaw = math.atan2(sanctX - lodgeX, sanctZ - lodgeZ)
			local lcf = CFrame.new(lodgeX, ly, lodgeZ) * CFrame.Angles(0, lodgeYaw, 0)
			if KitProps.Has("HuntersLodge") then
				local mdl = kitAt("HuntersLodge", lcf, 1.42 * scale, {
					STONE = f16Override.STONE,
					MOSS = f16Override.MOSS,
					WOOD = f16Override.WOOD,
					TRIM = f16Override.TRIM,
					GLOW = { Color = cWarmGlow, Material = Enum.Material.Neon },
				})
				local gp = mdl and mdl:FindFirstChild("GLOW")
				if gp then pointLight(gp, cWarmGlow, 0.95, 36) end
			else
				local baseCF = CFrame.new(origin + V(lodgeX, ly, lodgeZ)) * CFrame.Angles(0, lodgeYaw, 0)
				local stoneBase = block("LodgeStoneWall", V(27.0, 5.2, 22.0), V(lodgeX, ly + 1.0, lodgeZ), cGranite, Enum.Material.Slate)
				stoneBase.CFrame = baseCF * CFrame.new(0, 1.0, 0)
				local body = block("LodgeTimberBody", V(26.0, 11.2, 21.0), V(lodgeX, ly + 8.6, lodgeZ), cTimber, Enum.Material.Wood)
				body.CFrame = baseCF * CFrame.new(0, 8.6, 0)
				local door = block("LodgeFrontDoor", V(4.2, 7.6, 0.7), V(lodgeX, ly + 6.4, lodgeZ), rgb(72, 56, 44), Enum.Material.Wood)
				door.CFrame = baseCF * CFrame.new(0, 6.4, 10.6)
				for _, sx in { -7.0, 7.0 } do
					local win = block("LodgeWarmWindow", V(3.4, 3.4, 0.7), V(lodgeX, ly + 8.6, lodgeZ), cWarmGlow, Enum.Material.Neon)
					win.CFrame = baseCF * CFrame.new(sx, 8.6, 10.6)
					if sx > 0 then pointLight(win, cWarmGlow, 0.95, 36) end
				end
				for _, side in { -1, 1 } do
					local roof = block("LodgeSnowRoofSlope", V(29.5, 2.0, 16.0), V(lodgeX, ly + 17.0, lodgeZ), cSnow, Enum.Material.Snow)
					roof.CFrame = baseCF * CFrame.new(0, 16.8, side * 6.0) * CFrame.Angles(side * 0.56, 0, 0)
				end
				local chimney = block("LodgeStoneChimney", V(4.0, 14.5, 4.0), V(lodgeX, ly + 16.0, lodgeZ), cGraniteDark, Enum.Material.Slate)
				chimney.CFrame = baseCF * CFrame.new(-7.5, 16.0, -5.5)
				local rack = block("LodgeDryingRack", V(11.0, 0.7, 0.7), V(lodgeX, ly + 5.8, lodgeZ), cTimber, Enum.Material.Wood)
				rack.CFrame = baseCF * CFrame.new(-15.5, 5.8, 0) * CFrame.Angles(0, math.pi * 0.5, 0)
				for _, rz in { -4.4, 4.4 } do
					local post = block("LodgeRackPost", V(0.85, 7.0, 0.85), V(lodgeX, ly + 3.2, lodgeZ), cTimber, Enum.Material.Wood)
					post.CFrame = baseCF * CFrame.new(-15.5, 3.2, rz)
				end
			end
		end)

		-- 3. Fisher's Hut & beached rowboats on the east shoreline facing Sanctuary (122, hy, 28)
		local hutX, hutZ = 122, 28
		table.insert(reservedSpots, { hutX, hutZ, 28 })
		group("FisherHut", function()
			currentParent:SetAttribute("OnTerrain", true)
			local iceTop = if field then field.LiquidLevel else -1.2
			local hy = math.max(groundAt16(hutX, hutZ) - 1.4, iceTop - 0.35)
			local hutYaw = math.atan2(sanctX - hutX, sanctZ - hutZ)
			local hcf = CFrame.new(hutX, hy, hutZ) * CFrame.Angles(0, hutYaw, 0)
			if KitProps.Has("FisherHut") then
				local mdl = kitAt("FisherHut", hcf, 1.52 * scale, {
					STONE = f16Override.STONE,
					MOSS = f16Override.MOSS,
					WOOD = f16Override.WOOD,
					ALT = f16Override.ALT,
					GLOW = { Color = cWarmGlow, Material = Enum.Material.Neon },
				})
				local gp = mdl and mdl:FindFirstChild("GLOW")
				if gp then pointLight(gp, cWarmGlow, 0.95, 36) end
			else
				local baseCF = CFrame.new(origin + V(hutX, hy, hutZ)) * CFrame.Angles(0, hutYaw, 0)
				-- Timber jetty dock & pilings driven cleanly into the shoreline snow/ice (no grey slab)
				local dock = block("FisherDockDeck", V(25.0, 1.1, 20.5), V(hutX, hy + 2.8, hutZ), cTimber, Enum.Material.Wood)
				dock.CFrame = baseCF * CFrame.new(0, 2.8, 0)
				for _, px in { -10.2, 0, 10.2 } do
					for _, pz in { -8.4, 8.4 } do
						local pier = block("FisherDockPiling", V(1.9, 5.2, 1.9), V(hutX, hy + 0.5, hutZ), cGranite, Enum.Material.Slate)
						pier.CFrame = baseCF * CFrame.new(px, 0.5, pz)
					end
				end
				-- Boarded cabin, front door & windows (+Z facing Sanctuary), stove flue & thick snow roof
				local cabin = block("FisherCabin", V(20.6, 10.2, 16.0), V(hutX, hy + 8.4, hutZ), cTimber, Enum.Material.Wood)
				cabin.CFrame = baseCF * CFrame.new(0, 8.4, -0.8)
				local door = block("FisherDoor", V(4.4, 7.2, 0.7), V(hutX, hy + 7.2, hutZ), rgb(72, 56, 44), Enum.Material.Wood)
				door.CFrame = baseCF * CFrame.new(-3.6, 7.2, 7.3)
				for _, winSpec in { { 4.2, 8.6, 7.3, 0 }, { -10.4, 8.6, -0.8, math.pi * 0.5 } } do
					local wPart = block("FisherWarmWindow", V(3.4, 3.2, 0.6), V(hutX, hy + 8.6, hutZ), cWarmGlow, Enum.Material.Neon)
					wPart.CFrame = baseCF * CFrame.new(winSpec[1], winSpec[2], winSpec[3]) * CFrame.Angles(0, winSpec[4], 0)
					if winSpec[4] == 0 then pointLight(wPart, cWarmGlow, 0.95, 36) end
				end
				local roofL = block("FisherCabinSnowRoofL", V(15.4, 1.7, 20.0), V(hutX, hy + 15.8, hutZ), cSnow, Enum.Material.Snow)
				roofL.CFrame = baseCF * CFrame.new(-5.7, 15.6, -0.8) * CFrame.Angles(0, 0, math.rad(34))
				local roofR = block("FisherCabinSnowRoofR", V(15.4, 1.7, 20.0), V(hutX, hy + 15.8, hutZ), cSnow, Enum.Material.Snow)
				roofR.CFrame = baseCF * CFrame.new(5.7, 15.6, -0.8) * CFrame.Angles(0, 0, math.rad(-34))
				local ridge = block("FisherRoofSnowRidge", V(3.2, 1.5, 20.0), V(hutX, hy + 19.6, hutZ), cSnow, Enum.Material.Snow)
				ridge.CFrame = baseCF * CFrame.new(0, 19.6, -0.8)
				local flue = block("FisherStoveFlue", V(2.1, 7.4, 2.1), V(hutX, hy + 18.8, hutZ), cGraniteDark, Enum.Material.Slate)
				flue.CFrame = baseCF * CFrame.new(4.8, 18.8, -4.6)
				-- Twin fishing-net drying racks flanking sides clear of front (+Z) door/window
				for _, rSpec in { { -16.0, -2.0, 0.0 }, { 16.0, -2.0, 0.0 } } do
					local rCF = baseCF * CFrame.new(rSpec[1], 0, rSpec[2]) * CFrame.Angles(0, rSpec[3], 0)
					local net = block("FisherNetCloth", V(0.4, 5.8, 9.6), V(hutX, hy + 5.4, hutZ), rgb(118, 124, 132), Enum.Material.Fabric)
					net.CFrame = rCF * CFrame.new(0, 5.4, 0)
					local topBar = block("FisherNetBeam", V(0.7, 0.7, 11.4), V(hutX, hy + 8.6, hutZ), cTimber, Enum.Material.Wood)
					topBar.CFrame = rCF * CFrame.new(0, 8.6, 0)
					for _, rz in { -5.2, 5.2 } do
						local leg = block("FisherNetPost", V(0.7, 9.0, 0.7), V(hutX, hy + 4.4, hutZ), cTimber, Enum.Material.Wood)
						leg.CFrame = rCF * CFrame.new(0, 4.4, rz)
					end
				end
				-- Twin parallel wooden rowboats resting along the lakeside snow/ice
				for _, bOff in { { -19.0, -8.0, -0.45 }, { -25.0, -11.5, -0.52 } } do
					local boatPos = V(hutX + bOff[1], lakeY + 0.8, hutZ + bOff[2])
					local bCF = CFrame.new(origin + boatPos) * CFrame.Angles(0, bOff[3], 0)
					local hull = block("FisherRowboatHull", V(4.0, 1.8, 12.2), boatPos, cTimber, Enum.Material.Wood)
					hull.CFrame = bCF
					local thwart = block("FisherRowboatSeat", V(3.4, 0.4, 1.4), boatPos, rgb(138, 142, 148), Enum.Material.Wood)
					thwart.CFrame = bCF * CFrame.new(0, 1.1, 0)
					local bow = block("FisherRowboatBowTip", V(2.4, 1.7, 2.4), boatPos, cTimber, Enum.Material.Wood)
					bow.CFrame = bCF * CFrame.new(0, 0.05, -6.1) * CFrame.Angles(0, math.rad(45), 0)
				end
			end
		end)

		-- Snow-laden evergreen pines framing both shorelines behind the Lodge and Fisher's Hut
		for _, pine in {
			{ -146, 54, 0.95 },
			{ -146, 28, 1.05 },
			{ -140, -52, 0.92 },
			{ 146, 54, 1.00 },
			{ 148, 22, 1.08 },
		} do
			local px, pz, psc = pine[1], pine[2], pine[3]
			local py = groundAt16(px, pz) - 0.6
			table.insert(reservedSpots, { px, pz, 8 })
			if kitOn then
				group("ShorePine", function()
					local pineAt = V(px, py, pz)
					kitAt("PineTree", CFrame.new(pineAt) * CFrame.Angles(0, yawAt(pineAt), 0), psc * scale)
				end)
			else
				tree(V(px, py, pz), psc * scale, false, false)
			end
		end

		-- 4. Scattered Frozen Lake Ice Floe Slabs + Heart Floe stone cairn & ice-fishing holes
		for flIdx, fl in { { -24, -58, 0.4, 0.92 }, { 10, -24, -0.35, 0.86 }, { 114, -88, 0.65, 0.90 } } do
			local fx, fz, fyaw, fsc = fl[1], fl[2], fl[3], fl[4]
			table.insert(reservedSpots, { fx, fz, 16 })
			group("IceFloeSlab", function()
				currentParent:SetAttribute("OnTerrain", true)
				local fcf = CFrame.new(fx, lakeY - 1.2, fz) * CFrame.Angles(0, fyaw, 0)
				if KitProps.Has("IceFloeSlab") then
					kitAt("IceFloeSlab", fcf, fsc * scale, f16Override)
				else
					block("OffRouteIceFloe", V(22 * fsc, 2.8, 18 * fsc), V(fx, lakeY + 0.4, fz), cGlacier, Enum.Material.Glacier)
					block("OffRouteFloeSnow", V(18 * fsc, 0.9, 14 * fsc), V(fx, lakeY + 1.9, fz), cSnow, Enum.Material.Snow)
				end
			end)
		end

		-- Heart Floe (Crossing 60, 4, -50) north-west corner cairn + lakeside ice-fishing holes clear of bridge landings
		local hf = layout.Platforms.Crossing
		group("HeartFloeCairn", function()
			currentParent:SetAttribute("OnTerrain", true)
			local cx, cy, cz = 36, hf.Y, -68
			for cStep = 1, 4 do
				local cr = 2.4 - (cStep - 1) * 0.5
				cyl("HeartFloeCairnStone", V(cx, cy + (cStep - 0.5) * 0.85, cz), cr, 0.85, if cStep % 2 == 0 then cGranite else cGraniteDark, Enum.Material.Slate)
			end
		end)
		for _, holePos in { { 88, -66 }, { 28, -66 } } do
			group("IceFishingHole", function()
				currentParent:SetAttribute("OnTerrain", true)
				local hx, hz = holePos[1], holePos[2]
				cyl("IceFishingHoleRing", V(hx, lakeY + 0.12, hz), 3.6, 0.25, cSnow, Enum.Material.Snow)
				cyl("IceFishingHoleWater", V(hx, lakeY + 0.16, hz), 2.3, 0.25, rgb(28, 66, 98), Enum.Material.Ice)
			end)
		end

	elseif biome == "frozen_citadel" and layout.Authored == "frozen:2" then
		-- Floor 17, Frozen Barracks: Stillcold caught the Whiteguard garrison mid-drill on the Parade Ground.
		local cGranite = rgb(104, 116, 130)
		local cGraniteDark = rgb(72, 82, 96)
		local cSnow = rgb(236, 244, 254)
		local cGlacier = rgb(148, 214, 246)
		local cTimber = rgb(90, 72, 58)
		local cIron = rgb(54, 60, 70)
		local cBanner = rgb(138, 174, 206)
		local cFrostGlow = rgb(146, 228, 255)
		local cWarmWin = rgb(255, 208, 132)
		local groundAt17 = function(x: number, z: number): number
			for _, plat in layout.Platforms do
				if math.abs(x - plat.X) <= plat.Width * 0.5 + 3 and math.abs(z - plat.Z) <= plat.Depth * 0.5 + 3 then
					return plat.Y
				end
			end
			return if field then math.max(field.Height(x, z) + 2.0, bottom) else bottom
		end
		local f17Override = {
			STONE = { Color = cGranite, Material = Enum.Material.Slate },
			MOSS = { Color = cSnow, Material = Enum.Material.Snow },
			CRYSTAL = { Color = cGlacier, Material = Enum.Material.Ice, Transparency = 0.24 },
			GLOW = { Color = cFrostGlow, Material = Enum.Material.Neon },
			WOOD = { Color = cTimber, Material = Enum.Material.Wood },
			METAL = { Color = cIron, Material = Enum.Material.Metal },
			TRIM = { Color = cBanner, Material = Enum.Material.Fabric },
		}

		local function placeBarracks(tagName: string, bx: number, by: number, bz: number, yaw: number, bScale: number, hasLight: boolean)
			table.insert(reservedSpots, { bx, bz, 24 })
			group(tagName, function()
				currentParent:SetAttribute("OnTerrain", true)
				local bcf = CFrame.new(bx, by, bz) * CFrame.Angles(0, yaw, 0)
				if KitProps.Has("BarracksBlock") then
					local ov = table.clone(f17Override)
					ov.GLOW = { Color = cWarmWin, Material = Enum.Material.Neon }
					local mdl = kitAt("BarracksBlock", bcf, bScale, ov)
					if hasLight then
						local gp = mdl and mdl:FindFirstChild("GLOW")
						if gp then pointLight(gp, cWarmWin, 0.85, 34) end
					end
				else
					local sc = bScale / scale
					local baseCF = CFrame.new(origin + V(bx, by, bz)) * CFrame.Angles(0, yaw, 0)
					local body = block("BarracksBody", V(32 * sc, 12.5 * sc, 20 * sc), V(bx, by + 6.0 * sc, bz), cGranite, Enum.Material.Slate)
					body.CFrame = baseCF * CFrame.new(0, 6.0 * sc, 0)
					local porch = block("BarracksPorch", V(9.5 * sc, 13.0 * sc, 3.0 * sc), V(bx, by + 6.0 * sc, bz), cGraniteDark, Enum.Material.Slate)
					porch.CFrame = baseCF * CFrame.new(0, 6.0 * sc, 10.6 * sc)
					local door = block("BarracksDoor", V(4.4 * sc, 7.6 * sc, 0.6 * sc), V(bx, by + 4.4 * sc, bz), cTimber, Enum.Material.Wood)
					door.CFrame = baseCF * CFrame.new(0, 4.4 * sc, 12.1 * sc)
					local banner = block("BarracksBanner", V(2.6 * sc, 5.2 * sc, 0.35 * sc), V(bx, by + 11.2 * sc, bz), cBanner, Enum.Material.Fabric)
					banner.CFrame = baseCF * CFrame.new(0, 11.2 * sc, 12.3 * sc)
					-- Seal gable triangles front and back
					for _, sz in { -9.4 * sc, 9.4 * sc } do
						local g1 = block("BarracksGableFill", V(22 * sc, 4.2 * sc, 1.4 * sc), V(bx, by + 14.4 * sc, bz), cGranite, Enum.Material.Slate)
						g1.CFrame = baseCF * CFrame.new(0, 14.4 * sc, sz)
						local g2 = block("BarracksGablePeak", V(11 * sc, 3.8 * sc, 1.4 * sc), V(bx, by + 18.2 * sc, bz), cGranite, Enum.Material.Slate)
						g2.CFrame = baseCF * CFrame.new(0, 18.2 * sc, sz)
					end
					for _, side in { -1, 1 } do
						local roof = block("BarracksSlateRoof", V(21.0 * sc, 1.3 * sc, 24.0 * sc), V(bx, by + 17.5 * sc, bz), cGraniteDark, Enum.Material.Slate)
						roof.CFrame = baseCF * CFrame.new(side * 8.2 * sc, 17.4 * sc, 0) * CFrame.Angles(0, 0, -side * 0.62)
						local snowDrift = block("BarracksRoofSnow", V((if side > 0 then 19.5 else 15.0) * sc, 1.2 * sc, 23.8 * sc), V(bx, by + 18.4 * sc, bz), cSnow, Enum.Material.Snow)
						snowDrift.CFrame = baseCF * CFrame.new(side * 8.2 * sc, 18.4 * sc, 0) * CFrame.Angles(0, 0, -side * 0.62)
					end
					local win = block("BarracksWindowGlow", V(2.4 * sc, 3.6 * sc, 0.45 * sc), V(bx, by + 7.0 * sc, bz), cWarmWin, Enum.Material.Neon)
					win.CFrame = baseCF * CFrame.new(10.5 * sc, 7.0 * sc, 10.2 * sc)
					if hasLight then pointLight(win, cWarmWin, 0.85, 34) end
				end
			end)
		end

		local function placeSoldier(sx: number, sy: number, sz: number, yaw: number, sScale: number)
			table.insert(reservedSpots, { sx, sz, 4 })
			group("FrozenSoldier", function()
				currentParent:SetAttribute("OnTerrain", true)
				local scf = CFrame.new(sx, sy, sz) * CFrame.Angles(0, yaw, 0)
				if KitProps.Has("FrozenSoldier") then
					kitAt("FrozenSoldier", scf, sScale, f17Override)
				else
					local baseCF = CFrame.new(origin + V(sx, sy, sz)) * CFrame.Angles(0, yaw, 0)
					local iceShell = block("FrozenSoldierIceColumn", V(3.4, 7.2, 3.0), V(sx, sy + 3.6, sz), cGlacier, Enum.Material.Ice, nil, 0.26)
					iceShell.CFrame = baseCF * CFrame.new(0, 3.6, 0)
					local armorCore = block("FrozenSoldierArmor", V(1.8, 5.2, 1.3), V(sx, sy + 3.0, sz), cIron, Enum.Material.Metal)
					armorCore.CFrame = baseCF * CFrame.new(0, 3.0, 0)
					local pike = block("FrozenSoldierSpear", V(0.32, 8.2, 0.32), V(sx, sy + 4.1, sz), cIron, Enum.Material.Metal)
					pike.CFrame = baseCF * CFrame.new(1.2, 4.1, 0.2)
				end
			end)
		end

		local function placeIceBrazier(bx: number, by: number, bz: number, lit: boolean)
			table.insert(reservedSpots, { bx, bz, 6 })
			group("IceBrazier", function()
				currentParent:SetAttribute("OnTerrain", true)
				local bcf = CFrame.new(bx, by, bz)
				if KitProps.Has("IceBrazier") then
					local mdl = kitAt("IceBrazier", bcf, 1.05 * scale, f17Override)
					if lit then
						local gp = mdl and (mdl:FindFirstChild("GLOW") or mdl:FindFirstChildWhichIsA("BasePart"))
						if gp then pointLight(gp, cFrostGlow, 0.85, 28) end
					end
				else
					block("IceBrazierBasket", V(3.4, 2.8, 3.4), V(bx, by + 2.2, bz), cIron, Enum.Material.Metal)
					local crystalCore = block("IceBrazierCrystalFlame", V(2.1, 3.0, 2.1), V(bx, by + 4.4, bz), cGlacier, Enum.Material.Ice, nil, 0.14)
					if lit then pointLight(crystalCore, cFrostGlow, 0.85, 28) end
				end
			end)
		end

		-- 1. Parade Ground Frozen Drill Company (12 Whiteguard soldiers encased in ice ranks on the left parade avenue)
		for row = 0, 2 do
			for col = 0, 3 do
				local sx = -52 + col * 7.2 + (row % 2) * 1.4
				local sz = 128 + row * 8.0
				placeSoldier(sx, groundAt17(sx, sz) - 0.15, sz, -0.18, 0.96 * scale)
			end
		end

		-- 2. Barracks wings flanking the Parade Ground entrance and framing the Armory-to-Apex grand stairs
		placeBarracks("ParadeBarracksW", -90, 0, 156, math.pi * 0.45, 1.16 * scale, true)
		placeBarracks("ParadeBarracksE", 90, 0, 156, -math.pi * 0.45, 1.16 * scale, true)
		placeBarracks("WestYardBarracks", -186, 6, -4, math.pi * 0.50, 1.18 * scale, false)
		placeBarracks("EastYardBarracks", 186, 6, -4, -math.pi * 0.50, 1.18 * scale, false)
		placeBarracks("ArmoryFlankBarracksW", -60, 10, -112, 0.14, 1.12 * scale, true)
		placeBarracks("ArmoryFlankBarracksE", 60, 10, -112, -0.14, 1.12 * scale, true)

		-- 3. East Barracks & Kennels: Hound kennel run with iron cages & rigid frozen chains mid-swing
		local knX, knZ = 148, 48
		table.insert(reservedSpots, { knX, knZ, 18 })
		group("KennelRow", function()
			currentParent:SetAttribute("OnTerrain", true)
			local ky = groundAt17(knX, knZ) - 0.3
			local kcf = CFrame.new(knX, ky, knZ) * CFrame.Angles(0, -math.pi * 0.25, 0)
			if KitProps.Has("KennelRow") then
				kitAt("KennelRow", kcf, 1.08 * scale, f17Override)
			else
				local baseCF = CFrame.new(origin + V(knX, ky, knZ)) * CFrame.Angles(0, -math.pi * 0.25, 0)
				local backWall = block("KennelStoneBack", V(22, 8.2, 2.0), V(knX, ky + 4.1, knZ), cGraniteDark, Enum.Material.Slate)
				backWall.CFrame = baseCF * CFrame.new(0, 4.1, -4.4)
				local roof = block("KennelRoofSnow", V(23, 1.2, 12.0), V(knX, ky + 9.2, knZ), cSnow, Enum.Material.Snow)
				roof.CFrame = baseCF * CFrame.new(0, 9.2, 0) * CFrame.Angles(math.rad(14), 0, 0)
				for _, cx in { -6.5, 0, 6.5 } do
					local bars = block("KennelCageBars", V(5.2, 6.0, 0.4), V(knX, ky + 3.4, knZ), cIron, Enum.Material.Metal)
					bars.CFrame = baseCF * CFrame.new(cx, 3.4, 4.4)
				end
				local chain = beam("FrozenKennelChain", V(knX - 11, ky + 4.5, knZ + 5), V(knX - 7, ky + 2.8, knZ + 7), 0.32, cIron, Enum.Material.Metal)
				chain.CanCollide = false
			end
		end)

		-- West Barracks frozen bunkhouse yard props (wooden bunk frame & footlockers on outer edge clear of camp)
		group("WestBarracksYardProps", function()
			currentParent:SetAttribute("OnTerrain", true)
			for k = 0, 1 do
				local cx, cz = -160, 22 + k * 9
				block("FrozenFootlocker", V(4.6, 2.2, 2.8), V(cx, 6 + 1.1, cz), cTimber, Enum.Material.Wood)
				block("FootlockerFrostCap", V(4.8, 0.35, 3.0), V(cx, 6 + 2.3, cz), cSnow, Enum.Material.Snow)
			end
		end)

		-- 4. Crossing (Mess Hall 0, 4, -10): soup cauldron frozen mid-boil + long timber mess tables in clear NW/NE corners
		local mh = layout.Platforms.Crossing
		table.insert(reservedSpots, { mh.X - 30, mh.Z - 24, 8 })
		group("MessCauldron", function()
			currentParent:SetAttribute("OnTerrain", true)
			local cx, cy, cz = mh.X - 30, mh.Y, mh.Z - 24
			local ccf = CFrame.new(cx, cy, cz) * CFrame.Angles(0, 0.35, 0)
			if KitProps.Has("MessCauldron") then
				kitAt("MessCauldron", ccf, 1.05 * scale, f17Override)
			else
				cyl("MessCauldronPot", V(cx, cy + 2.6, cz), 3.0, 4.4, cIron, Enum.Material.Metal)
				for bIdx = 1, 5 do
					local ang = bIdx * math.pi * 2 / 5
					orb("FrozenBoilBubble", V(cx + math.cos(ang) * 1.4, cy + 5.1, cz + math.sin(ang) * 1.4), V(1.6, 1.6, 1.6), cGlacier, Enum.Material.Ice, 0.12)
				end
			end
		end)
		group("MessHallTables", function()
			currentParent:SetAttribute("OnTerrain", true)
			local tx, ty, tz = mh.X + 30, mh.Y, mh.Z - 24
			block("MessTableTop", V(10.0, 0.7, 4.0), V(tx, ty + 2.4, tz), cTimber, Enum.Material.Wood)
			block("MessTableSnowCap", V(9.6, 0.3, 3.6), V(tx, ty + 2.9, tz), cSnow, Enum.Material.Snow)
			for _, sx in { -3.8, 3.8 } do
				block("MessTableLeg", V(0.8, 2.2, 3.4), V(tx + sx, ty + 1.1, tz), cTimber, Enum.Material.Wood)
			end
		end)

		-- 5. Armory weapon racks with Ward-Star shields tucked in North corners of Armory (0, 10, -96)
		local arm = layout.Platforms.Armory
		for _, s in { -1, 1 } do
			group("ArmoryWeaponRack", function()
				currentParent:SetAttribute("OnTerrain", true)
				local rx, ry, rz = arm.X + s * 26, arm.Y, arm.Z - 16
				block("ArmoryRackBar", V(6.4, 0.55, 0.55), V(rx, ry + 4.4, rz), cTimber, Enum.Material.Wood)
				for _, pOff in { -2.6, 2.6 } do
					block("ArmoryRackPost", V(0.65, 4.8, 0.65), V(rx + pOff, ry + 2.4, rz), cTimber, Enum.Material.Wood)
				end
				for _, sOff in { -1.5, 1.5 } do
					local sh = block("ArmoryWardShield", V(2.0, 2.8, 0.45), V(rx + sOff, ry + 1.9, rz + 0.6), cGranite, Enum.Material.Slate)
					sh.CFrame = CFrame.new(origin + V(rx + sOff, ry + 1.9, rz + 0.6)) * CFrame.Angles(math.rad(-14), 0, 0)
				end
			end)
		end

		-- 6. Iron street ice braziers lining the Parade Ground avenue outside the 40-stud causeway and stair foot
		for _, bz in { { -28, 0, 152, true }, { 28, 0, 152, true }, { -22, 10, -124, true }, { 22, 10, -124, true } } do
			placeIceBrazier(bz[1], bz[2], bz[3], bz[4])
		end

		-- 7. Commander's Hall War Table sealed under ice on Apex side wing (clear of boss camp & portal spots)
		group("CommanderWarTable", function()
			currentParent:SetAttribute("OnTerrain", true)
			local wtX, wtY, wtZ = 42, apex.Y, apex.Z + 12
			block("WarTablePedestal", V(9.0, 2.4, 5.6), V(wtX, wtY + 1.2, wtZ), cGraniteDark, Enum.Material.Slate)
			block("WarTableTop", V(11.0, 0.8, 6.8), V(wtX, wtY + 2.8, wtZ), cTimber, Enum.Material.Wood)
			block("WarTableIceSeal", V(11.6, 1.4, 7.4), V(wtX, wtY + 3.6, wtZ), cGlacier, Enum.Material.Ice, nil, 0.25)
		end)
	elseif biome == "frozen_citadel" and layout.Authored == "frozen:3" then
		-- Floor 18 (Shattered Iceway): glacier spine strata & icicle walls, frozen supply cart atop crevasse ice pillar,
		-- towering forward-leaning glacier seracs on East Moraine, collapsed West Moraine toll shelter, and tilted road shrine.
		local cGranite = rgb(98, 112, 128)
		local cGraniteDark = rgb(62, 72, 86)
		local cTimber = rgb(88, 68, 50)
		local cIron = rgb(44, 48, 56)
		local cSnow = rgb(236, 244, 254)
		local cGlacier = rgb(146, 206, 238)
		local cGlacierDeep = rgb(64, 108, 148)
		local cRimeGlow = rgb(142, 224, 255)

		local function minFootY(x: number, z: number, reach: number, fallbackY: number): number
			if not field then return fallbackY end
			local h = field.Height(x, z)
			if reach > 0 then
				h = math.min(
					h,
					field.Height(x + reach, z),
					field.Height(x - reach, z),
					field.Height(x, z + reach),
					field.Height(x, z - reach)
				)
			end
			return h + 0.9
		end

		-- 1. CrevasseCartPillar: Frozen Moment supply coach pitched mid-fall off Crossing's SW lip into the West Crevasse
		local cartPos = V(-48, math.min(bottom, minFootY(-48, 26, 3.5, bottom - 1.0)), 26)
		group("CrevasseCartPillar", function()
			currentParent:SetAttribute("OnTerrain", true)
			if KitProps.Has("CrevasseCartPillar") then
				local mdl = kitAt("CrevasseCartPillar", CFrame.new(cartPos) * CFrame.Angles(0, math.rad(34), 0), 1.28 * scale, {
					CRYSTAL = { Color = cGlacier, Material = Enum.Material.Ice, Transparency = 0.1 },
					WOOD = { Color = cTimber, Material = Enum.Material.Wood },
					METAL = { Color = cIron, Material = Enum.Material.Metal },
					MOSS = { Color = cSnow, Material = Enum.Material.Snow },
					STONE = { Color = cGraniteDark, Material = Enum.Material.Slate },
				})
				local cp = mdl and mdl:FindFirstChildWhichIsA("BasePart")
				if cp then pointLight(cp, cRimeGlow, 1.0, 38) end
			else
				local col = cyl("FrozenCartColumn", cartPos + V(0, 10.5, 0), 3.8, 22, cGlacier, Enum.Material.Ice, 0.12)
				pointLight(col, cRimeGlow, 1.0, 38)
				for _, ic in { { -2.4, 1.2, 16 }, { 2.2, -1.4, 15 }, { 0.4, 2.3, 18 } } do
					cyl("CartIceRib", cartPos + V(ic[1], ic[3] * 0.5, ic[2]), 1.1, ic[3], rgb(174, 224, 250), Enum.Material.Ice, 0.1)
				end
				local pitch = CFrame.new(origin + cartPos + V(0, 21.5, 0)) * CFrame.Angles(math.rad(-36), math.rad(34), 0)
				local bed = block("FrozenCartBed", V(6.4, 1.2, 10.2), cartPos + V(0, 21.5, 0), cTimber, Enum.Material.Wood)
				bed.CFrame = pitch
				local hood = block("FrozenCartHood", V(5.8, 3.6, 9.2), cartPos + V(0, 24.0, 0), cTimber, Enum.Material.Wood)
				hood.CFrame = pitch * CFrame.new(0, 2.2, 0)
				for _, sx in { -3.5, 3.5 } do
					for _, sz in { -3.0, 3.0 } do
						local wh = cyl("FrozenCartWheel", cartPos, 2.1, 0.65, cIron, Enum.Material.Metal)
						wh.CFrame = pitch * CFrame.new(sx, -0.8, sz) * CFrame.Angles(0, 0, math.pi * 0.5)
					end
				end
			end
		end)

		-- 2. Towering forward-leaning Glacier Serac Clusters (multi-point grounded so zero spikes float on slopes; normal to colossal sizes)
		local seracSpots = {
			-- Colossal (56..66 studs tall) framing East Moraine & the Icefall Gate valley
			{ x = 186, y = 4, z = -34, yaw = math.rad(-22), s = 1.92 * scale, light = true },
			{ x = 182, y = 4, z = -104, yaw = math.rad(-30), s = 2.15 * scale, light = false },
			{ x = 104, y = 0, z = -160, yaw = math.rad(-38), s = 2.02 * scale, light = false },
			{ x = -124, y = 0, z = -170, yaw = math.rad(42), s = 2.08 * scale, light = false },
			-- Medium / tall (35..46 studs) framing crevasse walls & upper spine
			{ x = 96, y = bottom, z = 22, yaw = math.rad(-24), s = 1.24 * scale, light = false },
			{ x = -92, y = bottom, z = 32, yaw = math.rad(24), s = 1.18 * scale, light = false },
			{ x = 76, y = bottom, z = -126, yaw = math.rad(-28), s = 1.32 * scale, light = false },
			{ x = -104, y = 0, z = -152, yaw = math.rad(36), s = 1.26 * scale, light = false },
			-- Normal (20..28 studs) jagged ice teeth along moraine rims & foreground chasm lips
			{ x = 62, y = 0, z = 44, yaw = math.rad(-32), s = 0.74 * scale, light = false },
			{ x = -62, y = 0, z = 48, yaw = math.rad(26), s = 0.68 * scale, light = false },
			{ x = -182, y = 8, z = -14, yaw = math.rad(20), s = 0.86 * scale, light = false },
			{ x = 138, y = 4, z = -114, yaw = math.rad(-40), s = 0.78 * scale, light = false },
		}
		for _, sc in seracSpots do
			local sy = minFootY(sc.x, sc.z, 5.5 * sc.s, sc.y)
			local leanSign = if sc.x >= 0 then 1 else -1
			group("SeracCluster", function()
				currentParent:SetAttribute("OnTerrain", true)
				if KitProps.Has("SeracCluster") then
					local mdl = kitAt("SeracCluster", CFrame.new(sc.x, sy, sc.z) * CFrame.Angles(0, sc.yaw, 0), sc.s, {
						CRYSTAL = { Color = cGlacier, Material = Enum.Material.Ice, Transparency = 0.08 },
						MOSS = { Color = cSnow, Material = Enum.Material.Snow },
						STONE = { Color = cGraniteDark, Material = Enum.Material.Slate },
						GLOW = { Color = cRimeGlow, Material = Enum.Material.Neon },
					})
					local gp = sc.light and mdl and mdl:FindFirstChildWhichIsA("BasePart")
					if gp then pointLight(gp, cRimeGlow, 1.1, 44) end
				else
					local blades = { { 0, 36 * sc.s, 4.0, 0.28 }, { -4.4 * leanSign, 27 * sc.s, 3.2, 0.22 }, { 4.0 * leanSign, 21 * sc.s, 2.6, 0.32 } }
					for bi, b in blades do
						local sp = block("GlacierSeracBlade", V(b[3], b[2], b[3] * 0.9), V(sc.x + b[1], sy + b[2] * 0.45, sc.z), if bi == 1 then cGlacier else rgb(168, 220, 246), Enum.Material.Ice, nil, 0.1)
						sp.CFrame = CFrame.new(origin + V(sc.x + b[1], sy + b[2] * 0.45, sc.z)) * CFrame.Angles(math.rad(-8), sc.yaw, b[4] * leanSign)
						if sc.light and bi == 1 then pointLight(sp, cRimeGlow, 1.1, 44) end
					end
				end
			end)
		end

		-- 2b. Wind-blasted leafless FrozenBareTree snags framing Moraine Foot, outer moraines, and north approaches
		local bareTreeSpots = {
			-- Moraine Foot outer west snowbanks
			{ x = -142, z = 178, yaw = 0.4, s = 1.16 * scale },
			{ x = -168, z = 162, yaw = 1.3, s = 1.34 * scale },
			{ x = -156, z = 142, yaw = 2.2, s = 0.92 * scale },
			{ x = -174, z = 108, yaw = -0.6, s = 1.20 * scale },
			{ x = -154, z = 88, yaw = 2.8, s = 0.80 * scale },
			-- Moraine Foot outer east snowbanks
			{ x = 142, z = 178, yaw = -0.7, s = 1.14 * scale },
			{ x = 168, z = 164, yaw = -1.5, s = 1.32 * scale },
			{ x = 156, z = 142, yaw = -2.4, s = 0.90 * scale },
			{ x = 174, z = 108, yaw = 0.9, s = 1.18 * scale },
			{ x = 154, z = 88, yaw = 1.5, s = 0.82 * scale },
			-- West Moraine cliffs & north-west gate approaches
			{ x = -194, z = -72, yaw = 0.9, s = 1.06 * scale },
			{ x = -188, z = -104, yaw = 2.1, s = 0.84 * scale },
			{ x = -164, z = -140, yaw = -0.8, s = 1.22 * scale },
			{ x = -134, z = -150, yaw = 1.4, s = 0.88 * scale },
			{ x = -86, z = -194, yaw = 0.5, s = 1.12 * scale },
			{ x = -96, z = -214, yaw = 1.9, s = 0.90 * scale },
			-- East Moraine cliffs & north-east gate approaches
			{ x = 192, z = -74, yaw = -1.1, s = 1.04 * scale },
			{ x = 188, z = -118, yaw = -1.8, s = 0.92 * scale },
			{ x = 158, z = -142, yaw = 0.7, s = 1.26 * scale },
			{ x = 128, z = -172, yaw = -2.5, s = 0.86 * scale },
			{ x = 86, z = -194, yaw = -0.8, s = 1.10 * scale },
			{ x = 98, z = -214, yaw = -1.6, s = 0.88 * scale },
		}
		for _, bt in bareTreeSpots do
			local ty = minFootY(bt.x, bt.z, 3.2 * bt.s, 0)
			group("FrozenBareTree", function()
				currentParent:SetAttribute("OnTerrain", true)
				if KitProps.Has("FrozenBareTree") then
					kitAt("FrozenBareTree", CFrame.new(bt.x, ty, bt.z) * CFrame.Angles(0, bt.yaw, 0), bt.s, {
						WOOD = { Color = rgb(74, 62, 54), Material = Enum.Material.Wood },
						MOSS = { Color = cSnow, Material = Enum.Material.Snow },
						CRYSTAL = { Color = cGlacier, Material = Enum.Material.Ice, Transparency = 0.1 },
					})
				else
					local ts = bt.s
					local trunk = cyl("BareTreeTrunk", V(bt.x, ty + 10 * ts, bt.z), 1.2 * ts, 22 * ts, rgb(74, 62, 54), Enum.Material.Wood)
					trunk.CFrame = CFrame.new(origin + V(bt.x, ty + 10 * ts, bt.z)) * CFrame.Angles(math.rad(5), bt.yaw, math.rad(-4)) * CFrame.Angles(0, 0, math.pi * 0.5)
					local boughs = {
						{ 0, 9.5, 0, -4.4, 4.2, -1.6, 0.52 },
						{ 0, 12.0, 0, 4.8, 4.4, 1.4, 0.48 },
						{ 0, 15.8, 0, -3.6, 4.0, 2.4, 0.40 },
						{ 0, 17.5, 0, 3.8, 3.6, -2.2, 0.36 },
					}
					for _, bg in boughs do
						local pA = V(bt.x + bg[1] * ts, ty + bg[2] * ts, bt.z + bg[3] * ts)
						local off = CFrame.Angles(0, bt.yaw, 0) * V(bg[4] * ts, bg[5] * ts, bg[6] * ts)
						beam("BareTreeBranch", pA, pA + off, bg[7] * ts, rgb(82, 68, 58), Enum.Material.Wood)
					end
					for _, rz in { 7.5, 13.5 } do
						local ice = block("BareTreeRimeIce", V(0.85 * ts, 3.8 * ts, 0.85 * ts), V(bt.x, ty + rz * ts, bt.z - 0.9 * ts), cGlacier, Enum.Material.Ice, nil, 0.12)
						ice.CFrame = CFrame.new(origin + V(bt.x, ty + rz * ts, bt.z - 0.9 * ts)) * CFrame.Angles(math.rad(-26), bt.yaw, 0)
					end
				end
			end)
		end

		-- 3. GlacierShrine: half-swallowed tilted roadside shrine on Upper Iceway west rim + Moraine Foot Sentinel Shrine
		local shrines = {
			{ x = -28, y = 12, z = -96, yaw = math.rad(16), tilt = math.rad(7), s = 0.86 * scale },
			{ x = 56, y = 0, z = 148, yaw = math.rad(-26), tilt = math.rad(3), s = 0.86 * scale },
		}
		for _, sh in shrines do
			group("GlacierShrine", function()
				currentParent:SetAttribute("OnTerrain", true)
				if KitProps.Has("GlacierShrine") then
					kitAt("GlacierShrine", CFrame.new(sh.x, sh.y, sh.z) * CFrame.Angles(0, sh.yaw, sh.tilt), sh.s, {
						STONE = { Color = cGranite, Material = Enum.Material.Slate },
						TRIM = { Color = rgb(138, 152, 168), Material = Enum.Material.Granite },
						CRYSTAL = { Color = cGlacier, Material = Enum.Material.Ice, Transparency = 0.1 },
						MOSS = { Color = cSnow, Material = Enum.Material.Snow },
						GLOW = { Color = cRimeGlow, Material = Enum.Material.Neon },
					})
				else
					local p = block("GlacierShrinePillar", V(4.8, 10.5, 3.6), V(sh.x, sh.y + 5.2, sh.z), cGranite, Enum.Material.Slate)
					p.CFrame = CFrame.new(origin + V(sh.x, sh.y + 5.2, sh.z)) * CFrame.Angles(0, sh.yaw, sh.tilt)
					block("GlacierShrineIceWedge", V(3.4, 8.2, 3.2), V(sh.x + 2.4, sh.y + 3.8, sh.z), cGlacier, Enum.Material.Ice, nil, 0.12)
				end
			end)
		end

		-- 4. TollShelterRuins: collapsed timber-and-granite tollhouse on West Moraine cliff rim (clear of WestGallery camp & lanes)
		group("TollShelterRuins", function()
			currentParent:SetAttribute("OnTerrain", true)
			local tsX, tsY, tsZ = -196, 8, -28
			if KitProps.Has("TollShelterRuins") then
				kitAt("TollShelterRuins", CFrame.new(tsX, tsY, tsZ) * CFrame.Angles(0, math.rad(72), 0), 0.96 * scale, {
					STONE = { Color = cGranite, Material = Enum.Material.Slate },
					WOOD = { Color = cTimber, Material = Enum.Material.Wood },
					METAL = { Color = cIron, Material = Enum.Material.Metal },
					MOSS = { Color = cSnow, Material = Enum.Material.Snow },
					CRYSTAL = { Color = cGlacier, Material = Enum.Material.Ice, Transparency = 0.12 },
				})
			else
				block("TollShelterWall", V(14, 5.5, 11), V(tsX, tsY + 2.75, tsZ), cGranite, Enum.Material.Slate)
				local roof = block("TollShelterCollapsedRoof", V(15, 1.4, 12), V(tsX + 1, tsY + 7.2, tsZ), cTimber, Enum.Material.Wood)
				roof.CFrame = CFrame.new(origin + V(tsX + 1, tsY + 7.2, tsZ)) * CFrame.Angles(0.18, 0.1, -0.32)
			end
		end)

		-- 5. Foreground Moraine Foot storytelling: half-buried Whiteguard Ward-Star shield (SW) + abandoned bivouac tent & tripod (SE)
		group("WardStarShieldMarker", function()
			currentParent:SetAttribute("OnTerrain", true)
			if KitProps.Has("WardStarShieldMarker") then
				kitAt("WardStarShieldMarker", CFrame.new(-54, 0, 152) * CFrame.Angles(0, math.rad(28), 0), 1.05 * scale, {
					STONE = { Color = cGranite, Material = Enum.Material.Slate },
					CRYSTAL = { Color = cGlacier, Material = Enum.Material.Ice, Transparency = 0.1 },
					MOSS = { Color = cSnow, Material = Enum.Material.Snow },
					METAL = { Color = cIron, Material = Enum.Material.Metal },
				})
			else
				local sh = block("BuriedWardShield", V(6.2, 7.6, 1.2), V(-54, 2.8, 152), cGranite, Enum.Material.Slate)
				sh.CFrame = CFrame.new(origin + V(-54, 2.8, 152)) * CFrame.Angles(math.rad(-22), math.rad(24), math.rad(12))
			end
		end)
		group("MoraineBivouac", function()
			currentParent:SetAttribute("OnTerrain", true)
			local bx, bz = 70, 154
			for _, side in { -1, 1 } do
				local p = block("FrozenBivouacTent", V(6.6, 0.7, 9.2), V(bx + side * 1.9, 2.2, bz), rgb(104, 112, 122), Enum.Material.Fabric)
				p.CFrame = CFrame.new(origin + V(bx + side * 1.9, 2.2, bz)) * CFrame.Angles(0, math.rad(-18), -side * math.rad(42))
			end
			block("FrozenCampRing", V(5.2, 0.9, 5.2), V(bx - 11, 0.45, bz - 4), cGraniteDark, Enum.Material.Rock)
			block("FrozenCampEmberIce", V(2.4, 1.1, 2.4), V(bx - 11, 0.85, bz - 4), cGlacier, Enum.Material.Ice, nil, 0.1)
		end)

		-- 6. Glacier Spine cliff strata flanks (kept strictly clear of walkway lanes)
		local cliffSegments = {
			{ x = -35.8, y = -4, z = 28, h = 9.5, l = 18 },
			{ x = 35.8, y = -4, z = 27, h = 9.5, l = 18 },
			{ x = -32.8, y = -4, z = -96, h = 15.5, l = 44 },
		}
		for _, cs in cliffSegments do
			group("GlacierSpineCliff", function()
				currentParent:SetAttribute("OnTerrain", true)
				block("GlacierStrataRock", V(3.6, cs.h * 0.52, cs.l), V(cs.x, cs.y + cs.h * 0.26, cs.z), cGraniteDark, Enum.Material.Slate)
				block("GlacierStrataIce", V(4.0, cs.h * 0.42, cs.l - 1.5), V(cs.x, cs.y + cs.h * 0.72, cs.z), cGlacier, Enum.Material.Glacier)
			end)
		end
	elseif biome == "frozen_citadel" and layout.Authored == "frozen:4" then
		-- Floor 19 (Whiteguard Keep): Relief army Siege Camp & Battering Ram, Viaduct Gate & Siege Ladder,
		-- East Bailey Trebuchet, great Whiteguard Tower with frozen banner, West Glacier Caves + Rimelight Crystals,
		-- and central Keep Cliff Icefall beneath Keep Hall.
		local cGranite = rgb(104, 118, 134)
		local cGraniteDark = rgb(66, 76, 90)
		local cTimber = rgb(88, 68, 50)
		local cIron = rgb(44, 48, 56)
		local cSnow = rgb(236, 244, 254)
		local cGlacier = rgb(146, 206, 238)
		local cRimelight = rgb(78, 236, 255)
		local cCanvas = rgb(188, 194, 202)
		local cBanner = rgb(44, 88, 136)

		local function minFootY(x: number, z: number, reach: number, fallbackY: number): number
			if not field then return fallbackY end
			local h = field.Height(x, z)
			if reach > 0 then
				h = math.min(
					h,
					field.Height(x + reach, z),
					field.Height(x - reach, z),
					field.Height(x, z + reach),
					field.Height(x, z - reach)
				)
			end
			return h + 0.9
		end

		-- 1. Relief Army Siege Camp tents, pickets & Battering Ram at the Viaduct foot
		local tentSpots = {
			{ x = -156, z = 198, yaw = math.rad(18), s = 1.25 },
			{ x = -158, z = 118, yaw = math.rad(-14), s = 1.15 },
			{ x = -64, z = 192, yaw = math.rad(24), s = 1.22 },
			{ x = -54, z = 144, yaw = math.rad(10), s = 1.18 },
			{ x = 56, z = 188, yaw = math.rad(-20), s = 1.18 },
			{ x = 156, z = 198, yaw = math.rad(-18), s = 1.28 },
		}
		for idx, ts in tentSpots do
			local sc = ts.s
			local ty = math.max(0, if field then field.Height(ts.x, ts.z) + 0.6 else 0.6)
			local tCF = CFrame.new(origin + V(ts.x, ty, ts.z)) * CFrame.Angles(0, ts.yaw, 0)
			group("SiegeTent", function()
				currentParent:SetAttribute("OnTerrain", true)
				local body = block("SiegeTentInterior", V(6.6 * sc, 5.2 * sc, 15.2 * sc), V(ts.x, ty + 2.6 * sc, ts.z), rgb(118, 124, 134), Enum.Material.Fabric)
				body.CFrame = tCF * CFrame.new(0, 2.6 * sc, 0)
				for _, side in { -1, 1 } do
					local roof = block("SiegeTentWall", V(10.6 * sc, 0.7, 16.5 * sc), V(ts.x, ty + 4.4 * sc, ts.z), cCanvas, Enum.Material.Fabric)
					roof.CFrame = tCF * CFrame.new(side * 3.2 * sc, 4.4 * sc, 0) * CFrame.Angles(0, 0, -side * math.rad(48))
				end
				local pole = cyl("SiegeTentRidge", V(ts.x, ty + 8.1 * sc, ts.z), 0.45, 18.0 * sc, cTimber, Enum.Material.Wood)
				pole.CFrame = tCF * CFrame.new(0, 8.1 * sc, 0) * CFrame.Angles(0, math.pi * 0.5, 0)
				local snowCap = block("SiegeTentSnowCap", V(5.4 * sc, 0.85, 15.0 * sc), V(ts.x, ty + 8.0 * sc, ts.z), cSnow, Enum.Material.Snow)
				snowCap.CFrame = tCF * CFrame.new(0, 8.0 * sc, 0)
				if idx % 2 == 1 then
					local flagPost = cyl("SiegeTentBannerPole", V(ts.x, ty + 6.5 * sc, ts.z), 0.35, 13.5 * sc, cTimber, Enum.Material.Wood)
					flagPost.CFrame = tCF * CFrame.new(4.2 * sc, 6.7 * sc, -8.5 * sc) * CFrame.Angles(0, 0, math.pi * 0.5)
					local flag = block("SiegeTentBanner", V(0.35, 4.4, 3.2), V(ts.x, ty + 11.2 * sc, ts.z), cBanner, Enum.Material.Fabric)
					flag.CFrame = tCF * CFrame.new(4.2 * sc, 11.2 * sc, -6.9 * sc)
				end
			end)
		end

		for _, fs in {
			{ x = -68, z = 178, yaw = 0.25 },
			{ x = -56, z = 170, yaw = 0.14 },
			{ x = -58, z = 142, yaw = 0.32 },
			{ x = 42, z = 114, yaw = -0.22 },
			{ x = 56, z = 110, yaw = -0.28 },
			{ x = 66, z = 122, yaw = -0.35 },
			{ x = 54, z = 184, yaw = -0.18 },
			{ x = 64, z = 172, yaw = -0.26 },
		} do
			local sy = math.max(0, minFootY(fs.x, fs.z, 1.8, 0))
			group("FrozenSoldier", function()
				currentParent:SetAttribute("OnTerrain", true)
				if KitProps.Has("FrozenSoldier") then
					kitAt("FrozenSoldier", CFrame.new(fs.x, sy, fs.z) * CFrame.Angles(0, fs.yaw, 0), 1.24 * scale, {
						CRYSTAL = { Color = cGlacier, Material = Enum.Material.Ice, Transparency = 0.16 },
						METAL = { Color = cIron, Material = Enum.Material.Metal },
						STONE = { Color = cGraniteDark, Material = Enum.Material.Slate },
					})
				else
					block("FrozenSoldierBlock", V(4.0, 9.6, 3.2), V(fs.x, sy + 4.8, fs.z), cGlacier, Enum.Material.Ice, nil, 0.18)
				end
			end)
		end

		-- Frozen wheeled Siege Battering Ram halted beside the Viaduct entrance approach
		group("FrozenBatteringRam", function()
			currentParent:SetAttribute("OnTerrain", true)
			local rx, ry, rz = 44, 0, 128
			local ramCF = CFrame.new(origin + V(rx, ry, rz)) * CFrame.Angles(0, math.rad(-14), 0)
			for _, sx in { -5.8, 5.8 } do
				local beam = block("RamFrameBeam", V(1.5, 1.6, 24.5), V(rx, ry + 0.8, rz), cTimber, Enum.Material.Wood)
				beam.CFrame = ramCF * CFrame.new(sx, 1.0, 0)
				for _, sz in { -7.2, 7.2 } do
					local post = block("RamAFramePost", V(1.3, 12.6, 1.3), V(rx, ry + 6.5, rz), cTimber, Enum.Material.Wood)
					post.CFrame = ramCF * CFrame.new(sx * 0.65, 6.5, sz) * CFrame.Angles(0, 0, if sx > 0 then math.rad(22) else math.rad(-22))
					local wh = cyl("RamWheel", V(rx, ry + 2.8, rz), 2.9, 1.1, cIron, Enum.Material.Metal)
					wh.CFrame = ramCF * CFrame.new(sx * 1.15, 2.8, sz)
				end
			end
			local log = cyl("RamTimberLog", V(rx, ry + 6.4, rz), 2.4, 26.5, cTimber, Enum.Material.Wood)
			log.CFrame = ramCF * CFrame.new(0, 6.4, -0.5) * CFrame.Angles(0, math.pi * 0.5, 0)
			local head = block("RamIronHead", V(5.2, 5.2, 4.6), V(rx, ry + 6.4, rz), cIron, Enum.Material.Metal)
			head.CFrame = ramCF * CFrame.new(0, 6.4, -14.5)
			local iceLock = block("RamFrozenIce", V(8.8, 7.2, 8.6), V(rx, ry + 3.6, rz), cGlacier, Enum.Material.Ice, nil, 0.15)
			iceLock.CFrame = ramCF * CFrame.new(0, 3.6, -10.5)
			local snowRoof = block("RamSnowShield", V(9.5, 1.1, 19.5), V(rx, ry + 11.4, rz), cSnow, Enum.Material.Snow)
			snowRoof.CFrame = ramCF * CFrame.new(0, 11.4, 0)
		end)

		-- 2. Grand Walled Barbican Gatehouse & Perimeter Fortress Walls around Crossing (Viaduct Gate)
		group("PortcullisGate", function()
			currentParent:SetAttribute("OnTerrain", true)
			local gx, gy, gz = 31, 8, 39
			local gateCF = CFrame.new(origin + V(gx, gy, gz)) * CFrame.Angles(0, math.rad(-15), 0)
			local function markNS(p: BasePart)
				p:SetAttribute("SolidScenery", false)
				return p
			end
			for _, side in { -1, 1 } do
				local txOff = side * 24.5
				local shaft = markNS(cyl("ViaductGateTowerShaft", V(gx, gy + 21, gz), 7.4, 42, cGranite, Enum.Material.Slate))
				shaft.CFrame = gateCF * CFrame.new(txOff, 21, 0) * CFrame.Angles(0, 0, math.pi * 0.5)
				local plinth = markNS(cyl("ViaductGateTowerBase", V(gx, gy + 4, gz), 8.6, 8, cGraniteDark, Enum.Material.Slate))
				plinth.CFrame = gateCF * CFrame.new(txOff, 4, 0) * CFrame.Angles(0, 0, math.pi * 0.5)
				local crown = markNS(cyl("ViaductGateTowerCrown", V(gx, gy + 43, gz), 8.6, 3.6, cGraniteDark, Enum.Material.Slate))
				crown.CFrame = gateCF * CFrame.new(txOff, 43, 0) * CFrame.Angles(0, 0, math.pi * 0.5)
				local snowRim = markNS(cyl("ViaductGateTowerSnow", V(gx, gy + 45.2, gz), 8.2, 1.0, cSnow, Enum.Material.Snow))
				snowRim.CFrame = gateCF * CFrame.new(txOff, 45.2, 0) * CFrame.Angles(0, 0, math.pi * 0.5)
				for m = 0, 3 do
					local ang = math.rad(m * 90 + 45)
					local mer = markNS(block("ViaductTowerMerlon", V(3.2, 3.2, 3.2), V(gx, gy + 46.8, gz), cGraniteDark, Enum.Material.Slate))
					mer.CFrame = gateCF * CFrame.new(txOff + math.cos(ang) * 6.8, 46.8, math.sin(ang) * 6.8) * CFrame.Angles(0, -ang, 0)
				end
				local slit = markNS(block("ViaductTowerEmbrasure", V(1.4, 7.5, 1.2), V(gx, gy + 26, gz), cRimelight, Enum.Material.Neon))
				slit.CFrame = gateCF * CFrame.new(txOff, 26, 7.4)
				local banner = markNS(block("ViaductGateBanner", V(2.4, 8.2, 0.5), V(gx, gy + 22, gz), cBanner, Enum.Material.Fabric))
				banner.CFrame = gateCF * CFrame.new(side * 16.5, 22, 6.2)
				local ic = markNS(block("ViaductTowerIcicle", V(1.6, 6.2, 1.6), V(gx, gy + 38.5, gz), cGlacier, Enum.Material.Ice, nil, 0.14))
				ic.CFrame = gateCF * CFrame.new(txOff, 38.5, 8.0)
			end
			-- Stepped pointed gatehouse lintel & battlements spanning cleanly over the 32-stud south portal
			local lintel = markNS(block("ViaductGateLintel", V(56, 12.0, 13.5), V(gx, gy + 27.5, gz), cGranite, Enum.Material.Slate))
			lintel.CFrame = gateCF * CFrame.new(0, 27.5, 0)
			local frieze = markNS(block("ViaductGateSnowCrest", V(58, 1.8, 14.2), V(gx, gy + 34.4, gz), cSnow, Enum.Material.Snow))
			frieze.CFrame = gateCF * CFrame.new(0, 34.4, 0)
			for _, hSide in { -1, 1 } do
				local haunch = markNS(block("ViaductGateArchHaunch", V(12, 4.5, 12.5), V(gx, gy + 21.0, gz), cGraniteDark, Enum.Material.Slate))
				haunch.CFrame = gateCF * CFrame.new(hSide * 13.5, 21.0, 0) * CFrame.Angles(0, 0, -hSide * math.rad(34))
			end
			for m = -18, 18, 9 do
				local mer = markNS(block("ViaductGateMerlon", V(4.8, 4.2, 13.8), V(gx, gy + 36.8, gz), cGraniteDark, Enum.Material.Slate))
				mer.CFrame = gateCF * CFrame.new(m, 36.8, 0)
			end
			for pbx = -12, 12, 4 do
				local bar = markNS(block("ViaductPortcullisSpike", V(0.75, 8.4, 0.75), V(gx, gy + 19.5, gz), cIron, Enum.Material.Metal))
				bar.CFrame = gateCF * CFrame.new(pbx, 19.5, 5.2)
			end

			-- Perimeter Curtain Walls & Corner Watch Turrets enclosing Crossing (leaving South, East & West bridge portals open)
			local function addWall(wName: string, wSize: Vector3, pos: Vector3, yawRad: number?, merlonCount: number?)
				local wCF = CFrame.new(origin + pos) * CFrame.Angles(0, yawRad or 0, 0)
				local wall = markNS(block(wName, wSize, pos, cGranite, Enum.Material.Slate))
				wall.CFrame = wCF
				local snow = markNS(block(wName .. "Snow", Vector3.new(wSize.X + 0.8, 1.3, wSize.Z + 0.8), pos, cSnow, Enum.Material.Snow))
				snow.CFrame = wCF * CFrame.new(0, wSize.Y * 0.5 + 0.65, 0)
				if merlonCount and merlonCount > 0 then
					for mi = 1, merlonCount do
						local mx = -wSize.X * 0.5 + (mi - 0.5) * (wSize.X / merlonCount)
						local mBlk = markNS(block(wName .. "Merlon", V(4.2, 3.4, wSize.Z + 0.6), pos, cGraniteDark, Enum.Material.Slate))
						mBlk.CFrame = wCF * CFrame.new(mx, wSize.Y * 0.5 + 2.8, 0)
					end
				end
			end
			local function addCornerTurret(tx: number, tz: number, hgt: number)
				markNS(cyl("CrossingCornerTurret", V(tx, gy + hgt * 0.5, tz), 6.2, hgt, cGranite, Enum.Material.Slate))
				markNS(cyl("CrossingCornerCrown", V(tx, gy + hgt + 1.4, tz), 7.2, 3.0, cGraniteDark, Enum.Material.Slate))
				markNS(cyl("CrossingCornerSnow", V(tx, gy + hgt + 3.2, tz), 6.8, 1.0, cSnow, Enum.Material.Snow))
			end
			-- North bastion curtain wall (Z = -20, X = 4..76) & NW / NE corner turrets
			addWall("CrossingNorthWall", V(72, 18, 6.5), V(40, gy + 9, -20), 0, 6)
			addCornerTurret(4, -19, 28)
			addCornerTurret(76, -19, 28)
			-- South flanking curtain walls outside the gatehouse + SE / SW corner turrets
			addWall("CrossingSouthEastWall", V(24, 18, 6.5), V(63, gy + 9, 37), 0, 2)
			addWall("CrossingSouthWestWall", V(11, 18, 6.5), V(8, gy + 9, 38), 0, 1)
			addCornerTurret(4, 37, 26)
			addCornerTurret(76, 37, 26)
			-- West & East side walls flanking the Crossing_WestGallery and Crossing_EastGallery bridge exits
			addWall("CrossingWestWallS", V(6.5, 16, 13), V(4, gy + 8, 29), 0, 0)
			addWall("CrossingWestWallN", V(6.5, 16, 9), V(4, gy + 8, -14), 0, 0)
			addWall("CrossingEastWallS", V(6.5, 16, 15), V(76, gy + 8, 28), 0, 0)
			-- Vaulted stone portal lintels framing the West & East bridge exits
			addWall("CrossingWestPortalArch", V(6.8, 6.0, 32), V(4, gy + 19.5, 6), 0, 0)
			addWall("CrossingEastPortalArch", V(6.8, 6.0, 32), V(76, gy + 19.5, -2), 0, 0)
		end)

		for _, lad in {
			{ x = 5.0, z = 41.5, yaw = -15, sc = 1.28 },
			{ x = 2.5, z = 40.5, yaw = -18, sc = 1.22 },
		} do
			group("FrozenSiegeLadder", function()
				currentParent:SetAttribute("OnTerrain", true)
				local lx, ly, lz = lad.x, 8, lad.z
				if KitProps.Has("FrozenSiegeLadder") then
					kitAt("FrozenSiegeLadder", CFrame.new(lx, ly, lz) * CFrame.Angles(0, math.rad(lad.yaw), 0), lad.sc * scale, {
						WOOD = { Color = cTimber, Material = Enum.Material.Wood },
						METAL = { Color = cIron, Material = Enum.Material.Metal },
						MOSS = { Color = cSnow, Material = Enum.Material.Snow },
						CRYSTAL = { Color = cGlacier, Material = Enum.Material.Ice, Transparency = 0.1 },
					})
				else
					local ladCF = CFrame.new(origin + V(lx, ly, lz)) * CFrame.Angles(0, math.rad(lad.yaw), 0) * CFrame.Angles(math.rad(-20), 0, 0)
					for _, sx in { -2.4, 2.4 } do
						local rail = block("SiegeLadderRail", V(0.8, 32, 0.8), V(lx, ly + 15, lz), cTimber, Enum.Material.Wood)
						rail.CFrame = ladCF * CFrame.new(sx, 15.5, 0)
						rail:SetAttribute("SolidScenery", false)
					end
					for rz = 3, 28, 3.4 do
						local rung = block("SiegeLadderRung", V(5.2, 0.55, 0.55), V(lx, ly + rz, lz), cTimber, Enum.Material.Wood)
						rung.CFrame = ladCF * CFrame.new(0, rz, 0)
						rung:SetAttribute("SolidScenery", false)
					end
				end
			end)
		end

		-- 3. East Bailey FrozenTrebuchet perched on an outer east granite siege spur (clear of EAST_GALLERY camp)
		group("FrozenTrebuchet", function()
			currentParent:SetAttribute("OnTerrain", true)
			local tx, ty, tz = 220, 10, -22
			local plinthH = ty - bottom + 6
			block("TrebuchetStoneSpur", V(32, plinthH, 34), V(tx, ty - plinthH * 0.5, tz), cGraniteDark, Enum.Material.Slate)
			if KitProps.Has("FrozenTrebuchet") then
				kitAt("FrozenTrebuchet", CFrame.new(tx, ty, tz) * CFrame.Angles(0, math.rad(115), 0), 1.48 * scale, {
					WOOD = { Color = cTimber, Material = Enum.Material.Wood },
					STONE = { Color = cGraniteDark, Material = Enum.Material.Slate },
					METAL = { Color = cIron, Material = Enum.Material.Metal },
					MOSS = { Color = cSnow, Material = Enum.Material.Snow },
					CRYSTAL = { Color = cGlacier, Material = Enum.Material.Ice, Transparency = 0.12 },
				})
			else
				for _, sx in { -6.8, 6.8 } do
					block("TrebuchetFrameBase", V(1.5, 1.5, 22), V(tx + sx, ty + 0.8, tz), cTimber, Enum.Material.Wood)
				end
				local arm = block("TrebuchetArm", V(1.4, 26, 1.4), V(tx, ty + 13, tz), cTimber, Enum.Material.Wood)
				arm.CFrame = CFrame.new(origin + V(tx, ty + 14, tz)) * CFrame.Angles(math.rad(-35), math.rad(115), 0)
			end
		end)

		-- 4. Towering WhiteguardTower standing on NE corner bastion plinth of EastBastion (clear of UPPER_EAST camp)
		group("WhiteguardTower", function()
			currentParent:SetAttribute("OnTerrain", true)
			local wx, wy, wz = 200, 16, -198
			local plinthH = wy - bottom + 6
			block("WhiteguardTowerPlinth", V(36, plinthH, 36), V(wx, wy - plinthH * 0.5, wz), cGraniteDark, Enum.Material.Slate)
			if KitProps.Has("WhiteguardTower") then
				local mdl = kitAt("WhiteguardTower", CFrame.new(wx, wy, wz) * CFrame.Angles(0, math.rad(65), 0), 1.52 * scale, {
					STONE = { Color = cGranite, Material = Enum.Material.Slate },
					TRIM = { Color = rgb(134, 148, 164), Material = Enum.Material.Granite },
					MOSS = { Color = cSnow, Material = Enum.Material.Snow },
					CRYSTAL = { Color = cGlacier, Material = Enum.Material.Ice, Transparency = 0.1 },
					METAL = { Color = cIron, Material = Enum.Material.Metal },
					ALT = { Color = cBanner, Material = Enum.Material.Fabric },
					GLOW = { Color = cRimelight, Material = Enum.Material.Neon },
				})
				local gp = mdl and mdl:FindFirstChildWhichIsA("BasePart")
				if gp then pointLight(gp, cRimelight, 1.1, 48) end
			else
				local tw = cyl("WhiteguardTowerShaft", V(wx, wy + 38, wz), 13.5, 76, cGranite, Enum.Material.Slate)
				pointLight(tw, cRimelight, 1.1, 48)
				cyl("WhiteguardTowerBase", V(wx, wy + 6, wz), 15.2, 12, cGraniteDark, Enum.Material.Slate)
				cyl("WhiteguardTowerCrown", V(wx, wy + 77, wz), 15.8, 5.5, cGraniteDark, Enum.Material.Slate)
				for m = 0, 3 do
					local ang = math.rad(m * 90 + 45)
					block("WhiteguardTowerMerlon", V(4.2, 4.2, 4.2), V(wx + math.cos(ang) * 13.0, wy + 81.5, wz + math.sin(ang) * 13.0), cGraniteDark, Enum.Material.Slate)
				end
				for k = 0, 3 do
					cyl("WhiteguardTowerRoof", V(wx, wy + 81.5 + k * 4.5, wz), 15.0 - k * 3.2, 4.8, if k % 2 == 0 then rgb(52, 62, 78) else cSnow, if k % 2 == 0 then Enum.Material.Slate else Enum.Material.Snow)
				end
				block("WhiteguardTowerFrozenBanner", V(1.4, 14.5, 16.0), V(wx - 15, wy + 62, wz), cBanner, Enum.Material.Fabric)
			end
		end)

		-- 5. West Glacier Caves: sculpted IceCaveOverhang arches facing +X from the west cliff & Rimelight Crystals
		local caveSides = {
			{ name = "IceCaveMouth", x = -218, y = 4, z = -10, roofX = -202, len = 60 },
			{ name = "CrystalGrotto", x = -214, y = 12, z = -150, roofX = -198, len = 58 },
		}
		for _, cv in caveSides do
			local cy = math.min(cv.y, minFootY(cv.x, cv.z, 7.0, cv.y))
			group("IceCaveOverhang", function()
				currentParent:SetAttribute("OnTerrain", true)
				if KitProps.Has("IceCaveOverhang") then
					-- Kit mesh back rests at -X and projects its overhanging brow/icicles toward +X (into the terrace)
					kitAt("IceCaveOverhang", CFrame.new(cv.x, cy, cv.z), 1.34 * scale, {
						STONE = { Color = cGraniteDark, Material = Enum.Material.Slate },
						MOSS = { Color = cSnow, Material = Enum.Material.Snow },
						CRYSTAL = { Color = cGlacier, Material = Enum.Material.Ice, Transparency = 0.1 },
						GLOW = { Color = cRimelight, Material = Enum.Material.Neon },
					})
				else
					local pS = block("CaveOuterPillarS", V(15, 32, 11), V(cv.x, cv.y + 16, cv.z + 15), cGraniteDark, Enum.Material.Slate)
					pS:SetAttribute("SolidScenery", false)
					local pN = block("CaveOuterPillarN", V(15, 32, 11), V(cv.x, cv.y + 16, cv.z - 15), cGraniteDark, Enum.Material.Slate)
					pN:SetAttribute("SolidScenery", false)
					local brow = block("CaveHighBrow", V(24, 5.5, 42), V(cv.x + 10, cv.y + 32, cv.z), cGraniteDark, Enum.Material.Slate)
					brow:SetAttribute("SolidScenery", false)
					local roof = block("CaveTranslucentIceRoof", V(28, 2.2, cv.len), V(cv.roofX, cv.y + 30.5, cv.z), cGlacier, Enum.Material.Ice, nil, 0.45)
					roof:SetAttribute("SolidScenery", false)
					for iz = -cv.len * 0.42, cv.len * 0.42, 10 do
						local ic = block("CaveRoofIcicle", V(1.8, 5.2, 1.8), V(cv.roofX + 12.5, cv.y + 27.6, cv.z + iz), cGlacier, Enum.Material.Ice, nil, 0.14)
						ic:SetAttribute("SolidScenery", false)
					end
				end
			end)
		end

		local crystalSpots = {
			{ x = -128, y = 0, z = 74, s = 1.25 * scale, light = true },
			{ x = -202, y = 4, z = 24, s = 1.38 * scale, light = false },
			{ x = -204, y = 4, z = -26, s = 1.48 * scale, light = true },
			{ x = -204, y = 4, z = 6, s = 1.20 * scale, light = false },
			{ x = -200, y = 12, z = -132, s = 1.56 * scale, light = true },
			{ x = -200, y = 12, z = -168, s = 1.48 * scale, light = false },
			{ x = -146, y = 12, z = -190, s = 1.62 * scale, light = false },
			{ x = -118, y = 12, z = -118, s = 1.32 * scale, light = false },
		}
		for _, cr in crystalSpots do
			local cy = minFootY(cr.x, cr.z, 3.6 * cr.s, cr.y)
			group("RimelightCrystalCluster", function()
				currentParent:SetAttribute("OnTerrain", true)
				if KitProps.Has("RimelightCrystalCluster") then
					local mdl = kitAt("RimelightCrystalCluster", CFrame.new(cr.x, cy, cr.z) * CFrame.Angles(0, cr.x * 0.1 + cr.z * 0.05, 0), cr.s, {
						STONE = { Color = cGraniteDark, Material = Enum.Material.Slate },
						MOSS = { Color = cSnow, Material = Enum.Material.Snow },
						CRYSTAL = { Color = cGlacier, Material = Enum.Material.Ice, Transparency = 0.08 },
						GLOW = { Color = cRimelight, Material = Enum.Material.Neon },
					})
					local gp = cr.light and mdl and mdl:FindFirstChildWhichIsA("BasePart")
					if gp then pointLight(gp, cRimelight, 1.3, 46) end
				else
					local sp = block("RimelightCrystalCore", V(4.2 * cr.s, 17 * cr.s, 4.2 * cr.s), V(cr.x, cy + 8.0 * cr.s, cr.z), cRimelight, Enum.Material.Neon)
					sp.CFrame = CFrame.new(origin + V(cr.x, cy + 8.0 * cr.s, cr.z)) * CFrame.Angles(0.14, cr.x * 0.1, -0.18)
					if cr.light then pointLight(sp, cRimelight, 1.3, 46) end
				end
			end)
		end

		-- 6. Sweeping Keep Cliff Icefall cascading down Keep Hall's front-west cliff drop between Crystal Grotto and Viaduct
		group("KeepMidCliffIcefall", function()
			currentParent:SetAttribute("OnTerrain", true)
			local ix, iz = -42, -138
			for ti, tier in { { -14, 24, 32 }, { 0, 22, 40 }, { 14, 24, 30 } } do
				local core = block("KeepIcefallCliffCore", V(tier[2], tier[3], 18), V(ix + tier[1], tier[3] * 0.5 - 6, iz - 8 + (ti % 2) * 3), cGraniteDark, Enum.Material.Slate)
				core:SetAttribute("SolidScenery", false)
				local snowLedge = block("KeepIcefallSnowLedge", V(tier[2] + 1, 2.2, 18.5), V(ix + tier[1], tier[3] - 5, iz - 8 + (ti % 2) * 3), cSnow, Enum.Material.Snow)
				snowLedge:SetAttribute("SolidScenery", false)
			end
			for ci, col in { { -22, 32, 9 }, { -14, 42, 10 }, { -6, 48, 11 }, { 2, 54, 12 }, { 10, 44, 10 }, { 18, 36, 9 }, { 24, 26, 8 } } do
				local ic = block("KeepMidCascadeColumn", V(col[3], col[2], 9), V(ix + col[1], col[2] * 0.5 - 6, iz + 4 + (ci % 2) * 2), if ci % 2 == 1 then cGlacier else rgb(172, 224, 250), Enum.Material.Ice, nil, 0.1)
				ic:SetAttribute("SolidScenery", false)
				if ci == 4 then pointLight(ic, cRimelight, 1.0, 56) end
			end
		end)
	elseif biome == "frozen_citadel" and layout.Authored == "frozen:5" then
		-- Floor 20, Frostbound Throne: ruined gothic castle interior — burst Antechamber gates, soaring
		-- iron-banded Nave colonnades & broken vault arches open to the night sky, Kneeling Knights,
		-- crystalline blue-fire braziers, Shattered Rose Windows, Glacial Urns, Frozen Font, & Permafrost Cage.
		local cGranite = rgb(104, 118, 134)
		local cGraniteDark = rgb(58, 68, 82)
		local cIron = rgb(44, 50, 60)
		local cSnow = rgb(236, 244, 254)
		local cGlacier = rgb(146, 208, 244)
		local cRimelight = rgb(78, 236, 255)
		local cBanner = rgb(44, 88, 136)

		local function markNS(p: BasePart): BasePart
			p:SetAttribute("SolidScenery", false)
			return p
		end

		local function minFootY(x: number, z: number, reach: number, fallbackY: number): number
			if not field then return fallbackY end
			local h = field.Height(x, z)
			if reach > 0 then
				h = math.min(
					h,
					field.Height(x + reach, z),
					field.Height(x - reach, z),
					field.Height(x, z + reach),
					field.Height(x, z - reach)
				)
			end
			return h + 0.9
		end

		-- 1. Ruined Cathedral Antechamber Gatehouse & Burst-Open Castle Porch (Basin Z = 132..228)
		group("PortcullisGate", function()
			currentParent:SetAttribute("OnTerrain", true)
			local gz = 132
			for _, s in { -1, 1 } do
				local pier = markNS(cyl("AntechamberGateTower", V(s * 36, 22, gz), 9.0, 46, cGranite, Enum.Material.Slate))
				markNS(cyl("AntechamberGateBase", V(s * 36, 4.5, gz), 10.4, 9, cGraniteDark, Enum.Material.Slate))
				markNS(cyl("AntechamberGateCrown", V(s * 36, 46, gz), 10.2, 4.0, cGraniteDark, Enum.Material.Slate))
				markNS(cyl("AntechamberGateSnow", V(s * 36, 48.4, gz), 9.6, 1.2, cSnow, Enum.Material.Snow))
				-- Shattered iron-bound castle doors forced wide outward into the courtyard (clear of Basin_Crossing)
				local doorCF = CFrame.new(origin + V(s * 24, 11, gz + 8)) * CFrame.Angles(0, s * math.rad(56), 0)
				local door = markNS(block("AntechamberBurstDoor", V(2.0, 22, 16), V(s * 24, 11, gz + 8), rgb(64, 52, 44), Enum.Material.Wood))
				door.CFrame = doorCF
				local doorBand = markNS(block("AntechamberDoorBand", V(2.3, 1.6, 15.6), V(s * 24, 11, gz + 8), cIron, Enum.Material.Metal))
				doorBand.CFrame = doorCF
				local doorIce = markNS(block("AntechamberDoorIce", V(4.2, 10, 6.5), V(s * 24, 5, gz + 8), cGlacier, Enum.Material.Ice, nil, 0.14))
				doorIce.CFrame = doorCF * CFrame.new(0, -6, -4)
				local ban = markNS(block("AntechamberBanner", V(3.6, 14, 0.6), V(s * 36, 27, gz + 9.2), cBanner, Enum.Material.Fabric))
				ban:SetAttribute("SolidScenery", false)
				-- Continued crenellated Antechamber wing walls & tip bastion towers on each side
				local wallLen = 132
				local wallX = s * 110
				markNS(block("AntechamberNorthWall", V(wallLen, 24, 7.5), V(wallX, 12, gz), cGranite, Enum.Material.Slate))
				markNS(block("AntechamberNorthSnow", V(wallLen + 1, 1.6, 8.2), V(wallX, 24.8, gz), cSnow, Enum.Material.Snow))
				for mx = -54, 54, 18 do
					markNS(block("AntechamberWingMerlon", V(5.4, 3.6, 8.0), V(wallX + mx, 27.0, gz), cGraniteDark, Enum.Material.Slate))
					if math.abs(mx) == 18 or math.abs(mx) == 54 then
						markNS(block("AntechamberWingPilaster", V(7.0, 26, 10.5), V(wallX + mx, 13, gz), cGraniteDark, Enum.Material.Slate))
					end
				end
				-- Grand bastion tower capping the tip of each wing wall (X = +-180, Z = 132)
				local tipX = s * 180
				markNS(cyl("AntechamberTipTowerShaft", V(tipX, 21, gz), 9.2, 42, cGranite, Enum.Material.Slate))
				markNS(cyl("AntechamberTipTowerBase", V(tipX, 4.5, gz), 10.6, 9, cGraniteDark, Enum.Material.Slate))
				markNS(cyl("AntechamberTipTowerBand", V(tipX, 24, gz), 9.8, 1.4, cIron, Enum.Material.Metal))
				markNS(cyl("AntechamberTipTowerCrown", V(tipX, 43.5, gz), 10.4, 4.0, cGraniteDark, Enum.Material.Slate))
				markNS(cyl("AntechamberTipTowerSnow", V(tipX, 46.0, gz), 9.8, 1.2, cSnow, Enum.Material.Snow))
				for m = 0, 3 do
					local ang = math.rad(m * 90 + 45)
					markNS(block("AntechamberTipTowerMerlon", V(3.4, 3.6, 3.4), V(tipX + math.cos(ang) * 8.2, 48.0, gz + math.sin(ang) * 8.2), cGraniteDark, Enum.Material.Slate))
				end
				markNS(block("AntechamberTipTowerSlit", V(1.6, 8.0, 1.4), V(tipX, 28, gz + 9.2), cRimelight, Enum.Material.Neon))
				local archHaunch = markNS(block("AntechamberArchHaunch", V(20, 5.5, 11.0), V(s * 18, 32.5, gz), cGraniteDark, Enum.Material.Slate))
				archHaunch.CFrame = CFrame.new(origin + V(s * 18, 32.5, gz)) * CFrame.Angles(0, 0, -s * math.rad(30))
			end
			markNS(block("AntechamberGateLintel", V(84, 9.5, 12.0), V(0, 39.5, gz), cGranite, Enum.Material.Slate))
			markNS(block("AntechamberGateSnow", V(86, 2.0, 12.8), V(0, 45.0, gz), cSnow, Enum.Material.Snow))
			for px = -14, 14, 7 do
				markNS(block("AntechamberPortcullisSpike", V(0.85, 8.5, 0.85), V(px, 31.0, gz + 4.5), cIron, Enum.Material.Metal))
			end
		end)

		-- 2. Outer Castle Cathedral Nave/Aisle/Porch Ruined Stone Walls & Banners (each bay independent so lanes stay open)
		for _, s in { -1, 1 } do
			-- Two-story western & eastern ruined nave/aisle outer cathedral walls
			local wx = s * 224
			for bi, bz in { -115, -20, 75, 165 } do
				group("CathedralWallBay", function()
					currentParent:SetAttribute("OnTerrain", true)
					local hgt = if bi % 2 == 0 then 52 else 46
					markNS(block("CathedralOuterWallBay", V(10, hgt, 82), V(wx, hgt * 0.5 - 6, bz), cGranite, Enum.Material.Slate))
					markNS(block("CathedralOuterCornice", V(12, 3.0, 82), V(wx, hgt - 5, bz), cGraniteDark, Enum.Material.Slate))
					markNS(block("CathedralOuterSnow", V(12.5, 1.8, 80), V(wx, hgt - 2.6, bz), cSnow, Enum.Material.Snow))
					markNS(block("CathedralWallPilaster", V(14, hgt + 4, 9), V(wx - s * 3, hgt * 0.5 - 6, bz - 36), cGraniteDark, Enum.Material.Slate))
					if bi == 1 or bi == 3 or bi == 5 then
						markNS(block("CathedralWallBanner", V(0.7, 16.0, 5.4), V(wx - s * 6.2, 24, bz), cBanner, Enum.Material.Fabric))
						markNS(block("CathedralClerestoryCrystal", V(1.6, 5.4, 2.2), V(wx - s * 5.8, 33, bz + 16), cRimelight, Enum.Material.Neon))
					end
				end)
			end
			-- South Antechamber ruined castle entrance walls flanking the Cathedral Porch
			group("CathedralSouthWall", function()
				currentParent:SetAttribute("OnTerrain", true)
				markNS(block("CathedralSouthWall", V(144, 36, 9), V(s * 148, 12, 232), cGranite, Enum.Material.Slate))
				markNS(block("CathedralSouthWallSnow", V(146, 2.2, 10), V(s * 148, 31.0, 232), cSnow, Enum.Material.Snow))
			end)
			-- Outer Northern Choir Wall behind WestBastion/EastBastion (clear of WestBastion_Apex/EastBastion_Apex paths)
			group("CathedralChoirWall", function()
				currentParent:SetAttribute("OnTerrain", true)
				markNS(block("CathedralNorthChoirWall", V(56, 54, 10), V(s * 194, 22, -206), cGranite, Enum.Material.Slate))
				markNS(block("CathedralNorthChoirSnow", V(58, 2.5, 11), V(s * 194, 50.0, -206), cSnow, Enum.Material.Snow))
			end)
		end

		-- 3. Colossal Gothic Nave Colonnade Pillars, Longitudinal Arcade Spans & Broken Roof Vault Arches
		-- Placed cleanly at X = +-46 outside Crossing (W=72 -> +-36), leaving Z = -20..+38 transept paths completely open.
		local navePillarZs = { -48, -20, 38, 66 }
		for _, pz in navePillarZs do
			for _, s in { -1, 1 } do
				local px = s * 46
				local pierH = 8 - bottom + 2
				block("NaveColumnChasmPier", V(14, pierH, 14), V(px, bottom + pierH * 0.5 - 1, pz), cGraniteDark, Enum.Material.Slate)
				group("GothicPillarColonnade", function()
					currentParent:SetAttribute("OnTerrain", true)
					if KitProps.Has("GothicPillarColonnade") then
						kitAt("GothicPillarColonnade", CFrame.new(px, 8, pz) * CFrame.Angles(0, s > 0 and math.rad(90) or math.rad(-90), 0), 1.18 * scale, {
							STONE = { Color = cGranite, Material = Enum.Material.Slate },
							METAL = { Color = cIron, Material = Enum.Material.Metal },
							MOSS = { Color = cSnow, Material = Enum.Material.Snow },
							CRYSTAL = { Color = cGlacier, Material = Enum.Material.Ice, Transparency = 0.12 },
							GLOW = { Color = cRimelight, Material = Enum.Material.Neon },
						})
					else
						local col = cyl("NaveColonnadeShaft", V(px, 34, pz), 5.2, 52, cGranite, Enum.Material.Slate)
						col:SetAttribute("SolidScenery", false)
						for _, bz in { 18, 30, 42 } do
							markNS(cyl("NaveColumnIronBand", V(px, bz, pz), 5.8, 1.4, cIron, Enum.Material.Metal))
						end
						markNS(cyl("NaveColumnCapital", V(px, 59, pz), 7.2, 4.8, cGraniteDark, Enum.Material.Slate))
						markNS(block("NaveColumnSnowCap", V(14.5, 2.0, 14.5), V(px, 62.2, pz), cSnow, Enum.Material.Snow))
						markNS(block("NaveColumnBracket", V(2.4, 4.5, 1.8), V(px - s * 5.8, 33, pz), cRimelight, Enum.Material.Neon))
						for _, icOff in { -3.5, 0, 3.5 } do
							markNS(block("NaveCapitalIcicle", V(1.4, 6.2, 1.4), V(px + icOff, 54.5, pz + 5.2), cGlacier, Enum.Material.Ice, nil, 0.14))
						end
					end
				end)
			end
			-- High overhead broken pointed cathedral vault ribs arcing across the nave (open center showing night aurora)
			group("GothicVaultArch", function()
				currentParent:SetAttribute("OnTerrain", true)
				for _, s in { -1, 1 } do
					local rib = markNS(block("NaveBrokenVaultRib", V(38, 4.8, 7.2), V(s * 28, 66, pz), cGraniteDark, Enum.Material.Slate))
					rib.CFrame = CFrame.new(origin + V(s * 28, 66, pz)) * CFrame.Angles(0, 0, -s * math.rad(28))
					local snowTop = markNS(block("NaveVaultRibSnow", V(36, 1.6, 7.6), V(s * 28, 68.8, pz), cSnow, Enum.Material.Snow))
					snowTop.CFrame = CFrame.new(origin + V(s * 28, 68.8, pz)) * CFrame.Angles(0, 0, -s * math.rad(28))
					markNS(block("NaveVaultHangingIcicle", V(1.6, 7.5, 1.6), V(s * 14, 70.0, pz), cGlacier, Enum.Material.Ice, nil, 0.12))
				end
			end)
		end
		-- Longitudinal gothic side arcade lintels & hanging ward-star banners connecting nave pillar bays (leaves Z=-20..+38 transept open)
		for _, pairZ in { { -48, -20 }, { 38, 66 } } do
			local midZ = (pairZ[1] + pairZ[2]) * 0.5
			local spanLen = math.abs(pairZ[2] - pairZ[1])
			for _, s in { -1, 1 } do
				group("GothicArcadeSpan", function()
					currentParent:SetAttribute("OnTerrain", true)
					markNS(block("NaveArcadeBeam", V(7.5, 6.5, spanLen), V(s * 46, 56, midZ), cGranite, Enum.Material.Slate))
					markNS(block("NaveArcadeSnow", V(8.0, 1.6, spanLen), V(s * 46, 60.0, midZ), cSnow, Enum.Material.Snow))
					markNS(block("NaveArcadeBanner", V(0.7, 16.0, 5.4), V(s * 42.2, 44, midZ), cBanner, Enum.Material.Fabric))
				end)
			end
		end

		-- 4. Honor Guard of Frozen Kneeling Knights lining Nave edges & Antechamber porch
		local knightSpots = {
			{ x = -30, y = 8, z = -40, yaw = math.rad(90) },
			{ x = 30, y = 8, z = -40, yaw = math.rad(-90) },
			{ x = -30, y = 8, z = -28, yaw = math.rad(90) },
			{ x = 30, y = 8, z = -28, yaw = math.rad(-90) },
			{ x = -30, y = 8, z = 44, yaw = math.rad(90) },
			{ x = 30, y = 8, z = 44, yaw = math.rad(-90) },
			{ x = -30, y = 8, z = 56, yaw = math.rad(90) },
			{ x = 30, y = 8, z = 56, yaw = math.rad(-90) },
			{ x = -42, y = 0, z = 152, yaw = math.rad(65) },
			{ x = 42, y = 0, z = 152, yaw = math.rad(-65) },
			{ x = -56, y = 0, z = 150, yaw = math.rad(55) },
			{ x = 56, y = 0, z = 150, yaw = math.rad(-55) },
		}
		for _, kn in knightSpots do
			local ky = if kn.y > 0 then kn.y else math.max(0, minFootY(kn.x, kn.z, 2.4, 0))
			group("KneelingKnight", function()
				currentParent:SetAttribute("OnTerrain", true)
				if KitProps.Has("KneelingKnight") then
					kitAt("KneelingKnight", CFrame.new(kn.x, ky, kn.z) * CFrame.Angles(0, kn.yaw, 0), 1.15 * scale, {
						STONE = { Color = cGranite, Material = Enum.Material.Slate },
						METAL = { Color = cIron, Material = Enum.Material.Metal },
						MOSS = { Color = cSnow, Material = Enum.Material.Snow },
						CRYSTAL = { Color = cGlacier, Material = Enum.Material.Ice, Transparency = 0.16 },
						GLOW = { Color = cRimelight, Material = Enum.Material.Neon },
					})
				else
					local kCF = CFrame.new(origin + V(kn.x, ky, kn.z)) * CFrame.Angles(0, kn.yaw, 0)
					block("KnightPedestal", V(5.2, 0.8, 6.2), V(kn.x, ky + 0.4, kn.z), cGraniteDark, Enum.Material.Slate).CFrame = kCF * CFrame.new(0, 0.4, 0)
					block("KnightLegsKneel", V(3.4, 2.6, 3.6), V(kn.x, ky + 2.0, kn.z), cIron, Enum.Material.Metal).CFrame = kCF * CFrame.new(0, 2.0, -0.3)
					block("KnightTorso", V(3.4, 3.8, 2.4), V(kn.x, ky + 4.4, kn.z), cIron, Enum.Material.Metal).CFrame = kCF * CFrame.new(0, 4.4, 0.15) * CFrame.Angles(math.rad(-14), 0, 0)
					block("KnightCloak", V(3.8, 4.4, 1.2), V(kn.x, ky + 3.2, kn.z), cGranite, Enum.Material.Slate).CFrame = kCF * CFrame.new(0, 3.2, -1.2) * CFrame.Angles(math.rad(14), 0, 0)
					for _, px in { -2.0, 2.0 } do
						block("KnightPauldron", V(1.5, 1.6, 1.8), V(kn.x, ky + 5.8, kn.z), cIron, Enum.Material.Metal).CFrame = kCF * CFrame.new(px, 5.8, 0.2)
					end
					block("KnightHelm", V(1.9, 2.0, 2.0), V(kn.x, ky + 7.2, kn.z), cIron, Enum.Material.Metal).CFrame = kCF * CFrame.new(0, 7.2, 0.5) * CFrame.Angles(math.rad(-20), 0, 0)
					block("KnightSword", V(0.4, 6.4, 0.5), V(kn.x, ky + 3.4, kn.z), cIron, Enum.Material.Metal).CFrame = kCF * CFrame.new(0, 3.4, 1.8)
					block("KnightSwordGuard", V(2.4, 0.4, 0.4), V(kn.x, ky + 5.2, kn.z), cIron, Enum.Material.Metal).CFrame = kCF * CFrame.new(0, 5.2, 1.8)
					local ic1 = block("KnightIceSpire", V(1.2, 5.4, 1.2), V(kn.x, ky + 3.0, kn.z), cGlacier, Enum.Material.Ice, nil, 0.22)
					ic1.CFrame = kCF * CFrame.new(2.1, 3.0, -1.1) * CFrame.Angles(0.15, 0, -0.25)
				end
			end)
		end

		-- 5. Crystalline Blue-Fire Cathedral Braziers (replaces flames with radiant cyan Rimelight)
		local brazierSpots = {
			{ x = -28, y = 0, z = 204, light = true },
			{ x = 28, y = 0, z = 204, light = false },
			{ x = -46, y = 0, z = 144, light = false },
			{ x = 46, y = 0, z = 144, light = true },
			{ x = -29, y = 8, z = 64, light = true },
			{ x = 29, y = 8, z = 64, light = false },
			{ x = -29, y = 8, z = -46, light = false },
			{ x = 29, y = 8, z = -46, light = true },
			{ x = -54, y = 28, z = -182, light = true },
			{ x = 54, y = 28, z = -182, light = false },
		}
		for _, br in brazierSpots do
			local by = if br.y > 0 then br.y else math.max(0, minFootY(br.x, br.z, 2.5, 0))
			group("IceCrystalBrazier", function()
				currentParent:SetAttribute("OnTerrain", true)
				if KitProps.Has("IceCrystalBrazier") then
					local mdl = kitAt("IceCrystalBrazier", CFrame.new(br.x, by, br.z), 1.15 * scale, {
						METAL = { Color = cIron, Material = Enum.Material.Metal },
						STONE = { Color = cGraniteDark, Material = Enum.Material.Slate },
						MOSS = { Color = cSnow, Material = Enum.Material.Snow },
						CRYSTAL = { Color = cGlacier, Material = Enum.Material.Ice, Transparency = 0.1 },
						GLOW = { Color = cRimelight, Material = Enum.Material.Neon },
					})
					local gp = br.light and mdl and mdl:FindFirstChildWhichIsA("BasePart")
					if gp then pointLight(gp, cRimelight, 1.35, 48) end
				else
					cyl("CrystalBrazierPlinth", V(br.x, by + 0.5, br.z), 3.6, 1.0, cGraniteDark, Enum.Material.Slate)
					cyl("CrystalBrazierBowl", V(br.x, by + 2.2, br.z), 3.2, 2.0, cIron, Enum.Material.Metal)
					for k = 0, 3 do
						local spk = block("BrazierRimSpike", V(0.5, 2.2, 0.5), V(br.x, by + 3.8, br.z), cIron, Enum.Material.Metal)
						spk.CFrame = CFrame.new(origin + V(br.x, by + 3.8, br.z)) * CFrame.Angles(0, k * math.pi * 0.5, 0) * CFrame.new(2.8, 0, 0)
					end
					local shard = block("CrystalBrazierCore", V(1.6, 4.8, 1.6), V(br.x, by + 4.4, br.z), cRimelight, Enum.Material.Neon)
					if br.light then pointLight(shard, cRimelight, 1.35, 48) end
				end
			end)
		end

		-- 6. Side Aisles & Chapels: Shattered Rose Windows, Frozen Font, West Chapel Glacial Urns, East Chapel Permafrost Cage
		for _, rw in {
			{ x = -218, y = 6, z = 20, yaw = math.rad(90) },
			{ x = 218, y = 6, z = 20, yaw = math.rad(-90) },
		} do
			group("ShatteredRoseWindow", function()
				currentParent:SetAttribute("OnTerrain", true)
				if KitProps.Has("ShatteredRoseWindow") then
					kitAt("ShatteredRoseWindow", CFrame.new(rw.x, rw.y, rw.z) * CFrame.Angles(0, rw.yaw, 0), 1.05 * scale, {
						STONE = { Color = cGraniteDark, Material = Enum.Material.Slate },
						MOSS = { Color = cSnow, Material = Enum.Material.Snow },
						CRYSTAL = { Color = cGlacier, Material = Enum.Material.Ice, Transparency = 0.14 },
						GLOW = { Color = cRimelight, Material = Enum.Material.Neon },
					})
				else
					local wCF = CFrame.new(origin + V(rw.x, rw.y, rw.z)) * CFrame.Angles(0, rw.yaw, 0)
					block("RoseWindowFrame", V(24, 38, 5), V(rw.x, rw.y + 19, rw.z), cGraniteDark, Enum.Material.Slate).CFrame = wCF * CFrame.new(0, 19, 0)
					local pane = cyl("RoseWindowGlaze", V(rw.x, rw.y + 21, rw.z), 7.5, 2.4, cGlacier, Enum.Material.Ice, 0.25)
					pane.CFrame = wCF * CFrame.new(0, 21, 0) * CFrame.Angles(0, math.pi * 0.5, 0)
				end
			end)
		end

		-- East Aisle Frozen Baptismal Font in an outer alcove
		group("FrozenFont", function()
			currentParent:SetAttribute("OnTerrain", true)
			local fx, fy, fz = 218, 6, 52
			local plinthH = fy - bottom + 2
			block("FrozenFontPlinth", V(18, plinthH, 18), V(fx, bottom + plinthH * 0.5 - 1, fz), cGraniteDark, Enum.Material.Slate)
			cyl("FrozenFontPedestal", V(fx, fy + 2.5, fz), 3.6, 5.0, cGranite, Enum.Material.Slate)
			cyl("FrozenFontBasin", V(fx, fy + 5.8, fz), 6.2, 2.4, cGraniteDark, Enum.Material.Slate)
			local water = cyl("FrozenFontIcePool", V(fx, fy + 6.8, fz), 5.2, 1.2, cRimelight, Enum.Material.Neon, 0.2)
			pointLight(water, cRimelight, 1.1, 38)
		end)

		-- West Chapel Row of Glacial Urns (runes frozen mid-glow) on outer chapel alcoves
		for idx, uz in { -162, -140, -118, -96 } do
			local ux, uy = -214, 16
			local plinthH = uy - bottom + 2
			block("ChapelUrnPlinth", V(14, plinthH, 14), V(ux, bottom + plinthH * 0.5 - 1, uz), cGraniteDark, Enum.Material.Slate)
			group("GlacialUrnShrine", function()
				currentParent:SetAttribute("OnTerrain", true)
				if KitProps.Has("GlacialUrnShrine") then
					kitAt("GlacialUrnShrine", CFrame.new(ux, uy, uz) * CFrame.Angles(0, math.rad(90), 0), 1.05 * scale, {
						STONE = { Color = cGranite, Material = Enum.Material.Slate },
						METAL = { Color = cIron, Material = Enum.Material.Metal },
						MOSS = { Color = cSnow, Material = Enum.Material.Snow },
						CRYSTAL = { Color = cGlacier, Material = Enum.Material.Ice, Transparency = 0.12 },
						GLOW = { Color = cRimelight, Material = Enum.Material.Neon },
					})
				else
					cyl("GlacialUrnBase", V(ux, uy + 2.6, uz), 3.2, 5.2, cGraniteDark, Enum.Material.Slate)
					cyl("GlacialUrnCore", V(ux, uy + 7.2, uz), 2.5, 4.4, cRimelight, Enum.Material.Neon, 0.16)
				end
			end)
		end

		-- East Chapel Reliquary: Permafrost Core in Iron Cage flanked by twin Glacial Urns
		group("PermafrostCage", function()
			currentParent:SetAttribute("OnTerrain", true)
			local cx, cy, cz = 216, 16, -130
			local cagePlinthH = cy - bottom + 2
			block("PermafrostCageAlcove", V(20, cagePlinthH, 24), V(cx, bottom + cagePlinthH * 0.5 - 1, cz), cGraniteDark, Enum.Material.Slate)
			if KitProps.Has("PermafrostCage") then
				local mdl = kitAt("PermafrostCage", CFrame.new(cx, cy, cz) * CFrame.Angles(0, math.rad(-90), 0), 1.2 * scale, {
					METAL = { Color = cIron, Material = Enum.Material.Metal },
					STONE = { Color = cGraniteDark, Material = Enum.Material.Slate },
					MOSS = { Color = cSnow, Material = Enum.Material.Snow },
					CRYSTAL = { Color = cGlacier, Material = Enum.Material.Ice, Transparency = 0.1 },
					GLOW = { Color = cRimelight, Material = Enum.Material.Neon },
				})
				local gp = mdl and mdl:FindFirstChildWhichIsA("BasePart")
				if gp then pointLight(gp, cRimelight, 1.4, 52) end
			else
				cyl("PermafrostCagePlinth", V(cx, cy + 2.0, cz), 5.6, 4.0, cGraniteDark, Enum.Material.Slate)
				for _, bx in { -4.0, 4.0 } do
					for _, bz in { -4.0, 4.0 } do
						block("ReliquaryCageBar", V(0.7, 14, 0.7), V(cx + bx, cy + 11, cz + bz), cIron, Enum.Material.Metal)
					end
				end
				local core = block("PermafrostCoreShard", V(3.8, 7.2, 3.8), V(cx, cy + 10.5, cz), cRimelight, Enum.Material.Neon)
				pointLight(core, cRimelight, 1.4, 52)
			end
		end)
		for _, uz in { -160, -100 } do
			local ux, uy = 214, 16
			local plinthH = uy - bottom + 2
			block("ChapelUrnPlinth", V(14, plinthH, 14), V(ux, bottom + plinthH * 0.5 - 1, uz), cGraniteDark, Enum.Material.Slate)
			group("GlacialUrnShrine", function()
				currentParent:SetAttribute("OnTerrain", true)
				if KitProps.Has("GlacialUrnShrine") then
					kitAt("GlacialUrnShrine", CFrame.new(ux, uy, uz) * CFrame.Angles(0, math.rad(-90), 0), 1.05 * scale, {
						STONE = { Color = cGranite, Material = Enum.Material.Slate },
						METAL = { Color = cIron, Material = Enum.Material.Metal },
						MOSS = { Color = cSnow, Material = Enum.Material.Snow },
						CRYSTAL = { Color = cGlacier, Material = Enum.Material.Ice, Transparency = 0.12 },
						GLOW = { Color = cRimelight, Material = Enum.Material.Neon },
					})
				else
					cyl("GlacialUrnBase", V(ux, uy + 2.6, uz), 3.2, 5.2, cGraniteDark, Enum.Material.Slate)
					cyl("GlacialUrnCore", V(ux, uy + 7.2, uz), 2.5, 4.4, cRimelight, Enum.Material.Neon, 0.16)
				end
			end)
		end

		-- 7. Abundant Off-Path Ruined Castle Debris, Shattered Ward-Star Shields & Rimelight Crystals
		local clutterSpots = {
			{ x = -64, z = 198, yaw = 0.4 },
			{ x = 64, z = 198, yaw = -0.4 },
			{ x = -196, z = 152, yaw = 0.9 },
			{ x = 196, z = 152, yaw = -0.9 },
			{ x = -198, z = 208, yaw = 1.3 },
			{ x = 198, z = 208, yaw = -1.3 },
		}
		for idx, cl in clutterSpots do
			local cy = math.max(0, minFootY(cl.x, cl.z, 2.5, 0))
			group("RuinedCastleDebris", function()
				currentParent:SetAttribute("OnTerrain", true)
				local slab = block("FallenGothicSlab", V(8.5, 2.2, 4.8), V(cl.x, cy + 1.1, cl.z), cGraniteDark, Enum.Material.Slate)
				slab.CFrame = CFrame.new(origin + V(cl.x, cy + 1.1, cl.z)) * CFrame.Angles(0.18, cl.yaw, 0.12)
				local snow = block("FallenSlabSnow", V(7.5, 0.9, 4.2), V(cl.x, cy + 2.4, cl.z), cSnow, Enum.Material.Snow)
				snow.CFrame = slab.CFrame * CFrame.new(0, 1.3, 0)
				if idx % 2 == 1 and KitProps.Has("WardStarShieldMarker") then
					kitAt("WardStarShieldMarker", CFrame.new(cl.x + 5, cy, cl.z) * CFrame.Angles(0, cl.yaw, 0), 1.15 * scale)
				end
			end)
		end

		local crystalSpots = {
			{ x = -88, y = 0, z = 112, s = 1.28 * scale, light = true },
			{ x = 88, y = 0, z = 112, s = 1.28 * scale, light = false },
			{ x = -112, y = 0, z = -34, s = 1.36 * scale, light = true },
			{ x = 112, y = 0, z = -34, s = 1.36 * scale, light = false },
			{ x = -108, y = 0, z = -152, s = 1.42 * scale, light = false },
			{ x = 108, y = 0, z = -152, s = 1.42 * scale, light = true },
			{ x = -78, y = 28, z = -270, s = 1.35 * scale, light = false },
			{ x = 78, y = 28, z = -270, s = 1.35 * scale, light = false },
		}
		for _, cr in crystalSpots do
			local cy = if cr.y > 0 then cr.y else minFootY(cr.x, cr.z, 3.0, 0)
			group("RimelightCrystalCluster", function()
				currentParent:SetAttribute("OnTerrain", true)
				if KitProps.Has("RimelightCrystalCluster") then
					local mdl = kitAt("RimelightCrystalCluster", CFrame.new(cr.x, cy, cr.z) * CFrame.Angles(0, cr.x * 0.1, 0), cr.s, {
						STONE = { Color = cGraniteDark, Material = Enum.Material.Slate },
						MOSS = { Color = cSnow, Material = Enum.Material.Snow },
						CRYSTAL = { Color = cGlacier, Material = Enum.Material.Ice, Transparency = 0.08 },
						GLOW = { Color = cRimelight, Material = Enum.Material.Neon },
					})
					local gp = cr.light and mdl and mdl:FindFirstChildWhichIsA("BasePart")
					if gp then pointLight(gp, cRimelight, 1.2, 46) end
				else
					local sp = block("RimelightCrystalCore", V(4.2 * cr.s, 16 * cr.s, 4.2 * cr.s), V(cr.x, cy + 7.5 * cr.s, cr.z), cRimelight, Enum.Material.Neon)
					if cr.light then pointLight(sp, cRimelight, 1.2, 46) end
				end
			end)
		end
	end

	-- Floor 6, Sporelit Entry (Fungal Hollow): the edge of the Veinweb in the Velmari lamp-masons' outer quarry.
	-- The Elder Cap rises from its island in the glowpool and hides the Apex; the oculus over the Skylight Dais
	-- drops a cyan shaft through a fringe of roots, and a crown of caps grows on the cliff above it. The
	-- Veinspan is an arched slate bridge over the east pool; the Chanters keep a candle altar on their terrace,
	-- the Skitters lay their eggs against the warren's cliff, and Lantern Spores gather by the crystals. Kit
	-- meshes from fungal_f6_kit where imported (KitProps.Has), part-built fallbacks otherwise.
	-- Floor 7, Mycelium Galleries: the lamp-galleries strung with the Veinweb's nets (fungal_f7_kit).
	-- Every hand-authored Fungal floor shares the palette, helpers, crystals, oculus and bridge arches below.
	local fungalFloor = if type(layout.Authored) == "string" and string.sub(layout.Authored, 1, 7) == "fungal:"
		then tonumber(string.sub(layout.Authored, 8)) else nil
	if fungalFloor then
		local violet = rgb(92, 52, 176)
		local slate = rgb(62, 56, 94)
		local slateDark = rgb(42, 38, 66)
		local cobble = rgb(96, 74, 138)
		local cyan = rgb(95, 245, 235)
		local bulbViolet = rgb(196, 112, 255)
		local teal = rgb(96, 236, 214)
		local capOverride = { CAP = { Color = violet }, STEM = { Color = rgb(176, 170, 206) }, MOSS = { Color = rgb(58, 50, 96), Material = Enum.Material.Grass } }
		local crystalOverride = { CRYSTAL = { Color = teal, Material = Enum.Material.Glass, Transparency = 0.25 }, STONE = { Color = slate, Material = Enum.Material.Slate } }
		local liquid = if field then field.LiquidLevel else bottom
		-- Ground under a spot: a terrace's walking plane, else the terrain (or the chasm floor).
		local function groundY(x: number, z: number): number
			for _, t in layout.Platforms do
				if math.abs(x - t.X) <= t.Width / 2 and math.abs(z - t.Z) <= t.Depth / 2 then
					return t.Y
				end
			end
			return if field then (field.Sample(x, z)) else bottom
		end
		-- The current prop group sits on the terrain's own surface (the settle pass leaves it alone).
		local function onTerrain()
			if currentParent ~= kit then currentParent:SetAttribute("OnTerrain", true) end
		end
		local function yawToward(from: Vector3, to: Vector3): number
			return math.atan2(to.X - from.X, to.Z - from.Z)
		end
		-- Teal crystal spires (the Lantern Spores' light).
		local function crystal(at: Vector3, s: number, yaw: number)
			group("PoolCrystal", function()
				onTerrain()
				if not kitAt("CrystalSpire", CFrame.new(at + V(0, -0.8, 0)) * CFrame.Angles(0.06, yaw, -0.04), s, crystalOverride) then
					spire(at, 44 * s, 18 * s, teal, cyan, true)
				end
			end)
			table.insert(reservedSpots, { at.X, at.Z, 22 * s + 2 })
		end
		-- A Velmari lamp-post; a dead one has a dark bulb and dull gill-lines.
		local deadLamp = { BULB = { Color = rgb(58, 48, 72), Material = Enum.Material.SmoothPlastic }, GLOW = { Color = rgb(44, 70, 80), Material = Enum.Material.SmoothPlastic } }
		-- A Lampkeeper's lamp burns a warm flame (the only warm light besides the Chanters' candles).
		local flameWarm = rgb(255, 170, 92)
		local warmLamp = { BULB = { Color = flameWarm, Material = Enum.Material.Neon }, GLOW = { Color = rgb(255, 206, 140), Material = Enum.Material.Neon } }
		local function lampPost(at: Vector3, yaw: number, s: number, dead: boolean?, warm: boolean?)
			group("VelmariLampPost", function()
				local o = if dead then deadLamp elseif warm then warmLamp else nil
				if not kitAt("VelmariLampPost", CFrame.new(at) * CFrame.Angles(0, yaw, 0), s, o) then
					block("LampPostShaft", V(1.4, 10 * s, 1.4), at + V(0, 5 * s, 0), slate, Enum.Material.Slate)
					orb("LampPostBulb", at + V(0, 10.6 * s, 0), V(1.6, 2, 1.6) * s, if dead then rgb(58, 48, 72) elseif warm then flameWarm else bulbViolet, if dead then Enum.Material.SmoothPlastic else Enum.Material.Neon)
				end
			end)
		end
		-- The Lampkeepers' sign, chalked on a rock: a gill-wheel with one long ray pointing the way up. `yaw`
		-- turns its face (front +Z) toward whoever walks past.
		local chalk = rgb(226, 222, 232)
		local function chalkSign(at: Vector3, yaw: number, s: number?)
			group("ChalkSign", function()
				onTerrain()
				local sc = s or 1.2
				if not kitAt("ChalkSign", CFrame.new(at) * CFrame.Angles(0, yaw, 0), sc, { ALT = { Color = chalk, Material = Enum.Material.SmoothPlastic }, STONE = { Color = slate, Material = Enum.Material.Slate } }) then
					local cf = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
					local stone = block("ChalkSignRock", V(3, 2.6, 1.8) * sc, V(0, 0, 0), slate, Enum.Material.Slate)
					stone.CFrame = CFrame.new(origin) * cf * CFrame.new(0, 1.3 * sc, 0)
					local ray = block("ChalkSignRay", V(0.12, 1.4, 0.05) * sc, V(0, 0, 0), chalk, Enum.Material.SmoothPlastic)
					ray.CFrame = CFrame.new(origin) * cf * CFrame.new(0, 1.9 * sc, 0.92 * sc)
					local wheel = cyl("ChalkSignWheel", V(0, 0, 0), 0.5 * sc, 0.05, chalk, Enum.Material.SmoothPlastic)
					wheel.CFrame = CFrame.new(origin) * cf * CFrame.new(0, 1.3 * sc, 0.92 * sc) * CFrame.Angles(0, math.pi / 2, 0)
				end
			end)
		end
		-- Glowing pad-caps floating on a pool at the water line (the settle pass leaves them there), kept out
		-- from under the bridge deck.
		local function padCaps(cx: number, cz: number, rMin: number, rMax: number, count: number, seed: number)
			if not field then return end
			local cross = layout.Platforms.Crossing
			local rand = Random.new(seed)
			local pads = 0
			for _ = 1, count * 12 do
				if pads >= count then break end
				local a, r = rand:NextNumber(0, math.pi * 2), rand:NextNumber(rMin, rMax)
				local x, z = cx + math.cos(a) * r, cz + math.sin(a) * r * 1.05
				local y, kind = field.Sample(x, z)
				local underDeck = math.abs(x - cross.X) < cross.Width / 2 + 3 and math.abs(z - cross.Z) < cross.Depth / 2 + 3
				if kind == "POOL" and y < liquid - 0.8 and not underDeck then
					pads += 1
					group("PadCap", function()
						onTerrain()
						local at = V(x, liquid - 0.15, z)
						local padCap = if fungalFloor == 9 then rgb(96, 48, 172) elseif fungalFloor == 10 then rgb(92, 44, 182) else rgb(70, 46, 140)
						local padGlow = if fungalFloor == 9 then rgb(182, 245, 74) elseif fungalFloor == 10 then rgb(112, 245, 255) else cyan
						if not kitAt("PadCap", CFrame.new(at) * CFrame.Angles(0, a, 0), rand:NextNumber(0.8, 1.6), { CAP = { Color = padCap }, GLOW = { Color = padGlow, Material = Enum.Material.Neon } }) then
							cyl("PadCapDisc", at + V(0, 0.2, 0), 2.2, 0.4, padCap, Enum.Material.SmoothPlastic)
							cyl("PadCapGlowRim", at + V(0, 0.45, 0), 1.8, 0.1, padGlow, Enum.Material.Neon)
						end
					end)
				end
			end
		end

		if fungalFloor == 6 then
		-- 1. The Elder Cap on its island, with a companion clutch of caps and one cyan light under the gills.
		local island = (layout.Terrain and layout.Terrain.Islands and layout.Terrain.Islands[1]) or { X = 0, Z = -34, R = 26 }
		-- Six studs east of the island's centre: the cap's glow (gills, roots and tendrils in one mesh) then clears
		-- the shoulder of the west ramp to the dais.
		local capAt = V(island.X + 6, groundY(island.X + 6, island.Z), island.Z)
		group("ElderCap", function()
			onTerrain()
			local placed = kitAt("ElderCap", CFrame.new(capAt + V(0, -0.6, 0)) * CFrame.Angles(0, math.rad(20), 0), 1, capOverride)
			if not placed then
				mushroom(capAt, 2.9, false)
			end
			local glow = orb("ElderCapGillGlow", capAt + V(0, 70, 0), V(2, 2, 2), cyan, Enum.Material.SmoothPlastic, 1)
			pointLight(glow, cyan, 1.6, 90)
			for k = 1, 3 do
				local a = k * 2.1 + 0.4
				local at = V(capAt.X + math.cos(a) * 15, 0, capAt.Z + math.sin(a) * 15)
				at = V(at.X, groundY(at.X, at.Z), at.Z)
				if not kitAt("MushroomCluster", CFrame.new(at) * CFrame.Angles(0, a, 0), 1.6 + 0.3 * k, capOverride) then
					mushroom(at, 0.3 + 0.05 * k, false)
				end
			end
		end)
		table.insert(reservedSpots, { capAt.X, capAt.Z, island.R + 8 })

		-- Teal crystal spires rising out of the glowpool round the island, and a stand of them beside the
		-- Glowpool Shore's east camp.
		for _, c in { { 44, -60, 0.42, 0.6 }, { -40, -6, 0.36, 2.2 }, { 30, 12, 0.3, 4.1 }, { -46, -70, 0.3, 1.1 }, { 10, -86, 0.26, 3.3 } } do
			crystal(V(c[1], groundY(c[1], c[2]), c[2]), c[3], c[4])
		end
		for _, c in { { 150, 124, 0.38, 0.4 }, { 158, 102, 0.3, 2.6 }, { 138, 132, 0.24, 4.4 } } do
			crystal(V(c[1], groundY(c[1], c[2]), c[2]), c[3], c[4])
		end

		-- Glowing pad-caps floating on the glowpool round the island.
		padCaps(island.X, island.Z, 28, 58, 14, 606)
		end -- floor 6 (Elder Cap, glowpool)

		-- 2. The oculus (Floor 6: over the Skylight Dais; Floor 7: over the Netted Isle): a fringe of dangling
		-- roots round its rim (Floor 7: glowing threads, the nets' drip) and a pale cyan shaft that fades out
		-- above every camp band under it, so camp clearance leaves it.
		local sky = layout.Skylight
		if sky then
			group("CavernSkylight", function()
				local rimY = h - 0.5
				for k = 0, 9 do
					local a = (k + 0.5) * math.pi * 2 / 10
					local at = V(sky.X + math.cos(a) * (sky.Radius + 3), 0, sky.Z + math.sin(a) * (sky.Radius + 3))
					local facing = math.atan2(sky.X - at.X, sky.Z - at.Z)
					local fringeH = KitProps.Size("HangingRootFringe").Y
					local base = V(at.X, rimY - fringeH + 1.5, at.Z)
					local fringe = if fungalFloor == 7
						then { WOOD = { Color = rgb(150, 236, 240), Material = Enum.Material.SmoothPlastic, Transparency = 0.25 }, MOSS = { Color = rgb(196, 112, 255), Material = Enum.Material.Neon } }
						elseif fungalFloor == 9
						then { WOOD = { Color = rgb(40, 32, 44) }, MOSS = { Color = rgb(70, 88, 62) }, GLOW = { Color = rgb(172, 238, 78) } }
						elseif fungalFloor == 10
						then { WOOD = { Color = rgb(216, 206, 242), Material = Enum.Material.Fabric }, MOSS = { Color = rgb(112, 242, 255), Material = Enum.Material.Neon }, GLOW = { Color = rgb(214, 116, 255), Material = Enum.Material.Neon } }
						else { WOOD = { Color = rgb(40, 32, 44) }, MOSS = { Color = rgb(70, 92, 120) } }
					if not kitAt("HangingRootFringe", CFrame.new(base) * CFrame.Angles(0, facing, 0), 1.05, fringe) then
						for j = -2, 2 do
							local top = V(at.X, rimY, at.Z) + V(math.cos(a + math.pi / 2), 0, math.sin(a + math.pi / 2)) * (j * 6)
							local rootCol = if fungalFloor == 10 then rgb(216, 206, 242) else rgb(40, 32, 44)
							local rootMat = if fungalFloor == 10 then Enum.Material.Fabric else Enum.Material.Wood
							beam("SkylightHangingRoot", top, top - V(0, 14 + (j % 3) * 7, 0), 1.6, rootCol, rootMat)
						end
					end
				end
				local shaftTop = h - 2
				local shaftBottom = math.max(apex.Y, crossing.Y) + 26
				local shaftColor = if fungalFloor == 9 then rgb(176, 232, 128) elseif fungalFloor == 10 then rgb(138, 244, 255) else rgb(176, 238, 255)
				local shaft = cyl("SkylightShaftBeam", V(sky.X, (shaftTop + shaftBottom) / 2, sky.Z), sky.Radius * 0.62, shaftTop - shaftBottom, shaftColor, Enum.Material.SmoothPlastic, 0.9)
				shaft.CFrame = CFrame.new(origin + V(sky.X, (shaftTop + shaftBottom) / 2, sky.Z)) * CFrame.Angles(0, 0, math.pi / 2)
			end)
		end

		-- 3. The Crown Cluster (Floor 6): colossal caps growing on the cliff above and behind the dais, framed
		-- by the oculus. Each stands where the cliff is (the field), sized to the headroom under the vault.
		if fungalFloor == 6 then group("CrownCluster", function()
			onTerrain()
			for i, c in { { -34, -201, 1.35 }, { 30, -199, 1.15 }, { -86, -196, 0.85 }, { 84, -194, 0.8 }, { 2, -206, 0.95 } } do
				local y = groundY(c[1], c[2])
				local headroom = h - 8 - y
				local s = math.min(c[3], headroom / 50)
				if s > 0.35 then
					if not kitAt("GiantMushroom", CFrame.new(c[1], y - 1, c[2]) * CFrame.Angles(0, i * 1.3, 0), s, capOverride) then
						mushroom(V(c[1], y, c[2]), s, false)
					end
				end
			end
		end) end

		-- 4. A bridge deck (`Terrain.DeckThickness`; Floor 6's Veinspan): arched slate piers under the deck,
		-- standing in its pool, with arch rings on both faces (Floor 6 adds a parapet and corner lamp-posts).
		local cross = layout.Platforms.Crossing
		local deckBottom = cross.Y - ((layout.Terrain and layout.Terrain.DeckThickness and layout.Terrain.DeckThickness.Crossing) or 3)
		local bed = if field then field.Bottom - 3 else bottom
		local xW, xE = cross.X - cross.Width / 2, cross.X + cross.Width / 2
		local zN, zS = cross.Z - cross.Depth / 2, cross.Z + cross.Depth / 2
		if layout.Terrain and layout.Terrain.DeckThickness and layout.Terrain.DeckThickness.Crossing then group("VeinspanArches", function()
			-- Piers stand across the deck's short side, spaced along its long side (Floor 6's Veinspan runs
			-- north-south, Floor 8's aqueduct east-west), with arch rings on both long faces.
			local alongZ = cross.Depth >= cross.Width
			local long, short = if alongZ then cross.Depth else cross.Width, if alongZ then cross.Width else cross.Depth
			local count = math.max(3, math.floor((long - 8) / 26) + 1)
			local piers = {}
			for i = 0, count - 1 do
				table.insert(piers, -long / 2 + 4 + (long - 8) * i / (count - 1))
			end
			local function at(a: number, b: number, y: number): Vector3
				-- a: along the long side, b: across it (both relative to the deck's centre)
				return if alongZ then V(cross.X + b, y, cross.Z + a) else V(cross.X + a, y, cross.Z + b)
			end
			local pierH = deckBottom - bed
			for _, pa in piers do
				local pier = block("VeinspanArchPier", if alongZ then V(short - 2, pierH, 6) else V(6, pierH, short - 2), at(pa, 0, (deckBottom + bed) / 2), slateDark, Enum.Material.Slate)
				pier.CastShadow = true
			end
			for i = 1, #piers - 1 do
				local mid = (piers[i] + piers[i + 1]) / 2
				local span = math.abs(piers[i + 1] - piers[i]) - 6
				for _, sb in { -short / 2 + 0.6, short / 2 - 0.6 } do
					-- Crowns 1.5 under the deck, below any camp's band on the deck (camp clearance would take them).
					ring("VeinspanArchRing", at(mid, sb, deckBottom - span * 0.5 - 1.5), span * 0.5, 2.2, cobble, Enum.Material.Cobblestone,
						if alongZ then CFrame.Angles(0, math.pi / 2, 0) else CFrame.identity, 0, math.pi, 10)
				end
			end
			-- The Veinweb climbing the piers.
			for _, pa in piers do
				for _, sb in { -1, 1 } do
					local foot = at(pa + 3.2, sb * (short / 2 - 8), bed + 0.5)
					local cf = if alongZ then CFrame.new(foot) else CFrame.new(foot) * CFrame.Angles(0, math.pi / 2, 0)
					if not kitAt("MyceliumVein", cf, 0.45, { STEM = { Color = rgb(150, 140, 190) } }) then
						beam("MyceliumVein", foot, foot + V(0, pierH - 2, 0), 0.6, cyan, Enum.Material.Neon)
					end
				end
			end
		end) end
		if fungalFloor == 6 then
		-- Each wall is its own prop, and stops short of the landings at the bridge's ends (the stair from the
		-- warren lands on the south of the deck, the steps to the dais leave from its west side).
		local function wall(ax: number, az: number, bx: number, bz: number)
			group("VeinspanParapet", function()
				local a, b = V(ax, cross.Y + 1.5, az), V(bx, cross.Y + 1.5, bz)
				local p = block("VeinspanParapetWall", V(1.6, 3, (b - a).Magnitude), (a + b) / 2, slate, Enum.Material.Slate)
				p.CFrame = CFrame.lookAt(origin + (a + b) / 2, origin + b)
				local cap = block("VeinspanParapetCap", V(2.2, 0.5, (b - a).Magnitude + 0.6), (a + b) / 2 + V(0, 1.7, 0), cobble, Enum.Material.Cobblestone)
				cap.CFrame = CFrame.lookAt(origin + (a + b) / 2 + V(0, 1.7, 0), origin + b + V(0, 1.7, 0))
			end)
		end
		wall(xE - 0.8, zS - 26, xE - 0.8, zN + 2) -- east side, north of the stair's landing
		wall(xW + 24, zN + 0.8, xE - 2, zN + 0.8) -- north end
		wall(xW + 0.8, zS - 2, xW + 0.8, zS - 12) -- west side, south of the steps to the dais
		for _, c in { { xW + 3, zS - 3 }, { xE - 3, zN + 3 } } do
			local at = V(c[1], cross.Y, c[2])
			lampPost(at, yawToward(at, V(cross.X, cross.Y, cross.Z)), 1.1)
		end
		-- Lamp-posts guarding the arrival ramp at the Glowpool Shore's edge.
		for _, sx in { -1, 1 } do
			lampPost(V(sx * 30, basin.Y, basin.Z + basin.Depth / 2 - 6), math.pi, 1.2)
		end

		-- 5. The Chanters' candle altar in the far corner of their terrace, facing its camp.
		local west = layout.Platforms.WestGallery
		local altarAt = V(west.X - west.Width / 2 + 12, west.Y, west.Z - west.Depth / 2 + 10)
		group("CandleAltar", function()
			local yaw = yawToward(altarAt, V(west.X, west.Y, west.Z))
			if not kitAt("CandleAltar", CFrame.new(altarAt) * CFrame.Angles(0, yaw, 0), 1, { TRIM = { Color = slate, Material = Enum.Material.Slate } }) then
				local cf = CFrame.new(altarAt) * CFrame.Angles(0, yaw, 0)
				for i, size in { V(15, 1.4, 11), V(11.6, 1.4, 8), V(8.2, 1.4, 5.2) } do
					local step = block("AltarDaisStep", size, V(0, 0, 0), slate, Enum.Material.Slate)
					step.CFrame = CFrame.new(origin) * cf * CFrame.new(0, 0.7 + 1.4 * (i - 1), -(i - 1))
				end
				local wheel = cyl("AltarGillWheel", V(0, 0, 0), 3, 0.6, rgb(118, 78, 215), Enum.Material.Slate)
				wheel.CFrame = CFrame.new(origin) * cf * CFrame.new(0, 9, -4) * CFrame.Angles(0, math.pi / 2, 0)
				for k = 1, 10 do
					orb("AltarCandleFlame", cf:PointToWorldSpace(V(((k % 5) - 2) * 2.6, 1.6 + 1.4 * (k % 2), 3 - (k % 3))), V(0.4, 0.7, 0.4), rgb(255, 198, 122), Enum.Material.Neon)
				end
			end
			local glow = orb("AltarCandleGlow", altarAt + V(0, 4, 0), V(1, 1, 1), rgb(255, 198, 122), Enum.Material.SmoothPlastic, 1)
			pointLight(glow, rgb(255, 190, 110), 1.2, 30)
		end)
		table.insert(reservedSpots, { altarAt.X, altarAt.Z, 12 })

		-- 6. The Skitter Warren: egg-sacs against the cliff along the warren's east edge, and grazed veins (dull,
		-- their bulbs eaten) on the ground nearby.
		local east = layout.Platforms.EastGallery
		for i, c in { { east.X + east.Width / 2 - 6, east.Z - 26 }, { east.X + east.Width / 2 - 5, east.Z + 30 }, { east.X + east.Width / 2 - 14, east.Z - 34 } } do
			group("EggSacCluster", function()
				onTerrain()
				local at = V(c[1], east.Y, c[2])
				if not kitAt("EggSacCluster", CFrame.new(at) * CFrame.Angles(0, i * 2.2, 0), 1.1 + 0.15 * i, { CRYSTAL = { Color = rgb(200, 176, 236), Material = Enum.Material.Glass, Transparency = 0.35 } }) then
					for k = 1, 5 do
						orb("EggSac", at + V((k % 3 - 1) * 1.8, 1.4 + (k % 2) * 1.2, (k % 2) * 1.6 - 0.8), V(2.2, 2.8, 2.2), rgb(200, 176, 236), Enum.Material.Glass, 0.35)
					end
				end
			end)
			table.insert(reservedSpots, { c[1], c[2], 6 })
		end
		for i, c in { { east.X - 6, east.Z + east.Depth / 2 + 10 }, { 150, 70 } } do
			group("GrazedVein", function()
				onTerrain()
				local at = V(c[1], groundY(c[1], c[2]) + 0.1, c[2])
				kitAt("MyceliumVein", CFrame.new(at) * CFrame.Angles(-math.pi / 2, i * 1.7, 0), 0.6, { GLOW = { Color = rgb(40, 70, 82), Material = Enum.Material.SmoothPlastic } })
			end)
		end

		-- 7. Falls from the north-west and north-east cliffs into their pools, each set against the cliff face
		-- (found from the field) and facing into the room, away from every ramp.
		if field then
			for _, f in { { X = -168, Z = -92, Dir = 1 }, { X = 172, Z = -64, Dir = -1 } } do
				local x = f.X
				for _ = 1, 24 do
					local nx = x - f.Dir * 2
					if field.Height(nx, f.Z) > liquid + 34 or math.abs(nx) > w / 2 - 4 then break end
					x = nx
				end
				local top = math.min(field.Height(x - f.Dir * 2, f.Z), liquid + 40)
				waterfall(V(x + f.Dir * 1.5, liquid - 0.4, f.Z), 12, top - liquid, rgb(86, 196, 210), if f.Dir > 0 then math.pi / 2 else -math.pi / 2)
			end
		end
		end -- floor 6 (parapets, lamps, altar, warren, falls)

		if fungalFloor == 7 then
			local east, west = layout.Platforms.EastGallery, layout.Platforms.WestGallery
			local niches = 0
			-- 1. Lamp niches cut along the galleries' cliff-side edges, facing in. The Lower Lamp Gallery still
			-- burns; the Upper Lamp Gallery's lamps are mostly dead (dark bulbs, dull gill-lines).
			local function niche(at: Vector3, yaw: number, lit: boolean, light: boolean)
				group("LampNiche", function()
					onTerrain()
					local o: any = { TRIM = { Color = slate, Material = Enum.Material.Slate } }
					if not lit then
						o.BULB, o.GLOW = deadLamp.BULB, deadLamp.GLOW
					end
					if not kitAt("LampNiche", CFrame.new(at) * CFrame.Angles(0, yaw, 0), 1.3, o) then
						local cf = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
						local slab = block("LampNicheSlab", V(16, 18, 3), V(0, 0, 0), slate, Enum.Material.Slate)
						slab.CFrame = CFrame.new(origin) * cf * CFrame.new(0, 9, -2.5)
						orb("LampNicheBulb", cf:PointToWorldSpace(V(0, 11, 0.5)), V(1.6, 2, 1.6), if lit then rgb(255, 198, 122) else rgb(58, 48, 72), if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic)
					end
					if light then
						local glow = orb("LampNicheGlow", at + V(0, 10, 0), V(1, 1, 1), rgb(255, 198, 122), Enum.Material.SmoothPlastic, 1)
						pointLight(glow, rgb(255, 190, 110), 1.1, 34)
					end
				end)
				niches += 1
				table.insert(reservedSpots, { at.X, at.Z, 9 })
			end
			local ex = east.X + east.Width / 2 - 3
			niche(V(ex, east.Y, east.Z - 26), -math.pi / 2, true, false)
			niche(V(ex, east.Y, east.Z), -math.pi / 2, true, true)
			local wx = west.X - west.Width / 2 + 3
			niche(V(wx, west.Y, west.Z - 26), math.pi / 2, false, false)
			niche(V(wx, west.Y, west.Z), math.pi / 2, true, true)
			niche(V(wx, west.Y, west.Z + 26), math.pi / 2, false, false)
			-- The Chanters' candle altar in the lower gallery's far corner, facing its camp.
			local altarAt = V(east.X + east.Width / 2 - 10, east.Y, east.Z + east.Depth / 2 - 8)
			group("CandleAltar", function()
				if not kitAt("CandleAltar", CFrame.new(altarAt) * CFrame.Angles(0, yawToward(altarAt, V(east.X, east.Y, east.Z)), 0), 0.9, { TRIM = { Color = slate, Material = Enum.Material.Slate } }) then
					block("AltarDaisStep", V(12, 2, 9), altarAt + V(0, 1, 0), slate, Enum.Material.Slate)
				end
			end)
			table.insert(reservedSpots, { altarAt.X, altarAt.Z, 11 })

			-- 2. The Netted Isle: Veinweb nets strung on stalks standing in the span pool round the isle (east side,
			-- north end, and the north-east toward the vault), and shelf-fungus clumps on its rocky shore.
			local cross = layout.Platforms.Crossing
			for _, n in {
				{ cross.X + cross.Width / 2 + 10, cross.Z, -math.pi / 2 },
				{ cross.X + 6, cross.Z - cross.Depth / 2 - 10, 0 },
				{ cross.X + cross.Width / 2 + 6, cross.Z - cross.Depth / 2 - 4, -math.pi / 4 },
			} do
				group("MyceliumNet", function()
					onTerrain()
					local at = V(n[1], groundY(n[1], n[2]), n[2])
					if not kitAt("MyceliumNet", CFrame.new(at + V(0, -0.4, 0)) * CFrame.Angles(0, n[3], 0), 1.2, { STEM = { Color = rgb(176, 170, 206) } }) then
						local cf = CFrame.new(at) * CFrame.Angles(0, n[3], 0)
						for _, sx in { -1, 1 } do
							beam("NetStalk", cf:PointToWorldSpace(V(sx * 14, 0, 0)), cf:PointToWorldSpace(V(sx * 14, 17, 0)), 1.6, rgb(176, 170, 206), Enum.Material.SmoothPlastic)
						end
						for r = 1, 4 do
							beam("NetStrand", cf:PointToWorldSpace(V(-14, 4 + r * 3, 0)), cf:PointToWorldSpace(V(14, 4 + r * 3, 0)), 0.2, cyan, Enum.Material.Neon)
						end
					end
				end)
				table.insert(reservedSpots, { n[1], n[2], 15 })
			end
			-- The shore: clumps of caps on the isle's rocky slopes, out where its rounded corners fall away (past
			-- the camp's reach), each on the ground the field gives there.
			for k = 0, 7 do
				local a = (k + 0.5) * math.pi / 4
				local r = cross.Width / 2 + 7 + (k % 3) * 2
				local x, z = cross.X + math.cos(a) * r, cross.Z + math.sin(a) * r
				group("IsleShoreFungi", function()
					onTerrain()
					local at = V(x, groundY(x, z), z)
					if not kitAt("MushroomCluster", CFrame.new(at) * CFrame.Angles(0, a * 1.7, 0), 1.1 + 0.15 * (k % 3), capOverride) then
						mushroom(at, 0.25, false)
					end
				end)
			end
			padCaps(cross.X, cross.Z, 30, 46, 10, 707)
			for _, pool in (layout.Terrain and layout.Terrain.Pools) or {} do
				if pool.X ~= cross.X or pool.Z ~= cross.Z then
					padCaps(pool.X, pool.Z, 2, math.min(pool.RX, pool.RZ) - 4, 3, math.floor(pool.X * 7 + pool.Z))
				end
			end

			-- 3. The Lantern Vault: dead lamp-posts round the dais and the one living lamp, a colossal post at its
			-- back corner (clear of the boss portals and the paths in).
			for _, c in { { apex.X + apex.Width / 2 - 4, apex.Z - apex.Depth / 2 + 4 }, { apex.X + apex.Width / 2 - 4, apex.Z + apex.Depth / 2 - 4 }, { apex.X - apex.Width / 2 + 4, apex.Z - apex.Depth / 2 + 4 } } do
				local at = V(c[1], apex.Y, c[2])
				lampPost(at, yawToward(at, V(apex.X, apex.Y, apex.Z)), 1.4, true)
			end
			local livingAt = V(apex.X - apex.Width / 2 + 10, apex.Y, apex.Z - 20)
			-- The Lampkeepers' trail begins here: the living lamp is theirs (a warm flame among the dead violet
			-- bulbs), and their chalk sign beside it points up.
			lampPost(livingAt, yawToward(livingAt, V(apex.X, apex.Y, apex.Z)), 2.6, false, true)
			chalkSign(livingAt + V(7, 0, 4), yawToward(livingAt, V(apex.X, apex.Y, apex.Z)))
			local livingGlow = orb("LivingLampGlow", livingAt + V(0, 26, 0), V(1, 1, 1), flameWarm, Enum.Material.SmoothPlastic, 1)
			pointLight(livingGlow, rgb(255, 178, 110), 1.6, 70)
			table.insert(reservedSpots, { livingAt.X, livingAt.Z, 10 })

			-- 4. The Drip Hall: dangling roots hanging from the vault over the hall (they hang high, above every
			-- path and camp), crystal stands by the hall's east camp and egg-sacs by its west camp.
			for i, c in { { -110, basin.Z - 10 }, { 104, basin.Z - 2 }, { -40, basin.Z + 30 }, { 52, basin.Z + 34 }, { 0, basin.Z - 40 } } do
				group("CeilingRoots", function()
					local fringeH = KitProps.Size("HangingRootFringe").Y
					local base = V(c[1], h - fringeH * 1.1 + 2, c[2])
					if not kitAt("HangingRootFringe", CFrame.new(base) * CFrame.Angles(0, i * 1.9, 0), 1.1, { WOOD = { Color = rgb(40, 32, 44) }, MOSS = { Color = rgb(70, 92, 120) } }) then
						for j = -2, 2 do
							local top = V(c[1] + j * 6, h - 0.5, c[2])
							beam("CeilingHangingRoot", top, top - V(0, 12 + (j % 3) * 6, 0), 1.4, rgb(40, 32, 44), Enum.Material.Wood)
						end
					end
				end)
			end
			for _, c in { { 158, 150, 0.36, 0.7 }, { 162, 86, 0.3, 2.1 }, { 146, 156, 0.24, 3.9 } } do
				crystal(V(c[1], groundY(c[1], c[2]), c[2]), c[3], c[4])
			end
			for i, c in { { -160, 88 }, { -156, 154 } } do
				group("EggSacCluster", function()
					onTerrain()
					local at = V(c[1], groundY(c[1], c[2]), c[2])
					if not kitAt("EggSacCluster", CFrame.new(at) * CFrame.Angles(0, i * 2.4, 0), 1.2, { CRYSTAL = { Color = rgb(200, 176, 236), Material = Enum.Material.Glass, Transparency = 0.35 } }) then
						orb("EggSac", at + V(0, 1.6, 0), V(2.6, 3.2, 2.6), rgb(200, 176, 236), Enum.Material.Glass, 0.35)
					end
				end)
				table.insert(reservedSpots, { c[1], c[2], 6 })
			end
			kit:SetAttribute("LampNiches", niches)
		end

		-- Lampkeeper camp helpers shared by Floors 8 and 9.
		local canvas = rgb(176, 160, 132)
		local rope = rgb(150, 128, 96)
		local supplies = { FOLIAGE = { Color = canvas, Material = Enum.Material.Fabric }, WOOD = { Color = rgb(104, 80, 62), Material = Enum.Material.WoodPlanks }, TRIM = { Color = slate, Material = Enum.Material.Slate } }
		local shelterO = { CAP = { Color = violet }, STEM = { Color = rgb(196, 150, 236) }, FOLIAGE = { Color = canvas, Material = Enum.Material.Fabric }, WOOD = { Color = rgb(104, 80, 62), Material = Enum.Material.Wood }, GLOW = { Color = rgb(90, 160, 170), Material = Enum.Material.SmoothPlastic } }
		local function piece(kind: string, name: string, at: Vector3, yaw: number, s: number, o: any, fallback: () -> (), tilt: CFrame?, after: (() -> ())?)
			group(kind, function()
				onTerrain()
				if not kitAt(name, CFrame.new(at) * CFrame.Angles(0, yaw, 0) * (tilt or CFrame.identity), s, o) then
					fallback()
				end
				if after then
					after()
				end
			end)
			table.insert(reservedSpots, { at.X, at.Z, 7 * s })
		end
		local function shelter(at: Vector3, yaw: number, crushed: boolean?)
			piece("CapShelter", "CapShelter", at, yaw, 1, shelterO, function()
				local cf = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
				local roof = block("ShelterCapRoof", V(13, 0.6, 9), V(0, 0, 0), violet, Enum.Material.SmoothPlastic)
				roof.CFrame = CFrame.new(origin) * cf * CFrame.new(0, 3.4, 0) * CFrame.Angles(-0.6, 0, 0)
				for _, sx in { -1, 1 } do
					beam("ShelterPole", cf:PointToWorldSpace(V(sx * 5, 0, 3.6)), cf:PointToWorldSpace(V(sx * 5, 6.6, 3.6)), 0.5, rgb(104, 80, 62), Enum.Material.Wood)
				end
			end, if crushed then CFrame.Angles(0.35, 0, 0.18) else nil)
		end
		local function cache(at: Vector3, yaw: number)
			piece("CampSupplies", "CampSupplies", at, yaw, 1, supplies, function()
				block("SupplyCrate", V(2.2, 1.6, 1.8), at + V(0, 0.8, 0), rgb(104, 80, 62), Enum.Material.WoodPlanks)
				orb("SupplySack", at + V(1.8, 0.8, 0.4), V(1.6, 1.8, 1.4), canvas, Enum.Material.Fabric)
			end)
		end

		if fungalFloor == 8 then
			local west, east = layout.Platforms.WestGallery, layout.Platforms.EastGallery
			local cross = layout.Platforms.Crossing
			local coldFire = { CANDLE = { Color = rgb(52, 44, 50), Material = Enum.Material.Slate }, CRYSTAL = { Color = rgb(90, 120, 130), Material = Enum.Material.Glass, Transparency = 0.4 }, TRIM = { Color = slate, Material = Enum.Material.Slate } }
			local warmFire = { CANDLE = { Color = flameWarm, Material = Enum.Material.Neon }, CRYSTAL = { Color = teal, Material = Enum.Material.Glass, Transparency = 0.25 }, TRIM = { Color = slate, Material = Enum.Material.Slate } }
			local function brazier(at: Vector3, lit: boolean)
				piece("CrystalBrazier", "CrystalBrazier", at, 0, 1.1, if lit then warmFire else coldFire, function()
					cyl("BrazierRing", at + V(0, 0.6, 0), 2.2, 1.2, slate, Enum.Material.Slate)
					if lit then orb("BrazierFlame", at + V(0, 1.6, 0), V(1, 2, 1), flameWarm, Enum.Material.Neon) end
				end)
			end

			-- 1. The Violet Cap: the round cap top (TowerRoomBuilder) gets its curled lip, glowing gills and ribs
			-- beneath, spots out toward its rim (past the camp's reach), and a stout stem down into its pool.
			local capR = math.sqrt(west.Width ^ 2 + west.Depth ^ 2) / 2 + 1
			local capTop = V(west.X, west.Y, west.Z)
			local stemBed = if field then field.Bottom - 3 else bottom
			-- The curled lip is a ring of separate segments, so clearance drops only those under a walkway (the
			-- walkways then seem to arrive through gaps in the lip) and never takes the whole cap's dressing.
			local lipSegments = 20
			for k = 0, lipSegments - 1 do
				local a0, a1 = k * 2 * math.pi / lipSegments, (k + 1) * 2 * math.pi / lipSegments
				local r = capR + 1.2
				group("VioletCapLip", function()
					local seg = beam("VioletCapLip", capTop + V(math.cos(a0) * r, -3.6, math.sin(a0) * r), capTop + V(math.cos(a1) * r, -3.6, math.sin(a1) * r), 2.4, rgb(78, 44, 150), Enum.Material.SmoothPlastic)
					seg.CastShadow = true
				end)
			end
			group("VioletCapGills", function()
				-- Flat ellipsoids, not upright cylinders: camp clearance measures a part's unrotated size, and an
				-- upright cylinder's diameter would count as its height.
				orb("VioletCapGills", capTop - V(0, 4.9, 0), V((capR - 2) * 2, 0.6, (capR - 2) * 2), cyan, Enum.Material.Neon, 0.3)
				for k = 0, 23 do
					local a = k * math.pi / 12
					local r0, r1 = 14, capR - 3
					beam("VioletCapGillRib", capTop + V(math.cos(a) * r0, -4.6, math.sin(a) * r0), capTop + V(math.cos(a) * r1, -4.2, math.sin(a) * r1), 0.4, cyan, Enum.Material.Neon)
				end
			end)
			group("VioletCap", function()
				local stemH = (west.Y - 5) - stemBed
				-- A swollen stem (an ellipsoid running from the pool bed up into the cap) on a broad foot.
				-- Its top stays under the cap's camp band (camp clearance); the gill disc hides the join.
				local stem = orb("VioletCapStemIsland", V(west.X, stemBed + stemH / 2, west.Z), V(26, stemH + 2, 26), rgb(176, 170, 206), Enum.Material.SmoothPlastic)
				stem.CastShadow = true
				orb("VioletCapStemFoot", V(west.X, stemBed + 2, west.Z), V(36, 5, 36), rgb(150, 142, 182), Enum.Material.SmoothPlastic)
				for k = 0, 5 do
					local a = k * math.pi / 3 + 0.3
					beam("VioletCapRoot", V(west.X + math.cos(a) * 12, stemBed + 3, west.Z + math.sin(a) * 12), V(west.X + math.cos(a) * 24, stemBed + 0.5, west.Z + math.sin(a) * 24), 2.2, rgb(150, 142, 182), Enum.Material.SmoothPlastic)
				end
			end)
			for k = 0, 9 do
				local a = k * math.pi / 5 + 0.2
				local r = 36 + (k % 3) * 2.5
				group("VioletCapSpot", function()
					cyl("VioletCapSpotDisc", capTop + V(math.cos(a) * r, 0.06, math.sin(a) * r), 1.6 + (k % 2) * 0.8, 0.12, rgb(196, 150, 236), Enum.Material.SmoothPlastic)
				end)
			end
			table.insert(reservedSpots, { west.X, west.Z, capR + 4 })

			-- 2. The Old Aqueduct: the broken spans' last piers stand in the chasm under the Lampkeepers' walkways
			-- (their tops well under the planks), and the watch-post: a barricade across the deck's north-west
			-- corner with a dead lamp beside it (the Elite camp holds the deck's middle).
			local bed = if field then field.Bottom - 3 else bottom
			for _, ex in { cross.X - cross.Width / 2 - 22, cross.X + cross.Width / 2 + 22 } do
				group("AqueductBrokenPier", function()
					local topY = math.min(-3, cross.Y - 16)
					block("AqueductRuinPierIsland", V(7, topY - bed, cross.Depth - 6), V(ex, (topY + bed) / 2, cross.Z), slateDark, Enum.Material.Slate)
					block("AqueductRuinPierCap", V(9, 1.2, cross.Depth - 4), V(ex, topY + 0.6, cross.Z), cobble, Enum.Material.Cobblestone)
				end)
			end
			local postAt = V(cross.X - cross.Width / 2 + 8, cross.Y, cross.Z - cross.Depth / 2 + 3)
			piece("Barricade", "Barricade", postAt, 0, 1, { WOOD = { Color = rgb(104, 80, 62), Material = Enum.Material.WoodPlanks }, TRIM = { Color = slate, Material = Enum.Material.Slate }, STEM = { Color = rope, Material = Enum.Material.Fabric } }, function()
				block("BarricadePlanks", V(14, 4, 0.6), postAt + V(0, 2, 0), rgb(104, 80, 62), Enum.Material.WoodPlanks)
			end)
			-- Behind the barricade at the deck's north edge: clear of the aqueduct camp (34+ studs from its centre)
			-- and of the west walkway's landing on the deck.
			lampPost(postAt + V(-4, 0, -2), 0, 1, true)

			-- 3. Lampkeepers' Rest (the Sanctuary): their last lit camp, now the Masters' safe ground. Two cap
			-- shelters open toward the floor at the back corners, a lit brazier and a supply cache, all clear of
			-- the portals, the arrival and the exit lane.
			for _, sx in { -1, 1 } do
				shelter(V(sx * (safe.Width / 2 - 10), safe.Y, safe.Z + safe.Depth / 2 - 9), math.pi)
			end
			local restFire = V(-safe.Width / 2 + 22, safe.Y, safe.Z - 2)
			brazier(restFire, true)
			local restGlow = orb("RestBrazierGlow", restFire + V(0, 3, 0), V(1, 1, 1), flameWarm, Enum.Material.SmoothPlastic, 1)
			pointLight(restGlow, rgb(255, 170, 100), 1.4, 40)
			cache(V(safe.Width / 2 - 22, safe.Y, safe.Z - 2), -math.pi / 2)

			-- 4. The forward camp at the Rim of Blooms' west end: one shelter facing the chasm, a cache, a cold
			-- fire-ring and a dead lamp. They left it.
			local fx, fz = basin.X - basin.Width / 2 + 24, basin.Z + 14
			shelter(V(fx, basin.Y, fz), math.pi)
			cache(V(fx + 14, basin.Y, fz + 8), 0.6)
			brazier(V(fx + 8, basin.Y, fz - 12), false)
			lampPost(V(fx - 12, basin.Y, fz - 10), math.pi / 4, 1, true)

			-- 5. The fallen camp on the chasm floor below the Crystal Islet, near the east return ramp: a shelter
			-- crushed under a toppled cap, supplies spilled, its lamp still faintly lit. Only fallers find it.
			local cx, cz = east.X - 22, east.Z + east.Depth / 2 + 32
			local cy = groundY(cx, cz)
			shelter(V(cx, cy, cz), 0.4, true)
			group("ToppledCap", function()
				onTerrain()
				local at = V(cx + 10, cy - 1, cz - 4)
				if not kitAt("GiantMushroom", CFrame.new(at) * CFrame.Angles(0, 1.1, 0) * CFrame.Angles(0, 0, math.rad(78)), 0.42, capOverride) then
					mushroom(at, 0.42, false)
				end
			end)
			cache(V(cx - 8, groundY(cx - 8, cz + 6), cz + 6), 2.2)
			local fallenLamp = V(cx + 4, groundY(cx + 4, cz + 9), cz + 9)
			lampPost(fallenLamp, 0.8, 0.8, false, true)
			local fallenGlow = orb("FallenLampGlow", fallenLamp + V(0, 8, 0), V(1, 1, 1), flameWarm, Enum.Material.SmoothPlastic, 1)
			pointLight(fallenGlow, rgb(255, 160, 90), 0.6, 24)

			-- 6. Chalk signs at the Rim's two walkway heads (beside each walkway, outside its lane) and by the
			-- aqueduct stairs' top on the ledge, all pointing the way up.
			for _, link in layout.Links do
				if link.From == "Basin" and (link.To == "WestGallery" or link.To == "EastGallery") then
					local ux, uz = link.UX, link.UZ
					local side = if link.To == "WestGallery" then 1 else -1
					-- Beside the walkway's landing, clear of it (the landing is 36 wide plus a 3-stud shoulder).
					local at = V(link.AX + uz * side * 30 - ux * 6, basin.Y, link.AZ - ux * side * 30 - uz * 6)
					chalkSign(at, math.atan2(-ux, -uz))
				elseif link.From == "Crossing" and link.To == "Apex" then
					-- On the ledge itself, beside the stairs' landing.
					chalkSign(V(link.BX - 26, apex.Y, apex.Z + apex.Depth / 2 - 5), math.pi)
				end
			end

			-- 7. Teal crystal spires at the Crystal Islet's far corners (past its camp's reach), and pad-caps on the
			-- chasm pools.
			for _, c in { { east.X + east.Width / 2 - 6, east.Z - east.Depth / 2 + 6, 0.42, 0.5 }, { east.X + east.Width / 2 - 8, east.Z + east.Depth / 2 - 6, 0.34, 2.4 }, { east.X + east.Width / 2 - 18, east.Z - east.Depth / 2 + 4, 0.26, 4.1 } } do
				crystal(V(c[1], east.Y, c[2]), c[3], c[4])
			end
			for _, pool in (layout.Terrain and layout.Terrain.Pools) or {} do
				padCaps(pool.X, pool.Z, 4, math.min(pool.RX, pool.RZ) - 3, 6, math.floor(pool.X * 3 + pool.Z * 5))
			end
		end

		if fungalFloor == 9 then
			local west, east = layout.Platforms.WestGallery, layout.Platforms.EastGallery
			local westB, eastB = layout.Platforms.WestBastion, layout.Platforms.EastBastion
			local cross = layout.Platforms.Crossing
			local bed = if field then field.Bottom - 3 else bottom
			local rotGlow = rgb(182, 245, 74)
			local rotBulb = rgb(212, 255, 96)
			local rotCap = rgb(96, 48, 172)
			local rotVioletLight = rgb(152, 82, 238)
			local boneCol = rgb(208, 226, 172)
			local bannerCloth = rgb(112, 38, 68)
			local rotStem = rgb(156, 152, 178)
			local rotMoss = rgb(76, 62, 118)
			local brokenO = { WOOD = { Color = rgb(92, 72, 56), Material = Enum.Material.WoodPlanks }, TRIM = { Color = slate, Material = Enum.Material.Slate }, STEM = { Color = rope, Material = Enum.Material.Fabric }, MOSS = { Color = rotMoss, Material = Enum.Material.Grass }, CAP = { Color = rotCap }, GLOW = { Color = rotGlow, Material = Enum.Material.Neon }, BULB = { Color = rotBulb, Material = Enum.Material.Neon } }
			local vatO = { TRIM = { Color = slate, Material = Enum.Material.Slate }, GLOW = { Color = rotGlow, Material = Enum.Material.Neon }, BULB = { Color = rotBulb, Material = Enum.Material.Neon }, MOSS = { Color = rotMoss, Material = Enum.Material.Grass }, WOOD = { Color = rgb(92, 72, 56), Material = Enum.Material.Wood }, CAP = { Color = rotCap } }
			local boneO = { ALT = { Color = boneCol, Material = Enum.Material.SmoothPlastic }, CAP = { Color = rotCap }, GLOW = { Color = rotGlow, Material = Enum.Material.Neon }, BULB = { Color = rotBulb, Material = Enum.Material.Neon }, STEM = { Color = rotStem }, MOSS = { Color = rotMoss, Material = Enum.Material.Grass } }
			local towerO = { TRIM = { Color = slateDark, Material = Enum.Material.Slate }, ACCENT = { Color = rgb(142, 76, 224), Material = Enum.Material.Slate }, CAP = { Color = rotCap }, GLOW = { Color = rotGlow, Material = Enum.Material.Neon }, BULB = { Color = rotBulb, Material = Enum.Material.Neon }, STEM = { Color = rotStem }, MOSS = { Color = rotMoss, Material = Enum.Material.Grass } }
			local bannerO = { WOOD = { Color = rgb(84, 64, 50), Material = Enum.Material.Wood }, TRIM = { Color = slate, Material = Enum.Material.Slate }, FOLIAGE = { Color = bannerCloth, Material = Enum.Material.Fabric }, ALT = { Color = rgb(224, 218, 228), Material = Enum.Material.SmoothPlastic }, GLOW = { Color = rotGlow, Material = Enum.Material.Neon }, CAP = { Color = rotCap } }
			local clusterO = { CAP = { Color = rotCap }, GLOW = { Color = rotGlow, Material = Enum.Material.Neon }, BULB = { Color = rotBulb, Material = Enum.Material.Neon }, STEM = { Color = rotStem }, MOSS = { Color = rotMoss, Material = Enum.Material.Grass } }

			local function brokenBarricade(at: Vector3, yaw: number, s: number?)
				local sc = s or 1
				piece("BrokenBarricade", "BrokenBarricade", at, yaw, sc, brokenO, function()
					local cf = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
					for _, sx in { -1, 1 } do
						local plank = block("BrokenBarricadePlank", V(5.5 * sc, 3.2 * sc, 0.5), V(0, 0, 0), rgb(92, 72, 56), Enum.Material.WoodPlanks)
						plank.CFrame = CFrame.new(origin) * cf * CFrame.new(sx * 4.5 * sc, 1.6 * sc, 0) * CFrame.Angles(0, 0, sx * 0.25)
						local capPos = cf:PointToWorldSpace(V(sx * 5.2 * sc, 2.3 * sc, -0.4 * sc))
						orb("BrokenBarricadeCap", capPos, V(2.5 * sc, 1.1 * sc, 2.5 * sc), rotCap, Enum.Material.SmoothPlastic)
						orb("BrokenBarricadeGills", capPos - V(0, 0.35 * sc, 0), V(2.0 * sc, 0.5 * sc, 2.0 * sc), rotGlow, Enum.Material.Neon)
						beam("BrokenBarricadeVein", cf:PointToWorldSpace(V(sx * 6.0 * sc, 2.8 * sc, -0.4 * sc)), cf:PointToWorldSpace(V(sx * 2.0 * sc, 0.3 * sc, -1.2 * sc)), 0.22 * sc, rotGlow, Enum.Material.Neon)
					end
				end)
			end
			local function rotVat(at: Vector3, yaw: number, s: number?)
				local sc = s or 1
				piece("RotVat", "RotVat", at, yaw, sc, vatO, function()
					cyl("RotVatBody", at + V(0, 2.0 * sc, 0), 2.8 * sc, 4.0 * sc, slate, Enum.Material.Slate)
					cyl("RotVatBrew", at + V(0, 3.9 * sc, 0), 2.4 * sc, 0.35 * sc, rotGlow, Enum.Material.Neon)
					orb("RotVatBubble", at + V(0.8 * sc, 4.2 * sc, -0.5 * sc), V(1.0, 0.9, 1.0) * sc, rotBulb, Enum.Material.Neon)
					orb("RotVatCap", at + V(-2.7 * sc, 2.0 * sc, -0.8 * sc), V(2.0 * sc, 0.9 * sc, 2.0 * sc), rotCap, Enum.Material.SmoothPlastic)
					beam("RotVatSpill", at + V(0.5 * sc, 3.8 * sc, -2.3 * sc), at + V(0.7 * sc, 0.2 * sc, -3.0 * sc), 0.35 * sc, rotGlow, Enum.Material.Neon)
				end)
			end
			local function ossuaryBones(at: Vector3, yaw: number, s: number?)
				local sc = s or 1
				piece("OssuaryBones", "OssuaryBones", at, yaw, sc, boneO, function()
					local cf = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
					orb("OssuarySkull", cf:PointToWorldSpace(V(-0.4 * sc, 1.8 * sc, -2.0 * sc)), V(3.6, 3.2, 4.0) * sc, boneCol, Enum.Material.SmoothPlastic)
					for _, sx in { -1, 1 } do
						orb("OssuaryEyeRot", cf:PointToWorldSpace(V((-0.4 + sx * 0.7) * sc, 2.1 * sc, -3.5 * sc)), V(0.7, 0.7, 0.7) * sc, rotBulb, Enum.Material.Neon)
					end
					for k = -1, 1 do
						local rib = block("OssuaryRib", V(8 * sc, 4 * sc, 0.8 * sc), V(0, 0, 0), boneCol, Enum.Material.SmoothPlastic)
						rib.CFrame = CFrame.new(origin) * cf * CFrame.new(0, 2.4 * sc, k * 2.2 * sc)
					end
					local capAt = cf:PointToWorldSpace(V(1.6 * sc, 4.4 * sc, 0.6 * sc))
					beam("OssuaryStem", cf:PointToWorldSpace(V(1.4 * sc, 0.2 * sc, 0.6 * sc)), capAt, 0.9 * sc, rotStem, Enum.Material.SmoothPlastic)
					orb("OssuaryCap", capAt + V(0, 0.6 * sc, 0), V(4.2 * sc, 1.5 * sc, 4.2 * sc), rotCap, Enum.Material.SmoothPlastic)
					cyl("OssuaryCapGills", capAt, 1.8 * sc, 0.4 * sc, rotGlow, Enum.Material.Neon)
				end)
			end
			local function rotcapTower(at: Vector3, yaw: number, s: number?, tilt: CFrame?)
				local sc = s or 1
				piece("RotcapTower", "RotcapTower", at, yaw, sc, towerO, function()
					local cf = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
					local shaft = block("RotcapTowerShaft", V(8 * sc, 20 * sc, 8 * sc), V(0, 0, 0), slateDark, Enum.Material.Slate)
					shaft.CFrame = CFrame.new(origin) * cf * CFrame.new(0, 10 * sc, 0)
					local capA = cf:PointToWorldSpace(V(-3.4 * sc, 13.0 * sc, -2.8 * sc))
					orb("RotcapTowerCap", capA, V(8.4 * sc, 3.0 * sc, 8.4 * sc), rotCap, Enum.Material.SmoothPlastic)
					cyl("RotcapTowerGills", capA - V(0, 0.9 * sc, 0), 3.6 * sc, 0.6 * sc, rotGlow, Enum.Material.Neon)
					local capB = cf:PointToWorldSpace(V(1.2 * sc, 20.6 * sc, -1.0 * sc))
					orb("RotcapTowerCrown", capB, V(7.6 * sc, 2.8 * sc, 7.6 * sc), rotCap, Enum.Material.SmoothPlastic)
					cyl("RotcapTowerCrownGills", capB - V(0, 0.8 * sc, 0), 3.2 * sc, 0.5 * sc, rotGlow, Enum.Material.Neon)
					for k = -1, 1 do
						beam("RotcapTowerVein", cf:PointToWorldSpace(V(k * 2.4 * sc, 0.2 * sc, -4.1 * sc)), cf:PointToWorldSpace(V(k * 2.0 * sc, 18.0 * sc, -4.1 * sc)), 0.35 * sc, rotGlow, Enum.Material.Neon)
					end
				end, tilt)
			end
			local function velmariBanner(at: Vector3, yaw: number, s: number?)
				local sc = s or 1
				piece("VelmariBanner", "VelmariBanner", at, yaw, sc, bannerO, function()
					block("BannerBase", V(2.4 * sc, 1 * sc, 2.4 * sc), at + V(0, 0.5 * sc, 0), slate, Enum.Material.Slate)
					beam("BannerPole", at + V(0, 0.8 * sc, 0), at + V(0, 13.5 * sc, 0), 0.5 * sc, rgb(84, 64, 50), Enum.Material.Wood)
					local cloth = block("BannerCloth", V(4.2 * sc, 7.6 * sc, 0.3), V(0, 0, 0), bannerCloth, Enum.Material.Fabric)
					cloth.CFrame = CFrame.new(origin) * CFrame.new(at) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 8.2 * sc, 0.4)
					orb("BannerCrestGlow", (CFrame.new(at) * CFrame.Angles(0, yaw, 0)):PointToWorldSpace(V(0, 8.4 * sc, 0.65)), V(1.2 * sc, 1.2 * sc, 0.35), rotGlow, Enum.Material.Neon)
					orb("BannerBaseCap", at + V(0.8 * sc, 1.2 * sc, 0.6 * sc), V(1.8 * sc, 0.8 * sc, 1.8 * sc), rotCap, Enum.Material.SmoothPlastic)
				end)
			end
			local function rotcapCluster(at: Vector3, yaw: number, s: number?)
				local sc = s or 1
				piece("RotcapCluster", "RotcapCluster", at, yaw, sc, clusterO, function()
					local cf = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
					for _, sub in { { 0, 7.0, 0, 3.4 }, { -2.4, 4.8, -1.2, 2.2 }, { 2.4, 5.2, -1.0, 2.4 } } do
						local base = cf:PointToWorldSpace(V(sub[1] * 0.4 * sc, 0.2 * sc, sub[3] * 0.4 * sc))
						local top = cf:PointToWorldSpace(V(sub[1] * sc, sub[2] * sc, sub[3] * sc))
						beam("RotcapClusterStem", base, top, sub[4] * 0.35 * sc, rotStem, Enum.Material.SmoothPlastic)
						orb("RotcapClusterDome", top + V(0, sub[4] * 0.28 * sc, 0), V(sub[4] * 2 * sc, sub[4] * 0.9 * sc, sub[4] * 2 * sc), rotCap, Enum.Material.SmoothPlastic)
						cyl("RotcapClusterGills", top - V(0, 0.1 * sc, 0), sub[4] * 0.85 * sc, 0.35 * sc, rotGlow, Enum.Material.Neon)
						orb("RotcapClusterSpot", top + V(0, sub[4] * 0.55 * sc, 0), V(0.9 * sc, 0.45 * sc, 0.9 * sc), rotBulb, Enum.Material.Neon)
					end
				end)
			end
			local function rotMyceliumWeb(at: Vector3, yaw: number, s: number?)
				local sc = s or 1
				piece("RotMyceliumWeb", "RotMyceliumWeb", at, yaw, sc, clusterO, function()
					local cf = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
					orb("RotWebMound", at + V(0, 0.8 * sc, 0), V(6.0 * sc, 2.2 * sc, 5.6 * sc), rotMoss, Enum.Material.Grass)
					for k = 0, 5 do
						local a = k * math.pi / 3
						local p0 = cf:PointToWorldSpace(V(0, 1.5 * sc, 0))
						local p1 = cf:PointToWorldSpace(V(math.cos(a) * 5.6 * sc, 0.25 * sc, math.sin(a) * 5.2 * sc))
						beam("RotWebTendril", p0, p1, 0.35 * sc, rotGlow, Enum.Material.Neon)
						orb("RotWebBulb", p0:Lerp(p1, 0.55) + V(0, 0.25 * sc, 0), V(0.8 * sc, 0.8 * sc, 0.8 * sc), rotBulb, Enum.Material.Neon)
					end
					orb("RotWebCap", cf:PointToWorldSpace(V(-1.0 * sc, 2.6 * sc, -1.0 * sc)), V(3.6 * sc, 1.2 * sc, 3.6 * sc), rotCap, Enum.Material.SmoothPlastic)
				end)
			end

			-- 1. The Broken Gate (Sanctuary) & Fallen Quarry (Basin): smashed barricades, tattered banners,
			-- torn shelters, dead lamp-posts (no warm light anywhere on Floor 9), Brute club-drag scars, and
			-- mixed yellow-green & violet rot clusters.
			for _, sx in { -1, 1 } do
				shelter(V(sx * (safe.Width / 2 - 12), safe.Y, safe.Z + safe.Depth / 2 - 9), math.pi + sx * 0.25, true)
				brokenBarricade(V(sx * 34, safe.Y, safe.Z - safe.Depth / 2 + 6), sx * 0.14, 1)
				velmariBanner(V(sx * 23, safe.Y, safe.Z - safe.Depth / 2 + 4), math.pi, 0.95)
				lampPost(V(sx * 48, safe.Y, safe.Z - safe.Depth / 2 + 6), math.pi, 1.1, true)
				velmariBanner(V(sx * 26, basin.Y, basin.Z + basin.Depth / 2 - 9), math.pi, 1.05)
				-- Second broken barricade line across the north rim of the quarry, outside lanes and camps.
				brokenBarricade(V(sx * 84, basin.Y, basin.Z - basin.Depth / 2 + 10), sx * 0.12, 1.05)
				brokenBarricade(V(sx * 152, basin.Y, basin.Z - basin.Depth / 2 + 10), -sx * 0.18, 1.0)
				-- Brute quarry devastation: club-drag scars and toppled blocks at the far east and west ends.
				brokenBarricade(V(sx * 194, basin.Y, basin.Z + 4), sx * 0.85, 1.1)
				lampPost(V(sx * 188, basin.Y, basin.Z + 32), -sx * math.pi / 2, 1.15, true)
				group("ClubDragScar", function()
					onTerrain()
					local x0 = sx * 176
					for k = 0, 2 do
						local scar = block("QuarryDragScar", V(2.4, 0.28, 22), V(x0 + sx * k * 5, basin.Y + 0.08, basin.Z + 12), slateDark, Enum.Material.Slate)
						scar.CFrame *= CFrame.Angles(0, sx * (0.2 + k * 0.08), 0)
					end
					block("ToppledQuarryBlock", V(6.5, 4.2, 5.5), V(sx * 204, basin.Y + 2.0, basin.Z - 26), slateDark, Enum.Material.Slate).CFrame *= CFrame.Angles(0.15, 0.4 * sx, 0.1)
				end)
			end
			-- Quarry rot growths and twin rot/violet lights flanking the northern quarry rim.
			local quarryWestAt = V(-152, basin.Y, basin.Z - basin.Depth / 2 + 20)
			rotcapCluster(quarryWestAt, 0.5, 1.05)
			local quarryWestGlow = orb("QuarryWestRotLight", quarryWestAt + V(0, 6, 0), V(1, 1, 1), rotGlow, Enum.Material.SmoothPlastic, 1)
			pointLight(quarryWestGlow, rotGlow, 1.25, 46)
			local quarryEastAt = V(152, basin.Y, basin.Z - basin.Depth / 2 + 20)
			rotMyceliumWeb(quarryEastAt, -0.7, 1.05)
			local quarryEastGlow = orb("QuarryEastVioletLight", quarryEastAt + V(0, 6, 0), V(1, 1, 1), rotVioletLight, Enum.Material.SmoothPlastic, 1)
			pointLight(quarryEastGlow, rotVioletLight, 1.25, 46)
			rotMyceliumWeb(V(-198, basin.Y, basin.Z - 32), 0.4, 0.9)
			rotcapCluster(V(198, basin.Y, basin.Z - 32), -0.4, 0.95)

			-- 2. Brewing Cellars (WestGallery): Lampkeepers' overrun camp turned into a Chanter shrine,
			-- bubbling rot vats, and a sickly rot-green CandleAltar (zero warm light).
			local altarAt = V(west.X - west.Width / 2 + 10, west.Y, west.Z - west.Depth / 2 + 10)
			group("CandleAltar", function()
				onTerrain()
				local yaw = yawToward(altarAt, V(west.X, west.Y, west.Z))
				if not kitAt("CandleAltar", CFrame.new(altarAt) * CFrame.Angles(0, yaw, 0), 1, { TRIM = { Color = slate, Material = Enum.Material.Slate }, CANDLE = { Color = rotBulb, Material = Enum.Material.Neon }, BULB = { Color = rotGlow, Material = Enum.Material.Neon }, GLOW = { Color = rotGlow, Material = Enum.Material.Neon } }) then
					block("AltarDaisStep", V(14, 2, 10), altarAt + V(0, 1, 0), slate, Enum.Material.Slate)
				end
				local glow = orb("AltarRotGlow", altarAt + V(0, 5, 0), V(1, 1, 1), rotGlow, Enum.Material.SmoothPlastic, 1)
				pointLight(glow, rotGlow, 1.4, 44)
			end)
			table.insert(reservedSpots, { altarAt.X, altarAt.Z, 12 })
			rotVat(V(west.X - west.Width / 2 + 7, west.Y, west.Z + 6), 0.4, 1.05)
			rotVat(V(west.X - west.Width / 2 + 10, west.Y, west.Z + west.Depth / 2 - 10), 1.9, 1.15)
			rotVat(V(west.X - 22, west.Y, west.Z + west.Depth / 2 - 8), -0.8, 0.95)
			rotcapCluster(V(west.X - west.Width / 2 + 7, west.Y, west.Z - 12), 1.2, 0.72)
			shelter(V(west.X + west.Width / 2 - 10, west.Y, west.Z - west.Depth / 2 + 10), -math.pi * 0.75, true)
			cache(V(west.X + west.Width / 2 - 10, west.Y, west.Z - west.Depth / 2 + 24), -1.1)

			-- 3. Ossuary of Caps (EastGallery): giant bones & skulls sprouted with rotcaps, dead lamps among them.
			local ossNE = V(east.X + east.Width / 2 - 10, east.Y, east.Z - east.Depth / 2 + 10)
			ossuaryBones(ossNE, -math.pi * 0.75, 1.05)
			local ossGlow = orb("OssuaryRotGlow", ossNE + V(0, 5, 0), V(1, 1, 1), rotGlow, Enum.Material.SmoothPlastic, 1)
			pointLight(ossGlow, rotGlow, 1.3, 42)
			ossuaryBones(V(east.X + east.Width / 2 - 10, east.Y, east.Z + east.Depth / 2 - 10), -math.pi * 0.25, 0.95)
			rotMyceliumWeb(V(east.X + east.Width / 2 - 8, east.Y, east.Z - 12), -math.pi / 2, 0.7)
			lampPost(V(east.X + east.Width / 2 - 7, east.Y, east.Z), -math.pi / 2, 1.15, true)
			lampPost(V(east.X - east.Width / 2 + 10, east.Y, east.Z - east.Depth / 2 + 10), math.pi * 0.25, 1.1, true)
			lampPost(V(east.X + 20, east.Y, east.Z + east.Depth / 2 - 6), math.pi, 1.05, true)

			-- 4. West & East Rot-Spires (WestBastion, EastBastion): split and leaning keep towers, plus the
			-- Lampkeepers' last ChalkSign on the East Rot-Spire lookout pointing at Keep of the Rotcap.
			local westTowerAt = V(westB.X - westB.Width / 2 + 10, westB.Y, westB.Z - westB.Depth / 2 + 10)
			rotcapTower(westTowerAt, math.pi * 0.2, 0.85)
			local westTowerGlow = orb("WestSpireRotLight", westTowerAt + V(0, 12, 0), V(1, 1, 1), rotGlow, Enum.Material.SmoothPlastic, 1)
			pointLight(westTowerGlow, rotGlow, 1.35, 44)
			velmariBanner(V(westB.X + westB.Width / 2 - 10, westB.Y, westB.Z - westB.Depth / 2 + 8), -0.35, 1.0)
			local eastTowerAt = V(eastB.X + eastB.Width / 2 - 10, eastB.Y - 0.2, eastB.Z - eastB.Depth / 2 + 10)
			rotcapTower(eastTowerAt, -math.pi * 0.25, 0.85, CFrame.Angles(0.05, 0, -0.06))
			local eastTowerGlow = orb("EastSpireVioletLight", eastTowerAt + V(0, 12, 0), V(1, 1, 1), rotVioletLight, Enum.Material.SmoothPlastic, 1)
			pointLight(eastTowerGlow, rotVioletLight, 1.35, 44)
			local lookoutAt = V(eastB.X - westB.Width / 2 + 12, eastB.Y, eastB.Z - eastB.Depth / 2 + 10)
			chalkSign(lookoutAt, yawToward(lookoutAt, V(apex.X, apex.Y, apex.Z)), 1.3)
			lampPost(lookoutAt + V(6, 0, -4), yawToward(lookoutAt, V(apex.X, apex.Y, apex.Z)), 1.1, true)

			-- 5. The High Spans & The Keystone (Crossing): arched masonry under the high spans above the rot pit,
			-- the Lampkeepers' last broken barricade at the NW corner, dead lamp and Velmari banners.
			for _, link in layout.Links do
				if link.From == "WestBastion" or link.From == "EastBastion" then
					group("HighSpanArch", function()
						onTerrain()
						local a, b = V(link.AX, link.AY, link.AZ), V(link.BX, link.BY, link.BZ)
						local delta = b - a
						local spanLen = delta.Magnitude
						local flat = V(delta.X, 0, delta.Z)
						local yaw = math.atan2(flat.X, flat.Z)
						local right = V(-link.UZ, 0, link.UX)
						for _, frac in { 0.26, 0.74 } do
							local pt = a:Lerp(b, frac)
							local pierTop = pt.Y - 2.05
							local pierH = math.max(4, pierTop - bed)
							for _, sb in { -1, 1 } do
								local foot = V(pt.X + right.X * sb * (link.Width / 2 - 2.5), bed, pt.Z + right.Z * sb * (link.Width / 2 - 2.5))
								local pier = block("HighSpanPier", V(4.5, pierH, 5.5), foot + V(0, pierH / 2, 0), slateDark, Enum.Material.Slate)
								pier.CFrame = CFrame.lookAt(origin + foot + V(0, pierH / 2, 0), origin + foot + V(0, pierH / 2, 0) + flat)
								pier.CastShadow = true
							end
						end
						local mid = (a + b) / 2
						local archSpan = spanLen * 0.48
						for _, sb in { -1, 1 } do
							local archCenter = V(mid.X + right.X * sb * (link.Width / 2 - 1.2), mid.Y - archSpan * 0.5 - 3.2, mid.Z + right.Z * sb * (link.Width / 2 - 1.2))
							ring("HighSpanArchRing", archCenter, archSpan * 0.5, 2.0, cobble, Enum.Material.Cobblestone, CFrame.Angles(0, yaw + math.pi / 2, 0), 0, math.pi, 10)
						end
					end)
				end
			end
			group("RotPitGlow", function()
				onTerrain()
				local pitGlow = orb("KeystoneRotPitLight", V(cross.X, cross.Y - 8, cross.Z + 20), V(1, 1, 1), rotGlow, Enum.Material.SmoothPlastic, 1)
				pointLight(pitGlow, rotGlow, 1.5, 68)
			end)
			brokenBarricade(V(cross.X - 31, cross.Y, cross.Z - 25), -0.62, 0.75)
			lampPost(V(cross.X + 32, cross.Y, cross.Z - 25), -0.5, 1.0, true)
			velmariBanner(V(cross.X - 32, cross.Y, cross.Z + 25), 0.3, 0.9)
			velmariBanner(V(cross.X + 32, cross.Y, cross.Z + 25), -0.3, 0.9)

			-- 6. Keep of the Rotcap (Apex): ruined keep towers & curtain walls framing the Keep's back corners,
			-- crowned by the Colossal Rotcap rising from the Keep's back shelf (sickly yellow-green glow underneath).
			local rotCapOverride = { CAP = { Color = rotCap }, GLOW = { Color = rotGlow, Material = Enum.Material.Neon }, BULB = { Color = rotBulb, Material = Enum.Material.Neon }, STEM = { Color = rotStem }, MOSS = { Color = rotMoss, Material = Enum.Material.Grass } }
			local crownZ = apex.Z - apex.Depth / 2 + 1
			local crownBaseY = apex.Y + 16
			group("RotcapCrown", function()
				block("RotcapCrownShelf", V(10, 16, 6), V(0, apex.Y + 8, crownZ), slateDark, Enum.Material.Slate)
				orb("RotcapCrownMoss", V(0, crownBaseY + 0.5, crownZ), V(11, 2.5, 7), rotMoss, Enum.Material.Grass)
				local crownAt = V(0, crownBaseY, crownZ)
				if not kitAt("ElderCap", CFrame.new(crownAt + V(0, 2, -1)) * CFrame.Angles(0, 0.15, 0), 0.85, rotCapOverride) then
					mushroom(crownAt, 1.55, false)
				end
				local glow = orb("RotcapCrownGlow", crownAt + V(0, 36, 4), V(2, 2, 2), rotGlow, Enum.Material.SmoothPlastic, 1)
				pointLight(glow, rotGlow, 1.6, 90)
			end)
			table.insert(reservedSpots, { 0, crownZ, 24 })
			for _, sx in { -1, 1 } do
				local sideAt = V(sx * 42, apex.Y, apex.Z - 14)
				if not kitAt("GiantMushroom", CFrame.new(sideAt) * CFrame.Angles(0, sx * 0.9, 0), 0.55, rotCapOverride) then
					mushroom(sideAt, 0.55, false)
				end
				rotcapCluster(V(sx * 22, apex.Y, apex.Z - apex.Depth / 2 + 2), sx * 0.5, 0.9)
				rotMyceliumWeb(V(sx * 11, apex.Y, apex.Z - apex.Depth / 2 + 2), sx * 0.8, 0.85)
				rotcapTower(V(sx * 46, apex.Y, apex.Z - apex.Depth / 2 + 6), sx * 0.25, 0.95)
				velmariBanner(V(sx * 44, apex.Y, apex.Z + apex.Depth / 2 - 8), sx * 0.2, 1.0)
				group("KeepCurtainWall", function()
					local wall = block("KeepRuinWall", V(11, 11, 4), V(sx * 33, apex.Y + 5.5, apex.Z - apex.Depth / 2 + 3), slateDark, Enum.Material.Slate)
					wall.CastShadow = true
					for k = -1, 1, 2 do
						block("KeepWallMerlon", V(3.5, 3.5, 4.4), V(sx * 33 + k * 3.5, apex.Y + 12.5, apex.Z - apex.Depth / 2 + 3), cobble, Enum.Material.Cobblestone)
					end
				end)
			end

			-- 7. Rot pools & side-cliff rot falls: sickly pad-caps and yellow-green falls off the west/east cliffs.
			if field then
				for _, f in { { X = -205, Z = -78, Dir = 1 }, { X = 205, Z = -78, Dir = -1 } } do
					local x = f.X
					for _ = 1, 24 do
						local nx = x - f.Dir * 2
						if field.Height(nx, f.Z) > liquid + 36 or math.abs(nx) > w / 2 - 4 then break end
						x = nx
					end
					local top = math.min(field.Height(x - f.Dir * 2, f.Z), liquid + 42)
					waterfall(V(x + f.Dir * 1.5, liquid - 0.4, f.Z), 12, top - liquid, rotGlow, if f.Dir > 0 then math.pi / 2 else -math.pi / 2)
				end
				-- Keep Floor 9 within its local light budget (harsher contrast, no extra waterfall fill lights).
				for _, child in kit:GetChildren() do
					if child.Name == "Waterfall" then
						for _, d in child:GetDescendants() do
							if d:IsA("PointLight") then d:Destroy() end
						end
					end
				end
			end
			for _, pool in (layout.Terrain and layout.Terrain.Pools) or {} do
				padCaps(pool.X, pool.Z, 4, math.min(pool.RX, pool.RZ) - 4, 6, math.floor(pool.X * 5 + pool.Z * 7 + 9))
			end
		end

		if fungalFloor == 10 then
			local west, east = layout.Platforms.WestGallery, layout.Platforms.EastGallery
			local westB, eastB = layout.Platforms.WestBastion, layout.Platforms.EastBastion
			local cross = layout.Platforms.Crossing
			local bed = if field then field.Bottom - 3 else bottom
			local silkPale = rgb(216, 206, 242)
			local silkGlow = rgb(96, 245, 255)
			local heartCyan = rgb(112, 245, 255)
			local heartMagenta = rgb(218, 84, 255)
			local cocoonBulb = rgb(224, 132, 255)
			local heartCap = rgb(92, 44, 182)
			local heartMoss = rgb(68, 48, 112)
			local lampWarm = rgb(255, 174, 96)
			local stoneViolet = rgb(96, 74, 138)
			local ironDark = rgb(48, 46, 60)

			local archO = { TRIM = { Color = slateDark, Material = Enum.Material.Slate }, STONE = { Color = stoneViolet, Material = Enum.Material.Cobblestone }, STEM = { Color = silkPale, Material = Enum.Material.Fabric }, BULB = { Color = cocoonBulb, Material = Enum.Material.Neon }, GLOW = { Color = silkGlow, Material = Enum.Material.Neon }, CAP = { Color = heartCap } }
			local spireO = { TRIM = { Color = slateDark, Material = Enum.Material.Slate }, STONE = { Color = stoneViolet, Material = Enum.Material.Cobblestone }, STEM = { Color = silkPale, Material = Enum.Material.Fabric }, GLOW = { Color = silkGlow, Material = Enum.Material.Neon }, BULB = { Color = cocoonBulb, Material = Enum.Material.Neon }, CAP = { Color = heartCap } }
			local clutchO = { MOSS = { Color = heartMoss, Material = Enum.Material.Grass }, STEM = { Color = silkPale, Material = Enum.Material.Fabric }, BULB = { Color = cocoonBulb, Material = Enum.Material.Neon }, GLOW = { Color = heartCyan, Material = Enum.Material.Neon }, CAP = { Color = heartCap } }
			local stolenO = { TRIM = { Color = slateDark, Material = Enum.Material.Slate }, METAL = { Color = ironDark, Material = Enum.Material.Metal }, STEM = { Color = silkPale, Material = Enum.Material.Fabric }, BULB = { Color = cocoonBulb, Material = Enum.Material.Neon }, GLOW = { Color = silkGlow, Material = Enum.Material.Neon }, CAP = { Color = heartCap } }
			local windlassO = { WOOD = { Color = rgb(84, 64, 52), Material = Enum.Material.Wood }, TRIM = { Color = slate, Material = Enum.Material.Slate }, METAL = { Color = ironDark, Material = Enum.Material.Metal }, STEM = { Color = silkPale, Material = Enum.Material.Fabric }, GLOW = { Color = heartCyan, Material = Enum.Material.Neon }, BULB = { Color = cocoonBulb, Material = Enum.Material.Neon } }
			local shrineO = { TRIM = { Color = slateDark, Material = Enum.Material.Slate }, STONE = { Color = stoneViolet, Material = Enum.Material.Cobblestone }, WOOD = { Color = rgb(88, 66, 52), Material = Enum.Material.Wood }, STEM = { Color = silkPale, Material = Enum.Material.Fabric }, CANDLE = { Color = lampWarm, Material = Enum.Material.Neon }, BULB = { Color = rgb(255, 224, 152), Material = Enum.Material.Neon }, GLOW = { Color = heartCyan, Material = Enum.Material.Neon } }
			local curtainO = { STEM = { Color = silkPale, Material = Enum.Material.Fabric }, GLOW = { Color = silkGlow, Material = Enum.Material.Neon }, BULB = { Color = cocoonBulb, Material = Enum.Material.Neon }, CAP = { Color = heartCap } }

			local function webbedArchway(at: Vector3, yaw: number, s: number?, after: (() -> ())?)
				local sc = s or 1
				piece("WebbedArchway", "WebbedArchway", at, yaw, sc, archO, function()
					local cf = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
					for _, px in { -7.6, 0, 7.6 } do
						local plinth = block("WebArchPlinth", V(2.8, 1.2, 3.6) * sc, V(0, 0, 0), stoneViolet, Enum.Material.Cobblestone)
						plinth.CFrame = CFrame.new(origin) * cf * CFrame.new(px * sc, 0.6 * sc, 0)
						local pier = block("WebArchPier", V(2.0, 10.0, 2.8) * sc, V(0, 0, 0), slateDark, Enum.Material.Slate)
						pier.CFrame = CFrame.new(origin) * cf * CFrame.new(px * sc, 6.2 * sc, 0)
						pier.CastShadow = true
					end
					local lintel = block("WebArchLintel", V(18.0, 1.6, 3.0) * sc, V(0, 0, 0), slateDark, Enum.Material.Slate)
					lintel.CFrame = CFrame.new(origin) * cf * CFrame.new(0, 12.6 * sc, 0)
					for _, bx in { -4.6, -2.1, 2.1, 4.6 } do
						local top = cf:PointToWorldSpace(V(bx * sc, 11.8 * sc, 0))
						local bot = cf:PointToWorldSpace(V(bx * sc, 7.2 * sc, 0))
						beam("WebArchSilk", top, bot, 0.22 * sc, silkPale, Enum.Material.Fabric)
						orb("WebArchCocoon", top:Lerp(bot, 0.85), V(1.6, 2.6, 1.6) * sc, cocoonBulb, Enum.Material.Neon)
					end
					for _, sx in { -1, 1 } do
						beam("WebArchDrape", cf:PointToWorldSpace(V(sx * 7.6 * sc, 11.4 * sc, -1.2 * sc)), cf:PointToWorldSpace(V(0, 8.8 * sc, -1.2 * sc)), 0.28 * sc, silkPale, Enum.Material.Fabric)
					end
				end, nil, after)
			end
			local function silkSpire(at: Vector3, yaw: number, s: number?, after: (() -> ())?)
				local sc = s or 1
				piece("SilkSpire", "SilkSpire", at, yaw, sc, spireO, function()
					local cf = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
					local base = block("SilkSpireBase", V(9.2, 2.0, 9.2) * sc, V(0, 0, 0), stoneViolet, Enum.Material.Cobblestone)
					base.CFrame = CFrame.new(origin) * cf * CFrame.new(0, 1.0 * sc, 0)
					local lower = block("SilkSpireLower", V(7.0, 11.0, 7.0) * sc, V(0, 0, 0), slateDark, Enum.Material.Slate)
					lower.CFrame = CFrame.new(origin) * cf * CFrame.new(0, 7.5 * sc, 0)
					lower.CastShadow = true
					local upper = block("SilkSpireUpper", V(4.6, 8.5, 4.6) * sc, V(0, 0, 0), slate, Enum.Material.Slate)
					upper.CFrame = CFrame.new(origin) * cf * CFrame.new(0, 17.2 * sc, 0)
					local peak = block("SilkSpirePeak", V(2.2, 4.2, 2.2) * sc, V(0, 0, 0), stoneViolet, Enum.Material.Cobblestone)
					peak.CFrame = CFrame.new(origin) * cf * CFrame.new(0, 23.0 * sc, 0)
					for k = 0, 3 do
						local a = k * math.pi / 2 + 0.4
						local p0 = cf:PointToWorldSpace(V(math.cos(a) * 4.4 * sc, 1.0 * sc, math.sin(a) * 4.4 * sc))
						local p1 = cf:PointToWorldSpace(V(math.cos(a + 0.7) * 2.2 * sc, 21.0 * sc, math.sin(a + 0.7) * 2.2 * sc))
						beam("SilkSpireWrap", p0, p1, 0.36 * sc, silkPale, Enum.Material.Fabric)
						beam("SilkSpireVein", p0 + V(0, 0.6 * sc, 0), p1, 0.16 * sc, heartCyan, Enum.Material.Neon)
					end
					local capAt = cf:PointToWorldSpace(V(-3.4 * sc, 7.4 * sc, -2.6 * sc))
					orb("SilkSpireCap", capAt, V(3.0, 1.2, 3.0) * sc, heartCap, Enum.Material.SmoothPlastic)
				end, nil, after)
			end
			local function broodEggClutch(at: Vector3, yaw: number, s: number?)
				local sc = s or 1
				piece("BroodEggClutch", "BroodEggClutch", at, yaw, sc, clutchO, function()
					local cf = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
					orb("BroodNestMoss", cf:PointToWorldSpace(V(0, 0.6 * sc, 0)), V(8.0, 1.4, 8.0) * sc, heartMoss, Enum.Material.Grass)
					for _, e in { { 0, 2.4, 0, 2.6, 4.0, 2.6 }, { -1.6, 1.7, -1.0, 2.0, 3.1, 2.0 }, { 1.6, 1.8, -0.9, 2.0, 3.0, 2.0 }, { -1.1, 1.6, 1.5, 1.8, 2.7, 1.8 } } do
						orb("BroodEgg", cf:PointToWorldSpace(V(e[1] * sc, e[2] * sc, e[3] * sc)), V(e[4], e[5], e[6]) * sc, cocoonBulb, Enum.Material.Neon)
					end
					for k = 0, 3 do
						local a = k * math.pi / 2
						beam("BroodNestSilk", cf:PointToWorldSpace(V(math.cos(a) * 3.6 * sc, 0.4 * sc, math.sin(a) * 3.6 * sc)), cf:PointToWorldSpace(V(math.cos(a) * 1.8 * sc, 2.5 * sc, math.sin(a) * 1.8 * sc)), 0.32 * sc, silkPale, Enum.Material.Fabric)
					end
				end)
			end
			local function stolenLampCocoon(at: Vector3, yaw: number, s: number?)
				local sc = s or 1
				piece("StolenLampCocoon", "StolenLampCocoon", at, yaw, sc, stolenO, function()
					local cf = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
					local plinth = block("StolenLampPlinth", V(3.6, 1.4, 3.6) * sc, V(0, 0, 0), slateDark, Enum.Material.Slate)
					plinth.CFrame = CFrame.new(origin) * cf * CFrame.new(0, 0.7 * sc, -0.5 * sc)
					beam("StolenLampPost", cf:PointToWorldSpace(V(0, 1.0 * sc, -1.0 * sc)), cf:PointToWorldSpace(V(0, 11.6 * sc, -0.5 * sc)), 0.65 * sc, ironDark, Enum.Material.Metal)
					beam("StolenLampArm", cf:PointToWorldSpace(V(0, 11.6 * sc, -0.5 * sc)), cf:PointToWorldSpace(V(0, 11.0 * sc, 2.2 * sc)), 0.45 * sc, ironDark, Enum.Material.Metal)
					local bulbAt = cf:PointToWorldSpace(V(0, 6.8 * sc, 2.2 * sc))
					beam("StolenLampThread", cf:PointToWorldSpace(V(0, 11.0 * sc, 2.2 * sc)), bulbAt, 0.2 * sc, silkPale, Enum.Material.Fabric)
					orb("StolenLampShroud", bulbAt, V(2.2, 3.4, 2.2) * sc, cocoonBulb, Enum.Material.Neon)
					cyl("StolenLampBand", bulbAt, 1.2 * sc, 0.35 * sc, heartCyan, Enum.Material.Neon)
				end)
			end
			local function silkWindlass(at: Vector3, yaw: number, s: number?, after: (() -> ())?)
				local sc = s or 1
				piece("SilkWindlass", "SilkWindlass", at, yaw, sc, windlassO, function()
					local cf = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
					local sill = block("WindlassSill", V(9.2, 0.8, 5.4) * sc, V(0, 0, 0), slate, Enum.Material.Slate)
					sill.CFrame = CFrame.new(origin) * cf * CFrame.new(0, 0.4 * sc, 0)
					for _, sx in { -1, 1 } do
						beam("WindlassFrameA", cf:PointToWorldSpace(V(sx * 3.4 * sc, 0.8 * sc, -1.6 * sc)), cf:PointToWorldSpace(V(sx * 3.4 * sc, 5.6 * sc, 0)), 0.55 * sc, rgb(84, 64, 52), Enum.Material.Wood)
						beam("WindlassFrameB", cf:PointToWorldSpace(V(sx * 3.4 * sc, 0.8 * sc, 1.6 * sc)), cf:PointToWorldSpace(V(sx * 3.4 * sc, 5.6 * sc, 0)), 0.55 * sc, rgb(84, 64, 52), Enum.Material.Wood)
					end
					local drum = block("WindlassSilkDrum", V(5.4, 3.0, 3.0) * sc, V(0, 0, 0), silkPale, Enum.Material.Fabric, Enum.PartType.Cylinder)
					drum.CFrame = CFrame.new(origin) * cf * CFrame.new(0, 4.6 * sc, 0)
					for k = -1, 1 do
						beam("WindlassStrand", cf:PointToWorldSpace(V(k * 1.8 * sc, 4.0 * sc, 1.4 * sc)), cf:PointToWorldSpace(V(k * 2.0 * sc, 0.6 * sc, 2.8 * sc)), 0.25 * sc, heartCyan, Enum.Material.Neon)
					end
				end, nil, after)
			end
			local function lastLampShrine(at: Vector3, yaw: number, s: number?)
				local sc = s or 1
				piece("LastLampShrine", "LastLampShrine", at, yaw, sc, shrineO, function()
					local cf = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
					local floorPlate = block("LastLampDais", V(12.6, 0.9, 9.4) * sc, V(0, 0, 0), stoneViolet, Enum.Material.Cobblestone)
					floorPlate.CFrame = CFrame.new(origin) * cf * CFrame.new(0, 0.45 * sc, 0)
					local back = block("LastLampBackWall", V(10.2, 6.8, 1.4) * sc, V(0, 0, 0), slateDark, Enum.Material.Slate)
					back.CFrame = CFrame.new(origin) * cf * CFrame.new(0, 3.8 * sc, -3.6 * sc)
					for _, sx in { -1, 1 } do
						local pierF = block("LastLampPier", V(1.6, 6.2, 1.6) * sc, V(0, 0, 0), slateDark, Enum.Material.Slate)
						pierF.CFrame = CFrame.new(origin) * cf * CFrame.new(sx * 4.8 * sc, 3.5 * sc, 3.4 * sc)
						local roof = block("LastLampRoof", V(6.2, 0.8, 9.2) * sc, V(0, 0, 0), stoneViolet, Enum.Material.Cobblestone)
						roof.CFrame = CFrame.new(origin) * cf * CFrame.new(sx * 2.5 * sc, 8.4 * sc, 0) * CFrame.Angles(0, 0, -sx * 0.52)
					end
					local ped = block("LastLampPedestal", V(1.6, 2.4, 1.6) * sc, V(0, 0, 0), slateDark, Enum.Material.Slate)
					ped.CFrame = CFrame.new(origin) * cf * CFrame.new(2.6 * sc, 2.0 * sc, 2.8 * sc)
					orb("LastLampWarmFlame", cf:PointToWorldSpace(V(2.6 * sc, 4.1 * sc, 2.8 * sc)), V(1.4, 2.0, 1.4) * sc, lampWarm, Enum.Material.Neon)
				end)
			end
			local function silkWebCurtain(at: Vector3, yaw: number, s: number?)
				local sc = s or 1
				piece("SilkWebCurtain", "SilkWebCurtain", at, yaw, sc, curtainO, function()
					local cf = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
					for _, sx in { -1, 1 } do
						beam("SilkCurtainPost", cf:PointToWorldSpace(V(sx * 7.2 * sc, 0, 0)), cf:PointToWorldSpace(V(sx * 7.2 * sc, 5.8 * sc, 0)), 1.3 * sc, silkPale, Enum.Material.SmoothPlastic)
						orb("SilkCurtainCap", cf:PointToWorldSpace(V(sx * 7.2 * sc, 5.8 * sc, 0)), V(2.8, 1.1, 2.8) * sc, heartCap, Enum.Material.SmoothPlastic)
					end
					for _, hz in { 5.4, 4.0, 2.6 } do
						beam("SilkCurtainCord", cf:PointToWorldSpace(V(-7.0 * sc, hz * sc, 0)), cf:PointToWorldSpace(V(7.0 * sc, hz * sc, 0)), 0.25 * sc, silkPale, Enum.Material.Fabric)
					end
					for _, cx in { -3.5, 0, 3.5 } do
						orb("SilkCurtainCocoon", cf:PointToWorldSpace(V(cx * sc, 2.8 * sc, 0)), V(1.1, 1.8, 1.1) * sc, cocoonBulb, Enum.Material.Neon)
					end
				end)
			end

			-- The nest kit (fungal_f10_nest_kit): the Matriarch's own silk, as against the stolen Velmari stone.
			local silkO = { SILK = { Color = silkPale, Material = Enum.Material.Fabric }, TRIM = { Color = slateDark, Material = Enum.Material.Slate }, GLOW = { Color = silkGlow, Material = Enum.Material.Neon }, WOOD = { Color = rgb(84, 64, 52), Material = Enum.Material.Wood }, BULB = { Color = cocoonBulb, Material = Enum.Material.Neon }, CRYSTAL = { Color = heartCyan, Material = Enum.Material.Glass, Transparency = 0.25 }, CANDLE = { Color = heartCyan, Material = Enum.Material.Neon }, MOSS = { Color = heartMoss, Material = Enum.Material.Grass }, STEM = { Color = silkPale, Material = Enum.Material.Fabric } }
			local function shroudSpire(at: Vector3, yaw: number, s: number)
				piece("ShroudSpire", "ShroudSpire", at, yaw, s, silkO, function()
					block("ShroudSpireCore", V(8, 46, 8) * s, at + V(0, 23 * s, 0), slateDark, Enum.Material.Slate).CastShadow = true
					orb("ShroudSpireSilk", at + V(0, 18 * s, 0), V(20, 40, 20) * s, silkPale, Enum.Material.Fabric, 0.35)
					orb("ShroudSpireSilkUpper", at + V(0, 42 * s, 0), V(9, 22, 9) * s, silkPale, Enum.Material.Fabric, 0.2)
					beam("ShroudSpireVein", at + V(0, 2 * s, 0), at + V(0, 56 * s, 0), 0.5 * s, silkGlow, Enum.Material.Neon)
				end)
			end
			local function eggRack(at: Vector3, yaw: number, s: number)
				piece("EggRack", "EggRack", at, yaw, s, silkO, function()
					local cf = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
					for _, sx in { -1, 1 } do
						beam("EggRackPost", cf:PointToWorldSpace(V(sx * 6 * s, 0, 0)), cf:PointToWorldSpace(V(sx * 6 * s, 19 * s, 0)), 0.9 * s, slateDark, Enum.Material.Slate)
					end
					for _, ry in { 5, 11, 17 } do
						beam("EggRackBar", cf:PointToWorldSpace(V(-6 * s, ry * s, 0)), cf:PointToWorldSpace(V(6 * s, ry * s, 0)), 0.5 * s, rgb(84, 64, 52), Enum.Material.Wood)
						for _, ex in { -3.2, 0, 3.2 } do
							orb("EggRackEgg", cf:PointToWorldSpace(V(ex * s, (ry - 2.2) * s, 0.4 * s)), V(2.2, 3.4, 2.2) * s, cocoonBulb, Enum.Material.Neon)
						end
					end
				end)
			end
			local function silkSpool(at: Vector3, yaw: number, s: number)
				piece("SilkSpool", "SilkSpool", at, yaw, s, silkO, function()
					local drum = block("SilkSpoolDrum", V(9, 6, 6) * s, V(0, 0, 0), silkPale, Enum.Material.Fabric, Enum.PartType.Cylinder)
					drum.CFrame = CFrame.new(origin + at) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 3.6 * s, 0)
				end)
			end
			local function cocoonLamp(at: Vector3, yaw: number, s: number)
				piece("CocoonLamp", "CocoonLamp", at, yaw, s, silkO, function()
					beam("CocoonLampPost", at, at + V(0, 10 * s, 0), 0.5 * s, slateDark, Enum.Material.Slate)
					orb("CocoonLampShroud", at + V(0, 7 * s, 1.6 * s), V(2.2, 3.4, 2.2) * s, silkPale, Enum.Material.Fabric)
					orb("CocoonLampFlame", at + V(0, 7 * s, 1.6 * s), V(1, 1.6, 1) * s, heartCyan, Enum.Material.Neon)
				end)
			end

			-- 1. The Last Lamp (Sanctuary): the sole warm-light Lampkeeper shrine & lantern in the entire floor,
			-- paired with a torn refuge shelter and carved Velmari floor rosette.
			local shrineAt = V(-safe.Width / 2 + 14, safe.Y, safe.Z - 4)
			lastLampShrine(shrineAt, math.pi / 2, 1.0)
			lampPost(V(-safe.Width / 2 + 12, safe.Y, safe.Z - 16), math.pi * 0.35, 1.1, false, true)
			group("LastLampRosette", function()
				local glow = orb("LastLampWarmGlow", shrineAt + V(3, 5, 2.5), V(1, 1, 1), lampWarm, Enum.Material.SmoothPlastic, 1)
				pointLight(glow, lampWarm, 2.0, 56)
				cyl("SanctuaryRosette", V(-30, safe.Y + 0.06, safe.Z - 4), 6.2, 0.12, stoneViolet, Enum.Material.Cobblestone)
				cyl("SanctuaryRosetteRing", V(-30, safe.Y + 0.10, safe.Z - 4), 4.6, 0.06, heartCyan, Enum.Material.Neon, 0.25)
			end)
			shelter(V(safe.Width / 2 - 12, safe.Y, safe.Z - 2), -math.pi / 2, false)

			-- 2. Silk Shore (Basin): Gothic rim silk curtains, Skitter egg-clutches west, Lantern Spore crystals
			-- east, and ChalkSigns on the north shore beside the two gallery walkway heads (which leave at about
			-- X +/-45; the causeway keeps the middle clear).
			for _, sx in { -1, 1 } do
				silkWebCurtain(V(sx * 108, basin.Y, basin.Z - basin.Depth / 2 + 6), math.pi, 1.05)
				silkWebCurtain(V(sx * 158, basin.Y, basin.Z - basin.Depth / 2 + 6), math.pi, 1.0)
			end
			broodEggClutch(V(-176, basin.Y, basin.Z + 16), 0.4, 1.05)
			broodEggClutch(V(-198, basin.Y, basin.Z - 12), 1.1, 0.9)
			crystal(V(176, basin.Y, basin.Z + 16), 0.42, 0.6)
			crystal(V(198, basin.Y, basin.Z - 12), 0.34, 2.1)
			chalkSign(V(-58, basin.Y, basin.Z - basin.Depth / 2 + 24), -2.4, 1.2)
			chalkSign(V(58, basin.Y, basin.Z - basin.Depth / 2 + 24), 2.4, 1.2)

			-- 3. Brood Pillar (Crossing, the deck at the back of the nest): a giant mushroom-and-silk pillar in the
			-- Brood Pool under the deck, with 4 corner BroodEggClutch nests, one magenta core glow, and silk
			-- spools in the deck's back corners (the camp clears everything within 34 studs of its centre).
			local poolBed = if field then field.Bottom - 2 else bottom
			group("BroodPillarColumn", function()
				onTerrain()
				local colTop = cross.Y - 4.2
				local colH = math.max(6, colTop - poolBed)
				for _, rot in { 0, math.pi / 4 } do
					local col = block("BroodPillarCore", V(17, colH, 17), V(cross.X, poolBed + colH / 2, cross.Z), slateDark, Enum.Material.Slate)
					col.CFrame *= CFrame.Angles(0, rot, 0)
					col.CastShadow = true
					local foot = block("BroodPillarFoot", V(23, 3.5, 23), V(cross.X, poolBed + 1.75, cross.Z), stoneViolet, Enum.Material.Cobblestone)
					foot.CFrame *= CFrame.Angles(0, rot, 0)
				end
				for k = 0, 7 do
					local a = k * math.pi / 4 + 0.2
					local tierY = poolBed + 4 + (k % 3) * 3.8
					local out = 13.5 + (k % 2) * 2.5
					local cx, cz = cross.X + math.cos(a) * out, cross.Z + math.sin(a) * out
					orb("BroodPillarShelfCap", V(cx, tierY, cz), V(7.5, 2.2, 7.5), heartCap, Enum.Material.SmoothPlastic)
					orb("BroodPillarShelfGills", V(cx, tierY - 0.9, cz), V(6.0, 0.9, 6.0), if k % 2 == 0 then heartCyan else heartMagenta, Enum.Material.Neon)
					beam("BroodPillarSilkStrand", V(cross.X + math.cos(a) * 11, colTop - 1, cross.Z + math.sin(a) * 11), V(cross.X + math.cos(a) * 18, poolBed + 0.5, cross.Z + math.sin(a) * 18), 0.5, silkPale, Enum.Material.Fabric)
				end
				local coreGlow = orb("BroodPillarCoreLight", V(cross.X, cross.Y - 6, cross.Z), V(1, 1, 1), heartMagenta, Enum.Material.SmoothPlastic, 1)
				pointLight(coreGlow, heartMagenta, 1.8, 72)
			end)
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local corner = V(cross.X + sx * 31, cross.Y, cross.Z + sz * 31)
					broodEggClutch(corner, yawToward(corner, V(cross.X, cross.Y, cross.Z)), 0.72)
				end
				silkSpool(V(cross.X + sx * 30, cross.Y, cross.Z - cross.Depth / 2 + 9), sx * math.pi / 2, 0.9)
			end

			-- 4. High Silk Spans (5 hung Terrain.Bridges): arched Velmari piers below deck clearance.
			local bridgeLinks = (layout.Terrain and layout.Terrain.Bridges) or {}
			for _, link in layout.Links do
				if bridgeLinks[link.Id] then
					group("WebSpanArch", function()
						onTerrain()
						local a, b = V(link.AX, link.AY, link.AZ), V(link.BX, link.BY, link.BZ)
						local delta = b - a
						local spanLen = delta.Magnitude
						local flat = V(delta.X, 0, delta.Z)
						local yaw = math.atan2(flat.X, flat.Z)
						local right = V(-link.UZ, 0, link.UX)
						-- The lane box tilts with the span, so drop the piers' tops by the slope across their width.
						local slope = math.abs(delta.Y) / math.max(flat.Magnitude, 1)
						for _, frac in { 0.25, 0.75 } do
							local pt = a:Lerp(b, frac)
							local pierTop = pt.Y - 2.3 - slope * 6
							for _, sb in { -1, 1 } do
								local fx = pt.X + right.X * sb * (link.Width / 2 - 2.5)
								local fz = pt.Z + right.Z * sb * (link.Width / 2 - 2.5)
								local fy = math.max(bottom, groundY(fx, fz))
								local pierH = math.max(3.5, pierTop - fy)
								local foot = V(fx, fy, fz)
								local pier = block("WebSpanPier", V(4.2, pierH, 5.2), foot + V(0, pierH / 2, 0), slateDark, Enum.Material.Slate)
								pier.CFrame = CFrame.lookAt(origin + foot + V(0, pierH / 2, 0), origin + foot + V(0, pierH / 2, 0) + flat)
								pier.CastShadow = true
							end
						end
						local mid = (a + b) / 2
						local archSpan = math.min(28, spanLen * 0.44)
						if mid.Y - archSpan * 0.5 - 3.6 - slope * archSpan * 0.5 >= bottom - 1 then
							for _, sb in { -1, 1 } do
								local archCenter = V(mid.X + right.X * sb * (link.Width / 2 - 1.2), mid.Y - archSpan * 0.5 - 3.6 - slope * archSpan * 0.5, mid.Z + right.Z * sb * (link.Width / 2 - 1.2))
								ring("WebSpanArchRing", archCenter, archSpan * 0.5, 1.9, stoneViolet, Enum.Material.Cobblestone, CFrame.Angles(0, yaw + math.pi / 2, 0), 0, math.pi, 10)
							end
						end
					end)
				end
			end

			-- 5. West Egg Gallery (WestGallery): egg racks against the west cliff either side of one webbed
			-- arch, a cool violet-cyan Chanter altar in the SW corner, brood eggs in the NW corner, no warm light.
			local westEdgeX = west.X - west.Width / 2 + 6
			eggRack(V(westEdgeX - 2, west.Y, west.Z - 22), math.pi / 2, 1.0)
			webbedArchway(V(westEdgeX, west.Y, west.Z), math.pi / 2, 0.95, function()
				local g = orb("CocoonColonnadeLight", V(westEdgeX + 3, west.Y + 9, west.Z), V(1, 1, 1), heartMagenta, Enum.Material.SmoothPlastic, 1)
				pointLight(g, rgb(184, 92, 248), 1.6, 58)
			end)
			eggRack(V(westEdgeX - 2, west.Y, west.Z + 22), math.pi / 2, 1.0)
			local westAltarAt = V(west.X - west.Width / 2 + 14, west.Y, west.Z + west.Depth / 2 - 10)
			group("CandleAltar", function()
				onTerrain()
				local yaw = yawToward(westAltarAt, V(west.X, west.Y, west.Z))
				if not kitAt("CandleAltar", CFrame.new(westAltarAt) * CFrame.Angles(0, yaw, 0), 0.95, { TRIM = { Color = slateDark, Material = Enum.Material.Slate }, CANDLE = { Color = heartCyan, Material = Enum.Material.Neon }, BULB = { Color = cocoonBulb, Material = Enum.Material.Neon }, GLOW = { Color = heartCyan, Material = Enum.Material.Neon } }) then
					block("ChanterColdShrineBase", V(11, 1.8, 8), westAltarAt + V(0, 0.9, 0), slateDark, Enum.Material.Slate)
					orb("ChanterColdFlame", westAltarAt + V(0, 3.0, 0), V(1.6, 2.2, 1.6), heartCyan, Enum.Material.Neon)
				end
			end)
			table.insert(reservedSpots, { westAltarAt.X, westAltarAt.Z, 12 })
			broodEggClutch(V(west.X - west.Width / 2 + 14, west.Y, west.Z - west.Depth / 2 + 10), math.pi * 0.25, 0.95)

			-- 6. Spinneret Ledge (EastGallery): dual silk windlasses, central webbed arch, curtain & anchored
			-- loom cables sweeping down into the moat round the dais.
			local eastEdgeX = east.X + east.Width / 2 - 8
			silkWindlass(V(eastEdgeX, east.Y, east.Z - 18), -math.pi / 2, 1.0, function()
				local g = orb("SpinneretLoomLight", V(eastEdgeX - 3, east.Y + 8, east.Z - 18), V(1, 1, 1), heartCyan, Enum.Material.SmoothPlastic, 1)
				pointLight(g, heartCyan, 1.6, 58)
			end)
			silkWindlass(V(eastEdgeX, east.Y, east.Z + 18), -math.pi / 2, 1.0)
			webbedArchway(V(east.X + east.Width / 2 - 5, east.Y, east.Z), -math.pi / 2, 0.92)
			silkWebCurtain(V(east.X + east.Width / 2 - 14, east.Y, east.Z - east.Depth / 2 + 8), -math.pi * 0.75, 0.88)
			for _, cableZ in { -22, -8 } do
				local lowX = apex.X + apex.Width / 2 + 36
				local lowAt = V(lowX, groundY(lowX, east.Z + cableZ), east.Z + cableZ)
				local highAt = V(east.X - east.Width / 2 - 2, east.Y - 1.5, east.Z + cableZ)
				group("SilkLoomCable", function()
					onTerrain()
					beam("LoomCableStrand", lowAt + V(0, 0.4, 0), highAt, 0.55, silkPale, Enum.Material.Fabric)
					orb("LoomCableAnchor", lowAt + V(0, 0.8, 0), V(3.0, 1.6, 3.0), stoneViolet, Enum.Material.Cobblestone)
				end)
			end

			-- 7. West & East Web-Spires (WestBastion, EastBastion): Gothic silk spires, curtains & brood eggs.
			local westSpireAt = V(westB.X - westB.Width / 2 + 10, westB.Y, westB.Z - westB.Depth / 2 + 10)
			silkSpire(westSpireAt, math.pi * 0.25, 1.15, function()
				local g = orb("WestWebSpireLight", westSpireAt + V(0, 14, 0), V(1, 1, 1), heartMagenta, Enum.Material.SmoothPlastic, 1)
				pointLight(g, rgb(196, 88, 252), 1.6, 58)
			end)
			broodEggClutch(V(westB.X - westB.Width / 2 + 16, westB.Y, westB.Z + westB.Depth / 2 - 8), 0.7, 0.95)
			eggRack(V(westB.X - westB.Width / 2 + 4, westB.Y, westB.Z + 20), math.pi / 2, 0.95)
			silkWebCurtain(V(westB.X - westB.Width / 2 + 4, westB.Y, westB.Z), math.pi / 2, 0.95)

			local eastSpireAt = V(eastB.X + eastB.Width / 2 - 10, eastB.Y, eastB.Z - eastB.Depth / 2 + 10)
			silkSpire(eastSpireAt, -math.pi * 0.25, 1.15, function()
				local g = orb("EastWebSpireLight", eastSpireAt + V(0, 14, 0), V(1, 1, 1), heartCyan, Enum.Material.SmoothPlastic, 1)
				pointLight(g, heartCyan, 1.6, 58)
			end)
			broodEggClutch(V(eastB.X + eastB.Width / 2 - 16, eastB.Y, eastB.Z + eastB.Depth / 2 - 8), -0.7, 0.95)
			eggRack(V(eastB.X + eastB.Width / 2 - 4, eastB.Y, eastB.Z + 20), -math.pi / 2, 0.95)
			silkWebCurtain(V(eastB.X + eastB.Width / 2 - 4, eastB.Y, eastB.Z), -math.pi / 2, 0.95)

			-- 8. Matriarch's Dais (Apex, a mesa in the middle of the nest) & The Veinweb Heart: ring of
			-- StolenLampCocoon rib-hooks round the dais rim (outside the boss discs and the Silk Stair's landing on
			-- the north side), and the colossal Veinweb heart on the south rim between the boss portals, facing
			-- the stair the Masters arrive by.
			-- Two cocoon lamps flank the head of the Silk Stair (its landing is 21 studs either side of X = 0).
			for _, sx in { -1, 1 } do
				cocoonLamp(V(apex.X + sx * 27, apex.Y, apex.Z - apex.Depth / 2 + 4), 0, 1.1)
			end
			for _, lamp in {
				{ -58, -36, 0.9 }, { 58, -36, -0.9 },
				{ -62, -10, math.pi * 0.5 }, { 62, -10, -math.pi * 0.5 },
				{ -62, 4, math.pi * 0.6 }, { 62, 4, -math.pi * 0.6 },
				{ -60, 20, math.pi * 0.7 }, { 60, 20, -math.pi * 0.7 },
			} do
				local at = V(apex.X + lamp[1], apex.Y, apex.Z + lamp[2])
				stolenLampCocoon(at, yawToward(at, V(apex.X, apex.Y, apex.Z)), 1.05)
			end

			local heartCapOverride = { CAP = { Color = heartCap }, GLOW = { Color = heartCyan, Material = Enum.Material.Neon }, BULB = { Color = cocoonBulb, Material = Enum.Material.Neon }, STEM = { Color = silkPale }, MOSS = { Color = heartMoss, Material = Enum.Material.Grass } }
			-- The heart grows out of the dais itself: the Elder Cap stands on the floor (its roots on the ground,
			-- never on a plinth), set in from the south rim so the roots stay on the mesa, and its foot is buried
			-- in a low mound of mossy slate the roots climb out of. Unrotated and on the rim so the cap's gill and
			-- tendril box (60 studs at 0.75, down to the ground) stays more than 37 studs from the boss camp's
			-- front mob slots at Z = -48 (CampHitTest; one hit would clear the whole heart). The cap overhangs the moat.
			local heartZ = apex.Z + apex.Depth / 2 - 4
			local heartBaseY = apex.Y
			group("VeinwebHeart", function()
				local crownAt = V(0, heartBaseY, heartZ)
				if not kitAt("ElderCap", CFrame.new(crownAt + V(0, -0.6, 0)), 0.75, heartCapOverride) then
					mushroom(crownAt, 1.4, false)
				end
				-- Root mound: overlapping slate boulders round the trunk, moss draped over them, lower outward.
				for k = 0, 6 do
					local a = k * math.pi * 2 / 7 + 0.3
					local r = 6 + (k % 3) * 1.1
					local ax, az = crownAt.X + math.cos(a) * r, crownAt.Z + math.sin(a) * r
					local at = V(ax, groundY(ax, az) + 0.6, az)
					local rock = orb("VeinwebHeartRootRock", at, V(8 + (k % 2) * 2.5, 4.4 - (k % 3) * 0.8, 6 + (k % 3) * 1.2), slateDark, Enum.Material.Slate)
					rock.CFrame = CFrame.new(origin + at) * CFrame.Angles(0, -a, 0)
					local mx, mz = crownAt.X + math.cos(a + 0.25) * (r + 1.5), crownAt.Z + math.sin(a + 0.25) * (r + 1.5)
					local mossAt = V(mx, groundY(mx, mz) + 0.2, mz)
					local moss = orb("VeinwebHeartMoss", mossAt, V(8.5, 1.6, 6), heartMoss, Enum.Material.Grass)
					moss.CFrame = CFrame.new(origin + mossAt) * CFrame.Angles(0, -a - 0.25, 0)
				end
				orb("VeinwebHeartMoss", crownAt + V(0, 1.4, 0), V(15, 3.0, 15), heartMoss, Enum.Material.Grass)
				-- Silk veins running from the mound out east and west along the rim, the heart feeding its nest.
				for _, a in { -0.15, 0.45, math.pi - 0.45, math.pi + 0.15 } do
					local fx, fz = crownAt.X + math.cos(a) * 7, crownAt.Z + math.sin(a) * 7
					local tx, tz = crownAt.X + math.cos(a + 0.2) * 19, crownAt.Z + math.sin(a + 0.2) * 19
					local from, to = V(fx, groundY(fx, fz) + 0.3, fz), V(tx, groundY(tx, tz) + 0.15, tz)
					beam("VeinwebHeartVein", from, to, 0.35, heartCyan, Enum.Material.Neon)
				end
				local cyanGlow = orb("VeinwebHeartCyanLight", crownAt + V(0, 60, 4), V(2, 2, 2), heartCyan, Enum.Material.SmoothPlastic, 1)
				pointLight(cyanGlow, heartCyan, 2.0, 108)
				local magGlow = orb("VeinwebHeartMagentaLight", crownAt + V(0, 20, 2), V(2, 2, 2), heartMagenta, Enum.Material.SmoothPlastic, 1)
				pointLight(magGlow, heartMagenta, 1.8, 92)
			end)
			table.insert(reservedSpots, { 0, heartZ, 26 })
			for _, sx in { -1, 1 } do
				-- South rim, inside the portals (at X +/-44): a spire either side frames the heart.
				silkSpire(V(apex.X + sx * 26, apex.Y, apex.Z + apex.Depth / 2 - 6), math.pi + sx * 0.4, 1.0)
				local flankAt = V(apex.X + sx * 44, apex.Y, apex.Z - 26)
				if not kitAt("GiantMushroom", CFrame.new(flankAt) * CFrame.Angles(0, sx * 0.8, 0), 0.6, heartCapOverride) then
					mushroom(flankAt, 0.6, false)
				end
			end

			-- The Shroud Spires: four silk-wrapped spires standing in the moat at the dais's corners, the landmark
			-- of the floor (kept off the Silk Stair at X = 0 and the mesa's rim).
			for _, sp in { { -92, -60, 0.5 }, { 92, -60, -0.5 }, { -92, 54, 2.6 }, { 92, 54, -2.6 } } do
				local x, z = apex.X + sp[1], apex.Z + sp[2]
				shroudSpire(V(x, groundY(x, z), z), sp[3], 1.0)
				table.insert(reservedSpots, { x, z, 18 })
			end

			-- 9. Pool pad-caps and twin cyan-violet chasm waterfalls (lightless to preserve the 24-light budget).
			if field then
				for _, f in { { X = -232, Z = -74, Dir = 1 }, { X = 232, Z = -74, Dir = -1 } } do
					local x = f.X
					for _ = 1, 24 do
						local nx = x - f.Dir * 2
						if field.Height(nx, f.Z) > liquid + 38 or math.abs(nx) > w / 2 - 4 then break end
						x = nx
					end
					local top = math.min(field.Height(x - f.Dir * 2, f.Z), liquid + 44)
					waterfall(V(x + f.Dir * 1.5, liquid - 0.4, f.Z), 14, top - liquid, heartCyan, if f.Dir > 0 then math.pi / 2 else -math.pi / 2)
				end
				for _, child in kit:GetChildren() do
					if child.Name == "Waterfall" then
						for _, d in child:GetDescendants() do
							if d:IsA("PointLight") then d:Destroy() end
						end
					end
				end
			end
			for _, pool in (layout.Terrain and layout.Terrain.Pools) or {} do
				padCaps(pool.X, pool.Z, 4, math.min(pool.RX, pool.RZ) - 4, 6, math.floor(pool.X * 5 + pool.Z * 7 + 10))
			end
		end
	end

	-- Infernal Foundry authored floors build their set pieces in TowerSetPieces/InfernalFoundry (Floors 21-23)
	-- and per-floor modules (InfernalFloor24, InfernalFloor25), and Corrupted Grove floors in
	-- TowerSetPieces/CorruptedGrove, through these builders.
	local setPieceBuild = if layout.Authored == "infernal:1" then InfernalSetPieces.Floor21
		elseif layout.Authored == "infernal:2" then InfernalSetPieces.Floor22
		elseif layout.Authored == "infernal:3" then InfernalSetPieces.Floor23
		elseif layout.Authored == "infernal:4" then InfernalFloor24.Build
		elseif layout.Authored == "infernal:5" then InfernalFloor25.Build
		elseif layout.Authored == "corrupted:1" then CorruptedSetPieces.Floor31
		elseif layout.Authored == "corrupted:2" then CorruptedFloor32.Build
		else nil
	if setPieceBuild then
		setPieceBuild({
			origin = origin, layout = layout, field = field, w = w, d = d, h = h, bottom = bottom,
			group = group, block = block, beam = beam, cyl = cyl, orb = orb, ring = ring,
			pointLight = pointLight, kitAt = kitAt, has = KitProps.Has, footprintClear = footprintClear,
			current = function(): Instance return currentParent end,
			tag = function(name: string, value: any) currentParent:SetAttribute(name, value) end,
			reserve = function(x: number, z: number, r: number) table.insert(reservedSpots, { x, z, r }) end,
			setAttribute = function(name: string, value: any) kit:SetAttribute(name, value) end,
		})
	end

	-- =========================================================================
	-- 5. MONUMENTAL NORTH APEX CITADEL / TEMPLE / PORTAL & OVERHEAD SKY SPECTACLE
	-- =========================================================================
	local backdrop = V(apex.X, apex.Y, -d / 2 + 24)

	-- Rock shelf behind the Apex terrace, level with it, so the citadel, temple and throne backdrops
	-- stand on ground instead of hanging over the chasm.
	local apexBack = apex.Z - apex.Depth / 2
	local shelfDepth = apexBack + d / 2
	if shelfDepth > 1 and layout.Authored ~= "frozen:1" and not (layout.Terrain and layout.Terrain.NoApexShelf) then
		block("ApexShelfMassif", V(w - 60, apex.Y - bottom, shelfDepth + 2), V(0, (apex.Y + bottom) / 2, -d / 2 + shelfDepth / 2), cliffColor, cliffMat)
	end

	if layout.Authored == "ashen:1" then
		-- Columnar dark basalt cliff palisade framing the north horizon (mirrors media_1794989586079_d62a0199.jpg)
		group("AshenBasaltCliffWall", function()
			for i = -8, 8 do
				if math.abs(i) <= 1 then continue end
				local cx = i * 24
				local cz = backdrop.Z + math.abs(i % 3) * 6 - 4
				local ch = (58 + ((math.abs(i) * 13) % 24)) * scale
				block("ColumnarBasaltCliff", V(24.5, ch, 28), V(cx, apex.Y + ch * 0.5 - 12, cz), rgb(38, 34, 36), Enum.Material.Basalt)
			end
		end)
	elseif layout.Authored == "ashen:2" then
		-- Stratified terracotta & ochre sandstone canyon cliffs rising behind Caravan Master's Tomb and Spice Vault
		group("VarrashStrataCliffs", function()
			for i = -8, 8 do
				local cx = i * 25
				if math.abs(cx - apex.X) < 34 then continue end
				local cz = backdrop.Z + (math.abs(i % 3) * 6) - 6
				local ch = (54 + ((math.abs(i) * 11) % 22)) * scale
				block("StrataCliffBasalt", V(25.5, 16 * scale, 30), V(cx, apex.Y + 4 * scale - 10, cz), rgb(52, 44, 44), Enum.Material.Basalt)
				block("StrataCliffOchre", V(24.8, 18 * scale, 28), V(cx, apex.Y + 21 * scale - 10, cz), rgb(172, 134, 96), Enum.Material.Sandstone)
				block("StrataCliffTerra", V(23.5, math.max(10, ch - 34 * scale), 26), V(cx, apex.Y + 39 * scale - 10, cz), rgb(158, 88, 62), Enum.Material.Slate)
			end
		end)
	elseif layout.Authored == "frozen:1" or layout.Authored == "frozen:2" or layout.Authored == "frozen:3" or layout.Authored == "frozen:4" or layout.Authored == "frozen:5" or layout.Authored == "infernal:1" or layout.Authored == "infernal:2" or layout.Authored == "infernal:3" or layout.Authored == "infernal:4" or layout.Authored == "infernal:5" or corruptedFloor then
		-- Floors 16-25 and 31-35 own their north horizon backdrops directly (Floors 21-25, 31-35: TowerSetPieces).
	else
		-- Authored Fungal floors have their own backdrop: the cavern wall itself (Floor 6's Crown Cluster grows on it).
		for _, s in if fungalFloor then {} else { -1, 1 } do
			local wingX = s * (apex.Width * 0.5 + 38)
			group("CitadelWing", function()
				block("NorthCitadelWingCliff", V(68, 76 * scale, 44), backdrop + V(wingX, 28 * scale, 4), cliffColor, cliffMat)
				arch(backdrop + V(wingX, 12 * scale, 28), 36 * scale, 34 * scale, 10, theme.TrimColor, theme.TrimMaterial, 0)
				waterfall(backdrop + V(s * (apex.Width * 0.5 + 16), bottom - apex.Y, 20), 15 * scale, (apex.Y - bottom + 40 * scale), liquidColor, 0)
			end)
		end
	end

	if biome == "verdant_ruins" then
		if layout.Authored == "verdant:3" then
			-- Monumental Heartroot Mother-Trunk & carved Solmere Root-Throne perched behind Apex (Root-Throne),
			-- staying north of Apex PortalSpots (Z = -210) and APEX_SANCTUM camp radius.
			local throneAt = V(apex.X, apex.Y, apex.Z - apex.Depth / 2 - 14)
			group("RootThrone", function()
				if KitProps.Has("RootThrone") then
					kitAt("RootThrone", CFrame.new(throneAt), 1.45 * scale, {
						TRIM = { Color = rgb(196, 190, 168), Material = Enum.Material.Limestone },
						ACCENT = { Color = rgb(92, 150, 128), Material = Enum.Material.Slate },
						GOLD = { Color = gold, Material = Enum.Material.Cobblestone },
						GLOW = { Color = rgb(150, 235, 120), Material = Enum.Material.Neon },
						MOSS = { Color = rgb(86, 132, 58), Material = Enum.Material.Grass },
						WOOD = { Color = rgb(82, 64, 46), Material = Enum.Material.Wood },
					})
				else
					-- Native fallback: colossal Heartroot trunk + flared buttress roots framing a Sun-Disc throne
					cyl("MotherTrunk", throneAt + V(0, 0, -4), 16 * scale, 90 * scale, rgb(82, 64, 46), Enum.Material.Wood)
					for _, s in { -1, 1 } do
						block("ThroneRootButtress", V(8, 34, 14), throneAt + V(s * 16, 16, 2), rgb(62, 48, 36), Enum.Material.Wood)
					end
					block("RootThroneBack", V(14, 24, 5), throneAt + V(0, 12, 4), rgb(196, 190, 168), Enum.Material.Limestone)
					block("RootThroneSeat", V(9, 5, 6), throneAt + V(0, 2.5, 7), rgb(196, 190, 168), Enum.Material.Limestone)
					ring("RootThroneSunRim", throneAt + V(0, 24, 6.5), 5.5, 0.9, gold, Enum.Material.Cobblestone, nil, 0, math.pi * 2, 14)
					orb("RootThroneSunCore", throneAt + V(0, 24, 6.8), V(2.4, 2.4, 0.9), rgb(150, 235, 120), Enum.Material.Neon)
				end
				-- Upper canopy trunk shaft continuing up into the noon skylight opening
				cyl("MotherTrunkCanopy", throneAt + V(0, 38 * scale, -4), 11 * scale, math.max(24, h - apex.Y - 26), rgb(74, 58, 42), Enum.Material.Wood)
			end)
			-- Strong diagonal noon light shafts illuminating The Knot and Root-Throne
			for bIdx = -1, 2 do
				beam("JungleSunbeam", V(bIdx * 42 - 30, h - 4, -d * 0.24 + bIdx * 24), V(bIdx * 36 + 22, 4, -d * 0.04 + bIdx * 32), 11, rgb(252, 234, 172), Enum.Material.SmoothPlastic, 0.90)
			end
		elseif layout.Authored == "verdant:4" then
			-- Monumental roofless Vinebound Keep rising behind Inner Keep (Apex), keeping north of PortalSpots.
			local keepAt = V(apex.X, apex.Y, apex.Z - apex.Depth / 2 - 14)
			group("VineboundKeep", function()
				if KitProps.Has("VineboundKeep") then
					kitAt("VineboundKeep", CFrame.new(keepAt), 1.35 * scale, {
						TRIM = { Color = rgb(196, 190, 168), Material = Enum.Material.Limestone },
						ACCENT = { Color = rgb(92, 150, 128), Material = Enum.Material.Slate },
						GOLD = { Color = gold, Material = Enum.Material.Cobblestone },
						MOSS = { Color = rgb(86, 132, 58), Material = Enum.Material.Grass },
						WOOD = { Color = rgb(82, 64, 46), Material = Enum.Material.Wood },
					})
				else
					for _, s in { -1, 1 } do
						block("KeepTurret", V(15, 52 * scale, 16), keepAt + V(s * 22, 26 * scale, 0), rgb(196, 190, 168), Enum.Material.Limestone)
					end
					block("KeepSanctumWall", V(30, 34 * scale, 12), keepAt + V(0, 17 * scale, 2), rgb(196, 190, 168), Enum.Material.Limestone)
					ring("KeepSunDisc", keepAt + V(0, 30 * scale, 8.5), 4.8, 0.7, gold, Enum.Material.Cobblestone, nil, 0, math.pi * 2, 12)
				end
			end)
		elseif layout.Authored == "verdant:5" then
			-- Monumental Open Cenote Colonnade Dome & soaring Heartroot Mother-Heart tree behind Mossbound Dais,
			-- framed north of MossboundDais (-277) so PortalSpots (Z=-265) and the 140x110 boss arena stay clear.
			local domeAt = V(apex.X, apex.Y, apex.Z - apex.Depth / 2 - 22)
			group("CenoteColonnadeDome", function()
				if KitProps.Has("CenoteColonnadeDome") then
					kitAt("CenoteColonnadeDome", CFrame.new(domeAt), 1.05, {
						TRIM = { Color = rgb(196, 190, 168), Material = Enum.Material.Limestone },
						ACCENT = { Color = rgb(92, 150, 128), Material = Enum.Material.Slate },
						GOLD = { Color = gold, Material = Enum.Material.Cobblestone },
						MOSS = { Color = rgb(82, 134, 62), Material = Enum.Material.Grass },
						WOOD = { Color = rgb(82, 64, 46), Material = Enum.Material.Wood },
					})
				else
					for i = 0, 6 do
						local ang = (i / 6) * math.pi
						local colAt = domeAt + V(math.cos(ang) * 62, 22, -math.sin(ang) * 34)
						cyl("DomeColumn", colAt, 2.4, 44, rgb(196, 190, 168), Enum.Material.Limestone)
					end
					ring("CenoteDomeOculus", domeAt + V(0, 66, -12), 20, 2.2, rgb(196, 190, 168), Enum.Material.Limestone, nil, 0, math.pi * 2, 14)
				end
			end)
			local heartAt = V(apex.X, apex.Y - 10, apex.Z - apex.Depth / 2 - 28)
			group("HeartrootMotherHeart", function()
				if KitProps.Has("HeartrootMotherHeart") then
					kitAt("HeartrootMotherHeart", CFrame.new(heartAt), 1.05, {
						WOOD = { Color = rgb(82, 64, 46), Material = Enum.Material.Wood },
						GLOW = { Color = rgb(150, 235, 120), Material = Enum.Material.Neon },
						MOSS = { Color = rgb(82, 134, 62), Material = Enum.Material.Grass },
						FOLIAGE = { Color = rgb(44, 108, 56), Material = Enum.Material.Grass },
					})
				else
					cyl("MotherHeartTrunk", heartAt + V(0, 52, 0), 14, 104, rgb(82, 64, 46), Enum.Material.Wood)
				end
				-- Glowing Heartroot sap heart core & golden-hour dusk skylight beams pouring through the open dome
				local sapCore = orb("HeartrootSapHeart", heartAt + V(0, 32, 6), V(5.5, 8.5, 4.5), rgb(150, 235, 120), Enum.Material.Neon)
				pointLight(sapCore, rgb(150, 235, 120), 1.8, 55)
			end)
			for bIdx = -1, 1 do
				beam("JungleSunbeam", V(bIdx * 40, h - 4, apex.Z - 48), V(bIdx * 28, apex.Y + 2, apex.Z + 18), 14, rgb(255, 224, 152), Enum.Material.SmoothPlastic, 0.89)
			end
		else
		local templeOrigin = if layout.Authored == "verdant:2" then V(apex.X, apex.Y, -d / 2 + 10) else backdrop
		local templeDepth = if layout.Authored == "verdant:2" then 24 * scale else 38 * scale
		group("Temple", function()
			for step = 1, 5 do
				local tierW = (156 - step * 22) * scale
				local tierH = 13 * scale
				local tierY = (step - 0.5) * tierH
				block("GoldenTempleTier", V(tierW, tierH, templeDepth), templeOrigin + V(0, tierY, -2), if step >= 4 then gold else theme.TrimColor, theme.TrimMaterial)
				block("TempleTierCornice", V(tierW + 6, 2.4, templeDepth + 3), templeOrigin + V(0, step * tierH, -2), gold, Enum.Material.Cobblestone)
			end
			if layout.Authored == "verdant:2" then
				local shrineAt = templeOrigin + V(0, 65 * scale, 2)
				if KitProps.Has("SunDiscShrine") then
					kitAt("SunDiscShrine", CFrame.new(shrineAt), 1.65 * scale, {
						TRIM = { Color = rgb(196, 190, 168), Material = Enum.Material.Limestone },
						ACCENT = { Color = rgb(92, 150, 128), Material = Enum.Material.Slate },
						GOLD = { Color = gold, Material = Enum.Material.Cobblestone },
						GLOW = { Color = rgb(150, 235, 120), Material = Enum.Material.Neon },
						MOSS = { Color = rgb(86, 132, 58), Material = Enum.Material.Grass },
					})
				else
					local sunPos = shrineAt + V(0, 14, 2)
					ring("WellheadSunDiscRim", sunPos, 10 * scale, 1.6, gold, Enum.Material.Cobblestone, nil, 0, math.pi * 2, 12)
					for k = 0, 7 do
						local a = k * math.pi / 4
						beam("WellheadSunRay", sunPos + V(math.cos(a) * 10.5 * scale, math.sin(a) * 10.5 * scale, 0),
							sunPos + V(math.cos(a) * 15.5 * scale, math.sin(a) * 15.5 * scale, 0), 1.4, rgb(92, 150, 128), Enum.Material.Slate)
					end
					orb("WellheadSunCore", sunPos, V(6.5 * scale, 6.5 * scale, 2.5), rgb(150, 235, 120), Enum.Material.Neon)
				end
			else
				spire(templeOrigin + V(0, 62 * scale, -4), 46 * scale, 18 * scale, gold, accent, false)
			end
			for _, s in { -1, 1 } do
				spire(templeOrigin + V(s * 48 * scale, 36 * scale, 0), 36 * scale, 13 * scale, theme.TrimColor, accent, false)
			end
		end)
		group("TemplePortal", function()
			if layout.Authored == "verdant:2" then
				-- Wide sun-gate behind the off-centre Wellhead Shrine portals, clear of both PortalAscend and PortalRerun.
				arch(templeOrigin + V(0, 0, 12), 62, 34 * scale, 8, gold, Enum.Material.Cobblestone, 0)
			else
				arch(backdrop + V(0, 0, 18), 40 * scale, 34 * scale, 10, gold, Enum.Material.Cobblestone, 0)
				orb("SunlitTemplePortal", backdrop + V(0, 24 * scale, 16), V(28 * scale, 38 * scale, 3), rgb(225, 195, 115), Enum.Material.SmoothPlastic, 0.45)
			end
		end)
		for bIdx = -2, 2 do
			beam("JungleSunbeam", V(bIdx * 55 - 35, h - 4, -d * 0.25 + bIdx * 30), V(bIdx * 45 + 25, 4, -d * 0.08 + bIdx * 35), 10, rgb(240, 220, 150), Enum.Material.SmoothPlastic, 0.92)
		end
		end

	elseif biome == "fungal_hollow" and not fungalFloor then
		mushroom(backdrop + V(0, 0, -4), 2.25 * scale, false)
		for _, s in { -1, 1 } do
			mushroom(backdrop + V(s * 54 * scale, -4, 12), 1.55 * scale, false)
			arch(backdrop + V(s * 34 * scale, 0, 16), 28 * scale, 26 * scale, 8, theme.TrimColor, Enum.Material.Cobblestone, 0)
		end
		arch(backdrop + V(0, 0, 18), 44 * scale, 36 * scale, 10, theme.TrimColor, Enum.Material.Cobblestone, 0)
		group("CavernSkylight", function()
			cyl("CavernSkylightOpening", V(0, h - 2, -d * 0.12), 72 * scale, 2.5, rgb(125, 205, 235), Enum.Material.SmoothPlastic, 0.65)
			for rIdx = 1, 8 do
				local a = rIdx * math.pi / 4
				local rTop = V(math.cos(a) * 54 * scale, h - 3, -d * 0.12 + math.sin(a) * 54 * scale)
				beam("SkylightHangingRoot", rTop, rTop - V(math.cos(a) * 12, 46 * scale, math.sin(a) * 12), 2.6, rgb(48, 38, 34), Enum.Material.Wood)
			end
		end)

	elseif biome == "ashen_dunes" then
		if layout.Authored == "ashen:1" then
			local gateAt = V(apex.X, apex.Y, apex.Z - apex.Depth / 2 - 10)
			group("CinderGateArch", function()
				if KitProps.Has("CinderGateArch") then
					local mdl = kitAt("CinderGateArch", CFrame.new(gateAt), 1.18 * scale, {
						TRIM = { Color = rgb(188, 158, 116), Material = Enum.Material.Sandstone },
						ALT = { Color = rgb(175, 95, 65), Material = Enum.Material.Slate },
						STONE = { Color = rgb(40, 34, 36), Material = Enum.Material.Basalt },
						METAL = { Color = rgb(58, 52, 56), Material = Enum.Material.Metal },
						GLOW = { Color = rgb(255, 165, 65), Material = Enum.Material.Neon },
						ACCENT = { Color = rgb(245, 115, 42), Material = Enum.Material.Slate },
					})
					if mdl then
						local anchor = mdl:FindFirstChildWhichIsA("BasePart")
						if anchor then pointLight(anchor, rgb(255, 155, 62), 1.5, 52) end
					end
				else
					-- Stepped sandstone approach threshold, massive banded sandstone+terracotta piers, basalt doorway recess & flame keystone
					for st = 0, 3 do
						block("CinderGateStep", V((34 - st * 1.5) * scale, 1.2, 2.4), gateAt + V(0, 0.6 + st * 0.6, 9.5 - st * 2.0), if st % 2 == 0 then rgb(188, 158, 116) else rgb(175, 95, 65), Enum.Material.Sandstone)
					end
					for _, ps in { -1, 1 } do
						local px = ps * 14.5 * scale
						block("CinderGatePierBase", V(9.0 * scale, 5.0 * scale, 10.5 * scale), gateAt + V(px, 2.5 * scale, 0), rgb(40, 34, 36), Enum.Material.Basalt)
						block("CinderGatePierLower", V(8.0 * scale, 8.0 * scale, 9.5 * scale), gateAt + V(px, 9.0 * scale, 0), rgb(188, 158, 116), Enum.Material.Sandstone)
						block("CinderGatePierBand", V(8.2 * scale, 4.5 * scale, 9.7 * scale), gateAt + V(px, 15.2 * scale, 0), rgb(175, 95, 65), Enum.Material.Slate)
						block("CinderGatePierUpper", V(7.8 * scale, 8.5 * scale, 9.2 * scale), gateAt + V(px, 21.7 * scale, 0), rgb(188, 158, 116), Enum.Material.Sandstone)
						block("CinderGateCapital", V(9.2 * scale, 2.4 * scale, 10.2 * scale), gateAt + V(px, 27.1 * scale, 0), rgb(175, 95, 65), Enum.Material.Slate)
					end
					block("CinderGateRecess", V(22 * scale, 30 * scale, 4.5), gateAt + V(0, 15 * scale, -3.5), rgb(24, 20, 22), Enum.Material.Basalt)
					local springY = 28.0 * scale
					local archR = 13.8 * scale
					for ai = 0, 10 do
						local ang = (ai / 10) * math.pi
						local ax = math.cos(ang) * archR
						local ay = springY + math.sin(ang) * archR
						local vCol = if ai % 2 == 0 then rgb(188, 158, 116) else rgb(175, 95, 65)
						local vBlock = block("CinderGateVoussoir", V(4.8 * scale, 5.2 * scale, 9.0 * scale), gateAt + V(ax, ay, 0), vCol, Enum.Material.Sandstone)
						vBlock.CFrame = CFrame.new(origin + gateAt + V(ax, ay, 0)) * CFrame.Angles(0, 0, ang - math.pi * 0.5)
					end
					block("CinderGateKeystoneHood", V(7.5 * scale, 8.5 * scale, 10.2 * scale), gateAt + V(0, springY + archR + 3.2 * scale, 0.8), rgb(175, 95, 65), Enum.Material.Slate)
					local emberKey = orb("CinderGateFlameKeystone", gateAt + V(0, springY + archR + 3.5 * scale, 4.2), V(3.0, 4.8, 2.2), rgb(255, 165, 65), Enum.Material.Neon)
					pointLight(emberKey, rgb(255, 155, 62), 1.5, 52)
				end
			end)
		elseif layout.Authored == "ashen:2" then
			-- Tented Caravan Master's Tomb Pavilion behind Apex PortalSpots (Z = -220, clear of -198 PortalSpots)
			local tombAt = V(apex.X, apex.Y - 0.5, apex.Z - apex.Depth / 2 - 10)
			group("MasterTombPavilion", function()
				if KitProps.Has("MasterTombPavilion") then
					local mdl = kitAt("MasterTombPavilion", CFrame.new(tombAt), 1.25 * scale, {
						TRIM = { Color = rgb(188, 158, 116), Material = Enum.Material.Sandstone },
						STONE = { Color = rgb(44, 38, 40), Material = Enum.Material.Basalt },
						FOLIAGE = { Color = rgb(124, 118, 108), Material = Enum.Material.Fabric },
						GOLD = { Color = gold, Material = Enum.Material.Metal },
						METAL = { Color = rgb(58, 52, 56), Material = Enum.Material.Metal },
						GLOW = { Color = rgb(255, 162, 62), Material = Enum.Material.Neon },
					})
					if mdl then
						local anchor = mdl:FindFirstChildWhichIsA("BasePart")
						if anchor then pointLight(anchor, rgb(255, 160, 62), 1.4, 48) end
					end
				else
					block("TombPodium", V(34 * scale, 4, 24 * scale), tombAt + V(0, 2, 0), rgb(188, 158, 116), Enum.Material.Sandstone)
					for _, ps in { -1, 1 } do
						block("TombPillar", V(2.4, 16 * scale, 2.4), tombAt + V(ps * 12 * scale, 10 * scale, 8), rgb(188, 158, 116), Enum.Material.Sandstone)
					end
					block("TombCanopy", V(28 * scale, 1.2, 20 * scale), tombAt + V(0, 19 * scale, 0), rgb(124, 118, 108), Enum.Material.Fabric)
					local tombLight = orb("TombLanternCore", tombAt + V(0, 8, 10), V(2.5, 3.5, 2.5), rgb(255, 162, 62), Enum.Material.Neon)
					pointLight(tombLight, rgb(255, 160, 62), 1.4, 48)
				end
			end)
		elseif layout.Authored == "ashen:3" then
			-- Lightning Scar Apex Backdrop: twin VarrashLightningRod storm arrestor pylons on visible south-flank rim & fused basalt crater rim
			local scarObsidian = rgb(32, 26, 32)
			local scarAmber = rgb(248, 152, 46)
			local scarCrystal = rgb(230, 220, 206)
			for _, side in { -1, 1 } do
				local rodAt = V(apex.X + side * 48, apex.Y - 0.6, apexBack - 8)
				group("VarrashLightningRod", function()
					currentParent:SetAttribute("OnTerrain", true)
					block("LightningRodBasePlinth", V(20, 8, 20), rodAt - V(0, 3.5, 0), scarObsidian, Enum.Material.Basalt)
					if KitProps.Has("VarrashLightningRod") then
						local mdl = kitAt("VarrashLightningRod", CFrame.new(rodAt) * CFrame.Angles(0, math.rad(side * 22), 0), 1.35 * scale, {
							METAL = { Color = rgb(72, 58, 48), Material = Enum.Material.Metal },
							STONE = { Color = scarObsidian, Material = Enum.Material.Basalt },
							CRYSTAL = { Color = scarCrystal, Material = Enum.Material.Glass },
							GLOW = { Color = scarAmber, Material = Enum.Material.Neon },
						})
						if mdl then
							local anchor = mdl:FindFirstChildWhichIsA("BasePart")
							if anchor then pointLight(anchor, scarAmber, 1.35, 44) end
						end
					else
						block("LightningRodPlinth", V(10, 4, 10), rodAt + V(0, 2, 0), scarObsidian, Enum.Material.Basalt)
						cyl("LightningRodMast", rodAt + V(0, 16 * scale, 0), 0.7, 28 * scale, rgb(72, 58, 48), Enum.Material.Metal)
						local orbNode = orb("LightningCapacitor", rodAt + V(0, 24 * scale, 0), V(3.2, 3.2, 3.2), scarAmber, Enum.Material.Neon)
						pointLight(orbNode, scarAmber, 1.35, 44)
					end
				end)
			end
			-- North crater rim basalt ridge & vitrified fulgurite scar behind PortalSpots (-215)
			group("LightningScarCraterRim", function()
				currentParent:SetAttribute("OnTerrain", true)
				for i = -5, 5 do
					local cragH = (26 + ((math.abs(i) * 9) % 18)) * scale
					local cx = apex.X + i * 26
					local cz = apexBack - 14 - math.abs(i) * 2
					block("ScarCraterWall", V(27, cragH, 24), V(cx, apex.Y + cragH * 0.5 - 6, cz), scarObsidian, Enum.Material.Basalt)
				end
				beam("LightningScarGlassSeam", V(apex.X - 36, apex.Y + 1.5, apexBack - 4), V(apex.X + 36, apex.Y + 1.5, apexBack - 4), 2.4, scarAmber, Enum.Material.Glass, 0.2)
			end)
		elseif layout.Authored == "ashen:4" then
			-- Monumental Sunscar Throne fortress keep framing Apex portals behind the glass-floored Vein Tap
			local fBasalt = rgb(44, 38, 42)
			local fSand = rgb(182, 152, 112)
			local fTerra = rgb(166, 92, 62)
			local fAmber = rgb(252, 146, 44)
			local throneZ = apexBack - 14
			group("SunscarThroneKeep", function()
				currentParent:SetAttribute("OnTerrain", true)
				for _, side in { -1, 1 } do
					block("ThroneBastionWing", V(38, 46 * scale, 26), V(apex.X + side * 44, apex.Y + 23 * scale - 4, throneZ), fBasalt, Enum.Material.Basalt)
					block("ThroneSandstoneButtress", V(14, 52 * scale, 18), V(apex.X + side * 26, apex.Y + 26 * scale - 4, throneZ + 4), fSand, Enum.Material.Sandstone)
				end
				block("ThroneBackKeepWall", V(56, 38 * scale, 16), V(apex.X, apex.Y + 19 * scale - 4, throneZ - 6), fBasalt, Enum.Material.Basalt)
				block("ThroneCorniceTrim", V(110, 3.0, 22), V(apex.X, apex.Y + 38 * scale - 4, throneZ + 2), fTerra, Enum.Material.Slate)
				local brazier = orb("ThroneVeinBrazierGlow", V(apex.X, apex.Y + 28 * scale, throneZ + 4), V(5.5, 4.5, 4.5), fAmber, Enum.Material.Neon)
				pointLight(brazier, fAmber, 1.6, 56)
			end)
		elseif layout.Authored == "ashen:5" then
			-- Monumental Cinderhold Volcanic Vent & Eruption Column rising directly behind the Colossus Dais (clear of PortalSpots at apexBack + 12)
			local cBasalt = rgb(38, 30, 34)
			local cSand = rgb(176, 146, 108)
			local cTerra = rgb(164, 86, 56)
			local cMagma = rgb(255, 110, 28)
			local ventPos = V(apex.X, apex.Y - 2, apexBack - 46)
			group("CinderholdVent", function()
				currentParent:SetAttribute("OnTerrain", true)
				block("CinderholdVentPlinth", V(110, (apex.Y - bottom) + 4, 44), V(ventPos.X, (apex.Y + bottom) * 0.5, ventPos.Z), cBasalt, Enum.Material.Basalt)
				if KitProps.Has("CinderholdVent") then
					local mdl = kitAt("CinderholdVent", CFrame.new(ventPos), 1.05 * scale, {
						STONE = { Color = cBasalt, Material = Enum.Material.Basalt },
						TRIM = { Color = cSand, Material = Enum.Material.Sandstone },
						ALT = { Color = cTerra, Material = Enum.Material.Slate },
						METAL = { Color = rgb(78, 62, 54), Material = Enum.Material.Metal },
						GLOW = { Color = cMagma, Material = Enum.Material.Neon },
					})
					local glowPart = mdl and (mdl:FindFirstChild("GLOW") or mdl:FindFirstChildWhichIsA("BasePart"))
					if glowPart then
						pointLight(glowPart, cMagma, 2.2, 80)
					end
				else
					-- Jagged caldera volcanic slopes + flanking dais colonnades + central eruption magma column
					for k = 1, 9 do
						local a = k * math.pi / 9
						local peakH = (44 + math.sin(a) * 66) * scale
						block("CinderholdCalderaSpire", V(22 * scale, peakH, 28 * scale), ventPos + V((k - 5) * 18 * scale, peakH * 0.5 - 4, -8), cBasalt, Enum.Material.Basalt)
					end
					for _, side in { -1, 1 } do
						local wingX = apex.X + side * 48
						local wingZ = apexBack - 8
						for col = -1, 1 do
							cyl("DaisColonnadePillar", V(wingX + col * 8, apex.Y + 14, wingZ), 2.1, 28, cSand, Enum.Material.Sandstone)
						end
						block("DaisColonnadeLintel", V(24, 3.2, 6), V(wingX, apex.Y + 29, wingZ), cTerra, Enum.Material.Slate)
					end
					local magmaCol = cyl("VentEruptionColumn", ventPos + V(0, 52 * scale, 2), 11 * scale, 108 * scale, cMagma, Enum.Material.Neon)
					pointLight(magmaCol, cMagma, 2.2, 80)
				end
				local plumeAnchor = orb("VentAshPlumeAnchor", ventPos + V(0, 72 * scale, 0), V(4, 4, 4), cBasalt, Enum.Material.Slate, 1)
				local ashPlume = Instance.new("ParticleEmitter")
				ashPlume.Name = "CinderholdAshPlume"
				ashPlume.Color = ColorSequence.new(rgb(255, 128, 42), rgb(44, 32, 32))
				ashPlume.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 7), NumberSequenceKeypoint.new(1, 18) })
				ashPlume.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
				ashPlume.Lifetime = NumberRange.new(3.0, 5.0)
				ashPlume.Rate = 6
				ashPlume.Speed = NumberRange.new(12, 22)
				ashPlume.Parent = plumeAnchor
				for _, s in { -1, 1 } do
					beam("VentEruptionGlowShaft", ventPos + V(s * 12, 92 * scale, 4), V(apex.X + s * 32, apex.Y + 4, apex.Z + 12), 11, rgb(255, 138, 62), Enum.Material.SmoothPlastic, 0.88)
				end
			end)
		else
			group("Volcano", function()
				for k = 1, 11 do
					local a = k * math.pi / 11
					local peakH = (38 + math.sin(a) * 60) * scale
					block("VolcanoCalderaSlope", V(25 * scale, peakH, 30 * scale), backdrop + V((k - 6) * 19 * scale, peakH / 2 - 4, -6), rgb(36, 26, 26), Enum.Material.Basalt)
				end
				orb("CalderaCraterMagma", backdrop + V(0, 66 * scale, -4), V(48 * scale, 18 * scale, 20 * scale), rgb(255, 112, 28), Enum.Material.SmoothPlastic, 0.15)
				orb("VolcanicAshPlume1", backdrop + V(0, 86 * scale, -6), V(62 * scale, 28 * scale, 34 * scale), rgb(52, 38, 38), Enum.Material.Slate, 0.25)
				orb("VolcanicAshPlume2", backdrop + V(12, 106 * scale, -8), V(80 * scale, 30 * scale, 42 * scale), rgb(68, 44, 42), Enum.Material.Slate, 0.35)
				for _, s in { -1, 1 } do
					beam("CalderaLavaRiver", backdrop + V(s * 12 * scale, 62 * scale, 4), backdrop + V(s * 38 * scale, 2, 24), 5.0 * scale, rgb(255, 105, 24), Enum.Material.SmoothPlastic, 0.2)
				end
			end)
		end

	elseif biome == "frozen_citadel" then
		if layout.Authored == "frozen:1" then
			-- The Rimefall cascading behind the Apex shrine & north lake shore, plus the distant Frozen Citadel silhouette high on the ridge.
			local cGranite = rgb(104, 118, 134)
			local cGraniteDark = rgb(74, 86, 100)
			local cSnow = rgb(232, 242, 252)
			local cGlacier = rgb(146, 206, 238)
			local cRimeBlue = rgb(142, 224, 255)
			local wfPos = V(30, apex.Y - 5, apexBack - 7)
			group("RimefallIcefall", function()
				currentParent:SetAttribute("OnTerrain", true)
				block("RimefallBasePlinth", V(72, (apex.Y - bottom) + 6, 24), V(wfPos.X, (apex.Y + bottom) * 0.5 - 2, wfPos.Z - 4), cGraniteDark, Enum.Material.Slate)
				if KitProps.Has("RimefallIcefall") then
					local mdl = kitAt("RimefallIcefall", CFrame.new(wfPos), 0.94 * scale, {
						STONE = { Color = cGraniteDark, Material = Enum.Material.Slate },
						MOSS = { Color = cSnow, Material = Enum.Material.Snow },
						CRYSTAL = { Color = cGlacier, Material = Enum.Material.Ice, Transparency = 0.1 },
						GLOW = { Color = cRimeBlue, Material = Enum.Material.Neon },
					})
					local gp = mdl and (mdl:FindFirstChild("GLOW") or mdl:FindFirstChildWhichIsA("BasePart"))
					if gp then pointLight(gp, cRimeBlue, 1.5, 76) end
				else
					local cliffL = block("RimefallGorgeCliffL", V(14, 56, 18), wfPos + V(-25, 26, 0), cGraniteDark, Enum.Material.Slate)
					cliffL.CFrame = CFrame.new(origin + wfPos + V(-25, 26, 0)) * CFrame.Angles(0, 0.12, -0.06)
					local cliffR = block("RimefallGorgeCliffR", V(16, 66, 20), wfPos + V(28, 31, 0), cGraniteDark, Enum.Material.Slate)
					cliffR.CFrame = CFrame.new(origin + wfPos + V(28, 31, 0)) * CFrame.Angles(0, -0.14, 0.05)
					block("RimefallUpperSnowCap", V(64, 6, 18), wfPos + V(1, 64, -3), cSnow, Enum.Material.Snow)
					local cols = {
						{ -17, 56, 12, 3.0, cGlacier },
						{ -8, 63, 13, 5.5, rgb(176, 226, 250) },
						{ 2, 66, 14, 7.0, cGlacier },
						{ 12, 60, 13, 4.5, rgb(166, 220, 246) },
						{ 20, 52, 11, 2.5, cGlacier },
					}
					for idx, col in cols do
						local p = block("RimefallCascadeColumn", V(col[3], col[2], 12), wfPos + V(col[1], col[2] * 0.5, col[4]), col[5], Enum.Material.Ice, nil, 0.1)
						if idx == 3 then pointLight(p, cRimeBlue, 1.5, 76) end
					end
					for _, ic in { -14, -4, 7, 17 } do
						block("RimefallIcicleSpire", V(3.2, 18, 3.2), wfPos + V(ic, 46, 10.5), rgb(212, 240, 255), Enum.Material.Ice, nil, 0.08)
					end
					for _, sp in { -15, 0, 16 } do
						orb("RimefallFoamDrift", wfPos + V(sp, 6, 12), V(16, 10, 13), cSnow, Enum.Material.Snow)
					end
				end
			end)
			-- Ward-Star Shrine Arch framing the back of Rimefall Shrine outside both Apex portal lanes
			arch(V(apex.X, apex.Y, apexBack - 7), 62, 34, 8, cGranite, Enum.Material.Slate, 0)
			-- Distant Frozen Citadel silhouette rising high above the falls in alpine mist
			group("FrozenCitadelSilhouette", function()
				currentParent:SetAttribute("OnTerrain", true)
				local silColor = rgb(162, 176, 194)
				local silZ = -d * 0.5 + 4
				block("CitadelKeepSilhouette", V(52, 18, 12), V(18, 76, silZ), silColor, Enum.Material.Slate, nil, 0.22)
				block("CitadelCentralKeep", V(18, 28, 12), V(18, 94, silZ), silColor, Enum.Material.Slate, nil, 0.24)
				local spireCone = block("CitadelCentralRoof", V(13, 18, 10), V(18, 113, silZ), silColor, Enum.Material.Slate, nil, 0.26)
				spireCone.CFrame = CFrame.new(origin + V(18, 113, silZ)) * CFrame.Angles(0, 0, math.rad(45))
				for _, tw in { { -4, 24, 9 }, { 38, 26, 10 } } do
					cyl("CitadelSpireSilhouette", V(tw[1], 88 + tw[2] * 0.5, silZ), tw[3] * 0.5, tw[2], silColor, Enum.Material.Slate, 0.24)
					local cap = block("CitadelTurretRoof", V(tw[3] * 0.72, tw[3] * 0.72, tw[3] * 0.72), V(tw[1], 88 + tw[2] + 3, silZ), silColor, Enum.Material.Slate, nil, 0.26)
					cap.CFrame = CFrame.new(origin + V(tw[1], 88 + tw[2] + 3, silZ)) * CFrame.Angles(0, 0, math.rad(45))
				end
			end)
		elseif layout.Authored == "frozen:2" then
			-- Floor 17 Commander's Hall north garrison wall: twin round conical-roofed watchtowers + crenellated curtain wall + keep gable behind Apex portals
			local cGranite = rgb(104, 116, 130)
			local cGraniteDark = rgb(72, 82, 96)
			local cSnow = rgb(236, 244, 254)
			local cGlacier = rgb(148, 214, 246)
			local wallZ = apexBack - 6
			group("CommanderKeepBackdrop", function()
				currentParent:SetAttribute("OnTerrain", true)
				-- Twin round watchtowers flanking Commander's Hall (matching media_1795013043673_6f636e12.jpg upper skyline)
				for _, s in { -1, 1 } do
					local tx = s * 86
					local tz = wallZ + 12
					cyl("GarrisonCornerTower", V(tx, apex.Y + 26, tz), 13.5, 58, cGranite, Enum.Material.Slate)
					cyl("GarrisonTowerCorbel", V(tx, apex.Y + 55, tz), 15.2, 4.5, cGraniteDark, Enum.Material.Slate)
					for step = 0, 3 do
						local cr = 15.6 - step * 3.4
						cyl("GarrisonTowerRoofTier", V(tx, apex.Y + 59 + step * 5.0, tz), cr, 5.2, if step % 2 == 0 then cGraniteDark else cSnow, if step % 2 == 0 then Enum.Material.Slate else Enum.Material.Snow)
					end
					-- Flanking crenellated battlement curtain connecting watchtower to Armory flank & back wall
					local cwX = s * 68
					block("GarrisonCurtainWall", V(36, 34, 10), V(cwX, apex.Y + 14, tz - 4), cGranite, Enum.Material.Slate)
					for m = -1, 1 do
						block("GarrisonMerlon", V(6.5, 5.0, 10.6), V(cwX + m * 12, apex.Y + 33.5, tz - 4), cGraniteDark, Enum.Material.Slate)
					end
				end
				-- Commander's Hall central keep wall & steep slate gable strictly north of Apex portals
				local keepZ = wallZ - 6
				block("CommanderKeepWall", V(92, 44, 14), V(0, apex.Y + 22, keepZ), cGranite, Enum.Material.Slate)
				block("CommanderKeepGableFill", V(56, 12, 13.4), V(0, apex.Y + 46, keepZ), cGranite, Enum.Material.Slate)
				for _, ps in { -28, -12, 12, 28 } do
					block("CommanderKeepPilaster", V(5, 44, 15.6), V(ps, apex.Y + 22, keepZ), cGraniteDark, Enum.Material.Slate)
				end
				for _, side in { -1, 1 } do
					local roof = block("CommanderKeepRoofSlope", V(58, 2.4, 22), V(0, apex.Y + 54, keepZ), rgb(54, 62, 74), Enum.Material.Slate)
					roof.CFrame = CFrame.new(origin + V(side * 22, apex.Y + 54, keepZ)) * CFrame.Angles(0, 0, -side * 0.56)
					local snowCap = block("CommanderKeepSnow", V(56, 1.5, 21.6), V(0, apex.Y + 55.6, keepZ), cSnow, Enum.Material.Snow)
					snowCap.CFrame = CFrame.new(origin + V(side * 22, apex.Y + 55.6, keepZ)) * CFrame.Angles(0, 0, -side * 0.56)
					block("CommanderKeepWindow", V(4.4, 11, 1.4), V(side * 20, apex.Y + 25, wallZ + 1.2), rgb(150, 200, 232), Enum.Material.Ice, nil, 0.2)
				end
				block("CommanderKeepDoor", V(18, 22, 2.4), V(0, apex.Y + 11, wallZ + 1.2), rgb(52, 38, 28), Enum.Material.WoodPlanks)
				block("CommanderKeepDoorTrim", V(19.6, 2.4, 3), V(0, apex.Y + 14, wallZ + 1.4), rgb(44, 48, 56), Enum.Material.Metal)
				block("CommanderKeepArchLintel", V(32, 6, 4), V(0, apex.Y + 26, wallZ + 2), cGlacier, Enum.Material.Ice, nil, 0.15)
			end)
		elseif layout.Authored == "frozen:3" then
			-- Floor 18 Icefall Gate: twin tall conical-roofed round Whiteguard towers flanking a portcullis arch gatehouse under a massive frozen icefall
			local cGranite = rgb(124, 138, 154)
			local cGraniteDark = rgb(74, 86, 100)
			local cSnow = rgb(236, 244, 254)
			local cGlacier = rgb(148, 214, 246)
			local cIron = rgb(40, 44, 52)
			local cRimeBlue = rgb(142, 224, 255)
			local wallZ = apexBack - 6
			group("IcefallGateBackdrop", function()
				currentParent:SetAttribute("OnTerrain", true)
				-- Twin round conical-capped gate towers (exact silhouette match to media_1795016381755_4ec5e256.jpg)
				for _, s in { -1, 1 } do
					local tx = s * 46
					local tz = wallZ + 4
					cyl("IcefallGateTower", V(tx, apex.Y + 30, tz), 13.5, 64, cGranite, Enum.Material.Slate)
					cyl("IcefallGateTowerCorbel", V(tx, apex.Y + 62, tz), 15.2, 4.5, cGraniteDark, Enum.Material.Slate)
					for step = 0, 3 do
						local cr = 15.8 - step * 3.5
						cyl("IcefallGateConeTier", V(tx, apex.Y + 66 + step * 5.2, tz), cr, 5.4, if step % 2 == 0 then cGraniteDark else cSnow, if step % 2 == 0 then Enum.Material.Slate else Enum.Material.Snow)
					end
					block("IcefallGateWindowSlit", V(2.4, 9.0, 2.0), V(tx, apex.Y + 44, tz + 13.0), cRimeBlue, Enum.Material.Ice, nil, 0.15)
					-- Gate jamb pilaster + rimelight crystal sconce framing arch
					block("IcefallGateJamb", V(4.6, 36, 15.6), V(s * 15.5, apex.Y + 18, wallZ), cGraniteDark, Enum.Material.Slate)
					block("IcefallGateCrystalSconce", V(1.6, 4.2, 1.6), V(s * 15.5, apex.Y + 16, wallZ + 8.4), cRimeBlue, Enum.Material.Neon)
					-- Flanking battlement wing walls anchoring towers into north mountain crags
					block("IcefallGateWingWall", V(44, 30, 12), V(s * 76, apex.Y + 14, wallZ - 2), cGranite, Enum.Material.Slate)
					block("IcefallGateWingSnow", V(42, 3.0, 12.6), V(s * 76, apex.Y + 30, wallZ - 2), cSnow, Enum.Material.Snow)
				end
				-- Central crenellated gatehouse wall + pointed portcullis archway strictly behind Apex portals
				block("IcefallGateWallL", V(24, 42, 14), V(-24, apex.Y + 21, wallZ), cGranite, Enum.Material.Slate)
				block("IcefallGateWallR", V(24, 42, 14), V(24, apex.Y + 21, wallZ), cGranite, Enum.Material.Slate)
				block("IcefallGateLintel", V(68, 14, 14), V(0, apex.Y + 36, wallZ), cGranite, Enum.Material.Slate)
				block("IcefallGateVoid", V(26, 28, 8), V(0, apex.Y + 14, wallZ - 2), rgb(24, 30, 38), Enum.Material.Slate)
				for _, m in { -24, -12, 0, 12, 24 } do
					block("IcefallGateMerlon", V(6.5, 5.5, 14.6), V(m, apex.Y + 45.5, wallZ), cGraniteDark, Enum.Material.Slate)
				end
				-- Iron portcullis grate bars hanging inside the open archway
				for gx = -9, 9, 4.5 do
					block("PortcullisBar", V(0.75, 18, 0.8), V(gx, apex.Y + 20, wallZ + 3.5), cIron, Enum.Material.Metal)
				end
				block("PortcullisCrossbar", V(22, 1.4, 1.0), V(0, apex.Y + 14, wallZ + 3.5), cIron, Enum.Material.Metal)
				-- Monumental frozen icefall cascade pouring down the mountain wall behind the gatehouse
				for idx, col in { { -28, 78, 18 }, { -10, 92, 22 }, { 10, 96, 22 }, { 28, 82, 18 } } do
					local iceCol = block("NorthIcefallCascade", V(col[3], col[2], 14), V(col[1], apex.Y + col[2] * 0.5 + 4, wallZ - 14), if idx % 2 == 0 then rgb(174, 226, 250) else cGlacier, Enum.Material.Ice, nil, 0.1)
					if idx == 3 then pointLight(iceCol, cRimeBlue, 1.4, 72) end
				end
			end)
		elseif layout.Authored == "frozen:4" then
			-- Floor 19 Monumental Whiteguard Citadel Keep: soaring multi-tiered royal donjon, conical slate-and-snow
			-- spires, gothic pointed waterfall arch portal, stepped buttresses, curtain wings, and emerald aurora.
			local cGranite = rgb(118, 132, 148)
			local cGraniteDark = rgb(66, 76, 90)
			local cSlateRoof = rgb(52, 62, 78)
			local cSnow = rgb(236, 244, 254)
			local cGlacier = rgb(148, 214, 246)
			local cGlacierBright = rgb(178, 228, 252)
			local cRimelight = rgb(78, 236, 255)
			local cBanner = rgb(44, 88, 136)
			local wallZ = apexBack - 16
			group("WhiteguardKeepBackdrop", function()
				currentParent:SetAttribute("OnTerrain", true)
				-- Lower main keep fortress wall framing the pointed waterfall arch
				for _, s in { -1, 1 } do
					block("KeepMainPier", V(34, 68, 22), V(s * 38, apex.Y + 34, wallZ), cGranite, Enum.Material.Slate):SetAttribute("SolidScenery", false)
					block("KeepMainButtress", V(8.5, 62, 22), V(s * 24, apex.Y + 31, wallZ + 2), cGraniteDark, Enum.Material.Slate):SetAttribute("SolidScenery", false)
					block("KeepMainButtressCap", V(9.5, 2.5, 22.5), V(s * 24, apex.Y + 63, wallZ + 2), cSnow, Enum.Material.Snow):SetAttribute("SolidScenery", false)
					-- Flanking great octagonal/cylindrical donjon towers with corbel collar & stacked conical roof
					local tx = s * 52
					cyl("KeepHallTurret", V(tx, apex.Y + 46, wallZ + 2), 15.5, 92, cGranite, Enum.Material.Slate):SetAttribute("SolidScenery", false)
					cyl("KeepHallTurretBase", V(tx, apex.Y + 7, wallZ + 2), 16.5, 14, cGraniteDark, Enum.Material.Slate):SetAttribute("SolidScenery", false)
					cyl("KeepHallTurretCollar", V(tx, apex.Y + 88, wallZ + 2), 17.5, 4.5, cGraniteDark, Enum.Material.Slate):SetAttribute("SolidScenery", false)
					cyl("KeepHallTurretSnowRim", V(tx, apex.Y + 90.8, wallZ + 2), 18.0, 1.4, cSnow, Enum.Material.Snow):SetAttribute("SolidScenery", false)
					for k = 0, 4 do
						local r = 17.5 - k * 3.2
						local cy = apex.Y + 93 + k * 4.4
						cyl("KeepHallTurretCone", V(tx, cy, wallZ + 2), r, 4.6, if k % 2 == 0 then cSlateRoof else cSnow, if k % 2 == 0 then Enum.Material.Slate else Enum.Material.Snow)
					end
					block("KeepHallTurretSpire", V(1.6, 8, 1.6), V(tx, apex.Y + 115, wallZ + 2), cGraniteDark, Enum.Material.Metal)
					for _, wyOff in { 42, 66 } do
						block("KeepHallWindow", V(2.6, 9.5, 2.0), V(tx, apex.Y + wyOff, wallZ + 18.6), cRimelight, Enum.Material.Neon)
					end
					-- Curtain wing walls + outer bastion watchtowers
					block("KeepHallWingWall", V(58, 40, 16), V(s * 84, apex.Y + 20, wallZ - 4), cGranite, Enum.Material.Slate)
					block("KeepHallWingSnow", V(56, 3.0, 16.8), V(s * 84, apex.Y + 41, wallZ - 4), cSnow, Enum.Material.Snow)
					block("KeepWingIcicle", V(2.4, 8.5, 2.4), V(s * 74, apex.Y + 35, wallZ + 4.5), cGlacier, Enum.Material.Ice, nil, 0.14)
					local ox = s * 116
					cyl("KeepOuterTower", V(ox, apex.Y + 34, wallZ - 2), 13.0, 68, cGranite, Enum.Material.Slate)
					cyl("KeepOuterCrown", V(ox, apex.Y + 69, wallZ - 2), 14.5, 4.0, cGraniteDark, Enum.Material.Slate)
					for k = 0, 2 do
						cyl("KeepOuterCone", V(ox, apex.Y + 72.5 + k * 4.0, wallZ - 2), 14.2 - k * 4.2, 4.2, if k == 1 then cSnow else cSlateRoof, if k == 1 then Enum.Material.Snow else Enum.Material.Slate)
					end
					block("KeepHallBanner", V(4.2, 16.0, 0.8), V(s * 34, apex.Y + 44, wallZ + 11.8), cBanner, Enum.Material.Fabric)
				end
				-- Pointed Gothic Keep Archway + cascading glacial waterfall pouring forward over the cliff
				block("KeepHallUpperLintels", V(56, 16, 22), V(0, apex.Y + 60, wallZ), cGranite, Enum.Material.Slate)
				for _, aSide in { -1, 1 } do
					local archRib = block("KeepGothicArchRib", V(22, 7.5, 24), V(aSide * 10.5, apex.Y + 48, wallZ + 1), cGraniteDark, Enum.Material.Slate)
					archRib.CFrame = CFrame.new(origin + V(aSide * 10.5, apex.Y + 48, wallZ + 1)) * CFrame.Angles(0, 0, -aSide * math.rad(38))
					local archSnow = block("KeepGothicArchSnow", V(21, 2.2, 24.5), V(aSide * 10.5, apex.Y + 52.5, wallZ + 1), cSnow, Enum.Material.Snow)
					archSnow.CFrame = CFrame.new(origin + V(aSide * 10.5, apex.Y + 52.5, wallZ + 1)) * CFrame.Angles(0, 0, -aSide * math.rad(38))
				end
				block("KeepHallIceArchBacking", V(44, 52, 12), V(0, apex.Y + 26, wallZ + 2), rgb(26, 38, 54), Enum.Material.Slate)
				for idx, col in { { -14, 46, 10 }, { -5, 52, 11 }, { 5, 52, 11 }, { 14, 45, 10 } } do
					local waterCol = block("KeepHallGateIcefall", V(col[3], col[2], 7.5), V(col[1], apex.Y + col[2] * 0.5 + 1, wallZ + 8), if idx == 2 or idx == 3 then cGlacierBright else cGlacier, Enum.Material.Ice, nil, 0.1)
					if idx == 2 then pointLight(waterCol, cRimelight, 1.4, 72) end
				end
				-- Soaring Upper Royal Donjon rising behind/above the gothic gate arch
				block("KeepUpperRoyalHall", V(66, 38, 24), V(0, apex.Y + 84, wallZ - 6), cGranite, Enum.Material.Slate)
				for _, rs in { -1, 1 } do
					local roofPitch = block("KeepUpperGableRoof", V(38, 3.2, 26), V(rs * 16.5, apex.Y + 109, wallZ - 6), cSlateRoof, Enum.Material.Slate)
					roofPitch.CFrame = CFrame.new(origin + V(rs * 16.5, apex.Y + 109, wallZ - 6)) * CFrame.Angles(0, 0, -rs * math.rad(32))
					local roofSnow = block("KeepUpperGableSnow", V(37, 1.6, 26.5), V(rs * 16.5, apex.Y + 111.2, wallZ - 6), cSnow, Enum.Material.Snow)
					roofSnow.CFrame = CFrame.new(origin + V(rs * 16.5, apex.Y + 111.2, wallZ - 6)) * CFrame.Angles(0, 0, -rs * math.rad(32))
					cyl("KeepUpperSpirelet", V(rs * 34, apex.Y + 92, wallZ - 4), 6.2, 34, cGraniteDark, Enum.Material.Slate)
					cyl("KeepUpperSpireCap", V(rs * 34, apex.Y + 112, wallZ - 4), 7.2, 8.5, cSnow, Enum.Material.Snow)
					block("KeepUpperClerestory", V(3.0, 12.0, 2.0), V(rs * 18, apex.Y + 84, wallZ + 6.5), cRimelight, Enum.Material.Neon)
				end
				local roseWin = cyl("KeepRoyalRoseWindow", V(0, apex.Y + 84, wallZ + 6.5), 7.8, 2.2, cRimelight, Enum.Material.Neon, 0.14)
				roseWin.CFrame = CFrame.new(origin + V(0, apex.Y + 84, wallZ + 6.5)) * CFrame.Angles(0, math.pi * 0.5, 0)
				block("KeepHallIceCrest", V(112, 3.8, 22), V(0, apex.Y + 69, wallZ), cSnow, Enum.Material.Snow)
			end)
			for aIdx = -1, 2 do
				local ay = h - 14 + math.abs(aIdx) * 4
				local az = -170 + aIdx * 42
				beam("AuroraBorealisRibbon", V(-w * 0.34, ay, az + 24), V(w * 0.34, ay + 8, az - 28), 6.5, if aIdx % 2 == 0 then rgb(84, 255, 198) else rgb(148, 178, 255), Enum.Material.Neon, 0.72)
			end
		elseif layout.Authored == "frozen:5" then
			-- Floor 20 North Apse Ruined Castle Backdrop: broken pointed gothic apse arch, crown of icicles,
			-- Shattered Rose Window, Frozen Avalanche Wave bursting behind the throne, & Frostbound King on ThroneOfIcicles.
			local cGranite = rgb(104, 118, 134)
			local cGraniteDark = rgb(58, 68, 82)
			local cIron = rgb(44, 50, 60)
			local cSnow = rgb(236, 244, 254)
			local cGlacier = rgb(148, 214, 246)
			local cRimelight = rgb(78, 236, 255)
			local cBanner = rgb(44, 88, 136)
			local wallZ = apexBack - 16
			group("ApexThroneCathedralApse", function()
				currentParent:SetAttribute("OnTerrain", true)
				for _, s in { -1, 1 } do
					local apsePier = block("ApseMainPier", V(36, 86, 22), V(s * 48, apex.Y + 43, wallZ), cGranite, Enum.Material.Slate)
					apsePier:SetAttribute("SolidScenery", false)
					block("ApseInnerButtress", V(10, 78, 24), V(s * 34, apex.Y + 39, wallZ + 2), cGraniteDark, Enum.Material.Slate):SetAttribute("SolidScenery", false)
					block("ApseWingWall", V(82, 54, 16), V(s * 106, apex.Y + 27, wallZ - 4), cGranite, Enum.Material.Slate):SetAttribute("SolidScenery", false)
					block("ApseWingSnow", V(84, 2.8, 17), V(s * 106, apex.Y + 55, wallZ - 4), cSnow, Enum.Material.Snow):SetAttribute("SolidScenery", false)
					block("ApseChoirBanner", V(4.8, 20.0, 0.8), V(s * 48, apex.Y + 54, wallZ + 11.6), cBanner, Enum.Material.Fabric):SetAttribute("SolidScenery", false)
					block("ApseLancetSlit", V(3.2, 16.0, 2.0), V(s * 48, apex.Y + 32, wallZ + 11.4), cRimelight, Enum.Material.Neon):SetAttribute("SolidScenery", false)
					-- Broken pointed gothic vault arch framing the ruined apse sky breach
					local apseArch = block("ApseBrokenArchRib", V(34, 7.5, 22), V(s * 18, apex.Y + 76, wallZ + 2), cGraniteDark, Enum.Material.Slate)
					apseArch.CFrame = CFrame.new(origin + V(s * 18, apex.Y + 76, wallZ + 2)) * CFrame.Angles(0, 0, -s * math.rad(34))
					apseArch:SetAttribute("SolidScenery", false)
					local archSnow = block("ApseArchSnow", V(33, 2.2, 22.6), V(s * 18, apex.Y + 80.2, wallZ + 2), cSnow, Enum.Material.Snow)
					archSnow.CFrame = CFrame.new(origin + V(s * 18, apex.Y + 80.2, wallZ + 2)) * CFrame.Angles(0, 0, -s * math.rad(34))
					archSnow:SetAttribute("SolidScenery", false)
				end
				-- Crown of jagged icicles hanging along the shattered apse vault above the Throne
				for _, ic in { { -24, 13 }, { -16, 17 }, { -8, 15 }, { 0, 19 }, { 8, 16 }, { 16, 17 }, { 24, 12 } } do
					local icPart = block("ApseCrownIcicle", V(2.0, ic[2], 2.0), V(ic[1], apex.Y + 72 - math.abs(ic[1]) * 0.25 - ic[2] * 0.5, wallZ + 10), cGlacier, Enum.Material.Ice, nil, 0.14)
					icPart:SetAttribute("SolidScenery", false)
				end
			end)
			-- Shattered Rose Window high in upper broken apse wall above the breach
			group("ShatteredRoseWindow", function()
				currentParent:SetAttribute("OnTerrain", true)
				if KitProps.Has("ShatteredRoseWindow") then
					kitAt("ShatteredRoseWindow", CFrame.new(0, apex.Y + 42, wallZ - 14), 1.45 * scale, {
						STONE = { Color = cGraniteDark, Material = Enum.Material.Slate },
						MOSS = { Color = cSnow, Material = Enum.Material.Snow },
						CRYSTAL = { Color = cGlacier, Material = Enum.Material.Ice, Transparency = 0.14 },
						GLOW = { Color = cRimelight, Material = Enum.Material.Neon },
					})
				else
					local ring = cyl("ApseRoseRing", V(0, apex.Y + 74, wallZ - 12), 14.5, 4.0, cGraniteDark, Enum.Material.Slate)
					ring.CFrame = CFrame.new(origin + V(0, apex.Y + 74, wallZ - 12)) * CFrame.Angles(0, math.pi * 0.5, 0)
					ring:SetAttribute("SolidScenery", false)
				end
			end)
			-- Colossal Frozen Avalanche Wave bursting through the shattered apse behind the Throne (safely behind portals)
			group("FrozenAvalancheWave", function()
				currentParent:SetAttribute("OnTerrain", true)
				local wPos = V(0, apex.Y, wallZ - 2)
				if KitProps.Has("FrozenAvalancheWave") then
					local mdl = kitAt("FrozenAvalancheWave", CFrame.new(wPos), 1.38 * scale, {
						MOSS = { Color = cSnow, Material = Enum.Material.Snow },
						CRYSTAL = { Color = cGlacier, Material = Enum.Material.Ice, Transparency = 0.12 },
						STONE = { Color = cGraniteDark, Material = Enum.Material.Slate },
					})
					local gp = mdl and mdl:FindFirstChildWhichIsA("BasePart")
					if gp then pointLight(gp, cRimelight, 1.2, 64) end
				else
					for wi, wv in { { -24, 38, 18 }, { -8, 52, 22 }, { 8, 54, 22 }, { 24, 36, 18 } } do
						local crest = block("AvalancheWaveCrest", V(wv[3], wv[2], 18), wPos + V(wv[1], wv[2] * 0.5 - 2, -2), if wi == 2 or wi == 3 then rgb(174, 226, 250) else cGlacier, Enum.Material.Ice, nil, 0.1)
						crest.CFrame = CFrame.new(origin + wPos + V(wv[1], wv[2] * 0.5 - 2, -2)) * CFrame.Angles(math.rad(16), 0, 0)
						crest:SetAttribute("SolidScenery", false)
						if wi == 2 then pointLight(crest, cRimelight, 1.2, 64) end
					end
					block("AvalancheSnowBank", V(72, 16, 20), wPos + V(0, 8, -4), cSnow, Enum.Material.Snow):SetAttribute("SolidScenery", false)
				end
			end)
			-- The Frostbound King upon the Elevated Stepped Royal Throne Dais (Z = wallZ + 4, Y = apex.Y + 8, visible above portals)
			group("ThroneOfIcicles", function()
				currentParent:SetAttribute("OnTerrain", true)
				local daisY = apex.Y + 8
				local tPos = V(0, daisY, wallZ + 4)
				-- Stepped decorative throne dais & stair rising behind the PortalSpots line (Z = -290..-306)
				block("ThroneElevatedSubDais", V(38, 12, 28), V(0, apex.Y + 2, wallZ + 6), cGraniteDark, Enum.Material.Slate):SetAttribute("SolidScenery", false)
				for st = 1, 4 do
					block("ThroneApproachStep", V(34 - st * 1.5, 2.2, 4.2), V(0, apex.Y + st * 2.0 - 0.8, wallZ + 20 - st * 2.6), cGranite, Enum.Material.Slate):SetAttribute("SolidScenery", false)
				end
				if KitProps.Has("ThroneOfIcicles") then
					local mdl = kitAt("ThroneOfIcicles", CFrame.new(tPos), 1.35 * scale, {
						STONE = { Color = cGraniteDark, Material = Enum.Material.Slate },
						METAL = { Color = cIron, Material = Enum.Material.Metal },
						MOSS = { Color = cSnow, Material = Enum.Material.Snow },
						CRYSTAL = { Color = cGlacier, Material = Enum.Material.Ice, Transparency = 0.1 },
						GLOW = { Color = cRimelight, Material = Enum.Material.Neon },
					})
					local gp = mdl and mdl:FindFirstChildWhichIsA("BasePart")
					if gp then pointLight(gp, cRimelight, 1.6, 58) end
				else
					block("ThronePlinthBase", V(28, 4.5, 22), tPos + V(0, 2.2, 0), cGraniteDark, Enum.Material.Slate):SetAttribute("SolidScenery", false)
					block("ThroneHighBack", V(16, 42, 6), tPos + V(0, 23, -5), cGranite, Enum.Material.Slate):SetAttribute("SolidScenery", false)
					block("ThroneSeatArmL", V(3.2, 8.5, 11), tPos + V(-7.2, 6.2, -1), cGraniteDark, Enum.Material.Slate):SetAttribute("SolidScenery", false)
					block("ThroneSeatArmR", V(3.2, 8.5, 11), tPos + V(7.2, 6.2, -1), cGraniteDark, Enum.Material.Slate):SetAttribute("SolidScenery", false)
					for _, s in { -1, 1 } do
						block("ThroneIceSpire", V(4.2, 48, 4.2), tPos + V(s * 9.5, 25, -4), cGlacier, Enum.Material.Ice, nil, 0.1):SetAttribute("SolidScenery", false)
					end
					block("FrostboundKingBody", V(9.5, 13, 7.5), tPos + V(0, 12.5, 0), cIron, Enum.Material.Metal):SetAttribute("SolidScenery", false)
					block("FrostboundKingPauldrons", V(13.5, 3.8, 7.8), tPos + V(0, 17.5, 0), cIron, Enum.Material.Metal):SetAttribute("SolidScenery", false)
					block("FrostboundKingHead", V(4.5, 4.5, 4.5), tPos + V(0, 21.5, 0), cIron, Enum.Material.Metal):SetAttribute("SolidScenery", false)
					block("FrostboundKingCrown", V(5.2, 2.6, 5.2), tPos + V(0, 24.5, 0), cGlacier, Enum.Material.Ice, nil, 0.1):SetAttribute("SolidScenery", false)
					block("FrostboundKingSword", V(1.2, 16.0, 1.4), tPos + V(0, 11.0, 5.4), cIron, Enum.Material.Metal):SetAttribute("SolidScenery", false)
					local heart = orb("KingStillheart", tPos + V(0, 14.5, 4.2), V(3.8, 4.4, 2.4), cRimelight, Enum.Material.Neon)
					heart:SetAttribute("SolidScenery", false)
					pointLight(heart, cRimelight, 1.6, 58)
				end
			end)
			-- Still, eerie emerald-indigo night Aurora Borealis gleaming above the broken cathedral roof
			for aIdx = -1, 2 do
				local ay = h - 14 + math.abs(aIdx) * 4
				local az = -190 + aIdx * 48
				beam("AuroraBorealisRibbon", V(-w * 0.34, ay, az + 24), V(w * 0.34, ay + 8, az - 28), 6.5, if aIdx % 2 == 0 then rgb(78, 255, 206) else rgb(142, 168, 255), Enum.Material.Neon, 0.70)
			end
		else
			group("CitadelKeep", function()
				block("CitadelKeepHall", V(102 * scale, 58 * scale, 36 * scale), backdrop + V(0, 29 * scale, -4), theme.CliffColor, Enum.Material.Brick)
				spire(backdrop + V(0, 52 * scale, -4), 52 * scale, 19 * scale, rgb(145, 218, 252), accent, true)
				cyl("GlacialRoseWindow", backdrop + V(0, 44 * scale, 15), 15 * scale, 2.2, accent, Enum.Material.Neon, 0.18)
			end)
			for _, s in { -1, 1 } do
				spire(backdrop + V(s * 50 * scale, 0, 6), 68 * scale, 17 * scale, rgb(130, 205, 245), accent, true)
			end
			arch(backdrop + V(0, 0, 16), 40 * scale, 36 * scale, 10, theme.TrimColor, Enum.Material.Ice, 0)
			for aIdx = -1, 1 do
				beam("AuroraBorealisRibbon", V(-w * 0.38, h - 14 - math.abs(aIdx) * 6, aIdx * 85), V(w * 0.38, h - 10, aIdx * 85 - 35), 8.5, if aIdx == 0 then rgb(95, 255, 195) else rgb(115, 220, 255), Enum.Material.Neon, 0.72)
			end
		end

	elseif biome == "infernal_foundry" and (layout.Authored == "infernal:1" or layout.Authored == "infernal:2" or layout.Authored == "infernal:3" or layout.Authored == "infernal:4" or layout.Authored == "infernal:5") then
		-- Floors 21-25 build their own fortress, furnace, crucible and works backdrops in TowerSetPieces.
	elseif biome == "infernal_foundry" then
		for _, s in { -1, 1 } do
			spire(backdrop + V(s * 54 * scale, 0, 4), 72 * scale, 19 * scale, rgb(38, 28, 30), rgb(255, 108, 28), false)
			cogwheel(V(s * 78 * scale, h - 28, -d * 0.18), 30 * scale, CFrame.Angles(math.pi / 2, 0, 0))
			chain(V(s * 58 * scale, h - 8, -d * 0.24), backdrop + V(s * 24 * scale, 64 * scale, 2), 2.5)
		end
		group("ForgeCrucible", function()
			cyl("SuspendedForgeRing", backdrop + V(0, 70 * scale, 2), 40 * scale, 11 * scale, theme.TrimColor, Enum.Material.Metal)
			cyl("MoltenCrucibleVat", backdrop + V(0, 54 * scale, 2), 24 * scale, 19 * scale, rgb(48, 36, 38), Enum.Material.Metal)
			block("CrucibleLavaCascade", V(15 * scale, 54 * scale, 9 * scale), backdrop + V(0, 26 * scale, 10), rgb(255, 118, 24), Enum.Material.SmoothPlastic, nil, 0.2)
			orb("CrucibleSplashPool", backdrop + V(0, 2, 14), V(40 * scale, 5 * scale, 28 * scale), rgb(255, 145, 35), Enum.Material.SmoothPlastic, 0.2)
		end)

	elseif biome == "thunder_highlands" then
		group("StormPeaks", function()
			for k = 1, 7 do
				local mh = (40 + (4 - math.abs(k - 4)) * 16) * scale
				block("StormPeakCrag", V(28 * scale, mh, 30 * scale), backdrop + V((k - 4) * 20 * scale, mh / 2, -6), cliffColor, Enum.Material.Rock)
			end
			spire(backdrop + V(0, 30 * scale, -4), 72 * scale, 19 * scale, theme.TrimColor, accent, false)
		end)
		for ringIdx = 1, 5 do
			ring(
				"TempestVortexRing",
				V(0, h - 8 - ringIdx * 4, backdrop.Z + 18),
				(15 + ringIdx * 16) * scale,
				3.4,
				if ringIdx % 2 == 0 then rgb(135, 115, 255) else rgb(115, 195, 255),
				Enum.Material.Neon,
				CFrame.Angles(math.pi / 2, 0, 0),
				0,
				math.pi * 2,
				18
			)
		end
		beam("ApexLightningBoltMain", backdrop + V(0, 92 * scale, -4), V(0, h - 6, backdrop.Z + 18), 3.0, rgb(215, 238, 255), Enum.Material.Neon)

	elseif corruptedFloor then
		-- Floors 31-35 build their own Apex landmarks and horizon (TowerSetPieces/CorruptedGrove).
	elseif biome == "corrupted_grove" then
		group("CorruptionDais", function()
			for step = 1, 3 do
				block("CorruptionAltarDais", V((82 - step * 14) * scale, 4.5, (44 - step * 6) * scale), backdrop + V(0, step * 4.5 - 2, 8), theme.TrimColor, Enum.Material.Cobblestone)
			end
		end)
		for _, s in { -1, 1 } do
			block("VineChokedMonolith", V(12 * scale, 48 * scale, 12 * scale), backdrop + V(s * 38 * scale, 24 * scale, 8), cliffColor, Enum.Material.Rock)
			tree(backdrop + V(s * 62 * scale, 0, -4), 1.45 * scale, true, false)
		end
		local ringCenter = backdrop + V(0, 48 * scale, 8)
		group("CorruptionCrescent", function()
			ring("SpikedCrescent", ringCenter, 28 * scale, 4.5 * scale, rgb(28, 18, 34), Enum.Material.Metal, nil, 0.15, math.pi * 1.85, 18)
			orb("CorruptionCore", ringCenter - V(0, 4 * scale, 0), V(18 * scale, 18 * scale, 18 * scale), rgb(255, 65, 195), Enum.Material.Neon, 0.05)
			for j = 1, 9 do
				local a = j * math.pi / 5
				local thornBase = ringCenter + V(math.cos(a) * 29 * scale, math.sin(a) * 29 * scale, 0)
				beam("CrescentSpike", thornBase, thornBase + V(math.cos(a) * 14 * scale, math.sin(a) * 14 * scale, 0), 2.5 * scale, rgb(24, 16, 28), Enum.Material.Metal)
			end
		end)

	elseif biome == "sunken_sanctuary" then
		group("SanctuarySpire", function()
			spire(backdrop + V(0, 12 * scale, -8), 80 * scale, 19 * scale, theme.TrimColor, accent, false)
			for rIdx = 1, 3 do
				ring("SpireCyanSigil", backdrop + V(0, (40 + rIdx * 16) * scale, 2), (15 - rIdx * 2) * scale, 1.3, accent, Enum.Material.Neon, nil, 0, math.pi * 2, 14)
			end
		end)
		local portalCenter = backdrop + V(0, 30 * scale, 14)
		group("LotusPortal", function()
			ring("GoldenLotusPortal", portalCenter, 22 * scale, 3.4 * scale, gold, Enum.Material.Metal, nil, 0, math.pi * 2, 18)
			orb("SanctuaryGoldenOrb", portalCenter, V(28 * scale, 28 * scale, 5 * scale), rgb(235, 210, 140), Enum.Material.SmoothPlastic, 0.35)
			for pIdx = 1, 8 do
				local a = pIdx * math.pi / 4
				local petalAt = portalCenter + V(math.cos(a) * 24 * scale, math.sin(a) * 24 * scale, 0)
				beam("LotusPetal", petalAt, petalAt + V(math.cos(a) * 9 * scale, math.sin(a) * 9 * scale, 0), 2.6 * scale, gold, Enum.Material.Metal)
			end
		end)
		for bIdx = -2, 2 do
			beam("OceanCausticSunbeam", V(bIdx * 52, h - 4, -d * 0.2 + bIdx * 25), V(bIdx * 42 + 18, 0, -d * 0.08 + bIdx * 25), 16, rgb(135, 245, 255), Enum.Material.SmoothPlastic, 0.90)
		end

	elseif biome == "astral_archives" then
		arch(backdrop + V(0, 0, 12), 48 * scale, 46 * scale, 12, gold, Enum.Material.Metal, 0)
		group("GalaxyPortal", function()
			orb("GalaxyPortal", backdrop + V(0, 36 * scale, 10), V(40 * scale, 58 * scale, 4), rgb(88, 118, 245), Enum.Material.SmoothPlastic, 0.35)
			orb("GalaxyPortalCore", backdrop + V(0, 36 * scale, 11), V(24 * scale, 38 * scale, 3), rgb(168, 115, 255), Enum.Material.SmoothPlastic, 0.45)
		end)
		local orreryCenter = backdrop + V(0, 90 * scale, 22)
		group("Orrery", function()
			for j = 1, 4 do
				ring("CelestialOrreryRing", orreryCenter, (19 + j * 8) * scale, 1.9 * scale, gold, Enum.Material.Metal, CFrame.Angles(0.35 * j, 0.55 * j, 0.2 * j), 0, math.pi * 2, 18)
				local pAng = j * 1.4
				orb("OrbitingPlanet", orreryCenter + V(math.cos(pAng) * (19 + j * 8) * scale, math.sin(pAng) * 8 * scale, math.sin(pAng) * (19 + j * 8) * scale), V(5.5 * scale, 5.5 * scale, 5.5 * scale), if j % 2 == 0 then accent else gold, Enum.Material.SmoothPlastic, 0.2)
			end
			orb("OrreryCentralSun", orreryCenter, V(15 * scale, 15 * scale, 15 * scale), rgb(240, 220, 140), Enum.Material.SmoothPlastic, 0.2)
		end)

	else
		group("ObsidianKeep", function()
			block("ObsidianCitadelKeep", V(72 * scale, 76 * scale, 30 * scale), backdrop + V(0, 38 * scale, -6), rgb(20, 16, 28), Enum.Material.Basalt)
			spire(backdrop + V(0, 58 * scale, -6), 56 * scale, 21 * scale, rgb(24, 18, 34), rgb(165, 95, 255), false)
		end)
		for _, s in { -1, 1 } do
			group("ChainedSpire", function()
				spire(backdrop + V(s * 36 * scale, 12 * scale, 0), 68 * scale, 16 * scale, rgb(24, 18, 34), accent, false)
				chain(backdrop + V(s * 36 * scale, 56 * scale, 0), V(s * (w * 0.36), 44 * scale, -d * 0.28), 2.4)
			end)
		end
		group("Throne", function()
			block("ObsidianThroneBack", V(28 * scale, 46 * scale, 8 * scale), backdrop + V(0, 23 * scale, 10), rgb(18, 14, 26), Enum.Material.Basalt)
			block("ObsidianThroneSeat", V(30 * scale, 5 * scale, 18 * scale), backdrop + V(0, 8 * scale, 16), gold, Enum.Material.Metal)
		end)
		local eclipseAt = backdrop + V(0, 98 * scale, 14)
		group("Eclipse", function()
			orb("EclipseCoronaHalo", eclipseAt, V(60 * scale, 60 * scale, 5 * scale), rgb(162, 95, 255), Enum.Material.SmoothPlastic, 0.45)
			orb("BlackEclipseSphere", eclipseAt + V(0, 0, 2), V(52 * scale, 52 * scale, 12 * scale), rgb(8, 6, 14), Enum.Material.SmoothPlastic)
			block("DescendingVioletBeam", V(5.0 * scale, 86 * scale, 5.0 * scale), backdrop + V(0, 50 * scale, 14), rgb(178, 108, 255), Enum.Material.SmoothPlastic, nil, 0.50)
		end)
	end

	-- =========================================================================
	-- 6. BIOME-SPECIFIC ENVIRONMENTAL CLUTTER & FOLIAGE SUITE (MAKES FLOORS FULL)
	-- =========================================================================
	local function foliageBush(at: Vector3, bScale: number, col1: Color3?, col2: Color3?)
		local leafA = col1 or rgb(48, 115, 52)
		local leafB = col2 or rgb(72, 140, 60)
		orb("FoliageBushMain", at + V(0, 2.2 * bScale, 0), V(7 * bScale, 4.5 * bScale, 7 * bScale), leafA, Enum.Material.Grass)
		orb("FoliageBushClusterB", at + V(2.2 * bScale, 1.8 * bScale, 1.2 * bScale), V(5 * bScale, 3.8 * bScale, 5 * bScale), leafB, Enum.Material.Grass)
		orb("FoliageBushClusterC", at + V(-1.8 * bScale, 1.5 * bScale, -1.8 * bScale), V(4.5 * bScale, 3.2 * bScale, 4.5 * bScale), leafA, Enum.Material.Grass)
		block("BushBaseRubble", V(3 * bScale, 1.4 * bScale, 2.6 * bScale), at + V(0.5 * bScale, 0.7 * bScale, -1 * bScale), theme.CliffColor, theme.CliffMaterial)
	end

	local function stoneRuinClutter(at: Vector3, rScale: number)
		block("BrokenMasonryBlockA", V(4.5 * rScale, 2.8 * rScale, 3.8 * rScale), at + V(0, 1.4 * rScale, 0), theme.TrimColor, theme.TrimMaterial)
		block("BrokenMasonryBlockB", V(3.2 * rScale, 2.2 * rScale, 2.8 * rScale), at + V(2.6 * rScale, 1.1 * rScale, 1.4 * rScale), theme.CliffColor, theme.CliffMaterial)
		cyl("FallenColumnDrum", at + V(-2.4 * rScale, 1.2 * rScale, -1.2 * rScale), 2.2 * rScale, 3.5 * rScale, theme.TrimColor, theme.TrimMaterial)
	end

	local function stoneUrnPlanter(at: Vector3, uScale: number)
		cyl("UrnBase", at + V(0, 1.0 * uScale, 0), 2.2 * uScale, 2.0 * uScale, theme.TrimColor, theme.TrimMaterial)
		orb("UrnBelly", at + V(0, 3.2 * uScale, 0), V(4.2 * uScale, 3.6 * uScale, 4.2 * uScale), theme.TrimColor, theme.TrimMaterial)
		cyl("UrnRim", at + V(0, 5.0 * uScale, 0), 2.6 * uScale, 1.0 * uScale, theme.AccentColor, theme.TrimMaterial)
		orb("UrnSpillingFoliage", at + V(0, 5.8 * uScale, 0), V(3.8 * uScale, 2.2 * uScale, 3.8 * uScale), rgb(62, 138, 68), Enum.Material.Grass)
	end

	local function mushroomClutter(at: Vector3, mScale: number, capCol: Color3, glowCol: Color3)
		for idxM = 1, 3 do
			local off = if idxM == 1 then V(0, 0, 0) elseif idxM == 2 then V(2.2 * mScale, 0, 1.4 * mScale) else V(-1.8 * mScale, 0, -1.2 * mScale)
			local sz = if idxM == 1 then 1.0 else (if idxM == 2 then 0.7 else 0.5)
			local hStem = 4.5 * mScale * sz
			local rCap = 3.2 * mScale * sz
			beam("SporeStalk", at + off, at + off + V(0, hStem, 0), 0.9 * mScale * sz, rgb(160, 155, 185), Enum.Material.SmoothPlastic)
			orb("SporeCap", at + off + V(0, hStem + 1.2 * mScale * sz, 0), V(rCap * 2, 2.4 * mScale * sz, rCap * 2), capCol, Enum.Material.SmoothPlastic)
			cyl("SporeRingGlow", at + off + V(0, hStem, 0), rCap * 0.75, 0.6 * mScale * sz, glowCol, Enum.Material.Neon, 0.2)
		end
		orb("SporeMushroomMound", at + V(0, 0.8 * mScale, 0), V(4.5 * mScale, 1.6 * mScale, 4.5 * mScale), theme.GroundColor, theme.GroundMaterial)
	end

	local function basaltDrift(at: Vector3, dScale: number)
		block("BasaltBoulderA", V(5.2 * dScale, 3.6 * dScale, 4.8 * dScale), at + V(0, 1.8 * dScale, 0), rgb(32, 26, 28), Enum.Material.Basalt)
		block("BasaltBoulderB", V(3.8 * dScale, 2.4 * dScale, 3.2 * dScale), at + V(2.8 * dScale, 1.2 * dScale, 1.6 * dScale), rgb(44, 34, 36), Enum.Material.Basalt)
		block("BasaltBoulderC", V(2.8 * dScale, 1.8 * dScale, 2.6 * dScale), at + V(-2.4 * dScale, 0.9 * dScale, -1.8 * dScale), rgb(28, 22, 24), Enum.Material.Basalt)
	end

	local function iceCrystalClutter(at: Vector3, cScale: number)
		for idxC = 1, 3 do
			local off = if idxC == 1 then V(0, 0, 0) elseif idxC == 2 then V(2.0 * cScale, 0, 1.2 * cScale) else V(-1.6 * cScale, 0, -1.0 * cScale)
			local sz = if idxC == 1 then 1.0 else (if idxC == 2 then 0.75 else 0.55)
			local cryH = 7.5 * cScale * sz
			local cryW = 2.2 * cScale * sz
			block("IceCrystalSpike", V(cryW, cryH, cryW), at + off + V(0, cryH / 2, 0), rgb(165, 225, 255), Enum.Material.Ice, nil, 0.15)
		end
		orb("SnowdriftMound", at + V(0, 0.8 * cScale, 0), V(6.5 * cScale, 1.8 * cScale, 5.5 * cScale), rgb(225, 238, 252), Enum.Material.Sand)
	end

	local function forgeScrapClutter(at: Vector3, fScale: number)
		block("ScrapIronIngotA", V(4.2 * fScale, 1.6 * fScale, 2.2 * fScale), at + V(0, 0.8 * fScale, 0), rgb(52, 48, 56), Enum.Material.Metal)
		block("ScrapIronIngotB", V(3.6 * fScale, 1.4 * fScale, 2.0 * fScale), at + V(0.8 * fScale, 2.2 * fScale, 0.4 * fScale), darkGold, Enum.Material.Metal)
		block("SlagHeapDebris", V(5.5 * fScale, 2.4 * fScale, 4.8 * fScale), at + V(-2.6 * fScale, 1.2 * fScale, 1.2 * fScale), rgb(36, 28, 30), Enum.Material.Basalt)
		ring("DiscardedCogRim", at + V(2.4 * fScale, 1.4 * fScale, -1.8 * fScale), 2.2 * fScale, 0.5 * fScale, rgb(68, 58, 62), Enum.Material.Metal, CFrame.Angles(0.3, 0.4, 0), 0, math.pi * 2, 8)
	end

	local function highlandCairnClutter(at: Vector3, cScale: number)
		cyl("CairnStone1", at + V(0, 0.8 * cScale, 0), 2.8 * cScale, 1.6 * cScale, theme.TrimColor, Enum.Material.Cobblestone)
		cyl("CairnStone2", at + V(0, 2.2 * cScale, 0), 2.1 * cScale, 1.4 * cScale, theme.TrimColor, Enum.Material.Cobblestone)
		cyl("CairnStone3", at + V(0, 3.4 * cScale, 0), 1.4 * cScale, 1.2 * cScale, theme.AccentColor, Enum.Material.Cobblestone)
		orb("StormgrassTuftA", at + V(2.4 * cScale, 1.0 * cScale, 1.2 * cScale), V(4.2 * cScale, 2.2 * cScale, 4.2 * cScale), rgb(78, 108, 72), Enum.Material.Grass)
		orb("StormgrassTuftB", at + V(-2.2 * cScale, 0.8 * cScale, -1.4 * cScale), V(3.6 * cScale, 1.8 * cScale, 3.6 * cScale), rgb(64, 88, 60), Enum.Material.Grass)
	end

	local function corruptedBriarClutter(at: Vector3, bScale: number)
		ring("BlightThornLoop", at + V(0, 2.6 * bScale, 0), 3.2 * bScale, 0.8 * bScale, rgb(28, 18, 32), Enum.Material.Wood, CFrame.Angles(0.4, 0.6, 0), 0, math.pi * 1.6, 8)
		orb("BlightSporePod", at + V(0, 1.8 * bScale, 0), V(3.6 * bScale, 2.6 * bScale, 3.6 * bScale), rgb(118, 32, 98), Enum.Material.SmoothPlastic, 0.1)
		orb("BlightPodCore", at + V(0, 2.0 * bScale, 0), V(1.8 * bScale, 1.8 * bScale, 1.8 * bScale), rgb(255, 65, 185), Enum.Material.Neon, 0.15)
		block("BlightRootRot", V(4.8 * bScale, 1.6 * bScale, 4.2 * bScale), at + V(1.4 * bScale, 0.8 * bScale, -1.2 * bScale), rgb(22, 16, 26), Enum.Material.Slate)
	end

	local function coralReefClutter(at: Vector3, cScale: number)
		for idxCr = 1, 4 do
			local a = idxCr * math.pi / 2
			local tip = at + V(math.cos(a) * 3.2 * cScale, 5.5 * cScale, math.sin(a) * 3.2 * cScale)
			beam("CoralBranch", at + V(0, 0.5 * cScale, 0), tip, 0.9 * cScale, if idxCr % 2 == 0 then rgb(52, 188, 204) else rgb(238, 142, 112), Enum.Material.SmoothPlastic)
			orb("CoralTipBulb", tip, V(1.8 * cScale, 1.8 * cScale, 1.8 * cScale), if idxCr % 2 == 0 then rgb(95, 235, 245) else rgb(255, 175, 135), Enum.Material.SmoothPlastic, 0.1)
		end
		orb("AnemoneMound", at + V(0, 1.2 * cScale, 0), V(5.5 * cScale, 2.4 * cScale, 5.5 * cScale), rgb(165, 198, 190), Enum.Material.Limestone)
	end

	local function tomeArchiveClutter(at: Vector3, tScale: number)
		block("TomeStackA", V(3.6 * tScale, 1.2 * tScale, 2.8 * tScale), at + V(0, 0.6 * tScale, 0), rgb(38, 48, 88), Enum.Material.SmoothPlastic)
		block("TomeStackB", V(3.2 * tScale, 1.0 * tScale, 2.5 * tScale), at + V(0.2 * tScale, 1.6 * tScale, 0.1 * tScale), rgb(155, 45, 45), Enum.Material.SmoothPlastic)
		block("TomeStackC", V(2.8 * tScale, 0.9 * tScale, 2.2 * tScale), at + V(-0.1 * tScale, 2.5 * tScale, 0.2 * tScale), gold, Enum.Material.Metal)
		cyl("ScrollHeap", at + V(2.4 * tScale, 0.6 * tScale, 1.2 * tScale), 0.8 * tScale, 3.2 * tScale, rgb(235, 225, 205), Enum.Material.SmoothPlastic)
	end

	local function voidSpireClutter(at: Vector3, vScale: number)
		block("ObsidianShardSpikeA", V(1.8 * vScale, 6.5 * vScale, 1.8 * vScale), at + V(0, 3.2 * vScale, 0), rgb(20, 16, 28), Enum.Material.Basalt)
		block("ObsidianShardSpikeB", V(1.4 * vScale, 4.5 * vScale, 1.4 * vScale), at + V(1.8 * vScale, 2.2 * vScale, 1.2 * vScale), rgb(28, 22, 38), Enum.Material.Basalt)
		orb("VoidCoreGlow", at + V(0, 4.2 * vScale, 0), V(1.6 * vScale, 1.6 * vScale, 1.6 * vScale), accent, Enum.Material.Neon, 0.15)
		block("VoidCryptPlinth", V(4.5 * vScale, 1.2 * vScale, 4.5 * vScale), at + V(0, 0.6 * vScale, 0), rgb(16, 12, 22), Enum.Material.Marble)
	end

	local function spawnBiomeClutter(at: Vector3, clScale: number, variantSeed: number)
		group("Clutter", function()
			if kitOn and biomeKit then
				local list = biomeKit.Clutter
				local name = list[variantSeed % #list + 1]
				-- Ashen urns are buried terracotta.
				local o = if biome == "ashen_dunes" and name == "StoneUrn" then { TRIM = { Color = rgb(175, 95, 65), Material = Enum.Material.Slate } } else nil
				kitAt(name, CFrame.new(at) * CFrame.Angles(0, yawAt(at), 0), clScale, o)
			elseif biome == "verdant_ruins" then
				if variantSeed % 3 == 0 then
					foliageBush(at, clScale)
				elseif variantSeed % 3 == 1 then
					stoneRuinClutter(at, clScale)
				else
					stoneUrnPlanter(at, clScale)
				end
			elseif biome == "fungal_hollow" then
				mushroomClutter(at, clScale, rgb(85, 58, 168), accent)
			elseif biome == "ashen_dunes" then
				if variantSeed % 2 == 0 then
					basaltDrift(at, clScale)
				else
					block("BuriedTerracottaUrn", V(3.5 * clScale, 4.2 * clScale, 3.5 * clScale), at + V(0, 1.8 * clScale, 0), rgb(175, 95, 65), Enum.Material.Slate)
				end
			elseif biome == "frozen_citadel" then
				iceCrystalClutter(at, clScale)
			elseif biome == "infernal_foundry" then
				forgeScrapClutter(at, clScale)
			elseif biome == "thunder_highlands" then
				highlandCairnClutter(at, clScale)
			elseif biome == "corrupted_grove" then
				corruptedBriarClutter(at, clScale)
			elseif biome == "sunken_sanctuary" then
				coralReefClutter(at, clScale)
			elseif biome == "astral_archives" then
				tomeArchiveClutter(at, clScale)
			else
				voidSpireClutter(at, clScale)
			end
		end)
	end

	if not natural then
	-- 1. Lateral clutter beds across the wide Basin terrace (flanking the central causeway)
	for _, s in { -1, 1 } do
		for k = 1, 6 do
			local frac = (k - 0.5) / 6
			local cz = basin.Z - basin.Depth * 0.38 + frac * (basin.Depth * 0.76)
			-- Inner curb line flanking the walkway
			-- Outside the 40-stud causeway lane (clutter reaches about 5 studs from its centre).
			local cxInner = s * (28 + (k % 2) * 6)
			spawnBiomeClutter(V(cxInner, basin.Y, cz), 0.95 * scale, k)

			-- Mid terrace clutter islands filling open spaces
			local cxMid = s * (basin.Width * 0.28 + ((k * 7) % 18))
			spawnBiomeClutter(V(cxMid, basin.Y, cz), 1.15 * scale, k + 1)
		end
	end

	-- 3. Gallery Terraces Outer Corner Clutter
	for _, gal in { layout.Platforms.WestGallery, layout.Platforms.EastGallery } do
		if gal then
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local cornerAt = V(gal.X + sx * (gal.Width * 0.36), gal.Y, gal.Z + sz * (gal.Depth * 0.36))
					spawnBiomeClutter(cornerAt, 1.05 * scale, sx + sz)
				end
			end
		end
	end

	-- 4. Sanctuary Safe Zone Entrance Gateway Framing
	for _, s in { -1, 1 } do
		-- Beside the pillars, outside the 36-stud Sanctuary exit lane.
		local gatePos1 = V(s * 30, safe.Y, safe.Z - 18)
		spawnBiomeClutter(gatePos1, 1.15 * scale, s)
		local gatePos2 = V(s * 35, safe.Y, safe.Z - 8)
		spawnBiomeClutter(gatePos2, 0.95 * scale, s + 1)
	end

	end -- not natural (clutter beds)

	-- =========================================================================
	-- 7. NATURAL FLOORS: AN ECOSYSTEM SCATTERED OVER THE TERRAIN
	-- =========================================================================
	-- Groves on open ground (a centrepiece, smaller companions, understory around them), trees climbing the
	-- mountain slopes, boulders, rock outcrops half sunk in the slopes and a few monoliths, from the biome's
	-- Ecology (TowerBiomeKit). Spots come from the terrain field (ground kind and slope), keep apart from
	-- each other (Poisson-style), stay out of every camp and walkway lane, and are seeded by the floor id,
	-- so every floor grows its own landscape the same way each time it is built.
	if natural and field and biomeKit then
		local eco = Kit.Ecology[biome]
		local floorId = (parent:GetAttribute("FloorId") :: number?) or index
		local rand = Random.new(floorId * 7919 + 13)
		local placed: { { number } } = table.clone(reservedSpots)
		local function radiusOf(name: string, s: number): number
			local t = Kit.Templates[name] or Kit.ExtraTemplates[name]
			return if t then math.max(t.Size.X, t.Size.Z) * 0.5 * s * (Kit.RefScale[name] or 1) * 0.6 else 4
		end
		-- r keeps props apart; laneR (default r) keeps them off walkways: a tree's canopy may overhang a path
		-- high above heads, so trees only keep their trunk clear.
		local function free(x: number, z: number, r: number, laneR: number?): boolean
			for _, p in placed do
				local dx, dz = p[1] - x, p[2] - z
				if dx * dx + dz * dz < (p[3] + r) ^ 2 then
					return false
				end
			end
			for _, camp in layout.Camps do
				local dx, dz = camp.X - x, camp.Z - z
				if dx * dx + dz * dz < (38 + r) ^ 2 then
					return false
				end
			end
			local lr = laneR or r
			return footprintClear(x, z, lr, lr)
		end
		local function open(kind: string, slope: number): boolean
			return (kind == "CHASM" or kind == "MOUNTAIN" or kind == "LAWN") and slope < 0.6
		end
		-- Counts scale with the floor's size (a floor 5 room holds over twice a floor 1 room's ground).
		local density = w * d / (380 * 420)
		-- The ground at a spot: the terrain, or the top of a big terrace (its open lawn; never the Sanctuary,
		-- a bend terrace or a ramp).
		local function ground(x: number, z: number): (number, string, number)
			local y, kind = field.Sample(x, z)
			if kind == "WALK" or kind == "TRAIL" then
				for id, t in layout.Platforms do
					if math.abs(x - t.X) < t.Width / 2 - 4 and math.abs(z - t.Z) < t.Depth / 2 - 4 then
						local lawn = id ~= "Sanctuary" and not t.Bend and t.Width >= 60
						return t.Y, if lawn then "LAWN" else "WALK", 0
					end
				end
			end
			return y, kind, field.Slope(x, z)
		end
		local isVarrash = layout.PathStyle == "VARRASH"
		local function search(r: number, accept: (string, number, number) -> boolean, near: Vector3?, spread: number?, laneR: number?, allowSteep: boolean?): (number?, number, number)
			for _ = 1, 36 do
				local x, z
				if near then
					local a, dist = rand:NextNumber(0, math.pi * 2), rand:NextNumber(0.35, 1) * (spread or 20)
					x, z = near.X + math.cos(a) * dist, near.Z + math.sin(a) * dist
				else
					x, z = rand:NextNumber(-w / 2 + 14, w / 2 - 14), rand:NextNumber(-d / 2 + 14, d / 2 - 14)
				end
				if math.abs(x) < w / 2 - 6 and math.abs(z) < d / 2 - 6 then
					local y, kind, slope = ground(x, z)
					local edgeOk = true
					if isVarrash and not allowSteep then
						local span = math.max(r * 1.35, 8)
						for _, ox in { -span, 0, span } do
							for _, oz in { -span, 0, span } do
								if ox ~= 0 or oz ~= 0 then
									local ey = (ground(x + ox, z + oz))
									if math.abs(y - ey) > 1.3 then
										edgeOk = false
										break
									end
								end
							end
							if not edgeOk then break end
						end
					end
					if edgeOk and accept(kind, slope, y) and free(x, z, r, laneR) then
						return x, y, z
					end
				end
			end
			return nil, 0, 0
		end
		local rotEcoMix = { CAP = { Color = rgb(142, 198, 62) }, GLOW = { Color = rgb(162, 88, 245), Material = Enum.Material.Neon }, BULB = { Color = rgb(188, 118, 255), Material = Enum.Material.Neon } }
		local heartEcoMix = { CAP = { Color = rgb(148, 48, 198) }, GLOW = { Color = rgb(206, 104, 255), Material = Enum.Material.Neon }, BULB = { Color = rgb(120, 248, 255), Material = Enum.Material.Neon }, STEM = { Color = rgb(222, 212, 242) } }
		local ecoPlacedIdx = 0
		local function put(propKind: string, name: string, x: number, y: number, z: number, s: number, r: number, sink: number?)
			table.insert(placed, { x, z, r })
			ecoPlacedIdx += 1
			local isScatterFungi = name == "GiantMushroom" or name == "MushroomCluster" or name == "GlowcapTuftA" or name == "GlowcapTuftB"
			local o = if layout.Authored == "fungal:9" and ecoPlacedIdx % 2 == 1 and isScatterFungi
				then rotEcoMix
				elseif layout.Authored == "fungal:10" and ecoPlacedIdx % 2 == 1 and isScatterFungi
				then heartEcoMix
				else nil
			group(propKind, function()
				-- Placed on the terrain's own surface: the settle pass leaves it alone (TowerPropClearance).
				currentParent:SetAttribute("OnTerrain", true)
				local tilt = CFrame.Angles(rand:NextNumber(-0.05, 0.05), rand:NextNumber(0, math.pi * 2), rand:NextNumber(-0.05, 0.05))
				kitAt(name, CFrame.new(x, y - (sink or 0.4), z) * tilt, s, o)
			end)
		end
		local function pick(list: { string }): string
			return list[rand:NextInteger(1, #list)]
		end
		-- Groves (skipped on Floor 17 barracks, Floor 18 bare-tree glacier, Floor 19 siege fortress, and Floor 20 throne hall)
		-- An authored floor can thin its groves (Floor 6: one giant, the Elder Cap, not a forest of them).
		local td = layout.Terrain or {}
		local groveScale = td.GroveScale or 1
		local groveCount = if layout.Authored == "frozen:2" or layout.Authored == "frozen:3" or layout.Authored == "frozen:4" or layout.Authored == "frozen:5" or layout.Authored == "infernal:1" or layout.Authored == "infernal:2" or layout.Authored == "infernal:3" or layout.Authored == "infernal:4" or layout.Authored == "infernal:5" then 0 else math.round(eco.Groves * 1.5 * density * groveScale)
		for _ = 1, groveCount do
			local name = pick(eco.Trees)
			local s = rand:NextNumber(eco.TreeScale[1], eco.TreeScale[2])
			local r = radiusOf(name, s)
			local x, y, z = search(r, function(kind, slope) return open(kind, slope) end, nil, nil, r * 0.35)
			if not x then continue end
			put("Grove", name, x, y, z, s, r, if isVarrash then 1.4 else nil)
			local centre = V(x, y, z)
			for _ = 1, rand:NextInteger(1, eco.Companions + 1) do
				local cs = s * rand:NextNumber(0.5, 0.8)
				local cr = radiusOf(name, cs)
				local cx, cy, cz = search(cr, function(kind, slope) return open(kind, slope) end, centre, r * 2.6, cr * 0.35)
				if cx then put("Grove", name, cx, cy, cz, cs, cr, if isVarrash then 1.4 else nil) end
			end
			for _ = 1, eco.UnderPerGrove do
				local under = pick(eco.Understory)
				local us = rand:NextNumber(0.8, 1.35)
				local ur = radiusOf(under, us)
				local ux, uy, uz = search(ur, function(kind, slope)
					return kind ~= "WALK" and kind ~= "BRIDGE" and kind ~= "TRAIL" and kind ~= "POOL" and slope < 0.8
				end, centre, r * 2.2)
				if ux then put("Understory", under, ux, uy, uz, us, ur) end
			end
		end
		-- Meadow: small understory scattered loosely over open ground and terrace lawns (Floor 21: the yard's
		-- coal, scrap and clinker once its kit is imported).
		local understory = if (layout.Authored == "infernal:1" or layout.Authored == "infernal:2" or layout.Authored == "infernal:3" or layout.Authored == "infernal:4" or layout.Authored == "infernal:5") and KitProps.Has("CoalHeap") and KitProps.Has("ScrapHeap")
			then { "CoalHeap", "ScrapHeap", "ForgeScrap", "BoulderCluster" }
			else eco.Understory
		-- An authored floor can thin the meadow too (Floor 31: its own autumn and blight ground cover instead).
		for _ = 1, math.floor(w * d / 1800 * (td.MeadowScale or 1)) do
			local name = pick(understory)
			local ms = rand:NextNumber(0.6, 1.1)
			local mr = radiusOf(name, ms)
			local mx, my, mz = search(mr, function(kind, slope)
				return (kind == "CHASM" or kind == "LAWN" or kind == "MOUNTAIN") and slope < 0.6
			end)
			if mx then put("Meadow", name, mx, my, mz, ms, mr, 0.3) end
		end
		-- Plateau rims: understory and boulders just inside each terrace's edge (never on a walkway or in a camp).
		for id, t in layout.Platforms do
			if id == "Sanctuary" then continue end
			for _ = 1, math.floor((t.Width + t.Depth) / 40) do
				local side = rand:NextInteger(1, 4)
				local along = rand:NextNumber(-0.45, 0.45)
				local inset = if isVarrash then 10 else 5
				local x = if side <= 2 then t.X + along * t.Width else t.X + (if side == 3 then -1 else 1) * (t.Width / 2 - inset)
				local z = if side <= 2 then t.Z + (if side == 1 then -1 else 1) * (t.Depth / 2 - inset) else t.Z + along * t.Depth
				local name = if rand:NextNumber() < 0.7 then pick(eco.Understory) else "BoulderCluster"
				local us = rand:NextNumber(0.8, 1.3)
				local ur = radiusOf(name, us)
				if free(x, z, ur) then put("TerraceEdge", name, x, t.Y, z, us, ur, if isVarrash then 1.1 else 0.2) end
			end
		end
		-- Trees climbing the mountain slopes (skipped on Floors 18-20)
		local slopeTreeCount = if layout.Authored == "frozen:3" or layout.Authored == "frozen:4" or layout.Authored == "frozen:5" then 0 else math.round(eco.SlopeForestCount * 1.5 * density)
		for _ = 1, slopeTreeCount do
			local name = pick(eco.SlopeForest)
			local s = rand:NextNumber(eco.TreeScale[1], eco.TreeScale[2]) * 0.85
			local r = radiusOf(name, s) * 0.7
			local x, y, z = search(r, function(kind, slope, y)
				return kind == "MOUNTAIN" and slope < 0.8 and y > field.Bottom + 6
			end)
			if x then
				put("SlopeTree", name, x, y, z, s, r, 1.2)
			end
		end
		-- Boulders
		for _ = 1, math.round(eco.Rocks * density) do
			local s = rand:NextNumber(0.9, 2.2)
			local r = radiusOf("BoulderCluster", s)
			local x, y, z = search(r, function(kind, slope)
				return kind ~= "WALK" and kind ~= "BRIDGE" and kind ~= "TRAIL" and kind ~= "POOL" and slope < 1.1
			end)
			if x then put("Boulders", "BoulderCluster", x, y, z, s, r, 0.6) end
		end
		-- Rock outcrops half sunk in the slopes
		for i = 1, math.round(eco.Outcrops * 1.5 * density) do
			local name = if i % 2 == 0 then "CliffRockA" else "CliffRockB"
			local s = rand:NextNumber(0.16, 0.32)
			local r = radiusOf(name, s) * 0.8
			local maxSlope = if isVarrash then 0.95 else 2.6
			local x, y, z = search(r, function(kind, slope)
				return (kind == "MOUNTAIN" or kind == "APRON") and slope > 0.45 and slope < maxSlope
			end, nil, nil, nil, true)
			if x then
				local sink = 2.5
				local skip = false
				if isVarrash then
					local span = math.max(r * 1.5, 8)
					local lowY = y
					for _, ox in { -span, 0, span } do
						for _, oz in { -span, 0, span } do
							lowY = math.min(lowY, (ground(x + ox, z + oz)))
						end
					end
					sink = math.max(2.5, (y - lowY) + 4.5)
					skip = (y - lowY) > 6
				end
				if not skip then
					put("Outcrop", name, x, y, z, s, r, sink)
				end
			end
		end
		-- Monoliths
		for _ = 1, eco.MonolithCount do
			local name = pick(eco.Monoliths)
			local s = rand:NextNumber(eco.MonolithScale[1], eco.MonolithScale[2])
			local r = radiusOf(name, s)
			local x, y, z = search(r, function(kind, slope) return kind == "CHASM" and slope < 0.3 end)
			if x then put("Monolith", name, x, y, z, s, r, 0.6) end
		end
		-- Ground cover (an authored floor's GroundCover templates, e.g. Fungal glowcap turf and spore-moss): the
		-- biome's "grass", dense and cheap, over open ground, terrace lawns, banks and island crowns. Small, so it
		-- keeps only its own radius from other props; never in a camp or on a walkway.
		local cover = td.GroundCover
		if cover and #cover > 0 and Kit.ExtraTemplates[cover[1]] and KitProps.Has(cover[1]) then
			local count = 0
			for _ = 1, td.GroundCoverCount or 0 do
				local name = pick(cover)
				local gs = rand:NextNumber(0.8, 1.5)
				local gr = radiusOf(name, gs) * 0.8
				local gx, gy, gz = search(gr, function(kind, slope)
					return (kind == "CHASM" or kind == "LAWN" or kind == "APRON" or kind == "ISLAND" or kind == "MOUNTAIN") and slope < 0.9
				end)
				if gx then
					put("GroundCover", name, gx, gy, gz, gs, gr, 0.15)
					count += 1
				end
			end
			kit:SetAttribute("GroundCoverProps", count)
		end
		-- Veins on the cliffs (an authored floor's CliffVeins): the Veinweb's nerves laid against the steep
		-- mountain faces, leaning back with the slope and facing down it, into the room.
		if (td.CliffVeins or 0) > 0 and KitProps.Has("MyceliumVein") then
			local veins = 0
			for _ = 1, td.CliffVeins * 3 do
				if veins >= td.CliffVeins then break end
				local vs = rand:NextNumber(0.7, 1.3)
				local vr = 9 * vs
				local vx, vy, vz = search(vr, function(kind, slope, y)
					return kind == "MOUNTAIN" and slope > 0.9 and slope < 4 and y > field.Bottom + 4 and y < h - 40
				end)
				if vx then
					local gx = field.Height(vx + 2, vz) - field.Height(vx - 2, vz)
					local gz = field.Height(vx, vz + 2) - field.Height(vx, vz - 2)
					local down = V(-gx, 0, -gz)
					if down.Magnitude > 1e-3 then
						down = down.Unit
						local lean = math.atan(1 / math.max(V(gx, 0, gz).Magnitude / 4, 0.2))
						table.insert(placed, { vx, vz, vr })
						veins += 1
						group("CliffVein", function()
							currentParent:SetAttribute("OnTerrain", true)
							local at = V(vx, vy - 3, vz) - down * 0.8
							kitAt("MyceliumVein", CFrame.lookAt(at, at - down) * CFrame.Angles(-lean, 0, 0), vs)
						end)
					end
				end
			end
			kit:SetAttribute("CliffVeinProps", veins)
		end
		kit:SetAttribute("EcosystemProps", #placed)
	end

	-- Kit rock over the cliff, ledge and island boxes (after every caller has set its final CFrame). Each box
	-- stays as the invisible collider and support; the rock takes its colour and material from the box.
	local roomCentre = origin + V(0, 0, 0)
	local dressed = 0
	for _, p in pendingDress do
		if p.Parent then
			local names = kitDress[p.Name]
			if names then
				dressed += KitProps.DressBox(p, names, resolveRole, roomCentre + V(0, p.Position.Y - origin.Y, 0), { STONE = { Color = p.Color, Material = p.Material } })
			end
		end
	end
	kit:SetAttribute("KitRocks", dressed)

	-- Keep every enemy camp completely clear of props (removed whole, see TowerPropClearance).
	kit:SetAttribute("PropsClearedForCamps", PropClearance.Apply(kit, Assets.CampHitTest(origin, layout)))

	kit.Parent = parent
end

return Assets
