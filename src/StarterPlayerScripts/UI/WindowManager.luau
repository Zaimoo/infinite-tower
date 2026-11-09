--!strict
-- StarterPlayerScripts/UI/WindowManager.luau
-- One place that knows every modal window (UI overhaul plan §4.1). It replaces the hand-written
-- lists in _G.OpenMasterModal / _G.IsAnyMasterModalOpen with a registry:
--   * one window at a time: Open(id) closes the others first;
--   * Backspace / gamepad B goes to the topmost window only: its Back() handler (close a picker, ask about
--     unsaved changes) or a plain close. Inner layers with their own higher-priority InputContext
--     (hero drawer 4000, confirm dialog 5000) sink the key before it gets here;
--   * closing animates (shrink + hide) for windows that expose a Root with a UIScale;
--   * `Changed` fires on every open/close so the HUD can fade its rails, chips and nameplates.
-- HUDController registers the windows; other code keeps using the _G shims, which route here.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UIFeel = require(script.Parent:WaitForChild("UIFeel"))

export type Adapter = {
	Open: ((...any) -> ())?,
	Close: () -> (),
	IsOpen: () -> boolean,
	-- Handles Backspace / B itself when it can (closes an inner picker, asks about unsaved changes).
	-- Return true when handled; false or nil lets the manager close the window.
	Back: (() -> boolean)?,
	-- The window's own input context already handles Backspace / B; the manager leaves it alone.
	OwnsBack: boolean?,
	-- The window frame, for the close animation (needs a UIScale child, as ModalFit adds).
	Root: (() -> GuiObject?)?,
	-- Keep the HUD's Gold/Gems bar visible on top of this window (it has no currency of its own).
	HudCurrency: boolean?,
}

local WindowManager = {}

local adapters: { [string]: Adapter } = {}
local order: { string } = {} -- most recently opened last
-- Bumped on every open, so a close animation that finishes after the window was reopened
-- doesn't close it again.
local generation: { [string]: number } = {}
local changed = Instance.new("BindableEvent")
WindowManager.Changed = changed.Event

local function touch(id: string)
	generation[id] = (generation[id] or 0) + 1
	local i = table.find(order, id)
	if i then table.remove(order, i) end
	table.insert(order, id)
end

local function isOpen(id: string): boolean
	local a = adapters[id]
	if not a then return false end
	local ok, open = pcall(a.IsOpen)
	return ok and open == true
end

function WindowManager.Register(id: string, adapter: Adapter)
	adapters[id] = adapter
end

function WindowManager.IsOpen(id: string): boolean
	return isOpen(id)
end

function WindowManager.IsAnyOpen(): boolean
	for id in adapters do
		if isOpen(id) then return true end
	end
	return false
end

-- The window Backspace / B should act on: the most recently opened one still open, else any open one.
function WindowManager.Top(): string?
	for i = #order, 1, -1 do
		if isOpen(order[i]) then return order[i] end
	end
	for id in adapters do
		if isOpen(id) then return id end
	end
	return nil
end

-- Whether the HUD's currency bar should stay on top of the open window.
function WindowManager.WantsHudCurrency(): boolean
	local top = WindowManager.Top()
	return top ~= nil and adapters[top].HudCurrency == true
end

-- Tells the manager a window opened through its own path (a world prompt, a rail button).
function WindowManager.Opened(id: string)
	touch(id)
	changed:Fire(id, true)
end

-- Closes `id`, shrinking it out first when it has a Root with a UIScale.
function WindowManager.Close(id: string, immediate: boolean?)
	local a = adapters[id]
	if not a or not isOpen(id) then return end
	local root = a.Root and a.Root()
	local scale = root and root:FindFirstChildOfClass("UIScale")
	local gen = generation[id]
	local function finish()
		if generation[id] ~= gen then return end -- reopened while closing
		pcall(a.Close)
		local i = table.find(order, id)
		if i and not isOpen(id) then table.remove(order, i) end
		changed:Fire(id, false)
	end
	if immediate or not root or not scale or not root.Visible or UIFeel.ReducedMotion() then
		finish()
		return
	end
	local resting = scale.Scale
	local tween = TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = resting * 0.94 })
	tween.Completed:Once(function()
		finish()
		-- Restore for the next open (ModalFit's open pop starts from the resting scale).
		scale.Scale = resting
	end)
	tween:Play()
end

-- Closes every open window except `keep`.
function WindowManager.CloseAll(keep: string?, immediate: boolean?)
	for id in adapters do
		if id ~= keep then WindowManager.Close(id, immediate) end
	end
end

-- Opens `id` after closing the others. Extra arguments go to the window's Open.
function WindowManager.Open(id: string, ...: any)
	local a = adapters[id]
	if not a then return end
	WindowManager.CloseAll(id)
	if a.Open then a.Open(...) end
	touch(id)
	changed:Fire(id, true)
end

-- Backspace / B: the topmost window's Back, or close it. Returns true when something was handled.
function WindowManager.Back(): boolean
	local top = WindowManager.Top()
	if not top then return false end
	local a = adapters[top]
	if a.OwnsBack then return true end
	if a.Back then
		local ok, handled = pcall(a.Back)
		if ok and handled then return true end
	end
	WindowManager.Close(top)
	return true
end

-- Backspace / gamepad B through the Input Action System, below every window's own context, so an inner
-- layer (drawer, dialog) that sinks the key wins.
task.spawn(function()
	local context = Instance.new("InputContext")
	context.Name = "WindowManagerBack"
	context.Priority = 1000
	context.Sink = false
	local action = Instance.new("InputAction")
	action.Name = "Back"
	action.Type = Enum.InputActionType.Bool
	action.Parent = context
	for _, key in { Enum.KeyCode.Backspace, Enum.KeyCode.ButtonB } do
		local binding = Instance.new("InputBinding")
		binding.KeyCode = key
		binding.Parent = action
	end
	action.Pressed:Connect(function()
		if UserInputService:GetFocusedTextBox() then return end
		WindowManager.Back()
	end)
	context.Parent = Players.LocalPlayer:WaitForChild("PlayerScripts")
end)

return WindowManager
