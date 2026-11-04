--!strict
-- Pure rules for affixed Elites (Phase F). No Roblox services, so specs can run it directly.
-- Affixes are a chance summon: each time a camp Elite spawns it may emerge AFFIXED. An affixed Elite
-- carries 1 affix (2 from biome 7), is announced to the floor, and pays out far more: its relic drop
-- chance is multiplied by RelicDropMultiplier (Abyssal Cores stay Elite-only) and its Gold by
-- GoldMultiplier. Kill points are unchanged.
local AffixRules = {}

export type Affix = {
	Id: string,
	Name: string, -- name plate prefix
	Text: string, -- what it does, for the GDD and tooltips
}

AffixRules.Affixes = table.freeze({
	table.freeze({ Id = "SHIELDED", Name = "Shielded", Text = "Starts with a shield of 30% MaxHP that returns after 6 s without being hit" }),
	table.freeze({ Id = "HASTED", Name = "Hasted", Text = "+35% move speed, attack cooldowns 25% shorter" }),
	table.freeze({ Id = "VAMPIRIC", Name = "Vampiric", Text = "Heals 35% of the damage it deals" }),
	table.freeze({ Id = "FRENZIED", Name = "Frenzied", Text = "Below 50% HP: +40% ATK and cooldowns 20% shorter" }),
	table.freeze({ Id = "SPLITTING", Name = "Splitting", Text = "On death, two Regulars of its biome step out (they never respawn and give no kill progress)" }),
	table.freeze({ Id = "WARDED", Name = "Warded", Text = "Allies within 18 studs take 25% less damage" }),
	table.freeze({ Id = "COMMANDER", Name = "Commanding", Text = "Allies within 20 studs deal +20% damage" }),
}) :: { Affix }

AffixRules.RelicDropMultiplier = 4 -- an affixed Elite's relic drop chance, x4 (capped at a certain drop)
AffixRules.GoldMultiplier = 1.5
AffixRules.ShieldFraction = 0.3
AffixRules.ShieldRegenSeconds = 6
AffixRules.HasteSpeed = 1.35
AffixRules.HasteCooldown = 0.75
AffixRules.VampiricFraction = 0.35
AffixRules.FrenzyThreshold = 0.5
AffixRules.FrenzyAtk = 1.4
AffixRules.FrenzyCooldown = 0.8
AffixRules.SplitCount = 2
AffixRules.WardRadius = 18
AffixRules.WardReduction = 0.25
AffixRules.CommandRadius = 20
AffixRules.CommandBonus = 0.2

-- Pairs that never roll together (two damage-soak affixes would be a wall).
local BANNED = { SHIELDED_WARDED = true, WARDED_SHIELDED = true }

-- Chance that a camp Elite spawns affixed: 10% in biome 1, rising 1.5% a biome to 23.5% in biome 10.
function AffixRules.SpawnChance(biomeIndex: number): number
	return 0.10 + 0.015 * (math.clamp(biomeIndex, 1, 10) - 1)
end

function AffixRules.AffixCount(biomeIndex: number): number
	return if biomeIndex >= 7 then 2 else 1
end

-- Rolls whether an Elite spawns affixed and, if so, which affixes. `rng` returns [0, 1). `force`
-- (Calamity Hour, Phase G) skips the chance. Returns an empty list for a plain Elite.
function AffixRules.Roll(rng: () -> number, biomeIndex: number, force: boolean?): { string }
	if not force and rng() >= AffixRules.SpawnChance(biomeIndex) then
		return {}
	end
	local chosen: { string } = {}
	local wanted = AffixRules.AffixCount(biomeIndex)
	for _ = 1, 40 do
		if #chosen >= wanted then break end
		local affix = AffixRules.Affixes[math.min(#AffixRules.Affixes, math.floor(rng() * #AffixRules.Affixes) + 1)]
		local ok = not table.find(chosen, affix.Id)
		for _, other in chosen do
			if BANNED[affix.Id .. "_" .. other] then ok = false end
		end
		if ok then table.insert(chosen, affix.Id) end
	end
	return chosen
end

function AffixRules.Has(mob: any, id: string): boolean
	return mob.Affixes ~= nil and table.find(mob.Affixes, id) ~= nil
end

function AffixRules.IsAffixed(mob: any): boolean
	return mob.Affixes ~= nil and #mob.Affixes > 0
end

-- "Frenzied, Hasted Glacier Knight".
function AffixRules.DisplayName(baseName: string, affixes: { string }): string
	if #affixes == 0 then return baseName end
	local names = {}
	for _, id in affixes do
		for _, affix in AffixRules.Affixes do
			if affix.Id == id then table.insert(names, affix.Name) end
		end
	end
	return table.concat(names, ", ") .. " " .. baseName
end

-- Sets up a freshly spawned mob's affix state (shield). Clears it for a plain mob.
function AffixRules.Prepare(mob: any, affixes: { string }, now: number)
	mob.Affixes = if #affixes > 0 then affixes else nil
	mob.AffixShieldMax = if AffixRules.Has(mob, "SHIELDED") then math.round(mob.MaxHP * AffixRules.ShieldFraction) else nil
	mob.AffixShield = mob.AffixShieldMax
	mob.LastHitAt = now
end

-- Regrows a SHIELDED Elite's shield after ShieldRegenSeconds without being hit.
function AffixRules.Regen(mob: any, now: number)
	if mob.AffixShieldMax and (mob.AffixShield or 0) < mob.AffixShieldMax and now - (mob.LastHitAt or now) >= AffixRules.ShieldRegenSeconds then
		mob.AffixShield = mob.AffixShieldMax
	end
end

-- Damage left after a SHIELDED Elite's own shield. Mutates the shield and the last-hit time.
function AffixRules.Absorb(mob: any, damage: number, now: number): number
	mob.LastHitAt = now
	local shield = mob.AffixShield or 0
	if shield <= 0 then return damage end
	local soaked = math.min(shield, damage)
	mob.AffixShield = shield - soaked
	return damage - soaked
end

function AffixRules.SpeedMultiplier(mob: any): number
	return if AffixRules.Has(mob, "HASTED") then AffixRules.HasteSpeed else 1
end

function AffixRules.CooldownMultiplier(mob: any): number
	local m = 1
	if AffixRules.Has(mob, "HASTED") then m *= AffixRules.HasteCooldown end
	if AffixRules.Has(mob, "FRENZIED") and mob.CurrentHP <= mob.MaxHP * AffixRules.FrenzyThreshold then m *= AffixRules.FrenzyCooldown end
	return m
end

-- The mob's own outgoing damage multiplier (FRENZIED). Auras come from AuraAtk.
function AffixRules.AtkMultiplier(mob: any): number
	return if AffixRules.Has(mob, "FRENZIED") and mob.CurrentHP <= mob.MaxHP * AffixRules.FrenzyThreshold then AffixRules.FrenzyAtk else 1
end

type Point = { X: number, Z: number }
local function near(a: Point, b: Point, radius: number): boolean
	local dx, dz = a.X - b.X, a.Z - b.Z
	return dx * dx + dz * dz <= radius * radius
end

-- Damage multiplier from COMMANDER auras of `others` (living Elites on the floor) around `mob`.
function AffixRules.AuraAtk(mob: any, others: { any }): number
	for _, o in others do
		if o ~= mob and AffixRules.Has(o, "COMMANDER") and near(o.Position, mob.Position, AffixRules.CommandRadius) then
			return 1 + AffixRules.CommandBonus
		end
	end
	return 1
end

-- Incoming damage multiplier from WARDED auras of `others` around `mob` (a WARDED Elite does not ward itself).
function AffixRules.AuraDefense(mob: any, others: { any }): number
	for _, o in others do
		if o ~= mob and AffixRules.Has(o, "WARDED") and near(o.Position, mob.Position, AffixRules.WardRadius) then
			return 1 - AffixRules.WardReduction
		end
	end
	return 1
end

-- The relic drop roll to pass to TowerFloorConfig.RollRelic: dividing the uniform roll by the
-- multiplier multiplies the drop chance by it (capped at a certain drop).
function AffixRules.DropRoll(mob: any, roll: number): number
	return if AffixRules.IsAffixed(mob) then roll / AffixRules.RelicDropMultiplier else roll
end

function AffixRules.GoldMultiplierFor(mob: any): number
	return if AffixRules.IsAffixed(mob) then AffixRules.GoldMultiplier else 1
end

return table.freeze(AffixRules)
