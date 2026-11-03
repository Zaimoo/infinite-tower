--!strict
-- HubLayout.luau
-- Single source of truth for Central Hub world geometry (GDD §3.1, §3.2, §3.5).
-- The Masters' Commons park sits north of the tower gate; the 6 fortress plots form a
-- horseshoe around it with the open side facing the tower. Bearings are measured from
-- the park centre in degrees: 0 = north (-Z, away from the tower), positive = east (+X).

local HubLayout = {}

HubLayout.IslandSurfaceY = 12 -- Hero ground height used by CombatSimulation & EntityRenderer
HubLayout.TowerWalkwayY = 16
HubLayout.TowerWalkwayRadius = 375
HubLayout.TowerClearRadius = 420 -- No plot geometry may come closer to the tower centre

-- The Masters' Commons
HubLayout.ParkCentre = Vector3.new(0, 12, -650)
HubLayout.ParkRadius = 170

-- Plot horseshoe (Plot_1 .. Plot_6, west to east through north)
HubLayout.PlotBearingsDeg = { -120, -72, -24, 24, 72, 120 }
HubLayout.PlotCentreRadius = 478 -- Island bounding-box centre (IslandRoot) distance from the park centre
HubLayout.PlotHalfWidth = 130
HubLayout.PlotHalfDepth = 168
HubLayout.PlotBridgeWidth = 18

-- Pilgrim's Causeway: tower walkway -> Commons South Gate (deck width; bastions and statues stand outside it)
HubLayout.CausewayWidth = 40
HubLayout.CausewayTowerZ = -(375 + 11) -- Outer edge of the tower walkway
HubLayout.SouthGateBearingDeg = 180
HubLayout.SouthGateWidth = 44
HubLayout.BoulevardWidth = 28 -- Pilgrim's Way inside the park
HubLayout.PlotGateWidth = 20

-- Safety catch plane & background horizon
HubLayout.KillZoneCentre = Vector3.new(0, -95, -500)
HubLayout.KillZoneSize = Vector3.new(3400, 8, 3400)
HubLayout.IsletRingMin = 1450
HubLayout.IsletRingMax = 1650

-- Unit direction (x, z) for a bearing in degrees.
function HubLayout.BearingDir(deg: number): (number, number)
	local r = math.rad(deg)
	return math.sin(r), -math.cos(r)
end

-- World point at `radius` studs from the park centre along `deg`, at height y (default island surface).
function HubLayout.BearingPoint(deg: number, radius: number, y: number?): Vector3
	local dx, dz = HubLayout.BearingDir(deg)
	local c = HubLayout.ParkCentre
	return Vector3.new(c.X + dx * radius, y or HubLayout.IslandSurfaceY, c.Z + dz * radius)
end

function HubLayout.PlotCentre(index: number): Vector3
	return HubLayout.BearingPoint(HubLayout.PlotBearingsDeg[index], HubLayout.PlotCentreRadius)
end

-- IslandRoot CFrame for Plot_N: centred on its bearing, front (-Z local) facing the park centre.
function HubLayout.PlotIslandCFrame(index: number): CFrame
	local c = HubLayout.ParkCentre
	return CFrame.lookAt(HubLayout.PlotCentre(index), Vector3.new(c.X, HubLayout.IslandSurfaceY, c.Z))
end

-- Point on the park rim where Plot_N's bridge lands.
function HubLayout.ParkGatePoint(index: number): Vector3
	return HubLayout.BearingPoint(HubLayout.PlotBearingsDeg[index], HubLayout.ParkRadius)
end

function HubLayout.CausewayParkZ(): number
	return HubLayout.ParkCentre.Z + HubLayout.ParkRadius
end

-- Safe, bankable hub zones as world XZ polygons: the Commons (24-gon), each plot bridge, and the causeway.
-- Plot interiors get their own zones from PlotSpawn in TowerFloorService.
HubLayout.BridgeZoneOuterRadius = 345 -- Reaches past each plot's front gate (about 328 from the park centre)

function HubLayout.BankZonePolygons(): { { Id: string, Points: { { number } } } }
	local c = HubLayout.ParkCentre
	local zones = {}
	local park = {}
	for i = 0, 23 do
		local a = i * math.pi / 12
		local r = HubLayout.ParkRadius + 2
		table.insert(park, { c.X + math.cos(a) * r, c.Z + math.sin(a) * r })
	end
	table.insert(zones, { Id = "HUB_COMMONS", Points = park })
	local half = HubLayout.PlotBridgeWidth * 0.5 + 2
	for i, deg in HubLayout.PlotBearingsDeg do
		local fx, fz = HubLayout.BearingDir(deg)
		local px, pz = -fz, fx
		local r0, r1 = HubLayout.ParkRadius - 4, HubLayout.BridgeZoneOuterRadius
		table.insert(zones, {
			Id = "HUB_BRIDGE_" .. i,
			Points = {
				{ c.X + fx * r0 - px * half, c.Z + fz * r0 - pz * half },
				{ c.X + fx * r1 - px * half, c.Z + fz * r1 - pz * half },
				{ c.X + fx * r1 + px * half, c.Z + fz * r1 + pz * half },
				{ c.X + fx * r0 + px * half, c.Z + fz * r0 + pz * half },
			},
		})
	end
	local w = HubLayout.CausewayWidth * 0.5 + 2
	local z0, z1 = HubLayout.CausewayParkZ() - 4, HubLayout.CausewayTowerZ + 2
	table.insert(zones, { Id = "HUB_CAUSEWAY", Points = { { -w, z0 }, { w, z0 }, { w, z1 }, { -w, z1 } } })
	return zones
end

-- The 4 XZ corners of Plot_N's island footprint (for overlap and clearance checks).
function HubLayout.PlotCorners(index: number): { { number } }
	local deg = HubLayout.PlotBearingsDeg[index]
	local fx, fz = HubLayout.BearingDir(deg) -- outward from the park
	local px, pz = -fz, fx -- perpendicular
	local centre = HubLayout.PlotCentre(index)
	local out = {}
	for _, s in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		local w, d = s[1] * HubLayout.PlotHalfWidth, s[2] * HubLayout.PlotHalfDepth
		table.insert(out, { centre.X + px * w + fx * d, centre.Z + pz * w + fz * d })
	end
	return out
end

return HubLayout
