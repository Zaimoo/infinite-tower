--!strict
-- ServerScriptService/Core/SynthesisChamberBuilder.luau
-- Enterable dark-gothic rotunda for the Synthesis Chamber ("The Pit").
--
-- Layout (building-local studs; origin = ground centre of the plinth, doors face +Z):
--   * 40 x 40 square plinth, round podium (floor Y = 2.4), 7-step front stair flanked by cheek walls.
--   * Rotunda wall: outer R 17 / inner R 15, top Y 22, with a flat projecting entrance bay.
--   * Doorway: 12 wide x 16 tall (round arch, spring Y 12.4) closed by two hinged leaves that the
--     client swings OUTWARD (left -95 deg, right +95 deg) - see SynthesisDoorController.
--   * Exterior colonnade, blind arches, cyan lattice windows, cornice, battlements, ribbed dome with
--     violet rune channels, dormer vents and a tiered spire.
--   * Interior sanctum: two-tier arcade gallery, cyan/violet lancet windows, magic circle and the
--     Synthesis anvil on a dais. The prompt anchor sits above the anvil, so players walk inside.
--
-- Mesh path: if ReplicatedStorage.Assets.CustomFacilityMeshes.SynthesisChamber exists (FBX built by
-- tools/blender/generate_synthesis_chamber.py and imported with Import 3D), its MeshParts are used
-- for visuals and the procedural solids below stay behind as invisible colliders.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = {}

local V = Vector3.new
local rad = math.rad

-- Shared dimensions (keep in sync with tools/blender/generate_synthesis_chamber.py)
local DIM = {
	PlinthHalf = 20,
	PlinthTop = 1.2,
	PodiumR = 18.6,
	FloorY = 2.4,
	InteriorFloorY = 2.45,
	WallOuterR = 17,
	WallInnerR = 15,
	WallTopY = 22,
	DoorHalfW = 6,
	DoorSpringY = 12.4,
	DoorArchR = 6,
	BayHalfW = 9.5,
	BayBackZ = 13.4,
	BayFrontZ = 17.4,
	StepCount = 7,
	StepFrontZ = 25,
	StepTread = 1,
	StepHalfW = 7,
	DomeBaseY = 23,
	DomeR = 16.2,
	DomeH = 9.5,
	GalleryR = 13.4,
	DoorOpenAngleDeg = 95,
}
Builder.Dimensions = DIM

-- Socket positions (building-local)
Builder.Sockets = {
	DoorTriggerCenter = V(0, 3, 18.5),
	PromptAnchor = V(0, 6.2, 0),
	PedestalCoreVFXSocket = V(0, 7.45, 0),
}

-- 6 material zones
local C_STONE = Color3.fromRGB(58, 63, 71) -- #3A3F47 Mat_DarkGothicStone
local C_STONE_LIGHT = Color3.fromRGB(82, 88, 99)
local C_STONE_DARK = Color3.fromRGB(40, 44, 51)
local C_GALLERY = Color3.fromRGB(74, 68, 88) -- #4A4458 Mat_InteriorGalleryStone
local C_GALLERY_LIGHT = Color3.fromRGB(104, 96, 122)
local C_FLOOR = Color3.fromRGB(58, 54, 70)
local C_TIMBER = Color3.fromRGB(46, 40, 42) -- #2E282A Mat_HeavyDoorTimber
local C_TIMBER_LIGHT = Color3.fromRGB(66, 58, 60)
local C_IRON = Color3.fromRGB(26, 28, 32) -- #1A1C20 Mat_DarkForgedIron
local C_CYAN = Color3.fromRGB(0, 229, 255) -- #00E5FF Mat_NeonCyanArcane
local C_VIOLET = Color3.fromRGB(192, 132, 252) -- #C084FC Mat_NeonVioletRune
local C_VIOLET_DEEP = Color3.fromRGB(126, 34, 206)

local SMOKE_TEXTURE = "rbxassetid://243660364"

type Ctx = {
	Model: Model,
	CF: CFrame,
}

--------------------------------------------------------------------------------
-- Primitive helpers
--------------------------------------------------------------------------------
local function newPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	collide: boolean
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = collide
	p.CanQuery = collide
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if material == Enum.Material.Neon then
		p.CastShadow = false
	end
	p.Parent = parent
	return p
end

-- Vertical cylinder centred on `cf` (Roblox cylinders run along X, so roll 90 deg).
local function vcyl(
	parent: Instance,
	name: string,
	radius: number,
	height: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	collide: boolean
): Part
	local p = newPart(parent, name, V(height, radius * 2, radius * 2), cf * CFrame.Angles(0, 0, math.pi / 2), color, material, collide)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Flat disc whose axis points along the frame's local Z (used for arch heads and door roundels).
local function zdisc(
	parent: Instance,
	name: string,
	diameter: number,
	thickness: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local p = newPart(parent, name, V(thickness, diameter, diameter), cf * CFrame.Angles(0, math.pi / 2, 0), color, material, false)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ball(parent: Instance, name: string, diameter: number, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = newPart(parent, name, V(diameter, diameter, diameter), cf, color, material, false)
	p.Shape = Enum.PartType.Ball
	return p
end

-- Frame on a circle: angle measured from +Z toward +X; local Z = radial outward, local X = tangent.
local function ringCF(base: CFrame, angleDeg: number, radius: number, y: number): CFrame
	local a = rad(angleDeg)
	return base * CFrame.new(math.sin(a) * radius, y, math.cos(a) * radius) * CFrame.Angles(0, a, 0)
end

local function pointLight(parent: Instance, name: string, color: Color3, brightness: number, range: number): PointLight
	local l = Instance.new("PointLight")
	l.Name = name
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	l.Parent = parent
	return l
end

local function keep(p: BasePart): BasePart
	-- Parts flagged MeshKeep survive the mesh path (VFX/light holders, door hinges, interaction parts).
	p:SetAttribute("MeshKeep", true)
	return p
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- True when an angle (deg, from +Z) falls inside the projecting entrance bay.
local function inEntranceBay(angleDeg: number, radius: number): boolean
	local a = rad(angleDeg)
	return math.cos(a) > 0 and math.abs(math.sin(a) * radius) < DIM.BayHalfW + 0.1
end

--------------------------------------------------------------------------------
-- 1. Plinth, podium and front stair
--------------------------------------------------------------------------------
local function buildBase(ctx: Ctx)
	local g = folder(ctx.Model, "Chamber_Base")
	local cf = ctx.CF
	local h = DIM.PlinthHalf * 2
	newPart(g, "PlinthSlab", V(h, DIM.PlinthTop, h), cf * CFrame.new(0, DIM.PlinthTop / 2, 0), C_STONE_DARK, Enum.Material.Slate, true)
	newPart(g, "PlinthPaving", V(h - 0.8, 0.1, h - 0.8), cf * CFrame.new(0, DIM.PlinthTop + 0.05, 0), C_STONE, Enum.Material.Cobblestone, true)
	for _, s in ipairs({ -1, 1 }) do
		newPart(g, "PlinthEdgeX", V(0.8, 0.5, h), cf * CFrame.new(s * (DIM.PlinthHalf - 0.4), DIM.PlinthTop + 0.1, 0), C_STONE_LIGHT, Enum.Material.Slate, true)
		newPart(g, "PlinthEdgeZ", V(h, 0.5, 0.8), cf * CFrame.new(0, DIM.PlinthTop + 0.1, s * (DIM.PlinthHalf - 0.4)), C_STONE_LIGHT, Enum.Material.Slate, true)
	end
	local podiumH = DIM.FloorY - DIM.PlinthTop
	vcyl(g, "Podium", DIM.PodiumR, podiumH - 0.3, cf * CFrame.new(0, DIM.PlinthTop + (podiumH - 0.3) / 2, 0), C_STONE, Enum.Material.Slate, true)
	vcyl(g, "PodiumLip", DIM.PodiumR + 0.3, 0.3, cf * CFrame.new(0, DIM.FloorY - 0.15, 0), C_STONE_LIGHT, Enum.Material.Slate, true)

	-- Stair: each step is a solid block from the ground so nothing can be seen underneath.
	local rise = DIM.FloorY / DIM.StepCount
	local backZ = DIM.PodiumR - 1.1
	for i = 1, DIM.StepCount do
		local topY = i * rise
		local frontZ = DIM.StepFrontZ - (i - 1) * DIM.StepTread
		local depth = frontZ - backZ
		local color = if i % 2 == 0 then C_STONE_LIGHT else C_STONE
		newPart(g, "Step_" .. i, V(DIM.StepHalfW * 2, topY, depth), cf * CFrame.new(0, topY / 2, backZ + depth / 2), color, Enum.Material.Slate, true)
	end

	-- Cheek walls with cap stones
	local cheekLen = DIM.StepFrontZ + 0.4 - backZ
	for _, s in ipairs({ -1, 1 }) do
		local x = s * (DIM.StepHalfW + 0.9)
		newPart(g, "StairCheekWall", V(1.8, 3.2, cheekLen), cf * CFrame.new(x, 1.6, backZ + cheekLen / 2), C_STONE_DARK, Enum.Material.Slate, true)
		newPart(g, "StairCheekCap", V(2.2, 0.4, cheekLen + 0.2), cf * CFrame.new(x, 3.4, backZ + cheekLen / 2), C_STONE_LIGHT, Enum.Material.Slate, true)
	end
end

--------------------------------------------------------------------------------
-- 2. Rotunda wall, entrance bay and exterior ornament
--------------------------------------------------------------------------------
local function buildShell(ctx: Ctx)
	local g = folder(ctx.Model, "Chamber_Shell")
	local cf = ctx.CF
	local wallH = DIM.WallTopY - DIM.FloorY
	local wallMidY = DIM.FloorY + wallH / 2

	-- 24-segment double-skin wall: dark slate outside, purple gallery stone inside.
	for k = 0, 23 do
		local a = 7.5 + k * 15
		if not inEntranceBay(a, DIM.WallOuterR - 1) then
			newPart(g, "WallOuter_" .. k, V(4.6, wallH, 1.2), ringCF(cf, a, DIM.WallOuterR - 0.6, wallMidY), C_STONE, Enum.Material.Slate, true)
			newPart(g, "WallInner_" .. k, V(4.0, wallH, 0.8), ringCF(cf, a, DIM.WallInnerR + 0.4, wallMidY), C_GALLERY, Enum.Material.Granite, true)
			newPart(g, "WallBaseCourse_" .. k, V(4.7, 1.4, 0.8), ringCF(cf, a, DIM.WallOuterR + 0.2, DIM.FloorY + 0.7), C_STONE_LIGHT, Enum.Material.Slate, true)
		end
	end

	-- Projecting entrance bay with a round-arched 12 x 16 opening
	local bayDepth = DIM.BayFrontZ - DIM.BayBackZ
	local bayZ = DIM.BayBackZ + bayDepth / 2
	local pierW = DIM.BayHalfW - DIM.DoorHalfW
	for _, s in ipairs({ -1, 1 }) do
		newPart(g, "BayPier", V(pierW, wallH, bayDepth), cf * CFrame.new(s * (DIM.DoorHalfW + pierW / 2), wallMidY, bayZ), C_STONE, Enum.Material.Slate, true)
	end
	local slices = 10
	local sliceH = DIM.DoorArchR / slices
	for j = 0, slices - 1 do
		local hMid = (j + 0.5) * sliceH
		local w = math.sqrt(math.max(0, DIM.DoorArchR * DIM.DoorArchR - hMid * hMid))
		local fillW = DIM.DoorHalfW - w
		if fillW > 0.05 then
			for _, s in ipairs({ -1, 1 }) do
				newPart(
					g,
					"BayArchInfill",
					V(fillW, sliceH, bayDepth),
					cf * CFrame.new(s * (w + fillW / 2), DIM.DoorSpringY + hMid, bayZ),
					C_STONE,
					Enum.Material.Slate,
					true
				)
			end
		end
	end
	local apexY = DIM.DoorSpringY + DIM.DoorArchR
	newPart(g, "BayArchCrown", V(DIM.DoorHalfW * 2, DIM.WallTopY - apexY, bayDepth), cf * CFrame.new(0, (apexY + DIM.WallTopY) / 2, bayZ), C_STONE, Enum.Material.Slate, true)

	-- Voussoir ring set back 0.6 from the opening so the outward door swing never clips it
	local vCount = 15
	local vR = DIM.DoorArchR + 1.2
	for i = 0, vCount - 1 do
		local th = math.pi * (i + 0.5) / vCount
		local isKey = i == math.floor(vCount / 2)
		local segLen = 2 * vR * math.sin(math.pi / (2 * vCount)) + 0.12
		newPart(
			g,
			if isKey then "ArchKeystone" else "ArchVoussoir_" .. i,
			if isKey then V(1.9, 1.9, 0.75) else V(segLen, 1.2, 0.6),
			cf * CFrame.new(math.cos(th) * vR, DIM.DoorSpringY + math.sin(th) * vR, DIM.BayFrontZ - 0.2) * CFrame.Angles(0, 0, th + math.pi / 2),
			if i % 2 == 0 then C_STONE_LIGHT else C_STONE,
			Enum.Material.Slate,
			false
		)
	end
	newPart(g, "KeystoneRune", V(0.7, 0.7, 0.1), cf * CFrame.new(0, DIM.DoorSpringY + vR, DIM.BayFrontZ + 0.2) * CFrame.Angles(0, 0, math.pi / 4), C_VIOLET, Enum.Material.Neon, false)

	-- Engaged columns, frieze and rune band framing the bay
	for _, s in ipairs({ -1, 1 }) do
		local x = s * (DIM.BayHalfW - 0.75)
		newPart(g, "BayColumnBase", V(1.9, 1.0, 1.2), cf * CFrame.new(x, DIM.FloorY + 0.5, DIM.BayFrontZ + 0.3), C_STONE_LIGHT, Enum.Material.Slate, true)
		vcyl(g, "BayColumn", 0.7, 16.6, cf * CFrame.new(x, DIM.FloorY + 1.0 + 8.3, DIM.BayFrontZ + 0.25), C_STONE_LIGHT, Enum.Material.Slate, true)
		newPart(g, "BayColumnCapital", V(2.0, 1.0, 1.3), cf * CFrame.new(x, DIM.FloorY + 18.1, DIM.BayFrontZ + 0.3), C_STONE_LIGHT, Enum.Material.Slate, false)
	end
	newPart(g, "BayFrieze", V(DIM.BayHalfW * 2, 0.9, 0.5), cf * CFrame.new(0, 21.0, DIM.BayFrontZ + 0.15), C_STONE_LIGHT, Enum.Material.Slate, false)
	newPart(g, "BayRuneFrieze", V(9.0, 0.22, 0.1), cf * CFrame.new(0, 21.0, DIM.BayFrontZ + 0.45), C_VIOLET, Enum.Material.Neon, false)

	-- Free-standing colonnade aligned with the interior arcade (every 30 deg, clear of the bay)
	for a = 60, 300, 30 do
		newPart(g, "ColonnadeBase", V(2.0, 1.0, 2.0), ringCF(cf, a, 18.0, DIM.FloorY + 0.5), C_STONE_LIGHT, Enum.Material.Slate, true)
		vcyl(g, "ColonnadeShaft", 0.8, 17.4, ringCF(cf, a, 18.0, DIM.FloorY + 1.0 + 8.7), C_STONE, Enum.Material.Slate, true)
		newPart(g, "ColonnadeCapital", V(2.2, 1.0, 2.2), ringCF(cf, a, 18.0, DIM.FloorY + 18.9), C_STONE_LIGHT, Enum.Material.Slate, false)
	end

	-- Blind arches between columns; cyan lattice windows on the lower flanks
	local windowBays = { [75] = true, [105] = true, [255] = true, [285] = true }
	for a = 45, 315, 30 do
		local r = DIM.WallOuterR + 0.05
		newPart(g, "BlindArchPanel", V(3.0, 8.6, 0.2), ringCF(cf, a, r, 10.3), C_STONE_DARK, Enum.Material.Slate, false)
		zdisc(g, "BlindArchHead", 3.0, 0.2, ringCF(cf, a, r, 14.6), C_STONE_DARK, Enum.Material.Slate)
		if windowBays[a] then
			local w = newPart(g, "LatticeWindowGlow", V(1.3, 4.6, 0.2), ringCF(cf, a, r + 0.12, 9.6), C_CYAN, Enum.Material.Neon, false)
			w.Transparency = 0.1
			newPart(g, "LatticeMullionV", V(0.16, 4.6, 0.12), ringCF(cf, a, r + 0.26, 9.6), C_IRON, Enum.Material.Metal, false)
			newPart(g, "LatticeMullionH", V(1.3, 0.16, 0.12), ringCF(cf, a, r + 0.26, 8.6), C_IRON, Enum.Material.Metal, false)
			newPart(g, "LatticeMullionH", V(1.3, 0.16, 0.12), ringCF(cf, a, r + 0.26, 10.6), C_IRON, Enum.Material.Metal, false)
		end
	end

	-- Overhanging cornice, parapet ring and merlons
	for k = 0, 23 do
		local a = k * 15
		newPart(g, "Cornice_" .. k, V(4.9, 1.2, 2.4), ringCF(cf, a, 17.7, 22.4), C_STONE_LIGHT, Enum.Material.Slate, true)
		newPart(g, "Parapet_" .. k, V(5.0, 1.0, 1.0), ringCF(cf, a, 18.2, 23.5), C_STONE, Enum.Material.Slate, true)
	end
	for k = 0, 15 do
		newPart(g, "Merlon_" .. k, V(2.2, 1.4, 1.2), ringCF(cf, k * 22.5 + 11.25, 18.2, 24.7), C_STONE, Enum.Material.Slate, true)
	end
end

--------------------------------------------------------------------------------
-- 3. Ribbed dome, rune channels, dormer vents and spire
--------------------------------------------------------------------------------
local function domeProfile(t: number): (number, number)
	-- t in [0,1] -> (radius, y) on a slightly flattened ellipsoid
	return DIM.DomeR * math.sqrt(math.max(0, 1 - t * t)), DIM.DomeBaseY + DIM.DomeH * t
end

local function buildRoof(ctx: Ctx): { Attachment }
	local g = folder(ctx.Model, "Chamber_Roof")
	local cf = ctx.CF
	local tiers = 12
	local tierH = DIM.DomeH / tiers
	for i = 0, tiers - 1 do
		local r = domeProfile((i + 0.5) / tiers)
		vcyl(
			g,
			"DomeCourse_" .. i,
			r,
			tierH,
			cf * CFrame.new(0, DIM.DomeBaseY + (i + 0.5) * tierH, 0),
			if i % 2 == 0 then C_STONE else C_STONE_DARK,
			Enum.Material.Slate,
			true
		)
	end

	-- Strip of straight segments following the dome profile at a given azimuth.
	local function profileStrip(name: string, azimuth: number, t0: number, t1: number, steps: number, lift: number, size: Vector2, color: Color3, material: Enum.Material)
		local rot = cf * CFrame.Angles(0, rad(azimuth), 0)
		for j = 0, steps - 1 do
			local ta = t0 + (t1 - t0) * j / steps
			local tb = t0 + (t1 - t0) * (j + 1) / steps
			local ra, ya = domeProfile(ta)
			local rb, yb = domeProfile(tb)
			local pa = rot:PointToWorldSpace(V(0, ya, ra + lift))
			local pb = rot:PointToWorldSpace(V(0, yb, rb + lift))
			local len = (pb - pa).Magnitude
			newPart(g, name, V(size.X, size.Y, len + 0.15), CFrame.lookAt((pa + pb) / 2, pb, rot.UpVector), color, material, false)
		end
	end

	for k = 0, 7 do
		profileStrip("DomeRib", 22.5 + k * 45, 0, 0.93, 5, 0.3, Vector2.new(0.9, 0.7), C_STONE_LIGHT, Enum.Material.Slate)
	end
	for k = 0, 3 do
		profileStrip("DomeRuneChannel", k * 90, 0.12, 0.8, 3, 0.06, Vector2.new(0.35, 0.12), C_VIOLET, Enum.Material.Neon)
	end

	-- Dormer vents with violet glow and smoke sockets
	local smokeSockets: { Attachment } = {}
	for k = 0, 3 do
		local a = 45 + k * 90
		local r, y = domeProfile(0.3)
		local dcf = ringCF(cf, a, r - 0.6, y + 0.6)
		newPart(g, "DormerVent", V(2.6, 2.2, 2.2), dcf, C_STONE, Enum.Material.Slate, false)
		newPart(g, "DormerHood", V(3.0, 0.4, 2.6), dcf * CFrame.new(0, 1.3, 0.1), C_STONE_LIGHT, Enum.Material.Slate, false)
		newPart(g, "DormerGlow", V(1.4, 1.1, 0.12), dcf * CFrame.new(0, -0.1, 1.12), C_VIOLET, Enum.Material.Neon, false)
		local att = Instance.new("Attachment")
		att.Name = "RoofSmokeVFXSocket"
		att.CFrame = (ctx.CF:ToObjectSpace(dcf * CFrame.new(0, 1.6, 0.4)))
		table.insert(smokeSockets, att)
	end

	-- Tiered spire
	local topR, topY = domeProfile(1)
	local y = topY
	local function spireTier(name: string, r: number, h: number, color: Color3, material: Enum.Material): Part
		local p = vcyl(g, name, r, h, cf * CFrame.new(0, y + h / 2, 0), color, material, false)
		y += h
		return p
	end
	local _ = topR
	spireTier("SpireDrum", 2.7, 1.3, C_STONE, Enum.Material.Slate)
	spireTier("SpireDrumCap", 3.0, 0.4, C_STONE_LIGHT, Enum.Material.Slate)
	local lanternY = y
	spireTier("SpireLantern", 1.6, 1.8, C_STONE_DARK, Enum.Material.Slate)
	for k = 0, 3 do
		newPart(g, "SpireLanternSlit", V(0.35, 1.2, 0.1), ringCF(cf, k * 90 + 45, 1.62, lanternY + 0.9), C_VIOLET, Enum.Material.Neon, false)
	end
	spireTier("SpireCap", 2.0, 0.4, C_STONE_LIGHT, Enum.Material.Slate)
	spireTier("SpireTier1", 1.2, 0.9, C_STONE, Enum.Material.Slate)
	spireTier("SpireTier2", 0.8, 0.9, C_STONE, Enum.Material.Slate)
	spireTier("SpireTier3", 0.45, 0.9, C_STONE_LIGHT, Enum.Material.Slate)
	spireTier("SpireNeedle", 0.16, 2.8, C_IRON, Enum.Material.Metal)

	local spireAtt = Instance.new("Attachment")
	spireAtt.Name = "RoofSmokeVFXSocket"
	spireAtt.Position = V(0, lanternY + 1.0, 0)
	table.insert(smokeSockets, spireAtt)
	return smokeSockets
end

--------------------------------------------------------------------------------
-- 4. Outward-opening double doors (Models pivoted on their outer hinge edge)
--------------------------------------------------------------------------------
local function buildDoorLeaf(ctx: Ctx, name: string, side: number): Model
	-- side = -1 for the left leaf (hinge at -X), +1 for the right leaf (hinge at +X)
	local cf = ctx.CF
	local door = Instance.new("Model")
	door.Name = name
	door.Parent = ctx.Model

	local hx = side * DIM.DoorHalfW
	local hingeCF = cf * CFrame.new(hx, DIM.InteriorFloorY, DIM.BayFrontZ)
	local hinge = keep(newPart(door, "HingePivot", V(0.2, 0.2, 0.2), hingeCF, C_IRON, Enum.Material.Metal, false))
	hinge.Transparency = 1
	door.PrimaryPart = hinge

	local zMid = DIM.BayFrontZ - 0.3
	local zFace = DIM.BayFrontZ + 0.05
	local leafX = function(dx: number): number
		-- dx measured from the hinge toward the doorway centre
		return hx - side * dx
	end

	local bottomY = DIM.InteriorFloorY + 0.05
	local slabH = DIM.DoorSpringY - bottomY
	newPart(door, "DoorSlab", V(DIM.DoorHalfW, slabH, 0.6), cf * CFrame.new(leafX(DIM.DoorHalfW / 2), bottomY + slabH / 2, zMid), C_TIMBER, Enum.Material.Wood, false)
	local slices = 8
	local sliceH = DIM.DoorArchR / slices
	for j = 0, slices - 1 do
		local hMid = (j + 0.5) * sliceH
		local w = math.sqrt(math.max(0, DIM.DoorArchR * DIM.DoorArchR - hMid * hMid))
		if w > 0.1 then
			newPart(door, "DoorArchSlice", V(w, sliceH, 0.6), cf * CFrame.new(-side * w / 2, DIM.DoorSpringY + hMid, zMid), C_TIMBER, Enum.Material.Wood, false)
		end
	end
	for _, dx in ipairs({ 1.5, 4.5 }) do
		newPart(door, "PlankGroove", V(0.12, slabH - 0.4, 0.06), cf * CFrame.new(leafX(dx), bottomY + slabH / 2, zFace), C_IRON, Enum.Material.Wood, false)
	end
	for _, y in ipairs({ 4.6, 10.6 }) do
		newPart(door, "HingeStrap", V(3.0, 0.45, 0.12), cf * CFrame.new(leafX(1.5), y, zFace + 0.02), C_IRON, Enum.Material.Metal, false)
	end
	newPart(door, "IronBand", V(DIM.DoorHalfW - 0.3, 0.35, 0.1), cf * CFrame.new(leafX(DIM.DoorHalfW / 2), 7.4, zFace), C_IRON, Enum.Material.Metal, false)
	-- Raised circular / crescent moulding and pull ring
	local roundel = cf * CFrame.new(leafX(3.0), 13.6, zFace)
	zdisc(door, "RoundelOuter", 3.4, 0.12, roundel, C_TIMBER_LIGHT, Enum.Material.Wood)
	zdisc(door, "RoundelInner", 2.5, 0.14, roundel * CFrame.new(0, 0, 0.02), C_TIMBER, Enum.Material.Wood)
	zdisc(door, "RoundelCrescent", 1.7, 0.16, roundel * CFrame.new(side * 0.35, 0.2, 0.04), C_IRON, Enum.Material.Metal)
	zdisc(door, "RoundelBoss", 0.6, 0.2, roundel * CFrame.new(0, 0, 0.06), C_VIOLET, Enum.Material.Neon)
	zdisc(door, "PullRing", 1.0, 0.12, cf * CFrame.new(leafX(5.1), 7.0, zFace + 0.06), C_IRON, Enum.Material.Metal)
	zdisc(door, "PullRingHole", 0.6, 0.14, cf * CFrame.new(leafX(5.1), 7.0, zFace + 0.08), C_TIMBER, Enum.Material.Wood)

	door:SetAttribute("OpenAngleDeg", if side < 0 then -DIM.DoorOpenAngleDeg else DIM.DoorOpenAngleDeg)
	door:SetAttribute("ClosedPivot", hingeCF)
	return door
end

--------------------------------------------------------------------------------
-- 5. Interior sanctum
--------------------------------------------------------------------------------
type InteriorRefs = { CoreBall: BasePart }

local function buildInterior(ctx: Ctx): InteriorRefs
	local g = folder(ctx.Model, "Chamber_Interior")
	local cf = ctx.CF
	local fy = DIM.InteriorFloorY
	vcyl(g, "SanctumFloor", DIM.WallInnerR + 0.05, 0.1, cf * CFrame.new(0, fy - 0.05, 0), C_FLOOR, Enum.Material.Granite, true)

	-- Magic circle: stacked discs read as concentric rings without any custom texture.
	local circle = folder(g, "Chamber_MagicCircle_Neon")
	local rings = {
		{ 8.0, C_CYAN, Enum.Material.Neon },
		{ 7.7, C_FLOOR, Enum.Material.Granite },
		{ 7.4, C_VIOLET, Enum.Material.Neon },
		{ 7.1, C_FLOOR, Enum.Material.Granite },
		{ 5.2, C_CYAN, Enum.Material.Neon },
		{ 4.95, C_FLOOR, Enum.Material.Granite },
	}
	for i, ring in ipairs(rings) do
		local r = ring[1] :: number
		vcyl(circle, "CircleRing_" .. i, r, 0.02, cf * CFrame.new(0, fy + 0.01 + i * 0.02, 0), ring[2] :: Color3, ring[3] :: Enum.Material, false)
	end
	local glyphY = fy + 0.16
	for k = 0, 11 do
		newPart(circle, "CircleGlyph", V(1.1, 0.04, 0.32), ringCF(cf, k * 30 + 15, 6.15, glyphY), C_VIOLET, Enum.Material.Neon, false)
		newPart(circle, "CircleTick", V(0.18, 0.04, 0.9), ringCF(cf, k * 30, 6.15, glyphY), C_CYAN, Enum.Material.Neon, false)
	end
	-- Hexagram (two triangles inscribed in r = 4.7)
	local triR = 4.7
	local side = triR * math.sqrt(3)
	for k = 0, 5 do
		local a = k * 60 + 30
		newPart(circle, "CircleHexagram", V(side, 0.04, 0.18), ringCF(cf, a, triR / 2, glyphY + 0.01), C_CYAN, Enum.Material.Neon, false)
	end

	-- Dais + Synthesis anvil
	vcyl(g, "Chamber_Center_Pedestal", 3.2, 0.8, cf * CFrame.new(0, fy + 0.4, 0), C_STONE, Enum.Material.Slate, true)
	vcyl(g, "PedestalIronTrim", 2.5, 0.5, cf * CFrame.new(0, fy + 1.05, 0), C_IRON, Enum.Material.Metal, true)
	local ay = fy + 1.3
	newPart(g, "AnvilFoot", V(2.4, 0.5, 1.7), cf * CFrame.new(0, ay + 0.25, 0), C_IRON, Enum.Material.Metal, true)
	newPart(g, "AnvilWaist", V(1.1, 1.1, 1.0), cf * CFrame.new(0, ay + 1.05, 0), C_IRON, Enum.Material.Metal, true)
	newPart(g, "AnvilFace", V(3.2, 0.7, 1.4), cf * CFrame.new(-0.2, ay + 1.95, 0), C_IRON, Enum.Material.Metal, true)
	local horn = Instance.new("WedgePart")
	horn.Name = "AnvilHorn"
	horn.Size = V(1.2, 0.7, 1.3)
	horn.CFrame = cf * CFrame.new(2.0, ay + 1.95, 0) * CFrame.Angles(0, -math.pi / 2, 0)
	horn.Color = C_IRON
	horn.Material = Enum.Material.Metal
	horn.Anchored = true
	horn.CanCollide = false
	horn.CanQuery = false
	horn.CanTouch = false
	horn.Parent = g
	newPart(g, "AnvilRuneInlay", V(2.4, 0.06, 0.25), cf * CFrame.new(-0.2, ay + 2.31, 0), C_CYAN, Enum.Material.Neon, false)

	local corePos = Builder.Sockets.PedestalCoreVFXSocket
	local core = keep(ball(g, "SynthesisCore", 1.0, cf * CFrame.new(corePos), C_CYAN, Enum.Material.Neon))
	core.Transparency = 0.1
	pointLight(core, "SynthesisCoreLight", C_CYAN, 1.4, 24)
	local flame = Instance.new("ParticleEmitter")
	flame.Name = "SynthesisCoreFlame"
	flame.Texture = SMOKE_TEXTURE
	flame.Color = ColorSequence.new(Color3.fromRGB(200, 250, 255), C_CYAN)
	flame.LightEmission = 1
	flame.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(0.6, 0.8),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	flame.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	flame.Lifetime = NumberRange.new(0.6, 1.1)
	flame.Rate = 6
	flame.Speed = NumberRange.new(1, 2.5)
	flame.Acceleration = V(0, 3, 0)
	flame.SpreadAngle = Vector2.new(18, 18)
	flame.Parent = core

	-- Lower arcade: 11 columns every 30 deg (gap over the doorway), 10 round arches
	local gr = DIM.GalleryR
	local capTop = fy + 8.75
	for a = 30, 330, 30 do
		newPart(g, "ArcadeBase", V(1.5, 0.5, 1.5), ringCF(cf, a, gr, fy + 0.25), C_GALLERY_LIGHT, Enum.Material.Granite, true)
		vcyl(g, "ArcadeShaft", 0.6, 7.7, ringCF(cf, a, gr, fy + 0.5 + 3.85), C_GALLERY_LIGHT, Enum.Material.Granite, true)
		newPart(g, "ArcadeCapital", V(1.7, 0.6, 1.7), ringCF(cf, a, gr, capTop - 0.3), C_GALLERY_LIGHT, Enum.Material.Granite, false)
		vcyl(g, "GalleryShaft", 0.45, 7.3, ringCF(cf, a, gr, 15.7 + 3.65), C_GALLERY_LIGHT, Enum.Material.Granite, false)
	end
	local halfChord = gr * math.sin(rad(15))
	local chordR = gr * math.cos(rad(15))
	for a = 45, 315, 30 do
		local frame = ringCF(cf, a, chordR, 0)
		for i = 0, 2 do
			local th = math.pi * (i + 0.5) / 3
			newPart(
				g,
				"ArcadeArch",
				V(2 * halfChord * math.sin(math.pi / 6) + 0.15, 0.7, 1.0),
				frame * CFrame.new(math.cos(th) * halfChord, capTop + math.sin(th) * halfChord, 0) * CFrame.Angles(0, 0, th + math.pi / 2),
				C_GALLERY_LIGHT,
				Enum.Material.Granite,
				false
			)
		end
		-- Upper gallery ledge + balustrade
		newPart(g, "GalleryLedge", V(7.9, 0.8, 2.4), ringCF(cf, a, 13.8, 15.3), C_GALLERY, Enum.Material.Granite, false)
		newPart(g, "GalleryBalustrade", V(7.0, 1.0, 0.3), ringCF(cf, a, 12.75, 16.2), C_GALLERY_LIGHT, Enum.Material.Granite, false)
		newPart(g, "GalleryRail", V(7.2, 0.25, 0.5), ringCF(cf, a, 12.75, 16.82), C_GALLERY_LIGHT, Enum.Material.Granite, false)
		-- Lancet windows: cyan below, violet above
		local lw = newPart(g, "LancetWindowCyan", V(1.4, 4.4, 0.15), ringCF(cf, a, DIM.WallInnerR - 0.05, fy + 4.6), C_CYAN, Enum.Material.Neon, false)
		lw.Transparency = 0.12
		zdisc(g, "LancetWindowCyanHead", 1.4, 0.15, ringCF(cf, a, DIM.WallInnerR - 0.05, fy + 6.8), C_CYAN, Enum.Material.Neon)
		local uw = newPart(g, "LancetWindowViolet", V(1.6, 3.8, 0.15), ringCF(cf, a, DIM.WallInnerR - 0.05, 19.0), C_VIOLET, Enum.Material.Neon, false)
		uw.Transparency = 0.2
	end
	-- Ceiling frieze ring (including above the doorway)
	for k = 0, 11 do
		newPart(g, "CeilingFrieze", V(7.2, 0.8, 1.8), ringCF(cf, k * 30 + 15, 14.0, 22.6), C_GALLERY, Enum.Material.Granite, false)
	end
	-- Ceiling ribs radiating to a violet oculus
	for k = 0, 7 do
		local a = 22.5 + k * 45
		newPart(g, "CeilingRib", V(0.6, 0.5, 10.4), ringCF(cf, a, 8.0, 22.75), C_GALLERY_LIGHT, Enum.Material.Granite, false)
	end
	vcyl(g, "CeilingOculusRim", 3.0, 0.4, cf * CFrame.new(0, 22.8, 0), C_GALLERY_LIGHT, Enum.Material.Granite, false)
	local oculus = keep(vcyl(g, "CeilingOculusGlow", 2.3, 0.1, cf * CFrame.new(0, 22.56, 0), C_VIOLET, Enum.Material.Neon, false))
	pointLight(oculus, "SanctumAmbientLight", C_VIOLET, 0.8, 22)

	return { CoreBall = core }
end

--------------------------------------------------------------------------------
-- 6. Roof smoke / embers
--------------------------------------------------------------------------------
local function addRoofSmoke(att: Attachment, embers: boolean)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "ArcaneRoofMist"
	smoke.Texture = SMOKE_TEXTURE
	smoke.Color = ColorSequence.new(C_VIOLET, C_VIOLET_DEEP)
	smoke.LightEmission = 0.6
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 4.5),
	})
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Lifetime = NumberRange.new(2.0, 3.2)
	smoke.Rate = 3
	smoke.Speed = NumberRange.new(2, 4)
	smoke.SpreadAngle = Vector2.new(12, 12)
	smoke.RotSpeed = NumberRange.new(-30, 30)
	smoke.Acceleration = V(0, 1.5, 0)
	smoke.Parent = att
	if embers then
		local e = Instance.new("ParticleEmitter")
		e.Name = "ArcaneRoofEmbers"
		e.Color = ColorSequence.new(C_VIOLET)
		e.LightEmission = 1
		e.Size = NumberSequence.new(0.15)
		e.Lifetime = NumberRange.new(1.5, 2.5)
		e.Rate = 5
		e.Speed = NumberRange.new(3, 6)
		e.SpreadAngle = Vector2.new(35, 35)
		e.Parent = att
	end
end

--------------------------------------------------------------------------------
-- 7. Optional imported-mesh visuals
--------------------------------------------------------------------------------
local MESH_LOOK: { [string]: { Color: Color3, Material: Enum.Material } } = {
	Chamber_Exterior_StaticMesh = { Color = C_STONE, Material = Enum.Material.Slate },
	Chamber_Interior_StaticMesh = { Color = C_GALLERY, Material = Enum.Material.Granite },
	Chamber_Door_Left = { Color = C_TIMBER, Material = Enum.Material.Wood },
	Chamber_Door_Right = { Color = C_TIMBER, Material = Enum.Material.Wood },
	Chamber_Center_Pedestal = { Color = C_IRON, Material = Enum.Material.Metal },
	Chamber_MagicCircle_Neon = { Color = C_CYAN, Material = Enum.Material.Neon },
	Chamber_Windows_Neon = { Color = C_CYAN, Material = Enum.Material.Neon },
	Chamber_Runes_Neon = { Color = C_VIOLET, Material = Enum.Material.Neon },
}

local function findImportedTemplate(): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local custom = assets and assets:FindFirstChild("CustomFacilityMeshes")
	local template = custom and custom:FindFirstChild("SynthesisChamber")
	if template and template:IsA("Model") and template:FindFirstChildWhichIsA("MeshPart", true) then
		return template
	end
	return nil
end

local function applyImportedMeshes(ctx: Ctx, template: Model, doors: { [string]: Model })
	-- Strip procedural visuals; keep solid parts as invisible colliders.
	for _, d in ipairs(ctx.Model:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("MeshKeep") ~= true then
			if d.CanCollide then
				d.Transparency = 1
			else
				d:Destroy()
			end
		end
	end

	local clone = template:Clone()
	clone:PivotTo(ctx.CF)
	local holder = folder(ctx.Model, "Chamber_Meshes")
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("MeshPart") then
			local look = MESH_LOOK[d.Name]
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			if look then
				d.Color = look.Color
				d.Material = look.Material
				if look.Material == Enum.Material.Neon then
					d.CastShadow = false
				end
			end
			local door = doors[d.Name]
			d.Parent = if door then door else holder
		end
	end
	clone:Destroy()
end

--------------------------------------------------------------------------------
-- Public entry
--------------------------------------------------------------------------------
function Builder.Build(parent: Instance, centerCF: CFrame): (Model, Part)
	local model = Instance.new("Model")
	model.Name = "Building_ThePit"
	model:SetAttribute("SynthesisChamber", true)
	model:SetAttribute("DoorOpenAngleDeg", DIM.DoorOpenAngleDeg)
	-- Stream the building as one unit so the door leaves always arrive with the shell.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local ctx: Ctx = { Model = model, CF = centerCF }

	buildBase(ctx)
	buildShell(ctx)
	local smokeSockets = buildRoof(ctx)
	local leftDoor = buildDoorLeaf(ctx, "Chamber_Door_Left", -1)
	local rightDoor = buildDoorLeaf(ctx, "Chamber_Door_Right", 1)
	buildInterior(ctx)

	-- Ground-level root (non-colliding so the hollow interior stays walkable)
	local root = keep(newPart(model, "PrimaryRoot", V(DIM.PlinthHalf * 2, 1, DIM.PlinthHalf * 2), centerCF * CFrame.new(0, 0.5, 0), C_STONE_DARK, Enum.Material.SmoothPlastic, false))
	root.Transparency = 1
	model.PrimaryPart = root

	local function socket(name: string, localPos: Vector3): Attachment
		local att = Instance.new("Attachment")
		att.Name = name
		att.CFrame = root.CFrame:ToObjectSpace(centerCF * CFrame.new(localPos))
		att.Parent = root
		return att
	end
	socket("DoorTriggerCenter", Builder.Sockets.DoorTriggerCenter)
	socket("PromptAnchor", Builder.Sockets.PromptAnchor)
	socket("PedestalCoreVFXSocket", Builder.Sockets.PedestalCoreVFXSocket)
	for i, att in ipairs(smokeSockets) do
		att.CFrame = root.CFrame:ToObjectSpace(centerCF * att.CFrame)
		att.Parent = root
		addRoofSmoke(att, i == #smokeSockets)
	end

	local interaction = keep(newPart(model, "FacilityInteraction", V(2, 2, 2), centerCF * CFrame.new(Builder.Sockets.PromptAnchor), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, false))
	interaction.Transparency = 1

	local template = findImportedTemplate()
	if template then
		applyImportedMeshes(ctx, template, { Chamber_Door_Left = leftDoor, Chamber_Door_Right = rightDoor })
		model:SetAttribute("VisualSource", "ImportedMesh")
	else
		model:SetAttribute("VisualSource", "Procedural")
	end

	model.Parent = parent
	return model, interaction
end

return Builder
