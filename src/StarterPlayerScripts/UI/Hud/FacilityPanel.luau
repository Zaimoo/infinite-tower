--!strict
-- StarterPlayerScripts/UI/Hud/FacilityPanel.luau
-- Phase 5 §4.5: one Gilded Grimoire panel for every support facility (Guard Post, Market, Training
-- Grounds, God's Blessing).
--   * Header: drawn facility icon, title, level, worker count and the next Fortress Tree node.
--   * Bonus: the live figure in big inked numbers, a hover preview, and a caption/value breakdown.
--   * Workers: large slots with portrait, labor and a +25% badge, plus REMOVE. An empty slot
--     points at the list; the next locked slot opens the Fortress Tree.
--   * Hero list: labor here, rarity and status, with one clear action per row (ASSIGN, MOVE HERE
--     with a confirm step, RESTING or FULL). Filters: All / Bench / Best fit.
-- Assignments go through AssignHeroRole; every reply is shown. No upgrade button: facilities are
-- levelled only in the Fortress Tree.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local FacilityConfig = require(Shared:WaitForChild("Config"):WaitForChild("FacilityConfig"))
local HeroCatalog = require(Shared:WaitForChild("Config"):WaitForChild("HeroCatalog"))
local TreeConfig = require(Shared:WaitForChild("Config"):WaitForChild("FortressTreeConfig"))
local FortressTree = require(Shared:WaitForChild("Util"):WaitForChild("FortressTree"))
local StatFormulas = require(Shared:WaitForChild("Util"):WaitForChild("StatFormulas"))
local SummonLuck = require(Shared:WaitForChild("Util"):WaitForChild("SummonLuck"))
local Grimoire = require(Shared:WaitForChild("Util"):WaitForChild("GildedGrimoire"))

local Theme = require(script.Parent:WaitForChild("Theme"))
local Portrait = require(script.Parent:WaitForChild("Portrait"))
local Components = require(script.Parent:WaitForChild("Components"))

local AssignHeroRole = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TycoonGachaRemotes"):WaitForChild("AssignHeroRole") :: RemoteFunction

local e = React.createElement
local Panel = Components.Panel
local Heavy = Components.HeavyLabel
local Body = Components.Body
local IconAt = Components.IconAt
local Tones = Grimoire.Tones
local TEXT = Grimoire.Text
local INK = Grimoire.Ink
local CLOSE_ACTION = "FacilityPanelClose"

local FACILITIES = {
	GuardPost = { Title = "OUTSKIRTS GUARD POST", Tag = "FACILITY_GUARD_POST", Worker = "Adventurer", Icon = "Camp", Tone = "Teal", Branch = "Outskirts",
		Blurb = "Adventurers patrol the outskirts and earn Gold, even while you're offline." },
	Market = { Title = "THE MARKET", Tag = "FACILITY_MARKET", Worker = "Merchant", Icon = "Market", Tone = "Bronze", Branch = "Commerce",
		Blurb = "Merchants raise the Gold you bring back from the tower." },
	TrainingGrounds = { Title = "TRAINING GROUNDS", Tag = "FACILITY_TRAINING", Worker = "Trainer", Icon = "Power", Tone = "Crimson", Branch = "Martial",
		Blurb = "Trainers drill your squad: more ATK and HP for every deployed hero." },
	GodsBlessing = { Title = "GOD'S BLESSING", Tag = "FACILITY_GODS_BLESSING", Worker = "Acolyte", Icon = "Blessing", Tone = "Violet", Branch = "Divine",
		Blurb = "Acolytes pray for luck: better odds on every hero summon." },
}

local ASSIGNMENT_LABELS: { [string]: string } = {
	BENCHED = "Bench",
	FACILITY_GUARD_POST = "Guard Post",
	FACILITY_MARKET = "Market",
	FACILITY_TRAINING = "Training",
	FACILITY_GODS_BLESSING = "Blessing",
}

type Filter = "All" | "Bench" | "Best"

local function assignmentLabel(assignment: string?): string
	local slot = string.match(assignment or "", "^SQUAD_SLOT_(%d+)$")
	if slot then return "Squad · Slot " .. slot end
	return ASSIGNMENT_LABELS[assignment or "BENCHED"] or "Bench"
end

local function hasSynergy(facility: string, hero: any): boolean
	local seed = HeroCatalog.Seeds[hero.TemplateId]
	local pref = seed and seed.PreferredFacility or ""
	local tag = FACILITIES[facility].Tag
	return pref == "ALL" or pref == tag or (tag == "FACILITY_GODS_BLESSING" and (hero.Archetype or (seed and seed.Archetype)) == "Healer")
end

local function restingSeconds(hero: any): number
	return math.max(0, (hero.ComaUntilTimestamp or 0) - os.time())
end

local function awakeLabor(profile: any, uuids: { string }, tag: string): number
	local sum = 0
	for _, uuid in uuids do
		local hero = profile.Heroes[uuid]
		if hero and restingSeconds(hero) == 0 then
			sum += StatFormulas.GetEffectiveLabor(hero, tag)
		end
	end
	return sum
end

-- The facility's big number for a given total worker labor, plus a formatter and breakdown rows
-- ({ caption, value }).
local function bonusFor(facility: string, profile: any, level: number, labor: number): (number, string, { { string } })
	local perks = FortressTree.PerkBonuses(profile.FortressTree)
	if facility == "GuardPost" then
		local tier = profile.HighestClearedBiomeBoss or 0
		local rate = StatFormulas.GetPassiveGoldRate(level, labor, tier, perks)
		local cfg = FacilityConfig.UpgradeTable.GuardPost[level]
		local cap = if cfg then (cfg.MaxOfflineMinutes + perks.OfflineMinutes) / 60 else 0
		return rate, string.format("%s Gold/min", Components.Abbreviate(rate)), {
			{ "Base rate" .. (if perks.GuardPostRate > 0 then " (Long Patrols)" else ""), string.format("%d Gold/min", math.round((cfg and cfg.BaseGoldPerMin or 0) * (1 + perks.GuardPostRate))) },
			{ "Adventurer labor", string.format("%.1f × 0.85", labor) },
			{ "Biome Boss bonus", string.format("+%d%% (tier %d)", tier * 15, tier) },
			{ "Offline earnings", string.format("%dh cap · %d%%", cap, math.round((cfg and cfg.OfflineEfficiency or 0) * 100)) },
		}
	elseif facility == "Market" then
		local mult = StatFormulas.GetMarketLootMultiplier(level, labor, perks)
		local cfg = FacilityConfig.UpgradeTable.Market[level]
		return mult, string.format("+%.1f%% tower loot", (mult - 1) * 100), {
			{ "Level bonus" .. (if perks.MarketBonus > 0 then " (Appraiser's Eye)" else ""), string.format("+%.0f%%", ((cfg and cfg.BaseBonus or 0) + perks.MarketBonus) * 100) },
			{ "Merchant labor", string.format("%.1f × 0.5%%", labor) },
		}
	elseif facility == "TrainingGrounds" then
		local mult = StatFormulas.GetTrainingCombatMultiplier(level, labor, perks)
		local cfg = FacilityConfig.UpgradeTable.TrainingGrounds[level]
		local before = StatFormulas.GetSquadPower(profile, 1)
		local after = StatFormulas.GetSquadPower(profile, mult)
		return mult, string.format("+%.1f%% ATK & HP", (mult - 1) * 100), {
			{ "Level bonus" .. (if perks.TrainingBonus > 0 then " (Veteran Drills)" else ""), string.format("+%.0f%%", ((cfg and cfg.BaseBonus or 0) + perks.TrainingBonus) * 100) },
			{ "Trainer labor", string.format("%.1f × 0.4%%", labor) },
			{ "Squad Power gained", "+" .. Components.Abbreviate(after - before) },
		}
	else
		local luck = SummonLuck.Luck(level, labor, perks.BlessingLuck)
		local cfg = FacilityConfig.UpgradeTable.GodsBlessing[level]
		local rates = HeroCatalog.LimitedBanner.Rates :: { number }
		local top = #rates
		return luck, string.format("+%.1f%% summon luck", luck * 100), {
			{ "Base luck", string.format("+%.0f%%", (cfg and cfg.BaseLuck or 0) * 100) },
			{ "Acolyte labor" .. (if perks.BlessingLuck > 0 then " (Saint's Favor +3%)" else ""), string.format("%.1f × 0.4%%", labor) },
			{ "Luck cap", string.format("+%d%%", math.round(FacilityConfig.Constants.MaxSummonLuck * 100)) },
			{ "Astrea (Mythical) odds", string.format("%.2f%% → %.3f%%", rates[top] * 100, SummonLuck.ApplyLuck(rates, luck)[top] * 100) },
		}
	end
end

local function nextNode(facility: string, tree: any): any
	for _, node in TreeConfig.Nodes do
		if node.Facility == facility and not FortressTree.Owns(tree, node.Id) then
			return node
		end
	end
	return nil
end

-- A themed button: toned panel, label as a child (a fill gradient would tint text on the button).
local function button(props: { [string]: any }, tone: string, text: string, textSize: number?)
	local t = Tones[tone] or Tones.Slate
	local inst: { [string]: any } = { Class = "TextButton", Text = "", AutoButtonColor = false, Radius = 10, Top = t.Top, Bottom = t.Bottom, Rail = t.Rail, Selectable = true }
	for k, v in props do inst[k] = v end
	return Panel(inst, {
		Label = Heavy({ Position = UDim2.fromOffset(4, 2), Size = UDim2.new(1, -8, 1, -4), MaxSize = textSize or 15, Outline = 2, Gold = false,
			Text = text, ZIndex = (props.ZIndex or 1) + 2 }),
	})
end

-- A small inked caption + value row for the bonus breakdown.
local function breakdownRow(order: number, caption: string, value: string)
	return e("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1 }, {
		Caption = Body({ Size = UDim2.new(0.58, 0, 1, 0), TextSize = 14, TextColor3 = TEXT.Muted, Text = caption }),
		Value = Body({ Position = UDim2.fromScale(0.58, 0), Size = UDim2.new(0.42, 0, 1, 0), TextSize = 14, TextColor3 = TEXT.Parchment,
			TextXAlignment = Enum.TextXAlignment.Right, Text = value, FontFace = Grimoire.Fonts.Number }),
	})
end

local function FacilityPanel(props: { Facility: string, Profile: any, Width: number, OnClose: () -> () })
	local info = FACILITIES[props.Facility]
	local hovered, setHovered = React.useState(nil :: string?)
	local confirming, setConfirming = React.useState(nil :: string?)
	local message, setMessage = React.useState("")
	local isError, setIsError = React.useState(false)
	local busy, setBusy = React.useState(false)
	local filter, setFilter = React.useState("All" :: Filter)

	React.useEffect(function()
		ContextActionService:BindAction(CLOSE_ACTION, function(_, state)
			if state == Enum.UserInputState.Begin then props.OnClose() end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.ButtonB)
		return function() ContextActionService:UnbindAction(CLOSE_ACTION) end
	end, {})

	local profile = props.Profile
	if not info or not profile then return nil end
	local data = profile.Facilities and profile.Facilities[props.Facility] or { Level = 0, AssignedHeroUUIDs = {} }
	local level = data.Level or 0
	local perks = FortressTree.PerkBonuses(profile.FortressTree)
	local maxWorkers = StatFormulas.GetFacilityMaxWorkers(props.Facility, level, perks)
	local assigned = data.AssignedHeroUUIDs or {}
	local labor = awakeLabor(profile, assigned, info.Tag)
	local value, figure, breakdown = bonusFor(props.Facility, profile, level, labor)
	local levelCfg = (FacilityConfig.UpgradeTable :: any)[props.Facility][level]
	local narrow = props.Width < 820
	local full = #assigned >= maxWorkers
	local tone = Tones[info.Tone] or Tones.Violet

	local function say(text: string, bad: boolean?)
		setMessage(text)
		setIsError(bad == true)
	end

	local function request(uuid: string, target: string)
		if busy then return end
		setBusy(true)
		say("Saving…")
		task.spawn(function()
			local ok, success, msg = pcall(function() return AssignHeroRole:InvokeServer(uuid, target) end)
			setBusy(false)
			setConfirming(nil)
			if not ok then
				say("Couldn't reach the server. Try again.", true)
			elseif success then
				local hero = profile.Heroes[uuid]
				say(if target == "BENCHED" then string.format("%s returned to the bench.", hero and hero.DisplayName or "Hero")
					else string.format("%s now works here.", hero and hero.DisplayName or "Hero"))
			else
				say(tostring(msg or "Unable to assign that hero."), true)
			end
		end)
	end

	-- What the big figure becomes if a hero joined (while a slot is free).
	local function gainText(hero: any): string
		local after = bonusFor(props.Facility, profile, level, labor + StatFormulas.GetEffectiveLabor(hero, info.Tag))
		if props.Facility == "GuardPost" then
			return string.format("+%s Gold/min", Components.Abbreviate(after - value))
		end
		return string.format("+%.1f%%", (after - value) * 100)
	end
	local hoverHero = hovered and profile.Heroes[hovered]
	local preview = if hoverHero and hoverHero.Assignment ~= info.Tag and not full and restingSeconds(hoverHero) == 0 then gainText(hoverHero) else ""

	-- Header ----------------------------------------------------------------
	local synergy = table.concat(FacilityConfig.FacilityArchetypeSynergies[props.Facility] or {}, ", ")
	local nxt = nextNode(props.Facility, profile.FortressTree)
	local nextText = if nxt
		then string.format("NEXT: %s · %s Gold%s", string.upper(nxt.Name), Components.Abbreviate(nxt.Gold), if nxt.FloorGate > (profile.HighestClearedFloor or 0) then string.format(" · Floor %d", nxt.FloorGate) else "")
		else "ALL NODES BUILT"
	local header = e("Frame", { Position = UDim2.fromOffset(20, 14), Size = UDim2.new(1, -96, 0, 84), BackgroundTransparency = 1, ZIndex = 24 }, {
		Icon = IconAt(info.Icon, 76, { Position = UDim2.fromOffset(0, 2), ZIndex = 25 }),
		Title = Heavy({ Position = UDim2.fromOffset(90, 2), Size = UDim2.new(1, -90, 0, 34), MaxSize = 30, TextXAlignment = Enum.TextXAlignment.Left, Text = info.Title, ZIndex = 25 }),
		Level = Panel({ Position = UDim2.fromOffset(90, 42), Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, Radius = 14,
			Top = tone.Top, Bottom = tone.Bottom, Rail = tone.Rail, ZIndex = 25 }, {
			Pad = e("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }),
			Text = Heavy({ AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 28), TextScaled = false, TextSize = 15, Outline = 2, Gold = false, ZIndex = 27,
				Text = string.format("LV.%d · %s", level, string.upper(levelCfg and levelCfg.VisualTitle or "Unbuilt")) }),
		}),
		Blurb = Body({ Position = UDim2.fromOffset(90, 72), Size = UDim2.new(1, -90, 0, 16), TextSize = 13, TextColor3 = TEXT.Muted, Text = info.Blurb, ZIndex = 25 }),
	})

	-- Bonus panel -------------------------------------------------------------
	local rows: { [string]: any } = { Layout = e("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }) }
	for i, row in breakdown do
		rows["R" .. i] = breakdownRow(i, row[1], row[2])
	end
	local bonusHeight = 118 + #breakdown * 24
	local bonus = Panel({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, bonusHeight), Top = Tones.Deep.Top, Bottom = Tones.Deep.Bottom, Rail = tone.Rail }, {
		Caption = Heavy({ Position = UDim2.fromOffset(18, 12), Size = UDim2.new(1, -36, 0, 18), MaxSize = 15, Outline = 2, TextXAlignment = Enum.TextXAlignment.Left,
			Text = "CURRENT BONUS", ZIndex = 3 }),
		Figure = e("TextLabel", { Position = UDim2.fromOffset(18, 34), Size = UDim2.new(1, -36, 0, 44), BackgroundTransparency = 1, FontFace = Grimoire.Fonts.Number,
			TextScaled = true, TextColor3 = TEXT.Gold, TextXAlignment = Enum.TextXAlignment.Left, Text = figure, ZIndex = 3 }, {
			Limit = e("UITextSizeConstraint", { MaxTextSize = 36 }),
			Ink = e("UIStroke", { Color = INK, Thickness = 2.6, LineJoinMode = Enum.LineJoinMode.Round }),
		}),
		Preview = if preview ~= "" then Panel({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 12), Size = UDim2.fromOffset(0, 26),
			AutomaticSize = Enum.AutomaticSize.X, Radius = 13, Top = Color3.fromRGB(40, 120, 70), Bottom = Color3.fromRGB(16, 60, 34), Rail = TEXT.Good, ZIndex = 4 }, {
			Pad = e("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
			Text = Heavy({ AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 26), TextScaled = false, TextSize = 14, Outline = 2, Gold = false, Text = preview, ZIndex = 6 }),
		}) else nil,
		Note = Body({ Position = UDim2.fromOffset(18, 80), Size = UDim2.new(1, -36, 0, 16), TextSize = 12, TextColor3 = TEXT.Muted, ZIndex = 3,
			Text = string.format("%d / %d %ss working · labor %.1f%s", #assigned, maxWorkers, info.Worker, labor, if synergy ~= "" then " · +25% for " .. synergy else "") }),
		Lines = e("Frame", { Position = UDim2.fromOffset(18, 104), Size = UDim2.new(1, -36, 1, -112), BackgroundTransparency = 1, ZIndex = 3 }, rows),
	})

	-- Worker slots ----------------------------------------------------------
	local slots: { [string]: any } = { Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) }
	for i = 1, math.min(math.max(maxWorkers, 1) + 1, 5) do
		local uuid = assigned[i]
		local hero = uuid and profile.Heroes[uuid]
		local size = UDim2.fromOffset(104, 160)
		if i <= maxWorkers and hero then
			local rarity = StatFormulas.GetHeroRarity(hero)
			local resting = restingSeconds(hero)
			slots["S" .. i] = Panel({ LayoutOrder = i, Size = size, Radius = 10, Top = Tones.Violet.Top, Bottom = Tones.Violet.Bottom, Rail = Theme.RarityColor(rarity) }, {
				Art = e("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(72, 72),
					BackgroundColor3 = Color3.fromRGB(14, 10, 22), ClipsDescendants = true, ZIndex = 3 }, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
					Ring = e("UIStroke", { Color = Theme.RarityColor(rarity), Thickness = 2.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
					Portrait = e(Portrait, { TemplateId = hero.TemplateId, Archetype = hero.Archetype, Stars = hero.Stars }),
				}),
				Bonus = if hasSynergy(props.Facility, hero) then IconAt("Spark", 22, { Position = UDim2.fromOffset(4, 2), ZIndex = 6 }) else nil,
				Name = Heavy({ Position = UDim2.fromOffset(4, 82), Size = UDim2.new(1, -8, 0, 18), MaxSize = 13, Outline = 1.8, Gold = false, Text = hero.DisplayName, ZIndex = 4 }),
				Labor = Body({ Position = UDim2.fromOffset(4, 100), Size = UDim2.new(1, -8, 0, 16), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4,
					TextColor3 = if resting > 0 then TEXT.Bad else TEXT.Gold,
					Text = if resting > 0 then string.format("Resting %ds", resting) else string.format("%.1f labor", StatFormulas.GetEffectiveLabor(hero, info.Tag)) }),
				Remove = button({ Position = UDim2.fromOffset(8, 122), Size = UDim2.new(1, -16, 0, 30), ZIndex = 4,
					[React.Event.Activated] = function() request(uuid, "BENCHED") end }, "Slate", "REMOVE", 13),
			})
		elseif i <= maxWorkers then
			slots["S" .. i] = Panel({ Class = "TextButton", Text = "", AutoButtonColor = false, LayoutOrder = i, Size = size, Radius = 10,
				Top = Tones.Deep.Top, Bottom = Tones.Deep.Bottom, Rail = TEXT.Gold,
				[React.Event.Activated] = function() say("Pick a hero from the list on the right to fill this slot.") end }, {
				Plus = Heavy({ Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 50), MaxSize = 48, Text = "+", ZIndex = 4 }),
				Hint = Body({ Position = UDim2.fromOffset(6, 92), Size = UDim2.new(1, -12, 0, 40), TextSize = 12, TextWrapped = true, TextTruncate = Enum.TextTruncate.None,
					TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = TEXT.Muted, Text = "Free slot\npick a hero", ZIndex = 4 }),
			})
		else
			-- The next slot this facility can open, through a level or perk node.
			slots["S" .. i] = Panel({ Class = "TextButton", Text = "", AutoButtonColor = false, LayoutOrder = i, Size = size, Radius = 10,
				Top = Tones.Slate.Top, Bottom = Tones.Slate.Bottom, Rail = Tones.Slate.Rail,
				[React.Event.Activated] = function()
					props.OnClose()
					if _G.OpenFacilityHUD then _G.OpenFacilityHUD("FortressTree") end
				end }, {
				Padlock = IconAt("Lock", 40, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 24), ZIndex = 4 }),
				Lock = Body({ Position = UDim2.fromOffset(6, 74), Size = UDim2.new(1, -12, 0, 56), TextSize = 12, TextWrapped = true, TextTruncate = Enum.TextTruncate.None,
					TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = TEXT.Muted, Text = "More slots in the\nFortress Tree", ZIndex = 4 }),
			})
		end
	end
	local slotPanel = Panel({ LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 214), Top = Tones.Deep.Top, Bottom = Tones.Deep.Bottom, Rail = Tones.Deep.Rail }, {
		Caption = Heavy({ Position = UDim2.fromOffset(18, 12), Size = UDim2.new(1, -36, 0, 18), MaxSize = 15, Outline = 2, TextXAlignment = Enum.TextXAlignment.Left,
			Text = string.format("WORKERS  %d/%d", #assigned, maxWorkers), ZIndex = 3 }),
		Row = e("ScrollingFrame", { Position = UDim2.fromOffset(16, 40), Size = UDim2.new(1, -32, 0, 168), BackgroundTransparency = 1, BorderSizePixel = 0,
			ScrollBarThickness = 4, ScrollingDirection = Enum.ScrollingDirection.X, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(), ZIndex = 3 }, slots),
	})

	-- Hero list -------------------------------------------------------------
	local heroes = {}
	for _, hero in pairs(profile.Heroes or {}) do
		if hero.Assignment ~= info.Tag then
			if filter == "All" or (filter == "Bench" and hero.Assignment == "BENCHED") or (filter == "Best" and hasSynergy(props.Facility, hero)) then
				table.insert(heroes, hero)
			end
		end
	end
	table.sort(heroes, function(a, b)
		local ra, rb = restingSeconds(a) > 0, restingSeconds(b) > 0
		if ra ~= rb then return rb end
		local la, lb = StatFormulas.GetEffectiveLabor(a, info.Tag), StatFormulas.GetEffectiveLabor(b, info.Tag)
		if la ~= lb then return la > lb end
		return tostring(a.UUID) < tostring(b.UUID)
	end)
	local cards: { [string]: any } = { Layout = e("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		Pad = e("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8) }) }
	for i, hero in heroes do
		local good = hasSynergy(props.Facility, hero)
		local rarity = StatFormulas.GetHeroRarity(hero)
		local resting = restingSeconds(hero)
		local away = hero.Assignment ~= "BENCHED"
		local isConfirming = confirming == hero.UUID
		local heroLabor = StatFormulas.GetEffectiveLabor(hero, info.Tag)
		local actionTone, actionText = "Action", "ASSIGN"
		if resting > 0 then
			actionTone, actionText = "Slate", "RESTING"
		elseif full then
			actionTone, actionText = "Slate", "FULL"
		elseif isConfirming then
			actionTone, actionText = "Gold", "CONFIRM"
		elseif away then
			actionTone, actionText = "Bronze", "MOVE HERE"
		end
		local function act()
			if resting > 0 then
				say(string.format("%s is resting for %ds.", hero.DisplayName, resting), true)
			elseif full then
				say(string.format("All %d %s slots are full. Remove a worker first.", maxWorkers, info.Worker), true)
			elseif away and not isConfirming then
				setConfirming(hero.UUID)
				say(string.format("Take %s off %s? Press CONFIRM.", hero.DisplayName, assignmentLabel(hero.Assignment)))
			else
				request(hero.UUID, info.Tag)
			end
		end
		cards["H" .. i] = Panel({
			Class = "TextButton", Text = "", AutoButtonColor = false, Selectable = true, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 78), Radius = 10,
			Top = if hovered == hero.UUID then Tones.Violet.Top else Tones.Deep.Top, Bottom = Tones.Deep.Bottom,
			Rail = if good then TEXT.Gold else Color3.fromRGB(110, 96, 140),
			[React.Event.MouseEnter] = function() setHovered(hero.UUID) end,
			[React.Event.MouseLeave] = function() if hovered == hero.UUID then setHovered(nil) end end,
			[React.Event.Activated] = act,
		}, {
			Art = e("Frame", { Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(62, 62), BackgroundColor3 = Color3.fromRGB(14, 10, 22), ClipsDescendants = true, ZIndex = 3 }, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
				Ring = e("UIStroke", { Color = Theme.RarityColor(rarity), Thickness = 2.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
				Portrait = e(Portrait, { TemplateId = hero.TemplateId, Archetype = hero.Archetype, Stars = hero.Stars }),
			}),
			Arch = IconAt(hero.Archetype or "Striker", 24, { Position = UDim2.fromOffset(54, 50), ZIndex = 6 }),
			Name = Heavy({ Position = UDim2.fromOffset(84, 8), Size = UDim2.new(1, -250, 0, 20), MaxSize = 16, Outline = 2, Gold = false,
				TextXAlignment = Enum.TextXAlignment.Left, Text = hero.DisplayName, ZIndex = 4 }),
			Info = Body({ Position = UDim2.fromOffset(84, 30), Size = UDim2.new(1, -250, 0, 16), TextSize = 12, ZIndex = 4, TextColor3 = Theme.RarityColor(rarity),
				Text = string.format("%s · %s %d★ · Lv.%d", hero.Archetype or "?", HeroCatalog.RarityName(rarity), hero.Stars or 1, hero.Level or 1) }),
			Where = Body({ Position = UDim2.fromOffset(84, 50), Size = UDim2.new(1, -250, 0, 16), TextSize = 12, ZIndex = 4,
				TextColor3 = if resting > 0 then TEXT.Bad elseif away then Color3.fromRGB(150, 236, 255) else TEXT.Muted,
				Text = if resting > 0 then string.format("Resting %ds", resting) else "Now: " .. assignmentLabel(hero.Assignment) }),
			Labor = e("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -140, 0.5, 0), Size = UDim2.fromOffset(92, 56), BackgroundTransparency = 1, ZIndex = 4 }, {
				Value = e("TextLabel", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, FontFace = Grimoire.Fonts.Number, TextSize = 24, ZIndex = 4,
					TextColor3 = if good then TEXT.Gold else TEXT.Parchment, Text = string.format("%.1f", heroLabor) }, {
					Ink = e("UIStroke", { Color = INK, Thickness = 2 }),
				}),
				Caption = Body({ Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 14), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center,
					TextColor3 = if good then TEXT.Gold else TEXT.Muted, Text = if good then "LABOR · +25%" else "LABOR", ZIndex = 4 }),
				Gain = if not full and resting == 0 then Body({ Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 14), TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = TEXT.Good, Text = gainText(hero), ZIndex = 4 }) else nil,
			}),
			Action = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(118, 40), ZIndex = 4,
				[React.Event.Activated] = act }, actionTone, actionText, 14),
		})
	end
	if #heroes == 0 then
		cards.Empty = Body({ Size = UDim2.new(1, 0, 0, 60), TextSize = 14, TextColor3 = TEXT.Muted, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true,
			Text = if filter == "All" then "No other heroes. Summon more at the Summoning Altar." else "No heroes match this filter." })
	end
	local chips: { [string]: any } = { Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) }
	for order, key in { "All", "Bench", "Best" } do
		chips[key] = button({ LayoutOrder = order, Size = UDim2.fromOffset(if key == "Best" then 96 else 72, 28), ZIndex = 4,
			[React.Event.Activated] = function() setFilter(key :: Filter) end },
			if filter == key then "Gold" else "Slate", if key == "Best" then "BEST FIT" else string.upper(key), 12)
	end
	local picker = Panel({ LayoutOrder = 3, Size = if narrow then UDim2.new(1, 0, 0, 420) else UDim2.fromScale(1, 1),
		Top = Tones.Deep.Top, Bottom = Tones.Deep.Bottom, Rail = Tones.Deep.Rail }, {
		Caption = Heavy({ Position = UDim2.fromOffset(18, 12), Size = UDim2.new(1, -300, 0, 20), MaxSize = 16, Outline = 2, TextXAlignment = Enum.TextXAlignment.Left,
			Text = string.format("ASSIGN %sS", string.upper(info.Worker)), ZIndex = 3 }),
		Chips = e("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 8), Size = UDim2.fromOffset(280, 28), BackgroundTransparency = 1, ZIndex = 3 }, chips),
		List = e("ScrollingFrame", {
			Position = UDim2.fromOffset(12, 44), Size = UDim2.new(1, -24, 1, -54), BackgroundTransparency = 1, BorderSizePixel = 0,
			ScrollBarThickness = 5, ScrollBarImageColor3 = Color3.fromRGB(240, 196, 110),
			AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 3,
		}, cards),
	})

	-- Layout: two columns on desktop, one scrolling column on narrow screens.
	local body
	if narrow then
		body = e("ScrollingFrame", { Position = UDim2.fromOffset(20, 108), Size = UDim2.new(1, -40, 1, -156), BackgroundTransparency = 1, BorderSizePixel = 0,
			ScrollBarThickness = 4, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 23 }, {
			Layout = e("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
			Bonus = bonus, Slots = slotPanel, Picker = picker,
		})
	else
		body = e("Frame", { Position = UDim2.fromOffset(20, 108), Size = UDim2.new(1, -40, 1, -156), BackgroundTransparency = 1, ZIndex = 23 }, {
			Left = e("Frame", { Size = UDim2.new(0.44, -8, 1, 0), BackgroundTransparency = 1, ZIndex = 23 }, {
				Layout = e("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
				Bonus = bonus, Slots = slotPanel,
			}),
			Right = e("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.56, -8, 1, 0), BackgroundTransparency = 1, ZIndex = 23 }, {
				Picker = picker,
			}),
		})
	end

	-- Footer: the Fortress Tree link and the status line.
	local footer = e("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, -12), Size = UDim2.new(1, -40, 0, 36), BackgroundTransparency = 1, ZIndex = 24 }, {
		Status = Body({ Size = UDim2.new(1, -340, 1, 0), TextSize = 14, TextColor3 = if isError then TEXT.Bad else TEXT.Muted, Text = message, ZIndex = 25 }),
		Next = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(330, 36), ZIndex = 25,
			[React.Event.Activated] = function()
				props.OnClose()
				if _G.OpenFacilityHUD then _G.OpenFacilityHUD("FortressTree") end
			end }, "Bronze", nextText .. "  ›", 13),
	})

	return e("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(6, 5, 10), BackgroundTransparency = 0.35, Text = "", AutoButtonColor = false, ZIndex = 20,
		[React.Event.Activated] = function() props.OnClose() end,
	}, {
		Window = Panel({
			Class = "TextButton", Text = "", AutoButtonColor = false, -- swallows clicks so they don't reach the scrim
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0.94, 0, 0.9, 0),
			Radius = 16,
			Rail = tone.Rail,
			ZIndex = 21,
		}, {
			Max = e("UISizeConstraint", { MaxSize = Vector2.new(1120, 720) }),
			Header = header,
			Close = Panel({
				Class = "TextButton", Text = "", AutoButtonColor = false, Selectable = true, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 18),
				Size = UDim2.fromOffset(44, 40), Radius = 10, Top = Tones.Crimson.Top, Bottom = Tones.Crimson.Bottom, Rail = Tones.Crimson.Rail, ZIndex = 25,
				[React.Event.Activated] = function() props.OnClose() end,
			}, {
				X = IconAt("Close", 18, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 27 }),
			}),
			Body = body,
			Footer = footer,
		}),
	})
end

return FacilityPanel
