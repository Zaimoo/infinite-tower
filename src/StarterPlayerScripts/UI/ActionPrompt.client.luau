--!strict
-- StarterPlayerScripts/UI/ActionPrompt.client.luau
-- The game's own action prompt in place of Roblox's default ProximityPrompt look. Every prompt is
-- switched to Style = Custom on this client (servers keep creating plain prompts), and
-- ProximityPromptService's PromptShown/PromptHidden draw a Brighter Grimoire card instead: key cap,
-- action and object text, a gold hold bar for HoldDuration prompts, and a tap/click target when
-- the prompt is ClickablePrompt. Triggering still goes through the prompt itself, so every
-- PromptTriggered listener (TowerController, MasterController, ...) works unchanged.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UI = script.Parent
local Kit = require(UI:WaitForChild("Kit"))
local UIFeel = require(UI:WaitForChild("UIFeel"))
local Tokens = Kit.Tokens
local New = Tokens.New

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GAMEPAD_LABELS: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.ButtonA] = "A", [Enum.KeyCode.ButtonB] = "B", [Enum.KeyCode.ButtonX] = "X", [Enum.KeyCode.ButtonY] = "Y",
	[Enum.KeyCode.ButtonL1] = "LB", [Enum.KeyCode.ButtonR1] = "RB", [Enum.KeyCode.ButtonL2] = "LT", [Enum.KeyCode.ButtonR2] = "RT",
	[Enum.KeyCode.DPadUp] = "Up", [Enum.KeyCode.DPadDown] = "Down", [Enum.KeyCode.DPadLeft] = "Left", [Enum.KeyCode.DPadRight] = "Right",
}

local function adopt(instance: Instance)
	if instance:IsA("ProximityPrompt") then instance.Style = Enum.ProximityPromptStyle.Custom end
end
for _, d in workspace:GetDescendants() do adopt(d) end
workspace.DescendantAdded:Connect(adopt)

-- BillboardGuis render only as direct LayerCollectors under PlayerGui (or a Folder), never inside a ScreenGui.
local gui = New("Folder", { Name = "ActionPrompts" }, playerGui)

local function keyLabel(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Touch then return "TAP" end
	if inputType == Enum.ProximityPromptInputType.Gamepad then
		return GAMEPAD_LABELS[prompt.GamepadKeyCode] or prompt.GamepadKeyCode.Name
	end
	local code = prompt.KeyboardKeyCode
	local text = UserInputService:GetStringForKeyCode(code)
	if text == nil or text == "" then text = code.Name end
	return string.upper(text)
end

type View = { Billboard: BillboardGui, Cleanup: { RBXScriptConnection } }
local views: { [ProximityPrompt]: View } = {}

local function hide(prompt: ProximityPrompt)
	local view = views[prompt]
	if not view then return end
	views[prompt] = nil
	for _, c in view.Cleanup do c:Disconnect() end
	local card = view.Billboard:FindFirstChild("Card") :: GuiObject?
	local scale = card and card:FindFirstChildOfClass("UIScale")
	if scale and not UIFeel.ReducedMotion() then
		local t = TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.6 })
		t.Completed:Once(function() view.Billboard:Destroy() end)
		t:Play()
	else
		view.Billboard:Destroy()
	end
end

local function show(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	hide(prompt)
	local parent = prompt.Parent
	local adornee: Instance? = nil
	if parent and (parent:IsA("BasePart") or parent:IsA("Attachment")) then
		adornee = parent
	elseif parent and parent:IsA("Model") then
		adornee = parent.PrimaryPart or parent:FindFirstChildWhichIsA("BasePart", true)
	else
		adornee = prompt:FindFirstAncestorWhichIsA("BasePart")
	end
	if not adornee then return end

	local touch = inputType == Enum.ProximityPromptInputType.Touch
	local billboard = New("BillboardGui", {
		Name = "Prompt_" .. prompt.Name, Adornee = adornee, AlwaysOnTop = true, Active = true,
		Size = UDim2.fromOffset(320, 72), SizeOffset = Vector2.new(0, 0.5),
		StudsOffset = Vector3.new(0, 1.5, 0), LightInfluence = 0, MaxDistance = prompt.MaxActivationDistance + 30,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, ResetOnSpawn = false,
	}, gui)

	-- The card: a TextButton so touch and mouse can press it when the prompt is clickable.
	local card: TextButton = New("TextButton", {
		Name = "Card", Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, 56), AutomaticSize = Enum.AutomaticSize.X,
		Active = prompt.ClickablePrompt, Selectable = false,
	}, billboard)
	Tokens.Paint(card, Tokens.Surface.Hud, Tokens.Radius.Panel, 2.5, 0.2)
	local scale = New("UIScale", { Scale = if UIFeel.ReducedMotion() then 1 else 0.6 }, card)

	local content = New("Frame", {
		Name = "Content", BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 56), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 2,
	}, card)
	New("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 16) }, content)
	New("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder,
	}, content)

	-- Key cap with the hold ring drawn as a filling gold bar beneath it.
	local cap = New("Frame", { Name = "KeyCap", LayoutOrder = 1, Size = UDim2.fromOffset(if touch then 52 else 40, 40), ZIndex = 3 }, content)
	Tokens.Paint(cap, Tokens.Intent.Primary, Tokens.Radius.Tile, 2, 0.1)
	Tokens.Label(cap, keyLabel(prompt, inputType), if touch then 15 else 20, "Title", {
		Name = "Key", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Tokens.Ink, TextStrokeTransparency = 1, ZIndex = 4,
	})

	local texts = New("Frame", {
		Name = "Texts", LayoutOrder = 2, BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 44), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 3,
	}, content)
	New("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, texts)
	local objectLabel = Tokens.Label(texts, prompt.ObjectText, Tokens.Type.Caption, "Body", {
		Name = "Object", LayoutOrder = 1, Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X,
		TextColor3 = Tokens.Text.Muted, Visible = prompt.ObjectText ~= "", ZIndex = 4,
	})
	local actionLabel = Tokens.Label(texts, prompt.ActionText, 18, "Title", {
		Name = "Action", LayoutOrder = 2, Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X,
		TextColor3 = Tokens.Text.White, ZIndex = 4,
	})
	for _, l in { objectLabel, actionLabel } do New("UISizeConstraint", { MaxSize = Vector2.new(220, 40) }, l) end

	-- Hold progress along the card's bottom edge (HoldDuration > 0 only).
	local track = New("Frame", {
		Name = "HoldTrack", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -5),
		Size = UDim2.new(1, -20, 0, 4), BackgroundColor3 = Tokens.Ink, BackgroundTransparency = 0.4,
		BorderSizePixel = 0, Visible = prompt.HoldDuration > 0, ZIndex = 5,
	}, card)
	New("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
	local fill = New("Frame", {
		Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Tokens.Severity.reward, BorderSizePixel = 0, ZIndex = 6,
	}, track)
	New("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
	local holdTween: Tween? = nil
	local function resetHold()
		if holdTween then holdTween:Cancel(); holdTween = nil end
		fill.Size = UDim2.fromScale(0, 1)
	end

	local cleanup: { RBXScriptConnection } = {}
	table.insert(cleanup, prompt.PromptButtonHoldBegan:Connect(function(who: Player)
		if who ~= player or prompt.HoldDuration <= 0 then return end
		resetHold()
		holdTween = TweenService:Create(fill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) })
		;(holdTween :: Tween):Play()
	end))
	table.insert(cleanup, prompt.PromptButtonHoldEnded:Connect(function(who: Player)
		if who == player then resetHold() end
	end))
	table.insert(cleanup, prompt.Triggered:Connect(function(who: Player)
		if who ~= player then return end
		resetHold()
		UIFeel.Pop(card, 0.1)
	end))
	for _, prop in { "ActionText", "ObjectText" } do
		table.insert(cleanup, prompt:GetPropertyChangedSignal(prop):Connect(function()
			actionLabel.Text = prompt.ActionText
			objectLabel.Text = prompt.ObjectText
			objectLabel.Visible = prompt.ObjectText ~= ""
		end))
	end

	-- Touch and mouse press the card itself (ClickablePrompt), like the default prompt.
	if prompt.ClickablePrompt then
		local pressed = false
		table.insert(cleanup, card.InputBegan:Connect(function(input: InputObject)
			if pressed then return end
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				pressed = true
				prompt:InputHoldBegin()
			end
		end))
		table.insert(cleanup, card.InputEnded:Connect(function(input: InputObject)
			if not pressed then return end
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				pressed = false
				prompt:InputHoldEnd()
			end
		end))
	end

	views[prompt] = { Billboard = billboard, Cleanup = cleanup }
	if not UIFeel.ReducedMotion() then
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
end

ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom then return end
	show(prompt, inputType)
end)
ProximityPromptService.PromptHidden:Connect(hide)
