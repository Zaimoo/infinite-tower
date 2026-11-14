--!strict
-- StarterPlayerScripts/UI/FacilityController.luau
-- Authoritative Facility HUD featuring:
--   1. HERO BANNER & ARTIFACT BANNER SUMMONING (Call of the Rift & Echoes of the Rift)
--   2. Banner cards with the featured hero, a per-tier roster with drop rates, pity bar, 1X & 10X summons
--   3. Per-pull animated reveal (SummonReveal.luau)
--   4. Support facility panels (Guard Post, Market, Training Grounds, God's Blessing) & Squad Management
-- Matches the exact cosmic purple aesthetic with corner diamond accents, glowing borders, and responsive scaling.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FacilityConfig = require(Shared:WaitForChild("Config"):WaitForChild("FacilityConfig"))
local HeroCatalog = require(Shared:WaitForChild("Config"):WaitForChild("HeroCatalog"))
local ArtifactCatalog = require(Shared:WaitForChild("Config"):WaitForChild("ArtifactCatalog"))
local StatFormulas = require(Shared:WaitForChild("Util"):WaitForChild("StatFormulas"))
local FortressTree = require(Shared:WaitForChild("Util"):WaitForChild("FortressTree"))
local InventoryCapacity = require(Shared:WaitForChild("Util"):WaitForChild("InventoryCapacity"))
local SummonLuck = require(Shared:WaitForChild("Util"):WaitForChild("SummonLuck"))
local GothicBoxStyle = require(Shared:WaitForChild("Util"):WaitForChild("GothicBoxStyle"))
local GrimoireIcons = require(Shared:WaitForChild("Util"):WaitForChild("GrimoireIcons"))
local GrimoireSummonButton = require(Shared:WaitForChild("Util"):WaitForChild("GrimoireSummonButton"))
local GildedGrimoire = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("GildedGrimoire"))
local HeroCard = require(script.Parent:WaitForChild("HeroCard"))
local ModalFit = require(script.Parent:WaitForChild("ModalFit"))
local Theme = require(script.Parent:WaitForChild("Hud"):WaitForChild("Theme"))
local SummonReveal = require(script.Parent:WaitForChild("SummonReveal"))
local HeroOddsModal = require(script.Parent:WaitForChild("HeroOddsModal"))
local HeroBannerFx = require(script.Parent:WaitForChild("HeroBannerFx"))
local UIAssets = require(script.Parent:WaitForChild("UIAssets"))
local UIFeel = require(script.Parent:WaitForChild("UIFeel"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local StatBalance = require(Shared:WaitForChild("Config"):WaitForChild("StatBalance"))

local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local ArtifactRemotes = RemotesFolder:FindFirstChild("ArtifactRemotes") :: Folder?

local Controller = {}
Controller.__index = Controller

local WIDTH, HEIGHT = 760, 520

local C = {
	Scrim = Color3.fromRGB(6, 5, 10),
	Panel = Color3.fromRGB(15, 13, 22),
	PanelInner = Color3.fromRGB(20, 17, 30),
	CardBg = Color3.fromRGB(24, 21, 40),
	SlotBg = Color3.fromRGB(18, 15, 26),
	StatBoxBg = Color3.fromRGB(12, 10, 18),
	Border = Color3.fromRGB(192, 132, 252),
	BorderGlow = Color3.fromRGB(175, 115, 215),
	BorderDim = Color3.fromRGB(58, 48, 75),
	BorderCard = Color3.fromRGB(59, 45, 84),
	Text = Color3.fromRGB(255, 255, 255),
	TextMuted = Color3.fromRGB(155, 145, 175),
	TextLavender = Color3.fromRGB(180, 175, 205),
	GoldYellow = Color3.fromRGB(250, 204, 21),
	Green = Color3.fromRGB(74, 222, 128),
	Red = Color3.fromRGB(239, 68, 68),
	Arrow = Color3.fromRGB(140, 130, 160),
	Underline = Color3.fromRGB(225, 150, 245),
}

local DETAILS = {
	Summoning = { Title = "SUMMONING", Description = "Call legendary heroes through the dimensional rift.", Color = Color3.fromRGB(192, 132, 252) },
	SquadManagement = { Title = "SQUAD MANAGEMENT", Description = "Deploy rested heroes and bench your current squad.", Color = Color3.fromRGB(245, 128, 99) },
	GuardPost = { Title = "OUTSKIRTS GUARD POST", Description = "Station Adventurers along the southern trail to defend the outskirts and generate passive Gold online & offline.", Color = Color3.fromRGB(130, 205, 95) },
	Market = { Title = "THE MARKET", Description = "Station Merchants to multiply Infinite Tower mob/boss loot drops and cargo extraction banking.", Color = Color3.fromRGB(245, 195, 75) },
	TrainingGrounds = { Title = "TRAINING GROUNDS", Description = "Station Trainers to run martial combat drills, multiplying overall squad Final ATK and Final HP.", Color = Color3.fromRGB(235, 80, 80) },
	GodsBlessing = { Title = "GOD'S BLESSING", Description = "Station Acolytes (Healers preferred) at the angel fountain to raise your summon luck on every banner.", Color = Color3.fromRGB(255, 226, 150) },
}

-- Facility panels have no upgrade button: support facilities are levelled only in the Fortress Tree.

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local o = Instance.new(className)
	for k, v in pairs(props) do
		(o :: any)[k] = v
	end
	o.Parent = parent
	return o
end

local function stroke(parent: Instance, color: Color3, thickness: number?, transparency: number?): UIStroke
	return new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
	}, parent)
end

local function glow(parent: GuiObject, pad: number, color: Color3?, transparency: number?)
	local g = new("Frame", {
		Name = "Glow",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, pad, 1, pad),
		ZIndex = parent.ZIndex,
	}, parent)
	stroke(g, color or C.BorderGlow, 3, transparency or 0.8)
end

local function applyGothicStyle(container: GuiObject, style: "Window" | "Card" | "Button" | "Compact")
	return GothicBoxStyle.Apply(container, { Style = style })
end

local function cornerDiamonds(parent: GuiObject, size: number, color: Color3?)
	-- Styled automatically by GothicBoxStyle
end

local function label(parent: Instance, text: string, size: number, color: Color3, font: Enum.Font?): TextLabel
	local lbl = new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		TextColor3 = color,
		Font = font or GothicBoxStyle.Font.LegacyFont or Enum.Font.GothamBold,
		Size = UDim2.new(1, 0, 0, size + 8),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		RichText = true,
	}, parent)
	GothicBoxStyle.Font.Apply(lbl, {
		Role = if size >= 20 then "Title" else if size >= 15 then "Header" else "Body",
		Color = color,
		Size = size,
	})
	return lbl
end

--============================================================================
-- CONSTRUCTOR
--============================================================================

function Controller.new(gui: ScreenGui, getProfile: () -> any, remotes: Instance)
	local self: any = setmetatable({}, Controller)
	self.GetProfile = getProfile
	self.Busy = false
	self.LastSummoned = {}
	self.Current = "Summoning"
	self.ActiveSummonTab = "CALL_OF_THE_RIFT" -- "CALL_OF_THE_RIFT" | "A_STARS_ARRIVAL"

	-- Remotes
	self.Summon = remotes:WaitForChild("RequestSummon") :: RemoteFunction
	self.Assign = remotes:WaitForChild("AssignHeroRole") :: RemoteFunction
	self.Facility = remotes:WaitForChild("FacilityInteract") :: RemoteEvent

	if ArtifactRemotes then
		self.RequestSummonArtifact = ArtifactRemotes:FindFirstChild("RequestSummonArtifact") :: RemoteFunction?
	end

	-- 1. Scrim Background (dims world)
	self.Scrim = new("TextButton", {
		Name = "FacilityScrim",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.Scrim,
		BackgroundTransparency = 1, -- no dim behind the window; still catches outside clicks
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 50,
	}, gui)
	self.Scrim.Activated:Connect(function()
		if not self.Busy and (os.clock() - (self.OpenTime or 0) >= 0.25) then
			self:Close()
		end
	end)

	-- 2. Modal Frame (Ornate Gothic Box Container)
	local root = new("Frame", {
		Name = "FacilityModal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 51,
	}, gui)
	self.Root = root
	-- Gilded Grimoire theme: convert this screen's legacy Gotham text (now and as it is rebuilt).
	GildedGrimoire.Watch(root)

	applyGothicStyle(root, "Window")
	self.Stroke = GildedGrimoire.StateStroke(root)

	self.Scale = new("UIScale", {}, root)

	-- 3. Close Button (High contrast gothic rounded square with Latin 'X')
	local closeBtn = GothicBoxStyle.CreateCloseButton(root, function()
		if not self.Busy then
			self:Close()
		end
	end)

	-- 4. Currency / Gems Indicator in Top Bar
	-- Gems counter: a drawn Gilded Grimoire gem beside the amount.
	local gemRow, gemCurrency = GrimoireIcons.IconText("Gems", 24, root, 53)
	gemRow.Name = "GemCurrency"
	gemRow.AnchorPoint = Vector2.new(1, 0)
	gemRow.Position = UDim2.new(1, -60, 0, 18)
	gemCurrency.Text = "0 Gems"
	gemCurrency.TextSize = 17
	gemCurrency.TextColor3 = C.GoldYellow
	GildedGrimoire.StyleText(gemCurrency, "Number")
	gemCurrency:SetAttribute("Grimoire", true)
	self.GemCurrencyRow = gemRow
	self.GemCurrency = gemCurrency

	-- 5. Top Tab Container (CALL OF THE RIFT | A STAR'S ARRIVAL)
	local tabContainer = new("Frame", {
		Name = "TabContainer",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(24, 14),
		Size = UDim2.new(1, -260, 0, 44),
		ZIndex = 52,
	}, root)
	self.TabContainer = tabContainer

	local callTabBtn = new("TextButton", {
		Name = "TabCallOfTheRift",
		Text = "CALL OF THE RIFT",
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		TextColor3 = C.Text,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(165, 36),
		Position = UDim2.fromOffset(10, 0),
		ZIndex = 53,
	}, tabContainer)
	callTabBtn:SetAttribute("FeelSound", "TabSwitch")

	local starTabBtn = new("TextButton", {
		Name = "TabAStarsArrival",
		Text = "A STAR'S ARRIVAL",
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		TextColor3 = C.TextMuted,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(165, 36),
		Position = UDim2.fromOffset(185, 0),
		ZIndex = 53,
	}, tabContainer)
	starTabBtn:SetAttribute("FeelSound", "TabSwitch")

	local activeIndicator = new("Frame", {
		Name = "ActiveTabIndicator",
		BackgroundColor3 = C.Underline,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 130, 0, 3),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(92, 36),
		ZIndex = 54,
	}, tabContainer)
	stroke(activeIndicator, C.BorderGlow, 1.5, 0.4)

	self.CallTabBtn = callTabBtn
	self.StarTabBtn = starTabBtn
	self.ActiveIndicator = activeIndicator

	callTabBtn.Activated:Connect(function()
		self:SetSummonTab("CALL_OF_THE_RIFT")
	end)
	starTabBtn.Activated:Connect(function()
		self:SetSummonTab("A_STARS_ARRIVAL")
	end)

	-- Header Title (Fallback for non-summon facilities like the Guard Post / Squad)
	local headerTitle = label(root, "SUMMONING", 20, C.Text, Enum.Font.GothamBold)
	headerTitle.Name = "FacilityHeaderTitle"
	headerTitle.Position = UDim2.fromOffset(24, 18)
	headerTitle.Size = UDim2.new(1, -260, 0, 26)
	headerTitle.TextXAlignment = Enum.TextXAlignment.Left
	headerTitle.Visible = false
	self.HeaderTitle = headerTitle

	-- Tab Divider line
	local tabDivider = new("Frame", {
		Name = "TabDivider",
		BackgroundColor3 = C.BorderDim,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 62),
		Size = UDim2.new(1, -32, 0, 1),
		ZIndex = 52,
	}, root)
	self.TabDivider = tabDivider

	-- 6. Summon Views (Permanent 5-Star Banner & Limited 7-Star Banner)
	self:BuildPermanentSummonView(root)
	self:BuildLimitedSummonView(root)

	-- 7. General Facility View (support facilities, SquadManagement fallback)
	self:BuildGeneralFacilityView(root)

	-- 8. Summon Reveal Modal
	self:BuildSummonRevealModal(gui)

	-- 9. "View Heroes & Odds" window (over the Altar window)
	self.HeroOdds = HeroOddsModal.new(gui, {
		CALL_OF_THE_RIFT = HeroCatalog.PermanentBanner,
		A_STARS_ARRIVAL = HeroCatalog.LimitedBanner,
	}, getProfile)

	-- Fit the window inside the safe area (below the top bar, clear of the bottom edge).
	ModalFit.Bind(root, self.Scale, WIDTH, HEIGHT, { MaxScale = 1.25 })

	root:GetPropertyChangedSignal("Visible"):Connect(function()
		if not root.Visible then
			self:SyncBannerFx(false)
		end
	end)

	return self
end

--============================================================================
-- SECTION 1: HERO BANNER VIEWS ("CALL OF THE RIFT" 1★–7★, "A STAR'S ARRIVAL" 1★–7★)
--============================================================================

-- Per-banner look. Both views share one builder; the featured portrait is built lazily the first
-- time a view is shown. The full roster and odds open in HeroOddsModal.
local BANNER_VIEWS = {
	CALL_OF_THE_RIFT = {
		Name = "PermanentSummonView", Prefix = "Perm", Banner = HeroCatalog.PermanentBanner,
		Tag = "PERMANENT HERO BANNER  ·  1★ – 7★", TitleColor = Color3.fromRGB(250, 204, 21), Stroke = Color3.fromRGB(120, 80, 0),
		Gradient = { Color3.fromRGB(28, 19, 50), Color3.fromRGB(20, 14, 36), Color3.fromRGB(12, 9, 22) },
	},
	A_STARS_ARRIVAL = {
		Name = "LimitedSummonView", Prefix = "Lim", Banner = HeroCatalog.LimitedBanner,
		Tag = "LIMITED RATE-UP EVENT  ·  1★ – 7★", TitleColor = Color3.fromRGB(255, 220, 100), Stroke = Color3.fromRGB(140, 85, 10),
		Gradient = { Color3.fromRGB(44, 25, 68), Color3.fromRGB(28, 16, 44), Color3.fromRGB(14, 10, 24) },
	},
}

-- Gem price of a 1x / 10x summon on a banner (the server charges the same values from HeroCatalog).
local function summonCost(bannerId: string, count: number): number
	local banner = (BANNER_VIEWS[bannerId] or BANNER_VIEWS.CALL_OF_THE_RIFT).Banner
	return if count == 10 then banner.Cost10X else banner.Cost1X
end

local function featuredOf(banner: any): (string, number)
	local top = banner.MaxStar
	return banner.FeaturedHeroId or banner.HeroesByStar[top], top
end

local function rateText(rate: number): string
	local pct = rate * 100
	return if pct >= 10 then string.format("%d%%", math.round(pct))
		elseif pct >= 1 then string.format("%.1f%%", pct)
		else (string.gsub(string.format("%.2f", pct), "0$", "")) .. "%"
end

local BANNER_VIEW_POS = UDim2.fromOffset(16, 72)

function Controller:BuildBannerView(root: Frame, key: string)
	local def = BANNER_VIEWS[key]
	local banner = def.Banner
	local featuredId, topTier = featuredOf(banner)
	local featuredSeed = HeroCatalog.Seeds[featuredId]
	local topColor = Theme.RarityColor(topTier)

	local view = new("Frame", {
		Name = def.Name,
		BackgroundTransparency = 1,
		Position = BANNER_VIEW_POS,
		Size = UDim2.new(1, -32, 1, -82),
		Visible = false,
		ZIndex = 52,
	}, root)

	-- 1. Banner card: title and roster on the left, the featured hero on the right.
	local card = new("Frame", {
		Name = def.Prefix .. "BannerCard",
		Size = UDim2.new(1, 0, 0, 240),
		BackgroundColor3 = def.Gradient[2],
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 53,
	}, view)
	applyGothicStyle(card, "Card")
	local oldGrad = card:FindFirstChild("GothicObsidianGrad")
	if oldGrad then oldGrad:Destroy() end
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, def.Gradient[1]),
			ColorSequenceKeypoint.new(0.5, def.Gradient[2]),
			ColorSequenceKeypoint.new(1.0, def.Gradient[3]),
		}),
		Rotation = 35,
	}, card)

	-- Featured hero: a rarity-coloured halo behind a large portrait, with a name plate.
	local halo = new("Frame", {
		Name = "FeaturedHalo", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -118, 0, 112),
		Size = UDim2.fromOffset(250, 250), BackgroundColor3 = topColor, BackgroundTransparency = 0.82, BorderSizePixel = 0, ZIndex = 54,
	}, card)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, halo)
	new("UIGradient", { Transparency = NumberSequence.new(0, 0.6), Rotation = 90 }, halo)
	local featuredHost = new("Frame", {
		Name = "FeaturedPortrait", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 10),
		Size = UDim2.fromOffset(200, 196), BackgroundTransparency = 1, ZIndex = 55,
	}, card)
	local plate = new("Frame", {
		Name = "FeaturedPlate", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(1, -118, 1, -10),
		Size = UDim2.fromOffset(196, 28), BackgroundColor3 = Color3.fromRGB(14, 10, 22), BorderSizePixel = 0, ZIndex = 57,
	}, card)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, plate)
	stroke(plate, topColor, 1.6)
	local plateLabel = label(plate, string.format("%s  ·  %s %d★", featuredSeed and featuredSeed.DisplayName or "Featured",
		HeroCatalog.RarityName(topTier), topTier), 13, topColor, Enum.Font.GothamBold)
	plateLabel.Size = UDim2.fromScale(1, 1)
	plateLabel.ZIndex = 58

	local tag = label(card, def.Tag, 13, Color3.fromRGB(230, 220, 255), Enum.Font.GothamBold)
	tag.TextTransparency = 0.35
	tag.Position = UDim2.fromOffset(22, 16)
	tag.Size = UDim2.new(1, -270, 0, 18)
	tag.TextXAlignment = Enum.TextXAlignment.Left
	tag.ZIndex = 56

	local title = label(card, banner.Title, 36, def.TitleColor, Enum.Font.GothamBlack)
	title.Position = UDim2.fromOffset(22, 40)
	title.Size = UDim2.new(1, -270, 0, 44)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextStrokeTransparency = 0.35
	title.TextStrokeColor3 = def.Stroke
	title.ZIndex = 56

	local blurb = label(card, string.format("Featured: <b>%s</b>, %s %d★. See every hero and their odds.",
		featuredSeed and featuredSeed.DisplayName or "Hero", HeroCatalog.RarityName(topTier), topTier), 13, C.TextLavender, Enum.Font.GothamMedium)
	blurb.Position = UDim2.fromOffset(22, 88)
	blurb.Size = UDim2.new(1, -270, 0, 18)
	blurb.TextXAlignment = Enum.TextXAlignment.Left
	blurb.ZIndex = 56

	-- Top-tier odds teaser and the "View Heroes & Odds" button (the full roster and odds live in
	-- HeroOddsModal, like the Forge's "View all weapons & odds").
	local teaser = label(card, string.format("%s <b>%s %s</b>  ·  %s+ guaranteed by pull %d",
		if banner.FeaturedHeroId then "Featured" else "Top tier", HeroCatalog.RarityName(topTier), rateText(banner.Rates[topTier] or 0),
		HeroCatalog.RarityName(banner.PityMinTier or 5), banner.MaxPity), 13, C.TextMuted, Enum.Font.GothamMedium)
	teaser.Position = UDim2.fromOffset(22, 112)
	teaser.Size = UDim2.new(1, -270, 0, 18)
	teaser.TextXAlignment = Enum.TextXAlignment.Left
	teaser.ZIndex = 56

	local viewHeroesBtn = new("TextButton", {
		Name = def.Prefix .. "ViewHeroesBtn",
		Position = UDim2.fromOffset(22, 146),
		Size = UDim2.fromOffset(230, 38),
		Text = "VIEW HEROES & ODDS",
		Font = Enum.Font.GothamBlack,
		TextSize = 13,
		TextColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 58,
	}, card)
	GothicBoxStyle.Apply(viewHeroesBtn, { Style = "ButtonSecondary" })
	viewHeroesBtn.FontFace = GildedGrimoire.Fonts.Title
	viewHeroesBtn.TextStrokeColor3 = GildedGrimoire.Ink
	viewHeroesBtn.TextStrokeTransparency = 0.3
	viewHeroesBtn:SetAttribute("Grimoire", true)
	viewHeroesBtn.Activated:Connect(function()
		if self.HeroOdds then self.HeroOdds:Open(key) end
	end)

	-- 2. Pity row: text and a progress bar on the left, the Blessing badge and 10x rule on the right.
	local pityLabel = label(view, "", 14, C.TextLavender, Enum.Font.GothamMedium)
	pityLabel.Position = UDim2.fromOffset(6, 250)
	pityLabel.Size = UDim2.new(0.58, 0, 0, 20)
	pityLabel.TextXAlignment = Enum.TextXAlignment.Left
	local pityTrack, pityFill = GildedGrimoire.Bar(view, topColor)
	pityTrack.Position = UDim2.fromOffset(6, 276)
	pityTrack.Size = UDim2.new(0.58, 0, 0, 12)
	pityTrack.ZIndex = 53
	pityFill.ZIndex = 54
	pityFill.Size = UDim2.fromScale(0, 1)

	local infoLabel = label(view, "", 14, C.TextLavender, Enum.Font.GothamMedium)
	infoLabel.AnchorPoint = Vector2.new(1, 0)
	infoLabel.Position = UDim2.new(1, -6, 0, 250)
	infoLabel.Size = UDim2.new(0.4, 0, 0, 20)
	infoLabel.TextXAlignment = Enum.TextXAlignment.Right
	local guarantee = label(view, string.format("10x guarantees a %s or better hero", HeroCatalog.RarityName(banner.TenPullMinTier)), 12, C.TextMuted, Enum.Font.GothamMedium)
	guarantee.AnchorPoint = Vector2.new(1, 0)
	guarantee.Position = UDim2.new(1, -6, 0, 272)
	guarantee.Size = UDim2.new(0.4, 0, 0, 18)
	guarantee.TextXAlignment = Enum.TextXAlignment.Right

	-- 3. Status line (refusals, busy) and the two summon buttons (100 / 900 Gems).
	local status = label(view, "", 13, C.TextMuted, Enum.Font.GothamMedium)
	status.Position = UDim2.fromOffset(6, 296)
	status.Size = UDim2.new(1, -12, 0, 20)

	local btnRow = new("Frame", {
		Name = def.Prefix .. "ButtonRow",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 322),
		Size = UDim2.new(1, 0, 0, 84),
		ZIndex = 53,
	}, view)
	local buttons = {}
	for i, count in { 1, 10 } do
		local b = GrimoireSummonButton.new(btnRow, {
			Name = string.format("%sSummon%dXBtn", def.Prefix, count),
			Title = string.format("SUMMON %dX", count),
			Cost = summonCost(key, count),
			AnchorPoint = Vector2.new(i - 1, 0),
			Position = UDim2.fromScale(i - 1, 0),
			Size = UDim2.new(0.485, 0, 1, 0),
			ZIndex = 54,
			OnClick = function()
				self:PerformSummon(key, count)
			end,
		})
		-- Hover/press spring, click sound and haptic come from UIFeel.
		buttons[count] = b
	end

	local fx = HeroBannerFx.Attach({
		Key = key :: HeroBannerFx.BannerKey,
		Card = card,
		Halo = halo,
		PortraitHost = featuredHost,
		Plate = plate,
		TitleLabel = title,
		TagLabel = tag,
		PityFill = pityFill,
		Button10X = buttons[10].Root,
		AccentColor = topColor,
		KeyArtId = if key == "CALL_OF_THE_RIFT" then UIAssets.Images.BannerCallOfTheRift else UIAssets.Images.BannerStarsArrival,
		IsVisible = function()
			return self.Root ~= nil and self.Root.Visible and self.Current == "Summoning" and view.Visible
		end,
	})

	self.BannerViews = self.BannerViews or {}
	self.BannerViews[key] = {
		View = view, Pity = pityLabel, PityFill = pityFill, Info = infoLabel, Status = status, Buttons = buttons,
		FeaturedHost = featuredHost, FeaturedId = featuredId, TopTier = topTier, PortraitBuilt = false, ViewHeroes = viewHeroesBtn,
		Fx = fx,
	}
	return view
end

-- Syncs banner VFX state so only the currently displayed banner animates.
function Controller:SyncBannerFx(playEntrance: boolean?)
	if not self.BannerViews then return end
	local open = self.Root ~= nil and self.Root.Visible and self.Current == "Summoning"
	for key, bv in self.BannerViews do
		local active = open and (self.ActiveSummonTab == key)
		if bv.Fx then
			bv.Fx:SetActive(active)
			if active and playEntrance then
				bv.Fx:PlayEntrance()
			end
		end
	end
end

-- Builds a view's featured-hero portrait the first time it is shown.
function Controller:EnsureBannerPortraits(key: string)
	local bv = self.BannerViews and self.BannerViews[key]
	if not bv or bv.PortraitBuilt then return end
	bv.PortraitBuilt = true
	local portrait = HeroCard.Portrait(bv.FeaturedHost, { TemplateId = bv.FeaturedId, Stars = bv.TopTier })
	if portrait then
		portrait.ZIndex = bv.FeaturedHost.ZIndex
	end
end

function Controller:BuildPermanentSummonView(root: Frame)
	self.PermanentSummonView = self:BuildBannerView(root, "CALL_OF_THE_RIFT")
	self.PermanentPityLabel = self.BannerViews.CALL_OF_THE_RIFT.Pity
	self.PermanentInfoLabel = self.BannerViews.CALL_OF_THE_RIFT.Info
end

function Controller:BuildLimitedSummonView(root: Frame)
	self.LimitedSummonView = self:BuildBannerView(root, "A_STARS_ARRIVAL")
	self.LimitedPityLabel = self.BannerViews.A_STARS_ARRIVAL.Pity
	self.LimitedInfoLabel = self.BannerViews.A_STARS_ARRIVAL.Info
end

--============================================================================
-- GENERAL FACILITY VIEW (support facilities, SquadManagement fallback)
--============================================================================

function Controller:BuildGeneralFacilityView(root: Frame)
	local generalView = new("Frame", {
		Name = "GeneralFacilityView",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 72),
		Size = UDim2.new(1, -32, 1, -82),
		Visible = false,
		ZIndex = 52,
	}, root)
	self.GeneralFacilityView = generalView

	self.Title = label(generalView, "FacilityTitle", 18, C.Text, Enum.Font.GothamBold)
	self.Title.Position = UDim2.fromOffset(12, 0)
	self.Title.Size = UDim2.new(1, -24, 0, 24)
	self.Title.TextXAlignment = Enum.TextXAlignment.Left

	self.Description = label(generalView, "Description", 13, C.TextMuted, Enum.Font.GothamMedium)
	self.Description.Position = UDim2.fromOffset(12, 26)
	self.Description.Size = UDim2.new(1, -24, 0, 20)
	self.Description.TextXAlignment = Enum.TextXAlignment.Left

	self.Summary = label(generalView, "Summary", 14, C.TextLavender, Enum.Font.GothamMedium)
	self.Summary.Position = UDim2.fromOffset(12, 50)
	self.Summary.Size = UDim2.new(1, -24, 0, 22)
	self.Summary.TextXAlignment = Enum.TextXAlignment.Left

	self.Actions = new("Frame", {
		Name = "FacilityActions",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 80),
		Size = UDim2.new(1, -24, 0, 44),
		ZIndex = 53,
	}, generalView)

	self.List = new("ScrollingFrame", {
		Name = "HeroList",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 136),
		Size = UDim2.new(1, -24, 1, -176),
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.Border,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 53,
	}, generalView)

	local layout = new("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, self.List)

	self.Status = label(generalView, "", 13, C.TextMuted, Enum.Font.GothamMedium)
	self.Status.Position = UDim2.new(0, 12, 1, -30)
	self.Status.Size = UDim2.new(1, -24, 0, 24)
	self.Status.TextXAlignment = Enum.TextXAlignment.Left
end

--============================================================================
-- SUMMON REVEAL (one animated beat per pull; see SummonReveal.luau)
--============================================================================

function Controller:BuildSummonRevealModal(gui: ScreenGui)
	self.Reveal = SummonReveal.new(gui)
end

-- `ownedBefore` is the set of hero templates owned before the pull (for the NEW badge).
function Controller:ShowSummonResults(summonedList: { any }, bannerId: string, ownedBefore: { [string]: boolean })
	local seen = table.clone(ownedBefore)
	self.Reveal:Play(summonedList, false, {
		BannerId = bannerId,
		IsNew = function(hero: any): boolean
			local id = hero.TemplateId
			if not id or seen[id] then return false end
			seen[id] = true -- two copies in one 10x: only the first is NEW
			return true
		end,
		Cost1 = summonCost(bannerId, 1),
		Cost10 = summonCost(bannerId, 10),
		Currency = "Gems",
		OnAgain = function(count: number)
			return self:PerformSummon(bannerId, count)
		end,
		OnContinue = function()
			self:Open("Summoning")
		end,
	})
end

local function ownedTemplates(profile: any): { [string]: boolean }
	local owned = {}
	for _, h in (profile and profile.Heroes) or {} do
		if h.TemplateId then owned[h.TemplateId] = true end
	end
	return owned
end

--============================================================================
-- ACTIONS & METHODS
--============================================================================

function Controller:Button(parent: Instance, name: string, text: string, size: UDim2, position: UDim2, action: () -> ()): TextButton
	local b = new("TextButton", {
		Name = name,
		Text = text,
		Size = size,
		Position = position,
		ZIndex = 54,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextWrapped = true,
		BackgroundColor3 = Color3.fromRGB(34, 28, 52),
		TextColor3 = C.Text,
		BorderSizePixel = 0,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
	stroke(b, C.BorderDim, 1)
	b.Activated:Connect(action)
	return b
end

function Controller:SetSummonTab(tab: "CALL_OF_THE_RIFT" | "A_STARS_ARRIVAL")
	local prev = self.ActiveSummonTab
	self.ActiveSummonTab = tab
	local isCall = (tab == "CALL_OF_THE_RIFT")
	self.CallTabBtn.TextColor3 = isCall and C.Text or C.TextMuted
	self.StarTabBtn.TextColor3 = not isCall and C.Text or C.TextMuted

	local targetX = isCall and 92 or 268
	TweenService:Create(self.ActiveIndicator, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(targetX, 36),
	}):Play()

	self.PermanentSummonView.Visible = isCall
	self.LimitedSummonView.Visible = not isCall
	if prev ~= tab and not UIFeel.ReducedMotion() then
		local activeView = if isCall then self.PermanentSummonView else self.LimitedSummonView
		local dir = if isCall then -1 else 1
		if self.TabSlideTween then
			self.TabSlideTween:Cancel()
		end
		activeView.Position = BANNER_VIEW_POS + UDim2.fromOffset(18 * dir, 0)
		local slide = TweenService:Create(activeView, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = BANNER_VIEW_POS,
		})
		self.TabSlideTween = slide
		slide:Play()
	end
	if self.HeroOdds then self.HeroOdds:Close() end
	self:EnsureBannerPortraits(tab)
	self:SyncBannerFx(prev ~= tab)
	self:Refresh()
end

-- A refused summon: the button row shakes, the status line pops, error sound and haptic.
function Controller:DenySummon(bannerId: string)
	local bv = self.BannerViews and self.BannerViews[bannerId]
	if not bv then return end
	local row = bv.Buttons[1] and bv.Buttons[1].Root.Parent
	UIFeel.Deny(if row and row:IsA("GuiObject") then row else nil)
	UIFeel.Pop(bv.Status, 0.12)
end

-- Shows a line under a banner's pity row: refusals in red, everything else muted.
function Controller:SetSummonStatus(bannerId: string, text: string, isError: boolean?)
	local bv = self.BannerViews and self.BannerViews[bannerId]
	if not bv then return end
	bv.Status.Text = text
	bv.Status.TextColor3 = if isError then C.Red else C.TextMuted
end

function Controller:PerformSummon(bannerId: string, count: number, confirmed: boolean?): boolean?
	if self.Busy then return false end
	local profile = self.GetProfile()
	local cost = summonCost(bannerId, count)
	local gems = profile and profile.Currencies and profile.Currencies.Gems or 0
	if gems < cost then
		self:SetSummonStatus(bannerId, string.format("You need %d Gems for this summon (you have %d).", cost, math.floor(gems)), true)
		self:DenySummon(bannerId)
		if self.Reveal and self.Reveal:IsOpen() then
			local btn = if count == 10 then self.Reveal.Again10.Root else self.Reveal.Again1.Root
			UIFeel.Deny(btn)
		end
		return false
	end

	-- The first 10x of the session asks before spending Gems (plan §6, Soft).
	if count == 10 and not confirmed and not self.Summon10Confirmed then
		Kit.Confirm.Ask({
			Tier = Kit.Rules.ConfirmTier("SUMMON_10X"),
			Title = string.format("Spend %s Gems?", StatBalance.Format(cost)),
			Body = "Summon 10 heroes from this banner.",
			ConfirmText = "Summon 10x",
			SessionKey = "SUMMON_10X_HEROES",
			OnConfirm = function()
				self.Summon10Confirmed = true
				self:PerformSummon(bannerId, count, true)
			end,
		})
		return false
	end

	local ownedBefore = ownedTemplates(profile)
	if self.HeroOdds then self.HeroOdds:Close() end
	self.Busy = true
	local activeBv = self.BannerViews and self.BannerViews[bannerId]
	if activeBv and activeBv.Fx then
		activeBv.Fx:SetCharging(true)
	end
	self:SetSummonStatus(bannerId, if bannerId == "A_STARS_ARRIVAL" then "Calling upon the stars…" else "Opening the rift…")
	self:Refresh()
	task.spawn(function()
		local ok, result = pcall(function()
			return self.Summon:InvokeServer(count, nil, bannerId)
		end)
		self.Busy = false
		if ok and result and result.Success then
			self.LastSummoned = result.Summoned or {}
			local topPulledStars = 1
			local topPulledRarity = 1
			for _, h in ipairs(self.LastSummoned) do
				if type(h) == "table" then
					if (h.Stars or 1) > topPulledStars then
						topPulledStars = h.Stars or 1
					end
					local r = StatFormulas.GetHeroRarity(h)
					if r > topPulledRarity then
						topPulledRarity = r
					end
				end
			end
			if _G.PortalEffectController and _G.PortalEffectController.TriggerSummonBurst then
				_G.PortalEffectController.TriggerSummonBurst(nil, topPulledStars)
			end
			if activeBv and activeBv.Fx then
				activeBv.Fx:PlayTriggerBurst(topPulledRarity)
				if self.Root.Visible and not UIFeel.ReducedMotion() then
					task.wait(0.18)
				end
				activeBv.Fx:SetCharging(false)
			end
			self:SetSummonStatus(bannerId, "")
			self.Root.Visible = false
			self.Scrim.Visible = false
			self:ShowSummonResults(self.LastSummoned, bannerId, ownedBefore)
		elseif ok then
			if activeBv and activeBv.Fx then
				activeBv.Fx:SetCharging(false)
			end
			if not self.Root.Visible then
				self:Open("Summoning")
			end
			self:SetSummonStatus(bannerId, tostring(result and result.Message or "The summon was refused."), true)
			self:DenySummon(bannerId)
			if self.Reveal and self.Reveal:IsOpen() then
				self.Reveal:Close(true)
			end
		else
			if activeBv and activeBv.Fx then
				activeBv.Fx:SetCharging(false)
			end
			if not self.Root.Visible then
				self:Open("Summoning")
			end
			self:SetSummonStatus(bannerId, "Couldn't reach the server. Try again.", true)
			self:DenySummon(bannerId)
			if self.Reveal and self.Reveal:IsOpen() then
				self.Reveal:Close(true)
			end
		end
		self:Refresh()
	end)
	return true
end

function Controller:IsOpen(): boolean
	return (self.Root ~= nil and self.Root.Visible) or (self.Reveal ~= nil and self.Reveal:IsOpen())
end

function Controller:Close()
	if self.HeroOdds then self.HeroOdds:Close() end
	if not self:IsOpen() then return end
	if self.Root then self.Root.Visible = false end
	if self.Scrim then self.Scrim.Visible = false end
	if self.Reveal then self.Reveal:Close() end
	if _G.SetModalFocusMode then
		_G.SetModalFocusMode(false)
	end
	if _G.UpdateBottomTabHighlights then
		_G.UpdateBottomTabHighlights()
	end
end

function Controller:Open(facility: string)
	if not DETAILS[facility] then return end
	if _G.SetModalFocusMode then
		_G.SetModalFocusMode(true)
	end
	self.OpenTime = os.clock()
	self.Current = facility
	self.Root.Visible = true
	self.Scrim.Visible = true
	self.Root:SetAttribute("Facility", facility)
	if self.Status then self.Status.Text = "" end
	if _G.UpdateBottomTabHighlights then
		_G.UpdateBottomTabHighlights()
	end

	local isSummon = (facility == "Summoning")
	if not isSummon and self.HeroOdds then self.HeroOdds:Close() end
	self.TabContainer.Visible = isSummon
	self.TabDivider.Visible = isSummon
	self.HeaderTitle.Visible = not isSummon
	self.PermanentSummonView.Visible = isSummon and (self.ActiveSummonTab == "CALL_OF_THE_RIFT")
	self.LimitedSummonView.Visible = isSummon and (self.ActiveSummonTab == "A_STARS_ARRIVAL")
	self.GeneralFacilityView.Visible = not isSummon

	if isSummon then
		self:EnsureBannerPortraits(self.ActiveSummonTab)
	else
		local info = DETAILS[facility]
		self.HeaderTitle.Text = info.Title
		self.HeaderTitle.TextColor3 = info.Color
	end

	self:SyncBannerFx(isSummon)
	self:Refresh()
end

function Controller:Request(callback: () -> (boolean, string))
	if self.Busy then return end
	self.Busy = true
	if self.Status then self.Status.Text = "Working…" end
	task.spawn(function()
		local ok, success, message = pcall(callback)
		self.Busy = false
		if self.Status then
			self.Status.Text = if ok then message or (success and "Done." or "Unable to complete this action.") else "Connection failed. Please try again."
		end
		self:Refresh()
	end)
end

function Controller:Refresh()
	if not self.Root.Visible then return end
	local profile = self.GetProfile()
	local gems = profile and profile.Currencies and profile.Currencies.Gems or 0
	self.GemCurrency.Text = string.format("%d Gems", math.floor(gems))

	if self.Current == "Summoning" then
		-- Pity text and bar, and the buttons' affordability / busy state, per banner.
		local pityCount = {
			CALL_OF_THE_RIFT = profile and (profile.HeroPermanentPity or profile.HeroBannerPity) or 0,
			A_STARS_ARRIVAL = profile and profile.HeroLimitedPity or 0,
		}
		for key, bv in self.BannerViews do
			local banner = BANNER_VIEWS[key].Banner
			local done = pityCount[key] % banner.MaxPity
			local guaranteedFeatured = key == "A_STARS_ARRIVAL" and profile ~= nil and profile.HeroLimitedFeaturedGuarantee == true
			local featuredSeed = HeroCatalog.Seeds[banner.FeaturedHeroId or ""]
			bv.Pity.Text = if guaranteedFeatured
				then string.format("Guaranteed <b>%s</b> in <b>%d</b> summons", featuredSeed and featuredSeed.DisplayName or "featured hero", math.max(1, banner.MaxPity - done))
				else string.format("Guaranteed %s+ hero in <b>%d</b> summons", HeroCatalog.RarityName(banner.PityMinTier or 5), math.max(1, banner.MaxPity - done))
			TweenService:Create(bv.PityFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(done / banner.MaxPity, 1) }):Play()
			if bv.Fx then
				bv.Fx:SetPityRatio(done / banner.MaxPity, guaranteedFeatured)
			end
			for count, b in bv.Buttons do
				local cost = summonCost(key, count)
				b.TitleLabel.Text = if self.Busy then "SUMMONING…" else string.format("SUMMON %dX", count)
				b.CostLabel.TextColor3 = if gems >= cost then Color3.new(1, 1, 1) else C.Red
				b.Root.AutoButtonColor = false
			end
		end

		-- God's Blessing badge: the luck the server applies to the next pull.
		local blessing = profile and profile.Facilities and profile.Facilities.GodsBlessing
		local luck = 0
		if blessing and (blessing.Level or 0) > 0 then
			local sumLabor = 0
			for _, u in ipairs(blessing.AssignedHeroUUIDs or {}) do
				local h = profile.Heroes[u]
				if h and (h.ComaUntilTimestamp or 0) <= os.time() then
					sumLabor += StatFormulas.GetEffectiveLabor(h, "FACILITY_GODS_BLESSING")
				end
			end
			luck = SummonLuck.Luck(blessing.Level, sumLabor, FortressTree.PerkBonuses(profile.FortressTree).BlessingLuck)
		end
		local badge = if luck > 0 then string.format("<font color=\"#FFE296\">Blessing +%.1f%% luck</font>", luck * 100) else "No Blessing luck active"
		if self.PermanentInfoLabel then self.PermanentInfoLabel.Text = badge end
		if self.LimitedInfoLabel then self.LimitedInfoLabel.Text = badge end
		if self.HeroOdds then self.HeroOdds:Refresh() end
		return
	end

	-- Support facility or SquadManagement rendering
	local info = DETAILS[self.Current]
	if not info then return end

	self.Title.Text = info.Title
	self.Title.TextColor3 = info.Color
	self.Description.Text = info.Description
	if self.Stroke then
		self.Stroke.Color = info.Color
	end

	for _, c in self.Actions:GetChildren() do c:Destroy() end
	for _, c in self.List:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end

	if not profile then
		self.Summary.Text = "Loading your heroes…"
		return
	end

	local currentTag = FacilityConfig.AssignmentTags[self.Current]
	-- Facility workers are out of the backpack: list only this facility's own workers plus free heroes.
	local heroes = {}
	for _, h in profile.Heroes or {} do
		if not InventoryCapacity.IsInFacility(h) or h.Assignment == currentTag then table.insert(heroes, h) end
	end

	table.sort(heroes, function(a, b)
		if currentTag then
			local aAssigned, bAssigned = a.Assignment == currentTag, b.Assignment == currentTag
			if aAssigned ~= bAssigned then return aAssigned end
		elseif self.Current == "SquadManagement" then
			local aSquad, bSquad = a.Assignment:match("^SQUAD_SLOT_") ~= nil, b.Assignment:match("^SQUAD_SLOT_") ~= nil
			if aSquad ~= bSquad then return aSquad end
		end
		if a.Stars ~= b.Stars then return a.Stars > b.Stars end
		return tostring(a.UUID) < tostring(b.UUID)
	end)

	if self.Current == "GuardPost" then
		local fac = profile.Facilities and profile.Facilities.GuardPost or { Level = 1, AssignedHeroUUIDs = {} }
		local sumLabor = 0
		for _, u in ipairs(fac.AssignedHeroUUIDs) do
			local h = profile.Heroes[u]
			if h and (h.ComaUntilTimestamp or 0) <= os.time() then
				sumLabor += StatFormulas.GetEffectiveLabor(h, "FACILITY_GUARD_POST")
			end
		end
		local bossTier = profile.HighestClearedBiomeBoss or 0
		local perks = FortressTree.PerkBonuses(profile.FortressTree)
		local rate = StatFormulas.GetPassiveGoldRate(fac.Level, sumLabor, bossTier, perks)
		local cfg = FacilityConfig.UpgradeTable.GuardPost[fac.Level]
		local hours = cfg and math.round((cfg.MaxOfflineMinutes + perks.OfflineMinutes) / 60) or 4
		local eff = cfg and math.round(cfg.OfflineEfficiency * 100) or 75
		local bossText = bossTier > 0 and string.format(" (+%d%% Boss Tier %d)", bossTier * 15, bossTier) or ""

		self.Summary.Text = string.format("Guard Post Lv.%d (%s)  •  %d/%d Adventurers  •  <b>%.1f Gold/min</b>%s  •  Offline Cap: %dh (%d%%)", fac.Level, cfg and cfg.VisualTitle or "Bastion", #fac.AssignedHeroUUIDs, cfg and cfg.MaxWorkers or 1, rate, bossText, hours, eff)

	elseif self.Current == "Market" then
		local fac = profile.Facilities and profile.Facilities.Market or { Level = 1, AssignedHeroUUIDs = {} }
		local sumLabor = 0
		for _, u in ipairs(fac.AssignedHeroUUIDs) do
			local h = profile.Heroes[u]
			if h and (h.ComaUntilTimestamp or 0) <= os.time() then
				sumLabor += StatFormulas.GetEffectiveLabor(h, "FACILITY_MARKET")
			end
		end
		local perks = FortressTree.PerkBonuses(profile.FortressTree)
		local mult = StatFormulas.GetMarketLootMultiplier(fac.Level, sumLabor, perks)
		local bonusPct = math.round((mult - 1) * 1000) / 10
		local cfg = FacilityConfig.UpgradeTable.Market[fac.Level]

		self.Summary.Text = string.format("Market Lv.%d (%s)  •  %d/%d Merchants  •  <b>+%.1f%% Tower & Cargo Gold</b>", fac.Level, cfg and cfg.VisualTitle or "Bazaar", #fac.AssignedHeroUUIDs, StatFormulas.GetFacilityMaxWorkers("Market", fac.Level, perks), bonusPct)

	elseif self.Current == "TrainingGrounds" then
		local fac = profile.Facilities and profile.Facilities.TrainingGrounds or { Level = 1, AssignedHeroUUIDs = {} }
		local sumLabor = 0
		for _, u in ipairs(fac.AssignedHeroUUIDs) do
			local h = profile.Heroes[u]
			if h and (h.ComaUntilTimestamp or 0) <= os.time() then
				sumLabor += StatFormulas.GetEffectiveLabor(h, "FACILITY_TRAINING")
			end
		end
		local perks = FortressTree.PerkBonuses(profile.FortressTree)
		local mult = StatFormulas.GetTrainingCombatMultiplier(fac.Level, sumLabor, perks)
		local bonusPct = math.round((mult - 1) * 1000) / 10
		local cfg = FacilityConfig.UpgradeTable.TrainingGrounds[fac.Level]

		self.Summary.Text = string.format("Training Grounds Lv.%d (%s)  •  %d/%d Trainers  •  <b>+%.1f%% Squad Final ATK & HP</b>", fac.Level, cfg and cfg.VisualTitle or "Arena", #fac.AssignedHeroUUIDs, StatFormulas.GetFacilityMaxWorkers("TrainingGrounds", fac.Level, perks), bonusPct)

	elseif self.Current == "GodsBlessing" then
		local fac = profile.Facilities and profile.Facilities.GodsBlessing or { Level = 0, AssignedHeroUUIDs = {} }
		local sumLabor = 0
		for _, u in ipairs(fac.AssignedHeroUUIDs) do
			local h = profile.Heroes[u]
			if h and (h.ComaUntilTimestamp or 0) <= os.time() then
				sumLabor += StatFormulas.GetEffectiveLabor(h, "FACILITY_GODS_BLESSING")
			end
		end
		local perks = FortressTree.PerkBonuses(profile.FortressTree)
		local luck = SummonLuck.Luck(fac.Level, sumLabor, perks.BlessingLuck)
		local cfg = FacilityConfig.UpgradeTable.GodsBlessing[fac.Level]
		self.Summary.Text = string.format("God's Blessing Lv.%d (%s)  •  %d/%d Acolytes  •  <b>+%.1f%% Summon Luck</b> (cap +%d%%)", fac.Level, cfg and cfg.VisualTitle or "Angel", #fac.AssignedHeroUUIDs, StatFormulas.GetFacilityMaxWorkers("GodsBlessing", fac.Level, perks), luck * 100, math.round(FacilityConfig.Constants.MaxSummonLuck * 100))

	else
		local deployed = 0
		for _, h in heroes do if h.Assignment:match("^SQUAD_SLOT_") then deployed += 1 end end
		local slots = 5
		self.Summary.Text = string.format("%d / %d squad slots occupied  •  Deploy heroes or send them to the bench", deployed, slots)
		self:Button(self.Actions, "RotateSquad", "REST EXHAUSTED & DEPLOY FRESH HEROES", UDim2.new(1, 0, 1, 0), UDim2.new(), function()
			self:Request(function() return self.Assign:InvokeServer("AUTO_SWAP_EXHAUSTED", "") end)
		end)
	end

	if #heroes == 0 then
		local empty = label(self.List, "Your roster is empty. Visit Summoning to call a hero.", 14, C.TextMuted, Enum.Font.GothamMedium)
		empty.Size = UDim2.new(1, 0, 0, 60)
		empty.TextXAlignment = Enum.TextXAlignment.Center
	end

	for index, hero in ipairs(heroes) do
		local row = new("Frame", {
			Name = "Hero_" .. hero.UUID,
			LayoutOrder = index,
			Size = UDim2.new(1, -8, 0, 84),
			BackgroundColor3 = C.CardBg,
			BorderSizePixel = 0,
			ZIndex = 54,
		}, self.List)
		new("UICorner", { CornerRadius = UDim.new(0, 6) }, row)
		stroke(row, C.BorderCard, 1)

		local desc = label(row, "", 13, C.Text, Enum.Font.GothamMedium)
		desc.Position = UDim2.fromOffset(12, 8)
		desc.Size = UDim2.new(0.6, -18, 1, -16)
		desc.TextXAlignment = Enum.TextXAlignment.Left

		local coma = math.max(0, (hero.ComaUntilTimestamp or 0) - os.time())
		local status = coma > 0 and string.format("<font color=\"#EF4444\">Coma (%ds)</font>", coma) or string.format("Stamina %d%%", math.round(hero.CurrentStamina or 100))
		local stars = HeroCatalog.RarityName(StatFormulas.GetHeroRarity(hero)) .. " " .. string.rep("★", hero.Stars or 1)
		local archIcon = string.format("<font color=\"#C4B8DB\">%s ·</font>", hero.Archetype or "Hero")

		local labor = StatFormulas.GetEffectiveLabor(hero, currentTag or hero.Assignment)
		local seed = HeroCatalog.Seeds[hero.TemplateId]
		local pref = seed and seed.PreferredFacility or ""
		local hasSynergy = currentTag and (pref == "ALL" or pref == currentTag or (currentTag == "FACILITY_GODS_BLESSING" and hero.Archetype == "Healer"))
		local synergyText = hasSynergy and " <font color=\"#4ADE80\">★ +25% Synergy</font>" or ""

		desc.Text = string.format("%s %s  <font color=\"#FACC15\">%s</font>  %s\n<font color=\"#A0B0C4\">%s  •  %s</font>\n<font color=\"#E2D5FC\">Labor: <b>%.1f</b>%s</font>", archIcon, hero.DisplayName, stars, StatFormulas.LevelText(hero), hero.Assignment, status, labor, synergyText)

		local assignTitle = "DEPLOY"
		local targetAssignment = "SQUAD_AUTO"
		if self.Current == "GuardPost" then
			assignTitle = "PATROL"
			targetAssignment = "FACILITY_GUARD_POST"
		elseif self.Current == "Market" then
			assignTitle = "MERCHANT"
			targetAssignment = "FACILITY_MARKET"
		elseif self.Current == "TrainingGrounds" then
			assignTitle = "TRAIN"
			targetAssignment = "FACILITY_TRAINING"
		elseif self.Current == "GodsBlessing" then
			assignTitle = "PRAY"
			targetAssignment = "FACILITY_GODS_BLESSING"
		end

		local uuid = hero.UUID
		self:Button(row, "Assign", assignTitle, UDim2.new(0.18, -4, 0, 36), UDim2.new(0.62, 0, 0.5, -18), function()
			self:Request(function() return self.Assign:InvokeServer(uuid, targetAssignment) end)
		end)
		self:Button(row, "Bench", "BENCH", UDim2.new(0.18, -4, 0, 36), UDim2.new(0.81, 0, 0.5, -18), function()
			self:Request(function() return self.Assign:InvokeServer(uuid, "BENCHED") end)
		end)
	end
end

return Controller
