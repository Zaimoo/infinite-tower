--!strict
-- Pure camp roster rules for the tower encounter runtime (Phase C). No Roblox services or Random, so
-- specs can run it directly.
-- 1. Every spawning area (camp) fields ALL of the biome's Regular types. Members are dealt types from a
--    shuffled bag, so each camp holds every type, and the mix is reshuffled when its wave comes back.
-- 2. A floor has a fixed number of Elites, but which areas they lead is random, and an Elite moves to
--    another cleared area when its camp's wave comes back. A camp that is fighting never changes.
-- 3. Members stand at scattered points inside their area, re-rolled each wave.
local CampRoster = {}

export type Rng = () -> number -- uniform in [0, 1)
export type Offset = { X: number, Z: number }

local MODULUS = 2147483647

-- Deterministic Park-Miller generator, so a floor's roster can be replayed from its seed.
function CampRoster.Rng(seed: number): Rng
	local state = math.floor(math.abs(seed)) % MODULUS
	if state == 0 then
		state = 1
	end
	return function(): number
		state = (state * 48271) % MODULUS
		return (state - 1) / (MODULUS - 1)
	end
end

-- Seed for one roll: the floor, its room generation, the camp (0 for floor-wide rolls) and the wave.
function CampRoster.Seed(floorId: number, generation: number, campIndex: number, wave: number): number
	return (floorId * 1000003 + generation * 7919 + campIndex * 104729 + wave * 15485863) % MODULUS
end

local function pick<T>(rng: Rng, list: { T }): T
	return list[math.min(#list, math.floor(rng() * #list) + 1)]
end

local function shuffled<T>(rng: Rng, list: { T }): { T }
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = math.min(i, math.floor(rng() * i) + 1)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

-- A Regular type dealt to one camp member. `bag` is the camp's bag for this wave (start it empty): it is
-- refilled with the whole pool, shuffled, whenever it runs out, so any `#pool` members dealt in a row
-- hold every type. Mutates `bag`.
function CampRoster.DealType(rng: Rng, bag: { string }, pool: { string }): string
	assert(#pool > 0, "Empty Regular pool")
	if #bag == 0 then
		for _, enemyId in shuffled(rng, pool) do
			table.insert(bag, enemyId)
		end
	end
	return table.remove(bag) :: string
end

-- Which eligible camps an Elite leads. `upper` marks camps above the Basin; with `needUpper` at least
-- one Elite stands there (when any upper camp is eligible), so the climb still hardens near the Apex.
function CampRoster.AssignElites(rng: Rng, eligible: { string }, count: number, upper: { [string]: boolean }, needUpper: boolean): { [string]: boolean }
	local order = shuffled(rng, eligible)
	local chosen: { [string]: boolean } = {}
	local picked: { string } = {}
	for i = 1, math.min(count, #order) do
		chosen[order[i]] = true
		table.insert(picked, order[i])
	end
	if needUpper and #picked > 0 then
		local hasUpper = false
		for _, campId in picked do
			if upper[campId] then hasUpper = true break end
		end
		if not hasUpper then
			for i = #picked + 1, #order do
				if upper[order[i]] then
					chosen[picked[#picked]] = nil
					chosen[order[i]] = true
					break
				end
			end
		end
	end
	return chosen
end

-- Where the Elite of camp `from` leads next, when `from`'s wave comes back: a random eligible camp that
-- has no Elite and is cleared (waiting to respawn, so no fight is in progress). Stays at `from` if none.
function CampRoster.MoveElite(rng: Rng, from: string, eliteCamps: { [string]: boolean }, eligible: { string }, cleared: { [string]: boolean }): string
	local candidates = {}
	for _, campId in eligible do
		if campId ~= from and not eliteCamps[campId] and cleared[campId] then
			table.insert(candidates, campId)
		end
	end
	return if #candidates > 0 then pick(rng, candidates) else from
end

-- Scattered offsets from a camp centre, inside `radius`, at least `minSpacing` from each other and
-- from `existing`. Falls back to a golden-angle ring when a point cannot be placed.
function CampRoster.RollOffsets(rng: Rng, radius: number, count: number, minSpacing: number, existing: { Offset }?): { Offset }
	local placed: { Offset } = table.clone(existing or {})
	local result: { Offset } = {}
	for i = 1, count do
		local point: Offset? = nil
		for _ = 1, 30 do
			local r = radius * math.sqrt(rng())
			local a = rng() * math.pi * 2
			local candidate = { X = math.cos(a) * r, Z = math.sin(a) * r }
			local ok = true
			for _, other in placed do
				local dx, dz = other.X - candidate.X, other.Z - candidate.Z
				if dx * dx + dz * dz < minSpacing * minSpacing then
					ok = false
					break
				end
			end
			if ok then
				point = candidate
				break
			end
		end
		if not point then
			local a = (#placed + i) * 2.39996
			point = { X = math.cos(a) * radius * 0.7, Z = math.sin(a) * radius * 0.7 }
		end
		local chosen = point :: Offset
		table.insert(placed, chosen)
		table.insert(result, chosen)
	end
	return result
end

return table.freeze(CampRoster)
