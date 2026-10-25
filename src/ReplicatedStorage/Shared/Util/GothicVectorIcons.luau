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
-- 3. SHOP MEDALLION (Vector Merchant Coin Pouch & Vault)
--------------------------------------------------------------------------------
function GothicVectorIcons.CreateShop(opts: IconOptions?): Frame
	local o = opts or {}
	local baseZ = o.ZIndex or 12
	local accent = o.AccentColor or Color3.fromRGB(250, 204, 21) -- Imperial Gold (#FACC15)

	local root = new("Frame", {
		Name = "VectorShopBadge",
		BackgroundTransparency = 1,
		Size = o.Size or UDim2.fromScale(1, 1),
		Position = o.Position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = o.AnchorPoint or Vector2.new(0.5, 0.5),
		ZIndex = baseZ,
	}, o.Parent)

	new("UIAspectRatioConstraint", { AspectRatio = 1, AspectType = Enum.AspectType.FitWithinMaxSize }, root)

	-- Outer Ambient Glow Ring
	local glowRing = new("Frame", {
		Name = "OuterGlowRing",
		Size = UDim2.fromScale(0.96, 0.96),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = baseZ,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, glowRing)
	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = accent,
		Thickness = 2.4,
		Transparency = 0.45,
	}, glowRing)

	-- Obsidian Disc
	local disc = new("Frame", {
		Name = "ObsidianDisc",
		Size = UDim2.fromScale(0.88, 0.88),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(20, 15, 30),
		BorderSizePixel = 0,
		ZIndex = baseZ + 1,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, disc)

	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(36, 26, 52)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(18, 13, 26)),
			ColorSequenceKeypoint.new(1.0, Color3.fromRGB(10, 7, 16)),
		}),
		Rotation = 55,
	}, disc)

	-- Outer Ornate Gold Border
	new("UIStroke", {
		Name = "DiscGoldBorder",
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = accent,
		Thickness = 2.0,
	}, disc)

	-- Inner Subtle Ring
	local innerRing = new("Frame", {
		Name = "InnerFiligreeRing",
		Size = UDim2.fromScale(0.82, 0.82),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = baseZ + 2,
	}, disc)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, innerRing)
	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(255, 235, 140),
		Thickness = 1.0,
		Transparency = 0.65,
	}, innerRing)

	-- Merchant Pouch / Vault Silhouette
	local glyphContainer = new("Frame", {
		Name = "GlyphContainer",
		Size = UDim2.fromScale(0.66, 0.66),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = baseZ + 3,
	}, disc)

	-- Top Triangular Collar / Drawstring Top
	local topCollar = new("Frame", {
		Name = "TopCollar",
		Size = UDim2.fromScale(0.36, 0.22),
		Position = UDim2.fromScale(0.5, 0.22),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		ZIndex = baseZ + 4,
	}, glyphContainer)
	new("UICorner", { CornerRadius = UDim.new(0, 3) }, topCollar)
	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(255, 245, 180),
		Thickness = 1.2,
	}, topCollar)

	-- Drawstring Tie Band
	local tieBand = new("Frame", {
		Name = "TieBand",
		Size = UDim2.fromScale(0.42, 0.08),
		Position = UDim2.fromScale(0.5, 0.34),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 245, 180),
		BorderSizePixel = 0,
		ZIndex = baseZ + 5,
	}, glyphContainer)
	new("UICorner", { CornerRadius = UDim.new(0, 2) }, tieBand)

	-- Main Rounded Pouch Body
	local pouchBody = new("Frame", {
		Name = "PouchBody",
		Size = UDim2.fromScale(0.68, 0.54),
		Position = UDim2.fromScale(0.5, 0.64),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(35, 26, 46),
		BorderSizePixel = 0,
		ZIndex = baseZ + 4,
	}, glyphContainer)
	new("UICorner", { CornerRadius = UDim.new(0, 10) }, pouchBody)
	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = accent,
		Thickness = 1.8,
	}, pouchBody)

	-- Golden Coin Core on Pouch
	local coinCore = new("Frame", {
		Name = "CoinCore",
		Size = UDim2.fromScale(0.32, 0.32),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Rotation = 45,
		ZIndex = baseZ + 5,
	}, pouchBody)
	new("UICorner", { CornerRadius = UDim.new(0, 2) }, coinCore)
	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(255, 255, 255),
		Thickness = 1.0,
	}, coinCore)

	return root
end

--------------------------------------------------------------------------------
-- 4. SQUAD MEDALLION (Vector Knight Shield with Crossed 'X')
--------------------------------------------------------------------------------
function GothicVectorIcons.CreateSquad(opts: IconOptions?): Frame
	local o = opts or {}
	local baseZ = o.ZIndex or 12
	local accent = o.AccentColor or Color3.fromRGB(56, 189, 248) -- Azure (#38BDF8)

	local root = new("Frame", {
		Name = "VectorSquadBadge",
		BackgroundTransparency = 1,
		Size = o.Size or UDim2.fromScale(1, 1),
		Position = o.Position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = o.AnchorPoint or Vector2.new(0.5, 0.5),
		ZIndex = baseZ,
	}, o.Parent)

	new("UIAspectRatioConstraint", { AspectRatio = 1, AspectType = Enum.AspectType.FitWithinMaxSize }, root)

	-- Outer Ambient Azure Glow
	local glow = new("Frame", {
		Name = "OuterGlowRing",
		Size = UDim2.fromScale(0.96, 0.96),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = baseZ,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, glow)
	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = accent,
		Thickness = 2.4,
		Transparency = 0.45,
	}, glow)

	-- Midnight Navy Obsidian Base Disc
	local disc = new("Frame", {
		Name = "ObsidianDisc",
		Size = UDim2.fromScale(0.88, 0.88),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(14, 18, 32),
		BorderSizePixel = 0,
		ZIndex = baseZ + 1,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, disc)

	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(24, 32, 54)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(14, 18, 32)),
			ColorSequenceKeypoint.new(1.0, Color3.fromRGB(8, 10, 20)),
		}),
		Rotation = 45,
	}, disc)

	-- Polished Azure Rim Stroke
	new("UIStroke", {
		Name = "SilverRim",
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = accent,
		Thickness = 2.0,
	}, disc)

	-- Inner Ring
	local innerRing = new("Frame", {
		Name = "InnerSteelRing",
		Size = UDim2.fromScale(0.82, 0.82),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = baseZ + 2,
	}, disc)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, innerRing)
	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(180, 225, 255),
		Thickness = 1.0,
		Transparency = 0.65,
	}, innerRing)

	-- Heraldic Knight Shield with Crossed 'X'
	local shieldRoot = new("Frame", {
		Name = "ShieldRoot",
		Size = UDim2.fromScale(0.54, 0.64),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(20, 30, 52),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		ZIndex = baseZ + 3,
	}, disc)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, shieldRoot)
	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = accent,
		Thickness = 2.0,
	}, shieldRoot)

	-- Crossed 'X' Bar 1 (-45 deg)
	local x1 = new("Frame", {
		Name = "Bar1",
		Size = UDim2.new(0, 3, 0.68, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Rotation = -45,
		ZIndex = baseZ + 4,
	}, shieldRoot)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, x1)

	-- Crossed 'X' Bar 2 (45 deg)
	local x2 = new("Frame", {
		Name = "Bar2",
		Size = UDim2.new(0, 3, 0.68, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Rotation = 45,
		ZIndex = baseZ + 4,
	}, shieldRoot)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, x2)

	-- Center Diamond Node
	local centerNode = new("Frame", {
		Name = "CenterNode",
		Size = UDim2.fromOffset(6, 6),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		Rotation = 45,
		ZIndex = baseZ + 5,
	}, shieldRoot)
	new("UICorner", { CornerRadius = UDim.new(0, 1) }, centerNode)

	return root
end

--------------------------------------------------------------------------------
-- 5. OVERDRIVE MEDALLION (Vector Electric Lightning Bolt)
--------------------------------------------------------------------------------
function GothicVectorIcons.CreateOverdrive(opts: IconOptions?): Frame
	local o = opts or {}
	local baseZ = o.ZIndex or 12
	local accent = o.AccentColor or Color3.fromRGB(245, 158, 11) -- Amber (#F59E0B)

	local root = new("Frame", {
		Name = "VectorOverdriveBadge",
		BackgroundTransparency = 1,
		Size = o.Size or UDim2.fromScale(1, 1),
		Position = o.Position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = o.AnchorPoint or Vector2.new(0.5, 0.5),
		ZIndex = baseZ,
	}, o.Parent)

	new("UIAspectRatioConstraint", { AspectRatio = 1, AspectType = Enum.AspectType.FitWithinMaxSize }, root)

	-- Outer Fiery Amber Halo
	local glow = new("Frame", {
		Name = "OuterGlowRing",
		Size = UDim2.fromScale(0.96, 0.96),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = baseZ,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, glow)
	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = accent,
		Thickness = 2.4,
		Transparency = 0.45,
	}, glow)

	-- Deep Crimson Obsidian Disc
	local disc = new("Frame", {
		Name = "ObsidianDisc",
		Size = UDim2.fromScale(0.88, 0.88),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(28, 16, 12),
		BorderSizePixel = 0,
		ZIndex = baseZ + 1,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, disc)

	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(48, 26, 16)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(26, 14, 10)),
			ColorSequenceKeypoint.new(1.0, Color3.fromRGB(12, 6, 4)),
		}),
		Rotation = 45,
	}, disc)

	-- Radiant Molten Amber Rim
	new("UIStroke", {
		Name = "AmberRim",
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = accent,
		Thickness = 2.0,
	}, disc)

	-- Inner Ring
	local innerRing = new("Frame", {
		Name = "InnerAmberRing",
		Size = UDim2.fromScale(0.82, 0.82),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = baseZ + 2,
	}, disc)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, innerRing)
	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(255, 220, 130),
		Thickness = 1.0,
		Transparency = 0.65,
	}, innerRing)

	-- Dynamic Vector Lightning Bolt
	local boltContainer = new("Frame", {
		Name = "BoltContainer",
		Size = UDim2.fromScale(0.60, 0.64),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = baseZ + 3,
	}, disc)

	-- Upper Bolt Segment (Slanted)
	local upper = new("Frame", {
		Name = "BoltUpper",
		Size = UDim2.fromScale(0.24, 0.50),
		Position = UDim2.fromScale(0.58, 0.30),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 230, 110),
		BorderSizePixel = 0,
		Rotation = -26,
		ZIndex = baseZ + 4,
	}, boltContainer)
	new("UICorner", { CornerRadius = UDim.new(0, 2) }, upper)

	-- Lower Bolt Segment (Slanted towards bottom-left tip)
	local lower = new("Frame", {
		Name = "BoltLower",
		Size = UDim2.fromScale(0.22, 0.50),
		Position = UDim2.fromScale(0.42, 0.68),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Rotation = -26,
		ZIndex = baseZ + 4,
	}, boltContainer)
	new("UICorner", { CornerRadius = UDim.new(0, 2) }, lower)

	-- Horizontal Central Joining Bridge
	local bridge = new("Frame", {
		Name = "BoltBridge",
		Size = UDim2.fromScale(0.38, 0.16),
		Position = UDim2.fromScale(0.50, 0.49),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 245, 160),
		BorderSizePixel = 0,
		ZIndex = baseZ + 5,
	}, boltContainer)
	new("UICorner", { CornerRadius = UDim.new(0, 2) }, bridge)

	return root
end

--------------------------------------------------------------------------------
-- 6. RECALL MEDALLION (Vector Circular Return / Rewind Arrow)
--------------------------------------------------------------------------------
function GothicVectorIcons.CreateRecall(opts: IconOptions?): Frame
	local o = opts or {}
	local baseZ = o.ZIndex or 12
	local accent = o.AccentColor or Color3.fromRGB(34, 211, 238) -- Cyan (#22D3EE)

	local root = new("Frame", {
		Name = "VectorRecallBadge",
		BackgroundTransparency = 1,
		Size = o.Size or UDim2.fromScale(1, 1),
		Position = o.Position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = o.AnchorPoint or Vector2.new(0.5, 0.5),
		ZIndex = baseZ,
	}, o.Parent)

	new("UIAspectRatioConstraint", { AspectRatio = 1, AspectType = Enum.AspectType.FitWithinMaxSize }, root)

	-- Outer Arcane Cyan Halo
	local glow = new("Frame", {
		Name = "OuterGlowRing",
		Size = UDim2.fromScale(0.96, 0.96),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = baseZ,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, glow)
	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = accent,
		Thickness = 2.4,
		Transparency = 0.45,
	}, glow)

	-- Deep Arcane Cyan/Navy Obsidian Disc
	local disc = new("Frame", {
		Name = "ObsidianDisc",
		Size = UDim2.fromScale(0.88, 0.88),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(12, 20, 32),
		BorderSizePixel = 0,
		ZIndex = baseZ + 1,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, disc)

	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(20, 36, 56)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(10, 20, 34)),
			ColorSequenceKeypoint.new(1.0, Color3.fromRGB(5, 10, 18)),
		}),
		Rotation = 45,
	}, disc)

	-- Arcane Cyan Rim
	new("UIStroke", {
		Name = "CyanRim",
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = accent,
		Thickness = 2.0,
	}, disc)

	-- Return / Rewind Circular Arrow Glyph
	local arrowRoot = new("Frame", {
		Name = "ReturnArrowRoot",
		Size = UDim2.fromScale(0.62, 0.62),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = baseZ + 3,
	}, disc)

	-- Circular Arc (3/4 loop)
	local arc = new("Frame", {
		Name = "ArcRing",
		Size = UDim2.fromScale(0.86, 0.86),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = baseZ + 3,
	}, arrowRoot)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, arc)
	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = accent,
		Thickness = 2.4,
	}, arc)
	-- Cutout gradient to leave open gap at top-left
	new("UIGradient", {
		Rotation = 45,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 1.0),
			NumberSequenceKeypoint.new(0.22, 1.0),
			NumberSequenceKeypoint.new(0.28, 0.0),
			NumberSequenceKeypoint.new(1.0, 0.0),
		}),
	}, arc)

	-- Arrowhead pointing Left/Down at opening
	local arrowHead = new("Frame", {
		Name = "ArrowHead",
		Size = UDim2.fromOffset(10, 10),
		Position = UDim2.fromScale(0.18, 0.32),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Rotation = 35,
		ZIndex = baseZ + 5,
	}, arrowRoot)
	new("UICorner", { CornerRadius = UDim.new(0, 1) }, arrowHead)

	-- Center Sacred Dot
	local centerDot = new("Frame", {
		Name = "CenterDot",
		Size = UDim2.fromOffset(5, 5),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		Rotation = 45,
		ZIndex = baseZ + 4,
	}, arrowRoot)
	new("UICorner", { CornerRadius = UDim.new(0, 1) }, centerDot)

	return root
end

--------------------------------------------------------------------------------
-- 7. TOWER MEDALLION (Vector Monolith Tower Spire with Floors)
--------------------------------------------------------------------------------
function GothicVectorIcons.CreateTower(opts: IconOptions?): Frame
	local o = opts or {}
	local baseZ = o.ZIndex or 12
	local accent = o.AccentColor or Color3.fromRGB(192, 132, 252) -- Violet (#C084FC)

	local root = new("Frame", {
		Name = "VectorTowerBadge",
		BackgroundTransparency = 1,
		Size = o.Size or UDim2.fromScale(1, 1),
		Position = o.Position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = o.AnchorPoint or Vector2.new(0.5, 0.5),
		ZIndex = baseZ,
	}, o.Parent)

	new("UIAspectRatioConstraint", { AspectRatio = 1, AspectType = Enum.AspectType.FitWithinMaxSize }, root)

	-- Outer Mystic Violet Halo
	local glow = new("Frame", {
		Name = "OuterGlowRing",
		Size = UDim2.fromScale(0.96, 0.96),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = baseZ,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, glow)
	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = accent,
		Thickness = 2.4,
		Transparency = 0.45,
	}, glow)

	-- Deep Astral Obsidian Disc
	local disc = new("Frame", {
		Name = "ObsidianDisc",
		Size = UDim2.fromScale(0.88, 0.88),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(22, 14, 32),
		BorderSizePixel = 0,
		ZIndex = baseZ + 1,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, disc)

	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(38, 22, 54)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(20, 12, 30)),
			ColorSequenceKeypoint.new(1.0, Color3.fromRGB(10, 6, 16)),
		}),
		Rotation = 45,
	}, disc)

	-- Mystic Amethyst Rim
	new("UIStroke", {
		Name = "AmethystRim",
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = accent,
		Thickness = 2.0,
	}, disc)

	-- Inner Ring
	local innerRing = new("Frame", {
		Name = "InnerVioletRing",
		Size = UDim2.fromScale(0.82, 0.82),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = baseZ + 2,
	}, disc)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, innerRing)
	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(230, 200, 255),
		Thickness = 1.0,
		Transparency = 0.65,
	}, innerRing)

	-- Tower Monolith Spire Body
	local towerRoot = new("Frame", {
		Name = "MonolithRoot",
		Size = UDim2.fromScale(0.56, 0.66),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = baseZ + 3,
	}, disc)

	-- Pointed Spire Roof / Peak
	local peak = new("Frame", {
		Name = "SpirePeak",
		Size = UDim2.fromScale(0.40, 0.30),
		Position = UDim2.fromScale(0.5, 0.22),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Rotation = 45,
		ZIndex = baseZ + 4,
	}, towerRoot)
	new("UICorner", { CornerRadius = UDim.new(0, 1) }, peak)

	-- Main Tower Shaft
	local shaft = new("Frame", {
		Name = "TowerShaft",
		Size = UDim2.fromScale(0.52, 0.55),
		Position = UDim2.fromScale(0.5, 0.62),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(30, 18, 44),
		BorderSizePixel = 0,
		ZIndex = baseZ + 4,
	}, towerRoot)
	new("UICorner", { CornerRadius = UDim.new(0, 2) }, shaft)
	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = accent,
		Thickness = 1.8,
	}, shaft)

	-- Horizontal Floor Line 1
	local line1 = new("Frame", {
		Name = "FloorLine1",
		Size = UDim2.fromScale(0.72, 0.08),
		Position = UDim2.fromScale(0.5, 0.38),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		ZIndex = baseZ + 5,
	}, shaft)

	-- Horizontal Floor Line 2
	local line2 = new("Frame", {
		Name = "FloorLine2",
		Size = UDim2.fromScale(0.72, 0.08),
		Position = UDim2.fromScale(0.5, 0.68),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		ZIndex = baseZ + 5,
	}, shaft)

	-- Base Foundation Plinth
	local basePlinth = new("Frame", {
		Name = "BasePlinth",
		Size = UDim2.fromScale(0.76, 0.10),
		Position = UDim2.fromScale(0.5, 0.94),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		ZIndex = baseZ + 5,
	}, towerRoot)
	new("UICorner", { CornerRadius = UDim.new(0, 2) }, basePlinth)

	return root
end--------------------------------------------------------------------------------
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
