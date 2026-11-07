-- Phase G timed tower event specs. Bundled by run.ps1 after the module list; `nodes`, `register` and `require` come from the shim.
local EventConfig = require(nodes["ReplicatedStorage.Shared.Config.TowerEventConfig"])
local Rules = require(nodes["ReplicatedStorage.Shared.Util.TowerEventRules"])
local Icons = require(nodes["ReplicatedStorage.Shared.Util.GrimoireIcons"])
local Floors = require(nodes["ReplicatedStorage.Shared.Config.TowerFloorConfig"])
local RelicConfig = require(nodes["ReplicatedStorage.Shared.RelicConfig"])
local Progress = require(nodes["ReplicatedStorage.Shared.Util.TowerProgress"])
local CampRoster = require(nodes["ReplicatedStorage.Shared.Util.CampRoster"])
local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end

test("Every event has an icon drawn on the 64 grid, an accent, short text and effect lines", function()
	assert(#EventConfig.Events == 6)
	local ids = {}
	for _, event in EventConfig.Events do
		assert(not ids[event.Id]); ids[event.Id] = true
		local drawing = assert(Icons.Drawings[event.Icon], "Missing icon " .. event.Icon)
		for _, s in drawing do
			assert(s.X >= 0 and s.X <= 64 and s.Y >= 0 and s.Y <= 64, event.Icon .. " shape off the grid")
		end
		assert(event.Accent and #event.Description <= 140 and #event.Description > 0)
		local lines = #event.MobEffects + #event.RewardEffects
		assert(lines >= 1 and lines <= 4, event.Id .. " has " .. lines .. " effect lines")
		assert(event.Scope == "TOWER" or event.Scope == "BIOME")
		assert(event.Weight > 0 and EventConfig.Get(event.Id) == event)
	end
	assert(Icons.Drawings.EventHourglass)
end)

test("The scheduler never repeats an event back to back and only features unlocked biomes", function()
	local rng = CampRoster.Rng(4242)
	local last: string? = nil
	for _ = 1, 2000 do
		local unlocked = Rules.UnlockedBiomes(math.floor(rng() * 50))
		local id, biome = Rules.Pick(rng, last, unlocked)
		assert(id and id ~= last, "Repeated or missing event")
		local event = assert(EventConfig.Get(id))
		if event.Scope == "BIOME" then
			assert(table.find(unlocked, biome), "Featured a locked biome")
			assert(biome >= math.ceil(event.MinFloor / 5))
		else
			assert(biome == 0)
		end
		last = id
	end
	-- A fresh server (nothing cleared) still gets an event, never one that cannot touch floor 1-5.
	for seed = 1, 200 do
		local id = Rules.Pick(CampRoster.Rng(seed), nil, Rules.UnlockedBiomes(0))
		assert(id and assert(EventConfig.Get(id)).MinFloor <= 5)
	end
end)

test("Difficulty events never touch floors 1-5, and biome events only touch their featured biome", function()
	for _, event in EventConfig.Events do
		local hard = event.Mods.HP or event.Mods.ATK or event.Mods.ForceAffix or event.Mods.AllCampsElite or event.Mods.RespawnSeconds
		for floorId = 1, 50 do
			local biome = math.ceil(floorId / 5)
			local applies = Rules.Applies(event, floorId, biome, 3)
			if hard and floorId <= 5 then assert(not applies, event.Id .. " touches floor " .. floorId) end
			if event.Scope == "BIOME" then assert(not applies or biome == 3) end
		end
	end
end)

test("Event relic mods keep Hearts on Alphas and Bosses and Cores on Elites, and raise what they promise", function()
	local calamity = assert(EventConfig.Get("CALAMITY_HOUR")).Mods
	local hunt = assert(EventConfig.Get("ALPHA_HUNT")).Mods
	local n = 4000
	for _, floorId in { 6, 30, 50 } do
		local biome = RelicConfig.GetBiomeForFloor(floorId)
		local apexRelic = biome and biome.DropTable[4] or "CALAMITY_HEART"
		local eliteRelic = biome and biome.DropTable[3] or "ABYSSAL_CORE"
		for _, role in { "REGULAR", "ELITE", "ALPHA", "BOSS" } do
			local base, boosted = 0, 0
			for i = 1, n do
				local roll = (i - 0.5) / n
				local tier = Floors.RollRelic(floorId, role, roll, (i * 37 % n) / n, calamity)
				if tier then boosted += 1 end
				if Floors.RollRelic(floorId, role, roll, 0.5) then base += 1 end
				assert(tier ~= apexRelic or role == "ALPHA" or role == "BOSS", "Heart outside Alphas and Bosses")
				assert(tier ~= eliteRelic or role == "ELITE", "Core outside Elites")
				local hunted = Floors.RollRelic(floorId, role, roll, (i * 37 % n) / n, hunt)
				assert(hunted ~= eliteRelic or role == "ELITE")
			end
			assert(boosted >= base * 1.9, role .. " drops did not double on floor " .. floorId)
		end
	end
	-- Alpha Hunt triples the Heart / Apex Core share.
	local f26Biome = RelicConfig.GetBiomeForFloor(26)
	local f26Apex = f26Biome and f26Biome.DropTable[4] or "CALAMITY_HEART"
	local hearts, huntedHearts = 0, 0
	for i = 1, n do
		local roll = (i - 0.5) / n
		if Floors.RollRelic(26, "ALPHA", 0, roll) == f26Apex then hearts += 1 end
		if Floors.RollRelic(26, "ALPHA", 0, roll, hunt) == f26Apex then huntedHearts += 1 end
	end
	assert(math.abs(huntedHearts - hearts * 3) <= 3)
end)

test("Swarm's kill progress multiplier speeds up the boss summon", function()
	local plain, swarm = Progress.CreateProgress(10), Progress.CreateProgress(10)
	local plainKills, swarmKills = 0, 0
	while not plain.BossSpawned do Progress.RecordKill(plain, "REGULAR"); plainKills += 1 end
	while not swarm.BossSpawned do Progress.RecordKill(swarm, "REGULAR", assert(EventConfig.Get("SWARM")).Mods.KillMult); swarmKills += 1 end
	assert(swarmKills < plainKills and swarmKills >= math.floor(plainKills / 1.5))
end)

test("The HUD timer counts calm down to the start, fills the warning and drains the event", function()
	local left, fraction = Rules.Timer("CALM", 100, 400, 700, 60)
	assert(left == 300 and fraction == 0)
	left, fraction = Rules.Timer("WARNING", 370, 400, 700, 60)
	assert(left == 30 and math.abs(fraction - 0.5) < 1e-9)
	left, fraction = Rules.Timer("ACTIVE", 550, 400, 700, 60)
	assert(left == 150 and math.abs(fraction - 0.5) < 1e-9)
	left, fraction = Rules.Timer("ACTIVE", 800, 400, 700, 60)
	assert(left == 0 and fraction == 0, "Server time drift past the end must not go negative")
	assert(Rules.Format(272) == "4:32" and Rules.Format(-3) == "0:00")
end)

test("Camp resets hit every floor a tower event touches and only the featured biome for biome events", function()
	local biomeOf = function(floorId: number): number return assert(Floors.Get(floorId)).BiomeIndex end
	for _, event in EventConfig.Events do
		local featured = if event.Scope == "BIOME" then math.max(3, math.ceil(event.MinFloor / 5)) else 0
		local floors = Rules.AffectedFloors(event, featured, Floors.FloorCount, biomeOf)
		assert(#floors > 0, event.Id .. " resets no floor")
		local hit = {}
		for _, floorId in floors do
			hit[floorId] = true
			assert(floorId >= event.MinFloor, event.Id .. " resets a floor below its minimum")
			assert(event.Scope == "TOWER" or biomeOf(floorId) == featured, event.Id .. " resets outside its biome")
		end
		for floorId = 1, Floors.FloorCount do
			assert((hit[floorId] == true) == Rules.Applies(event, floorId, biomeOf(floorId), featured), event.Id .. " missed floor " .. floorId)
		end
	end
end)

print("Event tests: " .. passed .. " passed, 0 failed")
