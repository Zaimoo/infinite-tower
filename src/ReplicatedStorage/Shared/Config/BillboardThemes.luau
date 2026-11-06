--!strict
-- ReplicatedStorage/Shared/Config/BillboardThemes.luau
-- World-space billboard themes. Relic plates are themed by rarity (RelicConfig tier) and mob nameplates by tier
-- (Normal, Elite, Alpha, Biome Boss), so a glance tells the player what a drop is worth and what they are fighting.
-- Tone is a key of GildedGrimoire.Tones; Badge is the tag chip drawn above the plate (nil draws no chip).

export type Theme = {
	Tone: string,
	Rail: Color3,
	Title: Color3,
	TitleGradient: { Color3 }?, -- 2-3 stops, left to right, over the title text
	Accent: Color3, -- badge chip, HP bar and Highlight outline
	Badge: string?,
	Size: Vector2, -- billboard pixels, plate only (the badge strip is added on top)
	MaxDistance: number,
	AlwaysOnTop: boolean,
}

export type MobTier = "NORMAL" | "ELITE" | "ALPHA" | "BIOME_BOSS"

local RelicConfig = require(script.Parent.RelicConfig)

local BillboardThemes = {}

BillboardThemes.BADGE_HEIGHT = 16

local rarityDefaults: { [string]: { Tone: string, Badge: string, AlwaysOnTop: boolean, Size: Vector2, MaxDistance: number } } = {
	Common = { Tone = "Azure", Badge = "COMMON", AlwaysOnTop = false, Size = Vector2.new(210, 84), MaxDistance = 240 },
	Uncommon = { Tone = "Azure", Badge = "UNCOMMON", AlwaysOnTop = false, Size = Vector2.new(215, 84), MaxDistance = 250 },
	Rare = { Tone = "Amber", Badge = "RARE", AlwaysOnTop = false, Size = Vector2.new(220, 86), MaxDistance = 260 },
	Superior = { Tone = "Void", Badge = "SUPERIOR", AlwaysOnTop = true, Size = Vector2.new(225, 88), MaxDistance = 280 },
	Exalted = { Tone = "Blood", Badge = "EXALTED", AlwaysOnTop = true, Size = Vector2.new(235, 90), MaxDistance = 300 },
	Legendary = { Tone = "Gilded", Badge = "LEGENDARY", AlwaysOnTop = true, Size = Vector2.new(245, 92), MaxDistance = 330 },
	Mythical = { Tone = "Blood", Badge = "MYTHICAL", AlwaysOnTop = true, Size = Vector2.new(255, 94), MaxDistance = 360 },
	Origin = { Tone = "Gilded", Badge = "ORIGIN", AlwaysOnTop = true, Size = Vector2.new(265, 96), MaxDistance = 400 },
}

local relicThemes: { [string]: Theme } = {
	MANA_GEODE = table.freeze({
		Tone = "Azure",
		Rail = Color3.fromRGB(120, 220, 255),
		Title = Color3.fromRGB(150, 230, 255),
		Accent = Color3.fromRGB(65, 190, 255),
		Badge = "COMMON",
		Size = Vector2.new(210, 84),
		MaxDistance = 240,
		AlwaysOnTop = false,
	}),
	CURSED_URN = table.freeze({
		Tone = "Amber",
		Rail = Color3.fromRGB(255, 196, 90),
		Title = Color3.fromRGB(255, 190, 80),
		TitleGradient = { Color3.fromRGB(255, 226, 140), Color3.fromRGB(255, 150, 40) },
		Accent = Color3.fromRGB(255, 150, 40),
		Badge = "RARE",
		Size = Vector2.new(220, 86),
		MaxDistance = 260,
		AlwaysOnTop = false,
	}),
	ABYSSAL_CORE = table.freeze({
		Tone = "Void",
		Rail = Color3.fromRGB(210, 130, 255),
		Title = Color3.fromRGB(215, 150, 255),
		TitleGradient = { Color3.fromRGB(240, 200, 255), Color3.fromRGB(170, 70, 255), Color3.fromRGB(240, 200, 255) },
		Accent = Color3.fromRGB(170, 60, 255),
		Badge = "ELITE EXCLUSIVE",
		Size = Vector2.new(230, 90),
		MaxDistance = 300,
		AlwaysOnTop = true,
	}),
	CALAMITY_HEART = table.freeze({
		Tone = "Blood",
		Rail = Color3.fromRGB(255, 214, 110),
		Title = Color3.fromRGB(255, 90, 100),
		TitleGradient = { Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 40, 70), Color3.fromRGB(255, 220, 120) },
		Accent = Color3.fromRGB(230, 25, 60),
		Badge = "ALPHA EXCLUSIVE",
		Size = Vector2.new(250, 94),
		MaxDistance = 360,
		AlwaysOnTop = true,
	}),
}

if RelicConfig and RelicConfig.Items then
	for itemId, item in pairs(RelicConfig.Items) do
		local rDef = rarityDefaults[item.Rarity] or rarityDefaults.Common
		local col = item.Color or Color3.fromRGB(255, 255, 255)
		local titleCol = col:Lerp(Color3.new(1, 1, 1), 0.35)
		local gradient = if item.BiomeTier >= 3 or item.Rarity == "Legendary" or item.Rarity == "Mythical" or item.Rarity == "Origin"
			then { col:Lerp(Color3.new(1, 1, 1), 0.5), col, col:Lerp(Color3.new(1, 1, 1), 0.5) }
			else nil

		relicThemes[itemId] = table.freeze({
			Tone = rDef.Tone,
			Rail = col,
			Title = titleCol,
			TitleGradient = gradient,
			Accent = col,
			Badge = rDef.Badge,
			Size = rDef.Size,
			MaxDistance = rDef.MaxDistance,
			AlwaysOnTop = rDef.AlwaysOnTop,
		})
	end
end

BillboardThemes.Relic = table.freeze(relicThemes)

BillboardThemes.Mob = table.freeze({
	NORMAL = table.freeze({
		Tone = "Slate",
		Rail = Color3.fromRGB(150, 140, 170),
		Title = Color3.fromRGB(255, 170, 160),
		Accent = Color3.fromRGB(245, 70, 90),
		Size = Vector2.new(150, 52),
		MaxDistance = 150,
		AlwaysOnTop = false,
	}),
	ELITE = table.freeze({
		Tone = "Void",
		Rail = Color3.fromRGB(210, 130, 255),
		Title = Color3.fromRGB(225, 175, 255),
		Accent = Color3.fromRGB(205, 70, 220),
		Badge = "ELITE",
		Size = Vector2.new(175, 56),
		MaxDistance = 200,
		AlwaysOnTop = false,
	}),
	ALPHA = table.freeze({
		Tone = "Gilded",
		Rail = Color3.fromRGB(255, 226, 130),
		Title = Color3.fromRGB(255, 220, 120),
		TitleGradient = { Color3.fromRGB(255, 248, 200), Color3.fromRGB(255, 190, 60), Color3.fromRGB(255, 248, 200) },
		Accent = Color3.fromRGB(255, 140, 40),
		Badge = "ALPHA",
		Size = Vector2.new(210, 62),
		MaxDistance = 260,
		AlwaysOnTop = true,
	}),
	BIOME_BOSS = table.freeze({
		Tone = "Blood",
		Rail = Color3.fromRGB(255, 214, 110),
		Title = Color3.fromRGB(255, 120, 110),
		TitleGradient = { Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 60, 80), Color3.fromRGB(255, 220, 120) },
		Accent = Color3.fromRGB(255, 40, 60),
		Badge = "BIOME BOSS",
		Size = Vector2.new(260, 70),
		MaxDistance = 320,
		AlwaysOnTop = true,
	}),
} :: { [MobTier]: Theme })

-- Hero nameplates by inherent rarity tier (HeroCatalog.RarityOf), in the ArtifactCatalog rarity colours. The HP bar
-- stays green so allies read as allies; Accent drives the badge and outline.
local function hero(tone: string, rail: Color3, title: Color3, accent: Color3, badge: string, width: number, gradient: { Color3 }?): Theme
	return table.freeze({
		Tone = tone,
		Rail = rail,
		Title = title,
		TitleGradient = gradient,
		Accent = accent,
		Badge = badge,
		Size = Vector2.new(width, 52),
		MaxDistance = 150,
		AlwaysOnTop = false,
	})
end

BillboardThemes.HeroByRarity = table.freeze({
	hero("Slate", Color3.fromRGB(190, 190, 196), Color3.fromRGB(225, 225, 230), Color3.fromRGB(150, 150, 158), "COMMON", 150),
	hero("Jade", Color3.fromRGB(120, 230, 120), Color3.fromRGB(150, 245, 150), Color3.fromRGB(60, 170, 70), "UNCOMMON", 150),
	hero("Azure", Color3.fromRGB(120, 200, 255), Color3.fromRGB(150, 215, 255), Color3.fromRGB(41, 128, 200), "RARE", 155),
	hero("Void", Color3.fromRGB(205, 140, 255), Color3.fromRGB(220, 175, 255), Color3.fromRGB(142, 68, 173), "SUPERIOR", 160),
	hero("Amber", Color3.fromRGB(255, 170, 80), Color3.fromRGB(255, 180, 90), Color3.fromRGB(211, 84, 0), "EXALTED", 165,
		{ Color3.fromRGB(255, 225, 150), Color3.fromRGB(255, 140, 40) }),
	hero("Gilded", Color3.fromRGB(255, 226, 130), Color3.fromRGB(255, 222, 110), Color3.fromRGB(220, 170, 15), "LEGENDARY", 170,
		{ Color3.fromRGB(255, 250, 210), Color3.fromRGB(255, 196, 40), Color3.fromRGB(255, 250, 210) }),
	hero("Blood", Color3.fromRGB(255, 214, 110), Color3.fromRGB(255, 110, 100), Color3.fromRGB(231, 76, 60), "MYTHICAL", 175,
		{ Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 70, 80), Color3.fromRGB(255, 220, 120) }),
} :: { Theme })

-- Theme for a hero rarity tier; tiers above the launch set (8-16) use the highest one until they get their own.
function BillboardThemes.Hero(tier: number?): Theme
	local list = BillboardThemes.HeroByRarity
	return list[math.clamp(math.floor(tier or 1), 1, #list)]
end

-- Tier of a FirstBiomeCombat / MobCatalog entry (Role + Alpha flag).
function BillboardThemes.MobTier(spec: { Role: string, Alpha: boolean? }?): MobTier
	if not spec then return "NORMAL" end
	if spec.Role == "BOSS" then return "BIOME_BOSS" end
	if spec.Alpha then return "ALPHA" end
	if spec.Role == "ELITE" then return "ELITE" end
	return "NORMAL"
end

-- Billboard size with room for the badge strip.
function BillboardThemes.BillboardSize(theme: Theme): UDim2
	local extra = if theme.Badge then BillboardThemes.BADGE_HEIGHT else 0
	return UDim2.fromOffset(theme.Size.X, theme.Size.Y + extra)
end

-- Builds the plate Frame inside `bb` (below the badge strip, if any) and the badge chip. Returns the plate;
-- callers frame it with GildedGrimoire.Frame(plate, { Tone = theme.Tone, Rail = theme.Rail }).
function BillboardThemes.Plate(bb: BillboardGui, theme: Theme, styleText: (TextLabel, string) -> ()): Frame
	local top = if theme.Badge then BillboardThemes.BADGE_HEIGHT - 4 else 0
	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.Position = UDim2.fromOffset(0, top)
	plate.Size = UDim2.new(1, 0, 1, -top)
	plate.BorderSizePixel = 0
	plate.Parent = bb
	if theme.Badge then
		local chip = Instance.new("TextLabel")
		chip.Name = "TierBadge"
		chip.AnchorPoint = Vector2.new(0.5, 0)
		chip.Position = UDim2.fromScale(0.5, 0)
		chip.AutomaticSize = Enum.AutomaticSize.X
		chip.Size = UDim2.fromOffset(0, BillboardThemes.BADGE_HEIGHT)
		chip.BackgroundColor3 = theme.Accent
		chip.BorderSizePixel = 0
		chip.Text = theme.Badge
		chip.TextColor3 = Color3.new(1, 1, 1)
		chip.TextSize = 11
		chip.ZIndex = 6
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 7)
		pad.PaddingRight = UDim.new(0, 7)
		pad.Parent = chip
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = chip
		local ink = Instance.new("UIStroke")
		ink.Color = Color3.fromRGB(10, 6, 14)
		ink.Thickness = 1.6
		ink.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		ink.Parent = chip
		local shade = Instance.new("UIGradient")
		shade.Rotation = 90
		shade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 180))
		shade.Parent = chip
		chip.Parent = bb
		styleText(chip, "Body")
	end
	return plate
end

-- Colours a title label: a gradient across the text for themes that have one, else the flat title colour.
function BillboardThemes.PaintTitle(label: TextLabel, theme: Theme)
	local stops = theme.TitleGradient
	if not stops then
		label.TextColor3 = theme.Title
		return
	end
	label.TextColor3 = Color3.new(1, 1, 1)
	local keys = {}
	for i, c in stops do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#stops - 1), c))
	end
	local grad = Instance.new("UIGradient")
	grad.Name = "TierGradient"
	grad.Color = ColorSequence.new(keys)
	grad.Parent = label
end

return table.freeze(BillboardThemes)
