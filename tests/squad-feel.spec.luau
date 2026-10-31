-- Squad feel specs: spawn keep-out and SquadTactics. Bundled by run.ps1 after the module list; `nodes` and `require` come from the shim.
local Layout = require(nodes["ReplicatedStorage.Shared.Config.TowerLayout"])
local CampWaves = require(nodes["ReplicatedStorage.Shared.Util.CampWaves"])
local Combat = require(nodes["ReplicatedStorage.Shared.Config.FirstBiomeCombat"])
local MobCatalog = require(nodes["ReplicatedStorage.Shared.Config.MobCatalog"])
local Tactics = require(nodes["ReplicatedStorage.Shared.Util.SquadTactics"])
local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end
local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 1e-3)
end
local function flatDist(a: any, b: any): number
	return math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2)
end
local function role(enemyId: string): string?
	local e = Combat.Get(enemyId)
	return e and e.Role or nil
end

test("Spawn keep-out: points in the perimeter cliff band or off-terrace clamp onto open terrace", function()
	for index = 1, 5 do
		local layout = Layout.Get(index)
		local limit = layout.Width / 2 - Layout.PERIMETER_KEEP_OUT
		-- The Basin's outer ends run under the perimeter cliffs.
		local basin = layout.Platforms.Basin
		assert(not Layout.IsSpawnable(index, basin.X + basin.Width / 2 - 2, basin.Z))
		local x, z, terrace = Layout.ClampToSpawnable(index, basin.X + basin.Width / 2 - 2, basin.Z)
		assert(terrace == "Basin" and x <= limit + 1e-3 and near(z, basin.Z))
		-- The Sanctuary is never a spawn terrace.
		local safe = layout.Sanctuary
		local _, _, safeTerrace = Layout.ClampToSpawnable(index, safe.X, safe.Z)
		assert(safeTerrace ~= "Sanctuary")
		-- Terrace centres are open.
		assert(Layout.IsSpawnable(index, layout.Platforms.Crossing.X, layout.Platforms.Crossing.Z))
	end
end)

test("Spawn keep-out: every authored and scaled-in camp placement sits on open terrace", function()
	for biomeIndex, biome in MobCatalog.Biomes do
		for index = 1, 5 do
			local placements = Layout.Placements(biome, index)
			for _, p in placements do
				assert(Layout.IsSpawnable(index, p.X, p.Z), string.format("biome %d floor %d %s off terrace", biomeIndex, index, p.CampId))
			end
			for _, p in CampWaves.EffectivePlacements(index, placements, 6, role) do
				assert(Layout.IsSpawnable(index, p.X, p.Z), string.format("biome %d floor %d extra %s off terrace", biomeIndex, index, p.CampId))
			end
		end
	end
end)

test("SquadTactics: engage points fan squadmates around a target at their range", function()
	local target = Vector3.new(0, 0, 0)
	local from = Vector3.new(0, 0, 30)
	local points = {}
	for slot = 1, 5 do
		local p = Tactics.EngagePoint(from, target, slot, 6)
		assert(near(flatDist(p, target), 6 * .7), "melee stands inside its reach")
		table.insert(points, p)
	end
	for i = 1, 5 do
		for j = i + 1, 5 do
			assert(flatDist(points[i], points[j]) > 2, "slots do not stack")
		end
	end
	local ranged = Tactics.EngagePoint(from, target, 1, 30)
	assert(near(flatDist(ranged, target), 24), "ranged holds back at 80% range")
end)

test("SquadTactics: formation trails behind the heading", function()
	for slot = 1, 5 do
		local north = Tactics.FormationOffset(slot, 0, -1)
		assert(north.Z > 0, "behind a hero heading -Z means +Z")
		local east = Tactics.FormationOffset(slot, 1, 0)
		assert(east.X < 0, "behind a hero heading +X means -X")
	end
	local left, right = Tactics.FormationOffset(1, 0, -1), Tactics.FormationOffset(2, 0, -1)
	assert(left.X < 0 and right.X > 0, "slots 1 and 2 flank left and right")
end)

test("SquadTactics: speed signature and easing", function()
	local seen = {}
	for slot = 1, 5 do
		local s = Tactics.SpeedScale(slot)
		assert(s >= .96 and s <= 1.04)
		seen[s] = true
	end
	local distinct = 0
	for _ in seen do distinct += 1 end
	assert(distinct >= 4, "squadmates do not share one speed")
	assert(near(Tactics.Accelerate(0, 16, .1), Tactics.ACCELERATION * .1))
	assert(Tactics.Accelerate(15.9, 16, .1) == 16)
	assert(Tactics.Accelerate(16, 0, 1) == 0)
end)

test("SquadTactics: melee spreads off crowded mobs, ranged focuses, threats get peeled", function()
	local hero = Vector3.new(0, 0, 0)
	local crowded = { Id = 1, Position = Vector3.new(5, 0, 0), MeleeEngaged = 3, Engaged = 3, ThreatensAlly = false }
	local free = { Id = 2, Position = Vector3.new(0, 0, 12), MeleeEngaged = 0, Engaged = 0, ThreatensAlly = false }
	assert(Tactics.PickTarget(hero, 6, { crowded, free }) == 2, "melee picks the free mob")
	assert(Tactics.PickTarget(hero, 30, { crowded, free }) == 1, "ranged joins the focus")
	local threat = { Id = 3, Position = Vector3.new(0, 0, -10), MeleeEngaged = 0, Engaged = 0, ThreatensAlly = true }
	local idle = { Id = 4, Position = Vector3.new(0, 0, 6), MeleeEngaged = 0, Engaged = 0, ThreatensAlly = false }
	assert(Tactics.PickTarget(hero, 6, { threat, idle }) == 3, "peel the mob on a squadmate")
	-- Cohesion: a slightly nearer mob far from the squad centre loses to one by the squad.
	local stray = { Id = 5, Position = Vector3.new(-20, 0, 0), MeleeEngaged = 0, Engaged = 0, ThreatensAlly = false }
	local withSquad = { Id = 6, Position = Vector3.new(24, 0, 0), MeleeEngaged = 0, Engaged = 0, ThreatensAlly = false }
	assert(Tactics.PickTarget(hero, 6, { stray, withSquad }, Vector3.new(30, 0, 0)) == 6)
	assert(Tactics.PickTarget(hero, 6, {}) == nil)
end)

print(string.format("squad-feel: %d passed", passed))
