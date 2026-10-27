--!strict
-- tests/phase3-pvp-duels.luau
-- Phase 3: contested drops, [Loot Thief] contests, retaliation duel layout and the loser lockout
-- (docs/rework-plan/PHASE_3_TOWER_PVP_RETALIATION.md). Owner and thief are locked out alike.

local LootDuel = require(nodes["ReplicatedStorage.Shared.Util.LootDuel"])
local HeroSkillEffects = require(nodes["ServerScriptService.Combat.HeroSkillEffects"])

local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end

local OWNER, THIEF, BYSTANDER = 101, 202, 303

test("Phase 3: the killer picking up their own drop is not theft; anyone else is", function()
	assert(not LootDuel.IsTheft(OWNER, OWNER), "killer pickup must not flag a thief")
	assert(LootDuel.IsTheft(OWNER, THIEF), "non-killer pickup must flag a thief")
	assert(not LootDuel.IsTheft(0, THIEF), "open loot is free for all")
end)

test("Phase 3: a theft opens a 3-minute contest only the owner can act on", function()
	local contest = LootDuel.NewContest(7, OWNER, THIEF, 100)
	assert(contest.Status == "CONTESTED" and contest.ExpiresAt == 100 + LootDuel.THIEF_FLAG_SECONDS)
	assert(LootDuel.CanRetaliate(contest, OWNER, 150))
	assert(not LootDuel.CanRetaliate(contest, THIEF, 150), "the thief cannot retaliate")
	assert(not LootDuel.CanRetaliate(contest, BYSTANDER, 150), "a bystander cannot retaliate")
	assert(not LootDuel.CanRetaliate(contest, OWNER, 100 + LootDuel.THIEF_FLAG_SECONDS), "window closes at expiry")
	assert(not LootDuel.CanRetaliate(nil, OWNER, 150))
	contest.Status = "DUELING"
	assert(not LootDuel.CanRetaliate(contest, OWNER, 150), "no second duel while one runs")
end)

test("Phase 3: the drop is untouchable while its duel runs", function()
	local drop = { KillerUserId = OWNER, DuelLocked = true }
	for _, userId in { OWNER, THIEF, BYSTANDER } do
		assert(not LootDuel.CanPickUp(drop, userId), "nobody may grab a drop mid-duel")
	end
end)

test("Phase 3: owner wins - drop is theirs, the thief is locked out", function()
	local contest = LootDuel.NewContest(7, OWNER, THIEF, 0)
	local drop = { KillerUserId = OWNER, DuelLocked = true }
	local loser = LootDuel.Resolve(contest, drop, OWNER)
	assert(loser == THIEF and contest.Status == "RESOLVED" and contest.WinnerUserId == OWNER)
	assert(drop.KillerUserId == OWNER and not drop.DuelLocked)
	assert(LootDuel.CanPickUp(drop, OWNER), "winner can carry the drop")
	assert(not LootDuel.CanPickUp(drop, THIEF), "losing thief is locked out")
	assert(LootDuel.CanPickUp(drop, BYSTANDER), "the lockout only applies to the loser")
	assert(not LootDuel.IsTheft(drop.KillerUserId, OWNER))
end)

test("Phase 3: thief wins - they keep the drop and the owner is locked out the same way", function()
	local contest = LootDuel.NewContest(7, OWNER, THIEF, 0)
	local drop = { KillerUserId = OWNER, DuelLocked = true }
	local loser = LootDuel.Resolve(contest, drop, THIEF)
	assert(loser == OWNER and contest.WinnerUserId == THIEF)
	assert(drop.KillerUserId == THIEF, "the winning thief becomes the drop's owner")
	assert(LootDuel.CanPickUp(drop, THIEF))
	assert(not LootDuel.CanPickUp(drop, OWNER), "losing owner is locked out of their old drop")
	assert(not LootDuel.IsTheft(drop.KillerUserId, THIEF), "the winner carrying it is no longer theft")
	-- The lockout survives the drop being put down and picked up again (it travels with the record).
	local respilled = { KillerUserId = 0, LockedOut = drop.LockedOut }
	assert(not LootDuel.CanPickUp(respilled, OWNER), "the lockout lasts for the drop's lifetime")
end)

test("Phase 3: duel winner is decided by knockouts, then HP on timeout", function()
	assert(LootDuel.DecideWinner(3, 2, 2.1, 1.4, false) == nil, "still fighting")
	assert(LootDuel.DecideWinner(1, 0, 0.2, 0, false) == "A")
	assert(LootDuel.DecideWinner(0, 4, 0, 3, false) == "B")
	assert(LootDuel.DecideWinner(0, 0, 0, 0, false) == "B", "a double KO goes to the defender")
	assert(LootDuel.DecideWinner(2, 2, 1.6, 1.2, true) == "A", "timeout: more HP left wins")
	assert(LootDuel.DecideWinner(2, 2, 1.0, 1.0, true) == "B", "timeout tie goes to the defender")
end)

test("Phase 3: duel formation puts melee in front and mirrors the squads across the arena", function()
	local order = LootDuel.FormationOrder({ "Healer", "Marksman", "Vanguard", "Striker", "Scholar" })
	-- Vanguard, Striker, Marksman, Scholar, Healer
	assert(order[1] == 3 and order[2] == 4 and order[3] == 2 and order[4] == 5 and order[5] == 1)

	local seen = {}
	for slot = 1, 5 do
		local q, r = LootDuel.SlotHex("A", slot)
		local bq, br = LootDuel.SlotHex("B", slot)
		assert(bq == -q and br == -r, "side B mirrors side A")
		assert(LootDuel.HexDistance(q, r) <= LootDuel.ARENA_RINGS, "every slot sits on an arena tile")
		local key = q .. "," .. r
		assert(not seen[key], "slots never overlap")
		seen[key] = true
		local a, b = LootDuel.SlotLocal("A", slot), LootDuel.SlotLocal("B", slot)
		assert(a.Z < 0 and b.Z > 0, "side A stands on -Z, side B on +Z")
	end
	local front, back = LootDuel.SlotLocal("A", 1), LootDuel.SlotLocal("A", 4)
	assert(front.Z > back.Z, "the front row faces the enemy")
	assert(#LootDuel.ArenaTiles() == 3 * LootDuel.ARENA_RINGS * (LootDuel.ARENA_RINGS + 1) + 1, "hex arena tile count")
end)

test("Phase 3: duel skill splash hits the opposing squad through the duel hooks, never mobs", function()
	local hits = {}
	local enemy = { NetId = 9, DuelId = 1, State = "ATTACKING", CurrentHP = 500, MaxHP = 500, Position = Vector3.new(2, 0, 0) }
	local mob = { NetId = 10, IsAlive = true, CurrentHP = 900, MaxHP = 900, Position = Vector3.new(1, 0, 0), DamageLedger = {} }
	local attacker = { Owner = { UserId = OWNER }, Archetype = "Scholar", MaxHP = 400, Position = Vector3.new(0, 0, 0) }
	local ctx = {
		Mobs = { [9] = enemy },
		Now = 0,
		Same = function() return true end,
		IsCombatSafe = function() return false end,
		Broadcast = function() end,
		HandleMobDeath = function() error("duel hits must not report mob deaths") end,
		Eligible = function(target: any) return target.DuelId == 1 and target.CurrentHP > 0 end,
		Damage = function(target: any, amount: number) table.insert(hits, { target, amount }) end,
	}
	HeroSkillEffects.Resolve(ctx :: any, {
		Impact = { Atk = 100, DamageMult = 2, Ticks = 1 },
		Attacker = attacker,
		Profile = { Skill = { Radius = 20 } },
		Tier = "SKILL",
		Tick = 1,
		Primary = nil,
		Center = Vector3.new(0, 0, 0),
	})
	assert(#hits == 1 and hits[1][1] == enemy and hits[1][2] > 0, "splash routed through ctx.Damage")
	assert(mob.CurrentHP == 900, "mobs are not part of a duel")
	assert(enemy.CurrentHP == 500, "the hook, not the effect module, applies duel damage")
end)

print(string.format("phase3-pvp-duels: %d tests passed", passed))
