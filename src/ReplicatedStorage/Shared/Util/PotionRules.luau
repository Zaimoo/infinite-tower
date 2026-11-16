--!strict
-- ReplicatedStorage/Shared/Util/PotionRules.luau
-- Pure rules for potions and their timed boosts (GDD §4.9). No Roblox services, so
-- tests/battlepass.spec.luau runs them in the CLI. The server (Core/PotionService) is the only
-- caller that mutates a profile; the client reads Owned / Remaining / Multiplier to draw the
-- Backpack and the summon odds.
--
-- State on the profile:
--   Potions = { [potionId] = count }
--   Boosts  = { [effect] = seconds remaining }   -- counts down only while the player is online

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.PotionConfig)

local PotionRules = {}

local function int(value: any, min: number, max: number): number
	if type(value) ~= "number" or value ~= value then return min end
	return math.clamp(math.floor(value), min, max)
end

-- Creates or repairs profile.Potions and profile.Boosts. Unknown potions and effects are dropped,
-- and every number is clamped, so a damaged save can never give a free or endless boost.
function PotionRules.EnsureState(profile: any)
	local owned = {}
	local savedOwned = if type(profile.Potions) == "table" then profile.Potions else {}
	for id in Config.Potions do
		local count = int(savedOwned[id], 0, Config.MaxOwned)
		if count > 0 then owned[id] = count end
	end
	profile.Potions = owned

	local boosts = {}
	local savedBoosts = if type(profile.Boosts) == "table" then profile.Boosts else {}
	for _, id in Config.Order do
		local effect = Config.Potions[id].Effect
		local seconds = int(savedBoosts[effect], 0, Config.MaxBoostSeconds)
		if seconds > 0 then boosts[effect] = seconds end
	end
	profile.Boosts = boosts
end

function PotionRules.Owned(profile: any, id: string): number
	local owned = profile and profile.Potions
	return if type(owned) == "table" then int(owned[id], 0, Config.MaxOwned) else 0
end

-- Adds potions (rewards). Returns how many were actually added (the rest are over MaxOwned).
function PotionRules.Add(profile: any, id: any, amount: any): number
	if type(id) ~= "string" or not Config.Potions[id] then return 0 end
	local count = int(amount, 0, Config.MaxOwned)
	if count <= 0 then return 0 end
	if type(profile.Potions) ~= "table" then profile.Potions = {} end
	local before = PotionRules.Owned(profile, id)
	local after = math.min(Config.MaxOwned, before + count)
	profile.Potions[id] = after
	return after - before
end

-- Seconds left on a boost (0 when it is off).
function PotionRules.Remaining(profile: any, effect: string): number
	local boosts = profile and profile.Boosts
	return if type(boosts) == "table" then int(boosts[effect], 0, Config.MaxBoostSeconds) else 0
end

-- The bonus an effect gives right now: 0 when its boost is off, else the potion's Amount.
function PotionRules.Bonus(profile: any, effect: string): number
	local potion = Config.ByEffect(effect)
	if not potion or PotionRules.Remaining(profile, effect) <= 0 then return 0 end
	return potion.Amount
end

-- 1 + Bonus, for the multiplied effects (Gold, Gems, HeroXP, PassXP).
function PotionRules.Multiplier(profile: any, effect: string): number
	return 1 + PotionRules.Bonus(profile, effect)
end

-- Drinks one potion: spends it and adds its minutes to the boost. Refused, with nothing spent,
-- when the player owns none or the boost would pass MaxBoostSeconds.
function PotionRules.Use(profile: any, id: any): (boolean, string)
	local potion = if type(id) == "string" then Config.Potions[id] else nil
	if not potion then return false, "Unknown potion." end
	local owned = PotionRules.Owned(profile, potion.Id)
	if owned <= 0 then return false, "You don't have that potion." end
	local remaining = PotionRules.Remaining(profile, potion.Effect)
	local after = remaining + potion.Minutes * 60
	if after > Config.MaxBoostSeconds then
		return false, string.format("That boost is full (%d hours at most).", Config.MaxBoostSeconds // 3600)
	end
	if type(profile.Boosts) ~= "table" then profile.Boosts = {} end
	profile.Potions[potion.Id] = if owned > 1 then owned - 1 else nil
	profile.Boosts[potion.Effect] = after
	return true, if remaining > 0
		then string.format("%s extended by %d min", potion.Summary, potion.Minutes)
		else string.format("%s for %d min", potion.Summary, potion.Minutes)
end

-- Counts every running boost down by `seconds` of play. Returns the effects that just ended.
function PotionRules.Tick(profile: any, seconds: number): { string }
	local expired = {}
	local boosts = profile.Boosts
	if type(boosts) ~= "table" or seconds ~= seconds or seconds <= 0 then return expired end
	for effect, left in boosts do
		local after = (if type(left) == "number" and left == left then left else 0) - seconds
		if after <= 0 then
			boosts[effect] = nil
			table.insert(expired, effect)
		else
			boosts[effect] = after
		end
	end
	table.sort(expired)
	return expired
end

-- True when any boost is running.
function PotionRules.AnyActive(profile: any): boolean
	local boosts = profile and profile.Boosts
	if type(boosts) ~= "table" then return false end
	for _, left in boosts do
		if type(left) == "number" and left > 0 then return true end
	end
	return false
end

return table.freeze(PotionRules)
