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
})

UIAssets.Sounds = table.freeze({
	Click = "rbxassetid://139403951941162", -- the existing settings click
	Hover = "",
	Error = "", -- refused action / not enough Gems
	ToastIn = "",
	WindowOpen = "", -- soft page/whoosh when a window pops open
	TabSwitch = "",
	Reward = "", -- coins/gems landing (offline rewards, claims)
	SummonCharge = "", -- rift orb charging (≈0.6 s riser)
	SummonPulse = "", -- each orb pulse
	SummonBurstCommon = "",
	SummonBurstRare = "", -- Superior+
	SummonBurstJackpot = "", -- Legendary+ / 5★ artifact; choir hit
	CardFlip = "",
	StarTick = "", -- one per star as they pop in
	ResultsPop = "", -- each card in the 10x grid
	NewBadge = "",
})

return UIAssets
