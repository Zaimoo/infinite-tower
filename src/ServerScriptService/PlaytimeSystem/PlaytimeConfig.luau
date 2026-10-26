local RunService = game:GetService("RunService")

local Config = {}

Config.IS_STUDIO = RunService:IsStudio()
Config.DS_SCOPE  = Config.IS_STUDIO and "STUDIO" or "PROD"

Config.DS_ORDERED_NAME = "PlaytimeTotals_V1"
Config.DS_MAIN_NAME    = "PlaytimeData_V1"

Config.SAVE_INTERVAL = 60 -- auto-save per player ke DataStore
Config.BOARD_REFRESH = 30
Config.TICK_INTERVAL = 1  -- update angka playtime realtime + countdown UpdateLabel

Config.MAX_BOARD_ROWS  = 100 -- jumlah card maksimal yang ditampilin di ScreenPlaytime
Config.MAX_STAND_RANKS = 3

Config.Paths = {
	ScreenPlaytimePart = { "AvxsedPlaytimeWS", "ScreenPlaytime" },
	RigstandFolder      = { "AvxsedPlaytimeWS", "Rigstand" },
}

Config.Admin = {
	AdminUserIds = {
		[8789609975] = true,
		[118832016] = true, -- AwesomePunkbro (Owner)
	},
	RefreshCooldown = 5,
}

Config.Topbar = {
	Image = "rbxassetid://96714408085433",
	Label = "",
}

return Config
