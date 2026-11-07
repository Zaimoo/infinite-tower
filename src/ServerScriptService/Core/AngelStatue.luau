--!strict
-- ServerScriptService/Core/AngelStatue.luau
-- The God's Blessing consecration on the Plaza Fountain (Phase 4 §6.1).
-- Enhances the 1:1 Goddess Statue on `PlazaFountain` with consecrated progression
-- ornaments (votive candles, gilded wings, light motes, radiant halo, sky beam, and
-- the [F] Pray & Assign Acolytes prompt). Level 0 removes the consecration and leaves
-- the base Goddess Fountain.

local AngelStatue = {}

local MODEL_NAME = "Facility_GodsBlessing"
local PROMPT_VERSION = 2
local MARBLE = Color3.fromRGB(232, 228, 220)
local GOLD = Color3.fromRGB(240, 196, 92)
local LIGHT = Color3.fromRGB(255, 232, 170)
local WATER_CYAN = Color3.fromRGB(14, 165, 233)
local WATER_BLESSED = Color3.fromRGB(56, 189, 248)
local MOTE_TEXTURE = "rbxassetid://243660364"

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.Marble
	p.Color = MARBLE
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

-- Returns the fountain's top-centre point and the PlazaFountain model, or nil while not built.
local function fountainTop(plot: Instance): (Vector3?, Model?)
	local fountain = plot:FindFirstChild("PlazaFountain")
	local crest = fountain and fountain:FindFirstChild("Tier3_WaterCrest")
	if not fountain or not fountain:IsA("Model") or not crest or not crest:IsA("BasePart") then
		return nil, nil
	end
	-- Fountain cylinders stand on their X axis, so Size.X is the height.
	return crest.Position + Vector3.new(0, crest.Size.X / 2, 0), fountain
end

local function tintFountain(fountain: Model?, level: number)
	if not fountain then
		return
	end
	for _, name in { "Tier1_WaterPool", "Tier2_WaterPool", "Tier3_WaterCrest" } do
		local water = fountain:FindFirstChild(name)
		if water and water:IsA("BasePart") then
			if water:GetAttribute("OriginalColor") == nil then
				water:SetAttribute("OriginalColor", water.Color)
			end
			local original = water:GetAttribute("OriginalColor")
			water.Color = if level >= 2
				then WATER_BLESSED
				elseif typeof(original) == "Color3" then original
				else WATER_CYAN
		end
	end
end

local function wing(model: Model, base: CFrame, side: number, spread: boolean, gilded: boolean)
	-- Three tapering feathers fanned behind the Goddess's shoulder blades.
	local open = if spread then math.rad(30) else math.rad(84)
	for i = 0, 2 do
		local length = 3.8 - i * 0.8
		local feather = base
			* CFrame.new(side * 0.65, 1.1 - i * 0.55, 0.55)
			* CFrame.Angles(0, 0, side * (open + math.rad(i * 14)))
			* CFrame.new(side * length / 2, 0, 0)
		part(model, {
			Name = "WingFeather",
			Size = Vector3.new(length, 0.55, 0.18),
			CFrame = feather,
			Color = if gilded and i == 0 then GOLD else MARBLE,
			Material = if gilded and i == 0 then Enum.Material.Foil else Enum.Material.Marble,
		})
	end
end

local function build(plot: Instance, level: number): Model?
	local top, fountain = fountainTop(plot)
	if not top or not fountain then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = MODEL_NAME
	model:SetAttribute("Facility", "GodsBlessing")
	model:SetAttribute("Level", level)
	model:SetAttribute("PromptVersion", PROMPT_VERSION)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	local hasGoddess = fountain:GetAttribute("GoddessFountainOverhaul") == true
		or fountain:FindFirstChild("Goddess_Statue") ~= nil

	local base = CFrame.new(top)
	local chest: CFrame
	local lanternCF: CFrame

	if hasGoddess then
		-- Align ornaments directly with the 1:1 Goddess Statue standing on the top plinth
		chest = base * CFrame.new(0, 5.2, 0)
		lanternCF = base * CFrame.new(-1.82, 7.85, -0.42)
	else
		-- Legacy fallback if a custom un-overhauled fountain is present
		part(model, {
			Name = "Pedestal",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.6, 2.4, 2.4),
			CFrame = base * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)),
		})
		local body = base * CFrame.new(0, 0.6, 0)
		for i, width in { 1.9, 1.6, 1.3 } do
			part(model, {
				Name = "Robe",
				Size = Vector3.new(width, 1.1, width * 0.75),
				CFrame = body * CFrame.new(0, 0.55 + (i - 1) * 1.05, 0),
			})
		end
		chest = body * CFrame.new(0, 3.65, 0)
		part(model, { Name = "Torso", Size = Vector3.new(1.15, 1.1, 0.75), CFrame = chest })
		part(model, {
			Name = "Head",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.85, 0.85, 0.85),
			CFrame = chest * CFrame.new(0, 1.0, 0),
		})
		lanternCF = chest * CFrame.new(0, 2.15, 0)
	end

	local lantern = part(model, {
		Name = "Lantern",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.58, 0.58, 0.58),
		CFrame = lanternCF,
		Material = Enum.Material.Neon,
		Color = LIGHT,
		Transparency = 0.25,
		CastShadow = false,
	})
	model.PrimaryPart = lantern

	local glow = Instance.new("PointLight")
	glow.Name = "LanternGlow"
	glow.Color = LIGHT
	glow.Brightness = 0.9 + level * 0.22
	glow.Range = 12 + level * 2
	glow.Shadows = false
	glow.Parent = lantern

	local pulse = Instance.new("ParticleEmitter")
	pulse.Name = "BlessingPulse"
	pulse.Texture = MOTE_TEXTURE
	pulse.Color = ColorSequence.new(LIGHT)
	pulse.LightEmission = 0.6
	pulse.Size = NumberSequence.new(0.6, 0)
	pulse.Lifetime = NumberRange.new(1, 1.6)
	pulse.Speed = NumberRange.new(6, 10)
	pulse.SpreadAngle = Vector2.new(180, 180)
	pulse.Rate = 0
	pulse.Parent = lantern

	wing(model, chest, -1, level >= 5, level >= 2)
	wing(model, chest, 1, level >= 5, level >= 2)

	-- Lv.1: Votive candles on the lower basin rim.
	local fountainCenter = Vector3.new(top.X, 0, top.Z)
	local rim = fountain:FindFirstChild("Tier1_Rim")
	if rim and rim:IsA("BasePart") then
		local rimTop = rim.Position.Y + rim.Size.X / 2
		local radius = rim.Size.Y / 2 - 0.45
		for i = 0, 5 do
			local angle = (i / 6 + 1 / 12) * math.pi * 2
			local spot = Vector3.new(
				fountainCenter.X + math.cos(angle) * radius,
				rimTop + 0.35,
				fountainCenter.Z + math.sin(angle) * radius
			)
			part(model, {
				Name = "Candle",
				Size = Vector3.new(0.25, 0.7, 0.25),
				CFrame = CFrame.new(spot),
				Color = Color3.fromRGB(250, 244, 226),
				Material = Enum.Material.SmoothPlastic,
			})
			local flame = part(model, {
				Name = "Flame",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.22, 0.22, 0.22),
				CFrame = CFrame.new(spot + Vector3.new(0, 0.48, 0)),
				Material = Enum.Material.Neon,
				Color = Color3.fromRGB(255, 196, 96),
				CastShadow = false,
			})
			local flicker = Instance.new("PointLight")
			flicker.Color = Color3.fromRGB(255, 190, 110)
			flicker.Brightness = 0.55
			flicker.Range = 6
			flicker.Shadows = false
			flicker.Parent = flame
		end
	end

	-- Lv.3: Rising light motes.
	if level >= 3 then
		local motes = pulse:Clone()
		motes.Name = "LightMotes"
		motes.Rate = 6
		motes.Speed = NumberRange.new(1.5, 3)
		motes.Acceleration = Vector3.new(0, 1.5, 0)
		motes.SpreadAngle = Vector2.new(60, 60)
		motes.Lifetime = NumberRange.new(2.5, 3.5)
		motes.Size = NumberSequence.new(0.3, 0)
		motes.Parent = lantern
	end

	-- Lv.4: Floating golden halo above the Goddess's crown and drifting petals.
	if level >= 4 then
		local haloCenter = chest * CFrame.new(0, 2.85, 0)
		for i = 0, 11 do
			local angle = i / 12 * math.pi * 2
			part(model, {
				Name = "Halo",
				Size = Vector3.new(0.42, 0.1, 0.14),
				CFrame = haloCenter * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, 0.68),
				Material = Enum.Material.Neon,
				Color = GOLD,
				CastShadow = false,
			})
		end
		local petals = pulse:Clone()
		petals.Name = "Petals"
		petals.Color = ColorSequence.new(Color3.fromRGB(255, 214, 230))
		petals.LightEmission = 0.3
		petals.Rate = 4
		petals.Speed = NumberRange.new(0.5, 1.5)
		petals.Acceleration = Vector3.new(0, -1, 0)
		petals.Lifetime = NumberRange.new(4, 6)
		petals.Size = NumberSequence.new(0.35)
		petals.Parent = lantern
	end

	-- Lv.5: Soft beam of consecrated light into the sky.
	if level >= 5 then
		part(model, {
			Name = "SkyBeam",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(120, 1.1, 1.1),
			CFrame = lantern.CFrame * CFrame.new(0, 60.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Neon,
			Color = LIGHT,
			Transparency = 0.65,
			CastShadow = false,
		})
	end

	-- [F] prompt on the fountain: the God's Blessing facility panel.
	local promptY = if rim and rim:IsA("BasePart") then rim.Position.Y + rim.Size.X / 2 + 1.5 else top.Y
	local interaction = part(model, {
		Name = "FacilityInteraction",
		Size = Vector3.one,
		CFrame = CFrame.new(fountainCenter.X, promptY, fountainCenter.Z),
		Transparency = 1,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FacilityHUDPrompt"
	prompt:SetAttribute("FacilityHUD", "GodsBlessing")
	prompt.ObjectText = "God's Blessing"
	prompt.ActionText = "Pray & Assign Acolytes"
	prompt.MaxActivationDistance = 18
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Enum.KeyCode.F, Enum.KeyCode.ButtonX
	prompt.ClickablePrompt = true
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Parent = interaction

	model.Parent = plot
	return model
end

function AngelStatue.Get(plot: Instance): Model?
	local existing = plot:FindFirstChild(MODEL_NAME)
	return if existing and existing:IsA("Model") then existing else nil
end

-- Builds, rebuilds or removes the consecration for `level`. Returns the model (nil at level 0).
function AngelStatue.Apply(plot: Instance, level: number): Model?
	local existing = AngelStatue.Get(plot)
	local _, fountain = fountainTop(plot)
	tintFountain(fountain, level)
	if level <= 0 then
		if existing then
			existing:Destroy()
		end
		return nil
	end
	if
		existing
		and existing:GetAttribute("Level") == level
		and existing:GetAttribute("PromptVersion") == PROMPT_VERSION
	then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	return build(plot, level)
end

-- Bright burst from the blessing orb after a lucky summon.
function AngelStatue.Pulse(plot: Instance)
	local statue = AngelStatue.Get(plot)
	local lantern = statue and statue:FindFirstChild("Lantern")
	local emitter = lantern and lantern:FindFirstChild("BlessingPulse")
	if emitter and emitter:IsA("ParticleEmitter") then
		emitter:Emit(40)
	end
end

return AngelStatue
