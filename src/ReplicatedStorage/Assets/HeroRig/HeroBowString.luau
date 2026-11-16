--!strict
-- ReplicatedStorage/Assets/HeroRig/HeroBowString.luau
-- The live bowstring and nocked arrow of an equipped bow (docs/hero-creation-pipeline.md §7).
--
-- Every bow prefab carries a straight BowString part, a HunterArrow sub-model welded to the
-- handle, a Nock attachment (the arrow's tail on the string) and TipUpper / TipLower (where the
-- string meets the limbs). HeroAnimator pulls the draw hand back along the arrow line while an
-- attack draws (SolveBowDraw); this module makes the bow follow that hand:
--   * while the hand holds the string, the string is drawn as two beams from the limb tips to
--     the hand (the straight BowString part is hidden), and the arrow rides on it: its tail on
--     the string, its shaft through the arrow rest on the riser;
--   * when the string is let go it snaps forward through rest and shivers out (a damped
--     oscillation along the arrow line), then the straight BowString part comes back.
--
-- Geometry is read once per equipped weapon, in the handle's space, so it holds for every
-- prefab (mesh bows, the code-built weapon_bow, Gilded Anvil bows) whatever their frame.

local HeroBowString = {}

export type Geometry = {
	Handle: BasePart,
	Arrow: Model?,
	StringParts: { BasePart },
	NockH: Vector3, -- the arrow's tail at rest
	StringRestH: Vector3, -- the point of the resting string nearest the nock
	ArrowH: Vector3, -- unit, the way the arrow flies
	RestH: Vector3, -- where the shaft crosses the riser (the arrow rest)
	TipUpperH: Vector3,
	TipLowerH: Vector3,
	MaxPull: number, -- deepest draw, studs behind the resting string
	Width: number,
	Color: Color3,
	Glow: boolean,
}

type State = {
	Geometry: Geometry,
	Top: Attachment?,
	Bottom: Attachment?,
	Nock: Attachment?,
	Beams: { Beam },
	ArrowRoot: BasePart?,
	ArrowWeld: Weld?,
	ArrowRest: CFrame,
	Held: boolean,
	HeldSince: number,
	Pull: number,
	VibStart: number?,
	VibAmp: number,
	Shown: boolean, -- beams on, straight string hidden
}

-- How the released string settles: one swing every 1/VIB_HZ s, decaying with VIB_DECAY s.
local VIB_HZ = 13
local VIB_DECAY = 0.06
local VIB_SECONDS = 0.35
-- Draws deeper than this many half-lengths of the bow are cut short (stylised, not physical).
local MAX_PULL_RATIO = 1.6
-- The hand's sideways offset from the string fades in over this much draw, so the string does
-- not jump sideways the moment the hand takes it.
local LATERAL_BLEND = 0.3
-- When the hand takes the string short of where it rests (out of reach, or mid-blend), the
-- string slides to the hand over this long instead of jumping.
local GRAB_SECONDS = 0.08
-- A hand further than this from the arrow line is not on the string (an interrupted or odd
-- pose): the string stays where it is.
local MAX_HAND_OFFSET = 0.8

local geometryCache: { [Instance]: Geometry | false } = setmetatable({}, { __mode = "k" }) :: any
local states: { [Instance]: State } = setmetatable({}, { __mode = "k" }) :: any

local function attachmentPos(handle: BasePart, root: Instance, names: { string }): Vector3?
	for _, name in names do
		local a = root:FindFirstChild(name, true)
		if a and a:IsA("Attachment") then
			return handle.CFrame:PointToObjectSpace(a.WorldPosition)
		end
	end
	return nil
end

local function isArrowPart(arrow: Instance?, part: Instance?): boolean
	return arrow ~= nil and part ~= nil and part:IsDescendantOf(arrow)
end

-- The bow's string and arrow geometry in handle space, or nil for a weapon that is not a bow.
function HeroBowString.Geometry(weapon: Instance?): Geometry?
	if not weapon or not weapon:IsA("Model") then
		return nil
	end
	local cached = geometryCache[weapon]
	if cached ~= nil then
		return if cached then cached else nil
	end
	local handle = weapon.PrimaryPart
	local nockH = handle and attachmentPos(handle, weapon, { "Nock" })
	if not handle or not nockH then
		geometryCache[weapon] = false
		return nil
	end

	local stringParts: { BasePart } = {}
	for _, d in weapon:GetDescendants() do
		if d:IsA("BasePart") and string.find(string.lower(d.Name), "string", 1, true) then
			table.insert(stringParts, d)
		end
	end
	local tipU = attachmentPos(handle, weapon, { "TipUpper", "BowStringTop" })
	local tipL = attachmentPos(handle, weapon, { "TipLower", "BowStringBottom" })
	local main = stringParts[1]
	if (not tipU or not tipL) and main then
		local size = main.Size
		local axis = if size.Y >= size.X and size.Y >= size.Z then Vector3.yAxis elseif size.X >= size.Z then Vector3.xAxis else Vector3.zAxis
		local half = axis * math.max(size.X, size.Y, size.Z) / 2
		tipU = handle.CFrame:PointToObjectSpace(main.CFrame * half)
		tipL = handle.CFrame:PointToObjectSpace(main.CFrame * -half)
		if (tipU :: Vector3).Y < (tipL :: Vector3).Y then
			tipU, tipL = tipL, tipU
		end
	end
	if not tipU or not tipL or (tipU - tipL).Magnitude < 0.2 then
		geometryCache[weapon] = false
		return nil
	end

	local along = (tipU - tipL).Unit
	local stringRest = tipL + along * (nockH - tipL):Dot(along)
	local gripH = attachmentPos(handle, weapon, { "Grip" }) or Vector3.zero

	-- The arrow flies from the nock towards its head; without a head, square off the string
	-- towards the grip.
	local arrow = weapon:FindFirstChild("HunterArrow", true)
	local arrowModel: Model? = if arrow and arrow:IsA("Model") then arrow else nil
	local arrowH: Vector3? = nil
	local head = arrowModel and arrowModel:FindFirstChild("ArrowHead", true)
	if head and head:IsA("BasePart") then
		local d = handle.CFrame:PointToObjectSpace(head.Position) - nockH
		if d.Magnitude > 0.1 then
			arrowH = d.Unit
		end
	end
	if not arrowH then
		local d = gripH - stringRest
		d -= along * d:Dot(along)
		arrowH = if d.Magnitude > 1e-3 then d.Unit else Vector3.zAxis
	end
	local a = arrowH :: Vector3

	local width, color, glow = 0.04, Color3.fromRGB(230, 225, 210), false
	if main then
		local s = main.Size
		width = math.clamp(math.min(s.X, s.Y, s.Z), 0.035, 0.12)
		color = main.Color
		glow = main.Material == Enum.Material.Neon
	end

	local geometry: Geometry = {
		Handle = handle,
		Arrow = arrowModel,
		StringParts = stringParts,
		NockH = nockH,
		StringRestH = stringRest,
		ArrowH = a,
		RestH = nockH + a * (gripH - nockH):Dot(a),
		TipUpperH = tipU,
		TipLowerH = tipL,
		MaxPull = MAX_PULL_RATIO * (tipU - tipL).Magnitude / 2,
		Width = width,
		Color = color,
		Glow = glow,
	}
	geometryCache[weapon] = geometry
	return geometry
end

-- Re-hangs the arrow on one Weld from the handle (its other parts welded to its root), so its
-- C0 can carry the arrow along the drawn string. Parts are at rest here, so offsets hold.
local function hangArrow(state: State, weapon: Instance)
	local g = state.Geometry
	local arrow = g.Arrow
	if not arrow then
		return
	end
	local parts: { BasePart } = {}
	for _, d in arrow:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	local root = arrow.PrimaryPart or arrow:FindFirstChild("ArrowShaft") or parts[1]
	if not root or not root:IsA("BasePart") then
		return
	end
	for _, d in weapon:GetDescendants() do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			local p0, p1 = (d :: any).Part0, (d :: any).Part1
			if isArrowPart(arrow, p0) or isArrowPart(arrow, p1) then
				d:Destroy()
			end
		end
	end
	for _, part in parts do
		if part ~= root then
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = part
			w.Parent = part
		end
	end
	local rest = g.Handle.CFrame:ToObjectSpace(root.CFrame)
	local weld = Instance.new("Weld")
	weld.Name = "BowArrowWeld"
	weld.Part0 = g.Handle
	weld.Part1 = root
	weld.C0 = rest
	weld.Parent = root
	state.ArrowRoot, state.ArrowWeld, state.ArrowRest = root, weld, rest
end

local function newAttachment(handle: BasePart, name: string, position: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = position
	a.Parent = handle
	return a
end

local function newBeam(handle: BasePart, a0: Attachment, a1: Attachment, g: Geometry): Beam
	local b = Instance.new("Beam")
	b.Name = "BowStringBeam"
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Width0 = g.Width
	b.Width1 = g.Width
	b.Segments = 1
	b.FaceCamera = true
	b.Color = ColorSequence.new(g.Color)
	b.Transparency = NumberSequence.new(0)
	b.LightEmission = if g.Glow then 1 else 0
	b.LightInfluence = if g.Glow then 0 else 1
	b.Enabled = false
	b.Parent = handle
	return b
end

local function bind(weapon: Instance): State?
	local existing = states[weapon]
	if existing then
		return existing
	end
	local g = HeroBowString.Geometry(weapon)
	if not g then
		return nil
	end
	local state: State = {
		Geometry = g,
		Beams = {},
		ArrowRest = CFrame.identity,
		Held = false,
		HeldSince = 0,
		Pull = 0,
		VibStart = nil,
		VibAmp = 0,
		Shown = false,
	}
	hangArrow(state, weapon)
	local top = newAttachment(g.Handle, "BowStringTopLive", g.TipUpperH)
	local bottom = newAttachment(g.Handle, "BowStringBottomLive", g.TipLowerH)
	local nock = newAttachment(g.Handle, "BowStringNockLive", g.StringRestH)
	state.Top, state.Bottom, state.Nock = top, bottom, nock
	state.Beams = { newBeam(g.Handle, top, nock, g), newBeam(g.Handle, nock, bottom, g) }
	states[weapon] = state
	return state
end

-- Rotation taking unit vector a onto unit vector b by the shortest way.
local function rotationBetween(a: Vector3, b: Vector3): CFrame
	local axis = a:Cross(b)
	local dot = math.clamp(a:Dot(b), -1, 1)
	if axis.Magnitude < 1e-6 then
		return CFrame.identity
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(dot))
end

-- Where the string is held this frame (handle space), from the draw hand's grip attachment.
local function heldPoint(g: Geometry, hand: Vector3): (Vector3, number)
	local along = (g.StringRestH - hand):Dot(g.ArrowH) -- studs behind the resting string
	if along <= 0 then
		return g.StringRestH, 0
	end
	local pull = math.min(along, g.MaxPull)
	local onLine = g.StringRestH - g.ArrowH * pull
	local lateral = hand - (g.StringRestH - g.ArrowH * along)
	if lateral.Magnitude > MAX_HAND_OFFSET then
		return g.StringRestH, 0
	end
	return onLine + lateral * math.clamp(along / LATERAL_BLEND, 0, 1), pull
end

-- Moves the string and arrow of the rig's equipped bow for this frame. `held`: the draw hand
-- holds the string (HeroAnimator.BowHeld); `now`: a clock in seconds.
function HeroBowString.Step(rig: Model, weapon: Instance?, held: boolean, now: number)
	if not weapon then
		return
	end
	local state = bind(weapon)
	if not state then
		return
	end
	local g = state.Geometry
	local handle = g.Handle

	local point = g.StringRestH
	if held then
		if not state.Held then
			state.HeldSince = now
		end
		local hand = rig:FindFirstChild("RightHand")
		local grip = hand and hand:FindFirstChild("RightGripAttachment")
		if grip and grip:IsA("Attachment") then
			local pull
			point, pull = heldPoint(g, handle.CFrame:PointToObjectSpace(grip.WorldPosition))
			local x = math.clamp((now - state.HeldSince) / GRAB_SECONDS, 0, 1)
			local ease = x * x * (3 - 2 * x)
			point = g.StringRestH:Lerp(point, ease)
			state.Pull = pull * ease
		end
		state.VibStart = nil
	elseif state.Held then
		-- Let go: the string snaps forward through rest and shivers out.
		if state.Pull > 0.05 then
			state.VibStart, state.VibAmp = now, state.Pull
		end
		state.Pull = 0
	end
	state.Held = held
	local vibStart = state.VibStart
	if not held and vibStart then
		local t = now - vibStart
		if t < 0 or t >= VIB_SECONDS then
			state.VibStart = nil
		else
			local x = state.VibAmp * math.exp(-t / VIB_DECAY) * math.cos(2 * math.pi * VIB_HZ * t)
			point = g.StringRestH - g.ArrowH * x
		end
	end

	local displaced = (point - g.StringRestH).Magnitude > 0.02
	if displaced ~= state.Shown then
		state.Shown = displaced
		for _, beam in state.Beams do
			beam.Enabled = displaced
		end
		for _, part in g.StringParts do
			part.LocalTransparencyModifier = if displaced then 1 else 0
		end
	end
	if displaced then
		(state.Nock :: Attachment).Position = point
		-- The beams follow the bow's own visibility (a hidden or fading hero).
		local hidden = math.max(handle.Transparency, handle.LocalTransparencyModifier)
		local seq = NumberSequence.new(hidden)
		for _, beam in state.Beams do
			beam.Transparency = seq
		end
	end

	-- The arrow's tail rides the string (keeping its sideways offset from it); the shaft runs
	-- through the arrow rest.
	local weld = state.ArrowWeld
	if weld then
		if (point - g.StringRestH).Magnitude > 0.005 then
			local tail = point + (g.NockH - g.StringRestH)
			local dir = g.RestH - tail
			local rot = if dir.Magnitude > 1e-3 then rotationBetween(g.ArrowH, dir.Unit) else CFrame.identity
			weld.C0 = CFrame.new(tail) * rot * CFrame.new(-g.NockH) * state.ArrowRest
		elseif weld.C0 ~= state.ArrowRest then
			weld.C0 = state.ArrowRest
		end
	end
end

-- Test hook: the held point for a hand position, in handle space.
HeroBowString._heldPoint = heldPoint

return HeroBowString
