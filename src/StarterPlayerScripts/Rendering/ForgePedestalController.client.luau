--!strict
debug.setmemorycategory("ForgePedestals")
-- StarterPlayerScripts/Rendering/ForgePedestalController.client.luau
-- Renders 3D rolled weapons and world-space stud-sized Rarity + Name + Cost labels above Open Forge
-- pedestals (Pedestal_1..6) across Workspace.WaitingRoomPlots.
-- Driven by Building_Blacksmith's RollBatchSeq for a strict sequential 1-pedestal-at-a-time rolling
-- animation (Pedestal 1 rolls -> reveals -> Pedestal 2 rolls -> reveals -> ... -> Pedestal N),
-- setting LocalPlayer:SetAttribute("ForgeRollAnimating", true) until the final pedestal finishes.

local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArtifactCatalog = require(Shared:WaitForChild("Config"):WaitForChild("ArtifactCatalog"))
local BillboardThemes = require(Shared:WaitForChild("Config"):WaitForChild("BillboardThemes"))
local StatBalance = require(Shared:WaitForChild("Config"):WaitForChild("StatBalance"))
local AudioManager = require(script.Parent.Parent:WaitForChild("Audio"):WaitForChild("AudioManager"))
local UIFeel = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIFeel"))
local Kit = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Kit"))

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Tokens = Kit.Tokens
local New = Tokens.New

local MAX_RENDER_DISTANCE = 140
local VFX_CULL_DISTANCE = 65
local LABEL_MAX_DISTANCE = 68
local SPIN_SPEED = 0.85
local BOB_HEIGHT = 0.20
local BOB_SPEED = 2.0
local BRONZE_DEFAULT = Color3.fromRGB(186, 138, 68)
local SPARK_TEXTURE = "rbxassetid://243660364"

local DEFAULT_SLOT_ROLL_SECONDS = 0.42
local REVEAL_DURATION = 0.36
local CYCLE_STEP_SEC = 0.065

local ROLL_CYCLE_COLORS: { Color3 } = {}
for t = 1, 7 do
	ROLL_CYCLE_COLORS[t] = ArtifactCatalog.GetRarityInfo(t).Color
end

local billboardFolder = New("Folder", { Name = "ForgePedestalLabels" }, PlayerGui)
local worldVisualFolder = Workspace:FindFirstChild("ClientForgePedestalVisuals") :: Folder?
if not worldVisualFolder then
	local created = Instance.new("Folder")
	created.Name = "ClientForgePedestalVisuals"
	created.Parent = Workspace
	worldVisualFolder = created
end

type AnimPhase = "IDLE" | "QUEUED" | "ROLLING" | "REVEALING"

type PedestalVisual = {
	Pedestal: Model,
	Forge: Model?,
	Plot: Instance?,
	SlotIndex: number,
	Anchor: Attachment,
	RuneRing: BasePart?,
	WeaponModel: Model?,
	PendingWeaponModel: Model?,
	PendingHalfHeight: number,
	PendingBaseScale: number,
	PendingEmitters: { ParticleEmitter },
	RollCore: Model?,
	RollOuterPart: BasePart?,
	RollInnerPart: BasePart?,
	EmitterList: { ParticleEmitter },
	Light: PointLight?,
	BurstPart: Part,
	BurstEmitter: ParticleEmitter,
	TargetBeam: Beam,
	Billboard: BillboardGui,
	RarityLabel: TextLabel,
	NameLabel: TextLabel,
	PriceLabel: TextLabel,
	TemplateId: string,
	LoadingTemplateId: string,
	LoadToken: number,
	BaseScale: number,
	ModelHalfHeight: number,
	TargetTier: number,
	TargetColor: Color3,
	TargetLightBrightness: number,
	TargetLightRange: number,
	TargetMatched: boolean,
	AnimPhase: AnimPhase,
	RollStartAt: number,
	RollEndAt: number,
	RevealStart: number,
	LastCycleIdx: number,
	Phase: number,
	Connections: { RBXScriptConnection },
}

local activePedestals: { [Model]: PedestalVisual } = {}
local pendingPedestals: { [Model]: boolean } = {}
local localRollEndAt = 0

type PreparedPrefab = {
	Template: Model,
	HalfHeight: number,
	BaseScale: number,
}
local preparedCache: { [string]: PreparedPrefab } = {}
local cachedWeaponsFolder: Folder? = nil
local cachedBuilder: any = nil
local builderChecked = false

local function setLocalRollAnimating(active: boolean)
	if LocalPlayer:GetAttribute("ForgeRollAnimating") ~= active then
		LocalPlayer:SetAttribute("ForgeRollAnimating", active)
	end
end
setLocalRollAnimating(false)

local function getPlotAncestor(inst: Instance): Instance?
	local cur: Instance? = inst
	while cur and cur.Parent do
		if cur.Parent.Name == "WaitingRoomPlots" then
			return cur
		end
		cur = cur.Parent
	end
	return nil
end

local function getForgeAncestor(inst: Instance): Model?
	local cur: Instance? = inst.Parent
	while cur do
		if cur:IsA("Model") and cur.Name == "Building_Blacksmith" then
			return cur
		end
		cur = cur.Parent
	end
	return nil
end

local function isOwnedByLocalPlayer(plot: Instance?): boolean
	if not plot then
		return false
	end
	return plot:GetAttribute("OwnerUserId") == LocalPlayer.UserId
end

local function setPedestalStoneVisible(pedestal: Model, unlocked: boolean)
	for _, child in pedestal:GetChildren() do
		if child:IsA("BasePart") then
			if child.Name == "PedestalRoot" then
				child.CanCollide = unlocked
				child.Transparency = 1
			else
				child.Transparency = if unlocked then 0 else 1
			end
		end
	end
end

local function getWeaponsFolder(waitTime: number?): Folder?
	if cachedWeaponsFolder and cachedWeaponsFolder.Parent then
		return cachedWeaponsFolder
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
		or (if waitTime then ReplicatedStorage:WaitForChild("Assets", waitTime) else nil)
	if not assets then
		return nil
	end
	local weapons = assets:FindFirstChild("Weapons")
		or (if waitTime then assets:WaitForChild("Weapons", waitTime) else nil)
	if weapons and weapons:IsA("Folder") then
		cachedWeaponsFolder = weapons
		return weapons
	end
	return nil
end

local function getWeaponModelBuilder(): any
	if builderChecked then
		return cachedBuilder
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local builderMod = assets and assets:FindFirstChild("WeaponModelBuilder")
	if builderMod then
		builderChecked = true
		local ok, mod = pcall(require, builderMod)
		if ok then
			cachedBuilder = mod
		end
	end
	return cachedBuilder
end

local function cloneRawWeaponModel(modelAssetId: string, waitTime: number?): Model?
	local builder = getWeaponModelBuilder()
	if builder and builder.IsGildedTemplate and builder.IsGildedTemplate(modelAssetId) then
		return builder.CloneOrBuildPrefab(modelAssetId)
	end
	local weapons = getWeaponsFolder(waitTime)
	if not weapons then
		return nil
	end
	local source = weapons:FindFirstChild(modelAssetId)
		or (if waitTime then weapons:WaitForChild(modelAssetId, waitTime) else nil)
	if source and source:IsA("Model") and source:FindFirstChildWhichIsA("BasePart", true) then
		return source:Clone()
	end
	return nil
end

-- Poses a cloned weapon assembly upright & centered around CFrame.identity for 3D pedestal display.
local function prepareWeaponForPedestal(model: Model): (number, number, { ParticleEmitter })
	local emitters: { ParticleEmitter } = {}
	local visibleParts: { BasePart } = {}

	local shield = model:FindFirstChild("OffhandShield")
	local leftDagger = model:FindFirstChild("LeftDagger")
	if shield and shield:IsA("Model") then
		shield:PivotTo(model:GetPivot() * CFrame.new(-0.95, -0.2, 0.35) * CFrame.Angles(0, math.rad(22), 0))
	end
	if leftDagger and leftDagger:IsA("Model") then
		leftDagger:PivotTo(model:GetPivot() * CFrame.new(-0.75, 0, 0) * CFrame.Angles(0, 0, math.rad(-26)))
	end

	for _, desc in model:GetDescendants() do
		if desc:IsA("LuaSourceContainer") or desc:IsA("WeldConstraint") or desc:IsA("Weld") or desc:IsA("Motor6D") or desc:IsA("Trail") then
			desc:Destroy()
		elseif desc:IsA("ParticleEmitter") then
			table.insert(emitters, desc)
		elseif desc:IsA("BasePart") then
			desc.Anchored = true
			desc.CanCollide = false
			desc.CanTouch = false
			desc.CanQuery = false
			desc.CastShadow = false
			if desc.Transparency < 0.98 then
				table.insert(visibleParts, desc)
			end
		end
	end

	local bounds, size = model:GetBoundingBox()
	local maxExtent = math.max(size.X, size.Y, size.Z)
	local targetScale = if maxExtent > 5.0 then 4.6 / maxExtent elseif maxExtent > 0.1 and maxExtent < 2.4 then 2.6 / maxExtent else 1.0
	if math.abs(targetScale - 1.0) > 0.04 then
		model:ScaleTo(model:GetScale() * targetScale)
		bounds, size = model:GetBoundingBox()
	end

	local axes = {
		{ Dir = bounds.RightVector, Len = size.X, NativeUp = false },
		{ Dir = bounds.UpVector, Len = size.Y, NativeUp = true },
		{ Dir = bounds.LookVector, Len = size.Z, NativeUp = false },
	}
	table.sort(axes, function(a, b)
		return a.Len > b.Len
	end)
	local long, mid, thin = axes[1], axes[2], axes[3]
	if long.Len >= mid.Len * 1.45 then
		local up = long.Dir
		if not long.NativeUp then
			local weight, moment = 0, 0
			for _, p in visibleParts do
				local vol = p.Size.X * p.Size.Y * p.Size.Z
				weight += vol
				moment += vol * (p.Position - bounds.Position):Dot(up)
			end
			if weight > 0 and moment < 0 then
				up = -up
			end
		end
		local orient = CFrame.fromMatrix(bounds.Position, up:Cross(thin.Dir), up, thin.Dir)
		local display = CFrame.Angles(math.rad(10), 0, math.rad(-18))
		model:PivotTo(display * orient:Inverse() * model:GetPivot())
	else
		local display = CFrame.Angles(math.rad(16), math.rad(-24), 0)
		model:PivotTo(display * bounds:Inverse() * model:GetPivot())
	end

	model.PrimaryPart = nil
	local finalBounds, finalSize = model:GetBoundingBox()
	model:PivotTo(CFrame.new(-finalBounds.Position) * model:GetPivot())
	model.WorldPivot = CFrame.identity
	return math.max(1.2, finalSize.Y * 0.5), model:GetScale(), emitters
end

local function collectEmitters(model: Model): { ParticleEmitter }
	local emitters: { ParticleEmitter } = {}
	for _, desc in model:GetDescendants() do
		if desc:IsA("ParticleEmitter") then
			table.insert(emitters, desc)
		end
	end
	return emitters
end

-- Builds and caches a showcase-ready template for `modelAssetId` so subsequent pedestal clones are instant.
local function getOrBuildPreparedPrefab(modelAssetId: string, waitTime: number?): PreparedPrefab?
	local existing = preparedCache[modelAssetId]
	if existing then
		return existing
	end
	local raw = cloneRawWeaponModel(modelAssetId, waitTime)
	if not raw then
		return nil
	end
	local halfH, baseScale = prepareWeaponForPedestal(raw)
	local entry: PreparedPrefab = {
		Template = raw,
		HalfHeight = halfH,
		BaseScale = baseScale,
	}
	preparedCache[modelAssetId] = entry
	return entry
end

-- Background warmup: preloads every Open Forge weapon's meshes/textures via ContentProvider:PreloadAsync
-- and pre-poses showcase templates so the very first roll of any artifact renders with zero delay.
task.spawn(function()
	local weapons = getWeaponsFolder(20)
	if not weapons then
		return
	end
	local preloadedIds: { [string]: boolean } = {}
	local function warmId(modelAssetId: string)
		if preloadedIds[modelAssetId] then
			return
		end
		local src = weapons:FindFirstChild(modelAssetId)
		if not (src and src:IsA("Model") and src:FindFirstChildWhichIsA("BasePart", true)) then
			return
		end
		preloadedIds[modelAssetId] = true
		getOrBuildPreparedPrefab(modelAssetId, nil)
	end

	-- Pass 1: warm all 84 Open Forge catalog weapons in small non-blocking batches + PreloadAsync GPU assets
	local batch: { Instance } = {}
	local builtCount = 0
	for _, id in ipairs(ArtifactCatalog.CatalogOrder) do
		local seed = ArtifactCatalog.Seeds[id]
		if seed and type(seed.ModelAssetId) == "string" then
			local src = weapons:FindFirstChild(seed.ModelAssetId)
			if src then
				table.insert(batch, src)
			end
			warmId(seed.ModelAssetId)
			builtCount += 1
			if #batch >= 12 then
				local toPreload = batch
				batch = {}
				task.spawn(function()
					pcall(function()
						ContentProvider:PreloadAsync(toPreload)
					end)
				end)
			end
			if builtCount % 6 == 0 then
				task.wait()
			end
		end
	end
	if #batch > 0 then
		local toPreload = batch
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync(toPreload)
			end)
		end)
	end

	-- Pass 2: if server finishes populating any remaining weapon models after client join, warm them immediately
	weapons.ChildAdded:Connect(function(child)
		if child:IsA("Model") and not preloadedIds[child.Name] then
			task.defer(function()
				if not child.Parent then
					return
				end
				warmId(child.Name)
				pcall(function()
					ContentProvider:PreloadAsync({ child })
				end)
			end)
		end
	end)
end)

local function createRollCore(pos: Vector3): (Model, Part, Part)
	local core = Instance.new("Model")
	core.Name = "ForgeRollCore"

	local outer = Instance.new("Part")
	outer.Name = "OuterCrystal"
	outer.Size = Vector3.new(1.65, 1.65, 1.65)
	outer.Material = Enum.Material.Neon
	outer.Color = Color3.fromRGB(255, 196, 72)
	outer.Transparency = 0.22
	outer.Anchored = true
	outer.CanCollide = false
	outer.CanTouch = false
	outer.CanQuery = false
	outer.CastShadow = false
	outer.CFrame = CFrame.new(pos) * CFrame.Angles(math.rad(45), 0, math.rad(45))
	outer.Parent = core

	local inner = Instance.new("Part")
	inner.Name = "InnerEmber"
	inner.Shape = Enum.PartType.Ball
	inner.Size = Vector3.new(0.92, 0.92, 0.92)
	inner.Material = Enum.Material.Neon
	inner.Color = Color3.new(1, 1, 1)
	inner.Transparency = 0.05
	inner.Anchored = true
	inner.CanCollide = false
	inner.CanTouch = false
	inner.CanQuery = false
	inner.CastShadow = false
	inner.CFrame = CFrame.new(pos)
	inner.Parent = core

	core.WorldPivot = CFrame.new(pos)
	core.Parent = worldVisualFolder
	return core, outer, inner
end

local function spawnRevealShockwave(pos: Vector3, color: Color3, tier: number)
	if UIFeel.ReducedMotion() then
		return
	end
	local ring = Instance.new("Part")
	ring.Name = "ForgeRevealRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.12
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanTouch = false
	ring.CanQuery = false
	ring.CastShadow = false
	ring.Size = Vector3.new(0.14, 1.6, 1.6)
	ring.CFrame = CFrame.new(pos - Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = worldVisualFolder

	local endDiameter = if tier >= 6 then 6.4 elseif tier >= 4 then 5.2 else 4.0
	local tw = TweenService:Create(ring, TweenInfo.new(0.36, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.06, endDiameter, endDiameter),
		Transparency = 1,
		CFrame = CFrame.new(pos + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	})
	tw.Completed:Connect(function()
		ring:Destroy()
	end)
	tw:Play()
end

local function destroyRollCore(state: PedestalVisual)
	if state.RollCore then
		state.RollCore:Destroy()
		state.RollCore = nil
		state.RollOuterPart = nil
		state.RollInnerPart = nil
	end
end

local function destroyPendingWeapon(state: PedestalVisual)
	if state.PendingWeaponModel then
		state.PendingWeaponModel:Destroy()
		state.PendingWeaponModel = nil
	end
	state.PendingEmitters = {}
end

local function clearGradient(label: TextLabel)
	local existing = label:FindFirstChild("TierGradient")
	if existing then
		existing:Destroy()
	end
end

local function easeBackOut(t: number): number
	local c1 = 1.85
	local c3 = c1 + 1
	local u = t - 1
	return 1 + c3 * u * u * u + c1 * u * u
end

local function revealPedestalWeapon(state: PedestalVisual, playVfx: boolean)
	destroyRollCore(state)
	local model = state.PendingWeaponModel
	if not model then
		state.AnimPhase = "IDLE"
		return
	end
	state.PendingWeaponModel = nil

	if state.WeaponModel then
		state.WeaponModel:Destroy()
	end
	state.WeaponModel = model
	state.BaseScale = state.PendingBaseScale
	state.ModelHalfHeight = state.PendingHalfHeight
	state.EmitterList = state.PendingEmitters
	state.PendingEmitters = {}

	local pos = state.Anchor.WorldPosition
	state.Billboard.StudsOffsetWorldSpace = Vector3.new(0, state.ModelHalfHeight + 0.85, 0)

	if state.RuneRing then
		state.RuneRing.Color = state.TargetColor
	end
	if state.Light then
		state.Light.Color = state.TargetColor
		state.Light.Range = state.TargetLightRange
		state.Light.Brightness = if playVfx then state.TargetLightBrightness * 2.4 else state.TargetLightBrightness
		state.Light.Enabled = true
	end

	local reduced = UIFeel.ReducedMotion()
	if reduced or not playVfx then
		model:ScaleTo(state.BaseScale)
		model:PivotTo(CFrame.new(pos))
		model.Parent = worldVisualFolder
		state.AnimPhase = "IDLE"
	else
		model:ScaleTo(math.max(0.05, state.BaseScale * 0.08))
		model:PivotTo(CFrame.new(pos - Vector3.new(0, 1.35, 0)))
		model.Parent = worldVisualFolder
		state.AnimPhase = "REVEALING"
		state.RevealStart = os.clock()
	end

	local modalOpen = (_G :: any).IsAnyMasterModalOpen ~= nil and (_G :: any).IsAnyMasterModalOpen()
	state.Billboard.Enabled = not modalOpen
	state.TargetBeam.Color = ColorSequence.new(state.TargetColor)
	state.TargetBeam.Enabled = state.TargetMatched

	if playVfx and not reduced then
		state.BurstEmitter.Color = ColorSequence.new(Color3.new(1, 1, 1), state.TargetColor)
		state.BurstPart.Position = pos
		local burstCount = if state.TargetTier >= 6
			then 48
			elseif state.TargetTier >= 5 then 36
			elseif state.TargetTier >= 4 then 24
			else 16
		state.BurstEmitter:Emit(burstCount)
		spawnRevealShockwave(pos, state.TargetColor, state.TargetTier)
		if isOwnedByLocalPlayer(state.Plot) then
			if state.TargetTier >= 5 then
				UIFeel.Sfx("Success")
			else
				UIFeel.Sfx("Click")
			end
		end
	end
end

local function updatePedestalMetadata(state: PedestalVisual): (boolean, ArtifactCatalog.ArtifactSeed?, string)
	local pedestal = state.Pedestal
	local unlocked = pedestal:GetAttribute("Unlocked") == true
	setPedestalStoneVisible(pedestal, unlocked)

	local templateId = if unlocked and type(pedestal:GetAttribute("TemplateId")) == "string"
		then (pedestal:GetAttribute("TemplateId") :: string)
		else ""
	local seed = if templateId ~= "" then ArtifactCatalog.Seeds[templateId] else nil

	if not unlocked or not seed then
		destroyRollCore(state)
		destroyPendingWeapon(state)
		if state.WeaponModel then
			state.WeaponModel:Destroy()
			state.WeaponModel = nil
		end
		state.EmitterList = {}
		state.TemplateId = ""
		state.LoadingTemplateId = ""
		state.LoadToken += 1
		state.AnimPhase = "IDLE"
		state.Billboard.Enabled = false
		state.TargetBeam.Enabled = false
		if state.Light then
			state.Light.Enabled = false
		end
		if state.RuneRing then
			state.RuneRing.Color = BRONZE_DEFAULT
		end
		return false, nil, ""
	end

	local tier = math.clamp(math.floor(seed.RarityTier or 1), 1, 16)
	local rarityInfo = ArtifactCatalog.GetRarityInfo(tier)
	local theme = BillboardThemes.Hero(tier)
	local costAttr = pedestal:GetAttribute("Cost")
	local cost = if type(costAttr) == "number" and costAttr > 0 then costAttr else ArtifactCatalog.GetPedestalCost(seed)
	local power = ArtifactCatalog.CalculateEffectiveStats(1, tier, nil, seed.TemplateId)

	state.TargetTier = tier
	state.TargetColor = rarityInfo.Color
	state.TargetLightBrightness = if tier >= 6 then 2.2 elseif tier >= 4 then 1.5 else 0.9
	state.TargetLightRange = if tier >= 6 then 13 else 9
	state.TargetMatched = pedestal:GetAttribute("TargetMatched") == true

	clearGradient(state.RarityLabel)
	local rarityText = string.upper(rarityInfo.Name)
	if seed.IsHighStat then
		rarityText ..= " · ENHANCED"
	end
	state.RarityLabel.Text = rarityText
	BillboardThemes.PaintTitle(state.RarityLabel, theme)
	if tier < 5 then
		state.RarityLabel.TextColor3 = rarityInfo.Color:Lerp(Color3.new(1, 1, 1), 0.28)
	end

	state.NameLabel.Text = seed.DisplayName
	local owned = isOwnedByLocalPlayer(state.Plot)
	state.PriceLabel.Visible = owned
	if owned then
		state.PriceLabel.Text = string.format("%s Gold · %s PWR", StatBalance.Format(cost), StatBalance.Format(power))
	end

	return true, seed, templateId
end

local function applyTierHighlight(cloned: Model, tier: number, targetColor: Color3)
	if tier >= 5 then
		local hl = Instance.new("Highlight")
		hl.FillColor = targetColor
		hl.OutlineColor = targetColor:Lerp(Color3.new(1, 1, 1), 0.35)
		hl.FillTransparency = 0.88
		hl.OutlineTransparency = 0.15
		hl.Adornee = cloned
		hl.Parent = cloned
	end
end

local function queueWeaponClone(state: PedestalVisual, seed: ArtifactCatalog.ArtifactSeed, templateId: string, revealImmediately: boolean)
	destroyPendingWeapon(state)
	state.TemplateId = templateId
	state.LoadToken += 1
	local myToken = state.LoadToken
	local tier = state.TargetTier
	local targetColor = state.TargetColor

	-- Fast synchronous path: when the background warmup cache already holds this weapon, clone it
	-- instantly on frame 0 with zero yield, zero bounding-box recompute, and zero reveal hitch!
	local cached = preparedCache[seed.ModelAssetId]
	if cached then
		local cloned = cached.Template:Clone()
		applyTierHighlight(cloned, tier, targetColor)
		state.PendingWeaponModel = cloned
		state.PendingHalfHeight = cached.HalfHeight
		state.PendingBaseScale = cached.BaseScale
		state.PendingEmitters = collectEmitters(cloned)
		state.LoadingTemplateId = ""
		if revealImmediately and state.AnimPhase == "IDLE" then
			revealPedestalWeapon(state, false)
		elseif state.AnimPhase == "ROLLING" and os.clock() >= state.RollEndAt then
			revealPedestalWeapon(state, true)
		end
		return
	end

	-- Cold fallback (only if player rolls in the first moment after join before warmup finishes)
	state.LoadingTemplateId = templateId
	task.spawn(function()
		local entry = getOrBuildPreparedPrefab(seed.ModelAssetId, 5)
		if not entry then
			if state.LoadToken == myToken then
				state.LoadingTemplateId = ""
				if state.AnimPhase == "ROLLING" or state.AnimPhase == "QUEUED" then
					destroyRollCore(state)
					state.AnimPhase = "IDLE"
				end
			end
			return
		end
		pcall(function()
			ContentProvider:PreloadAsync({ entry.Template })
		end)
		if state.LoadToken ~= myToken or state.TemplateId ~= templateId or not state.Pedestal.Parent then
			return
		end
		local cloned = entry.Template:Clone()
		applyTierHighlight(cloned, tier, targetColor)
		state.PendingWeaponModel = cloned
		state.PendingHalfHeight = entry.HalfHeight
		state.PendingBaseScale = entry.BaseScale
		state.PendingEmitters = collectEmitters(cloned)
		state.LoadingTemplateId = ""

		if revealImmediately and state.AnimPhase == "IDLE" then
			revealPedestalWeapon(state, false)
		elseif state.AnimPhase == "ROLLING" and os.clock() >= state.RollEndAt then
			revealPedestalWeapon(state, true)
		end
	end)
end

local function refreshPedestalVisual(state: PedestalVisual)
	local ok, seed, templateId = updatePedestalMetadata(state)
	if not ok or not seed then
		return
	end

	local inRollSequence = state.AnimPhase == "QUEUED" or state.AnimPhase == "ROLLING"
	local alreadyLoaded = state.TemplateId == templateId and (state.WeaponModel ~= nil or state.PendingWeaponModel ~= nil)
	local alreadyLoading = state.LoadingTemplateId == templateId

	if inRollSequence then
		-- If TemplateId replicated slightly after RollBatchSeq, swap the pending clone without disrupting roll timing!
		if not alreadyLoaded and not alreadyLoading then
			queueWeaponClone(state, seed, templateId, false)
		end
		return
	end

	if alreadyLoaded or alreadyLoading then
		local modalOpen = (_G :: any).IsAnyMasterModalOpen ~= nil and (_G :: any).IsAnyMasterModalOpen()
		state.Billboard.Enabled = not modalOpen
		state.TargetBeam.Color = ColorSequence.new(state.TargetColor)
		state.TargetBeam.Enabled = state.TargetMatched
		return
	end

	queueWeaponClone(state, seed, templateId, true)
end

-- Starts a sequential 1-by-1 rolling animation across all unlocked pedestals of `forge`:
-- Pedestal 1 rolls -> reveals -> Pedestal 2 rolls -> reveals -> ... -> Pedestal N.
local function startSequentialForgeRoll(forge: Model)
	local slotDur = tonumber(forge:GetAttribute("RollSlotDuration")) or DEFAULT_SLOT_ROLL_SECONDS
	local totalDur = tonumber(forge:GetAttribute("RollTotalDuration"))
	local reduced = UIFeel.ReducedMotion()

	local list: { PedestalVisual } = {}
	for _, state in activePedestals do
		if state.Forge == forge and state.Pedestal:GetAttribute("Unlocked") == true then
			table.insert(list, state)
		end
	end
	table.sort(list, function(a, b)
		return a.SlotIndex < b.SlotIndex
	end)
	if #list == 0 then
		return
	end

	local now = os.clock()
	local effectiveSlotDur = if reduced then 0.06 else slotDur
	local batchDuration = totalDur or (#list * effectiveSlotDur + 0.30)

	local plot = getPlotAncestor(forge)
	if isOwnedByLocalPlayer(plot) then
		localRollEndAt = math.max(localRollEndAt, now + batchDuration)
		setLocalRollAnimating(true)
	end

	for orderIdx, state in ipairs(list) do
		-- Clear previous weapon & hide billboard immediately across all pedestals
		destroyRollCore(state)
		destroyPendingWeapon(state)
		if state.WeaponModel then
			state.WeaponModel:Destroy()
			state.WeaponModel = nil
		end
		state.EmitterList = {}
		state.Billboard.Enabled = false
		state.TargetBeam.Enabled = false
		if state.RuneRing then
			state.RuneRing.Color = BRONZE_DEFAULT
		end
		if state.Light then
			state.Light.Enabled = false
		end

		local ok, seed, templateId = updatePedestalMetadata(state)
		if ok and seed then
			state.AnimPhase = "QUEUED"
			state.RollStartAt = now + (orderIdx - 1) * effectiveSlotDur
			state.RollEndAt = state.RollStartAt + effectiveSlotDur
			state.LastCycleIdx = -1
			-- Force a fresh clone even if the exact same TemplateId rolled again
			queueWeaponClone(state, seed, templateId, false)
		else
			state.AnimPhase = "IDLE"
		end
	end
end

local function detachPedestal(pedestal: Model)
	local state = activePedestals[pedestal]
	if not state then
		return
	end
	activePedestals[pedestal] = nil
	for _, conn in state.Connections do
		conn:Disconnect()
	end
	destroyRollCore(state)
	destroyPendingWeapon(state)
	if state.WeaponModel then
		state.WeaponModel:Destroy()
	end
	state.BurstPart:Destroy()
	state.Billboard:Destroy()
end

local function attachPedestal(pedestal: Model)
	if activePedestals[pedestal] or pendingPedestals[pedestal] then
		return
	end
	pendingPedestals[pedestal] = true
	local root = pedestal:FindFirstChild("PedestalRoot") or pedestal:WaitForChild("PedestalRoot", 15)
	local anchor = if root then (root:FindFirstChild("DisplayAnchor") or root:WaitForChild("DisplayAnchor", 15)) else nil
	pendingPedestals[pedestal] = nil
	if activePedestals[pedestal] or not pedestal:IsDescendantOf(Workspace) then
		return
	end
	if not (root and root:IsA("BasePart") and anchor and anchor:IsA("Attachment")) then
		return
	end

	local runeRing = pedestal:FindFirstChild("RuneRing") :: BasePart?
	local burstPart = Instance.new("Part")
	burstPart.Name = "PedestalFx_" .. pedestal.Name
	burstPart.Size = Vector3.new(0.5, 0.5, 0.5)
	burstPart.Transparency = 1
	burstPart.Anchored = true
	burstPart.CanCollide = false
	burstPart.CanTouch = false
	burstPart.CanQuery = false
	burstPart.Position = anchor.WorldPosition
	burstPart.Parent = worldVisualFolder

	local light = Instance.new("PointLight")
	light.Enabled = false
	light.Shadows = false
	light.Parent = burstPart

	local burstEmitter = Instance.new("ParticleEmitter")
	burstEmitter.Texture = SPARK_TEXTURE
	burstEmitter.LightEmission = 1
	burstEmitter.Rate = 0
	burstEmitter.Lifetime = NumberRange.new(0.28, 0.58)
	burstEmitter.Speed = NumberRange.new(5, 14)
	burstEmitter.SpreadAngle = Vector2.new(180, 180)
	burstEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.44),
		NumberSequenceKeypoint.new(1, 0),
	})
	burstEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(1, 1),
	})
	burstEmitter.Parent = burstPart

	local beamAtt0 = Instance.new("Attachment")
	beamAtt0.Position = Vector3.new(0, -1.8, 0)
	beamAtt0.Parent = burstPart
	local beamAtt1 = Instance.new("Attachment")
	beamAtt1.Position = Vector3.new(0, 9.5, 0)
	beamAtt1.Parent = burstPart
	local targetBeam = Instance.new("Beam")
	targetBeam.Attachment0 = beamAtt0
	targetBeam.Attachment1 = beamAtt1
	targetBeam.FaceCamera = true
	targetBeam.LightEmission = 1
	targetBeam.LightInfluence = 0
	targetBeam.Width0 = 1.6
	targetBeam.Width1 = 0.2
	targetBeam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	targetBeam.Enabled = false
	targetBeam.Parent = burstPart

	-- World-space stud-sized BillboardGui (6.2 x 1.85 studs): constant physical size in 3D space!
	local billboard: BillboardGui = New("BillboardGui", {
		Name = "PedestalLabel_" .. pedestal.Name,
		Adornee = anchor,
		Size = UDim2.fromScale(6.2, 1.85),
		SizeOffset = Vector2.new(0, 0.5),
		StudsOffsetWorldSpace = Vector3.new(0, 2.35, 0),
		MaxDistance = LABEL_MAX_DISTANCE,
		AlwaysOnTop = false,
		LightInfluence = 0,
		ClipsDescendants = false,
		ResetOnSpawn = false,
		Enabled = false,
	}, billboardFolder)
	CollectionService:AddTag(billboard, "UnitNameplate")

	New("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0.02, 0),
	}, billboard)

	local function makeWorldLabel(name: string, order: number, heightScale: number, font: Font, color: Color3, maxSize: number): TextLabel
		local lbl = BillboardThemes.Text(billboard, font, "", maxSize, color)
		lbl.Name = name
		lbl.LayoutOrder = order
		lbl.AutomaticSize = Enum.AutomaticSize.None
		lbl.Size = UDim2.fromScale(1, heightScale)
		lbl.TextScaled = true
		lbl.TextWrapped = false
		lbl.TextTruncate = Enum.TextTruncate.AtEnd
		New("UITextSizeConstraint", { MaxTextSize = maxSize, MinTextSize = 8 }, lbl)
		return lbl
	end

	local rarityLabel = makeWorldLabel("Rarity", 1, 0.27, Tokens.Fonts.Number, Tokens.Text.Gold, 16)
	local nameLabel = makeWorldLabel("ArtifactName", 2, 0.42, Tokens.Fonts.Title, Tokens.Text.White, 22)
	local priceLabel = makeWorldLabel("Price", 3, 0.27, Tokens.Fonts.Number, Tokens.Text.Gold, 16)

	local plot = getPlotAncestor(pedestal)
	local forge = getForgeAncestor(pedestal)
	local slotIdx = math.clamp(tonumber(pedestal:GetAttribute("SlotIndex")) or 1, 1, 6)
	local state: PedestalVisual = {
		Pedestal = pedestal,
		Forge = forge,
		Plot = plot,
		SlotIndex = slotIdx,
		Anchor = anchor,
		RuneRing = runeRing,
		WeaponModel = nil,
		PendingWeaponModel = nil,
		PendingHalfHeight = 1.6,
		PendingBaseScale = 1,
		PendingEmitters = {},
		RollCore = nil,
		RollOuterPart = nil,
		RollInnerPart = nil,
		EmitterList = {},
		Light = light,
		BurstPart = burstPart,
		BurstEmitter = burstEmitter,
		TargetBeam = targetBeam,
		Billboard = billboard,
		RarityLabel = rarityLabel,
		NameLabel = nameLabel,
		PriceLabel = priceLabel,
		TemplateId = "",
		LoadingTemplateId = "",
		LoadToken = 0,
		BaseScale = 1,
		ModelHalfHeight = 1.6,
		TargetTier = 1,
		TargetColor = BRONZE_DEFAULT,
		TargetLightBrightness = 0.9,
		TargetLightRange = 9,
		TargetMatched = false,
		AnimPhase = "IDLE",
		RollStartAt = 0,
		RollEndAt = 0,
		RevealStart = 0,
		LastCycleIdx = -1,
		Phase = slotIdx * 0.95,
		Connections = {},
	}
	activePedestals[pedestal] = state

	for _, attr in ipairs({ "Unlocked", "TemplateId", "Cost", "TargetMatched" }) do
		table.insert(state.Connections, pedestal:GetAttributeChangedSignal(attr):Connect(function()
			refreshPedestalVisual(state)
		end))
	end
	if plot then
		table.insert(state.Connections, plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
			refreshPedestalVisual(state)
		end))
	end
	table.insert(state.Connections, pedestal.Destroying:Connect(function()
		detachPedestal(pedestal)
	end))
	table.insert(state.Connections, pedestal.AncestryChanged:Connect(function()
		if not pedestal:IsDescendantOf(Workspace) then
			detachPedestal(pedestal)
		end
	end))

	refreshPedestalVisual(state)
end

-- Watch each Open Forge building for Anvil strike sparks/audio AND RollBatchSeq sequential rolls
local watchedForges: { [Instance]: { RBXScriptConnection } } = {}
local function watchForgeBuilding(forge: Model)
	if watchedForges[forge] then
		return
	end
	local conns: { RBXScriptConnection } = {}
	watchedForges[forge] = conns

	table.insert(conns, forge:GetAttributeChangedSignal("AnvilStrikeSeq"):Connect(function()
		local anvilFace = forge:FindFirstChild("AnvilFace", true)
		if anvilFace and anvilFace:IsA("BasePart") then
			local burst = anvilFace:FindFirstChild("AnvilStrikeBurst")
			if burst and burst:IsA("ParticleEmitter") and not UIFeel.ReducedMotion() then
				burst:Emit(24)
			end
			pcall(function()
				AudioManager.Play3D("ForgeHammer", anvilFace.Position)
			end)
		end
	end))

	table.insert(conns, forge:GetAttributeChangedSignal("RollBatchSeq"):Connect(function()
		startSequentialForgeRoll(forge)
	end))

	table.insert(conns, forge.Destroying:Connect(function()
		local list = watchedForges[forge]
		watchedForges[forge] = nil
		if list then
			for _, c in list do
				c:Disconnect()
			end
		end
	end))
end

local function isPedestalModel(inst: Instance?): boolean
	return inst ~= nil
		and inst:IsA("Model")
		and inst.Parent ~= nil
		and inst.Parent.Name == "Pedestals"
		and string.sub(inst.Name, 1, 9) == "Pedestal_"
end

local function considerDescendant(inst: Instance)
	if inst:IsA("Model") then
		if inst.Name == "Building_Blacksmith" then
			watchForgeBuilding(inst)
		elseif isPedestalModel(inst) then
			task.spawn(attachPedestal, inst)
		end
	elseif inst.Name == "DisplayAnchor" and inst:IsA("Attachment") then
		local root = inst.Parent
		local ped = root and root.Parent
		if isPedestalModel(ped) then
			task.spawn(attachPedestal, ped :: Model)
		end
	end
end

task.spawn(function()
	local plots = Workspace:WaitForChild("WaitingRoomPlots")
	for _, desc in plots:GetDescendants() do
		considerDescendant(desc)
	end
	plots.DescendantAdded:Connect(considerDescendant)
end)

RunService.RenderStepped:Connect(function()
	debug.profilebegin("ForgePedestals")
	local now = os.clock()
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	local reduced = UIFeel.ReducedMotion()
	local modalOpen = (_G :: any).IsAnyMasterModalOpen ~= nil and (_G :: any).IsAnyMasterModalOpen()
	local anyLocalRolling = false

	for pedestal, state in activePedestals do
		if not pedestal.Parent then
			detachPedestal(pedestal)
			continue
		end
		local basePos = state.Anchor.WorldPosition
		state.BurstPart.Position = basePos
		local dist = (basePos - eye).Magnitude
		local owned = isOwnedByLocalPlayer(state.Plot)

		if state.AnimPhase == "QUEUED" then
			if owned then
				anyLocalRolling = true
			end
			state.Billboard.Enabled = false
			if now >= state.RollStartAt then
				-- This pedestal's turn! Spawn the rolling Forge Core right here.
				state.AnimPhase = "ROLLING"
				state.LastCycleIdx = -1
				if not reduced then
					destroyRollCore(state)
					local core, outer, inner = createRollCore(basePos)
					state.RollCore = core
					state.RollOuterPart = outer
					state.RollInnerPart = inner
					if state.Light then
						state.Light.Enabled = true
						state.Light.Range = 10
						state.Light.Brightness = 1.8
					end
				end
			end
			continue
		end

		if state.AnimPhase == "ROLLING" then
			if owned then
				anyLocalRolling = true
			end
			state.Billboard.Enabled = false
			if now >= state.RollEndAt and (state.PendingWeaponModel ~= nil or now >= state.RollEndAt + 1.5) then
				revealPedestalWeapon(state, true)
			elseif state.RollCore and state.RollOuterPart and state.RollInnerPart and dist <= MAX_RENDER_DISTANCE then
				local elapsed = math.max(0, now - state.RollStartAt)
				local cycleIdx = math.floor(elapsed / CYCLE_STEP_SEC)
				local color = ROLL_CYCLE_COLORS[(cycleIdx + state.SlotIndex) % #ROLL_CYCLE_COLORS + 1]
				if cycleIdx ~= state.LastCycleIdx then
					state.LastCycleIdx = cycleIdx
					state.RollOuterPart.Color = color
					if state.RuneRing then
						state.RuneRing.Color = color
					end
					if state.Light then
						state.Light.Color = color
					end
					if dist <= VFX_CULL_DISTANCE then
						state.BurstEmitter.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
						state.BurstEmitter:Emit(3)
					end
				end
				local pulse = 1 + 0.18 * math.sin(elapsed * 28)
				local hop = math.abs(math.sin(elapsed * 12)) * 0.48 - 0.15
				local pos = basePos + Vector3.new(0, hop, 0)
				state.RollOuterPart.Size = Vector3.new(1.55, 1.55, 1.55) * pulse
				state.RollOuterPart.CFrame = CFrame.new(pos) * CFrame.Angles(elapsed * 8.0, elapsed * 14.5, elapsed * 5.5)
				state.RollInnerPart.CFrame = CFrame.new(pos) * CFrame.Angles(-elapsed * 9.5, elapsed * 11.5, 0)
			end
			continue
		end

		if state.TemplateId ~= "" then
			state.Billboard.Enabled = not modalOpen
		end

		local model = state.WeaponModel
		if not model then
			continue
		end
		if dist > MAX_RENDER_DISTANCE then
			continue
		end

		local t = now + state.Phase
		if state.AnimPhase == "REVEALING" then
			if owned then
				anyLocalRolling = true
			end
			local u = math.clamp((now - state.RevealStart) / REVEAL_DURATION, 0, 1)
			local easedScale = math.max(0.05, 0.08 + 0.92 * easeBackOut(u))
			local oneMinusU = 1 - u
			local riseOffset = -1.35 * oneMinusU * oneMinusU * oneMinusU
			local extraSpin = (2.2 * math.pi) * oneMinusU * oneMinusU
			local bob = if reduced then 0 else math.sin(t * BOB_SPEED) * BOB_HEIGHT * u
			local spin = (if reduced then 0.4 else (t * SPIN_SPEED)) + extraSpin

			model:ScaleTo(state.BaseScale * easedScale)
			model:PivotTo(CFrame.new(basePos + Vector3.new(0, riseOffset + bob, 0)) * CFrame.Angles(0, spin, 0))
			if state.Light then
				state.Light.Brightness = state.TargetLightBrightness * (1 + 1.4 * oneMinusU * oneMinusU)
			end
			if u >= 1 then
				model:ScaleTo(state.BaseScale)
				if state.Light then
					state.Light.Brightness = state.TargetLightBrightness
				end
				state.AnimPhase = "IDLE"
			end
		else
			local bob = if reduced then 0 else math.sin(t * BOB_SPEED) * BOB_HEIGHT
			local spin = if reduced then 0.4 else (t * SPIN_SPEED) % (math.pi * 2)
			model:PivotTo(CFrame.new(basePos + Vector3.new(0, bob, 0)) * CFrame.Angles(0, spin, 0))
		end

		local showVfx = dist <= VFX_CULL_DISTANCE and not reduced
		for _, emit in state.EmitterList do
			if emit.Parent then
				emit.Enabled = showVfx
			end
		end
	end

	setLocalRollAnimating(anyLocalRolling or now < localRollEndAt)
	debug.profileend()
end)
