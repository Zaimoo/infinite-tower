--!strict
-- StarterPlayerScripts/UI/Kit/Notify.luau
-- Toasts (UI overhaul plan §4.3): up to 3 stacked at the top centre, newest on top. Each is a small
-- card: an icon, a short headline in the kind's colour and, when there is more to say, one short
-- line under it. The same message again coalesces into "×3" instead of flickering.
-- Results ("Saved", "Optimal gear equipped") go here; blockers go to a Callout next to the action.
-- Keep them terse: a headline of two or three words, a detail line of one clause.
--
--   Notify.Push("success", "Settings applied")
--   Notify.Push("warn", "Locked|Clear Floor 1 first")  -- headline | detail
--   Notify.Push("reward", "Gold", { Amount = 472 })    -- "GOLD / +472 Gold", amounts add up when repeated

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
local views: { [number]: { Frame: Frame, Label: TextLabel, Detail: TextLabel?, Scale: UIScale, Icon: string? } } = {}
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

-- What a toast card shows: its headline and the lines under it.
local function parts(toast: Rules.Toast): (string, { string }?)
	local count = if toast.Count > 1 then string.format(" ×%d", toast.Count) else ""
	if toast.Lines then return toast.Text, toast.Lines end
	if toast.Amount and toast.Kind == "reward" then
		return toast.Text, { string.format("+%s %s", StatBalance.Format(toast.Amount), toast.Text) }
	end
	local title, detail = Rules.SplitToast(toast.Text)
	return title .. count, if detail then { detail } else nil
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

local MAX_TEXT = 340 -- px; longer lines wrap rather than run across the screen

local function build(toast: Rules.Toast, iconName: string?)
	local color = Tokens.Severity[toast.Kind] or Tokens.Severity.info
	local title, lines = parts(toast)
	local stackFrame = root()
	local frame = New("Frame", { Name = "Toast_" .. toast.Kind, AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0), ZIndex = 2 })
	Tokens.Paint(frame, Tokens.Surface.Hud, Tokens.Radius.Panel, 2.5, 0.3)
	local accent = New("Frame", { Name = "Accent", BackgroundColor3 = color, BorderSizePixel = 0, Position = UDim2.fromOffset(6, 8), Size = UDim2.new(0, 4, 1, -16), ZIndex = 3 }, frame)
	New("UICorner", { CornerRadius = UDim.new(1, 0) }, accent)
	-- Layout lives in its own frame: Paint's rail is a child too and must not be laid out.
	local content = New("Frame", { Name = "Content", BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0), ZIndex = 3 }, frame)
	New("UIPadding", {
		PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18),
		PaddingTop = UDim.new(0, Tokens.Space.S), PaddingBottom = UDim.new(0, Tokens.Space.S),
	}, content)
	New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, content)
	local icon = GrimoireIcons.Create(iconName or Tokens.SeverityIcon[toast.Kind] or "Spark", if lines then 32 else 26, content, 4)
	icon.LayoutOrder = 1
	local details = New("Frame", {
		Name = "Details", LayoutOrder = 2, BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0), ZIndex = 4,
	}, content)
	New("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder }, details)
	local function line(name: string, text: string, size: number, role: string, textColor: Color3, layoutOrder: number): TextLabel
		local label = Tokens.Label(details, text, size, role, {
			Name = name, LayoutOrder = layoutOrder, AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0),
			TextWrapped = true, RichText = false, TextColor3 = textColor, ZIndex = 4,
		})
		local limit = New("UISizeConstraint", {}, label)
		local function fit()
			limit.MaxSize = Vector2.new(math.max(120, math.min(MAX_TEXT, stackFrame.AbsoluteSize.X - 96)), math.huge)
		end
		fit()
		local resized = stackFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		label.Destroying:Once(function() resized:Disconnect() end)
		return label
	end
	local label: TextLabel
	local detail: TextLabel? = nil
	if lines then
		-- Headline in the kind's colour, small caps weight; what happened in plain white under it.
		label = line("Title", string.upper(title), 14, "Title", color, 0)
		for index, body in lines do
			local row = line("Line" .. index, body, Tokens.Type.Body, "Body", Tokens.Text.White, index)
			if index == 1 then detail = row end
		end
	else
		label = line("Text", title, 16, "Body", if toast.Kind == "error" or toast.Kind == "warn" then color else Tokens.Text.White, 0)
	end
	local scale = New("UIScale", { Scale = if UIFeel.ReducedMotion() then 1 else 0.6 }, frame)
	frame.Parent = stackFrame
	views[toast.Id] = { Frame = frame, Label = label, Detail = detail, Scale = scale, Icon = iconName }
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
	clean = (string.gsub(clean, "\239\184\143", "")) -- the variation selector some emoji leave behind
	clean = (string.gsub(clean, "^%s+", ""))
	local toast, isNew, evicted = Rules.PushToast(stack, kind, clean, os.clock(), o.Amount, o.Hold, o.Lines)
	for _, gone in evicted do remove(gone.Id, true) end
	if isNew then
		build(toast, o.Icon)
	else
		local v = views[toast.Id]
		if v then
			local title, lines = parts(toast)
			v.Label.Text = if lines then string.upper(title) else title
			if v.Detail and lines then v.Detail.Text = lines[1] end
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
