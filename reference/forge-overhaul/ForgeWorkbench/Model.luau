--!strict
-- Pure UI selectors. These do not grant permission: the server repeats every rule.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.Shared.Config.ArtifactCatalog)
local Stats = require(ReplicatedStorage.Shared.Util.StatFormulas)
local Types = require(script.Parent.Types)
type Artifact = Types.Artifact
type Hero = Types.Hero
type Snapshot = Types.Snapshot
type Filter = Types.Filter

local Model = {}

function Model.ownerIds(snapshot: Snapshot, artifactId: string): { string }
	local ids = {}
	local artifact = snapshot.Artifacts[artifactId]
	if artifact and artifact.EquippedHeroUUID then
		table.insert(ids, artifact.EquippedHeroUUID)
	end
	-- Fail protected when reciprocal pointers disagree, including a missing hero.
	for id, hero in snapshot.Heroes do
		if hero.EquippedArtifactUUID == artifactId and not table.find(ids, id) then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return ids
end

function Model.ownerText(snapshot: Snapshot, artifactId: string): string
	local owners = Model.ownerIds(snapshot, artifactId)
	if #owners == 0 then return "Unequipped" end
	if #owners > 1 then return "Equipped · sync required" end
	local hero = snapshot.Heroes[owners[1]]
	return if hero then string.format("Equipped · %s · Lv.%d · #%s", hero.DisplayName, hero.Level, string.sub(hero.UUID, -4)) else "Equipped · unavailable hero"
end

function Model.compatible(hero: Hero?, artifact: Artifact?): boolean
	return hero ~= nil and artifact ~= nil and Catalog.CanHeroEquip(hero.Archetype, artifact.Type)
end

function Model.power(artifact: Artifact): number
	return Catalog.CalculateEffectiveStats(artifact.Star, artifact.Rarity, nil, artifact.TemplateId)
end

function Model.materialReason(snapshot: Snapshot, targetId: string?, artifactId: string): string?
	local target = targetId and snapshot.Artifacts[targetId]
	local artifact = snapshot.Artifacts[artifactId]
	if not artifact then return "No longer owned" end
	if not target then return "Choose a target first" end
	if targetId == artifactId then return "Upgrade target · kept" end
	if #Model.ownerIds(snapshot, artifactId) > 0 then return "Protected · unequip before using" end
	if artifact.Locked then return "Protected · unlock before using" end
	if target.Star >= Catalog.MaxStars then return "Target is at maximum stars" end
	if target.Type ~= artifact.Type then return "Requires the same weapon type" end
	if target.Rarity ~= artifact.Rarity then return "Requires the same rarity" end
	return nil
end

function Model.materials(snapshot: Snapshot, targetId: string?, ids: { string }): { string }
	local target = targetId and snapshot.Artifacts[targetId]
	local count = if target then Catalog.GetFodderRequirement(target.Star) else 0
	local clean, seen = {}, {}
	for _, id in ids do
		if #clean < count and not seen[id] and not Model.materialReason(snapshot, targetId, id) then
			seen[id] = true
			table.insert(clean, id)
		end
	end
	return clean
end

function Model.autoFill(snapshot: Snapshot, targetId: string, selected: { string }): { string }
	local target = snapshot.Artifacts[targetId]
	if not target then return {} end
	local result = Model.materials(snapshot, targetId, selected)
	local candidates = {}
	for id, artifact in snapshot.Artifacts do
		if not table.find(result, id) and not Model.materialReason(snapshot, targetId, id) then
			table.insert(candidates, artifact)
		end
	end
	table.sort(candidates, function(a: Artifact, b: Artifact): boolean
		if a.Star ~= b.Star then return a.Star < b.Star end
		local aPower, bPower = Model.power(a), Model.power(b)
		if aPower ~= bPower then return aPower < bPower end
		return a.UUID < b.UUID
	end)
	local count = Catalog.GetFodderRequirement(target.Star)
	for _, artifact in candidates do
		if #result >= count then break end
		table.insert(result, artifact.UUID)
	end
	return result
end

function Model.upgradeReason(snapshot: Snapshot, targetId: string?, materialIds: { string }): string?
	local target = targetId and snapshot.Artifacts[targetId]
	if not target then return "Choose an artifact to upgrade" end
	local rule = Catalog.GetStarPromotionCost(target.Star)
	if not rule then return "Maximum 7 stars reached" end
	local materials = Model.materials(snapshot, targetId, materialIds)
	if #materials ~= #materialIds then return "Materials changed. Select eligible materials again." end
	if #materials ~= rule.Donors then
		return string.format("Choose %d more materials", math.max(0, rule.Donors - #materials))
	end
	if snapshot.Gold < rule.Gold then return "Not enough Gold" end
	if snapshot.Gems < rule.Gems then return "Not enough Gems" end
	return nil
end

function Model.equipReason(snapshot: Snapshot, heroId: string?, artifactId: string?): string?
	local hero = heroId and snapshot.Heroes[heroId]
	local artifact = artifactId and snapshot.Artifacts[artifactId]
	if not hero then return "Choose a hero" end
	if not artifact then return "Choose an artifact" end
	if not Model.compatible(hero, artifact) then return "This hero cannot use this weapon type" end
	local owners = Model.ownerIds(snapshot, artifact.UUID)
	if #owners > 1 or (#owners == 1 and not snapshot.Heroes[owners[1]]) then return "Equipment changed · refresh required" end
	if hero.EquippedArtifactUUID == artifactId then return "Already equipped on this hero" end
	return nil
end

function Model.equipLabel(snapshot: Snapshot, heroId: string?, artifactId: string?): string
	local hero = heroId and snapshot.Heroes[heroId]
	if not hero then return "Choose hero" end
	local owners = artifactId and Model.ownerIds(snapshot, artifactId) or {}
	if #owners > 0 and owners[1] ~= heroId then return "Move to " .. hero.DisplayName end
	return (if hero.EquippedArtifactUUID then "Replace on " else "Equip to ") .. hero.DisplayName
end

function Model.consequences(snapshot: Snapshot, heroId: string, artifactId: string): string
	local hero = snapshot.Heroes[heroId]
	local artifact = snapshot.Artifacts[artifactId]
	if not hero or not artifact then return "Inventory changed. Select again." end
	local parts = { artifact.DisplayName .. " → " .. hero.DisplayName .. "." }
	for _, ownerId in Model.ownerIds(snapshot, artifactId) do
		if ownerId ~= heroId then
			local owner = snapshot.Heroes[ownerId]
			table.insert(parts, (if owner then owner.DisplayName else "Previous hero") .. " will have an empty weapon slot.")
		end
	end
	local old = hero.EquippedArtifactUUID and snapshot.Artifacts[hero.EquippedArtifactUUID]
	if old and old.UUID ~= artifactId then table.insert(parts, old.DisplayName .. " returns to inventory.") end
	return table.concat(parts, " ")
end

function Model.heroLabel(hero: Hero): string
	return string.format("%s · Lv.%d · %s · %s", hero.DisplayName, hero.Level, hero.Archetype, string.sub(hero.UUID, -4))
end

function Model.sortedHeroes(snapshot: Snapshot): { Hero }
	local heroes = {}
	for _, hero in snapshot.Heroes do table.insert(heroes, hero) end
	table.sort(heroes, function(a: Hero, b: Hero): boolean
		if a.DisplayName ~= b.DisplayName then return a.DisplayName < b.DisplayName end
		return a.UUID < b.UUID
	end)
	return heroes
end

function Model.best(snapshot: Snapshot, heroId: string?): string?
	local hero = heroId and snapshot.Heroes[heroId]
	if not hero then return nil end
	local bestId, bestScore = nil, -math.huge
	for id, artifact in snapshot.Artifacts do
		-- Never suggest stealing from another hero as the default best action.
		local owners = Model.ownerIds(snapshot, id)
		if Model.compatible(hero, artifact) and (#owners == 0 or (#owners == 1 and owners[1] == heroId)) then
			local score = Stats.GetCombatSnapshot(hero, artifact).DPS
			if score > bestScore or (score == bestScore and (bestId == nil or id < bestId)) then
				bestId, bestScore = id, score
			end
		end
	end
	return bestId
end

function Model.inventory(snapshot: Snapshot, filter: Filter, heroId: string?): { Artifact }
	local query = string.lower(filter.Query)
	local result = {}
	local best = Model.best(snapshot, heroId)
	for id, artifact in snapshot.Artifacts do
		local owners = Model.ownerIds(snapshot, id)
		local heroMatches = heroId ~= nil and table.find(owners, heroId) ~= nil
		local ownership = filter.Ownership == "ALL"
			or (filter.Ownership == "EQUIPPED" and #owners > 0)
			or (filter.Ownership == "UNEQUIPPED" and #owners == 0)
			or (filter.Ownership == "HERO" and heroMatches)
		local searchText = string.lower(artifact.DisplayName .. " " .. artifact.Type .. " " .. Catalog.GetRarityInfo(artifact.Rarity).Name .. " " .. Model.ownerText(snapshot, id))
		if ownership and (filter.Rarity == 0 or artifact.Rarity == filter.Rarity)
			and (filter.WeaponType == "ALL" or artifact.Type == filter.WeaponType)
			and (query == "" or string.find(searchText, query, 1, true) ~= nil) then
			table.insert(result, artifact)
		end
	end
	table.sort(result, function(a: Artifact, b: Artifact): boolean
		if filter.Sort == "BEST" and (a.UUID == best) ~= (b.UUID == best) then return a.UUID == best end
		if filter.Sort == "RARITY" and a.Rarity ~= b.Rarity then return a.Rarity > b.Rarity end
		if filter.Sort == "STARS" and a.Star ~= b.Star then return a.Star > b.Star end
		if filter.Sort ~= "NAME" then
			local ap, bp = Model.power(a), Model.power(b)
			if ap ~= bp then return ap > bp end
		end
		if a.DisplayName ~= b.DisplayName then return a.DisplayName < b.DisplayName end
		return a.UUID < b.UUID
	end)
	return result
end

return Model
