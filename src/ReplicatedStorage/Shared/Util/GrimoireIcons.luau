--!strict
-- ReplicatedStorage/Shared/Util/GrimoireIcons.luau
-- Gilded Grimoire icons: chunky "toy" drawings built from GUI shapes. Every shape has a top-lit
-- gradient, a thick black ink outline and a soft white sheen. Drawings live on a 64 x 64 grid and
-- are scaled with UIScale (outlines scale with them). No image assets and no emoji.
--
-- Imperative screens: GrimoireIcons.Create(name, size, parent?) returns a Frame.
-- React screens: StarterPlayerScripts/UI/Hud/Icons renders the same Drawings.
-- Weapons are not drawn here: they get their own art from their models.

local GrimoireIcons = {}

GrimoireIcons.Ink = Color3.fromRGB(10, 6, 14)

-- Gothic palette: obsidian, amethyst, antique gold, ember, steel, arcane cyan.
local P = {
	GoldHi = Color3.fromRGB(255, 226, 120), GoldLo = Color3.fromRGB(196, 120, 24),
	VioletHi = Color3.fromRGB(214, 150, 255), VioletLo = Color3.fromRGB(96, 34, 170),
	SteelHi = Color3.fromRGB(236, 238, 248), SteelLo = Color3.fromRGB(120, 124, 146),
	IronHi = Color3.fromRGB(110, 106, 124), IronLo = Color3.fromRGB(38, 34, 48),
	EmberHi = Color3.fromRGB(255, 196, 90), EmberLo = Color3.fromRGB(220, 60, 20),
	StoneHi = Color3.fromRGB(196, 190, 206), StoneLo = Color3.fromRGB(104, 96, 118),
	CyanHi = Color3.fromRGB(170, 250, 255), CyanLo = Color3.fromRGB(20, 140, 200),
	BloodHi = Color3.fromRGB(255, 110, 110), BloodLo = Color3.fromRGB(150, 16, 30),
	LeatherHi = Color3.fromRGB(168, 92, 60), LeatherLo = Color3.fromRGB(86, 38, 24),
	PageHi = Color3.fromRGB(255, 248, 226), PageLo = Color3.fromRGB(214, 196, 160),
	LeafHi = Color3.fromRGB(150, 255, 150), LeafLo = Color3.fromRGB(30, 150, 70),
	Dark = Color3.fromRGB(28, 22, 40),
	White = Color3.new(1, 1, 1),
}
GrimoireIcons.Palette = P

export type ShapeSpec = {
	X: number, Y: number, W: number, H: number, -- centre and size on the 64 grid
	Hi: Color3, Lo: Color3,
	Rot: number?, Radius: number?, Round: boolean?, Outline: number?, Sheen: boolean?,
}

-- Each icon is a list of shapes, back to front.
GrimoireIcons.Drawings = {
	-- Summoning: an amethyst crystal hovering over a gold altar, with a star spark.
	Summon = {
		{ X = 32, Y = 52, W = 40, H = 11, Hi = P.GoldHi, Lo = P.GoldLo, Radius = 4 },
		{ X = 32, Y = 45, W = 24, H = 7, Hi = P.GoldHi, Lo = P.GoldLo, Radius = 3 },
		{ X = 32, Y = 25, W = 24, H = 24, Rot = 45, Hi = P.VioletHi, Lo = P.VioletLo, Radius = 4 },
		{ X = 32, Y = 25, W = 10, H = 10, Rot = 45, Hi = P.White, Lo = P.VioletHi, Radius = 2, Outline = 1.6, Sheen = false },
		{ X = 50, Y = 10, W = 9, H = 9, Rot = 45, Hi = P.GoldHi, Lo = P.GoldLo, Radius = 1, Outline = 2 },
	},
	-- Squad: a steel heater shield with a gold boss and crossed blades behind it.
	Squad = {
		{ X = 32, Y = 30, W = 6, H = 52, Rot = 40, Hi = P.SteelHi, Lo = P.SteelLo, Radius = 2 },
		{ X = 32, Y = 30, W = 6, H = 52, Rot = -40, Hi = P.SteelHi, Lo = P.SteelLo, Radius = 2 },
		{ X = 32, Y = 30, W = 36, H = 30, Hi = P.BloodHi, Lo = P.BloodLo, Radius = 6 },
		{ X = 32, Y = 44, W = 25, H = 25, Rot = 45, Hi = P.BloodHi, Lo = P.BloodLo, Radius = 5, Sheen = false },
		{ X = 32, Y = 32, W = 12, H = 12, Hi = P.GoldHi, Lo = P.GoldLo, Round = true },
	},
	-- Forge: an iron anvil under a glowing ember hammer.
	Forge = {
		{ X = 32, Y = 54, W = 22, H = 10, Hi = P.IronHi, Lo = P.IronLo, Radius = 2 },
		{ X = 32, Y = 46, W = 12, H = 10, Hi = P.IronHi, Lo = P.IronLo, Radius = 1, Sheen = false },
		{ X = 30, Y = 38, W = 44, H = 10, Hi = P.IronHi, Lo = P.IronLo, Radius = 4 },
		{ X = 40, Y = 18, W = 7, H = 30, Rot = 35, Hi = P.LeatherHi, Lo = P.LeatherLo, Radius = 3 },
		{ X = 28, Y = 12, W = 26, H = 13, Rot = 35, Hi = P.EmberHi, Lo = P.EmberLo, Radius = 3 },
	},
	-- Fortress: a stone keep with an amethyst roof and a gold pennant.
	Fortress = {
		{ X = 32, Y = 44, W = 36, H = 30, Hi = P.StoneHi, Lo = P.StoneLo, Radius = 3 },
		{ X = 19, Y = 28, W = 9, H = 8, Hi = P.StoneHi, Lo = P.StoneLo, Radius = 1, Sheen = false },
		{ X = 45, Y = 28, W = 9, H = 8, Hi = P.StoneHi, Lo = P.StoneLo, Radius = 1, Sheen = false },
		{ X = 32, Y = 22, W = 24, H = 24, Rot = 45, Hi = P.VioletHi, Lo = P.VioletLo, Radius = 3 },
		{ X = 32, Y = 50, W = 12, H = 16, Hi = P.IronHi, Lo = P.IronLo, Radius = 6, Sheen = false },
		{ X = 40, Y = 6, W = 14, H = 7, Hi = P.GoldHi, Lo = P.GoldLo, Radius = 2, Outline = 2 },
	},
	-- Hero Index: an open leather tome with a gold bookmark.
	Index = {
		{ X = 32, Y = 36, W = 54, H = 36, Hi = P.LeatherHi, Lo = P.LeatherLo, Radius = 5 },
		{ X = 19, Y = 33, W = 24, H = 30, Rot = -6, Hi = P.PageHi, Lo = P.PageLo, Radius = 3 },
		{ X = 45, Y = 33, W = 24, H = 30, Rot = 6, Hi = P.PageHi, Lo = P.PageLo, Radius = 3 },
		{ X = 32, Y = 34, W = 4, H = 32, Hi = P.LeatherHi, Lo = P.LeatherLo, Radius = 2, Sheen = false, Outline = 1.8 },
		{ X = 44, Y = 52, W = 6, H = 14, Hi = P.BloodHi, Lo = P.BloodLo, Radius = 1, Outline = 1.8, Sheen = false },
	},
	-- Overdrive: a forked gold lightning bolt.
	Overdrive = {
		{ X = 37, Y = 18, W = 13, H = 30, Rot = 22, Hi = P.GoldHi, Lo = P.EmberLo, Radius = 2 },
		{ X = 32, Y = 32, W = 30, H = 10, Rot = -12, Hi = P.GoldHi, Lo = P.EmberHi, Radius = 2, Sheen = false },
		{ X = 27, Y = 46, W = 13, H = 30, Rot = 22, Hi = P.GoldHi, Lo = P.EmberLo, Radius = 2, Sheen = false },
	},
	-- Recall: an arcane portal ring with a homing chevron.
	Recall = {
		{ X = 32, Y = 32, W = 52, H = 52, Hi = P.CyanHi, Lo = P.CyanLo, Round = true },
		{ X = 32, Y = 32, W = 34, H = 34, Hi = Color3.fromRGB(16, 30, 52), Lo = Color3.fromRGB(8, 14, 30), Round = true, Sheen = false },
		{ X = 32, Y = 30, W = 18, H = 18, Rot = 45, Hi = P.White, Lo = P.CyanHi, Radius = 3, Outline = 2.2 },
		{ X = 32, Y = 42, W = 8, H = 14, Hi = P.White, Lo = P.CyanHi, Radius = 2, Outline = 2.2, Sheen = false },
	},
	-- Gold: a stack of three coins, the top one face-on with an embossed rim.
	Gold = {
		{ X = 32, Y = 50, W = 46, H = 14, Hi = P.GoldHi, Lo = P.GoldLo, Round = true },
		{ X = 32, Y = 41, W = 46, H = 14, Hi = P.GoldHi, Lo = P.GoldLo, Round = true, Sheen = false },
		{ X = 32, Y = 24, W = 40, H = 40, Hi = P.GoldHi, Lo = P.GoldLo, Round = true },
		{ X = 32, Y = 24, W = 26, H = 26, Hi = P.GoldLo, Lo = P.GoldHi, Round = true, Outline = 2, Sheen = false },
		{ X = 32, Y = 24, W = 9, H = 16, Hi = P.GoldHi, Lo = P.GoldLo, Radius = 2, Outline = 1.8, Sheen = false },
	},
	-- Gems: a cut cyan diamond (crown over a pavilion) with a white facet glint.
	Gems = {
		{ X = 32, Y = 36, W = 34, H = 34, Rot = 45, Hi = P.CyanHi, Lo = P.CyanLo, Radius = 4 },
		{ X = 32, Y = 22, W = 46, H = 14, Hi = Color3.fromRGB(220, 255, 255), Lo = P.CyanHi, Radius = 4 },
		{ X = 32, Y = 32, W = 12, H = 12, Rot = 45, Hi = P.White, Lo = P.CyanHi, Radius = 2, Outline = 1.6, Sheen = false },
	},
	-- Squad Power: two crossed swords with gold guards behind a shield boss.
	Power = {
		{ X = 32, Y = 30, W = 8, H = 54, Rot = 42, Hi = P.SteelHi, Lo = P.SteelLo, Radius = 2 },
		{ X = 32, Y = 30, W = 8, H = 54, Rot = -42, Hi = P.SteelHi, Lo = P.SteelLo, Radius = 2 },
		{ X = 18, Y = 46, W = 20, H = 7, Rot = 42, Hi = P.GoldHi, Lo = P.GoldLo, Radius = 2, Outline = 2, Sheen = false },
		{ X = 46, Y = 46, W = 20, H = 7, Rot = -42, Hi = P.GoldHi, Lo = P.GoldLo, Radius = 2, Outline = 2, Sheen = false },
		{ X = 32, Y = 32, W = 22, H = 22, Hi = P.BloodHi, Lo = P.BloodLo, Round = true },
		{ X = 32, Y = 32, W = 9, H = 9, Rot = 45, Hi = P.GoldHi, Lo = P.GoldLo, Radius = 1, Outline = 1.8, Sheen = false },
	},
	-- Next Goal: a parchment quest scroll with rolled ends and a wax seal.
	Goal = {
		{ X = 32, Y = 32, W = 40, H = 40, Hi = P.PageHi, Lo = P.PageLo, Radius = 3 },
		{ X = 32, Y = 13, W = 48, H = 10, Hi = P.PageHi, Lo = P.PageLo, Round = true },
		{ X = 32, Y = 51, W = 48, H = 10, Hi = P.PageHi, Lo = P.PageLo, Round = true, Sheen = false },
		{ X = 32, Y = 27, W = 24, H = 3, Hi = P.LeatherHi, Lo = P.LeatherLo, Radius = 1, Outline = 1, Sheen = false },
		{ X = 30, Y = 34, W = 20, H = 3, Hi = P.LeatherHi, Lo = P.LeatherLo, Radius = 1, Outline = 1, Sheen = false },
		{ X = 44, Y = 44, W = 14, H = 14, Hi = P.BloodHi, Lo = P.BloodLo, Round = true, Outline = 2 },
	},
	-- Locked: a gold padlock.
	Lock = {
		{ X = 32, Y = 22, W = 26, H = 28, Hi = P.SteelHi, Lo = P.SteelLo, Radius = 13, Sheen = false },
		{ X = 32, Y = 22, W = 14, H = 18, Hi = P.Dark, Lo = P.Dark, Radius = 7, Outline = 2, Sheen = false },
		{ X = 32, Y = 42, W = 40, H = 30, Hi = P.GoldHi, Lo = P.GoldLo, Radius = 5 },
		{ X = 32, Y = 42, W = 7, H = 12, Hi = P.Dark, Lo = P.Dark, Radius = 3, Outline = 1.6, Sheen = false },
	},
	-- Tower: an obsidian spire with a violet window and a gold finial.
	Tower = {
		{ X = 32, Y = 42, W = 22, H = 40, Hi = P.IronHi, Lo = P.IronLo, Radius = 3 },
		{ X = 32, Y = 20, W = 18, H = 18, Rot = 45, Hi = P.VioletHi, Lo = P.VioletLo, Radius = 2 },
		{ X = 32, Y = 40, W = 8, H = 12, Hi = P.VioletHi, Lo = P.VioletLo, Radius = 4, Outline = 2, Sheen = false },
		{ X = 32, Y = 7, W = 7, H = 7, Rot = 45, Hi = P.GoldHi, Lo = P.GoldLo, Radius = 1, Outline = 2 },
		{ X = 32, Y = 60, W = 34, H = 7, Hi = P.StoneHi, Lo = P.StoneLo, Radius = 2 },
	},

	-- Archetypes ------------------------------------------------------------------------------
	-- Vanguard: a steel heater shield with a gold boss.
	Vanguard = {
		{ X = 32, Y = 26, W = 42, H = 30, Hi = P.SteelHi, Lo = P.SteelLo, Radius = 6 },
		{ X = 32, Y = 40, W = 30, H = 30, Rot = 45, Hi = P.SteelHi, Lo = P.SteelLo, Radius = 5, Sheen = false },
		{ X = 32, Y = 32, W = 6, H = 34, Hi = P.BloodHi, Lo = P.BloodLo, Radius = 2, Outline = 1.8, Sheen = false },
		{ X = 32, Y = 30, W = 14, H = 14, Hi = P.GoldHi, Lo = P.GoldLo, Round = true },
	},
	-- Striker: two crossed daggers with gold guards and leather grips.
	Striker = {
		{ X = 30, Y = 28, W = 8, H = 40, Rot = 38, Hi = P.SteelHi, Lo = P.SteelLo, Radius = 3 },
		{ X = 34, Y = 28, W = 8, H = 40, Rot = -38, Hi = P.SteelHi, Lo = P.SteelLo, Radius = 3 },
		{ X = 18, Y = 46, W = 18, H = 6, Rot = 38, Hi = P.GoldHi, Lo = P.GoldLo, Radius = 2, Outline = 2, Sheen = false },
		{ X = 46, Y = 46, W = 18, H = 6, Rot = -38, Hi = P.GoldHi, Lo = P.GoldLo, Radius = 2, Outline = 2, Sheen = false },
		{ X = 13, Y = 54, W = 7, H = 12, Rot = 38, Hi = P.LeatherHi, Lo = P.LeatherLo, Radius = 2, Outline = 2, Sheen = false },
		{ X = 51, Y = 54, W = 7, H = 12, Rot = -38, Hi = P.LeatherHi, Lo = P.LeatherLo, Radius = 2, Outline = 2, Sheen = false },
	},
	-- Marksman: a fletched arrow with a steel head.
	Marksman = {
		{ X = 32, Y = 32, W = 6, H = 54, Rot = 45, Hi = P.LeatherHi, Lo = P.LeatherLo, Radius = 2 },
		{ X = 12, Y = 46, W = 8, H = 16, Rot = 0, Hi = P.BloodHi, Lo = P.BloodLo, Radius = 2, Outline = 2, Sheen = false },
		{ X = 18, Y = 52, W = 16, H = 8, Rot = 0, Hi = P.BloodHi, Lo = P.BloodLo, Radius = 2, Outline = 2, Sheen = false },
		{ X = 48, Y = 16, W = 18, H = 18, Rot = 45, Hi = P.SteelHi, Lo = P.SteelLo, Radius = 3 },
	},
	-- Miner: a pickaxe with a steel head and leather haft.
	Miner = {
		{ X = 32, Y = 36, W = 8, H = 50, Rot = 35, Hi = P.LeatherHi, Lo = P.LeatherLo, Radius = 3 },
		{ X = 40, Y = 18, W = 50, H = 11, Rot = 35, Hi = P.SteelHi, Lo = P.SteelLo, Radius = 5 },
		{ X = 41, Y = 18, W = 12, H = 14, Rot = 35, Hi = P.GoldHi, Lo = P.GoldLo, Radius = 3, Outline = 2, Sheen = false },
	},
	-- Scholar: a violet scrying orb on a gold stand.
	Scholar = {
		{ X = 32, Y = 54, W = 34, H = 9, Hi = P.GoldHi, Lo = P.GoldLo, Radius = 3 },
		{ X = 32, Y = 46, W = 18, H = 8, Hi = P.GoldHi, Lo = P.GoldLo, Radius = 2, Sheen = false },
		{ X = 32, Y = 26, W = 38, H = 38, Hi = P.VioletHi, Lo = P.VioletLo, Round = true },
		{ X = 32, Y = 26, W = 12, H = 12, Rot = 45, Hi = P.White, Lo = P.VioletHi, Radius = 2, Outline = 1.6, Sheen = false },
	},
	-- Healer: a green cross with a white heart-glint.
	Healer = {
		{ X = 32, Y = 32, W = 18, H = 48, Hi = P.LeafHi, Lo = P.LeafLo, Radius = 5 },
		{ X = 32, Y = 32, W = 48, H = 18, Hi = P.LeafHi, Lo = P.LeafLo, Radius = 5 },
		{ X = 32, Y = 32, W = 10, H = 10, Rot = 45, Hi = P.White, Lo = P.LeafHi, Radius = 2, Outline = 1.6, Sheen = false },
	},

	-- Facilities and branches -----------------------------------------------------------------
	-- Guard Post / Outskirts: a campfire on crossed logs.
	Camp = {
		{ X = 32, Y = 52, W = 46, H = 9, Rot = 14, Hi = P.LeatherHi, Lo = P.LeatherLo, Radius = 4 },
		{ X = 32, Y = 52, W = 46, H = 9, Rot = -14, Hi = P.LeatherHi, Lo = P.LeatherLo, Radius = 4 },
		{ X = 32, Y = 30, W = 28, H = 28, Rot = 45, Hi = P.EmberHi, Lo = P.EmberLo, Radius = 6 },
		{ X = 32, Y = 36, W = 14, H = 14, Rot = 45, Hi = P.White, Lo = P.GoldHi, Radius = 3, Outline = 1.8, Sheen = false },
	},
	-- Market / Commerce: a leather-strapped crate with a gold clasp.
	Market = {
		{ X = 32, Y = 38, W = 48, H = 34, Hi = P.LeatherHi, Lo = P.LeatherLo, Radius = 4 },
		{ X = 32, Y = 24, W = 52, H = 10, Hi = P.GoldHi, Lo = P.GoldLo, Radius = 3 },
		{ X = 18, Y = 40, W = 5, H = 30, Hi = P.IronHi, Lo = P.IronLo, Radius = 1, Outline = 1.6, Sheen = false },
		{ X = 46, Y = 40, W = 5, H = 30, Hi = P.IronHi, Lo = P.IronLo, Radius = 1, Outline = 1.6, Sheen = false },
		{ X = 32, Y = 32, W = 12, H = 12, Hi = P.GoldHi, Lo = P.GoldLo, Radius = 2, Outline = 2 },
	},
	-- God's Blessing / Divine: a gold halo over white wings.
	Blessing = {
		{ X = 18, Y = 38, W = 22, H = 36, Rot = -28, Hi = P.White, Lo = P.PageLo, Radius = 10 },
		{ X = 46, Y = 38, W = 22, H = 36, Rot = 28, Hi = P.White, Lo = P.PageLo, Radius = 10 },
		{ X = 32, Y = 40, W = 16, H = 16, Hi = P.GoldHi, Lo = P.GoldLo, Round = true },
		{ X = 32, Y = 12, W = 38, H = 12, Hi = P.GoldHi, Lo = P.GoldLo, Round = true },
		{ X = 32, Y = 12, W = 24, H = 5, Hi = P.Dark, Lo = P.Dark, Round = true, Outline = 1.6, Sheen = false },
	},
	-- Command: a crimson war banner on an iron pole.
	Banner = {
		{ X = 18, Y = 34, W = 6, H = 56, Hi = P.IronHi, Lo = P.IronLo, Radius = 2 },
		{ X = 36, Y = 22, W = 32, H = 26, Hi = P.BloodHi, Lo = P.BloodLo, Radius = 3 },
		{ X = 42, Y = 36, W = 16, H = 16, Rot = 45, Hi = P.BloodHi, Lo = P.BloodLo, Radius = 2, Sheen = false },
		{ X = 36, Y = 22, W = 10, H = 10, Rot = 45, Hi = P.GoldHi, Lo = P.GoldLo, Radius = 1, Outline = 1.8, Sheen = false },
		{ X = 18, Y = 6, W = 10, H = 10, Hi = P.GoldHi, Lo = P.GoldLo, Round = true, Outline = 2 },
	},
	-- Close: two crossed bone-white bars (text "×"/"✕" glyphs are missing from Cinzel and draw as squares).
	Close = {
		{ X = 32, Y = 32, W = 12, H = 52, Rot = 45, Hi = P.White, Lo = P.StoneHi, Radius = 4 },
		{ X = 32, Y = 32, W = 12, H = 52, Rot = -45, Hi = P.White, Lo = P.StoneHi, Radius = 4, Sheen = false },
	},
	-- Settings: a steel cog with a gold hub.
	Gear = {
		{ X = 32, Y = 32, W = 12, H = 58, Hi = P.SteelHi, Lo = P.SteelLo, Radius = 3 },
		{ X = 32, Y = 32, W = 12, H = 58, Rot = 45, Hi = P.SteelHi, Lo = P.SteelLo, Radius = 3, Sheen = false },
		{ X = 32, Y = 32, W = 12, H = 58, Rot = 90, Hi = P.SteelHi, Lo = P.SteelLo, Radius = 3, Sheen = false },
		{ X = 32, Y = 32, W = 12, H = 58, Rot = 135, Hi = P.SteelHi, Lo = P.SteelLo, Radius = 3, Sheen = false },
		{ X = 32, Y = 32, W = 42, H = 42, Hi = P.SteelHi, Lo = P.SteelLo, Round = true },
		{ X = 32, Y = 32, W = 22, H = 22, Hi = P.GoldHi, Lo = P.GoldLo, Round = true },
		{ X = 32, Y = 32, W = 9, H = 9, Hi = P.Dark, Lo = P.Dark, Round = true, Outline = 2, Sheen = false },
	},
	-- Perks and rewards: a four-point gold spark.
	Spark = {
		{ X = 32, Y = 32, W = 12, H = 52, Hi = P.GoldHi, Lo = P.GoldLo, Radius = 6 },
		{ X = 32, Y = 32, W = 52, H = 12, Hi = P.GoldHi, Lo = P.GoldLo, Radius = 6, Sheen = false },
		{ X = 32, Y = 32, W = 22, H = 22, Rot = 45, Hi = P.White, Lo = P.GoldHi, Radius = 4 },
	},
}

-- Aliases so callers can use game names directly.
local ALIAS: { [string]: string } = {
	Root = "Fortress", Outskirts = "Camp", Commerce = "Market", Martial = "Power", Divine = "Blessing",
	Command = "Banner", Perk = "Spark", GuardPost = "Camp", TrainingGrounds = "Power", GodsBlessing = "Blessing",
	Training = "Power", Gem = "Gems",
}

function GrimoireIcons.Resolve(name: string): { ShapeSpec }?
	local d = GrimoireIcons.Drawings :: any
	return d[name] or d[ALIAS[name] or ""]
end

local function shape(s: ShapeSpec, z: number, parent: Instance)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset(s.X, s.Y)
	f.Size = UDim2.fromOffset(s.W, s.H)
	f.Rotation = s.Rot or 0
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BorderSizePixel = 0
	f.ZIndex = z
	local c = Instance.new("UICorner")
	c.CornerRadius = if s.Round then UDim.new(1, 0) else UDim.new(0, s.Radius or 3)
	c.Parent = f
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(s.Hi, s.Lo)
	g.Rotation = 90
	g.Parent = f
	local o = Instance.new("UIStroke")
	o.Color = GrimoireIcons.Ink
	o.Thickness = s.Outline or 2.6
	o.LineJoinMode = Enum.LineJoinMode.Round
	o.Parent = f
	if s.Sheen ~= false then
		local sh = Instance.new("Frame")
		sh.Position = UDim2.new(0.14, 0, 0.1, 0)
		sh.Size = UDim2.new(0.42, 0, 0.18, 0)
		sh.BackgroundColor3 = Color3.new(1, 1, 1)
		sh.BackgroundTransparency = 0.55
		sh.BorderSizePixel = 0
		sh.ZIndex = z
		local sc = Instance.new("UICorner")
		sc.CornerRadius = UDim.new(1, 0)
		sc.Parent = sh
		sh.Parent = f
	end
	f.Parent = parent
end

-- Builds icon `name` at `size` pixels. Returns the outer Frame (position it like any GuiObject).
-- `zIndex` is the base ZIndex of the shapes (default 1).
function GrimoireIcons.Create(name: string, size: number, parent: Instance?, zIndex: number?): Frame
	local root = Instance.new("Frame")
	root.Name = "GrimoireIcon_" .. name
	root.Size = UDim2.fromOffset(size, size)
	root.BackgroundTransparency = 1
	root.ZIndex = zIndex or 1
	local canvas = Instance.new("Frame")
	canvas.Name = "Canvas"
	canvas.Size = UDim2.fromOffset(64, 64)
	canvas.BackgroundTransparency = 1
	canvas.ZIndex = zIndex or 1
	local scale = Instance.new("UIScale")
	scale.Scale = size / 64
	scale.Parent = canvas
	local drawing = GrimoireIcons.Resolve(name)
	if drawing then
		for i, spec in drawing do
			shape(spec, (zIndex or 1) + i, canvas)
		end
	end
	canvas.Parent = root
	if parent then root.Parent = parent end
	return root
end

-- Turns a text close button into a drawn one: clears its "×" text and centres the Close icon.
function GrimoireIcons.CloseGlyph(button: TextButton, size: number?): Frame
	button.Text = ""
	local old = button:FindFirstChild("GrimoireIcon_Close")
	if old then old:Destroy() end
	local icon = GrimoireIcons.Create("Close", size or 16, button, button.ZIndex + 1)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	return icon
end

-- A horizontal "icon + text" row (e.g. a Gems cost): returns the row Frame and its TextLabel.
-- The label is left for the caller (or GildedGrimoire.Watch) to style.
function GrimoireIcons.IconText(name: string, iconSize: number, parent: Instance?, zIndex: number?): (Frame, TextLabel)
	local row = Instance.new("Frame")
	row.Name = "IconText"
	row.BackgroundTransparency = 1
	row.AutomaticSize = Enum.AutomaticSize.X
	row.Size = UDim2.fromOffset(0, iconSize)
	row.ZIndex = zIndex or 1
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = row
	local icon = GrimoireIcons.Create(name, iconSize, row, zIndex)
	icon.LayoutOrder = 1
	local lbl = Instance.new("TextLabel")
	lbl.Name = "Text"
	lbl.BackgroundTransparency = 1
	lbl.AutomaticSize = Enum.AutomaticSize.X
	lbl.Size = UDim2.fromOffset(0, iconSize)
	lbl.LayoutOrder = 2
	lbl.ZIndex = (zIndex or 1) + 8
	lbl.Parent = row
	if parent then row.Parent = parent end
	return row, lbl
end

return GrimoireIcons
