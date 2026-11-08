--!strict
-- StarterPlayerScripts/UI/Kit/Tooltip.luau
-- One tooltip layer for the whole game (UI overhaul plan §4.6). Shows on mouse hover (0.35 s),
-- touch long-press (0.4 s) or gamepad selection (0.5 s dwell), flips at screen edges
-- (UiKitRules.PlaceTooltip) and can show stat deltas, a disabled reason and a key hint.
--
--   local unbind = Tooltip.Bind(button, function() return { Title = "Holy Claymore", Body = "..." } end)
--   Tooltip.Flash(button, "Only on Tower floors")   -- a short reason after a tap on a blocked button

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("UiKitRules"))
local GrimoireIcons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("GrimoireIcons"))
local Tokens = require(script.Parent:WaitForChild("Tokens"))

local New = Tokens.New

export type Line = { Label: string, Value: string?, Before: number?, After: number?, Format: string? }
export type Content = {
	Title: string?,
	Tag: string?, -- small coloured line under the title (rarity, "Equipped by Aaron")
	TagColor: Color3?,
	Lines: { Line }?,
	Body: string?,
	Reason: string?, -- why something is unavailable, in red
	Key: string?, -- key hint, e.g. "Q"
}
export type Options = { Prefer: ("Below" | "Right" | "Left")?, Delay: number? }

local Tooltip = {}

local WIDTH = 260
local gui: ScreenGui? = nil
local current: Frame? = nil
local currentAnchor: GuiObject? = nil
local showToken = 0

local function layer(): ScreenGui
	if gui and gui.Parent then return gui end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = New("ScreenGui", {
		Name = "KitTooltipGui", DisplayOrder = 400, ResetOnSpawn = false, IgnoreGuiInset = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)
	return gui :: ScreenGui
end

local function normalise(content: Content | string): Content
	if type(content) == "string" then return { Body = content } end
	return content
end

local function build(content: Content): Frame
	local frame = New("Frame", {
		Name = "KitTooltip", Size = UDim2.fromOffset(WIDTH, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 50, Active = false,
	})
	Tokens.Paint(frame, Tokens.Surface.Inset, 10, 2.5, 0.3)
	-- Layout lives in its own frame: Paint's rail is a child too and must not be laid out.
	local body = New("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 51 }, frame)
	New("UIPadding", {
		PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
	}, body)
	New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, body)
	local order = 0
	local function nextOrder(): number order += 1 return order end
	local function line(text: string, size: number, role: string?, color: Color3?)
		Tokens.Label(body, text, size, role, {
			LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true, TextColor3 = color or Tokens.Text.Parchment, ZIndex = 52,
		})
	end
	if content.Title then line(content.Title, 16, "Title", Tokens.Text.White) end
	if content.Tag then line(content.Tag, 13, "Body", content.TagColor or Tokens.Text.Gold) end
	for _, l in content.Lines or {} do
		local row = New("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, ZIndex = 52 }, body)
		Tokens.Label(row, l.Label, 13, "Body", { Size = UDim2.fromScale(0.5, 1), TextColor3 = Tokens.Text.Muted, ZIndex = 52 })
		local value = l.Value or ""
		local color = Tokens.Text.Parchment
		if l.Before ~= nil and l.After ~= nil then
			local fmt = l.Format or "%.0f"
			local delta, sign = Rules.FormatDelta(l.Before, l.After, fmt)
			value = string.format(fmt, l.After) .. "  (" .. delta .. ")"
			color = if sign > 0 then Tokens.Severity.success elseif sign < 0 then Tokens.Severity.error else Tokens.Text.Parchment
		end
		Tokens.Label(row, value, 13, "Number", {
			Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.5, 1), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = color, ZIndex = 52,
		})
	end
	if content.Body then line(content.Body, 14) end
	if content.Reason then line(content.Reason, 14, "Body", Tokens.Severity.error) end
	if content.Key then
		local row = New("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, ZIndex = 52 }, body)
		local chip = Tokens.Label(row, content.Key, 13, "Number", {
			Size = UDim2.fromOffset(24, 22), TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 0,
			BackgroundColor3 = Tokens.Surface.Panel.Top, ZIndex = 53,
		})
		New("UICorner", { CornerRadius = UDim.new(0, 6) }, chip)
		New("UIStroke", { Color = Tokens.Text.Gold, Thickness = 1.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, chip)
		Tokens.Label(row, "shortcut", 13, "Body", { Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -32, 1, 0), TextColor3 = Tokens.Text.Muted, ZIndex = 52 })
	end
	if content.Reason and not content.Title then
		-- A bare reason gets a lock to read as "blocked" at a glance.
		local icon = GrimoireIcons.Create("Lock", 16, body, 53)
		icon.LayoutOrder = 0
	end
	return frame
end

-- Screen-space top-left of `anchor` in the tooltip layer's coordinates.
local function anchorRect(anchor: GuiObject): (number, number, number, number)
	local pos, size = anchor.AbsolutePosition, anchor.AbsoluteSize
	local host = anchor:FindFirstAncestorWhichIsA("ScreenGui")
	local inset = GuiService:GetGuiInset()
	local dy = if host and host.IgnoreGuiInset then -inset.Y else 0
	return pos.X, pos.Y + dy, size.X, size.Y
end

function Tooltip.Hide()
	showToken += 1
	if current then current:Destroy() end
	current, currentAnchor = nil, nil
end

-- Shows `content` next to `anchor` right away (Bind adds the hover/press delays).
function Tooltip.Show(anchor: GuiObject, content: Content | string, opts: Options?)
	Tooltip.Hide()
	local o = opts or {}
	local root = layer()
	local frame = build(normalise(content))
	frame.Visible = false
	frame.Parent = root
	current, currentAnchor = frame, anchor
	-- Measure after layout, then place.
	task.defer(function()
		if current ~= frame or not anchor.Parent then return end
		local ax, ay, aw, ah = anchorRect(anchor)
		local screen = root.AbsoluteSize
		local p = Rules.PlaceTooltip(ax, ay, aw, ah, frame.AbsoluteSize.X, frame.AbsoluteSize.Y, screen.X, screen.Y, 8, 8, o.Prefer)
		frame.Position = UDim2.fromOffset(p.X, p.Y)
		frame.Visible = true
	end)
end

-- Shows a tooltip for `seconds` (default 2.2), e.g. the reason after tapping a disabled button.
function Tooltip.Flash(anchor: GuiObject, content: Content | string, seconds: number?, opts: Options?)
	Tooltip.Show(anchor, content, opts)
	local token = showToken
	task.delay(seconds or 2.2, function()
		if showToken == token and currentAnchor == anchor then Tooltip.Hide() end
	end)
end

-- Wires hover, long-press and gamepad selection on `anchor`. `content` is called each time it
-- shows (return nil to show nothing). Returns a function that unbinds.
function Tooltip.Bind(anchor: GuiObject, content: () -> (Content | string)?, opts: Options?): () -> ()
	local o = opts or {}
	local conns: { RBXScriptConnection } = {}
	local function showAfter(delay: number)
		showToken += 1
		local token = showToken
		task.delay(delay, function()
			if showToken ~= token or not anchor.Parent or not anchor.Visible then return end
			local c = content()
			if c then Tooltip.Show(anchor, c, o) end
		end)
	end
	-- Leaving cancels a pending show for this anchor and hides its tooltip.
	local function hide()
		Tooltip.Hide()
	end
	table.insert(conns, anchor.MouseEnter:Connect(function() showAfter(o.Delay or 0.35) end))
	table.insert(conns, anchor.MouseLeave:Connect(hide))
	table.insert(conns, anchor.SelectionGained:Connect(function() showAfter(0.5) end))
	table.insert(conns, anchor.SelectionLost:Connect(hide))
	table.insert(conns, anchor.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then showAfter(0.4) end
	end))
	table.insert(conns, anchor.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then
			showToken += 1
			local token = showToken
			task.delay(1.5, function() if showToken == token and currentAnchor == anchor then Tooltip.Hide() end end)
		end
	end))
	table.insert(conns, anchor.Destroying:Connect(hide))
	return function()
		for _, c in conns do c:Disconnect() end
		if currentAnchor == anchor then Tooltip.Hide() end
	end
end

return table.freeze(Tooltip)
