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
-- 3. SHOP MEDALLION (Vector Merchant Vault & Arch)
--------------------------------------------------------------------------------
function GothicVectorIcons.CreateShop(opts: IconOptions?): Frame
	local o = opts or {}
	local baseZ = o.ZIndex or 12

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
		Color = Color3.fromRGB(230, 185, 75),
		Thickness = 2.5,
		Transparency = 0.45,
	}, glowRing)

	-- Obsidian-Purple Gothic Medallion Disc
	local disc = new("Frame", {
		Name = "ObsidianDisc",
		Size = UDim2.fromScale(0.88, 0.88),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(22, 16, 32),
		BorderSizePixel = 0,
		ZIndex = baseZ + 1,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, disc)

	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(38, 26, 56)),
			ColorSequenceKeypoint.new(0.45, Color3.fromRGB(22, 15, 34)),
			ColorSequenceKeypoint.new(1.0, Color3.fromRGB(12, 8, 20)),
		}),
		Rotation = 55,
	}, disc)

	-- Outer Ornate Gold Border
	new("UIStroke", {
		Name = "DiscGoldBorder",
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(245, 205, 95),
		Thickness = 2.2,
	}, disc)

	-- Inner Delicate Silver Filigree Ring
	local innerRing = new("Frame", {
		Name = "InnerFiligreeRing",
		Size = UDim2.fromScale(0.80, 0.80),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = baseZ + 2,
	}, disc)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, innerRing)
	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(215, 195, 240),
		Thickness = 1.0,
		Transparency = 0.35,
	}, innerRing)

	-- Vector Merchant Vault & Canopy Structure
	local glyphContainer = new("Frame", {
		Name = "GlyphContainer",
		Size = UDim2.fromScale(0.66, 0.66),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = baseZ + 3,
	}, disc)

	-- Merchant Canopy Roof (Arched gold crest)
	local canopy = new("Frame", {
		Name = "CanopyRoof",
		Size = UDim2.fromScale(0.72, 0.22),
		Position = UDim2.fromScale(0.5, 0.22),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(245, 205, 95),
		BorderSizePixel = 0,
		ZIndex = baseZ + 4,
	}, glyphContainer)
	new("UICorner", { CornerRadius = UDim.new(0, 4) }, canopy)
	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 235, 140)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(225, 175, 60)),
			ColorSequenceKeypoint.new(1.0, Color3.fromRGB(180, 125, 25)),
		}),
		Rotation = 90,
	}, canopy)

	-- Apex Crown Diamond
	local crownApex = new("Frame", {
		Name = "CrownApex",
		Size = UDim2.fromScale(0.24, 0.24),
		Position = UDim2.fromScale(0.5, 0.08),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 245, 180),
		BorderSizePixel = 0,
		Rotation = 45,
		ZIndex = baseZ + 5,
	}, glyphContainer)
	new("UICorner", { CornerRadius = UDim.new(0, 1) }, crownApex)

	-- Slender Vault Pillars (Left and Right)
	for _, posX in ipairs({ 0.26, 0.74 }) do
		local pillar = new("Frame", {
			Name = "VaultPillar",
			Size = UDim2.fromScale(0.08, 0.36),
			Position = UDim2.fromScale(posX, 0.50),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(240, 195, 80),
			BorderSizePixel = 0,
			ZIndex = baseZ + 4,
		}, glyphContainer)
		new("UICorner", { CornerRadius = UDim.new(0, 1) }, pillar)
	end

	-- Center Golden Vault Medallion (Hanging Treasure Coin)
	local vaultCoin = new("Frame", {
		Name = "VaultCoin",
		Size = UDim2.fromScale(0.44, 0.44),
		Position = UDim2.fromScale(0.5, 0.56),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 215, 75),
		BorderSizePixel = 0,
		ZIndex = baseZ + 5,
	}, glyphContainer)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, vaultCoin)
	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 245, 160)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(240, 185, 45)),
			ColorSequenceKeypoint.new(1.0, Color3.fromRGB(175, 115, 15)),
		}),
		Rotation = 45,
	}, vaultCoin)
	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(255, 250, 200),
		Thickness = 1.2,
	}, vaultCoin)

	-- Center Diamond Core in Coin
	local coinCore = new("Frame", {
		Name = "CoinCore",
		Size = UDim2.fromScale(0.38, 0.38),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		Rotation = 45,
		ZIndex = baseZ + 6,
	}, vaultCoin)
	new("UICorner", { CornerRadius = UDim.new(0, 1) }, coinCore)

	-- Base Vault Plinth
	local plinth = new("Frame", {
		Name = "VaultPlinth",
		Size = UDim2.fromScale(0.80, 0.12),
		Position = UDim2.fromScale(0.5, 0.82),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(215, 170, 65),
		BorderSizePixel = 0,
		ZIndex = baseZ + 4,
	}, glyphContainer)
	new("UICorner", { CornerRadius = UDim.new(0, 2) }, plinth)

	return root
end

--------------------------------------------------------------------------------
-- 4. SQUAD MEDALLION (Vector Knight Shield & Crossed Broadswords)
--------------------------------------------------------------------------------
function GothicVectorIcons.CreateSquad(opts: IconOptions?): Frame
	local o = opts or {}
	local baseZ = o.ZIndex or 12

	local root = new("Frame", {
		Name = "VectorSquadBadge",
		BackgroundTransparency = 1,
		Size = o.Size or UDim2.fromScale(1, 1),
		Position = o.Position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = o.AnchorPoint or Vector2.new(0.5, 0.5),
		ZIndex = baseZ,
	}, o.Parent)

	new("UIAspectRatioConstraint", { AspectRatio = 1, AspectType = Enum.AspectType.FitWithinMaxSize }, root)

	-- Outer Ambient Silver/Azure Glow
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
		Color = Color3.fromRGB(160, 195, 245),
		Thickness = 2.5,
		Transparency = 0.45,
	}, glow)

	-- Midnight Navy Obsidian Base Disc
	local disc = new("Frame", {
		Name = "ObsidianDisc",
		Size = UDim2.fromScale(0.88, 0.88),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(16, 22, 38),
		BorderSizePixel = 0,
		ZIndex = baseZ + 1,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, disc)

	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(26, 36, 60)),
			ColorSequenceKeypoint.new(0.45, Color3.fromRGB(16, 22, 38)),
			ColorSequenceKeypoint.new(1.0, Color3.fromRGB(8, 12, 22)),
		}),
		Rotation = 45,
	}, disc)

	-- Polished Silver-White Outer Stroke
	new("UIStroke", {
		Name = "SilverRim",
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(246, 244, 255),
		Thickness = 2.2,
	}, disc)

	-- Inner Steel Blue Filigree Ring
	local innerRing = new("Frame", {
		Name = "InnerSteelRing",
		Size = UDim2.fromScale(0.80, 0.80),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = baseZ + 2,
	}, disc)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, innerRing)
	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(130, 160, 205),
		Thickness = 1.0,
		Transparency = 0.4,
	}, innerRing)

	-- Crossed Swords & Heraldic Shield Group
	local glyphRoot = new("Frame", {
		Name = "SwordGlyphRoot",
		Size = UDim2.fromScale(0.70, 0.70),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = baseZ + 3,
	}, disc)

	-- Crossed Sword 1 (Diagonal Left to Right, 45 deg)
	local function makeSword(name: string, rot: number)
		local sword = new("Frame", {
			Name = name,
			Size = UDim2.fromScale(0.12, 0.90),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Rotation = rot,
			ZIndex = baseZ + 4,
		}, glyphRoot)

		-- Blade (Silver gradient)
		local blade = new("Frame", {
			Name = "Blade",
			Size = UDim2.fromScale(0.5, 0.65),
			Position = UDim2.fromScale(0.5, 0.25),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(240, 240, 250),
			BorderSizePixel = 0,
			ZIndex = baseZ + 4,
		}, sword)
		new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(220, 225, 240)),
				ColorSequenceKeypoint.new(1.0, Color3.fromRGB(160, 170, 190)),
			}),
			Rotation = 0,
		}, blade)

		-- Blade Tip (Diamond)
		local tip = new("Frame", {
			Name = "Tip",
			Size = UDim2.fromScale(0.65, 0.14),
			Position = UDim2.fromScale(0.5, -0.05),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel = 0,
			Rotation = 45,
			ZIndex = baseZ + 4,
		}, blade)
		new("UICorner", { CornerRadius = UDim.new(0, 1) }, tip)

		-- Crossguard
		local guard = new("Frame", {
			Name = "Crossguard",
			Size = UDim2.fromScale(1.8, 0.08),
			Position = UDim2.fromScale(0.5, 0.58),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(240, 195, 80),
			BorderSizePixel = 0,
			ZIndex = baseZ + 5,
		}, sword)
		new("UICorner", { CornerRadius = UDim.new(0, 2) }, guard)

		-- Grip / Hilt
		local hilt = new("Frame", {
			Name = "Hilt",
			Size = UDim2.fromScale(0.45, 0.18),
			Position = UDim2.fromScale(0.5, 0.72),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(80, 50, 30),
			BorderSizePixel = 0,
			ZIndex = baseZ + 4,
		}, sword)

		-- Pommel (Gold Diamond)
		local pommel = new("Frame", {
			Name = "Pommel",
			Size = UDim2.fromScale(0.7, 0.10),
			Position = UDim2.fromScale(0.5, 0.85),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(240, 195, 80),
			BorderSizePixel = 0,
			Rotation = 45,
			ZIndex = baseZ + 5,
		}, sword)
		new("UICorner", { CornerRadius = UDim.new(0, 1) }, pommel)
	end

	makeSword("Sword_L", -45)
	makeSword("Sword_R", 45)

	-- Central Heraldic Knight Shield in foreground
	local shield = new("Frame", {
		Name = "KnightShield",
		Size = UDim2.fromScale(0.42, 0.52),
		Position = UDim2.fromScale(0.5, 0.52),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(24, 34, 58),
		BorderSizePixel = 0,
		ZIndex = baseZ + 6,
	}, glyphRoot)
	new("UICorner", { CornerRadius = UDim.new(0, 4) }, shield)

	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(38, 52, 85)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(22, 30, 50)),
			ColorSequenceKeypoint.new(1.0, Color3.fromRGB(12, 18, 30)),
		}),
		Rotation = 45,
	}, shield)

	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(246, 244, 255),
		Thickness = 1.6,
	}, shield)

	-- Golden Crest Star on Shield
	local shieldStar = new("Frame", {
		Name = "ShieldStar",
		Size = UDim2.fromScale(0.38, 0.38),
		Position = UDim2.fromScale(0.5, 0.48),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 215, 80),
		BorderSizePixel = 0,
		Rotation = 45,
		ZIndex = baseZ + 7,
	}, shield)
	new("UICorner", { CornerRadius = UDim.new(0, 1) }, shieldStar)

	return root
end

--------------------------------------------------------------------------------
-- 5. OVERDRIVE MEDALLION (Vector Celestial Starburst & Lightning)
--------------------------------------------------------------------------------
function GothicVectorIcons.CreateOverdrive(opts: IconOptions?): Frame
	local o = opts or {}
	local baseZ = o.ZIndex or 12

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
		Color = Color3.fromRGB(255, 120, 40),
		Thickness = 2.5,
		Transparency = 0.40,
	}, glow)

	-- Deep Crimson Obsidian Disc
	local disc = new("Frame", {
		Name = "ObsidianDisc",
		Size = UDim2.fromScale(0.88, 0.88),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(36, 12, 18),
		BorderSizePixel = 0,
		ZIndex = baseZ + 1,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, disc)

	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(56, 18, 26)),
			ColorSequenceKeypoint.new(0.45, Color3.fromRGB(34, 10, 16)),
			ColorSequenceKeypoint.new(1.0, Color3.fromRGB(14, 4, 8)),
		}),
		Rotation = 45,
	}, disc)

	-- Radiant Molten Amber Rim
	new("UIStroke", {
		Name = "AmberRim",
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(255, 175, 50),
		Thickness = 2.2,
	}, disc)

	-- Starburst Energy Spires (4 Cardinal + 4 Diagonal)
	local glyphContainer = new("Frame", {
		Name = "EnergyBurstContainer",
		Size = UDim2.fromScale(0.66, 0.66),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = baseZ + 2,
	}, disc)

	local function makeSpire(rot: number, sizeScale: number, color: Color3)
		local spire = new("Frame", {
			Name = "Spire",
			Size = UDim2.fromScale(0.12 * sizeScale, 0.85 * sizeScale),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Rotation = rot,
			ZIndex = baseZ + 3,
		}, glyphContainer)
		new("UICorner", { CornerRadius = UDim.new(0, 1) }, spire)
	end

	-- Diagonal bursts
	makeSpire(45, 0.72, Color3.fromRGB(255, 140, 40))
	makeSpire(-45, 0.72, Color3.fromRGB(255, 140, 40))
	-- Cardinal bursts
	makeSpire(0, 0.90, Color3.fromRGB(255, 200, 60))
	makeSpire(90, 0.90, Color3.fromRGB(255, 200, 60))

	-- Lightning Energy Bolt (Vector Zigzag)
	local bolt1 = new("Frame", {
		Name = "BoltUpper",
		Size = UDim2.fromScale(0.18, 0.44),
		Position = UDim2.fromScale(0.54, 0.34),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 245, 180),
		BorderSizePixel = 0,
		Rotation = -24,
		ZIndex = baseZ + 5,
	}, glyphContainer)
	new("UICorner", { CornerRadius = UDim.new(0, 2) }, bolt1)

	local bolt2 = new("Frame", {
		Name = "BoltLower",
		Size = UDim2.fromScale(0.16, 0.44),
		Position = UDim2.fromScale(0.44, 0.66),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 215, 60),
		BorderSizePixel = 0,
		Rotation = -24,
		ZIndex = baseZ + 5,
	}, glyphContainer)
	new("UICorner", { CornerRadius = UDim.new(0, 2) }, bolt2)

	-- Center Radiant Star Diamond
	local core = new("Frame", {
		Name = "CoreDiamond",
		Size = UDim2.fromScale(0.36, 0.36),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		Rotation = 45,
		ZIndex = baseZ + 6,
	}, glyphContainer)
	new("UICorner", { CornerRadius = UDim.new(0, 1) }, core)

	return root
end

--------------------------------------------------------------------------------
-- 6. RECALL MEDALLION (Vector Arcane Portal & Spiral Gateway)
--------------------------------------------------------------------------------
function GothicVectorIcons.CreateRecall(opts: IconOptions?): Frame
	local o = opts or {}
	local baseZ = o.ZIndex or 12

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
		Color = Color3.fromRGB(56, 189, 248),
		Thickness = 2.5,
		Transparency = 0.40,
	}, glow)

	-- Deep Arcane Cyan/Navy Obsidian Disc
	local disc = new("Frame", {
		Name = "ObsidianDisc",
		Size = UDim2.fromScale(0.88, 0.88),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(12, 22, 38),
		BorderSizePixel = 0,
		ZIndex = baseZ + 1,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, disc)

	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(18, 38, 64)),
			ColorSequenceKeypoint.new(0.45, Color3.fromRGB(10, 20, 36)),
			ColorSequenceKeypoint.new(1.0, Color3.fromRGB(5, 10, 20)),
		}),
		Rotation = 45,
	}, disc)

	-- Arcane Cyan Rim
	new("UIStroke", {
		Name = "CyanRim",
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(103, 232, 249),
		Thickness = 2.2,
	}, disc)

	-- Concentric Arcane Portal Rings
	local portalRoot = new("Frame", {
		Name = "PortalRoot",
		Size = UDim2.fromScale(0.70, 0.70),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = baseZ + 2,
	}, disc)

	-- Mid Arcane Ring
	local midRing = new("Frame", {
		Name = "MidRing",
		Size = UDim2.fromScale(0.82, 0.82),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = baseZ + 3,
	}, portalRoot)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, midRing)
	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(125, 211, 252),
		Thickness = 1.4,
		Transparency = 0.25,
	}, midRing)

	-- 4 Orbiting Arcane Rune Diamonds
	for _, angle in ipairs({ 0, 90, 180, 270 }) do
		local rad = math.rad(angle)
		local px = 0.5 + 0.41 * math.cos(rad)
		local py = 0.5 + 0.41 * math.sin(rad)
		local rune = new("Frame", {
			Name = "OrbitRune",
			Size = UDim2.fromScale(0.12, 0.12),
			Position = UDim2.fromScale(px, py),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(224, 242, 254),
			BorderSizePixel = 0,
			Rotation = angle + 45,
			ZIndex = baseZ + 4,
		}, portalRoot)
		new("UICorner", { CornerRadius = UDim.new(0, 1) }, rune)
	end

	-- Central Return Chevron / Sacred Arch
	local arch = new("Frame", {
		Name = "GatewayArch",
		Size = UDim2.fromScale(0.44, 0.44),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = baseZ + 5,
	}, portalRoot)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, arch)
	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(240, 249, 255),
		Thickness = 2.0,
	}, arch)

	-- Upward Sacred Beacon Arrow inside Portal
	local beacon = new("Frame", {
		Name = "RecallBeacon",
		Size = UDim2.fromScale(0.24, 0.24),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		Rotation = 45,
		ZIndex = baseZ + 6,
	}, arch)
	new("UICorner", { CornerRadius = UDim.new(0, 1) }, beacon)

	return root
end

--------------------------------------------------------------------------------
-- 7. TOWER MEDALLION (Vector Monolith Spire & Celestial Spire)
--------------------------------------------------------------------------------
function GothicVectorIcons.CreateTower(opts: IconOptions?): Frame
	local o = opts or {}
	local baseZ = o.ZIndex or 12

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
		Color = Color3.fromRGB(192, 132, 252),
		Thickness = 2.5,
		Transparency = 0.40,
	}, glow)

	-- Deep Astral Obsidian Disc
	local disc = new("Frame", {
		Name = "ObsidianDisc",
		Size = UDim2.fromScale(0.88, 0.88),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(26, 14, 36),
		BorderSizePixel = 0,
		ZIndex = baseZ + 1,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, disc)

	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(44, 22, 60)),
			ColorSequenceKeypoint.new(0.45, Color3.fromRGB(24, 12, 34)),
			ColorSequenceKeypoint.new(1.0, Color3.fromRGB(10, 5, 16)),
		}),
		Rotation = 45,
	}, disc)

	-- Mystic Amethyst Rim
	new("UIStroke", {
		Name = "AmethystRim",
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(216, 180, 254),
		Thickness = 2.2,
	}, disc)

	-- Vector Gothic Monolith Tower Spire
	local towerRoot = new("Frame", {
		Name = "MonolithRoot",
		Size = UDim2.fromScale(0.66, 0.66),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = baseZ + 2,
	}, disc)

	-- Plinth / Base Rampart
	local baseRampart = new("Frame", {
		Name = "BaseRampart",
		Size = UDim2.fromScale(0.70, 0.12),
		Position = UDim2.fromScale(0.5, 0.82),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(230, 215, 245),
		BorderSizePixel = 0,
		ZIndex = baseZ + 3,
	}, towerRoot)
	new("UICorner", { CornerRadius = UDim.new(0, 2) }, baseRampart)

	-- Tower Main Body (Tier 1)
	local tier1 = new("Frame", {
		Name = "Tier1",
		Size = UDim2.fromScale(0.48, 0.28),
		Position = UDim2.fromScale(0.5, 0.64),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(210, 190, 235),
		BorderSizePixel = 0,
		ZIndex = baseZ + 3,
	}, towerRoot)
	new("UICorner", { CornerRadius = UDim.new(0, 1) }, tier1)
	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(250, 245, 255),
		Thickness = 1.0,
	}, tier1)

	-- Tower Slit Window
	local slit = new("Frame", {
		Name = "SlitWindow",
		Size = UDim2.fromScale(0.18, 0.50),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(24, 12, 36),
		BorderSizePixel = 0,
		ZIndex = baseZ + 4,
	}, tier1)
	new("UICorner", { CornerRadius = UDim.new(0, 1) }, slit)

	-- Tower Upper Body (Tier 2)
	local tier2 = new("Frame", {
		Name = "Tier2",
		Size = UDim2.fromScale(0.32, 0.24),
		Position = UDim2.fromScale(0.5, 0.40),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(235, 220, 250),
		BorderSizePixel = 0,
		ZIndex = baseZ + 4,
	}, towerRoot)
	new("UICorner", { CornerRadius = UDim.new(0, 1) }, tier2)

	-- Spire Needle Peak
	local needle = new("Frame", {
		Name = "SpireNeedle",
		Size = UDim2.fromScale(0.12, 0.22),
		Position = UDim2.fromScale(0.5, 0.20),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		ZIndex = baseZ + 5,
	}, towerRoot)
	new("UICorner", { CornerRadius = UDim.new(0, 1) }, needle)

	-- Spire Apex Beacon Star (Glowing diamond floating at the pinnacle)
	local beacon = new("Frame", {
		Name = "ApexBeacon",
		Size = UDim2.fromScale(0.20, 0.20),
		Position = UDim2.fromScale(0.5, 0.08),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		Rotation = 45,
		ZIndex = baseZ + 6,
	}, towerRoot)
	new("UICorner", { CornerRadius = UDim.new(0, 1) }, beacon)
	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(245, 210, 255),
		Thickness = 1.2,
	}, beacon)

	return root
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
	else
		-- Fallback to gold or generic diamond
		return GothicVectorIcons.CreateGold(opts)
	end
end

return GothicVectorIcons
