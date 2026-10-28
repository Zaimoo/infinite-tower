--!strict
-- StarterPlayerScripts/UI/Hud/ShopPanel.luau
-- Robux Store (Phase 5), drawn in Gilded Grimoire. Offers come from ShopConfig:
--   * Featured LIMITED pack: the limited banner's top heroes (top tier shown largest, with Squad
--     Power), and Buy 1 / Buy 5 / Buy 10 summon offers (10 shows its struck-through price).
--   * Gem and Gold rows: drawn currency art, amount, bonus tag and a Robux price button.
-- Prices are read live from MarketplaceService; offers with ProductId 0 show COMING SOON. Summon
-- packs are hidden for players who may not buy paid random items. Purchases are granted by the
-- server (ShopService); the result arrives as a toast and a profile sync.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShopConfig = require(Shared:WaitForChild("Config"):WaitForChild("ShopConfig"))
local HeroCatalog = require(Shared:WaitForChild("Config"):WaitForChild("HeroCatalog"))
local StatFormulas = require(Shared:WaitForChild("Util"):WaitForChild("StatFormulas"))
local Grimoire = require(Shared:WaitForChild("Util"):WaitForChild("GildedGrimoire"))
local Portrait = require(script.Parent:WaitForChild("Portrait"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local Components = require(script.Parent:WaitForChild("Components"))

local e = React.createElement
local Panel = Components.Panel
local Heavy = Components.HeavyLabel
local Body = Components.Body
local IconAt = Components.IconAt
local Tones = Grimoire.Tones
local TEXT = Grimoire.Text
local INK = Grimoire.Ink
local LocalPlayer = Players.LocalPlayer
local CLOSE_ACTION = "RobuxShopClose"

-- Live Robux prices, fetched once per product.
local priceCache: { [number]: number } = {}
local function livePrice(offer: ShopConfig.Offer): number
	if offer.ProductId == 0 then return offer.RobuxPrice end
	local cached = priceCache[offer.ProductId]
	if cached then return cached end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(offer.ProductId, Enum.InfoType.Product)
	end)
	local price = if ok and info and (info :: any).PriceInRobux then (info :: any).PriceInRobux else offer.RobuxPrice
	priceCache[offer.ProductId] = price
	return price
end

local function inkNumber(props: { [string]: any })
	local base: { [string]: any } = { BackgroundTransparency = 1, FontFace = Grimoire.Fonts.Number, TextColor3 = Color3.new(1, 1, 1), TextScaled = true }
	local max = props.MaxSize or 24
	for k, v in props do if k ~= "MaxSize" then base[k] = v end end
	return e("TextLabel", base, {
		Limit = e("UITextSizeConstraint", { MaxTextSize = max }),
		Ink = e("UIStroke", { Color = INK, Thickness = 2.4, LineJoinMode = Enum.LineJoinMode.Round }),
	})
end

-- The Robux price button: drawn Robux mark + price; disabled (COMING SOON) until a ProductId is set.
local function PriceButton(props: { Offer: ShopConfig.Offer, Tone: string?, Size: UDim2, Position: UDim2?, AnchorPoint: Vector2?, LayoutOrder: number?, OnBuy: (ShopConfig.Offer) -> () })
	local offer = props.Offer
	local live = offer.ProductId ~= 0
	local price, setPrice = React.useState(offer.RobuxPrice)
	local scaleRef = React.useRef(nil)
	React.useEffect(function()
		if not live then return end
		task.spawn(function() setPrice(livePrice(offer)) end)
	end, { offer.ProductId })
	local t = Tones[if live then (props.Tone or "Gold") else "Slate"]
	return Panel({
		Class = "TextButton", Text = "", AutoButtonColor = false, Selectable = true,
		Size = props.Size, Position = props.Position, AnchorPoint = props.AnchorPoint, LayoutOrder = props.LayoutOrder,
		Radius = 12, Top = t.Top, Bottom = t.Bottom, Rail = t.Rail, ZIndex = 6,
		[React.Event.Activated] = function() props.OnBuy(offer) end,
		[React.Event.MouseEnter] = function()
			if scaleRef.current then TweenService:Create(scaleRef.current, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1.06 }):Play() end
		end,
		[React.Event.MouseLeave] = function()
			if scaleRef.current then TweenService:Create(scaleRef.current, TweenInfo.new(0.12), { Scale = 1 }):Play() end
		end,
	}, {
		Scale = e("UIScale", { ref = scaleRef }),
		Row = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 7 }, {
			Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
			Mark = if live then IconAt("Robux", 26, { LayoutOrder = 1, ZIndex = 8 }) else nil,
			Price = if live then inkNumber({ LayoutOrder = 2, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 30), TextScaled = false, TextSize = 24,
				Text = tostring(price), ZIndex = 8 })
				else Heavy({ LayoutOrder = 2, Size = UDim2.new(1, -12, 0, 24), MaxSize = 15, Outline = 2, Gold = false, Text = "COMING SOON", ZIndex = 8 }),
		}),
	})
end

-- A featured hero tile: portrait in a rarity frame, name above, Squad Power below.
local function heroTile(order: number, heroId: string, big: boolean)
	local seed = HeroCatalog.Seeds[heroId]
	if not seed then return nil end
	local rarity = Theme.RarityColor(seed.Rarity)
	local probe = { TemplateId = seed.HeroId, Stars = seed.BaseStar, Level = 1, QualityScalar = 1, Archetype = seed.Archetype }
	local power = StatFormulas.GetHeroPower(probe)
	return e("Frame", { LayoutOrder = order, Size = if big then UDim2.fromOffset(196, 236) else UDim2.fromOffset(142, 196), BackgroundTransparency = 1 }, {
		Name = Heavy({ Size = UDim2.new(1, 0, 0, if big then 26 else 22), MaxSize = if big then 20 else 16, Outline = 2.2, Gold = big,
			TextColor3 = if big then Color3.new(1, 1, 1) else Color3.fromRGB(255, 190, 170), Text = seed.DisplayName, ZIndex = 6 }),
		Frame = Panel({ Position = UDim2.fromOffset(0, if big then 30 else 26), Size = UDim2.new(1, 0, 1, if big then -30 else -26), Radius = 14,
			Top = Tones.Deep.Top:Lerp(rarity, if big then 0.55 else 0.35), Bottom = Tones.Crimson.Bottom, Rail = rarity, ZIndex = 5 }, {
			Art = e("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 1, -48), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 6 }, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
				Portrait = e(Portrait, { TemplateId = seed.HeroId, Archetype = seed.Archetype, Stars = seed.BaseStar, Size = UDim2.fromScale(1, 1) }),
			}),
			Rarity = Body({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.new(1, -12, 0, 16), TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = rarity, Text = string.format("%s · %d★", HeroCatalog.RarityName(seed.Rarity), seed.BaseStar), ZIndex = 7 }),
			Power = inkNumber({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, -12, 0, 22), MaxSize = if big then 22 else 18,
				TextColor3 = TEXT.Good, Text = Components.Abbreviate(power) .. " PWR", ZIndex = 7 }),
		}),
	})
end

-- A Gem / Gold card.
local function currencyCard(order: number, offer: ShopConfig.Offer, icon: string, tone: string, onBuy: (ShopConfig.Offer) -> ())
	local t = Tones[tone]
	return Panel({ LayoutOrder = order, Size = UDim2.fromOffset(196, 236), Radius = 14, Top = t.Top, Bottom = Tones.Deep.Bottom, Rail = t.Rail }, {
		Tag = if offer.Tag then Panel({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 8, 0, -10), Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X,
			Radius = 13, Top = Tones.Crimson.Top:Lerp(Color3.fromRGB(255, 80, 80), 0.4), Bottom = Tones.Crimson.Bottom, Rail = Tones.Crimson.Rail, ZIndex = 8 }, {
			Pad = e("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
			Text = Heavy({ AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 26), TextScaled = false, TextSize = 13, Outline = 2, Gold = false, Text = offer.Tag, ZIndex = 9 }),
		}) else nil,
		Art = IconAt(icon, 86, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 16), ZIndex = 4 }),
		Amount = inkNumber({ Position = UDim2.fromOffset(8, 108), Size = UDim2.new(1, -16, 0, 34), MaxSize = 30, TextColor3 = if offer.Grant.Kind == "Gems" then Color3.fromRGB(170, 250, 255) else TEXT.Gold,
			Text = Components.Abbreviate(offer.Grant.Amount), ZIndex = 4 }),
		Label = Body({ Position = UDim2.fromOffset(8, 144), Size = UDim2.new(1, -16, 0, 18), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, Text = offer.Label, ZIndex = 4 }),
		Buy = e(PriceButton, { Offer = offer, Tone = "Gold", Position = UDim2.fromOffset(12, 176), Size = UDim2.new(1, -24, 0, 46), OnBuy = onBuy }),
	})
end

local function sectionHeader(order: number, icon: string, title: string, subtitle: string)
	return e("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 }, {
		Icon = IconAt(icon, 40, { Position = UDim2.fromOffset(0, 2), ZIndex = 4 }),
		Title = Heavy({ Position = UDim2.fromOffset(50, 0), Size = UDim2.new(1, -50, 0, 26), MaxSize = 22, TextXAlignment = Enum.TextXAlignment.Left, Text = title, ZIndex = 4 }),
		Sub = Body({ Position = UDim2.fromOffset(50, 26), Size = UDim2.new(1, -50, 0, 16), TextSize = 13, TextColor3 = TEXT.Muted, Text = subtitle, ZIndex = 4 }),
	})
end

local function ShopPanel(props: { Profile: any, Width: number, OnClose: () -> () })
	local restricted, setRestricted = React.useState(true) -- hide summon packs until the policy says otherwise
	local status, setStatus = React.useState("")

	React.useEffect(function()
		ContextActionService:BindAction(CLOSE_ACTION, function(_, state)
			if state == Enum.UserInputState.Begin then props.OnClose() end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.ButtonB)
		task.spawn(function()
			local ok, info = pcall(function() return PolicyService:GetPolicyInfoForPlayerAsync(LocalPlayer) end)
			setRestricted(not ok or (info :: any).ArePaidRandomItemsRestricted == true)
		end)
		local conn = MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, _productId, purchased)
			if userId == LocalPlayer.UserId then
				setStatus(if purchased then "Thank you! Your purchase is on its way." else "Purchase cancelled.")
			end
		end)
		return function()
			ContextActionService:UnbindAction(CLOSE_ACTION)
			conn:Disconnect()
		end
	end, {})

	local function buy(offer: ShopConfig.Offer)
		if offer.ProductId == 0 then
			setStatus(offer.Label .. " isn't on sale yet.")
			return
		end
		setStatus("Opening Roblox checkout…")
		MarketplaceService:PromptProductPurchase(LocalPlayer, offer.ProductId)
	end

	local narrow = props.Width < 820
	local featured = ShopConfig.Featured
	local banner = HeroCatalog.LimitedBanner
	local rows: { [string]: any } = {
		Layout = e("UIListLayout", { Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }),
		Pad = e("UIPadding", { PaddingTop = UDim.new(0, 16), PaddingBottom = UDim.new(0, 20), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 14) }),
	}

	-- Featured LIMITED pack ----------------------------------------------------------------------
	if not restricted then
		local tiles: { [string]: any } = {
			Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Bottom,
				HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
		}
		local tiers = featured.ShowcaseTiers
		-- Smaller heroes first, the top tier last and largest (like a reveal).
		for i = #tiers, 1, -1 do
			local id = banner.HeroesByStar[tiers[i]]
			if id then tiles["T" .. i] = heroTile(#tiers - i + 1, id, i == 1) end
		end
		local buys: { [string]: any } = {
			Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }),
		}
		for i, offer in featured.Offers do
			buys["O" .. i] = e("Frame", { LayoutOrder = i, Size = UDim2.fromOffset(196, 84), BackgroundTransparency = 1 }, {
				Was = if offer.WasPrice then Body({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, -20), Size = UDim2.fromOffset(110, 18), TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(255, 140, 140), Text = string.format("<s>%d</s> %s", offer.WasPrice, offer.Tag or ""), ZIndex = 7 }) else nil,
				Button = e(PriceButton, { Offer = offer, Tone = if offer.WasPrice then "Gold" else "Crimson", Size = UDim2.new(1, 0, 0, 52), OnBuy = buy }),
				Label = Heavy({ Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 22), MaxSize = 16, Outline = 2, Gold = false,
					Text = string.format("%s · %d summon%s", offer.Label, offer.Grant.Amount, if offer.Grant.Amount == 1 then "" else "s"), ZIndex = 7 }),
			})
		end
		rows.Featured = Panel({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 470), Radius = 16,
			Top = Tones.Crimson.Top:Lerp(Color3.fromRGB(180, 40, 50), 0.35), Bottom = Tones.Crimson.Bottom, Rail = TEXT.Gold }, {
			Crest = IconAt("Spark", 54, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 10), ZIndex = 6 }),
			Title = Heavy({ Position = UDim2.fromOffset(22, 14), Size = UDim2.new(1, -220, 0, 46), MaxSize = 42, TextXAlignment = Enum.TextXAlignment.Left,
				Text = featured.Title, ZIndex = 6 }),
			Limited = Panel({ Position = UDim2.fromOffset(24, 62), Size = UDim2.fromOffset(104, 26), Radius = 13, Top = Color3.new(1, 1, 1), Bottom = Color3.fromRGB(220, 220, 230),
				Rail = INK, ZIndex = 6 }, {
				Text = Heavy({ Size = UDim2.fromScale(1, 1), MaxSize = 14, Outline = 0, Gold = false, TextColor3 = Color3.fromRGB(150, 20, 30), Text = "LIMITED", ZIndex = 8 }),
			}),
			Sub = Body({ Position = UDim2.fromOffset(140, 66), Size = UDim2.new(1, -160, 0, 18), TextSize = 14, TextColor3 = Color3.fromRGB(255, 220, 210), Text = featured.Subtitle, ZIndex = 6 }),
			Tiles = e("Frame", { Position = UDim2.fromOffset(16, 94), Size = UDim2.new(1, -32, 0, 240), BackgroundTransparency = 1, ZIndex = 5 }, tiles),
			Buys = e("Frame", { Position = UDim2.fromOffset(16, 360), Size = UDim2.new(1, -32, 0, 84), BackgroundTransparency = 1, ZIndex = 5 }, buys),
		})
	end

	-- Gems ------------------------------------------------------------------------------------------
	local function cardRow(order: number, list: { ShopConfig.Offer }, icon: string, tone: string)
		local kids: { [string]: any } = {
			Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder, Wraps = true }),
		}
		for i, offer in list do
			kids["C" .. i] = currencyCard(i, offer, icon, tone, buy)
		end
		return e("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, kids)
	end
	rows.GemsHeader = sectionHeader(2, "Gems", "GEMS", "Summon heroes and artifacts")
	rows.Gems = cardRow(3, ShopConfig.Gems, "Gems", "Teal")
	rows.GoldHeader = sectionHeader(4, "Gold", "GOLD", "Build the Fortress Tree and promote heroes")
	rows.Gold = cardRow(5, ShopConfig.Gold, "Gold", "Bronze")

	local profile = props.Profile
	local gems = profile and profile.Currencies and profile.Currencies.Gems or 0
	local gold = profile and profile.Currencies and profile.Currencies.Gold or 0

	return e("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(6, 5, 10), BackgroundTransparency = 0.35, Text = "", AutoButtonColor = false, ZIndex = 20,
		[React.Event.Activated] = function() props.OnClose() end,
	}, {
		Window = Panel({
			Class = "TextButton", Text = "", AutoButtonColor = false, -- swallows clicks so they don't reach the scrim
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.94, 0, 0.9, 0), Radius = 16, ZIndex = 21,
		}, {
			Max = e("UISizeConstraint", { MaxSize = Vector2.new(1040, 760) }),
			Icon = IconAt("Shop", 66, { Position = UDim2.fromOffset(16, -14), ZIndex = 26 }),
			Title = Heavy({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(300, 48), MaxSize = 44, Text = "STORE", ZIndex = 25 }),
			Wallet = e("Frame", { Position = UDim2.fromOffset(92, 18), Size = UDim2.fromOffset(260, 32), BackgroundTransparency = 1, ZIndex = 25, Visible = not narrow }, {
				Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
				GemIcon = IconAt("Gems", 26, { LayoutOrder = 1, ZIndex = 26 }),
				Gems = inkNumber({ LayoutOrder = 2, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 26), TextScaled = false, TextSize = 18,
					TextColor3 = Color3.fromRGB(170, 250, 255), Text = Components.Abbreviate(gems) .. "  ", ZIndex = 26 }),
				GoldIcon = IconAt("Gold", 26, { LayoutOrder = 3, ZIndex = 26 }),
				Gold = inkNumber({ LayoutOrder = 4, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 26), TextScaled = false, TextSize = 18,
					TextColor3 = TEXT.Gold, Text = Components.Abbreviate(gold), ZIndex = 26 }),
			}),
			Close = Panel({
				Class = "TextButton", Text = "", AutoButtonColor = false, Selectable = true, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 14),
				Size = UDim2.fromOffset(48, 44), Radius = 10, Top = Tones.Crimson.Top, Bottom = Tones.Crimson.Bottom, Rail = Tones.Crimson.Rail, ZIndex = 25,
				[React.Event.Activated] = function() props.OnClose() end,
			}, {
				X = IconAt("Close", 20, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 27 }),
			}),
			Scroll = e("ScrollingFrame", {
				Position = UDim2.fromOffset(16, 70), Size = UDim2.new(1, -32, 1, -112), BackgroundTransparency = 1, BorderSizePixel = 0,
				ScrollBarThickness = 6, ScrollBarImageColor3 = Color3.fromRGB(240, 196, 110), AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 22,
			}, rows),
			Status = Body({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(1, -40, 0, 20), TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = TEXT.Muted, Text = status, ZIndex = 25 }),
		}),
	})
end

return ShopPanel
