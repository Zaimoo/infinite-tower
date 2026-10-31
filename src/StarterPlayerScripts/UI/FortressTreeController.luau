--!strict
-- StarterPlayerScripts/UI/FortressTreeController.luau
-- The Fortress Development Tree panel (Phase 4 §5), opened from the Architect's Table or the
-- FORTRESS toolbar button. A full-screen, windowless map of hexagon nodes winding out from the
-- Citadel Charter in four branches: drag to pan, scroll (or +/−) to zoom toward the cursor, and
-- hover a node for its tooltip. The server validates every purchase
-- through ProgressionRemotes.UnlockTreeNode.
--
-- Nodes are bevelled hexagons joined to their prerequisite by drawn chain links, with the node name
-- above the tile and its price / gate below it.
--
-- Node states:
--   OWNED      filled with the branch colour, branch-tinted chain
--   AVAILABLE  grey tile with the branch icon, price below (green when affordable, red when short);
--              affordable nodes pulse a green rim. Click to build
--   GATED      grey tile with a lock, "Floor N" below (prerequisites owned, floor not cleared)
--   HIDDEN     dark "?" (its previous node is not built yet); deeper hidden nodes are not drawn
-- Hover: the tile springs up with a branch-coloured halo, the icon wiggles, and the chain path back to
-- the Citadel lights up link by link.
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

local HEX_RADIUS = 34 -- pointy-top circumradius in pixels
local HEX_SPACING = 80 -- grid radius; neighbours sit ~139 px apart, leaving room for the chains
local RIM = 4 -- dark ink outline around every tile
local DRAG_THRESHOLD = 6
local SQRT3 = math.sqrt(3)
local ZOOM_MIN, ZOOM_MAX = 0.45, 1.8
local ZOOM_STEP = 1.15 -- per scroll notch or +/− press
local ZOOM_ACTION = "FortressTreeZoom"

-- Chain links: open ovals alternating with edge-on bars, overlapping like a real chain.
local LINK_LEN, LINK_W, LINK_BAR_W = 17, 10, 4
local LINK_STEP = 11.5
local CHAIN_TRIM = HEX_RADIUS * 0.82 -- links start just under the tile rim

local HOVER_SCALE = 1.14
local PRESS_SCALE = 0.94
local HALO_GAP = 7 -- hover halo thickness beyond the rim
local PULSE_GAP = 4 -- affordable pulse ring thickness beyond the rim

local C = {
	Scrim = Color3.fromRGB(6, 5, 10),
	Ink = Color3.fromRGB(16, 12, 22),
	Root = Color3.fromRGB(246, 160, 36),
	Locked = Color3.fromRGB(118, 116, 128),
	Gated = Color3.fromRGB(88, 86, 98),
	Hidden = Color3.fromRGB(54, 52, 62),
	ChainSteel = Color3.fromRGB(150, 146, 162),
	ChainDark = Color3.fromRGB(74, 71, 84),
	Rim = Color3.fromRGB(255, 255, 255),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(175, 168, 192),
	Gold = Color3.fromRGB(255, 214, 64),
	Red = Color3.fromRGB(255, 84, 84),
	Green = Color3.fromRGB(110, 230, 120),
	Orange = Color3.fromRGB(255, 170, 90),
}

-- Owned tiles take their branch colour; chains and hover halos are tinted from it.
local BRANCH_COLORS: { [string]: Color3 } = {
	Root = C.Root,
	Outskirts = Color3.fromRGB(72, 196, 86),
	Commerce = Color3.fromRGB(250, 186, 44),
	Martial = Color3.fromRGB(226, 62, 62),
	Divine = Color3.fromRGB(168, 96, 240),
	Command = Color3.fromRGB(52, 150, 240),
}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local function lighten(c: Color3, t: number): Color3 return c:Lerp(WHITE, t) end
local function darken(c: Color3, t: number): Color3 return c:Lerp(BLACK, t) end

local function tween(obj: Instance, info: TweenInfo, goal: { [string]: any }): Tween
	local t = TweenService:Create(obj, info, goal)
	t:Play()
	return t
end

local EASE_SPRING = TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local EASE_OUT = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local EASE_PRESS = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

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
		GrimoireIcons.Create(name, 30, frame, frame.ZIndex)
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
local function hexagon(parent: Instance, radius: number, color: Color3, zIndex: number, yOffset: number?): { Frame }
	local bars = {}
	for i = 0, 2 do
		table.insert(bars, new("Frame", {
			Name = "Hex",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, yOffset or 0),
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

-- Draws a chain between two tile centres (canvas pixels). Returns the edge record; `Tinted` holds
-- the coloured parts (oval strokes and bar fills) so the chain can be recoloured or lit up later.
local function buildChain(parent: Instance, from: Vector2, to: Vector2): any
	local edgeFrame = new("Frame", {
		Name = "Chain",
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		ZIndex = 53,
	}, parent)
	local delta = to - from
	local dir = delta.Unit
	local angle = math.deg(math.atan2(dir.Y, dir.X))
	local start = from + dir * CHAIN_TRIM
	local span = delta.Magnitude - CHAIN_TRIM * 2
	local count = math.max(2, math.floor((span - LINK_LEN) / LINK_STEP) + 1)
	local step = (span - LINK_LEN) / (count - 1)

	local tinted: { { Inst: Instance, Prop: string } } = {}
	for i = 0, count - 1 do
		local at = start + dir * (LINK_LEN / 2 + i * step)
		if i % 2 == 0 then
			-- Face-on oval: an ink outline under a coloured ring.
			local outline = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(at.X, at.Y),
				Size = UDim2.fromOffset(LINK_LEN, LINK_W),
				Rotation = angle,
				BackgroundTransparency = 1,
				ZIndex = 1,
			}, edgeFrame)
			new("UICorner", { CornerRadius = UDim.new(1, 0) }, outline)
			new("UIStroke", { Color = C.Ink, Thickness = 5.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, outline)
			local ring = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(at.X, at.Y),
				Size = UDim2.fromOffset(LINK_LEN, LINK_W),
				Rotation = angle,
				BackgroundTransparency = 1,
				ZIndex = 2,
			}, edgeFrame)
			new("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
			local stroke = new("UIStroke", { Color = C.ChainSteel, Thickness = 2.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, ring)
			table.insert(tinted, { Inst = stroke, Prop = "Color" })
		else
			-- Edge-on link threaded through its neighbours.
			local bar = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(at.X, at.Y),
				Size = UDim2.fromOffset(LINK_LEN, LINK_BAR_W),
				Rotation = angle,
				BackgroundColor3 = C.ChainSteel,
				BorderSizePixel = 0,
				ZIndex = 3,
			}, edgeFrame)
			new("UICorner", { CornerRadius = UDim.new(1, 0) }, bar)
			new("UIStroke", { Color = C.Ink, Thickness = 1.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, bar)
			table.insert(tinted, { Inst = bar, Prop = "BackgroundColor3" })
		end
	end
	return { Frame = edgeFrame, Tinted = tinted, Color = C.ChainSteel, Lit = false }
end

local function colorChain(edge: any, color: Color3, info: TweenInfo?)
	for _, part in edge.Tinted do
		if info then
			tween(part.Inst, info, { [part.Prop] = color })
		else
			(part.Inst :: any)[part.Prop] = color
		end
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

	-- Chains sit beneath every tile.
	local chainLayer = new("Frame", {
		Name = "Chains",
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		ZIndex = 53,
	}, canvas)

	local minX, maxX, minY, maxY = 0, 0, 0, 0
	local positions: { [string]: Vector2 } = {}
	for _, node in TreeConfig.Nodes do
		local hex = LAYOUT[node.Id]
		if hex then
			local p = hexToPixel(hex[1], hex[2])
			positions[node.Id] = p
			minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
			minY, maxY = math.min(minY, p.Y), math.max(maxY, p.Y)
			self.Nodes[node.Id] = self:BuildNode(canvas, node, p)
			-- Grid distance from the Citadel staggers the open animation outward.
			self.Nodes[node.Id].Ring = (math.abs(hex[1]) + math.abs(hex[2]) + math.abs(hex[1] + hex[2])) / 2
		end
	end
	-- Each node hangs from its first prerequisite by one chain.
	self.EdgeTo = {} :: { [string]: any }
	for _, node in TreeConfig.Nodes do
		local parentId = node.Requires[1]
		local a, b = parentId and positions[parentId], positions[node.Id]
		if a and b then
			local edge = buildChain(chainLayer, a, b)
			edge.Frame.Name = "Chain_" .. node.Id
			self.EdgeTo[node.Id] = edge
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
		self.DefaultZoom = math.clamp(cam.ViewportSize.Y / 980, ZOOM_MIN, 1)
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

	-- Rings behind the rim. Each is an opaque hexagon on its own UIScale: shrunk to `hidden` it sits
	-- entirely behind the rim, scaled to 1 it shows as a band of `gap` pixels around the tile.
	local function ringLayer(name: string, gap: number, z: number): (UIScale, { Frame }, number)
		local layer = new("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = z,
		}, holder)
		local hidden = (HEX_RADIUS - 1) / (HEX_RADIUS + gap)
		local layerScale = new("UIScale", { Scale = hidden }, layer)
		return layerScale, hexagon(layer, HEX_RADIUS + gap, C.Rim, z), hidden
	end
	local haloScale, halo, haloHidden = ringLayer("Halo", HALO_GAP, 54)
	local pulseScale, pulse, pulseHidden = ringLayer("Pulse", PULSE_GAP, 55)

	-- Bevelled tile: ink rim, a darker lip, and the face nudged up so the lip shows along the bottom.
	local rim = hexagon(holder, HEX_RADIUS, C.Ink, 56)
	local lip = hexagon(holder, HEX_RADIUS - RIM, C.Gated, 57)
	local face = hexagon(holder, HEX_RADIUS - RIM - 2, C.Locked, 58, -1.5)
	local sheen = new("Frame", {
		Name = "Sheen",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -HEX_RADIUS * 0.5),
		Size = UDim2.fromOffset(SQRT3 * (HEX_RADIUS - RIM) * 0.5, 4),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.62,
		BorderSizePixel = 0,
		ZIndex = 59,
	}, holder)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, sheen)

	local icon = new("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(30, 30),
		BackgroundTransparency = 1,
		ZIndex = 60,
	}, holder)
	local mark = new("TextLabel", {
		Name = "Mark",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -1),
		Size = UDim2.fromOffset(40, 40),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 32,
		TextColor3 = Color3.fromRGB(235, 232, 242),
		Text = "?",
		Visible = false,
		ZIndex = 61,
	}, holder)
	new("UIStroke", { Color = C.Ink, Thickness = 2.4, LineJoinMode = Enum.LineJoinMode.Round }, mark)

	-- Name above the tile, price / gate below it (outlined text like the reference).
	local title = new("TextLabel", {
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -2),
		Size = UDim2.fromOffset(132, 16),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextColor3 = C.Text,
		Text = "",
		ZIndex = 70,
	}, holder)
	new("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 8 }, title)
	new("UIStroke", { Color = C.Ink, Thickness = 1.8, LineJoinMode = Enum.LineJoinMode.Round }, title)

	local priceRow = new("Frame", {
		Name = "Price",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 2),
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		ZIndex = 70,
	}, holder)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 3),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, priceRow)
	local coin = GrimoireIcons.Create("Gold", 15, priceRow, 71)
	coin.LayoutOrder = 1
	local sub = new("TextLabel", {
		Name = "Sub",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 13,
		TextColor3 = C.Gold,
		Text = "",
		ZIndex = 72,
	}, priceRow)
	new("UIStroke", { Color = C.Ink, Thickness = 1.8, LineJoinMode = Enum.LineJoinMode.Round }, sub)

	-- Round hit area inside the hexagon; hexagon corners are left to the board (and its drag).
	local hit = new("TextButton", {
		Name = "Hit",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(SQRT3 * HEX_RADIUS, SQRT3 * HEX_RADIUS),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 80,
	}, holder)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, hit)

	local entry = {
		Node = node, Holder = holder, Scale = scale, Rim = rim, Lip = lip, Face = face, Sheen = sheen,
		Icon = icon, Mark = mark, Title = title, PriceRow = priceRow, Coin = coin, Sub = sub,
		Halo = halo, HaloScale = haloScale, HaloHidden = haloHidden,
		Pulse = pulse, PulseScale = pulseScale, PulseHidden = pulseHidden, PulseTween = nil :: Tween?,
		Accent = BRANCH_COLORS[node.Branch] or C.Root, State = "HIDDEN",
	}
	hit.MouseEnter:Connect(function()
		if self.Dragging then return end
		self.Hovered = node.Id
		self:SetHover(entry, true)
		self:ShowTooltip(node.Id)
	end)
	hit.MouseLeave:Connect(function()
		if self.Hovered == node.Id then
			self.Hovered = nil
			if self.Selected ~= node.Id then self:HideTooltip() end
		end
		self:SetHover(entry, false)
	end)
	hit.MouseButton1Down:Connect(function()
		tween(scale, EASE_PRESS, { Scale = PRESS_SCALE })
	end)
	hit.MouseButton1Up:Connect(function()
		tween(scale, EASE_SPRING, { Scale = if self.Hovered == node.Id then HOVER_SCALE else 1 })
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
			-- Not buildable: a short shake says "no".
			local x = holder.Position.X.Offset
			local base = holder.Position
			holder.Position = base + UDim2.fromOffset(-5, 0)
			tween(holder, TweenInfo.new(0.35, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Position = UDim2.new(base.X.Scale, x, base.Y.Scale, base.Y.Offset) })
			self:ShowTooltip(node.Id)
		end
	end)
	return entry
end

-- Hover in: the tile springs up, a halo in the branch colour slides out from under the rim, the
-- icon wiggles, the name lifts, and the chain path back to the Citadel lights up.
function Controller:SetHover(entry: any, on: boolean)
	if on then
		paint(entry.Halo, lighten(if entry.State == "HIDDEN" then C.Locked else entry.Accent, 0.25))
		tween(entry.Scale, EASE_SPRING, { Scale = HOVER_SCALE })
		tween(entry.HaloScale, EASE_SPRING, { Scale = 1 })
		tween(entry.Title, EASE_SPRING, { Position = UDim2.new(0.5, 0, 0, -6) })
		entry.Icon.Rotation = 0
		local wiggle = tween(entry.Icon, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = -14 })
		wiggle.Completed:Once(function(state)
			if state == Enum.PlaybackState.Completed and self.Hovered == entry.Node.Id then
				tween(entry.Icon, TweenInfo.new(0.55, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Rotation = 0 })
			end
		end)
		self:LightPath(entry.Node.Id, true)
	else
		tween(entry.Scale, EASE_OUT, { Scale = 1 })
		tween(entry.HaloScale, EASE_OUT, { Scale = entry.HaloHidden })
		tween(entry.Title, EASE_OUT, { Position = UDim2.new(0.5, 0, 0, -2) })
		tween(entry.Icon, EASE_OUT, { Rotation = 0 })
		self:LightPath(entry.Node.Id, false)
	end
end

-- Lights (or restores) the chains from the Citadel out to `nodeId`, one link segment after another.
function Controller:LightPath(nodeId: string, on: boolean)
	local path = {}
	local cursor: string? = nodeId
	while cursor do
		local edge = self.EdgeTo[cursor]
		if not edge then break end
		table.insert(path, 1, edge)
		local node = TreeConfig.ById[cursor]
		cursor = node and node.Requires[1]
	end
	for i, edge in path do
		edge.Lit = on
		local color = if on then lighten(edge.Color, 0.55) else edge.Color
		local info = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, if on then (i - 1) * 0.05 else 0)
		colorChain(edge, color, info)
	end
end

-- Affordable nodes breathe a green ring; everything else tucks it away behind the rim.
function Controller:SetPulse(entry: any, on: boolean)
	if on then
		if entry.PulseTween then return end
		paint(entry.Pulse, C.Green)
		entry.PulseScale.Scale = 1
		entry.PulseTween = tween(entry.PulseScale, TweenInfo.new(0.75, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = entry.PulseHidden + (1 - entry.PulseHidden) * 0.35 })
	else
		if entry.PulseTween then
			entry.PulseTween:Cancel()
			entry.PulseTween = nil
		end
		entry.PulseScale.Scale = entry.PulseHidden
	end
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
				entry.Scale.Scale = 1.32
				tween(entry.Scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = if self.Hovered == nodeId then HOVER_SCALE else 1 })
				paint(entry.Halo, WHITE)
				entry.HaloScale.Scale = 1.08
				tween(entry.HaloScale, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = if self.Hovered == nodeId then 1 else entry.HaloHidden })
				entry.Icon.Rotation = -18
				tween(entry.Icon, TweenInfo.new(0.6, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Rotation = 0 })
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

	-- Pass 1: resolve each node's state so Pass 2 can check parent states for visibility and chain tinting.
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
	end

	-- Pass 2: style tiles, update labels & icons, and tint chains.
	for nodeId, entry in self.Nodes do
		local node = entry.Node
		local state = entry.State
		local parentId = node.Requires[1]
		local parentEntry = parentId and self.Nodes[parentId]
		local parentState = parentEntry and parentEntry.State

		-- Show owned/available/gated nodes, plus the first "?" node immediately following a visible node.
		local visible = (state ~= "HIDDEN") or (parentState ~= nil and parentState ~= "HIDDEN")
		entry.Holder.Visible = visible

		local edge = self.EdgeTo[nodeId]
		if edge then
			edge.Frame.Visible = visible
			local chainCol = if state == "OWNED" then lighten(entry.Accent, 0.08)
				elseif state == "AVAILABLE" or state == "GATED" then C.ChainSteel
				else C.ChainDark
			edge.Color = chainCol
			if not edge.Lit then
				colorChain(edge, chainCol, nil)
			end
		end

		if not visible then
			self:SetPulse(entry, false)
			continue
		end

		local icon = if node.Kind == "ROOT" then ICONS.Root elseif node.Kind == "PERK" then ICONS.Perk else ICONS[node.Branch] or "Spark"
		if state == "HIDDEN" then
			paint(entry.Rim, C.Ink)
			paint(entry.Lip, darken(C.Hidden, 0.35))
			paint(entry.Face, C.Hidden)
			entry.Sheen.Visible = false
			setIcon(entry.Icon, nil)
			entry.Mark.Visible = true
			entry.Title.Text = ""
			entry.PriceRow.Visible = false
			self:SetPulse(entry, false)
		else
			entry.Mark.Visible = false
			entry.Sheen.Visible = true
			entry.Title.Text = if node.Kind == "ROOT" then "Citadel" else node.Name
			entry.Title.TextColor3 = C.Text

			if node.Kind == "ROOT" or state == "OWNED" then
				local fillCol = if node.Kind == "ROOT" then C.Root else entry.Accent
				paint(entry.Rim, C.Ink)
				paint(entry.Lip, darken(fillCol, 0.35))
				paint(entry.Face, fillCol)
				setIcon(entry.Icon, icon)
				entry.PriceRow.Visible = false
				self:SetPulse(entry, false)
			elseif state == "AVAILABLE" then
				local canAfford = gold >= node.Gold
				paint(entry.Rim, C.Ink)
				paint(entry.Lip, darken(C.Locked, 0.32))
				paint(entry.Face, C.Locked)
				setIcon(entry.Icon, icon)
				entry.PriceRow.Visible = true
				entry.Coin.Visible = node.Gold > 0
				entry.Sub.Text = if node.Gold > 0 then formatShort(node.Gold) else "FREE"
				entry.Sub.TextColor3 = if canAfford then C.Green else C.Red
				self:SetPulse(entry, canAfford)
			else -- GATED
				paint(entry.Rim, C.Ink)
				paint(entry.Lip, darken(C.Gated, 0.35))
				paint(entry.Face, C.Gated)
				setIcon(entry.Icon, "Lock")
				entry.PriceRow.Visible = true
				entry.Coin.Visible = false
				entry.Sub.Text = if node.FloorGate > floor then string.format("Floor %d", node.FloorGate) else "Locked"
				entry.Sub.TextColor3 = C.Orange
				self:SetPulse(entry, false)
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
	-- Staggered pop-in outward from the Citadel by ring distance.
	for _, entry in self.Nodes do
		if entry.Holder.Visible then
			local ring = entry.Ring or 0
			entry.Scale.Scale = 0.01
			tween(entry.Scale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, ring * 0.035), { Scale = 1 })
		end
	end
end

function Controller:Close()
	self.Root.Visible = false
	self.Scrim.Visible = false
	self:HideTooltip()
	for _, entry in self.Nodes do
		self:SetPulse(entry, false)
		entry.Scale.Scale = 1
		entry.HaloScale.Scale = entry.HaloHidden
		entry.Icon.Rotation = 0
	end
	ContextActionService:UnbindAction(ZOOM_ACTION)
	if _G.UpdateBottomTabHighlights then
		_G.UpdateBottomTabHighlights()
	end
end

return Controller
