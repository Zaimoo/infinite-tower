--!strict
-- LeaderboardBoardBuilder.luau
-- Builds each Gothic Medieval Fantasy world leaderboard monument (Top Robux Donated,
-- Top Power, Top Playtime) using Blender-authored geometry via LeaderboardMeshHydrator
-- and a uniform Cinzel / CinzelDecorative SurfaceGui with left-of-avatar rank numbers.
-- Built at 1x base scale around origin with the screen facing -Z; SharedLeaderboards seats and scales it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LeaderboardRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("LeaderboardRules"))
local LeaderboardMeshHydrator = require(ReplicatedStorage:WaitForChild("Assets"):WaitForChild("LeaderboardMeshHydrator"))
local PartKit = require(script.Parent:WaitForChild("PartKit"))

local LeaderboardBoardBuilder = {}

LeaderboardBoardBuilder.DesignVersion = 2

export type Kind = LeaderboardRules.LeaderboardKind

local HAN = LeaderboardRules.HAN_PALETTE
local SCREEN_SIZE = LeaderboardRules.SCREEN_SIZE
local SCREEN_Y = LeaderboardRules.SCREEN_Y
local PPS = LeaderboardRules.PIXELS_PER_STUD

local OBSIDIAN_BG = Color3.fromRGB(14, 16, 24)
local CARD_BG = Color3.fromRGB(24, 28, 39)
local GOLD_TEXT = Color3.fromRGB(245, 222, 168)
local GOLD_FRAME = Color3.fromRGB(198, 162, 92)
local CREAM = Color3.fromRGB(238, 244, 251)
local MUTED_TEXT = Color3.fromRGB(172, 178, 198)
local INK = Color3.fromRGB(6, 10, 16)

local MODEL_META: { [Kind]: { BoardName: string, ScreenName: string, ValueFrame: string, ValueLabel: string, ModelKey: string, StudioModel: string } } = {
	Donated = {
		BoardName = "AvxsedDonatedWS",
		ScreenName = "ScreenDonated",
		ValueFrame = "TotalDonatedLabelFrame",
		ValueLabel = "TotalDonatedLabel",
		ModelKey = "leaderboard_pediment_frame",
		StudioModel = "LeaderboardPedimentFrame",
	},
	Power = {
		BoardName = "AvxsedPowerWS",
		ScreenName = "ScreenPower",
		ValueFrame = "TotalPowerLabelFrame",
		ValueLabel = "TotalPowerLabel",
		ModelKey = "leaderboard_power_monolith",
		StudioModel = "LeaderboardPowerMonolith",
	},
	Playtime = {
		BoardName = "AvxsedPlaytimeWS",
		ScreenName = "ScreenPlaytime",
		ValueFrame = "TotalPlaytimeLabelFrame",
		ValueLabel = "TotalPlaytimeLabel",
		ModelKey = "leaderboard_pediment_frame",
		StudioModel = "LeaderboardPedimentFrame",
	},
}

local function newInst(className: string, props: { [string]: any }): Instance
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	inst.Parent = props.Parent
	return inst
end

local function applyCinzelFont(lbl: TextLabel, family: string, weight: Enum.FontWeight)
	local ok, face = pcall(function()
		return Font.fromName(family, weight)
	end)
	if ok and face then
		lbl.FontFace = face
	else
		lbl.Font = Enum.Font.Garamond
	end
end

local function makeLabel(
	name: string,
	parent: Instance,
	text: string,
	size: UDim2,
	pos: UDim2,
	color: Color3,
	family: string,
	weight: Enum.FontWeight,
	align: Enum.TextXAlignment?,
	strokeThickness: number?
): TextLabel
	local lbl = newInst("TextLabel", {
		Name = name,
		Size = size,
		Position = pos,
		BackgroundTransparency = 1,
		Text = text,
		TextScaled = true,
		TextColor3 = color,
		TextXAlignment = align or Enum.TextXAlignment.Center,
		Parent = parent,
	}) :: TextLabel
	applyCinzelFont(lbl, family, weight)
	if strokeThickness and strokeThickness > 0 then
		newInst("UIStroke", {
			Color = INK,
			Thickness = strokeThickness,
			Transparency = 0.1,
			Parent = lbl,
		})
	end
	return lbl
end

function LeaderboardBoardBuilder.RankColor(rank: number): Color3
	return LeaderboardRules.RankColor(rank)
end

function LeaderboardBoardBuilder.UpdateCanvasSize(scrollFrame: ScrollingFrame, rowCount: number)
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.None
	scrollFrame.CanvasSize = UDim2.fromOffset(0, LeaderboardRules.CanvasHeight(rowCount))
end

local function buildScreenGui(screen: BasePart, kind: Kind)
	local meta = MODEL_META[kind]
	local isPower = kind == "Power"
	local accentColor = if isPower then HAN.Primary else GOLD_FRAME
	local valueColor = if isPower then HAN.Core else GOLD_TEXT

	local gui = newInst("SurfaceGui", {
		Name = "SurfaceGui",
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = PPS,
		LightInfluence = 0,
		ZOffset = 1,
		MaxDistance = 600,
		Parent = screen,
	})
	local holder = newInst("Frame", {
		Name = "Holder",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = OBSIDIAN_BG,
		BorderSizePixel = 0,
		Parent = gui,
	})
	newInst("UIStroke", {
		Color = accentColor,
		Thickness = if isPower then 5 else 4,
		Transparency = if isPower then 0.2 else 0.35,
		Parent = holder,
	})

	local header = newInst("Frame", {
		Name = "Header",
		Size = UDim2.fromScale(1, 0.13),
		BackgroundColor3 = Color3.fromRGB(22, 26, 38),
		BorderSizePixel = 0,
		Parent = holder,
	})
	newInst("UIGradient", {
		Color = if isPower
			then ColorSequence.new(Color3.fromRGB(24, 38, 66), OBSIDIAN_BG)
			else ColorSequence.new(Color3.fromRGB(22, 32, 48), OBSIDIAN_BG),
		Rotation = 90,
		Parent = header,
	})
	newInst("Frame", {
		Name = "HeaderRule",
		Size = UDim2.new(0.92, 0, 0, 2),
		Position = UDim2.new(0.04, 0, 1, -2),
		BackgroundColor3 = accentColor,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Parent = header,
	})
	local headerFrame = newInst("Frame", {
		Name = "LabelFrame",
		Size = UDim2.fromScale(0.92, 0.78),
		Position = UDim2.fromScale(0.04, 0.11),
		BackgroundTransparency = 1,
		Parent = header,
	})
	makeLabel(
		"HeaderLabel",
		headerFrame,
		LeaderboardRules.TitleFor(kind),
		UDim2.fromScale(1, 1),
		UDim2.new(),
		GOLD_TEXT,
		"CinzelDecorative",
		Enum.FontWeight.Heavy,
		Enum.TextXAlignment.Center,
		2.6
	)

	local body = newInst("Frame", {
		Name = "Body",
		Size = UDim2.fromScale(1, 0.78),
		Position = UDim2.fromScale(0, 0.13),
		BackgroundTransparency = 1,
		Parent = holder,
	})
	local scroll = newInst("ScrollingFrame", {
		Name = "ScrollingFrame",
		Size = UDim2.new(1, -8, 1, -8),
		Position = UDim2.fromOffset(4, 4),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 7,
		ScrollBarImageColor3 = accentColor,
		ScrollingEnabled = true,
		AutomaticCanvasSize = Enum.AutomaticSize.None,
		CanvasSize = UDim2.new(),
		Parent = body,
	}) :: ScrollingFrame
	newInst("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 14),
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		Parent = scroll,
	})
	newInst("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, LeaderboardRules.ROW_PADDING),
		Parent = scroll,
	})

	-- Template row cloned by renderers: [#Rank] -> [Avatar] -> [DisplayName/@Username] -> [Value]
	local card = newInst("Frame", {
		Name = "TemplateCardFrame",
		Size = UDim2.new(1, -2, 0, LeaderboardRules.ROW_HEIGHT),
		BackgroundColor3 = CARD_BG,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Visible = false,
		Parent = scroll,
	})
	newInst("UICorner", { CornerRadius = UDim.new(0, 8), Parent = card })
	newInst("UIStroke", {
		Color = accentColor,
		Thickness = 1.4,
		Transparency = if isPower then 0.55 else 0.7,
		Parent = card,
	})

	makeLabel(
		"RankLabel",
		card,
		"#1",
		UDim2.new(0, 46, 1, -10),
		UDim2.fromOffset(6, 5),
		LeaderboardRules.RankColor(1),
		"Cinzel",
		Enum.FontWeight.Heavy,
		Enum.TextXAlignment.Center,
		2.0
	)

	local avatarFrame = newInst("Frame", {
		Name = "AvatarIconFrame",
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.fromOffset(56, 6),
		BackgroundColor3 = OBSIDIAN_BG,
		BorderSizePixel = 0,
		Parent = card,
	})
	newInst("UICorner", { CornerRadius = UDim.new(0, 8), Parent = avatarFrame })
	newInst("UIStroke", { Color = Color3.fromRGB(85, 92, 118), Thickness = 1, Parent = avatarFrame })
	local avatar = newInst("ImageLabel", {
		Name = "AvatarIcon",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = avatarFrame,
	})
	newInst("UICorner", { CornerRadius = UDim.new(0, 8), Parent = avatar })

	local info = newInst("Frame", {
		Name = "InfoLabel",
		Size = UDim2.new(0.57, -108, 1, -10),
		Position = UDim2.fromOffset(108, 5),
		BackgroundTransparency = 1,
		Parent = card,
	})
	makeLabel(
		"DisplayNameLabel",
		info,
		"Player",
		UDim2.fromScale(1, 0.58),
		UDim2.new(),
		CREAM,
		"Cinzel",
		Enum.FontWeight.Heavy,
		Enum.TextXAlignment.Left,
		1.2
	)
	makeLabel(
		"UsernameLabel",
		info,
		"@player",
		UDim2.fromScale(1, 0.38),
		UDim2.fromScale(0, 0.6),
		MUTED_TEXT,
		"Cinzel",
		Enum.FontWeight.Bold,
		Enum.TextXAlignment.Left,
		0
	)

	local valueFrame = newInst("Frame", {
		Name = meta.ValueFrame,
		Size = UDim2.new(0.41, -10, 0.68, 0),
		Position = UDim2.fromScale(0.58, 0.16),
		BackgroundTransparency = 1,
		Parent = card,
	})
	makeLabel(
		meta.ValueLabel,
		valueFrame,
		"0",
		UDim2.fromScale(1, 1),
		UDim2.new(),
		valueColor,
		"Cinzel",
		Enum.FontWeight.Heavy,
		Enum.TextXAlignment.Right,
		1.4
	)

	local footer = newInst("Frame", {
		Name = "Footer",
		Size = UDim2.fromScale(1, 0.09),
		Position = UDim2.fromScale(0, 0.91),
		BackgroundColor3 = Color3.fromRGB(18, 20, 30),
		BorderSizePixel = 0,
		Parent = holder,
	})
	local footerFrame = newInst("Frame", {
		Name = "LabelFrame",
		Size = UDim2.fromScale(0.92, 0.72),
		Position = UDim2.fromScale(0.04, 0.14),
		BackgroundTransparency = 1,
		Parent = footer,
	})
	makeLabel(
		"UpdateLabel",
		footerFrame,
		"Updating...",
		UDim2.fromScale(1, 1),
		UDim2.new(),
		MUTED_TEXT,
		"Cinzel",
		Enum.FontWeight.Bold,
		Enum.TextXAlignment.Center,
		0
	)
end

local function attachPowerVfx(parts: { BasePart })
	for _, p in ipairs(parts) do
		if p.Name == "Monolith_GlitchChannels" then
			newInst("PointLight", {
				Name = "HanGlitchLight",
				Color = HAN.Primary,
				Range = 20,
				Brightness = 1.6,
				Shadows = false,
				Parent = p,
			})
			newInst("ParticleEmitter", {
				Name = "HanGlitchSparks",
				Color = ColorSequence.new(HAN.Primary, HAN.Core),
				LightEmission = 1,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.25),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.22),
					NumberSequenceKeypoint.new(1, 0),
				}),
				Lifetime = NumberRange.new(0.45, 0.95),
				Rate = 10,
				Speed = NumberRange.new(0.5, 2.0),
				SpreadAngle = Vector2.new(25, 25),
				Parent = p,
			})
		elseif p.Name == "Monolith_KeystoneRunes" then
			newInst("PointLight", {
				Name = "HanRuneGlow",
				Color = HAN.Core,
				Range = 14,
				Brightness = 1.1,
				Shadows = false,
				Parent = p,
			})
		end
	end
end

function LeaderboardBoardBuilder.Build(kind: Kind): Folder
	local meta = MODEL_META[kind]
	local board = Instance.new("Folder")
	board.Name = meta.BoardName
	board:SetAttribute("BoardDesignVersion", LeaderboardBoardBuilder.DesignVersion)
	board:SetAttribute("LeaderboardKind", kind)

	local build = Instance.new("Model")
	build.Name = "Build"
	build.Parent = board

	local meshParts = LeaderboardMeshHydrator.BuildMonument(build, meta.ModelKey, meta.StudioModel)
	if kind == "Power" then
		attachPowerVfx(meshParts)
	end

	-- Recessed screen sitting snugly inside the Blender monument aperture, facing -Z
	local screenCF = CFrame.new(0, SCREEN_Y, 0)
	local screen = PartKit.Part({
		Name = meta.ScreenName,
		Size = SCREEN_SIZE,
		CFrame = screenCF,
		Color = OBSIDIAN_BG,
		Material = Enum.Material.Glass,
		Parent = board,
	})
	screen.CanCollide = false
	screen.CanTouch = false
	buildScreenGui(screen, kind)

	return board
end

return LeaderboardBoardBuilder
