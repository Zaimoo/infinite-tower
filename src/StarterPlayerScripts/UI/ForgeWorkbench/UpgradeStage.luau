--!strict
-- The upgrade bench: the weapon being upgraded on a rarity-lit card, and under it one square slot
-- per weapon the upgrade consumes. Tap an empty slot to pick a weapon; tap a filled one to remove it.
local R = game:GetService("ReplicatedStorage")
local React = require(R.Packages.React)
local Catalog = require(R.Shared.Config.ArtifactCatalog)
local C = require(script.Parent.Components)
local T = require(script.Parent.Tokens)
local e = React.createElement

return function(props: any)
	local target = props.Target
	local rule = Catalog.GetStarPromotionCost(target.Star)
	local count = if rule then rule.Donors else 0
	local rarity = Catalog.GetRarityInfo(target.Rarity)
	local filled = 0
	local slots: any = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for i = 1, count do
		local id = props.Materials[i]
		local artifact = id and props.Snapshot.Artifacts[id]
		if artifact then filled += 1 end
		slots["Slot" .. i] = e("Frame", { Name = "MaterialSlot" .. i, LayoutOrder = i, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
			Square = e("UIAspectRatioConstraint", { AspectRatio = 1 }),
			Button = e(C.Button, { Name = "ChooseMaterialSlot" .. i, Text = "", Icon = if artifact then nil else "Add", Size = UDim2.fromScale(1, 1), OnActivate = function() props.OnSlot(id) end }),
			Preview = if artifact then e("Frame", { Position = UDim2.fromOffset(5, 5), Size = UDim2.new(1, -10, 1, -10), BackgroundTransparency = 1 }, {
				Model = e(C.Preview, { Artifact = artifact, Size = UDim2.fromScale(1, 1) }),
			}) else nil,
			Remove = if artifact then e(C.Text, {
				Text = "✕", TextSize = 14, TextColor3 = T.Bad, TextXAlignment = Enum.TextXAlignment.Center,
				AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(18, 18), ZIndex = 6,
			}) else nil,
		})
	end
	return e("Frame", { Name = "UpgradeStage", BackgroundTransparency = 1, Size = props.Size }, {
		Card = e("Frame", { Name = "TargetCard", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.5, 0.56), BackgroundTransparency = 1 }, {
			Preview = e(C.Preview, { Artifact = target, Size = UDim2.fromScale(1, 1) }),
			Edge = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 4 }, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
				Line = e("UIStroke", { Color = rarity.Color, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			}),
		}),
		Name = e(C.Text, { Text = target.DisplayName, TextColor3 = T.Text, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, Position = UDim2.fromScale(0, 0.58), Size = UDim2.fromScale(1, 0.09) }),
		Stars = e(C.Text, {
			Text = if rule then string.format("%d★  →  %d★", target.Star, target.Star + 1) else string.format("%d★ · Max", target.Star),
			FontFace = T.Theme.Fonts.Number, TextSize = 20, TextColor3 = T.Gold, TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromScale(0, 0.67), Size = UDim2.fromScale(1, 0.08),
		}),
		Label = e(C.Text, {
			Text = if count > 0 then string.format("WEAPONS TO CONSUME  %d / %d", filled, count) else "",
			TextSize = 14, TextColor3 = if filled >= count then T.Good else T.Muted, TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromScale(0, 0.76), Size = UDim2.fromScale(1, 0.06),
		}),
		Slots = e("Frame", { Name = "MaterialSlots", BackgroundTransparency = 1, Position = UDim2.fromScale(0, 0.83), Size = UDim2.fromScale(1, 0.17) }, slots),
	})
end
