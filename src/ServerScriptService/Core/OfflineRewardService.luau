--!strict
-- ServerScriptService/Core/OfflineRewardService.luau
-- Authoritative Offline Accumulation & Welcome Back Modal Dispatch (GDD Sections 2.4 & 4.3)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FacilityConfig = require(Shared:WaitForChild("Config"):WaitForChild("FacilityConfig"))
local StatFormulas = require(Shared:WaitForChild("Util"):WaitForChild("StatFormulas"))

export type OfflineRewardPayload = {
	OfflineMinutes: number,
	CappedMinutes: number,
	GoldEarned: number,
	RatePerMin: number,
	GuardPostLevel: number,
	BiomeBossTier: number,
}

local OfflineRewardService = {}
local OfflineRewardEvent: RemoteEvent? = nil

local function getRemote(remotesFolder: Instance): RemoteEvent
	if OfflineRewardEvent then return OfflineRewardEvent end
	local tycoonRemotes = remotesFolder:WaitForChild("TycoonGachaRemotes")
	local existing = tycoonRemotes:FindFirstChild("OfflineRewardClaimed") :: RemoteEvent?
	if not existing then
		existing = Instance.new("RemoteEvent")
		existing.Name = "OfflineRewardClaimed"
		existing.Parent = tycoonRemotes
	end
	OfflineRewardEvent = existing
	return existing
end

function OfflineRewardService.ComputeGuardPostLabor(profile: any): number
	local guardPost = profile.Facilities and profile.Facilities.GuardPost
	if not guardPost or not guardPost.AssignedHeroUUIDs then return 0 end
	local sumLabor = 0
	local now = os.time()
	for _, uuid in ipairs(guardPost.AssignedHeroUUIDs) do
		local hero = profile.Heroes and profile.Heroes[uuid]
		if hero and (hero.ComaUntilTimestamp or 0) <= now then
			sumLabor += StatFormulas.GetEffectiveLabor(hero, FacilityConfig.AssignmentTags.GuardPost)
		end
	end
	return sumLabor
end

function OfflineRewardService.ProcessLoginRewards(player: Player, profile: any, dm: any)
	local now = os.time()
	local lastTime = profile.LastLogoutTimestamp or profile.LastActiveTimestamp
	if not lastTime or lastTime <= 0 then
		profile.LastActiveTimestamp = now
		profile.LastLogoutTimestamp = now
		return
	end

	local elapsedSeconds = math.max(0, now - lastTime)
	local elapsedMinutes = math.floor(elapsedSeconds / 60)
	if elapsedMinutes < 1 then
		profile.LastActiveTimestamp = now
		return
	end

	local guardPost = profile.Facilities and profile.Facilities.GuardPost
	local level = guardPost and guardPost.Level or 1
	local sumLabor = OfflineRewardService.ComputeGuardPostLabor(profile)
	local bossTier = profile.HighestClearedBiomeBoss or 0
	local rate = StatFormulas.GetPassiveGoldRate(level, sumLabor, bossTier)
	local gold, cappedMinutes = StatFormulas.CalculateOfflineGold(level, rate, elapsedMinutes)

	profile.LastActiveTimestamp = now
	profile.LastLogoutTimestamp = now

	if gold > 0 then
		profile.Currencies.Gold = (profile.Currencies.Gold or 0) + gold
		local payload: OfflineRewardPayload = {
			OfflineMinutes = elapsedMinutes,
			CappedMinutes = cappedMinutes,
			GoldEarned = gold,
			RatePerMin = rate,
			GuardPostLevel = level,
			BiomeBossTier = bossTier,
		}

		local remotes = ReplicatedStorage:WaitForChild("Remotes")
		local remote = getRemote(remotes)
		task.delay(1.0, function()
			if player.Parent == Players then
				remote:FireClient(player, payload)
				if dm and dm.SendToast then
					dm.SendToast(player, string.format("👑 Welcome Back! Your Adventurers returned with +%d Gold!", gold), "SUCCESS")
				end
			end
		end)
	end
end

function OfflineRewardService.RecordLogout(player: Player, profile: any)
	local now = os.time()
	profile.LastLogoutTimestamp = now
	profile.LastActiveTimestamp = now
end

return OfflineRewardService
