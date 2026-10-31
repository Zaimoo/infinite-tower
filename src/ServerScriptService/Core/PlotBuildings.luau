--!strict
-- ServerScriptService/Core/PlotBuildings.luau
-- Waiting Room Plot Island Redesign (Phase 2 & 3):
-- Builds all redesigned gothic fortress courtyard facilities & Outskirts Guardpost,
-- populates ReplicatedStorage.Assets.PlotFacilities prefabs, aligns the Playtime Leaderboard
-- onto the ornate North-Wall LeaderboardBoard, and removes legacy Infirmary instances.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Buildings = {}
local Architecture = require(script.Parent:WaitForChild("PlotFacilityArchitecture"))
local OutskirtsBuilder = require(script.Parent:WaitForChild("OutskirtsEnvironmentBuilder"))
local FacilityPresence = require(script.Parent:WaitForChild("FacilityPresence"))
local FacilityConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("FacilityConfig"))

local VERSION = 21 -- 21: one [F] prompt for The Pit (was Synthesis [E] + Promotion [F])

local function attachPrompt(
	parent: Instance,
	name: string,
	hudAttr: string,
	objectText: string,
	actionText: string,
	keyCode: Enum.KeyCode,
	maxDist: number?,
	uiOffset: Vector2?
): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt:SetAttribute("FacilityHUD", hudAttr)
	prompt.ObjectText = objectText
	prompt.ActionText = actionText
	prompt.MaxActivationDistance = maxDist or 15
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = keyCode
	prompt.GamepadKeyCode = if keyCode == Enum.KeyCode.E then Enum.KeyCode.ButtonY else Enum.KeyCode.ButtonX
	prompt.ClickablePrompt = true
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	if uiOffset then
		prompt.UIOffset = uiOffset
	end
	prompt.Parent = parent
	return prompt
end

local function syncPlotFacilityAnchor(plot: Instance, name: string, cf: CFrame)
	local existing = plot:FindFirstChild("Facility_" .. name)
	if existing and existing:IsA("BasePart") then
		existing.CFrame = cf
		existing.CanCollide = false
		existing.CanTouch = false
		existing.CanQuery = false
		existing.Transparency = 1
		-- Remove duplicate bare prompts on legacy Facility_* anchors so only the styled building prompts show
		for _, child in ipairs(existing:GetChildren()) do
			if child:IsA("ProximityPrompt") then
				child:Destroy()
			end
		end
	end
end

local function alignPlaytimeBoardToWall(plot: Instance, origin: CFrame)
	local playtimeStand = plot:FindFirstChild("AvxsedPlaytimeWS")
	if not playtimeStand then
		return
	end

	local rigstand = playtimeStand:FindFirstChild("Rigstand")
	local top1 = rigstand and rigstand:FindFirstChild("Top 1")
	if top1 and top1:IsA("BasePart") then
		local targetTop1CF = origin * CFrame.new(116.6, 6.8, -20.9) * CFrame.Angles(0, math.rad(90), 0)
		local deltaPos = targetTop1CF.Position - top1.Position
		if deltaPos.Magnitude > 0.05 then
			for _, d in ipairs(playtimeStand:GetDescendants()) do
				if d:IsA("BasePart") and d.Name ~= "ScreenPlaytime" then
					d.CFrame = d.CFrame + deltaPos
				end
			end
		end
	end

	local screen = playtimeStand:FindFirstChild("ScreenPlaytime")
	if screen and screen:IsA("BasePart") then
		screen.Anchored = true
		screen.CanCollide = false
		screen.Size = Vector3.new(9.4, 12.4, 0.5)
		screen.Transparency = 0
		screen.Color = Color3.fromRGB(15, 15, 18)
		screen.Material = Enum.Material.Glass
		screen.CFrame = origin * CFrame.new(116.2, 6.65, -31.3) * CFrame.Angles(0, math.rad(90), 0)
	end
end

local function alignPowerBoardToWall(plot: Instance, origin: CFrame)
	local powerStand = plot:FindFirstChild("AvxsedPowerWS")
	if not powerStand then
		local playtimeStand = plot:FindFirstChild("AvxsedPlaytimeWS")
		if playtimeStand then
			local clone = playtimeStand:Clone()
			clone.Name = "AvxsedPowerWS"
			local screen = clone:FindFirstChild("ScreenPlaytime")
			if screen then
				screen.Name = "ScreenPower"
				local holder = screen:FindFirstChild("SurfaceGui") and screen.SurfaceGui:FindFirstChild("Holder")
				local headerLbl = holder and holder:FindFirstChild("Header") and holder.Header:FindFirstChild("LabelFrame") and holder.Header.LabelFrame:FindFirstChild("HeaderLabel") :: TextLabel?
				if headerLbl then
					headerLbl.Text = "TOP POWER"
				end
			end
			clone.Parent = plot
			powerStand = clone
		else
			return
		end
	end

	local rigstand = powerStand:FindFirstChild("Rigstand")
	local top1 = rigstand and rigstand:FindFirstChild("Top 1")
	if top1 and top1:IsA("BasePart") then
		local targetTop1CF = origin * CFrame.new(116.6, 6.8, 20.4) * CFrame.Angles(0, math.rad(90), 0)
		local deltaPos = targetTop1CF.Position - top1.Position
		if deltaPos.Magnitude > 0.05 then
			for _, d in ipairs(powerStand:GetDescendants()) do
				if d:IsA("BasePart") and d.Name ~= "ScreenPower" then
					d.CFrame = d.CFrame + deltaPos
				end
			end
		end
	end

	local screen = powerStand:FindFirstChild("ScreenPower") or powerStand:FindFirstChild("ScreenPlaytime")
	if screen and screen:IsA("BasePart") then
		screen.Name = "ScreenPower"
		screen.Anchored = true
		screen.CanCollide = false
		screen.Size = Vector3.new(9.4, 12.4, 0.5)
		screen.Transparency = 0
		screen.Color = Color3.fromRGB(15, 15, 18)
		screen.Material = Enum.Material.Glass
		screen.CFrame = origin * CFrame.new(116.2, 6.65, 10.0) * CFrame.Angles(0, math.rad(90), 0)
	end
end

function Buildings.Build(plot: Instance)
	-- Ensure standardized facility prefabs exist under ReplicatedStorage.Assets.PlotFacilities
	Architecture.EnsureFacilityPrefabs()

	-- Always purge removed Infirmary from plot
	local oldInfirmaryAnchor = plot:FindFirstChild("Facility_Infirmary")
	if oldInfirmaryAnchor then
		oldInfirmaryAnchor:Destroy()
	end

	local existing = plot:FindFirstChild("PlotBuildings")
	if existing and existing:GetAttribute("Version") == VERSION then
		return existing
	end

	local spawn = plot:FindFirstChild("PlotSpawn")
	if not spawn or not spawn:IsA("BasePart") then
		return nil
	end
	local island = plot:FindFirstChild("FloatingFortressIsland")
	local top = island and island:FindFirstChild("IslandTopSurface")
	local surfaceY = if top and top:IsA("BasePart")
		then top.Position.Y + top.Size.Y / 2
		else spawn.Position.Y - spawn.Size.Y / 2

	local origin: CFrame
	if top and top:IsA("BasePart") then
		if top.Size.Z > 200 then
			origin = CFrame.new(top.Position.X, surfaceY, top.Position.Z) * top.CFrame.Rotation * CFrame.new(0, 0, -70)
		else
			origin = CFrame.new(top.Position.X, surfaceY, top.Position.Z) * top.CFrame.Rotation
		end
	else
		origin = CFrame.new(spawn.Position.X, surfaceY, spawn.Position.Z) * spawn.CFrame.Rotation * CFrame.new(0, 0, 80)
	end

	local folder = Instance.new("Folder")
	folder.Name = "PlotBuildings_Updating"
	folder:SetAttribute("Version", VERSION)
	folder.Parent = plot

	local layout = FacilityConfig.FacilityLayout

	-- 1. Build Eastern Forested Outskirts (28 layered conical pines, craggy rocks, winding Ground trail)
	OutskirtsBuilder.Build(folder, origin)

	-- 2. Summoning Portal (Circular Stone Stargate in NW / Bridge-Right Quadrant)
	local summonCfg = layout.SummoningPortal
	local summonCF = origin * CFrame.new(summonCfg.Offset) * CFrame.Angles(0, summonCfg.RotationY or math.rad(-135), 0)
	local summonInteract = Architecture.BuildSummoning(folder, summonCF)
	local summonModel = folder:FindFirstChild("Building_Summoning")
	if summonModel then
		summonModel:SetAttribute("Facility", "Summoning")
	end
	attachPrompt(
		summonInteract,
		"FacilityHUDPrompt",
		"Summoning",
		"Summoning Portal",
		summonCfg.PromptText or "Summon Heroes",
		summonCfg.Keybind or Enum.KeyCode.F,
		16
	)
	syncPlotFacilityAnchor(plot, "Summoning", summonInteract.CFrame)

	-- 3. Playtime & Power Leaderboard Assets (Ground-based stands & arch along North Wall)
	alignPlaytimeBoardToWall(plot, origin)
	alignPowerBoardToWall(plot, origin)

	-- 4. Market Cluster (4-Stall Merchant Bazaar in NE Corner)
	local marketCfg = layout.Market
	local marketCF = origin * CFrame.new(marketCfg.Offset) * CFrame.Angles(0, marketCfg.RotationY or math.rad(-145), 0)
	local marketInteract = Architecture.BuildMarket(folder, marketCF)
	local marketModel = folder:FindFirstChild("Building_Market")
	if marketModel then
		marketModel:SetAttribute("Facility", "Market")
	end
	attachPrompt(
		marketInteract,
		"FacilityHUDPrompt",
		"Market",
		"The Market",
		marketCfg.PromptText or "Open Market",
		marketCfg.Keybind or Enum.KeyCode.F,
		16
	)
	syncPlotFacilityAnchor(plot, "Market", marketInteract.CFrame)

	-- 5. Synthesis Chamber / The Pit (Monumental Domed Arcane Rotunda in SW Corner)
	local pitCfg = layout.SynthesisChamber
	local pitCF = origin * CFrame.new(pitCfg.Offset) * CFrame.Angles(0, pitCfg.RotationY or math.rad(42), 0)
	local pitInteract = Architecture.BuildThePit(folder, pitCF)
	local pitModel = folder:FindFirstChild("Building_ThePit")
	if pitModel then
		pitModel:SetAttribute("Facility", "ThePit")
	end
	-- One [F] prompt for the whole Pit; its screen has Synthesis and Promotion tabs.
	attachPrompt(
		pitInteract,
		"FacilityHUDPrompt",
		"Pit",
		"The Pit",
		pitCfg.PromptText or "Synthesis & Promotion",
		pitCfg.Keybind or Enum.KeyCode.F,
		16
	)
	syncPlotFacilityAnchor(plot, "Synthesis", pitInteract.CFrame)
	-- Strip the old Promotion Altar anchor's bare prompt as well.
	syncPlotFacilityAnchor(plot, "Promotion", pitInteract.CFrame)

	-- 6. Blacksmith Forge (Open-Air Stone Hearth & Anvil against Dividing Wall)
	local forgeCfg = layout.BlacksmithForge
	local forgeCF = origin * CFrame.new(forgeCfg.Offset) * CFrame.Angles(0, forgeCfg.RotationY or math.rad(180), 0)
	local forgeInteract = Architecture.BuildBlacksmith(folder, forgeCF)
	local forgeModel = folder:FindFirstChild("Building_Blacksmith")
	if forgeModel then
		forgeModel:SetAttribute("Facility", "Blacksmith")
	end
	attachPrompt(
		forgeInteract,
		"BlacksmithPrompt",
		"Forge",
		"Blacksmith Forge",
		forgeCfg.PromptText or "Blacksmith Forge",
		forgeCfg.Keybind or Enum.KeyCode.F,
		15
	)
	syncPlotFacilityAnchor(plot, "Blacksmith", forgeInteract.CFrame)

	-- 7. Training Area (28-Stud Circular Cobblestone Ring in SE Corner)
	local trainCfg = layout.TrainingArea
	local trainCF = origin * CFrame.new(trainCfg.Offset) * CFrame.Angles(0, trainCfg.RotationY or 0, 0)
	local trainInteract = Architecture.BuildTrainingGrounds(folder, trainCF)
	local trainModel = folder:FindFirstChild("Building_TrainingGrounds")
	if trainModel then
		trainModel:SetAttribute("Facility", "TrainingGrounds")
	end
	attachPrompt(
		trainInteract,
		"FacilityHUDPrompt",
		"TrainingGrounds",
		"Training Grounds",
		trainCfg.PromptText or "Training Grounds",
		trainCfg.Keybind or Enum.KeyCode.F,
		16
	)
	syncPlotFacilityAnchor(plot, "TrainingGrounds", trainInteract.CFrame)

	-- 8. Guardpost Outskirts (Timber Palisade Watch-Post & Campfire in Eastern Forest)
	local gpCfg = layout.Guardpost
	local gpCF = origin * CFrame.new(gpCfg.Offset) * CFrame.Angles(0, gpCfg.RotationY or 0, 0)
	local gpInteract = Architecture.BuildGuardPost(folder, gpCF)
	local gpModel = folder:FindFirstChild("Building_GuardPost")
	if gpModel then
		gpModel:SetAttribute("Facility", "GuardPost")
	end
	attachPrompt(
		gpInteract,
		"FacilityHUDPrompt",
		"GuardPost",
		"Outskirts Guard Post",
		gpCfg.PromptText or "Guardpost",
		gpCfg.Keybind or Enum.KeyCode.F,
		16
	)
	syncPlotFacilityAnchor(plot, "GuardPost", gpInteract.CFrame)

	-- 9. Command Post (War Banner for Squad Management & Architect's Table for Fortress Tree)
	local bannerCF = origin * CFrame.new(-22, 0, -24)
	local tableCF = origin * CFrame.new(-24, 0, 16) * CFrame.Angles(0, math.rad(35), 0)
	local cmdAnchors = Architecture.BuildCommandPost(folder, bannerCF, tableCF)

	attachPrompt(
		cmdAnchors.SquadBanner,
		"FacilityHUDPrompt",
		"SquadManagement",
		"War Banner",
		"Deploy & Manage Squad",
		Enum.KeyCode.F,
		14
	)
	syncPlotFacilityAnchor(plot, "SquadManagement", cmdAnchors.SquadBanner.CFrame)

	attachPrompt(
		cmdAnchors.ArchitectTable,
		"FacilityHUDPrompt",
		"FortressTree",
		"Architect's Table",
		"Open Upgrades",
		Enum.KeyCode.F,
		14
	)

	-- Compatibility alias models for external references (Onboarding arrows & HeroNavigation)
	for _, aliasDef in ipairs({
		{ Name = "Building_Synthesis", Fac = "Synthesis", Ref = pitInteract },
		{ Name = "Building_Promotion", Fac = "Promotion", Ref = pitInteract },
		{ Name = "Building_SquadManagement", Fac = "SquadManagement", Ref = cmdAnchors.SquadBanner },
		{ Name = "Building_ArchitectTable", Fac = "ArchitectTable", Ref = cmdAnchors.ArchitectTable },
	}) do
		local alias = Instance.new("Model")
		alias.Name = aliasDef.Name
		alias:SetAttribute("Facility", aliasDef.Fac)
		local p = Instance.new("Part")
		p.Name = "FacilityInteraction"
		p.Size = Vector3.new(1, 1, 1)
		p.CFrame = aliasDef.Ref.CFrame
		p.Anchored = true
		p.Transparency = 1
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Parent = alias
		alias.PrimaryPart = p
		alias.Parent = folder
	end

	if existing then
		existing:Destroy()
	end
	folder.Name = "PlotBuildings"
	FacilityPresence.Reapply(plot)
	return folder
end

return Buildings
