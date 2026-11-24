--!strict
-- Client-side cosmetic animator for Sunken Sanctuary Floor 40 (Leviathan's Basin):
--   * Smoothly rotates the 3-layer Maelstrom Vortex rings & swirling debris ("SunkenMaelstromRing")
--     around their drain pivots with gentle vertical wave bobbing, synchronized via GetServerTimeNow().
--   * Orbits the far-layer Sea-Dome ocean silhouettes ("SunkenDomeSwimmer": Tidal Leviathan shadow,
--     whales, mantas, sharks) high overhead outside the dome glass.
--   * Quality-scales and distance-culls the maelstrom eye spray & bubble emitters ("MaelstromSprayEmitter").
-- Replication-safe: reads atomic BasePos/BaseYaw attributes and captures every descendant BasePart's
-- relative offset via DescendantAdded so streaming order never freezes BaseCF at the world origin.
-- Zero server replication, zero gameplay or collision effect, and completely dormant off Floor 40.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local RING_TAG = "SunkenMaelstromRing"
local SWIMMER_TAG = "SunkenDomeSwimmer"
local SPRAY_TAG = "MaelstromSprayEmitter"
local ACTIVE_DISTANCE = 1400

type RingState = {
	Model: Model,
	BaseCF: CFrame?,
	Speed: number,
	BobAmp: number,
	BobFreq: number,
	Phase: number,
	Parts: { [BasePart]: CFrame },
	Conn: RBXScriptConnection,
}

type SwimmerState = {
	Model: Model,
	CenterX: number?,
	CenterZ: number?,
	Radius: number?,
	OrbitY: number?,
	Speed: number,
	Phase: number,
}

local rings: { [Model]: RingState } = {}
local swimmers: { [Model]: SwimmerState } = {}
local emitters: { [ParticleEmitter]: number } = {}

local function qualityScale(): number
	local ok, lvl = pcall(function()
		return UserSettings().GameSettings.SavedQualityLevel
	end)
	if not ok then
		return 1.0
	end
	if lvl == Enum.SavedQualitySetting.Automatic then
		return 1.0
	end
	local v = lvl.Value
	if v <= 3 then
		return 0.35
	elseif v <= 6 then
		return 0.65
	end
	return 1.0
end

local function resolveRingBase(model: Model): CFrame?
	local basePos = model:GetAttribute("MaelstromBasePos")
	if typeof(basePos) == "Vector3" then
		local baseYaw = (model:GetAttribute("MaelstromBaseYaw") :: number?) or 0
		return CFrame.new(basePos) * CFrame.Angles(0, baseYaw, 0)
	end
	if model.PrimaryPart then
		return model.PrimaryPart.CFrame
	end
	local pivot = model:FindFirstChild("VortexPivot") or model:FindFirstChild("DebrisPivot")
	if pivot and pivot:IsA("BasePart") then
		return pivot.CFrame
	end
	return nil
end

local function captureRingPart(st: RingState, inst: Instance)
	if not inst:IsA("BasePart") or st.Parts[inst] then
		return
	end
	if inst.Name == "VortexPivot" or inst.Name == "DebrisPivot" then
		return
	end
	if not st.BaseCF then
		st.BaseCF = resolveRingBase(st.Model)
	end
	if st.BaseCF then
		st.Parts[inst] = st.BaseCF:ToObjectSpace(inst.CFrame)
	end
end

local function registerRing(inst: Instance)
	if not inst:IsA("Model") or rings[inst] then
		return
	end
	local st: RingState = {
		Model = inst,
		BaseCF = resolveRingBase(inst),
		Speed = (inst:GetAttribute("MaelstromSpinSpeed") :: number?) or 0.45,
		BobAmp = (inst:GetAttribute("MaelstromBobAmp") :: number?) or 0.55,
		BobFreq = (inst:GetAttribute("MaelstromBobFreq") :: number?) or 1.2,
		Phase = (inst:GetAttribute("MaelstromBobPhase") :: number?) or 0,
		Parts = {},
		Conn = nil :: any,
	}
	for _, d in inst:GetDescendants() do
		captureRingPart(st, d)
	end
	st.Conn = inst.DescendantAdded:Connect(function(d)
		if not st.BaseCF then
			st.BaseCF = resolveRingBase(inst)
			if st.BaseCF then
				for _, existing in inst:GetDescendants() do
					captureRingPart(st, existing)
				end
			end
		end
		captureRingPart(st, d)
	end)
	rings[inst] = st
end

local function unregisterRing(inst: Instance)
	if inst:IsA("Model") then
		local st = rings[inst]
		if st then
			st.Conn:Disconnect()
			rings[inst] = nil
		end
	end
end

local function hydrateRing(st: RingState)
	local model = st.Model
	if not st.BaseCF then
		st.BaseCF = resolveRingBase(model)
	end
	if st.BaseCF then
		local spd = model:GetAttribute("MaelstromSpinSpeed")
		if typeof(spd) == "number" then st.Speed = spd end
		local amp = model:GetAttribute("MaelstromBobAmp")
		if typeof(amp) == "number" then st.BobAmp = amp end
		local frq = model:GetAttribute("MaelstromBobFreq")
		if typeof(frq) == "number" then st.BobFreq = frq end
		local ph = model:GetAttribute("MaelstromBobPhase")
		if typeof(ph) == "number" then st.Phase = ph end
		for _, d in model:GetDescendants() do
			captureRingPart(st, d)
		end
	end
end

local function registerSwimmer(inst: Instance)
	if not inst:IsA("Model") or swimmers[inst] then
		return
	end
	swimmers[inst] = {
		Model = inst,
		CenterX = inst:GetAttribute("DomeCenterX") :: number?,
		CenterZ = inst:GetAttribute("DomeCenterZ") :: number?,
		Radius = inst:GetAttribute("DomeOrbitRadius") :: number?,
		OrbitY = inst:GetAttribute("DomeOrbitY") :: number?,
		Speed = (inst:GetAttribute("DomeOrbitSpeed") :: number?) or 0.08,
		Phase = (inst:GetAttribute("DomeOrbitPhase") :: number?) or 0,
	}
end

local function unregisterSwimmer(inst: Instance)
	if inst:IsA("Model") then
		swimmers[inst] = nil
	end
end

local function registerEmitter(inst: Instance)
	if not inst:IsA("ParticleEmitter") then
		return
	end
	local baseRate = (inst:GetAttribute("BaseRate") :: number?) or inst.Rate
	emitters[inst] = baseRate
end

local function unregisterEmitter(inst: Instance)
	if inst:IsA("ParticleEmitter") then
		emitters[inst] = nil
	end
end

for _, inst in CollectionService:GetTagged(RING_TAG) do
	registerRing(inst)
end
for _, inst in CollectionService:GetTagged(SWIMMER_TAG) do
	registerSwimmer(inst)
end
for _, inst in CollectionService:GetTagged(SPRAY_TAG) do
	registerEmitter(inst)
end

CollectionService:GetInstanceAddedSignal(RING_TAG):Connect(registerRing)
CollectionService:GetInstanceRemovedSignal(RING_TAG):Connect(unregisterRing)
CollectionService:GetInstanceAddedSignal(SWIMMER_TAG):Connect(registerSwimmer)
CollectionService:GetInstanceRemovedSignal(SWIMMER_TAG):Connect(unregisterSwimmer)
CollectionService:GetInstanceAddedSignal(SPRAY_TAG):Connect(registerEmitter)
CollectionService:GetInstanceRemovedSignal(SPRAY_TAG):Connect(unregisterEmitter)

local lastQualityCheck = 0
local cachedQScale = 1.0

RunService.Heartbeat:Connect(function()
	if next(rings) == nil and next(swimmers) == nil and next(emitters) == nil then
		return
	end
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	local t = workspace:GetServerTimeNow()

	-- 1. Rotate concentric maelstrom spiral rings smoothly inward around the drain eye
	for model, st in rings do
		if not model.Parent then
			st.Conn:Disconnect()
			rings[model] = nil
			continue
		end
		if not st.BaseCF or next(st.Parts) == nil then
			hydrateRing(st)
			if not st.BaseCF then
				continue
			end
		end
		local baseCF = st.BaseCF :: CFrame
		if (baseCF.Position - camPos).Magnitude <= ACTIVE_DISTANCE then
			local spinAngle = -t * st.Speed
			local bobY = math.sin(t * st.BobFreq + st.Phase) * st.BobAmp
			local targetCF = baseCF * CFrame.new(0, bobY, 0) * CFrame.Angles(0, spinAngle, 0)
			for part, relCF in st.Parts do
				if part.Parent then
					part.CFrame = targetCF * relCF
				else
					st.Parts[part] = nil
				end
			end
		end
	end

	-- 2. Glide Sea-Dome Leviathan shadow & whale/manta/shark silhouettes overhead
	for model, sw in swimmers do
		if not model.Parent then
			swimmers[model] = nil
			continue
		end
		if not (sw.CenterX and sw.CenterZ and sw.Radius and sw.OrbitY) then
			sw.CenterX = model:GetAttribute("DomeCenterX") :: number?
			sw.CenterZ = model:GetAttribute("DomeCenterZ") :: number?
			sw.Radius = model:GetAttribute("DomeOrbitRadius") :: number?
			sw.OrbitY = model:GetAttribute("DomeOrbitY") :: number?
			local sp = model:GetAttribute("DomeOrbitSpeed")
			if typeof(sp) == "number" then sw.Speed = sp end
			local ph = model:GetAttribute("DomeOrbitPhase")
			if typeof(ph) == "number" then sw.Phase = ph end
			if not (sw.CenterX and sw.CenterZ and sw.Radius and sw.OrbitY) then
				continue
			end
		end
		local cx, cz, rad, oy = sw.CenterX :: number, sw.CenterZ :: number, sw.Radius :: number, sw.OrbitY :: number
		local center = Vector3.new(cx, oy, cz)
		if (center - camPos).Magnitude <= ACTIVE_DISTANCE then
			local ang = sw.Phase + t * sw.Speed
			local nextAng = ang + (if sw.Speed >= 0 then 0.04 else -0.04)
			local bob = math.sin(t * 0.45 + sw.Phase) * 4.5
			local pos = Vector3.new(cx + math.cos(ang) * rad, oy + bob, cz + math.sin(ang) * rad)
			local ahead = Vector3.new(cx + math.cos(nextAng) * rad, oy + bob, cz + math.sin(nextAng) * rad)
			model:PivotTo(CFrame.lookAt(pos, ahead))
		end
	end

	-- 3. Quality-scale & distance-cull maelstrom spray and bubble emitters once per second
	if t - lastQualityCheck >= 1.0 then
		lastQualityCheck = t
		cachedQScale = qualityScale()
		for em, baseRate in emitters do
			if not em.Parent then
				emitters[em] = nil
				continue
			end
			local p = em.Parent
			if p:IsA("BasePart") then
				local inRange = (p.Position - camPos).Magnitude <= ACTIVE_DISTANCE
				em.Enabled = inRange
				if inRange then
					em.Rate = math.max(1, math.round(baseRate * cachedQScale))
				end
			end
		end
	end
end)
