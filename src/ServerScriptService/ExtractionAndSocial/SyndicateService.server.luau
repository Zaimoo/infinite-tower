--!strict
-- ServerScriptService/ExtractionAndSocial/SyndicateService.server.luau
-- Waiting Room Espionage (Bless vs Leech + 15s Purge)

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
local PlayerEspionageCooldowns: { [number]: { [number]: number } } = {} -- [callerUserId][targetUserId] = expiresAt

--============================================================================
-- WAITING ROOM ESPIONAGE (BLESS VS LEECH & 15s PURGE)
--============================================================================

PlotEspionageEvent.OnServerEvent:Connect(function(player: Player, opCode: any, plotIndex: any, facilityKey: any)
	local dm = getDataManager()
	local profile = dm.GetProfile(player)
	if not profile or type(opCode) ~= "number" then
		return
	end

	local facName = "GuardPost" -- the one support facility every plot has (the Infirmary was removed)

	if opCode == 2 or opCode == 3 then
		-- 2 = COMPLETE_BLESS (+25% output, +25 Gems)
		-- 3 = COMPLETE_LEECH (-20% stolen output for 3m)
		if type(plotIndex) ~= "number" then return end
		local targetOwner = _G.PlotManager and _G.PlotManager.GetPlotOwner(plotIndex)
		if not targetOwner or targetOwner == player then
			-- Reject self-targeting or invalid plot owner
			return
		end

		local plotModel = PlotsFolder:FindFirstChild("Plot_" .. tostring(plotIndex)) :: Model?
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local island = plotModel and plotModel:FindFirstChild("FloatingFortressIsland")
		local surface = island and island:FindFirstChild("IslandTopSurface") :: BasePart?
		local plotPos = surface and surface.Position or (plotModel and plotModel:FindFirstChild("PlotSpawn") and (plotModel.PlotSpawn :: BasePart).Position)
		if not hrp or not plotPos or (hrp.Position - plotPos).Magnitude > 95 then
			return
		end

		local nowUnix = os.time()
		local callerCooldowns = PlayerEspionageCooldowns[player.UserId]
		if not callerCooldowns then
			callerCooldowns = {}
			PlayerEspionageCooldowns[player.UserId] = callerCooldowns
		end
		if callerCooldowns[targetOwner.UserId] and nowUnix < callerCooldowns[targetOwner.UserId] then
			dm.SendToast(player, "You must wait before channeling another rune on this player's plot!", "WARN")
			return
		end
		callerCooldowns[targetOwner.UserId] = nowUnix + 60

		local targetProf = dm.GetProfile(targetOwner)
		if not targetProf then return end
		local facData = (targetProf.Facilities :: any)[facName]
		if not facData then
			return
		end

		facData.LastRuneTimestamp = nowUnix

		if opCode == 2 then
			-- Cooperative Blessing
			facData.BlessedUntil = nowUnix + 180
			facData.LastRuneWasLeech = false
			local bonusGems = 25
			profile.Currencies.Gems += bonusGems
			dm.SendToast(player, string.format("✨ Blessed %s (+25%% Output for 3m)! Earned +%d Gems!", facName, bonusGems), "SUCCESS")
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
					dm.SendToast(thief, "⚡ LEECH RUNE PURGED! You were stunned for 3.0s and dropped a Bounty Bag!", "WARN")
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

_G.SyndicateService = SyndicateService
