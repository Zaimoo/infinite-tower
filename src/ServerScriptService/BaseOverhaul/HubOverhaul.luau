--!strict
-- HubOverhaul.luau
-- ModuleScript: builds the whole Central Hub. Build() runs both at server start (from
-- PlaceIslandsInRing.server.luau) and from Studio's Edit mode to bake the geometry into the place.
-- 1. Builds the centerpiece Black & Red Tower and applies Storm Lighting/Effects.
-- 2. Builds the Cloister Commons, the solid rounded-rectangle garden hub in front of the tower gate (CloisterBuilder).
-- 3. Builds one reusable Floating Island template (Island + Fortress Walls + Default Plaza Fountain) and clones it once per plot.
-- 4. Places the 8 islands around the Commons' outer edge (HubLayout.PlotSlots), each facing into the hub.
-- 5. Moves Plot_1 .. Plot_8 onto their islands while preserving existing ownership, PlotSpawn, PrivateExtractionPad,
--    and facility objects so PlotManager, RelicService, CombatSimulation, and MasterController keep working untouched.
-- 6. Creates a Kill/Respawn Zone below the hub that safely returns anyone who falls to their PlotSpawn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("HubLayout"))

local BaseOverhaulFolder = script.Parent
local IslandBuilder = require(BaseOverhaulFolder:WaitForChild("IslandBuilder"))
local StaticGeometry = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("StaticGeometry"))
local WallsBuilder = require(BaseOverhaulFolder:WaitForChild("WallsBuilder"))
local FountainBuilder = require(BaseOverhaulFolder:WaitForChild("FountainBuilder"))
local TowerBuilder = require(BaseOverhaulFolder:WaitForChild("TowerBuilder"))
local LightingAndEffects = require(BaseOverhaulFolder:WaitForChild("LightingAndEffects"))
local CloisterBuilder = require(BaseOverhaulFolder:WaitForChild("CloisterBuilder"))
local SharedLeaderboards = require(BaseOverhaulFolder:WaitForChild("SharedLeaderboards"))

local HubOverhaul = {}
HubOverhaul.Version = 23 -- Bump to force a rebuild of baked geometry (23: solid Commons, 8 plots)

-- Runtime cleanup sweep to destroy pre-baked light shaft beams, god-ray attachments, and SunRays
function HubOverhaul.CleanupLightShaftsAndRays()
	local Lighting = game:GetService("Lighting")
	-- 1. Remove all SunRaysEffects from Lighting
	for _, effect in ipairs(Lighting:GetChildren()) do
		if effect:IsA("SunRaysEffect") then
			effect.Enabled = false
			effect.Intensity = 0
			effect:Destroy()
		end
	end

	-- 2. Sweep Workspace for pre-baked light shafts, volumetric beams, and god ray anchors
	for _, desc in ipairs(Workspace:GetDescendants()) do
		if desc:FindFirstAncestorOfClass("Tool")
			or desc:FindFirstAncestorWhichIsA("Humanoid")
			or desc:FindFirstAncestor("LiveEntities")
			or desc:FindFirstAncestor("ActiveMobs")
			or desc:FindFirstAncestor("ActiveHeroes")
		then
			continue
		end

		local nameLower = string.lower(desc.Name)
		if desc:IsA("Beam") then
			if string.find(nameLower, "godray")
				or string.find(nameLower, "lightshaft")
				or string.find(nameLower, "abyssray")
				or string.find(nameLower, "mistbeam")
				or string.find(nameLower, "chasmlight")
				or string.find(nameLower, "volumetriclightcolumn")
			then
				desc.Enabled = false
				desc:Destroy()
			end
		elseif desc:IsA("Attachment") then
			if string.find(nameLower, "godrayfloor")
				or string.find(nameLower, "shaftanchor")
			then
				desc:Destroy()
			end
		elseif desc:IsA("BasePart") then
			if string.find(nameLower, "volumetriclightshaft")
				or string.find(nameLower, "lightshaftray")
			then
				desc:Destroy()
			end
		end
	end
end

--============================================================================
-- CONFIGURATION TABLE
--============================================================================
local Config = {
	-- Eight plots around the Cloister Commons (positions live in HubLayout, GDD Section 3.2)
	IslandCount = HubLayout.PlotCount,


	-- Kill / Respawn Safety Zone below the whole hub
	KillZoneCentre = HubLayout.KillZoneCentre,
	KillZoneSize = HubLayout.KillZoneSize,
}

--============================================================================
-- HELPER FUNCTIONS
--============================================================================
local function createMasterIslandTemplate(): Model
	local template = IslandBuilder.Build()
	WallsBuilder.Build(template)
	FountainBuilder.Build(template)
	return template
end

-- Repositions a Plot_N model onto its new floating island CFrame while keeping all required children intact
-- Courtyard-local offsets (courtyard centre = fountain centre, -Z faces the Tower / front gate at z = -60).
-- The fountain basin spans ~24 studs, so the spawn sits between the fountain and the front gate.
local SPAWN_COURTYARD_OFFSET = CFrame.new(0, 0.5, -38) * CFrame.Angles(0, math.pi, 0) -- face into the fortress
local BEACON_ANCHOR_Y = 12

-- Places PlotSpawn on clear cobblestone, aligns PlazaFountain to face the island entrance (-Z of courtyardTopCF),
-- and centres the persistent beacon anchor over the courtyard.
-- Runs for both freshly built and pre-baked islands so stale baked positions are always corrected.
local function alignPlotSpawnAndBeacon(plotModel: Model, islandTopCF: CFrame)
	local courtyardTopCF = islandTopCF * CFrame.new(0, 0, -(IslandBuilder.Config.CenterOffsetZ or 100))

	local fountain = plotModel:FindFirstChild("PlazaFountain")
	if fountain and fountain:IsA("Model") then
		fountain:PivotTo(courtyardTopCF)
	end

	local plotSpawn = plotModel:FindFirstChild("PlotSpawn") :: SpawnLocation?
	if plotSpawn then
		plotSpawn.Anchored = true
		plotSpawn.CanCollide = false
		plotSpawn.Transparency = 1 -- Blends cleanly into the cobblestone floor
		plotSpawn.Neutral = false
		plotSpawn.CFrame = courtyardTopCF * SPAWN_COURTYARD_OFFSET
		local decal = plotSpawn:FindFirstChildWhichIsA("Decal")
		if decal then
			decal.Transparency = 1
		end
	end

	plotModel.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local beaconAnchor = plotModel:FindFirstChild("PlotBeaconAnchor") :: Model?
	if not beaconAnchor then
		beaconAnchor = Instance.new("Model")
		beaconAnchor.Name = "PlotBeaconAnchor"
		beaconAnchor.Parent = plotModel
	end
	assert(beaconAnchor)
	beaconAnchor.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	local anchorPart = beaconAnchor:FindFirstChild("AnchorPart") :: BasePart?
	if not anchorPart then
		local newPart = Instance.new("Part")
		newPart.Name = "AnchorPart"
		newPart.Size = Vector3.new(2, 2, 2)
		newPart.Anchored = true
		newPart.CanCollide = false
		newPart.CanTouch = false
		newPart.CanQuery = false
		newPart.Transparency = 1
		newPart.Parent = beaconAnchor
		anchorPart = newPart
	end
	assert(anchorPart)
	beaconAnchor.PrimaryPart = anchorPart
	local c = courtyardTopCF.Position
	anchorPart.CFrame = CFrame.new(c.X, BEACON_ANCHOR_Y, c.Z)
end

local function migratePlotToIsland(plotModel: Model, islandClone: Model, islandTopCF: CFrame)
	-- 1. Delete old flat PlotFloor, ArenaEntryRamp, and Art_PrivateExtractionPad if present
	for _, partName in ipairs({ "PlotFloor", "ArenaEntryRamp", "Art_PrivateExtractionPad" }) do
		local oldPart = plotModel:FindFirstChild(partName)
		if oldPart then
			oldPart:Destroy()
		end
	end

	-- 2. PlotSpawn + beacon anchor are placed by alignPlotSpawnAndBeacon (step 6)

	-- 3. Move PrivateExtractionPad to the inner edge near the front gate so Relic drop-off continues to work
	local extractionPad = plotModel:FindFirstChild("PrivateExtractionPad") :: BasePart?
	local padCFrame = islandTopCF * CFrame.new(22, 0.6, -46)
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

	-- 6. Place PlotSpawn on clear ground and the persistent PlotBeaconAnchor over the courtyard
	alignPlotSpawnAndBeacon(plotModel, islandTopCF)

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

	local ringCentre = HubLayout.ParkCentre
	for i = 1, isletCount do
		-- Place around the outer horizon ring, centred on the Commons
		local angle = ((i - 1) / isletCount) * math.pi * 2 + math.rad(12)
		local radius = rng:NextNumber(HubLayout.IsletRingMin, HubLayout.IsletRingMax)
		local elevY = rng:NextNumber(-28, 52)
		local center = Vector3.new(ringCentre.X + math.cos(angle) * radius, elevY, ringCentre.Z + math.sin(angle) * radius)
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
		task.wait()
	end
end

local function connectKillZoneTouch(killZone: BasePart)
	local debounce: { [Player]: number } = {}
	StaticGeometry.MarkNeedsTouch(killZone)
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

-- Parts are capped at 2048 studs per axis, so the catch plane is a grid of tiles.
local MAX_PART_SPAN = 2048

local function setupKillRespawnZone(container: Instance): Folder
	local oldZone = container:FindFirstChild("IslandKillRespawnZone")
	if oldZone then
		oldZone:Destroy()
	end

	local zone = Instance.new("Folder")
	zone.Name = "IslandKillRespawnZone"
	local size, centre = Config.KillZoneSize, Config.KillZoneCentre
	local nx, nz = math.ceil(size.X / MAX_PART_SPAN), math.ceil(size.Z / MAX_PART_SPAN)
	local tileX, tileZ = size.X / nx, size.Z / nz
	for ix = 1, nx do
		for iz = 1, nz do
			local tile = Instance.new("Part")
			tile.Name = string.format("KillTile_%d_%d", ix, iz)
			tile.Size = Vector3.new(tileX, size.Y, tileZ)
			tile.Position = centre + Vector3.new((ix - 0.5) * tileX - size.X * 0.5, 0, (iz - 0.5) * tileZ - size.Z * 0.5)
			tile.Anchored = true
			tile.CanCollide = false
			tile.CanTouch = true
			tile.CanQuery = false
			tile.Transparency = 1
			tile.Parent = zone
		end
	end
	zone.Parent = container
	return zone
end

-- Plots past PlotCount are left over from older layouts (the hub had 10): remove them so PlotManager never
-- initialises or assigns a plot with no slot.
local function removeExtraPlots(plotsFolder: Instance)
	for _, plot in plotsFolder:GetChildren() do
		local index = tonumber(string.match(plot.Name, "^Plot_(%d+)$"))
		if index and index > Config.IslandCount then
			plot:Destroy()
		end
	end
end

--============================================================================
-- EXECUTION
--============================================================================
local function mountLeaderboards(container: Instance, plotsFolder: Instance, rescued: { [string]: Instance }?)
	local commons = container:FindFirstChild("MastersCommons")
	local pavilion = commons and commons:FindFirstChild("LeaderboardPavilion")
	if pavilion then
		SharedLeaderboards.Mount(pavilion, plotsFolder, rescued)
	end
end

-- Builds (or reuses already-baked) hub geometry. Returns the container and whether it was rebuilt.
function HubOverhaul.Build(forceRebuild: boolean?): (Instance, boolean)
	-- Always apply lighting & atmospheric effects
	LightingAndEffects.Apply()
	HubOverhaul.CleanupLightShaftsAndRays()

	local OVERHAUL_VERSION = HubOverhaul.Version
	local plotsFolder = Workspace:WaitForChild("WaitingRoomPlots")
	removeExtraPlots(plotsFolder)
	local existingContainer = Workspace:FindFirstChild("BaseOverhaulGeometry")
	local plot1 = plotsFolder:FindFirstChild("Plot_1")
	local alreadyBaked = existingContainer ~= nil
		and existingContainer:GetAttribute("OverhaulVersion") == OVERHAUL_VERSION
		and existingContainer:FindFirstChild("CentralCrimsonTower") ~= nil
		and existingContainer:FindFirstChild("BackgroundFloatingIslets") ~= nil
		and existingContainer:FindFirstChild("MastersCommons") ~= nil
		and plot1 ~= nil
		and plot1:FindFirstChild("FloatingFortressIsland") ~= nil
		and plotsFolder:FindFirstChild("Plot_" .. Config.IslandCount) ~= nil
		and (plotsFolder:FindFirstChild("Plot_" .. Config.IslandCount) :: Instance):FindFirstChild("FloatingFortressIsland") ~= nil
		and #plotsFolder:GetChildren() >= Config.IslandCount

	if alreadyBaked and not forceRebuild then
		-- Geometry was already baked in Edit mode; re-seat spawns, beacons and the shared leaderboards
		local baked = existingContainer :: Instance
		for i = 1, Config.IslandCount do
			local pModel = plotsFolder:FindFirstChild("Plot_" .. tostring(i))
			if pModel and pModel:IsA("Model") then
				alignPlotSpawnAndBeacon(pModel, HubLayout.PlotIslandCFrame(i))
			end
		end
		local zone = baked:FindFirstChild("IslandKillRespawnZone")
		if not (zone and zone:IsA("Folder")) then
			setupKillRespawnZone(baked)
		end
		mountLeaderboards(baked, plotsFolder)
		return baked, false
	end

	local rescued = SharedLeaderboards.Rescue(existingContainer)
	if existingContainer then
		existingContainer:Destroy()
	end
	local overhaulContainer = Instance.new("Folder")
	overhaulContainer.Name = "BaseOverhaulGeometry"
	overhaulContainer:SetAttribute("OverhaulVersion", OVERHAUL_VERSION)
	overhaulContainer.Parent = Workspace

	-- 1. Build Central Black & Red Tower
	TowerBuilder.Build(overhaulContainer)

	-- 2. Build the Cloister Commons in front of the tower gate
	CloisterBuilder.Build(overhaulContainer)

	-- 3. Build 1 Master Island Template & clone it onto each plot slot around the cloister
	local masterTemplate = createMasterIslandTemplate()

	for i = 1, Config.IslandCount do
		-- Each island's front (-Z local) faces the Commons centre
		local islandTopCF = HubLayout.PlotIslandCFrame(i)

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
		task.wait()
	end

	masterTemplate:Destroy()

	-- 4. Create Kill/Respawn Zone below the hub + Distant Floating Background Islets
	setupKillRespawnZone(overhaulContainer)
	buildDistantBackgroundIslets(overhaulContainer)

	-- 5. One shared Playtime + Power board pair in the Commons pavilion (replaces the per-plot copies)
	mountLeaderboards(overhaulContainer, plotsFolder, rescued)

	StaticGeometry.Apply(overhaulContainer)
	StaticGeometry.Apply(plotsFolder)
	print("[BaseOverhaul] Cloister Commons + " .. Config.IslandCount .. " Floating Fortress Islands + Central Crimson Tower generated successfully.")
	return overhaulContainer, true
end

-- Courtyard facilities and outskirts follow their island (PlotBuildings skips plots already in place).
function HubOverhaul.RebuildPlotBuildings()
	local core = game:GetService("ServerScriptService"):FindFirstChild("Core")
	local module = core and core:FindFirstChild("PlotBuildings")
	if not (module and module:IsA("ModuleScript")) then
		return
	end
	local PlotBuildings = (require :: any)(module)
	for _, plot in Workspace:WaitForChild("WaitingRoomPlots"):GetChildren() do
		PlotBuildings.Build(plot)
		task.wait()
	end
end

-- Server-only wiring that cannot be baked: kill-zone touches, live gate nameplates, and moving
-- players already in the server after a rebuild.
function HubOverhaul.StartRuntime(container: Instance, rebuilt: boolean)
	HubOverhaul.CleanupLightShaftsAndRays()
	local killZone = container:FindFirstChild("IslandKillRespawnZone")
	if killZone then
		for _, tile in killZone:GetChildren() do
			if tile:IsA("BasePart") then
				connectKillZoneTouch(tile)
			end
		end
	end
	local commons = container:FindFirstChild("MastersCommons")
	if commons then
		CloisterBuilder.BindGateTablets(commons, Workspace:WaitForChild("WaitingRoomPlots"))
	end
	if rebuilt then
		-- Islands may have moved under buildings that PlotBuildingPlacement already placed
		HubOverhaul.RebuildPlotBuildings()
	end
	if rebuilt and _G.PlotManager and _G.PlotManager.TeleportPlayerToPlot then
		for _, player in ipairs(Players:GetPlayers()) do
			_G.PlotManager.TeleportPlayerToPlot(player)
		end
	end
end

return HubOverhaul
