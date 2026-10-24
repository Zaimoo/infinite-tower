--!strict
-- ReplicatedStorage/Shared/Util/OrnateFrameButton.luau
-- Reusable gothic ornate frame button component for Infinite Tower.
-- Matches the classical dark navy rectangular panel with thin silver double border,
-- ornate filigree corners, soft lavender outer glow, serif gold typography, and faceted gem cost.

local TweenService = game:GetService("TweenService")

local GothicFont = require(script.Parent:WaitForChild("GothicFont"))
local GothicBoxStyle = require(script.Parent:WaitForChild("GothicBoxStyle"))
local GothicVectorIcons = require(script.Parent:WaitForChild("GothicVectorIcons"))

local OrnateFrameButton = {}
OrnateFrameButton.__index = OrnateFrameButton

--============================================================================
-- ASSET AND SLICE CONFIGURATION TABLE
-- Swap art, asset IDs, slice centers, and glow padding here in one place.
--============================================================================
export type ButtonConfig = {
	-- Asset Inputs (Replace placeholders when custom assets are uploaded):
	FRAME_IMAGE: string,
	FRAME_IMAGE_SIZE: Vector2,
	GLOW_PADDING_PX: number,
	GEM_IMAGE: string,

	-- 9-Slice Parameters:
	SLICE_CENTER: Rect,
	SLICE_SCALE: number,

	-- Temporary Fallback Asset:
	FALLBACK_FRAME_IMAGE: string,

	-- Typography & Palette:
	FONT: Enum.Font,
	USE_CUSTOM_FONT_FACE: boolean,
	COLOR_TITLE: Color3,
	COLOR_TITLE_HOVER: Color3,
	COLOR_COST: Color3,
	COLOR_COST_HOVER: Color3,
	COLOR_DISABLED: Color3,
	FRAME_COLOR_NORMAL: Color3,
	FRAME_COLOR_HOVER: Color3,
	FRAME_COLOR_DISABLED: Color3,
	BG_COLOR: Color3,
}

local CONFIG: ButtonConfig = {
	-- ASSET INPUTS:
	-- Set to your uploaded Roblox asset ID (e.g. "rbxassetid://123456789").
	-- When set to "rbxassetid://REPLACE_ME", automatically uses FALLBACK_FRAME_IMAGE.
	FRAME_IMAGE = "rbxassetid://106460392252247",

	-- Source Image Resolution:
	-- PRESET 1 (Tightly Cropped, GothicFrame_Cropped.png - rbxassetid://106460392252247): Vector2.new(690, 303)
	-- PRESET 2 (Master Canvas, GothicFrame.png - rbxassetid://122557249536640):           Vector2.new(1024, 572)
	FRAME_IMAGE_SIZE = Vector2.new(690, 303),

	-- Transparent padding around the visible frame border for the ambient glow (in image pixels)
	GLOW_PADDING_PX = 16,

	-- Faceted blue gem icon (authoritative existing project gem asset)
	GEM_IMAGE = "rbxassetid://78431923289071",

	-- 9-Slice Bounds: Chosen from FRAME_IMAGE_SIZE so corner spires and filigree
	-- remain 100% undistorted while the center borders stretch cleanly.
	-- For 690x303 (GothicFrame_Cropped): Rect.new(174, 105, 518, 195)
	-- For 1024x572 (GothicFrame Master): Rect.new(350, 250, 674, 320)
	SLICE_CENTER = Rect.new(174, 105, 518, 195),

	-- Slice scale suited for button heights (~76px) to prevent corner squishing:
	SLICE_SCALE = 0.25,

	-- Authoritative temporary fallback frame ID (from GothicBoxStyle.luau)
	FALLBACK_FRAME_IMAGE = "rbxassetid://110449235011652",

	-- Typography: Built-in serif closest to inscriptional Roman gothic fantasy.
	-- Enum.Font.Garamond matches classical dark fantasy serif proportions.
	FONT = Enum.Font.Garamond,
	USE_CUSTOM_FONT_FACE = false, -- Default to built-in serif Enum.Font.Garamond (set true to bind to GothicFont.GetFont())

	-- Bronze / gold palette (RGB ~190, 150, 95)
	COLOR_TITLE = Color3.fromRGB(190, 150, 95),
	COLOR_TITLE_HOVER = Color3.fromRGB(230, 185, 125),
	COLOR_COST = Color3.fromRGB(190, 150, 95),
	COLOR_COST_HOVER = Color3.fromRGB(230, 185, 125),
	COLOR_DISABLED = Color3.fromRGB(120, 100, 70),

	-- Frame tint states
	FRAME_COLOR_NORMAL = Color3.fromRGB(240, 238, 245),
	FRAME_COLOR_HOVER = Color3.fromRGB(255, 255, 255),
	FRAME_COLOR_DISABLED = Color3.fromRGB(130, 125, 140),

	-- Dark navy / near-black panel interior background
	BG_COLOR = Color3.fromRGB(16, 13, 26),
}

OrnateFrameButton.Config = CONFIG

-- Allows overriding global configuration table properties programmatically
function OrnateFrameButton.SetConfig(overrides: { [string]: any })
	for k, v in pairs(overrides) do
		(CONFIG :: any)[k] = v
	end
end

--============================================================================
-- PUBLIC TYPES
--============================================================================
export type ButtonProps = {
	Name: string?,
	Title: string?,
	Cost: (number | string)?,
	Icon: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	ZIndex: number?,
	LayoutOrder: number?,
	Visible: boolean?,
	Enabled: boolean?,
	Selectable: boolean?,
	Variant: ("PrimaryGold" | "PrimaryViolet" | "Secondary")?,
	OnClick: (() -> ())?,
	OnActivated: (() -> ())?,
	Config: { [string]: any }?,
}

export type ButtonInstance = {
	Root: TextButton,
	Activated: RBXScriptSignal,
	SetTitle: (self: any, title: string) -> (),
	SetCost: (self: any, cost: (number | string)?) -> (),
	SetEnabled: (self: any, enabled: boolean) -> (),
	IsEnabled: (self: any) -> boolean,
	Destroy: (self: any) -> (),
}

--============================================================================
-- INTERNAL HELPERS
--============================================================================
local function new<T>(className: string, props: { [string]: any }, parent: Instance?): T
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst :: any
end

local function tween(instance: Instance, info: TweenInfo, goals: { [string]: any }): Tween
	local t = TweenService:Create(instance, info, goals)
	t:Play()
	return t
end

local function resolveFrameImage(cfg: ButtonConfig, customCfg: { [string]: any }?): (string, boolean)
	local img = if customCfg and customCfg.FRAME_IMAGE ~= nil then customCfg.FRAME_IMAGE else cfg.FRAME_IMAGE
	if not img or img == "" or string.find(img, "REPLACE_ME") then
		return cfg.FALLBACK_FRAME_IMAGE, true
	end
	return img, false
end

local function resolveGemImage(cfg: ButtonConfig, customCfg: { [string]: any }?, propIcon: string?): string
	if propIcon and propIcon ~= "" and not string.find(propIcon, "REPLACE_ME") then
		return propIcon
	end
	local img = if customCfg and customCfg.GEM_IMAGE ~= nil then customCfg.GEM_IMAGE else cfg.GEM_IMAGE
	if not img or img == "" or string.find(img, "REPLACE_ME") then
		return "rbxassetid://74751786636473"
	end
	return img
end

--============================================================================
-- CONSTRUCTOR
--============================================================================
function OrnateFrameButton.new(parent: Instance?, props: ButtonProps): ButtonInstance
	local customCfg = props.Config or {}
	local baseZ = props.ZIndex or 54

	local frameAsset, isUsingFallback = resolveFrameImage(CONFIG, customCfg)
	local gemAsset = resolveGemImage(CONFIG, customCfg, props.Icon)

	-- Slice bounds: If using the fallback image from GothicBoxStyle, use its proven 1024 slice
	local activeSliceCenter = if isUsingFallback
		then Rect.new(195, 135, 829, 552)
		else (customCfg.SLICE_CENTER or CONFIG.SLICE_CENTER)

	local activeSliceScale = if isUsingFallback
		then 0.17
		else (customCfg.SLICE_SCALE or CONFIG.SLICE_SCALE)

	local glowPad = if customCfg.GLOW_PADDING_PX ~= nil then customCfg.GLOW_PADDING_PX else CONFIG.GLOW_PADDING_PX
	local glowOffset = math.max(0, math.round(glowPad * activeSliceScale))

	local activeFont = customCfg.FONT or CONFIG.FONT
	local useCustomFontFace = if customCfg.USE_CUSTOM_FONT_FACE ~= nil
		then customCfg.USE_CUSTOM_FONT_FACE
		else CONFIG.USE_CUSTOM_FONT_FACE

	-- 1. Root Transparent TextButton (Clickable & Touch Hit Area)
	local rootBtn = new("TextButton", {
		Name = props.Name or "OrnateFrameButton",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Selectable = if props.Selectable ~= nil then props.Selectable else true,
		Active = true,
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
		Position = props.Position or UDim2.fromScale(0, 0),
		Size = props.Size or UDim2.fromOffset(200, 60),
		ZIndex = baseZ,
		LayoutOrder = props.LayoutOrder or 0,
		Visible = if props.Visible ~= nil then props.Visible else true,
		ClipsDescendants = false,
	}, parent)

	-- 2. Visual Root Container (Houses visual components and central UIScale for bounce)
	local visualRoot = new("Frame", {
		Name = "VisualRoot",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ClipsDescendants = false,
		ZIndex = baseZ,
	}, rootBtn)

	local visualScale = new("UIScale", {
		Name = "VisualScale",
		Scale = 1.0,
	}, visualRoot)

	-- 3. Modern Gothic Button Panel (Clean filled gradient or outlined per mockup)
	local variant: "PrimaryGold" | "PrimaryViolet" | "Secondary"
	if props.Variant then
		variant = props.Variant
	elseif props.Title and string.find(props.Title, "10X") then
		variant = "PrimaryGold"
	elseif props.Title and string.find(props.Title, "1X") then
		variant = "PrimaryViolet"
	else
		variant = "PrimaryGold"
	end

	local darkPanel = new("Frame", {
		Name = "DarkPanel",
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ClipsDescendants = false,
		ZIndex = baseZ,
	}, visualRoot)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, darkPanel)

	local panelGrad = new("UIGradient", {
		Name = "PanelGradient",
		Rotation = 90,
	}, darkPanel)

	local panelStroke = new("UIStroke", {
		Name = "PanelStroke",
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = 1.5,
	}, darkPanel)

	-- 4. Vector Container / Legacy ImageLabel Fallback (Set to transparent vector frame)
	local frameImage = new("ImageLabel", {
		Name = "FrameImage",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = "",
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = activeSliceCenter,
		SliceScale = activeSliceScale,
		ImageColor3 = customCfg.FRAME_COLOR_NORMAL or CONFIG.FRAME_COLOR_NORMAL,
		Position = UDim2.fromOffset(-glowOffset, -glowOffset),
		Size = UDim2.new(1, glowOffset * 2, 1, glowOffset * 2),
		ClipsDescendants = false,
		ZIndex = baseZ + 1,
	}, visualRoot)

	-- 5. Title TextLabel (Centered on top, Roman serif Garamond, bronze/gold all-caps)
	local hasCost = (props.Cost ~= nil and props.Cost ~= "")
	local titleLabel = new("TextLabel", {
		Name = "TitleLabel",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = activeFont,
		Text = props.Title or "",
		TextColor3 = customCfg.COLOR_TITLE or CONFIG.COLOR_TITLE,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		AnchorPoint = if hasCost then Vector2.new(0.5, 0) else Vector2.new(0.5, 0.5),
		Position = if hasCost then UDim2.new(0.5, 0, 0, 14) else UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -20, 0, 20),
		ZIndex = baseZ + 2,
	}, visualRoot)

	if useCustomFontFace then
		pcall(function()
			local fontObj = GothicFont.GetFont("Bold")
			if fontObj then
				titleLabel.FontFace = fontObj
			end
		end)
	end

	-- 6. Cost Row Container (Centered horizontal row with UIListLayout)
	local costRow = new("Frame", {
		Name = "CostRow",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 40),
		Size = UDim2.new(1, -20, 0, 22),
		ClipsDescendants = false,
		Visible = hasCost,
		ZIndex = baseZ + 2,
	}, visualRoot)

	new("UIListLayout", {
		Name = "ListLayout",
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 5),
	}, costRow)

	-- Procedural Vector Diamond Gem
	local gemIcon = new("ImageLabel", {
		Name = "GemIcon",
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = "",
		Size = UDim2.fromOffset(18, 18),
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = baseZ + 3,
	}, costRow)

	GothicVectorIcons.CreateGems({
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = baseZ + 3,
		Parent = gemIcon,
	})

	local costLabel = new("TextLabel", {
		Name = "CostLabel",
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = activeFont,
		Text = tostring(props.Cost or ""),
		TextColor3 = customCfg.COLOR_COST or CONFIG.COLOR_COST,
		TextStrokeTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = baseZ + 3,
	}, costRow)

	if useCustomFontFace then
		pcall(function()
			local fontObj = GothicFont.GetFont("Bold")
			if fontObj then
				costLabel.FontFace = fontObj
			end
		end)
	end

	-- 7. Responsive Text Sizing (Scales cleanly relative to button height)
	local connections: { RBXScriptConnection } = {}

	local function updateLayout()
		local h = rootBtn.AbsoluteSize.Y
		if h <= 0 then
			if rootBtn.Size.Y.Offset > 0 then
				h = rootBtn.Size.Y.Offset
			else
				h = 76
			end
		end

		local titleSize = math.clamp(math.round(h * 0.21), 11, 24)
		local costSize = math.clamp(math.round(h * 0.19), 10, 22)
		titleLabel.TextSize = titleSize
		costLabel.TextSize = costSize

		local gemSize = math.clamp(math.round(costSize * 1.15), 14, 24)
		gemIcon.Size = UDim2.fromOffset(gemSize, gemSize)
	end

	table.insert(connections, rootBtn:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLayout))
	updateLayout()

	-- 8. Interactive State Management (Hover, Press, Disabled/Busy)
	local isHovered = false
	local isPressed = false
	local isEnabled = if props.Enabled ~= nil then props.Enabled else true

	local function refreshVisualState(animate: boolean)
		local duration = if animate then 0.15 else 0
		local tInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		if not isEnabled then
			panelGrad.Color = ColorSequence.new(Color3.fromRGB(39, 32, 48), Color3.fromRGB(27, 21, 35))
			panelStroke.Color = Color3.fromRGB(69, 58, 86)
			tween(darkPanel, tInfo, {
				BackgroundColor3 = Color3.fromRGB(39, 32, 48),
				BackgroundTransparency = 0,
			})
			tween(titleLabel, tInfo, {
				TextColor3 = Color3.fromRGB(154, 142, 181),
				TextTransparency = 0.40,
			})
			tween(costLabel, tInfo, {
				TextColor3 = Color3.fromRGB(154, 142, 181),
				TextTransparency = 0.40,
			})
			tween(gemIcon, tInfo, {
				ImageTransparency = 0.40,
			})
			tween(visualScale, tInfo, {
				Scale = 1.0,
			})
			return
		end

		local targetBgColor: Color3
		local targetGrad: ColorSequence
		local targetStrokeColor: Color3
		local targetTitleColor: Color3
		local targetCostColor: Color3

		if variant == "PrimaryGold" then
			if isHovered then
				targetBgColor = Color3.fromHex("#FDE047")
				targetGrad = ColorSequence.new(Color3.fromHex("#FDE047"), Color3.fromHex("#F59E0B"))
				targetStrokeColor = Color3.fromRGB(255, 255, 255)
				targetTitleColor = Color3.fromHex("#160F04")
				targetCostColor = Color3.fromHex("#160F04")
			else
				targetBgColor = Color3.fromHex("#FACC15")
				targetGrad = ColorSequence.new(Color3.fromHex("#FACC15"), Color3.fromHex("#D97706"))
				targetStrokeColor = Color3.fromHex("#FEF08A")
				targetTitleColor = Color3.fromHex("#160F04")
				targetCostColor = Color3.fromHex("#160F04")
			end
		elseif variant == "PrimaryViolet" then
			if isHovered then
				targetBgColor = Color3.fromHex("#392457")
				targetGrad = ColorSequence.new(Color3.fromHex("#392457"), Color3.fromHex("#24163A"))
				targetStrokeColor = Color3.fromHex("#FACC15")
				targetTitleColor = Color3.fromRGB(255, 255, 255)
				targetCostColor = Color3.fromRGB(255, 255, 255)
			else
				targetBgColor = Color3.fromHex("#2B1B42")
				targetGrad = ColorSequence.new(Color3.fromHex("#2B1B42"), Color3.fromHex("#190F29"))
				targetStrokeColor = Color3.fromHex("#E4BA73")
				targetTitleColor = Color3.fromHex("#FDE047")
				targetCostColor = Color3.fromHex("#F6F4FF")
			end
		else -- "Secondary"
			if isHovered then
				targetBgColor = Color3.fromHex("#231934")
				targetGrad = ColorSequence.new(Color3.fromHex("#231934"), Color3.fromHex("#231934"))
				targetStrokeColor = Color3.fromHex("#C084FC")
				targetTitleColor = Color3.fromRGB(255, 255, 255)
				targetCostColor = Color3.fromRGB(255, 255, 255)
			else
				targetBgColor = Color3.fromHex("#161020")
				targetGrad = ColorSequence.new(Color3.fromHex("#161020"), Color3.fromHex("#161020"))
				targetStrokeColor = Color3.fromHex("#564770")
				targetTitleColor = Color3.fromHex("#E2D9F3")
				targetCostColor = Color3.fromHex("#E2D9F3")
			end
		end

		panelGrad.Color = targetGrad

		local targetScale = if isPressed then 0.97 else 1.0
		local scaleTInfo = if isPressed
			then TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			else TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		tween(darkPanel, tInfo, {
			BackgroundColor3 = targetBgColor,
			BackgroundTransparency = 0,
		})
		tween(panelStroke, tInfo, {
			Color = targetStrokeColor,
		})
		tween(titleLabel, tInfo, {
			TextColor3 = targetTitleColor,
			TextTransparency = 0,
		})
		tween(costLabel, tInfo, {
			TextColor3 = targetCostColor,
			TextTransparency = 0,
		})
		tween(gemIcon, tInfo, {
			ImageTransparency = 0,
		})
		tween(visualScale, scaleTInfo, {
			Scale = targetScale,
		})
	end

	-- Connect Hover Events (Mouse and Gamepad navigation)
	table.insert(connections, rootBtn.MouseEnter:Connect(function()
		isHovered = true
		refreshVisualState(true)
	end))

	table.insert(connections, rootBtn.MouseLeave:Connect(function()
		isHovered = false
		isPressed = false
		refreshVisualState(true)
	end))

	table.insert(connections, rootBtn.SelectionGained:Connect(function()
		isHovered = true
		refreshVisualState(true)
	end))

	table.insert(connections, rootBtn.SelectionLost:Connect(function()
		isHovered = false
		isPressed = false
		refreshVisualState(true)
	end))

	-- Connect Press Events (Mouse, Touch, and Gamepad ButtonA)
	table.insert(connections, rootBtn.InputBegan:Connect(function(input: InputObject)
		if not isEnabled then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA then
			isPressed = true
			refreshVisualState(true)
		end
	end))

	table.insert(connections, rootBtn.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA then
			isPressed = false
			refreshVisualState(true)
		end
	end))

	-- Connect Activated Click Callback
	table.insert(connections, rootBtn.Activated:Connect(function()
		if not isEnabled then return end
		if props.OnClick then
			props.OnClick()
		end
		if props.OnActivated then
			props.OnActivated()
		end
	end))

	-- 9. Construct Component Instance
	local instance: ButtonInstance
	instance = {
		Root = rootBtn,
		Activated = rootBtn.Activated,

		SetTitle = function(selfOrTitle: any, maybeTitle: any)
			local title = if maybeTitle ~= nil then maybeTitle else selfOrTitle
			if typeof(title) == "string" then
				titleLabel.Text = title
			end
		end,

		SetCost = function(selfOrCost: any, maybeCost: any)
			local cost = if maybeCost ~= nil then maybeCost else selfOrCost
			if cost == nil or cost == "" then
				costRow.Visible = false
				titleLabel.Position = UDim2.fromScale(0.5, 0.5)
				titleLabel.AnchorPoint = Vector2.new(0.5, 0.5)
			else
				costRow.Visible = true
				costLabel.Text = tostring(cost)
				titleLabel.Position = UDim2.new(0.5, 0, 0, 14)
				titleLabel.AnchorPoint = Vector2.new(0.5, 0)
			end
		end,

		SetEnabled = function(selfOrEnabled: any, maybeEnabled: any)
			local enabled = if maybeEnabled ~= nil then maybeEnabled else selfOrEnabled
			if typeof(enabled) == "boolean" then
				isEnabled = enabled
				refreshVisualState(true)
			end
		end,

		IsEnabled = function(_self: any)
			return isEnabled
		end,

		Destroy = function(_self: any)
			for _, conn in ipairs(connections) do
				conn:Disconnect()
			end
			table.clear(connections)
			rootBtn:Destroy()
		end,
	}

	return instance
end

return OrnateFrameButton
