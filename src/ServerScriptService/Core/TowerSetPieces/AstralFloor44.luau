--!strict
-- Hand-authored set pieces for Astral Archives Floor 44: Runeguard Athenaeum (astral:4, ELITE_STRONGHOLD).
-- Design: docs/prompts/astral-archives-floor-layouts-prompt.md (Floor 44).
--
-- Sealed by the Runeguard: three stepped wards separated by two wall-to-wall rune-ward moats & glowing
-- glyph veils, pierced only by the alternating West and East Waygates (the only unshuttered gold lamps on
-- the floor), crowned by the 222-stud chained Athenaeum Dome over the Sealed Stacks (back-east, Y 60).
local CollectionService = game:GetService("CollectionService")
local InfernalFoundry = require(script.Parent.InfernalFoundry)

local AstralFloor44 = {}

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

-- Sealed indigo dusk palette: dim lapis & slate masonry, gold-leaf ribs, aged brass chains & shuttered
-- lamps, luminous pale ice-silver glyph veils and warm pale starlight gold inside the two Waygates.
local RIFTWARD_44 = table.freeze({
	STONE = swatch(178, 174, 172, Mat.Limestone),
	ALT = swatch(34, 38, 72, Mat.Marble),
	TRIM = swatch(206, 176, 102, Mat.Metal),
	METAL = swatch(166, 134, 76, Mat.Metal),
	WOOD = swatch(44, 34, 38, Mat.Wood),
	SILK = swatch(226, 218, 202, Mat.Fabric),
	GLOW = swatch(244, 224, 162, Mat.Neon),
	CRYSTAL = swatch(148, 198, 238, Mat.Glass, 0.24),
	MOSS = swatch(74, 98, 114, Mat.Grass),
})

local WARD_VEIL_TINT = tinted(RIFTWARD_44, {
	GLOW = swatch(168, 214, 250, Mat.Neon),
	CRYSTAL = swatch(132, 186, 240, Mat.Glass, 0.36),
})

local SHUTTER_TINT = tinted(RIFTWARD_44, {
	GLOW = swatch(92, 98, 128, Mat.SmoothPlastic), -- shuttered dark behind rune-plates
})

local GOLD_LIGHT = rgb(244, 224, 162)
local WARD_LIGHT = rgb(168, 214, 250)

-- Floor 44's 22 landmark footprints (local floor space, 800 x 795).
AstralFloor44.Landmarks = table.freeze({
	-- 1–2. The Athenaeum Dome over The Sealed Stacks (118 + 104.1 = 222.1 >= 210 studs tall!)
	{ Id = "AthenaeumDomeCrown", X = 230, Z = -300, Y = 174, HalfX = 51.3, HalfZ = 51.4, Top = 104.2, Straddles = true },
	{ Id = "AthenaeumDomeDrum", X = 230, Z = -300, Y = 60, HalfX = 71.0, HalfZ = 50.6, Top = 118.0, Straddles = true },
	-- 3–4. The Two Waygate Ring-Portals (only crossings of the two wards, only unshuttered lamps)
	{ Id = "WestWaygateRing", X = -130, Z = -15, Y = 20, HalfX = 18.7, HalfZ = 4.0, Top = 37.9, Straddles = true },
	{ Id = "EastWaygateRing", X = 140, Z = -195, Y = 44, HalfX = 18.7, HalfZ = 4.0, Top = 37.9, Straddles = true },
	-- 5–6. West & East Runeguard Bastion Towers (outer flanks, >= 80 studs from bastion camps)
	{ Id = "WestRuneguardTower", X = -354, Z = -110, Y = 32, HalfX = 15.5, HalfZ = 15.5, Top = 36.6 },
	{ Id = "EastRuneguardTower", X = 344, Z = -120, Y = 36, HalfX = 15.5, HalfZ = 15.5, Top = 36.6 },
	-- 7. Hall of Indices great star-glyph board
	{ Id = "HallIndexBoard", X = -10, Z = -132, Y = 28, HalfX = 10.8, HalfZ = 1.8, Top = 14.1 },
	-- 8. Seal Forge star-iron anvil
	{ Id = "SealForgeAnvil", X = 110, Z = -102, Y = 24, HalfX = 7.5, HalfZ = 4.4, Top = 13.3 },
	-- 9. Court of Seals sealing press
	{ Id = "CourtSealPress", X = 30, Z = -342, Y = 52, HalfX = 8.6, HalfZ = 3.0, Top = 10.0 },
	-- 10. Forbidden Vault half-open brass ring door
	{ Id = "ForbiddenVaultDoor", X = -60, Z = -364, Y = 56, HalfX = 13.0, HalfZ = 13.5, Top = 23.0 },
	-- 11. Reliquary of Lenses ground-lens rack
	{ Id = "ReliquaryLensRack", X = -200, Z = -328, Y = 48, HalfX = 8.6, HalfZ = 2.4, Top = 13.5 },
	-- 12. Lantern Walk chained confiscated tomes
	{ Id = "LanternWalkTomeRack", X = -130, Z = -200, Y = 40, HalfX = 6.2, HalfZ = 5.5, Top = 16.9 },
	-- 13. Copyists' Yard shaded awning
	{ Id = "CopyistAwningW", X = -354, Z = 70, Y = 12, HalfX = 5.8, HalfZ = 3.6, Top = 9.0 },
	-- 14. Binders' Yard sewing frame
	{ Id = "BindersSewingFrame", X = 318, Z = 70, Y = 16, HalfX = 6.0, HalfZ = 1.8, Top = 7.6 },
	-- 15. Porters' Lodge book-cart lift
	{ Id = "PortersBookCart", X = 126, Z = 46, Y = 4, HalfX = 7.3, HalfZ = 4.6, Top = 15.6 },
	-- 16–18. First Rune-Ward Pylons along Z = -22 (leaving West Waygate open at X = -130)
	{ Id = "Ward1PylonWest", X = -260, Z = -22, Y = 10, HalfX = 4.0, HalfZ = 4.0, Top = 27.0 },
	{ Id = "Ward1PylonMid", X = -30, Z = -22, Y = 10, HalfX = 4.0, HalfZ = 4.0, Top = 27.0 },
	{ Id = "Ward1PylonEast", X = 210, Z = -22, Y = 10, HalfX = 4.0, HalfZ = 4.0, Top = 27.0 },
	-- 19–21. Second Rune-Ward Pylons along Z = -215..-235 (leaving East Waygate open at X = 140)
	{ Id = "Ward2PylonWest", X = -280, Z = -216, Y = 30, HalfX = 4.0, HalfZ = 4.0, Top = 27.0 },
	{ Id = "Ward2PylonMid", X = -50, Z = -220, Y = 34, HalfX = 4.0, HalfZ = 4.0, Top = 27.0 },
	{ Id = "Ward2PylonEast", X = 324, Z = -234, Y = 38, HalfX = 4.0, HalfZ = 4.0, Top = 27.0 },
	-- 22. Warded Court waiting circle pad (clear of Crossing camp and lanes)
	{ Id = "WardedCircleFloor", X = -166, Z = 95, Y = 8, HalfX = 12.0, HalfZ = 12.0, Top = 0.5 },
}) :: { Landmark }

local function safeTag(inst: Instance?, tagName: string)
	if inst then
		pcall(function()
			CollectionService:AddTag(inst, tagName)
		end)
	end
end

function AstralFloor44.Build(ctx: any)
	local H = InfernalFoundry.Helpers(ctx)
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
	local function tagDetail(m: Instance?)
		if not m then return end
		noCollide(m)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.CastShadow = false
				safeTag(d, "TowerDetail")
			end
		end
	end
	local function pageEmitter(pos: Vector3, rate: number)
		if emittersUsed >= 12 then return end
		emittersUsed += 1
		local anchor = ctx.block("PageDriftAnchor", V(1, 1, 1), pos, RIFTWARD_44.SILK.Color, Mat.SmoothPlastic, nil, 1)
		anchor.CanCollide, anchor.CanQuery, anchor.CastShadow = false, false, false
		anchor:SetAttribute("ConjunctionPageEmitter", true)
		safeTag(anchor, "ConjunctionPageEmitter")
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "AstralPages"
		pe.Color = ColorSequence.new(rgb(232, 224, 206), rgb(168, 214, 250))
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(0.5, 1.0), NumberSequenceKeypoint.new(1, 0.3) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.8, 0.4), NumberSequenceKeypoint.new(1, 1) })
		pe.Lifetime = NumberRange.new(3.0, 5.0)
		pe.Rate = rate
		pe.Speed = NumberRange.new(1.2, 2.8)
		pe.SpreadAngle = Vector2.new(50, 50)
		pe.RotSpeed = NumberRange.new(-55, 55)
		pe.Acceleration = V(0, 0.4, 0)
		pe.Parent = anchor
	end

	for _, lm in AstralFloor44.Landmarks do
		ctx.reserve(lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ))
	end

	-- 1–2. The Athenaeum Dome (222.1 studs tall over the Sealed Stacks, visible over both ward walls from arrival!)
	do
		local drum = AstralFloor44.Landmarks[2]
		local md = piece("AstralDome", drum.X, drum.Z, 0, "AthenaeumDomeDrum", 1.0, RIFTWARD_44, function(cf)
			for i = 0, 7 do
				local a = i * math.pi / 4
				if math.abs(a - math.pi / 2) > 0.4 and math.abs(a - math.pi) > 0.4 then
					boxAt("DomePier", cf * CFrame.new(math.cos(a) * 62, 58, math.sin(a) * 44), V(8, 116, 8), RIFTWARD_44.STONE.Color, Mat.Limestone)
				end
			end
		end, drum.Y)
		pin(md)
		noCollide(md)
		if md then addLight(H.glowOf(md), GOLD_LIGHT, 2.0, 100) end

		local crown = AstralFloor44.Landmarks[1]
		local mc = piece("AstralDome", crown.X, crown.Z, 0, "AthenaeumDomeCrown", 1.0, RIFTWARD_44, function(cf)
			ctx.orb("DomeCap", cf.Position + V(0, 50, 0), V(98, 98, 98), RIFTWARD_44.ALT.Color, Mat.Marble)
		end, crown.Y)
		pin(mc)
		noCollide(mc)
	end

	-- 3–4. The Two Waygate Ring-Portals (the ONLY unshuttered warm-gold lamps on Floor 44!)
	for _, idx in { 3, 4 } do
		local lm = AstralFloor44.Landmarks[idx]
		local mw = piece("AstralGateRing", lm.X, lm.Z, 0, "WaygateRing", 1.0, RIFTWARD_44, function(cf)
			ctx.ring("WaygateFallback", cf.Position + V(0, 19, 0), 17, 2.6, RIFTWARD_44.TRIM.Color, Mat.Metal, nil, 0, math.pi * 2, 18)
		end, lm.Y)
		pin(mw)
		noCollide(mw)
		if mw then
			mw:SetAttribute("ConjunctionLamp", true)
			safeTag(mw, "ConjunctionLamp")
			addLight(H.glowOf(mw), GOLD_LIGHT, 2.2, 68)
		end
	end

	-- 5–15. Fortress-library wing landmarks
	local propSpecs = {
		{ AstralFloor44.Landmarks[5], "RuneguardTower", 90, 1.30 },
		{ AstralFloor44.Landmarks[6], "RuneguardTower", -90, 1.30 },
		{ AstralFloor44.Landmarks[7], "IndexBoard", 0, 1.15 },
		{ AstralFloor44.Landmarks[8], "StarIronAnvil", -90, 1.15 },
		{ AstralFloor44.Landmarks[9], "SealPress", 0, 1.10 },
		{ AstralFloor44.Landmarks[10], "VaultRingDoor", 0, 1.35 },
		{ AstralFloor44.Landmarks[11], "LensRack", 0, 1.10 },
		{ AstralFloor44.Landmarks[12], "ChainedTomeRack", 0, 1.10 },
		{ AstralFloor44.Landmarks[13], "CopyistAwning", 90, 1.15 },
		{ AstralFloor44.Landmarks[14], "SewingFrame", -90, 1.10 },
		{ AstralFloor44.Landmarks[15], "BookCartLift", 25, 1.10 },
	}
	for _, spec in propSpecs do
		local lm = spec[1]
		local m = piece(lm.Id, lm.X, lm.Z, spec[3], spec[2], spec[4], RIFTWARD_44, function(cf)
			boxAt(lm.Id .. "Fallback", cf * CFrame.new(0, lm.Top * 0.5, 0), V(lm.HalfX * 1.8, lm.Top, lm.HalfZ * 1.8), RIFTWARD_44.STONE.Color, Mat.Limestone)
		end, lm.Y)
		pin(m)
		if spec[2] == "IndexBoard" or spec[2] == "StarIronAnvil" or spec[2] == "VaultRingDoor" then
			addLight(H.glowOf(m) or (m and m:FindFirstChildWhichIsA("BasePart", true)), GOLD_LIGHT, 1.6, 56)
		end
	end

	-- 16–21. Rune-Ward Pylons + Shimmering Glyph Veils spanning both wall-to-wall ward moats!
	for _, idx in { 16, 17, 18, 19, 20, 21 } do
		local lm = AstralFloor44.Landmarks[idx]
		local mp = piece(lm.Id, lm.X, lm.Z, 0, "RunewardPylon", 1.0, WARD_VEIL_TINT, function(cf)
			boxAt("WardPylon", cf * CFrame.new(0, 13, 0), V(7, 26, 7), RIFTWARD_44.ALT.Color, Mat.Marble)
		end, lm.Y)
		pin(mp)
		if idx == 17 or idx == 20 then
			addLight(H.glowOf(mp), WARD_LIGHT, 1.5, 60)
		end
	end

	-- Unbroken Wall-to-Wall Rune-Ward Glyph Veils spanning both moats (open ONLY at West Waygate X=-130 and East Waygate X=+140!)
	local veilSpans: { { number } } = {}
	-- Ward 1 (Z = -22): continuous 36-stud veils across X = -376..-186 and X = -74..+376
	for x = -376, -186, 36 do
		table.insert(veilSpans, { x, 10, -22 })
	end
	for x = -74, 376, 36 do
		table.insert(veilSpans, { x, 10, -22 })
	end
	-- Ward 2 (Z = -215 west to -235 east): continuous 36-stud veils across X = -376..+84 and X = +196..+376
	for x = -376, 84, 36 do
		local t = (x + 400) / 800
		table.insert(veilSpans, { x, 30 + t * 8, -215 - t * 20 })
	end
	for x = 196, 376, 36 do
		local t = (x + 400) / 800
		table.insert(veilSpans, { x, 30 + t * 8, -215 - t * 20 })
	end
	for i, sp in veilSpans do
		local mv = piece("AstralWardVeil", sp[1], sp[3], 0, "RunewardVeil", 1.0, WARD_VEIL_TINT, function(cf)
			boxAt("WardVeilFallback", cf * CFrame.new(0, 9.5, 0), V(36, 19, 2), WARD_VEIL_TINT.GLOW.Color, Mat.Neon, 0.35)
		end, sp[2])
		pin(mv)
		noCollide(mv)
		if mv then
			mv:SetAttribute("ConjunctionGlyph", true)
			safeTag(mv, "ConjunctionGlyph")
			if i == 8 or i == 22 then
				addLight(H.glowOf(mv), WARD_LIGHT, 1.5, 64)
			end
		end
	end

	-- 22. Warded Court warding circle pad
	do
		local lm = AstralFloor44.Landmarks[22]
		local mp = piece(lm.Id, lm.X, lm.Z, 0, "WardedCirclePad", 1.0, RIFTWARD_44, function(cf)
			ctx.cyl("WardedCircle", cf.Position + V(0, 0.2, 0), 12, 0.4, RIFTWARD_44.TRIM.Color, Mat.Metal)
		end, lm.Y)
		pin(mp)
		tagDetail(mp)
	end

	-- Shuttered Lamps everywhere along the wards (dark behind rune-plates — contrast with the two Waygates!)
	for i, sp in {
		{ -190, 0, 196 }, { 190, 0, 196 },
		{ -230, 12, 70 }, { 190, 16, 70 },
		{ -210, 32, -110 }, { 200, 36, -120 },
		{ -100, 40, -165 }, { 0, 52, -300 },
	} do
		local ms = piece("AstralShutteredLamp", sp[1], sp[3], i * 40, "ShutteredLamp", 1.0, SHUTTER_TINT, function(cf)
			ctx.cyl("ShutteredPost", cf.Position + V(0, 6, 0), 0.7, 12, SHUTTER_TINT.METAL.Color, Mat.Metal)
		end, sp[2])
		pin(ms)
		tagDetail(ms)
	end

	-- Jagged branching diagonal violet Rift tear slashing across the sky behind the Athenaeum dome (matching guide art!)
	ctx.group("AstralSkyNorthRift", function()
		local mainPts = {
			V(-260, 175, -355), V(-165, 198, -360), V(-90, 206, -364),
			V(-10, 224, -366), V(85, 240, -370), V(180, 256, -374), V(295, 272, -378),
		}
		for i = 1, #mainPts - 1 do
			local t = 1 - math.abs((i - 3.5) / 3.5)
			local seg = ctx.beam("NorthSkyRift", mainPts[i], mainPts[i + 1], 1.6 + t * 3.8, rgb(172, 102, 255), Mat.Neon, 0.08)
			seg:SetAttribute("ConjunctionGlyph", true)
			safeTag(seg, "ConjunctionGlyph")
		end
		-- Forked crackling rift tendrils
		for _, fork in {
			{ V(-90, 206, -364), V(-125, 224, -366) },
			{ V(-10, 224, -366), V(28, 212, -368) },
			{ V(85, 240, -370), V(62, 258, -372) },
		} do
			local fSeg = ctx.beam("NorthSkyRiftFork", fork[1], fork[2], 1.2, rgb(196, 146, 255), Mat.Neon, 0.12)
			fSeg:SetAttribute("ConjunctionGlyph", true)
			safeTag(fSeg, "ConjunctionGlyph")
		end
		noCollide(ctx.current())
		pin(ctx.current())
	end)

	pageEmitter(V(-130, 26, -15), 3)
	pageEmitter(V(140, 50, -195), 3)
	pageEmitter(V(230, 68, -300), 4)

	ctx.setAttribute("AstralFloor", 44)
	ctx.setAttribute("AstralLights", lightsUsed)
end

return AstralFloor44
