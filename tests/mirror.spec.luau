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
		PitMaterials = { PromotionStone = 1000 }, Social = {}, Artifacts = {},
	}
	for _, h in heroes do p.Heroes[h.UUID] = h end
	PitService.EnsureDefaults(p)
	return p
end

-- Power with the same rounding as GetHeroPower, before any weapon or Training Grounds.
local function rawPower(h)
	return Stats.GetHeroPower(h, nil, 1)
end

local MIRRORS = { "hero_isabelle", "hero_nyx", "hero_caspian", "hero_seraphine", "hero_rook" }

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
	local expected = { hero_isabelle = 1.10, hero_nyx = 1.20, hero_caspian = 1.30, hero_seraphine = 1.40, hero_rook = 1.50 }
	for id, base in expected do
		close(Stats.GetMirrorPercent(hero("m", id)), base, 1e-9, id .. " 1 star")
		close(Stats.GetMirrorPercent(hero("m", id, { Stars = 7 })), base + 0.12, 1e-9, id .. " 7 stars")
	end
	check(Stats.GetMirrorPercent(hero("m", "hero_isabelle", { Stars = 7 })) > Stats.GetMirrorPercent(hero("m", "hero_nyx")), "a 7-star Isabelle beats a 1-star Nyx")
end)

test("the source is the best normal hero, never another mirror hero", function()
	local weak, strong = hero("a", "hero_gide"), hero("b", "hero_astrea", { Stars = 3 })
	local p = profileWith({ weak, strong, hero("m", "hero_rook"), hero("n", "hero_isabelle") })
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
	local p = profileWith({ hero("s", "hero_astrea", { Stars = 2 }), hero("m", "hero_rook") })
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
	local preview = service:Build(two, { Action = "SYNTHESIS", Recipient = "m", Donors = { "a", "b", "c" } })
	check(not preview.CanCommit and preview.Reason == PitService.LastNormalHeroReason, "consuming every normal hero at once is refused")
	local ok = service:Build(two, { Action = "SYNTHESIS", Recipient = "c", Donors = { "a", "b" } })
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

local MirrorBanner = require(nodes["ReplicatedStorage.Shared.Util.MirrorBanner"])
local ShopConfig = require(nodes["ReplicatedStorage.Shared.Config.ShopConfig"])

test("pulls follow the banner rates and never land below Isabelle", function()
	local n, counts = 10000, {}
	local i = 0
	local tiers = MirrorBanner.RollTiers(n, function() i += 1; return (i - 0.5) / n end)
	for _, tier in tiers do counts[tier] = (counts[tier] or 0) + 1 end
	for tier = 1, 6 do check(counts[tier] == nil, "no tier " .. tier) end
	for tier = 7, 11 do
		close(counts[tier] / n, Catalog.MirrorBanner.Rates[tier], 0.002, "tier " .. tier .. " rate")
		check(Catalog.Seeds[MirrorBanner.HeroForTier(tier)].Rarity == tier, "tier " .. tier .. " hero")
	end
	local top = MirrorBanner.RollTiers(1, function() return 0.9999999999 end)
	check(top[1] == 7, "a roll at the very top of [0,1) is Isabelle")
end)

test("a ten-pull of nine Isabelles ends on Caspian or better", function()
	local tiers = MirrorBanner.RollTiers(10, function() return 0.99 end)
	for pull = 1, 9 do check(tiers[pull] == 7, "pull " .. pull .. " is Isabelle") end
	check(tiers[10] >= 9, "the tenth is Caspian or better")
	local single = MirrorBanner.RollTiers(1, function() return 0.99 end)
	check(single[1] == 7, "single pulls have no floor")
end)

test("the Spark banks one pick every 80 pulls and repairs bad saves", function()
	local p = {}
	local spark = MirrorBanner.EnsureSpark(p)
	check(p.MirrorSpark == spark and spark.Pulls == 0 and spark.Selections == 0, "created")
	check(MirrorBanner.AddPulls(spark, 79) == 0 and spark.Pulls == 79, "79 pulls")
	check(MirrorBanner.AddPulls(spark, 10) == 1 and spark.Pulls == 9 and spark.Selections == 1, "the 80th pull banks a pick")
	check(MirrorBanner.AddPulls(spark, 160) == 2 and spark.Selections == 3, "picks stack")
	p.MirrorSpark = { Pulls = 0 / 0, Selections = -4 }
	local fixed = MirrorBanner.EnsureSpark(p)
	check(fixed.Pulls == 0 and fixed.Selections == 0, "NaN and negatives are repaired")
	check(MirrorBanner.IsSparkChoice("hero_rook") and not MirrorBanner.IsSparkChoice("hero_astrea") and not MirrorBanner.IsSparkChoice(7), "only the five")
end)

test("Robux packs pull on the mirror banner; restricted players get 150 Gems a pull", function()
	check(MirrorBanner.IsBanner("GILDED_MIRROR") and MirrorBanner.IsBanner("banner_gilded_mirror") and not MirrorBanner.IsBanner("A_STARS_ARRIVAL"), "banner ids")
	local one, ten = ShopConfig.ById("pack_mirror_1"), ShopConfig.ById("pack_mirror_10")
	check(one and one.RobuxPrice == 55 and one.Grant.Amount == 1 and one.Grant.Banner == "GILDED_MIRROR", "single pull offer")
	check(ten and ten.RobuxPrice == 499 and ten.Grant.Amount == 10 and ten.Grant.Banner == "GILDED_MIRROR", "ten-pull offer")
	local safe = ShopConfig.SafeGrant(ten.Grant, true)
	check(safe.Kind == "Gems" and safe.Amount == 1500, "restricted ten-pull becomes 1,500 Gems")
	check(ShopConfig.SafeGrant(ten.Grant, false).Kind == "Summons", "allowed players get the pulls")
end)

test("hero lists show the mirror share instead of a level", function()
	local p = profileWith({ hero("s", "hero_astrea", { Level = 7 }), hero("m", "hero_rook", { Stars = 2 }) })
	check(Stats.LevelText(p.Heroes.s) == "Lv.7", "normal heroes show their level")
	check(Stats.LevelText(p.Heroes.m) == "Mirror 152%", "mirror heroes show their share")
	check(Stats.MirrorDescription(p.Heroes.s) == nil, "no mirror line for normal heroes")
	check(Stats.MirrorDescription(p.Heroes.m) == "Copies 152% of your best hero's power", "before a source is known")
	Stats.RefreshMirrorSources(p)
	check(Stats.MirrorDescription(p.Heroes.m) == "Copies 152% of Astrea's power", "names the source")
end)

local Skills = require(nodes["ReplicatedStorage.Shared.Config.ArchetypeCombatSkills"])
local Effects = require(nodes["ServerScriptService.Combat.HeroSkillEffects"])

local function mob(id, x, hp)
	return { NetId = id, IsAlive = true, CurrentHP = hp or 1000, MaxHP = hp or 1000, Position = Vector3.new(x, 0, 0), DamageLedger = {} }
end
local function effectContext(mobs)
	return { Mobs = mobs, Now = 100, Same = function() return true end, IsCombatSafe = function() return false end,
		Broadcast = function() end, HandleMobDeath = function() end }
end
local function attacker(heroId, archetype, hp)
	return { Owner = { UserId = 1 }, Archetype = archetype, TemplateId = heroId, MaxHP = 1000, CurrentHP = hp or 1000, NetId = 1, Position = Vector3.new(0, 0, 0) }
end
local function resolve(heroId, archetype, tier, mobs, primary, a)
	local profile = Skills.GetSkillProfile(heroId, archetype)
	local def = if tier == "SKILL" then profile.Skill elseif tier == "SPECIAL" then profile.Special else profile.Basic
	return Effects.Resolve(effectContext(mobs) :: any, { Impact = { Atk = 100, DamageMult = def.DamageMultiplier, Ticks = 1, Origin = Vector3.new(0, 0, 0) },
		Attacker = a or attacker(heroId, archetype), Profile = profile, Tier = tier, Tick = 1, Primary = primary, Center = primary.Position })
end

test("Refraction splits to three other enemies within 14 studs; Ricochet to one", function()
	local target, near1, near2, near3, near4, far = mob(1, 5), mob(2, 8), mob(3, 9), mob(4, 10), mob(5, 11), mob(6, 40)
	resolve("hero_seraphine", "Scholar", "SPECIAL", { target, near1, near2, near3, near4, far }, target)
	local hit = 0
	for _, m in { near1, near2, near3, near4 } do if m.CurrentHP == 940 then hit += 1 end end
	check(hit == 3, "three shards at 0.60x ATK")
	check(far.CurrentHP == 1000 and target.CurrentHP == 1000, "the far enemy is untouched; the caller lands the prism")
	local t2, a, b = mob(1, 5), mob(2, 8), mob(3, 9)
	resolve("hero_isabelle", "Marksman", "SPECIAL", { t2, a, b }, t2)
	check((a.CurrentHP == 925) ~= (b.CurrentHP == 925), "one bounce at 0.75x ATK")
end)

test("Last Stand grows from 1.5x at full HP to 2.5x at 10% HP", function()
	local special = Skills.GetSkillProfile("hero_rook", "Berserker").Special
	close(Effects.LastStandBonus({ CurrentHP = 1000, MaxHP = 1000 }, special), 1, 1e-9, "full HP")
	close(Effects.LastStandBonus({ CurrentHP = 100, MaxHP = 1000 }, special), 2.5 / 1.5, 1e-9, "10% HP")
	close(Effects.LastStandBonus({ CurrentHP = 10, MaxHP = 1000 }, special), 2.5 / 1.5, 1e-9, "capped below 10%")
	close(Effects.LastStandBonus({ CurrentHP = 550, MaxHP = 1000 }, special), 1 + 0.5 * (2.5 / 1.5 - 1), 1e-9, "halfway")
	local target = mob(1, 4)
	local bonus = resolve("hero_rook", "Berserker", "SPECIAL", { target, mob(2, 6) }, target, attacker("hero_rook", "Berserker", 100))
	close(bonus, 2.5 / 1.5, 1e-9, "Resolve returns the bonus")
end)

test("Twin Reflection hits the toughest other enemy, or the lone target twice", function()
	local target, weak, tough, far = mob(1, 10, 1000), mob(2, 12, 500), mob(3, 14, 5000), mob(4, 60, 9999)
	resolve("hero_isabelle", "Marksman", "SKILL", { target, weak, tough, far }, target)
	check(tough.CurrentHP == 5000 - 250 and weak.CurrentHP == 500 and far.CurrentHP == 9999, "2.50x ATK to the toughest within 30 studs")
	check(target.CurrentHP == 1000, "no splash: the caller lands the first half")
	local alone = mob(1, 10)
	resolve("hero_isabelle", "Marksman", "SKILL", { alone }, alone)
	check(alone.CurrentHP == 750, "a lone target takes the second half too")
end)

test("Twin Reflection's second half lands on the target picked when the attack started", function()
	local profile = Skills.GetSkillProfile("hero_isabelle", "Marksman")
	local function twinHit(mobs, primary, picked, generation)
		return Effects.Resolve(effectContext(mobs) :: any, { Impact = { Atk = 100, DamageMult = profile.Skill.DamageMultiplier, Ticks = 1,
			Origin = Vector3.new(0, 0, 0), TwinTarget = picked, TwinGeneration = generation },
			Attacker = attacker("hero_isabelle", "Marksman"), Profile = profile, Tier = "SKILL", Tick = 1, Primary = primary, Center = primary.Position })
	end
	local target, a, b = mob(1, 10), mob(2, 12, 3000), mob(3, 14, 5000)
	a.EntityGeneration, b.EntityGeneration = 1, 1
	local picked = Effects.PickTwinTarget(effectContext({ target, a, b }) :: any, { Impact = {}, Primary = target } :: any, Vector3.new(0, 0, 0), 30)
	check(picked == b, "the pick is the toughest other enemy in range")
	b.CurrentHP = 2000 -- b took damage before the arrow landed; a is now tougher
	twinHit({ target, a, b }, target, b, 1)
	check(b.CurrentHP == 2000 - 250 and a.CurrentHP == 3000, "the half the client drew toward b still lands on b")
	local c, d = mob(1, 10), mob(2, 12, 3000)
	d.EntityGeneration = 2
	local gone = mob(3, 14, 5000)
	gone.EntityGeneration, gone.IsAlive = 1, false
	twinHit({ c, d, gone }, c, gone, 1)
	check(d.CurrentHP == 3000 - 250, "a dead pick falls back to the toughest living enemy")
end)

test("Looking-Glass Bulwark reflects for 6s; Gilded Frenzy speeds Rook up for 4s", function()
	local caspian = attacker("hero_caspian", "Vanguard")
	local target = mob(1, 5)
	resolve("hero_caspian", "Vanguard", "SKILL", { target }, target, caspian)
	check(caspian.ReflectPercent == 0.20 and caspian.ReflectExpires == 106, "reflection set")
	check(caspian.BarrierHP == 400 and target.TauntedByNetId == 1, "the Vanguard barrier and taunt still apply")
	local rook = attacker("hero_rook", "Berserker")
	local t2 = mob(1, 5)
	resolve("hero_rook", "Berserker", "SKILL", { t2, mob(2, 10) }, t2, rook)
	check(rook.AttackSpeedBonus == 0.25 and rook.AttackSpeedUntil == 104, "frenzy set")
end)

test("Gilded Frenzy: a slam over 18 studs, then four spins over 12, 2.6x in total, buff on the last spin", function()
	local profile = Skills.GetSkillProfile("hero_rook", "Berserker")
	local skill = profile.Skill :: any
	check(skill.Ticks == 5 and skill.Radius == 18 and skill.SpinRadius == 12 and skill.CastSeconds == 2.4, "kit shape")
	local total = 0
	for tick = 1, 5 do
		total += Effects.TickWeight(skill, tick, 5) / 5
	end
	close(total, 1, 1e-9, "the weights keep the 2.6x total")
	close(Effects.TickWeight(skill, 1, 5) / 5 * 2.6, 1.2, 1e-9, "the slam is 1.2x")
	close(Effects.TickWeight(skill, 3, 5) / 5 * 2.6, 0.35, 1e-9, "each spin is 0.35x")
	local rook = attacker("hero_rook", "Berserker")
	local function frenzyTick(mobs, primary, tick)
		return Effects.Resolve(effectContext(mobs) :: any, { Impact = { Atk = 100, DamageMult = skill.DamageMultiplier, Ticks = 5, Origin = Vector3.new(0, 0, 0) },
			Attacker = rook, Profile = profile, Tier = "SKILL", Tick = tick, Primary = primary, Center = primary.Position })
	end
	local target, mid, far = mob(1, 0), mob(2, 15), mob(3, 25)
	frenzyTick({ target, mid, far }, target, 1)
	check(mid.CurrentHP == 1000 - 60 and far.CurrentHP == 1000, "the slam hits others within 18 studs for half of 1.2x")
	frenzyTick({ target, mid, far }, target, 2)
	check(mid.CurrentHP == 940, "a spin does not reach 15 studs")
	check(rook.AttackSpeedBonus == nil, "no buff before the last spin")
	local near = mob(4, 8)
	frenzyTick({ target, near }, target, 5)
	check(near.CurrentHP == 1000 - math.round(17.5), "a spin hits others within 12 studs for half of 0.35x")
	check(rook.AttackSpeedBonus == 0.25 and rook.AttackSpeedUntil == 104, "the buff starts on the last spin")
end)

test("Saved Rourkes become Rook (hero_rourke -> hero_rook) on load", function()
	local Migrations = require(nodes["ServerScriptService.Core.ProfileMigrations"])
	local profile = { Heroes = { a = { TemplateId = "hero_rourke", DisplayName = "Rourke" }, b = { TemplateId = "hero_nyx" } } }
	Migrations.RenameTemplates(profile)
	check(profile.Heroes.a.TemplateId == "hero_rook" and profile.Heroes.b.TemplateId == "hero_nyx", "renamed, others untouched")
	Migrations.RenameTemplates(profile)
	check(profile.Heroes.a.TemplateId == "hero_rook", "idempotent")
	check(Catalog.Seeds.hero_rook ~= nil and Catalog.Seeds.hero_rourke == nil, "the catalog only knows the new id")
end)

test("Nyx's Gilded Edge passive is on her kit only", function()
	local passive = (Skills.GetSkillProfile("hero_nyx", "Striker") :: any).Passive
	check(passive and passive.Effect == "GILDED_EDGE" and passive.GaugeBonus == 0.15 and passive.Radius == 8, "Nyx's passive")
	check((Skills.GetSkillProfile("hero_edis", "Striker") :: any).Passive == nil, "other Strikers have none")
end)

print(string.format("mirror: %d passed, %d failed", passed, failed))
if failed > 0 then error(string.format("%d mirror tests failed", failed)) end
