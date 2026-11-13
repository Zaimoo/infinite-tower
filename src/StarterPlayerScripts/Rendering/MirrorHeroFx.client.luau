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
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local TAG = "MirrorHero"
local GOLD = Color3.fromRGB(255, 214, 120)
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

local function watch(model: Instance)
	if not model:IsA("Model") then return end
	model:GetAttributeChangedSignal("HeroDown"):Connect(function()
		if model:GetAttribute("HeroDown") == true then shatter(model :: Model) end
	end)
	task.spawn(function()
		-- Let the squad's other models spawn before looking for the source.
		task.wait(0.4)
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
