--!strict
-- ReplicatedFirst/LoadingScreen/LoadingScreenView.luau
-- Minimal obsidian join loading screen with the centered stickman hero cutout logo and a
-- diagonal curtain wipe-across reveal: a pure black (-39 deg) curtain sweeps in from top-right
-- to bottom-left over the logo until covering the viewport, hides the backdrop, and continues
-- sweeping down-left to uncover the live 3D world and HUD.
-- ReplicatedFirst runs before ReplicatedStorage arrives, so styling tokens and assets live here.

local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LOGO_IMAGE_ASSET_ID = "rbxassetid://111490026450912" -- clean cutout of stickman_4k.png

local STAGE_COLOR = Color3.fromRGB(10, 10, 12) -- #0A0A0C dark stage contrasting against #000000 curtain
local CURTAIN_COLOR = Color3.fromRGB(0, 0, 0)
local SKIP_BG = Color3.fromRGB(16, 18, 26)
local SKIP_BORDER = Color3.fromRGB(90, 160, 230)
local SKIP_TEXT = Color3.fromRGB(225, 245, 255)
local INK = Color3.fromRGB(6, 6, 8)

local DIAGONAL_ANGLE_DEG = -39 -- matches reference video "\" seam (top-right -> bottom-left sweep)
local CURTAIN_OVERSCAN = 1.08 -- brief full-black beat at midpoint before uncovering the world
local CURTAIN_HEIGHT_PAD = 96
local CURTAIN_EDGE_PAD = 16

local DEFAULT_WIPE_DURATION = 0.60
local LOGO_REVEAL_DURATION = 0.22

export type View = {
	PreloadTargets: { Instance },
	RevealLogo: (self: View) -> (),
	ShowSkip: (self: View, onSkip: () -> ()) -> (),
	FadeOut: (self: View, duration: number?) -> (),
	Destroy: (self: View) -> (),
}

local View = {}

local function getViewportSize(stage: Frame): Vector2
	local size = stage.AbsoluteSize
	if size.X > 0 and size.Y > 0 then
		return size
	end
	local camera = workspace.CurrentCamera
	if camera and camera.ViewportSize.X > 0 and camera.ViewportSize.Y > 0 then
		return camera.ViewportSize
	end
	return Vector2.new(1920, 1080)
end

function View.new(playerGui: Instance): View
	local gui = Instance.new("ScreenGui")
	gui.Name = "LoadingScreen"
	gui.DisplayOrder = 10000
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.Size = UDim2.fromScale(1, 1)
	stage.Position = UDim2.fromScale(0, 0)
	stage.BackgroundTransparency = 1
	stage.BorderSizePixel = 0
	stage.ClipsDescendants = true
	stage.Parent = gui

	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = STAGE_COLOR
	backdrop.BorderSizePixel = 0
	backdrop.ZIndex = 1
	backdrop.Parent = stage

	local logoContainer = Instance.new("Frame")
	logoContainer.Name = "LogoContainer"
	logoContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	logoContainer.Position = UDim2.fromScale(0.5, 0.5)
	logoContainer.Size = UDim2.fromScale(0.32, 0.32)
	logoContainer.SizeConstraint = Enum.SizeConstraint.RelativeYY
	logoContainer.BackgroundTransparency = 1
	logoContainer.ZIndex = 2
	logoContainer.Parent = stage

	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = logoContainer

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(150, 150)
	sizeConstraint.MaxSize = Vector2.new(380, 380)
	sizeConstraint.Parent = logoContainer

	local logoScale = Instance.new("UIScale")
	logoScale.Scale = 0.90
	logoScale.Parent = logoContainer

	local logoImage = Instance.new("ImageLabel")
	logoImage.Name = "StickmanLogo"
	logoImage.AnchorPoint = Vector2.new(0.5, 0.5)
	logoImage.Position = UDim2.fromScale(0.5, 0.5)
	logoImage.Size = UDim2.fromScale(1, 1)
	logoImage.BackgroundTransparency = 1
	logoImage.Image = LOGO_IMAGE_ASSET_ID
	logoImage.ScaleType = Enum.ScaleType.Fit
	logoImage.ResampleMode = Enum.ResamplerMode.Default
	logoImage.ImageTransparency = 1
	logoImage.ZIndex = 2
	logoImage.Parent = logoContainer

	-- Pitch-black diagonal curtain that sweeps top-right -> bottom-left over the logo and off-screen
	local curtain = Instance.new("Frame")
	curtain.Name = "DiagonalCurtain"
	curtain.AnchorPoint = Vector2.new(0.5, 0.5)
	curtain.Position = UDim2.fromScale(2, -1)
	curtain.Size = UDim2.fromOffset(100, 100)
	curtain.BackgroundColor3 = CURTAIN_COLOR
	curtain.BorderSizePixel = 0
	curtain.Rotation = DIAGONAL_ANGLE_DEG
	curtain.Visible = false
	curtain.ZIndex = 10
	curtain.Parent = stage

	-- Optional Skip button inside safe area, only shown if loading exceeds SKIP_AFTER seconds
	local skipSafeArea = Instance.new("Frame")
	skipSafeArea.Name = "SkipSafeArea"
	skipSafeArea.AnchorPoint = Vector2.new(0.5, 1)
	skipSafeArea.Position = UDim2.new(0.5, 0, 1, -36)
	skipSafeArea.Size = UDim2.fromOffset(132, 42)
	skipSafeArea.BackgroundTransparency = 1
	skipSafeArea.ZIndex = 5
	skipSafeArea.Parent = stage

	local skip = Instance.new("TextButton")
	skip.Name = "Skip"
	skip.Size = UDim2.fromScale(1, 1)
	skip.BackgroundColor3 = SKIP_BG
	skip.Font = Enum.Font.GothamBold
	skip.TextSize = 16
	skip.TextColor3 = SKIP_TEXT
	skip.Text = "Skip"
	skip.AutoButtonColor = true
	skip.Selectable = true
	skip.Visible = false
	skip.ZIndex = 5
	skip.Parent = skipSafeArea

	local skipCorner = Instance.new("UICorner")
	skipCorner.CornerRadius = UDim.new(0, 10)
	skipCorner.Parent = skip

	local skipStroke = Instance.new("UIStroke")
	skipStroke.Color = SKIP_BORDER
	skipStroke.Thickness = 1.6
	skipStroke.Transparency = 0.25
	skipStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	skipStroke.Parent = skip

	local skipTextStroke = Instance.new("UIStroke")
	skipTextStroke.Color = INK
	skipTextStroke.Thickness = 1.5
	skipTextStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	skipTextStroke.Parent = skip

	gui.Parent = playerGui

	local destroyed = false
	local logoRevealed = false
	local skipConn: RBXScriptConnection? = nil

	local self = {} :: View
	self.PreloadTargets = { logoImage }

	function self.RevealLogo(_: View)
		if logoRevealed or destroyed then
			return
		end
		logoRevealed = true
		local info = TweenInfo.new(LOGO_REVEAL_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(logoImage, info, { ImageTransparency = 0 }):Play()
		TweenService:Create(logoScale, info, { Scale = 1.0 }):Play()
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

	function self.FadeOut(_: View, duration: number?)
		if destroyed then
			return
		end
		if GuiService.SelectedObject == skip then
			GuiService.SelectedObject = nil
		end
		skip.Active = false
		skip.Visible = false

		if not logoRevealed then
			logoRevealed = true
			logoImage.ImageTransparency = 0
			logoScale.Scale = 1.0
		end

		local wipeDuration = duration or DEFAULT_WIPE_DURATION
		local theta = math.rad(DIAGONAL_ANGLE_DEG)
		-- Local +X axis points up-right; local +Y axis points down-right along the "\" diagonal seam
		local axisU = Vector2.new(math.cos(theta), math.sin(theta))
		local axisV = Vector2.new(-math.sin(theta), math.cos(theta))

		local elapsed = 0
		local stageHidden = false
		local done = false

		local function step(dt: number)
			elapsed += dt
			local alpha = math.clamp(elapsed / wipeDuration, 0, 1)
			local eased = TweenService:GetValue(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

			local vp = getViewportSize(stage)
			local spanU = math.abs(axisU.X) * vp.X + math.abs(axisU.Y) * vp.Y
			local spanV = math.abs(axisV.X) * vp.X + math.abs(axisV.Y) * vp.Y

			local curtainW = spanU * CURTAIN_OVERSCAN
			local curtainH = spanV + CURTAIN_HEIGHT_PAD
			local dStart = (curtainW + spanU) * 0.5 + CURTAIN_EDGE_PAD
			local dEnd = -(curtainW + spanU) * 0.5 - CURTAIN_EDGE_PAD
			local d = dStart + (dEnd - dStart) * eased

			curtain.Size = UDim2.fromOffset(math.ceil(curtainW), math.ceil(curtainH))
			curtain.Position = UDim2.fromOffset(vp.X * 0.5 + axisU.X * d, vp.Y * 0.5 + axisU.Y * d)
			curtain.Visible = true

			-- Once the black curtain covers 100% of the screen, drop the backdrop & logo behind it
			-- so the continuing sweep uncovers the live 3D game world and HUD.
			if not stageHidden and d <= (curtainW - spanU) * 0.5 - 4 then
				stageHidden = true
				backdrop.Visible = false
				logoContainer.Visible = false
			end

			if alpha >= 1 then
				done = true
			end
		end

		step(0)
		local conn = RunService.RenderStepped:Connect(step)
		while not done and not destroyed do
			task.wait()
		end
		conn:Disconnect()
	end

	function self.Destroy(_: View)
		if destroyed then
			return
		end
		destroyed = true
		if skipConn then
			skipConn:Disconnect()
		end
		gui:Destroy()
	end

	return self
end

return View
