--!strict
-- StarterPlayerScripts/UI/Hud/HudApp.luau
-- Phase 5 HUD root (§2): Left Rail (menus), Right Rail (combat), Next Goal card, Squad Status Card,
-- Squad Power badge and the Hero Index modal. Zones are placed from the live screen size so they
-- never overlap: the Right Rail starts below the goal card and stops above the power badge, the
-- Left Rail stops above the status card, and rail buttons shrink (never below 44 px) to fit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local ReactRoblox = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("ReactRoblox"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local HeroCatalog = require(Shared:WaitForChild("Config"):WaitForChild("HeroCatalog"))
local TreeConfig = require(Shared:WaitForChild("Config"):WaitForChild("FortressTreeConfig"))
local FortressTree = require(Shared:WaitForChild("Util"):WaitForChild("FortressTree"))
local StatFormulas = require(Shared:WaitForChild("Util"):WaitForChild("StatFormulas"))

local Theme = require(script.Parent:WaitForChild("Theme"))
local Store = require(script.Parent:WaitForChild("Store"))
local Whistles = require(script.Parent:WaitForChild("Whistles"))
local Components = require(script.Parent:WaitForChild("Components"))
local HeroIndex = require(script.Parent:WaitForChild("HeroIndex"))
local FacilityPanel = require(script.Parent:WaitForChild("FacilityPanel"))
local ShopPanel = require(script.Parent:WaitForChild("ShopPanel"))

-- Support facilities shown in the Phase 5 gothic panel.
local PANEL_FACILITIES = { GuardPost = true, Market = true, TrainingGrounds = true, GodsBlessing = true }

local e = React.createElement
local L = Theme.Layout
local LocalPlayer = Players.LocalPlayer

local HERO_STATES = { [1] = "Idle", [2] = "Moving", [3] = "Fighting", [4] = "Down" }

local function call(name: string, ...: any)
	local fn = (_G :: any)[name]
	if type(fn) == "function" then fn(...) end
end

-- Live combat data for this player's heroes, keyed by hero UUID.
local function liveHeroes(): { [string]: any }
	local state = _G.ClientCombatState
	local out = {}
	if not state or not state.Metadata or not state.VisualNodes then return out end
	for netId, meta in pairs(state.Metadata) do
		if meta.IsHero and meta.OwnerUserId == LocalPlayer.UserId and meta.HeroUUID then
			local node = state.VisualNodes[netId]
			if node and node.HpPermille then
				out[meta.HeroUUID] = { Node = node, Meta = meta }
			end
		end
	end
	return out
end

local function buildRows(profile: any): ({ any }, string?)
	local open = FortressTree.SquadSlots(profile and profile.FortressTree)
	local bySlot: { [number]: any } = {}
	for uuid, hero in pairs(profile and profile.Heroes or {}) do
		local slot = tonumber(string.match(hero.Assignment or "", "^SQUAD_SLOT_(%d+)$"))
		if slot then bySlot[slot] = hero end
	end
	local live = liveHeroes()
	local now = os.time()
	local recalled = Whistles.Remaining("Recall") > Whistles.Cooldown.Recall - 2
	local rows = {}
	for slot = 1, open do
		local hero = bySlot[slot]
		if not hero then
			table.insert(rows, { Slot = slot })
		else
			local seed = HeroCatalog.Seeds[hero.TemplateId]
			local rarity = StatFormulas.GetHeroRarity(hero)
			local row: any = {
				Slot = slot, Hero = true, Name = hero.DisplayName, TemplateId = hero.TemplateId, Archetype = hero.Archetype or (seed and seed.Archetype) or "Striker",
				Rarity = rarity, RarityName = HeroCatalog.RarityName(rarity), Stars = hero.Stars or 1, Level = hero.Level or 1,
			}
			local info = live[hero.UUID]
			local comaLeft = (hero.ComaUntilTimestamp or 0) - now
			if info then
				row.HpFraction = info.Node.HpPermille / 1000
				row.Gauge = info.Node.Stamina or 0
				row.State = if info.Meta.DuelSide then "Dueling" else HERO_STATES[info.Node.StateEnum or 1] or "Idle"
				if row.State ~= "Down" and row.State ~= "Dueling" and recalled then row.State = "Recalled" end
			else
				row.ShowStamina = true
				row.HpFraction = (hero.CurrentStamina or 100) / math.max(1, hero.MaxStamina or 100)
				row.Gauge = 0
				row.State = "Resting"
			end
			if comaLeft > 0 then
				row.State = "Down"
				row.DownSeconds = comaLeft
			end
			table.insert(rows, row)
		end
	end
	local lockedText = nil
	if open < TreeConfig.MaxSquadSlots then
		lockedText = string.format("Slots %d–%d · unlock in the Fortress Tree", open + 1, TreeConfig.MaxSquadSlots)
	end
	return rows, lockedText
end

local function buildableNodes(profile: any): number
	if not profile then return 0 end
	local count = 0
	for _, node in TreeConfig.Nodes do
		if FortressTree.CanUnlock(profile.FortressTree, node.Id, profile.Currencies and profile.Currencies.Gold or 0,
			profile.HighestClearedFloor or 0, profile.Unlocks) then
			count += 1
		end
	end
	return count
end

-- Which Pit screen is open (legacy controllers until slice 3), and where its window starts.
local function pitState(host: GuiObject): (string?, Vector2?)
	local synth = _G.SynthesisController
	local promo = _G.PromotionController
	local active, window = nil, nil
	if synth and synth.Root and synth.Root.Visible then
		active, window = "Synthesis", synth.Root
	elseif promo and promo.IsOpen and promo:IsOpen() then
		active, window = "Promotion", promo.Root
	end
	if not active or not window then return nil, nil end
	local origin = host.AbsolutePosition
	local top = window.AbsolutePosition - origin
	-- The Pit windows leave 64 px free above them (PIT_TAB_SPACE); the tab bar sits in that gap.
	return active, Vector2.new(top.X + window.AbsoluteSize.X / 2, math.max(56, top.Y - 8))
end

local function railSize(count: number, available: number): number
	if count <= 0 then return L.RailButton end
	-- Each button is the icon plus ~20% for the label that overlaps its foot.
	local per = (available - (count - 1) * L.RailGap) / count / 1.2
	return math.clamp(math.floor(per), L.RailButtonMin, L.RailButton)
end

local function rail(name: string, side: "Left" | "Right", top: number, size: number, buttons: { any })
	local children: { [string]: any } = {
		Layout = e("UIListLayout", { Padding = UDim.new(0, L.RailGap), SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	}
	for i, b in buttons do
		b.Order = i
		b.Size = size
		children["B" .. i] = e(Components.RailButton, b)
	end
	return e("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(if side == "Left" then 0 else 1, 0),
		Position = if side == "Left" then UDim2.fromOffset(L.Edge, top) else UDim2.new(1, -L.Edge, 0, top),
		Size = UDim2.fromOffset(size + 24, #buttons * (math.ceil(size * 1.2) + L.RailGap)),
		BackgroundTransparency = 1,
	}, children)
end

local function HudApp(props: { Root: GuiObject, Overlay: GuiObject? })
	local _, setRevision = React.useState(0)
	local _, setTick = React.useState(0)
	local screen, setScreen = React.useState(props.Root.AbsoluteSize)
	local indexOpen, setIndexOpen = React.useState(false)
	local facilityOpen, setFacilityOpen = React.useState(nil :: string?)
	local shopOpen, setShopOpen = React.useState(false)
	local knownTemplates = React.useRef(nil :: { [string]: boolean }?)
	local newHeroes, setNewHeroes = React.useState(0)

	React.useEffect(function()
		local conns = {
			Store.Changed:Connect(function(rev) setRevision(rev) end),
			Whistles.Changed:Connect(function() setTick(os.clock()) end),
			props.Root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() setScreen(props.Root.AbsoluteSize) end),
		}
		-- Live status, cooldown sweeps and coma countdowns refresh at 5 Hz.
		local alive = true
		task.spawn(function()
			while alive do
				task.wait(0.2)
				setTick(os.clock())
			end
		end)
		return function()
			alive = false
			for _, c in conns do c:Disconnect() end
		end
	end, {})

	React.useEffect(function()
		_G.OpenHeroIndex = function()
			call("OpenMasterModal", "NONE")
			setIndexOpen(true)
			setNewHeroes(0)
		end
		_G.IsHeroIndexOpen = function() return indexOpen or facilityOpen ~= nil or shopOpen end
		_G.CloseHeroIndex = function()
			setIndexOpen(false)
			setFacilityOpen(nil)
			setShopOpen(false)
		end
		-- Robux Store (Phase 5): the Shop button on the Right Rail.
		_G.OpenRobuxShop = function()
			call("OpenMasterModal", "NONE")
			setIndexOpen(false)
			setFacilityOpen(nil)
			setShopOpen(true)
		end
		_G.OpenFacilityPanel = function(facility: string): boolean
			if not PANEL_FACILITIES[facility] then return false end
			call("OpenMasterModal", "NONE")
			setFacilityOpen(facility)
			return true
		end
	end, { indexOpen, facilityOpen, shopOpen })

	local profile = Store.Profile
	local unlocks = profile and profile.Unlocks or {}

	-- Index badge: hero templates first owned since the session started and not yet viewed.
	React.useEffect(function()
		if not profile then return end
		local seen = {}
		for _, hero in pairs(profile.Heroes or {}) do seen[hero.TemplateId] = true end
		if not knownTemplates.current then
			knownTemplates.current = seen
			return
		end
		local fresh = 0
		for id in seen do
			if not knownTemplates.current[id] then
				knownTemplates.current[id] = true
				fresh += 1
			end
		end
		if fresh > 0 and not indexOpen then setNewHeroes(newHeroes + fresh) end
	end, { Store.Revision })

	local compact = screen.X < 700 or screen.Y < 480
	local goal = Store.Goal
	local rows, lockedText = buildRows(profile)
	local emptySlots = 0
	for _, r in rows do if not r.Hero then emptySlots += 1 end end
	-- The status card grows to the right with each open slot. Tiles shrink to stay clear of the
	-- Squad Power badge; if even the smallest tiles would reach it, use the compact portrait strip.
	local lockedRange = if lockedText then string.format("%d–%d", #rows + 1, TreeConfig.MaxSquadSlots) else nil
	local roomForCard = screen.X - 2 * L.Edge - L.PowerBadgeWidth - L.ZoneGap
	local tileWidth = Components.StatusTileMax
	if not compact then
		local fixed = Components.StatusCardWidth(0, lockedText ~= nil, 0) + #rows * 6
		tileWidth = math.min(Components.StatusTileMax, math.floor((roomForCard - fixed) / math.max(1, #rows)))
		if tileWidth < Components.StatusTileMin then compact = true end
	end
	local cardHeight = Components.StatusCardHeight(#rows, lockedText ~= nil, compact)
	local powerHeight = if compact then 40 else L.PowerBadgeHeight

	local leftButtons = {
		{ Icon = "Summon", Label = "Summon", Accent = Color3.fromRGB(250, 204, 21), OnActivated = function() call("OpenFacilityHUD", "Summoning") end },
	}
	if unlocks.Squad then
		table.insert(leftButtons, { Icon = "Squad", Label = "Squad", Accent = Color3.fromRGB(56, 189, 248), Badge = emptySlots,
			OnActivated = function() call("OpenMasterModal", "SQUAD") end })
	end
	if unlocks.Forge then
		table.insert(leftButtons, { Icon = "Forge", Label = "Forge", Accent = Color3.fromRGB(255, 120, 40),
			OnActivated = function() call("OpenMasterModal", "BLACKSMITH") end })
	end
	if unlocks.Squad then
		table.insert(leftButtons, { Icon = "Fortress", Label = "Fortress", Accent = Color3.fromRGB(214, 180, 120), Badge = buildableNodes(profile),
			OnActivated = function() call("OpenFacilityHUD", "FortressTree") end })
	end
	table.insert(leftButtons, { Icon = "Index", Label = "Index", Accent = Color3.fromRGB(180, 140, 255), Badge = newHeroes,
		OnActivated = function() if _G.OpenHeroIndex then _G.OpenHeroIndex() end end })
	-- Settings closes the Left Rail (it replaced the old floating gear in the top-right corner).
	table.insert(leftButtons, { Icon = "Gear", Label = "Settings", Accent = Color3.fromRGB(200, 196, 220),
		OnActivated = function() call("ToggleSettings") end })

	local overdriveBlocked = Whistles.Blocked("Overdrive")
	local recallBlocked = Whistles.Blocked("Recall")
	local rightButtons = {
		{ Icon = "Shop", Label = "Store", Accent = Color3.fromRGB(255, 214, 110), Wiggle = not shopOpen,
			OnActivated = function() if _G.OpenRobuxShop then _G.OpenRobuxShop() end end },
		{ Icon = "Overdrive", Label = "Overdrive", Accent = Color3.fromRGB(245, 158, 11), KeyHint = "Q",
			Cooldown = Whistles.Remaining("Overdrive"), CooldownTotal = Whistles.Cooldown.Overdrive,
			Disabled = overdriveBlocked ~= nil, OnActivated = function() Whistles.Fire("Overdrive") end },
		{ Icon = "Recall", Label = "Recall", Accent = Color3.fromRGB(34, 211, 238), KeyHint = "E",
			Cooldown = Whistles.Remaining("Recall"), CooldownTotal = Whistles.Cooldown.Recall,
			Disabled = recallBlocked ~= nil, OnActivated = function() Whistles.Fire("Recall") end },
	}
	if unlocks.Tower then
		table.insert(rightButtons, { Icon = "Tower", Label = "Tower", Accent = Color3.fromRGB(192, 132, 252),
			OnActivated = function() call("ToggleTower") end })
	end

	-- Gold and Gems sit directly above the status card; the Left Rail stops above both.
	local currencyGap = 8
	local currencyBottom = L.Edge + cardHeight + currencyGap
	local currencyWidth = if compact then math.max(200, 16 + (#rows + (if lockedText then 1 else 0)) * 52)
		else math.clamp(Components.StatusCardWidth(#rows, lockedText ~= nil, tileWidth), 260, 360)
	local leftTop = L.TopZone
	local leftBottom = screen.Y - currencyBottom - Components.CurrencyBarHeight - L.StackGap
	local rightTop = L.TopZone + (if goal then L.GoalCardHeight + L.ZoneGap else 0)
	local rightBottom = screen.Y - L.Edge - powerHeight - L.StackGap
	local leftSize = railSize(#leftButtons, leftBottom - leftTop)
	local rightSize = railSize(#rightButtons, rightBottom - rightTop)

	local breakdown = {}
	for uuid, power in pairs(profile and profile.SquadPowerByHero or {}) do
		local hero = profile.Heroes and profile.Heroes[uuid]
		table.insert(breakdown, { Name = hero and hero.DisplayName or "Hero", Power = power })
	end
	table.sort(breakdown, function(a, b) return a.Power > b.Power end)

	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Goal = e(Components.NextGoalCard, { Goal = goal }),
		LeftRail = rail("LeftRail", "Left", leftTop, leftSize, leftButtons),
		RightRail = rail("RightRail", "Right", rightTop, rightSize, rightButtons),
		Status = if profile then e(Components.SquadStatusCard, {
			Rows = rows, LockedText = lockedText, LockedRange = lockedRange, Compact = compact, TileWidth = tileWidth,
			OnRow = function() call("OpenMasterModal", "SQUAD") end,
			OnLocked = function() call("OpenFacilityHUD", "FortressTree") end,
		}) else nil,
		Currency = if profile then e(Components.CurrencyBar, {
			Gold = profile.Currencies and profile.Currencies.Gold or 0,
			Gems = profile.Currencies and profile.Currencies.Gems or 0,
			Bottom = currencyBottom, Width = currencyWidth,
		}) else nil,
		Power = if profile then e(Components.SquadPowerBadge, {
			Power = profile.SquadPower or 0, Breakdown = breakdown, Compact = compact,
		}) else nil,
		-- Screens and the Pit tabs render above the building screens; the zones above stay behind them.
		Overlay = ReactRoblox.createPortal({
		PitTabs = (function()
			local active, anchor = pitState(props.Root)
			if not active or not anchor then return nil end
			return e(Components.PitTabs, { Active = active, Center = anchor, OnSelect = function(tab) call("OpenFacilityHUD", tab) end })
		end)(),
		Facility = if facilityOpen then e(FacilityPanel, { Facility = facilityOpen, Profile = profile, Width = screen.X,
			OnClose = function() setFacilityOpen(nil) end }) else nil,
		Shop = if shopOpen then e(ShopPanel, { Profile = profile, Width = screen.X, OnClose = function() setShopOpen(false) end }) else nil,
		Index = if indexOpen then e(HeroIndex, { Profile = profile, Width = screen.X, OnClose = function() setIndexOpen(false) end }) else nil,
		}, props.Overlay or props.Root),
	})
end

return HudApp
