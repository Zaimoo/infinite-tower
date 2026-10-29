--!strict
-- ReplicatedStorage/Shared/Util/FortressTree.luau
-- Pure rules for the Fortress Development Tree (Phase 4 §5). The server is the only writer of
-- profile.FortressTree; the client uses the same checks to draw owned, buyable and locked nodes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.FortressTreeConfig)

export type Tree = { Nodes: { [string]: boolean } }
export type Perks = {
	OfflineMinutes: number,
	GuardPostRate: number,
	MarketWorkers: number,
	MarketBonus: number,
	TrainingWorkers: number,
	TrainingBonus: number,
	BlessingWorkers: number,
	BlessingLuck: number,
}

local FortressTree = {}

function FortressTree.DefaultTree(): Tree
	local owned = {}
	for _, node in Config.Nodes do
		if node.Default then
			owned[node.Id] = true
		end
	end
	return { Nodes = owned }
end

function FortressTree.Owns(tree: Tree?, nodeId: string): boolean
	return tree ~= nil and type(tree.Nodes) == "table" and tree.Nodes[nodeId] == true
end

-- Level = consecutive LEVEL nodes owned from level 1, so a hole in a bad save can't skip levels.
function FortressTree.FacilityLevel(tree: Tree?, facility: string): number
	local levels: { [number]: string } = {}
	for _, node in Config.Nodes do
		if node.Kind == "LEVEL" and node.Facility == facility and node.Level then
			levels[node.Level] = node.Id
		end
	end
	local level = 0
	while levels[level + 1] and FortressTree.Owns(tree, levels[level + 1]) do
		level += 1
	end
	return level
end

-- Open squad slots: the base slot plus one per Command level owned.
function FortressTree.SquadSlots(tree: Tree?): number
	return math.min(Config.MaxSquadSlots, Config.BaseSquadSlots + FortressTree.FacilityLevel(tree, "Squad"))
end

function FortressTree.PerkBonuses(tree: Tree?): Perks
	local perks: Perks = {
		OfflineMinutes = 0,
		GuardPostRate = 0,
		MarketWorkers = 0,
		MarketBonus = 0,
		TrainingWorkers = 0,
		TrainingBonus = 0,
		BlessingWorkers = 0,
		BlessingLuck = 0,
	}
	for _, node in Config.Nodes do
		local perk = node.Perk
		if perk and FortressTree.Owns(tree, node.Id) then
			(perks :: any)[perk.Key] += perk.Value
		end
	end
	return perks
end

-- Why a node's onboarding system is still closed, keyed by the node's System.
local SYSTEM_HINTS: { [string]: string } = {
	FortressTree = "Upgrades unlock after you upgrade a weapon at the Forge.",
	Squad = "Summon your first hero to unlock squad slots.",
}

-- `gold`, `highestClearedFloor` and `unlocks` (profile.Unlocks) come from the profile. Each node
-- needs its own onboarding system: "FortressTree" unless the node names another (squad slots).
function FortressTree.CanUnlock(tree: Tree?, nodeId: any, gold: number, highestClearedFloor: number, unlocks: { [string]: boolean }?): (boolean, string?)
	if type(nodeId) ~= "string" then
		return false, "Unknown node."
	end
	local node = Config.ById[nodeId]
	if not node then
		return false, "Unknown node."
	end
	local system = node.System or "FortressTree"
	if not (unlocks and unlocks[system]) then
		return false, SYSTEM_HINTS[system] or "This part of the tree is still locked."
	end
	if FortressTree.Owns(tree, nodeId) then
		return false, node.Name .. " is already built."
	end
	for _, required in node.Requires do
		if not FortressTree.Owns(tree, required) then
			local previous = Config.ById[required]
			return false, "Requires " .. (if previous then previous.Name else required) .. " first."
		end
	end
	if highestClearedFloor < node.FloorGate then
		return false, string.format("Clear Floor %d of the Tower first.", node.FloorGate)
	end
	if gold < node.Gold then
		return false, string.format("Need %d Gold for %s.", node.Gold, node.Name)
	end
	return true, nil
end

-- Save migration: grant the LEVEL nodes matching facility levels the player already bought, and
-- enough Command nodes to keep every squad slot a saved hero occupies. Perks are never granted.
-- The Guard Post always keeps its default level 1 node.
function FortressTree.NodesFromFacilityLevels(facilities: any, highestSquadSlot: number?): Tree
	local tree = FortressTree.DefaultTree()
	for _, node in Config.Nodes do
		if node.Kind == "LEVEL" and node.Facility and node.Level then
			local data = type(facilities) == "table" and facilities[node.Facility]
			local saved = if node.Facility == "Squad" then (highestSquadSlot or 0) - Config.BaseSquadSlots
				elseif type(data) == "table" and type(data.Level) == "number" then data.Level
				else 0
			if node.Level <= saved then
				tree.Nodes[node.Id] = true
			end
		end
	end
	return tree
end

return table.freeze(FortressTree)
