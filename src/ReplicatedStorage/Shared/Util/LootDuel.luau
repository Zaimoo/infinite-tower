--!strict
-- Shared/Util/LootDuel.luau
-- Rules for contested tower drops and retaliation duels (docs/rework-plan/PHASE_3_TOWER_PVP_RETALIATION.md).
-- Pure data and math: the server owns the state, the client only reads the layout constants.

local LootDuel = {}

LootDuel.THIEF_FLAG_SECONDS = 180 -- [Loot Thief] flag and retaliation window
LootDuel.DUEL_MAX_SECONDS = 40 -- after this the side with more HP left wins
LootDuel.DUEL_INTRO_SECONDS = 2.5 -- squads stand in formation before the first swing
LootDuel.DUEL_OUTRO_SECONDS = 3.0 -- result banner before squads return to their Masters
LootDuel.DUEL_DAMAGE_SCALE = 0.5 -- hero-vs-hero damage multiplier
LootDuel.RETALIATE_COOLDOWN = 3.0

-- Arena geometry: flat-top hex grid, HEX_SIZE is centre-to-corner in studs.
LootDuel.HEX_SIZE = 3.2
LootDuel.ARENA_RINGS = 5
LootDuel.ARENA_LIFT = 14 -- studs below the room's ceiling bound where the arena floats

export type Side = "A" | "B"

export type Contest = {
	DropId: number,
	OwnerUserId: number,
	ThiefUserId: number,
	ExpiresAt: number,
	Status: "CONTESTED" | "DUELING" | "RESOLVED" | "EXPIRED",
	WinnerUserId: number?,
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
local FRONTLINE_ORDER = table.freeze({ Vanguard = 1, Miner = 2, Striker = 3, Marksman = 4, Scholar = 5, Healer = 6 })

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
		WinnerUserId = nil,
	}
end

function LootDuel.CanRetaliate(contest: Contest?, requesterUserId: number, now: number): (boolean, string?)
	if not contest then
		return false, "That drop is no longer contested."
	elseif contest.OwnerUserId ~= requesterUserId then
		return false, "Only the drop's owner can retaliate."
	elseif contest.Status == "DUELING" then
		return false, "A duel for this drop is already underway."
	elseif contest.Status ~= "CONTESTED" or now >= contest.ExpiresAt then
		return false, "The retaliation window has closed."
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

-- Applies a duel result to the contest and the drop record. The winner becomes the drop's owner;
-- the loser, whichever role they had, can never pick this drop up again.
function LootDuel.Resolve(contest: Contest, drop: any?, winnerUserId: number)
	local loserUserId = if winnerUserId == contest.OwnerUserId then contest.ThiefUserId else contest.OwnerUserId
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
