--!strict
-- Install this folder under StarterPlayerScripts/UI. Reuses the existing theme and previews.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local React = require(ReplicatedStorage.Packages.React)
local Catalog = require(ReplicatedStorage.Shared.Config.ArtifactCatalog)
local Stats = require(ReplicatedStorage.Shared.Util.StatFormulas)
local Balance = require(ReplicatedStorage.Shared.Config.StatBalance)
local Portrait = require(script.Parent.Parent.Hud.Portrait)
local Icons = require(script.Parent.Parent.Hud.Icons)
local ArtifactPreview = require(script.Parent.Parent.ArtifactPreview)
local UIFeel = require(script.Parent.Parent.UIFeel)
local Model = require(script.Parent.Model)
local T = require(script.Parent.Tokens)
local Kit = require(script.Parent.Parent.Kit)
local Types = require(script.Parent.Types)
type Artifact = Types.Artifact
type Hero = Types.Hero
type Snapshot = Types.Snapshot
local e = React.createElement
local C = {}

function C.Text(props: { [string]: any })
	local result: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = T.Theme.Fonts.Title,
		TextSize = T.Body,
		TextColor3 = T.Text,
		TextStrokeColor3 = T.Theme.Ink,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		RichText = false, -- names are always plain text
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 32),
	}
	for key, value in props do result[key] = value end
	-- A contextual stroke outlines the glyphs separately from button borders.
	result.TextStrokeTransparency = 1
	return e("TextLabel", result, {
		Ink = e("UIStroke", { Name = "GrimoireTextInk", ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Color = T.Theme.Ink, Thickness = math.clamp((result.TextSize or T.Body) * 0.12, 2, 3), Transparency = 0, LineJoinMode = Enum.LineJoinMode.Round }),
	})
end

function C.Stack(props: { Size: UDim2?, Position: UDim2?, Order: number?, Children: { [string]: any }, ZIndex: number? })
	local children = table.clone(props.Children)
	children.Layout = e("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	return e("Frame", {
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.new(1, 0, 0, 0),
		AutomaticSize = if props.Size then Enum.AutomaticSize.None else Enum.AutomaticSize.Y,
		Position = props.Position,
		LayoutOrder = props.Order,
		ZIndex = props.ZIndex or 1,
	}, children)
end

function C.Scroll(props: { Size: UDim2, Position: UDim2?, Children: { [string]: any }, Ref: any? })
	local children = table.clone(props.Children)
	children.Layout = e("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder })
	children.Padding = e("UIPadding", {
		PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 16),
		PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 16),
	})
	return e("ScrollingFrame", {
		ref = props.Ref,
		Size = props.Size, Position = props.Position,
		BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 6,
		ScrollBarImageColor3 = T.Gold,
		SelectionGroup = true, ClipsDescendants = true,
	}, children)
end

local function reveal(button: GuiObject)
	local parent = button:FindFirstAncestorWhichIsA("ScrollingFrame")
	if not parent then return end
	local top = button.AbsolutePosition.Y - parent.AbsolutePosition.Y
	local bottom = top + button.AbsoluteSize.Y
	local offset = if top < 8 then top - 8 elseif bottom > parent.AbsoluteWindowSize.Y - 8 then bottom - parent.AbsoluteWindowSize.Y + 8 else 0
	parent.CanvasPosition = Vector2.new(parent.CanvasPosition.X, math.max(0, parent.CanvasPosition.Y + offset))
end

type ButtonProps = {
	Text: string,
	OnActivate: () -> (),
	Size: UDim2?, Position: UDim2?, Order: number?, Name: string?,
	Disabled: boolean?, Primary: boolean?, Selected: boolean?, Accent: Color3?,
	FocusOrder: number?, Ref: any?, Icon: string?, Tooltip: string?,
	-- Brighter Grimoire intent colour (UI kit): "Primary" gold, "Confirm" jade, "Travel" azure,
	-- "Secondary" violet, "Danger" crimson. Overrides Primary/Accent for the fill.
	Intent: ("Primary" | "Confirm" | "Travel" | "Secondary" | "Danger")?,
}

function C.Button(props: ButtonProps)
	local hovered, setHovered = React.useState(false)
	local focused, setFocused = React.useState(false)
	local scaleRef = React.useRef(nil)
	local tweenRef = React.useRef(nil)
	local function animate(value: number, duration: number)
		if tweenRef.current then tweenRef.current:Cancel() end
		if not scaleRef.current then return end
		if UIFeel.ReducedMotion() then scaleRef.current.Scale = 1; return end
		local tween = TweenService:Create(scaleRef.current, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = value })
		tweenRef.current = tween
		tween:Play()
	end
	React.useEffect(function()
		animate(if not props.Disabled and (hovered or focused) then 1.035 else 1, 0.12)
		return function() if tweenRef.current then tweenRef.current:Cancel() end end
	end, { hovered, focused, props.Disabled })
	local iconSize = if props.Icon == "Add" then 44 else 28
	local active = props.Selected or focused
	local intentTone = if props.Intent and not props.Disabled then Kit.Tokens.Intent[props.Intent] else nil
	local tone = if props.Disabled then T.Theme.Tones.Slate
		elseif intentTone then intentTone
		elseif props.Primary then (if props.Accent == T.Bad then T.Theme.Tones.Crimson else T.Theme.Tones.Action)
		elseif props.Selected then T.Theme.Tones.Gold else T.Theme.Tones.Deep
	return e("TextButton", {
		ref = props.Ref,
		-- Unique, readable names (e.g. "Action_AllSpare") so tests, Studio MCP and focus maps can find them.
		Name = props.Name or ("Action_" .. (string.gsub(props.Text, "[^%w]", ""))),
		Size = props.Size or UDim2.new(1, 0, 0, T.Touch), Position = props.Position,
		LayoutOrder = props.Order, Text = "", AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0, Selectable = true, Active = true,
		Interactable = not props.Disabled,
		SelectionOrder = props.FocusOrder or props.Order or 0,
		[React.Event.MouseEnter] = function() setHovered(true) end,
		[React.Event.MouseLeave] = function() setHovered(false) end,
		[React.Event.SelectionGained] = function(button) setFocused(true); reveal(button) end,
		[React.Event.SelectionLost] = function() setFocused(false) end,
		[React.Event.InputBegan] = function(_, input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA then
				if not props.Disabled then animate(0.98, 0.06) end
			end
		end,
		[React.Event.InputEnded] = function() animate(if hovered or focused then 1.015 else 1, 0.1) end,
		[React.Event.Activated] = function()
			if props.Disabled then return end
			UIFeel.Sfx("Click")
			props.OnActivate()
		end,
	}, {
		Fill = e("UIGradient", { Color = ColorSequence.new(tone.Top, tone.Bottom), Rotation = 90 }),
		Scale = e("UIScale", { ref = scaleRef }),
		Corner = e("UICorner", { CornerRadius = UDim.new(0, T.Theme.Radius.Button) }),
		Ink = e("UIStroke", { Color = T.Theme.Ink, Thickness = T.Theme.InkWidth.Button, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		Rail = e("Frame", {
			Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), BackgroundTransparency = 1,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 7) }),
			-- A disabled button never shows the gold rail, so it can't be mistaken for a ready action.
			Line = e("UIStroke", {
				Color = if props.Disabled then T.Theme.Tones.Slate.Rail
					elseif intentTone then (if active or hovered then Color3.new(1, 1, 1) else intentTone.Rail)
					else props.Accent or (if active or hovered or props.Primary then T.Gold else T.Theme.Tones.Slate.Rail),
				Thickness = if active and not props.Disabled then 2.5 else 1.4,
				Transparency = if props.Disabled then 0.45 else 0,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		}),
		Tooltip = if props.Tooltip and (hovered or focused) then e("Frame", { Name = "ActionTooltip", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 0, -8), Size = UDim2.fromOffset(240, 64), BackgroundColor3 = T.Background, BorderSizePixel = 0, ZIndex = 50 }, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Rail = e("UIStroke", { Color = T.Gold, Thickness = 1 }),
			Label = e(C.Text, { Text = props.Tooltip, Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 1, -8), TextSize = 14, ZIndex = 51 }),
		}) else nil,
		Icon = if props.Icon then e("Frame", { Name = "ActionIcon", AnchorPoint = Vector2.new(if props.Text == "" then 0.5 else 0, 0.5), Position = if props.Text == "" then UDim2.fromScale(0.5, 0.5) else UDim2.new(0, 12, 0.5, 0), Size = UDim2.fromOffset(iconSize, iconSize), BackgroundTransparency = 1, ZIndex = 3 }, { Art = e(Icons.Icon, { Name = props.Icon, Size = iconSize, Dim = props.Disabled }) }) else nil,
		Label = e(C.Text, {
			Position = UDim2.fromOffset(if props.Icon and props.Text ~= "" then 46 else 8, 2), Size = UDim2.new(1, if props.Icon and props.Text ~= "" then -54 else -16, 1, -4),
			Text = props.Text, TextSize = 18, FontFace = T.Theme.Fonts.Title,
			TextStrokeColor3 = T.Theme.Ink, TextStrokeTransparency = if props.Disabled then 1 else 0.15,
			TextColor3 = if props.Disabled then T.Muted else T.Text, TextXAlignment = Enum.TextXAlignment.Center,
		}),
	})
end

function C.Currency(props: { Icon: string, Text: string, Position: UDim2 })
	return e("Frame", { Name = props.Icon .. "Chip", Position = props.Position, Size = UDim2.fromOffset(150, 34), BackgroundColor3 = T.Theme.Tones.Deep.Bottom, BorderSizePixel = 0 }, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
		Outline = e("UIStroke", { Color = T.Gold, Thickness = 2 }),
		Icon = e("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(22, 22) }, { Art = e(Icons.Icon, { Name = props.Icon, Size = 22 }) }),
		Value = e(C.Text, { Text = props.Text, FontFace = T.Theme.Fonts.Number, TextSize = 17, Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -44, 1, 0), TextXAlignment = Enum.TextXAlignment.Center }),
	})
end

function C.Badge(props: { Text: string, Color: Color3?, Order: number? })
	return e(C.Text, {
		Text = props.Text, TextSize = 14, TextColor3 = props.Color or T.Muted,
		Size = UDim2.new(1, 0, 0, 24), LayoutOrder = props.Order,
		TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false,
	})
end

function C.StateBadges(props: { Snapshot: Snapshot, Artifact: Artifact, Selected: boolean?, Material: boolean?, Reason: string? })
	local artifact = props.Artifact
	local owners = Model.ownerIds(props.Snapshot, artifact.UUID)
	local equipped = #owners > 0
	local owner = #owners == 1 and props.Snapshot.Heroes[owners[1]] or nil
	local state = if props.Material then "[−] Artifact · consumed" elseif props.Selected then "[✓] Selected" else nil
	return e(C.Stack, { Children = {
		Owner = e("Frame", { Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1, LayoutOrder = 1 }, {
			Portrait = if owner then e("Frame", { Position = UDim2.fromOffset(0, 8), Size = UDim2.fromOffset(24, 32), BackgroundTransparency = 1 }, { Image = e(Portrait, { TemplateId = owner.TemplateId, Archetype = owner.Archetype, Stars = owner.Stars }) }) else nil,
			Label = e(C.Text, {
				Text = if owner then string.format("[E] %s · #%s\nEquipped", owner.DisplayName, string.sub(owner.UUID, -4)) elseif equipped then "[E] Equipped\nSync required" else "[—] Unequipped",
				Position = UDim2.fromOffset(if owner then 28 else 0, 0), Size = UDim2.new(1, if owner then -28 else 0, 1, 0),
				TextSize = 14, TextColor3 = if equipped then T.Equipped else T.Muted,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
		}),
		Protection = e(C.Badge, {
			Text = if artifact.Locked then "[L] Locked" elseif equipped then "[P] Protected" else "[U] Unlocked",
			Color = if artifact.Locked or equipped then T.Gold else T.Muted, Order = 2,
		}),
		Selection = if state then e(C.Badge, { Text = state, Color = if props.Material then T.Bad else T.Selected, Order = 3 }) else nil,
		Reason = if props.Reason then e(C.Text, { Text = props.Reason, TextSize = 14, TextColor3 = T.Muted, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 4 }) else nil,
	} })
end

function C.Preview(props: { Artifact: Artifact, Size: UDim2?, Order: number? })
	local ref = React.useRef(nil)
	React.useEffect(function()
		local host = ref.current
		if not host then return end
		local shown = ArtifactPreview.Show(host, props.Artifact.TemplateId)
		local fallback = host:FindFirstChild("Fallback")
		if fallback then fallback.Visible = not shown end
		return function()
			local view = host:FindFirstChild("ArtifactModelPreview")
			if view then view:Destroy() end
		end
	end, { props.Artifact.TemplateId })
	return e("Frame", {
		ref = ref, Size = props.Size or UDim2.new(1, 0, 0, 112), LayoutOrder = props.Order,
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
		Fill = e("UIGradient", { Color = ColorSequence.new(Catalog.GetRarityInfo(props.Artifact.Rarity).Color:Lerp(T.Background, 0.65), T.Background), Rotation = 90 }),
		Halo = e("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.58, 0.72), BackgroundTransparency = 1, Rotation = 45 }, {
			Aspect = e("UIAspectRatioConstraint", { AspectRatio = 1 }),
			Line = e("UIStroke", { Color = Catalog.GetRarityInfo(props.Artifact.Rarity).Color, Thickness = 2, Transparency = 0.65 }),
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
		}),
		Fallback = e(C.Text, { Name = "Fallback", Size = UDim2.fromScale(1, 1), Text = props.Artifact.Type, TextXAlignment = Enum.TextXAlignment.Center }),
	})
end

type HeroSlotProps = { Snapshot: Snapshot, Hero: Hero, Selected: boolean, OnSelect: () -> (), Order: number, Compatible: boolean?, Busy: boolean? }
function C.HeroSlot(props: HeroSlotProps)
	local hero = props.Hero
	local artifact = hero.EquippedArtifactUUID and props.Snapshot.Artifacts[hero.EquippedArtifactUUID]
	local available = props.Compatible ~= false
	local deployedSlot = Model.deployedSlot(hero)
	return e("Frame", { Name = "HeroCard_" .. hero.UUID, BackgroundTransparency = 1, Size = UDim2.fromOffset(196, 286), LayoutOrder = props.Order + (if available then 0 else 10000) }, {
		Button = e(C.Button, { Text = "", Selected = props.Selected, Disabled = props.Busy or not available, OnActivate = props.OnSelect, Size = UDim2.fromScale(1, 1), Name = "Hero_" .. hero.UUID, FocusOrder = props.Order }),
		Content = e("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 1, -20), ZIndex = 2 }, {
			Portrait = e("Frame", { Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 116), BackgroundColor3 = T.Background, BorderSizePixel = 0 }, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Image = e(Portrait, { TemplateId = hero.TemplateId, Archetype = hero.Archetype, Stars = hero.Stars, Dark = not available }),
			}),
			Power = e(C.Text, { Text = string.format("%.0f PWR", Model.heroPower(props.Snapshot, hero)), TextSize = 14, TextColor3 = T.Gold, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 92), Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = T.Background, BackgroundTransparency = 0.12, ZIndex = 5 }),
			Deployment = e(C.Text, { Name = "DeploymentBadge", Text = if deployedSlot then "DEPLOYED · SLOT " .. deployedSlot else "UNDEPLOYED", TextSize = 12, TextColor3 = if deployedSlot then T.Equipped else T.Muted, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 0.12, BackgroundColor3 = T.Background, ZIndex = 5 }),
			Name = e(C.Text, { Text = hero.DisplayName, TextColor3 = if available then T.Gold else T.Muted, Position = UDim2.fromOffset(0, 120), Size = UDim2.new(1, 0, 0, 28), TextSize = 18, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Center }),
			Rank = e(C.Text, { Text = string.format("Lv.%d · %s", hero.Level, string.rep("★", hero.Stars)), Position = UDim2.fromOffset(0, 148), Size = UDim2.new(1, 0, 0, 24), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center }),
			Class = e(C.Text, { Text = hero.Archetype .. " · #" .. string.sub(hero.UUID, -4), Position = UDim2.fromOffset(0, 172), Size = UDim2.new(1, 0, 0, 22), TextSize = 12, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Center }),
			Weapon = e(C.Text, { Text = if artifact then "Current: " .. artifact.DisplayName else "Empty weapon slot", Position = UDim2.fromOffset(0, 196), Size = UDim2.new(1, 0, 0, 36), TextSize = 13, TextColor3 = if artifact then T.Equipped else T.Muted, TextXAlignment = Enum.TextXAlignment.Center }),
			Action = e(C.Text, { Text = if not available then "INCOMPATIBLE" elseif artifact then "REPLACE WEAPON" else "EQUIP", Position = UDim2.fromOffset(0, 236), Size = UDim2.new(1, 0, 0, 28), TextSize = 14, TextColor3 = if available then T.Gold else T.Muted, TextXAlignment = Enum.TextXAlignment.Center }),
		}),
	})
end

-- `Square` lays out square cells (artifact tiles keep a 1:1 aspect): about `SquareSize` px, as many
-- columns as fit, centred, with even gaps. Without it, cells are 1/columns wide and CellHeight tall.
function C.CardGrid(props: { Children: { [string]: any }, Size: UDim2, Position: UDim2?, CellHeight: number?, Square: boolean?, SquareSize: number? })
	local columns, setColumns = React.useState(4)
	local width, setWidth = React.useState(600)
	local children = table.clone(props.Children)
	local gap = 10
	local cellSize: UDim2
	if props.Square then
		local target = props.SquareSize or 140
		local cols = math.max(1, math.floor((width - 8 + gap) / (target + gap)))
		local cell = math.floor(math.min(target * 1.25, (width - 8 - gap * (cols - 1)) / cols))
		cellSize = UDim2.fromOffset(cell, cell)
	else
		cellSize = UDim2.new(1 / columns, -10, 0, props.CellHeight or 110)
	end
	children.Layout = e("UIGridLayout", {
		CellSize = cellSize, CellPadding = UDim2.fromOffset(gap, gap), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = if props.Square then Enum.HorizontalAlignment.Center else Enum.HorizontalAlignment.Left,
	})
	children.Padding = e("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8) })
	return e("ScrollingFrame", { Name = "CardGrid", Size = props.Size, Position = props.Position, BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 6, ScrollBarImageColor3 = T.Gold, ClipsDescendants = true, SelectionGroup = true,
		[React.Change.AbsoluteSize] = function(frame)
			setColumns(math.clamp(math.floor(frame.AbsoluteSize.X / 106), 2, 6))
			setWidth(frame.AbsoluteWindowSize.X)
		end,
	}, children)
end

--============================================================================
-- STAT CHIP & COMPACT ACTION ICONS (Reference Layout)
--============================================================================
function C.StatChip(props: { Label: string, Value: string, Order: number?, Color: Color3? })
	return e("Frame", {
		Name = "StatChip_" .. props.Label,
		Size = UDim2.new(0.31, 0, 0, 46),
		BackgroundColor3 = T.Theme.Tones.Deep.Top,
		BorderSizePixel = 0,
		LayoutOrder = props.Order,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
		Stroke = e("UIStroke", { Color = T.Theme.Tones.Deep.Rail, Thickness = 1, Transparency = 0.45 }),
		Title = e(C.Text, {
			Text = props.Label,
			TextSize = 13,
			TextColor3 = T.Muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.new(0, 2, 0, 4),
			Size = UDim2.new(1, -4, 0, 14),
		}),
		Val = e(C.Text, {
			Text = props.Value,
			TextSize = 14,
			FontFace = T.Theme.Fonts.Number,
			TextColor3 = props.Color or T.Text,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.new(0, 2, 0, 18),
			Size = UDim2.new(1, -4, 0, 24),
		}),
	})
end

function C.IconAction(props: {
	Icon: string,
	Label: string,
	OnActivate: () -> (),
	Size: UDim2?,
	Disabled: boolean?,
	Selected: boolean?,
	Accent: Color3?,
	Order: number?,
})
	local hovered, setHovered = React.useState(false)
	return e("TextButton", {
		Name = "Action_" .. props.Label,
		Text = "",
		Size = props.Size or UDim2.fromOffset(56, 52),
		BackgroundColor3 = if props.Selected then T.Theme.Tones.Gold.Bottom else T.Theme.Tones.Deep.Bottom,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Selectable = not props.Disabled,
		Active = not props.Disabled,
		LayoutOrder = props.Order,
		[React.Event.MouseEnter] = function() setHovered(true) end,
		[React.Event.MouseLeave] = function() setHovered(false) end,
		[React.Event.Activated] = function()
			if not props.Disabled then
				UIFeel.Sfx("Click")
				props.OnActivate()
			end
		end,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
		Stroke = e("UIStroke", {
			Color = props.Accent or (if props.Selected then T.Gold elseif hovered then T.Gold else T.Theme.Tones.Deep.Rail),
			Thickness = if props.Selected or hovered then 1.8 else 1,
			Transparency = if props.Selected or hovered then 0 else 0.4,
		}),
		Icon = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 5),
			Size = UDim2.fromOffset(22, 22),
			BackgroundTransparency = 1,
		}, {
			Art = e(Icons.Icon, { Name = props.Icon, Size = 22, Dim = props.Disabled }),
		}),
		Label = e(C.Text, {
			Text = props.Label,
			TextSize = 13,
			TextColor3 = if props.Disabled then T.Muted elseif props.Selected then T.Gold else T.Text,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.new(0, 2, 0, 28),
			Size = UDim2.new(1, -4, 0, 20),
		}),
	})
end

--============================================================================
-- CONFIRM MODAL (Selling Rare or better artifacts)
--============================================================================
function C.ConfirmModal(props: {
	Title: string,
	Message: string,
	TotalGold: number?,
	ConfirmText: string,
	CancelText: string,
	OnConfirm: () -> (),
	OnCancel: () -> (),
})
	local ref = React.useRef(nil)
	React.useEffect(function()
		if ref.current and UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then
			GuiService:Select(ref.current)
		end
	end, {})

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 250,
	}, {
		Shade = e("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(),
			BackgroundTransparency = 0.35,
			Text = "",
			AutoButtonColor = false,
			Selectable = false,
			ZIndex = 1,
			[React.Event.Activated] = props.OnCancel,
		}),
		Dialog = e("Frame", {
			ref = ref,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(450, 260),
			BackgroundColor3 = T.Background,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 14) }),
			Outline = e("UIStroke", { Color = T.Bad, Thickness = 2.4 }),
			WarningIcon = e("Frame", {
				Position = UDim2.fromOffset(18, 16),
				Size = UDim2.fromOffset(32, 32),
				BackgroundTransparency = 1,
			}, {
				Art = e(Icons.Icon, { Name = "Warning", Size = 32 }),
			}),
			Title = e(C.Text, {
				Text = props.Title,
				TextColor3 = T.Bad,
				TextSize = 20,
				Position = UDim2.fromOffset(58, 18),
				Size = UDim2.new(1, -74, 0, 28),
			}),
			Message = e(C.Text, {
				Text = props.Message,
				TextColor3 = T.Text,
				TextSize = 14,
				Position = UDim2.fromOffset(20, 56),
				Size = UDim2.new(1, -40, 0, 68),
			}),
			GoldNotice = if props.TotalGold then e(C.Text, {
				Text = string.format("You will receive +%s Gold. This cannot be undone.", Balance.Format(props.TotalGold)),
				TextColor3 = T.Gold,
				FontFace = T.Theme.Fonts.Number,
				TextSize = 15,
				Position = UDim2.fromOffset(20, 130),
				Size = UDim2.new(1, -40, 0, 28),
			}) else nil,
			Actions = e("Frame", {
				Position = UDim2.new(0, 20, 1, -64),
				Size = UDim2.new(1, -40, 0, 48),
				BackgroundTransparency = 1,
			}, {
				Cancel = e(C.Button, {
					Text = props.CancelText,
					Size = UDim2.new(0.48, -4, 1, 0),
					Position = UDim2.fromScale(0, 0),
					OnActivate = props.OnCancel,
				}),
				Confirm = e(C.Button, {
					Text = props.ConfirmText,
					Size = UDim2.new(0.48, -4, 1, 0),
					Position = UDim2.new(0.52, 4, 0, 0),
					Primary = true,
					Accent = T.Bad,
					OnActivate = props.OnConfirm,
				}),
			}),
		}),
	})
end

--============================================================================
-- ARTIFACT TILE (Image-first, square card from reference)
--============================================================================
export type TileProps = {
	Snapshot: Snapshot,
	Artifact: Artifact,
	Selected: boolean,
	Material: boolean?,
	Checked: boolean?,
	Protected: boolean?,
	Reason: string?,
	OnSelect: () -> (),
	Order: number,
	ShowPreview: boolean?,
	UpgradeChoice: boolean?,
	SellMode: boolean?,
}

function C.ArtifactTile(props: TileProps)
	local artifact = props.Artifact
	local rarity = Catalog.GetRarityInfo(artifact.Rarity)
	local owners = Model.ownerIds(props.Snapshot, artifact.UUID)
	local equipped = #owners > 0
	local isProtected = props.Protected or (props.SellMode and (equipped or artifact.Locked))
	local isNotUsable = props.UpgradeChoice and (equipped or artifact.Locked)
	local isChecked = props.Checked or props.Material
	local hovered, setHovered = React.useState(false)
	local focused, setFocused = React.useState(false)
	local previewHostRef = React.useRef(nil)

	-- The border always carries the rarity (or selection state); "equipped" is the owner badge in the
	-- corner, never a border colour (an Exalted weapon used to show a teal border once equipped).
	local accent = if props.Selected then T.Gold
		elseif isChecked then T.Bad
		elseif isProtected then T.Theme.Tones.Slate.Rail
		else rarity.Color
	local owner = if equipped then props.Snapshot.Heroes[owners[1]] else nil

	React.useEffect(function()
		local host = previewHostRef.current
		if not host or props.ShowPreview == false then return end
		ArtifactPreview.Show(host, artifact.TemplateId)
		return function()
			local current = host:FindFirstChild("ArtifactModelPreview")
			if current then current:Destroy() end
		end
	end, { artifact.TemplateId, props.ShowPreview })

	local powerText = Balance.Format(Model.power(artifact))

	return e("Frame", {
		Name = "Tile_" .. artifact.UUID,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		LayoutOrder = props.Order,
	}, {
		Aspect = e("UIAspectRatioConstraint", { AspectRatio = 1 }),
		Button = e("TextButton", {
			Name = "TileButton",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 0,
			BackgroundColor3 = Color3.fromRGB(16, 12, 24),
			Text = "",
			AutoButtonColor = false,
			Selectable = not isProtected and not isNotUsable,
			Active = true,
			SelectionOrder = 100 + props.Order,
			[React.Event.MouseEnter] = function() setHovered(true) end,
			[React.Event.MouseLeave] = function() setHovered(false) end,
			[React.Event.SelectionGained] = function(b) setFocused(true); reveal(b) end,
			[React.Event.SelectionLost] = function() setFocused(false) end,
			[React.Event.Activated] = function()
				if isProtected or isNotUsable then
					UIFeel.Sfx("Error")
					return
				end
				UIFeel.Sfx("Click")
				props.OnSelect()
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
			-- Brighter Grimoire: a rarity-tinted fill instead of near-black.
			Gradient = e("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, rarity.Color:Lerp(Color3.fromRGB(30, 22, 44), 0.42)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(26, 18, 40)),
				}),
				Rotation = 90,
			}),
			Stroke = e("UIStroke", {
				Color = accent,
				Thickness = if props.Selected then 3 elseif isChecked then 2.6 else 2,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			-- 3D model between the label band and the power line, so text never sits on the art.
			ModelHost = e("Frame", {
				ref = previewHostRef,
				Name = "ModelHost",
				Position = UDim2.fromOffset(0, 20),
				Size = UDim2.new(1, 0, 1, -42),
				BackgroundTransparency = 1,
				ZIndex = 2,
				ClipsDescendants = true,
			}),
			-- Top band: lock on the left; rarity and stars on the right, on a dark strip for contrast.
			TopBand = e("Frame", {
				Name = "TopBand",
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundColor3 = Color3.fromRGB(10, 6, 14),
				BackgroundTransparency = 0.35,
				ZIndex = 4,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
				Lock = if artifact.Locked then e("Frame", {
					Position = UDim2.fromOffset(5, 2),
					Size = UDim2.fromOffset(16, 16),
					BackgroundTransparency = 1,
					ZIndex = 5,
				}, {
					Icon = e(Icons.Icon, { Name = "Lock", Size = 16 }),
				}) else nil,
				Label = e(C.Text, {
					Text = string.format("%s  <font color=\"#FFD678\">★%d</font>", rarity.Name, artifact.Star),
					RichText = true, -- catalog rarity names only, never player text
					TextSize = 13,
					TextColor3 = rarity.Color,
					FontFace = T.Theme.Fonts.Title,
					TextXAlignment = Enum.TextXAlignment.Right,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -6, 0, 1),
					Size = UDim2.new(1, -26, 1, -2),
					ZIndex = 5,
				}),
			}),
			-- Bottom: power, and the owner's portrait when equipped.
			BottomLeft = e("Frame", {
				Name = "BottomLeftPower",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 6, 1, -3),
				Size = UDim2.new(1, -36, 0, 20),
				BackgroundTransparency = 1,
				ZIndex = 4,
			}, {
				Power = e(C.Text, {
					Text = "⚔ " .. powerText,
					TextSize = 15,
					FontFace = T.Theme.Fonts.Number,
					TextColor3 = Color3.fromRGB(255, 230, 140),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextStrokeColor3 = T.Theme.Ink,
					TextStrokeTransparency = 0.2,
					Size = UDim2.fromScale(1, 1),
				}),
			}),
			OwnerBadge = if owner then e("Frame", {
				Name = "OwnerBadge",
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -4, 1, -4),
				Size = UDim2.fromOffset(26, 26),
				BackgroundColor3 = Color3.fromRGB(14, 10, 22),
				ClipsDescendants = true,
				ZIndex = 5,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Ring = e("UIStroke", { Color = T.Equipped, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
				Face = e(Portrait, { TemplateId = owner.TemplateId, Archetype = owner.Archetype, Stars = owner.Stars }),
			}) else nil,
			-- Checked badge in center when selected for sale or upgrade
			CheckedBadge = if isChecked then e("Frame", {
				Name = "CheckedBadge",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(30, 30),
				BackgroundColor3 = Color3.fromRGB(20, 14, 28),
				BackgroundTransparency = 0.2,
				ZIndex = 6,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Stroke = e("UIStroke", { Color = if props.Material then T.Bad else T.Good, Thickness = 2 }),
				Icon = e("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(20, 20),
					BackgroundTransparency = 1,
				}, {
					Art = e(Icons.Icon, { Name = "Check", Size = 20 }),
				}),
			}) else nil,
			-- Protected or Not Usable overlay
			ProtectedOverlay = if isProtected or isNotUsable then e("Frame", {
				Name = "ProtectedOverlay",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 0.55,
				ZIndex = 8,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
				LockIcon = e("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(24, 24),
					BackgroundTransparency = 1,
				}, {
					Art = e(Icons.Icon, { Name = "Lock", Size = 24 }),
				}),
			}) else nil,
		}),
	})
end

-- Backward compatibility alias
C.ArtifactCard = C.ArtifactTile

--============================================================================
-- INVENTORY GRID (Square responsive tiles)
--============================================================================
type GridProps = {
	Snapshot: Snapshot,
	Items: { Artifact },
	TargetId: string?,
	MaterialIds: { string }?,
	MaterialMode: boolean?,
	HeroId: string?,
	Width: number,
	OnSelect: (id: string) -> (),
	FilterKey: string?,
	Page: number?,
	OnPage: ((page: number) -> ())?,
	SellMode: boolean?,
	CheckedIds: { [string]: boolean }?,
}

function C.InventoryGrid(props: GridProps)
	local tileSize = T.TileSize or 104
	local tileGap = T.TileGap or 8
	local columns = math.max(1, math.floor((props.Width - 16 + tileGap) / (tileSize + tileGap)))
	local cellWidth = math.max(80, math.floor((props.Width - 16 - tileGap * (columns - 1)) / columns))
	local ref = React.useRef(nil)
	local view, setView = React.useState({ Row = 0, Height = 340 })
	local best = Model.best(props.Snapshot, props.HeroId)

	local function observe(scroll: ScrollingFrame)
		local row = math.floor(scroll.CanvasPosition.Y / (cellWidth + tileGap))
		local height = scroll.AbsoluteWindowSize.Y
		setView(function(previous)
			return if previous.Row == row and previous.Height == height then previous else { Row = row, Height = height }
		end)
	end

	local children: { [string]: any } = {
		Layout = e("UIGridLayout", {
			CellSize = UDim2.fromOffset(cellWidth, cellWidth),
			CellPadding = UDim2.fromOffset(tileGap, tileGap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingLeft = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 8),
		}),
	}

	local visibleRows = math.max(1, math.ceil(view.Height / (cellWidth + tileGap)))
	for index, artifact in props.Items do
		local row = math.floor((index - 1) / columns)
		local isChecked = if props.SellMode then (props.CheckedIds and props.CheckedIds[artifact.UUID] == true)
			elseif props.MaterialIds then (table.find(props.MaterialIds, artifact.UUID) ~= nil)
			else false

		children[artifact.UUID] = e(C.ArtifactTile, {
			Snapshot = props.Snapshot,
			Artifact = artifact,
			Selected = props.TargetId == artifact.UUID,
			Material = props.MaterialMode and isChecked,
			Checked = props.SellMode and isChecked,
			SellMode = props.SellMode,
			Reason = if props.MaterialMode then Model.materialReason(props.Snapshot, props.TargetId, artifact.UUID) else nil,
			OnSelect = function() props.OnSelect(artifact.UUID) end,
			Order = index,
			ShowPreview = row >= view.Row - 1 and row <= view.Row + visibleRows,
		})
	end

	React.useEffect(function()
		if ref.current then ref.current.CanvasPosition = Vector2.zero end
	end, { props.FilterKey })

	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Grid = e("ScrollingFrame", {
			ref = ref,
			Name = "ArtifactGrid",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = T.Gold,
			SelectionGroup = true,
			ClipsDescendants = true,
			[React.Change.CanvasPosition] = observe,
			[React.Change.AbsoluteWindowSize] = observe,
		}, children),
		Empty = if #props.Items == 0 then e(C.Text, {
			Text = if next(props.Snapshot.Artifacts) == nil then "No artifacts yet. Open Summon to get your first weapon." else "No matching artifacts. Clear your filters to see all owned weapons.",
			Size = UDim2.new(1, -20, 0, 100),
			Position = UDim2.fromOffset(8, 12),
		}) else nil,
	})
end

type StatRowProps = { Label: string, Before: number, After: number, Format: string?, Order: number }
function C.StatRow(props: StatRowProps)
	local delta = props.After - props.Before
	local format = props.Format or "%.0f"
	-- A multiplier's "×" belongs on the values, not the change: "×6.40 → ×9.64 (+3.24)".
	local deltaText = (string.gsub(string.format(format, math.abs(delta)), "^×", ""))
	local changeColor = if delta > 0.00001 then T.Good elseif delta < -0.00001 then T.Bad else T.Muted
	-- Two lines, so it reads in a narrow column: a label, then "before → after" large with the change
	-- on the right (it was one 16 px line that wrapped and then got scaled down with the window).
	return e("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 56), LayoutOrder = props.Order }, {
		Label = e(C.Text, { Text = props.Label, TextSize = 15, FontFace = T.Theme.Fonts.Body, TextColor3 = T.Muted, Size = UDim2.new(1, 0, 0, 20) }),
		Values = e(C.Text, {
			Text = string.format("%s  →  %s", string.format(format, props.Before), string.format(format, props.After)),
			TextSize = 22, FontFace = T.Theme.Fonts.Number, TextColor3 = if math.abs(delta) < 0.00001 then T.Text else changeColor,
			Position = UDim2.fromOffset(0, 22), Size = UDim2.new(0.72, 0, 0, 32), TextWrapped = false,
		}),
		Change = e(C.Text, {
			Text = if math.abs(delta) < 0.00001 then "no change" else string.format("%s%s", if delta > 0 then "+" else "-", deltaText),
			TextSize = if math.abs(delta) < 0.00001 then 15 else 20, FontFace = T.Theme.Fonts.Number, TextColor3 = changeColor,
			TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0.72, 0, 0, 22), Size = UDim2.new(0.28, 0, 0, 32), TextWrapped = false,
		}),
	})
end

function C.ItemSummary(props: { Snapshot: Snapshot, Artifact: Artifact?, Heading: string, Order: number? })
	local artifact = props.Artifact
	return e(C.Stack, { Order = props.Order, Children = {
		Heading = e(C.Text, { Text = props.Heading, TextColor3 = T.Gold, LayoutOrder = 1 }),
		Name = e(C.Text, { Text = if artifact then artifact.DisplayName else "Empty weapon slot", Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 2 }),
		State = if artifact then e("Frame", { Size = UDim2.new(1, 0, 0, 88), BackgroundTransparency = 1, LayoutOrder = 3 }, {
			Badges = e(C.StateBadges, { Snapshot = props.Snapshot, Artifact = artifact }),
		}) else nil,
		FullOwner = if artifact then e(C.Text, { Text = Model.ownerText(props.Snapshot, artifact.UUID), TextSize = 14, TextColor3 = T.Equipped, Size = UDim2.new(1, 0, 0, 52), LayoutOrder = 4 }) else nil,
	} })
end

function C.ComparisonPanel(props: { Snapshot: Snapshot, HeroId: string?, Artifact: Artifact })
	local hero = props.HeroId and props.Snapshot.Heroes[props.HeroId]
	local current = hero and hero.EquippedArtifactUUID and props.Snapshot.Artifacts[hero.EquippedArtifactUUID]
	local before = if current then Catalog.GetStatBreakdown(current.TemplateId, current.Star, current.Rarity) else { Power = 0, DamageMultiplier = 1, ["Attack Speed"] = 0 }
	local after = Catalog.GetStatBreakdown(props.Artifact.TemplateId, props.Artifact.Star, props.Artifact.Rarity)
	local canCompareHero = hero ~= nil and Model.compatible(hero, props.Artifact)
	return e(C.Stack, { Children = {
		Current = e(C.ItemSummary, { Snapshot = props.Snapshot, Artifact = current, Heading = "CURRENT · " .. (if hero then hero.DisplayName else "Choose hero"), Order = 1 }),
		Candidate = e(C.ItemSummary, { Snapshot = props.Snapshot, Artifact = props.Artifact, Heading = "CANDIDATE", Order = 2 }),
		Power = e(C.StatRow, { Label = "Weapon power", Before = before.Power, After = after.Power, Order = 3 }),
		Multiplier = e(C.StatRow, { Label = "Damage multiplier", Before = before.DamageMultiplier, After = after.DamageMultiplier, Format = "×%.2f", Order = 4 }),
		Speed = e(C.StatRow, { Label = "Attack speed bonus (percentage points)", Before = before["Attack Speed"], After = after["Attack Speed"], Format = "%.1f%%", Order = 5 }),
		DPS = if canCompareHero then e(C.StatRow, { Label = "Base hero DPS · no temporary buffs", Before = Stats.GetCombatSnapshot(hero, current).DPS, After = Stats.GetCombatSnapshot(hero, props.Artifact).DPS, Format = "%.1f", Order = 6 }) else e(C.Text, { Text = "Select a compatible hero for a DPS comparison.", TextColor3 = T.Muted, LayoutOrder = 6, Size = UDim2.new(1, 0, 0, 48) }),
	} })
end

function C.UpgradePreviewPanel(props: { Snapshot: Snapshot, Target: Artifact, MaterialIds: { string }, OnRemove: (id: string) -> () })
	local target = props.Target
	local afterTarget = table.clone(target)
	afterTarget.Star = math.min(Catalog.MaxStars, target.Star + 1)
	local before = Catalog.GetStatBreakdown(target.TemplateId, target.Star, target.Rarity)
	local after = Catalog.GetStatBreakdown(target.TemplateId, afterTarget.Star, target.Rarity)
	local rule = Catalog.GetStarPromotionCost(target.Star)
	local owners = Model.ownerIds(props.Snapshot, target.UUID)
	local hero = #owners == 1 and props.Snapshot.Heroes[owners[1]] or nil
	local children: { [string]: any } = {
		Target = e(C.ItemSummary, { Snapshot = props.Snapshot, Artifact = target, Heading = "TARGET · KEPT", Order = 1 }),
		Rank = e(C.Text, { Text = if rule then string.format("%d★ → %d★ · %s rarity stays", target.Star, afterTarget.Star, Catalog.GetRarityInfo(target.Rarity).Name) else "Maximum 7 stars reached", TextColor3 = T.Gold, Size = UDim2.new(1, 0, 0, 48), LayoutOrder = 2 }),
		Power = e(C.StatRow, { Label = "Weapon power", Before = before.Power, After = after.Power, Order = 3 }),
		Damage = e(C.StatRow, { Label = "Damage multiplier", Before = before.DamageMultiplier, After = after.DamageMultiplier, Format = "×%.2f", Order = 4 }),
		Speed = e(C.StatRow, { Label = "Attack speed bonus", Before = before["Attack Speed"], After = after["Attack Speed"], Format = "%.1f%%", Order = 5 }),
		DPS = if hero then e(C.StatRow, { Label = "Owner's base DPS · no temporary buffs", Before = Stats.GetCombatSnapshot(hero, target).DPS, After = Stats.GetCombatSnapshot(hero, afterTarget).DPS, Format = "%.1f", Order = 6 }) else nil,
		Cost = e(C.Text, {
			Text = if rule then string.format("Cost: %d Gold + %d Gems\nBalance after: %d Gold · %d Gems", rule.Gold, rule.Gems, props.Snapshot.Gold - rule.Gold, props.Snapshot.Gems - rule.Gems) else "No further promotion available.",
			Size = UDim2.new(1, 0, 0, 76), TextColor3 = T.Gold, LayoutOrder = 7,
		}),
		Materials = e(C.Text, { Text = string.format("ARTIFACTS · CONSUMED %d/%d", #props.MaterialIds, if rule then rule.Donors else 0), LayoutOrder = 8 }),
		Warning = e(C.Text, { Text = "Selected artifacts are permanently consumed. Equipped and locked items are protected.", TextColor3 = T.Muted, Size = UDim2.new(1, 0, 0, 60), LayoutOrder = 9 }),
	}
	for index, id in props.MaterialIds do
		local artifact = props.Snapshot.Artifacts[id]
		if artifact then
			children[id] = e(C.Button, {
				Text = string.format("Remove · %s · %d★", artifact.DisplayName, artifact.Star),
				OnActivate = function() props.OnRemove(id) end, Order = 10 + index,
			})
		end
	end
	return e(C.Stack, { Children = children })
end

function C.ActionFlow(props: { Label: string, Reason: string?, Busy: boolean, OnActivate: () -> (), Order: number? })
	return e(C.Stack, { Order = props.Order, Children = {
		Reason = e(C.Text, { Text = props.Reason or "Ready", TextColor3 = if props.Reason then T.Muted else T.Good, TextSize = 14, Size = UDim2.new(1, 0, 0, 48), LayoutOrder = 1 }),
		Action = e(C.Button, { Text = if props.Busy then "Waiting for server…" else props.Label, Primary = true, Disabled = props.Busy or props.Reason ~= nil, OnActivate = props.OnActivate, Order = 2 }),
	} })
end

return C
