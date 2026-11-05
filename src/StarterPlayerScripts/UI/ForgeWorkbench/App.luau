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
	return e(C.Button, { Text = if seconds > 0 then string.format("Undo (%ds)", seconds) else "Undo expired", Disabled = seconds <= 0 or props.Busy, OnActivate = props.OnUndo })
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
		Shade = e("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(), BackgroundTransparency = 0.2, Text = "", AutoButtonColor = false, Selectable = false, [React.Event.Activated] = props.OnCancel }),
		Dialog = e("Frame", {
			ref = ref, Size = UDim2.new(0.94, 0, 0.92, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = T.Background, BorderSizePixel = 0,
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
	local rootRef = React.useRef(nil)
	local inventoryRef = React.useRef(nil)
	local detailRef = React.useRef(nil)
	local rosterRef = React.useRef(nil)
	local closeRef = React.useRef(nil)
	local size, setSize = React.useState(Vector2.new(1120, 760))
	local preferred, setPreferred = React.useState(UserInputService.PreferredInput)
	local mobilePane, setMobilePane = React.useState(props.InitialPane or (if props.InitialArtifactId then "DETAILS" else "INVENTORY"))
	local materialMode, setMaterialMode = React.useState(false)
	local dialog, setDialog = React.useState(nil :: string?)
	local confirmRevision, setConfirmRevision = React.useState(nil :: number?)
	local page, setPage = React.useState(1)
	local filter, setFilter = React.useState({ Query = "", Ownership = "ALL", Rarity = 0, WeaponType = "ALL", Sort = "BEST" } :: Types.Filter)
	local inputName = React.useRef("ForgeMenu_" .. HttpService:GenerateGUID(false))
	local handlers = React.useRef({ Back = function() end, NextRegion = function() end, PreviousRegion = function() end })
	local short = size.Y < 520
	local narrow = size.X < 760
	local rosterWidth = if size.X >= 1120 then 232 else 0
	local detailWidth = if narrow then size.X - 32 else math.clamp(size.X * 0.34, 304, 380)
	local inventoryWidth = if narrow then size.X - 32 else size.X - rosterWidth - detailWidth - (if rosterWidth > 0 then 64 else 48)
	local inventoryX = if rosterWidth > 0 then rosterWidth + 32 else 16
	local busy = forge.Phase ~= "idle"
	local hasStatusAction = forge.Undo ~= nil or forge.Phase == "uncertain"
	local footerHeight = if hasStatusAction then 124 else 76
	local contentY = if short and narrow then 120 elseif short then 64 elseif narrow then 224 else 112
	local contentHeight = math.max(80, size.Y - contentY - footerHeight - 8)
	local gridY = if short then 56 elseif narrow then 104 else 156
	local target = forge.TargetId and snapshot.Artifacts[forge.TargetId]
	local hero = forge.HeroId and snapshot.Heroes[forge.HeroId]
	local items = React.useMemo(function() return Model.inventory(snapshot, filter, forge.HeroId) end, { snapshot, filter, forge.HeroId })
	local heroes = React.useMemo(function() return Model.sortedHeroes(snapshot) end, { snapshot })
	local upgradeReason = Model.upgradeReason(snapshot, forge.TargetId, forge.Materials)
	local equipReason = Model.equipReason(snapshot, forge.HeroId, forge.TargetId)
	React.useEffect(function()
		if props.OnContextChanged then props.OnContextChanged(forge.HeroId, forge.TargetId, forge.Mode) end
	end, { forge.HeroId, forge.TargetId, forge.Mode })

	local function updateFilter(key: string, value: any)
		setFilter(function(previous) local nextFilter = table.clone(previous); (nextFilter :: any)[key] = value; return nextFilter end)
		setPage(1)
	end
	local function clearFilters()
		setFilter({ Query = "", Ownership = "ALL", Rarity = 0, WeaponType = "ALL", Sort = "BEST" })
		setPage(1)
	end
	local function switchMode(mode: string)
		forge.SetMode(mode)
		setMaterialMode(false)
		if mode == "UPGRADE" then clearFilters() end -- explicit visible reset, never secretly exclude equipped items
	end
	local function chooseArtifact(id: string)
		if busy then return end
		if materialMode then forge.ToggleMaterial(id) else forge.SelectTarget(id); if narrow then setMobilePane("DETAILS") end end
	end
	local function back()
		if dialog then setDialog(nil)
		elseif materialMode then setMaterialMode(false); setMobilePane("DETAILS")
		elseif narrow and mobilePane == "DETAILS" then setMobilePane("INVENTORY")
		else props.OnClose() end
	end
	local function moveRegion(direction: number)
		if dialog then return end
		if narrow then
			setMobilePane(if mobilePane == "INVENTORY" then "DETAILS" else "INVENTORY")
			return
		end
		local regions = {}
		if rosterRef.current then table.insert(regions, rosterRef.current) end
		if inventoryRef.current then table.insert(regions, inventoryRef.current) end
		if detailRef.current then table.insert(regions, detailRef.current) end
		local current = GuiService.SelectedObject
		local index = 1
		for i, region in regions do if current and current:IsDescendantOf(region) then index = i end end
		if #regions > 0 then GuiService:Select(regions[(index - 1 + direction) % #regions + 1]) end
	end
	handlers.current = { Back = back, NextRegion = function() moveRegion(1) end, PreviousRegion = function() moveRegion(-1) end }
	React.useEffect(function()
		local previous = GuiService.SelectedObject
		if rootRef.current then setSize(rootRef.current.AbsoluteSize) end
		if UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then GuiService.SelectedObject = closeRef.current end
		local connection = UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function() setPreferred(UserInputService.PreferredInput) end)
		-- New cross-platform menu input is scoped to this mounted workbench.
		local context = Instance.new("InputContext")
		context.Name = inputName.current
		context.Priority = 2500
		context.Sink = false -- do not sink D-pad, text entry, or Roblox's core menu
		local function bind(name: string, codes: { Enum.KeyCode }, handler: string)
			local action = Instance.new("InputAction")
			action.Name = name; action.Type = Enum.InputActionType.Bool; action.Parent = context
			for index, code in codes do
				local binding = Instance.new("InputBinding"); binding.Name = "Key" .. index; binding.KeyCode = code; binding.Parent = action
			end
			action.Pressed:Connect(function()
				if not UserInputService:GetFocusedTextBox() then handlers.current[handler]() end
			end)
		end
		bind("Back", { Enum.KeyCode.ButtonB }, "Back")
		bind("NextRegion", { Enum.KeyCode.ButtonR1 }, "NextRegion")
		bind("PreviousRegion", { Enum.KeyCode.ButtonL1 }, "PreviousRegion")
		context.Parent = Players.LocalPlayer:WaitForChild("PlayerScripts")
		return function()
			context:Destroy(); connection:Disconnect()
			if previous and previous.Parent then GuiService.SelectedObject = previous end
		end
	end, {})
	React.useEffect(function()
		if preferred ~= Enum.PreferredInput.Gamepad or dialog then return end
		local region = if narrow and mobilePane == "DETAILS" then detailRef.current else inventoryRef.current
		local current = GuiService.SelectedObject
		if region and (not current or not current:IsDescendantOf(region)) then GuiService:Select(region) end
	end, { mobilePane, narrow, page, filter, preferred, dialog })
	React.useEffect(function()
		local maxPage = math.max(1, math.ceil(#items / T.PageSize))
		if page > maxPage then setPage(maxPage) end
	end, { #items, page })

	local rosterChildren: { [string]: any } = {}
	for index, entry in heroes do
		rosterChildren[entry.UUID] = e(C.HeroSlot, { Snapshot = snapshot, Hero = entry, Selected = forge.HeroId == entry.UUID, OnSelect = function() if not busy then forge.SetHero(entry.UUID) end end, Order = index })
	end
	local detailChildren: { [string]: any } = {
		Modes = e("Frame", { Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1, LayoutOrder = 1 }, {
			Equip = e(C.Button, { Text = "Equip", Size = UDim2.new(0.5, -4, 1, 0), Selected = forge.Mode == "EQUIP", Disabled = busy, OnActivate = function() switchMode("EQUIP") end }),
			Upgrade = e(C.Button, { Text = "Upgrade", Position = UDim2.new(0.5, 4, 0, 0), Size = UDim2.new(0.5, -4, 1, 0), Selected = forge.Mode == "UPGRADE", Disabled = busy, OnActivate = function() switchMode("UPGRADE") end }),
		}),
	}
	if target then
		detailChildren.Lock = e(C.Button, { Text = if target.Locked then "[L] Unlock protection" else "[U] Lock protection", OnActivate = forge.ToggleLock, Disabled = busy, Order = 2 })
		if forge.Mode == "EQUIP" then
			detailChildren.Comparison = e(C.Stack, { Order = 3, Children = { Comparison = e(C.ComparisonPanel, { Snapshot = snapshot, HeroId = forge.HeroId, Artifact = target }) } })
			detailChildren.Consequences = e(C.Text, { Text = if hero then Model.consequences(snapshot, hero.UUID, target.UUID) else "Choose a hero to preview the equipment change.", Size = UDim2.new(1, 0, 0, 112), LayoutOrder = 4 })
			detailChildren.Action = e(C.ActionFlow, { Label = Model.equipLabel(snapshot, forge.HeroId, forge.TargetId), Reason = equipReason, Busy = busy, OnActivate = forge.Equip, Order = 5 })
			detailChildren.Unequip = e(C.Button, { Text = "Unequip from " .. (if hero then hero.DisplayName else "hero"), OnActivate = forge.Unequip, Disabled = busy or not hero or not hero.EquippedArtifactUUID, Order = 6 })
		else
			detailChildren.Preview = e(C.Stack, { Order = 3, Children = { Preview = e(C.UpgradePreviewPanel, { Snapshot = snapshot, Target = target, MaterialIds = forge.Materials, OnRemove = forge.ToggleMaterial }) } })
			detailChildren.Materials = e(C.Button, { Text = if materialMode then "Done choosing materials" else "Choose materials from inventory", Disabled = busy or target.Star >= Catalog.MaxStars, Order = 4, OnActivate = function()
				setMaterialMode(not materialMode); clearFilters(); if narrow then setMobilePane(if materialMode then "DETAILS" else "INVENTORY") end
			end })
			detailChildren.AutoFill = e(C.Button, { Text = "Auto-fill safe materials", Disabled = busy or target.Star >= Catalog.MaxStars, OnActivate = forge.AutoFill, Order = 5 })
			detailChildren.Action = e(C.ActionFlow, { Label = string.format("Review upgrade to %d★", math.min(Catalog.MaxStars, target.Star + 1)), Reason = upgradeReason, Busy = busy, Order = 6, OnActivate = function() setConfirmRevision(snapshot.Revision); setDialog("UPGRADE") end })
		end
	else
		detailChildren.Empty = e(C.Text, { Text = "Choose any owned artifact. Equipped items can be upgraded in place; materials are protected while equipped or locked.", Size = UDim2.new(1, 0, 0, 180), LayoutOrder = 2 })
	end

	if props.OnSell then detailChildren.Sell = e(C.Button, { Text = "Sell artifacts", OnActivate = props.OnSell, Disabled = busy, Order = 99 }) end
	local dialogView = nil
	if dialog == "HERO" then
		-- Rebuild choices with a close-after-selection action for the modal.
		local choices: { [string]: any } = {}
		for index, entry in heroes do choices[entry.UUID] = e(C.HeroSlot, { Snapshot = snapshot, Hero = entry, Selected = forge.HeroId == entry.UUID, OnSelect = function() if not busy then forge.SetHero(entry.UUID); setDialog(nil) end end, Order = index }) end
		if #heroes == 0 then choices.Empty = e(C.Text, { Text = "No heroes owned yet. You can still inspect and upgrade artifacts.", Size = UDim2.new(1, 0, 0, 80) }) end
		dialogView = e(Dialog, { Title = "Choose hero", Children = choices, OnCancel = function() setDialog(nil) end, FocusKey = "HERO" })
	elseif dialog == "FILTER" then
		local choices: { [string]: any } = {
			Search = e("TextBox", { Size = UDim2.new(1, 0, 0, 48), LayoutOrder = -1, Text = filter.Query, PlaceholderText = "Search artifacts or owner…", ClearTextOnFocus = false, FontFace = T.Theme.Fonts.Body, TextSize = 14, TextColor3 = T.Text, BackgroundColor3 = T.Raised, [React.Change.Text] = function(box) updateFilter("Query", box.Text) end }),
			Clear = e(C.Button, { Text = "Clear all filters", OnActivate = clearFilters, Order = 0 }),
		}
		for index, value in { "ALL", "EQUIPPED", "UNEQUIPPED", "HERO" } do
			choices["Ownership" .. value] = e(C.Button, { Text = if value == "HERO" then "Equipped on selected hero" else value, Selected = filter.Ownership == value, OnActivate = function() updateFilter("Ownership", value) end, Order = index })
		end
		choices.RarityTitle = e(C.Text, { Text = "RARITY", TextColor3 = T.Gold, LayoutOrder = 8 })
		choices.AllRarities = e(C.Button, { Text = "All rarities", Selected = filter.Rarity == 0, OnActivate = function() updateFilter("Rarity", 0) end, Order = 9 })
		for index, rarity in Catalog.Rarities do choices["Rarity" .. index] = e(C.Button, { Text = rarity.Name, Selected = filter.Rarity == index, OnActivate = function() updateFilter("Rarity", index) end, Order = 10 + index }) end
		choices.TypeTitle = e(C.Text, { Text = "WEAPON TYPE", TextColor3 = T.Gold, LayoutOrder = 30 })
		local weaponTypes = { "ALL" }
		for _, value in Catalog.ArchetypeTypes do table.insert(weaponTypes, value) end
		for index, value in weaponTypes do choices["Type" .. value] = e(C.Button, { Text = value, Selected = filter.WeaponType == value, OnActivate = function() updateFilter("WeaponType", value) end, Order = 30 + index }) end
		dialogView = e(Dialog, { Title = "Inventory filters", Children = choices, OnCancel = function() setDialog(nil) end, FocusKey = "FILTER" })
	elseif dialog == "UPGRADE" and target then
		local changed = snapshot.Revision ~= confirmRevision
		dialogView = e(Dialog, { Title = "Confirm permanent consumption", OnCancel = function() setDialog(nil) end, FocusKey = "UPGRADE", Children = {
			Cancel = e(C.Button, { Text = "Cancel · keep materials", OnActivate = function() setDialog(nil) end, Order = -10 }), -- safest default focus
			Preview = e(C.Stack, { Order = 1, Children = { Preview = e(C.UpgradePreviewPanel, { Snapshot = snapshot, Target = target, MaterialIds = forge.Materials, OnRemove = function(id) forge.ToggleMaterial(id); setDialog(nil) end }) } }),
			Notice = e(C.Text, { Text = if changed then "Inventory changed. Close this review and check the updated preview." else "The listed materials and currency will be consumed. The target and its hero assignment are kept. This upgrade cannot be undone.", Size = UDim2.new(1, 0, 0, 112), TextColor3 = T.Gold, LayoutOrder = 2 }),
			Confirm = e(C.Button, { Text = "Consume materials & upgrade", Primary = true, Disabled = changed or busy or upgradeReason ~= nil, Order = 3, OnActivate = function() if confirmRevision and forge.Upgrade(confirmRevision) then setDialog(nil) end end }),
		} })
	end

	local filterCount = (if filter.Ownership ~= "ALL" then 1 else 0) + (if filter.Rarity ~= 0 then 1 else 0) + (if filter.WeaponType ~= "ALL" then 1 else 0)
	local sortOrder = { "BEST", "POWER", "RARITY", "STARS", "NAME" }
	return e("ScreenGui", {
		Name = "ForgeWorkbench", ResetOnSpawn = false, DisplayOrder = 80,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	}, {
		Scrim = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Theme.Ink, BackgroundTransparency = 0.2, Active = true, BorderSizePixel = 0 }),
		Root = e("Frame", {
			ref = rootRef, Size = UDim2.fromScale(0.9, 0.86), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, SelectionGroup = true,
			SelectionBehaviorUp = Enum.SelectionBehavior.Stop, SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
			SelectionBehaviorLeft = Enum.SelectionBehavior.Stop, SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
			[React.Change.AbsoluteSize] = function(root) setSize(root.AbsoluteSize) end,
		}, {
			Fill = e("UIGradient", { Color = ColorSequence.new(T.Theme.Tones.Violet.Top, T.Theme.Tones.Violet.Bottom), Rotation = 90 }),
			Constraint = e("UISizeConstraint", { MaxSize = props.MaxWindowSize or Vector2.new(960, 640) }),
			Corner = e("UICorner", { CornerRadius = UDim.new(0, T.Theme.Radius.Window) }),
			Stroke = e("UIStroke", { Color = T.Gold, Thickness = 1.4 }),
			Title = if not short then e(C.Text, { Text = "BLACKSMITH FORGE", TextSize = if narrow then 16 else 22, TextColor3 = T.Gold, FontFace = T.Theme.Fonts.Title, Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, if narrow then -96 else -360, 0, 40) }) else nil,
			Close = e(C.Button, { Ref = closeRef, Text = "Close", Position = UDim2.new(1, -80, 0, 8), Size = UDim2.fromOffset(64, 48), OnActivate = back, FocusOrder = -100 }),
			Balance = if not short and not narrow then e(C.Text, { Text = string.format("%d Gold · %d Gems", snapshot.Gold, snapshot.Gems), Position = UDim2.new(1, -340, 0, 8), Size = UDim2.fromOffset(248, 40), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Right }) else nil,
			Destinations = e("Frame", { Size = if narrow then UDim2.new(1, -32, 0, 48) else UDim2.fromOffset(224, 48), Position = UDim2.fromOffset(16, if short and narrow then 64 elseif short then 8 else 56), BackgroundTransparency = 1 }, {
				Artifacts = e(C.Button, { Text = "Artifacts", Selected = true, Size = UDim2.new(0.5, -4, 1, 0), OnActivate = function() end }),
				Summon = e(C.Button, { Text = "Summon", Size = UDim2.new(0.5, -4, 1, 0), Position = UDim2.new(0.5, 4, 0, 0), Disabled = busy, OnActivate = props.OnSummon, Name = "SummonArtifact" }),
			}),
			ChooseHero = e(C.Button, {
				Text = if hero then Model.heroLabel(hero) else "Choose hero",
				Position = if narrow then UDim2.fromOffset(16, if short then 8 else 112) else UDim2.fromOffset(252, if short then 8 else 56),
				Size = if short and narrow then UDim2.new(1, -216, 0, 48) elseif narrow then UDim2.new(1, -32, 0, 48) else UDim2.new(1, if short then -348 else -268, 0, 48),
				OnActivate = function() setDialog("HERO") end, Disabled = busy,
			}),
			Navigation = if narrow then e("Frame", { Size = if short then UDim2.fromOffset(104, 48) else UDim2.new(1, -32, 0, 48), Position = if short then UDim2.new(1, -192, 0, 8) else UDim2.fromOffset(16, 168), BackgroundTransparency = 1 }, {
				Inventory = e(C.Button, { Text = "Inventory", Selected = mobilePane == "INVENTORY", Size = UDim2.new(0.5, -4, 1, 0), OnActivate = function() setMobilePane("INVENTORY") end }),
				Details = e(C.Button, { Text = "Details", Selected = mobilePane == "DETAILS", Position = UDim2.new(0.5, 4, 0, 0), Size = UDim2.new(0.5, -4, 1, 0), OnActivate = function() setMobilePane("DETAILS") end }),
			}) else nil,
			Roster = if rosterWidth > 0 then e("Frame", { ref = rosterRef, BackgroundTransparency = 1, Position = UDim2.fromOffset(16, contentY), Size = UDim2.fromOffset(rosterWidth, contentHeight) }, {
				List = e(C.Scroll, { Size = UDim2.fromScale(1, 1), Children = rosterChildren }),
			}) else nil,
			Inventory = if not narrow or mobilePane == "INVENTORY" then e("Frame", { ref = inventoryRef, BackgroundTransparency = 1, Position = UDim2.fromOffset(inventoryX, contentY), Size = UDim2.fromOffset(inventoryWidth, contentHeight) }, {
				Search = if not narrow and not short then e("TextBox", {
					Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = T.Raised, BorderSizePixel = 0,
					Text = filter.Query, PlaceholderText = "Search artifact, type, rarity, owner…", ClearTextOnFocus = false,
					FontFace = T.Theme.Fonts.Body, TextSize = 14, TextColor3 = T.Text, PlaceholderColor3 = T.Muted,
					[React.Change.Text] = function(box) updateFilter("Query", box.Text) end,
				}) else nil,
				Filter = e(C.Button, { Text = string.format("Search/filters (%d)", filterCount), Size = UDim2.new(0.58, -4, 0, 48), Position = UDim2.fromOffset(0, if narrow or short then 0 else 56), OnActivate = function() setDialog("FILTER") end }),
				Sort = e(C.Button, { Text = "Sort: " .. filter.Sort, Size = UDim2.new(0.42, -4, 0, 48), Position = UDim2.new(0.58, 4, 0, if narrow or short then 0 else 56), OnActivate = function() local index = table.find(sortOrder, filter.Sort) or 1; updateFilter("Sort", sortOrder[index % #sortOrder + 1]) end }),
				Context = if not short then e(C.Text, { Text = if materialMode then "MATERIALS → " .. (if target then target.DisplayName else "Select target") .. " · " .. #forge.Materials .. " chosen" else string.format("%d artifacts shown · select to inspect", #items), Position = UDim2.fromOffset(0, if narrow then 56 else 108), Size = UDim2.new(1, 0, 0, 44), TextSize = 14, TextColor3 = if materialMode then T.Gold else T.Muted }) else nil,
				Done = if materialMode and narrow and not short then e(C.Button, { Text = "Review chosen materials", Position = UDim2.fromOffset(0, gridY), OnActivate = function() setMobilePane("DETAILS"); setMaterialMode(false) end }) else nil,
				Grid = e("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, gridY + (if materialMode and narrow and not short then 56 else 0)), Size = UDim2.new(1, 0, 1, -(gridY + (if materialMode and narrow and not short then 56 else 0))) }, {
					List = e(C.InventoryGrid, { Snapshot = snapshot, Items = items, TargetId = forge.TargetId, MaterialIds = forge.Materials, MaterialMode = materialMode, HeroId = forge.HeroId, Width = inventoryWidth, OnSelect = chooseArtifact, Page = page, OnPage = setPage }),
				}),
			}) else nil,
			Detail = if not narrow or mobilePane == "DETAILS" then e("Frame", { ref = detailRef, BackgroundTransparency = 1, Position = UDim2.fromOffset(if narrow then 16 else size.X - detailWidth - 16, contentY), Size = UDim2.fromOffset(detailWidth, contentHeight) }, {
				List = e(C.Scroll, { Size = UDim2.fromScale(1, 1), Children = detailChildren }),
			}) else nil,
			Status = e("Frame", { Position = UDim2.new(0, 16, 1, -footerHeight), Size = UDim2.new(1, -32, 0, footerHeight - 8), BackgroundTransparency = 1 }, {
				Feedback = e("Frame", { Size = UDim2.new(1, 0, 0, if hasStatusAction then 60 else 44), BackgroundTransparency = 1 }, { Message = e(Feedback, { Text = forge.Message, Success = forge.Success, Sequence = forge.Sequence }) }),
				Undo = if forge.Undo then e("Frame", { Position = UDim2.fromOffset(0, 64), Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1 }, { Button = e(UndoButton, { ExpiresAt = forge.Undo.ExpiresAt, Busy = busy, OnUndo = forge.UndoLast }) }) elseif forge.Phase == "uncertain" then e(C.Button, { Text = "Check server status", Position = UDim2.fromOffset(0, 64), OnActivate = forge.Reconcile }) else e(C.Text, { Text = if preferred == Enum.PreferredInput.Gamepad then "A Select · B Back · LB/RB Region" else "Equipped & locked materials are protected.", Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 24), TextSize = 14, TextColor3 = T.Muted }),
			}),
			Modal = dialogView,
		}),
	})
end

return App
