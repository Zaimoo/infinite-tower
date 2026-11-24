--!strict
-- tests/battlepass.spec.luau
-- Battle Pass and potions (GDD §4.9): seasons, XP and levels, the free and premium rows, the season
-- rollover, potion boosts and their hooks into rewards, summon luck, the Store and save migration.

local PassConfig = require(nodes["ReplicatedStorage.Shared.Config.BattlePassConfig"])
local PotionConfig = require(nodes["ReplicatedStorage.Shared.Config.PotionConfig"])
local Pass = require(nodes["ReplicatedStorage.Shared.Util.BattlePassRules"])
local Potions = require(nodes["ReplicatedStorage.Shared.Util.PotionRules"])
local RewardRules = require(nodes["ReplicatedStorage.Shared.Util.RewardRules"])
local SummonLuck = require(nodes["ReplicatedStorage.Shared.Util.SummonLuck"])
local ShopConfig = require(nodes["ReplicatedStorage.Shared.Config.ShopConfig"])
local Migrations = require(nodes["ServerScriptService.Core.ProfileMigrations"])

local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end

local DAY = 86400
local EPOCH = PassConfig.Epoch
local SEASON = PassConfig.SeasonDays * DAY
local LEVEL = PassConfig.XpPerLevel

test("battle pass: both rows have a reward per level and only pay known potions", function()
	assert(#PassConfig.Free == PassConfig.MaxLevel and #PassConfig.Premium == PassConfig.MaxLevel, "one reward per level")
	for _, row in { PassConfig.Free, PassConfig.Premium } do
		for level, reward in row do
			assert(RewardRules.Describe(reward) ~= "", "level " .. level .. " pays something")
			for id, amount in reward.Potions or {} do
				assert(PotionConfig.Potions[id] ~= nil and amount > 0, "level " .. level .. " pays a known potion")
			end
		end
	end
	for source, xp in PassConfig.Xp do
		assert(xp > 0 and xp < LEVEL, source .. " pays less than a level")
	end
end)

test("battle pass: seasons run back to back from the epoch on UTC", function()
	assert(EPOCH % DAY == 0, "the epoch is midnight UTC")
	assert((EPOCH / DAY + 3) % 7 == 0, "the epoch is a Monday")
	assert(Pass.SeasonOf(EPOCH) == 1 and Pass.SeasonOf(EPOCH + SEASON - 1) == 1, "season 1 lasts SeasonDays")
	assert(Pass.SeasonOf(EPOCH + SEASON) == 2, "season 2 starts the next second")
	assert(Pass.SeasonOf(EPOCH - 5 * DAY) == 1, "a clock before the epoch still has a season")
	assert(Pass.SeasonEndsAt(1) == EPOCH + SEASON and Pass.SeasonEndsAt(2) == EPOCH + 2 * SEASON, "end times")
	assert(Pass.SeasonName(1) ~= Pass.SeasonName(2), "names cycle")
	assert(string.find(Pass.SeasonName(#PassConfig.SeasonNames + 1), PassConfig.SeasonNames[1], 1, true) ~= nil, "names wrap around")
end)

test("battle pass: XP turns into levels and stops at the cap", function()
	local state = Pass.NewState(EPOCH)
	assert(Pass.LevelOf(state.Xp) == 0 and Pass.AddXp(state, LEVEL - 1) == 0, "just short of level 1")
	assert(Pass.AddXp(state, 1) == 1 and Pass.LevelOf(state.Xp) == 1, "level 1")
	local into, needed = Pass.Progress(state.Xp)
	assert(into == 0 and needed == LEVEL, "progress restarts each level")
	assert(Pass.AddXp(state, 2.5 * LEVEL) == 2, "several levels at once")
	assert(Pass.AddXp(state, -50) == 0 and Pass.AddXp(state, 0 / 0) == 0, "bad amounts are ignored")
	Pass.AddXp(state, 1e9)
	assert(state.Xp == PassConfig.MaxLevel * LEVEL and Pass.LevelOf(state.Xp) == PassConfig.MaxLevel, "capped at the max level")
	into, needed = Pass.Progress(state.Xp)
	assert(into == needed, "the bar is full at the max level")
end)

test("battle pass: the free row pays each reached level once", function()
	local state = Pass.NewState(EPOCH)
	Pass.AddXp(state, 2 * LEVEL)
	assert(Pass.Status(state, "Free", 1) == "Claim" and Pass.Status(state, "Free", 3) == "Locked", "statuses")
	assert(Pass.Claim(state, "Free", 1) == PassConfig.Free[1], "level 1 pays its reward")
	local again, problem = Pass.Claim(state, "Free", 1)
	assert(again == nil and problem ~= nil and Pass.Status(state, "Free", 1) == "Claimed", "second claim refused")
	assert(Pass.Claim(state, "Free", 3) == nil, "a level not reached is refused")
	for _, bad in { 0, -1, 1.5, PassConfig.MaxLevel + 1, 0 / 0, "2", {} } :: { any } do
		assert(Pass.Claim(state, "Free", bad) == nil, "bad level refused")
	end
	assert(Pass.Claim(state, "Gold", 2) == nil and Pass.Claim(state, nil, 2) == nil, "bad track refused")
	assert(Pass.Claim(state, "Free", 2) == PassConfig.Free[2], "level 2 still pays after the bad requests")
end)

test("battle pass: the premium row needs the unlock, and a late unlock pays earlier levels", function()
	local state = Pass.NewState(EPOCH)
	Pass.AddXp(state, 3 * LEVEL)
	assert(Pass.Status(state, "Premium", 2) == "Premium" and Pass.Claim(state, "Premium", 2) == nil, "locked without Premium")
	assert(Pass.ClaimableCount(state) == 3, "only the free rewards are ready")
	assert(Pass.UnlockPremium(state) == true and Pass.UnlockPremium(state) == false, "unlocks once")
	assert(Pass.ClaimableCount(state) == 6, "every reached premium level opens")
	assert(Pass.Claim(state, "Premium", 2) == PassConfig.Premium[2] and Pass.Claim(state, "Premium", 2) == nil, "pays once")
	assert(Pass.Status(state, "Free", 2) == "Claim", "the rows are claimed separately")
	assert(Pass.Status(state, "Premium", 4) == "Locked", "later levels still need XP")
end)

test("battle pass: claim all pays everything ready and nothing twice", function()
	local state = Pass.NewState(EPOCH)
	Pass.AddXp(state, 4 * LEVEL)
	Pass.UnlockPremium(state)
	Pass.Claim(state, "Free", 2)
	local rewards = Pass.ClaimAll(state)
	assert(#rewards == 7, "3 free + 4 premium")
	assert(Pass.ClaimableCount(state) == 0 and #Pass.ClaimAll(state) == 0, "nothing left")
	local total = RewardRules.Merge(rewards)
	local gold = 0
	for _, level in { 1, 3, 4 } do gold += PassConfig.Free[level].Gold or 0 end
	for level = 1, 4 do gold += PassConfig.Premium[level].Gold or 0 end
	assert(total.Gold == gold, "merged Gold is the sum")
	-- The top level claims too (bit 30 of the mask).
	Pass.AddXp(state, 1e9)
	assert(Pass.Claim(state, "Premium", PassConfig.MaxLevel) == PassConfig.Premium[PassConfig.MaxLevel], "last level pays")
	assert(Pass.Status(state, "Premium", PassConfig.MaxLevel) == "Claimed" and Pass.Status(state, "Free", PassConfig.MaxLevel) == "Claim", "only that bit is set")
end)

test("battle pass: a new season delivers unclaimed rewards and resets the track", function()
	local state = Pass.NewState(EPOCH + DAY)
	Pass.AddXp(state, 2 * LEVEL)
	Pass.UnlockPremium(state)
	Pass.Claim(state, "Free", 1)
	assert(Pass.Rollover(state, EPOCH + SEASON - 1) == nil, "same season: nothing happens")
	local owed = Pass.Rollover(state, EPOCH + SEASON)
	assert(owed ~= nil and #owed == 3, "free level 2 and premium levels 1-2 are delivered")
	assert(state.Season == 2 and state.Xp == 0 and state.Premium == false and state.Free == 0 and state.Paid == 0, "fresh season")
	assert(Pass.Rollover(state, EPOCH + SEASON + 5) == nil, "delivered once")
	assert(Pass.Rollover(state, EPOCH) == nil and state.Season == 2, "a clock that moved back never rolls a season back")
	-- A locked premium row is not delivered.
	local free = Pass.NewState(EPOCH)
	Pass.AddXp(free, 2 * LEVEL)
	local owedFree = Pass.Rollover(free, EPOCH + 3 * SEASON)
	assert(owedFree ~= nil and #owedFree == 2 and free.Season == 4, "only free rewards without Premium, and seasons can be skipped")
end)

test("battle pass: a damaged save is repaired without unlocking anything", function()
	local profile: any = { BattlePass = { Season = "x", Xp = -5, Premium = "yes", Free = { true }, Paid = 2 ^ 40 } }
	local state = Pass.EnsureState(profile, EPOCH)
	assert(state.Season == 1 and state.Xp == 0 and state.Premium == false and state.Free == 0 and state.Paid == 0, "bad values reset")
	profile.BattlePass = { Season = 3, Xp = 1e12, Premium = true, Free = 5, Paid = 0 / 0 }
	state = Pass.EnsureState(profile, EPOCH)
	assert(state.Xp == PassConfig.MaxLevel * LEVEL and state.Free == 5 and state.Paid == 0 and state.Premium == true, "valid values kept, XP clamped")
	local blank: any = {}
	assert(Pass.Read(blank) == nil, "no state to read yet")
	assert(Pass.EnsureState(blank, EPOCH + SEASON).Season == 2 and Pass.Read(blank) ~= nil, "created for the current season")
end)

test("potions: one potion per effect, each with a drawing name and a boost attribute", function()
	local effects = {}
	for _, id in PotionConfig.Order do
		local potion = PotionConfig.Potions[id]
		assert(not effects[potion.Effect], "one potion per effect")
		effects[potion.Effect] = true
		assert(PotionConfig.ByEffect(potion.Effect) == potion, "lookup by effect")
		assert(potion.Icon ~= "" and PotionConfig.Attribute(potion.Effect) == "Boost" .. potion.Effect .. "Until", "icon and attribute")
	end
	for _, effect in { "Gold", "Gems", "Luck", "HeroXP", "PassXP" } do assert(effects[effect], effect .. " has a potion") end
	local Icons = require(nodes["ReplicatedStorage.Shared.Util.GrimoireIcons"])
	for _, id in PotionConfig.Order do assert(Icons.Drawings[PotionConfig.Potions[id].Icon], "missing drawing for " .. id) end
	assert(Icons.Drawings.Pass, "the Battle Pass rail icon exists")
end)

test("potions: drinking spends one and starts or extends the boost", function()
	local profile: any = {}
	Potions.EnsureState(profile)
	assert(Potions.Multiplier(profile, "Gold") == 1 and Potions.Bonus(profile, "Luck") == 0, "no boost yet")
	local ok, message = Potions.Use(profile, "GoldPotion")
	assert(not ok and message ~= "", "none owned")
	assert(Potions.Add(profile, "GoldPotion", 2) == 2 and Potions.Owned(profile, "GoldPotion") == 2, "added")
	assert(Potions.Add(profile, "Nope", 3) == 0 and Potions.Add(profile, "GoldPotion", -1) == 0 and Potions.Add(profile, "GoldPotion", 0 / 0) == 0, "bad adds ignored")
	assert(Potions.Use(profile, "GoldPotion"), "first drink")
	local minutes = PotionConfig.Potions.GoldPotion.Minutes
	assert(Potions.Remaining(profile, "Gold") == minutes * 60 and Potions.Owned(profile, "GoldPotion") == 1, "boost started, one spent")
	assert(Potions.Multiplier(profile, "Gold") == 1 + PotionConfig.Potions.GoldPotion.Amount, "multiplier while active")
	assert(Potions.Multiplier(profile, "Gems") == 1, "other effects untouched")
	assert(Potions.Use(profile, "GoldPotion"), "second drink")
	assert(Potions.Remaining(profile, "Gold") == 2 * minutes * 60 and profile.Potions.GoldPotion == nil, "time added, none left")
	assert(not Potions.Use(profile, "GoldPotion") and not Potions.Use(profile, "Nope") and not Potions.Use(profile, nil), "refused")
end)

test("potions: boosts count down with play time, end, and cannot pass the cap", function()
	local profile: any = {}
	Potions.EnsureState(profile)
	Potions.Add(profile, "LuckPotion", 50)
	Potions.Add(profile, "XpPotion", 1)
	Potions.Use(profile, "LuckPotion")
	Potions.Use(profile, "XpPotion")
	local luckSeconds = PotionConfig.Potions.LuckPotion.Minutes * 60
	assert(#Potions.Tick(profile, luckSeconds - 1) == 0 and Potions.Remaining(profile, "Luck") == 1, "one second left")
	assert(#Potions.Tick(profile, 0) == 0 and #Potions.Tick(profile, -5) == 0 and #Potions.Tick(profile, 0 / 0) == 0, "bad ticks ignored")
	local expired = Potions.Tick(profile, 5)
	assert(#expired == 1 and expired[1] == "Luck" and Potions.Bonus(profile, "Luck") == 0, "the luck boost ended")
	assert(Potions.Remaining(profile, "HeroXP") > 0 and Potions.AnyActive(profile), "the longer boost is still running")
	Potions.Tick(profile, 1e6)
	assert(not Potions.AnyActive(profile) and next(profile.Boosts) == nil, "everything ended")
	-- Stacking stops at MaxBoostSeconds and a refused drink spends nothing.
	local drinks = PotionConfig.MaxBoostSeconds // luckSeconds
	for _ = 1, drinks do assert(Potions.Use(profile, "LuckPotion"), "stack up to the cap") end
	local before = Potions.Owned(profile, "LuckPotion")
	assert(not Potions.Use(profile, "LuckPotion") and Potions.Owned(profile, "LuckPotion") == before, "over the cap: refused, not spent")
	assert(Potions.Remaining(profile, "Luck") <= PotionConfig.MaxBoostSeconds, "never past the cap")
end)

test("potions: a damaged save loses unknown entries and never gains a boost", function()
	local profile: any = { Potions = { GoldPotion = 1e9, Fake = 5, GemPotion = -3, XpPotion = "many" }, Boosts = { Gold = 1e9, Luck = 0 / 0, Fake = 100, Gems = -1 } }
	Potions.EnsureState(profile)
	assert(profile.Potions.GoldPotion == PotionConfig.MaxOwned and profile.Potions.Fake == nil and profile.Potions.GemPotion == nil and profile.Potions.XpPotion == nil, "counts repaired")
	assert(profile.Boosts.Gold == PotionConfig.MaxBoostSeconds and profile.Boosts.Luck == nil and profile.Boosts.Fake == nil and profile.Boosts.Gems == nil, "boosts repaired")
	assert(Potions.Multiplier(nil, "Gold") == 1 and Potions.Owned(nil, "GoldPotion") == 0 and not Potions.AnyActive(nil), "no profile is safe to read")
end)

test("potions: rewards can pay them, describe them and merge them", function()
	local profile: any = { Currencies = { Gold = 0, Gems = 0 } }
	local reward = PassConfig.Premium[PassConfig.MaxLevel]
	RewardRules.Grant(profile, reward)
	assert(profile.Currencies.Gems == reward.Gems and profile.PitMaterials.PromotionStone == reward.PromotionStones, "balances paid")
	assert(Potions.Owned(profile, "LuckPotion") == (reward.Potions :: any).LuckPotion, "potions paid")
	assert(string.find(RewardRules.Describe({ Potions = { GoldPotion = 1 } }), "+1 Gold Potion", 1, true) ~= nil, "singular")
	assert(string.find(RewardRules.Describe({ Gold = 500, Potions = { GemPotion = 2 } }, false), "2 Gem Potions", 1, true) ~= nil, "plural, no sign")
	local merged = RewardRules.Merge({ { Gold = 1, Potions = { GoldPotion = 1 } }, { Gems = 2, Potions = { GoldPotion = 2, XpPotion = 1 } }, { PromotionStones = 3 } })
	assert(merged.Gold == 1 and merged.Gems == 2 and merged.PromotionStones == 3, "balances merged")
	assert((merged.Potions :: any).GoldPotion == 3 and (merged.Potions :: any).XpPotion == 1, "potions merged")
	assert(PassConfig.Free[2].Potions.GoldPotion == 1, "merging never changes the config rewards")
end)

test("potions: a Luck Potion adds to summon luck with or without God's Blessing", function()
	local bonus = PotionConfig.Potions.LuckPotion.Amount
	local plain: any = { Facilities = { GodsBlessing = { Level = 0, AssignedHeroUUIDs = {} } }, Heroes = {} }
	assert(SummonLuck.ForProfile(plain) == 0, "no luck without a potion")
	plain.Boosts = { Luck = 60 }
	assert(SummonLuck.ForProfile(plain) == bonus, "the potion alone gives its luck")
	local blessed: any = { Facilities = { GodsBlessing = { Level = 1, AssignedHeroUUIDs = {} } }, Heroes = {} }
	local base = SummonLuck.ForProfile(blessed)
	assert(base > 0, "the fountain gives luck")
	blessed.Boosts = { Luck = 60 }
	assert(math.abs(SummonLuck.ForProfile(blessed) - (base + bonus)) < 1e-9, "the potion adds on top")
	local rates = SummonLuck.ApplyLuck({ 0.9, 0.08, 0.02 }, SummonLuck.ForProfile(blessed))
	assert(math.abs(rates[1] + rates[2] + rates[3] - 1) < 1e-9 and rates[3] > 0.02, "odds still add up to 1 and the top tier rose")
end)

test("battle pass: the Store sells Premium as a fixed, non-random product", function()
	local offer = ShopConfig.ById("pass_premium")
	assert(offer ~= nil and offer.Grant.Kind == "BattlePass" and offer.RobuxPrice > 0, "the offer exists")
	assert(ShopConfig.SafeGrant(offer.Grant, true) == offer.Grant, "restricted players get the same grant: it is not a random item")
end)

test("battle pass: schema v11 gives old saves a pass and potion tables", function()
	assert(Migrations.CurrentSchema >= 11, "schema 11+")
	local old: any = { SchemaVersion = 10 }
	Migrations.ToV11(old)
	assert(old.SchemaVersion == 11 and Pass.Read(old) ~= nil and old.BattlePass.Xp == 0 and old.BattlePass.Premium == false, "pass added at level 0")
	assert(type(old.Potions) == "table" and next(old.Potions) == nil and type(old.Boosts) == "table" and next(old.Boosts) == nil, "no potions, no boosts")
	local current: any = { SchemaVersion = 11, BattlePass = { Season = 1, Xp = 4200, Premium = true, Free = 3, Paid = 1 }, Potions = { GoldPotion = 2 }, Boosts = { Gold = 90 } }
	Migrations.ToV11(current)
	assert(current.BattlePass.Xp == 4200 and current.Potions.GoldPotion == 2 and current.Boosts.Gold == 90, "a current save is untouched")
end)

test("quests: progress counts towards daily and weekly quests and stops at the goal", function()
	local now = PassConfig.Epoch + 3 * 86400 + 500
	local state = Pass.NewState(now)
	assert(state.Quests.Day == Pass.DayOf(now) and state.Quests.Week == 0, "a new state starts in the current day and week")
	local byId: { [string]: any } = {}
	for _, list in { PassConfig.DailyQuests, PassConfig.WeeklyQuests } do
		for _, quest in list do byId[quest.Id] = quest end
	end
	local finished = Pass.QuestRecord(state, "Floors", 2)
	assert(#finished == 0 and Pass.QuestStatus(state, byId.d_floor) == 2, "two floors of three")
	finished = Pass.QuestRecord(state, "Floors", 5)
	assert(#finished == 1 and finished[1].Id == "d_floor", "the daily finished, the weekly did not")
	local count, status = Pass.QuestStatus(state, byId.d_floor)
	assert(count == byId.d_floor.Goal and status == "Claim", "progress stops at the goal")
	assert(select(1, Pass.QuestStatus(state, byId.w_floor)) == 7, "the weekly quest counted every floor")
	assert(#Pass.QuestRecord(state, "Nothing", 5) == 0 and #Pass.QuestRecord(state, "Floors", -3) == 0, "unknown metrics and bad amounts do nothing")
	assert(Pass.QuestClaimableCount(state) == 1, "one quest is ready")
end)

test("quests: a finished quest pays its XP once", function()
	local state = Pass.NewState(PassConfig.Epoch)
	local xp, problem = Pass.QuestClaim(state, "d_hero")
	assert(xp == nil and problem ~= nil, "an unfinished quest cannot be claimed")
	Pass.QuestRecord(state, "Heroes", 1)
	xp = Pass.QuestClaim(state, "d_hero")
	assert(xp == 100, "the daily hero quest pays 100 XP")
	assert(Pass.QuestClaim(state, "d_hero") == nil, "never twice")
	assert(Pass.QuestClaim(state, "nope") == nil and Pass.QuestClaim(state, 7) == nil, "unknown ids are refused")
	Pass.QuestRecord(state, "Artifacts", 10)
	assert(Pass.QuestClaimAll(state) == 100 + 600, "claim all pays the daily and weekly artifact quests")
	assert(Pass.QuestClaimAll(state) == 0 and Pass.QuestClaimableCount(state) == 0, "nothing left")
end)

test("quests: a new day clears dailies, a new week clears weeklies, and finished quests are owed", function()
	local monday = PassConfig.Epoch
	local state = Pass.NewState(monday)
	Pass.QuestRecord(state, "Heroes", 10) -- finishes d_hero and w_hero
	Pass.QuestRecord(state, "Kills", 20)
	local changed, owed = Pass.QuestReset(state, monday + 3600)
	assert(changed == false and owed == 0, "the same day resets nothing")
	changed, owed = Pass.QuestReset(state, monday + 86400)
	assert(changed and owed == 100, "the unclaimed daily is owed at the day's end")
	assert(state.Quests.Progress.d_hero == nil and state.Quests.Progress.d_kills == nil, "daily progress is cleared")
	assert(state.Quests.Progress.w_hero == 10 and state.Quests.Progress.w_kills == 20, "weekly progress stays")
	assert(Pass.QuestClaim(state, "w_hero") == 600, "the weekly is claimed by hand")
	changed, owed = Pass.QuestReset(state, monday + 7 * 86400)
	assert(changed and owed == 0 and next(state.Quests.Progress) == nil and next(state.Quests.Claimed) == nil, "a claimed weekly is not owed again")
	changed = Pass.QuestReset(state, monday)
	assert(changed == false and state.Quests.Week == 1, "a clock that went backwards resets nothing")
	assert(Pass.WeekEndsAt(0) == monday + 7 * 86400 and Pass.DayEndsAt(Pass.DayOf(monday)) == monday + 86400, "reset times")
end)

test("quests: old and damaged saves are repaired", function()
	local now = PassConfig.Epoch + 100
	local old: any = { BattlePass = { Season = 1, Xp = 500, Premium = false, Free = 0, Paid = 0 } }
	local state = Pass.EnsureState(old, now)
	assert(type(state.Quests) == "table" and next(state.Quests.Progress) == nil, "a save without quests gains them")
	local bad: any = { BattlePass = { Season = 1, Xp = 0, Premium = false, Free = 0, Paid = 0,
		Quests = { Day = "x", Week = 0 / 0, Progress = { d_kills = 9999, w_hero = -4, junk = 3 }, Claimed = { d_kills = true, d_floor = true, junk = true } } } }
	state = Pass.EnsureState(bad, now)
	assert(state.Quests.Day == Pass.DayOf(now) and state.Quests.Week == 0, "bad clocks become now")
	assert(state.Quests.Progress.d_kills == 50 and state.Quests.Progress.w_hero == nil and state.Quests.Progress.junk == nil, "progress is clamped to known quests")
	assert(state.Quests.Claimed.d_kills == true and state.Quests.Claimed.d_floor == nil and state.Quests.Claimed.junk == nil, "a claim needs a finished quest")
	local client: any = { Season = 1, Xp = 0, Premium = false, Free = 0, Paid = 0 }
	assert(select(2, Pass.QuestStatus(client, PassConfig.DailyQuests[1])) == "Progress" and Pass.QuestClaimableCount(client) == 0, "reads survive a missing quest table")
end)

test("quests: every quest metric has a source", function()
	local fed: { [string]: boolean } = { Heroes = true, Artifacts = true } -- reported by the summon handlers
	for source, metrics in PassConfig.QuestMetrics do
		assert(PassConfig.Xp[source] ~= nil, source .. " is an XP source")
		for _, metric in metrics do fed[metric] = true end
	end
	for _, list in { PassConfig.DailyQuests, PassConfig.WeeklyQuests } do
		for _, quest in list do assert(fed[quest.Metric], quest.Id .. " counts something the server reports") end
	end
end)

test("Robux Gold packs grant minutes of frontier income and never less than their listed amount", function()
	local Income = require(nodes["ReplicatedStorage.Shared.Util.FrontierIncome"])
	local purse, hoard = ShopConfig.ById("gold_100k"), ShopConfig.ById("gold_1680k")
	assert(purse and hoard and purse.IncomeMinutes == 10 and hoard.IncomeMinutes == 168)
	assert(ShopConfig.GrantAmount(purse, 0) == 100000, "a new Master gets the listed amount")
	assert(ShopConfig.GrantAmount(purse, nil) == 100000 and ShopConfig.GrantAmount(purse, 0 / 0) == 100000)
	local last = 0
	for floor = 1, 50 do
		local rate = Income.GoldPerMinute(floor)
		assert(rate >= last, "frontier income never falls as the Master climbs")
		last = rate
	end
	local late = ShopConfig.GrantAmount(purse, 50)
	assert(late == Income.Round(10 * Income.GoldPerMinute(50)) and late > 10000000, "a Floor 50 purse is ten minutes of Floor 50 income")
	assert(ShopConfig.GrantAmount(hoard, 50) > 16 * late, "the bigger packs keep their bonus")
	assert(ShopConfig.GrantAmount(ShopConfig.ById("gems_15700") :: any, 50) == 15700, "Gem packs never scale")
end)

print(string.format("battlepass.spec: %d passed", passed))
