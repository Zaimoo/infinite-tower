--!strict
-- tests/forge.spec.luau
-- Authoritative unit and regression tests for Blacksmith Forge System:
--   1. Crafting recipes, materials & class restrictions
--   2. Stat scaling: Level +4 (120 ATK) -> Level +5 (155 ATK) parity
--   3. Fodder requirements (1 to 5 progression)
--   4. Max level cap enforcement

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArtifactCatalog = require(ReplicatedStorage.Shared.Config.ArtifactCatalog)

local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		print("PASS " .. name)
	else
		print("FAIL " .. name .. ": " .. tostring(err))
		error(err)
	end
end

local function assertEqual(a: any, b: any, msg: string?)
	if a ~= b then
		error(string.format("%s: expected %s, got %s", msg or "Assertion failed", tostring(b), tostring(a)))
	end
end

-- 1. Recipe catalog checks
test("Featured mock recipes exist with exact costs and properties", function()
	local blade = ArtifactCatalog.Seeds.art_blade_of_the_rift
	assert(blade ~= nil, "Blade of the Rift missing")
	assertEqual(blade.DisplayName, "Blade of the Rift")
	assertEqual(blade.Type, "SWORD_SHIELD")
	assertEqual(blade.CraftCost.IronGear, 5)
	assertEqual(blade.CraftCost.RiftOrb, 3)

	local aegis = ArtifactCatalog.Seeds.art_aegis_core
	assert(aegis ~= nil, "Aegis Core missing")
	assertEqual(aegis.DisplayName, "Aegis Core")
	assertEqual(aegis.Type, "SWORD_SHIELD")
	assertEqual(aegis.CraftCost.IronGear, 8)
	assertEqual(aegis.CraftCost.AegisGem, 2)

	assert(ArtifactCatalog.Seeds.art_ring_of_haste == nil, "Rings are removed")
end)

-- 2. Crafting materials metadata
test("Crafting materials define icon and color metadata", function()
	for _, matKey in { "IronGear", "RiftOrb", "AegisGem", "StarDust", "VoidPowder" } do
		local info = ArtifactCatalog.CraftingMaterials[matKey]
		assert(info ~= nil, "Missing crafting material: " .. matKey)
		assert(info.Name ~= nil and #info.Name > 0, "Missing material name")
		assert(info.Icon ~= nil and #info.Icon > 0, "Missing material icon")
	end
end)

-- 3. Class Restrictions
test("Each archetype equips exactly one weapon type", function()
	local expected = {
		Vanguard = "SWORD_SHIELD",
		Striker = "DAGGERS",
		Marksman = "BOW",
		Miner = "AXE",
		Scholar = "STAFF",
		Healer = "TOME",
	}
	local weaponTypes = { "SWORD_SHIELD", "DAGGERS", "BOW", "AXE", "STAFF", "TOME" }
	for role, allowedType in expected do
		for _, weaponType in weaponTypes do
			assertEqual(ArtifactCatalog.CanHeroEquip(role, weaponType :: any), weaponType == allowedType, role .. " / " .. weaponType)
		end
		assert(not ArtifactCatalog.CanHeroEquip(role, "RING" :: any), role .. " cannot equip RING")
		assert(not ArtifactCatalog.CanHeroEquip(role, "SHIELD" :: any), role .. " cannot equip SHIELD")
		assert(not ArtifactCatalog.CanHeroEquip(role, "SWORD" :: any), role .. " cannot equip legacy SWORD")
	end
end)

test("Every catalog and banner artifact belongs to a live weapon type", function()
	local live = {}
	for _, weaponType in ArtifactCatalog.ArchetypeWeaponType do
		live[weaponType] = true
	end
	for id, seed in ArtifactCatalog.Seeds do
		assert(live[seed.Type], id .. " has orphan type " .. seed.Type)
	end
	local banner = ArtifactCatalog.Banner
	for _, pool in { banner.Featured5Stars, banner.Pool4Stars, banner.Pool3Stars, banner.Pool12Stars } do
		for _, id in pool do
			assert(ArtifactCatalog.Seeds[id] ~= nil, "Banner references missing seed " .. id)
		end
	end
	for _, id in ArtifactCatalog.CraftingRecipeOrder do
		assert(ArtifactCatalog.Seeds[id] ~= nil, "Recipe order references missing seed " .. id)
	end
end)

-- Star progression replaces enhancement; named templates cannot bypass the formula.
test("Mythical power and speed are inherent and ignore enhancement fields",function()
 for _,id in {"art_blade_of_the_rift","art_iron_broadsword","art_crystal_greatbow"} do
  local p,speed=ArtifactCatalog.CalculateEffectiveStats(7,7,0,id)
  assertEqual(p,112000);assertEqual(speed,.30)
  local legacy=ArtifactCatalog.CalculateEffectiveStats(7,7,999,id)
  assertEqual(legacy,p)
 end
 assertEqual(ArtifactCatalog.MaxStars,7)
 assertEqual(ArtifactCatalog.GetFodderRequirement(6),6)
 assertEqual(ArtifactCatalog.GetFodderRequirement(7),0)
end)

-- 7. Artifact Banner configuration & pity math
test("Artifact banner Echoes of the Rift matches mockup pricing and pity", function()
	local banner = ArtifactCatalog.Banner
	assert(banner ~= nil, "ArtifactCatalog.Banner missing")
	assertEqual(banner.Title, "ECHOES OF THE RIFT")
	assertEqual(banner.Cost1X, 160, "1X summon costs 160 gems")
	assertEqual(banner.Cost10X, 1600, "10X summon costs 1600 gems")
	assertEqual(banner.MaxPity, 50, "Pity threshold is 50 pulls")
	assertEqual(ArtifactCatalog.GetPityRemaining(8), 42, "Mockup parity: initial pity is 42 remaining")
	assertEqual(ArtifactCatalog.GetPityRemaining(49), 1, "49 pulls gives 1 remaining to guaranteed 5-star")
	assertEqual(ArtifactCatalog.GetPityRemaining(50), 50, "50 pulls resets to 50 remaining")
end)

local Promotion=require(ReplicatedStorage.Shared.Util.WeaponPromotion)
local Stats=require(ReplicatedStorage.Shared.Util.StatFormulas)
local Heroes=require(ReplicatedStorage.Shared.Config.HeroCatalog)
local Balance=require(ReplicatedStorage.Shared.Config.StatBalance)
local function fixture()
 local p={Currencies={Gold=300000,Gems=1000},Heroes={},Artifacts={target={TemplateId="art_iron_broadsword",Star=6,Rarity=7,Level=999}}}
 local donors={}
 for i=1,6 do local id="donor"..i;p.Artifacts[id]={TemplateId="art_iron_broadsword",Star=1,Rarity=1};table.insert(donors,id) end
 return p,donors
end
test("Six-donor final promotion preserves rarity and commits exact resources once",function()
 local p,d=fixture();local target=p.Artifacts.target
 local ok,_,star=Promotion.Promote(p,"target",d)
 assert(ok);assertEqual(star,7);assertEqual(target.Rarity,7);assertEqual(target.Level,999)
 assertEqual(p.Currencies.Gold,50000);assertEqual(p.Currencies.Gems,500)
 for _,id in d do assert(p.Artifacts[id]==nil) end
 assert(not Promotion.Promote(p,"target",d));assertEqual(p.Currencies.Gold,50000)
end)
test("Every promotion step charges exactly once and retains identity, rarity and speed",function()
 for star=1,6 do
  local p,d=fixture();p.Artifacts.target.Star=star
  for i=6,star+1,-1 do d[i]=nil end
  local rule=Balance.WeaponPromotionCosts[star]
  local before=p.Artifacts.target
  local ok=Promotion.Promote(p,"target",d);assert(ok)
  assert(p.Artifacts.target==before);assertEqual(before.Star,star+1);assertEqual(before.Rarity,7)
  assertEqual(p.Currencies.Gold,300000-rule.Gold);assertEqual(p.Currencies.Gems,1000-rule.Gems)
  local _,speed=ArtifactCatalog.CalculateEffectiveStats(before.Star,before.Rarity)
  assertEqual(speed,.3)
  assert(not Promotion.Promote(p,"target",d));assertEqual(p.Currencies.Gold,300000-rule.Gold)
 end
end)
test("Malformed, stale, protected and insufficient promotions reject without mutation",function()
 for _,change in {
  function(p,d) d[6]=d[1] end,
  function(p,d) d[6]="target" end,
  function(p,d) d[6]="foreign" end,
  function(p,d) d[6]=nil end,
  function(p,d) d[7]="extra" end,
  function(p,d) d.fake="donor1" end,
  function(p,d) p.Artifacts.donor1.Locked=true end,
  function(p,d) p.Artifacts.donor1.EquippedHeroUUID="hero" end,
  function(p,d) p.Heroes.hero={EquippedArtifactUUID="donor1"} end,
  function(p,d) p.Artifacts.donor1.TemplateId="other" end,
  function(p,d) p.Currencies.Gold=0 end,
  function(p,d) p.Currencies.Gems=0 end,
  function(p,d) p.Artifacts.target.Star=0/0 end,
 } do
  local p,d=fixture();change(p,d);local gold,gems=p.Currencies.Gold,p.Currencies.Gems
  local ok=Promotion.Promote(p,"target",d);assert(not ok)
  assertEqual(p.Currencies.Gold,gold);assertEqual(p.Currencies.Gems,gems);assert(p.Artifacts.donor1~=nil)
  assertEqual(p.Artifacts.target.Rarity,7)
 end
end)
test("All hero/weapon tiers are finite, monotonic and independent of legacy levels",function()
 for id,seed in Heroes.Seeds do
  local hero={TemplateId=id,Stars=5,Level=50,QualityScalar=1,CurrentStamina=100}
  for r=1,16 do
   local last=0
   for star=1,7 do
    local artifact={TemplateId="art_iron_broadsword",Rarity=r,Star=star,Level=10000}
    local v=Stats.GetCombatSnapshot(hero,artifact)
    assert(v.AttackDamage>last);last=v.AttackDamage
    assert(v.AttackSpeed<=5);assertEqual(v.MovementSpeed,20)
    local expectedPower=Balance.RarityPower[r]*Balance.WeaponStarMultipliers[star]
    local rarity=Balance.HeroRarityCombatMultiplier^(seed.Rarity-1) -- inherent hero rarity (Phase 4 §7)
    assertEqual(v.AttackDamage,math.round(seed.BaseATK_1Star*rarity*81*1.08^49*(1+expectedPower/40)))
    assert(math.abs(v.AttackSpeed-(1+Balance.RaritySpeed[r])/seed.AttackInterval)<1e-9)
    assertEqual(v.Health,math.round(seed.BaseHP_1Star*rarity*81*1.08^49))
   end
  end
 end
end)
test("Low-quality mixed squad exceeds one billion DPS at 75 percent uptime",function()
 local total=0
 for _,id in {"hero_han","hero_jenna","hero_aaron","hero_velkist","hero_eolka"} do
  local h={TemplateId=id,Stars=5,Level=50,QualityScalar=.9,CurrentStamina=100}
  local v=Stats.GetCombatSnapshot(h,{Star=7,Rarity=7})
  total+=v.DPS
 end
 -- Includes the inherent hero rarity multiplier (Aaron/Velkist 1.35x, Eolka 1.8225x; Phase 4 §7).
 assert(math.abs(total*.75-2312856397)<2)
 assert(total*.75>1e9)
 assertEqual(Balance.GetFloorStats(50,"BOSS").MaxHP,61580351563)
end)
test("Legacy trait and imprint fields cannot restore retired stat bonuses",function()
 local hero={TemplateId="hero_han",Stars=5,Level=50,QualityScalar=1,CurrentStamina=100}
 local clean=Stats.GetCombatSnapshot(hero,{Star=7,Rarity=7})
 hero.PassiveTrait="Blood Pact";hero.TraitATKBonus=100;hero.TraitHPBonus=100;hero.InheritedImprints={melee_memory=3}
 local legacy=Stats.GetCombatSnapshot(hero,{Star=7,Rarity=7,Level=999},false,true)
 assertEqual(legacy.AttackDamage,clean.AttackDamage);assertEqual(legacy.Health,clean.Health)
 assertEqual(legacy.AttackSpeed,clean.AttackSpeed)
end)
test("Formatting supports damage and health above unsigned 32-bit range",function()
 assertEqual(Balance.Format(110844632813),"110.84B")
 assertEqual(Balance.Format(0/0),"0")
end)
print("All Forge spec tests passed successfully!")
