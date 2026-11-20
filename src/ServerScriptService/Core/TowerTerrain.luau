--!strict
-- ServerScriptService/Core/TowerTerrain.luau
-- Natural voxel terrain for a tower floor (GDD §3.3): every floor stands in its own little landscape.
--
--   * Chasm ground: rolling, with marsh pools (Water), lava crusts (CrackedLava) or frozen ponds (Ice).
--   * Mountain walls: noisy, partly terraced slopes from the chasm up past the ceiling hide the room's walls.
--   * Plateaus: steep rock aprons around every terrace, so terraces read as natural mesas.
--   * Land bridges: earthen embankments under every ramp and landing.
--   * The rock shelf behind the Apex is raised to the Apex, so its backdrop monuments stand on ground.
--
-- Walkways stay exactly where TowerLayout puts them, and the terrain never offers a new way onto them:
-- within reach of a terrace, ramp or landing the ground stays a full voxel (4.5 studs) under its top and edge,
-- since voxel surfaces render a little off their requested height, but never digs under the chasm floor; it
-- falls away at 1.4 studs per stud or steeper, which is too steep to walk (HeroNavigation needs a
-- ground normal of at least 0.65). The floor's invisible Ground slab (TowerRoomBuilder) still catches anyone
-- who drops into the chasm, so shallow pools read as wading water.
--
-- The field is analytic (TowerTerrain.Field), so the ecosystem scatter (TowerBiomeAssets) can ask for the
-- ground height, slope and kind of any spot without raycasting.

local TowerTerrain = {}

local RES = 4
local APRON = 1.4 -- studs of drop per stud of distance next to a walkway (>= 54 degrees: not walkable)
-- Voxel surfaces render up to about two studs off their requested height, so the ground keeps a full voxel
-- under walkways: UNDER below a terrace top or deck, and RIM below the edge where an apron starts.
local UNDER = 4.5
local RIM = 4.5
local MOAT = 6

export type Palette = {
	Ground: Enum.Material,
	Lush: Enum.Material,
	Slope: Enum.Material,
	Cliff: Enum.Material,
	Peak: Enum.Material,
	Shore: Enum.Material,
	Liquid: Enum.Material,
	LiquidSolid: boolean, -- lava crust or ice: a solid surface instead of carved, filled water
}

local M = Enum.Material
local Palettes: { [string]: Palette } = {
	verdant_ruins = { Ground = M.Grass, Lush = M.LeafyGrass, Slope = M.LeafyGrass, Cliff = M.Rock, Peak = M.Slate, Shore = M.Mud, Liquid = M.Water, LiquidSolid = false },
	fungal_hollow = { Ground = M.Mud, Lush = M.LeafyGrass, Slope = M.Slate, Cliff = M.Slate, Peak = M.Basalt, Shore = M.Ground, Liquid = M.Water, LiquidSolid = false },
	ashen_dunes = { Ground = M.Sand, Lush = M.Sandstone, Slope = M.Sandstone, Cliff = M.Basalt, Peak = M.Basalt, Shore = M.Basalt, Liquid = M.CrackedLava, LiquidSolid = true },
	frozen_citadel = { Ground = M.Snow, Lush = M.Snow, Slope = M.Glacier, Cliff = M.Rock, Peak = M.Snow, Shore = M.Glacier, Liquid = M.Ice, LiquidSolid = true },
	infernal_foundry = { Ground = M.Basalt, Lush = M.Ground, Slope = M.Basalt, Cliff = M.Basalt, Peak = M.Slate, Shore = M.Basalt, Liquid = M.CrackedLava, LiquidSolid = true },
	thunder_highlands = { Ground = M.Grass, Lush = M.LeafyGrass, Slope = M.Grass, Cliff = M.Slate, Peak = M.Rock, Shore = M.Mud, Liquid = M.Water, LiquidSolid = false },
	corrupted_grove = { Ground = M.Mud, Lush = M.LeafyGrass, Slope = M.Ground, Cliff = M.Slate, Peak = M.Basalt, Shore = M.Mud, Liquid = M.Water, LiquidSolid = false },
	sunken_sanctuary = { Ground = M.Sand, Lush = M.Grass, Slope = M.Limestone, Cliff = M.Limestone, Peak = M.Sandstone, Shore = M.Sand, Liquid = M.Water, LiquidSolid = false },
	astral_archives = { Ground = M.Salt, Lush = M.Limestone, Slope = M.Limestone, Cliff = M.Slate, Peak = M.Salt, Shore = M.Salt, Liquid = M.Glacier, LiquidSolid = true },
	abyssal_throne = { Ground = M.Basalt, Lush = M.Slate, Slope = M.Slate, Cliff = M.Basalt, Peak = M.Slate, Shore = M.Basalt, Liquid = M.CrackedLava, LiquidSolid = true },
}
TowerTerrain.Palettes = Palettes

-- Surface palettes for hand-authored floors whose terraces and ramps are the terrain itself (TowerLayout
-- `Terrain.Direct`): what paths, walk surfaces, banks, cliffs and pool beds are made of.
export type Surface = {
	Trail: Enum.Material, -- the trodden spine of every ramp and path
	Walk: Enum.Material, -- terrace and ramp ground
	WalkAccent: Enum.Material, -- flags and patches broken into the walk ground
	Bank: Enum.Material, -- slopes and aprons
	Cliff: Enum.Material,
	Peak: Enum.Material,
	PoolBed: Enum.Material,
	Lush: Enum.Material, -- open chasm ground
}
local Surfaces: { [string]: Surface } = {
	-- Fungal Hollow: violet Velmari cobble trails over an indigo spore-moss carpet, indigo slate cliffs and
	-- wet teal-black pool beds. Every material here is Fungal-owned (see MaterialColors).
	FUNGAL = { Trail = M.Cobblestone, Walk = M.Concrete, WalkAccent = M.Pavement, Bank = M.Concrete,
		Cliff = M.Pavement, Peak = M.Basalt, PoolBed = M.Asphalt, Lush = M.Concrete },
	-- Infernal Foundry (the Sootwrights): sooty basalt yards, slate-grey trodden tracks, patches of brown ash,
	-- slate banks and cracked-lava sumps. (Never Brick or WoodPlanks: see BlockyMaterials.)
	SOOTWRIGHT = { Trail = M.Slate, Walk = M.Basalt, WalkAccent = M.Ground, Bank = M.Slate,
		Cliff = M.Basalt, Peak = M.Slate, PoolBed = M.CrackedLava, Lush = M.Basalt },
}
TowerTerrain.Surfaces = Surfaces

-- Terrain material colours. Only the tower floors use voxel terrain (the hub is built from parts), so these
-- are safe to set place-wide; they replicate with the Terrain. They are place-wide, so a colour belongs to
-- one look: Cobblestone, Concrete, Pavement and Asphalt are Fungal-owned (no biome palette uses them), and
-- tests/tower-layout-variants.spec.luau keeps them that way.
TowerTerrain.MaterialColors = table.freeze({
	[M.Grass] = Color3.fromRGB(82, 132, 58),
	[M.LeafyGrass] = Color3.fromRGB(62, 114, 50),
	[M.Mud] = Color3.fromRGB(70, 56, 46),
	[M.Ground] = Color3.fromRGB(96, 80, 62),
	[M.Rock] = Color3.fromRGB(104, 106, 100),
	-- Fungal Hollow
	[M.Cobblestone] = Color3.fromRGB(96, 74, 138), -- violet Velmari cobble
	[M.Concrete] = Color3.fromRGB(50, 44, 82), -- indigo spore-moss carpet
	[M.Pavement] = Color3.fromRGB(56, 52, 84), -- indigo slate
	[M.Asphalt] = Color3.fromRGB(22, 40, 50), -- wet teal-black pool beds
	[M.Sand] = Color3.fromRGB(154, 136, 108),
	[M.Sandstone] = Color3.fromRGB(182, 148, 108),
	[M.Basalt] = Color3.fromRGB(58, 52, 54),
	[M.Snow] = Color3.fromRGB(240, 246, 254),
	[M.Ice] = Color3.fromRGB(106, 174, 224),
})
TowerTerrain.FungalMaterials = table.freeze({ M.Cobblestone, M.Concrete, M.Pavement, M.Asphalt })
-- Terrain materials Roblox shapes as blocks: a smooth slope written in them collides as 4-stud steps, which no
-- hero can climb (measured in Studio, 2026-11-20). No palette or surface may use them for terrain.
TowerTerrain.BlockyMaterials = table.freeze({ M.Brick, M.WoodPlanks })
local colorsApplied = false
local function applyColors()
	if colorsApplied then return end
	colorsApplied = true
	for material, color in TowerTerrain.MaterialColors do
		workspace.Terrain:SetMaterialColor(material, color)
	end
	workspace.Terrain.WaterColor = Color3.fromRGB(44, 138, 132)
	workspace.Terrain.WaterTransparency = 0.38
	workspace.Terrain.WaterReflectance = 0.14
end

export type Field = {
	Height: (x: number, z: number) -> number,
	-- "CHASM", "POOL", "MOUNTAIN", "APRON", "BRIDGE", "WALK"; direct floors add "TRAIL" (a path's trodden
	-- spine) and "ISLAND" (an authored rock island in a pool).
	Kind: (x: number, z: number) -> string,
	Slope: (x: number, z: number) -> number,
	Sample: (x: number, z: number) -> (number, string),
	Bottom: number,
	LiquidLevel: number,
	Palette: Palette,
	Surface: Surface?, -- direct floors only
	-- An authored feature's own material at a spot (a slag tip's clinker and glowing seams), or nil.
	Accent: ((x: number, z: number) -> Enum.Material?)?,
}

-- Direct floors (TowerLayout `Terrain.Direct`): smooth voxel terrain renders its surface about RES / 2 above
-- the requested field height, so the field sits SOFT under a natural terrace or ramp to land flush with its
-- walking plane (its part stays as an invisible proxy), STAIR_UNDER under stair treads, and UNDER under
-- built decks (solid, visible masonry).
local SOFT = 2.0
local STAIR_UNDER = 2.8

local function fbm(x: number, z: number, seed: number, octaves: number): number
	local total, amp, freq, norm = 0, 1, 1, 0
	for _ = 1, octaves do
		total += math.noise(x * freq, z * freq, seed) * amp
		norm += amp
		amp *= 0.5
		freq *= 2.03
	end
	return total / norm
end

-- Walkway shapes in local coordinates: terrace rectangles and ramp/landing strips.
-- On a direct floor, rects and strips also say what they are: built decks (IsDeck), bridge decks that raise
-- no ground under themselves (IsBridge), stairs (IsStair) and ramps (IsRamp); other floors ignore the flags.
local function walkways(layout: any): ({ any }, { any })
	local td = layout.Terrain
	local decks = td and td.Decks or {}
	local bridges = td and td.DeckThickness or {}
	local shapes = td and td.Shapes or {}
	local bridgeLinks = td and td.Bridges or {}
	local rects, strips = {}, {}
	local deckMap = layout.Decks
	local susp = layout.Suspended
	local suspPlatMap = susp and susp.Platforms
	local suspLinkMap = susp and susp.Links
	for id, p in layout.Platforms do
		if suspPlatMap and suspPlatMap[id] then
			continue
		end
		local isDeck = decks[id] == true or (deckMap ~= nil and deckMap[id] == true)
		table.insert(rects, { X = p.X, Z = p.Z, HX = p.Width / 2, HZ = p.Depth / 2, Y = p.Y, IsDeck = isDeck,
			IsBridge = bridges[id] ~= nil, Round = shapes[id] })
	end
	local function addLink(link: any, bridgeSuspended: boolean)
		local isStair = link.Kind == "STAIRS"
		if not bridgeSuspended then
			table.insert(strips, { AX = link.AX, AY = link.AY, AZ = link.AZ, BX = link.BX, BY = link.BY, BZ = link.BZ, Half = link.Width / 2, IsStair = isStair, IsRamp = true,
				IsHung = bridgeLinks[link.Id] == true })
		end
		for _, name in { "LandingA", "LandingB" } do
			local pad = link[name]
			local padPlat = if name == "LandingA" then link.From else link.To
			if suspPlatMap and suspPlatMap[padPlat] then
				continue
			end
			local padDeck = decks[padPlat] == true or (deckMap ~= nil and deckMap[padPlat] == true)
			table.insert(strips, { AX = pad.AX, AY = pad.AY, AZ = pad.AZ, BX = pad.BX, BY = pad.BY, BZ = pad.BZ, Half = pad.Width / 2, IsDeck = padDeck,
				IsBridge = bridges[padPlat] ~= nil })
		end
	end
	for _, link in layout.Links do
		addLink(link, suspLinkMap ~= nil and suspLinkMap[link.Id] == true)
	end
	for _, link in layout.ReturnLinks or {} do
		addLink(link, false)
	end
	return rects, strips
end

function TowerTerrain.Field(layout: any, biomeId: string, floorId: number): Field
	local palette = Palettes[biomeId] or Palettes.verdant_ruins
	local w, d, h = layout.Width, layout.Depth, layout.Height
	local bottom = layout.Bottom - 4 -- the chasm floor (top of the Ground slab)
	local seed = floorId * 17.37
	local rects, strips = walkways(layout)
	local apex = layout.Platforms.Apex
	local directTerrain = layout.DirectTerrain == true
	local liquidCfg = layout.Liquid
	local features = layout.TerrainFeatures
	local dryPools = liquidCfg ~= nil and liquidCfg.Dry == true
	-- An authored floor can shape its own ground (TowerLayout `Terrain`): direct walkways, its own pools and
	-- islands, the water level and pool depth, and the width of the mountain band.
	local td = layout.Terrain
	local direct = td ~= nil and td.Direct == true
	-- A floor with top-level DirectTerrain names its surface beside it (layout.Surface, e.g. Floor 21).
	local surface = if direct and td.Surface then Surfaces[td.Surface]
		elseif directTerrain and layout.Surface then Surfaces[layout.Surface]
		else nil
	if surface then
		palette = table.clone(palette)
		palette.Cliff, palette.Peak, palette.Shore = surface.Cliff, surface.Peak, surface.PoolBed
		palette.Ground, palette.Lush, palette.Slope = surface.Walk, surface.Lush, surface.Bank
	end
	local liquidLevel = if td and td.LiquidRise then bottom + td.LiquidRise
		elseif liquidCfg and liquidCfg.LevelOffset then bottom + liquidCfg.LevelOffset
		else bottom - 0.3
	local floorDip = if td and td.FloorDip then td.FloorDip elseif liquidCfg and liquidCfg.FloorDip then liquidCfg.FloorDip else 2.6
	-- An authored floor whose Apex stands in the middle of the room (floor 10) has no shelf behind it.
	local noShelf = td ~= nil and td.NoApexShelf == true
	local reach = 0
	for _, r in rects do
		reach = math.max(reach, (r.Y - bottom + 12) / APRON)
	end

	-- Slag tips (TerrainFeatures SLAG_TIP, Infernal): a heap of tipped slag at (X, Z), Top studs over the floor,
	-- spilling a widening fan Length studs along Yaw (degrees; 0 = +Z, 90 = +X). Returns the heap's height
	-- over the floor and how far inside it the spot is (0 outside, 1 on the crest), or 0, 0.
	local slagTips = {}
	local pourPits = {}
	local lavaFalls = {}
	for _, feat in features or {} do
		if feat.Kind == "SLAG_TIP" then
			local yaw = math.rad(feat.Yaw or 0)
			table.insert(slagTips, { X = feat.X, Z = feat.Z, Top = feat.Top, Length = feat.Length, DX = math.sin(yaw), DZ = math.cos(yaw),
				Half = feat.HalfWidth or 18, Spread = feat.Spread or 24 })
		elseif feat.Kind == "POUR_PIT" then
			table.insert(pourPits, {
				X = feat.X or 0, Z = feat.Z or 0,
				RX = feat.RX or 75, RZ = feat.RZ or 60,
				RimWidth = feat.RimWidth or 16, RimHeight = feat.RimHeight or 3.8,
				NoiseAmp = feat.NoiseAmp or 0.14, NoiseSeed = feat.NoiseSeed or 141,
				Gain = feat.Gain or 0.42,
			})
		elseif feat.Kind == "LAVA_FALL" then
			table.insert(lavaFalls, {
				X = feat.X or 0, Z = feat.Z or 0,
				HalfW = (feat.Width or 26) * 0.5, HalfD = (feat.Depth or 38) * 0.5,
				Height = feat.Height or 110, Axis = feat.Axis or "X",
				RibbonHalf = (feat.RibbonWidth or 10) * 0.5,
			})
		end
	end
	local function pourPitDist(pit: any, x: number, z: number): number
		return math.sqrt(((x - pit.X) / pit.RX) ^ 2 + ((z - pit.Z) / pit.RZ) ^ 2)
			+ pit.NoiseAmp * fbm(x / 22, z / 22, seed + pit.NoiseSeed, 2)
	end
	local function slagTip(x: number, z: number): (number, number)
		local bestH, bestW = 0, 0
		for i, tip in slagTips do
			local rx, rz = x - tip.X, z - tip.Z
			local along = rx * tip.DX + rz * tip.DZ
			local across = math.abs(rx * tip.DZ - rz * tip.DX)
			local t = along / tip.Length
			if t > -0.3 and t < 1 then
				local half = tip.Half + tip.Spread * math.max(t, 0)
				-- Behind the crest the heap rounds off over a short back slope.
				local fall = if t < 0 then (1 + t / 0.3) else (1 - t) ^ 1.25
				local u = across / half + 0.1 * fbm(x / 16, z / 16, seed + 101 + i, 2)
				if u < 1 and fall > 0 then
					local lumps = 1 + 0.14 * fbm(x / 9, z / 9, seed + 107 + i, 2)
					local height = tip.Top * fall * (1 - u * u) ^ 0.6 * lumps
					if height > bestH then
						bestH, bestW = height, (1 - u) * fall
					end
				end
			end
		end
		return bestH, bestW
	end

	-- Ground before walkways: chasm, pools, dunes and mountains.
	local function natural(x: number, z: number): (number, string)
		local base = bottom + 1.6 * fbm(x / 70, z / 70, seed, 3) + 0.7 * fbm(x / 23, z / 23, seed + 3, 2)
		local kind = "CHASM"
		-- Mountains: a noisy band along every wall, terraced into ledges, rising past the ceiling.
		local edge = math.min(w / 2 - math.abs(x), d / 2 - math.abs(z))
		local band = if td and td.WallBand then td.WallBand.Base + td.WallBand.Noise * fbm(x / 95, z / 95, seed + 7, 2)
			else 58 + 26 * fbm(x / 95, z / 95, seed + 7, 2)
		if directTerrain then
			band = 34 + 14 * fbm(x / 95, z / 95, seed + 7, 2)
			if features and z < apex.Z then
				for _, feat in features do
					if feat.Kind == "APEX_ALCOVE" then
						local alcove = math.clamp((math.abs(x - apex.X) - feat.Width) / feat.Feather, 0, 1)
						band *= alcove
					end
				end
			end
		end
		if edge < band then
			local t = 1 - math.max(edge, 0) / band
			-- Ridged noise breaks the slopes into spurs and gullies instead of smooth pyramids.
			local ridge = 1 - math.abs(fbm(x / 34, z / 34, seed + 17, 3)) * 2
			local rise = (h + 40 - bottom) * t ^ 1.35 * (0.7 + 0.18 * fbm(x / 40, z / 40, seed + 11, 2) + 0.22 * ridge)
			local ledge = 9 + 3 * fbm(x / 60, z / 60, seed + 13, 1)
			rise -= (rise % ledge) * 0.55
			if bottom + rise > base then
				base = bottom + rise
				kind = "MOUNTAIN"
			end
		end
		-- The open chasm never dips under its floor: the floor's invisible Ground slab is the walking surface
		-- there, so lower ground would leave anyone walking on air above it. Only pools go lower (under water).
		if kind == "CHASM" then
			base = math.max(base, bottom)
		end
		-- Slag tips heap up over open ground and the mountain foot alike (kept off walkways by the caps below).
		if #slagTips > 0 then
			local heap = slagTip(x, z)
			if heap > 0.5 and bottom + heap > base then
				base, kind = bottom + heap, "MOUNTAIN"
			end
		end
		-- Lava falls: volcanic cascade chutes banked into the outer cavern mountain walls.
		for i, fall in lavaFalls do
			local fx, fz = math.abs(x - fall.X), math.abs(z - fall.Z)
			if fx < fall.HalfW and fz < fall.HalfD then
				local ux = 1 - (fx / fall.HalfW) ^ 1.6
				local uz = 1 - (fz / fall.HalfD) ^ 1.6
				local warp = 1 + 0.14 * fbm(x / 18, z / 18, seed + 151 + i, 2)
				local cliffH = fall.Height * ux * uz * warp
				if bottom + cliffH > base then
					base, kind = bottom + cliffH, "MOUNTAIN"
				end
			end
		end
		-- Pour pits: a jagged volcanic basalt berm ringing the molten cauldron (kept off walkways by caps).
		if kind == "CHASM" then
			for _, pit in pourPits do
				local pd = pourPitDist(pit, x, z)
				local rimNorm = pit.RimWidth / math.max(pit.RX, pit.RZ)
				if pd >= 1.0 and pd < 1.0 + rimNorm then
					local t = 1 - (pd - 1.0) / rimNorm
					local rimH = pit.RimHeight * (t * t * (3 - 2 * t)) * (0.78 + 0.22 * fbm(x / 10, z / 10, seed + 149, 2))
					base = math.max(base, bottom + rimH)
				end
			end
		end
		-- Authored wind-carved sand dunes in open desert basins (walkway caps still protect terraces/ramps).
		if kind == "CHASM" and features then
			for _, feat in features do
				if feat.Kind == "DUNE" then
					local dx = x - feat.X
					local dz = z - feat.Z
					local yaw = math.rad(feat.Yaw or 0)
					local c, s = math.cos(-yaw), math.sin(-yaw)
					local lx = dx * c - dz * s
					local lz = dx * s + dz * c
					local u = lx / (feat.Width * 0.5)
					local v = lz / (feat.Length * 0.5)
					local d2 = u * u + v * v
					if d2 < 1 then
						local env = (1 - d2) ^ 1.45
						local crestCurve = (feat.CrestSway or 0.18) * math.sin(v * math.pi * 1.15)
						local off = u - crestCurve
						-- Windward slope (west/negative) rises gradually; slip-face (east/positive) falls sharper for a crisp S-crest.
						local flank = if off > 0 then math.abs(off) * (feat.SlipSteep or 1.45) else math.abs(off) * 0.95
						local ridge = math.max(0, 1 - flank)
						local peak = feat.Height * env * (0.45 + 0.55 * ridge)
						local ripple = (feat.RippleAmp or 0.22) * math.sin((lx + lz * 0.35) * 0.45) * env
						base = math.max(base, bottom + peak + ripple)
					end
				elseif feat.Kind == "RAVINE" then
					if z >= feat.ZStart and z <= feat.ZEnd then
						local meander = (feat.NoiseAmp or 8) * fbm(z / 55, 0, seed + 51, 2)
						local dist = math.abs(x - (feat.X or 0) - meander)
						if dist < feat.HalfWidth then
							-- Deep wind-scoured canyon trench along the ravine spine
							base = bottom
							if feat.IceFloor and palette.LiquidSolid and dist < feat.HalfWidth * 0.62 then
								kind = "POOL"
							end
						end
					end
				elseif feat.Kind == "GLACIER_SPINE" then
					-- Raised, strata-banded glacier ridge running along the spine under elevated Iceway slabs
					local z0, z1 = feat.ZStart or -152, feat.ZEnd or 68
					if z >= z0 - 18 and z <= z1 + 18 then
						local endFade = math.clamp(math.min(z - (z0 - 18), (z1 + 18) - z) / 22, 0, 1)
						local meander = (feat.NoiseAmp or 5) * fbm(z / 44, 0, seed + 91, 2)
						local hw = (feat.HalfWidth or 42) * (0.88 + 0.22 * fbm(z / 28, 0, seed + 97, 2))
						local dist = math.abs(x - (feat.X or 0) - meander)
						if dist < hw then
							local u = dist / hw
							local wallProfile = (1 - u ^ 1.8) ^ 0.72
							local alongT = math.clamp((z1 - z) / math.max(1, z1 - z0), 0, 1)
							local shelfH = (feat.BaseHeight or 12) + alongT * (feat.RiseHeight or 8)
							local strata = math.sin(z * 0.26 + u * 2.4) * (feat.StrataAmp or 1.4) * (1 - u)
							local hRidge = bottom + (shelfH * wallProfile + strata) * endFade
							if hRidge > base then
								base = hRidge
								kind = "APRON"
							end
						end
					end
				elseif feat.Kind == "ICEFALL" then
					-- Frozen cascade bank rising along a north cliff pocket behind Apex/Rimefall
					local fx = x - (feat.X or 0)
					local fz = z - (feat.Z or 0)
					local hw = (feat.Width or 80) * 0.5
					local hd = (feat.Depth or 32) * 0.5
					if math.abs(fx) < hw and math.abs(fz) < hd then
						local ux = 1 - (math.abs(fx) / hw) ^ 1.6
						local uz = 1 - math.max(0, fz / hd)
						local stepH = (feat.Height or 36) * ux * math.clamp(uz, 0, 1)
						local warp = 1 + 0.18 * fbm(x / 18, z / 18, seed + 71, 2)
						if bottom + stepH * warp > base then
							base = bottom + stepH * warp
							kind = "MOUNTAIN"
						end
					end
				end
			end
		end
		-- Pools in the open chasm.
		if kind == "CHASM" and not dryPools then
			-- An authored floor has only its own pools (noisy shores), never random ones in its lanes.
			local wet = if td and td.Pools then -1 else fbm(x / 75 + 40, z / 75 - 40, seed + 21, 2)
			for _, pool in (td and td.Pools) or {} do
				local e = ((x - pool.X) / pool.RX) ^ 2 + ((z - pool.Z) / pool.RZ) ^ 2 + 0.18 * fbm(x / 21, z / 21, seed + 29, 2)
				if e < 1 then
					-- Steep: most of the ellipse is at full depth, so a pool round an island is open water, not a
					-- shallow ring.
					wet = math.max(wet, 0.28 + (1 - e) * 0.6)
				end
			end
			if features then
				for _, feat in features do
					if feat.Kind == "POOL_ELLIPSES_SQ" then
						local best = math.huge
						for _, e in feat.Ellipses do
							local dSq = ((x - e.X) / e.RX) ^ 2 + ((z - e.Z) / e.RZ) ^ 2
							if dSq < best then best = dSq end
						end
						if best < 1.0 then
							wet = math.max(wet, feat.Strength + (1.0 - best) * feat.Gain)
						end
					elseif feat.Kind == "RIVER_GORGE" then
						local riverZ = feat.BaseZ + feat.Amp * math.sin(x / feat.Freq) + feat.NoiseAmp * fbm(x / feat.NoiseScale, z / feat.NoiseScale, seed + feat.NoiseSeed, 2)
						local riverBand = math.abs(z - riverZ) / feat.HalfWidth
						local dist = riverBand
						if feat.WestPool then
							local wp = feat.WestPool
							local wDist = math.sqrt(((x - wp.X) / wp.RX) ^ 2 + ((z - wp.Z) / wp.RZ) ^ 2)
							dist = math.min(dist, wDist)
						end
						if dist < 1.0 then
							wet = math.max(wet, 0.28 + (1.0 - dist) * feat.Gain)
						end
					elseif feat.Kind == "MOAT_CHANNELS" then
						local moatZ = feat.BaseZ + feat.Amp * math.sin(x / feat.Freq) + feat.NoiseAmp * fbm(x / feat.NoiseScale, z / feat.NoiseScale, seed + feat.NoiseSeed, 2)
						local dist = math.abs(z - moatZ) / feat.HalfWidth
						for _, ch in feat.Channels or {} do
							local cDist = math.sqrt(((x - ch.X) / ch.RX) ^ 2 + ((z - ch.Z) / ch.RZ) ^ 2)
							if cDist < dist then dist = cDist end
						end
						if dist < 1.0 then
							wet = math.max(wet, 0.28 + (1.0 - dist) * feat.Gain)
						end
					elseif feat.Kind == "CENOTE_LAGOON" then
						local cDist = math.sqrt((x / feat.RX) ^ 2 + ((z - feat.Z) / feat.RZ) ^ 2) + feat.NoiseAmp * fbm(x / feat.NoiseScale, z / feat.NoiseScale, seed + feat.NoiseSeed, 2)
						if cDist < 1.0 then
							wet = math.max(wet, feat.Base + (1.0 - cDist) * feat.Gain)
						end
					elseif feat.Kind == "LAVA_CHANNEL" then
						local meander = (feat.NoiseAmp or 6) * fbm(z / 48, 0, seed + 63, 2)
						local dist = math.huge
						if z >= feat.ZStart and z <= feat.ZEnd then
							dist = math.abs(x - (feat.X or 0) - meander) / feat.HalfWidth
						end
						if feat.GateMoat then
							local gm = feat.GateMoat
							local gDist = math.sqrt((x / gm.RX) ^ 2 + ((z - gm.Z) / gm.RZ) ^ 2)
							if gDist < dist then dist = gDist end
						end
						if dist < 1.0 then
							wet = math.max(wet, 0.28 + (1.0 - dist) * (feat.Gain or 0.36))
						end
					elseif feat.Kind == "POUR_PIT" then
						local pd = math.sqrt(((x - (feat.X or 0)) / (feat.RX or 75)) ^ 2 + ((z - (feat.Z or 0)) / (feat.RZ or 60)) ^ 2)
							+ (feat.NoiseAmp or 0.14) * fbm(x / 22, z / 22, seed + (feat.NoiseSeed or 141), 2)
						if pd < 1.0 then
							wet = math.max(wet, 0.30 + (1.0 - pd) * (feat.Gain or 0.42))
						end
					end
				end
			end
			if wet > 0.28 then
				local depth = math.clamp((wet - 0.28) / 0.12, 0, 1)
				base = if palette.LiquidSolid then math.min(base, liquidLevel + 0.05) else base - (base - (bottom - floorDip)) * depth
				kind = "POOL"
				if palette.LiquidSolid and features then
					for _, feat in features do
						if feat.Kind == "PRESSURE_RIDGE" then
							for _, seg in feat.Ridges or {} do
								local dx, dz = seg.BX - seg.AX, seg.BZ - seg.AZ
								local len = math.max(math.sqrt(dx * dx + dz * dz), 1e-3)
								local t = math.clamp(((x - seg.AX) * dx + (z - seg.AZ) * dz) / (len * len), 0, 1)
								local cx = seg.AX + dx * t + (seg.WarpAmp or 5) * math.sin(t * math.pi * 2)
								local cz = seg.AZ + dz * t
								local dLine = math.sqrt((x - cx) ^ 2 + (z - cz) ^ 2)
								local halfW = seg.HalfWidth or 4.5
								if dLine < halfW then
									local crest = (1 - dLine / halfW) * (seg.Height or 2.0) * (0.75 + 0.25 * fbm(x / 12, z / 12, seed + 83, 2))
									base = math.max(base, liquidLevel + crest)
								end
							end
						end
					end
				end
			end
		end
		-- Authored rock islands: a flat crown with steep, noisy shores, rising out of their pool.
		for _, island in (td and td.Islands) or {} do
			local dist = math.sqrt((x - island.X) ^ 2 + (z - island.Z) ^ 2) / island.R + 0.12 * fbm(x / 14, z / 14, seed + 33, 2)
			if dist < 1 then
				local t = math.clamp((1 - dist) / 0.45, 0, 1)
				local top = island.Top + 0.8 * fbm(x / 9, z / 9, seed + 37, 2)
				local y = (bottom - floorDip) + (top - (bottom - floorDip)) * (t * t * (3 - 2 * t))
				if y > base then
					base, kind = y, "ISLAND"
				end
			end
		end
		return base, kind
	end

	-- Walkways: aprons and embankments raise the ground toward them; caps keep it below them.
	local directGrassLayout = directTerrain
	local function shaped(x: number, z: number): (number, string)
		local y, kind = natural(x, z)
		local wild, wildKind = y, kind
		local raise, cap = -math.huge, math.huge
		local nearest = math.huge
		local surface = -math.huge -- the highest walkway within reach
		local ownSurface = -math.huge -- exact surface when (x, z) is directly inside a walkway/terrace
		local ownIsDeck, ownIsStair = false, false
		local onTrail = false
		for _, r in rects do
			local dx = math.max(0, math.abs(x - r.X) - r.HX)
			local dz = math.max(0, math.abs(z - r.Z) - r.HZ)
			if dx < reach and dz < reach then
				local dist = math.sqrt(dx * dx + dz * dz)
				nearest = math.min(nearest, dist)
				local directGrass = directGrassLayout and not r.IsDeck
				if dist == 0 and (r.Y > ownSurface or (r.Y == ownSurface and ownIsDeck and not r.IsDeck)) then
					ownSurface = r.Y
					ownIsDeck = r.IsDeck == true
					ownIsStair = false
				end
				-- Smooth voxel terrain renders RES/2 (= 2 studs) above the requested field height, so subtract 2
				-- on direct-terrain grassy surfaces so Terrain lands flush on the authored Y plane.
				local rimD = if directGrass then 2.0 else RIM
				local underD = if directGrass then 2.0 else UNDER
				local warpDist = if directGrass and dist > 0 then math.max(0, dist - (1.5 + 2.0 * fbm(x / 18, z / 18, seed + 47, 2))) else dist
				local rim = r.Y - rimD
				surface = math.max(surface, r.Y)
				cap = math.min(cap, if dist == 0 then r.Y - underD else rim - APRON * warpDist)
				local steep = if directGrass
					then APRON * (0.72 + 0.45 * (0.5 + 0.5 * fbm(x / 16, z / 16, seed + 31, 2)))
					else APRON + 1.2 * (0.5 + 0.5 * fbm(x / 18, z / 18, seed + 31, 2))
				raise = math.max(raise, rim - steep * warpDist)
			end
		end
		for _, s in strips do
			local dx, dz = s.BX - s.AX, s.BZ - s.AZ
			local len = math.max(math.sqrt(dx * dx + dz * dz), 1e-3)
			local ux, uz = dx / len, dz / len
			local rx, rz = x - s.AX, z - s.AZ
			local along = rx * ux + rz * uz
			local perp = math.abs(-uz * rx + ux * rz)
			local endDist = math.max(0, -along, along - len)
			local sideDist = math.max(0, perp - s.Half)
			local beyond = math.sqrt(endDist * endDist + sideDist * sideDist)
			if beyond < reach then
				local directGrass = directGrassLayout and not s.IsDeck and not s.IsStair
				local t = math.clamp(along / len, 0, 1)
				local stripY = s.AY + (s.BY - s.AY) * t
				local stripUnder = if directGrass then 2.0 elseif directGrassLayout and s.IsStair then 2.8 else UNDER
				local deck = stripY - stripUnder
				if beyond == 0 and (stripY > ownSurface or (stripY == ownSurface and (not s.IsDeck or not ownIsDeck) and s.IsRamp)) then
					ownSurface = stripY
					ownIsDeck = s.IsDeck == true
					ownIsStair = s.IsStair == true
				end
				local warpBeyond = if directGrass and beyond > 0 then math.max(0, beyond - (1.5 + 2.0 * fbm(x / 16, z / 16, seed + 53, 2))) else beyond
				nearest = math.min(nearest, beyond)
				surface = math.max(surface, stripY)
				cap = math.min(cap, deck - APRON * warpBeyond)
				local sideSlope = if directGrass
					then APRON * (0.68 + 0.45 * (0.5 + 0.5 * fbm(x / 15, z / 15, seed + 37, 2)))
					else APRON + 0.8
				raise = math.max(raise, deck - sideSlope * warpBeyond)
				if beyond == 0 then
					kind = "BRIDGE"
					if directGrass and perp <= (if s.IsRamp then 5.2 else 6.8) + 2.2 * fbm(x / 12, z / 12, seed + 41, 2) then
						onTrail = true
					end
				end
			end
		end
		if raise > y then
			y = raise
			if kind ~= "BRIDGE" then
				kind = "APRON"
			end
		end
		-- Clearance never digs under the chasm floor: every walkway stands above it, and digging deeper would
		-- only leave pits and walking-on-air spots over the invisible Ground slab.
		cap = math.max(cap, bottom)
		if ownSurface > -math.huge and directGrassLayout then
			-- A terrace or ramp directly under (x, z) is never cratered down by an adjacent lower terrace's cap.
			if ownIsDeck then
				y = math.min(y, ownSurface - UNDER)
			elseif ownIsStair then
				y = ownSurface - 2.8
			else
				y = ownSurface - 2.0
			end
		elseif cap < y then
			y = cap
		end
		-- A mountain may still rise beside a walkway as a canyon wall: past a moat MOAT studs wide, and only
		-- where it stands well above every walkway in reach, so its face is a cliff, never a way up.
		if wildKind == "MOUNTAIN" and nearest >= MOAT and wild >= surface + 8 and wild > y then
			y, kind = wild, "MOUNTAIN"
		end
		-- The shelf behind the Apex rises to it (the Apex's own cap keeps a lip at its back edge).
		if not noShelf and z < apex.Z - apex.Depth / 2 - 6 and math.abs(x - apex.X) < w / 2 - 30 then
			y = math.max(y, math.min(apex.Y - RIM, cap))
		end
		if nearest == 0 then
			kind = if onTrail then "TRAIL" else "WALK"
		elseif onTrail then
			kind = "TRAIL"
		end
		return y, kind
	end

	-- Direct floors: natural terraces and ramps ARE the terrain (their parts are invisible proxies), so the
	-- ground under each walkway lands exactly on its walking plane (SOFT below the field's surface, see
	-- above), aprons fall away along noise-warped edges instead of straight rectangles, and every path gets
	-- a trodden TRAIL spine. Built decks keep a voxel under them (UNDER); bridge decks raise no ground at all,
	-- so their pool runs on underneath; stair treads keep STAIR_UNDER. Where walkways overlap, the highest
	-- surface wins, and a ramp wins a tie with a deck so it meets the deck's landing flush.
	local function shapedDirect(x: number, z: number): (number, string)
		local y, kind = natural(x, z)
		local wild, wildKind = y, kind
		local raise, cap = -math.huge, math.huge
		local nearest = math.huge
		local surfaceY = -math.huge
		local own, ownDeck, ownStair, ownBridge = -math.huge, false, false, false
		local onTrail = false
		local hungNear = math.huge -- distance to the nearest hung walkway (it shapes no ground, but keeps cliffs off)
		for _, r in rects do
			local dx = math.max(0, math.abs(x - r.X) - r.HX)
			local dz = math.max(0, math.abs(z - r.Z) - r.HZ)
			if dx < reach and dz < reach then
				local dist = math.sqrt(dx * dx + dz * dz)
				local round = r.Round
				if round then
					-- A rounded terrace (`Terrain.Shapes`): a superellipse ("squircle") Grow studs past the
					-- terrace's edges, so a terrain island reads as rock, not a square slab. Its corners fall
					-- away; its edges' middles, where paths land, stay flat.
					local ax, az = r.HX + round.Grow, r.HZ + round.Grow
					local n = round.Round
					local sq = ((math.abs(x - r.X) / ax) ^ n + (math.abs(z - r.Z) / az) ^ n) ^ (1 / n)
					dist = math.max(0, (sq - 1) * math.min(ax, az))
				end
				nearest = math.min(nearest, dist)
				local soft = not r.IsDeck
				if dist == 0 and (r.Y > own or (r.Y == own and ownDeck and soft)) then
					own, ownDeck, ownStair, ownBridge = r.Y, r.IsDeck, false, r.IsBridge
				end
				local rim = r.Y - (if soft then SOFT else RIM)
				local warp = if soft and dist > 0 then math.max(0, dist - (1.5 + 2 * fbm(x / 18, z / 18, seed + 47, 2))) else dist
				surfaceY = math.max(surfaceY, r.Y)
				cap = math.min(cap, if dist == 0 then r.Y - (if soft then SOFT else UNDER) else rim - APRON * warp)
				if not r.IsBridge then
					local steep = if soft then APRON * (0.72 + 0.45 * (0.5 + 0.5 * fbm(x / 16, z / 16, seed + 31, 2)))
						else APRON + 1.2 * (0.5 + 0.5 * fbm(x / 18, z / 18, seed + 31, 2))
					raise = math.max(raise, rim - steep * warp)
				end
			end
		end
		for _, s in strips do
			local dx, dz = s.BX - s.AX, s.BZ - s.AZ
			local len = math.max(math.sqrt(dx * dx + dz * dz), 1e-3)
			local ux, uz = dx / len, dz / len
			local rx, rz = x - s.AX, z - s.AZ
			local along = rx * ux + rz * uz
			local perp = math.abs(-uz * rx + ux * rz)
			local endDist = math.max(0, -along, along - len)
			local sideDist = math.max(0, perp - s.Half)
			local beyond = math.sqrt(endDist * endDist + sideDist * sideDist)
			if s.IsHung then
				-- A hung walkway (`Terrain.Bridges`, rope and plank over the chasm): a solid part. The ground only
				-- keeps a voxel under its planks; over a terrace, the terrace's own ground stays as it is.
				if beyond < reach then
					local stripY = s.AY + (s.BY - s.AY) * math.clamp(along / len, 0, 1)
					cap = math.min(cap, stripY - UNDER - APRON * beyond)
					hungNear = math.min(hungNear, beyond)
				end
			elseif beyond < reach then
				local soft = not s.IsDeck and not s.IsStair
				local stripY = s.AY + (s.BY - s.AY) * math.clamp(along / len, 0, 1)
				local deck = stripY - (if soft then SOFT elseif s.IsStair then STAIR_UNDER else UNDER)
				if beyond == 0 and (stripY > own or (stripY == own and (not s.IsDeck or not ownDeck) and s.IsRamp)) then
					own, ownDeck, ownStair, ownBridge = stripY, s.IsDeck == true, s.IsStair == true, false
				end
				local warp = if soft and beyond > 0 then math.max(0, beyond - (1.5 + 2 * fbm(x / 16, z / 16, seed + 53, 2))) else beyond
				nearest = math.min(nearest, beyond)
				surfaceY = math.max(surfaceY, stripY)
				cap = math.min(cap, deck - APRON * warp)
				if not s.IsBridge then
					local side = if soft then APRON * (0.68 + 0.45 * (0.5 + 0.5 * fbm(x / 15, z / 15, seed + 37, 2))) else APRON + 0.8
					raise = math.max(raise, deck - side * warp)
				end
				if beyond == 0 then
					kind = "BRIDGE"
					if soft and perp <= (if s.IsRamp then 5.2 else 6.8) + 2.2 * fbm(x / 12, z / 12, seed + 41, 2) then
						onTrail = true
					end
				end
			end
		end
		if raise > y then
			y = raise
			if kind ~= "BRIDGE" then
				kind = "APRON"
			end
		end
		cap = math.max(cap, bottom)
		if own > -math.huge then
			-- A walkway directly overhead sets the ground itself; a lower neighbour's cap never craters it.
			y = if ownDeck then math.min(y, own - UNDER) elseif ownStair then own - STAIR_UNDER else own - SOFT
		elseif cap < y then
			y = cap
		end
		if wildKind == "MOUNTAIN" and nearest >= MOAT and hungNear >= MOAT and wild >= surfaceY + 8 and wild > y then
			y, kind = wild, "MOUNTAIN"
		end
		if not noShelf and z < apex.Z - apex.Depth / 2 - 6 and math.abs(x - apex.X) < w / 2 - 30 then
			y = math.max(y, math.min(apex.Y - SOFT, cap))
		end
		if ownBridge and (wildKind == "POOL" or wildKind == "CHASM") and y <= wild + 0.01 then
			-- Under a bridge deck the pool (or open ground) runs on.
			return y, wildKind
		end
		if wildKind == "POOL" and nearest > 0 and y < liquidLevel - 0.3 then
			-- A walkway's slope running down into a pool is a shore: still under water, so it keeps its water
			-- (otherwise an island would stand in a dry ring).
			return y, "POOL"
		end
		if nearest == 0 then
			kind = if onTrail then "TRAIL" else "WALK"
		elseif onTrail then
			kind = "TRAIL"
		end
		return y, kind
	end
	if direct then
		shaped = shapedDirect
	end

	local function height(x: number, z: number): number
		return (shaped(x, z))
	end
	local function slope(x: number, z: number): number
		local gx = (height(x + 2, z) - height(x - 2, z)) / 4
		local gz = (height(x, z + 2) - height(x, z - 2)) / 4
		return math.sqrt(gx * gx + gz * gz)
	end
	return {
		Height = height,
		Kind = function(x: number, z: number): string
			local _, kind = shaped(x, z)
			return kind
		end,
		Slope = slope,
		Sample = shaped,
		Bottom = bottom,
		LiquidLevel = liquidLevel,
		Palette = palette,
		Surface = surface,
		-- Authored feature materials: slag tips, glowing pour-pit rims, and volcanic lava-fall chutes.
		Accent = if #slagTips > 0 or #pourPits > 0 or #lavaFalls > 0
			then function(x: number, z: number): Enum.Material?
				for i, fall in lavaFalls do
					local fx, fz = math.abs(x - fall.X), math.abs(z - fall.Z)
					if fx < fall.HalfW and fz < fall.HalfD then
						local along = if fall.Axis == "Z" then x else z
						local across = if fall.Axis == "Z" then (z - fall.Z) else (x - fall.X)
						local sway = 3.5 * fbm(along / 18, 0, seed + 161 + i, 2)
						if math.abs(across - sway) < fall.RibbonHalf then
							return M.CrackedLava
						end
						return M.Basalt
					end
				end
				for _, pit in pourPits do
					local pd = pourPitDist(pit, x, z)
					local rimNorm = pit.RimWidth / math.max(pit.RX, pit.RZ)
					if pd >= 0.94 and pd < 1.0 + rimNorm then
						local seam = math.abs(fbm(x / 10, z / 10, seed + 157, 2))
						if pd < 1.04 or seam < 0.14 then
							return M.CrackedLava
						end
						return M.Basalt
					end
				end
				if #slagTips > 0 then
					local heap, inside = slagTip(x, z)
					if heap >= 1.5 then
						local seam = math.abs(fbm(x / 11, z / 11, seed + 131, 2))
						if seam < 0.07 + 0.08 * inside then
							return M.CrackedLava
						end
						return if math.noise(x / 13, z / 13, seed + 137) > 0.1 then M.Slate else M.Basalt
					end
				end
				return nil
			end
			else nil,
	}
end

local function materialFor(field: Field, palette: Palette, kind: string, y: number, slopeValue: number, x: number, z: number, seed: number, directTerrain: boolean?): Enum.Material
	local s = field.Surface
	if s then
		-- Direct floors: a trodden trail down every path, the walk ground broken by flags and trail patches,
		-- banks on the steeper ground, cliffs where it can't be walked.
		local tuft = math.noise(x / 17, z / 17, seed + 5)
		local patch = math.noise(x / 29, z / 29, seed + 13)
		if kind == "TRAIL" then
			return if tuft > 0.3 then s.WalkAccent else s.Trail
		elseif kind == "BRIDGE" or kind == "WALK" then
			return if patch > 0.34 then s.Trail elseif tuft > 0.2 then s.WalkAccent else s.Walk
		elseif kind == "POOL" then
			return s.PoolBed
		elseif kind == "ISLAND" then
			return if slopeValue > 0.9 then s.Cliff else s.Bank
		elseif slopeValue > 1.25 then
			return s.Cliff
		elseif slopeValue > 0.85 then
			return s.Bank
		elseif kind == "MOUNTAIN" and y - field.Bottom > 34 then
			return s.Peak
		end
		return if patch > 0.22 then s.WalkAccent else s.Lush
	end
	if directTerrain then
		local tuft = math.noise(x / 17, z / 17, seed + 5)
		local patch = math.noise(x / 29, z / 29, seed + 13)
		local trailMat = if palette.Ground == M.Grass then M.Ground else palette.Slope
		if kind == "TRAIL" then
			return if tuft > 0.28 then palette.Ground else trailMat
		elseif kind == "BRIDGE" or kind == "WALK" then
			if patch > 0.34 then
				return trailMat
			elseif tuft > 0.16 then
				return palette.Slope
			end
			return palette.Ground
		elseif kind == "POOL" then
			return if palette.LiquidSolid then palette.Liquid else M.Ground
		elseif slopeValue > 1.25 then
			return palette.Cliff
		elseif slopeValue > 0.85 then
			return if tuft > 0 then palette.Slope else palette.Ground
		elseif kind == "MOUNTAIN" and y - field.Bottom > 34 then
			return palette.Peak
		end
		return if patch > 0.22 then palette.Lush else palette.Ground
	end
	if kind == "BRIDGE" or kind == "WALK" or kind == "TRAIL" then
		return palette.Slope
	elseif kind == "POOL" then
		return if palette.LiquidSolid then palette.Liquid elseif field.LiquidLevel > field.Bottom then M.Ground else palette.Shore
	elseif slopeValue > 1.05 then
		return palette.Cliff
	elseif slopeValue > 0.5 then
		return palette.Slope
	elseif kind == "MOUNTAIN" and y - field.Bottom > 34 then
		return palette.Peak
	end
	return if math.noise(x / 31, z / 31, seed) > 0.12 then palette.Lush else palette.Ground
end

-- The vertical span of terrain a floor can hold, in local Y.
local function span(layout: any): (number, number)
	local yMin = math.floor((layout.Bottom - 16) / RES) * RES
	local yMax = math.ceil((layout.Height + 16) / RES) * RES
	return yMin, yMax
end

-- Removes the floor's terrain (room rebuilt or retired).
function TowerTerrain.Clear(origin: Vector3, layout: any)
	local yMin, yMax = span(layout)
	local size = Vector3.new(layout.Width + 16, yMax - yMin, layout.Depth + 16)
	workspace.Terrain:FillBlock(CFrame.new(origin + Vector3.new(0, (yMin + yMax) / 2, 0)), size, Enum.Material.Air)
end

-- Writes the floor's terrain and returns its field.
function TowerTerrain.Build(origin: Vector3, layout: any, biomeId: string, floorId: number): Field
	applyColors()
	TowerTerrain.Clear(origin, layout)
	local field = TowerTerrain.Field(layout, biomeId, floorId)
	local palette = field.Palette
	local terrain = workspace.Terrain
	local yMin, yMax = span(layout)
	-- Even column counts keep the region on the 4-stud voxel grid (room origins are multiples of 4).
	local nx = math.ceil(layout.Width / (2 * RES)) * 2
	local nz = math.ceil(layout.Depth / (2 * RES)) * 2
	local x0 = -nx * RES / 2
	local z0 = -nz * RES / 2
	local seed = floorId * 3.71

	-- Heights, kinds and materials per column.
	local heights, kinds, mats = table.create(nx), table.create(nx), table.create(nx)
	for i = 1, nx do
		local hRow, kRow, mRow = table.create(nz), table.create(nz), table.create(nz)
		local x = x0 + (i - 0.5) * RES
		for k = 1, nz do
			local z = z0 + (k - 0.5) * RES
			hRow[k], kRow[k] = field.Sample(x, z)
		end
		heights[i], kinds[i], mats[i] = hRow, kRow, mRow
	end
	for i = 1, nx do
		for k = 1, nz do
			local y = heights[i][k]
			local gx = (heights[math.min(i + 1, nx)][k] - heights[math.max(i - 1, 1)][k]) / (2 * RES)
			local gz = (heights[i][math.min(k + 1, nz)] - heights[i][math.max(k - 1, 1)]) / (2 * RES)
			local x = x0 + (i - 0.5) * RES
			local z = z0 + (k - 0.5) * RES
			mats[i][k] = materialFor(field, palette, kinds[i][k], y, math.sqrt(gx * gx + gz * gz), x, z, seed, layout.DirectTerrain == true)
		end
	end

	-- Voxels, written in strips of columns so no single write grows large. Each strip only spans up to its
	-- tallest column (most of the room is low; the mountain strips go up to the ceiling).
	local strip = 24
	for i0 = 1, nx, strip do
		local i1 = math.min(nx, i0 + strip - 1)
		local top = yMin
		for i = i0, i1 do
			for k = 1, nz do
				top = math.max(top, heights[i][k], field.LiquidLevel)
			end
		end
		local ny = math.clamp(math.ceil((top + RES - yMin) / RES), 1, (yMax - yMin) / RES)
		local materials, occupancy = table.create(i1 - i0 + 1), table.create(i1 - i0 + 1)
		for i = i0, i1 do
			local mCol, oCol = table.create(ny), table.create(ny)
			for j = 1, ny do
				local cellBottom = yMin + (j - 1) * RES
				local mRow, oRow = table.create(nz), table.create(nz)
				for k = 1, nz do
					local y = heights[i][k]
					local fill = math.clamp((y - cellBottom) / RES, 0, 1)
					if fill > 0 then
						mRow[k] = if y - cellBottom < RES * 2 then mats[i][k] else palette.Cliff
						oRow[k] = fill
					elseif not palette.LiquidSolid and kinds[i][k] == "POOL" and cellBottom < field.LiquidLevel then
						mRow[k] = palette.Liquid
						oRow[k] = math.clamp((field.LiquidLevel - cellBottom) / RES, 0, 1)
					else
						mRow[k] = Enum.Material.Air
						oRow[k] = 0
					end
				end
				mCol[j], oCol[j] = mRow, oRow
			end
			materials[i - i0 + 1], occupancy[i - i0 + 1] = mCol, oCol
		end
		local lo = origin + Vector3.new(x0 + (i0 - 1) * RES, yMin, z0)
		local hi = origin + Vector3.new(x0 + i1 * RES, yMin + ny * RES, z0 + nz * RES)
		terrain:WriteVoxels(Region3.new(lo, hi):ExpandToGrid(RES), RES, materials, occupancy)
	end
	return field
end

return TowerTerrain
