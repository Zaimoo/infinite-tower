--!strict
-- ServerScriptService/Tycoon/WaitingRoomService.server.luau
-- 1 Hz Authoritative Waiting Room & Outskirts AFK Economy Loop (GDD Sections 2.4 & 4.3)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FacilityConfig = require(Shared:WaitForChild("Config"):WaitForChild("FacilityConfig"))
local StatFormulas = require(Shared:WaitForChild("Util"):WaitForChild("StatFormulas"))
local FortressTree = require(Shared:WaitForChild("Util"):WaitForChild("FortressTree"))

local function getDataManager(): any
	while not _G.DataManager do
		task.wait(0.05)
	end
	return _G.DataManager
end

local function computeFacilitySumLabor(profile: any, facilityData: any, assignmentTag: string): number
	local sum = 0
	if not facilityData or not facilityData.AssignedHeroUUIDs then return 0 end
	for _, uuid in ipairs(facilityData.AssignedHeroUUIDs) do
		local hero = profile.Heroes[uuid]
		if hero and (hero.ComaUntilTimestamp or 0) <= os.time() then
			sum += StatFormulas.GetEffectiveLabor(hero, assignmentTag)
		end
	end
	return sum
end

local function getBlessOrLeechMultiplier(facData: any, nowUnix: number): number
	if nowUnix < (facData.LeechedUntil or 0) then
		return 0.80 -- -20% stolen by Leech Rune
	elseif nowUnix < (facData.BlessedUntil or 0) then
		return 1.25 -- +25% from Visitor Blessing
	end
	return 1.00
end

-- 1 Hz Economy & AFK Facility Loop
task.spawn(function()
	local dm = getDataManager()
	local tickCount = 0

	while true do
		task.wait(1.0)
		tickCount += 1
		local nowUnix = os.time()

		for _, player in ipairs(Players:GetPlayers()) do
			local profile = dm.GetProfile(player)
			if profile then
				dm.EnsureFacilities(profile)
				local dirty = false

				-- Expire Rented Mercenary if contract has elapsed
				local merc = profile.Social and profile.Social.RentedMercenary
				if merc and nowUnix >= merc.ExpiresAt then
					profile.Social.RentedMercenary = nil
					dirty = true
				end

				-- 1. Coma clearing and passive stamina recovery (the Infirmary was removed in Phase 4)
				for _, hero in pairs(profile.Heroes) do
					-- Check Coma resolution
					-- Older saves may hold nil here (it was once cleared to nil); treat as 0.
					local comaTime = hero.ComaUntilTimestamp or 0
					if comaTime > 0 and nowUnix >= comaTime then
						hero.ComaUntilTimestamp = 0
						hero.CurrentStamina = 50.0
						dirty = true
					end

					-- Benched heroes and facility workers recover passively
					if (hero.Assignment == "BENCHED"
						or hero.Assignment == "FACILITY_GUARD_POST"
						or hero.Assignment == "FACILITY_MARKET"
						or hero.Assignment == "FACILITY_TRAINING"
						or hero.Assignment == "FACILITY_GODS_BLESSING")
						and hero.CurrentStamina < hero.MaxStamina
						and hero.ComaUntilTimestamp <= nowUnix then
						-- Benched & Stationed Facility workers passively recover without combat stamina drain
						hero.CurrentStamina = math.min(hero.MaxStamina, hero.CurrentStamina + 1.0)
					end
				end

				-- 2. The Outskirts Guard Post: Auto-Received Online Gold (Section 2.4 & 4.3)
				-- Every 60s (ticked in 10s sub-increments)
				if tickCount % FacilityConfig.Constants.PassiveGoldTickIntervalSeconds == 0 then
					local guardPost = profile.Facilities.GuardPost
					if guardPost and guardPost.Level >= 1 then
						local gpLabor = computeFacilitySumLabor(profile, guardPost, "FACILITY_GUARD_POST") * getBlessOrLeechMultiplier(guardPost, nowUnix)
						local bossTier = profile.HighestClearedBiomeBoss or 0
						local goldRatePerMin = StatFormulas.GetPassiveGoldRate(guardPost.Level, gpLabor, bossTier, FortressTree.PerkBonuses(profile.FortressTree))
						local goldSubIncrement = math.round((goldRatePerMin / 60) * FacilityConfig.Constants.PassiveGoldTickIntervalSeconds * 100) / 100

						if goldSubIncrement > 0 then
							profile.Currencies.Gold = (profile.Currencies.Gold or 0) + goldSubIncrement
							profile.LastActiveTimestamp = nowUnix
							dirty = true
						end
					end
				end

				if dirty or (tickCount % 3 == 0) then
					dm.SyncProfile(player)
				end
			end
		end
	end
end)
