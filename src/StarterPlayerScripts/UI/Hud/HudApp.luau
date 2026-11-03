--!strict
-- StarterPlayerScripts/UI/Hud/HudApp.luau
-- Phase 5 HUD root (§2): Left Rail (menus), Right Rail (combat), Next Goal card, Squad Status Card,
-- Squad Power badge and the Hero Index modal. Zones are placed from the live screen size so they
-- never overlap: the Right Rail starts below the goal card and stops above the power badge, the
-- Left Rail stops above the status card, the leaderboard stacks between the goal card and the Right
-- Rail, and rail buttons shrink (never below 44 px) to fit.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
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
		lockedText = string.format("Slots %d–%d · unlock in Upgrades", open + 1, TreeConfig.MaxSquadSlots)
	end
	return rows, lockedText
end

-- The legacy squad alerts (HUDController) that should open the Squad drawer while they show.
local function squadAlertShowing(): boolean
	local hud = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("MasterHUDScreenGui")
	if not hud then return false end
	for _, name in { "PartiallyDefeatedSquadBanner", "SquadWipeRecoveryBanner" } do
		local banner = hud:FindFirstChild(name)
		if banner and banner:IsA("GuiObject") and banner.Visible then return true end
	end
	return false
end

local function buildableNodes(profile: any): number
	if not profile or not (profile.Unlocks and profile.Unlocks.FortressTree) then return 0 end
	local tree = profile.FortressTree
	local gold = profile.Currencies and profile.Currencies.Gold or 0
	local floor = profile.HighestClearedFloor or 0
	local count = 0
	for _, node in TreeConfig.Nodes do
		if node.Kind ~= "LEVEL" or node.Default then
			continue
		end
		if node.Gold <= 0 or gold < node.Gold then
			continue
		end
		if FortressTree.CanUnlock(tree, node.Id, gold, floor, profile.Unlocks) then
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
	-- The window's top-centre, in the host's coordinates (the tab bar's fallback spot).
	return active, Vector2.new(top.X + window.AbsoluteSize.X / 2, top.Y)
end

local function railSize(count: number, available: number): number
	if count <= 0 then return L.RailButton end
	-- Each button is the icon plus ~20% for the label that overlaps its foot.
	local per = (available - (count - 1) * L.RailGap) / count / 1.2
	return math.clamp(math.floor(per), L.RailButtonMin, L.RailButton)
end

-- A rail of `size` buttons inside `available` px of height. When even 44 px buttons don't fit in one
-- column (short screens), the rail wraps into extra columns, growing inward from its screen edge,
-- so it never runs into the cards below it.
local function rail(name: string, side: "Left" | "Right", top: number, size: number, available: number, buttons: { any })
	local cellW = size + 24
	local cellH = size + math.floor(math.floor(size * 0.36) * 0.55) -- RailButton's own height
	local perColumn = math.max(1, math.floor((available + L.RailGap) / (cellH + L.RailGap)))
	local columns = math.max(1, math.ceil(#buttons / perColumn))
	local rows = math.min(#buttons, perColumn)
	local children: { [string]: any } = {
		Layout = e("UIGridLayout", {
			CellSize = UDim2.fromOffset(cellW, cellH),
			CellPadding = UDim2.fromOffset(L.RailGap, L.RailGap),
			FillDirection = Enum.FillDirection.Vertical,
			FillDirectionMaxCells = perColumn,
			SortOrder = Enum.SortOrder.LayoutOrder,
			StartCorner = if side == "Left" then Enum.StartCorner.TopLeft else Enum.StartCorner.TopRight,
		}),
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
		Size = UDim2.fromOffset(columns * cellW + (columns - 1) * L.RailGap, rows * cellH + (rows - 1) * L.RailGap),
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
	-- Squad drawer: the player's choice (kept in Store), plus a danger auto-expand that collapses
	-- 4 s after the danger clears. `layoutOpen` trails a collapse until the slide finishes, so the
	-- Left Rail never grows into the drawer mid-tween.
	local userOpen, setUserOpen = React.useState(Store.DrawerExpanded)
	local autoOpen, setAutoOpen = React.useState(false)
	local suppressAuto, setSuppressAuto = React.useState(false)
	local layoutOpen, setLayoutOpen = React.useState(Store.DrawerExpanded)
	local toggleRef = React.useRef(nil :: (() -> ())?)
	-- Leaderboard: nil follows the default (collapsed while the goal card shows), else the player's choice.
	local boardChoice, setBoardChoice = React.useState(Store.LeaderboardOpen)
	local boardToggleRef = React.useRef(nil :: (() -> ())?)
	-- Re-render when Roblox's top bar changes (the layout reads GuiService.TopbarInset live).
	React.useEffect(function()
		local conn = GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function() setTick(os.clock()) end)
		return function() conn:Disconnect() end
	end, {})

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
	local roomForCard = screen.X - 2 * L.Edge - L.PowerBadgeWidth - L.ZoneGap - Components.DrawerTabWidth
	local tileWidth = Components.StatusTileMax
	if not compact then
		local fixed = Components.StatusCardWidth(0, lockedText ~= nil, 0) + #rows * 6
		tileWidth = math.min(Components.StatusTileMax, math.floor((roomForCard - fixed) / math.max(1, #rows)))
		if tileWidth < Components.StatusTileMin then compact = true end
	end
	local cardHeight = Components.StatusCardHeight(#rows, lockedText ~= nil, compact)

	-- Danger (a hero Down, or a squad alert) opens the drawer; phones stay collapsed unless tapped.
	local phone = screen.X < 700
	local danger = squadAlertShowing()
	for _, r in rows do if r.State == "Down" then danger = true end end
	local drawerOpen = userOpen or (autoOpen and not phone)
	React.useEffect(function()
		if danger then
			if not suppressAuto then setAutoOpen(true) end
			return nil
		end
		setSuppressAuto(false)
		local alive = true
		task.delay(4, function() if alive then setAutoOpen(false) end end)
		return function() alive = false end
	end, { danger })
	React.useEffect(function()
		if drawerOpen then
			setLayoutOpen(true)
			return nil
		end
		local alive = true
		task.delay(Components.DrawerTween, function() if alive then setLayoutOpen(false) end end)
		return function() alive = false end
	end, { drawerOpen })
	toggleRef.current = function()
		if drawerOpen then
			-- Closing during danger keeps it closed until that danger clears.
			setUserOpen(false)
			setAutoOpen(false)
			if danger then setSuppressAuto(true) end
			Store.DrawerExpanded = false
		else
			setUserOpen(true)
			Store.DrawerExpanded = true
		end
	end
	-- C / gamepad Y toggle the drawer. They pass through while a modal is open, and Y also passes
	-- while a ProximityPrompt (which uses Y on gamepads) is on screen.
	React.useEffect(function()
		local prompts: { [ProximityPrompt]: boolean } = {}
		local conns = {
			ProximityPromptService.PromptShown:Connect(function(prompt) prompts[prompt] = true end),
			ProximityPromptService.PromptHidden:Connect(function(prompt) prompts[prompt] = nil end),
		}
		ContextActionService:BindAction("HudSquadDrawer", function(_, state, input)
			if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
			local modal = _G.IsAnyMasterModalOpen and _G.IsAnyMasterModalOpen()
			if modal or (input.KeyCode == Enum.KeyCode.ButtonY and next(prompts) ~= nil) then return Enum.ContextActionResult.Pass end
			if toggleRef.current then toggleRef.current() end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.C, Enum.KeyCode.ButtonY)
		-- Tab toggles the leaderboard (the CoreGui player list is disabled).
		ContextActionService:BindAction("HudLeaderboard", function(_, state)
			if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
			if (_G.IsAnyMasterModalOpen and _G.IsAnyMasterModalOpen()) or not boardToggleRef.current then return Enum.ContextActionResult.Pass end
			boardToggleRef.current()
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.Tab)
		return function()
			ContextActionService:UnbindAction("HudLeaderboard")
			ContextActionService:UnbindAction("HudSquadDrawer")
			for _, c in conns do c:Disconnect() end
		end
	end, {})
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
		table.insert(leftButtons, { Icon = "Fortress", Label = "Upgrades", Accent = Color3.fromRGB(214, 180, 120), Badge = buildableNodes(profile),
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

	-- Gold and Gems ride on the Squad drawer's top edge; the Left Rail stops above both. The rail
	-- uses the drawer's height until a collapse has finished sliding (`layoutOpen`).
	local currencyGap = 8
	local currencyBottom = L.Edge + Components.DrawerHeight(drawerOpen or layoutOpen, cardHeight) + currencyGap
	local currencyWidth = if compact then math.max(200, 16 + (#rows + (if lockedText then 1 else 0)) * 52)
		else math.clamp(Components.StatusCardWidth(#rows, lockedText ~= nil, tileWidth), 260, 360)
	-- Both rails start at the top of the safe area, just under Roblox's top bar.
	local leftTop = L.Edge
	local leftBottom = screen.Y - currencyBottom - Components.CurrencyBarHeight - L.StackGap
	local rightBottom = screen.Y - L.Edge - powerHeight - L.StackGap
	-- Top right, top to bottom: the leaderboard, in Roblox's top bar beside its right-hand buttons (its
	-- header centred in the strip, never wider than the free part), then the Next Goal card, then the
	-- Right Rail. Without room in the top bar the order is goal card, leaderboard, rail. The leaderboard
	-- shows only as many rows as fit above the rail at its minimum button size, and drops to its pill if
	-- none fit; phones always get the pill. Positions are in the Root's coordinates unless noted.
	-- Free part of Roblox's top bar, in screen pixels: the leaderboard sits at its right end. Read live,
	-- because it can still be empty when the HUD first renders. If Roblox reports no free area, use the
	-- whole strip (GetGuiInset height) up to 12 px from the right edge: with the CoreGui player list off,
	-- the right end of the bar is empty.
	local topbar = GuiService.TopbarInset
	if topbar.Width <= 0 or topbar.Height <= 0 then
		local cam = workspace.CurrentCamera
		local strip = (GuiService:GetGuiInset()).Y
		topbar = Rect.new(0, 0, (if cam then cam.ViewportSize.X else screen.X) - 4, strip)
	end
	local boardHost = LocalPlayer.PlayerGui:FindFirstChild("CustomLeaderboardGui") :: LayerCollector?
	-- TopbarInset is in screen pixels, but AbsolutePosition is measured from below the top bar (a
	-- layer that reaches into the bar reports y = -58): shift the top-bar rect into that space.
	local guiInset = (GuiService:GetGuiInset())
	local rootOrigin = props.Root.AbsolutePosition
	local hostOrigin = if boardHost then boardHost.AbsolutePosition else rootOrigin
	local boardInTopbar = boardHost ~= nil and topbar.Height >= Components.LeaderboardHeaderHeight
		and topbar.Width >= Components.LeaderboardPillWidth + 16
	local goalBlock = if goal then L.GoalCardHeight + L.ZoneGap else 0
	local boardTop = if boardInTopbar then topbar.Min.Y - guiInset.Y + (topbar.Height - Components.LeaderboardHeaderHeight) / 2 - rootOrigin.Y
		else L.Edge + goalBlock
	local boardWanted = if phone then false elseif boardChoice ~= nil then boardChoice else goal == nil
	local boardRows = 0
	if boardWanted then
		local railMin = #rightButtons * (math.ceil(L.RailButtonMin * 1.2) + L.RailGap)
		local room = rightBottom - boardTop - L.ZoneGap - railMin - (if boardInTopbar then goalBlock else 0)
		boardRows = #Store.Players
		while boardRows > 0 and Components.LeaderboardHeight(boardRows) > room do
			boardRows -= 1
		end
	end
	boardToggleRef.current = if phone then nil else function()
		Store.LeaderboardOpen = not boardWanted
		setBoardChoice(not boardWanted)
	end
	local boardBottom = boardTop + Components.LeaderboardHeight(boardRows)
	local goalTop = if boardInTopbar then math.max(L.Edge, boardBottom + L.ZoneGap) else L.Edge
	local rightTop = if boardInTopbar then math.max(L.Edge, boardBottom + L.ZoneGap) + goalBlock else boardBottom + L.ZoneGap
	-- Pit tabs (Synthesis / Promotion): centred in Roblox's top bar under the window, kept between
	-- Roblox's left buttons and the leaderboard. If they don't fit there, they straddle the window's top edge.
	local pitHost = props.Overlay or props.Root
	local pitActive, pitTop = pitState(pitHost)
	local pitCenter: Vector2? = nil
	if pitActive and pitTop then
		local hostOrigin2 = pitHost.AbsolutePosition
		local tabs = Components.PitTabsSize
		local boardWidth = math.min(if boardRows > 0 then Components.LeaderboardWidth else Components.LeaderboardPillWidth, topbar.Width - 16)
		local stripLeft = topbar.Min.X - guiInset.X + 8
		local stripRight = (if boardInTopbar then topbar.Max.X - guiInset.X - 8 - boardWidth else topbar.Max.X - guiInset.X) - 8
		if topbar.Height >= tabs.Y and stripRight - stripLeft >= tabs.X then
			local x = math.clamp(pitTop.X + hostOrigin2.X, stripLeft + tabs.X / 2, stripRight - tabs.X / 2)
			pitCenter = Vector2.new(x - hostOrigin2.X, topbar.Min.Y - guiInset.Y + topbar.Height / 2 - hostOrigin2.Y)
		else
			pitCenter = pitTop
		end
	end
	local leftSize = railSize(#leftButtons, leftBottom - leftTop)
	local rightSize = railSize(#rightButtons, rightBottom - rightTop)

	local breakdown = {}
	for uuid, power in pairs(profile and profile.SquadPowerByHero or {}) do
		local hero = profile.Heroes and profile.Heroes[uuid]
		table.insert(breakdown, { Name = hero and hero.DisplayName or "Hero", Power = power })
	end
	table.sort(breakdown, function(a, b) return a.Power > b.Power end)

	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Goal = e(Components.NextGoalCard, { Goal = goal, Top = goalTop }),
		-- Drawn into LeaderboardController's ScreenGui (DisplayOrder 8) when it exists.
		Leaderboard = ReactRoblox.createPortal({
			Panel = e(Components.Leaderboard, {
				Players = Store.Players, Max = Players.MaxPlayers, Top = boardTop + rootOrigin.Y - hostOrigin.Y, Rows = boardRows, Pill = phone,
				Right = if boardInTopbar then topbar.Max.X - guiInset.X - hostOrigin.X - 8 else nil,
				MaxWidth = if boardInTopbar then topbar.Width - 16 else nil,
				OnToggle = if phone then nil else function() if boardToggleRef.current then boardToggleRef.current() end end,
			}),
		}, LocalPlayer.PlayerGui:FindFirstChild("CustomLeaderboardGui") or props.Root),
		LeftRail = rail("LeftRail", "Left", leftTop, leftSize, leftBottom - leftTop, leftButtons),
		RightRail = rail("RightRail", "Right", rightTop, rightSize, rightBottom - rightTop, rightButtons),
		Status = if profile then e(Components.SquadDrawer, {
			Rows = rows, LockedText = lockedText, LockedRange = lockedRange, Compact = compact, TileWidth = tileWidth,
			CardHeight = cardHeight, Expanded = drawerOpen,
			OnToggle = function() if toggleRef.current then toggleRef.current() end end,
			OnRow = function() call("OpenMasterModal", "SQUAD") end,
			OnLocked = function() call("OpenFacilityHUD", "FortressTree") end,
			Above = e(Components.CurrencyBar, {
				Gold = profile.Currencies and profile.Currencies.Gold or 0,
				Gems = profile.Currencies and profile.Currencies.Gems or 0,
				Width = currencyWidth, Position = UDim2.fromScale(0, 1),
			}),
		}) else nil,
		Power = if profile then e(Components.SquadPowerBadge, {
			Power = profile.SquadPower or 0, Breakdown = breakdown, Compact = compact,
		}) else nil,
		-- Screens and the Pit tabs render above the building screens; the zones above stay behind them.
		Overlay = ReactRoblox.createPortal({
		PitTabs = (function()
			if not pitActive or not pitCenter then return nil end
			return e(Components.PitTabs, { Active = pitActive, Center = pitCenter, OnSelect = function(tab) call("OpenFacilityHUD", tab) end })
		end)(),
		Facility = if facilityOpen then e(FacilityPanel, { Facility = facilityOpen, Profile = profile, Width = screen.X,
			OnClose = function() setFacilityOpen(nil) end }) else nil,
		Shop = if shopOpen then e(ShopPanel, { Profile = profile, Width = screen.X, OnClose = function() setShopOpen(false) end }) else nil,
		Index = if indexOpen then e(HeroIndex, { Profile = profile, Width = screen.X, OnClose = function() setIndexOpen(false) end }) else nil,
		}, props.Overlay or props.Root),
	})
end

return HudApp
