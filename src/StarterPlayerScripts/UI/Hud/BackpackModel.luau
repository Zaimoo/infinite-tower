--!strict
-- Display rows derived from the player's synced profile.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local HeroCatalog = require(Config:WaitForChild("HeroCatalog"))
local ArtifactCatalog = require(Config:WaitForChild("ArtifactCatalog"))
local PitBalance = require(Config:WaitForChild("PitBalanceConfig"))

export type Tab = "Artifacts" | "Heroes" | "Materials"
export type Row = {
	Id: string, Name: string, Summary: string, Description: string, Status: string?,
	Icon: string, Color: Color3, Rarity: number, Stars: number, TemplateId: string?, Archetype: string?,
	ArtifactTemplateId: string?, AssignedArtifact: string?,
}

local GOLD = Color3.fromRGB(250, 211, 125)
local MATERIALS: { [string]: { Name: string, Description: string, Icon: string } } = {
	PromotionStone = { Name = PitBalance.Recipes.PromotionStone.Name, Description = "Used at the Pit to increase a hero's star rank.", Icon = "Gems" },
	SoulEssence = { Name = "Soul Essence", Description = "Earned by converting heroes at the Pit. Used in Pit material recipes.", Icon = "Summon" },
	ImprintCatalyst = { Name = PitBalance.Recipes.ImprintCatalyst.Name, Description = "Used for Focused Imprint at the Pit.", Icon = "Spark" },
}
local FORGE_ICONS = { IronGear = "Gear", RiftOrb = "Summon", AegisGem = "Gems", StarDust = "Spark", VoidPowder = "Summon" }
local ASSIGNMENTS = {
	FACILITY_GUARD_POST = "Guard Post", FACILITY_MARKET = "Market",
	FACILITY_TRAINING = "Training Grounds", FACILITY_GODS_BLESSING = "God's Blessing",
}

local function readable(id: string): string
	local words = id:gsub("^(hero_)", ""):gsub("^(art_)", ""):gsub("(%l)(%u)", "%1 %2"):gsub("_+", " ")
	return if words == string.upper(words) then string.lower(words):gsub("^%l", string.upper) else words:gsub("^%l", string.upper)
end

local function number(value: any, fallback: number): number
	return if type(value) == "number" and value == value and value >= 0 and value < math.huge then math.floor(value) else fallback
end

local function artifactName(item: any, id: string): string
	local seed = ArtifactCatalog.Seeds[item.TemplateId]
	return item.DisplayName or (seed and seed.DisplayName) or readable(item.TemplateId or id)
end

local function assignment(tag: string?): string
	if not tag or tag == "" or tag == "BENCHED" then return "Benched" end
	local slot = string.match(tag, "^SQUAD_SLOT_(%d+)$")
	if slot then return "Squad slot " .. slot end
	return ASSIGNMENTS[tag] or readable(tag)
end

local Model = {}

function Model.Build(profile: any, tab: Tab): { Row }?
	if not profile then return nil end
	local rows: { Row } = {}
	local heroes = profile.Heroes or {}
	local artifacts = profile.Artifacts or {}
	if tab == "Materials" then
		local materials = table.clone(profile.PitMaterials or {})
		materials.PromotionStone = number(materials.PromotionStone, 0)
		for id, amount in materials do
			local count = number(amount, 0)
			if type(id) ~= "string" or (id ~= "PromotionStone" and count == 0) then continue end
			local pit = MATERIALS[id]
			local forge = ArtifactCatalog.CraftingMaterials[id]
			table.insert(rows, {
				Id = id, Name = if pit then pit.Name elseif forge then forge.Name else readable(id),
				Summary = ("%d owned"):format(count),
				Description = if pit then pit.Description elseif forge then "Used in Forge recipes. " .. forge.Description else "Stored in your materials.",
				Icon = if pit then pit.Icon else FORGE_ICONS[id] or "Gems",
				Color = if forge then forge.Color else GOLD, Rarity = if id == "PromotionStone" then 1 else 0, Stars = 0,
			})
		end
	elseif tab == "Artifacts" then
		local equippedBy = {}
		for _, hero in heroes do
			if hero.EquippedArtifactUUID then equippedBy[hero.EquippedArtifactUUID] = hero end
		end
		for id, item in artifacts do
			local seed = ArtifactCatalog.Seeds[item.TemplateId]
			local rarity = number(item.Rarity, 1)
			local info = ArtifactCatalog.GetRarityInfo(rarity)
			local stars = number(item.Star, 1)
			local carrier = heroes[item.EquippedHeroUUID] or equippedBy[id]
			local weaponType = readable(item.Type or (seed and seed.Type) or "Weapon")
			table.insert(rows, {
				Id = id, Name = artifactName(item, id),
				Summary = ("%s  ·  %d★  ·  %s"):format(info.Name, stars, weaponType),
				Description = (seed and seed.Description) or "An artifact in your collection.",
				Status = if carrier then "Equipped by " .. (carrier.DisplayName or "a hero") else "Unequipped",
				Icon = "Forge", Color = info.Color, Rarity = rarity, Stars = stars, ArtifactTemplateId = item.TemplateId,
			})
		end
	else
		for id, hero in heroes do
			local seed = HeroCatalog.Seeds[hero.TemplateId]
			local rarity = number(hero.Rarity, HeroCatalog.RarityOf(hero.TemplateId))
			local stars = number(hero.Stars, 1)
			local item = artifacts[hero.EquippedArtifactUUID]
			local role = hero.Archetype or (seed and seed.Archetype) or "Hero"
			table.insert(rows, {
				Id = id, Name = hero.DisplayName or (seed and seed.DisplayName) or readable(hero.TemplateId or id),
				Summary = ("%s  ·  %d★  ·  Lv. %d"):format(HeroCatalog.RarityName(rarity), stars, number(hero.Level, 1)),
				Description = role,
				AssignedArtifact = if item then artifactName(item, "Artifact") else nil,
				ArtifactTemplateId = if item then item.TemplateId else nil,
				Status = assignment(hero.Assignment), Icon = "Squad", Color = GOLD, Rarity = rarity, Stars = stars,
				TemplateId = if seed then hero.TemplateId else nil, Archetype = role,
			})
		end
	end
	table.sort(rows, function(a, b)
		if a.Rarity ~= b.Rarity then return a.Rarity > b.Rarity end
		if a.Stars ~= b.Stars then return a.Stars > b.Stars end
		if a.Name ~= b.Name then return a.Name < b.Name end
		return a.Id < b.Id
	end)
	return rows
end

-- Compare only fields that affect the Backpack. Full profile syncs can resend equivalent records,
-- and Pit deltas mutate the client hero dictionary in place.
local HERO_FIELDS = { "TemplateId", "DisplayName", "Archetype", "Rarity", "Stars", "Level", "Assignment", "EquippedArtifactUUID" }
local ARTIFACT_FIELDS = { "TemplateId", "DisplayName", "Type", "Rarity", "Star", "EquippedHeroUUID" }

local function sameRecords(before: any, after: any, fields: { string }?): boolean
	for id, old in before do
		local current = after[id]
		if old ~= current then
			if current == nil or fields == nil then return false end
			for _, field in fields do
				if old[field] ~= current[field] then return false end
			end
		end
	end
	for id in after do
		if before[id] == nil then return false end
	end
	return true
end

function Model.Track(tab: Tab): (any) -> (boolean, { Row }?)
	local loaded = false
	local previousHeroes, previousArtifacts, previousMaterials = {}, {}, {}
	return function(profile: any): (boolean, { Row }?)
		if not profile then return false, nil end
		if tab == "Materials" then
			local materials = profile.PitMaterials or {}
			if loaded and sameRecords(previousMaterials, materials, nil) then return false, nil end
			previousMaterials = table.clone(materials)
		else
			local heroes = profile.Heroes or {}
			local artifacts = profile.Artifacts or {}
			if loaded and sameRecords(previousHeroes, heroes, HERO_FIELDS) and sameRecords(previousArtifacts, artifacts, ARTIFACT_FIELDS) then
				return false, nil
			end
			previousHeroes = table.clone(heroes)
			previousArtifacts = table.clone(artifacts)
		end
		loaded = true
		return true, Model.Build(profile, tab)
	end
end

return Model
