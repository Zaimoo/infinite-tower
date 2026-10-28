--!strict
-- ReplicatedStorage/Shared/Util/GrimoireSummonButton.luau
-- The Gilded Grimoire summon button (hero banners and the Forge's artifact banner): an Action-tone
-- gothic button with a heavy title over an "icon + cost" row (a drawn Gems icon, never an emoji).

local GothicBoxStyle = require(script.Parent:WaitForChild("GothicBoxStyle"))
local GildedGrimoire = require(script.Parent:WaitForChild("GildedGrimoire"))
local GrimoireIcons = require(script.Parent:WaitForChild("GrimoireIcons"))

local GrimoireSummonButton = {}

export type Props = {
	Name: string,
	Title: string,
	Cost: number | string,
	Icon: string?, -- GrimoireIcons name (default "Gems")
	Position: UDim2,
	Size: UDim2,
	AnchorPoint: Vector2?,
	ZIndex: number?,
	OnClick: () -> (),
}

export type Button = {
	Root: TextButton,
	TitleLabel: TextLabel,
	CostLabel: TextLabel,
	SetCost: (cost: number | string) -> (),
}

function GrimoireSummonButton.new(parent: Instance, props: Props): Button
	local z = props.ZIndex or 54
	local btn = Instance.new("TextButton")
	btn.Name = props.Name
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.BorderSizePixel = 0
	btn.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	btn.Position = props.Position
	btn.Size = props.Size
	btn.ZIndex = z
	btn.Parent = parent
	GothicBoxStyle.Apply(btn, { Style = "Button" })

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.new(0.5, 0, 0.33, 0)
	title.Size = UDim2.new(1, -16, 0, 24)
	title.Text = props.Title
	title.ZIndex = z + 2
	title.Parent = btn
	GothicBoxStyle.Font.Apply(title, { Role = "Button", Size = 20, Color = Color3.new(1, 1, 1) })

	local row, cost = GrimoireIcons.IconText(props.Icon or "Gems", 22, btn, z + 2)
	row.AnchorPoint = Vector2.new(0.5, 0.5)
	row.Position = UDim2.new(0.5, 0, 0.72, 0)
	cost.Text = tostring(props.Cost)
	cost.TextColor3 = Color3.new(1, 1, 1)
	cost.TextSize = 19
	GildedGrimoire.StyleText(cost, "Number")
	cost:SetAttribute("Grimoire", true)

	btn.Activated:Connect(props.OnClick)

	return {
		Root = btn,
		TitleLabel = title,
		CostLabel = cost,
		SetCost = function(value: number | string)
			cost.Text = tostring(value)
		end,
	}
end

return GrimoireSummonButton
