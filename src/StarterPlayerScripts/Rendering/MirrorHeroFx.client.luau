--!strict
-- StarterPlayerScripts/Rendering/MirrorHeroFx.client.luau
-- World effects for the Gilded Mirror heroes (docs/gilded-mirror-plan.md §6.1). EntityRenderer tags each mirror
-- hero's model "MirrorHero" and stamps HeroUUID, OwnerUserId and MirrorSourceUUID on every hero model.
--   * Reflection thread: when a mirror hero appears, and every so often after, a thin gold beam links it to the
--     hero it copies (same owner, HeroUUID == MirrorSourceUUID) and fades out. A light effect: kept under Reduce Motion.
--   * Glint: every few seconds a small burst of gold sparkles off the hero. Skipped under Reduce Motion.
--   * Shatter: when the hero is knocked out (EntityRenderer sets HeroDown), its glass bursts into shards.
-- Client-only decoration; nothing here touches gameplay.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local HeroAnimator = require(ReplicatedStorage:WaitForChild("Assets"):WaitForChild("HeroRig"):WaitForChild("HeroAnimator"))

local LocalPlayer = Players.LocalPlayer
local TAG = "MirrorHero"
local GOLD = Color3.fromRGB(255, 214, 120)
local FRENZY_ROSE = Color3.fromRGB(255, 76, 148)
local HALO_BLUE = Color3.fromRGB(150, 200, 255)
local HALO_CORE = Color3.fromRGB(230, 245, 255)
local HALO_SHARDS = { "HaloShardTop", "HaloShardL", "HaloShardR" }
local THREAD_SECONDS = 1.2
local THREAD_EVERY = 14
local GLINT_EVERY = { 6, 10 }

local function reducedMotion(): boolean
	return LocalPlayer:GetAttribute("Settings_ReduceMotion") == true
end

local function rootOf(model: Instance): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- The rendered model of the hero this mirror hero copies, if it is out right now.
local function sourceModel(model: Model): Model?
	local sourceUUID = model:GetAttribute("MirrorSourceUUID")
	local owner = model:GetAttribute("OwnerUserId")
	if type(sourceUUID) ~= "string" or sourceUUID == "" or not model.Parent then return nil end
	for _, other in model.Parent:GetChildren() do
		if other ~= model and other:IsA("Model") and other:GetAttribute("HeroUUID") == sourceUUID and other:GetAttribute("OwnerUserId") == owner then
			return other
		end
	end
	return nil
end

local function attachmentOn(part: BasePart, name: string, offset: Vector3): Attachment
	local existing = part:FindFirstChild(name)
	if existing and existing:IsA("Attachment") then return existing end
	local att = Instance.new("Attachment")
	att.Name = name
	att.Position = offset
	att.Parent = part
	return att
end

local function playThread(model: Model)
	local source = sourceModel(model)
	local fromRoot, toRoot = rootOf(model), source and rootOf(source)
	if not fromRoot or not toRoot then return end
	local beam = Instance.new("Beam")
	beam.Name = "MirrorThread"
	beam.Attachment0 = attachmentOn(fromRoot, "MirrorThreadA", Vector3.new(0, 1.5, 0))
	beam.Attachment1 = attachmentOn(toRoot, "MirrorThreadB", Vector3.new(0, 1.5, 0))
	beam.Color = ColorSequence.new(GOLD, Color3.new(1, 1, 1))
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Width0, beam.Width1 = 0.18, 0.08
	beam.CurveSize0, beam.CurveSize1 = 1.5, -1.5
	beam.Segments = 16
	beam.Transparency = NumberSequence.new(1)
	beam.Parent = fromRoot
	-- Fade in, hold, fade out: a NumberValue drives the beam's transparency.
	local fade = Instance.new("NumberValue")
	fade.Value = 1
	fade.Changed:Connect(function(v) beam.Transparency = NumberSequence.new(v) end)
	TweenService:Create(fade, TweenInfo.new(THREAD_SECONDS * 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true, 0), { Value = 0.15 }):Play()
	task.delay(THREAD_SECONDS, function()
		beam:Destroy()
		fade:Destroy()
	end)
end

local function glint(model: Model)
	local root = rootOf(model)
	if not root or reducedMotion() then return end
	local att = attachmentOn(root, "MirrorGlint", Vector3.new(0, 2, 0))
	local emitter = att:FindFirstChild("Sparkle") :: ParticleEmitter?
	if not emitter then
		local e = Instance.new("ParticleEmitter")
		e.Name = "Sparkle"
		e.Color = ColorSequence.new(GOLD, Color3.new(1, 1, 1))
		e.LightEmission = 1
		e.Rate = 0
		e.Lifetime = NumberRange.new(0.35, 0.6)
		e.Speed = NumberRange.new(3, 6)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		e.Rotation = NumberRange.new(0, 360)
		e.Parent = att
		emitter = e
	end
	(emitter :: ParticleEmitter):Emit(10)
end

-- Glass and gilt shards burst outward and fall when a mirror hero goes down.
local function shatter(model: Model)
	local root = rootOf(model)
	if not root then return end
	local att = attachmentOn(root, "MirrorShatter", Vector3.new(0, 2, 0))
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 225, 255)), ColorSequenceKeypoint.new(1, GOLD) })
	e.LightEmission = 0.6
	e.Rate = 0
	e.Lifetime = NumberRange.new(0.6, 1.0)
	e.Speed = NumberRange.new(8, 16)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -40, 0)
	e.RotSpeed = NumberRange.new(-360, 360)
	e.Rotation = NumberRange.new(0, 360)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.1) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = att
	e:Emit(if reducedMotion() then 10 else 28)
	task.delay(1.2, function() e:Destroy() end)
end

-- Seraphine's halo: an ice-blue ring of light wrapping through the three glowing crystal shards,
-- plus soft light and drifting starlight motes on each shard. EntityRenderer sets HaloHidden on a
-- shard when it launches off her head (Basic / Special), dimming its glow until it reforms.
local function weldLocalPos(head: BasePart, shard: BasePart): Vector3
	local weld = shard:FindFirstChild("CostumeWeld")
	if weld and weld:IsA("Weld") and weld.Part0 == head then
		return (weld.C0 * weld.C1:Inverse()).Position
	end
	return head.CFrame:PointToObjectSpace(shard.Position)
end

local function attachHaloFx(model: Model)
	if model:GetAttribute("HaloFxAttached") then return end
	local head = model:FindFirstChild("Head", true)
	local sTop = model:FindFirstChild("HaloShardTop", true)
	local sL = model:FindFirstChild("HaloShardL", true)
	local sR = model:FindFirstChild("HaloShardR", true)
	if not (head and head:IsA("BasePart") and sTop and sTop:IsA("BasePart") and sL and sL:IsA("BasePart") and sR and sR:IsA("BasePart")) then
		return
	end
	model:SetAttribute("HaloFxAttached", true)

	local pTop = weldLocalPos(head, sTop)
	local pL = weldLocalPos(head, sL)
	local pR = weldLocalPos(head, sR)
	local spec = HeroAnimator.HaloRingSpec(pTop, pL, pR)

	local attL = attachmentOn(head, "HaloRingL", spec.Center - Vector3.xAxis * spec.Rx)
	attL.CFrame = CFrame.fromMatrix(attL.Position, spec.Axis, spec.Normal, spec.Axis:Cross(spec.Normal))
	local attR = attachmentOn(head, "HaloRingR", spec.Center + Vector3.xAxis * spec.Rx)
	attR.CFrame = CFrame.fromMatrix(attR.Position, -spec.Axis, spec.Normal, (-spec.Axis):Cross(spec.Normal))

	local curve = spec.Ry * 4 / 3
	local beams: { Beam } = {}
	for i, c in { curve, -curve } do
		local name = if i == 1 then "HaloRingUpper" else "HaloRingLower"
		local existing = head:FindFirstChild(name)
		if existing and existing:IsA("Beam") then
			table.insert(beams, existing)
			continue
		end
		local b = Instance.new("Beam")
		b.Name = name
		b.Attachment0 = attL
		b.Attachment1 = attR
		b.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, HALO_BLUE),
			ColorSequenceKeypoint.new(0.5, HALO_CORE),
			ColorSequenceKeypoint.new(1, HALO_BLUE),
		})
		b.LightEmission = 1
		b.LightInfluence = 0
		b.FaceCamera = true
		b.Width0, b.Width1 = 0.06, 0.06
		b.Segments = 28
		b.CurveSize0, b.CurveSize1 = c, c
		b.Transparency = NumberSequence.new(0.2)
		b.Parent = head
		table.insert(beams, b)
	end

	local shardFx: { { Shard: BasePart, Light: PointLight, Motes: ParticleEmitter } } = {}
	for _, shardName in HALO_SHARDS do
		local shard = model:FindFirstChild(shardName, true)
		if not (shard and shard:IsA("BasePart")) then continue end
		local light = Instance.new("PointLight")
		light.Name = "HaloGlow"
		light.Color = HALO_BLUE
		light.Range = if shardName == "HaloShardTop" then 5.5 else 4.5
		light.Brightness = 1.0
		light.Shadows = false
		light.Parent = shard

		local att = attachmentOn(shard, "HaloMoteOrigin", Vector3.zero)
		local motes = Instance.new("ParticleEmitter")
		motes.Name = "HaloMotes"
		motes.Color = ColorSequence.new(HALO_CORE, HALO_BLUE)
		motes.LightEmission = 1
		motes.Rate = 3
		motes.Lifetime = NumberRange.new(0.6, 1.1)
		motes.Speed = NumberRange.new(0.3, 0.9)
		motes.SpreadAngle = Vector2.new(180, 180)
		motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.14), NumberSequenceKeypoint.new(1, 0) })
		motes.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		motes.Rotation = NumberRange.new(0, 360)
		motes.Enabled = not reducedMotion()
		motes.Parent = att
		table.insert(shardFx, { Shard = shard, Light = light, Motes = motes })
	end

	local function refresh()
		local allHidden = true
		local rm = reducedMotion()
		for _, fx in shardFx do
			local hidden = fx.Shard:GetAttribute("HaloHidden") == true
			fx.Light.Enabled = not hidden
			fx.Motes.Enabled = (not hidden) and (not rm)
			if not hidden then allHidden = false end
		end
		for _, b in beams do
			b.Enabled = not allHidden
		end
	end

	for _, fx in shardFx do
		fx.Shard:GetAttributeChangedSignal("HaloHidden"):Connect(function()
			local hidden = fx.Shard:GetAttribute("HaloHidden") == true
			if hidden and not reducedMotion() then
				fx.Motes:Emit(5)
			end
			refresh()
		end)
	end
	refresh()
end

-- Rook's Gilded Frenzy aura: 4 seconds of hot-rose lightning sparks & glow on his greataxe.
local function watchFrenzyAura(model: Model)
	local function hostPart(): BasePart?
		local weapon = model:FindFirstChild("EquippedWeapon", true)
		if weapon and weapon:IsA("Model") and weapon.PrimaryPart then
			return weapon.PrimaryPart
		end
		local hand = model:FindFirstChild("RightHand", true)
		return if hand and hand:IsA("BasePart") then hand else rootOf(model)
	end
	local function setAura(active: boolean, burst: boolean)
		local host = hostPart()
		if not host then return end
		local att = attachmentOn(host, "FrenzyAuraOrigin", Vector3.new(0, 0.8, 0))
		local emitter = att:FindFirstChild("FrenzySparks") :: ParticleEmitter?
		local light = host:FindFirstChild("FrenzyLight") :: PointLight?
		if active then
			if not emitter then
				local e = Instance.new("ParticleEmitter")
				e.Name = "FrenzySparks"
				e.Color = ColorSequence.new(FRENZY_ROSE, GOLD)
				e.LightEmission = 1
				e.Rate = 18
				e.Lifetime = NumberRange.new(0.25, 0.45)
				e.Speed = NumberRange.new(2, 5)
				e.SpreadAngle = Vector2.new(180, 180)
				e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.24), NumberSequenceKeypoint.new(1, 0) })
				e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
				e.Rotation = NumberRange.new(0, 360)
				e.Parent = att
				emitter = e
			end
			if not light then
				local l = Instance.new("PointLight")
				l.Name = "FrenzyLight"
				l.Color = FRENZY_ROSE
				l.Range = 7
				l.Brightness = 1.6
				l.Shadows = false
				l.Parent = host
				light = l
			end
			if emitter then
				emitter.Enabled = not reducedMotion()
				if burst and not reducedMotion() then emitter:Emit(12) end
			end
			if light then light.Enabled = true end
		else
			if emitter then emitter.Enabled = false end
			if light then light.Enabled = false end
		end
	end

	model:GetAttributeChangedSignal("FrenzyUntil"):Connect(function()
		local untilTime = model:GetAttribute("FrenzyUntil")
		if type(untilTime) ~= "number" or untilTime <= os.clock() or model:GetAttribute("HeroDown") == true then
			setAura(false, false)
			return
		end
		setAura(true, true)
		task.delay(math.max(0.05, untilTime - os.clock()), function()
			if not model.Parent then return end
			local cur = model:GetAttribute("FrenzyUntil")
			if type(cur) ~= "number" or cur <= os.clock() + 0.02 or model:GetAttribute("HeroDown") == true then
				setAura(false, false)
			end
		end)
	end)
end

local function watch(model: Instance)
	if not model:IsA("Model") then return end
	local typed = model :: Model
	attachHaloFx(typed)
	watchFrenzyAura(typed)
	local conn: RBXScriptConnection? = nil
	if not typed:GetAttribute("HaloFxAttached") then
		conn = typed.DescendantAdded:Connect(function()
			if typed:GetAttribute("HaloFxAttached") then
				if conn then conn:Disconnect() end
				return
			end
			attachHaloFx(typed)
			if typed:GetAttribute("HaloFxAttached") and conn then
				conn:Disconnect()
			end
		end)
	end
	model:GetAttributeChangedSignal("HeroDown"):Connect(function()
		if model:GetAttribute("HeroDown") == true then
			model:SetAttribute("FrenzyUntil", nil)
			shatter(typed)
		end
	end)
	task.spawn(function()
		-- Let the squad's other models spawn before looking for the source.
		task.wait(0.4)
		attachHaloFx(typed)
		if conn and typed:GetAttribute("HaloFxAttached") then conn:Disconnect() end
		local nextThread, nextGlint = 0, os.clock() + math.random(GLINT_EVERY[1], GLINT_EVERY[2])
		while model.Parent and CollectionService:HasTag(model, TAG) do
			local now = os.clock()
			if now >= nextThread then
				playThread(model)
				nextThread = now + THREAD_EVERY
			end
			if now >= nextGlint then
				glint(model)
				nextGlint = now + math.random(GLINT_EVERY[1], GLINT_EVERY[2])
			end
			task.wait(0.5)
		end
	end)
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(watch)
for _, model in CollectionService:GetTagged(TAG) do watch(model) end
