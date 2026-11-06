--!strict
local R = game:GetService("ReplicatedStorage")
local React = require(R.Packages.React)
local Catalog = require(R.Shared.Config.ArtifactCatalog)
local C = require(script.Parent.Components)
local T = require(script.Parent.Tokens)
local e = React.createElement

return function(props: any)
	local rule = Catalog.GetStarPromotionCost(props.Target.Star)
	local count = if rule then rule.Donors else 0
	local children: any = {
		Center = e("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.32, 0.18), Size = UDim2.fromScale(0.36, 0.56) }, {
			Preview = e(C.Preview, { Artifact = props.Target, Size = UDim2.fromScale(1, 1) }),
			Rail = e("UIStroke", { Color = T.Gold, Thickness = 2 }),
		}),
		Name = e(C.Text, { Text = props.Target.DisplayName, TextColor3 = T.Gold, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromScale(0, 0.78), Size = UDim2.fromScale(1, 0.12) }),
		Stars = e(C.Text, { Text = string.rep("★", props.Target.Star) .. " · KEPT", TextColor3 = T.Gold, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromScale(0, 0.9), Size = UDim2.fromScale(1, 0.1) }),
	}
	for i = 1, count do
		local id = props.Materials[i]
		local artifact = id and props.Snapshot.Artifacts[id]
		local side = (i - 1) % 2
		local row = math.floor((i - 1) / 2)
		local rows = math.ceil(count / 2)
		children["Slot" .. i] = e("Frame", { Name = "MaterialSlot" .. i, BackgroundTransparency = 1, Position = UDim2.fromScale(if side == 0 then 0.02 else 0.74, 0.12 + row * (0.62 / math.max(1, rows))), Size = UDim2.fromScale(0.24, math.min(0.3, 0.58 / math.max(1, rows))) }, {
			Button = e(C.Button, { Name = "ChooseMaterialSlot" .. i, Text = "", Icon = if artifact then nil else "Add", Size = UDim2.fromScale(1, 1), OnActivate = function() props.OnSlot(id) end }),
			Preview = if artifact then e(C.Preview, { Artifact = artifact, Size = UDim2.new(1, 0, 1, -20) }) else nil,
			Label = if artifact then e(C.Text, { Text = artifact.Star .. "★ · Remove", TextSize = 12, Position = UDim2.new(0, 0, 1, -20), Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Center }) else nil,
		})
	end
	return e("Frame", { Name = "UpgradeStage", BackgroundTransparency = 1, Size = props.Size }, children)
end
