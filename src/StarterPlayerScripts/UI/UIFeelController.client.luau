--!strict
-- StarterPlayerScripts/UI/UIFeelController.client.luau
-- Gives every button in PlayerGui the shared hover/press spring, click sound and haptic (UIFeel).

local Players = game:GetService("Players")

local UIFeel = require(script.Parent:WaitForChild("UIFeel"))

UIFeel.WatchGui(Players.LocalPlayer:WaitForChild("PlayerGui"))

local TextReadability = require(script.Parent:WaitForChild("TextReadability"))
TextReadability.Watch(Players.LocalPlayer:WaitForChild("PlayerGui"))
