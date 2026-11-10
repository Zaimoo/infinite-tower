--!strict
-- HubLayout.luau
-- Single source of truth for Central Hub world geometry (GDD §3.1, §3.2, §3.5).
-- The Cloister Commons is one solid rounded-rectangle garden north of the tower gate (no outer band or void).
-- Eight fortress plots bridge straight onto its edge: 3 on the west side, 2 on the north edge, 3 on the east side.
-- Hub-local frame: origin at HubCentre, +X east, -Z north (away from the tower).

local HubLayout = {}

HubLayout.IslandSurfaceY = 12 -- Hero ground height used by CombatSimulation & EntityRenderer
HubLayout.TowerWalkwayY = 16
HubLayout.TowerWalkwayRadius = 375
HubLayout.TowerClearRadius = 420 -- No plot geometry may come closer to the tower centre

-- Cloister Commons (its south edge stays at world Z -476, where the causeway lands)
HubLayout.HubHalfX = 240
HubLayout.HubHalfZ = 320
HubLayout.OuterCornerRadius = 60
HubLayout.HubCentre = Vector3.new(0, 12, -476 - HubLayout.HubHalfZ) -- (0, 12, -796)
HubLayout.ParkCentre = HubLayout.HubCentre -- Fast travel and background islets centre on the hub
HubLayout.HubArrival = Vector3.new(0, HubLayout.IslandSurfaceY + 3.8, HubLayout.HubCentre.Z + 61) -- South red-runner entrance to the Wayfinder Dais

-- Plots. A plot island is not centred on its IslandRoot: the front gate is PlotFrontDepth toward the hub
-- and the back edge PlotBackDepth behind it (IslandBuilder: courtyard + outskirts, measured with walls).
HubLayout.PlotCount = 8
HubLayout.PlotHalfWidth = 92
HubLayout.PlotFrontDepth = 168
HubLayout.PlotBackDepth = 66
HubLayout.PlotBridgeWidth = 18
HubLayout.PlotBridgeLength = 40
HubLayout.PlotSpacing = 208 -- Centre to centre along a side (184 wide + 24 gap)
HubLayout.PlotGateWidth = 20
-- Fill nearest-to-the-gate first so small servers cluster by the tower
HubLayout.AssignmentOrder = { 1, 8, 2, 7, 3, 6, 4, 5 }

-- Pilgrim's Causeway: tower walkway -> Cloister South Gate (deck width; bastions and statues stand outside it)
HubLayout.CausewayWidth = 40
HubLayout.CausewayTowerZ = -(375 + 11) -- Outer edge of the tower walkway
HubLayout.SouthGateWidth = 44
HubLayout.BoulevardWidth = 28 -- Pilgrim's Way from the South Gate to the dais

-- Raid Portal (docs/raid-boss-plan.md §6): on the Commons, east of the Reflecting Pool (its right
-- side seen from the dais), facing diagonally back toward the island centre. Hub-local.
HubLayout.RaidPortal = { X = 100, Z = -160, Scale = 1.0, ClearRadius = 30 }
function HubLayout.RaidPortalCFrame(): CFrame
	local p = HubLayout.RaidPortal
	local pos = HubLayout.HubPoint(p.X, p.Z)
	local centre = HubLayout.HubPoint(0, 0)
	return CFrame.lookAt(pos, centre) -- LookVector faces the island centre (south-west)
end
-- Where Masters land when they leave a raid: on the promenade in front of the portal.
function HubLayout.RaidPortalLanding(): Vector3
	local cf = HubLayout.RaidPortalCFrame()
	local ahead = cf.Position + cf.LookVector * 34
	return Vector3.new(ahead.X, HubLayout.IslandSurfaceY + 3.5, ahead.Z)
end
-- Safety catch plane & background horizon
HubLayout.KillZoneCentre = Vector3.new(0, -95, -950)
HubLayout.KillZoneSize = Vector3.new(2400, 8, 3400)
HubLayout.IsletRingMin = 1250
HubLayout.IsletRingMax = 1450


-- Hub-local (x, z) -> world point at height y (default island surface).
function HubLayout.HubPoint(x: number, z: number, y: number?): Vector3
	local c = HubLayout.HubCentre
	return Vector3.new(c.X + x, y or HubLayout.IslandSurfaceY, c.Z + z)
end

-- Each plot's hub-local IslandRoot and outward direction (unit x, z). Plot_1..3 west (south to north),
-- Plot_4..5 north (west to east), Plot_6..8 east (north to south).
local function buildPlotSlots(): { { X: number, Z: number, DX: number, DZ: number } }
	local slots = {}
	local reach = HubLayout.PlotBridgeLength + HubLayout.PlotFrontDepth
	local sideX = HubLayout.HubHalfX + reach
	local northZ = -(HubLayout.HubHalfZ + reach)
	local s = HubLayout.PlotSpacing
	for _, z in { s, 0, -s } do
		table.insert(slots, { X = -sideX, Z = z, DX = -1, DZ = 0 })
	end
	for _, x in { -s * 0.5, s * 0.5 } do
		table.insert(slots, { X = x, Z = northZ, DX = 0, DZ = -1 })
	end
	for _, z in { -s, 0, s } do
		table.insert(slots, { X = sideX, Z = z, DX = 1, DZ = 0 })
	end
	return slots
end
HubLayout.PlotSlots = buildPlotSlots()

function HubLayout.PlotCentre(index: number): Vector3
	local slot = HubLayout.PlotSlots[index]
	return HubLayout.HubPoint(slot.X, slot.Z)
end

-- IslandRoot CFrame for Plot_N: front (-Z local) faces back across its bridge into the hub.
function HubLayout.PlotIslandCFrame(index: number): CFrame
	local slot = HubLayout.PlotSlots[index]
	local centre = HubLayout.PlotCentre(index)
	return CFrame.lookAt(centre, centre - Vector3.new(slot.DX, 0, slot.DZ))
end

-- Point on the hub's outer edge where Plot_N's bridge lands.
function HubLayout.HubLandingPoint(index: number): Vector3
	local slot = HubLayout.PlotSlots[index]
	local back = HubLayout.PlotFrontDepth + HubLayout.PlotBridgeLength
	return HubLayout.HubPoint(slot.X - slot.DX * back, slot.Z - slot.DZ * back)
end

-- World Z of the hub's south edge, where the causeway lands.
function HubLayout.CausewayParkZ(): number
	return HubLayout.HubCentre.Z + HubLayout.HubHalfZ
end

-- The 4 XZ corners of Plot_N's island footprint, gate side first (for overlap and clearance checks).
function HubLayout.PlotCorners(index: number): { { number } }
	local slot = HubLayout.PlotSlots[index]
	local fx, fz = slot.DX, slot.DZ
	local px, pz = -fz, fx
	local centre = HubLayout.PlotCentre(index)
	local out = {}
	local front, back = HubLayout.PlotFrontDepth, HubLayout.PlotBackDepth
	for _, c in { { -1, -front }, { 1, -front }, { 1, back }, { -1, back } } do
		local w, d = c[1] * HubLayout.PlotHalfWidth, c[2]
		table.insert(out, { centre.X + px * w + fx * d, centre.Z + pz * w + fz * d })
	end
	return out
end

-- Hub-local points around a rounded rectangle (corner arcs sampled), grown outward by `pad`.
function HubLayout.RoundedRectPoints(hx: number, hz: number, r: number, pad: number, perArc: number): { { number } }
	local out = {}
	local cx, cz = hx - r, hz - r
	for _, q in { { 1, 1 }, { -1, 1 }, { -1, -1 }, { 1, -1 } } do
		local a0 = math.atan2(q[2], q[1]) - math.pi * 0.25
		for i = 0, perArc do
			local a = a0 + (i / perArc) * math.pi * 0.5
			table.insert(out, { q[1] * cx + math.cos(a) * (r + pad), q[2] * cz + math.sin(a) * (r + pad) })
		end
	end
	return out
end

-- Safe, bankable hub zones as world XZ polygons: the Commons itself, each plot bridge and the causeway.
-- Plot interiors get their own zones from PlotSpawn in TowerFloorService.
function HubLayout.BankZonePolygons(): { { Id: string, Points: { { number } } } }
	local c = HubLayout.HubCentre
	local zones = {}
	local commons = {}
	for _, p in HubLayout.RoundedRectPoints(HubLayout.HubHalfX, HubLayout.HubHalfZ, HubLayout.OuterCornerRadius, 2, 4) do
		table.insert(commons, { c.X + p[1], c.Z + p[2] })
	end
	table.insert(zones, { Id = "HUB_COMMONS", Points = commons })
	local half = HubLayout.PlotBridgeWidth * 0.5 + 2
	for i, slot in HubLayout.PlotSlots do
		local fx, fz = slot.DX, slot.DZ
		local px, pz = -fz, fx
		local land = HubLayout.HubLandingPoint(i)
		local r0, r1 = -4, HubLayout.PlotBridgeLength + 6 -- from just inside the hub edge to past the plot gate
		table.insert(zones, {
			Id = "HUB_BRIDGE_" .. i,
			Points = {
				{ land.X + fx * r0 - px * half, land.Z + fz * r0 - pz * half },
				{ land.X + fx * r1 - px * half, land.Z + fz * r1 - pz * half },
				{ land.X + fx * r1 + px * half, land.Z + fz * r1 + pz * half },
				{ land.X + fx * r0 + px * half, land.Z + fz * r0 + pz * half },
			},
		})
	end
	local w = HubLayout.CausewayWidth * 0.5 + 2
	local z0, z1 = HubLayout.CausewayParkZ() - 4, HubLayout.CausewayTowerZ + 2
	table.insert(zones, { Id = "HUB_CAUSEWAY", Points = { { -w, z0 }, { w, z0 }, { w, z1 }, { -w, z1 } } })
	return zones
end

return HubLayout
