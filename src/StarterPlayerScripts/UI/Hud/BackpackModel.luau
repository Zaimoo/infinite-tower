--!strict
-- Display rows derived from the player's synced profile.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local HeroCatalog = require(Config:WaitForChild("HeroCatalog"))
local StatFormulas = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("StatFormulas"))
local ArtifactCatalog = require(Config:WaitForChild("ArtifactCatalog"))
local InventoryCapacity = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("InventoryCapacity"))
local PotionConfig = require(Config:WaitForChild("PotionConfig"))
local PotionRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("PotionRules"))

export type Tab = "Artifacts" | "Heroes" | "Materials" | "Potions"
export type Row = {
	Id: string, Name: string, Summary: string, Description: string, Status: string?,
	Icon: string, Color: Color3, Rarity: number, Stars: number, TemplateId: string?, Archetype: string?,
	ArtifactTemplateId: string?, AssignedArtifact: string?,
	PotionId: string?, PotionEffect: string?, Owned: number?, -- Potions tab (GDD §4.9)
	Badge: string?, -- the short line under a grid slot: stars, level or a stack count
	Marked: boolean?, -- in use: an equipped artifact, a squad hero, a running boost
}
export type Sort = "Rarity" | "Stars" | "Name"

local GOLD = Color3.fromRGB(250, 211, 125)
local MATERIALS: { [string]: { Name: string, Description: string, Icon: string } } = {
	PromotionStone = { Name = "Promotion Stone", Description = "Earned from Floor Alphas, Biome Bosses, and High-Tier Relic Extractions. Used at The Pit to ascend a hero's Star Rank (up to 7★).", Icon = "Gems" },
}
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
Model.Sorts = { "Rarity", "Stars", "Name" } :: { Sort }

-- How many heroes and artifacts the player holds against the inventory caps (50 each, raised by the
-- Storage branch of the Fortress Tree). Heroes working in a facility are not in the backpack and don't
-- count. Summons that would go past a cap are refused by the server.
export type Capacity = { Have: number, Max: number }
function Model.Capacity(profile: any): { Heroes: Capacity, Artifacts: Capacity }
	local tree = profile and profile.FortressTree
	return {
		Heroes = { Have = InventoryCapacity.HeroCount(profile), Max = InventoryCapacity.HeroCap(tree) },
		Artifacts = { Have = InventoryCapacity.ArtifactCount(profile), Max = InventoryCapacity.ArtifactCap(tree) },
	}
end

function Model.Build(profile: any, tab: Tab): { Row }?
	if not profile then return nil end
	local rows: { Row } = {}
	local heroes = profile.Heroes or {}
	local artifacts = profile.Artifacts or {}
	if tab == "Potions" then
		-- Owned potions, plus any whose boost is running (so its timer stays visible at zero owned).
		for index, id in PotionConfig.Order do
			local potion = PotionConfig.Potions[id]
			local owned = PotionRules.Owned(profile, id)
			if owned <= 0 and PotionRules.Remaining(profile, potion.Effect) <= 0 then continue end
			table.insert(rows, {
				Id = id, Name = potion.Name,
				Summary = ("%d owned  ·  %s  ·  %d min"):format(owned, potion.Summary, potion.Minutes),
				Description = potion.Description .. " Boost time only counts down while you are in the game.",
				Icon = potion.Icon, Color = potion.Tint, Rarity = #PotionConfig.Order - index, Stars = 0,
				PotionId = id, PotionEffect = potion.Effect, Owned = owned, Badge = "×" .. owned,
			})
		end
	elseif tab == "Materials" then
		local materials = table.clone(profile.PitMaterials or {})
		materials.PromotionStone = number(materials.PromotionStone, 0)
		for id, amount in materials do
			local count = number(amount, 0)
			if type(id) ~= "string" or (id ~= "PromotionStone" and count == 0) then continue end
			local pit = MATERIALS[id]
			table.insert(rows, {
				Id = id, Name = if pit then pit.Name else readable(id),
				Summary = ("%d owned"):format(count),
				Description = if pit then pit.Description else "Stored in your materials.",
				Icon = if pit then pit.Icon else "Gems",
				Color = GOLD, Rarity = if id == "PromotionStone" then 1 else 0, Stars = 0, Badge = "×" .. count,
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
				Badge = stars .. "★", Marked = carrier ~= nil,
			})
		end
	else
		for id, hero in heroes do
			if InventoryCapacity.IsInFacility(hero) then continue end -- lives in its facility until unassigned
			local seed = HeroCatalog.Seeds[hero.TemplateId]
			local rarity = number(hero.Rarity, HeroCatalog.RarityOf(hero.TemplateId))
			local stars = number(hero.Stars, 1)
			local item = artifacts[hero.EquippedArtifactUUID]
			local role = hero.Archetype or (seed and seed.Archetype) or "Hero"
			table.insert(rows, {
				Id = id, Name = hero.DisplayName or (seed and seed.DisplayName) or readable(hero.TemplateId or id),
				Summary = ("%s  ·  %d★  ·  %s"):format(HeroCatalog.RarityName(rarity), stars,
					if StatFormulas.IsMirror(hero) then StatFormulas.LevelText(hero) else ("Lv. %d"):format(number(hero.Level, 1))),
				Description = if StatFormulas.IsMirror(hero) then role .. " · " .. (StatFormulas.MirrorDescription(hero) :: string) else role,
				AssignedArtifact = if item then artifactName(item, "Artifact") else nil,
				ArtifactTemplateId = if item then item.TemplateId else nil,
				Status = assignment(hero.Assignment), Icon = "Squad", Color = GOLD, Rarity = rarity, Stars = stars,
				TemplateId = if seed then hero.TemplateId else nil, Archetype = role,
				Badge = if StatFormulas.IsMirror(hero) then stars .. "★" else ("%d★ Lv %d"):format(stars, number(hero.Level, 1)),
				Marked = string.find(hero.Assignment or "", "^SQUAD_SLOT_") ~= nil,
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

-- A sorted copy for the grid. Rarity is Build's own order; the others fall back to it on ties.
function Model.Sorted(rows: { Row }, sort: Sort): { Row }
	local out = table.clone(rows)
	if sort == "Rarity" then return out end
	local order: { [Row]: number } = {}
	for i, row in rows do order[row] = i end
	table.sort(out, function(a, b)
		if sort == "Stars" and a.Stars ~= b.Stars then return a.Stars > b.Stars end
		if sort == "Name" and a.Name ~= b.Name then return a.Name < b.Name end
		return order[a] < order[b]
	end)
	return out
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
	local previousPotions = ""
	return function(profile: any): (boolean, { Row }?)
		if not profile then return false, nil end
		if tab == "Potions" then
			-- Counts and which boosts are running; the time left is drawn live by the panel.
			local parts = {}
			for _, id in PotionConfig.Order do
				table.insert(parts, PotionRules.Owned(profile, id) .. (if PotionRules.Remaining(profile, PotionConfig.Potions[id].Effect) > 0 then "+" else ""))
			end
			local signature = table.concat(parts, ",")
			if loaded and signature == previousPotions then return false, nil end
			previousPotions = signature
		elseif tab == "Materials" then
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
