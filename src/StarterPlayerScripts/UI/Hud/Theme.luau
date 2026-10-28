--!strict
-- StarterPlayerScripts/UI/Hud/Theme.luau
-- Phase 5 HUD tokens: the obsidian-gold palette, rarity frame colours, archetype icons and the
-- fixed-zone layout metrics shared by every HUD component.

local Theme = {}

Theme.Colors = table.freeze({
	Panel = Color3.fromRGB(15, 13, 22),
	PanelSoft = Color3.fromRGB(24, 21, 36),
	Border = Color3.fromRGB(88, 70, 120),
	Gold = Color3.fromRGB(250, 204, 21),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(170, 160, 190),
	Green = Color3.fromRGB(74, 222, 128),
	Red = Color3.fromRGB(239, 68, 68),
	HP = Color3.fromRGB(65, 220, 110),
	Gauge = Color3.fromRGB(255, 210, 55),
	Badge = Color3.fromRGB(239, 68, 68),
})

-- Rarity tier frame colours, Common (1) to Mythical (7).
Theme.Rarity = table.freeze({
	Color3.fromRGB(170, 170, 182),
	Color3.fromRGB(92, 205, 112),
	Color3.fromRGB(70, 150, 255),
	Color3.fromRGB(176, 104, 255),
	Color3.fromRGB(255, 160, 50),
	Color3.fromRGB(255, 92, 72),
	Color3.fromRGB(255, 215, 90),
})

function Theme.RarityColor(tier: number?): Color3
	return Theme.Rarity[math.clamp(math.floor(tier or 1), 1, #Theme.Rarity)]
end

-- Archetype icons are drawn (GrimoireIcons: Vanguard, Striker, Marksman, Miner, Scholar, Healer).

Theme.FacilityNames = table.freeze({
	FACILITY_GUARD_POST = "Guard Post",
	FACILITY_MARKET = "Market",
	FACILITY_TRAINING = "Training Grounds",
	FACILITY_GODS_BLESSING = "God's Blessing",
	ALL = "Every facility",
})

-- Fixed-zone layout (Phase 5 §2). All values are pixels inside CoreUISafeInsets.
Theme.Layout = table.freeze({
	Edge = 12, -- gap to the safe-area edge
	TopZone = 92, -- below the currency bar / floor bar row
	GoalCardHeight = 88,
	GoalCardWidth = 300,
	ZoneGap = 16, -- Right Rail below the goal card
	StackGap = 12, -- rails stop this far above the bottom cards
	RailButton = 72, -- chunky icons, like the rail reference
	RailButtonMin = 44, -- never smaller (touch target)
	RailGap = 6,
	PowerBadgeHeight = 58,
	PowerBadgeWidth = 200,
	StatusRowHeight = 56,
	StatusWidth = 300,
})

Theme.Font = Enum.Font.GothamBold
Theme.FontBody = Enum.Font.GothamMedium
Theme.FontBlack = Enum.Font.GothamBlack

return table.freeze(Theme)
