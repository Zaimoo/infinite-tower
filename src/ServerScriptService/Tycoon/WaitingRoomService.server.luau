--!strict
-- ServerScriptService/Tycoon/WaitingRoomService.server.luau
-- 1 Hz Authoritative Waiting Room Facility Tick (Mana Conduit, Infirmary & Barracks, Dimensional Lab)

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

				-- 1. Mana Conduit (Gems / Minute)
				local conduit = profile.Facilities.ManaConduit
				local conduitCfg = FacilityConfig.UpgradeTable.ManaConduit[conduit.Level] or FacilityConfig.UpgradeTable.ManaConduit[1]
				local conduitLabor = computeFacilitySumLabor(profile, conduit, "FACILITY_CONDUIT")

				-- Add Rented Mercenary labor if active
				local merc = profile.Social.RentedMercenary
				if merc and nowUnix < merc.ExpiresAt then
					local mercEff = StatFormulas.GetEffectiveLabor(merc.HeroSnapshot, "FACILITY_CONDUIT")
					if merc.Directive == "LOYAL" then
						mercEff *= 1.10
					end
					if merc.Audited and merc.Directive == "LOYAL" then
						mercEff *= 1.05 -- +5% Morale boost after passing Audit Soul
					end
					conduitLabor += mercEff
				elseif merc and nowUnix >= merc.ExpiresAt then
					profile.Social.RentedMercenary = nil
					dirty = true
				end

				local conduitMult = getBlessOrLeechMultiplier(conduit, nowUnix)
				local gemsPerMin = StatFormulas.GetManaConduitGemsPerMin(conduit.Level, conduitLabor, conduitMult)
				local gemsThisSec = gemsPerMin / 60.0

				-- Check Parasite Mercenary Siphon (30% of Mana Conduit Gem production)
				if merc and nowUnix < merc.ExpiresAt and merc.Directive == "PARASITE" then
					local siphoned = gemsThisSec * 0.30
					gemsThisSec -= siphoned
					merc.SiphonedGems += siphoned

					-- Deposit siphoned Gems to Owner every 60s
					if tickCount % 60 == 0 and merc.SiphonedGems >= 1 then
						local ownerPlayer = Players:GetPlayerByUserId(merc.OwnerUserId)
						local ownerProfile = ownerPlayer and dm.GetProfile(ownerPlayer)
						if ownerProfile then
							local transfer = math.floor(merc.SiphonedGems)
							ownerProfile.Facilities.ManaConduit.UncollectedOutput += transfer
						end
					end
				elseif merc and nowUnix < merc.ExpiresAt and merc.Directive == "LOYAL" then
					-- Loyal Contract mints +15% Bonus Royalty to Owner
					local ownerPlayer = Players:GetPlayerByUserId(merc.OwnerUserId)
					local ownerProfile = ownerPlayer and dm.GetProfile(ownerPlayer)
					if ownerProfile then
						ownerProfile.Facilities.ManaConduit.UncollectedOutput += (gemsThisSec * 0.15)
					end
				end

				-- Check Leech Rune routing to Visitor
				if nowUnix < (conduit.LeechedUntil or 0) and conduit.LeechVisitorUserId then
					local thief = Players:GetPlayerByUserId(conduit.LeechVisitorUserId)
					local thiefProfile = thief and dm.GetProfile(thief)
					if thiefProfile then
						thiefProfile.Currencies.Gems += (gemsPerMin / 60.0) * 0.20
					end
				end

				conduit.UncollectedOutput = math.min(conduitCfg.Cap, conduit.UncollectedOutput + gemsThisSec)

				-- 2. The Infirmary & Barracks (Stamina Recovery & Coma Clearing)
				if not profile.Facilities.Infirmary then
					profile.Facilities.Infirmary = { Level = 1, AssignedHeroUUIDs = {}, UncollectedOutput = 0, BlessedUntil = 0, LeechedUntil = 0, LastRuneTimestamp = 0, LastRuneWasLeech = false }
				end
				local inf = profile.Facilities.Infirmary
				local infLabor = computeFacilitySumLabor(profile, inf, "FACILITY_INFIRMARY")
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
