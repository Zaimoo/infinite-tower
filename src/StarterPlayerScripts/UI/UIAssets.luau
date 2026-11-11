--!strict
-- StarterPlayerScripts/UI/UIAssets.luau
-- One place for the uploaded art and audio the UI can use. Every slot is optional: an empty string
-- means "not uploaded yet", and the code falls back to its procedural look (drawn frames, gradients,
-- GrimoireIcons) or stays silent. Paste an rbxassetid:// here and the UI picks it up; nothing else
-- needs to change. The full brief for each slot is in docs/ui/UI_ASSET_REQUESTS.md.

local UIAssets = {}

UIAssets.Images = table.freeze({
	-- Backpack materials
	PromotionStone = "rbxassetid://78914267684294",
	-- Summon reveal
	RevealRays = "", -- 1024² additive sunburst, white on transparent; tinted by rarity and spun.
	RevealGlow = "", -- 512² soft radial glow, white centre to transparent edge.
	RevealSparkle = "", -- 128² four-point star sparkle, white.
	RevealRiftOrb = "", -- 512² swirling rift orb, greyscale (tinted by rarity).
	CardBack = "", -- 540×760 card back shown before the flip (Gilded Grimoire sigil).
	CardFoil = "", -- 540×760 holographic foil sweep for Superior+ cards, greyscale.
	-- Banner key art (behind the featured hero on the Summoning screen)
	BannerCallOfTheRift = "", -- 1600×900 permanent banner background.
	BannerStarsArrival = "", -- 1600×900 limited banner background.
	BannerArtifactForge = "", -- 1600×900 artifact banner background.
	-- Tower Biome Banners (Infinite Tower Travel & Hub Floor Selector)
	BiomeBanners = table.freeze({
		verdant_ruins = "rbxassetid://93875713627917",
		fungal_hollow = "rbxassetid://101580789455814",
		ashen_dunes = "rbxassetid://94817733825787",
		frozen_citadel = "rbxassetid://106259487975925",
		infernal_foundry = "rbxassetid://85509085913763",
		thunder_highlands = "rbxassetid://122513568623188",
		corrupted_grove = "rbxassetid://110433752583302",
		sunken_sanctuary = "rbxassetid://129768018099787",
		astral_archives = "rbxassetid://116413443963257",
		abyssal_throne = "rbxassetid://92731064207895",
	}),
})

UIAssets.Sounds = table.freeze({
	Click = "rbxassetid://139403951941162", -- the existing settings click
	Hover = "rbxassetid://88442833509532", -- ui-simple-button-click
	Error = "rbxassetid://139892036682632", -- Cancel deltarune
	ToastIn = "rbxassetid://73774648241042", -- RatingExcellent / chime
	WindowOpen = "rbxassetid://9065073444", -- Darkest Dungeon SFX UI Button Click
	TabSwitch = "rbxassetid://9065073444", -- quick tactile tab tick
	Reward = "rbxassetid://4612375051", -- coin_pickup_3
	SummonCharge = "rbxassetid://133193041768155", -- Dark Blast riser
	SummonPulse = "rbxassetid://126976659766267", -- Impact blunt pulse
	SummonBurstCommon = "rbxassetid://73774648241042", -- common/superior card burst
	SummonBurstRare = "rbxassetid://4612374036", -- bling_big_diamond_pickup
	SummonBurstJackpot = "rbxassetid://133193041768155", -- Dark Blast jackpot
	CardFlip = "rbxassetid://9065073444", -- textured card flip
	StarTick = "rbxassetid://4612374036", -- bling diamond star tick
	ResultsPop = "rbxassetid://9065073444", -- each card in the 10x grid
	NewBadge = "rbxassetid://4612374036", -- new badge chime
})

local BIOME_BANNER_BY_INDEX: { [number]: string } = table.freeze({
	[1] = "rbxassetid://93875713627917",
	[2] = "rbxassetid://101580789455814",
	[3] = "rbxassetid://94817733825787",
	[4] = "rbxassetid://106259487975925",
	[5] = "rbxassetid://85509085913763",
	[6] = "rbxassetid://122513568623188",
	[7] = "rbxassetid://110433752583302",
	[8] = "rbxassetid://129768018099787",
	[9] = "rbxassetid://116413443963257",
	[10] = "rbxassetid://92731064207895",
})

function UIAssets.GetBiomeBanner(biomeKeyOrIndex: string | number): string
	if type(biomeKeyOrIndex) == "number" then
		return BIOME_BANNER_BY_INDEX[biomeKeyOrIndex] or ""
	elseif type(biomeKeyOrIndex) == "string" then
		local images = UIAssets.Images :: any
		local banners = images and images.BiomeBanners
		return (banners and banners[biomeKeyOrIndex]) or ""
	end
	return ""
end

return UIAssets
