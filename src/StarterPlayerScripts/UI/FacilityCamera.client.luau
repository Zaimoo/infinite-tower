--!strict
-- StarterPlayerScripts/UI/FacilityCamera.client.luau
-- Opening a facility from its world prompt first eases the camera in on the station (the Pit's
-- altar, the Blacksmith's forge, the Summoning Altar, a support facility's counter), then opens its
-- window; the camera eases back to where it was when the last window closes. MasterController hands
-- the open step to _G.FocusFacilityCamera(prompt, open), which runs it when the pan lands (or at
-- once when the camera can't move). Only prompts on the Master's own plot pan; windows opened from
-- HUD buttons leave the camera alone. Another script taking the camera (duel, squad view) cancels
-- the focus without restoring over it.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UI = script.Parent
local WindowManager = require(UI:WaitForChild("WindowManager"))
local UIFeel = require(UI:WaitForChild("UIFeel"))

local player = Players.LocalPlayer

local DISTANCE = 14 -- studs from the station, on the side the camera came from
local HEIGHT = 6 -- above the station
local LOOK_LIFT = 1.5 -- aim slightly above the prompt point
local IN_TIME, OUT_TIME = 0.5, 0.45

-- Opening: the pan is still running and the window isn't up yet, so nothing may release it.
type Focus = { Saved: CFrame, SavedType: Enum.CameraType, Goal: CFrame, Tween: Tween?, Opening: boolean }
local focus: Focus? = nil

local function onOwnPlot(prompt: ProximityPrompt): boolean
	local current: Instance? = prompt
	while current and current.Parent do
		if current.Parent.Name == "WaitingRoomPlots" then
			return current:GetAttribute("OwnerUserId") == player.UserId
		end
		current = current.Parent
	end
	return false
end

local function stationPoint(prompt: ProximityPrompt): Vector3?
	local parent = prompt.Parent
	if parent and parent:IsA("Attachment") then return parent.WorldPosition end
	if parent and parent:IsA("BasePart") then return parent.Position end
	local part = prompt:FindFirstAncestorWhichIsA("BasePart")
	return part and part.Position
end

local function anyWindowOpen(): boolean
	if WindowManager.Top() ~= nil then return true end
	local isOpen = (_G :: any).IsAnyMasterModalOpen
	return type(isOpen) == "function" and isOpen() == true
end

local function release(immediate: boolean?)
	local f = focus
	if not f then return end
	focus = nil
	if f.Tween then f.Tween:Cancel() end
	local camera = Workspace.CurrentCamera
	-- Someone else moved the camera since we focused it: leave theirs alone.
	if not camera or camera.CameraType ~= Enum.CameraType.Scriptable then return end
	if immediate or UIFeel.ReducedMotion() then
		camera.CameraType = f.SavedType
		return
	end
	local back = TweenService:Create(camera, TweenInfo.new(OUT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = f.Saved })
	back.Completed:Once(function(state)
		if focus ~= nil then return end -- refocused meanwhile
		if state == Enum.PlaybackState.Completed and camera.CameraType == Enum.CameraType.Scriptable then
			camera.CameraType = f.SavedType
		end
	end)
	back:Play()
end

-- Pans to `point`, then calls `onArrive` (also when the camera can't move, so the window always opens).
local function focusOn(point: Vector3, onArrive: () -> ())
	local camera = Workspace.CurrentCamera
	local current = focus
	local blocked = not camera
		or ((_G :: any).IsViewingSquad and (_G :: any).IsViewingSquad())
		or (not current and camera.CameraType ~= Enum.CameraType.Custom) -- another script owns it
	if blocked or not camera then
		onArrive()
		return
	end
	local saved = if current then current.Saved else camera.CFrame
	local savedType = if current then current.SavedType else camera.CameraType
	if current and current.Tween then current.Tween:Cancel() end

	-- Approach from the side the camera is already on, so the move reads as a push-in.
	local away = saved.Position - point
	local flat = Vector3.new(away.X, 0, away.Z)
	if flat.Magnitude < 0.5 then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		flat = if root then root.Position - point else Vector3.new(0, 0, 1)
		flat = Vector3.new(flat.X, 0, flat.Z)
		if flat.Magnitude < 0.5 then flat = Vector3.new(0, 0, 1) end
	end
	local look = point + Vector3.new(0, LOOK_LIFT, 0)
	local goal = CFrame.lookAt(point + flat.Unit * DISTANCE + Vector3.new(0, HEIGHT, 0), look)

	camera.CameraType = Enum.CameraType.Scriptable
	local f: Focus = { Saved = saved, SavedType = savedType, Goal = goal, Tween = nil, Opening = true }
	focus = f
	local function arrive()
		if focus ~= f then return end -- released or refocused meanwhile
		f.Opening = false
		onArrive()
	end
	if UIFeel.ReducedMotion() then
		camera.CFrame = goal
		arrive()
	else
		local tween = TweenService:Create(camera, TweenInfo.new(IN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = goal })
		f.Tween = tween
		tween.Completed:Once(function(state)
			if state == Enum.PlaybackState.Completed then arrive() end
		end)
		tween:Play()
	end
end

-- MasterController's facility prompts: pan to the station, then `open` its window. A second press
-- while the pan is running is ignored.
(_G :: any).FocusFacilityCamera = function(prompt: ProximityPrompt, open: () -> ())
	if focus and focus.Opening then return end
	local point = if onOwnPlot(prompt) then stationPoint(prompt) else nil
	if not point then
		open()
		return
	end
	focusOn(point, open)
end

-- The last window closing (any way: X, scrim, Backspace) eases the camera back.
WindowManager.Changed:Connect(function(_, open: boolean)
	if open or not focus then return end
	task.defer(function()
		if focus and not focus.Opening and not anyWindowOpen() then release() end
	end)
end)

player.CharacterRemoving:Connect(function() release(true) end)

-- Safety net for windows that close outside WindowManager: never leave the camera parked.
task.spawn(function()
	while true do
		task.wait(0.5)
		if focus and not focus.Opening and not anyWindowOpen() then release() end
	end
end)
