--!strict
-- ReplicatedFirst/LoadingScreen/LoadingScreenView.luau
-- Builds the join loading screen: a dark cosmic backdrop with ethereal floating specks,
-- the stickman hero logo with animated neon glow strictly on its outlines (starts dim,
-- flares up to radiant bright along every contour line, and rhythmically breathes),
-- a sleek cyan/white loading bar, a status line, and an optional Skip button.
-- ReplicatedFirst runs before ReplicatedStorage arrives, so all styling tokens and assets
-- are self-contained here.

local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Uploaded assets for the stickman hero logo:
local LOGO_BASE_IMAGE = "rbxassetid://89970755424339" -- transparent cutout of the stickman hero (HD)
local LOGO_OUTLINE_GLOW = "rbxassetid://72701493106519" -- isolated contour neon glow (HD)

local INK = Color3.fromRGB(6, 6, 8)
local BG_DARK = Color3.fromRGB(10, 10, 14)
local BG_MID = Color3.fromRGB(15, 17, 24)
local NEON_CYAN = Color3.fromRGB(140, 215, 255)
local NEON_CORE = Color3.fromRGB(225, 245, 255)
local TEXT_COLOR = Color3.fromRGB(195, 225, 250)

local BODY_FONT = Font.fromName("Cinzel", Enum.FontWeight.Bold)

local SPECK_COUNT = 20
local NARROW_WIDTH = 600
local INTRO_DURATION = 1.3 -- seconds to transition from dim to radiant bright

export type View = {
	PreloadTargets: { Instance },
	SetProgress: (self: View, alpha: number) -> (),
	SetStatus: (self: View, text: string) -> (),
	ShowSkip: (self: View, onSkip: () -> ()) -> (),
	FadeOut: (self: View, duration: number) -> (),
	Destroy: (self: View) -> (),
}

local View = {}

local function corner(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function textStroke(parent: Instance, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = INK
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = parent
end

local function screenGui(name: string, displayOrder: number, insets: Enum.ScreenInsets, playerGui: Instance): (ScreenGui, CanvasGroup)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.DisplayOrder = displayOrder
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ScreenInsets = insets

	local root = Instance.new("CanvasGroup")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = gui
	gui.Parent = playerGui
	return gui, root
end

-- Background: sleek dark gradient, subtle vignette, and drifting ethereal embers.
local function buildBackground(root: CanvasGroup): { Frame }
	local fill = Instance.new("Frame")
	fill.Name = "Backdrop"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.Parent = root

	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, BG_MID),
		ColorSequenceKeypoint.new(0.5, BG_DARK),
		ColorSequenceKeypoint.new(1, INK),
	})
	g.Rotation = 90
	g.Parent = fill

	-- Vignette: darkened border frame
	local vignette = Instance.new("Frame")
	vignette.Name = "Vignette"
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.BackgroundColor3 = INK
	vignette.BorderSizePixel = 0
	vignette.Parent = root

	local vg = Instance.new("UIGradient")
	vg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.28, 1),
		NumberSequenceKeypoint.new(0.72, 1),
		NumberSequenceKeypoint.new(1, 0.35),
	})
	vg.Parent = vignette

	-- Floating glowing embers/specks
	local specks: { Frame } = {}
	local rng = Random.new()
	for i = 1, SPECK_COUNT do
		local speck = Instance.new("Frame")
		speck.Name = "Speck"
		speck.AnchorPoint = Vector2.new(0.5, 0.5)
		speck.Position = UDim2.fromScale(rng:NextNumber(), rng:NextNumber())
		local px = rng:NextInteger(2, 4)
		speck.Size = UDim2.fromOffset(px, px)
		speck.BackgroundColor3 = NEON_CYAN
		speck.BackgroundTransparency = rng:NextNumber(0.45, 0.85)
		speck.BorderSizePixel = 0
		speck:SetAttribute("Speed", rng:NextNumber(0.015, 0.038))
		speck:SetAttribute("Sway", rng:NextNumber(0, math.pi * 2))
		speck.Parent = root
		corner(speck, UDim.new(0.5, 0))
		specks[i] = speck
	end

	return specks
end

function View.new(playerGui: Instance): View
	local bgGui, bgRoot = screenGui("LoadingScreen", 1000, Enum.ScreenInsets.None, playerGui)
	local contentGui, contentRoot = screenGui("LoadingScreenContent", 1001, Enum.ScreenInsets.CoreUISafeInsets, playerGui)
	local specks = buildBackground(bgRoot)

	-- Center content column
	local column = Instance.new("Frame")
	column.Name = "Column"
	column.AnchorPoint = Vector2.new(0.5, 0.5)
	column.Position = UDim2.fromScale(0.5, 0.5)
	column.Size = UDim2.fromScale(0.9, 0.9)
	column.BackgroundTransparency = 1
	column.Parent = contentRoot

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0.02, 0)
	list.Parent = column

	local columnScale = Instance.new("UIScale")
	columnScale.Parent = column

	-- Logo Container (holds the stickman hero with animated outline-only glow)
	local logoContainer = Instance.new("Frame")
	logoContainer.Name = "LogoContainer"
	logoContainer.LayoutOrder = 1
	logoContainer.Size = UDim2.fromScale(0.55, 0.55)
	logoContainer.SizeConstraint = Enum.SizeConstraint.RelativeYY
	logoContainer.BackgroundTransparency = 1
	logoContainer.Parent = column

	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = logoContainer

	local logoConstraint = Instance.new("UISizeConstraint")
	logoConstraint.MinSize = Vector2.new(240, 240)
	logoConstraint.MaxSize = Vector2.new(540, 540)
	logoConstraint.Parent = logoContainer

	local logoScale = Instance.new("UIScale")
	logoScale.Parent = logoContainer

	-- Layer 1: Ethereal outline bloom (behind character, exact 1x alignment, zero displacement blur)
	local outlineGlow = Instance.new("ImageLabel")
	outlineGlow.Name = "OutlineGlow"
	outlineGlow.AnchorPoint = Vector2.new(0.5, 0.5)
	outlineGlow.Position = UDim2.fromScale(0.5, 0.5)
	outlineGlow.Size = UDim2.fromScale(1, 1)
	outlineGlow.BackgroundTransparency = 1
	outlineGlow.Image = LOGO_OUTLINE_GLOW
	outlineGlow.ImageColor3 = Color3.fromRGB(80, 140, 200)
	outlineGlow.ImageTransparency = 0.85
	outlineGlow.ZIndex = 1
	outlineGlow.Parent = logoContainer

	-- Layer 2: Stickman Hero silhouette & sword (needle-sharp foreground, exact 1x alignment)
	local baseLogo = Instance.new("ImageLabel")
	baseLogo.Name = "BaseLogo"
	baseLogo.AnchorPoint = Vector2.new(0.5, 0.5)
	baseLogo.Position = UDim2.fromScale(0.5, 0.5)
	baseLogo.Size = UDim2.fromScale(1, 1)
	baseLogo.BackgroundTransparency = 1
	baseLogo.Image = LOGO_BASE_IMAGE
	baseLogo.ImageColor3 = Color3.fromRGB(200, 215, 230)
	baseLogo.ZIndex = 2
	baseLogo.Parent = logoContainer

	-- Spacer between logo and progress bar
	local spacer = Instance.new("Frame")
	spacer.Name = "Spacer"
	spacer.LayoutOrder = 2
	spacer.Size = UDim2.fromScale(1, 0.015)
	spacer.BackgroundTransparency = 1
	spacer.Parent = column

	-- Progress Bar Track
	local track = Instance.new("Frame")
	track.Name = "BarTrack"
	track.LayoutOrder = 3
	track.Size = UDim2.new(0.44, 0, 0, 12)
	track.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	track.Parent = column
	corner(track, UDim.new(0.5, 0))
	stroke(track, Color3.fromRGB(70, 130, 190), 1.5, 0.35)

	local trackSize = Instance.new("UISizeConstraint")
	trackSize.MinSize = Vector2.new(220, 12)
	trackSize.MaxSize = Vector2.new(520, 12)
	trackSize.Parent = track

	-- Progress Bar Fill
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.Parent = track
	corner(fill, UDim.new(0.5, 0))

	local fillGrad = Instance.new("UIGradient")
	fillGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(65, 150, 235)),
		ColorSequenceKeypoint.new(0.8, Color3.fromRGB(160, 225, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
	})
	fillGrad.Parent = fill

	-- Status Label
	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.LayoutOrder = 4
	status.Size = UDim2.new(0.65, 0, 0, 22)
	status.BackgroundTransparency = 1
	status.FontFace = BODY_FONT
	status.TextSize = 16
	status.TextColor3 = TEXT_COLOR
	status.Text = "Opening the gates…"
	status.Parent = column
	textStroke(status, 1.5)

	-- Skip Button
	local skip = Instance.new("TextButton")
	skip.Name = "Skip"
	skip.LayoutOrder = 5
	skip.Size = UDim2.fromOffset(132, 42)
	skip.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
	skip.FontFace = BODY_FONT
	skip.TextSize = 17
	skip.TextColor3 = NEON_CORE
	skip.Text = "Skip"
	skip.AutoButtonColor = true
	skip.Selectable = true
	skip.Visible = false
	skip.Parent = column
	corner(skip, UDim.new(0, 10))
	stroke(skip, Color3.fromRGB(90, 160, 230), 1.8, 0.2)
	textStroke(skip, 1.5)

	-- Responsive fit for narrow / mobile screens
	local function refit()
		columnScale.Scale = if contentGui.AbsoluteSize.X > 0 and contentGui.AbsoluteSize.X < NARROW_WIDTH then 0.85 else 1
	end
	local sizeConn = contentGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	refit()

	local clock = 0
	local currentProgress = 0
	local fading = false

	-- Applies outline glow level `g` from 0 (dim) to 1 (bright + extra bright peak)
	-- All glow effects strictly follow the outline contour of the stickman hero
	local function applyGlow(g: number)
		g = math.clamp(g, 0, 1)

		-- Outline bloom behind the character
		outlineGlow.ImageTransparency = 0.85 - 0.80 * g
		outlineGlow.ImageColor3 = Color3.fromRGB(
			math.floor(80 + 175 * g),
			math.floor(140 + 115 * g),
			math.floor(200 + 55 * g)
		)

		-- Base character lineart brightness (starts clear, reaches blazing white at peak)
		baseLogo.ImageColor3 = Color3.fromRGB(
			math.floor(190 + 65 * g),
			math.floor(205 + 50 * g),
			math.floor(220 + 35 * g)
		)

		if not fading then
			logoScale.Scale = 1.0 + 0.02 * g
		end
	end

	-- Animation loop: drives ember drift and outline-only breathing glow
	local renderConn = RunService.RenderStepped:Connect(function(dt: number)
		clock += dt

		-- Glow animation on the outlines: starts dim, flares to bright peak, then rhythmically breathes
		local glowLevel: number
		if clock < INTRO_DURATION then
			local t = clock / INTRO_DURATION
			glowLevel = t * t * (3 - 2 * t) -- smooth ease-in from 0 (dim) to 1 (bright)
		else
			local breathCycle = clock - INTRO_DURATION
			local breath = 0.5 + 0.5 * math.cos(breathCycle * 2.2)
			local floorGlow = 0.25 + 0.35 * currentProgress
			glowLevel = floorGlow + (1 - floorGlow) * breath
		end
		applyGlow(glowLevel)

		-- Ember particles floating upward
		for _, speck in specks do
			local pos = speck.Position
			local speed = (speck:GetAttribute("Speed") :: number?) or 0.02
			local sway = (speck:GetAttribute("Sway") :: number?) or 0
			local y = pos.Y.Scale - speed * dt
			local x = pos.X.Scale + math.sin(clock * 0.9 + sway) * 0.005 * dt
			if y < -0.02 then
				y = 1.02
			end
			speck.Position = UDim2.fromScale(x, y)
		end
	end)

	local skipConn: RBXScriptConnection? = nil
	local destroyed = false

	local self = {} :: View
	self.PreloadTargets = { baseLogo, outlineGlow, status }

	function self.SetProgress(_: View, alpha: number)
		currentProgress = math.clamp(alpha, 0, 1)
		fill.Size = UDim2.fromScale(currentProgress, 1)
	end

	function self.SetStatus(_: View, text: string)
		if status.Text ~= text then
			status.Text = text
		end
	end

	function self.ShowSkip(_: View, onSkip: () -> ())
		if skip.Visible or destroyed then
			return
		end
		skip.Visible = true
		skip.TextTransparency = 1
		skip.BackgroundTransparency = 1
		TweenService:Create(skip, TweenInfo.new(0.35), { TextTransparency = 0, BackgroundTransparency = 0 }):Play()
		skipConn = skip.Activated:Connect(onSkip)
		GuiService.SelectedObject = skip
	end

	function self.FadeOut(_: View, duration: number)
		if GuiService.SelectedObject == skip then
			GuiService.SelectedObject = nil
		end
		skip.Active = false
		fading = true
		local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(logoScale, info, { Scale = 1.08 }):Play()
		TweenService:Create(contentRoot, info, { GroupTransparency = 1 }):Play()
		local bgTween = TweenService:Create(bgRoot, info, { GroupTransparency = 1 })
		bgTween:Play()
		bgTween.Completed:Wait()
	end

	function self.Destroy(_: View)
		if destroyed then
			return
		end
		destroyed = true
		renderConn:Disconnect()
		sizeConn:Disconnect()
		if skipConn then
			skipConn:Disconnect()
		end
		bgGui:Destroy()
		contentGui:Destroy()
	end

	return self
end

return View