--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EquipBest = require(ReplicatedStorage.Shared.Util.EquipBest)
local Catalog = require(ReplicatedStorage.Shared.Config.ArtifactCatalog)

local function bow(id: string, star: number, rarity: number, owner: string?)
	return {
		UUID = id,
		TemplateId = "art_crystal_greatbow",
		DisplayName = "Crystal Greatbow",
		Type = "BOW",
		Rarity = rarity,
		Star = star,
		Locked = false,
		EquippedHeroUUID = owner,
	}
end

local function sword(id: string, star: number, rarity: number, owner: string?)
	return {
		UUID = id,
		TemplateId = "art_crystal_claymore",
		DisplayName = "Crystal Claymore",
		Type = "GREATSWORD",
		Rarity = rarity,
		Star = star,
		Locked = false,
		EquippedHeroUUID = owner,
	}
end

local function marksman(id: string, slot: number?, equippedArt: string?)
	return {
		UUID = id,
		TemplateId = "hero_jenna",
		DisplayName = "Jenna",
		Archetype = "Marksman",
		Stars = 1,
		Level = 10,
		Assignment = if slot then "SQUAD_SLOT_" .. slot else nil,
		EquippedArtifactUUID = equippedArt,
	}
end

local function vanguard(id: string, slot: number?, equippedArt: string?)
	return {
		UUID = id,
		TemplateId = "hero_elena",
		DisplayName = "Elena",
		Archetype = "Vanguard",
		Stars = 1,
		Level = 10,
		Assignment = if slot then "SQUAD_SLOT_" .. slot else nil,
		EquippedArtifactUUID = equippedArt,
	}
end

-- Test 1: Deployed hero gets better unequipped weapon
do
	local heroes = {
		h1 = marksman("h1", 1, "bow1"),
	}
	local artifacts = {
		bow1 = bow("bow1", 1, 1, "h1"),
		bow2 = bow("bow2", 3, 3, nil),
	}
	local plan = EquipBest.Plan(heroes, artifacts)
	assert(plan.HasChanges, "Expected plan to have changes")
	assert(plan.Changes["h1"] == "bow2", "Hero should be assigned bow2")
	assert(plan.ChangeCount == 1, "Expected 1 change")
	assert(plan.PowerDelta > 0, "Expected positive power delta")
	print("PASS: EquipBest assigns better unequipped weapon to deployed hero")
end

-- Test 2: Does NOT steal from undeployed bench heroes
do
	local heroes = {
		deployed = marksman("deployed", 1, nil),
		bench = marksman("bench", nil, "bench_bow"),
	}
	local artifacts = {
		bench_bow = bow("bench_bow", 4, 4, "bench"),
		spare_bow = bow("spare_bow", 1, 1, nil),
	}
	local plan = EquipBest.Plan(heroes, artifacts)
	assert(plan.Changes["deployed"] == "spare_bow", "Deployed hero must get spare_bow, NOT bench_bow")
	assert(plan.Changes["bench"] == nil, "Bench hero must not be modified")
	print("PASS: EquipBest never steals from bench heroes")
end

-- Test 3: Incompatible weapons are rejected
do
	local heroes = {
		h1 = vanguard("h1", 1, nil),
	}
	local artifacts = {
		bow1 = bow("bow1", 5, 5, nil),
	}
	local plan = EquipBest.Plan(heroes, artifacts)
	assert(not plan.HasChanges, "Vanguard cannot equip bow")
	assert(plan.ChangeCount == 0, "No changes expected")
	print("PASS: Incompatible weapons are not assigned")
end

-- Test 4: Already optimal squad has no changes
do
	local heroes = {
		h1 = marksman("h1", 1, "bow_best"),
	}
	local artifacts = {
		bow_best = bow("bow_best", 5, 5, "h1"),
		bow_worse = bow("bow_worse", 1, 1, nil),
	}
	local plan = EquipBest.Plan(heroes, artifacts)
	assert(not plan.HasChanges, "Squad is already optimal")
	assert(plan.ChangeCount == 0, "Expected 0 changes")
	assert(plan.PowerDelta == 0, "Expected 0 power delta")
	print("PASS: Already optimal squad returns no changes")
end

print("ALL EquipBest unit tests passed successfully!")
return true
