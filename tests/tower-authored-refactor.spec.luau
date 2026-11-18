-- Snapshot parity spec for the §4.1 data-driven TowerLayout refactor:
-- proves Verdant authored floors 1-5 and generic floors 6-50 emit identical geometry, links,
-- lanes, camps, and patrol routes after moving special cases into TowerLayout.AUTHORED.
local Layout = require(nodes["ReplicatedStorage.Shared.Config.TowerLayout"])
local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end

local CORE_KEYS = {
	"Width", "Depth", "Height", "Bottom", "ReturnLinks",
	"Platforms", "Links", "Camps", "Sanctuary", "EliteCount",
	"Index", "Varied", "Authored", "Name", "PathStyle",
}

local function sig(tbl: any): string
	if type(tbl) ~= "table" then
		return tostring(tbl)
	end
	local ks = {}
	for k in tbl do
		table.insert(ks, k)
	end
	table.sort(ks, function(a, b)
		return tostring(a) < tostring(b)
	end)
	local parts = {}
	for _, k in ks do
		table.insert(parts, tostring(k) .. "=" .. sig(tbl[k]))
	end
	return "{" .. table.concat(parts, ",") .. "}"
end

local function coreRoom(room: any): { [string]: any }
	local out = {}
	for _, k in CORE_KEYS do
		out[k] = room[k]
	end
	return out
end

local function fnv(s: string): string
	local h = 2166136261
	for i = 1, #s do
		h = bit32.bxor(h, string.byte(s, i))
		h = (h * 16777619) % 4294967296
	end
	return string.format("%08x", h)
end

local EXPECTED = {
	[1] = { "ce927088", "a8ca6d50", "4294f520" },
	[2] = { "bcc9fecf", "132f32e0", "cb0e1198" },
	[3] = { "fac63290", "95a91ba0", "8b879cc8" },
	[4] = { "d227f520", "ab8a9630", "7f47fb98" },
	[5] = { "d57eeea0", "73e9c578", "42447b30" },
	[6] = { "2cd11d60", "55becba0", "4294f520" },
	[7] = { "26c02780", "879f5748", "6669c338" },
	[8] = { "b8659fa8", "248f8550", "bbcfd110" },
	[9] = { "fe262790", "757d6fd0", "1bab9308" },
	[10] = { "8a64d817", "cdd30e58", "1a2af540" },
	[11] = { "7dddf970", "4f51bbc8", "4294f520" },
	[12] = { "bada21a0", "2ea07f04", "6669c338" },
	[13] = { "6aeb4b88", "013b42c8", "22aacd2f" },
	[14] = { "74163f88", "495b6e58", "d99f29e8" },
	[15] = { "d9dca9f0", "6149b208", "43dbcc38" },
	[16] = { "0a72a0e8", "b98d8208", "4294f520" },
	[17] = { "1dd08ff0", "4cc340df", "6669c338" },
	[18] = { "d1897078", "788cf95f", "d4dffa58" },
	[19] = { "58982f68", "2947d6c0", "284069e0" },
	[20] = { "6dabec08", "a60c8b60", "bace04a0" },
	[21] = { "1c95e548", "61e1ad60", "4294f520" },
	[22] = { "d4aea3b8", "a95465c0", "6669c338" },
	[23] = { "36098828", "3f3b1f57", "a1fa15a8" },
	[24] = { "0ddde1d8", "2e477338", "7f4b7a58" },
	[25] = { "894d1df0", "d72e4838", "82177fdf" },
	[26] = { "51bbfe77", "ced109c0", "4294f520" },
	[27] = { "25ed26e8", "61b1ac68", "6669c338" },
	[28] = { "251bdc38", "29c20f68", "9e639718" },
	[29] = { "41a0d008", "b70046e0", "9184db9c" },
	[30] = { "595db7f8", "46d268b8", "e62de550" },
	[31] = { "3819d8a8", "c3b367f0", "4294f520" },
	[32] = { "b0a28600", "3e351088", "6669c338" },
	[33] = { "cf349f68", "35a2f708", "24edc108" },
	[34] = { "053e1558", "07c90def", "3e3fdea0" },
	[35] = { "5ce8eb38", "ec549648", "ef39e2c8" },
	[36] = { "aa420e28", "94f0f2b8", "4294f520" },
	[37] = { "f8b4935f", "adebc4a8", "6669c338" },
	[38] = { "ffe28ad8", "d9bf7824", "dcb32058" },
	[39] = { "72630f04", "57edd6e0", "a590d490" },
	[40] = { "4d6c7238", "3e543520", "22d3fd88" },
	[41] = { "6155e658", "6a0d8fd8", "4294f520" },
	[42] = { "76aa9390", "412c0c70", "6669c338" },
	[43] = { "b07e30ff", "808fca08", "d7738d48" },
	[44] = { "a53dc918", "74465b40", "d07e87a0" },
	[45] = { "909345b0", "89b432c0", "3a3e5fc6" },
	[46] = { "b68dbb5f", "140af270", "4294f520" },
	[47] = { "1daa39f9", "321d4568", "6669c338" },
	[48] = { "db0094e8", "98e68218", "9e598410" },
	[49] = { "35443510", "83097190", "a1de0290" },
	[50] = { "35fbe038", "5b33c4f8", "d73126d0" },
}

test("data-driven refactor preserves exact room, lane and patrol snapshots for floors 1-5 and unauthored 6-50", function()
	for floorId, exp in EXPECTED do
		if floorId == 11 or floorId == 12 or floorId == 13 then
			continue
		end
		local idx = (floorId - 1) % 5 + 1
		local room = Layout.ForFloor(floorId)
		local lanes = Layout.Lanes(idx, floorId)
		local pat = Layout.PatrolRoutes(idx, floorId)
		local rHash = fnv(sig(coreRoom(room)))
		local lHash = fnv(sig(lanes))
		local pHash = fnv(sig(pat))
		assert(rHash == exp[1], string.format("floor %d room snapshot mismatch: got %s expected %s", floorId, rHash, exp[1]))
		assert(lHash == exp[2], string.format("floor %d lanes snapshot mismatch: got %s expected %s", floorId, lHash, exp[2]))
		assert(pHash == exp[3], string.format("floor %d patrol snapshot mismatch: got %s expected %s", floorId, pHash, exp[3]))
	end
end)

test("Verdant 1-5 expose DirectTerrain, Decks, Suspended, Masonry, Liquid, TerrainFeatures and Patrols on room data", function()
	for f = 1, 5 do
		local room = Layout.ForFloor(f)
		assert(room.DirectTerrain == true, "Verdant DirectTerrain missing on floor " .. f)
	end
	assert(Layout.ForFloor(2).Decks.Crossing and Layout.ForFloor(2).Liquid.LevelOffset == 2.6)
	assert(Layout.ForFloor(3).Masonry == "ORGANIC" and Layout.ForFloor(3).Suspended.Platforms.Crossing)
	assert(Layout.ForFloor(4).Masonry == "FORTRESS" and Layout.ForFloor(4).Patrols.WALL_WALK ~= nil)
	assert(Layout.ForFloor(5).Masonry == "FORTRESS" and Layout.ForFloor(5).SunMedallions == true)
	assert(Layout.ForFloor(11).Authored == "ashen:1" and Layout.ForFloor(11).DirectTerrain == true)
	assert(Layout.ForFloor(12).Authored == "ashen:2" and Layout.ForFloor(12).Masonry == "VARRASH_DECK" and Layout.ForFloor(12).Decks.Crossing)
	assert(Layout.ForFloor(13).Authored == "ashen:3" and Layout.ForFloor(13).Masonry == "VARRASH_GLASS" and Layout.ForFloor(13).Suspended.Platforms.Crossing and Layout.ForFloor(13).Patrols.ARCH_CROSSING ~= nil)
	assert(Layout.ForFloor(6).DirectTerrain == false)
end)

print(string.format("tower-authored-refactor: %d passed", passed))
