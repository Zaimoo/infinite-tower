--!strict
-- StarterPlayerScripts/Rendering/EntityRenderer.client.luau
-- Unpacks 5 Hz Binary Buffer Snapshots & Interpolates Hero/Mob/Boss Visuals at 60 FPS (RenderStepped)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local HeroCatalog = require(Shared:WaitForChild("Config"):WaitForChild("HeroCatalog"))

local CombatRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CombatRemotes")
local ReplicationTickRemote = CombatRemotes:WaitForChild("ReplicationTick") :: UnreliableRemoteEvent
local BossTelegraphRemote = CombatRemotes:WaitForChild("BossTelegraph") :: RemoteEvent
local CombatVFXRemote = CombatRemotes:WaitForChild("CombatVFX") :: UnreliableRemoteEvent
local EntityMetadataRemote = CombatRemotes:WaitForChild("EntityMetadataSync") :: RemoteEvent

local Protocol=require(Shared.Util.TowerProtocol)
local FirstBiome=require(Shared.Config.FirstBiomeCombat)
local ActionState=require(Shared.Util.EnemyActionState)
local EnemyAnimation=require(ReplicatedStorage.Assets.EnemyAnimationController)
local Actions=ActionState.New()
local PendingActions={}
local DyingNodes={}
local ActionMetrics={Started=0,Canceled=0,Deaths=0,Rejected=0,Seeks=0}
local TowerRemotes=ReplicatedStorage.Remotes:WaitForChild("TowerRemotes")
local View: any=nil
local LastBootstrap=0
local Assembly: any=nil
local Bootstrapped=false
local Buffered={}
local EntitySequences: {[number]:number}={}
local Generations: {[number]:number}={}
local VisualFolder = Workspace:WaitForChild("ClientVisualEntities")
local CombatFeedback=require(ReplicatedStorage.Assets.CombatFeedback).new(VisualFolder)
local CombatVfx = ReplicatedStorage.Assets:WaitForChild("CombatVfx")
local SkillVfx = require(CombatVfx:WaitForChild("SkillVfx"))
-- Own folder: clearView empties VisualFolder, and pooled VFX must survive that.
local CombatVfxPool = require(CombatVfx:WaitForChild("VfxPool")).new(Workspace)
local ArtPackVisuals = require(ReplicatedStorage:WaitForChild("Assets"):WaitForChild("ArtPackVisuals"))
local HeroRig = ReplicatedStorage.Assets:WaitForChild("HeroRig")
local HeroRigSpec = require(HeroRig:WaitForChild("HeroRigSpec"))
local HeroAnimator = require(HeroRig:WaitForChild("HeroAnimator"))
local HeroLoadout = require(HeroRig:WaitForChild("HeroLoadout"))
local HeroSockets = require(HeroRig:WaitForChild("HeroSockets"))

-- Attack tier codes in the HERO_CUE (TowerProtocol.EncodeHeroCue) -> HeroClips action states.
local ATTACK_TIER_STATES = { [1] = "AttackBasic", [2] = "AttackSpecial", [3] = "AttackSkill" }

-- Hero walk/idle switching (studs of interpolation gap, seconds of grace).
local MOVE_START_GAP = 0.3
local MOVE_KEEP_GAP = 0.05
local MOVE_GRACE = 0.35

-- The hero rig inside a rendered entity when it was built by HeroRegistry (Phase 3 rigs).
local function heroRig(model: Model): Model?
	local art = model:FindFirstChild("ArtPackVisual")
	if art and art:IsA("Model") and art:GetAttribute("HeroRigVersion") ~= nil then
		return art
	end
	return nil
end

-- Hides the nocked arrow on an equipped bow (WeaponModelBuilder's HunterArrow) while a shot is
-- in the air: from an attack's Release marker until its Nock marker or the end of the action.
local function setBowArrowHidden(rig: Model, hidden: boolean)
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

-- Where a shot leaves the hero: the equipped bow's Nock attachment, else the rig's chest.
local function shotOrigin(rig: Model): Vector3
	local weapon = rig:FindFirstChild(HeroSockets.EQUIPPED_NAME)
	local nock = weapon and weapon:FindFirstChild("Nock", true)
	if nock and nock:IsA("Attachment") then
		return nock.WorldPosition
	end
	return rig:GetPivot().Position + Vector3.new(0, 1.5, 0)
end

-- Heroes without a HeroRegistry rig (template missing, placeholder body) carry no weapon.
local function equipHero(model: Model, meta: any)
	local rig = heroRig(model)
	if not rig then return end
	local artifactId = meta and meta.EquippedArtifactId
	if artifactId == "" then artifactId = nil end
	if artifactId or (meta and meta.EquippedArtifactType and meta.EquippedArtifactType ~= "") then
		HeroLoadout.Equip(model, rig, artifactId, meta.EquippedArtifactType, meta.EquippedArtifactRarity)
	else
		HeroLoadout.Unequip(model, rig)
	end
end

type VisualNode = {
	NetId: number,
	IsHero: boolean,
	Model: Model,
	RootPart: BasePart,
	GoalPos: Vector3,
	GoalYaw: number,
	CurrentPos: Vector3,
	CurrentYaw: number,
	HPBarFill: Frame?,
	StamBarFill: Frame?,
	TitleLabel: TextLabel?,
	StateLabel: TextLabel?,
	Highlight: Highlight?,
	LastSeenClock: number,
	HpPermille: number,
	Stamina: number,
	StateEnum: number,
	Flags: number,
}

local MetadataByNetId: { [number]: any } = {}
local VisualNodesByNetId: { [number]: VisualNode } = {}
local LastMetadataRequestClock = -math.huge
local METADATA_REQUEST_INTERVAL = 1.0

local function requestEntityMetadata()
	local now = os.clock()
	if now - LastMetadataRequestClock < METADATA_REQUEST_INTERVAL then
		return
	end
	LastMetadataRequestClock = now
	EntityMetadataRemote:FireServer()
end

-- Expose shared client state for HUD & Input controllers
_G.ClientCombatState = {
	EnemyActions=Actions,ActionMetrics=ActionMetrics,
	VisualNodes = VisualNodesByNetId,
	Metadata = MetadataByNetId,
	FocusedNetId = nil :: number?,
}

-- Legacy getGroundY removed in Phase 0; elevations derive from room context and Vector3 positions

-- Starts a hero attack's VFX at its Release marker (CombatVfx/SkillVfx). Declared after
-- VisualNodesByNetId so the target lookup sees that local. The projectile follows
-- the target's rendered body while it exists and falls back to the server's aim point.
-- Where the server reported hits and heals in the last moment, so area effects (chains, crystal
-- spikes, mends) land on the enemies and allies the server actually picked.
local RECENT_HIT_LIMIT = 64
local RecentHits: { { Kind: string, Position: Vector3, At: number } } = {}

local function recordHit(kind: string, position: any)
	if typeof(position) ~= "Vector3" then
		return
	end
	table.insert(RecentHits, { Kind = kind, Position = position, At = Workspace:GetServerTimeNow() })
	if #RecentHits > RECENT_HIT_LIMIT then
		table.remove(RecentHits, 1)
	end
end

local function recentHits(kind: string, center: Vector3, radius: number, since: number): { Vector3 }
	local found: { Vector3 } = {}
	for _, hit in RecentHits do
		if hit.Kind == kind and hit.At >= since and (hit.Position - center).Magnitude <= radius then
			table.insert(found, hit.Position)
		end
	end
	return found
end

local function playAttackVfx(rig: Model, animator: any, meta: any, cue: any)
	local targetNetId = cue.TargetNetId
	local ownerUserId = meta and meta.OwnerUserId
	SkillVfx.Play(CombatVfxPool, {
		HeroId = meta and meta.TemplateId,
		WeaponType = animator.WeaponType,
		Cue = cue,
		Origin = shotOrigin(rig),
		Target = function(): Vector3
			local target = targetNetId and VisualNodesByNetId[targetNetId]
			if target and target.RootPart.Parent then
				return target.RootPart.Position
			end
			return cue.Aim
		end,
		Self = function(): Vector3
			local node = VisualNodesByNetId[cue.NetId]
			return if node then node.CurrentPos else rig:GetPivot().Position
		end,
		Allies = function(): { Vector3 }
			local positions: { Vector3 } = {}
			for netId, node in VisualNodesByNetId do
				local entry = MetadataByNetId[netId]
				if node.IsHero and node.StateEnum ~= 4 and entry and entry.OwnerUserId == ownerUserId then
					table.insert(positions, node.CurrentPos)
				end
			end
			return positions
		end,
		RecentHits = recentHits,
		Now = Workspace:GetServerTimeNow(),
		Shake = if meta and meta.OwnerUserId == LocalPlayer.UserId then function(magnitude: number)
			CombatFeedback:ScreenShake(magnitude)
		end else nil,
	})
end

local KO_ASSET_TEXTURE = "rbxassetid://10762151233"

local function attachKOVFX(node: any)
	if not node or not node.RootPart or not node.Model or not node.Model.Parent then return end
	local existing = node.RootPart:FindFirstChild("KOAttachment")
	if existing then return end

	local att = Instance.new("Attachment")
	att.Name = "KOAttachment"
	att.Position = Vector3.new(0, 3.8, 0)
	att.Parent = node.RootPart

	local pe = Instance.new("ParticleEmitter")
	pe.Name = "KOParticles"
	pe.Texture = KO_ASSET_TEXTURE
	pe.Size = NumberSequence.new(5)
	pe.Transparency = NumberSequence.new(0)
	pe.Color = ColorSequence.new(Color3.new(1, 1, 1))
	pe.Rate = 1
	pe.Lifetime = NumberRange.new(1, 1)
	pe.Speed = NumberRange.new(0, 0)
	pe.SpreadAngle = Vector2.new(0, 0)
	pe.VelocitySpread = 0
	pe.Acceleration = Vector3.new(0, 0, 0)
	pe.Drag = 4.5
	pe.LockedToPart = true
	pe.LightEmission = 0
	pe.LightInfluence = 0
	pe.Orientation = Enum.ParticleOrientation.FacingCamera
	pe.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8
	pe.FlipbookMode = Enum.ParticleFlipbookMode.Loop
	pe.FlipbookFramerate = NumberRange.new(60, 60)
	pe.TimeScale = 1
	pe.Brightness = 1
	pe.Enabled = true
	pe.Parent = att

	pe:Emit(1)
end

local function removeKOVFX(node: any)
	if not node or not node.RootPart then return end
	local att = node.RootPart:FindFirstChild("KOAttachment")
	if att then
		att:Destroy()
	end
end

local function createEntityModel(netId: number, meta: any, initPos: Vector3): VisualNode
	local isHero = (meta and meta.IsHero) or false
	local model = Instance.new("Model")
	model.Name = string.format("Entity_%d_%s", netId, meta and meta.Name or "Unit")
	model:SetAttribute("NetId", netId)
	model:SetAttribute("IsHero", isHero)
	model:SetAttribute("EntityGeneration",meta.EntityGeneration)
	model:SetAttribute("FloorId",meta.FloorId)
	model:SetAttribute("RoomGeneration",meta.RoomGeneration)

	local bodySize = Vector3.new(2.4, 3.4, 1.4)
	local bodyColor = Color3.fromRGB(90, 170, 255)
	local isBoss = false

	if isHero then
		local seed = meta and HeroCatalog.Seeds[meta.TemplateId]
		bodyColor = (seed and seed.Color) or Color3.fromRGB(85, 175, 255)
	end

	local enemySpec=meta.EnemyId and FirstBiome.Get(meta.EnemyId)
	if enemySpec then bodySize=Vector3.new(enemySpec.Role=="BOSS" and 13 or 5,enemySpec.Height,5);isBoss=enemySpec.Role=="BOSS";bodyColor=Color3.fromRGB(106,149,89) end
	local rootOffsetY = enemySpec and enemySpec.RootHeight or isHero and HeroRigSpec.GROUND_OFFSET or (bodySize.Y * 0.5)
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = isHero and Vector3.new(2, 2, 1) or bodySize
	root.Position = initPos + Vector3.new(0, rootOffsetY, 0)
	root.Color = bodyColor
	root.Material = isBoss and Enum.Material.Neon or Enum.Material.SmoothPlastic
	root.Anchored = true
	root.CanCollide = false
	root.Transparency = 1
	root:SetAttribute("NetId", netId)
	root.Parent = model

	-- Only add fallback Head for non-heroes without art packs
	local head = nil
	if not isHero and not enemySpec and meta and meta.SpecId ~= "mob_mana_node" then
		head = Instance.new("Part")
		head.Name = "Head"
		head.Shape = Enum.PartType.Ball
		local hScale = isBoss and 4.5 or 1.6
		head.Size = Vector3.new(hScale, hScale, hScale)
		head.Color = bodyColor:Lerp(Color3.new(1, 1, 1), 0.25)
		head.Material = isBoss and Enum.Material.Neon or Enum.Material.SmoothPlastic
		head.Anchored = true
		head.CanCollide = false
		head:SetAttribute("NetId", netId)
		head.Position = root.Position + Vector3.new(0, (bodySize.Y * 0.5) + (hScale * 0.45), 0)
		head.Parent = model
	end

	local enemyRig=enemySpec and EnemyAnimation.Attach(model,root,meta.EnemyId)
	local art = not enemyRig and ArtPackVisuals.Attach(model, meta or {}, root, bodySize) or nil
	if art and head then
		head:Destroy()
	elseif isHero and not art then
		-- Fallback visual rig if hero model is missing or loading
		root.Transparency = 0
		root.Material = Enum.Material.SmoothPlastic
		head = Instance.new("Part")
		head.Name = "Head"
		head.Shape = Enum.PartType.Ball
		head.Size = Vector3.new(1.4, 1.4, 1.4)
		head.Color = Color3.fromRGB(255, 224, 196)
		head.Material = Enum.Material.SmoothPlastic
		head.Anchored = true
		head.CanCollide = false
		head:SetAttribute("NetId", netId)
		head.Position = root.Position + Vector3.new(0, 1.8, 0)
		head.Parent = model
	end
	local hl = Instance.new("Highlight")
	hl.FillColor = bodyColor
	hl.OutlineColor = isHero and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(255, 90, 90)
	hl.FillTransparency = 1
	hl.OutlineTransparency = 0.25
	hl.Adornee = art or model
	hl.Parent = model

	-- World-Space BillboardGui (Name, Stars, Green HP Bar, Yellow Stamina Bar)
	local bb = Instance.new("BillboardGui")
	bb.Name = "UnitBillboard"
	bb.Size = isBoss and UDim2.new(0, 240, 0, 64) or UDim2.new(0, 145, 0, 48)
	bb.StudsOffset = Vector3.new(0, (bodySize.Y * 0.5) + (isBoss and 5.5 or 3.2), 0)
	bb.MaxDistance = isBoss and 320 or 150
	bb.AlwaysOnTop = isBoss
	bb.Parent = root

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
	bg.BackgroundTransparency = 0.2
	bg.BorderSizePixel = 0
	bg.Parent = bb

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = bg

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -6, 0.42, 0)
	title.Position = UDim2.new(0, 3, 0, 1)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	if isHero then
		local stars = string.rep("★", (meta and meta.Stars) or 1)
		title.Text = string.format("%s %s Lv.%d", (meta and meta.Name) or "Hero", stars, (meta and meta.Level) or 1)
		title.TextColor3 = Color3.fromRGB(255, 225, 95)
	else
		title.Text = (meta and meta.Name) or "Ruin Entity"
		title.TextColor3 = isBoss and Color3.fromRGB(255, 95, 245) or Color3.fromRGB(255, 130, 130)
	end
	title.Parent = bg

	-- HP Bar
	local hpBg = Instance.new("Frame")
	hpBg.Size = UDim2.new(0.92, 0, 0.22, 0)
	hpBg.Position = UDim2.new(0.04, 0, 0.45, 0)
	hpBg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	hpBg.BorderSizePixel = 0
	hpBg.Parent = bg

	local hpFill = Instance.new("Frame")
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.BackgroundColor3 = isHero and Color3.fromRGB(65, 235, 115) or Color3.fromRGB(245, 65, 85)
	hpFill.BorderSizePixel = 0
	hpFill.Parent = hpBg

	-- Stamina Bar (for Heroes) or State Subtext (for Mobs)
	local stamFill: Frame? = nil
	if isHero then
		local stBg = Instance.new("Frame")
		stBg.Size = UDim2.new(0.92, 0, 0.18, 0)
		stBg.Position = UDim2.new(0.04, 0, 0.72, 0)
		stBg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
		stBg.BorderSizePixel = 0
		stBg.Parent = bg

		local sf = Instance.new("Frame")
		sf.Size = UDim2.fromScale(1, 1)
		sf.BackgroundColor3 = Color3.fromRGB(255, 210, 55)
		sf.BorderSizePixel = 0
		sf.Parent = stBg
		stamFill = sf
	end

	if isHero then
		equipHero(model, meta)
	end

	model.PrimaryPart = root
	model.Parent = VisualFolder

	-- Rigs built by HeroRegistry are posed by HeroAnimator on this client (Motor6D.Transform
	-- does not replicate, so every client animates its own copy).
	local rig = isHero and heroRig(model) or nil
	local animator = rig and HeroAnimator.new(rig, { HeroId = meta and meta.TemplateId }) or nil
	if animator and rig then
		animator.OnMarker = function(marker: string, action: any)
			if marker == "Release" and action.Data then
				-- Cosmetic: a VFX fault must not break this frame's animation and rendering.
				local ok, err = pcall(playAttackVfx, rig, animator, meta, action.Data)
				if not ok then
					warn(`CombatVfx: attack effect failed: {err}`)
				end
			end
			if animator.WeaponType ~= "BOW" then
				return
			end
			if marker == "Release" then
				setBowArrowHidden(rig, true)
			elseif marker == "Nock" or marker == "End" then
				setBowArrowHidden(rig, false)
			end
		end
	end

	return {
		HeroAnimator = animator,
		EnemyRig=enemyRig,RootHeight=rootOffsetY,BornAt=meta.BornAt,
		NetId = netId,
		IsHero = isHero,
		Model = model,
		RootPart = root,
		GoalPos = initPos,
		GoalYaw = 0,
		CurrentPos = initPos,
		CurrentYaw = 0,
		HPBarFill = hpFill,
		StamBarFill = stamFill,
		TitleLabel = title,
		StateLabel = nil,
		Highlight = hl,
		LastSeenClock = os.clock(),
		HpPermille = 1000,
		Stamina = 100,
		StateEnum = 1,
		Flags = 0,
	}
end

local function clearView()
 CombatFeedback:Clear()
 CombatVfxPool:Clear()
 table.clear(RecentHits)
 EnemyAnimation.Clear()
 for _,node in pairs(DyingNodes) do node.Model:Destroy() end;table.clear(DyingNodes)
 Actions=ActionState.New();_G.ClientCombatState.EnemyActions=Actions;table.clear(PendingActions)
 for _,node in pairs(VisualNodesByNetId) do node.Model:Destroy() end
 table.clear(VisualNodesByNetId);table.clear(MetadataByNetId);table.clear(EntitySequences);table.clear(Generations)
 VisualFolder:ClearAllChildren();_G.ClientCombatState.Metadata=MetadataByNetId
 _G.ClientCombatState.FocusedNetId=nil;_G.ClientCombatState.FloorBoss=nil
 Assembly=nil;Bootstrapped=false;table.clear(Buffered);LastBootstrap=0
end
TowerRemotes.Context.OnClientEvent:Connect(function(c)
 if c.Stage~="COMMIT" then return end
 if not Protocol.Same(c,View) then clearView() end
 View=c;_G.TowerView=c
end)
local function retireVisual(id,at)
 local node=VisualNodesByNetId[id];if not node then return end
 VisualNodesByNetId[id]=nil
 if node.EnemyRig and at+1.6>Workspace:GetServerTimeNow() then
  EnemyAnimation.Death(node,at);DyingNodes[ActionState.Key({NetId=id,EntityGeneration=node.Model:GetAttribute("EntityGeneration")})]=node
 else node.Model:Destroy() end
end
local function applyAction(message)
 local id=message.Actor;local now=Workspace:GetServerTimeNow()
 if message.Kind=="HIT" then
  local node=id and VisualNodesByNetId[id.NetId]
  if node and node.Model:GetAttribute("EntityGeneration")==id.EntityGeneration and now-message.StartServerTime<.3 then EnemyAnimation.Hit(node,now) end
  return
 end
 if message.Kind=="IMPACT" then
  local node=id and VisualNodesByNetId[id.NetId]
  local active=Actions.Actors[ActionState.Key(id)]
  if node and not node.DeathAt and node.Model:GetAttribute("EntityGeneration")==id.EntityGeneration and active and not active.Terminal
   and active.Sequence==message.ActionSequence and not active.ImpactShown then
   active.ImpactShown=true;EnemyAnimation.Contact(node,message,View.Origin,now)
  end
  return
 end
 if not ActionState.Receive(Actions,message,MetadataByNetId,now) then ActionMetrics.Rejected+=1;return end
 local node=id and VisualNodesByNetId[id.NetId]
 if node and node.Model:GetAttribute("EntityGeneration")~=id.EntityGeneration then node=nil end
 if message.Kind=="DEATH" then
  ActionMetrics.Deaths+=1
  if _G.ClientCombatState.FloorBoss and _G.ClientCombatState.FloorBoss.NetId==id.NetId then _G.ClientCombatState.FloorBoss.Enabled=false end
  if node then retireVisual(id.NetId,message.StartServerTime) end
 elseif message.Kind=="START" then
  ActionMetrics.Started+=1;if now-message.StartServerTime>.15 then ActionMetrics.Seeks+=1 end
  if node then EnemyAnimation.Action(node,message,View.Origin,now) end
 elseif node then ActionMetrics.Canceled+=1;EnemyAnimation.Cancel(node) end
end
TowerRemotes.TowerAction.OnClientEvent:Connect(function(context,message)
 if not Protocol.Same(context,View) or type(message)~="table" or type(message.Actor)~="table" then return end
 if message.Actor.FloorId~=View.FloorId or message.Actor.RoomGeneration~=View.RoomGeneration then return end
 if Assembly or not Bootstrapped or (message.Kind=="START" and not MetadataByNetId[message.Actor.NetId]) then
  if #PendingActions<128 then table.insert(PendingActions,message) else table.clear(PendingActions);requestEntityMetadata() end
  if not Assembly then requestEntityMetadata() end
  return
 end
 applyAction(message)
end)
local function consume(buf: buffer)
 local packet=Protocol.Decode(buf,View)
 if not packet then return end
 if not Bootstrapped then if #Buffered<2 then table.insert(Buffered,buf) else requestEntityMetadata() end;return end
 local now=os.clock()
 for _,e in packet.Entities do
  local id=e.NetId;local meta=MetadataByNetId[id]
  if Actions.Tombstones[ActionState.Key(e)] then continue end
  if not meta or meta.EntityGeneration~=e.EntityGeneration then requestEntityMetadata();continue end
  if EntitySequences[id]~=nil and not Protocol.Newer(packet.Sequence,EntitySequences[id]) then continue end
  EntitySequences[id]=packet.Sequence
  local node=VisualNodesByNetId[id]
  if not node then
   node=createEntityModel(id,meta,e.Position);VisualNodesByNetId[id]=node
   local active=Actions.Actors[ActionState.Key(e)]
   if active and not active.Terminal and active.Action then EnemyAnimation.Action(node,active.Action,View.Origin,Workspace:GetServerTimeNow()) end
  end
  if node.IsHero and e.Position~=node.GoalPos then
   -- Heroes glide at constant speed from where they are now to the new snapshot over one
   -- snapshot interval, so they arrive as the next one lands (no surge-and-stall at 5 Hz).
   local clock=os.clock();local n=node :: any
   n.SegFrom=node.CurrentPos;n.SegStart=clock
   n.SegDuration=math.clamp(clock-(n.LastSnapshotAt or (clock-0.2)),0.1,0.4);n.LastSnapshotAt=clock
  end
  node.GoalPos=e.Position;node.GoalYaw=e.Yaw;node.HpPermille=e.HpPermille;node.Stamina=e.Stamina
  node.StateEnum=e.StateEnum;node.Flags=e.Flags;node.LastSeenClock=now
  if node.HPBarFill then node.HPBarFill.Size=UDim2.fromScale(e.HpPermille/1000,1) end
  if node.StamBarFill then
   node.StamBarFill.Size=UDim2.fromScale(math.clamp(e.Stamina/100,0,1),1)
   if e.Stamina >= 100 then
    local pulse = (math.sin(now * 8) + 1) * 0.5
    node.StamBarFill.BackgroundColor3 = Color3.fromRGB(255, 215, 60):Lerp(Color3.fromRGB(255, 250, 180), pulse)
   else
    node.StamBarFill.BackgroundColor3 = Color3.fromRGB(255, 210, 55)
   end
  end
  if node.Highlight then
   node.Highlight.OutlineColor=_G.ClientCombatState.FocusedNetId==id and Color3.fromRGB(0,255,235) or bit32.band(e.Flags,2)~=0 and Color3.fromRGB(255,195,40) or Color3.new(1,1,1)
   node.Highlight.OutlineTransparency=meta.TowerEnemy and (_G.ClientCombatState.FocusedNetId==id and .15 or .8) or .25
  end
  if not ActionState.Expected(Actions,e,e.ActionSequence) then requestEntityMetadata() end
 end
end
TowerRemotes.TowerSnapshot.OnClientEvent:Connect(consume)
TowerRemotes.TowerEntityState.OnClientEvent:Connect(function(context,message)
 if not Protocol.Same(context,View) or type(message)~="table" then return end
 local revision=message.BootstrapRevision
 if type(revision)~="number" or revision<=LastBootstrap then return end
 if message.Kind=="BOOTSTRAP" then
  if not Protocol.Integer(message.BatchCount,1,512) or not Protocol.Integer(message.BatchIndex,1,message.BatchCount) or type(message.Entities)~="table" or #message.Entities>32 then return end
  if Assembly and revision<Assembly.Revision then return end
  if not Assembly or Assembly.Revision~=revision then Assembly={Revision=revision,Count=message.BatchCount,Chunks={},Actions={},Started=os.clock()} end
  if Assembly.Count~=message.BatchCount then Assembly=nil;requestEntityMetadata();return end
  Assembly.Chunks[message.BatchIndex]=message.Entities
  Assembly.Actions[message.BatchIndex]=message.Actions or {}
  Assembly.Boss=message.BossPresentation
 elseif message.Kind=="COMPLETE" then
  if not Assembly or Assembly.Revision~=revision then requestEntityMetadata();return end
  local nextMetadata={}
  for i=1,Assembly.Count do
   local chunk=Assembly.Chunks[i];if not chunk then Assembly=nil;requestEntityMetadata();return end
   for _,entry in chunk do
    if not Protocol.Integer(entry.NetId,1,4294967295) or not Protocol.Integer(entry.EntityGeneration,1,4294967295) or nextMetadata[entry.NetId] then Assembly=nil;requestEntityMetadata();return end
    if entry.EntityGeneration<(Generations[entry.NetId] or 0) then continue end
    nextMetadata[entry.NetId]=entry
   end
  end
  for id,node in pairs(VisualNodesByNetId) do
   local new=nextMetadata[id];local old=MetadataByNetId[id]
   if not new or not old or new.EntityGeneration~=old.EntityGeneration then
    if not new and node.EnemyRig then
     Actions.Tombstones[ActionState.Key(old)]=true;retireVisual(id,Workspace:GetServerTimeNow())
    else EnemyAnimation.Cancel(node);node.Model:Destroy();VisualNodesByNetId[id]=nil end
    EntitySequences[id]=nil
   end
  end
  for id,entry in pairs(nextMetadata) do
   Generations[id]=entry.EntityGeneration
   local node=VisualNodesByNetId[id]
   if node and not node.EnemyRig and (node.Model:GetAttribute("ArtPackAssetId")~=ArtPackVisuals.Resolve(entry) or node.IsHero~=(entry.IsHero==true)) then
    local replacement=createEntityModel(id,entry,node.CurrentPos)
    for _,key in {"GoalPos","GoalYaw","CurrentYaw","LastSeenClock","HpPermille","Stamina","StateEnum","Flags"} do (replacement :: any)[key]=(node :: any)[key] end
    node.Model:Destroy();node=replacement;VisualNodesByNetId[id]=node
   end
   if node then
    if node.TitleLabel then node.TitleLabel.Text=entry.IsHero and string.format("%s %s Lv.%d",entry.Name or "Hero",string.rep("★",entry.Stars or 1),entry.Level or 1) or entry.Name or "Mob" end
    if entry.IsHero then
     local currentArtId = node.Model:GetAttribute("EquippedArtifactId")
     local nextArtId = entry.EquippedArtifactId
     if nextArtId == "" then nextArtId = nil end
     if currentArtId ~= nextArtId then
      equipHero(node.Model, entry)
      local animator = (node :: any).HeroAnimator
      if animator then animator:SetWeaponType(node.Model:GetAttribute("EquippedArtifactType")) end
     end
    end
   end
  end
  MetadataByNetId=nextMetadata;_G.ClientCombatState.Metadata=MetadataByNetId
  local bootstrapActions=Assembly.Actions
  _G.ClientCombatState.FloorBoss=Assembly.Boss
  LastBootstrap=revision;Assembly=nil;Bootstrapped=true
  for _,chunk in pairs(bootstrapActions) do for _,action in chunk do applyAction(action) end end
  local queued=PendingActions;PendingActions={};for _,action in queued do applyAction(action) end
  local pending=Buffered;Buffered={};for _,buf in pending do consume(buf) end
 end
end)
-- Reliable full roster cuts define existence. Packet loss only freezes poses and requests resync.
RunService.Heartbeat:Connect(function()
 local now=os.clock()
 if Assembly and now-Assembly.Started>3 then Assembly=nil;requestEntityMetadata() end
 for _,node in pairs(VisualNodesByNetId) do if now-node.LastSeenClock>1 then requestEntityMetadata() end end
end)
requestEntityMetadata()

-- 60 FPS Smooth Interpolation Loop
RunService.RenderStepped:Connect(function(dt: number)
	CombatFeedback:Step(os.clock())
	local serverNow=Workspace:GetServerTimeNow();EnemyAnimation.StepEffects(serverNow)
	CombatVfxPool:Step(serverNow)
	for key,node in pairs(DyingNodes) do
		if serverNow>=node.DeathEnd then node.Model:Destroy();DyingNodes[key]=nil else EnemyAnimation.Step(node,dt,serverNow) end
	end
	local alpha = math.clamp(dt * 12.0, 0, 1)
	for _, node in pairs(VisualNodesByNetId) do
		local n = node :: any
		local yaw = node.GoalYaw
		if (node.GoalPos - node.CurrentPos).Magnitude > 35 then
			node.CurrentPos = node.GoalPos
			n.SegStart = nil
		elseif node.IsHero and n.SegStart then
			local t = math.clamp((os.clock() - n.SegStart) / n.SegDuration, 0, 1)
			node.CurrentPos = n.SegFrom:Lerp(node.GoalPos, t)
		else
			node.CurrentPos = node.CurrentPos:Lerp(node.GoalPos, alpha)
		end
		if node.IsHero then
			-- Turn smoothly toward the snapshot yaw along the shortest arc.
			local diff = (node.GoalYaw - node.CurrentYaw + math.pi) % (2 * math.pi) - math.pi
			node.CurrentYaw += diff * math.clamp(dt * 10, 0, 1)
			yaw = node.CurrentYaw
		end
		local bodyH = (node :: any).RootHeight or node.IsHero and HeroRigSpec.GROUND_OFFSET or (node.RootPart.Size.Y * 0.5)
		local cf = CFrame.new(node.CurrentPos + Vector3.new(0, bodyH, 0)) * CFrame.Angles(0, yaw, 0)
		node.Model:PivotTo(cf)
		local animator = (node :: any).HeroAnimator
		if (node :: any).EnemyRig then
			EnemyAnimation.Step(node,dt,serverNow)
		elseif animator then
			debug.profilebegin("HeroAnimator.Step")
			-- Hysteresis: positions arrive at 5 Hz, so the lerp gap dips below any single
			-- threshold between snapshots. Start walking on a clear gap and keep walking until
			-- the hero has been still for MOVE_GRACE, so Move/Idle do not flicker every frame.
			local gap = (node.GoalPos - node.CurrentPos).Magnitude
			local now = os.clock()
			if gap > MOVE_START_GAP or ((node :: any).WalkingUntil and gap > MOVE_KEEP_GAP) then
				(node :: any).WalkingUntil = now + MOVE_GRACE
			end
			local walking = ((node :: any).WalkingUntil or 0) > now
			local isKnockedOut = node.StateEnum == 4 or (node.HpPermille ~= nil and node.HpPermille <= 0)
			animator:SetLocomotion(if isKnockedOut then "Coma" elseif walking then "Move" else "Idle")
			animator:Step(dt)
			debug.profileend()
		else
			ArtPackVisuals.Animate(node, dt, os.clock())
		end
		if node.IsHero then
			local isKnockedOut = node.StateEnum == 4 or (node.HpPermille ~= nil and node.HpPermille <= 0)
			if isKnockedOut then
				attachKOVFX(node)
			else
				removeKOVFX(node)
			end
		end
		local head = node.Model:FindFirstChild("Head") :: BasePart?
		if head and not node.IsHero then
			head.Position = cf.Position + Vector3.new(0, bodyH + (head.Size.Y * 0.45), 0)
		end
	end
end)

--============================================================================
-- TELEGRAPH VFX (DEVOURING NOVA, ELITE AOES & WHISTLE RINGS)
--============================================================================

BossTelegraphRemote.OnClientEvent:Connect(function(context: any, telegraphType: number, origin: any, radius: number, durationMs: number)
	if not Protocol.Same(context,View) then return end
	local durationSec = durationMs / 1000.0
	local ox: number, oy: number, oz: number
	if typeof(origin) == "Vector3" then
		ox, oy, oz = origin.X, origin.Y + 0.25, origin.Z
	elseif typeof(origin) == "Vector2int16" or typeof(origin) == "Vector2" then
		ox, oz = origin.X, origin.Y
		local floorY = (View and View.Origin and View.Origin.Y) or 0
		oy = floorY + 0.25
	else
		return
	end

	if telegraphType == 1 then
		-- DEVOURING NOVA (3.0s Red Telegraph on Ring 3, R = 85 studs)
		_G.ClientCombatState.NovaCastStartClock = os.clock()
		_G.ClientCombatState.NovaCastDuration = durationSec
	end

	if telegraphType == 1 or telegraphType == 3 then
		local ringPart = Instance.new("Part")
		ringPart.Name = "AoETelegraphDisk"
		ringPart.Shape = Enum.PartType.Cylinder
		ringPart.Size = Vector3.new(0.3, 2, 2)
		ringPart.CFrame = CFrame.new(ox, oy, oz) * CFrame.Angles(0, 0, math.rad(90))
		ringPart.Color = (telegraphType == 1) and Color3.fromRGB(255, 25, 55) or Color3.fromRGB(255, 95, 40)
		ringPart.Material = Enum.Material.Neon
		ringPart.Transparency = 0.45
		ringPart.Anchored = true
		ringPart.CanCollide = false
		ringPart.Parent = VisualFolder

		local goalDiameter = radius * 2
		local tween = TweenService:Create(
			ringPart,
			TweenInfo.new(durationSec, Enum.EasingStyle.Linear),
			{ Size = Vector3.new(0.35, goalDiameter, goalDiameter), Transparency = 0.15 }
		)
		tween:Play()
		task.delay(durationSec + 0.15, function()
			ringPart:Destroy()
		end)
	end
end)

CombatVFXRemote.OnClientEvent:Connect(function(context: any, vfxType: string, pos: Vector3, amount: number?, isOverdrive: any, incoming: any)
	if not Protocol.Same(context,View) then return end
	if vfxType=="HERO_CUE" then
		-- Cosmetic attack cue: play the tier's clip over the server's cast time, starting late if
		-- the cue arrived late. The animator's markers then time the bow arrow (and, later, VFX).
		local cue = Protocol.DecodeHeroCue(pos)
		local node = cue and VisualNodesByNetId[cue.NetId]
		local animator = node and (node :: any).HeroAnimator
		if cue and animator and node.Model:GetAttribute("EntityGeneration") == cue.EntityGeneration then
			local elapsed = math.max(0, Workspace:GetServerTimeNow() - cue.StartServerTime)
			if elapsed < cue.CastSeconds then
				animator:PlayAction(ATTACK_TIER_STATES[cue.Tier] or "AttackBasic", cue.CastSeconds, elapsed, cue)
			end
		end
		return
	elseif vfxType=="HERO_KO" then
		local node = VisualNodesByNetId[amount or -1]
		if node then
			attachKOVFX(node)
		end
		return
	elseif vfxType=="HIT_SPARK" then
		recordHit("HIT",pos)
		CombatFeedback:Hit(pos,amount,isOverdrive,incoming)
		return
	elseif vfxType=="HIT_SPECIAL" then
		recordHit("HIT",pos)
		CombatFeedback:Special(pos,amount,isOverdrive,incoming)
		return
	elseif vfxType=="HIT_SKILL" then
		recordHit("HIT",pos)
		CombatFeedback:Skill(pos,amount,vfxType)
		return
	elseif vfxType=="SKILL_CAST" or vfxType=="SKILL_TEMPEST" or vfxType=="SKILL_METEOR" or vfxType=="SKILL_ARROWS" or vfxType=="SKILL_CRYSTAL" or vfxType=="SKILL_SHIELD" or vfxType=="BARRIER_APPLIED" then
		CombatFeedback:Skill(pos,amount,vfxType)
		return
	elseif vfxType=="HEAL_SPARK" or vfxType=="HEAL_BURST" then
		recordHit("HEAL",pos)
		CombatFeedback:Heal(pos,amount)
		return
	end
	if vfxType == "WHISTLE_Q" or vfxType == "WHISTLE_E" then
		local pulse = Instance.new("Part")
		pulse.Shape = Enum.PartType.Cylinder
		pulse.Size = Vector3.new(0.3, 4, 4)
		pulse.CFrame = CFrame.new(pos.X, pos.Y - 1.5, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
		pulse.Color = (vfxType == "WHISTLE_Q") and Color3.fromRGB(255, 185, 35) or Color3.fromRGB(55, 240, 255)
		pulse.Material = Enum.Material.Neon
		pulse.Transparency = 0.25
		pulse.Anchored = true
		pulse.CanCollide = false
		pulse.Parent = VisualFolder

		TweenService:Create(
			pulse,
			TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.new(0.3, 28, 28), Transparency = 1.0 }
		):Play()
		task.delay(0.5, function()
			pulse:Destroy()
		end)
	end
end)


