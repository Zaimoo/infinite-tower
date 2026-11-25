--!strict
-- StarterPlayerScripts/Rendering/Dirge.luau
-- Client-only, zero-remote ambience controller for Abyssal Throne Floors 46–50 (GDD §3.3, prompt §5.6).
--
-- Synchronised purely from workspace:GetServerTimeNow() so every player sees the same Dirge toll
-- with zero remotes and zero gameplay effect:
--   * Cycle period tightens floor by floor: 16 s (F46) -> 13.5 s (F47) -> 11 s (F48) -> 8.5 s (F49) -> 6 s (F50).
--   * Parks any daytime Lighting Sky and installs a sunless, starless copy of it ("AbyssalVaultSky") while on
--     F46–50: an overcast vault under the floor's haze, never a space skybox.
--   * Continuously scrolls "DirgeUndertow" toward -Z (the Throne) and surges speed & brightness on each toll.
--   * Flares & leans "DirgeWardlight" bone-white flames toward -Z, draws "DirgeChain" dressing taut then slackens,
--     lifts "DirgeAshEmitter" particles toward -Z, bows "DirgeSilhouette" far-ledge figures toward the Throne,
--     nudges "DirgeBloomNudge" (+0.05..0.08, never a flash), and plays a soft far iron bell toll.
--   * On Floor 50, ~0.55 s after each toll, triggers a double heartbeat (lub-dub) in deep matte red-black on
--     "DirgeHeartbeat" (Crimson Eclipse & Throne heart-crack) with a low heartbeat sound.
--   * At lowest Graphics quality (QualityLevel1/2 or SettingsColorFX == false), only the bell toll and Undertow run.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local HubLighting = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("HubLighting"))

local Dirge = {}

local LocalPlayer = Players.LocalPlayer

-- Cycle period (seconds) per Abyssal Throne floor (46..50).
Dirge.CycleSeconds = table.freeze({
	[46] = 16.0,
	[47] = 13.5,
	[48] = 11.0,
	[49] = 8.5,
	[50] = 6.0,
})

local MAX_UNDERTOW = 64
local MAX_WARDLIGHTS = 48
local MAX_CHAINS = 48
local MAX_EMITTERS = 16
local MAX_SILHOUETTES = 32
local MAX_HEARTBEATS = 8
local RESCAN_INTERVAL = 2.0
-- Only small dressing sways on the toll (a lantern, a short chain, a court figure). A big tagged piece (a gatehouse,
-- a cage, a 30-stud chain segment, an anchor spire) visibly tipped up and back, and pulled apart from what it
-- hangs on, so it keeps still and only its light and flame answer the toll.
local MAX_SWAY_SIZE = 16

local UNDERTOW_PEAK_COLOR = Color3.fromRGB(164, 112, 245) -- void violet surge (never on walk surfaces)
local WARDLIGHT_PEAK_COLOR = Color3.fromRGB(244, 240, 228) -- bone-white flame (hue ~45°, sat <= 0.1)
local HEARTBEAT_PEAK_COLOR = Color3.fromRGB(96, 16, 26) -- deep matte red-black (never bright crimson)
local HEARTBEAT_REST_COLOR = Color3.fromRGB(48, 8, 14)

type UndertowBeamEntry = {
	Beam: Beam,
	BaseSpeed: number,
	BaseBrightness: number,
	BaseLightEmission: number,
	DirSign: number,
}
type UndertowTextureEntry = {
	Texture: Texture,
	DirU: number,
	DirV: number,
	BaseOffsetU: number,
	BaseOffsetV: number,
	OffsetU: number,
	OffsetV: number,
	BaseTransparency: number,
}
type UndertowEntry = {
	Part: BasePart?,
	BaseColor: Color3,
	Light: PointLight?,
	BaseLightBrightness: number,
	Beams: { UndertowBeamEntry },
	Textures: { UndertowTextureEntry },
}
type WardlightEntry = {
	TargetModel: Model?,
	TargetPart: BasePart?,
	BaseCFrame: CFrame,
	Light: PointLight?,
	BaseBrightness: number,
	FlamePart: BasePart?,
	BaseFlameColor: Color3,
	PhaseOffset: number,
}
type ChainEntry = {
	TargetModel: Model?,
	TargetPart: BasePart?,
	BaseCFrame: CFrame,
	PhaseOffset: number,
}
type EmitterEntry = {
	Emitter: ParticleEmitter,
	BaseRate: number,
	BaseAccel: Vector3,
}
type SilhouetteEntry = {
	TargetModel: Model?,
	TargetPart: BasePart?,
	BaseCFrame: CFrame,
}
type HeartbeatPartEntry = {
	Part: BasePart,
	BaseColor: Color3,
}
type HeartbeatEntry = {
	Parts: { HeartbeatPartEntry },
	Light: PointLight?,
	BaseBrightness: number,
	BaseLightColor: Color3,
}

local started = false
local activeFloor: number? = nil
local lastScan = 0
local lastCycleIndex = -1
local lastHeartbeatCycleIndex = -1
local lowQRestored = false

local undertows: { UndertowEntry } = {}
local wardlights: { WardlightEntry } = {}
local chains: { ChainEntry } = {}
local emitters: { EmitterEntry } = {}
local silhouettes: { SilhouetteEntry } = {}
local heartbeats: { HeartbeatEntry } = {}

local bellSound: Sound? = nil
local heartbeatSound: Sound? = nil
local bloomNudge: BloomEffect? = nil
local vaultSky: Sky? = nil
local savedSkies: { { Sky: Sky, Parent: Instance? } } = {}

local function smoothstep01(t: number): number
	local x = math.clamp(t, 0, 1)
	return x * x * (3 - 2 * x)
end

local function setVaultSky(enabled: boolean)
	if enabled then
		if not vaultSky then
			-- Park any existing Lighting Sky instances locally while inside the underground Abyssal Vault
			for _, child in Lighting:GetChildren() do
				if child:IsA("Sky") and child.Name ~= "AbyssalVaultSky" then
					table.insert(savedSkies, { Sky = child, Parent = child.Parent })
					child.Parent = nil
				end
			end
			-- Not a space skybox: the tower's own clouded sky (a copy of the parked one), with no sun, moon or
			-- stars, so the floor's haze and atmosphere grade tint it into a dim overcast vault.
			local base = savedSkies[1] and savedSkies[1].Sky
			local sky: Sky = (if base then base:Clone() else nil) or Instance.new("Sky")
			sky.Name = "AbyssalVaultSky"
			sky.StarCount = 0
			sky.CelestialBodiesShown = false
			sky.Parent = Lighting
			vaultSky = sky
		end
	else
		if vaultSky then
			vaultSky:Destroy()
			vaultSky = nil
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
		if cam then
			pos = cam.CFrame.Position
		end
	else
		local char = LocalPlayer and LocalPlayer.Character
		local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			pos = root.Position
		elseif workspace.CurrentCamera then
			pos = workspace.CurrentCamera.Focus.Position
		end
	end
	if not pos then
		return nil
	end
	local fId = HubLighting.TowerFloorAt(pos.X, pos.Z)
	if fId and fId >= 46 and fId <= 50 then
		return fId
	end
	return nil
end

local function ensureAudio()
	if not bellSound then
		local s = Instance.new("Sound")
		s.Name = "DirgeBellToll"
		s.SoundId = "rbxassetid://9113677250" -- pitched down to a soft far iron bell toll
		s.Volume = 0.14
		s.PlaybackSpeed = 0.50
		s.Parent = SoundService
		bellSound = s
	end
	if not heartbeatSound then
		local s = Instance.new("Sound")
		s.Name = "DirgeThroneHeartbeat"
		s.SoundId = "rbxassetid://6655787968" -- heavy heartbeat from SoundCatalog
		s.Volume = 0.15
		s.PlaybackSpeed = 0.78
		s.Parent = SoundService
		heartbeatSound = s
	end
end

local function ensureBloom(): BloomEffect
	if bloomNudge and bloomNudge.Parent == Lighting then
		return bloomNudge
	end
	local existing = Lighting:FindFirstChild("DirgeBloomNudge")
	if existing and existing:IsA("BloomEffect") then
		bloomNudge = existing
		return existing
	end
	local b = Instance.new("BloomEffect")
	b.Name = "DirgeBloomNudge"
	b.Intensity = 0
	b.Size = 22
	b.Threshold = 1.35
	b.Enabled = false
	b.Parent = Lighting
	bloomNudge = b
	return b
end

local function restoreQualityScaledEffects()
	for _, w in wardlights do
		if w.TargetModel and w.TargetModel.Parent then
			w.TargetModel:PivotTo(w.BaseCFrame)
		elseif w.TargetPart and w.TargetPart.Parent then
			w.TargetPart.CFrame = w.BaseCFrame
		end
		if w.Light and w.Light.Parent then
			w.Light.Brightness = w.BaseBrightness
		end
		if w.FlamePart and w.FlamePart.Parent then
			w.FlamePart.Color = w.BaseFlameColor
		end
	end
	for _, c in chains do
		if c.TargetModel and c.TargetModel.Parent then
			c.TargetModel:PivotTo(c.BaseCFrame)
		elseif c.TargetPart and c.TargetPart.Parent then
			c.TargetPart.CFrame = c.BaseCFrame
		end
	end
	for _, s in silhouettes do
		if s.TargetModel and s.TargetModel.Parent then
			s.TargetModel:PivotTo(s.BaseCFrame)
		elseif s.TargetPart and s.TargetPart.Parent then
			s.TargetPart.CFrame = s.BaseCFrame
		end
	end
	for _, hb in heartbeats do
		for _, p in hb.Parts do
			if p.Part.Parent then
				p.Part.Color = p.BaseColor
			end
		end
		if hb.Light and hb.Light.Parent then
			hb.Light.Brightness = hb.BaseBrightness
			hb.Light.Color = hb.BaseLightColor
		end
	end
	if bloomNudge then
		bloomNudge.Intensity = 0
		bloomNudge.Enabled = false
	end
end

local function clearState()
	for _, u in undertows do
		if u.Part and u.Part.Parent then
			u.Part.Color = u.BaseColor
		end
		if u.Light and u.Light.Parent then
			u.Light.Brightness = u.BaseLightBrightness
		end
		for _, b in u.Beams do
			if b.Beam.Parent then
				b.Beam.TextureSpeed = b.BaseSpeed * b.DirSign
				b.Beam.Brightness = b.BaseBrightness
				b.Beam.LightEmission = b.BaseLightEmission
			end
		end
		for _, t in u.Textures do
			if t.Texture.Parent then
				t.Texture.OffsetStudsU = t.BaseOffsetU
				t.Texture.OffsetStudsV = t.BaseOffsetV
				t.Texture.Transparency = t.BaseTransparency
			end
		end
	end
	restoreQualityScaledEffects()
	for _, e in emitters do
		if e.Emitter.Parent then
			e.Emitter.Rate = e.BaseRate
			e.Emitter.Acceleration = e.BaseAccel
		end
	end
	table.clear(undertows)
	table.clear(wardlights)
	table.clear(chains)
	table.clear(emitters)
	table.clear(silhouettes)
	table.clear(heartbeats)
	lowQRestored = false
end

local function textureScrollDirsTowardNorth(part: BasePart, face: Enum.NormalId): (number, number)
	local cf = part.CFrame
	local uAxis: Vector3
	local vAxis: Vector3
	if face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then
		uAxis = cf.RightVector
		vAxis = cf.LookVector
	elseif face == Enum.NormalId.Front or face == Enum.NormalId.Back then
		uAxis = cf.RightVector
		vAxis = cf.UpVector
	else
		uAxis = cf.LookVector
		vAxis = cf.UpVector
	end
	local north = Vector3.new(0, 0, -1)
	local dotU = uAxis:Dot(north)
	local dotV = vAxis:Dot(north)
	local mag = math.sqrt(dotU * dotU + dotV * dotV)
	if mag < 0.05 then
		return 0, 1
	end
	return dotU / mag, dotV / mag
end

local function beamDirSignTowardNorth(beam: Beam): number
	local a0 = beam.Attachment0
	local a1 = beam.Attachment1
	if a0 and a1 then
		if a1.WorldPosition.Z <= a0.WorldPosition.Z then
			return 1
		else
			return -1
		end
	end
	return 1
end

local function instancePosition(inst: Instance): Vector3?
	if inst:IsA("BasePart") then
		return inst.Position
	elseif inst:IsA("Model") then
		return inst:GetPivot().Position
	elseif inst:IsA("Attachment") then
		return inst.WorldPosition
	elseif inst:IsA("Beam") then
		if inst.Attachment0 then
			return inst.Attachment0.WorldPosition
		elseif inst.Parent and inst.Parent:IsA("BasePart") then
			return inst.Parent.Position
		end
	elseif inst:IsA("ParticleEmitter") then
		local p = inst.Parent
		if p and p:IsA("BasePart") then
			return p.Position
		elseif p and p:IsA("Attachment") then
			return p.WorldPosition
		end
	end
	return nil
end

-- True when a tagged piece is a single small walk-through part that may lean, bow or draw taut on the toll.
-- A Model never moves: under streaming only some of its parts may have arrived when the floor is scanned, so it
-- measures small, and pivoting it moves just those parts while the rest stream in where they were (the "broken"
-- great chains on Floor 48).
local function canSway(inst: Instance): boolean
	if inst:IsA("BasePart") then
		return math.max(inst.Size.X, inst.Size.Y, inst.Size.Z) <= MAX_SWAY_SIZE and not inst.CanCollide
	end
	return false
end

local function scanFloor(floorId: number)
	clearState()
	local origin = floorOrigin(floorId)
	local radiusLimit = 620

	local function inFloor(pos: Vector3): boolean
		return math.abs(pos.X - origin.X) <= radiusLimit and math.abs(pos.Z - origin.Z) <= radiusLimit
	end

	-- 1. DirgeUndertow: BasePart (with child Texture or Beam) / Beam
	for _, inst in CollectionService:GetTagged("DirgeUndertow") do
		if #undertows >= MAX_UNDERTOW then
			break
		end
		local pos = instancePosition(inst)
		if pos and inFloor(pos) then
			if inst:IsA("Beam") then
				local dirSign = beamDirSignTowardNorth(inst)
				local rawSpeed = math.abs(inst.TextureSpeed)
				table.insert(undertows, {
					Part = nil,
					BaseColor = Color3.new(0, 0, 0),
					Light = nil,
					BaseLightBrightness = 0,
					Beams = {
						{
							Beam = inst,
							BaseSpeed = if rawSpeed > 0.05 then rawSpeed else 1.2,
							BaseBrightness = inst.Brightness,
							BaseLightEmission = inst.LightEmission,
							DirSign = dirSign,
						},
					},
					Textures = {},
				})
			elseif inst:IsA("BasePart") then
				local beamList: { UndertowBeamEntry } = {}
				local texList: { UndertowTextureEntry } = {}
				local lightInst: PointLight? = inst:FindFirstChildWhichIsA("PointLight", true)
				for _, child in inst:GetDescendants() do
					if child:IsA("Beam") then
						local dirSign = beamDirSignTowardNorth(child)
						local rawSpeed = math.abs(child.TextureSpeed)
						table.insert(beamList, {
							Beam = child,
							BaseSpeed = if rawSpeed > 0.05 then rawSpeed else 1.2,
							BaseBrightness = child.Brightness,
							BaseLightEmission = child.LightEmission,
							DirSign = dirSign,
						})
					elseif child:IsA("Texture") then
						local dirU, dirV = textureScrollDirsTowardNorth(inst, child.Face)
						table.insert(texList, {
							Texture = child,
							DirU = dirU,
							DirV = dirV,
							BaseOffsetU = child.OffsetStudsU,
							BaseOffsetV = child.OffsetStudsV,
							OffsetU = child.OffsetStudsU,
							OffsetV = child.OffsetStudsV,
							BaseTransparency = child.Transparency,
						})
					end
				end
				if #beamList > 0 or #texList > 0 or lightInst then
					table.insert(undertows, {
						Part = inst,
						BaseColor = inst.Color,
						Light = lightInst,
						BaseLightBrightness = if lightInst then lightInst.Brightness else 0,
						Beams = beamList,
						Textures = texList,
					})
				end
			end
		end
	end

	-- 2. DirgeWardlight: Model or BasePart with optional PointLight and bone-white Neon flame
	for _, inst in CollectionService:GetTagged("DirgeWardlight") do
		if #wardlights >= MAX_WARDLIGHTS then
			break
		end
		local pos = instancePosition(inst)
		if pos and inFloor(pos) then
			if inst:IsA("Model") then
				local lightInst = inst:FindFirstChildWhichIsA("PointLight", true)
				local flamePart: BasePart? = nil
				for _, d in inst:GetDescendants() do
					if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
						flamePart = d
						break
					end
				end
				local baseCF = inst:GetPivot()
				table.insert(wardlights, {
					TargetModel = if canSway(inst) then inst else nil,
					TargetPart = nil,
					BaseCFrame = baseCF,
					Light = lightInst,
					BaseBrightness = if lightInst then lightInst.Brightness else 1,
					FlamePart = flamePart,
					BaseFlameColor = if flamePart then flamePart.Color else WARDLIGHT_PEAK_COLOR,
					PhaseOffset = (pos.X * 0.13 + pos.Z * 0.17) % (math.pi * 2),
				})
			elseif inst:IsA("BasePart") then
				local lightInst = inst:FindFirstChildWhichIsA("PointLight", true)
				local flamePart: BasePart? = if inst.Material == Enum.Material.Neon then inst else nil
				table.insert(wardlights, {
					TargetModel = nil,
					TargetPart = if canSway(inst) then inst else nil,
					BaseCFrame = inst.CFrame,
					Light = lightInst,
					BaseBrightness = if lightInst then lightInst.Brightness else 1,
					FlamePart = flamePart,
					BaseFlameColor = if flamePart then flamePart.Color else WARDLIGHT_PEAK_COLOR,
					PhaseOffset = (pos.X * 0.13 + pos.Z * 0.17) % (math.pi * 2),
				})
			end
		end
	end

	-- 3. DirgeChain: non-colliding dressing Model or BasePart
	for _, inst in CollectionService:GetTagged("DirgeChain") do
		if #chains >= MAX_CHAINS then
			break
		end
		local pos = instancePosition(inst)
		if pos and inFloor(pos) then
			if inst:IsA("Model") and canSway(inst) then
				table.insert(chains, {
					TargetModel = inst,
					TargetPart = nil,
					BaseCFrame = inst:GetPivot(),
					PhaseOffset = (pos.X * 0.11 + pos.Z * 0.19) % (math.pi * 2),
				})
			elseif inst:IsA("BasePart") and canSway(inst) then
				table.insert(chains, {
					TargetModel = nil,
					TargetPart = inst,
					BaseCFrame = inst.CFrame,
					PhaseOffset = (pos.X * 0.11 + pos.Z * 0.19) % (math.pi * 2),
				})
			end
		end
	end

	-- 4. DirgeAshEmitter: ParticleEmitter or BasePart/Attachment hosting ParticleEmitter
	for _, inst in CollectionService:GetTagged("DirgeAshEmitter") do
		if #emitters >= MAX_EMITTERS then
			break
		end
		local pos = instancePosition(inst)
		if pos and inFloor(pos) then
			local pe: ParticleEmitter? = nil
			if inst:IsA("ParticleEmitter") then
				pe = inst
			elseif inst:IsA("BasePart") or inst:IsA("Attachment") then
				pe = inst:FindFirstChildWhichIsA("ParticleEmitter", true)
			end
			if pe then
				table.insert(emitters, {
					Emitter = pe,
					BaseRate = pe.Rate,
					BaseAccel = pe.Acceleration,
				})
			end
		end
	end

	-- 5. DirgeSilhouette: far-ledge court silhouettes that bow toward -Z on the toll
	for _, inst in CollectionService:GetTagged("DirgeSilhouette") do
		if #silhouettes >= MAX_SILHOUETTES then
			break
		end
		local pos = instancePosition(inst)
		if pos and inFloor(pos) and canSway(inst) then
			if inst:IsA("Model") then
				table.insert(silhouettes, {
					TargetModel = inst,
					TargetPart = nil,
					BaseCFrame = inst:GetPivot(),
				})
			elseif inst:IsA("BasePart") then
				table.insert(silhouettes, {
					TargetModel = nil,
					TargetPart = inst,
					BaseCFrame = inst.CFrame,
				})
			end
		end
	end

	-- 6. DirgeHeartbeat (Floor 50 only): Crimson Eclipse & Throne heart-crack
	if floorId == 50 then
		for _, inst in CollectionService:GetTagged("DirgeHeartbeat") do
			if #heartbeats >= MAX_HEARTBEATS then
				break
			end
			local pos = instancePosition(inst)
			if pos and inFloor(pos) then
				local partsList: { HeartbeatPartEntry } = {}
				local lightInst = inst:FindFirstChildWhichIsA("PointLight", true)
				if inst:IsA("BasePart") then
					table.insert(partsList, { Part = inst, BaseColor = inst.Color })
				elseif inst:IsA("Model") then
					for _, d in inst:GetDescendants() do
						if d:IsA("BasePart") and (d.Material == Enum.Material.Neon or string.find(d.Name, "Heart") or string.find(d.Name, "Eclipse") or string.find(d.Name, "Crack")) then
							table.insert(partsList, { Part = d, BaseColor = d.Color })
						end
					end
					if #partsList == 0 then
						local firstPart = inst:FindFirstChildWhichIsA("BasePart", true)
						if firstPart then
							table.insert(partsList, { Part = firstPart, BaseColor = firstPart.Color })
						end
					end
				end
				if #partsList > 0 or lightInst then
					table.insert(heartbeats, {
						Parts = partsList,
						Light = lightInst,
						BaseBrightness = if lightInst then lightInst.Brightness else 1,
						BaseLightColor = if lightInst then lightInst.Color else HEARTBEAT_REST_COLOR,
					})
				end
			end
		end
	end
end

local function computeTollPulse(elapsed: number): number
	if elapsed < 0.25 then
		return smoothstep01(elapsed / 0.25)
	elseif elapsed < 2.65 then
		local decay = (elapsed - 0.25) / 2.40
		return 0.5 * (1 + math.cos(math.pi * decay))
	end
	return 0
end

local function computeBowEnvelope(elapsed: number): number
	if elapsed < 0.75 then
		return smoothstep01(elapsed / 0.75)
	elseif elapsed < 2.85 then
		return 1 - smoothstep01((elapsed - 0.75) / 2.10)
	end
	return 0
end

local function computeDoubleHeartbeat(elapsed: number): number
	if elapsed < 0.50 or elapsed > 1.30 then
		return 0
	end
	-- Lub-dub (~0.55 s after toll, second beat ~0.25 s later)
	local lub = math.exp(-((elapsed - 0.63) / 0.085) ^ 2)
	local dub = 0.85 * math.exp(-((elapsed - 0.88) / 0.075) ^ 2)
	return math.clamp(math.max(lub, dub), 0, 1)
end

local function step(dt: number)
	local floorId = currentPlayerFloor()
	if floorId ~= activeFloor then
		activeFloor = floorId
		if floorId then
			local period = Dirge.CycleSeconds[floorId] or 16.0
			local serverNow = workspace:GetServerTimeNow()
			local currentCycle = math.floor(serverNow / period)
			local elapsed = serverNow % period
			-- Align to the shared server toll unless we entered right as a toll began
			lastCycleIndex = if elapsed < 0.35 then currentCycle - 1 else currentCycle
			lastHeartbeatCycleIndex = if floorId == 50 and elapsed < 0.55 then currentCycle - 1 else currentCycle

			setVaultSky(true)
			scanFloor(floorId)
			lastScan = os.clock()
		else
			lastCycleIndex = -1
			lastHeartbeatCycleIndex = -1
			setVaultSky(false)
			clearState()
		end
	end
	if not floorId then
		return
	end

	local nowClock = os.clock()
	if nowClock - lastScan >= RESCAN_INTERVAL and #undertows == 0 and #wardlights == 0 then
		scanFloor(floorId)
		lastScan = nowClock
	end

	local period = Dirge.CycleSeconds[floorId] or 16.0
	local serverNow = workspace:GetServerTimeNow()
	local cycleIndex = math.floor(serverNow / period)
	local elapsed = serverNow % period
	local tollPulse = computeTollPulse(elapsed)
	local lowQ = isLowQuality()

	-- 1. Far iron bell toll once per cycle (runs at all Graphics qualities)
	if cycleIndex ~= lastCycleIndex then
		lastCycleIndex = cycleIndex
		ensureAudio()
		if bellSound then
			bellSound.PlaybackSpeed = 0.50 - (floorId - 46) * 0.025
			pcall(function()
				bellSound:Play()
			end)
		end
	end

	-- 2. Undertow continuous uphill scroll toward -Z + surge on toll (runs at all Graphics qualities)
	local clampedDt = math.min(dt, 0.1)
	local speedMult = 1 + 1.65 * tollPulse
	for _, u in undertows do
		if u.Part and u.Part.Parent then
			u.Part.Color = u.BaseColor:Lerp(UNDERTOW_PEAK_COLOR, tollPulse * 0.45)
		end
		if u.Light and u.Light.Parent then
			u.Light.Brightness = u.BaseLightBrightness * (1 + 0.65 * tollPulse)
		end
		for _, b in u.Beams do
			if b.Beam.Parent then
				b.Beam.TextureSpeed = b.DirSign * b.BaseSpeed * speedMult
				b.Beam.Brightness = b.BaseBrightness * (1 + 0.90 * tollPulse)
				b.Beam.LightEmission = math.clamp(b.BaseLightEmission + 0.25 * tollPulse, 0, 1)
			end
		end
		for _, t in u.Textures do
			local tex = t.Texture
			if tex.Parent then
				local stepStuds = clampedDt * 2.4 * speedMult
				local tileU = math.max(tex.StudsPerTileU, 0.1)
				local tileV = math.max(tex.StudsPerTileV, 0.1)
				t.OffsetU = (t.OffsetU + t.DirU * stepStuds) % tileU
				t.OffsetV = (t.OffsetV + t.DirV * stepStuds) % tileV
				tex.OffsetStudsU = t.OffsetU
				tex.OffsetStudsV = t.OffsetV
				tex.Transparency = math.clamp(t.BaseTransparency - 0.12 * tollPulse, 0, 1)
			end
		end
	end

	if lowQ then
		if not lowQRestored then
			restoreQualityScaledEffects()
			lowQRestored = true
		end
		for _, e in emitters do
			if e.Emitter.Parent then
				e.Emitter.Rate = math.min(e.BaseRate, 1)
				e.Emitter.Acceleration = e.BaseAccel
			end
		end
		return
	end
	lowQRestored = false

	-- 3. Wardlights: bone-white flare & gentle lean toward -Z (the Throne) on toll, then settle
	for _, w in wardlights do
		local flicker = 1 + 0.08 * math.sin(serverNow * 7.5 + w.PhaseOffset) * tollPulse
		local leanAngle = math.rad(6.0) * tollPulse + math.rad(0.75) * math.sin(serverNow * 6.5 + w.PhaseOffset) * tollPulse
		local tiltedCF = CFrame.new(w.BaseCFrame.Position) * CFrame.Angles(-leanAngle, 0, 0) * w.BaseCFrame.Rotation
		if w.TargetModel and w.TargetModel.Parent then
			w.TargetModel:PivotTo(tiltedCF)
		elseif w.TargetPart and w.TargetPart.Parent then
			w.TargetPart.CFrame = tiltedCF
		end
		if w.Light and w.Light.Parent then
			w.Light.Brightness = w.BaseBrightness * (1 + 0.35 * tollPulse) * flicker
		end
		if w.FlamePart and w.FlamePart.Parent then
			w.FlamePart.Color = w.BaseFlameColor:Lerp(WARDLIGHT_PEAK_COLOR, tollPulse * 0.65)
		end
	end

	-- 4. Chains: dressing draws taut slightly on the toll and slackens smoothly afterwards
	for _, c in chains do
		local lift = 0.35 * tollPulse
		local pullZ = -0.25 * tollPulse
		local tautPitch = -math.rad(1.6) * tollPulse
		local slackSway = (1 - tollPulse) * math.sin(serverNow * 1.4 + c.PhaseOffset) * math.rad(1.2)
		local targetCF = CFrame.new(c.BaseCFrame.Position + Vector3.new(0, lift, pullZ))
			* CFrame.Angles(tautPitch, 0, slackSway)
			* c.BaseCFrame.Rotation
		if c.TargetModel and c.TargetModel.Parent then
			c.TargetModel:PivotTo(targetCF)
		elseif c.TargetPart and c.TargetPart.Parent then
			c.TargetPart.CFrame = targetCF
		end
	end

	-- 5. Ash emitters: lift rate and -Z acceleration briefly on the toll, then settle
	for _, e in emitters do
		if e.Emitter.Parent then
			e.Emitter.Rate = e.BaseRate * (1 + 1.15 * tollPulse)
			e.Emitter.Acceleration = e.BaseAccel + Vector3.new(0, 2.6 * tollPulse, -5.5 * tollPulse)
		end
	end

	-- 6. Silhouettes: distant court figures stay still until toll, then bow smoothly toward -Z and rise back
	local bowT = computeBowEnvelope(elapsed)
	if bowT > 0 or elapsed < 3.0 then
		local bowAngle = math.rad(26) * bowT
		for _, s in silhouettes do
			local bowedCF = CFrame.new(s.BaseCFrame.Position) * CFrame.Angles(-bowAngle, 0, 0) * s.BaseCFrame.Rotation
			if s.TargetModel and s.TargetModel.Parent then
				s.TargetModel:PivotTo(bowedCF)
			elseif s.TargetPart and s.TargetPart.Parent then
				s.TargetPart.CFrame = bowedCF
			end
		end
	end

	-- 7. Floor 50 double heartbeat (~0.55 s after each toll) in deep matte red-black + low heartbeat sound
	if floorId == 50 then
		if cycleIndex ~= lastHeartbeatCycleIndex and elapsed >= 0.55 then
			lastHeartbeatCycleIndex = cycleIndex
			ensureAudio()
			if heartbeatSound then
				pcall(function()
					heartbeatSound:Play()
				end)
			end
		end
		local beatPulse = computeDoubleHeartbeat(elapsed)
		local beatColor = HEARTBEAT_REST_COLOR:Lerp(HEARTBEAT_PEAK_COLOR, beatPulse)
		for _, hb in heartbeats do
			for _, p in hb.Parts do
				if p.Part.Parent then
					p.Part.Color = beatColor
				end
			end
			if hb.Light and hb.Light.Parent then
				hb.Light.Color = beatColor
				hb.Light.Brightness = hb.BaseBrightness * (0.75 + 0.75 * beatPulse)
			end
		end
	end

	-- 8. Dedicated subtle bloom nudge (+0.05..0.08 on toll, never a screen flash)
	local b = ensureBloom()
	local peakBloom = 0.05 + (floorId - 46) * 0.0075
	local intensity = peakBloom * tollPulse
	b.Enabled = intensity > 0.004
	b.Intensity = intensity
end

function Dirge.Start()
	if started then
		return
	end
	started = true
	RunService.RenderStepped:Connect(step)
end

return Dirge
