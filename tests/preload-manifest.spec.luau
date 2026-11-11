--!strict
-- tests/preload-manifest.spec.luau
-- PreloadManifest.ScanIds / ScanAssets: collect the asset IDs the join loading screen preloads from
-- config tables, and tell images from meshes and sounds.

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

test("ScanAssets takes each ID's kind from the keys above it", function()
	local assets = PreloadManifest.ScanAssets({
		Logo = "rbxassetid://1",
		Sounds = table.freeze({ Click = "rbxassetid://2", Hover = "" }),
		CLICK_SOUND_ID = "rbxassetid://2",
		Parts = { { MeshId = "rbxassetid://3", TextureId = "rbxassetid://4", Glow = { { MeshId = "rbxassetid://5" } } } },
		ParticleTexture = "rbxassetid://6",
	})
	local kinds: { [string]: string } = {}
	for _, asset in assets do
		assert(kinds[asset.Id] == nil, asset.Id .. " collected once")
		kinds[asset.Id] = asset.Kind
	end
	local expected = { "Image", "Sound", "Mesh", "Image", "Mesh", "Image" }
	for index, kind in expected do
		local id = "rbxassetid://" .. index
		assert(kinds[id] == kind, `{id} is a {kind}, got {kinds[id]}`)
	end
	assert(#assets == #expected, "exactly six assets, got " .. #assets)
end)

test("hero hair meshes are never classed as images", function()
	local kinds: { [string]: string } = {}
	for _, asset in PreloadManifest.ScanAssets(HeroCostumes) do
		kinds[asset.Id] = asset.Kind
	end
	assert(kinds[HeroCostumes.DEFAULT_FACE] == "Image", "default face is an image")
	for meshId in HeroCostumes.MESHES do
		assert(kinds[meshId] == "Mesh", meshId .. " is a mesh")
	end
end)

print(string.format("preload-manifest: %d tests passed", passed))
