--!strict
-- tests/effect-culling.spec.luau
-- Pure rules behind HubEffectCulling: cull distances, hysteresis and the atmospheric-emitter exemption.

local Rules = require(nodes["ReplicatedStorage.Shared.Util.EffectCullingRules"])
local cfg = Rules.Config

local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end

test("lights reach further the larger their range; emitters use one distance", function()
	assert(Rules.CullDistance(true, 22) == cfg.LightCullDistance + 22)
	assert(Rules.CullDistance(true, 38) > Rules.CullDistance(true, 22))
	assert(Rules.CullDistance(true, -5) == cfg.LightCullDistance, "negative range clamps to 0")
	assert(Rules.CullDistance(false, 99) == cfg.EmitterCullDistance, "emitters ignore reach")
end)

test("a running effect stays on up to its cull distance and turns off past it", function()
	assert(Rules.ShouldRun(100, 200, true))
	assert(Rules.ShouldRun(200, 200, true))
	assert(not Rules.ShouldRun(200.5, 200, true))
end)

test("a culled effect only turns back on inside the hysteresis band", function()
	assert(not Rules.ShouldRun(200, 200, false), "edge: stays off")
	assert(not Rules.ShouldRun(200 - cfg.Hysteresis + 1, 200, false), "still inside the band")
	assert(Rules.ShouldRun(200 - cfg.Hysteresis, 200, false), "turns on at the band's inner edge")
end)

test("an effect walked past the edge and back does not flicker", function()
	local running = true
	local flips = 0
	for _, d in { 195, 205, 199, 201, 190, 180, 176, 174 } do
		local nextRunning = Rules.ShouldRun(d, 200, running)
		if nextRunning ~= running then flips += 1 end
		running = nextRunning
	end
	assert(flips == 2, "expected one off and one on, got " .. flips)
	assert(running)
end)

test("max particle size includes the envelope", function()
	local size = Rules.MaxParticleSize({ { Value = 2, Envelope = 0 }, { Value = 20, Envelope = 6 }, { Value = 0.5, Envelope = 0 } })
	assert(size == 26, tostring(size))
end)

test("fog banks are atmospheric; torch flames and sparks are not", function()
	assert(Rules.IsAtmospheric(160), "cloud bank mist")
	assert(Rules.IsAtmospheric(34), "island cloud wisps")
	assert(not Rules.IsAtmospheric(3), "torch flame")
	assert(not Rules.IsAtmospheric(8), "chimney smoke")
	assert(not Rules.IsAtmospheric(cfg.AtmosphericParticleSize), "threshold is exclusive")
end)

print(`effect-culling: {passed} passed`)
