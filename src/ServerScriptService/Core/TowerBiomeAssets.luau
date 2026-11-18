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
local Assets = {}
local V = Vector3.new
local rgb = Color3.fromRGB
local gold = rgb(218, 178, 88)
local darkGold = rgb(168, 132, 58)

local CampExemptKinds = { RampArch = true, GlassArchSpan = true }

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
	Ring = true, Chain = true, Cogwheel = true, Orrery = true, Eclipse = true, CavernSkylight = true,
	GalaxyPortal = true, LotusPortal = true, CorruptionCrescent = true, AirborneVineCable = true,
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
	local resolveRole = KitProps.Resolver(biome, theme)
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
		-- Structural scenery participates in both physics and navigation probes.
  local solid = name:find("Cliff") or name:find("Wall") or name:find("Island")
   or name:find("Crag") or name:find("Bastion") or name:find("Massif")
   or name:find("HorizonPeak") or name:find("HorizonFoothill") or name:find("SkyPeak")
   or name:find("ArchPier") or name:find("Monolith") or name:find("Obelisk")
   or name:find("TempleTier") or name:find("CitadelKeep") or name:find("AltarDais")
   or name:find("Throne") or name == "SpirePlinth" or name == "SpireShaft"
   or name == "SpireUpperTier" or name == "LibraryPilaster"
  p.CanCollide = solid ~= nil
  p.CanTouch = false
  p.CanQuery = p.CanCollide
  p:SetAttribute("SolidScenery", p.CanCollide)
		p.CastShadow = false
		p.Color = color or theme.TrimColor
		p.Material = material or theme.TrimMaterial
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if shape then p.Shape = shape end
		if trans then p.Transparency = trans end
		-- Bloom safeguard for liquid blocks: liquid surfaces (water, lava, falls, pools, rivers, mist)
		-- must NEVER have Neon material so bloom does NOT trigger on liquid blocks.
		local isLiquid = name:find("Liquid") or name:find("Water") or name:find("Fall")
			or name:find("Lava") or name:find("Sea") or name:find("Pool") or name:find("Cascade")
			or name:find("River") or name:find("Stream") or name:find("CrucibleLava")
			or name:find("Shoal") or name:find("BubbleGlow") or name:find("CraterMagma")
		if isLiquid then
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
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
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
		if kitOn then
			group("Mushroom", function()
				kitAt("GiantMushroom", CFrame.new(at) * CFrame.Angles(0, yawAt(at), 0), mScale, if corrupted
					then { CAP = { Color = rgb(138, 36, 118) }, GLOW = { Color = rgb(235, 75, 185) } }
					else { CAP = { Color = rgb(68, 48, 168) }, GLOW = { Color = rgb(95, 245, 235) } })
			end)
			return
		end
		group("Mushroom", function()
			local stemH = 30 * mScale
			local capR = 24 * mScale
			local capColor = if corrupted then rgb(138, 36, 118) else rgb(68, 48, 168)
			local spotColor = if corrupted then rgb(255, 95, 195) else rgb(115, 225, 255)
			local gillColor = if corrupted then rgb(235, 75, 185) else rgb(95, 245, 235)
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

	if biome == "corrupted_grove" then
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
	end

	-- =========================================================================
	-- 5. MONUMENTAL NORTH APEX CITADEL / TEMPLE / PORTAL & OVERHEAD SKY SPECTACLE
	-- =========================================================================
	local backdrop = V(apex.X, apex.Y, -d / 2 + 24)

	-- Rock shelf behind the Apex terrace, level with it, so the citadel, temple and throne backdrops
	-- stand on ground instead of hanging over the chasm.
	local apexBack = apex.Z - apex.Depth / 2
	local shelfDepth = apexBack + d / 2
	if shelfDepth > 1 then
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
	else
		for _, s in { -1, 1 } do
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

	elseif biome == "fungal_hollow" then
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
			local t = Kit.Templates[name]
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
		local function put(propKind: string, name: string, x: number, y: number, z: number, s: number, r: number, sink: number?)
			table.insert(placed, { x, z, r })
			group(propKind, function()
				-- Placed on the terrain's own surface: the settle pass leaves it alone (TowerPropClearance).
				currentParent:SetAttribute("OnTerrain", true)
				local tilt = CFrame.Angles(rand:NextNumber(-0.05, 0.05), rand:NextNumber(0, math.pi * 2), rand:NextNumber(-0.05, 0.05))
				kitAt(name, CFrame.new(x, y - (sink or 0.4), z) * tilt, s)
			end)
		end
		local function pick(list: { string }): string
			return list[rand:NextInteger(1, #list)]
		end
		-- Groves
		for _ = 1, math.round(eco.Groves * 1.5 * density) do
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
		-- Meadow: small understory scattered loosely over open ground and terrace lawns.
		for _ = 1, math.floor(w * d / 1800) do
			local name = pick(eco.Understory)
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
		-- Trees climbing the mountain slopes
		for _ = 1, math.round(eco.SlopeForestCount * 1.5 * density) do
			local name = pick(eco.SlopeForest)
			local s = rand:NextNumber(eco.TreeScale[1], eco.TreeScale[2]) * 0.85
			local r = radiusOf(name, s) * 0.7
			local x, y, z = search(r, function(kind, slope, y)
				return kind == "MOUNTAIN" and slope < 0.8 and y > field.Bottom + 6
			end)
			if x then put("SlopeTree", name, x, y, z, s, r, 1.2) end
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
				if isVarrash then
					local span = math.max(r * 1.5, 8)
					local lowY = y
					for _, ox in { -span, 0, span } do
						for _, oz in { -span, 0, span } do
							lowY = math.min(lowY, (ground(x + ox, z + oz)))
						end
					end
					sink = math.max(2.5, (y - lowY) + 4.5)
				end
				put("Outcrop", name, x, y, z, s, r, sink)
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
