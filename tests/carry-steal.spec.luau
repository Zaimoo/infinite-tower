--!strict
-- tests/carry-steal.spec.luau
-- Carry challenges (GDD 6.1): any Master may challenge a Master carrying a relic for it, which
-- starts a duel at once; the loser is locked out of that relic. Each guardrail has a test.

local LootDuel = require(nodes["ReplicatedStorage.Shared.Util.LootDuel"])

local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end

local CARRIER, CHALLENGER, BYSTANDER = 101, 202, 303
local NOW = 1000

local function check(overrides: { [string]: any }?): LootDuel.CarryCheck
	local c: any = {
		ChallengerUserId = CHALLENGER, CarrierUserId = CARRIER,
		Drop = {}, SameFloor = true, FloorId = 7,
		ChallengerCarrying = false, ChallengerBestFloor = 7,
		ChallengerSafe = false, CarrierSafe = false, CarrierBossLocked = false, Busy = false,
		Now = NOW,
	}
	for key, value in overrides or {} do c[key] = value end
	return c
end

local function refused(overrides: { [string]: any }, headline: string)
	local ok, reason = LootDuel.CanChallengeCarrier(check(overrides))
	assert(not ok, headline .. " should refuse")
	assert(reason ~= nil and string.sub(reason, 1, #headline) == headline, `expected "{headline}", got "{tostring(reason)}"`)
	assert(string.find(reason :: string, "|", 1, true) ~= nil, "refusals are Headline|detail toasts")
end

test("carry: a Master on the same floor with empty hands can challenge a carrier", function()
	assert(LootDuel.CanChallengeCarrier(check()))
end)

test("carry: the contest is fought at once, carrier defending, and never makes a thief", function()
	local contest = LootDuel.NewCarryContest(9, CARRIER, CHALLENGER, NOW)
	assert(contest.Kind == "CARRY" and contest.Status == "CONTESTED")
	assert(contest.ThiefUserId == CARRIER and contest.OwnerUserId == CARRIER and contest.ChallengerUserId == CHALLENGER)
	assert(contest.ExpiresAt > NOW + LootDuel.DUEL_INTRO_SECONDS + LootDuel.DUEL_MAX_SECONDS + LootDuel.DUEL_OUTRO_SECONDS,
		"the window outlasts the whole duel")
	assert(LootDuel.CanChallenge(contest, CHALLENGER, NOW), "the challenger can open the duel")
	assert(not LootDuel.CanChallenge(contest, CARRIER, NOW), "the carrier can't challenge themselves")
end)

test("carry: the loser is locked out of the relic, whichever side they were on", function()
	local contest = LootDuel.NewCarryContest(9, CARRIER, CHALLENGER, NOW)
	local drop: any = { KillerUserId = CARRIER }
	assert(LootDuel.Resolve(contest, drop, CHALLENGER) == CARRIER)
	assert(drop.KillerUserId == CHALLENGER and drop.LockedOut[CARRIER], "a winning challenger takes it; the carrier is locked out")
	assert(not LootDuel.CanPickUp(drop, CARRIER), "the beaten carrier can't pick it back up")

	local defended = LootDuel.NewCarryContest(10, CARRIER, CHALLENGER, NOW)
	local kept: any = { KillerUserId = CARRIER }
	assert(LootDuel.Resolve(defended, kept, CARRIER) == CHALLENGER)
	assert(kept.KillerUserId == CARRIER and kept.LockedOut[CHALLENGER] and not kept.LockedOut[CARRIER], "a carrier who wins keeps it")
	refused({ Drop = kept }, "Locked out")
	assert(LootDuel.CanChallengeCarrier(check({ Drop = kept, ChallengerUserId = BYSTANDER })), "others may still try")
end)

test("carry: guardrails on who may challenge, and where", function()
	refused({ ChallengerUserId = CARRIER }, "Your own relic")
	refused({ Busy = true }, "Not now")
	refused({ SameFloor = false }, "Out of reach")
	refused({ FloorId = 0 }, "Out of reach")
	refused({ FloorId = 60 }, "Out of reach") -- raid arena
	refused({ ChallengerCarrying = true }, "Hands full")
	refused({ Drop = { ProtectedForUserId = CARRIER } }, "Protected")
	refused({ Drop = { TrainingFor = CARRIER } }, "Protected") -- the Rival Master lesson's relic (A7)
	refused({ Drop = { DuelLocked = true } }, "Already contested")
	refused({ ChallengerSafe = true }, "Sanctuary")
	refused({ CarrierSafe = true }, "Sanctuary")
	refused({ CarrierBossLocked = true }, "Boss fight")
end)

test("carry: over-levelled Masters can't farm low floors", function()
	local floor = 7
	assert(LootDuel.CanChallengeCarrier(check({ ChallengerBestFloor = floor + LootDuel.CARRY_OVERLEVEL_FLOORS - 1 })))
	refused({ ChallengerBestFloor = floor + LootDuel.CARRY_OVERLEVEL_FLOORS }, "Beneath you")
	assert(LootDuel.CanChallengeCarrier(check({ ChallengerBestFloor = 0 })), "a weaker Master may always try")
end)

test("carry: shields and cooldowns stop chain duels and repeat targets", function()
	refused({ CarrierShieldUntil = NOW + 10 }, "Shielded")
	assert(LootDuel.CanChallengeCarrier(check({ CarrierShieldUntil = NOW })), "a shield ends on time")
	refused({ ChallengerCooldownUntil = NOW + 5 }, "Catch your breath")
	refused({ PairCooldownUntil = NOW + 300 }, "Not again")
	assert(LootDuel.CARRY_SHIELD_SECONDS > LootDuel.DUEL_OUTRO_SECONDS, "the shield outlasts the outro")
	assert(LootDuel.CARRY_LOSS_COOLDOWN > LootDuel.CARRY_WIN_COOLDOWN, "losing costs more time than winning")
	assert(LootDuel.CARRY_PAIR_COOLDOWN >= 300, "the same two Masters wait minutes, not seconds")
	assert(LootDuel.PairKey(CARRIER, CHALLENGER) == LootDuel.PairKey(CHALLENGER, CARRIER), "a pair is one key either way")
end)

print(string.format("carry-steal.spec: %d passed", passed))
