--!strict
-- ReplicatedStorage/Shared/Util/MirrorBanner.luau
-- The Gilded Mirror's pull rules (docs/gilded-mirror-plan.md §1, §2.4), kept pure so the server and the
-- specs share them. Robux only: no Gem price, no God's Blessing luck and no pity counter. Instead:
--   * the 10th pull of a ten-pull is Caspian or better if the first nine weren't (TenPullMinTier);
--   * every pull adds to the Spark; at SparkPulls the Master earns one free pick of any of the five.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HeroCatalog = require(ReplicatedStorage.Shared.Config.HeroCatalog)
local SummonLuck = require(ReplicatedStorage.Shared.Util.SummonLuck)

local MirrorBanner = {}

export type Spark = { Pulls: number, Selections: number }

MirrorBanner.Banner = HeroCatalog.MirrorBanner
MirrorBanner.LowestTier = 7 -- Isabelle, Mythical

function MirrorBanner.IsBanner(bannerId: any): boolean
	return bannerId == "GILDED_MIRROR" or bannerId == HeroCatalog.MirrorBanner.BannerId
end

-- The profile's Spark, created or repaired in place (lazy migration for older saves).
function MirrorBanner.EnsureSpark(profile: any): Spark
	local spark = profile.MirrorSpark
	if type(spark) ~= "table" then
		spark = { Pulls = 0, Selections = 0 }
		profile.MirrorSpark = spark
	end
	local function whole(v: any): number
		return if type(v) == "number" and v == v and v >= 0 and v < math.huge then math.floor(v) else 0
	end
	spark.Pulls = math.min(whole(spark.Pulls), HeroCatalog.MirrorBanner.SparkPulls - 1)
	spark.Selections = whole(spark.Selections)
	return spark
end

-- Adds pulls to the Spark; every SparkPulls pulls bank one free pick. Returns the picks earned.
function MirrorBanner.AddPulls(spark: Spark, count: number): number
	local total = spark.Pulls + count
	local earned = total // HeroCatalog.MirrorBanner.SparkPulls
	spark.Pulls = total % HeroCatalog.MirrorBanner.SparkPulls
	spark.Selections += earned
	return earned
end

-- Rolls `count` tiers. `rng` returns a number in [0, 1).
function MirrorBanner.RollTiers(count: number, rng: () -> number): { number }
	local banner = HeroCatalog.MirrorBanner
	local rates = banner.Rates :: { number }
	local tiers, best = {}, 0
	for pull = 1, count do
		local floor = if count == 10 and pull == count and best < banner.TenPullMinTier then banner.TenPullMinTier else nil
		local tier = if floor then SummonLuck.RollAtLeast(rates, floor, rng()) else SummonLuck.Roll(rates, rng())
		-- Tiers 1-6 are 0%; Roll only lands there on float rounding at r ~ 1, so that is the lowest hero.
		tier = math.max(tier, MirrorBanner.LowestTier)
		best = math.max(best, tier)
		table.insert(tiers, tier)
	end
	return tiers
end

function MirrorBanner.HeroForTier(tier: number): string
	return HeroCatalog.MirrorBanner.HeroesByStar[tier] or HeroCatalog.MirrorBanner.HeroesByStar[7]
end

-- Whether `heroId` is one of the five heroes a Spark may pick.
function MirrorBanner.IsSparkChoice(heroId: any): boolean
	if type(heroId) ~= "string" then return false end
	for _, id in HeroCatalog.MirrorBanner.HeroesByStar do
		if id == heroId then return true end
	end
	return false
end

return table.freeze(MirrorBanner)
