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

-- Terrain material colours. Only the tower floors use voxel terrain (the hub is built from parts), so these
-- are safe to set place-wide; they replicate with the Terrain.
TowerTerrain.MaterialColors = table.freeze({
	[M.Grass] = Color3.fromRGB(82, 132, 58),
	[M.LeafyGrass] = Color3.fromRGB(62, 114, 50),
	[M.Mud] = Color3.fromRGB(70, 56, 46),
	[M.Ground] = Color3.fromRGB(96, 80, 62),
	[M.Rock] = Color3.fromRGB(104, 106, 100),
})
local colorsApplied = false
local function applyColors()
	if colorsApplied then return end
	colorsApplied = true
	for material, color in TowerTerrain.MaterialColors do
		workspace.Terrain:SetMaterialColor(material, color)
	end
end

export type Field = {
	Height: (x: number, z: number) -> number,
	Kind: (x: number, z: number) -> string, -- "CHASM", "POOL", "MOUNTAIN", "APRON", "BRIDGE", "WALK"
	Slope: (x: number, z: number) -> number,
	Sample: (x: number, z: number) -> (number, string),
	Bottom: number,
	LiquidLevel: number,
	Palette: Palette,
}

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
local function walkways(layout: any): ({ any }, { any })
	local rects, strips = {}, {}
	for _, p in layout.Platforms do
		table.insert(rects, { X = p.X, Z = p.Z, HX = p.Width / 2, HZ = p.Depth / 2, Y = p.Y })
	end
	local connectors = table.clone(layout.Links)
	for _, link in layout.ReturnLinks or {} do
		table.insert(connectors, link)
	end
	for _, link in connectors do
		table.insert(strips, { AX = link.AX, AY = link.AY, AZ = link.AZ, BX = link.BX, BY = link.BY, BZ = link.BZ, Half = link.Width / 2 })
		for _, name in { "LandingA", "LandingB" } do
			local pad = link[name]
			table.insert(strips, { AX = pad.AX, AY = pad.AY, AZ = pad.AZ, BX = pad.BX, BY = pad.BY, BZ = pad.BZ, Half = pad.Width / 2 })
		end
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
	local liquidLevel = bottom - 0.3
	local reach = 0
	for _, r in rects do
		reach = math.max(reach, (r.Y - bottom + 12) / APRON)
	end

	-- Ground before walkways: chasm, pools and mountains.
	local function natural(x: number, z: number): (number, string)
		local base = bottom + 1.6 * fbm(x / 70, z / 70, seed, 3) + 0.7 * fbm(x / 23, z / 23, seed + 3, 2)
		local kind = "CHASM"
		-- Mountains: a noisy band along every wall, terraced into ledges, rising past the ceiling.
		local edge = math.min(w / 2 - math.abs(x), d / 2 - math.abs(z))
		local band = 58 + 26 * fbm(x / 95, z / 95, seed + 7, 2)
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
		-- Pools in the open chasm.
		if kind == "CHASM" then
			local wet = fbm(x / 75 + 40, z / 75 - 40, seed + 21, 2)
			if wet > 0.28 then
				local depth = math.clamp((wet - 0.28) / 0.12, 0, 1)
				base = if palette.LiquidSolid then math.min(base, liquidLevel + 0.05) else base - (base - (bottom - 2.6)) * depth
				kind = "POOL"
			end
		end
		return base, kind
	end

	-- Walkways: aprons and embankments raise the ground toward them; caps keep it below them.
	local function shaped(x: number, z: number): (number, string)
		local y, kind = natural(x, z)
		local wild, wildKind = y, kind
		local raise, cap = -math.huge, math.huge
		local nearest = math.huge
		local surface = -math.huge -- the highest walkway within reach
		for _, r in rects do
			local dx = math.max(0, math.abs(x - r.X) - r.HX)
			local dz = math.max(0, math.abs(z - r.Z) - r.HZ)
			if dx < reach and dz < reach then
				local dist = math.sqrt(dx * dx + dz * dz)
				nearest = math.min(nearest, dist)
				local rim = r.Y - RIM
				surface = math.max(surface, r.Y)
				cap = math.min(cap, if dist == 0 then r.Y - UNDER else rim - APRON * dist)
				-- A steeper, noisy apron so plateaus have rugged, uneven skirts.
				local steep = APRON + 1.2 * (0.5 + 0.5 * fbm(x / 18, z / 18, seed + 31, 2))
				raise = math.max(raise, rim - steep * dist)
			end
		end
		for _, s in strips do
			local dx, dz = s.BX - s.AX, s.BZ - s.AZ
			local length2 = math.max(dx * dx + dz * dz, 1e-6)
			local t = math.clamp(((x - s.AX) * dx + (z - s.AZ) * dz) / length2, 0, 1)
			local px, pz = s.AX + dx * t - x, s.AZ + dz * t - z
			local lateral = math.sqrt(px * px + pz * pz)
			if lateral < s.Half + reach then
				local deck = s.AY + (s.BY - s.AY) * t - UNDER
				local beyond = math.max(0, lateral - s.Half)
				nearest = math.min(nearest, beyond)
				surface = math.max(surface, deck + UNDER)
				cap = math.min(cap, deck - APRON * beyond)
				raise = math.max(raise, deck - (APRON + 0.8) * beyond)
				if beyond == 0 then
					kind = "BRIDGE"
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
		if cap < y then
			y = cap
		end
		-- A mountain may still rise beside a walkway as a canyon wall: past a moat MOAT studs wide, and only
		-- where it stands well above every walkway in reach, so its face is a cliff, never a way up.
		if wildKind == "MOUNTAIN" and nearest >= MOAT and wild >= surface + 8 and wild > y then
			y, kind = wild, "MOUNTAIN"
		end
		-- The shelf behind the Apex rises to it (the Apex's own cap keeps a lip at its back edge).
		if z < apex.Z - apex.Depth / 2 - 6 and math.abs(x - apex.X) < w / 2 - 30 then
			y = math.max(y, math.min(apex.Y - RIM, cap))
		end
		if nearest == 0 then
			kind = "WALK"
		end
		return y, kind
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
	}
end

local function materialFor(field: Field, palette: Palette, kind: string, y: number, slopeValue: number, x: number, z: number, seed: number): Enum.Material
	if kind == "BRIDGE" or kind == "WALK" then
		return palette.Slope
	elseif kind == "POOL" then
		return if palette.LiquidSolid then palette.Liquid else palette.Shore
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
			mats[i][k] = materialFor(field, palette, kinds[i][k], y, math.sqrt(gx * gx + gz * gz), x, z, seed)
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
