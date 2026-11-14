--!strict
-- tests/anvil.spec.luau
-- Unit & regression checks for The Gilded Anvil (docs/gilded-anvil-plan.md):
--   1. Six Tier-8 Gildforged seeds (1 per archetype, 10,000 Power at 1★ -> 160,000 at 7★, unsellable)
--   2. WeaponVfxConfig Band 6 profiles & raised Band 5 for tiers 8-11
--   3. AnvilBanner Focus odds (40% / 12%), 10-pull Focus guarantee, Spark 60-pull counter & claim
--   4. ShopConfig.Anvil offers (49 R$ / 449 R$) and 135 Gems/pull restricted conversion
--   5. WeaponPromotion cross-type Tier-8 promotion & HeroSockets/WeaponModelBuilder wiring

local function mod(pathKey: string, fallback: Instance)
	if type(nodes) == "table" and nodes[pathKey] then
		return require(nodes[pathKey])
	end
	return require(fallback :: any)
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArtifactCatalog = mod("ReplicatedStorage.Shared.Config.ArtifactCatalog", ReplicatedStorage.Shared.Config.ArtifactCatalog)
local WeaponVfxConfig = mod("ReplicatedStorage.Shared.Config.WeaponVfxConfig", ReplicatedStorage.Shared.Config.WeaponVfxConfig)
local AnvilBanner = mod("ReplicatedStorage.Shared.Util.AnvilBanner", ReplicatedStorage.Shared.Util.AnvilBanner)
local ShopConfig = mod("ReplicatedStorage.Shared.Config.ShopConfig", ReplicatedStorage.Shared.Config.ShopConfig)
local Promotion = mod("ReplicatedStorage.Shared.Util.WeaponPromotion", ReplicatedStorage.Shared.Util.WeaponPromotion)
local HeroSockets = mod("ReplicatedStorage.Assets.HeroRig.HeroSockets", ReplicatedStorage.Assets.HeroRig.HeroSockets)
local WeaponModelBuilder = if type(nodes) ~= "table" or nodes["ReplicatedStorage.Assets.WeaponModelBuilder"]
	then mod("ReplicatedStorage.Assets.WeaponModelBuilder", ReplicatedStorage.Assets.WeaponModelBuilder)
	else nil

local passed, failed = 0, 0
local function check(condition: any, message: string?)
	assert(condition, message or "Expected condition to be true")
end
local function close(actual: number, expected: number, tolerance: number, message: string?)
	check(math.abs(actual - expected) <= tolerance, string.format("%s: expected %s, got %s", message or "Value differs", tostring(expected), tostring(actual)))
end
local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print("PASS " .. name)
	else
		failed += 1
		print("FAIL " .. name .. ": " .. tostring(err))
		error(err)
	end
end

local GILD_IDS = {
	SWORD_SHIELD = "art_gild_dawnwarden_oath",
	DAGGERS = "art_gild_eclipse_sisters",
	BOW = "art_gild_aurora_skyhook",
	AXE = "art_gild_wyrmheart_cleaver",
	STAFF = "art_gild_ninth_sky_orrery",
	TOME = "art_gild_evergarden_codex",
}

test("Six Tier-8 Gildforged seeds exist (1 per archetype), scale 10K->160K, and cannot be sold", function()
	check(#ArtifactCatalog.AnvilOrder == 6, "6 AnvilOrder items")
	for weaponType, id in pairs(GILD_IDS) do
		local seed = ArtifactCatalog.Seeds[id]
		check(seed ~= nil, "Missing Gildforged seed " .. id)
		check(seed.Type == weaponType, id .. " weapon type")
		check(seed.RarityTier == 8, id .. " tier 8")
		check(seed.Variant == "Gildforged", id .. " Variant Gildforged")
		check(ArtifactCatalog.IsGildforged(id), id .. " IsGildforged")

		local p1 = ArtifactCatalog.GetStatBreakdown(id, 1, 8).Power
		local p7 = ArtifactCatalog.GetStatBreakdown(id, 7, 8).Power
		check(p1 == 10000, id .. " 1★ Power == 10,000, got " .. tostring(p1))
		check(p7 == 160000, id .. " 7★ Power == 160,000, got " .. tostring(p7))
		check(ArtifactCatalog.CalculateSellPrice(8, 1, id) == 0, id .. " sell price at 1★ == 0")
		check(ArtifactCatalog.CalculateSellPrice(8, 7, id) == 0, id .. " sell price at 7★ == 0")
	end
	check(ArtifactCatalog.CalculateSellPrice(8, 1) == 0, "tier >= 8 without id still returns 0")
	check(not ArtifactCatalog.IsGildforged("art_iron_broadsword"), "normal weapon not Gildforged")
	check(ArtifactCatalog.CalculateSellPrice(7, 1, "art_book_of_primordial_genesis") == 40000, "tier 7 normal sell price unchanged")
end)

test("WeaponVfxConfig gives Band 6 to Gildforged relics and raises tiers 8-11 to Band 5", function()
	for tier = 8, 11 do
		check(WeaponVfxConfig.RarityBands[tier] == 5, "tier " .. tier .. " raised to Band 5")
	end
	local seenElem = {}
	for _, id in pairs(GILD_IDS) do
		local prof = WeaponVfxConfig.GetProfile(id, 8)
		check(prof.Band == 6, id .. " Band == 6")
		check(prof.MoteRate == 18 and prof.AuraRate == 18, id .. " Band 6 emitter rates")
		check(prof.LightRange == 8.5 and math.abs(prof.LightBrightness - 0.90) < 1e-6, id .. " Band 6 light")
		check(prof.Element ~= "PHYSICAL" and not seenElem[prof.Element], id .. " bespoke unique element")
		seenElem[prof.Element] = true
	end
end)

test("AnvilBanner pulls match 40% Focus / 12% off-Focus and 10-pull guarantees Focus", function()
	local n = 10000
	local counts: { [string]: number } = {}
	for i = 1, n do
		local r = (i - 0.5) / n
		local picked = AnvilBanner.Roll(1, "AXE", function() return r end)[1]
		counts[picked] = (counts[picked] or 0) + 1
	end
	close((counts[GILD_IDS.AXE] or 0) / n, 0.40, 0.005, "Focus AXE rate")
	for wType, id in pairs(GILD_IDS) do
		if wType ~= "AXE" then
			close((counts[id] or 0) / n, 0.12, 0.005, "Off-Focus " .. wType .. " rate")
		end
	end

	-- 10-pull guarantee when first 9 rolls miss Focus
	local ten = AnvilBanner.Roll(10, "BOW", function() return 0.99 end)
	check(#ten == 10, "ten pulls returned")
	for pull = 1, 9 do
		check(ten[pull] ~= GILD_IDS.BOW, "pull " .. pull .. " missed Focus")
	end
	check(ten[10] == GILD_IDS.BOW, "tenth pull guarantees Focus BOW")

	-- Single pull has no guarantee
	local one = AnvilBanner.Roll(1, "BOW", function() return 0.99 end)
	check(one[1] ~= GILD_IDS.BOW, "single pull has no Focus guarantee")
end)

test("AnvilBanner Spark counter banks every 60 pulls, sets Focus, and repairs bad saves", function()
	local p: any = {}
	local spark = AnvilBanner.EnsureSpark(p)
	check(p.AnvilSpark == spark and spark.Pulls == 0 and spark.Selections == 0 and spark.Focus == "SWORD_SHIELD", "created")
	local okFocus, resolvedFocus = AnvilBanner.SetFocus(p, GILD_IDS.STAFF)
	check(okFocus and resolvedFocus == "STAFF" and spark.Focus == "STAFF", "SetFocus accepts templateId")
	check(not AnvilBanner.SetFocus(p, "RING"), "SetFocus rejects invalid type")

	check(AnvilBanner.AddPulls(spark, 59) == 0 and spark.Pulls == 59, "59 pulls")
	check(AnvilBanner.AddPulls(spark, 10) == 1 and spark.Pulls == 9 and spark.Selections == 1, "60th pull banks 1 pick")
	local claimed, claimedId = AnvilBanner.ClaimSpark(p, "TOME")
	check(claimed and claimedId == GILD_IDS.TOME and spark.Selections == 0, "ClaimSpark redeems pick for TOME")
	check(not AnvilBanner.ClaimSpark(p, "BOW"), "cannot claim with 0 selections")

	p.AnvilSpark = { Pulls = 0 / 0, Selections = -5, Focus = "INVALID" }
	local repaired = AnvilBanner.EnsureSpark(p)
	check(repaired.Pulls == 0 and repaired.Selections == 0 and repaired.Focus == "SWORD_SHIELD", "repairs NaN/negative/invalid")
end)

test("ShopConfig.Anvil defines 49 R$ / 449 R$ packs and converts restricted purchases at 135 Gems/pull", function()
	local one = ShopConfig.ById("pack_anvil_1")
	local ten = ShopConfig.ById("pack_anvil_10")
	check(one and one.RobuxPrice == 49 and one.Grant.Amount == 1 and one.Grant.Banner == "GILDED_ANVIL", "1x pack")
	check(ten and ten.RobuxPrice == 449 and ten.WasPrice == 490 and ten.Grant.Amount == 10 and ten.Grant.Banner == "GILDED_ANVIL", "10x pack")
	local restrictedGrant = ShopConfig.SafeGrant(ten.Grant, true)
	check(restrictedGrant.Kind == "Gems" and restrictedGrant.Amount == 1350, "restricted 10x -> 1350 Gems")
	check(ShopConfig.SafeGrant(ten.Grant, false).Kind == "Summons", "unrestricted stays Summons")
end)

test("Gildforged Tier-8 weapons promote together and resolve sockets & builder templates", function()
	local profile = {
		Currencies = { Gold = 10000, Gems = 0 },
		Heroes = {},
		Artifacts = {
			a1 = { UUID = "a1", TemplateId = GILD_IDS.SWORD_SHIELD, Rarity = 8, Star = 1, Locked = false },
			a2 = { UUID = "a2", TemplateId = GILD_IDS.AXE, Rarity = 8, Star = 1, Locked = false },
			n7 = { UUID = "n7", TemplateId = "art_world_carver", Rarity = 7, Star = 1, Locked = false },
		},
	}
	check(not Promotion.IsDonorFor(profile.Artifacts.a1, profile.Artifacts.n7), "tier-7 donor rejected")
	check(Promotion.IsDonorFor(profile.Artifacts.a1, profile.Artifacts.a2), "tier-8 donor accepted across archetypes")
	local ok, _, newStar = Promotion.Promote(profile, "a1", { "a2" })
	check(ok and newStar == 2 and profile.Artifacts.a2 == nil and profile.Currencies.Gold == 9500, "promoted to 2★")

	for weaponType, id in pairs(GILD_IDS) do
		local prefab, resolvedType = HeroSockets.ResolvePrefab(id, nil, ArtifactCatalog.Seeds)
		check(prefab == id and resolvedType == weaponType, "HeroSockets resolves " .. id)
		if WeaponModelBuilder then
			check(WeaponModelBuilder.IsGildedTemplate(id), "WeaponModelBuilder marks " .. id .. " Gildforged")
		end
	end
end)

print(string.format("anvil.spec: %d passed, %d failed", passed, failed))
