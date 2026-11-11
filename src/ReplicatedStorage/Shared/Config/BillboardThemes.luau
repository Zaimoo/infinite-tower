--!strict
-- ReplicatedStorage/Shared/Config/BillboardThemes.luau
-- World-space billboard themes. Billboards have no plate: a name and (for units) a slim bar, both in the
-- colour of the thing's quality. Relics are coloured by rarity (RelicConfig tier), mobs by tier (Normal,
-- Elite, Alpha, Biome Boss) and heroes by inherent rarity, so a glance says what a drop is worth and what
-- you are fighting without a panel covering the fight.

export type Theme = {
	Tone: string, -- a key of GildedGrimoire.Tones (kept for screen UI that themes by tier)
	Rail: Color3,
	Title: Color3,
	TitleGradient: { Color3 }?, -- 2-3 stops, left to right, over the title text
	Accent: Color3, -- HP bar and Highlight outline
	Badge: string?, -- tier name for screen UI (the boss bar); never drawn in the world
	Size: Vector2, -- billboard pixels
	NameSize: number, -- title text size
	BarHeight: number, -- HP bar thickness (units only)
	MaxDistance: number,
	AlwaysOnTop: boolean,
}

export type MobTier = "NORMAL" | "ELITE" | "ALPHA" | "BIOME_BOSS"

local RelicConfig = require(script.Parent.RelicConfig)

local BillboardThemes = {}

BillboardThemes.Ink = Color3.fromRGB(10, 6, 14)

local relicThemes: { [string]: Theme } = {
	MANA_GEODE = table.freeze({
		Tone = "Azure",
		Rail = Color3.fromRGB(120, 220, 255),
		Title = Color3.fromRGB(150, 230, 255),
		Accent = Color3.fromRGB(65, 190, 255),
		Badge = "COMMON",
		Size = Vector2.new(220, 52),
		NameSize = 15,
		BarHeight = 0,
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
		Size = Vector2.new(220, 54),
		NameSize = 16,
		BarHeight = 0,
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
		Size = Vector2.new(240, 58),
		NameSize = 18,
		BarHeight = 0,
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
		Size = Vector2.new(260, 62),
		NameSize = 20,
		BarHeight = 0,
		MaxDistance = 360,
		AlwaysOnTop = true,
	}),
}

-- A biome relic wears its base tier's plate (tone, badge, size), with the rail and accent in the biome colour.
for itemId, item in pairs(RelicConfig.Items) do
	local theme = table.clone(relicThemes[item.BaseTierId]) :: any
	theme.Rail = item.Color
	theme.Accent = item.Color
	relicThemes[itemId] = table.freeze(theme)
end

BillboardThemes.Relic = table.freeze(relicThemes)

BillboardThemes.Mob = table.freeze({
	NORMAL = table.freeze({
		Tone = "Slate",
		Rail = Color3.fromRGB(150, 140, 170),
		Title = Color3.fromRGB(255, 170, 160),
		Accent = Color3.fromRGB(245, 70, 90),
		Size = Vector2.new(84, 24),
		NameSize = 12,
		BarHeight = 5,
		MaxDistance = 110,
		AlwaysOnTop = false,
	}),
	ELITE = table.freeze({
		Tone = "Void",
		Rail = Color3.fromRGB(210, 130, 255),
		Title = Color3.fromRGB(225, 175, 255),
		Accent = Color3.fromRGB(205, 70, 220),
		Badge = "ELITE",
		Size = Vector2.new(104, 26),
		NameSize = 13,
		BarHeight = 6,
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
		Size = Vector2.new(128, 30),
		NameSize = 15,
		BarHeight = 7,
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
		Size = Vector2.new(190, 34),
		NameSize = 18,
		BarHeight = 6, -- the screen-top boss bar is the real gauge
		MaxDistance = 320,
		AlwaysOnTop = true,
	}),
} :: { [MobTier]: Theme })

-- Hero nameplates by inherent rarity tier (HeroCatalog.RarityOf), in the ArtifactCatalog rarity colours: the
-- name and the HP bar both take the rarity colour.
local function hero(tone: string, rail: Color3, title: Color3, accent: Color3, badge: string, width: number, gradient: { Color3 }?): Theme
	return table.freeze({
		Tone = tone,
		Rail = rail,
		Title = title,
		TitleGradient = gradient,
		Accent = accent,
		Badge = badge,
		Size = Vector2.new(width, 28),
		NameSize = 13,
		BarHeight = 5,
		MaxDistance = 150,
		AlwaysOnTop = false,
	})
end

BillboardThemes.HeroByRarity = table.freeze({
	hero("Slate", Color3.fromRGB(190, 190, 196), Color3.fromRGB(225, 225, 230), Color3.fromRGB(150, 150, 158), "COMMON", 96),
	hero("Jade", Color3.fromRGB(120, 230, 120), Color3.fromRGB(150, 245, 150), Color3.fromRGB(60, 170, 70), "UNCOMMON", 96),
	hero("Azure", Color3.fromRGB(120, 200, 255), Color3.fromRGB(150, 215, 255), Color3.fromRGB(41, 128, 200), "RARE", 96),
	hero("Void", Color3.fromRGB(205, 140, 255), Color3.fromRGB(220, 175, 255), Color3.fromRGB(142, 68, 173), "SUPERIOR", 96),
	hero("Amber", Color3.fromRGB(255, 170, 80), Color3.fromRGB(255, 180, 90), Color3.fromRGB(211, 84, 0), "EXALTED", 96,
		{ Color3.fromRGB(255, 225, 150), Color3.fromRGB(255, 140, 40) }),
	hero("Gilded", Color3.fromRGB(255, 226, 130), Color3.fromRGB(255, 222, 110), Color3.fromRGB(220, 170, 15), "LEGENDARY", 96,
		{ Color3.fromRGB(255, 250, 210), Color3.fromRGB(255, 196, 40), Color3.fromRGB(255, 250, 210) }),
	hero("Blood", Color3.fromRGB(255, 214, 110), Color3.fromRGB(255, 110, 100), Color3.fromRGB(231, 76, 60), "MYTHICAL", 96,
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

function BillboardThemes.BillboardSize(theme: Theme): UDim2
	return UDim2.fromOffset(theme.Size.X, theme.Size.Y)
end

-- A line of world text with no background: `font` (callers pass a GildedGrimoire face) and an ink outline.
function BillboardThemes.Text(parent: Instance, font: Font, text: string, size: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.FontFace = font
	label.Text = text
	label.TextSize = size
	label.TextColor3 = color
	label.TextStrokeColor3 = BillboardThemes.Ink
	label.TextStrokeTransparency = 0
	label.TextWrapped = false
	label.Size = UDim2.new(1, 0, 0, size + 4)
	-- Marked so GildedGrimoire.Watch never re-fonts it.
	label:SetAttribute("Grimoire", true)
	label.Parent = parent
	return label
end

-- A slim gauge with no plate: a dark see-through track with a hairline of ink, and a flat fill in `color`.
-- Returns (track, fill); size the fill with UDim2.fromScale(fraction, 1).
function BillboardThemes.Bar(parent: Instance, color: Color3, height: number): (Frame, Frame)
	local track = Instance.new("Frame")
	track.Name = "Bar"
	track.BackgroundColor3 = BillboardThemes.Ink
	track.BackgroundTransparency = 0.4
	track.BorderSizePixel = 0
	track.Size = UDim2.new(1, -2, 0, height)
	local edge = Instance.new("UIStroke")
	edge.Color = BillboardThemes.Ink
	edge.Thickness = 1
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = track
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = track
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	fill.Parent = track
	track.Parent = parent
	return track, fill
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
