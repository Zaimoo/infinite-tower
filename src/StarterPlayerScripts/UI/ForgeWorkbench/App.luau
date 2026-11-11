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
local useSell = require(script.Parent.useSell)
local Screens = require(script.Parent.Screens)
local UpgradeStage = require(script.Parent.UpgradeStage)
local UpgradeResult = require(script.Parent.UpgradeResult)
local HeroPicker = require(script.Parent.HeroPicker)
local Balance = require(ReplicatedStorage.Shared.Config.StatBalance)
local Icons = require(script.Parent.Parent.Hud.Icons)
local UIFeel = require(script.Parent.Parent.UIFeel)
local WindowScale = require(script.Parent.Parent.WindowScale)
local ModalFit = require(script.Parent.Parent.ModalFit)
local Types = require(script.Parent.Types)
local Kit = require(script.Parent.Parent.Kit)
local e = React.createElement

local TOOLBAR_HEIGHT = 84
local WEAPON_TYPE_LABEL: { [string]: string } = {
	SWORD_SHIELD = "Sword", DAGGERS = "Daggers", BOW = "Bow", AXE = "Axe", STAFF = "Staff", TOME = "Tome",
}

-- "500 Gold · 1 weapon consumed": Gems only when the rank actually costs Gems.
local function upgradeCostText(rule: { Gold: number, Gems: number, Donors: number }): string
	local parts = { string.format("%s Gold", Balance.Format(rule.Gold)) }
	if (rule.Gems or 0) > 0 then table.insert(parts, string.format("%s Gems", Balance.Format(rule.Gems))) end
	table.insert(parts, string.format("%d %s consumed", rule.Donors, if rule.Donors == 1 then "weapon" else "weapons"))
	return table.concat(parts, " · ")
end

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
	return e(C.Button, {
		Name = "UndoEquipmentButton",
		Size = UDim2.fromScale(1, 1),
		Text = if seconds > 0 then string.format("Undo (%ds)", seconds) else "Undo expired",
		Disabled = seconds <= 0 or props.Busy,
		OnActivate = props.OnUndo,
	})
end

local function Feedback(props: { Text: string, Success: boolean, Sequence: number })
	local ref = React.useRef(nil)
	React.useEffect(function()
		if not ref.current or UIFeel.ReducedMotion() or props.Sequence == 0 then return end
		ref.current.Scale = 0.98
		local tween = TweenService:Create(ref.current, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		tween:Play()
		-- No sound here: results are toasts now, and the toast plays the sound.
		return function() tween:Cancel() end
	end, { props.Sequence })
	return e("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		Scale = e("UIScale", { ref = ref }),
		Text = e(C.Text, { Text = props.Text, TextColor3 = if props.Success then T.Good else T.Text, TextSize = 14, Size = UDim2.fromScale(1, 1) }),
	})
end

local function Dialog(props: { Title: string, Children: { [string]: any }, OnCancel: () -> (), FocusKey: string, Cards: boolean?, HeaderExtras: any?, CardHeight: number?,
	Subtitle: string?, MaxSize: Vector2?, Square: boolean? })
	local ref = React.useRef(nil)
	React.useEffect(function()
		local previous = GuiService.SelectedObject
		if ref.current and UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then GuiService:Select(ref.current) end
		return function()
			if previous and previous.Parent then GuiService.SelectedObject = previous end
		end
	end, { props.FocusKey })
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 100 }, {
		Shade = e("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(), BackgroundTransparency = 0.25, Text = "", AutoButtonColor = false, Selectable = false, ZIndex = 1, [React.Event.Activated] = props.OnCancel }),
		-- Same anatomy as the Forge window (Brighter Grimoire): ember header bar, white title, red X,
		-- a lifted plum panel with ink and a gold rail; an optional subtitle says what to do.
		Dialog = e("Frame", {
			ref = ref, Size = UDim2.new(0.94, 0, 0.92, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2,
			SelectionGroup = true, SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
			SelectionBehaviorDown = Enum.SelectionBehavior.Stop, SelectionBehaviorLeft = Enum.SelectionBehavior.Stop, SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
		}, {
			Constraint = e("UISizeConstraint", { MaxSize = props.MaxSize or Vector2.new(if props.Cards then 1050 else 620, 760) }),
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 16) }),
			Fill = e("UIGradient", { Rotation = 90, Color = ColorSequence.new(Kit.Tokens.Surface.Window.Top, Kit.Tokens.Surface.Inset.Bottom) }),
			Ink = e("UIStroke", { Color = T.Theme.Ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			Rail = e("Frame", { Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), BackgroundTransparency = 1, ZIndex = 2 }, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 13) }),
				Line = e("UIStroke", { Color = T.Gold, Thickness = 1.4, Transparency = 0.25, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			}),
			HeaderBar = e("Frame", { Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, 56), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2 }, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
				Fill = e("UIGradient", { Rotation = 90, Color = ColorSequence.new(Kit.Tokens.Domain.Forge.Top, Kit.Tokens.Domain.Forge.Bottom) }),
			}),
			Title = e(C.Text, { Text = props.Title, TextColor3 = T.Text, Position = UDim2.fromOffset(22, 10), Size = UDim2.new(1, -96, 0, 52), TextSize = 22, ZIndex = 3 }),
			-- In a ZIndex-4 holder so it draws above the header bar (it was hidden under it).
			CloseHolder = e("Frame", { Name = "CloseHolder", Size = UDim2.fromOffset(44, 44), Position = UDim2.new(1, -56, 0, 12), BackgroundTransparency = 1, ZIndex = 4 }, {
				Close = e(C.Button, { Name = "CloseDialogButton", Text = "", Icon = "Close", Accent = T.Bad, Size = UDim2.fromScale(1, 1), OnActivate = props.OnCancel, FocusOrder = -100 }),
			}),
			Subtitle = if props.Subtitle then e(C.Text, {
				Text = props.Subtitle, RichText = true, TextColor3 = T.Text, TextSize = 16, FontFace = T.Theme.Fonts.Body,
				Position = UDim2.fromOffset(20, 68), Size = UDim2.new(1, -40, 0, 30), ZIndex = 3,
			}) else nil,
			Extras = props.HeaderExtras,
			Content = e(if props.Cards then C.CardGrid else C.Scroll, {
				Size = UDim2.new(1, -24, 1, if props.HeaderExtras then -152 elseif props.Subtitle then -118 else -84),
				Position = UDim2.fromOffset(12, if props.HeaderExtras then 138 elseif props.Subtitle then 104 else 72),
				Children = props.Children, CellHeight = props.CardHeight, Square = props.Square,
			}),
		}),
	})
end

local function App(props: Types.Props)
	local forge = useForge(props)
	local snapshot = forge.Snapshot
	local rootRef, bodyRef = React.useRef(nil), React.useRef(nil)
	local headerBarRef, summonHostRef = React.useRef(nil), React.useRef(nil)
	local summonTab = props.ActiveTab == "Summon"
	-- Hand the body frame to the legacy summon view while the Summon tab shows, and take it back.
	-- A layout effect: its cleanup runs before React destroys the host frame, so the summon view is
	-- moved out first instead of being destroyed with it.
	React.useLayoutEffect(function()
		if not summonTab or not props.OnSummonHost then return nil end
		props.OnSummonHost(summonHostRef.current)
		return function() props.OnSummonHost(nil) end
	end, { summonTab })
	-- The header's domain colour bar (Brighter Grimoire: Forge = ember).
	React.useEffect(function()
		if headerBarRef.current then Kit.Tokens.Paint(headerBarRef.current, Kit.Tokens.Domain.Forge, 12, 0, 0.35) end
	end, {})
	local transitionRef = React.useRef(nil)
	local camera = workspace.CurrentCamera
	local screen, setScreen = React.useState(if camera then camera.ViewportSize else Vector2.new(1280, 720))
	local preferred, setPreferred = React.useState(UserInputService.PreferredInput)
	local route, setRoute = React.useState(if props.InitialMode == "UPGRADE" then "UPGRADE_PICK" else "INVENTORY")
	local sellMode, setSellMode = React.useState(props.InitialPane == "SELL")
	local dialog, setDialog = React.useState(nil :: string?)
	local review, setReview = React.useState(nil :: any)
	local filter, setFilter = React.useState({ Query = "", Ownership = "ALL", Rarity = 0, WeaponType = "ALL", Sort = "BEST" } :: Types.Filter)
	local handlers = React.useRef({ Back = function() end })
	local inputName = React.useRef("ForgeMenu_" .. HttpService:GenerateGUID(false))
	local busy = forge.Phase ~= "idle"
	local target = forge.TargetId and snapshot.Artifacts[forge.TargetId]
	local hero = forge.HeroId and snapshot.Heroes[forge.HeroId]

	local windowPosition, windowScale, design = ModalFit.Calculate(screen, 0, 1120, 630, {
		MaxScale = 1.2,
		FillWidth = true,
	})
	local width, height = design.X, design.Y
	local statusAction = forge.Undo ~= nil or forge.Phase == "uncertain"
	local statusHeight = if statusAction then 54 else 30
	local contentWidth = width - 48

	local items = React.useMemo(function() return Model.inventory(snapshot, filter, forge.HeroId) end, { snapshot, filter, forge.HeroId })
	local heroes = React.useMemo(function() return Model.sortedHeroes(snapshot) end, { snapshot })
	local filterKey = table.concat({filter.Query, filter.Ownership, tostring(filter.Rarity), filter.WeaponType, filter.Sort}, "|")
	local rule = target and Catalog.GetStarPromotionCost(target.Star)
	local maxRank = target ~= nil and rule == nil
	local upgradeReason = Model.upgradeReason(snapshot, forge.TargetId, forge.Materials)

	-- Equip Best Plan
	local equipBestPlan = React.useMemo(function()
		return Model.equipBestPlan(snapshot)
	end, { snapshot })

	-- Sell Mode Hook
	local sell = useSell({
		Snapshot = snapshot,
		Items = items,
		OnSellArtifacts = props.OnSellArtifacts,
		OnBusyChanged = props.OnBusyChanged,
	})

	-- Results as toasts (UI overhaul plan §4.3): every forge result (equip, upgrade, lock, Equip Best,
	-- refusals) and every finished sale. Refusals are amber with the refusal sound.
	React.useEffect(function()
		if forge.Sequence == 0 or forge.Message == "" then return end
		Kit.Notify.Push(if forge.Success then "success" else "warn", forge.Message)
	end, { forge.Sequence })
	local sellWasBusy = React.useRef(false)
	React.useEffect(function()
		if sellWasBusy.current and not sell.Busy and sell.Message ~= "" then
			local ok = string.find(string.lower(sell.Message), "sold") ~= nil
			Kit.Notify.Push(if ok then "success" else "warn", sell.Message)
		end
		sellWasBusy.current = sell.Busy
	end, { sell.Busy, sell.Message })

	-- Count owned artifacts & capacity
	local artifactCount = 0
	for _ in snapshot.Artifacts do artifactCount += 1 end
	local artifactCap = snapshot.ArtifactCap or 50
	local isCapFull = artifactCount >= artifactCap
	local isCapNear = artifactCount >= artifactCap * 0.8
	local capColor = if isCapFull then T.Bad elseif isCapNear then T.Gold else T.Text

	-- Auto-select target if none selected yet
	React.useEffect(function()
		if not forge.TargetId and #items > 0 then
			local bestId = Model.best(snapshot, forge.HeroId) or items[1].UUID
			forge.SelectTarget(bestId)
		end
	end, { items, forge.TargetId })

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
		if dialog then
			setDialog(nil)
		elseif sellMode then
			setSellMode(false)
			sell.Clear()
		elseif route == "REVIEW" then
			setRoute("MATERIALS")
		elseif route == "MATERIALS" then
			inventory()
		elseif route ~= "INVENTORY" then
			inventory()
		else
			props.OnClose()
		end
	end
	handlers.current = { Back = back }

	local function chooseArtifact(id: string)
		if busy then return end
		if sellMode then
			sell.Toggle(id)
			return
		end
		if route == "MATERIALS" then
			forge.ToggleMaterial(id)
			return
		end
		if route == "UPGRADE_PICK" then
			forge.SelectTarget(id)
			forge.SetMode("UPGRADE")
			clearFilters()
			setRoute("MATERIALS")
			return
		end

		forge.SelectTarget(id)
		forge.SetMode("EQUIP")
		local artifact = snapshot.Artifacts[id]
		if not Model.compatible(hero, artifact) then
			local owners = Model.ownerIds(snapshot, id)
			local chosen = #owners == 1 and snapshot.Heroes[owners[1]] or nil
			if chosen and Model.compatible(chosen, artifact) then
				forge.SetHero(chosen.UUID)
			else
				for _, entry in heroes do
					if Model.compatible(entry, artifact) then
						forge.SetHero(entry.UUID)
						break
					end
				end
			end
		end
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

	local function handleEquipTarget()
		if not target or busy then return end
		local owners = Model.ownerIds(snapshot, target.UUID)
		if #owners > 0 then
			forge.Unequip(owners[1])
		else
			setDialog("HERO")
		end
	end

	-- Selling asks by risk (UI overhaul plan §6): Commons and Uncommons sell straight away; Rare to
	-- Superior is a Hard confirm (arms after 1 s); Exalted+ or any ★2+ weapon must be held to confirm.
	local function handleSellAction()
		if sell.SelectedCount == 0 or busy then return end
		local maxRarity, maxStars = 1, 1
		local items = {}
		for _, artifact in sell.SelectedItems do
			maxRarity = math.max(maxRarity, artifact.Rarity or 1)
			maxStars = math.max(maxStars, artifact.Star or 1)
			table.insert(items, string.format("%s · %s %d★", artifact.DisplayName, Catalog.GetRarityInfo(artifact.Rarity or 1).Name, artifact.Star or 1))
		end
		local tier = Kit.Rules.ConfirmTier("SELL", { MaxRarity = maxRarity, MaxStars = maxStars })
		if tier == "None" then
			sell.Sell()
			return
		end
		Kit.Confirm.Ask({
			Tier = tier,
			Title = string.format("Sell %d weapon%s?", sell.SelectedCount, if sell.SelectedCount == 1 then "" else "s"),
			Body = string.format("They're gone for good. You get %s Gold.", Balance.Format(sell.TotalGold)),
			Items = items,
			ConfirmText = "Sell",
			OnConfirm = function() sell.Sell() end,
		})
	end

	React.useEffect(function()
		if rootRef.current then T.Theme.Frame(rootRef.current, { Class = "Window", Tone = "Violet", ZIndex = 2 }) end
		local inputConnection = UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function() setPreferred(UserInputService.PreferredInput) end)
		local context = Instance.new("InputContext")
		context.Name = inputName.current; context.Priority = 2500; context.Sink = false
		local action = Instance.new("InputAction")
		action.Name = "Back"; action.Type = Enum.InputActionType.Bool; action.Parent = context
		-- Backspace and gamepad B step back (dialog → sell mode → upgrade route → close). WindowManager
		-- leaves the Forge's Back to this context.
		for _, key in { Enum.KeyCode.ButtonB, Enum.KeyCode.Backspace } do
			local binding = Instance.new("InputBinding")
			binding.KeyCode = key; binding.Parent = action
		end
		action.Pressed:Connect(function() if not UserInputService:GetFocusedTextBox() then handlers.current.Back() end end)
		context.Parent = Players.LocalPlayer:WaitForChild("PlayerScripts")
		return function() context:Destroy(); inputConnection:Disconnect() end
	end, {})

	React.useEffect(function()
		if props.OnContextChanged then props.OnContextChanged(forge.HeroId, forge.TargetId, forge.Mode) end
	end, { forge.HeroId, forge.TargetId, forge.Mode })

	React.useEffect(function()
		if props.OnBusyChanged then props.OnBusyChanged(busy or sell.Busy) end
		return function() if props.OnBusyChanged then props.OnBusyChanged(false) end end
	end, { busy, sell.Busy })

	React.useEffect(function()
		if rootRef.current then rootRef.current:SetAttribute("ForgeView", route) end
		local scale = transitionRef.current
		local tween
		if scale and not UIFeel.ReducedMotion() then
			scale.Scale = if route == "RESULT" then 0.9 else 0.98
			tween = TweenService:Create(scale, TweenInfo.new(if route == "RESULT" then 0.35 else 0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			tween:Play()
		end
		if preferred == Enum.PreferredInput.Gamepad and bodyRef.current and not dialog then GuiService:Select(bodyRef.current) end
	end, { route, preferred })

	React.useEffect(function()
		if route ~= "INVENTORY" and route ~= "UPGRADE_PICK" and not target then inventory() end
	end, { target, route })

	React.useEffect(function()
		if route == "REVIEW" and forge.Success and forge.Sequence > 0 and forge.Phase == "idle" then setRoute("RESULT") end
	end, { forge.Sequence })

	-- Toolbar: weapon types are one tap away as a chip row; search, the rarer filters and sort sit under it.
	local filterCount = (if filter.Ownership ~= "ALL" then 1 else 0) + (if filter.Rarity ~= 0 then 1 else 0)
	local typeChips: { [string]: any } = {
		Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalFlex = Enum.UIFlexAlignment.Fill, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		Pad = e("UIPadding", { PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2) }),
		All = e(C.Chip, { Name = "TypeChip_ALL", Text = "All", Order = 0, Selected = filter.WeaponType == "ALL", OnActivate = function() updateFilter("WeaponType", "ALL") end }),
	}
	for index, value in Catalog.ArchetypeTypes do
		typeChips[value] = e(C.Chip, {
			Name = "TypeChip_" .. value, Text = WEAPON_TYPE_LABEL[value] or value, Order = index, Selected = filter.WeaponType == value,
			OnActivate = function() updateFilter("WeaponType", if filter.WeaponType == value then "ALL" else value) end,
		})
	end
	local toolbar = e("Frame", { Name = "InventoryToolbar", Size = UDim2.new(1, 0, 0, TOOLBAR_HEIGHT), BackgroundTransparency = 1 }, {
		Types = e("Frame", { Name = "WeaponTypes", Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1 }, typeChips),
		Search = e("TextBox", {
			Name = "ArtifactSearch", Text = filter.Query, PlaceholderText = "Search…", ClearTextOnFocus = false,
			Position = UDim2.fromOffset(0, 44), Size = UDim2.new(0.5, -4, 0, 40), BackgroundColor3 = T.Raised, BorderSizePixel = 0,
			FontFace = T.Theme.Fonts.Body, TextSize = 16, TextColor3 = T.Text, PlaceholderColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Left,
			[React.Change.Text] = function(box) updateFilter("Query", box.Text) end,
		}, { Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }), Padding = e("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 12) }), Ink = e("UIStroke", { Color = T.Theme.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) }),
		Filter = e(C.Button, { Name = "FilterArtifactsButton", Text = if filterCount > 0 then string.format("Filters (%d)", filterCount) else "Filters", Selected = filterCount > 0, Position = UDim2.new(0.5, 0, 0, 44), Size = UDim2.new(0.25, -4, 0, 40), OnActivate = function() setDialog("FILTER") end }),
		Sort = e(C.Button, { Name = "SortArtifactsButton", Text = "Sort: " .. string.upper(string.sub(filter.Sort, 1, 1)) .. string.lower(string.sub(filter.Sort, 2)), Tooltip = "Tap to cycle: Best, Power, Rarity, Stars, Name", Position = UDim2.new(0.75, 0, 0, 44), Size = UDim2.new(0.25, 0, 0, 40), OnActivate = function()
			local order = { "BEST", "POWER", "RARITY", "STARS", "NAME" }
			updateFilter("Sort", order[(table.find(order, filter.Sort) or 1) % #order + 1])
		end }),
	})

	local gridWidth = math.floor(contentWidth * T.GridShare) - 16
	local grid = e(C.InventoryGrid, {
		Snapshot = snapshot,
		Items = items,
		TargetId = forge.TargetId,
		MaterialIds = forge.Materials,
		MaterialMode = route == "MATERIALS",
		HeroId = forge.HeroId,
		Width = gridWidth,
		OnSelect = chooseArtifact,
		FilterKey = filterKey,
		SellMode = sellMode,
		CheckedIds = sell.Selected,
	})

	-- Main Workbench Body (Grid + Detail / Sell Summary + Action Bar)
	local view: { [string]: any } = { Scale = e("UIScale", { ref = transitionRef }) }

	if route == "INVENTORY" or route == "UPGRADE_PICK" then
		-- Bottom Action Bar
		local actionBar = if sellMode then e("Frame", {
			Name = "SellActionBar",
			Size = UDim2.new(1, 0, 0, T.ActionBarHeight),
			Position = UDim2.new(0, 0, 1, -T.ActionBarHeight),
			BackgroundTransparency = 1,
		}, {
			Hammer = e(C.Button, {
				Name = "ExitSellHammer",
				Icon = "Hammer",
				Text = "Back",
				Accent = T.Bad,
				Selected = true,
				Size = UDim2.new(0.16, -6, 0, 48),
				Position = UDim2.new(0, 0, 0, 4),
				OnActivate = function() setSellMode(false); sell.Clear() end,
			}),
			QuickCommon = e(C.Button, {
				Text = "Common",
				Size = UDim2.new(0.16, -6, 0, 48),
				Position = UDim2.new(0.16, 0, 0, 4),
				Disabled = sell.Busy,
				OnActivate = function() sell.QuickPick(1) end,
			}),
			QuickUncommon = e(C.Button, {
				Text = "Uncommon",
				Size = UDim2.new(0.18, -6, 0, 48),
				Position = UDim2.new(0.32, 0, 0, 4),
				Disabled = sell.Busy,
				OnActivate = function() sell.QuickPick(2) end,
			}),
			QuickAll = e(C.Button, {
				Text = "All Spare",
				Size = UDim2.new(0.16, -6, 0, 48),
				Position = UDim2.new(0.50, 0, 0, 4),
				Disabled = sell.Busy,
				OnActivate = function() sell.QuickPick(nil) end,
			}),
			Clear = e(C.Button, {
				Text = "Clear",
				Size = UDim2.new(0.11, -6, 0, 48),
				Position = UDim2.new(0.66, 0, 0, 4),
				Disabled = sell.Busy or sell.SelectedCount == 0,
				OnActivate = sell.Clear,
			}),
			SellBtn = e(C.Button, {
				Name = "CommitSellButton",
				Text = if sell.Busy then "Selling…" elseif sell.SelectedCount > 0 then string.format("Sell %d (+%s)", sell.SelectedCount, Balance.Format(sell.TotalGold)) else "Pick weapons to sell",
				Tooltip = if sell.SelectedCount == 0 then "Tap weapons in the grid, or use Common / Uncommon / All Spare." else nil,
				Primary = true,
				Accent = T.Bad,
				Size = UDim2.new(0.23, 0, 0, 48),
				Position = UDim2.new(0.77, 0, 0, 4),
				Disabled = sell.Busy or sell.SelectedCount == 0,
				OnActivate = handleSellAction,
			}),
		}) else e("Frame", {
			Name = "NormalActionBar",
			Size = UDim2.new(1, 0, 0, T.ActionBarHeight),
			Position = UDim2.new(0, 0, 1, -T.ActionBarHeight),
			BackgroundTransparency = 1,
		}, {
			-- Upgrade / Equip live in the detail panel next to the grid; this bar holds the two
			-- inventory-wide actions only (they used to be repeated here).
			Hammer = e(C.Button, {
				Name = "EnterSellHammer",
				Icon = "Hammer",
				Text = "Sell weapons",
				Intent = "Danger",
				Tooltip = "Pick spare weapons to sell for Gold",
				Size = UDim2.new(0.34, -6, 0, 48),
				Position = UDim2.new(0, 0, 0, 4),
				OnActivate = function() setSellMode(true) end,
			}),
			EquipBest = e(C.Button, {
				Name = "EquipBestButton",
				Icon = "Equipped",
				Text = if equipBestPlan.HasChanges then string.format("Equip Best (+%s power)", Balance.Format(equipBestPlan.PowerDelta)) else "Squad already optimal",
				Intent = "Confirm",
				Tooltip = if equipBestPlan.HasChanges then "Gives every deployed squad hero its strongest compatible weapon. Benched heroes keep theirs." else "Every deployed hero already has its best weapon.",
				Size = UDim2.new(0.66, 0, 0, 48),
				Position = UDim2.new(0.34, 0, 0, 4),
				Disabled = busy or not equipBestPlan.HasChanges,
				OnActivate = forge.EquipBest,
			}),
		})

		-- Left Pane: Grid + Toolbar + Action Bar
		view.LeftPane = e("Frame", {
			Name = "GridPane",
			Size = UDim2.new(T.GridShare, -8, 1, 0),
			BackgroundTransparency = 1,
		}, {
			Toolbar = toolbar,
			GridArea = e("Frame", {
				Position = UDim2.fromOffset(0, TOOLBAR_HEIGHT + 6),
				Size = UDim2.new(1, 0, 1, -TOOLBAR_HEIGHT - 12 - T.ActionBarHeight),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
			}, { Content = grid }),
			ActionBar = actionBar,
		})

		-- Right Pane: Detail Panel OR Sell Summary
		local rightContent = if sellMode then e(Screens.SellSummary, {
			SelectedCount = sell.SelectedCount,
			TotalGold = sell.TotalGold,
			RarityCounts = sell.RarityCounts,
			Busy = sell.Busy,
			Message = sell.Message,
			OnExitSell = function() setSellMode(false); sell.Clear() end,
		}) elseif target then e(Screens.DetailPanel, {
			Snapshot = snapshot,
			Artifact = target,
			Hero = hero,
			Busy = busy,
			OnEquip = function() setDialog("HERO") end,
			OnUnequip = function()
				local owners = Model.ownerIds(snapshot, target.UUID)
				if #owners > 0 then forge.Unequip(owners[1]) end
			end,
			OnUpgrade = startUpgrade,
			OnToggleLock = forge.ToggleLock,
			OnSell = function()
				setSellMode(true)
				sell.Toggle(target.UUID)
			end,
		}) else e(C.Text, {
			Text = "Select an artifact to view details.",
			TextColor3 = T.Muted,
			TextSize = 16,
			Position = UDim2.fromOffset(20, 40),
			Size = UDim2.new(1, -40, 0, 60),
		})

		view.RightPane = e("Frame", {
			Name = "DetailPane",
			Position = UDim2.fromScale(T.GridShare, 0),
			Size = UDim2.new(T.DetailShare, 0, 1, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
			Fill = e("UIGradient", { Rotation = 90, Color = ColorSequence.new(Kit.Tokens.Surface.Window.Top, Kit.Tokens.Surface.Inset.Bottom) }),
			Ink = e("UIStroke", { Color = T.Theme.Ink, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			Rail = e("Frame", { Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), BackgroundTransparency = 1 }, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 9) }),
				Line = e("UIStroke", { Color = T.Gold, Thickness = 1.4, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			}),
			Inner = e("Frame", {
				Position = UDim2.fromOffset(10, 10),
				Size = UDim2.new(1, -20, 1, -20),
				BackgroundTransparency = 1,
			}, { Content = rightContent }),
		})

	elseif route == "MATERIALS" and target then
		local after = table.clone(target)
		after.Star = math.min(Catalog.MaxStars, target.Star + 1)
		view.Stage = e(UpgradeStage, {
			Snapshot = snapshot,
			Target = target,
			Materials = forge.Materials,
			OnSlot = function(id) if id then forge.ToggleMaterial(id) else setDialog("MATERIAL") end end,
			Size = UDim2.fromScale(0.6, 0.8),
		})
		view.Stats = e("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.62, 0), Size = UDim2.fromScale(0.38, 0.8) }, {
			Content = e(C.Stack, { Children = {
				Title = e(C.Text, { Text = "UPGRADE RESULT", TextColor3 = T.Gold, LayoutOrder = 1 }),
				Rank = e(C.Text, { Text = string.format("CURRENT %d★  →  AFTER %d★", target.Star, after.Star), LayoutOrder = 2 }),
				Stats = e(C.Stack, { Order = 3, Children = { Values = e(Screens.Stats, { Before = target, After = after }) } }),
				Cost = e(C.Text, { Text = if rule then upgradeCostText(rule) else "Maximum stars", TextColor3 = T.Gold, LayoutOrder = 4 }),
				Reason = e(C.Text, { Text = upgradeReason or "Ready to upgrade", TextSize = 14, LayoutOrder = 5 }),
			} }),
		})
		-- A visible way back to the inventory (before, only the X, the tab or Backspace / B left this screen).
		view.Back = e(C.Button, { Name = "UpgradeBackButton", Icon = "Back", Text = "Back", Position = UDim2.new(0, 0, 1, -48), Size = UDim2.new(0.18, -8, 0, 48), Disabled = busy, OnActivate = inventory })
		view.AutoFill = e(C.Button, { Name = "AutoFillMaterialsButton", Text = "Auto-fill safe weapons", Position = UDim2.new(0.18, 0, 1, -48), Size = UDim2.new(0.32, -8, 0, 48), Disabled = busy or maxRank, OnActivate = forge.AutoFill })
		view.Review = e(C.Button, { Name = "ReviewUpgradeButton", Icon = "Forge", Text = string.format("REVIEW UPGRADE · %d★ → %d★", target.Star, after.Star), Primary = true, Position = UDim2.new(0.5, 0, 1, -48), Size = UDim2.new(0.5, 0, 0, 48), Disabled = busy or upgradeReason ~= nil, Tooltip = upgradeReason, OnActivate = reviewUpgrade })

	elseif route == "REVIEW" and target and review then
		local changed = snapshot.Revision ~= review.Revision
		local owners = Model.ownerIds(snapshot, target.UUID)
		local owner = #owners == 1 and snapshot.Heroes[owners[1]] or nil
		-- One-screen visual confirm (Screens.UpgradeReview): kept → result, stat changes, what is
		-- destroyed and the cost.
		view.Review = e(Screens.UpgradeReview, {
			Snapshot = snapshot, Before = review.Before, After = review.After, Materials = review.Materials,
			Gold = review.Gold, Gems = review.Gems, Owner = owner, Changed = changed,
		})
		view.Back = e(C.Button, { Name = "BackToMaterialsButton", Icon = "Back", Text = "Back", Intent = "Secondary", Position = UDim2.new(0, 0, 1, -48), Size = UDim2.new(0.3, -4, 0, 48), Disabled = busy, OnActivate = function() setRoute("MATERIALS") end })
		view.Confirm = e(C.Button, {
			Name = "ConfirmUpgradeButton", Icon = "Forge",
			Text = if busy then "Upgrading…" else string.format("Upgrade %d★ → %d★", review.Before.Star, review.After.Star),
			Intent = "Primary", Position = UDim2.new(0.3, 4, 1, -48), Size = UDim2.new(0.7, -4, 0, 48),
			Disabled = busy or changed or upgradeReason ~= nil,
			Tooltip = if changed then "Your inventory changed. Go back and review again." else upgradeReason,
			OnActivate = function() forge.Upgrade(review.Revision) end,
		})

	elseif route == "RESULT" and target then
		view.Success = e(UpgradeResult, {
			Snapshot = snapshot,
			Before = review and review.Before or target,
			After = target,
			Materials = review and review.Materials,
			Gold = review and review.Gold,
			Gems = review and review.Gems,
			Owner = hero,
			OnBack = inventory,
			OnAgain = startUpgrade,
			MaxRank = maxRank,
		})
	end

	-- Dialogs
	local dialogView = nil
	if dialog == "MATERIAL" then
		local choices = {}
		local candidates = {}
		for _, artifact in snapshot.Artifacts do
			if Model.isEligibleDonor(snapshot, forge.TargetId, artifact.UUID) and not table.find(forge.Materials, artifact.UUID) then
				table.insert(candidates, artifact)
			end
		end
		table.sort(candidates, function(a, b)
			local aOwners = Model.ownerIds(snapshot, a.UUID)
			local bOwners = Model.ownerIds(snapshot, b.UUID)
			local aEquipped = #aOwners > 0
			local bEquipped = #bOwners > 0
			if aEquipped ~= bEquipped then return not aEquipped end
			local aLocked = a.Locked == true
			local bLocked = b.Locked == true
			if aLocked ~= bLocked then return not aLocked end
			local ap, bp = Model.power(a), Model.power(b)
			if ap ~= bp then return ap < bp end
			return a.DisplayName < b.DisplayName
		end)
		for index, artifact in candidates do
			local owners = Model.ownerIds(snapshot, artifact.UUID)
			local isEquipped = #owners > 0
			local isNotUsable = isEquipped or artifact.Locked
			choices[artifact.UUID] = e(C.ArtifactTile, {
				Snapshot = snapshot,
				Artifact = artifact,
				Selected = false,
				Material = false,
				UpgradeChoice = true,
				Order = index,
				ShowPreview = true,
				OnSelect = function()
					if isNotUsable then return end
					forge.ToggleMaterial(artifact.UUID)
					setDialog(nil)
				end,
			})
		end
		-- What qualifies, how many are still needed, and that the pick is destroyed.
		local need = if rule then math.max(0, rule.Donors - #forge.Materials) else 0
		local wanted = if target then string.format("%s %d★", Catalog.GetRarityInfo(target.Rarity).Name, target.Star) else "matching"
		local subtitle = string.format("Pick <b>%d more</b> · any <b>%s</b> weapon · <font color=\"#FF7A7A\">it will be destroyed</font>", need, wanted)
		local empty = next(choices) == nil
		if empty then
			-- Empty state: say why, and offer the way to get one.
			choices.Empty = e("Frame", { Name = "EmptyState", Size = UDim2.new(1, -8, 0, 220), BackgroundTransparency = 1 }, {
				Icon = e("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(64, 64), BackgroundTransparency = 1 }, {
					Art = e(Icons.Icon, { Name = "Forge", Size = 64 }),
				}),
				Text = e(C.Text, {
					Text = string.format("No spare %s weapons yet. Equipped and locked ones can't be used.", wanted),
					TextSize = 16, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Center,
					Position = UDim2.fromOffset(0, 84), Size = UDim2.new(1, 0, 0, 52),
				}),
				Summon = if props.OnSelectTab then e(C.Button, {
					Name = "EmptyGoSummon", Text = "Summon weapons", Icon = "Summon", Intent = "Primary",
					-- C.Button has no AnchorPoint: centre it with the offset.
					Position = UDim2.new(0.5, -130, 0, 148), Size = UDim2.fromOffset(260, 48),
					OnActivate = function() setDialog(nil); props.OnSelectTab("Summon") end,
				}) else nil,
			})
		end
		dialogView = e(Dialog, {
			Title = "Choose upgrade material", Subtitle = subtitle, Cards = not empty, Square = true,
			-- Compact when there is nothing to pick, so the empty state isn't lost in a big empty box.
			MaxSize = if empty then Vector2.new(600, 360) else Vector2.new(780, 560),
			Children = choices, OnCancel = function() setDialog(nil) end, FocusKey = "MATERIAL",
		})
	elseif dialog == "HERO" and target then
		dialogView = e(HeroPicker, {
			Snapshot = snapshot, Target = target, Busy = busy,
			OnClose = function() setDialog(nil) end,
			OnSelect = function(uuid)
				local chosen = snapshot.Heroes[uuid]
				if busy or not chosen or not Model.compatible(chosen, target) then return end
				forge.SetHero(uuid)
				local accepted = if chosen.EquippedArtifactUUID == target.UUID then forge.Unequip(uuid) else forge.Equip(uuid)
				if accepted then setDialog(nil) end
			end,
		})
	elseif dialog == "FILTER" then
		local choices: { [string]: any } = {
			Clear = e(C.Button, { Text = "Clear filters", OnActivate = clearFilters, Order = 0 }),
		}
		for index, value in { "ALL", "EQUIPPED", "UNEQUIPPED" } do
			choices["Ownership" .. value] = e(C.Button, { Text = value, Selected = filter.Ownership == value, OnActivate = function() updateFilter("Ownership", value) end, Order = index })
		end
		choices.Rarity = e(C.Text, { Text = "RARITY", TextColor3 = T.Gold, LayoutOrder = 8 })
		choices.AllRarities = e(C.Button, { Text = "All rarities", Selected = filter.Rarity == 0, OnActivate = function() updateFilter("Rarity", 0) end, Order = 9 })
		for index, r in Catalog.Rarities do choices["Rarity" .. index] = e(C.Button, { Text = r.Name, Selected = filter.Rarity == index, OnActivate = function() updateFilter("Rarity", index) end, Order = 10 + index }) end
		dialogView = e(Dialog, { Title = "Inventory filters", Children = choices, OnCancel = function() setDialog(nil) end, FocusKey = "FILTER" })
	end

	-- Before any server result, the footer is a hint that follows what the player is doing (it used to
	-- keep saying "Select an artifact…" after one was selected, and on the upgrade screen).
	local idleHint = if route == "MATERIALS" or route == "REVIEW" then (upgradeReason or "Ready: review the upgrade.")
		elseif target then string.format("%s selected. Equip, upgrade, lock or sell it.", target.DisplayName)
		else "Select an artifact to equip or upgrade."
	-- The footer is only ever a hint now. Server results and refusals ("Not enough unprotected
	-- artifacts", "Optimal gear equipped…") are toasts (the effects below), so they can't be missed
	-- in small text at the bottom.
	local message = if sellMode then "Select spare weapons to sell. Equipped and locked weapons are protected." else idleHint

	return e("ScreenGui", {
		Name = "ForgeWorkbench", ResetOnSpawn = false, DisplayOrder = 80, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		[React.Change.AbsoluteSize] = function(gui) setScreen(gui.AbsoluteSize) end,
	}, {
		Scrim = e("Frame", { Name = "Scrim", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Active = true, BorderSizePixel = 0, ZIndex = 1 }),
		Root = e("Frame", {
			ref = rootRef, Name = "Root", AnchorPoint = Vector2.new(0.5, 0.5), Position = windowPosition,
			Size = UDim2.fromOffset(width, height), BackgroundColor3 = T.Background, BorderSizePixel = 0, ZIndex = 2,
			SelectionGroup = true, SelectionBehaviorUp = Enum.SelectionBehavior.Escape, SelectionBehaviorDown = Enum.SelectionBehavior.Stop, SelectionBehaviorLeft = Enum.SelectionBehavior.Stop, SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
		}, {
			Scale = e(WindowScale, { Scale = windowScale, Window = "Forge" }),
			-- Header: the Forge's ember bar, icon, title and the Artifacts / Summon tabs, all inside
			-- the window (they used to float above it in a separate bar).
			HeaderBar = e("Frame", {
				ref = headerBarRef, Name = "HeaderBar",
				Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, 56), ZIndex = 0,
			}),
			HeaderIcon = e("Frame", {
				Position = UDim2.fromOffset(18, 8),
				Size = UDim2.fromOffset(46, 46),
				BackgroundTransparency = 1,
			}, { Art = e(Icons.Icon, { Name = "Forge", Size = 46 }) }),
			HeaderTitle = e(C.Text, {
				Text = "FORGE",
				FontFace = T.Theme.Fonts.Title,
				TextSize = 28,
				TextColor3 = T.Text,
				TextStrokeColor3 = T.Theme.Ink,
				TextStrokeTransparency = 0,
				Position = UDim2.fromOffset(72, 14),
				Size = UDim2.fromOffset(120, 34),
			}),
			Tabs = e("Frame", {
				Name = "ForgeTabs", Position = UDim2.fromOffset(196, 12), Size = UDim2.fromOffset(276, 42), BackgroundTransparency = 1,
			}, {
				Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
				Artifacts = e(C.Button, {
					Name = "ArtifactsTab", Text = "Artifacts", Order = 1, Size = UDim2.fromOffset(134, 42), Selected = not summonTab,
					Disabled = busy and summonTab, OnActivate = function() if summonTab and props.OnSelectTab then props.OnSelectTab("Artifacts") end end,
				}),
				Summon = e(C.Button, {
					Name = "SummonTab", Text = "Summon", Order = 2, Size = UDim2.fromOffset(134, 42), Selected = summonTab,
					Disabled = busy and not summonTab, OnActivate = function() if not summonTab and props.OnSelectTab then props.OnSelectTab("Summon") end end,
				}),
			}),
			-- Currencies + Capacity Counter
			Gold = e(C.Currency, { Icon = "Gold", Text = Balance.Format(snapshot.Gold), Position = UDim2.new(1, -520, 0, 16) }),
			Gems = e(C.Currency, { Icon = "Gems", Text = Balance.Format(snapshot.Gems), Position = UDim2.new(1, -360, 0, 16) }),
			Capacity = e("Frame", {
				Name = "BackpackCapacityChip",
				Position = UDim2.new(1, -200, 0, 16),
				Size = UDim2.fromOffset(136, 34),
				BackgroundColor3 = T.Theme.Tones.Deep.Bottom,
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Outline = e("UIStroke", { Color = capColor, Thickness = 1.8 }),
				Icon = e("Frame", {
					Position = UDim2.fromOffset(8, 6),
					Size = UDim2.fromOffset(22, 22),
					BackgroundTransparency = 1,
				}, { Art = e(Icons.Icon, { Name = "Backpack", Size = 22 }) }),
				Label = e(C.Text, {
					Text = string.format("%d/%d", artifactCount, artifactCap),
					FontFace = T.Theme.Fonts.Number,
					TextSize = 16,
					TextColor3 = capColor,
					TextXAlignment = Enum.TextXAlignment.Center,
					Position = UDim2.fromOffset(32, 0),
					Size = UDim2.new(1, -36, 1, 0),
				}),
			}),
			Close = e(C.Button, {
				Name = "CloseForgeButton",
				Text = "",
				Icon = "Close",
				Accent = T.Bad,
				Position = UDim2.new(1, -54, 0, 11),
				Size = UDim2.fromOffset(44, 44),
				OnActivate = props.OnClose,
				FocusOrder = -100,
			}),
			-- Main Body Area
			Body = e("Frame", {
				Name = "Body",
				Position = UDim2.fromOffset(16, 68),
				Size = UDim2.new(1, -32, 1, -78 - statusHeight),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
				-- Brighter Grimoire: a lifted plum panel instead of near-black.
				Fill = e("UIGradient", { Rotation = 90, Color = ColorSequence.new(Kit.Tokens.Surface.Panel.Top, Kit.Tokens.Surface.Panel.Bottom) }),
				Rail = e("UIStroke", { Color = Kit.Tokens.Surface.Panel.Rail, Thickness = 1.4, Transparency = 0.35 }),
				Content = if summonTab then nil else e("Frame", {
					ref = bodyRef,
					Name = "Content",
					Position = UDim2.fromOffset(8, 8),
					Size = UDim2.new(1, -16, 1, -16),
					BackgroundTransparency = 1,
				}, view),
				-- Summon tab: the legacy summon view (banner, pity, Summon 1x/10x) is parented here.
				SummonHost = if summonTab then e("Frame", {
					ref = summonHostRef,
					Name = "SummonHost",
					Position = UDim2.fromOffset(12, 10),
					Size = UDim2.new(1, -24, 1, -20),
					BackgroundTransparency = 1,
				}) else nil,
			}),
			-- Status Bar (hidden on RESULT screen so message doesn't duplicate, and on the Summon tab)
			Status = if route ~= "RESULT" and not summonTab then e("Frame", {
				Name = "Status",
				Position = UDim2.new(0, 16, 1, -statusHeight),
				Size = UDim2.new(1, -32, 0, statusHeight - 4),
				BackgroundTransparency = 1,
			}, {
				Message = e("Frame", {
					Size = UDim2.new(1, if statusAction then -172 else 0, 1, 0),
					BackgroundTransparency = 1,
				}, { Text = e(Feedback, { Text = message, Success = forge.Success, Sequence = forge.Sequence }) }),
				Undo = if forge.Undo then e("Frame", {
					Position = UDim2.new(1, -164, 0, 2),
					Size = UDim2.fromOffset(164, 42),
					BackgroundTransparency = 1,
				}, { Button = e(UndoButton, { ExpiresAt = forge.Undo.ExpiresAt, Busy = busy, OnUndo = forge.UndoLast }) })
				elseif forge.Phase == "uncertain" then e(C.Button, {
					Name = "ReconcileForgeButton",
					Text = "Check status",
					Position = UDim2.new(1, -164, 0, 2),
					Size = UDim2.fromOffset(164, 42),
					OnActivate = forge.Reconcile,
				}) else nil,
			}) else nil,
			Modal = dialogView,
		}),
	})
end

return App
