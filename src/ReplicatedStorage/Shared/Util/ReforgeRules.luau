--!strict
-- ReplicatedStorage/Shared/Util/ReforgeRules.luau
-- Pure rules for the Weapon Reforge (GDD §7.6). No Roblox services, so specs run it directly; the server
-- (Core/ReforgeService) adds the remote, the rate limit and the random numbers.
--
-- Save shape (all optional, repaired by EnsureState):
--   artifact.Enchantment   = { Id = "KEEN" | "VIGOR" | "SWIFT" | "FOCUS", Grade = 1..6 }
--   profile.Reforge  = { Pity = rolls since the last Epic or better, Rolls = lifetime rolls,
--                        Pending = { UUID = artifact id, Enchantment = { Id, Grade } }? }
-- A roll charges its Gold at once and parks the result in Pending; Choose then keeps it or the old enchantment.
-- Pending is saved, so a disconnect never loses a paid roll.
local Config = require(script.Parent.Parent.Config.ReforgeConfig)
local B = require(script.Parent.Parent.Config.StatBalance)

local Rules = {}

local GRADE_COUNT = #Config.Grades

function Rules.IsEnchantment(enchantment: any): boolean
	return type(enchantment) == "table" and type(enchantment.Id) == "string" and Config.Enchantments[enchantment.Id] ~= nil
		and B.Integer(enchantment.Grade, 1, GRADE_COUNT)
end

-- The enchantment's bonus in percent (0 when there is none).
function Rules.Value(enchantment: any): number
	if not Rules.IsEnchantment(enchantment) then return 0 end
	return Config.Enchantments[enchantment.Id].Values[enchantment.Grade]
end

-- "Keen · Epic: +9% damage", or "No enchantment".
function Rules.Describe(enchantment: any): string
	if not Rules.IsEnchantment(enchantment) then return "No enchantment" end
	local def = Config.Enchantments[enchantment.Id]
	return string.format("%s · %s: " .. def.Summary, def.Name, Config.Grades[enchantment.Grade].Name, def.Values[enchantment.Grade])
end

-- What a weapon's enchantment does to its hero: ATK and HP multipliers, attack speed added to the weapon's speed
-- bonus, and the Skill Gauge charge multiplier. All 1 / 0 for a weapon without an enchantment.
function Rules.Bonuses(artifact: any): (number, number, number, number)
	local enchantment = type(artifact) == "table" and artifact.Enchantment or nil
	if not Rules.IsEnchantment(enchantment) then return 1, 1, 0, 1 end
	local v = Rules.Value(enchantment) / 100
	if enchantment.Id == "KEEN" then return 1 + v, 1, 0, 1 end
	if enchantment.Id == "VIGOR" then return 1, 1 + v, 0, 1 end
	if enchantment.Id == "SWIFT" then return 1, 1, v, 1 end
	return 1, 1, 0, 1 + v -- FOCUS
end

function Rules.GaugeMultiplier(artifact: any): number
	local _, _, _, gauge = Rules.Bonuses(artifact)
	return gauge
end

-- Gold for one roll on this weapon.
function Rules.Cost(artifact: any): number
	if type(artifact) ~= "table" then return 0 end
	local star = if B.Integer(artifact.Star, 1, 7) then artifact.Star else 1
	return math.round(Config.BaseRollGold * B.RarityGoldFactor(artifact.Rarity) * (1 + Config.StarCostStep * (star - 1)))
end

-- Each grade's chance per roll (0..1), without pity. For the odds window.
function Rules.GradeChances(): { number }
	local total = 0
	for _, grade in Config.Grades do total += grade.Weight end
	local chances = {}
	for i, grade in Config.Grades do chances[i] = grade.Weight / total end
	return chances
end

-- True when the next roll is guaranteed PityGrade or better.
function Rules.PityReady(pity: number): boolean
	return pity + 1 >= Config.PityRolls
end

-- Picks a grade from a uniform roll in [0, 1). With pity ready, only PityGrade and better can come up,
-- in their usual proportions.
function Rules.RollGrade(roll: number, pity: number): number
	local first = if Rules.PityReady(pity) then Config.PityGrade else 1
	local total = 0
	for i = first, GRADE_COUNT do total += Config.Grades[i].Weight end
	local point = math.clamp(roll, 0, 0.999999) * total
	for i = first, GRADE_COUNT do
		point -= Config.Grades[i].Weight
		if point < 0 then return i end
	end
	return GRADE_COUNT
end

-- Picks an enchantment id from a uniform roll in [0, 1).
function Rules.RollEnchantmentId(roll: number): string
	local order = Config.EnchantmentOrder
	return order[math.clamp(math.floor(roll * #order) + 1, 1, #order)]
end

-- Adds profile.Reforge (old saves) and drops damaged enchantments and pending rolls.
function Rules.EnsureState(profile: any)
	if type(profile) ~= "table" then return end
	local state = profile.Reforge
	if type(state) ~= "table" then
		state = {}
		profile.Reforge = state
	end
	state.Pity = if B.Integer(state.Pity, 0, 1e9) then state.Pity else 0
	state.Rolls = if B.Integer(state.Rolls, 0, 1e12) then state.Rolls else 0
	local pending = state.Pending
	if pending ~= nil and (type(pending) ~= "table" or type(pending.UUID) ~= "string" or not Rules.IsEnchantment(pending.Enchantment)
		or type(profile.Artifacts) ~= "table" or profile.Artifacts[pending.UUID] == nil) then
		state.Pending = nil
	end
	for _, artifact in profile.Artifacts or {} do
		if type(artifact) == "table" and artifact.Enchantment ~= nil and not Rules.IsEnchantment(artifact.Enchantment) then
			artifact.Enchantment = nil
		end
	end
end

local function weaponName(artifact: any): string
	return if type(artifact.DisplayName) == "string" then artifact.DisplayName else "that weapon"
end

-- Charges one roll on `uuid` and parks the result. `enchantmentRoll` and `gradeRoll` are uniform in [0, 1).
-- Rolling again on the weapon that has a pending result discards that result (the old enchantment stays).
-- Returns ok, message, and the pending enchantment.
function Rules.Roll(profile: any, uuid: any, enchantmentRoll: number, gradeRoll: number): (boolean, string, any?)
	if type(profile) ~= "table" or type(uuid) ~= "string" or #uuid == 0 or #uuid > 64 then return false, "Choose a weapon.", nil end
	Rules.EnsureState(profile)
	local artifact = profile.Artifacts and profile.Artifacts[uuid]
	if type(artifact) ~= "table" then return false, "That weapon is not in your Backpack.", nil end
	local state = profile.Reforge
	local pending = state.Pending
	if pending and pending.UUID ~= uuid then
		local other = profile.Artifacts[pending.UUID]
		return false, string.format("Keep or discard your last roll on %s first.", if other then weaponName(other) else "another weapon"), nil
	end
	local cost = Rules.Cost(artifact)
	local currencies = profile.Currencies
	if type(currencies) ~= "table" or not B.Finite(currencies.Gold) or currencies.Gold < cost then
		return false, "Not enough Gold.", nil
	end
	-- Every check is done; nothing below can fail or yield.
	currencies.Gold -= cost
	local grade = Rules.RollGrade(gradeRoll, state.Pity)
	state.Pity = if grade >= Config.PityGrade then 0 else state.Pity + 1
	state.Rolls += 1
	local enchantment = { Id = Rules.RollEnchantmentId(enchantmentRoll), Grade = grade }
	state.Pending = { UUID = uuid, Enchantment = enchantment }
	return true, Rules.Describe(enchantment), table.clone(enchantment)
end

-- Keeps the pending roll on `uuid` (keepNew) or the weapon's old enchantment, and clears the pending roll.
function Rules.Choose(profile: any, uuid: any, keepNew: any): (boolean, string)
	if type(profile) ~= "table" or type(uuid) ~= "string" or type(keepNew) ~= "boolean" then return false, "Invalid choice." end
	Rules.EnsureState(profile)
	local state = profile.Reforge
	local pending = state.Pending
	if not pending or pending.UUID ~= uuid then return false, "There is no roll to keep on that weapon." end
	local artifact = profile.Artifacts[uuid]
	state.Pending = nil
	if type(artifact) ~= "table" then return false, "That weapon is no longer in your Backpack." end
	if keepNew then
		artifact.Enchantment = { Id = pending.Enchantment.Id, Grade = pending.Enchantment.Grade }
		return true, "Kept " .. Rules.Describe(artifact.Enchantment)
	end
	return true, if Rules.IsEnchantment(artifact.Enchantment) then "Kept " .. Rules.Describe(artifact.Enchantment) else "Roll discarded."
end

return table.freeze(Rules)
