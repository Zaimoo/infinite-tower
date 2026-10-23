--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local GothicFont = require(script.Parent:WaitForChild("GothicFont"))

local GothicBoxStyle = {}
GothicBoxStyle.Font = GothicFont

-- Configured authoritative asset ID uploaded by user
GothicBoxStyle.CustomAssetId = "rbxassetid://110449235011652" :: string?

export type GothicStyle = "Window" | "Card" | "Button" | "Compact"

export type ApplyOptions = {
	Style: GothicStyle?,
	ZIndex: number?,
	OnClick: (() -> ())?,
	AssetId: string?,
}

local C = {
	ObsidianDark = Color3.fromRGB(15, 12, 24),
	ObsidianMid = Color3.fromRGB(22, 18, 34),
	ObsidianSheen = Color3.fromRGB(36, 28, 52),
	RailWhite = Color3.fromRGB(255, 255, 255),
	RailInnerWhite = Color3.fromRGB(246, 244, 255),
	TextWhite = Color3.fromRGB(255, 255, 255),
	TextDim = Color3.fromRGB(165, 155, 185),
	CloseRed = Color3.fromRGB(220, 38, 38),
}

GothicBoxStyle.Palette = C

local SCALE_MAP = {
	Window = 1.0,
	Card = 0.72,
	Button = 0.54,
	Compact = 0.40,
}

local SLICE_SCALE_MAP = {
	Window = 0.55,
	Card = 0.32,
	Button = 0.17,
	Compact = 0.15,
}

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

function GothicBoxStyle.SetCustomAsset(assetId: string?)
	GothicBoxStyle.CustomAssetId = assetId
end

function GothicBoxStyle.Apply(container: GuiObject, opts: ApplyOptions?): GuiObject
	local options = opts or {}
	local style = options.Style or "Window"
	local scale = SCALE_MAP[style] or 1.0
	local baseZ = options.ZIndex or container.ZIndex or 1

	container.BorderSizePixel = 0
	container.ZIndex = baseZ

	-- Clear prior styling
	for _, childName in ipairs({
		"GothicMainCorner",
		"GothicObsidianGrad",
		"GothicOuterGlow",
		"WhiteOuterRail",
		"WhiteInnerRail",
		"InnerPurpleLine",
		"InnerPurpleGlow",
		"GothicDecorRoot",
		"Gothic9SliceImage",
	}) do
		local existing = container:FindFirstChild(childName)
		if existing then
			existing:Destroy()
		end
	end

	local assetId = options.AssetId or GothicBoxStyle.CustomAssetId
	if assetId and assetId ~= "" then
		-- Direct 9-Slice Image Rendering from Uploaded User Asset
		container.BackgroundTransparency = 1

		local sliceImg = new("ImageLabel", {
			Name = "Gothic9SliceImage",
			Image = assetId,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(195, 135, 829, 552),
			SliceScale = SLICE_SCALE_MAP[style] or 0.5,
			ImageColor3 = Color3.fromRGB(245, 242, 250),
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0, 0),
			ZIndex = baseZ,
		}, container)

		if style == "Button" and container:IsA("GuiButton") then
			local btn = container :: GuiButton
			btn.AutoButtonColor = false
			btn.MouseEnter:Connect(function()
				TweenService:Create(sliceImg, TweenInfo.new(0.15), {
					ImageColor3 = Color3.fromRGB(255, 255, 255),
				}):Play()
			end)
			btn.MouseLeave:Connect(function()
				TweenService:Create(sliceImg, TweenInfo.new(0.15), {
					ImageColor3 = Color3.fromRGB(245, 242, 250),
				}):Play()
			end)
			if options.OnClick then
				btn.Activated:Connect(options.OnClick)
			end
		end

		return container
	end

	-- Procedural Vector Fallback (Clean White Gothic Frame without Purple Line)
	container.BackgroundColor3 = C.ObsidianDark
	container.BackgroundTransparency = 0.08

	-- 1. Outer Corner Radius & Subtle Gradient
	new("UICorner", {
		Name = "GothicMainCorner",
		CornerRadius = UDim.new(0, math.max(1, math.floor(3 * scale))),
	}, container)

	new("UIGradient", {
		Name = "GothicObsidianGrad",
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, C.ObsidianSheen),
			ColorSequenceKeypoint.new(0.3, C.ObsidianMid),
			ColorSequenceKeypoint.new(1.0, C.ObsidianDark),
		}),
		Rotation = 45,
	}, container)

	-- 2. Outer Stark White Rail
	new("UIStroke", {
		Name = "WhiteOuterRail",
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = C.RailWhite,
		Thickness = math.max(1.5, 2.4 * scale),
		Transparency = 0,
	}, container)

	-- 3. Inner White Rail (Parallel double-rail with dark groove)
	local innerRailOffset = math.max(2, math.floor(4 * scale))
	local innerWhiteRail = new("Frame", {
		Name = "WhiteInnerRail",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(innerRailOffset, innerRailOffset),
		Size = UDim2.new(1, -innerRailOffset * 2, 1, -innerRailOffset * 2),
		ZIndex = baseZ + 1,
	}, container)
	new("UICorner", { CornerRadius = UDim.new(0, math.max(1, math.floor(2 * scale))) }, innerWhiteRail)
	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = C.RailInnerWhite,
		Thickness = math.max(1, 1.3 * scale),
		Transparency = 0.15,
	}, innerWhiteRail)

	-- 4. Ornate Gothic Bone Flourishes Folder
	local decor = new("Folder", { Name = "GothicDecorRoot" }, container)

	-- 4A. 4-Corner Carved Bone Brackets with Hollow Teardrop/Diamond Negative Space Cutouts
	local bracketSize = math.floor(40 * scale)
	local cutoutSize = math.floor(15 * scale)
	local corners = {
		{ Name = "Claw_TL", Anchor = Vector2.new(0.5, 0.5), Pos = UDim2.fromScale(0, 0), SignX = 1, SignY = 1 },
		{ Name = "Claw_TR", Anchor = Vector2.new(0.5, 0.5), Pos = UDim2.fromScale(1, 0), SignX = -1, SignY = 1 },
		{ Name = "Claw_BL", Anchor = Vector2.new(0.5, 0.5), Pos = UDim2.fromScale(0, 1), SignX = 1, SignY = -1 },
		{ Name = "Claw_BR", Anchor = Vector2.new(0.5, 0.5), Pos = UDim2.fromScale(1, 1), SignX = -1, SignY = -1 },
	}

	for _, c in ipairs(corners) do
		local rootCorner = new("Frame", {
			Name = c.Name,
			AnchorPoint = c.Anchor,
			Position = c.Pos,
			Size = UDim2.fromOffset(bracketSize, bracketSize),
			BackgroundTransparency = 1,
			ZIndex = baseZ + 3,
		}, decor)

		-- Main Outer Bone Diamond
		local mainHead = new("Frame", {
			Name = "MainHead",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(math.floor(28 * scale), math.floor(28 * scale)),
			BackgroundColor3 = C.RailWhite,
			BorderSizePixel = 0,
			Rotation = 45,
			ZIndex = baseZ + 3,
		}, rootCorner)

		-- Inner Negative Space Cutout
		new("Frame", {
			Name = "NegativeCutout",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(cutoutSize, cutoutSize),
			BackgroundColor3 = C.ObsidianDark,
			BorderSizePixel = 0,
			Rotation = 0,
			ZIndex = baseZ + 4,
		}, mainHead)

		-- Outward Thorn Tip
		new("Frame", {
			Name = "OuterTip",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.floor(c.SignX * 16 * scale), 0.5, math.floor(c.SignY * 16 * scale)),
			Size = UDim2.fromOffset(math.floor(12 * scale), math.floor(12 * scale)),
			BackgroundColor3 = C.RailWhite,
			BorderSizePixel = 0,
			Rotation = 45,
			ZIndex = baseZ + 4,
		}, rootCorner)

		-- Horizontal Rail Hook
		new("Frame", {
			Name = "HorizontalHook",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.floor(c.SignX * 22 * scale), 0.5, math.floor(c.SignY * 2 * scale)),
			Size = UDim2.fromOffset(math.floor(18 * scale), math.floor(8 * scale)),
			BackgroundColor3 = C.RailWhite,
			BorderSizePixel = 0,
			Rotation = c.SignX * 10,
			ZIndex = baseZ + 3,
		}, rootCorner)

		-- Vertical Rail Hook
		new("Frame", {
			Name = "VerticalHook",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.floor(c.SignX * 2 * scale), 0.5, math.floor(c.SignY * 22 * scale)),
			Size = UDim2.fromOffset(math.floor(8 * scale), math.floor(18 * scale)),
			BackgroundColor3 = C.RailWhite,
			BorderSizePixel = 0,
			Rotation = c.SignY * -10,
			ZIndex = baseZ + 3,
		}, rootCorner)
	end

	-- 4B. Dual Sweeping Horn Crests on Top & Bottom Rails (at 24% and 76%)
	local hornW = math.floor(58 * scale)
	local hornH = math.floor(16 * scale)

	local railHorns = {
		{ Name = "TopHorn_L", Pos = UDim2.new(0.24, 0, 0, 0), SignX = 1, SignY = -1 },
		{ Name = "TopHorn_R", Pos = UDim2.new(0.76, 0, 0, 0), SignX = -1, SignY = -1 },
		{ Name = "BottomHorn_L", Pos = UDim2.new(0.24, 0, 1, 0), SignX = 1, SignY = 1 },
		{ Name = "BottomHorn_R", Pos = UDim2.new(0.76, 0, 1, 0), SignX = -1, SignY = 1 },
	}

	for _, h in ipairs(railHorns) do
		local horn = new("Frame", {
			Name = h.Name,
			AnchorPoint = Vector2.new(0.5, h.SignY == -1 and 1 or 0),
			Position = h.Pos,
			Size = UDim2.fromOffset(hornW, hornH),
			BackgroundTransparency = 1,
			ZIndex = baseZ + 3,
		}, decor)

		local fin = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.fromOffset(math.floor(48 * scale), math.floor(10 * scale)),
			BackgroundColor3 = C.RailWhite,
			BorderSizePixel = 0,
			Rotation = h.SignX * h.SignY * 9,
			ZIndex = baseZ + 3,
		}, horn)
		new("UICorner", { CornerRadius = UDim.new(0, 3) }, fin)

		new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(h.SignX == 1 and 0.85 or 0.15, 0, 0.5, math.floor(h.SignY * -3 * scale)),
			Size = UDim2.fromOffset(math.floor(12 * scale), math.floor(12 * scale)),
			BackgroundColor3 = C.RailWhite,
			BorderSizePixel = 0,
			Rotation = 45,
			ZIndex = baseZ + 4,
		}, horn)
	end

	-- Center Top & Bottom Subtle Crest Notches
	local topCenterNotch = new("Frame", {
		Name = "TopCenterNotch",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(math.floor(20 * scale), math.floor(8 * scale)),
		BackgroundColor3 = C.RailWhite,
		BorderSizePixel = 0,
		ZIndex = baseZ + 3,
	}, decor)
	new("UICorner", { CornerRadius = UDim.new(0, 2) }, topCenterNotch)

	local btmCenterNotch = new("Frame", {
		Name = "BottomCenterNotch",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(math.floor(20 * scale), math.floor(8 * scale)),
		BackgroundColor3 = C.RailWhite,
		BorderSizePixel = 0,
		ZIndex = baseZ + 3,
	}, decor)
	new("UICorner", { CornerRadius = UDim.new(0, 2) }, btmCenterNotch)

	-- 4C. Left & Right Rail Midpoint Barbs
	local sideBarbSize = math.floor(14 * scale)
	new("Frame", {
		Name = "LeftMidBarb",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(sideBarbSize, sideBarbSize),
		BackgroundColor3 = C.RailWhite,
		BorderSizePixel = 0,
		Rotation = 45,
		ZIndex = baseZ + 3,
	}, decor)

	new("Frame", {
		Name = "RightMidBarb",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(sideBarbSize, sideBarbSize),
		BackgroundColor3 = C.RailWhite,
		BorderSizePixel = 0,
		Rotation = 45,
		ZIndex = baseZ + 3,
	}, decor)

	-- 5. Interactive Hover Feedback for Buttons
	if style == "Button" and container:IsA("GuiButton") then
		local btn = container :: GuiButton
		btn.AutoButtonColor = false
		btn.MouseEnter:Connect(function()
			TweenService:Create(container, TweenInfo.new(0.18), { BackgroundColor3 = C.ObsidianSheen }):Play()
		end)
		btn.MouseLeave:Connect(function()
			TweenService:Create(container, TweenInfo.new(0.18), { BackgroundColor3 = C.ObsidianDark }):Play()
		end)
		if options.OnClick then
			btn.Activated:Connect(options.OnClick)
		end
	end

	return container
end

function GothicBoxStyle.CreateContainer(props: {
	Name: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Style: GothicStyle?,
	Parent: Instance?,
	ZIndex: number?,
	AssetId: string?,
}): Frame
	local frame = new("Frame", {
		Name = props.Name or "GothicContainer",
		Size = props.Size or UDim2.fromOffset(400, 300),
		Position = props.Position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		ZIndex = props.ZIndex or 10,
	}, props.Parent)
	GothicBoxStyle.Apply(frame, {
		Style = props.Style or "Window",
		ZIndex = props.ZIndex or 10,
		AssetId = props.AssetId,
	})
	return frame
end

function GothicBoxStyle.CreateButton(props: {
	Name: string?,
	Text: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Parent: Instance?,
	ZIndex: number?,
	OnClick: (() -> ())?,
	AssetId: string?,
}): TextButton
	local btn = new("TextButton", {
		Name = props.Name or "GothicButton",
		Text = props.Text or "ACTION",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = C.TextWhite,
		Size = props.Size or UDim2.fromOffset(180, 44),
		Position = props.Position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		ZIndex = props.ZIndex or 10,
	}, props.Parent)
	GothicBoxStyle.Apply(btn, {
		Style = "Button",
		ZIndex = props.ZIndex or 10,
		OnClick = props.OnClick,
		AssetId = props.AssetId,
	})
	return btn
end

function GothicBoxStyle.CreateCloseButton(parent: GuiObject, onClose: () -> ()): TextButton
	local closeBtn = new("TextButton", {
		Name = "GothicCloseButton",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = Color3.fromRGB(26, 20, 36),
		Text = "×",
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		TextColor3 = C.TextDim,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex = parent.ZIndex + 15,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, closeBtn)
	local stroke = new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(90, 75, 115),
		Thickness = 1.2,
	}, closeBtn)

	closeBtn.MouseEnter:Connect(function()
		TweenService:Create(closeBtn, TweenInfo.new(0.15), { BackgroundColor3 = C.CloseRed, TextColor3 = Color3.new(1, 1, 1) }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.15), { Color = Color3.fromRGB(255, 120, 130) }):Play()
	end)
	closeBtn.MouseLeave:Connect(function()
		TweenService:Create(closeBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(26, 20, 36), TextColor3 = C.TextDim }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.15), { Color = Color3.fromRGB(90, 75, 115) }):Play()
	end)
	closeBtn.Activated:Connect(onClose)
	return closeBtn
end

return GothicBoxStyle
