--!strict
-- ReplicatedStorage/Shared/Util/ForgeRollRules.luau
-- Pure, deterministic rules for the Open Forge pedestal rolling & relic-scaled purchase system.
-- Contains no Roblox service yields so unit tests exercise exact production logic in the Luau CLI.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArtifactCatalog = require(ReplicatedStorage.Shared.Config.ArtifactCatalog)
local StatBalance = require(ReplicatedStorage.Shared.Config.StatBalance)
local FortressTree = require(ReplicatedStorage.Shared.Util.FortressTree)
local InventoryCapacity = require(ReplicatedStorage.Shared.Util.InventoryCapacity)
local RollLuck = require(ReplicatedStorage.Shared.Util.RollLuck)

export type State = {
	Slots: { [string]: string }, -- "1".."6" -> TemplateId (string keys avoid sparse JSON array holes)
	MinRarity: number, -- 1..7 Auto-Roll stop threshold
	WeaponType: string, -- "ANY" or WeaponType
	Initialized: boolean?, -- true once starter pedestals have been rolled (bought slots stay empty until reroll)
}

local VALID_TYPES: { [string]: boolean } = { ANY = true }
for _, wt in ipairs(ArtifactCatalog.ArchetypeTypes) do
	VALID_TYPES[wt] = true
end

local ForgeRollRules = {}

function ForgeRollRules.SlotKey(slotIndex: number): string
	return tostring(math.floor(slotIndex))
end

function ForgeRollRules.NewState(): State
	return {
		Slots = {},
		MinRarity = 3,
		WeaponType = "ANY",
		Initialized = false,
	}
end

function ForgeRollRules.EnsureState(profile: any): State
	local raw = type(profile) == "table" and profile.ForgeRoll
	if type(raw) ~= "table" then
		local fresh = ForgeRollRules.NewState()
		if type(profile) == "table" then
			profile.ForgeRoll = fresh
		end
		return fresh
	end

	local cleanSlots: { [string]: string } = {}
	if type(raw.Slots) == "table" then
		for k, v in pairs(raw.Slots) do
			local idx = tonumber(k)
			if idx and idx >= 1 and idx <= 6 and idx % 1 == 0 and type(v) == "string" and ArtifactCatalog.Seeds[v] ~= nil then
				cleanSlots[tostring(idx)] = v
			end
		end
	end
	raw.Slots = cleanSlots

	local minR = tonumber(raw.MinRarity)
	raw.MinRarity = if minR and minR == minR then math.clamp(math.floor(minR), 1, 7) else 3
	raw.WeaponType = if type(raw.WeaponType) == "string" and VALID_TYPES[raw.WeaponType] then raw.WeaponType else "ANY"
	if type(raw.Initialized) ~= "boolean" then
		raw.Initialized = next(cleanSlots) ~= nil
	end
	return raw :: State
end

function ForgeRollRules.SanitizeFilter(minRarity: any, weaponType: any): (number?, string?)
	local outRarity: number? = nil
	local outType: string? = nil
	if minRarity ~= nil then
		if type(minRarity) == "number" and minRarity == minRarity and minRarity >= 1 and minRarity <= 7 and minRarity % 1 == 0 then
			outRarity = minRarity
		else
			return nil, nil
		end
	end
	if weaponType ~= nil then
		if type(weaponType) == "string" and VALID_TYPES[weaponType] then
			outType = weaponType
		else
			return nil, nil
		end
	end
	return outRarity, outType
end

local function pickSeed(rates: { number }, rand: () -> number, forcedType: string?, capTier: number?): ArtifactCatalog.ArtifactSeed
	local tier = RollLuck.Roll(rates, rand())
	if capTier then
		tier = math.min(tier, capTier)
	end
	local types = ArtifactCatalog.ArchetypeTypes
	local chosenType: ArtifactCatalog.WeaponType = if forcedType and VALID_TYPES[forcedType] and forcedType ~= "ANY"
		then (forcedType :: ArtifactCatalog.WeaponType)
		else types[math.clamp(math.floor(rand() * #types) + 1, 1, #types)]

	local stdSeed, enhSeed = ArtifactCatalog.GetTierPair(tier, chosenType)
	local chosen = if rand() <= 0.60 then (stdSeed or enhSeed) else (enhSeed or stdSeed)
	assert(chosen, string.format("Missing artifact seed for tier %d %s", tier, chosenType))
	return chosen
end

-- Rerolls ALL unlocked pedestals (`1..PedestalCount`), clearing any previous unbought slots.
function ForgeRollRules.RollAll(profile: any, rng: (() -> number)?, guidedWeaponType: string?): { [number]: string }
	local state = ForgeRollRules.EnsureState(profile)
	local rand = rng or math.random
	local pedestalCount = FortressTree.ForgePedestals(profile.FortressTree)
	local luck = FortressTree.RollLuck(profile.FortressTree)
	local rates = RollLuck.ApplyLuck(ArtifactCatalog.RollRates, luck)

	local newSlots: { [string]: string } = {}
	local byIndex: { [number]: string } = {}
	for slot = 1, pedestalCount do
		-- First onboarding roll guarantees an affordable (Common/Uncommon) weapon matching the starter hero.
		local seed = if slot == 1 and guidedWeaponType
			then pickSeed(rates, rand, guidedWeaponType, 2)
			else pickSeed(rates, rand, nil, nil)
		newSlots[tostring(slot)] = seed.TemplateId
		byIndex[slot] = seed.TemplateId
	end
	state.Slots = newSlots
	state.Initialized = true
	return byIndex
end

-- Populates a single unlocked pedestal if it is empty (used when unlocking a brand-new pedestal slot).
-- Never refills other previously bought/empty pedestals.
function ForgeRollRules.PopulateSlot(profile: any, slotIndex: number, rng: (() -> number)?): boolean
	local state = ForgeRollRules.EnsureState(profile)
	local pedestalCount = FortressTree.ForgePedestals(profile.FortressTree)
	if slotIndex < 1 or slotIndex > pedestalCount then
		return false
	end
	local key = tostring(math.floor(slotIndex))
	if state.Slots[key] ~= nil then
		return false
	end
	local rand = rng or math.random
	local luck = FortressTree.RollLuck(profile.FortressTree)
	local rates = RollLuck.ApplyLuck(ArtifactCatalog.RollRates, luck)
	local seed = pickSeed(rates, rand, nil, nil)
	state.Slots[key] = seed.TemplateId
	state.Initialized = true
	return true
end

-- Performs the one-time initial starter roll on a brand-new ForgeRoll state.
-- Once Initialized is true, bought/empty pedestals remain empty until the player explicitly rerolls!
function ForgeRollRules.EnsureUnlockedPopulated(profile: any, rng: (() -> number)?, guidedWeaponType: string?): boolean
	local state = ForgeRollRules.EnsureState(profile)
	if state.Initialized then
		return false
	end
	ForgeRollRules.RollAll(profile, rng, guidedWeaponType)
	return true
end

function ForgeRollRules.MatchesFilter(state: State, templateId: string?): boolean
	if type(templateId) ~= "string" or templateId == "" then
		return false
	end
	local seed = ArtifactCatalog.Seeds[templateId]
	if not seed then
		return false
	end
	if (seed.RarityTier or 1) < (state.MinRarity or 3) then
		return false
	end
	if state.WeaponType ~= "ANY" and seed.Type ~= state.WeaponType then
		return false
	end
	return true
end

function ForgeRollRules.MatchingSlots(profile: any): { number }
	local state = ForgeRollRules.EnsureState(profile)
	local pedestalCount = FortressTree.ForgePedestals(profile.FortressTree)
	local matched: { number } = {}
	for slot = 1, pedestalCount do
		if ForgeRollRules.MatchesFilter(state, state.Slots[tostring(slot)]) then
			table.insert(matched, slot)
		end
	end
	return matched
end

function ForgeRollRules.ValidatePurchase(profile: any, slotIndex: any): (boolean, string?, ArtifactCatalog.ArtifactSeed?, number?)
	if type(profile) ~= "table" then
		return false, "Profile not loaded", nil, nil
	end
	if type(slotIndex) ~= "number" or slotIndex ~= slotIndex or slotIndex % 1 ~= 0 or slotIndex < 1 or slotIndex > 6 then
		return false, "Invalid pedestal", nil, nil
	end
	local pedestalCount = FortressTree.ForgePedestals(profile.FortressTree)
	if slotIndex > pedestalCount then
		return false, "Pedestal not unlocked yet", nil, nil
	end

	local state = ForgeRollRules.EnsureState(profile)
	local templateId = state.Slots[tostring(slotIndex)]
	if not templateId or templateId == "" then
		return false, "This pedestal is empty · Reroll at the Anvil", nil, nil
	end
	local seed = ArtifactCatalog.Seeds[templateId]
	if not seed then
		return false, "Unknown artifact", nil, nil
	end

	local cap = InventoryCapacity.ArtifactCap(profile.FortressTree)
	if InventoryCapacity.ArtifactCount(profile) + 1 > cap then
		return false, string.format("Artifacts full (%d/%d) · Sell or promote to make room", cap, cap), nil, nil
	end

	local cost = ArtifactCatalog.GetPedestalCost(seed)
	local gold = profile.Currencies and profile.Currencies.Gold or 0
	if gold < cost then
		return false, string.format("Need %s Gold (have %s)", StatBalance.Format(cost), StatBalance.Format(gold)), nil, nil
	end

	return true, nil, seed, cost
end

return table.freeze(ForgeRollRules)
