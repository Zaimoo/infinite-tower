--!strict
-- tests/profile-delta.spec.luau
-- ProfileDelta: the diff the server sends instead of a whole profile, and the client-side apply.

local Delta = require(nodes["ReplicatedStorage.Shared.Util.ProfileDelta"])

local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end

local function profile(): any
	return {
		Currencies = { Gold = 100, Gems = 5 },
		PitMaterials = { PromotionStone = 2 },
		HighestClearedFloor = 3,
		Heroes = {
			h1 = { UUID = "h1", Level = 4, CurrentStamina = 50, Assignment = "SQUAD_SLOT_1" },
			h2 = { UUID = "h2", Level = 1, CurrentStamina = 20, Assignment = "BENCHED" },
		},
		Artifacts = {
			a1 = { UUID = "a1", Stars = 1, Locked = false },
		},
	}
end

-- What the client ends up with after the server diffs `after` against what it last sent.
local function roundTrip(before: any, after: any): (any, any)
	local delta = Delta.Diff(before, after)
	local client = Delta.DeepCopy(before)
	if delta then
		Delta.Apply(client, Delta.DeepCopy(delta))
	end
	return client, delta
end

test("an unchanged profile produces no delta", function()
	assert(Delta.Diff(profile(), profile()) == nil)
end)

test("a kill reward sends only the currencies", function()
	local before, after = profile(), profile()
	after.Currencies.Gold += 12
	local client, delta = roundTrip(before, after)
	assert(delta and delta.Set and delta.Set.Currencies.Gold == 112)
	assert(delta.Maps == nil and delta.Unset == nil, "no hero or artifact travels")
	local keys = 0
	for _ in delta.Set do keys += 1 end
	assert(keys == 1, "only Currencies is resent")
	assert(Delta.DeepEqual(client, after))
end)

test("one changed hero travels alone", function()
	local before, after = profile(), profile()
	after.Heroes.h2.CurrentStamina = 21
	local client, delta = roundTrip(before, after)
	assert(delta and delta.Maps and delta.Maps.Heroes and delta.Maps.Heroes.Set)
	assert(delta.Maps.Heroes.Set.h2 and delta.Maps.Heroes.Set.h1 == nil)
	assert(delta.Set == nil)
	assert(Delta.DeepEqual(client, after))
end)

test("added and removed heroes and artifacts reach the client", function()
	local before, after = profile(), profile()
	after.Heroes.h2 = nil
	after.Heroes.h3 = { UUID = "h3", Level = 1 }
	after.Artifacts.a1 = nil
	after.Artifacts.a2 = { UUID = "a2", Stars = 2 }
	local client = roundTrip(before, after)
	assert(client.Heroes.h2 == nil and client.Heroes.h3.Level == 1)
	assert(client.Artifacts.a1 == nil and client.Artifacts.a2.Stars == 2)
	assert(Delta.DeepEqual(client, after))
end)

test("a removed top-level key is unset; a new one is set", function()
	local before, after = profile(), profile()
	after.PitMaterials = nil
	after.SquadPower = 420
	local client, delta = roundTrip(before, after)
	assert(delta and delta.Unset and delta.Unset[1] == "PitMaterials")
	assert(client.PitMaterials == nil and client.SquadPower == 420)
end)

test("a nested change resends its whole top-level value", function()
	local before, after = profile(), profile()
	after.PitMaterials.PromotionStone = 9
	local client, delta = roundTrip(before, after)
	assert(delta and delta.Set and delta.Set.PitMaterials.PromotionStone == 9)
	assert(Delta.DeepEqual(client, after))
end)

test("applying a delta twice equals applying it once", function()
	local before, after = profile(), profile()
	after.Currencies.Gems = 0
	after.Heroes.h1.Level = 5
	after.Heroes.h2 = nil
	local delta = assert(Delta.Diff(before, after))
	local client = Delta.DeepCopy(before)
	Delta.Apply(client, Delta.DeepCopy(delta))
	Delta.Apply(client, Delta.DeepCopy(delta))
	assert(Delta.DeepEqual(client, after))
end)

test("the server snapshot follows the client across several syncs", function()
	local live = profile()
	local sent = Delta.DeepCopy(live)
	local client = Delta.DeepCopy(live)
	local function sync()
		local delta = Delta.Diff(sent, live)
		if delta then
			Delta.Apply(sent, Delta.DeepCopy(delta))
			Delta.Apply(client, Delta.DeepCopy(delta))
		end
		return delta
	end
	live.Currencies.Gold = 250
	assert(sync())
	assert(sync() == nil, "nothing new since the last send")
	live.Heroes.h1.CurrentStamina = 10
	live.Artifacts.a9 = { UUID = "a9", Stars = 1 }
	assert(sync())
	live.Heroes.h1 = nil
	assert(sync())
	assert(Delta.DeepEqual(client, live) and Delta.DeepEqual(sent, live))
end)

test("the snapshot does not alias the live profile", function()
	local live = profile()
	local sent = Delta.DeepCopy(live)
	live.Heroes.h1.Level = 99
	assert(sent.Heroes.h1.Level == 4)
end)

test("Apply reports the top-level keys it touched", function()
	local before, after = profile(), profile()
	after.Currencies.Gold = 1
	after.Heroes.h1.Level = 7
	after.PitMaterials = nil
	local touched = Delta.Apply(Delta.DeepCopy(before), assert(Delta.Diff(before, after)))
	assert(touched.Currencies and touched.Heroes and touched.PitMaterials)
	assert(not touched.Artifacts and not touched.HighestClearedFloor)
end)

test("Affects: a refresh runs unless every touched key is ignored", function()
	local ignored = { Currencies = true, LastActiveTimestamp = true }
	assert(Delta.Affects(nil, ignored), "a full profile refreshes everything")
	assert(not Delta.Affects({ Currencies = true }, ignored))
	assert(not Delta.Affects({ Currencies = true, LastActiveTimestamp = true }, ignored))
	assert(Delta.Affects({ Currencies = true, Heroes = true }, ignored))
	assert(Delta.Affects({ SomeNewField = true }, ignored), "unknown keys count as relevant")
	assert(not Delta.Affects({}, ignored))
end)

test("IsDelta tells a delta from a full profile", function()
	assert(Delta.IsDelta({ _Delta = true }))
	assert(not Delta.IsDelta(profile()))
	assert(not Delta.IsDelta(nil))
end)

print(`profile-delta: {passed} passed`)
