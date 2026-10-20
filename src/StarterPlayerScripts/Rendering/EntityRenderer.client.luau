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
local WorldBossConfig = require(Shared:WaitForChild("Config"):WaitForChild("WorldBossConfig"))

local CombatRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CombatRemotes")
local ReplicationTickRemote = CombatRemotes:WaitForChild("ReplicationTick") :: UnreliableRemoteEvent
local BossTelegraphRemote = CombatRemotes:WaitForChild("BossTelegraph") :: RemoteEvent
local CombatVFXRemote = CombatRemotes:WaitForChild("CombatVFX") :: UnreliableRemoteEvent
local EntityMetadataRemote = CombatRemotes:WaitForChild("EntityMetadataSync") :: RemoteEvent

local VisualFolder = Workspace:WaitForChild("ClientVisualEntities")
local ArtPackVisuals = require(ReplicatedStorage:WaitForChild("Assets"):WaitForChild("ArtPackVisuals"))

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
	VisualNodes = VisualNodesByNetId,
	Metadata = MetadataByNetId,
	FocusedNetId = nil :: number?,
	WorldBossNetId = nil :: number?,
	WorldBossHPPerMille = 1000,
	WorldBossPhase = 1,
	WorldBossCoreExposed = false,
	NovaCastStartClock = 0,
	NovaCastDuration = 0,
}

local function getGroundY(x: number, z: number): number
	local r = math.sqrt(x * x + z * z)
	if r <= 122 then
		return 16.0
	elseif r <= 282 then
		return 4.0
	elseif r <= 462 then
		return 2.0
	end
	return 12.0
end

local function createEntityModel(netId: number, meta: any, initPos: Vector3): VisualNode
	local isHero = (meta and meta.IsHero) or false
	local model = Instance.new("Model")
	model.Name = string.format("Entity_%d_%s", netId, meta and meta.Name or "Unit")
	model:SetAttribute("NetId", netId)
	model:SetAttribute("IsHero", isHero)

	local bodySize = Vector3.new(2.4, 3.4, 1.4)
	local bodyColor = Color3.fromRGB(90, 170, 255)
	local isBoss = false

	if isHero then
		local seed = meta and HeroCatalog.Seeds[meta.TemplateId]
		bodyColor = (seed and seed.Color) or Color3.fromRGB(85, 175, 255)
	else
		local spec = meta and (WorldBossConfig.MobSpecs :: any)[meta.SpecId]
		if meta and meta.MobType == "WORLD_BOSS" then
			bodySize = Vector3.new(13, 20, 13)
			bodyColor = Color3.fromRGB(190, 35, 255)
			isBoss = true
		elseif spec then
			bodySize = spec.Size or Vector3.new(4, 5.5, 4)
			bodyColor = spec.Color or Color3.fromRGB(215, 75, 95)
			if meta.MobType == "RIFT_BOSS" then
				isBoss = true
			end
		end
	end

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = bodySize
	root.Position = initPos + Vector3.new(0, bodySize.Y * 0.5, 0)
	root.Color = bodyColor
	root.Material = isBoss and Enum.Material.Neon or Enum.Material.SmoothPlastic
	root.Anchored = true
	root.CanCollide = false
	root:SetAttribute("NetId", netId)
	root.Parent = model

	-- Add Head for character silhouette
	if isHero or (meta and meta.SpecId ~= "mob_mana_node") then
		local head = Instance.new("Part")
		head.Name = "Head"
		head.Shape = Enum.PartType.Ball
		local hScale = isBoss and 4.5 or 1.6
		head.Size = Vector3.new(hScale, hScale, hScale)
		head.Color = isHero and Color3.fromRGB(245, 215, 190) or bodyColor:Lerp(Color3.new(1, 1, 1), 0.25)
		head.Material = isBoss and Enum.Material.Neon or Enum.Material.SmoothPlastic
		head.Anchored = true
		head.CanCollide = false
		head:SetAttribute("NetId", netId)
		head.Position = root.Position + Vector3.new(0, (bodySize.Y * 0.5) + (hScale * 0.45), 0)
		head.Parent = model
	end

	ArtPackVisuals.Attach(model, meta or {}, root, bodySize)
	local hl = Instance.new("Highlight")
	hl.FillColor = bodyColor
	hl.OutlineColor = isHero and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(255, 90, 90)
	hl.FillTransparency = 1
	hl.OutlineTransparency = 0.15
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

	model.PrimaryPart = root
	model.Parent = VisualFolder

	return {
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

EntityMetadataRemote.OnClientEvent:Connect(function(metaTable: any)
	if type(metaTable) ~= "table" then
		return
	end

	-- Index payload records by numeric IDs, accepting the dense list and legacy keyed maps.
	local normalizedMetadata: { [number]: any } = {}
	for key, meta in pairs(metaTable) do
		if type(meta) == "table" then
			local netId = tonumber(meta.NetId) or tonumber(key)
			if netId then
				normalizedMetadata[netId] = meta
			end
		end
	end
	MetadataByNetId = normalizedMetadata
	_G.ClientCombatState.Metadata = MetadataByNetId

	local foundWorldBoss: number? = nil
	for netId, meta in pairs(MetadataByNetId) do
		if not meta.IsHero and meta.MobType == "WORLD_BOSS" then
			foundWorldBoss = netId
		end
		local node = VisualNodesByNetId[netId]
        if node and (node.Model:GetAttribute("ArtPackAssetId") ~= ArtPackVisuals.Resolve(meta) or node.IsHero ~= (meta.IsHero == true)) then
            local replacement=createEntityModel(netId,meta,node.CurrentPos)
            for _,key in {"GoalPos","GoalYaw","CurrentYaw","LastSeenClock","HpPermille","Stamina","StateEnum","Flags"} do
                (replacement :: any)[key]=(node :: any)[key]
            end
            node.Model:Destroy();node=replacement;VisualNodesByNetId[netId]=replacement
        end
		if node and node.TitleLabel then
			if meta.IsHero then
				local stars = string.rep("★", meta.Stars or 1)
				node.TitleLabel.Text = string.format("%s %s Lv.%d", meta.Name or "Hero", stars, meta.Level or 1)
			else
				node.TitleLabel.Text = meta.Name or "Mob"
			end
		end
	end
	_G.ClientCombatState.WorldBossNetId = foundWorldBoss
end)

-- Unpack 5 Hz Binary Buffer Snapshot
ReplicationTickRemote.OnClientEvent:Connect(function(buf: buffer)
	local count = buffer.readu8(buf, 0)
	local now = os.clock()
	local offset = 5
	local needsMetadata = false

	for i = 1, count do
		local netId = buffer.readu16(buf, offset + 0)
		local posX = buffer.readi16(buf, offset + 2) / 10.0
		local posZ = buffer.readi16(buf, offset + 4) / 10.0
		local yawByte = buffer.readu8(buf, offset + 6)
		local stateEnum = buffer.readu8(buf, offset + 7)
		local hpPermille = buffer.readu16(buf, offset + 8)
		local stamina = buffer.readu8(buf, offset + 10)
		local flags = buffer.readu8(buf, offset + 11)
		offset += 12

		local yaw = ((yawByte / 255.0) * (math.pi * 2)) - math.pi
		local y = getGroundY(posX, posZ)
		local goalPos = Vector3.new(posX, y, posZ)

		local meta = MetadataByNetId[netId]
		local node = VisualNodesByNetId[netId]
		if not meta then
			-- Identity is not in the snapshot; wait for it instead of rendering heroes as mobs.
			needsMetadata = true
			if node then
				node.Model:Destroy()
				VisualNodesByNetId[netId] = nil
			end
			continue
		end
		if not node then
			node = createEntityModel(netId, meta, goalPos)
			VisualNodesByNetId[netId] = node
		end

		node.GoalPos = goalPos
		node.GoalYaw = yaw
		node.HpPermille = hpPermille
		node.Stamina = stamina
		node.StateEnum = stateEnum
		node.Flags = flags
		node.LastSeenClock = now

		if node.HPBarFill then
			node.HPBarFill.Size = UDim2.fromScale(math.clamp(hpPermille / 1000.0, 0, 1), 1)
		end
		if node.StamBarFill then
			node.StamBarFill.Size = UDim2.fromScale(math.clamp(stamina / 100.0, 0, 1), 1)
		end

		-- Check Overdrive / Focused Highlight
		if node.Highlight then
			local isOverdrive = bit32.band(flags, 1) ~= 0
			local isFocused = (_G.ClientCombatState.FocusedNetId == netId)
			if isFocused then
				node.Highlight.OutlineColor = Color3.fromRGB(0, 255, 235)
				node.Highlight.OutlineTransparency = 0
			elseif isOverdrive then
				node.Highlight.OutlineColor = Color3.fromRGB(255, 195, 40)
				node.Highlight.OutlineTransparency = 0
			else
				node.Highlight.OutlineColor = node.IsHero and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(255, 85, 85)
				node.Highlight.OutlineTransparency = 0.25
			end
		end

		if meta and meta.MobType == "WORLD_BOSS" then
			_G.ClientCombatState.WorldBossNetId = netId
			_G.ClientCombatState.WorldBossHPPerMille = hpPermille
			_G.ClientCombatState.WorldBossPhase = math.max(1, stateEnum - 10)
			_G.ClientCombatState.WorldBossCoreExposed = (bit32.band(flags, 4) ~= 0)
		end
	end
	if needsMetadata then
		requestEntityMetadata()
	end

	-- Clean up stale entities not seen for > 0.8s
	for netId, node in pairs(VisualNodesByNetId) do
		if (now - node.LastSeenClock) > 0.85 then
			node.Model:Destroy()
			VisualNodesByNetId[netId] = nil
			if _G.ClientCombatState.WorldBossNetId == netId then
				_G.ClientCombatState.WorldBossNetId = nil
			end
		end
	end
end)

-- Request the initial identities after both listeners are ready, including late client starts.
requestEntityMetadata()

-- 60 FPS Smooth Interpolation Loop
RunService.RenderStepped:Connect(function(dt: number)
	local alpha = math.clamp(dt * 12.0, 0, 1)
	for _, node in pairs(VisualNodesByNetId) do
		node.CurrentPos = node.CurrentPos:Lerp(node.GoalPos, alpha)
		local bodyH = node.RootPart.Size.Y * 0.5
		local cf = CFrame.new(node.CurrentPos + Vector3.new(0, bodyH, 0)) * CFrame.Angles(0, node.GoalYaw, 0)
		node.Model:PivotTo(cf)
		ArtPackVisuals.Animate(node,dt,os.clock())
		local head = node.Model:FindFirstChild("Head") :: BasePart?
		if head then
			head.Position = cf.Position + Vector3.new(0, bodyH + (head.Size.Y * 0.45), 0)
		end
	end
end)

--============================================================================
-- TELEGRAPH VFX (DEVOURING NOVA, ELITE AOES & WHISTLE RINGS)
--============================================================================

BossTelegraphRemote.OnClientEvent:Connect(function(telegraphType: number, originXZ: Vector2int16, radius: number, durationMs: number)
	local durationSec = durationMs / 1000.0
	local ox = originXZ.X
	local oz = originXZ.Y
	local oy = getGroundY(ox, oz) + 0.25

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

CombatVFXRemote.OnClientEvent:Connect(function(vfxType: string, pos: Vector3, amount: number?, isOverdrive: boolean?)
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


