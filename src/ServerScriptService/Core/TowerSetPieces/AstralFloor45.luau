--!strict
-- Hand-authored set pieces for Astral Archives Floor 45: Rift Warden's Observatory (astral:5, BOSS_ARENA).
-- Design: docs/prompts/astral-archives-floor-layouts-prompt.md (Floor 45) & reference/Astral Archives 45.jpg.
--
-- Compact, sculpted circular Observatory terraces perched on craggy dark-obsidian floating cliffs around a
-- churning violet cosmic Rift Vortex, connected by 100%-solid flush stone walkways, lashed timber-and-bookcase
-- Sutures, and symmetrical glowing sapphire-cyan Star-Glass Ring Stairs passing through twin golden Azimuth
-- Rings onto the grand 208-stud circular Observing Floor dais under the colossal Great Telescope & open dome.
local CollectionService = game:GetService("CollectionService")
local InfernalFoundry = require(script.Parent.InfernalFoundry)

local AstralFloor45 = {}

local V = Vector3.new
local rgb = Color3.fromRGB
local Mat = Enum.Material

export type Landmark = InfernalFoundry.Landmark

local function swatch(r: number, g: number, b: number, mat: Enum.Material, trans: number?): any
	return { Color = rgb(r, g, b), Material = mat, Transparency = trans }
end

local function tinted(base: any, changes: { [string]: any }): any
	local o = table.clone(base)
	for role, s in changes do
		o[role] = s
	end
	return o
end

local RIFTWARD_45 = table.freeze({
	STONE = swatch(132, 138, 162, Mat.Slate),
	ALT = swatch(32, 40, 76, Mat.Marble),
	TRIM = swatch(224, 190, 104, Mat.Metal),
	METAL = swatch(176, 142, 76, Mat.Metal),
	WOOD = swatch(74, 48, 36, Mat.Wood),
	SILK = swatch(234, 226, 210, Mat.Fabric),
	GLOW = swatch(250, 228, 162, Mat.Neon),
	CRYSTAL = swatch(148, 206, 250, Mat.Glass, 0.18),
	MOSS = swatch(64, 82, 112, Mat.Grass),
})

local TELESCOPE_TINT = tinted(RIFTWARD_45, {
	STONE = swatch(128, 136, 162, Mat.Slate),
	ALT = swatch(30, 40, 78, Mat.Marble),
	METAL = swatch(192, 154, 80, Mat.Metal),
	TRIM = swatch(232, 198, 110, Mat.Metal),
	CRYSTAL = swatch(176, 218, 255, Mat.Glass, 0.14),
	GLOW = swatch(224, 238, 255, Mat.Neon),
})

local DOME_TINT = tinted(RIFTWARD_45, {
	STONE = swatch(114, 122, 148, Mat.Slate),
	ALT = swatch(28, 36, 70, Mat.Slate),
	METAL = swatch(174, 142, 80, Mat.Metal),
	TRIM = swatch(218, 184, 102, Mat.Metal),
})

local RIFT_EYE_TINT = tinted(RIFTWARD_45, {
	ALT = swatch(22, 10, 50, Mat.SmoothPlastic),
	CRYSTAL = swatch(154, 86, 250, Mat.Glass, 0.14),
	GLOW = swatch(212, 152, 255, Mat.Neon),
	SILK = swatch(238, 226, 250, Mat.Fabric),
})

local RIFT_LIP_TINT = tinted(RIFTWARD_45, {
	STONE = swatch(42, 42, 66, Mat.Slate),
	ALT = swatch(28, 22, 54, Mat.Slate),
	CRYSTAL = swatch(166, 118, 250, Mat.Glass, 0.18),
	GLOW = swatch(206, 162, 255, Mat.Neon),
})

local SILVER_LENS_TINT = tinted(RIFTWARD_45, {
	GLOW = swatch(214, 236, 255, Mat.Neon),
	CRYSTAL = swatch(182, 224, 255, Mat.Glass, 0.14),
})

local INK_POOL_TINT = tinted(RIFTWARD_45, {
	STONE = swatch(118, 124, 148, Mat.Slate),
	ALT = swatch(26, 36, 98, Mat.Marble),
	CRYSTAL = swatch(96, 118, 240, Mat.Glass, 0.16),
	GLOW = swatch(162, 148, 255, Mat.Neon),
})

local STONE_TOP = rgb(114, 120, 148)
local STONE_LIGHT = rgb(146, 152, 178)
local STONE_DARK = rgb(76, 82, 110)
local WALL_FACE = rgb(88, 94, 124)
local CLIFF_ROCK = rgb(54, 58, 84)
local CLIFF_MID = rgb(40, 44, 68)
local CLIFF_DEEP = rgb(26, 28, 50)
local LAPIS_DARK = rgb(42, 52, 92)
local GOLD_BRIGHT = rgb(234, 198, 112)
local BRASS_AGED = rgb(186, 150, 82)
local WOOD_WARM = rgb(108, 74, 52)
local WOOD_DARK = rgb(68, 44, 32)
local VELLUM_PAGE = rgb(238, 230, 214)

local GOLD_LIGHT = rgb(252, 228, 162)
local SILVER_LIGHT = rgb(220, 236, 255)
local VIOLET_LIGHT = rgb(172, 98, 255)
local VIOLET_CORE = rgb(230, 190, 255)
local CYAN_STAR = rgb(124, 216, 255)

local ABYSS_Y = -36

-- Floor 45's 24 landmark footprints (tight, cohesive circular Observatory inside 900 x 795 room).
-- Every non-straddling piece rests on a solid circular terrace or outer crescent alcove, facing inward,
-- completely clear of the 204 x 152 boss dais, portals (Z = -292), all 26 lanes and all 8 camps.
AstralFloor45.Landmarks = table.freeze({
	-- 1–2. The Great Telescope (colossal centrepiece: Y=166 + Top=187.5 -> 285.5 >= 285 studs above Apex!)
	{ Id = "GreatTelescopeMount", X = 0, Z = -346, Y = 68, HalfX = 30.0, HalfZ = 30.0, Top = 111.4, Straddles = true },
	{ Id = "GreatTelescopeTube", X = 0, Z = -346, Y = 166, HalfX = 25.0, HalfZ = 45.0, Top = 187.5, Straddles = true },
	-- 3. Open-ribbed Observatory Dome framing the circular dais & Great Telescope from behind
	{ Id = "ObservatoryDomeRibs", X = 0, Z = -312, Y = 68, HalfX = 81.5, HalfZ = 46.8, Top = 141.9, Straddles = true },
	-- 4–5. Colossal Brass Azimuth Rings straddling BOTH straight glowing sapphire-cyan Ring Stairs at Z = -228!
	{ Id = "WestAzimuthRing", X = -155, Z = -228, Y = 57, HalfX = 16.2, HalfZ = 4.2, Top = 36.4, Straddles = true },
	{ Id = "EastAzimuthRing", X = 155, Z = -228, Y = 58, HalfX = 16.2, HalfZ = 4.2, Top = 36.4, Straddles = true },
	-- 6. The Rift Eye vortex swirling deep in the Rift chasm (Y = -35, directly under Middle Suture & Overlook)
	{ Id = "RiftEyeVoid", X = 0, Z = -34, Y = -35, HalfX = 34.5, HalfZ = 34.5, Top = 6.1 },
	-- 7–8. Dais Outer Meridian Footings flush along the southern circular arc of Observing Floor (R = 97 < 104!)
	{ Id = "MeridianFootingW", X = -47, Z = -143, Y = 68, HalfX = 19.6, HalfZ = 4.2, Top = 6.8, Straddles = true },
	{ Id = "MeridianFootingE", X = 47, Z = -143, Y = 68, HalfX = 19.6, HalfZ = 4.2, Top = 6.8, Straddles = true },
	-- 9. Rift Overlook cantilevered balcony with Grand Indexer's overturned chair jutting over the Rift Vortex
	{ Id = "RiftOverlookDeck", X = -52, Z = -108, Y = 20, HalfX = 7.2, HalfZ = 7.8, Top = 12.7 },
	-- 10–11. West & East Transit Towers on solid circular rocky flank crags (doors facing INWARD!)
	{ Id = "WestTransitTower", X = -304, Z = -56, Y = 30, HalfX = 13.0, HalfZ = 13.0, Top = 34.2 },
	{ Id = "EastTransitTower", X = 322, Z = -128, Y = 42, HalfX = 13.0, HalfZ = 13.0, Top = 34.2 },
	-- 12–13. Meridian Transit Instruments flanking the towers on solid circular bays
	{ Id = "WestTransitInstrument", X = -298, Z = -18, Y = 30, HalfX = 5.5, HalfZ = 6.5, Top = 14.9 },
	{ Id = "EastTransitInstrument", X = 324, Z = -90, Y = 42, HalfX = 5.5, HalfZ = 6.5, Top = 14.9 },
	-- 14–15. Lens Gallery grinding benches on solid circular north alcove, all lenses turned toward the Rift Eye
	{ Id = "LensGalleryBenchA", X = 80, Z = -96, Y = 34, HalfX = 5.8, HalfZ = 2.4, Top = 9.4 },
	{ Id = "LensGalleryBenchB", X = 104, Z = -96, Y = 34, HalfX = 5.8, HalfZ = 2.4, Top = 9.4 },
	-- 16. Fallen Orrery on Orrery Crest's circular outer balcony
	{ Id = "OrreryCrestFallen", X = 332, Z = -278, Y = 48, HalfX = 12.8, HalfZ = 10.8, Top = 20.8 },
	-- 17. Grand Star-Lectern on Lectern's solid circular west alcove (open book facing EAST!)
	{ Id = "StarLecternGrand", X = -184, Z = 44, Y = 20, HalfX = 8.5, HalfZ = 8.5, Top = 10.0 },
	-- 18. Recessed glowing indigo Star-Ink Pool beside Ink
	{ Id = "InkPoolSpill", X = -146, Z = 148, Y = 14, HalfX = 7.0, HalfZ = 7.0, Top = 3.9 },
	-- 19. Fallen Catalogue toppled cabinet range on Fallen's solid circular east alcove (spilling NW into Rift!)
	{ Id = "FallenCatalogueRange", X = 196, Z = 144, Y = 9, HalfX = 12.8, HalfZ = 9.6, Top = 10.1 },
	-- 20. Proof Room press & blank sheet table on Proof's solid south alcove (facing NORTH!)
	{ Id = "ProofRoomPress", X = 66, Z = 104, Y = 19, HalfX = 7.0, HalfZ = 2.8, Top = 6.8 },
	-- 21–23. Crystallised Starlight Rift Lips embedded in dark cliff flanks along the diagonal tear
	{ Id = "WestRiftLipCrystal", X = -308, Z = -200, Y = -22, HalfX = 12.8, HalfZ = 7.4, Top = 13.7 },
	{ Id = "MidRiftLipCrystal", X = -92, Z = -40, Y = -22, HalfX = 12.8, HalfZ = 7.4, Top = 13.7 },
	{ Id = "EastRiftLipCrystal", X = 310, Z = 96, Y = -22, HalfX = 12.8, HalfZ = 7.4, Top = 13.7 },
	-- 24. The Last Lamp at Sanctuary (still warm gold, still steady!)
	{ Id = "TheLastLampPost", X = 24, Z = 338, Y = 8, HalfX = 2.0, HalfZ = 2.4, Top = 12.6 },
}) :: { Landmark }

local function safeTag(inst: Instance?, tagName: string)
	if inst then
		pcall(function()
			CollectionService:AddTag(inst, tagName)
		end)
	end
end

function AstralFloor45.Build(ctx: any)
	local H = InfernalFoundry.Helpers(ctx)
	local P = H.P
	local _boxAt, lump, light, piece, noCollide = H.boxAt, H.lump, H.light, H.piece, H.noCollide
	local function boxAt(name: string, cf: CFrame, size: Vector3, color: Color3, mat: Enum.Material, trans: number?): Part
		return _boxAt(name, size, cf, color, mat, trans)
	end

	local lightsUsed = 0
	local emittersUsed = 0
	local function addLight(p: Instance?, color: Color3, brightness: number, range: number)
		if p and lightsUsed < 14 then
			lightsUsed += 1
			light(p, color, brightness, range)
		end
	end
	local function pin(m: Instance?)
		if m then m:SetAttribute("OnTerrain", true) end
	end
	local function makeDecor(m: Instance?)
		if not m then return end
		noCollide(m)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.CastShadow = false
				d:SetAttribute("SolidScenery", false)
			end
		end
	end
	local function tagDetail(m: Instance?)
		if not m then return end
		makeDecor(m)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				safeTag(d, "TowerDetail")
			end
		end
	end

	local function placeKitScaled(groupName: string, x: number, y: number, z: number, yawDeg: number, kitName: string, scale: Vector3, override: any?, fallback: ((cf: CFrame) -> ())?): Instance?
		local prop: Instance? = nil
		ctx.group(groupName, function()
			prop = ctx.current()
			local cf = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yawDeg), 0)
			if ctx.has(kitName) then
				ctx.kitAt(kitName, cf, scale, override)
			elseif fallback then
				fallback(cf)
			end
		end)
		pin(prop)
		return prop
	end

	local function addLightCurtain(name: string, p0: Vector3, p1: Vector3, height0: number, height1: number, col0: Color3, col1: Color3, alpha: number, faceCam: boolean?, taperEnds: boolean?)
		local mid = (p0 + p1) * 0.5
		local anchor = ctx.block(name .. "_Anchor", V(1, 1, 1), mid, col0, Mat.SmoothPlastic, nil, 1)
		anchor.CanCollide, anchor.CanQuery, anchor.CanTouch, anchor.CastShadow = false, false, false, false
		anchor:SetAttribute("SolidScenery", false)
		anchor:SetAttribute("ConjunctionGlyph", true)
		safeTag(anchor, "ConjunctionGlyph")
		local a0 = Instance.new("Attachment")
		a0.Position = p0 - mid
		a0.Axis = V(0, 1, 0)
		a0.SecondaryAxis = V(0, 0, 1)
		a0.Parent = anchor
		local a1 = Instance.new("Attachment")
		a1.Position = p1 - mid
		a1.Axis = V(0, 1, 0)
		a1.SecondaryAxis = V(0, 0, 1)
		a1.Parent = anchor
		local b = Instance.new("Beam")
		b.Name = name
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.Width0 = height0
		b.Width1 = height1
		b.FaceCamera = faceCam == true
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Segments = 24
		b.Color = ColorSequence.new(col0, col1)
		if taperEnds then
			b.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0.0, 1.0),
				NumberSequenceKeypoint.new(0.15, math.min(0.96, alpha + 0.22)),
				NumberSequenceKeypoint.new(0.35, math.min(0.94, alpha + 0.06)),
				NumberSequenceKeypoint.new(0.50, alpha),
				NumberSequenceKeypoint.new(0.65, math.min(0.94, alpha + 0.06)),
				NumberSequenceKeypoint.new(0.85, math.min(0.96, alpha + 0.22)),
				NumberSequenceKeypoint.new(1.0, 1.0),
			})
		else
			b.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0.0, math.min(0.96, alpha + 0.14)),
				NumberSequenceKeypoint.new(0.12, alpha),
				NumberSequenceKeypoint.new(0.88, alpha),
				NumberSequenceKeypoint.new(1.0, math.min(0.96, alpha + 0.14)),
			})
		end
		b.Parent = anchor
	end

	local function riftMistEmitter(pos: Vector3, rate: number)
		if emittersUsed >= 14 then return end
		emittersUsed += 1
		local anchor = ctx.block("RiftMistAnchor", V(1, 1, 1), pos, VIOLET_LIGHT, Mat.SmoothPlastic, nil, 1)
		anchor.CanCollide, anchor.CanQuery, anchor.CastShadow = false, false, false
		anchor:SetAttribute("ConjunctionGlyph", true)
		safeTag(anchor, "ConjunctionGlyph")
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "RiftVioletMist"
		pe.Color = ColorSequence.new(rgb(138, 66, 232), rgb(206, 152, 255))
		pe.LightEmission = 0.85
		pe.LightInfluence = 0
		pe.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 6.0),
			NumberSequenceKeypoint.new(0.45, 14.0),
			NumberSequenceKeypoint.new(1, 20.0),
		})
		pe.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.0),
			NumberSequenceKeypoint.new(0.25, 0.72),
			NumberSequenceKeypoint.new(0.70, 0.80),
			NumberSequenceKeypoint.new(1, 1.0),
		})
		pe.Lifetime = NumberRange.new(3.5, 5.8)
		pe.Rate = rate
		pe.Speed = NumberRange.new(3.2, 6.5)
		pe.SpreadAngle = Vector2.new(32, 32)
		pe.RotSpeed = NumberRange.new(-18, 18)
		pe.Acceleration = V(0, 1.8, 0)
		pe.Parent = anchor
	end

	local function pageEmitter(pos: Vector3, rate: number)
		if emittersUsed >= 14 then return end
		emittersUsed += 1
		local anchor = ctx.block("PageDriftAnchor", V(1, 1, 1), pos, VELLUM_PAGE, Mat.SmoothPlastic, nil, 1)
		anchor.CanCollide, anchor.CanQuery, anchor.CastShadow = false, false, false
		anchor:SetAttribute("ConjunctionPageEmitter", true)
		safeTag(anchor, "ConjunctionPageEmitter")
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "AstralPages"
		pe.Color = ColorSequence.new(rgb(238, 230, 214), rgb(186, 134, 255))
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(0.5, 1.1), NumberSequenceKeypoint.new(1, 0.35) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.8, 0.35), NumberSequenceKeypoint.new(1, 1) })
		pe.Lifetime = NumberRange.new(2.8, 4.6)
		pe.Rate = rate
		pe.Speed = NumberRange.new(2.2, 5.0)
		pe.SpreadAngle = Vector2.new(65, 65)
		pe.RotSpeed = NumberRange.new(-90, 90)
		pe.Acceleration = V(0, -1.6, 0)
		pe.Parent = anchor
	end

	local function buildRockOutcrop(pos: Vector3, size: Vector3, yawDeg: number)
		local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(yawDeg), 0)
		boxAt("CliffCore", cf * CFrame.new(0, size.Y * 0.35, 0) * CFrame.Angles(math.rad(6), math.rad(10), math.rad(-5)),
			V(size.X, size.Y * 0.70, size.Z), CLIFF_ROCK, Mat.Slate)
		boxAt("CliffShoulderA", cf * CFrame.new(-size.X * 0.24, size.Y * 0.48, size.Z * 0.14) * CFrame.Angles(math.rad(-8), math.rad(22), math.rad(9)),
			V(size.X * 0.62, size.Y * 0.54, size.Z * 0.64), CLIFF_MID, Mat.Slate)
		boxAt("CliffShoulderB", cf * CFrame.new(size.X * 0.24, size.Y * 0.42, -size.Z * 0.12) * CFrame.Angles(math.rad(8), math.rad(-18), math.rad(-9)),
			V(size.X * 0.56, size.Y * 0.48, size.Z * 0.60), CLIFF_DEEP, Mat.Slate)
		boxAt("CliffCrest", cf * CFrame.new(0, size.Y * 0.74, 0) * CFrame.Angles(math.rad(-4), math.rad(14), math.rad(5)),
			V(size.X * 0.48, size.Y * 0.36, size.Z * 0.48), CLIFF_ROCK, Mat.Slate)
	end

	local function streetLamp(pos: Vector3, col: Color3, emitLight: boolean?)
		ctx.cyl("ObsLampBase", pos + V(0, 0.9, 0), 0.75, 1.8, STONE_LIGHT, Mat.Slate)
		ctx.cyl("ObsLampShaft", pos + V(0, 5.2, 0), 0.26, 7.6, rgb(42, 46, 66), Mat.Metal)
		boxAt("ObsLampCap", CFrame.new(pos + V(0, 9.8, 0)), V(1.5, 0.42, 1.5), BRASS_AGED, Mat.Metal)
		local bulb = lump("ObsLampBulb", pos + V(0, 9.0, 0), V(1.3, 1.65, 1.3), col, Mat.Neon)
		bulb:SetAttribute("ConjunctionLamp", true)
		safeTag(bulb, "ConjunctionLamp")
		if emitLight then
			addLight(bulb, col, 1.5, 52)
		end
	end

	local fenceColliders: { BasePart } = {}
	local function enableFences()
		for _, c in fenceColliders do
			c.CanCollide = true
			c.CanQuery = true
		end
		table.clear(fenceColliders)
	end

	local function balustradeSpan(x0: number, z0: number, x1: number, z1: number, y: number, lampEvery: number?, warmGold: boolean?)
		local a, b = V(x0, y, z0), V(x1, y, z1)
		local len = (b - a).Magnitude
		if len < 4 then return end
		local mid = (a + b) * 0.5
		local cf = CFrame.lookAt(mid, b)
		boxAt("ObsBalWall", cf * CFrame.new(0, 1.35, 0), V(1.4, 2.7, len), WALL_FACE, Mat.Slate)
		boxAt("ObsBalBase", cf * CFrame.new(0, 0.35, 0), V(1.8, 0.7, len + 0.4), STONE_DARK, Mat.Slate)
		boxAt("ObsBalCap", cf * CFrame.new(0, 2.85, 0), V(1.75, 0.42, len + 0.4), STONE_LIGHT, Mat.Slate)
		boxAt("ObsBalTrim", cf * CFrame.new(0, 3.14, 0), V(1.15, 0.24, len), BRASS_AGED, Mat.Metal)
		local col = boxAt("ObsBalCollider", cf * CFrame.new(0, 1.8, 0), V(1.5, 3.6, len + 0.4), WALL_FACE, Mat.Slate, 1)
		table.insert(fenceColliders, col)
		local posts = math.max(2, math.floor(len / 18))
		for i = 0, posts do
			local pt = a:Lerp(b, i / posts)
			local isEnd = (i == 0 or i == posts)
			local pw = if isEnd then 2.3 else 1.85
			local ph = if isEnd then 3.8 else 3.3
			boxAt("ObsBalPillar", CFrame.new(pt + V(0, ph * 0.5, 0)), V(pw, ph, pw), STONE_LIGHT, Mat.Slate)
			boxAt("ObsBalPillarCap", CFrame.new(pt + V(0, ph + 0.22, 0)), V(pw + 0.35, 0.38, pw + 0.35), GOLD_BRIGHT, Mat.Metal)
			if lampEvery and lampEvery > 0 and i > 0 and i < posts and (i % lampEvery == 0) then
				local lCol = if warmGold then GOLD_LIGHT else VIOLET_CORE
				ctx.cyl("ObsBalLampPost", pt + V(0, ph + 3.0, 0), 0.28, 5.8, rgb(40, 44, 64), Mat.Metal)
				boxAt("ObsBalLampHood", CFrame.new(pt + V(0, ph + 6.5, 0)), V(1.4, 0.4, 1.4), BRASS_AGED, Mat.Metal)
				local bulb = lump("ObsBalLampGlow", pt + V(0, ph + 5.7, 0), V(1.2, 1.5, 1.2), lCol, Mat.Neon)
				bulb:SetAttribute("ConjunctionLamp", true)
				safeTag(bulb, "ConjunctionLamp")
			end
		end
	end

	-- Collect every bridge & alcove exit angle per platform so curved balustrades stay 100% open at every entry!
	local openAngles: { [string]: { { number } } } = {}
	local function addOpenAngle(platId: string, ang: number, halfSpanRad: number)
		local list = openAngles[platId]
		if not list then
			list = {}
			openAngles[platId] = list
		end
		table.insert(list, { ang, halfSpanRad })
	end
	local function angleBlocked(list: { { number } }?, ang: number): boolean
		if not list then return false end
		for _, pair in list do
			local diff = math.atan2(math.sin(ang - pair[1]), math.cos(ang - pair[1]))
			if math.abs(diff) < pair[2] then
				return true
			end
		end
		return false
	end
	for _, link in ctx.layout.Links do
		local pA, pB = P[link.From], P[link.To]
		if pA and pB then
			local angA = math.atan2(link.AZ - pA.Z, link.AX - pA.X)
			local angB = math.atan2(link.BZ - pB.Z, link.BX - pB.X)
			local rA = math.max(pA.Width, pA.Depth) * 0.5 + 2
			local rB = math.max(pB.Width, pB.Depth) * 0.5 + 2
			-- Exact chord half-angle for the bridge width + clearance so NO balustrade pillar ever clips a bridge!
			local halfW = link.Width * 0.5 + 3.0
			addOpenAngle(link.From, angA, math.asin(math.min(0.95, halfW / math.max(rA, 18))) + 0.08)
			addOpenAngle(link.To, angB, math.asin(math.min(0.95, halfW / math.max(rB, 18))) + 0.08)
		end
	end
	-- Also keep curved openings cleanly clear where circular outer alcoves & balconies join their parent terraces!
	local alcoveJoins = {
		{ "Apex", 0, -342, 0.58 },
		{ "WestGallery", -268, 108, 0.62 },
		{ "Ink", -146, 148, 0.68 },
		{ "Lectern", -184, 44, 0.70 },
		{ "WestBastion", -300, -40, 0.72 },
		{ "EastBastion", 318, -112, 0.72 },
		{ "Lens", 96, -104, 0.70 },
		{ "Orrery", 330, -276, 0.70 },
		{ "EastGallery", 298, 26, 0.62 },
		{ "Fallen", 194, 144, 0.70 },
		{ "Proof", 66, 104, 0.72 },
		{ "Overlook", -52, -108, 0.42 },
	}
	for _, aj in alcoveJoins do
		local plat = P[aj[1]]
		if plat then
			addOpenAngle(aj[1], math.atan2(aj[3] - plat.Z, aj[2] - plat.X), aj[4])
		end
	end

	-- Sculpted CIRCULAR Observatory island: beveled stone cornice, brass meridian ring, inlaid compass,
	-- craggy multi-tiered obsidian rock cliff plunging into the abyss, and curved open-mouth balustrade!
	local function buildCircularObservatoryIsle(id: string, x: number, y: number, z: number, radius: number, seed: number, solidWalkable: boolean?, skipBalustrade: boolean?, customOpen: { { number } }?)
		local bottomY = ABYSS_Y + 1.0
		local totalH = math.max(24.0, y - bottomY)
		ctx.group("AstralIsleDeck", function()
			local solidTop: Part? = nil
			if solidWalkable then
				solidTop = ctx.cyl(id .. "WalkCap", V(x, y - 1.2, z), radius, 2.4, STONE_TOP, Mat.Slate)
			end
			-- Beveled stone rim cornice & antique brass frieze ring (eliminates sharp edges completely!)
			ctx.cyl(id .. "StoneCornice", V(x, y - 2.35, z), radius + 1.3, 1.9, STONE_LIGHT, Mat.Slate)
			ctx.ring(id .. "BrassFrieze", V(x, y - 3.35, z), radius + 1.45, 0.55, BRASS_AGED, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 32)
			ctx.cyl(id .. "LapisCollar", V(x, y - 4.8, z), radius + 0.3, 2.4, LAPIS_DARK, Mat.Slate)

			-- Inlaid brass floor rings & flagstone rosette (zero flat bare grey slabs!)
			if id ~= "Apex" then
				ctx.ring(id .. "FloorRingOuter", V(x, y + 0.08, z), radius - 3.2, 0.38, BRASS_AGED, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 28)
				ctx.ring(id .. "FloorRingInner", V(x, y + 0.08, z), radius * 0.52, 0.28, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 22)
				ctx.cyl(id .. "CenterInlay", V(x, y + 0.05, z), radius * 0.50, 0.07, rgb(96, 102, 132), Mat.Slate)
			end

			-- Tapered craggy obsidian mountain core + organic angled rock buttresses plunging into space!
			local hullH = totalH - 5.2
			local h1, h2 = hullH * 0.48, hullH * 0.54
			ctx.cyl(id .. "CliffUpper", V(x, y - 5.4 - h1 * 0.5, z), radius * 0.94, h1, CLIFF_ROCK, Mat.Slate)
			ctx.cyl(id .. "CliffLower", V(x, bottomY + h2 * 0.5, z), radius * 0.72, h2, CLIFF_DEEP, Mat.Slate)

			local opens = customOpen or openAngles[id]
			local nCrags = math.clamp(math.floor(radius / 5.5), 7, 16)
			for k = 0, nCrags - 1 do
				local a = (k / nCrags) * math.pi * 2 + (seed % 7) * 0.14
				if angleBlocked(opens, a) then continue end
				local dist = radius * (0.86 + ((k * 3 + seed) % 3) * 0.06)
				local cx = x + math.cos(a) * dist
				local cz = z + math.sin(a) * dist
				local cw = math.max(10, radius * 0.34)
				local ch = hullH * (0.72 + ((k + seed) % 3) * 0.11)
				local ccf = CFrame.new(V(cx, y - 5.2 - ch * 0.46, cz))
					* CFrame.Angles(0, -a, 0)
					* CFrame.Angles(0, 0, math.rad(10 + (k % 3) * 3))
				boxAt(id .. "CliffSpur", ccf, V(cw * 0.72, ch, cw), if k % 2 == 0 then CLIFF_ROCK else CLIFF_MID, Mat.Slate)
			end

			-- Curved stone-and-brass balustrade wrapping EVERY non-bridge arc!
			if not skipBalustrade then
				local segs = math.clamp(math.floor(radius * 0.75), 18, 44)
				local rBal = radius - 1.15
				local segLen = (2 * math.pi * rBal) / segs + 0.45
				for k = 0, segs - 1 do
					local a = (k + 0.5) / segs * math.pi * 2
					if angleBlocked(opens, a) then continue end
					local bx = x + math.cos(a) * rBal
					local bz = z + math.sin(a) * rBal
					local tangent = V(-math.sin(a), 0, math.cos(a))
					local bcf = CFrame.lookAt(V(bx, y, bz), V(bx, y, bz) + tangent)
					boxAt(id .. "BalWall", bcf * CFrame.new(0, 1.35, 0), V(1.35, 2.7, segLen), WALL_FACE, Mat.Slate)
					boxAt(id .. "BalCap", bcf * CFrame.new(0, 2.85, 0), V(1.75, 0.40, segLen + 0.2), STONE_LIGHT, Mat.Slate)
					boxAt(id .. "BalTrim", bcf * CFrame.new(0, 3.12, 0), V(1.1, 0.22, segLen), BRASS_AGED, Mat.Metal)
					local col = boxAt(id .. "BalCollider", bcf * CFrame.new(0, 1.8, 0), V(1.4, 3.6, segLen + 0.2), WALL_FACE, Mat.Slate, 1)
					table.insert(fenceColliders, col)
					if k % 3 == 0 then
						boxAt(id .. "BalPier", bcf * CFrame.new(0, 1.75, 0), V(2.0, 3.5, 2.0), STONE_LIGHT, Mat.Slate)
						boxAt(id .. "BalFinial", bcf * CFrame.new(0, 3.68, 0), V(2.25, 0.36, 2.25), GOLD_BRIGHT, Mat.Metal)
					end
				end
			end

			makeDecor(ctx.current())
			enableFences()
			if solidTop then
				solidTop.CanCollide = true
				solidTop.CanQuery = true
				solidTop.CanTouch = true
			end
			pin(ctx.current())
		end)
	end

	-- Sculpted CIRCULAR suspended timber-and-brass Rift Suture Hubs (SutureMid, SutureW, Overlook):
	-- beveled oak cornice, brass hoop band, crossed heavy timber cradle, angled diagonal anchor chains,
	-- and curved stitch-laced timber railings opening cleanly onto every bridge & Overlook balcony!
	local function buildCircularSutureHub(id: string, x: number, y: number, z: number, radius: number)
		ctx.group("AstralIsleDeck", function()
			-- Beveled oak cornice, antique brass hoop band & inlaid timber compass ring
			ctx.cyl(id .. "OakCornice", V(x, y - 1.9, z), radius + 1.1, 1.8, WOOD_DARK, Mat.Wood)
			ctx.ring(id .. "BrassHoop", V(x, y - 2.65, z), radius + 1.3, 0.52, BRASS_AGED, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 28)
			ctx.ring(id .. "DeckRingOuter", V(x, y + 0.07, z), radius - 2.8, 0.36, BRASS_AGED, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 24)
			ctx.ring(id .. "DeckRingInner", V(x, y + 0.07, z), radius * 0.48, 0.28, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 18)

			-- Heavy crossed underside timber cradle beams + central iron-brass keel hub
			local beamLen = radius * 1.85
			boxAt(id .. "CradleBeamX", CFrame.new(V(x, y - 3.6, z)), V(beamLen, 1.8, 2.8), WOOD_DARK, Mat.Wood)
			boxAt(id .. "CradleBeamZ", CFrame.new(V(x, y - 3.6, z)), V(2.8, 1.8, beamLen), WOOD_DARK, Mat.Wood)
			ctx.cyl(id .. "CradleKeel", V(x, y - 4.4, z), radius * 0.42, 2.4, rgb(44, 34, 32), Mat.Wood)
			ctx.ring(id .. "CradleKeelBand", V(x, y - 4.6, z), radius * 0.44, 0.45, BRASS_AGED, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 18)

			-- Curved timber-and-brass suture railings with glowing golden stitch-lacing on every non-bridge arc!
			local opens = openAngles[id]
			local segs = 22
			local rBal = radius - 1.05
			local segLen = (2 * math.pi * rBal) / segs + 0.35
			for k = 0, segs - 1 do
				local a = (k + 0.5) / segs * math.pi * 2
				if angleBlocked(opens, a) then continue end
				local bx = x + math.cos(a) * rBal
				local bz = z + math.sin(a) * rBal
				local tangent = V(-math.sin(a), 0, math.cos(a))
				local bcf = CFrame.lookAt(V(bx, y, bz), V(bx, y, bz) + tangent)
				boxAt(id .. "SutCurb", bcf * CFrame.new(0, 0.45, 0), V(1.25, 0.90, segLen), WOOD_DARK, Mat.Wood)
				boxAt(id .. "SutTopRail", bcf * CFrame.new(0, 3.15, 0), V(0.65, 0.45, segLen), BRASS_AGED, Mat.Metal)
				boxAt(id .. "SutMidChain", bcf * CFrame.new(0, 1.80, 0), V(0.32, 0.32, segLen), GOLD_BRIGHT, Mat.Metal)
				local col = boxAt(id .. "SutRailCollider", bcf * CFrame.new(0, 1.8, 0), V(1.3, 3.6, segLen + 0.2), WOOD_DARK, Mat.Wood, 1)
				table.insert(fenceColliders, col)
				local stitch = boxAt(id .. "SutStitch", bcf * CFrame.new(0, 2.15, 0) * CFrame.Angles(math.rad(28), 0, 0), V(0.24, 0.24, segLen * 0.92), GOLD_LIGHT, Mat.Neon, 0.12)
				stitch:SetAttribute("ConjunctionGlyph", true)
				if k % 2 == 0 then
					boxAt(id .. "SutPost", bcf * CFrame.new(0, 1.85, 0), V(1.3, 3.7, 1.3), WOOD_WARM, Mat.Wood)
					boxAt(id .. "SutPostCap", bcf * CFrame.new(0, 3.82, 0), V(1.55, 0.40, 1.55), GOLD_BRIGHT, Mat.Metal)
				end
			end

			makeDecor(ctx.current())
			enableFences()
			pin(ctx.current())
		end)
	end

	local function buildStandingBookcase(pos: Vector3, yawDeg: number, scale: number)
		local s = scale
		local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(yawDeg), 0)
		local w, h, d = 11.8 * s, 14.2 * s, 3.2 * s
		boxAt("CaseBack", cf * CFrame.new(0, h * 0.5, -d * 0.36), V(w, h, 0.7 * s), WOOD_DARK, Mat.Wood)
		for _, sx in { -1, 1 } do
			boxAt("CaseSide", cf * CFrame.new(sx * (w * 0.5 - 0.5 * s), h * 0.5, 0), V(1.0 * s, h, d), WOOD_WARM, Mat.Wood)
		end
		boxAt("CaseCrown", cf * CFrame.new(0, h + 0.4 * s, 0.2 * s), V(w + 1.2 * s, 1.0 * s, d + 0.7 * s), WOOD_WARM, Mat.Wood)
		boxAt("CaseCrownTrim", cf * CFrame.new(0, h + 0.95 * s, 0.2 * s), V(w + 1.4 * s, 0.32 * s, d + 0.9 * s), BRASS_AGED, Mat.Metal)
		boxAt("CasePlinth", cf * CFrame.new(0, 0.55 * s, 0), V(w + 0.5 * s, 1.1 * s, d + 0.3 * s), WOOD_DARK, Mat.Wood)
		for row = 0, 3 do
			local ry = (2.1 + row * 2.9) * s
			boxAt("CaseShelf", cf * CFrame.new(0, ry, 0), V(w - 1.2 * s, 0.38 * s, d - 0.5 * s), WOOD_WARM, Mat.Wood)
			for b = 0, 3 do
				local bx = (-w * 0.34 + b * (w * 0.22))
				local bh = (1.9 + ((row + b) % 3) * 0.24) * s
				local bCol = if (row + b) % 3 == 0 then rgb(124, 60, 48) elseif (row + b) % 3 == 1 then rgb(52, 70, 120) else rgb(148, 120, 68)
				boxAt("CaseBooks", cf * CFrame.new(bx, ry + bh * 0.5 + 0.2 * s, 0.22 * s), V(2.0 * s, bh, 1.7 * s), bCol, Mat.Wood)
			end
		end
	end

	local function buildWritingDesk(pos: Vector3, yawDeg: number)
		local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(yawDeg), 0)
		boxAt("DeskTop", cf * CFrame.new(0, 3.0, 0), V(9.2, 0.48, 4.6), WOOD_WARM, Mat.Wood)
		boxAt("DeskTrim", cf * CFrame.new(0, 2.72, 0), V(8.8, 0.24, 4.2), BRASS_AGED, Mat.Metal)
		for _, sx in { -4.0, 4.0 } do
			for _, sz in { -1.8, 1.8 } do
				boxAt("DeskLeg", cf * CFrame.new(sx, 1.5, sz), V(0.55, 3.0, 0.55), WOOD_DARK, Mat.Wood)
			end
		end
		boxAt("DeskPageA", cf * CFrame.new(-1.8, 3.30, 0.4) * CFrame.Angles(0, math.rad(14), 0), V(2.0, 0.12, 1.5), VELLUM_PAGE, Mat.Fabric)
		boxAt("DeskPageB", cf * CFrame.new(1.5, 3.30, -0.3) * CFrame.Angles(0, math.rad(-18), 0), V(2.2, 0.12, 1.6), VELLUM_PAGE, Mat.Fabric)
		boxAt("DeskTome", cf * CFrame.new(2.7, 3.55, 0.8) * CFrame.Angles(0, math.rad(8), 0), V(1.9, 0.65, 1.4), rgb(52, 68, 118), Mat.Wood)
		boxAt("DeskStool", cf * CFrame.new(0, 1.9, 3.3), V(2.2, 0.35, 2.2), WOOD_WARM, Mat.Wood)
		boxAt("DeskStoolBase", cf * CFrame.new(0, 0.95, 3.3), V(1.6, 1.8, 1.6), WOOD_DARK, Mat.Wood)
	end

	local function buildBench(pos: Vector3, yawDeg: number)
		local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(yawDeg), 0)
		boxAt("BenchSeat", cf * CFrame.new(0, 1.6, 0), V(8.0, 0.42, 2.3), WOOD_WARM, Mat.Wood)
		boxAt("BenchBack", cf * CFrame.new(0, 2.9, -0.95), V(8.0, 1.8, 0.35), WOOD_DARK, Mat.Wood)
		for _, sx in { -3.2, 3.2 } do
			boxAt("BenchLeg", cf * CFrame.new(sx, 0.85, 0), V(0.55, 1.7, 2.1), STONE_DARK, Mat.Slate)
		end
	end

	local function buildCrateCluster(pos: Vector3, yawDeg: number)
		local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(yawDeg), 0)
		for _, spec in {
			{ V(0, 1.4, 0), 2.8, 0 },
			{ V(3.1, 1.15, 0.5), 2.3, 18 },
			{ V(-2.8, 1.1, -0.5), 2.2, -16 },
			{ V(0.2, 3.9, -0.1), 2.2, 24 },
		} do
			local c = cf * CFrame.new(spec[1]) * CFrame.Angles(0, math.rad(spec[3]), 0)
			local sz = spec[2]
			boxAt("ArchiveCrate", c, V(sz, sz, sz), WOOD_WARM, Mat.Wood)
			boxAt("ArchiveCrateBand", c, V(sz + 0.14, 0.28, sz + 0.14), BRASS_AGED, Mat.Metal)
		end
	end

	local function buildVoidLantern(anchorPos: Vector3, dropLen: number, emitLight: boolean?)
		local endPos = anchorPos - V(0, dropLen, 0)
		ctx.cyl("VoidLanternChain", (anchorPos + endPos) * 0.5, 0.18, dropLen, BRASS_AGED, Mat.Metal)
		boxAt("VoidLanternCap", CFrame.new(endPos + V(0, 1.4, 0)), V(2.4, 0.65, 2.4), BRASS_AGED, Mat.Metal)
		local bulb = lump("VoidLanternCore", endPos, V(2.2, 3.0, 2.2), VIOLET_CORE, Mat.Neon)
		bulb:SetAttribute("ConjunctionLamp", true)
		safeTag(bulb, "ConjunctionLamp")
		boxAt("VoidLanternBase", CFrame.new(endPos - V(0, 1.6, 0)), V(2.0, 0.5, 2.0), BRASS_AGED, Mat.Metal)
		if emitLight then
			addLight(bulb, VIOLET_LIGHT, 2.1, 68)
		end
	end

	for _, lm in AstralFloor45.Landmarks do
		ctx.reserve(lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ))
	end

	-- =========================================================================
	-- A. DEEP STARRY COSMIC SPACE VOID, SWIRLING RIFT VORTEX & FLOATING ASTEROIDS
	-- =========================================================================
	ctx.group("AstralNebulaSea", function()
		boxAt("ObservatoryVoidFloor", CFrame.new(V(0, ABYSS_Y, -10)), V(1180, 0.6, 1100), rgb(7, 7, 20), Mat.SmoothPlastic, 0)

		-- Diagonal violet cosmic Rift energy channel running end-to-end beneath the three sutures!
		for idx, np in {
			{ 310, ABYSS_Y + 0.6, 108, 68, rgb(76, 36, 148), 0.58 },
			{ 200, ABYSS_Y + 0.7, 56, 88, rgb(96, 42, 182), 0.52 },
			{ 96, ABYSS_Y + 0.8, 8, 112, rgb(128, 54, 224), 0.44 },
			{ 0, ABYSS_Y + 1.0, -34, 138, rgb(162, 76, 252), 0.34 },
			{ -108, ABYSS_Y + 0.8, -76, 110, rgb(120, 50, 212), 0.46 },
			{ -208, ABYSS_Y + 0.7, -138, 94, rgb(92, 42, 178), 0.52 },
			{ -330, ABYSS_Y + 0.6, -184, 78, rgb(70, 34, 144), 0.58 },
		} do
			local disc = ctx.cyl("RiftChasmGlow_" .. idx, V(np[1], np[2], np[3]), np[4], 0.22, np[5], Mat.Neon)
			disc.Transparency = np[6]
		end

		-- Luminous layered swirling vortex whirlpool rings centred at the Rift Eye (0, -34)!
		local vx, vz = 0, -34
		for _, ringSpec in {
			{ 112, 0.25, rgb(118, 50, 212), 0.46 },
			{ 84, 0.30, rgb(154, 72, 246), 0.34 },
			{ 56, 0.35, rgb(194, 120, 255), 0.22 },
			{ 34, 0.40, rgb(232, 198, 255), 0.12 },
			{ 17, 0.48, rgb(18, 8, 40), 0.0 },
		} do
			local d = ctx.cyl("RiftVortexLayer", V(vx, ABYSS_Y + 1.2 + ringSpec[2], vz), ringSpec[1], 0.18, ringSpec[3], if ringSpec[4] == 0 then Mat.SmoothPlastic else Mat.Neon)
			d.Transparency = ringSpec[4]
			d:SetAttribute("ConjunctionGlyph", true)
			safeTag(d, "ConjunctionGlyph")
		end
		-- Floating white vellum pages spiralling upward out of the vortex!
		for k = 1, 28 do
			local ang = k * 0.58
			local rad = 22 + (k % 8) * 10.5
			local px = vx + math.cos(ang) * rad
			local pz = vz + math.sin(ang) * rad
			local py = ABYSS_Y + 4.5 + (k % 6) * 4.2
			boxAt("VortexDriftPage", CFrame.new(V(px, py, pz)) * CFrame.Angles(math.rad(-20), ang, math.rad(16)), V(2.8, 0.12, 2.0), VELLUM_PAGE, Mat.Fabric)
		end

		-- Dense cosmic starfield glittering across the entire deep space void!
		for i = 1, 220 do
			local sx = math.sin(i * 12.9898) * 440
			local sz = math.cos(i * 78.233) * 420 - 10
			local sSize = if i % 8 == 0 then 2.4 elseif i % 3 == 0 then 1.4 else 0.9
			local sCol = if i % 5 == 0 then GOLD_LIGHT elseif i % 3 == 0 then VIOLET_CORE else SILVER_LIGHT
			lump("VoidStarGlint", V(sx, ABYSS_Y + 0.9, sz), V(sSize, 0.24, sSize), sCol, Mat.Neon)
		end

		-- Floating outer dark-obsidian asteroid crags framing the space perimeter (sells the floating cosmic realm!)
		for i, rock in {
			{ -385, -18, 175, 42, 30, 34, 24 },
			{ -405, -8, 10, 48, 38, 36, -16 },
			{ -395, 10, -175, 52, 42, 38, 18 },
			{ -365, 22, -315, 44, 36, 34, -28 },
			{ 385, -18, 185, 44, 32, 34, -22 },
			{ 405, -4, 35, 50, 38, 36, 15 },
			{ 410, 14, -145, 52, 44, 38, -20 },
			{ 385, 28, -325, 46, 36, 36, 26 },
		} do
			buildRockOutcrop(V(rock[1], rock[2], rock[3]), V(rock[4], rock[5], rock[6]), rock[7])
			-- Subtle star-crystal flecks & luminous cosmic dust perched on each floating space asteroid
			local cCol = if i % 2 == 0 then CYAN_STAR else VIOLET_CORE
			local rcf = CFrame.new(V(rock[1], rock[2] + rock[5] * 0.72, rock[3])) * CFrame.Angles(math.rad(16), math.rad(rock[7]), math.rad(-14))
			boxAt("AsteroidCrystalA", rcf * CFrame.new(4, 3, 2), V(2.4, 8.5, 2.4), cCol, Mat.Neon, 0.18)
			boxAt("AsteroidCrystalB", rcf * CFrame.new(-5, 1.5, -3) * CFrame.Angles(0, 0, math.rad(28)), V(1.8, 6.2, 1.8), VIOLET_LIGHT, Mat.Neon, 0.24)
			if i % 2 == 0 then
				lump("OuterSpaceStar", V(rock[1], rock[2] + rock[5] + 18, rock[3]), V(2.2, 2.2, 2.2), if i % 4 == 0 then GOLD_LIGHT else VIOLET_CORE, Mat.Neon)
			end
		end

		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	-- =========================================================================
	-- B. SCULPTED CIRCULAR OBSERVATORY ISLES & SOLID CIRCULAR OUTER ALCOVES
	-- =========================================================================
	local roundIsles = {
		"Fallen", "WestGallery", "EastGallery", "Crossing",
		"Ink", "Lectern", "Proof",
		"WestBastion", "Lens", "EastBastion",
		"Orrery", "RiftLipW", "WestAnchor", "EastAnchor",
		"Apex",
	}
	for idx, id in roundIsles do
		local plat = P[id]
		if plat then
			local radius = math.max(plat.Width, plat.Depth) * 0.5 + 2
			buildCircularObservatoryIsle(id, plat.X, plat.Y, plat.Z, radius, idx * 17 + 5, false, false, nil)
		end
	end

	-- Sculpted circular suspended timber-and-brass Rift Suture Hubs (SutureMid, SutureW, Overlook)!
	for _, sId in { "SutureMid", "Overlook", "SutureW" } do
		local plat = P[sId]
		if plat then
			local radius = math.max(plat.Width, plat.Depth) * 0.5 + 2
			buildCircularSutureHub(sId, plat.X, plat.Y, plat.Z, radius)
		end
	end

	-- Solid 100%-walkable CIRCULAR outer Observatory alcoves (seamlessly overlapping parent circular terraces!)
	local function openTowardParent(ax: number, az: number, parentId: string, halfRad: number): { { number } }
		local pp = P[parentId]
		if not pp then return {} end
		return { { math.atan2(pp.Z - az, pp.X - ax), halfRad } }
	end
	buildCircularObservatoryIsle("ApexTelescopeRearBay", 0, 68, -342, 68, 201, true, true, nil)
	buildCircularObservatoryIsle("WestStacksAlcove", -268, 12, 108, 30, 202, true, false, openTowardParent(-268, 108, "WestGallery", 1.05))
	buildCircularObservatoryIsle("InkPoolsAlcove", -146, 14, 148, 22, 203, true, false, openTowardParent(-146, 148, "Ink", 1.10))
	buildCircularObservatoryIsle("StarLecternAlcove", -184, 20, 44, 30, 204, true, false, openTowardParent(-184, 44, "Lectern", 1.08))
	buildCircularObservatoryIsle("WestTowerCrag", -300, 30, -40, 36, 205, true, false, openTowardParent(-300, -40, "WestBastion", 1.15))
	buildCircularObservatoryIsle("EastTowerCrag", 318, 42, -112, 36, 206, true, false, openTowardParent(318, -112, "EastBastion", 1.15))
	buildCircularObservatoryIsle("LensGalleryAlcove", 96, 34, -104, 28, 207, true, false, openTowardParent(96, -104, "Lens", 1.10))
	buildCircularObservatoryIsle("OrreryCrestAlcove", 330, 48, -276, 32, 208, true, false, openTowardParent(330, -276, "Orrery", 1.08))
	buildCircularObservatoryIsle("EastStacksAlcove", 298, 25, 26, 30, 209, true, false, openTowardParent(298, 26, "EastGallery", 1.05))
	buildCircularObservatoryIsle("FallenCatalogueAlcove", 194, 9, 144, 26, 210, true, false, openTowardParent(194, 144, "Fallen", 1.12))
	buildCircularObservatoryIsle("ProofRoomAlcove", 66, 19, 104, 22, 211, true, false, openTowardParent(66, 104, "Proof", 1.18))

	-- =========================================================================
	-- C. ROUNDED STADIUM BASIN, ORNATE SANCTUARY & CIRCULAR APEX COMPASS DAIS
	-- =========================================================================
	local basin = P.Basin
	if basin then
		local by, bz = basin.Y, basin.Z
		local halfW, halfD = basin.Width * 0.5, basin.Depth * 0.5
		-- Rounded semicircular solid stone end-caps at BOTH ends of Basin (ZERO sharp 90-deg corners!)
		buildCircularObservatoryIsle("BasinWestCap", -halfW, by, bz, halfD, 301, true, false, { { 0, math.pi * 0.55 } })
		buildCircularObservatoryIsle("BasinEastCap", halfW, by, bz, halfD, 302, true, false, { { math.pi, math.pi * 0.55 } })

		ctx.group("AstralConcourseDeck", function()
			-- Sculpted rocky cliff foundation under Basin's central span
			local hullH = by - (ABYSS_Y + 1.0) - 2.4
			boxAt("BasinStoneCornice", CFrame.new(V(0, by - 1.8, bz)), V(basin.Width + 1.6, 2.0, basin.Depth + 2.2), STONE_LIGHT, Mat.Slate)
			boxAt("BasinBrassFrieze", CFrame.new(V(0, by - 2.95, bz)), V(basin.Width + 2.0, 0.50, basin.Depth + 2.6), BRASS_AGED, Mat.Metal)
			boxAt("BasinCliffBody", CFrame.new(V(0, by - 3.2 - hullH * 0.5, bz)), V(basin.Width - 2, hullH, basin.Depth - 2), CLIFF_ROCK, Mat.Slate)
			for rx = -halfW + 30, halfW - 30, 56 do
				buildRockOutcrop(V(rx, ABYSS_Y + 2, bz + halfD - 2), V(38, 32, 22), (rx * 0.3) % 30 - 15)
				buildRockOutcrop(V(rx, ABYSS_Y + 2, bz - halfD + 2), V(38, 32, 22), -(rx * 0.3) % 30 + 15)
			end

			-- Ornate central zodiac compass medallion inlaid on Basin!
			ctx.cyl("BasinCompassBase", V(0, by + 0.05, bz), 24.0, 0.07, LAPIS_DARK, Mat.Marble)
			ctx.ring("BasinCompassOuter", V(0, by + 0.11, bz), 23.6, 0.48, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 32)
			ctx.ring("BasinCompassInner", V(0, by + 0.11, bz), 14.0, 0.32, BRASS_AGED, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 24)
			boxAt("BasinMeridianX", CFrame.new(V(0, by + 0.09, bz)), V(basin.Width - 28, 0.08, 0.55), BRASS_AGED, Mat.Metal)
			boxAt("BasinMeridianZ", CFrame.new(V(0, by + 0.09, bz)), V(0.55, 0.08, basin.Depth - 14), BRASS_AGED, Mat.Metal)

			-- South & North balustrades with exact openings for Sanctuary and all 3 north bridges!
			local northZ = bz - halfD + 1.2
			local southZ = bz + halfD - 1.2
			balustradeSpan(-halfW + 2, southZ, -19, southZ, by, 3, true)
			balustradeSpan(19, southZ, halfW - 2, southZ, by, 3, true)
			streetLamp(V(-20, by, southZ - 2.2), GOLD_LIGHT, true)
			streetLamp(V(20, by, southZ - 2.2), GOLD_LIGHT, true)

			local gaps: { { number } } = {}
			for _, link in ctx.layout.Links do
				if link.From == "Basin" or link.To == "Basin" then
					local ax = if link.From == "Basin" then link.AX else link.BX
					local tz = if link.From == "Basin" then link.BZ else link.AZ
					if tz < bz then
						local hOpen = link.Width * 0.5 + 2.2
						table.insert(gaps, { ax - hOpen, ax + hOpen })
					end
				end
			end
			table.sort(gaps, function(g1, g2) return g1[1] < g2[1] end)
			local curX = -halfW + 2
			for _, g in gaps do
				if g[1] - curX >= 6 then
					balustradeSpan(curX, northZ, g[1], northZ, by, 3, false)
				end
				curX = math.max(curX, g[2])
			end
			if (halfW - 2) - curX >= 6 then
				balustradeSpan(curX, northZ, halfW - 2, northZ, by, 3, false)
			end

			-- Handcrafted reading vignettes along Basin's rounded ends & edge bays (strictly clear of BASIN_WEST/EAST camps!)
			buildBench(V(-54, by, southZ - 5.5), 180)
			buildBench(V(54, by, southZ - 5.5), 180)
			buildWritingDesk(V(-(halfW + 6), by, bz - 9), 90)
			buildWritingDesk(V(-(halfW + 6), by, bz + 10), 90)
			buildCrateCluster(V(-(halfW + 18), by, bz + 2), 20)
			buildWritingDesk(V(halfW + 6, by, bz - 7), -90)
			buildCrateCluster(V(halfW + 16, by, bz + 12), -24)
			streetLamp(V(-(halfW + 24), by, bz), GOLD_LIGHT, false)
			streetLamp(V(halfW + 24, by, bz), GOLD_LIGHT, false)

			makeDecor(ctx.current())
			enableFences()
			pin(ctx.current())
		end)
	end

	-- Ornate Sanctuary arrival platform foundation + rounded corner turrets + railings!
	local safe = P.Sanctuary
	if safe then
		ctx.group("AstralIsleDeck", function()
			local sy, sz = safe.Y, safe.Z
			local hw, hd = safe.Width * 0.5, safe.Depth * 0.5
			local hullH = sy - (ABYSS_Y + 1.0) - 2.4
			boxAt("SanctuaryCornice", CFrame.new(V(0, sy - 1.8, sz)), V(safe.Width + 1.8, 2.0, safe.Depth + 1.8), STONE_LIGHT, Mat.Slate)
			boxAt("SanctuaryBrassFrieze", CFrame.new(V(0, sy - 2.95, sz)), V(safe.Width + 2.2, 0.5, safe.Depth + 2.2), BRASS_AGED, Mat.Metal)
			boxAt("SanctuaryCliff", CFrame.new(V(0, sy - 3.2 - hullH * 0.5, sz)), V(safe.Width - 4, hullH, safe.Depth - 4), CLIFF_ROCK, Mat.Slate)
			for _, sx in { -1, 1 } do
				for _, fz in { -1, 1 } do
					ctx.cyl("SanctuaryCornerTurret", V(sx * hw, sy - 4, sz + fz * hd), 4.6, 16, STONE_LIGHT, Mat.Slate)
					ctx.cyl("SanctuaryCornerCap", V(sx * hw, sy + 4.3, sz + fz * hd), 5.0, 0.7, GOLD_BRIGHT, Mat.Metal)
				end
			end
			balustradeSpan(-hw + 3, sz - hd + 1.2, -18, sz - hd + 1.2, sy, 0, true)
			balustradeSpan(18, sz - hd + 1.2, hw - 3, sz - hd + 1.2, sy, 0, true)
			balustradeSpan(-hw + 1.2, sz - hd + 3, -hw + 1.2, sz + hd - 3, sy, 0, true)
			balustradeSpan(hw - 1.2, sz - hd + 3, hw - 1.2, sz + hd - 3, sy, 0, true)
			makeDecor(ctx.current())
			enableFences()
			pin(ctx.current())
		end)
	end

	-- Grand circular zodiac celestial compass inlaid flush across the 208-stud circular Observing Floor dais!
	ctx.group("ObservatoryMeridianLine", function()
		local ay, az = 68, -228
		ctx.cyl("DaisCompassOuter", V(0, ay + 0.05, az), 94.0, 0.08, rgb(36, 46, 84), Mat.Marble)
		ctx.cyl("DaisCompassMid", V(0, ay + 0.08, az), 66.0, 0.08, rgb(28, 38, 72), Mat.Marble)
		ctx.ring("DaisGoldRingRim", V(0, ay + 0.14, az), 98.0, 0.75, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 56)
		ctx.ring("DaisGoldRingOuter", V(0, ay + 0.14, az), 66.0, 0.55, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 44)
		ctx.ring("DaisGoldRingInner", V(0, ay + 0.14, az), 34.0, 0.42, BRASS_AGED, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 32)
		local line = boxAt("GoldMeridianLine", CFrame.new(V(0, ay + 0.15, az)), V(1.1, 0.12, 190), GOLD_BRIGHT, Mat.Metal)
		line:SetAttribute("ConjunctionGlyph", true)
		safeTag(line, "ConjunctionGlyph")
		local cross = boxAt("GoldMeridianCross", CFrame.new(V(0, ay + 0.15, az)), V(190, 0.12, 1.1), GOLD_BRIGHT, Mat.Metal)
		cross:SetAttribute("ConjunctionGlyph", true)
		safeTag(cross, "ConjunctionGlyph")
		for k = 0, 7 do
			local ang = k * math.pi / 4
			local spoke = boxAt("DaisCompassSpoke", CFrame.new(V(0, ay + 0.13, az)) * CFrame.Angles(0, ang, 0), V(0.55, 0.10, 188), BRASS_AGED, Mat.Metal)
			spoke:SetAttribute("ConjunctionGlyph", true)
			safeTag(spoke, "ConjunctionGlyph")
		end
		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	-- Floating carved corbel brackets directly under Azimuth Ring pedestals + hanging void lanterns (no void-floor pillars!)
	ctx.group("AstralIsleBalustrade", function()
		for _, spec in { { -155, 57 }, { 155, 58 } } do
			local rx, ry = spec[1], spec[2]
			for _, sz in { -1, 1 } do
				local pz = -228 + sz * 15.8
				boxAt("AzimuthCorbelCap", CFrame.new(V(rx, ry - 0.85, pz)), V(10.4, 1.5, 10.4), STONE_LIGHT, Mat.Slate)
				boxAt("AzimuthCorbelBrass", CFrame.new(V(rx, ry - 1.85, pz)), V(10.6, 0.45, 10.6), BRASS_AGED, Mat.Metal)
				boxAt("AzimuthCorbelTaper", CFrame.new(V(rx, ry - 3.4, pz)), V(7.6, 2.8, 7.6), WALL_FACE, Mat.Slate)
			end
		end

		-- Hanging purple void lanterns dangling beneath the three Rift sutures into the glowing chasm!
		buildVoidLantern(V(-220, 32, -108), 20, true)
		buildVoidLantern(V(-166, 30, -124), 24, false)
		buildVoidLantern(V(-14, 22, 34), 22, true)
		buildVoidLantern(V(78, 26, -24), 24, false)
		buildVoidLantern(V(192, 12, 74), 18, false)
		buildVoidLantern(V(-52, 24, -98), 20, false)

		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	-- =========================================================================
	-- D. LANDMARKS 1–5: GREAT TELESCOPE, OBSERVATORY DOME & TWIN AZIMUTH RINGS
	-- =========================================================================
	do
		local mount = AstralFloor45.Landmarks[1]
		local mm = placeKitScaled("AstralDome", mount.X, mount.Y :: number, mount.Z, -18, "GreatTelescopeMount", V(1.56, 1.56, 1.56), TELESCOPE_TINT, function(cf)
			boxAt("TelescopeMountBase", cf * CFrame.new(0, 56, 0), V(58, 112, 58), TELESCOPE_TINT.STONE.Color, Mat.Slate)
		end)
		noCollide(mm)
		if mm then addLight(H.glowOf(mm) or mm:FindFirstChildWhichIsA("BasePart", true), SILVER_LIGHT, 2.8, 130) end

		local tube = AstralFloor45.Landmarks[2]
		local mt = placeKitScaled("AstralDome", tube.X, tube.Y :: number, tube.Z, -18, "GreatTelescopeTube", V(1.04, 1.02, 1.04), TELESCOPE_TINT, function(cf)
			boxAt("TelescopeBarrel", cf * CFrame.new(0, 88, 0) * CFrame.Angles(math.rad(-26), 0, 0), V(28, 175, 28), TELESCOPE_TINT.METAL.Color, Mat.Metal)
		end)
		noCollide(mt)
		if mt then addLight(H.glowOf(mt) or mt:FindFirstChildWhichIsA("BasePart", true), SILVER_LIGHT, 2.5, 125) end

		local dome = AstralFloor45.Landmarks[3]
		local md = placeKitScaled("AstralDome", dome.X, dome.Y :: number, dome.Z, 0, "ObservatoryDomeRibs", V(1.26, 1.32, 1.18), DOME_TINT, function(cf)
			for i = -2, 2 do
				ctx.ring("ObservatoryRib", cf.Position + V(0, 40, 0), 76, 3.2, DOME_TINT.METAL.Color, Mat.Metal, CFrame.Angles(0, i * 0.42, 0), 0, math.pi, 16)
			end
		end)
		noCollide(md)
	end

	-- 4–5. Twin Brass Azimuth Rings straddling BOTH straight glowing sapphire-cyan Ring Stairs!
	for _, spec in { { AstralFloor45.Landmarks[4], 90 }, { AstralFloor45.Landmarks[5], -90 } } do
		local lm = spec[1]
		local ma = piece("AstralGateRing", lm.X, lm.Z, spec[2], "AzimuthRing", 1.10, RIFTWARD_45, function(cf)
			ctx.ring("AzimuthArc", cf.Position + V(0, 22, 0), 19, 2.4, GOLD_BRIGHT, Mat.Metal, nil, -0.3, math.pi + 0.3, 18)
		end, lm.Y)
		pin(ma)
		noCollide(ma)
		if ma then
			ma:SetAttribute("ConjunctionLamp", true)
			safeTag(ma, "ConjunctionLamp")
			addLight(H.glowOf(ma) or ma:FindFirstChildWhichIsA("BasePart", true), GOLD_LIGHT, 2.6, 95)
		end
	end

	-- =========================================================================
	-- E. LANDMARK 6: THE SWIRLING RIFT EYE & CLIFF-EMBEDDED CRYSTALLISED RIFT LIPS
	-- =========================================================================
	do
		local eye = AstralFloor45.Landmarks[6]
		local me = piece("AstralRiftEye", eye.X, eye.Z, 0, "RiftEyeMesh", 2.60, RIFT_EYE_TINT, function(cf)
			ctx.cyl("RiftEyeDisc", cf.Position + V(0, 2, 0), 64, 3.5, VIOLET_LIGHT, Mat.Neon)
		end, ABYSS_Y + 1.0)
		pin(me)
		noCollide(me)
		if me then
			me:SetAttribute("ConjunctionRiftEye", true)
			safeTag(me, "ConjunctionRiftEye")
			addLight(H.glowOf(me) or me:FindFirstChildWhichIsA("BasePart", true), VIOLET_LIGHT, 3.2, 140)
		end
		pageEmitter(V(eye.X, ABYSS_Y + 12, eye.Z), 7)

		-- Crystallised violet Rift Lip crags embedded into jagged dark-basalt chasm cliff walls (NEVER floating loose!)
		ctx.group("AstralIsleDeck", function()
			for _, cr in {
				{ 225, 76, 30 }, { 132, 34, 22 }, { -42, -16, -24 },
				{ -128, -76, -34 }, { -232, -152, -18 }, { 82, -62, 165 },
				{ -12, -104, 152 }, { -148, -164, 160 }, { 196, 10, 155 },
			} do
				buildRockOutcrop(V(cr[1], ABYSS_Y, cr[2]), V(32, 24, 22), cr[3])
			end
			makeDecor(ctx.current())
			pin(ctx.current())
		end)
		for i, cr in {
			{ 225, 76, ABYSS_Y + 14, 30, 1.35 }, { 132, 34, ABYSS_Y + 14, 22, 1.45 },
			{ -42, -16, ABYSS_Y + 14, -24, 1.50 }, { -128, -76, ABYSS_Y + 14, -34, 1.45 },
			{ -232, -152, ABYSS_Y + 14, -18, 1.40 }, { 82, -62, ABYSS_Y + 14, 165, 1.45 },
			{ -12, -104, ABYSS_Y + 14, 152, 1.55 }, { -148, -164, ABYSS_Y + 14, 160, 1.45 },
			{ 196, 10, ABYSS_Y + 14, 155, 1.35 },
		} do
			local mc = piece("RiftBedGlows", cr[1], cr[2], cr[4], "RiftLipCrystal", cr[5], RIFT_LIP_TINT, function(cf)
				ctx.cyl("RiftLipFallback", cf.Position + V(0, 6, 0), 8, 12, RIFT_LIP_TINT.GLOW.Color, Mat.Neon)
			end, cr[3])
			pin(mc)
			tagDetail(mc)
			if mc and (i == 2 or i == 7) then
				addLight(H.glowOf(mc) or mc:FindFirstChildWhichIsA("BasePart", true), VIOLET_LIGHT, 2.2, 85)
			end
		end
	end

	-- =========================================================================
	-- F. LANDMARKS 7–24: PROPERLY POSITIONED & COURT-FACING OBSERVATORY VIGNETTES
	-- =========================================================================
	local propSpecs = {
		{ AstralFloor45.Landmarks[7], "MeridianFooting", -29, RIFTWARD_45, 1.00 },         -- Dais SW curved rim (flush!)
		{ AstralFloor45.Landmarks[8], "MeridianFooting", 29, RIFTWARD_45, 1.00 },          -- Dais SE curved rim (flush!)
		{ AstralFloor45.Landmarks[9], "RiftOverlookDeck", 180, RIFTWARD_45, 1.15 },        -- Cantilevered balcony over Rift
		{ AstralFloor45.Landmarks[10], "TransitTower", 90, RIFTWARD_45, 1.28 },            -- West Transit Tower -> faces EAST
		{ AstralFloor45.Landmarks[11], "TransitTower", -90, RIFTWARD_45, 1.28 },           -- East Transit Tower -> faces WEST
		{ AstralFloor45.Landmarks[12], "TransitInstrument", 70, SILVER_LENS_TINT, 1.12 },  -- West instrument -> faces EAST
		{ AstralFloor45.Landmarks[13], "TransitInstrument", -70, SILVER_LENS_TINT, 1.12 }, -- East instrument -> faces WEST
		{ AstralFloor45.Landmarks[14], "LensBench", -28, SILVER_LENS_TINT, 1.10 },         -- Lens Gallery A -> faces Rift
		{ AstralFloor45.Landmarks[15], "LensBench", -28, SILVER_LENS_TINT, 1.10 },         -- Lens Gallery B -> faces Rift
		{ AstralFloor45.Landmarks[16], "FallenOrrery", -45, RIFTWARD_45, 1.42 },           -- Orrery Crest -> faces Observatory
		{ AstralFloor45.Landmarks[17], "StarLecternGrand", 90, RIFTWARD_45, 1.18 },        -- Star-Lectern -> faces EAST
		{ AstralFloor45.Landmarks[18], "InkPoolDecal", 0, INK_POOL_TINT, 1.10 },           -- Star-Ink Pool 1
		{ AstralFloor45.Landmarks[19], "ToppledCabinetRange", -145, RIFTWARD_45, 1.10 },   -- Fallen Catalogue -> spills NW!
		{ AstralFloor45.Landmarks[20], "ProofPress", 180, RIFTWARD_45, 1.08 },             -- Proof Room -> faces NORTH
		{ AstralFloor45.Landmarks[21], "RiftLipCrystal", 35, RIFT_LIP_TINT, 1.35 },
		{ AstralFloor45.Landmarks[22], "RiftLipCrystal", -20, RIFT_LIP_TINT, 1.35 },
		{ AstralFloor45.Landmarks[23], "RiftLipCrystal", -35, RIFT_LIP_TINT, 1.35 },
	}
	for _, spec in propSpecs do
		local lm = spec[1]
		local m = piece(lm.Id, lm.X, lm.Z, spec[3], spec[2], spec[5], spec[4], function(cf)
			boxAt(lm.Id .. "Fallback", cf * CFrame.new(0, lm.Top * 0.5, 0), V(lm.HalfX * 1.8, lm.Top, lm.HalfZ * 1.8), STONE_LIGHT, Mat.Slate)
		end, lm.Y)
		pin(m)
		if spec[2] == "InkPoolDecal" or spec[2] == "RiftLipCrystal" or spec[2] == "MeridianFooting" then
			tagDetail(m)
		end
		if spec[2] == "StarLecternGrand" or spec[2] == "FallenOrrery" then
			addLight(H.glowOf(m) or (m and m:FindFirstChildWhichIsA("BasePart", true)), GOLD_LIGHT, 1.6, 62)
		end
	end

	-- Companion Lens Gallery rows & tall Lens Racks on LensGalleryAlcove (aimed at the Rift!)
	for _, lb in {
		{ 80, 34, -110, -28, 1.05 },
		{ 104, 34, -110, -28, 1.05 },
	} do
		local mb = piece("LensGalleryBenchExtra", lb[1], lb[3], lb[4], "LensBench", lb[5], SILVER_LENS_TINT, function(cf)
			boxAt("LensBenchFallback", cf * CFrame.new(0, 4, 0), V(10, 8, 4), WOOD_WARM, Mat.Wood)
		end, lb[2])
		pin(mb)
		tagDetail(mb)
	end
	if ctx.has("LensRack") then
		for _, lr in { { 82, 34, -120, 0 }, { 108, 34, -120, 0 } } do
			local mr = piece("LensGalleryRackExtra", lr[1], lr[3], lr[4], "LensRack", 1.0, SILVER_LENS_TINT, nil, lr[2])
			pin(mr)
			tagDetail(mr)
		end
	end

	-- Companion glowing Star-Ink Pools beside Star-Lectern (3 glowing indigo pools total!)
	for _, ip in {
		{ -184, 20, 62, 0.80 },
		{ -166, 20, 62, 0.80 },
	} do
		local mi = piece("InkPoolExtra", ip[1], ip[3], 0, "InkPoolDecal", ip[4], INK_POOL_TINT, function(cf)
			ctx.cyl("InkPoolDisc", cf.Position + V(0, 0.3, 0), 5.5, 0.6, rgb(42, 54, 134), Mat.Marble)
		end, ip[2])
		pin(mi)
		tagDetail(mi)
	end

	-- Curved Ebony Bookcase Alcoves, Study Desks & Warm Street Lamps (facing INWARD, zero path blocking!)
	ctx.group("AstralIsleDeck", function()
		-- West Stacks curved bookcase arc (facing EAST +X!)
		buildStandingBookcase(V(-282, 12, 92), 68, 1.02)
		buildStandingBookcase(V(-286, 12, 108), 90, 1.02)
		buildStandingBookcase(V(-282, 12, 124), 112, 1.02)
		buildWritingDesk(V(-266, 12, 108), 90)

		-- Star-Lectern curved west bookcase backdrop (facing EAST!)
		buildStandingBookcase(V(-204, 20, 34), 76, 1.00)
		buildStandingBookcase(V(-204, 20, 54), 104, 1.00)

		-- East Stacks curved bookcase arc (facing WEST -X!)
		buildStandingBookcase(V(312, 25, 10), -68, 1.02)
		buildStandingBookcase(V(316, 25, 26), -90, 1.02)
		buildStandingBookcase(V(312, 25, 42), -112, 1.02)
		buildWritingDesk(V(296, 25, 26), -90)

		-- Fallen Catalogue & Proof Room vignettes
		buildCrateCluster(V(206, 9, 158), -32)
		buildWritingDesk(V(78, 19, 106), 180)

		-- Warm Observatory lanterns accenting key terraces
		streetLamp(V(-256, 12, 124), GOLD_LIGHT, false)
		streetLamp(V(286, 25, 42), GOLD_LIGHT, false)
		streetLamp(V(310, 48, -296), GOLD_LIGHT, false)

		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	-- 24. The Last Lamp at Sanctuary (still warm gold, still steady!) + symmetrical companion arrival lamp!
	do
		local lm = AstralFloor45.Landmarks[24]
		for idx, lx in { lm.X, -lm.X } do
			local ml = piece(if idx == 1 then lm.Id else "TheLastLampPostWest", lx, lm.Z, 0, "IndexLamp", 1.1, RIFTWARD_45, function(cf)
				ctx.cyl("LastLampPost", cf.Position + V(0, 6.2, 0), 0.55, 12.4, BRASS_AGED, Mat.Metal)
				lump("LastLampBulb", cf.Position + V(0, 12.2, 0), V(2.4, 3.0, 2.4), GOLD_LIGHT, Mat.Neon)
			end, lm.Y)
			pin(ml)
			tagDetail(ml)
			if ml then
				ml:SetAttribute("ConjunctionLamp", true)
				safeTag(ml, "ConjunctionLamp")
				if idx == 1 then
					addLight(H.glowOf(ml), GOLD_LIGHT, 2.0, 60)
				end
			end
		end
	end

	-- =========================================================================
	-- G. DRAMATIC COSMIC GALAXY NEBULA SKY & OBSERVATORY MOONBEAM
	-- =========================================================================
	ctx.group("AstralTornSky", function()
		-- Soft, painterly cosmic galaxy nebula ribbons arcing across the starry space sky behind the Observatory!
		addLightCurtain("TornSkyNebulaOuter", V(-20, 172, -366), V(440, 344, -396), 44, 88, rgb(70, 34, 168), rgb(154, 66, 224), 0.72, true, true)
		addLightCurtain("TornSkyNebulaMidA", V(38, 194, -364), V(268, 286, -380), 22, 46, rgb(124, 72, 238), VIOLET_LIGHT, 0.56, true, true)
		addLightCurtain("TornSkyNebulaMidB", V(195, 256, -376), V(415, 338, -392), 44, 18, VIOLET_LIGHT, rgb(196, 102, 244), 0.58, true, true)
		addLightCurtain("TornSkyCoreA", V(72, 210, -362), V(262, 282, -378), 8.0, 20.0, CYAN_STAR, VIOLET_CORE, 0.42, true, true)
		addLightCurtain("TornSkyCoreB", V(210, 264, -374), V(388, 328, -388), 18.0, 6.0, VIOLET_CORE, rgb(238, 178, 255), 0.44, true, true)
		addLightCurtain("TornSkyWestBand", V(-420, 260, -384), V(-85, 192, -364), 38, 20, rgb(48, 66, 176), rgb(118, 56, 214), 0.74, true, true)
		addLightCurtain("TornSkyForkA", V(172, 248, -372), V(124, 290, -376), 9.0, 2.5, VIOLET_LIGHT, CYAN_STAR, 0.62, true, true)
		addLightCurtain("TornSkyForkB", V(286, 294, -382), V(346, 262, -386), 9.0, 2.5, VIOLET_LIGHT, CYAN_STAR, 0.62, true, true)
		-- Overhead cool silver-white Observatory zenith spotlight shaft!
		addLightCurtain("ObservatoryZenithBeam", V(0, 348, -306), V(0, 74, -236), 34, 82, SILVER_LIGHT, rgb(188, 214, 255), 0.85, true, false)
		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	-- Soft violet cosmic mist rising from the Rift Vortex chasm + lifted pages drifting across the Observatory
	riftMistEmitter(V(0, ABYSS_Y + 6, -34), 4)
	riftMistEmitter(V(-140, ABYSS_Y + 6, -98), 3)
	riftMistEmitter(V(148, ABYSS_Y + 6, 46), 3)
	pageEmitter(V(32, 30, -8), 5)
	pageEmitter(V(-194, 44, -138), 4)
	pageEmitter(V(192, 18, 72), 4)
	pageEmitter(V(0, 74, -228), 3)

	ctx.setAttribute("AstralFloor", 45)
	ctx.setAttribute("AstralLights", lightsUsed)
end

return AstralFloor45
