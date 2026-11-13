--!strict
-- ReplicatedStorage/Shared/Config/SettingsConfig.luau
-- Default values, themes, and configuration for Settings UI & Persistence

export type ThemeName = "Gold" | "Cyan" | "Purple" | "Green" | "Orange" | "Red"
export type FontName = "Gotham" | "Arcade" | "Fredoka" | "SciFi"
export type QualityName = "Low" | "Medium" | "High"
export type TabName = "Overview" | "Audio" | "Graphics"

export type SettingsState = {
	-- Audio
	Sound: number,
	Music: number,
	Ambience: number,
	MuteMusic: boolean,
	MuteSFX: boolean,
	MuteAmbience: boolean,

	-- Graphics
	Quality: QualityName,
	Brightness: number,
	FOV: number,
	GlobalShadows: boolean,
	Bloom: boolean,
	ColorFX: boolean,

	-- Interface
	CompactMode: boolean,
	ShowNotifications: boolean,
	DamageNumbers: boolean,
	ReduceMotion: boolean,
	HighContrast: boolean,
	LivePreview: boolean,
	Scale: number,

	-- Style
	Theme: ThemeName,
	Font: FontName,
}

local SettingsConfig = {}

SettingsConfig.DEFAULTS = table.freeze({
	Sound = 0.80,
	Music = 0.55,
	Ambience = 0.60,
	MuteMusic = false,
	MuteSFX = false,
	MuteAmbience = false,

	Quality = "High" :: QualityName,
	Brightness = 0.20,
	FOV = 70,
	GlobalShadows = false, -- sun shadows cost ~20% of the hub frame; players can turn them on in Settings
	Bloom = true,
	ColorFX = true,

	CompactMode = false,
	ShowNotifications = true,
	DamageNumbers = true,
	ReduceMotion = false,
	HighContrast = false,
	LivePreview = true,
	Scale = 1.0,

	Theme = "Gold" :: ThemeName, -- Gilded Grimoire antique gold
	Font = "Gotham" :: FontName,
})

SettingsConfig.THEMES = table.freeze({
	Gold = {
		Accent = Color3.fromRGB(255, 214, 110),
		Soft = Color3.fromRGB(96, 64, 24),
		Glow = Color3.fromRGB(240, 186, 82),
		Border = Color3.fromRGB(240, 196, 110),
	},
	Cyan = {
		Accent = Color3.fromRGB(84, 215, 255),
		Soft = Color3.fromRGB(24, 52, 84),
		Glow = Color3.fromRGB(39, 125, 186),
		Border = Color3.fromRGB(48, 88, 136),
	},
	Purple = {
		Accent = Color3.fromRGB(178, 133, 255),
		Soft = Color3.fromRGB(56, 39, 99),
		Glow = Color3.fromRGB(96, 70, 170),
		Border = Color3.fromRGB(86, 60, 150),
	},
	Green = {
		Accent = Color3.fromRGB(103, 244, 169),
		Soft = Color3.fromRGB(29, 88, 61),
		Glow = Color3.fromRGB(49, 150, 105),
		Border = Color3.fromRGB(42, 120, 84),
	},
	Orange = {
		Accent = Color3.fromRGB(255, 177, 90),
		Soft = Color3.fromRGB(100, 57, 22),
		Glow = Color3.fromRGB(163, 94, 34),
		Border = Color3.fromRGB(140, 78, 30),
	},
	Red = {
		Accent = Color3.fromRGB(255, 107, 130),
		Soft = Color3.fromRGB(97, 33, 51),
		Glow = Color3.fromRGB(160, 62, 88),
		Border = Color3.fromRGB(145, 45, 70),
	},
})

local hasEnum = pcall(function() return Enum.Font end)
local EnumFont = if hasEnum then Enum.Font else nil

SettingsConfig.FONTS = table.freeze({
	Gotham = if EnumFont then EnumFont.Gotham else "Gotham" :: any,
	GothamBold = if EnumFont then EnumFont.GothamBold else "GothamBold" :: any,
	GothamBlack = if EnumFont then EnumFont.GothamBlack else "GothamBlack" :: any,
	Arcade = if EnumFont then EnumFont.Arcade else "Arcade" :: any,
	Fredoka = if EnumFont then EnumFont.FredokaOne else "FredokaOne" :: any,
	SciFi = if EnumFont then EnumFont.SciFi else "SciFi" :: any,
})

SettingsConfig.CLICK_SOUND_ID = "rbxassetid://139403951941162"
SettingsConfig.GEAR_ICON_ID = "rbxassetid://116900178322793"

-- Pure validator: sanitizes and ensures all settings fields conform to schema
function SettingsConfig.Sanitize(raw: any): SettingsState
	local out = table.clone(SettingsConfig.DEFAULTS)
	if type(raw) ~= "table" then
		return out
	end

	if type(raw.Sound) == "number" then out.Sound = math.clamp(raw.Sound, 0, 1) end
	if type(raw.Music) == "number" then out.Music = math.clamp(raw.Music, 0, 1) end
	if type(raw.Ambience) == "number" then out.Ambience = math.clamp(raw.Ambience, 0, 1) end

	if type(raw.MuteSFX) == "boolean" then out.MuteSFX = raw.MuteSFX end
	if type(raw.MuteMusic) == "boolean" then out.MuteMusic = raw.MuteMusic end
	if type(raw.MuteAmbience) == "boolean" then out.MuteAmbience = raw.MuteAmbience end

	if raw.Quality == "Low" or raw.Quality == "Medium" or raw.Quality == "High" then
		out.Quality = raw.Quality
	end

	if type(raw.Brightness) == "number" then out.Brightness = math.clamp(raw.Brightness, 0, 1) end
	if type(raw.FOV) == "number" then out.FOV = math.clamp(raw.FOV, 50, 100) end

	if type(raw.GlobalShadows) == "boolean" then out.GlobalShadows = raw.GlobalShadows end
	if type(raw.Bloom) == "boolean" then out.Bloom = raw.Bloom end
	if type(raw.ColorFX) == "boolean" then out.ColorFX = raw.ColorFX end

	if type(raw.CompactMode) == "boolean" then out.CompactMode = raw.CompactMode end
	if type(raw.ShowNotifications) == "boolean" then out.ShowNotifications = raw.ShowNotifications end
	if type(raw.DamageNumbers) == "boolean" then out.DamageNumbers = raw.DamageNumbers end
	if type(raw.ReduceMotion) == "boolean" then out.ReduceMotion = raw.ReduceMotion end
	if type(raw.HighContrast) == "boolean" then out.HighContrast = raw.HighContrast end
	if type(raw.LivePreview) == "boolean" then out.LivePreview = raw.LivePreview end

	if type(raw.Scale) == "number" then out.Scale = math.clamp(raw.Scale, 0.75, 1.25) end

	if raw.Theme and SettingsConfig.THEMES[raw.Theme] then
		out.Theme = raw.Theme
	end
	if raw.Font and SettingsConfig.FONTS[raw.Font] then
		out.Font = raw.Font
	end

	return out
end

return SettingsConfig