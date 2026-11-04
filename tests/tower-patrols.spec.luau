-- Phase E patrol specs. Bundled by run.ps1 after the module list; `nodes`, `register` and `require` come from the shim.
local Layout = require(nodes["ReplicatedStorage.Shared.Config.TowerLayout"])
local PatrolPath = require(nodes["ReplicatedStorage.Shared.Util.PatrolPath"])
local Combat = require(nodes["ReplicatedStorage.Shared.Config.FirstBiomeCombat"])
local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end

-- True when a point stands on a terrace (not the Sanctuary) or on a link's walkway.
local function onWalkable(room: any, p: any): boolean
	for id, terrace in room.Platforms do
		if id ~= "Sanctuary" and math.abs(p.X - terrace.X) <= terrace.Width / 2 and math.abs(p.Z - terrace.Z) <= terrace.Depth / 2
			and math.abs(p.Y - terrace.Y) < 0.01 then
			return true
		end
	end
	for _, link in room.Links do
		if link.From ~= "Sanctuary" then
			local dx, dz = link.BX - link.AX, link.BZ - link.AZ
			local t = math.clamp(((p.X - link.AX) * dx + (p.Z - link.AZ) * dz) / (dx * dx + dz * dz), 0, 1)
			local px, pz = link.AX + dx * t - p.X, link.AZ + dz * t - p.Z
			if px * px + pz * pz <= (link.Width / 2) ^ 2 then return true end
		end
	end
	return false
end

test("Every floor has the Basin loop, gallery routes from the third floor and the bastion ring on the fourth and fifth", function()
	for index = 1, 5 do
		local routes = Layout.PatrolRoutes(index)
		assert(routes.BASIN_LOOP)
		assert((routes.GALLERY_WEST ~= nil) == (index >= 3) and (routes.GALLERY_EAST ~= nil) == (index >= 3))
		assert((routes.BASTION_RING ~= nil) == (index >= 4))
	end
end)

test("Every waypoint stands on a walkway, outside the Sanctuary, and the Basin loop keeps to the back of the Basin", function()
	for index = 1, 5 do
		local room = Layout.Get(index)
		local safe, basin = room.Sanctuary, room.Platforms.Basin
		for id, route in Layout.PatrolRoutes(index) do
			assert(#route >= 2, id .. " is too short")
			for _, p in route do
				assert(onWalkable(room, p), id .. " waypoint off the walkways on layout " .. index)
				assert(math.abs(p.X) > safe.Width / 2 or math.abs(p.Z - safe.Z) > safe.Depth / 2, id .. " enters the Sanctuary")
			end
		end
		for _, p in Layout.PatrolRoutes(index).BASIN_LOOP do
			assert(p.Z < basin.Z, "The Basin loop must stay away from the arrival ramp")
		end
	end
end)

test("The anchor walks at the given distance, turns back at both ends and finishes a loop in loop time", function()
	local route = { { X = 0, Y = 0, Z = 0 }, { X = 10, Y = 0, Z = 0 }, { X = 10, Y = 0, Z = 10 } }
	local state = PatrolPath.Start(route)
	PatrolPath.Advance(route, state, 4)
	assert(math.abs(state.X - 4) < 1e-6 and state.Z == 0)
	PatrolPath.Advance(route, state, 11) -- past the corner and up the second leg
	assert(math.abs(state.X - 10) < 1e-6 and math.abs(state.Z - 5) < 1e-6)
	PatrolPath.Advance(route, state, 10) -- reaches the end and turns back
	assert(math.abs(state.X - 10) < 1e-6 and math.abs(state.Z - 5) < 1e-6 and state.Dir == -1)
	local full = PatrolPath.Start(route)
	PatrolPath.Advance(full, full, 0)
	PatrolPath.Advance(route, full, PatrolPath.LoopLength(route))
	assert(math.abs(full.X) < 1e-6 and math.abs(full.Z) < 1e-6, "A full loop must return to the start")
	for index = 1, 5 do
		for id, r in Layout.PatrolRoutes(index) do
			local seconds = PatrolPath.LoopLength(r) / PatrolPath.Speed
			assert(seconds > 5 and seconds < 240, id .. " loop takes " .. seconds .. " s")
		end
	end
end)

test("Patrol slots sit below the support and extra slots, and the formation holds four members", function()
	assert(Combat.PatrolSlotBase + 2 * 10 + #PatrolPath.Formation < Combat.SupportSlotBase)
	assert(Combat.SupportSlotBase < Combat.ExtraSlotBase and #PatrolPath.Formation == 4)
	assert(Combat.PatrolRespawnSeconds > Combat.CampRespawnSeconds and Combat.PatrolClearRadius > 0)
end)

print("Patrol tests: " .. passed .. " passed, 0 failed")
