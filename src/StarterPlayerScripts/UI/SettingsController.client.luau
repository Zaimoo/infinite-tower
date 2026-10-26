--!strict
-- StarterPlayerScripts/UI/SettingsController.client.luau
-- Mounts Declarative React Luau Settings UI using ReactRoblox

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local ReactRoblox = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("ReactRoblox"))

local SettingsApp = require(script.Parent:WaitForChild("Settings"):WaitForChild("SettingsApp"))

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local oldGui = PlayerGui:FindFirstChild("SettingsUi")
if oldGui then
	oldGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SettingsUi"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 100
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = PlayerGui

local root = ReactRoblox.createRoot(screenGui)
root:render(React.createElement(SettingsApp))

script.Destroying:Connect(function()
	root:unmount()
	if screenGui then
		screenGui:Destroy()
	end
end)
