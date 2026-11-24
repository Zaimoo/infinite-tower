--!strict
-- StarterPlayerScripts/Rendering/Conjunction.luau
-- Client-only, zero-remote ambience controller for Astral Archives Floors 41–45 (GDD §3.3, prompt §5.6).
--
-- Synchronised purely from workspace:GetServerTimeNow() so every player sees the same Conjunction sweep
-- with zero remotes and zero gameplay effect:
--   * Cycle period tightens floor by floor: 16 s (F41) -> 13.5 s (F42) -> 11 s (F43) -> 8.5 s (F44) -> 6 s (F45).
--   * Sweeps across CollectionService-tagged star-glyphs ("ConjunctionGlyph"), brightens Index Lamps
--     ("ConjunctionLamp"), lifts & settles tagged page emitters ("ConjunctionPageEmitter"), slowly turns
--     Floor 45's Rift Eye ("ConjunctionRiftEye"), nudges bloom by +0.05..0.10 (never a flash), and plays
--     a soft far chime (plus a low Rift undertone on Floors 43–45).
--   * At the lowest Graphics quality or with Colour FX off, only the glyph wash runs.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local HubLighting = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("HubLighting"))

local Conjunction = {}

local LocalPlayer = Players.LocalPlayer

-- Cycle period (seconds) per Astral Archives floor (41..45).
Conjunction.CycleSeconds = table.freeze({
	[41] = 16.0,
	[42] = 13.5,
	[43] = 11.0,
	[44] = 8.5,
	[45] = 6.0,
})

local MAX_GLYPHS = 96
local MAX_LAMPS = 32
local MAX_EMITTERS = 16
local RESCAN_INTERVAL = 2.0

local GLYPH_PEAK_COLOR = Color3.fromRGB(252, 238, 186) -- pale starlight gold (never orange/red)
local RIFT_EYE_LOCAL = Vector3.new(12, -10, -32)

type GlyphEntry = {
	Part: BasePart,
	BaseColor: Color3,
	Order: number, -- 0..1 sweep order along room Z/radial
}
type LampEntry = {
	Light: PointLight?,
	BaseBrightness: number,
	Part: BasePart?,
	BaseColor: Color3,
	Order: number,
}
type EmitterEntry = {
	Anchor: BasePart,
	Emitter: ParticleEmitter,
	BaseRate: number,
	BaseAccel: Vector3,
}

local started = false
local activeFloor: number? = nil
local lastScan = 0
local lastCycleIndex = -1
local glyphs: { GlyphEntry } = {}
local lamps: { LampEntry } = {}
local emitters: { EmitterEntry } = {}
local riftEyes: { Model } = {}
local chimeSound: Sound? = nil
local riftSound: Sound? = nil
local bloomNudge: BloomEffect? = nil
local astralSky: Sky? = nil
local savedSkies: { { Sky: Sky, Parent: Instance? } } = {}

local function setAstralSky(enabled: boolean, floorId: number?)
	if enabled then
		if not astralSky then
			-- Park any existing daytime Lighting Sky locally while inside the open-sky Astral Archives
			for _, child in Lighting:GetChildren() do
				if child:IsA("Sky") and child.Name ~= "AstralArchivesSky" then
					table.insert(savedSkies, { Sky = child, Parent = child.Parent })
					child.Parent = nil
				end
			end
			local sky = Instance.new("Sky")
			sky.Name = "AstralArchivesSky"
			-- Deep dark indigo-black cosmos with dense starfield (matches all 5 Astral Archives reference scenes)
			sky.SkyboxBk = "rbxassetid://159454299"
			sky.SkyboxDn = "rbxassetid://159454296"
			sky.SkyboxFt = "rbxassetid://159454293"
			sky.SkyboxLf = "rbxassetid://159454286"
			sky.SkyboxRt = "rbxassetid://159454300"
			sky.SkyboxUp = "rbxassetid://159454288"
			sky.StarCount = 5000
			sky.CelestialBodiesShown = false
			sky.Parent = Lighting
			astralSky = sky
		end
		if astralSky and floorId then
			-- Starfield dims progressively as the Rift consumes the sky (F41 full stars -> F45 half black)
			astralSky.StarCount = math.max(1800, 5000 - (floorId - 41) * 750)
		end
	else
		if astralSky then
			astralSky:Destroy()
			astralSky = nil
		end
		for _, entry in savedSkies do
			if entry.Sky and entry.Parent then
				entry.Sky.Parent = entry.Parent
			end
		end
		table.clear(savedSkies)
	end
end

local function floorOrigin(floorId: number): Vector3
	local col = (floorId - 1) % 10
	local row = math.floor((floorId - 1) / 10)
	return Vector3.new(
		HubLighting.FloorGridOrigin + col * HubLighting.FloorGridSpacing,
		1000,
		HubLighting.FloorGridOrigin + row * HubLighting.FloorGridSpacing
	)
end

local function isLowQuality(): boolean
	if Lighting:GetAttribute("SettingsColorFX") == false then
		return true
	end
	local ok, lvl = pcall(function()
		return UserSettings().GameSettings.SavedQualityLevel
	end)
	if ok and (lvl == Enum.SavedQualitySetting.QualityLevel1 or lvl == Enum.SavedQualitySetting.QualityLevel2) then
		return true
	end
	return false
end

local function currentPlayerFloor(): number?
	local pos: Vector3? = nil
	if _G.IsViewingSquad and _G.IsViewingSquad() then
		local cam = workspace.CurrentCamera
		if cam then pos = cam.CFrame.Position end
	else
		local char = LocalPlayer and LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			pos = root.Position
		elseif workspace.CurrentCamera then
			pos = workspace.CurrentCamera.Focus.Position
		end
	end
	if not pos then return nil end
	local fId = HubLighting.TowerFloorAt(pos.X, pos.Z)
	if fId and fId >= 41 and fId <= 45 then
		return fId
	end
	return nil
end

local function ensureAudio()
	if not chimeSound then
		local s = Instance.new("Sound")
		s.Name = "ConjunctionChime"
		s.SoundId = "rbxassetid://9113677250" -- gentle resonant chime
		s.Volume = 0.14
		s.PlaybackSpeed = 0.85
		s.Parent = SoundService
		chimeSound = s
	end
	if not riftSound then
		local s = Instance.new("Sound")
		s.Name = "ConjunctionRiftNote"
		s.SoundId = "rbxassetid://9114221735" -- low ambient drone
		s.Volume = 0.12
		s.PlaybackSpeed = 0.52
		s.Parent = SoundService
		riftSound = s
	end
end

local function ensureBloom(): BloomEffect
	if bloomNudge and bloomNudge.Parent == Lighting then
		return bloomNudge
	end
	local existing = Lighting:FindFirstChild("ConjunctionBloomNudge")
	if existing and existing:IsA("BloomEffect") then
		bloomNudge = existing
		return existing
	end
	local b = Instance.new("BloomEffect")
	b.Name = "ConjunctionBloomNudge"
	b.Intensity = 0
	b.Size = 22
	b.Threshold = 1.35
	b.Enabled = false
	b.Parent = Lighting
	bloomNudge = b
	return b
end

local function clearState()
	for _, g in glyphs do
		if g.Part.Parent then
			g.Part.Color = g.BaseColor
		end
	end
	for _, l in lamps do
		if l.Light and l.Light.Parent then
			l.Light.Brightness = l.BaseBrightness
		end
		if l.Part and l.Part.Parent then
			l.Part.Color = l.BaseColor
		end
	end
	for _, e in emitters do
		if e.Emitter.Parent then
			e.Emitter.Rate = e.BaseRate
			e.Emitter.Acceleration = e.BaseAccel
		end
	end
	table.clear(glyphs)
	table.clear(lamps)
	table.clear(emitters)
	table.clear(riftEyes)
	if bloomNudge then
		bloomNudge.Intensity = 0
		bloomNudge.Enabled = false
	end
end

local function scanFloor(floorId: number)
	clearState()
	local origin = floorOrigin(floorId)
	local radiusLimit = 620

	local function inFloor(pos: Vector3): boolean
		return math.abs(pos.X - origin.X) <= radiusLimit and math.abs(pos.Z - origin.Z) <= radiusLimit
	end

	for _, inst in CollectionService:GetTagged("ConjunctionGlyph") do
		if #glyphs >= MAX_GLYPHS then break end
		if inst:IsA("BasePart") and inFloor(inst.Position) then
			local relZ = (inst.Position.Z - origin.Z + 400) / 800
			table.insert(glyphs, {
				Part = inst,
				BaseColor = inst.Color,
				Order = math.clamp(1 - relZ, 0, 1),
			})
		end
	end

	for _, inst in CollectionService:GetTagged("ConjunctionLamp") do
		if #lamps >= MAX_LAMPS then break end
		local pos: Vector3? = nil
		local lightInst: PointLight? = nil
		local glowPart: BasePart? = nil
		if inst:IsA("Model") then
			pos = inst:GetPivot().Position
			lightInst = inst:FindFirstChildWhichIsA("PointLight", true)
			for _, d in inst:GetDescendants() do
				if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
					glowPart = d
					break
				end
			end
		elseif inst:IsA("BasePart") then
			pos = inst.Position
			glowPart = inst
			lightInst = inst:FindFirstChildWhichIsA("PointLight", true)
		end
		if pos and inFloor(pos) and (lightInst or glowPart) then
			local relZ = (pos.Z - origin.Z + 400) / 800
			table.insert(lamps, {
				Light = lightInst,
				BaseBrightness = if lightInst then lightInst.Brightness else 1,
				Part = glowPart,
				BaseColor = if glowPart then glowPart.Color else GLYPH_PEAK_COLOR,
				Order = math.clamp(1 - relZ, 0, 1),
			})
		end
	end

	for _, inst in CollectionService:GetTagged("ConjunctionPageEmitter") do
		if #emitters >= MAX_EMITTERS then break end
		if inst:IsA("BasePart") and inFloor(inst.Position) then
			local pe = inst:FindFirstChildWhichIsA("ParticleEmitter")
			if pe then
				table.insert(emitters, {
					Anchor = inst,
					Emitter = pe,
					BaseRate = pe.Rate,
					BaseAccel = pe.Acceleration,
				})
			end
		end
	end

	if floorId == 45 then
		for _, inst in CollectionService:GetTagged("ConjunctionRiftEye") do
			if inst:IsA("Model") and inFloor(inst:GetPivot().Position) then
				table.insert(riftEyes, inst)
			end
		end
	end
end

local function step(dt: number)
	local floorId = currentPlayerFloor()
	if floorId ~= activeFloor then
		activeFloor = floorId
		lastCycleIndex = -1
		if floorId then
			setAstralSky(true, floorId)
			scanFloor(floorId)
			lastScan = os.clock()
		else
			setAstralSky(false, nil)
			clearState()
		end
	end
	if not floorId then return end

	local nowClock = os.clock()
	if nowClock - lastScan >= RESCAN_INTERVAL and (#glyphs == 0 or #lamps == 0) then
		scanFloor(floorId)
		lastScan = nowClock
	end

	local period = Conjunction.CycleSeconds[floorId] or 16.0
	local serverNow = workspace:GetServerTimeNow()
	local cycleIndex = math.floor(serverNow / period)
	local phase = (serverNow % period) / period -- 0..1 synchronized across all clients
	local lowQ = isLowQuality()

	-- 1. Star-glyph & constellation sweep wave (runs at all Graphics qualities)
	for _, g in glyphs do
		if g.Part.Parent then
			local dist = math.abs(phase - g.Order)
			dist = math.min(dist, 1 - dist)
			local wave = math.clamp(1 - dist / 0.18, 0, 1)
			local glowT = wave * wave * (3 - 2 * wave)
			g.Part.Color = g.BaseColor:Lerp(GLYPH_PEAK_COLOR, glowT * 0.65)
		end
	end

	if lowQ then
		if bloomNudge and bloomNudge.Enabled then
			bloomNudge.Intensity = 0
			bloomNudge.Enabled = false
		end
		for _, e in emitters do
			if e.Emitter.Parent then
				e.Emitter.Rate = math.min(e.BaseRate, 1)
			end
		end
		return
	end

	-- 2. Index Lamp gentle brightening wave
	for _, l in lamps do
		local dist = math.abs(phase - l.Order)
		dist = math.min(dist, 1 - dist)
		local wave = math.clamp(1 - dist / 0.22, 0, 1)
		local pulse = wave * wave
		if l.Light and l.Light.Parent then
			l.Light.Brightness = l.BaseBrightness * (1 + 0.24 * pulse)
		end
		if l.Part and l.Part.Parent then
			l.Part.Color = l.BaseColor:Lerp(GLYPH_PEAK_COLOR, pulse * 0.45)
		end
	end

	-- 3. Loose page lift/settle (on Floor 45, pages lift continuously and pull toward the Rift Eye!)
	local origin = floorOrigin(floorId)
	local riftWorld = origin + RIFT_EYE_LOCAL
	local liftPulse = math.sin(phase * math.pi)
	for _, e in emitters do
		if e.Emitter.Parent and e.Anchor.Parent then
			if floorId == 45 then
				local toEye = riftWorld - e.Anchor.Position
				local pullDir = if toEye.Magnitude > 1 then toEye.Unit else Vector3.new(0, -1, 0)
				e.Emitter.Rate = e.BaseRate * (1.25 + 0.8 * liftPulse)
				e.Emitter.Acceleration = pullDir * (4.5 + 3.5 * liftPulse) + Vector3.new(0, 1.8, 0)
			else
				e.Emitter.Rate = e.BaseRate * (0.85 + 0.9 * liftPulse)
				e.Emitter.Acceleration = e.BaseAccel + Vector3.new(0, 2.4 * liftPulse, 0)
			end
		end
	end

	-- 4. Slow client rotation of Floor 45's Rift Eye
	if floorId == 45 and #riftEyes > 0 then
		local rotStep = CFrame.Angles(0, dt * 0.22, 0)
		for _, eye in riftEyes do
			if eye.Parent then
				eye:PivotTo(eye:GetPivot() * rotStep)
			end
		end
	end

	-- 5. Subtle bloom nudge (+0.05..0.10 peak, never a flash)
	local b = ensureBloom()
	local intensity = (0.05 + (floorId - 41) * 0.0125) * math.sin(phase * math.pi) ^ 2
	b.Enabled = intensity > 0.004
	b.Intensity = intensity

	-- 6. Far chime once per cycle (plus low Rift undertone on Floors 43–45)
	if cycleIndex ~= lastCycleIndex then
		lastCycleIndex = cycleIndex
		ensureAudio()
		if chimeSound then
			chimeSound.PlaybackSpeed = 0.92 - (floorId - 41) * 0.04
			pcall(function() chimeSound:Play() end)
		end
		if floorId >= 43 and riftSound then
			riftSound.Volume = 0.08 + (floorId - 43) * 0.04
			pcall(function() riftSound:Play() end)
		end
	end
end

function Conjunction.Start()
	if started then return end
	started = true
	RunService.RenderStepped:Connect(step)
end

return Conjunction
