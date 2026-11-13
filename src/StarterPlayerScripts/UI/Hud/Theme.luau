--!strict
-- StarterPlayerScripts/UI/Hud/Theme.luau
-- Phase 5 HUD tokens: the obsidian-gold palette, rarity frame colours, archetype icons and the
-- fixed-zone layout metrics shared by every HUD component.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GildedGrimoire = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("GildedGrimoire"))

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

-- Rarity tier frame colours, Common (1) to Immortal (11; 8-11 are the Gilded Mirror heroes). Same hues as ArtifactCatalog's rarities
-- and BillboardThemes.HeroByRarity: Legendary is gold, Mythical is red.
Theme.Rarity = table.freeze({
	Color3.fromRGB(170, 170, 182), -- Common
	Color3.fromRGB(92, 205, 112), -- Uncommon
	Color3.fromRGB(70, 150, 255), -- Rare
	Color3.fromRGB(176, 104, 255), -- Superior
	Color3.fromRGB(255, 160, 50), -- Exalted
	Color3.fromRGB(255, 215, 90), -- Legendary
	Color3.fromRGB(255, 92, 72), -- Mythical
	Color3.fromRGB(40, 210, 175), -- Transcendent (Nyx)
	Color3.fromRGB(224, 96, 253), -- Ascendant (Caspian)
	Color3.fromRGB(120, 125, 240), -- Ethereal (Seraphine)
	Color3.fromRGB(255, 130, 150), -- Immortal (Rook)
})

function Theme.RarityColor(tier: number?): Color3
	return Theme.Rarity[math.clamp(math.floor(tier or 1), 1, #Theme.Rarity)]
end

-- Archetype icons are drawn (GrimoireIcons: Vanguard, Striker, Marksman, Berserker, Scholar, Healer).

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
	EventBadgeHeight = 52, -- timed tower event badge (Phase G), stacked above Squad Power
	StatusRowHeight = 56,
	StatusWidth = 300,
})

-- "Clear Glass" (HUD zones only): defined once in Shared/Util/GildedGrimoire so imperative HUD
-- pieces (banners, the duel and offline-reward popups) share the same tokens.
Theme.Glass = GildedGrimoire.Glass

Theme.Font = Enum.Font.GothamBold
Theme.FontBody = Enum.Font.GothamMedium
Theme.FontBlack = Enum.Font.GothamBlack

return table.freeze(Theme)
