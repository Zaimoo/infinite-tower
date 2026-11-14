--!strict
-- ReplicatedStorage/Shared/Util/AnvilBanner.luau
-- The Gilded Anvil's pull rules (docs/gilded-anvil-plan.md §2), kept pure so the server and specs
-- share them. Robux only: no Gem/Gold price, no God's Blessing luck, and no pity counter.
-- Instead:
--   * the Master picks a Focus archetype (40% Focus, 12% each of the other 5);
--   * every 10-pull includes at least one copy of the Focus weapon;
--   * every pull adds to the Spark; at 60 pulls the Master earns one free pick of any of the six.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArtifactCatalog = require(ReplicatedStorage.Shared.Config.ArtifactCatalog)

local AnvilBanner = {}

export type Spark = { Pulls: number, Selections: number, Focus: string }

AnvilBanner.Banner = ArtifactCatalog.AnvilBanner
AnvilBanner.POOL = ArtifactCatalog.AnvilOrder
AnvilBanner.FOCUS_CHANCE = ArtifactCatalog.AnvilBanner.FocusChance or 0.40
AnvilBanner.OFF_FOCUS_CHANCE = ArtifactCatalog.AnvilBanner.OffFocusChance or 0.12
AnvilBanner.GUARANTEE_AT = 10
AnvilBanner.SPARK_COST = ArtifactCatalog.AnvilBanner.SparkPulls or 60
AnvilBanner.DEFAULT_FOCUS = ArtifactCatalog.AnvilBanner.DefaultFocus or "SWORD_SHIELD"

function AnvilBanner.IsBanner(bannerId: any): boolean
	return bannerId == "GILDED_ANVIL" or bannerId == ArtifactCatalog.AnvilBanner.BannerId
end

function AnvilBanner.ResolveFocusType(choice: any): string?
	if type(choice) ~= "string" then
		return nil
	end
	if ArtifactCatalog.AnvilBanner.WeaponByType[choice] ~= nil then
		return choice
	end
	local seed = ArtifactCatalog.Seeds[choice]
	if seed and ArtifactCatalog.IsGildforged(seed) then
		return seed.Type
	end
	return nil
end

function AnvilBanner.ResolveWeaponId(choice: any): string?
	if type(choice) ~= "string" then
		return nil
	end
	local byType = ArtifactCatalog.AnvilBanner.WeaponByType[choice]
	if byType then
		return byType
	end
	if ArtifactCatalog.IsGildforged(choice) then
		return choice
	end
	return nil
end

function AnvilBanner.IsSparkChoice(choice: any): boolean
	return AnvilBanner.ResolveWeaponId(choice) ~= nil
end

-- The profile's AnvilSpark, created or repaired in place (lazy migration for older saves).
function AnvilBanner.EnsureSpark(profile: any): Spark
	local spark = profile.AnvilSpark
	if type(spark) ~= "table" then
		spark = { Pulls = 0, Selections = 0, Focus = AnvilBanner.DEFAULT_FOCUS }
		profile.AnvilSpark = spark
	end
	local function whole(v: any): number
		return if type(v) == "number" and v == v and v >= 0 and v < math.huge then math.floor(v) else 0
	end
	spark.Pulls = math.min(whole(spark.Pulls), AnvilBanner.SPARK_COST - 1)
	spark.Selections = whole(spark.Selections)
	spark.Focus = AnvilBanner.ResolveFocusType(spark.Focus) or AnvilBanner.DEFAULT_FOCUS
	return spark
end

function AnvilBanner.SetFocus(profile: any, choice: any): (boolean, string?)
	local resolved = AnvilBanner.ResolveFocusType(choice)
	if not resolved then
		return false, nil
	end
	local spark = AnvilBanner.EnsureSpark(profile)
	spark.Focus = resolved
	return true, resolved
end

-- Adds pulls to the Spark; every SPARK_COST pulls bank one free pick. Returns the picks earned.
function AnvilBanner.AddPulls(spark: Spark, count: number): number
	local n = if type(count) == "number" and count > 0 and count < math.huge then math.floor(count) else 0
	if n == 0 then
		return 0
	end
	local total = spark.Pulls + n
	local earned = total // AnvilBanner.SPARK_COST
	spark.Pulls = total % AnvilBanner.SPARK_COST
	spark.Selections += earned
	return earned
end

-- Spends one banked Spark pick and returns (ok, templateId).
function AnvilBanner.ClaimSpark(profile: any, choice: any): (boolean, string?)
	local weaponId = AnvilBanner.ResolveWeaponId(choice)
	if not weaponId then
		return false, nil
	end
	local spark = AnvilBanner.EnsureSpark(profile)
	if spark.Selections <= 0 then
		return false, nil
	end
	spark.Selections -= 1
	return true, weaponId
end

-- Rolls `count` Gildforged template IDs using `focus` (archetype or templateId). `rng` returns [0, 1).
function AnvilBanner.Roll(count: number, focus: any?, rng: (() -> number)?): { string }
	local safeCount = if type(count) == "number" and count > 0 and count < math.huge then math.floor(count) else 1
	local focusId = AnvilBanner.ResolveWeaponId(focus)
		or AnvilBanner.ResolveWeaponId(AnvilBanner.DEFAULT_FOCUS)
		:: string
	local offFocus: { string } = {}
	for _, id in AnvilBanner.POOL do
		if id ~= focusId then
			table.insert(offFocus, id)
		end
	end

	local draw = rng or math.random
	local results: { string } = {}
	local blockHasFocus = false

	for pull = 1, safeCount do
		if (pull - 1) % AnvilBanner.GUARANTEE_AT == 0 then
			blockHasFocus = false
		end

		local r = draw()
		if type(r) ~= "number" or r ~= r then
			r = 0.5
		end
		r = math.clamp(r, 0, 1 - 1e-12)

		local chosen: string
		if r < AnvilBanner.FOCUS_CHANCE then
			chosen = focusId
		else
			local idx = math.clamp(math.floor((r - AnvilBanner.FOCUS_CHANCE) / AnvilBanner.OFF_FOCUS_CHANCE) + 1, 1, #offFocus)
			chosen = offFocus[idx]
		end

		if chosen == focusId then
			blockHasFocus = true
		elseif pull % AnvilBanner.GUARANTEE_AT == 0 and not blockHasFocus then
			chosen = focusId
			blockHasFocus = true
		end

		table.insert(results, chosen)
	end

	return results
end

return table.freeze(AnvilBanner)
