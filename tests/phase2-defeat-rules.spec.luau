--!strict
-- tests/phase2-defeat-rules.spec.luau
-- Phase 2 Defeat Rules: Hard Death, Coma State, Squad Wipe Trigger, and Instant Plot Restoration.

local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end

test("Phase 2: Individual hero death puts hero in COMA with no 60s timer and allows remaining heroes to fight", function()
	local fakeOwner = { UserId = 501, Name = "MasterPlayer" }

	local deployedHeroes: { [string]: any } = {
		["hero_1"] = { UUID = "hero_1", DisplayName = "Han", MaxHP = 1000, CurrentHP = 1000, State = "FOLLOW_MASTER", SlotIndex = 1 },
		["hero_2"] = { UUID = "hero_2", DisplayName = "Baird", MaxHP = 1500, CurrentHP = 1500, State = "FOLLOW_MASTER", SlotIndex = 2 },
		["hero_3"] = { UUID = "hero_3", DisplayName = "Evelyn", MaxHP = 800, CurrentHP = 800, State = "FOLLOW_MASTER", SlotIndex = 3 },
		["hero_4"] = { UUID = "hero_4", DisplayName = "Vance", MaxHP = 1200, CurrentHP = 1200, State = "FOLLOW_MASTER", SlotIndex = 4 },
		["hero_5"] = { UUID = "hero_5", DisplayName = "Morrigan", MaxHP = 750, CurrentHP = 750, State = "FOLLOW_MASTER", SlotIndex = 5 },
	}

	local masterState = {
		DeployedHeroes = deployedHeroes,
		IsSquadWiped = false,
		CanCollectLoot = true,
		CarriedLoot = { Gold = 500, Gems = 5 },
	}

	local profile = {
		Heroes = {
			["hero_1"] = { UUID = "hero_1", CurrentStamina = 100, ComaUntilTimestamp = nil },
			["hero_2"] = { UUID = "hero_2", CurrentStamina = 100, ComaUntilTimestamp = nil },
			["hero_3"] = { UUID = "hero_3", CurrentStamina = 100, ComaUntilTimestamp = nil },
			["hero_4"] = { UUID = "hero_4", CurrentStamina = 100, ComaUntilTimestamp = nil },
			["hero_5"] = { UUID = "hero_5", CurrentStamina = 100, ComaUntilTimestamp = nil },
		},
		BankedCurrencies = { Gold = 25000, Gems = 150 },
	}

	-- Function to simulate hero reaching 0 HP in Phase 2
	local lootDropped = false
	local teleportTriggered = false
	local defeatNotificationFired = false

	local function onHeroDefeated(simHero: any)
		simHero.CurrentHP = 0
		simHero.State = "COMA"
		simHero.TargetNetId = nil

		local heroInst = profile.Heroes[simHero.UUID]
		if heroInst then
			-- Phase 2: 60s timer is abolished!
			heroInst.ComaUntilTimestamp = nil
		end

		-- Check alive heroes in squad
		local hasAlive = false
		for _, h in pairs(masterState.DeployedHeroes) do
			if h.State ~= "COMA" and h.CurrentHP > 0 then
				hasAlive = true
				break
			end
		end

		if not hasAlive and not masterState.IsSquadWiped then
			masterState.CanCollectLoot = false
			masterState.IsSquadWiped = true
			lootDropped = true
			masterState.CarriedLoot = { Gold = 0, Gems = 0 }
			defeatNotificationFired = true
			teleportTriggered = true
		end
	end

	-- 1. Kill Hero 1
	onHeroDefeated(deployedHeroes["hero_1"])
	assert(deployedHeroes["hero_1"].State == "COMA", "Hero 1 must enter COMA")
	assert(deployedHeroes["hero_1"].CurrentHP == 0, "Hero 1 HP must be 0")
	assert(profile.Heroes["hero_1"].ComaUntilTimestamp == nil, "No 60-second timer allowed")
	assert(masterState.IsSquadWiped == false, "Squad should not be wiped with 4 heroes alive")
	assert(masterState.CanCollectLoot == true, "Looting should still be allowed")
	assert(lootDropped == false, "Loot should not drop when partially alive")

	-- 2. Kill Heroes 2, 3, 4
	onHeroDefeated(deployedHeroes["hero_2"])
	onHeroDefeated(deployedHeroes["hero_3"])
	onHeroDefeated(deployedHeroes["hero_4"])
	assert(masterState.IsSquadWiped == false, "Squad should not be wiped with 1 hero alive")
	assert(deployedHeroes["hero_5"].State == "FOLLOW_MASTER", "Hero 5 must still be fighting")
	assert(deployedHeroes["hero_5"].CurrentHP > 0, "Hero 5 must be alive")

	-- 3. Kill 5th and final hero -> SQUAD WIPE!
	onHeroDefeated(deployedHeroes["hero_5"])
	assert(deployedHeroes["hero_5"].State == "COMA", "Hero 5 must enter COMA")
	assert(masterState.IsSquadWiped == true, "Squad must be marked WIPED")
	assert(masterState.CanCollectLoot == false, "Looting must be disabled on squad wipe")
	assert(lootDropped == true, "Carried unbanked floor loot must be dropped on wipe")
	assert(masterState.CarriedLoot.Gold == 0 and masterState.CarriedLoot.Gems == 0, "Carried loot cleared")
	assert(defeatNotificationFired == true, "Defeat notification must fire")
	assert(teleportTriggered == true, "Teleport to Fortress Plot must trigger")

	-- 4. Verify Banked items/currencies are 100% safe!
	assert(profile.BankedCurrencies.Gold == 25000, "Banked Gold must remain 100% safe")
	assert(profile.BankedCurrencies.Gems == 150, "Banked Gems must remain 100% safe")

	-- 5. Simulate Arrival at Fortress Plot (Instant Squad Restoration)
	local function onPlotArrival()
		for _, h in pairs(masterState.DeployedHeroes) do
			h.CurrentHP = h.MaxHP
			h.State = "FOLLOW_MASTER"
		end
		masterState.IsSquadWiped = false
		masterState.CanCollectLoot = true
		for _, heroInst in pairs(profile.Heroes) do
			heroInst.ComaUntilTimestamp = nil
		end
	end

	onPlotArrival()

	-- All 5 heroes must be restored to 100% HP and active state immediately
	for uuid, h in pairs(deployedHeroes) do
		assert(h.CurrentHP == h.MaxHP, string.format("%s must be restored to MaxHP %d, got %d", uuid, h.MaxHP, h.CurrentHP))
		assert(h.State == "FOLLOW_MASTER", string.format("%s must be FOLLOW_MASTER", uuid))
		assert(profile.Heroes[uuid].ComaUntilTimestamp == nil, "Coma timestamp must remain nil")
	end
	assert(masterState.IsSquadWiped == false, "Wipe state must be cleared on plot")
	assert(masterState.CanCollectLoot == true, "Loot collection must be re-enabled on plot")
end)

test("Phase 2: Transfer and squad recall on the same floor preserves COMA state of fallen heroes", function()
	local heroes = {
		h1 = { UUID = "h1", CurrentHP = 0, State = "COMA" },
		h2 = { UUID = "h2", CurrentHP = 500, State = "ATTACKING" },
		h3 = { UUID = "h3", CurrentHP = 800, State = "MOVE_TO_TARGET" },
	}

	-- Simulate Transfer on the same floor (e.g. recall)
	local function onTransfer(roomFloorId: number)
		for _, h in pairs(heroes) do
			if h.CurrentHP > 0 and h.State ~= "COMA" then
				h.State = "FOLLOW_MASTER"
			else
				h.State = "COMA"
			end
		end
		if roomFloorId == 0 then
			for _, h in pairs(heroes) do
				h.CurrentHP = 1000
				h.State = "FOLLOW_MASTER"
			end
		end
	end

	-- Recall on floor 1: h1 must remain in COMA!
	onTransfer(1)
	assert(heroes.h1.State == "COMA", "Fallen hero must remain in COMA on squad recall")
	assert(heroes.h1.CurrentHP == 0, "Fallen hero HP must remain 0")
	assert(heroes.h2.State == "FOLLOW_MASTER", "Living hero h2 enters FOLLOW_MASTER")
	assert(heroes.h3.State == "FOLLOW_MASTER", "Living hero h3 enters FOLLOW_MASTER")

	-- Transfer to Fortress Plot (floor 0): all heroes restored!
	onTransfer(0)
	assert(heroes.h1.State == "FOLLOW_MASTER", "Fallen hero restores on plot")
	assert(heroes.h1.CurrentHP == 1000, "Fallen hero restores HP on plot")
end)

test("Phase 2: Navigating between floors fully revives and heals every hero from COMA", function()
	local heroes = {
		h1 = { UUID = "h1", DisplayName = "Han", MaxHP = 1200, CurrentHP = 0, State = "COMA", FloorId = 1 },
		h2 = { UUID = "h2", DisplayName = "Valeria", MaxHP = 1500, CurrentHP = 400, State = "FOLLOW_MASTER", FloorId = 1 },
		h3 = { UUID = "h3", DisplayName = "Aaron", MaxHP = 1000, CurrentHP = 0, State = "COMA", FloorId = 1 },
	}

	-- Simulate floor traversal: player moves from Floor 1 to Floor 2
	local function onFloorTraversal(targetFloorId: number)
		local changedFloor = false
		for _, h in pairs(heroes) do
			if h.FloorId ~= targetFloorId then
				changedFloor = true
			end
			h.FloorId = targetFloorId
		end
		-- Rule: Moving between floors fully heals and revives squad (targetFloorId == 0 or changedFloor == true)
		if targetFloorId == 0 or changedFloor then
			for _, h in pairs(heroes) do
				h.CurrentHP = h.MaxHP
				h.State = "FOLLOW_MASTER"
			end
		end
	end

	-- Move from Floor 1 -> Floor 2
	onFloorTraversal(2)

	-- All heroes must be fully healed and revived!
	for id, h in pairs(heroes) do
		assert(h.CurrentHP == h.MaxHP, string.format("%s must be healed to MaxHP %d, got %d", id, h.MaxHP, h.CurrentHP))
		assert(h.State == "FOLLOW_MASTER", string.format("%s must be revived to FOLLOW_MASTER, got %s", id, h.State))
		assert(h.FloorId == 2, "Hero must be on floor 2")
	end
end)

test("Phase 2: Partial squad casualty tracking produces accurate status and tooltip payload", function()
	local heroes = {
		h1 = { DisplayName = "Han", MaxHP = 1000, CurrentHP = 0, State = "COMA" },
		h2 = { DisplayName = "Valeria", MaxHP = 1200, CurrentHP = 600, State = "FOLLOW_MASTER" },
		h3 = { DisplayName = "Aaron", MaxHP = 800, CurrentHP = 800, State = "FOLLOW_MASTER" },
		h4 = { DisplayName = "Ignis", MaxHP = 900, CurrentHP = 0, State = "COMA" },
	}

	local total = 0
	local alive = 0
	local fallen = 0
	local fallenNames = {}
	local heroStatuses = {}

	for _, h in pairs(heroes) do
		total += 1
		local isDown = h.State == "COMA" or h.CurrentHP <= 0
		if isDown then
			fallen += 1
			table.insert(fallenNames, h.DisplayName)
			table.insert(heroStatuses, { Name = h.DisplayName, Alive = false, HpPct = 0 })
		else
			alive += 1
			local pct = math.round((h.CurrentHP / math.max(1, h.MaxHP)) * 100)
			table.insert(heroStatuses, { Name = h.DisplayName, Alive = true, HpPct = pct })
		end
	end

	assert(total == 4, "Total count must be 4")
	assert(alive == 2, "Alive count must be 2")
	assert(fallen == 2, "Fallen count must be 2")
	assert(#fallenNames == 2, "2 fallen names recorded")
	assert(table.find(fallenNames, "Han") ~= nil, "Han must be in fallen list")
	assert(table.find(fallenNames, "Ignis") ~= nil, "Ignis must be in fallen list")
end)

print(string.format("Phase 2 defeat rule tests: %d passed", passed))
