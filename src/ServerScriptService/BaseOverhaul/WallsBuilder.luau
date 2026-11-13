--!strict
-- WallsBuilder.luau
-- ModuleScript: Builds the Gothic Medieval Fortification Walls & Spire Corner Towers around each Plot Island.
-- Supports both imported FBX MeshPart assets (ReplicatedStorage.Assets.PlotWalls) and a high-detail native
-- Roblox Part/WedgePart fallback matching the exact 4-module kit from Stage 1 (`Wall_Gothic_Straight`,
-- `Wall_Gothic_GateArch`, `Tower_Gothic_CornerSpire`, `Prop_Wall_Banner_And_Torch`).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PartKit = require(script.Parent:WaitForChild("PartKit"))
local makePart = PartKit.Part
local makeWedge = PartKit.Wedge

local WallsBuilder = {}

--============================================================================
-- CONFIGURATION TABLE
--============================================================================
WallsBuilder.Config = {
	-- Perimeter Dimensions (Compact Citadel & Courtyard: 160 x 120 studs)
	PerimeterWidth = 160,
	PerimeterLength = 120,

	-- Wall & Tower Geometry (Matching Stage 1 Modular Kit)
	WallHeight = 22,
	WallThickness = 6,
	BastionSize = 20,
	BastionHeight = 68,

	-- Crenellations (Merlons on top of the wall)
	MerlonWidth = 3.5,
	MerlonHeight = 2.4,
	MerlonSpacing = 6.0,

	-- Front Gate Opening (Facing the Tower, -Z local direction)
	IncludeFrontOpening = true,
	OpeningWidth = 14,
	OpeningArchHeight = 15,
	BlockOpeningWithInvisibleBarrier = false, -- Non-collidable so players walk across bridge into fortress

	-- Rear Gate Opening (Facing the Outskirts, +Z local direction, opening to forest trail)
	IncludeRearOpening = true,
	RearGateCenterX = 14,
	RearOpeningWidth = 14,
	RearOpeningArchHeight = 15,

	-- North Portcullis Alcove Gate (+X wall at Z = -20, matching image_8b03db.jpg top-left wall)
	IncludeNorthPortcullisGate = true,
	NorthGateCenterZ = -20,

	-- Invisible Backup Safety Barrier
	InvisibleBarrierHeight = 48,

	-- Materials & Colors (Exact Palette from Stage 1 / Section 3 of Implementation Plan)
	WallMaterial = Enum.Material.Slate,
	WallColor = Color3.fromHex("#3B4048"), -- M_DarkAshlarStone
	TrimMaterial = Enum.Material.Rock,
	TrimColor = Color3.fromHex("#4E555F"), -- M_WeatheredCapStone
	BastionColor = Color3.fromHex("#3B4048"),
	PlinthColor = Color3.fromHex("#4E555F"),
	MortarColor = Color3.fromHex("#1E2228"), -- M_DeepMortarRecess
	SpireRoofColor = Color3.fromHex("#232730"), -- M_SpireSlateRoof
	TimberColor = Color3.fromHex("#3A2618"), -- M_DarkGateTimber
	IronColor = Color3.fromHex("#181A1E"), -- M_WroughtIron
	CrimsonColor = Color3.fromHex("#7F1D1D"), -- M_CrimsonBanner
	GoldColor = Color3.fromHex("#D97706"), -- M_BannerGoldTrim
	EmberGlowColor = Color3.fromHex("#FF7A1A"), -- M_WindowEmberGlow
}

-- Exact colors & materials shortcuts
local C_STONE = Color3.fromHex("#3B4048")
local C_CAP = Color3.fromHex("#4E555F")
local C_MORTAR = Color3.fromHex("#1E2228")
local C_ROOF = Color3.fromHex("#232730")
local C_TIMBER = Color3.fromHex("#3A2618")
local C_IRON = Color3.fromHex("#181A1E")
local C_CRIMSON = Color3.fromHex("#7F1D1D")
local C_GOLD = Color3.fromHex("#D97706")
local C_GLOW = Color3.fromHex("#FF7A1A")

--============================================================================
-- HELPER FUNCTIONS: SOCKETS, TORCH VFX & BANNERS (STAGE 3 SPECS)
--============================================================================
local function getImportedWallAsset(assetName: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local plotWalls = assets and assets:FindFirstChild("PlotWalls")
	local found = plotWalls and plotWalls:FindFirstChild(assetName)
	if found and found:IsA("Model") then
		return found
	end
	return nil
end

local function createSocketPart(parent: Instance, name: string, cf: CFrame): Part
	return makePart({
		Name = name,
		Size = Vector3.new(0.4, 0.4, 0.4),
		CFrame = cf,
		Transparency = 1,
		Decorative = true,
		Parent = parent,
	})
end

-- Attaches the Stage 3 flickering PointLight + dual ParticleEmitters (Flame Core + Rising Sparks)
local function attachTorchLightAndVFX(emberCore: BasePart)
	local pt = Instance.new("PointLight")
	pt.Name = "WallTorchPointLight"
	pt.Color = Color3.fromRGB(255, 148, 56) -- #FF9438
	pt.Brightness = 2.2
	pt.Range = 22
	pt.Shadows = false
	pt.Parent = emberCore
	CollectionService:AddTag(pt, "WallTorchFlicker")

	local flameEmit = Instance.new("ParticleEmitter")
	flameEmit.Name = "TorchFlameCore"
	flameEmit.Texture = "rbxassetid://243660364"
	flameEmit.Color = ColorSequence.new(Color3.fromRGB(255, 220, 100), Color3.fromRGB(255, 90, 15))
	flameEmit.LightEmission = 1
	flameEmit.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(1, 0),
	})
	flameEmit.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	flameEmit.Lifetime = NumberRange.new(0.35, 0.6)
	flameEmit.Rate = 28
	flameEmit.EmissionDirection = Enum.NormalId.Top
	flameEmit.Speed = NumberRange.new(2.5, 4)
	flameEmit.Acceleration = Vector3.new(0, 4, 0)
	flameEmit.Parent = emberCore

	local sparkEmit = Instance.new("ParticleEmitter")
	sparkEmit.Name = "TorchRisingSparks"
	sparkEmit.Texture = "rbxassetid://243660364"
	sparkEmit.Color = ColorSequence.new(Color3.fromRGB(255, 195, 85), Color3.fromRGB(255, 95, 20))
	sparkEmit.LightEmission = 1
	sparkEmit.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkEmit.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparkEmit.Lifetime = NumberRange.new(0.75, 1.05)
	sparkEmit.Rate = 8
	sparkEmit.EmissionDirection = Enum.NormalId.Top
	sparkEmit.Speed = NumberRange.new(2.2, 3.8)
	sparkEmit.SpreadAngle = Vector2.new(18, 18)
	sparkEmit.Acceleration = Vector3.new(0, 4, 0)
	sparkEmit.Parent = emberCore
end

-- Module 4B: Wrought-Iron Wall Sconce + Pitch Torch + Ember Core + Stage 3 VFX
-- Socket CFrame has local -Z pointing into the courtyard (away from wall face at +Z).
local function spawnWallTorchAtSocket(parent: Instance, name: string, socketCF: CFrame)
	local imported = getImportedWallAsset("Prop_WallTorchSconce")
	if imported then
		local clone = imported:Clone()
		clone.Name = name
		clone:PivotTo(socketCF)
		clone.Parent = parent
		local core = clone:FindFirstChild("Prop_WallTorchSconce_Glow", true) :: BasePart?
			or clone.PrimaryPart
			or clone:FindFirstChildWhichIsA("BasePart", true)
		if core then
			core.Material = Enum.Material.Neon
			core.Color = C_GLOW
			attachTorchLightAndVFX(core)
		end
		return
	end

	local sconceModel = Instance.new("Model")
	sconceModel.Name = name
	sconceModel.Parent = parent

	-- Wall backplate (sits against the stone behind the socket along +Z)
	makePart({
		Name = "SconcePlate",
		Size = Vector3.new(0.7, 1.3, 0.14),
		CFrame = socketCF * CFrame.new(0, -1.1, 1.35),
		Material = Enum.Material.Metal,
		Color = C_IRON,
		Decorative = true,
		Parent = sconceModel,
	})
	-- Angled iron strut arm
	makePart({
		Name = "SconceArm",
		Size = Vector3.new(0.18, 0.18, 1.45),
		CFrame = socketCF * CFrame.new(0, -0.95, 0.68) * CFrame.Angles(math.rad(24), 0, 0),
		Material = Enum.Material.Metal,
		Color = C_IRON,
		Decorative = true,
		Parent = sconceModel,
	})
	-- Pitch-soaked timber torch shaft & iron cup ring
	makePart({
		Name = "TorchShaft",
		Size = Vector3.new(0.28, 1.65, 0.28),
		CFrame = socketCF * CFrame.new(0, -0.95, 0) * CFrame.Angles(math.rad(-14), 0, 0),
		Material = Enum.Material.WoodPlanks,
		Color = C_TIMBER,
		Decorative = true,
		Parent = sconceModel,
	})
	makePart({
		Name = "TorchCup",
		Size = Vector3.new(0.55, 0.38, 0.55),
		CFrame = socketCF * CFrame.new(0, -0.32, -0.12),
		Material = Enum.Material.Metal,
		Color = C_IRON,
		Decorative = true,
		Parent = sconceModel,
	})
	local emberCore = makePart({
		Name = "TorchEmberCore",
		Size = Vector3.new(0.46, 0.62, 0.46),
		CFrame = socketCF * CFrame.new(0, 0.12, -0.16),
		Material = Enum.Material.Neon,
		Color = C_GLOW,
		Transparency = 0.1,
		Decorative = true,
		Parent = sconceModel,
	})
	attachTorchLightAndVFX(emberCore)
end

-- Module 4A: Medieval Heraldic Banner (`2.8W x 7.5H`) mounted at BannerSocket
local function spawnWallBannerAtSocket(parent: Instance, name: string, socketCF: CFrame)
	local imported = getImportedWallAsset("Prop_WallBanner")
	if imported then
		local clone = imported:Clone()
		clone.Name = name
		clone:PivotTo(socketCF)
		clone.Parent = parent
		return
	end

	local bannerModel = Instance.new("Model")
	bannerModel.Name = name
	bannerModel.Parent = parent

	-- Top wrought-iron crossbar & finials
	makePart({
		Name = "Crossbar",
		Size = Vector3.new(3.4, 0.22, 0.22),
		CFrame = socketCF * CFrame.new(0, -0.1, -0.32),
		Material = Enum.Material.Metal,
		Color = C_IRON,
		Decorative = true,
		Parent = bannerModel,
	})
	for _, s in ipairs({ -1, 1 }) do
		makePart({
			Name = "Finial",
			Size = Vector3.new(0.34, 0.34, 0.34),
			CFrame = socketCF * CFrame.new(s * 1.8, -0.1, -0.32),
			Material = Enum.Material.Metal,
			Color = C_IRON,
			Decorative = true,
			Parent = bannerModel,
		})
	end
	-- Gold trim backing plate
	makePart({
		Name = "GoldTrimBorder",
		Size = Vector3.new(2.8, 6.1, 0.08),
		CFrame = socketCF * CFrame.new(0, -3.3, -0.28),
		Material = Enum.Material.Metal,
		Color = C_GOLD,
		Decorative = true,
		Parent = bannerModel,
	})
	-- Main crimson tapestry cloth
	makePart({
		Name = "CrimsonTapestry",
		Size = Vector3.new(2.4, 5.85, 0.08),
		CFrame = socketCF * CFrame.new(0, -3.32, -0.34),
		Material = Enum.Material.Fabric,
		Color = C_CRIMSON,
		Decorative = true,
		Parent = bannerModel,
	})
	-- Pointed swallowtail / shield tip at the bottom
	for _, s in ipairs({ -1, 1 }) do
		makeWedge({
			Name = "BannerTipGold",
			Size = Vector3.new(0.08, 1.4, 1.4),
			CFrame = socketCF * CFrame.new(s * 0.7, -7.05, -0.28) * CFrame.Angles(0, math.rad(s * 90), math.rad(180)),
			Material = Enum.Material.Metal,
			Color = C_GOLD,
			Decorative = true,
			Parent = bannerModel,
		})
		makeWedge({
			Name = "BannerTipCrimson",
			Size = Vector3.new(0.08, 1.2, 1.2),
			CFrame = socketCF * CFrame.new(s * 0.6, -6.85, -0.34) * CFrame.Angles(0, math.rad(s * 90), math.rad(180)),
			Material = Enum.Material.Fabric,
			Color = C_CRIMSON,
			Decorative = true,
			Parent = bannerModel,
		})
	end
	-- Central gold heraldic emblem
	makePart({
		Name = "HeraldicEmblem",
		Size = Vector3.new(1.1, 1.4, 0.08),
		CFrame = socketCF * CFrame.new(0, -3.2, -0.40),
		Material = Enum.Material.Metal,
		Color = C_GOLD,
		Decorative = true,
		Parent = bannerModel,
	})
	makePart({
		Name = "TopGoldStripe",
		Size = Vector3.new(2.4, 0.22, 0.06),
		CFrame = socketCF * CFrame.new(0, -1.0, -0.39),
		Material = Enum.Material.Metal,
		Color = C_GOLD,
		Decorative = true,
		Parent = bannerModel,
	})
end

-- Helper to build chamfered stone merlon + cap block at module-local coordinates
local function addBevelledMerlon(parent: Instance, moduleCF: CFrame, x: number, yBase: number, z: number, width: number, height: number, depth: number)
	makePart({
		Name = "MerlonBody",
		Size = Vector3.new(width, height, depth),
		CFrame = moduleCF * CFrame.new(x, yBase + height * 0.5, z),
		Material = Enum.Material.Slate,
		Color = C_STONE,
		Decorative = true,
		Parent = parent,
	})
	makePart({
		Name = "MerlonCapSlab",
		Size = Vector3.new(width + 0.4, 0.55, depth + 0.4),
		CFrame = moduleCF * CFrame.new(x, yBase + height + 0.275, z),
		Material = Enum.Material.Rock,
		Color = C_CAP,
		Decorative = true,
		Parent = parent,
	})
	makePart({
		Name = "MerlonCapChamfer",
		Size = Vector3.new(width - 0.1, 0.28, depth - 0.1),
		CFrame = moduleCF * CFrame.new(x, yBase + height + 0.69, z),
		Material = Enum.Material.Rock,
		Color = C_CAP,
		Decorative = true,
		Parent = parent,
	})
end

--============================================================================
-- MODULE 1: `Wall_Gothic_Straight` (24W x 22H x 6D, scalable width `segWidth`)
-- Origin = bottom-center (0, 0, 0); -Z faces the interior courtyard.
--============================================================================
local function spawnGothicStraightWall(
	parent: Instance,
	name: string,
	moduleCF: CFrame,
	segWidth: number?,
	spawnTorch: boolean?,
	spawnBanners: boolean?
): Model
	local W = segWidth or 24
	local scaleX = W / 24.0

	local imported = getImportedWallAsset("Wall_Gothic_Straight")
	if imported and math.abs(W - 24) < 0.5 then
		local clone = imported:Clone()
		clone.Name = name
		clone:PivotTo(moduleCF)
		clone.Parent = parent
		if spawnTorch ~= false then
			spawnWallTorchAtSocket(clone, name .. "_Torch", moduleCF * CFrame.new(0, 9.5, -2.6))
		end
		if spawnBanners ~= false then
			spawnWallBannerAtSocket(clone, name .. "_BannerL", moduleCF * CFrame.new(-9, 13.5, -2.8))
			spawnWallBannerAtSocket(clone, name .. "_BannerR", moduleCF * CFrame.new(9, 13.5, -2.8))
		end
		return clone
	end

	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent

	-- 1. Stepped Plinth Base (Y = 0..3.5)
	makePart({
		Name = "PlinthLower",
		Size = Vector3.new(W, 1.5, 6.0),
		CFrame = moduleCF * CFrame.new(0, 0.75, 0),
		Material = Enum.Material.Rock,
		Color = C_CAP,
		Decorative = false,
		Parent = m,
	})
	makePart({
		Name = "PlinthUpper",
		Size = Vector3.new(W, 2.0, 5.4),
		CFrame = moduleCF * CFrame.new(0, 2.5, 0),
		Material = Enum.Material.Rock,
		Color = C_CAP,
		Decorative = false,
		Parent = m,
	})

	-- 2. Main Structural Wall Core Hull (CanCollide = true)
	makePart({
		Name = "WallCoreHull",
		Size = Vector3.new(W, 14.5, 3.0),
		CFrame = moduleCF * CFrame.new(0, 10.75, 0.4),
		Material = Enum.Material.Slate,
		Color = C_STONE,
		Decorative = false,
		Parent = m,
	})

	-- 3. Recessed Pointed Gothic Blind Arch Bay on Courtyard Face (-Z)
	-- Dark mortar recess backing
	makePart({
		Name = "ArchRecessBack",
		Size = Vector3.new(8.8 * scaleX, 12.6, 0.25),
		CFrame = moduleCF * CFrame.new(0, 10.0, -0.95),
		Material = Enum.Material.Slate,
		Color = C_MORTAR,
		Decorative = true,
		Parent = m,
	})
	-- Left & Right pier masonry framing the recessed arch
	local pierW = (W - 8.8 * scaleX) * 0.5
	local pierX = (8.8 * scaleX + pierW) * 0.5
	for _, s in ipairs({ -1, 1 }) do
		makePart({
			Name = s < 0 and "CourtyardPier_L" or "CourtyardPier_R",
			Size = Vector3.new(pierW, 13.5, 1.5),
			CFrame = moduleCF * CFrame.new(s * pierX, 10.25, -1.6),
			Material = Enum.Material.Slate,
			Color = C_STONE,
			Decorative = false,
			Parent = m,
		})
		-- Pointed Gothic Arch Spandrels (angled stone corbel wedges forming the pointed arch top)
		makeWedge({
			Name = "GothicArchSpandrel",
			Size = Vector3.new(1.5, 5.2, 4.4 * scaleX),
			CFrame = moduleCF * CFrame.new(s * 2.2 * scaleX, 13.6, -1.6) * CFrame.Angles(0, math.rad(s * 90), math.rad(180)),
			Material = Enum.Material.Slate,
			Color = C_STONE,
			Decorative = true,
			Parent = m,
		})
		-- Raised CapStone Arch Moulding & Jambs
		makePart({
			Name = "ArchJamb",
			Size = Vector3.new(0.75, 7.5, 0.35),
			CFrame = moduleCF * CFrame.new(s * 4.5 * scaleX, 7.25, -2.35),
			Material = Enum.Material.Rock,
			Color = C_CAP,
			Decorative = true,
			Parent = m,
		})
		makePart({
			Name = "ArchVoussoirSlope",
			Size = Vector3.new(0.75, 5.6, 0.4),
			CFrame = moduleCF * CFrame.new(s * 2.3 * scaleX, 13.2, -2.38) * CFrame.Angles(0, 0, math.rad(s * 38)),
			Material = Enum.Material.Rock,
			Color = C_CAP,
			Decorative = true,
			Parent = m,
		})
		-- Vertical Pilaster Buttress (Width = 3 studs)
		makePart({
			Name = "PilasterButtress",
			Size = Vector3.new(3.0 * scaleX, 13.5, 0.8),
			CFrame = moduleCF * CFrame.new(s * 9.0 * scaleX, 10.25, -2.5),
			Material = Enum.Material.Slate,
			Color = C_STONE,
			Decorative = false,
			Parent = m,
		})
		makePart({
			Name = "PilasterPlinthCap",
			Size = Vector3.new(3.6 * scaleX, 2.5, 1.0),
			CFrame = moduleCF * CFrame.new(s * 9.0 * scaleX, 4.75, -2.6),
			Material = Enum.Material.Rock,
			Color = C_CAP,
			Decorative = true,
			Parent = m,
		})
		-- Exterior Buttress & Ashlar Relief (+Z face)
		makePart({
			Name = "ExteriorPilaster",
			Size = Vector3.new(2.8 * scaleX, 13.5, 0.7),
			CFrame = moduleCF * CFrame.new(s * 9.0 * scaleX, 10.25, 2.25),
			Material = Enum.Material.Slate,
			Color = C_STONE,
			Decorative = true,
			Parent = m,
		})
	end
	-- Arch Keystone & Upper Spandrel Beam
	makePart({
		Name = "ArchSpandrelHeader",
		Size = Vector3.new(9.2 * scaleX, 1.2, 1.55),
		CFrame = moduleCF * CFrame.new(0, 16.4, -1.6),
		Material = Enum.Material.Slate,
		Color = C_STONE,
		Decorative = true,
		Parent = m,
	})
	makePart({
		Name = "ArchKeystone",
		Size = Vector3.new(0.95, 1.35, 0.48),
		CFrame = moduleCF * CFrame.new(0, 16.0, -2.45),
		Material = Enum.Material.Rock,
		Color = C_CAP,
		Decorative = true,
		Parent = m,
	})
	-- Exterior Glowing Gothic Lancet Slit (+Z face)
	makePart({
		Name = "ExteriorLancetGlow",
		Size = Vector3.new(1.3, 4.4, 0.2),
		CFrame = moduleCF * CFrame.new(0, 9.8, 1.92),
		Material = Enum.Material.Neon,
		Color = C_GLOW,
		Transparency = 0.15,
		Decorative = true,
		Parent = m,
	})

	-- 4. Walkable Upper Stone Rampart Walkway (Y = 18, Width = 4.5 studs) & Corbelled Cornices
	makePart({
		Name = "InnerCornice",
		Size = Vector3.new(W, 0.75, 1.0),
		CFrame = moduleCF * CFrame.new(0, 17.3, -2.55),
		Material = Enum.Material.Rock,
		Color = C_CAP,
		Decorative = true,
		Parent = m,
	})
	makePart({
		Name = "OuterCornice",
		Size = Vector3.new(W, 0.75, 1.0),
		CFrame = moduleCF * CFrame.new(0, 16.8, 2.45),
		Material = Enum.Material.Rock,
		Color = C_CAP,
		Decorative = true,
		Parent = m,
	})
	makePart({
		Name = "RampartMortarBed",
		Size = Vector3.new(W, 0.6, 4.5),
		CFrame = moduleCF * CFrame.new(0, 17.3, -0.65),
		Material = Enum.Material.Slate,
		Color = C_MORTAR,
		Decorative = false,
		Parent = m,
	})
	for _, fx in ipairs({ -9, -3, 3, 9 }) do
		makePart({
			Name = "RampartFlagstone",
			Size = Vector3.new(5.8 * scaleX, 0.4, 4.5),
			CFrame = moduleCF * CFrame.new(fx * scaleX, 17.8, -0.65),
			Material = Enum.Material.Rock,
			Color = C_CAP,
			Decorative = false,
			Parent = m,
		})
	end
	makePart({
		Name = "InnerRampartKerb",
		Size = Vector3.new(W, 0.65, 0.45),
		CFrame = moduleCF * CFrame.new(0, 18.3, -2.75),
		Material = Enum.Material.Rock,
		Color = C_CAP,
		Decorative = true,
		Parent = m,
	})

	-- 5. Outer Parapet & 4 Bevelled Stone Merlons (Y = 18..22)
	makePart({
		Name = "OuterParapetWall",
		Size = Vector3.new(W, 1.8, 1.4),
		CFrame = moduleCF * CFrame.new(0, 17.9, 2.2),
		Material = Enum.Material.Slate,
		Color = C_STONE,
		Decorative = false,
		Parent = m,
	})
	for _, mx in ipairs({ -9, -3, 3, 9 }) do
		addBevelledMerlon(m, moduleCF, mx * scaleX, 18.8, 2.2, 3.5 * scaleX, 2.4, 1.6)
	end
	for _, c in ipairs({ { -11.35, 1.2 }, { -6.0, 2.4 }, { 0.0, 2.4 }, { 6.0, 2.4 }, { 11.35, 1.2 } }) do
		makePart({
			Name = "CrenelCopingSlab",
			Size = Vector3.new(c[2] * scaleX, 0.45, 1.75),
			CFrame = moduleCF * CFrame.new(c[1] * scaleX, 19.0, 2.2),
			Material = Enum.Material.Rock,
			Color = C_CAP,
			Decorative = true,
			Parent = m,
		})
	end

	-- 6. Sockets + Dressed Wall Props (Torches & Banners)
	local torchCF = moduleCF * CFrame.new(0, 9.5, -2.6)
	local bannerLCF = moduleCF * CFrame.new(-9.0 * scaleX, 13.5, -2.8)
	local bannerRCF = moduleCF * CFrame.new(9.0 * scaleX, 13.5, -2.8)
	createSocketPart(m, "TorchSocket_Center", torchCF)
	createSocketPart(m, "BannerSocket_Left", bannerLCF)
	createSocketPart(m, "BannerSocket_Right", bannerRCF)

	if spawnTorch ~= false then
		spawnWallTorchAtSocket(m, name .. "_Torch", torchCF)
	end
	if spawnBanners ~= false then
		spawnWallBannerAtSocket(m, name .. "_BannerL", bannerLCF)
		spawnWallBannerAtSocket(m, name .. "_BannerR", bannerRCF)
	end

	return m
end

--============================================================================
-- MODULE 2: `Wall_Gothic_GateArch` (32W x 24H x 8D; 14W x 15H clear walkthrough)
-- Supports Variant A ("OpenDoors" for West Bridge & East Outskirts) and
-- Variant B ("PortcullisAlcove" for the North Wall Alcove Gate in image_8b03db.jpg).
--============================================================================
local function spawnGothicGateArch(
	parent: Instance,
	name: string,
	moduleCF: CFrame,
	variant: "OpenDoors" | "PortcullisAlcove",
	isMainFrontGate: boolean?
): (Model, BasePart)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent

	-- Always create `GateLintel` on the Front Gate so `BridgeBuilder.luau` finds `walls:FindFirstChild("GateLintel")`
	-- with `LookVector` pointing outward (-Z in island space) and `Position.Z == -57`.
	local lintel = makePart({
		Name = if isMainFrontGate then "GateLintel" else (name .. "_Lintel"),
		Size = Vector3.new(18, 6.5, 6.8),
		CFrame = moduleCF * CFrame.new(0, 18.25, 0) * CFrame.Angles(0, math.pi, 0),
		Material = Enum.Material.Slate,
		Color = C_STONE,
		Decorative = false,
		Parent = m,
	})

	local imported = getImportedWallAsset("Wall_Gothic_GateArch")
	if imported then
		local clone = imported:Clone()
		clone.Name = name .. "_Mesh"
		clone:PivotTo(moduleCF)
		clone.Parent = m

		local portcullis = clone:FindFirstChild("Gate_Portcullis", true)
		local stairs = clone:FindFirstChild("Gate_StairThreshold", true)
		local doorL = clone:FindFirstChild("Gate_Door_Left", true)
		local doorR = clone:FindFirstChild("Gate_Door_Right", true)

		if variant == "OpenDoors" then
			if portcullis then portcullis:Destroy() end
			if stairs then stairs:Destroy() end
			if doorL and doorL:IsA("Model") then
				doorL:PivotTo(moduleCF * CFrame.new(-7, 0, 0) * CFrame.Angles(0, math.rad(78), 0))
			end
			if doorR and doorR:IsA("Model") then
				doorR:PivotTo(moduleCF * CFrame.new(7, 0, 0) * CFrame.Angles(0, math.rad(-78), 0))
			end
		else
			if doorL then doorL:Destroy() end
			if doorR then doorR:Destroy() end
		end

		for _, sName in ipairs({ "TorchSocket_Left", "TorchSocket_Right", "TorchSocket_OuterLeft", "TorchSocket_OuterRight" }) do
			local sock = clone:FindFirstChild(sName, true)
			if sock and sock:IsA("BasePart") then
				spawnWallTorchAtSocket(m, name .. "_" .. sName, sock.CFrame)
			end
		end
		lintel.Transparency = 1
		return m, lintel
	end

	-- 1. Flanking Gate Piers & Stepped Plinths (14-stud wide clear opening in [-7, +7])
	for _, s in ipairs({ -1, 1 }) do
		makePart({
			Name = s < 0 and "GatePier_Left" or "GatePier_Right",
			Size = Vector3.new(9.0, 17.5, 6.8),
			CFrame = moduleCF * CFrame.new(s * 11.5, 8.75, 0),
			Material = Enum.Material.Slate,
			Color = C_STONE,
			Decorative = false,
			Parent = m,
		})
		makePart({
			Name = "GatePlinth",
			Size = Vector3.new(9.4, 3.2, 8.0),
			CFrame = moduleCF * CFrame.new(s * 11.5, 1.6, 0),
			Material = Enum.Material.Rock,
			Color = C_CAP,
			Decorative = false,
			Parent = m,
		})
		-- Twin Flanking Gate Buttresses (at X = ±14)
		makePart({
			Name = "GateButtressLower",
			Size = Vector3.new(4.0, 12.0, 8.2),
			CFrame = moduleCF * CFrame.new(s * 14.0, 6.0, 0),
			Material = Enum.Material.Slate,
			Color = C_STONE,
			Decorative = false,
			Parent = m,
		})
		makePart({
			Name = "GateButtressWeathering",
			Size = Vector3.new(4.3, 0.7, 8.5),
			CFrame = moduleCF * CFrame.new(s * 14.0, 12.35, 0),
			Material = Enum.Material.Rock,
			Color = C_CAP,
			Decorative = true,
			Parent = m,
		})
		makePart({
			Name = "GateButtressUpper",
			Size = Vector3.new(3.5, 5.2, 7.4),
			CFrame = moduleCF * CFrame.new(s * 14.0, 15.2, 0),
			Material = Enum.Material.Slate,
			Color = C_STONE,
			Decorative = false,
			Parent = m,
		})
		-- Pointed Gothic Arch Spandrels & Radial Stone Voussoirs (above Y = 11.5 so 14W x 15H stays clear)
		makeWedge({
			Name = "GateArchSpandrel",
			Size = Vector3.new(6.8, 4.2, 4.5),
			CFrame = moduleCF * CFrame.new(s * 4.75, 13.4, 0) * CFrame.Angles(0, math.rad(s * 90), math.rad(180)),
			Material = Enum.Material.Slate,
			Color = C_STONE,
			Decorative = true,
			Parent = m,
		})
		for _, faceZ in ipairs({ -3.55, 3.55 }) do
			makePart({
				Name = "GateArchVoussoir",
				Size = Vector3.new(1.1, 6.2, 0.55),
				CFrame = moduleCF * CFrame.new(s * 4.2, 13.0, faceZ) * CFrame.Angles(0, 0, math.rad(s * 42)),
				Material = Enum.Material.Rock,
				Color = C_CAP,
				Decorative = true,
				Parent = m,
			})
			makePart({
				Name = "GateArchJamb",
				Size = Vector3.new(1.1, 10.5, 0.5),
				CFrame = moduleCF * CFrame.new(s * 7.35, 5.25, faceZ),
				Material = Enum.Material.Rock,
				Color = C_CAP,
				Decorative = true,
				Parent = m,
			})
		end
	end

	-- Raised Arch Keystones on both faces
	for _, faceZ in ipairs({ -3.7, 3.7 }) do
		makePart({
			Name = "GateKeystone",
			Size = Vector3.new(1.35, 1.85, 0.65),
			CFrame = moduleCF * CFrame.new(0, 15.8, faceZ),
			Material = Enum.Material.Rock,
			Color = C_CAP,
			Decorative = true,
			Parent = m,
		})
	end

	-- 2. Gatehouse Upper Walkway, Raised Crest Panel & Double-Merlon Crown (Y = 18..24)
	makePart({
		Name = "GateWalkwaySlab",
		Size = Vector3.new(32, 0.9, 7.6),
		CFrame = moduleCF * CFrame.new(0, 17.8, 0),
		Material = Enum.Material.Rock,
		Color = C_CAP,
		Decorative = false,
		Parent = m,
	})
	makePart({
		Name = "GateCrestPanel",
		Size = Vector3.new(8.4, 3.4, 0.9),
		CFrame = moduleCF * CFrame.new(0, 19.6, -3.55),
		Material = Enum.Material.Slate,
		Color = C_STONE,
		Decorative = true,
		Parent = m,
	})
	makePart({
		Name = "GateCrestCap",
		Size = Vector3.new(9.0, 0.5, 1.2),
		CFrame = moduleCF * CFrame.new(0, 21.5, -3.55),
		Material = Enum.Material.Rock,
		Color = C_CAP,
		Decorative = true,
		Parent = m,
	})
	-- Glowing Crimson & Gold Crest Shield at the Gate Apex (`#B91C1C` / `#7F1D1D`)
	makePart({
		Name = "GateCrestShieldGold",
		Size = Vector3.new(2.7, 2.9, 0.22),
		CFrame = moduleCF * CFrame.new(0, 19.6, -4.05),
		Material = Enum.Material.Metal,
		Color = C_GOLD,
		Decorative = true,
		Parent = m,
	})
	makePart({
		Name = "GateCrestShieldCrimson",
		Size = Vector3.new(2.2, 2.4, 0.24),
		CFrame = moduleCF * CFrame.new(0, 19.6, -4.14),
		Material = Enum.Material.Neon,
		Color = Color3.fromHex("#B91C1C"),
		Transparency = 0.12,
		Decorative = true,
		Parent = m,
	})
	-- Outer Gatehouse Parapet + Raised Double-Merlon Crown
	makePart({
		Name = "GateOuterParapet",
		Size = Vector3.new(32, 1.8, 1.6),
		CFrame = moduleCF * CFrame.new(0, 18.8, 2.9),
		Material = Enum.Material.Slate,
		Color = C_STONE,
		Decorative = true,
		Parent = m,
	})
	makePart({
		Name = "GateCrownRiser",
		Size = Vector3.new(10.5, 2.4, 1.6),
		CFrame = moduleCF * CFrame.new(0, 20.6, 2.9),
		Material = Enum.Material.Slate,
		Color = C_STONE,
		Decorative = true,
		Parent = m,
	})
	addBevelledMerlon(m, moduleCF, -3.0, 21.6, 2.9, 3.2, 1.8, 1.6)
	addBevelledMerlon(m, moduleCF, 3.0, 21.6, 2.9, 3.2, 1.8, 1.6)
	for _, s in ipairs({ -1, 1 }) do
		addBevelledMerlon(m, moduleCF, s * 8.4, 19.6, 2.9, 3.5, 2.2, 1.6)
		addBevelledMerlon(m, moduleCF, s * 13.6, 19.6, 2.9, 3.5, 2.2, 1.6)
	end

	-- 3. Variant-Specific Doors vs. Iron Portcullis + 4-Step Threshold
	if variant == "OpenDoors" then
		-- Variant A: Heavy Timber & Wrought-Iron Double Doors swung open 80° into the courtyard
		for _, s in ipairs({ -1, 1 }) do
			local hingeCF = moduleCF * CFrame.new(s * 6.8, 0, -0.4) * CFrame.Angles(0, math.rad(s * 78), 0)
			local leafX = -s * 3.2
			makePart({
				Name = s < 0 and "Gate_Door_Left" or "Gate_Door_Right",
				Size = Vector3.new(6.4, 13.6, 0.65),
				CFrame = hingeCF * CFrame.new(leafX, 6.9, 0),
				Material = Enum.Material.WoodPlanks,
				Color = C_TIMBER,
				Decorative = true,
				Parent = m,
			})
			for _, sy in ipairs({ 2.4, 6.8, 11.2 }) do
				makePart({
					Name = "DoorIronStrap",
					Size = Vector3.new(6.2, 0.45, 0.78),
					CFrame = hingeCF * CFrame.new(leafX, sy, 0),
					Material = Enum.Material.Metal,
					Color = C_IRON,
					Decorative = true,
					Parent = m,
				})
			end
		end
	else
		-- Variant B (North Wall Alcove Gate): Backing dark recess wall, iron portcullis grate, and 4-step stone stair threshold
		makePart({
			Name = "PortcullisAlcoveBack",
			Size = Vector3.new(15.2, 16.0, 0.8),
			CFrame = moduleCF * CFrame.new(0, 8.0, 2.2),
			Material = Enum.Material.Slate,
			Color = C_MORTAR,
			Decorative = false,
			Parent = m,
		})
		for i = -5, 5 do
			makePart({
				Name = "PortcullisBarV",
				Size = Vector3.new(0.32, 14.5, 0.32),
				CFrame = moduleCF * CFrame.new(i * 1.22, 7.25, -1.6),
				Material = Enum.Material.Metal,
				Color = C_IRON,
				Decorative = false,
				Parent = m,
			})
		end
		for _, py in ipairs({ 2.0, 4.8, 7.6, 10.4, 13.0 }) do
			makePart({
				Name = "PortcullisBarH",
				Size = Vector3.new(13.8, 0.30, 0.42),
				CFrame = moduleCF * CFrame.new(0, py, -1.6),
				Material = Enum.Material.Metal,
				Color = C_IRON,
				Decorative = true,
				Parent = m,
			})
		end
		-- 4-Step Stone Stair Threshold projecting into the courtyard
		for step = 1, 4 do
			local stepH = step * 0.42
			local zFar = -7.2 + (step - 1) * 1.15
			local depth = -2.2 - zFar
			makePart({
				Name = "AlcoveStep_" .. step,
				Size = Vector3.new(12.8 - step * 0.45, stepH, depth),
				CFrame = moduleCF * CFrame.new(0, stepH * 0.5, (zFar - 2.2) * 0.5),
				Material = Enum.Material.Rock,
				Color = C_CAP,
				Decorative = false,
				Parent = m,
			})
		end
	end

	-- 4. Flanking Torches on Gate Piers (Interior + Exterior for OpenDoors, Interior for Alcove)
	for _, s in ipairs({ -1, 1 }) do
		local inCF = moduleCF * CFrame.new(s * 10.6, 10.5, -4.1)
		spawnWallTorchAtSocket(m, string.format("%s_TorchIn_%d", name, s), inCF)
		if variant == "OpenDoors" then
			local outCF = moduleCF * CFrame.new(s * 10.6, 10.5, 4.1) * CFrame.Angles(0, math.pi, 0)
			spawnWallTorchAtSocket(m, string.format("%s_TorchOut_%d", name, s), outCF)
		end
	end

	return m, lintel
end

--============================================================================
-- MODULE 3: `Tower_Gothic_CornerSpire` (20W x 68H x 20D)
-- Matches `image_8b0bda.png` & `image_8b03db.jpg`:
--   1. Stepped Fortress Base (Y = 0..22) with 5 exterior steps & rampart doorways at Y = 18
--   2. Square Gothic Shaft (Y = 22..44) with quoins & 4 glowing Y-tracery lancet windows
--   3. Corbelled Machicolation & Parapet Crown (Y = 44..48)
--   4. Steep Central Spire + 4 Corner Turret Pinnacles (Y = 48..68)
--============================================================================
local function spawnGothicCornerSpireTower(parent: Instance, name: string, towerCF: CFrame): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent

	-- Apply Stage 3 Tower Window & Rampart Arch PointLights
	local function addTowerSocketsAndLights(targetModel: Instance)
		local windowDirs = {
			{ Name = "VFX_TowerWindow_N", Pos = Vector3.new(0, 33, -8.5) },
			{ Name = "VFX_TowerWindow_S", Pos = Vector3.new(0, 33, 8.5) },
			{ Name = "VFX_TowerWindow_E", Pos = Vector3.new(8.5, 33, 0) },
			{ Name = "VFX_TowerWindow_W", Pos = Vector3.new(-8.5, 33, 0) },
		}
		for _, w in ipairs(windowDirs) do
			local sock = createSocketPart(targetModel, w.Name, towerCF * CFrame.new(w.Pos))
			local pt = Instance.new("PointLight")
			pt.Name = "TowerLancetLight"
			pt.Color = Color3.fromRGB(255, 125, 40)
			pt.Brightness = 1.8
			pt.Range = 26
			pt.Shadows = false
			pt.Parent = sock
		end
		local rampartSock = createSocketPart(targetModel, "VFX_RampartArch_Glow", towerCF * CFrame.new(0, 20, 0))
		local rLight = Instance.new("PointLight")
		rLight.Name = "RampartArchLight"
		rLight.Color = Color3.fromRGB(255, 125, 40)
		rLight.Brightness = 1.8
		rLight.Range = 26
		rLight.Shadows = false
		rLight.Parent = rampartSock
	end

	local imported = getImportedWallAsset("Tower_Gothic_CornerSpire")
	if imported then
		local clone = imported:Clone()
		clone.Name = name .. "_Mesh"
		clone:PivotTo(towerCF)
		clone.Parent = m
		for _, desc in ipairs(clone:GetDescendants()) do
			if desc:IsA("BasePart") and string.find(desc.Name, "Glow") then
				desc.Material = Enum.Material.Neon
				desc.Color = Color3.fromRGB(255, 122, 26)
				desc.Transparency = 0.15
			end
		end
		addTowerSocketsAndLights(m)
		return m
	end

	-- 1. Stepped Fortress Base (Y = 0..18) with 5 wrap-around exterior stone steps
	for i = 0, 4 do
		local s = 20.4 - i * 0.55
		makePart({
			Name = "BastionBaseStep_" .. (i + 1),
			Size = Vector3.new(s, 0.8, s),
			CFrame = towerCF * CFrame.new(0, i * 0.8 + 0.4, 0),
			Material = Enum.Material.Rock,
			Color = C_CAP,
			Decorative = false,
			Parent = m,
		})
	end
	makePart({
		Name = "BastionLowerCore",
		Size = Vector3.new(18.0, 14.0, 18.0),
		CFrame = towerCF * CFrame.new(0, 11.0, 0),
		Material = Enum.Material.Slate,
		Color = C_STONE,
		Decorative = false,
		Parent = m,
	})
	makePart({
		Name = "BastionRampartBelt",
		Size = Vector3.new(18.8, 0.6, 18.8),
		CFrame = towerCF * CFrame.new(0, 17.8, 0),
		Material = Enum.Material.Rock,
		Color = C_CAP,
		Decorative = false,
		Parent = m,
	})

	-- 2. Rampart Chamber (Y = 18..24) with 4 Arched Doorways & Internal Warm Glow
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		makePart({
			Name = "RampartCornerPier",
			Size = Vector3.new(5.2, 6.2, 5.2),
			CFrame = towerCF * CFrame.new(c[1] * 6.4, 21.1, c[2] * 6.4),
			Material = Enum.Material.Slate,
			Color = C_STONE,
			Decorative = false,
			Parent = m,
		})
	end
	makePart({
		Name = "RampartInnerGlowCore",
		Size = Vector3.new(9.5, 4.8, 9.5),
		CFrame = towerCF * CFrame.new(0, 20.6, 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 122, 26),
		Transparency = 0.2,
		Decorative = true,
		Parent = m,
	})
	for k = 0, 3 do
		local faceCF = towerCF * CFrame.Angles(0, k * math.pi * 0.5, 0)
		makePart({
			Name = "RampartArchHeader",
			Size = Vector3.new(8.0, 1.8, 2.2),
			CFrame = faceCF * CFrame.new(0, 23.3, 7.9),
			Material = Enum.Material.Rock,
			Color = C_CAP,
			Decorative = true,
			Parent = m,
		})
		for _, s in ipairs({ -1, 1 }) do
			makeWedge({
				Name = "RampartArchWedge",
				Size = Vector3.new(2.2, 2.2, 2.2),
				CFrame = faceCF * CFrame.new(s * 2.1, 21.5, 7.9) * CFrame.Angles(0, math.rad(s * 90), math.rad(180)),
				Material = Enum.Material.Rock,
				Color = C_CAP,
				Decorative = true,
				Parent = m,
			})
		end
	end
	makePart({
		Name = "BastionShaftBelt",
		Size = Vector3.new(19.0, 0.7, 19.0),
		CFrame = towerCF * CFrame.new(0, 24.35, 0),
		Material = Enum.Material.Rock,
		Color = C_CAP,
		Decorative = true,
		Parent = m,
	})

	-- 3. Square Gothic Basha Shaft (Y = 24.5..44) with Corner Quoins & 4 Tall Y-Tracery Lancet Windows
	makePart({
		Name = "GothicShaftCore",
		Size = Vector3.new(14.8, 19.5, 14.8),
		CFrame = towerCF * CFrame.new(0, 34.25, 0),
		Material = Enum.Material.Slate,
		Color = C_STONE,
		Decorative = false,
		Parent = m,
	})
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		makePart({
			Name = "ShaftCornerButtress",
			Size = Vector3.new(3.2, 19.5, 3.2),
			CFrame = towerCF * CFrame.new(c[1] * 7.8, 34.25, c[2] * 7.8),
			Material = Enum.Material.Slate,
			Color = C_STONE,
			Decorative = true,
			Parent = m,
		})
		for q = 0, 4 do
			local qs = (q % 2 == 0) and 3.55 or 3.35
			makePart({
				Name = "CornerQuoinBlock",
				Size = Vector3.new(qs, 1.15, qs),
				CFrame = towerCF * CFrame.new(c[1] * 7.8, 26.2 + q * 3.8, c[2] * 7.8),
				Material = Enum.Material.Rock,
				Color = C_CAP,
				Decorative = true,
				Parent = m,
			})
		end
	end

	-- 4 Gothic Lancet Windows with Emissive Glass Backing & Y-Tracery Stone Mullions
	for k = 0, 3 do
		local faceCF = towerCF * CFrame.Angles(0, k * math.pi * 0.5, 0)
		-- Recessed glowing amber glass pane (`Enum.Material.Neon`, `#FF7A1A`, `Transparency = 0.15`)
		makePart({
			Name = "TowerWindowGlass_Neon",
			Size = Vector3.new(4.4, 9.6, 0.25),
			CFrame = faceCF * CFrame.new(0, 32.8, 7.35),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 122, 26),
			Transparency = 0.15,
			Decorative = true,
			Parent = m,
		})
		-- Window Sill & Jambs
		makePart({
			Name = "LancetSill",
			Size = Vector3.new(5.6, 0.5, 1.2),
			CFrame = faceCF * CFrame.new(0, 27.8, 7.8),
			Material = Enum.Material.Rock,
			Color = C_CAP,
			Decorative = true,
			Parent = m,
		})
		for _, s in ipairs({ -1, 1 }) do
			makePart({
				Name = "LancetJamb",
				Size = Vector3.new(0.65, 9.8, 0.9),
				CFrame = faceCF * CFrame.new(s * 2.4, 32.9, 7.65),
				Material = Enum.Material.Rock,
				Color = C_CAP,
				Decorative = true,
				Parent = m,
			})
			makePart({
				Name = "LancetArchHood",
				Size = Vector3.new(0.65, 3.2, 0.95),
				CFrame = faceCF * CFrame.new(s * 1.2, 36.8, 7.7) * CFrame.Angles(0, 0, math.rad(s * 36)),
				Material = Enum.Material.Rock,
				Color = C_CAP,
				Decorative = true,
				Parent = m,
			})
			-- Y-Tracery Fork Bars
			makePart({
				Name = "LancetYTraceryFork",
				Size = Vector3.new(0.34, 2.4, 0.45),
				CFrame = faceCF * CFrame.new(s * 0.85, 34.9, 7.55) * CFrame.Angles(0, 0, math.rad(s * 34)),
				Material = Enum.Material.Rock,
				Color = C_CAP,
				Decorative = true,
				Parent = m,
			})
		end
		-- Central Y-Tracery Mullion & Rose Trefoil Ring
		makePart({
			Name = "LancetCenterMullion",
			Size = Vector3.new(0.38, 6.4, 0.48),
			CFrame = faceCF * CFrame.new(0, 31.2, 7.55),
			Material = Enum.Material.Rock,
			Color = C_CAP,
			Decorative = true,
			Parent = m,
		})
		makePart({
			Name = "LancetRoseRing",
			Size = Vector3.new(1.15, 1.15, 0.48),
			CFrame = faceCF * CFrame.new(0, 36.0, 7.55) * CFrame.Angles(0, 0, math.rad(45)),
			Material = Enum.Material.Rock,
			Color = C_CAP,
			Decorative = true,
			Parent = m,
		})

		-- 4. Corbelled Machicolation & Parapet Crown (Y = 44..48)
		makePart({
			Name = "MachicolationShadowRecess",
			Size = Vector3.new(13.6, 1.6, 0.3),
			CFrame = faceCF * CFrame.new(0, 43.4, 7.5),
			Material = Enum.Material.Slate,
			Color = C_MORTAR,
			Decorative = true,
			Parent = m,
		})
		for _, cx in ipairs({ -5.2, -2.6, 0.0, 2.6, 5.2 }) do
			makePart({
				Name = "MachicolationCorbel",
				Size = Vector3.new(1.05, 1.7, 1.4),
				CFrame = faceCF * CFrame.new(cx, 43.4, 8.2),
				Material = Enum.Material.Rock,
				Color = C_CAP,
				Decorative = true,
				Parent = m,
			})
		end
		makePart({
			Name = "TowerCrownParapet",
			Size = Vector3.new(20.0, 1.6, 1.2),
			CFrame = faceCF * CFrame.new(0, 46.0, 9.4),
			Material = Enum.Material.Slate,
			Color = C_STONE,
			Decorative = true,
			Parent = m,
		})
		for _, mx in ipairs({ -4.6, 0.0, 4.6 }) do
			addBevelledMerlon(m, faceCF, mx, 46.8, 9.4, 2.4, 1.2, 1.3)
		end
	end

	makePart({
		Name = "TowerCrownDeck",
		Size = Vector3.new(20.2, 1.0, 20.2),
		CFrame = towerCF * CFrame.new(0, 44.7, 0),
		Material = Enum.Material.Rock,
		Color = C_CAP,
		Decorative = true,
		Parent = m,
	})

	-- 5. Steep Central Spire + 4 Corner Turret Pinnacles (Y = 45.2..68, CanCollide = false)
	local spireBaseY = 45.2
	local spireHeight = 21.0
	local spireTiers = 5
	for t = 0, spireTiers - 1 do
		local y0 = spireBaseY + (spireHeight * t / spireTiers)
		local tierH = spireHeight / spireTiers
		local w0 = 13.6 * (1 - t / spireTiers)
		-- Shingle tier rib collar
		makePart({
			Name = "SpireShingleRib_" .. (t + 1),
			Size = Vector3.new(w0 + 0.45, 0.35, w0 + 0.45),
			CFrame = towerCF * CFrame.new(0, y0 + 0.18, 0),
			Material = Enum.Material.Slate,
			Color = C_ROOF,
			Decorative = true,
			Parent = m,
		})
		for k = 0, 3 do
			local slopeCF = towerCF * CFrame.Angles(0, k * math.pi * 0.5, 0)
			makeWedge({
				Name = "CentralSpireSlope",
				Size = Vector3.new(w0, tierH + 0.2, w0 * 0.5),
				CFrame = slopeCF * CFrame.new(0, y0 + tierH * 0.5, w0 * 0.25),
				Material = Enum.Material.Slate,
				Color = C_ROOF,
				Decorative = true,
				Parent = m,
			})
		end
	end
	-- Spire Iron Finial Tip (Y = 66..68)
	makePart({
		Name = "SpireIronFinial",
		Size = Vector3.new(0.55, 2.4, 0.55),
		CFrame = towerCF * CFrame.new(0, 67.0, 0),
		Material = Enum.Material.Metal,
		Color = C_IRON,
		Decorative = true,
		Parent = m,
	})

	-- 4 Slender Corner Turret Pinnacles with Needle Spires (at X/Z = ±8.9)
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		local px, pz = c[1] * 8.9, c[2] * 8.9
		makePart({
			Name = "CornerPinnacleShaft",
			Size = Vector3.new(2.0, 7.4, 2.0),
			CFrame = towerCF * CFrame.new(px, 48.9, pz),
			Material = Enum.Material.Slate,
			Color = C_STONE,
			Decorative = true,
			Parent = m,
		})
		makePart({
			Name = "CornerPinnacleCap",
			Size = Vector3.new(2.4, 0.6, 2.4),
			CFrame = towerCF * CFrame.new(px, 52.8, pz),
			Material = Enum.Material.Rock,
			Color = C_CAP,
			Decorative = true,
			Parent = m,
		})
		for k = 0, 3 do
			local pCF = towerCF * CFrame.new(px, 0, pz) * CFrame.Angles(0, k * math.pi * 0.5, 0)
			makeWedge({
				Name = "CornerPinnacleNeedle",
				Size = Vector3.new(2.1, 7.4, 1.05),
				CFrame = pCF * CFrame.new(0, 56.8, 0.525),
				Material = Enum.Material.Slate,
				Color = C_ROOF,
				Decorative = true,
				Parent = m,
			})
		end
		makePart({
			Name = "CornerPinnacleFinial",
			Size = Vector3.new(0.28, 1.6, 0.28),
			CFrame = towerCF * CFrame.new(px, 61.1, pz),
			Material = Enum.Material.Metal,
			Color = C_IRON,
			Decorative = true,
			Parent = m,
		})
	end

	addTowerSocketsAndLights(m)
	return m
end

--============================================================================
-- STAGE 3 STEP 2.4: EXTERIOR PERIMETER PROPS (SCAFFOLDING, CRATES & BARRELS)
-- Placed along the outer West (-Z) and South (-X) wall ledges (`CanCollide = false`).
--============================================================================
local function buildExteriorPerimeterProps(parent: Instance, halfW: number, halfL: number)
	local propsFolder = Instance.new("Folder")
	propsFolder.Name = "ExteriorPerimeterProps"
	propsFolder.Parent = parent

	local function buildScaffoldingFrame(name: string, baseCF: CFrame)
		local sModel = Instance.new("Model")
		sModel.Name = name
		sModel.Parent = propsFolder
		-- 4 vertical timber posts
		for _, sx in ipairs({ -3.6, 3.6 }) do
			for _, sz in ipairs({ -1.4, 1.4 }) do
				makePart({
					Name = "ScaffoldPost",
					Size = Vector3.new(0.45, 9.5, 0.45),
					CFrame = baseCF * CFrame.new(sx, 4.75, sz),
					Material = Enum.Material.WoodPlanks,
					Color = C_TIMBER,
					Decorative = true,
					Parent = sModel,
				})
			end
		end
		-- Upper plank platform & cross-braces
		makePart({
			Name = "ScaffoldPlatform",
			Size = Vector3.new(8.2, 0.35, 3.4),
			CFrame = baseCF * CFrame.new(0, 7.2, 0),
			Material = Enum.Material.WoodPlanks,
			Color = Color3.fromRGB(96, 66, 42),
			Decorative = true,
			Parent = sModel,
		})
		makePart({
			Name = "ScaffoldCrossBrace",
			Size = Vector3.new(7.8, 0.28, 0.28),
			CFrame = baseCF * CFrame.new(0, 4.0, -1.4) * CFrame.Angles(0, 0, math.rad(28)),
			Material = Enum.Material.WoodPlanks,
			Color = C_TIMBER,
			Decorative = true,
			Parent = sModel,
		})
	end

	local function buildCrateAndBarrelCluster(name: string, baseCF: CFrame)
		local cModel = Instance.new("Model")
		cModel.Name = name
		cModel.Parent = propsFolder
		makePart({
			Name = "SupplyCrateLarge",
			Size = Vector3.new(3.2, 3.2, 3.2),
			CFrame = baseCF * CFrame.new(-1.6, 1.6, 0) * CFrame.Angles(0, math.rad(14), 0),
			Material = Enum.Material.WoodPlanks,
			Color = Color3.fromRGB(112, 76, 46),
			Decorative = true,
			Parent = cModel,
		})
		makePart({
			Name = "SupplyCrateSmall",
			Size = Vector3.new(2.4, 2.4, 2.4),
			CFrame = baseCF * CFrame.new(-1.4, 4.4, 0.2) * CFrame.Angles(0, math.rad(-22), 0),
			Material = Enum.Material.WoodPlanks,
			Color = Color3.fromRGB(124, 86, 52),
			Decorative = true,
			Parent = cModel,
		})
		local barrel = makePart({
			Name = "SupplyBarrel",
			Size = Vector3.new(3.0, 2.2, 2.2),
			CFrame = baseCF * CFrame.new(1.8, 1.5, 0.4) * CFrame.Angles(0, 0, math.pi * 0.5),
			Material = Enum.Material.WoodPlanks,
			Color = Color3.fromRGB(92, 62, 38),
			Decorative = true,
			Parent = cModel,
		})
		barrel.Shape = Enum.PartType.Cylinder
	end

	-- Outer South Wall (-X = -77) scaffolding & supply clusters (matching foreground of image_8b03db.jpg)
	buildScaffoldingFrame("SouthLedgeScaffold_1", CFrame.new(-halfW - 4.4, 0, -24) * CFrame.Angles(0, math.pi * 0.5, 0))
	buildScaffoldingFrame("SouthLedgeScaffold_2", CFrame.new(-halfW - 4.4, 0, 24) * CFrame.Angles(0, math.pi * 0.5, 0))
	buildCrateAndBarrelCluster("SouthLedgeCrates_1", CFrame.new(-halfW - 4.2, 0, -6) * CFrame.Angles(0, math.pi * 0.5, 0))
	buildCrateAndBarrelCluster("SouthLedgeCrates_2", CFrame.new(-halfW - 4.2, 0, 40) * CFrame.Angles(0, math.pi * 0.5, 0))

	-- Outer West Bridge Wall (-Z = -57) supply clusters & scaffolding flanking the bridge gate
	buildScaffoldingFrame("WestLedgeScaffold_L", CFrame.new(-42, 0, -halfL - 4.4))
	buildCrateAndBarrelCluster("WestLedgeCrates_L", CFrame.new(-24, 0, -halfL - 4.2))
	buildCrateAndBarrelCluster("WestLedgeCrates_R", CFrame.new(24, 0, -halfL - 4.2))
end

--============================================================================
-- MAIN PERIMETER BUILDER
--============================================================================
function WallsBuilder.Build(parentIsland: Instance?, customConfig: { [string]: any }?): Model
	local cfg = table.clone(WallsBuilder.Config)
	if customConfig then
		for k, v in pairs(customConfig) do
			(cfg :: any)[k] = v
		end
	end

	local wallsModel = Instance.new("Model")
	wallsModel.Name = "FortressWalls"

	local halfW = cfg.PerimeterWidth * 0.5 - (cfg.WallThickness * 0.5) -- 77
	local halfL = cfg.PerimeterLength * 0.5 - (cfg.WallThickness * 0.5) -- 57

	-- 1. Four Spire Corner Bastion Towers (`Tower_Gothic_CornerSpire` at (±77, 0, ±57))
	local corners = {
		{ Name = "CornerSpire_NW", Pos = Vector3.new(halfW, 0, -halfL), Yaw = 0 },
		{ Name = "CornerSpire_NE", Pos = Vector3.new(halfW, 0, halfL), Yaw = math.pi * 0.5 },
		{ Name = "CornerSpire_SW", Pos = Vector3.new(-halfW, 0, -halfL), Yaw = -math.pi * 0.5 },
		{ Name = "CornerSpire_SE", Pos = Vector3.new(-halfW, 0, halfL), Yaw = math.pi },
	}
	for _, c in ipairs(corners) do
		spawnGothicCornerSpireTower(wallsModel, c.Name, CFrame.new(c.Pos) * CFrame.Angles(0, c.Yaw, 0))
	end

	-- 2. West Front Wall (-Z = -57, facing the Central Tower and Bridge)
	--    Center `Wall_Gothic_GateArch` (32W) at X = 0, flanked by 2 straight bays (26W each) on Left and Right.
	--    Inside of wall faces +Z (courtyard), so module Yaw = math.pi (making local -Z point toward +Z).
	local westRot = CFrame.Angles(0, math.pi, 0)
	spawnGothicGateArch(wallsModel, "WestBridgeGateArch", CFrame.new(0, 0, -halfL) * westRot, "OpenDoors", true)
	for _, bx in ipairs({ -55, -29, 29, 55 }) do
		spawnGothicStraightWall(
			wallsModel,
			string.format("Wall_West_Bay_%d", bx),
			CFrame.new(bx, 0, -halfL) * westRot,
			26,
			true,
			true
		)
	end

	-- 3. East Outskirts Dividing Wall (+Z = +57, separating Courtyard from Forested Outskirts)
	--    `Wall_Gothic_GateArch` (32W) centered at X = RearGateCenterX (14), spanning [-2, +30].
	--    Left of gate [-68, -2] = 66 studs -> 3 straight bays of 22W at X = -57, -35, -13.
	--    Right of gate [+30, +68] = 38 studs -> 2 straight bays of 19W at X = 39.5, 58.5.
	--    Inside of wall faces -Z (courtyard), so module Yaw = 0.
	local gateX = cfg.RearGateCenterX or 14
	spawnGothicGateArch(wallsModel, "EastOutskirtsGateArch", CFrame.new(gateX, 0, halfL), "OpenDoors", false)
	for idx, bx in ipairs({ -57, -35, -13 }) do
		spawnGothicStraightWall(
			wallsModel,
			"Wall_EastLeft_Bay_" .. idx,
			CFrame.new(bx, 0, halfL),
			22,
			true,
			true
		)
	end
	for idx, bx in ipairs({ 39.5, 58.5 }) do
		spawnGothicStraightWall(
			wallsModel,
			"Wall_EastRight_Bay_" .. idx,
			CFrame.new(bx, 0, halfL),
			19,
			true,
			true
		)
	end

	-- 4. South Wall (-X = -77, bottom-left foreground wall in image_8b03db.jpg)
	--    Spans Z in [-48, +48] = 96 studs -> 4 exact 24-stud `Wall_Gothic_Straight` bays at Z = -36, -12, +12, +36.
	--    Inside of wall faces +X (courtyard), so module Yaw = -math.pi * 0.5.
	local southRot = CFrame.Angles(0, -math.pi * 0.5, 0)
	for idx, bz in ipairs({ -36, -12, 12, 36 }) do
		spawnGothicStraightWall(
			wallsModel,
			"Wall_South_Bay_" .. idx,
			CFrame.new(-halfW, 0, bz) * southRot,
			24,
			true,
			true
		)
	end

	-- 5. North Wall (+X = +77, top-left wall in image_8b03db.jpg featuring the Portcullis Alcove Gate)
	--    Inside of wall faces -X (courtyard), so module Yaw = math.pi * 0.5.
	local northRot = CFrame.Angles(0, math.pi * 0.5, 0)
	if cfg.IncludeNorthPortcullisGate then
		-- Portcullis Alcove Gate centered at Z = -20 (spanning [-36, -4]), flanked by:
		--   Z in [-48, -36] (12W bay at Z = -42)
		--   Z in [-4, +48] (52 studs -> two 26W bays at Z = +9 and Z = +35)
		spawnGothicStraightWall(wallsModel, "Wall_North_Bay_1", CFrame.new(halfW, 0, -42) * northRot, 12, true, false)
		spawnGothicGateArch(wallsModel, "NorthPortcullisGateArch", CFrame.new(halfW, 0, -20) * northRot, "PortcullisAlcove", false)
		spawnGothicStraightWall(wallsModel, "Wall_North_Bay_2", CFrame.new(halfW, 0, 9) * northRot, 26, true, true)
		spawnGothicStraightWall(wallsModel, "Wall_North_Bay_3", CFrame.new(halfW, 0, 35) * northRot, 26, true, true)
	else
		for idx, bz in ipairs({ -36, -12, 12, 36 }) do
			spawnGothicStraightWall(wallsModel, "Wall_North_Bay_" .. idx, CFrame.new(halfW, 0, bz) * northRot, 24, true, true)
		end
	end

	-- 6. Exterior Ledge Scaffolding, Crates & Barrels (Stage 3 Step 2.4)
	buildExteriorPerimeterProps(wallsModel, halfW, halfL)

	-- 7. Invisible Backup Collision Barriers (preserving exact openings at West Bridge & East Outskirts gates)
	local barrierFolder = Instance.new("Folder")
	barrierFolder.Name = "InvisibleEdgeBarriers"
	barrierFolder.Parent = wallsModel

	local bY = cfg.InvisibleBarrierHeight * 0.5
	local halfOpen = cfg.RearOpeningWidth * 0.5
	local leftEdge = -cfg.PerimeterWidth * 0.5
	local rightEdge = cfg.PerimeterWidth * 0.5
	local leftSpan = (gateX - halfOpen) - leftEdge
	local rightSpan = rightEdge - (gateX + halfOpen)
	local leftRearX = leftEdge + leftSpan * 0.5
	local rightRearX = (gateX + halfOpen) + rightSpan * 0.5

	local barrierDefs = {
		{ Name = "Barrier_West", Size = Vector3.new(2, cfg.InvisibleBarrierHeight, cfg.PerimeterLength + 4), Pos = Vector3.new(-halfW - 1.5, bY, 0) },
		{ Name = "Barrier_East", Size = Vector3.new(2, cfg.InvisibleBarrierHeight, cfg.PerimeterLength + 4), Pos = Vector3.new(halfW + 1.5, bY, 0) },
		-- Rear barriers flanking the dividing wall gate opening
		{ Name = "Barrier_BackLeft", Size = Vector3.new(leftSpan, cfg.InvisibleBarrierHeight, 2), Pos = Vector3.new(leftRearX, bY, halfL + 1.5) },
		{ Name = "Barrier_BackRight", Size = Vector3.new(rightSpan, cfg.InvisibleBarrierHeight, 2), Pos = Vector3.new(rightRearX, bY, halfL + 1.5) },
	}

	for _, b in ipairs(barrierDefs) do
		makePart({
			Name = b.Name,
			Size = b.Size,
			CFrame = CFrame.new(b.Pos),
			Transparency = 1,
			CastShadow = false,
			Decorative = false,
			Parent = barrierFolder,
		})
	end

	if parentIsland then
		wallsModel.Parent = parentIsland
	end

	return wallsModel
end

return WallsBuilder
