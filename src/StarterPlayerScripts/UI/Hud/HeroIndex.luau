--!strict
-- StarterPlayerScripts/UI/Hud/HeroIndex.luau
-- Hero Index (Phase 5 §4.7): banners (left), the heroes in the selected banner (middle) and details
-- for the selected hero (right). Client-only: catalog data plus the synced profile. Narrow screens
-- show one column at a time with a back button. ButtonB / the close button closes it.

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
local Portrait = require(script.Parent:WaitForChild("Portrait"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local Icons = require(script.Parent:WaitForChild("Icons"))
local Components = require(script.Parent:WaitForChild("Components"))

local e = React.createElement
local C = Theme.Colors
local text = Components.Text
local corner = Components.Corner
local stroke = Components.Stroke

local BANNERS = {
	{ Key = "PERMANENT", Banner = HeroCatalog.PermanentBanner, Tag = "PERMANENT" },
	{ Key = "LIMITED", Banner = HeroCatalog.LimitedBanner, Tag = "LIMITED" },
}

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

local function column(name: string, order: number, width: UDim, children: { [string]: any })
	children.Corner = corner(8)
	children.Stroke = stroke(C.Border, 1, 0.3)
	return e("Frame", {
		Name = name,
		LayoutOrder = order,
		Size = UDim2.new(width, UDim.new(1, 0)),
		BackgroundColor3 = C.PanelSoft,
		BackgroundTransparency = 0.15,
	}, children)
end

local function scroller(children: { [string]: any }, grid: boolean?)
	children.Layout = if grid
		then e("UIGridLayout", { CellSize = UDim2.fromOffset(104, 132), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder })
		else e("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	children.Padding = e("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) })
	return e("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 1, -30),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, children)
end

local function heading(label: string)
	return text({ Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 20), TextSize = 13, TextColor3 = C.Gold, Text = label })
end

local function detailLine(order: number, label: string, value: string, height: number?)
	return text({
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, height or 16),
		TextSize = 12,
		Font = Theme.FontBody,
		TextWrapped = (height or 16) > 16,
		TextTruncate = Enum.TextTruncate.None,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = string.format("<font color=\"#AAA0BE\">%s</font>  %s", label, value),
	})
end

local function HeroIndex(props: { Profile: any, Width: number, OnClose: () -> () })
	local bannerKey, setBannerKey = React.useState("PERMANENT")
	local selected, setSelected = React.useState(nil :: string?)
	local ownedOnly, setOwnedOnly = React.useState(false)
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

	-- Left: banners.
	local bannerChildren: { [string]: any } = {}
	for i, b in BANNERS do
		local ids = heroesOf(b.Banner)
		local have = 0
		for _, id in ids do if owned[id] then have += 1 end end
		local active = b.Key == bannerKey
		bannerChildren["B" .. i] = e("TextButton", {
			ref = if i == 1 then firstButton else nil,
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 64),
			BackgroundColor3 = if active then Color3.fromRGB(46, 36, 70) else C.Panel,
			Text = "",
			AutoButtonColor = true,
			Selectable = true,
			[React.Event.Activated] = function()
				setBannerKey(b.Key)
				setSelected(nil)
				if narrow then setStep("heroes") end
			end,
		}, {
			Corner = corner(6),
			Stroke = stroke(if active then C.Gold else C.Border, if active then 1.6 else 1),
			Title = text({ Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 18), TextSize = 14, Text = b.Banner.Title }),
			Tag = text({ Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -20, 0, 14), TextSize = 10, TextColor3 = C.Muted,
				Text = string.format("%s · %d TIERS", b.Tag, #ids) }),
			Owned = text({ Position = UDim2.fromOffset(10, 42), Size = UDim2.new(1, -20, 0, 14), TextSize = 11, TextColor3 = C.Green, Font = Theme.FontBody,
				Text = string.format("%d/%d owned", have, #ids) }),
		})
	end

	-- Middle: heroes in the banner.
	local heroChildren: { [string]: any } = {}
	for i, id in heroIds do
		local seed = HeroCatalog.Seeds[id]
		local mine = owned[id]
		if seed and (not ownedOnly or mine) then
			local rarityColor = Theme.RarityColor(seed.Rarity)
			heroChildren["H" .. i] = e("TextButton", {
				LayoutOrder = i,
				BackgroundColor3 = if id == selectedId then Color3.fromRGB(46, 36, 70) else C.Panel,
				Text = "",
				AutoButtonColor = true,
				Selectable = true,
				[React.Event.Activated] = function()
					setSelected(id)
					if narrow then setStep("details") end
				end,
			}, {
				Corner = corner(6),
				Stroke = stroke(rarityColor, if id == selectedId then 2.4 else 1.4),
				Art = e("Frame", { Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, 82), BackgroundColor3 = Color3.fromRGB(12, 10, 18), ClipsDescendants = true }, {
					Corner = corner(4),
					Portrait = e(Portrait, { TemplateId = id, Archetype = seed.Archetype, Stars = seed.BaseStar, Size = UDim2.fromScale(1, 1), Dark = mine == nil }),
				}),
				Name = text({ Position = UDim2.fromOffset(6, 92), Size = UDim2.new(1, -12, 0, 15), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center,
					Text = seed.DisplayName }),
				Tier = text({ Position = UDim2.fromOffset(6, 108), Size = UDim2.new(1, -12, 0, 13), TextSize = 10, Font = Theme.FontBody,
					TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = rarityColor,
					Text = string.format("%s %d★", HeroCatalog.RarityName(seed.Rarity), seed.BaseStar) }),
				Count = if mine then text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(28, 16),
					BackgroundTransparency = 0, BackgroundColor3 = C.Green, TextColor3 = C.Panel, TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Center, Text = "×" .. mine.Copies, ZIndex = 3 }) else nil,
			})
		end
	end

	-- Right: details for the selected hero.
	local detail: { [string]: any } = {}
	local seed = selectedId and HeroCatalog.Seeds[selectedId]
	if seed then
		local tier = seed.Rarity or seed.BaseStar
		local probe = { TemplateId = seed.HeroId, Stars = seed.BaseStar, Level = 1, QualityScalar = 1, Archetype = seed.Archetype }
		local labor = StatFormulas.GetEffectiveLabor(probe, seed.PreferredFacility)
		local kit = Skills.GetSkillProfile(seed.HeroId, seed.Archetype)
		local rates = banner.Rates :: { number }
		local base = rates[tier] or 0
		local lucky = if luck > 0 then SummonLuck.ApplyLuck(rates, luck)[tier] else base
		local mine = owned[seed.HeroId]
		local function kitLine(def: any): string
			if not def then return "—" end
			return string.format("<b>%s</b> — %s", def.Name or "?", def.Description or string.format("%.0f%% damage", (def.DamageMultiplier or 1) * 100))
		end
		local order = 0
		local function add(label: string, value: string, height: number?)
			order += 1
			detail["D" .. order] = detailLine(order, label, value, height)
		end
		order += 1
		detail.Art = e("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 150), BackgroundColor3 = Color3.fromRGB(12, 10, 18), ClipsDescendants = true }, {
			Corner = corner(6),
			Ring = stroke(Theme.RarityColor(tier), 2),
			Portrait = e(Portrait, { TemplateId = seed.HeroId, Archetype = seed.Archetype, Stars = seed.BaseStar, Size = UDim2.fromScale(1, 1), Dark = mine == nil }),
		})
		order += 1
		detail.Name = text({ LayoutOrder = order, Size = UDim2.new(1, 0, 0, 22), TextSize = 18, Font = Theme.FontBlack, Text = seed.DisplayName })
		add("Rarity", string.format("<font color=\"#%s\">%s</font> (tier %d) · summoned at %d★", Theme.RarityColor(tier):ToHex(), HeroCatalog.RarityName(tier), tier, seed.BaseStar))
		add("Archetype", string.format("%s · %s", seed.Archetype, ArtifactCatalog.ArchetypeWeaponType[seed.Archetype] or "?"))
		add("Native HP / ATK", string.format("%s / %s  (rarity ×%.2f)", Components.Abbreviate(seed.NativeHP), Components.Abbreviate(seed.NativeATK), StatBalance.HeroRarityCombatMultiplier ^ (tier - 1)))
		add("Labor", string.format("%.1f at %s", labor, Theme.FacilityNames[seed.PreferredFacility] or "—"))
		add("Passive", seed.PassiveTraitName, 30)
		add("Basic", kitLine(kit and kit.Basic), 30)
		add("Special", kitLine(kit and kit.Special), 44)
		add("Skill", kitLine(kit and kit.Skill), 44)
		add("Drop rate", if luck > 0
			then string.format("%.2f%% → <font color=\"#4ADE80\">%.2f%%</font> with Blessing", base * 100, lucky * 100)
			else string.format("%.2f%%", base * 100))
		if tier == banner.MaxStar then
			add("Pity", string.format("Guaranteed within %d pulls", banner.MaxPity))
		end
		add("Owned", if mine then string.format("×%d · best %d★ · highest Lv.%d", mine.Copies, mine.BestStar, mine.BestLevel) else "Not yet")
	end

	local leftCol = column("Banners", 1, if narrow then UDim.new(1, 0) else UDim.new(0.22, -8), {
		Heading = heading("BANNERS"),
		List = scroller(bannerChildren),
	})
	local midCol = column("Heroes", 2, if narrow then UDim.new(1, 0) else UDim.new(0.43, -8), {
		Heading = heading(banner.Title),
		Filter = e("TextButton", {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 5), Size = UDim2.fromOffset(84, 20),
			BackgroundColor3 = C.Panel, Text = if ownedOnly then "OWNED" else "ALL", TextColor3 = C.Text, TextSize = 11, Font = Theme.Font,
			[React.Event.Activated] = function() setOwnedOnly(not ownedOnly) end,
		}, { Corner = corner(4), Stroke = stroke(C.Border) }),
		Grid = scroller(heroChildren, true),
	})
	local rightCol = column("Details", 3, if narrow then UDim.new(1, 0) else UDim.new(0.35, 0), {
		Heading = heading("HERO DETAILS"),
		List = scroller(detail),
	})

	local body: { [string]: any }
	if narrow then
		body = {
			Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal }),
			Only = if step == "banners" then leftCol elseif step == "heroes" then midCol else rightCol,
		}
	else
		body = {
			Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
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
		Window = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0.92, 0, 0.86, 0),
			BackgroundColor3 = C.Panel,
		}, {
			Max = e("UISizeConstraint", { MaxSize = Vector2.new(1180, 720) }),
			Corner = corner(12),
			Stroke = stroke(C.Gold, 1.6, 0.2),
			TitleIcon = e("Frame", { Position = UDim2.fromOffset(14, 6), Size = UDim2.fromOffset(36, 36), BackgroundTransparency = 1, ZIndex = 3 }, {
				Art = e(Icons.Icon, { Name = "Index", Size = 36 }),
			}),
			Title = text({ Position = UDim2.fromOffset(58, 10), Size = UDim2.new(1, -240, 0, 28), TextSize = 22, Font = Theme.FontBlack, TextColor3 = C.Gold,
				Text = "HERO INDEX" }),
			Back = if narrow and step ~= "banners" then e("TextButton", {
				AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -64, 0, 10), Size = UDim2.fromOffset(80, 30),
				BackgroundColor3 = C.PanelSoft, Text = "‹ BACK", TextColor3 = C.Text, TextSize = 13, Font = Theme.Font,
				[React.Event.Activated] = function() setStep(if step == "details" then "heroes" else "banners") end,
			}, { Corner = corner(6) }) else nil,
			Close = e("TextButton", {
				AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.fromOffset(44, 30),
				BackgroundColor3 = Color3.fromRGB(70, 30, 36), Text = "✕", TextColor3 = C.Text, TextSize = 16, Font = Theme.Font,
				[React.Event.Activated] = function() props.OnClose() end,
			}, { Corner = corner(6) }),
			Body = e("Frame", { Position = UDim2.fromOffset(12, 48), Size = UDim2.new(1, -24, 1, -60), BackgroundTransparency = 1 }, body),
		}),
	})
end

return HeroIndex
