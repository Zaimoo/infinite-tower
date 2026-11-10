--!strict
-- StarterPlayerScripts/UI/HeroOddsModal.luau
-- "View Heroes & Odds" window for the Summoning Altar's hero banners (Call of the Rift and A Star's
-- Arrival). Laid out like the Blacksmith Forge's "All weapons & odds" window: rate pills and the
-- banner rules on top, then every tier (rarest first) with the heroes it can award, each hero's
-- chance per pull, and Featured / Owned markers. Odds come from HeroBannerOdds (the server's roll)
-- with the profile's God's Blessing luck applied. Portraits are built on open and freed on close.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HeroCatalog = require(Shared:WaitForChild("Config"):WaitForChild("HeroCatalog"))
local ArtifactCatalog = require(Shared:WaitForChild("Config"):WaitForChild("ArtifactCatalog"))
local StatBalance = require(Shared:WaitForChild("Config"):WaitForChild("StatBalance"))
local SummonLuck = require(Shared:WaitForChild("Util"):WaitForChild("SummonLuck"))
local HeroBannerOdds = require(Shared:WaitForChild("Util"):WaitForChild("HeroBannerOdds"))
local GothicBoxStyle = require(Shared:WaitForChild("Util"):WaitForChild("GothicBoxStyle"))
local GrimoireIcons = require(Shared:WaitForChild("Util"):WaitForChild("GrimoireIcons"))
local GildedGrimoire = require(Shared:WaitForChild("Util"):WaitForChild("GildedGrimoire"))
local HeroCard = require(script.Parent:WaitForChild("HeroCard"))
local ModalFit = require(script.Parent:WaitForChild("ModalFit"))
local Theme = require(script.Parent:WaitForChild("Hud"):WaitForChild("Theme"))

local HeroOddsModal = {}
HeroOddsModal.__index = HeroOddsModal

local WIDTH, HEIGHT = 760, 520 -- same size as the Summoning Altar window
local Z = 66
local CLOSE_ACTION = "HeroOddsClose"

local TEXT = Color3.fromRGB(246, 242, 255)
local SUBTEXT = Color3.fromRGB(214, 204, 232)

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local o = Instance.new(className)
	for k, v in pairs(props) do
		(o :: any)[k] = v
	end
	o.Parent = parent
	return o
end

local function label(parent: Instance, text: string, size: number, color: Color3, font: Enum.Font?): TextLabel
	local lbl = new("TextLabel", {
		BackgroundTransparency = 1, Text = text, TextSize = size, TextColor3 = color,
		Font = font or Enum.Font.GothamBold, Size = UDim2.new(1, 0, 0, size + 8),
		TextTruncate = Enum.TextTruncate.AtEnd, RichText = true,
	}, parent)
	GothicBoxStyle.Font.Apply(lbl, { Role = if size >= 20 then "Title" else if size >= 15 then "Header" else "Body", Color = color, Size = size })
	return lbl
end

-- Small text reads muddy with the Body role's ink stroke; drop it (as the Forge catalog does).
local function plainText(obj: TextLabel)
	obj.TextStrokeTransparency = 1
	local ink = obj:FindFirstChild("GrimoireTextInk")
	if ink then ink:Destroy() end
end

-- Rare blue and Superior purple are too dark for small text on a dark card.
local function readable(color: Color3): Color3
	return color:Lerp(Color3.new(1, 1, 1), 0.4)
end

-- 75.14 -> "75.1", 1.65 -> "1.65", 0.03 -> "0.03", 0.015 -> "0.015"
local function formatPercent(pct: number): string
	if pct >= 10 then return string.format("%.1f", pct) end
	if pct >= 0.1 then return (string.gsub(string.format("%.2f", pct), "0$", "")) end
	return (string.gsub(string.format("%.3f", pct), "0$", ""))
end

local function ownership(profile: any): { [string]: number }
	local copies: { [string]: number } = {}
	for _, hero in (profile and profile.Heroes) or {} do
		if hero.TemplateId then copies[hero.TemplateId] = (copies[hero.TemplateId] or 0) + 1 end
	end
	return copies
end

-- `banners` maps a banner key ("CALL_OF_THE_RIFT" / "A_STARS_ARRIVAL") to its HeroCatalog banner.
function HeroOddsModal.new(gui: ScreenGui, banners: { [string]: any }, getProfile: () -> any)
	local self: any = setmetatable({}, HeroOddsModal)
	self.Banners = banners
	self.GetProfile = getProfile
	self.BannerKey = nil

	local scrim = new("TextButton", {
		Name = "HeroOddsScrim", Text = "", AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = Z - 1,
	}, gui)
	scrim.Activated:Connect(function() self:Close() end)
	self.Scrim = scrim

	-- A TextButton (not a Frame) so clicks inside the window don't fall through to the scrim.
	local win = new("TextButton", {
		Name = "HeroOddsWindow", Text = "", AutoButtonColor = false, Active = true,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, HEIGHT), BackgroundColor3 = Color3.fromRGB(15, 13, 22),
		BorderSizePixel = 0, ZIndex = Z,
	}, scrim)
	GildedGrimoire.Frame(win, { Class = "Window", Tone = "Deep", ZIndex = Z })
	ModalFit.Bind(win, new("UIScale", {}, win), WIDTH, HEIGHT, { MaxScale = 1.25 })

	-- Header
	local headerIcon = GrimoireIcons.Create("Summon", 36, win, Z + 2)
	headerIcon.Position = UDim2.fromOffset(18, 12)
	local title = label(win, "", 20, Color3.new(1, 1, 1), Enum.Font.GothamBlack)
	title.Position = UDim2.fromOffset(62, 16)
	title.Size = UDim2.new(1, -140, 0, 26)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = Z + 2
	self.Title = title

	local closeBtn = new("TextButton", {
		Name = "CloseBtn", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 12),
		Size = UDim2.fromOffset(34, 34), Text = "", BackgroundColor3 = Color3.fromRGB(28, 20, 36),
		BorderSizePixel = 0, ZIndex = Z + 2,
	}, win)
	GildedGrimoire.Frame(closeBtn, { Class = "Button", Tone = "Crimson", ZIndex = Z + 3 })
	GrimoireIcons.CloseGlyph(closeBtn, 16)
	closeBtn.Activated:Connect(function() self:Close() end)

	-- Rates box: one pill per tier, then the banner's rules and live state (50/50, Blessing).
	local ratesBox = new("Frame", {
		Name = "RatesBox", Position = UDim2.fromOffset(18, 56), Size = UDim2.new(1, -36, 0, 80),
		BackgroundColor3 = Color3.fromRGB(22, 16, 32), BorderSizePixel = 0, ZIndex = Z + 1,
	}, win)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, ratesBox)
	new("UIStroke", { Color = Color3.fromRGB(80, 55, 110), Thickness = 1.2 }, ratesBox)
	local ratesRow = new("Frame", {
		Name = "RatesRow", Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 22),
		BackgroundTransparency = 1, ZIndex = Z + 2,
	}, ratesBox)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6),
	}, ratesRow)
	self.RatesRow = ratesRow

	local rules = label(ratesBox, "", 12, SUBTEXT, Enum.Font.GothamMedium)
	rules.Position = UDim2.fromOffset(12, 34)
	rules.Size = UDim2.new(1, -24, 0, 18)
	rules.TextXAlignment = Enum.TextXAlignment.Left
	rules.ZIndex = Z + 2
	plainText(rules)
	self.Rules = rules

	local state = label(ratesBox, "", 12, SUBTEXT, Enum.Font.GothamMedium)
	state.Position = UDim2.fromOffset(12, 54)
	state.Size = UDim2.new(1, -24, 0, 18)
	state.TextXAlignment = Enum.TextXAlignment.Left
	state.ZIndex = Z + 2
	plainText(state)
	self.State = state

	-- Hero list
	local scroll = new("ScrollingFrame", {
		Name = "HeroScroll", BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = UDim2.fromOffset(18, 146), Size = UDim2.new(1, -36, 1, -160),
		ScrollBarThickness = 6, ScrollBarImageColor3 = Color3.fromRGB(240, 196, 110),
		CanvasSize = UDim2.fromScale(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = Z + 1,
	}, win)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }, scroll)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 16), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 8),
	}, scroll)
	self.Scroll = scroll

	return self
end

function HeroOddsModal:IsOpen(): boolean
	return self.Scrim.Visible
end

function HeroOddsModal:Open(bannerKey: string)
	if not self.Banners[bannerKey] then return end
	self.BannerKey = bannerKey
	self.Scrim.Visible = true
	self.Scroll.CanvasPosition = Vector2.zero
	ContextActionService:BindAction(CLOSE_ACTION, function(_, inputState)
		if inputState == Enum.UserInputState.Begin then self:Close() end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.ButtonB)
	self:Render()
end

function HeroOddsModal:Close()
	if not self.Scrim.Visible then return end
	self.Scrim.Visible = false
	ContextActionService:UnbindAction(CLOSE_ACTION)
	self:Clear() -- frees the portrait viewports
end

-- Everything the window shows that depends on the profile. Profile syncs arrive every few seconds
-- (passive Gold ticks), so Refresh only rebuilds when one of these actually changed; rebuilding on
-- every sync destroys the portrait viewports and makes the heroes flicker.
function HeroOddsModal:Signature(): string
	local banner = self.Banners[self.BannerKey]
	local profile = self.GetProfile()
	local copies = ownership(profile)
	local parts = { tostring(self.BannerKey), string.format("%.6f", SummonLuck.ForProfile(profile)),
		tostring(profile ~= nil and profile.HeroLimitedFeaturedGuarantee == true) }
	for _, id in HeroBannerOdds.Heroes(banner) do
		table.insert(parts, tostring(copies[id] or 0))
	end
	return table.concat(parts, "|")
end

-- Re-renders while open, but only when owned copies, Blessing luck or the 50/50 state changed.
function HeroOddsModal:Refresh()
	if self.Scrim.Visible and self:Signature() ~= self.RenderedSignature then self:Render() end
end

function HeroOddsModal:Clear()
	self.RenderedSignature = nil
	for _, parent in { self.RatesRow, self.Scroll } do
		for _, child in parent:GetChildren() do
			if child:IsA("GuiObject") then child:Destroy() end
		end
	end
end

function HeroOddsModal:Render()
	local banner = self.Banners[self.BannerKey]
	if not banner then return end
	self:Clear()
	self.RenderedSignature = self:Signature()

	local profile = self.GetProfile()
	local luck = SummonLuck.ForProfile(profile)
	local tiers = HeroBannerOdds.Tiers(banner, luck)
	local copies = ownership(profile)
	local featuredId = banner.FeaturedHeroId or banner.HeroesByStar[banner.MaxStar]
	local featuredSeed = HeroCatalog.Seeds[featuredId]
	local featuredName = featuredSeed and featuredSeed.DisplayName or "the featured hero"

	self.Title.Text = string.format("%s  ·  HEROES & ODDS", banner.Title)

	-- Rate pills, rarest first.
	for i, t in tiers do
		local color = Theme.RarityColor(t.Tier)
		local pill = new("Frame", {
			Name = "RatePill_" .. t.Tier, LayoutOrder = i, BackgroundColor3 = Color3.fromRGB(16, 12, 24),
			BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 22), ZIndex = Z + 3,
		}, self.RatesRow)
		new("UICorner", { CornerRadius = UDim.new(0, 5) }, pill)
		new("UIStroke", { Color = color, Thickness = 1.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, pill)
		new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, pill)
		local t1 = label(pill, string.format("%s %s%%", HeroCatalog.RarityName(t.Tier), formatPercent(t.Rate * 100)), 11, readable(color), Enum.Font.GothamBold)
		t1.AutomaticSize = Enum.AutomaticSize.X -- the pill takes its width from the text
		t1.Size = UDim2.new(0, 0, 1, 0)
		t1.TextTruncate = Enum.TextTruncate.None
		t1.ZIndex = Z + 4
		plainText(t1)
	end

	self.Rules.Text = string.format("%s+ guaranteed by pull %d  ·  %s+ in every 10x  ·  every hero drops at 1★  ·  %d / %s Gems",
		HeroCatalog.RarityName(banner.PityMinTier or 5), banner.MaxPity, HeroCatalog.RarityName(banner.TenPullMinTier),
		banner.Cost1X, StatBalance.Format(banner.Cost10X))

	local stateParts = {}
	if banner.FeaturedHeroId then
		if profile and profile.HeroLimitedFeaturedGuarantee == true then
			table.insert(stateParts, string.format("<font color=\"#FFD678\"><b>Your next pity is guaranteed %s.</b></font>", featuredName))
		else
			table.insert(stateParts, string.format("50/50: an %s+ hero that isn't %s makes your next pity %s.", HeroCatalog.RarityName(banner.PityMinTier or 5), featuredName, featuredName))
		end
	end
	table.insert(stateParts, if luck > 0
		then string.format("<font color=\"#FFE296\">God's Blessing: +%s%% on every tier above Common</font>", formatPercent(luck * 100))
		else "No God's Blessing luck active")
	self.State.Text = table.concat(stateParts, "  ·  ")

	-- Tiers, rarest first: a header row with the tier's chance, then its heroes two per row.
	local order = 0
	for _, t in tiers do
		if #t.Heroes == 0 then continue end
		local color = Theme.RarityColor(t.Tier)
		order += 1
		local header = new("Frame", {
			Name = "Tier" .. t.Tier, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 32), BorderSizePixel = 0, ZIndex = Z + 2,
		}, self.Scroll)
		GildedGrimoire.Frame(header, { Class = "Row", Tone = "Violet", Rail = color, ZIndex = Z + 2 })
		local name = label(header, string.upper(HeroCatalog.RarityName(t.Tier)) .. "  " .. string.rep("★", t.Tier), 15, readable(color), Enum.Font.GothamBlack)
		name.Position = UDim2.fromOffset(14, 0)
		name.Size = UDim2.new(0.5, 0, 1, 0)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.ZIndex = Z + 4
		name.FontFace = GildedGrimoire.Fonts.Title
		local oddsText = string.format("<b>%s%%</b> for this tier", formatPercent(t.Rate * 100))
		if #t.Heroes > 1 then
			oddsText ..= string.format("  ·  %s%% per hero", formatPercent(t.Rate * 100 / #t.Heroes))
		end
		local odds = label(header, oddsText, 12, TEXT, Enum.Font.GothamMedium)
		odds.AnchorPoint = Vector2.new(1, 0)
		odds.Position = UDim2.new(1, -14, 0, 0)
		odds.Size = UDim2.new(0.5, 0, 1, 0)
		odds.TextXAlignment = Enum.TextXAlignment.Right
		odds.ZIndex = Z + 4
		plainText(odds)

		for first = 1, #t.Heroes, 2 do
			order += 1
			local row = new("Frame", {
				Name = string.format("Row_%d_%d", t.Tier, first), LayoutOrder = order,
				Size = UDim2.new(1, 0, 0, 96), BackgroundTransparency = 1, ZIndex = Z + 1,
			}, self.Scroll)
			new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, row)
			for i = first, math.min(first + 1, #t.Heroes) do
				local h = t.Heroes[i]
				self:HeroCard(row, h.HeroId, t.Tier, h.Chance, copies[h.HeroId] or 0, h.HeroId == featuredId, i)
			end
		end
	end
end

-- One hero card: portrait, name, archetype and weapon, 1★ stats, chance per pull, Featured / Owned.
function HeroOddsModal:HeroCard(parent: Instance, heroId: string, tier: number, chance: number, owned: number, featured: boolean, order: number)
	local seed = HeroCatalog.Seeds[heroId]
	if not seed then return end
	local heroTier = HeroCatalog.RarityOf(heroId)
	local color = Theme.RarityColor(heroTier)
	local card = new("Frame", {
		Name = "Card_" .. heroId, LayoutOrder = order, Size = UDim2.new(0.5, -6, 1, 0), BorderSizePixel = 0, ZIndex = Z + 2,
	}, parent)
	GildedGrimoire.Frame(card, { Class = "Card", Tone = "Deep", Rail = color, ZIndex = Z + 2 })

	local portraitBox = new("Frame", {
		Name = "PortraitBox", Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(76, 76),
		BackgroundColor3 = color:Lerp(Color3.fromRGB(10, 6, 16), 0.75), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = Z + 3,
	}, card)
	new("UICorner", { CornerRadius = UDim.new(0, 10) }, portraitBox)
	new("UIStroke", { Color = color, Thickness = if featured then 2.6 else 1.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, portraitBox)
	local portrait = HeroCard.Portrait(portraitBox, { TemplateId = heroId, Stars = 1 })
	portrait.ZIndex = Z + 4

	local nameLbl = label(card, seed.DisplayName, 14, TEXT, Enum.Font.GothamBlack)
	nameLbl.Position = UDim2.fromOffset(96, 10)
	nameLbl.Size = UDim2.new(1, -206, 0, 18)
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.ZIndex = Z + 3
	nameLbl.FontFace = GildedGrimoire.Fonts.Title

	local archetype = seed.Archetype or "Hero"
	local icon = GrimoireIcons.Create(archetype, 16, card, Z + 4)
	icon.Position = UDim2.fromOffset(96, 31)
	local weapon = string.gsub(ArtifactCatalog.ArchetypeWeaponType[archetype] or "?", "_", " & ")
	local roleLbl = label(card, string.format("%s  ·  %s", archetype, weapon), 11, SUBTEXT, Enum.Font.GothamBold)
	roleLbl.Position = UDim2.fromOffset(116, 30)
	roleLbl.Size = UDim2.new(1, -216, 0, 16)
	roleLbl.TextXAlignment = Enum.TextXAlignment.Left
	roleLbl.ZIndex = Z + 3
	plainText(roleLbl)

	-- A tier whose hero has another rarity (Call of the Rift's Superior roll awards Catio) says so.
	local rarityText = string.format("%s hero", HeroCatalog.RarityName(heroTier))
	if heroTier ~= tier then
		rarityText ..= string.format("  ·  from a %s roll", HeroCatalog.RarityName(tier))
	end
	local rarityLbl = label(card, rarityText, 11, readable(color), Enum.Font.GothamBold)
	rarityLbl.Position = UDim2.fromOffset(96, 48)
	rarityLbl.Size = UDim2.new(1, -196, 0, 15)
	rarityLbl.TextXAlignment = Enum.TextXAlignment.Left
	rarityLbl.ZIndex = Z + 3
	plainText(rarityLbl)

	local statsLbl = label(card, string.format("1★  HP <b>%s</b>   ATK <b>%s</b>   Labor <b>%s</b>",
		StatBalance.Format(seed.NativeHP or seed.BaseHP_1Star or 0), StatBalance.Format(seed.NativeATK or seed.BaseATK_1Star or 0),
		StatBalance.Format(seed.NativeLabor or seed.BaseLabor_1Star or 0)), 11, TEXT, Enum.Font.GothamMedium)
	statsLbl.Position = UDim2.fromOffset(96, 66)
	statsLbl.Size = UDim2.new(1, if owned > 0 then -186 else -106, 0, 15)
	statsLbl.TextXAlignment = Enum.TextXAlignment.Left
	statsLbl.ZIndex = Z + 3
	plainText(statsLbl)

	local oddsLbl = label(card, string.format("<b>%s%%</b> per pull", formatPercent(chance * 100)), 12, readable(Theme.RarityColor(tier)), Enum.Font.GothamBold)
	oddsLbl.AnchorPoint = Vector2.new(1, 0)
	oddsLbl.Position = UDim2.new(1, -12, 0, 10)
	oddsLbl.Size = UDim2.fromOffset(100, 16)
	oddsLbl.TextXAlignment = Enum.TextXAlignment.Right
	oddsLbl.ZIndex = Z + 3
	plainText(oddsLbl)

	-- `top` anchors the stud under the odds line; otherwise it sits in the bottom-right corner.
	local function stud(text: string, tone: string, top: boolean, width: number)
		local s = new("Frame", {
			AnchorPoint = Vector2.new(1, if top then 0 else 1),
			Position = if top then UDim2.new(1, -10, 0, 32) else UDim2.new(1, -10, 1, -8),
			Size = UDim2.fromOffset(width, 20),
			BorderSizePixel = 0, ZIndex = Z + 4,
		}, card)
		GildedGrimoire.Frame(s, { Class = "Compact", Tone = tone, ZIndex = Z + 4 })
		local t = label(s, text, 10, if tone == "Gold" then Color3.fromRGB(30, 18, 6) else Color3.new(1, 1, 1), Enum.Font.GothamBlack)
		t.Size = UDim2.fromScale(1, 1)
		t.TextXAlignment = Enum.TextXAlignment.Center
		t.ZIndex = Z + 6
		t.FontFace = GildedGrimoire.Fonts.Title
		return s
	end
	if owned > 0 then
		stud(if owned > 1 then string.format("OWNED ×%d", owned) else "OWNED", "Jade", false, 74).Name = "OwnedStud"
	end
	if featured then
		stud("FEATURED", "Gold", true, 74).Name = "FeaturedStud"
	end
end

function HeroOddsModal:Destroy()
	self:Close()
	self.Scrim:Destroy()
end

return HeroOddsModal
