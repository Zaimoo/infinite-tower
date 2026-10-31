--!strict
-- PlaceIslandsInRing.server.luau
-- Master Runner Script:
-- 1. Builds the centerpiece Black & Red Tower and applies Storm Lighting/Effects.
-- 2. Builds one reusable Floating Island template (Island + Fortress Walls + Default Plaza Fountain) and clones it 5 times.
-- 3. Places the 5 islands evenly in a ring (72 degrees apart) around the Tower at Config.RingRadius, all facing the Tower.
-- 4. Moves Plot_1 .. Plot_5 onto their islands while preserving existing ownership, PlotSpawn, PrivateExtractionPad,
--    and facility objects so PlotManager, RelicService, CombatSimulation, and MasterController keep working untouched.
-- 5. Creates a Kill/Respawn Zone below the islands that safely returns anyone who falls to their PlotSpawn.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local BaseOverhaulFolder = script.Parent
local IslandBuilder = require(BaseOverhaulFolder:WaitForChild("IslandBuilder"))
local WallsBuilder = require(BaseOverhaulFolder:WaitForChild("WallsBuilder"))
local FountainBuilder = require(BaseOverhaulFolder:WaitForChild("FountainBuilder"))
local TowerBuilder = require(BaseOverhaulFolder:WaitForChild("TowerBuilder"))
local LightingAndEffects = require(BaseOverhaulFolder:WaitForChild("LightingAndEffects"))

--============================================================================
-- CONFIGURATION TABLE
--============================================================================
local Config = {
	-- Ring Layout (6 Floating Islands, 60 degrees apart, facing the Tower)
	IslandCount = 6,
	RingCenter = Vector3.new(0, 0, 0),
	RingRadius = 650, -- GDD Section 3.2 & 3.4: 1.2x expansion out to R = 650 studs
	IslandSurfaceY = 12, -- Keeps Y = 12 so CombatSimulation & EntityRenderer hero ground height works without changes!
	StartAngleDeg = -90, -- -90 deg places Plot_1 at (0, 12, -650), matching original Plot_1 orientation

	-- Existing Plot & Environment Visibility
	HideOldPerimeterHighway = true, -- Hides flat connecting highway segments so islands float over open sky
	HideOldFlatCenterArena = true, -- Hides flat Ring1/Ring2 floors & ruin props so islands float over open sky around the central Tower

	-- Kill / Respawn Safety Zone Below Islands
	KillZoneY = -95, -- Height of the safety catch plane below the islands
	KillZoneSize = Vector3.new(2400, 8, 2400),
}

--============================================================================
-- HELPER FUNCTIONS
--============================================================================
local function hideInstanceVisuals(inst: Instance)
	if inst:IsA("BasePart") then
		inst.Transparency = 1
		inst.CanCollide = false
		inst.CanTouch = false
		inst.CanQuery = false
		inst.CastShadow = false
	elseif inst:IsA("ProximityPrompt") or inst:IsA("BillboardGui") or inst:IsA("SurfaceGui") or inst:IsA("Highlight") or inst:IsA("ParticleEmitter") or inst:IsA("Beam") then
		(inst :: any).Enabled = false
	elseif inst:IsA("Decal") or inst:IsA("Texture") then
		inst.Transparency = 1
	end
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Transparency = 1
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.CastShadow = false
		elseif d:IsA("ProximityPrompt") or d:IsA("BillboardGui") or d:IsA("SurfaceGui") or d:IsA("Highlight") or d:IsA("ParticleEmitter") or d:IsA("Beam") then
			(d :: any).Enabled = false
		elseif d:IsA("Decal") or d:IsA("Texture") then
			d.Transparency = 1
		end
	end
end

local function createMasterIslandTemplate(): Model
	local template = IslandBuilder.Build()
	WallsBuilder.Build(template)
	FountainBuilder.Build(template)
	return template
end

-- Repositions a Plot_N model onto its new floating island CFrame while keeping all required children intact
local function migratePlotToIsland(plotModel: Model, islandClone: Model, islandTopCF: CFrame)
	-- 1. Delete old flat PlotFloor, ArenaEntryRamp, and Art_PrivateExtractionPad if present
	for _, partName in ipairs({ "PlotFloor", "ArenaEntryRamp", "Art_PrivateExtractionPad" }) do
		local oldPart = plotModel:FindFirstChild(partName)
		if oldPart then
			oldPart:Destroy()
		end
	end

	-- 2. Move PlotSpawn to the front plaza side of the island (between Fountain and Front Gate, facing the Tower)
	local plotSpawn = plotModel:FindFirstChild("PlotSpawn") :: SpawnLocation?
	if plotSpawn then
		plotSpawn.Anchored = true
		plotSpawn.CanCollide = false
		plotSpawn.Transparency = 1 -- Blends cleanly into the cobblestone floor
		plotSpawn.Neutral = false
		plotSpawn.CFrame = islandTopCF * CFrame.new(0, 0.5, -80)
	end

	-- 3. Move PrivateExtractionPad to the inner edge near the front gate so Relic drop-off continues to work
	local extractionPad = plotModel:FindFirstChild("PrivateExtractionPad") :: BasePart?
	local padCFrame = islandTopCF * CFrame.new(36, 0.6, -72)
	if extractionPad then
		extractionPad.Anchored = true
		extractionPad.CFrame = padCFrame
		extractionPad.Transparency = 1
		extractionPad.CanCollide = false
		local oldBb = extractionPad:FindFirstChild("InfoBillboard")
		if oldBb then
			oldBb:Destroy()
		end
	end

	-- 4. Delete old Tycoon Facility Models (Infirmary, DimLab, SummoningAltar, legacy Blacksmith)
	for _, facName in ipairs({ "Facility_Infirmary", "Facility_DimLab", "SummoningAltar", "Facility_Blacksmith" }) do
		local fac = plotModel:FindFirstChild(facName)
		if fac then
			fac:Destroy()
		end
	end

	-- 5. Parent the generated Floating Island, Walls, and Default Plaza Fountain into Plot_N
	local prevIsland = plotModel:FindFirstChild("FloatingFortressIsland")
	if prevIsland then
		prevIsland:Destroy()
	end
	local prevFountain = plotModel:FindFirstChild("PlazaFountain")
	if prevFountain then
		prevFountain:Destroy()
	end

	islandClone:PivotTo(islandTopCF * CFrame.new(0, -IslandBuilder.Config.TopThickness * 0.5, 0))

	-- Expose PlazaFountain directly under Plot_N as a default starter object so build systems can move/remove it easily
	local fountain = islandClone:FindFirstChild("PlazaFountain")
	if fountain then
		fountain.Parent = plotModel
	end

	-- 6. Ensure persistent PlotBeaconAnchor so client avatar beacons never stream out
	plotModel.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local beaconAnchor = plotModel:FindFirstChild("PlotBeaconAnchor") :: Model?
	if not beaconAnchor then
		beaconAnchor = Instance.new("Model")
		beaconAnchor.Name = "PlotBeaconAnchor"
		beaconAnchor.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		beaconAnchor.Parent = plotModel
	end
	beaconAnchor.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	local anchorPart = beaconAnchor:FindFirstChild("AnchorPart") :: BasePart?
	if not anchorPart then
		anchorPart = Instance.new("Part")
		anchorPart.Name = "AnchorPart"
		anchorPart.Size = Vector3.new(2, 2, 2)
		anchorPart.Anchored = true
		anchorPart.CanCollide = false
		anchorPart.CanTouch = false
		anchorPart.CanQuery = false
		anchorPart.Transparency = 1
		anchorPart.Parent = beaconAnchor
		beaconAnchor.PrimaryPart = anchorPart
	end
	anchorPart.CFrame = CFrame.new(islandTopCF.Position.X, islandTopCF.Position.Y, islandTopCF.Position.Z)

	-- 7. Ensure Leaderboard Playtime asset is present and placed on the ground along the North Wall
	local leaderboard = plotModel:FindFirstChild("AvxsedPlaytimeWS")
	if not leaderboard then
		local rep = game:GetService("ReplicatedStorage")
		local assets = rep:FindFirstChild("Assets")
		local template = assets and assets:FindFirstChild("LeaderboardTemplate")
		if template then
			local clone = template:Clone()
			clone.Name = "AvxsedPlaytimeWS"
			clone.Parent = plotModel
			leaderboard = clone
		end
	end
	if leaderboard then
		local rigstand = leaderboard:FindFirstChild("Rigstand")
		local top1 = rigstand and rigstand:FindFirstChild("Top 1")
		if top1 and top1:IsA("BasePart") then
			local targetTop1CF = islandTopCF * CFrame.new(116.6, 6.8, -20.9) * CFrame.Angles(0, math.rad(90), 0)
			local deltaPos = targetTop1CF.Position - top1.Position
			if deltaPos.Magnitude > 0.05 then
				for _, d in ipairs(leaderboard:GetDescendants()) do
					if d:IsA("BasePart") and d.Name ~= "ScreenPlaytime" then
						d.CFrame = d.CFrame + deltaPos
					end
				end
			end
		end

		local screen = leaderboard:FindFirstChild("ScreenPlaytime")
		if screen and screen:IsA("BasePart") then
			screen.Anchored = true
			screen.CanCollide = false
			screen.Size = Vector3.new(9.4, 12.4, 0.5)
			screen.Transparency = 0
			screen.Color = Color3.fromRGB(15, 15, 18)
			screen.Material = Enum.Material.Glass
			screen.CFrame = islandTopCF * CFrame.new(116.2, 6.65, -31.3) * CFrame.Angles(0, math.rad(90), 0)
		end
	end

	-- 8. Ensure Leaderboard Power asset is present and placed on the ground along the North Wall
	local powerLeaderboard = plotModel:FindFirstChild("AvxsedPowerWS")
	if not powerLeaderboard and leaderboard then
		local clone = leaderboard:Clone()
		clone.Name = "AvxsedPowerWS"
		local s = clone:FindFirstChild("ScreenPlaytime")
		if s then
			s.Name = "ScreenPower"
			local holder = s:FindFirstChild("SurfaceGui") and s.SurfaceGui:FindFirstChild("Holder")
			local headerLbl = holder and holder:FindFirstChild("Header") and holder.Header:FindFirstChild("LabelFrame") and holder.Header.LabelFrame:FindFirstChild("HeaderLabel") :: TextLabel?
			if headerLbl then
				headerLbl.Text = "TOP POWER"
			end
		end
		clone.Parent = plotModel
		powerLeaderboard = clone
	end
	if powerLeaderboard then
		local rigstand = powerLeaderboard:FindFirstChild("Rigstand")
		local top1 = rigstand and rigstand:FindFirstChild("Top 1")
		if top1 and top1:IsA("BasePart") then
			local targetTop1CF = islandTopCF * CFrame.new(116.6, 6.8, -2.6) * CFrame.Angles(0, math.rad(90), 0)
			local deltaPos = targetTop1CF.Position - top1.Position
			if deltaPos.Magnitude > 0.05 then
				for _, d in ipairs(powerLeaderboard:GetDescendants()) do
					if d:IsA("BasePart") and d.Name ~= "ScreenPower" then
						d.CFrame = d.CFrame + deltaPos
					end
				end
			end
		end

		local screen = powerLeaderboard:FindFirstChild("ScreenPower") or powerLeaderboard:FindFirstChild("ScreenPlaytime")
		if screen and screen:IsA("BasePart") then
			screen.Name = "ScreenPower"
			screen.Anchored = true
			screen.CanCollide = false
			screen.Size = Vector3.new(9.4, 12.4, 0.5)
			screen.Transparency = 0
			screen.Color = Color3.fromRGB(15, 15, 18)
			screen.Material = Enum.Material.Glass
			screen.CFrame = islandTopCF * CFrame.new(116.2, 6.65, -13.0) * CFrame.Angles(0, math.rad(90), 0)
		end
	end

	islandClone.Parent = plotModel
end

-- Phase 4.2: Distant Background Floating Islets (8-12 non-collidable rock islets with pines & boulders)
local function buildDistantBackgroundIslets(container: Instance)
	local isletsFolder = Instance.new("Folder")
	isletsFolder.Name = "BackgroundFloatingIslets"
	isletsFolder.Parent = container

	local rng = Random.new(20261028)
	local isletCount = 12
	local slateColor = Color3.fromRGB(65, 68, 72)
	local deepSlate = Color3.fromRGB(45, 48, 54)
	local grassTop = Color3.fromRGB(48, 78, 44)
	local pineNeedle = Color3.fromRGB(45, 75, 42)
	local trunkBark = Color3.fromRGB(58, 42, 28)

	for i = 1, isletCount do
		-- Place around the outer horizon ring in R in [790, 980]
		local angle = ((i - 1) / isletCount) * math.pi * 2 + math.rad(12)
		local radius = rng:NextNumber(790, 980)
		local elevY = rng:NextNumber(-28, 52)
		local center = Vector3.new(
			Config.RingCenter.X + math.cos(angle) * radius,
			elevY,
			Config.RingCenter.Z + math.sin(angle) * radius
		)
		local width = rng:NextNumber(46, 78)
		local length = rng:NextNumber(42, 72)
		local depth = rng:NextNumber(38, 64)
		local yaw = rng:NextNumber(0, math.pi * 2)
		local isletCF = CFrame.new(center) * CFrame.Angles(0, yaw, 0)

		local isletModel = Instance.new("Model")
		isletModel.Name = string.format("DistantIslet_%d", i)
		isletModel.Parent = isletsFolder

		local function decPart(name: string, size: Vector3, cf: CFrame, col: Color3, mat: Enum.Material, shape: Enum.PartType?)
			local p = Instance.new("Part")
			p.Name = name
			p.Size = size
			p.CFrame = cf
			p.Color = col
			p.Material = mat
			if shape then
				p.Shape = shape
			end
			p.Anchored = true
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.CastShadow = false
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
			p.Parent = isletModel
			return p
		end

		-- Grass cap & upper slate mass
		decPart("GrassCap", Vector3.new(width, 3.0, length), isletCF * CFrame.new(0, 1.5, 0), grassTop, Enum.Material.Grass)
		decPart("UpperRock", Vector3.new(width * 0.92, depth * 0.38, length * 0.92), isletCF * CFrame.new(0, -depth * 0.19, 0), slateColor, Enum.Material.Slate)
		decPart("MidRock", Vector3.new(width * 0.64, depth * 0.36, length * 0.64), isletCF * CFrame.new(0, -depth * 0.52, 0) * CFrame.Angles(0, 0.3, 0), slateColor:Lerp(deepSlate, 0.5), Enum.Material.Slate)
		decPart("ApexRock", Vector3.new(width * 0.32, depth * 0.35, length * 0.32), isletCF * CFrame.new(0, -depth * 0.82, 0) * CFrame.Angles(0.15, 0.6, 0), deepSlate, Enum.Material.Slate)

		-- 3 Conical Pine Trees on each distant islet
		local treeCount = rng:NextInteger(2, 4)
		for t = 1, treeCount do
			local tx = rng:NextNumber(-width * 0.28, width * 0.28)
			local tz = rng:NextNumber(-length * 0.28, length * 0.28)
			local scale = rng:NextNumber(0.85, 1.25)
			local treeBase = isletCF * CFrame.new(tx, 3.0, tz)

			decPart("PineTrunk", Vector3.new(14 * scale, 2.2 * scale, 2.2 * scale), treeBase * CFrame.new(0, 7 * scale, 0) * CFrame.Angles(0, 0, math.pi * 0.5), trunkBark, Enum.Material.Wood, Enum.PartType.Cylinder)
			decPart("PineTier1", Vector3.new(4.5 * scale, 14 * scale, 14 * scale), treeBase * CFrame.new(0, 8 * scale, 0) * CFrame.Angles(0, 0, math.pi * 0.5), pineNeedle, Enum.Material.Grass, Enum.PartType.Cylinder)
			decPart("PineTier2", Vector3.new(4.0 * scale, 10 * scale, 10 * scale), treeBase * CFrame.new(0, 12 * scale, 0) * CFrame.Angles(0, 0, math.pi * 0.5), pineNeedle, Enum.Material.Grass, Enum.PartType.Cylinder)
			decPart("PineTier3", Vector3.new(3.6 * scale, 6 * scale, 6 * scale), treeBase * CFrame.new(0, 15.5 * scale, 0) * CFrame.Angles(0, 0, math.pi * 0.5), pineNeedle, Enum.Material.Grass, Enum.PartType.Cylinder)
		end

		-- Craggy Boulders on the islet
		for b = 1, 2 do
			local bx = rng:NextNumber(-width * 0.32, width * 0.32)
			local bz = rng:NextNumber(-length * 0.32, length * 0.32)
			decPart("IsletBoulder_" .. b, Vector3.new(6, 4, 5), isletCF * CFrame.new(bx, 4.2, bz) * CFrame.Angles(0.1, b * 1.1, 0), slateColor, Enum.Material.Slate)
		end
	end
end

local function connectKillZoneTouch(killZone: BasePart)
	local debounce: { [Player]: number } = {}
	killZone.Touched:Connect(function(hit: BasePart)
		local char = hit.Parent
		if not char then
			return
		end
		local player = Players:GetPlayerFromCharacter(char)
		if not player then
			return
		end
		local now = os.clock()
		if debounce[player] and (now - debounce[player]) < 1.0 then
			return
		end
		debounce[player] = now

		-- Return player to their assigned PlotSpawn via PlotManager or RespawnLocation
		if _G.PlotManager and _G.PlotManager.TeleportPlayerToPlot then
			_G.PlotManager.TeleportPlayerToPlot(player)
		else
			local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
			local spawnLoc = player.RespawnLocation
			if hrp and spawnLoc then
				hrp.AssemblyLinearVelocity = Vector3.zero
				hrp.CFrame = spawnLoc.CFrame * CFrame.new(0, 4, 0)
			end
		end
	end)
end

local function setupKillRespawnZone(container: Instance): BasePart
	local oldZone = container:FindFirstChild("IslandKillRespawnZone")
	if oldZone then
		oldZone:Destroy()
	end

	local killZone = Instance.new("Part")
	killZone.Name = "IslandKillRespawnZone"
	killZone.Size = Config.KillZoneSize
	killZone.Position = Vector3.new(Config.RingCenter.X, Config.KillZoneY, Config.RingCenter.Z)
	killZone.Anchored = true
	killZone.CanCollide = false
	killZone.CanTouch = true
	killZone.CanQuery = false
	killZone.Transparency = 1
	killZone.Parent = container

	connectKillZoneTouch(killZone)
	return killZone
end

--============================================================================
-- EXECUTION
--============================================================================
local function buildOverhaul(forceRebuild: boolean?)
	-- Always apply lighting & atmospheric effects
	LightingAndEffects.Apply()

	-- Hide old PerimeterHighway and flat Arena discs if configured (non-destructive)
	if Config.HideOldPerimeterHighway then
		local highway = Workspace:FindFirstChild("PerimeterHighway")
		if highway then
			hideInstanceVisuals(highway)
		end
	end

	if Config.HideOldFlatCenterArena then
		local artEnv = Workspace:FindFirstChild("ArtPackEnvironment")
		if artEnv then
			hideInstanceVisuals(artEnv)
		end
		local arenaRings = Workspace:FindFirstChild("ArenaRings")
		if arenaRings then
			local r1 = arenaRings:FindFirstChild("Ring1_OuterRuins")
			local r2 = arenaRings:FindFirstChild("Ring2_CorruptedGrove")
			local r3 = arenaRings:FindFirstChild("Ring3_CenterBossAltar")
			if r1 then
				hideInstanceVisuals(r1)
			end
			if r2 then
				hideInstanceVisuals(r2)
			end
			if r3 then
				for _, child in ipairs(r3:GetChildren()) do
					if child.Name ~= "Ring3_ObsidianAltar" then
						hideInstanceVisuals(child)
					else
						child.Color = Color3.fromRGB(22, 16, 20)
						child.Material = Enum.Material.Basalt
					end
				end
			end
		end
	end

	local OVERHAUL_VERSION = 7
	local plotsFolder = Workspace:WaitForChild("WaitingRoomPlots")
	local existingContainer = Workspace:FindFirstChild("BaseOverhaulGeometry")
	local plot1 = plotsFolder:FindFirstChild("Plot_1")
	local alreadyBaked = existingContainer ~= nil
		and existingContainer:GetAttribute("OverhaulVersion") == OVERHAUL_VERSION
		and existingContainer:FindFirstChild("CentralCrimsonTower") ~= nil
		and existingContainer:FindFirstChild("BackgroundFloatingIslets") ~= nil
		and plot1 ~= nil
		and plot1:FindFirstChild("FloatingFortressIsland") ~= nil
		and plotsFolder:FindFirstChild("Plot_6") ~= nil
		and plotsFolder.Plot_6:FindFirstChild("FloatingFortressIsland") ~= nil
		and #plotsFolder:GetChildren() >= 6

	if alreadyBaked and not forceRebuild then
		-- Geometry was already baked in Edit mode; just hook up runtime listeners!
		local killZone = existingContainer:FindFirstChild("IslandKillRespawnZone") :: BasePart?
		if killZone then
			connectKillZoneTouch(killZone)
		else
			setupKillRespawnZone(existingContainer)
		end
		return
	end

	if existingContainer then
		existingContainer:Destroy()
	end
	local overhaulContainer = Instance.new("Folder")
	overhaulContainer.Name = "BaseOverhaulGeometry"
	overhaulContainer:SetAttribute("OverhaulVersion", OVERHAUL_VERSION)
	overhaulContainer.Parent = Workspace

	-- 1. Build Central Black & Red Tower
	TowerBuilder.Build(overhaulContainer)

	-- 2. Build 1 Master Island Template & Clone 5 Times Around the Ring (72 degrees apart)
	local masterTemplate = createMasterIslandTemplate()

	for i = 1, Config.IslandCount do
		local stepDeg = (i - 1) * (360 / Config.IslandCount) -- 0, 72, 144, 216, 288 degrees
		local angleRad = math.rad(Config.StartAngleDeg + stepDeg)

		local posX = Config.RingCenter.X + math.cos(angleRad) * Config.RingRadius
		local posZ = Config.RingCenter.Z + math.sin(angleRad) * Config.RingRadius
		local islandPos = Vector3.new(posX, Config.IslandSurfaceY, posZ)

		-- Orient each island so its front (-Z local) faces directly toward the central Tower
		local lookTarget = Vector3.new(Config.RingCenter.X, Config.IslandSurfaceY, Config.RingCenter.Z)
		local islandTopCF = CFrame.lookAt(islandPos, lookTarget)

		local plotModel = plotsFolder:FindFirstChild("Plot_" .. tostring(i)) :: Model?
		if not plotModel then
			plotModel = Instance.new("Model")
			plotModel.Name = "Plot_" .. tostring(i)
			plotModel.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
			plotModel.Parent = plotsFolder

			local plotSpawn = Instance.new("SpawnLocation")
			plotSpawn.Name = "PlotSpawn"
			plotSpawn.Neutral = false
			plotSpawn.Parent = plotModel

			local extPad = Instance.new("Part")
			extPad.Name = "PrivateExtractionPad"
			extPad.Size = Vector3.new(12, 1, 12)
			extPad.Parent = plotModel
		end

		local islandClone = masterTemplate:Clone()
		migratePlotToIsland(plotModel, islandClone, islandTopCF)
	end

	masterTemplate:Destroy()

	-- 3. Create Kill/Respawn Zone below the islands + Distant Floating Background Islets
	setupKillRespawnZone(overhaulContainer)
	buildDistantBackgroundIslets(overhaulContainer)

	-- 4. Re-teleport any currently connected players to their updated island PlotSpawn
	if _G.PlotManager and _G.PlotManager.TeleportPlayerToPlot then
		for _, player in ipairs(Players:GetPlayers()) do
			_G.PlotManager.TeleportPlayerToPlot(player)
		end
	end

	print("[BaseOverhaul] 5 Floating Fortress Islands + Central Crimson Tower generated successfully.")
end

buildOverhaul(false)

local BridgeBuilder = require(script.Parent:WaitForChild("BridgeBuilder"))
BridgeBuilder.Build()
