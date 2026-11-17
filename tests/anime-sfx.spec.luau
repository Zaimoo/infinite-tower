--!strict
-- Verification tests for the Free Anime SFX Pack manifest, SoundCatalog bindings,
-- biome music/ambience mappings, and PreloadManifest compatibility.

local AnimeSfxManifest = require(nodes["ReplicatedStorage.Shared.Config.AnimeSfxManifest"])
local SoundCatalog = require(nodes["ReplicatedStorage.Shared.Config.SoundCatalog"])
local PreloadManifest = require(nodes["ReplicatedStorage.Shared.Util.PreloadManifest"])

local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end

test("AnimeSfxManifest contains all 126 WAV entries with valid metadata", function()
	local keys = AnimeSfxManifest.AllKeys()
	assert(AnimeSfxManifest.Count == 126, "expected AnimeSfxManifest.Count == 126, got " .. tostring(AnimeSfxManifest.Count))
	assert(#keys == 126, "expected 126 AllKeys entries, got " .. tostring(#keys))

	local count = 0
	for key, entry in pairs(AnimeSfxManifest.Entries) do
		count += 1
		assert(entry.Key == key, "mismatched Key for " .. key)
		assert(type(entry.Category) == "string" and entry.Category ~= "", "missing Category for " .. key)
		assert(type(entry.RepoPath) == "string" and string.sub(entry.RepoPath, 1, 11) == "assets/sfx/", "bad RepoPath for " .. key)
		assert(type(entry.StudioId) == "string" and string.sub(entry.StudioId, 1, 15) == "rbxasset://sfx/", "bad StudioId for " .. key)
		assert(type(entry.Bytes) == "number" and entry.Bytes > 44, "invalid WAV byte size for " .. key)
		assert(type(entry.DurationSeconds) == "number" and entry.DurationSeconds > 0, "invalid DurationSeconds for " .. key)
		assert(type(entry.SampleRate) == "number" and entry.SampleRate > 0, "invalid SampleRate for " .. key)
		assert(type(entry.Channels) == "number" and entry.Channels >= 1, "invalid Channels for " .. key)
		assert(AnimeSfxManifest.Get(key) == entry, "Get mismatch for " .. key)
		assert(AnimeSfxManifest.GetStudioId(key) == entry.StudioId, "GetStudioId mismatch for " .. key)
		if entry.AssetId == "" then
			assert(AnimeSfxManifest.GetPlayableId(key, true) == entry.StudioId, "GetPlayableId(true) mismatch for " .. key)
			assert(AnimeSfxManifest.GetPlayableId(key, false) == nil, "expected nil GetPlayableId(false) when AssetId is empty for " .. key)
		else
			assert(string.match(entry.AssetId, "^rbxassetid://%d+$") ~= nil, "bad AssetId for " .. key)
			assert(AnimeSfxManifest.GetPlayableId(key, true) == entry.AssetId, "uploaded AssetId should win in Studio for " .. key)
			assert(AnimeSfxManifest.GetPlayableId(key, false) == entry.AssetId, "uploaded AssetId should play live for " .. key)
		end
	end
	assert(count == 126, "expected 126 Entries pairs, got " .. tostring(count))
end)

test("SoundCatalog entries have valid categories, volumes, manifest links, and Studio IDs", function()
	local validCategories = {
		SFX = true,
		Music = true,
		Ambience = true,
	}

	local entryCount = 0
	for name, def in pairs(SoundCatalog.Entries) do
		entryCount += 1
		assert(SoundCatalog.Get(name) == def, "Get mismatch for " .. name)
		assert(validCategories[def.Category], "invalid Category for " .. name .. ": " .. tostring(def.Category))
		assert(type(def.Volume) == "number" and def.Volume == def.Volume and def.Volume >= 0, "invalid Volume for " .. name)

		if def.MaxDuration ~= nil then
			assert(type(def.MaxDuration) == "number" and def.MaxDuration > 0, "invalid MaxDuration for " .. name)
		end
		if def.FadeOutSeconds ~= nil then
			assert(type(def.FadeOutSeconds) == "number" and def.FadeOutSeconds >= 0, "invalid FadeOutSeconds for " .. name)
		end

		if def.SourceFile ~= nil and def.SourceFile ~= "" then
			local manifestEntry = AnimeSfxManifest.Get(def.SourceFile)
			assert(manifestEntry ~= nil, "missing SourceFile in AnimeSfxManifest for " .. name .. ": " .. tostring(def.SourceFile))
			if def.TimeOffset ~= nil then
				assert(
					type(def.TimeOffset) == "number" and def.TimeOffset >= 0 and def.TimeOffset < manifestEntry.DurationSeconds,
					"TimeOffset out of bounds for " .. name
				)
			end
		end

		if def.Variants ~= nil then
			assert(#def.Variants > 0, "empty Variants list for " .. name)
			for _, variantKey in ipairs(def.Variants) do
				local variantEntry = AnimeSfxManifest.Get(variantKey)
				assert(variantEntry ~= nil, "missing Variant in AnimeSfxManifest for " .. name .. ": " .. tostring(variantKey))
				if def.TimeOffset ~= nil then
					assert(
						type(def.TimeOffset) == "number" and def.TimeOffset >= 0 and def.TimeOffset < variantEntry.DurationSeconds,
						"TimeOffset out of variant bounds for " .. name
					)
				end
			end
		end

		local studioId = SoundCatalog.ResolveId(name, true)
		if name == "HubTheme" then
			assert(def.Volume == 0, "HubTheme is expected to stay muted (Volume == 0)")
		else
			assert(type(studioId) == "string" and studioId ~= "", "ResolveId(true) failed to produce a playable ID for " .. name)
		end
	end
	assert(entryCount > 80, "expected expanded SoundCatalog (>80 entries), got " .. tostring(entryCount))
end)

test("Biome music and ambience keys resolve cleanly for biomes 1..10", function()
	for biome = 1, 10 do
		local musicKey = SoundCatalog.GetBiomeMusicKey(biome)
		local musicDef = SoundCatalog.Get(musicKey)
		assert(musicDef ~= nil, "missing biome music def for biome " .. tostring(biome) .. ": " .. tostring(musicKey))
		assert(musicDef.Category == "Music", "expected Music category for biome music " .. musicKey)
		local musicId = SoundCatalog.ResolveId(musicKey, true)
		assert(type(musicId) == "string" and musicId ~= "", "empty music ID for " .. musicKey)

		local ambienceKey = SoundCatalog.GetBiomeAmbienceKey(biome)
		local ambienceDef = SoundCatalog.Get(ambienceKey)
		assert(ambienceDef ~= nil, "missing biome ambience def for biome " .. tostring(biome) .. ": " .. tostring(ambienceKey))
		assert(ambienceDef.Category == "Ambience", "expected Ambience category for biome ambience " .. ambienceKey)
		local ambienceId = SoundCatalog.ResolveId(ambienceKey, true)
		assert(type(ambienceId) == "string" and ambienceId ~= "", "empty ambience ID for " .. ambienceKey)
	end
end)

test("PreloadManifest skips rbxasset:// Studio paths and preserves rbxassetid:// sound fallbacks", function()
	local scanned = PreloadManifest.ScanAssets({
		SoundCatalog = SoundCatalog.Entries,
		AnimeSfxManifest = AnimeSfxManifest.Entries,
	})
	assert(#scanned > 0, "expected fallback rbxassetid sound IDs in SoundCatalog")
	for _, asset in ipairs(scanned) do
		assert(string.match(asset.Id, "^rbxassetid://%d+$") ~= nil, "unexpected asset ID in PreloadManifest: " .. asset.Id)
		assert(asset.Kind == "Sound", "expected Sound asset kind for " .. asset.Id .. ", got " .. asset.Kind)
	end
end)

print(string.format("anime-sfx: %d passed", passed))
