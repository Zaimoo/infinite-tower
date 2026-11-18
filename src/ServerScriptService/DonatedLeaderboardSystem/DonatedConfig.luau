--!strict
local RunService = game:GetService("RunService")

local Config = {}

Config.IS_STUDIO = RunService:IsStudio()
Config.DS_SCOPE  = "PROD"

Config.DS_ORDERED_NAME = "RobuxDonatedTotals_V1"
Config.DS_MAIN_NAME    = "RobuxDonatedData_V1"

Config.SAVE_INTERVAL = 60
Config.BOARD_REFRESH = 30
Config.TICK_INTERVAL = 1

Config.MAX_BOARD_ROWS = 100

Config.Paths = {
	ScreenDonatedPart = { "AvxsedDonatedWS", "ScreenDonated" },
}

Config.Admin = {
	AdminUserIds = {
		[8789609975] = true,
		[118832016] = true,
	},
	RefreshCooldown = 5,
}

return Config
