-- Raid boss rules (docs/raid-boss-plan.md). Bundled by run.ps1; `nodes` and `require` come from the shim.
local Config = require(nodes["ReplicatedStorage.Shared.Config.RaidConfig"])
local Rules = require(nodes["ReplicatedStorage.Shared.Util.RaidRules"])
local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end
local function near(a: number, b: number, eps: number?): boolean return math.abs(a - b) <= (eps or 1e-6) end

test("Raids start on the :00 and :30 UTC grid and rotate through all four bosses", function()
	assert(Rules.NextStart(0) == 1800)
	assert(Rules.NextStart(1799) == 1800 and Rules.NextStart(1800) == 3600)
	local seen = {}
	for n = 100, 103 do seen[Rules.BossFor(n).Id] = true end
	local count = 0
	for _ in seen do count += 1 end
	assert(count == 4 and #Config.Bosses == 4)
	assert(Rules.BossFor(100).Id == Rules.BossFor(104).Id)
	assert(Rules.RaidNumber(Rules.NextStart(5000)) == 3)
end)

test("Phases run calm, warning, active, results, calm; entry closes before the end", function()
	local t = Rules.Timings(false)
	local s = 10000
	assert(Rules.PhaseAt(s - 61, s, t) == "CALM")
	assert(Rules.PhaseAt(s - 60, s, t) == "WARNING")
	assert(Rules.PhaseAt(s, s, t) == "ACTIVE" and Rules.PhaseAt(s + 299, s, t) == "ACTIVE")
	assert(Rules.PhaseAt(s + 300, s, t) == "RESULTS")
	assert(Rules.PhaseAt(s + 312, s, t) == "CALM")
	assert(not Rules.CanEnter(s - 61, s, t) and Rules.CanEnter(s - 60, s, t))
	assert(Rules.CanEnter(s + 269, s, t) and not Rules.CanEnter(s + 270, s, t))
	local f = Rules.Timings(true)
	assert(f.Active < t.Active and f.Warning < t.Warning)
end)

test("Late joiners grow max HP but never heal the boss's HP fraction", function()
	local share = Rules.HpShare(100)
	assert(near(share, 100 * 300 * Config.HpFactor))
	assert(Rules.HpShare(0) == Rules.HpShare(Config.MinDPS))
	assert(Rules.HpShare(0 / 0) == Rules.HpShare(Config.MinDPS), "NaN DPS uses the floor")
	local hp, max = Rules.AddShare(2500, 10000, 10000)
	assert(near(max, 20000) and near(hp, 5000))
	local hp2, max2 = Rules.AddShare(0, 0, 400)
	assert(hp2 == 400 and max2 == 400)
end)

test("Ranking sorts by damage, then by who got there first", function()
	local ranked = Rules.Rank({ { UserId = 1, Damage = 50, FirstAt = 3 }, { UserId = 2, Damage = 80, FirstAt = 9 }, { UserId = 3, Damage = 50, FirstAt = 1 } })
	assert(ranked[1].UserId == 2 and ranked[2].UserId == 3 and ranked[3].UserId == 1)
end)

test("Rewards rise with damage, top out at exactly 2,000 Gems on a kill, and match the plan table", function()
	local maxHP = 1e6
	local top = Rules.Reward(1000, 1000, 1, maxHP, 1)
	assert(top.Gems == 2000 and Config.MaxGems == 2000)
	assert(Rules.Reward(500, 1000, 2, maxHP, 1).Gems == 1388)
	assert(Rules.Reward(250, 1000, 3, maxHP, 1).Gems == 983)
	assert(Rules.Reward(50, 1000, 4, maxHP, 1).Gems == 498)
	assert(Rules.Reward(1000, 1000, 1, maxHP, 0.6).Gems == 1600)
	local last = -1
	for d = 1, 1000, 7 do
		local g = Rules.Reward(d, 1000, 1, maxHP, 1).Gems
		assert(g >= last and g <= 2000, "Rewards must be monotonic and capped")
		last = g
	end
	-- the cap holds even for bad inputs
	assert(Rules.Reward(5000, 1000, 1, maxHP, 3).Gems == 2000)
end)

test("Only qualifiers are paid; every qualifier gets the participation floor", function()
	local maxHP = 1e6
	assert(not Rules.Reward(0, 1000, 1, maxHP, 1).Qualified)
	local tiny = Rules.Reward(1, 1e6, 11, maxHP, 1)
	assert(not tiny.Qualified and tiny.Gems == 0, "rank 11 below 0.5% of max HP")
	local topTen = Rules.Reward(1, 1e6, 10, maxHP, 1)
	assert(topTen.Qualified and topTen.Gems >= 200)
	assert(Rules.Reward(5000, 1e6, 40, maxHP, 1).Qualified, "0.5% of max HP qualifies at any rank")
	assert(Rules.Reward(1, 1e6, 10, maxHP, 0).Gems >= 100)
end)

test("Gold follows Gems and floor scaling", function()
	local r = Rules.Reward(1000, 1000, 1, 1e6, 1, Rules.FloorScale(21))
	assert(r.Gold == math.round(2000 * Config.GoldPerGem * 2))
	assert(Rules.FloorScale(1) == 1 and Rules.FloorScale(99) == Rules.FloorScale(50))
end)

test("The leaderboard buffer round-trips and rejects bad lengths", function()
	local buf = Rules.EncodeBoard({ { Slot = 3, Damage = 1.5e12 }, { Slot = 1, Damage = 42 } }, 7, 99, 2e12, 5e12, 1e12)
	local d = assert(Rules.DecodeBoard(buf))
	assert(#d.Rows == 2 and d.Rows[1].Slot == 3 and d.Rows[1].Damage == 1.5e12 and d.Rows[2].Damage == 42)
	assert(d.SelfRank == 7 and d.SelfDamage == 99 and d.Total == 2e12 and d.MaxHP == 5e12 and d.CurrentHP == 1e12)
	assert(Rules.DecodeBoard(buffer.create(5)) == nil)
	assert(Rules.DecodeBoard(buffer.create(0)) == nil)
end)

test("Clock and damage abbreviations read cleanly", function()
	assert(Rules.Clock(252) == "4:12" and Rules.Clock(0) == "0:00" and Rules.Clock(-3) == "0:00")
	assert(Rules.Abbrev(950) == "950" and Rules.Abbrev(12400) == "12.4K" and Rules.Abbrev(3.25e6) == "3.2M" and Rules.Abbrev(456e9) == "456B")
end)

test("Every boss has a full kit with known telegraph shapes", function()
	local shapes = { ARC = true, SELF_DISC = true, TARGET_DISC = true, PROJECTILE = true }
	for _, boss in Config.Bosses do
		assert(Config.Get(boss.Id) == boss)
		assert(shapes[boss.Basic.Shape] and shapes[boss.Enrage.Shape] and #boss.Signatures >= 2)
		for _, a in boss.Signatures do assert(shapes[a.Shape] and a.Signature and a.Windup > 0) end
		assert(boss.Height > 0 and boss.HitRadius > 0 and boss.AttackInterval > 0)
	end
	assert(Config.FloorId > 50 and Config.FloorId <= 255)
end)

print(`raid.spec: {passed} passed`)
