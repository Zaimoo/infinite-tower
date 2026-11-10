--!strict
-- tests/hero-banner-odds.spec.luau
-- HeroBannerOdds: the per-hero odds shown in the summon screen's "View Heroes & Odds" window.

local HeroCatalog = require(nodes["ReplicatedStorage.Shared.Config.HeroCatalog"])
local HeroBannerOdds = require(nodes["ReplicatedStorage.Shared.Util.HeroBannerOdds"])

local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end

local BANNERS = { HeroCatalog.PermanentBanner, HeroCatalog.LimitedBanner }

test("hero chances sum to 1 on both banners, with and without luck", function()
	for _, banner in BANNERS do
		for _, luck in { 0, 0.25, 0.5 } do
			local total = 0
			for _, t in HeroBannerOdds.Tiers(banner, luck) do
				local tierSum = 0
				for _, h in t.Heroes do tierSum += h.Chance end
				assert(math.abs(tierSum - t.Rate) < 1e-12, banner.Title .. " tier " .. t.Tier .. " heroes add up to the tier rate")
				total += tierSum
			end
			assert(math.abs(total - 1) < 1e-9, string.format("%s sums to 1 at luck %.2f (got %.6f)", banner.Title, luck, total))
		end
	end
end)

test("tiers are listed rarest first and match the banner rates", function()
	for _, banner in BANNERS do
		local tiers = HeroBannerOdds.Tiers(banner)
		assert(#tiers == banner.MaxStar, "one entry per tier")
		for i, t in tiers do
			assert(t.Tier == banner.MaxStar - i + 1, "rarest first")
			assert(math.abs(t.Rate - banner.Rates[t.Tier]) < 1e-12, "no luck keeps the base rate")
		end
	end
end)

test("pool tiers split their rate evenly", function()
	local exalted = HeroBannerOdds.Tiers(HeroCatalog.PermanentBanner)[HeroCatalog.PermanentBanner.MaxStar - 5 + 1]
	assert(exalted.Tier == 5 and #exalted.Heroes == 2, "Call of the Rift Exalted holds Ignis and Diran")
	assert(exalted.Heroes[1].Chance == exalted.Heroes[2].Chance, "even split")
	local ids = HeroBannerOdds.Heroes(HeroCatalog.LimitedBanner)
	assert(table.find(ids, "hero_valeria") and table.find(ids, "hero_archon"), "Valeria and Archon both listed")
	assert(table.find(HeroBannerOdds.Heroes(HeroCatalog.PermanentBanner), "hero_shurn"), "Shurn listed")
end)

test("every listed hero has a seed and appears once", function()
	for _, banner in BANNERS do
		local seen = {}
		for _, id in HeroBannerOdds.Heroes(banner) do
			assert(HeroCatalog.Seeds[id], "seed for " .. id)
			assert(not seen[id], id .. " listed once")
			seen[id] = true
		end
		assert(seen[banner.FeaturedHeroId or banner.HeroesByStar[banner.MaxStar]], "featured hero listed")
	end
end)

-- The Hero Index lists exactly HeroBannerOdds.Heroes(banner), so a seed missing from every banner
-- never shows in the Index (or on the summon screen).
test("every hero seed can be pulled from a banner at its own rarity", function()
	local found = {}
	for _, banner in BANNERS do
		for _, t in HeroBannerOdds.Tiers(banner) do
			for _, h in t.Heroes do
				found[h.HeroId] = found[h.HeroId] or {}
				table.insert(found[h.HeroId], t.Tier)
			end
		end
	end
	for id, seed in HeroCatalog.Seeds do
		assert(found[id], id .. " is on a hero banner (Hero Index and summon screen)")
		assert(table.find(found[id], seed.Rarity), string.format("%s is pulled at its own rarity %d", id, seed.Rarity))
	end
end)

print(string.format("hero-banner-odds: %d passed", passed))
