--!strict
debug.setmemorycategory("AdventurerPatrol")
-- StarterPlayerScripts/Rendering/AdventurerPatrolController.client.luau
-- Client-rendered physical & visual Outskirts Guard Post wave defense loop:
--   * Spawns full costumed R15 hero rigs + weapons for stationed Guard Post Adventurers
--   * Newly assigned heroes jog out from the Rear Fortress Gatehouse to their post
--   * Loops waves of biome/floor-matched 3D TowerEnemyRigs marching from the southern treeline
--     to assault stationed Adventurers and Building_GuardPost (no overhead BillboardGuis)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local HubPresence = require(script.Parent:WaitForChild("HubPresence"))

local LocalPlayer = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local HeroCatalog = require(Config:WaitForChild("HeroCatalog"))
local FirstBiomeCombat = require(Config:WaitForChild("FirstBiomeCombat"))
local OutskirtsRules = require(Shared:WaitForChild("Util"):WaitForChild("OutskirtsRules"))

local Assets = ReplicatedStorage:WaitForChild("Assets")
local ArtPackVisuals = require(Assets:WaitForChild("ArtPackVisuals"))
local EnemyRigFactory = require(Assets:WaitForChild("EnemyRigFactory")) -- remodelled templates, else the part rig
local TowerEnemyClips = require(Assets:WaitForChild("TowerEnemyClips"))

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
local OutskirtsVfxPool = VfxPool.new(EntitiesFolder)

local FULL_RATE_DIST = 240
local THROTTLE_DIST = 480
local THROTTLE_STEP = 1 / 15
-- Highlights are costly and capped per client: only plots inside the full-rate radius keep outlines.
local HIGHLIGHT_DIST = FULL_RATE_DIST

local GOLD_COLOR = Color3.fromRGB(255, 214, 92)
local DEPLOY_COLOR = Color3.fromRGB(130, 245, 210)
local TIMBER_SPARK_COLOR = Color3.fromRGB(255, 172, 84)

local ATTACK_CYCLE = table.freeze({ 1, 1, 2, 1, 3 })
local TIER_ACTION_NAMES = table.freeze({
	[1] = "AttackBasic",
	[2] = "AttackSpecial",
	[3] = "AttackSkill",
})

local RANGED_WEAPONS: { [string]: boolean } = table.freeze({
	BOW = true,
	STAFF = true,
	TOME = true,
})

type HeroVisual = {
	UUID: string,
	Slot: number,
	SyntheticNetId: number,
	TemplateId: string,
	Archetype: string,
	Rarity: number,
	ArtifactKey: string,
	ComaUntil: number,
	Model: Model,
	RootPart: Part,
	Rig: Model?,
	Animator: HeroAnimator.HeroAnimator?,
	Highlight: Highlight,
	LocalPos: Vector3,
	Yaw: number,
	RunInIndex: number?, -- 1..#GatehouseRunIn while jogging from Rear Gatehouse
	PatrolT: number,
	PatrolDir: number,
	PatrolPauseUntil: number,
	NextAttackAt: number,
	AttackCycleIdx: number,
	HitFlashUntil: number,
	TargetMobId: number?,
}

type MobVisual = {
	Id: number,
	EnemyId: string,
	Role: string,
	LaneIndex: number,
	TargetsBuildingFirst: boolean,
	SpawnAt: number,
	Spawned: boolean,
	BornAt: number,
	Model: Model?,
	RootPart: Part?,
	EnemyRig: any,
	Highlight: Highlight?,
	LocalPos: Vector3,
	Yaw: number,
	PassedMid: boolean,
	MoveSpeed: number,
	RootHeight: number,
	AttackRange: number,
	HitsTaken: number,
	HitsToDefeat: number,
	HitAt: number?,
	ActionStartedAt: number?,
	ActionImpactOffset: number,
	ActionRecovery: number,
	ActionImpactDone: boolean,
	NextAttackAt: number,
	AttackingBuilding: boolean,
	DeathAt: number?,
}

type DirectorState = "IDLE_EMPTY" | "PATROL" | "WAVE_APPROACH" | "CLASH" | "AFTERMATH"

type PlotDirector = {
	Plot: Model,
	PlotIndex: number,
	Initialized: boolean,
	State: DirectorState,
	StateEnteredAt: number,
	FloorId: number,
	BiomeId: string,
	GuardPostLevel: number,
	WaveIndex: number,
	NextMobId: number,
	TotalWavesSpawned: number,
	TotalMobsDefeated: number,
	Heroes: { [string]: HeroVisual },
	Mobs: { [number]: MobVisual },
	AccumulatedDt: number,
	Parked: boolean,
	DirtyWorkers: boolean,
	Connections: { RBXScriptConnection },
}

local Directors: { [Model]: PlotDirector } = {}
local DebugSummary: { [string]: any } = {}
_G.OutskirtsPatrolState = DebugSummary

local ensuredHeroesOnce = false
local function ensureHeroTemplates()
	if ensuredHeroesOnce then
		return
	end
	ensuredHeroesOnce = true
	local heroes = Assets:FindFirstChild("Heroes")
	if not heroes or #heroes:GetChildren() == 0 then
		pcall(HeroRegistry.EnsureHeroes)
	end
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

local resolvePlotOrigin = HubPresence.ResolvePlotOrigin

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
	local delta = Vector3.new(goal.X - current.X, 0, goal.Z - current.Z)
	local dist = delta.Magnitude
	if dist <= 1e-3 then
		return goal, 0
	end
	if dist <= maxStep then
		return goal, dist
	end
	return current + (delta / dist) * maxStep, maxStep
end

local function destroyMobVisual(mob: MobVisual)
	if mob.Model then
		mob.Model:Destroy()
		mob.Model = nil
	end
	mob.RootPart = nil
	mob.EnemyRig = nil
	mob.Highlight = nil
end

local function clearDirectorMobs(director: PlotDirector)
	for id, mob in pairs(director.Mobs) do
		destroyMobVisual(mob)
		director.Mobs[id] = nil
	end
end

local function destroyHeroVisual(hero: HeroVisual)
	setBowArrowHidden(hero.Rig, false)
	hero.Model:Destroy()
end

local function equipHeroWeapon(hero: HeroVisual, artifactId: string, artifactType: string, artifactRarity: number)
	local key = string.format("%s|%s|%d", artifactId, artifactType, artifactRarity)
	if hero.ArtifactKey == key then
		return
	end
	hero.ArtifactKey = key
	if not hero.Rig then
		return
	end
	local resolvedType = HeroLoadout.Equip(
		hero.Model,
		hero.Rig,
		if artifactId ~= "" then artifactId else nil,
		if artifactType ~= "" then artifactType else OutskirtsRules.DefaultWeaponForArchetype(hero.Archetype),
		artifactRarity
	)
	if hero.Animator then
		hero.Animator:SetWeaponType(resolvedType or OutskirtsRules.DefaultWeaponForArchetype(hero.Archetype))
	end
end

local function createHeroVisual(
	director: PlotDirector,
	origin: CFrame,
	entry: Configuration,
	runFromGatehouse: boolean
): HeroVisual
	ensureHeroTemplates()

	local uuid = tostring(entry:GetAttribute("UUID") or entry.Name)
	local slot = math.clamp(tonumber(entry:GetAttribute("Slot")) or 1, 1, 5)
	local templateId = tostring(entry:GetAttribute("TemplateId") or "hero_han")
	local seed = HeroCatalog.Seeds[templateId] or HeroCatalog.Seeds.hero_han
	local archetype = tostring(entry:GetAttribute("Archetype") or (seed and seed.Archetype) or "Vanguard")
	local rarity = tonumber(entry:GetAttribute("Rarity")) or HeroCatalog.RarityOf(templateId)
	local artifactId = tostring(entry:GetAttribute("EquippedArtifactId") or "")
	local artifactType = tostring(entry:GetAttribute("EquippedArtifactType") or OutskirtsRules.DefaultWeaponForArchetype(archetype))
	local artifactRarity = tonumber(entry:GetAttribute("EquippedArtifactRarity")) or 1
	local comaUntil = tonumber(entry:GetAttribute("ComaUntilTimestamp")) or 0

	local defenderSlot = OutskirtsRules.DefenderSlots[slot] or OutskirtsRules.DefenderSlots[1]
	local initialT = ((slot * 0.37) % 1)
	local patrolX = defenderSlot.PatrolMinX + (defenderSlot.PatrolMaxX - defenderSlot.PatrolMinX) * initialT
	local startLocal = if runFromGatehouse
		then OutskirtsRules.GatehouseRunIn[1]
		elseif comaUntil > os.time() then (OutskirtsRules.CampfireRestSlots[slot] or OutskirtsRules.CampfireRestSlots[1])
		else OutskirtsRules.TrailPoint(patrolX)
	local initialYaw = if runFromGatehouse
		then yawTowards(OutskirtsRules.GatehouseRunIn[1], OutskirtsRules.GatehouseRunIn[2], math.pi)
		else math.pi

	local model = Instance.new("Model")
	model.Name = string.format("OutskirtsHero_%d_%s", director.PlotIndex, uuid)

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 4, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
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
	hl.Name = "OutskirtsHeroHighlight"
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
			WeaponType = artifactType,
		})
	end

	local visual: HeroVisual = {
		UUID = uuid,
		Slot = slot,
		SyntheticNetId = director.PlotIndex * 16 + slot,
		TemplateId = templateId,
		Archetype = archetype,
		Rarity = rarity,
		ArtifactKey = "",
		ComaUntil = comaUntil,
		Model = model,
		RootPart = root,
		Rig = rig,
		Animator = animator,
		Highlight = hl,
		LocalPos = startLocal,
		Yaw = initialYaw,
		RunInIndex = if runFromGatehouse then 2 else nil,
		PatrolT = initialT,
		PatrolDir = if slot % 2 == 0 then -1 else 1,
		PatrolPauseUntil = 0,
		NextAttackAt = os.clock() + 0.4 + slot * 0.18,
		AttackCycleIdx = 1,
		HitFlashUntil = 0,
		TargetMobId = nil,
	}

	equipHeroWeapon(visual, artifactId, artifactType, artifactRarity)

	if animator then
		animator.OnMarker = function(markerName: string, action: HeroAnimator.Action)
			if markerName == "Nock" or markerName == "End" then
				setBowArrowHidden(visual.Rig, false)
				return
			end
			if markerName ~= "Release" then
				return
			end
			if animator.WeaponType == "BOW" then
				setBowArrowHidden(visual.Rig, true)
			end
			local data = action.Data
			if not data then
				return
			end
			local curOrigin = resolvePlotOrigin(director.Plot)
			if not curOrigin then
				return
			end
			local targetMob: MobVisual? = data.MobId and director.Mobs[data.MobId] or nil
			local serverNow = Workspace:GetServerTimeNow()
			local fromWorld = shotOrigin(visual.Rig, visual.RootPart)
			local aimGroundWorld: Vector3 = data.AimWorld
			if targetMob and targetMob.DeathAt == nil then
				aimGroundWorld = curOrigin:PointToWorldSpace(targetMob.LocalPos)
			end
			local isRanged = RANGED_WEAPONS[animator.WeaponType] == true
			local dist = (aimGroundWorld - fromWorld).Magnitude
			local travel = if isRanged then math.clamp(dist / 58, 0.08, 0.55) else 0.02

			SkillVfx.Play(OutskirtsVfxPool, {
				HeroId = visual.TemplateId,
				WeaponType = animator.WeaponType,
				Cue = {
					NetId = visual.SyntheticNetId,
					Tier = data.Tier or 1,
					StartServerTime = serverNow,
					ReleaseSeconds = 0,
					TravelSeconds = travel,
					Aim = aimGroundWorld,
				},
				Origin = fromWorld,
				Target = function(): Vector3
					if targetMob and targetMob.RootPart and targetMob.RootPart.Parent then
						return targetMob.RootPart.Position
					end
					return aimGroundWorld + Vector3.new(0, 2.2, 0)
				end,
				Self = function(): Vector3
					return Vector3.new(visual.RootPart.Position.X, aimGroundWorld.Y, visual.RootPart.Position.Z)
				end,
				Allies = function(): { Vector3 }
					local pts: { Vector3 } = {}
					for _, ally in pairs(director.Heroes) do
						if ally.RootPart.Parent then
							table.insert(pts, Vector3.new(ally.RootPart.Position.X, aimGroundWorld.Y, ally.RootPart.Position.Z))
						end
					end
					return pts
				end,
				Now = serverNow,
				Shake = nil,
			})

			-- Schedule damage / hit reaction / defeat on the Outskirts mob when the strike lands
			VfxPrimitives.At(OutskirtsVfxPool, serverNow + travel, function()
				local mob = data.MobId and director.Mobs[data.MobId]
				if not mob or mob.DeathAt ~= nil then
					return
				end
				local hitClock = os.clock()
				mob.HitsTaken += if (data.Tier or 1) >= 3 then 2 else 1
				mob.HitAt = hitClock
				if mob.HitsTaken >= mob.HitsToDefeat then
					mob.DeathAt = hitClock
					director.TotalMobsDefeated += 1
					if mob.RootPart then
						local deathPos = mob.RootPart.Position
						local vfxNow = Workspace:GetServerTimeNow()
						VfxPrimitives.Burst(OutskirtsVfxPool, deathPos, GOLD_COLOR, 2.4, vfxNow, 0.28)
						VfxPrimitives.Motes(OutskirtsVfxPool, deathPos, GOLD_COLOR, vfxNow, 5, 0.75)
					end
				end
			end)
		end
	end

	if runFromGatehouse then
		local nowServer = Workspace:GetServerTimeNow()
		local spawnWorld = origin:PointToWorldSpace(startLocal)
		VfxPrimitives.Ring(OutskirtsVfxPool, {
			Center = spawnWorld,
			From = 0.8,
			To = 5.2,
			Color = DEPLOY_COLOR,
			StartAt = nowServer,
			EndAt = nowServer + 0.48,
			Width = 0.65,
		})
		VfxPrimitives.Motes(OutskirtsVfxPool, spawnWorld + Vector3.new(0, 1.5, 0), GOLD_COLOR, nowServer, 6, 0.85)
	end

	return visual
end

local function syncPlotWorkers(director: PlotDirector, origin: CFrame)
	director.DirtyWorkers = false
	local plot = director.Plot
	local ownerUserId = tonumber(plot:GetAttribute("OwnerUserId")) or 0
	if ownerUserId <= 0 then
		clearDirectorMobs(director)
		for uuid, hero in pairs(director.Heroes) do
			destroyHeroVisual(hero)
			director.Heroes[uuid] = nil
		end
		director.State = "IDLE_EMPTY"
		director.Initialized = false
		return
	end

	local attrFloor = tonumber(plot:GetAttribute("OutskirtsFloorId"))
	local floorInfo = OutskirtsRules.ResolveFrontierInfo(attrFloor and (attrFloor - 1) or 0, attrFloor or 1)
	director.FloorId = floorInfo.FloorId
	director.BiomeId = floorInfo.BiomeId
	director.GuardPostLevel = math.clamp(tonumber(plot:GetAttribute("GuardPostLevel")) or 1, 1, 5)

	local container = plot:FindFirstChild("ActivePlotWorkers")
	local seenUUIDs: { [string]: boolean } = {}
	local canRunIn = director.Initialized and plot:GetAttribute("OutskirtsSynced") == true

	if container then
		for _, child in ipairs(container:GetChildren()) do
			if not child:IsA("Configuration") then
				continue
			end
			if child:GetAttribute("Facility") and child:GetAttribute("Facility") ~= "GuardPost" then
				continue
			end
			local uuid = tostring(child:GetAttribute("UUID") or child.Name)
			seenUUIDs[uuid] = true

			local existing = director.Heroes[uuid]
			if not existing then
				director.Heroes[uuid] = createHeroVisual(director, origin, child, canRunIn)
			else
				existing.Slot = math.clamp(tonumber(child:GetAttribute("Slot")) or existing.Slot, 1, 5)
				existing.ComaUntil = tonumber(child:GetAttribute("ComaUntilTimestamp")) or 0
				local artId = tostring(child:GetAttribute("EquippedArtifactId") or "")
				local artType = tostring(
					child:GetAttribute("EquippedArtifactType") or OutskirtsRules.DefaultWeaponForArchetype(existing.Archetype)
				)
				local artRarity = tonumber(child:GetAttribute("EquippedArtifactRarity")) or 1
				equipHeroWeapon(existing, artId, artType, artRarity)
			end
		end
	end

	for uuid, hero in pairs(director.Heroes) do
		if not seenUUIDs[uuid] then
			destroyHeroVisual(hero)
			director.Heroes[uuid] = nil
		end
	end

	if plot:GetAttribute("OutskirtsSynced") == true then
		director.Initialized = true
	end
end

local function realizeMobModel(director: PlotDirector, origin: CFrame, mob: MobVisual, now: number)
	mob.Spawned = true
	mob.BornAt = now

	local spec = FirstBiomeCombat.Get(mob.EnemyId)
	local rootHeight = (spec and spec.RootHeight) or 3.2
	mob.RootHeight = rootHeight

	local model = Instance.new("Model")
	model.Name = string.format("OutskirtsMob_%d_%d_%s", director.PlotIndex, mob.Id, mob.EnemyId)

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.CastShadow = false
	root.CFrame = worldRootCFrame(origin, mob.LocalPos, rootHeight, mob.Yaw)
	root.Parent = model
	model.PrimaryPart = root

	local rig = EnemyRigFactory.Build(model, root, mob.EnemyId)
	for _, p in ipairs(rig.Parts) do
		if p:IsA("BasePart") then
			p.CanQuery = false
			p.CanTouch = false
			p.CanCollide = false
		end
	end

	local hl = Instance.new("Highlight")
	hl.Name = "OutskirtsMobHighlight"
	hl.FillColor = Color3.fromRGB(245, 255, 200)
	hl.OutlineColor = if mob.Role == "ALPHA"
		then Color3.fromRGB(255, 196, 72)
		elseif mob.Role == "ELITE" then Color3.fromRGB(255, 125, 85)
		else Color3.fromRGB(48, 56, 52)
	hl.FillTransparency = 1
	hl.OutlineTransparency = if mob.Role == "ALPHA" or mob.Role == "ELITE" then 0.25 else 0.55
	hl.Adornee = rig.Model or model
	hl.Parent = model

	model.Parent = if director.Parked then nil else EntitiesFolder
	mob.Model = model
	mob.RootPart = root
	mob.EnemyRig = rig
	mob.Highlight = hl

	if not director.Parked then
		local vfxNow = Workspace:GetServerTimeNow()
		local emergeWorld = origin:PointToWorldSpace(mob.LocalPos)
		VfxPrimitives.Ring(OutskirtsVfxPool, {
			Center = emergeWorld,
			From = 0.6,
			To = if mob.Role == "ALPHA" then 5.4 else 3.6,
			Color = if mob.Role == "ALPHA" then GOLD_COLOR else Color3.fromRGB(165, 225, 145),
			StartAt = vfxNow,
			EndAt = vfxNow + 0.42,
			Width = 0.45,
		})
	end
end

local function spawnNextWave(director: PlotDirector, awakeCount: number, now: number)
	clearDirectorMobs(director)
	director.WaveIndex += 1
	director.TotalWavesSpawned += 1

	local roster = OutskirtsRules.ResolveWaveRoster(
		director.FloorId,
		director.GuardPostLevel,
		awakeCount,
		director.WaveIndex
	)

	for _, entry in ipairs(roster) do
		local lane = OutskirtsRules.SpawnLanes[entry.LaneIndex] or OutskirtsRules.SpawnLanes[1]
		local spec = FirstBiomeCombat.Get(entry.EnemyId)
		local moveSpeed = if spec and type(spec.MoveSpeed) == "number"
			then math.clamp(spec.MoveSpeed * 1.15, 9.5, 15.0)
			else 11.5
		local isRangedMob = spec ~= nil and spec.Attacks ~= nil and spec.Attacks[1] ~= nil and spec.Attacks[1].Shape == "PROJECTILE"
		local jitterX = ((director.NextMobId % 3) - 1) * 3.2
		local spawnLocal = lane.Spawn + Vector3.new(jitterX, 0, (director.NextMobId % 2) * 2.4)

		director.NextMobId += 1
		local mobId = director.NextMobId
		director.Mobs[mobId] = {
			Id = mobId,
			EnemyId = entry.EnemyId,
			Role = entry.Role,
			LaneIndex = entry.LaneIndex,
			TargetsBuildingFirst = entry.TargetsBuildingFirst,
			SpawnAt = now + entry.SpawnDelay,
			Spawned = false,
			BornAt = now + entry.SpawnDelay,
			Model = nil,
			RootPart = nil,
			EnemyRig = nil,
			Highlight = nil,
			LocalPos = spawnLocal,
			Yaw = yawTowards(spawnLocal, lane.Mid, 0),
			PassedMid = false,
			MoveSpeed = moveSpeed,
			RootHeight = (spec and spec.RootHeight) or 3.2,
			AttackRange = if isRangedMob or entry.Role == "SUPPORT" then 14.5 else 5.2,
			HitsTaken = 0,
			HitsToDefeat = entry.HitsToDefeat,
			HitAt = nil,
			ActionStartedAt = nil,
			ActionImpactOffset = 0.52,
			ActionRecovery = 0.58,
			ActionImpactDone = false,
			NextAttackAt = now + entry.SpawnDelay + 1.0,
			AttackingBuilding = false,
			DeathAt = nil,
		}
	end
end

local function stepMobAnimation(
	director: PlotDirector,
	origin: CFrame,
	mob: MobVisual,
	movedDist: number,
	now: number
)
	local rig = mob.EnemyRig
	local root = mob.RootPart
	if not rig or not root then
		return
	end
	root.CFrame = worldRootCFrame(origin, mob.LocalPos, mob.RootHeight, mob.Yaw)

	local clips = TowerEnemyClips[mob.EnemyId]
	if not clips then
		return
	end

	rig.Distance = (rig.Distance or 0) + math.min(movedDist, 4)
	local frames = clips.Idle
	local phase = (now % 3) / 3

	if mob.DeathAt then
		frames = clips.Death
		phase = math.clamp((now - mob.DeathAt) / 1.6, 0, 1)
	elseif mob.ActionStartedAt then
		local elapsed = now - mob.ActionStartedAt
		local total = mob.ActionImpactOffset + mob.ActionRecovery
		if elapsed < total then
			frames = clips.BasicAttack or clips.Idle
			phase = if elapsed < mob.ActionImpactOffset
				then 0.8 * (elapsed / mob.ActionImpactOffset)
				else 0.8 + 0.2 * ((elapsed - mob.ActionImpactOffset) / mob.ActionRecovery)
			if not mob.ActionImpactDone and elapsed >= mob.ActionImpactOffset then
				mob.ActionImpactDone = true
				if mob.AttackingBuilding and not director.Parked then
					local lane = OutskirtsRules.SpawnLanes[mob.LaneIndex] or OutskirtsRules.SpawnLanes[1]
					local hitWorld = origin:PointToWorldSpace(lane.BuildingTarget + Vector3.new(0, 2.2, 0))
					local vfxNow = Workspace:GetServerTimeNow()
					VfxPrimitives.Burst(OutskirtsVfxPool, hitWorld, TIMBER_SPARK_COLOR, 1.9, vfxNow, 0.22)
				end
			end
		else
			mob.ActionStartedAt = nil
		end
	elseif clips.Awakening and now - mob.BornAt < 1.1 then
		frames = clips.Awakening
		phase = (now - mob.BornAt) / 1.1
	elseif movedDist > 0.02 then
		frames = clips.Locomotion
		local stride = if rig.Spec.Role == "REGULAR" then 3.6 else 4.8
		phase = (rig.Distance / stride) % 1
	elseif mob.HitAt and now - mob.HitAt < 0.28 then
		frames = clips.HitReaction
		phase = (now - mob.HitAt) / 0.28
	end

	local poses = TowerEnemyClips.Sample(frames, phase)
	for name, joint in pairs(rig.Joints) do
		joint.Motor.C0 = joint.Bind * (poses[name] or CFrame.identity)
	end

	if mob.Highlight then
		if mob.HitAt and now - mob.HitAt < 0.15 and not mob.DeathAt then
			mob.Highlight.FillTransparency = 0.35
		else
			mob.Highlight.FillTransparency = 1
		end
	end

	if mob.DeathAt then
		local alpha = math.clamp((now - mob.DeathAt - 1.05) / 0.5, 0, 1)
		for _, p in ipairs(rig.Parts) do
			p.Transparency = alpha
		end
	end
end

local function pickHeroTargetMob(director: PlotDirector, hero: HeroVisual): MobVisual?
	local bestMob: MobVisual? = nil
	local bestScore = math.huge

	for _, mob in pairs(director.Mobs) do
		if mob.Spawned and mob.DeathAt == nil then
			local dist = (mob.LocalPos - hero.LocalPos).Magnitude
			-- Prioritize raiders actively attacking Building_GuardPost or pushing toward it
			local threatBonus = if mob.AttackingBuilding then -28 elseif mob.TargetsBuildingFirst then -10 else 0
			local score = dist + threatBonus
			if score < bestScore then
				bestScore = score
				bestMob = mob
			end
		end
	end
	return bestMob
end

local function pickNearestAwakeHero(awakeHeroes: { HeroVisual }, fromLocal: Vector3): (HeroVisual?, number)
	local best: HeroVisual? = nil
	local bestDist = math.huge
	for _, hero in ipairs(awakeHeroes) do
		if hero.RunInIndex == nil then
			local d = (hero.LocalPos - fromLocal).Magnitude
			if d < bestDist then
				bestDist = d
				best = hero
			end
		end
	end
	return best, bestDist
end

local function stepDirector(director: PlotDirector, origin: CFrame, dt: number, now: number)
	local nowUnix = os.time()
	local awakeHeroes: { HeroVisual } = {}
	for _, hero in pairs(director.Heroes) do
		if hero.ComaUntil <= nowUnix then
			table.insert(awakeHeroes, hero)
		end
	end
	table.sort(awakeHeroes, function(a, b)
		return a.Slot < b.Slot
	end)

	-- State machine transitions
	if #awakeHeroes == 0 then
		if director.State ~= "IDLE_EMPTY" then
			clearDirectorMobs(director)
			director.State = "IDLE_EMPTY"
			director.StateEnteredAt = now
		end
	else
		if director.State == "IDLE_EMPTY" then
			director.State = "PATROL"
			director.StateEnteredAt = now
		elseif director.State == "PATROL" then
			local waitSeconds = if director.TotalWavesSpawned == 0
				then OutskirtsRules.Timing.FirstWavePatrolSeconds
				else OutskirtsRules.Timing.PatrolSeconds
			-- Wait until at least one hero has finished jogging in from the gatehouse (or timeout)
			local anyReady = false
			for _, h in ipairs(awakeHeroes) do
				if h.RunInIndex == nil then
					anyReady = true
					break
				end
			end
			if anyReady and (now - director.StateEnteredAt >= waitSeconds) then
				spawnNextWave(director, #awakeHeroes, now)
				director.State = "WAVE_APPROACH"
				director.StateEnteredAt = now
			end
		elseif director.State == "WAVE_APPROACH" or director.State == "CLASH" then
			local pendingOrAlive = 0
			local anyInClash = false
			for id, mob in pairs(director.Mobs) do
				if not mob.Spawned then
					pendingOrAlive += 1
					if now >= mob.SpawnAt then
						realizeMobModel(director, origin, mob, now)
					end
				elseif mob.DeathAt == nil then
					pendingOrAlive += 1
					if mob.LocalPos.Z <= 185 or mob.AttackingBuilding then
						anyInClash = true
					end
				elseif now >= mob.DeathAt + 1.62 then
					destroyMobVisual(mob)
					director.Mobs[id] = nil
				else
					pendingOrAlive += 1
				end
			end
			if director.State == "WAVE_APPROACH" and anyInClash then
				director.State = "CLASH"
				director.StateEnteredAt = now
			end
			if pendingOrAlive == 0 then
				director.State = "AFTERMATH"
				director.StateEnteredAt = now
			end
		elseif director.State == "AFTERMATH" then
			if now - director.StateEnteredAt >= OutskirtsRules.Timing.AftermathSeconds then
				director.State = "PATROL"
				director.StateEnteredAt = now
			end
		end
	end

	-- Step Mobs
	for _, mob in pairs(director.Mobs) do
		if not mob.Spawned then
			continue
		end
		local movedDist = 0
		if mob.DeathAt == nil then
			local lane = OutskirtsRules.SpawnLanes[mob.LaneIndex] or OutskirtsRules.SpawnLanes[1]
			if not mob.PassedMid then
				local nextPos, stepped = stepTowards(mob.LocalPos, lane.Mid, mob.MoveSpeed * dt)
				mob.LocalPos = nextPos
				movedDist = stepped
				mob.Yaw = lerpAngle(mob.Yaw, yawTowards(mob.LocalPos, lane.Mid, mob.Yaw), math.min(1, dt * 10))
				if (mob.LocalPos - lane.Mid).Magnitude <= 2.2 then
					mob.PassedMid = true
				end
			else
				local nearestHero, heroDist = pickNearestAwakeHero(awakeHeroes, mob.LocalPos)
				local chaseHero = false
				if nearestHero then
					if not mob.TargetsBuildingFirst or heroDist <= 9.5 then
						chaseHero = true
					end
				end

				local goalPos = if chaseHero and nearestHero then nearestHero.LocalPos else lane.BuildingTarget
				local distToGoal = (goalPos - mob.LocalPos).Magnitude
				mob.AttackingBuilding = not chaseHero and distToGoal <= (mob.AttackRange + 1.0)

				mob.Yaw = lerpAngle(mob.Yaw, yawTowards(mob.LocalPos, goalPos, mob.Yaw), math.min(1, dt * 10))
				if distToGoal > mob.AttackRange then
					local nextPos, stepped = stepTowards(mob.LocalPos, goalPos, mob.MoveSpeed * dt)
					mob.LocalPos = nextPos
					movedDist = stepped
				elseif now >= mob.NextAttackAt then
					mob.NextAttackAt = now + OutskirtsRules.Timing.MobAttackInterval
					mob.ActionStartedAt = now
					mob.ActionImpactDone = false
					if chaseHero and nearestHero then
						nearestHero.HitFlashUntil = now + 0.14
					end
				end
			end
		end
		stepMobAnimation(director, origin, mob, movedDist, now)
	end

	-- Step Heroes
	local campfireLook = Vector3.new(10.5, 0, 160.5)
	for _, hero in pairs(director.Heroes) do
		local movedDist = 0
		local speedScale = 1.0
		local desiredLoco = "Idle"

		if hero.RunInIndex ~= nil then
			local waypoint = OutskirtsRules.GatehouseRunIn[hero.RunInIndex]
			if waypoint then
				local nextPos, stepped = stepTowards(hero.LocalPos, waypoint, 17.5 * dt)
				hero.LocalPos = nextPos
				movedDist = stepped
				speedScale = 1.28
				desiredLoco = "Move"
				hero.Yaw = lerpAngle(hero.Yaw, yawTowards(hero.LocalPos, waypoint, hero.Yaw), math.min(1, dt * 12))
				if (hero.LocalPos - waypoint).Magnitude <= 1.2 then
					if hero.RunInIndex < #OutskirtsRules.GatehouseRunIn then
						hero.RunInIndex += 1
					else
						hero.RunInIndex = nil
					end
				end
			else
				hero.RunInIndex = nil
			end
		elseif hero.ComaUntil > nowUnix then
			local restGoal = OutskirtsRules.CampfireRestSlots[hero.Slot] or OutskirtsRules.CampfireRestSlots[1]
			local dist = (restGoal - hero.LocalPos).Magnitude
			if dist > 0.8 then
				local nextPos, stepped = stepTowards(hero.LocalPos, restGoal, 11.0 * dt)
				hero.LocalPos = nextPos
				movedDist = stepped
				desiredLoco = "Move"
				hero.Yaw = lerpAngle(hero.Yaw, yawTowards(hero.LocalPos, restGoal, hero.Yaw), math.min(1, dt * 10))
			else
				desiredLoco = "Sleep"
				hero.Yaw = lerpAngle(hero.Yaw, yawTowards(hero.LocalPos, campfireLook, hero.Yaw), math.min(1, dt * 8))
			end
		elseif director.State == "WAVE_APPROACH" or director.State == "CLASH" then
			local slotDef = OutskirtsRules.DefenderSlots[hero.Slot] or OutskirtsRules.DefenderSlots[1]
			local weaponType = if hero.Animator then hero.Animator.WeaponType else OutskirtsRules.DefaultWeaponForArchetype(hero.Archetype)
			local isRanged = RANGED_WEAPONS[weaponType] == true
			local targetMob = pickHeroTargetMob(director, hero)

			if targetMob then
				hero.TargetMobId = targetMob.Id
				local desiredRange = if isRanged then 34.0 else 4.8
				local holdPoint = if isRanged then slotDef.Rally else targetMob.LocalPos
				local distToMob = (targetMob.LocalPos - hero.LocalPos).Magnitude

				if isRanged then
					local rallyDist = (holdPoint - hero.LocalPos).Magnitude
					if rallyDist > 1.5 and distToMob > desiredRange then
						local nextPos, stepped = stepTowards(hero.LocalPos, holdPoint, 14.0 * dt)
						hero.LocalPos = nextPos
						movedDist = stepped
						desiredLoco = "Move"
						hero.Yaw = lerpAngle(hero.Yaw, yawTowards(hero.LocalPos, holdPoint, hero.Yaw), math.min(1, dt * 12))
					else
						hero.Yaw = lerpAngle(hero.Yaw, yawTowards(hero.LocalPos, targetMob.LocalPos, hero.Yaw), math.min(1, dt * 14))
						desiredLoco = if movedDist > 0.02 then "Move" else "Idle"
					end
				else
					if distToMob > desiredRange then
						local nextPos, stepped = stepTowards(hero.LocalPos, targetMob.LocalPos, 15.5 * dt)
						hero.LocalPos = nextPos
						movedDist = stepped
						speedScale = 1.18
						desiredLoco = "Move"
					end
					hero.Yaw = lerpAngle(hero.Yaw, yawTowards(hero.LocalPos, targetMob.LocalPos, hero.Yaw), math.min(1, dt * 14))
				end

				if distToMob <= desiredRange + 1.2 and now >= hero.NextAttackAt then
					local tier = ATTACK_CYCLE[hero.AttackCycleIdx] or 1
					hero.AttackCycleIdx = (hero.AttackCycleIdx % #ATTACK_CYCLE) + 1
					hero.NextAttackAt = now + OutskirtsRules.Timing.HeroAttackInterval + (if tier == 3 then 0.35 else 0)
					if hero.Animator then
						local actionState = TIER_ACTION_NAMES[tier] or "AttackBasic"
						hero.Animator:PlayAction(actionState, 0.78, 0, {
							MobId = targetMob.Id,
							Tier = tier,
							AimWorld = origin:PointToWorldSpace(targetMob.LocalPos),
						})
					end
				end
			else
				-- Move to defensive rally arc facing the southern treeline (+Z)
				local rallyDist = (slotDef.Rally - hero.LocalPos).Magnitude
				if rallyDist > 0.9 then
					local nextPos, stepped = stepTowards(hero.LocalPos, slotDef.Rally, 13.5 * dt)
					hero.LocalPos = nextPos
					movedDist = stepped
					desiredLoco = "Move"
					hero.Yaw = lerpAngle(hero.Yaw, yawTowards(hero.LocalPos, slotDef.Rally, hero.Yaw), math.min(1, dt * 10))
				else
					desiredLoco = "Idle"
					hero.Yaw = lerpAngle(hero.Yaw, math.pi, math.min(1, dt * 8))
				end
			end
		else
			-- PATROL / AFTERMATH: stroll along the curved wilderness dirt trail
			local slotDef = OutskirtsRules.DefenderSlots[hero.Slot] or OutskirtsRules.DefenderSlots[1]
			local span = math.max(12, slotDef.PatrolMaxX - slotDef.PatrolMinX)
			if now < hero.PatrolPauseUntil then
				desiredLoco = "Idle"
			else
				hero.PatrolT += (dt * 9.5 / span) * hero.PatrolDir
				if hero.PatrolT >= 1.0 then
					hero.PatrolT = 1.0
					hero.PatrolDir = -1
					hero.PatrolPauseUntil = now + 0.9
				elseif hero.PatrolT <= 0.0 then
					hero.PatrolT = 0.0
					hero.PatrolDir = 1
					hero.PatrolPauseUntil = now + 0.9
				end
				local targetX = slotDef.PatrolMinX + span * hero.PatrolT
				local trailGoal = OutskirtsRules.TrailPoint(targetX)
				local nextPos, stepped = stepTowards(hero.LocalPos, trailGoal, 11.5 * dt)
				hero.LocalPos = nextPos
				movedDist = stepped
				if stepped > 0.01 then
					desiredLoco = "Move"
					local aheadX = math.clamp(targetX + hero.PatrolDir * 4, -110, 110)
					hero.Yaw = lerpAngle(hero.Yaw, yawTowards(hero.LocalPos, OutskirtsRules.TrailPoint(aheadX), hero.Yaw), math.min(1, dt * 10))
				else
					desiredLoco = "Idle"
				end
			end
		end

		hero.RootPart.CFrame = worldRootCFrame(origin, hero.LocalPos, 3.0, hero.Yaw)
		if hero.Animator then
			hero.Animator:SetLocomotion(desiredLoco)
			hero.Animator:Step(dt, speedScale)
		end
		hero.Highlight.FillTransparency = if now < hero.HitFlashUntil then 0.55 else 1
	end

	local heroCount = 0
	for _ in pairs(director.Heroes) do
		heroCount += 1
	end
	local liveMobs = 0
	for _, m in pairs(director.Mobs) do
		if m.DeathAt == nil then
			liveMobs += 1
		end
	end
	DebugSummary[director.Plot.Name] = {
		State = director.State,
		FloorId = director.FloorId,
		BiomeId = director.BiomeId,
		GuardPostLevel = director.GuardPostLevel,
		WaveIndex = director.WaveIndex,
		HeroCount = heroCount,
		LiveMobCount = liveMobs,
		TotalWavesSpawned = director.TotalWavesSpawned,
		TotalMobsDefeated = director.TotalMobsDefeated,
	}
end

local function setDirectorParked(director: PlotDirector, parked: boolean)
	if director.Parked == parked then
		return
	end
	director.Parked = parked
	local parent: Instance? = if parked then nil else EntitiesFolder
	for _, hero in pairs(director.Heroes) do
		hero.Model.Parent = parent
	end
	for _, mob in pairs(director.Mobs) do
		if mob.Model then
			mob.Model.Parent = parent
		end
	end
end

local function bindWorkersContainer(director: PlotDirector, container: Instance)
	local function markDirty()
		director.DirtyWorkers = true
	end
	local function hookWorker(child: Instance)
		if child:IsA("Configuration") then
			table.insert(director.Connections, child.AttributeChanged:Connect(markDirty))
		end
	end
	for _, child in ipairs(container:GetChildren()) do
		hookWorker(child)
	end
	table.insert(
		director.Connections,
		container.ChildAdded:Connect(function(child)
			hookWorker(child)
			markDirty()
		end)
	)
	table.insert(director.Connections, container.ChildRemoved:Connect(markDirty))
end

local function registerPlot(plot: Model)
	if Directors[plot] then
		return
	end
	local plotIdx = tonumber(string.match(plot.Name, "%d+")) or 1
	local director: PlotDirector = {
		Plot = plot,
		PlotIndex = plotIdx,
		Initialized = false,
		State = "IDLE_EMPTY",
		StateEnteredAt = os.clock(),
		FloorId = 1,
		BiomeId = "verdant_ruins",
		GuardPostLevel = 1,
		WaveIndex = 0,
		NextMobId = 0,
		TotalWavesSpawned = 0,
		TotalMobsDefeated = 0,
		Heroes = {},
		Mobs = {},
		AccumulatedDt = 0,
		Parked = false,
		DirtyWorkers = true,
		Connections = {},
	}
	Directors[plot] = director

	table.insert(
		director.Connections,
		plot.AttributeChanged:Connect(function(attrName: string)
			if
				attrName == "OwnerUserId"
				or attrName == "OutskirtsFloorId"
				or attrName == "OutskirtsBiomeId"
				or attrName == "GuardPostLevel"
				or attrName == "OutskirtsSynced"
			then
				director.DirtyWorkers = true
			end
		end)
	)

	local existingWorkers = plot:FindFirstChild("ActivePlotWorkers")
	if existingWorkers then
		bindWorkersContainer(director, existingWorkers)
	end
	table.insert(
		director.Connections,
		plot.ChildAdded:Connect(function(child: Instance)
			if child.Name == "ActivePlotWorkers" then
				bindWorkersContainer(director, child)
				director.DirtyWorkers = true
			elseif child.Name == "PlotBuildings" then
				director.DirtyWorkers = true
			end
		end)
	)
end

local function unregisterPlot(plot: Model)
	local director = Directors[plot]
	if not director then
		return
	end
	for _, conn in ipairs(director.Connections) do
		conn:Disconnect()
	end
	table.clear(director.Connections)
	clearDirectorMobs(director)
	for uuid, hero in pairs(director.Heroes) do
		destroyHeroVisual(hero)
		director.Heroes[uuid] = nil
	end
	DebugSummary[plot.Name] = nil
	Directors[plot] = nil
end

local PlotsFolder = Workspace:WaitForChild("WaitingRoomPlots")
for _, child in ipairs(PlotsFolder:GetChildren()) do
	if child:IsA("Model") then
		registerPlot(child)
	end
end
PlotsFolder.ChildAdded:Connect(function(child: Instance)
	if child:IsA("Model") then
		registerPlot(child)
	end
end)
PlotsFolder.ChildRemoved:Connect(function(child: Instance)
	if child:IsA("Model") then
		unregisterPlot(child)
	end
end)

local function stepAdventurerPatrol(dt: number)
	local frameDt = math.min(dt, 0.1)
	local now = os.clock()
	local camera = Workspace.CurrentCamera
	local camPos = if camera then camera.CFrame.Position else nil

	OutskirtsVfxPool:Step(Workspace:GetServerTimeNow())

	if HubPresence.InTower() then
		for _, director in pairs(Directors) do
			setDirectorParked(director, true)
		end
		return
	end

	for _, director in pairs(Directors) do
		local origin = HubPresence.CachedOrigin(director.Plot, now)
		if not origin then
			continue
		end

		if director.DirtyWorkers then
			syncPlotWorkers(director, origin)
		end

		local ownerUserId = tonumber(director.Plot:GetAttribute("OwnerUserId")) or 0
		if ownerUserId <= 0 then
			continue
		end

		local guardWorld = origin:PointToWorldSpace(OutskirtsRules.GuardPostCenter)
		local camDist = if camPos then (camPos - guardWorld).Magnitude else 0
		if camDist > THROTTLE_DIST and ownerUserId ~= LocalPlayer.UserId then
			setDirectorParked(director, true)
			continue
		elseif camDist > THROTTLE_DIST * 1.35 then
			-- Local player is deep inside a Tower floor far from the Overworld
			setDirectorParked(director, true)
			continue
		end

		setDirectorParked(director, false)

		local wantOutline = camDist <= HIGHLIGHT_DIST
		for _, hero in pairs(director.Heroes) do
			if hero.Highlight.Enabled ~= wantOutline then
				hero.Highlight.Enabled = wantOutline
			end
		end
		for _, mob in pairs(director.Mobs) do
			local hl = mob.Highlight
			if hl and hl.Enabled ~= wantOutline then
				hl.Enabled = wantOutline
			end
		end

		if camDist > FULL_RATE_DIST then
			director.AccumulatedDt += frameDt
			if director.AccumulatedDt < THROTTLE_STEP then
				continue
			end
			local stepDt = math.min(director.AccumulatedDt, 0.15)
			director.AccumulatedDt = 0
			stepDirector(director, origin, stepDt, now)
		else
			director.AccumulatedDt = 0
			stepDirector(director, origin, frameDt, now)
		end
	end
end
RunService.RenderStepped:Connect(function(dt: number)
	debug.profilebegin("AdventurerPatrol")
	stepAdventurerPatrol(dt)
	debug.profileend()
end)
