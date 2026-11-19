--!strict
-- tests/hub-grass-mask.spec.luau
-- Pure math & layout tests for HubGrassMask (rounded-rectangle bounds, Hub path/landmark exclusions,
-- deterministic noise clustering, and distance emergence fade).

local HubLayout = require(nodes["ReplicatedStorage.Shared.Config.HubLayout"])
local HubGrassMask = require(nodes["ReplicatedStorage.Shared.Util.HubGrassMask"])

local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end

test("InsideHubBounds matches the Cloister Commons rounded rectangle with rim margin", function()
	assert(HubGrassMask.InsideHubBounds(0, 0), "Hub centre should be inside")
	assert(HubGrassMask.InsideHubBounds(-180, 120), "SW lawn should be inside")
	assert(HubGrassMask.InsideHubBounds(180, -120), "NE lawn should be inside")
	assert(not HubGrassMask.InsideHubBounds(238, 0), "Rim margin should exclude outer wall strip")
	assert(not HubGrassMask.InsideHubBounds(0, 318), "Rim margin should exclude south wall strip")
	assert(not HubGrassMask.InsideHubBounds(225, 305), "Outside rounded corner arc must be excluded")
	assert(not HubGrassMask.InsideHubBounds(300, 0), "Outside Hub width must be excluded")
end)

test("IsOnPathOrLandmark excludes WayfinderDais, Pilgrim's Way, radial paths, ponds, and buildings", function()
	assert(HubGrassMask.IsOnPathOrLandmark(0, 0), "WayfinderDais centre excluded")
	assert(HubGrassMask.IsOnPathOrLandmark(0, 50), "WayfinderDais edge excluded")
	assert(HubGrassMask.IsOnPathOrLandmark(0, 180), "Pilgrim's Way boulevard excluded")
	assert(HubGrassMask.IsOnPathOrLandmark(46, 136), "Leaderboard Pavilion spur excluded")
	assert(HubGrassMask.IsOnPathOrLandmark(86, 156), "Leaderboard Pavilion footprint excluded")
	assert(HubGrassMask.IsOnPathOrLandmark(-90, 165), "Gazebo footprint excluded")
	assert(HubGrassMask.IsOnPathOrLandmark(-150, 280), "OverlookTerrace excluded")
	assert(HubGrassMask.IsOnPathOrLandmark(150, 275), "BiomeStones excluded")
	assert(HubGrassMask.IsOnPathOrLandmark(0, -160), "ReflectingPool excluded")
	assert(HubGrassMask.IsOnPathOrLandmark(117.5, -173), "WaterfallBoulderPond excluded")
	assert(HubGrassMask.IsOnPathOrLandmark(-52.1, 233.1), "RockeryKoiPond excluded")
	assert(HubGrassMask.IsOnPathOrLandmark(157, 43.4), "SteppingStreamPond excluded")
	assert(HubGrassMask.IsOnPathOrLandmark(HubLayout.RaidPortal.X, HubLayout.RaidPortal.Z), "RaidPortal excluded")
	assert(HubGrassMask.IsOnPathOrLandmark(HubLayout.ReforgeStation.X, HubLayout.ReforgeStation.Z), "ReforgeStation excluded")

	-- Radial path midpoints to all 8 plots must be excluded
	local c = HubLayout.HubCentre
	for i = 1, HubLayout.PlotCount do
		local land = HubLayout.HubLandingPoint(i)
		local lx, lz = land.X - c.X, land.Z - c.Z
		assert(HubGrassMask.IsOnPathOrLandmark(lx * 0.5, lz * 0.5), "Plot_" .. i .. " radial path midpoint excluded")
	end

	-- Open lawn bays must remain clear for grass
	assert(not HubGrassMask.IsOnPathOrLandmark(-55, 85), "SW open lawn near Pilgrim's Way should allow grass")
	assert(not HubGrassMask.IsOnPathOrLandmark(75, -80), "NE open lawn should allow grass")
	assert(not HubGrassMask.IsOnPathOrLandmark(-140, -140), "NW open lawn should allow grass")
end)

test("SampleCell is deterministic and produces natural clustered patches", function()
	local ok1, x1, z1, d1, y1 = HubGrassMask.SampleCell(-15, 22)
	local ok2, x2, z2, d2, y2 = HubGrassMask.SampleCell(-15, 22)
	assert(ok1 == ok2 and x1 == x2 and z1 == z2 and d1 == d2 and y1 == y2, "Same cell must sample identically")

	local hits, total = 0, 0
	for cx = -28, -10 do
		for cz = 14, 32 do
			total += 1
			local ok, lx, lz = HubGrassMask.SampleCell(cx, cz)
			if ok then
				hits += 1
				assert(HubGrassMask.InsideHubBounds(lx, lz), "Sampled cell must be inside Hub bounds")
				assert(not HubGrassMask.IsOnPathOrLandmark(lx, lz), "Sampled cell must clear paths and landmarks")
			end
		end
	end
	assert(hits > 0 and hits < total, string.format("Expected organic grass clustering (got %d/%d hits)", hits, total))
end)

test("FadeFactor smoothly fades from 1 inside FadeStartRadius to 0 at ActiveRadius", function()
	local cfg = HubGrassMask.Config
	assert(HubGrassMask.FadeFactor(0) == 1)
	assert(HubGrassMask.FadeFactor(cfg.FadeStartRadius) == 1)
	local mid = HubGrassMask.FadeFactor((cfg.FadeStartRadius + cfg.ActiveRadius) * 0.5)
	assert(mid > 0.4 and mid < 0.6, "Midpoint smoothstep should be near 0.5, got " .. tostring(mid))
	assert(HubGrassMask.FadeFactor(cfg.FadeStartRadius + 1) > HubGrassMask.FadeFactor(cfg.ActiveRadius - 1))
	assert(HubGrassMask.FadeFactor(cfg.ActiveRadius) == 0)
	assert(HubGrassMask.FadeFactor(cfg.ActiveRadius + 20) == 0)
end)

print(`hub-grass-mask: {passed} passed`)
