--!strict
-- ReplicatedStorage/Shared/Util/GothicBoxStyle.luau
-- Saved Reusable UI Text Box & Container Design ("Gothic Obsidian & White Filigree Frame")
-- Used for Currency Box Containers (Gold / Diamonds), Synthesis Confirmation Dialogs ("WILL YOU SYNTHESIZE?"),
-- and ornate system notifications.

local GothicBoxStyle = {}

GothicBoxStyle.Palette = {
	ObsidianDark = Color3.fromRGB(13, 9, 18),
	ObsidianMid = Color3.fromRGB(20, 14, 28),
	ObsidianSheen = Color3.fromRGB(38, 28, 50),
	FiligreeWhite = Color3.fromRGB(246, 244, 255),
	OuterGlow = Color3.fromRGB(222, 205, 255),
	CornerCutout = Color3.fromRGB(26, 15, 38),
	InnerLineBright = Color3.fromRGB(112, 100, 132),
	InnerLineMuted = Color3.fromRGB(68, 58, 84),
	YesButtonRed = Color3.fromRGB(238, 48, 56),
	NoButtonDark = Color3.fromRGB(18, 13, 24),
	GoldText = Color3.fromRGB(230, 192, 112),
	DiamondText = Color3.fromRGB(78, 232, 224),
}

export type GothicBoxOptions = {
	Compact: boolean?,
	ZIndex: number?,
}

-- Applies the saved Gothic UI Text Box Design to any Frame container
function GothicBoxStyle.Apply(container: Frame, opts: GothicBoxOptions?): Frame
	local compact = if opts and opts.Compact ~= nil then opts.Compact else false
	local baseZ = (opts and opts.ZIndex) or container.ZIndex or 8
	local P = GothicBoxStyle.Palette

	container.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	container.BackgroundTransparency = 0
	container.BorderSizePixel = 0
	container.ZIndex = baseZ

	-- Clear existing UICorner/UIStroke/UIGradient or previous decor
	for _, child in ipairs(container:GetChildren()) do
		if
			child:IsA("UICorner")
			or child:IsA("UIStroke")
			or child:IsA("UIGradient")
			or child.Name == "GothicDecorRoot"
		then
			child:Destroy()
		end
	end

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, compact and 3 or 4)
	corner.Parent = container

	-- Diagonal glossy obsidian-violet gradient sheen
	local grad = Instance.new("UIGradient")
	grad.Rotation = 128
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.00, P.ObsidianDark),
		ColorSequenceKeypoint.new(0.28, P.ObsidianMid),
		ColorSequenceKeypoint.new(0.46, P.ObsidianSheen),
		ColorSequenceKeypoint.new(0.62, P.ObsidianMid),
		ColorSequenceKeypoint.new(1.00, P.ObsidianDark),
	})
	grad.Parent = container

	-- Crisp white/silver outer border
	local outerStroke = Instance.new("UIStroke")
	outerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outerStroke.Thickness = compact and 1.5 or 2
	outerStroke.Color = P.FiligreeWhite
	outerStroke.Transparency = 0.04
	outerStroke.Parent = container

	local decorRoot = Instance.new("Folder")
	decorRoot.Name = "GothicDecorRoot"
	decorRoot.Parent = container

	-- Soft lavender-white outer glow frame
	local glowFrame = Instance.new("Frame")
	glowFrame.Name = "OuterGlow"
	glowFrame.Size = UDim2.new(1, compact and 6 or 10, 1, compact and 6 or 10)
	glowFrame.Position = UDim2.fromScale(0.5, 0.5)
	glowFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	glowFrame.BackgroundTransparency = 1
	glowFrame.ZIndex = baseZ
	glowFrame.Parent = decorRoot

	local glowCorner = Instance.new("UICorner")
	glowCorner.CornerRadius = UDim.new(0, compact and 5 or 7)
	glowCorner.Parent = glowFrame

	local glowStroke = Instance.new("UIStroke")
	glowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	glowStroke.Thickness = compact and 2.5 or 4
	glowStroke.Color = P.OuterGlow
	glowStroke.Transparency = 0.62
	glowStroke.Parent = glowFrame

	-- Double inner horizontal trim lines (top & bottom)
	local insetX = compact and 10 or 18
	local line1Y = compact and 4 or 7
	local line2Y = compact and 6 or 11

	local function makeTrimLine(name: string, yOffset: number, fromBottom: boolean, col: Color3, trans: number)
		local line = Instance.new("Frame")
		line.Name = name
		line.Size = UDim2.new(1, -insetX * 2, 0, 1)
		line.Position = if fromBottom
			then UDim2.new(0, insetX, 1, -yOffset)
			else UDim2.new(0, insetX, 0, yOffset)
		line.BackgroundColor3 = col
		line.BackgroundTransparency = trans
		line.BorderSizePixel = 0
		line.ZIndex = baseZ + 1
		line.Parent = decorRoot
	end

	makeTrimLine("TopTrimOuter", line1Y, false, P.InnerLineBright, 0.25)
	makeTrimLine("TopTrimInner", line2Y, false, P.InnerLineMuted, 0.42)
	makeTrimLine("BottomTrimOuter", line1Y, true, P.InnerLineBright, 0.25)
	makeTrimLine("BottomTrimInner", line2Y, true, P.InnerLineMuted, 0.42)

	-- Ornate Gothic 4-Corner Filigree Crests (White scrollwork + dark purple diamond cutout)
	local wingLen = compact and 13 or 24
	local wingThick = compact and 2 or 3
	local diamondOuter = compact and 9 or 15
	local diamondInner = compact and 5 or 8
	local spurSize = compact and 4 or 6

	local corners = {
		{ Name = "CornerTL", X = 0, Y = 0, AX = 0, AY = 0, SX = 1, SY = 1 },
		{ Name = "CornerTR", X = 1, Y = 0, AX = 1, AY = 0, SX = -1, SY = 1 },
		{ Name = "CornerBL", X = 0, Y = 1, AX = 0, AY = 1, SX = 1, SY = -1 },
		{ Name = "CornerBR", X = 1, Y = 1, AX = 1, AY = 1, SX = -1, SY = -1 },
	}

	for _, c in ipairs(corners) do
		-- Horizontal filigree wing
		local hWing = Instance.new("Frame")
		hWing.Name = c.Name .. "_HWing"
		hWing.Size = UDim2.fromOffset(wingLen, wingThick)
		hWing.AnchorPoint = Vector2.new(c.AX, c.AY)
		hWing.Position = UDim2.new(c.X, -c.SX * 1, c.Y, -c.SY * 1)
		hWing.BackgroundColor3 = P.FiligreeWhite
		hWing.BorderSizePixel = 0
		hWing.ZIndex = baseZ + 2
		hWing.Parent = decorRoot

		-- Vertical filigree wing
		local vWing = Instance.new("Frame")
		vWing.Name = c.Name .. "_VWing"
		vWing.Size = UDim2.fromOffset(wingThick, wingLen)
		vWing.AnchorPoint = Vector2.new(c.AX, c.AY)
		vWing.Position = UDim2.new(c.X, -c.SX * 1, c.Y, -c.SY * 1)
		vWing.BackgroundColor3 = P.FiligreeWhite
		vWing.BorderSizePixel = 0
		vWing.ZIndex = baseZ + 2
		vWing.Parent = decorRoot

		-- Stepped gothic spur tip on horizontal edge
		local hSpur = Instance.new("Frame")
		hSpur.Name = c.Name .. "_HSpur"
		hSpur.Size = UDim2.fromOffset(spurSize, spurSize)
		hSpur.AnchorPoint = Vector2.new(0.5, 0.5)
		hSpur.Position = UDim2.new(c.X, c.SX * (wingLen - 2), c.Y, c.SY * 1)
		hSpur.Rotation = 45
		hSpur.BackgroundColor3 = P.FiligreeWhite
		hSpur.BorderSizePixel = 0
		hSpur.ZIndex = baseZ + 2
		hSpur.Parent = decorRoot

		-- Stepped gothic spur tip on vertical edge
		local vSpur = Instance.new("Frame")
		vSpur.Name = c.Name .. "_VSpur"
		vSpur.Size = UDim2.fromOffset(spurSize, spurSize)
		vSpur.AnchorPoint = Vector2.new(0.5, 0.5)
		vSpur.Position = UDim2.new(c.X, c.SX * 1, c.Y, c.SY * (wingLen - 2))
		vSpur.Rotation = 45
		vSpur.BackgroundColor3 = P.FiligreeWhite
		vSpur.BorderSizePixel = 0
		vSpur.ZIndex = baseZ + 2
		vSpur.Parent = decorRoot

		-- Outer white gothic corner crest (45 deg diamond)
		local crestOuter = Instance.new("Frame")
		crestOuter.Name = c.Name .. "_CrestOuter"
		crestOuter.Size = UDim2.fromOffset(diamondOuter, diamondOuter)
		crestOuter.AnchorPoint = Vector2.new(0.5, 0.5)
		crestOuter.Position = UDim2.new(c.X, c.SX * (compact and 3 or 5), c.Y, c.SY * (compact and 3 or 5))
		crestOuter.Rotation = 45
		crestOuter.BackgroundColor3 = P.FiligreeWhite
		crestOuter.BorderSizePixel = 0
		crestOuter.ZIndex = baseZ + 2
		crestOuter.Parent = decorRoot

		-- Dark purple inner diamond cutout inside corner crest
		local crestCutout = Instance.new("Frame")
		crestCutout.Name = "DarkCutout"
		crestCutout.Size = UDim2.fromOffset(diamondInner, diamondInner)
		crestCutout.AnchorPoint = Vector2.new(0.5, 0.5)
		crestCutout.Position = UDim2.fromScale(0.5, 0.5)
		crestCutout.BackgroundColor3 = P.CornerCutout
		crestCutout.BorderSizePixel = 0
		crestCutout.ZIndex = baseZ + 3
		crestCutout.Parent = crestOuter
	end

	return container
end

return GothicBoxStyle
