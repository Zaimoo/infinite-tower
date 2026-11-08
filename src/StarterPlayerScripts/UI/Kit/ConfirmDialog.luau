--!strict
-- StarterPlayerScripts/UI/Kit/ConfirmDialog.luau
-- The one confirmation dialog (UI overhaul plan §4.5), in three tiers picked from the §6 risk table
-- (UiKitRules.ConfirmTier):
--   Soft      Cancel / Confirm, plus "Don't ask again this session" when a SessionKey is given.
--   Hard      lists what will be lost; Confirm (Danger) arms after 1 s.
--   Critical  as Hard, but Confirm must be held for 1.2 s.
-- Focus starts on Cancel; Backspace, gamepad B and the scrim cancel. Only one dialog shows at a time.
--
--   ConfirmDialog.Ask({ Tier = "Hard", Title = "Sell 3 weapons?", Body = "...", Items = { "Holy Claymore · Exalted 2★" },
--     ConfirmText = "Sell", OnConfirm = sell })
--   if ConfirmDialog.AskAsync({ Tier = "Soft", Title = "Spend 45,000 Gold?", SessionKey = "SUMMON_10X" }) then ... end

local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Rules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("UiKitRules"))
local GrimoireIcons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("GrimoireIcons"))
local UIFeel = require(script.Parent.Parent:WaitForChild("UIFeel"))
local Tokens = require(script.Parent:WaitForChild("Tokens"))
local Button = require(script.Parent:WaitForChild("Button"))

local New = Tokens.New

export type Options = {
	Tier: Rules.Tier?, -- default "Soft"
	Title: string,
	Body: string?,
	Items: { string }?, -- what will be consumed or lost (Hard / Critical)
	ConfirmText: string?,
	CancelText: string?,
	SessionKey: string?, -- Soft only: offers "Don't ask again this session"
	OnConfirm: (() -> ())?,
	OnCancel: (() -> ())?,
}

local ConfirmDialog = {}

local skipped: { [string]: boolean } = {}
local gui: ScreenGui? = nil
local closeCurrent: ((boolean) -> ())? = nil

local function layer(): ScreenGui
	if gui and gui.Parent then return gui end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = New("ScreenGui", {
		Name = "KitConfirmGui", DisplayOrder = 300, ResetOnSpawn = false, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Enabled = true,
	}, playerGui)
	return gui :: ScreenGui
end

-- Forget "Don't ask again" choices (e.g. on respawn or for tests).
function ConfirmDialog.ResetSession()
	table.clear(skipped)
end

function ConfirmDialog.IsOpen(): boolean
	return closeCurrent ~= nil
end

-- Shows the dialog (or confirms straight away when the tier is None or the player chose
-- "Don't ask again" for this SessionKey). Returns a function that cancels it.
function ConfirmDialog.Ask(opts: Options): () -> ()
	local tier: Rules.Tier = opts.Tier or "Soft"
	if not Rules.ShouldAsk(tier, skipped, opts.SessionKey) then
		if opts.OnConfirm then task.defer(opts.OnConfirm) end
		return function() end
	end
	if closeCurrent then closeCurrent(false) end

	local root = layer()
	local destructive = tier == "Hard" or tier == "Critical"
	local scrim: TextButton = New("TextButton", {
		Name = "ConfirmScrim", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1,
	})
	scrim:SetAttribute("NoFeel", true)
	local dialog = New("Frame", {
		Name = "ConfirmDialog", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 10, Active = true,
	}, scrim)
	Tokens.Paint(dialog, Tokens.Surface.Window, Tokens.Radius.Window, 3.5)
	local scale = New("UIScale", { Scale = 1 }, dialog)
	-- Layout lives in its own frame: Paint's rail is a child too and must not be laid out.
	local stack = New("Frame", { Name = "Stack", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 10 }, dialog)
	New("UIListLayout", { Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder }, stack)

	-- Header bar in the tier's colour.
	local header = New("Frame", { Name = "Header", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 52), ZIndex = 11 }, stack)
	Tokens.Paint(header, if destructive then Tokens.Intent.Danger else Tokens.Domain.Fortress, Tokens.Radius.Window, 0, 0.4)
	local headerIcon = GrimoireIcons.Create(if destructive then "Warning" else "Spark", 28, header, 13)
	headerIcon.AnchorPoint = Vector2.new(0, 0.5)
	headerIcon.Position = UDim2.new(0, 22, 0.5, 0)
	Tokens.Label(header, opts.Title, 20, "Title", {
		Name = "Title", Position = UDim2.fromOffset(60, 0), Size = UDim2.new(1, -80, 1, 0), TextColor3 = Tokens.Text.White, ZIndex = 13, TextTruncate = Enum.TextTruncate.AtEnd,
	})

	-- Everything under the header, padded.
	local inner = New("Frame", {
		Name = "Inner", LayoutOrder = 2, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 11,
	}, stack)
	New("UIPadding", { PaddingLeft = UDim.new(0, 22), PaddingRight = UDim.new(0, 22), PaddingTop = UDim.new(0, 16), PaddingBottom = UDim.new(0, 20) }, inner)
	New("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, inner)

	if opts.Body then
		Tokens.Label(inner, opts.Body, 15, "Body", {
			Name = "Body", LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, ZIndex = 12,
		})
	end

	if opts.Items and #opts.Items > 0 then
		local box = New("Frame", { Name = "Items", LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 11 }, inner)
		Tokens.Paint(box, Tokens.Surface.Inset, Tokens.Radius.Tile, 2, 0.6)
		local list = New("Frame", { Name = "List", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 12 }, box)
		New("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, list)
		New("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, list)
		Tokens.Label(list, if destructive then "WILL BE DESTROYED" else "INCLUDES", 13, "Title", {
			LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 20), TextColor3 = if destructive then Tokens.Severity.error else Tokens.Text.Gold, ZIndex = 13,
		})
		local shown = math.min(#opts.Items, 6)
		for i = 1, shown do
			Tokens.Label(list, "• " .. opts.Items[i], 14, "Body", { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 20), ZIndex = 13 })
		end
		if #opts.Items > shown then
			Tokens.Label(list, string.format("…and %d more", #opts.Items - shown), 13, "Body", { LayoutOrder = shown + 1, Size = UDim2.new(1, 0, 0, 20), TextColor3 = Tokens.Text.Muted, ZIndex = 13 })
		end
	end

	-- "Don't ask again this session" (Soft with a key only).
	local dontAsk = false
	if tier == "Soft" and opts.SessionKey then
		local toggle: TextButton = New("TextButton", {
			Name = "DontAskAgain", LayoutOrder = 4, Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 28), ZIndex = 12, Selectable = true,
		}, inner)
		local box = New("Frame", { Name = "Box", Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(0, 3), ZIndex = 13 }, toggle)
		Tokens.Paint(box, Tokens.Surface.Inset, 6, 2, 0.4)
		local tick = GrimoireIcons.Create("Check", 18, box, 15)
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		tick.Position = UDim2.fromScale(0.5, 0.5)
		tick.Visible = false
		Tokens.Label(toggle, "Don't ask again this session", 14, "Body", { Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -32, 1, 0), TextColor3 = Tokens.Text.Muted, ZIndex = 13 })
		toggle.Activated:Connect(function()
			dontAsk = not dontAsk
			tick.Visible = dontAsk
		end)
	end

	local actions = New("Frame", { Name = "Actions", LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1, ZIndex = 11 }, inner)
	local cancel = Button.Create(actions, {
		Name = "ConfirmCancel", Text = opts.CancelText or "Cancel", Intent = "Secondary", Size = "M", Width = UDim.new(0.42, -6), ZIndex = 12,
	})
	local confirmText = opts.ConfirmText or "Confirm"
	local confirm = Button.Create(actions, {
		Name = "ConfirmAccept", Text = confirmText, Intent = if destructive then "Danger" else "Primary", Size = "M",
		Width = UDim.new(0.58, -6), Position = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(1, 0), ZIndex = 12,
	})

	local done = false
	local actionName = "KitConfirm_" .. HttpService:GenerateGUID(false)
	local backContext: InputContext? = nil
	local heartbeat: RBXScriptConnection? = nil
	local previousSelection = GuiService.SelectedObject

	local function close(accepted: boolean)
		if done then return end
		done = true
		closeCurrent = nil
		if backContext then backContext:Destroy() end
		if heartbeat then heartbeat:Disconnect() end
		if accepted and dontAsk and opts.SessionKey then skipped[opts.SessionKey] = true end
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(scrim) then
			GuiService.SelectedObject = if previousSelection and previousSelection.Parent then previousSelection else nil
		end
		local finish = function()
			cancel.Destroy()
			confirm.Destroy()
			scrim:Destroy()
		end
		if UIFeel.ReducedMotion() then finish()
		else
			TweenService:Create(scrim, TweenInfo.new(0.12), { BackgroundTransparency = 1 }):Play()
			local t = TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.95 })
			t.Completed:Once(finish)
			t:Play()
		end
		if accepted then
			if opts.OnConfirm then task.spawn(opts.OnConfirm) end
		elseif opts.OnCancel then
			task.spawn(opts.OnCancel)
		end
	end
	closeCurrent = close

	cancel.Update({ OnActivate = function() close(false) end })
	scrim.Activated:Connect(function() close(false) end)

	-- Hard: Confirm arms after a delay. Critical: hold to confirm.
	local arm = Rules.ArmDelay[tier] or 0
	if tier == "Hard" and arm > 0 then
		confirm.Update({ Disabled = true, Text = string.format("%s (%d)", confirmText, math.ceil(arm)), Reason = "Read what will be lost first." })
		task.delay(arm, function()
			if not done then confirm.Update({ Disabled = false, Text = confirmText, Reason = nil, OnActivate = function() close(true) end }) end
		end)
	elseif tier == "Critical" then
		local held: number? = nil
		local fill = New("Frame", {
			Name = "HoldFill", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.6, BorderSizePixel = 0,
			Size = UDim2.fromScale(0, 1), ZIndex = 20, Active = false,
		}, confirm.Instance)
		New("UICorner", { CornerRadius = UDim.new(0, Tokens.Radius.Button) }, fill)
		confirm.Update({ Text = "Hold to " .. string.lower(confirmText) })
		local button = confirm.Instance
		local function release()
			held = nil
			fill.Size = UDim2.fromScale(0, 1)
		end
		button.InputBegan:Connect(function(input: InputObject)
			local t = input.UserInputType
			if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA or input.KeyCode == Enum.KeyCode.Return then
				held = os.clock()
			end
		end)
		button.InputEnded:Connect(release)
		button.MouseLeave:Connect(release)
		heartbeat = RunService.Heartbeat:Connect(function()
			if not held then return end
			local p = math.clamp((os.clock() - held) / arm, 0, 1)
			fill.Size = UDim2.fromScale(p, 1)
			if p >= 1 then
				held = nil
				UIFeel.Haptic("Impact")
				close(true)
			end
		end)
	else
		confirm.Update({ OnActivate = function() close(true) end })
	end

	-- Backspace / gamepad B cancel while the dialog is up. Priority 5000 and Sink, above every window's
	-- context (hero drawer 4000, Forge 2500, WindowManager 1000), so the key never reaches them.
	backContext = New("InputContext", { Name = actionName, Priority = 5000, Sink = true })
	local backAction = New("InputAction", { Name = "Cancel", Type = Enum.InputActionType.Bool }, backContext)
	for _, key in { Enum.KeyCode.ButtonB, Enum.KeyCode.Backspace } do
		New("InputBinding", { KeyCode = key }, backAction)
	end
	backAction.Pressed:Connect(function()
		-- Backspace while typing in chat edits text; it doesn't cancel the dialog.
		if UserInputService:GetFocusedTextBox() then return end
		close(false)
	end)
	backContext.Parent = Players.LocalPlayer:WaitForChild("PlayerScripts")

	scrim.Parent = root
	UIFeel.Sfx(if destructive then "Error" else "WindowOpen", 1, 0.5)
	if UIFeel.ReducedMotion() then
		scrim.BackgroundTransparency = 0.45
	else
		scale.Scale = 0.9
		TweenService:Create(scrim, TweenInfo.new(0.15), { BackgroundTransparency = 0.45 }):Play()
		TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	GuiService.SelectedObject = cancel.Instance

	return function() close(false) end
end

-- Yields until the player answers; true when confirmed.
function ConfirmDialog.AskAsync(opts: Options): boolean
	local result: boolean? = nil
	local thread = coroutine.running()
	local o = table.clone(opts)
	o.OnConfirm = function() if result == nil then result = true task.spawn(thread) end end
	o.OnCancel = function() if result == nil then result = false task.spawn(thread) end end
	ConfirmDialog.Ask(o)
	if result == nil then coroutine.yield() end
	return result == true
end

return table.freeze(ConfirmDialog)
