--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.Shared.Config.ArtifactCatalog)
local StatFormulas = require(ReplicatedStorage.Shared.Util.StatFormulas)

export type Hero = {
	UUID: string,
	Assignment: string?,
	TemplateId: string,
	DisplayName: string,
	Archetype: string,
	Stars: number,
	Level: number,
	EquippedArtifactUUID: string?,
	[string]: any,
}

export type Artifact = {
	UUID: string,
	TemplateId: string,
	DisplayName: string,
	Type: string,
	Rarity: number,
	Star: number,
	Locked: boolean?,
	EquippedHeroUUID: string?,
	[string]: any,
}

export type PlanResult = {
	Changes: { [string]: string }, -- heroUUID -> newArtifactUUID
	TouchedArtifacts: { [string]: boolean }, -- all artifact UUIDs whose ownership changed
	BeforeSquadPower: number,
	AfterSquadPower: number,
	PowerDelta: number,
	ChangeCount: number,
	HasChanges: boolean,
}

local EquipBest = {}

function EquipBest.GetDeployedSlot(hero: Hero): number?
	local slot = string.match(hero.Assignment or "", "^SQUAD_SLOT_(%d+)$")
	local number = slot and tonumber(slot)
	return if number and number >= 1 then number else nil
end

function EquipBest.Plan(heroes: { [string]: Hero }, artifacts: { [string]: Artifact }): PlanResult
	local deployedHeroes: { Hero } = {}
	local deployedHeroIds: { [string]: boolean } = {}

	for _, hero in heroes do
		if EquipBest.GetDeployedSlot(hero) ~= nil then
			table.insert(deployedHeroes, hero)
			deployedHeroIds[hero.UUID] = true
		end
	end

	-- Compute current squad power before any changes
	local beforeSquadPower = 0
	for _, hero in deployedHeroes do
		local currentArt = hero.EquippedArtifactUUID and artifacts[hero.EquippedArtifactUUID]
		beforeSquadPower += StatFormulas.GetHeroPower(hero, currentArt)
	end

	-- Gather available pool:
	-- 1. Artifacts not equipped on ANY hero
	-- 2. Artifacts equipped on DEPLOYED heroes (can be swapped/upgraded)
	-- Never take artifacts from undeployed/bench heroes!
	local pool: { Artifact } = {}
	for _, artifact in artifacts do
		local ownerId = artifact.EquippedHeroUUID
		if not ownerId or ownerId == "" or deployedHeroIds[ownerId] then
			table.insert(pool, artifact)
		end
	end

	-- Sort deployed heroes by base hero power desc (strongest hero gets priority on best weapon)
	-- Tie-break with slot number
	table.sort(deployedHeroes, function(a: Hero, b: Hero): boolean
		local baseA = StatFormulas.GetHeroPower(a, nil)
		local baseB = StatFormulas.GetHeroPower(b, nil)
		if math.abs(baseA - baseB) > 0.001 then
			return baseA > baseB
		end
		local slotA = EquipBest.GetDeployedSlot(a) or 99
		local slotB = EquipBest.GetDeployedSlot(b) or 99
		return slotA < slotB
	end)

	local usedArtifacts: { [string]: boolean } = {}
	local assignments: { [string]: string } = {} -- heroUUID -> artifactUUID

	for _, hero in deployedHeroes do
		local bestArt: Artifact? = nil
		local bestPower: number = -1

		for _, artifact in pool do
			if not usedArtifacts[artifact.UUID] and Catalog.CanHeroEquip(hero.Archetype, artifact.Type) then
				local power = StatFormulas.GetHeroPower(hero, artifact)
				if power > bestPower then
					bestPower = power
					bestArt = artifact
				elseif power == bestPower and bestArt then
					-- Tie break deterministically by UUID
					if artifact.UUID < bestArt.UUID then
						bestArt = artifact
					end
				end
			end
		end

		if bestArt then
			usedArtifacts[bestArt.UUID] = true
			assignments[hero.UUID] = bestArt.UUID
		end
	end

	-- Compute changes vs current equipment
	local changes: { [string]: string } = {}
	local touchedArtifacts: { [string]: boolean } = {}
	local changeCount = 0

	for _, hero in deployedHeroes do
		local assignedArtId = assignments[hero.UUID]
		if assignedArtId and assignedArtId ~= hero.EquippedArtifactUUID then
			changes[hero.UUID] = assignedArtId
			changeCount += 1
			touchedArtifacts[assignedArtId] = true
			if hero.EquippedArtifactUUID then
				touchedArtifacts[hero.EquippedArtifactUUID] = true
			end
		end
	end

	-- Compute squad power after optimal assignments
	local afterSquadPower = 0
	for _, hero in deployedHeroes do
		local finalArtId = assignments[hero.UUID] or hero.EquippedArtifactUUID
		local finalArt = finalArtId and artifacts[finalArtId]
		afterSquadPower += StatFormulas.GetHeroPower(hero, finalArt)
	end

	local powerDelta = math.max(0, afterSquadPower - beforeSquadPower)

	return {
		Changes = changes,
		TouchedArtifacts = touchedArtifacts,
		BeforeSquadPower = beforeSquadPower,
		AfterSquadPower = afterSquadPower,
		PowerDelta = powerDelta,
		ChangeCount = changeCount,
		HasChanges = changeCount > 0 and powerDelta > 0,
	}
end

return EquipBest
