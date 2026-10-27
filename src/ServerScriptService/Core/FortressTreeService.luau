--!strict
-- ServerScriptService/Core/FortressTreeService.luau
-- Server owner of profile.FortressTree (Phase 4 §5.5). The only writer of the support facilities'
-- Facilities[name].Level, which every facility formula still reads.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.FortressTreeConfig)
local FortressTree = require(ReplicatedStorage.Shared.Util.FortressTree)

export type Dependencies = {
	GetProfile: (Player) -> any,
	SendToast: (Player, string, string?) -> (),
	SyncProfile: (Player) -> (),
	IsUnlocked: (Player, string) -> boolean,
	Report: (Player, string) -> (),
	UnlockRemote: RemoteFunction,
}

local FortressTreeService = {}
local deps: Dependencies? = nil
local recentRequests: { [Player]: { number } } = {}

local MAX_REQUESTS_PER_SECOND = 4

local function allowRequest(player: Player): boolean
	local now = os.clock()
	local list = recentRequests[player] or {}
	local kept = {}
	for _, t in list do
		if now - t < 1 then table.insert(kept, t) end
	end
	if #kept >= MAX_REQUESTS_PER_SECOND then
		recentRequests[player] = kept
		return false
	end
	table.insert(kept, now)
	recentRequests[player] = kept
	return true
end

function FortressTreeService.EnsureState(profile: any)
	if type(profile.FortressTree) ~= "table" or type(profile.FortressTree.Nodes) ~= "table" then
		profile.FortressTree = FortressTree.DefaultTree()
	end
	-- Default nodes (root, Frontier Camp) are always owned, even on older saves.
	for _, node in Config.Nodes do
		if node.Default then
			profile.FortressTree.Nodes[node.Id] = true
		end
	end
end

-- Recomputes every gated facility's level from the owned nodes.
function FortressTreeService.ApplyLevels(profile: any)
	FortressTreeService.EnsureState(profile)
	for _, facility in Config.GatedFacilities do
		local data = profile.Facilities and profile.Facilities[facility]
		if data then
			data.Level = FortressTree.FacilityLevel(profile.FortressTree, facility)
		end
	end
end

function FortressTreeService.Unlock(player: Player, nodeId: any): (boolean, string)
	local d = deps
	local profile = d and d.GetProfile(player)
	if not d or not profile then
		return false, "Profile not loaded"
	end
	FortressTreeService.EnsureState(profile)
	local ok, reason = FortressTree.CanUnlock(profile.FortressTree, nodeId, profile.Currencies.Gold or 0,
		profile.HighestClearedFloor or 0, profile.Unlocks)
	if not ok then
		return false, reason or "Cannot unlock that node."
	end
	local node = Config.ById[nodeId :: string]
	profile.Currencies.Gold -= node.Gold
	profile.FortressTree.Nodes[node.Id] = true
	FortressTreeService.ApplyLevels(profile)

	local message = if node.Facility == "Squad"
		then string.format("🚩 %s raised! Squad slot %d is open.", node.Name, FortressTree.SquadSlots(profile.FortressTree))
		elseif node.Kind == "LEVEL" and node.Level == 1
		then string.format("🏗️ %s unlocked! The building rises on your plot.", node.Name)
		elseif node.Kind == "LEVEL" then string.format("🏗️ %s complete!", node.Name)
		else string.format("✨ Perk unlocked: %s", node.Name)
	d.SendToast(player, message, "SUCCESS")
	d.SyncProfile(player)
	d.Report(player, "TreeNodeUnlocked")
	return true, message
end

function FortressTreeService.Init(dependencies: Dependencies)
	deps = dependencies
	dependencies.UnlockRemote.OnServerInvoke = function(player: Player, nodeId: any)
		if not allowRequest(player) then
			return false, "Too many requests. Please wait a moment."
		end
		return FortressTreeService.Unlock(player, nodeId)
	end
end

function FortressTreeService.Forget(player: Player)
	recentRequests[player] = nil
end

return FortressTreeService
