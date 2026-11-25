--!strict
-- Hand-authored set pieces for Abyssal Throne Floor 49: Dreadguard Citadel (abyssal:4, ELITE_STRONGHOLD).
-- Design: docs/prompts/abyssal-throne-floor-layouts-prompt.md (Floor 49, §5.2-5.8) & Abyssal Throne 49.jpg.
--
-- A bastioned obsidian-and-iron star fort under steel-blue iron night, rising around the moated Dreadguard
-- Keep in the dead centre of the room. From the Iron Postern (Sanctuary) across the ash-drifted Glacis,
-- squads see the pointed Ravelin outwork with its blind iron portcullis, the covered ways lined with
-- angled iron-stake palisades, the arrow-head star bastions crowned with sentry boxes and matte wine silk
-- banners, and the 244-stud Dreadguard Keep Tower soaring above the Ravelin with the Overlord's empty
-- sword-niche and Chained Crown relief. Outer wall Wardlights are shuttered dark iron; ONLY the twin
-- iron-banded Drawbridge stairs and their chained gate-towers burn bone-white over the glowing violet
-- Undertow moat. Zero orange anywhere; crimson on/near walk surfaces is strictly matte Fabric wine silk,
-- with only a faint distant crimson glow high on the far north sky horizon.
local CollectionService = game:GetService("CollectionService")
local InfernalFoundry = require(script.Parent.InfernalFoundry)
local AbyssalCollision = require(script.Parent.AbyssalCollision)

local AbyssalFloor49 = {}

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

-- Dreadguard Citadel iron-night palette (§5.4 & §5.7):
-- Obsidian, blackened iron, bone-white marble, matte wine crimson silk (118, 22, 36), pale ash, and
-- bone-white Wardlight glow (244, 238, 222) reserved exclusively for the drawbridges & Iron Postern.
local DREAD_49 = table.freeze({
	STONE = swatch(30, 33, 44, Mat.Basalt),
	ALT = swatch(212, 208, 198, Mat.Limestone),
	METAL = swatch(46, 50, 62, Mat.Metal),
	TRIM = swatch(26, 28, 36, Mat.Metal),
	SILK = swatch(118, 22, 36, Mat.Fabric),
	ACCENT = swatch(172, 140, 76, Mat.Metal),
	GOLD = swatch(172, 140, 76, Mat.Metal),
	GLOW = swatch(244, 238, 222, Mat.Neon),
	CANDLE = swatch(244, 238, 222, Mat.Neon),
	BULB = swatch(244, 238, 222, Mat.Neon),
	CRYSTAL = swatch(124, 76, 182, Mat.Glass, 0.24),
	WOOD = swatch(46, 36, 34, Mat.Wood),
	MOSS = swatch(92, 98, 110, Mat.Slate),
	FOLIAGE = swatch(52, 54, 66, Mat.Slate),
	CAP = swatch(34, 36, 46, Mat.Basalt),
	STEM = swatch(184, 180, 170, Mat.Limestone),
	CORAL = swatch(102, 56, 152, Mat.SmoothPlastic),
})

-- Outer bastions, curtains & generic props keep lamps shuttered dark iron (ZERO Neon near outer walks!).
local SHUTTER_TINT = tinted(DREAD_49, {
	GLOW = swatch(32, 36, 46, Mat.Metal),
	CANDLE = swatch(32, 36, 46, Mat.Metal),
	BULB = swatch(32, 36, 46, Mat.Metal),
	CRYSTAL = swatch(54, 42, 78, Mat.SmoothPlastic),
})

-- Far skyline & deep abyss spires (soft muted silver-violet glints, far from walk surfaces).
local FAR_SPIRE_TINT = tinted(DREAD_49, {
	STONE = swatch(22, 24, 34, Mat.Basalt),
	TRIM = swatch(32, 36, 48, Mat.Metal),
	GLOW = swatch(148, 162, 196, Mat.SmoothPlastic),
	CRYSTAL = swatch(112, 68, 168, Mat.SmoothPlastic),
})

local OBSIDIAN = rgb(28, 31, 42)
local OBSIDIAN_MID = rgb(38, 42, 56)
local OBSIDIAN_DARK = rgb(20, 22, 30)
local IRON_BLACK = rgb(44, 48, 60)
local IRON_DARK = rgb(24, 26, 34)
local BONE_MARBLE = rgb(214, 210, 200)
local WINE_SILK = rgb(118, 22, 36)
local ASH_GREY = rgb(94, 100, 114)
local WARDLIGHT_BONE = rgb(244, 238, 222)
local SILVER_KEY = rgb(214, 224, 240)
local UNDERTOW_DEEP = rgb(84, 34, 158)
local UNDERTOW_CORE = rgb(146, 76, 238)
local HORIZON_CRIMSON = rgb(164, 26, 44)

local MOAT_BED_Y = -9.6

-- Floor 49's 26 landmark footprints (room-local, 840 x 795 x 320, Bottom = -6).
-- Verified clear of all 25 links, 2 return ramps, 8 camps (radius 34 + slot 7), and both Apex portals (±16, 64, -132).
AbyssalFloor49.Landmarks = table.freeze({
	-- 1. Dreadguard Keep Tower (244.0 studs tall, rising to Y=308.0 behind Apex portals & south of Countermine)
	{ Id = "DreadguardKeepTower", X = 0, Z = -172, Y = 64, HalfX = 20.0, HalfZ = 16.5, Top = 244.0 },
	-- 2–3. Inner Drawbridge Gatehouses straddling the West & East Drawbridges at the Keep rim (lit bone-white!)
	{ Id = "WestDrawbridgeGatehouse", X = -74, Z = -80, Y = 64, HalfX = 7.0, HalfZ = 14.5, Top = 41.7, Straddles = true },
	{ Id = "EastDrawbridgeGatehouse", X = 74, Z = -80, Y = 64, HalfX = 7.0, HalfZ = 14.5, Top = 41.7, Straddles = true },
	-- 4–5. Tall Chained Gate Towers flanking the drawbridges on InnerW / InnerE south-inner shoulders
	{ Id = "WestGateTowerChained", X = -152, Z = -38, Y = 52, HalfX = 7.2, HalfZ = 8.2, Top = 54.4 },
	{ Id = "EastGateTowerChained", X = 152, Z = -38, Y = 56, HalfX = 7.2, HalfZ = 8.2, Top = 54.4 },
	-- 6–7. Iron-banded Drawbridge Frames straddling the inner-ward drawbridge departures
	{ Id = "WestDrawbridgeFrame", X = -142, Z = -80, Y = 52, HalfX = 6.0, HalfZ = 12.5, Top = 25.7, Straddles = true },
	{ Id = "EastDrawbridgeFrame", X = 142, Z = -80, Y = 56, HalfX = 6.0, HalfZ = 12.5, Top = 25.7, Straddles = true },
	-- 8. Blind Iron Portcullis on the Sallyport north pier facing south across the Ravelin (the fort has no front gate)
	{ Id = "RavelinBlindPortcullis", X = 0, Z = 2, Y = 22, HalfX = 13.5, HalfZ = 5.2, Top = 21.2 },
	-- 9–10. Ravelin flanking arrow-head salient wings (north shoulders of Crossing, clear of CENTRAL_CROSSING & all links)
	{ Id = "RavelinFlankSalientW", X = -48, Z = 72, Y = 12, HalfX = 12.0, HalfZ = 10.5, Top = 26.0 },
	{ Id = "RavelinFlankSalientE", X = 48, Z = 72, Y = 12, HalfX = 12.0, HalfZ = 10.5, Top = 26.0 },
	-- 11–12. Front star-fort bastion salients (Bastion of Hooks & Bastion of Axes outer SW/SE prows)
	{ Id = "BastionHooksSalient", X = -312, Z = 118, Y = 16, HalfX = 14.5, HalfZ = 12.5, Top = 28.9 },
	{ Id = "BastionAxesSalient", X = 312, Z = 118, Y = 20, HalfX = 14.5, HalfZ = 12.5, Top = 28.9 },
	-- 13–14. Rear Dread Bastion arrow-head salients (NW/NE prows)
	{ Id = "WestDreadSalient", X = -318, Z = -256, Y = 32, HalfX = 14.5, HalfZ = 12.5, Top = 28.9 },
	{ Id = "EastDreadSalient", X = 318, Z = -256, Y = 36, HalfX = 14.5, HalfZ = 12.5, Top = 28.9 },
	-- 15. North Bastion salient prow pointing at the far north wall
	{ Id = "NorthBastionSalient", X = 0, Z = -375, Y = 40, HalfX = 14.5, HalfZ = 12.5, Top = 28.9 },
	-- 16. Bastion of Hooks: colossal Siege-Hook Crane (NE shoulder of WestGallery, off camp & lanes)
	{ Id = "HooksSiegeCrane", X = -224, Z = 38, Y = 16, HalfX = 5.5, HalfZ = 11.0, Top = 36.3 },
	-- 17. Bastion of Axes: Executioners' Yard dais, whetstone & axe-rack (NW shoulder of EastGallery, off camp & lanes)
	{ Id = "AxesExecutionYard", X = 224, Z = 38, Y = 20, HalfX = 6.5, HalfZ = 5.2, Top = 9.0 },
	-- 18–19. Chained Penitents' Cages on West & East Dread Bastions (outer W/E flanks, off camps & lanes)
	{ Id = "WestBastionPenitentCage", X = -318, Z = -215, Y = 32, HalfX = 3.0, HalfZ = 5.0, Top = 22.8 },
	{ Id = "EastBastionPenitentCage", X = 318, Z = -215, Y = 36, HalfX = 3.0, HalfZ = 5.0, Top = 22.8 },
	-- 20. North Bastion: the fort's Great Cracked Iron Alarm Bell
	{ Id = "NorthBastionGreatBell", X = 0, Z = -352, Y = 40, HalfX = 9.0, HalfZ = 5.2, Top = 33.0 },
	-- 21. The Countermine: void-pit shaft collar & winding hoist gear (south lip of Countermine, clear of landing)
	{ Id = "CountermineHoist", X = 0, Z = -196, Y = 30, HalfX = 7.0, HalfZ = 6.5, Top = 28.5 },
	-- 22–23. Inner Ward Armouries (blackened Dreadguard plate on stands, off drawbridge lanes)
	{ Id = "InnerWestArmoury", X = -196, Z = -46, Y = 52, HalfX = 3.0, HalfZ = 2.8, Top = 10.0 },
	{ Id = "InnerEastArmoury", X = 196, Z = -46, Y = 56, HalfX = 3.0, HalfZ = 2.8, Top = 10.0 },
	-- 24–25. Covered Way iron-stake palisades guarding the Glacis flank slopes
	{ Id = "CovertWestPalisade", X = -178, Z = 158, Y = 0, HalfX = 10.0, HalfZ = 3.8, Top = 9.3 },
	{ Id = "CovertEastPalisade", X = 178, Z = 158, Y = 0, HalfX = 10.0, HalfZ = 3.8, Top = 9.3 },
	-- 26. The Iron Postern arrival gate-arch straddling the Sanctuary exit onto the Glacis
	{ Id = "IronPosternGateArch", X = 0, Z = 336, Y = 8, HalfX = 28.0, HalfZ = 4.2, Top = 32.0, Straddles = true },
	-- 27–28. Far North Fortress Towers framing the crimson horizon
	{ Id = "NorthFortressTowerW", X = -248, Z = -364, Y = -10, HalfX = 15.0, HalfZ = 15.0, Top = 132.0 },
	{ Id = "NorthFortressTowerE", X = 248, Z = -364, Y = -10, HalfX = 15.0, HalfZ = 15.0, Top = 132.0 },
}) :: { Landmark }

local function safeTag(inst: Instance?, tagName: string)
	if inst then
		pcall(function()
			CollectionService:AddTag(inst, tagName)
		end)
	end
end

function AbyssalFloor49.Build(ctx: any)
	local H = InfernalFoundry.Helpers(ctx)
	local P = H.P
	local _boxAt, lump, light, noCollide = H.boxAt, H.lump, H.light, H.noCollide
	local function boxAt(name: string, cf: CFrame, size: Vector3, color: Color3, mat: Enum.Material, trans: number?): Part
		return _boxAt(name, size, cf, color, mat, trans)
	end

	local placedProps = 0
	local groundCoverCount = 0
	local lightsUsed = 0
	local emittersUsed = 0
	local templateCounts: { [string]: number } = {}
	local placedSpots: { { number } } = {}
	local rng = Random.new(49 * 7919 + 17)

	local function recordTemplate(name: string)
		templateCounts[name] = (templateCounts[name] or 0) + 1
	end

	local function addLight(p: Instance?, color: Color3, brightness: number, range: number)
		if p and lightsUsed < 16 then
			lightsUsed += 1
			light(p, color, brightness, range)
		end
	end

	local function pin(m: Instance?)
		if m then m:SetAttribute("OnTerrain", true) end
	end

	-- Walk-through dressing: no collision, queries, touches or shadows.
	local function ghost(m: Instance?)
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
	-- A placed prop: overhead, sky, glow, hanging and small pieces become ghosts; everything else a player can
	-- walk into keeps its collision (AbyssalCollision).
	local function makeDecor(m: Instance?)
		if not m then return end
		if AbyssalCollision.StaysSolid(m) then
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					d.CanTouch = false
				end
			end
			return
		end
		ghost(m)
	end

	-- A platform support (AbyssalCollision.SupportKinds) collides, but its top meets the walkway it holds up, so
	-- the room's solid-scenery lane check (which pads every part by 2-3 studs) must not count it as blocking.
	local function supportOnly(m: Instance?)
		if not m then return end
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d:SetAttribute("SolidScenery", false)
			end
		end
	end

	local function tagDirge(inst: Instance?, tagName: string)
		if not inst then return end
		inst:SetAttribute(tagName, true)
		safeTag(inst, tagName)
	end

	local function groundY(x: number, z: number): number
		if ctx.field then
			return ctx.field.Height(x, z) + 0.5
		end
		return ctx.bottom
	end

	local function onAnyPlatform(x: number, z: number, pad: number): boolean
		for _, plat in P do
			if math.abs(x - plat.X) <= plat.Width * 0.5 + pad and math.abs(z - plat.Z) <= plat.Depth * 0.5 + pad then
				return true
			end
		end
		return false
	end

	local function onApexArena(x: number, z: number, pad: number): boolean
		local apex = P.Apex
		if not apex then return false end
		return math.abs(x - apex.X) <= apex.Width * 0.5 + pad and math.abs(z - apex.Z) <= apex.Depth * 0.5 + pad
	end

	local function campFree(x: number, z: number, r: number): boolean
		for _, camp in ctx.layout.Camps do
			if (camp.X - x) ^ 2 + (camp.Z - z) ^ 2 < (36 + r) ^ 2 then
				return false
			end
		end
		return true
	end

	local function spotFree(x: number, z: number, r: number, allowOnPlatform: boolean?): boolean
		if math.abs(x) > ctx.w * 0.5 - 12 or math.abs(z) > ctx.d * 0.5 - 12 then
			return false
		end
		if onApexArena(x, z, r + 4) then
			return false
		end
		if not allowOnPlatform and onAnyPlatform(x, z, r + 2) then
			return false
		end
		if not campFree(x, z, r) then
			return false
		end
		if not ctx.footprintClear(x, z, r + 1.5, r + 1.5) then
			return false
		end
		for _, pt in placedSpots do
			if (pt[1] - x) ^ 2 + (pt[2] - z) ^ 2 < (pt[3] + r) ^ 2 then
				return false
			end
		end
		return true
	end

	-- Places a counted non-ground-cover kit prop (or native fallback until imported).
	local function placeProp(
		groupName: string,
		kitName: string,
		x: number,
		y: number,
		z: number,
		yawDeg: number,
		scale: any,
		override: any?,
		fallback: ((cf: CFrame) -> ())?,
		clearR: number?,
		dirgeTag: string?,
		keepCollision: boolean?
	): Instance?
		local prop: Instance? = nil
		local s = if typeof(scale) == "number" then V(scale, scale, scale) else scale
		ctx.group(groupName, function()
			prop = ctx.current()
			local cf = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yawDeg), 0)
			if ctx.has(kitName) then
				ctx.kitAt(kitName, cf, s, override)
			elseif fallback then
				fallback(cf)
			else
				boxAt(kitName .. "_Fallback", cf * CFrame.new(0, 2.5, 0), V(4, 5, 4) * s, OBSIDIAN_MID, Mat.Basalt)
			end
		end)
		pin(prop)
		if not keepCollision then
			makeDecor(prop)
		end
		if dirgeTag and prop then
			tagDirge(prop, dirgeTag)
		end
		placedProps += 1
		recordTemplate(kitName)
		if clearR and clearR > 0 then
			table.insert(placedSpots, { x, z, clearR })
		end
		return prop
	end

	local function addSkyCurtain(name: string, p0: Vector3, p1: Vector3, h0: number, h1: number, col0: Color3, col1: Color3, alpha: number)
		local mid = (p0 + p1) * 0.5
		local anchor = ctx.block(name .. "_Anchor", V(1, 1, 1), mid, col0, Mat.SmoothPlastic, nil, 1)
		anchor.CanCollide, anchor.CanQuery, anchor.CanTouch, anchor.CastShadow = false, false, false, false
		anchor:SetAttribute("SolidScenery", false)
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
		b.Width0 = h0
		b.Width1 = h1
		b.FaceCamera = true
		b.LightEmission = 0.72
		b.LightInfluence = 0
		b.Segments = 20
		b.Color = ColorSequence.new(col0, col1)
		b.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 1.0),
			NumberSequenceKeypoint.new(0.20, math.min(0.96, alpha + 0.14)),
			NumberSequenceKeypoint.new(0.50, alpha),
			NumberSequenceKeypoint.new(0.80, math.min(0.96, alpha + 0.14)),
			NumberSequenceKeypoint.new(1.0, 1.0),
		})
		b.Parent = anchor
	end

	local function addAshEmitter(pos: Vector3, rate: number)
		if emittersUsed >= 14 then return end
		emittersUsed += 1
		local anchor = ctx.block("DirgeAshAnchor", V(1, 1, 1), pos, ASH_GREY, Mat.SmoothPlastic, nil, 1)
		anchor.CanCollide, anchor.CanQuery, anchor.CanTouch, anchor.CastShadow = false, false, false, false
		tagDirge(anchor, "DirgeAshEmitter")
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "DreadguardAsh"
		pe.Color = ColorSequence.new(rgb(142, 148, 166), rgb(82, 86, 102))
		pe.LightEmission = 0.08
		pe.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 0.45),
			NumberSequenceKeypoint.new(0.5, 0.95),
			NumberSequenceKeypoint.new(1.0, 0.25),
		})
		pe.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 1.0),
			NumberSequenceKeypoint.new(0.2, 0.42),
			NumberSequenceKeypoint.new(0.8, 0.65),
			NumberSequenceKeypoint.new(1.0, 1.0),
		})
		pe.Lifetime = NumberRange.new(3.2, 5.4)
		pe.Rate = rate
		pe.Speed = NumberRange.new(2.0, 4.4)
		pe.SpreadAngle = Vector2.new(28, 28)
		pe.RotSpeed = NumberRange.new(-40, 40)
		-- Ash drifts north (-Z) toward the Throne!
		pe.Acceleration = V(0, 0.5, -2.4)
		pe.Parent = anchor
	end

	-- Reserve every landmark footprint so procedural passes stay clear.
	for _, lm in AbyssalFloor49.Landmarks do
		local r = math.max(lm.HalfX, lm.HalfZ)
		ctx.reserve(lm.X, lm.Z, r)
		table.insert(placedSpots, { lm.X, lm.Z, r + 2 })
	end

	-- =========================================================================
	-- A. DREADGUARD KEEP MOUND, BASTION RETAINING WALLS & UNDERTOW MOAT RING
	-- =========================================================================
	-- 1. Central Dreadguard Keep craggy obsidian mound & Keep Tower north plinth (-10..64)
	ctx.group("DreadguardKeepMound", function()
		-- Main octagonal Keep mound under Apex (144 x 108 at Y=64)
		local moundH = 74.0
		ctx.cyl("KeepMoundCore", V(0, -10 + moundH * 0.5, -90), 76.0, moundH - 1.2, OBSIDIAN, Mat.Basalt)
		ctx.cyl("KeepMoundLower", V(0, -10 + 18, -90), 84.0, 36.0, OBSIDIAN_DARK, Mat.Basalt)
		boxAt("KeepMoundShoulderW", CFrame.new(V(-62, 26, -90)), V(28, 72, 92), OBSIDIAN, Mat.Basalt)
		boxAt("KeepMoundShoulderE", CFrame.new(V(62, 26, -90)), V(28, 72, 92), OBSIDIAN, Mat.Basalt)
		-- Battered crag buttresses around the mound rim (facing out into the Undertow moat!)
		for k = 0, 15 do
			local a = k * (math.pi * 2 / 16)
			local rx = math.cos(a) * 76.0
			local rz = -90 + math.sin(a) * 58.0
			-- Leave drawbridge approach pockets clear on X = ±76, Z = -80
			if math.abs(rz + 80) < 18 and math.abs(rx) > 60 then continue end
			local cf = CFrame.new(V(rx, 24, rz)) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, math.rad(10))
			boxAt("KeepMoundButtress", cf, V(14, 72, 16), if k % 2 == 0 then OBSIDIAN else OBSIDIAN_DARK, Mat.Basalt)
		end

		-- North Tower Plinth under DreadguardKeepTower at (0, -172), rising cleanly to Y=64
		boxAt("KeepTowerPlinth", CFrame.new(V(0, 26.8, -172)), V(42, 73.6, 35), OBSIDIAN, Mat.Basalt)
		boxAt("KeepTowerPlinthBand", CFrame.new(V(0, 62.6, -172)), V(44, 2.2, 37), IRON_BLACK, Mat.Metal)
		boxAt("KeepTowerPlinthCoping", CFrame.new(V(0, 63.9, -172)), V(44.6, 0.7, 37.6), BONE_MARBLE, Mat.Limestone)

		-- Clean flush Chained Crown floor inlay on Apex (non-colliding, 0.06 studs thin so boss arena stays 100% flat)
		ctx.ring("KeepArenaOuterRing", V(0, 64.04, -90), 48.0, 0.55, IRON_BLACK, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 36)
		ctx.ring("KeepArenaBoneRing", V(0, 64.04, -90), 34.0, 0.42, BONE_MARBLE, Mat.Limestone, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 28)
		ctx.ring("KeepArenaCrownRing", V(0, 64.04, -90), 16.0, 0.36, IRON_BLACK, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 20)

		-- The mound, its shoulders, buttresses and the tower plinth hold the Keep up and stay solid
		-- (AbyssalCollision.SupportKinds); the flush arena rings on the Apex floor stay walk-through.
		makeDecor(ctx.current())
		supportOnly(ctx.current())
		local mound = ctx.current()
		if mound then
			for _, d in mound:GetDescendants() do
				if d:IsA("BasePart") and string.find(d.Name, "Ring", 1, true) then
					d.CanCollide = false
					d.CanQuery = false
				end
			end
		end
		pin(ctx.current())
	end)

	-- 2. Undertow Moat Ring circling the Keep mound (strictly Y <= -7.5, no Neon near walk surfaces!)
	ctx.group("UndertowMoatRing", function()
		local segs = 28
		local rxMoat, rzMoat = 104.0, 80.0
		for k = 0, segs - 1 do
			local a = (k + 0.5) * (math.pi * 2 / segs)
			local mx = math.cos(a) * rxMoat
			local mz = -90 + math.sin(a) * rzMoat
			local tangent = V(-math.sin(a) * rxMoat, 0, math.cos(a) * rzMoat)
			local segLen = (2 * math.pi * 92) / segs + 6.0
			local mcf = CFrame.lookAt(V(mx, MOAT_BED_Y, mz), V(mx, MOAT_BED_Y, mz) + tangent)
			boxAt("MoatBasaltBed", mcf, V(30.0, 0.8, segLen), OBSIDIAN_DARK, Mat.Basalt)
			local river = boxAt("UndertowRibbonOuter", mcf * CFrame.new(0, 0.75, 0), V(22.0, 0.35, segLen * 0.96), UNDERTOW_DEEP, Mat.SmoothPlastic, 0.18)
			tagDirge(river, "DirgeUndertow")
			local core = boxAt("UndertowRibbonCore", mcf * CFrame.new((k % 2 == 0 and 2.5 or -2.5), 1.05, 0), V(9.5, 0.25, segLen * 0.92), UNDERTOW_CORE, Mat.SmoothPlastic, 0.28)
			tagDirge(core, "DirgeUndertow")
			if k % 7 == 0 then
				-- 4 invisible PointLight anchors at Y = -7.8 casting cold violet under-glow onto the Keep cliffs
				local anchor = boxAt("UndertowGlowAnchor", mcf * CFrame.new(0, 1.8, 0), V(1, 1, 1), UNDERTOW_CORE, Mat.SmoothPlastic, 1)
				addLight(anchor, UNDERTOW_CORE, 1.7, 52)
			end
		end
		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	-- 3. Battered Star-Fort Bastion Retaining Aprons (frames each wall/bastion plateau so they read as star-fort masonry)
	ctx.group("StarFortRetainingAprons", function()
		local fortWalls = {
			"WestGallery", "EastGallery", "CurtainW", "CurtainE",
			"WestBastion", "EastBastion", "CurtainNW", "CurtainNE", "NorthBastion",
		}
		for _, id in fortWalls do
			local plat = P[id]
			if not plat then continue end
			local baseH = plat.Y - (-10)
			boxAt(id .. "MasonryWall", CFrame.new(V(plat.X, -10 + baseH * 0.5 - 0.3, plat.Z)), V(plat.Width + 2.4, baseH - 0.6, plat.Depth + 2.4), OBSIDIAN, Mat.Basalt)
			boxAt(id .. "IronBand", CFrame.new(V(plat.X, plat.Y - 2.2, plat.Z)), V(plat.Width + 3.2, 1.1, plat.Depth + 3.2), IRON_BLACK, Mat.Metal)
			boxAt(id .. "BoneCornice", CFrame.new(V(plat.X, plat.Y - 0.8, plat.Z)), V(plat.Width + 3.4, 0.55, plat.Depth + 3.4), BONE_MARBLE, Mat.Limestone)
		end
		-- Sallyport blind iron postern door in the Keep-facing north rock pier + Countermine hoist apron
		local sally = P.Sallyport
		if sally then
			boxAt("SallyportWallBase", CFrame.new(V(sally.X, (sally.Y - 10) * 0.5, sally.Z - 4)), V(sally.Width - 2, sally.Y + 9.2, sally.Depth + 8), OBSIDIAN_DARK, Mat.Basalt)
			boxAt("SallyportTrim", CFrame.new(V(sally.X, sally.Y - 0.6, sally.Z - 4)), V(sally.Width + 1.2, 0.8, sally.Depth + 9.2), IRON_BLACK, Mat.Metal)
		end
		-- Masonry piers from the moat floor under the salient prows that jut past their terraces (the North
		-- Bastion's prow at the Throne Gate, and the Ravelin's two wings off the Crossing's north corners).
		for _, idx in { 15, 9, 10 } do
			local lm = AbyssalFloor49.Landmarks[idx]
			local topY = lm.Y :: number
			local h = topY + 12
			boxAt(lm.Id .. "Pier", CFrame.new(V(lm.X, topY - h / 2, lm.Z)), V(lm.HalfX * 1.7, h, lm.HalfZ * 1.7), OBSIDIAN, Mat.Basalt)
			boxAt(lm.Id .. "PierBand", CFrame.new(V(lm.X, topY - 2.2, lm.Z)), V(lm.HalfX * 1.7 + 0.8, 1.1, lm.HalfZ * 1.7 + 0.8), IRON_BLACK, Mat.Metal)
		end
		local cm = P.Countermine
		if cm then
			boxAt("CountermineHoistApron", CFrame.new(V(cm.X, (cm.Y - 10) * 0.5, cm.Z + 20)), V(26, cm.Y + 9.2, 24), OBSIDIAN_DARK, Mat.Basalt)
			boxAt("CountermineHoistRim", CFrame.new(V(cm.X, cm.Y - 0.6, cm.Z + 20)), V(27.2, 0.8, 25.2), IRON_BLACK, Mat.Metal)
		end
		makeDecor(ctx.current())
		supportOnly(ctx.current())
		pin(ctx.current())
	end)

	-- =========================================================================
	-- B. LANDMARKS 1–28: DREADGUARD KEEP, DRAWBRIDGES, BASTIONS & VIGNETTES
	-- =========================================================================
	-- 1. Colossal 244-stud DreadguardKeepTower rising behind Apex
	do
		local lm = AbyssalFloor49.Landmarks[1]
		local kt = placeProp("DreadguardKeep", "DreadguardKeepTower", lm.X, lm.Y :: number, lm.Z, 0, 1.0, DREAD_49, function(cf)
			boxAt("KeepTowerFallback", cf * CFrame.new(0, 122, 0), V(36, 244, 30), OBSIDIAN, Mat.Basalt)
		end)
		if kt then
			-- Subtle cold silver moonlight accent high on the Keep spire crown (nowhere near walk surfaces!)
			local crownAnchor = boxAt("KeepCrownLightAnchor", CFrame.new(V(0, 245, -172)), V(1, 1, 1), SILVER_KEY, Mat.SmoothPlastic, 1)
			noCollide(crownAnchor)
			addLight(crownAnchor, SILVER_KEY, 1.4, 90)
		end
	end

	-- 2–7. Twin Drawbridge Gatehouses, Chained Gate Towers & Iron-Banded Drawbridge Frames (ONLY lit wall lamps!)
	for _, spec in {
		{ idx = 2, kit = "DreadguardKeepGatehouse", yaw = -90, lit = true, tag = "DirgeWardlight" },
		{ idx = 3, kit = "DreadguardKeepGatehouse", yaw = 90, lit = true, tag = "DirgeWardlight" },
		{ idx = 4, kit = "GateTowerChained", yaw = -90, lit = true, tag = "DirgeWardlight" },
		{ idx = 5, kit = "GateTowerChained", yaw = 90, lit = true, tag = "DirgeWardlight" },
		{ idx = 6, kit = "DrawbridgeStair", yaw = -90, lit = false, tag = "DirgeChain" },
		{ idx = 7, kit = "DrawbridgeStair", yaw = 90, lit = false, tag = "DirgeChain" },
	} do
		local lm = AbyssalFloor49.Landmarks[spec.idx]
		local m = placeProp(lm.Id, spec.kit, lm.X, lm.Y :: number, lm.Z, spec.yaw, 1.0, DREAD_49, function(cf)
			boxAt(lm.Id .. "Fallback", cf * CFrame.new(0, 18, 0), V(14, 36, 12), IRON_BLACK, Mat.Metal)
		end, nil, spec.tag)
		if spec.lit and m then
			addLight(H.glowOf(m) or m:FindFirstChildWhichIsA("BasePart", true), WARDLIGHT_BONE, 2.2, 72)
		end
	end

	-- 8. Ravelin Blind Iron Portcullis (leads nowhere)
	do
		local lm = AbyssalFloor49.Landmarks[8]
		placeProp(lm.Id, "RavelinPortcullis", lm.X, lm.Y :: number, lm.Z, 0, 1.0, DREAD_49, function(cf)
			boxAt("BlindPortcullisFallback", cf * CFrame.new(0, 10.5, 0), V(26, 21, 10), OBSIDIAN, Mat.Basalt)
		end)
	end

	-- 9–15. Arrow-head Star-Fort Bastion Salients (facing outward into the Glacis & abyss)
	for _, spec in {
		{ idx = 9, yaw = 22 },
		{ idx = 10, yaw = -22 },
		{ idx = 11, yaw = 42 },
		{ idx = 12, yaw = -42 },
		{ idx = 13, yaw = 138 },
		{ idx = 14, yaw = -138 },
		{ idx = 15, yaw = 180 },
	} do
		local lm = AbyssalFloor49.Landmarks[spec.idx]
		placeProp(lm.Id, "StarBastionSalient", lm.X, lm.Y :: number, lm.Z, spec.yaw, 1.0, DREAD_49, function(cf)
			boxAt(lm.Id .. "Fallback", cf * CFrame.new(0, 14, 0), V(24, 28, 20), OBSIDIAN, Mat.Basalt)
		end)
	end

	-- 16–25. Bastion & Terrace Signature Landmarks
	local bespokeLandmarks = {
		{ idx = 16, kit = "SiegeHookCrane", yaw = 135, tag = "DirgeChain" },
		{ idx = 17, kit = "ExecutionYardSet", yaw = -135, tag = nil },
		{ idx = 18, kit = "PenitentCage", yaw = 45, tag = "DirgeChain" },
		{ idx = 19, kit = "PenitentCage", yaw = -45, tag = "DirgeChain" },
		{ idx = 20, kit = "GreatIronBell", yaw = 0, tag = "DirgeChain" },
		{ idx = 21, kit = "MineWindingGear", yaw = 0, tag = "DirgeChain" },
		{ idx = 22, kit = "ArmourStandPlate", yaw = -150, tag = nil },
		{ idx = 23, kit = "ArmourStandPlate", yaw = 150, tag = nil },
		{ idx = 24, kit = "IronStakePalisade", yaw = 0, tag = nil },
		{ idx = 25, kit = "IronStakePalisade", yaw = 0, tag = nil },
	}
	for _, bl in bespokeLandmarks do
		local lm = AbyssalFloor49.Landmarks[bl.idx]
		placeProp(lm.Id, bl.kit, lm.X, lm.Y :: number, lm.Z, bl.yaw, 1.0, DREAD_49, nil, nil, bl.tag)
	end

	-- 26. Sanctuary Iron Postern Gate Arch + arrival bone-white Wardlights
	do
		local lm = AbyssalFloor49.Landmarks[26]
		placeProp(lm.Id, "GatehouseArch", lm.X, lm.Y :: number, lm.Z, 0, V(0.76, 1.05, 0.72), DREAD_49, function(cf)
			boxAt("IronPosternFallback", cf * CFrame.new(0, 16, 0), V(56, 32, 8), OBSIDIAN, Mat.Basalt)
		end)
		for _, sx in { -1, 1 } do
			local lamp = placeProp("SanctuaryWardlight", "HangingLantern", sx * 24, 8, 338, 0, 1.25, DREAD_49, function(cf)
				boxAt("PosternLampPost", cf * CFrame.new(0, 3, 0), V(1.4, 6, 1.4), IRON_BLACK, Mat.Metal)
				lump("PosternLampFlame", cf.Position + V(0, 6.2, 0), V(1.6, 2.0, 1.6), WARDLIGHT_BONE, Mat.Neon)
			end, 2.5, "DirgeWardlight")
			if lamp then
				addLight(H.glowOf(lamp) or lamp:FindFirstChildWhichIsA("BasePart", true), WARDLIGHT_BONE, 1.8, 56)
			end
		end
	end

	-- 27–28. Far North Fortress Towers framing the crimson horizon
	for _, idx in { 27, 28 } do
		local lm = AbyssalFloor49.Landmarks[idx]
		-- StormkeepRoundTower at 2.9x (about 130 studs): the ChainTowerRound kit isn't imported, and its fallback
		-- left a 7-stud stub on the moat floor in each far corner instead of a tower.
		placeProp(lm.Id, "StormkeepRoundTower", lm.X, lm.Y :: number, lm.Z, if idx == 27 then 28 else -28, 2.9, FAR_SPIRE_TINT)
	end

	-- =========================================================================
	-- C. COLOSSAL KEEP CHAINS, LINK DRESSING & BASTION VIGNETTES
	-- =========================================================================
	-- The Keep (Apex) is round (a superellipse, Shapes.Apex.Round), not its 144 x 108 rectangle: its battlements
	-- and corner sentries stand on that round edge, facing out, instead of on the rectangle's corners where the
	-- edge has fallen away under them.
	local apex = P.Apex
	local apexRound = (ctx.layout.Terrain and ctx.layout.Terrain.Shapes and ctx.layout.Terrain.Shapes.Apex
		and ctx.layout.Terrain.Shapes.Apex.Round) or 2.8
	local ax, az = apex.Width / 2, apex.Depth / 2
	-- A point `inset` studs inside the Keep's edge in direction `deg` (0 = east, 90 = south), and the yaw that
	-- turns a piece's front (-Z at yaw 0) to face out of the Keep there.
	local function keepEdge(deg: number, inset: number): (number, number, number)
		local c, sn = math.cos(math.rad(deg)), math.sin(math.rad(deg))
		local r = 1 / ((math.abs(c) / ax) ^ apexRound + (math.abs(sn) / az) ^ apexRound) ^ (1 / apexRound)
		local ex, ez = r * c, r * sn
		local gx = (if ex < 0 then -1 else 1) * math.abs(ex) ^ (apexRound - 1) / ax ^ apexRound
		local gz = (if ez < 0 then -1 else 1) * math.abs(ez) ^ (apexRound - 1) / az ^ apexRound
		local gl = math.sqrt(gx * gx + gz * gz)
		gx, gz = gx / gl, gz / gl
		return apex.X + ex - gx * inset, apex.Z + ez - gz * inset, math.deg(math.atan2(-gx, -gz))
	end

	-- Corner sentries on the four diagonals of the Keep's edge (clear of the boss portals on the north side and
	-- the drawbridge landings on the east and west).
	local sentryTops: { [string]: Vector3 } = {}
	for _, deg in { 45, 135, 225, 315 } do
		local x, z, yaw = keepEdge(deg, 6)
		placeProp("KeepCornerSentry", "DreadguardSentry", x, apex.Y, z, yaw, 0.9, DREAD_49)
		sentryTops[tostring(deg)] = V(x, apex.Y + 17, z)
	end
	-- South battlements following the curve between the two south sentries (the north edge keeps the portals).
	for _, deg in { 72, 108 } do
		local x, z, yaw = keepEdge(deg, 4)
		placeProp("KeepSouthCurtain", "CurtainWallCrenel", x, apex.Y, z, yaw, V(1.0, 1.0, 0.9), DREAD_49)
	end

	-- Giant iron chains from the Keep Tower to things that hold them: the two north corner sentries, the two
	-- drawbridge gatehouses and the two drawbridge frames out on the inner wards.
	ctx.group("KeepAnchorChains", function()
		local frameW = AbyssalFloor49.Landmarks[6]
		local frameE = AbyssalFloor49.Landmarks[7]
		local chains = {
			{ V(-16, 152, -162), sentryTops["225"] },
			{ V(16, 152, -162), sentryTops["315"] },
			{ V(-16, 118, -160), V(-74, 96, -80) },
			{ V(16, 118, -160), V(74, 96, -80) },
			{ V(-18, 96, -184), V(frameW.X, (frameW.Y :: number) + 24, frameW.Z) },
			{ V(18, 96, -184), V(frameE.X, (frameE.Y :: number) + 24, frameE.Z) },
		}
		for _, ch in chains do
			local r = H.rod("ColossalKeepChain", ch[1], ch[2], 0.55, IRON_DARK, Mat.Metal)
			tagDirge(r, "DirgeChain")
		end
		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	-- Covered Way Iron-Stake Palisades flanking the Glacis & Ravelin
	local palisadeLine = {
		{ -340, 180, -14 }, { -306, 174, -12 }, { -272, 168, -10 }, { -238, 162, -8 },
		{ -204, 156, -6 }, { -168, 152, -4 }, { -86, 150, 8 }, { -56, 148, 16 },
		{ 56, 148, -16 }, { 86, 150, -8 }, { 168, 152, 4 }, { 204, 156, 6 },
		{ 238, 162, 8 }, { 272, 168, 10 }, { 306, 174, 12 }, { 340, 180, 14 },
	}
	for _, sp in palisadeLine do
		if spotFree(sp[1], sp[2], 7, false) then
			placeProp("CovertPalisade", "IronStakePalisade", sp[1], groundY(sp[1], sp[2]), sp[2], sp[3], 1.15, DREAD_49, nil, 6.5)
		end
	end

	-- Shuttered Wardlights along every outer curtain, bastion & link end (dark iron, NO glow!)
	local shutterSpots = {
		{ -102, 4, 100, 35 }, { -148, 4, 102, -35 },
		{ 102, 8, 100, -35 }, { 148, 8, 102, 35 },
		{ -225, 16, 42, -90 }, { -225, 16, 108, -90 },
		{ 225, 20, 42, 90 }, { 225, 20, 108, 90 },
		{ -294, 24, -42, -90 }, { -294, 24, -98, -90 },
		{ 294, 28, -42, 90 }, { 294, 28, -98, 90 },
		{ -230, 32, -180, -45 }, { -230, 32, -250, -135 },
		{ 230, 36, -180, 45 }, { 230, 36, -250, 135 },
		{ -112, 44, -276, 180 }, { -168, 44, -276, 180 },
		{ 112, 48, -276, 180 }, { 168, 48, -276, 180 },
		{ -34, 40, -296, 180 }, { 34, 40, -296, 180 },
		{ -26, 22, 12, 0 }, { 26, 22, 12, 0 },
		{ -26, 30, -242, 180 }, { 26, 30, -242, 180 },
	}
	for _, sl in shutterSpots do
		if ctx.footprintClear(sl[1], sl[3], 2.5, 2.5) and campFree(sl[1], sl[3], 2.0) then
			placeProp("OuterShutteredLamp", "ShutteredWardlight", sl[1], sl[2], sl[3], sl[4], 1.0, SHUTTER_TINT, nil, 2.0)
		end
	end

	-- Outer Bastion & Curtain Wall Crenelations + Dreadguard Sentries + Wine War Banners
	local curtainSpots = {
		{ -346, 24, -70, -90, "CurtainWallCrenel" },
		{ 346, 28, -70, 90, "CurtainWallCrenel" },
		{ -140, 44, -324, 180, "CurtainWallCrenel" },
		{ 140, 48, -324, 180, "CurtainWallCrenel" },
		{ -305, 16, 75, -90, "CurtainWallSegment" },
		{ 305, 20, 75, 90, "CurtainWallSegment" },
		{ -308, 32, -215, -90, "BulwarkWall" },
		{ 308, 36, -215, 90, "BulwarkWall" },
		{ -248, 16, 40, 135, "DreadguardSentry" },
		{ 248, 20, 40, -135, "DreadguardSentry" },
		{ -242, 32, -248, 45, "DreadguardSentry" },
		{ 242, 36, -248, -45, "DreadguardSentry" },
		{ -34, 40, -342, 180, "DreadguardSentry" },
		{ 34, 40, -342, 180, "DreadguardSentry" },
		{ -18, 22, 20, 15, "ArmourStandPlate" },
		{ 18, 22, 20, -15, "ArmourStandPlate" },
		{ -22, 30, -208, 20, "ArmourStandPlate" },
		{ 22, 30, -208, -20, "ArmourStandPlate" },
		{ -196, 52, -94, 135, "AbyssReliquaryShrine" },
		{ 196, 56, -94, -135, "AbyssReliquaryShrine" },
	}
	for _, cs in curtainSpots do
		if ctx.footprintClear(cs[1], cs[3], 4.0, 4.0) and campFree(cs[1], cs[3], 3.0) then
			placeProp("CitadelWallPiece", cs[5], cs[1], cs[2], cs[3], cs[4], 0.92, DREAD_49, nil, 3.5)
		end
	end

	-- Every link end dressed with matching iron bollards / wine banners / armour racks off-lane
	for _, link in ctx.layout.Links do
		local dx, dz = link.BX - link.AX, link.BZ - link.AZ
		local len = math.max(1, math.sqrt(dx * dx + dz * dz))
		local ux, uz = dx / len, dz / len
		local nx, nz = -uz, ux
		local yaw = math.deg(math.atan2(ux, uz))
		for endIdx, base in { { link.AX, link.AY, link.AZ }, { link.BX, link.BY, link.BZ } } do
			for _, side in { -1, 1 } do
				local px = base[1] + nx * side * 19.5
				local pz = base[3] + nz * side * 19.5
				if spotFree(px, pz, 3.0, true) then
					local tName = if (endIdx + side) % 3 == 0 then "WarBannerPole"
						elseif (endIdx + side) % 3 == 1 then "ChainAnchorBollard"
						else "ShutteredWardlight"
					local sc = if tName == "ChainAnchorBollard" then 0.34 elseif tName == "WarBannerPole" then 0.85 else 0.95
					local tint = if tName == "ShutteredWardlight" then SHUTTER_TINT else DREAD_49
					placeProp("LinkDressing", tName, px, base[2], pz, yaw + side * 90, sc, tint, nil, 3.0)
				end
			end
		end
	end

	-- Curated Fortress Vignettes across Bastion terraces, Glacis & Outer Cliff Flanks (diverse templates!)
	local curatedVignettes = {
		-- Bastion of Hooks & West Flank
		{ "BladeDisplay", -298, 16, 102, 45, 0.95 },
		{ "ArmourRack", -232, 16, 108, -120, 0.95 },
		{ "ChainWinch", -338, 24, -44, -90, 0.85 },
		{ "ChainHoist", -340, 24, -96, -90, 0.85 },
		{ "SiegeBallista", -302, 24, -68, -90, 0.85 },
		-- Bastion of Axes & East Flank
		{ "ExecutionYardSet", 232, 20, 108, 135, 0.85 },
		{ "BladeDisplay", 298, 20, 102, -45, 0.95 },
		{ "ArmourRack", 338, 28, -44, 90, 0.95 },
		{ "SiegeBallista", 302, 28, -68, 90, 0.85 },
		{ "ChainWinch", 340, 28, -96, 90, 0.85 },
		-- North Curtains & Dread Bastions
		{ "WatchBellGallows", -168, 44, -278, 180, 0.9 },
		{ "WatchBellGallows", 168, 48, -278, 180, 0.9 },
		{ "SiegeHookCrane", -298, 32, -248, -145, 0.78 },
		{ "SiegeHookCrane", 298, 36, -248, 145, 0.78 },
		{ "PenitentCage", -112, 44, -320, 180, 0.9 },
		{ "PenitentCage", 112, 48, -320, 180, 0.9 },
		-- Glacis outer flank defences & fallen Vahl
		{ "WardenSkeleton", -210, 0, 224, 30, 0.85 },
		{ "WardenSkeleton", 210, 0, 224, -30, 0.85 },
		{ "WardenSkeleton", -360, 0, 260, 75, 0.9 },
		{ "WardenSkeleton", 360, 0, 260, -75, 0.9 },
		{ "KneelingKnight", -56, 8, 344, 15, 1.1 },
		{ "KneelingKnight", 56, 8, 344, -15, 1.1 },
		{ "KneelingKnight", -150, 52, -44, 100, 0.95 },
		{ "KneelingKnight", 150, 56, -44, -100, 0.95 },
		-- Far Outer Bastion Watchtowers & Spires (three skyline layers)
		{ "StormkeepRoundTower", -382, -10, -140, 90, 1.45 },
		{ "StormkeepRoundTower", 382, -10, -140, -90, 1.45 },
		{ "ShatteredWatchtower", -378, -10, 165, 60, 1.25 },
		{ "ShatteredWatchtower", 378, -10, 165, -60, 1.25 },
		{ "FaultRetainingButtress", -358, -10, -70, -90, 1.65 },
		{ "FaultRetainingButtress", 358, -10, -70, 90, 1.65 },
		{ "VaultRibArch", -210, -10, -346, 0, 0.78 },
		{ "VaultRibArch", 210, -10, -346, 0, 0.78 },
		{ "GothicPillarColonnade", -366, -10, -290, 40, 1.35 },
		{ "GothicPillarColonnade", 366, -10, -290, -40, 1.35 },
	}
	for _, cv in curatedVignettes do
		local tName, vx, vy, vz, yaw, sc = cv[1], cv[2], cv[3], cv[4], cv[5], cv[6]
		if spotFree(vx, vz, 5.0, true) then
			placeProp("CitadelVignette", tName, vx, vy, vz, yaw, sc, SHUTTER_TINT, nil, 5.0)
		end
	end

	-- =========================================================================
	-- D. MULTI-PASS STAR-FORT SCATTER (>= 660 props, >= 39 templates, <= 11% cap)
	-- =========================================================================
	-- Note: Cap every single template well below 11% (max 28 per template across ~700 props = ~4% max share!)
	local scatterPool = {
		{ Name = "CurtainWallCrenel", SMin = 0.65, SMax = 0.95, R = 8.0, Tint = DREAD_49 },
		{ Name = "CurtainWallSegment", SMin = 0.70, SMax = 1.05, R = 7.5, Tint = SHUTTER_TINT },
		{ Name = "CurtainWallRuins", SMin = 0.55, SMax = 0.85, R = 8.5, Tint = SHUTTER_TINT },
		{ Name = "RampartWallSegment", SMin = 0.75, SMax = 1.05, R = 7.5, Tint = SHUTTER_TINT },
		{ Name = "PalisadeWallSpan", SMin = 0.80, SMax = 1.10, R = 6.5, Tint = DREAD_49 },
		{ Name = "IronStakePalisade", SMin = 0.85, SMax = 1.15, R = 7.0, Tint = DREAD_49 },
		{ Name = "ChainGalleryRail", SMin = 0.75, SMax = 1.05, R = 7.0, Tint = SHUTTER_TINT },
		{ Name = "BulwarkWall", SMin = 0.65, SMax = 0.95, R = 8.5, Tint = SHUTTER_TINT },
		{ Name = "FaultRetainingButtress", SMin = 0.80, SMax = 1.25, R = 7.5, Tint = SHUTTER_TINT },
		{ Name = "ArchPierBase", SMin = 0.90, SMax = 1.35, R = 5.0, Tint = DREAD_49 },
		{ Name = "ArchPierSegment", SMin = 0.90, SMax = 1.35, R = 4.5, Tint = DREAD_49 },
		{ Name = "ChainAnchorBollard", SMin = 0.42, SMax = 0.68, R = 5.5, Tint = SHUTTER_TINT },
		{ Name = "WarBannerPole", SMin = 0.85, SMax = 1.15, R = 3.5, Tint = DREAD_49 },
		{ Name = "ShutteredWardlight", SMin = 0.90, SMax = 1.15, R = 3.0, Tint = SHUTTER_TINT },
		{ Name = "DreadguardSentry", SMin = 0.75, SMax = 1.05, R = 5.0, Tint = DREAD_49 },
		{ Name = "ArmourStandPlate", SMin = 0.90, SMax = 1.15, R = 3.5, Tint = DREAD_49 },
		{ Name = "ArmourRack", SMin = 0.85, SMax = 1.10, R = 4.5, Tint = DREAD_49 },
		{ Name = "BladeDisplay", SMin = 0.85, SMax = 1.15, R = 4.5, Tint = DREAD_49 },
		{ Name = "PenitentCage", SMin = 0.80, SMax = 1.05, R = 4.5, Tint = DREAD_49 },
		{ Name = "ExecutionYardSet", SMin = 0.78, SMax = 1.00, R = 6.0, Tint = DREAD_49 },
		{ Name = "WatchBellGallows", SMin = 0.80, SMax = 1.05, R = 5.0, Tint = DREAD_49 },
		{ Name = "ChainWinch", SMin = 0.78, SMax = 1.05, R = 5.0, Tint = SHUTTER_TINT },
		{ Name = "ChainHoist", SMin = 0.75, SMax = 1.05, R = 3.5, Tint = SHUTTER_TINT },
		{ Name = "SiegeBallista", SMin = 0.75, SMax = 0.95, R = 7.5, Tint = DREAD_49 },
		{ Name = "AbyssReliquaryShrine", SMin = 0.65, SMax = 0.90, R = 7.5, Tint = SHUTTER_TINT },
		{ Name = "HangingAbyssChain", SMin = 0.75, SMax = 1.15, R = 4.0, Tint = SHUTTER_TINT },
		{ Name = "ObsidianSpire", SMin = 0.55, SMax = 1.15, R = 7.5, Tint = FAR_SPIRE_TINT },
		{ Name = "VoidShards", SMin = 0.85, SMax = 1.45, R = 4.0, Tint = SHUTTER_TINT },
		{ Name = "WardenSkeleton", SMin = 0.75, SMax = 1.05, R = 6.0, Tint = DREAD_49 },
		{ Name = "KneelingKnight", SMin = 0.90, SMax = 1.25, R = 4.0, Tint = DREAD_49 },
		{ Name = "StoneUrn", SMin = 0.80, SMax = 1.25, R = 3.5, Tint = DREAD_49 },
		{ Name = "RuinRubble", SMin = 0.85, SMax = 1.40, R = 4.5, Tint = DREAD_49 },
		{ Name = "BoulderCluster", SMin = 0.85, SMax = 1.55, R = 5.0, Tint = DREAD_49 },
		{ Name = "CliffRockA", SMin = 0.24, SMax = 0.42, R = 8.0, Tint = DREAD_49 },
		{ Name = "CliffRockB", SMin = 0.24, SMax = 0.42, R = 8.0, Tint = DREAD_49 },
		{ Name = "BlightTree", SMin = 0.42, SMax = 0.68, R = 9.0, Tint = SHUTTER_TINT },
		{ Name = "ShatteredWatchtower", SMin = 0.70, SMax = 1.00, R = 8.5, Tint = SHUTTER_TINT },
		{ Name = "StormkeepRoundTower", SMin = 0.70, SMax = 1.05, R = 8.5, Tint = SHUTTER_TINT },
		{ Name = "GothicPillarColonnade", SMin = 0.75, SMax = 1.10, R = 5.5, Tint = SHUTTER_TINT },
	}

	local maxPerTemplate = 24
	local targetProps = 700
	local halfRoomW = ctx.w * 0.5 - 16
	local halfRoomD = ctx.d * 0.5 - 16
	for attempt = 1, 9000 do
		if placedProps >= targetProps then
			break
		end
		local item = scatterPool[(attempt % #scatterPool) + 1]
		if (templateCounts[item.Name] or 0) >= maxPerTemplate then
			continue
		end
		local x = rng:NextNumber(-halfRoomW, halfRoomW)
		local z = rng:NextNumber(-halfRoomD, halfRoomD)
		-- Keep moat basin & Sanctuary clear of heavy props
		if (x / 128) ^ 2 + ((z + 90) / 96) ^ 2 < 1.0 then
			continue
		end
		if z > 322 then
			continue
		end
		if not spotFree(x, z, item.R, false) then
			continue
		end
		local y = groundY(x, z)
		local sc = rng:NextNumber(item.SMin, item.SMax)
		local yaw = rng:NextNumber(0, 360)
		local dTag = if item.Name == "HangingAbyssChain" then "DirgeChain" else nil
		placeProp("CitadelScatter", item.Name, x, y - 0.35, z, yaw, sc, item.Tint, nil, item.R, dTag)
	end

	-- Pass E: Lightweight Ground Cover Clumps (>= 480 TowerDetail clumps: ash drifts, bone rubble, caltrops)
	local targetCover = 490
	for attempt = 1, 5000 do
		if groundCoverCount >= targetCover then
			break
		end
		local x = rng:NextNumber(-halfRoomW, halfRoomW)
		local z = rng:NextNumber(-halfRoomD, halfRoomD)
		-- Keep off Apex arena, Keep moat core, Sanctuary, camps & lanes
		if (x / 124) ^ 2 + ((z + 90) / 92) ^ 2 < 1.0 then
			continue
		end
		if z > 328 or onApexArena(x, z, 8) or not campFree(x, z, 4) or not ctx.footprintClear(x, z, 4, 4) then
			continue
		end
		local y = groundY(x, z)
		local kindIdx = attempt % 3
		local yaw = rng:NextNumber(0, math.pi * 2)
		ctx.group("GroundCover", function()
			local grp = ctx.current()
			if kindIdx == 0 then
				-- Ash drift & obsidian chips
				local s1 = rng:NextNumber(2.8, 5.2)
				boxAt("AshDriftMound", CFrame.new(V(x, y + 0.35, z)) * CFrame.Angles(0, yaw, 0), V(s1, 0.7, s1 * 0.72), ASH_GREY, Mat.Slate)
				boxAt("ObsidianChip", CFrame.new(V(x + 0.8, y + 0.6, z - 0.4)) * CFrame.Angles(0.2, yaw + 0.7, 0.1), V(1.2, 1.4, 1.0), OBSIDIAN, Mat.Basalt)
			elseif kindIdx == 1 then
				-- Bone-white marble rubble & dark iron shard
				boxAt("BoneRubbleA", CFrame.new(V(x, y + 0.45, z)) * CFrame.Angles(0.1, yaw, -0.1), V(1.8, 0.9, 1.4), BONE_MARBLE, Mat.Limestone)
				boxAt("IronShard", CFrame.new(V(x - 1.0, y + 0.55, z + 0.5)) * CFrame.Angles(-0.3, yaw + 1.1, 0.2), V(0.7, 1.5, 0.7), IRON_BLACK, Mat.Metal)
			else
				-- Iron caltrop & ash patch
				boxAt("AshPatch", CFrame.new(V(x, y + 0.25, z)) * CFrame.Angles(0, yaw, 0), V(3.4, 0.5, 2.8), ASH_GREY, Mat.Slate)
				boxAt("IronCaltrop", CFrame.new(V(x, y + 0.65, z)) * CFrame.Angles(0.4, yaw, 0.4), V(0.45, 1.6, 0.45), IRON_DARK, Mat.Metal)
			end
			makeDecor(grp)
			pin(grp)
			for _, d in grp:GetDescendants() do
				if d:IsA("BasePart") then
					safeTag(d, "TowerDetail")
				end
			end
		end)
		groundCoverCount += 1
	end

	-- =========================================================================
	-- E. SKYLINE: NORTH CRIMSON HORIZON GLOW, HAIRLINE RIFT, COURT SILHOUETTES & ASH
	-- =========================================================================
	ctx.group("AbyssalSkyHorizon", function()
		-- Faint crimson glow on the far north sky horizon (Y = 110..210, >= 70 studs above NorthBastion Y=40!)
		addSkyCurtain("NorthHorizonCrimsonA", V(-340, 128, -388), V(340, 128, -388), 54, 54, rgb(86, 18, 34), HORIZON_CRIMSON, 0.68)
		addSkyCurtain("NorthHorizonCrimsonB", V(-180, 114, -384), V(180, 114, -384), 32, 32, HORIZON_CRIMSON, rgb(184, 34, 54), 0.58)
		-- Closing hairline pale Rift high overhead in the black vault (Y = 266..278)
		addSkyCurtain("VaultHairlineRift", V(-220, 274, -220), V(220, 266, -240), 2.8, 1.8, SILVER_KEY, WARDLIGHT_BONE, 0.32)

		-- Distant silent court silhouettes standing watch on far abyss ledges (tagged DirgeSilhouette)
		local silSpots = {
			{ -392, 64, -220, 115 }, { -394, 58, -120, 95 }, { -392, 52, -20, 85 },
			{ 392, 64, -220, -115 }, { 394, 58, -120, -95 }, { 392, 52, -20, -85 },
			{ -180, 74, -376, 175 }, { -90, 72, -378, 180 }, { 90, 72, -378, 180 }, { 180, 74, -376, -175 },
		}
		for _, ss in silSpots do
			local cf = CFrame.new(V(ss[1], ss[2], ss[3])) * CFrame.Angles(0, math.rad(ss[4]), 0)
			local body = boxAt("CourtSilhouette", cf * CFrame.new(0, 5.5, 0), V(3.2, 11.0, 2.2), OBSIDIAN_DARK, Mat.SmoothPlastic)
			tagDirge(body, "DirgeSilhouette")
			local head = lump("CourtSilhouetteHead", (cf * CFrame.new(0, 11.8, 0)).Position, V(2.0, 2.4, 2.0), OBSIDIAN_DARK, Mat.SmoothPlastic)
			tagDirge(head, "DirgeSilhouette")
		end

		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	-- =========================================================================
	-- F. THE THRONE GATE: the citadel guards the way into the Throne (Floor 50). Its colossal gate stands in
	-- the north wall behind the North Bastion: twin gate towers, closed iron doors above the Bastion's prow
	-- (the threshold), a pointed arch and gable crowned by the Chained Crown sigil, wine banners, and a thin
	-- crimson glow between the door leaves. Solid masonry, all behind the North Bastion's camp and lanes.
	-- =========================================================================
	ctx.group("ThroneGate", function()
		local fz = -381 -- the façade's front face
		boxAt("ThroneGateFacade", CFrame.new(V(0, 115, fz - 10)), V(260, 250, 20), OBSIDIAN, Mat.Basalt)
		boxAt("ThroneGateGable", CFrame.new(V(0, 262, fz - 8)), V(64, 44, 16), OBSIDIAN, Mat.Basalt)
		-- The gable roofline: two raking beams from the façade's corners to a peak over the sigil.
		local gRun, gRise = 130, 60
		local gLen, gTilt = math.sqrt(gRun * gRun + gRise * gRise), math.atan2(gRise, gRun)
		for _, side in { -1, 1 } do
			boxAt("ThroneGateGableRake", CFrame.new(V(side * gRun / 2, 240 + gRise / 2, fz - 6)) * CFrame.Angles(0, 0, -side * gTilt), V(gLen, 10, 14), IRON_BLACK, Mat.Metal)
		end
		-- The doorway: jambs, a pointed arch and two closed iron leaves on the Bastion prow (Y 72).
		local doorBase, doorTop, halfSpan = 72, 202, 44
		for _, side in { -1, 1 } do
			boxAt("ThroneGateJamb", CFrame.new(V(side * halfSpan, (doorBase + doorTop) / 2, fz + 2)), V(8, doorTop - doorBase, 6), IRON_BLACK, Mat.Metal)
			local aRise = 38
			local aLen, aTilt = math.sqrt(halfSpan * halfSpan + aRise * aRise), math.atan2(aRise, halfSpan)
			boxAt("ThroneGateArch", CFrame.new(V(side * halfSpan / 2, doorTop + aRise / 2, fz + 2)) * CFrame.Angles(0, 0, -side * aTilt), V(aLen, 8, 6), IRON_BLACK, Mat.Metal)
			boxAt("ThroneGateDoorLeaf", CFrame.new(V(side * 20.5, (doorBase + doorTop) / 2, fz + 0.5)), V(39, doorTop - doorBase - 2, 3), IRON_DARK, Mat.Metal)
			for _, by in { 92, 122, 152, 182 } do
				boxAt("ThroneGateDoorStrap", CFrame.new(V(side * 20.5, by, fz + 2.3)), V(37, 2.2, 0.8), IRON_BLACK, Mat.Metal)
			end
			boxAt("ThroneGateDoorRing", CFrame.new(V(side * 6, 132, fz + 2.6)), V(4, 4, 0.8), SILVER_KEY, Mat.Metal)
		end
		-- Never a crimson light (the §5.7 telegraph rule): the slit glows on its own, far from any walkway.
		boxAt("ThroneGateCrimsonSlit", CFrame.new(V(0, (doorBase + doorTop) / 2, fz + 2.1)), V(1.4, doorTop - doorBase - 4, 0.6), rgb(110, 18, 30), Mat.Neon)
		-- Twin gate towers with iron bands, crenellated caps, spires and long wine banners.
		for _, side in { -1, 1 } do
			local tx = side * 64
			boxAt("ThroneGateTower", CFrame.new(V(tx, 140, fz - 4)), V(36, 300, 36), OBSIDIAN_MID, Mat.Basalt)
			for _, by in { 72, 150, 222 } do
				boxAt("ThroneGateTowerBand", CFrame.new(V(tx, by, fz - 4)), V(37.6, 3, 37.6), IRON_BLACK, Mat.Metal)
			end
			boxAt("ThroneGateTowerCap", CFrame.new(V(tx, 294, fz - 4)), V(42, 8, 42), OBSIDIAN, Mat.Basalt)
			for _, c in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
				boxAt("ThroneGateMerlon", CFrame.new(V(tx + c[1] * 16, 303, fz - 4 + c[2] * 16)), V(8, 10, 8), OBSIDIAN, Mat.Basalt)
			end
			boxAt("ThroneGateSpire", CFrame.new(V(tx, 328, fz - 4)), V(10, 60, 10), IRON_BLACK, Mat.Metal)
			boxAt("ThroneGateWineBanner", CFrame.new(V(tx, 176, fz + 14.6)), V(18, 132, 1), WINE_SILK, Mat.Fabric)
			boxAt("ThroneGateBannerRod", CFrame.new(V(tx, 243, fz + 15)), V(22, 1.2, 1.2), IRON_BLACK, Mat.Metal)
		end
		-- The Chained Crown sigil over the arch: a bone-marble ring and five crown points.
		ctx.ring("ThroneGateSigilRing", V(0, 262, fz + 1), 12, 1.4, BONE_MARBLE, Mat.Limestone, nil, 0, math.pi * 2, 20)
		for k = -2, 2 do
			local h = 10 - math.abs(k) * 2.5
			boxAt("ThroneGateCrownPoint", CFrame.new(V(k * 5.5, 276 + h / 2, fz + 1)), V(2.2, h, 1.2), BONE_MARBLE, Mat.Limestone)
		end
		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	-- Drifting ash emitters blowing north toward the Keep & Throne (<= 16 emitters)
	for _, ae in {
		V(0, 10, 240), V(-180, 8, 220), V(180, 8, 220),
		V(-265, 24, 75), V(265, 28, 75), V(0, 22, 110),
		V(-270, 40, -215), V(270, 44, -215), V(0, 48, -320),
		V(-110, 8, -90), V(110, 8, -90), V(0, 72, -140),
	} do
		addAshEmitter(ae, 5)
	end

	local distinctCount = 0
	for _ in templateCounts do
		distinctCount += 1
	end

	ctx.setAttribute("AbyssalFloor", 49)
	ctx.setAttribute("AbyssalLights", lightsUsed)
	ctx.setAttribute("AbyssalEmitters", emittersUsed)
	ctx.setAttribute("PlacedPropCount", placedProps)
	ctx.setAttribute("GroundCoverCount", groundCoverCount)
	ctx.setAttribute("DistinctTemplateCount", distinctCount)
	ctx.setAttribute("SetPieceLightCount", lightsUsed)
end

return AbyssalFloor49
