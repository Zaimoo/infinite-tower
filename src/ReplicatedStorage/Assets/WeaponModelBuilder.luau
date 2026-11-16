--!strict
-- ReplicatedStorage/Assets/WeaponModelBuilder.luau
-- Authoritative Modular 3D Weapon Model Factory & Setup.
-- Populates ReplicatedStorage.Assets.Weapons with modular weapon prefabs:
--   - weapon_bow (Marksman bows: Hunter's Shortbow, Recurve, Crystal Greatbow)
--   - weapon_sword (bare sword prefab, base of weapon_sword_shield)
--   - weapon_sword_shield (Vanguard sword & shield: Broadswords, Claymores, Aegis Core)
--   - weapon_daggers (Striker dual daggers: Rogue Daggers, Shadow Fangs)
--   - weapon_axe (Berserker two-handed greataxes)
--   - weapon_staff (Scholar staves: Ruby Staff, Archmage Scepter)
--   - weapon_tome (Healer tomes: Pyromancer Tome, Eldritch Grimoire)

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GildedAnvilMeshData = require(script.Parent:WaitForChild("GildedAnvilMeshData"))
local SwordBowMeshData = require(script.Parent:WaitForChild("SwordBowMeshData"))

local WeaponModelBuilder = {}

-- Scripts cannot write MeshPart.MeshId ("lacking capability NotAccessible"), so a MeshPart for an
-- uploaded mesh has to come from AssetService:CreateMeshPartAsync. Each mesh is loaded once and cloned.
local uploadedMeshCache: { [string]: MeshPart } = {}

local function loadUploadedMesh(meshId: string)
	if uploadedMeshCache[meshId] then return end
	local ok, mp = pcall(function(): any
		return AssetService:CreateMeshPartAsync(Content.fromUri(meshId))
	end)
	if ok and mp then
		uploadedMeshCache[meshId] = mp
	else
		warn(`[WeaponModelBuilder] Could not load mesh {meshId}: {mp}`)
	end
end

-- Loads every mesh in `meshIds` in parallel (CreateMeshPartAsync yields per call) and waits for them.
local function prefetchUploadedMeshes(meshIds: { string })
	local pending = 0
	local seen: { [string]: boolean } = {}
	for _, meshId in meshIds do
		if not uploadedMeshCache[meshId] and not seen[meshId] then
			seen[meshId] = true
			pending += 1
			task.spawn(function()
				loadUploadedMesh(meshId)
				pending -= 1
			end)
		end
	end
	local deadline = os.clock() + 30
	while pending > 0 and os.clock() < deadline do
		task.wait()
	end
end

-- A MeshPart showing the uploaded mesh `meshId` (an empty MeshPart if the mesh could not load).
local function newUploadedMeshPart(meshId: string?): MeshPart
	if type(meshId) == "string" and meshId ~= "" then
		loadUploadedMesh(meshId)
		local template = uploadedMeshCache[meshId]
		if template then return template:Clone() end
	end
	return Instance.new("MeshPart")
end

local function makePart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.Anchored = false
	p.Parent = parent
	return p
end

local function makeWedge(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): WedgePart
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.Anchored = false
	p.Parent = parent
	return p
end

local function makeCylinder(parent: Instance, name: string, lengthY: number, diameter: number, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(lengthY, diameter, diameter)
	p.CFrame = cf * CFrame.Angles(0, 0, math.rad(90))
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.Anchored = false
	p.Parent = parent
	return p
end

local function makeBall(parent: Instance, name: string, diameter: number, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(diameter, diameter, diameter)
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.Anchored = false
	p.Parent = parent
	return p
end

local function weldTo(primary: BasePart, part: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = primary
	w.Part1 = part
	w.Parent = primary
	return w
end

-- Socket attachments (hero-rig-rebuild-plan.md, section 3). Every Grip follows one rule:
-- UpVector runs along the handle toward the weapon's head, LookVector is the weapon's
-- working direction. HeroSockets welds a Grip to the hero's matching hand attachment.
local function addSocket(part: BasePart, name: string, position: Vector3, rotationDegrees: Vector3?)
	local existing = part:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local rot = rotationDegrees or Vector3.zero
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.CFrame = CFrame.new(position) * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
	attachment.Parent = part
	return attachment
end

-- Studs between a greataxe's two hands along the haft (the Blender generator uses the same gap).
local AXE_HAND_GAP = 1.7

-- Blades and axe heads sit along handle +Y with their edge facing handle +X, so the grip
-- looks along +X (CFrame.Angles(0, -90, 0) turns -Z onto +X and keeps +Y).
local EDGE_PLUS_X = Vector3.new(0, -90, 0)

-- ============================================================================
-- VANGUARD SWORDS & MARKSMAN BOWS - Blender-authored artifact meshes
-- ============================================================================
-- The 14 SWORD_SHIELD and 14 BOW artifacts come from tools/blender/generate_vanguard_swords.py
-- and generate_marksman_bows.py; SwordBowMeshData holds their uploaded meshes, materials and
-- sockets. Handle space is the Studio importer's frame (see SwordBowMeshData), which only turns
-- the sockets: Grip, ShieldMount and Nock keep their meaning for HeroSockets and the renderer.
local SWORD_BOW_PRIMARY: { [string]: string } = { [""] = "Handle", OffhandShield = "HandleS", HunterArrow = "ArrowShaft" }

local function makeMeshSwordBow(name: string): Model
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local weaponsFolder = assets and assets:FindFirstChild("Weapons")
	local existing = weaponsFolder and weaponsFolder:FindFirstChild(name)
	if existing and existing:IsA("Model") then
		return existing:Clone()
	end

	local data = SwordBowMeshData[name]
	assert(data, `No sword/bow mesh data for {name}`)

	local model = Instance.new("Model")
	model.Name = name
	local subModels: { [string]: Model } = {}
	local byName: { [string]: BasePart } = {}
	for _, info in data.Parts do
		local p = newUploadedMeshPart(info.MeshId)
		p.Name = info.Name
		p.Size = info.Size
		p.CFrame = CFrame.new(info.Offset)
		p.Material = info.Material
		p.Color = info.Color
		p.Transparency = info.Transparency
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.Anchored = false
		p.CastShadow = false
		if info.Assembly == "" then
			p.Parent = model
		else
			local sub = subModels[info.Assembly]
			if not sub then
				sub = Instance.new("Model")
				sub.Name = info.Assembly
				sub.Parent = model
				subModels[info.Assembly] = sub
			end
			p.Parent = sub
		end
		byName[info.Name] = p
	end

	local handle = byName.Handle
	assert(handle, `Handle part missing for {name}`)
	model.PrimaryPart = handle
	for assembly, sub in subModels do
		sub.PrimaryPart = byName[SWORD_BOW_PRIMARY[assembly]]
	end

	-- Every part is welded to its own assembly's primary; the nocked arrow rides on the bow.
	for _, info in data.Parts do
		local part = byName[info.Name]
		local primary = byName[SWORD_BOW_PRIMARY[info.Assembly]] or handle
		if part ~= primary then
			weldTo(primary, part)
		end
	end
	if byName.ArrowShaft then
		weldTo(handle, byName.ArrowShaft)
	end

	for _, s in data.Sockets do
		local part = byName[s.Part]
		if part then
			addSocket(part, s.Name, s.Position, Vector3.new(0, s.RotationY, 0))
		end
	end

	-- Apply client-side weapon VFX (glints, lights, auras, trails)
	local combatVfx = assets and assets:FindFirstChild("CombatVfx")
	local weaponVfxMod = combatVfx and combatVfx:FindFirstChild("WeaponVfx")
	if weaponVfxMod then
		local ok, WeaponVfx = pcall(require, weaponVfxMod)
		if ok and WeaponVfx and WeaponVfx.Apply then
			WeaponVfx.Apply(model, data.Type, data.RarityTier, name)
		end
	end

	return model
end

-- ============================================================================
-- 1. WEAPON_BOW (Hunter & Ranger Bow)
-- Handle space: stave along +Y (upper limb up), string behind the riser at +Z,
-- nocked arrow flying toward -Z, resting on the riser's +X side.
-- ============================================================================
local BOW_STRING_Z = 0.42
local BOW_TIP_Y = 1.84
local ARROW_REST = Vector3.new(0.2, 0.1, 0)

local function alignHunterArrow(bowModel: Model, handle: BasePart)
	local arrow = bowModel:FindFirstChild("HunterArrow", true)
	if not arrow then return end

	local shaft = arrow:FindFirstChild("ArrowShaft") :: BasePart?
	local head = arrow:FindFirstChild("ArrowHead") :: BasePart?
	local f1 = arrow:FindFirstChild("ArrowFletch_1") :: BasePart?
	local f2 = arrow:FindFirstChild("ArrowFletch_2") :: BasePart?
	local f3 = arrow:FindFirstChild("ArrowFletch_3") :: BasePart?

	if not shaft then return end

	-- Clean old arrow welds
	for _, d in ipairs(bowModel:GetDescendants()) do
		if d:IsA("WeldConstraint") or d:IsA("Weld") or d:IsA("Motor6D") then
			local p0 = d.Part0
			local p1 = d.Part1
			if (p0 and p0.Name:find("Arrow")) or (p1 and p1.Name:find("Arrow")) then
				d:Destroy()
			end
		end
	end

	-- Nock on the string, shaft (2 studs) pointing at -Z past the riser.
	local nockAtt = handle:FindFirstChild("Nock") :: Attachment?
	local pNock = if nockAtt then nockAtt.Position else Vector3.new(ARROW_REST.X, ARROW_REST.Y, BOW_STRING_Z)
	local pCenter = pNock + Vector3.new(0, 0, -1.0)
	local shaftCFInHandle = CFrame.lookAt(pCenter, pCenter + Vector3.new(0, 0, -1), Vector3.new(0, 1, 0))
	local shaftWorld = handle.CFrame * shaftCFInHandle
	shaft.CFrame = shaftWorld

	if head then
		head.CFrame = shaftWorld * CFrame.new(0, -0.02, -1.06)
		local wHead = Instance.new("WeldConstraint")
		wHead.Part0 = shaft
		wHead.Part1 = head
		wHead.Parent = head
	end

	if f1 then
		f1.CFrame = shaftWorld * CFrame.new(0, 0.035, 0.85)
		local w = Instance.new("WeldConstraint")
		w.Part0 = shaft
		w.Part1 = f1
		w.Parent = f1
	end
	if f2 then
		f2.CFrame = shaftWorld * CFrame.new(-0.030, -0.018, 0.85) * CFrame.Angles(0, 0, math.rad(120))
		local w = Instance.new("WeldConstraint")
		w.Part0 = shaft
		w.Part1 = f2
		w.Parent = f2
	end
	if f3 then
		f3.CFrame = shaftWorld * CFrame.new(0.030, -0.018, 0.85) * CFrame.Angles(0, 0, math.rad(-120))
		local w = Instance.new("WeldConstraint")
		w.Part0 = shaft
		w.Part1 = f3
		w.Parent = f3
	end

	local wHandle = Instance.new("WeldConstraint")
	wHandle.Part0 = handle
	wHandle.Part1 = shaft
	wHandle.Parent = shaft
end

local function createHunterArrow(parentModel: Model, handle: BasePart)
	local arrowModel = Instance.new("Model")
	arrowModel.Name = "HunterArrow"
	arrowModel.Parent = parentModel
	makePart(arrowModel, "ArrowShaft", Vector3.new(0.04, 0.04, 2.0), CFrame.new(0, 0, 0), Color3.fromRGB(120, 80, 50))
	makeWedge(arrowModel, "ArrowHead", Vector3.new(0.08, 0.12, 0.28), CFrame.new(0, 0, 0), Color3.fromRGB(90, 85, 80), Enum.Material.Slate)
	makePart(arrowModel, "ArrowFletch_1", Vector3.new(0.01, 0.06, 0.22), CFrame.new(0, 0, 0), Color3.fromRGB(180, 175, 170))
	makePart(arrowModel, "ArrowFletch_2", Vector3.new(0.01, 0.06, 0.22), CFrame.new(0, 0, 0), Color3.fromRGB(60, 55, 50))
	makePart(arrowModel, "ArrowFletch_3", Vector3.new(0.01, 0.06, 0.22), CFrame.new(0, 0, 0), Color3.fromRGB(180, 175, 170))
	alignHunterArrow(parentModel, handle)
end

function WeaponModelBuilder.BuildBow(): Model
	-- Built from code only: no Studio-authored or hero-baked bow is consulted, so the
	-- geometry below is the single definition the Grip attachment is measured against.
	local model = Instance.new("Model")
	model.Name = "weapon_bow"
	local leatherBrown = Color3.fromRGB(115, 80, 50)
	local bowGreen = Color3.fromRGB(85, 195, 125)
	local stringColor = Color3.fromRGB(230, 240, 255)

	local handle = makePart(model, "Handle", Vector3.new(0.3, 0.8, 0.35), CFrame.new(0, 0, 0), leatherBrown)
	model.PrimaryPart = handle

	-- Limbs bow forward from the riser and curve back so their tips meet the string.
	local limbAngle = math.rad(22)
	local topLimb = makePart(model, "BowLimbUpper", Vector3.new(0.22, 1.6, 0.25), CFrame.new(0, 1.1, 0.12) * CFrame.Angles(limbAngle, 0, 0), bowGreen)
	weldTo(handle, topLimb)

	local botLimb = makePart(model, "BowLimbLower", Vector3.new(0.22, 1.6, 0.25), CFrame.new(0, -1.1, 0.12) * CFrame.Angles(-limbAngle, 0, 0), bowGreen)
	weldTo(handle, botLimb)

	local stringPart = makePart(model, "BowString", Vector3.new(0.06, BOW_TIP_Y * 2, 0.06), CFrame.new(0, 0, BOW_STRING_Z), stringColor)
	weldTo(handle, stringPart)

	addSocket(handle, "Grip", Vector3.zero) -- up = upper limb, look = arrow flight (-Z)
	addSocket(handle, "Nock", Vector3.new(ARROW_REST.X, ARROW_REST.Y, BOW_STRING_Z))
	addSocket(handle, "TipUpper", Vector3.new(0, BOW_TIP_Y, BOW_STRING_Z))
	addSocket(handle, "TipLower", Vector3.new(0, -BOW_TIP_Y, BOW_STRING_Z))

	createHunterArrow(model, handle)

	return model
end

-- ============================================================================
-- Hunter's Shortbow (art_hunters_shortbow)
-- ============================================================================
-- ============================================================================
-- 1. Hunter's Shortbow (art_hunters_shortbow) - Common Standard
-- ============================================================================
function WeaponModelBuilder.BuildHuntersShortbow(): Model
	return makeMeshSwordBow("art_hunters_shortbow")
end

-- ============================================================================
-- 2. Reinforced Longbow (art_reinforced_longbow) - Common Enhanced
-- ============================================================================
function WeaponModelBuilder.BuildReinforcedLongbow(): Model
	return makeMeshSwordBow("art_reinforced_longbow")
end

-- ============================================================================
-- 3. Recurve Composite (art_recurve_composite) - Uncommon Standard
-- ============================================================================
function WeaponModelBuilder.BuildRecurveComposite(): Model
	return makeMeshSwordBow("art_recurve_composite")
end

-- ============================================================================
-- 4. Gale Force Composite (art_gale_force_composite) - Uncommon Enhanced
-- ============================================================================
function WeaponModelBuilder.BuildGaleForceComposite(): Model
	return makeMeshSwordBow("art_gale_force_composite")
end

-- ============================================================================
-- 5. Stormstrider Longbow (art_stormstrider_longbow) - Rare Standard
-- ============================================================================
function WeaponModelBuilder.BuildStormstriderLongbow(): Model
	return makeMeshSwordBow("art_stormstrider_longbow")
end

-- ============================================================================
-- 6. Thunderhead Recurve (art_thunderhead_recurve) - Rare Enhanced
-- ============================================================================
function WeaponModelBuilder.BuildThunderheadRecurve(): Model
	return makeMeshSwordBow("art_thunderhead_recurve")
end

-- ============================================================================
-- 7. Crystal Greatbow (art_crystal_greatbow) - Superior Standard
-- ============================================================================
function WeaponModelBuilder.BuildCrystalGreatbow(): Model
	return makeMeshSwordBow("art_crystal_greatbow")
end

-- ============================================================================
-- 8. Prismatic Arbalest (art_prismatic_arbalest) - Superior Enhanced
-- ============================================================================
function WeaponModelBuilder.BuildPrismaticArbalest(): Model
	return makeMeshSwordBow("art_prismatic_arbalest")
end

-- ============================================================================
-- 9. Phoenix Flatbow (art_phoenix_flatbow) - Exalted Standard
-- ============================================================================
function WeaponModelBuilder.BuildPhoenixFlatbow(): Model
	return makeMeshSwordBow("art_phoenix_flatbow")
end

-- ============================================================================
-- 10. Solar Flare Recurve (art_solar_flare_recurve) - Exalted Enhanced
-- ============================================================================
function WeaponModelBuilder.BuildSolarFlareRecurve(): Model
	return makeMeshSwordBow("art_solar_flare_recurve")
end

-- ============================================================================
-- 11. Celestial Zenith (art_celestial_zenith) - Legendary Standard
-- ============================================================================
function WeaponModelBuilder.BuildCelestialZenith(): Model
	return makeMeshSwordBow("art_celestial_zenith")
end

-- ============================================================================
-- 12. Supernova Greatbow (art_supernova_greatbow) - Legendary Enhanced
-- ============================================================================
function WeaponModelBuilder.BuildSupernovaGreatbow(): Model
	return makeMeshSwordBow("art_supernova_greatbow")
end

-- ============================================================================
-- 13. Astrea Cosmic Bow (art_astrea_cosmic_bow) - Origin Standard
-- ============================================================================
function WeaponModelBuilder.BuildAstreaCosmicBow(): Model
	return makeMeshSwordBow("art_astrea_cosmic_bow")
end

-- ============================================================================
-- 14. Infinity Genesis Bow (art_infinity_genesis_bow) - Origin Enhanced
-- ============================================================================
function WeaponModelBuilder.BuildInfinityGenesisBow(): Model
	return makeMeshSwordBow("art_infinity_genesis_bow")
end

function WeaponModelBuilder.BuildSword(): Model
	local model = Instance.new("Model")
	model.Name = "weapon_sword"

	local steel = Color3.fromRGB(215, 222, 235)
	local gold = Color3.fromRGB(235, 195, 60)
	local darkLeather = Color3.fromRGB(42, 36, 48)

	-- Handle gripped in RightHand
	local handle = makePart(model, "Handle", Vector3.new(0.24, 1.2, 0.24), CFrame.new(0, 0, 0), darkLeather)
	model.PrimaryPart = handle

	-- Pommel
	local pommel = makePart(model, "Pommel", Vector3.new(0.38, 0.35, 0.38), CFrame.new(0, -0.65, 0), gold)
	weldTo(handle, pommel)

	-- Crossguard
	local guard = makePart(model, "Crossguard", Vector3.new(1.3, 0.22, 0.42), CFrame.new(0, 0.65, 0), gold)
	weldTo(handle, guard)

	-- Blade (Extending along Y from guard)
	local blade = makePart(model, "Blade", Vector3.new(0.36, 3.2, 0.1), CFrame.new(0, 2.3, 0), steel, Enum.Material.Metal)
	weldTo(handle, blade)

	-- Blade Tip
	local tip = makeWedge(model, "BladeTip", Vector3.new(0.36, 0.7, 0.1), CFrame.new(0, 4.25, 0) * CFrame.Angles(0, math.pi, 0), steel, Enum.Material.Metal)
	weldTo(handle, tip)

	-- Emissive Rune Core (Glows based on rarity)
	local rune = makePart(model, "BladeRune", Vector3.new(0.08, 2.2, 0.12), CFrame.new(0, 2.2, 0), Color3.fromRGB(120, 200, 255), Enum.Material.Neon)
	weldTo(handle, rune)

	addSocket(handle, "Grip", Vector3.zero, EDGE_PLUS_X) -- up = blade, look = edge

	return model
end

-- ============================================================================
-- 2b. WEAPON_SWORD_SHIELD (Vanguard Sword in RightHand + Kite Shield in LeftHand)
-- ============================================================================
function WeaponModelBuilder.BuildSwordShield(): Model
	local model = WeaponModelBuilder.BuildSword()
	model.Name = "weapon_sword_shield"

	local steel = Color3.fromRGB(150, 158, 172)
	local gold = Color3.fromRGB(235, 195, 60)

	-- Off-hand Shield (LeftHand)
	local shieldModel = Instance.new("Model")
	shieldModel.Name = "OffhandShield"
	shieldModel.Parent = model

	local grip = makePart(shieldModel, "HandleS", Vector3.new(0.2, 0.6, 0.2), CFrame.new(0, 0, 0), gold)
	shieldModel.PrimaryPart = grip

	local face = makePart(shieldModel, "ShieldFace", Vector3.new(0.24, 2.6, 1.6), CFrame.new(-0.3, 0, 0), steel, Enum.Material.Metal)
	weldTo(grip, face)

	local trim = makePart(shieldModel, "ShieldTrim", Vector3.new(0.28, 2.7, 0.16), CFrame.new(-0.3, 0, 0), gold)
	weldTo(grip, trim)

	local crest = makePart(shieldModel, "ShieldCrystal", Vector3.new(0.3, 0.6, 0.6), CFrame.new(-0.36, 0.3, 0), Color3.fromRGB(120, 200, 255), Enum.Material.Neon)
	crest.Shape = Enum.PartType.Ball
	weldTo(grip, crest)

	-- Strapped to the forearm: the mount sits on the back of the face plate, looks out
	-- through the face (-X) and runs up the shield's long axis (+Y).
	addSocket(grip, "ShieldMount", Vector3.new(-0.18, 0, 0), Vector3.new(0, 90, 0))

	return model
end

-- ============================================================================
-- 2c. WEAPON_IRON_BROADSWORD (1★ Vanguard Iron Broadsword & Buckler)
-- ============================================================================
function WeaponModelBuilder.BuildIronBroadsword(): Model
	local model = Instance.new("Model")
	model.Name = "weapon_iron_broadsword"

	local polishedSteel = Color3.fromRGB(212, 216, 223)
	local forgedIron = Color3.fromRGB(140, 146, 158)
	local darkGrip = Color3.fromRGB(30, 29, 36)

	-- Handle gripped in RightHand at (0, 0, 0)
	local handle = makePart(model, "Handle", Vector3.new(0.24, 0.75 * 1.38, 0.24), CFrame.new(0, 0, 0), darkGrip)
	model.PrimaryPart = handle

	-- Ferrule Collar
	local ferrule = makePart(model, "GripFerrule", Vector3.new(0.26 * 1.45, 0.08 * 1.38, 0.26 * 1.45), CFrame.new(0, 0.34 * 1.38, 0), forgedIron, Enum.Material.Metal)
	weldTo(handle, ferrule)

	-- Scent-Stopper Fishtail Pommel
	local pommelNeck = makePart(model, "PommelNeck", Vector3.new(0.25 * 1.45, 0.12 * 1.38, 0.22 * 1.40), CFrame.new(0, -0.42 * 1.38, 0), forgedIron, Enum.Material.Metal)
	weldTo(handle, pommelNeck)
	local pommelBody = makePart(model, "PommelBody", Vector3.new(0.38 * 1.45, 0.22 * 1.38, 0.28 * 1.40), CFrame.new(0, -0.58 * 1.38, 0), forgedIron, Enum.Material.Metal)
	weldTo(handle, pommelBody)
	local pommelCap = makePart(model, "PommelCap", Vector3.new(0.28 * 1.45, 0.08 * 1.38, 0.22 * 1.40), CFrame.new(0, -0.73 * 1.38, 0), polishedSteel, Enum.Material.Metal)
	weldTo(handle, pommelCap)

	-- Cruciform Crossguard with Ecusson
	local guard = makePart(model, "Crossguard", Vector3.new(0.95 * 1.45, 0.12 * 1.38, 0.18 * 1.40), CFrame.new(0, 0.45 * 1.38, 0), forgedIron, Enum.Material.Metal)
	weldTo(handle, guard)
	local ecusson = makePart(model, "GuardEcusson", Vector3.new(0.32 * 1.45, 0.18 * 1.38, 0.22 * 1.40), CFrame.new(0, 0.48 * 1.38, 0), forgedIron, Enum.Material.Metal)
	weldTo(handle, ecusson)

	-- Blade (Ricasso + Fuller + Diamond Spear Point)
	local ricasso = makePart(model, "BladeRicasso", Vector3.new(0.28 * 1.45, 0.32 * 1.38, 0.06 * 1.40), CFrame.new(0, 0.62 * 1.38, 0), forgedIron, Enum.Material.Metal)
	weldTo(handle, ricasso)
	local bladeBody = makePart(model, "Blade", Vector3.new(0.26 * 1.45, 1.80 * 1.38, 0.05 * 1.40), CFrame.new(0, 1.68 * 1.38, 0), polishedSteel, Enum.Material.Metal)
	weldTo(handle, bladeBody)
	local fuller = makePart(model, "FullerGroove", Vector3.new(0.09 * 1.45, 1.60 * 1.38, 0.06 * 1.40), CFrame.new(0, 1.65 * 1.38, 0), forgedIron, Enum.Material.Metal)
	weldTo(handle, fuller)
	local upperBlade = makePart(model, "BladeDiamond", Vector3.new(0.20 * 1.45, 0.70 * 1.38, 0.04 * 1.40), CFrame.new(0, 2.90 * 1.38, 0), polishedSteel, Enum.Material.Metal)
	weldTo(handle, upperBlade)
	local tip = makeWedge(model, "BladeTip", Vector3.new(0.18 * 1.45, 0.35 * 1.38, 0.04 * 1.40), CFrame.new(0, 3.25 * 1.38, 0) * CFrame.Angles(0, math.pi, 0), polishedSteel, Enum.Material.Metal)
	weldTo(handle, tip)

	addSocket(handle, "Grip", Vector3.zero, EDGE_PLUS_X) -- up = blade, look = edge

	-- Off-hand Buckler Shield (LeftHand)
	local shieldModel = Instance.new("Model")
	shieldModel.Name = "OffhandShield"
	shieldModel.Parent = model

	local gripS = makePart(shieldModel, "HandleS", Vector3.new(0.2, 0.6, 0.2), CFrame.new(0, 0, 0), forgedIron)
	shieldModel.PrimaryPart = gripS

	local plate = makePart(shieldModel, "ShieldPlate", Vector3.new(0.12, 1.8, 1.8), CFrame.new(-0.25, 0, 0), forgedIron, Enum.Material.Metal)
	weldTo(gripS, plate)

	local boss = makePart(shieldModel, "ShieldBoss", Vector3.new(0.15, 0.6, 0.6), CFrame.new(-0.33, 0, 0), polishedSteel, Enum.Material.Metal)
	boss.Shape = Enum.PartType.Ball
	weldTo(gripS, boss)

	addSocket(gripS, "ShieldMount", Vector3.new(-0.18, 0, 0), Vector3.new(0, 90, 0))

	return model
end

-- ============================================================================
-- 2d. WEAPON_RUNIC_LONGSWORD (2★ Vanguard Runic Longsword & Heater Shield)
-- ============================================================================
function WeaponModelBuilder.BuildRunicLongsword(): Model
	local model = Instance.new("Model")
	model.Name = "weapon_runic_longsword"

	local frostedSteel = Color3.fromRGB(203, 232, 247)
	local darkForgedIron = Color3.fromRGB(37, 40, 48)
	local obsidianGrip = Color3.fromRGB(24, 24, 31)
	local runicCyan = Color3.fromRGB(0, 229, 255)

	-- Handle gripped in RightHand at (0, 0, 0)
	local handle = makePart(model, "Handle", Vector3.new(0.24, 0.80, 0.24), CFrame.new(0, 0, 0), obsidianGrip)
	model.PrimaryPart = handle

	-- Ferrule Collars
	local topCollar = makePart(model, "GripCollarTop", Vector3.new(0.28, 0.08, 0.28), CFrame.new(0, 0.38, 0), darkForgedIron, Enum.Material.Metal)
	weldTo(handle, topCollar)
	local botCollar = makePart(model, "GripCollarBottom", Vector3.new(0.28, 0.08, 0.28), CFrame.new(0, -0.38, 0), darkForgedIron, Enum.Material.Metal)
	weldTo(handle, botCollar)

	-- Gothic Pommel Cage & Runic Crystal Core
	local pommelCage = makePart(model, "PommelCage", Vector3.new(0.36, 0.35, 0.36), CFrame.new(0, -0.62, 0), darkForgedIron, Enum.Material.Metal)
	weldTo(handle, pommelCage)
	local pommelGem = makePart(model, "PommelGem", Vector3.new(0.22, 0.26, 0.22), CFrame.new(0, -0.62, 0), runicCyan, Enum.Material.Neon)
	weldTo(handle, pommelGem)
	local pommelTip = makePart(model, "PommelFinial", Vector3.new(0.12, 0.12, 0.12), CFrame.new(0, -0.82, 0), darkForgedIron, Enum.Material.Metal)
	weldTo(handle, pommelTip)

	-- 8-Point Astral Star Crossguard
	local guardCenter = makePart(model, "CrossguardStar", Vector3.new(0.52, 0.24, 0.26), CFrame.new(0, 0.55, 0), darkForgedIron, Enum.Material.Metal)
	weldTo(handle, guardCenter)
	local starRune = makePart(model, "GuardStarRune", Vector3.new(0.26, 0.26, 0.28), CFrame.new(0, 0.55, 0), runicCyan, Enum.Material.Neon)
	weldTo(handle, starRune)

	-- Swept Gothic Quillons
	local leftQuillon = makePart(model, "QuillonLeft", Vector3.new(0.48, 0.14, 0.16), CFrame.new(-0.46, 0.62, 0) * CFrame.Angles(0, 0, math.rad(-22)), darkForgedIron, Enum.Material.Metal)
	weldTo(handle, leftQuillon)
	local rightQuillon = makePart(model, "QuillonRight", Vector3.new(0.48, 0.14, 0.16), CFrame.new(0.46, 0.62, 0) * CFrame.Angles(0, 0, math.rad(22)), darkForgedIron, Enum.Material.Metal)
	weldTo(handle, rightQuillon)

	-- Blade (Ricasso + Fuller + Diamond Spear Point)
	local ricasso = makePart(model, "BladeRicasso", Vector3.new(0.46, 0.25, 0.08), CFrame.new(0, 0.78, 0), frostedSteel, Enum.Material.Metal)
	weldTo(handle, ricasso)
	local bladeBody = makePart(model, "Blade", Vector3.new(0.40, 2.40, 0.07), CFrame.new(0, 2.05, 0), frostedSteel, Enum.Material.Metal)
	weldTo(handle, bladeBody)
	local fullerRune = makePart(model, "FullerRune", Vector3.new(0.16, 2.20, 0.085), CFrame.new(0, 2.05, 0), runicCyan, Enum.Material.Neon)
	weldTo(handle, fullerRune)
	local bladeDiamond = makePart(model, "BladeDiamond", Vector3.new(0.26, 0.55, 0.05), CFrame.new(0, 3.48, 0), frostedSteel, Enum.Material.Metal)
	weldTo(handle, bladeDiamond)
	local tip = makeWedge(model, "BladeTip", Vector3.new(0.22, 0.35, 0.05), CFrame.new(0, 3.92, 0) * CFrame.Angles(0, math.pi, 0), frostedSteel, Enum.Material.Metal)
	weldTo(handle, tip)

	-- Sockets & Attachments
	addSocket(handle, "Grip", Vector3.zero, EDGE_PLUS_X)
	local trailBottom = addSocket(handle, "TrailBottom", Vector3.new(0, 0.75, 0))
	local trailTop = addSocket(handle, "TrailTop", Vector3.new(0, 4.10, 0))
	local vfxCore = addSocket(handle, "VFXCore", Vector3.new(0, 2.40, 0))

	-- Weapon Swing Trail
	local trail = Instance.new("Trail")
	trail.Name = "SwingTrail"
	trail.Attachment0 = trailBottom
	trail.Attachment1 = trailTop
	trail.FaceCamera = true
	trail.Lifetime = 0.35
	trail.LightEmission = 1.0
	trail.LightInfluence = 0.0
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Color3.fromRGB(0, 229, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(56, 189, 248)),
		ColorSequenceKeypoint.new(1.0, Color3.fromRGB(30, 64, 175)),
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
	trail.Enabled = false
	trail.Parent = handle

	-- VFXCore ParticleEmitter (Frost runes and ice motes)
	local particles = Instance.new("ParticleEmitter")
	particles.Name = "RunicAuraEmitter"
	particles.Rate = 12
	particles.Lifetime = NumberRange.new(0.6, 1.2)
	particles.Speed = NumberRange.new(0.4, 1.2)
	particles.Drag = 2.0
	particles.SpreadAngle = Vector2.new(35, 35)
	particles.EmissionDirection = Enum.NormalId.Top
	particles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Color3.fromRGB(0, 229, 255)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(100, 216, 255)),
		ColorSequenceKeypoint.new(1.0, Color3.fromRGB(15, 30, 90)),
	})
	particles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 1.0),
		NumberSequenceKeypoint.new(0.2, 0.1),
		NumberSequenceKeypoint.new(0.8, 0.3),
		NumberSequenceKeypoint.new(1.0, 1.0),
	})
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 0.25),
		NumberSequenceKeypoint.new(0.5, 0.45),
		NumberSequenceKeypoint.new(1.0, 0.05),
	})
	particles.LightEmission = 1.0
	particles.LightInfluence = 0.0
	particles.Parent = vfxCore

	local light = Instance.new("PointLight")
	light.Name = "RunicGlow"
	light.Color = runicCyan
	light.Range = 9.0
	light.Brightness = 1.8
	light.Shadows = false
	light.Parent = vfxCore

	-- Off-hand Heater Shield
	local shieldModel = Instance.new("Model")
	shieldModel.Name = "OffhandShield"
	shieldModel.Parent = model

	local gripS = makePart(shieldModel, "HandleS", Vector3.new(0.2, 0.6, 0.2), CFrame.new(0, 0, 0), darkForgedIron)
	shieldModel.PrimaryPart = gripS

	local plate = makePart(shieldModel, "ShieldPlate", Vector3.new(0.14, 2.2, 1.6), CFrame.new(-0.25, 0, 0), frostedSteel, Enum.Material.Metal)
	weldTo(gripS, plate)

	local boss = makePart(shieldModel, "ShieldBoss", Vector3.new(0.18, 0.7, 0.7), CFrame.new(-0.33, 0.2, 0), runicCyan, Enum.Material.Neon)
	boss.Shape = Enum.PartType.Ball
	weldTo(gripS, boss)

	addSocket(gripS, "ShieldMount", Vector3.new(-0.18, 0, 0), Vector3.new(0, 90, 0))

	return model
end


-- ============================================================================
-- VANGUARD ARTIFACT WEAPONS (ALL 14 SWORDS & SHIELDS)
-- ============================================================================

function WeaponModelBuilder.BuildIronBroadswordArtifact(): Model
	return makeMeshSwordBow("art_iron_broadsword")
end


function WeaponModelBuilder.BuildTemperedBastardSword(): Model
	return makeMeshSwordBow("art_tempered_bastard_sword")
end


function WeaponModelBuilder.BuildRunicLongswordArtifact(): Model
	return makeMeshSwordBow("art_runic_longsword")
end


function WeaponModelBuilder.BuildKnightlyEstoc(): Model
	return makeMeshSwordBow("art_knightly_estoc")
end


function WeaponModelBuilder.BuildPaladinSpatha(): Model
	return makeMeshSwordBow("art_paladin_spatha")
end


function WeaponModelBuilder.BuildVanguardWardenBastion(): Model
	return makeMeshSwordBow("art_vanguard_warden_bastion")
end


function WeaponModelBuilder.BuildCrystalClaymore(): Model
	return makeMeshSwordBow("art_crystal_claymore")
end


function WeaponModelBuilder.BuildResonantBulwark(): Model
	return makeMeshSwordBow("art_resonant_bulwark")
end


function WeaponModelBuilder.BuildPaladinClaymoreArtifact(): Model
	return makeMeshSwordBow("art_paladin_claymore")
end


function WeaponModelBuilder.BuildAegisOfValor(): Model
	return makeMeshSwordBow("art_aegis_of_valor")
end


function WeaponModelBuilder.BuildBladeOfTheRift(): Model
	return makeMeshSwordBow("art_blade_of_the_rift")
end


function WeaponModelBuilder.BuildAegisCore(): Model
	return makeMeshSwordBow("art_aegis_core")
end


function WeaponModelBuilder.BuildAstralExecutioner(): Model
	return makeMeshSwordBow("art_astral_executioner")
end


function WeaponModelBuilder.BuildGenesisWorldbreaker(): Model
	return makeMeshSwordBow("art_genesis_worldbreaker")
end

-- ============================================================================
-- 3. WEAPON_DAGGERS (Dual Rogue Trench Stilettos)
-- ============================================================================
function WeaponModelBuilder.BuildDaggers(): Model
	local model = Instance.new("Model")
	model.Name = "weapon_daggers"

	local obsidian = Color3.fromRGB(35, 32, 45)
	local crimsonGlow = Color3.fromRGB(240, 70, 95)
	local darkGrip = Color3.fromRGB(25, 20, 30)

	-- Main Hand Dagger (RightHand)
	local handle = makePart(model, "Handle", Vector3.new(0.2, 0.8, 0.2), CFrame.new(0, 0, 0), darkGrip)
	model.PrimaryPart = handle

	local guard = makePart(model, "Crossguard", Vector3.new(0.7, 0.15, 0.25), CFrame.new(0, 0.45, 0), obsidian)
	weldTo(handle, guard)

	local blade = makePart(model, "Blade", Vector3.new(0.24, 1.6, 0.08), CFrame.new(0, 1.3, 0), obsidian, Enum.Material.Metal)
	weldTo(handle, blade)

	local tip = makeWedge(model, "BladeTip", Vector3.new(0.24, 0.45, 0.08), CFrame.new(0, 2.3, 0) * CFrame.Angles(0, math.pi, 0), obsidian, Enum.Material.Metal)
	weldTo(handle, tip)

	local glow = makePart(model, "BladeRune", Vector3.new(0.06, 1.2, 0.09), CFrame.new(0, 1.25, 0), crimsonGlow, Enum.Material.Neon)
	weldTo(handle, glow)

	-- Off-hand Dagger (LeftHand)
	local leftDagger = Instance.new("Model")
	leftDagger.Name = "LeftDagger"
	leftDagger.Parent = model

	local handleL = makePart(leftDagger, "HandleL", Vector3.new(0.2, 0.8, 0.2), CFrame.new(0, 0, 0), darkGrip)
	leftDagger.PrimaryPart = handleL

	local guardL = makePart(leftDagger, "Crossguard", Vector3.new(0.7, 0.15, 0.25), CFrame.new(0, 0.45, 0), obsidian)
	weldTo(handleL, guardL)

	local bladeL = makePart(leftDagger, "Blade", Vector3.new(0.24, 1.6, 0.08), CFrame.new(0, 1.3, 0), obsidian, Enum.Material.Metal)
	weldTo(handleL, bladeL)

	local tipL = makeWedge(leftDagger, "BladeTip", Vector3.new(0.24, 0.45, 0.08), CFrame.new(0, 2.3, 0) * CFrame.Angles(0, math.pi, 0), obsidian, Enum.Material.Metal)
	weldTo(handleL, tipL)

	local glowL = makePart(leftDagger, "BladeRune", Vector3.new(0.06, 1.2, 0.09), CFrame.new(0, 1.25, 0), crimsonGlow, Enum.Material.Neon)
	weldTo(handleL, glowL)

	addSocket(handle, "Grip", Vector3.zero, EDGE_PLUS_X)
	addSocket(handleL, "Grip", Vector3.zero, EDGE_PLUS_X)

	return model
end

-- ============================================================================
-- 4. WEAPON_AXE (generic two-handed greataxe)
-- ============================================================================
function WeaponModelBuilder.BuildAxe(): Model
	local model = Instance.new("Model")
	model.Name = "weapon_axe"

	local ashwood = Color3.fromRGB(115, 85, 55)
	local leather = Color3.fromRGB(70, 48, 32)
	local iron = Color3.fromRGB(165, 172, 185)
	local gold = Color3.fromRGB(235, 195, 60)

	-- Two-handed: a 5.4-stud haft with the head at the top. Grip is the upper (right) hand,
	-- OffhandGrip the lower (left) hand, AXE_HAND_GAP studs towards the butt.
	local handle = makePart(model, "Handle", Vector3.new(0.24, 5.4, 0.24), CFrame.new(0, 0, 0), ashwood)
	model.PrimaryPart = handle

	local pommel = makePart(model, "Pommel", Vector3.new(0.38, 0.3, 0.38), CFrame.new(0, -2.75, 0), iron)
	weldTo(handle, pommel)

	local headCollar = makePart(model, "HeadCollar", Vector3.new(0.42, 0.9, 0.42), CFrame.new(0, 2.0, 0), gold)
	weldTo(handle, headCollar)

	-- Broad beveled blade
	local blade = makePart(model, "Blade", Vector3.new(1.5, 1.9, 0.2), CFrame.new(0.85, 1.95, 0), iron, Enum.Material.Metal)
	weldTo(handle, blade)

	local edge = makeWedge(model, "BladeEdge", Vector3.new(0.2, 2.2, 0.5), CFrame.new(1.85, 1.95, 0) * CFrame.Angles(0, 0, math.rad(-90)), iron, Enum.Material.Metal)
	weldTo(handle, edge)

	-- Counter-spike
	local spike = makeWedge(model, "BackSpike", Vector3.new(0.2, 0.7, 0.5), CFrame.new(-0.46, 2.0, 0) * CFrame.Angles(0, 0, math.rad(90)), iron, Enum.Material.Metal)
	weldTo(handle, spike)

	local gripY = 0.35
	for _, y in { gripY, gripY - AXE_HAND_GAP } do
		local wrap = makePart(model, "GripWrap", Vector3.new(0.3, 0.66, 0.3), CFrame.new(0, y, 0), leather)
		weldTo(handle, wrap)
	end

	addSocket(handle, "Grip", Vector3.new(0, gripY, 0), EDGE_PLUS_X)
	addSocket(handle, "OffhandGrip", Vector3.new(0, gripY - AXE_HAND_GAP, 0), EDGE_PLUS_X)

	return model
end

-- ============================================================================
-- 5. WEAPON_STAFF (Ruby Staff / Archmage Scepter)
-- ============================================================================
function WeaponModelBuilder.BuildStaff(): Model
	local model = Instance.new("Model")
	model.Name = "weapon_staff"

	local darkWood = Color3.fromRGB(55, 40, 30)
	local gold = Color3.fromRGB(240, 200, 70)
	local rubyNeon = Color3.fromRGB(255, 65, 105)

	local handle = makePart(model, "Handle", Vector3.new(0.22, 4.2, 0.22), CFrame.new(0, 0, 0), darkWood)
	model.PrimaryPart = handle

	local pommel = makePart(model, "Pommel", Vector3.new(0.35, 0.35, 0.35), CFrame.new(0, -2.15, 0), gold)
	weldTo(handle, pommel)

	local crown = makePart(model, "StaffHead", Vector3.new(0.9, 0.9, 0.3), CFrame.new(0, 2.2, 0), gold)
	weldTo(handle, crown)

	-- Glowing magic ruby crystal orb
	local orb = makePart(model, "CrystalOrb", Vector3.new(0.65, 0.65, 0.65), CFrame.new(0, 2.65, 0), rubyNeon, Enum.Material.Neon)
	weldTo(handle, orb)

	addSocket(handle, "Grip", Vector3.new(0, -0.4, 0)) -- up = orb, look = crown face (-Z)

	return model
end

-- ============================================================================
-- 6. WEAPON_TOME (Pyromancer Grimoire / Eldritch Tome)
-- ============================================================================
local makeMeshTome: (string) -> Model

function WeaponModelBuilder.BuildTome(): Model
	local model = makeMeshTome("art_novice_tome")
	model.Name = "weapon_tome"
	return model
end

-- ============================================================================
-- PUBLIC ENSURE API
-- ============================================================================
-- ============================================================================
-- STYLING (shared by every equip path)
-- ============================================================================
-- Forward declarations for weapon style tables defined below
local DAGGER_STYLES: { [string]: any }
local AXE_STYLES: { [string]: any }
local STAFF_STYLES: { [string]: any }
local TOME_STYLES: { [string]: any }

-- Per-artifact colour overrides and the rarity glow, applied to a cloned prefab.
local DAGGER_STYLES: { [string]: any } = nil :: any

function WeaponModelBuilder.Style(wModel: Model, weaponAssetId: string?, rarityIndex: number?)
	if weaponAssetId == "weapon_runic_longsword" then
		for _, p in ipairs(wModel:GetDescendants()) do
			if p:IsA("BasePart") then
				if p.Name:find("Rune") or p.Name:find("Gem") or p.Name:find("Aura") or p.Name:find("Boss") then
					p.Material = Enum.Material.Neon
					p.Color = Color3.fromRGB(0, 229, 255)
				elseif p.Name:find("Blade") or p.Name:find("Tip") or p.Name:find("ShieldPlate") then
					p.Material = Enum.Material.Metal
					p.Color = Color3.fromRGB(203, 232, 247)
				elseif p.Name:find("Guard") or p.Name:find("Quillon") or p.Name:find("Pommel") or p.Name:find("Collar") or p.Name:find("HandleS") then
					p.Material = Enum.Material.Metal
					p.Color = Color3.fromRGB(37, 40, 48)
				elseif p.Name == "Handle" then
					p.Material = Enum.Material.SmoothPlastic
					p.Color = Color3.fromRGB(24, 24, 31)
				end
			end
		end
	end

	-- Striker Dual Daggers (Batch 3) Styling Hook
	local daggerStyle = (DAGGER_STYLES and weaponAssetId) and DAGGER_STYLES[weaponAssetId]
	if daggerStyle then
		if daggerStyle.Parts then
			local leftDagger = wModel:FindFirstChild("LeftDagger")
			for partName, pStyle in pairs(daggerStyle.Parts) do
				local target = (leftDagger and leftDagger:FindFirstChild(partName)) or wModel:FindFirstChild(partName)
				if target and target:IsA("BasePart") then
					if pStyle.Material then target.Material = pStyle.Material end
					if pStyle.Color then target.Color = pStyle.Color end
				end
			end
		end

		local handle = wModel:FindFirstChild("Handle") :: BasePart?
		if handle and daggerStyle.PrimaryMaterial then
			handle.Material = daggerStyle.PrimaryMaterial
			if daggerStyle.PrimaryColor then handle.Color = daggerStyle.PrimaryColor end
		end

		local leftDagger = wModel:FindFirstChild("LeftDagger")
		local handleL = leftDagger and leftDagger:FindFirstChild("HandleL") :: BasePart?
		if handleL and (daggerStyle.LeftMaterial or daggerStyle.PrimaryMaterial) then
			handleL.Material = daggerStyle.LeftMaterial or daggerStyle.PrimaryMaterial
			if daggerStyle.LeftColor or daggerStyle.PrimaryColor then
				handleL.Color = daggerStyle.LeftColor or daggerStyle.PrimaryColor
			end
		end
	end

	-- Berserker Greataxes (Batch 4) Styling Hook
	local axeStyle = (AXE_STYLES and weaponAssetId) and AXE_STYLES[weaponAssetId]
	if axeStyle and axeStyle.Parts then
		for partName, pStyle in pairs(axeStyle.Parts) do
			local part = wModel:FindFirstChild(partName) :: BasePart?
			if part then
				if pStyle.Material then part.Material = pStyle.Material end
				if pStyle.Color then part.Color = pStyle.Color end
			end
		end
	end

	-- Mage Staves (Batch 5) Styling Hook
	local staffStyle = (STAFF_STYLES and weaponAssetId) and STAFF_STYLES[weaponAssetId]
	if staffStyle and staffStyle.Parts then
		for partName, pStyle in pairs(staffStyle.Parts) do
			local part = wModel:FindFirstChild(partName) :: BasePart?
			if part then
				if pStyle.Material then part.Material = pStyle.Material end
				if pStyle.Color then part.Color = pStyle.Color end
			end
		end
	end

	-- Healer Tomes (Batch 6) Styling Hook
	local tomeStyle = (TOME_STYLES and weaponAssetId) and TOME_STYLES[weaponAssetId]
	if tomeStyle and tomeStyle.Parts then
		for partName, pStyle in pairs(tomeStyle.Parts) do
			local part = wModel:FindFirstChild(partName) :: BasePart?
			if part then
				if pStyle.Material then part.Material = pStyle.Material end
				if pStyle.Color then part.Color = pStyle.Color end
			end
		end
	end

	-- Subtle accent rune glow for Exalted+ weapons (rarity >= 5), applied ONLY to dedicated micro-pip parts.
	-- Main staves, limbs, blades, wings, rings, and crystals retain their physical materials.
	-- Gildforged (The Gilded Anvil) weapons preserve their sculpted bespoke element palettes.
	local isGildforged = wModel:GetAttribute("IsGildforged") == true or (weaponAssetId ~= nil and GildedAnvilMeshData.Weapons[weaponAssetId] ~= nil)
	if not isGildforged and rarityIndex and rarityIndex >= 5 then
		local Shared = ReplicatedStorage:FindFirstChild("Shared")
		local ArtifactCatalog = Shared and require(Shared:WaitForChild("Config"):WaitForChild("ArtifactCatalog")) :: any
		local rInfo = ArtifactCatalog and ArtifactCatalog.GetRarityInfo(rarityIndex)
		if rInfo then
			for _, p in ipairs(wModel:GetDescendants()) do
				if p:IsA("BasePart") and (p.Name:find("RuneInlay") or p.Name:find("GlowPip")) then
					p.Material = Enum.Material.Neon
					p.Color = rInfo.Color
				end
			end
		end
	end

	-- Apply client-side weapon VFX (glints, lights, auras, trails)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local combatVfx = assets and assets:FindFirstChild("CombatVfx")
	local weaponVfxMod = combatVfx and combatVfx:FindFirstChild("WeaponVfx")
	if weaponVfxMod then
		local ok, WeaponVfx = pcall(require, weaponVfxMod)
		if ok and WeaponVfx and WeaponVfx.Apply then
			local Shared = ReplicatedStorage:FindFirstChild("Shared")
			local ArtifactCatalog = Shared and require(Shared:WaitForChild("Config"):WaitForChild("ArtifactCatalog")) :: any
			local seed = weaponAssetId and ArtifactCatalog and ArtifactCatalog.Seeds and ArtifactCatalog.Seeds[weaponAssetId]
			local resolvedType = (seed and seed.Type) or (if wModel:FindFirstChild("OffhandShield") then "SWORD_SHIELD" else "BOW")
			WeaponVfx.Apply(wModel, resolvedType, rarityIndex, weaponAssetId)
		end
	end
end

-- STRIKER DUAL DAGGERS (Batch 3) - 14 Modular 3D Anime Trench Daggers, Stilettos & Katars
export type DaggerPartData = {
	Name: string,
	MeshId: string,
	Size: Vector3,
	Offset: Vector3,
	Mat: Enum.Material,
	Color: Color3,
	IsLeft: boolean,
}

export type DaggerMeshData = {
	GripPos: Vector3,
	TipPos: Vector3,
	BasePos: Vector3,
	CorePos: Vector3,
	Parts: { DaggerPartData },
}

local DAGGER_MESH_DATA: { [string]: DaggerMeshData } = {
	art_abyssal_ravagers = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 0.0000, 2.2200),
		BasePos = Vector3.new(0.0000, 0.0000, 0.4000),
		CorePos = Vector3.new(0.0000, 0.0000, 1.3100),
		Parts = {
			{ Name = "BackSpike", MeshId = "rbxassetid://108448357073143", Size = Vector3.new(0.2641, 0.0560, 0.3167), Offset = Vector3.new(0.1750, 0.0000, 0.5756), Mat = Enum.Material.Metal, Color = Color3.fromRGB(88, 28, 135), IsLeft = false },
			{ Name = "Blade", MeshId = "rbxassetid://87788611429309", Size = Vector3.new(0.7200, 0.0900, 1.6993), Offset = Vector3.new(0.0000, 0.0000, 1.3096), Mat = Enum.Material.Metal, Color = Color3.fromRGB(36, 10, 62), IsLeft = false },
			{ Name = "BladeEdge", MeshId = "rbxassetid://73656944343107", Size = Vector3.new(0.7200, 0.0320, 0.5700), Offset = Vector3.new(0.0000, 0.0000, 1.9350), Mat = Enum.Material.Metal, Color = Color3.fromRGB(192, 132, 252), IsLeft = false },
			{ Name = "Crossguard", MeshId = "rbxassetid://75628606109574", Size = Vector3.new(0.6000, 0.6160, 0.4072), Offset = Vector3.new(0.0000, 0.0000, 0.5773), Mat = Enum.Material.Metal, Color = Color3.fromRGB(59, 7, 100), IsLeft = false },
			{ Name = "Handle", MeshId = "rbxassetid://103001058349397", Size = Vector3.new(0.2568, 0.1480, 0.8400), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(24, 8, 40), IsLeft = false },
			{ Name = "Pommel", MeshId = "rbxassetid://124547371528972", Size = Vector3.new(0.3041, 0.2920, 0.3071), Offset = Vector3.new(0.0000, 0.0000, -0.5400), Mat = Enum.Material.Metal, Color = Color3.fromRGB(76, 29, 149), IsLeft = false },
			{ Name = "RuneInlay", MeshId = "rbxassetid://103924688892845", Size = Vector3.new(0.4598, 0.0220, 1.2758), Offset = Vector3.new(0.0000, 0.0000, 1.3250), Mat = Enum.Material.Neon, Color = Color3.fromRGB(232, 121, 249), IsLeft = false },
			{ Name = "BackSpikeL", MeshId = "rbxassetid://84983905144974", Size = Vector3.new(0.2641, 0.0560, 0.3167), Offset = Vector3.new(-0.1750, 0.0000, 0.5756), Mat = Enum.Material.Metal, Color = Color3.fromRGB(88, 28, 135), IsLeft = true },
			{ Name = "BladeEdgeL", MeshId = "rbxassetid://114451057025980", Size = Vector3.new(0.7200, 0.0320, 0.5700), Offset = Vector3.new(0.0000, 0.0000, 1.9350), Mat = Enum.Material.Metal, Color = Color3.fromRGB(192, 132, 252), IsLeft = true },
			{ Name = "BladeL", MeshId = "rbxassetid://128113741062683", Size = Vector3.new(0.7200, 0.0900, 1.6993), Offset = Vector3.new(0.0000, 0.0000, 1.3096), Mat = Enum.Material.Metal, Color = Color3.fromRGB(36, 10, 62), IsLeft = true },
			{ Name = "CrossguardL", MeshId = "rbxassetid://121785908154474", Size = Vector3.new(0.6000, 0.6160, 0.4072), Offset = Vector3.new(0.0000, 0.0000, 0.5773), Mat = Enum.Material.Metal, Color = Color3.fromRGB(59, 7, 100), IsLeft = true },
			{ Name = "HandleL", MeshId = "rbxassetid://73534665642651", Size = Vector3.new(0.2568, 0.1480, 0.8400), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(24, 8, 40), IsLeft = true },
			{ Name = "PommelL", MeshId = "rbxassetid://83890804029700", Size = Vector3.new(0.3041, 0.2920, 0.3071), Offset = Vector3.new(0.0000, 0.0000, -0.5400), Mat = Enum.Material.Metal, Color = Color3.fromRGB(76, 29, 149), IsLeft = true },
			{ Name = "RuneInlayL", MeshId = "rbxassetid://85079919632425", Size = Vector3.new(0.4598, 0.0220, 1.2758), Offset = Vector3.new(0.0000, 0.0000, 1.3250), Mat = Enum.Material.Neon, Color = Color3.fromRGB(232, 121, 249), IsLeft = true },
		},
	},
	art_abyssal_razor = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 0.0000, 2.1400),
		BasePos = Vector3.new(0.0000, 0.0000, 0.4000),
		CorePos = Vector3.new(0.0000, 0.0000, 1.2700),
		Parts = {
			{ Name = "Blade", MeshId = "rbxassetid://131253598214759", Size = Vector3.new(0.2900, 0.0880, 1.6370), Offset = Vector3.new(-0.0725, 0.0000, 1.2686), Mat = Enum.Material.Metal, Color = Color3.fromRGB(9, 9, 11), IsLeft = false },
			{ Name = "BladeEdge", MeshId = "rbxassetid://80367306020177", Size = Vector3.new(0.0387, 0.0160, 0.0630), Offset = Vector3.new(-0.0097, 0.0000, 2.1185), Mat = Enum.Material.Metal, Color = Color3.fromRGB(107, 33, 168), IsLeft = false },
			{ Name = "Crossguard", MeshId = "rbxassetid://106372237136621", Size = Vector3.new(0.9626, 0.1929, 0.4175), Offset = Vector3.new(0.0000, 0.0215, 0.5813), Mat = Enum.Material.Metal, Color = Color3.fromRGB(39, 39, 42), IsLeft = false },
			{ Name = "Handle", MeshId = "rbxassetid://87333497030437", Size = Vector3.new(0.2080, 0.1440, 0.9080), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(18, 19, 22), IsLeft = false },
			{ Name = "Pommel", MeshId = "rbxassetid://101245514031339", Size = Vector3.new(0.1900, 0.1900, 0.2780), Offset = Vector3.new(0.0000, 0.0000, -0.5810), Mat = Enum.Material.Metal, Color = Color3.fromRGB(39, 39, 42), IsLeft = false },
			{ Name = "RuneInlay", MeshId = "rbxassetid://121449806796041", Size = Vector3.new(0.0471, 0.0500, 1.3827), Offset = Vector3.new(-0.0200, 0.0000, 1.1900), Mat = Enum.Material.Neon, Color = Color3.fromRGB(147, 51, 234), IsLeft = false },
			{ Name = "BladeEdgeL", MeshId = "rbxassetid://86935671026438", Size = Vector3.new(0.0387, 0.0160, 0.0630), Offset = Vector3.new(0.0097, 0.0000, 2.1185), Mat = Enum.Material.Metal, Color = Color3.fromRGB(107, 33, 168), IsLeft = true },
			{ Name = "BladeL", MeshId = "rbxassetid://133192310651854", Size = Vector3.new(0.2900, 0.0880, 1.6370), Offset = Vector3.new(0.0725, 0.0000, 1.2686), Mat = Enum.Material.Metal, Color = Color3.fromRGB(9, 9, 11), IsLeft = true },
			{ Name = "CrossguardL", MeshId = "rbxassetid://115298082897269", Size = Vector3.new(0.9626, 0.1929, 0.4175), Offset = Vector3.new(0.0000, 0.0215, 0.5813), Mat = Enum.Material.Metal, Color = Color3.fromRGB(39, 39, 42), IsLeft = true },
			{ Name = "HandleL", MeshId = "rbxassetid://128626581036736", Size = Vector3.new(0.2080, 0.1440, 0.9080), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(18, 19, 22), IsLeft = true },
			{ Name = "PommelL", MeshId = "rbxassetid://97052647858614", Size = Vector3.new(0.1900, 0.1900, 0.2780), Offset = Vector3.new(0.0000, 0.0000, -0.5810), Mat = Enum.Material.Metal, Color = Color3.fromRGB(39, 39, 42), IsLeft = true },
			{ Name = "RuneInlayL", MeshId = "rbxassetid://110304795902922", Size = Vector3.new(0.0471, 0.0500, 1.3827), Offset = Vector3.new(0.0200, 0.0000, 1.1900), Mat = Enum.Material.Neon, Color = Color3.fromRGB(147, 51, 234), IsLeft = true },
		},
	},
	art_bloodthirst_twinblades = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 0.0000, 2.1000),
		BasePos = Vector3.new(0.0000, 0.0000, 0.4000),
		CorePos = Vector3.new(0.0000, 0.0000, 1.2500),
		Parts = {
			{ Name = "Blade", MeshId = "rbxassetid://125574067941455", Size = Vector3.new(0.4122, 0.0920, 1.6128), Offset = Vector3.new(-0.1481, 0.0000, 1.1879), Mat = Enum.Material.Metal, Color = Color3.fromRGB(74, 14, 23), IsLeft = false },
			{ Name = "BladeEdge", MeshId = "rbxassetid://136627091501008", Size = Vector3.new(0.0883, 0.0213, 0.0672), Offset = Vector3.new(-0.0864, 0.0000, 2.0280), Mat = Enum.Material.Metal, Color = Color3.fromRGB(244, 63, 94), IsLeft = false },
			{ Name = "Crossguard", MeshId = "rbxassetid://103229026740475", Size = Vector3.new(0.9430, 0.1837, 0.4543), Offset = Vector3.new(0.0000, 0.0118, 0.5402), Mat = Enum.Material.Metal, Color = Color3.fromRGB(120, 53, 15), IsLeft = false },
			{ Name = "Handle", MeshId = "rbxassetid://109804958005755", Size = Vector3.new(0.2277, 0.2277, 0.8969), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Fabric, Color = Color3.fromRGB(92, 20, 30), IsLeft = false },
			{ Name = "Pommel", MeshId = "rbxassetid://86457159451810", Size = Vector3.new(0.2230, 0.2154, 0.1867), Offset = Vector3.new(0.0000, 0.0000, -0.5686), Mat = Enum.Material.Metal, Color = Color3.fromRGB(88, 18, 30), IsLeft = false },
			{ Name = "RuneInlay", MeshId = "rbxassetid://93011823716426", Size = Vector3.new(0.1008, 0.0342, 1.4849), Offset = Vector3.new(-0.0326, 0.0000, 1.1516), Mat = Enum.Material.Neon, Color = Color3.fromRGB(255, 30, 64), IsLeft = false },
			{ Name = "BladeEdgeL", MeshId = "rbxassetid://115100228737581", Size = Vector3.new(0.0883, 0.0213, 0.0672), Offset = Vector3.new(0.0864, 0.0000, 2.0280), Mat = Enum.Material.Metal, Color = Color3.fromRGB(244, 63, 94), IsLeft = true },
			{ Name = "BladeL", MeshId = "rbxassetid://102213266143156", Size = Vector3.new(0.4122, 0.0920, 1.6128), Offset = Vector3.new(0.1481, 0.0000, 1.1879), Mat = Enum.Material.Metal, Color = Color3.fromRGB(74, 14, 23), IsLeft = true },
			{ Name = "CrossguardL", MeshId = "rbxassetid://128051826217467", Size = Vector3.new(0.9430, 0.1837, 0.4543), Offset = Vector3.new(0.0000, 0.0118, 0.5402), Mat = Enum.Material.Metal, Color = Color3.fromRGB(120, 53, 15), IsLeft = true },
			{ Name = "HandleL", MeshId = "rbxassetid://106954800568900", Size = Vector3.new(0.2277, 0.2277, 0.8969), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Fabric, Color = Color3.fromRGB(92, 20, 30), IsLeft = true },
			{ Name = "PommelL", MeshId = "rbxassetid://81196700541115", Size = Vector3.new(0.2230, 0.2154, 0.1867), Offset = Vector3.new(0.0000, 0.0000, -0.5686), Mat = Enum.Material.Metal, Color = Color3.fromRGB(88, 18, 30), IsLeft = true },
			{ Name = "RuneInlayL", MeshId = "rbxassetid://125783710526315", Size = Vector3.new(0.1008, 0.0342, 1.4849), Offset = Vector3.new(0.0326, 0.0000, 1.1516), Mat = Enum.Material.Neon, Color = Color3.fromRGB(255, 30, 64), IsLeft = true },
		},
	},
	art_crimson_carnage = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 0.0000, 2.0600),
		BasePos = Vector3.new(0.0000, 0.0000, 0.4000),
		CorePos = Vector3.new(0.0000, 0.0000, 1.2300),
		Parts = {
			{ Name = "BackSpike", MeshId = "rbxassetid://122419773689464", Size = Vector3.new(0.3417, 0.0380, 1.3151), Offset = Vector3.new(0.0280, 0.0000, 1.3130), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(226, 217, 208), IsLeft = false },
			{ Name = "Blade", MeshId = "rbxassetid://139682598450917", Size = Vector3.new(0.3020, 0.0920, 1.5552), Offset = Vector3.new(-0.1045, 0.0000, 1.2151), Mat = Enum.Material.Metal, Color = Color3.fromRGB(136, 19, 55), IsLeft = false },
			{ Name = "BladeEdge", MeshId = "rbxassetid://131894573673061", Size = Vector3.new(0.0557, 0.0169, 0.0648), Offset = Vector3.new(-0.2400, 0.0000, 2.0251), Mat = Enum.Material.Metal, Color = Color3.fromRGB(251, 113, 133), IsLeft = false },
			{ Name = "Crossguard", MeshId = "rbxassetid://111579536555297", Size = Vector3.new(0.5000, 0.2104, 0.1550), Offset = Vector3.new(0.0000, 0.0000, 0.4300), Mat = Enum.Material.Metal, Color = Color3.fromRGB(131, 24, 67), IsLeft = false },
			{ Name = "Handle", MeshId = "rbxassetid://131316641844681", Size = Vector3.new(0.2749, 0.1797, 0.8450), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(222, 216, 208), IsLeft = false },
			{ Name = "Pommel", MeshId = "rbxassetid://101407026612558", Size = Vector3.new(0.1700, 0.1719, 0.1700), Offset = Vector3.new(0.0000, 0.0031, -0.5225), Mat = Enum.Material.Metal, Color = Color3.fromRGB(92, 16, 32), IsLeft = false },
			{ Name = "RuneInlay", MeshId = "rbxassetid://75577888060791", Size = Vector3.new(0.1796, 0.0380, 1.3843), Offset = Vector3.new(-0.0698, 0.0000, 1.1696), Mat = Enum.Material.Neon, Color = Color3.fromRGB(255, 0, 51), IsLeft = false },
			{ Name = "BackSpikeL", MeshId = "rbxassetid://124220710408140", Size = Vector3.new(0.3417, 0.0380, 1.3151), Offset = Vector3.new(-0.0280, 0.0000, 1.3130), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(226, 217, 208), IsLeft = true },
			{ Name = "BladeEdgeL", MeshId = "rbxassetid://105728166121803", Size = Vector3.new(0.0557, 0.0169, 0.0648), Offset = Vector3.new(0.2400, 0.0000, 2.0251), Mat = Enum.Material.Metal, Color = Color3.fromRGB(251, 113, 133), IsLeft = true },
			{ Name = "BladeL", MeshId = "rbxassetid://136430435316581", Size = Vector3.new(0.3020, 0.0920, 1.5552), Offset = Vector3.new(0.1045, 0.0000, 1.2151), Mat = Enum.Material.Metal, Color = Color3.fromRGB(136, 19, 55), IsLeft = true },
			{ Name = "CrossguardL", MeshId = "rbxassetid://130812210302958", Size = Vector3.new(0.5000, 0.2104, 0.1550), Offset = Vector3.new(0.0000, 0.0000, 0.4300), Mat = Enum.Material.Metal, Color = Color3.fromRGB(131, 24, 67), IsLeft = true },
			{ Name = "HandleL", MeshId = "rbxassetid://88314154983249", Size = Vector3.new(0.2749, 0.1797, 0.8450), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(222, 216, 208), IsLeft = true },
			{ Name = "PommelL", MeshId = "rbxassetid://98887009239343", Size = Vector3.new(0.1700, 0.1719, 0.1700), Offset = Vector3.new(0.0000, 0.0031, -0.5225), Mat = Enum.Material.Metal, Color = Color3.fromRGB(92, 16, 32), IsLeft = true },
			{ Name = "RuneInlayL", MeshId = "rbxassetid://82235123917280", Size = Vector3.new(0.1796, 0.0380, 1.3843), Offset = Vector3.new(0.0698, 0.0000, 1.1696), Mat = Enum.Material.Neon, Color = Color3.fromRGB(255, 0, 51), IsLeft = true },
		},
	},
	art_eclipse_daggers = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 0.0000, 2.1000),
		BasePos = Vector3.new(0.0000, 0.0000, 0.4000),
		CorePos = Vector3.new(0.0000, 0.0000, 1.2500),
		Parts = {
			{ Name = "Blade", MeshId = "rbxassetid://80720598031866", Size = Vector3.new(0.2430, 0.0880, 1.6128), Offset = Vector3.new(-0.0675, 0.0000, 1.2264), Mat = Enum.Material.Metal, Color = Color3.fromRGB(252, 211, 77), IsLeft = false },
			{ Name = "BladeEdge", MeshId = "rbxassetid://105910691416406", Size = Vector3.new(0.0338, 0.0162, 0.0672), Offset = Vector3.new(-0.0560, 0.0000, 2.0664), Mat = Enum.Material.Metal, Color = Color3.fromRGB(254, 240, 138), IsLeft = false },
			{ Name = "Crossguard", MeshId = "rbxassetid://124607775464719", Size = Vector3.new(0.5421, 0.3480, 0.1789), Offset = Vector3.new(-0.0011, 0.0000, 0.4469), Mat = Enum.Material.Metal, Color = Color3.fromRGB(230, 140, 20), IsLeft = false },
			{ Name = "Handle", MeshId = "rbxassetid://83183783273164", Size = Vector3.new(0.2080, 0.1480, 0.9680), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(245, 158, 11), IsLeft = false },
			{ Name = "Pommel", MeshId = "rbxassetid://135337760987234", Size = Vector3.new(0.2600, 0.4200, 0.1600), Offset = Vector3.new(0.0000, 0.0000, -0.5000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(251, 191, 36), IsLeft = false },
			{ Name = "RuneInlay", MeshId = "rbxassetid://129693272423098", Size = Vector3.new(0.0710, 0.0342, 1.4827), Offset = Vector3.new(-0.0175, 0.0000, 1.2000), Mat = Enum.Material.Neon, Color = Color3.fromRGB(255, 237, 213), IsLeft = false },
			{ Name = "BladeEdgeL", MeshId = "rbxassetid://90253412863114", Size = Vector3.new(0.0315, 0.0155, 0.0672), Offset = Vector3.new(0.0552, 0.0000, 2.0664), Mat = Enum.Material.Metal, Color = Color3.fromRGB(248, 250, 252), IsLeft = true },
			{ Name = "BladeL", MeshId = "rbxassetid://90556509782787", Size = Vector3.new(0.2250, 0.0840, 1.6128), Offset = Vector3.new(0.0625, 0.0000, 1.2264), Mat = Enum.Material.Metal, Color = Color3.fromRGB(226, 232, 240), IsLeft = true },
			{ Name = "CrossguardL", MeshId = "rbxassetid://77830116112036", Size = Vector3.new(0.5482, 0.1600, 0.2040), Offset = Vector3.new(0.0047, 0.0000, 0.4620), Mat = Enum.Material.Metal, Color = Color3.fromRGB(170, 185, 205), IsLeft = true },
			{ Name = "HandleL", MeshId = "rbxassetid://90543911603604", Size = Vector3.new(0.2080, 0.1409, 0.9680), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(203, 213, 225), IsLeft = true },
			{ Name = "PommelL", MeshId = "rbxassetid://96384206459381", Size = Vector3.new(0.1000, 0.2180, 0.2180), Offset = Vector3.new(0.0000, 0.0000, -0.5200), Mat = Enum.Material.Metal, Color = Color3.fromRGB(148, 163, 184), IsLeft = true },
			{ Name = "RuneInlayL", MeshId = "rbxassetid://89549757807568", Size = Vector3.new(0.0710, 0.0342, 1.4827), Offset = Vector3.new(0.0175, 0.0000, 1.2000), Mat = Enum.Material.Neon, Color = Color3.fromRGB(224, 242, 254), IsLeft = true },
		},
	},
	art_nightstalker_katar = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 0.0000, 2.1600),
		BasePos = Vector3.new(0.0000, 0.0000, 0.4000),
		CorePos = Vector3.new(0.0000, 0.0000, 1.2800),
		Parts = {
			{ Name = "Blade", MeshId = "rbxassetid://114962933486806", Size = Vector3.new(0.5000, 0.1000, 1.1700), Offset = Vector3.new(-0.1588, 0.0000, 1.3200), Mat = Enum.Material.Metal, Color = Color3.fromRGB(40, 42, 50), IsLeft = false },
			{ Name = "BladeEdge", MeshId = "rbxassetid://115872251537292", Size = Vector3.new(0.2400, 0.0520, 0.3100), Offset = Vector3.new(-0.1588, 0.0000, 2.0600), Mat = Enum.Material.Neon, Color = Color3.fromRGB(168, 85, 247), IsLeft = false },
			{ Name = "Crossguard", MeshId = "rbxassetid://79799131369513", Size = Vector3.new(0.7200, 0.1600, 0.8850), Offset = Vector3.new(-0.1588, 0.0000, 0.3075), Mat = Enum.Material.Metal, Color = Color3.fromRGB(43, 45, 53), IsLeft = false },
			{ Name = "Handle", MeshId = "rbxassetid://92532418361826", Size = Vector3.new(0.8025, 0.1620, 0.3720), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(43, 45, 53), IsLeft = false },
			{ Name = "Pommel", MeshId = "rbxassetid://74628490433478", Size = Vector3.new(0.6600, 0.1328, 0.4000), Offset = Vector3.new(-0.1588, 0.0214, -0.2850), Mat = Enum.Material.Metal, Color = Color3.fromRGB(31, 33, 40), IsLeft = false },
			{ Name = "RuneInlay", MeshId = "rbxassetid://107921052544896", Size = Vector3.new(0.1800, 0.0450, 1.2500), Offset = Vector3.new(-0.1588, 0.0000, 1.4050), Mat = Enum.Material.Neon, Color = Color3.fromRGB(192, 132, 252), IsLeft = false },
			{ Name = "BladeEdgeL", MeshId = "rbxassetid://101539697531608", Size = Vector3.new(0.2400, 0.0520, 0.3100), Offset = Vector3.new(0.1588, 0.0000, 2.0600), Mat = Enum.Material.Neon, Color = Color3.fromRGB(168, 85, 247), IsLeft = true },
			{ Name = "BladeL", MeshId = "rbxassetid://88535800508287", Size = Vector3.new(0.5000, 0.1000, 1.1700), Offset = Vector3.new(0.1588, 0.0000, 1.3200), Mat = Enum.Material.Metal, Color = Color3.fromRGB(40, 42, 50), IsLeft = true },
			{ Name = "CrossguardL", MeshId = "rbxassetid://113079941482372", Size = Vector3.new(0.7200, 0.1600, 0.8850), Offset = Vector3.new(0.1588, 0.0000, 0.3075), Mat = Enum.Material.Metal, Color = Color3.fromRGB(43, 45, 53), IsLeft = true },
			{ Name = "HandleL", MeshId = "rbxassetid://110156573367176", Size = Vector3.new(0.8025, 0.1620, 0.3720), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(43, 45, 53), IsLeft = true },
			{ Name = "PommelL", MeshId = "rbxassetid://89224762812046", Size = Vector3.new(0.6600, 0.1328, 0.4000), Offset = Vector3.new(0.1588, 0.0214, -0.2850), Mat = Enum.Material.Metal, Color = Color3.fromRGB(31, 33, 40), IsLeft = true },
			{ Name = "RuneInlayL", MeshId = "rbxassetid://86143616182656", Size = Vector3.new(0.1800, 0.0450, 1.2500), Offset = Vector3.new(0.1588, 0.0000, 1.4050), Mat = Enum.Material.Neon, Color = Color3.fromRGB(192, 132, 252), IsLeft = true },
		},
	},
	art_phantom_edge = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 0.0000, 2.1200),
		BasePos = Vector3.new(0.0000, 0.0000, 0.4000),
		CorePos = Vector3.new(0.0000, 0.0000, 1.2600),
		Parts = {
			{ Name = "Blade", MeshId = "rbxassetid://76330363365966", Size = Vector3.new(0.2200, 0.0900, 1.4600), Offset = Vector3.new(0.0000, 0.0000, 1.1500), Mat = Enum.Material.Glass, Color = Color3.fromRGB(56, 189, 248), IsLeft = false },
			{ Name = "BladeEdge", MeshId = "rbxassetid://80589280837663", Size = Vector3.new(0.1900, 0.0360, 0.2400), Offset = Vector3.new(0.0000, 0.0000, 2.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(125, 211, 252), IsLeft = false },
			{ Name = "Crossguard", MeshId = "rbxassetid://102251809043166", Size = Vector3.new(1.0599, 0.1728, 0.4584), Offset = Vector3.new(0.0000, 0.0064, 0.5762), Mat = Enum.Material.Metal, Color = Color3.fromRGB(210, 220, 232), IsLeft = false },
			{ Name = "Handle", MeshId = "rbxassetid://84206754805083", Size = Vector3.new(0.1840, 0.1640, 0.7800), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(226, 232, 240), IsLeft = false },
			{ Name = "Pommel", MeshId = "rbxassetid://122263676397638", Size = Vector3.new(0.3299, 0.2100, 0.2649), Offset = Vector3.new(0.0000, 0.0000, -0.4925), Mat = Enum.Material.Metal, Color = Color3.fromRGB(226, 232, 240), IsLeft = false },
			{ Name = "RuneInlay", MeshId = "rbxassetid://77440850332220", Size = Vector3.new(0.0400, 0.0380, 0.7000), Offset = Vector3.new(0.0000, 0.0000, 1.4500), Mat = Enum.Material.Neon, Color = Color3.fromRGB(2, 132, 199), IsLeft = false },
			{ Name = "BladeEdgeL", MeshId = "rbxassetid://88919433125782", Size = Vector3.new(0.1900, 0.0360, 0.2400), Offset = Vector3.new(0.0000, 0.0000, 2.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(125, 211, 252), IsLeft = true },
			{ Name = "BladeL", MeshId = "rbxassetid://76843404281624", Size = Vector3.new(0.2200, 0.0900, 1.4600), Offset = Vector3.new(0.0000, 0.0000, 1.1500), Mat = Enum.Material.Glass, Color = Color3.fromRGB(56, 189, 248), IsLeft = true },
			{ Name = "CrossguardL", MeshId = "rbxassetid://129469023382358", Size = Vector3.new(1.0599, 0.1728, 0.4584), Offset = Vector3.new(0.0000, 0.0064, 0.5762), Mat = Enum.Material.Metal, Color = Color3.fromRGB(210, 220, 232), IsLeft = true },
			{ Name = "HandleL", MeshId = "rbxassetid://135206318336031", Size = Vector3.new(0.1840, 0.1640, 0.7800), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(226, 232, 240), IsLeft = true },
			{ Name = "PommelL", MeshId = "rbxassetid://137324021389488", Size = Vector3.new(0.3299, 0.2100, 0.2649), Offset = Vector3.new(0.0000, 0.0000, -0.4925), Mat = Enum.Material.Metal, Color = Color3.fromRGB(226, 232, 240), IsLeft = true },
			{ Name = "RuneInlayL", MeshId = "rbxassetid://80131077133453", Size = Vector3.new(0.0400, 0.0380, 0.7000), Offset = Vector3.new(0.0000, 0.0000, 1.4500), Mat = Enum.Material.Neon, Color = Color3.fromRGB(2, 132, 199), IsLeft = true },
		},
	},
	art_phantom_stiletto = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 0.0000, 2.0200),
		BasePos = Vector3.new(0.0000, 0.0000, 0.4000),
		CorePos = Vector3.new(0.0000, 0.0000, 1.2100),
		Parts = {
			{ Name = "Blade", MeshId = "rbxassetid://125693663741934", Size = Vector3.new(0.1500, 0.0900, 1.4954), Offset = Vector3.new(0.0000, 0.0000, 1.1618), Mat = Enum.Material.Glass, Color = Color3.fromRGB(93, 226, 248), IsLeft = false },
			{ Name = "BladeEdge", MeshId = "rbxassetid://130032835512498", Size = Vector3.new(0.0226, 0.0169, 0.1246), Offset = Vector3.new(0.0000, 0.0000, 1.9718), Mat = Enum.Material.Metal, Color = Color3.fromRGB(165, 243, 252), IsLeft = false },
			{ Name = "Crossguard", MeshId = "rbxassetid://128416076952168", Size = Vector3.new(0.4759, 0.2988, 0.8439), Offset = Vector3.new(-0.0179, 0.0000, 0.0662), Mat = Enum.Material.Metal, Color = Color3.fromRGB(195, 205, 218), IsLeft = false },
			{ Name = "Handle", MeshId = "rbxassetid://109132866439021", Size = Vector3.new(0.1580, 0.1160, 0.7882), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(208, 216, 226), IsLeft = false },
			{ Name = "Pommel", MeshId = "rbxassetid://122569711358172", Size = Vector3.new(0.2000, 0.1902, 0.2050), Offset = Vector3.new(0.0000, 0.0000, -0.4284), Mat = Enum.Material.Glass, Color = Color3.fromRGB(103, 232, 249), IsLeft = false },
			{ Name = "RuneInlay", MeshId = "rbxassetid://98195112552005", Size = Vector3.new(0.0280, 0.0266, 1.4500), Offset = Vector3.new(0.0000, 0.0000, 1.1891), Mat = Enum.Material.Neon, Color = Color3.fromRGB(56, 189, 248), IsLeft = false },
			{ Name = "BladeEdgeL", MeshId = "rbxassetid://87208369642605", Size = Vector3.new(0.0226, 0.0169, 0.1246), Offset = Vector3.new(0.0000, 0.0000, 1.9718), Mat = Enum.Material.Metal, Color = Color3.fromRGB(165, 243, 252), IsLeft = true },
			{ Name = "BladeL", MeshId = "rbxassetid://127767754905372", Size = Vector3.new(0.1500, 0.0900, 1.4954), Offset = Vector3.new(0.0000, 0.0000, 1.1618), Mat = Enum.Material.Glass, Color = Color3.fromRGB(93, 226, 248), IsLeft = true },
			{ Name = "CrossguardL", MeshId = "rbxassetid://129773157358446", Size = Vector3.new(0.4759, 0.2988, 0.8439), Offset = Vector3.new(0.0179, 0.0000, 0.0662), Mat = Enum.Material.Metal, Color = Color3.fromRGB(195, 205, 218), IsLeft = true },
			{ Name = "HandleL", MeshId = "rbxassetid://93170532662175", Size = Vector3.new(0.1580, 0.1160, 0.7882), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(208, 216, 226), IsLeft = true },
			{ Name = "PommelL", MeshId = "rbxassetid://110670511491659", Size = Vector3.new(0.2000, 0.1902, 0.2050), Offset = Vector3.new(0.0000, 0.0000, -0.4284), Mat = Enum.Material.Glass, Color = Color3.fromRGB(103, 232, 249), IsLeft = true },
			{ Name = "RuneInlayL", MeshId = "rbxassetid://99585498838595", Size = Vector3.new(0.0280, 0.0266, 1.4500), Offset = Vector3.new(0.0000, 0.0000, 1.1891), Mat = Enum.Material.Neon, Color = Color3.fromRGB(56, 189, 248), IsLeft = true },
		},
	},
	art_rusty_daggers = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 0.0000, 1.7800),
		BasePos = Vector3.new(0.0000, 0.0000, 0.4000),
		CorePos = Vector3.new(0.0000, 0.0000, 1.0900),
		Parts = {
			{ Name = "Blade", MeshId = "rbxassetid://97680961740688", Size = Vector3.new(0.1400, 0.0760, 1.1500), Offset = Vector3.new(-0.0100, 0.0000, 0.9750), Mat = Enum.Material.Metal, Color = Color3.fromRGB(50, 52, 56), IsLeft = false },
			{ Name = "BladeEdge", MeshId = "rbxassetid://115891528184706", Size = Vector3.new(0.0800, 0.0400, 0.2300), Offset = Vector3.new(-0.0100, 0.0000, 1.6650), Mat = Enum.Material.Metal, Color = Color3.fromRGB(200, 204, 214), IsLeft = false },
			{ Name = "Crossguard", MeshId = "rbxassetid://75249418474133", Size = Vector3.new(0.3800, 0.1427, 0.0600), Offset = Vector3.new(0.0000, 0.0000, 0.3800), Mat = Enum.Material.Metal, Color = Color3.fromRGB(66, 69, 74), IsLeft = false },
			{ Name = "Fuller", MeshId = "rbxassetid://128001255683829", Size = Vector3.new(0.0240, 0.0420, 0.8000), Offset = Vector3.new(0.0000, 0.0000, 0.9500), Mat = Enum.Material.Metal, Color = Color3.fromRGB(36, 38, 42), IsLeft = false },
			{ Name = "Handle", MeshId = "rbxassetid://140368191338461", Size = Vector3.new(0.1720, 0.1236, 0.7200), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Wood, Color = Color3.fromRGB(82, 58, 38), IsLeft = false },
			{ Name = "Pommel", MeshId = "rbxassetid://81898286138929", Size = Vector3.new(0.2000, 0.1712, 0.1421), Offset = Vector3.new(0.0000, 0.0000, -0.4111), Mat = Enum.Material.Metal, Color = Color3.fromRGB(66, 69, 74), IsLeft = false },
			{ Name = "BladeEdgeL", MeshId = "rbxassetid://99570007072736", Size = Vector3.new(0.0800, 0.0400, 0.2300), Offset = Vector3.new(0.0100, 0.0000, 1.6650), Mat = Enum.Material.Metal, Color = Color3.fromRGB(200, 204, 214), IsLeft = true },
			{ Name = "BladeL", MeshId = "rbxassetid://71067606124519", Size = Vector3.new(0.1400, 0.0760, 1.1500), Offset = Vector3.new(0.0100, 0.0000, 0.9750), Mat = Enum.Material.Metal, Color = Color3.fromRGB(50, 52, 56), IsLeft = true },
			{ Name = "CrossguardL", MeshId = "rbxassetid://117884708644817", Size = Vector3.new(0.3800, 0.1427, 0.0600), Offset = Vector3.new(0.0000, 0.0000, 0.3800), Mat = Enum.Material.Metal, Color = Color3.fromRGB(66, 69, 74), IsLeft = true },
			{ Name = "FullerL", MeshId = "rbxassetid://99153019004045", Size = Vector3.new(0.0240, 0.0420, 0.8000), Offset = Vector3.new(0.0000, 0.0000, 0.9500), Mat = Enum.Material.Metal, Color = Color3.fromRGB(36, 38, 42), IsLeft = true },
			{ Name = "HandleL", MeshId = "rbxassetid://98792940880063", Size = Vector3.new(0.1720, 0.1236, 0.7200), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Wood, Color = Color3.fromRGB(82, 58, 38), IsLeft = true },
			{ Name = "PommelL", MeshId = "rbxassetid://87368653405587", Size = Vector3.new(0.2000, 0.1712, 0.1421), Offset = Vector3.new(0.0000, 0.0000, -0.4111), Mat = Enum.Material.Metal, Color = Color3.fromRGB(66, 69, 74), IsLeft = true },
		},
	},
	art_serrated_skewers = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 0.0000, 1.8800),
		BasePos = Vector3.new(0.0000, 0.0000, 0.4000),
		CorePos = Vector3.new(0.0000, 0.0000, 1.1400),
		Parts = {
			{ Name = "BackSpike", MeshId = "rbxassetid://93229505324923", Size = Vector3.new(0.0813, 0.0250, 0.8611), Offset = Vector3.new(0.1100, 0.0000, 1.0250), Mat = Enum.Material.Metal, Color = Color3.fromRGB(110, 114, 125), IsLeft = false },
			{ Name = "Blade", MeshId = "rbxassetid://81381873181907", Size = Vector3.new(0.2300, 0.0840, 1.2000), Offset = Vector3.new(-0.0250, 0.0000, 1.0200), Mat = Enum.Material.Metal, Color = Color3.fromRGB(88, 92, 102), IsLeft = false },
			{ Name = "BladeEdge", MeshId = "rbxassetid://121782393796949", Size = Vector3.new(0.1800, 0.0440, 0.2600), Offset = Vector3.new(-0.0300, 0.0000, 1.7500), Mat = Enum.Material.Metal, Color = Color3.fromRGB(210, 214, 224), IsLeft = false },
			{ Name = "Crossguard", MeshId = "rbxassetid://95089895454732", Size = Vector3.new(0.3940, 0.1400, 0.8157), Offset = Vector3.new(-0.0270, 0.0000, 0.0172), Mat = Enum.Material.Metal, Color = Color3.fromRGB(200, 150, 62), IsLeft = false },
			{ Name = "Handle", MeshId = "rbxassetid://125249517609356", Size = Vector3.new(0.1880, 0.1600, 0.7400), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(44, 46, 51), IsLeft = false },
			{ Name = "Pommel", MeshId = "rbxassetid://101660521771754", Size = Vector3.new(0.2300, 0.2100, 0.1950), Offset = Vector3.new(0.0000, 0.0000, -0.4475), Mat = Enum.Material.Metal, Color = Color3.fromRGB(200, 150, 62), IsLeft = false },
			{ Name = "BackSpikeL", MeshId = "rbxassetid://111256821640531", Size = Vector3.new(0.0813, 0.0250, 0.8611), Offset = Vector3.new(-0.1100, 0.0000, 1.0250), Mat = Enum.Material.Metal, Color = Color3.fromRGB(110, 114, 125), IsLeft = true },
			{ Name = "BladeEdgeL", MeshId = "rbxassetid://75607226286954", Size = Vector3.new(0.1800, 0.0440, 0.2600), Offset = Vector3.new(0.0300, 0.0000, 1.7500), Mat = Enum.Material.Metal, Color = Color3.fromRGB(210, 214, 224), IsLeft = true },
			{ Name = "BladeL", MeshId = "rbxassetid://112264509100774", Size = Vector3.new(0.2300, 0.0840, 1.2000), Offset = Vector3.new(0.0250, 0.0000, 1.0200), Mat = Enum.Material.Metal, Color = Color3.fromRGB(88, 92, 102), IsLeft = true },
			{ Name = "CrossguardL", MeshId = "rbxassetid://128555931400147", Size = Vector3.new(0.3940, 0.1400, 0.8157), Offset = Vector3.new(0.0270, 0.0000, 0.0172), Mat = Enum.Material.Metal, Color = Color3.fromRGB(200, 150, 62), IsLeft = true },
			{ Name = "HandleL", MeshId = "rbxassetid://129986147710965", Size = Vector3.new(0.1880, 0.1600, 0.7400), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(44, 46, 51), IsLeft = true },
			{ Name = "PommelL", MeshId = "rbxassetid://138997959137074", Size = Vector3.new(0.2300, 0.2100, 0.1950), Offset = Vector3.new(0.0000, 0.0000, -0.4475), Mat = Enum.Material.Metal, Color = Color3.fromRGB(200, 150, 62), IsLeft = true },
		},
	},
	art_shadow_fangs = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 0.0000, 2.0000),
		BasePos = Vector3.new(0.0000, 0.0000, 0.4000),
		CorePos = Vector3.new(0.0000, 0.0000, 1.2000),
		Parts = {
			{ Name = "BackSpike", MeshId = "rbxassetid://77952752105013", Size = Vector3.new(0.2916, 0.0560, 0.3305), Offset = Vector3.new(0.1776, 0.0000, 1.0145), Mat = Enum.Material.Metal, Color = Color3.fromRGB(70, 55, 45), IsLeft = false },
			{ Name = "Blade", MeshId = "rbxassetid://106295121454613", Size = Vector3.new(0.2610, 0.0840, 1.4585), Offset = Vector3.new(-0.0725, 0.0000, 1.1267), Mat = Enum.Material.Glass, Color = Color3.fromRGB(24, 20, 32), IsLeft = false },
			{ Name = "BladeEdge", MeshId = "rbxassetid://85715582279906", Size = Vector3.new(0.0442, 0.0181, 0.1215), Offset = Vector3.new(-0.0685, 0.0000, 1.9167), Mat = Enum.Material.Metal, Color = Color3.fromRGB(88, 46, 122), IsLeft = false },
			{ Name = "Crossguard", MeshId = "rbxassetid://123350796582932", Size = Vector3.new(0.6965, 0.1600, 0.2300), Offset = Vector3.new(0.0000, 0.0000, 0.4324), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(216, 210, 196), IsLeft = false },
			{ Name = "Handle", MeshId = "rbxassetid://115040716573885", Size = Vector3.new(0.2463, 0.1773, 0.8450), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(216, 210, 196), IsLeft = false },
			{ Name = "Pommel", MeshId = "rbxassetid://107664176433296", Size = Vector3.new(0.3822, 0.1040, 0.2388), Offset = Vector3.new(0.1373, 0.0000, -0.5171), Mat = Enum.Material.Metal, Color = Color3.fromRGB(50, 40, 34), IsLeft = false },
			{ Name = "BackSpikeL", MeshId = "rbxassetid://123910253366651", Size = Vector3.new(0.2916, 0.0560, 0.3305), Offset = Vector3.new(-0.1776, 0.0000, 1.0145), Mat = Enum.Material.Metal, Color = Color3.fromRGB(70, 55, 45), IsLeft = true },
			{ Name = "BladeEdgeL", MeshId = "rbxassetid://100312796073153", Size = Vector3.new(0.0442, 0.0181, 0.1215), Offset = Vector3.new(0.0685, 0.0000, 1.9167), Mat = Enum.Material.Metal, Color = Color3.fromRGB(88, 46, 122), IsLeft = true },
			{ Name = "BladeL", MeshId = "rbxassetid://91969521436405", Size = Vector3.new(0.2610, 0.0840, 1.4585), Offset = Vector3.new(0.0725, 0.0000, 1.1267), Mat = Enum.Material.Glass, Color = Color3.fromRGB(24, 20, 32), IsLeft = true },
			{ Name = "CrossguardL", MeshId = "rbxassetid://72691421657890", Size = Vector3.new(0.6965, 0.1600, 0.2300), Offset = Vector3.new(0.0000, 0.0000, 0.4324), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(216, 210, 196), IsLeft = true },
			{ Name = "HandleL", MeshId = "rbxassetid://104205000838987", Size = Vector3.new(0.2463, 0.1773, 0.8450), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(216, 210, 196), IsLeft = true },
			{ Name = "PommelL", MeshId = "rbxassetid://80959631532220", Size = Vector3.new(0.3822, 0.1040, 0.2388), Offset = Vector3.new(-0.1373, 0.0000, -0.5171), Mat = Enum.Material.Metal, Color = Color3.fromRGB(50, 40, 34), IsLeft = true },
		},
	},
	art_silent_dirks = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 0.0000, 1.9800),
		BasePos = Vector3.new(0.0000, 0.0000, 0.4000),
		CorePos = Vector3.new(0.0000, 0.0000, 1.1900),
		Parts = {
			{ Name = "Blade", MeshId = "rbxassetid://128214097161090", Size = Vector3.new(0.1300, 0.0800, 1.3300), Offset = Vector3.new(0.0000, 0.0000, 1.0900), Mat = Enum.Material.Metal, Color = Color3.fromRGB(48, 58, 72), IsLeft = false },
			{ Name = "BladeEdge", MeshId = "rbxassetid://75911213787471", Size = Vector3.new(0.0500, 0.0280, 0.2300), Offset = Vector3.new(0.0000, 0.0000, 1.8700), Mat = Enum.Material.Metal, Color = Color3.fromRGB(82, 106, 146), IsLeft = false },
			{ Name = "Crossguard", MeshId = "rbxassetid://113658424208605", Size = Vector3.new(0.5160, 0.1260, 0.1228), Offset = Vector3.new(0.0000, 0.0000, 0.3950), Mat = Enum.Material.Metal, Color = Color3.fromRGB(56, 68, 86), IsLeft = false },
			{ Name = "Fuller", MeshId = "rbxassetid://95339502348009", Size = Vector3.new(0.0180, 0.0450, 1.1000), Offset = Vector3.new(0.0000, 0.0000, 1.0550), Mat = Enum.Material.Metal, Color = Color3.fromRGB(24, 28, 34), IsLeft = false },
			{ Name = "Handle", MeshId = "rbxassetid://106458372545074", Size = Vector3.new(0.1640, 0.1400, 0.7932), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Slate, Color = Color3.fromRGB(34, 38, 44), IsLeft = false },
			{ Name = "Pommel", MeshId = "rbxassetid://76496801118649", Size = Vector3.new(0.2200, 0.1900, 0.2260), Offset = Vector3.new(0.0000, 0.0000, -0.4680), Mat = Enum.Material.Metal, Color = Color3.fromRGB(50, 60, 74), IsLeft = false },
			{ Name = "BladeEdgeL", MeshId = "rbxassetid://86126921166460", Size = Vector3.new(0.0500, 0.0280, 0.2300), Offset = Vector3.new(0.0000, 0.0000, 1.8700), Mat = Enum.Material.Metal, Color = Color3.fromRGB(82, 106, 146), IsLeft = true },
			{ Name = "BladeL", MeshId = "rbxassetid://79618151921914", Size = Vector3.new(0.1300, 0.0800, 1.3300), Offset = Vector3.new(0.0000, 0.0000, 1.0900), Mat = Enum.Material.Metal, Color = Color3.fromRGB(48, 58, 72), IsLeft = true },
			{ Name = "CrossguardL", MeshId = "rbxassetid://106967120279702", Size = Vector3.new(0.5160, 0.1260, 0.1228), Offset = Vector3.new(0.0000, 0.0000, 0.3950), Mat = Enum.Material.Metal, Color = Color3.fromRGB(56, 68, 86), IsLeft = true },
			{ Name = "FullerL", MeshId = "rbxassetid://90249389214710", Size = Vector3.new(0.0180, 0.0450, 1.1000), Offset = Vector3.new(0.0000, 0.0000, 1.0550), Mat = Enum.Material.Metal, Color = Color3.fromRGB(24, 28, 34), IsLeft = true },
			{ Name = "HandleL", MeshId = "rbxassetid://136495783881742", Size = Vector3.new(0.1640, 0.1400, 0.7932), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Slate, Color = Color3.fromRGB(34, 38, 44), IsLeft = true },
			{ Name = "PommelL", MeshId = "rbxassetid://105585548051833", Size = Vector3.new(0.2200, 0.1900, 0.2260), Offset = Vector3.new(0.0000, 0.0000, -0.4680), Mat = Enum.Material.Metal, Color = Color3.fromRGB(50, 60, 74), IsLeft = true },
		},
	},
	art_viper_kris = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 0.0000, 1.9000),
		BasePos = Vector3.new(0.0000, 0.0000, 0.4000),
		CorePos = Vector3.new(0.0000, 0.0000, 1.1500),
		Parts = {
			{ Name = "Blade", MeshId = "rbxassetid://97343854545520", Size = Vector3.new(0.3267, 0.0760, 1.4000), Offset = Vector3.new(-0.0133, 0.0000, 1.1400), Mat = Enum.Material.Metal, Color = Color3.fromRGB(114, 98, 68), IsLeft = false },
			{ Name = "BladeEdge", MeshId = "rbxassetid://130315729614982", Size = Vector3.new(0.0814, 0.0178, 0.1000), Offset = Vector3.new(-0.0207, 0.0000, 1.8900), Mat = Enum.Material.Metal, Color = Color3.fromRGB(46, 204, 113), IsLeft = false },
			{ Name = "Crossguard", MeshId = "rbxassetid://94178386431987", Size = Vector3.new(0.5558, 0.1400, 0.2152), Offset = Vector3.new(-0.0178, 0.0000, 0.4675), Mat = Enum.Material.Metal, Color = Color3.fromRGB(200, 154, 56), IsLeft = false },
			{ Name = "Handle", MeshId = "rbxassetid://117968597579888", Size = Vector3.new(0.2180, 0.1600, 0.9480), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(100, 80, 48), IsLeft = false },
			{ Name = "Pommel", MeshId = "rbxassetid://139551712587127", Size = Vector3.new(0.2736, 0.1800, 0.1300), Offset = Vector3.new(0.0050, 0.0000, -0.3850), Mat = Enum.Material.Metal, Color = Color3.fromRGB(200, 154, 56), IsLeft = false },
			{ Name = "RuneInlay", MeshId = "rbxassetid://113535035530806", Size = Vector3.new(0.1780, 0.0285, 1.3929), Offset = Vector3.new(0.0060, 0.0000, 1.1700), Mat = Enum.Material.Neon, Color = Color3.fromRGB(16, 185, 129), IsLeft = false },
			{ Name = "BladeEdgeL", MeshId = "rbxassetid://110147249623441", Size = Vector3.new(0.0814, 0.0178, 0.1000), Offset = Vector3.new(0.0207, 0.0000, 1.8900), Mat = Enum.Material.Metal, Color = Color3.fromRGB(46, 204, 113), IsLeft = true },
			{ Name = "BladeL", MeshId = "rbxassetid://114319398191164", Size = Vector3.new(0.3267, 0.0760, 1.4000), Offset = Vector3.new(0.0133, 0.0000, 1.1400), Mat = Enum.Material.Metal, Color = Color3.fromRGB(114, 98, 68), IsLeft = true },
			{ Name = "CrossguardL", MeshId = "rbxassetid://130462755479774", Size = Vector3.new(0.5558, 0.1400, 0.2152), Offset = Vector3.new(0.0178, 0.0000, 0.4675), Mat = Enum.Material.Metal, Color = Color3.fromRGB(200, 154, 56), IsLeft = true },
			{ Name = "HandleL", MeshId = "rbxassetid://91624072783757", Size = Vector3.new(0.2180, 0.1600, 0.9480), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(100, 80, 48), IsLeft = true },
			{ Name = "PommelL", MeshId = "rbxassetid://108428019513818", Size = Vector3.new(0.2736, 0.1800, 0.1300), Offset = Vector3.new(-0.0050, 0.0000, -0.3850), Mat = Enum.Material.Metal, Color = Color3.fromRGB(200, 154, 56), IsLeft = true },
			{ Name = "RuneInlayL", MeshId = "rbxassetid://82068637363062", Size = Vector3.new(0.1780, 0.0285, 1.3929), Offset = Vector3.new(-0.0060, 0.0000, 1.1700), Mat = Enum.Material.Neon, Color = Color3.fromRGB(16, 185, 129), IsLeft = true },
		},
	},
	art_void_reapers = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 0.0000, 2.3000),
		BasePos = Vector3.new(0.0000, 0.0000, 0.4000),
		CorePos = Vector3.new(0.0000, 0.0000, 1.3500),
		Parts = {
			{ Name = "BackSpike", MeshId = "rbxassetid://118618454120428", Size = Vector3.new(0.3621, 0.0400, 1.4073), Offset = Vector3.new(0.0350, 0.0000, 1.4136), Mat = Enum.Material.Metal, Color = Color3.fromRGB(49, 46, 129), IsLeft = false },
			{ Name = "Blade", MeshId = "rbxassetid://116210923180067", Size = Vector3.new(0.3916, 0.0960, 1.7874), Offset = Vector3.new(-0.1359, 0.0000, 1.3337), Mat = Enum.Material.Metal, Color = Color3.fromRGB(9, 13, 22), IsLeft = false },
			{ Name = "BladeEdge", MeshId = "rbxassetid://114046103027071", Size = Vector3.new(0.0877, 0.0195, 0.0526), Offset = Vector3.new(-0.2744, 0.0000, 2.2537), Mat = Enum.Material.Metal, Color = Color3.fromRGB(99, 102, 241), IsLeft = false },
			{ Name = "Crossguard", MeshId = "rbxassetid://73748787521753", Size = Vector3.new(1.2956, 0.2360, 0.5524), Offset = Vector3.new(0.0000, 0.0000, 0.6487), Mat = Enum.Material.Metal, Color = Color3.fromRGB(67, 56, 202), IsLeft = false },
			{ Name = "Handle", MeshId = "rbxassetid://123705031062553", Size = Vector3.new(0.2680, 0.1960, 0.9880), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(251, 191, 36), IsLeft = false },
			{ Name = "Pommel", MeshId = "rbxassetid://107848397478415", Size = Vector3.new(0.2920, 0.4340, 0.4069), Offset = Vector3.new(0.0000, 0.0000, -0.5800), Mat = Enum.Material.Metal, Color = Color3.fromRGB(15, 23, 42), IsLeft = false },
			{ Name = "RuneInlay", MeshId = "rbxassetid://92033175945334", Size = Vector3.new(0.2420, 0.0457, 1.4340), Offset = Vector3.new(-0.0734, 0.0000, 1.3210), Mat = Enum.Material.Neon, Color = Color3.fromRGB(129, 140, 248), IsLeft = false },
			{ Name = "BackSpikeL", MeshId = "rbxassetid://132712040581155", Size = Vector3.new(0.3621, 0.0400, 1.4073), Offset = Vector3.new(-0.0350, 0.0000, 1.4136), Mat = Enum.Material.Metal, Color = Color3.fromRGB(49, 46, 129), IsLeft = true },
			{ Name = "BladeEdgeL", MeshId = "rbxassetid://96807793146846", Size = Vector3.new(0.0877, 0.0195, 0.0526), Offset = Vector3.new(0.2744, 0.0000, 2.2537), Mat = Enum.Material.Metal, Color = Color3.fromRGB(99, 102, 241), IsLeft = true },
			{ Name = "BladeL", MeshId = "rbxassetid://89052455861699", Size = Vector3.new(0.3916, 0.0960, 1.7874), Offset = Vector3.new(0.1359, 0.0000, 1.3337), Mat = Enum.Material.Metal, Color = Color3.fromRGB(9, 13, 22), IsLeft = true },
			{ Name = "CrossguardL", MeshId = "rbxassetid://108438982634094", Size = Vector3.new(1.2956, 0.2360, 0.5524), Offset = Vector3.new(0.0000, 0.0000, 0.6487), Mat = Enum.Material.Metal, Color = Color3.fromRGB(67, 56, 202), IsLeft = true },
			{ Name = "HandleL", MeshId = "rbxassetid://89755167209537", Size = Vector3.new(0.2680, 0.1960, 0.9880), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(251, 191, 36), IsLeft = true },
			{ Name = "PommelL", MeshId = "rbxassetid://138016873242989", Size = Vector3.new(0.2920, 0.4340, 0.4069), Offset = Vector3.new(0.0000, 0.0000, -0.5800), Mat = Enum.Material.Metal, Color = Color3.fromRGB(15, 23, 42), IsLeft = true },
			{ Name = "RuneInlayL", MeshId = "rbxassetid://99124133716748", Size = Vector3.new(0.2420, 0.0457, 1.4340), Offset = Vector3.new(0.0734, 0.0000, 1.3210), Mat = Enum.Material.Neon, Color = Color3.fromRGB(129, 140, 248), IsLeft = true },
		},
	},
}

type DaggerPartStyle = {
	Material: Enum.Material?,
	Color: Color3?,
}

type DaggerStyleData = {
	RarityTier: number,
	Parts: { [string]: DaggerPartStyle },
	PrimaryMaterial: Enum.Material?,
	PrimaryColor: Color3?,
	LeftMaterial: Enum.Material?,
	LeftColor: Color3?,
}

DAGGER_STYLES = {
	art_abyssal_ravagers = {
		RarityTier = 7,
		Parts = {
			BackSpike = { Material = Enum.Material.Metal, Color = Color3.fromRGB(88, 28, 135) },
			Blade = { Material = Enum.Material.Metal, Color = Color3.fromRGB(36, 10, 62) },
			BladeEdge = { Material = Enum.Material.Metal, Color = Color3.fromRGB(192, 132, 252) },
			Crossguard = { Material = Enum.Material.Metal, Color = Color3.fromRGB(59, 7, 100) },
			Handle = { Material = Enum.Material.Metal, Color = Color3.fromRGB(24, 8, 40) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(76, 29, 149) },
			RuneInlay = { Material = Enum.Material.Neon, Color = Color3.fromRGB(232, 121, 249) },
			BackSpikeL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(88, 28, 135) },
			BladeEdgeL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(192, 132, 252) },
			BladeL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(36, 10, 62) },
			CrossguardL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(59, 7, 100) },
			HandleL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(24, 8, 40) },
			PommelL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(76, 29, 149) },
			RuneInlayL = { Material = Enum.Material.Neon, Color = Color3.fromRGB(232, 121, 249) },
		},
	},
	art_abyssal_razor = {
		RarityTier = 6,
		Parts = {
			Blade = { Material = Enum.Material.Metal, Color = Color3.fromRGB(9, 9, 11) },
			BladeEdge = { Material = Enum.Material.Metal, Color = Color3.fromRGB(107, 33, 168) },
			Crossguard = { Material = Enum.Material.Metal, Color = Color3.fromRGB(39, 39, 42) },
			Handle = { Material = Enum.Material.Metal, Color = Color3.fromRGB(18, 19, 22) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(39, 39, 42) },
			RuneInlay = { Material = Enum.Material.Neon, Color = Color3.fromRGB(147, 51, 234) },
			BladeEdgeL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(107, 33, 168) },
			BladeL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(9, 9, 11) },
			CrossguardL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(39, 39, 42) },
			HandleL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(18, 19, 22) },
			PommelL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(39, 39, 42) },
			RuneInlayL = { Material = Enum.Material.Neon, Color = Color3.fromRGB(147, 51, 234) },
		},
	},
	art_bloodthirst_twinblades = {
		RarityTier = 5,
		Parts = {
			Blade = { Material = Enum.Material.Metal, Color = Color3.fromRGB(74, 14, 23) },
			BladeEdge = { Material = Enum.Material.Metal, Color = Color3.fromRGB(244, 63, 94) },
			Crossguard = { Material = Enum.Material.Metal, Color = Color3.fromRGB(120, 53, 15) },
			Handle = { Material = Enum.Material.Fabric, Color = Color3.fromRGB(92, 20, 30) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(88, 18, 30) },
			RuneInlay = { Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 30, 64) },
			BladeEdgeL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(244, 63, 94) },
			BladeL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(74, 14, 23) },
			CrossguardL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(120, 53, 15) },
			HandleL = { Material = Enum.Material.Fabric, Color = Color3.fromRGB(92, 20, 30) },
			PommelL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(88, 18, 30) },
			RuneInlayL = { Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 30, 64) },
		},
	},
	art_crimson_carnage = {
		RarityTier = 5,
		Parts = {
			BackSpike = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(226, 217, 208) },
			Blade = { Material = Enum.Material.Metal, Color = Color3.fromRGB(136, 19, 55) },
			BladeEdge = { Material = Enum.Material.Metal, Color = Color3.fromRGB(251, 113, 133) },
			Crossguard = { Material = Enum.Material.Metal, Color = Color3.fromRGB(131, 24, 67) },
			Handle = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(222, 216, 208) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(92, 16, 32) },
			RuneInlay = { Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 0, 51) },
			BackSpikeL = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(226, 217, 208) },
			BladeEdgeL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(251, 113, 133) },
			BladeL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(136, 19, 55) },
			CrossguardL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(131, 24, 67) },
			HandleL = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(222, 216, 208) },
			PommelL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(92, 16, 32) },
			RuneInlayL = { Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 0, 51) },
		},
	},
	art_eclipse_daggers = {
		RarityTier = 6,
		Parts = {
			Blade = { Material = Enum.Material.Metal, Color = Color3.fromRGB(252, 211, 77) },
			BladeEdge = { Material = Enum.Material.Metal, Color = Color3.fromRGB(254, 240, 138) },
			Crossguard = { Material = Enum.Material.Metal, Color = Color3.fromRGB(230, 140, 20) },
			Handle = { Material = Enum.Material.Metal, Color = Color3.fromRGB(245, 158, 11) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(251, 191, 36) },
			RuneInlay = { Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 237, 213) },
			BladeEdgeL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(248, 250, 252) },
			BladeL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(226, 232, 240) },
			CrossguardL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(170, 185, 205) },
			HandleL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(203, 213, 225) },
			PommelL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(148, 163, 184) },
			RuneInlayL = { Material = Enum.Material.Neon, Color = Color3.fromRGB(224, 242, 254) },
		},
	},
	art_nightstalker_katar = {
		RarityTier = 4,
		Parts = {
			Blade = { Material = Enum.Material.Metal, Color = Color3.fromRGB(40, 42, 50) },
			BladeEdge = { Material = Enum.Material.Neon, Color = Color3.fromRGB(168, 85, 247) },
			Crossguard = { Material = Enum.Material.Metal, Color = Color3.fromRGB(43, 45, 53) },
			Handle = { Material = Enum.Material.Metal, Color = Color3.fromRGB(43, 45, 53) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(31, 33, 40) },
			RuneInlay = { Material = Enum.Material.Neon, Color = Color3.fromRGB(192, 132, 252) },
			BladeEdgeL = { Material = Enum.Material.Neon, Color = Color3.fromRGB(168, 85, 247) },
			BladeL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(40, 42, 50) },
			CrossguardL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(43, 45, 53) },
			HandleL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(43, 45, 53) },
			PommelL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(31, 33, 40) },
			RuneInlayL = { Material = Enum.Material.Neon, Color = Color3.fromRGB(192, 132, 252) },
		},
	},
	art_phantom_edge = {
		RarityTier = 4,
		Parts = {
			Blade = { Material = Enum.Material.Glass, Color = Color3.fromRGB(56, 189, 248) },
			BladeEdge = { Material = Enum.Material.Metal, Color = Color3.fromRGB(125, 211, 252) },
			Crossguard = { Material = Enum.Material.Metal, Color = Color3.fromRGB(210, 220, 232) },
			Handle = { Material = Enum.Material.Metal, Color = Color3.fromRGB(226, 232, 240) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(226, 232, 240) },
			RuneInlay = { Material = Enum.Material.Neon, Color = Color3.fromRGB(2, 132, 199) },
			BladeEdgeL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(125, 211, 252) },
			BladeL = { Material = Enum.Material.Glass, Color = Color3.fromRGB(56, 189, 248) },
			CrossguardL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(210, 220, 232) },
			HandleL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(226, 232, 240) },
			PommelL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(226, 232, 240) },
			RuneInlayL = { Material = Enum.Material.Neon, Color = Color3.fromRGB(2, 132, 199) },
		},
	},
	art_phantom_stiletto = {
		RarityTier = 3,
		Parts = {
			Blade = { Material = Enum.Material.Glass, Color = Color3.fromRGB(93, 226, 248) },
			BladeEdge = { Material = Enum.Material.Metal, Color = Color3.fromRGB(165, 243, 252) },
			Crossguard = { Material = Enum.Material.Metal, Color = Color3.fromRGB(195, 205, 218) },
			Handle = { Material = Enum.Material.Metal, Color = Color3.fromRGB(208, 216, 226) },
			Pommel = { Material = Enum.Material.Glass, Color = Color3.fromRGB(103, 232, 249) },
			RuneInlay = { Material = Enum.Material.Neon, Color = Color3.fromRGB(56, 189, 248) },
			BladeEdgeL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(165, 243, 252) },
			BladeL = { Material = Enum.Material.Glass, Color = Color3.fromRGB(93, 226, 248) },
			CrossguardL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(195, 205, 218) },
			HandleL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(208, 216, 226) },
			PommelL = { Material = Enum.Material.Glass, Color = Color3.fromRGB(103, 232, 249) },
			RuneInlayL = { Material = Enum.Material.Neon, Color = Color3.fromRGB(56, 189, 248) },
		},
	},
	art_rusty_daggers = {
		RarityTier = 1,
		Parts = {
			Blade = { Material = Enum.Material.Metal, Color = Color3.fromRGB(50, 52, 56) },
			BladeEdge = { Material = Enum.Material.Metal, Color = Color3.fromRGB(200, 204, 214) },
			Crossguard = { Material = Enum.Material.Metal, Color = Color3.fromRGB(66, 69, 74) },
			Fuller = { Material = Enum.Material.Metal, Color = Color3.fromRGB(36, 38, 42) },
			Handle = { Material = Enum.Material.Wood, Color = Color3.fromRGB(82, 58, 38) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(66, 69, 74) },
			BladeEdgeL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(200, 204, 214) },
			BladeL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(50, 52, 56) },
			CrossguardL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(66, 69, 74) },
			FullerL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(36, 38, 42) },
			HandleL = { Material = Enum.Material.Wood, Color = Color3.fromRGB(82, 58, 38) },
			PommelL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(66, 69, 74) },
		},
	},
	art_serrated_skewers = {
		RarityTier = 1,
		Parts = {
			BackSpike = { Material = Enum.Material.Metal, Color = Color3.fromRGB(110, 114, 125) },
			Blade = { Material = Enum.Material.Metal, Color = Color3.fromRGB(88, 92, 102) },
			BladeEdge = { Material = Enum.Material.Metal, Color = Color3.fromRGB(210, 214, 224) },
			Crossguard = { Material = Enum.Material.Metal, Color = Color3.fromRGB(200, 150, 62) },
			Handle = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(44, 46, 51) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(200, 150, 62) },
			BackSpikeL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(110, 114, 125) },
			BladeEdgeL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(210, 214, 224) },
			BladeL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(88, 92, 102) },
			CrossguardL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(200, 150, 62) },
			HandleL = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(44, 46, 51) },
			PommelL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(200, 150, 62) },
		},
	},
	art_shadow_fangs = {
		RarityTier = 3,
		Parts = {
			BackSpike = { Material = Enum.Material.Metal, Color = Color3.fromRGB(70, 55, 45) },
			Blade = { Material = Enum.Material.Glass, Color = Color3.fromRGB(24, 20, 32) },
			BladeEdge = { Material = Enum.Material.Metal, Color = Color3.fromRGB(88, 46, 122) },
			Crossguard = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(216, 210, 196) },
			Handle = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(216, 210, 196) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(50, 40, 34) },
			BackSpikeL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(70, 55, 45) },
			BladeEdgeL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(88, 46, 122) },
			BladeL = { Material = Enum.Material.Glass, Color = Color3.fromRGB(24, 20, 32) },
			CrossguardL = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(216, 210, 196) },
			HandleL = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(216, 210, 196) },
			PommelL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(50, 40, 34) },
		},
	},
	art_silent_dirks = {
		RarityTier = 2,
		Parts = {
			Blade = { Material = Enum.Material.Metal, Color = Color3.fromRGB(48, 58, 72) },
			BladeEdge = { Material = Enum.Material.Metal, Color = Color3.fromRGB(82, 106, 146) },
			Crossguard = { Material = Enum.Material.Metal, Color = Color3.fromRGB(56, 68, 86) },
			Fuller = { Material = Enum.Material.Metal, Color = Color3.fromRGB(24, 28, 34) },
			Handle = { Material = Enum.Material.Slate, Color = Color3.fromRGB(34, 38, 44) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(50, 60, 74) },
			BladeEdgeL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(82, 106, 146) },
			BladeL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(48, 58, 72) },
			CrossguardL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(56, 68, 86) },
			FullerL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(24, 28, 34) },
			HandleL = { Material = Enum.Material.Slate, Color = Color3.fromRGB(34, 38, 44) },
			PommelL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(50, 60, 74) },
		},
	},
	art_viper_kris = {
		RarityTier = 2,
		Parts = {
			Blade = { Material = Enum.Material.Metal, Color = Color3.fromRGB(114, 98, 68) },
			BladeEdge = { Material = Enum.Material.Metal, Color = Color3.fromRGB(46, 204, 113) },
			Crossguard = { Material = Enum.Material.Metal, Color = Color3.fromRGB(200, 154, 56) },
			Handle = { Material = Enum.Material.Metal, Color = Color3.fromRGB(100, 80, 48) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(200, 154, 56) },
			RuneInlay = { Material = Enum.Material.Neon, Color = Color3.fromRGB(16, 185, 129) },
			BladeEdgeL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(46, 204, 113) },
			BladeL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(114, 98, 68) },
			CrossguardL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(200, 154, 56) },
			HandleL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(100, 80, 48) },
			PommelL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(200, 154, 56) },
			RuneInlayL = { Material = Enum.Material.Neon, Color = Color3.fromRGB(16, 185, 129) },
		},
	},
	art_void_reapers = {
		RarityTier = 7,
		Parts = {
			BackSpike = { Material = Enum.Material.Metal, Color = Color3.fromRGB(49, 46, 129) },
			Blade = { Material = Enum.Material.Metal, Color = Color3.fromRGB(9, 13, 22) },
			BladeEdge = { Material = Enum.Material.Metal, Color = Color3.fromRGB(99, 102, 241) },
			Crossguard = { Material = Enum.Material.Metal, Color = Color3.fromRGB(67, 56, 202) },
			Handle = { Material = Enum.Material.Metal, Color = Color3.fromRGB(251, 191, 36) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(15, 23, 42) },
			RuneInlay = { Material = Enum.Material.Neon, Color = Color3.fromRGB(129, 140, 248) },
			BackSpikeL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(49, 46, 129) },
			BladeEdgeL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(99, 102, 241) },
			BladeL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(9, 13, 22) },
			CrossguardL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(67, 56, 202) },
			HandleL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(251, 191, 36) },
			PommelL = { Material = Enum.Material.Metal, Color = Color3.fromRGB(15, 23, 42) },
			RuneInlayL = { Material = Enum.Material.Neon, Color = Color3.fromRGB(129, 140, 248) },
		},
	},
} :: { [string]: DaggerStyleData }

local function makeMeshDagger(name: string): Model
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local weaponsFolder = assets and assets:FindFirstChild("Weapons")
	local existing = weaponsFolder and weaponsFolder:FindFirstChild(name)
	if existing and existing:IsA("Model") then
		return existing:Clone()
	end

	local data = DAGGER_MESH_DATA[name]
	assert(data, `No dagger mesh data for {name}`)

	local model = Instance.new("Model")
	model.Name = name

	local style = DAGGER_STYLES and DAGGER_STYLES[name]

	local leftDagger = Instance.new("Model")
	leftDagger.Name = "LeftDagger"
	leftDagger.Parent = model

	local handlePart: MeshPart?
	local handlePartL: MeshPart?

	for _, pInfo in ipairs(data.Parts) do
		local p = newUploadedMeshPart(pInfo.MeshId)
		p.Name = pInfo.Name
		p.Size = pInfo.Size
		p.CFrame = CFrame.new(pInfo.Offset)

		local pStyle = style and style.Parts and style.Parts[pInfo.Name]
		p.Material = (pStyle and pStyle.Material) or pInfo.Mat or Enum.Material.Metal
		p.Color = (pStyle and pStyle.Color) or pInfo.Color or Color3.fromRGB(150, 150, 150)

		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.Anchored = false
		p.CastShadow = false

		if pInfo.IsLeft then
			p.Parent = leftDagger
			if pInfo.Name == "HandleL" then
				handlePartL = p
				leftDagger.PrimaryPart = p
			end
		else
			p.Parent = model
			if pInfo.Name == "Handle" then
				handlePart = p
				model.PrimaryPart = p
			end
		end
	end

	assert(handlePart, `Handle part missing for {name}`)
	assert(handlePartL, `HandleL part missing for {name}`)

	-- Weld right dagger parts to Handle
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") and child ~= handlePart then
			local weld = Instance.new("WeldConstraint")
			weld.Name = "Weld_" .. child.Name
			weld.Part0 = handlePart
			weld.Part1 = child
			weld.Parent = handlePart
		end
	end

	-- Weld left dagger parts to HandleL
	for _, child in ipairs(leftDagger:GetChildren()) do
		if child:IsA("BasePart") and child ~= handlePartL then
			local weld = Instance.new("WeldConstraint")
			weld.Name = "Weld_" .. child.Name
			weld.Part0 = handlePartL
			weld.Part1 = child
			weld.Parent = handlePartL
		end
	end

	-- Attachments / Sockets for both Handle and HandleL
	local function setupSockets(part: MeshPart)
		local grip = Instance.new("Attachment")
		grip.Name = "Grip"
		grip.CFrame = CFrame.fromMatrix(data.GripPos, Vector3.new(0, -1, 0), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0))
		grip.Parent = part

		local tip = Instance.new("Attachment")
		tip.Name = "Tip"
		tip.CFrame = CFrame.new(data.TipPos)
		tip.Parent = part

		local vfxTip = Instance.new("Attachment")
		vfxTip.Name = "VfxTip"
		vfxTip.CFrame = CFrame.new(data.TipPos)
		vfxTip.Parent = part

		local vfxBase = Instance.new("Attachment")
		vfxBase.Name = "VfxBase"
		vfxBase.CFrame = CFrame.new(data.BasePos)
		vfxBase.Parent = part

		local vfxCore = Instance.new("Attachment")
		vfxCore.Name = "VfxCore"
		vfxCore.CFrame = CFrame.new(data.CorePos)
		vfxCore.Parent = part
	end

	setupSockets(handlePart)
	setupSockets(handlePartL)

	-- Apply client-side weapon VFX (glints, lights, auras, trails)
	local combatVfx = assets and assets:FindFirstChild("CombatVfx")
	local weaponVfxMod = combatVfx and combatVfx:FindFirstChild("WeaponVfx")
	if weaponVfxMod then
		local ok, WeaponVfx = pcall(require, weaponVfxMod)
		if ok and WeaponVfx and WeaponVfx.Apply then
			local rarity = style and style.RarityTier or 1
			WeaponVfx.Apply(model, "DAGGERS", rarity, name)
		end
	end

	return model
end

function WeaponModelBuilder.BuildRustyDaggersArtifact(): Model
	return makeMeshDagger("art_rusty_daggers")
end

function WeaponModelBuilder.BuildSerratedSkewersArtifact(): Model
	return makeMeshDagger("art_serrated_skewers")
end

function WeaponModelBuilder.BuildViperKrisArtifact(): Model
	return makeMeshDagger("art_viper_kris")
end

function WeaponModelBuilder.BuildSilentDirksArtifact(): Model
	return makeMeshDagger("art_silent_dirks")
end

function WeaponModelBuilder.BuildShadowFangsArtifact(): Model
	return makeMeshDagger("art_shadow_fangs")
end

function WeaponModelBuilder.BuildPhantomStilettoArtifact(): Model
	return makeMeshDagger("art_phantom_stiletto")
end

function WeaponModelBuilder.BuildPhantomEdgeArtifact(): Model
	return makeMeshDagger("art_phantom_edge")
end

function WeaponModelBuilder.BuildNightstalkerKatarArtifact(): Model
	return makeMeshDagger("art_nightstalker_katar")
end

function WeaponModelBuilder.BuildBloodthirstTwinbladesArtifact(): Model
	return makeMeshDagger("art_bloodthirst_twinblades")
end

function WeaponModelBuilder.BuildCrimsonCarnageArtifact(): Model
	return makeMeshDagger("art_crimson_carnage")
end

function WeaponModelBuilder.BuildEclipseDaggersArtifact(): Model
	return makeMeshDagger("art_eclipse_daggers")
end

function WeaponModelBuilder.BuildAbyssalRazorArtifact(): Model
	return makeMeshDagger("art_abyssal_razor")
end

function WeaponModelBuilder.BuildAbyssalRavagersArtifact(): Model
	return makeMeshDagger("art_abyssal_ravagers")
end

function WeaponModelBuilder.BuildVoidReapersArtifact(): Model
	return makeMeshDagger("art_void_reapers")
end

-- ============================================================================
-- BERSERKER GREATAXES (Batch 4) - 14 modular two-handed greataxes
-- ============================================================================
-- Imported with tests/studio-greataxe-import.luau from assets/artifacts/axes/*.fbx. In the
-- Handle's space the haft runs along +Y (head up) and the main cutting edge faces +X. Materials
-- and colours come from AXE_STYLES. Offsets and sizes are in studs.
type AxePartData = {
	Name: string,
	MeshId: string,
	Size: Vector3,
	Offset: Vector3,
}

type AxeMeshData = {
	Parts: { AxePartData },
	GripPos: Vector3, -- upper (right) hand
	OffhandGripPos: Vector3, -- lower (left) hand, AXE_HAND_GAP towards the butt
	TipPos: Vector3,
	BasePos: Vector3,
	CorePos: Vector3,
}

local AXE_MESH_DATA: { [string]: AxeMeshData } = {
	art_miner_pickaxe = {
		GripPos = Vector3.new(0.0000, 0.5800, 0.0000),
		OffhandGripPos = Vector3.new(0.0000, -1.1200, 0.0000),
		TipPos = Vector3.new(1.1250, 2.6300, 0.0000),
		BasePos = Vector3.new(1.0750, 1.0800, 0.0000),
		CorePos = Vector3.new(0.5625, 2.0800, 0.0000),
		Parts = {
			{ Name = "Handle", MeshId = "rbxassetid://109773881228463", Size = Vector3.new(0.2100, 5.2000, 0.2100), Offset = Vector3.new(0.0000, 0.0000, 0.0000) },
			{ Name = "GripWrap", MeshId = "rbxassetid://82568459452584", Size = Vector3.new(0.2520, 2.4200, 0.2520), Offset = Vector3.new(0.0000, -0.2700, 0.0000) },
			{ Name = "Pommel", MeshId = "rbxassetid://94171209498967", Size = Vector3.new(0.3150, 0.3600, 0.3150), Offset = Vector3.new(0.0000, -2.5800, 0.0000) },
			{ Name = "HeadCollar", MeshId = "rbxassetid://129687261573943", Size = Vector3.new(0.3801, 1.3100, 0.3497), Offset = Vector3.new(0.0000, 1.9250, 0.0000) },
			{ Name = "Blade", MeshId = "rbxassetid://129009107137173", Size = Vector3.new(1.2450, 1.5500, 0.1600), Offset = Vector3.new(0.6025, 1.8550, 0.0000) },
			{ Name = "BladeEdge", MeshId = "rbxassetid://128545858833589", Size = Vector3.new(0.2163, 1.5596, 0.1230), Offset = Vector3.new(1.1368, 1.8544, 0.0000) },
			{ Name = "BackSpike", MeshId = "rbxassetid://105161887034805", Size = Vector3.new(0.3800, 0.4500, 0.2835), Offset = Vector3.new(-0.2950, 2.0800, 0.0000) },
		},
	},
	art_heavy_hewing_axe = {
		GripPos = Vector3.new(0.0000, 0.4600, 0.0000),
		OffhandGripPos = Vector3.new(0.0000, -1.2400, 0.0000),
		TipPos = Vector3.new(1.2600, 2.8600, 0.0000),
		BasePos = Vector3.new(1.2040, 0.9600, 0.0000),
		CorePos = Vector3.new(0.6300, 2.0100, 0.0000),
		Parts = {
			{ Name = "Handle", MeshId = "rbxassetid://119450506780293", Size = Vector3.new(0.2300, 5.3000, 0.2300), Offset = Vector3.new(0.0000, 0.0000, 0.0000) },
			{ Name = "GripWrap", MeshId = "rbxassetid://72900063451041", Size = Vector3.new(0.2760, 2.4200, 0.2760), Offset = Vector3.new(0.0000, -0.3900, 0.0000) },
			{ Name = "Pommel", MeshId = "rbxassetid://89449665445167", Size = Vector3.new(0.4025, 0.4612, 0.4025), Offset = Vector3.new(0.0000, -2.6807, 0.0000) },
			{ Name = "HeadCollar", MeshId = "rbxassetid://80537875441032", Size = Vector3.new(0.4163, 2.1350, 0.3830), Offset = Vector3.new(0.0000, 1.5625, 0.0000) },
			{ Name = "Blade", MeshId = "rbxassetid://78702626230632", Size = Vector3.new(1.3500, 1.9000, 0.2000), Offset = Vector3.new(0.6550, 1.9100, 0.0000) },
			{ Name = "BladeEdge", MeshId = "rbxassetid://125601023525044", Size = Vector3.new(0.1990, 1.9062, 0.1450), Offset = Vector3.new(1.2505, 1.9094, 0.0000) },
			{ Name = "BackSpike", MeshId = "rbxassetid://123627611674527", Size = Vector3.new(0.5800, 0.8190, 0.3105), Offset = Vector3.new(-0.4050, 2.0100, 0.0000) },
		},
	},
	art_canyon_splitter = {
		GripPos = Vector3.new(0.0000, 0.3300, 0.0000),
		OffhandGripPos = Vector3.new(0.0000, -1.3700, 0.0000),
		TipPos = Vector3.new(1.3050, 2.8800, 0.0000),
		BasePos = Vector3.new(1.2470, 0.8300, 0.0000),
		CorePos = Vector3.new(0.6525, 2.0800, 0.0000),
		Parts = {
			{ Name = "Handle", MeshId = "rbxassetid://79662440402911", Size = Vector3.new(0.2400, 5.4000, 0.2283), Offset = Vector3.new(0.0000, 0.0000, 0.0000) },
			{ Name = "GripWrap", MeshId = "rbxassetid://71602687449906", Size = Vector3.new(0.2880, 2.4200, 0.2739), Offset = Vector3.new(0.0000, -0.5200, 0.0000) },
			{ Name = "Pommel", MeshId = "rbxassetid://77552975024105", Size = Vector3.new(0.5880, 0.6946, 0.3196), Offset = Vector3.new(0.0000, -2.8673, 0.0000) },
			{ Name = "HeadCollar", MeshId = "rbxassetid://140203607906820", Size = Vector3.new(0.4488, 3.2900, 0.3927), Offset = Vector3.new(0.0000, 1.0350, 0.0000) },
			{ Name = "Blade", MeshId = "rbxassetid://90093374420444", Size = Vector3.new(1.3845, 2.0500, 0.2200), Offset = Vector3.new(0.6723, 1.8550, 0.0000) },
			{ Name = "BladeEdge", MeshId = "rbxassetid://85785425952680", Size = Vector3.new(0.1927, 2.0552, 0.1560), Offset = Vector3.new(1.2882, 1.8545, 0.0000) },
			{ Name = "BackSpike", MeshId = "rbxassetid://94315946513429", Size = Vector3.new(0.9700, 0.6400, 0.1980), Offset = Vector3.new(-0.4650, 2.0800, 0.0000) },
			{ Name = "RuneInlay", MeshId = "rbxassetid://89000027353376", Size = Vector3.new(1.3198, 0.7718, 0.2188), Offset = Vector3.new(0.5931, 2.7673, 0.0060) },
		},
	},
	art_quakestone_greataxe = {
		GripPos = Vector3.new(0.0000, 0.2990, 0.0000),
		OffhandGripPos = Vector3.new(0.0000, -1.4010, 0.0000),
		TipPos = Vector3.new(1.3500, 3.1490, 0.0000),
		BasePos = Vector3.new(1.2900, 0.7990, 0.0000),
		CorePos = Vector3.new(0.6750, 2.0990, 0.0000),
		Parts = {
			{ Name = "Handle", MeshId = "rbxassetid://71972021455682", Size = Vector3.new(0.2600, 5.5000, 0.2252), Offset = Vector3.new(0.0000, 0.0000, 0.0000) },
			{ Name = "GripWrap", MeshId = "rbxassetid://127482820048600", Size = Vector3.new(0.3120, 2.4200, 0.3120), Offset = Vector3.new(0.0000, -0.5510, 0.0000) },
			{ Name = "Pommel", MeshId = "rbxassetid://125884019315848", Size = Vector3.new(0.3900, 0.3600, 0.3900), Offset = Vector3.new(0.0000, -2.7300, 0.0000) },
			{ Name = "HeadCollar", MeshId = "rbxassetid://85995778539796", Size = Vector3.new(0.4862, 3.3400, 0.4473), Offset = Vector3.new(0.0000, 1.0291, 0.0000) },
			{ Name = "Blade", MeshId = "rbxassetid://107089315488255", Size = Vector3.new(1.5350, 2.3500, 0.2200), Offset = Vector3.new(0.7475, 1.9740, 0.0000) },
			{ Name = "BladeEdge", MeshId = "rbxassetid://124463868777868", Size = Vector3.new(0.3006, 2.3599, 0.1560), Offset = Vector3.new(1.3847, 1.9735, 0.0000) },
			{ Name = "BackSpike", MeshId = "rbxassetid://88096914718422", Size = Vector3.new(1.1125, 1.4710, 0.2815), Offset = Vector3.new(-0.3937, 2.5145, 0.0000) },
			{ Name = "RuneInlay", MeshId = "rbxassetid://131649248097616", Size = Vector3.new(0.6615, 0.6211, 0.2640), Offset = Vector3.new(0.7619, 2.0990, 0.0000) },
		},
	},
	art_battleaxe_cleaver = {
		GripPos = Vector3.new(0.0000, 0.5800, 0.0000),
		OffhandGripPos = Vector3.new(0.0000, -1.1200, 0.0000),
		TipPos = Vector3.new(1.3050, 3.1800, 0.0000),
		BasePos = Vector3.new(1.2470, 1.0800, 0.0000),
		CorePos = Vector3.new(0.6525, 2.1800, 0.0000),
		Parts = {
			{ Name = "Handle", MeshId = "rbxassetid://89078483037450", Size = Vector3.new(0.2500, 5.6000, 0.2378), Offset = Vector3.new(0.0000, 0.0000, 0.0000) },
			{ Name = "GripWrap", MeshId = "rbxassetid://87270001154303", Size = Vector3.new(0.3000, 2.4200, 0.2853), Offset = Vector3.new(0.0000, -0.2700, 0.0000) },
			{ Name = "Pommel", MeshId = "rbxassetid://127896046418750", Size = Vector3.new(0.4000, 0.7500, 0.3804), Offset = Vector3.new(0.0000, -2.9750, 0.0000) },
			{ Name = "HeadCollar", MeshId = "rbxassetid://106213043456920", Size = Vector3.new(0.4825, 4.7300, 0.5513), Offset = Vector3.new(0.0000, 0.5350, 0.0000) },
			{ Name = "Blade", MeshId = "rbxassetid://108276742968257", Size = Vector3.new(1.4700, 2.1000, 0.2200), Offset = Vector3.new(0.7150, 2.1300, 0.0000) },
			{ Name = "BladeEdge", MeshId = "rbxassetid://72611934343834", Size = Vector3.new(2.9400, 2.1100, 0.1560), Offset = Vector3.new(0.0000, 2.1295, 0.0000) },
			{ Name = "BackSpike", MeshId = "rbxassetid://122406048878171", Size = Vector3.new(1.6500, 2.6700, 0.2200), Offset = Vector3.new(-0.6250, 2.4150, 0.0000) },
			{ Name = "RuneInlay", MeshId = "rbxassetid://108131857254631", Size = Vector3.new(1.9317, 0.8014, 0.7722), Offset = Vector3.new(0.0000, 2.1801, 0.0000) },
		},
	},
	art_iron_juggernaut_cleaver = {
		GripPos = Vector3.new(0.0000, 0.2300, 0.0000),
		OffhandGripPos = Vector3.new(0.0000, -1.4700, 0.0000),
		TipPos = Vector3.new(1.5360, 3.1380, 0.0000),
		BasePos = Vector3.new(1.1520, 0.7300, 0.0000),
		CorePos = Vector3.new(0.7200, 2.0800, 0.0000),
		Parts = {
			{ Name = "Handle", MeshId = "rbxassetid://90375561019897", Size = Vector3.new(0.2700, 5.6000, 0.2568), Offset = Vector3.new(0.0000, 0.0000, 0.0000) },
			{ Name = "GripWrap", MeshId = "rbxassetid://120732176274446", Size = Vector3.new(0.3240, 2.4200, 0.3081), Offset = Vector3.new(0.0000, -0.6200, 0.0000) },
			{ Name = "Pommel", MeshId = "rbxassetid://91916151229473", Size = Vector3.new(0.4725, 0.4962, 0.4494), Offset = Vector3.new(0.0000, -2.8481, 0.0000) },
			{ Name = "HeadCollar", MeshId = "rbxassetid://88800978953592", Size = Vector3.new(0.5211, 4.9600, 0.5868), Offset = Vector3.new(0.0000, 0.3000, 0.0000) },
			{ Name = "Blade", MeshId = "rbxassetid://130103159979309", Size = Vector3.new(1.6200, 2.5000, 0.3000), Offset = Vector3.new(0.7900, 1.9800, 0.0000) },
			{ Name = "BladeEdge", MeshId = "rbxassetid://79988274269140", Size = Vector3.new(0.5141, 2.4218, 0.2000), Offset = Vector3.new(1.3627, 1.9277, 0.0000) },
			{ Name = "BackSpike", MeshId = "rbxassetid://97177239308079", Size = Vector3.new(0.6510, 1.0000, 0.4860), Offset = Vector3.new(-0.4605, 2.0800, 0.0000) },
			{ Name = "RuneInlay", MeshId = "rbxassetid://114757363177253", Size = Vector3.new(0.6254, 1.4683, 0.3440), Offset = Vector3.new(0.8480, 1.9399, 0.0000) },
		},
	},
	art_magma_behemoth = {
		GripPos = Vector3.new(0.0000, 0.2180, 0.0000),
		OffhandGripPos = Vector3.new(0.0000, -1.4820, 0.0000),
		TipPos = Vector3.new(1.5300, 3.2680, 0.0000),
		BasePos = Vector3.new(1.4620, 0.7180, 0.0000),
		CorePos = Vector3.new(0.7650, 2.1680, 0.0000),
		Parts = {
			{ Name = "Handle", MeshId = "rbxassetid://86324771258672", Size = Vector3.new(0.2975, 5.7000, 0.2951), Offset = Vector3.new(0.0000, 0.0000, 0.0000) },
			{ Name = "GripWrap", MeshId = "rbxassetid://101545700060214", Size = Vector3.new(0.3360, 2.4200, 0.3360), Offset = Vector3.new(-0.0026, -0.6320, 0.0051) },
			{ Name = "Pommel", MeshId = "rbxassetid://128699143147809", Size = Vector3.new(0.4760, 6.1025, 0.4122), Offset = Vector3.new(-0.0026, 0.1813, 0.0051) },
			{ Name = "HeadCollar", MeshId = "rbxassetid://75586951544825", Size = Vector3.new(0.5572, 3.5400, 0.5126), Offset = Vector3.new(-0.0026, 1.0480, 0.0051) },
			{ Name = "Blade", MeshId = "rbxassetid://103426460663944", Size = Vector3.new(1.7492, 2.5500, 0.3000), Offset = Vector3.new(0.8521, 1.9930, 0.0051) },
			{ Name = "BladeEdge", MeshId = "rbxassetid://96953390499609", Size = Vector3.new(0.3611, 2.5709, 0.2000), Offset = Vector3.new(1.5660, 1.9937, 0.0051) },
			{ Name = "BackSpike", MeshId = "rbxassetid://98275551811389", Size = Vector3.new(1.6777, 1.5420, 0.3412), Offset = Vector3.new(-0.6837, 2.5790, 0.0051) },
			{ Name = "RuneInlay", MeshId = "rbxassetid://72769107530143", Size = Vector3.new(1.0434, 1.3867, 0.3440), Offset = Vector3.new(0.7448, 2.0588, 0.0051) },
		},
	},
	art_obsidian_hell_splitter = {
		GripPos = Vector3.new(0.0000, 0.3870, 0.0000),
		OffhandGripPos = Vector3.new(0.0000, -1.3130, 0.0000),
		TipPos = Vector3.new(1.4400, 3.3370, 0.0000),
		BasePos = Vector3.new(1.3760, 0.8870, 0.0000),
		CorePos = Vector3.new(0.7200, 2.1870, 0.0000),
		Parts = {
			{ Name = "Handle", MeshId = "rbxassetid://79687283302419", Size = Vector3.new(0.2700, 5.8000, 0.2700), Offset = Vector3.new(0.0000, 0.0000, 0.0000) },
			{ Name = "GripWrap", MeshId = "rbxassetid://134881646012374", Size = Vector3.new(0.3240, 2.4200, 0.3240), Offset = Vector3.new(0.0000, -0.4630, 0.0000) },
			{ Name = "Pommel", MeshId = "rbxassetid://98596001073143", Size = Vector3.new(0.4590, 6.2025, 0.3975), Offset = Vector3.new(0.0000, 0.1813, 0.0000) },
			{ Name = "HeadCollar", MeshId = "rbxassetid://81421501563031", Size = Vector3.new(0.5373, 5.0230, 0.4943), Offset = Vector3.new(0.0000, 0.4885, 0.0000) },
			{ Name = "Blade", MeshId = "rbxassetid://108296715353112", Size = Vector3.new(1.6293, 2.4500, 0.2400), Offset = Vector3.new(0.7946, 2.1121, 0.0000) },
			{ Name = "BladeEdge", MeshId = "rbxassetid://126393339175438", Size = Vector3.new(3.2651, 2.4704, 0.1670), Offset = Vector3.new(-0.0033, 2.1110, 0.0000) },
			{ Name = "BackSpike", MeshId = "rbxassetid://138755075334013", Size = Vector3.new(1.8159, 2.9630, 0.2400), Offset = Vector3.new(-0.7080, 2.3685, 0.0000) },
			{ Name = "RuneInlay", MeshId = "rbxassetid://127405192196350", Size = Vector3.new(2.3878, 1.3006, 0.8216), Offset = Vector3.new(0.0007, 2.1405, 0.0000) },
		},
	},
	art_titan_earthshaker = {
		GripPos = Vector3.new(0.0000, 0.2130, 0.0000),
		OffhandGripPos = Vector3.new(0.0000, -1.4870, 0.0000),
		TipPos = Vector3.new(1.6200, 3.5130, 0.0000),
		BasePos = Vector3.new(1.5480, 0.7130, 0.0000),
		CorePos = Vector3.new(0.8100, 2.1630, 0.0000),
		Parts = {
			{ Name = "Handle", MeshId = "rbxassetid://108637142443728", Size = Vector3.new(0.2900, 6.0000, 0.2900), Offset = Vector3.new(0.0000, 0.0000, 0.0000) },
			{ Name = "GripWrap", MeshId = "rbxassetid://125803412064582", Size = Vector3.new(0.3480, 2.4200, 0.3480), Offset = Vector3.new(0.0000, -0.6370, 0.0000) },
			{ Name = "Pommel", MeshId = "rbxassetid://114387369869546", Size = Vector3.new(0.5945, 0.8600, 0.5945), Offset = Vector3.new(0.0000, -3.1700, 0.0000) },
			{ Name = "HeadCollar", MeshId = "rbxassetid://117269060488112", Size = Vector3.new(0.5945, 5.2970, 0.6682), Offset = Vector3.new(0.0000, 0.4515, 0.0000) },
			{ Name = "Blade", MeshId = "rbxassetid://101702863064507", Size = Vector3.new(1.8560, 2.8000, 0.2600), Offset = Vector3.new(0.9080, 2.1130, 0.0000) },
			{ Name = "BladeEdge", MeshId = "rbxassetid://85552726851546", Size = Vector3.new(3.7120, 2.8108, 0.1780), Offset = Vector3.new(0.0000, 2.1125, 0.0000) },
			{ Name = "BackSpike", MeshId = "rbxassetid://120389072019686", Size = Vector3.new(2.0360, 3.6870, 0.2600), Offset = Vector3.new(-0.8180, 2.5565, 0.0000) },
			{ Name = "RuneInlay", MeshId = "rbxassetid://95414121871679", Size = Vector3.new(2.5290, 1.6886, 0.8730), Offset = Vector3.new(0.0000, 2.1376, 0.0000) },
		},
	},
	art_mountain_breaker = {
		GripPos = Vector3.new(0.0000, 0.0320, 0.0000),
		OffhandGripPos = Vector3.new(0.0000, -1.6680, 0.0000),
		TipPos = Vector3.new(1.6720, 3.2240, 0.0000),
		BasePos = Vector3.new(1.7860, 0.8520, 0.0000),
		CorePos = Vector3.new(0.8550, 2.1320, 0.0000),
		Parts = {
			{ Name = "Handle", MeshId = "rbxassetid://130802419797662", Size = Vector3.new(0.3390, 6.0000, 0.3362), Offset = Vector3.new(0.0000, 0.0000, 0.0000) },
			{ Name = "GripWrap", MeshId = "rbxassetid://112063351178805", Size = Vector3.new(0.3840, 2.4200, 0.3840), Offset = Vector3.new(-0.0029, -0.8180, 0.0057) },
			{ Name = "Pommel", MeshId = "rbxassetid://79173854299112", Size = Vector3.new(0.6560, 0.8600, 0.6560), Offset = Vector3.new(-0.0029, -3.1700, 0.0057) },
			{ Name = "HeadCollar", MeshId = "rbxassetid://124486439432205", Size = Vector3.new(0.6560, 5.3100, 0.6035), Offset = Vector3.new(-0.0029, 0.2770, 0.0057) },
			{ Name = "Blade", MeshId = "rbxassetid://75900507775688", Size = Vector3.new(1.9200, 3.0000, 0.4200), Offset = Vector3.new(0.9371, 2.0320, 0.0057) },
			{ Name = "BladeEdge", MeshId = "rbxassetid://81712330961787", Size = Vector3.new(0.3116, 2.3783, 0.2660), Offset = Vector3.new(1.7612, 2.0396, 0.0057) },
			{ Name = "BackSpike", MeshId = "rbxassetid://108017338349774", Size = Vector3.new(1.1277, 1.9980, 0.6720), Offset = Vector3.new(-0.3866, 2.5010, 0.0057) },
			{ Name = "RuneInlay", MeshId = "rbxassetid://89093571902546", Size = Vector3.new(0.3800, 1.9500, 0.4640), Offset = Vector3.new(0.9471, 1.9871, 0.0057) },
		},
	},
	art_valkyrie_waraxe = {
		GripPos = Vector3.new(0.0000, 0.0580, 0.0000),
		OffhandGripPos = Vector3.new(0.0000, -1.6420, 0.0000),
		TipPos = Vector3.new(1.4000, 3.6580, 0.0000),
		BasePos = Vector3.new(1.4000, 0.5580, 0.0000),
		CorePos = Vector3.new(0.7875, 2.0580, 0.0000),
		Parts = {
			{ Name = "Handle", MeshId = "rbxassetid://92809868602326", Size = Vector3.new(0.2704, 6.1000, 0.2636), Offset = Vector3.new(0.0000, 0.0000, 0.0000) },
			{ Name = "GripWrap", MeshId = "rbxassetid://99139881641931", Size = Vector3.new(0.3120, 2.4200, 0.3042), Offset = Vector3.new(0.0000, -0.7920, 0.0000) },
			{ Name = "Pommel", MeshId = "rbxassetid://108333270220911", Size = Vector3.new(0.5330, 0.8600, 0.5330), Offset = Vector3.new(0.0000, -3.2200, 0.0000) },
			{ Name = "HeadCollar", MeshId = "rbxassetid://77791252143031", Size = Vector3.new(0.5486, 5.8320, 0.4921), Offset = Vector3.new(0.0000, 0.2340, 0.0000) },
			{ Name = "Blade", MeshId = "rbxassetid://76887488218693", Size = Vector3.new(1.7000, 3.1000, 0.2200), Offset = Vector3.new(0.8300, 2.1080, 0.0000) },
			{ Name = "BladeEdge", MeshId = "rbxassetid://112133507649262", Size = Vector3.new(0.3630, 3.1109, 0.1560), Offset = Vector3.new(1.5185, 2.1080, 0.0000) },
			{ Name = "BackSpike", MeshId = "rbxassetid://122122598478578", Size = Vector3.new(1.3813, 2.9840, 0.1200), Offset = Vector3.new(-0.4907, 2.9580, 0.0000) },
			{ Name = "RuneInlay", MeshId = "rbxassetid://87878414447245", Size = Vector3.new(0.9470, 1.4520, 0.8317), Offset = Vector3.new(0.3015, 2.0790, 0.0000) },
		},
	},
	art_world_shaper = {
		GripPos = Vector3.new(0.0000, 0.1320, 0.0000),
		OffhandGripPos = Vector3.new(0.0000, -1.5680, 0.0000),
		TipPos = Vector3.new(1.7100, 3.6320, 0.0000),
		BasePos = Vector3.new(1.6340, 0.6320, 0.0000),
		CorePos = Vector3.new(0.8550, 2.2320, 0.0000),
		Parts = {
			{ Name = "Handle", MeshId = "rbxassetid://80841942461919", Size = Vector3.new(0.3000, 6.2000, 0.2925), Offset = Vector3.new(0.0000, 0.0000, 0.0000) },
			{ Name = "GripWrap", MeshId = "rbxassetid://108844582964260", Size = Vector3.new(0.3600, 2.4200, 0.3510), Offset = Vector3.new(0.0000, -0.7180, 0.0000) },
			{ Name = "Pommel", MeshId = "rbxassetid://76711884700270", Size = Vector3.new(0.6150, 0.8600, 0.6150), Offset = Vector3.new(0.0000, -3.2700, 0.0000) },
			{ Name = "HeadCollar", MeshId = "rbxassetid://82926485737471", Size = Vector3.new(1.0600, 6.7880, 0.9947), Offset = Vector3.new(0.0000, 0.7860, 0.0000) },
			{ Name = "Blade", MeshId = "rbxassetid://103685906828970", Size = Vector3.new(1.9208, 3.0000, 0.3000), Offset = Vector3.new(0.9404, 2.1320, 0.0000) },
			{ Name = "BladeEdge", MeshId = "rbxassetid://72651788900013", Size = Vector3.new(0.3501, 3.0092, 0.2000), Offset = Vector3.new(1.7457, 2.1316, 0.0000) },
			{ Name = "BackSpike", MeshId = "rbxassetid://99969748795547", Size = Vector3.new(0.9825, 1.0500, 0.6300), Offset = Vector3.new(-0.6412, 2.2321, 0.0000) },
			{ Name = "RuneInlay", MeshId = "rbxassetid://90795644688029", Size = Vector3.new(1.5900, 2.2780, 0.5200), Offset = Vector3.new(0.5350, 2.7710, 0.0000) },
		},
	},
	art_world_carver = {
		GripPos = Vector3.new(0.0000, -0.4780, 0.0000),
		OffhandGripPos = Vector3.new(0.0000, -2.1780, 0.0000),
		TipPos = Vector3.new(1.8860, 3.9220, 0.0000),
		BasePos = Vector3.new(1.7940, 0.0220, 0.0000),
		CorePos = Vector3.new(1.0350, 2.0220, 0.0000),
		Parts = {
			{ Name = "Handle", MeshId = "rbxassetid://71637548209624", Size = Vector3.new(0.3260, 6.4000, 0.3233), Offset = Vector3.new(0.0000, 0.0000, 0.0000) },
			{ Name = "GripWrap", MeshId = "rbxassetid://93459597852710", Size = Vector3.new(0.3720, 2.4200, 0.3720), Offset = Vector3.new(-0.0028, -1.3280, 0.0056) },
			{ Name = "Pommel", MeshId = "rbxassetid://135096127513216", Size = Vector3.new(0.5270, 6.8025, 0.4564), Offset = Vector3.new(-0.0028, 0.1813, 0.0056) },
			{ Name = "HeadCollar", MeshId = "rbxassetid://139537135583524", Size = Vector3.new(0.6727, 6.5180, 0.6189), Offset = Vector3.new(-0.0028, 0.0410, 0.0056) },
			{ Name = "Blade", MeshId = "rbxassetid://136478028796707", Size = Vector3.new(2.2503, 3.9000, 0.3000), Offset = Vector3.new(1.1024, 1.9720, 0.0056) },
			{ Name = "BladeEdge", MeshId = "rbxassetid://98624012016379", Size = Vector3.new(0.5155, 3.9170, 0.2000), Offset = Vector3.new(1.9898, 1.9719, 0.0056) },
			{ Name = "BackSpike", MeshId = "rbxassetid://94946493805202", Size = Vector3.new(2.7388, 4.1065, 0.4908), Offset = Vector3.new(-1.1722, 2.5468, 0.0364) },
			{ Name = "RuneInlay", MeshId = "rbxassetid://102402693978883", Size = Vector3.new(1.8990, 2.7525, 0.3782), Offset = Vector3.new(0.7576, 1.9871, 0.0056) },
		},
	},
	art_genesis_sunderer = {
		GripPos = Vector3.new(0.0000, 0.0080, 0.0000),
		OffhandGripPos = Vector3.new(0.0000, -1.6920, 0.0000),
		TipPos = Vector3.new(1.8900, 3.8080, 0.0000),
		BasePos = Vector3.new(1.8060, 0.5080, 0.0000),
		CorePos = Vector3.new(0.9450, 2.2080, 0.0000),
		Parts = {
			{ Name = "Handle", MeshId = "rbxassetid://77866838254217", Size = Vector3.new(0.3200, 6.4000, 0.3120), Offset = Vector3.new(0.0000, 0.0000, 0.0000) },
			{ Name = "GripWrap", MeshId = "rbxassetid://79194263813391", Size = Vector3.new(0.3840, 2.4200, 0.3744), Offset = Vector3.new(0.0000, -0.8420, 0.0000) },
			{ Name = "Pommel", MeshId = "rbxassetid://136050170245197", Size = Vector3.new(0.6560, 0.8600, 0.6560), Offset = Vector3.new(0.0000, -3.3700, 0.0000) },
			{ Name = "HeadCollar", MeshId = "rbxassetid://138809836593954", Size = Vector3.new(1.0500, 7.1273, 1.2400), Offset = Vector3.new(0.0000, 0.6936, 0.0000) },
			{ Name = "Blade", MeshId = "rbxassetid://123357242464604", Size = Vector3.new(2.1626, 3.3000, 0.3000), Offset = Vector3.new(1.0613, 2.1580, 0.0000) },
			{ Name = "BladeEdge", MeshId = "rbxassetid://125778625612557", Size = Vector3.new(4.3252, 3.3107, 2.6968), Offset = Vector3.new(0.0000, 2.1576, 0.0000) },
			{ Name = "BackSpike", MeshId = "rbxassetid://83490077431234", Size = Vector3.new(2.2926, 3.3000, 2.6568), Offset = Vector3.new(-0.9963, 2.1580, 0.0000) },
			{ Name = "RuneInlay", MeshId = "rbxassetid://139745271937039", Size = Vector3.new(2.8907, 2.8020, 0.9630), Offset = Vector3.new(0.0000, 2.5990, 0.0000) },
		},
	},
}

type AxePartStyle = {
	Material: Enum.Material?,
	Color: Color3?,
}

type AxeStyleData = {
	RarityTier: number,
	Parts: { [string]: AxePartStyle },
}

AXE_STYLES = {
	art_miner_pickaxe = {
		RarityTier = 1,
		Parts = {
			GripWrap = { Material = Enum.Material.Leather, Color = Color3.fromRGB(70, 48, 32) },
			BackSpike = { Material = Enum.Material.Metal, Color = Color3.fromRGB(130, 135, 145) },
			Blade = { Material = Enum.Material.Metal, Color = Color3.fromRGB(145, 150, 160) },
			BladeEdge = { Material = Enum.Material.Metal, Color = Color3.fromRGB(205, 210, 220) },
			Handle = { Material = Enum.Material.Wood, Color = Color3.fromRGB(115, 85, 55) },
			HeadCollar = { Material = Enum.Material.Metal, Color = Color3.fromRGB(110, 115, 125) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(95, 100, 108) },
		},
	},
	art_heavy_hewing_axe = {
		RarityTier = 1,
		Parts = {
			GripWrap = { Material = Enum.Material.Leather, Color = Color3.fromRGB(52, 38, 28) },
			BackSpike = { Material = Enum.Material.Metal, Color = Color3.fromRGB(95, 100, 110) },
			Blade = { Material = Enum.Material.Metal, Color = Color3.fromRGB(135, 140, 150) },
			BladeEdge = { Material = Enum.Material.Metal, Color = Color3.fromRGB(215, 220, 230) },
			Handle = { Material = Enum.Material.Wood, Color = Color3.fromRGB(90, 65, 42) },
			HeadCollar = { Material = Enum.Material.Metal, Color = Color3.fromRGB(100, 105, 115) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(80, 85, 92) },
		},
	},
	art_canyon_splitter = {
		RarityTier = 2,
		Parts = {
			GripWrap = { Material = Enum.Material.Leather, Color = Color3.fromRGB(60, 44, 34) },
			BackSpike = { Material = Enum.Material.Metal, Color = Color3.fromRGB(135, 140, 150) },
			Blade = { Material = Enum.Material.Metal, Color = Color3.fromRGB(120, 125, 135) },
			BladeEdge = { Material = Enum.Material.Metal, Color = Color3.fromRGB(195, 200, 215) },
			Handle = { Material = Enum.Material.Slate, Color = Color3.fromRGB(82, 80, 88) },
			HeadCollar = { Material = Enum.Material.Metal, Color = Color3.fromRGB(180, 135, 75) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(165, 120, 65) },
			RuneInlay = { Material = Enum.Material.Neon, Color = Color3.fromRGB(185, 105, 255) },
		},
	},
	art_quakestone_greataxe = {
		RarityTier = 2,
		Parts = {
			GripWrap = { Material = Enum.Material.Leather, Color = Color3.fromRGB(74, 52, 36) },
			BackSpike = { Material = Enum.Material.Metal, Color = Color3.fromRGB(125, 130, 140) },
			Blade = { Material = Enum.Material.Metal, Color = Color3.fromRGB(140, 145, 155) },
			BladeEdge = { Material = Enum.Material.Metal, Color = Color3.fromRGB(210, 215, 225) },
			Handle = { Material = Enum.Material.Metal, Color = Color3.fromRGB(190, 150, 65) },
			HeadCollar = { Material = Enum.Material.Metal, Color = Color3.fromRGB(115, 118, 125) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(170, 130, 50) },
			RuneInlay = { Material = Enum.Material.Neon, Color = Color3.fromRGB(245, 205, 90) },
		},
	},
	art_battleaxe_cleaver = {
		RarityTier = 3,
		Parts = {
			GripWrap = { Material = Enum.Material.Leather, Color = Color3.fromRGB(48, 36, 30) },
			BackSpike = { Material = Enum.Material.Metal, Color = Color3.fromRGB(120, 125, 138) },
			Blade = { Material = Enum.Material.Metal, Color = Color3.fromRGB(110, 115, 128) },
			BladeEdge = { Material = Enum.Material.Metal, Color = Color3.fromRGB(215, 222, 235) },
			Handle = { Material = Enum.Material.Metal, Color = Color3.fromRGB(65, 70, 78) },
			HeadCollar = { Material = Enum.Material.Metal, Color = Color3.fromRGB(175, 125, 45) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(195, 145, 60) },
			RuneInlay = { Material = Enum.Material.Neon, Color = Color3.fromRGB(60, 210, 255) },
		},
	},
	art_iron_juggernaut_cleaver = {
		RarityTier = 3,
		Parts = {
			GripWrap = { Material = Enum.Material.Leather, Color = Color3.fromRGB(40, 32, 28) },
			BackSpike = { Material = Enum.Material.Metal, Color = Color3.fromRGB(85, 88, 96) },
			Blade = { Material = Enum.Material.Metal, Color = Color3.fromRGB(125, 130, 140) },
			BladeEdge = { Material = Enum.Material.Metal, Color = Color3.fromRGB(200, 205, 218) },
			Handle = { Material = Enum.Material.Metal, Color = Color3.fromRGB(55, 58, 64) },
			HeadCollar = { Material = Enum.Material.Metal, Color = Color3.fromRGB(90, 94, 102) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(75, 78, 86) },
			RuneInlay = { Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 140, 30) },
		},
	},
	art_magma_behemoth = {
		RarityTier = 4,
		Parts = {
			GripWrap = { Material = Enum.Material.Leather, Color = Color3.fromRGB(58, 34, 30) },
			BackSpike = { Material = Enum.Material.Basalt, Color = Color3.fromRGB(35, 32, 40) },
			Blade = { Material = Enum.Material.Basalt, Color = Color3.fromRGB(48, 44, 52) },
			BladeEdge = { Material = Enum.Material.Metal, Color = Color3.fromRGB(90, 75, 85) },
			Handle = { Material = Enum.Material.Basalt, Color = Color3.fromRGB(40, 38, 44) },
			HeadCollar = { Material = Enum.Material.Metal, Color = Color3.fromRGB(70, 50, 50) },
			Pommel = { Material = Enum.Material.Slate, Color = Color3.fromRGB(30, 28, 35) },
			RuneInlay = { Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 70, 15) },
		},
	},
	art_obsidian_hell_splitter = {
		RarityTier = 4,
		Parts = {
			GripWrap = { Material = Enum.Material.Leather, Color = Color3.fromRGB(62, 36, 34) },
			BackSpike = { Material = Enum.Material.Metal, Color = Color3.fromRGB(35, 30, 38) },
			Blade = { Material = Enum.Material.Glass, Color = Color3.fromRGB(30, 28, 36) },
			BladeEdge = { Material = Enum.Material.Glass, Color = Color3.fromRGB(150, 40, 45) },
			Handle = { Material = Enum.Material.Metal, Color = Color3.fromRGB(45, 40, 48) },
			HeadCollar = { Material = Enum.Material.Metal, Color = Color3.fromRGB(80, 55, 55) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(60, 45, 50) },
			RuneInlay = { Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 180, 20) },
		},
	},
	art_titan_earthshaker = {
		RarityTier = 5,
		Parts = {
			GripWrap = { Material = Enum.Material.Leather, Color = Color3.fromRGB(120, 82, 46) },
			BackSpike = { Material = Enum.Material.Metal, Color = Color3.fromRGB(225, 175, 45) },
			Blade = { Material = Enum.Material.Metal, Color = Color3.fromRGB(210, 215, 225) },
			BladeEdge = { Material = Enum.Material.Metal, Color = Color3.fromRGB(255, 220, 80) },
			Handle = { Material = Enum.Material.Marble, Color = Color3.fromRGB(235, 235, 240) },
			HeadCollar = { Material = Enum.Material.Metal, Color = Color3.fromRGB(245, 195, 60) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(235, 185, 50) },
			RuneInlay = { Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 230, 110) },
		},
	},
	art_mountain_breaker = {
		RarityTier = 5,
		Parts = {
			GripWrap = { Material = Enum.Material.Leather, Color = Color3.fromRGB(96, 68, 40) },
			BackSpike = { Material = Enum.Material.Metal, Color = Color3.fromRGB(110, 105, 115) },
			Blade = { Material = Enum.Material.Slate, Color = Color3.fromRGB(70, 68, 75) },
			BladeEdge = { Material = Enum.Material.Metal, Color = Color3.fromRGB(240, 190, 70) },
			Handle = { Material = Enum.Material.Granite, Color = Color3.fromRGB(85, 80, 88) },
			HeadCollar = { Material = Enum.Material.Metal, Color = Color3.fromRGB(220, 165, 55) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(190, 140, 50) },
			RuneInlay = { Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 175, 40) },
		},
	},
	art_valkyrie_waraxe = {
		RarityTier = 6,
		Parts = {
			GripWrap = { Material = Enum.Material.Leather, Color = Color3.fromRGB(70, 110, 160) },
			BackSpike = { Material = Enum.Material.Metal, Color = Color3.fromRGB(235, 240, 252) },
			Blade = { Material = Enum.Material.Metal, Color = Color3.fromRGB(230, 235, 250) },
			BladeEdge = { Material = Enum.Material.Metal, Color = Color3.fromRGB(255, 225, 95) },
			Handle = { Material = Enum.Material.Metal, Color = Color3.fromRGB(225, 230, 245) },
			HeadCollar = { Material = Enum.Material.Metal, Color = Color3.fromRGB(250, 210, 80) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(245, 205, 70) },
			RuneInlay = { Material = Enum.Material.Neon, Color = Color3.fromRGB(0, 235, 255) },
		},
	},
	art_world_shaper = {
		RarityTier = 6,
		Parts = {
			GripWrap = { Material = Enum.Material.Leather, Color = Color3.fromRGB(84, 58, 40) },
			BackSpike = { Material = Enum.Material.Metal, Color = Color3.fromRGB(215, 160, 45) },
			Blade = { Material = Enum.Material.Metal, Color = Color3.fromRGB(175, 185, 200) },
			BladeEdge = { Material = Enum.Material.Metal, Color = Color3.fromRGB(245, 195, 75) },
			Handle = { Material = Enum.Material.Metal, Color = Color3.fromRGB(150, 160, 175) },
			HeadCollar = { Material = Enum.Material.Metal, Color = Color3.fromRGB(235, 180, 60) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(225, 170, 50) },
			RuneInlay = { Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 205, 30) },
		},
	},
	art_world_carver = {
		RarityTier = 7,
		Parts = {
			GripWrap = { Material = Enum.Material.Leather, Color = Color3.fromRGB(70, 50, 110) },
			BackSpike = { Material = Enum.Material.Slate, Color = Color3.fromRGB(30, 24, 38) },
			Blade = { Material = Enum.Material.Metal, Color = Color3.fromRGB(35, 28, 45) },
			BladeEdge = { Material = Enum.Material.Metal, Color = Color3.fromRGB(220, 225, 245) },
			Handle = { Material = Enum.Material.Slate, Color = Color3.fromRGB(25, 20, 32) },
			HeadCollar = { Material = Enum.Material.Metal, Color = Color3.fromRGB(205, 210, 228) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(195, 200, 218) },
			RuneInlay = { Material = Enum.Material.Neon, Color = Color3.fromRGB(195, 70, 255) },
		},
	},
	art_genesis_sunderer = {
		RarityTier = 7,
		Parts = {
			GripWrap = { Material = Enum.Material.Leather, Color = Color3.fromRGB(120, 60, 110) },
			BackSpike = { Material = Enum.Material.Metal, Color = Color3.fromRGB(55, 42, 72) },
			Blade = { Material = Enum.Material.Metal, Color = Color3.fromRGB(65, 50, 85) },
			BladeEdge = { Material = Enum.Material.Metal, Color = Color3.fromRGB(255, 225, 90) },
			Handle = { Material = Enum.Material.Metal, Color = Color3.fromRGB(45, 35, 60) },
			HeadCollar = { Material = Enum.Material.Metal, Color = Color3.fromRGB(255, 210, 75) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(250, 200, 65) },
			RuneInlay = { Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 100, 180) },
		},
	},
} :: { [string]: AxeStyleData }

local function makeMeshAxe(name: string): Model
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local weaponsFolder = assets and assets:FindFirstChild("Weapons")
	local existing = weaponsFolder and weaponsFolder:FindFirstChild(name)
	if existing and existing:IsA("Model") then
		return existing:Clone()
	end

	local data = AXE_MESH_DATA[name]
	assert(data, `No axe mesh data for {name}`)

	local model = Instance.new("Model")
	model.Name = name

	local style = AXE_STYLES and AXE_STYLES[name]
	local handlePart: MeshPart?

	for _, pInfo in ipairs(data.Parts) do
		local p = newUploadedMeshPart(pInfo.MeshId)
		p.Name = pInfo.Name
		p.Size = pInfo.Size
		p.CFrame = CFrame.new(pInfo.Offset)

		local pStyle = style and style.Parts and style.Parts[pInfo.Name]
		p.Material = (pStyle and pStyle.Material) or Enum.Material.Metal
		p.Color = (pStyle and pStyle.Color) or Color3.fromRGB(150, 150, 150)

		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.Anchored = false
		p.CastShadow = false
		p.Parent = model

		if pInfo.Name == "Handle" then
			handlePart = p
			model.PrimaryPart = p
		end
	end

	assert(handlePart, `Handle part missing for {name}`)

	-- Weld all child parts to the primary Handle
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") and child ~= handlePart then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handlePart
			weld.Part1 = child
			weld.Parent = handlePart
		end
	end

	-- Sockets: Grip, OffhandGrip, Tip, VfxTip, VfxBase, VfxCore. The haft runs along the Handle's
	-- +Y and the main edge faces +X, so both grips have UpVector +Y and LookVector +X.
	local gripRotation = CFrame.Angles(math.rad(EDGE_PLUS_X.X), math.rad(EDGE_PLUS_X.Y), math.rad(EDGE_PLUS_X.Z))
	local grip = Instance.new("Attachment")
	grip.Name = "Grip"
	grip.CFrame = CFrame.new(data.GripPos) * gripRotation
	grip.Parent = handlePart

	local offhandGrip = Instance.new("Attachment")
	offhandGrip.Name = "OffhandGrip"
	offhandGrip.CFrame = CFrame.new(data.OffhandGripPos) * gripRotation
	offhandGrip.Parent = handlePart

	local tip = Instance.new("Attachment")
	tip.Name = "Tip"
	tip.CFrame = CFrame.new(data.TipPos)
	tip.Parent = handlePart

	local vfxTip = Instance.new("Attachment")
	vfxTip.Name = "VfxTip"
	vfxTip.CFrame = CFrame.new(data.TipPos)
	vfxTip.Parent = handlePart

	local vfxBase = Instance.new("Attachment")
	vfxBase.Name = "VfxBase"
	vfxBase.CFrame = CFrame.new(data.BasePos)
	vfxBase.Parent = handlePart

	local vfxCore = Instance.new("Attachment")
	vfxCore.Name = "VfxCore"
	vfxCore.CFrame = CFrame.new(data.CorePos)
	vfxCore.Parent = handlePart

	-- Apply client-side weapon VFX (glints, lights, auras, trails)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local combatVfx = assets and assets:FindFirstChild("CombatVfx")
	local weaponVfxMod = combatVfx and combatVfx:FindFirstChild("WeaponVfx")
	if weaponVfxMod then
		local ok, WeaponVfx = pcall(require, weaponVfxMod)
		if ok and WeaponVfx and WeaponVfx.Apply then
			local rarity = style and style.RarityTier or 1
			WeaponVfx.Apply(model, "AXE", rarity, name)
		end
	end

	return model
end

function WeaponModelBuilder.BuildMinerPickaxeArtifact(): Model
	return makeMeshAxe("art_miner_pickaxe")
end

function WeaponModelBuilder.BuildHeavyHewingAxeArtifact(): Model
	return makeMeshAxe("art_heavy_hewing_axe")
end

function WeaponModelBuilder.BuildCanyonSplitterArtifact(): Model
	return makeMeshAxe("art_canyon_splitter")
end

function WeaponModelBuilder.BuildQuakestoneGreataxeArtifact(): Model
	return makeMeshAxe("art_quakestone_greataxe")
end

function WeaponModelBuilder.BuildBattleaxeCleaverArtifact(): Model
	return makeMeshAxe("art_battleaxe_cleaver")
end

function WeaponModelBuilder.BuildIronJuggernautCleaverArtifact(): Model
	return makeMeshAxe("art_iron_juggernaut_cleaver")
end

function WeaponModelBuilder.BuildMagmaBehemothArtifact(): Model
	return makeMeshAxe("art_magma_behemoth")
end

function WeaponModelBuilder.BuildObsidianHellSplitterArtifact(): Model
	return makeMeshAxe("art_obsidian_hell_splitter")
end

function WeaponModelBuilder.BuildTitanEarthshakerArtifact(): Model
	return makeMeshAxe("art_titan_earthshaker")
end

function WeaponModelBuilder.BuildMountainBreakerArtifact(): Model
	return makeMeshAxe("art_mountain_breaker")
end

function WeaponModelBuilder.BuildValkyrieWaraxeArtifact(): Model
	return makeMeshAxe("art_valkyrie_waraxe")
end

function WeaponModelBuilder.BuildWorldShaperArtifact(): Model
	return makeMeshAxe("art_world_shaper")
end

function WeaponModelBuilder.BuildWorldCarverArtifact(): Model
	return makeMeshAxe("art_world_carver")
end

function WeaponModelBuilder.BuildGenesisSundererArtifact(): Model
	return makeMeshAxe("art_genesis_sunderer")
end

-- MAGE STAVES (Batch 5) - 14 Modular 3D Anime Staves, Scepters & Spindles
export type StaffPartData = {
	Name: string,
	MeshId: string,
	Size: Vector3,
	Offset: Vector3,
	Mat: Enum.Material,
	Color: Color3,
}

export type StaffMeshData = {
	GripPos: Vector3,
	TipPos: Vector3,
	BasePos: Vector3,
	CorePos: Vector3,
	Parts: { StaffPartData },
}

local STAFF_MESH_DATA: { [string]: StaffMeshData } = {
	art_apprentice_cane = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 1.9000, 0.0000),
		BasePos = Vector3.new(0.0000, -1.5000, 0.0000),
		CorePos = Vector3.new(0.0000, 1.7500, 0.0000),
		Parts = {
			{ Name = "ArcaneCore", MeshId = "rbxassetid://75594269387003", Size = Vector3.new(0.3600, 0.3600, 0.3600), Offset = Vector3.new(0.0000, 1.7500, 0.0000), Mat = Enum.Material.Glass, Color = Color3.fromRGB(225, 230, 235) },
			{ Name = "Crown", MeshId = "rbxassetid://125313355802453", Size = Vector3.new(0.2835, 0.5247, 0.2800), Offset = Vector3.new(-0.0032, 1.5173, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(195, 125, 90) },
			{ Name = "Handle", MeshId = "rbxassetid://110710633020146", Size = Vector3.new(0.1485, 0.8000, 0.1500), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Wood, Color = Color3.fromRGB(195, 175, 140) },
			{ Name = "Pommel", MeshId = "rbxassetid://127542811256816", Size = Vector3.new(0.1584, 0.4250, 0.1600), Offset = Vector3.new(0.0000, -1.4625, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(180, 115, 80) },
			{ Name = "Shaft", MeshId = "rbxassetid://117267202012633", Size = Vector3.new(0.1386, 2.6000, 0.1400), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Wood, Color = Color3.fromRGB(195, 175, 140) },
			{ Name = "ShaftBands", MeshId = "rbxassetid://129430507986241", Size = Vector3.new(0.1800, 0.8640, 0.1782), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(180, 115, 80) },
		},
	},
	art_archmage_rod = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 2.7000, 0.0000),
		BasePos = Vector3.new(0.0000, -2.0000, 0.0000),
		CorePos = Vector3.new(0.0000, 2.3500, 0.0000),
		Parts = {
			{ Name = "ArcaneCore", MeshId = "rbxassetid://73035057637400", Size = Vector3.new(0.3800, 0.3800, 0.3800), Offset = Vector3.new(0.0000, 2.3500, 0.0000), Mat = Enum.Material.Neon, Color = Color3.fromRGB(160, 90, 255) },
			{ Name = "CaduceusWings", MeshId = "rbxassetid://105120652300312", Size = Vector3.new(0.9218, 0.5717, 0.0900), Offset = Vector3.new(0.0000, 2.3602, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(240, 200, 85) },
			{ Name = "Crown", MeshId = "rbxassetid://113124309966825", Size = Vector3.new(0.3600, 0.3500, 0.3600), Offset = Vector3.new(0.0000, 1.8500, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(235, 195, 80) },
			{ Name = "FocusProngs", MeshId = "rbxassetid://101040304600981", Size = Vector3.new(0.4661, 0.8049, 0.4368), Offset = Vector3.new(0.0000, 2.3144, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(215, 175, 60) },
			{ Name = "Handle", MeshId = "rbxassetid://107588427599063", Size = Vector3.new(0.1800, 0.9000, 0.1800), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Wood, Color = Color3.fromRGB(25, 25, 30) },
			{ Name = "Pommel", MeshId = "rbxassetid://104547152506622", Size = Vector3.new(0.3000, 0.4950, 0.3000), Offset = Vector3.new(0.0000, -1.8225, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(225, 185, 70) },
			{ Name = "Shaft", MeshId = "rbxassetid://111174941719215", Size = Vector3.new(0.1700, 3.3000, 0.1700), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Wood, Color = Color3.fromRGB(25, 25, 30) },
			{ Name = "ShaftBands", MeshId = "rbxassetid://105818649481766", Size = Vector3.new(0.2440, 2.3429, 0.2440), Offset = Vector3.new(0.0000, 0.6000, -0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(225, 185, 70) },
		},
	},
	art_chronomancers_spindle = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 2.6500, 0.0000),
		BasePos = Vector3.new(0.0000, -2.0000, 0.0000),
		CorePos = Vector3.new(0.0000, 2.3500, 0.0000),
		Parts = {
			{ Name = "ArcaneCore", MeshId = "rbxassetid://71690734843269", Size = Vector3.new(0.3200, 0.4800, 0.3200), Offset = Vector3.new(0.0000, 2.3500, 0.0000), Mat = Enum.Material.Neon, Color = Color3.fromRGB(250, 210, 90) },
			{ Name = "Crown", MeshId = "rbxassetid://77355294530423", Size = Vector3.new(0.4000, 0.3500, 0.4000), Offset = Vector3.new(0.0000, 1.8500, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(210, 170, 75) },
			{ Name = "FocusProngs", MeshId = "rbxassetid://126119887551655", Size = Vector3.new(0.4457, 0.4457, 0.6100), Offset = Vector3.new(0.0000, 2.3500, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(230, 185, 80) },
			{ Name = "Handle", MeshId = "rbxassetid://88208276463651", Size = Vector3.new(0.1800, 0.9000, 0.1800), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(190, 150, 65) },
			{ Name = "OrbitalRings", MeshId = "rbxassetid://124530086612399", Size = Vector3.new(0.7476, 0.4500, 0.7422), Offset = Vector3.new(0.0000, 2.3500, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(195, 155, 65) },
			{ Name = "Pommel", MeshId = "rbxassetid://115502749216905", Size = Vector3.new(0.3000, 0.4000, 0.3000), Offset = Vector3.new(0.0000, -1.7750, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(160, 120, 50) },
			{ Name = "Shaft", MeshId = "rbxassetid://104308157991665", Size = Vector3.new(0.1700, 3.3000, 0.1700), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(190, 150, 65) },
			{ Name = "ShaftBands", MeshId = "rbxassetid://132679879855233", Size = Vector3.new(0.2440, 2.3440, 0.2440), Offset = Vector3.new(0.0000, 0.6000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(190, 150, 65) },
		},
	},
	art_chronos_stave = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 2.8000, 0.0000),
		BasePos = Vector3.new(0.0000, -2.1500, 0.0000),
		CorePos = Vector3.new(0.0000, 2.4500, 0.0000),
		Parts = {
			{ Name = "ArcaneCore", MeshId = "rbxassetid://101064696461869", Size = Vector3.new(0.4400, 0.4400, 0.4400), Offset = Vector3.new(0.0000, 2.4500, 0.0000), Mat = Enum.Material.Neon, Color = Color3.fromRGB(80, 230, 255) },
			{ Name = "Crown", MeshId = "rbxassetid://131099756829563", Size = Vector3.new(0.4400, 0.4000, 0.4400), Offset = Vector3.new(0.0000, 2.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(200, 215, 230) },
			{ Name = "Handle", MeshId = "rbxassetid://115216547118104", Size = Vector3.new(0.1900, 0.9500, 0.1900), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(215, 225, 238) },
			{ Name = "OrbitalRings", MeshId = "rbxassetid://75645079066811", Size = Vector3.new(0.9600, 0.9280, 0.9493), Offset = Vector3.new(0.0000, 2.4500, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(240, 195, 80) },
			{ Name = "Pommel", MeshId = "rbxassetid://98307644125535", Size = Vector3.new(0.2559, 0.4679, 0.3440), Offset = Vector3.new(0.0000, -1.9440, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(180, 195, 215) },
			{ Name = "Shaft", MeshId = "rbxassetid://100842711001797", Size = Vector3.new(0.1800, 3.6000, 0.1800), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(215, 225, 238) },
			{ Name = "ShaftBands", MeshId = "rbxassetid://80007321371577", Size = Vector3.new(0.2660, 2.6000, 0.2660), Offset = Vector3.new(0.0000, 0.6250, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(235, 190, 75) },
		},
	},
	art_eye_of_singularity = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 2.9000, 0.0000),
		BasePos = Vector3.new(0.0000, -2.3000, 0.0000),
		CorePos = Vector3.new(0.0000, 2.6000, 0.0000),
		Parts = {
			{ Name = "ArcaneCore", MeshId = "rbxassetid://87131108470982", Size = Vector3.new(0.8642, 0.5000, 0.8887), Offset = Vector3.new(0.0000, 2.6000, 0.0000), Mat = Enum.Material.Neon, Color = Color3.fromRGB(195, 85, 255) },
			{ Name = "Crown", MeshId = "rbxassetid://89809975884823", Size = Vector3.new(0.5000, 0.4500, 0.5000), Offset = Vector3.new(0.0000, 2.1000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(65, 32, 95) },
			{ Name = "FloatingShards", MeshId = "rbxassetid://107092125986460", Size = Vector3.new(1.2254, 0.7565, 1.2279), Offset = Vector3.new(0.0000, 2.6014, 0.0000), Mat = Enum.Material.Glass, Color = Color3.fromRGB(225, 140, 255) },
			{ Name = "FocusProngs", MeshId = "rbxassetid://84098327727934", Size = Vector3.new(0.8415, 0.9437, 0.7395), Offset = Vector3.new(0.0000, 2.6000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(90, 45, 135) },
			{ Name = "Handle", MeshId = "rbxassetid://103181149788400", Size = Vector3.new(0.2000, 1.0000, 0.2000), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Glass, Color = Color3.fromRGB(15, 12, 22) },
			{ Name = "Pommel", MeshId = "rbxassetid://105669166263285", Size = Vector3.new(0.2600, 0.7250, 0.2600), Offset = Vector3.new(0.0000, -2.1625, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(48, 25, 75) },
			{ Name = "Shaft", MeshId = "rbxassetid://75393092124747", Size = Vector3.new(0.1900, 3.7500, 0.1900), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Glass, Color = Color3.fromRGB(15, 12, 22) },
			{ Name = "ShaftBands", MeshId = "rbxassetid://72058804288441", Size = Vector3.new(0.2860, 2.9054, 0.2860), Offset = Vector3.new(0.0000, 0.7250, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(75, 40, 110) },
		},
	},
	art_frostweaver_scepter = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 2.4000, 0.0000),
		BasePos = Vector3.new(0.0000, -1.8000, 0.0000),
		CorePos = Vector3.new(0.0000, 2.1500, 0.0000),
		Parts = {
			{ Name = "ArcaneCore", MeshId = "rbxassetid://121023718862452", Size = Vector3.new(0.5305, 0.2400, 0.5389), Offset = Vector3.new(0.0000, 2.1500, 0.0000), Mat = Enum.Material.Neon, Color = Color3.fromRGB(130, 220, 255) },
			{ Name = "Crown", MeshId = "rbxassetid://119568997697910", Size = Vector3.new(0.3683, 0.5965, 0.3853), Offset = Vector3.new(-0.0294, 1.7733, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(200, 210, 225) },
			{ Name = "Handle", MeshId = "rbxassetid://85891739453945", Size = Vector3.new(0.1700, 0.9000, 0.1700), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Wood, Color = Color3.fromRGB(215, 220, 225) },
			{ Name = "OrbitalRings", MeshId = "rbxassetid://115209279565436", Size = Vector3.new(0.8400, 0.0400, 0.8400), Offset = Vector3.new(0.0000, 2.1500, 0.0000), Mat = Enum.Material.Glass, Color = Color3.fromRGB(180, 235, 255) },
			{ Name = "Pommel", MeshId = "rbxassetid://115165221322985", Size = Vector3.new(0.2600, 0.4350, 0.2600), Offset = Vector3.new(0.0000, -1.6925, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(190, 200, 215) },
			{ Name = "Shaft", MeshId = "rbxassetid://94593230355800", Size = Vector3.new(0.1600, 3.0600, 0.1600), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Wood, Color = Color3.fromRGB(215, 220, 225) },
			{ Name = "ShaftBands", MeshId = "rbxassetid://73476339612412", Size = Vector3.new(0.2260, 2.0851, 0.2260), Offset = Vector3.new(0.0000, 0.5250, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(190, 200, 215) },
		},
	},
	art_glacial_monolith = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 2.4000, 0.0000),
		BasePos = Vector3.new(0.0000, -1.9500, 0.0000),
		CorePos = Vector3.new(0.0000, 2.1500, 0.0000),
		Parts = {
			{ Name = "ArcaneCore", MeshId = "rbxassetid://116141917102328", Size = Vector3.new(0.3989, 0.4000, 0.4000), Offset = Vector3.new(0.0000, 2.1500, 0.0000), Mat = Enum.Material.Neon, Color = Color3.fromRGB(60, 225, 255) },
			{ Name = "Crown", MeshId = "rbxassetid://86060257379879", Size = Vector3.new(0.2835, 0.6823, 0.3490), Offset = Vector3.new(0.0001, 1.9161, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(180, 205, 230) },
			{ Name = "FloatingShards", MeshId = "rbxassetid://86792468462979", Size = Vector3.new(1.0165, 0.5180, 0.9021), Offset = Vector3.new(0.0000, 2.1508, 0.0000), Mat = Enum.Material.Glass, Color = Color3.fromRGB(190, 240, 255) },
			{ Name = "Handle", MeshId = "rbxassetid://78434635409130", Size = Vector3.new(0.1795, 0.9000, 0.1800), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Glass, Color = Color3.fromRGB(70, 160, 215) },
			{ Name = "Pommel", MeshId = "rbxassetid://77334523433098", Size = Vector3.new(0.2194, 0.6500, 0.2200), Offset = Vector3.new(0.0000, -1.8500, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(170, 195, 220) },
			{ Name = "Shaft", MeshId = "rbxassetid://116447884325823", Size = Vector3.new(0.1695, 3.1500, 0.1700), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Glass, Color = Color3.fromRGB(70, 160, 215) },
			{ Name = "ShaftBands", MeshId = "rbxassetid://104824244866298", Size = Vector3.new(0.2400, 2.2100, 0.2393), Offset = Vector3.new(0.0000, 0.5649, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(170, 195, 220) },
		},
	},
	art_infernal_pillar = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 2.7000, 0.0000),
		BasePos = Vector3.new(0.0000, -2.0500, 0.0000),
		CorePos = Vector3.new(0.0000, 2.3500, 0.0000),
		Parts = {
			{ Name = "ArcaneCore", MeshId = "rbxassetid://117862777979265", Size = Vector3.new(0.4391, 0.4400, 0.4400), Offset = Vector3.new(0.0000, 2.3500, 0.0000), Mat = Enum.Material.Neon, Color = Color3.fromRGB(255, 60, 20) },
			{ Name = "Crown", MeshId = "rbxassetid://107864296147271", Size = Vector3.new(0.4391, 0.3800, 0.4400), Offset = Vector3.new(0.0000, 1.9000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(50, 40, 45) },
			{ Name = "FocusProngs", MeshId = "rbxassetid://136468241674461", Size = Vector3.new(0.5895, 0.5987, 0.5771), Offset = Vector3.new(-0.0293, 2.2935, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(180, 50, 25) },
			{ Name = "Handle", MeshId = "rbxassetid://70992733344132", Size = Vector3.new(0.1896, 0.9500, 0.1900), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(28, 26, 30) },
			{ Name = "OrbitalRings", MeshId = "rbxassetid://133836208107331", Size = Vector3.new(0.7405, 0.3898, 0.7098), Offset = Vector3.new(0.0000, 2.3500, 0.0000), Mat = Enum.Material.Neon, Color = Color3.fromRGB(255, 140, 30) },
			{ Name = "Pommel", MeshId = "rbxassetid://97011549577768", Size = Vector3.new(0.2395, 0.6350, 0.2400), Offset = Vector3.new(0.0000, -1.9575, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(45, 38, 42) },
			{ Name = "Shaft", MeshId = "rbxassetid://117620485596053", Size = Vector3.new(0.1796, 3.4500, 0.1800), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(28, 26, 30) },
			{ Name = "ShaftBands", MeshId = "rbxassetid://115248856737213", Size = Vector3.new(0.2580, 2.4473, 0.2575), Offset = Vector3.new(0.0000, 0.6000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(180, 50, 25) },
		},
	},
	art_omega_archon_caduceus = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 3.0000, 0.0000),
		BasePos = Vector3.new(0.0000, -2.3500, 0.0000),
		CorePos = Vector3.new(0.0000, 2.6500, 0.0000),
		Parts = {
			{ Name = "ArcaneCore", MeshId = "rbxassetid://124633983012337", Size = Vector3.new(0.5000, 0.5000, 0.5000), Offset = Vector3.new(0.0000, 2.6500, 0.0000), Mat = Enum.Material.Neon, Color = Color3.fromRGB(255, 245, 200) },
			{ Name = "Crown", MeshId = "rbxassetid://80798890341841", Size = Vector3.new(0.5200, 0.4500, 0.5200), Offset = Vector3.new(0.0000, 2.1000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(255, 215, 90) },
			{ Name = "FocusProngs", MeshId = "rbxassetid://107673575815355", Size = Vector3.new(1.5655, 0.9901, 0.1000), Offset = Vector3.new(0.0000, 2.5234, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(250, 205, 80) },
			{ Name = "Handle", MeshId = "rbxassetid://103181149788400", Size = Vector3.new(0.2000, 1.0000, 0.2000), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(245, 240, 230) },
			{ Name = "OrbitalRings", MeshId = "rbxassetid://114668873044934", Size = Vector3.new(1.0514, 0.4408, 0.7227), Offset = Vector3.new(0.0000, 2.6500, 0.0000), Mat = Enum.Material.Neon, Color = Color3.fromRGB(175, 130, 255) },
			{ Name = "Pommel", MeshId = "rbxassetid://112586924003879", Size = Vector3.new(0.3800, 0.5000, 0.3800), Offset = Vector3.new(0.0000, -2.0500, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(255, 210, 85) },
			{ Name = "Shaft", MeshId = "rbxassetid://75393092124747", Size = Vector3.new(0.1900, 3.7500, 0.1900), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(245, 240, 230) },
			{ Name = "ShaftBands", MeshId = "rbxassetid://71460876799025", Size = Vector3.new(0.2860, 2.9060, 0.2860), Offset = Vector3.new(0.0000, 0.7250, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(255, 210, 85) },
		},
	},
	art_pyromancers_torch_rod = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 2.3000, 0.0000),
		BasePos = Vector3.new(0.0000, -1.8000, 0.0000),
		CorePos = Vector3.new(0.0000, 1.9500, 0.0000),
		Parts = {
			{ Name = "ArcaneCore", MeshId = "rbxassetid://90609655843176", Size = Vector3.new(0.3186, 0.3200, 0.3200), Offset = Vector3.new(0.0000, 1.9500, 0.0000), Mat = Enum.Material.Neon, Color = Color3.fromRGB(255, 95, 20) },
			{ Name = "Crown", MeshId = "rbxassetid://86505835860389", Size = Vector3.new(0.3983, 0.3000, 0.4000), Offset = Vector3.new(0.0000, 1.6000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(50, 52, 58) },
			{ Name = "FocusProngs", MeshId = "rbxassetid://111311324740364", Size = Vector3.new(0.5064, 0.5665, 0.4466), Offset = Vector3.new(0.0000, 1.9583, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(60, 62, 70) },
			{ Name = "Handle", MeshId = "rbxassetid://94116964109412", Size = Vector3.new(0.1693, 0.9000, 0.1700), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(40, 42, 48) },
			{ Name = "Pommel", MeshId = "rbxassetid://71371851079709", Size = Vector3.new(0.1991, 0.5500, 0.2000), Offset = Vector3.new(0.0000, -1.7000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(55, 58, 65) },
			{ Name = "Shaft", MeshId = "rbxassetid://123895618170373", Size = Vector3.new(0.1593, 2.9500, 0.1600), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(40, 42, 48) },
			{ Name = "ShaftBands", MeshId = "rbxassetid://78741677961967", Size = Vector3.new(0.2260, 1.9151, 0.2250), Offset = Vector3.new(0.0000, 0.4600, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(190, 140, 50) },
		},
	},
	art_ruby_staff = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 2.3000, 0.0000),
		BasePos = Vector3.new(0.0000, -1.7000, 0.0000),
		CorePos = Vector3.new(0.0000, 2.0500, 0.0000),
		Parts = {
			{ Name = "ArcaneCore", MeshId = "rbxassetid://79317759674677", Size = Vector3.new(0.4000, 0.4000, 0.4000), Offset = Vector3.new(0.0000, 2.0500, 0.0000), Mat = Enum.Material.Neon, Color = Color3.fromRGB(240, 30, 80) },
			{ Name = "Crown", MeshId = "rbxassetid://80722231690598", Size = Vector3.new(0.3600, 0.5050, 0.3600), Offset = Vector3.new(0.0000, 1.6226, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(165, 115, 70) },
			{ Name = "FocusProngs", MeshId = "rbxassetid://87850337613471", Size = Vector3.new(0.3541, 0.5010, 0.3070), Offset = Vector3.new(-0.0441, 1.9467, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(175, 120, 75) },
			{ Name = "Handle", MeshId = "rbxassetid://72754428785273", Size = Vector3.new(0.1700, 0.8500, 0.1700), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Wood, Color = Color3.fromRGB(85, 55, 35) },
			{ Name = "Pommel", MeshId = "rbxassetid://92909408308738", Size = Vector3.new(0.2600, 0.4350, 0.2600), Offset = Vector3.new(0.0000, -1.5925, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(150, 105, 60) },
			{ Name = "Shaft", MeshId = "rbxassetid://76223130521129", Size = Vector3.new(0.1600, 2.8400, 0.1600), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Wood, Color = Color3.fromRGB(85, 55, 35) },
			{ Name = "ShaftBands", MeshId = "rbxassetid://94140276730837", Size = Vector3.new(0.2120, 1.8312, 0.2120), Offset = Vector3.new(0.0000, 0.4500, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(150, 105, 60) },
		},
	},
	art_scholars_spire = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 2.2000, 0.0000),
		BasePos = Vector3.new(0.0000, -1.6000, 0.0000),
		CorePos = Vector3.new(0.0000, 1.9500, 0.0000),
		Parts = {
			{ Name = "ArcaneCore", MeshId = "rbxassetid://126221139389673", Size = Vector3.new(0.3200, 0.5250, 0.3200), Offset = Vector3.new(0.0000, 1.9675, 0.0000), Mat = Enum.Material.Neon, Color = Color3.fromRGB(245, 160, 40) },
			{ Name = "Crown", MeshId = "rbxassetid://104821740261482", Size = Vector3.new(0.3167, 0.4250, 0.3200), Offset = Vector3.new(0.0000, 1.5375, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(220, 180, 85) },
			{ Name = "Handle", MeshId = "rbxassetid://128894348282340", Size = Vector3.new(0.1584, 0.8500, 0.1600), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Wood, Color = Color3.fromRGB(120, 70, 45) },
			{ Name = "Pommel", MeshId = "rbxassetid://117910379280759", Size = Vector3.new(0.2178, 0.3800, 0.2200), Offset = Vector3.new(0.0000, -1.5400, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(210, 170, 75) },
			{ Name = "Shaft", MeshId = "rbxassetid://72197993371952", Size = Vector3.new(0.1485, 2.7500, 0.1500), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Wood, Color = Color3.fromRGB(120, 70, 45) },
			{ Name = "ShaftBands", MeshId = "rbxassetid://107632089654087", Size = Vector3.new(0.2000, 1.7300, 0.1980), Offset = Vector3.new(0.0000, 0.4000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(210, 170, 75) },
		},
	},
	art_solaris_sunburst = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 2.8000, 0.0000),
		BasePos = Vector3.new(0.0000, -2.1500, 0.0000),
		CorePos = Vector3.new(0.0000, 2.4500, 0.0000),
		Parts = {
			{ Name = "ArcaneCore", MeshId = "rbxassetid://113396609524774", Size = Vector3.new(0.4800, 0.4800, 0.4800), Offset = Vector3.new(0.0000, 2.4500, 0.0000), Mat = Enum.Material.Neon, Color = Color3.fromRGB(255, 235, 175) },
			{ Name = "Crown", MeshId = "rbxassetid://114544498744736", Size = Vector3.new(0.4800, 0.4000, 0.4800), Offset = Vector3.new(0.0000, 2.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(240, 185, 55) },
			{ Name = "Handle", MeshId = "rbxassetid://115216547118104", Size = Vector3.new(0.1900, 0.9500, 0.1900), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(245, 195, 65) },
			{ Name = "OrbitalRings", MeshId = "rbxassetid://132589338472028", Size = Vector3.new(1.1067, 1.0062, 1.0295), Offset = Vector3.new(0.0000, 2.4500, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(255, 205, 80) },
			{ Name = "Pommel", MeshId = "rbxassetid://74918919692492", Size = Vector3.new(0.4018, 0.4800, 0.4018), Offset = Vector3.new(0.0000, -1.9500, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(255, 215, 95) },
			{ Name = "Shaft", MeshId = "rbxassetid://100842711001797", Size = Vector3.new(0.1800, 3.6000, 0.1800), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(245, 195, 65) },
			{ Name = "ShaftBands", MeshId = "rbxassetid://80007321371577", Size = Vector3.new(0.2660, 2.6000, 0.2660), Offset = Vector3.new(0.0000, 0.6250, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(255, 215, 95) },
		},
	},
	art_void_channeler = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 2.7000, 0.0000),
		BasePos = Vector3.new(0.0000, -2.0500, 0.0000),
		CorePos = Vector3.new(0.0000, 2.3500, 0.0000),
		Parts = {
			{ Name = "ArcaneCore", MeshId = "rbxassetid://127168285935259", Size = Vector3.new(0.4400, 0.4400, 0.4400), Offset = Vector3.new(0.0000, 2.3500, 0.0000), Mat = Enum.Material.Neon, Color = Color3.fromRGB(170, 50, 250) },
			{ Name = "Crown", MeshId = "rbxassetid://105220951861446", Size = Vector3.new(0.4400, 0.3800, 0.4400), Offset = Vector3.new(0.0000, 1.9000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(60, 32, 85) },
			{ Name = "FocusProngs", MeshId = "rbxassetid://140393742595376", Size = Vector3.new(0.4505, 0.6471, 0.6066), Offset = Vector3.new(-0.0006, 2.3414, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(80, 40, 115) },
			{ Name = "Handle", MeshId = "rbxassetid://75304298934818", Size = Vector3.new(0.1900, 0.9500, 0.1900), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Slate, Color = Color3.fromRGB(22, 18, 28) },
			{ Name = "OrbitalRings", MeshId = "rbxassetid://94607134565170", Size = Vector3.new(0.8648, 0.4661, 0.8886), Offset = Vector3.new(0.0000, 2.3500, 0.0000), Mat = Enum.Material.Neon, Color = Color3.fromRGB(215, 110, 255) },
			{ Name = "Pommel", MeshId = "rbxassetid://105978967739468", Size = Vector3.new(0.2800, 0.5000, 0.2800), Offset = Vector3.new(0.0000, -1.8900, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(55, 30, 75) },
			{ Name = "Shaft", MeshId = "rbxassetid://72626563061645", Size = Vector3.new(0.1800, 3.4500, 0.1800), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Slate, Color = Color3.fromRGB(22, 18, 28) },
			{ Name = "ShaftBands", MeshId = "rbxassetid://114910144631413", Size = Vector3.new(0.2580, 2.4473, 0.2580), Offset = Vector3.new(0.0000, 0.6000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(75, 40, 100) },
		},
	},
}

type StaffPartStyle = {
	Material: Enum.Material?,
	Color: Color3?,
}

type StaffStyleData = {
	RarityTier: number,
	Parts: { [string]: StaffPartStyle },
}

STAFF_STYLES = {
	art_apprentice_cane = {
		RarityTier = 1,
		Parts = {
			ArcaneCore = { Material = Enum.Material.Glass, Color = Color3.fromRGB(225, 230, 235) },
			Crown = { Material = Enum.Material.Metal, Color = Color3.fromRGB(195, 125, 90) },
			Handle = { Material = Enum.Material.Wood, Color = Color3.fromRGB(195, 175, 140) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(180, 115, 80) },
			Shaft = { Material = Enum.Material.Wood, Color = Color3.fromRGB(195, 175, 140) },
			ShaftBands = { Material = Enum.Material.Metal, Color = Color3.fromRGB(180, 115, 80) },
		},
	},
	art_archmage_rod = {
		RarityTier = 4,
		Parts = {
			ArcaneCore = { Material = Enum.Material.Neon, Color = Color3.fromRGB(160, 90, 255) },
			CaduceusWings = { Material = Enum.Material.Metal, Color = Color3.fromRGB(240, 200, 85) },
			Crown = { Material = Enum.Material.Metal, Color = Color3.fromRGB(235, 195, 80) },
			FocusProngs = { Material = Enum.Material.Metal, Color = Color3.fromRGB(215, 175, 60) },
			Handle = { Material = Enum.Material.Wood, Color = Color3.fromRGB(25, 25, 30) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(225, 185, 70) },
			Shaft = { Material = Enum.Material.Wood, Color = Color3.fromRGB(25, 25, 30) },
			ShaftBands = { Material = Enum.Material.Metal, Color = Color3.fromRGB(225, 185, 70) },
		},
	},
	art_chronomancers_spindle = {
		RarityTier = 4,
		Parts = {
			ArcaneCore = { Material = Enum.Material.Neon, Color = Color3.fromRGB(250, 210, 90) },
			Crown = { Material = Enum.Material.Metal, Color = Color3.fromRGB(210, 170, 75) },
			FocusProngs = { Material = Enum.Material.Metal, Color = Color3.fromRGB(230, 185, 80) },
			Handle = { Material = Enum.Material.Metal, Color = Color3.fromRGB(190, 150, 65) },
			OrbitalRings = { Material = Enum.Material.Metal, Color = Color3.fromRGB(195, 155, 65) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(160, 120, 50) },
			Shaft = { Material = Enum.Material.Metal, Color = Color3.fromRGB(190, 150, 65) },
			ShaftBands = { Material = Enum.Material.Metal, Color = Color3.fromRGB(190, 150, 65) },
		},
	},
	art_chronos_stave = {
		RarityTier = 6,
		Parts = {
			ArcaneCore = { Material = Enum.Material.Neon, Color = Color3.fromRGB(80, 230, 255) },
			Crown = { Material = Enum.Material.Metal, Color = Color3.fromRGB(200, 215, 230) },
			Handle = { Material = Enum.Material.Metal, Color = Color3.fromRGB(215, 225, 238) },
			OrbitalRings = { Material = Enum.Material.Metal, Color = Color3.fromRGB(240, 195, 80) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(180, 195, 215) },
			Shaft = { Material = Enum.Material.Metal, Color = Color3.fromRGB(215, 225, 238) },
			ShaftBands = { Material = Enum.Material.Metal, Color = Color3.fromRGB(235, 190, 75) },
		},
	},
	art_eye_of_singularity = {
		RarityTier = 7,
		Parts = {
			ArcaneCore = { Material = Enum.Material.Neon, Color = Color3.fromRGB(195, 85, 255) },
			Crown = { Material = Enum.Material.Metal, Color = Color3.fromRGB(65, 32, 95) },
			FloatingShards = { Material = Enum.Material.Glass, Color = Color3.fromRGB(225, 140, 255) },
			FocusProngs = { Material = Enum.Material.Metal, Color = Color3.fromRGB(90, 45, 135) },
			Handle = { Material = Enum.Material.Glass, Color = Color3.fromRGB(15, 12, 22) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(48, 25, 75) },
			Shaft = { Material = Enum.Material.Glass, Color = Color3.fromRGB(15, 12, 22) },
			ShaftBands = { Material = Enum.Material.Metal, Color = Color3.fromRGB(75, 40, 110) },
		},
	},
	art_frostweaver_scepter = {
		RarityTier = 3,
		Parts = {
			ArcaneCore = { Material = Enum.Material.Neon, Color = Color3.fromRGB(130, 220, 255) },
			Crown = { Material = Enum.Material.Metal, Color = Color3.fromRGB(200, 210, 225) },
			Handle = { Material = Enum.Material.Wood, Color = Color3.fromRGB(215, 220, 225) },
			OrbitalRings = { Material = Enum.Material.Glass, Color = Color3.fromRGB(180, 235, 255) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(190, 200, 215) },
			Shaft = { Material = Enum.Material.Wood, Color = Color3.fromRGB(215, 220, 225) },
			ShaftBands = { Material = Enum.Material.Metal, Color = Color3.fromRGB(190, 200, 215) },
		},
	},
	art_glacial_monolith = {
		RarityTier = 3,
		Parts = {
			ArcaneCore = { Material = Enum.Material.Neon, Color = Color3.fromRGB(60, 225, 255) },
			Crown = { Material = Enum.Material.Metal, Color = Color3.fromRGB(180, 205, 230) },
			FloatingShards = { Material = Enum.Material.Glass, Color = Color3.fromRGB(190, 240, 255) },
			Handle = { Material = Enum.Material.Glass, Color = Color3.fromRGB(70, 160, 215) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(170, 195, 220) },
			Shaft = { Material = Enum.Material.Glass, Color = Color3.fromRGB(70, 160, 215) },
			ShaftBands = { Material = Enum.Material.Metal, Color = Color3.fromRGB(170, 195, 220) },
		},
	},
	art_infernal_pillar = {
		RarityTier = 5,
		Parts = {
			ArcaneCore = { Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 60, 20) },
			Crown = { Material = Enum.Material.Metal, Color = Color3.fromRGB(50, 40, 45) },
			FocusProngs = { Material = Enum.Material.Metal, Color = Color3.fromRGB(180, 50, 25) },
			Handle = { Material = Enum.Material.Metal, Color = Color3.fromRGB(28, 26, 30) },
			OrbitalRings = { Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 140, 30) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(45, 38, 42) },
			Shaft = { Material = Enum.Material.Metal, Color = Color3.fromRGB(28, 26, 30) },
			ShaftBands = { Material = Enum.Material.Metal, Color = Color3.fromRGB(180, 50, 25) },
		},
	},
	art_omega_archon_caduceus = {
		RarityTier = 7,
		Parts = {
			ArcaneCore = { Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 245, 200) },
			Crown = { Material = Enum.Material.Metal, Color = Color3.fromRGB(255, 215, 90) },
			FocusProngs = { Material = Enum.Material.Metal, Color = Color3.fromRGB(250, 205, 80) },
			Handle = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(245, 240, 230) },
			OrbitalRings = { Material = Enum.Material.Neon, Color = Color3.fromRGB(175, 130, 255) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(255, 210, 85) },
			Shaft = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(245, 240, 230) },
			ShaftBands = { Material = Enum.Material.Metal, Color = Color3.fromRGB(255, 210, 85) },
		},
	},
	art_pyromancers_torch_rod = {
		RarityTier = 2,
		Parts = {
			ArcaneCore = { Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 95, 20) },
			Crown = { Material = Enum.Material.Metal, Color = Color3.fromRGB(50, 52, 58) },
			FocusProngs = { Material = Enum.Material.Metal, Color = Color3.fromRGB(60, 62, 70) },
			Handle = { Material = Enum.Material.Metal, Color = Color3.fromRGB(40, 42, 48) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(55, 58, 65) },
			Shaft = { Material = Enum.Material.Metal, Color = Color3.fromRGB(40, 42, 48) },
			ShaftBands = { Material = Enum.Material.Metal, Color = Color3.fromRGB(190, 140, 50) },
		},
	},
	art_ruby_staff = {
		RarityTier = 2,
		Parts = {
			ArcaneCore = { Material = Enum.Material.Neon, Color = Color3.fromRGB(240, 30, 80) },
			Crown = { Material = Enum.Material.Metal, Color = Color3.fromRGB(165, 115, 70) },
			FocusProngs = { Material = Enum.Material.Metal, Color = Color3.fromRGB(175, 120, 75) },
			Handle = { Material = Enum.Material.Wood, Color = Color3.fromRGB(85, 55, 35) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(150, 105, 60) },
			Shaft = { Material = Enum.Material.Wood, Color = Color3.fromRGB(85, 55, 35) },
			ShaftBands = { Material = Enum.Material.Metal, Color = Color3.fromRGB(150, 105, 60) },
		},
	},
	art_scholars_spire = {
		RarityTier = 1,
		Parts = {
			ArcaneCore = { Material = Enum.Material.Neon, Color = Color3.fromRGB(245, 160, 40) },
			Crown = { Material = Enum.Material.Metal, Color = Color3.fromRGB(220, 180, 85) },
			Handle = { Material = Enum.Material.Wood, Color = Color3.fromRGB(120, 70, 45) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(210, 170, 75) },
			Shaft = { Material = Enum.Material.Wood, Color = Color3.fromRGB(120, 70, 45) },
			ShaftBands = { Material = Enum.Material.Metal, Color = Color3.fromRGB(210, 170, 75) },
		},
	},
	art_solaris_sunburst = {
		RarityTier = 6,
		Parts = {
			ArcaneCore = { Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 235, 175) },
			Crown = { Material = Enum.Material.Metal, Color = Color3.fromRGB(240, 185, 55) },
			Handle = { Material = Enum.Material.Metal, Color = Color3.fromRGB(245, 195, 65) },
			OrbitalRings = { Material = Enum.Material.Metal, Color = Color3.fromRGB(255, 205, 80) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(255, 215, 95) },
			Shaft = { Material = Enum.Material.Metal, Color = Color3.fromRGB(245, 195, 65) },
			ShaftBands = { Material = Enum.Material.Metal, Color = Color3.fromRGB(255, 215, 95) },
		},
	},
	art_void_channeler = {
		RarityTier = 5,
		Parts = {
			ArcaneCore = { Material = Enum.Material.Neon, Color = Color3.fromRGB(170, 50, 250) },
			Crown = { Material = Enum.Material.Metal, Color = Color3.fromRGB(60, 32, 85) },
			FocusProngs = { Material = Enum.Material.Metal, Color = Color3.fromRGB(80, 40, 115) },
			Handle = { Material = Enum.Material.Slate, Color = Color3.fromRGB(22, 18, 28) },
			OrbitalRings = { Material = Enum.Material.Neon, Color = Color3.fromRGB(215, 110, 255) },
			Pommel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(55, 30, 75) },
			Shaft = { Material = Enum.Material.Slate, Color = Color3.fromRGB(22, 18, 28) },
			ShaftBands = { Material = Enum.Material.Metal, Color = Color3.fromRGB(75, 40, 100) },
		},
	},
} :: { [string]: StaffStyleData }

local function makeMeshStaff(name: string): Model
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local weaponsFolder = assets and assets:FindFirstChild("Weapons")
	local existing = weaponsFolder and weaponsFolder:FindFirstChild(name)
	if existing and existing:IsA("Model") then
		return existing:Clone()
	end

	local data = STAFF_MESH_DATA[name]
	assert(data, `No staff mesh data for {name}`)

	local model = Instance.new("Model")
	model.Name = name

	local style = STAFF_STYLES and STAFF_STYLES[name]
	local handlePart: MeshPart?

	for _, pInfo in ipairs(data.Parts) do
		local p = newUploadedMeshPart(pInfo.MeshId)
		p.Name = pInfo.Name
		p.Size = pInfo.Size
		p.CFrame = CFrame.new(pInfo.Offset)

		local pStyle = style and style.Parts and style.Parts[pInfo.Name]
		p.Material = (pStyle and pStyle.Material) or pInfo.Mat or Enum.Material.Wood
		p.Color = (pStyle and pStyle.Color) or pInfo.Color or Color3.fromRGB(150, 150, 150)

		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.Anchored = false
		p.CastShadow = false
		p.Parent = model

		if pInfo.Name == "Handle" then
			handlePart = p
			model.PrimaryPart = p
		end
	end

	assert(handlePart, `Handle part missing for {name}`)

	-- Weld all child parts to the primary Handle
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") and child ~= handlePart then
			local weld = Instance.new("WeldConstraint")
			weld.Name = "Weld_" .. child.Name
			weld.Part0 = handlePart
			weld.Part1 = child
			weld.Parent = handlePart
		end
	end

	-- Sockets: Grip, Tip, VfxTip, VfxBase, VfxCore. Staff meshes run along +Y (head up), so the
	-- grip is unrotated: UpVector = shaft toward the head, LookVector = head face (-Z), matching
	-- the procedural weapon_staff the STAFF clips were authored against.
	local grip = Instance.new("Attachment")
	grip.Name = "Grip"
	grip.CFrame = CFrame.new(data.GripPos)
	grip.Parent = handlePart

	local tip = Instance.new("Attachment")
	tip.Name = "Tip"
	tip.CFrame = CFrame.new(data.TipPos)
	tip.Parent = handlePart

	local vfxTip = Instance.new("Attachment")
	vfxTip.Name = "VfxTip"
	vfxTip.CFrame = CFrame.new(data.TipPos)
	vfxTip.Parent = handlePart

	local vfxBase = Instance.new("Attachment")
	vfxBase.Name = "VfxBase"
	vfxBase.CFrame = CFrame.new(data.BasePos)
	vfxBase.Parent = handlePart

	local vfxCore = Instance.new("Attachment")
	vfxCore.Name = "VfxCore"
	vfxCore.CFrame = CFrame.new(data.CorePos)
	vfxCore.Parent = handlePart

	-- Apply client-side weapon VFX (glints, lights, auras, trails)
	local combatVfx = assets and assets:FindFirstChild("CombatVfx")
	local weaponVfxMod = combatVfx and combatVfx:FindFirstChild("WeaponVfx")
	if weaponVfxMod then
		local ok, WeaponVfx = pcall(require, weaponVfxMod)
		if ok and WeaponVfx and WeaponVfx.Apply then
			local rarity = style and style.RarityTier or 1
			WeaponVfx.Apply(model, "STAFF", rarity, name)
		end
	end

	return model
end

function WeaponModelBuilder.BuildApprenticeCaneArtifact(): Model
	return makeMeshStaff("art_apprentice_cane")
end

function WeaponModelBuilder.BuildArchmageRodArtifact(): Model
	return makeMeshStaff("art_archmage_rod")
end

function WeaponModelBuilder.BuildChronomancersSpindleArtifact(): Model
	return makeMeshStaff("art_chronomancers_spindle")
end

function WeaponModelBuilder.BuildChronosStaveArtifact(): Model
	return makeMeshStaff("art_chronos_stave")
end

function WeaponModelBuilder.BuildEyeOfSingularityArtifact(): Model
	return makeMeshStaff("art_eye_of_singularity")
end

function WeaponModelBuilder.BuildFrostweaverScepterArtifact(): Model
	return makeMeshStaff("art_frostweaver_scepter")
end

function WeaponModelBuilder.BuildGlacialMonolithArtifact(): Model
	return makeMeshStaff("art_glacial_monolith")
end

function WeaponModelBuilder.BuildInfernalPillarArtifact(): Model
	return makeMeshStaff("art_infernal_pillar")
end

function WeaponModelBuilder.BuildOmegaArchonCaduceusArtifact(): Model
	return makeMeshStaff("art_omega_archon_caduceus")
end

function WeaponModelBuilder.BuildPyromancersTorchRodArtifact(): Model
	return makeMeshStaff("art_pyromancers_torch_rod")
end

function WeaponModelBuilder.BuildRubyStaffArtifact(): Model
	return makeMeshStaff("art_ruby_staff")
end

function WeaponModelBuilder.BuildScholarsSpireArtifact(): Model
	return makeMeshStaff("art_scholars_spire")
end

function WeaponModelBuilder.BuildSolarisSunburstArtifact(): Model
	return makeMeshStaff("art_solaris_sunburst")
end

function WeaponModelBuilder.BuildVoidChannelerArtifact(): Model
	return makeMeshStaff("art_void_channeler")
end

export type TomePartData = {
	Name: string,
	MeshId: string,
	Size: Vector3,
	Offset: Vector3,
	Mat: Enum.Material,
	Color: Color3,
}

export type TomeMeshData = {
	GripPos: Vector3,
	TipPos: Vector3,
	BasePos: Vector3,
	CorePos: Vector3,
	Parts: { TomePartData },
}

local TOME_MESH_DATA: { [string]: TomeMeshData } = {
art_novice_tome = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 0.6500, 0.0000),
		BasePos = Vector3.new(0.0000, 0.3500, 0.0000),
		CorePos = Vector3.new(0.0000, 0.5500, 0.0000),
		Parts = {
			{ Name = "Bookmark", MeshId = "rbxassetid://70434820513447", Size = Vector3.new(0.1399, 0.5820, 0.8000), Offset = Vector3.new(-0.0047, 0.2890, 0.4000), Mat = Enum.Material.Fabric, Color = Color3.fromRGB(165, 35, 35) },
			{ Name = "CornerBrackets", MeshId = "rbxassetid://76498378989143", Size = Vector3.new(1.1966, 0.0965, 1.1000), Offset = Vector3.new(0.0000, 0.5500, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(175, 125, 75) },
			{ Name = "Cover", MeshId = "rbxassetid://83009149870534", Size = Vector3.new(1.1901, 0.2249, 1.1000), Offset = Vector3.new(0.0000, 0.4758, 0.0000), Mat = Enum.Material.Leather, Color = Color3.fromRGB(115, 65, 45) },
			{ Name = "Handle", MeshId = "rbxassetid://84070404356820", Size = Vector3.new(0.1200, 0.1200, 0.1200), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Plastic, Color = Color3.fromRGB(163, 162, 165) },
			{ Name = "Pages", MeshId = "rbxassetid://100403073886843", Size = Vector3.new(1.1400, 0.3052, 1.0400), Offset = Vector3.new(0.0000, 0.5526, 0.0000), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(242, 235, 215) },
			{ Name = "Spine", MeshId = "rbxassetid://129398393562292", Size = Vector3.new(0.1800, 0.0900, 1.0500), Offset = Vector3.new(0.0000, 0.3350, 0.0000), Mat = Enum.Material.Leather, Color = Color3.fromRGB(85, 45, 30) },
		},
	},
	art_acolytes_litany = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 0.6500, 0.0000),
		BasePos = Vector3.new(0.0000, 0.3500, 0.0000),
		CorePos = Vector3.new(0.0000, 0.5500, 0.0000),
		Parts = {
			{ Name = "Bookmark", MeshId = "rbxassetid://113679044760475", Size = Vector3.new(0.1417, 0.5840, 0.8000), Offset = Vector3.new(-0.0031, 0.2880, 0.4000), Mat = Enum.Material.Fabric, Color = Color3.fromRGB(45, 95, 165) },
			{ Name = "CornerBrackets", MeshId = "rbxassetid://107532235906954", Size = Vector3.new(1.2361, 0.1042, 1.1200), Offset = Vector3.new(0.0000, 0.5546, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(195, 145, 85) },
			{ Name = "Cover", MeshId = "rbxassetid://131006700819476", Size = Vector3.new(1.2291, 0.2339, 1.1200), Offset = Vector3.new(0.0000, 0.4789, 0.0000), Mat = Enum.Material.Leather, Color = Color3.fromRGB(55, 75, 95) },
			{ Name = "Handle", MeshId = "rbxassetid://84070404356820", Size = Vector3.new(0.1200, 0.1200, 0.1200), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Plastic, Color = Color3.fromRGB(163, 162, 165) },
			{ Name = "Pages", MeshId = "rbxassetid://73148971893273", Size = Vector3.new(1.1800, 0.3217, 1.0600), Offset = Vector3.new(0.0000, 0.5609, 0.0000), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(245, 238, 220) },
			{ Name = "Spine", MeshId = "rbxassetid://130901321299982", Size = Vector3.new(0.1900, 0.0950, 1.0800), Offset = Vector3.new(0.0000, 0.3325, 0.0000), Mat = Enum.Material.Leather, Color = Color3.fromRGB(40, 55, 75) },
			{ Name = "SpineClasps", MeshId = "rbxassetid://100360622211975", Size = Vector3.new(0.2360, 0.1180, 0.4200), Offset = Vector3.new(0.0000, 0.3210, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(195, 145, 85) },
		},
	},
	art_cleric_scripture = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 0.6500, 0.0000),
		BasePos = Vector3.new(0.0000, 0.3500, 0.0000),
		CorePos = Vector3.new(0.0000, 0.5500, 0.0000),
		Parts = {
			{ Name = "Bookmark", MeshId = "rbxassetid://114826877345466", Size = Vector3.new(0.1503, 0.5850, 0.8000), Offset = Vector3.new(-0.0049, 0.2875, 0.4000), Mat = Enum.Material.Fabric, Color = Color3.fromRGB(195, 155, 45) },
			{ Name = "CornerBrackets", MeshId = "rbxassetid://137069433320337", Size = Vector3.new(1.2752, 0.1103, 1.1600), Offset = Vector3.new(0.0000, 0.5592, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(210, 175, 95) },
			{ Name = "Cover", MeshId = "rbxassetid://91519269250482", Size = Vector3.new(1.2678, 0.2420, 1.1600), Offset = Vector3.new(0.0000, 0.4820, 0.0000), Mat = Enum.Material.Leather, Color = Color3.fromRGB(135, 45, 45) },
			{ Name = "FiligreeTrim", MeshId = "rbxassetid://120333985823925", Size = Vector3.new(1.2721, 0.2553, 1.1600), Offset = Vector3.new(0.0000, 0.4820, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(225, 185, 105) },
			{ Name = "Handle", MeshId = "rbxassetid://84070404356820", Size = Vector3.new(0.1200, 0.1200, 0.1200), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Plastic, Color = Color3.fromRGB(163, 162, 165) },
			{ Name = "Pages", MeshId = "rbxassetid://122129191132157", Size = Vector3.new(1.2200, 0.3382, 1.1000), Offset = Vector3.new(0.0000, 0.5691, 0.0000), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(245, 240, 225) },
			{ Name = "Spine", MeshId = "rbxassetid://97936797175706", Size = Vector3.new(0.2000, 0.1000, 1.1200), Offset = Vector3.new(0.0000, 0.3300, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(180, 185, 195) },
			{ Name = "SpineClasps", MeshId = "rbxassetid://75228823810554", Size = Vector3.new(0.2460, 0.1230, 0.6250), Offset = Vector3.new(0.0000, 0.3185, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(210, 175, 95) },
		},
	},
	art_mendicants_psalter = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 0.6500, 0.0000),
		BasePos = Vector3.new(0.0000, 0.3500, 0.0000),
		CorePos = Vector3.new(0.0000, 0.5500, 0.0000),
		Parts = {
			{ Name = "Bookmark", MeshId = "rbxassetid://71385529613534", Size = Vector3.new(0.1536, 0.5850, 0.8000), Offset = Vector3.new(-0.0041, 0.2875, 0.4000), Mat = Enum.Material.Fabric, Color = Color3.fromRGB(50, 150, 95) },
			{ Name = "CornerBrackets", MeshId = "rbxassetid://132843153551217", Size = Vector3.new(1.3142, 0.1164, 1.1800), Offset = Vector3.new(0.0000, 0.5638, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(220, 185, 110) },
			{ Name = "Cover", MeshId = "rbxassetid://72144177174455", Size = Vector3.new(1.3064, 0.2501, 1.1800), Offset = Vector3.new(0.0000, 0.4851, 0.0000), Mat = Enum.Material.Leather, Color = Color3.fromRGB(45, 85, 65) },
			{ Name = "FiligreeTrim", MeshId = "rbxassetid://113339563040234", Size = Vector3.new(1.3112, 0.2649, 1.1800), Offset = Vector3.new(0.0000, 0.4851, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(230, 195, 120) },
			{ Name = "Handle", MeshId = "rbxassetid://84070404356820", Size = Vector3.new(0.1200, 0.1200, 0.1200), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Plastic, Color = Color3.fromRGB(163, 162, 165) },
			{ Name = "Pages", MeshId = "rbxassetid://95988683187791", Size = Vector3.new(1.2600, 0.3547, 1.1200), Offset = Vector3.new(0.0000, 0.5774, 0.0000), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(245, 240, 225) },
			{ Name = "Spine", MeshId = "rbxassetid://125779446386391", Size = Vector3.new(0.2100, 0.1050, 1.1500), Offset = Vector3.new(0.0000, 0.3275, 0.0000), Mat = Enum.Material.Leather, Color = Color3.fromRGB(30, 60, 45) },
			{ Name = "SpineClasps", MeshId = "rbxassetid://115718283358568", Size = Vector3.new(0.2560, 0.1280, 0.7550), Offset = Vector3.new(0.0000, 0.3160, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(220, 185, 110) },
		},
	},
	art_hermetic_grimoire = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 0.6500, 0.0000),
		BasePos = Vector3.new(0.0000, 0.3500, 0.0000),
		CorePos = Vector3.new(0.0000, 0.5500, 0.0000),
		Parts = {
			{ Name = "Bookmark", MeshId = "rbxassetid://71385529613534", Size = Vector3.new(0.1536, 0.5850, 0.8000), Offset = Vector3.new(-0.0041, 0.2875, 0.4000), Mat = Enum.Material.Fabric, Color = Color3.fromRGB(150, 75, 225) },
			{ Name = "CornerBrackets", MeshId = "rbxassetid://126990767785596", Size = Vector3.new(1.3142, 0.1164, 1.2000), Offset = Vector3.new(0.0000, 0.5639, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(215, 220, 235) },
			{ Name = "Cover", MeshId = "rbxassetid://123286733584154", Size = Vector3.new(1.3064, 0.2501, 1.2000), Offset = Vector3.new(0.0000, 0.4851, 0.0000), Mat = Enum.Material.Slate, Color = Color3.fromRGB(38, 30, 52) },
			{ Name = "FiligreeTrim", MeshId = "rbxassetid://136605537045315", Size = Vector3.new(1.3112, 0.2649, 1.2000), Offset = Vector3.new(0.0000, 0.4851, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(225, 230, 245) },
			{ Name = "Handle", MeshId = "rbxassetid://84070404356820", Size = Vector3.new(0.1200, 0.1200, 0.1200), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Plastic, Color = Color3.fromRGB(163, 162, 165) },
			{ Name = "Pages", MeshId = "rbxassetid://85442372248780", Size = Vector3.new(1.2600, 0.3547, 1.1400), Offset = Vector3.new(0.0000, 0.5774, 0.0000), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(240, 235, 225) },
			{ Name = "RunicGlyph", MeshId = "rbxassetid://72522635118448", Size = Vector3.new(0.4400, 0.0200, 0.4400), Offset = Vector3.new(0.0000, 0.6600, 0.0000), Mat = Enum.Material.Neon, Color = Color3.fromRGB(140, 100, 255) },
			{ Name = "Spine", MeshId = "rbxassetid://134505530502706", Size = Vector3.new(0.2100, 0.1050, 1.1600), Offset = Vector3.new(0.0000, 0.3275, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(185, 190, 205) },
			{ Name = "SpineClasps", MeshId = "rbxassetid://132083828419660", Size = Vector3.new(0.2560, 0.1280, 0.7660), Offset = Vector3.new(0.0000, 0.3160, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(215, 220, 235) },
		},
	},
	art_restorative_codex = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 0.6500, 0.0000),
		BasePos = Vector3.new(0.0000, 0.3500, 0.0000),
		CorePos = Vector3.new(0.0000, 0.5500, 0.0000),
		Parts = {
			{ Name = "Bookmark", MeshId = "rbxassetid://121857356491320", Size = Vector3.new(0.1600, 0.5860, 0.8000), Offset = Vector3.new(-0.0047, 0.2870, 0.4000), Mat = Enum.Material.Fabric, Color = Color3.fromRGB(60, 200, 130) },
			{ Name = "CornerBrackets", MeshId = "rbxassetid://95107926555683", Size = Vector3.new(1.3532, 0.1226, 1.2200), Offset = Vector3.new(0.0000, 0.5685, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(225, 195, 110) },
			{ Name = "Cover", MeshId = "rbxassetid://109958374659820", Size = Vector3.new(1.3451, 0.2582, 1.2200), Offset = Vector3.new(0.0000, 0.4882, 0.0000), Mat = Enum.Material.Leather, Color = Color3.fromRGB(30, 65, 55) },
			{ Name = "FiligreeTrim", MeshId = "rbxassetid://130316082086085", Size = Vector3.new(1.3504, 0.2745, 1.2200), Offset = Vector3.new(0.0000, 0.4882, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(235, 205, 125) },
			{ Name = "Handle", MeshId = "rbxassetid://84070404356820", Size = Vector3.new(0.1200, 0.1200, 0.1200), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Plastic, Color = Color3.fromRGB(163, 162, 165) },
			{ Name = "Pages", MeshId = "rbxassetid://92955019694497", Size = Vector3.new(1.3000, 0.3712, 1.1600), Offset = Vector3.new(0.0000, 0.5856, 0.0000), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(245, 242, 230) },
			{ Name = "RestorationSeal", MeshId = "rbxassetid://88592307972424", Size = Vector3.new(0.5000, 0.0220, 0.5000), Offset = Vector3.new(0.0000, 0.6800, 0.0000), Mat = Enum.Material.Neon, Color = Color3.fromRGB(80, 255, 160) },
			{ Name = "Spine", MeshId = "rbxassetid://94016010268972", Size = Vector3.new(0.2200, 0.1100, 1.1800), Offset = Vector3.new(0.0000, 0.3250, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(205, 175, 95) },
			{ Name = "SpineClasps", MeshId = "rbxassetid://92950697657214", Size = Vector3.new(0.2660, 0.1330, 0.7780), Offset = Vector3.new(0.0000, 0.3135, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(225, 195, 110) },
		},
	},
	art_valeria_sanctuary = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 0.6500, 0.0000),
		BasePos = Vector3.new(0.0000, 0.3500, 0.0000),
		CorePos = Vector3.new(0.0000, 0.5500, 0.0000),
		Parts = {
			{ Name = "Bookmark", MeshId = "rbxassetid://121857356491320", Size = Vector3.new(0.1600, 0.5860, 0.8000), Offset = Vector3.new(-0.0047, 0.2870, 0.4000), Mat = Enum.Material.Fabric, Color = Color3.fromRGB(235, 185, 65) },
			{ Name = "CornerBrackets", MeshId = "rbxassetid://85361847004775", Size = Vector3.new(1.3918, 0.1241, 1.2400), Offset = Vector3.new(0.0000, 0.5747, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(245, 205, 95) },
			{ Name = "Cover", MeshId = "rbxassetid://90674464028086", Size = Vector3.new(1.3834, 0.2653, 1.2400), Offset = Vector3.new(0.0000, 0.4913, 0.0000), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(248, 246, 242) },
			{ Name = "FiligreeTrim", MeshId = "rbxassetid://75629923293174", Size = Vector3.new(1.3890, 0.2824, 1.2400), Offset = Vector3.new(0.0000, 0.4913, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(255, 215, 110) },
			{ Name = "Handle", MeshId = "rbxassetid://84070404356820", Size = Vector3.new(0.1200, 0.1200, 0.1200), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Plastic, Color = Color3.fromRGB(163, 162, 165) },
			{ Name = "Pages", MeshId = "rbxassetid://121100559883288", Size = Vector3.new(1.3400, 0.3777, 1.1800), Offset = Vector3.new(0.0000, 0.5889, 0.0000), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(255, 250, 240) },
			{ Name = "SanctuaryHalo", MeshId = "rbxassetid://128524984333190", Size = Vector3.new(0.5600, 0.0220, 0.5600), Offset = Vector3.new(0.0000, 0.7000, 0.0000), Mat = Enum.Material.Neon, Color = Color3.fromRGB(90, 255, 160) },
			{ Name = "SeraphWings", MeshId = "rbxassetid://135630210539140", Size = Vector3.new(3.2191, 1.1653, 1.0388), Offset = Vector3.new(0.0000, 1.0101, 0.3119), Mat = Enum.Material.Metal, Color = Color3.fromRGB(250, 210, 100) },
			{ Name = "Spine", MeshId = "rbxassetid://96935436788270", Size = Vector3.new(0.2200, 0.1100, 1.2000), Offset = Vector3.new(0.0000, 0.3250, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(235, 195, 85) },
			{ Name = "SpineClasps", MeshId = "rbxassetid://131369980874718", Size = Vector3.new(0.2660, 0.1330, 0.7950), Offset = Vector3.new(0.0000, 0.3135, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(245, 205, 95) },
		},
	},
	art_seraphs_testament = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 0.6500, 0.0000),
		BasePos = Vector3.new(0.0000, 0.3500, 0.0000),
		CorePos = Vector3.new(0.0000, 0.5500, 0.0000),
		Parts = {
			{ Name = "Bookmark", MeshId = "rbxassetid://118361856042498", Size = Vector3.new(0.1649, 0.5860, 0.8000), Offset = Vector3.new(-0.0047, 0.2870, 0.4000), Mat = Enum.Material.Fabric, Color = Color3.fromRGB(240, 190, 70) },
			{ Name = "CornerBrackets", MeshId = "rbxassetid://131552819260211", Size = Vector3.new(1.4303, 0.1287, 1.2600), Offset = Vector3.new(0.0000, 0.5793, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(245, 210, 105) },
			{ Name = "Cover", MeshId = "rbxassetid://120585099317218", Size = Vector3.new(1.4218, 0.2724, 1.2600), Offset = Vector3.new(0.0000, 0.4943, 0.0000), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(230, 235, 245) },
			{ Name = "FiligreeTrim", MeshId = "rbxassetid://126044313521164", Size = Vector3.new(1.4276, 0.2903, 1.2600), Offset = Vector3.new(0.0000, 0.4943, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(255, 220, 115) },
			{ Name = "Handle", MeshId = "rbxassetid://84070404356820", Size = Vector3.new(0.1200, 0.1200, 0.1200), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Plastic, Color = Color3.fromRGB(163, 162, 165) },
			{ Name = "Pages", MeshId = "rbxassetid://127948239243587", Size = Vector3.new(1.3800, 0.3942, 1.2000), Offset = Vector3.new(0.0000, 0.5971, 0.0000), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(255, 252, 245) },
			{ Name = "SanctuaryHalo", MeshId = "rbxassetid://115648178985400", Size = Vector3.new(0.6000, 0.0240, 0.6000), Offset = Vector3.new(0.0000, 0.7200, 0.0000), Mat = Enum.Material.Neon, Color = Color3.fromRGB(255, 235, 120) },
			{ Name = "SeraphWings", MeshId = "rbxassetid://114380859981557", Size = Vector3.new(3.5950, 1.3185, 1.1712), Offset = Vector3.new(0.0000, 1.0968, 0.3781), Mat = Enum.Material.Metal, Color = Color3.fromRGB(255, 215, 110) },
			{ Name = "Spine", MeshId = "rbxassetid://85448768420489", Size = Vector3.new(0.2300, 0.1150, 1.2200), Offset = Vector3.new(0.0000, 0.3225, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(240, 205, 95) },
			{ Name = "SpineClasps", MeshId = "rbxassetid://75836294542369", Size = Vector3.new(0.2760, 0.1380, 0.8070), Offset = Vector3.new(0.0000, 0.3110, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(245, 210, 105) },
		},
	},
	art_necronomicon_pages = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 0.6500, 0.0000),
		BasePos = Vector3.new(0.0000, 0.3500, 0.0000),
		CorePos = Vector3.new(0.0000, 0.5500, 0.0000),
		Parts = {
			{ Name = "Bookmark", MeshId = "rbxassetid://118361856042498", Size = Vector3.new(0.1649, 0.5860, 0.8000), Offset = Vector3.new(-0.0047, 0.2870, 0.4000), Mat = Enum.Material.Fabric, Color = Color3.fromRGB(110, 30, 160) },
			{ Name = "CornerBrackets", MeshId = "rbxassetid://71456563301244", Size = Vector3.new(1.4503, 0.1348, 1.2800), Offset = Vector3.new(0.0000, 0.5809, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(75, 55, 95) },
			{ Name = "Cover", MeshId = "rbxassetid://88786755935426", Size = Vector3.new(1.4414, 0.2774, 1.2800), Offset = Vector3.new(0.0000, 0.4958, 0.0000), Mat = Enum.Material.Slate, Color = Color3.fromRGB(22, 18, 28) },
			{ Name = "EyeCore", MeshId = "rbxassetid://74048539739148", Size = Vector3.new(0.6386, 0.3800, 0.6355), Offset = Vector3.new(0.0000, 0.7500, 0.0000), Mat = Enum.Material.Neon, Color = Color3.fromRGB(180, 50, 255) },
			{ Name = "FiligreeTrim", MeshId = "rbxassetid://128438840799932", Size = Vector3.new(1.4477, 0.2968, 1.2800), Offset = Vector3.new(0.0000, 0.4958, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(85, 60, 105) },
			{ Name = "FloatingPages", MeshId = "rbxassetid://111109041164339", Size = Vector3.new(1.9217, 0.6153, 1.0104), Offset = Vector3.new(0.0000, 0.7937, -0.0172), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(225, 210, 195) },
			{ Name = "Handle", MeshId = "rbxassetid://84070404356820", Size = Vector3.new(0.1200, 0.1200, 0.1200), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Plastic, Color = Color3.fromRGB(163, 162, 165) },
			{ Name = "Pages", MeshId = "rbxassetid://82659118792565", Size = Vector3.new(1.4000, 0.3974, 1.2200), Offset = Vector3.new(0.0000, 0.5987, 0.0000), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(215, 205, 190) },
			{ Name = "Spine", MeshId = "rbxassetid://86399621851408", Size = Vector3.new(0.2300, 0.1150, 1.2400), Offset = Vector3.new(0.0000, 0.3225, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(60, 45, 75) },
			{ Name = "SpineClasps", MeshId = "rbxassetid://72148173474081", Size = Vector3.new(0.2760, 0.1380, 0.9017), Offset = Vector3.new(0.0000, 0.3110, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(75, 55, 95) },
		},
	},
	art_lifebinders_chronicle = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 0.6500, 0.0000),
		BasePos = Vector3.new(0.0000, 0.3500, 0.0000),
		CorePos = Vector3.new(0.0000, 0.5500, 0.0000),
		Parts = {
			{ Name = "Bookmark", MeshId = "rbxassetid://80762239333486", Size = Vector3.new(0.1697, 0.5860, 0.8000), Offset = Vector3.new(-0.0046, 0.2870, 0.4000), Mat = Enum.Material.Fabric, Color = Color3.fromRGB(50, 180, 90) },
			{ Name = "CornerBrackets", MeshId = "rbxassetid://114750590269506", Size = Vector3.new(1.4703, 0.1410, 1.3000), Offset = Vector3.new(0.0000, 0.5824, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(115, 175, 95) },
			{ Name = "Cover", MeshId = "rbxassetid://71986493530691", Size = Vector3.new(1.4611, 0.2824, 1.3000), Offset = Vector3.new(0.0000, 0.4974, 0.0000), Mat = Enum.Material.Wood, Color = Color3.fromRGB(48, 36, 26) },
			{ Name = "FiligreeTrim", MeshId = "rbxassetid://100906111322806", Size = Vector3.new(1.4679, 0.3033, 1.3000), Offset = Vector3.new(0.0000, 0.4974, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(125, 195, 105) },
			{ Name = "FloatingPages", MeshId = "rbxassetid://130596792555257", Size = Vector3.new(2.3524, 0.8840, 1.4076), Offset = Vector3.new(0.0000, 0.9401, 0.1658), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(245, 240, 225) },
			{ Name = "Handle", MeshId = "rbxassetid://84070404356820", Size = Vector3.new(0.1200, 0.1200, 0.1200), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Plastic, Color = Color3.fromRGB(163, 162, 165) },
			{ Name = "LifeCore", MeshId = "rbxassetid://113381293266049", Size = Vector3.new(0.7106, 0.4200, 0.7075), Offset = Vector3.new(0.0000, 0.7800, 0.0000), Mat = Enum.Material.Neon, Color = Color3.fromRGB(60, 255, 130) },
			{ Name = "Pages", MeshId = "rbxassetid://81602094197052", Size = Vector3.new(1.4200, 0.4107, 1.2400), Offset = Vector3.new(0.0000, 0.6053, 0.0000), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(245, 240, 225) },
			{ Name = "Spine", MeshId = "rbxassetid://116288409572909", Size = Vector3.new(0.2400, 0.1200, 1.2600), Offset = Vector3.new(0.0000, 0.3200, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(85, 135, 80) },
			{ Name = "SpineClasps", MeshId = "rbxassetid://75910468612378", Size = Vector3.new(0.2860, 0.1430, 0.9200), Offset = Vector3.new(0.0000, 0.3085, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(115, 175, 95) },
		},
	},
	art_seraphic_psalms = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 0.6500, 0.0000),
		BasePos = Vector3.new(0.0000, 0.3500, 0.0000),
		CorePos = Vector3.new(0.0000, 0.5500, 0.0000),
		Parts = {
			{ Name = "Bookmark", MeshId = "rbxassetid://127644695462590", Size = Vector3.new(0.1702, 0.5860, 0.8000), Offset = Vector3.new(-0.0048, 0.2870, 0.4000), Mat = Enum.Material.Fabric, Color = Color3.fromRGB(255, 200, 70) },
			{ Name = "CornerBrackets", MeshId = "rbxassetid://80562861479502", Size = Vector3.new(1.5094, 0.1471, 1.3200), Offset = Vector3.new(0.0000, 0.5870, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(255, 215, 95) },
			{ Name = "Cover", MeshId = "rbxassetid://123267179213886", Size = Vector3.new(1.4997, 0.2905, 1.3200), Offset = Vector3.new(0.0000, 0.5005, 0.0000), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(255, 252, 245) },
			{ Name = "FiligreeTrim", MeshId = "rbxassetid://90309867017701", Size = Vector3.new(1.5070, 0.3129, 1.3200), Offset = Vector3.new(0.0000, 0.5005, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(255, 225, 115) },
			{ Name = "FloatingPages", MeshId = "rbxassetid://70373241649912", Size = Vector3.new(1.9447, 0.6438, 1.0536), Offset = Vector3.new(0.0000, 0.8367, -0.0166), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(255, 252, 245) },
			{ Name = "Handle", MeshId = "rbxassetid://84070404356820", Size = Vector3.new(0.1200, 0.1200, 0.1200), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Plastic, Color = Color3.fromRGB(163, 162, 165) },
			{ Name = "OrbitalRings", MeshId = "rbxassetid://136054410739306", Size = Vector3.new(2.2442, 0.7802, 1.8653), Offset = Vector3.new(0.0000, 0.6600, 0.0000), Mat = Enum.Material.Neon, Color = Color3.fromRGB(255, 235, 130) },
			{ Name = "Pages", MeshId = "rbxassetid://79644130933813", Size = Vector3.new(1.4600, 0.4272, 1.2600), Offset = Vector3.new(0.0000, 0.6136, 0.0000), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(255, 255, 250) },
			{ Name = "SeraphWings", MeshId = "rbxassetid://85609698372381", Size = Vector3.new(3.9708, 1.4717, 1.3036), Offset = Vector3.new(0.0000, 1.1833, 0.4443), Mat = Enum.Material.Metal, Color = Color3.fromRGB(255, 220, 110) },
			{ Name = "Spine", MeshId = "rbxassetid://76804668800054", Size = Vector3.new(0.2400, 0.1200, 1.2800), Offset = Vector3.new(0.0000, 0.3200, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(255, 215, 95) },
			{ Name = "SpineClasps", MeshId = "rbxassetid://135644866195702", Size = Vector3.new(0.2860, 0.1430, 0.9333), Offset = Vector3.new(0.0000, 0.3085, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(255, 215, 95) },
		},
	},
	art_divine_providence = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 0.6500, 0.0000),
		BasePos = Vector3.new(0.0000, 0.3500, 0.0000),
		CorePos = Vector3.new(0.0000, 0.5500, 0.0000),
		Parts = {
			{ Name = "Bookmark", MeshId = "rbxassetid://105356489567088", Size = Vector3.new(0.1752, 0.5860, 0.8000), Offset = Vector3.new(-0.0048, 0.2870, 0.4000), Mat = Enum.Material.Fabric, Color = Color3.fromRGB(90, 190, 255) },
			{ Name = "CornerBrackets", MeshId = "rbxassetid://91284503876603", Size = Vector3.new(1.5484, 0.1532, 1.3400), Offset = Vector3.new(0.0000, 0.5917, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(250, 215, 105) },
			{ Name = "Cover", MeshId = "rbxassetid://125966296382542", Size = Vector3.new(1.5384, 0.2986, 1.3400), Offset = Vector3.new(0.0000, 0.5036, 0.0000), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(245, 248, 255) },
			{ Name = "FiligreeTrim", MeshId = "rbxassetid://70665577798241", Size = Vector3.new(1.5462, 0.3225, 1.3400), Offset = Vector3.new(0.0000, 0.5036, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(255, 225, 120) },
			{ Name = "FloatingPages", MeshId = "rbxassetid://86850595817390", Size = Vector3.new(2.3638, 0.9072, 1.4401), Offset = Vector3.new(0.0000, 0.9837, 0.1665), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(255, 255, 255) },
			{ Name = "Handle", MeshId = "rbxassetid://84070404356820", Size = Vector3.new(0.1200, 0.1200, 0.1200), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Plastic, Color = Color3.fromRGB(163, 162, 165) },
			{ Name = "OrbitalRings", MeshId = "rbxassetid://86964013371522", Size = Vector3.new(2.4033, 0.8313, 1.9815), Offset = Vector3.new(0.0000, 0.6800, 0.0000), Mat = Enum.Material.Neon, Color = Color3.fromRGB(130, 235, 255) },
			{ Name = "Pages", MeshId = "rbxassetid://112040369356684", Size = Vector3.new(1.5000, 0.4437, 1.2800), Offset = Vector3.new(0.0000, 0.6218, 0.0000), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(255, 255, 255) },
			{ Name = "SeraphWings", MeshId = "rbxassetid://121369466415466", Size = Vector3.new(4.3467, 1.6249, 1.4361), Offset = Vector3.new(0.0000, 1.2700, 0.5106), Mat = Enum.Material.Metal, Color = Color3.fromRGB(255, 225, 120) },
			{ Name = "Spine", MeshId = "rbxassetid://80242731102271", Size = Vector3.new(0.2500, 0.1250, 1.3000), Offset = Vector3.new(0.0000, 0.3175, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(240, 210, 100) },
			{ Name = "SpineClasps", MeshId = "rbxassetid://139770697073942", Size = Vector3.new(0.2960, 0.1480, 1.0136), Offset = Vector3.new(0.0000, 0.3060, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(250, 215, 105) },
		},
	},
	art_akashic_records = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 0.6500, 0.0000),
		BasePos = Vector3.new(0.0000, 0.3500, 0.0000),
		CorePos = Vector3.new(0.0000, 0.5500, 0.0000),
		Parts = {
			{ Name = "AkashicCore", MeshId = "rbxassetid://128483124962588", Size = Vector3.new(0.7826, 0.4800, 0.7795), Offset = Vector3.new(0.0000, 0.8400, 0.0000), Mat = Enum.Material.Neon, Color = Color3.fromRGB(210, 140, 255) },
			{ Name = "AstralWings", MeshId = "rbxassetid://87261705430703", Size = Vector3.new(4.7226, 1.7782, 1.5689), Offset = Vector3.new(0.0000, 1.3566, 0.5770), Mat = Enum.Material.Metal, Color = Color3.fromRGB(235, 205, 255) },
			{ Name = "Bookmark", MeshId = "rbxassetid://128876542275091", Size = Vector3.new(0.1794, 0.5860, 0.8000), Offset = Vector3.new(-0.0044, 0.2870, 0.4000), Mat = Enum.Material.Fabric, Color = Color3.fromRGB(175, 95, 245) },
			{ Name = "CornerBrackets", MeshId = "rbxassetid://80159821255257", Size = Vector3.new(1.5874, 0.1594, 1.3600), Offset = Vector3.new(0.0000, 0.5963, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(215, 185, 255) },
			{ Name = "Cover", MeshId = "rbxassetid://114020803989715", Size = Vector3.new(1.5770, 0.3067, 1.3600), Offset = Vector3.new(0.0000, 0.5067, 0.0000), Mat = Enum.Material.Slate, Color = Color3.fromRGB(18, 16, 26) },
			{ Name = "FiligreeTrim", MeshId = "rbxassetid://74925817421973", Size = Vector3.new(1.5853, 0.3321, 1.3600), Offset = Vector3.new(0.0000, 0.5067, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(225, 195, 255) },
			{ Name = "FloatingPages", MeshId = "rbxassetid://140424173710973", Size = Vector3.new(2.7642, 1.1515, 1.8213), Offset = Vector3.new(0.0000, 1.1192, 0.3463), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(248, 245, 255) },
			{ Name = "Handle", MeshId = "rbxassetid://84070404356820", Size = Vector3.new(0.1200, 0.1200, 0.1200), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Plastic, Color = Color3.fromRGB(163, 162, 165) },
			{ Name = "OrbitalRings", MeshId = "rbxassetid://98856433300698", Size = Vector3.new(2.5677, 0.8914, 2.1228), Offset = Vector3.new(0.0000, 0.7000, 0.0000), Mat = Enum.Material.Neon, Color = Color3.fromRGB(160, 100, 255) },
			{ Name = "Pages", MeshId = "rbxassetid://101649895517789", Size = Vector3.new(1.5400, 0.4602, 1.3000), Offset = Vector3.new(0.0000, 0.6301, 0.0000), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(245, 240, 255) },
			{ Name = "Spine", MeshId = "rbxassetid://126530548776398", Size = Vector3.new(0.2600, 0.1300, 1.3200), Offset = Vector3.new(0.0000, 0.3150, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(195, 165, 255) },
			{ Name = "SpineClasps", MeshId = "rbxassetid://88820334383639", Size = Vector3.new(0.3060, 0.1530, 1.0279), Offset = Vector3.new(0.0000, 0.3035, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(215, 185, 255) },
		},
	},
	art_book_of_primordial_genesis = {
		GripPos = Vector3.new(0.0000, 0.0000, 0.0000),
		TipPos = Vector3.new(0.0000, 0.6500, 0.0000),
		BasePos = Vector3.new(0.0000, 0.3500, 0.0000),
		CorePos = Vector3.new(0.0000, 0.5500, 0.0000),
		Parts = {
			{ Name = "Bookmark", MeshId = "rbxassetid://91867669562903", Size = Vector3.new(0.1853, 0.5860, 0.8000), Offset = Vector3.new(-0.0049, 0.2870, 0.4000), Mat = Enum.Material.Fabric, Color = Color3.fromRGB(255, 215, 80) },
			{ Name = "CornerBrackets", MeshId = "rbxassetid://75143299607661", Size = Vector3.new(1.6455, 0.1655, 1.4000), Offset = Vector3.new(0.0000, 0.6040, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(255, 220, 100) },
			{ Name = "Cover", MeshId = "rbxassetid://112052534727982", Size = Vector3.new(1.6347, 0.3178, 1.4000), Offset = Vector3.new(0.0000, 0.5114, 0.0000), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(255, 255, 255) },
			{ Name = "FiligreeTrim", MeshId = "rbxassetid://134663644543832", Size = Vector3.new(1.6435, 0.3448, 1.4000), Offset = Vector3.new(0.0000, 0.5114, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(255, 230, 120) },
			{ Name = "FloatingPages", MeshId = "rbxassetid://109638003288168", Size = Vector3.new(3.1842, 1.3798, 2.2010), Offset = Vector3.new(0.0000, 1.2440, 0.5157), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(255, 255, 255) },
			{ Name = "GenesisPrism", MeshId = "rbxassetid://101914424115025", Size = Vector3.new(0.8546, 0.5200, 0.8515), Offset = Vector3.new(0.0000, 0.8800, 0.0000), Mat = Enum.Material.Neon, Color = Color3.fromRGB(255, 255, 255) },
			{ Name = "GenesisWings", MeshId = "rbxassetid://87638125812851", Size = Vector3.new(5.0985, 1.9314, 1.7019), Offset = Vector3.new(0.0000, 1.4531, 0.6435), Mat = Enum.Material.Metal, Color = Color3.fromRGB(255, 230, 120) },
			{ Name = "Handle", MeshId = "rbxassetid://84070404356820", Size = Vector3.new(0.1200, 0.1200, 0.1200), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Plastic, Color = Color3.fromRGB(163, 162, 165) },
			{ Name = "OrbitalRings", MeshId = "rbxassetid://86405071626722", Size = Vector3.new(2.7508, 0.9529, 2.2696), Offset = Vector3.new(0.0000, 0.7200, 0.0000), Mat = Enum.Material.Neon, Color = Color3.fromRGB(80, 245, 255) },
			{ Name = "Pages", MeshId = "rbxassetid://129367485344852", Size = Vector3.new(1.6000, 0.4799, 1.3400), Offset = Vector3.new(0.0000, 0.6400, 0.0000), Mat = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(255, 255, 255) },
			{ Name = "Spine", MeshId = "rbxassetid://118392714839887", Size = Vector3.new(0.2700, 0.1350, 1.3500), Offset = Vector3.new(0.0000, 0.3125, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(255, 220, 100) },
			{ Name = "SpineClasps", MeshId = "rbxassetid://96075446779420", Size = Vector3.new(0.3160, 0.1580, 1.0543), Offset = Vector3.new(0.0000, 0.3010, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(255, 220, 100) },
		},
	},
}

TOME_STYLES = {
art_novice_tome = {
		RarityTier = 1,
		Parts = {
			Bookmark = { Material = Enum.Material.Fabric, Color = Color3.fromRGB(165, 35, 35) },
			CornerBrackets = { Material = Enum.Material.Metal, Color = Color3.fromRGB(175, 125, 75) },
			Cover = { Material = Enum.Material.Leather, Color = Color3.fromRGB(115, 65, 45) },
			Pages = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(242, 235, 215) },
			Spine = { Material = Enum.Material.Leather, Color = Color3.fromRGB(85, 45, 30) },
		},
	},
	art_acolytes_litany = {
		RarityTier = 1,
		Parts = {
			Bookmark = { Material = Enum.Material.Fabric, Color = Color3.fromRGB(45, 95, 165) },
			CornerBrackets = { Material = Enum.Material.Metal, Color = Color3.fromRGB(195, 145, 85) },
			Cover = { Material = Enum.Material.Leather, Color = Color3.fromRGB(55, 75, 95) },
			Pages = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(245, 238, 220) },
			Spine = { Material = Enum.Material.Leather, Color = Color3.fromRGB(40, 55, 75) },
			SpineClasps = { Material = Enum.Material.Metal, Color = Color3.fromRGB(195, 145, 85) },
		},
	},
	art_cleric_scripture = {
		RarityTier = 2,
		Parts = {
			Bookmark = { Material = Enum.Material.Fabric, Color = Color3.fromRGB(195, 155, 45) },
			CornerBrackets = { Material = Enum.Material.Metal, Color = Color3.fromRGB(210, 175, 95) },
			Cover = { Material = Enum.Material.Leather, Color = Color3.fromRGB(135, 45, 45) },
			FiligreeTrim = { Material = Enum.Material.Metal, Color = Color3.fromRGB(225, 185, 105) },
			Pages = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(245, 240, 225) },
			Spine = { Material = Enum.Material.Metal, Color = Color3.fromRGB(180, 185, 195) },
			SpineClasps = { Material = Enum.Material.Metal, Color = Color3.fromRGB(210, 175, 95) },
		},
	},
	art_mendicants_psalter = {
		RarityTier = 2,
		Parts = {
			Bookmark = { Material = Enum.Material.Fabric, Color = Color3.fromRGB(50, 150, 95) },
			CornerBrackets = { Material = Enum.Material.Metal, Color = Color3.fromRGB(220, 185, 110) },
			Cover = { Material = Enum.Material.Leather, Color = Color3.fromRGB(45, 85, 65) },
			FiligreeTrim = { Material = Enum.Material.Metal, Color = Color3.fromRGB(230, 195, 120) },
			Pages = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(245, 240, 225) },
			Spine = { Material = Enum.Material.Leather, Color = Color3.fromRGB(30, 60, 45) },
			SpineClasps = { Material = Enum.Material.Metal, Color = Color3.fromRGB(220, 185, 110) },
		},
	},
	art_hermetic_grimoire = {
		RarityTier = 3,
		Parts = {
			Bookmark = { Material = Enum.Material.Fabric, Color = Color3.fromRGB(150, 75, 225) },
			CornerBrackets = { Material = Enum.Material.Metal, Color = Color3.fromRGB(215, 220, 235) },
			Cover = { Material = Enum.Material.Slate, Color = Color3.fromRGB(38, 30, 52) },
			FiligreeTrim = { Material = Enum.Material.Metal, Color = Color3.fromRGB(225, 230, 245) },
			Pages = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(240, 235, 225) },
			RunicGlyph = { Material = Enum.Material.Neon, Color = Color3.fromRGB(140, 100, 255) },
			Spine = { Material = Enum.Material.Metal, Color = Color3.fromRGB(185, 190, 205) },
			SpineClasps = { Material = Enum.Material.Metal, Color = Color3.fromRGB(215, 220, 235) },
		},
	},
	art_restorative_codex = {
		RarityTier = 3,
		Parts = {
			Bookmark = { Material = Enum.Material.Fabric, Color = Color3.fromRGB(60, 200, 130) },
			CornerBrackets = { Material = Enum.Material.Metal, Color = Color3.fromRGB(225, 195, 110) },
			Cover = { Material = Enum.Material.Leather, Color = Color3.fromRGB(30, 65, 55) },
			FiligreeTrim = { Material = Enum.Material.Metal, Color = Color3.fromRGB(235, 205, 125) },
			Pages = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(245, 242, 230) },
			RestorationSeal = { Material = Enum.Material.Neon, Color = Color3.fromRGB(80, 255, 160) },
			Spine = { Material = Enum.Material.Metal, Color = Color3.fromRGB(205, 175, 95) },
			SpineClasps = { Material = Enum.Material.Metal, Color = Color3.fromRGB(225, 195, 110) },
		},
	},
	art_valeria_sanctuary = {
		RarityTier = 4,
		Parts = {
			Bookmark = { Material = Enum.Material.Fabric, Color = Color3.fromRGB(235, 185, 65) },
			CornerBrackets = { Material = Enum.Material.Metal, Color = Color3.fromRGB(245, 205, 95) },
			Cover = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(248, 246, 242) },
			FiligreeTrim = { Material = Enum.Material.Metal, Color = Color3.fromRGB(255, 215, 110) },
			Pages = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(255, 250, 240) },
			SanctuaryHalo = { Material = Enum.Material.Neon, Color = Color3.fromRGB(90, 255, 160) },
			SeraphWings = { Material = Enum.Material.Metal, Color = Color3.fromRGB(250, 210, 100) },
			Spine = { Material = Enum.Material.Metal, Color = Color3.fromRGB(235, 195, 85) },
			SpineClasps = { Material = Enum.Material.Metal, Color = Color3.fromRGB(245, 205, 95) },
		},
	},
	art_seraphs_testament = {
		RarityTier = 4,
		Parts = {
			Bookmark = { Material = Enum.Material.Fabric, Color = Color3.fromRGB(240, 190, 70) },
			CornerBrackets = { Material = Enum.Material.Metal, Color = Color3.fromRGB(245, 210, 105) },
			Cover = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(230, 235, 245) },
			FiligreeTrim = { Material = Enum.Material.Metal, Color = Color3.fromRGB(255, 220, 115) },
			Pages = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(255, 252, 245) },
			SanctuaryHalo = { Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 235, 120) },
			SeraphWings = { Material = Enum.Material.Metal, Color = Color3.fromRGB(255, 215, 110) },
			Spine = { Material = Enum.Material.Metal, Color = Color3.fromRGB(240, 205, 95) },
			SpineClasps = { Material = Enum.Material.Metal, Color = Color3.fromRGB(245, 210, 105) },
		},
	},
	art_necronomicon_pages = {
		RarityTier = 5,
		Parts = {
			Bookmark = { Material = Enum.Material.Fabric, Color = Color3.fromRGB(110, 30, 160) },
			CornerBrackets = { Material = Enum.Material.Metal, Color = Color3.fromRGB(75, 55, 95) },
			Cover = { Material = Enum.Material.Slate, Color = Color3.fromRGB(22, 18, 28) },
			EyeCore = { Material = Enum.Material.Neon, Color = Color3.fromRGB(180, 50, 255) },
			FiligreeTrim = { Material = Enum.Material.Metal, Color = Color3.fromRGB(85, 60, 105) },
			FloatingPages = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(225, 210, 195) },
			Pages = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(215, 205, 190) },
			Spine = { Material = Enum.Material.Metal, Color = Color3.fromRGB(60, 45, 75) },
			SpineClasps = { Material = Enum.Material.Metal, Color = Color3.fromRGB(75, 55, 95) },
		},
	},
	art_lifebinders_chronicle = {
		RarityTier = 5,
		Parts = {
			Bookmark = { Material = Enum.Material.Fabric, Color = Color3.fromRGB(50, 180, 90) },
			CornerBrackets = { Material = Enum.Material.Metal, Color = Color3.fromRGB(115, 175, 95) },
			Cover = { Material = Enum.Material.Wood, Color = Color3.fromRGB(48, 36, 26) },
			FiligreeTrim = { Material = Enum.Material.Metal, Color = Color3.fromRGB(125, 195, 105) },
			FloatingPages = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(245, 240, 225) },
			LifeCore = { Material = Enum.Material.Neon, Color = Color3.fromRGB(60, 255, 130) },
			Pages = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(245, 240, 225) },
			Spine = { Material = Enum.Material.Metal, Color = Color3.fromRGB(85, 135, 80) },
			SpineClasps = { Material = Enum.Material.Metal, Color = Color3.fromRGB(115, 175, 95) },
		},
	},
	art_seraphic_psalms = {
		RarityTier = 6,
		Parts = {
			Bookmark = { Material = Enum.Material.Fabric, Color = Color3.fromRGB(255, 200, 70) },
			CornerBrackets = { Material = Enum.Material.Metal, Color = Color3.fromRGB(255, 215, 95) },
			Cover = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(255, 252, 245) },
			FiligreeTrim = { Material = Enum.Material.Metal, Color = Color3.fromRGB(255, 225, 115) },
			FloatingPages = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(255, 252, 245) },
			OrbitalRings = { Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 235, 130) },
			Pages = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(255, 255, 250) },
			SeraphWings = { Material = Enum.Material.Metal, Color = Color3.fromRGB(255, 220, 110) },
			Spine = { Material = Enum.Material.Metal, Color = Color3.fromRGB(255, 215, 95) },
			SpineClasps = { Material = Enum.Material.Metal, Color = Color3.fromRGB(255, 215, 95) },
		},
	},
	art_divine_providence = {
		RarityTier = 6,
		Parts = {
			Bookmark = { Material = Enum.Material.Fabric, Color = Color3.fromRGB(90, 190, 255) },
			CornerBrackets = { Material = Enum.Material.Metal, Color = Color3.fromRGB(250, 215, 105) },
			Cover = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(245, 248, 255) },
			FiligreeTrim = { Material = Enum.Material.Metal, Color = Color3.fromRGB(255, 225, 120) },
			FloatingPages = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(255, 255, 255) },
			OrbitalRings = { Material = Enum.Material.Neon, Color = Color3.fromRGB(130, 235, 255) },
			Pages = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(255, 255, 255) },
			SeraphWings = { Material = Enum.Material.Metal, Color = Color3.fromRGB(255, 225, 120) },
			Spine = { Material = Enum.Material.Metal, Color = Color3.fromRGB(240, 210, 100) },
			SpineClasps = { Material = Enum.Material.Metal, Color = Color3.fromRGB(250, 215, 105) },
		},
	},
	art_akashic_records = {
		RarityTier = 7,
		Parts = {
			AkashicCore = { Material = Enum.Material.Neon, Color = Color3.fromRGB(210, 140, 255) },
			AstralWings = { Material = Enum.Material.Metal, Color = Color3.fromRGB(235, 205, 255) },
			Bookmark = { Material = Enum.Material.Fabric, Color = Color3.fromRGB(175, 95, 245) },
			CornerBrackets = { Material = Enum.Material.Metal, Color = Color3.fromRGB(215, 185, 255) },
			Cover = { Material = Enum.Material.Slate, Color = Color3.fromRGB(18, 16, 26) },
			FiligreeTrim = { Material = Enum.Material.Metal, Color = Color3.fromRGB(225, 195, 255) },
			FloatingPages = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(248, 245, 255) },
			OrbitalRings = { Material = Enum.Material.Neon, Color = Color3.fromRGB(160, 100, 255) },
			Pages = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(245, 240, 255) },
			Spine = { Material = Enum.Material.Metal, Color = Color3.fromRGB(195, 165, 255) },
			SpineClasps = { Material = Enum.Material.Metal, Color = Color3.fromRGB(215, 185, 255) },
		},
	},
	art_book_of_primordial_genesis = {
		RarityTier = 7,
		Parts = {
			Bookmark = { Material = Enum.Material.Fabric, Color = Color3.fromRGB(255, 215, 80) },
			CornerBrackets = { Material = Enum.Material.Metal, Color = Color3.fromRGB(255, 220, 100) },
			Cover = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(255, 255, 255) },
			FiligreeTrim = { Material = Enum.Material.Metal, Color = Color3.fromRGB(255, 230, 120) },
			FloatingPages = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(255, 255, 255) },
			GenesisPrism = { Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 255, 255) },
			GenesisWings = { Material = Enum.Material.Metal, Color = Color3.fromRGB(255, 230, 120) },
			OrbitalRings = { Material = Enum.Material.Neon, Color = Color3.fromRGB(80, 245, 255) },
			Pages = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(255, 255, 255) },
			Spine = { Material = Enum.Material.Metal, Color = Color3.fromRGB(255, 220, 100) },
			SpineClasps = { Material = Enum.Material.Metal, Color = Color3.fromRGB(255, 220, 100) },
		},
	},
}

function makeMeshTome(name: string): Model
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local weaponsFolder = assets and assets:FindFirstChild("Weapons")
	local existing = weaponsFolder and weaponsFolder:FindFirstChild(name)
	if existing and existing:IsA("Model") then
		return existing:Clone()
	end

	local data = TOME_MESH_DATA[name]
	assert(data, `No tome mesh data for {name}`)

	local model = Instance.new("Model")
	model.Name = name

	local style = TOME_STYLES and TOME_STYLES[name]
	local handlePart: MeshPart?

	for _, pInfo in ipairs(data.Parts) do
		local p = newUploadedMeshPart(pInfo.MeshId)
		p.Name = pInfo.Name
		p.Size = pInfo.Size
		p.CFrame = CFrame.new(pInfo.Offset)

		local pStyle = style and style.Parts and style.Parts[pInfo.Name]
		p.Material = (pStyle and pStyle.Material) or pInfo.Mat or Enum.Material.SmoothPlastic
		p.Color = (pStyle and pStyle.Color) or pInfo.Color or Color3.fromRGB(200, 200, 200)

		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.Anchored = false
		p.CastShadow = false
		if pInfo.Name == "Handle" then
			p.Transparency = 1
		end
		p.Parent = model

		if pInfo.Name == "Handle" then
			handlePart = p
			model.PrimaryPart = p
		end
	end

	assert(handlePart, `Handle part missing for {name}`)

	-- Weld all child parts to the primary Handle
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") and child ~= handlePart then
			local weld = Instance.new("WeldConstraint")
			weld.Name = "Weld_" .. child.Name
			weld.Part0 = handlePart
			weld.Part1 = child
			weld.Parent = handlePart
		end
	end

	-- Sockets: Grip, Tip, VfxTip, VfxBase, VfxCore
	-- Tomes float horizontally above the upturned open palm with pages facing skyward
	local floatOffset = 1.025
	local grip = Instance.new("Attachment")
	grip.Name = "Grip"
	grip.CFrame = CFrame.new(0, -floatOffset, -0.05) * CFrame.Angles(0, 0, math.rad(90))
	grip.Parent = handlePart

	local tip = Instance.new("Attachment")
	tip.Name = "Tip"
	tip.CFrame = CFrame.new(data.TipPos)
	tip.Parent = handlePart

	local vfxTip = Instance.new("Attachment")
	vfxTip.Name = "VfxTip"
	vfxTip.CFrame = CFrame.new(data.TipPos)
	vfxTip.Parent = handlePart

	local vfxBase = Instance.new("Attachment")
	vfxBase.Name = "VfxBase"
	vfxBase.CFrame = CFrame.new(data.BasePos)
	vfxBase.Parent = handlePart

	local vfxCore = Instance.new("Attachment")
	vfxCore.Name = "VfxCore"
	vfxCore.CFrame = CFrame.new(data.CorePos)
	vfxCore.Parent = handlePart

	-- Apply client-side weapon VFX (glints, lights, auras, trails)
	local combatVfx = assets and assets:FindFirstChild("CombatVfx")
	local weaponVfxMod = combatVfx and combatVfx:FindFirstChild("WeaponVfx")
	if weaponVfxMod then
		local ok, WeaponVfx = pcall(require, weaponVfxMod)
		if ok and WeaponVfx and WeaponVfx.Apply then
			local rarity = style and style.RarityTier or 1
			WeaponVfx.Apply(model, "TOME", rarity, name)
		end
	end

	return model
end

function WeaponModelBuilder.BuildNoviceTomeArtifact(): Model
	return makeMeshTome("art_novice_tome")
end

function WeaponModelBuilder.BuildAcolytesLitanyArtifact(): Model
	return makeMeshTome("art_acolytes_litany")
end

function WeaponModelBuilder.BuildClericScriptureArtifact(): Model
	return makeMeshTome("art_cleric_scripture")
end

function WeaponModelBuilder.BuildMendicantsPsalterArtifact(): Model
	return makeMeshTome("art_mendicants_psalter")
end

function WeaponModelBuilder.BuildHermeticGrimoireArtifact(): Model
	return makeMeshTome("art_hermetic_grimoire")
end

function WeaponModelBuilder.BuildRestorativeCodexArtifact(): Model
	return makeMeshTome("art_restorative_codex")
end

function WeaponModelBuilder.BuildValeriaSanctuaryArtifact(): Model
	return makeMeshTome("art_valeria_sanctuary")
end

function WeaponModelBuilder.BuildSeraphsTestamentArtifact(): Model
	return makeMeshTome("art_seraphs_testament")
end

function WeaponModelBuilder.BuildNecronomiconPagesArtifact(): Model
	return makeMeshTome("art_necronomicon_pages")
end

function WeaponModelBuilder.BuildLifebindersChronicleArtifact(): Model
	return makeMeshTome("art_lifebinders_chronicle")
end

function WeaponModelBuilder.BuildSeraphicPsalmsArtifact(): Model
	return makeMeshTome("art_seraphic_psalms")
end

function WeaponModelBuilder.BuildDivineProvidenceArtifact(): Model
	return makeMeshTome("art_divine_providence")
end

function WeaponModelBuilder.BuildAkashicRecordsArtifact(): Model
	return makeMeshTome("art_akashic_records")
end

function WeaponModelBuilder.BuildBookOfPrimordialGenesisArtifact(): Model
	return makeMeshTome("art_book_of_primordial_genesis")
end

-- ============================================================================
-- THE GILDED ANVIL (6 Gildforged Tier-8 Transcendent Weapons from Blender)
-- ============================================================================
type GildedSpec = {
	Type: string,
	GripPos: Vector3,
	GripRotDeg: Vector3?,
	OffhandGripPos: Vector3?,
	TipPos: Vector3,
	BasePos: Vector3,
	CorePos: Vector3,
	TrailTopPos: Vector3?,
	TrailBottomPos: Vector3?,
}

local GILDED_SPECS: { [string]: GildedSpec } = {
	art_gild_dawnwarden_oath = {
		Type = "SWORD_SHIELD",
		GripPos = Vector3.zero,
		GripRotDeg = EDGE_PLUS_X,
		TipPos = Vector3.new(0, 5.20, 0),
		BasePos = Vector3.new(0, 0.74, 0),
		CorePos = Vector3.new(0, 2.75, 0),
		TrailTopPos = Vector3.new(0, 5.15, 0),
		TrailBottomPos = Vector3.new(0, 0.85, 0),
	},
	art_gild_eclipse_sisters = {
		Type = "DAGGERS",
		GripPos = Vector3.zero,
		GripRotDeg = EDGE_PLUS_X,
		TipPos = Vector3.new(0, 2.58, 0),
		BasePos = Vector3.new(0, 0.46, 0),
		CorePos = Vector3.new(0, 1.45, 0),
		TrailTopPos = Vector3.new(0, 2.54, 0),
		TrailBottomPos = Vector3.new(0, 0.50, 0),
	},
	art_gild_aurora_skyhook = {
		Type = "BOW",
		GripPos = Vector3.zero,
		GripRotDeg = Vector3.zero,
		TipPos = Vector3.new(0, 1.96, 0.50),
		BasePos = Vector3.new(0, -1.96, 0.50),
		CorePos = Vector3.new(0, 0, -0.05),
		TrailTopPos = Vector3.new(0, 1.96, 0.50),
		TrailBottomPos = Vector3.new(0, -1.96, 0.50),
	},
	art_gild_wyrmheart_cleaver = {
		Type = "AXE",
		GripPos = Vector3.new(0, 0.35, 0),
		GripRotDeg = EDGE_PLUS_X,
		OffhandGripPos = Vector3.new(0, 0.35 - AXE_HAND_GAP, 0),
		TipPos = Vector3.new(1.88, 3.46, 0),
		BasePos = Vector3.new(1.76, 0.76, 0),
		CorePos = Vector3.new(0.74, 2.08, 0),
		TrailTopPos = Vector3.new(1.88, 3.46, 0),
		TrailBottomPos = Vector3.new(1.76, 0.76, 0),
	},
	art_gild_ninth_sky_orrery = {
		Type = "STAFF",
		GripPos = Vector3.new(0, -0.40, 0),
		GripRotDeg = Vector3.zero,
		TipPos = Vector3.new(0, 3.55, 0),
		BasePos = Vector3.new(0, 1.96, 0),
		CorePos = Vector3.new(0, 2.75, 0),
		TrailTopPos = Vector3.new(0, 3.55, 0),
		TrailBottomPos = Vector3.new(0, 2.02, 0),
	},
	art_gild_evergarden_codex = {
		Type = "TOME",
		GripPos = Vector3.new(0, -1.025, -0.05),
		GripRotDeg = Vector3.new(0, 0, 90),
		TipPos = Vector3.new(0, 0.90, 0),
		BasePos = Vector3.new(0, 0.34, 0),
		CorePos = Vector3.new(0, 0.72, 0),
		TrailTopPos = Vector3.new(0, 0.96, 0),
		TrailBottomPos = Vector3.new(0, 0.34, 0),
	},
}

local gildedMeshPartCache: { [string]: MeshPart } = {}
-- Studio's 3D importer turns every uploaded Gilded Anvil mesh 180° about +Y relative to the Blender export
-- (X and Z negated, checked against the shard vertices). Parts loaded from a MeshId undo that turn;
-- EditableMesh fallback parts are built straight from the shard and need no correction.
local GILDED_IMPORTER_FIX = CFrame.Angles(0, math.pi, 0)
local gildedLocalModelCache: { [string]: Model } = {}

function WeaponModelBuilder.IsGildedTemplate(templateId: string?): boolean
	return type(templateId) == "string" and GildedAnvilMeshData.Weapons[templateId] ~= nil
end

local function createGildedMeshPart(cacheKey: string, spec: GildedAnvilMeshData.PartMeshSpec, size: Vector3, doubleSided: boolean, meshId: string?): BasePart
	local targetSize = if size.Magnitude > 0.001
		then Vector3.new(math.max(0.02, size.X), math.max(0.02, size.Y), math.max(0.02, size.Z))
		else Vector3.new(0.04, 0.04, 0.04)

	local cachedMp = gildedMeshPartCache[cacheKey]
	if cachedMp then
		local cloned = cachedMp:Clone()
		pcall(function()
			cloned.DoubleSided = doubleSided
		end)
		cloned.Size = targetSize
		return cloned
	end

	if type(meshId) == "string" and meshId ~= "" then
		local okAsset, assetMp = pcall(function(): any
			local mp = AssetService:CreateMeshPartAsync(Content.fromUri(meshId))
			mp.DoubleSided = doubleSided
			mp.Size = targetSize
			mp:SetAttribute("GildUploadedMesh", true)
			return mp
		end)
		if okAsset and assetMp then
			gildedMeshPartCache[cacheKey] = assetMp
			return assetMp:Clone()
		end
		local directMp = Instance.new("MeshPart")
		local okAssign = pcall(function()
			(directMp :: any).MeshId = meshId
		end)
		if okAssign then
			pcall(function()
				directMp.DoubleSided = doubleSided
			end)
			directMp.Size = targetSize
			gildedMeshPartCache[cacheKey] = directMp
			return directMp:Clone()
		end
		directMp:Destroy()
	end

	-- Fallback: no uploaded MeshId (or it failed to load), so rebuild the sculpt from the packed shard geometry.
	local ok, resultPart = pcall(function(): any
		local verts, tris = GildedAnvilMeshData.GetGeometry(spec)
		local em = AssetService:CreateEditableMesh()
		local vertCount = #verts // 3
		local vPos = table.create(vertCount)
		local vIds = table.create(vertCount)
		for idx = 1, vertCount do
			local base = (idx - 1) * 3
			local pos = Vector3.new(verts[base + 1], verts[base + 2], verts[base + 3])
			vPos[idx] = pos
			vIds[idx] = em:AddVertex(pos)
		end

		local normX = table.create(vertCount, 0)
		local normY = table.create(vertCount, 0)
		local normZ = table.create(vertCount, 0)
		for i = 1, #tris, 3 do
			local i1, i2, i3 = tris[i], tris[i + 1], tris[i + 2]
			local p1, p2, p3 = vPos[i1], vPos[i2], vPos[i3]
			if p1 and p2 and p3 then
				local c = (p2 - p1):Cross(p3 - p1)
				normX[i1] += c.X
				normY[i1] += c.Y
				normZ[i1] += c.Z
				normX[i2] += c.X
				normY[i2] += c.Y
				normZ[i2] += c.Z
				normX[i3] += c.X
				normY[i3] += c.Y
				normZ[i3] += c.Z
			end
		end

		local nIds = table.create(vertCount)
		for idx = 1, vertCount do
			local nx, ny, nz = normX[idx], normY[idx], normZ[idx]
			local len = math.sqrt(nx * nx + ny * ny + nz * nz)
			local nVec = if len > 1e-6 then Vector3.new(nx / len, ny / len, nz / len) else Vector3.yAxis
			nIds[idx] = em:AddNormal(nVec)
		end

		for i = 1, #tris, 3 do
			local i1, i2, i3 = tris[i], tris[i + 1], tris[i + 2]
			local a, b, c = vIds[i1], vIds[i2], vIds[i3]
			if a and b and c then
				local triId = em:AddTriangle(a, b, c)
				local na, nb, nc = nIds[i1], nIds[i2], nIds[i3]
				if na and nb and nc then
					pcall(function()
						em:SetFaceNormals(triId, { na, nb, nc })
					end)
				end
			end
		end

		local mp = AssetService:CreateMeshPartAsync(Content.fromObject(em))
		pcall(function()
			em:Destroy()
		end)
		pcall(function()
			mp.DoubleSided = doubleSided
		end)
		mp.Size = targetSize
		gildedMeshPartCache[cacheKey] = mp
		return mp:Clone()
	end)
	if ok and resultPart then
		return resultPart
	end

	local fallback = Instance.new("Part")
	fallback.Size = targetSize
	return fallback
end

local function setWeaponSpaceAttachment(primary: BasePart, attName: string, weaponPos: Vector3, rotDeg: Vector3?): Attachment
	local rot = rotDeg or Vector3.zero
	local worldCF = CFrame.new(weaponPos) * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
	local existing = primary:FindFirstChild(attName)
	if existing then
		existing:Destroy()
	end
	local att = Instance.new("Attachment")
	att.Name = attName
	att.CFrame = primary.CFrame:ToObjectSpace(worldCF)
	att.Parent = primary
	return att
end

-- Loads every uploaded mesh of a Gildforged weapon at once (CreateMeshPartAsync yields per call, so one at a
-- time took 5-8 s a weapon) and fills gildedMeshPartCache. Yields until all of them have answered.
local function prefetchGildedMeshes(templateId: string)
	local meshList = GildedAnvilMeshData.Weapons[templateId]
	if not meshList then
		return
	end
	local pending = 0
	for idx, pData in ipairs(meshList) do
		local cacheKey = `{templateId}::{pData.Name}::{idx}`
		local meshId = pData.MeshId
		if not gildedMeshPartCache[cacheKey] and type(meshId) == "string" and meshId ~= "" then
			pending += 1
			task.spawn(function()
				local ok, mp = pcall(function(): any
					return AssetService:CreateMeshPartAsync(Content.fromUri(meshId))
				end)
				if ok and mp and not gildedMeshPartCache[cacheKey] then
					mp:SetAttribute("GildUploadedMesh", true)
					gildedMeshPartCache[cacheKey] = mp
				end
				pending -= 1
			end)
		end
	end
	local deadline = os.clock() + 20
	while pending > 0 and os.clock() < deadline do
		task.wait()
	end
end

-- Warms the mesh cache for all six Gildforged weapons in parallel (call once from a client or server bootstrap).
function WeaponModelBuilder.PreloadGildedMeshes()
	for templateId in pairs(GildedAnvilMeshData.Weapons) do
		task.spawn(prefetchGildedMeshes, templateId)
	end
end

local function buildGildedWeapon(templateId: string, spec: GildedSpec?): Model
	prefetchGildedMeshes(templateId)
	local meshList = GildedAnvilMeshData.Weapons[templateId]
	assert(meshList, `No GildedAnvilMeshData entry for {templateId}`)
	local resolvedSpec = spec or GILDED_SPECS[templateId]
	assert(resolvedSpec, `No GILDED_SPECS entry for {templateId}`)

	local model = Instance.new("Model")
	model.Name = templateId
	model:SetAttribute("IsGildforged", true)
	model:SetAttribute("WeaponTemplateId", templateId)

	local offhandShieldModel: Model? = nil
	local leftDaggerModel: Model? = nil
	local hunterArrowModel: Model? = nil

	if templateId == "art_gild_dawnwarden_oath" then
		offhandShieldModel = Instance.new("Model")
		offhandShieldModel.Name = "OffhandShield"
		offhandShieldModel.Parent = model
	elseif templateId == "art_gild_eclipse_sisters" then
		leftDaggerModel = Instance.new("Model")
		leftDaggerModel.Name = "LeftDagger"
		leftDaggerModel.Parent = model
	elseif templateId == "art_gild_aurora_skyhook" then
		hunterArrowModel = Instance.new("Model")
		hunterArrowModel.Name = "HunterArrow"
		hunterArrowModel.Parent = model
	end

	local animRecords: { { Part: BasePart, AssemblyPrimaryName: string, Role: string, PivotOffset: Vector3 } } = {}
	local partAssemblyPrimary: { [BasePart]: string } = {}
	local primaries: { [string]: BasePart } = {}

	for idx, pData in ipairs(meshList) do
		local cacheKey = `{templateId}::{pData.Name}::{idx}`
		local p = createGildedMeshPart(cacheKey, pData, pData.Size, pData.DoubleSided == true, pData.MeshId)
		p.Name = pData.Name
		local rotDeg = pData.RotDeg or Vector3.zero
		p.CFrame = CFrame.new(pData.Offset)
			* CFrame.Angles(math.rad(rotDeg.X), math.rad(rotDeg.Y), math.rad(rotDeg.Z))
			* (if p:GetAttribute("GildUploadedMesh") then GILDED_IMPORTER_FIX else CFrame.identity)
		p.Material = pData.Material or Enum.Material.Metal
		p.Color = pData.Color or Color3.fromRGB(245, 192, 72)
		p.Transparency = if templateId == "art_gild_evergarden_codex" and pData.Name == "Handle"
			then 1
			else (pData.Transparency or 0)
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.Anchored = false
		p.CastShadow = false

		local subCol = pData.SubCollection or ""
		local primaryKey = "Main"
		if subCol == "OffhandShield" and offhandShieldModel then
			p.Parent = offhandShieldModel
			primaryKey = "OffhandShield"
			if pData.Name == "HandleS" then
				offhandShieldModel.PrimaryPart = p
				primaries.OffhandShield = p
			end
		elseif subCol == "LeftDagger" and leftDaggerModel then
			p.Parent = leftDaggerModel
			primaryKey = "LeftDagger"
			if pData.Name == "HandleL" then
				leftDaggerModel.PrimaryPart = p
				primaries.LeftDagger = p
			end
		elseif subCol == "HunterArrow" and hunterArrowModel then
			p.Parent = hunterArrowModel
			primaryKey = "Main"
		else
			p.Parent = model
			primaryKey = "Main"
			if pData.Name == "Handle" then
				model.PrimaryPart = p
				primaries.Main = p
			end
		end

		partAssemblyPrimary[p] = primaryKey
		if pData.AnimRole and pData.AnimRole ~= "" then
			p:SetAttribute("GildAnimRole", pData.AnimRole)
			table.insert(animRecords, {
				Part = p,
				AssemblyPrimaryName = primaryKey,
				Role = pData.AnimRole,
				PivotOffset = pData.PivotOffset or pData.Offset,
			})
		end
	end

	local animByPart: { [BasePart]: { Role: string, PivotOffset: Vector3 } } = {}
	for _, rec in ipairs(animRecords) do
		animByPart[rec.Part] = { Role = rec.Role, PivotOffset = rec.PivotOffset }
	end

	local mainPrimary = primaries.Main
	assert(mainPrimary, `Handle part missing for {templateId}`)

	for part, key in pairs(partAssemblyPrimary) do
		local root = primaries[key]
		if root and part ~= root then
			local animInfo = animByPart[part]
			if animInfo then
				local weld = Instance.new("Weld")
				weld.Name = "GildAnimWeld_" .. part.Name
				weld.Part0 = root
				weld.Part1 = part
				weld.C0 = root.CFrame:ToObjectSpace(CFrame.new(animInfo.PivotOffset))
				weld.C1 = part.CFrame:ToObjectSpace(root.CFrame * weld.C0)
				weld:SetAttribute("BaseC0", weld.C0)
				weld:SetAttribute("GildAnimRole", animInfo.Role)
				weld.Parent = root
			else
				weldTo(root, part)
			end
		end
	end

	-- Main assembly socket & VFX attachments (in weapon space mapped to Handle object space)
	setWeaponSpaceAttachment(mainPrimary, "Grip", resolvedSpec.GripPos, resolvedSpec.GripRotDeg)
	if resolvedSpec.OffhandGripPos then
		setWeaponSpaceAttachment(mainPrimary, "OffhandGrip", resolvedSpec.OffhandGripPos, resolvedSpec.GripRotDeg)
	end
	if resolvedSpec.Type == "BOW" then
		setWeaponSpaceAttachment(mainPrimary, "Nock", Vector3.new(ARROW_REST.X, ARROW_REST.Y, 0.50))
		setWeaponSpaceAttachment(mainPrimary, "TipUpper", Vector3.new(0, 1.96, 0.50))
		setWeaponSpaceAttachment(mainPrimary, "TipLower", Vector3.new(0, -1.96, 0.50))
		setWeaponSpaceAttachment(mainPrimary, "BowStringTop", Vector3.new(0, 1.96, 0.50))
		setWeaponSpaceAttachment(mainPrimary, "BowStringBottom", Vector3.new(0, -1.96, 0.50))
	end
	setWeaponSpaceAttachment(mainPrimary, "Tip", resolvedSpec.TipPos)
	setWeaponSpaceAttachment(mainPrimary, "VfxTip", resolvedSpec.TipPos)
	setWeaponSpaceAttachment(mainPrimary, "VfxBase", resolvedSpec.BasePos)
	setWeaponSpaceAttachment(mainPrimary, "VfxCore", resolvedSpec.CorePos)
	if resolvedSpec.TrailTopPos then
		setWeaponSpaceAttachment(mainPrimary, "TrailTop", resolvedSpec.TrailTopPos)
	end
	if resolvedSpec.TrailBottomPos then
		setWeaponSpaceAttachment(mainPrimary, "TrailBottom", resolvedSpec.TrailBottomPos)
	end

	if offhandShieldModel and primaries.OffhandShield then
		local handleS = primaries.OffhandShield
		setWeaponSpaceAttachment(handleS, "ShieldMount", Vector3.new(-0.18, 0, 0), Vector3.new(0, 90, 0))
		setWeaponSpaceAttachment(handleS, "VfxShieldCenter", Vector3.new(-0.54, 0.24, 0))
	end

	if leftDaggerModel and primaries.LeftDagger then
		local handleL = primaries.LeftDagger
		setWeaponSpaceAttachment(handleL, "Grip", resolvedSpec.GripPos, resolvedSpec.GripRotDeg)
		setWeaponSpaceAttachment(handleL, "Tip", Vector3.new(0, 2.52, 0))
		setWeaponSpaceAttachment(handleL, "VfxTip", Vector3.new(0, 2.52, 0))
		setWeaponSpaceAttachment(handleL, "VfxBase", Vector3.new(0, 0.46, 0))
		setWeaponSpaceAttachment(handleL, "VfxCore", Vector3.new(0, 1.42, 0))
		setWeaponSpaceAttachment(handleL, "TrailTop", Vector3.new(0, 2.48, 0))
		setWeaponSpaceAttachment(handleL, "TrailBottom", Vector3.new(0, 0.48, 0))
	end

	-- Apply Gilded Band 6 VFX
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local combatVfx = assets and assets:FindFirstChild("CombatVfx")
	local weaponVfxMod = combatVfx and combatVfx:FindFirstChild("WeaponVfx")
	if weaponVfxMod then
		local ok, WeaponVfx = pcall(require, weaponVfxMod)
		if ok and WeaponVfx and WeaponVfx.Apply then
			WeaponVfx.Apply(model, resolvedSpec.Type, 8, templateId)
		end
	end

	return model
end

function WeaponModelBuilder.CloneOrBuildPrefab(prefabName: string): Model?
	if WeaponModelBuilder.IsGildedTemplate(prefabName) then
		-- On clients, always instantiate from a client-local EditableMesh cache so MeshContent stays valid across the client-server boundary.
		if RunService:IsClient() then
			local cached = gildedLocalModelCache[prefabName]
			if not cached then
				cached = buildGildedWeapon(prefabName, GILDED_SPECS[prefabName])
				gildedLocalModelCache[prefabName] = cached
			end
			return cached:Clone()
		end
		return buildGildedWeapon(prefabName, GILDED_SPECS[prefabName])
	end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local weaponsFolder = assets and assets:FindFirstChild("Weapons")
	local existing = weaponsFolder and weaponsFolder:FindFirstChild(prefabName)
	if existing and existing:IsA("Model") then
		return existing:Clone()
	end
	return nil
end

function WeaponModelBuilder.BuildDawnwardenOath(): Model
	return buildGildedWeapon("art_gild_dawnwarden_oath", GILDED_SPECS.art_gild_dawnwarden_oath)
end

function WeaponModelBuilder.BuildEclipseSisters(): Model
	return buildGildedWeapon("art_gild_eclipse_sisters", GILDED_SPECS.art_gild_eclipse_sisters)
end

function WeaponModelBuilder.BuildAuroraSkyhook(): Model
	return buildGildedWeapon("art_gild_aurora_skyhook", GILDED_SPECS.art_gild_aurora_skyhook)
end

function WeaponModelBuilder.BuildWyrmheartCleaver(): Model
	return buildGildedWeapon("art_gild_wyrmheart_cleaver", GILDED_SPECS.art_gild_wyrmheart_cleaver)
end

function WeaponModelBuilder.BuildNinthSkyOrrery(): Model
	return buildGildedWeapon("art_gild_ninth_sky_orrery", GILDED_SPECS.art_gild_ninth_sky_orrery)
end

function WeaponModelBuilder.BuildEvergardenCodex(): Model
	return buildGildedWeapon("art_gild_evergarden_codex", GILDED_SPECS.art_gild_evergarden_codex)
end





-- Returns the Weapons folder first (ArtPackVisuals relies on that), then name -> prefab.
function WeaponModelBuilder.EnsureWeapons(): (Folder, { [string]: Model })
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		assets = Instance.new("Folder")
		assets.Name = "Assets"
		assets.Parent = ReplicatedStorage
	end

	local weaponsFolder = assets:FindFirstChild("Weapons") :: Folder?
	if not weaponsFolder then
		weaponsFolder = Instance.new("Folder")
		weaponsFolder.Name = "Weapons"
		weaponsFolder.Parent = assets
	end

	local builders: { [string]: () -> Model } = {
		weapon_bow = WeaponModelBuilder.BuildBow,
		art_hunters_shortbow = WeaponModelBuilder.BuildHuntersShortbow,
		art_reinforced_longbow = WeaponModelBuilder.BuildReinforcedLongbow,
		art_recurve_composite = WeaponModelBuilder.BuildRecurveComposite,
		art_gale_force_composite = WeaponModelBuilder.BuildGaleForceComposite,
		art_stormstrider_longbow = WeaponModelBuilder.BuildStormstriderLongbow,
		art_thunderhead_recurve = WeaponModelBuilder.BuildThunderheadRecurve,
		art_crystal_greatbow = WeaponModelBuilder.BuildCrystalGreatbow,
		art_prismatic_arbalest = WeaponModelBuilder.BuildPrismaticArbalest,
		art_phoenix_flatbow = WeaponModelBuilder.BuildPhoenixFlatbow,
		art_solar_flare_recurve = WeaponModelBuilder.BuildSolarFlareRecurve,
		art_celestial_zenith = WeaponModelBuilder.BuildCelestialZenith,
		art_supernova_greatbow = WeaponModelBuilder.BuildSupernovaGreatbow,
		art_astrea_cosmic_bow = WeaponModelBuilder.BuildAstreaCosmicBow,
		art_infinity_genesis_bow = WeaponModelBuilder.BuildInfinityGenesisBow,
		weapon_sword = WeaponModelBuilder.BuildSword,
		weapon_sword_shield = WeaponModelBuilder.BuildSwordShield,
		weapon_iron_broadsword = WeaponModelBuilder.BuildIronBroadsword,
		weapon_runic_longsword = WeaponModelBuilder.BuildRunicLongsword,
		art_iron_broadsword = WeaponModelBuilder.BuildIronBroadswordArtifact,
		art_tempered_bastard_sword = WeaponModelBuilder.BuildTemperedBastardSword,
		art_runic_longsword = WeaponModelBuilder.BuildRunicLongswordArtifact,
		art_knightly_estoc = WeaponModelBuilder.BuildKnightlyEstoc,
		art_paladin_spatha = WeaponModelBuilder.BuildPaladinSpatha,
		art_vanguard_warden_bastion = WeaponModelBuilder.BuildVanguardWardenBastion,
		art_crystal_claymore = WeaponModelBuilder.BuildCrystalClaymore,
		art_resonant_bulwark = WeaponModelBuilder.BuildResonantBulwark,
		art_paladin_claymore = WeaponModelBuilder.BuildPaladinClaymoreArtifact,
		art_aegis_of_valor = WeaponModelBuilder.BuildAegisOfValor,
		art_blade_of_the_rift = WeaponModelBuilder.BuildBladeOfTheRift,
		art_aegis_core = WeaponModelBuilder.BuildAegisCore,
		art_astral_executioner = WeaponModelBuilder.BuildAstralExecutioner,
		art_genesis_worldbreaker = WeaponModelBuilder.BuildGenesisWorldbreaker,
		-- Striker Dual Daggers (Batch 3)
		art_rusty_daggers = WeaponModelBuilder.BuildRustyDaggersArtifact,
		art_serrated_skewers = WeaponModelBuilder.BuildSerratedSkewersArtifact,
		art_viper_kris = WeaponModelBuilder.BuildViperKrisArtifact,
		art_silent_dirks = WeaponModelBuilder.BuildSilentDirksArtifact,
		art_shadow_fangs = WeaponModelBuilder.BuildShadowFangsArtifact,
		art_phantom_stiletto = WeaponModelBuilder.BuildPhantomStilettoArtifact,
		art_phantom_edge = WeaponModelBuilder.BuildPhantomEdgeArtifact,
		art_nightstalker_katar = WeaponModelBuilder.BuildNightstalkerKatarArtifact,
		art_bloodthirst_twinblades = WeaponModelBuilder.BuildBloodthirstTwinbladesArtifact,
		art_crimson_carnage = WeaponModelBuilder.BuildCrimsonCarnageArtifact,
		art_eclipse_daggers = WeaponModelBuilder.BuildEclipseDaggersArtifact,
		art_abyssal_razor = WeaponModelBuilder.BuildAbyssalRazorArtifact,
		art_abyssal_ravagers = WeaponModelBuilder.BuildAbyssalRavagersArtifact,
		art_void_reapers = WeaponModelBuilder.BuildVoidReapersArtifact,
		-- Berserker Axes (Batch 4)
		art_miner_pickaxe = WeaponModelBuilder.BuildMinerPickaxeArtifact,
		art_heavy_hewing_axe = WeaponModelBuilder.BuildHeavyHewingAxeArtifact,
		art_canyon_splitter = WeaponModelBuilder.BuildCanyonSplitterArtifact,
		art_quakestone_greataxe = WeaponModelBuilder.BuildQuakestoneGreataxeArtifact,
		art_battleaxe_cleaver = WeaponModelBuilder.BuildBattleaxeCleaverArtifact,
		art_iron_juggernaut_cleaver = WeaponModelBuilder.BuildIronJuggernautCleaverArtifact,
		art_magma_behemoth = WeaponModelBuilder.BuildMagmaBehemothArtifact,
		art_obsidian_hell_splitter = WeaponModelBuilder.BuildObsidianHellSplitterArtifact,
		art_titan_earthshaker = WeaponModelBuilder.BuildTitanEarthshakerArtifact,
		art_mountain_breaker = WeaponModelBuilder.BuildMountainBreakerArtifact,
		art_valkyrie_waraxe = WeaponModelBuilder.BuildValkyrieWaraxeArtifact,
		art_world_shaper = WeaponModelBuilder.BuildWorldShaperArtifact,
		art_world_carver = WeaponModelBuilder.BuildWorldCarverArtifact,
		art_genesis_sunderer = WeaponModelBuilder.BuildGenesisSundererArtifact,
		-- Healer Tomes (Batch 6)
		art_novice_tome = WeaponModelBuilder.BuildNoviceTomeArtifact,
		art_acolytes_litany = WeaponModelBuilder.BuildAcolytesLitanyArtifact,
		art_cleric_scripture = WeaponModelBuilder.BuildClericScriptureArtifact,
		art_mendicants_psalter = WeaponModelBuilder.BuildMendicantsPsalterArtifact,
		art_hermetic_grimoire = WeaponModelBuilder.BuildHermeticGrimoireArtifact,
		art_restorative_codex = WeaponModelBuilder.BuildRestorativeCodexArtifact,
		art_valeria_sanctuary = WeaponModelBuilder.BuildValeriaSanctuaryArtifact,
		art_seraphs_testament = WeaponModelBuilder.BuildSeraphsTestamentArtifact,
		art_necronomicon_pages = WeaponModelBuilder.BuildNecronomiconPagesArtifact,
		art_lifebinders_chronicle = WeaponModelBuilder.BuildLifebindersChronicleArtifact,
		art_seraphic_psalms = WeaponModelBuilder.BuildSeraphicPsalmsArtifact,
		art_divine_providence = WeaponModelBuilder.BuildDivineProvidenceArtifact,
		art_akashic_records = WeaponModelBuilder.BuildAkashicRecordsArtifact,
		art_book_of_primordial_genesis = WeaponModelBuilder.BuildBookOfPrimordialGenesisArtifact,
		-- Mage Staves (Batch 5)
		art_apprentice_cane = WeaponModelBuilder.BuildApprenticeCaneArtifact,
		art_scholars_spire = WeaponModelBuilder.BuildScholarsSpireArtifact,
		art_ruby_staff = WeaponModelBuilder.BuildRubyStaffArtifact,
		art_pyromancers_torch_rod = WeaponModelBuilder.BuildPyromancersTorchRodArtifact,
		art_frostweaver_scepter = WeaponModelBuilder.BuildFrostweaverScepterArtifact,
		art_glacial_monolith = WeaponModelBuilder.BuildGlacialMonolithArtifact,
		art_archmage_rod = WeaponModelBuilder.BuildArchmageRodArtifact,
		art_chronomancers_spindle = WeaponModelBuilder.BuildChronomancersSpindleArtifact,
		art_infernal_pillar = WeaponModelBuilder.BuildInfernalPillarArtifact,
		art_void_channeler = WeaponModelBuilder.BuildVoidChannelerArtifact,
		art_solaris_sunburst = WeaponModelBuilder.BuildSolarisSunburstArtifact,
		art_chronos_stave = WeaponModelBuilder.BuildChronosStaveArtifact,
		art_eye_of_singularity = WeaponModelBuilder.BuildEyeOfSingularityArtifact,
		art_omega_archon_caduceus = WeaponModelBuilder.BuildOmegaArchonCaduceusArtifact,
		-- The Gilded Anvil (Tier 8 Gildforged)
		art_gild_dawnwarden_oath = WeaponModelBuilder.BuildDawnwardenOath,
		art_gild_eclipse_sisters = WeaponModelBuilder.BuildEclipseSisters,
		art_gild_aurora_skyhook = WeaponModelBuilder.BuildAuroraSkyhook,
		art_gild_wyrmheart_cleaver = WeaponModelBuilder.BuildWyrmheartCleaver,
		art_gild_ninth_sky_orrery = WeaponModelBuilder.BuildNinthSkyOrrery,
		art_gild_evergarden_codex = WeaponModelBuilder.BuildEvergardenCodex,
		weapon_daggers = WeaponModelBuilder.BuildDaggers,
		weapon_axe = WeaponModelBuilder.BuildAxe,
		weapon_staff = WeaponModelBuilder.BuildStaff,
		weapon_tome = WeaponModelBuilder.BuildTome,
	}

	local result: { [string]: Model } = {}

	-- Warm every uploaded mesh in parallel before building, unless every prefab is already saved in the place.
	for weaponName in builders do
		local existing = weaponsFolder:FindFirstChild(weaponName)
		if not (existing and existing:IsA("Model") and #existing:GetChildren() > 0) then
			local meshIds: { string } = {}
			for _, catalog in { DAGGER_MESH_DATA, AXE_MESH_DATA, STAFF_MESH_DATA, TOME_MESH_DATA, SwordBowMeshData } :: { { [string]: any } } do
				for _, data in catalog do
					for _, part in data.Parts do
						if type(part.MeshId) == "string" and part.MeshId ~= "" then table.insert(meshIds, part.MeshId) end
					end
				end
			end
			prefetchUploadedMeshes(meshIds)
			break
		end
	end

	for weaponName, builderFn in pairs(builders) do
		local existing = weaponsFolder:FindFirstChild(weaponName)
		local isValid = existing and existing:IsA("Model") and #existing:GetChildren() > 0

		if not isValid then
			if existing then
				existing:Destroy()
			end

			local ok, built = pcall(builderFn)
			if ok and built then
				built.Parent = weaponsFolder
				result[weaponName] = built
			else
				warn(string.format("[WeaponModelBuilder] Failed to build %s: %s", weaponName, tostring(built)))
			end
		else
			if weaponName == "weapon_bow" and existing:IsA("Model") then
				local handle = existing:FindFirstChild("Handle") :: BasePart?
				if handle then
					alignHunterArrow(existing, handle)
				end
			end
			-- A staff prefab saved in the place can carry sockets from an older import whose shaft
			-- ran along +Z, which holds the staff sideways. The mesh runs along +Y (head up), so
			-- put the sockets back where STAFF_MESH_DATA says they are.
			local staffData = STAFF_MESH_DATA[weaponName]
			local staffHandle = existing:IsA("Model") and existing.PrimaryPart
			if staffData and staffHandle then
				for socketName, position in { Grip = staffData.GripPos, Tip = staffData.TipPos, VfxTip = staffData.TipPos, VfxBase = staffData.BasePos, VfxCore = staffData.CorePos } do
					local socket = staffHandle:FindFirstChild(socketName)
					if socket and socket:IsA("Attachment") then
						socket.CFrame = CFrame.new(position)
					end
				end
			end
			-- Clean any cross-assembly welds from cached prefabs (e.g. LeftDagger or OffhandShield)
			local leftDagger = existing:FindFirstChild("LeftDagger")
			local shield = existing:FindFirstChild("OffhandShield")
			local sub = leftDagger or shield
			if sub then
				for _, d in ipairs(existing:GetDescendants()) do
					if d:IsA("JointInstance") or d:IsA("WeldConstraint") then
						local p0 = d.Part0
						local p1 = d.Part1
						if p0 and p1 then
							local inSub0 = p0:IsDescendantOf(sub)
							local inSub1 = p1:IsDescendantOf(sub)
							if (inSub0 and not inSub1) or (inSub1 and not inSub0) then
								d:Destroy()
							end
						end
					end
				end
			end
			result[weaponName] = existing :: Model
		end
	end

	return weaponsFolder, result
end

-- Every MeshId the artifact weapon builders use, de-duplicated.
function WeaponModelBuilder.CollectMeshIds(): { string }
	local ids: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, catalog in { DAGGER_MESH_DATA, AXE_MESH_DATA, STAFF_MESH_DATA, TOME_MESH_DATA, SwordBowMeshData } :: { { [string]: any } } do
		for _, data in catalog do
			for _, part in data.Parts do
				local id = part.MeshId
				if type(id) == "string" and id ~= "" and not seen[id] then
					seen[id] = true
					table.insert(ids, id)
				end
			end
		end
	end
	for _, parts in pairs(GildedAnvilMeshData.Weapons) do
		for _, part in ipairs(parts) do
			local id = (part :: any).MeshId
			if type(id) == "string" and id ~= "" and not seen[id] then
				seen[id] = true
				table.insert(ids, id)
			end
		end
	end
	return ids
end

return WeaponModelBuilder