--!strict
-- Install this folder under StarterPlayerScripts/UI. Reuses the existing theme and previews.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local React = require(ReplicatedStorage.Packages.React)
local Catalog = require(ReplicatedStorage.Shared.Config.ArtifactCatalog)
local Stats = require(ReplicatedStorage.Shared.Util.StatFormulas)
local Portrait = require(script.Parent.Parent.Hud.Portrait)
local ArtifactPreview = require(script.Parent.Parent.ArtifactPreview)
local UIFeel = require(script.Parent.Parent.UIFeel)
local Model = require(script.Parent.Model)
local T = require(script.Parent.Tokens)
local Types = require(script.Parent.Types)
type Artifact = Types.Artifact
type Hero = Types.Hero
type Snapshot = Types.Snapshot
local e = React.createElement
local C = {}

function C.Text(props: { [string]: any })
	local result: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = T.Theme.Fonts.Body,
		TextSize = T.Body,
		TextColor3 = T.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		RichText = false, -- names are always plain text
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 32),
	}
	for key, value in props do result[key] = value end
	return e("TextLabel", result)
end

function C.Stack(props: { Size: UDim2?, Position: UDim2?, Order: number?, Children: { [string]: any } })
	local children = table.clone(props.Children)
	children.Layout = e("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	return e("Frame", {
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.new(1, 0, 0, 0),
		AutomaticSize = if props.Size then Enum.AutomaticSize.None else Enum.AutomaticSize.Y,
		Position = props.Position,
		LayoutOrder = props.Order,
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
	Disabled: boolean?, Primary: boolean?, Selected: boolean?,
	FocusOrder: number?, Ref: any?,
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
		animate(if not props.Disabled and (hovered or focused) then 1.015 else 1, 0.12)
		return function() if tweenRef.current then tweenRef.current:Cancel() end end
	end, { hovered, focused, props.Disabled })
	local active = props.Selected or focused
	local tone = if props.Disabled then T.Theme.Tones.Slate elseif props.Primary then T.Theme.Tones.Bronze else T.Theme.Tones.Deep
	return e("TextButton", {
		ref = props.Ref,
		Name = props.Name or "Action",
		Size = props.Size or UDim2.new(1, 0, 0, T.Touch), Position = props.Position,
		LayoutOrder = props.Order, Text = "", AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0, Selectable = true, Active = true,
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
			Line = e("UIStroke", { Color = if active then T.Selected elseif hovered or props.Primary then T.Gold else T.Muted, Thickness = if active then 2.5 else 1.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		}),
		Label = e(C.Text, {
			Position = UDim2.fromOffset(8, 2), Size = UDim2.new(1, -16, 1, -4),
			Text = props.Text, TextSize = 14, FontFace = T.Theme.Fonts.Title,
			TextColor3 = if props.Disabled then T.Muted else T.Text, TextXAlignment = Enum.TextXAlignment.Center,
		}),
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
	local state = if props.Material then "[−] Material · consumed" elseif props.Selected then "[✓] Selected" else nil
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
		BackgroundColor3 = T.Background, BorderSizePixel = 0,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
		Fallback = e(C.Text, { Name = "Fallback", Size = UDim2.fromScale(1, 1), Text = props.Artifact.Type, TextXAlignment = Enum.TextXAlignment.Center }),
	})
end

type HeroSlotProps = { Snapshot: Snapshot, Hero: Hero, Selected: boolean, OnSelect: () -> (), Order: number }
function C.HeroSlot(props: HeroSlotProps)
	local hero = props.Hero
	local artifact = hero.EquippedArtifactUUID and props.Snapshot.Artifacts[hero.EquippedArtifactUUID]
	return e("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 112), LayoutOrder = props.Order }, {
		Button = e(C.Button, { Text = "", Selected = props.Selected, OnActivate = props.OnSelect, Size = UDim2.fromScale(1, 1), Name = "Hero_" .. hero.UUID, FocusOrder = props.Order }),
		Portrait = e("Frame", { Active = false, Position = UDim2.fromOffset(10, 16), Size = UDim2.fromOffset(48, 64), BackgroundTransparency = 1 }, {
			Image = e(Portrait, { TemplateId = hero.TemplateId, Archetype = hero.Archetype, Stars = hero.Stars }),
		}),
		Name = e(C.Text, { Text = Model.heroLabel(hero), Position = UDim2.fromOffset(68, 8), Size = UDim2.new(1, -80, 0, 52), TextSize = 14 }),
		Slot = e(C.Text, {
			Text = if artifact then "[E] " .. artifact.DisplayName else "[—] Empty weapon slot",
			TextColor3 = if artifact then T.Equipped else T.Muted, TextSize = 14,
			Position = UDim2.fromOffset(68, 62), Size = UDim2.new(1, -80, 0, 42),
		}),
	})
end

type CardProps = {
	Snapshot: Snapshot, Artifact: Artifact, Selected: boolean, Material: boolean,
	Recommended: boolean, Reason: string?, OnSelect: () -> (), Order: number,
}
function C.ArtifactCard(props: CardProps)
	local artifact = props.Artifact
	local rarity = Catalog.GetRarityInfo(artifact.Rarity)
	return e("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(T.CardWidth, T.CardHeight), LayoutOrder = props.Order }, {
		Button = e(C.Button, { Text = "", Selected = props.Selected or props.Material, OnActivate = props.OnSelect, Size = UDim2.fromScale(1, 1), Name = "Artifact_" .. artifact.UUID, FocusOrder = 100 + props.Order }),
		RarityRail = e("Frame", { Position = UDim2.fromOffset(5, 12), Size = UDim2.new(0, 3, 1, -24), BackgroundColor3 = rarity.Color, BorderSizePixel = 0 }),
		Content = e(C.Stack, { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -26, 1, -16), Children = {
			Name = e(C.Text, { Text = artifact.DisplayName, Size = UDim2.new(1, 0, 0, 38), TextSize = 14, LayoutOrder = 1 }),
			Preview = e(C.Preview, { Artifact = artifact, Size = UDim2.new(1, 0, 0, 54), Order = 2 }),
			Rarity = e(C.Text, { Text = string.format("%s · %d★ · %.0f PWR", rarity.Name, artifact.Star, Model.power(artifact)), TextSize = 14, Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 3 }),
			State = e("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 112), LayoutOrder = 4 }, {
				Badges = e(C.StateBadges, { Snapshot = props.Snapshot, Artifact = artifact, Selected = props.Selected, Material = props.Material }),
			}),
			Note = e(C.Text, { Text = props.Reason or (if props.Recommended then "[↑] Best for hero" else "Tap to inspect"), TextSize = 14, TextColor3 = if props.Reason then T.Muted elseif props.Recommended then T.Good else T.Muted, Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 5 }),
		} }),
	})
end

type GridProps = {
	Snapshot: Snapshot, Items: { Artifact }, TargetId: string?, MaterialIds: { string },
	MaterialMode: boolean, HeroId: string?, Width: number, OnSelect: (id: string) -> (),
	Page: number, OnPage: (page: number) -> (),
}
function C.InventoryGrid(props: GridProps)
	local columns = math.max(1, math.floor((props.Width + T.Gap) / (T.CardWidth + T.Gap)))
	local pages = math.max(1, math.ceil(#props.Items / T.PageSize))
	local page = math.clamp(props.Page, 1, pages)
	local ref = React.useRef(nil)
	local best = Model.best(props.Snapshot, props.HeroId)
	local children: { [string]: any } = {
		Layout = e("UIGridLayout", {
			CellSize = UDim2.new(1 / columns, -(T.Gap * (columns - 1) + 16) / columns, 0, T.CardHeight),
			CellPadding = UDim2.fromOffset(T.Gap, T.Gap), SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Padding = e("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8) }),
	}
	for index = (page - 1) * T.PageSize + 1, math.min(page * T.PageSize, #props.Items) do
		local artifact = props.Items[index]
		children[artifact.UUID] = e(C.ArtifactCard, {
			Snapshot = props.Snapshot, Artifact = artifact, Selected = props.TargetId == artifact.UUID,
			Material = table.find(props.MaterialIds, artifact.UUID) ~= nil, Recommended = best == artifact.UUID,
			Reason = if props.MaterialMode then Model.materialReason(props.Snapshot, props.TargetId, artifact.UUID) else nil,
			OnSelect = function() props.OnSelect(artifact.UUID) end, Order = index,
		})
	end
	React.useEffect(function()
		if ref.current then ref.current.CanvasPosition = Vector2.zero end
	end, { page })
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Grid = e("ScrollingFrame", {
			ref = ref, Size = UDim2.new(1, 0, 1, -60), BackgroundTransparency = 1, BorderSizePixel = 0,
			AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
			ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 6,
			ScrollBarImageColor3 = T.Gold, SelectionGroup = true, ClipsDescendants = true,
		}, children),
		Empty = if #props.Items == 0 then e(C.Text, { Text = if next(props.Snapshot.Artifacts) == nil then "No artifacts owned yet. Summon an artifact at the Forge to begin." else "No artifacts match. Clear filters to see all owned artifacts.", Size = UDim2.new(1, -20, 0, 100), Position = UDim2.fromOffset(8, 12) }) else nil,
		Previous = e(C.Button, { Text = "Previous", Position = UDim2.new(0, 4, 1, -52), Size = UDim2.new(0.3, -8, 0, 48), Disabled = page <= 1, OnActivate = function() props.OnPage(page - 1) end, FocusOrder = 800 }),
		Page = e(C.Text, { Text = string.format("%d/%d · %d items", page, pages, #props.Items), Position = UDim2.new(0.3, 0, 1, -52), Size = UDim2.new(0.4, 0, 0, 48), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center }),
		Next = e(C.Button, { Text = "Next", Position = UDim2.new(0.7, 4, 1, -52), Size = UDim2.new(0.3, -8, 0, 48), Disabled = page >= pages, OnActivate = function() props.OnPage(page + 1) end, FocusOrder = 801 }),
	})
end

type StatRowProps = { Label: string, Before: number, After: number, Format: string?, Order: number }
function C.StatRow(props: StatRowProps)
	local delta = props.After - props.Before
	local format = props.Format or "%.0f"
	local direction = if delta > 0.00001 then "↑ +" elseif delta < -0.00001 then "↓ −" else "= "
	return e(C.Stack, { Order = props.Order, Children = {
		Label = e(C.Text, { Text = props.Label, TextSize = 14, TextColor3 = T.Muted, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 1 }),
		Values = e(C.Text, {
			Text = string.format(format, props.Before) .. " → " .. string.format(format, props.After) .. "   " .. direction .. string.format(format, math.abs(delta)),
			TextColor3 = if delta > 0.00001 then T.Good elseif delta < -0.00001 then T.Bad else T.Text,
			Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 2,
		}),
	} })
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
		Materials = e(C.Text, { Text = string.format("MATERIALS · CONSUMED %d/%d", #props.MaterialIds, if rule then rule.Donors else 0), LayoutOrder = 8 }),
		Warning = e(C.Text, { Text = "Selected materials are permanently consumed. Equipped and locked items are protected.", TextColor3 = T.Muted, Size = UDim2.new(1, 0, 0, 60), LayoutOrder = 9 }),
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

-- Pure primary-action presentation shared by equip and promotion.
function C.ActionFlow(props: { Label: string, Reason: string?, Busy: boolean, OnActivate: () -> (), Order: number? })
	return e(C.Stack, { Order = props.Order, Children = {
		Reason = e(C.Text, { Text = props.Reason or "Ready", TextColor3 = if props.Reason then T.Muted else T.Good, TextSize = 14, Size = UDim2.new(1, 0, 0, 48), LayoutOrder = 1 }),
		Action = e(C.Button, { Text = if props.Busy then "Waiting for server…" else props.Label, Primary = true, Disabled = props.Busy or props.Reason ~= nil, OnActivate = props.OnActivate, Order = 2 }),
	} })
end

return C
