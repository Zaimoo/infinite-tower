--!strict
-- Shared presentation only. Eligibility, status and actions belong to the calling screen.
local HeroCard = require(script.Parent.HeroCard)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StatFormulas = require(ReplicatedStorage.Shared.Util.StatFormulas)
local GrimoireIcons = require(ReplicatedStorage.Shared.Util.GrimoireIcons)
local Grimoire = require(ReplicatedStorage.Shared.Util.GildedGrimoire)
local Theme = require(script.Parent.Hud.Theme)
local UIFeel = require(script.Parent.UIFeel)

local Card = {}
local GOLD = Grimoire.Text.Gold
local PARCHMENT = Grimoire.Text.Parchment
Card.WideHeight = 204
Card.TallHeight = 296
local WIDE_PORTRAIT_HEIGHT = 141
local TALL_PORTRAIT_HEIGHT = 160

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
		Name = "Portrait", Position = UDim2.fromOffset(5, 5), Size = UDim2.new(1, -10, 0, TALL_PORTRAIT_HEIGHT),
		BackgroundColor3 = Color3.fromRGB(20, 14, 30), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = z + 1,
	}, card)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, portrait)
	local badge = new("Frame", {
		Name = "ArchetypeBadge", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -3, 1, -3),
		Size = UDim2.fromOffset(24, 24), BackgroundColor3 = Color3.fromRGB(20, 12, 29), BorderSizePixel = 0, ZIndex = z + 4,
	}, portrait)
	new("UICorner", { CornerRadius = UDim.new(0, 5) }, badge)
	local icon = GrimoireIcons.Create(entry.Archetype or hero.Archetype or "Hero", 18, badge, z + 5)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	local image = HeroCard.Portrait(portrait, hero, "CloseUp")
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
	local name = text("HeroName", hero.DisplayName or "Hero", "Title", TALL_PORTRAIT_HEIGHT + 8, 30, 18, PARCHMENT)
	name.TextScaled = true
	name.TextTruncate = Enum.TextTruncate.AtEnd
	new("UITextSizeConstraint", { MinTextSize = 13, MaxTextSize = 20 }, name)
	local level = text("Level", string.format("★%d  ·  Lv.%d / %d", hero.Stars or 1, hero.Level or 1, StatFormulas.GetMaxLevel(hero.Stars or 1)), "Body", TALL_PORTRAIT_HEIGHT + 39, 18, 13, accent)
	level.TextWrapped = false
	level.TextScaled = true
	new("UITextSizeConstraint", { MinTextSize = 10, MaxTextSize = 13 }, level)
	local archetype = entry.Archetype or hero.Archetype or "Hero"
	local role = text("Archetype", archetype, "Body", TALL_PORTRAIT_HEIGHT - 17, 18, 12, PARCHMENT)
	role.TextWrapped = false
	role.TextTruncate = Enum.TextTruncate.AtEnd
	role.BackgroundColor3 = Color3.fromRGB(20, 14, 30)
	role.BackgroundTransparency = 0.25
	new("UICorner", { CornerRadius = UDim.new(0, 4) }, role)
	local statusColor = if entry.Disabled then Grimoire.Text.Bad else Grimoire.Text.Muted
	text("Status", entry.Status or "", "Body", TALL_PORTRAIT_HEIGHT + 58, 24, 12, statusColor)
	-- The whole card is the button (plan §5.4): a transparent hit area over the card, a gold outline on
	-- hover or gamepad focus, and a small "Select ›" hint where the big gold button used to be.
	local cardStroke = card:FindFirstChildOfClass("UIStroke") :: UIStroke
	local restColor, restThickness = cardStroke.Color, cardStroke.Thickness
	local hint = text("ActionHint", if entry.Disabled then "Unavailable" else (entry.Action or "Select") .. "  ›", "Title", 0, 22, 15,
		if entry.Disabled then Grimoire.Text.Muted else GOLD)
	hint.AnchorPoint = Vector2.new(0, 1)
	hint.Position = UDim2.new(0, 8, 1, -10)
	local action = new("TextButton", {
		Name = "HeroActionBtn", Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 1),
		Text = "", BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false, Selectable = true,
		ZIndex = z + 6,
	}, card)
	local function highlight(on: boolean)
		if entry.Disabled then return end
		cardStroke.Color = if on then GOLD else restColor
		cardStroke.Thickness = if on then 3 else restThickness
	end
	action.MouseEnter:Connect(function() highlight(true) end)
	action.MouseLeave:Connect(function() highlight(false) end)
	action.SelectionGained:Connect(function() highlight(true) end)
	action.SelectionLost:Connect(function() highlight(false) end)
	action:SetAttribute("HeroUUID", entry.UUID)
	action.Activated:Connect(function()
		if entry.Disabled then
			UIFeel.Deny(card)
			return
		end
		onSelect(entry.UUID)
	end)
	return action
end

function Card.Resize(action: TextButton, wide: boolean)
	local card = action.Parent :: Frame
	local portrait = card:FindFirstChild("Portrait") :: Frame
	portrait.Size = if wide then UDim2.new(0.46, -7, 0, WIDE_PORTRAIT_HEIGHT) else UDim2.new(1, -10, 0, TALL_PORTRAIT_HEIGHT)
	local positions = if wide then { HeroName = { 8, 40 }, Level = { 50, 18 }, Archetype = { 70, 18 }, Status = { 90, 50 } }
		else { HeroName = { TALL_PORTRAIT_HEIGHT + 8, 30 }, Level = { TALL_PORTRAIT_HEIGHT + 39, 18 }, Archetype = { TALL_PORTRAIT_HEIGHT - 17, 18 }, Status = { TALL_PORTRAIT_HEIGHT + 58, 24 } }
	for name, rect in positions do
		local label = card:FindFirstChild(name) :: TextLabel
		label.Position = if wide then UDim2.new(0.46, 3, 0, rect[1]) else UDim2.fromOffset(8, rect[1])
		label.Size = UDim2.new(if wide then 0.54 else 1, if wide then -10 else -16, 0, rect[2])
		label.TextXAlignment = if wide then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
	end
	local role = card:FindFirstChild("Archetype") :: TextLabel
	role.BackgroundTransparency = if wide then 1 else 0.25
	if not wide then
		role.Size = UDim2.new(1, -46, 0, 18)
	end
	action.TextSize = if wide then 15 else 16
end

return Card
