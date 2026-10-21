-- Offline review proofs. Actual extracted blocks are preserved between markers. No Roblox/network calls.
do -- repository : C:\Projects\infinite-tower\src\ServerScriptService\ExtractionAndSocial\SyndicateService.server.luau
local _G = {}
local player = { UserId = 77, DisplayName = 'OfflineTester' }
local function facility() return { LastRuneTimestamp = 0, LastRuneWasLeech = false } end
local profile = { Currencies = { Gold = 0, Gems = 0 }, Social = { Honor = 0, Stats = { LeechesPurged = 0 }, MimicIllusionMode = 'TRUE_STATE' }, Facilities = { Infirmary = facility(), ManaConduit = facility() } }
local Players = { GetPlayerByUserId = function(_, id) return id == player.UserId and player or nil end }
local dm = { GetProfile = function(p) assert(p == player); return profile end, AdjustHonor = function(p, delta) assert(p == player); profile.Social.Honor = math.clamp(profile.Social.Honor + delta, -100, 100) end, SendToast = function() end, BroadcastToast = function() end, SyncProfile = function() end }
local function getDataManager() return dm end
local callback
local PlotEspionageEvent = { OnServerEvent = { Connect = function(_, handler) callback = handler end } }
-- BEGIN ACTUAL EXTRACTED SYNDICATE HANDLER
PlotEspionageEvent.OnServerEvent:Connect(function(player: Player, opCode: any, plotIndex: any, facilityKey: any)
	local dm = getDataManager()
	local profile = dm.GetProfile(player)
	if not profile or type(opCode) ~= "number" then
		return
	end

	local facName = (type(facilityKey) == "string" and (facilityKey == "ManaConduit" or facilityKey == "Infirmary"))
		and facilityKey
		or "ManaConduit"

	if opCode == 2 or opCode == 3 then
		-- 2 = COMPLETE_BLESS (+25% output, +25 Gems, +5 Honor)
		-- 3 = COMPLETE_LEECH (-20% stolen output for 3m; identical visual animation!)
		local targetOwner = (_G.PlotManager and type(plotIndex) == "number") and _G.PlotManager.GetPlotOwner(plotIndex) or player
		local targetProf = (targetOwner and dm.GetProfile(targetOwner)) or profile
		local facData = (targetProf.Facilities :: any)[facName]
		if not facData then
			return
		end

		local nowUnix = os.time()
		facData.LastRuneTimestamp = nowUnix

		if opCode == 2 then
			-- Cooperative Blessing
			facData.BlessedUntil = nowUnix + 180
			facData.LastRuneWasLeech = false
			local bonusGems = (targetProf.Social.Honor >= 50) and 28 or 25
			profile.Currencies.Gems += bonusGems
			dm.AdjustHonor(player, 5, false)
			dm.SendToast(player, string.format("✨ Blessed %s (+25%% Output for 3m)! Earned +%d Gems & +5 Honor!", facName, bonusGems), "SUCCESS")
			if targetOwner and targetOwner ~= player then
				dm.SendToast(targetOwner, string.format("⚠️ %s channeled a rune on your %s! (15s to Purge if suspicious!)", player.DisplayName, facName), "WARN")
				dm.SyncProfile(targetOwner)
			end
		else
			-- Espionage: Plant Leech Rune
			-- Check if Target's Mana Conduit has FOOLS_GOLD Mimic Trap active!
			if facName == "ManaConduit" and targetProf.Social.MimicIllusionMode == "FOOLS_GOLD" then
				if _G.RelicService then
					_G.RelicService.StunPlayer(player, 3.0)
				end
				dm.AdjustHonor(player, -10, false)
				targetProf.Currencies.Gems += 50
				targetProf.Currencies.Gold += 500
				dm.SendToast(player, "🦷 MIMIC CHEST TRAP! You tried to leech a Fool's Gold Mimic! Stunned 3.0s & -10 Honor!", "WARN")
				if targetOwner then
					dm.SendToast(targetOwner, string.format("🦷 Your Fool's Gold Mimic Chest snapped shut on %s! Collected +50 Gems & +500 Gold Bounty!", player.DisplayName), "SUCCESS")
					dm.SyncProfile(targetOwner)
				end
				return
			end

			facData.LeechedUntil = nowUnix + 180
			facData.LeechVisitorUserId = player.UserId
			facData.LastRuneWasLeech = true
			dm.SendToast(player, string.format("🩸 Planted Secret Leech Rune on %s (Siphoning 20%% output for 3m)!", facName), "INFO")
			if targetOwner then
				dm.SendToast(targetOwner, string.format("⚠️ %s channeled a rune on your %s! (15s window to Purge Facility!)", player.DisplayName, facName), "WARN")
				dm.SyncProfile(targetOwner)
			end
		end
		dm.SyncProfile(player)

	elseif opCode == 4 then
		-- PURGE FACILITY (15.0s Window Counterplay)
		local facData = (profile.Facilities :: any)[facName]
		if not facData then
			return
		end
		local elapsed = os.time() - (facData.LastRuneTimestamp or 0)
		if elapsed > 15 then
			dm.SendToast(player, "No recent rune within the 15-second Purge window!", "INFO")
			return
		end
		facData.LastRuneTimestamp = 0

		if facData.LastRuneWasLeech then
			-- Caught a Leech Rune!
			facData.LeechedUntil = 0
			local thiefId = facData.LeechVisitorUserId
			facData.LeechVisitorUserId = nil
			profile.Social.Stats.LeechesPurged += 1
			profile.Currencies.Gems += 50
			profile.Currencies.Gold += 500

			if thiefId then
				local thief = Players:GetPlayerByUserId(thiefId)
				if thief then
					if _G.RelicService then
						_G.RelicService.StunPlayer(thief, 3.0)
					end
					dm.AdjustHonor(thief, -10, false)
					dm.SendToast(thief, "⚡ LEECH RUNE PURGED! You were stunned for 3.0s, lost -10 Honor, and dropped a Bounty Bag!", "WARN")
				end
			end
			dm.BroadcastToast(string.format("🛡️ %s purged a Leech Rune on their %s and claimed a +50 Gem / +500 Gold Bounty Bag!", player.DisplayName, facName), "SUCCESS")
		else
			-- Paranoid Mistake: Destroyed their own +25% Blessing!
			facData.BlessedUntil = 0
			dm.BroadcastToast(string.format("😂 PARANOIA! %s triggered Purge Facility and accidentally destroyed their own +25%% Blessing!", player.DisplayName), "WARN")
		end
		dm.SyncProfile(player)

	elseif opCode == 5 and type(facilityKey) == "string" then
		-- TOGGLE MIMIC CHEST ILLUSION ("TRUE_STATE" | "FOOLS_GOLD" | "VEIL_OF_POVERTY")
		if facilityKey == "TRUE_STATE" or facilityKey == "FOOLS_GOLD" or facilityKey == "VEIL_OF_POVERTY" then
			profile.Social.MimicIllusionMode = facilityKey :: any
			dm.SendToast(player, "Mana Conduit Mimic Illusion set to: " .. facilityKey, "INFO")
			dm.SyncProfile(player)
		end
	end
end)

-- END ACTUAL EXTRACTED SYNDICATE HANDLER
callback(player, 2, nil, 'Infirmary')
callback(player, 2, nil, 'Infirmary')
assert(profile.Currencies.Gems == 50, 'Expected repeat blessing payouts')
assert(profile.Social.Honor == 10, 'Expected repeat blessing honor')
print('PASS: two immediate self-bless calls: +50 Gems, +10 Honor')
local gemsBefore, goldBefore = profile.Currencies.Gems, profile.Currencies.Gold
for _ = 1, 2 do callback(player, 3, nil, 'Infirmary'); callback(player, 4, nil, 'Infirmary') end
assert(profile.Currencies.Gems - gemsBefore == 100, 'Expected repeat self-purge gem payouts')
assert(profile.Currencies.Gold - goldBefore == 1000, 'Expected repeat self-purge gold payouts')
print('PASS: two immediate self-leech/purge pairs: +100 Gems, +1000 Gold')
end
do -- studio-baseline : C:\Users\msi\Documents\ChatGPT\Infinite towers\tower-rebuild-baseline-20261021\studio-script-bodies\ServerScriptService.ExtractionAndSocial.SyndicateService.luau
local _G = {}
local player = { UserId = 77, DisplayName = 'OfflineTester' }
local function facility() return { LastRuneTimestamp = 0, LastRuneWasLeech = false } end
local profile = { Currencies = { Gold = 0, Gems = 0 }, Social = { Honor = 0, Stats = { LeechesPurged = 0 }, MimicIllusionMode = 'TRUE_STATE' }, Facilities = { Infirmary = facility(), ManaConduit = facility() } }
local Players = { GetPlayerByUserId = function(_, id) return id == player.UserId and player or nil end }
local dm = { GetProfile = function(p) assert(p == player); return profile end, AdjustHonor = function(p, delta) assert(p == player); profile.Social.Honor = math.clamp(profile.Social.Honor + delta, -100, 100) end, SendToast = function() end, BroadcastToast = function() end, SyncProfile = function() end }
local function getDataManager() return dm end
local callback
local PlotEspionageEvent = { OnServerEvent = { Connect = function(_, handler) callback = handler end } }
-- BEGIN ACTUAL EXTRACTED SYNDICATE HANDLER
PlotEspionageEvent.OnServerEvent:Connect(function(player: Player, opCode: any, plotIndex: any, facilityKey: any)
	local dm = getDataManager()
	local profile = dm.GetProfile(player)
	if not profile or type(opCode) ~= "number" then
		return
	end

	local facName = "Infirmary"

	if opCode == 2 or opCode == 3 then
		-- 2 = COMPLETE_BLESS (+25% output, +25 Gems, +5 Honor)
		-- 3 = COMPLETE_LEECH (-20% stolen output for 3m; identical visual animation!)
		local targetOwner = (_G.PlotManager and type(plotIndex) == "number") and _G.PlotManager.GetPlotOwner(plotIndex) or player
		local targetProf = (targetOwner and dm.GetProfile(targetOwner)) or profile
		local facData = (targetProf.Facilities :: any)[facName]
		if not facData then
			return
		end

		local nowUnix = os.time()
		facData.LastRuneTimestamp = nowUnix

		if opCode == 2 then
			-- Cooperative Blessing
			facData.BlessedUntil = nowUnix + 180
			facData.LastRuneWasLeech = false
			local bonusGems = (targetProf.Social.Honor >= 50) and 28 or 25
			profile.Currencies.Gems += bonusGems
			dm.AdjustHonor(player, 5, false)
			dm.SendToast(player, string.format("✨ Blessed %s (+25%% Output for 3m)! Earned +%d Gems & +5 Honor!", facName, bonusGems), "SUCCESS")
			if targetOwner and targetOwner ~= player then
				dm.SendToast(targetOwner, string.format("⚠️ %s channeled a rune on your %s! (15s to Purge if suspicious!)", player.DisplayName, facName), "WARN")
				dm.SyncProfile(targetOwner)
			end
		else
			-- Espionage: Plant Leech Rune
			facData.LeechedUntil = nowUnix + 180
			facData.LeechVisitorUserId = player.UserId
			facData.LastRuneWasLeech = true
			dm.SendToast(player, string.format("🩸 Planted Secret Leech Rune on %s (Siphoning 20%% output for 3m)!", facName), "INFO")
			if targetOwner then
				dm.SendToast(targetOwner, string.format("⚠️ %s channeled a rune on your %s! (15s window to Purge Facility!)", player.DisplayName, facName), "WARN")
				dm.SyncProfile(targetOwner)
			end
		end
		dm.SyncProfile(player)

	elseif opCode == 4 then
		-- PURGE FACILITY (15.0s Window Counterplay)
		local facData = (profile.Facilities :: any)[facName]
		if not facData then
			return
		end
		local elapsed = os.time() - (facData.LastRuneTimestamp or 0)
		if elapsed > 15 then
			dm.SendToast(player, "No recent rune within the 15-second Purge window!", "INFO")
			return
		end
		facData.LastRuneTimestamp = 0

		if facData.LastRuneWasLeech then
			-- Caught a Leech Rune!
			facData.LeechedUntil = 0
			local thiefId = facData.LeechVisitorUserId
			facData.LeechVisitorUserId = nil
			profile.Social.Stats.LeechesPurged += 1
			profile.Currencies.Gems += 50
			profile.Currencies.Gold += 500

			if thiefId then
				local thief = Players:GetPlayerByUserId(thiefId)
				if thief then
					if _G.RelicService then
						_G.RelicService.StunPlayer(thief, 3.0)
					end
					dm.AdjustHonor(thief, -10, false)
					dm.SendToast(thief, "⚡ LEECH RUNE PURGED! You were stunned for 3.0s, lost -10 Honor, and dropped a Bounty Bag!", "WARN")
				end
			end
			dm.BroadcastToast(string.format("🛡️ %s purged a Leech Rune on their %s and claimed a +50 Gem / +500 Gold Bounty Bag!", player.DisplayName, facName), "SUCCESS")
		else
			-- Paranoid Mistake: Destroyed their own +25% Blessing!
			facData.BlessedUntil = 0
			dm.BroadcastToast(string.format("😂 PARANOIA! %s triggered Purge Facility and accidentally destroyed their own +25%% Blessing!", player.DisplayName), "WARN")
		end
		dm.SyncProfile(player)
	end
end)

-- END ACTUAL EXTRACTED SYNDICATE HANDLER
callback(player, 2, nil, 'Infirmary')
callback(player, 2, nil, 'Infirmary')
assert(profile.Currencies.Gems == 50, 'Expected repeat blessing payouts')
assert(profile.Social.Honor == 10, 'Expected repeat blessing honor')
print('PASS: two immediate self-bless calls: +50 Gems, +10 Honor')
local gemsBefore, goldBefore = profile.Currencies.Gems, profile.Currencies.Gold
for _ = 1, 2 do callback(player, 3, nil, 'Infirmary'); callback(player, 4, nil, 'Infirmary') end
assert(profile.Currencies.Gems - gemsBefore == 100, 'Expected repeat self-purge gem payouts')
assert(profile.Currencies.Gold - goldBefore == 1000, 'Expected repeat self-purge gold payouts')
print('PASS: two immediate self-leech/purge pairs: +100 Gems, +1000 Gold')
end
do -- C:\Users\msi\Documents\ChatGPT\Infinite towers\tower-rebuild-baseline-20261021\studio-script-bodies\ServerScriptService.Core.DataManager.luau
local function syncMigration(profile) -- BEGIN ACTUAL EXTRACTED MIGRATION
-- Auto-migrate legacy SQUAD assignments or DeployedSquadOrder to SQUAD_SLOT_1..5
	local occupiedSlots: { [number]: string } = {}
	for uuid, h in pairs(profile.Heroes) do
		local slotNum = tonumber(string.match(h.Assignment or "", "^SQUAD_SLOT_(%d+)"))
		if slotNum and slotNum >= 1 and slotNum <= 5 then
			occupiedSlots[slotNum] = uuid
		end
	end
	if profile.DeployedSquadOrder then
		for _, uuid in ipairs(profile.DeployedSquadOrder) do
			local h = profile.Heroes[uuid]
			if h and not string.find(h.Assignment or "", "^SQUAD_SLOT_") and not string.find(h.Assignment or "", "^FACILITY_") then
				for s = 1, 5 do
					if not occupiedSlots[s] then
						h.Assignment = ("SQUAD_SLOT_" .. tostring(s)) :: HeroAssignment
						occupiedSlots[s] = uuid
						break
					end
				end
			end
		end
	end
	for uuid, h in pairs(profile.Heroes) do
		if h.Assignment == ("SQUAD" :: any) then
			for s = 1, 5 do
				if not occupiedSlots[s] then
					h.Assignment = ("SQUAD_SLOT_" .. tostring(s)) :: HeroAssignment
					occupiedSlots[s] = uuid
					break
				end
			end
			if not string.find(h.Assignment or "", "^SQUAD_SLOT_") then
				h.Assignment = "BENCHED"
			end
		elseif not h.Assignment or h.Assignment == ("" :: any) then
			h.Assignment = "BENCHED"
		end
	end

	-- Reconcile DeployedSquadOrder from Hero Assignments
	local deployed: { string } = {}
	for slot = 1, 5 do
		local slotTag = "SQUAD_SLOT_" .. tostring(slot)
		for uuid, h in pairs(profile.Heroes) do
			if h.Assignment == slotTag then
				table.insert(deployed, uuid)
				break
			end
		end
	end
	profile.DeployedSquadOrder = deployed

	
end -- END ACTUAL EXTRACTED MIGRATION
local benchProfile = { Heroes = { A = { UUID = 'A', Assignment = 'BENCHED' } }, DeployedSquadOrder = { 'A' } }
syncMigration(benchProfile)
assert(benchProfile.Heroes.A.Assignment == 'SQUAD_SLOT_1')
print('PASS: intended BENCHED A is redeployed into SQUAD_SLOT_1 by stale order')
local swapProfile = { Heroes = { A = { UUID = 'A', Assignment = 'BENCHED' }, B = { UUID = 'B', Assignment = 'SQUAD_SLOT_1' } }, DeployedSquadOrder = { 'A' } }
syncMigration(swapProfile)
assert(swapProfile.Heroes.A.Assignment == 'SQUAD_SLOT_2')
assert(swapProfile.Heroes.B.Assignment == 'SQUAD_SLOT_1')
print('PASS: displaced A is redeployed into empty SQUAD_SLOT_2 after replacing slot 1 with B')
end
do -- C:\Projects\infinite-tower\src\ServerScriptService\Core\DataManager.server.luau
local hero = { UUID = 'A', Assignment = 'FACILITY_INFIRMARY', ComaUntilTimestamp = 0 }
local profile = { Heroes = { A = hero }, Facilities = { Infirmary = { AssignedHeroUUIDs = { 'A' } } } }
for slot = 1, 5 do profile.Heroes['S' .. slot] = { UUID = 'S' .. slot, Assignment = 'SQUAD_SLOT_' .. slot } end
local player = {}
local ActiveProfiles = { [player] = profile }
local DataManager = { MaxSquadSlots = function() return 5 end, SyncProfile = function() end, SendToast = function() end }
local AssignHeroRoleFunc = {}
-- BEGIN ACTUAL EXTRACTED ASSIGNMENT BLOCK
local function removeUUIDFromFacilities(profile: PlayerProfile, uuid: string)
	for _, fac in pairs(profile.Facilities) do
		for i = #fac.AssignedHeroUUIDs, 1, -1 do
			if fac.AssignedHeroUUIDs[i] == uuid then
				table.remove(fac.AssignedHeroUUIDs, i)
			end
		end
	end
end

AssignHeroRoleFunc.OnServerInvoke = function(player: Player, heroUUID: any, targetAssignment: any)
	local profile = ActiveProfiles[player]
	if not profile then
		return false, "Profile not loaded"
	end

	-- Special Smart Action from Document 4 Section 2.2: "AUTO_SWAP_EXHAUSTED"
	if heroUUID == "AUTO_SWAP_EXHAUSTED" then
		local maxSlots = DataManager.MaxSquadSlots(profile)
		local swappedCount = 0

		-- 1. Move any deployed hero with Stamina < 25% into Infirmary
		for _, h in pairs(profile.Heroes) do
			if string.find(h.Assignment, "^SQUAD_SLOT_") and h.CurrentStamina < 25 then
				h.Assignment = "FACILITY_INFIRMARY"
				swappedCount += 1
			end
		end

		-- 2. Fill empty squad slots (1..maxSlots) with highest-DPS rested Benched heroes
		for slot = 1, maxSlots do
			local slotName = ("SQUAD_SLOT_" .. slot) :: HeroAssignment
			local occupied = false
			for _, h in pairs(profile.Heroes) do
				if h.Assignment == slotName then
					occupied = true
					break
				end
			end
			if not occupied then
				local bestHero: HeroInstance? = nil
				local bestDPS = -1
				for _, h in pairs(profile.Heroes) do
					if h.Assignment == "BENCHED" and h.CurrentStamina >= 50 and h.ComaUntilTimestamp <= os.time() then
						local _, _, dps = StatFormulas.GetEffectiveCombatStats(h, false, false)
						if dps > bestDPS then
							bestDPS = dps
							bestHero = h
						end
					end
				end
				if bestHero then
					bestHero.Assignment = slotName
					swappedCount += 1
				end
			end
		end

		DataManager.SyncProfile(player)
		DataManager.SendToast(player, string.format("Auto-Rotated Squad (%d hero assignments updated)!", swappedCount), "SUCCESS")
		return true, "Auto-swapped exhausted heroes"
	end

	if type(heroUUID) ~= "string" or type(targetAssignment) ~= "string" then
		return false, "Invalid parameters"
	end

	local hero = profile.Heroes[heroUUID]
	if not hero then
		return false, "Hero not found"
	end

	if hero.ComaUntilTimestamp > os.time() and targetAssignment ~= "FACILITY_INFIRMARY" and targetAssignment ~= "BENCHED" then
		return false, "Hero is in a Coma and must recover in The Infirmary!"
	end

	removeUUIDFromFacilities(profile, heroUUID)

	if targetAssignment == "BENCHED" then
		hero.Assignment = "BENCHED"
	elseif targetAssignment == "SQUAD_AUTO" then
		local maxSlots = DataManager.MaxSquadSlots(profile)
		local placed = false
		for slot = 1, maxSlots do
			local slotTag = ("SQUAD_SLOT_" .. slot) :: HeroAssignment
			local hasUnit = false
			for _, h in pairs(profile.Heroes) do
				if h.Assignment == slotTag then
					hasUnit = true
					break
				end
			end
			if not hasUnit then
				hero.Assignment = slotTag
				placed = true
				break
			end
		end
		if not placed then
			return false, string.format("All %d Squad Slots are full!", maxSlots)
		end
	elseif targetAssignment == "FACILITY_CONDUIT" or targetAssignment == "FACILITY_INFIRMARY" then
		local facKey = if targetAssignment == "FACILITY_CONDUIT" then "ManaConduit" else "Infirmary"
		local facData = (profile.Facilities :: any)[facKey] :: FacilityData
		local cfg = (FacilityConfig.UpgradeTable :: any)[facKey][facData.Level]
		local maxWorkers = cfg and cfg.MaxWorkers or 1

		-- Note: Infirmary also holds resting/Coma heroes beyond healer worker slots
		if targetAssignment ~= "FACILITY_INFIRMARY" and #facData.AssignedHeroUUIDs >= maxWorkers then
			return false, string.format("%s Lv.%d only has %d Worker Slot(s)! Upgrade facility for more.", facKey, facData.Level, maxWorkers)
		end
		hero.Assignment = targetAssignment :: HeroAssignment
		if #facData.AssignedHeroUUIDs < maxWorkers then
			table.insert(facData.AssignedHeroUUIDs, heroUUID)
		end
	else
		return false, "Unknown assignment target"
	end

	DataManager.SyncProfile(player)
	return true, string.format("Assigned %s -> %s", hero.DisplayName, hero.Assignment)
end

--============================================================================

-- END ACTUAL EXTRACTED ASSIGNMENT BLOCK
local success, message = AssignHeroRoleFunc.OnServerInvoke(player, 'A', 'SQUAD_AUTO')
assert(success == false)
assert(hero.Assignment == 'FACILITY_INFIRMARY')
assert(#profile.Facilities.Infirmary.AssignedHeroUUIDs == 0)
print('PASS: rejected SQUAD_AUTO removes existing infirmary worker index while preserving assignment: ' .. message)
end
print('All 7 isolated review reproductions passed. These are bug reproductions, not successful gameplay acceptance checks.')