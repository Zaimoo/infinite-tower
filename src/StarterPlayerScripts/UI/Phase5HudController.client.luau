--!strict
-- StarterPlayerScripts/UI/Phase5HudController.client.luau
-- Mounts the Phase 5 React HUD (rails, Next Goal card, Squad Status Card, Squad Power badge, Hero
-- Index) and binds the gamepad whistle buttons. Keyboard Q/E live in MasterController so they can
-- yield to ProximityPrompts; both routes go through Hud/Whistles.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local ReactRoblox = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("ReactRoblox"))

local Hud = script.Parent:WaitForChild("Hud")
local HudApp = require(Hud:WaitForChild("HudApp"))
local Whistles = require(Hud:WaitForChild("Whistles"))

local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Two layers (Phase 5 §2): the HUD zones sit BEHIND building screens (the legacy HUD gui is
-- raised to DISPLAY_BUILDINGS), while the React screens (facility panel, Hero Index, Pit tabs)
-- render through a portal into an overlay ABOVE them.
local DISPLAY_HUD, DISPLAY_OVERLAY = 1, 10

local function makeLayer(name: string, displayOrder: number): (ScreenGui, Frame)
	local old = PlayerGui:FindFirstChild(name)
	if old then old:Destroy() end
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = displayOrder
	gui.Parent = PlayerGui
	local frame = Instance.new("Frame")
	frame.Name = "Root"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	return gui, frame
end

local screenGui, host = makeLayer("Phase5Hud", DISPLAY_HUD)
local overlayGui, overlay = makeLayer("Phase5Overlay", DISPLAY_OVERLAY)
-- Gilded Grimoire: any leftover Gotham text (Hero Index, panels) renders in the theme fonts.
local GildedGrimoire = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("GildedGrimoire"))
GildedGrimoire.Watch(host)
GildedGrimoire.Watch(overlay)

local root = ReactRoblox.createRoot(host)
root:render(React.createElement(HudApp, { Root = host, Overlay = overlay }))

-- Gamepad: L1 Overdrive, R1 Recall (Phase 5 §2.1). Ignored off-floor, in a duel or on cooldown.
local function whistle(kind: string)
	return function(_: string, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			local modalOpen = _G.IsAnyMasterModalOpen and _G.IsAnyMasterModalOpen()
			if not modalOpen then Whistles.Fire(kind) end
		end
		return Enum.ContextActionResult.Pass
	end
end
ContextActionService:BindAction("WhistleOverdrivePad", whistle("Overdrive"), false, Enum.KeyCode.ButtonL1)
ContextActionService:BindAction("WhistleRecallPad", whistle("Recall"), false, Enum.KeyCode.ButtonR1)

script.Destroying:Connect(function()
	root:unmount()
	screenGui:Destroy()
	overlayGui:Destroy()
end)
