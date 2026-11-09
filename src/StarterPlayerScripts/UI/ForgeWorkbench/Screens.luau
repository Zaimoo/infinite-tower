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
			Padding = UDim.new(0, 8),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		-- 1. Preview Host with Star Pill
		PreviewCard = e("Frame", {
			Name = "PreviewCard",
			Size = UDim2.new(1, 0, 0, 160),
			BackgroundColor3 = Color3.fromRGB(16, 12, 24),
			BorderSizePixel = 0,
			LayoutOrder = 1,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
			Gradient = e("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, rarity.Color:Lerp(Color3.fromRGB(24, 18, 34), 0.65)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 8, 16)),
				}),
				Rotation = 90,
			}),
			Stroke = e("UIStroke", { Color = rarity.Color, Thickness = 1.4, Transparency = 0.3 }),
			-- Always the weapon itself (an equipped weapon used to show a tiny hero holding it, too
			-- small to read). The owner is named on the status line under the title.
			Model = e(C.Preview, {
				Artifact = artifact,
				Size = UDim2.fromScale(1, 1),
			}),
			-- Star Pill (Top Left of preview)
			StarPill = e("Frame", {
				Position = UDim2.fromOffset(8, 8),
				Size = UDim2.fromOffset(68, 24),
				BackgroundColor3 = Color3.fromRGB(24, 18, 32),
				BorderSizePixel = 0,
				ZIndex = 5,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
				Stroke = e("UIStroke", { Color = T.Gold, Thickness = 1.2 }),
				Text = e(C.Text, {
					Text = string.format("★ %d / 7", artifact.Star),
					FontFace = T.Theme.Fonts.Number,
					TextSize = 12,
					TextColor3 = T.Gold,
					TextXAlignment = Enum.TextXAlignment.Center,
					Size = UDim2.fromScale(1, 1),
				}),
			}),
		}),
		-- 2. Artifact Name
		Name = e(C.Text, {
			Text = artifact.DisplayName,
			FontFace = T.Theme.Fonts.Title,
			TextSize = 20,
			TextColor3 = T.Text,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 26),
			LayoutOrder = 2,
		}),
		-- 3. Rarity · Owner Status
		StatusLine = e(C.Text, {
			Text = string.format(
				"%s  ·  %s",
				rarity.Name,
				if owner then "Equipped by " .. owner.DisplayName elseif isEquipped then "Equipped" else "Unequipped"
			),
			FontFace = T.Theme.Fonts.Body,
			TextSize = 13,
			TextColor3 = if isEquipped then T.Equipped else rarity.Color,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 20),
			LayoutOrder = 3,
		}),
		-- 4. Huge Power Number + Delta
		PowerDisplay = e("Frame", {
			Name = "PowerDisplay",
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundTransparency = 1,
			LayoutOrder = 4,
		}, {
			Power = e(C.Text, {
				Text = string.format("%s PWR", Balance.Format(power)) .. (if deltaPower ~= 0 then string.format(" (%s%s)", if deltaPower > 0 then "+" else "", Balance.Format(deltaPower)) else ""),
				FontFace = T.Theme.Fonts.Number,
				TextSize = 24,
				TextColor3 = if deltaPower > 0 then T.Good elseif deltaPower < 0 then T.Bad else T.Gold,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.fromScale(1, 1),
			}),
		}),
		-- 5. 3 Stat Chips (DMG, ATK SPD, DPS)
		ChipsRow = e("Frame", {
			Name = "ChipsRow",
			Size = UDim2.new(1, 0, 0, 50),
			BackgroundTransparency = 1,
			LayoutOrder = 5,
		}, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
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
		-- 6. Actions as labelled buttons in a 2 × 2 grid (they were 22 px icons with 10 px labels).
		-- Upgrade is the gold primary; Sell is red; a disabled button says why on hover.
		ActionRow = e("Frame", {
			Name = "ActionRow",
			Size = UDim2.new(1, 0, 0, 100),
			BackgroundTransparency = 1,
			LayoutOrder = 6,
		}, {
			Layout = e("UIGridLayout", {
				CellSize = UDim2.new(0.5, -4, 0, 46),
				CellPadding = UDim2.fromOffset(8, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			UpgradeBtn = e(C.Button, {
				Name = "DetailUpgradeButton",
				Icon = "Forge",
				Text = if maxRank then "Max 7★" else "Upgrade",
				Primary = not maxRank,
				Disabled = props.Busy or maxRank,
				Tooltip = if maxRank then "This weapon is already at 7★." else nil,
				OnActivate = props.OnUpgrade,
				Order = 1,
			}),
			EquipBtn = e(C.Button, {
				Name = "DetailEquipButton",
				Icon = "Equipped",
				Text = if isEquipped then "Unequip" else "Equip",
				Disabled = props.Busy,
				OnActivate = if isEquipped then props.OnUnequip else props.OnEquip,
				Order = 2,
			}),
			LockBtn = e(C.Button, {
				Name = "DetailLockButton",
				Icon = "Lock",
				Text = if artifact.Locked then "Unlock" else "Lock",
				Selected = artifact.Locked == true,
				Disabled = props.Busy,
				Tooltip = "Locked weapons can't be sold or used as upgrade material.",
				OnActivate = props.OnToggleLock,
				Order = 3,
			}),
			SellBtn = e(C.Button, {
				Name = "DetailSellButton",
				Icon = "Hammer",
				Text = "Sell",
				Accent = T.Bad,
				Disabled = props.Busy or isEquipped or artifact.Locked == true,
				Tooltip = if isEquipped then "Unequip it first to sell." elseif artifact.Locked then "Unlock it first to sell." else nil,
				OnActivate = props.OnSell,
				Order = 4,
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

return Screens
