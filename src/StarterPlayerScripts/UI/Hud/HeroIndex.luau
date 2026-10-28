--!strict
-- StarterPlayerScripts/UI/Hud/HeroIndex.luau
-- Hero Index (Phase 5 §4.7), drawn in Gilded Grimoire:
--   * Left: banners with a collection bar (owned / total).
--   * Middle: the banner's heroes as rarity-tinted cards with owned counts; ALL / OWNED / MISSING.
--   * Right: the selected hero: portrait, rarity badge, archetype and weapon, stat tiles (HP, ATK,
--     labor), the combat kit, drop rate (with God's Blessing luck), pity, what you own, and a
--     button that opens this banner at the Summoning Altar.
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
local function ownership(profile: any): { [string]: { Copies: number, BestStar: number, BestLevel: number } }
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

local function HeroIndex(props: { Profile: any, Width: number, OnClose: () -> () })
	local bannerKey, setBannerKey = React.useState("PERMANENT")
	local selected, setSelected = React.useState(nil :: string?)
	local filter, setFilter = React.useState("All" :: Filter)
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
	local owned = ownership(props.Profile)
	local luck = SummonLuck.ForProfile(props.Profile)
	local entry = BANNERS[1]
	for _, b in BANNERS do if b.Key == bannerKey then entry = b end end
	local banner = entry.Banner
	local heroIds = heroesOf(banner)
	local selectedId = selected
	if not selectedId or not table.find(heroIds, selectedId) then selectedId = heroIds[1] end

	-- Collection totals for the header.
	local totalHave, totalAll = 0, 0
	for _, b in BANNERS do
		for _, id in heroesOf(b.Banner) do
			totalAll += 1
			if owned[id] then totalHave += 1 end
		end
	end

	-- Left: banners ---------------------------------------------------------------------------
	local bannerChildren: { [string]: any } = {}
	for i, b in BANNERS do
		local ids = heroesOf(b.Banner)
		local have = 0
		for _, id in ids do if owned[id] then have += 1 end end
		local active = b.Key == bannerKey
		local tone = Tones[b.Tone]
		bannerChildren["B" .. i] = Panel({
			Class = "TextButton", Text = "", AutoButtonColor = false, Selectable = true, ref = if i == 1 then firstButton else nil,
			LayoutOrder = i, Size = UDim2.new(1, 0, 0, 112), Radius = 12,
			Top = if active then tone.Top else Tones.Deep.Top, Bottom = tone.Bottom, Rail = if active then TEXT.Gold else tone.Rail,
			[React.Event.Activated] = function()
				setBannerKey(b.Key)
				setSelected(nil)
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

	-- Middle: heroes in the banner ------------------------------------------------------------
	local heroChildren: { [string]: any } = {}
	local shown = 0
	for i, id in heroIds do
		local seed = HeroCatalog.Seeds[id]
		local mine = owned[id]
		local keep = filter == "All" or (filter == "Owned" and mine ~= nil) or (filter == "Missing" and mine == nil)
		if seed and keep then
			shown += 1
			local rarityColor = Theme.RarityColor(seed.Rarity)
			local isSel = id == selectedId
			heroChildren["H" .. i] = Panel({
				Class = "TextButton", Text = "", AutoButtonColor = false, Selectable = true, LayoutOrder = i, Radius = 12,
				Top = Tones.Deep.Top:Lerp(rarityColor, if isSel then 0.4 else 0.22), Bottom = Tones.Deep.Bottom, Rail = if isSel then TEXT.Gold else rarityColor,
				[React.Event.Activated] = function()
					setSelected(id)
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
	if shown == 0 then
		heroChildren.Empty = Body({ Size = UDim2.new(1, 0, 0, 40), TextSize = 14, TextColor3 = TEXT.Muted, TextXAlignment = Enum.TextXAlignment.Center,
			Text = if filter == "Owned" then "You don't own any heroes from this banner yet." else "You own every hero on this banner!" })
	end

	-- Right: details --------------------------------------------------------------------------
	local detail: { [string]: any } = {}
	local seed = selectedId and HeroCatalog.Seeds[selectedId]
	if seed then
		local tier = seed.Rarity or seed.BaseStar
		local rarityColor = Theme.RarityColor(tier)
		local probe = { TemplateId = seed.HeroId, Stars = seed.BaseStar, Level = 1, QualityScalar = 1, Archetype = seed.Archetype }
		local labor = StatFormulas.GetEffectiveLabor(probe, seed.PreferredFacility)
		local kit = Skills.GetSkillProfile(seed.HeroId, seed.Archetype)
		local rates = banner.Rates :: { number }
		local base = rates[tier] or 0
		local lucky = if luck > 0 then SummonLuck.ApplyLuck(rates, luck)[tier] else base
		local mine = owned[seed.HeroId]
		local mult = StatBalance.HeroRarityCombatMultiplier ^ (tier - 1)
		local function kitLine(def: any): string
			if not def then return "—" end
			return string.format("<b>%s</b> — %s", def.Name or "?", def.Description or string.format("%.0f%% damage", (def.DamageMultiplier or 1) * 100))
		end

		detail.Hero = e("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 150), BackgroundTransparency = 1 }, {
			Art = e("Frame", { Size = UDim2.fromOffset(140, 140), BackgroundColor3 = Color3.fromRGB(12, 8, 18), ClipsDescendants = true, ZIndex = 3 }, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
				Ring = e("UIStroke", { Color = rarityColor, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
				Portrait = e(Portrait, { TemplateId = seed.HeroId, Archetype = seed.Archetype, Stars = seed.BaseStar, Size = UDim2.fromScale(1, 1), Dark = mine == nil }),
			}),
			Name = Heavy({ Position = UDim2.fromOffset(152, 2), Size = UDim2.new(1, -152, 0, 30), MaxSize = 24, TextXAlignment = Enum.TextXAlignment.Left,
				Text = seed.DisplayName, ZIndex = 3 }),
			Rarity = Panel({ Position = UDim2.fromOffset(152, 38), Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, Radius = 13,
				Top = rarityColor, Bottom = rarityColor:Lerp(Color3.new(0, 0, 0), 0.35), Rail = Color3.new(1, 1, 1), ZIndex = 3 }, {
				Pad = e("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
				Text = Heavy({ AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 26), TextScaled = false, TextSize = 14, Outline = 2, Gold = false,
					Text = string.format("%s · %d★", string.upper(HeroCatalog.RarityName(tier)), seed.BaseStar), ZIndex = 5 }),
			}),
			Arch = IconAt(seed.Archetype, 30, { Position = UDim2.fromOffset(150, 72), ZIndex = 4 }),
			ArchText = Body({ Position = UDim2.fromOffset(186, 78), Size = UDim2.new(1, -186, 0, 18), TextSize = 14,
				Text = string.format("%s · %s", seed.Archetype, (string.gsub(ArtifactCatalog.ArchetypeWeaponType[seed.Archetype] or "?", "_", " & "))), ZIndex = 3 }),
			Owned = Body({ Position = UDim2.fromOffset(152, 104), Size = UDim2.new(1, -152, 0, 34), TextSize = 13, TextWrapped = true, TextTruncate = Enum.TextTruncate.None,
				TextColor3 = if mine then TEXT.Good else TEXT.Muted,
				Text = if mine then string.format("Owned x%d · best %d★ · highest Lv.%d", mine.Copies, mine.BestStar, mine.BestLevel) else "Not owned yet", ZIndex = 3 }),
		})
		detail.Stats = e("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1 }, {
			Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
			HP = statTile(1, "BASE HP", Components.Abbreviate(seed.NativeHP * mult), TEXT.Good),
			ATK = statTile(2, "BASE ATK", Components.Abbreviate(seed.NativeATK * mult), Color3.fromRGB(255, 150, 120)),
			Labor = statTile(3, "LABOR · " .. string.upper(Theme.FacilityNames[seed.PreferredFacility] or "ANY"), string.format("%.1f", labor), TEXT.Gold),
		})
		detail.Passive = section(3, "PASSIVE", seed.PassiveTraitName or "—", 40)
		detail.Basic = section(4, "BASIC ATTACK", kitLine(kit and kit.Basic), 52)
		detail.Special = section(5, "SPECIAL", kitLine(kit and kit.Special), 60)
		detail.Skill = section(6, "SKILL", kitLine(kit and kit.Skill), 60)
		detail.Odds = Panel({ LayoutOrder = 7, Size = UDim2.new(1, 0, 0, if tier == banner.MaxStar then 78 else 58), Radius = 10,
			Top = Tones.Violet.Top, Bottom = Tones.Violet.Bottom, Rail = Tones.Violet.Rail }, {
			Title = Heavy({ Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 18), MaxSize = 14, Outline = 1.8, TextXAlignment = Enum.TextXAlignment.Left,
				Text = "DROP RATE", ZIndex = 3 }),
			Rate = Body({ Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -24, 0, 18), TextSize = 14, ZIndex = 3,
				Text = if luck > 0 then string.format("%.2f%%  →  <font color=\"#78FF8C\"><b>%.2f%%</b></font> with God's Blessing", base * 100, lucky * 100)
					else string.format("<b>%.2f%%</b> per summon", base * 100) }),
			Pity = if tier == banner.MaxStar then Body({ Position = UDim2.fromOffset(12, 52), Size = UDim2.new(1, -24, 0, 18), TextSize = 13, TextColor3 = TEXT.Gold,
				Text = string.format("Guaranteed within %d summons (pity)", banner.MaxPity), ZIndex = 3 }) else nil,
		})
		detail.Summon = button({ LayoutOrder = 8, Size = UDim2.new(1, 0, 0, 46), ZIndex = 3,
			[React.Event.Activated] = function()
				props.OnClose()
				if _G.OpenFacilityHUD then _G.OpenFacilityHUD("Summoning") end
			end }, "Action", "SUMMON ON " .. string.upper(banner.Title), 15)
	end

	-- Columns --------------------------------------------------------------------------------
	local filterChips: { [string]: any } = { Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) }
	for order, key in { "All", "Owned", "Missing" } do
		filterChips[key] = button({ LayoutOrder = order, Size = UDim2.fromOffset(if key == "Missing" then 84 else 70, 26), ZIndex = 4,
			[React.Event.Activated] = function() setFilter(key :: Filter) end }, if filter == key then "Gold" else "Slate", string.upper(key), 12)
	end

	local leftCol = column(1, if narrow then UDim.new(1, 0) else UDim.new(0.22, -8), "BANNERS", nil,
		scroller(bannerChildren, e("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder })))
	local midCol = column(2, if narrow then UDim.new(1, 0) else UDim.new(0.42, -8), string.upper(banner.Title), {
		Filter = e("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), Size = UDim2.fromOffset(240, 26), BackgroundTransparency = 1, ZIndex = 3 }, filterChips),
	}, scroller(heroChildren, e("UIGridLayout", { CellSize = UDim2.fromOffset(150, 172), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder })))
	local rightCol = column(3, if narrow then UDim.new(1, 0) else UDim.new(0.36, 0), "HERO DETAILS", nil,
		scroller(detail, e("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder })))

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

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(6, 5, 10),
		BackgroundTransparency = 0.35,
		Active = true,
		ZIndex = 20,
	}, {
		Window = Panel({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0.92, 0, 0.88, 0),
			Radius = 16,
			Active = true,
		}, {
			Max = e("UISizeConstraint", { MaxSize = Vector2.new(1200, 740) }),
			TitleIcon = IconAt("Index", 50, { Position = UDim2.fromOffset(18, 10), ZIndex = 3 }),
			Title = Heavy({ Position = UDim2.fromOffset(78, 12), Size = UDim2.fromOffset(320, 30), MaxSize = 28, TextXAlignment = Enum.TextXAlignment.Left,
				Text = "HERO INDEX", ZIndex = 3 }),
			Collected = Body({ Position = UDim2.fromOffset(80, 42), Size = UDim2.fromOffset(320, 16), TextSize = 13, TextColor3 = TEXT.Muted, ZIndex = 3,
				Text = string.format("Collected %d / %d heroes", totalHave, totalAll) }),
			CollectedBar = if not narrow then bar({ Position = UDim2.fromOffset(410, 30), Size = UDim2.fromOffset(220, 14), ZIndex = 3 },
				totalHave / math.max(1, totalAll), TEXT.Gold) else nil,
			Back = if narrow and step ~= "banners" then button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -76, 0, 16), Size = UDim2.fromOffset(96, 38), ZIndex = 4,
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
