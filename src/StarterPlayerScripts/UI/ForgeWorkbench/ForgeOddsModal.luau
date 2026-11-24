--!strict
-- StarterPlayerScripts/UI/ForgeWorkbench/ForgeOddsModal.luau
-- "Weapons & Odds" modal for the Open Forge, mirroring HeroOddsModal ("View Heroes & Odds"):
--   * Top RatesBox: 7 rarity rate pills (rarest first), Open Forge rules, and live Pedestals + Roll Luck state
--   * Scrollable list by rarity tier (Mythical -> Common): tier header bar + 2-column 96px weapon cards
--     featuring live 3D weapon previews, archetype icon, variant, 1★ stats, exact per-pedestal chance,
--     Relic-floor scaled Gold pedestal price, and OWNED / OWNED ×N badges.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Catalog = require(ReplicatedStorage.Shared.Config.ArtifactCatalog)
local Balance = require(ReplicatedStorage.Shared.Config.StatBalance)
local TreeConfig = require(ReplicatedStorage.Shared.Config.FortressTreeConfig)
local RollLuck = require(ReplicatedStorage.Shared.Util.RollLuck)

local C = require(script.Parent.Components)
local T = require(script.Parent.Tokens)
local Kit = require(script.Parent.Parent.Kit)
local Theme = require(script.Parent.Parent.Hud.Theme)
local Icons = require(script.Parent.Parent.Hud.Icons)
local ArtifactPreview = require(script.Parent.Parent.ArtifactPreview)
local Types = require(script.Parent.Types)

local e = React.createElement

local TEXT = Color3.fromRGB(246, 242, 255)
local SUBTEXT = Color3.fromRGB(214, 204, 232)
local GOLD_TEXT = Color3.fromRGB(255, 224, 118)
local ENHANCED_TEXT = Color3.fromRGB(255, 214, 110)

local WEAPON_TO_ARCHETYPE: { [string]: string } = {}
for role, weaponType in pairs(Catalog.ArchetypeWeaponType) do
	WEAPON_TO_ARCHETYPE[weaponType] = role
end

local function readable(color: Color3): Color3
	return color:Lerp(Color3.new(1, 1, 1), 0.40)
end

local function formatPercent(pct: number): string
	if pct >= 10 then
		return string.format("%.1f", pct)
	end
	if pct >= 0.1 then
		return (string.gsub(string.format("%.2f", pct), "0$", ""))
	end
	return (string.gsub(string.format("%.3f", pct), "0$", ""))
end

local function countOwned(snapshot: Types.Snapshot): { [string]: number }
	local copies: { [string]: number } = {}
	for _, artifact in pairs(snapshot.Artifacts or {}) do
		if artifact and artifact.TemplateId then
			copies[artifact.TemplateId] = (copies[artifact.TemplateId] or 0) + 1
		end
	end
	return copies
end

type WeaponCardProps = {
	Seed: Catalog.ArtifactSeed,
	ChancePct: number,
	Cost: number,
	Owned: number,
	Order: number,
}

local function WeaponOddsCard(props: WeaponCardProps)
	local seed = props.Seed
	local previewRef = React.useRef(nil :: Frame?)
	local tier = math.clamp(math.floor(seed.RarityTier or 1), 1, 7)
	local color = Theme.RarityColor(tier)

	React.useEffect(function()
		local host = previewRef.current
		if not host then
			return
		end
		ArtifactPreview.Show(host, seed.TemplateId, { Spin = false })
		return function()
			local existing = host:FindFirstChild("ArtifactModelPreview")
			if existing then
				existing:Destroy()
			end
		end
	end, { seed.TemplateId })

	local archetype = WEAPON_TO_ARCHETYPE[seed.Type] or "Vanguard"
	local weaponLabel = string.gsub(seed.Type, "_", " & ")
	local power, speedBonus = Catalog.CalculateEffectiveStats(1, tier, nil, seed.TemplateId)
	local dmgMult = 1 + power / 40
	local statsText = if speedBonus > 0
		then string.format("1★  PWR <b>%s</b>   DMG <b>%.2f×</b>   SPD <b>+%d%%</b>", Balance.Format(power), dmgMult, math.round(speedBonus * 100))
		else string.format("1★  PWR <b>%s</b>   DMG <b>%.2f×</b>", Balance.Format(power), dmgMult)

	local cardTop = Kit.Tokens.Surface.Inset.Top:Lerp(color, 0.12)
	local cardBottom = Color3.fromRGB(16, 12, 26)

	return e("Frame", {
		Name = "Card_" .. seed.TemplateId,
		LayoutOrder = props.Order,
		Size = UDim2.new(0.5, -6, 1, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 4,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 11) }),
		Fill = e("UIGradient", { Rotation = 90, Color = ColorSequence.new(cardTop, cardBottom) }),
		Ink = e("UIStroke", { Color = T.Theme.Ink, Thickness = 2.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		Rail = e("Frame", {
			Position = UDim2.fromOffset(2, 2),
			Size = UDim2.new(1, -4, 1, -4),
			BackgroundTransparency = 1,
			ZIndex = 4,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 9) }),
			Stroke = e("UIStroke", {
				Color = color,
				Thickness = if seed.IsHighStat then 1.6 else 1.2,
				Transparency = if seed.IsHighStat then 0.15 else 0.38,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		}),

		-- Left 76x76 3D Weapon Preview Box (mirrors HeroOddsModal's 76x76 PortraitBox)
		PreviewBox = e("Frame", {
			ref = previewRef,
			Name = "PreviewBox",
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.fromOffset(76, 76),
			BackgroundColor3 = color:Lerp(Color3.fromRGB(10, 6, 16), 0.76),
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 5,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
			Stroke = e("UIStroke", {
				Color = color,
				Thickness = if seed.IsHighStat then 2.2 else 1.5,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		}),

		-- Middle Column: Weapon Name, Archetype + Type, Variant, 1★ Stats
		NameLbl = e("TextLabel", {
			Position = UDim2.fromOffset(96, 10),
			Size = UDim2.new(1, -214, 0, 19),
			BackgroundTransparency = 1,
			FontFace = T.Theme.Fonts.Title,
			Text = seed.DisplayName,
			TextSize = 14,
			TextColor3 = TEXT,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 6,
		}),
		RoleIcon = e("Frame", {
			Position = UDim2.fromOffset(96, 31),
			Size = UDim2.fromOffset(16, 16),
			BackgroundTransparency = 1,
			ZIndex = 6,
		}, {
			Art = e(Icons.Icon, { Name = archetype, Size = 16 }),
		}),
		RoleLbl = e("TextLabel", {
			Position = UDim2.fromOffset(116, 31),
			Size = UDim2.new(1, -224, 0, 16),
			BackgroundTransparency = 1,
			FontFace = T.Theme.Fonts.Body,
			Text = string.format("%s  ·  %s", archetype, weaponLabel),
			TextSize = 11,
			TextColor3 = SUBTEXT,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 6,
		}),
		VariantLbl = e("TextLabel", {
			Position = UDim2.fromOffset(96, 49),
			Size = UDim2.new(1, -206, 0, 15),
			BackgroundTransparency = 1,
			FontFace = T.Theme.Fonts.Body,
			Text = if seed.IsHighStat then "Enhanced ★+  ·  1.20× stats" else "Standard  ·  1.00× stats",
			TextSize = 11,
			TextColor3 = if seed.IsHighStat then ENHANCED_TEXT else readable(color),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 6,
		}),
		StatsLbl = e("TextLabel", {
			Position = UDim2.fromOffset(96, 68),
			Size = UDim2.new(1, if props.Owned > 0 then -184 else -108, 0, 16),
			BackgroundTransparency = 1,
			FontFace = T.Theme.Fonts.Body,
			RichText = true,
			Text = statsText,
			TextSize = 11,
			TextColor3 = TEXT,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 6,
		}),

		-- Right Column: Exact per-pedestal chance, Pedestal Gold cost, and OWNED stud
		OddsLbl = e("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 10),
			Size = UDim2.fromOffset(112, 16),
			BackgroundTransparency = 1,
			FontFace = T.Theme.Fonts.Body,
			RichText = true,
			Text = string.format("<b>%s%%</b> / pedestal", formatPercent(props.ChancePct)),
			TextSize = 11,
			TextColor3 = readable(color),
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 6,
		}),
		PriceLbl = e("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 29),
			Size = UDim2.fromOffset(112, 18),
			BackgroundTransparency = 1,
			FontFace = T.Theme.Fonts.Number,
			Text = Balance.Format(props.Cost) .. " Gold",
			TextSize = 13,
			TextColor3 = GOLD_TEXT,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 6,
		}, {
			Ink = e("UIStroke", { Color = T.Theme.Ink, Thickness = 1.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }),
		}),
		OwnedStud = if props.Owned > 0
			then e("Frame", {
				Name = "OwnedStud",
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -10, 1, -8),
				Size = UDim2.fromOffset(78, 20),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				ZIndex = 6,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
				Fill = e("UIGradient", {
					Rotation = 90,
					Color = ColorSequence.new(Kit.Tokens.Intent.Confirm.Top, Kit.Tokens.Intent.Confirm.Bottom),
				}),
				Stroke = e("UIStroke", { Color = T.Theme.Ink, Thickness = 1.6 }),
				Text = e("TextLabel", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					FontFace = T.Theme.Fonts.Title,
					Text = if props.Owned > 1 then string.format("OWNED ×%d", props.Owned) else "OWNED",
					TextSize = 10,
					TextColor3 = Color3.new(1, 1, 1),
					ZIndex = 7,
				}),
			})
			else nil,
	})
end

export type Props = {
	Snapshot: Types.Snapshot,
	RollLuck: number,
	Pedestals: number,
	OnClose: () -> (),
}

local function ForgeOddsModal(props: Props)
	local rollLuck = props.RollLuck or 0
	local pedestals = props.Pedestals or 1
	local boosted = RollLuck.ApplyLuck(Catalog.RollRates, rollLuck)
	local tierCount = #Catalog.RollRates
	local ownedCopies = React.useMemo(function()
		return countOwned(props.Snapshot)
	end, { props.Snapshot })

	-- Group all 84 Open Forge weapons by rarity tier (1..7), Enhanced first then Standard within each tier
	local weaponsByTier = React.useMemo(function()
		local map: { [number]: { Catalog.ArtifactSeed } } = {}
		for _, id in ipairs(Catalog.CatalogOrder) do
			local seed = Catalog.Seeds[id]
			if seed and seed.RarityTier >= 1 and seed.RarityTier <= tierCount then
				local bucket = map[seed.RarityTier]
				if not bucket then
					bucket = {}
					map[seed.RarityTier] = bucket
				end
				table.insert(bucket, seed)
			end
		end
		for tier = 1, tierCount do
			local bucket = map[tier]
			if bucket then
				table.sort(bucket, function(a, b)
					if a.IsHighStat ~= b.IsHighStat then
						return a.IsHighStat == true
					end
					if a.Type ~= b.Type then
						return a.Type < b.Type
					end
					return a.DisplayName < b.DisplayName
				end)
			end
		end
		return map
	end, {})

	-- Top Rate Pills (rarest first: Mythical -> Common)
	local ratePills: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	}
	for i = 1, tierCount do
		local tier = tierCount - i + 1
		local info = Catalog.GetRarityInfo(tier)
		local color = Theme.RarityColor(tier)
		local pct = (boosted[tier] or 0) * 100
		ratePills["RatePill_" .. tier] = e("Frame", {
			Name = "RatePill_" .. tier,
			LayoutOrder = i,
			BackgroundColor3 = Color3.fromRGB(16, 12, 24),
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 22),
			ZIndex = 5,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 5) }),
			Stroke = e("UIStroke", { Color = color, Thickness = 1.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			Pad = e("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }),
			Label = e("TextLabel", {
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromScale(0, 1),
				BackgroundTransparency = 1,
				FontFace = T.Theme.Fonts.Number,
				Text = string.format("%s %s%%", info.Name, formatPercent(pct)),
				TextSize = 11,
				TextColor3 = readable(color),
				ZIndex = 6,
			}),
		})
	end

	-- Scroll body: Tier Header + 2-column Weapon Cards per tier (rarest first)
	local scrollChildren: { [string]: any } = {
		Layout = e("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
		Pad = e("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 16),
			PaddingLeft = UDim.new(0, 2),
			PaddingRight = UDim.new(0, 10),
		}),
	}
	local order = 0
	local archetypeCount = math.max(1, #Catalog.ArchetypeTypes)
	for tier = tierCount, 1, -1 do
		local seeds = weaponsByTier[tier] or {}
		if #seeds == 0 then
			continue
		end
		local info = Catalog.GetRarityInfo(tier)
		local color = Theme.RarityColor(tier)
		local tierRate = boosted[tier] or 0
		local stdGold = Balance.Format(Catalog.RarityStandardPedestalCost[tier] or 0)
		local enhGold = Balance.Format(Catalog.RarityEnhancedPedestalCost[tier] or 0)
		local floorAnchor = Catalog.RarityTargetFloor[tier] or 1

		order += 1
		scrollChildren["TierHeader_" .. tier] = e("Frame", {
			Name = "TierHeader_" .. tier,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 4,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 9) }),
			Fill = e("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new(
					Kit.Tokens.Surface.Panel.Top:Lerp(color, 0.22),
					Kit.Tokens.Surface.Inset.Bottom:Lerp(color, 0.10)
				),
			}),
			Ink = e("UIStroke", { Color = T.Theme.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			Rail = e("Frame", {
				Position = UDim2.fromOffset(2, 2),
				Size = UDim2.new(1, -4, 1, -4),
				BackgroundTransparency = 1,
				ZIndex = 4,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 7) }),
				Stroke = e("UIStroke", { Color = color, Thickness = 1.4, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			}),
			Left = e("TextLabel", {
				Position = UDim2.fromOffset(14, 0),
				Size = UDim2.new(0.45, 0, 1, 0),
				BackgroundTransparency = 1,
				FontFace = T.Theme.Fonts.Title,
				Text = string.format("%s  ·  FLOOR %d SCALE", string.upper(info.Name), floorAnchor),
				TextSize = 14,
				TextColor3 = readable(color),
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 5,
			}, {
				Ink = e("UIStroke", { Color = T.Theme.Ink, Thickness = 1.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }),
			}),
			Right = e("TextLabel", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -14, 0, 0),
				Size = UDim2.new(0.55, 0, 1, 0),
				BackgroundTransparency = 1,
				FontFace = T.Theme.Fonts.Body,
				RichText = true,
				Text = string.format(
					"<b>%s%%</b> for tier  ·  <font color=\"#FFE076\">Std %s / Enh %s Gold</font>",
					formatPercent(tierRate * 100),
					stdGold,
					enhGold
				),
				TextSize = 12,
				TextColor3 = TEXT,
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 5,
			}),
		})

		-- Two weapon cards per row (96px tall, matching HeroOddsModal)
		for first = 1, #seeds, 2 do
			order += 1
			local rowKids: { [string]: any } = {
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 12),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			}
			for i = first, math.min(first + 1, #seeds) do
				local seed = seeds[i]
				local variantShare = if seed.IsHighStat then 0.40 else 0.60
				local chancePct = (tierRate / archetypeCount) * variantShare * 100
				rowKids["W_" .. seed.TemplateId] = e(WeaponOddsCard, {
					Seed = seed,
					ChancePct = chancePct,
					Cost = Catalog.GetPedestalCost(seed),
					Owned = ownedCopies[seed.TemplateId] or 0,
					Order = i,
				})
			end
			scrollChildren[string.format("Row_%d_%d", tier, first)] = e("Frame", {
				Name = string.format("Row_%d_%d", tier, first),
				LayoutOrder = order,
				Size = UDim2.new(1, 0, 0, 96),
				BackgroundTransparency = 1,
				ZIndex = 4,
			}, rowKids)
		end
	end

	local luckLine = if rollLuck > 0
		then string.format(
			"Pedestals: <b>%d/%d</b>  ·  <font color=\"#FFE296\">Forge Roll Luck: +%s%% (uncapped · Eternal Stoking)</font>",
			pedestals,
			TreeConfig.MaxForgePedestals or 6,
			formatPercent(rollLuck * 100)
		)
		else string.format(
			"Pedestals: <b>%d/%d</b>  ·  No Forge Roll Luck active (unlock Roll Luck in Upgrades)",
			pedestals,
			TreeConfig.MaxForgePedestals or 6
		)

	return e("Frame", {
		Name = "ForgeOddsOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 100,
	}, {
		Scrim = e("TextButton", {
			Name = "ForgeOddsScrim",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.40,
			Text = "",
			AutoButtonColor = false,
			Selectable = false,
			ZIndex = 1,
			[React.Event.Activated] = props.OnClose,
		}),
		Window = e("TextButton", {
			Name = "ForgeOddsWindow",
			Text = "",
			AutoButtonColor = false,
			Active = true,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0.95, 0, 0.94, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 2,
		}, {
			Constraint = e("UISizeConstraint", { MaxSize = Vector2.new(880, 620) }),
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 16) }),
			Fill = e("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new(Kit.Tokens.Surface.Window.Top, Kit.Tokens.Surface.Inset.Bottom),
			}),
			Ink = e("UIStroke", { Color = T.Theme.Ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			Rail = e("Frame", {
				Position = UDim2.fromOffset(3, 3),
				Size = UDim2.new(1, -6, 1, -6),
				BackgroundTransparency = 1,
				Active = false,
				ZIndex = 2,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 13) }),
				Stroke = e("UIStroke", { Color = T.Gold, Thickness = 1.4, Transparency = 0.25, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			}),

			-- Header Bar
			HeaderBar = e("Frame", {
				Position = UDim2.fromOffset(6, 6),
				Size = UDim2.new(1, -12, 0, 52),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				ZIndex = 3,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
				Fill = e("UIGradient", {
					Rotation = 90,
					Color = ColorSequence.new(Kit.Tokens.Domain.Forge.Top, Kit.Tokens.Domain.Forge.Bottom),
				}),
			}),
			HeaderIcon = e("Frame", {
				Position = UDim2.fromOffset(18, 12),
				Size = UDim2.fromOffset(38, 38),
				BackgroundTransparency = 1,
				ZIndex = 4,
			}, {
				Art = e(Icons.Icon, { Name = "Forge", Size = 38 }),
			}),
			Title = e(C.Text, {
				Text = "OPEN FORGE  ·  WEAPONS & ODDS",
				TextColor3 = Color3.new(1, 1, 1),
				Position = UDim2.fromOffset(64, 14),
				Size = UDim2.new(1, -130, 0, 36),
				TextSize = 21,
				ZIndex = 4,
			}),
			CloseHolder = e("Frame", {
				Name = "CloseHolder",
				Size = UDim2.fromOffset(40, 40),
				Position = UDim2.new(1, -54, 0, 12),
				BackgroundTransparency = 1,
				ZIndex = 5,
			}, {
				Close = e(C.Button, {
					Name = "CloseOddsButton",
					Text = "",
					Icon = "Close",
					Accent = T.Bad,
					Size = UDim2.fromScale(1, 1),
					OnActivate = props.OnClose,
					FocusOrder = -100,
				}),
			}),

			-- Top RatesBox (matches HeroOddsModal: rate pills + rules + live luck/pedestal state)
			RatesBox = e("Frame", {
				Name = "RatesBox",
				Position = UDim2.fromOffset(16, 66),
				Size = UDim2.new(1, -32, 0, 82),
				BackgroundColor3 = Color3.fromRGB(22, 16, 32),
				BorderSizePixel = 0,
				ZIndex = 3,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 9) }),
				Stroke = e("UIStroke", { Color = Color3.fromRGB(92, 66, 126), Thickness = 1.3 }),
				RatesRow = e("Frame", {
					Name = "RatesRow",
					Position = UDim2.fromOffset(12, 8),
					Size = UDim2.new(1, -24, 0, 24),
					BackgroundTransparency = 1,
					ZIndex = 4,
				}, ratePills),
				Rules = e("TextLabel", {
					Position = UDim2.fromOffset(12, 36),
					Size = UDim2.new(1, -24, 0, 18),
					BackgroundTransparency = 1,
					FontFace = T.Theme.Fonts.Body,
					Text = "Anvil rerolls are FREE  ·  Every weapon drops at 1★  ·  Standard (60%, 1.00×) & Enhanced (40%, 1.20× stats, 1.30× Gold)",
					TextSize = 12,
					TextColor3 = SUBTEXT,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					ZIndex = 4,
				}),
				State = e("TextLabel", {
					Position = UDim2.fromOffset(12, 56),
					Size = UDim2.new(1, -24, 0, 18),
					BackgroundTransparency = 1,
					FontFace = T.Theme.Fonts.Body,
					RichText = true,
					Text = luckLine,
					TextSize = 12,
					TextColor3 = SUBTEXT,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					ZIndex = 4,
				}),
			}),

			-- Scrollable Tier & 2-Column Weapon Cards
			Scroll = e("ScrollingFrame", {
				Name = "WeaponsOddsScroll",
				Position = UDim2.fromOffset(16, 156),
				Size = UDim2.new(1, -32, 1, -168),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.fromScale(0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				ScrollBarThickness = 6,
				ScrollBarImageColor3 = Color3.fromRGB(240, 196, 110),
				ClipsDescendants = true,
				ZIndex = 3,
			}, scrollChildren),
		}),
	})
end

return ForgeOddsModal
