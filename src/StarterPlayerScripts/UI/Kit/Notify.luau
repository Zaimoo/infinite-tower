--!strict
-- StarterPlayerScripts/UI/Kit/Notify.luau
-- Toasts (UI overhaul plan §4.3): up to 3 stacked at the top centre, newest on top. Each slides in
-- with an icon for its kind; the same message again coalesces into "×3" instead of flickering.
-- Results ("Saved", "Optimal gear equipped") go here; blockers go to a Callout next to the action.
--
--   Notify.Push("success", "Settings applied.")
--   Notify.Push("reward", "Gold", { Amount = 472 })   -- "+472 Gold", amounts add up when repeated

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local StatBalance = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("StatBalance"))
local Rules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("UiKitRules"))
local TowerRun = require(ReplicatedStorage.Shared.Util.TowerRun)
local GrimoireIcons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("GrimoireIcons"))
local UIFeel = require(script.Parent.Parent:WaitForChild("UIFeel"))
local Tokens = require(script.Parent:WaitForChild("Tokens"))

local New = Tokens.New

export type Kind = Rules.ToastKind
export type Options = { Amount: number?, Icon: string?, Hold: number?, Lines: { string }? }

local Notify = {}

local stack = Rules.NewToastStack(3)
local views: { [number]: { Frame: Frame, Label: TextLabel, Scale: UIScale, Icon: string? } } = {}
local gui: ScreenGui? = nil
local holder: Frame? = nil
local ticking = false
local topInset = 0
local alignRight = false

local function placeStack(stackFrame: Frame)
	stackFrame.AnchorPoint = Vector2.new(if alignRight then 1 else 0.5, 0)
	stackFrame.Position = if alignRight then UDim2.new(1, -16, 0, 10 + topInset) else UDim2.new(0.5, 0, 0, 10 + topInset)
	stackFrame.Size = UDim2.new(if alignRight then 0.5 else 1, -24, 0, 0)
end

local function root(): Frame
	if holder and holder.Parent and gui and gui.Parent then return holder end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = New("ScreenGui", {
		Name = "KitNotifyGui", DisplayOrder = 290, -- under ConfirmDialog (300): a toast never covers a question
		 ResetOnSpawn = false, IgnoreGuiInset = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)
	holder = New("Frame", {
		Name = "Toasts", AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
	}, gui)
	placeStack(holder :: Frame)
	New("UISizeConstraint", { MaxSize = Vector2.new(560, math.huge) }, holder)
	New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, holder)
	return holder :: Frame
end

function Notify.SetTopInset(inset: number, right: boolean)
	if inset == topInset and right == alignRight then return end
	topInset, alignRight = inset, right
	if holder then placeStack(holder) end
end

local function text(toast: Rules.Toast): string
	if toast.Amount and toast.Kind == "reward" then
		return string.format("+%s %s", StatBalance.Format(toast.Amount), toast.Text)
	end
	return Rules.ToastLabel(toast)
end

local function order()
	-- Newest first: LayoutOrder follows the stack.
	for i, toast in stack.Items do
		local v = views[toast.Id]
		if v then v.Frame.LayoutOrder = i end
	end
end

local function remove(id: number, immediate: boolean?)
	local v = views[id]
	if not v then return end
	views[id] = nil
	if immediate or UIFeel.ReducedMotion() then v.Frame:Destroy() return end
	local t = TweenService:Create(v.Scale, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 })
	t.Completed:Once(function() v.Frame:Destroy() end)
	t:Play()
end

local function build(toast: Rules.Toast, iconName: string?)
	local color = Tokens.Severity[toast.Kind] or Tokens.Severity.info
	local lines = toast.Lines
	local stackFrame = root()
	local frame = New("Frame", { Name = "Toast_" .. toast.Kind, Size = UDim2.new(0, 0, 0, 48), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 2 })
	Tokens.Paint(frame, Tokens.Surface.Hud, Tokens.Radius.Panel, 2.5, 0.3)
	local accent = New("Frame", { Name = "Accent", BackgroundColor3 = color, BorderSizePixel = 0, Position = UDim2.fromOffset(6, 8), Size = UDim2.new(0, 4, 1, -16), ZIndex = 3 }, frame)
	New("UICorner", { CornerRadius = UDim.new(1, 0) }, accent)
	-- Layout lives in its own frame: Paint's rail is a child too and must not be laid out.
	local content = New("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 48), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 3 }, frame)
	New("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18) }, content)
	New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, content)
	local icon = GrimoireIcons.Create(iconName or Tokens.SeverityIcon[toast.Kind] or "Spark", 26, content, 4)
	icon.LayoutOrder = 1
	local label: TextLabel
	if lines then
		frame.Size = UDim2.fromScale(1, 0)
		frame.AutomaticSize = Enum.AutomaticSize.Y
		New("UISizeConstraint", { MaxSize = Vector2.new(460, math.huge) }, frame)
		content.Size = UDim2.fromScale(1, 0)
		content.AutomaticSize = Enum.AutomaticSize.Y
		local padding = content:FindFirstChildOfClass("UIPadding") :: UIPadding
		padding.PaddingTop = UDim.new(0, Tokens.Space.S)
		padding.PaddingBottom = UDim.new(0, Tokens.Space.S)
		local details = New("Frame", {
			Name = "Details", LayoutOrder = 2, BackgroundTransparency = 1,
			Size = UDim2.new(1, -36, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 4,
		}, content)
		New("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, details)
		label = Tokens.Label(details, toast.Text, Tokens.Type.Body, "Title", {
			Name = "Title", LayoutOrder = 0, Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true, RichText = false, TextColor3 = color, ZIndex = 4,
		})
		for index, line in lines do
			Tokens.Label(details, line, Tokens.Type.Caption, "Body", {
				Name = "RewardLine" .. index, LayoutOrder = index, Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, RichText = false, ZIndex = 4,
			})
		end
	else
		label = Tokens.Label(content, text(toast), 17, "Body", {
			Name = "Text", LayoutOrder = 2, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 48), ZIndex = 4,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = if toast.Kind == "error" or toast.Kind == "warn" then color else Tokens.Text.White,
		})
		local limit = New("UISizeConstraint", {}, label)
		local function fitLabel()
			limit.MaxSize = Vector2.new(math.max(0, stackFrame.AbsoluteSize.X - 72), 48)
		end
		fitLabel()
		local resized = stackFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitLabel)
		frame.Destroying:Once(function() resized:Disconnect() end)
	end
	local scale = New("UIScale", { Scale = if UIFeel.ReducedMotion() then 1 else 0.6 }, frame)
	frame.Parent = stackFrame
	views[toast.Id] = { Frame = frame, Label = label, Scale = scale, Icon = iconName }
	if not UIFeel.ReducedMotion() then
		TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	if toast.Kind == "warn" or toast.Kind == "error" then
		UIFeel.Sfx("Error")
		UIFeel.Haptic("Notify")
		UIFeel.Shake(frame, 2.5, 0.3)
	else
		UIFeel.Sfx(if toast.Kind == "reward" then "Reward" else "ToastIn", 1, 0.6)
	end
end

local function tick()
	if ticking then return end
	ticking = true
	task.spawn(function()
		while #stack.Items > 0 do
			task.wait(0.2)
			for _, gone in Rules.ExpireToasts(stack, os.clock()) do remove(gone.Id) end
		end
		ticking = false
	end)
end

-- Shows a toast. kind: "info" | "success" | "warn" | "error" | "reward".
function Notify.Push(kind: Kind, message: string, opts: Options?)
	local o = opts or {}
	-- Gilded Grimoire: no emoji in the UI (server messages may still carry them).
	local clean = (string.gsub(message, "[\240-\244][\128-\191]*", ""))
	clean = (string.gsub(clean, "^%s+", ""))
	local toast, isNew, evicted = Rules.PushToast(stack, kind, clean, os.clock(), o.Amount, o.Hold, o.Lines)
	for _, gone in evicted do remove(gone.Id, true) end
	if isNew then
		build(toast, o.Icon)
	else
		local v = views[toast.Id]
		if v then
			v.Label.Text = text(toast)
			UIFeel.Pop(v.Frame, 0.08)
		end
	end
	order()
	tick()
end

function Notify.Info(message: string) Notify.Push("info", message) end
function Notify.Success(message: string) Notify.Push("success", message) end
function Notify.Warn(message: string) Notify.Push("warn", message) end
function Notify.Error(message: string) Notify.Push("error", message) end
function Notify.Reward(currency: string, amount: number) Notify.Push("reward", currency, { Amount = amount, Icon = currency }) end

function Notify.RelicReceipt(receipt: TowerRun.RelicReceipt)
	local lines = {
		Rules.RewardLine("Gold", receipt.Gold, receipt.StreakGold),
		Rules.RewardLine("Gems", receipt.Gems, receipt.StreakGems),
	}
	local stones = receipt.PromotionStones
	if stones > 0 then
		table.insert(lines, Rules.RewardLine(if stones == 1 then "Promotion Stone" else "Promotion Stones", stones))
	end
	Notify.Push("reward", "Banked " .. receipt.RelicName, { Lines = lines, Hold = 5 })
end

return table.freeze(Notify)
