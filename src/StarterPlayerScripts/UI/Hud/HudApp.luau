--!strict
-- StarterPlayerScripts/UI/Hud/HudApp.luau
-- Phase 5 HUD root (§2): Left Rail (menus), Right Rail (combat), Next Goal card, Squad Status Card,
-- Squad Power badge and the Hero Index modal. Zones are placed from the live screen size so they
-- never overlap: the Right Rail starts below the goal card and stops above the power badge, the
-- Left Rail stops above the status card, and rail buttons shrink (never below 44 px) to fit. The
-- player list is Roblox's default CoreGui PlayerList (Tab toggles it).

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local ReactRoblox = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("ReactRoblox"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local HeroCatalog = require(Shared:WaitForChild("Config"):WaitForChild("HeroCatalog"))
local TreeConfig = require(Shared:WaitForChild("Config"):WaitForChild("FortressTreeConfig"))
local FortressTree = require(Shared:WaitForChild("Util"):WaitForChild("FortressTree"))
local StatFormulas = require(Shared:WaitForChild("Util"):WaitForChild("StatFormulas"))

local Theme = require(script.Parent:WaitForChild("Theme"))
local Store = require(script.Parent:WaitForChild("Store"))
local WindowManager = require(script.Parent.Parent:WaitForChild("WindowManager"))
local Whistles = require(script.Parent:WaitForChild("Whistles"))
local Components = require(script.Parent:WaitForChild("Components"))
local HeroIndex = require(script.Parent:WaitForChild("HeroIndex"))
local BackpackPanel = require(script.Parent:WaitForChild("BackpackPanel"))
local FacilityPanel = require(script.Parent:WaitForChild("FacilityPanel"))
local ShopPanel = require(script.Parent:WaitForChild("ShopPanel"))
local RewardsPanel = require(script.Parent:WaitForChild("RewardsPanel"))
local RewardsStore = require(script.Parent:WaitForChild("RewardsStore"))
local TowerEventHud = require(script.Parent:WaitForChild("TowerEventHud"))
local RaidHud = require(script.Parent:WaitForChild("RaidHud"))

-- Support facilities shown in the Phase 5 gothic panel.
local PANEL_FACILITIES = { GuardPost = true, Market = true, TrainingGrounds = true, GodsBlessing = true }

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local TeleportRequest: RemoteEvent? = Remotes:FindFirstChild("TeleportRequest") :: RemoteEvent?
if not TeleportRequest then
	task.spawn(function()
		TeleportRequest = Remotes:WaitForChild("TeleportRequest", 10) :: RemoteEvent?
	end)
end

local lastTeleportClock = 0
local function requestTeleport(destination: "Island" | "Hub" | "Tower" | "TowerGate")
	local now = os.clock()
	if now - lastTeleportClock < 1.5 then
		return
	end
	lastTeleportClock = now
	if _G.SetViewSquad and _G.IsViewingSquad and _G.IsViewingSquad() then
		_G.SetViewSquad(false)
	end
	if not TeleportRequest then
		TeleportRequest = Remotes:FindFirstChild("TeleportRequest") :: RemoteEvent?
	end
	if TeleportRequest then
		TeleportRequest:FireServer(destination)
	else
		warn("[HudApp] TeleportRequest remote not found!")
	end
end

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
				LevelText = StatFormulas.LevelText(hero),
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
				row.State = if Store.SquadAssignment ~= nil then ("Floor " .. tostring(Store.SquadAssignment)) else "Resting"
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

local function isFloorBossBannerVisible(): boolean
	local hud = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("MasterHUDScreenGui")
	local banner = hud and hud:FindFirstChild("FloorBossTopBanner")
	return banner ~= nil and banner:IsA("GuiObject") and banner.Visible
end

-- Heroes on the bench and fit to fight (the Squad rail badge).
local function benchedHeroes(profile: any): number
	local count, now = 0, os.time()
	for _, hero in pairs(profile and profile.Heroes or {}) do
		if hero.Assignment == "BENCHED" and (hero.ComaUntilTimestamp or 0) <= now then count += 1 end
	end
	return count
end

-- True when artifacts or heroes fill 90% or more of their backpack cap (the Backpack rail badge).
local function backpackNearlyFull(profile: any): boolean
	if not profile then return false end
	local InventoryCapacity = require(Shared:WaitForChild("Util"):WaitForChild("InventoryCapacity"))
	local artifacts = InventoryCapacity.ArtifactCount(profile) / math.max(1, InventoryCapacity.ArtifactCap(profile.FortressTree))
	local heroes = InventoryCapacity.HeroCount(profile) / math.max(1, InventoryCapacity.HeroCap(profile.FortressTree))
	return artifacts >= 0.9 or heroes >= 0.9
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

local function railSize(count: number, available: number): number
	if count <= 0 then return L.RailButton end
	-- Each button is the icon plus ~20% for the label that overlaps its foot.
	local per = (available - (count - 1) * L.RailGap) / count / 1.2
	return math.clamp(math.floor(per), L.RailButtonMin, L.RailButton)
end

-- A rail of `size` buttons inside `available` px of height. When even 44 px buttons don't fit in one
-- column (short screens), the rail wraps into extra columns, growing inward from its screen edge,
-- so it never runs into the cards below it.
local function rail(name: string, side: "Left" | "Right", top: number, bottom: number, size: number, available: number, buttons: { any }, screenY: number)
	local cellW = size + 24
	local cellH = size + math.floor(math.floor(size * 0.36) * 0.55) -- RailButton's own height
	local perColumn = math.max(1, math.floor((available + L.RailGap) / (cellH + L.RailGap)))
	local columns = math.max(1, math.ceil(#buttons / perColumn))
	local rows = math.min(#buttons, perColumn)
	local totalW = columns * cellW + (columns - 1) * L.RailGap
	local totalH = rows * cellH + (rows - 1) * L.RailGap

	-- Vertically center the rail on the screen, clamped safely between top and bottom boundaries
	local desiredCenterY = screenY * 0.5
	local minY = top + totalH / 2
	local maxY = bottom - totalH / 2
	local centerY = if maxY >= minY then math.clamp(desiredCenterY, minY, maxY) else (top + bottom) / 2

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
		b.TipSide = if side == "Left" then "Right" else "Left"
		children["B" .. i] = e(Components.RailButton, b)
	end
	return e("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(if side == "Left" then 0 else 1, 0.5),
		Position = if side == "Left" then UDim2.fromOffset(L.Edge, math.round(centerY)) else UDim2.new(1, -L.Edge, 0, math.round(centerY)),
		Size = UDim2.fromOffset(totalW, totalH),
		BackgroundTransparency = 1,
	}, children)
end

local currentFacilityOpen: string? = nil
local currentIndexOpen = false
local currentShopOpen = false
local currentRewardsOpen = false
local currentBackpackOpen = false

local function HudApp(props: { Root: GuiObject, Overlay: GuiObject? })
	local _, setRevision = React.useState(0)
	local _, setTick = React.useState(0)
	local screen, setScreen = React.useState(props.Root.AbsoluteSize)
	-- Re-render when any window opens or closes (the HUD currency bar follows the top window).
	local _, setWindowTick = React.useState(0)
	React.useEffect(function()
		local conn = WindowManager.Changed:Connect(function() setWindowTick(function(n: number) return n + 1 end) end)
		return function() conn:Disconnect() end
	end, {})
	local indexOpen, setIndexOpen = React.useState(false)
	local indexInitialMode, setIndexInitialMode = React.useState("HEROES" :: "HEROES" | "ARTIFACTS")
	local facilityOpen, setFacilityOpen = React.useState(nil :: string?)
	local shopOpen, setShopOpen = React.useState(false)
	local rewardsOpen, setRewardsOpen = React.useState(false)
	local backpackOpen, setBackpackOpen = React.useState(false)
	local backpackButton = React.useRef(nil :: GuiButton?)
	local closeBackpack = React.useCallback(function()
		if not currentBackpackOpen and not backpackOpen then return end
		currentBackpackOpen = false
		setBackpackOpen(false)
		call("SetModalFocusMode", false)
	end, { backpackOpen })
	local returnBackpackFocus = React.useCallback(function()
		local button = backpackButton.current
		if button and UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then
			GuiService.SelectedObject = button
		end
	end, {})
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
		_G.OpenBackpack = function()
			currentFacilityOpen = nil
			currentShopOpen = false
			currentRewardsOpen = false
			currentIndexOpen = false
			currentBackpackOpen = true
			call("OpenMasterModal", "BACKPACK")
			setFacilityOpen(nil)
			setShopOpen(false)
			setRewardsOpen(false)
			setIndexOpen(false)
			setBackpackOpen(true)
			call("SetModalFocusMode", true)
		end
		_G.IsBackpackOpen = function() return currentBackpackOpen end
		_G.CloseBackpack = closeBackpack
		return function()
			_G.OpenBackpack = nil
			_G.IsBackpackOpen = nil
			_G.CloseBackpack = nil
		end
	end, { backpackOpen, closeBackpack })

	React.useEffect(function()
		_G.OpenHeroIndex = function(mode: string?)
			currentFacilityOpen = nil
			currentShopOpen = false
			currentRewardsOpen = false
			currentIndexOpen = true
			call("OpenMasterModal", "INDEX")
			if mode == "ARTIFACTS" or mode == "HEROES" then
				setIndexInitialMode(mode :: any)
			end
			setFacilityOpen(nil)
			setShopOpen(false)
			setRewardsOpen(false)
			setIndexOpen(true)
			setNewHeroes(0)
			call("SetModalFocusMode", true)
		end
		_G.OpenArtifactIndex = function()
			currentFacilityOpen = nil
			currentShopOpen = false
			currentRewardsOpen = false
			currentIndexOpen = true
			call("OpenMasterModal", "INDEX")
			setIndexInitialMode("ARTIFACTS")
			setFacilityOpen(nil)
			setShopOpen(false)
			setRewardsOpen(false)
			setIndexOpen(true)
			call("SetModalFocusMode", true)
		end
		_G.IsHeroIndexOpen = function() return currentIndexOpen or currentShopOpen or currentRewardsOpen end
		_G.IsFacilityPanelOpen = function(): boolean
			return currentFacilityOpen ~= nil
		end
		_G.CloseFacilityPanel = function()
			if currentFacilityOpen == nil and facilityOpen == nil then return end
			currentFacilityOpen = nil
			setFacilityOpen(nil)
			call("SetModalFocusMode", false)
		end
		_G.CloseHeroIndex = function()
			if not currentIndexOpen and not currentShopOpen and not currentRewardsOpen and not indexOpen and not shopOpen and not rewardsOpen then return end
			currentIndexOpen = false
			currentShopOpen = false
			currentRewardsOpen = false
			setIndexOpen(false)
			setShopOpen(false)
			setRewardsOpen(false)
			call("SetModalFocusMode", false)
		end
		-- Robux Store (Phase 5): the Shop button on the Right Rail.
		_G.OpenRobuxShop = function()
			currentFacilityOpen = nil
			currentIndexOpen = false
			currentShopOpen = true
			currentRewardsOpen = false
			call("OpenMasterModal", "SHOP")
			setIndexOpen(false)
			setFacilityOpen(nil)
			setRewardsOpen(false)
			setShopOpen(true)
			call("SetModalFocusMode", true)
		end
		-- Rewards (GDD §4.8): shares the Index / Store panel slot.
		_G.OpenRewards = function()
			currentFacilityOpen = nil
			currentIndexOpen = false
			currentShopOpen = false
			currentRewardsOpen = true
			call("OpenMasterModal", "SHOP")
			setIndexOpen(false)
			setFacilityOpen(nil)
			setShopOpen(false)
			setRewardsOpen(true)
			call("SetModalFocusMode", true)
		end
		_G.OpenFacilityPanel = function(facility: string): boolean
			if not PANEL_FACILITIES[facility] then return false end
			currentFacilityOpen = facility
			currentIndexOpen = false
			currentShopOpen = false
			currentRewardsOpen = false
			call("OpenMasterModal", "FACILITY")
			setIndexOpen(false)
			setShopOpen(false)
			setRewardsOpen(false)
			setFacilityOpen(facility)
			call("SetModalFocusMode", true)
			return true
		end
	end, { indexOpen, facilityOpen, shopOpen, rewardsOpen })

	local raid = RaidHud.useRaid() -- raid arena state: swaps the Right Rail for the damage leaderboard
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
	local assignButtonWidth = 80
	local roomForCard = screen.X - 2 * L.Edge - L.PowerBadgeWidth - L.ZoneGap - Components.DrawerTabWidth - assignButtonWidth
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
		return function()
			ContextActionService:UnbindAction("HudSquadDrawer")
			for _, c in conns do c:Disconnect() end
		end
	end, {})

	local openSquad = function() call("OpenMasterModal", "SQUAD") end
	local leftButtons = {
		{
			Name = "SquadRailButton",
			Icon = "Squad",
			Label = "Squad",
			Accent = Color3.fromRGB(56, 189, 248), -- #38BDF8 Azure
			-- "!" while a slot is open and a hero is free to fill it.
			Badge = if emptySlots > 0 and benchedHeroes(profile) > 0 then "!" else nil,
			OnActivated = openSquad,
		},
		{
			Icon = "Shop",
			Label = "Store",
			Accent = Color3.fromRGB(250, 204, 21), -- #FACC15 Gold
			Wiggle = not shopOpen,
			OnActivated = function()
				if _G.OpenRobuxShop then
					_G.OpenRobuxShop()
				end
			end,
		},
		{
			Name = "RewardsRailButton",
			Icon = "Gems",
			Label = "Rewards",
			Accent = Color3.fromRGB(74, 222, 128), -- #4ADE80 Green
			-- Daily, weekly and playtime rewards ready to claim.
			Badge = RewardsStore.Claimable(),
			OnActivated = function()
				if _G.OpenRewards then
					_G.OpenRewards()
				end
			end,
		},
		{
			Icon = "Fortress",
			Label = "Upgrades",
			Accent = Color3.fromRGB(192, 132, 252), -- #C084FC Violet
			Badge = buildableNodes(profile),
			OnActivated = function()
				call("OpenFacilityHUD", "FortressTree")
			end,
		},
		{
			Icon = "Index",
			Label = "Index",
			Accent = Color3.fromRGB(251, 191, 36), -- #FBBF24 Amber / Gold
			Badge = newHeroes,
			OnActivated = function()
				if _G.OpenHeroIndex then
					_G.OpenHeroIndex()
				end
			end,
		},
		{
			Icon = "Backpack",
			Label = "Backpack",
			-- "!" when artifacts or heroes are at 90% of capacity (summons and drops start failing when full).
			Badge = if backpackNearlyFull(profile) then "!" else nil,
			Accent = Color3.fromRGB(243, 199, 119),
			ButtonRef = backpackButton,
			OnActivated = function()
				if _G.OpenBackpack then
					_G.OpenBackpack()
				else
					currentBackpackOpen = true
					call("OpenMasterModal", "BACKPACK")
					setBackpackOpen(true)
					call("SetModalFocusMode", true)
				end
			end,
		},
	}

	local overdriveBlocked = Whistles.Blocked("Overdrive")
	local recallBlocked = Whistles.Blocked("Recall")
	local rightButtons = {
		{
			Icon = "Island",
			Label = "Island",
			Accent = Color3.fromRGB(52, 211, 153), -- #34D399 Emerald
			OnActivated = function()
				requestTeleport("Island")
			end,
		},
		{
			Icon = "Hub",
			Label = "Hub",
			Accent = Color3.fromRGB(245, 158, 11), -- #F59E0B Royal Amber
			OnActivated = function()
				requestTeleport("Hub")
			end,
		},
		{
			Icon = "Tower",
			Label = "Tower",
			Accent = Color3.fromRGB(239, 68, 68), -- #EF4444 Crimson
			OnActivated = function()
				requestTeleport("Tower")
			end,
		},
		{
			Icon = "Overdrive",
			Label = "Overdrive",
			Accent = Color3.fromRGB(245, 158, 11),
			KeyHint = "Q",
			Cooldown = Whistles.Remaining("Overdrive"),
			CooldownTotal = Whistles.Cooldown.Overdrive,
			Disabled = overdriveBlocked ~= nil,
			DisabledReason = overdriveBlocked,
			OnActivated = function()
				Whistles.Fire("Overdrive")
			end,
		},
		{
			Icon = "Recall",
			Label = "Recall",
			Accent = Color3.fromRGB(34, 211, 238),
			KeyHint = "E",
			Cooldown = Whistles.Remaining("Recall"),
			CooldownTotal = Whistles.Cooldown.Recall,
			Disabled = recallBlocked ~= nil,
			DisabledReason = recallBlocked,
			OnActivated = function()
				Whistles.Fire("Recall")
			end,
		},
	}

	-- Gold and Gems ride on the Squad drawer's top edge; the Left Rail stops above both. The rail
	-- uses the drawer's height until a collapse has finished sliding (`layoutOpen`).
	local currencyGap = 8
	local currencyBottom = L.Edge + Components.DrawerHeight(drawerOpen or layoutOpen, cardHeight) + currencyGap
	-- Both rails start at the top of the safe area, just under Roblox's top bar.
	local leftTop = L.Edge
	local leftBottom = screen.Y - currencyBottom - Components.CurrencyBarHeight - L.StackGap
	-- The timed tower event badge (Phase G) sits 8 px above Squad Power; the Right Rail stops above both.
	local powerDrawn = if compact then 44 else L.PowerBadgeHeight
	local eventBottom = L.Edge + powerDrawn + 8
	local eventHeight = if compact then 40 else L.EventBadgeHeight
	-- While the Raid Portal is open (outside the arena), the raid chip stacks above the event badge.
	local raidChip = RaidHud.ChipVisible(raid.Phase, raid.InRaid)
	local raidChipBottom = eventBottom + eventHeight + 8
	local rightBottom = screen.Y - eventBottom - eventHeight - L.StackGap - (if raidChip then RaidHud.ChipHeight + 8 else 0)
	-- Top right, top to bottom: the Next Goal card, then the Right Rail. Positions are in the Root's
	-- coordinates unless noted.
	local goalBlock = if goal then Components.GoalCardHeight(goal, Store.GuideV2) + L.ZoneGap else 0
	local goalTop = L.TopZone
	local rightTop = L.TopZone + goalBlock
	do
		local open = drawerOpen or layoutOpen
		local cardWidth = if compact then 20 + (#rows + (if lockedText then 1 else 0)) * 54
			else Components.StatusCardWidth(#rows, lockedText ~= nil, tileWidth)
		local width = if open then cardWidth + Components.DrawerTabWidth else Components.StripWidth(#rows, lockedText ~= nil)
		Store.DrawerRight = L.Edge + width + assignButtonWidth
		Store.DrawerTop = currencyBottom + Components.CurrencyBarHeight
	end
	local leftSize = railSize(#leftButtons, leftBottom - leftTop)
	local rightSize = railSize(#rightButtons, rightBottom - rightTop)

	local breakdown = {}
	for uuid, power in pairs(profile and profile.SquadPowerByHero or {}) do
		local hero = profile.Heroes and profile.Heroes[uuid]
		table.insert(breakdown, { Name = hero and hero.DisplayName or "Hero", Power = power })
	end
	table.sort(breakdown, function(a, b) return a.Power > b.Power end)

	local hasSquadHeroes = false
	for _, r in rows do
		if r.Hero then hasSquadHeroes = true break end
	end

	local modalFocus = Store.ModalFocus

	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Goal = if not modalFocus then e(Components.NextGoalCard, {
			Goal = goal, Top = goalTop, GuideAction = if Store.GuideV2 then Store.GuideAction else nil, GuideVisible = Store.GuideVisible,
		}) else nil,
		LeftRail = if not modalFocus then rail("LeftRail", "Left", leftTop, leftBottom, leftSize, leftBottom - leftTop, leftButtons, screen.Y) else nil,
		RightRail = if modalFocus then nil
			elseif raid.InRaid then e(RaidHud.Leaderboard, { Top = rightTop, Bottom = rightBottom, Compact = compact })
			else rail("RightRail", "Right", rightTop, rightBottom, rightSize, rightBottom - rightTop, rightButtons, screen.Y),
		-- Raid: Leave sits bottom centre, just above the Squad Status card (it tracks the drawer's slide).
		RaidLeave = if not modalFocus and raid.InRaid then e(RaidHud.LeaveButton, {
			Bottom = L.Edge + Components.DrawerHeight(drawerOpen or layoutOpen, cardHeight) + 12,
		}) else nil,
		RaidChip = if not modalFocus and raidChip then e(RaidHud.HubChip, { Bottom = raidChipBottom, Compact = compact }) else nil,
		Status = if not modalFocus and profile then e(Components.SquadDrawer, {
			Rows = rows, LockedText = lockedText, LockedRange = lockedRange, Compact = compact, TileWidth = tileWidth,
			CardHeight = cardHeight, Expanded = drawerOpen,
			SquadAssignment = Store.SquadAssignment,
			OnAssignSquad = function() call("OpenTowerSelector", "ASSIGN") end,
			OnToggle = function() if toggleRef.current then toggleRef.current() end end,
			OnRow = openSquad,
			OnLocked = function() call("OpenFacilityHUD", "FortressTree") end,
			Above = e(Components.CurrencyBar, {
				Gold = profile.Currencies and profile.Currencies.Gold or 0,
				Gems = profile.Currencies and profile.Currencies.Gems or 0,
				Position = UDim2.fromScale(0, 1),
				Width = Components.CurrencyBarWidth,
			}),
		}) else nil,
		ViewSquad = if not modalFocus and hasSquadHeroes and (Store.SquadAssignment ~= nil or Store.ViewingSquad) and not (_G.IsDuelActive and _G.IsDuelActive()) then e(Components.ViewSquadBar, {
			SquadAssignment = Store.SquadAssignment,
			PlayerFloorId = Store.PlayerFloorId,
			ViewingSquad = Store.ViewingSquad,
			Compact = compact,
			Top = if isFloorBossBannerVisible() then 96 else 14,
			OnToggleView = function() call("ToggleViewSquad") end,
			OnRecall = function() call("TowerRecallSquad") end,
		}) else nil,
		TowerEvent = if not modalFocus then e(TowerEventHud.Badge, { Compact = compact, Bottom = eventBottom }) else nil,
		Power = if not modalFocus and profile then e(Components.SquadPowerBadge, {
			Power = profile.SquadPower or 0, Breakdown = breakdown, Compact = compact,
		}) else nil,
		-- Screens and the Pit tabs render above the building screens; the zones above stay behind them.
		Overlay = ReactRoblox.createPortal({
		-- Over an open window, only when that window has no currency display of its own (Forge, Store,
		-- Index and the Pit draw theirs or spend nothing): the HUD bar used to overlap their corners.
		FocusCurrency = if modalFocus and profile and WindowManager.WantsHudCurrency() then e("Frame", {
			Name = "ModalFocusCurrencyWrapper",
			Position = UDim2.new(0, L.Edge, 1, -L.Edge),
			AnchorPoint = Vector2.new(0, 1),
			Size = UDim2.fromOffset(Components.CurrencyBarWidth, Components.CurrencyBarHeight),
			BackgroundTransparency = 1,
			ZIndex = 50,
		}, {
			Bar = e(Components.CurrencyBar, {
				Gold = profile.Currencies and profile.Currencies.Gold or 0,
				Gems = profile.Currencies and profile.Currencies.Gems or 0,
				Position = UDim2.fromScale(0, 1),
				Width = Components.CurrencyBarWidth,
			}),
		}) else nil,
		-- Close buttons go through WindowManager, which shrinks the panel out and then calls the
		-- _G.Close* function that clears the state (the same path Backspace takes).
		Facility = if facilityOpen then e(FacilityPanel, { Facility = facilityOpen, Profile = profile, Width = screen.X,
			OnClose = function() WindowManager.Close("FacilityPanel") end,
		}) else nil,
		Shop = if shopOpen then e(ShopPanel, { Profile = profile, Width = screen.X, OnClose = function() WindowManager.Close("Index") end }) else nil,
		Rewards = if rewardsOpen then e(RewardsPanel, { Width = screen.X, OnClose = function() WindowManager.Close("Index") end }) else nil,
		TowerEventPopup = e(TowerEventHud.Popup, { Blocked = facilityOpen ~= nil or shopOpen or rewardsOpen or indexOpen or modalFocus }),
		RaidResults = e(RaidHud.ResultsCard, { Blocked = facilityOpen ~= nil or shopOpen or rewardsOpen or indexOpen or modalFocus }),
		Index = if indexOpen then e(HeroIndex, { Profile = profile, Width = screen.X, InitialMode = indexInitialMode, OnClose = function() WindowManager.Close("Index") end }) else nil,
		Backpack = if backpackOpen then e(BackpackPanel, {
			Width = screen.X, Height = screen.Y,
			OnClose = function()
				if WindowManager.IsOpen("Backpack") then
					WindowManager.Close("Backpack")
				else
					closeBackpack()
				end
			end,
			ReturnFocus = returnBackpackFocus,
		}) else nil,
		}, props.Overlay or props.Root),
	})
end

return HudApp
