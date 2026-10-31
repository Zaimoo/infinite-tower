--!strict
-- ReplicatedStorage/Assets/WeaponModelBuilder.luau
-- Authoritative Modular 3D Weapon Model Factory & Setup.
-- Populates ReplicatedStorage.Assets.Weapons with modular weapon prefabs:
--   - weapon_bow (Marksman bows: Hunter's Shortbow, Recurve, Crystal Greatbow)
--   - weapon_sword (bare sword prefab, base of weapon_sword_shield)
--   - weapon_sword_shield (Vanguard sword & shield: Broadswords, Claymores, Aegis Core)
--   - weapon_daggers (Striker dual daggers: Rogue Daggers, Shadow Fangs)
--   - weapon_axe (Miner axes: Pickaxe, Battleaxes)
--   - weapon_staff (Scholar staves: Ruby Staff, Archmage Scepter)
--   - weapon_tome (Healer tomes: Pyromancer Tome, Eldritch Grimoire)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WeaponModelBuilder = {}

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

-- Blades and axe heads sit along handle +Y with their edge facing handle +X, so the grip
-- looks along +X (CFrame.Angles(0, -90, 0) turns -Z onto +X and keeps +Y).
local EDGE_PLUS_X = Vector3.new(0, -90, 0)

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
	local pNock = Vector3.new(ARROW_REST.X, ARROW_REST.Y, BOW_STRING_Z)
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

	-- Procedural HunterArrow
	local arrowModel = Instance.new("Model")
	arrowModel.Name = "HunterArrow"
	arrowModel.Parent = model
	makePart(arrowModel, "ArrowShaft", Vector3.new(0.04, 0.04, 2.0), CFrame.new(0, 0, 0), Color3.fromRGB(120, 80, 50))
	makeWedge(arrowModel, "ArrowHead", Vector3.new(0.08, 0.12, 0.28), CFrame.new(0, 0, 0), Color3.fromRGB(90, 85, 80), Enum.Material.Slate)
	makePart(arrowModel, "ArrowFletch_1", Vector3.new(0.01, 0.06, 0.22), CFrame.new(0, 0, 0), Color3.fromRGB(180, 175, 170))
	makePart(arrowModel, "ArrowFletch_2", Vector3.new(0.01, 0.06, 0.22), CFrame.new(0, 0, 0), Color3.fromRGB(60, 55, 50))
	makePart(arrowModel, "ArrowFletch_3", Vector3.new(0.01, 0.06, 0.22), CFrame.new(0, 0, 0), Color3.fromRGB(180, 175, 170))
	alignHunterArrow(model, handle)

	return model
end

-- ============================================================================
-- 2. WEAPON_SWORD (Iron Broadsword / Katana / Greatsword)
-- ============================================================================
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
-- 4. WEAPON_AXE (Prospector's Cleaver / Warforged Battleaxe)
-- ============================================================================
function WeaponModelBuilder.BuildAxe(): Model
	local model = Instance.new("Model")
	model.Name = "weapon_axe"

	local ashwood = Color3.fromRGB(115, 85, 55)
	local iron = Color3.fromRGB(165, 172, 185)
	local gold = Color3.fromRGB(235, 195, 60)

	local handle = makePart(model, "Handle", Vector3.new(0.22, 2.8, 0.22), CFrame.new(0, 0, 0), ashwood)
	model.PrimaryPart = handle

	local pommel = makePart(model, "Pommel", Vector3.new(0.35, 0.3, 0.35), CFrame.new(0, -1.45, 0), iron)
	weldTo(handle, pommel)

	local headCollar = makePart(model, "HeadCollar", Vector3.new(0.38, 0.4, 0.38), CFrame.new(0, 1.1, 0), gold)
	weldTo(handle, headCollar)

	-- Beveled axe blade
	local blade = makePart(model, "Blade", Vector3.new(1.3, 1.2, 0.18), CFrame.new(0.7, 1.1, 0), iron, Enum.Material.Metal)
	weldTo(handle, blade)

	local edge = makeWedge(model, "BladeEdge", Vector3.new(0.18, 1.4, 0.5), CFrame.new(1.4, 1.1, 0) * CFrame.Angles(0, 0, math.rad(-90)), iron, Enum.Material.Metal)
	weldTo(handle, edge)

	-- Counter-spike
	local spike = makeWedge(model, "BackSpike", Vector3.new(0.18, 0.6, 0.4), CFrame.new(-0.4, 1.1, 0) * CFrame.Angles(0, 0, math.rad(90)), iron, Enum.Material.Metal)
	weldTo(handle, spike)

	-- Held near the butt of the haft; OffhandGrip is the second hand for two-handed swings.
	addSocket(handle, "Grip", Vector3.new(0, -0.9, 0), EDGE_PLUS_X)
	addSocket(handle, "OffhandGrip", Vector3.new(0, 0.2, 0), EDGE_PLUS_X)

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
function WeaponModelBuilder.BuildTome(): Model
	local model = Instance.new("Model")
	model.Name = "weapon_tome"

	local leatherRed = Color3.fromRGB(115, 30, 35)
	local parchment = Color3.fromRGB(240, 230, 205)
	local gold = Color3.fromRGB(245, 195, 65)
	local flameNeon = Color3.fromRGB(255, 140, 45)

	-- Spine used as Handle
	local handle = makePart(model, "Handle", Vector3.new(0.28, 1.5, 0.32), CFrame.new(0, 0, 0), leatherRed)
	model.PrimaryPart = handle

	local frontCover = makePart(model, "FrontCover", Vector3.new(1.05, 1.5, 0.06), CFrame.new(0.55, 0, 0.16), leatherRed)
	weldTo(handle, frontCover)

	local backCover = makePart(model, "BackCover", Vector3.new(1.05, 1.5, 0.06), CFrame.new(0.55, 0, -0.16), leatherRed)
	weldTo(handle, backCover)

	local pages = makePart(model, "Pages", Vector3.new(0.95, 1.4, 0.26), CFrame.new(0.52, 0, 0), parchment)
	weldTo(handle, pages)

	local clasp = makePart(model, "Clasp", Vector3.new(0.35, 0.35, 0.1), CFrame.new(1.05, 0, 0.18), gold)
	weldTo(handle, clasp)

	local rune = makePart(model, "TomeRune", Vector3.new(0.4, 0.4, 0.05), CFrame.new(0.55, 0, 0.2), flameNeon, Enum.Material.Neon)
	weldTo(handle, rune)

	addSocket(handle, "Grip", Vector3.zero, Vector3.new(0, 180, 0)) -- up = spine top, look = front cover (+Z)

	return model
end

-- ============================================================================
-- PUBLIC ENSURE API
-- ============================================================================
-- ============================================================================
-- STYLING (shared by every equip path)
-- ============================================================================
-- Per-artifact colour overrides and the rarity glow, applied to a cloned prefab.
function WeaponModelBuilder.Style(wModel: Model, weaponAssetId: string?, rarityIndex: number?)
	if weaponAssetId == "art_crystal_greatbow" then
		for _, p in ipairs(wModel:GetDescendants()) do
			if p:IsA("BasePart") then
				if p.Name:find("Limb") or p.Name:find("Seg") or p.Name:find("Core") or p.Name:find("Tip") then
					p.Material = Enum.Material.Neon
					p.Color = Color3.fromRGB(80, 225, 255)
				elseif p.Name:find("Band") or p.Name:find("Wrap") or p.Name:find("Rope") then
					p.Material = Enum.Material.SmoothPlastic
					p.Color = Color3.fromRGB(220, 240, 255)
				end
			end
		end
	elseif weaponAssetId == "art_recurve_composite" then
		for _, p in ipairs(wModel:GetDescendants()) do
			if p:IsA("BasePart") then
				if p.Name:find("Limb") or p.Name:find("Seg") or p.Name:find("Riser") then
					p.Material = Enum.Material.Wood
					p.Color = Color3.fromRGB(115, 75, 45)
				elseif p.Name:find("Band") or p.Name:find("Wrap") then
					p.Material = Enum.Material.SmoothPlastic
					p.Color = Color3.fromRGB(45, 35, 30)
				end
			end
		end
	elseif weaponAssetId == "art_iron_broadsword" then
		for _, p in ipairs(wModel:GetDescendants()) do
			if p:IsA("BasePart") then
				if p.Name:find("Blade") or p.Name:find("Tip") or p.Name:find("PommelCap") or p.Name:find("ShieldBoss") then
					p.Material = Enum.Material.Metal
					p.Color = Color3.fromRGB(212, 216, 223)
				elseif p.Name:find("Fuller") or p.Name:find("Ricasso") or p.Name:find("Crossguard") or p.Name:find("Guard") or p.Name:find("Pommel") or p.Name:find("Ferrule") or p.Name:find("ShieldPlate") or p.Name:find("HandleS") then
					p.Material = Enum.Material.Metal
					p.Color = Color3.fromRGB(140, 146, 158)
				elseif p.Name == "Handle" then
					p.Material = Enum.Material.SmoothPlastic
					p.Color = Color3.fromRGB(30, 29, 36)
				end
			end
		end
	end

	-- Rarity flair: Legendary+ weapons (rarity >= 14) glow in their rarity colour.
	if rarityIndex and rarityIndex >= 14 then
		local Shared = ReplicatedStorage:FindFirstChild("Shared")
		local ArtifactCatalog = Shared and require(Shared:WaitForChild("Config"):WaitForChild("ArtifactCatalog")) :: any
		local rInfo = ArtifactCatalog and ArtifactCatalog.GetRarityInfo(rarityIndex)
		if rInfo then
			for _, p in ipairs(wModel:GetDescendants()) do
				if p:IsA("BasePart") and (p.Name:find("Blade") or p.Name:find("Tip") or p.Name:find("Orb") or p.Name:find("Crystal")) then
					p.Material = Enum.Material.Neon
					p.Color = rInfo.Color
				end
			end
		end
	end
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
		weapon_sword = WeaponModelBuilder.BuildSword,
		weapon_sword_shield = WeaponModelBuilder.BuildSwordShield,
		weapon_iron_broadsword = WeaponModelBuilder.BuildIronBroadsword,
		weapon_daggers = WeaponModelBuilder.BuildDaggers,
		weapon_axe = WeaponModelBuilder.BuildAxe,
		weapon_staff = WeaponModelBuilder.BuildStaff,
		weapon_tome = WeaponModelBuilder.BuildTome,
	}

	local result: { [string]: Model } = {}

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
			result[weaponName] = existing :: Model
		end
	end

	return weaponsFolder, result
end

return WeaponModelBuilder