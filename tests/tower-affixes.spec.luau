-- Phase F affixed Elite specs. Bundled by run.ps1 after the module list; `nodes`, `register` and `require` come from the shim.
local AffixRules = require(nodes["ReplicatedStorage.Shared.Util.AffixRules"])
local CampRoster = require(nodes["ReplicatedStorage.Shared.Util.CampRoster"])
local Floors = require(nodes["ReplicatedStorage.Shared.Config.TowerFloorConfig"])
local RelicConfig = require(nodes["ReplicatedStorage.Shared.Config.RelicConfig"])
local Protocol = require(nodes["ReplicatedStorage.Shared.Util.TowerProtocol"])
local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end
local function mob(x: number, z: number, affixes: { string }?, hp: number?): any
	return { Position = { X = x, Z = z }, Affixes = affixes, CurrentHP = hp or 1000, MaxHP = 1000 }
end

test("Affixed Elites are a chance spawn that grows with depth, with one affix (two from biome 7)", function()
	assert(math.abs(AffixRules.SpawnChance(1) - 0.10) < 1e-9 and math.abs(AffixRules.SpawnChance(10) - 0.235) < 1e-9)
	for biome = 1, 10 do
		local rng = CampRoster.Rng(biome * 977)
		local affixed, n = 0, 20000
		for _ = 1, n do
			local rolled = AffixRules.Roll(rng, biome)
			if #rolled > 0 then
				affixed += 1
				assert(#rolled == AffixRules.AffixCount(biome))
				local seen = {}
				for _, id in rolled do
					assert(not seen[id], "Duplicate affix"); seen[id] = true
				end
				assert(not (seen.SHIELDED and seen.WARDED), "Banned pair rolled")
			end
		end
		local rate = affixed / n
		assert(math.abs(rate - AffixRules.SpawnChance(biome)) < 0.015, "Biome " .. biome .. " affix rate " .. rate)
	end
end)

test("An affixed Elite drops relics four times as often, keeps role tiers, and a plain Elite is unchanged", function()
	for _, floorId in { 1, 26, 50 } do
		local base = Floors.GetKillRewards(floorId, "ELITE").RelicChance
		local biome = RelicConfig.GetBiomeForFloor(floorId)
		local eliteTierId = biome and biome.DropTable[3] or "ABYSSAL_CORE"
		local plainDrops, affixedDrops, cores, n = 0, 0, 0, 4000
		for i = 1, n do
			local roll = (i - 0.5) / n
			if Floors.RollRelic(floorId, "ELITE", AffixRules.DropRoll(mob(0, 0, nil), roll), 0.5) then plainDrops += 1 end
			local tier = Floors.RollRelic(floorId, "ELITE", AffixRules.DropRoll(mob(0, 0, { "HASTED" }), roll), (i % 100) / 100)
			if tier then affixedDrops += 1 end
			if tier == eliteTierId or tier == "ABYSSAL_CORE" then cores += 1 end
		end
		assert(math.abs(plainDrops / n - base) < 0.002)
		assert(math.abs(affixedDrops / n - math.min(1, base * AffixRules.RelicDropMultiplier)) < 0.002)
		assert(cores > 0, "Affixed Elites still roll Elite tiers")
	end
	assert(AffixRules.GoldMultiplierFor(mob(0, 0, { "HASTED" })) > 1 and AffixRules.GoldMultiplierFor(mob(0, 0, nil)) == 1)
end)

test("SHIELDED soaks first and regrows only after six quiet seconds", function()
	local m = mob(0, 0)
	AffixRules.Prepare(m, { "SHIELDED" }, 0)
	assert(m.AffixShield == 300)
	assert(AffixRules.Absorb(m, 200, 1) == 0 and m.AffixShield == 100)
	assert(AffixRules.Absorb(m, 200, 2) == 100 and m.AffixShield == 0)
	AffixRules.Regen(m, 7)
	assert(m.AffixShield == 0, "Regrew too early")
	AffixRules.Regen(m, 8)
	assert(m.AffixShield == 300)
	AffixRules.Prepare(m, {}, 9)
	assert(m.Affixes == nil and m.AffixShield == nil and AffixRules.Absorb(m, 50, 10) == 50)
end)

test("HASTED, FRENZIED and the WARDED and COMMANDER auras scale as described", function()
	local hasted = mob(0, 0, { "HASTED" })
	assert(AffixRules.SpeedMultiplier(hasted) == 1.35 and AffixRules.CooldownMultiplier(hasted) == 0.75)
	local frenzied = mob(0, 0, { "FRENZIED" }, 900)
	assert(AffixRules.AtkMultiplier(frenzied) == 1)
	frenzied.CurrentHP = 400
	assert(AffixRules.AtkMultiplier(frenzied) == 1.4 and math.abs(AffixRules.CooldownMultiplier(frenzied) - 0.8) < 1e-9)
	local warden, commander = mob(0, 0, { "WARDED" }), mob(30, 0, { "COMMANDER" })
	local close, far = mob(10, 0), mob(60, 0)
	assert(AffixRules.AuraDefense(close, { warden, commander }) == 0.75 and AffixRules.AuraDefense(far, { warden, commander }) == 1)
	assert(AffixRules.AuraDefense(warden, { warden }) == 1, "A WARDED Elite does not ward itself")
	assert(math.abs(AffixRules.AuraAtk(close, { warden, commander }) - 1.2) < 1e-9 and AffixRules.AuraAtk(far, { commander }) == 1)
end)

test("Name plates lead with the affix names", function()
	assert(AffixRules.DisplayName("Glacier Knight", { "FRENZIED", "HASTED" }) == "Frenzied, Hasted Glacier Knight")
	assert(AffixRules.DisplayName("Glacier Knight", {}) == "Glacier Knight")
end)

test("Affixed Elite snapshot flags decode cleanly so affixed Elites render visibly on the client", function()
	local ctx = {
		ServerSessionId = "0123456789abcdef0123456789abcdef",
		FloorId = 6, RoomGeneration = 1, ViewEpoch = 1,
		Origin = Vector3.new(2000, 100, 2000),
		Bounds = { Min = Vector3.new(-200, -40, -200), Max = Vector3.new(200, 120, 200) },
	}
	-- 32 = affixed Elite, 40 = affixed + shielded, 48 = affixed + roused, 56 = affixed + shielded + roused.
	for _, flags in { 32, 40, 48, 56 } do
		local elite = {
			NetId = 4101, EntityGeneration = 1,
			Position = ctx.Origin + Vector3.new(12, 4, -18),
			CurrentHP = 1000, MaxHP = 1000, Stamina = 100,
			Flags = flags, StateEnum = 20, ActionSequence = 0, Yaw = math.pi,
		}
		local packet = assert(Protocol.Decode(Protocol.Encode(ctx, { elite }, 1, 10.0)[1], ctx), "Snapshot dropped for flags=" .. flags)
		assert(packet.Entities[1].Flags == flags)
	end
end)

print("Affix tests: " .. passed .. " passed, 0 failed")
