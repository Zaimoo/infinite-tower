--!strict
-- StarterPlayerScripts/Rendering/FacilityWorkerController.client.luau
-- Client-rendered physical & visual loop for stationed workers in:
--   * The Market (`Building_Market`) — Slots 1..4: Hawker, Crate Stockist, Relic Appraiser, Ledger Scribe
--   * Training Grounds (`Building_TrainingGrounds`) — Slots 1..4: Combo Striker, Target Marksman, Kata Specialist, Drill Sergeant
-- Spawns full costumed R15 hero rigs (no overhead BillboardGuis), jogs newly assigned workers
-- from the Central Courtyard Plaza into their specific stall/station, drives distinct per-slot
-- animations + handheld props + dummy recoil wobble, and parks rigs cleanly while in the Tower.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HeroCatalog = require(Shared:WaitForChild("Config"):WaitForChild("HeroCatalog"))
local FacilityWorkerRules = require(Shared:WaitForChild("Util"):WaitForChild("FacilityWorkerRules"))

local Assets = ReplicatedStorage:WaitForChild("Assets")
local ArtPackVisuals = require(Assets:WaitForChild("ArtPackVisuals"))

local HeroRigFolder = Assets:WaitForChild("HeroRig")
local HeroRegistry = require(HeroRigFolder:WaitForChild("HeroRegistry"))
local HeroAnimator = require(HeroRigFolder:WaitForChild("HeroAnimator"))
local HeroLoadout = require(HeroRigFolder:WaitForChild("HeroLoadout"))
local HeroSockets = require(HeroRigFolder:WaitForChild("HeroSockets"))

local CombatVfxFolder = Assets:WaitForChild("CombatVfx")
local VfxPool = require(CombatVfxFolder:WaitForChild("VfxPool"))
local VfxPrimitives = require(CombatVfxFolder:WaitForChild("VfxPrimitives"))
local SkillVfx = require(CombatVfxFolder:WaitForChild("SkillVfx"))

local ThemeFolder = script.Parent.Parent:WaitForChild("UI"):WaitForChild("Hud")
local Theme = require(ThemeFolder:WaitForChild("Theme"))

local VisualContainer = Workspace:FindFirstChild("AdventurerVisualEntities") :: Folder?
if not VisualContainer then
	local created = Instance.new("Folder")
	created.Name = "AdventurerVisualEntities"
	created.Parent = Workspace
	VisualContainer = created
end
local EntitiesFolder = VisualContainer :: Folder
local WorkerVfxPool = VfxPool.new(EntitiesFolder)

local FULL_RATE_DIST = 220
local THROTTLE_DIST = 480
local THROTTLE_STEP = 1 / 15

local GOLD_COLOR = Color3.fromRGB(255, 214, 92)
local MARKET_COLOR = Color3.fromRGB(240, 184, 78)
local RELIC_COLOR = Color3.fromRGB(115, 232, 255)
local TRAINING_COLOR = Color3.fromRGB(235, 92, 82)
local KATA_COLOR = Color3.fromRGB(175, 224, 255)
local STRAW_COLOR = Color3.fromRGB(232, 200, 118)

local RANGED_WEAPONS: { [string]: boolean } = table.freeze({
	BOW = true,
	STAFF = true,
	TOME = true,
})

local COMBO_TIERS = table.freeze({ 1, 1, 2, 3 })
local TIER_ACTIONS = table.freeze({
	[1] = "AttackBasic",
	[2] = "AttackSpecial",
	[3] = "AttackSkill",
})

type DummyPartRest = {
	Part: BasePart,
	OffsetFromPivot: CFrame,
}

type DummyWobbleState = {
	PivotWorld: CFrame,
	Parts: { DummyPartRest },
	AxisWorld: Vector3,
	StartClock: number,
	AmplitudeRad: number,
	Settled: boolean,
}

type WorkerVisual = {
	UUID: string,
	FacilityId: FacilityWorkerRules.WorkerFacilityId,
	Slot: number,
	SyntheticNetId: number,
	TemplateId: string,
	Archetype: string,
	Rarity: number,
	ArtifactKey: string,
	WeaponType: string,
	ComaUntil: number,
	Model: Model,
	RootPart: Part,
	Rig: Model?,
	Animator: HeroAnimator.HeroAnimator?,
	Highlight: Highlight,
	PropModel: Model?,
	PropKind: FacilityWorkerRules.PropKind,
	PropVisible: boolean,
	LocalPos: Vector3,
	Yaw: number,
	RunInWaypoints: { Vector3 }?,
	RunInIndex: number,
	Phase: number,
	PhaseUntil: number,
	SubCounter: number,
	NextActionAt: number,
	NextMoteAt: number,
}

type PlotWorkerDirector = {
	PlotIndex: number,
	Plot: Model,
	Workers: { [string]: WorkerVisual },
	DummyStates: { [number]: DummyWobbleState },
	DummySourceModel: Model?,
	Dirty: boolean,
	Initialized: boolean,
	Parked: boolean,
	ThrottleAccum: number,
	Connections: { RBXScriptConnection },
	ContainerConns: { RBXScriptConnection },
}

local PlotDirectors: { [number]: PlotWorkerDirector } = {}
local ensuredHeroesOnce = false

local function ensureHeroPrefabs()
	if ensuredHeroesOnce then
		return
	end
	ensuredHeroesOnce = true
	local heroes = Assets:FindFirstChild("Heroes")
	if not heroes or #heroes:GetChildren() == 0 then
		pcall(HeroRegistry.EnsureHeroes)
	end
end

local function resolvePlotOrigin(plot: Model): CFrame?
	local buildings = plot:FindFirstChild("PlotBuildings")
	if buildings then
		local attr = buildings:GetAttribute("Origin")
		if typeof(attr) == "CFrame" then
			return attr
		end
	end
	local island = plot:FindFirstChild("FloatingFortressIsland")
	local top = island and island:FindFirstChild("IslandTopSurface")
	if top and top:IsA("BasePart") then
		local surfaceY = top.Position.Y + top.Size.Y * 0.5
		if top.Size.Z > 200 then
			return CFrame.new(top.Position.X, surfaceY, top.Position.Z) * top.CFrame.Rotation * CFrame.new(0, 0, -70)
		end
		return CFrame.new(top.Position.X, surfaceY, top.Position.Z) * top.CFrame.Rotation
	end
	local spawn = plot:FindFirstChild("PlotSpawn")
	if spawn and spawn:IsA("BasePart") then
		local surfaceY = spawn.Position.Y - spawn.Size.Y * 0.5
		return CFrame.new(spawn.Position.X, surfaceY, spawn.Position.Z) * spawn.CFrame.Rotation * CFrame.new(0, 0, 80)
	end
	return nil
end

local function lerpAngle(a: number, b: number, t: number): number
	local diff = (b - a + math.pi) % (math.pi * 2) - math.pi
	return a + diff * math.clamp(t, 0, 1)
end

local function yawTowards(fromLocal: Vector3, toLocal: Vector3, fallback: number): number
	local dx = toLocal.X - fromLocal.X
	local dz = toLocal.Z - fromLocal.Z
	if dx * dx + dz * dz < 1e-4 then
		return fallback
	end
	return math.atan2(-dx, -dz)
end

local function worldRootCFrame(origin: CFrame, localPos: Vector3, rootHeight: number, yaw: number): CFrame
	return origin * CFrame.new(localPos.X, localPos.Y + rootHeight, localPos.Z) * CFrame.Angles(0, yaw, 0)
end

local function stepTowards(current: Vector3, goal: Vector3, maxStep: number): (Vector3, number)
	local dx = goal.X - current.X
	local dz = goal.Z - current.Z
	local dist = math.sqrt(dx * dx + dz * dz)
	if dist <= 1e-3 then
		return goal, 0
	end
	if dist <= maxStep then
		return goal, dist
	end
	local ratio = maxStep / dist
	return Vector3.new(
		current.X + dx * ratio,
		current.Y + (goal.Y - current.Y) * ratio,
		current.Z + dz * ratio
	), maxStep
end

local function setBowArrowHidden(rig: Model?, hidden: boolean)
	if not rig then
		return
	end
	local weapon = rig:FindFirstChild(HeroSockets.EQUIPPED_NAME)
	local arrow = weapon and weapon:FindFirstChild("HunterArrow", true)
	if not arrow then
		return
	end
	for _, part in arrow:GetDescendants() do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

local function shotOrigin(rig: Model?, fallbackRoot: BasePart): Vector3
	if rig then
		local weapon = rig:FindFirstChild(HeroSockets.EQUIPPED_NAME)
		local nock = weapon and weapon:FindFirstChild("Nock", true)
		if nock and nock:IsA("Attachment") then
			return nock.WorldPosition
		end
		return rig:GetPivot().Position + Vector3.new(0, 1.5, 0)
	end
	return fallbackRoot.Position + Vector3.new(0, 1.5, 0)
end

--============================================================================
-- PROCEDURAL HANDHELD PROPS FOR MARKET SLOTS
--============================================================================
local function makePropPart(
	parent: Instance,
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.Color = color
	p.Material = material
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function weldParts(part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame?)
	local w = Instance.new("Weld")
	w.Part0 = part0
	w.Part1 = part1
	w.C0 = c0
	w.C1 = c1 or CFrame.identity
	w.Parent = part1
end

local function attachMarketProp(rig: Model, propKind: FacilityWorkerRules.PropKind): Model?
	local existing = rig:FindFirstChild("FacilityWorkerProp")
	if existing then
		existing:Destroy()
	end
	if propKind == "NONE" then
		return nil
	end

	local propModel = Instance.new("Model")
	propModel.Name = "FacilityWorkerProp"

	if propKind == "CRATE" then
		local upperTorso = rig:FindFirstChild("UpperTorso") :: BasePart?
		if not upperTorso then
			propModel:Destroy()
			return nil
		end
		local crate = makePropPart(
			propModel,
			"MerchantCrate",
			Vector3.new(1.75, 1.05, 1.35),
			Color3.fromRGB(138, 96, 56),
			Enum.Material.WoodPlanks
		)
		local rim = makePropPart(
			propModel,
			"CrateRim",
			Vector3.new(1.85, 0.16, 1.45),
			Color3.fromRGB(98, 66, 38),
			Enum.Material.Wood
		)
		weldParts(crate, rim, CFrame.new(0, 0.46, 0))

		local goodA = makePropPart(
			propModel,
			"CrateGoodA",
			Vector3.new(0.55, 0.55, 0.55),
			Color3.fromRGB(235, 188, 56),
			Enum.Material.SmoothPlastic,
			Enum.PartType.Ball
		)
		weldParts(crate, goodA, CFrame.new(-0.38, 0.52, -0.12))

		local goodB = makePropPart(
			propModel,
			"CrateGoodB",
			Vector3.new(0.52, 0.52, 0.52),
			Color3.fromRGB(218, 68, 58),
			Enum.Material.SmoothPlastic,
			Enum.PartType.Ball
		)
		weldParts(crate, goodB, CFrame.new(0.36, 0.50, 0.14))

		propModel.PrimaryPart = crate
		propModel.Parent = rig
		weldParts(upperTorso, crate, CFrame.new(0, 0.18, -1.25))
		return propModel
	elseif propKind == "RELIC_ORB" then
		local leftHand = rig:FindFirstChild("LeftHand") :: BasePart?
		if not leftHand then
			propModel:Destroy()
			return nil
		end
		local base = makePropPart(
			propModel,
			"RelicPedestal",
			Vector3.new(0.52, 0.22, 0.52),
			Color3.fromRGB(214, 172, 72),
			Enum.Material.Metal
		)
		local orb = makePropPart(
			propModel,
			"RelicOrb",
			Vector3.new(0.68, 0.68, 0.68),
			Color3.fromRGB(110, 232, 255),
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		weldParts(base, orb, CFrame.new(0, 0.42, 0))
		propModel.PrimaryPart = base
		propModel.Parent = rig
		local grip = leftHand:FindFirstChild("LeftGripAttachment") :: Attachment?
		local c0 = if grip then grip.CFrame * CFrame.new(0, 0.22, 0) else CFrame.new(0, -0.15, -0.25)
		weldParts(leftHand, base, c0)
		return propModel
	elseif propKind == "LEDGER" then
		local leftHand = rig:FindFirstChild("LeftHand") :: BasePart?
		local rightHand = rig:FindFirstChild("RightHand") :: BasePart?
		if not leftHand then
			propModel:Destroy()
			return nil
		end
		local cover = makePropPart(
			propModel,
			"LedgerCover",
			Vector3.new(1.15, 0.14, 0.88),
			Color3.fromRGB(92, 48, 32),
			Enum.Material.SmoothPlastic
		)
		local pageL = makePropPart(
			propModel,
			"LedgerPageL",
			Vector3.new(0.50, 0.08, 0.78),
			Color3.fromRGB(242, 232, 206),
			Enum.Material.SmoothPlastic
		)
		weldParts(cover, pageL, CFrame.new(-0.27, 0.09, 0) * CFrame.Angles(0, 0, math.rad(8)))

		local pageR = makePropPart(
			propModel,
			"LedgerPageR",
			Vector3.new(0.50, 0.08, 0.78),
			Color3.fromRGB(242, 232, 206),
			Enum.Material.SmoothPlastic
		)
		weldParts(cover, pageR, CFrame.new(0.27, 0.09, 0) * CFrame.Angles(0, 0, math.rad(-8)))

		local clasp = makePropPart(
			propModel,
			"LedgerSpineGold",
			Vector3.new(0.14, 0.18, 0.90),
			Color3.fromRGB(224, 182, 74),
			Enum.Material.Metal
		)
		weldParts(cover, clasp, CFrame.new(0, 0.02, 0))

		if rightHand then
			local quill = makePropPart(
				propModel,
				"LedgerQuill",
				Vector3.new(0.09, 0.72, 0.09),
				Color3.fromRGB(245, 226, 152),
				Enum.Material.SmoothPlastic
			)
			local rGrip = rightHand:FindFirstChild("RightGripAttachment") :: Attachment?
			local qc0 = if rGrip then rGrip.CFrame * CFrame.new(0, 0.22, 0) else CFrame.new(0, -0.1, -0.2)
			weldParts(rightHand, quill, qc0)
		end

		propModel.PrimaryPart = cover
		propModel.Parent = rig
		local lGrip = leftHand:FindFirstChild("LeftGripAttachment") :: Attachment?
		local lc0 = if lGrip
			then lGrip.CFrame * CFrame.new(0, 0.25, 0.08) * CFrame.Angles(math.rad(-75), 0, 0)
			else CFrame.new(0, 0.15, -0.35)
		weldParts(leftHand, cover, lc0)
		return propModel
	end

	propModel:Destroy()
	return nil
end

local function setPropVisible(worker: WorkerVisual, visible: boolean)
	if worker.PropVisible == visible then
		return
	end
	worker.PropVisible = visible
	if not worker.PropModel then
		return
	end
	for _, d in worker.PropModel:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = if visible then 0 else 1
		end
	end
end

--============================================================================
-- TRAINING DUMMY PHYSICAL RECOIL WOBBLE
--============================================================================
local function ensureDummyCache(director: PlotWorkerDirector)
	local buildings = director.Plot:FindFirstChild("PlotBuildings")
	local trainingModel = buildings and buildings:FindFirstChild("Building_TrainingGrounds") :: Model?
	if trainingModel == director.DummySourceModel then
		return
	end
	-- Restore any previous parts before switching models
	for _, state in pairs(director.DummyStates) do
		for _, pr in ipairs(state.Parts) do
			if pr.Part.Parent then
				pr.Part.CFrame = state.PivotWorld * pr.OffsetFromPivot
			end
		end
	end
	table.clear(director.DummyStates)
	director.DummySourceModel = trainingModel
	if not trainingModel then
		return
	end

	for idx = 1, 4 do
		local basePart = trainingModel:FindFirstChild("DummyBase_" .. idx) :: BasePart?
		if not basePart then
			continue
		end
		local pivotWorld = basePart.CFrame
		local partNames = {
			"TrainingDummy_" .. idx,
			"DummyCrossbar_" .. idx,
			"DummyTorso_" .. idx,
			"DummyHead_" .. idx,
			"DummyTargetBand_" .. idx,
		}
		local list: { DummyPartRest } = {}
		for _, name in ipairs(partNames) do
			local p = trainingModel:FindFirstChild(name)
			if p and p:IsA("BasePart") then
				table.insert(list, {
					Part = p,
					OffsetFromPivot = pivotWorld:ToObjectSpace(p.CFrame),
				})
			end
		end
		if #list > 0 then
			director.DummyStates[idx] = {
				PivotWorld = pivotWorld,
				Parts = list,
				AxisWorld = Vector3.new(1, 0, 0),
				StartClock = -10,
				AmplitudeRad = 0,
				Settled = true,
			}
		end
	end
end

local function triggerDummyWobble(
	director: PlotWorkerDirector,
	dummyIndex: number,
	attackerWorldPos: Vector3,
	amplitudeDeg: number
)
	ensureDummyCache(director)
	local state = director.DummyStates[dummyIndex]
	if not state then
		return
	end
	local pushDir = Vector3.new(
		state.PivotWorld.Position.X - attackerWorldPos.X,
		0,
		state.PivotWorld.Position.Z - attackerWorldPos.Z
	)
	if pushDir.Magnitude < 1e-3 then
		pushDir = Vector3.new(0, 0, 1)
	else
		pushDir = pushDir.Unit
	end
	-- Right-hand rule: Vector3.yAxis:Cross(pushDir) tilts the top of the dummy toward pushDir!
	local tiltAxis = Vector3.yAxis:Cross(pushDir)
	if tiltAxis.Magnitude < 1e-3 then
		tiltAxis = Vector3.xAxis
	else
		tiltAxis = tiltAxis.Unit
	end

	state.AxisWorld = tiltAxis
	state.StartClock = os.clock()
	state.AmplitudeRad = math.rad(amplitudeDeg)
	state.Settled = false

	local vfxNow = Workspace:GetServerTimeNow()
	local torsoWorld = state.PivotWorld.Position + Vector3.new(0, 3.6, 0)
	VfxPrimitives.Burst(WorkerVfxPool, torsoWorld, STRAW_COLOR, 1.55, vfxNow, 0.22)
	VfxPrimitives.Motes(WorkerVfxPool, torsoWorld, STRAW_COLOR, vfxNow, 4, 0.55)
end

local function stepDummyWobbles(director: PlotWorkerDirector, nowClock: number)
	for _, state in pairs(director.DummyStates) do
		if state.Settled then
			continue
		end
		local elapsed = nowClock - state.StartClock
		if elapsed >= 0.72 then
			for _, pr in ipairs(state.Parts) do
				if pr.Part.Parent then
					pr.Part.CFrame = state.PivotWorld * pr.OffsetFromPivot
				end
			end
			state.Settled = true
		else
			local angle = state.AmplitudeRad * math.exp(-6.2 * elapsed) * math.sin(25 * elapsed)
			local worldTilt = CFrame.fromAxisAngle(state.AxisWorld, angle)
			local rotatedPivot = CFrame.new(state.PivotWorld.Position) * worldTilt * state.PivotWorld.Rotation
			for _, pr in ipairs(state.Parts) do
				if pr.Part.Parent then
					pr.Part.CFrame = rotatedPivot * pr.OffsetFromPivot
				end
			end
		end
	end
end

local function resetAllDummies(director: PlotWorkerDirector)
	for _, state in pairs(director.DummyStates) do
		for _, pr in ipairs(state.Parts) do
			if pr.Part.Parent then
				pr.Part.CFrame = state.PivotWorld * pr.OffsetFromPivot
			end
		end
		state.Settled = true
	end
end

--============================================================================
-- WORKER VISUAL CREATION & EQUIPMENT
--============================================================================
local function destroyWorkerVisual(worker: WorkerVisual)
	if worker.Model then
		worker.Model:Destroy()
	end
end

local function configureWorkerEquipment(
	worker: WorkerVisual,
	slotSpec: FacilityWorkerRules.FacilitySlotSpec,
	artifactId: string,
	artifactType: string,
	artifactRarity: number
)
	local resolvedWeapon = FacilityWorkerRules.ResolveHeroWeaponType(worker.Archetype, artifactType)
	local key = `{worker.FacilityId}|{worker.Slot}|{slotSpec.PropKind}|{artifactId}|{resolvedWeapon}|{artifactRarity}`
	if worker.ArtifactKey == key then
		return
	end
	worker.ArtifactKey = key

	if not worker.Rig then
		return
	end

	if slotSpec.EquipHeroWeapon then
		if worker.PropModel then
			worker.PropModel:Destroy()
			worker.PropModel = nil
		end
		worker.PropKind = "NONE"
		local equipped = HeroLoadout.Equip(worker.Model, worker.Rig, artifactId, resolvedWeapon, artifactRarity)
		local equippedType = equipped or resolvedWeapon
		worker.WeaponType = equippedType
		if worker.Animator then
			worker.Animator:SetWeaponType(equippedType)
		end
	else
		HeroLoadout.Unequip(worker.Model, worker.Rig)
		worker.WeaponType = "UNARMED"
		if worker.Animator then
			worker.Animator:SetWeaponType("UNARMED")
		end
		worker.PropKind = slotSpec.PropKind
		worker.PropModel = attachMarketProp(worker.Rig, slotSpec.PropKind)
		worker.PropVisible = true
		if slotSpec.PropKind == "CRATE" then
			-- Crate Stockist starts at counter stocking; crate appears when hauling from rear barrels
			setPropVisible(worker, false)
		end
	end
end

local function buildRunInWaypoints(
	facilityId: FacilityWorkerRules.WorkerFacilityId,
	slotSpec: FacilityWorkerRules.FacilitySlotSpec
): { Vector3 }
	local pts: { Vector3 } = {}
	local baseList = if facilityId == "Market"
		then FacilityWorkerRules.CourtyardRunIn.Market
		else FacilityWorkerRules.CourtyardRunIn.TrainingGrounds
	for _, p in ipairs(baseList) do
		table.insert(pts, p)
	end
	table.insert(pts, slotSpec.EntryWaypoint)
	table.insert(pts, slotSpec.Primary.Pos)
	return pts
end

local function createWorkerVisual(
	director: PlotWorkerDirector,
	origin: CFrame,
	entry: Configuration,
	facilityId: FacilityWorkerRules.WorkerFacilityId,
	runFromCourtyard: boolean
): WorkerVisual
	ensureHeroPrefabs()

	local uuid = tostring(entry:GetAttribute("UUID") or entry.Name)
	local slot = math.clamp(tonumber(entry:GetAttribute("Slot")) or 1, 1, 4)
	local templateId = tostring(entry:GetAttribute("TemplateId") or "hero_han")
	local archetype = tostring(entry:GetAttribute("Archetype") or "Vanguard")
	local rarity = tonumber(entry:GetAttribute("Rarity")) or 1
	local artifactId = tostring(entry:GetAttribute("EquippedArtifactId") or "")
	local artifactType = tostring(entry:GetAttribute("EquippedArtifactType") or "")
	local artifactRarity = tonumber(entry:GetAttribute("EquippedArtifactRarity")) or 1
	local comaUntil = tonumber(entry:GetAttribute("ComaUntilTimestamp")) or 0
	local seed = HeroCatalog.Seeds[templateId]

	local slotSpec = FacilityWorkerRules.GetSlotSpec(facilityId, slot) :: FacilityWorkerRules.FacilitySlotSpec
	local waypoints = if runFromCourtyard then buildRunInWaypoints(facilityId, slotSpec) else nil
	local startLocal = if waypoints then waypoints[1] else slotSpec.Primary.Pos
	local lookTarget = if waypoints and waypoints[2] then waypoints[2] else slotSpec.Primary.LookAt
	local initialYaw = yawTowards(startLocal, lookTarget, 0)

	local model = Instance.new("Model")
	model.Name = `FacilityWorker_{director.PlotIndex}_{facilityId}_{slot}`

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 4, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CastShadow = false
	root.CFrame = worldRootCFrame(origin, startLocal, 3.0, initialYaw)
	root.Parent = model
	model.PrimaryPart = root

	local art = ArtPackVisuals.Attach(model, { IsHero = true, TemplateId = templateId }, root, root.Size)
	if not art then
		root.Transparency = 0
		root.Color = (seed and seed.Color) or Color3.fromRGB(130, 205, 95)
		root.Material = Enum.Material.SmoothPlastic
	end
	local rig = if art and art:GetAttribute("HeroRigVersion") ~= nil then art else nil

	local hl = Instance.new("Highlight")
	hl.Name = "FacilityWorkerHighlight"
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.FillColor = Color3.fromRGB(255, 245, 210)
	hl.OutlineColor = Theme.RarityColor(rarity):Lerp(Color3.new(1, 1, 1), 0.35)
	hl.FillTransparency = 1
	hl.OutlineTransparency = 0.45
	hl.Adornee = art or model
	hl.Parent = model

	model.Parent = if director.Parked then nil else EntitiesFolder

	local animator: HeroAnimator.HeroAnimator? = nil
	if rig then
		animator = HeroAnimator.new(rig, {
			HeroId = templateId,
			WeaponType = "UNARMED",
		})
	end

	local facilityOffset = if facilityId == "Market" then 0 else 16
	local worker: WorkerVisual = {
		UUID = uuid,
		FacilityId = facilityId,
		Slot = slot,
		SyntheticNetId = 40000 + director.PlotIndex * 32 + facilityOffset + slot,
		TemplateId = templateId,
		Archetype = archetype,
		Rarity = rarity,
		ArtifactKey = "",
		WeaponType = "UNARMED",
		ComaUntil = comaUntil,
		Model = model,
		RootPart = root,
		Rig = rig,
		Animator = animator,
		Highlight = hl,
		PropModel = nil,
		PropKind = "NONE",
		PropVisible = true,
		LocalPos = startLocal,
		Yaw = initialYaw,
		RunInWaypoints = waypoints,
		RunInIndex = 2,
		Phase = 1,
		PhaseUntil = os.clock() + 3.2 + (slot - 1) * 0.65,
		SubCounter = 0,
		NextActionAt = os.clock() + 0.5 + (slot - 1) * 0.25,
		NextMoteAt = os.clock() + 1.4 + (slot - 1) * 0.5,
	}

	configureWorkerEquipment(worker, slotSpec, artifactId, artifactType, artifactRarity)

	if animator then
		animator.OnMarker = function(markerName: string, action: HeroAnimator.Action)
			if markerName == "Nock" or markerName == "End" then
				setBowArrowHidden(worker.Rig, false)
				return
			end
			if markerName ~= "Release" then
				return
			end
			if animator.WeaponType == "BOW" then
				setBowArrowHidden(worker.Rig, true)
			end
			local data = action.Data
			if not data then
				return
			end
			local curOrigin = resolvePlotOrigin(director.Plot)
			if not curOrigin then
				return
			end

			local serverNow = Workspace:GetServerTimeNow()
			local fromWorld = shotOrigin(worker.Rig, worker.RootPart)
			local aimWorld: Vector3 = curOrigin:PointToWorldSpace(data.AimPlot)
			local isRanged = RANGED_WEAPONS[animator.WeaponType] == true
			local dist = (aimWorld - fromWorld).Magnitude
			local travel = if isRanged then math.clamp(dist / 58, 0.06, 0.42) else 0.02

			SkillVfx.Play(WorkerVfxPool, {
				HeroId = worker.TemplateId,
				WeaponType = animator.WeaponType,
				Cue = {
					NetId = worker.SyntheticNetId,
					Tier = data.Tier or 1,
					StartServerTime = serverNow,
					ReleaseSeconds = 0,
					TravelSeconds = travel,
					Aim = aimWorld,
				},
				Origin = fromWorld,
				Target = function(): Vector3
					return aimWorld
				end,
				Self = function(): Vector3
					return Vector3.new(worker.RootPart.Position.X, aimWorld.Y, worker.RootPart.Position.Z)
				end,
				Allies = function(): { Vector3 }
					return { Vector3.new(worker.RootPart.Position.X, aimWorld.Y, worker.RootPart.Position.Z) }
				end,
				Now = serverNow,
				Shake = nil,
			})

			if data.DummyIndex then
				local amp = if (data.Tier or 1) >= 3 then 16 elseif (data.Tier or 1) == 2 then 12 else 9
				VfxPrimitives.At(WorkerVfxPool, serverNow + travel, function()
					triggerDummyWobble(director, data.DummyIndex, worker.RootPart.Position, amp)
				end)
			elseif data.IsBullseye then
				VfxPrimitives.At(WorkerVfxPool, serverNow + travel, function()
					local hitNow = Workspace:GetServerTimeNow()
					VfxPrimitives.Burst(WorkerVfxPool, aimWorld, TRAINING_COLOR, 1.4, hitNow, 0.22)
					VfxPrimitives.Motes(WorkerVfxPool, aimWorld, GOLD_COLOR, hitNow, 4, 0.55)
				end)
			end
		end
	end

	if runFromCourtyard then
		local nowServer = Workspace:GetServerTimeNow()
		local spawnWorld = origin:PointToWorldSpace(startLocal)
		local accent = if facilityId == "Market" then MARKET_COLOR else TRAINING_COLOR
		VfxPrimitives.Ring(WorkerVfxPool, {
			Center = spawnWorld + Vector3.new(0, 0.1, 0),
			From = 0.8,
			To = 4.8,
			Color = accent,
			StartAt = nowServer,
			EndAt = nowServer + 0.45,
			Width = 0.55,
		})
		VfxPrimitives.Motes(WorkerVfxPool, spawnWorld + Vector3.new(0, 1.4, 0), GOLD_COLOR, nowServer, 5, 0.8)
	end

	return worker
end

--============================================================================
-- SYNC ACTIVE PLOT WORKERS
--============================================================================
local function syncDirectorWorkers(director: PlotWorkerDirector, origin: CFrame)
	director.Dirty = false
	local plot = director.Plot
	local ownerUserId = tonumber(plot:GetAttribute("OwnerUserId")) or 0
	if ownerUserId <= 0 then
		for uuid, w in pairs(director.Workers) do
			destroyWorkerVisual(w)
			director.Workers[uuid] = nil
		end
		resetAllDummies(director)
		director.Initialized = false
		return
	end

	local marketLevel = tonumber(plot:GetAttribute("FacilityLevel_Market")) or 0
	local trainingLevel = tonumber(plot:GetAttribute("FacilityLevel_TrainingGrounds")) or 0
	local canRunIn = director.Initialized and plot:GetAttribute("PlotWorkersSynced") == true

	local container = plot:FindFirstChild("ActivePlotWorkers")
	local seenUUIDs: { [string]: boolean } = {}

	if container then
		for _, child in ipairs(container:GetChildren()) do
			if not child:IsA("Configuration") then
				continue
			end
			local facilityAttr = tostring(child:GetAttribute("Facility") or "")
			if not FacilityWorkerRules.IsSupportedFacility(facilityAttr) then
				continue
			end
			local facilityId = facilityAttr :: FacilityWorkerRules.WorkerFacilityId
			if facilityId == "Market" and marketLevel <= 0 then
				continue
			end
			if facilityId == "TrainingGrounds" and trainingLevel <= 0 then
				continue
			end

			local uuid = tostring(child:GetAttribute("UUID") or child.Name)
			local slot = math.clamp(tonumber(child:GetAttribute("Slot")) or 1, 1, 4)
			seenUUIDs[uuid] = true

			local existing = director.Workers[uuid]
			if existing and existing.FacilityId ~= facilityId then
				destroyWorkerVisual(existing)
				director.Workers[uuid] = nil
				existing = nil
			end

			if not existing then
				director.Workers[uuid] = createWorkerVisual(director, origin, child, facilityId, canRunIn)
			else
				local prevSlot = existing.Slot
				existing.Slot = slot
				existing.Model.Name = `FacilityWorker_{director.PlotIndex}_{facilityId}_{slot}`
				existing.ComaUntil = tonumber(child:GetAttribute("ComaUntilTimestamp")) or 0
				local slotSpec = FacilityWorkerRules.GetSlotSpec(facilityId, slot) :: FacilityWorkerRules.FacilitySlotSpec
				local artId = tostring(child:GetAttribute("EquippedArtifactId") or "")
				local artType = tostring(child:GetAttribute("EquippedArtifactType") or "")
				local artRarity = tonumber(child:GetAttribute("EquippedArtifactRarity")) or 1
				configureWorkerEquipment(existing, slotSpec, artId, artType, artRarity)
				if prevSlot ~= slot and existing.RunInWaypoints == nil then
					existing.Phase = 1
					existing.PhaseUntil = os.clock() + 3.0
					existing.SubCounter = 0
				end
			end
		end
	end

	for uuid, w in pairs(director.Workers) do
		if not seenUUIDs[uuid] then
			destroyWorkerVisual(w)
			director.Workers[uuid] = nil
		end
	end

	if plot:GetAttribute("PlotWorkersSynced") == true or plot:GetAttribute("OutskirtsSynced") == true then
		director.Initialized = true
	end
end

--============================================================================
-- PER-SLOT PHYSICAL & ANIMATION ROUTINES
--============================================================================
local function moveWorkerToStation(
	worker: WorkerVisual,
	station: FacilityWorkerRules.StationPose,
	speed: number,
	walkClip: string,
	dt: number
): boolean
	local nextPos, moved = stepTowards(worker.LocalPos, station.Pos, speed * dt)
	worker.LocalPos = nextPos
	if moved > 1e-4 then
		local moveYaw = yawTowards(worker.LocalPos, station.Pos, worker.Yaw)
		worker.Yaw = lerpAngle(worker.Yaw, moveYaw, math.clamp(dt * 11, 0, 1))
		if worker.Animator then
			worker.Animator:SetLocomotion(walkClip)
		end
		return false
	end
	local faceYaw = yawTowards(station.Pos, station.LookAt, worker.Yaw)
	worker.Yaw = lerpAngle(worker.Yaw, faceYaw, math.clamp(dt * 10, 0, 1))
	return true
end

local function stepMarketSlotRoutine(
	worker: WorkerVisual,
	slotSpec: FacilityWorkerRules.FacilitySlotSpec,
	origin: CFrame,
	nowClock: number,
	dt: number
)
	local slot = worker.Slot

	if slot == 1 then
		-- Slot 1: Bazaar Hawker — sweeps along Stall_RedAmber counter calling out deals
		local tertiary = slotSpec.Tertiary or slotSpec.Primary
		local targetStation = if worker.Phase == 1
			then slotSpec.Primary
			elseif worker.Phase == 2 then tertiary
			elseif worker.Phase == 3 then slotSpec.Secondary
			else tertiary
		local arrived = moveWorkerToStation(worker, targetStation, 7.5, "Move", dt)
		if arrived then
			if worker.Animator then
				worker.Animator:SetLocomotion("MarketHawker")
			end
			if nowClock >= worker.NextMoteAt then
				worker.NextMoteAt = nowClock + 2.6
				local vfxNow = Workspace:GetServerTimeNow()
				local counterWorld = origin:PointToWorldSpace(worker.LocalPos) + Vector3.new(0, 3.6, 0)
				VfxPrimitives.Motes(WorkerVfxPool, counterWorld, GOLD_COLOR, vfxNow, 3, 0.7)
			end
			if nowClock >= worker.PhaseUntil then
				worker.Phase = (worker.Phase % 4) + 1
				local hold = if worker.Phase == 2 or worker.Phase == 4 then 1.1 else 4.2
				worker.PhaseUntil = nowClock + hold
			end
		end
	elseif slot == 2 then
		-- Slot 2: Crate Stockist — stocks counter, walks to rear barrels, carries MerchantCrate back
		local tertiary = slotSpec.Tertiary or slotSpec.Primary
		if worker.Phase == 1 then
			setPropVisible(worker, false)
			if moveWorkerToStation(worker, slotSpec.Primary, 9.0, "Move", dt) then
				if worker.Animator then
					worker.Animator:SetLocomotion("MarketStock")
				end
				if nowClock >= worker.PhaseUntil then
					worker.Phase = 2
					worker.PhaseUntil = nowClock + 1.0
				end
			end
		elseif worker.Phase == 2 then
			setPropVisible(worker, false)
			if moveWorkerToStation(worker, slotSpec.Secondary, 10.0, "Move", dt) then
				if worker.Animator then
					worker.Animator:SetLocomotion("MarketStock")
				end
				if nowClock >= worker.PhaseUntil then
					setPropVisible(worker, true)
					worker.Phase = 3
					worker.PhaseUntil = nowClock + 3.6
				end
			end
		elseif worker.Phase == 3 then
			setPropVisible(worker, true)
			if moveWorkerToStation(worker, tertiary, 8.2, "MarketCarry", dt) then
				setPropVisible(worker, false)
				if worker.Animator then
					worker.Animator:SetLocomotion("MarketStock")
				end
				if nowClock >= worker.NextMoteAt then
					worker.NextMoteAt = nowClock + 2.8
					local vfxNow = Workspace:GetServerTimeNow()
					local trayWorld = origin:PointToWorldSpace(worker.LocalPos) + Vector3.new(0, 3.5, 0)
					VfxPrimitives.Motes(WorkerVfxPool, trayWorld, MARKET_COLOR, vfxNow, 3, 0.65)
				end
				if nowClock >= worker.PhaseUntil then
					worker.Phase = 1
					worker.PhaseUntil = nowClock + 3.8
				end
			end
		else
			worker.Phase = 1
			worker.PhaseUntil = nowClock + 3.5
		end
	elseif slot == 3 then
		-- Slot 3: Relic Appraiser — holds glowing RelicOrb up to the light, checks rear relic barrel
		local tertiary = slotSpec.Tertiary or slotSpec.Primary
		local targetStation = if worker.Phase == 1
			then slotSpec.Primary
			elseif worker.Phase == 2 then slotSpec.Secondary
			else tertiary
		local arrived = moveWorkerToStation(worker, targetStation, 8.0, "Move", dt)
		if arrived then
			local clipName = if worker.Phase == 2 then "MarketStock" else "MarketAppraiser"
			if worker.Animator then
				worker.Animator:SetLocomotion(clipName)
			end
			if worker.Phase ~= 2 and nowClock >= worker.NextMoteAt then
				worker.NextMoteAt = nowClock + 3.0
				local vfxNow = Workspace:GetServerTimeNow()
				local orbWorld = worker.RootPart.Position + Vector3.new(0, 2.3, 0)
				VfxPrimitives.Motes(WorkerVfxPool, orbWorld, RELIC_COLOR, vfxNow, 3, 0.75)
			end
			if nowClock >= worker.PhaseUntil then
				worker.Phase = (worker.Phase % 3) + 1
				local hold = if worker.Phase == 2 then 2.3 else 4.8
				worker.PhaseUntil = nowClock + hold
			end
		end
	else
		-- Slot 4: Quartermaster Ledger — scribes in GildedLedger & walks to front MarketCrate_2
		local tertiary = slotSpec.Tertiary or slotSpec.Primary
		local targetStation = if worker.Phase == 1
			then slotSpec.Primary
			elseif worker.Phase == 2 then tertiary
			elseif worker.Phase == 3 then slotSpec.Secondary
			else tertiary
		local arrived = moveWorkerToStation(worker, targetStation, 8.5, "Move", dt)
		if arrived then
			if worker.Animator then
				worker.Animator:SetLocomotion("MarketLedger")
			end
			if (worker.Phase == 1 or worker.Phase == 3) and nowClock >= worker.NextMoteAt then
				worker.NextMoteAt = nowClock + 2.9
				local vfxNow = Workspace:GetServerTimeNow()
				local ledgerWorld = worker.RootPart.Position + Vector3.new(0, 2.0, 0)
				VfxPrimitives.Motes(WorkerVfxPool, ledgerWorld, GOLD_COLOR, vfxNow, 2, 0.65)
			end
			if nowClock >= worker.PhaseUntil then
				worker.Phase = (worker.Phase % 4) + 1
				local hold = if worker.Phase == 2 or worker.Phase == 4
					then 0.15
					elseif worker.Phase == 3 then 3.2
					else 4.6
				worker.PhaseUntil = nowClock + hold
			end
		end
	end
end

local function fireTrainingAttack(
	worker: WorkerVisual,
	tier: number,
	aimPlot: Vector3,
	dummyIndex: number?,
	isBullseye: boolean,
	duration: number
)
	if not worker.Animator then
		return
	end
	local actionName = TIER_ACTIONS[tier] or "AttackBasic"
	worker.Animator:PlayAction(actionName, duration, 0, {
		Tier = tier,
		AimPlot = aimPlot,
		DummyIndex = dummyIndex,
		IsBullseye = isBullseye,
	})
end

local function stepTrainingSlotRoutine(
	worker: WorkerVisual,
	slotSpec: FacilityWorkerRules.FacilitySlotSpec,
	origin: CFrame,
	nowClock: number,
	dt: number
)
	local slot = worker.Slot

	if slot == 1 then
		-- Slot 1: Dummy Combo Striker — chains 4-hit weapon combos on Dummy_1 (NE), then Dummy_4 (SE)
		local dummyIndex = if worker.Phase == 1 then 1 else 4
		local targetStation = if worker.Phase == 1 then slotSpec.Primary else slotSpec.Secondary
		local arrived = moveWorkerToStation(worker, targetStation, 12.5, "Move", dt)
		if arrived then
			if worker.Animator then
				worker.Animator:SetLocomotion("Idle")
			end
			if nowClock >= worker.NextActionAt then
				worker.SubCounter += 1
				local tier = COMBO_TIERS[((worker.SubCounter - 1) % #COMBO_TIERS) + 1]
				local dummyPos = FacilityWorkerRules.GetDummyPlotPosition(dummyIndex) + Vector3.new(0, 3.3, 0)
				fireTrainingAttack(worker, tier, dummyPos, dummyIndex, false, 0.92)
				worker.NextActionAt = nowClock + 1.18
				if worker.SubCounter >= 4 then
					worker.SubCounter = 0
					worker.Phase = if worker.Phase == 1 then 2 else 1
					worker.NextActionAt = nowClock + 1.05
				end
			end
		end
	elseif slot == 2 then
		-- Slot 2: Bullseye Marksman — fires volleys into +Z Bullseye, resets form with TrainingKata
		local bullseyeAim = slotSpec.BullseyeTargetPlot
			or FacilityWorkerRules.FacilityToPlot("TrainingGrounds", Vector3.new(0, 4.1, 11.8))
		local tertiary = slotSpec.Tertiary or slotSpec.Primary

		if worker.Phase == 1 or worker.Phase == 3 then
			local markStation = if worker.Phase == 1 then slotSpec.Primary else slotSpec.Secondary
			if moveWorkerToStation(worker, markStation, 11.0, "Move", dt) then
				if worker.Animator then
					worker.Animator:SetLocomotion("Idle")
				end
				if nowClock >= worker.NextActionAt then
					worker.SubCounter += 1
					local tier = if worker.SubCounter == 1
						then 1
						elseif worker.Phase == 1 then 2
						else 3
					fireTrainingAttack(worker, tier, bullseyeAim, nil, true, 0.95)
					worker.NextActionAt = nowClock + 1.30
					if worker.SubCounter >= 2 then
						worker.SubCounter = 0
						worker.Phase = if worker.Phase == 1 then 2 else 4
						worker.PhaseUntil = nowClock + 2.4
					end
				end
			end
		else
			if moveWorkerToStation(worker, tertiary, 10.0, "Move", dt) then
				if worker.Animator then
					worker.Animator:SetLocomotion("TrainingKata")
				end
				if nowClock >= worker.PhaseUntil then
					worker.Phase = if worker.Phase == 2 then 3 else 1
					worker.NextActionAt = nowClock + 0.45
				end
			end
		end
	elseif slot == 3 then
		-- Slot 3: Kata Specialist — western mat TrainingKata -> Dummy_3 lunge strikes -> SW Weapon Rack check
		local tertiary = slotSpec.Tertiary or slotSpec.Primary
		if worker.Phase == 1 then
			if moveWorkerToStation(worker, slotSpec.Primary, 10.5, "Move", dt) then
				if worker.Animator then
					worker.Animator:SetLocomotion("TrainingKata")
				end
				if nowClock >= worker.NextMoteAt then
					worker.NextMoteAt = nowClock + 2.8
					local vfxNow = Workspace:GetServerTimeNow()
					local footWorld = origin:PointToWorldSpace(worker.LocalPos) + Vector3.new(0, 0.12, 0)
					VfxPrimitives.Ring(WorkerVfxPool, {
						Center = footWorld,
						From = 0.6,
						To = 3.2,
						Color = KATA_COLOR,
						StartAt = vfxNow,
						EndAt = vfxNow + 0.38,
						Width = 0.35,
					})
				end
				if nowClock >= worker.PhaseUntil then
					worker.Phase = 2
					worker.SubCounter = 0
					worker.NextActionAt = nowClock + 0.35
				end
			end
		elseif worker.Phase == 2 then
			if moveWorkerToStation(worker, slotSpec.Secondary, 13.5, "Move", dt) then
				if worker.Animator then
					worker.Animator:SetLocomotion("Idle")
				end
				if nowClock >= worker.NextActionAt then
					worker.SubCounter += 1
					local tier = if worker.SubCounter == 1 then 2 else 3
					local dummyPos = FacilityWorkerRules.GetDummyPlotPosition(3) + Vector3.new(0, 3.3, 0)
					fireTrainingAttack(worker, tier, dummyPos, 3, false, 0.92)
					worker.NextActionAt = nowClock + 1.15
					if worker.SubCounter >= 2 then
						worker.SubCounter = 0
						worker.Phase = 3
						worker.PhaseUntil = nowClock + 2.5
					end
				end
			end
		else
			if moveWorkerToStation(worker, tertiary, 9.5, "Move", dt) then
				if worker.Animator then
					worker.Animator:SetLocomotion("MarketAppraiser")
				end
				if nowClock >= worker.PhaseUntil then
					worker.Phase = 1
					worker.PhaseUntil = nowClock + 4.8
				end
			end
		end
	else
		-- Slot 4: Drill Sergeant — paces ring with TrainingCoach + crimson rally ring + Dummy_2 heavy skill
		local tertiary = slotSpec.Tertiary or slotSpec.Secondary
		if worker.Phase == 1 or worker.Phase == 2 then
			local coachSpot = if worker.Phase == 1 then slotSpec.Primary else slotSpec.Secondary
			if moveWorkerToStation(worker, coachSpot, 9.5, "Move", dt) then
				if worker.Animator then
					worker.Animator:SetLocomotion("TrainingCoach")
				end
				if nowClock >= worker.NextMoteAt then
					worker.NextMoteAt = nowClock + 2.6
					local vfxNow = Workspace:GetServerTimeNow()
					local footWorld = origin:PointToWorldSpace(worker.LocalPos) + Vector3.new(0, 0.12, 0)
					VfxPrimitives.Ring(WorkerVfxPool, {
						Center = footWorld,
						From = 0.7,
						To = 3.8,
						Color = TRAINING_COLOR,
						StartAt = vfxNow,
						EndAt = vfxNow + 0.42,
						Width = 0.45,
					})
				end
				if nowClock >= worker.PhaseUntil then
					if worker.Phase == 1 then
						worker.Phase = 2
						worker.PhaseUntil = nowClock + 3.4
					else
						worker.Phase = 3
						worker.SubCounter = 0
						worker.NextActionAt = nowClock + 0.35
					end
				end
			end
		else
			if moveWorkerToStation(worker, tertiary, 12.5, "Move", dt) then
				if worker.Animator then
					worker.Animator:SetLocomotion("Idle")
				end
				if nowClock >= worker.NextActionAt then
					worker.SubCounter += 1
					local dummyPos = FacilityWorkerRules.GetDummyPlotPosition(2) + Vector3.new(0, 3.3, 0)
					fireTrainingAttack(worker, 3, dummyPos, 2, false, 1.0)
					worker.NextActionAt = nowClock + 1.25
					worker.Phase = 1
					worker.PhaseUntil = nowClock + 3.8
				end
			end
		end
	end
end

--============================================================================
-- PLOT DIRECTOR STEPPING & PARKING
--============================================================================
local function parkDirector(director: PlotWorkerDirector, parked: boolean, origin: CFrame)
	if director.Parked == parked then
		return
	end
	director.Parked = parked
	for _, worker in pairs(director.Workers) do
		if parked then
			worker.Model.Parent = nil
		else
			worker.RootPart.CFrame = worldRootCFrame(origin, worker.LocalPos, 3.0, worker.Yaw)
			worker.Model.Parent = EntitiesFolder
		end
	end
	if parked then
		resetAllDummies(director)
	end
end

local function stepPlotDirector(
	director: PlotWorkerDirector,
	origin: CFrame,
	nowClock: number,
	nowUnix: number,
	dt: number
)
	stepDummyWobbles(director, nowClock)

	for _, worker in pairs(director.Workers) do
		local slotSpec = FacilityWorkerRules.GetSlotSpec(worker.FacilityId, worker.Slot)
		if not slotSpec then
			continue
		end

		local isComa = worker.ComaUntil > nowUnix
		if isComa then
			worker.RunInWaypoints = nil
			setPropVisible(worker, false)
			local comaSpot = FacilityWorkerRules.GetComaStation(worker.FacilityId, worker.Slot) or slotSpec.Primary
			local arrived = moveWorkerToStation(worker, comaSpot, 9.5, "Move", dt)
			if arrived and worker.Animator then
				worker.Animator:SetLocomotion("Coma")
			end
		elseif worker.RunInWaypoints ~= nil then
			local waypoints = worker.RunInWaypoints
			local wp = waypoints[worker.RunInIndex]
			if not wp then
				worker.RunInWaypoints = nil
			else
				local runClip = if worker.FacilityId == "Market" and worker.Slot == 2 and worker.RunInIndex >= 3
					then "Move"
					else "Move"
				local nextPos, moved = stepTowards(worker.LocalPos, wp, 17.5 * dt)
				worker.LocalPos = nextPos
				local runYaw = yawTowards(worker.LocalPos, wp, worker.Yaw)
				worker.Yaw = lerpAngle(worker.Yaw, runYaw, math.clamp(dt * 12, 0, 1))
				if worker.Animator then
					worker.Animator:SetLocomotion(runClip)
				end
				if moved <= 1e-4 or (Vector3.new(wp.X - worker.LocalPos.X, 0, wp.Z - worker.LocalPos.Z).Magnitude <= 0.45) then
					worker.RunInIndex += 1
					if worker.RunInIndex > #waypoints then
						worker.RunInWaypoints = nil
						worker.Phase = 1
						worker.PhaseUntil = nowClock + 3.8
						worker.NextActionAt = nowClock + 0.35
						local arriveNow = Workspace:GetServerTimeNow()
						local arriveWorld = origin:PointToWorldSpace(worker.LocalPos) + Vector3.new(0, 0.12, 0)
						local accent = if worker.FacilityId == "Market" then MARKET_COLOR else TRAINING_COLOR
						VfxPrimitives.Ring(WorkerVfxPool, {
							Center = arriveWorld,
							From = 0.6,
							To = 3.6,
							Color = accent,
							StartAt = arriveNow,
							EndAt = arriveNow + 0.38,
							Width = 0.45,
						})
					end
				end
			end
		elseif worker.FacilityId == "Market" then
			stepMarketSlotRoutine(worker, slotSpec, origin, nowClock, dt)
		else
			stepTrainingSlotRoutine(worker, slotSpec, origin, nowClock, dt)
		end

		worker.RootPart.CFrame = worldRootCFrame(origin, worker.LocalPos, 3.0, worker.Yaw)
		if worker.Animator then
			worker.Animator:Step(dt)
		end
	end
end

--============================================================================
-- PLOT WATCHERS & RENDER LOOP
--============================================================================
local function bindWorkersContainer(director: PlotWorkerDirector, container: Instance)
	for _, c in ipairs(director.ContainerConns) do
		c:Disconnect()
	end
	table.clear(director.ContainerConns)

	local function watchChild(child: Instance)
		if not child:IsA("Configuration") then
			return
		end
		table.insert(
			director.ContainerConns,
			child.AttributeChanged:Connect(function()
				director.Dirty = true
			end)
		)
	end

	for _, child in ipairs(container:GetChildren()) do
		watchChild(child)
	end
	table.insert(
		director.ContainerConns,
		container.ChildAdded:Connect(function(child)
			watchChild(child)
			director.Dirty = true
		end)
	)
	table.insert(
		director.ContainerConns,
		container.ChildRemoved:Connect(function()
			director.Dirty = true
		end)
	)
end

local function createPlotDirector(plotIndex: number, plot: Model): PlotWorkerDirector
	local director: PlotWorkerDirector = {
		PlotIndex = plotIndex,
		Plot = plot,
		Workers = {},
		DummyStates = {},
		DummySourceModel = nil,
		Dirty = true,
		Initialized = false,
		Parked = false,
		ThrottleAccum = 0,
		Connections = {},
		ContainerConns = {},
	}

	for _, attrName in ipairs({
		"OwnerUserId",
		"PlotWorkersSynced",
		"OutskirtsSynced",
		"FacilityLevel_Market",
		"FacilityLevel_TrainingGrounds",
	}) do
		table.insert(
			director.Connections,
			plot:GetAttributeChangedSignal(attrName):Connect(function()
				director.Dirty = true
			end)
		)
	end

	local existingContainer = plot:FindFirstChild("ActivePlotWorkers")
	if existingContainer then
		bindWorkersContainer(director, existingContainer)
	end
	table.insert(
		director.Connections,
		plot.ChildAdded:Connect(function(child)
			if child.Name == "ActivePlotWorkers" then
				bindWorkersContainer(director, child)
				director.Dirty = true
			elseif child.Name == "PlotBuildings" then
				director.DummySourceModel = nil
				director.Dirty = true
			end
		end)
	)

	return director
end

local PlotsFolder = Workspace:WaitForChild("WaitingRoomPlots", 15)
if PlotsFolder then
	local function registerPlot(child: Instance)
		if not child:IsA("Model") then
			return
		end
		local idx = tonumber(string.match(child.Name, "^Plot_(%d+)$"))
		if not idx or PlotDirectors[idx] then
			return
		end
		PlotDirectors[idx] = createPlotDirector(idx, child)
	end

	for _, child in ipairs(PlotsFolder:GetChildren()) do
		registerPlot(child)
	end
	PlotsFolder.ChildAdded:Connect(registerPlot)
end

RunService.RenderStepped:Connect(function(dt: number)
	local clampedDt = math.min(dt, 0.1)
	local nowClock = os.clock()
	local nowUnix = os.time()
	local nowServer = Workspace:GetServerTimeNow()

	WorkerVfxPool:Step(nowServer)

	local cam = Workspace.CurrentCamera
	local camPos = if cam then cam.CFrame.Position else Vector3.zero

	for _, director in pairs(PlotDirectors) do
		local origin = resolvePlotOrigin(director.Plot)
		if not origin then
			continue
		end

		if director.Dirty then
			syncDirectorWorkers(director, origin)
		end

		if next(director.Workers) == nil then
			resetAllDummies(director)
			continue
		end

		-- Measure distance to the nearer of Market or TrainingGrounds on this plot
		local marketWorld = origin:PointToWorldSpace(FacilityWorkerRules.Facilities.Market.Center)
		local trainWorld = origin:PointToWorldSpace(FacilityWorkerRules.Facilities.TrainingGrounds.Center)
		local distMarket = (camPos - marketWorld).Magnitude
		local distTrain = (camPos - trainWorld).Magnitude
		local nearestDist = math.min(distMarket, distTrain)

		if nearestDist > THROTTLE_DIST then
			parkDirector(director, true, origin)
			continue
		end

		if director.Parked then
			parkDirector(director, false, origin)
		end

		if nearestDist > FULL_RATE_DIST then
			director.ThrottleAccum += clampedDt
			if director.ThrottleAccum < THROTTLE_STEP then
				continue
			end
			local stepDt = math.min(director.ThrottleAccum, 0.12)
			director.ThrottleAccum = 0
			stepPlotDirector(director, origin, nowClock, nowUnix, stepDt)
		else
			director.ThrottleAccum = 0
			stepPlotDirector(director, origin, nowClock, nowUnix, clampedDt)
		end
	end
end)

_G.FacilityWorkerState = {
	GetPlotSummary = function(plotIndex: number)
		local d = PlotDirectors[plotIndex]
		if not d then
			return nil
		end
		local marketCount = 0
		local trainingCount = 0
		local roles: { [string]: string } = {}
		local clips: { [string]: string } = {}
		local runInCount = 0
		for _, w in pairs(d.Workers) do
			if w.FacilityId == "Market" then
				marketCount += 1
			else
				trainingCount += 1
			end
			local spec = FacilityWorkerRules.GetSlotSpec(w.FacilityId, w.Slot)
			local key = `{w.FacilityId}_{w.Slot}`
			roles[key] = if spec then spec.RoleId else "Unknown"
			clips[key] = if w.Animator then w.Animator.Locomotion else "None"
			if w.RunInWaypoints ~= nil then
				runInCount += 1
			end
		end
		return {
			MarketCount = marketCount,
			TrainingCount = trainingCount,
			Roles = roles,
			Locomotions = clips,
			RunInCount = runInCount,
			Parked = d.Parked,
		}
	end,
}
