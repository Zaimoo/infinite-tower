--!strict
-- Focused artifact screens: detail panel & sell summary matching the reference layout.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Catalog = require(ReplicatedStorage.Shared.Config.ArtifactCatalog)
local Stats = require(ReplicatedStorage.Shared.Util.StatFormulas)
local Balance = require(ReplicatedStorage.Shared.Config.StatBalance)
local Icons = require(script.Parent.Parent.Hud.Icons)
local C = require(script.Parent.Components)
local Model = require(script.Parent.Model)
local T = require(script.Parent.Tokens)
local Types = require(script.Parent.Types)
local EquippedHero = require(script.Parent.EquippedHero)
local e = React.createElement
local Screens = {}

function Screens.ItemHeader(props: { Snapshot: Types.Snapshot, Artifact: Types.Artifact, Kept: boolean?, Large: boolean? })
	local artifact = props.Artifact
	local rarity = Catalog.GetRarityInfo(artifact.Rarity)
	local large = props.Large == true
	local owners = Model.ownerIds(props.Snapshot, artifact.UUID)
	local owner = #owners == 1 and props.Snapshot.Heroes[owners[1]] or nil
	local height = if large then 200 else 96
	local previewWidth = if large then 160 else 80
	return e("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height) }, {
		Preview = if owner then e(EquippedHero, { Hero = owner, Artifact = artifact, Size = UDim2.fromOffset(previewWidth, height) }) else e(C.Preview, { Artifact = artifact, Size = UDim2.fromOffset(previewWidth, height) }),
		Name = e(C.Text, { Text = artifact.DisplayName, Position = UDim2.fromOffset(previewWidth + 16, 0), Size = UDim2.new(1, -previewWidth - 16, 0, if large then 64 else 36), TextSize = if large then 24 else 18, FontFace = T.Theme.Fonts.Title }),
		Stars = if large then e(C.Text, { Text = string.rep("★", artifact.Star), Position = UDim2.fromOffset(previewWidth + 16, 66), Size = UDim2.new(1, -previewWidth - 16, 0, 32), TextSize = 26, TextColor3 = T.Gold }) else nil,
		Stats = e(C.Text, { Text = (if props.Kept then "KEPT · " else "") .. string.format("%s · %d★ · %.0f PWR", rarity.Name, artifact.Star, Model.power(artifact)), Position = UDim2.fromOffset(previewWidth + 16, if large then 104 else 36), Size = UDim2.new(1, -previewWidth - 16, 0, 36), TextSize = 14, TextColor3 = rarity.Color }),
		Owner = e(C.Text, { Text = (if owner then owner.DisplayName .. " · Lv." .. owner.Level else Model.ownerText(props.Snapshot, artifact.UUID)) .. (if artifact.Locked then " · Locked" else ""), Position = UDim2.fromOffset(previewWidth + 16, if large then 146 else 66), Size = UDim2.new(1, -previewWidth - 16, 0, if large then 48 else 30), TextSize = 14, TextColor3 = if #Model.ownerIds(props.Snapshot, artifact.UUID) > 0 then T.Equipped else T.Muted }),
	})
end

function Screens.Stats(props: { Before: Types.Artifact?, After: Types.Artifact, Hero: Types.Hero? })
	local old = props.Before
	local before = if old then Catalog.GetStatBreakdown(old.TemplateId, old.Star, old.Rarity) else { Power = 0, DamageMultiplier = 1, ["Attack Speed"] = 0 }
	local after = Catalog.GetStatBreakdown(props.After.TemplateId, props.After.Star, props.After.Rarity)
	local hero = props.Hero
	return e(C.Stack, { Children = {
		Power = e(C.StatRow, { Label = "Weapon power", Before = before.Power, After = after.Power, Order = 1 }),
		Damage = e(C.StatRow, { Label = "Damage multiplier", Before = before.DamageMultiplier, After = after.DamageMultiplier, Format = "×%.2f", Order = 2 }),
		Speed = e(C.StatRow, { Label = "Attack speed", Before = before["Attack Speed"], After = after["Attack Speed"], Format = "%.1f%%", Order = 3 }),
		DPS = if hero and Model.compatible(hero, props.After) then e(C.StatRow, { Label = "Base hero DPS", Before = Stats.GetCombatSnapshot(hero, old).DPS, After = Stats.GetCombatSnapshot(hero, props.After).DPS, Format = "%.1f", Order = 4 }) else nil,
	} })
end

function Screens.MaterialList(props: { Items: { Types.Artifact }, Width: number })
	local columns = math.max(1, math.min(3, math.floor(props.Width / 180)))
	local rows = math.ceil(#props.Items / columns)
	local children: { [string]: any } = {
		Layout = e("UIGridLayout", { CellSize = UDim2.new(1 / columns, -8, 0, 44), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	}
	for index, artifact in props.Items do
		children[artifact.UUID] = e(C.Text, { Text = string.format("%s · %d★", artifact.DisplayName, artifact.Star), TextSize = 14, BackgroundTransparency = 0, BackgroundColor3 = T.Theme.Tones.Deep.Top, LayoutOrder = index })
	end
	return e("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, rows * 52) }, children)
end

--============================================================================
-- DETAIL PANEL (Matching Reference Layout)
-- 1. Large 3D Model preview with Star pill
-- 2. Artifact Name
-- 3. Rarity · Owner status
-- 4. Huge Power number (with comparison delta)
-- 5. 3 Stat Chips (DMG, ATK SPD, DPS)
-- 6. Compact action buttons (Lock, Upgrade, Equip, Sell)
--============================================================================
export type DetailPanelProps = {
	Snapshot: Types.Snapshot,
	Artifact: Types.Artifact,
	Hero: Types.Hero?,
	Busy: boolean,
	OnEquip: () -> (),
	OnUnequip: () -> (),
	OnUpgrade: () -> (),
	OnToggleLock: () -> (),
	OnSell: () -> (),
}

function Screens.DetailPanel(props: DetailPanelProps)
	local artifact = props.Artifact
	local hero = props.Hero
	local snapshot = props.Snapshot
	local rarity = Catalog.GetRarityInfo(artifact.Rarity)
	local owners = Model.ownerIds(snapshot, artifact.UUID)
	local isEquipped = #owners > 0
	local owner = #owners == 1 and snapshot.Heroes[owners[1]] or nil

	local currentArt = hero and hero.EquippedArtifactUUID and snapshot.Artifacts[hero.EquippedArtifactUUID]
	local stats = Catalog.GetStatBreakdown(artifact.TemplateId, artifact.Star, artifact.Rarity)
	local power = Model.power(artifact)

	local deltaPower = if currentArt and currentArt.UUID ~= artifact.UUID then power - Model.power(currentArt) else 0

	local canCompare = hero ~= nil and Model.compatible(hero, artifact)
	local heroDPS = if canCompare then Stats.GetCombatSnapshot(hero, artifact).DPS else nil
	local currentDPS = if canCompare and currentArt then Stats.GetCombatSnapshot(hero, currentArt).DPS else nil
	local dpsDelta = if heroDPS and currentDPS then heroDPS - currentDPS else 0

	local rule = Catalog.GetStarPromotionCost(artifact.Star)
	local maxRank = rule == nil

	return e("Frame", {
		Name = "DetailPanelRoot",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		List = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		-- 1. Preview Host with Star Pill
		PreviewCard = e("Frame", {
			Name = "PreviewCard",
			Size = UDim2.new(1, 0, 0, 160),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			LayoutOrder = 1,
		}, {
			-- Grows into the panel's spare height (it left ~40% empty before), so the weapon is big
			-- and the actions sit at the bottom.
			Flex = e("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
			-- A rarity-lit stage: bright at the top, fading to plum.
			Gradient = e("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, rarity.Color:Lerp(Color3.fromRGB(40, 28, 60), 0.38)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 20, 46)),
				}),
				Rotation = 90,
			}),
			Stroke = e("UIStroke", { Color = rarity.Color, Thickness = 2, Transparency = 0.1 }),
			-- Always the weapon itself (an equipped weapon used to show a tiny hero holding it, too
			-- small to read). The owner is named on the status line under the title.
			Model = e(C.Preview, {
				Artifact = artifact,
				Size = UDim2.fromScale(1, 1),
			}),
			-- Rarity pill (top left of the preview)
			RarityPill = e("Frame", {
				Position = UDim2.fromOffset(8, 8),
				Size = UDim2.fromOffset(0, 24),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = rarity.Color,
				BorderSizePixel = 0,
				ZIndex = 5,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Ink = e("UIStroke", { Color = T.Theme.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
				Pad = e("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
				Text = e(C.Text, {
					Text = string.upper(rarity.Name),
					TextSize = 13,
					TextColor3 = T.Theme.Text.White,
					TextWrapped = false,
					Size = UDim2.fromScale(0, 1),
					AutomaticSize = Enum.AutomaticSize.X,
				}),
			}),
		}),
		-- 2. Artifact name, with its stars out of seven under it
		Name = e(C.Text, {
			Text = artifact.DisplayName,
			FontFace = T.Theme.Fonts.Title,
			TextSize = 20,
			TextColor3 = T.Text,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 26),
			LayoutOrder = 2,
		}),
		Stars = e(C.Text, {
			Text = string.format("<font color=\"#FFD678\">%s</font><font color=\"#6A5A8C\">%s</font>", string.rep("★", artifact.Star), string.rep("★", math.max(0, Catalog.MaxStars - artifact.Star))),
			RichText = true, -- built from numbers only
			FontFace = T.Theme.Fonts.Number,
			TextSize = 20,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 22),
			LayoutOrder = 3,
		}),
		-- 3. Who holds it
		StatusLine = e(C.Text, {
			Text = if owner then "Equipped by " .. owner.DisplayName elseif isEquipped then "Equipped" else "Not equipped",
			FontFace = T.Theme.Fonts.Body,
			TextSize = 13,
			TextColor3 = if isEquipped then T.Good else T.Muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 18),
			LayoutOrder = 4,
		}),
		-- 4. Power badge, with the change against the picked hero's current weapon
		PowerDisplay = e("Frame", {
			Name = "PowerDisplay",
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1,
			LayoutOrder = 5,
		}, {
			Power = e(C.PowerBadge, {
				Value = power, Delta = deltaPower, Large = true,
				AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0),
			}),
		}),
		-- 5. 3 Stat Chips (DMG, ATK SPD, DPS)
		ChipsRow = e("Frame", {
			Name = "ChipsRow",
			Size = UDim2.new(1, 0, 0, 50),
			BackgroundTransparency = 1,
			LayoutOrder = 6,
		}, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalFlex = Enum.UIFlexAlignment.Fill, SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			DmgChip = e(C.StatChip, {
				Label = "DMG MULT",
				Value = string.format("×%.2f", stats.DamageMultiplier),
				Order = 1,
			}),
			SpeedChip = e(C.StatChip, {
				Label = "ATK SPEED",
				Value = string.format("+%.1f%%", stats["Attack Speed"]),
				Order = 2,
			}),
			DpsChip = e(C.StatChip, {
				Label = if hero then string.sub(hero.DisplayName, 1, 8) .. " DPS" else "BASE DPS",
				Value = if heroDPS then Balance.Format(heroDPS) else "--",
				Color = if dpsDelta > 0.001 then T.Good else T.Text,
				Order = 3,
			}),
		}),
		-- 6. Actions: the two things players do most are big (Equip, Upgrade); Lock and Sell sit
		-- under them. A disabled button says why on hover.
		ActionRow = e("Frame", {
			Name = "ActionRow",
			Size = UDim2.new(1, 0, 0, 104),
			BackgroundTransparency = 1,
			LayoutOrder = 7,
		}, {
			EquipBtn = e(C.Button, {
				Name = "DetailEquipButton",
				Icon = "Equipped",
				Intent = if isEquipped then "Secondary" else "Confirm",
				Text = if isEquipped then "Unequip" else "Equip",
				Disabled = props.Busy,
				OnActivate = if isEquipped then props.OnUnequip else props.OnEquip,
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.new(0.55, -4, 0, 52),
				FocusOrder = 1,
			}),
			UpgradeBtn = e(C.Button, {
				Name = "DetailUpgradeButton",
				Icon = "Forge",
				Text = if maxRank then "Max 7★" else "Upgrade",
				Intent = if maxRank then nil else "Primary",
				Disabled = props.Busy or maxRank,
				Tooltip = if maxRank then "This weapon is already at 7★." else nil,
				OnActivate = props.OnUpgrade,
				Position = UDim2.new(0.55, 4, 0, 0),
				Size = UDim2.new(0.45, -4, 0, 52),
				FocusOrder = 2,
			}),
			LockBtn = e(C.Button, {
				Name = "DetailLockButton",
				Icon = "Lock",
				Intent = "Secondary",
				Text = if artifact.Locked then "Unlock" else "Lock",
				Selected = artifact.Locked == true,
				Disabled = props.Busy,
				Tooltip = "Locked weapons can't be sold or used as upgrade material.",
				OnActivate = props.OnToggleLock,
				Position = UDim2.fromOffset(0, 60),
				Size = UDim2.new(0.5, -4, 0, 44),
				FocusOrder = 3,
			}),
			SellBtn = e(C.Button, {
				Name = "DetailSellButton",
				Icon = "Hammer",
				Intent = "Danger",
				Text = "Sell",
				Accent = T.Bad,
				Disabled = props.Busy or isEquipped or artifact.Locked == true,
				Tooltip = if isEquipped then "Unequip it first to sell." elseif artifact.Locked then "Unlock it first to sell." else nil,
				OnActivate = props.OnSell,
				Position = UDim2.new(0.5, 4, 0, 60),
				Size = UDim2.new(0.5, -4, 0, 44),
				FocusOrder = 4,
			}),
		}),
	})
end

--============================================================================
-- SELL SUMMARY (Shown in Right Pane during Sell Mode)
--============================================================================
export type SellSummaryProps = {
	SelectedCount: number,
	TotalGold: number,
	RarityCounts: { [number]: number },
	Busy: boolean,
	Message: string,
	OnExitSell: () -> (),
}

function Screens.SellSummary(props: SellSummaryProps)
	return e("Frame", {
		Name = "SellSummaryRoot",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		List = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 12),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		-- Header Badge
		Header = e("Frame", {
			Size = UDim2.new(1, 0, 0, 48),
			BackgroundTransparency = 1,
			LayoutOrder = 1,
		}, {
			Hammer = e("Frame", {
				Position = UDim2.fromOffset(8, 8),
				Size = UDim2.fromOffset(32, 32),
				BackgroundTransparency = 1,
			}, {
				Art = e(Icons.Icon, { Name = "Hammer", Size = 32 }),
			}),
			Title = e(C.Text, {
				Text = "SELL WEAPONS",
				FontFace = T.Theme.Fonts.Title,
				TextSize = 20,
				TextColor3 = T.Bad,
				Position = UDim2.fromOffset(48, 8),
				Size = UDim2.new(1, -56, 0, 32),
			}),
		}),
		-- Big Total Gold Card
		GoldCard = e("Frame", {
			Size = UDim2.new(1, 0, 0, 100),
			BackgroundColor3 = Color3.fromRGB(16, 12, 24),
			BorderSizePixel = 0,
			LayoutOrder = 2,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
			Outline = e("UIStroke", { Color = T.Gold, Thickness = 1.4 }),
			Count = e(C.Text, {
				Text = string.format("%d ARTIFACTS SELECTED", props.SelectedCount),
				FontFace = T.Theme.Fonts.Body,
				TextSize = 13,
				TextColor3 = T.Muted,
				TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.fromOffset(0, 12),
				Size = UDim2.new(1, 0, 0, 20),
			}),
			Gold = e(C.Text, {
				Text = string.format("+%s GOLD", Balance.Format(props.TotalGold)),
				FontFace = T.Theme.Fonts.Number,
				TextSize = 26,
				TextColor3 = T.Gold,
				TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.fromOffset(0, 38),
				Size = UDim2.new(1, 0, 0, 36),
			}),
		}),
		-- Rarity breakdown
		Breakdown = e("Frame", {
			Size = UDim2.new(1, 0, 0, 80),
			BackgroundColor3 = T.Theme.Tones.Deep.Top,
			BorderSizePixel = 0,
			LayoutOrder = 3,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Stroke = e("UIStroke", { Color = T.Theme.Tones.Deep.Rail, Thickness = 1, Transparency = 0.5 }),
			Title = e(C.Text, {
				Text = "SELECTION BREAKDOWN",
				FontFace = T.Theme.Fonts.Title,
				TextSize = 13,
				TextColor3 = T.Gold,
				Position = UDim2.fromOffset(12, 8),
				Size = UDim2.new(1, -24, 0, 18),
			}),
			Counts = e("Frame", {
				Position = UDim2.fromOffset(12, 30),
				Size = UDim2.new(1, -24, 0, 42),
				BackgroundTransparency = 1,
			}, {
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 10),
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),
				C = e(C.Text, { Text = string.format("Common: %d", props.RarityCounts[1] or 0), TextSize = 13, TextColor3 = Catalog.GetRarityInfo(1).Color, Size = UDim2.fromOffset(70, 20) }),
				U = e(C.Text, { Text = string.format("Uncommon: %d", props.RarityCounts[2] or 0), TextSize = 13, TextColor3 = Catalog.GetRarityInfo(2).Color, Size = UDim2.fromOffset(80, 20) }),
				R = e(C.Text, { Text = string.format("Rare+: %d", (props.RarityCounts[3] or 0) + (props.RarityCounts[4] or 0) + (props.RarityCounts[5] or 0)), TextSize = 13, TextColor3 = Catalog.GetRarityInfo(3).Color, Size = UDim2.fromOffset(70, 20) }),
			}),
		}),
		-- Notice / Safety advice
		Advice = e("Frame", {
			Size = UDim2.new(1, 0, 0, 90),
			BackgroundColor3 = Color3.fromRGB(18, 14, 26),
			BorderSizePixel = 0,
			LayoutOrder = 4,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Stroke = e("UIStroke", { Color = T.Theme.Tones.Slate.Rail, Thickness = 1, Transparency = 0.4 }),
			Hint = e(C.Text, {
				Text = "• Tap cards to toggle selection\n• Equipped and Locked items are protected\n• Use bottom buttons for quick-selection",
				FontFace = T.Theme.Fonts.Body,
				TextSize = 13,
				TextColor3 = T.Muted,
				Position = UDim2.fromOffset(12, 10),
				Size = UDim2.new(1, -24, 1, -20),
			}),
		}),
		-- No second exit here: the action bar's Back is the one way out of sell mode.
	})
end

--============================================================================
-- UPGRADE REVIEW (the confirm step before consuming materials)
-- Kept weapon → result, big stat changes, the weapons that will be destroyed and the cost, all on
-- one screen without scrolling (it used to be a long text list with raw numbers like 4240438.6).
--============================================================================
local function reviewCard(artifact: Types.Artifact, label: string, star: number, glow: boolean)
	local rarity = Catalog.GetRarityInfo(artifact.Rarity)
	return {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
		Fill = e("UIGradient", { Rotation = 90, Color = ColorSequence.new(rarity.Color:Lerp(Color3.fromRGB(40, 28, 60), 0.4), Color3.fromRGB(28, 18, 44)) }),
		Ink = e("UIStroke", { Color = if glow then T.Gold else rarity.Color, Thickness = if glow then 3 else 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		Band = e("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Color3.fromRGB(10, 6, 14), BackgroundTransparency = 0.3, ZIndex = 3 }, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
			Label = e(C.Text, { Text = label, TextSize = 15, TextColor3 = if glow then T.Gold else T.Text, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.6, 0, 1, 0), ZIndex = 4 }),
			Stars = e(C.Text, { Text = string.format("%d★", star), TextSize = if glow then 22 else 18, FontFace = T.Theme.Fonts.Number, TextColor3 = T.Gold,
				TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 0), Size = UDim2.new(0.4, 0, 1, 0), ZIndex = 4 }),
		}),
		Model = e("Frame", { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 1, -58), BackgroundTransparency = 1, ZIndex = 2 }, {
			Preview = e(C.Preview, { Artifact = artifact, Size = UDim2.fromScale(1, 1) }),
		}),
		Name = e(C.Text, { Text = artifact.DisplayName, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 6, 1, -4), Size = UDim2.new(1, -12, 0, 24), ZIndex = 3 }),
	}
end

local function deltaChip(order: number, label: string, before: number, after: number, show: (number) -> string)
	local delta = after - before
	return e("Frame", { LayoutOrder = order, Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1) }, {
		Flex = e("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
		Fill = e("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(62, 44, 92), Color3.fromRGB(32, 22, 52)) }),
		Ink = e("UIStroke", { Color = T.Theme.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		Label = e(C.Text, { Text = label, TextSize = 14, FontFace = T.Theme.Fonts.Body, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, 20) }),
		Value = e(C.Text, { Text = show(after), TextSize = 24, FontFace = T.Theme.Fonts.Number, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(4, 24), Size = UDim2.new(1, -8, 0, 30) }),
		Change = e(C.Text, {
			Text = if math.abs(delta) < 1e-6 then "no change" else string.format("%s%s", if delta > 0 then "+" else "-", (string.gsub(show(math.abs(delta)), "^×", ""))),
			TextSize = 16, FontFace = T.Theme.Fonts.Number, TextColor3 = if delta > 1e-6 then T.Good elseif delta < -1e-6 then T.Bad else T.Muted,
			TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(4, 54), Size = UDim2.new(1, -8, 0, 22),
		}),
	})
end

export type ReviewProps = {
	Snapshot: Types.Snapshot,
	Before: Types.Artifact,
	After: Types.Artifact,
	Materials: { Types.Artifact },
	Gold: number,
	Gems: number,
	Owner: Types.Hero?,
	Changed: boolean,
}

function Screens.UpgradeReview(props: ReviewProps)
	local before = Catalog.GetStatBreakdown(props.Before.TemplateId, props.Before.Star, props.Before.Rarity)
	local after = Catalog.GetStatBreakdown(props.After.TemplateId, props.After.Star, props.After.Rarity)
	local owner = props.Owner
	local withDps = owner ~= nil and Model.compatible(owner, props.After)
	local short = function(n: number) return Balance.Format(n) end
	local tiles: { [string]: any } = {
		Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center }),
	}
	for i, material in props.Materials do
		tiles["M" .. i] = e("Frame", { LayoutOrder = i, Size = UDim2.fromOffset(84, 84), BackgroundTransparency = 1 }, {
			Tile = e(C.ArtifactTile, { Snapshot = props.Snapshot, Artifact = material, Material = true, Order = i, ShowPreview = true, OnSelect = function() end }),
		})
	end
	local costParts = { string.format("%s Gold", short(props.Gold)) }
	if (props.Gems or 0) > 0 then table.insert(costParts, string.format("%s Gems", short(props.Gems))) end
	local balanceParts = { string.format("%s Gold", short(props.Snapshot.Gold - props.Gold)) }
	if (props.Gems or 0) > 0 then table.insert(balanceParts, string.format("%s Gems", short(props.Snapshot.Gems - props.Gems))) end

	return e("Frame", { Name = "UpgradeReview", Size = UDim2.new(1, 0, 1, -60), BackgroundTransparency = 1 }, {
		-- 1. Kept weapon → result
		Kept = e("Frame", { Name = "KeptCard", Size = UDim2.new(0.4, -8, 0.46, 0), BackgroundColor3 = Color3.new(1, 1, 1) },
			reviewCard(props.Before, "KEPT", props.Before.Star, false)),
		Arrow = e(C.Text, { Text = "→", TextSize = 48, FontFace = T.Theme.Fonts.Number, TextColor3 = T.Gold, TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromScale(0.4, 0), Size = UDim2.fromScale(0.2, 0.46) }),
		Result = e("Frame", { Name = "ResultCard", Position = UDim2.new(0.6, 8, 0, 0), Size = UDim2.new(0.4, -8, 0.46, 0), BackgroundColor3 = Color3.new(1, 1, 1) },
			reviewCard(props.After, "RESULT", props.After.Star, true)),
		-- 2. What changes
		Stats = e("Frame", { Name = "StatChanges", Position = UDim2.new(0, 0, 0.46, 10), Size = UDim2.new(1, 0, 0, 80), BackgroundTransparency = 1 }, {
			Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
			Power = deltaChip(1, "WEAPON POWER", before.Power, after.Power, short),
			Damage = deltaChip(2, "DAMAGE", before.DamageMultiplier, after.DamageMultiplier, function(n) return string.format("×%.2f", n) end),
			Third = if withDps and owner then deltaChip(3, string.upper(owner.DisplayName) .. " DPS",
					Stats.GetCombatSnapshot(owner, props.Before).DPS, Stats.GetCombatSnapshot(owner, props.After).DPS, short)
				else deltaChip(3, "ATTACK SPEED", before["Attack Speed"], after["Attack Speed"], function(n) return string.format("%.1f%%", n) end),
		}),
		-- 3. What it costs: the weapons destroyed, and Gold
		Destroyed = e("Frame", { Name = "Destroyed", Position = UDim2.new(0, 0, 0.46, 100), Size = UDim2.new(0.62, 0, 0, 118), BackgroundTransparency = 1 }, {
			Label = e(C.Text, { Text = if props.Changed then "INVENTORY CHANGED · GO BACK AND REVIEW" else "WILL BE DESTROYED", TextSize = 15, TextColor3 = T.Bad, Size = UDim2.new(1, 0, 0, 22) }),
			Tiles = e("Frame", { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 88), BackgroundTransparency = 1 }, tiles),
		}),
		Cost = e("Frame", { Name = "Cost", Position = UDim2.new(0.62, 8, 0.46, 100), Size = UDim2.new(0.38, -8, 0, 110), BackgroundColor3 = Color3.new(1, 1, 1) }, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
			Fill = e("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(96, 64, 24), Color3.fromRGB(34, 20, 10)) }),
			Ink = e("UIStroke", { Color = T.Theme.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			Label = e(C.Text, { Text = "COST", TextSize = 14, FontFace = T.Theme.Fonts.Body, TextColor3 = T.Muted, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 20) }),
			Amount = e(C.Text, { Text = table.concat(costParts, " · "), TextSize = 24, FontFace = T.Theme.Fonts.Number, TextColor3 = T.Gold, Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -24, 0, 34) }),
			After = e(C.Text, { Text = "You'll have " .. table.concat(balanceParts, " · "), TextSize = 14, FontFace = T.Theme.Fonts.Body, TextColor3 = T.Text, Position = UDim2.fromOffset(12, 66), Size = UDim2.new(1, -24, 0, 36) }),
		}),
	})
end

return Screens
