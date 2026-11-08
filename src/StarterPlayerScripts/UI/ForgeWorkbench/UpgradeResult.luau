--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local React = require(ReplicatedStorage.Packages.React)
local Catalog = require(ReplicatedStorage.Shared.Config.ArtifactCatalog)
local Stats = require(ReplicatedStorage.Shared.Util.StatFormulas)
local Balance = require(ReplicatedStorage.Shared.Config.StatBalance)
local Icons = require(script.Parent.Parent.Hud.Icons)
local ArtifactPreview = require(script.Parent.Parent.ArtifactPreview)
local UIFeel = require(script.Parent.Parent.UIFeel)
local C = require(script.Parent.Components)
local Model = require(script.Parent.Model)
local T = require(script.Parent.Tokens)
local Types = require(script.Parent.Types)
local e = React.createElement

export type UpgradeResultProps = {
	Snapshot: Types.Snapshot,
	Before: Types.Artifact,
	After: Types.Artifact,
	Materials: { Types.Artifact }?,
	Gold: number?,
	Gems: number?,
	Owner: Types.Hero?,
	OnBack: () -> (),
	OnAgain: () -> (),
	MaxRank: boolean,
}

local function UpgradeResult(props: UpgradeResultProps)
	local before = props.Before
	local after = props.After
	local rarity = Catalog.GetRarityInfo(after.Rarity)
	local reducedMotion = UIFeel.ReducedMotion()

	local beforePower = Model.power(before)
	local afterPower = Model.power(after)
	local powerDelta = math.max(0, afterPower - beforePower)

	local beforeStats = Catalog.GetStatBreakdown(before.TemplateId, before.Star, before.Rarity)
	local afterStats = Catalog.GetStatBreakdown(after.TemplateId, after.Star, after.Rarity)

	local hero = props.Owner
	local beforeDPS = if hero then Stats.GetCombatSnapshot(hero, before).DPS else nil
	local afterDPS = if hero then Stats.GetCombatSnapshot(hero, after).DPS else nil

	-- Animation phase state
	local animDone, setAnimDone = React.useState(reducedMotion)
	local powerDisplay, setPowerDisplay = React.useState(if reducedMotion then afterPower else beforePower)
	local bannerScaleRef = React.useRef(nil)
	local starScaleRef = React.useRef(nil)
	local raysRef = React.useRef(nil)
	local previewHostRef = React.useRef(nil)

	-- Mount 3D spinning preview
	React.useEffect(function()
		local host = previewHostRef.current
		if not host then return end
		ArtifactPreview.Show(host, after.TemplateId, { Spin = not reducedMotion, FieldOfView = 34 })
		return function()
			local current = host:FindFirstChild("ArtifactModelPreview")
			if current then current:Destroy() end
		end
	end, { after.TemplateId })

	-- Run animations
	React.useEffect(function()
		if reducedMotion then
			setPowerDisplay(afterPower)
			setAnimDone(true)
			return
		end

		UIFeel.Sfx("StarTick")

		-- Banner pop
		if bannerScaleRef.current then
			bannerScaleRef.current.Scale = 0.6
			local tween = TweenService:Create(bannerScaleRef.current, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			tween:Play()
		end

		-- Star pop
		if starScaleRef.current then
			starScaleRef.current.Scale = 0.2
			task.delay(0.3, function()
				if starScaleRef.current then
					local tween = TweenService:Create(starScaleRef.current, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.3 })
					tween:Play()
					tween.Completed:Connect(function()
						if starScaleRef.current then
							local settle = TweenService:Create(starScaleRef.current, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 })
							settle:Play()
						end
					end)
				end
			end)
		end

		-- Power count-up
		local val = Instance.new("NumberValue")
		val.Value = beforePower
		val.Changed:Connect(function(v)
			setPowerDisplay(math.round(v))
		end)
		local powerTween = TweenService:Create(val, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = afterPower })
		task.delay(0.4, function()
			powerTween:Play()
		end)

		-- Enable action buttons after animation
		local timer = task.delay(0.85, function()
			setAnimDone(true)
		end)

		return function()
			task.cancel(timer)
			val:Destroy()
		end
	end, {})

	local function skipAnimation()
		if not animDone then
			setPowerDisplay(afterPower)
			setAnimDone(true)
		end
	end

	local nextRule = Catalog.GetStarPromotionCost(after.Star)
	local canUpgradeAgain = not props.MaxRank and nextRule ~= nil

	return e("Frame", {
		Name = "UpgradeResultScreen",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		-- Click to skip animation
		SkipHitbox = e("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 1,
			[React.Event.Activated] = skipAnimation,
		}),
		Content = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			-- 1. Banner
			Banner = e("Frame", {
				Size = UDim2.new(1, 0, 0, 36),
				BackgroundTransparency = 1,
				LayoutOrder = 1,
			}, {
				Scale = e("UIScale", { ref = bannerScaleRef }),
				Title = e(C.Text, {
					Text = if props.MaxRank then "✦  MAX RANK REACHED!  ✦" else "✦  UPGRADE SUCCESS!  ✦",
					FontFace = T.Theme.Fonts.Title,
					TextSize = 24,
					TextColor3 = T.Gold,
					TextXAlignment = Enum.TextXAlignment.Center,
					Size = UDim2.fromScale(1, 1),
				}),
			}),
			-- 2. 3D Model Center Stage with Aura
			ModelStage = e("Frame", {
				Size = UDim2.fromOffset(180, 150),
				BackgroundColor3 = Color3.fromRGB(16, 12, 24),
				BorderSizePixel = 0,
				LayoutOrder = 2,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 14) }),
				Gradient = e("UIGradient", {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, rarity.Color:Lerp(Color3.fromRGB(34, 24, 48), 0.5)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 8, 16)),
					}),
					Rotation = 90,
				}),
				Stroke = e("UIStroke", { Color = rarity.Color, Thickness = 2, Transparency = 0.2 }),
				ViewportHost = e("Frame", {
					ref = previewHostRef,
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
				}),
			}),
			-- 3. Stars Display with pop
			StarsRow = e("Frame", {
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
				LayoutOrder = 3,
			}, {
				Scale = e("UIScale", { ref = starScaleRef }),
				Stars = e(C.Text, {
					Text = string.rep("★", after.Star),
					FontFace = T.Theme.Fonts.Number,
					TextSize = 22,
					TextColor3 = T.Gold,
					TextXAlignment = Enum.TextXAlignment.Center,
					Size = UDim2.fromScale(1, 1),
				}),
			}),
			-- 4. Name & Details
			Name = e(C.Text, {
				Text = after.DisplayName,
				FontFace = T.Theme.Fonts.Title,
				TextSize = 18,
				TextColor3 = T.Text,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, 0, 0, 22),
				LayoutOrder = 4,
			}),
			Subtext = e(C.Text, {
				Text = string.format("%s  ·  %s", rarity.Name, if hero then "Equipped by " .. hero.DisplayName else "Unequipped"),
				TextSize = 13,
				TextColor3 = if hero then T.Equipped else rarity.Color,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, 0, 0, 18),
				LayoutOrder = 5,
			}),
			-- 5. Power Counter + Green Delta
			PowerBox = e("Frame", {
				Size = UDim2.new(0.6, 0, 0, 44),
				BackgroundColor3 = Color3.fromRGB(20, 14, 30),
				BorderSizePixel = 0,
				LayoutOrder = 6,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Stroke = e("UIStroke", { Color = T.Gold, Thickness = 1.4 }),
				Text = e(C.Text, {
					Text = string.format("%s PWR  ", Balance.Format(powerDisplay)) .. string.format("<font color=\"#78FF8C\">(+%s)</font>", Balance.Format(powerDelta)),
					FontFace = T.Theme.Fonts.Number,
					TextSize = 20,
					TextColor3 = T.Gold,
					RichText = true,
					TextXAlignment = Enum.TextXAlignment.Center,
					Size = UDim2.fromScale(1, 1),
				}),
			}),
			-- 6. Stat Comparison Chips
			Chips = e("Frame", {
				Size = UDim2.new(0.88, 0, 0, 48),
				BackgroundTransparency = 1,
				LayoutOrder = 7,
			}, {
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalFlex = Enum.UIFlexAlignment.Fill,
					Padding = UDim.new(0, 8),
				}),
				Dmg = e(C.StatChip, {
					Label = "DMG MULTIPLIER",
					Value = string.format("×%.2f → ×%.2f", beforeStats.DamageMultiplier, afterStats.DamageMultiplier),
					Color = T.Good,
					Order = 1,
				}),
				Spd = e(C.StatChip, {
					Label = "ATTACK SPEED",
					Value = string.format("+%.1f%% → +%.1f%%", beforeStats["Attack Speed"], afterStats["Attack Speed"]),
					Color = T.Good,
					Order = 2,
				}),
				Dps = if beforeDPS and afterDPS then e(C.StatChip, {
					Label = "HERO DPS",
					Value = string.format("%s → %s", Balance.Format(beforeDPS), Balance.Format(afterDPS)),
					Color = T.Good,
					Order = 3,
				}) else nil,
			}),
			-- 7. Consumed Summary Line
			Summary = e(C.Text, {
				Text = string.format(
					"%d artifact%s consumed · −%s Gold · −%s Gems",
					props.Materials and #props.Materials or 1,
					if props.Materials and #props.Materials == 1 then "" else "s",
					Balance.Format(props.Gold or 0),
					Balance.Format(props.Gems or 0)
				),
				TextSize = 12,
				TextColor3 = T.Muted,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, 0, 0, 20),
				LayoutOrder = 8,
			}),
			-- 8. Action Buttons
			Buttons = e("Frame", {
				Size = UDim2.new(0.72, 0, 0, 48),
				BackgroundTransparency = 1,
				LayoutOrder = 9,
			}, {
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalFlex = Enum.UIFlexAlignment.Fill,
					Padding = UDim.new(0, 12),
				}),
				Back = e(C.Button, {
					Text = "Back to artifacts",
					Size = UDim2.new(0.5, -6, 1, 0),
					Disabled = not animDone,
					OnActivate = props.OnBack,
					Order = 1,
				}),
				Again = if canUpgradeAgain then e(C.Button, {
					Text = string.format("Upgrade again · %d★ → %d★", after.Star, after.Star + 1),
					Primary = true,
					Size = UDim2.new(0.5, -6, 1, 0),
					Disabled = not animDone,
					OnActivate = props.OnAgain,
					Order = 2,
				}) else nil,
			}),
		}),
	})
end

return UpgradeResult
