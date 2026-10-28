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
--                server converts any such purchase into Gems (GemsPerSummon each).

export type Grant = { Kind: "Gems" | "Gold" | "Summons", Amount: number, Banner: string? }

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

ShopConfig.GemsPerSummon = 100

-- Featured limited pack: summons on A Star's Arrival, showcasing its top heroes.
ShopConfig.Featured = table.freeze({
	Title = "STAR'S ARRIVAL PACK",
	Subtitle = "Summon the limited banner's legends",
	Banner = "A_STARS_ARRIVAL",
	ShowcaseTiers = table.freeze({ 7, 6, 5, 4 }), -- LimitedBanner.HeroesByStar tiers shown, top tier largest
	Offers = table.freeze({
		table.freeze({ Id = "pack_summon_1", ProductId = 0, RobuxPrice = 80, Label = "Buy 1", Grant = { Kind = "Summons", Amount = 1, Banner = "A_STARS_ARRIVAL" } }),
		table.freeze({ Id = "pack_summon_5", ProductId = 0, RobuxPrice = 400, Label = "Buy 5", Grant = { Kind = "Summons", Amount = 5, Banner = "A_STARS_ARRIVAL" } }),
		table.freeze({ Id = "pack_summon_10", ProductId = 0, RobuxPrice = 720, WasPrice = 800, Label = "Buy 10", Tag = "-10%",
			Grant = { Kind = "Summons", Amount = 10, Banner = "A_STARS_ARRIVAL" } }),
	} :: { Offer }),
})

ShopConfig.Gems = table.freeze({
	table.freeze({ Id = "gems_160", ProductId = 0, RobuxPrice = 80, Label = "Pouch of Gems", Grant = { Kind = "Gems", Amount = 160 } }),
	table.freeze({ Id = "gems_550", ProductId = 0, RobuxPrice = 250, Label = "Sack of Gems", Tag = "+10%", Grant = { Kind = "Gems", Amount = 550 } }),
	table.freeze({ Id = "gems_1200", ProductId = 0, RobuxPrice = 500, Label = "Chest of Gems", Tag = "+20%", Grant = { Kind = "Gems", Amount = 1200 } }),
	table.freeze({ Id = "gems_3000", ProductId = 0, RobuxPrice = 1000, Label = "Vault of Gems", Tag = "BEST VALUE", Grant = { Kind = "Gems", Amount = 3000 } }),
} :: { Offer })

ShopConfig.Gold = table.freeze({
	table.freeze({ Id = "gold_5k", ProductId = 0, RobuxPrice = 50, Label = "Coin Purse", Grant = { Kind = "Gold", Amount = 5000 } }),
	table.freeze({ Id = "gold_25k", ProductId = 0, RobuxPrice = 200, Label = "Gold Strongbox", Tag = "+25%", Grant = { Kind = "Gold", Amount = 25000 } }),
	table.freeze({ Id = "gold_80k", ProductId = 0, RobuxPrice = 500, Label = "Dragon's Hoard", Tag = "BEST VALUE", Grant = { Kind = "Gold", Amount = 80000 } }),
} :: { Offer })

-- Every offer, by ProductId (live products only) and by Id.
local byProduct: { [number]: Offer } = {}
local byId: { [string]: Offer } = {}
for _, list in { ShopConfig.Featured.Offers, ShopConfig.Gems, ShopConfig.Gold } do
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
		return { Kind = "Gems", Amount = grant.Amount * ShopConfig.GemsPerSummon }
	end
	return grant
end

return ShopConfig
