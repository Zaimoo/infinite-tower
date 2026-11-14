--!strict
-- StarterPlayerScripts/Rendering/GildedAnvilFx.client.luau
-- Band 6 ("Gilded") runtime layer for the six Gildforged weapons (docs/gilded-anvil-plan.md §3 and §4).
-- Everything here is cosmetic and client-only:
--   * Moving centrepieces: animates the GildAnimRole welds, spinning up from still on equip.
--   * Footprint: a sigil of its own under the hero for each weapon while it is drawn in the world.
--   * Idle extras: the Wyrmheart's heartbeat, embers and molten drips (and burning skull at low health),
--     the Dawnwarden's 3 s sun pulse, the Evergarden's footstep flowers, the Eclipse crescent waxing.
--   * Combat (driven by EntityRenderer): the gold-edged swing trail, a weapon afterimage on Specials,
--     each weapon's own hit effect, signature skill finishers, and kill / crit bursts.
--   * Budget: Reduce Motion turns off the moving pieces, footprints, afterimages and kill bursts (lights
--     and trails stay); past 60 studs only the light and glint remain; other Masters' weapons run at
--     Band 5 particle rates.
-- Hit and kill events carry no attacker, so they are attributed to the Gildforged hero that most recently
-- released an attack toward that spot (a cosmetic guess; nothing here touches gameplay).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponVfx = require(Assets:WaitForChild("CombatVfx"):WaitForChild("WeaponVfx"))
local HeroSockets = require(Assets:WaitForChild("HeroRig"):WaitForChild("HeroSockets"))
local WeaponVfxConfig = require(Shared:WaitForChild("Config"):WaitForChild("WeaponVfxConfig"))
local WeaponModelBuilder = require(Assets:WaitForChild("WeaponModelBuilder"))

-- Fetch the six weapons' uploaded meshes up front so the first equip or preview does not wait on them.
task.spawn(WeaponModelBuilder.PreloadGildedMeshes)

local LocalPlayer = Players.LocalPlayer
local TAG = "GildforgedWeapon"
local FAR_LOD_STUDS = 60
local OTHER_PLAYER_RATE_SCALE = 14 / 18
local EQUIP_SPINUP = 1.2 -- seconds for the centrepiece to reach full speed (equip flourish)
local LOW_HEALTH_PERMILLE = 300
local GROUND_DROP = 2.35 -- HumanoidRootPart to floor

local GOLD = Color3.fromRGB(255, 222, 118)
local WHITE_GOLD = Color3.fromRGB(255, 246, 214)
local SHADOW = Color3.fromRGB(26, 18, 36)
local AURORA_TEAL = Color3.fromRGB(70, 235, 212)
local AURORA_VIOLET = Color3.fromRGB(150, 110, 255)
local AURORA_PINK = Color3.fromRGB(232, 120, 235)
local CRIMSON = Color3.fromRGB(225, 42, 36)
local EMBER = Color3.fromRGB(255, 140, 40)
local STAR_BLUE = Color3.fromRGB(70, 130, 255)
local JADE = Color3.fromRGB(110, 224, 152)
local PETAL = Color3.fromRGB(255, 236, 244)

local DAWN = "art_gild_dawnwarden_oath"
local ECLIPSE = "art_gild_eclipse_sisters"
local AURORA = "art_gild_aurora_skyhook"
local WYRM = "art_gild_wyrmheart_cleaver"
local ORRERY = "art_gild_ninth_sky_orrery"
local CODEX = "art_gild_evergarden_codex"

local function reducedMotion(): boolean
	return LocalPlayer:GetAttribute("Settings_ReduceMotion") == true
end

local function camDistance(pos: Vector3): number
	local cam = Workspace.CurrentCamera
	return if cam then (pos - cam.CFrame.Position).Magnitude else 0
end

--============================================================================
-- Transient effect parts
--============================================================================

local function fxPart(size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?, transparency: number, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = "GildedAnvilFx"
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Material = material or Enum.Material.Neon
	p.Color = color
	p.Transparency = transparency
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	return p
end

-- A part that fades (and optionally grows or travels) over `duration`, then cleans itself up.
local function flash(size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?, startTransp: number, duration: number, goalSize: Vector3?, goalCF: CFrame?)
	local p = fxPart(size, cf, color, shape, startTransp)
	p.Parent = Workspace
	local goal: { [string]: any } = { Transparency = 1 }
	if goalSize then
		goal.Size = goalSize
	end
	if goalCF then
		goal.CFrame = goalCF
	end
	TweenService:Create(p, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	Debris:AddItem(p, duration + 0.05)
	return p
end

-- A flat ring lying on the XZ plane (a disc seen edge-on is a Cylinder rotated about Z).
local function groundRing(pos: Vector3, diameter: number, color: Color3, startTransp: number, duration: number, goalDiameter: number)
	flash(Vector3.new(0.12, diameter, diameter), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color,
		Enum.PartType.Cylinder, startTransp, duration, Vector3.new(0.12, goalDiameter, goalDiameter))
end

-- `count` pieces flying outward from `pos`, fading as they go.
local function burst(pos: Vector3, colors: { Color3 }, count: number, pieceSize: Vector3, distance: number, duration: number, rise: number, shape: Enum.PartType?)
	for i = 1, count do
		local yaw = (i / count) * math.pi * 2 + math.random() * 0.5
		local pitch = (math.random() - 0.3) * 0.9
		local dir = Vector3.new(math.cos(yaw) * math.cos(pitch), math.sin(pitch), math.sin(yaw) * math.cos(pitch))
		local start = CFrame.lookAt(pos, pos + dir)
		local goal = CFrame.lookAt(pos + dir * distance + Vector3.new(0, rise, 0), pos + dir * (distance + 1) + Vector3.new(0, rise, 0))
		flash(pieceSize, start, colors[(i - 1) % #colors + 1], shape, 0.1, duration * (0.8 + math.random() * 0.4), pieceSize * 0.4, goal)
	end
end

-- Thin bright arc of `segments` blocks around `center` (in the plane of `basis`'s X/Y axes).
local function arc(basis: CFrame, radius: number, fromAngle: number, toAngle: number, segments: number, color: Color3, thickness: number, duration: number)
	local step = (toAngle - fromAngle) / segments
	local chord = 2 * radius * math.sin(math.abs(step) / 2) + 0.05
	for i = 0, segments - 1 do
		local a = fromAngle + step * (i + 0.5)
		local cf = basis * CFrame.Angles(0, 0, a) * CFrame.new(radius, 0, 0)
		flash(Vector3.new(thickness, chord, thickness), cf, color, nil, 0.15, duration)
	end
end

--============================================================================
-- Footprint sigils (one design per weapon, built once, moved with BulkMoveTo)
--============================================================================

type SigilPiece = { Part: BasePart, Offset: CFrame, Order: number }
type Sigil = { Folder: Folder, Pieces: { SigilPiece }, Spin: number }

local function addPiece(pieces: { SigilPiece }, folder: Folder, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?, transparency: number, order: number?)
	local p = fxPart(size, CFrame.identity, color, shape, transparency)
	p.Name = "SigilPiece"
	p.Parent = folder
	table.insert(pieces, { Part = p, Offset = offset, Order = order or 0 })
end

local FLAT = CFrame.Angles(0, 0, math.rad(90)) -- turns a Cylinder's axis to +Y so it lies flat

local function buildSigil(templateId: string, element: string): Sigil
	local folder = Instance.new("Folder")
	folder.Name = "GildFooterSigil"
	local pieces: { SigilPiece } = {}
	local spin = 0.15
	local thin = 0.06

	if templateId == DAWN then
		-- Rising sun: a half disc on the horizon line with rays fanning out above it.
		addPiece(pieces, folder, Vector3.new(thin, 1.7, 1.7), FLAT, GOLD, Enum.PartType.Cylinder, 0.55)
		addPiece(pieces, folder, Vector3.new(3.8, thin, 0.08), CFrame.new(0, 0.01, 0), WHITE_GOLD, nil, 0.45)
		for i = 0, 8 do
			local a = math.rad(15 + i * 18.75)
			local r = if i % 2 == 0 then 1.75 else 1.45
			addPiece(pieces, folder, Vector3.new(0.09, thin, r - 0.95),
				CFrame.new(math.cos(a) * (0.95 + (r - 0.95) / 2), 0, -math.sin(a) * (0.95 + (r - 0.95) / 2)) * CFrame.Angles(0, a - math.pi / 2, 0),
				GOLD, nil, 0.5)
		end
		spin = 0
	elseif templateId == ECLIPSE then
		-- Crescent moon: 14 arc pieces; Order lets it wax while the hero stands still.
		local n = 14
		for i = 0, n - 1 do
			local a = math.rad(-120 + i * (240 / (n - 1)))
			local w = 0.12 + 0.22 * math.sin(math.pi * i / (n - 1))
			addPiece(pieces, folder, Vector3.new(w, thin, 0.42), CFrame.new(math.cos(a) * 1.6, 0, math.sin(a) * 1.6) * CFrame.Angles(0, -a, 0),
				if i % 2 == 0 then GOLD else WHITE_GOLD, nil, 0.45, math.abs(i - (n - 1) / 2))
		end
		addPiece(pieces, folder, Vector3.new(thin, 0.5, 0.5), CFrame.new(-0.6, 0, 0) * FLAT, SHADOW, Enum.PartType.Cylinder, 0.3)
		spin = 0.05
	elseif templateId == AURORA then
		-- Aurora ring (teal -> violet -> pink) with a four-point north star.
		local n = 18
		for i = 0, n - 1 do
			local a = i / n * math.pi * 2
			local t = i / n
			local c = if t < 0.5 then AURORA_TEAL:Lerp(AURORA_VIOLET, t * 2) else AURORA_VIOLET:Lerp(AURORA_PINK, (t - 0.5) * 2)
			addPiece(pieces, folder, Vector3.new(0.12, thin, 0.62), CFrame.new(math.cos(a) * 1.8, 0, math.sin(a) * 1.8) * CFrame.Angles(0, -a, 0), c, nil, 0.45)
		end
		for k = 0, 3 do
			local len = if k % 2 == 0 then 0.9 else 0.5
			addPiece(pieces, folder, Vector3.new(0.1, thin, len), CFrame.new(0, 0, -2.4) * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, 0, -len / 2), WHITE_GOLD, nil, 0.3)
		end
		spin = 0.12
	elseif templateId == WYRM then
		-- Cracked ground: seven jagged two-segment cracks glowing with lava light.
		addPiece(pieces, folder, Vector3.new(thin, 0.9, 0.9), FLAT, EMBER, Enum.PartType.Cylinder, 0.4)
		for i = 0, 6 do
			local a = i / 7 * math.pi * 2 + (i % 2) * 0.2
			local bend = if i % 2 == 0 then 0.35 else -0.3
			local mid = Vector3.new(math.cos(a) * 1.0, 0, math.sin(a) * 1.0)
			local tip = mid + Vector3.new(math.cos(a + bend) * 1.1, 0, math.sin(a + bend) * 1.1)
			addPiece(pieces, folder, Vector3.new(0.14, thin, 1.0), CFrame.lookAt(mid * 0.5, mid), CRIMSON, nil, 0.35)
			addPiece(pieces, folder, Vector3.new(0.09, thin, 1.1), CFrame.lookAt((mid + tip) / 2, tip), EMBER, nil, 0.4)
		end
		spin = 0
	elseif templateId == ORRERY then
		-- Star chart: outer ring, seven stars and the lines of one constellation; turns slowly.
		local n = 20
		for i = 0, n - 1 do
			local a = i / n * math.pi * 2
			addPiece(pieces, folder, Vector3.new(0.08, thin, 0.6), CFrame.new(math.cos(a) * 2.0, 0, math.sin(a) * 2.0) * CFrame.Angles(0, -a, 0), GOLD, nil, 0.55)
		end
		local stars = {
			Vector3.new(-1.2, 0, -0.5), Vector3.new(-0.6, 0, -0.9), Vector3.new(0.1, 0, -0.6), Vector3.new(0.7, 0, -0.1),
			Vector3.new(1.2, 0, 0.5), Vector3.new(0.2, 0, 0.8), Vector3.new(-0.7, 0, 0.6),
		}
		for i, s in stars do
			addPiece(pieces, folder, Vector3.new(0.22, 0.22, 0.22), CFrame.new(s + Vector3.new(0, 0.05, 0)), WHITE_GOLD, Enum.PartType.Ball, 0.2)
			local nxt = stars[i % #stars + 1]
			if i < #stars then
				addPiece(pieces, folder, Vector3.new(0.05, thin, (nxt - s).Magnitude), CFrame.lookAt((s + nxt) / 2, nxt), STAR_BLUE, nil, 0.45)
			end
		end
		spin = 0.08
	else
		-- Evergarden: a ring of eight blooming flowers with jade hearts.
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			local c = Vector3.new(math.cos(a) * 1.8, 0, math.sin(a) * 1.8)
			for k = 0, 4 do
				local pa = k / 5 * math.pi * 2
				addPiece(pieces, folder, Vector3.new(0.24, 0.05, 0.24), CFrame.new(c + Vector3.new(math.cos(pa) * 0.2, 0, math.sin(pa) * 0.2)), PETAL, Enum.PartType.Ball, 0.3)
			end
			addPiece(pieces, folder, Vector3.new(0.14, 0.07, 0.14), CFrame.new(c + Vector3.new(0, 0.02, 0)), JADE, Enum.PartType.Ball, 0.2)
		end
		spin = 0.1
	end

	-- Tint toward the weapon's element so the sigil reads as the same family as its trail.
	local style = WeaponVfxConfig.Elements[element]
	if style and templateId ~= AURORA then
		for _, piece in pieces do
			if piece.Part.Color ~= SHADOW then
				piece.Part.Color = piece.Part.Color:Lerp(style.PrimaryColor, 0.15)
			end
		end
	end
	return { Folder = folder, Pieces = pieces, Spin = spin }
end

--============================================================================
-- Tracked weapons
--============================================================================

type AnimWeld = { Weld: Weld, Role: string, BaseC0: CFrame }

type TrackedWeapon = {
	Model: Model,
	TemplateId: string,
	Element: string,
	AnimWelds: { AnimWeld },
	Lights: { { Light: PointLight, BaseBrightness: number } },
	Sigil: Sigil?,
	EquippedAt: number,
	Phase: number,
	LastScale: number,
	LastBeat: number,
	NextDrip: number,
	StillSince: number,
	LastRootPos: Vector3?,
	StepDistance: number,
	SkullFire: Fire?,
}

local tracked: { [Model]: TrackedWeapon } = {}

-- Sigils live in their own folder so weapon-level code (afterimages, holstering, bounds) never sees them.
local sigilRoot = Instance.new("Folder")
sigilRoot.Name = "GildedAnvilSigils"
sigilRoot.Parent = Workspace

local function scanAnimWelds(model: Model): { AnimWeld }
	local out: { AnimWeld } = {}
	for _, desc in model:GetDescendants() do
		if desc:IsA("Weld") then
			local role = desc:GetAttribute("GildAnimRole")
			local baseC0 = desc:GetAttribute("BaseC0")
			if type(role) == "string" and role ~= "" and typeof(baseC0) == "CFrame" then
				table.insert(out, { Weld = desc, Role = role, BaseC0 = baseC0 })
			end
		end
	end
	return out
end

local function scanLights(model: Model): { { Light: PointLight, BaseBrightness: number } }
	local out: { { Light: PointLight, BaseBrightness: number } } = {}
	for _, desc in model:GetDescendants() do
		if desc:IsA("PointLight") then
			table.insert(out, { Light = desc, BaseBrightness = desc.Brightness })
		end
	end
	return out
end

local function findOwnerUserId(model: Model): number?
	local cur: Instance? = model
	while cur and cur ~= Workspace do
		local uid = cur:GetAttribute("OwnerUserId")
		if type(uid) == "number" then
			return uid
		end
		cur = cur.Parent
	end
	return nil
end

-- The hero rig holding the weapon (the first ancestor Model with a HumanoidRootPart).
local function findHeroRig(model: Model): (Model?, BasePart?)
	local cur: Instance? = model.Parent
	while cur and cur ~= Workspace do
		if cur:IsA("Model") then
			local hrp = cur:FindFirstChild("HumanoidRootPart")
			if hrp and hrp:IsA("BasePart") then
				return cur, hrp
			end
		end
		cur = cur.Parent
	end
	return nil, nil
end

local function roleMotion(role: string, t: number): CFrame
	if role == "SunDisc" then
		return CFrame.Angles(0, 0, t * 0.95)
	elseif role == "HaloRing1" then
		return CFrame.Angles(0, 0, t * 0.55) * CFrame.Angles(math.sin(t * 0.7) * 0.14, 0, 0)
	elseif role == "HaloRing2" then
		return CFrame.Angles(0, 0, -t * 0.72) * CFrame.Angles(math.cos(t * 0.8) * 0.16, 0, 0)
	elseif role == "EclipseRing" then
		return CFrame.new(0, math.sin(t * 1.8) * 0.03, 0) * CFrame.Angles(0, t * 0.85, 0)
	elseif role == "EclipseCore" then
		return CFrame.new(0, math.sin(t * 1.8) * 0.03, 0) * CFrame.Angles(0, -t * 1.2, 0)
	elseif role == "AuroraRibbonUpper" then
		return CFrame.Angles(math.sin(t * 2.2) * 0.045, math.cos(t * 1.7) * 0.035, 0)
	elseif role == "AuroraRibbonLower" then
		return CFrame.Angles(math.sin(t * 2.2 + 1.2) * 0.045, math.cos(t * 1.7 + 1.2) * 0.035, 0)
	elseif role == "WyrmHeart" then
		local cycle = (t % 1.2) / 1.2
		local beat = math.exp(-cycle * 10) + 0.65 * math.exp(-((cycle - 0.22) % 1) * 14)
		return CFrame.new(0, 0, beat * 0.035) * CFrame.Angles(0, t * 0.45, 0)
	elseif role == "OrreryRing1" then
		return CFrame.Angles(t * 1.15, t * 0.45, 0)
	elseif role == "OrreryRing2" then
		return CFrame.Angles(-t * 0.85, t * 1.35, 0)
	elseif role == "OrreryRing3" then
		return CFrame.Angles(t * 0.55, -t * 1.25, t * 0.65)
	elseif role == "OrreryStar" then
		return CFrame.Angles(t * 0.4, t * 1.5, 0)
	elseif role == "OrreryMoon1" then
		return CFrame.Angles(0, t * 1.8, 0)
	elseif role == "OrreryMoon2" then
		return CFrame.Angles(math.sin(t * 0.4) * 0.2, -t * 1.45, 0)
	elseif role == "OrreryMoon3" then
		return CFrame.Angles(0, t * 2.3, math.cos(t * 0.5) * 0.15)
	elseif role == "LivingPage1" then
		return CFrame.Angles(0, math.sin(t * 1.8) * 0.24, math.cos(t * 1.3) * 0.08)
	elseif role == "LivingPage2" then
		return CFrame.Angles(0, math.sin(t * 1.8 + 1.5) * 0.24, math.cos(t * 1.3 + 1.5) * 0.08)
	elseif role == "JadeGem" then
		return CFrame.Angles(0, t * 0.6, 0)
	elseif role == "BlossomBookmark" then
		return CFrame.Angles(0, 0, math.sin(t * 1.5) * 0.14)
	end
	return CFrame.identity
end

local function emitEquipFlourish(entry: TrackedWeapon)
	if reducedMotion() then
		return
	end
	for _, desc in entry.Model:GetDescendants() do
		if desc:IsA("ParticleEmitter") and desc:GetAttribute("WeaponVfxInstance") then
			desc:Emit(if desc.Name == "VfxGildGlintSweep" then 6 else 10)
		end
	end
end

local function destroySigil(entry: TrackedWeapon)
	if entry.Sigil then
		entry.Sigil.Folder:Destroy()
		entry.Sigil = nil
	end
end

local function trackWeapon(instance: Instance)
	-- Templates stored in ReplicatedStorage are never shown; only world and UI (viewport) copies animate.
	if not instance:IsA("Model") or tracked[instance] or instance:IsDescendantOf(ReplicatedStorage) then
		return
	end
	local entry: TrackedWeapon = {
		Model = instance,
		TemplateId = tostring(instance:GetAttribute("GildTemplateId") or ""),
		Element = tostring(instance:GetAttribute("GildElement") or "SUNLIGHT"),
		AnimWelds = scanAnimWelds(instance),
		Lights = scanLights(instance),
		Sigil = nil,
		EquippedAt = os.clock(),
		Phase = 0,
		LastScale = 1,
		LastBeat = 0,
		NextDrip = 0,
		StillSince = os.clock(),
		LastRootPos = nil,
		StepDistance = 0,
		SkullFire = nil,
	}
	tracked[instance] = entry
	emitEquipFlourish(entry)
end

local function untrackWeapon(instance: Instance)
	local entry = tracked[instance :: Model]
	if entry then
		destroySigil(entry)
		if entry.SkullFire then
			entry.SkullFire:Destroy()
		end
		tracked[instance :: Model] = nil
	end
end

for _, inst in CollectionService:GetTagged(TAG) do
	trackWeapon(inst)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(trackWeapon)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(untrackWeapon)

--============================================================================
-- Per-weapon idle extras (world copies near the camera only)
--============================================================================

local function partNamed(model: Model, name: string): BasePart?
	local p = model:FindFirstChild(name, true)
	return if p and p:IsA("BasePart") then p else nil
end

local function spawnFootstepFlower(pos: Vector3)
	local base = CFrame.new(pos) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2
		local cf = base * CFrame.new(math.cos(a) * 0.16, 0.03, math.sin(a) * 0.16)
		flash(Vector3.new(0.05, 0.05, 0.05), cf, PETAL, Enum.PartType.Ball, 0.15, 2.0, Vector3.new(0.24, 0.06, 0.24))
	end
	flash(Vector3.new(0.05, 0.05, 0.05), base * CFrame.new(0, 0.05, 0), JADE, Enum.PartType.Ball, 0.1, 2.0, Vector3.new(0.14, 0.08, 0.14))
end

local function updateIdleExtras(entry: TrackedWeapon, now: number, rig: Model?, root: BasePart?, near: boolean, reduce: boolean)
	local model = entry.Model
	local id = entry.TemplateId

	if id == WYRM then
		-- Heartbeat every 1.2 s: a pulse of light, a ring of heat and a few embers. Molten gold drips.
		local heart = partNamed(model, "WyrmHeart")
		if heart and near and now - entry.LastBeat >= 1.2 then
			entry.LastBeat = now
			if not reduce then
				flash(Vector3.new(0.4, 0.4, 0.4), heart.CFrame, EMBER, Enum.PartType.Ball, 0.35, 0.35, Vector3.new(1.3, 1.3, 1.3))
				burst(heart.Position, { EMBER, GOLD }, 3, Vector3.new(0.07, 0.07, 0.07), 0.9, 0.5, 0.5, Enum.PartType.Ball)
			end
		end
		local edge = partNamed(model, "BladeEdge")
		if edge and near and not reduce and now >= entry.NextDrip then
			entry.NextDrip = now + 0.7 + math.random() * 0.6
			local drop = edge.CFrame * CFrame.new(0, (math.random() - 0.5) * edge.Size.Y * 0.8, 0)
			local floorY = if root then root.Position.Y - GROUND_DROP else drop.Position.Y - 3
			local fall = math.max(0.5, drop.Position.Y - floorY)
			flash(Vector3.new(0.1, 0.16, 0.1), drop, GOLD, Enum.PartType.Ball, 0.05, 0.12 * math.sqrt(fall), nil,
				CFrame.new(drop.Position.X, floorY + 0.05, drop.Position.Z))
			task.delay(0.12 * math.sqrt(fall), function()
				flash(Vector3.new(0.05, 0.05, 0.05), CFrame.new(drop.Position.X, floorY + 0.05, drop.Position.Z), EMBER, Enum.PartType.Ball, 0.2, 0.3, Vector3.new(0.35, 0.05, 0.35))
			end)
		end
		-- Low health: the skull burns (flame wings flicker from the axe head).
		local skull = partNamed(model, "DragonSkull")
		local hp = rig and rig:GetAttribute("HpPermille")
		local burning = skull ~= nil and type(hp) == "number" and hp > 0 and hp < LOW_HEALTH_PERMILLE and near
		if burning and not entry.SkullFire and skull then
			local fire = Instance.new("Fire")
			fire.Name = "GildSkullFire"
			fire.Color = CRIMSON
			fire.SecondaryColor = GOLD
			fire.Size = 3
			fire.Heat = 6
			fire.Parent = skull
			entry.SkullFire = fire
		elseif not burning and entry.SkullFire then
			entry.SkullFire:Destroy()
			entry.SkullFire = nil
		end
	elseif id == CODEX and root and near and not reduce then
		-- Small flowers sprout in the hero's footsteps and fade after 2 s.
		local pos = root.Position
		if entry.LastRootPos then
			local step = Vector3.new(pos.X - entry.LastRootPos.X, 0, pos.Z - entry.LastRootPos.Z).Magnitude
			if step < 4 then
				entry.StepDistance += step
			end
			if entry.StepDistance >= 1.6 then
				entry.StepDistance = 0
				spawnFootstepFlower(Vector3.new(pos.X, pos.Y - GROUND_DROP, pos.Z))
			end
		end
	end

	if root then
		local pos = root.Position
		if entry.LastRootPos and (pos - entry.LastRootPos).Magnitude > 0.05 then
			entry.StillSince = now
		end
		entry.LastRootPos = pos
	end
end

--============================================================================
-- Per-frame update
--============================================================================

RunService.RenderStepped:Connect(function(dt: number)
	local now = os.clock()
	local cam = Workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position
	local reduce = reducedMotion()
	local bulkParts: { BasePart } = {}
	local bulkCFrames: { CFrame } = {}

	for model, entry in tracked do
		if not model.Parent then
			untrackWeapon(model)
			continue
		end

		local isWorld = model:IsDescendantOf(Workspace)
		local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
		local dist = if isWorld and camPos and primary then (primary.Position - camPos).Magnitude else 0
		local isFar = dist > FAR_LOD_STUDS
		local rig, root = nil, nil
		if isWorld then
			rig, root = findHeroRig(model)
		end

		-- Ambient particle scale: off past 60 studs, Band 5 on other Masters' heroes, full on yours and in UI.
		local targetScale = 1.0
		if isFar then
			targetScale = 0
		elseif isWorld then
			local ownerId = findOwnerUserId(model)
			if ownerId and ownerId ~= LocalPlayer.UserId then
				targetScale = OTHER_PLAYER_RATE_SCALE
			end
		end
		if math.abs(targetScale - entry.LastScale) > 0.01 then
			entry.LastScale = targetScale
			WeaponVfx.SetRateScale(model, targetScale)
		end

		-- Moving centrepiece. The equip flourish spins it up from still (rings start turning, the sun rises).
		local sinceEquip = now - entry.EquippedAt
		local speed = if sinceEquip < EQUIP_SPINUP then (sinceEquip / EQUIP_SPINUP) ^ 2 else 1
		entry.Phase += dt * speed
		local animate = not reduce and not isFar
		for _, aw in entry.AnimWelds do
			if aw.Weld.Parent then
				local liveBase = aw.Weld:GetAttribute("BaseC0")
				if typeof(liveBase) == "CFrame" then
					aw.BaseC0 = liveBase
				end
				aw.Weld.C0 = if animate then aw.BaseC0 * roleMotion(aw.Role, entry.Phase) else aw.BaseC0
			end
		end

		-- Lights: the equip flourish ignites them from dim; the sun disc pulses warm every 3 s;
		-- the Wyrmheart's light beats with its heart.
		local flourish = if sinceEquip < 0.6 then 0.25 + 1.10 * math.sin((sinceEquip / 0.6) * math.pi) else 1
		local pulse = 1
		if not isFar then
			if entry.TemplateId == DAWN then
				pulse = 1 + 0.18 * math.max(0, math.sin(now * math.pi / 1.5))
			elseif entry.TemplateId == WYRM then
				local cycle = (now % 1.2) / 1.2
				pulse = 0.85 + 0.45 * math.exp(-cycle * 9)
			end
		end
		for _, l in entry.Lights do
			if l.Light.Parent then
				l.Light.Brightness = l.BaseBrightness * flourish * pulse
			end
		end

		if isWorld then
			updateIdleExtras(entry, now, rig, root, not isFar, reduce)
		end

		-- Footprint sigil while the weapon is drawn in the world.
		local showSigil = isWorld and root ~= nil and not reduce and not isFar
		if showSigil and root then
			if not entry.Sigil then
				entry.Sigil = buildSigil(entry.TemplateId, entry.Element)
			end
			local sigil = entry.Sigil :: Sigil
			if sigil.Folder.Parent ~= sigilRoot then
				sigil.Folder.Parent = sigilRoot
			end
			local pos = root.Position
			local _, yaw, _ = root.CFrame:ToOrientation()
			local base = CFrame.new(pos.X, pos.Y - GROUND_DROP, pos.Z) * CFrame.Angles(0, yaw + now * sigil.Spin, 0)
			-- The Eclipse crescent waxes from its middle outward while the hero stands still.
			local wax = if entry.TemplateId == ECLIPSE then math.clamp((now - entry.StillSince) / 2.5, 0.15, 1) * 7 else math.huge
			for _, piece in sigil.Pieces do
				table.insert(bulkParts, piece.Part)
				table.insert(bulkCFrames, base * piece.Offset)
				if entry.TemplateId == ECLIPSE and piece.Order > 0 then
					piece.Part.LocalTransparencyModifier = if piece.Order <= wax then 0 else 1
				end
			end
		elseif entry.Sigil then
			entry.Sigil.Folder.Parent = nil
			if not isWorld then
				destroySigil(entry)
			end
		end
	end

	if #bulkParts > 0 then
		Workspace:BulkMoveTo(bulkParts, bulkCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)

--============================================================================
-- Combat: releases, hits, kills
--============================================================================

type Release = { TemplateId: string, Target: Vector3, Self: Vector3, At: number }
local recentReleases: { Release } = {}
local lastHit: { [string]: { Pos: Vector3, At: number } } = {}
local ATTRIBUTE_RADIUS = 9
local HIT_WINDOW = 1.6
local KILL_WINDOW = 2.5

local function rememberRelease(release: Release)
	table.insert(recentReleases, release)
	if #recentReleases > 24 then
		table.remove(recentReleases, 1)
	end
end

-- The Gildforged weapon whose most recent attack was aimed near `pos` within `window` seconds.
local function attribute(pos: Vector3, window: number): string?
	local now = os.clock()
	for i = #recentReleases, 1, -1 do
		local r = recentReleases[i]
		if now - r.At > window then
			break
		end
		local flat = Vector3.new(pos.X - r.Target.X, 0, pos.Z - r.Target.Z)
		if flat.Magnitude <= ATTRIBUTE_RADIUS then
			return r.TemplateId
		end
	end
	return nil
end

-- Ghost copies of the equipped weapon that repeat the swing a beat later (Special attacks).
local function afterimage(weaponModel: Model, color: Color3, copies: number, gap: number)
	for c = 1, copies do
		task.delay(0.06 + gap * (c - 1), function()
			if not weaponModel.Parent then
				return
			end
			for _, part in weaponModel:GetDescendants() do
				if part:IsA("BasePart") and part.Transparency < 0.9 and part.Size.Magnitude > 0.25 then
					local ghost = part:Clone()
					ghost:ClearAllChildren()
					ghost.Anchored = true
					ghost.CanCollide = false
					ghost.CanQuery = false
					ghost.CanTouch = false
					ghost.CastShadow = false
					ghost.Material = Enum.Material.ForceField
					ghost.Color = color
					ghost.Transparency = 0.25
					ghost.Parent = Workspace
					TweenService:Create(ghost, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1 }):Play()
					Debris:AddItem(ghost, 0.4)
				end
			end
		end)
	end
end

-- Each weapon's own hit effect (Basic and Special).
local function playHit(templateId: string, pos: Vector3, kind: string)
	local p = pos + Vector3.new(0, 1.4, 0)
	local cam = Workspace.CurrentCamera
	local facing = if cam then CFrame.lookAt(p, cam.CFrame.Position) else CFrame.new(p)
	if templateId == DAWN then
		if kind == "SPECIAL" then
			-- The shield flashes and a hexagonal ward ripples outward.
			for k = 0, 5 do
				local a = k / 6 * math.pi * 2
				local cf = facing * CFrame.Angles(0, 0, a) * CFrame.new(0, 1.2, 0)
				flash(Vector3.new(1.3, 0.1, 0.1), cf, GOLD, nil, 0.2, 0.45, Vector3.new(2.6, 0.1, 0.1), facing * CFrame.Angles(0, 0, a) * CFrame.new(0, 2.4, 0))
			end
		else
			-- A crescent of light hangs in the air for 0.3 s.
			arc(facing, 1.3, math.rad(20), math.rad(160), 7, WHITE_GOLD, 0.12, 0.3)
		end
	elseif templateId == ECLIPSE then
		local prev = lastHit[templateId]
		if kind == "BASIC" and prev and os.clock() - prev.At < 1.2 and (prev.Pos - pos).Magnitude < 2 then
			-- Two hits on the same target: the black and gold trails cross into an X.
			flash(Vector3.new(0.16, 0.16, 3.8), facing * CFrame.Angles(0, 0, 0.75) * CFrame.Angles(math.pi / 2, 0, 0), GOLD, nil, 0.1, 0.3)
			flash(Vector3.new(0.16, 0.16, 3.8), facing * CFrame.Angles(0, 0, -0.75) * CFrame.Angles(math.pi / 2, 0, 0), SHADOW, nil, 0.1, 0.3)
		else
			flash(Vector3.new(0.5, 0.5, 0.5), CFrame.new(p), if kind == "SPECIAL" then SHADOW else GOLD, Enum.PartType.Ball, 0.2, 0.25, Vector3.new(1.6, 1.6, 1.6))
		end
		lastHit[templateId] = { Pos = pos, At = os.clock() }
	elseif templateId == AURORA then
		-- Impact blooms into a small aurora curtain.
		for k, c in { AURORA_TEAL, AURORA_VIOLET, AURORA_PINK } do
			local off = (k - 2) * 0.55
			local cf = facing * CFrame.new(off, 0, 0)
			flash(Vector3.new(0.45, 0.4, 0.05), cf, c, nil, 0.3, 0.55, Vector3.new(0.45, 2.6, 0.05), cf * CFrame.new(0, 1.0, 0))
		end
	elseif templateId == WYRM then
		if kind == "SPECIAL" then
			-- Glowing cracks spread from the impact with a ring shockwave.
			local ground = Vector3.new(pos.X, pos.Y - 0.9, pos.Z)
			for k = 0, 5 do
				local a = k / 6 * math.pi * 2 + math.random() * 0.4
				local tip = ground + Vector3.new(math.cos(a) * 2.6, 0, math.sin(a) * 2.6)
				flash(Vector3.new(0.14, 0.05, 2.6), CFrame.lookAt((ground + tip) / 2, tip), EMBER, nil, 0.1, 0.8)
			end
			groundRing(ground, 1.5, CRIMSON, 0.25, 0.45, 8)
		else
			burst(p, { EMBER, GOLD, CRIMSON }, 6, Vector3.new(0.09, 0.09, 0.09), 1.6, 0.4, 0.7, Enum.PartType.Ball)
		end
	elseif templateId == ORRERY then
		-- The comet strikes with a small star flash.
		flash(Vector3.new(0.4, 0.4, 0.4), CFrame.new(p), WHITE_GOLD, Enum.PartType.Ball, 0.1, 0.3, Vector3.new(1.8, 1.8, 1.8))
		arc(facing, 0.9, 0, math.pi * 2, 10, STAR_BLUE, 0.07, 0.35)
	elseif templateId == CODEX then
		-- A small bloom of petals.
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2
			local cf = facing * CFrame.Angles(0, 0, a)
			flash(Vector3.new(0.3, 0.12, 0.05), cf * CFrame.new(0, 0.2, 0), PETAL, Enum.PartType.Ball, 0.15, 0.5, Vector3.new(0.5, 0.2, 0.05), cf * CFrame.new(0, 0.9, 0))
		end
		flash(Vector3.new(0.3, 0.3, 0.3), CFrame.new(p), JADE, Enum.PartType.Ball, 0.2, 0.4, Vector3.new(0.9, 0.9, 0.9))
	end
end

-- Signature kill / crit burst.
local function playSignatureBurst(templateId: string, pos: Vector3)
	local p = pos + Vector3.new(0, 1.5, 0)
	if templateId == DAWN then
		burst(p, { GOLD, WHITE_GOLD }, 10, Vector3.new(0.08, 0.04, 0.5), 2.6, 0.7, 0.8) -- gold feathers
	elseif templateId == ECLIPSE then
		burst(p, { WHITE_GOLD, GOLD, SHADOW }, 10, Vector3.new(0.06, 0.22, 0.4), 2.4, 0.45, 0) -- outline shatters
	elseif templateId == AURORA then
		burst(p, { AURORA_TEAL, AURORA_VIOLET, AURORA_PINK }, 8, Vector3.new(0.07, 0.07, 1.2), 2.2, 0.4, 0) -- starburst
	elseif templateId == WYRM then
		burst(p, { EMBER, GOLD, CRIMSON }, 12, Vector3.new(0.1, 0.1, 0.1), 2.8, 0.6, 1.2, Enum.PartType.Ball) -- ember burst
	elseif templateId == ORRERY then
		flash(Vector3.new(0.6, 0.6, 0.6), CFrame.new(p), WHITE_GOLD, Enum.PartType.Ball, 0, 0.5, Vector3.new(4.2, 4.2, 4.2)) -- supernova
		flash(Vector3.new(0.6, 0.6, 0.6), CFrame.new(p), STAR_BLUE, Enum.PartType.Ball, 0.4, 0.7, Vector3.new(6, 6, 6))
	elseif templateId == CODEX then
		burst(p, { PETAL, Color3.fromRGB(250, 248, 230) }, 10, Vector3.new(0.08, 0.08, 0.08), 1.4, 1.4, 2.0, Enum.PartType.Ball) -- seed puff
	end
end

local GildedCombat = {}

function GildedCombat.OnRelease(rig: Model, meta: any, args: any)
	local templateId = meta and meta.EquippedArtifactId
	if not WeaponVfxConfig.IsGildforgedId(templateId) then
		return
	end
	local cue = args and args.Cue
	local tier = (cue and cue.Tier) or 1
	local selfPos = if args and args.Self then args.Self() else rig:GetPivot().Position
	local targetPos = if args and args.Target then args.Target() else (selfPos + rig:GetPivot().LookVector * 6)
	if camDistance(selfPos) > FAR_LOD_STUDS then
		return
	end
	rememberRelease({ TemplateId = templateId, Target = targetPos, Self = selfPos, At = os.clock() })

	-- The gold-edged swing trail stays on under Reduce Motion.
	local weaponModel = rig:FindFirstChild(HeroSockets.EQUIPPED_NAME)
	if weaponModel and weaponModel:IsA("Model") then
		WeaponVfx.TriggerAttack(weaponModel, tier, if tier >= 3 then 0.42 else nil)
	end
	if tier < 2 then
		return
	end
	local reduce = reducedMotion()

	-- Special: an afterimage of the weapon repeats the swing (the Eclipse Sisters leave three).
	if tier == 2 and not reduce and weaponModel and weaponModel:IsA("Model") then
		if templateId == ECLIPSE then
			afterimage(weaponModel, SHADOW, 3, 0.1)
		else
			local style = WeaponVfxConfig.Elements[tostring(weaponModel:GetAttribute("GildElement") or "")]
			afterimage(weaponModel, if style then style.PrimaryColor:Lerp(GOLD, 0.4) else GOLD, 1, 0)
		end
	end

	local dir = Vector3.new(targetPos.X - selfPos.X, 0, targetPos.Z - selfPos.Z)
	local flatLook = if dir.Magnitude > 0.1 then CFrame.lookAt(selfPos, selfPos + dir.Unit) else rig:GetPivot()

	if templateId == DAWN then
		if tier >= 3 then
			-- A translucent golden tower-shield wall rises in front of the squad, motes falling through it.
			local wallCF = flatLook * CFrame.new(0, 2.2, -3.5)
			flash(Vector3.new(9.5, 0.4, 0.28), wallCF * CFrame.new(0, -2.4, 0), GOLD, nil, 0.4, 1.6, Vector3.new(10.5, 5.8, 0.28), wallCF)
			if not reduce then
				for k = 1, 8 do
					local x = (k / 9 - 0.5) * 9
					local top = wallCF * CFrame.new(x, 2.6, -0.2)
					task.delay(k * 0.08, function()
						flash(Vector3.new(0.12, 0.12, 0.12), top, WHITE_GOLD, Enum.PartType.Ball, 0.1, 1.1, nil, top * CFrame.new(0, -5, 0))
					end)
				end
			end
		end
	elseif templateId == ECLIPSE then
		if tier >= 3 then
			-- A ring of eclipse light closes around the target, then bursts outward as a corona flare.
			local center = CFrame.new(targetPos + Vector3.new(0, 1.6, 0)) * FLAT
			flash(Vector3.new(0.16, 7.5, 7.5), center, SHADOW, Enum.PartType.Cylinder, 0.25, 0.40, Vector3.new(0.16, 1.0, 1.0))
			task.delay(0.4, function()
				flash(Vector3.new(0.2, 2.0, 2.0), center, GOLD, Enum.PartType.Cylinder, 0.2, 0.45, Vector3.new(0.2, 9.0, 9.0))
			end)
		end
	elseif templateId == AURORA then
		if tier >= 3 then
			-- An aurora curtain lights the sky over the target area and arrows of light rain through it.
			flash(Vector3.new(12, 0.2, 5.5), CFrame.new(targetPos + Vector3.new(0, 11, 0)), AURORA_TEAL, nil, 0.35, 1.4, Vector3.new(14, 4.5, 6.5))
			flash(Vector3.new(10, 0.18, 4.5), CFrame.new(targetPos + Vector3.new(0, 11.4, 0)) * CFrame.Angles(0, 0.25, 0), AURORA_PINK, nil, 0.45, 1.4, Vector3.new(12, 3.5, 5.5))
			for k = 1, 7 do
				local off = Vector3.new((math.random() - 0.5) * 8, 0, (math.random() - 0.5) * 4)
				local from = CFrame.lookAt(targetPos + off + Vector3.new(0, 10, 0), targetPos + off)
				task.delay(0.2 + k * 0.09, function()
					flash(Vector3.new(0.08, 0.08, 1.6), from, WHITE_GOLD, nil, 0.1, 0.35, nil, from * CFrame.new(0, 0, -9.5))
				end)
			end
		else
			-- Mid-flight the arrow passes through a prism flash and splits into three.
			local mid = selfPos:Lerp(targetPos, 0.45) + Vector3.new(0, 2.0, 0)
			flash(Vector3.new(1.2, 1.2, 1.2), CFrame.new(mid), AURORA_PINK, Enum.PartType.Ball, 0.25, 0.30, Vector3.new(3.0, 3.0, 3.0))
			for k = -1, 1 do
				local aim = CFrame.lookAt(mid, targetPos + Vector3.new(0, 1.4, 0)) * CFrame.Angles(0, k * 0.18, 0)
				flash(Vector3.new(0.07, 0.07, 1.4), aim, ({ AURORA_TEAL, WHITE_GOLD, AURORA_VIOLET })[k + 2], nil, 0.1, 0.25, nil, aim * CFrame.new(0, 0, -(targetPos - mid).Magnitude))
			end
		end
	elseif templateId == WYRM then
		if tier >= 3 then
			-- On the final chop a spectral dragon head roars out of the blade along the strike.
			local head = flatLook * CFrame.new(0, 2.2, -1.5)
			flash(Vector3.new(2.2, 1.8, 2.8), head, CRIMSON, nil, 0.25, 0.6, Vector3.new(4.2, 3.6, 5.5), head * CFrame.new(0, 0, -5))
			flash(Vector3.new(1.6, 0.5, 2.2), head * CFrame.new(0, -1.1, -0.4), EMBER, nil, 0.3, 0.6, Vector3.new(3.2, 0.8, 4.4), head * CFrame.new(0, -1.4, -5.4))
			groundRing(targetPos + Vector3.new(0, 0.2, 0), 3, GOLD, 0.28, 0.55, 11)
		end
	elseif templateId == ORRERY then
		if tier >= 3 then
			-- A large armillary sphere unfolds above the target area and meteors fall through it.
			local sky = CFrame.new(targetPos + Vector3.new(0, 9.5, 0))
			flash(Vector3.new(0.22, 2, 2), sky * CFrame.Angles(0.5, 0, math.rad(90)), GOLD, Enum.PartType.Cylinder, 0.45, 1.3, Vector3.new(0.22, 11.5, 11.5))
			flash(Vector3.new(0.22, 2, 2), sky * CFrame.Angles(-0.5, 0.4, math.rad(90)), STAR_BLUE, Enum.PartType.Cylinder, 0.5, 1.3, Vector3.new(0.22, 9.5, 9.5))
			flash(Vector3.new(0.22, 2, 2), sky * CFrame.Angles(0, 1.2, 0), GOLD, Enum.PartType.Cylinder, 0.5, 1.3, Vector3.new(0.22, 10.5, 10.5))
			for k = 1, 5 do
				local land = targetPos + Vector3.new((math.random() - 0.5) * 7, 0, (math.random() - 0.5) * 7)
				local from = CFrame.lookAt(land + Vector3.new(3, 12, 2), land)
				task.delay(0.25 + k * 0.12, function()
					flash(Vector3.new(0.5, 0.5, 1.6), from, WHITE_GOLD, Enum.PartType.Ball, 0.05, 0.3, nil, CFrame.lookAt(land, land - from.LookVector))
					task.delay(0.3, function()
						groundRing(land, 0.8, GOLD, 0.2, 0.4, 3.5)
					end)
				end)
			end
		else
			-- The hero draws a constellation glyph in the air before casting; it stays for 0.5 s.
			local glyph = flatLook * CFrame.new(0, 2.6, -1.4)
			local stars = { Vector3.new(-0.8, 0.5, 0), Vector3.new(-0.2, 0.9, 0), Vector3.new(0.5, 0.4, 0), Vector3.new(0.2, -0.4, 0), Vector3.new(-0.6, -0.5, 0) }
			for i, s in stars do
				local nxt = stars[i % #stars + 1]
				local a, b = glyph * s, glyph * nxt
				flash(Vector3.new(0.05, 0.05, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), GOLD, nil, 0.2, 0.5)
				flash(Vector3.new(0.16, 0.16, 0.16), CFrame.new(a), WHITE_GOLD, Enum.PartType.Ball, 0.05, 0.5)
			end
		end
	elseif templateId == CODEX then
		if tier >= 3 then
			-- A tree of light grows behind the hero; its canopy rains petals over allies in range.
			local trunk = flatLook * CFrame.new(0, 0, 2.5)
			flash(Vector3.new(1.2, 0.5, 1.2), trunk * CFrame.new(0, 0.25, 0), WHITE_GOLD, nil, 0.32, 1.6, Vector3.new(1.2, 9.0, 1.2), trunk * CFrame.new(0, 4.5, 0))
			flash(Vector3.new(2, 1, 2), trunk * CFrame.new(0, 8.8, 0), JADE, Enum.PartType.Ball, 0.38, 1.6, Vector3.new(9.5, 2.6, 9.5))
			if not reduce then
				for k = 1, 10 do
					local from = trunk * CFrame.new((math.random() - 0.5) * 8, 8.5, (math.random() - 0.5) * 8)
					task.delay(0.3 + k * 0.07, function()
						flash(Vector3.new(0.18, 0.06, 0.18), from, PETAL, Enum.PartType.Ball, 0.1, 1.3, nil, from * CFrame.new(math.random() - 0.5, -8, math.random() - 0.5))
					end)
				end
			end
		else
			-- A page tears free and becomes a glowing butterfly that flies to its target.
			local from = CFrame.lookAt(selfPos + Vector3.new(0, 2.2, 0), targetPos + Vector3.new(0, 1.6, 0))
			local to = CFrame.lookAt(targetPos + Vector3.new(0, 1.6, 0), targetPos + Vector3.new(0, 1.6, 0) + from.LookVector)
			for side = -1, 1, 2 do
				flash(Vector3.new(0.5, 0.05, 0.4), from * CFrame.new(side * 0.25, 0, 0) * CFrame.Angles(0, 0, side * 0.4), JADE:Lerp(PETAL, 0.4), nil, 0.1, 0.45, nil,
					to * CFrame.new(side * 0.25, 0, 0) * CFrame.Angles(0, 0, -side * 0.4))
			end
		end
	end
end

-- `kind` is "BASIC" or "SPECIAL"; `crit` is the server's Overdrive flag on the hit.
function GildedCombat.OnHit(pos: Vector3, kind: string, crit: boolean)
	if typeof(pos) ~= "Vector3" or camDistance(pos) > FAR_LOD_STUDS then
		return
	end
	local templateId = attribute(pos, HIT_WINDOW)
	if not templateId then
		return
	end
	playHit(templateId, pos, kind)
	if crit and not reducedMotion() then
		playSignatureBurst(templateId, pos)
	end
end

function GildedCombat.OnKill(pos: Vector3)
	if typeof(pos) ~= "Vector3" or reducedMotion() or camDistance(pos) > FAR_LOD_STUDS then
		return
	end
	local templateId = attribute(pos, KILL_WINDOW)
	if templateId then
		playSignatureBurst(templateId, pos)
	end
end

_G.GildedAnvilCombatFx = GildedCombat
