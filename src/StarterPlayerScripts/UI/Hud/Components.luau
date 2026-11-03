--!strict
-- StarterPlayerScripts/UI/Hud/Components.luau
-- Phase 5 HUD building blocks (React-lua): rail buttons, the Next Goal card, the Squad Status
-- Card and the Squad Power badge. Pure presentation; data arrives as props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local Portrait = require(script.Parent:WaitForChild("Portrait"))
-- One theme for the whole UI: "Gilded Grimoire" (Shared/Util/GildedGrimoire).
local Grimoire = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("GildedGrimoire"))

local e = React.createElement
local C = Theme.Colors
local L = Theme.Layout

local Components = {}

local G = Theme.Glass

local function reducedMotion(): boolean
	local ok, on = pcall(function() return (GuiService :: any).ReducedMotionEnabled end)
	return ok and on == true
end
Components.ReducedMotion = reducedMotion

local function corner(radius: number)
	return e("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function stroke(color: Color3, thickness: number?, transparency: number?)
	return e("UIStroke", { Color = color, Thickness = thickness or 1, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function text(props: { [string]: any })
	local base = {
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextColor3 = C.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		RichText = true,
	}
	for k, v in props do
		base[k] = v
	end
	return e("TextLabel", base)
end
Components.Text = text
Components.Corner = corner
Components.Stroke = stroke

local function bar(fraction: number, color: Color3, order: number, glow: boolean?)
	return e("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = Color3.fromRGB(40, 36, 52),
		BorderSizePixel = 0,
	}, {
		Corner = corner(3),
		Fill = e("Frame", {
			Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
		}, { Corner = corner(3), Glow = if glow then stroke(Color3.fromRGB(255, 250, 180), 1.5, 0.2) else nil }),
	})
end

--------------------------------------------------------------------------------
-- Rail button: a custom gothic icon (Hud/Icons) with a heavy outlined label overlapping its foot,
-- in the chunky style of the rail reference. Optional badge, key chip and cooldown countdown.
--------------------------------------------------------------------------------
-- Cinzel Decorative at its heaviest weight: gothic, but thick enough to read over the world.
local LABEL_FONT = Grimoire.Fonts.Title
local NUMBER_FONT = Grimoire.Fonts.Number
Components.LabelFont = LABEL_FONT
Components.NumberFont = NUMBER_FONT

-- White-to-gold title text with a thick black outline (the reference's "Store"/"Floors" look).
local function heavyLabel(props: { [string]: any })
	local base: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = LABEL_FONT,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
	}
	for k, v in props do
		if k ~= "Gold" and k ~= "Outline" and k ~= "MaxSize" then base[k] = v end
	end
	return e("TextLabel", base, {
		Limit = e("UITextSizeConstraint", { MaxTextSize = props.MaxSize or 22 }),
		Gradient = if props.Gold ~= false then e("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 240, 196)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(240, 186, 82)),
			}),
			Rotation = 90,
		}) else nil,
		Outline = e("UIStroke", { Color = Color3.fromRGB(10, 6, 14), Thickness = props.Outline or 2.6, LineJoinMode = Enum.LineJoinMode.Round }),
	})
end
Components.HeavyLabel = heavyLabel

function Components.RailButton(props: {
	Icon: string,
	Label: string,
	Accent: Color3,
	Order: number,
	Size: number,
	Badge: number?,
	KeyHint: string?,
	Cooldown: number?, -- seconds left
	CooldownTotal: number?,
	Disabled: boolean?,
	DisabledReason: string?,
	Wiggle: boolean?, -- a short shake every few seconds (the Store button)
	OnActivated: () -> (),
})
	local Icons = require(script.Parent:WaitForChild("Icons"))
	local scaleRef = React.useRef(nil)
	local iconRef = React.useRef(nil)
	React.useEffect(function()
		if not props.Wiggle then return nil end
		local alive = true
		task.spawn(function()
			while alive do
				task.wait(2.6)
				local icon = iconRef.current
				if not alive or not icon then continue end
				-- Shake: quick tilts that settle back to upright.
				for _, angle in { -14, 12, -9, 6, -3, 0 } do
					local tw = TweenService:Create(icon, TweenInfo.new(0.06, Enum.EasingStyle.Sine), { Rotation = angle })
					tw:Play()
					tw.Completed:Wait()
					if not alive then return end
				end
			end
		end)
		return function() alive = false end
	end, { props.Wiggle })
	local remaining = props.Cooldown or 0
	local dim = props.Disabled or remaining > 0
	local size = props.Size
	local labelH = math.floor(size * 0.36)
	local function tween(scale: number, rot: number)
		if scaleRef.current then
			TweenService:Create(scaleRef.current, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = scale }):Play()
		end
	end
	return e("TextButton", {
		LayoutOrder = props.Order,
		Size = UDim2.fromOffset(size + 24, size + math.floor(labelH * 0.55)),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Selectable = true,
		[React.Event.Activated] = function() props.OnActivated() end,
		[React.Event.MouseEnter] = function() tween(1.1, 0) end,
		[React.Event.MouseLeave] = function() tween(1, 0) end,
	}, {
		Scale = e("UIScale", { ref = scaleRef }),
		Icon = e("Frame", { ref = iconRef, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1 }, {
			Art = e(Icons.Icon, { Name = props.Icon, Size = size, Dim = dim }),
		}),
		Label = heavyLabel({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.new(1, 16, 0, labelH),
			Text = props.Label,
			MaxSize = math.floor(labelH * 0.95),
			ZIndex = 4,
			TextTransparency = if dim then 0.25 else 0,
		}),
		Seconds = if remaining > 0 then heavyLabel({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, size * 0.45),
			Size = UDim2.fromOffset(size, size * 0.5),
			FontFace = NUMBER_FONT,
			Text = tostring(math.ceil(remaining)),
			MaxSize = math.floor(size * 0.48),
			Gold = false,
			Outline = 3,
			ZIndex = 6,
		}) else nil,
		-- Key chip (top-left) and badge (top-right), both outlined like the icons.
		Key = if props.KeyHint then e("TextLabel", {
			Position = UDim2.fromOffset(2, -2),
			Size = UDim2.fromOffset(22, 22),
			BackgroundColor3 = Color3.fromRGB(28, 22, 40),
			FontFace = NUMBER_FONT,
			Text = props.KeyHint,
			TextColor3 = Color3.fromRGB(255, 236, 180),
			TextSize = 14,
			ZIndex = 7,
		}, {
			Corner = corner(6),
			Stroke = e("UIStroke", { Color = Color3.fromRGB(255, 236, 180), Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		}) else nil,
		Badge = if props.Badge and props.Badge > 0 then e("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -2, 0, -4),
			Size = UDim2.fromOffset(24, 24),
			BackgroundColor3 = Color3.fromRGB(214, 34, 48),
			FontFace = NUMBER_FONT,
			Text = if props.Badge > 9 then "9+" else tostring(props.Badge),
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 14,
			ZIndex = 7,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Ring = e("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		}) else nil,
	})
end

--------------------------------------------------------------------------------
-- Cartoon-gothic HUD kit (matches the rail buttons): obsidian-violet panels with a thick black
-- outline and a thin gold inner rail, chunky outlined bars, Cinzel body text.
--------------------------------------------------------------------------------
local BODY_FONT = Grimoire.Fonts.Body
Components.BodyFont = BODY_FONT
local INK = Grimoire.Ink

local function abbreviate(n: number): string
	if n >= 1e9 then return string.format("%.2fB", n / 1e9) end
	if n >= 1e6 then return string.format("%.2fM", n / 1e6) end
	local s = tostring(math.floor(n))
	while true do
		local replaced, count = string.gsub(s, "^(-?%d+)(%d%d%d)", "%1,%2")
		s = replaced
		if count == 0 then break end
	end
	return s
end
Components.Abbreviate = abbreviate

-- A panel: gradient fill, thick black outline, inset gold rail. `props` are Frame/TextButton props.
local function panel(props: { [string]: any }, children: { [string]: any }?)
	local inst: { [string]: any } = { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }
	for k, v in props do
		if k ~= "Class" and k ~= "Rail" and k ~= "Radius" and k ~= "Top" and k ~= "Bottom" then inst[k] = v end
	end
	local radius = props.Radius or 12
	local kids: { [string]: any } = {
		Corner = corner(radius),
		Fill = e("UIGradient", { Color = ColorSequence.new(props.Top or Grimoire.Tones.Violet.Top, props.Bottom or Grimoire.Tones.Violet.Bottom), Rotation = 90 }),
		Ink = e("UIStroke", { Color = INK, Thickness = 3, LineJoinMode = Enum.LineJoinMode.Round, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		Rail = e("Frame", { Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), BackgroundTransparency = 1, ZIndex = 1 }, {
			Corner = corner(math.max(2, radius - 3)),
			Stroke = e("UIStroke", { Color = props.Rail or Grimoire.Tones.Violet.Rail, Thickness = 1.4, Transparency = 0.35, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		}),
	}
	for k, v in children or {} do kids[k] = v end
	return e(props.Class or "Frame", inst, kids)
end
Components.Panel = panel

-- Cinzel body text with a light ink outline so it reads over bright scenery.
local function body(props: { [string]: any })
	local base: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = BODY_FONT,
		TextColor3 = Color3.fromRGB(236, 228, 246),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		RichText = true,
		TextStrokeColor3 = INK,
		TextStrokeTransparency = 0.45,
	}
	for k, v in props do base[k] = v end
	return e("TextLabel", base)
end
Components.Body = body

-- Chunky bar: black-outlined track, gradient fill and a top shine.
local function chunkyBar(fraction: number, hi: Color3, lo: Color3, order: number, height: number, glow: boolean?)
	return e("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = Color3.fromRGB(26, 20, 36),
		BorderSizePixel = 0,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Ink = e("UIStroke", { Color = if glow then Color3.fromRGB(255, 240, 160) else INK, Thickness = if glow then 2.2 else 1.8, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		Fill = if fraction > 0 then e("Frame", {
			Size = UDim2.fromScale(math.clamp(fraction, 0.04, 1), 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Grad = e("UIGradient", { Color = ColorSequence.new(hi, lo), Rotation = 90 }),
			Shine = e("Frame", { Position = UDim2.new(0, 3, 0, 1), Size = UDim2.new(1, -6, 0.35, 0), BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.6, BorderSizePixel = 0 }, { Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
		}) else nil,
	})
end

-- An icon from Hud/Icons, positioned freely.
local function icon(name: string, size: number, props: { [string]: any })
	local Icons = require(script.Parent:WaitForChild("Icons"))
	local frame: { [string]: any } = { Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, ZIndex = 4 }
	for k, v in props do
		if k ~= "Flat" then frame[k] = v end
	end
	return e("Frame", frame, { Art = e(Icons.Icon, { Name = name, Size = size, Flat = props.Flat }) })
end
Components.IconAt = icon

--------------------------------------------------------------------------------
-- Clear Glass kit (HUD cards): a dark translucent body, one hairline stroke, 6 px corners, flat
-- icons and Montserrat labels. Text stays opaque; Theme.Glass holds the contrast budget.
--------------------------------------------------------------------------------
local function glass(props: { [string]: any }, children: { [string]: any }?)
	local inst: { [string]: any } = { BackgroundColor3 = G.Base, BackgroundTransparency = G.BaseTransparency, BorderSizePixel = 0 }
	for k, v in props do
		if k ~= "Class" and k ~= "Radius" and k ~= "StrokeRef" then inst[k] = v end
	end
	local kids: { [string]: any } = {
		Corner = corner(props.Radius or G.Radius),
		Stroke = e("UIStroke", { ref = props.StrokeRef, Color = G.Hairline, Transparency = G.HairlineTransparency, Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	}
	for k, v in children or {} do kids[k] = v end
	return e(props.Class or "Frame", inst, kids)
end
Components.Glass = glass

local function glassText(props: { [string]: any })
	local base: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = G.Fonts.Label,
		TextColor3 = G.Text,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		RichText = true,
	}
	for k, v in props do base[k] = v end
	return e("TextLabel", base)
end
Components.GlassText = glassText

-- A slim Clear Glass bar: dark translucent track, hairline border, flat vibrant fill.
local function glassBar(fraction: number, color: Color3, order: number, height: number, glow: boolean?)
	return e("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = G.Base,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
	}, {
		Corner = corner(math.max(2, math.floor(height / 2))),
		Stroke = stroke(G.Hairline, 1, 0.75),
		Fill = if fraction > 0 then e("Frame", {
			Size = UDim2.fromScale(math.clamp(fraction, 0.02, 1), 1),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
		}, {
			Corner = corner(math.max(2, math.floor(height / 2))),
			Glow = if glow then stroke(Color3.fromRGB(255, 250, 180), 1.5, 0.2) else nil,
		}) else nil,
	})
end
Components.GlassBar = glassBar

-- An uppercase section label followed by a hairline rule ("SQUAD POWER ———").
local function sectionLabel(label: string, props: { [string]: any })
	local frame: { [string]: any } = { BackgroundTransparency = 1 }
	for k, v in props do frame[k] = v end
	return e("Frame", frame, {
		Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center }),
		Label = glassText({ LayoutOrder = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), Text = string.upper(label),
			TextTransparency = G.MutedTransparency, TextTruncate = Enum.TextTruncate.None }),
		Rule = e("Frame", { LayoutOrder = 2, Size = UDim2.fromOffset(0, 1), BackgroundColor3 = G.Hairline, BackgroundTransparency = 0.6, BorderSizePixel = 0 }, {
			Flex = e("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
		}),
	})
end
Components.SectionLabel = sectionLabel

-- A +/- change that rises 16 px and fades out over 0.8 s. Give it a new key per change.
local function Floater(props: { Delta: number, Position: UDim2, Size: UDim2, TextSize: number? })
	local ref = React.useRef(nil)
	React.useEffect(function()
		local label = ref.current
		if not label then return end
		local target: { [string]: any } = { TextTransparency = 1, TextStrokeTransparency = 1 }
		if not reducedMotion() then target.Position = props.Position - UDim2.fromOffset(0, 16) end
		TweenService:Create(label, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), target):Play()
	end, {})
	return glassText({
		ref = ref,
		AnchorPoint = Vector2.new(1, 1),
		Position = props.Position,
		Size = props.Size,
		FontFace = G.Fonts.Number,
		TextSize = props.TextSize or 14,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = if props.Delta > 0 then G.Vital else G.Danger,
		TextStrokeColor3 = G.Base,
		TextStrokeTransparency = 0.4,
		ZIndex = 8,
		Text = (if props.Delta > 0 then "+" else "−") .. abbreviate(math.abs(props.Delta)),
	})
end

--------------------------------------------------------------------------------
-- Next Goal card (top-right): a raised header strip ("NEXT GOAL ——— 3/7"), the goal title, its
-- hint and its reward. The stroke flashes Royal when the goal advances.
--------------------------------------------------------------------------------
function Components.NextGoalCard(props: { Goal: any, Top: number? })
	local goal = props.Goal
	local strokeRef = React.useRef(nil)
	local lastIndex = React.useRef(nil :: number?)
	local index = goal and goal.Index
	React.useEffect(function()
		local previous = lastIndex.current
		lastIndex.current = index
		local s = strokeRef.current
		if previous == nil or index == nil or index == previous or not s then return end
		s.Color = G.Royal
		s.Transparency = 0
		s.Thickness = 2
		TweenService:Create(s, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Color = G.Hairline, Transparency = G.HairlineTransparency, Thickness = 1 }):Play()
	end, { index })
	if not goal then return nil end
	-- Reward: "REWARD" then a flat Gold / Gems icon beside each amount.
	local reward: { [string]: any }? = nil
	if type(goal.Reward) == "table" and (goal.Reward.Gold or goal.Reward.Gems) then
		local items: { [string]: any } = {
			Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center }),
			Label = glassText({ LayoutOrder = 0, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), Text = "REWARD ",
				TextTransparency = G.MutedTransparency, TextTruncate = Enum.TextTruncate.None }),
		}
		local order = 1
		for _, kind in { "Gold", "Gems" } do
			local amount = goal.Reward[kind]
			if amount then
				items[kind .. "Icon"] = icon(kind, 14, { LayoutOrder = order, ZIndex = 2, Flat = true })
				items[kind] = glassText({ LayoutOrder = order + 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), FontFace = G.Fonts.Number,
					TextColor3 = G.Royal, TextTruncate = Enum.TextTruncate.None, Text = abbreviate(amount) .. "  " })
				order += 2
			end
		end
		reward = items
	end
	return glass({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -L.Edge, 0, props.Top or L.TopZone),
		Size = UDim2.fromOffset(L.GoalCardWidth, L.GoalCardHeight),
		StrokeRef = strokeRef,
	}, {
		Header = e("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = G.BaseRaised, BackgroundTransparency = G.RaisedTransparency, BorderSizePixel = 0 }, {
			Corner = corner(G.Radius),
			Shade = e("UIGradient", { Transparency = NumberSequence.new(0, 0.08), Rotation = 90 }),
			Icon = icon("Goal", 18, { Position = UDim2.fromOffset(8, 3), Flat = true }),
			Label = sectionLabel("Next Goal", { Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -84, 1, 0) }),
			Step = glassText({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 0), Size = UDim2.fromOffset(44, 24), FontFace = G.Fonts.Number,
				TextXAlignment = Enum.TextXAlignment.Right, Text = string.format("%d/%d", goal.Index or 1, goal.Total or 1) }),
		}),
		Title = glassText({ Position = UDim2.fromOffset(10, 28), Size = UDim2.new(1, -20, 0, 18), FontFace = G.Fonts.Number, TextSize = 15, Text = tostring(goal.Title) }),
		Hint = glassText({ Position = UDim2.fromOffset(10, 47), Size = UDim2.new(1, -20, 0, 15), TextTransparency = G.MutedTransparency, Text = tostring(goal.Description) }),
		Reward = if reward then e("Frame", { Position = UDim2.fromOffset(10, 66), Size = UDim2.new(1, -20, 0, 16), BackgroundTransparency = 1 }, reward) else nil,
	})
end


--------------------------------------------------------------------------------
-- Squad Status Card (bottom-left): one tile per open slot, laid out left to right, plus one narrow
-- tile for the locked slots. The card has a fixed height and grows to the right as slots open.
--------------------------------------------------------------------------------
local STATE_CHIPS = {
	Fighting = { "Fighting", Color3.fromRGB(255, 140, 96) },
	Moving = { "Moving", Color3.fromRGB(130, 210, 255) },
	Idle = { "Idle", Color3.fromRGB(196, 186, 214) },
	Recalled = { "Recalled", Color3.fromRGB(80, 230, 250) },
	Down = { "Down", Color3.fromRGB(255, 90, 90) },
	Dueling = { "Dueling", Color3.fromRGB(255, 214, 80) },
	Resting = { "Resting", Color3.fromRGB(130, 240, 160) },
}

local CARD_PAD = 10
local HEADER_H = 22
local TILE_GAP = 6
local TILE_HEIGHT = 86
local LOCKED_TILE = 92
Components.StatusTileMax = 180
Components.StatusTileMin = 136

function Components.StatusCardHeight(_openSlots: number, _hasLocked: boolean, compact: boolean): number
	if compact then return 66 end
	return CARD_PAD * 2 + HEADER_H + TILE_HEIGHT
end

-- Card width for `tiles` slot tiles of `tileWidth`, plus the locked tile when slots remain locked.
function Components.StatusCardWidth(tiles: number, hasLocked: boolean, tileWidth: number): number
	local count = tiles + (if hasLocked then 1 else 0)
	return CARD_PAD * 2 + tiles * tileWidth + (if hasLocked then LOCKED_TILE else 0) + math.max(0, count - 1) * TILE_GAP
end

function Components.SquadStatusCard(props: { Rows: { any }, LockedText: string?, LockedRange: string?, Compact: boolean, TileWidth: number?,
	OnRow: (number) -> (), OnLocked: () -> (), Position: UDim2? })
	local tileW = props.TileWidth or Components.StatusTileMax
	local children: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, if props.Compact then 6 else TILE_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}
	for i, row in props.Rows do
		local rarity = Theme.RarityColor(row.Rarity)
		local chip = STATE_CHIPS[row.State or "Idle"] or STATE_CHIPS.Idle
		local chipText = chip[1] .. (if row.DownSeconds then string.format(" %ds", row.DownSeconds) else "")
		if props.Compact then
			children["Slot" .. i] = e("TextButton", {
				LayoutOrder = i, Size = UDim2.fromOffset(48, 48), BackgroundColor3 = G.BaseRaised, BackgroundTransparency = G.RaisedTransparency,
				BorderSizePixel = 0, Text = "", AutoButtonColor = false,
				[React.Event.Activated] = function() props.OnRow(row.Slot) end,
			}, {
				Corner = corner(G.TileRadius),
				Stroke = stroke(if row.Hero then rarity else G.Hairline, 1, if row.Hero then 0.25 else 0.7),
				Ring = if row.Hero then e("Frame", { Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 1, -4), BackgroundTransparency = 1 }, {
					Corner = corner(G.TileRadius), Stroke = stroke(rarity, 1.4, 0.2),
				}) else nil,
				Art = if row.Hero then e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true }, {
					Corner = corner(G.TileRadius),
					Portrait = e(Portrait, { TemplateId = row.TemplateId, Archetype = row.Archetype, Stars = row.Stars }),
				}) else glassText({ Size = UDim2.fromScale(1, 1), FontFace = G.Fonts.Number, Text = "+", TextSize = 22,
					TextColor3 = G.TextMuted, TextTransparency = 0.3, TextXAlignment = Enum.TextXAlignment.Center }),
				Hp = if row.Hero then e("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 2), Size = UDim2.fromOffset(40, 5), BackgroundTransparency = 1 }, {
					Bar = glassBar(row.HpFraction or 1, if row.ShowStamina then G.Royal else G.Vital, 1, 5),
				}) else nil,
				Arch = if row.Hero then icon(row.Archetype or "Striker", 18, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 4, 0, -4), ZIndex = 6, Flat = true }) else nil,
			})
		elseif row.Hero then
			children["Slot" .. i] = e("TextButton", {
				LayoutOrder = i, Size = UDim2.fromOffset(tileW, TILE_HEIGHT),
				BackgroundColor3 = G.BaseRaised,
				BackgroundTransparency = G.RaisedTransparency,
				BorderSizePixel = 0,
				Text = "", AutoButtonColor = false, Selectable = true,
				[React.Event.Activated] = function() props.OnRow(row.Slot) end,
			}, {
				Corner = corner(G.TileRadius),
				Stroke = stroke(G.Hairline, 1, G.HairlineTransparency),
				RarityAccent = e("Frame", {
					Position = UDim2.fromOffset(0, 6),
					Size = UDim2.new(0, 2, 1, -12),
					BackgroundColor3 = rarity,
					BorderSizePixel = 0,
					ZIndex = 2,
				}),
				Portrait = e("Frame", { Position = UDim2.fromOffset(7, 6), Size = UDim2.fromOffset(44, 44), BackgroundColor3 = G.Base,
					BackgroundTransparency = 0.2, ClipsDescendants = true, ZIndex = 2 }, {
					Corner = corner(G.TileRadius),
					Art = e(Portrait, { TemplateId = row.TemplateId, Archetype = row.Archetype, Stars = row.Stars }),
				}),
				RarityRing = e("Frame", { Position = UDim2.fromOffset(7, 6), Size = UDim2.fromOffset(44, 44), BackgroundTransparency = 1, ZIndex = 3 }, {
					Corner = corner(G.TileRadius), Stroke = stroke(rarity, 1.4, 0.2),
				}),
				Arch = icon(row.Archetype or "Striker", 18, { Position = UDim2.fromOffset(35, 34), ZIndex = 5, Flat = true }),
				Name = glassText({ Position = UDim2.fromOffset(58, 5), Size = UDim2.new(1, -62, 0, 18), FontFace = G.Fonts.Number, TextSize = 13,
					TextColor3 = G.Text, Text = row.Name, ZIndex = 2 }),
				Info = glassText({ Position = UDim2.fromOffset(58, 23), Size = UDim2.new(1, -62, 0, 14), FontFace = G.Fonts.Label, TextSize = 11,
					TextColor3 = rarity, Text = string.format("%s %d★ · Lv.%d", row.RarityName, row.Stars, row.Level), ZIndex = 2 }),
				Chip = glassText({ Position = UDim2.fromOffset(58, 37), Size = UDim2.new(1, -62, 0, 14), FontFace = G.Fonts.Label, TextSize = 11,
					TextColor3 = chip[2], Text = chipText .. (if row.ShowStamina then " · Sta" else ""), ZIndex = 2 }),
				Bars = e("Frame", { Position = UDim2.fromOffset(8, 57), Size = UDim2.new(1, -16, 0, 20), BackgroundTransparency = 1, ZIndex = 2 }, {
					Layout = e("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
					Hp = glassBar(row.HpFraction or 1, if row.ShowStamina then G.Royal else G.Vital, 1, 6),
					Gauge = glassBar((row.Gauge or 0) / 100, if (row.Gauge or 0) >= 100 then G.Royal else G.Arcane, 2, 5, (row.Gauge or 0) >= 100),
				}),
			})
		else
			children["Slot" .. i] = e("TextButton", {
				LayoutOrder = i, Size = UDim2.fromOffset(tileW, TILE_HEIGHT), Text = "", AutoButtonColor = false, Selectable = true,
				BackgroundColor3 = G.BaseRaised, BackgroundTransparency = G.RaisedTransparency, BorderSizePixel = 0,
				[React.Event.Activated] = function() props.OnRow(row.Slot) end,
			}, {
				Corner = corner(G.TileRadius),
				Stroke = stroke(G.Hairline, 1, 0.7),
				Plus = glassText({ Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 32), FontFace = G.Fonts.Number, TextSize = 28,
					TextColor3 = G.TextMuted, TextTransparency = 0.3, TextXAlignment = Enum.TextXAlignment.Center, Text = "+" }),
				Label = glassText({ Position = UDim2.fromOffset(4, 46), Size = UDim2.new(1, -8, 0, 18), FontFace = G.Fonts.Label, TextSize = 12,
					TextColor3 = G.TextMuted, TextTransparency = 0.2, TextXAlignment = Enum.TextXAlignment.Center, Text = string.format("Assign slot %d", row.Slot) }),
			})
		end
	end
	if props.LockedText then
		children.Locked = if props.Compact
			then e("TextButton", {
				LayoutOrder = 99, Size = UDim2.fromOffset(44, 48), BackgroundTransparency = 1, Text = "",
				[React.Event.Activated] = function() props.OnLocked() end,
			}, { Lock = icon("Lock", 36, { Position = UDim2.fromOffset(4, 6), Flat = true }) })
			else e("TextButton", {
				LayoutOrder = 99, Size = UDim2.fromOffset(LOCKED_TILE, TILE_HEIGHT), Text = "", AutoButtonColor = false,
				BackgroundColor3 = G.BaseRaised, BackgroundTransparency = G.RaisedTransparency, BorderSizePixel = 0,
				[React.Event.Activated] = function() props.OnLocked() end,
			}, {
				Corner = corner(G.TileRadius),
				Stroke = stroke(G.Hairline, 1, 0.75),
				Lock = icon("Lock", 32, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Flat = true }),
				Range = glassText({ Position = UDim2.fromOffset(4, 46), Size = UDim2.new(1, -8, 0, 16), FontFace = G.Fonts.Number, TextSize = 12,
					TextColor3 = G.Text, TextXAlignment = Enum.TextXAlignment.Center, Text = "Slots " .. (props.LockedRange or "") }),
				Hint = glassText({ Position = UDim2.fromOffset(4, 64), Size = UDim2.new(1, -8, 0, 14), FontFace = G.Fonts.Label, TextSize = 10,
					TextColor3 = G.TextMuted, TextTransparency = 0.3, TextXAlignment = Enum.TextXAlignment.Center, Text = "Upgrades" }),
			})
	end
	if props.Compact then
		children.Padding = e("UIPadding", { PaddingLeft = UDim.new(0, CARD_PAD), PaddingRight = UDim.new(0, CARD_PAD) })
		return glass({
			AnchorPoint = Vector2.new(0, 1),
			Position = props.Position or UDim2.new(0, L.Edge, 1, -L.Edge),
			Size = UDim2.fromOffset(20 + (#props.Rows + (if props.LockedText then 1 else 0)) * 54, 66),
		}, { Strip = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, children) })
	end
	return glass({
		AnchorPoint = Vector2.new(0, 1),
		Position = props.Position or UDim2.new(0, L.Edge, 1, -L.Edge),
		Size = UDim2.fromOffset(Components.StatusCardWidth(#props.Rows, props.LockedText ~= nil, tileW), Components.StatusCardHeight(#props.Rows, props.LockedText ~= nil, false)),
	}, {
		Header = sectionLabel("Squad Status", { Position = UDim2.fromOffset(CARD_PAD + 2, CARD_PAD - 4), Size = UDim2.new(1, -CARD_PAD * 2, 0, HEADER_H) }),
		Strip = e("Frame", { Position = UDim2.fromOffset(CARD_PAD, CARD_PAD + HEADER_H), Size = UDim2.new(1, -CARD_PAD * 2, 0, TILE_HEIGHT), BackgroundTransparency = 1 }, children),
	})
end

--------------------------------------------------------------------------------
-- Clear Glass corner brackets: four 10x10 L-shaped hairlines just outside a panel's corners.
--------------------------------------------------------------------------------
function Components.Brackets(props: { Inset: number?, ZIndex: number? })
	local inset = props.Inset or -3
	local z = props.ZIndex or 8
	local corners: { [string]: any } = {}
	for _, spot in { { "TL", 0, 0 }, { "TR", 1, 0 }, { "BL", 0, 1 }, { "BR", 1, 1 } } do
		local name, x, y = spot[1], spot[2], spot[3]
		local function line(w: number, h: number)
			return e("Frame", { AnchorPoint = Vector2.new(x, y), Position = UDim2.fromScale(x, y), Size = UDim2.fromOffset(w, h),
				BackgroundColor3 = G.Hairline, BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = z })
		end
		corners[name] = e("Frame", {
			AnchorPoint = Vector2.new(x, y),
			Position = UDim2.new(x, if x == 0 then inset else -inset, y, if y == 0 then inset else -inset),
			Size = UDim2.fromOffset(10, 10),
			BackgroundTransparency = 1,
			ZIndex = z,
		}, { H = line(10, 1), V = line(1, 10) })
	end
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = z }, corners)
end

--------------------------------------------------------------------------------
-- Squad drawer (bottom-left): one squad view that is either a slim glass strip of portraits
-- (collapsed) or the full Squad Status Card (expanded), never both. Expanding grows the strip up
-- into the card; collapsing shrinks the card back down into the strip. The currency bar rides on
-- the drawer's top edge. Size is tweened imperatively (React never sets it after mount), so a 5 Hz
-- re-render can't snap it.
--------------------------------------------------------------------------------
local STRIP_H = 56
local STRIP_PAD = 6
local STRIP_SLOT = 44 -- hit area; the portrait inside is 36
local STRIP_GAP = 4
local DRAWER_GAP = 6 -- between the card and its collapse tab
local DRAWER_TAB = 44 -- the collapse tab beside the expanded card
local CLIP_PAD = 4 -- room for the card's outer ink stroke inside the clip
local DRAWER_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Components.DrawerTween = DRAWER_TWEEN.Time
Components.DrawerTabWidth = DRAWER_GAP + DRAWER_TAB -- the expanded card's extra width

local function stripWidth(slots: number, hasLocked: boolean): number
	local count = slots + (if hasLocked then 1 else 0) + 1 -- + the chevron tab
	return STRIP_PAD * 2 + count * STRIP_SLOT + (count - 1) * STRIP_GAP
end

-- Height of the drawer: the strip when collapsed, the card when expanded.
function Components.DrawerHeight(expanded: boolean, cardHeight: number): number
	return if expanded then math.max(cardHeight, STRIP_H) else STRIP_H
end

local function stateColor(state: string?): Color3
	local chip = STATE_CHIPS[state or "Idle"] or STATE_CHIPS.Idle
	return chip[2]
end

local function stripSlot(row: any, index: number, hovered: boolean, onHover: (number?) -> (), onOpen: () -> ())
	local children: { [string]: any } = {}
	if row.Hero then
		local down = row.State == "Down"
		children.Face = e("Frame", { Position = UDim2.fromOffset(4, 2), Size = UDim2.fromOffset(36, 36), BackgroundColor3 = G.Base,
			BackgroundTransparency = 0.2, ClipsDescendants = true, ZIndex = 2 }, {
			Corner = corner(G.TileRadius),
			Art = e(Portrait, { TemplateId = row.TemplateId, Archetype = row.Archetype, Stars = row.Stars }),
			-- Down: dimmed with the coma countdown, so it never relies on colour alone.
			Down = if down then e("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = G.Base, BackgroundTransparency = 0.3,
				FontFace = G.Fonts.Number, TextColor3 = G.Danger, TextSize = 12, ZIndex = 4,
				Text = if row.DownSeconds then string.format("%ds", row.DownSeconds) else "DOWN" }) else nil,
		})
		children.Ring = e("Frame", { Position = UDim2.fromOffset(4, 2), Size = UDim2.fromOffset(36, 36), BackgroundTransparency = 1, ZIndex = 5 }, {
			Corner = corner(G.TileRadius), Stroke = stroke(Theme.RarityColor(row.Rarity), 2),
		})
		children.Dot = e("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(39, 4), Size = UDim2.fromOffset(9, 9),
			BackgroundColor3 = stateColor(row.State), BorderSizePixel = 0, ZIndex = 6 }, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }), Ring = stroke(G.Base, 1.5),
		})
		children.Hp = e("Frame", { Position = UDim2.fromOffset(4, 42), Size = UDim2.fromOffset(36, 3), BackgroundColor3 = G.Base,
			BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 2 }, {
			Fill = e("Frame", { Size = UDim2.fromScale(math.clamp(row.HpFraction or 1, 0, 1), 1), BorderSizePixel = 0,
				BackgroundColor3 = if row.ShowStamina then G.Royal else G.Vital }),
		})
	else
		children.Empty = e("TextLabel", { Position = UDim2.fromOffset(4, 2), Size = UDim2.fromOffset(36, 36), BackgroundColor3 = G.BaseRaised,
			BackgroundTransparency = G.RaisedTransparency, FontFace = G.Fonts.Number, Text = "+", TextColor3 = G.Text, TextSize = 20, ZIndex = 2 }, {
			Corner = corner(G.TileRadius), Stroke = stroke(G.Hairline, 1, 0.6),
		})
	end
	return e("TextButton", {
		LayoutOrder = index,
		Size = UDim2.fromOffset(STRIP_SLOT, STRIP_H - 8),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Selectable = true,
		[React.Event.MouseEnter] = function() onHover(index) end,
		[React.Event.MouseLeave] = function() onHover(nil) end,
		[React.Event.SelectionGained] = function() onHover(index) end,
		[React.Event.SelectionLost] = function() onHover(nil) end,
		-- Mouse: hover shows the tooltip, so a click opens the Squad screen. Touch: first tap shows it.
		[React.Event.Activated] = function()
			if hovered or not row.Hero then onOpen() else onHover(index) end
		end,
	}, children)
end

local function stripTooltip(row: any, index: number)
	local hp = math.floor(math.clamp(row.HpFraction or 1, 0, 1) * 100 + 0.5)
	local state = (STATE_CHIPS[row.State or "Idle"] or STATE_CHIPS.Idle)[1] .. (if row.DownSeconds then string.format(" %ds", row.DownSeconds) else "")
	return e("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, STRIP_PAD + (index - 1) * (STRIP_SLOT + STRIP_GAP), 1, -(STRIP_H + 6)),
		Size = UDim2.fromOffset(170, 64),
		BackgroundColor3 = G.Base,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		ZIndex = 20,
	}, {
		Corner = corner(G.Radius),
		Stroke = stroke(G.Hairline, 1, G.HairlineTransparency),
		Name = e("TextLabel", { Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 18), BackgroundTransparency = 1, FontFace = G.Fonts.Display,
			Text = row.Name, TextColor3 = Theme.RarityColor(row.Rarity), TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 21 }),
		Info = e("TextLabel", { Position = UDim2.fromOffset(10, 25), Size = UDim2.new(1, -20, 0, 15), BackgroundTransparency = 1, FontFace = G.Fonts.Label,
			Text = string.format("Lv.%d · %d★ %s", row.Level, row.Stars, row.RarityName), TextColor3 = G.Text, TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 21 }),
		Hp = e("TextLabel", { Position = UDim2.fromOffset(10, 42), Size = UDim2.new(1, -20, 0, 15), BackgroundTransparency = 1, FontFace = G.Fonts.Label,
			Text = string.format("%s %d%% · %s", if row.ShowStamina then "Stamina" else "HP", hp, state), TextColor3 = G.Text,
			TextTransparency = 0.2, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 21 }),
	})
end

-- A drawn chevron: up (expand) or down (collapse).
-- When `not up` or `triple`, renders 3 stacked downward chevrons.
local function chevron(up: boolean, order: number, onToggle: () -> (), triple: boolean?, size: UDim2?, radius: number?)
	local function bar(side: number, yOff: number?, len: number?)
		return e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, side * 3.5, 0.5, yOff or 0),
			Size = UDim2.fromOffset(len or 12, 2),
			Rotation = side * (if up then 40 else -40),
			BackgroundColor3 = G.Text,
			BorderSizePixel = 0,
			ZIndex = 3,
		})
	end
	local kids: { [string]: any } = {
		Corner = corner(radius or G.TileRadius),
		Stroke = stroke(G.Hairline, 1, G.HairlineTransparency),
	}
	if triple or not up then
		-- 3 down arrows stacked vertically: top (-8px), middle (0px), bottom (+8px)
		for _, yOff in { -8, 0, 8 } do
			kids["Arr" .. yOff .. "L"] = bar(-1, yOff, 10)
			kids["Arr" .. yOff .. "R"] = bar(1, yOff, 10)
		end
	else
		kids.Left = bar(-1, 0, 12)
		kids.Right = bar(1, 0, 12)
	end
	return e("TextButton", {
		LayoutOrder = order,
		Size = size or UDim2.fromOffset(STRIP_SLOT, STRIP_H - 8),
		BackgroundColor3 = G.BaseRaised,
		BackgroundTransparency = G.RaisedTransparency,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Selectable = true,
		[React.Event.Activated] = function() onToggle() end,
	}, kids)
end

function Components.SquadDrawer(props: {
	Rows: { any },
	LockedText: string?,
	LockedRange: string?,
	Compact: boolean,
	TileWidth: number?,
	CardHeight: number,
	Expanded: boolean,
	Above: any?, -- the currency bar, riding on the drawer's top edge
	OnToggle: () -> (),
	OnRow: (number) -> (),
	OnLocked: () -> (),
})
	local shellRef = React.useRef(nil)
	local mounted = React.useRef(false)
	local hoverSlot, setHoverSlot = React.useState(nil :: number?)
	local showCard, setShowCard = React.useState(props.Expanded)

	local hasLocked = props.LockedText ~= nil
	local cardWidth = if props.Compact then 20 + (#props.Rows + (if hasLocked then 1 else 0)) * 54
		else Components.StatusCardWidth(#props.Rows, hasLocked, props.TileWidth or Components.StatusTileMax)
	local width = if props.Expanded then cardWidth + Components.DrawerTabWidth else stripWidth(#props.Rows, hasLocked)
	local height = Components.DrawerHeight(props.Expanded, props.CardHeight)

	React.useEffect(function()
		-- Expanding swaps to the card at once (it is revealed bottom-up as the drawer grows);
		-- collapsing keeps the card until the drawer has shrunk, then swaps back to the strip.
		if props.Expanded then
			setShowCard(true)
			setHoverSlot(nil)
		end
		local shell = shellRef.current
		if not shell then return nil end
		local size = UDim2.fromOffset(width, height)
		if not mounted.current or reducedMotion() then
			mounted.current = true
			shell.Size = size
			if not props.Expanded then setShowCard(false) end
			return nil
		end
		local tween = TweenService:Create(shell, DRAWER_TWEEN, { Size = size })
		local conn = tween.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and not props.Expanded then setShowCard(false) end
		end)
		tween:Play()
		return function() conn:Disconnect() end
	end, { props.Expanded, width, height } :: { any })

	local slots: { [string]: any } = {
		Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, STRIP_GAP), SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center }),
		Padding = e("UIPadding", { PaddingLeft = UDim.new(0, STRIP_PAD), PaddingRight = UDim.new(0, STRIP_PAD) }),
	}
	for i, row in props.Rows do
		slots["Slot" .. i] = stripSlot(row, i, hoverSlot == i, setHoverSlot, function() props.OnRow(row.Slot) end)
	end
	if hasLocked then
		slots.Locked = e("TextButton", { LayoutOrder = 98, Size = UDim2.fromOffset(STRIP_SLOT, STRIP_H - 8), BackgroundTransparency = 1, Text = "",
			Selectable = true, [React.Event.Activated] = function() props.OnLocked() end }, {
			Lock = icon("Lock", 32, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45) }),
		})
	end
	slots.Chevron = chevron(true, 99, props.OnToggle)

	local hoveredRow = if hoverSlot and not showCard then props.Rows[hoverSlot] else nil
	return e("Frame", {
		ref = shellRef,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, L.Edge, 1, -L.Edge),
		BackgroundTransparency = 1,
	}, {
		Brackets = e(Components.Brackets, {}),
		Above = if props.Above then e("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromOffset(0, -8), Size = UDim2.new(1, 0, 0, Components.CurrencyBarHeight),
			BackgroundTransparency = 1 }, { Bar = props.Above }) else nil,
		Clip = e("Frame", { Position = UDim2.fromOffset(-CLIP_PAD, -CLIP_PAD), Size = UDim2.new(1, CLIP_PAD * 2, 1, CLIP_PAD * 2),
			BackgroundTransparency = 1, ClipsDescendants = true }, {
			Card = if showCard then e("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, CLIP_PAD, 1, -CLIP_PAD),
				Size = UDim2.fromOffset(cardWidth, props.CardHeight), BackgroundTransparency = 1 }, {
				Status = e(Components.SquadStatusCard, {
					Rows = props.Rows, LockedText = props.LockedText, LockedRange = props.LockedRange, Compact = props.Compact, TileWidth = props.TileWidth,
					OnRow = props.OnRow, OnLocked = props.OnLocked, Position = UDim2.fromScale(0, 1),
				}),
				-- Collapse tab: full height matching the card, spanning top-to-bottom inside the corner outlines.
				Collapse = e("Frame", {
					AnchorPoint = Vector2.new(0, 0),
					Position = UDim2.new(1, DRAWER_GAP, 0, 0),
					Size = UDim2.new(0, DRAWER_TAB, 1, 0),
					BackgroundTransparency = 1,
				}, {
					Tab = chevron(false, 1, props.OnToggle, true, UDim2.fromScale(1, 1), G.Radius),
				}),
			}) else nil,
			Strip = if not showCard then e("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, CLIP_PAD, 1, -CLIP_PAD),
				Size = UDim2.fromOffset(stripWidth(#props.Rows, hasLocked), STRIP_H), BackgroundColor3 = G.Base,
				BackgroundTransparency = G.BaseTransparency, BorderSizePixel = 0 }, {
				Corner = corner(G.Radius),
				Stroke = stroke(G.Hairline, 1, G.HairlineTransparency),
				Row = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, slots),
			}) else nil,
		}),
		Tooltip = if hoveredRow and hoveredRow.Hero then stripTooltip(hoveredRow, hoverSlot :: number) else nil,
	})
end

--------------------------------------------------------------------------------
-- The Pit tab navigator: Synthesis | Promotion, centred just above the open Pit screen.
--------------------------------------------------------------------------------
-- Compact enough to sit in Roblox's top bar (HudApp centres it there, or on the window's top edge).
Components.PitTabsSize = Vector2.new(300, 46)

function Components.PitTabs(props: { Active: string, Center: Vector2, OnSelect: (string) -> () })
	local children: { [string]: any } = {
		Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center, HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	}
	for i, tab in { "Synthesis", "Promotion" } do
		local active = props.Active == tab
		local tone = if active then Grimoire.Tones.Gold else Grimoire.Tones.Slate
		children[tab] = panel({
			Class = "TextButton", LayoutOrder = i, Size = UDim2.fromOffset(134, 34), Text = "", AutoButtonColor = false, Selectable = true,
			Radius = 10, Top = tone.Top, Bottom = tone.Bottom, Rail = tone.Rail,
			[React.Event.Activated] = function()
				if not active then props.OnSelect(tab) end
			end,
		}, {
			Label = heavyLabel({ Size = UDim2.fromScale(1, 1), MaxSize = 15, Gold = not active, Outline = 2.2, ZIndex = 4,
				TextColor3 = if active then Color3.new(1, 1, 1) else Grimoire.Text.Muted, Text = tab }),
		})
	end
	return panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(props.Center.X, props.Center.Y),
		Size = UDim2.fromOffset(Components.PitTabsSize.X, Components.PitTabsSize.Y),
		ZIndex = 30,
	}, { Row = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, children) })
end

--------------------------------------------------------------------------------
-- Currency bar (Gold and Gems), riding on the Squad drawer: two glass chips, each a flat icon and
-- the value, with a change floater above.
--------------------------------------------------------------------------------
local function CurrencyChip(props: { Icon: string, Value: number, Order: number, Color: Color3 })
	local shown, setShown = React.useState(props.Value)
	local delta, setDelta = React.useState(0)
	local serial, setSerial = React.useState(0)
	React.useEffect(function()
		if props.Value == shown then return end
		setDelta(props.Value - shown)
		setShown(props.Value)
		setSerial(serial + 1)
		local alive = true
		task.delay(0.9, function() if alive then setDelta(0) end end)
		return function() alive = false end
	end, { props.Value })
	return e("Frame", { LayoutOrder = props.Order, Size = UDim2.new(0.5, -4, 1, 0), BackgroundTransparency = 1 }, {
		Body = glass({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 32) }, {
			Icon = icon(props.Icon, 20, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Flat = true }),
			Value = glassText({ Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -42, 1, 0), FontFace = G.Fonts.Number, TextSize = 16,
				TextColor3 = props.Color, Text = abbreviate(shown) }),
		}),
		["Floater" .. serial] = if delta ~= 0 then e(Floater, { Delta = delta, Position = UDim2.new(1, -4, 1, -34), Size = UDim2.fromOffset(110, 16) }) else nil,
	})
end

Components.CurrencyBarHeight = 40

function Components.CurrencyBar(props: { Gold: number, Gems: number, Bottom: number?, Width: number, Position: UDim2? })
	return e("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = props.Position or UDim2.new(0, L.Edge, 1, -(props.Bottom or 0)),
		Size = UDim2.fromOffset(props.Width, Components.CurrencyBarHeight),
		BackgroundTransparency = 1,
	}, {
		Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		Gold = e(CurrencyChip, { Icon = "Gold", Value = props.Gold, Order = 1, Color = G.Royal }),
		Gems = e(CurrencyChip, { Icon = "Gems", Value = props.Gems, Order = 2, Color = G.Text }),
	})
end

--------------------------------------------------------------------------------
-- Squad Power badge (bottom-right): a glass card with "SQUAD POWER ———", the value in Cinzel, a
-- change floater and a per-hero breakdown on hover. Phones show the icon and number only.
--------------------------------------------------------------------------------
function Components.SquadPowerBadge(props: { Power: number, Breakdown: { { Name: string, Power: number } }, Compact: boolean })
	local shown, setShown = React.useState(props.Power)
	local delta, setDelta = React.useState(0)
	local serial, setSerial = React.useState(0)
	local hover, setHover = React.useState(false)
	React.useEffect(function()
		if props.Power == shown then return end
		setDelta(props.Power - shown)
		setShown(props.Power)
		setSerial(serial + 1)
		local alive = true
		task.delay(0.9, function()
			if alive then setDelta(0) end
		end)
		return function() alive = false end
	end, { props.Power })

	local royal = G.Royal:ToHex()
	local rows: { [string]: any } = {
		Layout = e("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
		Padding = e("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
	}
	for i, entry in props.Breakdown do
		rows["R" .. i] = glassText({ LayoutOrder = i, Size = UDim2.new(1, 0, 0, 16), ZIndex = 6,
			Text = string.format("%s  <font color=\"#%s\">%s</font>", entry.Name, royal, abbreviate(entry.Power)) })
	end
	local width = if props.Compact then 130 else L.PowerBadgeWidth
	local height = if props.Compact then 44 else L.PowerBadgeHeight
	return e("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -L.Edge, 1, -L.Edge),
		Size = UDim2.fromOffset(width, height),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		[React.Event.MouseEnter] = function() setHover(true) end,
		[React.Event.MouseLeave] = function() setHover(false) end,
		[React.Event.Activated] = function() setHover(not hover) end,
	}, {
		Body = glass({ Size = UDim2.fromScale(1, 1) }, {
			Icon = icon("Power", if props.Compact then 24 else 30, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Flat = true }),
			Label = if not props.Compact then sectionLabel("Squad Power", { Position = UDim2.fromOffset(48, 6), Size = UDim2.new(1, -58, 0, 14) }) else nil,
			Value = glassText({ Position = UDim2.fromOffset(if props.Compact then 42 else 48, if props.Compact then 0 else 21),
				Size = UDim2.new(1, if props.Compact then -50 else -58, 0, if props.Compact then height else 30), FontFace = G.Fonts.Display,
				TextSize = if props.Compact then 20 else 24, Text = abbreviate(shown) }),
		}),
		["Floater" .. serial] = if delta ~= 0 then e(Floater, { Delta = delta, Position = UDim2.new(1, -6, 0, -2), Size = UDim2.fromOffset(130, 18), TextSize = 16 }) else nil,
		Tooltip = if hover and #props.Breakdown > 0 then glass({
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, 0, 0, -24),
			Size = UDim2.fromOffset(230, 16 + #props.Breakdown * 18),
			BackgroundTransparency = 0.15,
			ZIndex = 5,
		}, rows) else nil,
	})
end


return Components
