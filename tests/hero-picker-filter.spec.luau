--!strict
-- tests/hero-picker-filter.spec.luau
-- Search, sort and role filter of the hero picker drawer (HeroPickerFilter).

local Filter = require(nodes["ReplicatedStorage.Shared.Util.HeroPickerFilter"])

local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end

local function entry(uuid: string, displayName: string, archetype: string, level: number, stars: number, rarity: number, power: number, flags: any?): any
	local e = { UUID = uuid, Hero = { DisplayName = displayName, Archetype = archetype, Level = level, Stars = stars, TemplateId = "hero_" .. uuid },
		Rarity = rarity, Power = power }
	for k, v in flags or {} do e[k] = v end
	return e
end

local function ids(list: { any }): string
	local out = {}
	for _, e in list do table.insert(out, e.UUID) end
	return table.concat(out, ",")
end

local entries = {
	entry("a", "Gide", "Vanguard", 5, 1, 1, 300),
	entry("b", "Catio", "Striker", 9, 1, 2, 500),
	entry("c", "Han", "Scholar", 2, 2, 6, 900, { Disabled = true }),
	entry("d", "Aeli", "Healer", 1, 1, 3, 100, { Selected = true }),
	entry("e", "Rook", "Vanguard", 7, 1, 4, 700),
}

test("recommended keeps the caller's order, selected first and disabled last", function()
	assert(ids(Filter.Apply(entries)) == "d,a,b,e,c", ids(Filter.Apply(entries)))
end)

test("sorts by level, rarity, power and name", function()
	assert(ids(Filter.Apply(entries, { Sort = "LEVEL" })) == "d,b,e,a,c")
	assert(ids(Filter.Apply(entries, { Sort = "RARITY" })) == "d,e,b,a,c")
	assert(ids(Filter.Apply(entries, { Sort = "POWER" })) == "d,e,b,a,c")
	assert(ids(Filter.Apply(entries, { Sort = "NAME" })) == "d,b,a,e,c")
end)

test("search matches name or archetype, case-insensitive and trimmed", function()
	assert(ids(Filter.Apply(entries, { Query = "  GI " })) == "a")
	assert(ids(Filter.Apply(entries, { Query = "vanguard" })) == "a,e")
	assert(ids(Filter.Apply(entries, { Query = "zzz" })) == "")
end)

test("role filter and available-only", function()
	assert(ids(Filter.Apply(entries, { Role = "Vanguard" })) == "a,e")
	assert(ids(Filter.Apply(entries, { AvailableOnly = true })) == "d,a,b,e")
end)

test("roles list and cycling", function()
	assert(table.concat(Filter.Roles(entries), ",") == "ALL,Healer,Scholar,Striker,Vanguard")
	assert(Filter.Next(Filter.Sorts, "NAME") == "RECOMMENDED")
	assert(Filter.Next(Filter.Sorts, "LEVEL") == "RARITY")
	assert(Filter.Next({ "ALL" }, "Gone") == "ALL")
end)

print(string.format("hero-picker-filter: %d passed", passed))
