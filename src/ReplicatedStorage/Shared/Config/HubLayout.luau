--!strict
-- HubLayout.luau
-- Single source of truth for Central Hub world geometry (GDD §3.1, §3.2, §3.5).
-- The Cloister Commons is a hollow rounded rectangle north of the tower gate: a 120-stud walkable band
-- around an open void, with a garden island in the middle joined by four footbridges. Ten fortress
-- plots line its outside (3 per long side, 2 on the north edge, 2 on the north corners).
-- Hub-local frame: origin at HubCentre, +X east, -Z north (away from the tower).

local HubLayout = {}

HubLayout.IslandSurfaceY = 12 -- Hero ground height used by CombatSimulation & EntityRenderer
HubLayout.TowerWalkwayY = 16
HubLayout.TowerWalkwayRadius = 375
HubLayout.TowerClearRadius = 420 -- No plot geometry may come closer to the tower centre

-- Cloister Commons
HubLayout.HubCentre = Vector3.new(0, 12, -1036)
HubLayout.ParkCentre = HubLayout.HubCentre -- Fast travel and background islets centre on the hub
HubLayout.HubArrival = Vector3.new(0, HubLayout.IslandSurfaceY + 3.8, -975) -- South red-runner entrance to the Wayfinder Dais
HubLayout.HubHalfX = 420
HubLayout.HubHalfZ = 560
HubLayout.OuterCornerRadius = 160
HubLayout.BandWidth = 120
HubLayout.VoidHalfX = HubLayout.HubHalfX - HubLayout.BandWidth -- 300
HubLayout.VoidHalfZ = HubLayout.HubHalfZ - HubLayout.BandWidth -- 440
HubLayout.VoidCornerRadius = HubLayout.OuterCornerRadius - HubLayout.BandWidth -- 40, concentric with the outer corners
HubLayout.IslandHalfX = 170
HubLayout.IslandHalfZ = 250
HubLayout.IslandCornerRadius = 30
HubLayout.FootbridgeWidth = 20

-- Plots
HubLayout.PlotCount = 10
HubLayout.PlotHalfWidth = 130
HubLayout.PlotHalfDepth = 168
HubLayout.PlotBridgeWidth = 18
HubLayout.PlotBridgeLength = 40
HubLayout.PlotSpacing = 284 -- Centre to centre along a straight side (260 wide + 24 gap)
HubLayout.PlotGateWidth = 20
-- Fill nearest-to-the-gate first so small servers cluster by the tower
HubLayout.AssignmentOrder = { 1, 10, 2, 9, 3, 8, 4, 7, 5, 6 }

-- Pilgrim's Causeway: tower walkway -> Cloister South Gate (deck width; bastions and statues stand outside it)
HubLayout.CausewayWidth = 40
HubLayout.CausewayTowerZ = -(375 + 11) -- Outer edge of the tower walkway
HubLayout.SouthGateWidth = 44
HubLayout.BoulevardWidth = 28 -- Pilgrim's Way across the south band

-- Raid Portal (docs/raid-boss-plan.md §6): on the north band's outer half, at the end of the north
-- footbridge's axis, facing south (+Z) across the void toward the dais. Hub-local.
HubLayout.RaidPortal = { X = 0, Z = -536, Scale = 1.0, ClearRadius = 30 }
function HubLayout.RaidPortalCFrame(): CFrame
	local p = HubLayout.RaidPortal
	local pos = HubLayout.HubPoint(p.X, p.Z)
	return CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1)) -- LookVector faces south
end
-- Where Masters land when they leave a raid: on the promenade in front of the portal.
function HubLayout.RaidPortalLanding(): Vector3
	local p = HubLayout.RaidPortal
	return HubLayout.HubPoint(p.X, p.Z + 34, HubLayout.IslandSurfaceY + 3.5)
end
-- Safety catch plane & background horizon
HubLayout.KillZoneCentre = Vector3.new(0, -95, -950)
HubLayout.KillZoneSize = Vector3.new(2400, 8, 3400)
HubLayout.IsletRingMin = 1250
HubLayout.IsletRingMax = 1450

local SQRT_HALF = math.sqrt(0.5)

-- Hub-local (x, z) -> world point at height y (default island surface).
function HubLayout.HubPoint(x: number, z: number, y: number?): Vector3
	local c = HubLayout.HubCentre
	return Vector3.new(c.X + x, y or HubLayout.IslandSurfaceY, c.Z + z)
end

-- Each plot's hub-local centre and outward direction (unit x, z). Plot_1..3 west (south to north),
-- Plot_4 north-west corner, Plot_5..6 north, Plot_7 north-east corner, Plot_8..10 east (north to south).
local function buildPlotSlots(): { { X: number, Z: number, DX: number, DZ: number } }
	local slots = {}
	local reach = HubLayout.PlotBridgeLength + HubLayout.PlotHalfDepth
	local sideX = HubLayout.HubHalfX + reach
	local northZ = -(HubLayout.HubHalfZ + reach)
	local s = HubLayout.PlotSpacing
	local cornerR = HubLayout.OuterCornerRadius + reach
	local cx, cz = HubLayout.HubHalfX - HubLayout.OuterCornerRadius, HubLayout.HubHalfZ - HubLayout.OuterCornerRadius
	for _, z in { s, 0, -s } do
		table.insert(slots, { X = -sideX, Z = z, DX = -1, DZ = 0 })
	end
	table.insert(slots, { X = -cx - SQRT_HALF * cornerR, Z = -cz - SQRT_HALF * cornerR, DX = -SQRT_HALF, DZ = -SQRT_HALF })
	for _, x in { -s * 0.5, s * 0.5 } do
		table.insert(slots, { X = x, Z = northZ, DX = 0, DZ = -1 })
	end
	table.insert(slots, { X = cx + SQRT_HALF * cornerR, Z = -cz - SQRT_HALF * cornerR, DX = SQRT_HALF, DZ = -SQRT_HALF })
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
	local back = HubLayout.PlotHalfDepth + HubLayout.PlotBridgeLength
	return HubLayout.HubPoint(slot.X - slot.DX * back, slot.Z - slot.DZ * back)
end

-- World Z of the hub's south edge, where the causeway lands.
function HubLayout.CausewayParkZ(): number
	return HubLayout.HubCentre.Z + HubLayout.HubHalfZ
end

-- The 4 XZ corners of Plot_N's island footprint (for overlap and clearance checks).
function HubLayout.PlotCorners(index: number): { { number } }
	local slot = HubLayout.PlotSlots[index]
	local fx, fz = slot.DX, slot.DZ
	local px, pz = -fz, fx
	local centre = HubLayout.PlotCentre(index)
	local out = {}
	for _, sgn in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		local w, d = sgn[1] * HubLayout.PlotHalfWidth, sgn[2] * HubLayout.PlotHalfDepth
		table.insert(out, { centre.X + px * w + fx * d, centre.Z + pz * w + fz * d })
	end
	return out
end

-- Safe, bankable hub zones as world XZ polygons: the four band strips, the island, the four footbridges,
-- each plot bridge and the causeway. The void is deliberately not covered. Plot interiors get their own
-- zones from PlotSpawn in TowerFloorService.
function HubLayout.BankZonePolygons(): { { Id: string, Points: { { number } } } }
	local c = HubLayout.HubCentre
	local zones = {}
	local function box(id: string, x0: number, z0: number, x1: number, z1: number)
		table.insert(zones, { Id = id, Points = { { c.X + x0, c.Z + z0 }, { c.X + x1, c.Z + z0 }, { c.X + x1, c.Z + z1 }, { c.X + x0, c.Z + z1 } } })
	end
	local hx, hz, vx, vz = HubLayout.HubHalfX + 2, HubLayout.HubHalfZ + 2, HubLayout.VoidHalfX, HubLayout.VoidHalfZ
	box("HUB_BAND_SOUTH", -hx, vz, hx, hz)
	box("HUB_BAND_NORTH", -hx, -hz, hx, -vz)
	box("HUB_BAND_WEST", -hx, -vz, -vx, vz)
	box("HUB_BAND_EAST", vx, -vz, hx, vz)
	local ix, iz, fw = HubLayout.IslandHalfX + 2, HubLayout.IslandHalfZ + 2, HubLayout.FootbridgeWidth * 0.5 + 2
	box("HUB_ISLAND", -ix, -iz, ix, iz)
	box("HUB_FOOTBRIDGE_W", -vx - 2, -fw, -ix, fw)
	box("HUB_FOOTBRIDGE_E", ix, -fw, vx + 2, fw)
	box("HUB_FOOTBRIDGE_N", -fw, -vz - 2, fw, -iz)
	box("HUB_FOOTBRIDGE_S", -fw, iz, fw, vz + 2)
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
