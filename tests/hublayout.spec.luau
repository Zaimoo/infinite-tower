-- Hub geometry gate: plots never overlap each other, the tower, or fall outside the catch plane.
local Hub = require(nodes["ReplicatedStorage.Shared.Config.HubLayout"])
local passed, failed = 0, 0
local function test(name, callback)
	local ok, err = pcall(callback)
	if ok then passed += 1; print("PASS " .. name)
	else failed += 1; print("FAIL " .. name .. ": " .. tostring(err)) end
end

local function segDist(px, pz, ax, az, bx, bz)
	local dx, dz = bx - ax, bz - az
	local t = math.clamp(((px - ax) * dx + (pz - az) * dz) / (dx * dx + dz * dz), 0, 1)
	return math.sqrt((ax + t * dx - px) ^ 2 + (az + t * dz - pz) ^ 2)
end
local function polyDistToPoint(poly, px, pz)
	local best = math.huge
	for i = 1, #poly do
		local a, b = poly[i], poly[i % #poly + 1]
		best = math.min(best, segDist(px, pz, a[1], a[2], b[1], b[2]))
	end
	return best
end
-- Separating axis test for two convex quads.
local function overlaps(a, b)
	for _, poly in { a, b } do
		for i = 1, #poly do
			local p, q = poly[i], poly[i % #poly + 1]
			local nx, nz = -(q[2] - p[2]), q[1] - p[1]
			local function project(shape)
				local lo, hi = math.huge, -math.huge
				for _, v in shape do
					local d = v[1] * nx + v[2] * nz
					lo, hi = math.min(lo, d), math.max(hi, d)
				end
				return lo, hi
			end
			local aLo, aHi = project(a)
			local bLo, bHi = project(b)
			if aHi <= bLo or bHi <= aLo then return false end
		end
	end
	return true
end


local N = Hub.PlotCount

test("Eight plots around the Commons, with distinct slots and a full assignment order", function()
	assert(N == 8 and #Hub.PlotSlots == 8, "expected 8 plot slots")
	local seen = {}
	for _, i in Hub.AssignmentOrder do
		assert(i >= 1 and i <= N and not seen[i], "assignment order must list each plot once")
		seen[i] = true
	end
	assert(#Hub.AssignmentOrder == N)
end)

test("No two plot islands overlap, and neighbours keep at least 20 studs apart", function()
	for i = 1, N do
		for j = i + 1, N do
			local a, b = Hub.PlotCorners(i), Hub.PlotCorners(j)
			assert(not overlaps(a, b), string.format("Plot_%d overlaps Plot_%d", i, j))
			local gap = math.huge
			for _, v in a do gap = math.min(gap, polyDistToPoint(b, v[1], v[2])) end
			for _, v in b do gap = math.min(gap, polyDistToPoint(a, v[1], v[2])) end
			assert(gap >= 20, string.format("Plot_%d and Plot_%d are only %.0f studs apart", i, j, gap))
		end
	end
end)

test("Every plot island clears the tower and its walkway", function()
	for i = 1, N do
		local d = polyDistToPoint(Hub.PlotCorners(i), 0, 0)
		assert(d >= Hub.TowerClearRadius, string.format("Plot_%d is %.0f studs from the tower", i, d))
	end
end)

test("Every plot bridge is short and lands on the hub's outer edge", function()
	for i = 1, N do
		local slot = Hub.PlotSlots[i]
		local land = Hub.HubLandingPoint(i)
		local c = Hub.PlotCentre(i)
		local gate = Vector3.new(c.X - slot.DX * Hub.PlotFrontDepth, 12, c.Z - slot.DZ * Hub.PlotFrontDepth)
		local len = math.sqrt((gate.X - land.X) ^ 2 + (gate.Z - land.Z) ^ 2)
		assert(len >= 30 and len <= 60, string.format("Plot_%d bridge is %.0f studs", i, len))
		local lx, lz = math.abs(land.X - Hub.HubCentre.X), math.abs(land.Z - Hub.HubCentre.Z)
		local cx, cz = Hub.HubHalfX - Hub.OuterCornerRadius, Hub.HubHalfZ - Hub.OuterCornerRadius
		local onEdge = if lx > cx and lz > cz
			then math.abs(math.sqrt((lx - cx) ^ 2 + (lz - cz) ^ 2) - Hub.OuterCornerRadius) < 1
			else math.abs(lx - Hub.HubHalfX) < 1 or math.abs(lz - Hub.HubHalfZ) < 1
		assert(onEdge, "Plot_" .. i .. " bridge does not land on the hub edge")
	end
end)

test("Commons clears the tower walkway and leaves a causeway", function()
	local southEdge = Hub.CausewayParkZ()
	assert(southEdge < Hub.CausewayTowerZ, "hub overlaps the tower walkway")
	assert(Hub.CausewayTowerZ - southEdge >= 60, "causeway too short to slope gently")
end)

test("Every plot gate lands on a straight edge, clear of the corners and the South Gate", function()
	for i = 1, N do
		local land = Hub.HubLandingPoint(i)
		local lx, lz = math.abs(land.X - Hub.HubCentre.X), math.abs(land.Z - Hub.HubCentre.Z)
		local along = if math.abs(lx - Hub.HubHalfX) < 1 then lz else lx
		local straight = (if math.abs(lx - Hub.HubHalfX) < 1 then Hub.HubHalfZ else Hub.HubHalfX) - Hub.OuterCornerRadius
		assert(along + Hub.PlotGateWidth * 0.5 + 4 <= straight, "Plot_" .. i .. " gate runs into a corner")
		assert(land.Z < Hub.CausewayParkZ() - 1, "Plot_" .. i .. " lands on the south (gate) edge")
	end
end)

test("Every island corner lies on the catch plane and in hub bounds", function()
	local kc, ks = Hub.KillZoneCentre, Hub.KillZoneSize
	for i = 1, N do
		for _, v in Hub.PlotCorners(i) do
			assert(math.abs(v[1] - kc.X) < ks.X / 2 - 50 and math.abs(v[2] - kc.Z) < ks.Z / 2 - 50, "corner off the catch plane")
			assert(math.abs(v[1]) < 1600 and v[2] > -2100 and v[2] < 1600, "corner outside rooms[0].Bounds")
		end
	end
end)

test("Hub bank zones cover the Commons, plot bridges and causeway, but not the air around them", function()
	local Protocol = require(nodes["ReplicatedStorage.Shared.Util.TowerProtocol"])
	local zones = {}
	for _, z in Hub.BankZonePolygons() do
		local points = {}
		for _, p in z.Points do table.insert(points, Vector2.new(p[1], p[2])) end
		zones[z.Id] = { LocalPolygonXZ = points, MinY = -10, MaxY = 100 }
	end
	local origin = Vector3.new(0, 0, 0)
	local function inAny(pos)
		for _, z in zones do if Protocol.InZone(pos, origin, z) then return true end end
		return false
	end
	local hx, hz, r = Hub.HubHalfX, Hub.HubHalfZ, Hub.OuterCornerRadius
	assert(inAny(Hub.HubPoint(0, 0)), "Commons centre not covered")
	assert(inAny(Hub.HubPoint(-hx + 3, 0)) and inAny(Hub.HubPoint(hx - 3, 0)), "Commons side edges not covered")
	assert(inAny(Hub.HubPoint(0, hz - 3)) and inAny(Hub.HubPoint(0, -hz + 3)), "Commons north/south edges not covered")
	local d = (r - 3) * math.sqrt(0.5)
	assert(inAny(Hub.HubPoint(hx - r + d, hz - r + d)), "Commons corner not covered")
	for i = 1, N do
		local slot = Hub.PlotSlots[i]
		local land = Hub.HubLandingPoint(i)
		local h = Hub.PlotBridgeLength / 2
		local mid = Vector3.new(land.X + slot.DX * h, 12, land.Z + slot.DZ * h)
		assert(Protocol.InZone(mid, origin, zones["HUB_BRIDGE_" .. i]), "bridge " .. i .. " not covered")
	end
	assert(Protocol.InZone(Vector3.new(0, 14, (Hub.CausewayTowerZ + Hub.CausewayParkZ()) / 2), origin, zones.HUB_CAUSEWAY), "causeway not covered")
	assert(not inAny(Hub.HubPoint(hx - 3, hz - 3)), "the air outside a rounded corner must not be a bank zone")
	assert(not inAny(Hub.HubPoint(hx + 20, 100)), "the air beside the Commons must not be a bank zone")
	assert(not inAny(Vector3.new(0, 16, -300)), "tower arrival must not be a bank zone")
	assert(inAny(Hub.HubArrival), "HubArrival must be inside a bankable hub zone")
end)

test("HubArrival is placed on the red runner at the south entrance of the dais", function()
	assert(Hub.HubArrival ~= nil, "HubArrival must be defined")
	assert(math.abs(Hub.HubArrival.X) < 0.1, "HubArrival must be aligned on X = 0")
	assert(Hub.HubArrival.Z > Hub.HubCentre.Z, "HubArrival must be south of the Dais center (+Z)")
	local distFromPlazaCenter = math.abs(Hub.HubArrival.Z - Hub.HubCentre.Z)
	assert(distFromPlazaCenter >= 56 and distFromPlazaCenter <= 65, "HubArrival must be right at the south entrance to the Dais")
end)

test("Lighting: plots and the Commons are Sanctuary, the walkway is Dread, the causeway blends, floors are Storm", function()
	local Light = require(nodes["ReplicatedStorage.Shared.Config.HubLighting"])
	local keys = {}
	for key in Light.Presets.Sanctuary do keys[key] = true end
	for name, preset in Light.Presets do
		for key in keys do assert(preset[key] ~= nil, name .. " is missing " .. key) end
		for key in preset do assert(keys[key], name .. " has extra field " .. key) end
	end
	for i = 1, N do
		local c = Hub.PlotCentre(i)
		local zone, dread = Light.Classify(c.X, c.Z)
		assert(zone == "Hub" and dread == 0, "Plot_" .. i .. " centre is not full Sanctuary")
	end
	assert(select(2, Light.Classify(0, Hub.CausewayParkZ())) == 0, "the Commons' south edge is not full Sanctuary")
	assert(select(2, Light.Classify(0, -Hub.TowerWalkwayRadius)) == 1, "tower walkway is not full Dread")
	local mid = select(2, Light.Classify(0, (Hub.CausewayTowerZ + Hub.CausewayParkZ()) / 2))
	assert(mid > 0.2 and mid < 0.8, "causeway midpoint should be mid-transition, got " .. mid)
	assert(Light.Classify(12000, 12000) == "Storm", "tower floors should use Storm")
end)

test("Raid Portal stands on the Commons east of the pool, clear of the paths and the pool", function()
	local p = Hub.RaidPortal
	local footprint = 16 * p.Scale -- the portal's dais radius
	assert(math.abs(p.X) + footprint <= Hub.HubHalfX - 20 and math.abs(p.Z) + footprint <= Hub.HubHalfZ - 20, "portal must sit inside the Commons")
	assert(p.X > 0, "portal is on the pool's east (right, seen from the dais) side")
	-- CloisterBuilder runs a 16-wide path from every plot landing to the dais, and one north along X = 0
	assert(math.abs(p.X) - footprint > 8 + 4, "portal blocks the north path")
	for i = 1, N do
		local land = Hub.HubLandingPoint(i)
		local d = segDist(p.X, p.Z, land.X - Hub.HubCentre.X, land.Z - Hub.HubCentre.Z, 0, 0)
		assert(d - footprint > 8 + 4, "portal blocks the path to Plot_" .. i)
	end
	local poolZ, poolReach = -160, (26 + 2) * 1.3 -- CloisterBuilder: pool at (0, -160) scaled 1.3, coping included
	local dPool = math.sqrt(p.X ^ 2 + (p.Z - poolZ) ^ 2)
	assert(dPool - footprint > poolReach + 20, "portal crowds the Reflecting Pool")
	assert(math.abs(p.Z - poolZ) < 20, "portal sits beside the pool, not above or below it")
end)

print(string.format("HubLayout: %d passed, %d failed", passed, failed))
if failed > 0 then error("hub layout tests failed") end
