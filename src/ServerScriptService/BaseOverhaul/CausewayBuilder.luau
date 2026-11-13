--!strict
-- CausewayBuilder.luau
-- ModuleScript: builds the Pilgrim's Causeway, the obsidian bridge from the Masters' Commons South Gate
-- up to the tower walkway. Wide black deck with a pulsing crimson rune channel, spiked parapets,
-- fire-crowned pylons joined by arcs of crimson energy, two gothic arches with hanging cages,
-- hooded Warden statues guarding the tower end, and chains and spikes hanging into the void.
-- Parts tagged "CausewayPulse" are animated on the client (CommonsController).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local HubLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("HubLayout"))
local PartKit = require(script.Parent:WaitForChild("PartKit"))
local WallsBuilder = require(script.Parent:WaitForChild("WallsBuilder"))

local CausewayBuilder = {}

local makePart = PartKit.Part
local makeWedge = PartKit.Wedge
local makeCorner = PartKit.CornerWedge

-- Palette
local OBSIDIAN = Color3.fromRGB(22, 16, 20)
local DARK_STONE = Color3.fromRGB(40, 32, 38)
local IRON = Color3.fromRGB(30, 28, 30)
local BLOOD = Color3.fromRGB(110, 12, 22)
local CRIMSON = Color3.fromRGB(145, 28, 38)
local GLOW = Color3.fromRGB(190, 16, 32)
local GLOW_HOT = Color3.fromRGB(255, 40, 60)
local SMOKE_TEXTURE = "rbxassetid://243660364"

local PYLON_T = { 0.3, 0.55, 0.8 } -- Pylon pairs along the deck (0 = tower end, 1 = park end)
local ARCH_T = { 0.3, 0.8 }
local WARDEN_T = 0.09

local function pulse(p: BasePart, phase: number?): BasePart
	CollectionService:AddTag(p, "CausewayPulse")
	p:SetAttribute("PulseBase", p.Transparency)
	if phase then
		p:SetAttribute("PulsePhase", phase)
	end
	return p
end

local function chain(parent: Instance, name: string, top: Vector3, links: number)
	for i = 1, links do
		makePart({
			Name = name,
			Size = Vector3.new(0.35, 1.5, 0.75),
			CFrame = CFrame.new(top - Vector3.new(0, (i - 0.5) * 1.3, 0)) * CFrame.Angles(0, if i % 2 == 0 then math.pi * 0.5 else 0, 0),
			Color = IRON,
			Material = Enum.Material.Metal,
			Decorative = true,
			Parent = parent,
		})
	end
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	for k, v in pairs(props) do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

function CausewayBuilder.Build(parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "PilgrimsCauseway"

	local W = HubLayout.CausewayWidth
	local A = Vector3.new(0, HubLayout.TowerWalkwayY, HubLayout.CausewayTowerZ + 1) -- tower end (deck top)
	local B = Vector3.new(0, HubLayout.IslandSurfaceY, HubLayout.CausewayParkZ() - 2) -- park end (deck top)
	local L = (B - A).Magnitude
	local frame = CFrame.lookAt((A + B) * 0.5, B) -- deck-top frame, -Z toward the park

	-- Sloped deck-local CFrame at fraction t (0 = tower, 1 = park), lateral x, height y
	local function at(t: number, x: number, y: number): CFrame
		return frame * CFrame.new(x, y, (0.5 - t) * L)
	end
	-- Upright (unsloped) CFrame standing on the deck at t, x; -Z faces the park
	local function upright(t: number, x: number, y: number): CFrame
		return CFrame.new(at(t, x, 0).Position + Vector3.new(0, y, 0))
	end

	------------------------------------------------------------------------
	-- Deck, rune channel and parapets
	------------------------------------------------------------------------
	local deck = makePart({ Name = "CausewayDeck", Size = Vector3.new(W, 3, L + 1), CFrame = frame * CFrame.new(0, -1.5, 0), Color = OBSIDIAN, Material = Enum.Material.Basalt, Parent = model })
	model.PrimaryPart = deck
	for _, side in { -1, 1 } do
		makePart({ Name = "EdgeTrim", Size = Vector3.new(1, 0.2, L), CFrame = frame * CFrame.new(side * (W * 0.5 - 2.6), 0.1, 0), Color = CRIMSON, Material = Enum.Material.Granite, Decorative = true, Parent = model })
		makePart({ Name = "ChannelBorder", Size = Vector3.new(0.6, 0.16, L - 2), CFrame = frame * CFrame.new(side * 2.4, 0.08, 0), Color = IRON, Material = Enum.Material.Metal, Decorative = true, Parent = model })
	end
	local channel = makePart({ Name = "RuneChannel", Size = Vector3.new(4, 0.1, L - 2), CFrame = frame * CFrame.new(0, 0.06, 0), Color = GLOW, Material = Enum.Material.Neon, Decorative = true, Parent = model })
	channel.Transparency = 0.15
	pulse(channel)
	local plates = math.floor(L / 8)
	for k = 1, plates do
		local t = k / (plates + 1)
		makePart({ Name = "DeckSeam", Size = Vector3.new(W - 7, 0.08, 0.6), CFrame = at(t, 0, 0.04), Color = DARK_STONE, Material = Enum.Material.Slate, Decorative = true, Parent = model })
	end
	local glyphs = math.floor(L / 12)
	for k = 1, glyphs do
		local t = k / (glyphs + 1)
		local glyph = makePart({ Name = "RuneGlyph", Size = Vector3.new(2.6, 0.12, 2.6), CFrame = at(t, 0, 0.12) * CFrame.Angles(0, math.rad(45), 0), Color = GLOW_HOT, Material = Enum.Material.Neon, Decorative = true, Parent = model })
		pulse(glyph, t * 6)
	end

	local walls = Instance.new("Folder")
	walls.Name = "Parapets"
	walls.Parent = model
	for _, side in { -1, 1 } do
		local x = side * (W * 0.5 - 1)
		makePart({ Name = "Parapet", Size = Vector3.new(2, 3.5, L), CFrame = frame * CFrame.new(x, 1.75, 0), Color = OBSIDIAN, Material = Enum.Material.Basalt, Parent = walls })
		local barrier = makePart({ Name = "Barrier", Size = Vector3.new(1, 20, L), CFrame = frame * CFrame.new(side * (W * 0.5 + 0.5), 10, 0), Transparency = 1, CastShadow = false, Parent = walls })
		barrier.CanQuery = false
		barrier.CanTouch = false
		local caps = math.floor(L / 6)
		for k = 1, caps do
			local t = (k - 0.5) / caps
			if k % 2 == 1 then
				makePart({ Name = "Crenel", Size = Vector3.new(2.4, 1.2, 3), CFrame = at(t, x, 4.1), Color = DARK_STONE, Material = Enum.Material.Slate, Decorative = true, Parent = walls })
			end
			makeCorner({ Name = "ParapetSpike", Size = Vector3.new(1, 2.6, 1), CFrame = at(t, x, if k % 2 == 1 then 6 else 4.8) * CFrame.Angles(0, math.rad(45 + side * 90), 0), Color = IRON, Material = Enum.Material.Metal, Decorative = true, Parent = walls })
		end
	end

	------------------------------------------------------------------------
	-- Pylons with crimson braziers, linked by arcs of energy
	------------------------------------------------------------------------
	local pylons = Instance.new("Folder")
	pylons.Name = "Pylons"
	pylons.Parent = model
	for pairIndex, t in PYLON_T do
		local tops: { Attachment } = {}
		for _, side in { -1, 1 } do
			local x = side * (W * 0.5 + 3.5)
			local base = upright(t, x, 0)
			makePart({ Name = "Bastion", Size = Vector3.new(7, 5, 7), CFrame = base * CFrame.new(0, -2, 0), Color = OBSIDIAN, Material = Enum.Material.Basalt, Parent = pylons })
			makeWedge({ Name = "BastionSpike", Size = Vector3.new(6, 16, 6), CFrame = base * CFrame.new(0, -12.5, 0) * CFrame.Angles(math.pi, side * math.pi * 0.5, 0), Color = OBSIDIAN, Material = Enum.Material.Basalt, Decorative = true, Parent = pylons })
			makePart({ Name = "PylonFoot", Size = Vector3.new(5, 2, 5), CFrame = base * CFrame.new(0, 1.5, 0), Color = DARK_STONE, Material = Enum.Material.Slate, Parent = pylons })
			makePart({ Name = "PylonShaft", Size = Vector3.new(3.6, 20, 3.6), CFrame = base * CFrame.new(0, 12.5, 0), Color = OBSIDIAN, Material = Enum.Material.Basalt, Parent = pylons })
			local inlay = makePart({ Name = "PylonInlay", Size = Vector3.new(0.3, 16, 1), CFrame = base * CFrame.new(-side * 1.85, 12, 0), Color = GLOW, Material = Enum.Material.Neon, Decorative = true, Parent = pylons })
			pulse(inlay, t * 6)
			makePart({ Name = "PylonCap", Size = Vector3.new(5, 1.2, 5), CFrame = base * CFrame.new(0, 23.1, 0), Color = DARK_STONE, Material = Enum.Material.Slate, Decorative = true, Parent = pylons })
			for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
				makeCorner({ Name = "CapSpike", Size = Vector3.new(1, 3, 1), CFrame = base * CFrame.new(corner[1] * 2.1, 25.2, corner[2] * 2.1) * CFrame.Angles(0, math.atan2(corner[1], corner[2]) + math.pi * 0.75, 0), Color = IRON, Material = Enum.Material.Metal, Decorative = true, Parent = pylons })
			end
			local bowl = makePart({ Name = "Brazier", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 4.4, 4.4), CFrame = base * CFrame.new(0, 24.3, 0) * CFrame.Angles(0, 0, math.pi * 0.5), Color = IRON, Material = Enum.Material.Metal, Decorative = true, Parent = pylons })
			local fire = Instance.new("Fire")
			fire.Size = 7
			fire.Heat = 10
			fire.Color = Color3.fromRGB(200, 20, 30)
			fire.SecondaryColor = Color3.fromRGB(40, 0, 6)
			fire.Parent = bowl
			if side == 1 then
				local l = Instance.new("PointLight")
				l.Color = Color3.fromRGB(220, 40, 50)
				l.Range = 24
				l.Brightness = 2
				l.Parent = bowl
			end
			makePart({
				Name = "BannerArm",
				Size = Vector3.new(0.45, 0.24, 0.24),
				CFrame = base * CFrame.new(-side * 1.98, 19.5, 0),
				Color = IRON,
				Material = Enum.Material.Metal,
				Decorative = true,
				Parent = pylons,
			})
			WallsBuilder.SpawnBanner(
				pylons,
				string.format("CausewayBanner_%d_%s", pairIndex, if side < 0 then "L" else "R"),
				base * CFrame.new(-side * 2.2, 19.5, 0) * CFrame.Angles(0, math.pi * 0.5, 0),
				{ Scale = 1.1, DoubleSided = true, IncludeCrossbar = true }
			)

			-- Beam anchor above the brazier, primary axis pointing up so the arc bows skyward
			local anchor = Instance.new("Attachment")
			anchor.Name = "ArcAnchor"
			anchor.Parent = deck -- parent first: WorldCFrame is resolved against the parent part
			anchor.WorldCFrame = CFrame.fromMatrix(base.Position + Vector3.new(0, 27, 0), Vector3.yAxis, Vector3.xAxis)
			table.insert(tops, anchor)
		end
		for i, spec in { { Width = 1, Curve = 12, Transparency = 0.25 }, { Width = 0.35, Curve = 16, Transparency = 0.1 } } do
			local beam = Instance.new("Beam")
			beam.Name = string.format("CrimsonArc_%d_%d", pairIndex, i)
			beam.Attachment0 = tops[1]
			beam.Attachment1 = tops[2]
			beam.CurveSize0 = spec.Curve
			beam.CurveSize1 = -spec.Curve
			beam.Width0 = spec.Width
			beam.Width1 = spec.Width
			beam.Segments = 24
			beam.LightEmission = 1
			beam.LightInfluence = 0
			beam.FaceCamera = true
			beam.Color = ColorSequence.new(GLOW_HOT, GLOW)
			beam.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, spec.Transparency + 0.3),
				NumberSequenceKeypoint.new(0.5, spec.Transparency),
				NumberSequenceKeypoint.new(1, spec.Transparency + 0.3),
			})
			beam.Parent = deck
		end
	end

	------------------------------------------------------------------------
	-- Gothic arches with hanging cages
	------------------------------------------------------------------------
	local arches = Instance.new("Folder")
	arches.Name = "Arches"
	arches.Parent = model
	for _, t in ARCH_T do
		local c = upright(t, 0, 0)
		local span = W + 7
		makePart({ Name = "ArchLintel", Size = Vector3.new(span, 2.6, 3), CFrame = c * CFrame.new(0, 21.3, 0), Color = OBSIDIAN, Material = Enum.Material.Basalt, Parent = arches })
		makePart({ Name = "ArchTrim", Size = Vector3.new(span, 0.5, 3.3), CFrame = c * CFrame.new(0, 19.9, 0), Color = CRIMSON, Material = Enum.Material.Granite, Decorative = true, Parent = arches })
		-- Diamond crest whose lower tip hides inside the lintel
		makePart({ Name = "ArchCrest", Size = Vector3.new(8, 8, 2.4), CFrame = c * CFrame.new(0, 25.8, 0) * CFrame.Angles(0, 0, math.rad(45)), Color = OBSIDIAN, Material = Enum.Material.Basalt, Decorative = true, Parent = arches })
		makeCorner({ Name = "CrestSpike", Size = Vector3.new(1.4, 5, 1.4), CFrame = c * CFrame.new(0, 33.8, 0) * CFrame.Angles(0, math.rad(45), 0), Color = IRON, Material = Enum.Material.Metal, Decorative = true, Parent = arches })
		for _, face in { -1, 1 } do
			local sigil = makePart({ Name = "CrestSigil", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 3.4, 3.4), CFrame = c * CFrame.new(0, 26.2, face * 1.25) * CFrame.Angles(0, math.pi * 0.5, 0), Color = GLOW_HOT, Material = Enum.Material.Neon, Decorative = true, Parent = arches })
			pulse(sigil, t * 6 + 1)
		end
		-- Chain and gibbet cage, its floor well above head height
		local hang = c.Position + Vector3.new(0, 20, 0)
		chain(arches, "CageChain", hang, 4)
		local cageTop = hang.Y - 5.4
		local cage = c * CFrame.new(0, cageTop - c.Position.Y - 1.8, 0)
		makePart({ Name = "CageTop", Size = Vector3.new(3.4, 0.3, 3.4), CFrame = cage * CFrame.new(0, 1.8, 0), Color = IRON, Material = Enum.Material.Metal, Decorative = true, Parent = arches })
		makePart({ Name = "CageFloor", Size = Vector3.new(3.4, 0.3, 3.4), CFrame = cage * CFrame.new(0, -1.8, 0), Color = IRON, Material = Enum.Material.Metal, Decorative = true, Parent = arches })
		for _, b in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 }, { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } do
			makePart({ Name = "CageBar", Size = Vector3.new(0.22, 3.4, 0.22), CFrame = cage * CFrame.new(b[1] * 1.55, 0, b[2] * 1.55), Color = IRON, Material = Enum.Material.Metal, Decorative = true, Parent = arches })
		end
		local soul = makePart({ Name = "CagedSoul", Shape = Enum.PartType.Ball, Size = Vector3.new(1.3, 1.3, 1.3), CFrame = cage, Color = GLOW_HOT, Material = Enum.Material.Neon, Decorative = true, Parent = arches })
		soul.Transparency = 0.25
		pulse(soul, t * 9)
		local l = Instance.new("PointLight")
		l.Color = GLOW
		l.Range = 12
		l.Brightness = 1.5
		l.Parent = soul
	end

	------------------------------------------------------------------------
	-- Hooded Wardens guarding the tower end
	------------------------------------------------------------------------
	local wardens = Instance.new("Folder")
	wardens.Name = "Wardens"
	wardens.Parent = model
	for _, side in { -1, 1 } do
		local x = side * (W * 0.5 + 5.5)
		local base = upright(WARDEN_T, x, 0) * CFrame.Angles(0, side * math.rad(20), 0) -- turned slightly toward the deck
		local function wp(name: string, size: Vector3, cf: CFrame, color: Color3?, material: Enum.Material?, decorative: boolean?)
			return makePart({ Name = name, Size = size, CFrame = base * cf, Color = color or OBSIDIAN, Material = material or Enum.Material.Basalt, Decorative = decorative ~= false, Parent = wardens })
		end
		wp("WardenBastion", Vector3.new(10, 5, 10), CFrame.new(0, -2, 0), OBSIDIAN, Enum.Material.Basalt, false)
		makeWedge({ Name = "WardenBastionSpike", Size = Vector3.new(8, 20, 8), CFrame = base * CFrame.new(0, -14.5, 0) * CFrame.Angles(math.pi, 0, 0), Color = OBSIDIAN, Material = Enum.Material.Basalt, Decorative = true, Parent = wardens })
		wp("WardenPlinth", Vector3.new(7, 3, 7), CFrame.new(0, 2, 0), DARK_STONE, Enum.Material.Slate, false)
		wp("Robe", Vector3.new(5, 8, 4), CFrame.new(0, 7.5, 0))
		makeWedge({ Name = "RobeFlare", Size = Vector3.new(5.6, 4, 2), CFrame = base * CFrame.new(0, 5.5, -2.6), Color = OBSIDIAN, Material = Enum.Material.Basalt, Decorative = true, Parent = wardens })
		wp("Torso", Vector3.new(4.2, 4.5, 3), CFrame.new(0, 13.6, 0))
		wp("Shoulders", Vector3.new(6, 1.4, 3.2), CFrame.new(0, 15.6, 0))
		wp("Hood", Vector3.new(3.2, 3.6, 3.2), CFrame.new(0, 17.9, 0.2))
		makeWedge({ Name = "HoodPeak", Size = Vector3.new(3.2, 2, 3.2), CFrame = base * CFrame.new(0, 20.6, 0.2), Color = OBSIDIAN, Material = Enum.Material.Basalt, Decorative = true, Parent = wardens })
		wp("FaceVoid", Vector3.new(2, 2, 0.2), CFrame.new(0, 17.6, -1.45), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
		for _, ex in { -0.45, 0.45 } do
			local eye = wp("Eye", Vector3.new(0.4, 0.22, 0.1), CFrame.new(ex, 17.9, -1.56), GLOW_HOT, Enum.Material.Neon)
			pulse(eye, 0.5)
		end
		wp("Hands", Vector3.new(2.6, 1.3, 1.4), CFrame.new(0, 14.4, -2.2))
		wp("SwordGrip", Vector3.new(0.6, 2.4, 0.6), CFrame.new(0, 14.4, -2.4), IRON, Enum.Material.Metal)
		wp("SwordGuard", Vector3.new(4, 0.5, 0.8), CFrame.new(0, 13, -2.4), IRON, Enum.Material.Metal)
		wp("SwordBlade", Vector3.new(1, 10, 0.25), CFrame.new(0, 7.8, -2.4), Color3.fromRGB(60, 56, 60), Enum.Material.Metal)
		local edge = wp("BladeRune", Vector3.new(0.2, 8, 0.05), CFrame.new(0, 8, -2.55), GLOW, Enum.Material.Neon)
		pulse(edge, 1.5)
	end

	------------------------------------------------------------------------
	-- Underside: keel, hanging spikes and chains into the void
	------------------------------------------------------------------------
	local under = Instance.new("Folder")
	under.Name = "Underside"
	under.Parent = model
	makePart({ Name = "Keel", Size = Vector3.new(W * 0.6, 5, L - 4), CFrame = frame * CFrame.new(0, -5.5, 0), Color = OBSIDIAN, Material = Enum.Material.Basalt, Decorative = true, Parent = under })
	for _, t in { 0.22, 0.5, 0.78 } do
		makeWedge({ Name = "HangingSpike", Size = Vector3.new(W * 0.5, 26, 8), CFrame = at(t, 0, -21) * CFrame.Angles(math.pi, 0, 0), Color = OBSIDIAN, Material = Enum.Material.Basalt, Decorative = true, Parent = under })
	end
	for _, t in { 0.18, 0.42, 0.66, 0.92 } do
		for _, side in { -1, 1 } do
			chain(under, "DanglingChain", at(t, side * (W * 0.5 - 3), -3).Position, 6 + math.floor(t * 6))
		end
	end

	------------------------------------------------------------------------
	-- Effects: embers off the deck, crimson ground fog, red mist in the void below
	------------------------------------------------------------------------
	local fx = makePart({ Name = "DeckEffects", Size = Vector3.new(W - 6, 1, L - 4), CFrame = frame * CFrame.new(0, 1, 0), Transparency = 1, Decorative = true, Parent = model })
	emitter(fx, {
		Name = "Embers",
		Shape = Enum.ParticleEmitterShape.Box,
		Color = ColorSequence.new(Color3.fromRGB(255, 120, 60), Color3.fromRGB(200, 20, 30)),
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(3, 5),
		Rate = 18,
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(25, 25),
		Acceleration = Vector3.new(0, 1.5, 0),
		EmissionDirection = Enum.NormalId.Top,
	})
	emitter(fx, {
		Name = "CrimsonFog",
		Shape = Enum.ParticleEmitterShape.Box,
		Texture = SMOKE_TEXTURE,
		Color = ColorSequence.new(Color3.fromRGB(120, 14, 26), Color3.fromRGB(40, 6, 10)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.82), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 12) }),
		Lifetime = NumberRange.new(5, 8),
		Rate = 5,
		Speed = NumberRange.new(0.3, 1),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-8, 8),
		EmissionDirection = Enum.NormalId.Top,
	})
	local abyss = makePart({ Name = "AbyssMist", Size = Vector3.new(W, 1, L), CFrame = frame * CFrame.new(0, -16, 0), Transparency = 1, Decorative = true, Parent = under })
	emitter(abyss, {
		Name = "AbyssMist",
		Shape = Enum.ParticleEmitterShape.Box,
		Texture = SMOKE_TEXTURE,
		LightEmission = 0,
		Color = ColorSequence.new(Color3.fromRGB(35, 12, 18), Color3.fromRGB(16, 6, 10)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.88), NumberSequenceKeypoint.new(0.7, 0.92), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 18), NumberSequenceKeypoint.new(1, 30) }),
		Lifetime = NumberRange.new(6, 9),
		Rate = 4,
		Speed = NumberRange.new(1, 3),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-10, 10),
		EmissionDirection = Enum.NormalId.Bottom,
	})

	model.Parent = parent
	return model
end

return CausewayBuilder
