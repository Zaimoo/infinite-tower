--!strict
-- ReplicatedStorage/Shared/Util/InventoryCapacity.luau
-- Hero and artifact backpack caps (GDD §Inventory caps). Both start at StatBalance's base of 50 and
-- grow by 25 per Storage node in the Fortress Tree (nodes alternate heroes, artifacts, heroes...).
-- Heroes assigned to a support facility live in that facility, not the backpack: they are left out
-- of the hero count and the backpack/squad lists until they are unassigned.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StatBalance = require(ReplicatedStorage.Shared.Config.StatBalance)
local Config = require(ReplicatedStorage.Shared.Config.FortressTreeConfig)
local FortressTree = require(ReplicatedStorage.Shared.Util.FortressTree)

local InventoryCapacity = {}

-- Storage levels owned that raised the hero cap (odd levels) and the artifact cap (even levels).
local function split(tree: FortressTree.Tree?): (number, number)
	local level = FortressTree.FacilityLevel(tree, Config.StorageFacility)
	return math.ceil(level / 2), math.floor(level / 2)
end

function InventoryCapacity.HeroCap(tree: FortressTree.Tree?): number
	local heroNodes = split(tree)
	return StatBalance.MaxHeroInventory + heroNodes * Config.StorageStep
end

function InventoryCapacity.ArtifactCap(tree: FortressTree.Tree?): number
	local _, artifactNodes = split(tree)
	return StatBalance.MaxArtifactInventory + artifactNodes * Config.StorageStep
end

-- True while the hero works in a support facility (Assignment "FACILITY_*").
function InventoryCapacity.IsInFacility(hero: any): boolean
	return type(hero) == "table" and type(hero.Assignment) == "string" and string.sub(hero.Assignment, 1, 9) == "FACILITY_"
end

-- Heroes in the backpack: every owned hero except the ones working in a facility.
function InventoryCapacity.HeroCount(profile: any): number
	local count = 0
	for _, hero in (profile and profile.Heroes) or {} do
		if not InventoryCapacity.IsInFacility(hero) then count += 1 end
	end
	return count
end

function InventoryCapacity.ArtifactCount(profile: any): number
	local count = 0
	for _ in (profile and profile.Artifacts) or {} do count += 1 end
	return count
end

return table.freeze(InventoryCapacity)
