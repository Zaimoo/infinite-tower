--!strict
-- ServerScriptService/Tycoon/BlacksmithService.server.luau
-- Authoritative Blacksmith Facility & Upgrade System
-- Constructs interactive Blacksmith Forge stations in each Waiting Room plot with ProximityPrompts.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArtifactCatalog = require(Shared:WaitForChild("Config"):WaitForChild("ArtifactCatalog"))

local PlotsFolder = Workspace:WaitForChild("WaitingRoomPlots")

local BlacksmithService = {}

-- Construct a rich 3D Blacksmith Forge Station on a given plot
local function createBlacksmithStation(plotModel: Instance): Model
	local existing = plotModel:FindFirstChild("Facility_Blacksmith")
	if existing then
		return existing :: Model
	end

	local station = Instance.new("Model")
	station.Name = "Facility_Blacksmith"

	-- Offset relative to plot center: on the right plaza terrace
	local baseCF = CFrame.new(26, 0.3, -18) * CFrame.Angles(0, math.rad(-35), 0)
	local island = plotModel:FindFirstChild("FloatingFortressIsland")
	if island and island:IsA("Model") and island.PrimaryPart then
		-- Align with island coordinate space
		baseCF = island.PrimaryPart.CFrame * CFrame.new(26, 4.2, -18) * CFrame.Angles(0, math.rad(-35), 0)
	elseif plotModel:IsA("Model") and plotModel.PrimaryPart then
		baseCF = plotModel.PrimaryPart.CFrame * CFrame.new(26, 0.5, -18) * CFrame.Angles(0, math.rad(-35), 0)
	end

	local function makePart(name: string, size: Vector3, cf: CFrame, mat: Enum.Material, col: Color3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Material = mat
		p.Color = col
		p.Anchored = true
		p.CanCollide = true
		p.CanQuery = true
		p.CanTouch = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = station
		return p
	end

	-- 1. Base Cobblestone Foundation Slab
	local slab = makePart("ForgeSlab", Vector3.new(12, 0.6, 12), baseCF, Enum.Material.Slate, Color3.fromRGB(55, 58, 65))

	-- 2. Heavy Stone Furnace & Chimney
	local furnaceCF = baseCF * CFrame.new(0, 3.2, 4.0)
	local furnace = makePart("FurnaceStone", Vector3.new(5.0, 5.8, 3.6), furnaceCF, Enum.Material.Cobblestone, Color3.fromRGB(42, 44, 48))

	-- 3. Glowing Forge Hearth (Burning Neon Coals & Sparks)
	local coalsCF = baseCF * CFrame.new(0, 1.2, 2.8)
	local coals = makePart("ForgeCoals", Vector3.new(3.2, 1.4, 2.0), coalsCF, Enum.Material.Neon, Color3.fromRGB(255, 69, 0))
	coals.CanCollide = false

	local forgeLight = Instance.new("PointLight")
	forgeLight.Name = "ForgeLight"
	forgeLight.Color = Color3.fromRGB(255, 120, 20)
	forgeLight.Brightness = 2.8
	forgeLight.Range = 22
	forgeLight.Shadows = false
	forgeLight.Parent = coals

	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "ForgeSparks"
	sparks.Rate = 18
	sparks.Lifetime = NumberRange.new(0.6, 1.4)
	sparks.Speed = NumberRange.new(3, 8)
	sparks.SpreadAngle = Vector2.new(35, 35)
	sparks.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 80)),
		ColorSequenceKeypoint.new(0.7, Color3.fromRGB(255, 90, 20)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 20, 10)),
	})
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(1, 0.02),
	})
	sparks.Acceleration = Vector3.new(0, 5, 0)
	sparks.Parent = coals

	-- 4. Cast Iron Anvil
	local anvilBaseCF = baseCF * CFrame.new(-2.2, 1.0, -1.0)
	local anvilBase = makePart("AnvilBase", Vector3.new(1.8, 1.4, 1.6), anvilBaseCF, Enum.Material.Metal, Color3.fromRGB(30, 32, 38))

	local anvilFaceCF = anvilBaseCF * CFrame.new(0, 1.0, 0)
	local anvilFace = makePart("AnvilFace", Vector3.new(1.4, 0.6, 2.8), anvilFaceCF, Enum.Material.Metal, Color3.fromRGB(55, 60, 70))

	-- 5. Hammer Prop Resting on Anvil
	local hammerCF = anvilFaceCF * CFrame.new(0, 0.45, 0.2) * CFrame.Angles(0, math.rad(25), 0)
	local hammer = makePart("Hammer", Vector3.new(0.35, 0.4, 1.2), hammerCF, Enum.Material.Metal, Color3.fromRGB(180, 185, 195))
	hammer.CanCollide = false

	-- 6. Wooden Workbench with Ingot Racks
	local benchCF = baseCF * CFrame.new(2.8, 1.3, -1.2) * CFrame.Angles(0, math.rad(-15), 0)
	local bench = makePart("Workbench", Vector3.new(2.0, 2.0, 4.2), benchCF, Enum.Material.Wood, Color3.fromRGB(75, 50, 32))

	local ingotCF = benchCF * CFrame.new(0, 1.15, 0)
	local ingots = makePart("MetalIngots", Vector3.new(1.0, 0.3, 2.0), ingotCF, Enum.Material.Metal, Color3.fromRGB(215, 175, 55))
	ingots.CanCollide = false

	-- 7. Interactive ProximityPrompt Anchor
	local promptPart = makePart("InteractionPart", Vector3.new(2, 2, 2), baseCF * CFrame.new(0, 2.0, 0), Enum.Material.SmoothPlastic, Color3.new(1, 1, 1))
	promptPart.Transparency = 1
	promptPart.CanCollide = false
	promptPart.CanTouch = false

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BlacksmithPrompt"
	prompt.ActionText = "Upgrade & Refine Artifacts"
	prompt.ObjectText = "Blacksmith Forge"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.ClickablePrompt = true
	prompt.Parent = promptPart

	-- World-Space Billboard Label above the Forge
	local bb = Instance.new("BillboardGui")
	bb.Name = "BlacksmithBillboard"
	bb.Size = UDim2.new(0, 160, 0, 42)
	bb.StudsOffset = Vector3.new(0, 3.8, 0)
	bb.MaxDistance = 80
	bb.AlwaysOnTop = false
	bb.Parent = promptPart

	local bbLabel = Instance.new("TextLabel")
	bbLabel.Size = UDim2.fromScale(1, 1)
	bbLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	bbLabel.BackgroundTransparency = 0.25
	bbLabel.TextColor3 = Color3.fromRGB(255, 180, 50)
	bbLabel.Font = Enum.Font.GothamBold
	bbLabel.TextScaled = true
	bbLabel.Text = "⚒️ Blacksmith Forge"
	bbLabel.Parent = bb

	local bbCorner = Instance.new("UICorner")
	bbCorner.CornerRadius = UDim.new(0, 6)
	bbCorner.Parent = bbLabel

	station.PrimaryPart = slab
	station.Parent = plotModel
	return station
end

function BlacksmithService.ConfigurePlot(plotModel: Instance)
	createBlacksmithStation(plotModel)
end

-- Initialize for all current plots and future plots
for _, plot in ipairs(PlotsFolder:GetChildren()) do
	task.spawn(BlacksmithService.ConfigurePlot, plot)
end

PlotsFolder.ChildAdded:Connect(function(child)
	task.defer(BlacksmithService.ConfigurePlot, child)
end)

_G.BlacksmithService = BlacksmithService

return BlacksmithService
