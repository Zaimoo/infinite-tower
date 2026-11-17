--!strict
-- tests/reforge.spec.luau
-- Weapon Reforge (GDD §7.6): odds, costs, pity, the roll/keep flow, bonuses and save repair
-- (ReforgeConfig + ReforgeRules + StatFormulas).

local Config = require(nodes["ReplicatedStorage.Shared.Config.ReforgeConfig"])
local Rules = require(nodes["ReplicatedStorage.Shared.Util.ReforgeRules"])
local Stats = require(nodes["ReplicatedStorage.Shared.Util.StatFormulas"])
local Balance = require(nodes["ReplicatedStorage.Shared.Config.StatBalance"])

local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end

local function profile(gold: number): any
	return {
		Currencies = { Gold = gold, Gems = 0 },
		Heroes = {},
		Artifacts = {
			w1 = { UUID = "w1", TemplateId = "art_rusty_daggers", DisplayName = "Rusty Daggers", Type = "DAGGERS", Rarity = 1, Star = 1 },
			w2 = { UUID = "w2", TemplateId = "art_world_carver", DisplayName = "World Carver", Type = "AXE", Rarity = 7, Star = 7 },
		},
	}
end

test("reforge: grade odds add up to 100% and each trait's bonus rises with grade", function()
	local total = 0
	for _, chance in Rules.GradeChances() do total += chance end
	assert(math.abs(total - 1) < 1e-9, "grade chances add up to 1")
	for _, id in Config.TraitOrder do
		local values = Config.Traits[id].Values
		assert(#values == #Config.Grades, id .. " has a value per grade")
		for i = 2, #values do assert(values[i] > values[i - 1], id .. " rises with grade") end
	end
	assert(Config.Traits.KEEN.Values[#Config.Grades] <= 20 and Config.Traits.VIGOR.Values[#Config.Grades] <= 15,
		"traits stay far below one hero star (x3.24), so they cannot replace promotion")
end)

test("reforge: roll cost scales with rarity and stars", function()
	local p = profile(0)
	assert(Rules.Cost(p.Artifacts.w1) == 5000, "a Common 1★ roll costs 5,000")
	assert(Rules.Cost(p.Artifacts.w2) == 5000 * 60 * 4, "a Mythical 7★ roll costs 1.2M")
	assert(Rules.Cost({ Rarity = 6, Star = 3 }) == 5000 * Balance.RarityGoldFactor(6) * 2)
	assert(Rules.Cost({ Rarity = 8, Star = 1 }) == 5000 * 60, "Gildforged uses the Mythical factor")
end)

test("reforge: grade rolls follow the weights and pity forces Epic or better", function()
	assert(Rules.RollGrade(0, 0) == 1 and Rules.RollGrade(0.4999, 0) == 1 and Rules.RollGrade(0.5, 0) == 2)
	assert(Rules.RollGrade(0.999, 0) == 6 and Rules.RollGrade(0.997, 0) == 5, "the top 0.2% is Godly, the 1.8% below it Legendary")
	assert(not Rules.PityReady(Config.PityRolls - 2) and Rules.PityReady(Config.PityRolls - 1))
	for _, roll in { 0, 0.3, 0.7, 0.99 } do
		assert(Rules.RollGrade(roll, Config.PityRolls - 1) >= Config.PityGrade, "pity guarantees Epic or better")
	end
	assert(Rules.RollTraitId(0) == "KEEN" and Rules.RollTraitId(0.999) == "FOCUS")
end)

test("reforge: a roll charges once, parks the result, and keep new / keep old resolve it", function()
	local p = profile(20000)
	local ok, _, trait = Rules.Roll(p, "w1", 0, 0.6) -- KEEN, Uncommon
	assert(ok and trait and trait.Id == "KEEN" and trait.Grade == 2)
	assert(p.Currencies.Gold == 15000, "charged 5,000")
	assert(p.Reforge.Pending.UUID == "w1" and p.Reforge.Rolls == 1 and p.Reforge.Pity == 1)
	assert(p.Artifacts.w1.Trait == nil, "nothing changes on the weapon until the Master chooses")
	-- Another weapon cannot be rolled while a result is waiting.
	local blocked = Rules.Roll(p, "w2", 0, 0)
	assert(not blocked and p.Currencies.Gold == 15000)
	assert(Rules.Choose(p, "w1", true))
	assert(p.Artifacts.w1.Trait.Id == "KEEN" and p.Artifacts.w1.Trait.Grade == 2 and p.Reforge.Pending == nil)
	assert(not Rules.Choose(p, "w1", true), "nothing left to keep")
	-- Roll again, keep the old trait.
	assert(Rules.Roll(p, "w1", 0.3, 0.99)) -- VIGOR, Legendary
	assert(Rules.Choose(p, "w1", false))
	assert(p.Artifacts.w1.Trait.Id == "KEEN" and p.Reforge.Pity == 0, "old trait kept; a Legendary roll resets pity")
	-- Rolling again on the same weapon discards the waiting result.
	assert(Rules.Roll(p, "w1", 0.6, 0))
	assert(Rules.Roll(p, "w1", 0.8, 0))
	assert(p.Reforge.Pending.Trait.Id == "FOCUS" and p.Currencies.Gold == 0)
	assert(not Rules.Roll(p, "w1", 0, 0), "not enough Gold")
end)

test("reforge: bad requests change nothing", function()
	local p = profile(1e9)
	for _, uuid in { nil, 5, "", "missing", string.rep("x", 65) } do
		assert(not Rules.Roll(p, uuid :: any, 0, 0))
	end
	assert(p.Currencies.Gold == 1e9)
	assert(Rules.Roll(p, "w1", 0, 0))
	for _, choice in { nil, "NEW", 1 } do
		assert(not Rules.Choose(p, "w1", choice :: any), "keepNew must be a boolean")
	end
	p.Currencies.Gold = 0 / 0
	p.Reforge.Pending = nil
	assert(not Rules.Roll(p, "w1", 0, 0), "a NaN balance never pays")
	-- A pending roll whose weapon was sold is dropped.
	p.Currencies.Gold = 1e9
	assert(Rules.Roll(p, "w1", 0, 0))
	p.Artifacts.w1 = nil
	assert(not Rules.Choose(p, "w1", true) and p.Reforge.Pending == nil)
end)

test("reforge: save repair drops damaged traits and pending rolls", function()
	local p = profile(0)
	p.Artifacts.w1.Trait = { Id = "NOPE", Grade = 2 }
	p.Artifacts.w2.Trait = { Id = "KEEN", Grade = 9 }
	p.Reforge = { Pity = -4, Rolls = "x", Pending = { UUID = "gone", Trait = { Id = "KEEN", Grade = 1 } } }
	Rules.EnsureState(p)
	assert(p.Artifacts.w1.Trait == nil and p.Artifacts.w2.Trait == nil)
	assert(p.Reforge.Pity == 0 and p.Reforge.Rolls == 0 and p.Reforge.Pending == nil)
	local fresh = profile(0)
	Rules.EnsureState(fresh)
	assert(fresh.Reforge.Pity == 0 and fresh.Reforge.Pending == nil, "old saves gain the state")
end)

test("reforge: traits change hero stats, and Rift Attunement still caps the result", function()
	local hero = { TemplateId = "hero_han", Stars = 3, Level = 10, QualityScalar = 1 }
	local plain = { Star = 3, Rarity = 6, TemplateId = "art_rusty_daggers" }
	local function with(id: string, grade: number): any
		local w = table.clone(plain); w.Trait = { Id = id, Grade = grade }; return w
	end
	local base = Stats.GetCombatSnapshot(hero, plain)
	local keen = Stats.GetCombatSnapshot(hero, with("KEEN", 6))
	assert(math.abs(keen.AttackDamage / base.AttackDamage - 1.2) < 0.001 and keen.Health == base.Health, "Godly Keen: +20% damage")
	local vigor = Stats.GetCombatSnapshot(hero, with("VIGOR", 6))
	assert(math.abs(vigor.Health / base.Health - 1.15) < 0.001 and vigor.AttackDamage == base.AttackDamage, "Godly Vigor: +15% HP")
	local swift = Stats.GetCombatSnapshot(hero, with("SWIFT", 6))
	assert(swift.AttackInterval < base.AttackInterval, "Swift shortens the attack interval")
	assert(Rules.GaugeMultiplier(with("FOCUS", 6)) == 1.25 and Rules.GaugeMultiplier(plain) == 1)
	local cap = Stats.GetAttunementCap(10)
	local atk, hp = Stats.GetAttunedMultipliers(hero, with("KEEN", 6), 1, cap)
	local capped = Stats.GetCombatSnapshot(hero, with("KEEN", 6), false, false, atk, hp)
	assert(10 * capped.AttackDamage / capped.TickInterval + capped.Health <= cap * 1.001, "the cap still holds with a trait")
end)

print(string.format("reforge.spec: %d passed", passed))
