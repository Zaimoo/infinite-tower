-- Training Grounds & Market Worker Visual Loop unit tests.
-- Bundled by tests/run.ps1 after the module list; `nodes`, `register` and `require` come from the shim.
local FacilityWorkerRules = require(nodes["ReplicatedStorage.Shared.Util.FacilityWorkerRules"])
local HeroClips = require(nodes["ReplicatedStorage.Assets.HeroRig.HeroClips"])
local FacilityConfig = require(nodes["ReplicatedStorage.Shared.Config.FacilityConfig"])
local StatFormulas = require(nodes["ReplicatedStorage.Shared.Util.StatFormulas"])

local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end

local function dist2D(a: any, b: any): number
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function inCourtyard(p: any, label: string)
	local b = FacilityWorkerRules.CourtyardBounds
	assert(
		p.X >= b.MinX and p.X <= b.MaxX and p.Z >= b.MinZ and p.Z <= b.MaxZ,
		string.format("%s out of CourtyardBounds: (%.1f, %.1f)", label, p.X, p.Z)
	)
end

test("Market and TrainingGrounds centers match FacilityConfig.FacilityLayout", function()
	local mCfg = FacilityConfig.FacilityLayout.Market
	local tCfg = FacilityConfig.FacilityLayout.TrainingArea
	local mRule = FacilityWorkerRules.Facilities.Market
	local tRule = FacilityWorkerRules.Facilities.TrainingGrounds

	assert(dist2D(mRule.Center, mCfg.Offset) < 0.01, "Market center must match FacilityConfig")
	assert(math.abs(mRule.RotationY - mCfg.RotationY) < 1e-4, "Market rotation must match FacilityConfig")
	assert(dist2D(tRule.Center, tCfg.Offset) < 0.01, "TrainingGrounds center must match FacilityConfig")
	assert(math.abs(tRule.RotationY - tCfg.RotationY) < 1e-4, "TrainingGrounds rotation must match FacilityConfig")
end)

test("All 4 Market slots have distinct roles, distinct primary clips, valid HeroClips, and non-overlapping stations", function()
	local maxMarket = StatFormulas.GetFacilityMaxWorkers("Market", 5, { MarketWorkers = 1 })
	assert(maxMarket == 4, "Lv.5 Market + Extra Stall perk should allow 4 workers")

	local roles: { [string]: boolean } = {}
	local primaryClips: { [string]: boolean } = {}
	local positions: { any } = {}

	for slot = 1, 4 do
		local spec = assert(FacilityWorkerRules.GetSlotSpec("Market", slot))
		assert(spec.SlotIndex == slot and spec.FacilityId == "Market")
		assert(not roles[spec.RoleId], "Duplicate Market RoleId: " .. spec.RoleId)
		assert(not primaryClips[spec.PrimaryClip], "Duplicate Market PrimaryClip: " .. spec.PrimaryClip)
		roles[spec.RoleId] = true
		primaryClips[spec.PrimaryClip] = true

		assert(spec.EquipHeroWeapon == false, "Market merchants should use unarmed/prop stances")
		assert(HeroClips.Get("hero_han", "UNARMED", spec.PrimaryClip) ~= nil, "Missing PrimaryClip: " .. spec.PrimaryClip)
		assert(HeroClips.Get("hero_han", "UNARMED", spec.SecondaryClip) ~= nil, "Missing SecondaryClip: " .. spec.SecondaryClip)

		inCourtyard(spec.EntryWaypoint, "Market.EntryWaypoint[" .. slot .. "]")
		inCourtyard(spec.Primary.Pos, "Market.Primary[" .. slot .. "]")
		inCourtyard(spec.Secondary.Pos, "Market.Secondary[" .. slot .. "]")
		if spec.Tertiary then
			inCourtyard(spec.Tertiary.Pos, "Market.Tertiary[" .. slot .. "]")
		end

		for prevIdx, prevPos in ipairs(positions) do
			assert(
				dist2D(spec.Primary.Pos, prevPos) >= 4.0,
				string.format("Market slot %d overlaps slot %d", slot, prevIdx)
			)
		end
		table.insert(positions, spec.Primary.Pos)
	end
end)

test("All 4 TrainingGrounds slots have distinct roles, distinct primary clips, valid HeroClips, and non-overlapping stations", function()
	local maxTrain = StatFormulas.GetFacilityMaxWorkers("TrainingGrounds", 5, { TrainingWorkers = 1 })
	assert(maxTrain == 4, "Lv.5 TrainingGrounds + Drill Sergeant perk should allow 4 workers")

	local roles: { [string]: boolean } = {}
	local primaryClips: { [string]: boolean } = {}
	local positions: { any } = {}

	for slot = 1, 4 do
		local spec = assert(FacilityWorkerRules.GetSlotSpec("TrainingGrounds", slot))
		assert(spec.SlotIndex == slot and spec.FacilityId == "TrainingGrounds")
		assert(not roles[spec.RoleId], "Duplicate TrainingGrounds RoleId: " .. spec.RoleId)
		assert(not primaryClips[spec.PrimaryClip], "Duplicate TrainingGrounds PrimaryClip: " .. spec.PrimaryClip)
		roles[spec.RoleId] = true
		primaryClips[spec.PrimaryClip] = true

		assert(spec.EquipHeroWeapon == true, "TrainingGrounds trainers should equip hero weapons")
		for _, wType in ipairs(HeroClips.WEAPON_TYPES) do
			assert(
				HeroClips.Get("hero_aaron", wType, spec.PrimaryClip) ~= nil,
				"Missing PrimaryClip " .. spec.PrimaryClip .. " for " .. wType
			)
			assert(
				HeroClips.Get("hero_aaron", wType, spec.SecondaryClip) ~= nil,
				"Missing SecondaryClip " .. spec.SecondaryClip .. " for " .. wType
			)
		end

		inCourtyard(spec.EntryWaypoint, "TrainingGrounds.EntryWaypoint[" .. slot .. "]")
		inCourtyard(spec.Primary.Pos, "TrainingGrounds.Primary[" .. slot .. "]")
		inCourtyard(spec.Secondary.Pos, "TrainingGrounds.Secondary[" .. slot .. "]")
		if spec.Tertiary then
			inCourtyard(spec.Tertiary.Pos, "TrainingGrounds.Tertiary[" .. slot .. "]")
		end

		for prevIdx, prevPos in ipairs(positions) do
			assert(
				dist2D(spec.Primary.Pos, prevPos) >= 3.5,
				string.format("TrainingGrounds slot %d overlaps slot %d", slot, prevIdx)
			)
		end
		table.insert(positions, spec.Primary.Pos)
	end
end)

test("Courtyard run-in paths and coma rest spots stay inside courtyard bounds and clear PlazaFountain", function()
	for _, facilityId in ipairs({ "Market", "TrainingGrounds" }) do
		local runIn = FacilityWorkerRules.CourtyardRunIn[facilityId]
		assert(#runIn >= 3, facilityId .. " should have at least 3 run-in waypoints")
		for idx, wp in ipairs(runIn) do
			inCourtyard(wp, facilityId .. ".RunIn[" .. idx .. "]")
			assert(
				dist2D(wp, FacilityWorkerRules.PlazaFountainCenter) >= FacilityWorkerRules.PlazaFountainClearRadius,
				string.format("%s.RunIn[%d] clips into PlazaFountain", facilityId, idx)
			)
		end
		for slot = 1, 4 do
			local coma = assert(FacilityWorkerRules.GetComaStation(facilityId, slot))
			inCourtyard(coma.Pos, facilityId .. ".Coma[" .. slot .. "]")
		end
	end

	for dummyIdx = 1, 4 do
		local dPos = FacilityWorkerRules.GetDummyPlotPosition(dummyIdx)
		inCourtyard(dPos, "TrainingDummy_" .. dummyIdx)
		assert(
			math.abs(dist2D(dPos, FacilityWorkerRules.Facilities.TrainingGrounds.Center) - 9.6) < 0.05,
			"Dummy_" .. dummyIdx .. " should sit at radius 9.6 from TrainingGrounds center"
		)
	end
end)

print(string.format("Facility worker tests: %d passed, 0 failed", passed))
