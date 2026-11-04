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

test("Ten plots around the cloister, with distinct slots and a full assignment order", function()
	assert(N == 10 and #Hub.PlotSlots == 10, "expected 10 plot slots")
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
		local gate = Vector3.new(c.X - slot.DX * Hub.PlotHalfDepth, 12, c.Z - slot.DZ * Hub.PlotHalfDepth)
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

test("Cloister clears the tower walkway and leaves a causeway", function()
	local southEdge = Hub.CausewayParkZ()
	assert(southEdge < Hub.CausewayTowerZ, "hub overlaps the tower walkway")
	assert(Hub.CausewayTowerZ - southEdge >= 60, "causeway too short to slope gently")
	assert(Hub.VoidCornerRadius > 0 and Hub.IslandHalfX < Hub.VoidHalfX and Hub.IslandHalfZ < Hub.VoidHalfZ, "island must float inside the void")
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

test("Hub bank zones cover the band, island, footbridges, plot bridges and causeway, but not the void", function()
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
	local band = Hub.VoidHalfX + Hub.BandWidth * 0.5
	assert(inAny(Hub.HubPoint(-band, 0)) and inAny(Hub.HubPoint(band, 0)), "side bands not covered")
	assert(inAny(Hub.HubPoint(0, Hub.VoidHalfZ + 60)) and inAny(Hub.HubPoint(0, -Hub.VoidHalfZ - 60)), "north/south bands not covered")
	assert(inAny(Hub.HubPoint(0, 0)), "island not covered")
	assert(inAny(Hub.HubPoint((Hub.IslandHalfX + Hub.VoidHalfX) / 2, 0)), "east footbridge not covered")
	for i = 1, N do
		local slot = Hub.PlotSlots[i]
		local land = Hub.HubLandingPoint(i)
		local h = Hub.PlotBridgeLength / 2
		local mid = Vector3.new(land.X + slot.DX * h, 12, land.Z + slot.DZ * h)
		assert(Protocol.InZone(mid, origin, zones["HUB_BRIDGE_" .. i]), "bridge " .. i .. " not covered")
	end
	assert(Protocol.InZone(Vector3.new(0, 14, (Hub.CausewayTowerZ + Hub.CausewayParkZ()) / 2), origin, zones.HUB_CAUSEWAY), "causeway not covered")
	assert(not inAny(Hub.HubPoint((Hub.IslandHalfX + Hub.VoidHalfX) / 2, 100)), "the void must not be a bank zone")
	assert(not inAny(Vector3.new(0, 16, -300)), "tower arrival must not be a bank zone")
end)

test("Lighting: plots and the cloister are Sanctuary, the walkway is Dread, the causeway blends, floors are Storm", function()
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
	assert(select(2, Light.Classify(0, Hub.CausewayParkZ())) == 0, "the cloister's south edge is not full Sanctuary")
	assert(select(2, Light.Classify(0, -Hub.TowerWalkwayRadius)) == 1, "tower walkway is not full Dread")
	local mid = select(2, Light.Classify(0, (Hub.CausewayTowerZ + Hub.CausewayParkZ()) / 2))
	assert(mid > 0.2 and mid < 0.8, "causeway midpoint should be mid-transition, got " .. mid)
	assert(Light.Classify(12000, 12000) == "Storm", "tower floors should use Storm")
end)

print(string.format("HubLayout: %d passed, %d failed", passed, failed))
if failed > 0 then error("hub layout tests failed") end
