--!strict
-- ReplicatedStorage/Assets/CombatVfx/WeaponVfx.luau
-- Authoritative Client-side Weapon VFX Engine (Auras, Trails, Lights, and Hit Accents).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponVfxConfig = require(Shared:WaitForChild("Config"):WaitForChild("WeaponVfxConfig")) :: any

local WeaponVfx = {}

local VFX_TAG = "WeaponVfxInstance"
local SWING_TRAIL_NAME = "VfxSwingTrail"
local GILD_TRAIL_NAME = "VfxGildFiligreeTrail"
local GLINT_EMITTER_NAME = "VfxGlint"
local GILD_GLINT_NAME = "VfxGildGlintSweep"
local MOTES_EMITTER_NAME = "VfxMotes"
local AURA_EMITTER_NAME = "VfxAura"
local GLOW_LIGHT_NAME = "VfxGlowLight"

local function clearVfxInstances(container: Instance)
	for _, child in ipairs(container:GetDescendants()) do
		if child:GetAttribute(VFX_TAG) == true or child.Name:sub(1, 4) == "Vfx_" or child.Name == SWING_TRAIL_NAME or child.Name == GILD_TRAIL_NAME then
			child:Destroy()
		end
	end
end

local function getOrCreateAttachment(part: BasePart, name: string, defaultPos: Vector3?): Attachment
	local existing = part:FindFirstChild(name)
	if existing and existing:IsA("Attachment") then
		return existing
	end
	local att = Instance.new("Attachment")
	att.Name = name
	if defaultPos then
		att.Position = defaultPos
	end
	att.Parent = part
	return att
end

-- Applies data-driven VFX onto a weapon model according to rarity tier and element profile.
function WeaponVfx.Apply(model: Model, weaponType: string?, rarityIndex: number?, artifactId: string?)
	local primary = model.PrimaryPart
	if not primary then
		return
	end

	clearVfxInstances(model)

	local profile = WeaponVfxConfig.GetProfile(artifactId, rarityIndex)
	local band = profile.Band
	model:SetAttribute("WeaponVfxBand", band)

	-- 1. Ensure required VFX socket attachments exist on PrimaryPart if not already placed
	local vfxTip = getOrCreateAttachment(primary, "VfxTip", Vector3.new(0, 1.8, 0))
	local vfxBase = getOrCreateAttachment(primary, "VfxBase", Vector3.new(0, -1.8, 0))
	local vfxCore = getOrCreateAttachment(primary, "VfxCore", Vector3.new(0, 0, 0))

	if weaponType == "BOW" or primary:FindFirstChild("Nock") then
		getOrCreateAttachment(primary, "VfxNock", Vector3.new(0.2, 0.1, 0.42))
	end

	-- Dual-Wield Twin-Blade VFX Mirror (Striker Daggers) - mirrored early so all bands including Common offhands receive VFX
	local leftDagger = model:FindFirstChild("LeftDagger")
	if leftDagger and leftDagger:IsA("Model") and leftDagger.PrimaryPart and weaponType ~= "DAGGERS_OFFHAND" then
		WeaponVfx.Apply(leftDagger, "DAGGERS_OFFHAND", rarityIndex, artifactId)
	end

	-- Band 0: Common - Clean idle (no ambient emitters or lights), but responsive swing trail on attack
	if band == 0 then
		local trail = Instance.new("Trail")
		trail.Name = SWING_TRAIL_NAME
		trail:SetAttribute(VFX_TAG, true)
		trail.Attachment0 = vfxBase
		trail.Attachment1 = vfxTip
		trail.FaceCamera = true
		trail.Lifetime = 0.18
		trail.LightEmission = 0.70
		trail.LightInfluence = 0.30
		trail.Color = ColorSequence.new(Color3.fromRGB(220, 220, 225))
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 0.35),
			NumberSequenceKeypoint.new(0.7, 0.65),
			NumberSequenceKeypoint.new(1.0, 1.0),
		})
		trail.WidthScale = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 1.0),
			NumberSequenceKeypoint.new(0.8, 0.5),
			NumberSequenceKeypoint.new(1.0, 0.0),
		})
		trail.Enabled = false
		trail.Parent = primary
		return
	end

	local colorSeq = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, profile.Color),
		ColorSequenceKeypoint.new(0.7, profile.Accent),
		ColorSequenceKeypoint.new(1.0, profile.Color),
	})

	-- Band 1+: Sparkle Glint on tips/head + Weapon Edge Trail
	if band >= 1 then
		local glintUpper = Instance.new("ParticleEmitter")
		glintUpper.Name = GLINT_EMITTER_NAME .. "_Upper"
		glintUpper:SetAttribute(VFX_TAG, true)
		glintUpper.Rate = math.clamp(profile.MoteRate * 0.4, 1, 3)
		glintUpper.Lifetime = NumberRange.new(0.5, 1.0)
		glintUpper.Speed = NumberRange.new(0.15, 0.45)
		glintUpper.SpreadAngle = Vector2.new(180, 180)
		glintUpper.Color = colorSeq
		glintUpper.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 1.0),
			NumberSequenceKeypoint.new(0.2, 0.40),
			NumberSequenceKeypoint.new(0.7, 0.65),
			NumberSequenceKeypoint.new(1.0, 1.0),
		})
		glintUpper.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 0.12),
			NumberSequenceKeypoint.new(0.5, 0.28),
			NumberSequenceKeypoint.new(1.0, 0.0),
		})
		glintUpper.LightEmission = 0.45
		glintUpper.LightInfluence = 0.55
		glintUpper.Parent = vfxTip

		local glintLower = glintUpper:Clone()
		glintLower.Name = GLINT_EMITTER_NAME .. "_Lower"
		glintLower.Parent = vfxBase

		-- Swing / Flight Trail
		local trail = Instance.new("Trail")
		trail.Name = SWING_TRAIL_NAME
		trail:SetAttribute(VFX_TAG, true)
		trail.Attachment0 = vfxBase
		trail.Attachment1 = vfxTip
		trail.FaceCamera = true
		trail.Lifetime = if band >= 4 then 0.28 elseif band >= 2 then 0.22 else 0.18
		trail.LightEmission = 0.50
		trail.LightInfluence = 0.50
		trail.Color = colorSeq
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, if band >= 4 then 0.25 elseif band >= 2 then 0.32 else 0.40),
			NumberSequenceKeypoint.new(0.6, 0.45),
			NumberSequenceKeypoint.new(1.0, 1.0),
		})
		trail.WidthScale = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 1.0),
			NumberSequenceKeypoint.new(0.8, 0.5),
			NumberSequenceKeypoint.new(1.0, 0.0),
		})
		trail.Enabled = false
		trail.Parent = primary
	end

	-- Band 2+: PointLight & Drifting Motes
	if band >= 2 and profile.LightRange > 0 then
		local light = Instance.new("PointLight")
		light.Name = GLOW_LIGHT_NAME
		light:SetAttribute(VFX_TAG, true)
		light.Color = profile.Color
		light.Range = profile.LightRange
		light.Brightness = profile.LightBrightness
		light.Shadows = false
		light.Parent = vfxCore

		local motes = Instance.new("ParticleEmitter")
		motes.Name = MOTES_EMITTER_NAME
		motes:SetAttribute(VFX_TAG, true)
		motes.Rate = profile.MoteRate
		motes.Lifetime = NumberRange.new(0.7, 1.4)
		motes.Speed = NumberRange.new(0.25, 0.75)
		motes.Drag = 1.2
		motes.SpreadAngle = Vector2.new(60, 60)
		motes.EmissionDirection = Enum.NormalId.Top
		motes.Color = colorSeq
		motes.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 1.0),
			NumberSequenceKeypoint.new(0.2, 0.45),
			NumberSequenceKeypoint.new(0.8, 0.70),
			NumberSequenceKeypoint.new(1.0, 1.0),
		})
		motes.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 0.10),
			NumberSequenceKeypoint.new(0.5, 0.22),
			NumberSequenceKeypoint.new(1.0, 0.05),
		})
		motes.LightEmission = 0.45
		motes.LightInfluence = 0.55
		motes.Parent = vfxCore
	end

	-- Band 3+: Soft Elemental Aura & Wisps
	if band >= 3 and profile.AuraRate > 0 then
		local aura = Instance.new("ParticleEmitter")
		aura.Name = AURA_EMITTER_NAME
		aura:SetAttribute(VFX_TAG, true)
		aura.Rate = profile.AuraRate
		aura.Lifetime = NumberRange.new(0.8, 1.5)
		aura.Speed = NumberRange.new(0.30, 0.75)
		aura.Drag = 1.8
		aura.SpreadAngle = Vector2.new(40, 40)
		aura.EmissionDirection = Enum.NormalId.Top
		aura.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, profile.Accent),
			ColorSequenceKeypoint.new(0.5, profile.Color),
			ColorSequenceKeypoint.new(1.0, profile.Accent),
		})
		aura.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 1.0),
			NumberSequenceKeypoint.new(0.2, 0.65),
			NumberSequenceKeypoint.new(0.7, 0.80),
			NumberSequenceKeypoint.new(1.0, 1.0),
		})
		aura.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 0.15),
			NumberSequenceKeypoint.new(0.5, 0.35),
			NumberSequenceKeypoint.new(1.0, 0.08),
		})
		aura.LightEmission = 0.35
		aura.LightInfluence = 0.65
		aura.Parent = vfxCore

		-- Band 4+: Stave tip auras for full-body radiance
		if band >= 4 then
			local tipAura = aura:Clone()
			tipAura.Name = AURA_EMITTER_NAME .. "_Tip"
			tipAura.Rate = math.round(profile.AuraRate * 0.35)
			tipAura.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0.0, 0.14),
				NumberSequenceKeypoint.new(0.5, 0.34),
				NumberSequenceKeypoint.new(1.0, 0.08),
			})
			tipAura.Parent = vfxTip

			local baseAura = tipAura:Clone()
			baseAura.Name = AURA_EMITTER_NAME .. "_Base"
			baseAura.Parent = vfxBase
		end
	end

	-- Offhand Shield Subtle Low-Glow VFX
	local offhandShield = model:FindFirstChild("OffhandShield")
	if offhandShield and offhandShield:IsA("Model") then
		local shieldHandle = offhandShield.PrimaryPart
		local vfxShieldCenter = shieldHandle and (shieldHandle:FindFirstChild("VfxShieldCenter") or getOrCreateAttachment(shieldHandle, "VfxShieldCenter", Vector3.new(-0.46, 0.10, 0)))
		if vfxShieldCenter and vfxShieldCenter:IsA("Attachment") then
			-- Band 2+: Subtle ambient PointLight on shield center (soft illumination, strictly controlled glow)
			if band >= 2 and profile.LightRange > 0 then
				local shieldLight = Instance.new("PointLight")
				shieldLight.Name = "Vfx_ShieldGlowLight"
				shieldLight:SetAttribute(VFX_TAG, true)
				shieldLight.Color = profile.Color
				shieldLight.Range = math.min(profile.LightRange * 0.65, 4.5)
				shieldLight.Brightness = math.min(profile.LightBrightness * 0.40, 0.40)
				shieldLight.Shadows = false
				shieldLight.Parent = vfxShieldCenter
			end

			-- Band 2+: Subtle glint motes on shield center
			if band >= 2 then
				local shieldGlint = Instance.new("ParticleEmitter")
				shieldGlint.Name = "Vfx_ShieldGlint"
				shieldGlint:SetAttribute(VFX_TAG, true)
				shieldGlint.Rate = math.clamp(math.round(profile.MoteRate * 0.35), 2, 4)
				shieldGlint.Lifetime = NumberRange.new(0.6, 1.2)
				shieldGlint.Speed = NumberRange.new(0.12, 0.35)
				shieldGlint.Drag = 2.2
				shieldGlint.SpreadAngle = Vector2.new(45, 45)
				shieldGlint.EmissionDirection = Enum.NormalId.Front
				shieldGlint.Color = colorSeq
				shieldGlint.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0.0, 1.0),
					NumberSequenceKeypoint.new(0.2, 0.35),
					NumberSequenceKeypoint.new(0.8, 0.65),
					NumberSequenceKeypoint.new(1.0, 1.0),
				})
				shieldGlint.Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0.0, 0.08),
					NumberSequenceKeypoint.new(0.5, 0.18),
					NumberSequenceKeypoint.new(1.0, 0.04),
				})
				shieldGlint.LightEmission = 0.65
				shieldGlint.LightInfluence = 0.35
				shieldGlint.Parent = vfxShieldCenter
			end

			-- Band 4+: Gentle ambient shield wisp for Exalted+
			if band >= 4 and profile.AuraRate > 0 then
				local shieldAura = Instance.new("ParticleEmitter")
				shieldAura.Name = "Vfx_ShieldAura"
				shieldAura:SetAttribute(VFX_TAG, true)
				shieldAura.Rate = math.clamp(math.round(profile.AuraRate * 0.25), 2, 4)
				shieldAura.Lifetime = NumberRange.new(0.8, 1.4)
				shieldAura.Speed = NumberRange.new(0.15, 0.35)
				shieldAura.Drag = 2.5
				shieldAura.SpreadAngle = Vector2.new(30, 30)
				shieldAura.EmissionDirection = Enum.NormalId.Front
				shieldAura.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0.0, profile.Accent),
					ColorSequenceKeypoint.new(0.5, profile.Color),
					ColorSequenceKeypoint.new(1.0, profile.Accent),
				})
				shieldAura.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0.0, 1.0),
					NumberSequenceKeypoint.new(0.25, 0.50),
					NumberSequenceKeypoint.new(0.75, 0.70),
					NumberSequenceKeypoint.new(1.0, 1.0),
				})
				shieldAura.Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0.0, 0.15),
					NumberSequenceKeypoint.new(0.5, 0.30),
					NumberSequenceKeypoint.new(1.0, 0.08),
				})
				shieldAura.LightEmission = 0.55
				shieldAura.LightInfluence = 0.45
				shieldAura.Parent = vfxShieldCenter
			end
		end
	end

	-- Band 6 ("Gilded"): dual gold filigree edge trail, 4s sweeping filigree glint, and BaseRate stamps for LOD/cap.
	if band == 6 then
		CollectionService:AddTag(model, "GildforgedWeapon")
		model:SetAttribute("GildElement", profile.Element)
		model:SetAttribute("GildTemplateId", artifactId or "")

		local goldSeq = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 224, 118)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 250, 225)),
			ColorSequenceKeypoint.new(1.0, Color3.fromRGB(245, 195, 72)),
		})
		if vfxBase and vfxTip and primary then
			local gildTrail = Instance.new("Trail")
			gildTrail.Name = GILD_TRAIL_NAME
			gildTrail:SetAttribute(VFX_TAG, true)
			gildTrail.Attachment0 = vfxBase
			gildTrail.Attachment1 = vfxTip
			gildTrail.FaceCamera = true
			gildTrail.Lifetime = 0.34
			gildTrail.LightEmission = 0.85
			gildTrail.LightInfluence = 0.15
			gildTrail.Color = goldSeq
			gildTrail.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0.0, 0.12),
				NumberSequenceKeypoint.new(0.6, 0.40),
				NumberSequenceKeypoint.new(1.0, 1.0),
			})
			gildTrail.WidthScale = NumberSequence.new({
				NumberSequenceKeypoint.new(0.0, 0.68),
				NumberSequenceKeypoint.new(0.75, 0.38),
				NumberSequenceKeypoint.new(1.0, 0.0),
			})
			gildTrail.Enabled = false
			gildTrail.Parent = primary
		end

		local glintAnchor = vfxCore or vfxTip or vfxBase
		if glintAnchor then
			local sweep = Instance.new("ParticleEmitter")
			sweep.Name = GILD_GLINT_NAME
			sweep:SetAttribute(VFX_TAG, true)
			sweep:SetAttribute("VfxKeepFar", true)
			sweep.Rate = 0.25 -- 1 filigree sweep every 4s
			sweep.Lifetime = NumberRange.new(0.45, 0.70)
			sweep.Speed = NumberRange.new(0.05, 0.20)
			sweep.SpreadAngle = Vector2.new(35, 35)
			sweep.Color = goldSeq
			sweep.LightEmission = 1.0
			sweep.LightInfluence = 0.0
			sweep.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0.0, 0.05),
				NumberSequenceKeypoint.new(0.45, 0.55),
				NumberSequenceKeypoint.new(1.0, 0.0),
			})
			sweep.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0.0, 1.0),
				NumberSequenceKeypoint.new(0.3, 0.0),
				NumberSequenceKeypoint.new(1.0, 1.0),
			})
			sweep.Parent = glintAnchor
		end

		for _, desc in ipairs(model:GetDescendants()) do
			if desc:IsA("ParticleEmitter") and desc:GetAttribute(VFX_TAG) then
				desc:SetAttribute("BaseRate", desc.Rate)
				if string.sub(desc.Name, 1, #GLINT_EMITTER_NAME) == GLINT_EMITTER_NAME or desc.Name == "Vfx_ShieldGlint" then
					desc:SetAttribute("VfxKeepFar", true)
				end
			end
		end
	end

end

-- Toggles idle emitters and light when hero is benched, in COMA or far from the camera.
function WeaponVfx.SetIdleEnabled(model: Model, enabled: boolean)
	for _, child in ipairs(model:GetDescendants()) do
		if child:GetAttribute(VFX_TAG) == true then
			if child:IsA("ParticleEmitter") then
				child.Enabled = enabled
			elseif child:IsA("PointLight") then
				child.Enabled = enabled
			end
		end
	end
end

-- Triggers swing / attack trail for a brief interval during an attack animation.
function WeaponVfx.TriggerAttack(model: Model, tier: number, duration: number?)
	local dur = duration or (if tier >= 3 then 0.28 elseif tier == 2 then 0.22 else 0.18)
	for _, trail in ipairs(model:GetDescendants()) do
		if (trail.Name == SWING_TRAIL_NAME or trail.Name == GILD_TRAIL_NAME) and trail:IsA("Trail") then
			trail.Enabled = true
			trail:Clear()
			task.delay(dur, function()
				if trail and trail.Parent then
					trail.Enabled = false
				end
			end)
		end
	end

	-- Attack tip spark burst
	for _, glint in ipairs(model:GetDescendants()) do
		if glint.Name == GLINT_EMITTER_NAME .. "_Upper" and glint:IsA("ParticleEmitter") then
			glint:Emit(if tier >= 3 then 4 else 2)
		end
	end
end

return table.freeze(WeaponVfx)
