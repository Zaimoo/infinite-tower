--!strict
-- Shared presentation only. Eligibility, status and actions belong to the calling screen.
local HeroCard = require(script.Parent.HeroCard)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StatFormulas = require(ReplicatedStorage.Shared.Util.StatFormulas)
local GrimoireIcons = require(ReplicatedStorage.Shared.Util.GrimoireIcons)
local Grimoire = require(ReplicatedStorage.Shared.Util.GildedGrimoire)
local Theme = require(script.Parent.Hud.Theme)

local Card = {}
local GOLD = Grimoire.Text.Gold
local PARCHMENT = Grimoire.Text.Parchment

local function new(kind: string, props: { [string]: any }, parent: Instance): any
	local object = Instance.new(kind)
	for key, value in props do (object :: any)[key] = value end
	object.Parent = parent
	return object
end

function Card.Create(parent: Instance, entry: any, order: number, z: number, onSelect: (string) -> ()): TextButton
	local hero = entry.Hero
	local accent = if entry.Selected then GOLD else Theme.RarityColor(StatFormulas.GetHeroRarity(hero))
	local card = new("Frame", {
		Name = "Hero_" .. entry.UUID, LayoutOrder = order, BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = z,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, card)
	new("UIStroke", { Color = accent, Thickness = if entry.Selected then 3 else 1.5 }, card)
	new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(54, 33, 66), Color3.fromRGB(18, 12, 29)), Rotation = 90 }, card)
	local portrait = new("Frame", {
		Name = "Portrait", Position = UDim2.fromOffset(5, 5), Size = UDim2.new(1, -10, 0, 91),
		BackgroundColor3 = Color3.fromRGB(20, 14, 30), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = z + 1,
	}, card)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, portrait)
	local level = new("TextLabel", {
		Name = "LevelBadge", Text = string.format("Lv.%d", hero.Level or 1),
		TextSize = 12, TextColor3 = GOLD, BackgroundColor3 = Color3.fromRGB(20, 12, 29),
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 3, 1, -3), Size = UDim2.fromOffset(42, 20), ZIndex = z + 4,
	}, portrait)
	new("UICorner", { CornerRadius = UDim.new(0, 4) }, level)
	level:SetAttribute("Grimoire", true)
	Grimoire.StyleText(level, "Number")

	local badge = new("Frame", {
		Name = "ArchetypeBadge", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -3, 1, -3),
		Size = UDim2.fromOffset(24, 24), BackgroundColor3 = Color3.fromRGB(20, 12, 29), BorderSizePixel = 0, ZIndex = z + 4,
	}, portrait)
	new("UICorner", { CornerRadius = UDim.new(0, 5) }, badge)
	local icon = GrimoireIcons.Create(entry.Archetype or hero.Archetype or "Hero", 18, badge, z + 5)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	local image = HeroCard.Portrait(portrait, hero)
	image.ZIndex = z + 2
	local function text(name: string, value: string, role: string, y: number, height: number, size: number, color: Color3): TextLabel
		local label = new("TextLabel", {
			Name = name, Text = value, Position = UDim2.fromOffset(8, y), Size = UDim2.new(1, -16, 0, height),
			BackgroundTransparency = 1, TextSize = size, TextColor3 = color,
			TextWrapped = true, ZIndex = z + 2,
		}, card)
		label:SetAttribute("Grimoire", true)
		Grimoire.StyleText(label, role)
		return label
	end
	local name = text("HeroName", hero.DisplayName or "Hero", "Title", 99, 34, 18, PARCHMENT)
	name.TextScaled = true
	new("UITextSizeConstraint", { MinTextSize = 13, MaxTextSize = 20 }, name)
	text("Level", string.format("%s  Lv.%d / %d", string.rep("★", math.clamp(hero.Stars or 1, 1, 7)), hero.Level or 1, StatFormulas.GetMaxLevel(hero.Stars or 1)), "Body", 135, 19, 13, accent)
	local archetype = entry.Archetype or hero.Archetype or "Hero"
	text("Archetype", archetype, "Body", 155, 18, 13, PARCHMENT)
	local statusColor = if entry.Disabled then Grimoire.Text.Bad else Grimoire.Text.Muted
	text("Status", entry.Status or "", "Body", 175, 22, 12, statusColor)
	local action = new("TextButton", {
		Name = "HeroActionBtn", Position = UDim2.new(0, 8, 1, -52), Size = UDim2.new(1, -16, 0, 44),
		Text = entry.Action or "SELECT", TextSize = 18,
		TextColor3 = if entry.Disabled then Color3.fromRGB(180, 170, 190) else Color3.fromRGB(32, 19, 9),
		BackgroundColor3 = if entry.Disabled then Color3.fromRGB(116, 105, 122) else Color3.new(1, 1, 1),
		BorderSizePixel = 0, AutoButtonColor = not entry.Disabled, Selectable = true,
		ZIndex = z + 3,
	}, card)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, action)
	new("UIStroke", { Color = GOLD, Thickness = if entry.Selected then 2 else 1 }, action)
	new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 238, 169), Color3.fromRGB(179, 113, 36)), Rotation = 90 }, action)
	action:SetAttribute("HeroUUID", entry.UUID)
	action:SetAttribute("Grimoire", true)
	Grimoire.StyleText(action, "Title")
	action.Activated:Connect(function()
		if not entry.Disabled then onSelect(entry.UUID) end
	end)
	return action
end

function Card.Resize(action: TextButton, compact: boolean)
	local card = action.Parent :: Frame
	local portrait = card:FindFirstChild("Portrait") :: Frame
	portrait.Size = UDim2.new(1, -10, 0, if compact then 43 else 91)
	local positions = if compact then { HeroName = { 48, 26 }, Level = { 74, 16 }, Archetype = { 90, 16 }, Status = { 106, 18 } }
		else { HeroName = { 99, 34 }, Level = { 135, 19 }, Archetype = { 155, 18 }, Status = { 175, 22 } }
	for name, rect in positions do
		local label = card:FindFirstChild(name) :: TextLabel
		if label then
			label.Position = UDim2.fromOffset(8, rect[1])
			label.Size = UDim2.new(1, -16, 0, rect[2])
			if name == "Level" or name == "Archetype" then
				label.TextSize = if compact then 11 else 13
			elseif name == "Status" then
				label.TextSize = if compact then 10 else 12
			end
		end
	end
	action.TextSize = if compact then 15 else 18
end

return Card
