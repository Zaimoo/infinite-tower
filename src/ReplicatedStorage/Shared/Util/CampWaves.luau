--!strict
-- Pure camp rules for the tower encounter runtime (Phase 6 M1). No Roblox services, so specs can run it directly.
-- 1. A camp respawns as one wave once every member is dead (or a lone survivor has held it back too long).
-- 2. Extra Masters on a floor scale each camp up, within a per-floor live-mob budget.
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config.FirstBiomeCombat)
local TowerLayout = require(RS.Shared.Config.TowerLayout)

local CampWaves = {}

-- Returns the RespawnAt to store on a dead camp member that is still waiting (RespawnAt == math.huge), or nil to keep waiting.
function CampWaves.ScheduleRespawn(diedAt: number?, campAlive: boolean, now: number): number?
	if not campAlive then
		return now + Config.CampRespawnSeconds
	end
	if now - (diedAt or now) >= Config.CampMaxWaitSeconds then
		return now
	end
	return nil
end

-- Number of scaled-in members for a camp of `campSize` when `masters` Masters share the floor, before the floor budget.
function CampWaves.ExtraCount(campSize: number, masters: number): number
	if masters <= 1 then return 0 end
	return math.floor(campSize * Config.PlayerSpawnScale * (masters - 1))
end

-- Layout placements plus scaled-in members. Keys of the result are slot ids: layout slots keep their index and
-- extras use Config.ExtraSlotBase + campIndex * 100 + n so they never collide with layout slots or summoned entities.
function CampWaves.EffectivePlacements(indexInBiome: number, placements: { any }, masters: number, enemyRole: (string) -> string?): { [number]: any }
	local merged: { [number]: any } = table.clone(placements) :: any
	if masters <= 1 then return merged end
	local layout = TowerLayout.Get(indexInBiome)
	local camps: { [string]: any } = {}
	local order: { string } = {}
	local baseCount = 0
	for _, p in ipairs(placements) do
		local role = enemyRole(p.EnemyId)
		if role ~= nil and role ~= "BOSS" and p.CampId ~= "CAMP_APEX_SANCTUM" then
			baseCount += 1
			local c = camps[p.CampId]
			if not c then
				c = { Count = 0, Regulars = {} }
				camps[p.CampId] = c
				table.insert(order, p.CampId)
			end
			c.Count += 1
			if role == "REGULAR" then table.insert(c.Regulars, p.EnemyId) end
		end
	end
	local budget = math.max(0, Config.MaxLiveMobsPerFloor - baseCount)
	for index, campId in ipairs(order) do
		local c = camps[campId]
		local center: any = nil
		for _, camp in layout.Camps do
			if "CAMP_" .. camp.Id == campId then center = camp; break end
		end
		if center and #c.Regulars > 0 then
			local wanted = math.min(budget, CampWaves.ExtraCount(c.Count, masters))
			for i = 1, wanted do
				local angle = i * 2.39996 + index
				local radius = 18 + (i % 2) * 5
				local x, z, terrace = TowerLayout.ClampToSpawnable(indexInBiome, center.X + math.cos(angle) * radius, center.Z + math.sin(angle) * radius)
				merged[Config.ExtraSlotBase + index * 100 + i] = {
					EnemyId = c.Regulars[(i - 1) % #c.Regulars + 1],
					X = x,
					Y = layout.Platforms[terrace].Y,
					Z = z,
					CampId = campId,
					LeashRadius = 60,
				}
			end
			budget -= wanted
		end
	end
	return merged
end

return table.freeze(CampWaves)
