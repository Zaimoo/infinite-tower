--!strict
-- ReplicatedStorage/Shared/Util/RunicWeaponVfx.luau
-- Authoritative VFX, Trail & Procedural Animation Controller for Runic Longsword (and Runic Vanguard Swords)
--
-- Features:
--   - Standardized Attachment creation (Grip, TrailBottom, TrailTop, VFXCore)
--   - High-luminosity Swing Trail with Cyan -> Ice Blue -> Sapphire gradient
--   - Ambient Arcane ParticleEmitter & PointLight on VFXCore
--   - Lightweight RenderStepped procedural animation:
--       * Pulsing Neon transparency / emission
--       * Slow orbital rotation of secondary AuraMesh (10-15 deg/sec)
--   - Dynamic scaling based on 7-Star Promotion and 16-Tier Blacksmith Rarity Palette

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArtifactCatalog = require(Shared:WaitForChild("Config"):WaitForChild("ArtifactCatalog")) :: any

local RunicWeaponVfx = {}

export type RunicVfxHandle = {
	Model: Model,
	Trail: Trail,
	Emitter: ParticleEmitter,
	Light: PointLight,
	Disconnect: () -> (),
}

-- Standardized Attachment Offsets (Roblox Studs, Gripped at 0, 0, 0)
local SOCKET_OFFSETS = {
	Grip = Vector3.new(0, 0, 0),
	TrailBottom = Vector3.new(0, 0.75, 0),
	TrailTop = Vector3.new(0, 4.10, 0),
	VFXCore = Vector3.new(0, 2.40, 0),
}

local EDGE_PLUS_X = Vector3.new(0, -90, 0)

-- Default Ice/Arcane Cyan Colors
local DEFAULT_CYAN = Color3.fromRGB(0, 229, 255)
local DEFAULT_ICE_BLUE = Color3.fromRGB(56, 189, 248)
local DEFAULT_SAPPHIRE = Color3.fromRGB(30, 64, 175)

local function getOrCreateAttachment(parent: BasePart, name: string, pos: Vector3, rotDeg: Vector3?): Attachment
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Attachment") then
		return existing
	end
	local att = Instance.new("Attachment")
	att.Name = name
	local cf = CFrame.new(pos)
	if rotDeg then
		cf = cf * CFrame.Angles(math.rad(rotDeg.X), math.rad(rotDeg.Y), math.rad(rotDeg.Z))
	end
	att.CFrame = cf
	att.Parent = parent
	return att
end

-- ============================================================================
-- 1. BUILD / CONFIGURE WEAPON SWING TRAIL
-- ============================================================================
function RunicWeaponVfx.SetupTrail(handle: BasePart, trailBottom: Attachment, trailTop: Attachment, primaryColor: Color3?): Trail
	local existing = handle:FindFirstChild("SwingTrail")
	if existing and existing:IsA("Trail") then
		return existing
	end

	local c1 = primaryColor or DEFAULT_CYAN
	local c2 = DEFAULT_ICE_BLUE
	local c3 = DEFAULT_SAPPHIRE

	local trail = Instance.new("Trail")
	trail.Name = "SwingTrail"
	trail.Attachment0 = trailBottom
	trail.Attachment1 = trailTop
	trail.FaceCamera = true
	trail.Lifetime = 0.35
	trail.LightEmission = 1.0
	trail.LightInfluence = 0.0

	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, c1),
		ColorSequenceKeypoint.new(0.5, c2),
		ColorSequenceKeypoint.new(1.0, c3),
	})

	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 0.15),
		NumberSequenceKeypoint.new(0.7, 0.40),
		NumberSequenceKeypoint.new(1.0, 1.00),
	})

	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 1.0),
		NumberSequenceKeypoint.new(0.8, 0.75),
		NumberSequenceKeypoint.new(1.0, 0.0),
	})

	trail.Enabled = false -- Enabled dynamically during melee slash animation windows
	trail.Parent = handle
	return trail
end

-- ============================================================================
-- 2. BUILD / CONFIGURE VFXCORE PARTICLES & POINTLIGHT
-- ============================================================================
function RunicWeaponVfx.SetupAura(vfxCore: Attachment, starRating: number?, rarityIndex: number?): (ParticleEmitter, PointLight)
	local star = math.clamp(math.floor(starRating or 2), 1, 7)
	local rarityInfo = rarityIndex and ArtifactCatalog.GetRarityInfo(rarityIndex)
	local coreColor = (rarityInfo and rarityIndex >= 14) and rarityInfo.Color or DEFAULT_CYAN

	-- Particle Emitter
	local emitter = vfxCore:FindFirstChild("RunicAuraEmitter") :: ParticleEmitter?
	if not emitter then
		emitter = Instance.new("ParticleEmitter")
		emitter.Name = "RunicAuraEmitter"
		emitter.Parent = vfxCore
	end

	local rateScale = 1 + (star - 1) * 0.35
	emitter.Rate = math.round(12 * rateScale)
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Speed = NumberRange.new(0.4, 1.2)
	emitter.Drag = 2.0
	emitter.SpreadAngle = Vector2.new(35, 35)
	emitter.EmissionDirection = Enum.NormalId.Top

	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, coreColor),
		ColorSequenceKeypoint.new(0.6, DEFAULT_ICE_BLUE),
		ColorSequenceKeypoint.new(1.0, DEFAULT_SAPPHIRE),
	})

	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 1.0),
		NumberSequenceKeypoint.new(0.2, 0.15),
		NumberSequenceKeypoint.new(0.8, 0.35),
		NumberSequenceKeypoint.new(1.0, 1.0),
	})

	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 0.20 * rateScale),
		NumberSequenceKeypoint.new(0.5, 0.40 * rateScale),
		NumberSequenceKeypoint.new(1.0, 0.05),
	})

	emitter.LightEmission = 1.0
	emitter.LightInfluence = 0.0

	-- PointLight
	local light = vfxCore:FindFirstChild("RunicGlow") :: PointLight?
	if not light then
		light = Instance.new("PointLight")
		light.Name = "RunicGlow"
		light.Parent = vfxCore
	end

	light.Color = coreColor
	light.Range = 7.0 + (star * 1.0)
	light.Brightness = 1.2 + (star * 0.3)
	light.Shadows = false

	return emitter, light
end

-- ============================================================================
-- 3. PROCEDURAL ANIMATION RUNTIME (RENDERSTEPPED HOOK)
-- ============================================================================
function RunicWeaponVfx.AttachVfx(weaponModel: Model, starRating: number?, rarityIndex: number?): RunicVfxHandle
	local handle = weaponModel.PrimaryPart or weaponModel:FindFirstChild("Handle") :: BasePart?
	assert(handle, `[RunicWeaponVfx] Model '{weaponModel.Name}' must have a Handle BasePart!`)

	-- Standardized Attachments
	getOrCreateAttachment(handle, "Grip", SOCKET_OFFSETS.Grip, EDGE_PLUS_X)
	local trailBottom = getOrCreateAttachment(handle, "TrailBottom", SOCKET_OFFSETS.TrailBottom)
	local trailTop = getOrCreateAttachment(handle, "TrailTop", SOCKET_OFFSETS.TrailTop)
	local vfxCore = getOrCreateAttachment(handle, "VFXCore", SOCKET_OFFSETS.VFXCore)

	local rarityInfo = rarityIndex and ArtifactCatalog.GetRarityInfo(rarityIndex)
	local primaryColor = (rarityInfo and rarityIndex >= 14) and rarityInfo.Color or DEFAULT_CYAN

	local trail = RunicWeaponVfx.SetupTrail(handle, trailBottom, trailTop, primaryColor)
	local emitter, light = RunicWeaponVfx.SetupAura(vfxCore, starRating, rarityIndex)

	-- Locate Neon Rune channels and optional secondary AuraMesh
	local neonParts: { BasePart } = {}
	local auraMesh: BasePart? = nil

	for _, p in ipairs(weaponModel:GetDescendants()) do
		if p:IsA("BasePart") then
			if p.Name:find("AuraMesh") then
				auraMesh = p
			elseif p.Material == Enum.Material.Neon or p.Name:find("Rune") or p.Name:find("Gem") then
				table.insert(neonParts, p)
			end
		end
	end

	-- Procedural Animation: Pulsing Neon transparency + AuraMesh orbital rotation
	local connection: RBXScriptConnection? = nil
	local elapsed = 0

	if RunService:IsClient() then
		connection = RunService.RenderStepped:Connect(function(dt: number)
			if not weaponModel.Parent then
				if connection then connection:Disconnect() end
				return
			end
			elapsed += dt

			-- 1. Pulse Neon transparency between 0.0 and 0.25 (1.5 Hz breathing cycle)
			local pulse = (math.sin(elapsed * math.pi * 3.0) + 1) * 0.5
			local alpha = 0.05 + pulse * 0.20
			for _, p in ipairs(neonParts) do
				p.Transparency = alpha
			end

			-- 2. Orbital rotation of secondary AuraMesh (15 deg/sec counter-twist)
			if auraMesh and auraMesh:IsDescendantOf(weaponModel) then
				local rotY = math.rad(15 * dt)
				auraMesh.CFrame = auraMesh.CFrame * CFrame.Angles(0, rotY, 0)
			end
		end)
	end

	local function disconnect()
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end

	weaponModel.Destroying:Connect(disconnect)

	return {
		Model = weaponModel,
		Trail = trail,
		Emitter = emitter,
		Light = light,
		Disconnect = disconnect,
	}
end

return table.freeze(RunicWeaponVfx)
