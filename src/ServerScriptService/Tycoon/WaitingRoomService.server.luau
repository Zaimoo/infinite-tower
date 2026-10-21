--!strict
-- ServerScriptService/Tycoon/WaitingRoomService.server.luau
-- 1 Hz Authoritative Waiting Room Facility Tick (Infirmary & Barracks)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FacilityConfig = require(Shared:WaitForChild("Config"):WaitForChild("FacilityConfig"))
local StatFormulas = require(Shared:WaitForChild("Util"):WaitForChild("StatFormulas"))

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

-- 1 Hz Economy Loop
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
				local dirty = false

				-- Expire Rented Mercenary if contract has elapsed
				local merc = profile.Social.RentedMercenary
				if merc and nowUnix >= merc.ExpiresAt then
					profile.Social.RentedMercenary = nil
					dirty = true
				end

				-- 1. The Infirmary & Barracks (Stamina Recovery & Coma Clearing)
				if not profile.Facilities.Infirmary then
					profile.Facilities.Infirmary = { Level = 1, AssignedHeroUUIDs = {}, UncollectedOutput = 0, BlessedUntil = 0, LeechedUntil = 0, LastRuneTimestamp = 0, LastRuneWasLeech = false }
				end
				local inf = profile.Facilities.Infirmary
				local infLabor = computeFacilitySumLabor(profile, inf, "FACILITY_INFIRMARY") * getBlessOrLeechMultiplier(inf, nowUnix)
				local staminaRegenPerSec, _ = StatFormulas.GetInfirmaryRates(inf.Level, infLabor)

				for _, hero in pairs(profile.Heroes) do
					if hero.ComaUntilTimestamp > 0 and nowUnix >= hero.ComaUntilTimestamp then
						hero.ComaUntilTimestamp = 0
						hero.CurrentStamina = 50.0
						dirty = true
					end
					if hero.Assignment == "FACILITY_INFIRMARY" and hero.ComaUntilTimestamp <= nowUnix then
						if hero.CurrentStamina < hero.MaxStamina then
							hero.CurrentStamina = math.min(hero.MaxStamina, hero.CurrentStamina + staminaRegenPerSec)
							dirty = true
						end
					elseif hero.Assignment == "BENCHED" and hero.CurrentStamina < hero.MaxStamina then
						-- Gentle passive bench recovery
						hero.CurrentStamina = math.min(hero.MaxStamina, hero.CurrentStamina + 1.0)
					end
				end

				if dirty or (tickCount % 3 == 0) then
					dm.SyncProfile(player)
				end
			end
		end
	end
end)
