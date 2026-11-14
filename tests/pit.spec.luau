-- Regression tests execute real Pit modules through roblox-module-shim.luau.
local Config = require(nodes["ReplicatedStorage.Shared.Config.PitBalanceConfig"])
local Catalog = require(nodes["ReplicatedStorage.Shared.Config.HeroCatalog"])
local Stats = require(nodes["ReplicatedStorage.Shared.Util.StatFormulas"])
local Balance = require(nodes["ReplicatedStorage.Shared.Config.StatBalance"])
local Math = require(nodes["ReplicatedStorage.Shared.Util.PitMath"])
local PitService = require(nodes["ServerScriptService.Core.PitService"])

local passed, failed = 0, 0
local function check(condition, message)
	assert(condition, message or "Expected condition to be true")
end
local function equal(actual, expected, message)
	assert(actual == expected, (message or "Value differs") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function close(actual, expected, tolerance)
	check(math.abs(actual - expected) <= (tolerance or 0.00001), "Expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function deepEqual(a, b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	for key, value in pairs(a) do if not deepEqual(value, b[key]) then return false end end
	for key in pairs(b) do if a[key] == nil then return false end end
	return true
end
local function test(name, callback)
	local ok, result = pcall(callback)
	if ok then passed += 1; print("PASS " .. name)
	else failed += 1; print("FAIL " .. name .. "\n" .. tostring(result)) end
end
local function hero(id, seedId, fields)
	local seed = Catalog.Seeds[seedId or "hero_han"]
	local value = {
		UUID = id, TemplateId = seed.HeroId, DisplayName = seed.DisplayName, Archetype = seed.Archetype,
		Stars = seed.BaseStar, Level = 1, XP = 0, OverflowXP = 0, QualityScalar = 1,
		BaseHP = seed.NativeHP, BaseATK = seed.NativeATK, BaseLabor = seed.NativeLabor,
		AttackInterval = seed.AttackInterval, AttackRange = seed.AttackRange,
		CurrentStamina = 100, MaxStamina = 100,
		ComaUntilTimestamp = 0, IsHardAuditComa = false, Assignment = "BENCHED",
		Locked = false, Favorite = false,
	}
	-- The default test hero is a Han summoned while he was the Common starter: owned heroes keep
	-- their saved rarity, so he still counts as Common now that the template is Mythical.
	if seed.HeroId == "hero_han" then
		value.Rarity = 1
		value.BaseHP, value.BaseATK, value.BaseLabor = seed.BaseHP_1Star, seed.BaseATK_1Star, seed.BaseLabor_1Star
	end
	for key, valueOverride in pairs(fields or {}) do value[key] = valueOverride end
	return value
end

test("Existing level curve and all five caps remain intact", function()
	equal(Stats.GetXPRequiredForNextLevel(1), 50)
	equal(Stats.GetXPRequiredForNextLevel(2), 137)
	equal(Stats.GetXPRequiredForNextLevel(9), 1210)
	for stars = 1, 7 do equal(Stats.GetMaxLevel(stars), 10) end
	equal(Stats.GetXPRequiredForNextLevel(1, 2), 1618)
	equal(Stats.GetEffectiveLevel(3, 5), 25)
end)

test("Fresh donor value, affinity, research and efficiency have exact results", function()
	local recipient = hero("r")
	local donor = hero("d", "hero_jenna")
	local result = Math.GetSynthesisXP(donor, recipient, {})
	equal(result.Base, 125); equal(result.Efficiency, 1); equal(result.Final, 125)
	equal(Math.GetSynthesisXP(hero("a"), recipient, {}).Final, 131)
	equal(Math.GetSynthesisXP(donor, recipient, { EssenceAttunement = true }).Final, 138)
	recipient.Stars, recipient.Level = 3, 10
	local diminished = Math.GetSynthesisXP(donor, recipient, {})
	equal(diminished.Efficiency, 0.55); equal(diminished.Final, 69)
end)

test("Invested donors improve value at every rarity", function()
	for stars = 1, 5 do
		local recipient = hero("r", "hero_han", { Stars = stars, Level = 10 })
		local fresh = hero("a", "hero_jenna", { Stars = stars })
		local invested = hero("b", "hero_jenna", { Stars = stars, Level = 10 })
		check(Math.GetSynthesisXP(invested, recipient, {}).Final > Math.GetSynthesisXP(fresh, recipient, {}).Final)
	end
end)

test("Full balance sweep keeps donor XP monotonic and efficiency between 55 and 100 percent", function()
	for stars = 1, 5 do
		for recipientLevel = 1, 50 do
			for _, affinity in ipairs({ false, true }) do
				for _, researched in ipairs({ false, true }) do
					local previous = -1
					for donorLevel = 1, 10 do
						local donor = hero("d", affinity and "hero_han" or "hero_jenna", { Stars = stars, Level = donorLevel })
						local recipient = hero("r", "hero_han", { Stars = math.ceil(recipientLevel / 10), Level = recipientLevel - (math.ceil(recipientLevel / 10) - 1) * 10 })
						local result = Math.GetSynthesisXP(donor, recipient, { EssenceAttunement = researched })
						check(result.Efficiency >= 0.55 and result.Efficiency <= 1)
						check(result.Final >= 0 and result.Final >= previous, "Investing levels reduced donor value")
						local donorEffective = (stars - 1) * 10 + donorLevel
						local base = 100 * 3 ^ (stars - 1) + 25 * donorEffective
						-- Evaluate rational config constants without intermediate
						-- floating-point .5 boundary drift in the expected result.
						local efficiencyUnits = math.max(22, 40 - math.max(0, recipientLevel - donorEffective - 5))
						local bonusPercent = 100 + (researched and 10 or 0) + (affinity and 5 or 0)
						local expected = math.floor(base * efficiencyUnits * bonusPercent / 4000 + 0.5)
						equal(result.Final, expected, string.format("Rounding stars=%d donor=%d recipient=%d affinity=%s research=%s", stars, donorLevel, recipientLevel, tostring(affinity), tostring(researched)))
						previous = result.Final
					end
				end
			end
		end
	end
end)

test("Every native seed uses canonical compounded growth without retired effects", function()
	for seedId, seed in pairs(Catalog.Seeds) do
		if seed.Mirror then continue end -- mirror heroes copy another hero (mirror.spec.luau)
		equal(seed.BaseStar, 1, seedId .. " is summoned at 1 star")
		-- Rarity folds in the old summon-star bonus: 100% for Common-Rare, 50% from Superior up.
		local comp = seed.Rarity <= 3 and 1 or 0.5
		local rarityCombat = comp * (3 * 1.35)^(seed.Rarity-1)
		local rarityLabor = comp * (1.35 * 1.12)^(seed.Rarity-1)
		for _, stars in ipairs({ 1, 4, 7 }) do
			for level = 1, 10, 3 do
				for _, quality in ipairs({ 0.9, 1, 1.15 }) do
					local original = hero("native", seedId, { Stars = stars, Level = level, QualityScalar = quality, Rarity = seed.Rarity })
					local atk, hp, dps = Stats.GetEffectiveCombatStats(original, false, false)
					local expectedATK = math.round(seed.BaseATK_1Star * quality * rarityCombat * 1.5^(stars-1) * 1.08^((stars-1)*10+level-1))
					local expectedHP = math.round(seed.BaseHP_1Star * quality * rarityCombat * 1.5^(stars-1) * 1.08^((stars-1)*10+level-1))
					local expectedDPS = math.round((expectedATK / (math.ceil(seed.AttackInterval/Balance.TickSeconds-1e-10)*Balance.TickSeconds)) * 10) / 10
					equal(atk, expectedATK); equal(hp, expectedHP); equal(dps, expectedDPS)
					for _, facility in ipairs({ "BENCHED", "FACILITY_CONDUIT", "FACILITY_INFIRMARY", "FACILITY_LAB" }) do
						local synergy = (seed.PreferredFacility == "ALL" or seed.PreferredFacility == facility) and 0.25 or 0
						local expectedLabor = math.round(seed.BaseLabor_1Star * rarityLabor * 1.35^(stars-1) * quality * (1 + 0.05 * ((stars-1)*10 + level - 1)) * (1 + synergy) * 100) / 100
						equal(Stats.GetEffectiveLabor(original, facility), expectedLabor)
					end
				end
			end
		end
	end
end)

test("A 1-star pull keeps its old summoned power: 100% to Rare, 50% from Superior", function()
	for seedId, seed in pairs(Catalog.Seeds) do
		if seed.Mirror then continue end -- mirror heroes copy another hero (mirror.spec.luau)
		local now = Stats.GetHeroPower(hero("p", seedId, { Stars = 1, Rarity = seed.Rarity }))
		-- Old rule: summoned at star = tier, 3x per star, 1.35x per tier.
		local g = 3^(seed.Rarity-1) * 1.35^(seed.Rarity-1)
		local tick = math.ceil(seed.AttackInterval/Balance.TickSeconds-1e-10)*Balance.TickSeconds
		local old = 10 * math.round(seed.BaseATK_1Star * g) / tick + math.round(seed.BaseHP_1Star * g)
		local want = seed.Rarity <= 3 and 1 or 0.5
		check(math.abs(now / old - want) < 0.002, string.format("%s ratio %.4f", seedId, now / old))
	end
end)

test("A rare donor is worth its old summon star in The Pit", function()
	local astrea = hero("d", "hero_astrea", { Stars = 1 })
	equal(Math.EffectiveStars(astrea), 7)
	equal(Math.EffectiveStars(hero("h", "hero_han", { Stars = 3 })), 3)
end)
test("One and multiple donors apply the existing level curve", function()
	local original = hero("r")
	local after = Math.AdvanceXP(original, 125)
	equal(after.Level, 2); equal(after.XP, 75)
	local batch = Math.AdvanceXP(original, 250)
	equal(batch.Level, 3); equal(batch.XP, 63)
	equal(original.Level, 1); equal(original.XP, 0)
	local atk, hp, dps = Stats.GetEffectiveCombatStats(after, false, false)
	equal(atk, 43); equal(hp, 324); equal(dps, 47.8) -- 43 / 0.9s (a 0.85s attack rounds up to the 10 Hz tick)
	equal(Stats.GetEffectiveLabor(after), 14.7)
end)

test("Cap overflow is stored exactly and excess is reported", function()
	local recipient = hero("r", "hero_han", { Level = 9, XP = 1190 })
	local after, overflow = Math.AdvanceXP(recipient, 125)
	equal(after.Level, 10); equal(after.XP, 0); equal(after.OverflowXP, 105)
	equal(overflow.Rejected, 0); equal(overflow.Capacity, 3454) -- 2★ Lv 1 and Lv 2 (effective 11, 12)
	local bounded, excess = Math.AdvanceXP(hero("r", "hero_han", { Level = 10 }), 4000)
	equal(bounded.OverflowXP, 3454); equal(excess.Rejected, 546)
end)

test("Five stars never exceed level 50 or create a future-tier reserve", function()
	local result, overflow = Math.AdvanceXP(hero("r", "hero_han", { Stars = 7, Level = 10 }), 10000)
	equal(result.Level, 10); equal(result.XP, 0); equal(result.OverflowXP, 0); equal(overflow.Rejected, 10000)
end)

test("Promotion applies one multiplier and releases reserve through real levels", function()
	local before = hero("r", "hero_han", { Level = 10, OverflowXP = 3454 })
	local after = Math.Promote(before)
	equal(after.Stars, 2); equal(after.BaseATK, 60); equal(after.BaseHP, 450); equal(after.BaseLabor, 18.9)
	equal(after.Level, 3); equal(after.XP, 0) -- reset to Lv 1, reserve buys Lv 2 and 3; equal(after.OverflowXP, 0)
	equal(before.Stars, 1); equal(before.BaseATK, 40)
	local atk, hp = Stats.GetEffectiveCombatStats(after, false, false)
	equal(atk, math.round(60 * 1.08^12)); equal(hp, math.round(450 * 1.08^12))
	local repeatATK, repeatHP = Stats.GetEffectiveCombatStats(after, false, false)
	equal(repeatATK, atk); equal(repeatHP, hp); equal(after.BaseATK, 60)
	close(Stats.GetEffectiveLabor(after, "FACILITY_CONDUIT"), 30.24, 0.00001)
end)

-- Service tests follow below; all tests share the same assertions and real modules.
local function profile()
	return {
		SchemaVersion = 1, PlotIndex = 1,
		Currencies = { Gold = 1000000, Gems = 10000, ResearchPoints = 1000 },
		Heroes = { r = hero("r"), d = hero("d", "hero_jenna"), e = hero("e", "hero_jenna") },
		DeployedSquadOrder = {},
		Facilities = {
			ManaConduit = { Level = 1, AssignedHeroUUIDs = {}, UncollectedOutput = 0 },
			Infirmary = { Level = 1, AssignedHeroUUIDs = {}, UncollectedOutput = 0 },
			DimensionalLab = { Level = 5, AssignedHeroUUIDs = {}, UncollectedOutput = 0 },
		},
		UnlockedResearch = {},
		PitMaterials = { PromotionStone = 100 },
		Social = {},
	}
end

local function context()
	local c = { now = 100, nextToken = 0, syncs = 0, player = "master-one", other = "master-two" }
	c.profile, c.otherProfile = profile(), profile()
	c.profiles = { [c.player] = c.profile, [c.other] = c.otherProfile }
	for _, value in pairs(c.profiles) do PitService.EnsureDefaults(value) end
	c.service = PitService.new({
		GetProfile = function(player) return c.profiles[player] end,
		GenerateToken = function() c.nextToken += 1; return "opaque-test-token-" .. c.nextToken end,
		Clock = function() return c.now end,
		SyncProfile = function(player) c.syncs += 1; if c.onSync then c.onSync(player) end end,
	})
	function c:request(command, payload, player)
		self.now += 0.25
		return self.service:Request(player or self.player, command, payload)
	end
	function c:preview(request, player)
		local result = self:request("PREVIEW", request, player)
		check(result.Success, result.Message)
		return result.Preview
	end
	function c:commit(preview, extra, player)
		local payload = { Token = preview.Token, ConfirmRare = true }
		for key, value in pairs(extra or {}) do payload[key] = value end
		return self:request("COMMIT", payload, player)
	end
	return c
end

local function synthesis(donors)
	return { Action = "SYNTHESIS", Recipient = "r", Donors = donors or { "d" } }
end

local function rejectedWithoutMutation(c, command, payload)
	-- Newly inserted legacy fixtures may need schema defaults. Migration is
	-- deliberately allowed before measuring the irreversible operation's effects.
	PitService.EnsureDefaults(c.profile)
	local before = Math.Copy(c.profile)
	local response = c:request(command, payload)
	check(response.Success == false or (response.Preview and response.Preview.CanCommit == false), "Expected rejected operation")
	check(deepEqual(c.profile, before), "Rejected operation mutated the profile")
	return response
end

test("Schema migration preserves existing heroes, assignments, levels and inventory", function()
	local p = profile()
	p.PitMaterials = nil; p.Heroes.r.Level = 8; p.Heroes.r.Assignment = "FACILITY_LAB"
	p.Heroes.r.Locked = nil; p.Heroes.r.Favorite = nil; p.Heroes.r.OverflowXP = nil
	p.Facilities.DimensionalLab.AssignedHeroUUIDs = { "r" }
	p.UnlockedResearch.SquadSlot4 = true
	PitService.EnsureDefaults(p)
	equal(p.SchemaVersion, 2); equal(p.Heroes.r.Level, 8); equal(p.Heroes.r.XP, 0)
	equal(p.Heroes.r.Assignment, "FACILITY_LAB"); equal(p.Facilities.DimensionalLab.AssignedHeroUUIDs[1], "r")
	equal(p.Currencies.Gems, 10000); equal(p.UnlockedResearch.SquadSlot4, true)
	equal(p.Heroes.r.Locked, false); equal(p.Heroes.r.Favorite, false); equal(p.Heroes.r.OverflowXP, 0)
	equal(p.PitMaterials.SoulEssence, nil); equal(p.PitMaterials.PromotionStone, 0); equal(p.PitMaterials.ImprintCatalyst, nil)
	local stable = Math.Copy(p); PitService.EnsureDefaults(p); check(deepEqual(stable, p), "Migration must be idempotent")
end)

test("State snapshots do not expose mutable references", function()
	local c = context()
	local result = c:request("STATE")
	check(result.Success); equal(result.State.SessionOnly, true)
	result.State.Heroes.r.Level = 50; result.State.Materials.PromotionStone = 10000000
	equal(c.profile.Heroes.r.Level, 1); equal(c.profile.PitMaterials.PromotionStone, 100)
end)

test("Recipient status ignores donor protections and level cap", function()
	local c = context()
	local h = c.profile.Heroes.r
	h.Locked = true
	h.Favorite = true
	h.Assignment = "SQUAD_SLOT_1"
	h.Level = Stats.GetMaxLevel(h.Stars)
	local state = c:request("STATE").State
	check(state.Heroes.r.RecipientStatus.Eligible)
	check(not state.Heroes.r.PitStatus.EligibleDonor)
	local previewResult = c:request("PREVIEW", synthesis())
	check(not previewResult.Success or not previewResult.Preview.CanCommit)
end)

test("Recipient status exposes coma and profile reservations", function()
	local c = context()
	c.profile.ReservedHeroUUIDs = { r = true }
	local state = c:request("STATE").State
	check(not state.Heroes.r.RecipientStatus.Eligible)
	check(not c:preview(synthesis()).CanCommit)
	c.profile.ReservedHeroUUIDs = {}
	c.profile.Heroes.r.IsHardAuditComa = true
	state = c:request("STATE").State
	check(not state.Heroes.r.RecipientStatus.Eligible)
	check(not c:preview(synthesis()).CanCommit)
end)

test("Preview does not spend resources and committed single donor matches exact preview", function()
	local c = context()
	local before = Math.Copy(c.profile)
	local preview = c:preview(synthesis())
	check(preview.CanCommit); check(preview.Token); check(deepEqual(before, c.profile))
	equal(preview.XP.Final, 125); equal(preview.After.Level, 2); equal(preview.After.XP, 75)
	local result = c:commit(preview)
	check(result.Success, result.Message); equal(c.profile.Heroes.d, nil); check(c.profile.Heroes.e)
	check(deepEqual(Math.Snapshot(c.profile.Heroes.r), preview.After))
	equal(c.profile.Heroes.r.SynthesisHistory.DonorsConsumed, 1); equal(c.profile.Heroes.r.SynthesisHistory.XPGained, 125)
	equal(preview.Costs.Gold, 125); equal(c.profile.Currencies.Gold, before.Currencies.Gold - 125); equal(c.syncs, 1)
end)

test("Synthesis costs Gold for the EXP applied and is refused without enough Gold", function()
	equal(Math.GetSynthesisGoldCost(0), 0); equal(Math.GetSynthesisGoldCost(10), 50); equal(Math.GetSynthesisGoldCost(125), 125)
	local c = context(); c.profile.Currencies.Gold = 124
	local preview = c:preview(synthesis())
	check(not preview.CanCommit); equal(preview.Costs.Gold, 125)
	rejectedWithoutMutation(c, "PREVIEW", synthesis())
end)

test("Batch synthesis is deterministic and independent of donor order", function()
	local c = context()
	local preview = c:preview(synthesis({ "d", "e" }))
	local reverse = c:preview(synthesis({ "e", "d" }))
	equal(preview.XP.Final, 250); equal(reverse.XP.Final, 250)
	check(deepEqual(preview.After, reverse.After)); check(c:commit(reverse).Success)
	equal(c.profile.Heroes.r.Level, 3); equal(c.profile.Heroes.r.XP, 63)
	equal(c.profile.Heroes.d, nil); equal(c.profile.Heroes.e, nil)
end)

test("Donor limit and exact identities are enforced", function()
	local c = context()
	c.profile.Heroes.r = hero("r", "hero_han", { Stars = 5, Level = 1 })
	local ids = {}
	for i = 1, Config.MaxDonors + 1 do local id = "batch" .. i; c.profile.Heroes[id] = hero(id, "hero_jenna"); table.insert(ids, id) end
	rejectedWithoutMutation(c, "PREVIEW", synthesis(ids))
	table.remove(ids); local p = c:preview(synthesis(ids)); check(p.CanCommit); equal(#p.Donors, Config.MaxDonors)
	check(c:commit(p).Success); check(c.profile.Heroes["batch" .. (Config.MaxDonors + 1)])
	for _, id in ipairs(ids) do equal(c.profile.Heroes[id], nil) end
end)

test("Duplicate hero names remain separate UUID instances", function()
	local c = context()
	c.profile.Heroes.d = hero("d"); c.profile.Heroes.e = hero("e")
	equal(c.profile.Heroes.d.DisplayName, c.profile.Heroes.e.DisplayName)
	local preview = c:preview(synthesis({ "d" }))
	check(c:commit(preview).Success); equal(c.profile.Heroes.d, nil); check(c.profile.Heroes.e); check(c.profile.Heroes.r)
end)

test("Self-donors, duplicate UUIDs, missing heroes and foreign UUIDs reject atomically", function()
	for _, ids in ipairs({ { "r" }, { "d", "d" }, { "missing" }, { "foreign-only" } }) do
		local c = context(); c.otherProfile.Heroes["foreign-only"] = hero("foreign-only")
		rejectedWithoutMutation(c, "PREVIEW", synthesis(ids))
	end
end)

test("Every donor protection blocks synthesis", function()
	local protections = {
		{ Locked = true }, { Favorite = true }, { Favorited = true },
		{ Assignment = "SQUAD_SLOT_1" }, { Assignment = "FACILITY_CONDUIT" },
		{ ComaUntilTimestamp = os.time() + 1000 }, { IsHardAuditComa = true },
		{ ReservedBy = "ritual" }, { Reserved = true }, { OperationReserved = true },
		{ ReservedOperationId = "operation" }, { InCombat = true }, { IsInCombat = true },
		{ ActiveCombat = true }, { Unique = true }, { IsUnique = true }, { Protected = true },
		{ Stars = 8 }, { TemplateId = "unknown-unique" },
	}
	for _, fields in ipairs(protections) do
		local c = context()
		for key, value in pairs(fields) do c.profile.Heroes.d[key] = value end
		rejectedWithoutMutation(c, "PREVIEW", synthesis())
	end
end)

test("Redundant squad, facility and reservation indexes protect apparently benched donors", function()
	for _, index in ipairs({ "squad", "facility", "reservation" }) do
		local c = context()
		if index == "squad" then c.profile.DeployedSquadOrder = { "d" }
		elseif index == "facility" then c.profile.Facilities.ManaConduit.AssignedHeroUUIDs = { "d" }
		else c.profile.ReservedHeroUUIDs = { d = true } end
		rejectedWithoutMutation(c, "PREVIEW", synthesis())
	end
end)

test("Malformed and oversized client request shapes cannot mutate profiles", function()
	local bad = {
		false, 7, "SYNTHESIS", {}, { Action = 3 }, { Action = "FAKE" },
		{ Action = "SYNTHESIS", Recipient = {} }, { Action = "SYNTHESIS", Recipient = 3 },
		{ Action = "SYNTHESIS", Recipient = string.rep("x", 81) },
		{ Action = "SYNTHESIS", Recipient = "r", Donors = "d" },
		{ Action = "SYNTHESIS", Recipient = "r", Donors = { [2] = "d" } },
		{ Action = "SYNTHESIS", Recipient = "r", Donors = { [-1] = "d" } },
		{ Action = "SYNTHESIS", Recipient = "r", Donors = { donor = "d" } },
		{ Action = "SYNTHESIS", Recipient = "r", Donors = { [math.huge] = "d" } },
		{ Action = "SYNTHESIS", Recipient = "r", Donors = { "d", extra = "e" } },
		{ Action = "SYNTHESIS", Recipient = "r", Donors = { 0 / 0 } },
		{ Action = "SYNTHESIS", Recipient = "r", Donors = { math.huge } },
		{ Action = "SYNTHESIS", Recipient = "r", Donors = { string.rep("x", 81) } },
		{ Action = "IMPRINT", Recipient = "r", Donors = { "d" }, Imprint = "melee_memory" }, -- imprints were removed
		{ Action = "CONVERSION", Donors = { "d" } }, -- Soul Essence was removed
		{ Action = "CRAFT", Recipe = "PromotionStone" },
	}
	for _, payload in ipairs(bad) do rejectedWithoutMutation(context(), "PREVIEW", payload) end
	rejectedWithoutMutation(context(), "PREVIEW", nil)
	local acceptsNaNKey = pcall(function() return { [0 / 0] = "d" } end)
	equal(acceptsNaNKey, false) -- Luau rejects NaN keys before any request exists.
end)

test("Client EXP, cost, outcome and star fields never become authoritative", function()
	local c = context()
	local request = synthesis(); request.XP = 1e15; request.Gold = -999; request.FinalStars = 5; request.Success = true
	local preview = c:preview(request)
	equal(preview.XP.Final, 125)
	request.Donors[1] = "e"
	check(c:commit(preview, { XP = 1e15, Recipient = "e", FinalStars = 5 }).Success)
	equal(c.profile.Heroes.r.Stars, 1); equal(c.profile.Heroes.r.Level, 2)
	equal(c.profile.Heroes.d, nil); check(c.profile.Heroes.e)
end)

test("Stale economy, roster, assignment, research and material changes reject without partial consumption", function()
	local mutations = {
		function(p) p.Heroes.d.Level = 2 end,
		function(p) p.Heroes.d = nil end,
		function(p) p.Heroes.d.Locked = true end,
		function(p) p.Facilities.ManaConduit.AssignedHeroUUIDs = { "d" } end,
		function(p) p.DeployedSquadOrder = { "d" } end,
		function(p) p.UnlockedResearch.EssenceAttunement = true end,
		function(p) p.ReservedHeroUUIDs = { d = true } end,
	}
	for _, mutate in ipairs(mutations) do
		local c = context(); local preview = c:preview(synthesis()); mutate(c.profile)
		rejectedWithoutMutation(c, "COMMIT", { Token = preview.Token, ConfirmRare = true })
	end
end)

test("Income and combat EXP that leave the confirmed result unchanged preserve a valid preview", function()
	-- Regression: Guard Post Gold ticking in between preview and confirm used to void every synthesis.
	local c = context(); local p = c:preview(synthesis())
	c.profile.Currencies.Gold += 25; c.profile.Currencies.Gems += 1; c.profile.Heroes.r.CurrentHP = 12
	check(c:commit(p).Success); equal(c.profile.Heroes.d, nil)
end)

test("A commit whose result changed is flagged stale so the client can re-preview", function()
	local c = context(); local p = c:preview(synthesis()); c.profile.Heroes.d.Level = 2
	local response = rejectedWithoutMutation(c, "COMMIT", { Token = p.Token })
	equal(response.Stale, true)
end)

test("Armed donors are consumed and their weapon returns to the backpack", function()
	local c = context()
	c.profile.Artifacts = { art_test = { UUID = "art_test", DisplayName = "Test Blade", EquippedHeroUUID = "d" } }
	c.profile.Heroes.d.EquippedArtifactUUID = "art_test"
	local p = c:preview(synthesis())
	equal(#p.Unequips, 1); equal(p.Unequips[1].Artifact, "Test Blade")
	check(#p.Warnings >= 1, "the unequip is announced before confirming")
	check(c:commit(p).Success)
	equal(c.profile.Heroes.d, nil); equal(c.profile.Artifacts.art_test.EquippedHeroUUID, nil)
end)

test("Ordinary stamina regeneration preserves a valid preview", function()
	local c = context(); c.profile.Heroes.r.CurrentStamina = 80
	local p = c:preview(synthesis()); c.profile.Heroes.r.CurrentStamina = 82
	check(c:commit(p).Success)
end)

test("Tokens are expiring, single-use and isolated to their player", function()
	local c = context(); local p = c:preview(synthesis())
	local foreign = c:request("COMMIT", { Token = p.Token }, c.other)
	equal(foreign.Success, false); check(c.profile.Heroes.d)
	check(c:commit(p).Success)
	rejectedWithoutMutation(c, "COMMIT", { Token = p.Token })
	local expired = context(); local old = expired:preview(synthesis())
	expired.now += Config.PreviewLifetime + 1
	rejectedWithoutMutation(expired, "COMMIT", { Token = old.Token })
end)

test("A new preview invalidates a previous operation token", function()
	local c = context(); local old = c:preview(synthesis())
	c:preview(synthesis({ "e" }))
	rejectedWithoutMutation(c, "COMMIT", { Token = old.Token })
end)

test("Rare donors require explicit confirmation, with no cost on rejection", function()
	-- 4-star and below do not require rare confirmation
	local c4 = context(); c4.profile.Heroes.d = hero("d", "hero_morrigan"); PitService.EnsureDefaults(c4.profile)
	local p4 = c4:preview(synthesis())
	equal(p4.RequiresRareConfirmation, false)

	-- 5-star heroes require explicit confirmation
	local c = context(); c.profile.Heroes.d = hero("d", "hero_ignis"); PitService.EnsureDefaults(c.profile)
	local p = c:preview(synthesis())
	equal(p.RequiresRareConfirmation, true)
	rejectedWithoutMutation(c, "COMMIT", { Token = p.Token, ConfirmRare = false, ConfirmOverflow = true })
	p = c:preview(synthesis()); check(c:commit(p, { ConfirmOverflow = true }).Success)
	equal(c.profile.Heroes.d, nil)
end)

test("Reentrant requests observe the per-player lock and cannot double consume", function()
	local c = context(); local p = c:preview(synthesis())
	local nested
	c.onSync = function() nested = c.service:Request(c.player, "COMMIT", { Token = p.Token, ConfirmRare = true }) end
	local result = c:commit(p)
	check(result.Success); equal(nested.Success, false); equal(c.profile.Heroes.r.Level, 2)
	equal(c.profile.Heroes.d, nil); equal(c.service.Locks[c.player], nil)
end)

test("Replication exceptions preserve a committed success and release the lock", function()
	local c = context(); local p = c:preview(synthesis())
	c.onSync = function() error("simulated network sync error") end
	check(c:commit(p).Success); equal(c.profile.Heroes.d, nil); equal(c.profile.Heroes.r.Level, 2)
	equal(c.service.Locks[c.player], nil); check(c:request("STATE").Success)
end)

test("Committed deltas contain only affected heroes and exact removals", function()
	local c = context(); local p = c:preview(synthesis())
	local result = c:commit(p); check(result.Success); check(result.Delta)
	equal(result.State, nil); check(result.Delta.Heroes.r); equal(result.Delta.Heroes.e, nil)
	equal(#result.Delta.Removed, 1); equal(result.Delta.Removed[1], "d")
	equal(result.Delta.Revision, c.profile.PitRevision)
end)

test("Delta construction failure cannot misreport an already committed transaction", function()
	local c = context(); local p = c:preview(synthesis())
	c.service.Delta = function() error("simulated post-commit delta failure") end
	local result = c:commit(p); check(result.Success); equal(result.Delta, nil)
	equal(c.profile.Heroes.d, nil); equal(c.profile.Heroes.r.Level, 2)
	equal(c.service.Locks[c.player], nil)
end)

test("Recipient recovery and reservation reject before donors are lost", function()
	for _, fields in ipairs({ { ComaUntilTimestamp = os.time() + 1000 }, { ReservedBy = "operation" } }) do
		local c = context(); for key, value in pairs(fields) do c.profile.Heroes.r[key] = value end
		rejectedWithoutMutation(c, "PREVIEW", synthesis())
	end
	local c = context(); c.profile.Heroes.r.Level = 9; c.profile.Heroes.r.XP = 1190
	local p = c:preview(synthesis()); check(p.CanCommit); check(c:commit(p).Success)
	equal(c.profile.Heroes.r.Level, 10); equal(c.profile.Heroes.r.OverflowXP, 96)
end)

test("Synthesis rejects already-maxed heroes and rejects excess donors beyond the level cap", function()
	for _, scenario in ipairs({
		{ Stars = 1, Level = 10, Reserve = 3400 },
		{ Stars = 7, Level = 10, Reserve = 0 },
	}) do
		local c = context()
		local recipient = c.profile.Heroes.r
		recipient.Stars, recipient.Level, recipient.OverflowXP = scenario.Stars, scenario.Level, scenario.Reserve
		rejectedWithoutMutation(c, "PREVIEW", synthesis())
	end

	local cExcess = context()
	cExcess.profile.Heroes.r.Level = 9
	cExcess.profile.Heroes.r.XP = 1190
	rejectedWithoutMutation(cExcess, "PREVIEW", synthesis({ "d", "e" }))

	local cValid = context()
	cValid.profile.Heroes.r.Level = 9
	cValid.profile.Heroes.r.XP = 1190
	local p = cValid:preview(synthesis({ "d" }))
	check(p.CanCommit)
	local result = cValid:commit(p)
	check(result.Success)
	equal(cValid.profile.Heroes.r.Level, 10)
	equal(cValid.profile.Heroes.r.XP, 0)
end)

test("Valid promotion charges exact resources and cannot repeat", function()
	local c = context(); c.profile.Heroes.r.Level = 10
	local p = c:preview({ Action = "PROMOTION", Recipient = "r" }); check(p.CanCommit)
	equal(p.Costs.Gold, 1500); equal(p.Costs.PromotionStone, 1)
	check(c:commit(p).Success); equal(c.profile.Currencies.Gold, 998500); equal(c.profile.PitMaterials.PromotionStone, 99)
	equal(c.profile.Heroes.r.Stars, 2); equal(c.profile.Heroes.r.BaseATK, 60)
	equal(c.profile.Heroes.r.BaseLabor, 18.9)
	rejectedWithoutMutation(c, "COMMIT", { Token = p.Token })
	rejectedWithoutMutation(c, "PREVIEW", { Action = "PROMOTION", Recipient = "r" })
end)

test("Promotion validates cap, Gold, stones and five-star ceiling without research gates", function()
	local scenarios = {
		function(p) p.Heroes.r.Level = 9 end,
		function(p) p.Currencies.Gold = 1499 end,
		function(p) p.PitMaterials.PromotionStone = 0 end,
		function(p) p.Heroes.r.Stars = 7; p.Heroes.r.Level = 10 end,
	}
	for _, mutate in ipairs(scenarios) do
		local c = context(); c.profile.Heroes.r.Level = 10; mutate(c.profile)
		rejectedWithoutMutation(c, "PREVIEW", { Action = "PROMOTION", Recipient = "r" })
	end
	local c = context(); c.profile.Heroes.r.Stars = 4; c.profile.Heroes.r.Level = 10
	local p = c:preview({ Action = "PROMOTION", Recipient = "r" }); check(p.CanCommit); check(c:commit(p).Success)
	equal(c.profile.Heroes.r.Stars, 5)
	local cDonor = context(); cDonor.profile.Heroes.r.Level = 10
	rejectedWithoutMutation(cDonor, "PREVIEW", { Action = "PROMOTION", Recipient = "r", Donors = { "d" } })
	for _, tier in ipairs({ { Stars = 5, Gold = 450000, Stones = 40 }, { Stars = 6, Gold = 1250000, Stones = 85 } }) do
		local cTier = context()
		cTier.profile.Currencies.Gold = 5000000
		cTier.profile.PitMaterials.PromotionStone = 500
		cTier.profile.Heroes.r.Stars = tier.Stars
		cTier.profile.Heroes.r.Level = 10
		local pTier = cTier:preview({ Action = "PROMOTION", Recipient = "r" })
		check(pTier.CanCommit)
		equal(pTier.Costs.Gold, tier.Gold)
		equal(pTier.Costs.PromotionStone, tier.Stones)
		check(cTier:commit(pTier).Success)
		equal(cTier.profile.Heroes.r.Stars, tier.Stars + 1)
	end
end)

test("Current profiles promote without retired research currency or lab facilities", function()
	for _, stars in ipairs({ 3, 4 }) do
		local c = context()
		c.profile.Currencies.ResearchPoints = nil
		c.profile.Facilities.DimensionalLab = nil
		c.profile.UnlockedResearch = nil
		PitService.EnsureDefaults(c.profile)
		local state = c:request("STATE")
		check(state.Success); equal(state.State.Research, nil)
		equal(state.State.Resources.ResearchPoints, nil)
		c.profile.Heroes.r.Stars, c.profile.Heroes.r.Level = stars, 10
		local preview = c:preview({ Action = "PROMOTION", Recipient = "r" })
		check(preview.CanCommit); check(c:commit(preview).Success)
		equal(c.profile.Heroes.r.Stars, stars + 1)
	end
end)

test("Promotion updates actual assigned facility labor without double scaling", function()
	local c = context(); local r = c.profile.Heroes.r
	r.Level = 10; r.Assignment = "FACILITY_GUARD_POST"
	c.profile.Facilities.GuardPost = { Level = 1, AssignedHeroUUIDs = { "r" } }
	local beforeLabor = Stats.GetEffectiveLabor(r)
	local p = c:preview({ Action = "PROMOTION", Recipient = "r" }); check(c:commit(p).Success)
	local promoted = c.profile.Heroes.r; local actualLabor = Stats.GetEffectiveLabor(promoted)
	equal(promoted.Assignment, "FACILITY_GUARD_POST"); equal(c.profile.Facilities.GuardPost.AssignedHeroUUIDs[1], "r")
	check(actualLabor > beforeLabor); equal(actualLabor, p.After.Labor)
	local afterGold = Stats.GetPassiveGoldRate(1, actualLabor)
	local beforeGold = Stats.GetPassiveGoldRate(1, beforeLabor)
	check(afterGold > beforeGold)
	c:request("STATE"); equal(Stats.GetEffectiveLabor(c.profile.Heroes.r), actualLabor)
end)

test("Conversion and crafting were removed with Soul Essence", function()
	rejectedWithoutMutation(context(), "PREVIEW", { Action = "CONVERSION", Donors = { "d", "e" } })
	rejectedWithoutMutation(context(), "PREVIEW", { Action = "CRAFT", Recipe = "PromotionStone" })
	equal(Config.Conversion, nil); equal(Config.Recipes, nil)
	equal(context():request("STATE").State.Recipes, nil)
end)

test("Lock control invalidates previews and cannot unlock a unique or foreign hero", function()
	local c = context(); local p = c:preview(synthesis())
	check(c:request("LOCK", { Hero = "d", Locked = true }).Success); equal(c.profile.Heroes.d.Locked, true)
	rejectedWithoutMutation(c, "COMMIT", { Token = p.Token })
	check(c:request("LOCK", { Hero = "d", Locked = false }).Success); equal(c.profile.Heroes.d.Locked, false)
	c.profile.Heroes.d = hero("d", "hero_archon"); PitService.EnsureDefaults(c.profile)
	rejectedWithoutMutation(c, "LOCK", { Hero = "d", Locked = false })
	rejectedWithoutMutation(c, "LOCK", { Hero = "foreign-only", Locked = false })
	rejectedWithoutMutation(c, "LOCK", { Hero = "r", Locked = 0 })
end)

test("Deliberate unified unlock clears current and legacy favorite protection", function()
	local c = context(); local donor = c.profile.Heroes.d
	donor.Locked = true; donor.Favorite = true; donor.Favorited = true
	rejectedWithoutMutation(c, "PREVIEW", synthesis())
	local result = c:request("LOCK", { Hero = "d", Locked = false })
	check(result.Success); equal(donor.Locked, false); equal(donor.Favorite, false); equal(donor.Favorited, false)
	equal(result.Delta.Heroes.d.PitStatus.EligibleDonor, true)
	local p = c:preview(synthesis()); check(p.CanCommit); check(c:commit(p).Success)
	equal(c.profile.Heroes.d, nil)
end)

test("Two Masters' simultaneous valid operations affect only their own profiles", function()
	local c = context()
	local first = c:preview(synthesis({ "d" }))
	local second = c:preview(synthesis({ "e" }), c.other)
	check(c:commit(first).Success); check(c:commit(second, nil, c.other).Success)
	equal(c.profile.Heroes.d, nil); check(c.profile.Heroes.e)
	equal(c.otherProfile.Heroes.e, nil); check(c.otherProfile.Heroes.d)
	equal(c.profile.Heroes.r.Level, 2); equal(c.otherProfile.Heroes.r.Level, 2)
end)

test("Combat EXP requires active participation, bounds awards and applies cooldown", function()
	local c = context(); local before = Math.Copy(c.profile)
	equal(c.service:GrantCombatXP(c.player, "r", 25), false); check(deepEqual(c.profile, before))
	c.profile.Heroes.r.Assignment = "SQUAD_SLOT_1"; c.profile.DeployedSquadOrder = { "r" }
	check(c.service:GrantCombatXP(c.player, "r", 1e9)); equal(c.profile.Heroes.r.Level, 2); equal(c.profile.Heroes.r.XP, 100)
	equal(c.service:GrantCombatXP(c.player, "r", 25), false)
	c.now += Config.CombatXP.Cooldown; check(c.service:GrantCombatXP(c.player, "r", 25))
	equal(c.profile.Heroes.r.XP, 125)
	for _, invalid in ipairs({ -1, 0, 0 / 0, math.huge }) do equal(c.service:GrantCombatXP(c.player, "r", invalid), false) end
	c.now += Config.CombatXP.Cooldown; c.profile.Heroes.r.CurrentStamina = 0
	equal(c.service:GrantCombatXP(c.player, "r", 25), false)
	c.profile.Heroes.r.CurrentStamina = 100; c.profile.Heroes.r.ComaUntilTimestamp = os.time() + 1000
	equal(c.service:GrantCombatXP(c.player, "r", 25), false)
end)

test("Combat EXP holds the player lock through replication and rejects reentrant grants", function()
	local c = context(); local p = c:preview(synthesis())
	c.profile.Heroes.r.Assignment = "SQUAD_SLOT_1"; c.profile.DeployedSquadOrder = { "r" }
	local nestedCommit, nestedGrant, callbackCount
	callbackCount = 0
	c.service.Dependencies.SyncCombatXP = function(player, uuid, after)
		callbackCount += 1
		equal(c.service.Locks[player], true)
		equal(after.XP, 25); equal(c.profile.Heroes[uuid].XP, 25)
		nestedCommit = c.service:Request(player, "COMMIT", { Token = p.Token, ConfirmRare = true })
		nestedGrant = c.service:GrantCombatXP(player, uuid, 25)
	end
	local ok, result = c.service:GrantCombatXP(c.player, "r", 25)
	check(ok); equal(result.Before.XP, 0); equal(result.After.XP, 25)
	equal(nestedCommit.Success, false); equal(nestedGrant, false); equal(callbackCount, 1)
	equal(c.profile.Heroes.r.XP, 25); check(c.profile.Heroes.d); equal(c.profile.PitRevision, 1)
	equal(c.service.Locks[c.player], nil)
	check(c:request("STATE").Success)
end)

test("Combat EXP replication exceptions preserve one committed award and release the lock", function()
	local c = context(); c.profile.Heroes.r.Assignment = "SQUAD_SLOT_1"; c.profile.DeployedSquadOrder = { "r" }
	c.service.Dependencies.SyncCombatXP = function() error("simulated combat replication error") end
	local ok, result = c.service:GrantCombatXP(c.player, "r", 25)
	check(ok); equal(result.Before.XP, 0); equal(result.After.XP, 25)
	equal(c.profile.Heroes.r.XP, 25); equal(c.profile.PitRevision, 1); equal(c.service.Locks[c.player], nil)
	equal(c.service:GrantCombatXP(c.player, "r", 25), false)
	equal(c.profile.Heroes.r.XP, 25); equal(c.profile.PitRevision, 1)
	check(c:request("STATE").Success)
end)

test("Missing profiles, unknown commands and forgotten sessions fail safely", function()
	local c = context()
	equal(c:request("STATE", nil, "disconnected-player").Success, false)
	rejectedWithoutMutation(c, "BAD_COMMAND", {})
	local p = c:preview(synthesis()); c.service:Forget(c.player)
	rejectedWithoutMutation(c, "COMMIT", { Token = p.Token })
	equal(c.service.LastPreview[c.player], nil); equal(c.service.Locks[c.player], nil)
end)

test("Higher-rarity hero promotion preserves inherent rarity combat and labor multipliers", function()
	local eorka = hero("e", "hero_valeria", { Stars = 4, Level = 10 })
	equal(eorka.Stars, 4)

	local beforeATK, beforeHP = Stats.GetEffectiveCombatStats(eorka, false, false)
	local beforeLabor = Stats.GetEffectiveLabor(eorka)
	local promoted = Math.Promote(eorka)
	local afterATK, afterHP = Stats.GetEffectiveCombatStats(promoted, false, false)
	local afterLabor = Stats.GetEffectiveLabor(promoted)

	equal(promoted.Stars, 5)
	check(afterHP > beforeHP, "Promoted 4★ -> 5★ hero must gain HP instead of losing rarity multiplier")
	check(afterATK > beforeATK, "Promoted 4★ -> 5★ hero must gain ATK instead of losing rarity multiplier")
	check(afterLabor > beforeLabor, "Promoted 4★ -> 5★ hero must gain Labor instead of losing rarity multiplier")
end)

test("Tower floor first-clear and repeat Promotion Stone drops scale deterministically", function()
	local TowerFloorConfig = require(nodes["ReplicatedStorage.Shared.Config.TowerFloorConfig"])

	-- First-clear guaranteed stones (50 floors total, 5 floors per biome)
	equal(TowerFloorConfig.GetFirstClearPromotionStones(3, "ALPHA"), 1)
	equal(TowerFloorConfig.GetFirstClearPromotionStones(5, "BOSS"), 3)
	equal(TowerFloorConfig.GetFirstClearPromotionStones(25, "BOSS"), 7)
	equal(TowerFloorConfig.GetFirstClearPromotionStones(50, "BOSS"), 12)
	equal(TowerFloorConfig.GetFirstClearPromotionStones(0, "ALPHA"), 0)

	-- Repeat kills
	equal(TowerFloorConfig.RollPromotionStones(1, "REGULAR", 0.001, 1.0), 0)
	equal(TowerFloorConfig.RollPromotionStones(10, "ELITE", 0.01, 0.5), 1)
	equal(TowerFloorConfig.RollPromotionStones(10, "ELITE", 0.99, 0.5), 0)
	equal(TowerFloorConfig.RollPromotionStones(40, "BOSS", 0.10, 0.25), 3)
	equal(TowerFloorConfig.RollPromotionStones(10, "BOSS", 0.99, 0.5), 0)
end)

print(string.format("Pit regression tests: %d passed, %d failed", passed, failed))
if failed > 0 then error(tostring(failed) .. " Pit regression test(s) failed") end
