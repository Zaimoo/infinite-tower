-- Phase C camp roster specs. Bundled by run.ps1 after the module list; `nodes`, `register` and `require` come from the shim.
local CampRoster = require(nodes["ReplicatedStorage.Shared.Util.CampRoster"])
local Layout = require(nodes["ReplicatedStorage.Shared.Config.TowerLayout"])
local Mobs = require(nodes["ReplicatedStorage.Shared.Config.MobCatalog"])
local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end

-- Live camps of a layout (the Apex Sanctum is the summon spot, never a live camp).
local function liveCamps(index: number): ({ string }, { [string]: boolean })
	local ids, upper = {}, {}
	for _, camp in Layout.Get(index).Camps do
		if camp.Id ~= "APEX_SANCTUM" then
			table.insert(ids, camp.Id)
			upper[camp.Id] = camp.Platform ~= "Basin"
		end
	end
	return ids, upper
end

test("The roster generator is deterministic per seed and stays in [0, 1)", function()
	local a, b = CampRoster.Rng(CampRoster.Seed(3, 2, 1, 4)), CampRoster.Rng(CampRoster.Seed(3, 2, 1, 4))
	local c = CampRoster.Rng(CampRoster.Seed(3, 2, 1, 5))
	local differs = false
	for _ = 1, 200 do
		local x, y, z = a(), b(), c()
		assert(x == y and x >= 0 and x < 1)
		if x ~= z then differs = true end
	end
	assert(differs, "A different wave must give a different sequence")
end)

test("Every camp holds every Regular type, even with its leader taken by an Elite", function()
	for _, biome in Mobs.Biomes do
		local pool = biome.RegularEnemyIds
		for index = 1, 5 do
			for _, camp in Layout.Get(index).Camps do
				for seed = 1, 300 do
					for _, leaderIsElite in { false, true } do
						local rng = CampRoster.Rng(seed * 31 + index)
						local bag, seen = {}, {}
						local dealt = if leaderIsElite then camp.Size - 1 else camp.Size
						for _ = 1, dealt do
							local t = CampRoster.DealType(rng, bag, pool)
							assert(table.find(pool, t), "Type outside the biome pool")
							seen[t] = true
						end
						for _, t in pool do assert(seen[t], "Camp " .. camp.Id .. " is missing " .. t) end
					end
				end
			end
		end
	end
end)

test("A camp's type mix is reshuffled from wave to wave", function()
	local pool = { "a", "b" }
	local orders = {}
	for wave = 1, 50 do
		local rng = CampRoster.Rng(CampRoster.Seed(2, 1, 3, wave))
		local bag, order = {}, ""
		for _ = 1, 5 do order ..= CampRoster.DealType(rng, bag, pool) end
		orders[order] = true
	end
	local distinct = 0
	for _ in orders do distinct += 1 end
	assert(distinct > 1, "Every wave dealt the same mix")
end)

test("Each floor gets exactly its Elite count, one per camp, never in the Apex, with one above the Basin from floor 3", function()
	local expected = { 1, 2, 3, 4, 4 }
	for index = 1, 5 do
		assert(Layout.Get(index).EliteCount == expected[index])
		local ids, upper = liveCamps(index)
		for seed = 1, 1000 do
			local elites = CampRoster.AssignElites(CampRoster.Rng(seed), ids, expected[index], upper, index >= 3)
			local count, hasUpper = 0, false
			for id in elites do
				assert(table.find(ids, id) and id ~= "APEX_SANCTUM")
				count += 1
				if upper[id] then hasUpper = true end
			end
			assert(count == expected[index])
			if index >= 3 then assert(hasUpper, "No Elite above the Basin") end
		end
	end
end)

test("A moving Elite only enters a cleared camp without one, and the floor keeps its Elite count", function()
	local ids, upper = liveCamps(5)
	local visits = {}
	for seed = 1, 1000 do
		local rng = CampRoster.Rng(seed)
		local elites = CampRoster.AssignElites(rng, ids, 4, upper, true)
		local cleared = {}
		for _, id in ids do cleared[id] = rng() < 0.5 end
		for from in table.clone(elites) do
			cleared[from] = true
			local target = CampRoster.MoveElite(rng, from, elites, ids, cleared)
			if target ~= from then
				assert(cleared[target] and not elites[target], "Elite moved into a fight or onto another Elite")
				elites[from] = nil
				elites[target] = true
			end
			visits[target] = true
		end
		local count = 0
		for _ in elites do count += 1 end
		assert(count == 4)
	end
	for _, id in ids do assert(visits[id], "Camp " .. id .. " never hosted an Elite") end
	-- No cleared camp: the Elite stays.
	assert(CampRoster.MoveElite(CampRoster.Rng(7), "A", { A = true }, { "A", "B" }, { A = true, B = false }) == "A")
end)

test("Members scatter inside their area and keep their spacing", function()
	for index = 1, 5 do
		for _, camp in Layout.Get(index).Camps do
			assert(camp.Radius >= 8 and camp.Radius <= 20)
			for seed = 1, 200 do
				local offsets = CampRoster.RollOffsets(CampRoster.Rng(seed), camp.Radius, camp.Size, 8)
				assert(#offsets == camp.Size)
				for i, o in offsets do
					assert(o.X * o.X + o.Z * o.Z <= camp.Radius * camp.Radius + 1e-6, "Member outside its area")
					for j = i + 1, #offsets do
						local dx, dz = o.X - offsets[j].X, o.Z - offsets[j].Z
						assert(dx * dx + dz * dz >= 8 * 8 - 1e-6, "Members stacked closer than 8 studs")
					end
				end
			end
		end
	end
end)

print("Camp roster tests: " .. passed .. " passed, 0 failed")
