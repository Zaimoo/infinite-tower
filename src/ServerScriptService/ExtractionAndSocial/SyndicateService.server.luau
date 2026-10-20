--!strict
-- ServerScriptService/ExtractionAndSocial/SyndicateService.server.luau
-- Waiting Room Espionage (Bless vs Leech + 15s Purge + Mimic Chest Illusion)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StatFormulas = require(Shared:WaitForChild("Util"):WaitForChild("StatFormulas"))

local SyndicateRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SyndicateRemotes")
local PlotEspionageEvent = SyndicateRemotes:WaitForChild("PlotEspionage") :: RemoteEvent

local PlotsFolder = Workspace:WaitForChild("WaitingRoomPlots")

local function getDataManager(): any
	while not _G.DataManager do
		task.wait(0.05)
	end
	return _G.DataManager
end

local SyndicateService = {}

--============================================================================
-- WAITING ROOM ESPIONAGE (BLESS VS LEECH, 15s PURGE & MIMIC CHEST)
--============================================================================

PlotEspionageEvent.OnServerEvent:Connect(function(player: Player, opCode: any, plotIndex: any, facilityKey: any)
	local dm = getDataManager()
	local profile = dm.GetProfile(player)
	if not profile or type(opCode) ~= "number" then
		return
	end

	local facName = (type(facilityKey) == "string" and (facilityKey == "ManaConduit" or facilityKey == "Infirmary" or facilityKey == "DimensionalLab"))
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

_G.SyndicateService = SyndicateService
