-- tests/mirror.spec.luau
-- Mirror heroes (The Gilded Mirror, docs/gilded-mirror-plan.md): no stats of their own, a share of the
-- Master's best normal hero, the last normal hero protected in The Pit, and promotion without levels.
local Catalog = require(nodes["ReplicatedStorage.Shared.Config.HeroCatalog"])
local Balance = require(nodes["ReplicatedStorage.Shared.Config.StatBalance"])
local ArtifactCatalog = require(nodes["ReplicatedStorage.Shared.Config.ArtifactCatalog"])
local Stats = require(nodes["ReplicatedStorage.Shared.Util.StatFormulas"])
local Math = require(nodes["ReplicatedStorage.Shared.Util.PitMath"])
local PitService = require(nodes["ServerScriptService.Core.PitService"])

local passed, failed = 0, 0
local function check(condition, message)
	assert(condition, message or "Expected condition to be true")
end
local function close(actual, expected, tolerance, message)
	check(math.abs(actual - expected) <= (tolerance or 1e-9), string.format("%s: expected %s, got %s", message or "Value differs", tostring(expected), tostring(actual)))
end
local function test(name, callback)
	local ok, result = pcall(callback)
	if ok then passed += 1; print("PASS " .. name)
	else failed += 1; print("FAIL " .. name .. "\n" .. tostring(result)) end
end

local function hero(id, seedId, fields)
	local seed = Catalog.Seeds[seedId]
	local value = {
		UUID = id, TemplateId = seed.HeroId, DisplayName = seed.DisplayName, Archetype = seed.Archetype, Rarity = seed.Rarity,
		Stars = 1, Level = 1, XP = 0, OverflowXP = 0, QualityScalar = 1,
		BaseHP = seed.NativeHP, BaseATK = seed.NativeATK, BaseLabor = seed.NativeLabor,
		AttackInterval = seed.AttackInterval, AttackRange = seed.AttackRange, CurrentStamina = 100, MaxStamina = 100,
		ComaUntilTimestamp = 0, IsHardAuditComa = false, Assignment = "BENCHED", Locked = false, Favorite = false,
		SynthesisHistory = { DonorsConsumed = 0, XPGained = 0, Promotions = 0 },
	}
	for key, override in pairs(fields or {}) do value[key] = override end
	return value
end

local function profileWith(heroes)
	local p = {
		SchemaVersion = 1, PlotIndex = 1, Currencies = { Gold = 10000000, Gems = 10000, ResearchPoints = 1000 },
		Heroes = {}, DeployedSquadOrder = {}, Facilities = {}, UnlockedResearch = { AdvancedStonecraft = true, MasterStonecraft = true },
		PitMaterials = { SoulEssence = 1000, PromotionStone = 1000 }, Social = {}, Artifacts = {},
	}
	for _, h in heroes do p.Heroes[h.UUID] = h end
	PitService.EnsureDefaults(p)
	return p
end

-- Power with the same rounding as GetHeroPower, before any weapon or Training Grounds.
local function rawPower(h)
	return Stats.GetHeroPower(h, nil, 1)
end

local MIRRORS = { "hero_isabelle", "hero_nyx", "hero_caspian", "hero_seraphine", "hero_rourke" }

test("every mirror seed is a premium mirror hero with its own rarity tier 7-11", function()
	for i, id in MIRRORS do
		local seed = Catalog.Seeds[id]
		check(seed.Mirror == true and seed.BannerOrigin == "PREMIUM", id .. " is a premium mirror hero")
		check(seed.Rarity == 6 + i, id .. " rarity")
		check(Catalog.IsMirror(id), id .. " IsMirror")
	end
	check(not Catalog.IsMirror("hero_astrea"), "normal heroes are not mirrors")
	check(Catalog.RarityName(8) == "Transcendent" and Catalog.RarityName(11) == "Immortal", "rarity names reach Immortal")
end)

test("the mirror share is 110-150% by rarity plus 2% per star", function()
	local expected = { hero_isabelle = 1.10, hero_nyx = 1.20, hero_caspian = 1.30, hero_seraphine = 1.40, hero_rourke = 1.50 }
	for id, base in expected do
		close(Stats.GetMirrorPercent(hero("m", id)), base, 1e-9, id .. " 1 star")
		close(Stats.GetMirrorPercent(hero("m", id, { Stars = 7 })), base + 0.12, 1e-9, id .. " 7 stars")
	end
	check(Stats.GetMirrorPercent(hero("m", "hero_isabelle", { Stars = 7 })) > Stats.GetMirrorPercent(hero("m", "hero_nyx")), "a 7-star Isabelle beats a 1-star Nyx")
end)

test("the source is the best normal hero, never another mirror hero", function()
	local weak, strong = hero("a", "hero_gide"), hero("b", "hero_astrea", { Stars = 3 })
	local p = profileWith({ weak, strong, hero("m", "hero_rourke"), hero("n", "hero_isabelle") })
	check(Stats.GetMirrorSource(p) == strong, "Astrea is the strongest normal hero")
	check(Stats.RefreshMirrorSources(p), "the first refresh writes sources")
	check(not Stats.RefreshMirrorSources(p), "a second refresh changes nothing")
	check(p.Heroes.m.MirrorSource.UUID == "b" and p.Heroes.n.MirrorSource.UUID == "b", "both mirrors copy Astrea")
	check(p.Heroes.a.MirrorSource == nil, "normal heroes carry no mirror source")
	-- A weapon does not count when choosing the source.
	p.Heroes.a.EquippedArtifactUUID = "w"
	p.Artifacts.w = { UUID = "w", TemplateId = "art_miner_pickaxe", Star = 7, Rarity = 16 }
	check(Stats.GetMirrorSource(p) == strong, "the source ignores weapons")
end)

test("mirror power is its share of the source, shaped by its own archetype", function()
	for _, id in MIRRORS do
		for _, stars in { 1, 4, 7 } do
			local source = hero("s", "hero_astrea", { Stars = 4, Level = 6 })
			local p = profileWith({ source, hero("m", id, { Stars = stars }) })
			Stats.RefreshMirrorSources(p)
			local m = p.Heroes.m
			local target = rawPower(source) * Stats.GetMirrorPercent(m)
			close(rawPower(m), target, target * 0.001 + 2, id .. " power at " .. stars .. " stars")
			-- HP:ATK follows the mirror hero's own seed, not the source's.
			local seed = Catalog.Seeds[id]
			local snap = Stats.GetCombatSnapshot(m)
			close(snap.Health / snap.AttackDamage, seed.BaseHP_1Star / seed.BaseATK_1Star, 0.01 * seed.BaseHP_1Star / seed.BaseATK_1Star, id .. " keeps its own shape")
		end
	end
end)

test("its own weapon and Training Grounds multiply the mirrored stats", function()
	local p = profileWith({ hero("s", "hero_astrea", { Stars = 2 }), hero("m", "hero_rourke") })
	Stats.RefreshMirrorSources(p)
	local m = p.Heroes.m
	local bare = Stats.GetCombatSnapshot(m)
	local axe = { UUID = "w", TemplateId = "art_miner_pickaxe", Star = 3, Rarity = 4 }
	local armed = Stats.GetCombatSnapshot(m, axe)
	check(armed.WeaponPower > 0, "the test weapon has power")
	local weaponMult = 1 + armed.WeaponPower / Balance.WeaponPowerDivisor
	-- bare.AttackDamage is already rounded, so allow one unit of rounding per multiplier step.
	close(armed.AttackDamage, bare.AttackDamage * weaponMult, weaponMult + 1, "weapon multiplies ATK")
	close(armed.Health, bare.Health, 0, "weapon leaves HP alone")
	local trained = Stats.GetCombatSnapshot(m, nil, false, false, 1.5)
	close(trained.Health, bare.Health * 1.5, 1, "training multiplies HP")
	close(trained.AttackDamage, bare.AttackDamage * 1.5, 1, "training multiplies ATK")
end)

test("promoting the source raises every mirror hero by the same x1.5", function()
	local source = hero("s", "hero_edis", { Stars = 2 })
	local p = profileWith({ source, hero("m", "hero_nyx") })
	Stats.RefreshMirrorSources(p)
	local before = rawPower(p.Heroes.m)
	local promoted = Math.Promote(source)
	p.Heroes.s = promoted
	check(Stats.RefreshMirrorSources(p), "the source changed")
	close(rawPower(p.Heroes.m) / before, rawPower(promoted) / rawPower(source), 0.002, "mirror follows the source's growth")
end)

test("labor copies the source at 100%, with the mirror hero's own facility synergy", function()
	local source = hero("s", "hero_gide", { Stars = 3, Level = 4 })
	local p = profileWith({ source, hero("m", "hero_isabelle", { Stars = 7 }) })
	Stats.RefreshMirrorSources(p)
	local copied = Stats.GetEffectiveLabor(source, "")
	close(Stats.GetEffectiveLabor(p.Heroes.m, "FACILITY_GUARD_POST"), copied, 0.01, "no bonus for stars")
	close(Stats.GetEffectiveLabor(p.Heroes.m, "FACILITY_MARKET"), math.round(copied * 1.25 * 100) / 100, 0.01, "own preferred facility")
end)

test("a mirror hero with no source falls back to a 1-star Common", function()
	local m = hero("m", "hero_caspian")
	local common = rawPower(hero("c", "hero_gide", { Rarity = 1 }))
	close(rawPower(m), common * 1.30, common * 0.01 + 2, "fallback share")
end)

test("the last normal hero can't be a Pit donor, alone or with others", function()
	local service = PitService.new({ GetProfile = function() return nil end })
	local only = profileWith({ hero("a", "hero_gide"), hero("m", "hero_isabelle"), hero("n", "hero_isabelle") })
	local status = service:DonorStatus(only, only.Heroes.a)
	check(not status.EligibleDonor and status.Reason == PitService.LastNormalHeroReason, "the only normal hero is protected")
	check(service:DonorStatus(only, only.Heroes.n).EligibleDonor, "a duplicate mirror hero can still be used")

	local two = profileWith({ hero("a", "hero_gide"), hero("b", "hero_jenna"), hero("c", "hero_shurn"), hero("m", "hero_isabelle") })
	check(service:DonorStatus(two, two.Heroes.a).EligibleDonor, "one of several normal heroes is fine")
	local preview = service:Build(two, { Action = "CONVERSION", Donors = { "a", "b", "c" } })
	check(not preview.CanCommit and preview.Reason == PitService.LastNormalHeroReason, "consuming every normal hero at once is refused")
	local ok = service:Build(two, { Action = "CONVERSION", Donors = { "a", "b" } })
	check(ok.CanCommit, "keeping one normal hero is allowed: " .. tostring(ok.Reason))
end)

test("mirror heroes promote without a level and gain 2% a star, but never level", function()
	local service = PitService.new({ GetProfile = function() return nil end })
	local p = profileWith({ hero("s", "hero_astrea", { Stars = 3 }), hero("m", "hero_seraphine", { Stars = 2 }), hero("d", "hero_jenna") })
	Stats.RefreshMirrorSources(p)
	local preview = service:Build(p, { Action = "PROMOTION", Recipient = "m" })
	check(preview.CanCommit, "promotes at level 1: " .. tostring(preview.Reason))
	check(#preview.Requirements == 0, "no level requirement")
	close(preview.Before.MirrorPercent, 1.42, 1e-9, "before")
	close(preview.After.MirrorPercent, 1.44, 1e-9, "after")
	check(preview.After.HP > preview.Before.HP, "promotion raises HP")
	local normal = service:Build(p, { Action = "PROMOTION", Recipient = "s" })
	check(not normal.CanCommit, "normal heroes still need the level cap")

	local synth = service:Build(p, { Action = "SYNTHESIS", Recipient = "m", Donors = { "d" } })
	check(not synth.CanCommit, "mirror heroes can't take synthesis EXP")
	check(not service:RecipientStatus(p, p.Heroes.m).Eligible, "mirror heroes aren't EXP recipients")

	local xpService = PitService.new({ GetProfile = function() return p end, Clock = function() return 0 end })
	p.Heroes.m.Assignment = "SQUAD_SLOT_1"
	local granted, reason = xpService:GrantCombatXP("player", "m", 100)
	check(not granted and reason == "Mirror heroes don't level.", "no combat EXP")
end)

print(string.format("mirror: %d passed, %d failed", passed, failed))
if failed > 0 then error(string.format("%d mirror tests failed", failed)) end
