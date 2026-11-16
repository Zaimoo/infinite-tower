--!strict
-- ReplicatedStorage/Shared/Config/ShopConfig.luau
-- Robux Store (Phase 5). Every offer is a Developer Product. ProductId 0 means "not created yet":
-- the store shows the offer as COMING SOON and the server ignores it.
--
-- To go live: create each product in the Creator Dashboard, paste its id here, and set the same
-- Robux price there (the store reads the live price; RobuxPrice is only the fallback label).
-- Do not go live until player profiles are saved to a DataStore, or purchases are lost on leave.
--
-- Grants:
--   Gems / Gold: added to the profile's Currencies.
--   Summons:     free pulls on a hero banner. These are paid random items, so players whose
--                PolicyService marks paid random items as restricted never see them, and the
--                server converts any such purchase into Gems (the banner's 1x price per summon).
--   BattlePass:  unlocks the premium Battle Pass row for the season in which the receipt is granted
--                (GDD §4.9). Not random: every reward and its level is shown before purchase.

export type Grant = { Kind: "Gems" | "Gold" | "Summons" | "BattlePass", Amount: number, Banner: string? }

export type Offer = {
	Id: string,
	ProductId: number,
	RobuxPrice: number,
	Label: string,
	Grant: Grant,
	Tag: string?, -- e.g. "BEST VALUE", "+20%"
	WasPrice: number?, -- struck-through reference price
}

local ShopConfig = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HeroCatalog = require(ReplicatedStorage.Shared.Config.HeroCatalog)
local ArtifactCatalog = require(ReplicatedStorage.Shared.Config.ArtifactCatalog)

-- Gems a restricted player gets per summon: the 1x price of the banner the pack pulls on.
function ShopConfig.GemsPerSummon(banner: string?): number
	-- The Gilded Mirror and Gilded Anvil have no Gem price: restricted purchases convert at the Store rate.
	if banner == "GILDED_MIRROR" then return HeroCatalog.MirrorBanner.RestrictedGemsPerPull end
	if banner == "GILDED_ANVIL" then return ArtifactCatalog.AnvilBanner.RestrictedGemsPerPull end
	local catalog = if banner == "A_STARS_ARRIVAL" then HeroCatalog.LimitedBanner else HeroCatalog.PermanentBanner
	return catalog.Cost1X
end

-- Featured limited pack: summons on A Star's Arrival, showcasing its top heroes.
ShopConfig.Featured = table.freeze({
	Title = "STAR'S ARRIVAL PACK",
	Subtitle = "Summon the limited banner's legends",
	Banner = "A_STARS_ARRIVAL",
	ShowcaseTiers = table.freeze({ 7, 6, 5, 4 }), -- LimitedBanner.HeroesByStar tiers shown, top tier largest
	Offers = table.freeze({
		table.freeze({ Id = "pack_summon_1", ProductId = 0, RobuxPrice = 39, Label = "Buy 1", Grant = { Kind = "Summons", Amount = 1, Banner = "A_STARS_ARRIVAL" } }),
		table.freeze({ Id = "pack_summon_5", ProductId = 0, RobuxPrice = 149, Label = "Buy 5", Grant = { Kind = "Summons", Amount = 5, Banner = "A_STARS_ARRIVAL" } }),
		table.freeze({ Id = "pack_summon_10", ProductId = 0, RobuxPrice = 239, WasPrice = 390, Label = "Buy 10", Tag = "-39%",
			Grant = { Kind = "Summons", Amount = 10, Banner = "A_STARS_ARRIVAL" } }),
	} :: { Offer }),
})

-- The Gilded Mirror (docs/gilded-mirror-plan.md): Robux-only pulls on HeroCatalog.MirrorBanner.
ShopConfig.Mirror = table.freeze({
	Title = "THE GILDED MIRROR",
	Subtitle = "Heroes that copy your best hero",
	Banner = "GILDED_MIRROR",
	Offers = table.freeze({
		table.freeze({ Id = "pack_mirror_1", ProductId = 0, RobuxPrice = 49, Label = "Buy 1", Grant = { Kind = "Summons", Amount = 1, Banner = "GILDED_MIRROR" } }),
		table.freeze({ Id = "pack_mirror_10", ProductId = 0, RobuxPrice = 499, Label = "Buy 10",
			Grant = { Kind = "Summons", Amount = 10, Banner = "GILDED_MIRROR" } }),
	} :: { Offer }),
})

-- The Gilded Anvil (docs/gilded-anvil-plan.md): Robux-only pulls on ArtifactCatalog.AnvilBanner.
ShopConfig.Anvil = table.freeze({
	Title = "THE GILDED ANVIL",
	Subtitle = "Six Tier-8 Gildforged relics · Pick your Focus",
	Banner = "GILDED_ANVIL",
	Offers = table.freeze({
		table.freeze({ Id = "pack_anvil_1", ProductId = 0, RobuxPrice = 49, Label = "Buy 1", Grant = { Kind = "Summons", Amount = 1, Banner = "GILDED_ANVIL" } }),
		table.freeze({ Id = "pack_anvil_10", ProductId = 0, RobuxPrice = 449, WasPrice = 490, Label = "Buy 10", Tag = "-8%",
			Grant = { Kind = "Summons", Amount = 10, Banner = "GILDED_ANVIL" } }),
	} :: { Offer }),
})

ShopConfig.Gems = table.freeze({
	table.freeze({ Id = "gems_1000", ProductId = 0, RobuxPrice = 19, Label = "Pouch of Gems", Grant = { Kind = "Gems", Amount = 1000 } }),
	table.freeze({ Id = "gems_2840", ProductId = 0, RobuxPrice = 49, Label = "Sack of Gems", Tag = "+10%", Grant = { Kind = "Gems", Amount = 2840 } }),
	table.freeze({ Id = "gems_6250", ProductId = 0, RobuxPrice = 99, Label = "Chest of Gems", Tag = "+20%", Grant = { Kind = "Gems", Amount = 6250 } }),
	table.freeze({ Id = "gems_15700", ProductId = 0, RobuxPrice = 199, Label = "Vault of Gems", Tag = "BEST VALUE", Grant = { Kind = "Gems", Amount = 15700 } }),
} :: { Offer })

ShopConfig.Gold = table.freeze({
	table.freeze({ Id = "gold_100k", ProductId = 0, RobuxPrice = 19, Label = "Coin Purse", Grant = { Kind = "Gold", Amount = 100000 } }),
	table.freeze({ Id = "gold_520k", ProductId = 0, RobuxPrice = 79, Label = "Gold Strongbox", Tag = "+25%", Grant = { Kind = "Gold", Amount = 520000 } }),
	table.freeze({ Id = "gold_1680k", ProductId = 0, RobuxPrice = 199, Label = "Dragon's Hoard", Tag = "BEST VALUE", Grant = { Kind = "Gold", Amount = 1680000 } }),
} :: { Offer })

-- Premium Battle Pass (GDD §4.9). One purchase per season; the Battle Pass window sells it.
ShopConfig.Pass = table.freeze({
	table.freeze({ Id = "pass_premium", ProductId = 0, RobuxPrice = 399, Label = "Premium Pass", Grant = { Kind = "BattlePass", Amount = 1 } }),
} :: { Offer })

-- Every offer, by ProductId (live products only) and by Id.
local byProduct: { [number]: Offer } = {}
local byId: { [string]: Offer } = {}
for _, list in { ShopConfig.Featured.Offers, ShopConfig.Mirror.Offers, ShopConfig.Anvil.Offers, ShopConfig.Gems, ShopConfig.Gold, ShopConfig.Pass } do
	for _, offer in list :: { Offer } do
		byId[offer.Id] = offer
		if offer.ProductId ~= 0 then
			assert(byProduct[offer.ProductId] == nil, "ShopConfig: duplicate ProductId " .. offer.ProductId)
			byProduct[offer.ProductId] = offer
		end
	end
end

function ShopConfig.ByProductId(productId: number): Offer?
	return byProduct[productId]
end

function ShopConfig.ById(id: string): Offer?
	return byId[id]
end

-- Summons granted to a player who may not buy paid random items become Gems instead.
function ShopConfig.SafeGrant(grant: Grant, paidRandomRestricted: boolean): Grant
	if grant.Kind == "Summons" and paidRandomRestricted then
		return { Kind = "Gems", Amount = grant.Amount * ShopConfig.GemsPerSummon(grant.Banner) }
	end
	return grant
end

return ShopConfig
