--!strict
-- Pure rules for timed tower events (Phase G). No Roblox services, so specs can run it directly.
local EventConfig = require(script.Parent.Parent.Config.TowerEventConfig)

local Rules = {}

type Event = EventConfig.Event

-- The lowest biome an event can feature: its MinFloor's biome (5 floors a biome).
local function lowestBiome(event: Event): number
	return math.ceil(event.MinFloor / 5)
end

-- Picks the next event (never `lastId` again) by weight, plus the featured biome for BIOME events,
-- chosen from `unlockedBiomes`. Events that could not touch any unlocked floor are skipped.
-- Returns (event id, featured biome or 0).
function Rules.Pick(rng: () -> number, lastId: string?, unlockedBiomes: { number }): (string?, number)
	local candidates: { { Event: Event, Biomes: { number } } } = {}
	local total = 0
	for _, event in EventConfig.Events do
		if event.Id ~= lastId then
			local biomes = {}
			for _, b in unlockedBiomes do
				if b >= lowestBiome(event) then table.insert(biomes, b) end
			end
			if #biomes > 0 then
				table.insert(candidates, { Event = event, Biomes = biomes })
				total += event.Weight
			end
		end
	end
	if total <= 0 then return nil, 0 end
	local roll = rng() * total
	for _, c in candidates do
		roll -= c.Event.Weight
		if roll < 0 or c == candidates[#candidates] then
			local featured = 0
			if c.Event.Scope == "BIOME" then
				featured = c.Biomes[math.min(#c.Biomes, math.floor(rng() * #c.Biomes) + 1)]
			end
			return c.Event.Id, featured
		end
	end
	return nil, 0
end

-- Whether an active event touches a floor.
function Rules.Applies(event: Event, floorId: number, biomeIndex: number, featuredBiome: number): boolean
	if floorId < event.MinFloor then return false end
	return event.Scope == "TOWER" or biomeIndex == featuredBiome
end

-- Floors whose camps reset when `event` starts or ends: every floor it touches. `biomeOf` maps a floor to its biome.
function Rules.AffectedFloors(event: Event, featuredBiome: number, floorCount: number, biomeOf: (number) -> number): { number }
	local floors = {}
	for floorId = 1, floorCount do
		if Rules.Applies(event, floorId, biomeOf(floorId), featuredBiome) then table.insert(floors, floorId) end
	end
	return floors
end

-- Biomes a server has opened: every biome up to the one holding the floor after the best clear.
function Rules.UnlockedBiomes(highestCleared: number): { number }
	local top = math.clamp(math.ceil((highestCleared + 1) / 5), 1, 10)
	local list = {}
	for b = 1, top do table.insert(list, b) end
	return list
end

-- HUD timer: seconds left in the phase and how full its bar is. CALM counts down to the next start,
-- WARNING fills its bar towards the start, ACTIVE drains towards the end.
function Rules.Timer(phase: string, now: number, startsAt: number, endsAt: number, warningSeconds: number): (number, number)
	if phase == "ACTIVE" then
		local length = math.max(1, endsAt - startsAt)
		local left = math.max(0, endsAt - now)
		return left, math.clamp(left / length, 0, 1)
	end
	local left = math.max(0, startsAt - now)
	if phase == "WARNING" then
		return left, math.clamp(1 - left / math.max(1, warningSeconds), 0, 1)
	end
	return left, 0
end

function Rules.Format(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

return table.freeze(Rules)
