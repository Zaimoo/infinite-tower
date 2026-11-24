--!strict
-- ReplicatedStorage/Shared/Config/PotionConfig.luau
-- Potions (GDD §4.9): consumables kept in the Backpack. Drinking one starts a timed boost, or adds
-- its minutes to a boost that is already running. Boost time only counts down while the player is
-- in the game. There is one potion per effect, so a boost never has two strengths to reconcile.
--
-- Effects:
--   Gold    multiplies tower Gold (kills, floor bosses, banked relics); stacks with the Market,
--           the friend boost, affixes, events and climb streaks.
--   Gems    multiplies Gems from kills and banked relics. First-clear bonuses and raid payouts are
--           not affected.
--   Luck    is added to summon luck on the Gem and Gold banners, on top of God's Blessing and its
--           cap. The Robux banners (Gilded Mirror, Gilded Anvil) have no luck and stay that way.
--   HeroXP  multiplies combat XP earned by squad heroes.
--   PassXP  multiplies Battle Pass XP.

export type Effect = "Gold" | "Gems" | "Luck" | "HeroXP" | "PassXP"

export type Potion = {
	Id: string,
	Name: string,
	Effect: Effect,
	Amount: number, -- the bonus: 0.5 is +50%
	Minutes: number,
	Icon: string, -- GrimoireIcons drawing
	Tint: Color3,
	Summary: string, -- short effect line, e.g. "+50% Gold"
	Description: string,
}

local PotionConfig = {}

PotionConfig.Potions = table.freeze({
	GoldPotion = table.freeze({
		Id = "GoldPotion", Name = "Gold Potion", Effect = "Gold", Amount = 0.5, Minutes = 30,
		Icon = "PotionGold", Tint = Color3.fromRGB(250, 211, 125), Summary = "+50% Gold",
		Description = "More Gold from tower kills, floor bosses and banked relics. Stacks with the Market and the friend boost.",
	}),
	GemPotion = table.freeze({
		Id = "GemPotion", Name = "Gem Potion", Effect = "Gems", Amount = 0.5, Minutes = 30,
		Icon = "PotionGems", Tint = Color3.fromRGB(120, 226, 255), Summary = "+50% Gems",
		Description = "More Gems from tower kills and banked relics. First-clear bonuses and raid payouts are not affected.",
	}),
	LuckPotion = table.freeze({
		Id = "LuckPotion", Name = "Luck Potion", Effect = "Luck", Amount = 0.25, Minutes = 15,
		Icon = "PotionLuck", Tint = Color3.fromRGB(150, 255, 150), Summary = "+25% summon luck",
		Description = "Raises the odds of every tier above the lowest on Call of the Rift and A Star's Arrival. Adds to God's Blessing. Forge Roll Luck is upgraded separately.",
	}),
	XpPotion = table.freeze({
		Id = "XpPotion", Name = "Hero XP Potion", Effect = "HeroXP", Amount = 1, Minutes = 30,
		Icon = "PotionXp", Tint = Color3.fromRGB(214, 150, 255), Summary = "+100% hero XP",
		Description = "Your squad heroes earn double combat XP in the tower.",
	}),
	PassXpPotion = table.freeze({
		Id = "PassXpPotion", Name = "Pass XP Potion", Effect = "PassXP", Amount = 0.5, Minutes = 30,
		Icon = "PotionPass", Tint = Color3.fromRGB(255, 150, 120), Summary = "+50% Battle Pass XP",
		Description = "Earn Battle Pass XP faster from every source.",
	}),
} :: { [string]: Potion })

-- Display order (Backpack, HUD boost strip).
PotionConfig.Order = table.freeze({ "GoldPotion", "GemPotion", "LuckPotion", "XpPotion", "PassXpPotion" })

-- A boost cannot be stacked past this much remaining time.
PotionConfig.MaxBoostSeconds = 4 * 3600
-- Most potions of one kind a profile can hold; rewards past it are dropped.
PotionConfig.MaxOwned = 999

local byEffect: { [string]: Potion } = {}
for _, id in PotionConfig.Order do
	local potion = assert(PotionConfig.Potions[id], "PotionConfig: Order lists an unknown potion " .. id)
	assert(potion.Id == id, "PotionConfig: potion key and Id differ for " .. id)
	assert(byEffect[potion.Effect] == nil, "PotionConfig: one potion per effect (" .. potion.Effect .. ")")
	assert(potion.Amount > 0 and potion.Minutes > 0, "PotionConfig: " .. id .. " needs a positive Amount and Minutes")
	byEffect[potion.Effect] = potion
end
for id in PotionConfig.Potions do
	assert(table.find(PotionConfig.Order, id), "PotionConfig: " .. id .. " is missing from Order")
end

function PotionConfig.ByEffect(effect: string): Potion?
	return byEffect[effect]
end

-- The player attribute that carries a boost's end time (workspace:GetServerTimeNow() seconds; 0 when
-- the boost is off). PotionService sets it; the HUD reads it.
function PotionConfig.Attribute(effect: string): string
	return "Boost" .. effect .. "Until"
end

return PotionConfig
