--!strict
-- StarterPlayerScripts/UI/Settings/SettingsConfig.luau
-- Re-exports SettingsConfig from Shared/Config for backwards compatibility.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local SettingsConfig = require(Shared:WaitForChild("Config"):WaitForChild("SettingsConfig"))

export type ThemeName = SettingsConfig.ThemeName
export type FontName = SettingsConfig.FontName
export type QualityName = SettingsConfig.QualityName
export type TabName = SettingsConfig.TabName
export type SettingsState = SettingsConfig.SettingsState

return SettingsConfig