--!strict
-- StarterPlayerScripts/UI/Hud/Components.luau
-- Phase 5 HUD building blocks (React-lua): rail buttons, the Next Goal card, the Squad Status
-- Card and the Squad Power badge. Pure presentation; data arrives as props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
	for k, v in props do frame[k] = v end
	return e("Frame", frame, { Art = e(Icons.Icon, { Name = name, Size = size }) })
end
Components.IconAt = icon

--------------------------------------------------------------------------------
-- Next Goal card (top-right): a quest scroll icon, the step counter, the goal in heavy gothic
-- type and its reward.
--------------------------------------------------------------------------------
function Components.NextGoalCard(props: { Goal: any })
	local goal = props.Goal
	if not goal then return nil end
	-- Reward: "Reward" then a drawn Gold / Gems icon beside each amount.
	local reward: { [string]: any }? = nil
	if type(goal.Reward) == "table" and (goal.Reward.Gold or goal.Reward.Gems) then
		local items: { [string]: any } = {
			Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center }),
			Label = body({ LayoutOrder = 0, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 14), TextSize = 11,
				TextColor3 = Color3.fromRGB(255, 214, 120), Text = "Reward " }),
		}
		local order = 1
		for _, kind in { "Gold", "Gems" } do
			local amount = goal.Reward[kind]
			if amount then
				items[kind .. "Icon"] = icon(kind, 16, { LayoutOrder = order, ZIndex = 2 })
				items[kind] = body({ LayoutOrder = order + 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 14), TextSize = 11,
					TextColor3 = Color3.fromRGB(255, 214, 120), Text = abbreviate(amount) .. "  " })
				order += 2
			end
		end
		reward = items
	end
	return panel({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -L.Edge, 0, L.TopZone),
		Size = UDim2.fromOffset(L.GoalCardWidth, L.GoalCardHeight),
	}, {
		Scroll = icon("Goal", 58, { Position = UDim2.fromOffset(-14, -10) }),
		Step = heavyLabel({ Position = UDim2.fromOffset(52, 6), Size = UDim2.new(1, -64, 0, 16), MaxSize = 14, Outline = 2,
			TextXAlignment = Enum.TextXAlignment.Left, Text = string.format("Next Goal  %d/%d", goal.Index or 1, goal.Total or 1) }),
		Title = heavyLabel({ Position = UDim2.fromOffset(52, 23), Size = UDim2.new(1, -64, 0, 24), MaxSize = 20, Gold = false,
			TextXAlignment = Enum.TextXAlignment.Left, Text = tostring(goal.Title) }),
		Hint = body({ Position = UDim2.fromOffset(14, 50), Size = UDim2.new(1, -28, 0, 16), TextSize = 12, Text = tostring(goal.Description) }),
		Reward = if reward then e("Frame", { Position = UDim2.fromOffset(14, 66), Size = UDim2.new(1, -28, 0, 16), BackgroundTransparency = 1 }, reward) else nil,
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
	OnRow: (number) -> (), OnLocked: () -> () })
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
				LayoutOrder = i, Size = UDim2.fromOffset(48, 48), BackgroundColor3 = Color3.fromRGB(24, 18, 36), Text = "", AutoButtonColor = false,
				[React.Event.Activated] = function() props.OnRow(row.Slot) end,
			}, {
				Corner = corner(24),
				Ink = e("UIStroke", { Color = INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
				Ring = e("Frame", { Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 1, -4), BackgroundTransparency = 1 }, {
					Corner = corner(22), Stroke = stroke(if row.Hero then rarity else C.Border, 2),
				}),
				Art = if row.Hero then e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true }, {
					Corner = corner(24),
					Portrait = e(Portrait, { TemplateId = row.TemplateId, Archetype = row.Archetype, Stars = row.Stars }),
				}) else heavyLabel({ Size = UDim2.fromScale(1, 1), Text = "+", MaxSize = 26 }),
				Hp = if row.Hero then e("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 2), Size = UDim2.fromOffset(40, 7), BackgroundTransparency = 1 }, {
					Bar = chunkyBar(row.HpFraction or 1, if row.ShowStamina then C.Gauge else Color3.fromRGB(120, 255, 140), Color3.fromRGB(30, 150, 70), 1, 7),
				}) else nil,
				Arch = if row.Hero then icon(row.Archetype or "Striker", 20, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 6, 0, -6), ZIndex = 6 }) else nil,
			})
		elseif row.Hero then
			children["Slot" .. i] = panel({
				Class = "TextButton", LayoutOrder = i, Size = UDim2.fromOffset(tileW, TILE_HEIGHT), Text = "", AutoButtonColor = false, Selectable = true,
				Radius = 9, Rail = rarity, Top = Color3.fromRGB(46, 32, 70), Bottom = Color3.fromRGB(18, 12, 28),
				[React.Event.Activated] = function() props.OnRow(row.Slot) end,
			}, {
				Portrait = e("Frame", { Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(44, 44), BackgroundColor3 = Color3.fromRGB(12, 8, 18), ClipsDescendants = true, ZIndex = 2 }, {
					Corner = corner(8),
					Ink = e("UIStroke", { Color = INK, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
					Art = e(Portrait, { TemplateId = row.TemplateId, Archetype = row.Archetype, Stars = row.Stars }),
				}),
				RarityRing = e("Frame", { Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(44, 44), BackgroundTransparency = 1, ZIndex = 3 }, {
					Corner = corner(8), Stroke = stroke(rarity, 1.6),
				}),
				Arch = icon(row.Archetype or "Striker", 22, { Position = UDim2.fromOffset(34, 34), ZIndex = 5 }),
				Name = heavyLabel({ Position = UDim2.fromOffset(56, 5), Size = UDim2.new(1, -60, 0, 18), MaxSize = 15, Outline = 2, Gold = false,
					TextXAlignment = Enum.TextXAlignment.Left, Text = row.Name }),
				Info = body({ Position = UDim2.fromOffset(56, 23), Size = UDim2.new(1, -60, 0, 13), TextSize = 11, TextColor3 = rarity,
					Text = string.format("%s %d★ · Lv.%d", row.RarityName, row.Stars, row.Level) }),
				Chip = heavyLabel({ Position = UDim2.fromOffset(56, 37), Size = UDim2.new(1, -60, 0, 14), MaxSize = 12, Outline = 1.6, Gold = false,
					TextColor3 = chip[2], TextXAlignment = Enum.TextXAlignment.Left, Text = chipText .. (if row.ShowStamina then " · Sta" else "") }),
				Bars = e("Frame", { Position = UDim2.fromOffset(8, 57), Size = UDim2.new(1, -16, 0, 20), BackgroundTransparency = 1 }, {
					Layout = e("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
					Hp = chunkyBar(row.HpFraction or 1, if row.ShowStamina then Color3.fromRGB(255, 230, 110) else Color3.fromRGB(120, 255, 140),
						if row.ShowStamina then Color3.fromRGB(210, 140, 20) else Color3.fromRGB(30, 150, 70), 1, 9),
					Gauge = chunkyBar((row.Gauge or 0) / 100, Color3.fromRGB(220, 160, 255), Color3.fromRGB(110, 40, 190), 2, 7, (row.Gauge or 0) >= 100),
				}),
			})
		else
			children["Slot" .. i] = panel({
				Class = "TextButton", LayoutOrder = i, Size = UDim2.fromOffset(tileW, TILE_HEIGHT), Text = "", AutoButtonColor = true, Selectable = true,
				Radius = 9, Top = Color3.fromRGB(34, 26, 48), Bottom = Color3.fromRGB(16, 12, 24),
				[React.Event.Activated] = function() props.OnRow(row.Slot) end,
			}, {
				Plus = heavyLabel({ Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 34), MaxSize = 32, Text = "+" }),
				Label = heavyLabel({ Position = UDim2.fromOffset(4, 48), Size = UDim2.new(1, -8, 0, 18), MaxSize = 14, Outline = 2, Gold = false,
					Text = string.format("Assign slot %d", row.Slot) }),
			})
		end
	end
	if props.LockedText then
		children.Locked = if props.Compact
			then e("TextButton", {
				LayoutOrder = 99, Size = UDim2.fromOffset(44, 48), BackgroundTransparency = 1, Text = "",
				[React.Event.Activated] = function() props.OnLocked() end,
			}, { Lock = icon("Lock", 40, { Position = UDim2.fromOffset(2, 4) }) })
			else panel({
				Class = "TextButton", LayoutOrder = 99, Size = UDim2.fromOffset(LOCKED_TILE, TILE_HEIGHT), Text = "", AutoButtonColor = true,
				Radius = 9, Top = Color3.fromRGB(30, 24, 42), Bottom = Color3.fromRGB(14, 10, 22), Rail = Color3.fromRGB(140, 130, 160),
				[React.Event.Activated] = function() props.OnLocked() end,
			}, {
				Lock = icon("Lock", 38, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6) }),
				Range = heavyLabel({ Position = UDim2.fromOffset(4, 46), Size = UDim2.new(1, -8, 0, 16), MaxSize = 13, Outline = 1.8, Gold = false,
					Text = "Slots " .. (props.LockedRange or "") }),
				Hint = body({ Position = UDim2.fromOffset(4, 64), Size = UDim2.new(1, -8, 0, 13), TextSize = 10, TextColor3 = Color3.fromRGB(196, 186, 214),
					TextXAlignment = Enum.TextXAlignment.Center, Text = "Upgrades" }),
			})
	end
	if props.Compact then
		children.Padding = e("UIPadding", { PaddingLeft = UDim.new(0, CARD_PAD), PaddingRight = UDim.new(0, CARD_PAD) })
		return panel({
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, L.Edge, 1, -L.Edge),
			Size = UDim2.fromOffset(20 + (#props.Rows + (if props.LockedText then 1 else 0)) * 54, 66),
		}, { Strip = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, children) })
	end
	return panel({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, L.Edge, 1, -L.Edge),
		Size = UDim2.fromOffset(Components.StatusCardWidth(#props.Rows, props.LockedText ~= nil, tileW), Components.StatusCardHeight(#props.Rows, props.LockedText ~= nil, false)),
	}, {
		Header = heavyLabel({ Position = UDim2.fromOffset(CARD_PAD + 2, CARD_PAD - 3), Size = UDim2.new(1, -CARD_PAD * 2, 0, HEADER_H), MaxSize = 16, Outline = 2,
			TextXAlignment = Enum.TextXAlignment.Left, Text = "Squad Status" }),
		Strip = e("Frame", { Position = UDim2.fromOffset(CARD_PAD, CARD_PAD + HEADER_H), Size = UDim2.new(1, -CARD_PAD * 2, 0, TILE_HEIGHT), BackgroundTransparency = 1 }, children),
	})
end

--------------------------------------------------------------------------------
-- The Pit tab navigator: Synthesis | Promotion, centred just above the open Pit screen.
--------------------------------------------------------------------------------
function Components.PitTabs(props: { Active: string, Center: Vector2, OnSelect: (string) -> () })
	local children: { [string]: any } = {
		Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center, HorizontalAlignment = Enum.HorizontalAlignment.Center }),
		Title = heavyLabel({ LayoutOrder = 0, Size = UDim2.fromOffset(110, 30), MaxSize = 20, Text = "The Pit" }),
	}
	for i, tab in { "Synthesis", "Promotion" } do
		local active = props.Active == tab
		local tone = if active then Grimoire.Tones.Gold else Grimoire.Tones.Slate
		children[tab] = panel({
			Class = "TextButton", LayoutOrder = i, Size = UDim2.fromOffset(168, 40), Text = "", AutoButtonColor = false, Selectable = true,
			Radius = 10, Top = tone.Top, Bottom = tone.Bottom, Rail = tone.Rail,
			[React.Event.Activated] = function()
				if not active then props.OnSelect(tab) end
			end,
		}, {
			Label = heavyLabel({ Size = UDim2.fromScale(1, 1), MaxSize = 17, Gold = not active, Outline = 2.2, ZIndex = 4,
				TextColor3 = if active then Color3.new(1, 1, 1) else Grimoire.Text.Muted, Text = tab }),
		})
	end
	return panel({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromOffset(props.Center.X, props.Center.Y),
		Size = UDim2.fromOffset(500, 56),
		ZIndex = 30,
	}, { Row = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, children) })
end

--------------------------------------------------------------------------------
-- Currency bar (Gold and Gems), sitting directly above the Squad Status Card: each chip is a
-- cartoon panel with its icon breaking out over the left edge and the value in heavy type.
--------------------------------------------------------------------------------
local function CurrencyChip(props: { Icon: string, Value: number, Order: number, Top: Color3, Bottom: Color3, Rail: Color3 })
	local shown, setShown = React.useState(props.Value)
	local delta, setDelta = React.useState(0)
	React.useEffect(function()
		if props.Value == shown then return end
		setDelta(props.Value - shown)
		setShown(props.Value)
		local alive = true
		task.delay(1.4, function() if alive then setDelta(0) end end)
		return function() alive = false end
	end, { props.Value })
	return e("Frame", { LayoutOrder = props.Order, Size = UDim2.new(0.5, -6, 1, 0), BackgroundTransparency = 1 }, {
		Body = panel({ Position = UDim2.fromOffset(14, 4), Size = UDim2.new(1, -14, 1, -4), Radius = 10, Top = props.Top, Bottom = props.Bottom, Rail = props.Rail }, {
			Value = heavyLabel({ Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -36, 1, 0), MaxSize = 20, Outline = 2.2,
				TextXAlignment = Enum.TextXAlignment.Left, Text = abbreviate(shown) }),
		}),
		Icon = icon(props.Icon, 40, { Position = UDim2.fromOffset(-4, -2), ZIndex = 6 }),
		Floater = if delta ~= 0 then heavyLabel({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 0, 0), Size = UDim2.fromOffset(110, 18), MaxSize = 16,
			Outline = 2, Gold = false, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = if delta > 0 then Color3.fromRGB(120, 255, 140) else Color3.fromRGB(255, 100, 100),
			Text = (if delta > 0 then "+" else "−") .. abbreviate(math.abs(delta)) }) else nil,
	})
end

Components.CurrencyBarHeight = 40

function Components.CurrencyBar(props: { Gold: number, Gems: number, Bottom: number, Width: number })
	return e("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, L.Edge, 1, -props.Bottom),
		Size = UDim2.fromOffset(props.Width, Components.CurrencyBarHeight),
		BackgroundTransparency = 1,
	}, {
		Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
		Gold = e(CurrencyChip, { Icon = "Gold", Value = props.Gold, Order = 1, Top = Color3.fromRGB(96, 64, 24), Bottom = Color3.fromRGB(34, 20, 10), Rail = Color3.fromRGB(255, 214, 110) }),
		Gems = e(CurrencyChip, { Icon = "Gems", Value = props.Gems, Order = 2, Top = Color3.fromRGB(28, 70, 104), Bottom = Color3.fromRGB(10, 20, 40), Rail = Color3.fromRGB(150, 236, 255) }),
	})
end

--------------------------------------------------------------------------------
-- Squad Power badge (bottom-right): crossed-swords icon breaking out over the left edge, the value
-- in heavy gold type, a change floater and a per-hero breakdown on hover.
--------------------------------------------------------------------------------
function Components.SquadPowerBadge(props: { Power: number, Breakdown: { { Name: string, Power: number } }, Compact: boolean })
	local shown, setShown = React.useState(props.Power)
	local delta, setDelta = React.useState(0)
	local hover, setHover = React.useState(false)
	React.useEffect(function()
		if props.Power == shown then return end
		setDelta(props.Power - shown)
		setShown(props.Power)
		local alive = true
		task.delay(1.6, function()
			if alive then setDelta(0) end
		end)
		return function() alive = false end
	end, { props.Power })

	local rows: { [string]: any } = {
		Layout = e("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
		Padding = e("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
	}
	for i, entry in props.Breakdown do
		rows["R" .. i] = body({ LayoutOrder = i, Size = UDim2.new(1, 0, 0, 16), TextSize = 12,
			Text = string.format("%s  <font color=\"#FFD86E\">%s</font>", entry.Name, abbreviate(entry.Power)) })
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
		Body = panel({ Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -20, 1, 0), Radius = 12,
			Top = Color3.fromRGB(96, 30, 40), Bottom = Color3.fromRGB(30, 10, 18), Rail = Color3.fromRGB(255, 214, 110) }, {
			Label = if not props.Compact then heavyLabel({ Position = UDim2.fromOffset(34, 5), Size = UDim2.new(1, -42, 0, 15), MaxSize = 12, Outline = 1.8,
				Gold = false, TextColor3 = Color3.fromRGB(255, 214, 160), TextXAlignment = Enum.TextXAlignment.Left, Text = "Squad Power" }) else nil,
			Value = heavyLabel({ Position = UDim2.fromOffset(34, if props.Compact then 4 else 19), Size = UDim2.new(1, -42, 0, if props.Compact then 34 else 32),
				MaxSize = 26, Outline = 2.4, TextXAlignment = Enum.TextXAlignment.Left, Text = abbreviate(shown) }),
		}),
		Icon = icon("Power", if props.Compact then 44 else 56, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -6, 0.5, 0), ZIndex = 6 }),
		Floater = if delta ~= 0 then heavyLabel({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -6, 0, -2), Size = UDim2.fromOffset(130, 20), MaxSize = 18,
			Outline = 2.2, Gold = false, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = if delta > 0 then Color3.fromRGB(120, 255, 140) else Color3.fromRGB(255, 100, 100),
			Text = (if delta > 0 then "+" else "−") .. abbreviate(math.abs(delta)) }) else nil,
		Tooltip = if hover and #props.Breakdown > 0 then panel({
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, 0, 0, -26),
			Size = UDim2.fromOffset(230, 16 + #props.Breakdown * 18),
			Radius = 10,
			ZIndex = 5,
		}, rows) else nil,
	})
end

return Components
