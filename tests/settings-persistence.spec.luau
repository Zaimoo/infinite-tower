--!strict
-- tests/settings-persistence.spec.luau
-- Unit tests for SettingsConfig schema, sanitization, and ProfileMigrations integration.

local SettingsConfig = require(nodes["ReplicatedStorage.Shared.Config.SettingsConfig"])
local ProfileMigrations = require(nodes["ServerScriptService.Core.ProfileMigrations"])

local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end

test("defaults: all default settings exist and are valid types", function()
	local d = SettingsConfig.DEFAULTS
	assert(typeof(d.Sound) == "number" and d.Sound >= 0 and d.Sound <= 1, "valid sound default")
	assert(typeof(d.Music) == "number" and d.Music >= 0 and d.Music <= 1, "valid music default")
	assert(typeof(d.Ambience) == "number" and d.Ambience >= 0 and d.Ambience <= 1, "valid ambience default")
	assert(typeof(d.MuteSFX) == "boolean", "valid mute SFX")
	assert(typeof(d.MuteMusic) == "boolean", "valid mute Music")
	assert(typeof(d.MuteAmbience) == "boolean", "valid mute Ambience")
	assert(d.Quality == "High", "high quality default")
	assert(d.FOV == 70, "70 fov default")
end)

test("sanitize: clamps out-of-range volume and graphics numbers", function()
	local raw = {
		Sound = 5.0,
		Music = -0.5,
		Ambience = 0.42,
		FOV = 150,
		Brightness = -2.0,
		Scale = 99,
	}
	local clean = SettingsConfig.Sanitize(raw)
	assert(clean.Sound == 1.0, "sound clamped to 1.0")
	assert(clean.Music == 0.0, "music clamped to 0.0")
	assert(clean.Ambience == 0.42, "ambience preserved")
	assert(clean.FOV == 100, "fov clamped to 100")
	assert(clean.Brightness == 0.0, "brightness clamped to 0.0")
	assert(clean.Scale == 1.25, "scale clamped to 1.25")
end)

test("sanitize: preserves quiet mode preset", function()
	local quietMode = {
		Sound = 0.0,
		Music = 0.0,
		Ambience = 0.0,
		MuteSFX = true,
		MuteMusic = true,
		MuteAmbience = true,
	}
	local clean = SettingsConfig.Sanitize(quietMode)
	assert(clean.Sound == 0.0, "sound is 0")
	assert(clean.Music == 0.0, "music is 0")
	assert(clean.Ambience == 0.0, "ambience is 0")
	assert(clean.MuteSFX == true, "mute sfx true")
	assert(clean.MuteMusic == true, "mute music true")
	assert(clean.MuteAmbience == true, "mute ambience true")
end)

test("sanitize: safely rejects invalid enums and malformed types", function()
	local malicious = {
		Theme = "NonExistentTheme",
		Font = "ComicSans",
		Quality = "UltraMega4K",
		GlobalShadows = "yes please",
	}
	local clean = SettingsConfig.Sanitize(malicious)
	assert(clean.Theme == SettingsConfig.DEFAULTS.Theme, "reverts invalid theme")
	assert(clean.Font == SettingsConfig.DEFAULTS.Font, "reverts invalid font")
	assert(clean.Quality == SettingsConfig.DEFAULTS.Quality, "reverts invalid quality")
	assert(typeof(clean.GlobalShadows) == "boolean", "shadows remains boolean")
end)

test("profile migrations: ensures profile.Settings is populated and sanitized", function()
	local profile = {
		SchemaVersion = 1,
		Heroes = {},
		Facilities = {},
	}
	ProfileMigrations.Run(profile)
	assert(type(profile.Settings) == "table", "profile.Settings created")
	assert(profile.Settings.Sound == SettingsConfig.DEFAULTS.Sound, "default sound set")
	assert(profile.Settings.Quality == "High", "default quality set")
end)

print(string.format("settings-persistence: %d tests passed", passed))
