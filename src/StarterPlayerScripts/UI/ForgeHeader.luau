--!strict
-- Shared by the Summon host and the React artifact workbench.
local R = game:GetService("ReplicatedStorage")
local Grimoire = require(R.Shared.Util.GildedGrimoire)
local GothicBoxStyle = require(R.Shared.Util.GothicBoxStyle)
local Icons = require(R.Shared.Util.GrimoireIcons)

local Header = {}
function Header.Create(parent: Instance, zIndex: number?)
	local z = zIndex or 1
	local icon = Icons.Create("Forge", 46, parent, z)
	icon.Name = "ForgeHeaderIcon"
	icon.Position = UDim2.fromOffset(22, 10)
	local title = Instance.new("TextLabel")
	title.Name = "ForgeHeaderTitle"
	title.BackgroundTransparency = 1
	title.Text = "BLACKSMITH FORGE"
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 26
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextWrapped = false
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.RichText = true
	title.Position = UDim2.fromOffset(78, 14)
	title.Size = UDim2.fromOffset(460, 32)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = z
	GothicBoxStyle.Font.Apply(title, { Role = "Title", Color = Color3.new(1, 1, 1), Size = 26 })
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Grimoire.Text.Gold)
	gradient.Parent = title
	title.Parent = parent
	return function() title:Destroy(); icon:Destroy() end
end
return Header
