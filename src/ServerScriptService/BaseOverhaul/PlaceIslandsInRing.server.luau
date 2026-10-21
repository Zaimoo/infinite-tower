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
	-- Ring Layout (5 Floating Islands, 72 degrees apart, facing the Tower)
	IslandCount = 5,
	RingCenter = Vector3.new(0, 0, 0),
	RingRadius = 540, -- Keeps R >= 460 so CombatSimulation automatic Gem/Loot drop-off works without changes!
	IslandSurfaceY = 12, -- Keeps Y = 12 so CombatSimulation & EntityRenderer hero ground height works without changes!
	StartAngleDeg = -90, -- -90 deg places Plot_1 at (0, 12, -540), matching original Plot_1 orientation

	-- Existing Plot & Environment Visibility
	HidePrebuiltFacilitiesForEmptyLook = true, -- Tucks prebuilt facilities below the slab so the island top stays 100% open (only Walls + Fountain)
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
	-- 1. Hide old flat PlotFloor and ArenaEntryRamp (do not delete, so no script reference can break)
	for _, partName in ipairs({ "PlotFloor", "ArenaEntryRamp" }) do
		local oldPart = plotModel:FindFirstChild(partName)
		if oldPart and oldPart:IsA("BasePart") then
			hideInstanceVisuals(oldPart)
			oldPart.CFrame = islandTopCF * CFrame.new(0, -40, 0)
		end
	end

	-- 2. Move PlotSpawn to the front plaza side of the island (between Fountain and Front Gate, facing the Tower)
	local plotSpawn = plotModel:FindFirstChild("PlotSpawn") :: SpawnLocation?
	if plotSpawn then
		plotSpawn.Anchored = true
		plotSpawn.CanCollide = false
		plotSpawn.Transparency = 1 -- Blends cleanly into the cobblestone floor
		plotSpawn.CFrame = islandTopCF * CFrame.new(0, 0.5, -38)
	end

	-- 3. Move PrivateExtractionPad to the inner edge near the front gate so Relic drop-off continues to work
	local extractionPad = plotModel:FindFirstChild("PrivateExtractionPad") :: BasePart?
	local padCFrame = islandTopCF * CFrame.new(32, 0.6, -42)
	if extractionPad then
		extractionPad.Anchored = true
		extractionPad.CFrame = padCFrame
		if Config.HidePrebuiltFacilitiesForEmptyLook then
			extractionPad.Transparency = 1
			extractionPad.CanCollide = false
		end
	end
	local artPad = plotModel:FindFirstChild("Art_PrivateExtractionPad")
	if artPad and artPad:IsA("Model") then
		artPad:PivotTo(islandTopCF * CFrame.new(32, 0, -42))
		if Config.HidePrebuiltFacilitiesForEmptyLook then
			hideInstanceVisuals(artPad)
		end
	end

	-- 4. Handle existing Tycoon Facility Models (Infirmary, DimLab, SummoningAltar)
	local facilityOffsets: { [string]: CFrame } = {
		Facility_Infirmary = CFrame.new(-44, 0, 10),
		Facility_DimLab = CFrame.new(0, 0, 44),
		SummoningAltar = CFrame.new(-32, 0, -42),
	}

	for facName, localOffset in pairs(facilityOffsets) do
		local fac = plotModel:FindFirstChild(facName)
		if fac and fac:IsA("Model") then
			if Config.HidePrebuiltFacilitiesForEmptyLook then
				-- Tuck prebuilt facility models inside the rock core below the surface and hide them
				-- so the island top is 100% empty (only Walls + Fountain), while PlotManager & prompts never error!
				fac:PivotTo(islandTopCF * CFrame.new(localOffset.X, -35, localOffset.Z))
				hideInstanceVisuals(fac)
			else
				fac:PivotTo(islandTopCF * localOffset * CFrame.new(0, 5, 0))
			end
		end
	end

	-- Hide auto-spawned facility worker mannequins if prebuilt facilities are hidden for an empty island
	if Config.HidePrebuiltFacilitiesForEmptyLook then
		local function watchWorkers(workersFolder: Instance)
			hideInstanceVisuals(workersFolder)
			workersFolder.DescendantAdded:Connect(function(desc)
				task.defer(hideInstanceVisuals, desc)
			end)
		end
		local existingWorkers = plotModel:FindFirstChild("ActivePlotWorkers")
		if existingWorkers then
			watchWorkers(existingWorkers)
		end
		plotModel.ChildAdded:Connect(function(child)
			if child.Name == "ActivePlotWorkers" then
				watchWorkers(child)
			end
		end)
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

	islandClone.Parent = plotModel
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

	local plotsFolder = Workspace:WaitForChild("WaitingRoomPlots")
	local existingContainer = Workspace:FindFirstChild("BaseOverhaulGeometry")
	local plot1 = plotsFolder:FindFirstChild("Plot_1")
	local alreadyBaked = existingContainer ~= nil
		and existingContainer:FindFirstChild("CentralCrimsonTower") ~= nil
		and plot1 ~= nil
		and plot1:FindFirstChild("FloatingFortressIsland") ~= nil

	if alreadyBaked and not forceRebuild then
		-- Geometry was already baked in Edit mode; just hook up runtime listeners and worker hiding!
		local killZone = existingContainer:FindFirstChild("IslandKillRespawnZone") :: BasePart?
		if killZone then
			connectKillZoneTouch(killZone)
		else
			setupKillRespawnZone(existingContainer)
		end

		if Config.HidePrebuiltFacilitiesForEmptyLook then
			for i = 1, Config.IslandCount do
				local pModel = plotsFolder:FindFirstChild("Plot_" .. tostring(i))
				if pModel then
					local function watchWorkers(workersFolder: Instance)
						hideInstanceVisuals(workersFolder)
						workersFolder.DescendantAdded:Connect(function(desc)
							task.defer(hideInstanceVisuals, desc)
						end)
					end
					local w = pModel:FindFirstChild("ActivePlotWorkers")
					if w then
						watchWorkers(w)
					end
					pModel.ChildAdded:Connect(function(child)
						if child.Name == "ActivePlotWorkers" then
							watchWorkers(child)
						end
					end)
				end
			end
		end
		return
	end

	if existingContainer then
		existingContainer:Destroy()
	end
	local overhaulContainer = Instance.new("Folder")
	overhaulContainer.Name = "BaseOverhaulGeometry"
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
		if plotModel then
			local islandClone = masterTemplate:Clone()
			migratePlotToIsland(plotModel, islandClone, islandTopCF)
		end
	end

	-- Hide unused Plot_6 if present (since the ring uses 5 islands)
	local plot6 = plotsFolder:FindFirstChild("Plot_6")
	if plot6 then
		hideInstanceVisuals(plot6)
	end

	masterTemplate:Destroy()

	-- 3. Create Kill/Respawn Zone below the islands
	setupKillRespawnZone(overhaulContainer)

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
