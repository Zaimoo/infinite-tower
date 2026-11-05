--!strict
-- StarterPlayerScripts/UI/Hud/HeroIndex.luau
-- Master Compendium (Phase 5 §4.7), drawn in Gilded Grimoire:
--   * Mode Switcher: [HEROES] and [WEAPONS] compendiums
--   * HERO INDEX:
--       - Left: banners with collection bar (owned / total).
--       - Middle: hero cards with owned counts; ALL / OWNED / MISSING.
--       - Right: selected hero portrait, rarity badge, archetype, stats, kit, drop rate, summon button.
--   * WEAPON INDEX:
--       - Left: weapon categories (All, 6 Archetypes, Echoes of the Rift banner) with collection bars.
--       - Middle: weapon cards with 3D models/previews, star rating, rarity tint, owned counts.
--       - Right: 3D preview, stats (Power, Dmg Multiplier, AtkSpd), description, wielders, forge recipe, and Blacksmith button.
-- Client-only: catalog data plus the synced profile. Narrow screens show one column at a time with
-- a back button. ButtonB / the close button closes it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local HeroCatalog = require(Shared:WaitForChild("Config"):WaitForChild("HeroCatalog"))
local ArtifactCatalog = require(Shared:WaitForChild("Config"):WaitForChild("ArtifactCatalog"))
local Skills = require(Shared:WaitForChild("Config"):WaitForChild("ArchetypeCombatSkills"))
local StatBalance = require(Shared:WaitForChild("Config"):WaitForChild("StatBalance"))
local StatFormulas = require(Shared:WaitForChild("Util"):WaitForChild("StatFormulas"))
local SummonLuck = require(Shared:WaitForChild("Util"):WaitForChild("SummonLuck"))
local Grimoire = require(Shared:WaitForChild("Util"):WaitForChild("GildedGrimoire"))
local Portrait = require(script.Parent:WaitForChild("Portrait"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local Components = require(script.Parent:WaitForChild("Components"))
local ArtifactPreview = require(script.Parent.Parent:WaitForChild("ArtifactPreview"))

local e = React.createElement
local Panel = Components.Panel
local Heavy = Components.HeavyLabel
local Body = Components.Body
local IconAt = Components.IconAt
local Tones = Grimoire.Tones
local TEXT = Grimoire.Text
local INK = Grimoire.Ink

local BANNERS = {
	{ Key = "PERMANENT", Banner = HeroCatalog.PermanentBanner, Tag = "PERMANENT BANNER", Tone = "Violet", Summon = "CALL_OF_THE_RIFT" },
	{ Key = "LIMITED", Banner = HeroCatalog.LimitedBanner, Tag = "LIMITED EVENT", Tone = "Bronze", Summon = "A_STARS_ARRIVAL" },
}

local WEAPON_CATEGORIES = {
	{
		Key = "ALL",
		Title = "ALL WEAPONS",
		Tag = "MASTER CATALOG · 84 WEAPONS",
		Tone = "Gold",
		Icon = "Index",
		FilterFn = function(_seed: any) return true end,
	},
	{
		Key = "SWORD_SHIELD",
		Title = "SWORDS & SHIELDS",
		Tag = "VANGUARD · 14 WEAPONS",
		Tone = "Violet",
		Icon = "Vanguard",
		FilterFn = function(seed: any) return seed.Type == "SWORD_SHIELD" end,
	},
	{
		Key = "DAGGERS",
		Title = "DUAL DAGGERS",
		Tag = "STRIKER · 14 WEAPONS",
		Tone = "Crimson",
		Icon = "Striker",
		FilterFn = function(seed: any) return seed.Type == "DAGGERS" end,
	},
	{
		Key = "AXE",
		Title = "MINING AXES",
		Tag = "MINER · 14 WEAPONS",
		Tone = "Bronze",
		Icon = "Miner",
		FilterFn = function(seed: any) return seed.Type == "AXE" end,
	},
	{
		Key = "BOW",
		Title = "MARKSMAN BOWS",
		Tag = "MARKSMAN · 14 WEAPONS",
		Tone = "Cyan",
		Icon = "Marksman",
		FilterFn = function(seed: any) return seed.Type == "BOW" end,
	},
	{
		Key = "STAFF",
		Title = "SCHOLAR STAVES",
		Tag = "SCHOLAR · 14 WEAPONS",
		Tone = "Violet",
		Icon = "Scholar",
		FilterFn = function(seed: any) return seed.Type == "STAFF" end,
	},
	{
		Key = "TOME",
		Title = "HEALER TOMES",
		Tag = "HEALER · 14 WEAPONS",
		Tone = "Green",
		Icon = "Healer",
		FilterFn = function(seed: any) return seed.Type == "TOME" end,
	},
	{
		Key = "BANNER",
		Title = "BLACKSMITH FORGE BANNER",
		Tag = "ARTIFACT GACHA · 84 WEAPONS",
		Tone = "Violet",
		Icon = "Summon",
		FilterFn = function(_seed: any) return true end,
	},
}

local WIELDERS_BY_TYPE = {
	SWORD_SHIELD = "Aaron (2★), Morrigan (4★), Ignis (5★)",
	DAGGERS = "Han (1★), Velkist (2★), Sovereign Archon (5★)",
	AXE = "Catio (3★)",
	BOW = "Jenna (1★), Astrea (7★)",
	STAFF = "Eolka (3★), Solaris (6★)",
	TOME = "Valeria (4★)",
}

local WEAPON_EMOJI: { [string]: string } = {
	BOW = "🏹",
	SWORD_SHIELD = "🛡️",
	DAGGERS = "🗡️",
	AXE = "🪓",
	STAFF = "🪄",
	TOME = "📖",
}

type Filter = "All" | "Owned" | "Missing"

local CLOSE_ACTION = "HeroIndexClose"

local function heroesOf(banner: any): { string }
	local list = {}
	for tier = banner.MaxStar, 1, -1 do
		local id = banner.HeroesByStar[tier]
		if id then table.insert(list, id) end
	end
	return list
end

-- Owned copies, best star and highest level per template.
local function heroOwnership(profile: any): { [string]: { Copies: number, BestStar: number, BestLevel: number } }
	local owned = {}
	for _, hero in pairs(profile and profile.Heroes or {}) do
		local entry = owned[hero.TemplateId] or { Copies = 0, BestStar = 0, BestLevel = 0 }
		entry.Copies += 1
		entry.BestStar = math.max(entry.BestStar, hero.Stars or 1)
		entry.BestLevel = math.max(entry.BestLevel, hero.Level or 1)
		owned[hero.TemplateId] = entry
	end
	return owned
end

-- Owned copies, best star and highest rarity per weapon template.
local function weaponOwnership(profile: any): { [string]: { Copies: number, BestStar: number, BestRarity: number } }
	local owned = {}
	for _, art in pairs(profile and profile.Artifacts or {}) do
		if art and art.TemplateId then
			local entry = owned[art.TemplateId] or { Copies = 0, BestStar = 0, BestRarity = 0 }
			entry.Copies += 1
			entry.BestStar = math.max(entry.BestStar, art.Star or 1)
			entry.BestRarity = math.max(entry.BestRarity, art.Rarity or 1)
			owned[art.TemplateId] = entry
		end
	end
	return owned
end

local function weaponsOfCategory(cat: any): { string }
	local list = {}
	local order = ArtifactCatalog.CatalogOrder
	for _, id in ipairs(order) do
		local seed = ArtifactCatalog.Seeds[id]
		if seed and cat.FilterFn(seed) then
			table.insert(list, id)
		end
	end
	return list
end

-- Where a weapon comes from, read from the banner config: the price, this weapon's exact chance per
-- pull (tier chance / 6 weapon types x 60% Standard or 40% Enhanced, God's Blessing included) and
-- what it sells back for at 1 star.
local function acquisitionText(seed: any, luck: number): string
	local banner = ArtifactCatalog.Banner
	local rates = SummonLuck.ApplyLuck(banner.BaseRarityRates, luck)
	local chance = (rates[seed.RarityTier] or 0) / #ArtifactCatalog.ArchetypeOrder * (if seed.IsHighStat then 0.4 else 0.6) * 100
	local pct = if chance >= 0.1 then string.format("%.2f", chance) else string.format("%.3f", chance)
	return string.format("Blacksmith Forge banner · %s Gold per pull, %s per 10\n%s%% chance per pull%s · sells for %s Gold at 1★",
		StatBalance.Format(banner.Cost1X), StatBalance.Format(banner.Cost10X), pct,
		if luck > 0 then " (with God's Blessing)" else "",
		StatBalance.Format(ArtifactCatalog.CalculateSellPrice(seed.RarityTier, 1)))
end

-- A themed button with its label as a child (a fill gradient would tint text on the button).
local function button(props: { [string]: any }, tone: string, label: string, size: number?)
	local t = Tones[tone] or Tones.Slate
	local inst: { [string]: any } = { Class = "TextButton", Text = "", AutoButtonColor = false, Selectable = true, Radius = 10, Top = t.Top, Bottom = t.Bottom, Rail = t.Rail }
	for k, v in props do inst[k] = v end
	return Panel(inst, {
		Label = Heavy({ Position = UDim2.fromOffset(4, 2), Size = UDim2.new(1, -8, 1, -4), MaxSize = size or 14, Outline = 2, Gold = false, Text = label, ZIndex = (props.ZIndex or 1) + 2 }),
	})
end

-- Pill progress bar (ink track, shaded fill).
local function bar(props: { [string]: any }, fraction: number, color: Color3)
	local inst: { [string]: any } = { BackgroundColor3 = Color3.fromRGB(26, 20, 36), BorderSizePixel = 0 }
	for k, v in props do inst[k] = v end
	return e("Frame", inst, {
		Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Ink = e("UIStroke", { Color = INK, Thickness = 1.8, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		Fill = if fraction > 0 then e("Frame", { Size = UDim2.fromScale(math.clamp(fraction, 0.06, 1), 1), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = (props.ZIndex or 1) + 1 }, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Shade = e("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 165)) }),
		}) else nil,
	})
end

-- A titled Deep panel whose content sits in an inner frame (so the rail is not laid out with it).
local function column(order: number, width: UDim, title: string, extra: { [string]: any }?, content: any)
	local kids: { [string]: any } = {
		Heading = Heavy({ Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -150, 0, 22), MaxSize = 17, Outline = 2,
			TextXAlignment = Enum.TextXAlignment.Left, Text = title, ZIndex = 3 }),
		Content = content,
	}
	for k, v in extra or {} do kids[k] = v end
	return Panel({ LayoutOrder = order, Size = UDim2.new(width, UDim.new(1, 0)), Top = Tones.Deep.Top, Bottom = Tones.Deep.Bottom, Rail = Tones.Deep.Rail }, kids)
end

local function scroller(children: { [string]: any }, layout: any)
	children.Layout = layout
	children.Padding = e("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 10) })
	return e("ScrollingFrame", {
		Position = UDim2.fromOffset(6, 40), Size = UDim2.new(1, -12, 1, -46), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 5, ScrollBarImageColor3 = Color3.fromRGB(240, 196, 110),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 3,
	}, children)
end

-- A stat tile: caption over a big inked number.
local function statTile(order: number, caption: string, value: string, color: Color3?)
	return Panel({ LayoutOrder = order, Size = UDim2.new(1 / 3, -6, 1, 0), Radius = 10, Top = Tones.Violet.Top, Bottom = Tones.Violet.Bottom, Rail = Tones.Violet.Rail }, {
		Caption = Body({ Position = UDim2.fromOffset(4, 6), Size = UDim2.new(1, -8, 0, 14), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = TEXT.Muted, Text = caption, ZIndex = 3 }),
		Value = e("TextLabel", { Position = UDim2.fromOffset(4, 22), Size = UDim2.new(1, -8, 0, 24), BackgroundTransparency = 1, FontFace = Grimoire.Fonts.Number,
			TextScaled = true, TextColor3 = color or Color3.new(1, 1, 1), Text = value, ZIndex = 3 }, {
			Limit = e("UITextSizeConstraint", { MaxTextSize = 20 }),
			Ink = e("UIStroke", { Color = INK, Thickness = 2 }),
		}),
	})
end

-- A kit / info section: small gold heading and wrapped body text.
local function section(order: number, title: string, body: string, height: number)
	return e("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1 }, {
		Title = Heavy({ Size = UDim2.new(1, 0, 0, 18), MaxSize = 14, Outline = 1.8, TextXAlignment = Enum.TextXAlignment.Left, Text = title, ZIndex = 3 }),
		Text = Body({ Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 1, -20), TextSize = 13, TextWrapped = true, TextTruncate = Enum.TextTruncate.None,
			TextYAlignment = Enum.TextYAlignment.Top, Text = body, ZIndex = 3 }),
	})
end

-- 3D ViewportFrame / Model Preview for Weapons with emoji fallback.
local function WeaponPreviewBox(props: { TemplateId: string, Archetype: string, Size: UDim2, ZIndex: number })
	local frameRef = React.useRef(nil :: GuiObject?)
	local hasModel, setHasModel = React.useState(false)

	React.useEffect(function()
		if frameRef.current then
			local ok = ArtifactPreview.Show(frameRef.current, props.TemplateId)
			setHasModel(ok == true)
		end
		return function()
			local preview = frameRef.current and frameRef.current:FindFirstChild("ArtifactModelPreview")
			if preview then preview:Destroy() end
		end
	end, { props.TemplateId })

	return e("Frame", {
		ref = frameRef,
		Size = props.Size,
		BackgroundColor3 = Color3.fromRGB(12, 8, 18),
		BackgroundTransparency = 0,
		ClipsDescendants = true,
		ZIndex = props.ZIndex,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
		FallbackEmoji = if not hasModel then e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(48, 48),
			BackgroundTransparency = 1,
			Text = WEAPON_EMOJI[props.Archetype] or "⚔️",
			TextSize = 34,
			ZIndex = props.ZIndex + 1,
		}) else nil,
	})
end

local function HeroIndex(props: { Profile: any, Width: number, OnClose: () -> (), InitialMode: ("HEROES" | "WEAPONS")? })
	local indexMode, setIndexMode = React.useState((props.InitialMode or "HEROES") :: "HEROES" | "WEAPONS")
	local bannerKey, setBannerKey = React.useState("PERMANENT")
	local selectedHero, setSelectedHero = React.useState(nil :: string?)
	local heroFilter, setHeroFilter = React.useState("All" :: Filter)

	local weaponCatKey, setWeaponCatKey = React.useState("ALL")
	local selectedWeapon, setSelectedWeapon = React.useState(nil :: string?)
	local weaponFilter, setWeaponFilter = React.useState("All" :: Filter)

	local step, setStep = React.useState("banners") -- narrow layout only
	local firstButton = React.useRef(nil)

	-- ButtonB closes; the first banner gets gamepad focus.
	React.useEffect(function()
		ContextActionService:BindAction(CLOSE_ACTION, function(_, state)
			if state == Enum.UserInputState.Begin then props.OnClose() end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.ButtonB)
		if firstButton.current and GuiService:IsTenFootInterface() then
			GuiService.SelectedObject = firstButton.current
		end
		return function() ContextActionService:UnbindAction(CLOSE_ACTION) end
	end, {})

	local narrow = props.Width < 800
	local ownedHeroes = heroOwnership(props.Profile)
	local ownedWeapons = weaponOwnership(props.Profile)
	local luck = SummonLuck.ForProfile(props.Profile)

	-- =========================================================================
	-- TOTALS
	-- =========================================================================
	local totalHeroHave, totalHeroAll = 0, 0
	for _, b in BANNERS do
		for _, id in heroesOf(b.Banner) do
			totalHeroAll += 1
			if ownedHeroes[id] then totalHeroHave += 1 end
		end
	end

	local totalWeaponHave, totalWeaponAll = 0, 0
	for id, _ in pairs(ArtifactCatalog.Seeds) do
		totalWeaponAll += 1
		if ownedWeapons[id] then totalWeaponHave += 1 end
	end

	-- =========================================================================
	-- HERO MODE CONTENT
	-- =========================================================================
	local heroEntry = BANNERS[1]
	for _, b in BANNERS do if b.Key == bannerKey then heroEntry = b end end
	local heroIds = heroesOf(heroEntry.Banner)
	local selectedHeroId = selectedHero
	if not selectedHeroId or not table.find(heroIds, selectedHeroId) then selectedHeroId = heroIds[1] end

	local heroBannerChildren: { [string]: any } = {}
	for i, b in BANNERS do
		local ids = heroesOf(b.Banner)
		local have = 0
		for _, id in ids do if ownedHeroes[id] then have += 1 end end
		local active = b.Key == bannerKey
		local tone = Tones[b.Tone]
		heroBannerChildren["B" .. i] = Panel({
			Class = "TextButton", Text = "", AutoButtonColor = false, Selectable = true, ref = if i == 1 then firstButton else nil,
			LayoutOrder = i, Size = UDim2.new(1, 0, 0, 112), Radius = 12,
			Top = if active then tone.Top else Tones.Deep.Top, Bottom = tone.Bottom, Rail = if active then TEXT.Gold else tone.Rail,
			[React.Event.Activated] = function()
				setBannerKey(b.Key)
				setSelectedHero(nil)
				if narrow then setStep("heroes") end
			end,
		}, {
			Icon = IconAt("Summon", 40, { Position = UDim2.fromOffset(10, 10), ZIndex = 4 }),
			Title = Heavy({ Position = UDim2.fromOffset(56, 10), Size = UDim2.new(1, -66, 0, 22), MaxSize = 16, Outline = 2, Gold = active,
				TextXAlignment = Enum.TextXAlignment.Left, Text = b.Banner.Title, ZIndex = 4 }),
			Tag = Body({ Position = UDim2.fromOffset(56, 34), Size = UDim2.new(1, -66, 0, 14), TextSize = 11, TextColor3 = TEXT.Muted,
				Text = string.format("%s · %d HEROES", b.Tag, #ids), ZIndex = 4 }),
			Owned = Body({ Position = UDim2.fromOffset(12, 62), Size = UDim2.new(1, -24, 0, 16), TextSize = 13, TextColor3 = if have == #ids then TEXT.Gold else TEXT.Good,
				Text = if have == #ids then "Collection complete!" else string.format("Collected %d / %d", have, #ids), ZIndex = 4 }),
			Bar = bar({ Position = UDim2.fromOffset(12, 84), Size = UDim2.new(1, -24, 0, 12), ZIndex = 4 }, have / math.max(1, #ids),
				if have == #ids then TEXT.Gold else TEXT.Good),
		})
	end

	local heroCards: { [string]: any } = {}
	local heroShown = 0
	for i, id in heroIds do
		local seed = HeroCatalog.Seeds[id]
		local mine = ownedHeroes[id]
		local keep = heroFilter == "All" or (heroFilter == "Owned" and mine ~= nil) or (heroFilter == "Missing" and mine == nil)
		if seed and keep then
			heroShown += 1
			local rarityColor = Theme.RarityColor(seed.Rarity)
			local isSel = id == selectedHeroId
			heroCards["H" .. i] = Panel({
				Class = "TextButton", Text = "", AutoButtonColor = false, Selectable = true, LayoutOrder = i, Radius = 12,
				Top = Tones.Deep.Top:Lerp(rarityColor, if isSel then 0.4 else 0.22), Bottom = Tones.Deep.Bottom, Rail = if isSel then TEXT.Gold else rarityColor,
				[React.Event.Activated] = function()
					setSelectedHero(id)
					if narrow then setStep("details") end
				end,
			}, {
				Art = e("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.new(1, -20, 0, 110),
					BackgroundColor3 = Color3.fromRGB(12, 8, 18), ClipsDescendants = true, ZIndex = 3 }, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
					Ring = e("UIStroke", { Color = rarityColor, Thickness = 2.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
					Portrait = e(Portrait, { TemplateId = id, Archetype = seed.Archetype, Stars = seed.BaseStar, Size = UDim2.fromScale(1, 1), Dark = mine == nil }),
				}),
				Arch = IconAt(seed.Archetype, 26, { Position = UDim2.fromOffset(4, 100), ZIndex = 6 }),
				Missing = if mine == nil then Body({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52), Size = UDim2.new(1, -20, 0, 18), TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = TEXT.Muted, Text = "NOT OWNED", ZIndex = 5 }) else nil,
				Count = if mine then Panel({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(40, 24), Radius = 12,
					Top = Color3.fromRGB(60, 170, 90), Bottom = Color3.fromRGB(20, 90, 44), Rail = TEXT.Good, ZIndex = 6 }, {
					Text = Heavy({ Size = UDim2.fromScale(1, 1), MaxSize = 13, Outline = 1.8, Gold = false, Text = "x" .. mine.Copies, ZIndex = 8 }),
				}) else nil,
				Name = Heavy({ Position = UDim2.fromOffset(6, 126), Size = UDim2.new(1, -12, 0, 20), MaxSize = 15, Outline = 2, Gold = false, Text = seed.DisplayName, ZIndex = 4 }),
				Tier = Body({ Position = UDim2.fromOffset(6, 148), Size = UDim2.new(1, -12, 0, 16), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center,
					TextColor3 = rarityColor, Text = string.format("%s · %d★", HeroCatalog.RarityName(seed.Rarity), seed.BaseStar), ZIndex = 4 }),
			})
		end
	end
	if heroShown == 0 then
		heroCards.Empty = Body({ Size = UDim2.new(1, 0, 0, 40), TextSize = 14, TextColor3 = TEXT.Muted, TextXAlignment = Enum.TextXAlignment.Center,
			Text = if heroFilter == "Owned" then "You don't own any heroes from this banner yet." else "You own every hero on this banner!" })
	end

	local heroDetail: { [string]: any } = {}
	local heroSeed = selectedHeroId and HeroCatalog.Seeds[selectedHeroId]
	if heroSeed then
		local tier = heroSeed.Rarity or heroSeed.BaseStar
		local rarityColor = Theme.RarityColor(tier)
		local probe = { TemplateId = heroSeed.HeroId, Stars = heroSeed.BaseStar, Level = 1, QualityScalar = 1, Archetype = heroSeed.Archetype }
		local labor = StatFormulas.GetEffectiveLabor(probe, heroSeed.PreferredFacility)
		local kit = Skills.GetSkillProfile(heroSeed.HeroId, heroSeed.Archetype)
		local rates = heroEntry.Banner.Rates :: { number }
		local base = rates[tier] or 0
		local lucky = if luck > 0 then SummonLuck.ApplyLuck(rates, luck)[tier] else base
		local mine = ownedHeroes[heroSeed.HeroId]
		local mult = StatBalance.HeroRarityCombatMultiplier ^ (tier - 1)
		local function kitLine(def: any): string
			if not def then return "—" end
			return string.format("<b>%s</b> — %s", def.Name or "?", def.Description or string.format("%.0f%% damage", (def.DamageMultiplier or 1) * 100))
		end

		heroDetail.Hero = e("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 150), BackgroundTransparency = 1 }, {
			Art = e("Frame", { Size = UDim2.fromOffset(140, 140), BackgroundColor3 = Color3.fromRGB(12, 8, 18), ClipsDescendants = true, ZIndex = 3 }, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
				Ring = e("UIStroke", { Color = rarityColor, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
				Portrait = e(Portrait, { TemplateId = heroSeed.HeroId, Archetype = heroSeed.Archetype, Stars = heroSeed.BaseStar, Size = UDim2.fromScale(1, 1), Dark = mine == nil }),
			}),
			Name = Heavy({ Position = UDim2.fromOffset(152, 2), Size = UDim2.new(1, -152, 0, 30), MaxSize = 24, TextXAlignment = Enum.TextXAlignment.Left,
				Text = heroSeed.DisplayName, ZIndex = 3 }),
			Rarity = Panel({ Position = UDim2.fromOffset(152, 38), Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, Radius = 13,
				Top = rarityColor, Bottom = rarityColor:Lerp(Color3.new(0, 0, 0), 0.35), Rail = Color3.new(1, 1, 1), ZIndex = 3 }, {
				Pad = e("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
				Text = Heavy({ AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 26), TextScaled = false, TextSize = 14, Outline = 2, Gold = false,
					Text = string.format("%s · %d★", string.upper(HeroCatalog.RarityName(tier)), heroSeed.BaseStar), ZIndex = 5 }),
			}),
			Arch = IconAt(heroSeed.Archetype, 30, { Position = UDim2.fromOffset(150, 72), ZIndex = 4 }),
			ArchText = Body({ Position = UDim2.fromOffset(186, 78), Size = UDim2.new(1, -186, 0, 18), TextSize = 14,
				Text = string.format("%s · %s", heroSeed.Archetype, (string.gsub(ArtifactCatalog.ArchetypeWeaponType[heroSeed.Archetype] or "?", "_", " & "))), ZIndex = 3 }),
			Owned = Body({ Position = UDim2.fromOffset(152, 104), Size = UDim2.new(1, -152, 0, 34), TextSize = 13, TextWrapped = true, TextTruncate = Enum.TextTruncate.None,
				TextColor3 = if mine then TEXT.Good else TEXT.Muted,
				Text = if mine then string.format("Owned x%d · best %d★ · highest Lv.%d", mine.Copies, mine.BestStar, mine.BestLevel) else "Not owned yet", ZIndex = 3 }),
		})
		heroDetail.Stats = e("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1 }, {
			Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
			HP = statTile(1, "BASE HP", Components.Abbreviate(heroSeed.NativeHP * mult), TEXT.Good),
			ATK = statTile(2, "BASE ATK", Components.Abbreviate(heroSeed.NativeATK * mult), Color3.fromRGB(255, 150, 120)),
			Labor = statTile(3, "LABOR · " .. string.upper(Theme.FacilityNames[heroSeed.PreferredFacility] or "ANY"), string.format("%.1f", labor), TEXT.Gold),
		})
		heroDetail.Passive = section(3, "PASSIVE", heroSeed.PassiveTraitName or "—", 40)
		heroDetail.Basic = section(4, "BASIC ATTACK", kitLine(kit and kit.Basic), 52)
		heroDetail.Special = section(5, "SPECIAL", kitLine(kit and kit.Special), 60)
		heroDetail.Skill = section(6, "SKILL", kitLine(kit and kit.Skill), 60)
		heroDetail.Odds = Panel({ LayoutOrder = 7, Size = UDim2.new(1, 0, 0, if tier == heroEntry.Banner.MaxStar then 78 else 58), Radius = 10,
			Top = Tones.Violet.Top, Bottom = Tones.Violet.Bottom, Rail = Tones.Violet.Rail }, {
			Title = Heavy({ Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 18), MaxSize = 14, Outline = 1.8, TextXAlignment = Enum.TextXAlignment.Left,
				Text = "DROP RATE", ZIndex = 3 }),
			Rate = Body({ Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -24, 0, 18), TextSize = 14, ZIndex = 3,
				Text = if luck > 0 then string.format("%.2f%%  →  <font color=\"#78FF8C\"><b>%.2f%%</b></font> with God's Blessing", base * 100, lucky * 100)
					else string.format("<b>%.2f%%</b> per summon", base * 100) }),
			Pity = if tier == heroEntry.Banner.MaxStar then Body({ Position = UDim2.fromOffset(12, 52), Size = UDim2.new(1, -24, 0, 18), TextSize = 13, TextColor3 = TEXT.Gold,
				Text = string.format("Guaranteed within %d summons (pity)", heroEntry.Banner.MaxPity), ZIndex = 3 }) else nil,
		})
		heroDetail.Summon = button({ LayoutOrder = 8, Size = UDim2.new(1, 0, 0, 46), ZIndex = 3,
			[React.Event.Activated] = function()
				props.OnClose()
				if _G.OpenFacilityHUD then _G.OpenFacilityHUD("Summoning") end
			end }, "Action", "SUMMON ON " .. string.upper(heroEntry.Banner.Title), 15)
	end

	-- =========================================================================
	-- WEAPON MODE CONTENT
	-- =========================================================================
	local weaponEntry = WEAPON_CATEGORIES[1]
	for _, cat in WEAPON_CATEGORIES do if cat.Key == weaponCatKey then weaponEntry = cat end end
	local weaponIds = weaponsOfCategory(weaponEntry)
	local selectedWeaponId = selectedWeapon
	if not selectedWeaponId or not table.find(weaponIds, selectedWeaponId) then selectedWeaponId = weaponIds[1] end

	local weaponCategoryChildren: { [string]: any } = {}
	for i, cat in WEAPON_CATEGORIES do
		local ids = weaponsOfCategory(cat)
		local have = 0
		for _, id in ids do if ownedWeapons[id] then have += 1 end end
		local active = cat.Key == weaponCatKey
		local tone = Tones[cat.Tone] or Tones.Slate
		weaponCategoryChildren["WCat" .. i] = Panel({
			Class = "TextButton", Text = "", AutoButtonColor = false, Selectable = true, LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 112), Radius = 12,
			Top = if active then tone.Top else Tones.Deep.Top, Bottom = tone.Bottom, Rail = if active then TEXT.Gold else tone.Rail,
			[React.Event.Activated] = function()
				setWeaponCatKey(cat.Key)
				setSelectedWeapon(nil)
				if narrow then setStep("heroes") end
			end,
		}, {
			Icon = IconAt(cat.Icon, 40, { Position = UDim2.fromOffset(10, 10), ZIndex = 4 }),
			Title = Heavy({ Position = UDim2.fromOffset(56, 10), Size = UDim2.new(1, -66, 0, 22), MaxSize = 16, Outline = 2, Gold = active,
				TextXAlignment = Enum.TextXAlignment.Left, Text = cat.Title, ZIndex = 4 }),
			Tag = Body({ Position = UDim2.fromOffset(56, 34), Size = UDim2.new(1, -66, 0, 14), TextSize = 11, TextColor3 = TEXT.Muted,
				Text = cat.Tag, ZIndex = 4 }),
			Owned = Body({ Position = UDim2.fromOffset(12, 62), Size = UDim2.new(1, -24, 0, 16), TextSize = 13, TextColor3 = if have == #ids and #ids > 0 then TEXT.Gold else TEXT.Good,
				Text = if have == #ids and #ids > 0 then "Collection complete!" else string.format("Collected %d / %d", have, #ids), ZIndex = 4 }),
			Bar = bar({ Position = UDim2.fromOffset(12, 84), Size = UDim2.new(1, -24, 0, 12), ZIndex = 4 }, have / math.max(1, #ids),
				if have == #ids and #ids > 0 then TEXT.Gold else TEXT.Good),
		})
	end

	local weaponCards: { [string]: any } = {}
	local weaponShown = 0
	for i, id in weaponIds do
		local seed = ArtifactCatalog.Seeds[id]
		local mine = ownedWeapons[id]
		local keep = weaponFilter == "All" or (weaponFilter == "Owned" and mine ~= nil) or (weaponFilter == "Missing" and mine == nil)
		if seed and keep then
			weaponShown += 1
			local tier = seed.RarityTier or 1
			local rarityInfo = ArtifactCatalog.GetRarityInfo(tier)
			local rarityColor = Theme.RarityColor(tier)
			local isSel = id == selectedWeaponId
			weaponCards["W" .. i] = Panel({
				Class = "TextButton", Text = "", AutoButtonColor = false, Selectable = true, LayoutOrder = i, Radius = 12,
				Top = Tones.Deep.Top:Lerp(rarityColor, if isSel then 0.4 else 0.22), Bottom = Tones.Deep.Bottom, Rail = if isSel then TEXT.Gold else rarityColor,
				[React.Event.Activated] = function()
					setSelectedWeapon(id)
					if narrow then setStep("details") end
				end,
			}, {
				Art = e("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.new(1, -20, 0, 110),
					BackgroundColor3 = Color3.fromRGB(12, 8, 18), ClipsDescendants = true, ZIndex = 3 }, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
					Ring = e("UIStroke", { Color = rarityColor, Thickness = 2.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
					Preview = e(WeaponPreviewBox, { TemplateId = id, Archetype = seed.Type, Size = UDim2.fromScale(1, 1), ZIndex = 4 }),
				}),
				Arch = IconAt(seed.Type, 26, { Position = UDim2.fromOffset(4, 100), ZIndex = 6 }),
				Missing = if mine == nil then Body({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52), Size = UDim2.new(1, -20, 0, 18), TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = TEXT.Muted, Text = "NOT OWNED", ZIndex = 5 }) else nil,
				Count = if mine then Panel({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(40, 24), Radius = 12,
					Top = Color3.fromRGB(60, 170, 90), Bottom = Color3.fromRGB(20, 90, 44), Rail = TEXT.Good, ZIndex = 6 }, {
					Text = Heavy({ Size = UDim2.fromScale(1, 1), MaxSize = 13, Outline = 1.8, Gold = false, Text = "x" .. mine.Copies, ZIndex = 8 }),
				}) else nil,
				Name = Heavy({ Position = UDim2.fromOffset(6, 126), Size = UDim2.new(1, -12, 0, 20), MaxSize = 15, Outline = 2, Gold = false, Text = seed.DisplayName, ZIndex = 4 }),
				Tier = Body({ Position = UDim2.fromOffset(6, 148), Size = UDim2.new(1, -12, 0, 16), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center,
					TextColor3 = rarityColor, Text = string.format("%s · %s", rarityInfo.Name, seed.Variant or "Standard"), ZIndex = 4 }),
			})
		end
	end
	if weaponShown == 0 then
		weaponCards.Empty = Body({ Size = UDim2.new(1, 0, 0, 40), TextSize = 14, TextColor3 = TEXT.Muted, TextXAlignment = Enum.TextXAlignment.Center,
			Text = if weaponFilter == "Owned" then "You don't own any weapons from this category yet." else "You own every weapon in this category!" })
	end

	local weaponDetail: { [string]: any } = {}
	local weaponSeed = selectedWeaponId and ArtifactCatalog.Seeds[selectedWeaponId]
	if weaponSeed then
		local tier = weaponSeed.RarityTier or 1
		local rarityInfo = ArtifactCatalog.GetRarityInfo(tier)
		local rarityColor = Theme.RarityColor(tier)
		local mine = ownedWeapons[weaponSeed.TemplateId]
		local stats = ArtifactCatalog.GetStatBreakdown(weaponSeed.TemplateId, 1, tier)
		local power = stats.Power
		local dmgMult = stats.DamageMultiplier
		local speedBonus = stats["Attack Speed"]

		weaponDetail.Header = e("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 150), BackgroundTransparency = 1 }, {
			Art = e("Frame", { Size = UDim2.fromOffset(140, 140), BackgroundColor3 = Color3.fromRGB(12, 8, 18), ClipsDescendants = true, ZIndex = 3 }, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
				Ring = e("UIStroke", { Color = rarityColor, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
				Preview = e(WeaponPreviewBox, { TemplateId = weaponSeed.TemplateId, Archetype = weaponSeed.Type, Size = UDim2.fromScale(1, 1), ZIndex = 4 }),
			}),
			Name = Heavy({ Position = UDim2.fromOffset(152, 2), Size = UDim2.new(1, -152, 0, 30), MaxSize = 24, TextXAlignment = Enum.TextXAlignment.Left,
				Text = weaponSeed.DisplayName, ZIndex = 3 }),
			Rarity = Panel({ Position = UDim2.fromOffset(152, 38), Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, Radius = 13,
				Top = rarityColor, Bottom = rarityColor:Lerp(Color3.new(0, 0, 0), 0.35), Rail = Color3.new(1, 1, 1), ZIndex = 3 }, {
				Pad = e("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
				Text = Heavy({ AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 26), TextScaled = false, TextSize = 14, Outline = 2, Gold = false,
					Text = string.format("%s · %s", string.upper(rarityInfo.Name), string.upper(weaponSeed.Variant or "Standard")), ZIndex = 5 }),
			}),
			Arch = IconAt(weaponSeed.Type, 30, { Position = UDim2.fromOffset(150, 72), ZIndex = 4 }),
			ArchText = Body({ Position = UDim2.fromOffset(186, 78), Size = UDim2.new(1, -186, 0, 18), TextSize = 14,
				Text = string.format("%s Archetype", string.gsub(weaponSeed.Type, "_", " & ")), ZIndex = 3 }),
			Owned = Body({ Position = UDim2.fromOffset(152, 104), Size = UDim2.new(1, -152, 0, 34), TextSize = 13, TextWrapped = true, TextTruncate = Enum.TextTruncate.None,
				TextColor3 = if mine then TEXT.Good else TEXT.Muted,
				Text = if mine then string.format("Owned x%d · best %d★ · highest Tier %d", mine.Copies, mine.BestStar, mine.BestRarity) else "Not owned yet", ZIndex = 3 }),
		})

		weaponDetail.Stats = e("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1 }, {
			Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
			Power = statTile(1, "BASE POWER", Components.Abbreviate(power), TEXT.Gold),
			Mult = statTile(2, "DMG MULT", string.format("%.2fx", dmgMult), Color3.fromRGB(255, 150, 120)),
			Speed = statTile(3, "ATK SPEED", string.format("+%.1f%%", speedBonus), TEXT.Good),
		})

		weaponDetail.Description = section(3, "LORE & CONCEPT ART", weaponSeed.Description or "—", 52)
		weaponDetail.Wielders = section(4, "COMPATIBLE HEROES", WIELDERS_BY_TYPE[weaponSeed.Type] or "All heroes of this archetype", 40)
		weaponDetail.Acquisition = section(5, "ACQUISITION", acquisitionText(weaponSeed, luck), 66)

		weaponDetail.Action = button({ LayoutOrder = 6, Size = UDim2.new(1, 0, 0, 46), ZIndex = 3,
			[React.Event.Activated] = function()
				props.OnClose()
				if _G.OpenMasterModal then
					_G.OpenMasterModal("BLACKSMITH")
				elseif _G.OpenFacilityHUD then
					_G.OpenFacilityHUD("Blacksmith")
				end
			end }, "Action", "VISIT BLACKSMITH FORGE", 15)
	end

	-- =========================================================================
	-- COLUMNS ASSEMBLY
	-- =========================================================================
	local activeFilter = if indexMode == "HEROES" then heroFilter else weaponFilter
	local setActiveFilter = if indexMode == "HEROES" then setHeroFilter else setWeaponFilter
	local filterChips: { [string]: any } = { Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) }
	for order, key in { "All", "Owned", "Missing" } do
		filterChips[key] = button({ LayoutOrder = order, Size = UDim2.fromOffset(if key == "Missing" then 84 else 70, 26), ZIndex = 4,
			[React.Event.Activated] = function() setActiveFilter(key :: Filter) end }, if activeFilter == key then "Gold" else "Slate", string.upper(key), 12)
	end

	local leftTitle = if indexMode == "HEROES" then "BANNERS" else "CATEGORIES"
	local leftScrollerContent = if indexMode == "HEROES" then heroBannerChildren else weaponCategoryChildren
	local midTitle = if indexMode == "HEROES" then string.upper(heroEntry.Banner.Title) else string.upper(weaponEntry.Title)
	local midCards = if indexMode == "HEROES" then heroCards else weaponCards
	local rightTitle = if indexMode == "HEROES" then "HERO DETAILS" else "WEAPON DETAILS"
	local rightDetail = if indexMode == "HEROES" then heroDetail else weaponDetail

	local leftCol = column(1, if narrow then UDim.new(1, 0) else UDim.new(0.22, -8), leftTitle, nil,
		scroller(leftScrollerContent, e("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder })))
	local midCol = column(2, if narrow then UDim.new(1, 0) else UDim.new(0.42, -8), midTitle, {
		Filter = e("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), Size = UDim2.fromOffset(240, 26), BackgroundTransparency = 1, ZIndex = 3 }, filterChips),
	}, scroller(midCards, e("UIGridLayout", { CellSize = UDim2.fromOffset(150, 172), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder })))
	local rightCol = column(3, if narrow then UDim.new(1, 0) else UDim.new(0.36, 0), rightTitle, nil,
		scroller(rightDetail, e("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder })))

	local body: { [string]: any }
	if narrow then
		body = {
			Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal }),
			Only = if step == "banners" then leftCol elseif step == "heroes" then midCol else rightCol,
		}
	else
		body = {
			Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
			Left = leftCol,
			Mid = midCol,
			Right = rightCol,
		}
	end

	local windowTitle = if indexMode == "HEROES" then "HERO INDEX" else "WEAPON INDEX"
	local collectedText = if indexMode == "HEROES"
		then string.format("Collected %d / %d heroes", totalHeroHave, totalHeroAll)
		else string.format("Collected %d / %d weapons", totalWeaponHave, totalWeaponAll)
	local collectedFraction = if indexMode == "HEROES"
		then totalHeroHave / math.max(1, totalHeroAll)
		else totalWeaponHave / math.max(1, totalWeaponAll)

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(6, 5, 10),
		BackgroundTransparency = 1,
		Active = true,
		ZIndex = 20,
	}, {
		Window = Panel({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, -16),
			Size = UDim2.new(1, -48, 1, -80),
			Radius = 16,
			Active = true,
		}, {
			Max = e("UISizeConstraint", { MaxSize = Vector2.new(1200, 740) }),
			TitleIcon = IconAt("Index", 50, { Position = UDim2.fromOffset(18, 10), ZIndex = 3 }),
			Title = Heavy({ Position = UDim2.fromOffset(78, 12), Size = UDim2.fromOffset(300, 30), MaxSize = 28, TextXAlignment = Enum.TextXAlignment.Left,
				Text = windowTitle, ZIndex = 3 }),
			Collected = Body({ Position = UDim2.fromOffset(80, 42), Size = UDim2.fromOffset(300, 16), TextSize = 13, TextColor3 = TEXT.Muted, ZIndex = 3,
				Text = collectedText }),
			CollectedBar = if not narrow then bar({ Position = UDim2.fromOffset(390, 30), Size = UDim2.fromOffset(200, 14), ZIndex = 3 },
				collectedFraction, TEXT.Gold) else nil,
			ModeTabs = e("Frame", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, if narrow then -76 else -76, 0, 16),
				Size = UDim2.fromOffset(240, 38),
				BackgroundTransparency = 1,
				ZIndex = 4,
			}, {
				Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Right }),
				Heroes = button({
					Size = UDim2.fromOffset(112, 34),
					ZIndex = 4,
					[React.Event.Activated] = function()
						setIndexMode("HEROES")
						if narrow then setStep("banners") end
					end,
				}, if indexMode == "HEROES" then "Gold" else "Slate", "HEROES", 13),
				Weapons = button({
					Size = UDim2.fromOffset(112, 34),
					ZIndex = 4,
					[React.Event.Activated] = function()
						setIndexMode("WEAPONS")
						if narrow then setStep("banners") end
					end,
				}, if indexMode == "WEAPONS" then "Gold" else "Slate", "WEAPONS", 13),
			}),
			Back = if narrow and step ~= "banners" then button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -326, 0, 16), Size = UDim2.fromOffset(96, 38), ZIndex = 5,
				[React.Event.Activated] = function() setStep(if step == "details" then "heroes" else "banners") end }, "Slate", "‹ BACK", 14) else nil,
			Close = Panel({
				Class = "TextButton", Text = "", AutoButtonColor = false, Selectable = true, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 16),
				Size = UDim2.fromOffset(44, 40), Radius = 10, Top = Tones.Crimson.Top, Bottom = Tones.Crimson.Bottom, Rail = Tones.Crimson.Rail, ZIndex = 4,
				[React.Event.Activated] = function() props.OnClose() end,
			}, {
				X = IconAt("Close", 18, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 6 }),
			}),
			Body = e("Frame", { Position = UDim2.fromOffset(16, 70), Size = UDim2.new(1, -32, 1, -86), BackgroundTransparency = 1, ZIndex = 2 }, body),
		}),
	})
end

return HeroIndex
