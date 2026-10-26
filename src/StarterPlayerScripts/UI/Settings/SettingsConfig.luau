--!strict
-- StarterPlayerScripts/UI/Settings/SettingsConfig.luau
-- Default values, themes, and configuration for React Settings UI

export type ThemeName = "Cyan" | "Purple" | "Green" | "Orange" | "Red"
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

SettingsConfig.DEFAULTS = {
	Sound = 0.65,
	Music = 0.55,
	Ambience = 0.60,
	MuteMusic = false,
	MuteSFX = false,
	MuteAmbience = false,

	Quality = "High" :: QualityName,
	Brightness = 0.20,
	FOV = 70,
	GlobalShadows = true,
	Bloom = true,
	ColorFX = true,

	CompactMode = false,
	ShowNotifications = true,
	DamageNumbers = true,
	ReduceMotion = false,
	HighContrast = false,
	LivePreview = true,
	Scale = 1.0,

	Theme = "Cyan" :: ThemeName,
	Font = "Gotham" :: FontName,
}

SettingsConfig.THEMES = {
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
}

SettingsConfig.FONTS = {
	Gotham = Enum.Font.Gotham,
	GothamBold = Enum.Font.GothamBold,
	GothamBlack = Enum.Font.GothamBlack,
	Arcade = Enum.Font.Arcade,
	Fredoka = Enum.Font.FredokaOne,
	SciFi = Enum.Font.SciFi,
}

SettingsConfig.CLICK_SOUND_ID = "rbxassetid://139403951941162"
SettingsConfig.GEAR_ICON_ID = "rbxassetid://18801194936"

return SettingsConfig
