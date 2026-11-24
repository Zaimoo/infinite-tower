--!strict
-- Client-side cosmetic animator for Sunken Sanctuary Floor 40 (Leviathan's Basin):
--   * Smoothly rotates the 3-layer Maelstrom Vortex rings & swirling debris ("SunkenMaelstromRing")
--     around their drain pivots with gentle vertical wave bobbing, synchronized via GetServerTimeNow().
--   * Orbits the far-layer Sea-Dome ocean silhouettes ("SunkenDomeSwimmer": Tidal Leviathan shadow,
--     whales, mantas, sharks) high overhead outside the dome glass.
--   * Quality-scales and distance-culls the maelstrom eye spray & bubble emitters ("MaelstromSprayEmitter").
-- Zero server replication, zero gameplay or collision effect, and completely dormant off Floor 40.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local RING_TAG = "SunkenMaelstromRing"
local SWIMMER_TAG = "SunkenDomeSwimmer"
local SPRAY_TAG = "MaelstromSprayEmitter"
local ACTIVE_DISTANCE = 1150

type RingState = {
	Model: Model,
	BaseCF: CFrame,
	Speed: number,
	BobAmp: number,
	BobFreq: number,
	Phase: number,
}

type SwimmerState = {
	Model: Model,
	CenterX: number,
	CenterZ: number,
	Radius: number,
	OrbitY: number,
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

local function registerRing(inst: Instance)
	if not inst:IsA("Model") or rings[inst] then
		return
	end
	-- Wait briefly for PrimaryPart/children replication if the room just streamed in
	local pivotCF = if inst.PrimaryPart then inst.PrimaryPart.CFrame else inst:GetPivot()
	rings[inst] = {
		Model = inst,
		BaseCF = pivotCF,
		Speed = (inst:GetAttribute("MaelstromSpinSpeed") :: number?) or 0.28,
		BobAmp = (inst:GetAttribute("MaelstromBobAmp") :: number?) or 0.38,
		BobFreq = (inst:GetAttribute("MaelstromBobFreq") :: number?) or 1.1,
		Phase = (inst:GetAttribute("MaelstromBobPhase") :: number?) or 0,
	}
end

local function unregisterRing(inst: Instance)
	if inst:IsA("Model") then
		rings[inst] = nil
	end
end

local function registerSwimmer(inst: Instance)
	if not inst:IsA("Model") or swimmers[inst] then
		return
	end
	local cx = inst:GetAttribute("DomeCenterX") :: number?
	local cz = inst:GetAttribute("DomeCenterZ") :: number?
	local rad = inst:GetAttribute("DomeOrbitRadius") :: number?
	local oy = inst:GetAttribute("DomeOrbitY") :: number?
	if not (cx and cz and rad and oy) then
		return
	end
	swimmers[inst] = {
		Model = inst,
		CenterX = cx,
		CenterZ = cz,
		Radius = rad,
		OrbitY = oy,
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
			rings[model] = nil
			continue
		end
		if (st.BaseCF.Position - camPos).Magnitude <= ACTIVE_DISTANCE then
			local spinAngle = -t * st.Speed
			local bobY = math.sin(t * st.BobFreq + st.Phase) * st.BobAmp
			model:PivotTo(st.BaseCF * CFrame.new(0, bobY, 0) * CFrame.Angles(0, spinAngle, 0))
		end
	end

	-- 2. Glide Sea-Dome Leviathan shadow & whale/manta/shark silhouettes overhead
	for model, sw in swimmers do
		if not model.Parent then
			swimmers[model] = nil
			continue
		end
		local center = Vector3.new(sw.CenterX, sw.OrbitY, sw.CenterZ)
		if (center - camPos).Magnitude <= ACTIVE_DISTANCE then
			local ang = sw.Phase + t * sw.Speed
			local nextAng = ang + (if sw.Speed >= 0 then 0.04 else -0.04)
			local bob = math.sin(t * 0.45 + sw.Phase) * 4.5
			local pos = Vector3.new(sw.CenterX + math.cos(ang) * sw.Radius, sw.OrbitY + bob, sw.CenterZ + math.sin(ang) * sw.Radius)
			local ahead = Vector3.new(sw.CenterX + math.cos(nextAng) * sw.Radius, sw.OrbitY + bob, sw.CenterZ + math.sin(nextAng) * sw.Radius)
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
