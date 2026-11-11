--!strict
-- The Backpack lives in the Phase 5 HUD overlay and reads the existing profile store.
local ContextActionService = game:GetService("ContextActionService")
local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Grimoire = require(ReplicatedStorage.Shared.Util.GildedGrimoire)
local GrimoireIcons = require(ReplicatedStorage.Shared.Util.GrimoireIcons)
local Components = require(script.Parent.Components)
local WindowScale = require(script.Parent.Parent.WindowScale)
local Model = require(script.Parent.BackpackModel)
local Portrait = require(script.Parent.Portrait)
local ArtifactPreview = require(script.Parent.Parent.ArtifactPreview)
local UIAssets = require(script.Parent.Parent.UIAssets)
local Store = require(script.Parent.Store)

type Tab = Model.Tab
type Row = Model.Row

local e = React.createElement
local Panel = Components.Panel
local Heavy = Components.HeavyLabel
local Body = Components.Body
local Tones = Grimoire.Tones
local MUTED = Grimoire.Text.Muted
local TABS: { Tab } = { "Artifacts", "Heroes", "Materials" }
local CLOSE_ACTION = "InfiniteTowersBackpackBack"
local EMPTY = { Artifacts = "No artifacts owned yet.", Heroes = "No heroes owned yet.", Materials = "No materials owned yet." }
local PROMOTION_STONE_IMAGE = UIAssets.Images.PromotionStone

local lastTab: Tab = "Artifacts"

local function focus(target: GuiObject?)
	if target and UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then
		GuiService.SelectedObject = target
	end
end

local function button(props: { [any]: any }, text: string, selected: boolean?, labelColor: Color3?)
	local tone = if selected then Tones.Bronze else Tones.Slate
	props.Class = "TextButton"
	props.Text = ""
	props.AutoButtonColor = false
	props.Selectable = true
	props.Radius = 9
	props.Top, props.Bottom, props.Rail = tone.Top, tone.Bottom, tone.Rail
	return Panel(props, {
		Label = Heavy({ Text = text, Gold = selected == true and labelColor == nil, TextColor3 = labelColor, MaxSize = 15, Outline = 2,
			Position = UDim2.fromOffset(4, 3), Size = UDim2.new(1, -8, 1, -6) }),
	})
end

local function Weapon(props: { TemplateId: string, Size: number })
	local host = React.useRef(nil :: Frame?)
	React.useEffect(function()
		local frame = host.current
		if frame and not ArtifactPreview.Show(frame, props.TemplateId) then
			-- The themed icon covers legacy artifacts with missing models.
			GrimoireIcons.Create("Forge", props.Size, frame)
		end
		return function()
			if frame then frame:ClearAllChildren() end
		end
	end, { props.TemplateId, props.Size })
	return e("Frame", { ref = host, Size = UDim2.fromOffset(props.Size, props.Size), BackgroundTransparency = 1 })
end

local function PromotionStoneIcon(props: { Size: number, Fallback: string })
	local imageLoaded, setImageLoaded = React.useState(false)
	React.useEffect(function()
		local function update()
			setImageLoaded(ContentProvider:GetAssetFetchStatus(PROMOTION_STONE_IMAGE) == Enum.AssetFetchStatus.Success)
		end
		local connection = ContentProvider:GetAssetFetchStatusChangedSignal(PROMOTION_STONE_IMAGE):Connect(update)
		update()
		return function() connection:Disconnect() end
	end, {})
	local size = UDim2.fromOffset(props.Size, props.Size)
	return e("Frame", { Size = size, BackgroundTransparency = 1 }, {
		Fallback = if imageLoaded then nil else Components.IconAt(props.Fallback, props.Size, {}),
		Icon = e("ImageLabel", {
			Name = "PromotionStoneIcon",
			Image = PROMOTION_STONE_IMAGE,
			Size = size,
			ScaleType = Enum.ScaleType.Fit,
			BackgroundTransparency = 1,
		}),
	})
end

local function illustration(row: Row, size: number)
	if row.TemplateId then
		return e(Portrait, { TemplateId = row.TemplateId, Archetype = row.Archetype, Stars = row.Stars, Size = UDim2.fromOffset(size, size) })
	end
	if row.Icon == "Forge" and row.ArtifactTemplateId then
		return e(Weapon, { TemplateId = row.ArtifactTemplateId, Size = size })
	end
	if row.Id == "PromotionStone" and PROMOTION_STONE_IMAGE ~= "" then
		return e(PromotionStoneIcon, { Size = size, Fallback = row.Icon })
	end
	return Components.IconAt(row.Icon, size, {})
end

local function card(row: Row, order: number, selected: boolean, onSelect: (string) -> ())
	local tone = if selected then Tones.Bronze else Tones.Slate
	return Panel({
		Class = "TextButton", Name = "Row_" .. row.Id, LayoutOrder = order,
		Size = UDim2.new(1, -6, 0, 72), Text = "", Selectable = true, AutoButtonColor = false,
		Top = tone.Top, Bottom = tone.Bottom, Rail = if selected then tone.Rail else row.Color,
		[React.Event.Activated] = function() onSelect(row.Id) end,
	}, {
		Art = e("Frame", { Position = UDim2.fromOffset(8, 12), Size = UDim2.fromOffset(48, 48), BackgroundTransparency = 1 },
			{ Icon = illustration(row, 48) }),
		Title = Heavy({ Text = row.Name, TextXAlignment = Enum.TextXAlignment.Left, MaxSize = 16, Outline = 2,
			Position = UDim2.fromOffset(63, 7), Size = UDim2.new(1, -71, 0, 20) }),
		Summary = Body({ Text = row.Summary, TextSize = 13, TextColor3 = row.Color,
			Position = UDim2.fromOffset(63, 29), Size = UDim2.new(1, -71, 0, 16), RichText = false }),
		Status = if row.Status then Body({ Text = row.Status, TextSize = 12, TextColor3 = MUTED,
			Position = UDim2.fromOffset(63, 48), Size = UDim2.new(1, -71, 0, 16), RichText = false }) else nil,
	})
end

local function details(row: Row?, size: UDim2, position: UDim2)
	return Panel({
		Name = "Details", Position = position, Size = size,
		Top = Tones.Deep.Top, Bottom = Tones.Deep.Bottom, Rail = Tones.Deep.Rail,
	}, {
		Content = if row then e("ScrollingFrame", {
			key = row.Id, Size = UDim2.new(1, -16, 1, -16), Position = UDim2.fromOffset(8, 8),
			BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 4,
		}, {
			Padding = e("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10),
				PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 12) }),
			Layout = e("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
			Art = e("Frame", { LayoutOrder = 1, Size = UDim2.fromOffset(64, 64), BackgroundTransparency = 1 },
				{ Icon = illustration(row, 64) }),
			Title = Heavy({ LayoutOrder = 2, Text = row.Name, TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, 0, 0, 30), MaxSize = 24, Outline = 2 }),
			Summary = Body({ LayoutOrder = 3, Text = row.Summary, TextSize = 15, TextColor3 = row.Color,
				Size = UDim2.new(1, 0, 0, 20), RichText = false }),
			Status = if row.Status then Body({ LayoutOrder = 4, Text = row.Status, TextSize = 14, TextColor3 = MUTED,
				Size = UDim2.new(1, 0, 0, 20), RichText = false }) else nil,
			AssignedArtifact = if row.Icon == "Squad" then Panel({
				Name = "AssignedArtifact", LayoutOrder = 6, Size = UDim2.new(1, 0, 0, 66),
				Top = Tones.Slate.Top, Bottom = Tones.Slate.Bottom,
				Rail = if row.AssignedArtifact then Tones.Bronze.Rail else Color3.fromRGB(241, 148, 112),
			}, {
				Heading = Body({ Text = "Assigned artifact", TextSize = 12, TextColor3 = MUTED,
					Position = UDim2.fromOffset(12, 9), Size = UDim2.new(1, -24, 0, 17) }),
				Name = Heavy({ Text = row.AssignedArtifact or "No artifact assigned", MaxSize = 19, Gold = false,
					TextColor3 = if row.AssignedArtifact then Color3.fromRGB(255, 220, 146) else Color3.fromRGB(255, 171, 134),
					TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(12, 29),
					Size = UDim2.new(1, if row.ArtifactTemplateId then -82 else -24, 0, 25) }),
				Preview = if row.ArtifactTemplateId then e("Frame", {
					Position = UDim2.new(1, -61, 0, 7), Size = UDim2.fromOffset(52, 52), BackgroundTransparency = 1,
				}, { Weapon = e(Weapon, { TemplateId = row.ArtifactTemplateId, Size = 52 }) }) else nil,
			}) else nil,
			Description = Body({ LayoutOrder = 5, Text = row.Description, TextSize = 14, TextWrapped = true, RichText = false,
				AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), TextTruncate = Enum.TextTruncate.None }),
		}) else Body({ Text = "Select an item to inspect it.", TextSize = 15, TextColor3 = MUTED, TextWrapped = true,
			Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 46) }),
	})
end

local function BackpackPanel(props: { Width: number, Height: number, OnClose: () -> (), ReturnFocus: () -> () })
	local tab, setTab = React.useState(lastTab)
	local rows, setRows = React.useState(function() return Model.Build(Store.Profile, lastTab) end)
	local selectedId, setSelectedId = React.useState(nil :: string?)
	local showDetails, setShowDetails = React.useState(false)
	local tabRef = React.useRef(nil :: GuiButton?)
	local backRef = React.useRef(nil :: GuiButton?)
	local listRef = React.useRef(nil :: ScrollingFrame?)
	local restoreRow = React.useRef(false)

	React.useEffect(function()
		local track = Model.Track(tab)
		local function refresh()
			local changed, nextRows = track(Store.Profile)
			if changed then setRows(nextRows) end
		end
		local connection = Store.Changed:Connect(refresh)
		refresh()
		return function() connection:Disconnect() end
	end, { tab })

	local narrow = props.Width < 680
	local selected: Row? = nil
	for _, row in rows or {} do
		if row.Id == selectedId then selected = row break end
	end
	local inDetails = narrow and showDetails and selected ~= nil

	React.useEffect(function()
		if selectedId and not selected then
			restoreRow.current = true
			setSelectedId(nil)
			setShowDetails(false)
		end
	end, { selectedId, selected ~= nil })

	React.useEffect(function()
		if inDetails then
			focus(backRef.current)
		elseif restoreRow.current then
			restoreRow.current = false
			local list = listRef.current
			local row = if list and selectedId then list:FindFirstChild("Row_" .. selectedId) else nil
			focus(if row and row:IsA("GuiObject") then row else tabRef.current)
		else
			focus(tabRef.current)
		end
	end, { tab, inDetails, selectedId == nil })

	local function close()
		props.OnClose()
		props.ReturnFocus()
	end

	local function back()
		restoreRow.current = true
		setShowDetails(false)
	end

	React.useEffect(function()
		ContextActionService:BindAction(CLOSE_ACTION, function(_, state)
			if state == Enum.UserInputState.Begin then
				if inDetails then back() else close() end
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.ButtonB)
		return function() ContextActionService:UnbindAction(CLOSE_ACTION) end
	end, { inDetails, props.OnClose, props.ReturnFocus })

	local width = math.min(1000, math.max(1, props.Width - 24))
	local height = math.min(650, math.max(1, props.Height - 24))
	local compact = height < 340
	local tabY = if compact then 50 else 62
	local tabHeight = if compact then 42 else 46
	local contentY = tabY + tabHeight + 10
	local capacity = Model.Capacity(Store.Profile)
	local function capColor(c: Model.Capacity): Color3?
		if c.Have >= c.Max then return Color3.fromHex("#F87171") end
		if c.Have >= c.Max - 5 then return Color3.fromHex("#FBBF24") end
		return nil
	end
	local fullNote = if capacity.Artifacts.Have >= capacity.Artifacts.Max then "Artifacts full: sell or promote at the Forge to summon more."
		elseif capacity.Heroes.Have >= capacity.Heroes.Max then "Heroes full: convert or synthesize at the Pit to summon more."
		else nil

	local tabs = {}
	for i, name in TABS do
		tabs[name] = button({
			Name = name, ref = if tab == name then tabRef else nil,
			Position = UDim2.new((i - 1) / 3, 2, 0, 0), Size = UDim2.new(1 / 3, -4, 1, 0),
			[React.Event.Activated] = function()
				if tab == name then
					if inDetails then back() end
					return
				end
				lastTab = name
				setSelectedId(nil)
				setShowDetails(false)
				setRows(Model.Build(Store.Profile, name))
				setTab(name)
			end,
		}, if name == "Artifacts" then string.format("Artifacts %d/%d", capacity.Artifacts.Have, capacity.Artifacts.Max)
			elseif name == "Heroes" then string.format("Heroes %d/%d", capacity.Heroes.Have, capacity.Heroes.Max)
			else name, tab == name, if name == "Artifacts" then capColor(capacity.Artifacts)
			elseif name == "Heroes" then capColor(capacity.Heroes) else nil)
	end

	local listChildren: { [string]: any } = {
		Layout = e("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 7) }),
		Padding = e("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingLeft = UDim.new(0, 3), PaddingBottom = UDim.new(0, 5) }),
	}
	if not rows or #rows == 0 then
		listChildren.Empty = Body({ Text = if not rows then "Loading your backpack…" else EMPTY[tab],
			TextSize = 15, TextColor3 = MUTED, TextWrapped = true, Size = UDim2.new(1, -10, 0, 48) })
	else
		for i, row in rows do
			listChildren[row.Id] = card(row, i, row.Id == selectedId, function(id)
				setSelectedId(id)
				if narrow then setShowDetails(true) end
			end)
		end
	end

	return e("Frame", { Name = "BackpackOverlay", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 12 }, {
		Scrim = e("TextButton", { Name = "Scrim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(9, 6, 14),
			BackgroundTransparency = 1, AutoButtonColor = false, Selectable = false, Text = "", BorderSizePixel = 0,
			[React.Event.Activated] = close }),
		Window = Panel({
			Name = "BackpackWindow", AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(width, height),
			Active = true, ZIndex = 2, SelectionGroup = true,
			SelectionBehaviorUp = Enum.SelectionBehavior.Stop, SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
			SelectionBehaviorLeft = Enum.SelectionBehavior.Stop, SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
			Top = Tones.Violet.Top, Bottom = Tones.Deep.Bottom, Rail = Tones.Bronze.Rail,
		}, {
			Pop = e(WindowScale, { Window = "Backpack" }),
			Title = Heavy({ Text = "Backpack", MaxSize = 28, TextXAlignment = Enum.TextXAlignment.Left,
				Position = UDim2.fromOffset(20, 10), Size = UDim2.new(1, -84, 0, 34) }),
			FullNote = if fullNote then Body({ Name = "FullNote", TextSize = 12, TextColor3 = Color3.fromRGB(248, 113, 113),
				TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.new(0.4, 0, 0, 28), Size = UDim2.new(0.6, -66, 0, 18), Text = fullNote }) else nil,
			Close = Panel({
				Class = "TextButton", Name = "Close", Text = "", AutoButtonColor = false, Selectable = true,
				AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 8),
				Size = UDim2.fromOffset(44, 40), Radius = 10,
				Top = Tones.Crimson.Top, Bottom = Tones.Crimson.Bottom, Rail = Tones.Crimson.Rail, ZIndex = 10,
				[React.Event.Activated] = close,
			}, {
				X = Components.IconAt("Close", 18, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 12 }),
			}),
			Tabs = e("Frame", { Name = "Tabs", Position = UDim2.fromOffset(10, tabY),
				Size = UDim2.new(1, -20, 0, tabHeight), BackgroundTransparency = 1 }, tabs),
			List = e("ScrollingFrame", {
				key = tab, Name = "InventoryList", ref = listRef, Visible = not inDetails, Position = UDim2.fromOffset(12, contentY),
				Size = UDim2.new(if narrow then 1 else 0.56, if narrow then -24 else -16, 1, -contentY - 12),
				BackgroundTransparency = 1, BorderSizePixel = 0, AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(), ScrollBarThickness = 5, ScrollingDirection = Enum.ScrollingDirection.Y,
				ScrollBarImageColor3 = Color3.fromRGB(238, 192, 100),
			}, listChildren),
			Back = if inDetails then button({ Name = "Back", ref = backRef, Position = UDim2.fromOffset(12, contentY),
				Size = UDim2.fromOffset(90, 42), [React.Event.Activated] = back }, "Back") else nil,
			Details = if inDetails then details(selected, UDim2.new(1, -24, 1, -contentY - 62), UDim2.fromOffset(12, contentY + 50))
				elseif not narrow then details(selected, UDim2.new(0.44, -18, 1, -contentY - 12), UDim2.new(0.56, 6, 0, contentY)) else nil,
		}),
	})
end

return React.memo(BackpackPanel)
