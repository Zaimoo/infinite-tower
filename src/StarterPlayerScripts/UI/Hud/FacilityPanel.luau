--!strict
-- StarterPlayerScripts/UI/Hud/FacilityPanel.luau
-- Phase 5 §4.5: one gothic panel for every support facility (Guard Post, Market, Training Grounds,
-- God's Blessing). Header (level, workers, preferred archetypes, next Fortress Tree unlock), one big
-- live bonus figure with its breakdown, worker slots and a hero picker that previews the change.
-- Assignments go through AssignHeroRole; every refusal is shown. No upgrade button: facilities
-- are levelled only in the Fortress Tree.

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

local Theme = require(script.Parent:WaitForChild("Theme"))
local Gothic = require(script.Parent:WaitForChild("Gothic"))
local Portrait = require(script.Parent:WaitForChild("Portrait"))
local Components = require(script.Parent:WaitForChild("Components"))

local AssignHeroRole = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TycoonGachaRemotes"):WaitForChild("AssignHeroRole") :: RemoteFunction

local e = React.createElement
local P = Gothic.Palette
local CLOSE_ACTION = "FacilityPanelClose"

local FACILITIES = {
	GuardPost = { Title = "OUTSKIRTS GUARD POST", Tag = "FACILITY_GUARD_POST", Worker = "Adventurer", Accent = Color3.fromRGB(130, 205, 95), Branch = "Outskirts" },
	Market = { Title = "THE MARKET", Tag = "FACILITY_MARKET", Worker = "Merchant", Accent = Color3.fromRGB(245, 195, 75), Branch = "Commerce" },
	TrainingGrounds = { Title = "TRAINING GROUNDS", Tag = "FACILITY_TRAINING", Worker = "Trainer", Accent = Color3.fromRGB(235, 80, 80), Branch = "Martial" },
	GodsBlessing = { Title = "GOD'S BLESSING", Tag = "FACILITY_GODS_BLESSING", Worker = "Acolyte", Accent = Color3.fromRGB(255, 226, 150), Branch = "Divine" },
}

local ASSIGNMENT_LABELS: { [string]: string } = {
	BENCHED = "Bench",
	FACILITY_GUARD_POST = "Guard Post",
	FACILITY_MARKET = "Market",
	FACILITY_TRAINING = "Training",
	FACILITY_GODS_BLESSING = "Blessing",
}

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

local function awakeLabor(profile: any, uuids: { string }, tag: string): number
	local sum, now = 0, os.time()
	for _, uuid in uuids do
		local hero = profile.Heroes[uuid]
		if hero and (hero.ComaUntilTimestamp or 0) <= now then
			sum += StatFormulas.GetEffectiveLabor(hero, tag)
		end
	end
	return sum
end

-- The facility's big number for a given total worker labor, plus a formatter and breakdown lines.
local function bonusFor(facility: string, profile: any, level: number, labor: number): (number, string, { string })
	local perks = FortressTree.PerkBonuses(profile.FortressTree)
	if facility == "GuardPost" then
		local tier = profile.HighestClearedBiomeBoss or 0
		local rate = StatFormulas.GetPassiveGoldRate(level, labor, tier, perks)
		local cfg = FacilityConfig.UpgradeTable.GuardPost[level]
		local cap = if cfg then (cfg.MaxOfflineMinutes + perks.OfflineMinutes) / 60 else 0
		return rate, string.format("%s Gold/min", Components.Abbreviate(rate)), {
			string.format("Base rate  %d Gold/min%s", math.round((cfg and cfg.BaseGoldPerMin or 0) * (1 + perks.GuardPostRate)), if perks.GuardPostRate > 0 then " (Long Patrols)" else ""),
			string.format("Adventurer labor  %.1f × 0.85", labor),
			string.format("Biome Boss bonus  +%d%% (tier %d)", tier * 15, tier),
			string.format("Offline  %dh cap at %d%% efficiency", cap, math.round((cfg and cfg.OfflineEfficiency or 0) * 100)),
		}
	elseif facility == "Market" then
		local mult = StatFormulas.GetMarketLootMultiplier(level, labor, perks)
		local cfg = FacilityConfig.UpgradeTable.Market[level]
		return mult, string.format("+%.1f%% tower loot", (mult - 1) * 100), {
			string.format("Level bonus  +%.0f%%%s", ((cfg and cfg.BaseBonus or 0) + perks.MarketBonus) * 100, if perks.MarketBonus > 0 then " (Appraiser's Eye)" else ""),
			string.format("Merchant labor  %.1f × 0.5%%", labor),
		}
	elseif facility == "TrainingGrounds" then
		local mult = StatFormulas.GetTrainingCombatMultiplier(level, labor, perks)
		local cfg = FacilityConfig.UpgradeTable.TrainingGrounds[level]
		local before = StatFormulas.GetSquadPower(profile, 1)
		local after = StatFormulas.GetSquadPower(profile, mult)
		return mult, string.format("+%.1f%% squad ATK & HP", (mult - 1) * 100), {
			string.format("Level bonus  +%.0f%%%s", ((cfg and cfg.BaseBonus or 0) + perks.TrainingBonus) * 100, if perks.TrainingBonus > 0 then " (Veteran Drills)" else ""),
			string.format("Trainer labor  %.1f × 0.4%%", labor),
			string.format("Squad Power  +%s", Components.Abbreviate(after - before)),
		}
	else
		local luck = SummonLuck.Luck(level, labor, perks.BlessingLuck)
		local cfg = FacilityConfig.UpgradeTable.GodsBlessing[level]
		local rates = HeroCatalog.LimitedBanner.Rates :: { number }
		local top = #rates
		return luck, string.format("+%.1f%% summon luck", luck * 100), {
			string.format("Base luck  +%.0f%%", (cfg and cfg.BaseLuck or 0) * 100),
			string.format("Acolyte labor  %.1f × 0.4%%%s", labor, if perks.BlessingLuck > 0 then "  ·  Saint's Favor +3%" else ""),
			string.format("Capped at +%d%%", math.round(FacilityConfig.Constants.MaxSummonLuck * 100)),
			string.format("Astrea (Mythical)  %.2f%% → %.3f%%", rates[top] * 100, SummonLuck.ApplyLuck(rates, luck)[top] * 100),
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

local function FacilityPanel(props: { Facility: string, Profile: any, Width: number, OnClose: () -> () })
	local info = FACILITIES[props.Facility]
	local hovered, setHovered = React.useState(nil :: string?)
	local confirming, setConfirming = React.useState(nil :: string?)
	local message, setMessage = React.useState("")
	local busy, setBusy = React.useState(false)

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

	local function request(uuid: string, target: string)
		if busy then return end
		setBusy(true)
		setMessage("Working…")
		task.spawn(function()
			local ok, success, msg = pcall(function() return AssignHeroRole:InvokeServer(uuid, target) end)
			setBusy(false)
			setConfirming(nil)
			setMessage(if not ok then "Connection failed. Please try again." else tostring(msg or (if success then "Done." else "Unable to assign that hero.")))
		end)
	end

	-- Preview: the big figure if the hovered hero joined (only while a slot is free).
	local preview = ""
	local hoverHero = hovered and profile.Heroes[hovered]
	if hoverHero and hoverHero.Assignment ~= info.Tag and #assigned < maxWorkers then
		local after = bonusFor(props.Facility, profile, level, labor + StatFormulas.GetEffectiveLabor(hoverHero, info.Tag))
		if props.Facility == "GuardPost" then
			preview = string.format("+%s Gold/min", Components.Abbreviate(after - value))
		else
			preview = string.format("+%.1f%%", (after - value) * 100)
		end
	end

	-- Header ----------------------------------------------------------------
	local synergyIcons = {}
	for _, archetype in FacilityConfig.FacilityArchetypeSynergies[props.Facility] or {} do
		table.insert(synergyIcons, archetype)
	end
	local nxt = nextNode(props.Facility, profile.FortressTree)
	local nextText = if nxt
		then string.format("NEXT: %s · %s Gold%s", nxt.Name, Components.Abbreviate(nxt.Gold), if nxt.FloorGate > (profile.HighestClearedFloor or 0) then string.format(" · Floor %d", nxt.FloorGate) else "")
		else "ALL NODES BUILT"

	local header = e(Gothic.Box, { GothicStyle = "Panel", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 96) }, {
		Level = e(Gothic.Label, { Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -32, 0, 18), Role = "SubHeader", TextSize = 14,
			Color = info.Accent, Text = string.format("LV.%d · %s", level, string.upper(levelCfg and levelCfg.VisualTitle or "Unbuilt")) }),
		Workers = e(Gothic.Label, { Position = UDim2.fromOffset(16, 32), Size = UDim2.new(1, -32, 0, 16), Role = "Body", TextSize = 13,
			Color = P.TextWhite, Text = string.format("%d / %d %ss  ·  +25%% bonus: %s", #assigned, maxWorkers, info.Worker, table.concat(synergyIcons, ", ")) }),
		Next = e(Gothic.Box, {
			Class = "TextButton", GothicStyle = "ButtonSecondary", Position = UDim2.fromOffset(16, 56), Size = UDim2.new(1, -32, 0, 30), Selectable = true,
			[React.Event.Activated] = function()
				props.OnClose()
				if _G.OpenFacilityHUD then _G.OpenFacilityHUD("FortressTree") end
			end,
		}, {
			Label = e(Gothic.Label, { Size = UDim2.fromScale(1, 1), Role = "Button", TextSize = 12, Color = P.GoldWarm, ZIndex = 8,
				TextXAlignment = Enum.TextXAlignment.Center, Text = nextText .. "  ›  FORTRESS TREE" }),
		}),
	})

	-- Bonus block -----------------------------------------------------------
	local lines: { [string]: any } = { Layout = e("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) }
	for i, line in breakdown do
		lines["L" .. i] = e(Gothic.Label, { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 16), Role = "Body", TextSize = 12, Color = P.TextDim, Text = line })
	end
	local bonus = e(Gothic.Box, { GothicStyle = "Card", LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 92 + #breakdown * 20) }, {
		Caption = e(Gothic.Label, { Position = UDim2.fromOffset(18, 12), Size = UDim2.new(1, -36, 0, 14), Role = "SubHeader", TextSize = 11, Spaced = true,
			Color = P.TextDim, Text = "BONUS" }),
		Figure = e(Gothic.Label, { Position = UDim2.fromOffset(18, 30), Size = UDim2.new(1, -36, 0, 36), Role = "Title", TextSize = 28, Color = P.GoldBright, Text = figure }),
		Preview = if preview ~= "" then e(Gothic.Label, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 36), Size = UDim2.fromOffset(140, 24),
			Role = "Header", TextSize = 18, Color = P.GreenSuccess, Text = preview, TextXAlignment = Enum.TextXAlignment.Right }) else nil,
		Lines = e("Frame", { Position = UDim2.fromOffset(18, 74), Size = UDim2.new(1, -36, 1, -82), BackgroundTransparency = 1 }, lines),
	})

	-- Worker slots ----------------------------------------------------------
	local slots: { [string]: any } = { Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) }
	local shownSlots = math.max(maxWorkers, 1)
	for i = 1, math.min(shownSlots + 1, 5) do
		local uuid = assigned[i]
		local hero = uuid and profile.Heroes[uuid]
		if i <= maxWorkers and hero then
			slots["S" .. i] = e(Gothic.Box, { GothicStyle = "Slot", LayoutOrder = i, Size = UDim2.fromOffset(96, 120), ClipsDescendants = false }, {
				Art = e("Frame", { Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, 72), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 6 }, {
					Portrait = e(Portrait, { TemplateId = hero.TemplateId, Archetype = hero.Archetype, Stars = hero.Stars }),
				}),
				Name = e(Gothic.Label, { Position = UDim2.fromOffset(4, 80), Size = UDim2.new(1, -8, 0, 14), Role = "Body", TextSize = 11, ZIndex = 7,
					Color = Theme.RarityColor(StatFormulas.GetHeroRarity(hero)), TextXAlignment = Enum.TextXAlignment.Center,
					Text = (if hasSynergy(props.Facility, hero) then "★ " else "") .. hero.DisplayName }),
				Labor = e(Gothic.Label, { Position = UDim2.fromOffset(4, 96), Size = UDim2.new(1, -8, 0, 14), Role = "Body", TextSize = 10, ZIndex = 7, Color = P.TextDim,
					TextXAlignment = Enum.TextXAlignment.Center, Text = string.format("%.1f labor", StatFormulas.GetEffectiveLabor(hero, info.Tag)) }),
				Remove = e("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 6, 0, -6), Size = UDim2.fromOffset(24, 24), ZIndex = 9,
					BackgroundColor3 = P.CloseRed, Text = "✕", TextColor3 = P.TextWhite, TextSize = 13, Font = Theme.Font, Selectable = true,
					[React.Event.Activated] = function() request(uuid, "BENCHED") end }, { Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
			})
		elseif i <= maxWorkers then
			slots["S" .. i] = e(Gothic.Box, { GothicStyle = "Slot", LayoutOrder = i, Size = UDim2.fromOffset(96, 120) }, {
				Plus = e(Gothic.Label, { Size = UDim2.fromScale(1, 1), Role = "Title", TextSize = 30, Color = P.TextDim, ZIndex = 7,
					TextXAlignment = Enum.TextXAlignment.Center, Text = "+" }),
			})
		else
			-- The next slot this facility can open, through a level or perk node.
			slots["S" .. i] = e(Gothic.Box, { GothicStyle = "Slot", LayoutOrder = i, Size = UDim2.fromOffset(96, 120), Disabled = true }, {
				Padlock = Components.IconAt("Lock", 34, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 16), ZIndex = 7 }),
				Lock = e(Gothic.Label, { Size = UDim2.new(1, -8, 0, 54), Position = UDim2.fromOffset(4, 56), Role = "Body", TextSize = 11, Color = P.TextDim, ZIndex = 7,
					TextWrapped = true, TextTruncate = Enum.TextTruncate.None, TextXAlignment = Enum.TextXAlignment.Center,
					Text = "More slots in\nthe Fortress Tree" }),
			})
		end
	end
	local slotPanel = e(Gothic.Box, { GothicStyle = "Panel", LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 170) }, {
		Caption = e(Gothic.Label, { Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -32, 0, 16), Role = "SubHeader", TextSize = 12, Spaced = true,
			Color = P.TextDim, Text = "WORKERS" }),
		Row = e("Frame", { Position = UDim2.fromOffset(16, 36), Size = UDim2.new(1, -32, 0, 124), BackgroundTransparency = 1 }, slots),
	})

	-- Hero picker -----------------------------------------------------------
	local heroes = {}
	for _, hero in pairs(profile.Heroes or {}) do
		if hero.Assignment ~= info.Tag then table.insert(heroes, hero) end
	end
	table.sort(heroes, function(a, b)
		local sa, sb = hasSynergy(props.Facility, a), hasSynergy(props.Facility, b)
		if sa ~= sb then return sa end
		local la, lb = StatFormulas.GetEffectiveLabor(a, info.Tag), StatFormulas.GetEffectiveLabor(b, info.Tag)
		if la ~= lb then return la > lb end
		return tostring(a.UUID) < tostring(b.UUID)
	end)
	local cards: { [string]: any } = { Layout = e("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) }
	for i, hero in heroes do
		local synergy = hasSynergy(props.Facility, hero)
		local rarity = StatFormulas.GetHeroRarity(hero)
		local away = hero.Assignment ~= "BENCHED"
		local isConfirming = confirming == hero.UUID
		local full = #assigned >= maxWorkers
		cards["H" .. i] = e(Gothic.Box, {
			Class = "TextButton", GothicStyle = "Row", LayoutOrder = i, Size = UDim2.new(1, -8, 0, 64), Selectable = true, Accent = if synergy then P.GoldWarm else nil,
			[React.Event.MouseEnter] = function() setHovered(hero.UUID) end,
			[React.Event.MouseLeave] = function() if hovered == hero.UUID then setHovered(nil) end end,
			[React.Event.Activated] = function()
				if full then
					setMessage(string.format("All %d %s slots are full. Remove a worker first.", maxWorkers, info.Worker))
				elseif away and not isConfirming then
					setHovered(hero.UUID)
					setConfirming(hero.UUID)
					setMessage(string.format("Take %s off %s? Click again to confirm.", hero.DisplayName, assignmentLabel(hero.Assignment)))
				else
					request(hero.UUID, info.Tag)
				end
			end,
		}, {
			Art = e("Frame", { Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(52, 52), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 6 }, {
				Ring = e("UIStroke", { Color = Theme.RarityColor(rarity), Thickness = 2 }),
				Portrait = e(Portrait, { TemplateId = hero.TemplateId, Archetype = hero.Archetype, Stars = hero.Stars }),
			}),
			Arch = Components.IconAt(hero.Archetype or "Striker", 22, { Position = UDim2.fromOffset(44, 42), ZIndex = 8 }),
			Name = e(Gothic.Label, { Position = UDim2.fromOffset(70, 8), Size = UDim2.new(1, -220, 0, 18), Role = "Header", TextSize = 14, ZIndex = 7, Color = P.TextWhite,
				Text = string.format("%s%s", if synergy then "★ " else "", hero.DisplayName) }),
			Info = e(Gothic.Label, { Position = UDim2.fromOffset(70, 28), Size = UDim2.new(1, -220, 0, 14), Role = "Body", TextSize = 11, ZIndex = 7,
				Color = Theme.RarityColor(rarity), Text = string.format("%s · %s %d★ · Lv.%d", hero.Archetype or "?", HeroCatalog.RarityName(rarity), hero.Stars or 1, hero.Level or 1) }),
			Labor = e(Gothic.Label, { Position = UDim2.fromOffset(70, 44), Size = UDim2.new(1, -220, 0, 14), Role = "Body", TextSize = 11, ZIndex = 7, Color = P.TextDim,
				Text = string.format("%.1f labor here%s", StatFormulas.GetEffectiveLabor(hero, info.Tag), if synergy then "  ·  <font color=\"#E4BA73\">+25% bonus</font>" else "") }),
			Chip = e(Gothic.Label, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(140, 22), Role = "Body", TextSize = 11, ZIndex = 7,
				Color = if isConfirming then P.GoldBright elseif away then P.CyanEquipped else P.TextDim, TextXAlignment = Enum.TextXAlignment.Right,
				Text = if isConfirming then "CLICK TO CONFIRM" else assignmentLabel(hero.Assignment) }),
		})
	end
	if #heroes == 0 then
		cards.Empty = e(Gothic.Label, { Size = UDim2.new(1, 0, 0, 40), Role = "Body", TextSize = 13, Color = P.TextDim, TextXAlignment = Enum.TextXAlignment.Center,
			Text = "No other heroes. Summon more at the Summoning Altar." })
	end
	local picker = e(Gothic.Box, { GothicStyle = "Panel", LayoutOrder = 4, Size = if narrow then UDim2.new(1, 0, 0, 360) else UDim2.fromScale(1, 1) }, {
		Caption = e(Gothic.Label, { Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -32, 0, 16), Role = "SubHeader", TextSize = 12, Spaced = true,
			Color = P.TextDim, Text = "ASSIGN A HERO" }),
		List = e("ScrollingFrame", {
			Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -24, 1, -44), BackgroundTransparency = 1, BorderSizePixel = 0,
			ScrollBarThickness = 4, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 5,
		}, cards),
	})

	-- Layout: two columns on desktop, one scrolling column on narrow screens.
	local body
	if narrow then
		body = e("ScrollingFrame", { Position = UDim2.fromOffset(20, 72), Size = UDim2.new(1, -40, 1, -110), BackgroundTransparency = 1, BorderSizePixel = 0,
			ScrollBarThickness = 4, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new() }, {
			Layout = e("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
			Header = header, Bonus = bonus, Slots = slotPanel, Picker = picker,
		})
	else
		body = e("Frame", { Position = UDim2.fromOffset(20, 72), Size = UDim2.new(1, -40, 1, -110), BackgroundTransparency = 1 }, {
			Left = e("Frame", { Size = UDim2.new(0.46, -8, 1, 0), BackgroundTransparency = 1 }, {
				Layout = e("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
				Header = header, Bonus = bonus, Slots = slotPanel,
			}),
			Right = e("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.54, -8, 1, 0), BackgroundTransparency = 1 }, {
				Picker = picker,
			}),
		})
	end

	return e("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(6, 5, 10), BackgroundTransparency = 0.35, Text = "", AutoButtonColor = false, ZIndex = 20,
		[React.Event.Activated] = function() props.OnClose() end,
	}, {
		Window = e(Gothic.Box, {
			Class = "TextButton", -- swallows clicks so they don't reach the scrim
			GothicStyle = "Window",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0.94, 0, 0.9, 0),
			ZIndex = 21,
		}, {
			Max = e("UISizeConstraint", { MaxSize = Vector2.new(1120, 700) }),
			Title = e(Gothic.Label, { Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 34), Role = "Title", TextSize = 26, Spaced = true, ZIndex = 25,
				Color = P.TextWhite, Text = info.Title, TextXAlignment = Enum.TextXAlignment.Center }),
			Close = e(Gothic.Box, {
				Class = "TextButton", GothicStyle = "ButtonSecondary", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 16), Size = UDim2.fromOffset(44, 36),
				ZIndex = 25, Selectable = true, [React.Event.Activated] = function() props.OnClose() end,
			}, {
				X = e(Gothic.Label, { Size = UDim2.fromScale(1, 1), Role = "Button", TextSize = 16, Color = P.TextWhite, ZIndex = 26,
					TextXAlignment = Enum.TextXAlignment.Center, Text = "✕" }),
			}),
			Body = body,
			Status = e(Gothic.Label, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(1, -40, 0, 20), Role = "Body",
				TextSize = 13, ZIndex = 25, Color = if string.find(message, "full") or string.find(message, "Unable") or string.find(message, "failed") then P.CloseRed else P.TextDim,
				TextXAlignment = Enum.TextXAlignment.Center, Text = message }),
		}),
	})
end

return FacilityPanel
