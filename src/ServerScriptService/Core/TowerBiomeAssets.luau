--!strict
-- Reference-guided, high-detail procedural environment & architectural kits for all 10 biomes.
-- Every decorative part has CanCollide=false, CanQuery=false, CanTouch=false so it never
-- obstructs HeroNavigation raycasts, pathfinding, or grounded mob spawn checks.
local Assets = {}
local V = Vector3.new
local rgb = Color3.fromRGB
local gold = rgb(218, 178, 88)
local darkGold = rgb(168, 132, 58)

function Assets.Build(parent: Instance, origin: Vector3, biome: string, index: number, layout: any, theme: any)
	local kit = Instance.new("Model")
	kit.Name = "BiomeAssets"
	kit:SetAttribute("BiomeId", biome)
	kit:SetAttribute("Variant", index)

	local w, d, h = layout.Width, layout.Depth, layout.Height
	local bottom = layout.Bottom
	local scale = 0.85 + index * 0.09
	local accent = theme.LightColor
	local cliffColor = theme.CliffColor or theme.WallColor
	local cliffMat = theme.CliffMaterial or Enum.Material.Rock
	local liquidColor = theme.LiquidColor or accent

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
		-- Bloom control: large Neon surfaces (sunbeams, portals, auroras, lava sheets) blow out the
		-- screen, so render them as translucent plastic; small Neon accents are dimmed slightly.
		if p.Material == Enum.Material.Neon then
			local largest = math.max(size.X, size.Y, size.Z)
			if largest > 10 then
				p.Material = Enum.Material.SmoothPlastic
				p.Transparency = math.max(p.Transparency, 0.4)
			else
				p.Color = p.Color:Lerp(Color3.new(0, 0, 0), 0.3)
			end
		end
		p.Parent = kit
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
		p.Parent = kit
		return p
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
		local cf = CFrame.new(at) * (tilt or CFrame.identity)
		local sAng, eAng = startAngle or 0, endAngle or math.pi * 2
		local segments = segCount or (if name == "IronChainLink" then 6 else 18)
		for i = 0, segments - 1 do
			local a = sAng + (eAng - sAng) * i / segments
			local b = sAng + (eAng - sAng) * (i + 1) / segments
			beam(
				name,
				cf:PointToWorldSpace(V(math.cos(a) * radius, math.sin(a) * radius, 0)),
				cf:PointToWorldSpace(V(math.cos(b) * radius, math.sin(b) * radius, 0)),
				thickness,
				color,
				mat or Enum.Material.Metal
			)
		end
	end

	local function arch(at: Vector3, span: number, pierH: number, depthSize: number, color: Color3?, mat: Enum.Material?, rotY: number?)
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
	end

	local function waterfall(at: Vector3, fallWidth: number, fallHeight: number, color: Color3, rotY: number?)
		local cf = CFrame.new(at) * CFrame.Angles(0, rotY or 0, 0)
		local main = block("CascadingFall", V(fallWidth, fallHeight, 2.4), V(0, 0, 0), color, Enum.Material.SmoothPlastic, nil, 0.45)
		main.CFrame = CFrame.new(origin) * cf * CFrame.new(0, fallHeight / 2, 0)
		local core = block("FallFoamCore", V(fallWidth * 0.5, fallHeight, 1.4), V(0, 0, 0), rgb(215, 230, 240), Enum.Material.SmoothPlastic, nil, 0.65)
		core.CFrame = CFrame.new(origin) * cf * CFrame.new(0, fallHeight / 2, 0.6)
		local mist = orb("FallSplashMist", cf:PointToWorldSpace(V(0, 2, 1.5)), V(fallWidth * 0.85, 3.5, 4.5), rgb(210, 230, 245), Enum.Material.SmoothPlastic, 0.88)
		pointLight(mist, color, 0.15, 14)
	end

	local function spire(at: Vector3, height: number, widthBase: number, color: Color3, glow: Color3, isCrystal: boolean?)
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
	end

	local function mushroom(at: Vector3, mScale: number, corrupted: boolean)
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
	end

	local function tree(at: Vector3, tScale: number, corrupted: boolean, dead: boolean)
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
	end

	local function statue(at: Vector3, sScale: number, kind: string, faceSignX: number?)
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
	end

	local function libraryWing(at: Vector3, wingWidth: number, wingHeight: number, rotY: number)
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
	end

	local function cogwheel(at: Vector3, radius: number, tilt: CFrame?)
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
	end

	local function chain(a: Vector3, b: Vector3, linkRadius: number?)
		local r = linkRadius or 2.2
		local steps = 14
		for k = 0, steps do
			local at = a:Lerp(b, k / steps)
			ring("IronChainLink", at, r, 1.1, rgb(64, 66, 76), Enum.Material.Metal, CFrame.Angles(0, if k % 2 == 0 then 0 else math.pi / 2, 0), 0, math.pi * 2, 6)
		end
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
			local fissure1 = block("CragMagmaFissureFront", V(1.6 * lScale, 34 * lScale, 1.2), V(0, 0, 0), rgb(255, 115, 28), Enum.Material.Neon)
			fissure1.CFrame = crag.CFrame * CFrame.new(0, 2 * lScale, 9.1 * lScale)
			local fissure2 = block("CragMagmaFissureSide", V(1.2, 32 * lScale, 1.6 * lScale), V(0, 0, 0), rgb(255, 135, 38), Enum.Material.Neon)
			fissure2.CFrame = crag.CFrame * CFrame.new(-signX * 8.1 * lScale, 2 * lScale, 0)
			spire(at + V(-signX * 10 * lScale, 0, 8 * lScale), 32 * lScale, 8.5 * lScale, theme.TrimColor, rgb(255, 125, 35), false)
			if variantSeed % 2 == 1 then
				arch(at + V(-signX * 8, 0, 12), 24 * lScale, 20 * lScale, 6.5, theme.TrimColor, Enum.Material.Sandstone, 0.3 * signX)
			else
				tree(at + V(signX * 8, 0, -8), 0.75 * lScale, false, true)
			end
		elseif biome == "frozen_citadel" then
			spire(at, 44 * lScale, 11 * lScale, rgb(135, 210, 248), accent, true)
			spire(at + V(-signX * 10, -2, 9), 28 * lScale, 7.5 * lScale, rgb(155, 225, 255), accent, true)
		elseif biome == "infernal_foundry" then
			spire(at, 46 * lScale, 13 * lScale, rgb(40, 30, 32), rgb(255, 108, 28), false)
			arch(at + V(-signX * 10, 0, 0), 24 * lScale, 22 * lScale, 7.5, theme.TrimColor, Enum.Material.Metal, math.pi / 2)
		elseif biome == "thunder_highlands" then
			if variantSeed % 2 == 0 then
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

	if bottom < 0 then
		local basinSurface = block(
			"ElementalBasinSea",
			V(w - 12, 0.6, d - 12),
			V(0, bottom - 0.5, 0),
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
					orb("ValleyCloudBank", V(cx, bottom + 1, cz), V(52, 10, 48), rgb(232, 238, 252), Enum.Material.SmoothPlastic, 0.2)
				elseif isLava then
					block("BasaltSlagIsland", V(22, 2.5, 20), V(cx, bottom + 0.6, cz), cliffColor, Enum.Material.Basalt)
					orb("MoltenBubbleGlow", V(cx + s * 6, bottom + 0.3, cz - 4), V(8, 1.2, 8), rgb(255, 175, 55), Enum.Material.SmoothPlastic, 0.15)
				elseif isCosmic then
					orb("CosmicNebulaCloud", V(cx, bottom + 1, cz), V(48, 8, 44), rgb(88, 64, 175), Enum.Material.SmoothPlastic, 0.65)
				elseif isAbyss then
					orb("AbyssalTealMist", V(cx, bottom + 1, cz), V(48, 8, 44), rgb(52, 215, 228), Enum.Material.SmoothPlastic, 0.70)
					spire(V(cx, bottom - 1, cz), 18 + (k % 3) * 4, 6, cliffColor, accent, false)
				else
					cyl("SubmergedShoal", V(cx, bottom + 0.2, cz), 14, 1.2, theme.TrimColor, theme.GroundMaterial)
					orb("BioluminescentPoolFlora", V(cx, bottom + 1.2, cz), V(4, 3, 4), accent, Enum.Material.SmoothPlastic, 0.2)
				end
			end
		end
	end

	-- =========================================================================
	-- 2. FULL-HEIGHT 360° PERIMETER CLIFF RANGES, CORNER MASSIFS & NORTH HORIZON
	-- =========================================================================
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
			block("NorthHorizonPeak", V(w * 0.13, peakH, 38), V(nx, bottom + peakH / 2, nz), cliffColor, cliffMat)
			block("NorthHorizonFoothill", V(w * 0.11, peakH * 0.56, 28), V(nx, bottom + peakH * 0.28, nz + 18), theme.GroundColor, theme.GroundMaterial)
			if math.abs(k) == 3 then
				waterfall(V(nx, bottom, nz + 30), 13, peakH * 0.54, liquidColor, 0)
			end
			populateLandmark(V(nx, bottom + peakH * 0.55, nz + 16), 0.9 * scale, math.abs(k), if k > 0 then 1 else -1)
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

			-- Full-height outer backdrop massif reaching ceiling (prevents flat wall plane exposure)
			block("PerimeterSkyPeak", V(28, upperH, d / sideCount + 18), V(xEdge + s * 4, bottom + upperH / 2, zPos), cliffColor, cliffMat)
			-- Stepped mid cliff & lower terrace ledge protruding into the room
			block("PerimeterCliffBase", V(38, lowerH, d / sideCount + 12), V(xEdge - s * 8, bottom + lowerH / 2, zPos), cliffColor, cliffMat)
			block("PerimeterCliffLedge", V(28, lowerH * 0.62, d / sideCount + 4), V(xEdge - s * 20, bottom + lowerH * 0.31, zPos + 4), theme.GroundColor, theme.GroundMaterial)
			wedge(
				"PerimeterCliffSlope",
				V(d / sideCount + 4, lowerH * 0.42, 20),
				CFrame.new(xEdge - s * 22, bottom + lowerH * 0.78, zPos) * CFrame.Angles(0, if s > 0 then -math.pi / 2 else math.pi / 2, 0),
				cliffColor,
				cliffMat
			)

			if k % 2 == 0 then
				waterfall(V(xEdge - s * 26, bottom, zPos), 12, lowerH * 0.62, liquidColor, if s > 0 then -math.pi / 2 else math.pi / 2)
			end

			local ridgeAt = V(xEdge - s * 16, bottom + lowerH * 0.62, zPos)
			local floorAt = V(xEdge - s * 32, bottom, zPos)
			populateLandmark(ridgeAt, 0.95 * scale, k, s)
			if k % 2 == 1 then
				populateLandmark(floorAt, 0.85 * scale, k + 1, s)
			end
		end
	end

	-- =========================================================================
	-- 3. INTERIOR CHASM ISLANDS & OVERHEAD BRIDGE ARCHES (FILLS MIDGROUND VIEW!)
	-- =========================================================================
	local safe = layout.Sanctuary
	local basin = layout.Platforms.Basin
	local westGal = layout.Platforms.WestGallery
	local crossing = layout.Platforms.Crossing
	local apex = layout.Platforms.Apex

	-- Overhead Monumental Archways / Canopies / Ribs spanning across the central spine ramps
	local ramp1Mid = V(0, (safe.Y + basin.Y) * 0.5, (safe.Z - safe.Depth * 0.5 + basin.Z + basin.Depth * 0.5) * 0.5)
	local ramp2Mid = V(0, (basin.Y + crossing.Y) * 0.5, (basin.Z - basin.Depth * 0.5 + crossing.Z + crossing.Depth * 0.5) * 0.5)
	local stairMid = V(0, (crossing.Y + apex.Y) * 0.5, (crossing.Z - crossing.Depth * 0.5 + apex.Z + apex.Depth * 0.5) * 0.5)

	arch(ramp1Mid + V(0, -2, 0), 42, 28 * scale, 8, theme.TrimColor, theme.TrimMaterial, 0)
	arch(ramp2Mid + V(0, -2, 0), 38, 30 * scale, 8, theme.TrimColor, theme.TrimMaterial, 0)
	arch(stairMid + V(0, -2, 0), 42, 34 * scale, 9, gold, theme.TrimMaterial, 0)

	if biome == "corrupted_grove" then
		for _, rPos in { ramp1Mid, ramp2Mid, stairMid } do
			ring("PathwayThornArch", rPos + V(0, 8, 0), 28 * scale, 3.2, rgb(24, 16, 28), Enum.Material.Wood, nil, 0.15, math.pi - 0.15, 12)
		end
	end

	-- 3 Pairs of Towering Interior Chasm Islands right between the Central Spine and Side Galleries
	local innerIslands = {
		{ X = 68, Z = (safe.Z + basin.Z) * 0.5 + 8, H = 18, Scale = 1.08 }, -- Foreground Chasm Island
		{ X = 64, Z = crossing.Z + 44, H = 22, Scale = 1.18 },              -- Lower Midground Chasm Island
		{ X = 62, Z = (crossing.Z + apex.Z) * 0.5, H = 28, Scale = 1.25 },  -- Upper Grand-Stair Chasm Island
	}

	for idxIsland, isl in innerIslands do
		for _, s in { -1, 1 } do
			local islPos = V(s * isl.X, bottom, isl.Z)
			local islH = isl.H * scale - bottom
			-- Stepped rocky/masonry island rising out of the chasm right beside the central path
			block("InteriorChasmIslandBase", V(32 * scale, islH, 34 * scale), islPos + V(0, islH / 2, 0), cliffColor, cliffMat)
			block("InteriorChasmIslandCrown", V(26 * scale, 4, 28 * scale), islPos + V(0, islH + 1, 0), theme.GroundColor, theme.GroundMaterial)
			waterfall(islPos + V(-s * 14 * scale, 0, 0), 8 * scale, islH, liquidColor, if s > 0 then -math.pi / 2 else math.pi / 2)
			populateLandmark(islPos + V(0, islH + 2, 0), isl.Scale * scale, idxIsland, s)
		end
	end

	-- Foreground & Midground Lantern / Brazier Colonnades, Basin Courtyard Gardens & Gallery Flanking Structures
	-- Central causeway runner & curbing across the wide Basin terrace
	block("BasinCentralCauseway", V(34, 0.14, basin.Depth - 4), V(0, basin.Y + 0.04, basin.Z), theme.TrimColor, theme.TrimMaterial)
	block("BasinCausewayInlay", V(20, 0.18, basin.Depth - 8), V(0, basin.Y + 0.06, basin.Z), theme.AccentColor, theme.GroundMaterial)

	for _, s in { -1, 1 } do
		-- Sunken elemental pools / magma trenches / cloud basins on the lateral margins of the Basin courtyard
		local poolPos = V(s * (basin.Width * 0.44), basin.Y + 0.06, basin.Z)
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

		-- Courtyard Landmarks at the lateral margins of the Basin terrace (framing the open courtyard)
		populateLandmark(V(s * (basin.Width * 0.44), basin.Y, basin.Z + basin.Depth * 0.32), 0.92 * scale, 1, s)
		populateLandmark(V(s * (basin.Width * 0.44), basin.Y, basin.Z - basin.Depth * 0.32), 1.08 * scale, 2, s)

		local lampPos = V(s * 22, basin.Y, basin.Z + basin.Depth * 0.44)
		block("ApproachLanternPost", V(3, 8, 3), lampPos + V(0, 4, 0), theme.TrimColor, theme.TrimMaterial)
		local flame = orb("ApproachLanternGlow", lampPos + V(0, 9.5, 0), V(2.6, 3.6, 2.6), if biome == "fungal_hollow" then rgb(255, 195, 95) elseif biome == "abyssal_throne" then rgb(175, 85, 255) else accent, Enum.Material.SmoothPlastic, 0.1)
		pointLight(flame, flame.Color, 0.45, 28)

		local galOuter = V(s * (math.abs(westGal.X) + westGal.Width * 0.5 + 14), westGal.Y, westGal.Z)
		arch(galOuter, 38 * scale, 28 * scale, 9, theme.TrimColor, theme.TrimMaterial, math.pi / 2)
		populateLandmark(galOuter + V(s * 8, 0, -24), 1.15 * scale, 1, s)
		populateLandmark(galOuter + V(s * 8, 0, 24), 1.1 * scale, 2, s)

		if biome == "fungal_hollow" then
			for v = 1, 4 do
				beam("MyceliumVein", V(s * math.abs(westGal.X), bottom + 1, westGal.Z - 25 + v * 12), V(s * (math.abs(westGal.X) - 28), westGal.Y, westGal.Z - 18 + v * 10), 0.8, accent, Enum.Material.Neon, 0.12)
			end
		elseif biome == "astral_archives" then
			local pedAt = V(s * (crossing.Width * 0.5 + 12), crossing.Y, crossing.Z + 12)
			block("GrimoireLectern", V(5, 6, 5), pedAt + V(0, 3, 0), theme.GroundColor, Enum.Material.Marble)
			block("OpenStarGrimoire", V(4.5, 0.8, 3.2), pedAt + V(0, 6.5, 0), gold, Enum.Material.Neon)
			ring("BrassArmillaryOuter", pedAt + V(0, 13, 0), 6.5, 0.65, gold, Enum.Material.Metal, CFrame.Angles(0.4, 0.3, 0), 0, math.pi * 2, 14)
			ring("BrassArmillaryInner", pedAt + V(0, 13, 0), 4.8, 0.55, gold, Enum.Material.Metal, CFrame.Angles(-0.5, 1.1, 0), 0, math.pi * 2, 12)
			orb("ArmillaryCore", pedAt + V(0, 13, 0), V(2.4, 2.4, 2.4), accent, Enum.Material.Neon)
		elseif biome == "abyssal_throne" then
			local obAt = V(s * (crossing.Width * 0.5 + 22), bottom, crossing.Z - 12)
			spire(obAt, 62 * scale, 14, rgb(22, 18, 30), accent, false)
			chain(obAt + V(0, 52 * scale, 0), V(s * 28, apex.Y + 28, apex.Z))
		end
	end

	-- =========================================================================
	-- 4. BIOME-SPECIFIC FOREGROUND / MIDGROUND ICONIC GUARDIANS & MONUMENTS
	-- =========================================================================
	if biome == "verdant_ruins" then
		-- Left foreground: Giant Ancient Carved Stone Deity Head nestled in banyan roots (from Verdant Ruins.png)
		local headPos = V(-basin.Width * 0.36, basin.Y, basin.Z - 6)
		orb("AncientCarvedHead", headPos + V(0, 17 * scale, 0), V(26 * scale, 34 * scale, 24 * scale), theme.TrimColor, Enum.Material.Slate)
		cyl("CarvedHeaddressTier1", headPos + V(0, 31 * scale, 0), 12 * scale, 5 * scale, theme.AccentColor, Enum.Material.Cobblestone)
		cyl("CarvedHeaddressCrown", headPos + V(0, 36 * scale, 0), 7.5 * scale, 6.5 * scale, gold, Enum.Material.Cobblestone)
		block("CarvedNoseBridge", V(4.2 * scale, 11 * scale, 5.5 * scale), headPos + V(4.5 * scale, 17 * scale, 9.5 * scale), theme.TrimColor, Enum.Material.Slate)
		for _, s in { -1, 1 } do
			block("SereneEyeLid", V(5.8 * scale, 1.8 * scale, 3.2 * scale), headPos + V(5.5 * scale, 20 * scale, (2 + s * 4.8) * scale), cliffColor, Enum.Material.Slate)
		end
		tree(headPos + V(-14 * scale, 0, -10 * scale), 1.25 * scale, false, false)

		-- Right foreground: Seated Stone Lion Guardian on mossy plinth (from Verdant Ruins.png)
		statue(V(basin.Width * 0.36, basin.Y, basin.Z - 6), 1.3 * scale, "LionGuardian", 1)
		for _, s in { -1, 1 } do
			statue(V(s * (apex.Width * 0.5 + 18), apex.Y - 2, apex.Z + 18), 1.25 * scale, "LionGuardian", s)
		end

	elseif biome == "sunken_sanctuary" then
		-- Twin Colossal Flanking Statues: Robed Goddess with Staff (West) & Poseidon King with Trident (East)
		local statZ = westGal.Z - 18
		local statY = westGal.Y
		local statX = math.abs(westGal.X) - 12
		statue(V(-statX, statY, statZ), 1.45 * scale, "StaffGoddess", -1)
		statue(V(statX, statY, statZ), 1.45 * scale, "TridentKing", 1)

	elseif biome == "thunder_highlands" then
		-- West Ridge: Circular Stone Henge Portal Ring struck by vertical lightning (from Thunder Highlands.jpeg)
		local hengeAt = V(westGal.X - 10, westGal.Y, westGal.Z - 10)
		ring("StormHengeOuterRing", hengeAt + V(0, 26 * scale, 0), 21 * scale, 4.5 * scale, theme.TrimColor, Enum.Material.Rock, nil, 0, math.pi * 2, 16)
		ring("StormHengeInnerRing", hengeAt + V(0, 26 * scale, 0), 12 * scale, 2.6 * scale, accent, Enum.Material.Neon, nil, 0, math.pi * 2, 12)
		for _, s in { -1, 1 } do
			block("HengeMonolithPier", V(7.5 * scale, 28 * scale, 7.5 * scale), hengeAt + V(s * 14 * scale, 14 * scale, 0), theme.TrimColor, Enum.Material.Rock)
			block("HengeFlankingObelisk", V(6.5 * scale, 22 * scale, 6.5 * scale), hengeAt + V(s * 28 * scale, 11 * scale, 4), cliffColor, Enum.Material.Rock)
		end
		beam("HengeLightningStrike", hengeAt + V(0, 4 * scale, 0), hengeAt + V(4, h - 8, -6), 2.0, accent, Enum.Material.Neon)
	end

	-- =========================================================================
	-- 5. MONUMENTAL NORTH APEX CITADEL / TEMPLE / PORTAL & OVERHEAD SKY SPECTACLE
	-- =========================================================================
	local backdrop = V(0, apex.Y, -d / 2 + 24)

	for _, s in { -1, 1 } do
		local wingX = s * (apex.Width * 0.5 + 38)
		block("NorthCitadelWingCliff", V(68, 76 * scale, 44), backdrop + V(wingX, 28 * scale, 4), cliffColor, cliffMat)
		arch(backdrop + V(wingX, 12 * scale, 28), 36 * scale, 34 * scale, 10, theme.TrimColor, theme.TrimMaterial, 0)
		waterfall(backdrop + V(s * (apex.Width * 0.5 + 16), bottom - apex.Y, 20), 15 * scale, (apex.Y - bottom + 40 * scale), liquidColor, 0)
	end

	if biome == "verdant_ruins" then
		for step = 1, 5 do
			local tierW = (156 - step * 22) * scale
			local tierH = 13 * scale
			local tierY = (step - 0.5) * tierH
			block("GoldenTempleTier", V(tierW, tierH, 38 * scale), backdrop + V(0, tierY, -4), if step >= 4 then gold else theme.TrimColor, theme.TrimMaterial)
			block("TempleTierCornice", V(tierW + 6, 2.4, 41 * scale), backdrop + V(0, step * tierH, -4), gold, Enum.Material.Cobblestone)
		end
		spire(backdrop + V(0, 62 * scale, -4), 46 * scale, 18 * scale, gold, accent, false)
		for _, s in { -1, 1 } do
			spire(backdrop + V(s * 48 * scale, 36 * scale, 0), 36 * scale, 13 * scale, theme.TrimColor, accent, false)
		end
		arch(backdrop + V(0, 0, 18), 40 * scale, 34 * scale, 10, gold, Enum.Material.Cobblestone, 0)
		orb("SunlitTemplePortal", backdrop + V(0, 24 * scale, 16), V(28 * scale, 38 * scale, 3), rgb(225, 195, 115), Enum.Material.SmoothPlastic, 0.45)
		for bIdx = -2, 2 do
			beam("JungleSunbeam", V(bIdx * 55 - 35, h - 4, -d * 0.25 + bIdx * 30), V(bIdx * 45 + 25, 4, -d * 0.08 + bIdx * 35), 10, rgb(240, 220, 150), Enum.Material.SmoothPlastic, 0.92)
		end

	elseif biome == "fungal_hollow" then
		mushroom(backdrop + V(0, 0, -4), 2.25 * scale, false)
		for _, s in { -1, 1 } do
			mushroom(backdrop + V(s * 54 * scale, -4, 12), 1.55 * scale, false)
			arch(backdrop + V(s * 34 * scale, 0, 16), 28 * scale, 26 * scale, 8, theme.TrimColor, Enum.Material.Cobblestone, 0)
		end
		arch(backdrop + V(0, 0, 18), 44 * scale, 36 * scale, 10, theme.TrimColor, Enum.Material.Cobblestone, 0)
		cyl("CavernSkylightOpening", V(0, h - 2, -d * 0.12), 72 * scale, 2.5, rgb(125, 205, 235), Enum.Material.SmoothPlastic, 0.65)
		for rIdx = 1, 8 do
			local a = rIdx * math.pi / 4
			local rTop = V(math.cos(a) * 54 * scale, h - 3, -d * 0.12 + math.sin(a) * 54 * scale)
			beam("SkylightHangingRoot", rTop, rTop - V(math.cos(a) * 12, 46 * scale, math.sin(a) * 12), 2.6, rgb(48, 38, 34), Enum.Material.Wood)
		end

	elseif biome == "ashen_dunes" then
		for k = 1, 11 do
			local a = k * math.pi / 11
			local peakH = (38 + math.sin(a) * 60) * scale
			block("VolcanoCalderaSlope", V(25 * scale, peakH, 30 * scale), backdrop + V((k - 6) * 19 * scale, peakH / 2 - 4, -6), rgb(36, 26, 26), Enum.Material.Basalt)
		end
		orb("CalderaCraterMagma", backdrop + V(0, 66 * scale, -4), V(48 * scale, 18 * scale, 20 * scale), rgb(255, 112, 28), Enum.Material.Neon, 0.05)
		orb("VolcanicAshPlume1", backdrop + V(0, 86 * scale, -6), V(62 * scale, 28 * scale, 34 * scale), rgb(52, 38, 38), Enum.Material.Slate, 0.25)
		orb("VolcanicAshPlume2", backdrop + V(12, 106 * scale, -8), V(80 * scale, 30 * scale, 42 * scale), rgb(68, 44, 42), Enum.Material.Slate, 0.35)
		for _, s in { -1, 1 } do
			beam("CalderaLavaRiver", backdrop + V(s * 12 * scale, 62 * scale, 4), backdrop + V(s * 38 * scale, 2, 24), 5.0 * scale, rgb(255, 105, 24), Enum.Material.Neon)
		end

	elseif biome == "frozen_citadel" then
		block("CitadelKeepHall", V(102 * scale, 58 * scale, 36 * scale), backdrop + V(0, 29 * scale, -4), theme.CliffColor, Enum.Material.Brick)
		spire(backdrop + V(0, 52 * scale, -4), 52 * scale, 19 * scale, rgb(145, 218, 252), accent, true)
		for _, s in { -1, 1 } do
			spire(backdrop + V(s * 50 * scale, 0, 6), 68 * scale, 17 * scale, rgb(130, 205, 245), accent, true)
		end
		arch(backdrop + V(0, 0, 16), 40 * scale, 36 * scale, 10, theme.TrimColor, Enum.Material.Ice, 0)
		cyl("GlacialRoseWindow", backdrop + V(0, 44 * scale, 15), 15 * scale, 2.2, accent, Enum.Material.Neon, 0.18)
		for aIdx = -1, 1 do
			beam("AuroraBorealisRibbon", V(-w * 0.38, h - 14 - math.abs(aIdx) * 6, aIdx * 85), V(w * 0.38, h - 10, aIdx * 85 - 35), 8.5, if aIdx == 0 then rgb(95, 255, 195) else rgb(115, 220, 255), Enum.Material.Neon, 0.72)
		end

	elseif biome == "infernal_foundry" then
		for _, s in { -1, 1 } do
			spire(backdrop + V(s * 54 * scale, 0, 4), 72 * scale, 19 * scale, rgb(38, 28, 30), rgb(255, 108, 28), false)
			cogwheel(V(s * 78 * scale, h - 28, -d * 0.18), 30 * scale, CFrame.Angles(math.pi / 2, 0, 0))
			chain(V(s * 58 * scale, h - 8, -d * 0.24), backdrop + V(s * 24 * scale, 64 * scale, 2), 2.5)
		end
		cyl("SuspendedForgeRing", backdrop + V(0, 70 * scale, 2), 40 * scale, 11 * scale, theme.TrimColor, Enum.Material.Metal)
		cyl("MoltenCrucibleVat", backdrop + V(0, 54 * scale, 2), 24 * scale, 19 * scale, rgb(48, 36, 38), Enum.Material.Metal)
		block("CrucibleLavaCascade", V(15 * scale, 54 * scale, 9 * scale), backdrop + V(0, 26 * scale, 10), rgb(255, 118, 24), Enum.Material.Neon, nil, 0.05)
		orb("CrucibleSplashPool", backdrop + V(0, 2, 14), V(40 * scale, 5 * scale, 28 * scale), rgb(255, 145, 35), Enum.Material.Neon, 0.1)

	elseif biome == "thunder_highlands" then
		for k = 1, 7 do
			local mh = (40 + (4 - math.abs(k - 4)) * 16) * scale
			block("StormPeakCrag", V(28 * scale, mh, 30 * scale), backdrop + V((k - 4) * 20 * scale, mh / 2, -6), cliffColor, Enum.Material.Rock)
		end
		spire(backdrop + V(0, 30 * scale, -4), 72 * scale, 19 * scale, theme.TrimColor, accent, false)
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
		for step = 1, 3 do
			block("CorruptionAltarDais", V((82 - step * 14) * scale, 4.5, (44 - step * 6) * scale), backdrop + V(0, step * 4.5 - 2, 8), theme.TrimColor, Enum.Material.Cobblestone)
		end
		for _, s in { -1, 1 } do
			block("VineChokedMonolith", V(12 * scale, 48 * scale, 12 * scale), backdrop + V(s * 38 * scale, 24 * scale, 8), cliffColor, Enum.Material.Rock)
			tree(backdrop + V(s * 62 * scale, 0, -4), 1.45 * scale, true, false)
		end
		local ringCenter = backdrop + V(0, 48 * scale, 8)
		ring("SpikedCrescent", ringCenter, 28 * scale, 4.5 * scale, rgb(28, 18, 34), Enum.Material.Metal, nil, 0.15, math.pi * 1.85, 18)
		orb("CorruptionCore", ringCenter - V(0, 4 * scale, 0), V(18 * scale, 18 * scale, 18 * scale), rgb(255, 65, 195), Enum.Material.Neon, 0.05)
		for j = 1, 9 do
			local a = j * math.pi / 5
			local thornBase = ringCenter + V(math.cos(a) * 29 * scale, math.sin(a) * 29 * scale, 0)
			beam("CrescentSpike", thornBase, thornBase + V(math.cos(a) * 14 * scale, math.sin(a) * 14 * scale, 0), 2.5 * scale, rgb(24, 16, 28), Enum.Material.Metal)
		end

	elseif biome == "sunken_sanctuary" then
		spire(backdrop + V(0, 12 * scale, -8), 80 * scale, 19 * scale, theme.TrimColor, accent, false)
		for rIdx = 1, 3 do
			ring("SpireCyanSigil", backdrop + V(0, (40 + rIdx * 16) * scale, 2), (15 - rIdx * 2) * scale, 1.3, accent, Enum.Material.Neon, nil, 0, math.pi * 2, 14)
		end
		local portalCenter = backdrop + V(0, 30 * scale, 14)
		ring("GoldenLotusPortal", portalCenter, 22 * scale, 3.4 * scale, gold, Enum.Material.Metal, nil, 0, math.pi * 2, 18)
		orb("SanctuaryGoldenOrb", portalCenter, V(28 * scale, 28 * scale, 5 * scale), rgb(235, 210, 140), Enum.Material.SmoothPlastic, 0.35)
		for pIdx = 1, 8 do
			local a = pIdx * math.pi / 4
			local petalAt = portalCenter + V(math.cos(a) * 24 * scale, math.sin(a) * 24 * scale, 0)
			beam("LotusPetal", petalAt, petalAt + V(math.cos(a) * 9 * scale, math.sin(a) * 9 * scale, 0), 2.6 * scale, gold, Enum.Material.Metal)
		end
		for bIdx = -2, 2 do
			beam("OceanCausticSunbeam", V(bIdx * 52, h - 4, -d * 0.2 + bIdx * 25), V(bIdx * 42 + 18, 0, -d * 0.08 + bIdx * 25), 16, rgb(135, 245, 255), Enum.Material.SmoothPlastic, 0.90)
		end

	elseif biome == "astral_archives" then
		arch(backdrop + V(0, 0, 12), 48 * scale, 46 * scale, 12, gold, Enum.Material.Metal, 0)
		orb("GalaxyPortal", backdrop + V(0, 36 * scale, 10), V(40 * scale, 58 * scale, 4), rgb(88, 118, 245), Enum.Material.SmoothPlastic, 0.35)
		orb("GalaxyPortalCore", backdrop + V(0, 36 * scale, 11), V(24 * scale, 38 * scale, 3), rgb(168, 115, 255), Enum.Material.SmoothPlastic, 0.45)
		local orreryCenter = backdrop + V(0, 90 * scale, 22)
		for j = 1, 4 do
			ring("CelestialOrreryRing", orreryCenter, (19 + j * 8) * scale, 1.9 * scale, gold, Enum.Material.Metal, CFrame.Angles(0.35 * j, 0.55 * j, 0.2 * j), 0, math.pi * 2, 18)
			local pAng = j * 1.4
			orb("OrbitingPlanet", orreryCenter + V(math.cos(pAng) * (19 + j * 8) * scale, math.sin(pAng) * 8 * scale, math.sin(pAng) * (19 + j * 8) * scale), V(5.5 * scale, 5.5 * scale, 5.5 * scale), if j % 2 == 0 then accent else gold, Enum.Material.SmoothPlastic, 0.2)
		end
		orb("OrreryCentralSun", orreryCenter, V(15 * scale, 15 * scale, 15 * scale), rgb(240, 220, 140), Enum.Material.SmoothPlastic, 0.2)

	else
		block("ObsidianCitadelKeep", V(72 * scale, 76 * scale, 30 * scale), backdrop + V(0, 38 * scale, -6), rgb(20, 16, 28), Enum.Material.Basalt)
		spire(backdrop + V(0, 58 * scale, -6), 56 * scale, 21 * scale, rgb(24, 18, 34), rgb(165, 95, 255), false)
		for _, s in { -1, 1 } do
			spire(backdrop + V(s * 36 * scale, 12 * scale, 0), 68 * scale, 16 * scale, rgb(24, 18, 34), accent, false)
			chain(backdrop + V(s * 36 * scale, 56 * scale, 0), V(s * (w * 0.36), 44 * scale, -d * 0.28), 2.4)
		end
		block("ObsidianThroneBack", V(28 * scale, 46 * scale, 8 * scale), backdrop + V(0, 23 * scale, 10), rgb(18, 14, 26), Enum.Material.Basalt)
		block("ObsidianThroneSeat", V(30 * scale, 5 * scale, 18 * scale), backdrop + V(0, 8 * scale, 16), gold, Enum.Material.Metal)
		local eclipseAt = backdrop + V(0, 98 * scale, 14)
		orb("EclipseCoronaHalo", eclipseAt, V(60 * scale, 60 * scale, 5 * scale), rgb(162, 95, 255), Enum.Material.SmoothPlastic, 0.45)
		orb("BlackEclipseSphere", eclipseAt + V(0, 0, 2), V(52 * scale, 52 * scale, 12 * scale), rgb(8, 6, 14), Enum.Material.SmoothPlastic)
		block("DescendingVioletBeam", V(5.0 * scale, 86 * scale, 5.0 * scale), backdrop + V(0, 50 * scale, 14), rgb(178, 108, 255), Enum.Material.SmoothPlastic, nil, 0.50)
	end

	-- Keep every enemy camp completely clear of props.
	-- Mobs are grounded by raycasting downward; props overlapping a camp obstruct navigation and embed mobs.
	local campOffsets = { { 0, 0 }, { -18, 12 }, { 18, 12 }, { -12, -16 }, { 12, -16 } }
	for _, inst in kit:GetChildren() do
		if inst:IsA("BasePart") then
			local instPos = inst.Position
			local instSize = inst.Size
			local half = instSize * 0.5
			local shouldDestroy = false

			for _, camp in layout.Camps do
				local campCenter = origin + V(camp.X, camp.Y, camp.Z)
				-- Check vertical overlap: camp ground level - 2 up to camp ground level + 22
				if (instPos.Y - half.Y) <= (campCenter.Y + 22) and (instPos.Y + half.Y) >= (campCenter.Y - 2) then
					-- Check horizontal distance from camp center
					local cdx = instPos.X - campCenter.X
					local cdz = instPos.Z - campCenter.Z
					local cDistSq = cdx * cdx + cdz * cdz
					-- If the part center is within 34 studs of camp center, it's inside the camp zone
					if cDistSq <= (34 * 34) then
						shouldDestroy = true
						break
					end

					-- Also check against each mob slot bounding box
					for slot = 1, math.min(camp.Size, #campOffsets) do
						local o = campOffsets[slot]
						local slotWorld = campCenter + V(o[1], 2, o[2])
						local lp = inst.CFrame:PointToObjectSpace(slotWorld)
						local pad = Vector3.new(7, 6, 7)
						if math.abs(lp.X) <= (half.X + pad.X)
							and math.abs(lp.Y) <= (half.Y + pad.Y)
							and math.abs(lp.Z) <= (half.Z + pad.Z)
						then
							shouldDestroy = true
							break
						end
					end
					if shouldDestroy then break end
				end
			end

			if shouldDestroy then
				inst:Destroy()
			end
		end
	end

	kit.Parent = parent
end

return Assets
