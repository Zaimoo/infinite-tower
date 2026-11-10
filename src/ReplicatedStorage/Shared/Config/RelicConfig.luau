--!strict
-- ReplicatedStorage/Shared/Config/RelicConfig.luau
-- Relics, the contested tower loot (GDD §5.5).
--
-- Four base tiers carry every gameplay number: payout, walk-speed penalty, jump lock, despawn and seal times.
--   Tier 1 Mana Geode (anything), Tier 2 Cursed Urn (anything), Tier 3 Abyssal Core (camp Elites only),
--   Tier 4 Calamity Heart (Alphas and Biome Bosses only). Drop chances live in TowerFloorConfig.RelicDrops.
-- Each biome reskins the four tiers with its own name, colour and description (40 relics). A biome relic is a
-- copy of its base tier with those three fields replaced, so the economy is set by the tiers alone.

export type Payout = { Gems: number, Gold: number, PromotionStones: number }

export type RelicSpec = {
	TierId: string, -- this relic's id (a base tier id or a biome relic id)
	BaseTierId: string, -- MANA_GEODE, CURSED_URN, ABYSSAL_CORE or CALAMITY_HEART
	BiomeTier: number, -- 1..4, matching the base tier
	BiomeIndex: number?, -- 1..10 for biome relics, nil for the base tiers
	DisplayName: string,
	Rarity: string,
	Color: Color3,
	VisualDescription: string,
	WalkSpeedPenalty: number,
	SpeedPenalty: number,
	DisableJump: boolean,
	DespawnSeconds: number,
	InitialLockSeconds: number,
	GoldValue: number,
	GemValue: number,
	Payout: Payout,
}

export type BiomeConfig = {
	Name: string,
	FloorRange: { number },
	DropTable: { string }, -- relic ids by tier, 1..4
}

local RelicConfig: any = {}

local function baseTier(spec: any): RelicSpec
	spec.BaseTierId = spec.TierId
	spec.SpeedPenalty = spec.WalkSpeedPenalty
	spec.GoldValue = spec.Payout.Gold
	spec.GemValue = spec.Payout.Gems
	return table.freeze(spec) :: any
end

RelicConfig.MANA_GEODE = baseTier({
	TierId = "MANA_GEODE",
	BiomeTier = 1,
	DisplayName = "Mana Geode",
	Rarity = "Common",
	Color = Color3.fromRGB(65, 210, 255),
	VisualDescription = "A cracked rock shell with cyan crystals bursting from the cavity.",
	WalkSpeedPenalty = 0.15,
	DisableJump = false,
	DespawnSeconds = 90,
	InitialLockSeconds = 5.0,
	Payout = { Gems = 100, Gold = 250, PromotionStones = 0 },
})

RelicConfig.CURSED_URN = baseTier({
	TierId = "CURSED_URN",
	BiomeTier = 2,
	DisplayName = "Cursed Urn",
	Rarity = "Rare",
	Color = Color3.fromRGB(255, 165, 45),
	VisualDescription = "A bronze amphora with glowing rune bands, iron straps and a sealed lid.",
	WalkSpeedPenalty = 0.25,
	DisableJump = false,
	DespawnSeconds = 120,
	InitialLockSeconds = 5.0,
	Payout = { Gems = 300, Gold = 1200, PromotionStones = 1 },
})

RelicConfig.ABYSSAL_CORE = baseTier({
	TierId = "ABYSSAL_CORE",
	BiomeTier = 3,
	DisplayName = "Abyssal Core",
	Rarity = "Elite Exclusive",
	Color = Color3.fromRGB(190, 65, 255),
	VisualDescription = "A violet void nucleus in a glass shell, crossed orbit rings and an obsidian cage.",
	WalkSpeedPenalty = 0.35,
	DisableJump = true,
	DespawnSeconds = 150,
	InitialLockSeconds = 5.0,
	Payout = { Gems = 1000, Gold = 4000, PromotionStones = 2 },
})

RelicConfig.CALAMITY_HEART = baseTier({
	TierId = "CALAMITY_HEART",
	BiomeTier = 4,
	DisplayName = "The Calamity Heart",
	Rarity = "Alpha Exclusive",
	Color = Color3.fromRGB(255, 30, 65),
	VisualDescription = "A crimson heart with arteries, dark veins and jagged crystal growths.",
	WalkSpeedPenalty = 0.45,
	DisableJump = true,
	DespawnSeconds = 180,
	InitialLockSeconds = 15.0,
	Payout = { Gems = 5000, Gold = 15000, PromotionStones = 5 },
})

RelicConfig.BaseTiers = table.freeze({ "MANA_GEODE", "CURSED_URN", "ABYSSAL_CORE", "CALAMITY_HEART" })

-- Biome skins, in tier order: Geode, Urn, Core, Heart. { Name, Color, Description }.
type Skin = { string | Color3 }
local BIOMES: { { Key: string, Name: string, Floors: { number }, Skins: { Skin } } } = {
	{ Key = "VERDANT", Name = "Verdant Ruins", Floors = { 1, 5 }, Skins = {
		{ "Overgrown Moss Geode", Color3.fromRGB(75, 181, 67), "A stone shell split open, green crystals tangled in moss." },
		{ "Cursed Verdant Urn", Color3.fromRGB(100, 160, 80), "A clay amphora wrapped in vines, its chained lid pulsing weakly." },
		{ "Rootbound Earth Core", Color3.fromRGB(180, 140, 60), "Compressed soil and root fibre caged in gold filigree." },
		{ "Heart of the Mossbound", Color3.fromRGB(220, 160, 50), "A living heart of amber sap and stone, beating through the moss." },
	} },
	{ Key = "FUNGAL", Name = "Fungal Hollow", Floors = { 6, 10 }, Skins = {
		{ "Bioluminescent Spore Geode", Color3.fromRGB(120, 230, 200), "A puffball husk packed with glowing teal spores." },
		{ "Mycelial Urn", Color3.fromRGB(170, 120, 220), "A pot laced with pale mycelium threads that creep over the lid." },
		{ "Hollowroot Spore Core", Color3.fromRGB(200, 90, 230), "A violet spore cluster suspended in a cage of rotted root." },
		{ "Heart of the Spore Matriarch", Color3.fromRGB(240, 110, 200), "A pulsing fungal heart crowned with morel ridges." },
	} },
	{ Key = "ASHEN", Name = "Ashen Dunes", Floors = { 11, 15 }, Skins = {
		{ "Vitrified Glass Geode", Color3.fromRGB(255, 200, 120), "Sand fused to amber glass by lightning, still warm." },
		{ "Sun-Scorched Urn", Color3.fromRGB(230, 140, 60), "A caravan urn blackened by the sun, sealed with tar." },
		{ "Sandstorm Core", Color3.fromRGB(255, 170, 40), "A whirling knot of sand held in a sandstone cage." },
		{ "Heart of the Sandstone Colossus", Color3.fromRGB(255, 120, 40), "A magma-veined heart carved from desert stone." },
	} },
	{ Key = "FROZEN", Name = "Frozen Citadel", Floors = { 16, 20 }, Skins = {
		{ "Rimefrost Geode", Color3.fromRGB(170, 230, 255), "A frost-rimed stone bursting with pale ice crystals." },
		{ "Glacial Urn", Color3.fromRGB(120, 190, 255), "An urn of blue ice, its runes frozen mid-glow." },
		{ "Permafrost Core", Color3.fromRGB(90, 160, 255), "A sphere of ancient ice that never melts, caged in iron." },
		{ "Heart of the Frostbound King", Color3.fromRGB(200, 240, 255), "A crowned heart of glacier glass, beating slow and cold." },
	} },
	{ Key = "INFERNAL", Name = "Infernal Foundry", Floors = { 21, 25 }, Skins = {
		{ "Slag Iron Geode", Color3.fromRGB(255, 120, 50), "A crust of cooled slag cracked over molten orange crystal." },
		{ "Ashen Crucible Urn", Color3.fromRGB(230, 90, 40), "A smelting crucible sealed with riveted iron, still glowing." },
		{ "Molten Reactor Core", Color3.fromRGB(255, 80, 20), "A churning ball of molten metal inside a furnace cage." },
		{ "Heart of the Ember Titan", Color3.fromRGB(255, 60, 30), "An anvil-forged heart pumping liquid fire." },
	} },
	{ Key = "THUNDER", Name = "Thunder Highlands", Floors = { 26, 30 }, Skins = {
		{ "Fulgurite Geode", Color3.fromRGB(150, 200, 255), "Lightning-glass spikes erupting from a scorched stone." },
		{ "Storm-Charged Urn", Color3.fromRGB(110, 170, 255), "A highland urn that crackles with trapped static." },
		{ "Lightning Nexus Core", Color3.fromRGB(180, 140, 255), "A bolt of lightning knotted into a sphere, caged in copper." },
		{ "Heart of the Storm Roc", Color3.fromRGB(230, 230, 120), "A feathered thunderheart that flashes with every beat." },
	} },
	{ Key = "CORRUPTED", Name = "Corrupted Grove", Floors = { 31, 35 }, Skins = {
		{ "Blightroot Geode", Color3.fromRGB(150, 200, 60), "A diseased knot of wood split open over sickly green crystal." },
		{ "Rotbloom Urn", Color3.fromRGB(170, 90, 140), "An urn choked by a rotting flower that breathes spores." },
		{ "Heartrot Core", Color3.fromRGB(120, 200, 40), "A blighted seed pod oozing green ichor inside a thorn cage." },
		{ "Heart of the Blight Sovereign", Color3.fromRGB(180, 230, 60), "A heart of twisted briar, weeping blight with every beat." },
	} },
	{ Key = "SUNKEN", Name = "Sunken Sanctuary", Floors = { 36, 40 }, Skins = {
		{ "Drowned Pearl Geode", Color3.fromRGB(120, 230, 230), "A barnacled stone opened on a cluster of sea-pearls." },
		{ "Tidebound Urn", Color3.fromRGB(60, 170, 200), "A temple urn crusted with coral, water still sloshing inside." },
		{ "Coral Abyss Core", Color3.fromRGB(40, 140, 220), "A deep-sea light trapped in a cage of living coral." },
		{ "Heart of the Tidal Leviathan", Color3.fromRGB(80, 220, 255), "A scaled heart that pulses like a tide." },
	} },
	{ Key = "ASTRAL", Name = "Astral Archives", Floors = { 41, 45 }, Skins = {
		{ "Aether Glass Geode", Color3.fromRGB(190, 170, 255), "A stone shell holding starlit aether glass." },
		{ "Phase-Shift Urn", Color3.fromRGB(150, 130, 255), "An archive urn that flickers half out of the world." },
		{ "Nexus Singularity Core", Color3.fromRGB(120, 90, 255), "A pinpoint singularity orbited by tiny rune rings." },
		{ "Heart of the Rift Warden", Color3.fromRGB(230, 200, 255), "A heart bound in astrolabe rings, ticking like a clock." },
	} },
	{ Key = "THRONE", Name = "Abyssal Throne", Floors = { 46, 50 }, Skins = { -- not "ABYSSAL": ABYSSAL_CORE is a base tier
		{ "Abyssal Trench Geode", Color3.fromRGB(200, 60, 90), "Black rock split over blood-red abyssal crystal." },
		{ "Sovereign's Cursed Urn", Color3.fromRGB(170, 30, 60), "A throne-room urn sealed with chains and a crimson sigil." },
		{ "Void Titan Core", Color3.fromRGB(140, 20, 200), "A shard of the void itself, howling inside an obsidian cage." },
		{ "Heart of the Crimson Overlord", Color3.fromRGB(255, 20, 50), "The Overlord's crowned heart, burning crimson." },
	} },
}

local TIER_SUFFIX = { "GEODE", "URN", "CORE", "HEART" }

RelicConfig.Biomes = {} :: { BiomeConfig }
RelicConfig.Items = {} :: { [string]: RelicSpec }

for biomeIndex, biome in ipairs(BIOMES) do
	local dropTable = {}
	for tier, skin in ipairs(biome.Skins) do
		local id = biome.Key .. "_" .. TIER_SUFFIX[tier]
		assert(RelicConfig[id] == nil and RelicConfig.Items[id] == nil, "Relic id collides with an existing relic: " .. id)
		local item = table.clone(RelicConfig[RelicConfig.BaseTiers[tier]]) :: any
		item.TierId = id
		item.BiomeIndex = biomeIndex
		item.DisplayName = skin[1] :: string
		item.Color = skin[2] :: Color3
		item.VisualDescription = skin[3] :: string
		RelicConfig.Items[id] = table.freeze(item)
		table.insert(dropTable, id)
	end
	table.insert(RelicConfig.Biomes, table.freeze({ Name = biome.Name, FloorRange = biome.Floors, DropTable = table.freeze(dropTable) }))
end
table.freeze(RelicConfig.Biomes)
table.freeze(RelicConfig.Items)

-- Direct lookup by id: RelicConfig[itemId].
for id, item in pairs(RelicConfig.Items) do
	RelicConfig[id] = item
end

-- The biome whose floors include floorId (1..50), or nil.
function RelicConfig.GetBiomeForFloor(floorId: number): BiomeConfig?
	for _, biome in ipairs(RelicConfig.Biomes) do
		if floorId >= biome.FloorRange[1] and floorId <= biome.FloorRange[2] then
			return biome
		end
	end
	return nil
end

function RelicConfig.GetItem(itemId: string): RelicSpec?
	return RelicConfig.Items[itemId] or RelicConfig[itemId]
end

function RelicConfig.GetBiomeRelics(biomeIndex: number): { RelicSpec }
	local biome = RelicConfig.Biomes[biomeIndex]
	local relics = {}
	for _, relicId in ipairs(biome and biome.DropTable or {}) do
		table.insert(relics, RelicConfig.Items[relicId])
	end
	return relics
end

return RelicConfig
