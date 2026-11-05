--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local React = require(ReplicatedStorage.Packages.React)
local Catalog = require(ReplicatedStorage.Shared.Config.ArtifactCatalog)
local C = require(script.Parent.Components)
local Model = require(script.Parent.Model)
local T = require(script.Parent.Tokens)
local useForge = require(script.Parent.useForge)
local Screens = require(script.Parent.Screens)
local Sell = require(script.Parent.Sell)
local Balance = require(ReplicatedStorage.Shared.Config.StatBalance)
local UIFeel = require(script.Parent.Parent.UIFeel)
local Types = require(script.Parent.Types)
local e = React.createElement

local function UndoButton(props: { ExpiresAt: number, OnUndo: () -> (), Busy: boolean })
	local seconds, setSeconds = React.useState(math.max(0, math.ceil(props.ExpiresAt - Workspace:GetServerTimeNow())))
	React.useEffect(function()
		local alive = true
		task.spawn(function()
			while alive do
				local remaining = math.max(0, math.ceil(props.ExpiresAt - Workspace:GetServerTimeNow()))
				setSeconds(remaining)
				if remaining == 0 then break end
				task.wait(1)
			end
		end)
		return function() alive = false end
	end, { props.ExpiresAt })
	return e(C.Button, { Name = "UndoEquipmentButton", Size = UDim2.fromScale(1, 1), Text = if seconds > 0 then string.format("Undo (%ds)", seconds) else "Undo expired", Disabled = seconds <= 0 or props.Busy, OnActivate = props.OnUndo })
end

local function Feedback(props: { Text: string, Success: boolean, Sequence: number })
	local ref = React.useRef(nil)
	React.useEffect(function()
		if not ref.current or UIFeel.ReducedMotion() or props.Sequence == 0 then return end
		ref.current.Scale = 0.98
		local tween = TweenService:Create(ref.current, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		tween:Play()
		UIFeel.Sfx(if props.Success then "StarTick" else "Error")
		return function() tween:Cancel() end
	end, { props.Sequence })
	return e("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		Scale = e("UIScale", { ref = ref }),
		Text = e(C.Text, { Text = props.Text, TextColor3 = if props.Success then T.Good else T.Text, TextSize = 14, Size = UDim2.fromScale(1, 1) }),
	})
end

local function Dialog(props: { Title: string, Children: { [string]: any }, OnCancel: () -> (), FocusKey: string })
	local ref = React.useRef(nil)
	React.useEffect(function()
		local previous = GuiService.SelectedObject
		if ref.current and UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then GuiService:Select(ref.current) end
		return function()
			if previous and previous.Parent then GuiService.SelectedObject = previous end
		end
	end, { props.FocusKey })
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 100 }, {
		Shade = e("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(), BackgroundTransparency = 0.2, Text = "", AutoButtonColor = false, Selectable = false, ZIndex = 1, [React.Event.Activated] = props.OnCancel }),
		Dialog = e("Frame", {
			ref = ref, Size = UDim2.new(0.94, 0, 0.92, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = T.Background, BorderSizePixel = 0, ZIndex = 2,
			SelectionGroup = true, SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
			SelectionBehaviorDown = Enum.SelectionBehavior.Stop, SelectionBehaviorLeft = Enum.SelectionBehavior.Stop, SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
		}, {
			Constraint = e("UISizeConstraint", { MaxSize = Vector2.new(620, 760) }),
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 16) }),
			Outline = e("UIStroke", { Color = T.Gold, Thickness = 2 }),
			Title = e(C.Text, { Text = props.Title, TextColor3 = T.Gold, Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -88, 0, 56), TextSize = 18 }),
			Close = e(C.Button, { Text = "Back", Size = UDim2.fromOffset(64, 48), Position = UDim2.new(1, -80, 0, 12), OnActivate = props.OnCancel, FocusOrder = -100 }),
			Content = e(C.Scroll, { Size = UDim2.new(1, -16, 1, -88), Position = UDim2.fromOffset(8, 76), Children = props.Children }),
		}),
	})
end

local function App(props: Types.Props)
	local forge = useForge(props)
	local snapshot = forge.Snapshot
	local rootRef, bodyRef = React.useRef(nil), React.useRef(nil)
	local transitionRef = React.useRef(nil)
	local camera = workspace.CurrentCamera
	local screen, setScreen = React.useState(if camera then camera.ViewportSize else Vector2.new(1280, 720))
	local _, setBarTick = React.useState(0)
	local preferred, setPreferred = React.useState(UserInputService.PreferredInput)
	local route, setRoute = React.useState(if props.InitialPane == "SELL" then "SELL" elseif props.InitialMode == "UPGRADE" then "UPGRADE_PICK" else "INVENTORY")
	local dialog, setDialog = React.useState(nil :: string?)
	local review, setReview = React.useState(nil :: any)
	local filter, setFilter = React.useState({ Query = "", Ownership = "ALL", Rarity = 0, WeaponType = "ALL", Sort = "BEST" } :: Types.Filter)
	local handlers = React.useRef({ Back = function() end })
	local inputName = React.useRef("ForgeMenu_" .. HttpService:GenerateGUID(false))
	local busy = forge.Phase ~= "idle"
	local target = forge.TargetId and snapshot.Artifacts[forge.TargetId]
	local hero = forge.HeroId and snapshot.Heroes[forge.HeroId]
	local narrow = screen.X < 700
	local bar = GuiService.TopbarInset
	local tabsFitTopbar = bar.Height >= 44 and bar.Width >= math.min(420, screen.X - 24) + 16
	local top = if tabsFitTopbar then 16 else 72
	local width = math.min(960, screen.X - 32)
	local height = math.min(600, math.max(160, screen.Y - top - 20))
	local statusAction = forge.Undo ~= nil or forge.Phase == "uncertain"
	local statusHeight = if statusAction then 60 else 32
	local contentHeight = height - 68 - statusHeight - 16
	local contentWidth = width - 48
	local items = React.useMemo(function() return Model.inventory(snapshot, filter, forge.HeroId) end, { snapshot, filter, forge.HeroId })
	local heroes = React.useMemo(function() return Model.sortedHeroes(snapshot) end, { snapshot })
	local filterKey = table.concat({filter.Query, filter.Ownership, tostring(filter.Rarity), filter.WeaponType, filter.Sort}, "|")
	local equipReason = Model.equipReason(snapshot, forge.HeroId, forge.TargetId)
	local upgradeReason = Model.upgradeReason(snapshot, forge.TargetId, forge.Materials)
	local rule = target and Catalog.GetStarPromotionCost(target.Star)
	local maxRank = target ~= nil and rule == nil

	local function clearFilters()
		setFilter({ Query = "", Ownership = "ALL", Rarity = 0, WeaponType = "ALL", Sort = "BEST" })
	end
	local function updateFilter(key: string, value: any)
		setFilter(function(previous)
			local result: any = table.clone(previous)
			result[key] = value
			return result
		end)
	end
	local function inventory()
		setRoute("INVENTORY")
		forge.SetMode("EQUIP")
	end
	local function back()
		if dialog then setDialog(nil)
		elseif route == "SELL" then inventory()
		elseif route == "REVIEW" then setRoute("MATERIALS")
		elseif route == "MATERIALS" then setRoute("UPGRADE_PICK")
		elseif route ~= "INVENTORY" then inventory()
		else props.OnClose() end
	end
	handlers.current = { Back = back }
	local function chooseArtifact(id: string)
		if busy then return end
		if route == "MATERIALS" then forge.ToggleMaterial(id); return end
		if route == "UPGRADE_PICK" then forge.SelectTarget(id); forge.SetMode("UPGRADE"); clearFilters(); setRoute("MATERIALS"); return end
		forge.SelectTarget(id)
		forge.SetMode("EQUIP")
		local artifact = snapshot.Artifacts[id]
		if not Model.compatible(hero, artifact) then
			local owners = Model.ownerIds(snapshot, id)
			local chosen = #owners == 1 and snapshot.Heroes[owners[1]] or nil
			if chosen and Model.compatible(chosen, artifact) then forge.SetHero(chosen.UUID)
			else
				for _, entry in heroes do if Model.compatible(entry, artifact) then forge.SetHero(entry.UUID); break end end
			end
		end
		setRoute("DETAIL")
	end
	local function startUpgrade()
		if not target or busy then return end
		forge.SetMode("UPGRADE")
		clearFilters()
		setRoute("MATERIALS")
	end
	local function reviewUpgrade()
		if not target or not rule or upgradeReason or busy then return end
		local after = table.clone(target)
		after.Star += 1
		local materials = {}
		for _, id in forge.Materials do table.insert(materials, table.clone(snapshot.Artifacts[id])) end
		setReview({ Before = table.clone(target), After = after, Materials = materials, Gold = rule.Gold, Gems = rule.Gems, Revision = snapshot.Revision })
		setRoute("REVIEW")
	end

	React.useEffect(function()
		if rootRef.current then T.Theme.Frame(rootRef.current, { Class = "Window", Tone = "Violet", ZIndex = 2 }) end
		local barConnection = GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function() setBarTick(function(n) return n + 1 end) end)
		local inputConnection = UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function() setPreferred(UserInputService.PreferredInput) end)
		local context = Instance.new("InputContext")
		context.Name = inputName.current; context.Priority = 2500; context.Sink = false
		local action = Instance.new("InputAction")
		action.Name = "Back"; action.Type = Enum.InputActionType.Bool; action.Parent = context
		local binding = Instance.new("InputBinding")
		binding.KeyCode = Enum.KeyCode.ButtonB; binding.Parent = action
		action.Pressed:Connect(function() if not UserInputService:GetFocusedTextBox() then handlers.current.Back() end end)
		context.Parent = Players.LocalPlayer:WaitForChild("PlayerScripts")
		return function() context:Destroy(); barConnection:Disconnect(); inputConnection:Disconnect() end
	end, {})
	React.useEffect(function()
		if props.OnContextChanged then props.OnContextChanged(forge.HeroId, forge.TargetId, forge.Mode) end
	end, { forge.HeroId, forge.TargetId, forge.Mode })
	React.useEffect(function()
		if props.OnBusyChanged then props.OnBusyChanged(busy) end
		return function() if props.OnBusyChanged then props.OnBusyChanged(false) end end
	end, { busy })
	React.useEffect(function()
		if rootRef.current then rootRef.current:SetAttribute("ForgeView", route) end
  local scale = transitionRef.current
  local tween
  if scale and not UIFeel.ReducedMotion() then
   scale.Scale = if route == "RESULT" then 0.88 else 0.97
   tween = TweenService:Create(scale, TweenInfo.new(if route == "RESULT" then 0.4 else 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
   tween:Play()
  end
		if preferred == Enum.PreferredInput.Gamepad and bodyRef.current and not dialog then GuiService:Select(bodyRef.current) end
	end, { route, preferred, dialog })
	React.useEffect(function()
		if route ~= "INVENTORY" and route ~= "SELL" and route ~= "UPGRADE_PICK" and not target then inventory() end
	end, { target, route })
	React.useEffect(function()
		if route == "REVIEW" and forge.Success and forge.Sequence > 0 and forge.Phase == "idle" then setRoute("RESULT") end
	end, { forge.Sequence })

	local filterCount = (if filter.Ownership ~= "ALL" then 1 else 0) + (if filter.Rarity ~= 0 then 1 else 0) + (if filter.WeaponType ~= "ALL" then 1 else 0)
	local toolbar = e("Frame", { Name = "InventoryToolbar", Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1 }, {
		Search = e("TextBox", {
			Name = "ArtifactSearch", Text = filter.Query, PlaceholderText = "Search weapons…", ClearTextOnFocus = false,
			Size = UDim2.new(0.52, -4, 1, 0), BackgroundColor3 = T.Raised, BorderSizePixel = 0,
			FontFace = T.Theme.Fonts.Body, TextSize = 14, TextColor3 = T.Text, PlaceholderColor3 = T.Muted,
			[React.Change.Text] = function(box) updateFilter("Query", box.Text) end,
		}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }), Padding = e("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }) }),
		Filter = e(C.Button, { Name = "FilterArtifactsButton", Text = string.format("Filters (%d)", filterCount), Position = UDim2.fromScale(0.52, 0), Size = UDim2.new(0.24, -4, 1, 0), OnActivate = function() setDialog("FILTER") end }),
		Sort = e(C.Button, { Name = "SortArtifactsButton", Text = filter.Sort, Position = UDim2.fromScale(0.76, 0), Size = UDim2.fromScale(0.24, 1), OnActivate = function()
			local order = { "BEST", "POWER", "RARITY", "STARS", "NAME" }
			updateFilter("Sort", order[(table.find(order, filter.Sort) or 1) % #order + 1])
		end }),
	})
	local grid = e(C.InventoryGrid, {
		Snapshot = snapshot, Items = items, TargetId = forge.TargetId, MaterialIds = forge.Materials,
		MaterialMode = route == "MATERIALS", HeroId = forge.HeroId, Width = contentWidth,
		OnSelect = chooseArtifact, FilterKey = filterKey,
	})
	local view: { [string]: any } = { Scale = e("UIScale", { ref = transitionRef }) }
	if route == "SELL" then
		view.Sell = e(Sell, { OnCancel = inventory, Snapshot = snapshot, Items = items, Width = contentWidth, OnSellArtifacts = props.OnSellArtifacts, OnBusyChanged = props.OnBusyChanged or function() end })
	elseif route == "INVENTORY" or route == "UPGRADE_PICK" then
		view.Toolbar = toolbar
		view.Grid = e("Frame", { Position = UDim2.fromOffset(0, 108), Size = UDim2.new(1, 0, 1, -164), BackgroundTransparency = 1 }, { Items = grid })
  view.Mode = if route == "INVENTORY" then e(C.Button, { Name = "EnterSellModeButton", Text = "Sell artifacts", Position = UDim2.new(0, 0, 1, -48), Size = UDim2.new(1, 0, 0, 48), OnActivate = function() clearFilters(); setRoute("SELL") end }) else e(C.Text, { Text = "Choose the artifact to upgrade. It will be kept.", Position = UDim2.new(0, 0, 1, -48), Size = UDim2.new(1, 0, 0, 48), TextColor3 = T.Gold })
  view.Ownership = e("Frame", { Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 }, {
   All = e(C.Button, { Text = "All", Selected = filter.Ownership == "ALL", Size = UDim2.new(0.33, -6, 1, 0), OnActivate = function() updateFilter("Ownership", "ALL") end }),
   Equipped = e(C.Button, { Text = "Equipped", Accent = T.Equipped, Selected = filter.Ownership == "EQUIPPED", Position = UDim2.fromScale(0.33, 0), Size = UDim2.new(0.34, -6, 1, 0), OnActivate = function() updateFilter("Ownership", "EQUIPPED") end }),
   Available = e(C.Button, { Text = "Unequipped", Selected = filter.Ownership == "UNEQUIPPED", Position = UDim2.fromScale(0.67, 0), Size = UDim2.fromScale(0.33, 1), OnActivate = function() updateFilter("Ownership", "UNEQUIPPED") end }),
  })
 elseif route == "DETAIL" and target then
		local current = hero and hero.EquippedArtifactUUID and snapshot.Artifacts[hero.EquippedArtifactUUID]
		local details: { [string]: any } = {
			Target = e("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, if narrow then 120 else 200), BackgroundTransparency = 1 }, { Content = e(Screens.ItemHeader, { Snapshot = snapshot, Artifact = target, Large = not narrow }) }),
			Hero = e(C.Button, { Name = "ChooseEquipHeroButton", Order = 2, Text = (if hero then hero.DisplayName .. " · #" .. string.sub(hero.UUID, -4) else "Choose hero") .. "  |  Change hero\nCurrent: " .. (if current then current.DisplayName else "Empty weapon slot"), OnActivate = function() setDialog("HERO") end, Disabled = busy }),
			Stats = e(C.Stack, { Order = 3, Children = { Compare = e(Screens.Stats, { Before = current, After = target, Hero = hero }) } }),
			Consequence = e(C.Text, { LayoutOrder = 4, Text = if hero then Model.consequences(snapshot, hero.UUID, target.UUID) else "Choose a hero to compare this weapon.", TextSize = 14, Size = UDim2.new(1, 0, 0, 48), TextColor3 = T.Muted }),
			Management = e("Frame", { LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1 }, {
				Lock = e(C.Button, { Name = "LockArtifactButton", Text = if target.Locked then "Unlock artifact" else "Lock artifact", Size = UDim2.new(0.5, -4, 1, 0), Disabled = busy, OnActivate = forge.ToggleLock }),
				Unequip = e(C.Button, { Name = "UnequipArtifactButton", Text = "Unequip hero", Position = UDim2.new(0.5, 4, 0, 0), Size = UDim2.new(0.5, -4, 1, 0), Disabled = busy or not hero or not hero.EquippedArtifactUUID, OnActivate = forge.Unequip }),
			}),
			Reason = if equipReason then e(C.Text, { LayoutOrder = 6, Text = equipReason, TextSize = 14, Size = UDim2.new(1, 0, 0, 32), TextColor3 = T.Gold }) else nil,
		}
		view.Details = e(C.Scroll, { Size = UDim2.new(1, 0, 1, -60), Children = details })
		view.Equip = e(C.Button, { Name = "EquipArtifactButton", Text = if busy then "Waiting for server…" else Model.equipLabel(snapshot, forge.HeroId, forge.TargetId), Primary = true, Position = UDim2.new(0, 0, 1, -48), Size = UDim2.new(0.56, -4, 0, 48), Disabled = busy or equipReason ~= nil, OnActivate = forge.Equip })
		view.Upgrade = e(C.Button, { Name = "OpenUpgradeButton", Text = if maxRank then "Maximum stars" else "Upgrade artifact", Position = UDim2.new(0.56, 4, 1, -48), Size = UDim2.new(0.44, -4, 0, 48), Disabled = busy or maxRank, OnActivate = startUpgrade })
	elseif route == "MATERIALS" and target then
		local headerHeight = if height < 360 then 52 else 96
		view.Target = if headerHeight == 96 then e(Screens.ItemHeader, { Snapshot = snapshot, Artifact = target, Kept = true }) else e(C.Text, { Text = "KEPT: " .. target.DisplayName .. " · " .. target.Star .. "★\n" .. Model.ownerText(snapshot, target.UUID), Size = UDim2.new(1, 0, 0, 52), TextSize = 14, TextColor3 = T.Gold })
		view.Grid = e("Frame", { Position = UDim2.fromOffset(0, headerHeight + 8), Size = UDim2.new(1, 0, 1, -headerHeight - 72), BackgroundTransparency = 1 }, { Items = grid })
		view.AutoFill = e(C.Button, { Name = "AutoFillMaterialsButton", Text = "Auto-fill safe materials", Position = UDim2.new(0, 0, 1, -48), Size = UDim2.new(0.5, -4, 0, 48), Disabled = busy or maxRank, OnActivate = forge.AutoFill })
		view.Review = e(C.Button, { Name = "ReviewUpgradeButton", Text = string.format("Review upgrade (%d/%d)", #forge.Materials, if rule then rule.Donors else 0), Primary = true, Position = UDim2.new(0.5, 4, 1, -48), Size = UDim2.new(0.5, -4, 0, 48), Disabled = busy or upgradeReason ~= nil, OnActivate = reviewUpgrade })
	elseif route == "REVIEW" and target and review then
		local changed = snapshot.Revision ~= review.Revision
		local owners = Model.ownerIds(snapshot, target.UUID)
		local owner = #owners == 1 and snapshot.Heroes[owners[1]] or nil
		local children: { [string]: any } = {
			Target = e("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 96), BackgroundTransparency = 1 }, { Content = e(Screens.ItemHeader, { Snapshot = snapshot, Artifact = review.Before, Kept = true }) }),
			Rank = e(C.Text, { LayoutOrder = 2, Text = string.format("%d★ → %d★ · rarity and hero assignment stay", review.Before.Star, review.After.Star), TextColor3 = T.Gold, Size = UDim2.new(1, 0, 0, 28) }),
			Stats = e(C.Stack, { Order = 3, Children = { Compare = e(Screens.Stats, { Before = review.Before, After = review.After, Hero = owner }) } }),
			Cost = e(C.Text, { LayoutOrder = 4, Text = string.format("Cost: %d Gold + %d Gems\nBalance after: %d Gold · %d Gems", review.Gold, review.Gems, snapshot.Gold - review.Gold, snapshot.Gems - review.Gems), TextColor3 = T.Gold, Size = UDim2.new(1, 0, 0, 52) }),
			Consume = e(C.Text, { LayoutOrder = 5, Text = "PERMANENTLY CONSUMED", TextColor3 = T.Bad, Size = UDim2.new(1, 0, 0, 24), TextSize = 14 }),
			Materials = e(C.Stack, { Order = 6, Children = { Items = e(Screens.MaterialList, { Items = review.Materials, Width = contentWidth - 24 }) } }),
			Warning = e(C.Text, { LayoutOrder = 7, Text = if changed then "Inventory changed. Go back and review your materials again." else "The target is kept. Listed materials are consumed permanently. This upgrade cannot be undone.", TextColor3 = if changed then T.Bad else T.Muted, TextSize = 14, Size = UDim2.new(1, 0, 0, 48) }),
		}
		view.Review = e(C.Scroll, { Size = UDim2.new(1, 0, 1, -60), Children = children })
		view.Back = e(C.Button, { Name = "BackToMaterialsButton", Text = "Back to materials", Position = UDim2.new(0, 0, 1, -48), Size = UDim2.new(0.4, -4, 0, 48), Disabled = busy, OnActivate = function() setRoute("MATERIALS") end })
		view.Confirm = e(C.Button, { Name = "ConfirmUpgradeButton", Text = if busy then "Waiting for server…" else "Consume & upgrade", Primary = true, Position = UDim2.new(0.4, 4, 1, -48), Size = UDim2.new(0.6, -4, 0, 48), Disabled = busy or changed or upgradeReason ~= nil, OnActivate = function() forge.Upgrade(review.Revision) end })
	elseif route == "RESULT" and target then
		view.Success = e(C.Stack, { Children = {
			Title = e(C.Text, { Text = string.format("UPGRADED TO %d★", target.Star), TextSize = 24, TextColor3 = T.Gold, LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 48) }),
			Target = e("Frame", { LayoutOrder = 2, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 96) }, { Content = e(Screens.ItemHeader, { Snapshot = snapshot, Artifact = target, Kept = true }) }),
			Notice = e(C.Text, { Text = "Upgrade complete. Your artifact and its hero assignment are kept.", LayoutOrder = 3, TextColor3 = T.Good, Size = UDim2.new(1, 0, 0, 52) }),
		} })
		view.Inventory = e(C.Button, { Name = "ReturnToArtifactsButton", Text = "Back to artifacts", Position = UDim2.new(0, 0, 1, -48), Size = UDim2.new(0.5, -4, 0, 48), OnActivate = inventory })
		view.Continue = e(C.Button, { Name = "ContinueUpgradeButton", Text = "Upgrade again", Primary = true, Position = UDim2.new(0.5, 4, 1, -48), Size = UDim2.new(0.5, -4, 0, 48), Disabled = maxRank, OnActivate = startUpgrade })
	end

	local dialogView = nil
	if dialog == "HERO" then
		local choices: { [string]: any } = {}
		for index, entry in heroes do
			choices[entry.UUID] = e(C.HeroSlot, { Snapshot = snapshot, Hero = entry, Selected = forge.HeroId == entry.UUID, Order = index, OnSelect = function()
				if not busy and Model.compatible(entry, target) then forge.SetHero(entry.UUID); setDialog(nil)
				else forge.Explain("This hero cannot use that weapon type.") end
			end })
		end
		if #heroes == 0 then choices.Empty = e(C.Text, { Text = "No heroes owned yet.", Size = UDim2.new(1, 0, 0, 64) }) end
		dialogView = e(Dialog, { Title = "Choose hero", Children = choices, OnCancel = function() setDialog(nil) end, FocusKey = "HERO" })
	elseif dialog == "FILTER" then
		local choices: { [string]: any } = {
			Clear = e(C.Button, { Text = "Clear filters", OnActivate = clearFilters, Order = 0 }),
		}
		for index, value in { "ALL", "EQUIPPED", "UNEQUIPPED", "HERO" } do
			choices["Ownership" .. value] = e(C.Button, { Text = if value == "HERO" then "On selected hero" else value, Selected = filter.Ownership == value, OnActivate = function() updateFilter("Ownership", value) end, Order = index })
		end
		choices.Rarity = e(C.Text, { Text = "RARITY", TextColor3 = T.Gold, LayoutOrder = 8 })
		choices.AllRarities = e(C.Button, { Text = "All rarities", Selected = filter.Rarity == 0, OnActivate = function() updateFilter("Rarity", 0) end, Order = 9 })
		for index, rarity in Catalog.Rarities do choices["Rarity" .. index] = e(C.Button, { Text = rarity.Name, Selected = filter.Rarity == index, OnActivate = function() updateFilter("Rarity", index) end, Order = 10 + index }) end
		choices.Type = e(C.Text, { Text = "WEAPON TYPE", TextColor3 = T.Gold, LayoutOrder = 30 })
		choices.AllTypes = e(C.Button, { Text = "All weapon types", Selected = filter.WeaponType == "ALL", OnActivate = function() updateFilter("WeaponType", "ALL") end, Order = 31 })
		for index, value in Catalog.ArchetypeTypes do choices["Type" .. value] = e(C.Button, { Text = value, Selected = filter.WeaponType == value, OnActivate = function() updateFilter("WeaponType", value) end, Order = 32 + index }) end
		dialogView = e(Dialog, { Title = "Inventory filters", Children = choices, OnCancel = function() setDialog(nil) end, FocusKey = "FILTER" })
	end

	local titles = { SELL = "ARTIFACTS · SELL MODE", UPGRADE_PICK = "UPGRADE · CHOOSE ARTIFACT", INVENTORY = string.format("ARTIFACTS (%d)", #items), DETAIL = "ARTIFACT DETAILS", MATERIALS = "UPGRADE · CHOOSE MATERIALS", REVIEW = "UPGRADE · REVIEW & CONFIRM", RESULT = "UPGRADE COMPLETE" }
	local message = if forge.Sequence == 0 and forge.Message == "Choose a hero and an artifact to compare." then "Select an artifact to equip or upgrade." else forge.Message
	return e("ScreenGui", {
		Name = "ForgeWorkbench", ResetOnSpawn = false, DisplayOrder = 80, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		[React.Change.AbsoluteSize] = function(gui) setScreen(gui.AbsoluteSize) end,
	}, {
		Scrim = e("Frame", { Name = "Scrim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Theme.Ink, BackgroundTransparency = 0.65, Active = true, BorderSizePixel = 0, ZIndex = 1 }),
		Root = e("Frame", {
			ref = rootRef, Name = "Root", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, top),
			Size = UDim2.fromOffset(width, height), BackgroundColor3 = T.Background, BorderSizePixel = 0, ZIndex = 2,
			SelectionGroup = true, SelectionBehaviorUp = Enum.SelectionBehavior.Escape, SelectionBehaviorDown = Enum.SelectionBehavior.Stop, SelectionBehaviorLeft = Enum.SelectionBehavior.Stop, SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
		}, {
			Back = if route ~= "INVENTORY" then e(C.Button, { Name = "ForgeBackButton", Text = "<", Position = UDim2.fromOffset(16, 8), Size = UDim2.fromOffset(44, 44), OnActivate = back }) else nil,
			Title = e(C.Text, { Text = titles[route] or "ARTIFACTS", FontFace = T.Theme.Fonts.Title, TextSize = if narrow then 16 else 22, TextColor3 = T.Gold, Position = UDim2.fromOffset(if route == "INVENTORY" then 22 else 72, 8), Size = UDim2.new(1, -(if narrow then 132 else 340), 0, 44) }),
			Balance = if not narrow then e(C.Text, { Text = Balance.Format(snapshot.Gold) .. " Gold · " .. Balance.Format(snapshot.Gems) .. " Gems", Position = UDim2.new(1, -300, 0, 8), Size = UDim2.fromOffset(232, 44), TextSize = 16, TextColor3 = T.Gold, TextXAlignment = Enum.TextXAlignment.Right }) else nil,
			Close = e(C.Button, { Name = "CloseForgeButton", Text = "x", Position = UDim2.new(1, -60, 0, 8), Size = UDim2.fromOffset(44, 44), OnActivate = props.OnClose, FocusOrder = -100 }),
			Body = e("Frame", { Name = "Body", Position = UDim2.fromOffset(16, 60), Size = UDim2.new(1, -32, 1, -68 - statusHeight), BackgroundColor3 = T.Theme.Tones.Deep.Bottom, BorderSizePixel = 0 }, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
				Rail = e("UIStroke", { Color = T.Theme.Tones.Deep.Rail, Thickness = 1, Transparency = 0.35 }),
				Content = e("Frame", { ref = bodyRef, Name = "Content", Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 1, -16), BackgroundTransparency = 1 }, view),
			}),
			Status = e("Frame", { Name = "Status", Position = UDim2.new(0, 16, 1, -statusHeight), Size = UDim2.new(1, -32, 0, statusHeight - 4), BackgroundTransparency = 1 }, {
				Message = e("Frame", { Size = UDim2.new(1, if statusAction then -172 else 0, 1, 0), BackgroundTransparency = 1 }, { Text = e(Feedback, { Text = message, Success = forge.Success, Sequence = forge.Sequence }) }),
				Undo = if forge.Undo then e("Frame", { Position = UDim2.new(1, -164, 0, 4), Size = UDim2.fromOffset(164, 44), BackgroundTransparency = 1 }, { Button = e(UndoButton, { ExpiresAt = forge.Undo.ExpiresAt, Busy = busy, OnUndo = forge.UndoLast }) }) elseif forge.Phase == "uncertain" then e(C.Button, { Name = "ReconcileForgeButton", Text = "Check status", Position = UDim2.new(1, -164, 0, 4), Size = UDim2.fromOffset(164, 44), OnActivate = forge.Reconcile }) else nil,
			}),
			Modal = dialogView,
		}),
	})
end

return App
