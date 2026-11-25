--!strict
-- Hand-authored set pieces for Abyssal Throne Floor 50: Overlord's Throne (abyssal:5, BOSS_ARENA).
-- Design: docs/prompts/abyssal-throne-floor-layouts-prompt.md (Floor 50) & Abyssal Throne 50.jpg.
--
-- Colossal tiered obsidian Throne rising from the flagged Supplicants' Floor: Sabaton Feet, Greave
-- Towers, shattered Broken Grand Stair ending over open void, walled Armrest battlements, colossal
-- open Gauntlet Hands cradling the last two bone-white Wardlights, sweeping Mantle-Chains & caged
-- chain climbs, 212 x 156 clean Seat with worn bone-white Chained Crown floor inlay, >324-stud sheer
-- carved obsidian Backrest with full-height matte wine-silk banners, the Chained Crown (one broken
-- link), the Crimson Eclipse in the black vault, and the deep matte red-black Heart Crack at the base.
--
-- Telegraph safety (§5.7): ZERO crimson or orange light on any walk surface; walk-height Neon is
-- strictly bone-white or pale silver; ThroneHeartCrack is matte SmoothPlastic; CrimsonEclipseDisc
-- sits >= 175 studs above Apex in the far sky layer; Undertow ribbons stay in Y <= -7.5 beds.
local CollectionService = game:GetService("CollectionService")
local InfernalFoundry = require(script.Parent.InfernalFoundry)

local AbyssalFloor50 = {}

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

-- Vahl / Overlord master tint table (zero fallback to generic biome teal/purple; bone-white Wardlight GLOW).
local VAHL_50 = table.freeze({
	STONE = swatch(24, 22, 32, Mat.Basalt),
	ALT = swatch(214, 208, 194, Mat.Marble),
	METAL = swatch(40, 38, 48, Mat.Metal),
	TRIM = swatch(56, 52, 64, Mat.Metal),
	SILK = swatch(114, 22, 34, Mat.Fabric),
	ACCENT = swatch(172, 134, 62, Mat.Metal),
	GOLD = swatch(172, 134, 62, Mat.Metal),
	GLOW = swatch(244, 238, 222, Mat.Neon),
	CRYSTAL = swatch(92, 16, 28, Mat.SmoothPlastic),
	MOSS = swatch(74, 70, 82, Mat.Slate),
	WOOD = swatch(34, 28, 36, Mat.Wood),
	FOLIAGE = swatch(56, 52, 66, Mat.Slate),
})

local SILVER_KEY_TINT = tinted(VAHL_50, {
	GLOW = swatch(226, 228, 236, Mat.Neon),
})

-- ThroneHeartCrack: strictly matte red-black SmoothPlastic, NEVER Neon!
local HEART_CRACK_TINT = tinted(VAHL_50, {
	CRYSTAL = swatch(72, 12, 20, Mat.SmoothPlastic),
	SILK = swatch(72, 12, 20, Mat.SmoothPlastic),
	GLOW = swatch(72, 12, 20, Mat.SmoothPlastic),
})

-- CrimsonEclipseDisc: sky/far layer only (>= 175 studs above Apex).
local ECLIPSE_TINT = tinted(VAHL_50, {
	STONE = swatch(10, 8, 14, Mat.SmoothPlastic),
	TRIM = swatch(14, 10, 18, Mat.SmoothPlastic),
	GLOW = swatch(168, 20, 40, Mat.Neon),
	CRYSTAL = swatch(108, 14, 26, Mat.SmoothPlastic),
})

-- Dark iron & void shard tint for cages / reliquaries (no violet/crimson Neon near walk surfaces).
local RELIC_TINT = tinted(VAHL_50, {
	CRYSTAL = swatch(84, 16, 30, Mat.Glass, 0.15),
	GLOW = swatch(244, 238, 222, Mat.Neon),
})

local OBSIDIAN_DARK = rgb(20, 18, 28)
local OBSIDIAN_MID = rgb(30, 28, 40)
local IRON_BLACK = rgb(44, 42, 54)
local BONE_MARBLE = rgb(212, 206, 192)
local BONE_INLAY = rgb(146, 140, 130)
local WINE_SILK = rgb(114, 22, 34)
local OLD_GOLD = rgb(172, 134, 62)
local WARDLIGHT_BONE = rgb(244, 238, 222)
local SILVER_KEY = rgb(226, 228, 236)
local HEART_MATTE = rgb(72, 12, 20)
local UNDERTOW_VIOLET = rgb(94, 46, 176)
local UNDERTOW_CORE = rgb(134, 84, 224)
local ASH_GREY = rgb(74, 70, 82)

local ABYSS_Y = -8.0

-- Floor 50's 30 landmark footprints inside the 940 x 795 x 370 room (Bottom = -6).
-- Clear of all 29 links + 2 return links, all 8 camps (and 5 mob slots each), the 212 x 156 Seat arena,
-- and both Ascend/Rerun portals at (+-16, 72, -266).
AbyssalFloor50.Landmarks = table.freeze({
	-- 1. Colossal centrepiece: Throne Backrest rising behind the Seat (Y=36 + Top=334 -> Y=370, >= 324 tall!).
	{ Id = "ThroneBackrest", X = 0, Z = -342, Y = 36, HalfX = 72.0, HalfZ = 25.0, Top = 334.0, Straddles = true },
	-- 2. Monumental Chained Crown emblem mounted high on the backrest front face.
	{ Id = "ChainedCrownColossal", X = 0, Z = -316, Y = 238, HalfX = 42.0, HalfZ = 5.0, Top = 84.0, Straddles = true },
	-- 3. Crimson Eclipse burning high in the black vault behind the crown (>= 175 studs above Apex!).
	{ Id = "CrimsonEclipseDisc", X = 0, Z = -384, Y = 250, HalfX = 76.0, HalfZ = 4.0, Top = 152.0, Straddles = true },
	-- 4–5. Full-height matte wine-crimson silk banners flanking the backrest shoulders.
	{ Id = "BackrestBannerWineW", X = -32, Z = -318, Y = 146, HalfX = 9.5, HalfZ = 3.5, Top = 104.0, Straddles = true },
	{ Id = "BackrestBannerWineE", X = 32, Z = -318, Y = 146, HalfX = 9.5, HalfZ = 3.5, Top = 104.0, Straddles = true },
	-- 6. The Throne's Heart Crack low in the front base wall under the Seat (matte red-black SmoothPlastic).
	{ Id = "ThroneHeartCrack", X = 0, Z = -118, Y = 12, HalfX = 13.5, HalfZ = 5.0, Top = 21.0 },
	-- 7–8. Outer armrest battlement walls rimming the Seat's SW/SE and NW/NE sides (clear of Arm_Apex & Hand_Apex).
	{ Id = "ThroneArmrestWallW", X = -116, Z = -132, Y = 68, HalfX = 4.5, HalfZ = 14.0, Top = 23.0 },
	{ Id = "ThroneArmrestWallE", X = 116, Z = -132, Y = 68, HalfX = 4.5, HalfZ = 14.0, Top = 23.0 },
	{ Id = "ThroneArmrestWallNW", X = -116, Z = -276, Y = 68, HalfX = 4.5, HalfZ = 14.0, Top = 23.0 },
	{ Id = "ThroneArmrestWallNE", X = 116, Z = -276, Y = 68, HalfX = 4.5, HalfZ = 14.0, Top = 23.0 },
	-- 9–10. Outer armrest walls along ArmW and ArmE outer south-west/south-east edges.
	{ Id = "ArmWOuterWall", X = -232, Z = -174, Y = 52, HalfX = 4.5, HalfZ = 10.0, Top = 23.0 },
	{ Id = "ArmEOuterWall", X = 232, Z = -174, Y = 56, HalfX = 4.5, HalfZ = 10.0, Top = 23.0 },
	-- 11–12. Colossal open Gauntlet Hands at HandW / HandE north tips cradling the last two bone-white Wardlights!
	{ Id = "GauntletHandWest", X = -202, Z = -308, Y = 58, HalfX = 13.0, HalfZ = 13.0, Top = 29.0 },
	{ Id = "GauntletHandEast", X = 202, Z = -308, Y = 62, HalfX = 13.0, HalfZ = 13.0, Top = 29.0 },
	-- 13–14. Towering armored Greave columns flanking ShinW and ShinE.
	{ Id = "GreaveTowerWest", X = -242, Z = -14, Y = 12, HalfX = 11.5, HalfZ = 12.0, Top = 50.0 },
	{ Id = "GreaveTowerEast", X = 242, Z = -14, Y = 16, HalfX = 11.5, HalfZ = 12.0, Top = 50.0 },
	-- 15–16. Colossal armored Sabaton Feet planted beside FootW and FootE.
	{ Id = "SabatonFootWest", X = -126, Z = 16, Y = -6, HalfX = 13.0, HalfZ = 20.0, Top = 20.0 },
	{ Id = "SabatonFootEast", X = 126, Z = 16, Y = -6, HalfX = 13.0, HalfZ = 20.0, Top = 20.0 },
	-- 17. Shattered Broken Grand Stair snapping off the north lip of BrokenStair into the open void.
	{ Id = "BrokenGrandStair", X = 0, Z = -20, Y = 14, HalfX = 12.0, HalfZ = 14.5, Top = 19.0 },
	-- 18–19. Sweeping colossal Mantle-Chains hanging from the Throne's shoulders toward ChainW / ChainE.
	{ Id = "MantleChainWest", X = -275, Z = -205, Y = 115, HalfX = 32.0, HalfZ = 6.0, Top = 26.0, Straddles = true },
	{ Id = "MantleChainEast", X = 275, Z = -205, Y = 115, HalfX = 32.0, HalfZ = 6.0, Top = 26.0, Straddles = true },
	-- 20–21. Iron-barred Chain Climb Cages flanking the Bastion->Chain climb ramps.
	{ Id = "ChainClimbArchWest", X = -341, Z = -163, Y = 38, HalfX = 12.0, HalfZ = 12.0, Top = 20.0, Straddles = true },
	{ Id = "ChainClimbArchEast", X = 341, Z = -163, Y = 42, HalfX = 12.0, HalfZ = 12.0, Top = 20.0, Straddles = true },
	-- 22–23. Ornate Footstool dais trim & iron censers on Crossing's south-west / south-east corners.
	{ Id = "FootstoolTrimW", X = -46, Z = 138, Y = 16, HalfX = 14.0, HalfZ = 7.0, Top = 12.0 },
	{ Id = "FootstoolTrimE", X = 46, Z = 138, Y = 16, HalfX = 14.0, HalfZ = 7.0, Top = 12.0 },
	-- 24–25. Iron Reliquary Shrines on the dead-end ReliquaryW and ReliquaryE terraces.
	{ Id = "ReliquaryShrineW", X = -388, Z = -362, Y = 46, HalfX = 6.0, HalfZ = 6.0, Top = 17.0 },
	{ Id = "ReliquaryShrineE", X = 388, Z = -362, Y = 50, HalfX = 6.0, HalfZ = 6.0, Top = 17.0 },
	-- 26. The Last Oath arrival iron arch straddling Sanctuary's north threshold.
	{ Id = "LastOathGateArch", X = 0, Z = 335, Y = 8, HalfX = 38.5, HalfZ = 7.5, Top = 31.0, Straddles = true },
	-- 27. Hall of Kneeling supplicant statue gallery along WestGallery's outer west rim.
	{ Id = "HallOfKneelingLineW", X = -376, Z = 95, Y = 8, HalfX = 5.0, HalfZ = 24.0, Top = 11.5 },
	-- 28. Hall of Oaths chained tablet register wall along EastGallery's outer east rim.
	{ Id = "HallOfOathsWallE", X = 376, Z = 95, Y = 12, HalfX = 5.0, HalfZ = 22.0, Top = 25.5 },
	-- 29–30. Colossal chain mooring bollards anchoring the Mantle-Chains at ChainW / ChainE.
	{ Id = "WestChainAnchorBollard", X = -392, Z = -230, Y = 44, HalfX = 10.0, HalfZ = 10.0, Top = 26.5 },
	{ Id = "EastChainAnchorBollard", X = 392, Z = -230, Y = 48, HalfX = 10.0, HalfZ = 10.0, Top = 26.5 },
}) :: { Landmark }

local function safeTag(inst: Instance?, tagName: string)
	if inst then
		pcall(function()
			CollectionService:AddTag(inst, tagName)
		end)
	end
end

function AbyssalFloor50.Build(ctx: any)
	local H = InfernalFoundry.Helpers(ctx)
	local P = ctx.layout.Platforms
	local _boxAt, lump, light, piece, noCollide = H.boxAt, H.lump, H.light, H.piece, H.noCollide
	local function boxAt(name: string, cf: CFrame, size: Vector3, color: Color3, mat: Enum.Material, trans: number?): Part
		return _boxAt(name, size, cf, color, mat, trans)
	end

	local lightsUsed = 0
	local emittersUsed = 0
	local propsPlaced = 0
	local groundCoverPlaced = 0
	local templatesUsed: { [string]: boolean } = {}
	local templateCounts: { [string]: number } = {}

	local function recordTemplate(tplName: string)
		templatesUsed[tplName] = true
		templateCounts[tplName] = (templateCounts[tplName] or 0) + 1
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

	local function placeKit(
		groupName: string,
		x: number,
		y: number,
		z: number,
		yawDeg: number,
		tplName: string,
		scale: any,
		override: any,
		fallback: ((cf: CFrame) -> ())?,
		isGroundCover: boolean?
	): Instance?
		local prop: Instance? = nil
		ctx.group(groupName, function()
			prop = ctx.current()
			local cf = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yawDeg), 0)
			if ctx.has(tplName) then
				ctx.kitAt(tplName, cf, scale, override)
			elseif fallback then
				fallback(cf)
			else
				boxAt(tplName .. "_Fallback", cf * CFrame.new(0, 2.5, 0), V(4, 5, 4), OBSIDIAN_MID, Mat.Basalt)
			end
		end)
		pin(prop)
		if isGroundCover then
			tagDetail(prop)
			groundCoverPlaced += 1
		else
			recordTemplate(tplName)
			propsPlaced += 1
		end
		return prop
	end

	local function ashEmitter(pos: Vector3, rate: number)
		if emittersUsed >= 16 then return end
		emittersUsed += 1
		local anchor = ctx.block("DirgeAshAnchor", V(1, 1, 1), pos, ASH_GREY, Mat.SmoothPlastic, nil, 1)
		anchor.CanCollide, anchor.CanQuery, anchor.CastShadow = false, false, false
		anchor:SetAttribute("DirgeAshEmitter", true)
		safeTag(anchor, "DirgeAshEmitter")
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "DirgeAshDrift"
		pe.Color = ColorSequence.new(rgb(138, 134, 146), rgb(64, 60, 74))
		pe.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.45),
			NumberSequenceKeypoint.new(0.5, 0.9),
			NumberSequenceKeypoint.new(1, 0.25),
		})
		pe.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.8),
			NumberSequenceKeypoint.new(0.3, 0.42),
			NumberSequenceKeypoint.new(0.8, 0.58),
			NumberSequenceKeypoint.new(1, 1.0),
		})
		pe.Lifetime = NumberRange.new(3.2, 5.4)
		pe.Rate = rate
		pe.Speed = NumberRange.new(2.4, 5.2)
		pe.SpreadAngle = Vector2.new(35, 35)
		pe.RotSpeed = NumberRange.new(-45, 45)
		-- Ash drifts northward (-Z) toward the Throne!
		pe.Acceleration = V(0, 0.8, -3.6)
		pe.Parent = anchor
	end

	-- Deterministic spatial clearance helpers so scattered props never touch camps, lanes, or portals.
	local lanes = ctx.layout.Lanes or {}
	local camps = ctx.layout.Camps or {}
	local function campFree(x: number, z: number, minPad: number?): boolean
		local rMin = 34 + (minPad or 4)
		for _, c in camps do
			local dx, dz = x - c.X, z - c.Z
			if dx * dx + dz * dz < rMin * rMin then
				return false
			end
		end
		return true
	end
	local function laneFree(x: number, z: number, pad: number): boolean
		for _, link in ctx.layout.Links do
			local ax, az, bx, bz = link.AX, link.AZ, link.BX, link.BZ
			local vx, vz = bx - ax, bz - az
			local lenSq = vx * vx + vz * vz
			if lenSq > 1 then
				local t = math.clamp(((x - ax) * vx + (z - az) * vz) / lenSq, 0, 1)
				local px, pz = ax + vx * t, az + vz * t
				local hw = (link.Width or 28) * 0.5 + pad
				if (x - px) ^ 2 + (z - pz) ^ 2 < hw * hw then
					return false
				end
			end
		end
		for _, link in ctx.layout.ReturnLinks or {} do
			local ax, az, bx, bz = link.AX, link.AZ, link.BX, link.BZ
			local vx, vz = bx - ax, bz - az
			local lenSq = vx * vx + vz * vz
			if lenSq > 1 then
				local t = math.clamp(((x - ax) * vx + (z - az) * vz) / lenSq, 0, 1)
				local px, pz = ax + vx * t, az + vz * t
				local hw = (link.Width or 32) * 0.5 + pad
				if (x - px) ^ 2 + (z - pz) ^ 2 < hw * hw then
					return false
				end
			end
		end
		if math.abs(x) < 22 and z > 188 and z < 366 then
			return false
		end
		if math.abs(x) < 34 and z > -282 and z < -250 then
			return false
		end
		return true
	end
	local function portalFree(x: number, z: number): boolean
		return (math.abs(x) > 36 or z < -286 or z > -246)
	end

	for _, lm in AbyssalFloor50.Landmarks do
		ctx.reserve(lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ))
	end

	-- =========================================================================
	-- A. BLACK VAULT ABYSS FLOOR, THRONE FOUNDATION WALL & UNDERTOW CHANNELS
	-- =========================================================================
	ctx.group("AbyssalUndertowBed", function()
		boxAt("AbyssVoidBed", CFrame.new(V(0, ABYSS_Y - 1.5, -10)), V(1100, 1.0, 960), rgb(9, 8, 14), Mat.Basalt)

		-- Stepped carved obsidian Throne foundation wall beneath Apex (Z = -122..-360) so the Throne rises
		-- as one colossal architectural landform out of the abyss and houses the ThroneHeartCrack!
		boxAt("ThroneSubBaseSouth", CFrame.new(V(0, 32, -210)), V(218, 78, 176), OBSIDIAN_DARK, Mat.Basalt)
		boxAt("ThroneSubPlinth", CFrame.new(V(0, 14, -130)), V(172, 42, 32), OBSIDIAN_MID, Mat.Basalt)
		boxAt("ThroneBackPierMass", CFrame.new(V(0, 18, -342)), V(156, 48, 56), OBSIDIAN_DARK, Mat.Basalt)

		-- Undertow rivers in carved Rifts beds (Y = -8.0 <= -7.5, running along room edges toward Throne base).
		-- Strictly outside walk terraces & walkways, tagged "DirgeUndertow" for client scrolling/pulsing.
		local undertowPaths = {
			{ -425, 220, -405, 80 }, { -405, 80, -415, -60 }, { -415, -60, -410, -210 }, { -410, -210, -240, -320 },
			{ 425, 220, 405, 80 }, { 405, 80, 415, -60 }, { 415, -60, 410, -210 }, { 410, -210, 240, -320 },
			{ -255, 165, -248, 30 }, { -248, 30, -262, -90 }, { -262, -90, -255, -210 },
			{ 255, 165, 248, 30 }, { 248, 30, 262, -90 }, { 262, -90, 255, -210 },
			{ -85, 45, -75, -60 }, { -75, -60, -58, -118 },
			{ 85, 45, 75, -60 }, { 75, -60, 58, -118 },
		}
		for idx, seg in undertowPaths do
			local a, b = V(seg[1], ABYSS_Y, seg[2]), V(seg[3], ABYSS_Y, seg[4])
			local mid = (a + b) * 0.5
			local len = (b - a).Magnitude + 8
			local cf = CFrame.lookAt(mid, b)
			local bed = boxAt("UndertowChannel_" .. idx, cf, V(18, 0.45, len), UNDERTOW_VIOLET, Mat.SmoothPlastic, 0.22)
			bed:SetAttribute("DirgeUndertow", true)
			safeTag(bed, "DirgeUndertow")
			local core = boxAt("UndertowStream_" .. idx, cf * CFrame.new(0, 0.16, 0), V(6.5, 0.28, len * 0.96), UNDERTOW_CORE, Mat.Glass, 0.18)
			core:SetAttribute("DirgeUndertow", true)
			safeTag(core, "DirgeUndertow")
		end
		-- Two subtle Undertow glow anchors deep in the Y=-8 chasm beds.
		for _, up in { V(-410, ABYSS_Y + 2, -60), V(410, ABYSS_Y + 2, -60) } do
			local ua = boxAt("UndertowLightAnchor", CFrame.new(up), V(1, 1, 1), UNDERTOW_VIOLET, Mat.SmoothPlastic, 1)
			addLight(ua, UNDERTOW_VIOLET, 1.4, 75)
		end

		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	-- =========================================================================
	-- B. FLUSH NON-COLLIDABLE INLAYS: SUPPLICANTS' FLOOR KNEELING LINES & CLEAN SEAT CROWN INLAY
	-- =========================================================================
	ctx.group("AbyssalFloorInlay", function()
		-- Bone-white kneeling lines inlaid across the Supplicants' Floor (Basin at Y = 0).
		for _, bz in { 206, 224, 245, 266, 284 } do
			for _, side in { -1, 1 } do
				local line = boxAt("SupplicantKneelLine", CFrame.new(V(side * 228, 0.04, bz)), V(390, 0.06, 0.85), BONE_INLAY, Mat.Marble, 0.28)
				line.CanCollide = false
			end
		end
		-- Central processional bone-white Spine Flag trail on Basin -> Crossing.
		boxAt("SupplicantSpineInlay", CFrame.new(V(0, 0.05, 245)), V(14, 0.06, 98), BONE_INLAY, Mat.Marble, 0.34)

		-- The Seat (Apex, 212 x 156 at Y = 72): keep arena 100% clean!
		-- Only a subtle, flush, non-collidable worn bone-white Chained Crown inlay (SmoothPlastic/Marble, NOT Neon!).
		local ay, az = 72.03, -200
		ctx.ring("SeatChainRingOuter", V(0, ay, az), 58, 0.85, BONE_INLAY, Mat.Marble, CFrame.Angles(math.pi / 2, 0, 0), 0.14, math.pi * 2 - 0.14, 36)
		ctx.ring("SeatChainRingInner", V(0, ay, az), 34, 0.55, BONE_INLAY, Mat.Marble, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 28)
		-- Faint 5-pointed Crown inlay strokes inside the center ring.
		for k = -2, 2 do
			local cx = k * 11
			local h = 24 - math.abs(k) * 4.5
			boxAt("SeatCrownPoint_" .. k, CFrame.new(V(cx, ay, az - h * 0.35)), V(1.6, 0.05, h), BONE_INLAY, Mat.Marble, 0.32)
		end
		boxAt("SeatCrownBand", CFrame.new(V(0, ay, az + 12)), V(50, 0.05, 2.2), BONE_INLAY, Mat.Marble, 0.28)

		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	-- =========================================================================
	-- C. COLOSSAL THRONE BACKREST, CHAINED CROWN, CRIMSON ECLIPSE, BANNERS & HEART CRACK
	-- =========================================================================
	do
		local br = AbyssalFloor50.Landmarks[1]
		local mb = placeKit("ThroneMonument", br.X, br.Y :: number, br.Z, 0, "ThroneBackrest", 1.0, VAHL_50, function(cf)
			boxAt("ThroneBackrestWallFB", cf * CFrame.new(0, 167, 0), V(136, 334, 42), OBSIDIAN_DARK, Mat.Basalt)
		end)
		noCollide(mb)

		local cc = AbyssalFloor50.Landmarks[2]
		local mc = placeKit("ThroneCrown", cc.X, cc.Y :: number, cc.Z, 0, "ChainedCrownColossal", 1.0, VAHL_50, function(cf)
			ctx.ring("ChainedCrownRingFB", cf.Position + V(0, 42, 0), 36, 2.6, IRON_BLACK, Mat.Metal, nil, 0.18, math.pi * 2 - 0.18, 24)
		end)
		noCollide(mc)

		local ec = AbyssalFloor50.Landmarks[3]
		local me = placeKit("CrimsonEclipseSky", ec.X, ec.Y :: number, ec.Z, 0, "CrimsonEclipseDisc", 1.0, ECLIPSE_TINT, function(cf)
			ctx.cyl("CrimsonEclipseDiscFB", cf.Position + V(0, 75, 0), 62, 5, rgb(12, 8, 14), Mat.SmoothPlastic)
		end)
		noCollide(me)
		if me then
			me:SetAttribute("DirgeHeartbeat", true)
			safeTag(me, "DirgeHeartbeat")
		end

		for _, idx in { 4, 5 } do
			local bn = AbyssalFloor50.Landmarks[idx]
			local mbn = placeKit("ThroneBanner", bn.X, bn.Y :: number, bn.Z, 0, "BackrestBannerWine", V(1.0, 1.09, 1.0), VAHL_50, function(cf)
				boxAt("BannerWineFB", cf * CFrame.new(0, 52, 0), V(18, 104, 2), WINE_SILK, Mat.Fabric)
			end)
			noCollide(mbn)
		end

		-- 6. Throne's Heart Crack in the front Throne base wall (deep matte red-black SmoothPlastic, NEVER Neon!).
		local hc = AbyssalFloor50.Landmarks[6]
		local mhc = placeKit("ThroneHeartCrackProp", hc.X, hc.Y :: number, hc.Z, 0, "ThroneHeartCrack", 1.0, HEART_CRACK_TINT, function(cf)
			boxAt("HeartCrackCleftFB", cf * CFrame.new(0, 10, 0), V(6, 18, 4), HEART_MATTE, Mat.SmoothPlastic)
		end)
		noCollide(mhc)
		if mhc then
			mhc:SetAttribute("DirgeHeartbeat", true)
			safeTag(mhc, "DirgeHeartbeat")
		end
	end

	-- =========================================================================
	-- D. ARMREST WALLS, GAUNTLET HANDS (LAST TWO WARDLIGHTS), GREAVES, SABATONS, BROKEN STAIR, CHAINS & RELIQUARIES
	-- =========================================================================
	do
		local byId: { [string]: Landmark } = {}
		for _, lm in AbyssalFloor50.Landmarks do
			byId[lm.Id] = lm
		end

		-- Seat SW/SE & NW/NE outer armrest rim walls (outside Apex).
		for _, id in { "ThroneArmrestWallW", "ThroneArmrestWallE", "ThroneArmrestWallNW", "ThroneArmrestWallNE" } do
			local lm = byId[id]
			placeKit("ThroneArmrest", lm.X, lm.Y :: number, lm.Z, 0, "ThroneArmrestWall", V(1.0, 1.0, 0.77), VAHL_50, function(cf)
				boxAt("ArmrestWallFB", cf * CFrame.new(0, 11, 0), V(8, 22, 28), OBSIDIAN_DARK, Mat.Basalt)
			end)
		end
		-- ArmW and ArmE outer battlement walls.
		for _, id in { "ArmWOuterWall", "ArmEOuterWall" } do
			local lm = byId[id]
			placeKit("ThroneArmrest", lm.X, lm.Y :: number, lm.Z, 0, "ThroneArmrestWall", V(1.0, 1.0, 0.55), VAHL_50, function(cf)
				boxAt("ArmrestOuterFB", cf * CFrame.new(0, 11, 0), V(8, 22, 20), OBSIDIAN_DARK, Mat.Basalt)
			end)
		end

		-- Colossal Gauntlet Hands cradling the last two bone-white Wardlights!
		for _, spec in { { byId.GauntletHandWest, 18 }, { byId.GauntletHandEast, -18 } } do
			local lm = spec[1]
			local mg = placeKit("ThroneGauntlet", lm.X, lm.Y :: number, lm.Z, spec[2], "GauntletHandOpen", 1.0, VAHL_50, function(cf)
				boxAt("GauntletPalmFB", cf * CFrame.new(0, 12, 0), V(18, 24, 18), IRON_BLACK, Mat.Metal)
				lump("GauntletWardlightFB", cf.Position + V(0, 20, 0), V(3, 4, 3), WARDLIGHT_BONE, Mat.Neon)
			end)
			if mg then
				mg:SetAttribute("DirgeWardlight", true)
				safeTag(mg, "DirgeWardlight")
				addLight(H.glowOf(mg) or mg:FindFirstChildWhichIsA("BasePart", true), WARDLIGHT_BONE, 2.8, 95)
			end
		end

		-- Towering armored Greave columns flanking ShinW & ShinE.
		for _, spec in { { byId.GreaveTowerWest, 18 }, { byId.GreaveTowerEast, -18 } } do
			local lm = spec[1]
			placeKit("ThroneGreave", lm.X, lm.Y :: number, lm.Z, spec[2], "GreaveTower", 1.0, VAHL_50, function(cf)
				boxAt("GreaveTowerFB", cf * CFrame.new(0, 25, 0), V(20, 50, 20), IRON_BLACK, Mat.Metal)
			end)
		end

		-- Colossal Sabaton Feet planted beside FootW & FootE.
		for _, spec in { { byId.SabatonFootWest, 12 }, { byId.SabatonFootEast, -12 } } do
			local lm = spec[1]
			placeKit("ThroneSabaton", lm.X, lm.Y :: number, lm.Z, spec[2], "SabatonFoot", 0.86, VAHL_50, function(cf)
				boxAt("SabatonFootFB", cf * CFrame.new(0, 9, 0), V(22, 18, 36), IRON_BLACK, Mat.Metal)
			end)
		end

		-- Broken Grand Stair snapping off the north edge of BrokenStair into the open void!
		local bs = byId.BrokenGrandStair
		placeKit("BrokenStairSpan", bs.X, bs.Y :: number, bs.Z, 0, "BrokenGrandStair", 1.0, VAHL_50, function(cf)
			boxAt("BrokenGrandStairFB", cf * CFrame.new(0, 9, 0), V(22, 18, 28), OBSIDIAN_MID, Mat.Basalt)
		end)

		-- Colossal Mantle-Chains sweeping from the Throne's shoulders toward ChainW & ChainE.
		for _, spec in { { byId.MantleChainWest, -22 }, { byId.MantleChainEast, 22 } } do
			local lm = spec[1]
			local mc = placeKit("MantleChain", lm.X, lm.Y :: number, lm.Z, spec[2], "MantleChainColossal", V(1.65, 1.45, 1.45), VAHL_50, function(cf)
				boxAt("MantleChainFB", cf * CFrame.new(0, 12, 0), V(64, 4, 4), IRON_BLACK, Mat.Metal)
			end)
			noCollide(mc)
			if mc then
				mc:SetAttribute("DirgeChain", true)
				safeTag(mc, "DirgeChain")
			end
		end

		-- Caged Chain Climbs straddling WestBastion->ChainW and EastBastion->ChainE.
		for _, spec in { { byId.ChainClimbArchWest, 8 }, { byId.ChainClimbArchEast, -8 } } do
			local lm = spec[1]
			local mch = placeKit("ChainClimbArch", lm.X, lm.Y :: number, lm.Z, spec[2], "ChainClimbCage", V(1.5, 1.2, 1.2), VAHL_50, function(cf)
				boxAt("ChainClimbArchFB", cf * CFrame.new(0, 18, 0), V(24, 3, 22), IRON_BLACK, Mat.Metal)
			end)
			noCollide(mch)
			if mch then
				mch:SetAttribute("DirgeChain", true)
				safeTag(mch, "DirgeChain")
			end
		end

		-- Footstool ornate dais trims & corner iron censers on Crossing.
		for _, spec in { { byId.FootstoolTrimW, 145 }, { byId.FootstoolTrimE, -145 } } do
			local lm = spec[1]
			local mf = placeKit("FootstoolTrim", lm.X, lm.Y :: number, lm.Z, spec[2], "FootstoolGreat", 0.86, VAHL_50, function(cf)
				boxAt("FootstoolTrimFB", cf * CFrame.new(0, 5, 0), V(26, 10, 14), OBSIDIAN_MID, Mat.Basalt)
			end)
			if mf then
				mf:SetAttribute("DirgeWardlight", true)
				safeTag(mf, "DirgeWardlight")
				addLight(H.glowOf(mf), WARDLIGHT_BONE, 1.6, 56)
			end
		end

		-- Reliquary Shrines on dead-end ReliquaryW and ReliquaryE.
		for _, spec in { { byId.ReliquaryShrineW, 32 }, { byId.ReliquaryShrineE, -32 } } do
			local lm = spec[1]
			placeKit("ReliquaryCage", lm.X, lm.Y :: number, lm.Z, spec[2], "RelicCageIron", 1.1, RELIC_TINT, function(cf)
				boxAt("RelicCageFB", cf * CFrame.new(0, 8, 0), V(9, 16, 9), IRON_BLACK, Mat.Metal)
			end)
		end

		-- The Last Oath arrival iron arch over Sanctuary's north exit.
		local oa = byId.LastOathGateArch
		local moa = placeKit("LastOathGate", oa.X, oa.Y :: number, oa.Z, 0, "GatehouseArch", 1.0, VAHL_50, function(cf)
			boxAt("LastOathGateFB", cf * CFrame.new(0, 26, 0), V(72, 8, 12), IRON_BLACK, Mat.Metal)
		end)
		noCollide(moa)

		-- Hall of Kneeling supplicant row along WestGallery's outer west rim.
		local hk = byId.HallOfKneelingLineW
		for kz = -18, 18, 12 do
			placeKit("SupplicantStatue", hk.X, hk.Y :: number, hk.Z + kz, 90, "KneelingSupplicant", 1.05, VAHL_50, nil)
		end

		-- Hall of Oaths chained tablet register wall along EastGallery's outer east rim.
		local ho = byId.HallOfOathsWallE
		placeKit("OathRegister", ho.X, ho.Y :: number, ho.Z - 11, -90, "OathRegisterWall", 1.0, VAHL_50, nil)
		placeKit("OathRegister", ho.X, ho.Y :: number, ho.Z + 11, -90, "OathRegisterWall", 1.0, VAHL_50, nil)

		-- Chain Anchor Bollards anchoring the Mantle-Chains at ChainW and ChainE.
		for _, cb in { byId.WestChainAnchorBollard, byId.EastChainAnchorBollard } do
			placeKit("ChainAnchor", cb.X, cb.Y :: number, cb.Z, if cb.X < 0 then 90 else -90, "ChainAnchorBollard", 1.0, VAHL_50, nil)
		end
	end

	-- =========================================================================
	-- E. COLD SILVER-WHITE KEY LIGHTING ON THE SEAT & WARDLIGHT LANTERNS AT KEY WAYSTATIONS
	-- =========================================================================
	ctx.group("ThroneSilverKey", function()
		-- Cold silver-white key fill lights high above the Seat (zero crimson or orange!).
		for _, sp in { V(-48, 114, -180), V(48, 114, -220) } do
			local a = boxAt("SilverSeatKeyAnchor", CFrame.new(sp), V(1, 1, 1), SILVER_KEY, Mat.SmoothPlastic, 1)
			addLight(a, SILVER_KEY, 1.9, 130)
		end
		-- Bone-white Wardlight lanterns at key arrival/gallery/bastion junctions (<= 16 lights total!).
		for idx, wp in {
			{ -22, 8, 336, true }, { 22, 8, 336, false },
			{ -102, 0, 210, true }, { 102, 0, 210, false },
			{ -274, 8, 128, true }, { 274, 12, 128, true },
			{ -288, 32, -88, true }, { 288, 36, -88, true },
			{ -188, 52, -118, false }, { 188, 56, -118, false },
		} do
			local wl = placeKit("WardlightLantern", wp[1], wp[2], wp[3], if wp[1] < 0 then 28 else -28, "DaisBrazierPedestal", 0.68, VAHL_50, nil)
			if wl then
				wl:SetAttribute("DirgeWardlight", true)
				safeTag(wl, "DirgeWardlight")
				if wp[4] then
					addLight(H.glowOf(wl) or wl:FindFirstChildWhichIsA("BasePart", true), WARDLIGHT_BONE, 1.7, 58)
				end
			end
		end
	end)

	-- =========================================================================
	-- F. TERRACE VIGNETTES, LINK-END DRESSING & FAR VAULT SKYLINE (>= 780 PROPS, >= 42 TEMPLATES)
	-- =========================================================================
	-- Curated vignette props per terrace (never touching camps, lanes, portals, or Apex arena!).
	local vignetteSpecs: { { number | string | any } } = {
		-- Sanctuary (The Last Oath): oath registers, wine banners, kneeling guards, urns.
		{ -52, 8, 352, 35, "OathRegisterWall", 0.72, VAHL_50 },
		{ 52, 8, 352, -35, "OathRegisterWall", 0.72, VAHL_50 },
		{ -54, 8, 378, 25, "WarBannerPole", 1.15, VAHL_50 },
		{ 54, 8, 378, -25, "WarBannerPole", 1.15, VAHL_50 },
		{ -44, 8, 342, 15, "KneelingSupplicant", 0.95, VAHL_50 },
		{ 44, 8, 342, -15, "KneelingSupplicant", 0.95, VAHL_50 },
		{ -46, 8, 382, 0, "StoneUrn", 0.95, VAHL_50 },
		{ 46, 8, 382, 0, "StoneUrn", 0.95, VAHL_50 },
		{ -36, 8, 384, 15, "ChainGalleryRail", 0.95, VAHL_50 },
		{ 36, 8, 384, -15, "ChainGalleryRail", 0.95, VAHL_50 },

		-- Basin (The Supplicants' Floor): kneeling rows, oath walls, banners, urns, blade racks (clear of BASIN_WEST/EAST!).
		{ -230, 0, 286, 180, "KneelingSupplicant", 1.0, VAHL_50 },
		{ -200, 0, 286, 180, "KneelingSupplicant", 1.0, VAHL_50 },
		{ -170, 0, 286, 180, "KneelingSupplicant", 1.0, VAHL_50 },
		{ 170, 0, 286, 180, "KneelingSupplicant", 1.0, VAHL_50 },
		{ 200, 0, 286, 180, "KneelingSupplicant", 1.0, VAHL_50 },
		{ 230, 0, 286, 180, "KneelingSupplicant", 1.0, VAHL_50 },
		{ -260, 0, 284, 175, "OathRegisterWall", 0.85, VAHL_50 },
		{ 260, 0, 284, -175, "OathRegisterWall", 0.85, VAHL_50 },
		{ -428, 0, 245, 90, "CurtainWallRuins", 0.92, VAHL_50 },
		{ 428, 0, 245, -90, "CurtainWallRuins", 0.92, VAHL_50 },
		{ -402, 0, 284, 45, "ChainAnchorBollard", 0.72, VAHL_50 },
		{ 402, 0, 284, -45, "ChainAnchorBollard", 0.72, VAHL_50 },
		{ -390, 0, 206, 135, "StoneUrn", 1.0, VAHL_50 },
		{ 390, 0, 206, -135, "StoneUrn", 1.0, VAHL_50 },
		{ -290, 0, 212, 160, "BladeDisplay", 1.0, VAHL_50 },
		{ 290, 0, 212, -160, "BladeDisplay", 1.0, VAHL_50 },
		{ -62, 0, 286, 0, "WarBannerPole", 1.15, VAHL_50 },
		{ 62, 0, 286, 0, "WarBannerPole", 1.15, VAHL_50 },
		{ -38, 0, 212, 12, "StoneUrn", 1.05, VAHL_50 },
		{ 38, 0, 212, -12, "StoneUrn", 1.05, VAHL_50 },

		-- WestGallery (Hall of Kneeling, Elite): Dreadguard gibbets, armor racks, Gothic pillars, blade displays.
		{ -356, 8, 62, 40, "GibbetCage", 0.72, VAHL_50 },
		{ -356, 8, 128, 135, "PermafrostCage", 0.78, RELIC_TINT },
		{ -282, 8, 62, -45, "ArmourRack", 1.0, VAHL_50 },
		{ -358, 8, 74, 90, "GothicPillarColonnade", 0.75, VAHL_50 },
		{ -358, 8, 116, 90, "GothicPillarColonnade", 0.75, VAHL_50 },
		{ -300, 8, 130, 180, "BladeDisplay", 1.0, VAHL_50 },
		{ -280, 8, 108, -90, "WarBannerPole", 1.1, VAHL_50 },

		-- EastGallery (Hall of Oaths, Elite): RuneTablets, oath registers, urns, Gothic pillars.
		{ 356, 12, 62, -40, "RuneTablet", 1.1, VAHL_50 },
		{ 356, 12, 128, -135, "RuneTablet", 1.1, VAHL_50 },
		{ 282, 12, 62, 45, "ArmourRack", 1.0, VAHL_50 },
		{ 358, 12, 74, -90, "GothicPillarColonnade", 0.75, VAHL_50 },
		{ 358, 12, 116, -90, "GothicPillarColonnade", 0.75, VAHL_50 },
		{ 300, 12, 130, 180, "StoneUrn", 1.05, VAHL_50 },
		{ 280, 12, 108, 90, "WarBannerPole", 1.1, VAHL_50 },

		-- FootW & FootE: fallen Dreadguard statues, chains, rubble, banners.
		{ -196, 20, 42, 45, "BrokenTideStatue", 0.72, VAHL_50 },
		{ 196, 24, 42, -45, "BrokenTideStatue", 0.72, VAHL_50 },
		{ -144, 20, 84, -30, "WarBannerPole", 1.05, VAHL_50 },
		{ 144, 24, 84, 30, "WarBannerPole", 1.05, VAHL_50 },
		{ -198, 20, 84, 15, "ChainGalleryRail", 0.72, VAHL_50 },
		{ 198, 24, 84, -15, "ChainGalleryRail", 0.72, VAHL_50 },

		-- BrokenStair (dead end): tattered banners, broken rails, leaning Wardlight lanterns, rubble.
		{ -24, 30, 6, 15, "WarBannerPole", 1.1, VAHL_50 },
		{ 24, 30, 6, -15, "WarBannerPole", 1.1, VAHL_50 },
		{ -24, 30, 26, 90, "ChainGalleryRail", 0.75, VAHL_50 },
		{ 24, 30, 26, -90, "ChainGalleryRail", 0.75, VAHL_50 },
		{ -18, 30, -4, 0, "RuinRubble", 0.9, VAHL_50 },
		{ 18, 30, -4, 0, "RuinRubble", 0.9, VAHL_50 },

		-- WestBastion & EastBastion (Mantle Bastions, Elite): BulwarkWalls, GibbetCages, Winches, ArmourRacks.
		{ -368, 32, -90, 90, "BulwarkWall", 1.05, VAHL_50 },
		{ 368, 36, -90, -90, "BulwarkWall", 1.05, VAHL_50 },
		{ -364, 32, -56, 65, "GibbetCage", 0.72, VAHL_50 },
		{ 364, 36, -56, -65, "GibbetCage", 0.72, VAHL_50 },
		{ -364, 32, -124, 115, "ChainWinch", 0.85, VAHL_50 },
		{ 364, 36, -124, -115, "ChainWinch", 0.85, VAHL_50 },
		{ -292, 32, -120, -60, "ArmourRack", 1.0, VAHL_50 },
		{ 292, 36, -120, 60, "ArmourRack", 1.0, VAHL_50 },
		{ -292, 32, -56, -120, "BladeDisplay", 1.0, VAHL_50 },
		{ 292, 36, -56, 120, "BladeDisplay", 1.0, VAHL_50 },

		-- ShinW & ShinE: ChainGalleryRails, Gothic pillars, banners, urns.
		{ -224, 38, -20, 90, "ChainGalleryRail", 0.85, VAHL_50 },
		{ 224, 42, -20, -90, "ChainGalleryRail", 0.85, VAHL_50 },
		{ -174, 38, -56, -30, "WarBannerPole", 1.05, VAHL_50 },
		{ 174, 42, -56, 30, "WarBannerPole", 1.05, VAHL_50 },
		{ -224, 38, -60, 45, "StoneUrn", 0.95, VAHL_50 },
		{ 224, 42, -60, -45, "StoneUrn", 0.95, VAHL_50 },

		-- ChainW & ChainE: ChainHoist, ChainWinch, CurtainWallSegment, HangingAbyssChain.
		{ -374, 44, -208, 60, "ChainHoist", 0.85, VAHL_50 },
		{ 374, 48, -208, -60, "ChainHoist", 0.85, VAHL_50 },
		{ -374, 44, -252, 120, "ChainWinch", 0.85, VAHL_50 },
		{ 374, 48, -252, -120, "ChainWinch", 0.85, VAHL_50 },
		{ -322, 44, -206, -45, "WarBannerPole", 1.05, VAHL_50 },
		{ 322, 48, -206, 45, "WarBannerPole", 1.05, VAHL_50 },

		-- ReliquaryW & ReliquaryE (dead ends): AbyssReliquaryShrines, RelicCages, WardenSkeletons, Urns, OathWalls.
		{ -394, 46, -335, 90, "AbyssReliquaryShrine", 0.72, RELIC_TINT },
		{ 394, 50, -335, -90, "AbyssReliquaryShrine", 0.72, RELIC_TINT },
		{ -350, 46, -354, 150, "RelicCageIron", 0.95, RELIC_TINT },
		{ 350, 50, -354, -150, "StoneUrn", 1.15, VAHL_50 },
		{ -344, 46, -335, -90, "WardenSkeleton", 1.0, VAHL_50 },
		{ 344, 50, -335, 90, "WardenSkeleton", 1.0, VAHL_50 },
		{ -370, 46, -356, 0, "OathRegisterWall", 0.85, VAHL_50 },
		{ 370, 50, -356, 0, "OathRegisterWall", 0.85, VAHL_50 },

		-- ArmW & ArmE: banners, kneeling supplicants, chains, braziers.
		{ -214, 52, -120, 45, "KneelingSupplicant", 0.95, VAHL_50 },
		{ 214, 56, -120, -45, "KneelingSupplicant", 0.95, VAHL_50 },
		{ -214, 52, -180, 135, "WarBannerPole", 1.1, VAHL_50 },
		{ 214, 56, -180, -135, "WarBannerPole", 1.1, VAHL_50 },

		-- HandW & HandE: chain bollards, banners, rubble framing the gauntlets (clear of Hand_Apex lanes!).
		{ -224, 62, -242, 45, "ChainAnchorBollard", 0.6, VAHL_50 },
		{ 224, 66, -242, -45, "ChainAnchorBollard", 0.6, VAHL_50 },
		{ -174, 62, -288, -30, "WarBannerPole", 1.0, VAHL_50 },
		{ 174, 66, -288, 30, "WarBannerPole", 1.0, VAHL_50 },
	}
	for idx, sp in vignetteSpecs do
		local x, y, z, yaw, tpl, sc, ov = sp[1] :: number, sp[2] :: number, sp[3] :: number, sp[4] :: number, sp[5] :: string, sp[6] :: number, sp[7]
		if campFree(x, z, 2) and laneFree(x, z, 2) and portalFree(x, z) then
			placeKit("ThroneVignette_" .. idx, x, y, z, yaw, tpl, sc, ov, nil)
		end
	end

	-- Dress both ends of every link with bone-white HangingLanterns / ChainAnchorBollards / WarBannerPoles off the lane!
	local linkPropCycle = { "HangingLantern", "ChainAnchorBollard", "WarBannerPole", "CurtainWallSegment", "GothicPillarColonnade", "StoneUrn" }
	for lIdx, link in ctx.layout.Links do
		local dx, dz = link.BX - link.AX, link.BZ - link.AZ
		local len = math.sqrt(dx * dx + dz * dz)
		if len > 1 then
			local nx, nz = -dz / len, dx / len
			local yaw = math.deg(math.atan2(dx, dz))
			for eIdx, endPt in { { link.AX, link.AY, link.AZ }, { link.BX, link.BY, link.BZ } } do
				for _, side in { -1, 1 } do
					local px = endPt[1] + nx * side * 20
					local pz = endPt[3] + nz * side * 20
					local py = endPt[2]
					-- Keep Apex arena interior clean!
					if math.abs(px) < 110 and pz > -282 and pz < -118 then continue end
					if campFree(px, pz, 2) and laneFree(px, pz, 2) and portalFree(px, pz) then
						local tpl = linkPropCycle[((lIdx + eIdx + (if side > 0 then 1 else 0)) % #linkPropCycle) + 1]
						local sc = if tpl == "HangingLantern" then 1.35 elseif tpl == "ChainAnchorBollard" then 0.45 elseif tpl == "GothicPillarColonnade" then 0.55 elseif tpl == "CurtainWallSegment" then 0.65 else 0.95
						local m = placeKit("LinkDressing", px, py, pz, yaw + (if side > 0 then -18 else 18), tpl, sc, VAHL_50, nil)
						if tpl == "HangingLantern" and m then
							m:SetAttribute("DirgeWardlight", true)
							safeTag(m, "DirgeWardlight")
						end
					end
				end
			end
		end
	end

	-- =========================================================================
	-- G. THREE-LAYER SKYLINE & CHASM/VAULT ARCHITECTURE (REACHING >= 780 PROPS & >= 42 TEMPLATES)
	-- =========================================================================
	-- Mid-layer & Far-layer obsidian fortresses, VaultRibArches, ObsidianSpires, CliffRocks, HangingChains,
	-- and distant kneeling court silhouettes along the perimeter ledges!
	local farStructures: { { number | string } } = {
		-- Flanking colossal VaultRibArches & CitadelDoors framing the Throne backrest in the far north!
		{ -145, 10, -356, 22, "VaultRibArch", 1.45 },
		{ 145, 10, -356, -22, "VaultRibArch", 1.45 },
		{ -235, 10, -355, 25, "ChainTowerRound", 1.55 },
		{ 235, 10, -355, -25, "ChainTowerRound", 1.55 },
		{ -295, 12, -365, 18, "StormkeepRoundTower", 1.65 },
		{ 295, 12, -365, -18, "StormkeepRoundTower", 1.65 },
		{ -435, -6, -340, 35, "CitadelDoors", 1.1 },
		{ 435, -6, -340, -35, "CitadelDoors", 1.1 },
		{ -195, -6, -372, 12, "ObsidianSpire", 2.2 },
		{ 195, -6, -372, -12, "ObsidianSpire", 2.2 },
		{ -105, -6, -372, 8, "ObsidianSpire", 2.4 },
		{ 105, -6, -372, -8, "ObsidianSpire", 2.4 },
	}
	for _, fs in farStructures do
		local x, y, z, yaw, tpl, sc = fs[1] :: number, fs[2] :: number, fs[3] :: number, fs[4] :: number, fs[5] :: string, fs[6] :: number
		local m = placeKit("VaultSkyline_" .. tpl, x, y, z, yaw, tpl, sc, VAHL_50, nil)
		noCollide(m)
	end

	-- Overhead hanging chains & abyss chains spanning high across the outer chasm flanks (>= 18 studs clear!).
	for _, ch in {
		{ -305, 86, -155, 22, "HangingAbyssChain", 1.4 },
		{ 305, 90, -155, -22, "HangingAbyssChain", 1.4 },
		{ -275, 76, 45, 35, "HangingAbyssChain", 1.3 },
		{ 275, 80, 45, -35, "HangingAbyssChain", 1.3 },
		{ -350, 96, -280, 15, "HangingChainRun", 1.35 },
		{ 350, 100, -280, -15, "HangingChainRun", 1.35 },
		{ -255, 88, -110, 8, "HangingChainRun", 1.25 },
		{ 255, 92, -110, -8, "HangingChainRun", 1.25 },
	} do
		local mc = placeKit("AbyssHangingChain", ch[1] :: number, ch[2] :: number, ch[3] :: number, ch[4] :: number, ch[5] :: string, ch[6] :: number, VAHL_50, nil)
		noCollide(mc)
		if mc then
			mc:SetAttribute("DirgeChain", true)
			safeTag(mc, "DirgeChain")
		end
	end

	-- Distant kneeling court silhouettes along far west/east/north ledges (tagged "DirgeSilhouette").
	for k = 0, 19 do
		local side = if k % 2 == 0 then -1 else 1
		local sz = -325 + math.floor(k / 2) * 58
		local sx = side * 442
		local ms = placeKit("CourtSilhouette", sx, 18 + (k % 3) * 6, sz, side * 90, "KneelingSupplicant", 1.25, VAHL_50, nil)
		noCollide(ms)
		if ms then
			ms:SetAttribute("DirgeSilhouette", true)
			safeTag(ms, "DirgeSilhouette")
		end
	end

	-- Dense multi-template chasm/perimeter/edge prop population to hit >= 780 props across >= 42 templates,
	-- keeping every single template strictly <= 10.5% of total placed props!
	local rng = Random.new(505050)
	local chasmTemplates = {
		{ Name = "ObsidianSpire", Scale = { 0.65, 1.35 }, Y = ABYSS_Y + 1.5 },
		{ Name = "BlightTree", Scale = { 0.65, 1.05 }, Y = ABYSS_Y + 1.5 },
		{ Name = "CliffRockA", Scale = { 0.55, 0.95 }, Y = ABYSS_Y + 1.0 },
		{ Name = "CliffRockB", Scale = { 0.55, 0.95 }, Y = ABYSS_Y + 1.0 },
		{ Name = "CurtainWallRuins", Scale = { 0.65, 1.05 }, Y = ABYSS_Y + 1.5 },
		{ Name = "CurtainWallSegment", Scale = { 0.75, 1.15 }, Y = ABYSS_Y + 1.5 },
		{ Name = "BulwarkWall", Scale = { 0.65, 1.05 }, Y = ABYSS_Y + 1.5 },
		{ Name = "GothicPillarColonnade", Scale = { 0.65, 1.05 }, Y = ABYSS_Y + 1.5 },
		{ Name = "ChainAnchorBollard", Scale = { 0.55, 0.85 }, Y = ABYSS_Y + 1.5 },
		{ Name = "ChainTowerRound", Scale = { 0.55, 0.85 }, Y = ABYSS_Y + 1.5 },
		{ Name = "StormkeepRoundTower", Scale = { 0.55, 0.85 }, Y = ABYSS_Y + 1.5 },
		{ Name = "VaultRibArch", Scale = { 0.55, 0.85 }, Y = ABYSS_Y + 1.5 },
		{ Name = "BrokenTideStatue", Scale = { 0.65, 0.95 }, Y = ABYSS_Y + 1.5 },
		{ Name = "ThroneOfIcicles", Scale = { 0.60, 0.95 }, Y = ABYSS_Y + 1.5 },
		{ Name = "ShatteredRoseWindow", Scale = { 0.60, 0.90 }, Y = ABYSS_Y + 1.5 },
		{ Name = "BoulderCluster", Scale = { 1.10, 1.85 }, Y = ABYSS_Y + 1.5 },
		{ Name = "RuinRubble", Scale = { 1.05, 1.65 }, Y = ABYSS_Y + 1.5 },
		{ Name = "VoidShards", Scale = { 1.15, 1.85 }, Y = ABYSS_Y + 1.5 },
		{ Name = "StoneUrn", Scale = { 0.95, 1.45 }, Y = ABYSS_Y + 1.5 },
		{ Name = "RuneTablet", Scale = { 0.95, 1.35 }, Y = ABYSS_Y + 1.5 },
		{ Name = "GibbetCage", Scale = { 0.65, 0.90 }, Y = ABYSS_Y + 1.5 },
		{ Name = "PermafrostCage", Scale = { 0.75, 1.05 }, Y = ABYSS_Y + 1.5 },
		{ Name = "WardenSkeleton", Scale = { 0.95, 1.35 }, Y = ABYSS_Y + 1.5 },
		{ Name = "ArmourRack", Scale = { 0.90, 1.25 }, Y = ABYSS_Y + 1.5 },
		{ Name = "BladeDisplay", Scale = { 0.90, 1.25 }, Y = ABYSS_Y + 1.5 },
		{ Name = "ChainWinch", Scale = { 0.75, 1.10 }, Y = ABYSS_Y + 1.5 },
		{ Name = "ChainHoist", Scale = { 0.75, 1.10 }, Y = ABYSS_Y + 1.5 },
		{ Name = "ChainGalleryRail", Scale = { 0.85, 1.20 }, Y = ABYSS_Y + 1.5 },
		{ Name = "WarBannerPole", Scale = { 0.95, 1.30 }, Y = ABYSS_Y + 1.5 },
		{ Name = "DaisBrazierPedestal", Scale = { 0.65, 0.95 }, Y = ABYSS_Y + 1.5 },
		{ Name = "HangingLantern", Scale = { 1.25, 1.75 }, Y = ABYSS_Y + 2.5 },
		{ Name = "KneelingSupplicant", Scale = { 0.90, 1.25 }, Y = ABYSS_Y + 1.5 },
		{ Name = "OathRegisterWall", Scale = { 0.75, 1.05 }, Y = ABYSS_Y + 1.5 },
		{ Name = "RelicCageIron", Scale = { 0.90, 1.25 }, Y = ABYSS_Y + 1.5 },
		{ Name = "AbyssReliquaryShrine", Scale = { 0.65, 0.95 }, Y = ABYSS_Y + 1.5 },
		{ Name = "GreaveTower", Scale = { 0.55, 0.85 }, Y = ABYSS_Y + 1.5 },
		{ Name = "SabatonFoot", Scale = { 0.55, 0.85 }, Y = ABYSS_Y + 1.5 },
		{ Name = "ThroneArmrestWall", Scale = { 0.75, 1.05 }, Y = ABYSS_Y + 1.5 },
		{ Name = "FootstoolGreat", Scale = { 0.65, 0.95 }, Y = ABYSS_Y + 1.5 },
	}

	local function onAnyPlatform(x: number, z: number, pad: number): boolean
		for _, p in P do
			if math.abs(x - p.X) <= p.Width * 0.5 + pad and math.abs(z - p.Z) <= p.Depth * 0.5 + pad then
				return true
			end
		end
		return false
	end

	-- Scatter across the chasm perimeter, side gorges, and between terraces until propsPlaced >= 800
	-- while capping any single template strictly under 6% (well below the 11% ceiling!).
	local maxPerTemplate = 42
	local scatterTries = 0
	local specCursor = 1
	while propsPlaced < 805 and scatterTries < 4500 do
		scatterTries += 1
		local spec = chasmTemplates[specCursor]
		specCursor = (specCursor % #chasmTemplates) + 1
		if (templateCounts[spec.Name] or 0) >= maxPerTemplate then
			continue
		end

		local sx: number, sz: number
		local zone = scatterTries % 4
		if zone == 0 then
			-- Outer west & east perimeter cliff skirts (|X| = 365..452)
			local s = if (scatterTries % 2 == 0) then -1 else 1
			sx = s * rng:NextNumber(372, 452)
			sz = rng:NextNumber(-360, 290)
		elseif zone == 1 then
			-- Outer north & south chasm flanks
			sx = rng:NextNumber(-445, 445)
			sz = if (scatterTries % 8 < 4) then rng:NextNumber(-372, -295) else rng:NextNumber(305, 372)
		elseif zone == 2 then
			-- Mid chasm trenches between the Throne legs and outer galleries
			local s = if (scatterTries % 2 == 0) then -1 else 1
			sx = s * rng:NextNumber(80, 355)
			sz = rng:NextNumber(-280, 175)
		else
			-- Terrace rim edges (strictly off lanes, camps, and Apex interior)
			local rimList = { P.Basin, P.WestGallery, P.EastGallery, P.WestBastion, P.EastBastion, P.Crossing }
			local t = rimList[(scatterTries % #rimList) + 1]
			local edge = scatterTries % 4
			if edge == 0 then
				sx = t.X + rng:NextNumber(-t.Width * 0.45, t.Width * 0.45)
				sz = t.Z + t.Depth * 0.5 - rng:NextNumber(2.5, 6.0)
			elseif edge == 1 then
				sx = t.X + rng:NextNumber(-t.Width * 0.45, t.Width * 0.45)
				sz = t.Z - t.Depth * 0.5 + rng:NextNumber(2.5, 6.0)
			elseif edge == 2 then
				sx = t.X - t.Width * 0.5 + rng:NextNumber(2.5, 6.0)
				sz = t.Z + rng:NextNumber(-t.Depth * 0.45, t.Depth * 0.45)
			else
				sx = t.X + t.Width * 0.5 - rng:NextNumber(2.5, 6.0)
				sz = t.Z + rng:NextNumber(-t.Depth * 0.45, t.Depth * 0.45)
			end
		end

		-- Never crowd the BrokenStair->Apex open void (|X| < 48, Z in -118..-22) or Apex interior!
		if math.abs(sx) < 50 and sz > -120 and sz < -22 then continue end
		if math.abs(sx) < 112 and sz > -282 and sz < -118 then continue end
		if not campFree(sx, sz, 4) or not laneFree(sx, sz, 4) or not portalFree(sx, sz) then continue end

		local py: number
		if zone == 3 then
			local foundY: number? = nil
			for _, p in P do
				if math.abs(sx - p.X) <= p.Width * 0.5 and math.abs(sz - p.Z) <= p.Depth * 0.5 then
					foundY = p.Y
					break
				end
			end
			if not foundY then continue end
			py = foundY
		else
			if onAnyPlatform(sx, sz, 8) then continue end
			py = spec.Y
		end

		local sc = rng:NextNumber(spec.Scale[1], spec.Scale[2])
		local yaw = rng:NextNumber(0, 360)
		local ov = if spec.Name == "PermafrostCage" or spec.Name == "RelicCageIron" or spec.Name == "AbyssReliquaryShrine" then RELIC_TINT else VAHL_50
		local mp = placeKit("ChasmProp_" .. spec.Name, sx, py, sz, yaw, spec.Name, sc, ov, nil)
		if zone ~= 3 then
			noCollide(mp)
		end
		if spec.Name == "HangingLantern" and mp then
			mp:SetAttribute("DirgeWardlight", true)
			safeTag(mp, "DirgeWardlight")
		elseif (spec.Name == "ChainAnchorBollard" or spec.Name == "ChainWinch") and mp then
			mp:SetAttribute("DirgeChain", true)
			safeTag(mp, "DirgeChain")
		end
	end

	-- =========================================================================
	-- H. GROUND COVER CLUMPS (>= 540 TowerDetail clumps: ash drifts, bone rubble, shards)
	-- =========================================================================
	local coverTemplates = { "VoidShards", "RuinRubble", "BoulderCluster" }
	local coverTries = 0
	local coverTerraces = { P.Basin, P.WestGallery, P.EastGallery, P.Crossing, P.FootW, P.FootE, P.WestBastion, P.EastBastion, P.ArmW, P.ArmE, P.ChainW, P.ChainE, P.ReliquaryW, P.ReliquaryE }
	while groundCoverPlaced < 560 and coverTries < 3600 do
		coverTries += 1
		local gx: number, gz: number, gy: number
		if groundCoverPlaced < 280 then
			-- Terrace edge ash & bone rubble clumps (thickest on north-facing edges!).
			local t = coverTerraces[(coverTries % #coverTerraces) + 1]
			local edge = coverTries % 4
			if edge == 0 then
				gx = t.X + rng:NextNumber(-t.Width * 0.46, t.Width * 0.46)
				gz = t.Z - t.Depth * 0.5 + rng:NextNumber(1.2, 4.5)
			elseif edge == 1 then
				gx = t.X + rng:NextNumber(-t.Width * 0.46, t.Width * 0.46)
				gz = t.Z + t.Depth * 0.5 - rng:NextNumber(1.2, 4.5)
			elseif edge == 2 then
				gx = t.X - t.Width * 0.5 + rng:NextNumber(1.2, 4.5)
				gz = t.Z + rng:NextNumber(-t.Depth * 0.46, t.Depth * 0.46)
			else
				gx = t.X + t.Width * 0.5 - rng:NextNumber(1.2, 4.5)
				gz = t.Z + rng:NextNumber(-t.Depth * 0.46, t.Depth * 0.46)
			end
			gy = t.Y
		else
			gx = rng:NextNumber(-445, 445)
			gz = rng:NextNumber(-368, 360)
			if onAnyPlatform(gx, gz, 5) then continue end
			gy = ABYSS_Y + 1.2
		end
		if not campFree(gx, gz, 2) or not laneFree(gx, gz, 2) or not portalFree(gx, gz) then continue end
		local tpl = coverTemplates[(coverTries % #coverTemplates) + 1]
		local sc = rng:NextNumber(0.32, 0.58)
		placeKit("AbyssGroundCover", gx, gy, gz, rng:NextNumber(0, 360), tpl, sc, SILVER_KEY_TINT, function(cf)
			lump("AshDriftClump", cf.Position + V(0, 0.35, 0), V(2.4, 0.7, 2.0) * sc * 2, ASH_GREY, Mat.Slate)
		end, true)
	end

	-- =========================================================================
	-- I. DIRGE ASH EMITTERS (<= 16 emitters, drifting northward toward the Throne!)
	-- =========================================================================
	for _, ep in {
		V(0, 10, 295), V(-180, 4, 215), V(180, 4, 215),
		V(-320, 14, 95), V(320, 18, 95),
		V(0, 22, 110), V(0, 34, 15),
		V(-330, 38, -90), V(330, 42, -90),
		V(-200, 68, -265), V(200, 72, -265),
		V(0, 78, -200), V(0, 120, -310),
	} do
		ashEmitter(ep, 4)
	end

	local distinctCount = 0
	for _ in templatesUsed do
		distinctCount += 1
	end

	ctx.setAttribute("AbyssalFloor", 50)
	ctx.setAttribute("PlacedPropCount", propsPlaced)
	ctx.setAttribute("GroundCoverCount", groundCoverPlaced)
	ctx.setAttribute("DistinctTemplateCount", distinctCount)
	ctx.setAttribute("SetPieceLightCount", lightsUsed)
	ctx.setAttribute("SetPieceEmitterCount", emittersUsed)
end

return AbyssalFloor50
