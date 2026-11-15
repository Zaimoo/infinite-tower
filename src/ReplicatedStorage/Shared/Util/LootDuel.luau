--!strict
-- Shared/Util/LootDuel.luau
-- Rules for contested tower drops and duels (GDD 6.1). A thief carries an open bounty: any other
-- Master who walks up to them and presses F challenges them to a duel for the drop. Any Master
-- carrying a relic can also be challenged for it (a carry challenge), within the guardrails below.
-- Pure data and math: the server owns the state, the client only reads the layout constants.

local LootDuel = {}

LootDuel.THIEF_FLAG_SECONDS = 180 -- [Loot Thief] flag and bounty window
LootDuel.DUEL_MAX_SECONDS = 40 -- after this the side with more HP left wins
LootDuel.DUEL_INTRO_SECONDS = 2.5 -- squads stand in formation before the first swing
LootDuel.DUEL_OUTRO_SECONDS = 3.0 -- result banner before squads return to their Masters
LootDuel.DUEL_DAMAGE_SCALE = 0.5 -- hero-vs-hero damage multiplier
LootDuel.CHALLENGE_COOLDOWN = 3.0
LootDuel.CHALLENGE_RANGE = 12 -- studs between the hunter and the thief for the F prompt

-- Carry challenges: guardrails against griefing, ambushes and passing loot between accounts.
LootDuel.CARRY_SHIELD_SECONDS = 45 -- after any duel, the relic's holder can't be carry-challenged
LootDuel.CARRY_LOSS_COOLDOWN = 120 -- a challenger who loses waits this long to challenge anyone again
LootDuel.CARRY_WIN_COOLDOWN = 30 -- ...and this long after a win
LootDuel.CARRY_PAIR_COOLDOWN = 600 -- the same two Masters can't carry-duel each other again for 10 minutes
LootDuel.CARRY_OVERLEVEL_FLOORS = 10 -- no carry challenges on a floor this far below your best clear

-- Arena geometry: flat-top hex grid, HEX_SIZE is centre-to-corner in studs.
LootDuel.HEX_SIZE = 3.2
LootDuel.ARENA_RINGS = 5
LootDuel.ARENA_LIFT = 14 -- studs below the room's ceiling bound where the arena floats

export type Side = "A" | "B"

export type Contest = {
	DropId: number,
	OwnerUserId: number,
	ThiefUserId: number,
	ChallengerUserId: number?, -- the bounty hunter, set when a duel starts
	ExpiresAt: number,
	Status: "CONTESTED" | "DUELING" | "RESOLVED" | "EXPIRED",
	WinnerUserId: number?,
	-- "CARRY": a carry challenge. The carrier defends as the thief side (B) without being a thief:
	-- no [Loot Thief] flag and no bounty. nil: a theft's bounty.
	Kind: "CARRY"?,
	-- A Rival Master lesson's theft (first-session-and-social-plan.md A7): private to the thief. No
	-- public bounty toast or Claim Bounty prompt, and only the Rival may duel for it.
	Training: boolean?,
}

local SQRT3 = math.sqrt(3)

-- Axial (q, r) to arena-local offset; +Z points from side A toward side B.
function LootDuel.HexToLocal(q: number, r: number): Vector3
	local s = LootDuel.HEX_SIZE
	return Vector3.new(s * 1.5 * q, 0, s * SQRT3 * (r + q / 2))
end

function LootDuel.HexDistance(q: number, r: number): number
	return math.max(math.abs(q), math.abs(r), math.abs(q + r))
end

function LootDuel.ArenaTiles(rings: number?): { { q: number, r: number } }
	local n = rings or LootDuel.ARENA_RINGS
	local tiles = {}
	for q = -n, n do
		for r = math.max(-n, -q - n), math.min(n, -q + n) do
			table.insert(tiles, { q = q, r = r })
		end
	end
	return tiles
end

-- Side A formation in axial coordinates: three frontliners, two in the back row behind the gaps.
local SLOTS_A = table.freeze({
	{ q = 0, r = -2 }, -- front centre
	{ q = -2, r = -1 }, -- front left
	{ q = 2, r = -3 }, -- front right
	{ q = -1, r = -3 }, -- back left
	{ q = 1, r = -4 }, -- back right
})

-- Side B mirrors side A through the arena centre.
function LootDuel.SlotHex(side: Side, slot: number): (number, number)
	local hex = SLOTS_A[math.clamp(slot, 1, #SLOTS_A)]
	if side == "A" then
		return hex.q, hex.r
	end
	return -hex.q, -hex.r
end

function LootDuel.SlotLocal(side: Side, slot: number): Vector3
	return LootDuel.HexToLocal(LootDuel.SlotHex(side, slot))
end

-- Melee archetypes hold the front row, ranged and support stand behind.
local FRONTLINE_ORDER = table.freeze({ Vanguard = 1, Berserker = 2, Striker = 3, Marksman = 4, Scholar = 5, Healer = 6 })

-- Returns the indices of `archetypes` in formation order (slot 1 first). Ties keep squad order.
function LootDuel.FormationOrder(archetypes: { string }): { number }
	local order = {}
	for i = 1, #archetypes do
		order[i] = i
	end
	table.sort(order, function(a, b)
		local ra = FRONTLINE_ORDER[archetypes[a]] or 3
		local rb = FRONTLINE_ORDER[archetypes[b]] or 3
		if ra ~= rb then
			return ra < rb
		end
		return a < b
	end)
	return order
end

-- Winner of a finished or timed-out duel. HP fractions are summed over each side's squad.
-- Returns nil while both sides still stand and time remains. A timed-out tie goes to the defender (B).
function LootDuel.DecideWinner(aliveA: number, aliveB: number, hpA: number, hpB: number, timedOut: boolean): Side?
	if aliveA <= 0 and aliveB <= 0 then
		return "B"
	elseif aliveB <= 0 then
		return "A"
	elseif aliveA <= 0 then
		return "B"
	elseif timedOut then
		return if hpA > hpB then "A" else "B"
	end
	return nil
end

-- Picking up a drop tagged to another player is theft; open drops (KillerUserId 0) are free.
function LootDuel.IsTheft(killerUserId: number, pickerUserId: number): boolean
	return killerUserId ~= 0 and killerUserId ~= pickerUserId
end

function LootDuel.NewContest(dropId: number, ownerUserId: number, thiefUserId: number, now: number): Contest
	return {
		DropId = dropId,
		OwnerUserId = ownerUserId,
		ThiefUserId = thiefUserId,
		ExpiresAt = now + LootDuel.THIEF_FLAG_SECONDS,
		Status = "CONTESTED",
		ChallengerUserId = nil,
		WinnerUserId = nil,
	}
end

-- A carry challenge's contest: the carrier defends (thief side B), the challenger hunts (side A).
-- It is fought at once, so its window only has to outlast the duel.
function LootDuel.NewCarryContest(dropId: number, carrierUserId: number, challengerUserId: number, now: number): Contest
	return {
		DropId = dropId,
		OwnerUserId = carrierUserId,
		ThiefUserId = carrierUserId,
		ChallengerUserId = challengerUserId,
		ExpiresAt = now + LootDuel.DUEL_INTRO_SECONDS + LootDuel.DUEL_MAX_SECONDS + LootDuel.DUEL_OUTRO_SECONDS + 10,
		Status = "CONTESTED",
		WinnerUserId = nil,
		Kind = "CARRY",
	}
end

-- One key per pair of Masters, whichever challenged.
function LootDuel.PairKey(a: number, b: number): string
	return if a < b then `{a}:{b}` else `{b}:{a}`
end

-- Everything the server knows when a Master challenges a carrier (CombatSimulation gathers it).
export type CarryCheck = {
	ChallengerUserId: number,
	CarrierUserId: number,
	Drop: any, -- the carried relic's record (LockedOut, DuelLocked, ProtectedForUserId, TrainingFor)
	SameFloor: boolean,
	FloorId: number,
	ChallengerCarrying: boolean,
	ChallengerBestFloor: number, -- HighestClearedFloor
	ChallengerSafe: boolean, -- standing in a sanctuary or combat-safe zone
	CarrierSafe: boolean,
	CarrierBossLocked: boolean, -- has hurt this floor's boss, which is still alive
	Busy: boolean, -- either Master is duelling or travelling
	CarrierShieldUntil: number?,
	ChallengerCooldownUntil: number?,
	PairCooldownUntil: number?,
	Now: number,
}

-- Can this Master challenge that carrier for the relic they hold? Returns (ok, "Headline|detail").
-- Each refusal is a guardrail (GDD 6.1):
--   empty hands: the challenger risks a lockout and a cooldown, and can't hold two relics;
--   protected relics (a new Master's first) are never contested;
--   sanctuaries are off limits, so nobody is pinned at the door they are banking through;
--   a boss fight isn't interrupted;
--   over-levelled Masters can't farm low floors (or a low-floor alt account);
--   a fresh duel shields the relic's holder, a challenger waits after each try, and the same two
--   Masters can't keep duelling each other.
function LootDuel.CanChallengeCarrier(c: CarryCheck): (boolean, string?)
	local now = c.Now
	if c.ChallengerUserId == c.CarrierUserId then
		return false, "Your own relic|You're carrying it"
	elseif c.Busy then
		return false, "Not now|A duel or a trip is under way"
	elseif not c.SameFloor or c.FloorId < 1 or c.FloorId > 50 then
		return false, "Out of reach|Only on your own Tower floor"
	elseif c.ChallengerCarrying then
		return false, "Hands full|Bank or drop your relic first"
	elseif c.Drop.ProtectedForUserId then
		return false, "Protected|A new Master's first relic"
	elseif c.Drop.TrainingFor then
		return false, "Protected|A Rival lesson's relic"
	elseif c.Drop.DuelLocked then
		return false, "Already contested|A duel for it is running"
	elseif c.Drop.LockedOut and c.Drop.LockedOut[c.ChallengerUserId] then
		return false, "Locked out|You lost a duel for this relic"
	elseif c.ChallengerSafe or c.CarrierSafe then
		return false, "Sanctuary|No duels in a sanctuary"
	elseif c.CarrierBossLocked then
		return false, "Boss fight|Wait until the boss falls"
	elseif c.ChallengerBestFloor >= c.FloorId + LootDuel.CARRY_OVERLEVEL_FLOORS then
		return false, string.format("Beneath you|Floor %d is far below your best", c.FloorId)
	elseif (c.CarrierShieldUntil or 0) > now then
		return false, string.format("Shielded|%ds after their last duel", math.ceil((c.CarrierShieldUntil :: number) - now))
	elseif (c.ChallengerCooldownUntil or 0) > now then
		return false, string.format("Catch your breath|%ds until your next challenge", math.ceil((c.ChallengerCooldownUntil :: number) - now))
	elseif (c.PairCooldownUntil or 0) > now then
		return false, "Not again|You duelled them a moment ago"
	end
	return true, nil
end

-- Any Master except the thief may claim the bounty, the robbed owner included.
function LootDuel.CanChallenge(contest: Contest?, requesterUserId: number, now: number): (boolean, string?)
	if not contest then
		return false, "That player has no bounty on them."
	elseif contest.ThiefUserId == requesterUserId then
		return false, "You cannot claim the bounty on yourself."
	elseif contest.Status == "DUELING" then
		return false, "Someone is already dueling for this bounty."
	elseif contest.Status ~= "CONTESTED" or now >= contest.ExpiresAt then
		return false, "The bounty has expired."
	end
	return true, nil
end

-- Pickup rule for a drop record carrying a `LockedOut` set (userId -> true) and an optional
-- `DuelLocked` flag. The duel loser is locked out for the drop's lifetime, owner or thief alike.
function LootDuel.CanPickUp(drop: any, userId: number): (boolean, string?)
	if drop.DuelLocked then
		return false, "This drop is being fought over in a duel."
	end
	if drop.LockedOut and drop.LockedOut[userId] then
		return false, "You lost the duel for this drop and are locked out of it."
	end
	return true, nil
end

-- Applies a duel result to the contest and the drop record. The duel is hunter vs thief: the
-- winner becomes the drop's owner and the loser, hunter or thief, can never pick it up again.
function LootDuel.Resolve(contest: Contest, drop: any?, winnerUserId: number)
	local hunterUserId = contest.ChallengerUserId or contest.OwnerUserId
	local loserUserId = if winnerUserId == contest.ThiefUserId then hunterUserId else contest.ThiefUserId
	contest.Status = "RESOLVED"
	contest.WinnerUserId = winnerUserId
	if drop then
		drop.LockedOut = drop.LockedOut or {}
		drop.LockedOut[loserUserId] = true
		drop.DuelLocked = nil
		drop.KillerUserId = winnerUserId
	end
	return loserUserId
end

return table.freeze(LootDuel)
