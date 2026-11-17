--!strict
-- ReplicatedStorage/Shared/Config/ReforgeConfig.luau
-- Weapon Reforge (GDD §7.6): the Runesmith's Anvil on the Cloister Commons rolls one enchantment onto a weapon
-- for Gold. Plain data; the rules live in Shared/Util/ReforgeRules and the server in Core/ReforgeService.
--
-- A weapon holds at most one enchantment: { Id = enchantment id, Grade = 1..6 }. Each roll picks an enchantment (evenly) and a
-- grade (by Weight), and the Master then keeps the new enchantment or the old one. Bonuses are capped low on
-- purpose: one hero star is worth x3.24, so no enchantment can stand in for a promotion and the tower's
-- floor-50 gate (StatBalance.ExpectedSquads) still asks for 7★ heroes.

export type Grade = { Id: string, Name: string, Weight: number, Color: Color3 }
export type Enchantment = { Id: string, Name: string, Summary: string, Values: { number } }

local Config = {}

-- Grades from worst to best. Weights are percent and add up to 100.
Config.Grades = table.freeze({
	table.freeze({ Id = "COMMON", Name = "Common", Weight = 50, Color = Color3.fromRGB(176, 176, 176) }),
	table.freeze({ Id = "UNCOMMON", Name = "Uncommon", Weight = 28, Color = Color3.fromRGB(75, 181, 67) }),
	table.freeze({ Id = "RARE", Name = "Rare", Weight = 14, Color = Color3.fromRGB(41, 128, 185) }),
	table.freeze({ Id = "EPIC", Name = "Epic", Weight = 6, Color = Color3.fromRGB(142, 68, 173) }),
	table.freeze({ Id = "LEGENDARY", Name = "Legendary", Weight = 1.8, Color = Color3.fromRGB(241, 196, 15) }),
	table.freeze({ Id = "GODLY", Name = "Godly", Weight = 0.2, Color = Color3.fromRGB(255, 92, 92) }),
} :: { Grade })

-- Each enchantment's bonus in percent, by grade (Common .. Godly). Summary takes the value with %d.
Config.Enchantments = table.freeze({
	KEEN = table.freeze({ Id = "KEEN", Name = "Keen", Summary = "+%d%% damage", Values = table.freeze({ 2, 4, 6, 9, 13, 20 }) }),
	VIGOR = table.freeze({ Id = "VIGOR", Name = "Vigor", Summary = "+%d%% HP", Values = table.freeze({ 2, 3, 5, 7, 10, 15 }) }),
	SWIFT = table.freeze({ Id = "SWIFT", Name = "Swift", Summary = "+%d%% attack speed", Values = table.freeze({ 2, 3, 5, 7, 10, 14 }) }),
	FOCUS = table.freeze({ Id = "FOCUS", Name = "Focus", Summary = "+%d%% Skill Gauge charge", Values = table.freeze({ 4, 6, 9, 12, 16, 25 }) }),
} :: { [string]: Enchantment })
Config.EnchantmentOrder = table.freeze({ "KEEN", "VIGOR", "SWIFT", "FOCUS" })

-- Gold per roll: BaseRollGold x the weapon's rarity Gold factor (StatBalance.RarityGoldFactor, the same
-- x1 .. x60 as promotion) x (1 + StarCostStep x (stars - 1)). A Common 1★ costs 5,000; a Mythical 7★ 1.2M.
Config.BaseRollGold = 5000
Config.StarCostStep = 0.5

-- Pity: after PityRolls rolls in a row below PityGrade (counted per Master, across all weapons), the next
-- roll is at least PityGrade. Any roll at PityGrade or better resets the count.
Config.PityRolls = 50
Config.PityGrade = 4 -- Epic

-- Server rate limit for reforge requests.
Config.MaxRequestsPerSecond = 4

-- The station's prompt (built by ReforgeService at HubLayout.ReforgeStation); the client opens the window on it.
Config.PromptName = "ReforgeStationPrompt"

return table.freeze(Config)
