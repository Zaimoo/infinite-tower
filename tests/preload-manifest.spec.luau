--!strict
-- tests/preload-manifest.spec.luau
-- PreloadManifest.ScanIds: collects the asset IDs the join loading screen preloads from config tables.

local PreloadManifest = require(nodes["ReplicatedStorage.Shared.Util.PreloadManifest"])
local HeroCostumes = require(nodes["ReplicatedStorage.Assets.HeroRig.HeroCostumes"])

local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end

local function has(list: { string }, id: string): boolean
	return table.find(list, id) ~= nil
end

test("nested and frozen tables are walked, keys included", function()
	local ids = PreloadManifest.ScanIds({
		Logo = "rbxassetid://1",
		Banners = table.freeze({ a = "rbxassetid://2", deep = { "rbxassetid://3" } }),
		["rbxassetid://4"] = "",
	})
	for _, id in { "rbxassetid://1", "rbxassetid://2", "rbxassetid://3", "rbxassetid://4" } do
		assert(has(ids, id), id .. " collected")
	end
	assert(#ids == 4, "exactly four IDs, got " .. #ids)
end)

test("empty slots, placeholders and other strings are skipped", function()
	local ids = PreloadManifest.ScanIds({ "", "rbxassetid://REPLACE_ME", "rbxasset://textures/x.png", "hello", 12, true })
	assert(#ids == 0, "nothing collected, got " .. #ids)
end)

test("duplicates are collected once, across calls sharing out/seen", function()
	local out, seen = {}, {}
	PreloadManifest.ScanIds({ "rbxassetid://7", "rbxassetid://7" }, out, seen)
	PreloadManifest.ScanIds({ x = "rbxassetid://7", y = "rbxassetid://8" }, out, seen)
	assert(#out == 2, "two unique IDs, got " .. #out)
end)

test("cyclic tables terminate", function()
	local a: any = { id = "rbxassetid://9" }
	a.self = a
	local ids = PreloadManifest.ScanIds(a)
	assert(#ids == 1, "one ID from a cyclic table")
end)

test("hero costumes yield the default face and the hair meshes", function()
	local ids = PreloadManifest.ScanIds(HeroCostumes)
	assert(has(ids, HeroCostumes.DEFAULT_FACE), "default face collected")
	for meshId in HeroCostumes.MESHES do
		assert(has(ids, meshId), meshId .. " hair mesh collected")
	end
end)

print(string.format("preload-manifest: %d tests passed", passed))
