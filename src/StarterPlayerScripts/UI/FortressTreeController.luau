--!strict
-- StarterPlayerScripts/UI/FortressTreeController.luau
-- The Fortress Development Tree panel (Phase 4 §5), opened from the Architect's Table or the
-- FORTRESS toolbar button. A full-screen, windowless map of hexagon nodes winding out from the
-- Citadel Charter in four branches: drag to pan, scroll (or +/−) to zoom toward the cursor, and
-- hover a node for its tooltip. The server validates every purchase
-- through ProgressionRemotes.UnlockTreeNode.
--
-- Node states:
--   OWNED      blue, white rim, check mark
--   AVAILABLE  blue, price in gold (red when short of Gold); click to build
--   GATED      dark, "Floor N Required" (prerequisites owned, floor not cleared)
--   HIDDEN     dark "?" (its previous node is not built yet)
-- Touch: the first tap on a node shows its tooltip, a second tap builds it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TreeConfig = require(Shared:WaitForChild("Config"):WaitForChild("FortressTreeConfig"))
local FortressTree = require(Shared:WaitForChild("Util"):WaitForChild("FortressTree"))
local GrimoireIcons = require(Shared:WaitForChild("Util"):WaitForChild("GrimoireIcons"))

local Controller = {}
Controller.__index = Controller

local HEX_RADIUS = 46 -- pointy-top circumradius in pixels
local HEX_SPACING = 48 -- grid radius; the 2 px difference leaves a gap between neighbours
local RIM = 3
local DRAG_THRESHOLD = 6
local SQRT3 = math.sqrt(3)
local ZOOM_MIN, ZOOM_MAX = 0.45, 1.8
local ZOOM_STEP = 1.15 -- per scroll notch or +/− press
local ZOOM_ACTION = "FortressTreeZoom"

local C = {
	Scrim = Color3.fromRGB(6, 5, 10),
	Blue = Color3.fromRGB(64, 156, 236),
	BlueDark = Color3.fromRGB(40, 112, 196),
	Owned = Color3.fromRGB(56, 140, 220),
	Root = Color3.fromRGB(246, 160, 36),
	Dark = Color3.fromRGB(82, 80, 90),
	Rim = Color3.fromRGB(255, 255, 255),
	RimDark = Color3.fromRGB(44, 42, 50),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(175, 168, 192),
	Gold = Color3.fromRGB(255, 214, 64),
	Red = Color3.fromRGB(255, 90, 90),
	Green = Color3.fromRGB(110, 230, 140),
}

-- Branch icons (Gilded Grimoire drawings); perks use a spark, the root the citadel.
local ICONS: { [string]: string } = {
	Root = "Fortress",
	Outskirts = "Camp",
	Commerce = "Market",
	Martial = "Power",
	Divine = "Blessing",
	Command = "Banner",
	Perk = "Spark",
}

-- Swaps the drawn icon inside a node's icon frame (rebuilt only when the name changes).
local function setIcon(frame: Frame, name: string?)
	if frame:GetAttribute("IconName") == (name or "") then return end
	frame:SetAttribute("IconName", name or "")
	frame:ClearAllChildren()
	if name then
		GrimoireIcons.Create(name, 34, frame, frame.ZIndex)
	end
end

-- Pointy-top axial coordinates. The root sits at the centre; Divine winds north, Command north-east,
-- Commerce east, Outskirts south and Martial west, with each perk beside the level it hangs from.
local LAYOUT: { [string]: { number } } = {
	root = { 0, 0 },
	gb_1 = { 0, -1 }, gb_2 = { 1, -2 }, gb_3 = { 1, -3 }, gb_4 = { 2, -4 }, gb_5 = { 2, -5 },
	gb_votive_candles = { 0, -3 }, gb_saints_favor = { 1, -5 },
	mk_1 = { 1, 0 }, mk_2 = { 2, 0 }, mk_3 = { 3, -1 }, mk_4 = { 4, -1 }, mk_5 = { 5, -2 },
	mk_extra_stall = { 3, 0 }, mk_appraiser = { 5, -1 },
	gp_1 = { 0, 1 }, gp_2 = { -1, 2 }, gp_3 = { -1, 3 }, gp_4 = { -2, 4 }, gp_5 = { -2, 5 },
	gp_night_watch = { 0, 3 }, gp_long_patrols = { -1, 5 },
	tg_1 = { -1, 0 }, tg_2 = { -2, 0 }, tg_3 = { -3, 1 }, tg_4 = { -4, 1 }, tg_5 = { -5, 2 },
	tg_drill_sergeant = { -3, 0 }, tg_veteran_drills = { -5, 1 },
	-- Command (squad slots) climbs north-east, between Divine and Commerce.
	sq_1 = { 1, -1 }, sq_2 = { 2, -2 }, sq_3 = { 3, -3 }, sq_4 = { 4, -4 },
}

local function hexToPixel(q: number, r: number): Vector2
	return Vector2.new(HEX_SPACING * SQRT3 * (q + r / 2), HEX_SPACING * 1.5 * r)
end

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local o = Instance.new(className)
	for k, v in pairs(props) do
		(o :: any)[k] = v
	end
	o.Parent = parent
	return o
end

local function formatShort(n: number): string
	if n >= 1e6 then return string.format("%.1fm", n / 1e6) end
	if n >= 1e3 then return string.format("%gk", math.floor(n / 100) / 10) end
	return tostring(math.floor(n))
end

local function formatGold(n: number): string
	local s = tostring(math.floor(n))
	while true do
		local replaced, count = string.gsub(s, "^(-?%d+)(%d%d%d)", "%1,%2")
		s = replaced
		if count == 0 then break end
	end
	return s
end

-- A pointy-top hexagon is the union of three √3R x R bars rotated 0, 60 and 120 degrees.
local function hexagon(parent: Instance, radius: number, color: Color3, zIndex: number): { Frame }
	local bars = {}
	for i = 0, 2 do
		table.insert(bars, new("Frame", {
			Name = "Hex",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(SQRT3 * radius, radius),
			Rotation = i * 60,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = zIndex,
		}, parent))
	end
	return bars
end

local function paint(bars: { Frame }, color: Color3)
	for _, bar in bars do
		bar.BackgroundColor3 = color
	end
end

function Controller.new(gui: ScreenGui, getProfile: () -> any, remotes: Instance)
	local self: any = setmetatable({}, Controller)
	self.Gui = gui
	self.GetProfile = getProfile
	self.Busy = false
	self.Unlock = remotes:WaitForChild("UnlockTreeNode") :: RemoteFunction
	self.Nodes = {} :: { [string]: any }
	self.Pan = Vector2.zero
	self.Dragging = false
	self.Dragged = false
	self.Selected = nil :: string?
	self.Hovered = nil :: string?
	self.LastTouch = false

	-- No window: the map floats over a light dim of the world, and the whole screen is the drag area.
	self.Scrim = new("Frame", {
		Name = "FortressTreeScrim",
		BackgroundColor3 = C.Scrim,
		BackgroundTransparency = 0.55,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 50,
	}, gui)

	local root = new("Frame", {
		Name = "FortressTreeOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 51,
	}, gui)
	self.Root = root
	self.Board = root
	-- Middle-bottom Close button: fixed in front of the map, styled with vibrant crimson fill,
	-- rounded pill frame, dark ink border, and heavy outlined text matching the game's theme.
	local closeButton = new("TextButton", {
		Name = "CloseButton",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(190, 48),
		BackgroundColor3 = Color3.fromRGB(235, 52, 52),
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
		Active = true,
		ZIndex = 90,
	}, root)
	closeButton:SetAttribute("Grimoire", true)

	local buttonScale = new("UIScale", { Scale = 1 }, closeButton)

	new("UICorner", {
		CornerRadius = UDim.new(0, 12),
	}, closeButton)

	new("UIStroke", {
		Name = "Outline",
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(15, 10, 20),
		Thickness = 3,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, closeButton)

	new("UIGradient", {
		Name = "Gradient",
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(252, 75, 75)),
			ColorSequenceKeypoint.new(0.45, Color3.fromRGB(235, 48, 48)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(195, 30, 30)),
		}),
	}, closeButton)

	local closeLabel = new("TextLabel", {
		Name = "Label",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "Close",
		Font = Enum.Font.GothamBlack,
		TextSize = 24,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Active = false,
		ZIndex = 91,
	}, closeButton)
	closeLabel:SetAttribute("Grimoire", true)

	new("UIStroke", {
		Name = "TextStroke",
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Color = Color3.fromRGB(15, 10, 20),
		Thickness = 2.8,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, closeLabel)

	closeButton.MouseEnter:Connect(function()
		TweenService:Create(buttonScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.05 }):Play()
		TweenService:Create(closeButton, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(252, 68, 68) }):Play()
	end)
	closeButton.MouseLeave:Connect(function()
		TweenService:Create(buttonScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(closeButton, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(235, 52, 52) }):Play()
	end)
	closeButton.MouseButton1Down:Connect(function()
		TweenService:Create(buttonScale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.95 }):Play()
	end)
	closeButton.MouseButton1Up:Connect(function()
		TweenService:Create(buttonScale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.05 }):Play()
	end)
	closeButton.Activated:Connect(function()
		if not self.Busy and not self.Dragged then
			self:Close()
		end
	end)

	local function label(parent: Instance, value: string, size: number, color: Color3, props: { [string]: any }?): TextLabel
		local lbl = new("TextLabel", {
			BackgroundTransparency = 1,
			Text = value,
			TextSize = size,
			TextColor3 = color,
			TextStrokeTransparency = 0.35,
			Font = Enum.Font.GothamBold,
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 60,
		}, parent)
		for k, v in pairs(props or {}) do
			(lbl :: any)[k] = v
		end
		return lbl
	end

	local titleIcon = GrimoireIcons.Create("Fortress", 38, root, 60)
	titleIcon.Position = UDim2.fromOffset(20, 12)
	label(root, "UPGRADES", 24, C.Gold, { Position = UDim2.fromOffset(66, 16), Size = UDim2.fromOffset(420, 30) })
	label(root, "Drag to explore · scroll to zoom · hover for details · click to build", 13, C.Text, { Position = UDim2.fromOffset(24, 46), Size = UDim2.fromOffset(520, 18), Font = Enum.Font.GothamMedium })
	self.Status = label(root, "", 14, C.Text, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 24, 1, -20), Size = UDim2.fromOffset(360, 22), Font = Enum.Font.GothamMedium })

	-- Everything on the map lives in `canvas`: screen centre + pan, scaled by the zoom.
	local canvas = new("Frame", {
		Name = "Canvas",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		ZIndex = 53,
	}, root)
	self.Canvas = canvas
	self.ZoomScale = new("UIScale", {}, canvas)

	local minX, maxX, minY, maxY = 0, 0, 0, 0
	for _, node in TreeConfig.Nodes do
		local hex = LAYOUT[node.Id]
		if hex then
			local p = hexToPixel(hex[1], hex[2])
			minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
			minY, maxY = math.min(minY, p.Y), math.max(maxY, p.Y)
			self.Nodes[node.Id] = self:BuildNode(canvas, node, p)
		end
	end
	-- Map extent in unzoomed pixels; panning stops once an edge of the map reaches the screen centre.
	self.MapBounds = { MinX = minX, MaxX = maxX, MinY = minY, MaxY = maxY }

	self:BuildTooltip(gui)
	self:BindDrag()

	-- The default zoom fits the screen height; scrolling and the +/− buttons adjust from there.
	local function resize()
		local cam = Workspace.CurrentCamera
		if not cam then return end
		local fresh = self.Zoom == nil or self.Zoom == self.DefaultZoom
		self.DefaultZoom = math.clamp(cam.ViewportSize.Y / 900, ZOOM_MIN, 1)
		if fresh then self:SetZoom(self.DefaultZoom, nil) end
	end
	local camConn: RBXScriptConnection? = nil
	local function track()
		if camConn then camConn:Disconnect() end
		if Workspace.CurrentCamera then
			camConn = Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
		end
		resize()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(track)
	track()

	return self
end

function Controller:BuildNode(canvas: Frame, node: any, at: Vector2): any
	local holder = new("Frame", {
		Name = node.Id,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(at.X, at.Y),
		Size = UDim2.fromOffset(SQRT3 * HEX_RADIUS, 2 * HEX_RADIUS),
		BackgroundTransparency = 1,
		ZIndex = 54,
	}, canvas)
	local scale = new("UIScale", {}, holder)
	local rim = hexagon(holder, HEX_RADIUS, C.Rim, 54)
	local fill = hexagon(holder, HEX_RADIUS - RIM, C.Blue, 55)
	-- A darker lower half gives the tiles the glossy look of the reference.
	local shade = new("Frame", {
		Name = "Shade",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 4),
		Size = UDim2.fromOffset(SQRT3 * (HEX_RADIUS - RIM) - 2, HEX_RADIUS * 0.42),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		ZIndex = 56,
	}, holder)

	local icon = new("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -16),
		Size = UDim2.fromOffset(34, 34),
		BackgroundTransparency = 1,
		ZIndex = 57,
	}, holder)
	local title = new("TextLabel", {
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 10),
		Size = UDim2.fromOffset(SQRT3 * HEX_RADIUS - 16, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextWrapped = true,
		TextColor3 = C.Text,
		TextStrokeTransparency = 0.4,
		Text = "",
		ZIndex = 57,
	}, holder)
	local sub = new("TextLabel", {
		Name = "Sub",
		AnchorPoint = Vector2.new(0.5, 0.5),
		-- The hexagon narrows toward its lower point, so the price line is kept narrower than the title.
		Position = UDim2.new(0.5, 0, 0.5, 27),
		Size = UDim2.fromOffset(SQRT3 * HEX_RADIUS - 30, 12),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextColor3 = C.Gold,
		TextStrokeTransparency = 0.3,
		Text = "",
		ZIndex = 57,
	}, holder)
	new("UITextSizeConstraint", { MaxTextSize = 12 }, title)

	-- Round hit area inside the hexagon; hexagon corners are left to the board (and its drag).
	local hit = new("TextButton", {
		Name = "Hit",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(SQRT3 * HEX_RADIUS - 4, SQRT3 * HEX_RADIUS - 4),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 58,
	}, holder)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, hit)

	local entry = { Node = node, Holder = holder, Scale = scale, Rim = rim, Fill = fill, Shade = shade, Icon = icon, Title = title, Sub = sub, State = "HIDDEN" }
	hit.MouseEnter:Connect(function()
		if self.Dragging then return end
		self.Hovered = node.Id
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.08 }):Play()
		self:ShowTooltip(node.Id)
	end)
	hit.MouseLeave:Connect(function()
		if self.Hovered == node.Id then
			self.Hovered = nil
			if self.Selected ~= node.Id then self:HideTooltip() end
		end
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	hit.Activated:Connect(function()
		if self.Dragged then return end
		if self.LastTouch and self.Selected ~= node.Id then
			-- First tap on touch screens previews; the second tap builds.
			self.Selected = node.Id
			self:ShowTooltip(node.Id)
			return
		end
		self.Selected = nil
		if entry.State == "AVAILABLE" then
			self:Buy(node.Id)
		else
			self:ShowTooltip(node.Id)
		end
	end)
	return entry
end

function Controller:BuildTooltip(gui: ScreenGui)
	local tip = new("Frame", {
		Name = "FortressTreeTooltip",
		Size = UDim2.fromOffset(250, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(14, 12, 20),
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 80,
	}, gui)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, tip)
	self.TipStroke = new("UIStroke", { Color = C.Gold, Thickness = 1.5 }, tip)
	new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, tip)
	new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, tip)
	local function line(order: number, size: number, color: Color3, font: Enum.Font): TextLabel
		return new("TextLabel", {
			LayoutOrder = order,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Font = font,
			TextSize = size,
			TextColor3 = color,
			TextWrapped = true,
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "",
			ZIndex = 81,
		}, tip)
	end
	self.Tip = tip
	self.TipTitle = line(1, 15, C.Text, Enum.Font.GothamBlack)
	self.TipKind = line(2, 11, C.Muted, Enum.Font.GothamBold)
	self.TipBody = line(3, 13, Color3.fromRGB(220, 214, 232), Enum.Font.GothamMedium)
	self.TipFooter = line(4, 13, C.Gold, Enum.Font.GothamBold)
end

function Controller:TooltipFor(nodeId: string): (string, string, string, string, Color3)
	local entry = self.Nodes[nodeId]
	local node = entry.Node
	local branch = if node.Branch == "Root" then "Citadel" else node.Branch
	local kind = if node.Kind == "ROOT" then "FOUNDATION"
		elseif node.Kind == "PERK" then string.upper(branch) .. " · PERK"
		elseif node.Facility == "Squad" then string.format("COMMAND · SQUAD SLOT %d", (node.Level or 0) + TreeConfig.BaseSquadSlots)
		else string.format("%s · LEVEL %d", string.upper(branch), node.Level or 0)
	local footer, color
	if entry.State == "OWNED" then
		footer, color = "Built", C.Green
	elseif entry.State == "AVAILABLE" then
		local profile = self.GetProfile()
		local gold = profile and profile.Currencies and profile.Currencies.Gold or 0
		if gold >= node.Gold then
			footer, color = string.format("Cost: %s Gold · %s to build", formatGold(node.Gold), if self.LastTouch then "tap again" else "click"), C.Gold
		else
			footer, color = string.format("Cost: %s Gold (you have %s)", formatGold(node.Gold), formatGold(gold)), C.Red
		end
	else
		footer, color = "Locked: " .. (entry.Reason or "Locked"), C.Muted
	end
	return node.Name, kind, node.Description, footer, color
end

function Controller:ShowTooltip(nodeId: string)
	local entry = self.Nodes[nodeId]
	if not entry then return end
	local title, kind, body, footer, color = self:TooltipFor(nodeId)
	self.TipTitle.Text = title
	self.TipKind.Text = kind
	self.TipBody.Text = body
	self.TipFooter.Text = footer
	self.TipFooter.TextColor3 = color
	self.TipStroke.Color = if entry.State == "OWNED" then C.Green elseif entry.State == "AVAILABLE" then C.Gold else C.Muted
	self.TipNode = nodeId
	self.Tip.Visible = true
	self:PlaceTooltip()
end

function Controller:HideTooltip()
	self.Tip.Visible = false
	self.TipNode = nil
end

-- Follows the mouse; on touch it sits beside the tapped node. Kept inside the screen.
function Controller:PlaceTooltip()
	if not self.Tip.Visible then return end
	-- AbsolutePosition excludes the top-bar inset; GetMouseLocation includes it.
	local guiOrigin = self.Gui.AbsolutePosition
	local anchor: Vector2
	if self.LastTouch and self.TipNode and self.Nodes[self.TipNode] then
		local holder = self.Nodes[self.TipNode].Holder
		anchor = holder.AbsolutePosition + Vector2.new(holder.AbsoluteSize.X, 0) - guiOrigin
	else
		local mouse = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
		anchor = mouse - guiOrigin + Vector2.new(18, 12)
	end
	local screen = self.Gui.AbsoluteSize
	local size = self.Tip.AbsoluteSize
	local x = math.clamp(anchor.X, 4, math.max(4, screen.X - size.X - 4))
	local y = math.clamp(anchor.Y, 4, math.max(4, screen.Y - size.Y - 4))
	self.Tip.Position = UDim2.fromOffset(x, y)
end

-- `pan` is in screen pixels from the screen centre; the limits grow with the zoom.
function Controller:SetPan(pan: Vector2, animate: boolean?)
	local b, z = self.MapBounds, self.Zoom or 1
	self.Pan = Vector2.new(math.clamp(pan.X, -b.MaxX * z, -b.MinX * z), math.clamp(pan.Y, -b.MaxY * z, -b.MinY * z))
	local target = UDim2.new(0.5, self.Pan.X, 0.5, self.Pan.Y)
	if animate then
		TweenService:Create(self.Canvas, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = target }):Play()
	else
		self.Canvas.Position = target
	end
end

-- Zooms keeping the map point under `focus` (a screen point, AbsolutePosition space) in place.
-- Without a focus it zooms around the screen centre.
function Controller:SetZoom(zoom: number, focus: Vector2?)
	local old = self.Zoom or zoom
	local new = math.clamp(zoom, ZOOM_MIN, ZOOM_MAX)
	self.Zoom = new
	self.ZoomScale.Scale = new
	local center = self.Root.AbsolutePosition + self.Root.AbsoluteSize / 2
	local point = (focus or center) - center
	-- The map point under `point` before the zoom must stay under it afterwards.
	local mapPoint = (point - self.Pan) / old
	self:SetPan(point - mapPoint * new, false)
	if self.TipNode then self:PlaceTooltip() end
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

function Controller:BindDrag()
	local startInput: Vector2? = nil
	local startPan = Vector2.zero

	UserInputService.InputBegan:Connect(function(input: InputObject)
		if not self.Root.Visible or not isPress(input) then return end
		self.LastTouch = input.UserInputType == Enum.UserInputType.Touch
		-- InputObject.Position and AbsolutePosition share the same space (top-bar inset excluded).
		local pos = Vector2.new(input.Position.X, input.Position.Y)
		local boardPos, boardSize = self.Board.AbsolutePosition, self.Board.AbsoluteSize
		if pos.X < boardPos.X or pos.Y < boardPos.Y or pos.X > boardPos.X + boardSize.X or pos.Y > boardPos.Y + boardSize.Y then
			return
		end
		startInput = pos
		startPan = self.Pan
		self.Dragged = false
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseMovement and self.Tip.Visible and not self.LastTouch then
			self:PlaceTooltip()
		end
		local start = startInput
		if not start then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
		local delta = Vector2.new(input.Position.X, input.Position.Y) - start
		if not self.Dragged and delta.Magnitude < DRAG_THRESHOLD then return end
		if not self.Dragged then
			self.Dragged = true
			self.Dragging = true
			self.Selected = nil
			self:HideTooltip()
		end
		-- Screen pixels to panel pixels: undo the modal's UIScale.
		self:SetPan(startPan + delta, false)
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if not isPress(input) then return end
		startInput = nil
		self.Dragging = false
		-- `Dragged` stays set until the next press so the release does not count as a click.
	end)
end

function Controller:Buy(nodeId: string)
	if self.Busy then return end
	self.Busy = true
	self.Status.Text = "Building…"
	self.Status.TextColor3 = C.Muted
	task.spawn(function()
		local ok, success, message = pcall(function()
			return self.Unlock:InvokeServer(nodeId)
		end)
		self.Busy = false
		if not ok then
			self.Status.Text = "Connection failed. Please try again."
			self.Status.TextColor3 = C.Red
		else
			self.Status.Text = tostring(message or (if success then "Done." else "Unable to build that node."))
			self.Status.TextColor3 = if success then C.Green else C.Red
			local entry = self.Nodes[nodeId]
			if success and entry then
				entry.Scale.Scale = 1.25
				TweenService:Create(entry.Scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			end
		end
		self:Refresh()
	end)
end

function Controller:Refresh()
	if not self.Root.Visible then return end
	local profile = self.GetProfile()
	local tree = profile and profile.FortressTree
	local gold = profile and profile.Currencies and profile.Currencies.Gold or 0
	local floor = profile and profile.HighestClearedFloor or 0
	local unlocks = profile and profile.Unlocks

	for nodeId, entry in self.Nodes do
		local node = entry.Node
		local prereqsOwned = true
		for _, required in node.Requires do
			if not FortressTree.Owns(tree, required) then prereqsOwned = false break end
		end
		local owned = FortressTree.Owns(tree, nodeId)
		local _, reason = FortressTree.CanUnlock(tree, nodeId, math.huge, floor, unlocks)
		local state = if owned then "OWNED"
			elseif not prereqsOwned then "HIDDEN"
			elseif reason == nil then "AVAILABLE"
			else "GATED"
		entry.State = state
		entry.Reason = if state == "HIDDEN" then "Build the node before it first." else reason

		local icon = if node.Kind == "ROOT" then ICONS.Root elseif node.Kind == "PERK" then ICONS.Perk else ICONS[node.Branch] or "Spark"
		if state == "HIDDEN" then
			paint(entry.Rim, C.RimDark)
			paint(entry.Fill, C.Dark)
			setIcon(entry.Icon, nil)
			entry.Title.Text = "?"
			entry.Title.TextColor3 = Color3.fromRGB(150, 146, 158)
			entry.Title.Size = UDim2.fromOffset(SQRT3 * HEX_RADIUS - 16, 40)
			entry.Title.Position = UDim2.new(0.5, 0, 0.5, 0)
			entry.Sub.Text = ""
		else
			entry.Title.Size = UDim2.fromOffset(SQRT3 * HEX_RADIUS - 16, 22)
			entry.Title.Position = UDim2.new(0.5, 0, 0.5, 10)
			entry.Title.TextColor3 = C.Text
			setIcon(entry.Icon, icon)
			entry.Title.Text = if node.Kind == "ROOT" then "Citadel" else node.Name
			if node.Kind == "ROOT" then
				paint(entry.Rim, C.Rim)
				paint(entry.Fill, C.Root)
				entry.Sub.Text = "OPEN"
				entry.Sub.TextColor3 = C.Text
			elseif state == "OWNED" then
				paint(entry.Rim, C.Rim)
				paint(entry.Fill, C.Owned)
				entry.Sub.Text = "BUILT"
				entry.Sub.TextColor3 = C.Green
			elseif state == "AVAILABLE" then
				paint(entry.Rim, C.Rim)
				paint(entry.Fill, C.BlueDark)
				entry.Sub.Text = if node.Gold > 0 then formatShort(node.Gold) .. " Gold" else "FREE"
				entry.Sub.TextColor3 = if gold >= node.Gold then C.Gold else C.Red
			else -- GATED
				paint(entry.Rim, C.RimDark)
				paint(entry.Fill, C.Dark)
				entry.Sub.Text = if node.FloorGate > floor then string.format("Floor %d Required", node.FloorGate) else "Locked"
				entry.Sub.TextColor3 = Color3.fromRGB(255, 170, 90)
			end
		end
	end
	if self.TipNode then
		self:ShowTooltip(self.TipNode)
	end
end

function Controller:IsOpen(): boolean
	return self.Root.Visible
end

function Controller:Open()
	self.Root.Visible = true
	self.Scrim.Visible = true
	self.Status.Text = ""
	self.Selected = nil
	self:HideTooltip()
	self:SetPan(self.Pan, false)
	-- The scroll wheel zooms the map instead of the camera while the tree is open.
	ContextActionService:BindActionAtPriority(ZOOM_ACTION, function(_, state: Enum.UserInputState, input: InputObject)
		if state == Enum.UserInputState.Change and input.Position.Z ~= 0 then
			local mouse = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
			self:SetZoom(if input.Position.Z > 0 then self.Zoom * ZOOM_STEP else self.Zoom / ZOOM_STEP, mouse)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 10, Enum.UserInputType.MouseWheel)
	self:Refresh()
end

function Controller:Close()
	self.Root.Visible = false
	self.Scrim.Visible = false
	self:HideTooltip()
	ContextActionService:UnbindAction(ZOOM_ACTION)
	if _G.UpdateBottomTabHighlights then
		_G.UpdateBottomTabHighlights()
	end
end

return Controller
