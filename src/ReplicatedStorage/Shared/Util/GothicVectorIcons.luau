--!strict
-- ReplicatedStorage/Shared/Util/GothicVectorIcons.luau
-- Authoritative Pure Procedural Vector UI Icons for Infinite Towers.
-- Renders 100% mathematical vector GuiObjects (Frames, UICorner, UIStroke, UIGradient)
-- with zero raster image dependencies. These icons NEVER pixelate, blur, or distort
-- when resized, scaled across devices, or animated with UIScale.

local TweenService = game:GetService("TweenService")

local GothicVectorIcons = {}

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

export type IconOptions = {
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	ZIndex: number?,
	Parent: Instance?,
	AccentColor: Color3?,
}

--------------------------------------------------------------------------------
-- 1. GOLD CURRENCY MEDALLION (Vector Coin)
--------------------------------------------------------------------------------
function GothicVectorIcons.CreateGold(opts: IconOptions?): Frame
	local o = opts or {}
	local baseZ = o.ZIndex or 10

	local root = new("Frame", {
		Name = "VectorGoldCoin",
		BackgroundTransparency = 1,
		Size = o.Size or UDim2.fromOffset(24, 24),
		Position = o.Position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = o.AnchorPoint or Vector2.new(0.5, 0.5),
		ZIndex = baseZ,
	}, o.Parent)

	new("UIAspectRatioConstraint", { AspectRatio = 1, AspectType = Enum.AspectType.FitWithinMaxSize }, root)

	-- Outer Coin Rim with Radiant Gold Gradient
	local coin = new("Frame", {
		Name = "CoinBody",
		Size = UDim2.fromScale(0.92, 0.92),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(245, 180, 40),
		BorderSizePixel = 0,
		ZIndex = baseZ + 1,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, coin)

	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 238, 140)),
			ColorSequenceKeypoint.new(0.35, Color3.fromRGB(245, 190, 50)),
			ColorSequenceKeypoint.new(0.80, Color3.fromRGB(195, 130, 20)),
			ColorSequenceKeypoint.new(1.0, Color3.fromRGB(150, 95, 12)),
		}),
		Rotation = 45,
	}, coin)

	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(255, 248, 190),
		Thickness = 1.4,
		Transparency = 0.1,
	}, coin)

	-- Inner Beveled Groove
	local inner = new("Frame", {
		Name = "InnerGroove",
		Size = UDim2.fromScale(0.72, 0.72),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(185, 125, 20),
		BorderSizePixel = 0,
		ZIndex = baseZ + 2,
	}, coin)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, inner)

	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(210, 150, 30)),
			ColorSequenceKeypoint.new(1.0, Color3.fromRGB(130, 80, 10)),
		}),
		Rotation = 45,
	}, inner)

	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(105, 65, 8),
		Thickness = 1.0,
		Transparency = 0.3,
	}, inner)

	-- Central Star/Diamond Emblem
	local star = new("Frame", {
		Name = "StarEmblem",
		Size = UDim2.fromScale(0.38, 0.38),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 245, 185),
		BorderSizePixel = 0,
		Rotation = 45,
		ZIndex = baseZ + 3,
	}, inner)
	new("UICorner", { CornerRadius = UDim.new(0, 1) }, star)

	-- Top-Left Specular Glint
	local glint = new("Frame", {
		Name = "Glint",
		Size = UDim2.fromScale(0.24, 0.24),
		Position = UDim2.fromScale(0.32, 0.32),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = baseZ + 4,
	}, coin)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, glint)

	return root
end

--------------------------------------------------------------------------------
-- 2. GEMS / DIAMOND CURRENCY CRYSTAL (Vector Gem)
--------------------------------------------------------------------------------
function GothicVectorIcons.CreateGems(opts: IconOptions?): Frame
	local o = opts or {}
	local baseZ = o.ZIndex or 10

	local root = new("Frame", {
		Name = "VectorGemCrystal",
		BackgroundTransparency = 1,
		Size = o.Size or UDim2.fromOffset(24, 24),
		Position = o.Position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = o.AnchorPoint or Vector2.new(0.5, 0.5),
		ZIndex = baseZ,
	}, o.Parent)

	new("UIAspectRatioConstraint", { AspectRatio = 1, AspectType = Enum.AspectType.FitWithinMaxSize }, root)

	-- Main Faceted Cyan Diamond
	local gem = new("Frame", {
		Name = "GemDiamond",
		Size = UDim2.fromScale(0.68, 0.68),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(60, 200, 250),
		BorderSizePixel = 0,
		Rotation = 45,
		ZIndex = baseZ + 1,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(0, 2) }, gem)

	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(230, 250, 255)),
			ColorSequenceKeypoint.new(0.35, Color3.fromRGB(90, 215, 255)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(20, 140, 220)),
			ColorSequenceKeypoint.new(1.0, Color3.fromRGB(5, 75, 150)),
		}),
		Rotation = -45,
	}, gem)

	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(235, 250, 255),
		Thickness = 1.4,
		Transparency = 0.05,
	}, gem)

	-- Upper Specular Facet
	local upperFacet = new("Frame", {
		Name = "FacetHighlight",
		Size = UDim2.fromScale(0.48, 0.48),
		Position = UDim2.fromScale(0.24, 0.24),
		AnchorPoint = Vector2.new(0, 0),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.42,
		BorderSizePixel = 0,
		ZIndex = baseZ + 2,
	}, gem)
	new("UICorner", { CornerRadius = UDim.new(0, 1) }, upperFacet)

	-- Lower Refraction Facet
	local lowerFacet = new("Frame", {
		Name = "FacetDepth",
		Size = UDim2.fromScale(0.48, 0.48),
		Position = UDim2.fromScale(0.52, 0.52),
		AnchorPoint = Vector2.new(0, 0),
		BackgroundColor3 = Color3.fromRGB(2, 40, 95),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		ZIndex = baseZ + 2,
	}, gem)
	new("UICorner", { CornerRadius = UDim.new(0, 1) }, lowerFacet)

	return root
end

-- Alias for Gem
GothicVectorIcons.CreateGem = GothicVectorIcons.CreateGems

--------------------------------------------------------------------------------
-- HIGH RESOLUTION VECTOR ACTION BADGES (1:1 HUD Mockup Match)
--------------------------------------------------------------------------------
GothicVectorIcons.ASSETS = {
	Shop = "rbxassetid://84321655525740",
	Squad = "rbxassetid://107467890348154",
	Overdrive = "rbxassetid://77196239306470",
	Recall = "rbxassetid://101743588202795",
	Tower = "rbxassetid://93333257917354",
}

local function createActionBadge(
	badgeName: string,
	assetId: string,
	defaultAccent: Color3,
	opts: IconOptions?
): Frame
	local o = opts or {}
	local baseZ = o.ZIndex or 12
	local accent = o.AccentColor or defaultAccent

	local root = new("Frame", {
		Name = badgeName,
		BackgroundTransparency = 1,
		Size = o.Size or UDim2.fromScale(1, 1),
		Position = o.Position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = o.AnchorPoint or Vector2.new(0.5, 0.5),
		ZIndex = baseZ,
	}, o.Parent)

	new("UIAspectRatioConstraint", { AspectRatio = 1, AspectType = Enum.AspectType.FitWithinMaxSize }, root)

	-- Obsidian Disc Base (56px circular base with dark gradient and accent border)
	local disc = new("Frame", {
		Name = "ObsidianDisc",
		Size = UDim2.fromScale(0.92, 0.92),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(13, 9, 18),
		BorderSizePixel = 0,
		ZIndex = baseZ + 1,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, disc)

	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(38, 28, 50)),
			ColorSequenceKeypoint.new(1.0, Color3.fromRGB(13, 9, 18)),
		}),
		Rotation = 135,
	}, disc)

	new("UIStroke", {
		Name = "DiscBorder",
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = accent,
		Thickness = 1.6,
		Transparency = 0.0,
	}, disc)

	-- Inner Groove Shadow Ring
	local innerGroove = new("Frame", {
		Name = "InnerGroove",
		Size = UDim2.fromScale(0.86, 0.86),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = baseZ + 2,
	}, disc)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, innerGroove)
	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(0, 0, 0),
		Thickness = 1.0,
		Transparency = 0.65,
	}, innerGroove)

	-- Ambient Soft Glow Drop Shadow
	new("ImageLabel", {
		Name = "ShadowGlow",
		Size = UDim2.fromScale(0.54, 0.54),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = assetId,
		ImageColor3 = accent,
		ImageTransparency = 0.68,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = baseZ + 3,
	}, disc)

	-- Pure Vector Line Art (White line art tinted exactly to theme accent color)
	new("ImageLabel", {
		Name = "VectorGlyph",
		Size = UDim2.fromScale(0.48, 0.48),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = assetId,
		ImageColor3 = accent,
		ImageTransparency = 0,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = baseZ + 4,
	}, disc)

	return root
end

function GothicVectorIcons.CreateShop(opts: IconOptions?): Frame
	return createActionBadge("VectorShopBadge", GothicVectorIcons.ASSETS.Shop, Color3.fromRGB(250, 204, 21), opts)
end

function GothicVectorIcons.CreateSquad(opts: IconOptions?): Frame
	return createActionBadge("VectorSquadBadge", GothicVectorIcons.ASSETS.Squad, Color3.fromRGB(56, 189, 248), opts)
end

function GothicVectorIcons.CreateOverdrive(opts: IconOptions?): Frame
	return createActionBadge("VectorOverdriveBadge", GothicVectorIcons.ASSETS.Overdrive, Color3.fromRGB(245, 158, 11), opts)
end

function GothicVectorIcons.CreateRecall(opts: IconOptions?): Frame
	return createActionBadge("VectorRecallBadge", GothicVectorIcons.ASSETS.Recall, Color3.fromRGB(34, 211, 238), opts)
end

function GothicVectorIcons.CreateTower(opts: IconOptions?): Frame
	return createActionBadge("VectorTowerBadge", GothicVectorIcons.ASSETS.Tower, Color3.fromRGB(192, 132, 252), opts)
end

-- Fortress Tree badge. There is no uploaded line-art asset yet, so the disc carries a text glyph.
function GothicVectorIcons.CreateFortress(opts: IconOptions?): Frame
	local badge = createActionBadge("VectorFortressBadge", "", Color3.fromRGB(214, 180, 120), opts)
	local disc = badge:FindFirstChild("ObsidianDisc")
	if disc and disc:IsA("GuiObject") then
		new("TextLabel", {
			Name = "FortressGlyph",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0.62, 0.62),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Text = "🏰",
			TextScaled = true,
			ZIndex = disc.ZIndex + 4,
		}, disc)
	end
	return badge
end

--------------------------------------------------------------------------------
-- 8. ACTIVE AURA / HALO (Vector Circular Glow)
--------------------------------------------------------------------------------
function GothicVectorIcons.CreateAura(opts: IconOptions?): Frame
	local o = opts or {}
	local baseZ = o.ZIndex or 11

	local root = new("Frame", {
		Name = "ActiveAura",
		Size = o.Size or UDim2.fromScale(1.22, 1.22),
		Position = o.Position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = o.AnchorPoint or Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = baseZ,
	}, o.Parent)

	new("UIAspectRatioConstraint", { AspectRatio = 1, AspectType = Enum.AspectType.FitWithinMaxSize }, root)

	local halo = new("Frame", {
		Name = "HaloRing",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = baseZ,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, halo)

	local stroke = new("UIStroke", {
		Name = "AuraStroke",
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = o.AccentColor or Color3.fromRGB(200, 140, 255),
		Thickness = 3.5,
		Transparency = 0.35,
	}, halo)

	return root
end

--------------------------------------------------------------------------------
-- 9. PROGRESSION RIGHT ARROW (Vector Directional Ascension Arrow)
--------------------------------------------------------------------------------
function GothicVectorIcons.CreateRightArrow(opts: IconOptions?): Frame
	local o = opts or {}
	local baseZ = o.ZIndex or 43
	local accent = o.AccentColor or Color3.fromRGB(200, 162, 200)

	local root = new("Frame", {
		Name = "VectorRightArrow",
		BackgroundTransparency = 1,
		Size = o.Size or UDim2.fromOffset(60, 32),
		Position = o.Position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = o.AnchorPoint or Vector2.new(0.5, 0.5),
		ZIndex = baseZ,
	}, o.Parent)

	local bright = Color3.fromRGB(
		math.clamp(math.floor(accent.R * 255 * 1.25 + 20), 0, 255),
		math.clamp(math.floor(accent.G * 255 * 1.25 + 20), 0, 255),
		math.clamp(math.floor(accent.B * 255 * 1.25 + 20), 0, 255)
	)

	-- Outer Atmospheric Glow
	local glow = new("Frame", {
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -8, 0, 22),
		BackgroundColor3 = accent,
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		ZIndex = baseZ,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(0, 11) }, glow)

	-- Central Horizontal Shaft
	local shaft = new("Frame", {
		Name = "Shaft",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.new(1, -18, 0, 3.5),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		ZIndex = baseZ + 1,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, shaft)

	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(
				math.floor(accent.R * 255 * 0.75),
				math.floor(accent.G * 255 * 0.75),
				math.floor(accent.B * 255 * 0.75)
			)),
			ColorSequenceKeypoint.new(0.65, accent),
			ColorSequenceKeypoint.new(1.0, bright),
		}),
	}, shaft)

	-- Arrowhead Wings (Chevron pointing right)
	local wingTop = new("Frame", {
		Name = "WingTop",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0, 14, 0, 3.5),
		Rotation = 38,
		BackgroundColor3 = bright,
		BorderSizePixel = 0,
		ZIndex = baseZ + 2,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, wingTop)

	local wingBottom = new("Frame", {
		Name = "WingBottom",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0, 14, 0, 3.5),
		Rotation = -38,
		BackgroundColor3 = bright,
		BorderSizePixel = 0,
		ZIndex = baseZ + 2,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, wingBottom)

	-- Seamless Vertex Tip
	local tip = new("Frame", {
		Name = "Tip",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -10.5, 0.5, 0),
		Size = UDim2.fromOffset(5, 5),
		Rotation = 45,
		BackgroundColor3 = bright,
		BorderSizePixel = 0,
		ZIndex = baseZ + 3,
	}, root)

	return root
end

--------------------------------------------------------------------------------
-- 10. PADLOCK (Vector Gothic Lock for Slots & Locked Features)
--------------------------------------------------------------------------------
function GothicVectorIcons.CreatePadlock(opts: IconOptions?): Frame
	local o = opts or {}
	local baseZ = o.ZIndex or 10
	local accent = o.AccentColor or Color3.fromRGB(154, 142, 181)

	local root = new("Frame", {
		Name = "VectorPadlock",
		BackgroundTransparency = 1,
		Size = o.Size or UDim2.fromOffset(24, 24),
		Position = o.Position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = o.AnchorPoint or Vector2.new(0.5, 0.5),
		ZIndex = baseZ,
	}, o.Parent)

	new("UIAspectRatioConstraint", { AspectRatio = 1, AspectType = Enum.AspectType.FitWithinMaxSize }, root)

	-- Top Shackle (Arched U-bar)
	local shackle = new("Frame", {
		Name = "Shackle",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.1),
		Size = UDim2.fromScale(0.48, 0.44),
		BackgroundTransparency = 1,
		ZIndex = baseZ + 1,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, shackle)
	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = accent,
		Thickness = 2.2,
	}, shackle)

	-- Lower Body Box (Rounded Rect)
	local body = new("Frame", {
		Name = "Body",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.92),
		Size = UDim2.fromScale(0.66, 0.52),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		ZIndex = baseZ + 2,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(0, 3) }, body)

	-- Keyhole Center Circle & Slit
	local keyholeDot = new("Frame", {
		Name = "KeyholeCircle",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.22, 0.28),
		BackgroundColor3 = Color3.fromRGB(15, 12, 24),
		BorderSizePixel = 0,
		ZIndex = baseZ + 3,
	}, body)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, keyholeDot)

	local keyholeSlit = new("Frame", {
		Name = "KeyholeSlit",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromScale(0.12, 0.32),
		BackgroundColor3 = Color3.fromRGB(15, 12, 24),
		BorderSizePixel = 0,
		ZIndex = baseZ + 3,
	}, body)
	new("UICorner", { CornerRadius = UDim.new(0, 1) }, keyholeSlit)

	return root
end

GothicVectorIcons.CreateLock = GothicVectorIcons.CreatePadlock

--------------------------------------------------------------------------------
-- GENERAL DISPATCHER
--------------------------------------------------------------------------------
function GothicVectorIcons.Create(name: string, opts: IconOptions?): Frame
	local n = string.lower(name)
	if n == "gold" then
		return GothicVectorIcons.CreateGold(opts)
	elseif n == "gems" or n == "gem" or n == "diamond" then
		return GothicVectorIcons.CreateGems(opts)
	elseif n == "shop" then
		return GothicVectorIcons.CreateShop(opts)
	elseif n == "squad" then
		return GothicVectorIcons.CreateSquad(opts)
	elseif n == "overdrive" then
		return GothicVectorIcons.CreateOverdrive(opts)
	elseif n == "recall" then
		return GothicVectorIcons.CreateRecall(opts)
	elseif n == "tower" then
		return GothicVectorIcons.CreateTower(opts)
	elseif n == "fortress" then
		return GothicVectorIcons.CreateFortress(opts)
	elseif n == "aura" then
		return GothicVectorIcons.CreateAura(opts)
	elseif n == "arrow" or n == "rightarrow" or n == "right_arrow" then
		return GothicVectorIcons.CreateRightArrow(opts)
	elseif n == "lock" or n == "padlock" then
		return GothicVectorIcons.CreatePadlock(opts)
	else
		-- Fallback to gold or generic diamond
		return GothicVectorIcons.CreateGold(opts)
	end
end

return GothicVectorIcons
