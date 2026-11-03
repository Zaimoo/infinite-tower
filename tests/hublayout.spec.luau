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

test("Six plots in a horseshoe that opens toward the tower", function()
	assert(#Hub.PlotBearingsDeg == 6)
	for _, deg in Hub.PlotBearingsDeg do
		assert(math.abs(deg) < 180 - 30, "plot bearing blocks the South Gate: " .. deg)
	end
end)

test("No two plot islands overlap", function()
	for i = 1, 6 do
		for j = i + 1, 6 do
			assert(not overlaps(Hub.PlotCorners(i), Hub.PlotCorners(j)), string.format("Plot_%d overlaps Plot_%d", i, j))
		end
	end
end)

test("Every plot island clears the tower and its walkway", function()
	for i = 1, 6 do
		local d = polyDistToPoint(Hub.PlotCorners(i), 0, 0)
		assert(d >= Hub.TowerClearRadius, string.format("Plot_%d is %.0f studs from the tower", i, d))
	end
end)

test("Plot islands stay clear of the Commons", function()
	local c = Hub.ParkCentre
	for i = 1, 6 do
		local d = polyDistToPoint(Hub.PlotCorners(i), c.X, c.Z)
		assert(d >= Hub.ParkRadius + 100, string.format("Plot_%d bridge would be only %.0f studs", i, d - Hub.ParkRadius))
		assert(d <= Hub.ParkRadius + 180, string.format("Plot_%d bridge would be %.0f studs", i, d - Hub.ParkRadius))
	end
end)

test("Commons clears the tower walkway and leaves a causeway", function()
	local southEdge = Hub.CausewayParkZ()
	assert(southEdge < Hub.CausewayTowerZ, "park overlaps the tower walkway")
	assert(Hub.CausewayTowerZ - southEdge >= 40, "causeway too short to slope gently")
end)

test("Every island corner lies on the catch plane and in hub bounds", function()
	local kc, ks = Hub.KillZoneCentre, Hub.KillZoneSize
	for i = 1, 6 do
		for _, v in Hub.PlotCorners(i) do
			assert(math.abs(v[1] - kc.X) < ks.X / 2 - 50 and math.abs(v[2] - kc.Z) < ks.Z / 2 - 50, "corner off the catch plane")
			assert(math.abs(v[1]) < 1500 and math.abs(v[2]) < 1500, "corner outside rooms[0].Bounds")
		end
	end
end)

test("Hub bank zones cover the Commons, every bridge and the causeway, and nothing else", function()
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
	local c = Hub.ParkCentre
	assert(Protocol.InZone(Vector3.new(c.X + 150, 12, c.Z), origin, zones.HUB_COMMONS), "park edge not covered")
	for i, deg in Hub.PlotBearingsDeg do
		local mid = Hub.BearingPoint(deg, 250)
		assert(Protocol.InZone(mid, origin, zones["HUB_BRIDGE_" .. i]), "bridge " .. i .. " not covered")
	end
	assert(Protocol.InZone(Vector3.new(0, 14, (Hub.CausewayTowerZ + Hub.CausewayParkZ()) / 2), origin, zones.HUB_CAUSEWAY), "causeway not covered")
	assert(not inAny(Vector3.new(0, 16, -300)), "tower arrival must not be a bank zone")
	assert(not inAny(Vector3.new(c.X + 260, 12, c.Z - 40)), "open sky between bridges must not be a bank zone")
end)

test("Lighting: plots and Commons are Sanctuary, the walkway is Dread, the causeway blends, floors are Storm", function()
	local Light = require(nodes["ReplicatedStorage.Shared.Config.HubLighting"])
	local keys = {}
	for key in Light.Presets.Sanctuary do keys[key] = true end
	for name, preset in Light.Presets do
		for key in keys do assert(preset[key] ~= nil, name .. " is missing " .. key) end
		for key in preset do assert(keys[key], name .. " has extra field " .. key) end
	end
	for i = 1, 6 do
		local c = Hub.PlotCentre(i)
		local zone, dread = Light.Classify(c.X, c.Z)
		assert(zone == "Hub" and dread == 0, "Plot_" .. i .. " centre is not full Sanctuary")
	end
	local p = Hub.ParkCentre
	assert(select(2, Light.Classify(p.X, p.Z)) == 0, "Commons centre is not full Sanctuary")
	assert(select(2, Light.Classify(0, -Hub.TowerWalkwayRadius)) == 1, "tower walkway is not full Dread")
	local mid = select(2, Light.Classify(0, (Hub.CausewayTowerZ + Hub.CausewayParkZ()) / 2))
	assert(mid > 0.2 and mid < 0.8, "causeway midpoint should be mid-transition, got " .. mid)
	assert(Light.Classify(12000, 12000) == "Storm", "tower floors should use Storm")
end)

print(string.format("HubLayout: %d passed, %d failed", passed, failed))
if failed > 0 then error("hub layout tests failed") end
