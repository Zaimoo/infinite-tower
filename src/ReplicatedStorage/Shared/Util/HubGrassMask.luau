--!strict
-- ReplicatedStorage/Shared/Util/HubGrassMask.luau
-- Pure math bounds, Hub path/landmark exclusions, and deterministic grid sampling for
-- client-only proximity 3D grass on the Cloister Commons (MastersCommons).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("HubLayout"))

local HubGrassMask = {}

HubGrassMask.Config = table.freeze({
	CellSize = 3.6,
	ActiveRadius = 52,
	FadeStartRadius = 34,
	MaxPoolSize = 280,
	EdgeMargin = 5,
	DaisClearRadius = 58.0,
	SurfaceOffsetY = 0.025,
	DensityThreshold = 0.44,
})

export type PathSegment = {
	ax: number,
	az: number,
	bx: number,
	bz: number,
	clearRadius: number,
}

export type CircleExclusion = {
	x: number,
	z: number,
	r: number,
}

export type RectExclusion = {
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
}

-- Precompute Hub-local path segments matching CloisterBuilder.gardenPaths()
local function buildPathSegments(): { PathSegment }
	local list: { PathSegment } = {}
	local c = HubLayout.HubCentre
	local daisEdge = 56
	local pathHalf = 8 + 2.4 -- PathWidth * 0.5 + shoulder margin

	for i = 1, HubLayout.PlotCount do
		local land = HubLayout.HubLandingPoint(i)
		local lx, lz = land.X - c.X, land.Z - c.Z
		local len = math.sqrt(lx * lx + lz * lz)
		table.insert(list, {
			ax = lx,
			az = lz,
			bx = lx / len * daisEdge,
			bz = lz / len * daisEdge,
			clearRadius = pathHalf,
		})
	end
	-- Leaderboard Pavilion cobblestone spur
	table.insert(list, {
		ax = 6,
		az = 116,
		bx = 86,
		bz = 156,
		clearRadius = pathHalf,
	})
	-- Pilgrim's Way Boulevard
	table.insert(list, {
		ax = 0,
		az = HubLayout.HubHalfZ,
		bx = 0,
		bz = daisEdge,
		clearRadius = HubLayout.BoulevardWidth * 0.5 + 2.8,
	})
	return list
end

local function buildCircleExclusions(): { CircleExclusion }
	local list: { CircleExclusion } = {
		{ x = 0, z = 0, r = HubGrassMask.Config.DaisClearRadius },
		{ x = -90, z = 165, r = 23 }, -- Gazebo
		{ x = 150, z = 275, r = 24 }, -- BiomeStones
		{ x = 117.5, z = -173, r = 21 }, -- WaterfallBoulderPond
		{ x = -52.1, z = 233.1, r = 20 }, -- RockeryKoiPond
		{ x = 157, z = 43.4, r = 18 }, -- SteppingStreamPond
		{ x = HubLayout.RaidPortal.X, z = HubLayout.RaidPortal.Z, r = 20 },
		{ x = HubLayout.ReforgeStation.X, z = HubLayout.ReforgeStation.Z, r = 19 },
	}
	local c = HubLayout.HubCentre
	for i = 1, HubLayout.PlotCount do
		local slot = HubLayout.PlotSlots[i]
		local land = HubLayout.HubLandingPoint(i)
		table.insert(list, {
			x = land.X - c.X - slot.DX * 8,
			z = land.Z - c.Z - slot.DZ * 8,
			r = 19,
		})
	end
	return list
end

local PATH_SEGMENTS = buildPathSegments()
local CIRCLE_EXCLUSIONS = buildCircleExclusions()
local RECT_EXCLUSIONS: { RectExclusion } = {
	{ minX = -43, maxX = 43, minZ = -216, maxZ = -114 }, -- ReflectingPool (HeroBridgePond + willows)
	{ minX = -198, maxX = -102, minZ = 260, maxZ = 302 }, -- OverlookTerrace
	{ minX = -30, maxX = 30, minZ = 295, maxZ = 325 }, -- SouthGate & braziers
}

-- LeaderboardPavilion oriented footprint: centered at (86, 156) facing (0, 61)
local PAV_X, PAV_Z = 86, 156
local PAV_COS, PAV_SIN = (function(): (number, number)
	local dx, dz = -PAV_X, 61 - PAV_Z
	local len = math.sqrt(dx * dx + dz * dz)
	-- Local -Z looks along (dx, dz)/len
	local fx, fz = dx / len, dz / len
	local rx, rz = -fz, fx
	return rx, rz
end)()

local function segmentDistSq(px: number, pz: number, seg: PathSegment): number
	local dx = seg.bx - seg.ax
	local dz = seg.bz - seg.az
	local denom = dx * dx + dz * dz
	if denom <= 1e-6 then
		return (px - seg.ax) ^ 2 + (pz - seg.az) ^ 2
	end
	local t = math.clamp(((px - seg.ax) * dx + (pz - seg.az) * dz) / denom, 0, 1)
	local qx = seg.ax + t * dx - px
	local qz = seg.az + t * dz - pz
	return qx * qx + qz * qz
end

-- True when Hub-local (lx, lz) lies inside the rounded-rectangle Cloister Commons inset by `margin`.
function HubGrassMask.InsideHubBounds(lx: number, lz: number, margin: number?): boolean
	local m = margin or HubGrassMask.Config.EdgeMargin
	local hx = HubLayout.HubHalfX - m
	local hz = HubLayout.HubHalfZ - m
	if math.abs(lx) > hx or math.abs(lz) > hz then
		return false
	end
	local r = math.max(0, HubLayout.OuterCornerRadius - m)
	local cx = HubLayout.HubHalfX - HubLayout.OuterCornerRadius
	local cz = HubLayout.HubHalfZ - HubLayout.OuterCornerRadius
	local ax = math.abs(lx) - cx
	local az = math.abs(lz) - cz
	if ax > 0 and az > 0 then
		return (ax * ax + az * az) <= (r * r)
	end
	return true
end

-- True when Hub-local (lx, lz) overlaps any cobblestone path, plaza, pond, or Hub landmark.
function HubGrassMask.IsOnPathOrLandmark(lx: number, lz: number): boolean
	for _, c in CIRCLE_EXCLUSIONS do
		local dx = lx - c.x
		local dz = lz - c.z
		if (dx * dx + dz * dz) <= (c.r * c.r) then
			return true
		end
	end

	for _, rect in RECT_EXCLUSIONS do
		if lx >= rect.minX and lx <= rect.maxX and lz >= rect.minZ and lz <= rect.maxZ then
			return true
		end
	end

	-- Leaderboard Pavilion oriented apron
	local pdx, pdz = lx - PAV_X, lz - PAV_Z
	local localRight = pdx * PAV_COS + pdz * PAV_SIN
	local localBack = pdx * (-PAV_SIN) + pdz * PAV_COS
	if math.abs(localRight) <= 42 and math.abs(localBack) <= 18 then
		return true
	end

	for _, seg in PATH_SEGMENTS do
		if segmentDistSq(lx, lz, seg) <= (seg.clearRadius * seg.clearRadius) then
			return true
		end
	end

	return false
end

local function hash2D(cx: number, cz: number, salt: number): number
	local n = bit32.bxor(cx * 374761393, cz * 668265263, salt * 2147483647)
	n = bit32.bxor(n, bit32.rshift(n, 13))
	n = (n * 1274126177) % 2147483647
	return math.abs(n) / 2147483647
end

-- Smooth radial fade-out factor in [0, 1] from FadeStartRadius (1) to ActiveRadius (0).
function HubGrassMask.FadeFactor(distance: number): number
	local startR = HubGrassMask.Config.FadeStartRadius
	local maxR = HubGrassMask.Config.ActiveRadius
	if distance <= startR then
		return 1
	elseif distance >= maxR then
		return 0
	end
	local t = (distance - startR) / (maxR - startR)
	return 1 - (t * t * (3 - 2 * t))
end

-- Evaluates deterministic grid cell (cellX, cellZ) in Hub-local coordinates.
-- Returns (shouldSpawn, hubLocalX, hubLocalZ, densityWeight, yawRadians).
function HubGrassMask.SampleCell(cellX: number, cellZ: number): (boolean, number, number, number, number)
	local cellSize = HubGrassMask.Config.CellSize
	local jx = (hash2D(cellX, cellZ, 17) - 0.5) * cellSize * 0.78
	local jz = (hash2D(cellX, cellZ, 53) - 0.5) * cellSize * 0.78
	local lx = cellX * cellSize + jx
	local lz = cellZ * cellSize + jz

	if not HubGrassMask.InsideHubBounds(lx, lz) or HubGrassMask.IsOnPathOrLandmark(lx, lz) then
		return false, 0, 0, 0, 0
	end

	-- Macro FBM-like patchiness creates lush grassy clusters separated by open textured ground clearings
	local patch = 0.5
		+ 0.36 * math.noise(lx * 0.040, lz * 0.040, 713)
		+ 0.14 * math.noise(lx * 0.11, lz * 0.11, 919)
	local roll = hash2D(cellX, cellZ, 89)
	if patch < HubGrassMask.Config.DensityThreshold and roll > 0.12 then
		return false, 0, 0, 0, 0
	end

	local yaw = hash2D(cellX, cellZ, 137) * math.pi * 2
	return true, lx, lz, patch, yaw
end

return HubGrassMask
