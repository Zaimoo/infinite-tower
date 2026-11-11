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
	local model = Instance.new("Model")
	model.Name = "art_hunters_shortbow"

	local woodAsh = Color3.fromRGB(155, 115, 75)
	local woodTaper = Color3.fromRGB(140, 105, 65)
	local leatherBrown = Color3.fromRGB(90, 60, 35)
	local boneWhite = Color3.fromRGB(235, 230, 215)
	local brassGold = Color3.fromRGB(195, 155, 75)
	local hornDark = Color3.fromRGB(45, 40, 38)
	local stringColor = Color3.fromRGB(225, 215, 195)

	-- Contoured Ash Riser & Arrow Rest
	local handle = makePart(model, "Handle", Vector3.new(0.24, 0.70, 0.28), CFrame.new(0, 0, 0), woodAsh, Enum.Material.Wood)
	model.PrimaryPart = handle

	local shelf = makePart(model, "ArrowShelf_Bone", Vector3.new(0.08, 0.12, 0.18), CFrame.new(0.14, 0.10, -0.06), boneWhite, Enum.Material.SmoothPlastic)
	weldTo(handle, shelf)

	-- Leather Grip Wrap Bands & Brass Collars
	local wrap1 = makePart(model, "GripWrap_1", Vector3.new(0.26, 0.12, 0.30), CFrame.new(0, 0.18, 0), leatherBrown, Enum.Material.Fabric)
	weldTo(handle, wrap1)
	local wrap2 = makePart(model, "GripWrap_2", Vector3.new(0.27, 0.12, 0.31), CFrame.new(0, 0.06, 0), leatherBrown, Enum.Material.Fabric)
	weldTo(handle, wrap2)
	local wrap3 = makePart(model, "GripWrap_3", Vector3.new(0.27, 0.12, 0.31), CFrame.new(0, -0.06, 0), leatherBrown, Enum.Material.Fabric)
	weldTo(handle, wrap3)
	local wrap4 = makePart(model, "GripWrap_4", Vector3.new(0.26, 0.12, 0.30), CFrame.new(0, -0.18, 0), leatherBrown, Enum.Material.Fabric)
	weldTo(handle, wrap4)
	local collarTop = makePart(model, "GripCollar_Top", Vector3.new(0.26, 0.05, 0.30), CFrame.new(0, 0.28, 0), brassGold, Enum.Material.Metal)
	weldTo(handle, collarTop)
	local collarBot = makePart(model, "GripCollar_Bot", Vector3.new(0.26, 0.05, 0.30), CFrame.new(0, -0.28, 0), brassGold, Enum.Material.Metal)
	weldTo(handle, collarBot)

	-- Upper Limb: 4 curved & tapered ash segments
	local lu1 = makePart(model, "LimbU_1", Vector3.new(0.22, 0.38, 0.24), CFrame.new(0, 0.50, 0.03) * CFrame.Angles(math.rad(7), 0, 0), woodAsh, Enum.Material.Wood)
	weldTo(handle, lu1)
	local lu2 = makePart(model, "LimbU_2", Vector3.new(0.20, 0.38, 0.22), CFrame.new(0, 0.84, 0.10) * CFrame.Angles(math.rad(15), 0, 0), woodAsh, Enum.Material.Wood)
	weldTo(handle, lu2)
	local lu3 = makePart(model, "LimbU_3", Vector3.new(0.18, 0.38, 0.20), CFrame.new(0, 1.18, 0.22) * CFrame.Angles(math.rad(24), 0, 0), woodTaper, Enum.Material.Wood)
	weldTo(handle, lu3)
	local lu4 = makePart(model, "LimbU_4", Vector3.new(0.16, 0.40, 0.18), CFrame.new(0, 1.50, 0.38) * CFrame.Angles(math.rad(34), 0, 0), woodTaper, Enum.Material.Wood)
	weldTo(handle, lu4)

	-- Lower Limb: 4 curved & tapered ash segments
	local ll1 = makePart(model, "LimbL_1", Vector3.new(0.22, 0.38, 0.24), CFrame.new(0, -0.50, 0.03) * CFrame.Angles(-math.rad(7), 0, 0), woodAsh, Enum.Material.Wood)
	weldTo(handle, ll1)
	local ll2 = makePart(model, "LimbL_2", Vector3.new(0.20, 0.38, 0.22), CFrame.new(0, -0.84, 0.10) * CFrame.Angles(-math.rad(15), 0, 0), woodAsh, Enum.Material.Wood)
	weldTo(handle, ll2)
	local ll3 = makePart(model, "LimbL_3", Vector3.new(0.18, 0.38, 0.20), CFrame.new(0, -1.18, 0.22) * CFrame.Angles(-math.rad(24), 0, 0), woodTaper, Enum.Material.Wood)
	weldTo(handle, ll3)
	local ll4 = makePart(model, "LimbL_4", Vector3.new(0.16, 0.40, 0.18), CFrame.new(0, -1.50, 0.38) * CFrame.Angles(-math.rad(34), 0, 0), woodTaper, Enum.Material.Wood)
	weldTo(handle, ll4)

	-- Horn Tip Nocks
	local tipUpper = makePart(model, "TipNock_Upper", Vector3.new(0.14, 0.22, 0.18), CFrame.new(0, 1.72, 0.50) * CFrame.Angles(math.rad(42), 0, 0), hornDark, Enum.Material.Slate)
	weldTo(handle, tipUpper)
	local tipLower = makePart(model, "TipNock_Lower", Vector3.new(0.14, 0.22, 0.18), CFrame.new(0, -1.72, 0.50) * CFrame.Angles(-math.rad(42), 0, 0), hornDark, Enum.Material.Slate)
	weldTo(handle, tipLower)

	-- Bowstring
	local bowString = makePart(model, "BowString", Vector3.new(0.04, 3.50, 0.04), CFrame.new(0, 0, 0.52), stringColor, Enum.Material.Fabric)
	weldTo(handle, bowString)

	addSocket(handle, "Grip", Vector3.zero)
	addSocket(handle, "Nock", Vector3.new(ARROW_REST.X, ARROW_REST.Y, 0.52))
	addSocket(handle, "TipUpper", Vector3.new(0, 1.75, 0.52))
	addSocket(handle, "TipLower", Vector3.new(0, -1.75, 0.52))
	addSocket(handle, "VfxTip", Vector3.new(0, 1.75, 0.52))
	addSocket(handle, "VfxBase", Vector3.new(0, -1.75, 0.52))
	addSocket(handle, "VfxCore", Vector3.zero)
	addSocket(handle, "VfxNock", Vector3.new(ARROW_REST.X, ARROW_REST.Y, 0.52))

	createHunterArrow(model, handle)
	return model
end

-- ============================================================================
-- 2. Reinforced Longbow (art_reinforced_longbow) - Common Enhanced
-- ============================================================================
function WeaponModelBuilder.BuildReinforcedLongbow(): Model
	local model = Instance.new("Model")
	model.Name = "art_reinforced_longbow"

	local woodYew = Color3.fromRGB(120, 55, 30)
	local woodAsh = Color3.fromRGB(150, 105, 65)
	local ironDark = Color3.fromRGB(65, 68, 72)
	local ironRivet = Color3.fromRGB(140, 145, 150)
	local hornBlack = Color3.fromRGB(30, 28, 26)
	local stringColor = Color3.fromRGB(230, 225, 210)

	-- Yew Riser
	local handle = makePart(model, "Handle", Vector3.new(0.26, 0.76, 0.30), CFrame.new(0, 0, 0), woodYew, Enum.Material.Wood)
	model.PrimaryPart = handle

	-- Wrought Iron Riser Sleeves & Rivets
	local sleeve1 = makePart(model, "IronSleeve_1", Vector3.new(0.28, 0.10, 0.32), CFrame.new(0, 0.22, 0), ironDark, Enum.Material.Metal)
	weldTo(handle, sleeve1)
	local rivet1 = makePart(model, "Rivet_1", Vector3.new(0.30, 0.05, 0.08), CFrame.new(0, 0.22, 0.14), ironRivet, Enum.Material.Metal)
	weldTo(handle, rivet1)
	local sleeve2 = makePart(model, "IronSleeve_2", Vector3.new(0.29, 0.10, 0.33), CFrame.new(0, 0.08, 0), ironDark, Enum.Material.Metal)
	weldTo(handle, sleeve2)
	local rivet2 = makePart(model, "Rivet_2", Vector3.new(0.31, 0.05, 0.08), CFrame.new(0, 0.08, 0.15), ironRivet, Enum.Material.Metal)
	weldTo(handle, rivet2)
	local sleeve3 = makePart(model, "IronSleeve_3", Vector3.new(0.29, 0.10, 0.33), CFrame.new(0, -0.08, 0), ironDark, Enum.Material.Metal)
	weldTo(handle, sleeve3)
	local rivet3 = makePart(model, "Rivet_3", Vector3.new(0.31, 0.05, 0.08), CFrame.new(0, -0.08, 0.15), ironRivet, Enum.Material.Metal)
	weldTo(handle, rivet3)
	local sleeve4 = makePart(model, "IronSleeve_4", Vector3.new(0.28, 0.10, 0.32), CFrame.new(0, -0.22, 0), ironDark, Enum.Material.Metal)
	weldTo(handle, sleeve4)
	local rivet4 = makePart(model, "Rivet_4", Vector3.new(0.30, 0.05, 0.08), CFrame.new(0, -0.22, 0.14), ironRivet, Enum.Material.Metal)
	weldTo(handle, rivet4)

	local arrowPlate = makePart(model, "IronArrowPlate", Vector3.new(0.08, 0.14, 0.18), CFrame.new(0.15, 0.10, -0.07), ironDark, Enum.Material.Metal)
	weldTo(handle, arrowPlate)

	-- Upper Limb: 5 tapered ash/yew segments with progressive pitch
	local lu1 = makePart(model, "LimbU_1", Vector3.new(0.24, 0.38, 0.26), CFrame.new(0, 0.52, 0.02) * CFrame.Angles(math.rad(5), 0, 0), woodAsh, Enum.Material.Wood)
	weldTo(handle, lu1)
	local lu2 = makePart(model, "LimbU_2", Vector3.new(0.22, 0.38, 0.24), CFrame.new(0, 0.88, 0.07) * CFrame.Angles(math.rad(11), 0, 0), woodAsh, Enum.Material.Wood)
	weldTo(handle, lu2)
	local lu3 = makePart(model, "LimbU_3", Vector3.new(0.20, 0.38, 0.22), CFrame.new(0, 1.23, 0.16) * CFrame.Angles(math.rad(18), 0, 0), woodYew, Enum.Material.Wood)
	weldTo(handle, lu3)
	local lu4 = makePart(model, "LimbU_4", Vector3.new(0.18, 0.38, 0.20), CFrame.new(0, 1.56, 0.29) * CFrame.Angles(math.rad(26), 0, 0), woodYew, Enum.Material.Wood)
	weldTo(handle, lu4)
	local lu5 = makePart(model, "LimbU_5", Vector3.new(0.16, 0.40, 0.18), CFrame.new(0, 1.88, 0.45) * CFrame.Angles(math.rad(35), 0, 0), woodYew, Enum.Material.Wood)
	weldTo(handle, lu5)
	local limbBandU = makePart(model, "LimbBand_U", Vector3.new(0.22, 0.06, 0.24), CFrame.new(0, 1.23, 0.16) * CFrame.Angles(math.rad(18), 0, 0), ironDark, Enum.Material.Metal)
	weldTo(handle, limbBandU)

	-- Lower Limb: 5 tapered ash/yew segments
	local ll1 = makePart(model, "LimbL_1", Vector3.new(0.24, 0.38, 0.26), CFrame.new(0, -0.52, 0.02) * CFrame.Angles(-math.rad(5), 0, 0), woodAsh, Enum.Material.Wood)
	weldTo(handle, ll1)
	local ll2 = makePart(model, "LimbL_2", Vector3.new(0.22, 0.38, 0.24), CFrame.new(0, -0.88, 0.07) * CFrame.Angles(-math.rad(11), 0, 0), woodAsh, Enum.Material.Wood)
	weldTo(handle, ll2)
	local ll3 = makePart(model, "LimbL_3", Vector3.new(0.20, 0.38, 0.22), CFrame.new(0, -1.23, 0.16) * CFrame.Angles(-math.rad(18), 0, 0), woodYew, Enum.Material.Wood)
	weldTo(handle, ll3)
	local ll4 = makePart(model, "LimbL_4", Vector3.new(0.18, 0.38, 0.20), CFrame.new(0, -1.56, 0.29) * CFrame.Angles(-math.rad(26), 0, 0), woodYew, Enum.Material.Wood)
	weldTo(handle, ll4)
	local ll5 = makePart(model, "LimbL_5", Vector3.new(0.16, 0.40, 0.18), CFrame.new(0, -1.88, 0.45) * CFrame.Angles(-math.rad(35), 0, 0), woodYew, Enum.Material.Wood)
	weldTo(handle, ll5)
	local limbBandL = makePart(model, "LimbBand_L", Vector3.new(0.22, 0.06, 0.24), CFrame.new(0, -1.23, 0.16) * CFrame.Angles(-math.rad(18), 0, 0), ironDark, Enum.Material.Metal)
	weldTo(handle, limbBandL)

	-- Buffalo Horn 2-Piece Nocks
	local hornBaseU = makePart(model, "HornNock_U1", Vector3.new(0.15, 0.18, 0.17), CFrame.new(0, 2.06, 0.58) * CFrame.Angles(math.rad(44), 0, 0), hornBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, hornBaseU)
	local hornTipU = makePart(model, "HornNock_U2", Vector3.new(0.12, 0.16, 0.14), CFrame.new(0, 2.18, 0.68) * CFrame.Angles(math.rad(52), 0, 0), hornBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, hornTipU)
	local hornBaseL = makePart(model, "HornNock_L1", Vector3.new(0.15, 0.18, 0.17), CFrame.new(0, -2.06, 0.58) * CFrame.Angles(-math.rad(44), 0, 0), hornBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, hornBaseL)
	local hornTipL = makePart(model, "HornNock_L2", Vector3.new(0.12, 0.16, 0.14), CFrame.new(0, -2.18, 0.68) * CFrame.Angles(-math.rad(52), 0, 0), hornBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, hornTipL)

	-- Waxed Linen Bowstring
	local bowString = makePart(model, "BowString", Vector3.new(0.045, 4.30, 0.045), CFrame.new(0, 0, 0.68), stringColor, Enum.Material.Fabric)
	weldTo(handle, bowString)

	addSocket(handle, "Grip", Vector3.zero)
	addSocket(handle, "Nock", Vector3.new(ARROW_REST.X, ARROW_REST.Y, 0.68))
	addSocket(handle, "TipUpper", Vector3.new(0, 2.18, 0.68))
	addSocket(handle, "TipLower", Vector3.new(0, -2.18, 0.68))
	addSocket(handle, "VfxTip", Vector3.new(0, 2.18, 0.68))
	addSocket(handle, "VfxBase", Vector3.new(0, -2.18, 0.68))
	addSocket(handle, "VfxCore", Vector3.zero)
	addSocket(handle, "VfxNock", Vector3.new(ARROW_REST.X, ARROW_REST.Y, 0.68))

	createHunterArrow(model, handle)
	return model
end

-- ============================================================================
-- 3. Recurve Composite (art_recurve_composite) - Uncommon Standard
-- ============================================================================
function WeaponModelBuilder.BuildRecurveComposite(): Model
	local model = Instance.new("Model")
	model.Name = "art_recurve_composite"

	local hornBelly = Color3.fromRGB(50, 42, 36)
	local birchBack = Color3.fromRGB(195, 175, 140)
	local boneWhite = Color3.fromRGB(240, 235, 220)
	local raySkin = Color3.fromRGB(60, 80, 75)
	local goldAccent = Color3.fromRGB(210, 170, 80)
	local stringColor = Color3.fromRGB(245, 240, 230)

	-- Ray-skin Wrapped Riser
	local handle = makePart(model, "Handle", Vector3.new(0.24, 0.68, 0.28), CFrame.new(0, 0, 0), raySkin, Enum.Material.SmoothPlastic)
	model.PrimaryPart = handle

	local collarTop = makePart(model, "HandleCollar_Top", Vector3.new(0.26, 0.06, 0.30), CFrame.new(0, 0.26, 0), goldAccent, Enum.Material.Metal)
	weldTo(handle, collarTop)
	local collarBot = makePart(model, "HandleCollar_Bot", Vector3.new(0.26, 0.06, 0.30), CFrame.new(0, -0.26, 0), goldAccent, Enum.Material.Metal)
	weldTo(handle, collarBot)
	local arrowRest = makePart(model, "BoneArrowRest", Vector3.new(0.08, 0.12, 0.16), CFrame.new(0.14, 0.08, -0.06), boneWhite, Enum.Material.SmoothPlastic)
	weldTo(handle, arrowRest)
	local hornWedgeU = makePart(model, "GripWedge_U", Vector3.new(0.18, 0.10, 0.22), CFrame.new(0, 0.32, 0.04), hornBelly, Enum.Material.SmoothPlastic)
	weldTo(handle, hornWedgeU)
	local hornWedgeL = makePart(model, "GripWedge_L", Vector3.new(0.18, 0.10, 0.22), CFrame.new(0, -0.32, 0.04), hornBelly, Enum.Material.SmoothPlastic)
	weldTo(handle, hornWedgeL)

	-- Upper Limb: Steppe Reflex-Recurve (reflex forward then recurve back)
	local ru1 = makePart(model, "LimbU_Reflex1", Vector3.new(0.22, 0.32, 0.22), CFrame.new(0, 0.46, -0.03) * CFrame.Angles(-math.rad(6), 0, 0), birchBack, Enum.Material.Wood)
	weldTo(handle, ru1)
	local ru2 = makePart(model, "LimbU_Reflex2", Vector3.new(0.20, 0.32, 0.20), CFrame.new(0, 0.74, -0.08) * CFrame.Angles(-math.rad(12), 0, 0), birchBack, Enum.Material.Wood)
	weldTo(handle, ru2)
	local ru3 = makePart(model, "LimbU_Knee", Vector3.new(0.19, 0.30, 0.19), CFrame.new(0, 1.02, -0.07) * CFrame.Angles(math.rad(8), 0, 0), hornBelly, Enum.Material.SmoothPlastic)
	weldTo(handle, ru3)
	local ru4 = makePart(model, "LimbU_Recurve1", Vector3.new(0.18, 0.32, 0.18), CFrame.new(0, 1.28, 0.06) * CFrame.Angles(math.rad(26), 0, 0), birchBack, Enum.Material.Wood)
	weldTo(handle, ru4)
	local ru5 = makePart(model, "LimbU_Recurve2", Vector3.new(0.16, 0.32, 0.16), CFrame.new(0, 1.54, 0.26) * CFrame.Angles(math.rad(40), 0, 0), birchBack, Enum.Material.Wood)
	weldTo(handle, ru5)

	-- Upper Horn Belly Laminate Plates
	local bellyU1 = makePart(model, "BellyPlate_U1", Vector3.new(0.16, 0.40, 0.04), CFrame.new(0, 0.60, 0.08) * CFrame.Angles(-math.rad(8), 0, 0), hornBelly, Enum.Material.SmoothPlastic)
	weldTo(handle, bellyU1)
	local bellyU2 = makePart(model, "BellyPlate_U2", Vector3.new(0.15, 0.40, 0.04), CFrame.new(0, 1.38, 0.22) * CFrame.Angles(math.rad(30), 0, 0), hornBelly, Enum.Material.SmoothPlastic)
	weldTo(handle, bellyU2)
	local stringPadU = makePart(model, "StringPad_U", Vector3.new(0.10, 0.12, 0.06), CFrame.new(0, 1.64, 0.34) * CFrame.Angles(math.rad(45), 0, 0), hornBelly, Enum.Material.SmoothPlastic)
	weldTo(handle, stringPadU)

	-- Lower Limb: Steppe Reflex-Recurve
	local rl1 = makePart(model, "LimbL_Reflex1", Vector3.new(0.22, 0.32, 0.22), CFrame.new(0, -0.46, -0.03) * CFrame.Angles(math.rad(6), 0, 0), birchBack, Enum.Material.Wood)
	weldTo(handle, rl1)
	local rl2 = makePart(model, "LimbL_Reflex2", Vector3.new(0.20, 0.32, 0.20), CFrame.new(0, -0.74, -0.08) * CFrame.Angles(math.rad(12), 0, 0), birchBack, Enum.Material.Wood)
	weldTo(handle, rl2)
	local rl3 = makePart(model, "LimbL_Knee", Vector3.new(0.19, 0.30, 0.19), CFrame.new(0, -1.02, -0.07) * CFrame.Angles(-math.rad(8), 0, 0), hornBelly, Enum.Material.SmoothPlastic)
	weldTo(handle, rl3)
	local rl4 = makePart(model, "LimbL_Recurve1", Vector3.new(0.18, 0.32, 0.18), CFrame.new(0, -1.28, 0.06) * CFrame.Angles(-math.rad(26), 0, 0), birchBack, Enum.Material.Wood)
	weldTo(handle, rl4)
	local rl5 = makePart(model, "LimbL_Recurve2", Vector3.new(0.16, 0.32, 0.16), CFrame.new(0, -1.54, 0.26) * CFrame.Angles(-math.rad(40), 0, 0), birchBack, Enum.Material.Wood)
	weldTo(handle, rl5)

	-- Lower Horn Belly Laminate Plates
	local bellyL1 = makePart(model, "BellyPlate_L1", Vector3.new(0.16, 0.40, 0.04), CFrame.new(0, -0.60, 0.08) * CFrame.Angles(math.rad(8), 0, 0), hornBelly, Enum.Material.SmoothPlastic)
	weldTo(handle, bellyL1)
	local bellyL2 = makePart(model, "BellyPlate_L2", Vector3.new(0.15, 0.40, 0.04), CFrame.new(0, -1.38, 0.22) * CFrame.Angles(-math.rad(30), 0, 0), hornBelly, Enum.Material.SmoothPlastic)
	weldTo(handle, bellyL2)
	local stringPadL = makePart(model, "StringPad_L", Vector3.new(0.10, 0.12, 0.06), CFrame.new(0, -1.64, 0.34) * CFrame.Angles(-math.rad(45), 0, 0), hornBelly, Enum.Material.SmoothPlastic)
	weldTo(handle, stringPadL)

	-- Bone Syyahs (Static Ears) & String Bridges
	local syyahBaseU = makePart(model, "SyyahU_Base", Vector3.new(0.14, 0.24, 0.14), CFrame.new(0, 1.76, 0.44) * CFrame.Angles(math.rad(50), 0, 0), boneWhite, Enum.Material.SmoothPlastic)
	weldTo(handle, syyahBaseU)
	local syyahBladeU = makePart(model, "SyyahU_Blade", Vector3.new(0.10, 0.26, 0.12), CFrame.new(0, 1.94, 0.58) * CFrame.Angles(math.rad(58), 0, 0), boneWhite, Enum.Material.SmoothPlastic)
	weldTo(handle, syyahBladeU)
	local bridgeU = makePart(model, "StringBridge_U", Vector3.new(0.08, 0.06, 0.10), CFrame.new(0, 1.82, 0.48), goldAccent, Enum.Material.Metal)
	weldTo(handle, bridgeU)

	local syyahBaseL = makePart(model, "SyyahL_Base", Vector3.new(0.14, 0.24, 0.14), CFrame.new(0, -1.76, 0.44) * CFrame.Angles(-math.rad(50), 0, 0), boneWhite, Enum.Material.SmoothPlastic)
	weldTo(handle, syyahBaseL)
	local syyahBladeL = makePart(model, "SyyahL_Blade", Vector3.new(0.10, 0.26, 0.12), CFrame.new(0, -1.94, 0.58) * CFrame.Angles(-math.rad(58), 0, 0), boneWhite, Enum.Material.SmoothPlastic)
	weldTo(handle, syyahBladeL)
	local bridgeL = makePart(model, "StringBridge_L", Vector3.new(0.08, 0.06, 0.10), CFrame.new(0, -1.82, 0.48), goldAccent, Enum.Material.Metal)
	weldTo(handle, bridgeL)

	-- Bowstring
	local bowString = makePart(model, "BowString", Vector3.new(0.045, 3.86, 0.045), CFrame.new(0, 0, 0.58), stringColor, Enum.Material.Fabric)
	weldTo(handle, bowString)

	addSocket(handle, "Grip", Vector3.zero)
	addSocket(handle, "Nock", Vector3.new(ARROW_REST.X, ARROW_REST.Y, 0.58))
	addSocket(handle, "TipUpper", Vector3.new(0, 1.94, 0.58))
	addSocket(handle, "TipLower", Vector3.new(0, -1.94, 0.58))
	addSocket(handle, "VfxTip", Vector3.new(0, 1.94, 0.58))
	addSocket(handle, "VfxBase", Vector3.new(0, -1.94, 0.58))
	addSocket(handle, "VfxCore", Vector3.zero)
	addSocket(handle, "VfxNock", Vector3.new(ARROW_REST.X, ARROW_REST.Y, 0.58))

	createHunterArrow(model, handle)
	return model
end

-- ============================================================================
-- 4. Gale Force Composite (art_gale_force_composite) - Uncommon Enhanced
-- ============================================================================
function WeaponModelBuilder.BuildGaleForceComposite(): Model
	local model = Instance.new("Model")
	model.Name = "art_gale_force_composite"

	local jadeGreen = Color3.fromRGB(60, 145, 110)
	local jadePale = Color3.fromRGB(115, 185, 150)
	local silverMetal = Color3.fromRGB(220, 230, 235)
	local aeroTeal = Color3.fromRGB(40, 105, 95)
	local stringColor = Color3.fromRGB(215, 245, 240)

	-- Aerodynamic Cutaway Riser
	local handle = makePart(model, "Handle", Vector3.new(0.24, 0.72, 0.30), CFrame.new(0, 0, 0), aeroTeal, Enum.Material.SmoothPlastic)
	model.PrimaryPart = handle

	-- Jade Silk Wraps & Silver Ferrules
	local wrap1 = makePart(model, "JadeWrap_1", Vector3.new(0.26, 0.10, 0.32), CFrame.new(0, 0.20, 0), jadeGreen, Enum.Material.Fabric)
	weldTo(handle, wrap1)
	local wrap2 = makePart(model, "JadeWrap_2", Vector3.new(0.27, 0.10, 0.33), CFrame.new(0, 0.07, 0), jadeGreen, Enum.Material.Fabric)
	weldTo(handle, wrap2)
	local wrap3 = makePart(model, "JadeWrap_3", Vector3.new(0.27, 0.10, 0.33), CFrame.new(0, -0.07, 0), jadeGreen, Enum.Material.Fabric)
	weldTo(handle, wrap3)
	local wrap4 = makePart(model, "JadeWrap_4", Vector3.new(0.26, 0.10, 0.32), CFrame.new(0, -0.20, 0), jadeGreen, Enum.Material.Fabric)
	weldTo(handle, wrap4)

	local ferruleTop = makePart(model, "Ferrule_Top", Vector3.new(0.26, 0.05, 0.32), CFrame.new(0, 0.28, 0), silverMetal, Enum.Material.Metal)
	weldTo(handle, ferruleTop)
	local ferruleBot = makePart(model, "Ferrule_Bot", Vector3.new(0.26, 0.05, 0.32), CFrame.new(0, -0.28, 0), silverMetal, Enum.Material.Metal)
	weldTo(handle, ferruleBot)
	local ringTop = makePart(model, "JadeRing_Top", Vector3.new(0.27, 0.03, 0.33), CFrame.new(0, 0.32, 0), jadePale, Enum.Material.SmoothPlastic)
	weldTo(handle, ringTop)
	local ringBot = makePart(model, "JadeRing_Bot", Vector3.new(0.27, 0.03, 0.33), CFrame.new(0, -0.32, 0), jadePale, Enum.Material.SmoothPlastic)
	weldTo(handle, ringBot)
	local windVane = makePart(model, "WindArrowShelf", Vector3.new(0.08, 0.14, 0.18), CFrame.new(0.14, 0.09, -0.07), silverMetal, Enum.Material.Metal)
	weldTo(handle, windVane)

	-- Upper Aero Limbs: 5 tapered jade segments
	local lu1 = makePart(model, "LimbU_1", Vector3.new(0.22, 0.34, 0.22), CFrame.new(0, 0.48, -0.02) * CFrame.Angles(-math.rad(4), 0, 0), jadeGreen, Enum.Material.SmoothPlastic)
	weldTo(handle, lu1)
	local lu2 = makePart(model, "LimbU_2", Vector3.new(0.20, 0.34, 0.20), CFrame.new(0, 0.78, -0.05) * CFrame.Angles(-math.rad(10), 0, 0), jadeGreen, Enum.Material.SmoothPlastic)
	weldTo(handle, lu2)
	local lu3 = makePart(model, "LimbU_3", Vector3.new(0.18, 0.34, 0.18), CFrame.new(0, 1.08, -0.02) * CFrame.Angles(math.rad(10), 0, 0), jadePale, Enum.Material.SmoothPlastic)
	weldTo(handle, lu3)
	local lu4 = makePart(model, "LimbU_4", Vector3.new(0.16, 0.34, 0.16), CFrame.new(0, 1.36, 0.13) * CFrame.Angles(math.rad(28), 0, 0), jadePale, Enum.Material.SmoothPlastic)
	weldTo(handle, lu4)
	local lu5 = makePart(model, "LimbU_5", Vector3.new(0.14, 0.34, 0.14), CFrame.new(0, 1.62, 0.34) * CFrame.Angles(math.rad(44), 0, 0), jadePale, Enum.Material.SmoothPlastic)
	weldTo(handle, lu5)

	-- Upper Raised Dorsal Ribs
	local ribU1 = makePart(model, "DorsalRib_U1", Vector3.new(0.06, 0.36, 0.08), CFrame.new(0, 0.78, -0.12) * CFrame.Angles(-math.rad(10), 0, 0), silverMetal, Enum.Material.Metal)
	weldTo(handle, ribU1)
	local ribU2 = makePart(model, "DorsalRib_U2", Vector3.new(0.05, 0.36, 0.08), CFrame.new(0, 1.36, 0.06) * CFrame.Angles(math.rad(28), 0, 0), silverMetal, Enum.Material.Metal)
	weldTo(handle, ribU2)

	-- Swept Falcon Winglet Vanes (Upper)
	local wingU1 = makePart(model, "Winglet_U1", Vector3.new(0.04, 0.22, 0.16), CFrame.new(0.10, 1.12, 0.04) * CFrame.Angles(math.rad(18), math.rad(20), 0), silverMetal, Enum.Material.Metal)
	weldTo(handle, wingU1)
	local wingU2 = makePart(model, "Winglet_U2", Vector3.new(0.04, 0.22, 0.16), CFrame.new(-0.10, 1.12, 0.04) * CFrame.Angles(math.rad(18), -math.rad(20), 0), silverMetal, Enum.Material.Metal)
	weldTo(handle, wingU2)

	-- Lower Aero Limbs: 5 tapered jade segments
	local ll1 = makePart(model, "LimbL_1", Vector3.new(0.22, 0.34, 0.22), CFrame.new(0, -0.48, -0.02) * CFrame.Angles(math.rad(4), 0, 0), jadeGreen, Enum.Material.SmoothPlastic)
	weldTo(handle, ll1)
	local ll2 = makePart(model, "LimbL_2", Vector3.new(0.20, 0.34, 0.20), CFrame.new(0, -0.78, -0.05) * CFrame.Angles(math.rad(10), 0, 0), jadeGreen, Enum.Material.SmoothPlastic)
	weldTo(handle, ll2)
	local ll3 = makePart(model, "LimbL_3", Vector3.new(0.18, 0.34, 0.18), CFrame.new(0, -1.08, -0.02) * CFrame.Angles(-math.rad(10), 0, 0), jadePale, Enum.Material.SmoothPlastic)
	weldTo(handle, ll3)
	local ll4 = makePart(model, "LimbL_4", Vector3.new(0.16, 0.34, 0.16), CFrame.new(0, -1.36, 0.13) * CFrame.Angles(-math.rad(28), 0, 0), jadePale, Enum.Material.SmoothPlastic)
	weldTo(handle, ll4)
	local ll5 = makePart(model, "LimbL_5", Vector3.new(0.14, 0.34, 0.14), CFrame.new(0, -1.62, 0.34) * CFrame.Angles(-math.rad(44), 0, 0), jadePale, Enum.Material.SmoothPlastic)
	weldTo(handle, ll5)

	-- Lower Raised Dorsal Ribs
	local ribL1 = makePart(model, "DorsalRib_L1", Vector3.new(0.06, 0.36, 0.08), CFrame.new(0, -0.78, -0.12) * CFrame.Angles(math.rad(10), 0, 0), silverMetal, Enum.Material.Metal)
	weldTo(handle, ribL1)
	local ribL2 = makePart(model, "DorsalRib_L2", Vector3.new(0.05, 0.36, 0.08), CFrame.new(0, -1.36, 0.06) * CFrame.Angles(-math.rad(28), 0, 0), silverMetal, Enum.Material.Metal)
	weldTo(handle, ribL2)

	-- Swept Falcon Winglet Vanes (Lower)
	local wingL1 = makePart(model, "Winglet_L1", Vector3.new(0.04, 0.22, 0.16), CFrame.new(0.10, -1.12, 0.04) * CFrame.Angles(-math.rad(18), math.rad(20), 0), silverMetal, Enum.Material.Metal)
	weldTo(handle, wingL1)
	local wingL2 = makePart(model, "Winglet_L2", Vector3.new(0.04, 0.22, 0.16), CFrame.new(-0.10, -1.12, 0.04) * CFrame.Angles(-math.rad(18), -math.rad(20), 0), silverMetal, Enum.Material.Metal)
	weldTo(handle, wingL2)

	-- Silver Falcon-Beak Tips
	local beakBaseU = makePart(model, "BeakTip_U1", Vector3.new(0.14, 0.22, 0.14), CFrame.new(0, 1.84, 0.48) * CFrame.Angles(math.rad(52), 0, 0), silverMetal, Enum.Material.Metal)
	weldTo(handle, beakBaseU)
	local beakTipU = makePart(model, "BeakTip_U2", Vector3.new(0.10, 0.22, 0.12), CFrame.new(0, 1.98, 0.60) * CFrame.Angles(math.rad(62), 0, 0), silverMetal, Enum.Material.Metal)
	weldTo(handle, beakTipU)

	local beakBaseL = makePart(model, "BeakTip_L1", Vector3.new(0.14, 0.22, 0.14), CFrame.new(0, -1.84, 0.48) * CFrame.Angles(-math.rad(52), 0, 0), silverMetal, Enum.Material.Metal)
	weldTo(handle, beakBaseL)
	local beakTipL = makePart(model, "BeakTip_L2", Vector3.new(0.10, 0.22, 0.12), CFrame.new(0, -1.98, 0.60) * CFrame.Angles(-math.rad(62), 0, 0), silverMetal, Enum.Material.Metal)
	weldTo(handle, beakTipL)

	-- Bowstring
	local bowString = makePart(model, "BowString", Vector3.new(0.045, 3.96, 0.045), CFrame.new(0, 0, 0.60), stringColor, Enum.Material.Fabric)
	weldTo(handle, bowString)

	addSocket(handle, "Grip", Vector3.zero)
	addSocket(handle, "Nock", Vector3.new(ARROW_REST.X, ARROW_REST.Y, 0.60))
	addSocket(handle, "TipUpper", Vector3.new(0, 1.98, 0.60))
	addSocket(handle, "TipLower", Vector3.new(0, -1.98, 0.60))
	addSocket(handle, "VfxTip", Vector3.new(0, 1.98, 0.60))
	addSocket(handle, "VfxBase", Vector3.new(0, -1.98, 0.60))
	addSocket(handle, "VfxCore", Vector3.zero)
	addSocket(handle, "VfxNock", Vector3.new(ARROW_REST.X, ARROW_REST.Y, 0.60))

	createHunterArrow(model, handle)
	return model
end

-- ============================================================================
-- 5. Stormstrider Longbow (art_stormstrider_longbow) - Rare Standard
-- ============================================================================
function WeaponModelBuilder.BuildStormstriderLongbow(): Model
	local model = Instance.new("Model")
	model.Name = "art_stormstrider_longbow"

	local stormBlack = Color3.fromRGB(32, 35, 42)
	local stormBlue = Color3.fromRGB(45, 75, 125)
	local tsukaWrap = Color3.fromRGB(20, 22, 28)
	local lightningGold = Color3.fromRGB(240, 205, 75)
	local copperWire = Color3.fromRGB(195, 115, 65)
	local ironDark = Color3.fromRGB(70, 75, 82)
	local stringColor = Color3.fromRGB(180, 215, 255)

	-- Low-set Asymmetrical Daikyu Grip & Tsuka-ito Wrap
	local handle = makePart(model, "Handle", Vector3.new(0.24, 0.70, 0.30), CFrame.new(0, 0, 0), stormBlack, Enum.Material.SmoothPlastic)
	model.PrimaryPart = handle

	local wrap1 = makePart(model, "TsukaWrap_1", Vector3.new(0.26, 0.10, 0.32), CFrame.new(0, 0.20, 0), tsukaWrap, Enum.Material.Fabric)
	weldTo(handle, wrap1)
	local wrap2 = makePart(model, "TsukaWrap_2", Vector3.new(0.27, 0.10, 0.33), CFrame.new(0, 0.07, 0), tsukaWrap, Enum.Material.Fabric)
	weldTo(handle, wrap2)
	local wrap3 = makePart(model, "TsukaWrap_3", Vector3.new(0.27, 0.10, 0.33), CFrame.new(0, -0.07, 0), tsukaWrap, Enum.Material.Fabric)
	weldTo(handle, wrap3)
	local wrap4 = makePart(model, "TsukaWrap_4", Vector3.new(0.26, 0.10, 0.32), CFrame.new(0, -0.20, 0), tsukaWrap, Enum.Material.Fabric)
	weldTo(handle, wrap4)

	local stormCrest = makePart(model, "StormCrestCollar", Vector3.new(0.28, 0.06, 0.34), CFrame.new(0, 0.28, 0), lightningGold, Enum.Material.Metal)
	weldTo(handle, stormCrest)
	local menuki1 = makePart(model, "MenukiDragon_1", Vector3.new(0.10, 0.12, 0.14), CFrame.new(0.12, 0.05, 0), lightningGold, Enum.Material.Metal)
	weldTo(handle, menuki1)
	local menuki2 = makePart(model, "MenukiDragon_2", Vector3.new(0.10, 0.12, 0.14), CFrame.new(-0.12, -0.05, 0), lightningGold, Enum.Material.Metal)
	weldTo(handle, menuki2)
	local stormShelf = makePart(model, "StormShelf", Vector3.new(0.08, 0.14, 0.18), CFrame.new(0.14, 0.10, -0.07), ironDark, Enum.Material.Metal)
	weldTo(handle, stormShelf)

	-- Upper Arch: 8 expansive curved segments (daikyu 2:1 ratio, sweeps up to Y=+3.0)
	local lu1 = makePart(model, "LimbU_1", Vector3.new(0.22, 0.38, 0.24), CFrame.new(0, 0.50, 0.02) * CFrame.Angles(math.rad(4), 0, 0), stormBlue, Enum.Material.SmoothPlastic)
	weldTo(handle, lu1)
	local lu2 = makePart(model, "LimbU_2", Vector3.new(0.21, 0.38, 0.23), CFrame.new(0, 0.86, 0.05) * CFrame.Angles(math.rad(8), 0, 0), stormBlue, Enum.Material.SmoothPlastic)
	weldTo(handle, lu2)
	local lu3 = makePart(model, "LimbU_3", Vector3.new(0.20, 0.38, 0.22), CFrame.new(0, 1.22, 0.11) * CFrame.Angles(math.rad(13), 0, 0), stormBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, lu3)
	local lu4 = makePart(model, "LimbU_4", Vector3.new(0.19, 0.38, 0.20), CFrame.new(0, 1.58, 0.20) * CFrame.Angles(math.rad(18), 0, 0), stormBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, lu4)
	local lu5 = makePart(model, "LimbU_5", Vector3.new(0.18, 0.38, 0.19), CFrame.new(0, 1.94, 0.32) * CFrame.Angles(math.rad(24), 0, 0), stormBlue, Enum.Material.SmoothPlastic)
	weldTo(handle, lu5)
	local lu6 = makePart(model, "LimbU_6", Vector3.new(0.17, 0.38, 0.18), CFrame.new(0, 2.28, 0.48) * CFrame.Angles(math.rad(31), 0, 0), stormBlue, Enum.Material.SmoothPlastic)
	weldTo(handle, lu6)
	local lu7 = makePart(model, "LimbU_7", Vector3.new(0.16, 0.38, 0.17), CFrame.new(0, 2.60, 0.68) * CFrame.Angles(math.rad(39), 0, 0), stormBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, lu7)
	local lu8 = makePart(model, "LimbU_8", Vector3.new(0.15, 0.40, 0.16), CFrame.new(0, 2.90, 0.92) * CFrame.Angles(math.rad(48), 0, 0), stormBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, lu8)

	-- Upper Lightning Spine Plates (5 plates along dorsal back)
	local sp1 = makePart(model, "SpinePlate_1", Vector3.new(0.08, 0.36, 0.08), CFrame.new(0, 0.86, -0.06) * CFrame.Angles(math.rad(8), 0, 0), lightningGold, Enum.Material.Metal)
	weldTo(handle, sp1)
	local sp2 = makePart(model, "SpinePlate_2", Vector3.new(0.07, 0.36, 0.08), CFrame.new(0, 1.58, 0.09) * CFrame.Angles(math.rad(18), 0, 0), lightningGold, Enum.Material.Metal)
	weldTo(handle, sp2)
	local sp3 = makePart(model, "SpinePlate_3", Vector3.new(0.06, 0.36, 0.08), CFrame.new(0, 2.28, 0.37) * CFrame.Angles(math.rad(31), 0, 0), lightningGold, Enum.Material.Metal)
	weldTo(handle, sp3)
	local sp4 = makePart(model, "SpinePlate_4", Vector3.new(0.05, 0.36, 0.08), CFrame.new(0, 2.60, 0.57) * CFrame.Angles(math.rad(39), 0, 0), lightningGold, Enum.Material.Metal)
	weldTo(handle, sp4)

	-- Copper Wire Bindings (Upper & Lower)
	local wire1 = makePart(model, "WireBinding_1", Vector3.new(0.24, 0.06, 0.26), CFrame.new(0, 1.22, 0.11) * CFrame.Angles(math.rad(13), 0, 0), copperWire, Enum.Material.Metal)
	weldTo(handle, wire1)
	local wire2 = makePart(model, "WireBinding_2", Vector3.new(0.21, 0.06, 0.22), CFrame.new(0, 1.94, 0.32) * CFrame.Angles(math.rad(24), 0, 0), copperWire, Enum.Material.Metal)
	weldTo(handle, wire2)
	local wire3 = makePart(model, "WireBinding_3", Vector3.new(0.20, 0.06, 0.21), CFrame.new(0, 2.28, 0.48) * CFrame.Angles(math.rad(31), 0, 0), copperWire, Enum.Material.Metal)
	weldTo(handle, wire3)

	-- Upper Lightning Claw Tips (3-piece assembly)
	local clawBaseU = makePart(model, "Claw_U1", Vector3.new(0.14, 0.22, 0.14), CFrame.new(0, 3.12, 1.10) * CFrame.Angles(math.rad(56), 0, 0), lightningGold, Enum.Material.Metal)
	weldTo(handle, clawBaseU)
	local clawTipU = makePart(model, "Claw_U2", Vector3.new(0.10, 0.24, 0.12), CFrame.new(0, 3.26, 1.24) * CFrame.Angles(math.rad(66), 0, 0), lightningGold, Enum.Material.Metal)
	weldTo(handle, clawTipU)
	local clawSpurU = makePart(model, "Claw_U3", Vector3.new(0.06, 0.14, 0.10), CFrame.new(0, 3.06, 1.22) * CFrame.Angles(-math.rad(30), 0, 0), lightningGold, Enum.Material.Metal)
	weldTo(handle, clawSpurU)

	-- Lower Limb: 5 compact counter-recoil segments
	local ll1 = makePart(model, "LimbL_1", Vector3.new(0.22, 0.34, 0.24), CFrame.new(0, -0.48, 0.02) * CFrame.Angles(-math.rad(6), 0, 0), stormBlue, Enum.Material.SmoothPlastic)
	weldTo(handle, ll1)
	local ll2 = makePart(model, "LimbL_2", Vector3.new(0.21, 0.34, 0.23), CFrame.new(0, -0.80, 0.06) * CFrame.Angles(-math.rad(14), 0, 0), stormBlue, Enum.Material.SmoothPlastic)
	weldTo(handle, ll2)
	local ll3 = makePart(model, "LimbL_3", Vector3.new(0.20, 0.34, 0.22), CFrame.new(0, -1.12, 0.15) * CFrame.Angles(-math.rad(23), 0, 0), stormBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, ll3)
	local ll4 = makePart(model, "LimbL_4", Vector3.new(0.18, 0.34, 0.20), CFrame.new(0, -1.42, 0.29) * CFrame.Angles(-math.rad(33), 0, 0), stormBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, ll4)
	local ll5 = makePart(model, "LimbL_5", Vector3.new(0.16, 0.36, 0.18), CFrame.new(0, -1.70, 0.48) * CFrame.Angles(-math.rad(44), 0, 0), stormBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, ll5)

	-- Lower Wire Binding & Ground Iron Boot
	local wire4 = makePart(model, "WireBinding_4", Vector3.new(0.22, 0.06, 0.24), CFrame.new(0, -0.80, 0.06) * CFrame.Angles(-math.rad(14), 0, 0), copperWire, Enum.Material.Metal)
	weldTo(handle, wire4)
	local wire5 = makePart(model, "WireBinding_5", Vector3.new(0.22, 0.06, 0.24), CFrame.new(0, -1.12, 0.15) * CFrame.Angles(-math.rad(23), 0, 0), copperWire, Enum.Material.Metal)
	weldTo(handle, wire5)
	local boot1 = makePart(model, "GroundBoot_1", Vector3.new(0.18, 0.20, 0.20), CFrame.new(0, -1.90, 0.62) * CFrame.Angles(-math.rad(52), 0, 0), ironDark, Enum.Material.Metal)
	weldTo(handle, boot1)
	local boot2 = makePart(model, "GroundBoot_2", Vector3.new(0.14, 0.18, 0.16), CFrame.new(0, -2.02, 0.74) * CFrame.Angles(-math.rad(60), 0, 0), ironDark, Enum.Material.Metal)
	weldTo(handle, boot2)
	local bootSpike = makePart(model, "GroundBoot_Spike", Vector3.new(0.08, 0.14, 0.08), CFrame.new(0, -2.14, 0.82) * CFrame.Angles(-math.rad(68), 0, 0), lightningGold, Enum.Material.Metal)
	weldTo(handle, bootSpike)

	-- Storm-wire Bowstring
	local bowString = makePart(model, "BowString", Vector3.new(0.045, 5.30, 0.045), CFrame.new(0, 0.60, 0.85) * CFrame.Angles(math.rad(5), 0, 0), stringColor, Enum.Material.Fabric)
	weldTo(handle, bowString)

	addSocket(handle, "Grip", Vector3.zero)
	addSocket(handle, "Nock", Vector3.new(ARROW_REST.X, ARROW_REST.Y, 0.85))
	addSocket(handle, "TipUpper", Vector3.new(0, 3.26, 1.24))
	addSocket(handle, "TipLower", Vector3.new(0, -2.02, 0.74))
	addSocket(handle, "VfxTip", Vector3.new(0, 3.26, 1.24))
	addSocket(handle, "VfxBase", Vector3.new(0, -2.02, 0.74))
	addSocket(handle, "VfxCore", Vector3.zero)
	addSocket(handle, "VfxNock", Vector3.new(ARROW_REST.X, ARROW_REST.Y, 0.85))

	createHunterArrow(model, handle)
	return model
end

-- ============================================================================
-- 6. Thunderhead Recurve (art_thunderhead_recurve) - Rare Enhanced
-- ============================================================================
function WeaponModelBuilder.BuildThunderheadRecurve(): Model
	local model = Instance.new("Model")
	model.Name = "art_thunderhead_recurve"

	local bronzeDark = Color3.fromRGB(150, 95, 45)
	local bronzeBright = Color3.fromRGB(195, 135, 65)
	local copperBright = Color3.fromRGB(225, 125, 65)
	local vulcaniteBlack = Color3.fromRGB(30, 30, 32)
	local steelClamp = Color3.fromRGB(120, 125, 135)
	local sparkGold = Color3.fromRGB(255, 220, 90)
	local stringColor = Color3.fromRGB(240, 185, 100)

	-- Cast Bronze Heavy Riser
	local handle = makePart(model, "Handle", Vector3.new(0.26, 0.72, 0.32), CFrame.new(0, 0, 0), bronzeDark, Enum.Material.Metal)
	model.PrimaryPart = handle

	-- Knurled Vulcanite Grip & Dial Plate
	local vWrap1 = makePart(model, "VulcaniteGrip_1", Vector3.new(0.28, 0.12, 0.34), CFrame.new(0, 0.16, 0), vulcaniteBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, vWrap1)
	local vWrap2 = makePart(model, "VulcaniteGrip_2", Vector3.new(0.29, 0.12, 0.35), CFrame.new(0, 0.04, 0), vulcaniteBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, vWrap2)
	local vWrap3 = makePart(model, "VulcaniteGrip_3", Vector3.new(0.28, 0.12, 0.34), CFrame.new(0, -0.08, 0), vulcaniteBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, vWrap3)

	local voltDial = makePart(model, "VoltDialPlate", Vector3.new(0.12, 0.14, 0.08), CFrame.new(-0.14, 0.06, 0), steelClamp, Enum.Material.Metal)
	weldTo(handle, voltDial)
	local dialGlass = makePart(model, "VoltDialGlass", Vector3.new(0.08, 0.10, 0.04), CFrame.new(-0.17, 0.06, 0), sparkGold, Enum.Material.Glass)
	weldTo(handle, dialGlass)
	local dialNeedle = makePart(model, "VoltDialNeedle", Vector3.new(0.02, 0.08, 0.02), CFrame.new(-0.17, 0.06, 0) * CFrame.Angles(0, 0, math.rad(30)), copperBright, Enum.Material.Metal)
	weldTo(handle, dialNeedle)
	local arrowRest = makePart(model, "BronzeArrowRest", Vector3.new(0.08, 0.14, 0.18), CFrame.new(0.15, 0.08, -0.08), bronzeBright, Enum.Material.Metal)
	weldTo(handle, arrowRest)

	-- Upper Stepped Bronze Limbs (6 segments)
	local lu1 = makePart(model, "LimbU_1", Vector3.new(0.24, 0.34, 0.24), CFrame.new(0, 0.48, 0.02) * CFrame.Angles(math.rad(5), 0, 0), bronzeDark, Enum.Material.Metal)
	weldTo(handle, lu1)
	local lu2 = makePart(model, "LimbU_2", Vector3.new(0.22, 0.34, 0.22), CFrame.new(0, 0.78, 0.06) * CFrame.Angles(math.rad(11), 0, 0), bronzeDark, Enum.Material.Metal)
	weldTo(handle, lu2)
	local lu3 = makePart(model, "LimbU_3", Vector3.new(0.20, 0.34, 0.20), CFrame.new(0, 1.08, 0.14) * CFrame.Angles(math.rad(19), 0, 0), bronzeBright, Enum.Material.Metal)
	weldTo(handle, lu3)
	local lu4 = makePart(model, "LimbU_4", Vector3.new(0.18, 0.34, 0.18), CFrame.new(0, 1.36, 0.26) * CFrame.Angles(math.rad(28), 0, 0), bronzeBright, Enum.Material.Metal)
	weldTo(handle, lu4)
	local lu5 = makePart(model, "LimbU_5", Vector3.new(0.16, 0.34, 0.16), CFrame.new(0, 1.62, 0.42) * CFrame.Angles(math.rad(40), 0, 0), bronzeDark, Enum.Material.Metal)
	weldTo(handle, lu5)
	local lu6 = makePart(model, "LimbU_6", Vector3.new(0.14, 0.36, 0.14), CFrame.new(0, 1.86, 0.62) * CFrame.Angles(math.rad(54), 0, 0), bronzeDark, Enum.Material.Metal)
	weldTo(handle, lu6)

	-- Upper Copper Induction Coil (4 toroidal rings + 2 steel clamps + jumper)
	local coilU1 = makePart(model, "CoilU_1", Vector3.new(0.24, 0.07, 0.24), CFrame.new(0, 0.96, 0.10) * CFrame.Angles(math.rad(15), 0, 0), copperBright, Enum.Material.Metal)
	weldTo(handle, coilU1)
	local coilU2 = makePart(model, "CoilU_2", Vector3.new(0.24, 0.07, 0.24), CFrame.new(0, 1.05, 0.13) * CFrame.Angles(math.rad(18), 0, 0), copperBright, Enum.Material.Metal)
	weldTo(handle, coilU2)
	local coilU3 = makePart(model, "CoilU_3", Vector3.new(0.23, 0.07, 0.23), CFrame.new(0, 1.14, 0.16) * CFrame.Angles(math.rad(21), 0, 0), copperBright, Enum.Material.Metal)
	weldTo(handle, coilU3)
	local coilU4 = makePart(model, "CoilU_4", Vector3.new(0.23, 0.07, 0.23), CFrame.new(0, 1.23, 0.20) * CFrame.Angles(math.rad(24), 0, 0), copperBright, Enum.Material.Metal)
	weldTo(handle, coilU4)
	local clampU1 = makePart(model, "ClampU_1", Vector3.new(0.26, 0.05, 0.26), CFrame.new(0, 0.90, 0.08) * CFrame.Angles(math.rad(13), 0, 0), steelClamp, Enum.Material.Metal)
	weldTo(handle, clampU1)
	local clampU2 = makePart(model, "ClampU_2", Vector3.new(0.25, 0.05, 0.25), CFrame.new(0, 1.29, 0.23) * CFrame.Angles(math.rad(26), 0, 0), steelClamp, Enum.Material.Metal)
	weldTo(handle, clampU2)
	local jumperU = makePart(model, "CoilJumper_U", Vector3.new(0.04, 0.38, 0.04), CFrame.new(0.12, 1.10, 0.16) * CFrame.Angles(math.rad(20), 0, 0), copperBright, Enum.Material.Metal)
	weldTo(handle, jumperU)

	-- Upper Discharge Capacitor & Prongs
	local termU = makePart(model, "Terminal_U", Vector3.new(0.12, 0.20, 0.12), CFrame.new(0, 2.04, 0.76) * CFrame.Angles(math.rad(62), 0, 0), steelClamp, Enum.Material.Metal)
	weldTo(handle, termU)
	local prongU1 = makePart(model, "Prong_U1", Vector3.new(0.05, 0.22, 0.05), CFrame.new(0.06, 2.16, 0.86) * CFrame.Angles(math.rad(70), math.rad(10), 0), copperBright, Enum.Material.Metal)
	weldTo(handle, prongU1)
	local prongU2 = makePart(model, "Prong_U2", Vector3.new(0.05, 0.22, 0.05), CFrame.new(-0.06, 2.16, 0.86) * CFrame.Angles(math.rad(70), -math.rad(10), 0), copperBright, Enum.Material.Metal)
	weldTo(handle, prongU2)

	-- Lower Stepped Bronze Limbs (6 segments)
	local ll1 = makePart(model, "LimbL_1", Vector3.new(0.24, 0.34, 0.24), CFrame.new(0, -0.48, 0.02) * CFrame.Angles(-math.rad(5), 0, 0), bronzeDark, Enum.Material.Metal)
	weldTo(handle, ll1)
	local ll2 = makePart(model, "LimbL_2", Vector3.new(0.22, 0.34, 0.22), CFrame.new(0, -0.78, 0.06) * CFrame.Angles(-math.rad(11), 0, 0), bronzeDark, Enum.Material.Metal)
	weldTo(handle, ll2)
	local ll3 = makePart(model, "LimbL_3", Vector3.new(0.20, 0.34, 0.20), CFrame.new(0, -1.08, 0.14) * CFrame.Angles(-math.rad(19), 0, 0), bronzeBright, Enum.Material.Metal)
	weldTo(handle, ll3)
	local ll4 = makePart(model, "LimbL_4", Vector3.new(0.18, 0.34, 0.18), CFrame.new(0, -1.36, 0.26) * CFrame.Angles(-math.rad(28), 0, 0), bronzeBright, Enum.Material.Metal)
	weldTo(handle, ll4)
	local ll5 = makePart(model, "LimbL_5", Vector3.new(0.16, 0.34, 0.16), CFrame.new(0, -1.62, 0.42) * CFrame.Angles(-math.rad(40), 0, 0), bronzeDark, Enum.Material.Metal)
	weldTo(handle, ll5)
	local ll6 = makePart(model, "LimbL_6", Vector3.new(0.14, 0.36, 0.14), CFrame.new(0, -1.86, 0.62) * CFrame.Angles(-math.rad(54), 0, 0), bronzeDark, Enum.Material.Metal)
	weldTo(handle, ll6)

	-- Lower Copper Induction Coil
	local coilL1 = makePart(model, "CoilL_1", Vector3.new(0.24, 0.07, 0.24), CFrame.new(0, -0.96, 0.10) * CFrame.Angles(-math.rad(15), 0, 0), copperBright, Enum.Material.Metal)
	weldTo(handle, coilL1)
	local coilL2 = makePart(model, "CoilL_2", Vector3.new(0.24, 0.07, 0.24), CFrame.new(0, -1.05, 0.13) * CFrame.Angles(-math.rad(18), 0, 0), copperBright, Enum.Material.Metal)
	weldTo(handle, coilL2)
	local coilL3 = makePart(model, "CoilL_3", Vector3.new(0.23, 0.07, 0.23), CFrame.new(0, -1.14, 0.16) * CFrame.Angles(-math.rad(21), 0, 0), copperBright, Enum.Material.Metal)
	weldTo(handle, coilL3)
	local coilL4 = makePart(model, "CoilL_4", Vector3.new(0.23, 0.07, 0.23), CFrame.new(0, -1.23, 0.20) * CFrame.Angles(-math.rad(24), 0, 0), copperBright, Enum.Material.Metal)
	weldTo(handle, coilL4)
	local clampL1 = makePart(model, "ClampL_1", Vector3.new(0.26, 0.05, 0.26), CFrame.new(0, -0.90, 0.08) * CFrame.Angles(-math.rad(13), 0, 0), steelClamp, Enum.Material.Metal)
	weldTo(handle, clampL1)
	local clampL2 = makePart(model, "ClampL_2", Vector3.new(0.25, 0.05, 0.25), CFrame.new(0, -1.29, 0.23) * CFrame.Angles(-math.rad(26), 0, 0), steelClamp, Enum.Material.Metal)
	weldTo(handle, clampL2)
	local jumperL = makePart(model, "CoilJumper_L", Vector3.new(0.04, 0.38, 0.04), CFrame.new(0.12, -1.10, 0.16) * CFrame.Angles(-math.rad(20), 0, 0), copperBright, Enum.Material.Metal)
	weldTo(handle, jumperL)

	-- Lower Discharge Capacitor & Prongs
	local termL = makePart(model, "Terminal_L", Vector3.new(0.12, 0.20, 0.12), CFrame.new(0, -2.04, 0.76) * CFrame.Angles(-math.rad(62), 0, 0), steelClamp, Enum.Material.Metal)
	weldTo(handle, termL)
	local prongL1 = makePart(model, "Prong_L1", Vector3.new(0.05, 0.22, 0.05), CFrame.new(0.06, -2.16, 0.86) * CFrame.Angles(-math.rad(70), math.rad(10), 0), copperBright, Enum.Material.Metal)
	weldTo(handle, prongL1)
	local prongL2 = makePart(model, "Prong_L2", Vector3.new(0.05, 0.22, 0.05), CFrame.new(-0.06, -2.16, 0.86) * CFrame.Angles(-math.rad(70), -math.rad(10), 0), copperBright, Enum.Material.Metal)
	weldTo(handle, prongL2)

	-- Twisted Copper-Core Bowstring
	local bowString = makePart(model, "BowString", Vector3.new(0.045, 4.30, 0.045), CFrame.new(0, 0, 0.82), stringColor, Enum.Material.Fabric)
	weldTo(handle, bowString)

	addSocket(handle, "Grip", Vector3.zero)
	addSocket(handle, "Nock", Vector3.new(ARROW_REST.X, ARROW_REST.Y, 0.82))
	addSocket(handle, "TipUpper", Vector3.new(0, 2.16, 0.86))
	addSocket(handle, "TipLower", Vector3.new(0, -2.16, 0.86))
	addSocket(handle, "VfxTip", Vector3.new(0, 2.16, 0.86))
	addSocket(handle, "VfxBase", Vector3.new(0, -2.16, 0.86))
	addSocket(handle, "VfxCore", Vector3.zero)
	addSocket(handle, "VfxNock", Vector3.new(ARROW_REST.X, ARROW_REST.Y, 0.82))

	createHunterArrow(model, handle)
	return model
end

-- ============================================================================
-- 7. Crystal Greatbow (art_crystal_greatbow) - Superior Standard
-- ============================================================================
function WeaponModelBuilder.BuildCrystalGreatbow(): Model
	local model = Instance.new("Model")
	model.Name = "art_crystal_greatbow"

	local platinumSilver = Color3.fromRGB(225, 230, 240)
	local platinumDark = Color3.fromRGB(165, 175, 190)
	local velvetViolet = Color3.fromRGB(75, 25, 110)
	local amethystCrystal = Color3.fromRGB(175, 105, 245)
	local amethystPale = Color3.fromRGB(215, 165, 255)
	local stringColor = Color3.fromRGB(235, 215, 255)

	-- Chiseled Platinum Socket Cradle & Violet Velvet Wrap
	local handle = makePart(model, "Handle", Vector3.new(0.26, 0.74, 0.32), CFrame.new(0, 0, 0), platinumSilver, Enum.Material.Metal)
	model.PrimaryPart = handle

	local vWrap1 = makePart(model, "VelvetWrap_1", Vector3.new(0.28, 0.10, 0.34), CFrame.new(0, 0.20, 0), velvetViolet, Enum.Material.Fabric)
	weldTo(handle, vWrap1)
	local vWrap2 = makePart(model, "VelvetWrap_2", Vector3.new(0.29, 0.10, 0.35), CFrame.new(0, 0.07, 0), velvetViolet, Enum.Material.Fabric)
	weldTo(handle, vWrap2)
	local vWrap3 = makePart(model, "VelvetWrap_3", Vector3.new(0.29, 0.10, 0.35), CFrame.new(0, -0.07, 0), velvetViolet, Enum.Material.Fabric)
	weldTo(handle, vWrap3)
	local vWrap4 = makePart(model, "VelvetWrap_4", Vector3.new(0.28, 0.10, 0.34), CFrame.new(0, -0.20, 0), velvetViolet, Enum.Material.Fabric)
	weldTo(handle, vWrap4)

	local ferruleTop = makePart(model, "PlatFerrule_Top", Vector3.new(0.28, 0.06, 0.34), CFrame.new(0, 0.28, 0), platinumDark, Enum.Material.Metal)
	weldTo(handle, ferruleTop)
	local ferruleBot = makePart(model, "PlatFerrule_Bot", Vector3.new(0.28, 0.06, 0.34), CFrame.new(0, -0.28, 0), platinumDark, Enum.Material.Metal)
	weldTo(handle, ferruleBot)
	local crystalShelf = makePart(model, "CrystalShelf", Vector3.new(0.08, 0.14, 0.18), CFrame.new(0.15, 0.09, -0.08), amethystCrystal, Enum.Material.Glass)
	weldTo(handle, crystalShelf)

	-- Upper Platinum Exoskeleton Spine (5 segments)
	local spineU1 = makePart(model, "ExoSpineU_1", Vector3.new(0.12, 0.36, 0.12), CFrame.new(0, 0.50, -0.06) * CFrame.Angles(math.rad(6), 0, 0), platinumSilver, Enum.Material.Metal)
	weldTo(handle, spineU1)
	local spineU2 = makePart(model, "ExoSpineU_2", Vector3.new(0.11, 0.36, 0.11), CFrame.new(0, 0.82, -0.03) * CFrame.Angles(math.rad(14), 0, 0), platinumSilver, Enum.Material.Metal)
	weldTo(handle, spineU2)
	local spineU3 = makePart(model, "ExoSpineU_3", Vector3.new(0.10, 0.36, 0.10), CFrame.new(0, 1.14, 0.05) * CFrame.Angles(math.rad(24), 0, 0), platinumSilver, Enum.Material.Metal)
	weldTo(handle, spineU3)
	local spineU4 = makePart(model, "ExoSpineU_4", Vector3.new(0.09, 0.36, 0.09), CFrame.new(0, 1.44, 0.20) * CFrame.Angles(math.rad(36), 0, 0), platinumSilver, Enum.Material.Metal)
	weldTo(handle, spineU4)
	local spineU5 = makePart(model, "ExoSpineU_5", Vector3.new(0.08, 0.38, 0.08), CFrame.new(0, 1.72, 0.42) * CFrame.Angles(math.rad(50), 0, 0), platinumSilver, Enum.Material.Metal)
	weldTo(handle, spineU5)

	-- Upper Exoskeleton Clamp Collars
	local clampU1 = makePart(model, "ExoClampU_1", Vector3.new(0.24, 0.05, 0.24), CFrame.new(0, 0.65, -0.04) * CFrame.Angles(math.rad(10), 0, 0), platinumDark, Enum.Material.Metal)
	weldTo(handle, clampU1)
	local clampU2 = makePart(model, "ExoClampU_2", Vector3.new(0.22, 0.05, 0.22), CFrame.new(0, 0.98, 0.01) * CFrame.Angles(math.rad(19), 0, 0), platinumDark, Enum.Material.Metal)
	weldTo(handle, clampU2)
	local clampU3 = makePart(model, "ExoClampU_3", Vector3.new(0.20, 0.05, 0.20), CFrame.new(0, 1.29, 0.12) * CFrame.Angles(math.rad(30), 0, 0), platinumDark, Enum.Material.Metal)
	weldTo(handle, clampU3)
	local clampU4 = makePart(model, "ExoClampU_4", Vector3.new(0.18, 0.05, 0.18), CFrame.new(0, 1.58, 0.31) * CFrame.Angles(math.rad(43), 0, 0), platinumDark, Enum.Material.Metal)
	weldTo(handle, clampU4)

	-- Upper Hexagonal Amethyst Shards (6 crystals)
	local shardU1 = makePart(model, "AmethystU_1", Vector3.new(0.18, 0.32, 0.18), CFrame.new(0, 0.50, 0.06) * CFrame.Angles(math.rad(6), math.rad(30), 0), amethystCrystal, Enum.Material.Glass)
	weldTo(handle, shardU1)
	local shardU2 = makePart(model, "AmethystU_2", Vector3.new(0.17, 0.32, 0.17), CFrame.new(0, 0.82, 0.09) * CFrame.Angles(math.rad(14), math.rad(30), 0), amethystPale, Enum.Material.Glass)
	weldTo(handle, shardU2)
	local shardU3 = makePart(model, "AmethystU_3", Vector3.new(0.16, 0.32, 0.16), CFrame.new(0, 1.14, 0.17) * CFrame.Angles(math.rad(24), math.rad(30), 0), amethystCrystal, Enum.Material.Glass)
	weldTo(handle, shardU3)
	local shardU4 = makePart(model, "AmethystU_4", Vector3.new(0.15, 0.32, 0.15), CFrame.new(0, 1.44, 0.32) * CFrame.Angles(math.rad(36), math.rad(30), 0), amethystPale, Enum.Material.Glass)
	weldTo(handle, shardU4)
	local shardU5 = makePart(model, "AmethystU_5", Vector3.new(0.14, 0.32, 0.14), CFrame.new(0, 1.72, 0.54) * CFrame.Angles(math.rad(50), math.rad(30), 0), amethystCrystal, Enum.Material.Glass)
	weldTo(handle, shardU5)
	local shardU6 = makePart(model, "AmethystU_6", Vector3.new(0.12, 0.34, 0.12), CFrame.new(0, 1.96, 0.80) * CFrame.Angles(math.rad(62), math.rad(30), 0), amethystPale, Enum.Material.Glass)
	weldTo(handle, shardU6)

	-- Upper Crystal Accent Thorns
	local thornU1 = makePart(model, "ThornU_1", Vector3.new(0.06, 0.16, 0.10), CFrame.new(0.12, 0.98, 0.08) * CFrame.Angles(math.rad(19), math.rad(35), 0), amethystCrystal, Enum.Material.Glass)
	weldTo(handle, thornU1)
	local thornU2 = makePart(model, "ThornU_2", Vector3.new(0.06, 0.16, 0.10), CFrame.new(-0.12, 0.98, 0.08) * CFrame.Angles(math.rad(19), -math.rad(35), 0), amethystCrystal, Enum.Material.Glass)
	weldTo(handle, thornU2)

	-- Upper Prism Tip Assembly
	local tipU1 = makePart(model, "PrismTipU_1", Vector3.new(0.14, 0.22, 0.14), CFrame.new(0, 2.12, 0.96) * CFrame.Angles(math.rad(70), 0, 0), platinumSilver, Enum.Material.Metal)
	weldTo(handle, tipU1)
	local tipU2 = makePart(model, "PrismTipU_2", Vector3.new(0.08, 0.24, 0.08), CFrame.new(0, 2.24, 1.08) * CFrame.Angles(math.rad(76), 0, 0), amethystPale, Enum.Material.Glass)
	weldTo(handle, tipU2)

	-- Lower Platinum Exoskeleton Spine (5 segments)
	local spineL1 = makePart(model, "ExoSpineL_1", Vector3.new(0.12, 0.36, 0.12), CFrame.new(0, -0.50, -0.06) * CFrame.Angles(-math.rad(6), 0, 0), platinumSilver, Enum.Material.Metal)
	weldTo(handle, spineL1)
	local spineL2 = makePart(model, "ExoSpineL_2", Vector3.new(0.11, 0.36, 0.11), CFrame.new(0, -0.82, -0.03) * CFrame.Angles(-math.rad(14), 0, 0), platinumSilver, Enum.Material.Metal)
	weldTo(handle, spineL2)
	local spineL3 = makePart(model, "ExoSpineL_3", Vector3.new(0.10, 0.36, 0.10), CFrame.new(0, -1.14, 0.05) * CFrame.Angles(-math.rad(24), 0, 0), platinumSilver, Enum.Material.Metal)
	weldTo(handle, spineL3)
	local spineL4 = makePart(model, "ExoSpineL_4", Vector3.new(0.09, 0.36, 0.09), CFrame.new(0, -1.44, 0.20) * CFrame.Angles(-math.rad(36), 0, 0), platinumSilver, Enum.Material.Metal)
	weldTo(handle, spineL4)
	local spineL5 = makePart(model, "ExoSpineL_5", Vector3.new(0.08, 0.38, 0.08), CFrame.new(0, -1.72, 0.42) * CFrame.Angles(-math.rad(50), 0, 0), platinumSilver, Enum.Material.Metal)
	weldTo(handle, spineL5)

	-- Lower Exoskeleton Clamp Collars
	local clampL1 = makePart(model, "ExoClampL_1", Vector3.new(0.24, 0.05, 0.24), CFrame.new(0, -0.65, -0.04) * CFrame.Angles(-math.rad(10), 0, 0), platinumDark, Enum.Material.Metal)
	weldTo(handle, clampL1)
	local clampL2 = makePart(model, "ExoClampL_2", Vector3.new(0.22, 0.05, 0.22), CFrame.new(0, -0.98, 0.01) * CFrame.Angles(-math.rad(19), 0, 0), platinumDark, Enum.Material.Metal)
	weldTo(handle, clampL2)
	local clampL3 = makePart(model, "ExoClampL_3", Vector3.new(0.20, 0.05, 0.20), CFrame.new(0, -1.29, 0.12) * CFrame.Angles(-math.rad(30), 0, 0), platinumDark, Enum.Material.Metal)
	weldTo(handle, clampL3)
	local clampL4 = makePart(model, "ExoClampL_4", Vector3.new(0.18, 0.05, 0.18), CFrame.new(0, -1.58, 0.31) * CFrame.Angles(-math.rad(43), 0, 0), platinumDark, Enum.Material.Metal)
	weldTo(handle, clampL4)

	-- Lower Hexagonal Amethyst Shards (6 crystals)
	local shardL1 = makePart(model, "AmethystL_1", Vector3.new(0.18, 0.32, 0.18), CFrame.new(0, -0.50, 0.06) * CFrame.Angles(-math.rad(6), math.rad(30), 0), amethystCrystal, Enum.Material.Glass)
	weldTo(handle, shardL1)
	local shardL2 = makePart(model, "AmethystL_2", Vector3.new(0.17, 0.32, 0.17), CFrame.new(0, -0.82, 0.09) * CFrame.Angles(-math.rad(14), math.rad(30), 0), amethystPale, Enum.Material.Glass)
	weldTo(handle, shardL2)
	local shardL3 = makePart(model, "AmethystL_3", Vector3.new(0.16, 0.32, 0.16), CFrame.new(0, -1.14, 0.17) * CFrame.Angles(-math.rad(24), math.rad(30), 0), amethystCrystal, Enum.Material.Glass)
	weldTo(handle, shardL3)
	local shardL4 = makePart(model, "AmethystL_4", Vector3.new(0.15, 0.32, 0.15), CFrame.new(0, -1.44, 0.32) * CFrame.Angles(-math.rad(36), math.rad(30), 0), amethystPale, Enum.Material.Glass)
	weldTo(handle, shardL4)
	local shardL5 = makePart(model, "AmethystL_5", Vector3.new(0.14, 0.32, 0.14), CFrame.new(0, -1.72, 0.54) * CFrame.Angles(-math.rad(50), math.rad(30), 0), amethystCrystal, Enum.Material.Glass)
	weldTo(handle, shardL5)
	local shardL6 = makePart(model, "AmethystL_6", Vector3.new(0.12, 0.34, 0.12), CFrame.new(0, -1.96, 0.80) * CFrame.Angles(-math.rad(62), math.rad(30), 0), amethystPale, Enum.Material.Glass)
	weldTo(handle, shardL6)

	-- Lower Crystal Accent Thorns
	local thornL1 = makePart(model, "ThornL_1", Vector3.new(0.06, 0.16, 0.10), CFrame.new(0.12, -0.98, 0.08) * CFrame.Angles(-math.rad(19), math.rad(35), 0), amethystCrystal, Enum.Material.Glass)
	weldTo(handle, thornL1)
	local thornL2 = makePart(model, "ThornL_2", Vector3.new(0.06, 0.16, 0.10), CFrame.new(-0.12, -0.98, 0.08) * CFrame.Angles(-math.rad(19), -math.rad(35), 0), amethystCrystal, Enum.Material.Glass)
	weldTo(handle, thornL2)

	-- Lower Prism Tip Assembly
	local tipL1 = makePart(model, "PrismTipL_1", Vector3.new(0.14, 0.22, 0.14), CFrame.new(0, -2.12, 0.96) * CFrame.Angles(-math.rad(70), 0, 0), platinumSilver, Enum.Material.Metal)
	weldTo(handle, tipL1)
	local tipL2 = makePart(model, "PrismTipL_2", Vector3.new(0.08, 0.24, 0.08), CFrame.new(0, -2.24, 1.08) * CFrame.Angles(-math.rad(76), 0, 0), amethystPale, Enum.Material.Glass)
	weldTo(handle, tipL2)

	-- Harmonic Silver Bowstring
	local bowString = makePart(model, "BowString", Vector3.new(0.045, 4.46, 0.045), CFrame.new(0, 0, 1.04), stringColor, Enum.Material.Fabric)
	weldTo(handle, bowString)

	addSocket(handle, "Grip", Vector3.zero)
	addSocket(handle, "Nock", Vector3.new(ARROW_REST.X, ARROW_REST.Y, 1.04))
	addSocket(handle, "TipUpper", Vector3.new(0, 2.24, 1.08))
	addSocket(handle, "TipLower", Vector3.new(0, -2.24, 1.08))
	addSocket(handle, "VfxTip", Vector3.new(0, 2.24, 1.08))
	addSocket(handle, "VfxBase", Vector3.new(0, -2.24, 1.08))
	addSocket(handle, "VfxCore", Vector3.zero)
	addSocket(handle, "VfxNock", Vector3.new(ARROW_REST.X, ARROW_REST.Y, 1.04))

	createHunterArrow(model, handle)
	return model
end

-- ============================================================================
-- 8. Prismatic Arbalest (art_prismatic_arbalest) - Superior Enhanced
-- ============================================================================
function WeaponModelBuilder.BuildPrismaticArbalest(): Model
	local model = Instance.new("Model")
	model.Name = "art_prismatic_arbalest"

	local darkMagnesium = Color3.fromRGB(55, 60, 68)
	local anodizedRed = Color3.fromRGB(185, 45, 55)
	local brassCam = Color3.fromRGB(215, 175, 75)
	local carbonBlack = Color3.fromRGB(28, 28, 30)
	local opticGreen = Color3.fromRGB(80, 235, 120)
	local opticAmber = Color3.fromRGB(245, 160, 40)
	local stringColor = Color3.fromRGB(220, 225, 235)

	-- CNC Machined Skeleton Riser
	local handle = makePart(model, "Handle", Vector3.new(0.26, 0.76, 0.34), CFrame.new(0, 0, 0), darkMagnesium, Enum.Material.Metal)
	model.PrimaryPart = handle

	-- Skeleton Window Cutouts (4 parts)
	local win1 = makePart(model, "Window_1", Vector3.new(0.28, 0.08, 0.16), CFrame.new(0, 0.22, 0.04), carbonBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, win1)
	local win2 = makePart(model, "Window_2", Vector3.new(0.28, 0.08, 0.16), CFrame.new(0, 0.08, 0.04), carbonBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, win2)
	local win3 = makePart(model, "Window_3", Vector3.new(0.28, 0.08, 0.16), CFrame.new(0, -0.08, 0.04), carbonBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, win3)
	local win4 = makePart(model, "Window_4", Vector3.new(0.28, 0.08, 0.16), CFrame.new(0, -0.22, 0.04), carbonBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, win4)

	-- Riser Machined Truss Ribs
	local ribM1 = makePart(model, "TrussRib_1", Vector3.new(0.06, 0.24, 0.06), CFrame.new(0.10, 0.15, -0.04), anodizedRed, Enum.Material.Metal)
	weldTo(handle, ribM1)
	local ribM2 = makePart(model, "TrussRib_2", Vector3.new(0.06, 0.24, 0.06), CFrame.new(0.10, -0.15, -0.04), anodizedRed, Enum.Material.Metal)
	weldTo(handle, ribM2)

	-- Multi-Pin Optical Sight Bracket & Pins (Green + Amber)
	local sightBracket = makePart(model, "SightBracket", Vector3.new(0.06, 0.22, 0.18), CFrame.new(0.18, 0.14, -0.10), darkMagnesium, Enum.Material.Metal)
	weldTo(handle, sightBracket)
	local sightRing = makePart(model, "SightRing", Vector3.new(0.04, 0.18, 0.18), CFrame.new(0.22, 0.14, -0.16), anodizedRed, Enum.Material.Metal)
	weldTo(handle, sightRing)
	local sightPin1 = makePart(model, "SightPin_1", Vector3.new(0.03, 0.06, 0.03), CFrame.new(0.22, 0.16, -0.16), opticGreen, Enum.Material.Neon)
	weldTo(handle, sightPin1)
	local sightPin2 = makePart(model, "SightPin_2", Vector3.new(0.03, 0.06, 0.03), CFrame.new(0.22, 0.12, -0.16), opticAmber, Enum.Material.Neon)
	weldTo(handle, sightPin2)

	-- Forward Stabilizer Rod, Bushing & Weighted Dampener
	local stabMount = makePart(model, "StabMount", Vector3.new(0.12, 0.12, 0.08), CFrame.new(0, 0, -0.16), anodizedRed, Enum.Material.Metal)
	weldTo(handle, stabMount)
	local stabRod = makePart(model, "StabRod", Vector3.new(0.06, 0.06, 0.44), CFrame.new(0, 0, -0.38), darkMagnesium, Enum.Material.Metal)
	weldTo(handle, stabRod)
	local stabWeight = makePart(model, "StabWeight", Vector3.new(0.14, 0.14, 0.12), CFrame.new(0, 0, -0.66), anodizedRed, Enum.Material.Metal)
	weldTo(handle, stabWeight)

	-- Limb Hinge Pockets & Anodized Washers
	local pocketU = makePart(model, "LimbPocket_U", Vector3.new(0.28, 0.12, 0.28), CFrame.new(0, 0.42, 0.04), anodizedRed, Enum.Material.Metal)
	weldTo(handle, pocketU)
	local washerU = makePart(model, "PocketWasher_U", Vector3.new(0.24, 0.04, 0.12), CFrame.new(0, 0.48, 0.04), brassCam, Enum.Material.Metal)
	weldTo(handle, washerU)

	local pocketL = makePart(model, "LimbPocket_L", Vector3.new(0.28, 0.12, 0.28), CFrame.new(0, -0.42, 0.04), anodizedRed, Enum.Material.Metal)
	weldTo(handle, pocketL)
	local washerL = makePart(model, "PocketWasher_L", Vector3.new(0.24, 0.04, 0.12), CFrame.new(0, -0.48, 0.04), brassCam, Enum.Material.Metal)
	weldTo(handle, washerL)

	-- Quad Split Limbs: Upper Left & Right (parallel beams, 3 segments each)
	local ul_L1 = makePart(model, "SplitU_L1", Vector3.new(0.08, 0.36, 0.14), CFrame.new(0.09, 0.62, 0.06) * CFrame.Angles(math.rad(8), 0, 0), carbonBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, ul_L1)
	local ul_L2 = makePart(model, "SplitU_L2", Vector3.new(0.07, 0.36, 0.12), CFrame.new(0.09, 0.94, 0.13) * CFrame.Angles(math.rad(18), 0, 0), carbonBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, ul_L2)
	local ul_L3 = makePart(model, "SplitU_L3", Vector3.new(0.06, 0.38, 0.10), CFrame.new(0.09, 1.26, 0.28) * CFrame.Angles(math.rad(30), 0, 0), darkMagnesium, Enum.Material.Metal)
	weldTo(handle, ul_L3)

	local ul_R1 = makePart(model, "SplitU_R1", Vector3.new(0.08, 0.36, 0.14), CFrame.new(-0.09, 0.62, 0.06) * CFrame.Angles(math.rad(8), 0, 0), carbonBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, ul_R1)
	local ul_R2 = makePart(model, "SplitU_R2", Vector3.new(0.07, 0.36, 0.12), CFrame.new(-0.09, 0.94, 0.13) * CFrame.Angles(math.rad(18), 0, 0), carbonBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, ul_R2)
	local ul_R3 = makePart(model, "SplitU_R3", Vector3.new(0.06, 0.38, 0.10), CFrame.new(-0.09, 1.26, 0.28) * CFrame.Angles(math.rad(30), 0, 0), darkMagnesium, Enum.Material.Metal)
	weldTo(handle, ul_R3)

	-- Upper Limb Dampener Pods
	local dampU_L = makePart(model, "DampenerU_L", Vector3.new(0.06, 0.12, 0.10), CFrame.new(0.12, 0.94, 0.13), anodizedRed, Enum.Material.SmoothPlastic)
	weldTo(handle, dampU_L)
	local dampU_R = makePart(model, "DampenerU_R", Vector3.new(0.06, 0.12, 0.10), CFrame.new(-0.12, 0.94, 0.13), anodizedRed, Enum.Material.SmoothPlastic)
	weldTo(handle, dampU_R)

	-- Upper Multi-Lobe Eccentric Cam Assembly
	local camDiscU = makePart(model, "CamU_Disc", Vector3.new(0.06, 0.28, 0.28), CFrame.new(0, 1.48, 0.44) * CFrame.Angles(math.rad(30), 0, 0), brassCam, Enum.Material.Metal)
	weldTo(handle, camDiscU)
	local camLobeU = makePart(model, "CamU_Lobe", Vector3.new(0.08, 0.18, 0.22), CFrame.new(0, 1.54, 0.50) * CFrame.Angles(math.rad(45), 0, 0), anodizedRed, Enum.Material.Metal)
	weldTo(handle, camLobeU)
	local camAxleU = makePart(model, "CamU_Axle", Vector3.new(0.24, 0.04, 0.04), CFrame.new(0, 1.48, 0.44), darkMagnesium, Enum.Material.Metal)
	weldTo(handle, camAxleU)
	local camBearU = makePart(model, "CamU_Bearing", Vector3.new(0.10, 0.08, 0.08), CFrame.new(0, 1.48, 0.44), brassCam, Enum.Material.Metal)
	weldTo(handle, camBearU)

	-- Quad Split Limbs: Lower Left & Right
	local ll_L1 = makePart(model, "SplitL_L1", Vector3.new(0.08, 0.36, 0.14), CFrame.new(0.09, -0.62, 0.06) * CFrame.Angles(-math.rad(8), 0, 0), carbonBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, ll_L1)
	local ll_L2 = makePart(model, "SplitL_L2", Vector3.new(0.07, 0.36, 0.12), CFrame.new(0.09, -0.94, 0.13) * CFrame.Angles(-math.rad(18), 0, 0), carbonBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, ll_L2)
	local ll_L3 = makePart(model, "SplitL_L3", Vector3.new(0.06, 0.38, 0.10), CFrame.new(0.09, -1.26, 0.28) * CFrame.Angles(-math.rad(30), 0, 0), darkMagnesium, Enum.Material.Metal)
	weldTo(handle, ll_L3)

	local ll_R1 = makePart(model, "SplitL_R1", Vector3.new(0.08, 0.36, 0.14), CFrame.new(-0.09, -0.62, 0.06) * CFrame.Angles(-math.rad(8), 0, 0), carbonBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, ll_R1)
	local ll_R2 = makePart(model, "SplitL_R2", Vector3.new(0.07, 0.36, 0.12), CFrame.new(-0.09, -0.94, 0.13) * CFrame.Angles(-math.rad(18), 0, 0), carbonBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, ll_R2)
	local ll_R3 = makePart(model, "SplitL_R3", Vector3.new(0.06, 0.38, 0.10), CFrame.new(-0.09, -1.26, 0.28) * CFrame.Angles(-math.rad(30), 0, 0), darkMagnesium, Enum.Material.Metal)
	weldTo(handle, ll_R3)

	-- Lower Limb Dampener Pods
	local dampL_L = makePart(model, "DampenerL_L", Vector3.new(0.06, 0.12, 0.10), CFrame.new(0.12, -0.94, 0.13), anodizedRed, Enum.Material.SmoothPlastic)
	weldTo(handle, dampL_L)
	local dampL_R = makePart(model, "DampenerL_R", Vector3.new(0.06, 0.12, 0.10), CFrame.new(-0.12, -0.94, 0.13), anodizedRed, Enum.Material.SmoothPlastic)
	weldTo(handle, dampL_R)

	-- Lower Multi-Lobe Eccentric Cam Assembly
	local camDiscL = makePart(model, "CamL_Disc", Vector3.new(0.06, 0.28, 0.28), CFrame.new(0, -1.48, 0.44) * CFrame.Angles(-math.rad(30), 0, 0), brassCam, Enum.Material.Metal)
	weldTo(handle, camDiscL)
	local camLobeL = makePart(model, "CamL_Lobe", Vector3.new(0.08, 0.18, 0.22), CFrame.new(0, -1.54, 0.50) * CFrame.Angles(-math.rad(45), 0, 0), anodizedRed, Enum.Material.Metal)
	weldTo(handle, camLobeL)
	local camAxleL = makePart(model, "CamL_Axle", Vector3.new(0.24, 0.04, 0.04), CFrame.new(0, -1.48, 0.44), darkMagnesium, Enum.Material.Metal)
	weldTo(handle, camAxleL)
	local camBearL = makePart(model, "CamL_Bearing", Vector3.new(0.10, 0.08, 0.08), CFrame.new(0, -1.48, 0.44), brassCam, Enum.Material.Metal)
	weldTo(handle, camBearL)

	-- Cable Guard Rod, Slider Block & Dual Buss Cables
	local cableRod = makePart(model, "CableGuardRod", Vector3.new(0.04, 0.04, 0.44), CFrame.new(-0.12, 0.10, 0.28), darkMagnesium, Enum.Material.Metal)
	weldTo(handle, cableRod)
	local cableSlide = makePart(model, "CableSlider", Vector3.new(0.08, 0.08, 0.08), CFrame.new(-0.12, 0.10, 0.38), anodizedRed, Enum.Material.Metal)
	weldTo(handle, cableSlide)

	local buss1 = makePart(model, "BussCable_1", Vector3.new(0.03, 3.00, 0.03), CFrame.new(-0.10, 0, 0.40) * CFrame.Angles(math.rad(6), 0, 0), stringColor, Enum.Material.Fabric)
	weldTo(handle, buss1)
	local buss2 = makePart(model, "BussCable_2", Vector3.new(0.03, 3.00, 0.03), CFrame.new(-0.14, 0, 0.40) * CFrame.Angles(-math.rad(6), 0, 0), stringColor, Enum.Material.Fabric)
	weldTo(handle, buss2)
	local silencer1 = makePart(model, "StringSilencer_1", Vector3.new(0.08, 0.08, 0.08), CFrame.new(0, 0.60, 0.58), carbonBlack, Enum.Material.Fabric)
	weldTo(handle, silencer1)
	local silencer2 = makePart(model, "StringSilencer_2", Vector3.new(0.08, 0.08, 0.08), CFrame.new(0, -0.60, 0.58), carbonBlack, Enum.Material.Fabric)
	weldTo(handle, silencer2)

	-- Main Power String
	local bowString = makePart(model, "BowString", Vector3.new(0.045, 3.12, 0.045), CFrame.new(0, 0, 0.58), stringColor, Enum.Material.Fabric)
	weldTo(handle, bowString)

	addSocket(handle, "Grip", Vector3.zero)
	addSocket(handle, "Nock", Vector3.new(ARROW_REST.X, ARROW_REST.Y, 0.58))
	addSocket(handle, "TipUpper", Vector3.new(0, 1.54, 0.58))
	addSocket(handle, "TipLower", Vector3.new(0, -1.54, 0.58))
	addSocket(handle, "VfxTip", Vector3.new(0, 1.54, 0.58))
	addSocket(handle, "VfxBase", Vector3.new(0, -1.54, 0.58))
	addSocket(handle, "VfxCore", Vector3.zero)
	addSocket(handle, "VfxNock", Vector3.new(ARROW_REST.X, ARROW_REST.Y, 0.58))

	createHunterArrow(model, handle)
	return model
end

-- ============================================================================
-- 9. Phoenix Flatbow (art_phoenix_flatbow) - Exalted Standard
-- ============================================================================
function WeaponModelBuilder.BuildPhoenixFlatbow(): Model
	local model = Instance.new("Model")
	model.Name = "art_phoenix_flatbow"

	local solarGold = Color3.fromRGB(245, 185, 45)
	local carmineRed = Color3.fromRGB(180, 35, 40)
	local flameOrange = Color3.fromRGB(235, 105, 30)
	local volcanicAsh = Color3.fromRGB(45, 40, 42)
	local rubyGlow = Color3.fromRGB(255, 60, 80)
	local stringColor = Color3.fromRGB(255, 205, 120)

	-- Golden Phoenix Claw Riser & Ruby Heart
	local handle = makePart(model, "Handle", Vector3.new(0.26, 0.76, 0.32), CFrame.new(0, 0, 0), solarGold, Enum.Material.Metal)
	model.PrimaryPart = handle

	local rubyHeart = makePart(model, "RubyHeartGem", Vector3.new(0.12, 0.16, 0.14), CFrame.new(0, 0.05, -0.10), rubyGlow, Enum.Material.Neon)
	weldTo(handle, rubyHeart)
	local breastplate = makePart(model, "CrestBreastplate", Vector3.new(0.22, 0.28, 0.08), CFrame.new(0, 0.12, -0.06), solarGold, Enum.Material.Metal)
	weldTo(handle, breastplate)
	local emberCore = makePart(model, "EmberCoreGlow", Vector3.new(0.10, 0.10, 0.10), CFrame.new(0, -0.12, -0.08), flameOrange, Enum.Material.Neon)
	weldTo(handle, emberCore)

	local talon1 = makePart(model, "Talon_1", Vector3.new(0.08, 0.14, 0.12), CFrame.new(0.12, 0.22, 0.08) * CFrame.Angles(0, math.rad(25), 0), volcanicAsh, Enum.Material.SmoothPlastic)
	weldTo(handle, talon1)
	local talon2 = makePart(model, "Talon_2", Vector3.new(0.08, 0.14, 0.12), CFrame.new(-0.12, 0.22, 0.08) * CFrame.Angles(0, -math.rad(25), 0), volcanicAsh, Enum.Material.SmoothPlastic)
	weldTo(handle, talon2)
	local talon3 = makePart(model, "Talon_3", Vector3.new(0.08, 0.14, 0.12), CFrame.new(0.12, -0.22, 0.08) * CFrame.Angles(0, math.rad(25), 0), volcanicAsh, Enum.Material.SmoothPlastic)
	weldTo(handle, talon3)
	local talon4 = makePart(model, "Talon_4", Vector3.new(0.08, 0.14, 0.12), CFrame.new(-0.12, -0.22, 0.08) * CFrame.Angles(0, -math.rad(25), 0), volcanicAsh, Enum.Material.SmoothPlastic)
	weldTo(handle, talon4)
	local arrowRest = makePart(model, "PhoenixArrowRest", Vector3.new(0.08, 0.14, 0.18), CFrame.new(0.15, 0.09, -0.08), solarGold, Enum.Material.Metal)
	weldTo(handle, arrowRest)

	-- Upper Carmine Core Stave (6 segments)
	local cu1 = makePart(model, "CoreU_1", Vector3.new(0.24, 0.34, 0.22), CFrame.new(0, 0.48, 0.02) * CFrame.Angles(math.rad(5), 0, 0), carmineRed, Enum.Material.SmoothPlastic)
	weldTo(handle, cu1)
	local cu2 = makePart(model, "CoreU_2", Vector3.new(0.22, 0.34, 0.20), CFrame.new(0, 0.78, 0.06) * CFrame.Angles(math.rad(11), 0, 0), carmineRed, Enum.Material.SmoothPlastic)
	weldTo(handle, cu2)
	local cu3 = makePart(model, "CoreU_3", Vector3.new(0.20, 0.34, 0.18), CFrame.new(0, 1.08, 0.13) * CFrame.Angles(math.rad(18), 0, 0), carmineRed, Enum.Material.SmoothPlastic)
	weldTo(handle, cu3)
	local cu4 = makePart(model, "CoreU_4", Vector3.new(0.18, 0.34, 0.16), CFrame.new(0, 1.36, 0.24) * CFrame.Angles(math.rad(27), 0, 0), carmineRed, Enum.Material.SmoothPlastic)
	weldTo(handle, cu4)
	local cu5 = makePart(model, "CoreU_5", Vector3.new(0.16, 0.34, 0.14), CFrame.new(0, 1.62, 0.38) * CFrame.Angles(math.rad(38), 0, 0), carmineRed, Enum.Material.SmoothPlastic)
	weldTo(handle, cu5)
	local cu6 = makePart(model, "CoreU_6", Vector3.new(0.14, 0.36, 0.12), CFrame.new(0, 1.86, 0.56) * CFrame.Angles(math.rad(50), 0, 0), carmineRed, Enum.Material.SmoothPlastic)
	weldTo(handle, cu6)

	-- Upper Tiered Splayed Feather Blades
	local plumeU1_1 = makePart(model, "PlumeU1_Base", Vector3.new(0.06, 0.28, 0.18), CFrame.new(0.12, 0.76, -0.04) * CFrame.Angles(math.rad(10), math.rad(25), 0), flameOrange, Enum.Material.SmoothPlastic)
	weldTo(handle, plumeU1_1)
	local plumeU1_2 = makePart(model, "PlumeU1_Tip", Vector3.new(0.04, 0.24, 0.14), CFrame.new(0.16, 0.96, -0.06) * CFrame.Angles(math.rad(18), math.rad(35), 0), solarGold, Enum.Material.Metal)
	weldTo(handle, plumeU1_2)

	local plumeU2_1 = makePart(model, "PlumeU2_Base", Vector3.new(0.06, 0.28, 0.18), CFrame.new(-0.12, 0.76, -0.04) * CFrame.Angles(math.rad(10), -math.rad(25), 0), flameOrange, Enum.Material.SmoothPlastic)
	weldTo(handle, plumeU2_1)
	local plumeU2_2 = makePart(model, "PlumeU2_Tip", Vector3.new(0.04, 0.24, 0.14), CFrame.new(-0.16, 0.96, -0.06) * CFrame.Angles(math.rad(18), -math.rad(35), 0), solarGold, Enum.Material.Metal)
	weldTo(handle, plumeU2_2)

	local plumeU3_1 = makePart(model, "PlumeU3_Base", Vector3.new(0.06, 0.30, 0.18), CFrame.new(0.14, 1.32, 0.12) * CFrame.Angles(math.rad(25), math.rad(25), 0), flameOrange, Enum.Material.SmoothPlastic)
	weldTo(handle, plumeU3_1)
	local plumeU3_2 = makePart(model, "PlumeU3_Tip", Vector3.new(0.04, 0.26, 0.14), CFrame.new(0.18, 1.54, 0.16) * CFrame.Angles(math.rad(36), math.rad(35), 0), solarGold, Enum.Material.Metal)
	weldTo(handle, plumeU3_2)

	local plumeU4_1 = makePart(model, "PlumeU4_Base", Vector3.new(0.06, 0.30, 0.18), CFrame.new(-0.14, 1.32, 0.12) * CFrame.Angles(math.rad(25), -math.rad(25), 0), flameOrange, Enum.Material.SmoothPlastic)
	weldTo(handle, plumeU4_1)
	local plumeU4_2 = makePart(model, "PlumeU4_Tip", Vector3.new(0.04, 0.26, 0.14), CFrame.new(-0.18, 1.54, 0.16) * CFrame.Angles(math.rad(36), -math.rad(35), 0), solarGold, Enum.Material.Metal)
	weldTo(handle, plumeU4_2)

	local featherU_A = makePart(model, "FeatherEdgeU_1", Vector3.new(0.04, 0.26, 0.10), CFrame.new(0.16, 1.05, 0.06) * CFrame.Angles(math.rad(20), math.rad(30), 0), solarGold, Enum.Material.Metal)
	weldTo(handle, featherU_A)
	local featherU_B = makePart(model, "FeatherEdgeU_2", Vector3.new(0.04, 0.26, 0.10), CFrame.new(-0.16, 1.05, 0.06) * CFrame.Angles(math.rad(20), -math.rad(30), 0), solarGold, Enum.Material.Metal)
	weldTo(handle, featherU_B)
	local featherU_C = makePart(model, "FeatherEdgeU_3", Vector3.new(0.04, 0.26, 0.10), CFrame.new(0.18, 1.70, 0.30) * CFrame.Angles(math.rad(42), math.rad(30), 0), solarGold, Enum.Material.Metal)
	weldTo(handle, featherU_C)
	local featherU_D = makePart(model, "FeatherEdgeU_4", Vector3.new(0.04, 0.26, 0.10), CFrame.new(-0.18, 1.70, 0.30) * CFrame.Angles(math.rad(42), -math.rad(30), 0), solarGold, Enum.Material.Metal)
	weldTo(handle, featherU_D)

	-- Upper Gold Filigree Trim Ribs & Heat Channels
	local trimU1 = makePart(model, "TrimU_1", Vector3.new(0.06, 0.34, 0.08), CFrame.new(0, 0.78, 0.12) * CFrame.Angles(math.rad(11), 0, 0), solarGold, Enum.Material.Metal)
	weldTo(handle, trimU1)
	local trimU2 = makePart(model, "TrimU_2", Vector3.new(0.05, 0.34, 0.08), CFrame.new(0, 1.36, 0.30) * CFrame.Angles(math.rad(27), 0, 0), solarGold, Enum.Material.Metal)
	weldTo(handle, trimU2)
	local channelU = makePart(model, "SolarChannel_U", Vector3.new(0.05, 0.80, 0.05), CFrame.new(0, 1.10, -0.04) * CFrame.Angles(math.rad(18), 0, 0), rubyGlow, Enum.Material.Neon)
	weldTo(handle, channelU)

	-- Upper Eagle-Beak Crown Tips
	local beakBaseU = makePart(model, "BeakU_Base", Vector3.new(0.14, 0.22, 0.14), CFrame.new(0, 2.06, 0.70) * CFrame.Angles(math.rad(60), 0, 0), solarGold, Enum.Material.Metal)
	weldTo(handle, beakBaseU)
	local beakHookU = makePart(model, "BeakU_Hook", Vector3.new(0.08, 0.22, 0.12), CFrame.new(0, 2.18, 0.82) * CFrame.Angles(math.rad(72), 0, 0), volcanicAsh, Enum.Material.SmoothPlastic)
	weldTo(handle, beakHookU)
	local beakCombU = makePart(model, "BeakU_Comb", Vector3.new(0.04, 0.16, 0.12), CFrame.new(0, 2.02, 0.82) * CFrame.Angles(math.rad(40), 0, 0), rubyGlow, Enum.Material.Neon)
	weldTo(handle, beakCombU)

	-- Lower Carmine Core Stave (6 segments)
	local cl1 = makePart(model, "CoreL_1", Vector3.new(0.24, 0.34, 0.22), CFrame.new(0, -0.48, 0.02) * CFrame.Angles(-math.rad(5), 0, 0), carmineRed, Enum.Material.SmoothPlastic)
	weldTo(handle, cl1)
	local cl2 = makePart(model, "CoreL_2", Vector3.new(0.22, 0.34, 0.20), CFrame.new(0, -0.78, 0.06) * CFrame.Angles(-math.rad(11), 0, 0), carmineRed, Enum.Material.SmoothPlastic)
	weldTo(handle, cl2)
	local cl3 = makePart(model, "CoreL_3", Vector3.new(0.20, 0.34, 0.18), CFrame.new(0, -1.08, 0.13) * CFrame.Angles(-math.rad(18), 0, 0), carmineRed, Enum.Material.SmoothPlastic)
	weldTo(handle, cl3)
	local cl4 = makePart(model, "CoreL_4", Vector3.new(0.18, 0.34, 0.16), CFrame.new(0, -1.36, 0.24) * CFrame.Angles(-math.rad(27), 0, 0), carmineRed, Enum.Material.SmoothPlastic)
	weldTo(handle, cl4)
	local cl5 = makePart(model, "CoreL_5", Vector3.new(0.16, 0.34, 0.14), CFrame.new(0, -1.62, 0.38) * CFrame.Angles(-math.rad(38), 0, 0), carmineRed, Enum.Material.SmoothPlastic)
	weldTo(handle, cl5)
	local cl6 = makePart(model, "CoreL_6", Vector3.new(0.14, 0.36, 0.12), CFrame.new(0, -1.86, 0.56) * CFrame.Angles(-math.rad(50), 0, 0), carmineRed, Enum.Material.SmoothPlastic)
	weldTo(handle, cl6)

	-- Lower Tiered Splayed Feather Blades
	local plumeL1_1 = makePart(model, "PlumeL1_Base", Vector3.new(0.06, 0.28, 0.18), CFrame.new(0.12, -0.76, -0.04) * CFrame.Angles(-math.rad(10), math.rad(25), 0), flameOrange, Enum.Material.SmoothPlastic)
	weldTo(handle, plumeL1_1)
	local plumeL1_2 = makePart(model, "PlumeL1_Tip", Vector3.new(0.04, 0.24, 0.14), CFrame.new(0.16, -0.96, -0.06) * CFrame.Angles(-math.rad(18), math.rad(35), 0), solarGold, Enum.Material.Metal)
	weldTo(handle, plumeL1_2)

	local plumeL2_1 = makePart(model, "PlumeL2_Base", Vector3.new(0.06, 0.28, 0.18), CFrame.new(-0.12, -0.76, -0.04) * CFrame.Angles(-math.rad(10), -math.rad(25), 0), flameOrange, Enum.Material.SmoothPlastic)
	weldTo(handle, plumeL2_1)
	local plumeL2_2 = makePart(model, "PlumeL2_Tip", Vector3.new(0.04, 0.24, 0.14), CFrame.new(-0.16, -0.96, -0.06) * CFrame.Angles(-math.rad(18), -math.rad(35), 0), solarGold, Enum.Material.Metal)
	weldTo(handle, plumeL2_2)

	local plumeL3_1 = makePart(model, "PlumeL3_Base", Vector3.new(0.06, 0.30, 0.18), CFrame.new(0.14, -1.32, 0.12) * CFrame.Angles(-math.rad(25), math.rad(25), 0), flameOrange, Enum.Material.SmoothPlastic)
	weldTo(handle, plumeL3_1)
	local plumeL3_2 = makePart(model, "PlumeL3_Tip", Vector3.new(0.04, 0.26, 0.14), CFrame.new(0.18, -1.54, 0.16) * CFrame.Angles(-math.rad(36), math.rad(35), 0), solarGold, Enum.Material.Metal)
	weldTo(handle, plumeL3_2)

	local plumeL4_1 = makePart(model, "PlumeL4_Base", Vector3.new(0.06, 0.30, 0.18), CFrame.new(-0.14, -1.32, 0.12) * CFrame.Angles(-math.rad(25), -math.rad(25), 0), flameOrange, Enum.Material.SmoothPlastic)
	weldTo(handle, plumeL4_1)
	local plumeL4_2 = makePart(model, "PlumeL4_Tip", Vector3.new(0.04, 0.26, 0.14), CFrame.new(-0.18, -1.54, 0.16) * CFrame.Angles(-math.rad(36), -math.rad(35), 0), solarGold, Enum.Material.Metal)
	weldTo(handle, plumeL4_2)

	local featherL_A = makePart(model, "FeatherEdgeL_1", Vector3.new(0.04, 0.26, 0.10), CFrame.new(0.16, -1.05, 0.06) * CFrame.Angles(-math.rad(20), math.rad(30), 0), solarGold, Enum.Material.Metal)
	weldTo(handle, featherL_A)
	local featherL_B = makePart(model, "FeatherEdgeL_2", Vector3.new(0.04, 0.26, 0.10), CFrame.new(-0.16, -1.05, 0.06) * CFrame.Angles(-math.rad(20), -math.rad(30), 0), solarGold, Enum.Material.Metal)
	weldTo(handle, featherL_B)
	local featherL_C = makePart(model, "FeatherEdgeL_3", Vector3.new(0.04, 0.26, 0.10), CFrame.new(0.18, -1.70, 0.30) * CFrame.Angles(-math.rad(42), math.rad(30), 0), solarGold, Enum.Material.Metal)
	weldTo(handle, featherL_C)
	local featherL_D = makePart(model, "FeatherEdgeL_4", Vector3.new(0.04, 0.26, 0.10), CFrame.new(-0.18, -1.70, 0.30) * CFrame.Angles(-math.rad(42), -math.rad(30), 0), solarGold, Enum.Material.Metal)
	weldTo(handle, featherL_D)

	-- Lower Gold Filigree Trim Ribs & Heat Channels
	local trimL1 = makePart(model, "TrimL_1", Vector3.new(0.06, 0.34, 0.08), CFrame.new(0, -0.78, 0.12) * CFrame.Angles(-math.rad(11), 0, 0), solarGold, Enum.Material.Metal)
	weldTo(handle, trimL1)
	local trimL2 = makePart(model, "TrimL_2", Vector3.new(0.05, 0.34, 0.08), CFrame.new(0, -1.36, 0.30) * CFrame.Angles(-math.rad(27), 0, 0), solarGold, Enum.Material.Metal)
	weldTo(handle, trimL2)
	local channelL = makePart(model, "SolarChannel_L", Vector3.new(0.05, 0.80, 0.05), CFrame.new(0, -1.10, -0.04) * CFrame.Angles(-math.rad(18), 0, 0), rubyGlow, Enum.Material.Neon)
	weldTo(handle, channelL)

	-- Lower Eagle-Beak Crown Tips
	local beakBaseL = makePart(model, "BeakL_Base", Vector3.new(0.14, 0.22, 0.14), CFrame.new(0, -2.06, 0.70) * CFrame.Angles(-math.rad(60), 0, 0), solarGold, Enum.Material.Metal)
	weldTo(handle, beakBaseL)
	local beakHookL = makePart(model, "BeakL_Hook", Vector3.new(0.08, 0.22, 0.12), CFrame.new(0, -2.18, 0.82) * CFrame.Angles(-math.rad(72), 0, 0), volcanicAsh, Enum.Material.SmoothPlastic)
	weldTo(handle, beakHookL)
	local beakCombL = makePart(model, "BeakL_Comb", Vector3.new(0.04, 0.16, 0.12), CFrame.new(0, -2.02, 0.82) * CFrame.Angles(-math.rad(40), 0, 0), rubyGlow, Enum.Material.Neon)
	weldTo(handle, beakCombL)

	-- Spun Solar Flame Bowstring
	local bowString = makePart(model, "BowString", Vector3.new(0.045, 4.36, 0.045), CFrame.new(0, 0, 0.78), stringColor, Enum.Material.Fabric)
	weldTo(handle, bowString)

	addSocket(handle, "Grip", Vector3.zero)
	addSocket(handle, "Nock", Vector3.new(ARROW_REST.X, ARROW_REST.Y, 0.78))
	addSocket(handle, "TipUpper", Vector3.new(0, 2.18, 0.82))
	addSocket(handle, "TipLower", Vector3.new(0, -2.18, 0.82))
	addSocket(handle, "VfxTip", Vector3.new(0, 2.18, 0.82))
	addSocket(handle, "VfxBase", Vector3.new(0, -2.18, 0.82))
	addSocket(handle, "VfxCore", Vector3.zero)
	addSocket(handle, "VfxNock", Vector3.new(ARROW_REST.X, ARROW_REST.Y, 0.78))

	createHunterArrow(model, handle)
	return model
end

-- ============================================================================
-- 10. Solar Flare Recurve (art_solar_flare_recurve) - Exalted Enhanced
-- ============================================================================
function WeaponModelBuilder.BuildSolarFlareRecurve(): Model
	local model = Instance.new("Model")
	model.Name = "art_solar_flare_recurve"

	local auricGold = Color3.fromRGB(245, 195, 55)
	local solarBronze = Color3.fromRGB(175, 105, 45)
	local coronaGlow = Color3.fromRGB(255, 155, 40)
	local heatWhite = Color3.fromRGB(255, 240, 200)
	local copperPipe = Color3.fromRGB(215, 115, 55)
	local darkRadiator = Color3.fromRGB(45, 38, 35)
	local stringColor = Color3.fromRGB(255, 230, 160)

	-- Auric Bronze Sunburst Hub (Center Core + 6 Radial Rays)
	local handle = makePart(model, "Handle", Vector3.new(0.26, 0.74, 0.32), CFrame.new(0, 0, 0), solarBronze, Enum.Material.Metal)
	model.PrimaryPart = handle

	local sunHub = makePart(model, "SunburstHub", Vector3.new(0.32, 0.32, 0.16), CFrame.new(0, 0, -0.06), auricGold, Enum.Material.Metal)
	weldTo(handle, sunHub)
	local hubCore = makePart(model, "HubCoreGlow", Vector3.new(0.18, 0.18, 0.18), CFrame.new(0, 0, -0.08), heatWhite, Enum.Material.Neon)
	weldTo(handle, hubCore)

	local ray1 = makePart(model, "Ray_1", Vector3.new(0.06, 0.22, 0.08), CFrame.new(0.18, 0.18, -0.06) * CFrame.Angles(0, 0, -math.rad(45)), auricGold, Enum.Material.Metal)
	weldTo(handle, ray1)
	local ray2 = makePart(model, "Ray_2", Vector3.new(0.06, 0.22, 0.08), CFrame.new(-0.18, 0.18, -0.06) * CFrame.Angles(0, 0, math.rad(45)), auricGold, Enum.Material.Metal)
	weldTo(handle, ray2)
	local ray3 = makePart(model, "Ray_3", Vector3.new(0.06, 0.22, 0.08), CFrame.new(0.18, -0.18, -0.06) * CFrame.Angles(0, 0, math.rad(45)), auricGold, Enum.Material.Metal)
	weldTo(handle, ray3)
	local ray4 = makePart(model, "Ray_4", Vector3.new(0.06, 0.22, 0.08), CFrame.new(-0.18, -0.18, -0.06) * CFrame.Angles(0, 0, -math.rad(45)), auricGold, Enum.Material.Metal)
	weldTo(handle, ray4)
	local hubClamp1 = makePart(model, "HubClamp_1", Vector3.new(0.28, 0.05, 0.12), CFrame.new(0, 0.26, -0.04), solarBronze, Enum.Material.Metal)
	weldTo(handle, hubClamp1)
	local hubClamp2 = makePart(model, "HubClamp_2", Vector3.new(0.28, 0.05, 0.12), CFrame.new(0, -0.26, -0.04), solarBronze, Enum.Material.Metal)
	weldTo(handle, hubClamp2)
	local arrowRest = makePart(model, "SolarArrowRest", Vector3.new(0.08, 0.14, 0.18), CFrame.new(0.15, 0.09, -0.08), auricGold, Enum.Material.Metal)
	weldTo(handle, arrowRest)

	-- Upper Recurve Bronze Limbs (6 segments)
	local lu1 = makePart(model, "LimbU_1", Vector3.new(0.24, 0.34, 0.22), CFrame.new(0, 0.48, 0.02) * CFrame.Angles(math.rad(5), 0, 0), solarBronze, Enum.Material.Metal)
	weldTo(handle, lu1)
	local lu2 = makePart(model, "LimbU_2", Vector3.new(0.22, 0.34, 0.20), CFrame.new(0, 0.78, 0.06) * CFrame.Angles(math.rad(11), 0, 0), solarBronze, Enum.Material.Metal)
	weldTo(handle, lu2)
	local lu3 = makePart(model, "LimbU_3", Vector3.new(0.20, 0.34, 0.18), CFrame.new(0, 1.08, 0.14) * CFrame.Angles(math.rad(20), 0, 0), auricGold, Enum.Material.Metal)
	weldTo(handle, lu3)
	local lu4 = makePart(model, "LimbU_4", Vector3.new(0.18, 0.34, 0.16), CFrame.new(0, 1.36, 0.28) * CFrame.Angles(math.rad(32), 0, 0), auricGold, Enum.Material.Metal)
	weldTo(handle, lu4)
	local lu5 = makePart(model, "LimbU_5", Vector3.new(0.16, 0.34, 0.14), CFrame.new(0, 1.62, 0.46) * CFrame.Angles(math.rad(46), 0, 0), solarBronze, Enum.Material.Metal)
	weldTo(handle, lu5)
	local lu6 = makePart(model, "LimbU_6", Vector3.new(0.14, 0.36, 0.12), CFrame.new(0, 1.86, 0.68) * CFrame.Angles(math.rad(60), 0, 0), solarBronze, Enum.Material.Metal)
	weldTo(handle, lu6)

	-- Upper Miniature Solar Corona Disc (Center + 8 Pointed Rays)
	local coronaDiscU = makePart(model, "CoronaU_Center", Vector3.new(0.22, 0.22, 0.08), CFrame.new(0, 1.24, 0.18) * CFrame.Angles(math.rad(25), 0, 0), coronaGlow, Enum.Material.Neon)
	weldTo(handle, coronaDiscU)
	local cRayU1 = makePart(model, "CoronaU_Ray1", Vector3.new(0.05, 0.18, 0.06), CFrame.new(0.14, 1.24, 0.18) * CFrame.Angles(math.rad(25), 0, -math.rad(35)), auricGold, Enum.Material.Metal)
	weldTo(handle, cRayU1)
	local cRayU2 = makePart(model, "CoronaU_Ray2", Vector3.new(0.05, 0.18, 0.06), CFrame.new(-0.14, 1.24, 0.18) * CFrame.Angles(math.rad(25), 0, math.rad(35)), auricGold, Enum.Material.Metal)
	weldTo(handle, cRayU2)
	local cRayU3 = makePart(model, "CoronaU_Ray3", Vector3.new(0.05, 0.16, 0.06), CFrame.new(0.10, 1.36, 0.18) * CFrame.Angles(math.rad(25), 0, -math.rad(70)), auricGold, Enum.Material.Metal)
	weldTo(handle, cRayU3)
	local cRayU4 = makePart(model, "CoronaU_Ray4", Vector3.new(0.05, 0.16, 0.06), CFrame.new(-0.10, 1.36, 0.18) * CFrame.Angles(math.rad(25), 0, math.rad(70)), auricGold, Enum.Material.Metal)
	weldTo(handle, cRayU4)
	local cRayU5 = makePart(model, "CoronaU_Ray5", Vector3.new(0.04, 0.14, 0.05), CFrame.new(0.12, 1.12, 0.18) * CFrame.Angles(math.rad(25), 0, -math.rad(15)), heatWhite, Enum.Material.Neon)
	weldTo(handle, cRayU5)
	local cRayU6 = makePart(model, "CoronaU_Ray6", Vector3.new(0.04, 0.14, 0.05), CFrame.new(-0.12, 1.12, 0.18) * CFrame.Angles(math.rad(25), 0, math.rad(15)), heatWhite, Enum.Material.Neon)
	weldTo(handle, cRayU6)

	-- Upper Heat Sink Radiator Fins (dorsal cooling plates)
	local radU1 = makePart(model, "HeatSinkU_1", Vector3.new(0.04, 0.16, 0.14), CFrame.new(0, 0.68, -0.08) * CFrame.Angles(math.rad(10), 0, 0), darkRadiator, Enum.Material.Metal)
	weldTo(handle, radU1)
	local radU2 = makePart(model, "HeatSinkU_2", Vector3.new(0.04, 0.16, 0.14), CFrame.new(0, 0.94, -0.04) * CFrame.Angles(math.rad(16), 0, 0), darkRadiator, Enum.Material.Metal)
	weldTo(handle, radU2)
	local radU3 = makePart(model, "HeatSinkU_3", Vector3.new(0.04, 0.16, 0.14), CFrame.new(0, 1.48, 0.18) * CFrame.Angles(math.rad(38), 0, 0), darkRadiator, Enum.Material.Metal)
	weldTo(handle, radU3)
	local radU4 = makePart(model, "HeatSinkU_4", Vector3.new(0.04, 0.16, 0.14), CFrame.new(0, 1.74, 0.36) * CFrame.Angles(math.rad(52), 0, 0), darkRadiator, Enum.Material.Metal)
	weldTo(handle, radU4)

	-- Upper Copper Heat Pipe & Conduit
	local pipeU = makePart(model, "HeatPipe_U", Vector3.new(0.06, 1.20, 0.06), CFrame.new(0.12, 1.08, 0.10) * CFrame.Angles(math.rad(22), 0, 0), copperPipe, Enum.Material.Metal)
	weldTo(handle, pipeU)
	local pipeU_Elbow = makePart(model, "HeatPipeElbow_U", Vector3.new(0.08, 0.08, 0.10), CFrame.new(0.12, 1.68, 0.32), copperPipe, Enum.Material.Metal)
	weldTo(handle, pipeU_Elbow)

	-- Upper Sun-Lance Flared Tip
	local lanceBaseU = makePart(model, "LanceTipU_Base", Vector3.new(0.14, 0.22, 0.14), CFrame.new(0, 2.06, 0.84) * CFrame.Angles(math.rad(70), 0, 0), auricGold, Enum.Material.Metal)
	weldTo(handle, lanceBaseU)
	local lanceSpikeU = makePart(model, "LanceTipU_Spike", Vector3.new(0.08, 0.24, 0.08), CFrame.new(0, 2.20, 0.96) * CFrame.Angles(math.rad(78), 0, 0), heatWhite, Enum.Material.Neon)
	weldTo(handle, lanceSpikeU)
	local lanceFlangeU = makePart(model, "LanceTipU_Flange", Vector3.new(0.20, 0.06, 0.12), CFrame.new(0, 2.00, 0.80) * CFrame.Angles(math.rad(66), 0, 0), auricGold, Enum.Material.Metal)
	weldTo(handle, lanceFlangeU)
	local flameWispU = makePart(model, "FlameWisp_U", Vector3.new(0.04, 0.20, 0.08), CFrame.new(0, 2.14, 0.88) * CFrame.Angles(math.rad(82), 0, 0), coronaGlow, Enum.Material.Neon)
	weldTo(handle, flameWispU)

	-- Lower Recurve Bronze Limbs (6 segments)
	local ll1 = makePart(model, "LimbL_1", Vector3.new(0.24, 0.34, 0.22), CFrame.new(0, -0.48, 0.02) * CFrame.Angles(-math.rad(5), 0, 0), solarBronze, Enum.Material.Metal)
	weldTo(handle, ll1)
	local ll2 = makePart(model, "LimbL_2", Vector3.new(0.22, 0.34, 0.20), CFrame.new(0, -0.78, 0.06) * CFrame.Angles(-math.rad(11), 0, 0), solarBronze, Enum.Material.Metal)
	weldTo(handle, ll2)
	local ll3 = makePart(model, "LimbL_3", Vector3.new(0.20, 0.34, 0.18), CFrame.new(0, -1.08, 0.14) * CFrame.Angles(-math.rad(20), 0, 0), auricGold, Enum.Material.Metal)
	weldTo(handle, ll3)
	local ll4 = makePart(model, "LimbL_4", Vector3.new(0.18, 0.34, 0.16), CFrame.new(0, -1.36, 0.28) * CFrame.Angles(-math.rad(32), 0, 0), auricGold, Enum.Material.Metal)
	weldTo(handle, ll4)
	local ll5 = makePart(model, "LimbL_5", Vector3.new(0.16, 0.34, 0.14), CFrame.new(0, -1.62, 0.46) * CFrame.Angles(-math.rad(46), 0, 0), solarBronze, Enum.Material.Metal)
	weldTo(handle, ll5)
	local ll6 = makePart(model, "LimbL_6", Vector3.new(0.14, 0.36, 0.12), CFrame.new(0, -1.86, 0.68) * CFrame.Angles(-math.rad(60), 0, 0), solarBronze, Enum.Material.Metal)
	weldTo(handle, ll6)

	-- Lower Miniature Solar Corona Disc
	local coronaDiscL = makePart(model, "CoronaL_Center", Vector3.new(0.22, 0.22, 0.08), CFrame.new(0, -1.24, 0.18) * CFrame.Angles(-math.rad(25), 0, 0), coronaGlow, Enum.Material.Neon)
	weldTo(handle, coronaDiscL)
	local cRayL1 = makePart(model, "CoronaL_Ray1", Vector3.new(0.05, 0.18, 0.06), CFrame.new(0.14, -1.24, 0.18) * CFrame.Angles(-math.rad(25), 0, math.rad(35)), auricGold, Enum.Material.Metal)
	weldTo(handle, cRayL1)
	local cRayL2 = makePart(model, "CoronaL_Ray2", Vector3.new(0.05, 0.18, 0.06), CFrame.new(-0.14, -1.24, 0.18) * CFrame.Angles(-math.rad(25), 0, -math.rad(35)), auricGold, Enum.Material.Metal)
	weldTo(handle, cRayL2)
	local cRayL3 = makePart(model, "CoronaL_Ray3", Vector3.new(0.05, 0.16, 0.06), CFrame.new(0.10, -1.36, 0.18) * CFrame.Angles(-math.rad(25), 0, math.rad(70)), auricGold, Enum.Material.Metal)
	weldTo(handle, cRayL3)
	local cRayL4 = makePart(model, "CoronaL_Ray4", Vector3.new(0.05, 0.16, 0.06), CFrame.new(-0.10, -1.36, 0.18) * CFrame.Angles(-math.rad(25), 0, -math.rad(70)), auricGold, Enum.Material.Metal)
	weldTo(handle, cRayL4)
	local cRayL5 = makePart(model, "CoronaL_Ray5", Vector3.new(0.04, 0.14, 0.05), CFrame.new(0.12, -1.12, 0.18) * CFrame.Angles(-math.rad(25), 0, math.rad(15)), heatWhite, Enum.Material.Neon)
	weldTo(handle, cRayL5)
	local cRayL6 = makePart(model, "CoronaL_Ray6", Vector3.new(0.04, 0.14, 0.05), CFrame.new(-0.12, -1.12, 0.18) * CFrame.Angles(-math.rad(25), 0, -math.rad(15)), heatWhite, Enum.Material.Neon)
	weldTo(handle, cRayL6)

	-- Lower Heat Sink Radiator Fins
	local radL1 = makePart(model, "HeatSinkL_1", Vector3.new(0.04, 0.16, 0.14), CFrame.new(0, -0.68, -0.08) * CFrame.Angles(-math.rad(10), 0, 0), darkRadiator, Enum.Material.Metal)
	weldTo(handle, radL1)
	local radL2 = makePart(model, "HeatSinkL_2", Vector3.new(0.04, 0.16, 0.14), CFrame.new(0, -0.94, -0.04) * CFrame.Angles(-math.rad(16), 0, 0), darkRadiator, Enum.Material.Metal)
	weldTo(handle, radL2)
	local radL3 = makePart(model, "HeatSinkL_3", Vector3.new(0.04, 0.16, 0.14), CFrame.new(0, -1.48, 0.18) * CFrame.Angles(-math.rad(38), 0, 0), darkRadiator, Enum.Material.Metal)
	weldTo(handle, radL3)
	local radL4 = makePart(model, "HeatSinkL_4", Vector3.new(0.04, 0.16, 0.14), CFrame.new(0, -1.74, 0.36) * CFrame.Angles(-math.rad(52), 0, 0), darkRadiator, Enum.Material.Metal)
	weldTo(handle, radL4)

	-- Lower Copper Heat Pipe & Conduit
	local pipeL = makePart(model, "HeatPipe_L", Vector3.new(0.06, 1.20, 0.06), CFrame.new(0.12, -1.08, 0.10) * CFrame.Angles(-math.rad(22), 0, 0), copperPipe, Enum.Material.Metal)
	weldTo(handle, pipeL)
	local pipeL_Elbow = makePart(model, "HeatPipeElbow_L", Vector3.new(0.08, 0.08, 0.10), CFrame.new(0.12, -1.68, 0.32), copperPipe, Enum.Material.Metal)
	weldTo(handle, pipeL_Elbow)

	-- Lower Sun-Lance Flared Tip
	local lanceBaseL = makePart(model, "LanceTipL_Base", Vector3.new(0.14, 0.22, 0.14), CFrame.new(0, -2.06, 0.84) * CFrame.Angles(-math.rad(70), 0, 0), auricGold, Enum.Material.Metal)
	weldTo(handle, lanceBaseL)
	local lanceSpikeL = makePart(model, "LanceTipL_Spike", Vector3.new(0.08, 0.24, 0.08), CFrame.new(0, -2.20, 0.96) * CFrame.Angles(-math.rad(78), 0, 0), heatWhite, Enum.Material.Neon)
	weldTo(handle, lanceSpikeL)
	local lanceFlangeL = makePart(model, "LanceTipL_Flange", Vector3.new(0.20, 0.06, 0.12), CFrame.new(0, -2.00, 0.80) * CFrame.Angles(-math.rad(66), 0, 0), auricGold, Enum.Material.Metal)
	weldTo(handle, lanceFlangeL)
	local flameWispL = makePart(model, "FlameWisp_L", Vector3.new(0.04, 0.20, 0.08), CFrame.new(0, -2.14, 0.88) * CFrame.Angles(-math.rad(82), 0, 0), coronaGlow, Enum.Material.Neon)
	weldTo(handle, flameWispL)

	local radClampU = makePart(model, "RadClamp_U", Vector3.new(0.08, 0.05, 0.16), CFrame.new(0, 1.20, -0.06), solarBronze, Enum.Material.Metal)
	weldTo(handle, radClampU)
	local radClampL = makePart(model, "RadClamp_L", Vector3.new(0.08, 0.05, 0.16), CFrame.new(0, -1.20, -0.06), solarBronze, Enum.Material.Metal)
	weldTo(handle, radClampL)
	local solarGlowU = makePart(model, "SolarGlow_U", Vector3.new(0.06, 0.12, 0.06), CFrame.new(0, 1.50, 0.40), heatWhite, Enum.Material.Neon)
	weldTo(handle, solarGlowU)
	local solarGlowL = makePart(model, "SolarGlow_L", Vector3.new(0.06, 0.12, 0.06), CFrame.new(0, -1.50, 0.40), heatWhite, Enum.Material.Neon)
	weldTo(handle, solarGlowL)
	-- White-Gold Plasma Bowstring
	local bowString = makePart(model, "BowString", Vector3.new(0.045, 4.40, 0.045), CFrame.new(0, 0, 0.90), stringColor, Enum.Material.Fabric)
	weldTo(handle, bowString)

	addSocket(handle, "Grip", Vector3.zero)
	addSocket(handle, "Nock", Vector3.new(ARROW_REST.X, ARROW_REST.Y, 0.90))
	addSocket(handle, "TipUpper", Vector3.new(0, 2.20, 0.96))
	addSocket(handle, "TipLower", Vector3.new(0, -2.20, 0.96))
	addSocket(handle, "VfxTip", Vector3.new(0, 2.20, 0.96))
	addSocket(handle, "VfxBase", Vector3.new(0, -2.20, 0.96))
	addSocket(handle, "VfxCore", Vector3.zero)
	addSocket(handle, "VfxNock", Vector3.new(ARROW_REST.X, ARROW_REST.Y, 0.90))

	createHunterArrow(model, handle)
	return model
end

-- ============================================================================
-- 11. Celestial Zenith (art_celestial_zenith) - Legendary Standard
-- ============================================================================
function WeaponModelBuilder.BuildCelestialZenith(): Model
	local model = Instance.new("Model")
	model.Name = "art_celestial_zenith"

	local marbleWhite = Color3.fromRGB(242, 245, 248)
	local astralGold = Color3.fromRGB(235, 185, 55)
	local starlightCyan = Color3.fromRGB(160, 230, 255)
	local starlightCore = Color3.fromRGB(220, 248, 255)
	local lapisLazuli = Color3.fromRGB(35, 60, 130)
	local stringColor = Color3.fromRGB(225, 245, 255)

	-- Fluted Marble Column Riser with Doric Capital & Base
	local handle = makePart(model, "Handle", Vector3.new(0.26, 0.76, 0.30), CFrame.new(0, 0, 0), marbleWhite, Enum.Material.Marble)
	model.PrimaryPart = handle

	local colCapital = makePart(model, "ColCapital", Vector3.new(0.32, 0.08, 0.36), CFrame.new(0, 0.34, 0), astralGold, Enum.Material.Metal)
	weldTo(handle, colCapital)
	local colBase = makePart(model, "ColBase", Vector3.new(0.32, 0.08, 0.36), CFrame.new(0, -0.34, 0), astralGold, Enum.Material.Metal)
	weldTo(handle, colBase)

	local colFlute1 = makePart(model, "ColFlute_1", Vector3.new(0.04, 0.60, 0.04), CFrame.new(0.13, 0, 0.12), astralGold, Enum.Material.Metal)
	weldTo(handle, colFlute1)
	local colFlute2 = makePart(model, "ColFlute_2", Vector3.new(0.04, 0.60, 0.04), CFrame.new(-0.13, 0, 0.12), astralGold, Enum.Material.Metal)
	weldTo(handle, colFlute2)
	local colFlute3 = makePart(model, "ColFlute_3", Vector3.new(0.04, 0.60, 0.04), CFrame.new(0.13, 0, -0.12), astralGold, Enum.Material.Metal)
	weldTo(handle, colFlute3)
	local colFlute4 = makePart(model, "ColFlute_4", Vector3.new(0.04, 0.60, 0.04), CFrame.new(-0.13, 0, -0.12), astralGold, Enum.Material.Metal)
	weldTo(handle, colFlute4)

	-- Outer Armillary Ring (8 segments)
	local ring1 = makePart(model, "Astrolabe_1", Vector3.new(0.04, 0.22, 0.06), CFrame.new(0.24, 0.12, 0) * CFrame.Angles(0, 0, math.rad(22)), astralGold, Enum.Material.Metal)
	weldTo(handle, ring1)
	local ring2 = makePart(model, "Astrolabe_2", Vector3.new(0.04, 0.22, 0.06), CFrame.new(0.24, -0.12, 0) * CFrame.Angles(0, 0, -math.rad(22)), astralGold, Enum.Material.Metal)
	weldTo(handle, ring2)
	local ring3 = makePart(model, "Astrolabe_3", Vector3.new(0.04, 0.22, 0.06), CFrame.new(-0.24, 0.12, 0) * CFrame.Angles(0, 0, -math.rad(22)), astralGold, Enum.Material.Metal)
	weldTo(handle, ring3)
	local ring4 = makePart(model, "Astrolabe_4", Vector3.new(0.04, 0.22, 0.06), CFrame.new(-0.24, -0.12, 0) * CFrame.Angles(0, 0, math.rad(22)), astralGold, Enum.Material.Metal)
	weldTo(handle, ring4)
	local ring5 = makePart(model, "Astrolabe_5", Vector3.new(0.22, 0.04, 0.06), CFrame.new(0.12, 0.24, 0) * CFrame.Angles(0, 0, -math.rad(22)), astralGold, Enum.Material.Metal)
	weldTo(handle, ring5)
	local ring6 = makePart(model, "Astrolabe_6", Vector3.new(0.22, 0.04, 0.06), CFrame.new(-0.12, 0.24, 0) * CFrame.Angles(0, 0, math.rad(22)), astralGold, Enum.Material.Metal)
	weldTo(handle, ring6)
	local ring7 = makePart(model, "Astrolabe_7", Vector3.new(0.22, 0.04, 0.06), CFrame.new(0.12, -0.24, 0) * CFrame.Angles(0, 0, math.rad(22)), astralGold, Enum.Material.Metal)
	weldTo(handle, ring7)
	local ring8 = makePart(model, "Astrolabe_8", Vector3.new(0.22, 0.04, 0.06), CFrame.new(-0.12, -0.24, 0) * CFrame.Angles(0, 0, -math.rad(22)), astralGold, Enum.Material.Metal)
	weldTo(handle, ring8)

	-- Inner Armillary Ring (6 segments)
	local inRing1 = makePart(model, "InnerRing_1", Vector3.new(0.03, 0.16, 0.04), CFrame.new(0.15, 0.08, 0) * CFrame.Angles(0, 0, math.rad(30)), marbleWhite, Enum.Material.SmoothPlastic)
	weldTo(handle, inRing1)
	local inRing2 = makePart(model, "InnerRing_2", Vector3.new(0.03, 0.16, 0.04), CFrame.new(0.15, -0.08, 0) * CFrame.Angles(0, 0, -math.rad(30)), marbleWhite, Enum.Material.SmoothPlastic)
	weldTo(handle, inRing2)
	local inRing3 = makePart(model, "InnerRing_3", Vector3.new(0.03, 0.16, 0.04), CFrame.new(-0.15, 0.08, 0) * CFrame.Angles(0, 0, -math.rad(30)), marbleWhite, Enum.Material.SmoothPlastic)
	weldTo(handle, inRing3)
	local inRing4 = makePart(model, "InnerRing_4", Vector3.new(0.03, 0.16, 0.04), CFrame.new(-0.15, -0.08, 0) * CFrame.Angles(0, 0, math.rad(30)), marbleWhite, Enum.Material.SmoothPlastic)
	weldTo(handle, inRing4)
	local inRing5 = makePart(model, "InnerRing_5", Vector3.new(0.16, 0.03, 0.04), CFrame.new(0, 0.16, 0), marbleWhite, Enum.Material.SmoothPlastic)
	weldTo(handle, inRing5)
	local inRing6 = makePart(model, "InnerRing_6", Vector3.new(0.16, 0.03, 0.04), CFrame.new(0, -0.16, 0), marbleWhite, Enum.Material.SmoothPlastic)
	weldTo(handle, inRing6)

	local gimbalX = makePart(model, "GimbalAxle_X", Vector3.new(0.56, 0.04, 0.04), CFrame.new(0, 0, 0), astralGold, Enum.Material.Metal)
	weldTo(handle, gimbalX)
	local gimbalY = makePart(model, "GimbalAxle_Y", Vector3.new(0.04, 0.56, 0.04), CFrame.new(0, 0, 0), astralGold, Enum.Material.Metal)
	weldTo(handle, gimbalY)
	local gemCenter = makePart(model, "AstrolabeCore", Vector3.new(0.14, 0.14, 0.14), CFrame.new(0, 0, -0.06), starlightCyan, Enum.Material.Neon)
	weldTo(handle, gemCenter)
	local arrowRest = makePart(model, "CelestialArrowRest", Vector3.new(0.08, 0.14, 0.18), CFrame.new(0.15, 0.09, -0.08), astralGold, Enum.Material.Metal)
	weldTo(handle, arrowRest)

	-- Upper Alabaster Marble Limbs (8 curved segments)
	local lu1 = makePart(model, "LimbU_1", Vector3.new(0.22, 0.32, 0.22), CFrame.new(0, 0.48, 0.02) * CFrame.Angles(math.rad(4), 0, 0), marbleWhite, Enum.Material.Marble)
	weldTo(handle, lu1)
	local lu2 = makePart(model, "LimbU_2", Vector3.new(0.21, 0.32, 0.21), CFrame.new(0, 0.78, 0.05) * CFrame.Angles(math.rad(8), 0, 0), marbleWhite, Enum.Material.Marble)
	weldTo(handle, lu2)
	local lu3 = makePart(model, "LimbU_3", Vector3.new(0.20, 0.32, 0.20), CFrame.new(0, 1.08, 0.10) * CFrame.Angles(math.rad(13), 0, 0), marbleWhite, Enum.Material.Marble)
	weldTo(handle, lu3)
	local lu4 = makePart(model, "LimbU_4", Vector3.new(0.19, 0.32, 0.19), CFrame.new(0, 1.38, 0.18) * CFrame.Angles(math.rad(19), 0, 0), marbleWhite, Enum.Material.Marble)
	weldTo(handle, lu4)
	local lu5 = makePart(model, "LimbU_5", Vector3.new(0.18, 0.32, 0.18), CFrame.new(0, 1.66, 0.29) * CFrame.Angles(math.rad(26), 0, 0), marbleWhite, Enum.Material.Marble)
	weldTo(handle, lu5)
	local lu6 = makePart(model, "LimbU_6", Vector3.new(0.17, 0.32, 0.17), CFrame.new(0, 1.94, 0.43) * CFrame.Angles(math.rad(34), 0, 0), marbleWhite, Enum.Material.Marble)
	weldTo(handle, lu6)
	local lu7 = makePart(model, "LimbU_7", Vector3.new(0.16, 0.32, 0.16), CFrame.new(0, 2.20, 0.61) * CFrame.Angles(math.rad(43), 0, 0), marbleWhite, Enum.Material.Marble)
	weldTo(handle, lu7)
	local lu8 = makePart(model, "LimbU_8", Vector3.new(0.15, 0.34, 0.15), CFrame.new(0, 2.44, 0.83) * CFrame.Angles(math.rad(54), 0, 0), marbleWhite, Enum.Material.Marble)
	weldTo(handle, lu8)

	-- Upper Inlaid Gold Filigree Spine Ribs
	local filU1 = makePart(model, "FiligreeU_1", Vector3.new(0.06, 0.30, 0.06), CFrame.new(0, 0.78, 0.10) * CFrame.Angles(math.rad(8), 0, 0), astralGold, Enum.Material.Metal)
	weldTo(handle, filU1)
	local filU2 = makePart(model, "FiligreeU_2", Vector3.new(0.06, 0.30, 0.06), CFrame.new(0, 1.38, 0.23) * CFrame.Angles(math.rad(19), 0, 0), astralGold, Enum.Material.Metal)
	weldTo(handle, filU2)
	local filU3 = makePart(model, "FiligreeU_3", Vector3.new(0.05, 0.30, 0.06), CFrame.new(0, 1.94, 0.48) * CFrame.Angles(math.rad(34), 0, 0), astralGold, Enum.Material.Metal)
	weldTo(handle, filU3)
	local filU4 = makePart(model, "FiligreeU_4", Vector3.new(0.05, 0.30, 0.06), CFrame.new(0, 2.20, 0.66) * CFrame.Angles(math.rad(43), 0, 0), astralGold, Enum.Material.Metal)
	weldTo(handle, filU4)

	-- Upper Celestial Spire Tip & Hanging Teardrop
	local spireBaseU = makePart(model, "SpireU_Base", Vector3.new(0.14, 0.20, 0.14), CFrame.new(0, 2.62, 0.98) * CFrame.Angles(math.rad(64), 0, 0), astralGold, Enum.Material.Metal)
	weldTo(handle, spireBaseU)
	local spireTipU = makePart(model, "SpireU_Tip", Vector3.new(0.06, 0.26, 0.06), CFrame.new(0, 2.76, 1.12) * CFrame.Angles(math.rad(72), 0, 0), starlightCore, Enum.Material.Neon)
	weldTo(handle, spireTipU)
	local pendU_Ring = makePart(model, "PendRing_U", Vector3.new(0.06, 0.06, 0.06), CFrame.new(0, 2.56, 1.02), astralGold, Enum.Material.Metal)
	weldTo(handle, pendU_Ring)
	local pendU_Chain = makePart(model, "PendChain_U", Vector3.new(0.03, 0.08, 0.03), CFrame.new(0, 2.52, 1.04), astralGold, Enum.Material.Metal)
	weldTo(handle, pendU_Chain)
	local pendU = makePart(model, "Pendulum_U", Vector3.new(0.08, 0.16, 0.08), CFrame.new(0, 2.46, 1.06) * CFrame.Angles(0, 0, math.rad(45)), lapisLazuli, Enum.Material.SmoothPlastic)
	weldTo(handle, pendU)

	-- Lower Alabaster Marble Limbs (8 curved segments)
	local ll1 = makePart(model, "LimbL_1", Vector3.new(0.22, 0.32, 0.22), CFrame.new(0, -0.48, 0.02) * CFrame.Angles(-math.rad(4), 0, 0), marbleWhite, Enum.Material.Marble)
	weldTo(handle, ll1)
	local ll2 = makePart(model, "LimbL_2", Vector3.new(0.21, 0.32, 0.21), CFrame.new(0, -0.78, 0.05) * CFrame.Angles(-math.rad(8), 0, 0), marbleWhite, Enum.Material.Marble)
	weldTo(handle, ll2)
	local ll3 = makePart(model, "LimbL_3", Vector3.new(0.20, 0.32, 0.20), CFrame.new(0, -1.08, 0.10) * CFrame.Angles(-math.rad(13), 0, 0), marbleWhite, Enum.Material.Marble)
	weldTo(handle, ll3)
	local ll4 = makePart(model, "LimbL_4", Vector3.new(0.19, 0.32, 0.19), CFrame.new(0, -1.38, 0.18) * CFrame.Angles(-math.rad(19), 0, 0), marbleWhite, Enum.Material.Marble)
	weldTo(handle, ll4)
	local ll5 = makePart(model, "LimbL_5", Vector3.new(0.18, 0.32, 0.18), CFrame.new(0, -1.66, 0.29) * CFrame.Angles(-math.rad(26), 0, 0), marbleWhite, Enum.Material.Marble)
	weldTo(handle, ll5)
	local ll6 = makePart(model, "LimbL_6", Vector3.new(0.17, 0.32, 0.17), CFrame.new(0, -1.94, 0.43) * CFrame.Angles(-math.rad(34), 0, 0), marbleWhite, Enum.Material.Marble)
	weldTo(handle, ll6)
	local ll7 = makePart(model, "LimbL_7", Vector3.new(0.16, 0.32, 0.16), CFrame.new(0, -2.20, 0.61) * CFrame.Angles(-math.rad(43), 0, 0), marbleWhite, Enum.Material.Marble)
	weldTo(handle, ll7)
	local ll8 = makePart(model, "LimbL_8", Vector3.new(0.15, 0.34, 0.15), CFrame.new(0, -2.44, 0.83) * CFrame.Angles(-math.rad(54), 0, 0), marbleWhite, Enum.Material.Marble)
	weldTo(handle, ll8)

	-- Lower Inlaid Gold Filigree Spine Ribs
	local filL1 = makePart(model, "FiligreeL_1", Vector3.new(0.06, 0.30, 0.06), CFrame.new(0, -0.78, 0.10) * CFrame.Angles(-math.rad(8), 0, 0), astralGold, Enum.Material.Metal)
	weldTo(handle, filL1)
	local filL2 = makePart(model, "FiligreeL_2", Vector3.new(0.06, 0.30, 0.06), CFrame.new(0, -1.38, 0.23) * CFrame.Angles(-math.rad(19), 0, 0), astralGold, Enum.Material.Metal)
	weldTo(handle, filL2)
	local filL3 = makePart(model, "FiligreeL_3", Vector3.new(0.05, 0.30, 0.06), CFrame.new(0, -1.94, 0.48) * CFrame.Angles(-math.rad(34), 0, 0), astralGold, Enum.Material.Metal)
	weldTo(handle, filL3)
	local filL4 = makePart(model, "FiligreeL_4", Vector3.new(0.05, 0.30, 0.06), CFrame.new(0, -2.20, 0.66) * CFrame.Angles(-math.rad(43), 0, 0), astralGold, Enum.Material.Metal)
	weldTo(handle, filL4)

	-- Lower Celestial Spire Tip & Hanging Teardrop
	local spireBaseL = makePart(model, "SpireL_Base", Vector3.new(0.14, 0.20, 0.14), CFrame.new(0, -2.62, 0.98) * CFrame.Angles(-math.rad(64), 0, 0), astralGold, Enum.Material.Metal)
	weldTo(handle, spireBaseL)
	local spireTipL = makePart(model, "SpireL_Tip", Vector3.new(0.06, 0.26, 0.06), CFrame.new(0, -2.76, 1.12) * CFrame.Angles(-math.rad(72), 0, 0), starlightCore, Enum.Material.Neon)
	weldTo(handle, spireTipL)
	local pendL_Ring = makePart(model, "PendRing_L", Vector3.new(0.06, 0.06, 0.06), CFrame.new(0, -2.56, 1.02), astralGold, Enum.Material.Metal)
	weldTo(handle, pendL_Ring)
	local pendL_Chain = makePart(model, "PendChain_L", Vector3.new(0.03, 0.08, 0.03), CFrame.new(0, -2.52, 1.04), astralGold, Enum.Material.Metal)
	weldTo(handle, pendL_Chain)
	local pendL = makePart(model, "Pendulum_L", Vector3.new(0.08, 0.16, 0.08), CFrame.new(0, -2.46, 1.06) * CFrame.Angles(0, 0, math.rad(45)), lapisLazuli, Enum.Material.SmoothPlastic)
	weldTo(handle, pendL)

	local compassNeedleU = makePart(model, "CompassNeedle_U", Vector3.new(0.02, 0.22, 0.02), CFrame.new(0, 0.18, 0.08), starlightCyan, Enum.Material.Neon)
	weldTo(handle, compassNeedleU)
	local compassNeedleL = makePart(model, "CompassNeedle_L", Vector3.new(0.02, 0.22, 0.02), CFrame.new(0, -0.18, 0.08), starlightCyan, Enum.Material.Neon)
	weldTo(handle, compassNeedleL)
	local meridianStar1 = makePart(model, "MeridianStar_1", Vector3.new(0.06, 0.06, 0.06), CFrame.new(0.18, 0, 0.08), starlightCore, Enum.Material.Neon)
	weldTo(handle, meridianStar1)
	local meridianStar2 = makePart(model, "MeridianStar_2", Vector3.new(0.06, 0.06, 0.06), CFrame.new(-0.18, 0, 0.08), starlightCore, Enum.Material.Neon)
	weldTo(handle, meridianStar2)
	local meridianCenter = makePart(model, "MeridianCenter_Pin", Vector3.new(0.08, 0.08, 0.08), CFrame.new(0, 0, 0.08), astralGold, Enum.Material.Metal)
	weldTo(handle, meridianCenter)
	-- Spun Starlight Chord Bowstring
	local bowString = makePart(model, "BowString", Vector3.new(0.045, 5.50, 0.045), CFrame.new(0, 0, 1.08), stringColor, Enum.Material.Fabric)
	weldTo(handle, bowString)

	addSocket(handle, "Grip", Vector3.zero)
	addSocket(handle, "Nock", Vector3.new(ARROW_REST.X, ARROW_REST.Y, 1.08))
	addSocket(handle, "TipUpper", Vector3.new(0, 2.76, 1.12))
	addSocket(handle, "TipLower", Vector3.new(0, -2.76, 1.12))
	addSocket(handle, "VfxTip", Vector3.new(0, 2.76, 1.12))
	addSocket(handle, "VfxBase", Vector3.new(0, -2.76, 1.12))
	addSocket(handle, "VfxCore", Vector3.zero)
	addSocket(handle, "VfxNock", Vector3.new(ARROW_REST.X, ARROW_REST.Y, 1.08))

	createHunterArrow(model, handle)
	return model
end

-- ============================================================================
-- 12. Supernova Greatbow (art_supernova_greatbow) - Legendary Enhanced
-- ============================================================================
function WeaponModelBuilder.BuildSupernovaGreatbow(): Model
	local model = Instance.new("Model")
	model.Name = "art_supernova_greatbow"

	local darkTitanium = Color3.fromRGB(42, 45, 52)
	local titaniumBright = Color3.fromRGB(130, 140, 155)
	local obsidianBlack = Color3.fromRGB(22, 22, 26)
	local voidCore = Color3.fromRGB(15, 10, 25)
	local magneticPurple = Color3.fromRGB(145, 65, 235)
	local singularityGlow = Color3.fromRGB(205, 135, 255)
	local stringColor = Color3.fromRGB(195, 140, 245)

	-- Heavy Titanium Riser & Magnetic Claws
	local handle = makePart(model, "Handle", Vector3.new(0.30, 0.80, 0.36), CFrame.new(0, 0, 0), darkTitanium, Enum.Material.Metal)
	model.PrimaryPart = handle

	-- Central Void Singularity Core & Containment Rings
	local voidSphere = makePart(model, "VoidSphere", Vector3.new(0.28, 0.28, 0.28), CFrame.new(0, 0, -0.06), voidCore, Enum.Material.Glass)
	weldTo(handle, voidSphere)
	local singGlow = makePart(model, "SingularityGlow", Vector3.new(0.18, 0.18, 0.18), CFrame.new(0, 0, -0.06), singularityGlow, Enum.Material.Neon)
	weldTo(handle, singGlow)

	local claw1 = makePart(model, "MagClaw_1", Vector3.new(0.06, 0.20, 0.12), CFrame.new(0.16, 0.16, -0.06) * CFrame.Angles(0, 0, -math.rad(45)), titaniumBright, Enum.Material.Metal)
	weldTo(handle, claw1)
	local claw2 = makePart(model, "MagClaw_2", Vector3.new(0.06, 0.20, 0.12), CFrame.new(-0.16, 0.16, -0.06) * CFrame.Angles(0, 0, math.rad(45)), titaniumBright, Enum.Material.Metal)
	weldTo(handle, claw2)
	local claw3 = makePart(model, "MagClaw_3", Vector3.new(0.06, 0.20, 0.12), CFrame.new(0.16, -0.16, -0.06) * CFrame.Angles(0, 0, math.rad(45)), titaniumBright, Enum.Material.Metal)
	weldTo(handle, claw3)
	local claw4 = makePart(model, "MagClaw_4", Vector3.new(0.06, 0.20, 0.12), CFrame.new(-0.16, -0.16, -0.06) * CFrame.Angles(0, 0, -math.rad(45)), titaniumBright, Enum.Material.Metal)
	weldTo(handle, claw4)

	local contRingU = makePart(model, "ContRing_U", Vector3.new(0.32, 0.06, 0.32), CFrame.new(0, 0.30, 0), magneticPurple, Enum.Material.Neon)
	weldTo(handle, contRingU)
	local contRingL = makePart(model, "ContRing_L", Vector3.new(0.32, 0.06, 0.32), CFrame.new(0, -0.30, 0), magneticPurple, Enum.Material.Neon)
	weldTo(handle, contRingL)
	local damperU = makePart(model, "RecoilDamper_U", Vector3.new(0.10, 0.12, 0.10), CFrame.new(0, 0.38, 0.08), darkTitanium, Enum.Material.Metal)
	weldTo(handle, damperU)
	local damperL = makePart(model, "RecoilDamper_L", Vector3.new(0.10, 0.12, 0.10), CFrame.new(0, -0.38, 0.08), darkTitanium, Enum.Material.Metal)
	weldTo(handle, damperL)
	local strut1 = makePart(model, "RecoilStrut_1", Vector3.new(0.06, 0.20, 0.06), CFrame.new(0.12, 0.24, 0.12), titaniumBright, Enum.Material.Metal)
	weldTo(handle, strut1)
	local strut2 = makePart(model, "RecoilStrut_2", Vector3.new(0.06, 0.20, 0.06), CFrame.new(-0.12, 0.24, 0.12), titaniumBright, Enum.Material.Metal)
	weldTo(handle, strut2)
	local strut3 = makePart(model, "RecoilStrut_3", Vector3.new(0.06, 0.20, 0.06), CFrame.new(0.12, -0.24, 0.12), titaniumBright, Enum.Material.Metal)
	weldTo(handle, strut3)
	local strut4 = makePart(model, "RecoilStrut_4", Vector3.new(0.06, 0.20, 0.06), CFrame.new(-0.12, -0.24, 0.12), titaniumBright, Enum.Material.Metal)
	weldTo(handle, strut4)
	local arrowRest = makePart(model, "SupernovaArrowRest", Vector3.new(0.08, 0.16, 0.20), CFrame.new(0.16, 0.10, -0.09), darkTitanium, Enum.Material.Metal)
	weldTo(handle, arrowRest)

	-- Upper Quad Obsidian Split Rail Beams (Left & Right twin rails, 5 segments each)
	local rul1 = makePart(model, "RailUL_1", Vector3.new(0.08, 0.34, 0.16), CFrame.new(0.11, 0.50, 0.04) * CFrame.Angles(math.rad(6), 0, 0), obsidianBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, rul1)
	local rul2 = makePart(model, "RailUL_2", Vector3.new(0.07, 0.34, 0.15), CFrame.new(0.11, 0.82, 0.09) * CFrame.Angles(math.rad(13), 0, 0), obsidianBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, rul2)
	local rul3 = makePart(model, "RailUL_3", Vector3.new(0.06, 0.34, 0.14), CFrame.new(0.11, 1.14, 0.18) * CFrame.Angles(math.rad(22), 0, 0), obsidianBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, rul3)
	local rul4 = makePart(model, "RailUL_4", Vector3.new(0.06, 0.34, 0.13), CFrame.new(0.11, 1.44, 0.32) * CFrame.Angles(math.rad(33), 0, 0), obsidianBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, rul4)
	local rul5 = makePart(model, "RailUL_5", Vector3.new(0.05, 0.36, 0.12), CFrame.new(0.11, 1.72, 0.52) * CFrame.Angles(math.rad(46), 0, 0), obsidianBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, rul5)

	local rur1 = makePart(model, "RailUR_1", Vector3.new(0.08, 0.34, 0.16), CFrame.new(-0.11, 0.50, 0.04) * CFrame.Angles(math.rad(6), 0, 0), obsidianBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, rur1)
	local rur2 = makePart(model, "RailUR_2", Vector3.new(0.07, 0.34, 0.15), CFrame.new(-0.11, 0.82, 0.09) * CFrame.Angles(math.rad(13), 0, 0), obsidianBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, rur2)
	local rur3 = makePart(model, "RailUR_3", Vector3.new(0.06, 0.34, 0.14), CFrame.new(-0.11, 1.14, 0.18) * CFrame.Angles(math.rad(22), 0, 0), obsidianBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, rur3)
	local rur4 = makePart(model, "RailUR_4", Vector3.new(0.06, 0.34, 0.13), CFrame.new(-0.11, 1.44, 0.32) * CFrame.Angles(math.rad(33), 0, 0), obsidianBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, rur4)
	local rur5 = makePart(model, "RailUR_5", Vector3.new(0.05, 0.36, 0.12), CFrame.new(-0.11, 1.72, 0.52) * CFrame.Angles(math.rad(46), 0, 0), obsidianBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, rur5)

	-- Upper Titanium Spacer Blocks & Magnetic Acceleration Coils (4 coils per limb)
	local spcU1 = makePart(model, "SpacerU_1", Vector3.new(0.24, 0.06, 0.18), CFrame.new(0, 0.82, 0.09) * CFrame.Angles(math.rad(13), 0, 0), titaniumBright, Enum.Material.Metal)
	weldTo(handle, spcU1)
	local spcU2 = makePart(model, "SpacerU_2", Vector3.new(0.22, 0.06, 0.16), CFrame.new(0, 1.44, 0.32) * CFrame.Angles(math.rad(33), 0, 0), titaniumBright, Enum.Material.Metal)
	weldTo(handle, spcU2)

	local coilU1 = makePart(model, "MagCoilU_1", Vector3.new(0.18, 0.10, 0.10), CFrame.new(0, 0.66, 0.06) * CFrame.Angles(math.rad(9), 0, 0), magneticPurple, Enum.Material.Neon)
	weldTo(handle, coilU1)
	local coilU2 = makePart(model, "MagCoilU_2", Vector3.new(0.18, 0.10, 0.10), CFrame.new(0, 1.14, 0.18) * CFrame.Angles(math.rad(22), 0, 0), magneticPurple, Enum.Material.Neon)
	weldTo(handle, coilU2)
	local coilU3 = makePart(model, "MagCoilU_3", Vector3.new(0.16, 0.10, 0.10), CFrame.new(0, 1.58, 0.42) * CFrame.Angles(math.rad(40), 0, 0), magneticPurple, Enum.Material.Neon)
	weldTo(handle, coilU3)
	local tieU1 = makePart(model, "RailTieU_1", Vector3.new(0.26, 0.04, 0.14), CFrame.new(0, 1.00, 0.14) * CFrame.Angles(math.rad(18), 0, 0), titaniumBright, Enum.Material.Metal)
	weldTo(handle, tieU1)
	local tieU2 = makePart(model, "RailTieU_2", Vector3.new(0.24, 0.04, 0.12), CFrame.new(0, 1.30, 0.25) * CFrame.Angles(math.rad(28), 0, 0), titaniumBright, Enum.Material.Metal)
	weldTo(handle, tieU2)

	-- Massive Upper Flared Monolithic Siege Tips
	local tipU_Base = makePart(model, "SiegeTipU_Anchor", Vector3.new(0.26, 0.22, 0.22), CFrame.new(0, 1.94, 0.72) * CFrame.Angles(math.rad(58), 0, 0), darkTitanium, Enum.Material.Metal)
	weldTo(handle, tipU_Base)
	local tipU_HornL = makePart(model, "SiegeTipU_HornL", Vector3.new(0.06, 0.26, 0.14), CFrame.new(0.12, 2.10, 0.86) * CFrame.Angles(math.rad(68), math.rad(18), 0), obsidianBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, tipU_HornL)
	local tipU_HornR = makePart(model, "SiegeTipU_HornR", Vector3.new(0.06, 0.26, 0.14), CFrame.new(-0.12, 2.10, 0.86) * CFrame.Angles(math.rad(68), -math.rad(18), 0), obsidianBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, tipU_HornR)
	local tipU_Spike = makePart(model, "SiegeTipU_Spike", Vector3.new(0.08, 0.30, 0.08), CFrame.new(0, 2.18, 0.92) * CFrame.Angles(math.rad(74), 0, 0), singularityGlow, Enum.Material.Neon)
	weldTo(handle, tipU_Spike)
	local ventU1 = makePart(model, "PlasmaVent_U1", Vector3.new(0.04, 0.12, 0.06), CFrame.new(0.14, 1.88, 0.68) * CFrame.Angles(math.rad(58), 0, 0), magneticPurple, Enum.Material.Neon)
	weldTo(handle, ventU1)
	local ventU2 = makePart(model, "PlasmaVent_U2", Vector3.new(0.04, 0.12, 0.06), CFrame.new(-0.14, 1.88, 0.68) * CFrame.Angles(math.rad(58), 0, 0), magneticPurple, Enum.Material.Neon)
	weldTo(handle, ventU2)

	-- Lower Quad Obsidian Split Rail Beams (Left & Right twin rails, 5 segments each)
	local rll1 = makePart(model, "RailLL_1", Vector3.new(0.08, 0.34, 0.16), CFrame.new(0.11, -0.50, 0.04) * CFrame.Angles(-math.rad(6), 0, 0), obsidianBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, rll1)
	local rll2 = makePart(model, "RailLL_2", Vector3.new(0.07, 0.34, 0.15), CFrame.new(0.11, -0.82, 0.09) * CFrame.Angles(-math.rad(13), 0, 0), obsidianBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, rll2)
	local rll3 = makePart(model, "RailLL_3", Vector3.new(0.06, 0.34, 0.14), CFrame.new(0.11, -1.14, 0.18) * CFrame.Angles(-math.rad(22), 0, 0), obsidianBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, rll3)
	local rll4 = makePart(model, "RailLL_4", Vector3.new(0.06, 0.34, 0.13), CFrame.new(0.11, -1.44, 0.32) * CFrame.Angles(-math.rad(33), 0, 0), obsidianBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, rll4)
	local rll5 = makePart(model, "RailLL_5", Vector3.new(0.05, 0.36, 0.12), CFrame.new(0.11, -1.72, 0.52) * CFrame.Angles(-math.rad(46), 0, 0), obsidianBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, rll5)

	local rlr1 = makePart(model, "RailLR_1", Vector3.new(0.08, 0.34, 0.16), CFrame.new(-0.11, -0.50, 0.04) * CFrame.Angles(-math.rad(6), 0, 0), obsidianBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, rlr1)
	local rlr2 = makePart(model, "RailLR_2", Vector3.new(0.07, 0.34, 0.15), CFrame.new(-0.11, -0.82, 0.09) * CFrame.Angles(-math.rad(13), 0, 0), obsidianBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, rlr2)
	local rlr3 = makePart(model, "RailLR_3", Vector3.new(0.06, 0.34, 0.14), CFrame.new(-0.11, -1.14, 0.18) * CFrame.Angles(-math.rad(22), 0, 0), obsidianBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, rlr3)
	local rlr4 = makePart(model, "RailLR_4", Vector3.new(0.06, 0.34, 0.13), CFrame.new(-0.11, -1.44, 0.32) * CFrame.Angles(-math.rad(33), 0, 0), obsidianBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, rlr4)
	local rlr5 = makePart(model, "RailLR_5", Vector3.new(0.05, 0.36, 0.12), CFrame.new(-0.11, -1.72, 0.52) * CFrame.Angles(-math.rad(46), 0, 0), obsidianBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, rlr5)

	-- Lower Titanium Spacer Blocks & Magnetic Acceleration Coils
	local spcL1 = makePart(model, "SpacerL_1", Vector3.new(0.24, 0.06, 0.18), CFrame.new(0, -0.82, 0.09) * CFrame.Angles(-math.rad(13), 0, 0), titaniumBright, Enum.Material.Metal)
	weldTo(handle, spcL1)
	local spcL2 = makePart(model, "SpacerL_2", Vector3.new(0.22, 0.06, 0.16), CFrame.new(0, -1.44, 0.32) * CFrame.Angles(-math.rad(33), 0, 0), titaniumBright, Enum.Material.Metal)
	weldTo(handle, spcL2)

	local coilL1 = makePart(model, "MagCoilL_1", Vector3.new(0.18, 0.10, 0.10), CFrame.new(0, -0.66, 0.06) * CFrame.Angles(-math.rad(9), 0, 0), magneticPurple, Enum.Material.Neon)
	weldTo(handle, coilL1)
	local coilL2 = makePart(model, "MagCoilL_2", Vector3.new(0.18, 0.10, 0.10), CFrame.new(0, -1.14, 0.18) * CFrame.Angles(-math.rad(22), 0, 0), magneticPurple, Enum.Material.Neon)
	weldTo(handle, coilL2)
	local coilL3 = makePart(model, "MagCoilL_3", Vector3.new(0.16, 0.10, 0.10), CFrame.new(0, -1.58, 0.42) * CFrame.Angles(-math.rad(40), 0, 0), magneticPurple, Enum.Material.Neon)
	weldTo(handle, coilL3)
	local tieL1 = makePart(model, "RailTieL_1", Vector3.new(0.26, 0.04, 0.14), CFrame.new(0, -1.00, 0.14) * CFrame.Angles(-math.rad(18), 0, 0), titaniumBright, Enum.Material.Metal)
	weldTo(handle, tieL1)
	local tieL2 = makePart(model, "RailTieL_2", Vector3.new(0.24, 0.04, 0.12), CFrame.new(0, -1.30, 0.25) * CFrame.Angles(-math.rad(28), 0, 0), titaniumBright, Enum.Material.Metal)
	weldTo(handle, tieL2)

	-- Massive Lower Flared Monolithic Siege Tips
	local tipL_Base = makePart(model, "SiegeTipL_Anchor", Vector3.new(0.26, 0.22, 0.22), CFrame.new(0, -1.94, 0.72) * CFrame.Angles(-math.rad(58), 0, 0), darkTitanium, Enum.Material.Metal)
	weldTo(handle, tipL_Base)
	local tipL_HornL = makePart(model, "SiegeTipL_HornL", Vector3.new(0.06, 0.26, 0.14), CFrame.new(0.12, -2.10, 0.86) * CFrame.Angles(-math.rad(68), math.rad(18), 0), obsidianBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, tipL_HornL)
	local tipL_HornR = makePart(model, "SiegeTipL_HornR", Vector3.new(0.06, 0.26, 0.14), CFrame.new(-0.12, -2.10, 0.86) * CFrame.Angles(-math.rad(68), -math.rad(18), 0), obsidianBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, tipL_HornR)
	local tipL_Spike = makePart(model, "SiegeTipL_Spike", Vector3.new(0.08, 0.30, 0.08), CFrame.new(0, -2.18, 0.92) * CFrame.Angles(-math.rad(74), 0, 0), singularityGlow, Enum.Material.Neon)
	weldTo(handle, tipL_Spike)
	local ventL1 = makePart(model, "PlasmaVent_L1", Vector3.new(0.04, 0.12, 0.06), CFrame.new(0.14, -1.88, 0.68) * CFrame.Angles(-math.rad(58), 0, 0), magneticPurple, Enum.Material.Neon)
	weldTo(handle, ventL1)
	local ventL2 = makePart(model, "PlasmaVent_L2", Vector3.new(0.04, 0.12, 0.06), CFrame.new(-0.14, -1.88, 0.68) * CFrame.Angles(-math.rad(58), 0, 0), magneticPurple, Enum.Material.Neon)
	weldTo(handle, ventL2)

	local barbU1 = makePart(model, "HornBarb_U1", Vector3.new(0.04, 0.16, 0.08), CFrame.new(0.16, 2.22, 0.88) * CFrame.Angles(math.rad(70), math.rad(25), 0), obsidianBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, barbU1)
	local barbU2 = makePart(model, "HornBarb_U2", Vector3.new(0.04, 0.16, 0.08), CFrame.new(-0.16, 2.22, 0.88) * CFrame.Angles(math.rad(70), -math.rad(25), 0), obsidianBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, barbU2)
	local barbL1 = makePart(model, "HornBarb_L1", Vector3.new(0.04, 0.16, 0.08), CFrame.new(0.16, -2.22, 0.88) * CFrame.Angles(-math.rad(70), math.rad(25), 0), obsidianBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, barbL1)
	local barbL2 = makePart(model, "HornBarb_L2", Vector3.new(0.04, 0.16, 0.08), CFrame.new(-0.16, -2.22, 0.88) * CFrame.Angles(-math.rad(70), -math.rad(25), 0), obsidianBlack, Enum.Material.SmoothPlastic)
	weldTo(handle, barbL2)
	local injectorU = makePart(model, "FluxInjector_U", Vector3.new(0.08, 0.10, 0.08), CFrame.new(0, 0.44, -0.06), magneticPurple, Enum.Material.Neon)
	weldTo(handle, injectorU)
	local injectorL = makePart(model, "FluxInjector_L", Vector3.new(0.08, 0.10, 0.08), CFrame.new(0, -0.44, -0.06), magneticPurple, Enum.Material.Neon)
	weldTo(handle, injectorL)
	-- Magnetic Flux Bowstring
	local bowString = makePart(model, "BowString", Vector3.new(0.045, 4.40, 0.045), CFrame.new(0, 0, 0.86), stringColor, Enum.Material.Fabric)
	weldTo(handle, bowString)

	addSocket(handle, "Grip", Vector3.zero)
	addSocket(handle, "Nock", Vector3.new(ARROW_REST.X, ARROW_REST.Y, 0.86))
	addSocket(handle, "TipUpper", Vector3.new(0, 2.18, 0.92))
	addSocket(handle, "TipLower", Vector3.new(0, -2.18, 0.92))
	addSocket(handle, "VfxTip", Vector3.new(0, 2.18, 0.92))
	addSocket(handle, "VfxBase", Vector3.new(0, -2.18, 0.92))
	addSocket(handle, "VfxCore", Vector3.zero)
	addSocket(handle, "VfxNock", Vector3.new(ARROW_REST.X, ARROW_REST.Y, 0.86))

	createHunterArrow(model, handle)
	return model
end

-- ============================================================================
-- 13. Astrea Cosmic Bow (art_astrea_cosmic_bow) - Origin Standard
-- ============================================================================
function WeaponModelBuilder.BuildAstreaCosmicBow(): Model
	local model = Instance.new("Model")
	model.Name = "art_astrea_cosmic_bow"

	local astralIndigo = Color3.fromRGB(30, 22, 60)
	local starSilver = Color3.fromRGB(225, 235, 255)
	local starlightGold = Color3.fromRGB(250, 215, 95)
	local nebulaPurple = Color3.fromRGB(155, 75, 235)
	local starGlass = Color3.fromRGB(195, 225, 255)
	local stringColor = Color3.fromRGB(215, 235, 255)

	-- Astral Indigo Pivot Hub & Cosmic Star Disc
	local handle = makePart(model, "Handle", Vector3.new(0.26, 0.74, 0.32), CFrame.new(0, 0, 0), astralIndigo, Enum.Material.Metal)
	model.PrimaryPart = handle

	local starDisc = makePart(model, "StarDisc_Center", Vector3.new(0.32, 0.32, 0.12), CFrame.new(0, 0, -0.06), starlightGold, Enum.Material.Metal)
	weldTo(handle, starDisc)
	local starDiscRing = makePart(model, "StarDisc_Ring", Vector3.new(0.40, 0.40, 0.06), CFrame.new(0, 0, -0.06), nebulaPurple, Enum.Material.Neon)
	weldTo(handle, starDiscRing)

	local ray1 = makePart(model, "StarRay_1", Vector3.new(0.06, 0.26, 0.06), CFrame.new(0.20, 0.20, -0.06) * CFrame.Angles(0, 0, -math.rad(45)), starSilver, Enum.Material.Metal)
	weldTo(handle, ray1)
	local ray2 = makePart(model, "StarRay_2", Vector3.new(0.06, 0.26, 0.06), CFrame.new(-0.20, 0.20, -0.06) * CFrame.Angles(0, 0, math.rad(45)), starSilver, Enum.Material.Metal)
	weldTo(handle, ray2)
	local ray3 = makePart(model, "StarRay_3", Vector3.new(0.06, 0.26, 0.06), CFrame.new(0.20, -0.20, -0.06) * CFrame.Angles(0, 0, math.rad(45)), starSilver, Enum.Material.Metal)
	weldTo(handle, ray3)
	local ray4 = makePart(model, "StarRay_4", Vector3.new(0.06, 0.26, 0.06), CFrame.new(-0.20, -0.20, -0.06) * CFrame.Angles(0, 0, -math.rad(45)), starSilver, Enum.Material.Metal)
	weldTo(handle, ray4)
	local orbSeg1 = makePart(model, "Orbit_1", Vector3.new(0.04, 0.18, 0.04), CFrame.new(0.24, 0, -0.06), starGlass, Enum.Material.Glass)
	weldTo(handle, orbSeg1)
	local orbSeg2 = makePart(model, "Orbit_2", Vector3.new(0.04, 0.18, 0.04), CFrame.new(-0.24, 0, -0.06), starGlass, Enum.Material.Glass)
	weldTo(handle, orbSeg2)
	local arrowRest = makePart(model, "CosmicArrowRest", Vector3.new(0.08, 0.14, 0.18), CFrame.new(0.15, 0.09, -0.08), starlightGold, Enum.Material.Metal)
	weldTo(handle, arrowRest)

	-- Upper Open Tetrahedral Space-Frame Vector Truss
	-- 7 Diamond-faceted Star Glass Nodes
	local nodeU1 = makePart(model, "StarNodeU_1", Vector3.new(0.16, 0.16, 0.16), CFrame.new(0, 0.50, 0.02) * CFrame.Angles(math.rad(6), math.rad(45), 0), starGlass, Enum.Material.Glass)
	weldTo(handle, nodeU1)
	local nodeU2 = makePart(model, "StarNodeU_2", Vector3.new(0.15, 0.15, 0.15), CFrame.new(0, 0.78, 0.05) * CFrame.Angles(math.rad(11), math.rad(45), 0), nebulaPurple, Enum.Material.Neon)
	weldTo(handle, nodeU2)
	local nodeU3 = makePart(model, "StarNodeU_3", Vector3.new(0.14, 0.14, 0.14), CFrame.new(0, 1.06, 0.11) * CFrame.Angles(math.rad(18), math.rad(45), 0), starGlass, Enum.Material.Glass)
	weldTo(handle, nodeU3)
	local nodeU4 = makePart(model, "StarNodeU_4", Vector3.new(0.14, 0.14, 0.14), CFrame.new(0, 1.34, 0.20) * CFrame.Angles(math.rad(26), math.rad(45), 0), nebulaPurple, Enum.Material.Neon)
	weldTo(handle, nodeU4)
	local nodeU5 = makePart(model, "StarNodeU_5", Vector3.new(0.13, 0.13, 0.13), CFrame.new(0, 1.62, 0.34) * CFrame.Angles(math.rad(36), math.rad(45), 0), starGlass, Enum.Material.Glass)
	weldTo(handle, nodeU5)
	local nodeU6 = makePart(model, "StarNodeU_6", Vector3.new(0.12, 0.12, 0.12), CFrame.new(0, 1.88, 0.52) * CFrame.Angles(math.rad(48), math.rad(45), 0), nebulaPurple, Enum.Material.Neon)
	weldTo(handle, nodeU6)
	local nodeU7 = makePart(model, "StarNodeU_7", Vector3.new(0.11, 0.11, 0.11), CFrame.new(0, 2.12, 0.74) * CFrame.Angles(math.rad(62), math.rad(45), 0), starGlass, Enum.Material.Glass)
	weldTo(handle, nodeU7)

	-- Upper Vector Truss Struts (Dual cross-braced struts between nodes)
	local tu1_L = makePart(model, "TrussU1_L", Vector3.new(0.05, 0.32, 0.05), CFrame.new(0.08, 0.64, 0.03) * CFrame.Angles(math.rad(8), math.rad(15), 0), starSilver, Enum.Material.Metal)
	weldTo(handle, tu1_L)
	local tu1_R = makePart(model, "TrussU1_R", Vector3.new(0.05, 0.32, 0.05), CFrame.new(-0.08, 0.64, 0.03) * CFrame.Angles(math.rad(8), -math.rad(15), 0), starSilver, Enum.Material.Metal)
	weldTo(handle, tu1_R)

	local tu2_L = makePart(model, "TrussU2_L", Vector3.new(0.05, 0.32, 0.05), CFrame.new(0.08, 0.92, 0.08) * CFrame.Angles(math.rad(15), math.rad(15), 0), astralIndigo, Enum.Material.Metal)
	weldTo(handle, tu2_L)
	local tu2_R = makePart(model, "TrussU2_R", Vector3.new(0.05, 0.32, 0.05), CFrame.new(-0.08, 0.92, 0.08) * CFrame.Angles(math.rad(15), -math.rad(15), 0), astralIndigo, Enum.Material.Metal)
	weldTo(handle, tu2_R)

	local tu3_L = makePart(model, "TrussU3_L", Vector3.new(0.04, 0.32, 0.04), CFrame.new(0.07, 1.20, 0.15) * CFrame.Angles(math.rad(22), math.rad(15), 0), starSilver, Enum.Material.Metal)
	weldTo(handle, tu3_L)
	local tu3_R = makePart(model, "TrussU3_R", Vector3.new(0.04, 0.32, 0.04), CFrame.new(-0.07, 1.20, 0.15) * CFrame.Angles(math.rad(22), -math.rad(15), 0), starSilver, Enum.Material.Metal)
	weldTo(handle, tu3_R)

	local tu4_L = makePart(model, "TrussU4_L", Vector3.new(0.04, 0.32, 0.04), CFrame.new(0.06, 1.48, 0.27) * CFrame.Angles(math.rad(31), math.rad(15), 0), astralIndigo, Enum.Material.Metal)
	weldTo(handle, tu4_L)
	local tu4_R = makePart(model, "TrussU4_R", Vector3.new(0.04, 0.32, 0.04), CFrame.new(-0.06, 1.48, 0.27) * CFrame.Angles(math.rad(31), -math.rad(15), 0), astralIndigo, Enum.Material.Metal)
	weldTo(handle, tu4_R)

	local tu5_L = makePart(model, "TrussU5_L", Vector3.new(0.04, 0.32, 0.04), CFrame.new(0.05, 1.75, 0.43) * CFrame.Angles(math.rad(42), math.rad(15), 0), starSilver, Enum.Material.Metal)
	weldTo(handle, tu5_L)
	local tu5_R = makePart(model, "TrussU5_R", Vector3.new(0.04, 0.32, 0.04), CFrame.new(-0.05, 1.75, 0.43) * CFrame.Angles(math.rad(42), -math.rad(15), 0), starSilver, Enum.Material.Metal)
	weldTo(handle, tu5_R)

	local tu6_L = makePart(model, "TrussU6_L", Vector3.new(0.04, 0.32, 0.04), CFrame.new(0.05, 2.00, 0.63) * CFrame.Angles(math.rad(55), math.rad(15), 0), astralIndigo, Enum.Material.Metal)
	weldTo(handle, tu6_L)
	local tu6_R = makePart(model, "TrussU6_R", Vector3.new(0.04, 0.32, 0.04), CFrame.new(-0.05, 2.00, 0.63) * CFrame.Angles(math.rad(55), -math.rad(15), 0), astralIndigo, Enum.Material.Metal)
	weldTo(handle, tu6_R)

	-- Upper Web Cross Braces (4 diagonal stabilizers)
	local webU1 = makePart(model, "WebU_1", Vector3.new(0.03, 0.24, 0.03), CFrame.new(0, 0.78, 0.08) * CFrame.Angles(math.rad(15), 0, math.rad(45)), starlightGold, Enum.Material.Metal)
	weldTo(handle, webU1)
	local webU2 = makePart(model, "WebU_2", Vector3.new(0.03, 0.24, 0.03), CFrame.new(0, 1.34, 0.24) * CFrame.Angles(math.rad(30), 0, -math.rad(45)), starlightGold, Enum.Material.Metal)
	weldTo(handle, webU2)

	-- Upper Dorsal Starlight Spine Guides
	local sguideU1 = makePart(model, "SpineGuideU_1", Vector3.new(0.04, 0.34, 0.06), CFrame.new(0, 0.84, -0.04) * CFrame.Angles(math.rad(13), 0, 0), starlightGold, Enum.Material.Metal)
	weldTo(handle, sguideU1)
	local sguideU2 = makePart(model, "SpineGuideU_2", Vector3.new(0.04, 0.34, 0.06), CFrame.new(0, 1.50, 0.18) * CFrame.Angles(math.rad(33), 0, 0), starlightGold, Enum.Material.Metal)
	weldTo(handle, sguideU2)

	-- Upper 5-Piece 4-Pointed Star Crown
	local starCrownU_C = makePart(model, "StarCrownU_Center", Vector3.new(0.12, 0.12, 0.12), CFrame.new(0, 2.24, 0.88) * CFrame.Angles(math.rad(66), 0, 0), starlightGold, Enum.Material.Neon)
	weldTo(handle, starCrownU_C)
	local starCrownU_N = makePart(model, "StarCrownU_North", Vector3.new(0.06, 0.22, 0.06), CFrame.new(0, 2.38, 0.98) * CFrame.Angles(math.rad(74), 0, 0), starSilver, Enum.Material.Metal)
	weldTo(handle, starCrownU_N)
	local starCrownU_S = makePart(model, "StarCrownU_South", Vector3.new(0.05, 0.14, 0.05), CFrame.new(0, 2.12, 0.80) * CFrame.Angles(math.rad(56), 0, 0), starSilver, Enum.Material.Metal)
	weldTo(handle, starCrownU_S)
	local starCrownU_E = makePart(model, "StarCrownU_East", Vector3.new(0.05, 0.14, 0.05), CFrame.new(0.12, 2.24, 0.88) * CFrame.Angles(math.rad(66), 0, -math.rad(90)), starSilver, Enum.Material.Metal)
	weldTo(handle, starCrownU_E)
	local starCrownU_W = makePart(model, "StarCrownU_West", Vector3.new(0.05, 0.14, 0.05), CFrame.new(-0.12, 2.24, 0.88) * CFrame.Angles(math.rad(66), 0, math.rad(90)), starSilver, Enum.Material.Metal)
	weldTo(handle, starCrownU_W)

	-- Lower Open Tetrahedral Space-Frame Vector Truss
	local nodeL1 = makePart(model, "StarNodeL_1", Vector3.new(0.16, 0.16, 0.16), CFrame.new(0, -0.50, 0.02) * CFrame.Angles(-math.rad(6), math.rad(45), 0), starGlass, Enum.Material.Glass)
	weldTo(handle, nodeL1)
	local nodeL2 = makePart(model, "StarNodeL_2", Vector3.new(0.15, 0.15, 0.15), CFrame.new(0, -0.78, 0.05) * CFrame.Angles(-math.rad(11), math.rad(45), 0), nebulaPurple, Enum.Material.Neon)
	weldTo(handle, nodeL2)
	local nodeL3 = makePart(model, "StarNodeL_3", Vector3.new(0.14, 0.14, 0.14), CFrame.new(0, -1.06, 0.11) * CFrame.Angles(-math.rad(18), math.rad(45), 0), starGlass, Enum.Material.Glass)
	weldTo(handle, nodeL3)
	local nodeL4 = makePart(model, "StarNodeL_4", Vector3.new(0.14, 0.14, 0.14), CFrame.new(0, -1.34, 0.20) * CFrame.Angles(-math.rad(26), math.rad(45), 0), nebulaPurple, Enum.Material.Neon)
	weldTo(handle, nodeL4)
	local nodeL5 = makePart(model, "StarNodeL_5", Vector3.new(0.13, 0.13, 0.13), CFrame.new(0, -1.62, 0.34) * CFrame.Angles(-math.rad(36), math.rad(45), 0), starGlass, Enum.Material.Glass)
	weldTo(handle, nodeL5)
	local nodeL6 = makePart(model, "StarNodeL_6", Vector3.new(0.12, 0.12, 0.12), CFrame.new(0, -1.88, 0.52) * CFrame.Angles(-math.rad(48), math.rad(45), 0), nebulaPurple, Enum.Material.Neon)
	weldTo(handle, nodeL6)
	local nodeL7 = makePart(model, "StarNodeL_7", Vector3.new(0.11, 0.11, 0.11), CFrame.new(0, -2.12, 0.74) * CFrame.Angles(-math.rad(62), math.rad(45), 0), starGlass, Enum.Material.Glass)
	weldTo(handle, nodeL7)

	-- Lower Vector Truss Struts
	local tl1_L = makePart(model, "TrussL1_L", Vector3.new(0.05, 0.32, 0.05), CFrame.new(0.08, -0.64, 0.03) * CFrame.Angles(-math.rad(8), math.rad(15), 0), starSilver, Enum.Material.Metal)
	weldTo(handle, tl1_L)
	local tl1_R = makePart(model, "TrussL1_R", Vector3.new(0.05, 0.32, 0.05), CFrame.new(-0.08, -0.64, 0.03) * CFrame.Angles(-math.rad(8), -math.rad(15), 0), starSilver, Enum.Material.Metal)
	weldTo(handle, tl1_R)

	local tl2_L = makePart(model, "TrussL2_L", Vector3.new(0.05, 0.32, 0.05), CFrame.new(0.08, -0.92, 0.08) * CFrame.Angles(-math.rad(15), math.rad(15), 0), astralIndigo, Enum.Material.Metal)
	weldTo(handle, tl2_L)
	local tl2_R = makePart(model, "TrussL2_R", Vector3.new(0.05, 0.32, 0.05), CFrame.new(-0.08, -0.92, 0.08) * CFrame.Angles(-math.rad(15), -math.rad(15), 0), astralIndigo, Enum.Material.Metal)
	weldTo(handle, tl2_R)

	local tl3_L = makePart(model, "TrussL3_L", Vector3.new(0.04, 0.32, 0.04), CFrame.new(0.07, -1.20, 0.15) * CFrame.Angles(-math.rad(22), math.rad(15), 0), starSilver, Enum.Material.Metal)
	weldTo(handle, tl3_L)
	local tl3_R = makePart(model, "TrussL3_R", Vector3.new(0.04, 0.32, 0.04), CFrame.new(-0.07, -1.20, 0.15) * CFrame.Angles(-math.rad(22), -math.rad(15), 0), starSilver, Enum.Material.Metal)
	weldTo(handle, tl3_R)

	local tl4_L = makePart(model, "TrussL4_L", Vector3.new(0.04, 0.32, 0.04), CFrame.new(0.06, -1.48, 0.27) * CFrame.Angles(-math.rad(31), math.rad(15), 0), astralIndigo, Enum.Material.Metal)
	weldTo(handle, tl4_L)
	local tl4_R = makePart(model, "TrussL4_R", Vector3.new(0.04, 0.32, 0.04), CFrame.new(-0.06, -1.48, 0.27) * CFrame.Angles(-math.rad(31), -math.rad(15), 0), astralIndigo, Enum.Material.Metal)
	weldTo(handle, tl4_R)

	local tl5_L = makePart(model, "TrussL5_L", Vector3.new(0.04, 0.32, 0.04), CFrame.new(0.05, -1.75, 0.43) * CFrame.Angles(-math.rad(42), math.rad(15), 0), starSilver, Enum.Material.Metal)
	weldTo(handle, tl5_L)
	local tl5_R = makePart(model, "TrussL5_R", Vector3.new(0.04, 0.32, 0.04), CFrame.new(-0.05, -1.75, 0.43) * CFrame.Angles(-math.rad(42), -math.rad(15), 0), starSilver, Enum.Material.Metal)
	weldTo(handle, tl5_R)

	local tl6_L = makePart(model, "TrussL6_L", Vector3.new(0.04, 0.32, 0.04), CFrame.new(0.05, -2.00, 0.63) * CFrame.Angles(-math.rad(55), math.rad(15), 0), astralIndigo, Enum.Material.Metal)
	weldTo(handle, tl6_L)
	local tl6_R = makePart(model, "TrussL6_R", Vector3.new(0.04, 0.32, 0.04), CFrame.new(-0.05, -2.00, 0.63) * CFrame.Angles(-math.rad(55), -math.rad(15), 0), astralIndigo, Enum.Material.Metal)
	weldTo(handle, tl6_R)

	-- Lower Web Cross Braces
	local webL1 = makePart(model, "WebL_1", Vector3.new(0.03, 0.24, 0.03), CFrame.new(0, -0.78, 0.08) * CFrame.Angles(-math.rad(15), 0, math.rad(45)), starlightGold, Enum.Material.Metal)
	weldTo(handle, webL1)
	local webL2 = makePart(model, "WebL_2", Vector3.new(0.03, 0.24, 0.03), CFrame.new(0, -1.34, 0.24) * CFrame.Angles(-math.rad(30), 0, -math.rad(45)), starlightGold, Enum.Material.Metal)
	weldTo(handle, webL2)

	-- Lower Dorsal Starlight Spine Guides
	local sguideL1 = makePart(model, "SpineGuideL_1", Vector3.new(0.04, 0.34, 0.06), CFrame.new(0, -0.84, -0.04) * CFrame.Angles(-math.rad(13), 0, 0), starlightGold, Enum.Material.Metal)
	weldTo(handle, sguideL1)
	local sguideL2 = makePart(model, "SpineGuideL_2", Vector3.new(0.04, 0.34, 0.06), CFrame.new(0, -1.50, 0.18) * CFrame.Angles(-math.rad(33), 0, 0), starlightGold, Enum.Material.Metal)
	weldTo(handle, sguideL2)

	-- Lower 5-Piece 4-Pointed Star Crown
	local starCrownL_C = makePart(model, "StarCrownL_Center", Vector3.new(0.12, 0.12, 0.12), CFrame.new(0, -2.24, 0.88) * CFrame.Angles(-math.rad(66), 0, 0), starlightGold, Enum.Material.Neon)
	weldTo(handle, starCrownL_C)
	local starCrownL_N = makePart(model, "StarCrownL_North", Vector3.new(0.06, 0.22, 0.06), CFrame.new(0, -2.38, 0.98) * CFrame.Angles(-math.rad(74), 0, 0), starSilver, Enum.Material.Metal)
	weldTo(handle, starCrownL_N)
	local starCrownL_S = makePart(model, "StarCrownL_South", Vector3.new(0.05, 0.14, 0.05), CFrame.new(0, -2.12, 0.80) * CFrame.Angles(-math.rad(56), 0, 0), starSilver, Enum.Material.Metal)
	weldTo(handle, starCrownL_S)
	local starCrownL_E = makePart(model, "StarCrownL_East", Vector3.new(0.05, 0.14, 0.05), CFrame.new(0.12, -2.24, 0.88) * CFrame.Angles(-math.rad(66), 0, -math.rad(90)), starSilver, Enum.Material.Metal)
	weldTo(handle, starCrownL_E)
	local starCrownL_W = makePart(model, "StarCrownL_West", Vector3.new(0.05, 0.14, 0.05), CFrame.new(-0.12, -2.24, 0.88) * CFrame.Angles(-math.rad(66), 0, math.rad(90)), starSilver, Enum.Material.Metal)
	weldTo(handle, starCrownL_W)

	local auraPrismU1 = makePart(model, "AuraPrismU_1", Vector3.new(0.06, 0.14, 0.06), CFrame.new(0.10, 1.20, 0.20) * CFrame.Angles(math.rad(20), math.rad(45), 0), starGlass, Enum.Material.Glass)
	weldTo(handle, auraPrismU1)
	local auraPrismU2 = makePart(model, "AuraPrismU_2", Vector3.new(0.06, 0.14, 0.06), CFrame.new(-0.10, 1.20, 0.20) * CFrame.Angles(math.rad(20), -math.rad(45), 0), starGlass, Enum.Material.Glass)
	weldTo(handle, auraPrismU2)
	local auraPrismL1 = makePart(model, "AuraPrismL_1", Vector3.new(0.06, 0.14, 0.06), CFrame.new(0.10, -1.20, 0.20) * CFrame.Angles(-math.rad(20), math.rad(45), 0), starGlass, Enum.Material.Glass)
	weldTo(handle, auraPrismL1)
	local auraPrismL2 = makePart(model, "AuraPrismL_2", Vector3.new(0.06, 0.14, 0.06), CFrame.new(-0.10, -1.20, 0.20) * CFrame.Angles(-math.rad(20), -math.rad(45), 0), starGlass, Enum.Material.Glass)
	weldTo(handle, auraPrismL2)
	local hubGemU = makePart(model, "HubGem_U", Vector3.new(0.08, 0.08, 0.08), CFrame.new(0, 0.36, -0.06), starlightGold, Enum.Material.Neon)
	weldTo(handle, hubGemU)
	local hubGemL = makePart(model, "HubGem_L", Vector3.new(0.08, 0.08, 0.08), CFrame.new(0, -0.36, -0.06), starlightGold, Enum.Material.Neon)
	weldTo(handle, hubGemL)
	-- Quantum Starlight Bowstring
	local bowString = makePart(model, "BowString", Vector3.new(0.045, 4.76, 0.045), CFrame.new(0, 0, 0.94), stringColor, Enum.Material.Fabric)
	weldTo(handle, bowString)

	addSocket(handle, "Grip", Vector3.zero)
	addSocket(handle, "Nock", Vector3.new(ARROW_REST.X, ARROW_REST.Y, 0.94))
	addSocket(handle, "TipUpper", Vector3.new(0, 2.38, 0.98))
	addSocket(handle, "TipLower", Vector3.new(0, -2.38, 0.98))
	addSocket(handle, "VfxTip", Vector3.new(0, 2.38, 0.98))
	addSocket(handle, "VfxBase", Vector3.new(0, -2.38, 0.98))
	addSocket(handle, "VfxCore", Vector3.zero)
	addSocket(handle, "VfxNock", Vector3.new(ARROW_REST.X, ARROW_REST.Y, 0.94))

	createHunterArrow(model, handle)
	return model
end

-- ============================================================================
-- 14. Infinity Genesis Bow (art_infinity_genesis_bow) - Origin Enhanced
-- ============================================================================
function WeaponModelBuilder.BuildInfinityGenesisBow(): Model
	local model = Instance.new("Model")
	model.Name = "art_infinity_genesis_bow"

	local chronoPlatinum = Color3.fromRGB(235, 240, 252)
	local chronoGold = Color3.fromRGB(255, 215, 80)
	local eventHorizonDark = Color3.fromRGB(18, 12, 32)
	local singularityCore = Color3.fromRGB(240, 160, 255)
	local temporalCyan = Color3.fromRGB(120, 235, 255)
	local mobiusGlass = Color3.fromRGB(180, 220, 255)
	local stringColor = Color3.fromRGB(245, 235, 255)

	-- Chrono-Platinum Riser Cradle & Temporal Anchors
	local handle = makePart(model, "Handle", Vector3.new(0.26, 0.76, 0.34), CFrame.new(0, 0, 0), chronoPlatinum, Enum.Material.Metal)
	model.PrimaryPart = handle

	-- Central Singularity Event Horizon Ring (8 octagonal glass facets + center bead)
	local eh1 = makePart(model, "Torus_1", Vector3.new(0.04, 0.16, 0.06), CFrame.new(0.18, 0.08, -0.06) * CFrame.Angles(0, 0, math.rad(22)), mobiusGlass, Enum.Material.Glass)
	weldTo(handle, eh1)
	local eh2 = makePart(model, "Torus_2", Vector3.new(0.04, 0.16, 0.06), CFrame.new(0.18, -0.08, -0.06) * CFrame.Angles(0, 0, -math.rad(22)), mobiusGlass, Enum.Material.Glass)
	weldTo(handle, eh2)
	local eh3 = makePart(model, "Torus_3", Vector3.new(0.04, 0.16, 0.06), CFrame.new(-0.18, 0.08, -0.06) * CFrame.Angles(0, 0, -math.rad(22)), mobiusGlass, Enum.Material.Glass)
	weldTo(handle, eh3)
	local eh4 = makePart(model, "Torus_4", Vector3.new(0.04, 0.16, 0.06), CFrame.new(-0.18, -0.08, -0.06) * CFrame.Angles(0, 0, math.rad(22)), mobiusGlass, Enum.Material.Glass)
	weldTo(handle, eh4)
	local eh5 = makePart(model, "Torus_5", Vector3.new(0.16, 0.04, 0.06), CFrame.new(0.08, 0.18, -0.06) * CFrame.Angles(0, 0, -math.rad(22)), mobiusGlass, Enum.Material.Glass)
	weldTo(handle, eh5)
	local eh6 = makePart(model, "Torus_6", Vector3.new(0.16, 0.04, 0.06), CFrame.new(-0.08, 0.18, -0.06) * CFrame.Angles(0, 0, math.rad(22)), mobiusGlass, Enum.Material.Glass)
	weldTo(handle, eh6)
	local eh7 = makePart(model, "Torus_7", Vector3.new(0.16, 0.04, 0.06), CFrame.new(0.08, -0.18, -0.06) * CFrame.Angles(0, 0, math.rad(22)), mobiusGlass, Enum.Material.Glass)
	weldTo(handle, eh7)
	local eh8 = makePart(model, "Torus_8", Vector3.new(0.16, 0.04, 0.06), CFrame.new(-0.08, -0.18, -0.06) * CFrame.Angles(0, 0, -math.rad(22)), mobiusGlass, Enum.Material.Glass)
	weldTo(handle, eh8)

	local singBead = makePart(model, "SingularityBead", Vector3.new(0.16, 0.16, 0.16), CFrame.new(0, 0, -0.06), singularityCore, Enum.Material.Neon)
	weldTo(handle, singBead)
	local needle1 = makePart(model, "Needle_1", Vector3.new(0.03, 0.12, 0.03), CFrame.new(0.10, 0.10, -0.06) * CFrame.Angles(0, 0, -math.rad(45)), chronoGold, Enum.Material.Metal)
	weldTo(handle, needle1)
	local needle2 = makePart(model, "Needle_2", Vector3.new(0.03, 0.12, 0.03), CFrame.new(-0.10, 0.10, -0.06) * CFrame.Angles(0, 0, math.rad(45)), chronoGold, Enum.Material.Metal)
	weldTo(handle, needle2)
	local needle3 = makePart(model, "Needle_3", Vector3.new(0.03, 0.12, 0.03), CFrame.new(0.10, -0.10, -0.06) * CFrame.Angles(0, 0, math.rad(45)), chronoGold, Enum.Material.Metal)
	weldTo(handle, needle3)
	local needle4 = makePart(model, "Needle_4", Vector3.new(0.03, 0.12, 0.03), CFrame.new(-0.10, -0.10, -0.06) * CFrame.Angles(0, 0, -math.rad(45)), chronoGold, Enum.Material.Metal)
	weldTo(handle, needle4)

	local anchorU = makePart(model, "Anchor_U", Vector3.new(0.30, 0.06, 0.32), CFrame.new(0, 0.32, 0), chronoGold, Enum.Material.Metal)
	weldTo(handle, anchorU)
	local anchorL = makePart(model, "Anchor_L", Vector3.new(0.30, 0.06, 0.32), CFrame.new(0, -0.32, 0), chronoGold, Enum.Material.Metal)
	weldTo(handle, anchorL)
	local arrowRest = makePart(model, "GenesisArrowRest", Vector3.new(0.08, 0.16, 0.20), CFrame.new(0.15, 0.10, -0.08), chronoGold, Enum.Material.Metal)
	weldTo(handle, arrowRest)

	-- Upper Mobius Continuous Loop Rails (Forward Path 7 segs + Return Path 7 segs)
	local muf1 = makePart(model, "MobiusUF_1", Vector3.new(0.07, 0.28, 0.12), CFrame.new(0.09, 0.46, 0.02) * CFrame.Angles(math.rad(5), math.rad(8), 0), chronoPlatinum, Enum.Material.Metal)
	weldTo(handle, muf1)
	local muf2 = makePart(model, "MobiusUF_2", Vector3.new(0.06, 0.28, 0.11), CFrame.new(0.10, 0.72, 0.05) * CFrame.Angles(math.rad(10), math.rad(12), 0), chronoPlatinum, Enum.Material.Metal)
	weldTo(handle, muf2)
	local muf3 = makePart(model, "MobiusUF_3", Vector3.new(0.06, 0.28, 0.10), CFrame.new(0.10, 0.98, 0.10) * CFrame.Angles(math.rad(16), math.rad(18), 0), chronoGold, Enum.Material.Metal)
	weldTo(handle, muf3)
	local muf4 = makePart(model, "MobiusUF_4", Vector3.new(0.05, 0.28, 0.09), CFrame.new(0.09, 1.24, 0.19) * CFrame.Angles(math.rad(24), math.rad(24), 0), chronoGold, Enum.Material.Metal)
	weldTo(handle, muf4)
	local muf5 = makePart(model, "MobiusUF_5", Vector3.new(0.05, 0.28, 0.09), CFrame.new(0.08, 1.48, 0.32) * CFrame.Angles(math.rad(34), math.rad(28), 0), chronoPlatinum, Enum.Material.Metal)
	weldTo(handle, muf5)
	local muf6 = makePart(model, "MobiusUF_6", Vector3.new(0.05, 0.28, 0.08), CFrame.new(0.06, 1.70, 0.48) * CFrame.Angles(math.rad(46), math.rad(32), 0), chronoPlatinum, Enum.Material.Metal)
	weldTo(handle, muf6)
	local muf7 = makePart(model, "MobiusUF_7", Vector3.new(0.05, 0.30, 0.08), CFrame.new(0.04, 1.90, 0.66) * CFrame.Angles(math.rad(58), math.rad(34), 0), chronoPlatinum, Enum.Material.Metal)
	weldTo(handle, muf7)

	local mur1 = makePart(model, "MobiusUR_1", Vector3.new(0.07, 0.28, 0.12), CFrame.new(-0.09, 0.46, 0.02) * CFrame.Angles(math.rad(5), -math.rad(8), 0), chronoPlatinum, Enum.Material.Metal)
	weldTo(handle, mur1)
	local mur2 = makePart(model, "MobiusUR_2", Vector3.new(0.06, 0.28, 0.11), CFrame.new(-0.10, 0.72, 0.05) * CFrame.Angles(math.rad(10), -math.rad(12), 0), chronoPlatinum, Enum.Material.Metal)
	weldTo(handle, mur2)
	local mur3 = makePart(model, "MobiusUR_3", Vector3.new(0.06, 0.28, 0.10), CFrame.new(-0.10, 0.98, 0.10) * CFrame.Angles(math.rad(16), -math.rad(18), 0), chronoGold, Enum.Material.Metal)
	weldTo(handle, mur3)
	local mur4 = makePart(model, "MobiusUR_4", Vector3.new(0.05, 0.28, 0.09), CFrame.new(-0.09, 1.24, 0.19) * CFrame.Angles(math.rad(24), -math.rad(24), 0), chronoGold, Enum.Material.Metal)
	weldTo(handle, mur4)
	local mur5 = makePart(model, "MobiusUR_5", Vector3.new(0.05, 0.28, 0.09), CFrame.new(-0.08, 1.48, 0.32) * CFrame.Angles(math.rad(34), -math.rad(28), 0), chronoPlatinum, Enum.Material.Metal)
	weldTo(handle, mur5)
	local mur6 = makePart(model, "MobiusUR_6", Vector3.new(0.05, 0.28, 0.08), CFrame.new(-0.06, 1.70, 0.48) * CFrame.Angles(math.rad(46), -math.rad(32), 0), chronoPlatinum, Enum.Material.Metal)
	weldTo(handle, mur6)
	local mur7 = makePart(model, "MobiusUR_7", Vector3.new(0.05, 0.30, 0.08), CFrame.new(-0.04, 1.90, 0.66) * CFrame.Angles(math.rad(58), -math.rad(34), 0), chronoPlatinum, Enum.Material.Metal)
	weldTo(handle, mur7)

	-- Upper Orbital Rail Couplers (Quantum lock clips)
	local coupU1 = makePart(model, "CouplerU_1", Vector3.new(0.24, 0.05, 0.14), CFrame.new(0, 0.72, 0.05) * CFrame.Angles(math.rad(10), 0, 0), temporalCyan, Enum.Material.Neon)
	weldTo(handle, coupU1)
	local coupU2 = makePart(model, "CouplerU_2", Vector3.new(0.22, 0.05, 0.13), CFrame.new(0, 1.24, 0.19) * CFrame.Angles(math.rad(24), 0, 0), temporalCyan, Enum.Material.Neon)
	weldTo(handle, coupU2)
	local coupU3 = makePart(model, "CouplerU_3", Vector3.new(0.20, 0.05, 0.12), CFrame.new(0, 1.70, 0.48) * CFrame.Angles(math.rad(46), 0, 0), temporalCyan, Enum.Material.Neon)
	weldTo(handle, coupU3)

	-- Upper Chrono-Resonance Harmonic Fins & Crystals
	local finU1 = makePart(model, "ChronoFinU_1", Vector3.new(0.04, 0.22, 0.16), CFrame.new(0.12, 1.10, 0.18) * CFrame.Angles(math.rad(20), math.rad(20), 0), mobiusGlass, Enum.Material.Glass)
	weldTo(handle, finU1)
	local finU2 = makePart(model, "ChronoFinU_2", Vector3.new(0.04, 0.22, 0.16), CFrame.new(-0.12, 1.10, 0.18) * CFrame.Angles(math.rad(20), -math.rad(20), 0), mobiusGlass, Enum.Material.Glass)
	weldTo(handle, finU2)
	local finU3 = makePart(model, "ChronoFinU_3", Vector3.new(0.04, 0.20, 0.14), CFrame.new(0.10, 1.56, 0.38) * CFrame.Angles(math.rad(38), math.rad(20), 0), mobiusGlass, Enum.Material.Glass)
	weldTo(handle, finU3)
	local finU4 = makePart(model, "ChronoFinU_4", Vector3.new(0.04, 0.20, 0.14), CFrame.new(-0.10, 1.56, 0.38) * CFrame.Angles(math.rad(38), -math.rad(20), 0), mobiusGlass, Enum.Material.Glass)
	weldTo(handle, finU4)

	-- Upper Interlocking Crown Finials
	local crownU_Base = makePart(model, "CrownU_Base", Vector3.new(0.22, 0.20, 0.18), CFrame.new(0, 2.06, 0.76) * CFrame.Angles(math.rad(66), 0, 0), chronoPlatinum, Enum.Material.Metal)
	weldTo(handle, crownU_Base)
	local crownU_Pin = makePart(model, "CrownU_Pinnacle", Vector3.new(0.08, 0.26, 0.08), CFrame.new(0, 2.20, 0.90) * CFrame.Angles(math.rad(74), 0, 0), temporalCyan, Enum.Material.Neon)
	weldTo(handle, crownU_Pin)
	local crownU_WingL = makePart(model, "CrownU_WingL", Vector3.new(0.04, 0.20, 0.12), CFrame.new(0.10, 2.12, 0.84) * CFrame.Angles(math.rad(70), math.rad(25), 0), chronoGold, Enum.Material.Metal)
	weldTo(handle, crownU_WingL)
	local crownU_WingR = makePart(model, "CrownU_WingR", Vector3.new(0.04, 0.20, 0.12), CFrame.new(-0.10, 2.12, 0.84) * CFrame.Angles(math.rad(70), -math.rad(25), 0), chronoGold, Enum.Material.Metal)
	weldTo(handle, crownU_WingR)

	-- Lower Mobius Continuous Loop Rails (Forward Path 7 segs + Return Path 7 segs)
	local mlf1 = makePart(model, "MobiusLF_1", Vector3.new(0.07, 0.28, 0.12), CFrame.new(0.09, -0.46, 0.02) * CFrame.Angles(-math.rad(5), math.rad(8), 0), chronoPlatinum, Enum.Material.Metal)
	weldTo(handle, mlf1)
	local mlf2 = makePart(model, "MobiusLF_2", Vector3.new(0.06, 0.28, 0.11), CFrame.new(0.10, -0.72, 0.05) * CFrame.Angles(-math.rad(10), math.rad(12), 0), chronoPlatinum, Enum.Material.Metal)
	weldTo(handle, mlf2)
	local mlf3 = makePart(model, "MobiusLF_3", Vector3.new(0.06, 0.28, 0.10), CFrame.new(0.10, -0.98, 0.10) * CFrame.Angles(-math.rad(16), math.rad(18), 0), chronoGold, Enum.Material.Metal)
	weldTo(handle, mlf3)
	local mlf4 = makePart(model, "MobiusLF_4", Vector3.new(0.05, 0.28, 0.09), CFrame.new(0.09, -1.24, 0.19) * CFrame.Angles(-math.rad(24), math.rad(24), 0), chronoGold, Enum.Material.Metal)
	weldTo(handle, mlf4)
	local mlf5 = makePart(model, "MobiusLF_5", Vector3.new(0.05, 0.28, 0.09), CFrame.new(0.08, -1.48, 0.32) * CFrame.Angles(-math.rad(34), math.rad(28), 0), chronoPlatinum, Enum.Material.Metal)
	weldTo(handle, mlf5)
	local mlf6 = makePart(model, "MobiusLF_6", Vector3.new(0.05, 0.28, 0.08), CFrame.new(0.06, -1.70, 0.48) * CFrame.Angles(-math.rad(46), math.rad(32), 0), chronoPlatinum, Enum.Material.Metal)
	weldTo(handle, mlf6)
	local mlf7 = makePart(model, "MobiusLF_7", Vector3.new(0.05, 0.30, 0.08), CFrame.new(0.04, -1.90, 0.66) * CFrame.Angles(-math.rad(58), math.rad(34), 0), chronoPlatinum, Enum.Material.Metal)
	weldTo(handle, mlf7)

	local mlr1 = makePart(model, "MobiusLR_1", Vector3.new(0.07, 0.28, 0.12), CFrame.new(-0.09, -0.46, 0.02) * CFrame.Angles(-math.rad(5), -math.rad(8), 0), chronoPlatinum, Enum.Material.Metal)
	weldTo(handle, mlr1)
	local mlr2 = makePart(model, "MobiusLR_2", Vector3.new(0.06, 0.28, 0.11), CFrame.new(-0.10, -0.72, 0.05) * CFrame.Angles(-math.rad(10), -math.rad(12), 0), chronoPlatinum, Enum.Material.Metal)
	weldTo(handle, mlr2)
	local mlr3 = makePart(model, "MobiusLR_3", Vector3.new(0.06, 0.28, 0.10), CFrame.new(-0.10, -0.98, 0.10) * CFrame.Angles(-math.rad(16), -math.rad(18), 0), chronoGold, Enum.Material.Metal)
	weldTo(handle, mlr3)
	local mlr4 = makePart(model, "MobiusLR_4", Vector3.new(0.05, 0.28, 0.09), CFrame.new(-0.09, -1.24, 0.19) * CFrame.Angles(-math.rad(24), -math.rad(24), 0), chronoGold, Enum.Material.Metal)
	weldTo(handle, mlr4)
	local mlr5 = makePart(model, "MobiusLR_5", Vector3.new(0.05, 0.28, 0.09), CFrame.new(-0.08, -1.48, 0.32) * CFrame.Angles(-math.rad(34), -math.rad(28), 0), chronoPlatinum, Enum.Material.Metal)
	weldTo(handle, mlr5)
	local mlr6 = makePart(model, "MobiusLR_6", Vector3.new(0.05, 0.28, 0.08), CFrame.new(-0.06, -1.70, 0.48) * CFrame.Angles(-math.rad(46), -math.rad(32), 0), chronoPlatinum, Enum.Material.Metal)
	weldTo(handle, mlr6)
	local mlr7 = makePart(model, "MobiusLR_7", Vector3.new(0.05, 0.30, 0.08), CFrame.new(-0.04, -1.90, 0.66) * CFrame.Angles(-math.rad(58), -math.rad(34), 0), chronoPlatinum, Enum.Material.Metal)
	weldTo(handle, mlr7)

	-- Lower Orbital Rail Couplers
	local coupL1 = makePart(model, "CouplerL_1", Vector3.new(0.24, 0.05, 0.14), CFrame.new(0, -0.72, 0.05) * CFrame.Angles(-math.rad(10), 0, 0), temporalCyan, Enum.Material.Neon)
	weldTo(handle, coupL1)
	local coupL2 = makePart(model, "CouplerL_2", Vector3.new(0.22, 0.05, 0.13), CFrame.new(0, -1.24, 0.19) * CFrame.Angles(-math.rad(24), 0, 0), temporalCyan, Enum.Material.Neon)
	weldTo(handle, coupL2)
	local coupL3 = makePart(model, "CouplerL_3", Vector3.new(0.20, 0.05, 0.12), CFrame.new(0, -1.70, 0.48) * CFrame.Angles(-math.rad(46), 0, 0), temporalCyan, Enum.Material.Neon)
	weldTo(handle, coupL3)

	-- Lower Chrono-Resonance Harmonic Fins & Crystals
	local finL1 = makePart(model, "ChronoFinL_1", Vector3.new(0.04, 0.22, 0.16), CFrame.new(0.12, -1.10, 0.18) * CFrame.Angles(-math.rad(20), math.rad(20), 0), mobiusGlass, Enum.Material.Glass)
	weldTo(handle, finL1)
	local finL2 = makePart(model, "ChronoFinL_2", Vector3.new(0.04, 0.22, 0.16), CFrame.new(-0.12, -1.10, 0.18) * CFrame.Angles(-math.rad(20), -math.rad(20), 0), mobiusGlass, Enum.Material.Glass)
	weldTo(handle, finL2)
	local finL3 = makePart(model, "ChronoFinL_3", Vector3.new(0.04, 0.20, 0.14), CFrame.new(0.10, -1.56, 0.38) * CFrame.Angles(-math.rad(38), math.rad(20), 0), mobiusGlass, Enum.Material.Glass)
	weldTo(handle, finL3)
	local finL4 = makePart(model, "ChronoFinL_4", Vector3.new(0.04, 0.20, 0.14), CFrame.new(-0.10, -1.56, 0.38) * CFrame.Angles(-math.rad(38), -math.rad(20), 0), mobiusGlass, Enum.Material.Glass)
	weldTo(handle, finL4)

	-- Lower Interlocking Crown Finials
	local crownL_Base = makePart(model, "CrownL_Base", Vector3.new(0.22, 0.20, 0.18), CFrame.new(0, -2.06, 0.76) * CFrame.Angles(-math.rad(66), 0, 0), chronoPlatinum, Enum.Material.Metal)
	weldTo(handle, crownL_Base)
	local crownL_Pin = makePart(model, "CrownL_Pinnacle", Vector3.new(0.08, 0.26, 0.08), CFrame.new(0, -2.20, 0.90) * CFrame.Angles(-math.rad(74), 0, 0), temporalCyan, Enum.Material.Neon)
	weldTo(handle, crownL_Pin)
	local crownL_WingL = makePart(model, "CrownL_WingL", Vector3.new(0.04, 0.20, 0.12), CFrame.new(0.10, -2.12, 0.84) * CFrame.Angles(-math.rad(70), math.rad(25), 0), chronoGold, Enum.Material.Metal)
	weldTo(handle, crownL_WingL)
	local crownL_WingR = makePart(model, "CrownL_WingR", Vector3.new(0.04, 0.20, 0.12), CFrame.new(-0.10, -2.12, 0.84) * CFrame.Angles(-math.rad(70), -math.rad(25), 0), chronoGold, Enum.Material.Metal)
	weldTo(handle, crownL_WingR)

	local qLockU1 = makePart(model, "QuantumLockU_1", Vector3.new(0.14, 0.04, 0.08), CFrame.new(0, 0.98, 0.10), temporalCyan, Enum.Material.Neon)
	weldTo(handle, qLockU1)
	local qLockU2 = makePart(model, "QuantumLockU_2", Vector3.new(0.12, 0.04, 0.08), CFrame.new(0, 1.48, 0.32), temporalCyan, Enum.Material.Neon)
	weldTo(handle, qLockU2)
	local qLockL1 = makePart(model, "QuantumLockL_1", Vector3.new(0.14, 0.04, 0.08), CFrame.new(0, -0.98, 0.10), temporalCyan, Enum.Material.Neon)
	weldTo(handle, qLockL1)
	local qLockL2 = makePart(model, "QuantumLockL_2", Vector3.new(0.12, 0.04, 0.08), CFrame.new(0, -1.48, 0.32), temporalCyan, Enum.Material.Neon)
	weldTo(handle, qLockL2)
	local bolt1 = makePart(model, "AnchorBolt_1", Vector3.new(0.06, 0.06, 0.06), CFrame.new(0.12, 0.32, 0.10), chronoGold, Enum.Material.Metal)
	weldTo(handle, bolt1)
	local bolt2 = makePart(model, "AnchorBolt_2", Vector3.new(0.06, 0.06, 0.06), CFrame.new(-0.12, 0.32, 0.10), chronoGold, Enum.Material.Metal)
	weldTo(handle, bolt2)
	local bolt3 = makePart(model, "AnchorBolt_3", Vector3.new(0.06, 0.06, 0.06), CFrame.new(0.12, -0.32, 0.10), chronoGold, Enum.Material.Metal)
	weldTo(handle, bolt3)
	local bolt4 = makePart(model, "AnchorBolt_4", Vector3.new(0.06, 0.06, 0.06), CFrame.new(-0.12, -0.32, 0.10), chronoGold, Enum.Material.Metal)
	weldTo(handle, bolt4)
	local flowGuide = makePart(model, "TemporalFlowGuide", Vector3.new(0.08, 0.28, 0.08), CFrame.new(0, 0, 0.12), singularityCore, Enum.Material.Neon)
	weldTo(handle, flowGuide)
	-- Temporal Filament Bowstring
	local bowString = makePart(model, "BowString", Vector3.new(0.045, 4.40, 0.045), CFrame.new(0, 0, 0.86), stringColor, Enum.Material.Fabric)
	weldTo(handle, bowString)

	addSocket(handle, "Grip", Vector3.zero)
	addSocket(handle, "Nock", Vector3.new(ARROW_REST.X, ARROW_REST.Y, 0.86))
	addSocket(handle, "TipUpper", Vector3.new(0, 2.20, 0.90))
	addSocket(handle, "TipLower", Vector3.new(0, -2.20, 0.90))
	addSocket(handle, "VfxTip", Vector3.new(0, 2.20, 0.90))
	addSocket(handle, "VfxBase", Vector3.new(0, -2.20, 0.90))
	addSocket(handle, "VfxCore", Vector3.zero)
	addSocket(handle, "VfxNock", Vector3.new(ARROW_REST.X, ARROW_REST.Y, 0.86))

	createHunterArrow(model, handle)
	return model
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
	local model = Instance.new("Model")
	model.Name = "art_iron_broadsword"

	local castIron = Color3.fromRGB(115, 118, 125)
	local steelEdge = Color3.fromRGB(175, 180, 190)
	local leatherDark = Color3.fromRGB(75, 52, 38)
	local darkWood = Color3.fromRGB(105, 75, 48)
	local bandedIron = Color3.fromRGB(85, 88, 95)

	

-- Sword Assembly (14 parts: chivalric broadsword with converging wedge tip)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.20, 0.85, 0.20)
	handle.CFrame = CFrame.new(0, 0, 0)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = model
	model.PrimaryPart = handle

	local gripCyl = makeCylinder(model, "GripCylinder", 0.76, 0.18, CFrame.new(0, 0, 0), leatherDark)
	weldTo(handle, gripCyl)
	local gripWrap = makeCylinder(model, "GripWrap", 0.24, 0.20, CFrame.new(0, 0, 0), leatherDark)
	weldTo(handle, gripWrap)

	local pommelBall = makeBall(model, "PommelBall", 0.32, CFrame.new(0, -0.54, 0), bandedIron, Enum.Material.Metal)
	weldTo(handle, pommelBall)
	local pommelFinial = makeBall(model, "PommelFinial", 0.14, CFrame.new(0, -0.70, 0), castIron, Enum.Material.Metal)
	weldTo(handle, pommelFinial)

	local guardCenter = makePart(model, "GuardCenter", Vector3.new(0.26, 0.18, 0.22), CFrame.new(0, 0.46, 0), bandedIron, Enum.Material.Metal)
	weldTo(handle, guardCenter)
	local quillonL = makePart(model, "QuillonL", Vector3.new(0.16, 0.10, 0.42), CFrame.new(0, 0.48, 0.35) * CFrame.Angles(math.rad(6), 0, 0), castIron, Enum.Material.Metal)
	weldTo(handle, quillonL)
	local quillonR = makePart(model, "QuillonR", Vector3.new(0.16, 0.10, 0.42), CFrame.new(0, 0.48, -0.35) * CFrame.Angles(math.rad(-6), 0, 0), castIron, Enum.Material.Metal)
	weldTo(handle, quillonR)

	local ricasso = makePart(model, "Ricasso", Vector3.new(0.42, 0.35, 0.07), CFrame.new(0, 0.70, 0), castIron, Enum.Material.Metal)
	weldTo(handle, ricasso)
	local fuller = makePart(model, "BladeFuller", Vector3.new(0.16, 2.10, 0.065), CFrame.new(0, 1.90, 0), castIron, Enum.Material.Metal)
	weldTo(handle, fuller)
	local edgeFwd = makePart(model, "BladeEdgeFwd", Vector3.new(0.16, 2.05, 0.045), CFrame.new(0.14, 1.90, 0), steelEdge, Enum.Material.Metal)
	weldTo(handle, edgeFwd)
	local edgeBack = makePart(model, "BladeEdgeBack", Vector3.new(0.16, 2.05, 0.045), CFrame.new(-0.14, 1.90, 0), steelEdge, Enum.Material.Metal)
	weldTo(handle, edgeBack)

	local tipFwd = makeWedge(model, "TipFwd", Vector3.new(0.045, 0.45, 0.22), CFrame.new(0.11, 3.15, 0) * CFrame.Angles(0, math.rad(-90), 0), steelEdge, Enum.Material.Metal)
	weldTo(handle, tipFwd)
	local tipBack = makeWedge(model, "TipBack", Vector3.new(0.045, 0.45, 0.22), CFrame.new(-0.11, 3.15, 0) * CFrame.Angles(0, math.rad(90), 0), steelEdge, Enum.Material.Metal)
	weldTo(handle, tipBack)

	addSocket(handle, "Grip", Vector3.new(0, 0, 0), Vector3.new(0, -90, 0))
	addSocket(handle, "Tip", Vector3.new(0, 3.40, 0), Vector3.new(0, 0, 0))
	addSocket(handle, "VfxTip", Vector3.new(0, 3.40, 0))
	addSocket(handle, "VfxBase", Vector3.new(0, 0.65, 0))
	addSocket(handle, "VfxCore", Vector3.new(0, 0.46, 0))

	local shieldModel = Instance.new("Model")
	shieldModel.Name = "OffhandShield"
	shieldModel.Parent = model

	local shieldHandle = makePart(shieldModel, "HandleS", Vector3.new(0.20, 0.60, 0.20), CFrame.new(0, 0, 0), leatherDark)
	shieldModel.PrimaryPart = shieldHandle

	local faceCenter = makePart(shieldModel, "ShieldFaceCenter", Vector3.new(0.16, 2.30, 1.20), CFrame.new(-0.28, 0, 0), darkWood, Enum.Material.Wood)
	weldTo(shieldHandle, faceCenter)
	local faceTop = makePart(shieldModel, "ShieldFaceTop", Vector3.new(0.16, 0.40, 1.10), CFrame.new(-0.28, 1.30, 0), darkWood, Enum.Material.Wood)
	weldTo(shieldHandle, faceTop)
	local faceBottom = makePart(shieldModel, "ShieldFaceBottom", Vector3.new(0.16, 0.60, 0.80), CFrame.new(-0.28, -1.35, 0), darkWood, Enum.Material.Wood)
	weldTo(shieldHandle, faceBottom)

	local rimTop = makePart(shieldModel, "ShieldRimTop", Vector3.new(0.20, 0.14, 1.26), CFrame.new(-0.30, 1.50, 0), bandedIron, Enum.Material.Metal)
	weldTo(shieldHandle, rimTop)
	local rimLeft = makePart(shieldModel, "ShieldRimLeft", Vector3.new(0.20, 2.70, 0.14), CFrame.new(-0.30, 0.05, 0.62), bandedIron, Enum.Material.Metal)
	weldTo(shieldHandle, rimLeft)
	local rimRight = makePart(shieldModel, "ShieldRimRight", Vector3.new(0.20, 2.70, 0.14), CFrame.new(-0.30, 0.05, -0.62), bandedIron, Enum.Material.Metal)
	weldTo(shieldHandle, rimRight)

	local bossIron = makePart(shieldModel, "ShieldBossIron", Vector3.new(0.26, 0.50, 0.50), CFrame.new(-0.35, 0.20, 0), castIron, Enum.Material.Metal)
	weldTo(shieldHandle, bossIron)
	local bossSpike = makePart(shieldModel, "ShieldBossSpike", Vector3.new(0.30, 0.22, 0.22), CFrame.new(-0.42, 0.20, 0), bandedIron, Enum.Material.Metal)
	weldTo(shieldHandle, bossSpike)

	local strapUpper = makePart(shieldModel, "ShieldStrapUpper", Vector3.new(0.14, 0.12, 0.42), CFrame.new(-0.10, 0.25, 0), leatherDark)
	weldTo(shieldHandle, strapUpper)
	local strapLower = makePart(shieldModel, "ShieldStrapLower", Vector3.new(0.14, 0.12, 0.42), CFrame.new(-0.10, -0.25, 0), leatherDark)
	weldTo(shieldHandle, strapLower)
	local bracketPlate = makePart(shieldModel, "ShieldBracketPlate", Vector3.new(0.16, 0.50, 0.16), CFrame.new(-0.16, 0, 0), bandedIron, Enum.Material.Metal)
	weldTo(shieldHandle, bracketPlate)

	addSocket(shieldHandle, "ShieldMount", Vector3.new(-0.18, 0, 0), Vector3.new(0, 90, 0))
	addSocket(shieldHandle, "VfxShieldCenter", Vector3.new(-0.38, 0.10, 0))

	return model
end


function WeaponModelBuilder.BuildTemperedBastardSword(): Model
	local model = Instance.new("Model")
	model.Name = "art_tempered_bastard_sword"

	local darkSteel = Color3.fromRGB(85, 90, 100)
	local temperedEdge = Color3.fromRGB(195, 202, 215)
	local brassInlay = Color3.fromRGB(185, 145, 65)
	local gripCord = Color3.fromRGB(55, 42, 35)
	local rimPlate = Color3.fromRGB(130, 135, 145)

	

-- Sword Assembly (18 parts: tempered hand-and-a-half bastard sword with brass quillons)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.20, 0.95, 0.20)
	handle.CFrame = CFrame.new(0, 0, 0)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = model
	model.PrimaryPart = handle

	local gripCyl = makeCylinder(model, "GripCylinder", 0.88, 0.18, CFrame.new(0, 0, 0), gripCord)
	weldTo(handle, gripCyl)
	local gripWrap1 = makeCylinder(model, "GripWrap1", 0.12, 0.20, CFrame.new(0, -0.22, 0), brassInlay, Enum.Material.Metal)
	weldTo(handle, gripWrap1)
	local gripWrap2 = makeCylinder(model, "GripWrap2", 0.12, 0.20, CFrame.new(0, 0.22, 0), brassInlay, Enum.Material.Metal)
	weldTo(handle, gripWrap2)

	local pommelNeck = makeCylinder(model, "PommelNeck", 0.10, 0.22, CFrame.new(0, -0.52, 0), darkSteel, Enum.Material.Metal)
	weldTo(handle, pommelNeck)
	local pommelBall = makeBall(model, "PommelBall", 0.34, CFrame.new(0, -0.66, 0), darkSteel, Enum.Material.Metal)
	weldTo(handle, pommelBall)
	local pommelFinial = makeBall(model, "PommelFinial", 0.14, CFrame.new(0, -0.84, 0), brassInlay, Enum.Material.Metal)
	weldTo(handle, pommelFinial)

	local guardCenter = makePart(model, "GuardCenter", Vector3.new(0.28, 0.20, 0.22), CFrame.new(0, 0.52, 0), darkSteel, Enum.Material.Metal)
	weldTo(handle, guardCenter)
	local guardEcusson = makePart(model, "GuardEcusson", Vector3.new(0.22, 0.26, 0.08), CFrame.new(0, 0.54, 0.10), brassInlay, Enum.Material.Metal)
	weldTo(handle, guardEcusson)
	local quillonL = makePart(model, "QuillonL", Vector3.new(0.18, 0.12, 0.46), CFrame.new(0, 0.54, 0.38) * CFrame.Angles(math.rad(8), 0, 0), temperedEdge, Enum.Material.Metal)
	weldTo(handle, quillonL)
	local quillonR = makePart(model, "QuillonR", Vector3.new(0.18, 0.12, 0.46), CFrame.new(0, 0.54, -0.38) * CFrame.Angles(math.rad(-8), 0, 0), temperedEdge, Enum.Material.Metal)
	weldTo(handle, quillonR)
	local finialL = makeBall(model, "QuillonFinialL", 0.15, CFrame.new(0, 0.60, 0.64), brassInlay, Enum.Material.Metal)
	weldTo(handle, finialL)
	local finialR = makeBall(model, "QuillonFinialR", 0.15, CFrame.new(0, 0.60, -0.64), brassInlay, Enum.Material.Metal)
	weldTo(handle, finialR)

	local ricasso = makePart(model, "Ricasso", Vector3.new(0.44, 0.45, 0.075), CFrame.new(0, 0.82, 0), darkSteel, Enum.Material.Metal)
	weldTo(handle, ricasso)
	local fuller = makePart(model, "BladeFuller", Vector3.new(0.16, 2.60, 0.065), CFrame.new(0, 2.30, 0), darkSteel, Enum.Material.Metal)
	weldTo(handle, fuller)
	local edgeFwd = makePart(model, "BladeEdgeFwd", Vector3.new(0.18, 2.50, 0.045), CFrame.new(0.15, 2.30, 0), temperedEdge, Enum.Material.Metal)
	weldTo(handle, edgeFwd)
	local edgeBack = makePart(model, "BladeEdgeBack", Vector3.new(0.18, 2.50, 0.045), CFrame.new(-0.15, 2.30, 0), temperedEdge, Enum.Material.Metal)
	weldTo(handle, edgeBack)

	local tipFwd = makeWedge(model, "TipFwd", Vector3.new(0.045, 0.50, 0.24), CFrame.new(0.12, 3.80, 0) * CFrame.Angles(0, math.rad(-90), 0), temperedEdge, Enum.Material.Metal)
	weldTo(handle, tipFwd)
	local tipBack = makeWedge(model, "TipBack", Vector3.new(0.045, 0.50, 0.24), CFrame.new(-0.12, 3.80, 0) * CFrame.Angles(0, math.rad(90), 0), temperedEdge, Enum.Material.Metal)
	weldTo(handle, tipBack)

	addSocket(handle, "Grip", Vector3.new(0, 0, 0), Vector3.new(0, -90, 0))
	addSocket(handle, "Tip", Vector3.new(0, 4.05, 0), Vector3.new(0, 0, 0))
	addSocket(handle, "VfxTip", Vector3.new(0, 4.05, 0))
	addSocket(handle, "VfxBase", Vector3.new(0, 0.75, 0))
	addSocket(handle, "VfxCore", Vector3.new(0, 0.52, 0))

	local shieldModel = Instance.new("Model")
	shieldModel.Name = "OffhandShield"
	shieldModel.Parent = model

	local shieldHandle = makePart(shieldModel, "HandleS", Vector3.new(0.20, 0.60, 0.20), CFrame.new(0, 0, 0), gripCord)
	shieldModel.PrimaryPart = shieldHandle

	local bucklerPlate = makePart(shieldModel, "BucklerPlate", Vector3.new(0.20, 1.80, 1.80), CFrame.new(-0.28, 0, 0), darkSteel, Enum.Material.Metal)
	weldTo(shieldHandle, bucklerPlate)
	local rimTop = makePart(shieldModel, "BucklerRimTop", Vector3.new(0.24, 0.22, 1.70), CFrame.new(-0.30, 0.90, 0), rimPlate, Enum.Material.Metal)
	weldTo(shieldHandle, rimTop)
	local rimBottom = makePart(shieldModel, "BucklerRimBottom", Vector3.new(0.24, 0.22, 1.70), CFrame.new(-0.30, -0.90, 0), rimPlate, Enum.Material.Metal)
	weldTo(shieldHandle, rimBottom)
	local rimLeft = makePart(shieldModel, "BucklerRimLeft", Vector3.new(0.24, 1.70, 0.22), CFrame.new(-0.30, 0, 0.90), rimPlate, Enum.Material.Metal)
	weldTo(shieldHandle, rimLeft)
	local rimRight = makePart(shieldModel, "BucklerRimRight", Vector3.new(0.24, 1.70, 0.22), CFrame.new(-0.30, 0, -0.90), rimPlate, Enum.Material.Metal)
	weldTo(shieldHandle, rimRight)

	local bossDome = makePart(shieldModel, "BossDome", Vector3.new(0.28, 0.72, 0.72), CFrame.new(-0.36, 0, 0), temperedEdge, Enum.Material.Metal)
	weldTo(shieldHandle, bossDome)
	local bossPoint = makePart(shieldModel, "BossPoint", Vector3.new(0.34, 0.32, 0.32), CFrame.new(-0.44, 0, 0), brassInlay, Enum.Material.Metal)
	weldTo(shieldHandle, bossPoint)

	local stud1 = makePart(shieldModel, "Stud1", Vector3.new(0.26, 0.16, 0.16), CFrame.new(-0.32, 0.60, 0.60), brassInlay, Enum.Material.Metal)
	weldTo(shieldHandle, stud1)
	local stud2 = makePart(shieldModel, "Stud2", Vector3.new(0.26, 0.16, 0.16), CFrame.new(-0.32, -0.60, 0.60), brassInlay, Enum.Material.Metal)
	weldTo(shieldHandle, stud2)
	local stud3 = makePart(shieldModel, "Stud3", Vector3.new(0.26, 0.16, 0.16), CFrame.new(-0.32, 0.60, -0.60), brassInlay, Enum.Material.Metal)
	weldTo(shieldHandle, stud3)
	local stud4 = makePart(shieldModel, "Stud4", Vector3.new(0.26, 0.16, 0.16), CFrame.new(-0.32, -0.60, -0.60), brassInlay, Enum.Material.Metal)
	weldTo(shieldHandle, stud4)

	local armBrace = makePart(shieldModel, "ArmBrace", Vector3.new(0.18, 0.50, 0.22), CFrame.new(-0.16, 0, 0), darkSteel, Enum.Material.Metal)
	weldTo(shieldHandle, armBrace)
	local strapTop = makePart(shieldModel, "StrapTop", Vector3.new(0.14, 0.14, 0.38), CFrame.new(-0.10, 0.22, 0), gripCord)
	weldTo(shieldHandle, strapTop)
	local strapBot = makePart(shieldModel, "StrapBot", Vector3.new(0.14, 0.14, 0.38), CFrame.new(-0.10, -0.22, 0), gripCord)
	weldTo(shieldHandle, strapBot)

	addSocket(shieldHandle, "ShieldMount", Vector3.new(-0.18, 0, 0), Vector3.new(0, 90, 0))
	addSocket(shieldHandle, "VfxShieldCenter", Vector3.new(-0.46, 0.10, 0))

	return model
end


function WeaponModelBuilder.BuildRunicLongswordArtifact(): Model
	local model = Instance.new("Model")
	model.Name = "art_runic_longsword"

	local cobaltSteel = Color3.fromRGB(45, 68, 105)
	local runicSilver = Color3.fromRGB(205, 215, 230)
	local emeraldRune = Color3.fromRGB(45, 215, 125)
	local goldBanding = Color3.fromRGB(215, 175, 65)
	local darkGrip = Color3.fromRGB(35, 42, 55)

	

-- Sword Assembly (20 parts: runic longsword with flowing emerald fuller and cobalt steel crossguard)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.20, 1.05, 0.20)
	handle.CFrame = CFrame.new(0, 0, 0)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = model
	model.PrimaryPart = handle

	local gripCyl = makeCylinder(model, "GripCylinder", 0.98, 0.18, CFrame.new(0, 0, 0), darkGrip)
	weldTo(handle, gripCyl)
	local gripWrap1 = makeCylinder(model, "GripWrap1", 0.12, 0.20, CFrame.new(0, -0.25, 0), goldBanding, Enum.Material.Metal)
	weldTo(handle, gripWrap1)
	local gripWrap2 = makeCylinder(model, "GripWrap2", 0.12, 0.20, CFrame.new(0, 0.25, 0), goldBanding, Enum.Material.Metal)
	weldTo(handle, gripWrap2)

	local pommelNeck = makeCylinder(model, "PommelNeck", 0.10, 0.22, CFrame.new(0, -0.56, 0), cobaltSteel, Enum.Material.Metal)
	weldTo(handle, pommelNeck)
	local pommelBall = makeBall(model, "PommelBall", 0.34, CFrame.new(0, -0.72, 0), cobaltSteel, Enum.Material.Metal)
	weldTo(handle, pommelBall)
	local pommelGem = makeBall(model, "PommelGem", 0.16, CFrame.new(0, -0.90, 0), emeraldRune, Enum.Material.Neon)
	weldTo(handle, pommelGem)

	local guardCenter = makePart(model, "GuardCenter", Vector3.new(0.30, 0.22, 0.24), CFrame.new(0, 0.56, 0), cobaltSteel, Enum.Material.Metal)
	weldTo(handle, guardCenter)
	local guardEcusson = makePart(model, "GuardEcusson", Vector3.new(0.24, 0.28, 0.10), CFrame.new(0, 0.58, 0.10), emeraldRune, Enum.Material.Neon)
	weldTo(handle, guardEcusson)
	local quillonL = makePart(model, "QuillonL", Vector3.new(0.18, 0.12, 0.48), CFrame.new(0, 0.58, 0.40) * CFrame.Angles(math.rad(8), 0, 0), cobaltSteel, Enum.Material.Metal)
	weldTo(handle, quillonL)
	local quillonR = makePart(model, "QuillonR", Vector3.new(0.18, 0.12, 0.48), CFrame.new(0, 0.58, -0.40) * CFrame.Angles(math.rad(-8), 0, 0), cobaltSteel, Enum.Material.Metal)
	weldTo(handle, quillonR)
	local finialL = makeBall(model, "QuillonFinialL", 0.16, CFrame.new(0, 0.65, 0.66), goldBanding, Enum.Material.Metal)
	weldTo(handle, finialL)
	local finialR = makeBall(model, "QuillonFinialR", 0.16, CFrame.new(0, 0.65, -0.66), goldBanding, Enum.Material.Metal)
	weldTo(handle, finialR)

	local ricasso = makePart(model, "Ricasso", Vector3.new(0.46, 0.50, 0.075), CFrame.new(0, 0.88, 0), cobaltSteel, Enum.Material.Metal)
	weldTo(handle, ricasso)
	local fuller = makePart(model, "BladeFuller", Vector3.new(0.16, 2.90, 0.065), CFrame.new(0, 2.50, 0), runicSilver, Enum.Material.Metal)
	weldTo(handle, fuller)
	local runeChannel = makePart(model, "RuneChannel", Vector3.new(0.06, 2.40, 0.075), CFrame.new(0, 2.45, 0), emeraldRune, Enum.Material.Neon)
	weldTo(handle, runeChannel)
	local edgeFwd = makePart(model, "BladeEdgeFwd", Vector3.new(0.18, 2.80, 0.045), CFrame.new(0.16, 2.50, 0), runicSilver, Enum.Material.Metal)
	weldTo(handle, edgeFwd)
	local edgeBack = makePart(model, "BladeEdgeBack", Vector3.new(0.18, 2.80, 0.045), CFrame.new(-0.16, 2.50, 0), runicSilver, Enum.Material.Metal)
	weldTo(handle, edgeBack)

	local tipFwd = makeWedge(model, "TipFwd", Vector3.new(0.045, 0.52, 0.25), CFrame.new(0.12, 4.18, 0) * CFrame.Angles(0, math.rad(-90), 0), runicSilver, Enum.Material.Metal)
	weldTo(handle, tipFwd)
	local tipBack = makeWedge(model, "TipBack", Vector3.new(0.045, 0.52, 0.25), CFrame.new(-0.12, 4.18, 0) * CFrame.Angles(0, math.rad(90), 0), runicSilver, Enum.Material.Metal)
	weldTo(handle, tipBack)
	local tipSpine = makePart(model, "TipSpine", Vector3.new(0.045, 0.52, 0.045), CFrame.new(0, 4.18, 0), cobaltSteel, Enum.Material.Metal)
	weldTo(handle, tipSpine)

	addSocket(handle, "Grip", Vector3.new(0, 0, 0), Vector3.new(0, -90, 0))
	addSocket(handle, "Tip", Vector3.new(0, 4.45, 0), Vector3.new(0, 0, 0))
	addSocket(handle, "VfxTip", Vector3.new(0, 4.45, 0))
	addSocket(handle, "VfxBase", Vector3.new(0, 0.80, 0))
	addSocket(handle, "VfxCore", Vector3.new(0, 0.56, 0))

	local shieldModel = Instance.new("Model")
	shieldModel.Name = "OffhandShield"
	shieldModel.Parent = model

	local shieldHandle = makePart(shieldModel, "HandleS", Vector3.new(0.20, 0.60, 0.20), CFrame.new(0, 0, 0), darkGrip)
	shieldModel.PrimaryPart = shieldHandle

	local paviseMain = makePart(shieldModel, "PaviseMain", Vector3.new(0.20, 2.60, 1.40), CFrame.new(-0.30, 0, 0), cobaltSteel, Enum.Material.Metal)
	weldTo(shieldHandle, paviseMain)
	local paviseTopAngle = makePart(shieldModel, "PaviseTopAngle", Vector3.new(0.20, 0.45, 1.25), CFrame.new(-0.30, 1.48, 0), cobaltSteel, Enum.Material.Metal)
	weldTo(shieldHandle, paviseTopAngle)
	local paviseBottomSpike = makePart(shieldModel, "PaviseBottomSpike", Vector3.new(0.20, 0.55, 0.90), CFrame.new(-0.30, -1.52, 0), cobaltSteel, Enum.Material.Metal)
	weldTo(shieldHandle, paviseBottomSpike)

	local rimGoldTop = makePart(shieldModel, "RimGoldTop", Vector3.new(0.24, 0.16, 1.35), CFrame.new(-0.32, 1.70, 0), goldBanding, Enum.Material.Metal)
	weldTo(shieldHandle, rimGoldTop)
	local rimGoldL = makePart(shieldModel, "RimGoldL", Vector3.new(0.24, 3.10, 0.14), CFrame.new(-0.32, 0, 0.72), goldBanding, Enum.Material.Metal)
	weldTo(shieldHandle, rimGoldL)
	local rimGoldR = makePart(shieldModel, "RimGoldR", Vector3.new(0.24, 3.10, 0.14), CFrame.new(-0.32, 0, -0.72), goldBanding, Enum.Material.Metal)
	weldTo(shieldHandle, rimGoldR)

	local spineRidge = makePart(shieldModel, "SpineRidge", Vector3.new(0.26, 2.80, 0.24), CFrame.new(-0.36, 0, 0), runicSilver, Enum.Material.Metal)
	weldTo(shieldHandle, spineRidge)
	local runeGemCenter = makePart(shieldModel, "RuneGemCenter", Vector3.new(0.32, 0.40, 0.40), CFrame.new(-0.40, 0.20, 0), emeraldRune, Enum.Material.Neon)
	weldTo(shieldHandle, runeGemCenter)
	local runeRays1 = makePart(shieldModel, "RuneRays1", Vector3.new(0.28, 0.80, 0.10), CFrame.new(-0.38, 0.75, 0), emeraldRune, Enum.Material.SmoothPlastic)
	weldTo(shieldHandle, runeRays1)
	local runeRays2 = makePart(shieldModel, "RuneRays2", Vector3.new(0.28, 0.80, 0.10), CFrame.new(-0.38, -0.35, 0), emeraldRune, Enum.Material.SmoothPlastic)
	weldTo(shieldHandle, runeRays2)

	local cornerTrimTL = makePart(shieldModel, "CornerTrimTL", Vector3.new(0.22, 0.35, 0.35), CFrame.new(-0.32, 1.25, 0.50), runicSilver, Enum.Material.Metal)
	weldTo(shieldHandle, cornerTrimTL)
	local cornerTrimTR = makePart(shieldModel, "CornerTrimTR", Vector3.new(0.22, 0.35, 0.35), CFrame.new(-0.32, 1.25, -0.50), runicSilver, Enum.Material.Metal)
	weldTo(shieldHandle, cornerTrimTR)
	local cornerTrimBL = makePart(shieldModel, "CornerTrimBL", Vector3.new(0.22, 0.35, 0.35), CFrame.new(-0.32, -1.15, 0.40), runicSilver, Enum.Material.Metal)
	weldTo(shieldHandle, cornerTrimBL)
	local cornerTrimBR = makePart(shieldModel, "CornerTrimBR", Vector3.new(0.22, 0.35, 0.35), CFrame.new(-0.32, -1.15, -0.40), runicSilver, Enum.Material.Metal)
	weldTo(shieldHandle, cornerTrimBR)

	local armMount = makePart(shieldModel, "ArmMount", Vector3.new(0.18, 0.55, 0.24), CFrame.new(-0.16, 0, 0), cobaltSteel, Enum.Material.Metal)
	weldTo(shieldHandle, armMount)
	local armStrap = makePart(shieldModel, "ArmStrap", Vector3.new(0.14, 0.28, 0.44), CFrame.new(-0.10, 0, 0), darkGrip)
	weldTo(shieldHandle, armStrap)

	addSocket(shieldHandle, "ShieldMount", Vector3.new(-0.18, 0, 0), Vector3.new(0, 90, 0))
	addSocket(shieldHandle, "VfxShieldCenter", Vector3.new(-0.42, 0.10, 0))

	return model
end


function WeaponModelBuilder.BuildKnightlyEstoc(): Model
	local model = Instance.new("Model")
	model.Name = "art_knightly_estoc"

	local polishedChrome = Color3.fromRGB(225, 230, 240)
	local bluedSteel = Color3.fromRGB(52, 70, 95)
	local brassGilt = Color3.fromRGB(215, 178, 75)
	local velvetNavy = Color3.fromRGB(25, 35, 55)

	

-- Sword Assembly (23 parts: slender knightly estoc with swept ring guard and needle-point blade)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.20, 1.10, 0.20)
	handle.CFrame = CFrame.new(0, 0, 0)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = model
	model.PrimaryPart = handle

	local gripCyl = makeCylinder(model, "GripCylinder", 1.00, 0.17, CFrame.new(0, 0, 0), velvetNavy)
	weldTo(handle, gripCyl)
	local gripWrap1 = makeCylinder(model, "GripWrap1", 0.10, 0.19, CFrame.new(0, -0.30, 0), brassGilt, Enum.Material.Metal)
	weldTo(handle, gripWrap1)
	local gripWrap2 = makeCylinder(model, "GripWrap2", 0.10, 0.19, CFrame.new(0, 0.30, 0), brassGilt, Enum.Material.Metal)
	weldTo(handle, gripWrap2)

	local pommelNeck = makeCylinder(model, "PommelNeck", 0.10, 0.20, CFrame.new(0, -0.58, 0), polishedChrome, Enum.Material.Metal)
	weldTo(handle, pommelNeck)
	local pommelBall = makeBall(model, "PommelBall", 0.32, CFrame.new(0, -0.74, 0), brassGilt, Enum.Material.Metal)
	weldTo(handle, pommelBall)
	local pommelFinial = makeBall(model, "PommelFinial", 0.14, CFrame.new(0, -0.92, 0), bluedSteel, Enum.Material.Metal)
	weldTo(handle, pommelFinial)

	local guardCenter = makePart(model, "GuardCenter", Vector3.new(0.26, 0.18, 0.22), CFrame.new(0, 0.58, 0), polishedChrome, Enum.Material.Metal)
	weldTo(handle, guardCenter)
	local guardEcusson = makePart(model, "GuardEcusson", Vector3.new(0.20, 0.24, 0.10), CFrame.new(0, 0.60, 0.10), brassGilt, Enum.Material.Metal)
	weldTo(handle, guardEcusson)
	local quillonL = makePart(model, "QuillonL", Vector3.new(0.16, 0.10, 0.44), CFrame.new(0, 0.60, 0.36) * CFrame.Angles(math.rad(10), 0, 0), bluedSteel, Enum.Material.Metal)
	weldTo(handle, quillonL)
	local quillonR = makePart(model, "QuillonR", Vector3.new(0.16, 0.10, 0.44), CFrame.new(0, 0.60, -0.36) * CFrame.Angles(math.rad(-10), 0, 0), bluedSteel, Enum.Material.Metal)
	weldTo(handle, quillonR)
	local finialL = makeBall(model, "QuillonFinialL", 0.15, CFrame.new(0, 0.68, 0.60), brassGilt, Enum.Material.Metal)
	weldTo(handle, finialL)
	local finialR = makeBall(model, "QuillonFinialR", 0.15, CFrame.new(0, 0.68, -0.60), brassGilt, Enum.Material.Metal)
	weldTo(handle, finialR)

	local ringGuardL = makeCylinder(model, "RingGuardL", 0.12, 0.36, CFrame.new(0.08, 0.68, 0.20), polishedChrome, Enum.Material.Metal)
	weldTo(handle, ringGuardL)
	local ringGuardR = makeCylinder(model, "RingGuardR", 0.12, 0.36, CFrame.new(0.08, 0.68, -0.20), polishedChrome, Enum.Material.Metal)
	weldTo(handle, ringGuardR)

	local ricasso = makePart(model, "Ricasso", Vector3.new(0.38, 0.55, 0.07), CFrame.new(0, 0.92, 0), bluedSteel, Enum.Material.Metal)
	weldTo(handle, ricasso)
	local estocSpine = makePart(model, "EstocSpine", Vector3.new(0.14, 3.20, 0.065), CFrame.new(0, 2.75, 0), bluedSteel, Enum.Material.Metal)
	weldTo(handle, estocSpine)
	local edgeFwd = makePart(model, "BladeEdgeFwd", Vector3.new(0.14, 3.10, 0.045), CFrame.new(0.13, 2.75, 0), polishedChrome, Enum.Material.Metal)
	weldTo(handle, edgeFwd)
	local edgeBack = makePart(model, "BladeEdgeBack", Vector3.new(0.14, 3.10, 0.045), CFrame.new(-0.13, 2.75, 0), polishedChrome, Enum.Material.Metal)
	weldTo(handle, edgeBack)

	local tipMidFwd = makeWedge(model, "TipMidFwd", Vector3.new(0.045, 0.40, 0.18), CFrame.new(0.09, 4.45, 0) * CFrame.Angles(0, math.rad(-90), 0), polishedChrome, Enum.Material.Metal)
	weldTo(handle, tipMidFwd)
	local tipMidBack = makeWedge(model, "TipMidBack", Vector3.new(0.045, 0.40, 0.18), CFrame.new(-0.09, 4.45, 0) * CFrame.Angles(0, math.rad(90), 0), polishedChrome, Enum.Material.Metal)
	weldTo(handle, tipMidBack)
	local tipApexFwd = makeWedge(model, "TipApexFwd", Vector3.new(0.040, 0.40, 0.10), CFrame.new(0.05, 4.80, 0) * CFrame.Angles(0, math.rad(-90), 0), polishedChrome, Enum.Material.Metal)
	weldTo(handle, tipApexFwd)
	local tipApexBack = makeWedge(model, "TipApexBack", Vector3.new(0.040, 0.40, 0.10), CFrame.new(-0.05, 4.80, 0) * CFrame.Angles(0, math.rad(90), 0), polishedChrome, Enum.Material.Metal)
	weldTo(handle, tipApexBack)
	local tipSpur = makePart(model, "TipSpur", Vector3.new(0.04, 0.40, 0.04), CFrame.new(0, 4.80, 0), brassGilt, Enum.Material.Metal)
	weldTo(handle, tipSpur)

	addSocket(handle, "Grip", Vector3.new(0, 0, 0), Vector3.new(0, -90, 0))
	addSocket(handle, "Tip", Vector3.new(0, 5.00, 0), Vector3.new(0, 0, 0))
	addSocket(handle, "VfxTip", Vector3.new(0, 5.00, 0))
	addSocket(handle, "VfxBase", Vector3.new(0, 0.85, 0))
	addSocket(handle, "VfxCore", Vector3.new(0, 0.58, 0))

	local shieldModel = Instance.new("Model")
	shieldModel.Name = "OffhandShield"
	shieldModel.Parent = model

	local shieldHandle = makePart(shieldModel, "HandleS", Vector3.new(0.20, 0.60, 0.20), CFrame.new(0, 0, 0), velvetNavy)
	shieldModel.PrimaryPart = shieldHandle

	local kiteDome = makePart(shieldModel, "KiteDome", Vector3.new(0.22, 1.20, 1.40), CFrame.new(-0.32, 0.85, 0), bluedSteel, Enum.Material.Metal)
	weldTo(shieldHandle, kiteDome)
	local kiteMid = makePart(shieldModel, "KiteMid", Vector3.new(0.20, 1.20, 1.25), CFrame.new(-0.32, -0.30, 0), bluedSteel, Enum.Material.Metal)
	weldTo(shieldHandle, kiteMid)
	local kiteTaper = makePart(shieldModel, "KiteTaper", Vector3.new(0.18, 1.00, 0.85), CFrame.new(-0.32, -1.35, 0), bluedSteel, Enum.Material.Metal)
	weldTo(shieldHandle, kiteTaper)
	local kitePoint = makePart(shieldModel, "KitePoint", Vector3.new(0.16, 0.45, 0.40), CFrame.new(-0.32, -2.05, 0), brassGilt, Enum.Material.Metal)
	weldTo(shieldHandle, kitePoint)

	local rimCurvedTop = makePart(shieldModel, "RimCurvedTop", Vector3.new(0.26, 0.16, 1.45), CFrame.new(-0.34, 1.48, 0), brassGilt, Enum.Material.Metal)
	weldTo(shieldHandle, rimCurvedTop)
	local rimL1 = makePart(shieldModel, "RimL1", Vector3.new(0.24, 1.60, 0.14), CFrame.new(-0.34, 0.70, 0.72), polishedChrome, Enum.Material.Metal)
	weldTo(shieldHandle, rimL1)
	local rimR1 = makePart(shieldModel, "RimR1", Vector3.new(0.24, 1.60, 0.14), CFrame.new(-0.34, 0.70, -0.72), polishedChrome, Enum.Material.Metal)
	weldTo(shieldHandle, rimR1)
	local rimL2 = makePart(shieldModel, "RimL2", Vector3.new(0.22, 1.80, 0.14), CFrame.new(-0.34, -0.90, 0.52), polishedChrome, Enum.Material.Metal)
	weldTo(shieldHandle, rimL2)
	local rimR2 = makePart(shieldModel, "RimR2", Vector3.new(0.22, 1.80, 0.14), CFrame.new(-0.34, -0.90, -0.52), polishedChrome, Enum.Material.Metal)
	weldTo(shieldHandle, rimR2)

	local heraldicCrossV = makePart(shieldModel, "HeraldicCrossV", Vector3.new(0.26, 2.40, 0.22), CFrame.new(-0.36, 0.20, 0), brassGilt, Enum.Material.Metal)
	weldTo(shieldHandle, heraldicCrossV)
	local heraldicCrossH = makePart(shieldModel, "HeraldicCrossH", Vector3.new(0.26, 0.22, 1.00), CFrame.new(-0.36, 0.75, 0), brassGilt, Enum.Material.Metal)
	weldTo(shieldHandle, heraldicCrossH)
	local centerMedallion = makePart(shieldModel, "CenterMedallion", Vector3.new(0.32, 0.44, 0.44), CFrame.new(-0.40, 0.75, 0), polishedChrome, Enum.Material.Metal)
	weldTo(shieldHandle, centerMedallion)

	local fleurL = makePart(shieldModel, "FleurL", Vector3.new(0.28, 0.22, 0.22), CFrame.new(-0.36, 0.25, 0.35), brassGilt, Enum.Material.Metal)
	weldTo(shieldHandle, fleurL)
	local fleurR = makePart(shieldModel, "FleurR", Vector3.new(0.28, 0.22, 0.22), CFrame.new(-0.36, 0.25, -0.35), brassGilt, Enum.Material.Metal)
	weldTo(shieldHandle, fleurR)

	local armPad = makePart(shieldModel, "ArmPad", Vector3.new(0.18, 0.70, 0.30), CFrame.new(-0.16, 0, 0), velvetNavy)
	weldTo(shieldHandle, armPad)
	local strap1 = makePart(shieldModel, "Strap1", Vector3.new(0.12, 0.12, 0.42), CFrame.new(-0.10, 0.25, 0), bluedSteel, Enum.Material.Metal)
	weldTo(shieldHandle, strap1)
	local strap2 = makePart(shieldModel, "Strap2", Vector3.new(0.12, 0.12, 0.42), CFrame.new(-0.10, -0.25, 0), bluedSteel, Enum.Material.Metal)
	weldTo(shieldHandle, strap2)

	addSocket(shieldHandle, "ShieldMount", Vector3.new(-0.18, 0, 0), Vector3.new(0, 90, 0))
	addSocket(shieldHandle, "VfxShieldCenter", Vector3.new(-0.42, 0.10, 0))

	return model
end


function WeaponModelBuilder.BuildPaladinSpatha(): Model
	local model = Instance.new("Model")
	model.Name = "art_paladin_spatha"

	local holySteel = Color3.fromRGB(220, 226, 238)
	local radiantGold = Color3.fromRGB(235, 192, 65)
	local royalBlue = Color3.fromRGB(35, 55, 95)
	local sunGem = Color3.fromRGB(255, 230, 110)
	local whiteLeather = Color3.fromRGB(230, 230, 235)

	

-- Sword Assembly (22 parts: holy leaf-bladed spatha with radiant gold winged quillons)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.20, 1.10, 0.20)
	handle.CFrame = CFrame.new(0, 0, 0)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = model
	model.PrimaryPart = handle

	local gripCyl = makeCylinder(model, "GripCylinder", 1.00, 0.18, CFrame.new(0, 0, 0), whiteLeather)
	weldTo(handle, gripCyl)
	local gripWrap1 = makeCylinder(model, "GripWrap1", 0.12, 0.20, CFrame.new(0, -0.28, 0), radiantGold, Enum.Material.Metal)
	weldTo(handle, gripWrap1)
	local gripWrap2 = makeCylinder(model, "GripWrap2", 0.12, 0.20, CFrame.new(0, 0.28, 0), radiantGold, Enum.Material.Metal)
	weldTo(handle, gripWrap2)

	local pommelNeck = makeCylinder(model, "PommelNeck", 0.10, 0.22, CFrame.new(0, -0.58, 0), radiantGold, Enum.Material.Metal)
	weldTo(handle, pommelNeck)
	local pommelBall = makeBall(model, "PommelBall", 0.36, CFrame.new(0, -0.76, 0), radiantGold, Enum.Material.Metal)
	weldTo(handle, pommelBall)
	local pommelCross = makePart(model, "PommelCross", Vector3.new(0.24, 0.24, 0.08), CFrame.new(0, -0.96, 0), sunGem, Enum.Material.Neon)
	weldTo(handle, pommelCross)

	local guardCenter = makePart(model, "GuardCenter", Vector3.new(0.32, 0.22, 0.24), CFrame.new(0, 0.58, 0), radiantGold, Enum.Material.Metal)
	weldTo(handle, guardCenter)
	local guardWingL = makePart(model, "GuardWingL", Vector3.new(0.18, 0.14, 0.46), CFrame.new(0, 0.60, 0.38) * CFrame.Angles(math.rad(12), 0, 0), radiantGold, Enum.Material.Metal)
	weldTo(handle, guardWingL)
	local guardWingR = makePart(model, "GuardWingR", Vector3.new(0.18, 0.14, 0.46), CFrame.new(0, 0.60, -0.38) * CFrame.Angles(math.rad(-12), 0, 0), radiantGold, Enum.Material.Metal)
	weldTo(handle, guardWingR)
	local finialL = makeBall(model, "QuillonFinialL", 0.18, CFrame.new(0, 0.70, 0.64), radiantGold, Enum.Material.Metal)
	weldTo(handle, finialL)
	local finialR = makeBall(model, "QuillonFinialR", 0.18, CFrame.new(0, 0.70, -0.64), radiantGold, Enum.Material.Metal)
	weldTo(handle, finialR)

	local ricasso = makePart(model, "Ricasso", Vector3.new(0.44, 0.50, 0.075), CFrame.new(0, 0.90, 0), radiantGold, Enum.Material.Metal)
	weldTo(handle, ricasso)
	local leafSwellFwd = makePart(model, "LeafSwellFwd", Vector3.new(0.24, 2.00, 0.05), CFrame.new(0.18, 2.15, 0), holySteel, Enum.Material.Metal)
	weldTo(handle, leafSwellFwd)
	local leafSwellBack = makePart(model, "LeafSwellBack", Vector3.new(0.24, 2.00, 0.05), CFrame.new(-0.18, 2.15, 0), holySteel, Enum.Material.Metal)
	weldTo(handle, leafSwellBack)
	local bladeFuller = makePart(model, "BladeFuller", Vector3.new(0.16, 3.10, 0.065), CFrame.new(0, 2.70, 0), holySteel, Enum.Material.Metal)
	weldTo(handle, bladeFuller)
	local holyInlay = makePart(model, "HolyInlay", Vector3.new(0.06, 2.60, 0.075), CFrame.new(0, 2.60, 0), sunGem, Enum.Material.Neon)
	weldTo(handle, holyInlay)
	local edgeUpperFwd = makePart(model, "EdgeUpperFwd", Vector3.new(0.18, 1.20, 0.045), CFrame.new(0.14, 3.65, 0), holySteel, Enum.Material.Metal)
	weldTo(handle, edgeUpperFwd)
	local edgeUpperBack = makePart(model, "EdgeUpperBack", Vector3.new(0.18, 1.20, 0.045), CFrame.new(-0.14, 3.65, 0), holySteel, Enum.Material.Metal)
	weldTo(handle, edgeUpperBack)

	local tipFwd = makeWedge(model, "TipFwd", Vector3.new(0.045, 0.56, 0.26), CFrame.new(0.13, 4.45, 0) * CFrame.Angles(0, math.rad(-90), 0), holySteel, Enum.Material.Metal)
	weldTo(handle, tipFwd)
	local tipBack = makeWedge(model, "TipBack", Vector3.new(0.045, 0.56, 0.26), CFrame.new(-0.13, 4.45, 0) * CFrame.Angles(0, math.rad(90), 0), holySteel, Enum.Material.Metal)
	weldTo(handle, tipBack)

	addSocket(handle, "Grip", Vector3.new(0, 0, 0), Vector3.new(0, -90, 0))
	addSocket(handle, "Tip", Vector3.new(0, 4.75, 0), Vector3.new(0, 0, 0))
	addSocket(handle, "VfxTip", Vector3.new(0, 4.75, 0))
	addSocket(handle, "VfxBase", Vector3.new(0, 0.85, 0))
	addSocket(handle, "VfxCore", Vector3.new(0, 0.60, 0))

	local shieldModel = Instance.new("Model")
	shieldModel.Name = "OffhandShield"
	shieldModel.Parent = model

	local shieldHandle = makePart(shieldModel, "HandleS", Vector3.new(0.20, 0.60, 0.20), CFrame.new(0, 0, 0), royalBlue)
	shieldModel.PrimaryPart = shieldHandle

	local heaterBase = makePart(shieldModel, "HeaterBase", Vector3.new(0.22, 1.40, 1.40), CFrame.new(-0.32, 0.70, 0), royalBlue, Enum.Material.Metal)
	weldTo(shieldHandle, heaterBase)
	local heaterMid = makePart(shieldModel, "HeaterMid", Vector3.new(0.20, 1.20, 1.25), CFrame.new(-0.32, -0.45, 0), royalBlue, Enum.Material.Metal)
	weldTo(shieldHandle, heaterMid)
	local heaterPoint = makePart(shieldModel, "HeaterPoint", Vector3.new(0.18, 0.85, 0.80), CFrame.new(-0.32, -1.35, 0), royalBlue, Enum.Material.Metal)
	weldTo(shieldHandle, heaterPoint)
	local heaterTip = makePart(shieldModel, "HeaterTip", Vector3.new(0.16, 0.40, 0.35), CFrame.new(-0.32, -1.90, 0), radiantGold, Enum.Material.Metal)
	weldTo(shieldHandle, heaterTip)

	-- Trim
	local rimTopGold = makePart(shieldModel, "RimTopGold", Vector3.new(0.26, 0.18, 1.48), CFrame.new(-0.34, 1.40, 0), radiantGold, Enum.Material.Metal)
	weldTo(shieldHandle, rimTopGold)
	local rimL1 = makePart(shieldModel, "RimL1", Vector3.new(0.24, 1.40, 0.16), CFrame.new(-0.34, 0.65, 0.72), radiantGold, Enum.Material.Metal)
	weldTo(shieldHandle, rimL1)
	local rimR1 = makePart(shieldModel, "RimR1", Vector3.new(0.24, 1.40, 0.16), CFrame.new(-0.34, 0.65, -0.72), radiantGold, Enum.Material.Metal)
	weldTo(shieldHandle, rimR1)
	local rimL2 = makePart(shieldModel, "RimL2", Vector3.new(0.22, 1.60, 0.14), CFrame.new(-0.34, -0.75, 0.54), holySteel, Enum.Material.Metal)
	weldTo(shieldHandle, rimL2)
	local rimR2 = makePart(shieldModel, "RimR2", Vector3.new(0.22, 1.60, 0.14), CFrame.new(-0.34, -0.75, -0.54), holySteel, Enum.Material.Metal)
	weldTo(shieldHandle, rimR2)

	-- Radiant Sunburst Crest
	local sunCenterDisc = makePart(shieldModel, "SunCenterDisc", Vector3.new(0.30, 0.80, 0.80), CFrame.new(-0.38, 0.40, 0), radiantGold, Enum.Material.Metal)
	weldTo(shieldHandle, sunCenterDisc)
	local sunCoreFlame = makePart(shieldModel, "SunCoreFlame", Vector3.new(0.36, 0.38, 0.38), CFrame.new(-0.44, 0.20, 0), sunGem, Enum.Material.Neon)
	weldTo(shieldHandle, sunCoreFlame)

	local sunRayUp = makePart(shieldModel, "SunRayUp", Vector3.new(0.28, 0.55, 0.16), CFrame.new(-0.38, 0.95, 0), radiantGold, Enum.Material.Metal)
	weldTo(shieldHandle, sunRayUp)
	local sunRayDown = makePart(shieldModel, "SunRayDown", Vector3.new(0.28, 0.55, 0.16), CFrame.new(-0.38, -0.15, 0), radiantGold, Enum.Material.Metal)
	weldTo(shieldHandle, sunRayDown)
	local sunRayLeft = makePart(shieldModel, "SunRayLeft", Vector3.new(0.28, 0.16, 0.55), CFrame.new(-0.38, 0.40, 0.55), radiantGold, Enum.Material.Metal)
	weldTo(shieldHandle, sunRayLeft)
	local sunRayRight = makePart(shieldModel, "SunRayRight", Vector3.new(0.28, 0.16, 0.55), CFrame.new(-0.38, 0.40, -0.55), radiantGold, Enum.Material.Metal)
	weldTo(shieldHandle, sunRayRight)
	local sunRayTL = makePart(shieldModel, "SunRayTL", Vector3.new(0.26, 0.40, 0.40), CFrame.new(-0.38, 0.80, 0.40), radiantGold, Enum.Material.Metal)
	weldTo(shieldHandle, sunRayTL)
	local sunRayTR = makePart(shieldModel, "SunRayTR", Vector3.new(0.26, 0.40, 0.40), CFrame.new(-0.38, 0.80, -0.40), radiantGold, Enum.Material.Metal)
	weldTo(shieldHandle, sunRayTR)

	local chevronLower = makePart(shieldModel, "ChevronLower", Vector3.new(0.24, 0.60, 0.60), CFrame.new(-0.36, -0.85, 0), radiantGold, Enum.Material.Metal)
	weldTo(shieldHandle, chevronLower)

	local armPad = makePart(shieldModel, "ArmPad", Vector3.new(0.18, 0.75, 0.32), CFrame.new(-0.16, 0, 0), royalBlue)
	weldTo(shieldHandle, armPad)
	local strapTop = makePart(shieldModel, "StrapTop", Vector3.new(0.14, 0.14, 0.44), CFrame.new(-0.10, 0.28, 0), whiteLeather)
	weldTo(shieldHandle, strapTop)
	local strapBot = makePart(shieldModel, "StrapBot", Vector3.new(0.14, 0.14, 0.44), CFrame.new(-0.10, -0.28, 0), whiteLeather)
	weldTo(shieldHandle, strapBot)

	addSocket(shieldHandle, "ShieldMount", Vector3.new(-0.18, 0, 0), Vector3.new(0, 90, 0))
	addSocket(shieldHandle, "VfxShieldCenter", Vector3.new(-0.46, 0.10, 0))

	return model
end


function WeaponModelBuilder.BuildVanguardWardenBastion(): Model
	local model = Instance.new("Model")
	model.Name = "art_vanguard_warden_bastion"

	local gunmetalGrey = Color3.fromRGB(68, 72, 82)
	local hardenedSteel = Color3.fromRGB(165, 172, 185)
	local electricCyan = Color3.fromRGB(60, 215, 255)
	local bronzeReinforce = Color3.fromRGB(165, 115, 55)
	local heavyGrip = Color3.fromRGB(35, 38, 45)

	

-- Sword Assembly (24 parts: heavy fortress warden broadsword with storm-etched fuller)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.20, 1.15, 0.20)
	handle.CFrame = CFrame.new(0, 0, 0)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = model
	model.PrimaryPart = handle

	local gripCyl = makeCylinder(model, "GripCylinder", 1.05, 0.19, CFrame.new(0, 0, 0), heavyGrip)
	weldTo(handle, gripCyl)
	local gripWrap1 = makeCylinder(model, "GripWrap1", 0.12, 0.21, CFrame.new(0, -0.30, 0), bronzeReinforce, Enum.Material.Metal)
	weldTo(handle, gripWrap1)
	local gripWrap2 = makeCylinder(model, "GripWrap2", 0.12, 0.21, CFrame.new(0, 0.30, 0), bronzeReinforce, Enum.Material.Metal)
	weldTo(handle, gripWrap2)

	local pommelNeck = makeCylinder(model, "PommelNeck", 0.10, 0.24, CFrame.new(0, -0.60, 0), gunmetalGrey, Enum.Material.Metal)
	weldTo(handle, pommelNeck)
	local pommelBall = makeBall(model, "PommelBall", 0.38, CFrame.new(0, -0.78, 0), gunmetalGrey, Enum.Material.Metal)
	weldTo(handle, pommelBall)
	local pommelFinial = makeBall(model, "PommelFinial", 0.16, CFrame.new(0, -0.98, 0), bronzeReinforce, Enum.Material.Metal)
	weldTo(handle, pommelFinial)

	local guardCenter = makePart(model, "GuardCenter", Vector3.new(0.34, 0.24, 0.26), CFrame.new(0, 0.60, 0), gunmetalGrey, Enum.Material.Metal)
	weldTo(handle, guardCenter)
	local guardPlate = makePart(model, "GuardPlate", Vector3.new(0.26, 0.30, 0.10), CFrame.new(0, 0.62, 0.12), bronzeReinforce, Enum.Material.Metal)
	weldTo(handle, guardPlate)
	local quillonL = makePart(model, "QuillonL", Vector3.new(0.20, 0.14, 0.50), CFrame.new(0, 0.62, 0.40) * CFrame.Angles(math.rad(8), 0, 0), gunmetalGrey, Enum.Material.Metal)
	weldTo(handle, quillonL)
	local quillonR = makePart(model, "QuillonR", Vector3.new(0.20, 0.14, 0.50), CFrame.new(0, 0.62, -0.40) * CFrame.Angles(math.rad(-8), 0, 0), gunmetalGrey, Enum.Material.Metal)
	weldTo(handle, quillonR)
	local finialL = makeBall(model, "QuillonFinialL", 0.18, CFrame.new(0, 0.70, 0.68), bronzeReinforce, Enum.Material.Metal)
	weldTo(handle, finialL)
	local finialR = makeBall(model, "QuillonFinialR", 0.18, CFrame.new(0, 0.70, -0.68), bronzeReinforce, Enum.Material.Metal)
	weldTo(handle, finialR)

	local ricasso = makePart(model, "Ricasso", Vector3.new(0.48, 0.55, 0.08), CFrame.new(0, 0.95, 0), gunmetalGrey, Enum.Material.Metal)
	weldTo(handle, ricasso)
	local ricassoSpurL = makePart(model, "RicassoSpurL", Vector3.new(0.12, 0.20, 0.07), CFrame.new(0.28, 1.15, 0), bronzeReinforce, Enum.Material.Metal)
	weldTo(handle, ricassoSpurL)
	local ricassoSpurR = makePart(model, "RicassoSpurR", Vector3.new(0.12, 0.20, 0.07), CFrame.new(-0.28, 1.15, 0), bronzeReinforce, Enum.Material.Metal)
	weldTo(handle, ricassoSpurR)

	local bladeFuller = makePart(model, "BladeFuller", Vector3.new(0.18, 3.20, 0.07), CFrame.new(0, 2.80, 0), hardenedSteel, Enum.Material.Metal)
	weldTo(handle, bladeFuller)
	local fullerInlay = makePart(model, "FullerInlay", Vector3.new(0.06, 2.70, 0.08), CFrame.new(0, 2.75, 0), electricCyan, Enum.Material.Neon)
	weldTo(handle, fullerInlay)
	local edgeFwd = makePart(model, "BladeEdgeFwd", Vector3.new(0.20, 3.10, 0.045), CFrame.new(0.18, 2.80, 0), hardenedSteel, Enum.Material.Metal)
	weldTo(handle, edgeFwd)
	local edgeBack = makePart(model, "BladeEdgeBack", Vector3.new(0.20, 3.10, 0.045), CFrame.new(-0.18, 2.80, 0), hardenedSteel, Enum.Material.Metal)
	weldTo(handle, edgeBack)

	local tipFwd = makeWedge(model, "TipFwd", Vector3.new(0.045, 0.58, 0.28), CFrame.new(0.14, 4.65, 0) * CFrame.Angles(0, math.rad(-90), 0), hardenedSteel, Enum.Material.Metal)
	weldTo(handle, tipFwd)
	local tipBack = makeWedge(model, "TipBack", Vector3.new(0.045, 0.58, 0.28), CFrame.new(-0.14, 4.65, 0) * CFrame.Angles(0, math.rad(90), 0), hardenedSteel, Enum.Material.Metal)
	weldTo(handle, tipBack)
	local tipSpine = makePart(model, "TipSpine", Vector3.new(0.045, 0.58, 0.045), CFrame.new(0, 4.65, 0), gunmetalGrey, Enum.Material.Metal)
	weldTo(handle, tipSpine)

	addSocket(handle, "Grip", Vector3.new(0, 0, 0), Vector3.new(0, -90, 0))
	addSocket(handle, "Tip", Vector3.new(0, 4.95, 0), Vector3.new(0, 0, 0))
	addSocket(handle, "VfxTip", Vector3.new(0, 4.95, 0))
	addSocket(handle, "VfxBase", Vector3.new(0, 0.90, 0))
	addSocket(handle, "VfxCore", Vector3.new(0, 0.62, 0))

	local shieldModel = Instance.new("Model")
	shieldModel.Name = "OffhandShield"
	shieldModel.Parent = model

	local shieldHandle = makePart(shieldModel, "HandleS", Vector3.new(0.22, 0.65, 0.22), CFrame.new(0, 0, 0), heavyGrip)
	shieldModel.PrimaryPart = shieldHandle

	local bastionBody = makePart(shieldModel, "BastionBody", Vector3.new(0.24, 2.80, 1.60), CFrame.new(-0.34, 0, 0), gunmetalGrey, Enum.Material.Metal)
	weldTo(shieldHandle, bastionBody)
	local scallopTop1 = makePart(shieldModel, "ScallopTop1", Vector3.new(0.26, 0.40, 0.60), CFrame.new(-0.34, 1.55, 0.50), gunmetalGrey, Enum.Material.Metal)
	weldTo(shieldHandle, scallopTop1)
	local scallopTop2 = makePart(shieldModel, "ScallopTop2", Vector3.new(0.26, 0.40, 0.60), CFrame.new(-0.34, 1.55, -0.50), gunmetalGrey, Enum.Material.Metal)
	weldTo(shieldHandle, scallopTop2)
	local scallopCenter = makePart(shieldModel, "ScallopCenter", Vector3.new(0.26, 0.55, 0.40), CFrame.new(-0.34, 1.62, 0), bronzeReinforce, Enum.Material.Metal)
	weldTo(shieldHandle, scallopCenter)
	local scallopBot = makePart(shieldModel, "ScallopBot", Vector3.new(0.24, 0.50, 1.20), CFrame.new(-0.34, -1.60, 0), gunmetalGrey, Enum.Material.Metal)
	weldTo(shieldHandle, scallopBot)

	-- Heavy Armor Plates
	local plateUpper = makePart(shieldModel, "PlateUpper", Vector3.new(0.28, 0.90, 1.40), CFrame.new(-0.38, 0.70, 0), hardenedSteel, Enum.Material.Metal)
	weldTo(shieldHandle, plateUpper)
	local plateLower = makePart(shieldModel, "PlateLower", Vector3.new(0.28, 0.90, 1.30), CFrame.new(-0.38, -0.70, 0), hardenedSteel, Enum.Material.Metal)
	weldTo(shieldHandle, plateLower)

	local rimL = makePart(shieldModel, "RimL", Vector3.new(0.28, 3.40, 0.16), CFrame.new(-0.36, 0, 0.82), bronzeReinforce, Enum.Material.Metal)
	weldTo(shieldHandle, rimL)
	local rimR = makePart(shieldModel, "RimR", Vector3.new(0.28, 3.40, 0.16), CFrame.new(-0.36, 0, -0.82), bronzeReinforce, Enum.Material.Metal)
	weldTo(shieldHandle, rimR)

	local centerBossPillar = makePart(shieldModel, "CenterBossPillar", Vector3.new(0.32, 2.20, 0.32), CFrame.new(-0.42, 0, 0), bronzeReinforce, Enum.Material.Metal)
	weldTo(shieldHandle, centerBossPillar)
	local coreBeacon = makePart(shieldModel, "CoreBeacon", Vector3.new(0.38, 0.38, 0.38), CFrame.new(-0.46, 0.15, 0), electricCyan, Enum.Material.Neon)
	weldTo(shieldHandle, coreBeacon)
	local cornerPlateTL = makePart(shieldModel, "CornerPlateTL", Vector3.new(0.26, 0.40, 0.40), CFrame.new(-0.36, 1.30, 0.70), bronzeReinforce, Enum.Material.Metal)
	weldTo(shieldHandle, cornerPlateTL)
	local cornerPlateTR = makePart(shieldModel, "CornerPlateTR", Vector3.new(0.26, 0.40, 0.40), CFrame.new(-0.36, 1.30, -0.70), bronzeReinforce, Enum.Material.Metal)
	weldTo(shieldHandle, cornerPlateTR)
	local cornerPlateBL = makePart(shieldModel, "CornerPlateBL", Vector3.new(0.26, 0.40, 0.40), CFrame.new(-0.36, -1.30, 0.60), bronzeReinforce, Enum.Material.Metal)
	weldTo(shieldHandle, cornerPlateBL)
	local cornerPlateBR = makePart(shieldModel, "CornerPlateBR", Vector3.new(0.26, 0.40, 0.40), CFrame.new(-0.36, -1.30, -0.60), bronzeReinforce, Enum.Material.Metal)
	weldTo(shieldHandle, cornerPlateBR)

	-- Fortress Rivets & Slits
	local slitL = makePart(shieldModel, "SlitL", Vector3.new(0.30, 0.60, 0.10), CFrame.new(-0.39, 0.80, 0.40), electricCyan, Enum.Material.SmoothPlastic)
	weldTo(shieldHandle, slitL)
	local slitR = makePart(shieldModel, "SlitR", Vector3.new(0.30, 0.60, 0.10), CFrame.new(-0.39, 0.80, -0.40), electricCyan, Enum.Material.SmoothPlastic)
	weldTo(shieldHandle, slitR)
	local rivet1 = makePart(shieldModel, "Rivet1", Vector3.new(0.30, 0.18, 0.18), CFrame.new(-0.40, 1.20, 0.60), bronzeReinforce, Enum.Material.Metal)
	weldTo(shieldHandle, rivet1)
	local rivet2 = makePart(shieldModel, "Rivet2", Vector3.new(0.30, 0.18, 0.18), CFrame.new(-0.40, 1.20, -0.60), bronzeReinforce, Enum.Material.Metal)
	weldTo(shieldHandle, rivet2)
	local rivet3 = makePart(shieldModel, "Rivet3", Vector3.new(0.30, 0.18, 0.18), CFrame.new(-0.40, -1.20, 0.50), bronzeReinforce, Enum.Material.Metal)
	weldTo(shieldHandle, rivet3)
	local rivet4 = makePart(shieldModel, "Rivet4", Vector3.new(0.30, 0.18, 0.18), CFrame.new(-0.40, -1.20, -0.50), bronzeReinforce, Enum.Material.Metal)
	weldTo(shieldHandle, rivet4)

	local armFrame = makePart(shieldModel, "ArmFrame", Vector3.new(0.20, 0.90, 0.36), CFrame.new(-0.16, 0, 0), gunmetalGrey, Enum.Material.Metal)
	weldTo(shieldHandle, armFrame)
	local strap1 = makePart(shieldModel, "Strap1", Vector3.new(0.14, 0.16, 0.48), CFrame.new(-0.10, 0.30, 0), heavyGrip)
	weldTo(shieldHandle, strap1)
	local strap2 = makePart(shieldModel, "Strap2", Vector3.new(0.14, 0.16, 0.48), CFrame.new(-0.10, -0.30, 0), heavyGrip)
	weldTo(shieldHandle, strap2)

	addSocket(shieldHandle, "ShieldMount", Vector3.new(-0.18, 0, 0), Vector3.new(0, 90, 0))
	addSocket(shieldHandle, "VfxShieldCenter", Vector3.new(-0.48, 0.10, 0))

	return model
end


function WeaponModelBuilder.BuildCrystalClaymore(): Model
	local model = Instance.new("Model")
	model.Name = "art_crystal_claymore"

	local quartzPurple = Color3.fromRGB(175, 95, 235)
	local quartzGlow = Color3.fromRGB(215, 145, 255)
	local titaniumGold = Color3.fromRGB(235, 205, 115)
	local darkObsidian = Color3.fromRGB(42, 38, 48)
	local crystalClear = Color3.fromRGB(145, 220, 255)

	

-- Sword Assembly (28 parts: prismatic crystalline anime claymore with faceted glass edge shards)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.20, 1.25, 0.20)
	handle.CFrame = CFrame.new(0, 0, 0)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = model
	model.PrimaryPart = handle

	local gripCyl = makeCylinder(model, "GripCylinder", 1.15, 0.18, CFrame.new(0, 0, 0), darkObsidian)
	weldTo(handle, gripCyl)
	local gripWrap1 = makeCylinder(model, "GripWrap1", 0.12, 0.20, CFrame.new(0, -0.32, 0), titaniumGold, Enum.Material.Metal)
	weldTo(handle, gripWrap1)
	local gripWrap2 = makeCylinder(model, "GripWrap2", 0.12, 0.20, CFrame.new(0, 0.32, 0), titaniumGold, Enum.Material.Metal)
	weldTo(handle, gripWrap2)

	local pommelNeck = makeCylinder(model, "PommelNeck", 0.10, 0.22, CFrame.new(0, -0.64, 0), titaniumGold, Enum.Material.Metal)
	weldTo(handle, pommelNeck)
	local pommelBall = makeBall(model, "PommelBall", 0.36, CFrame.new(0, -0.82, 0), titaniumGold, Enum.Material.Metal)
	weldTo(handle, pommelBall)
	local pommelGem = makeBall(model, "PommelGem", 0.18, CFrame.new(0, -1.02, 0), quartzGlow, Enum.Material.Neon)
	weldTo(handle, pommelGem)

	local guardCenter = makePart(model, "GuardCenter", Vector3.new(0.36, 0.22, 0.26), CFrame.new(0, 0.64, 0), titaniumGold, Enum.Material.Metal)
	weldTo(handle, guardCenter)
	local guardPrismL = makePart(model, "GuardPrismL", Vector3.new(0.18, 0.24, 0.12), CFrame.new(0, 0.66, 0.20), crystalClear, Enum.Material.Glass)
	guardPrismL.Transparency = 0.25
	weldTo(handle, guardPrismL)
	local guardPrismR = makePart(model, "GuardPrismR", Vector3.new(0.18, 0.24, 0.12), CFrame.new(0, 0.66, -0.20), crystalClear, Enum.Material.Glass)
	guardPrismR.Transparency = 0.25
	weldTo(handle, guardPrismR)

	local quillonL = makePart(model, "QuillonL", Vector3.new(0.20, 0.14, 0.54), CFrame.new(0, 0.66, 0.44) * CFrame.Angles(math.rad(10), 0, 0), titaniumGold, Enum.Material.Metal)
	weldTo(handle, quillonL)
	local quillonR = makePart(model, "QuillonR", Vector3.new(0.20, 0.14, 0.54), CFrame.new(0, 0.66, -0.44) * CFrame.Angles(math.rad(-10), 0, 0), titaniumGold, Enum.Material.Metal)
	weldTo(handle, quillonR)
	local finialL = makeBall(model, "QuillonFinialL", 0.18, CFrame.new(0, 0.76, 0.74), quartzPurple, Enum.Material.Glass)
	weldTo(handle, finialL)
	local finialR = makeBall(model, "QuillonFinialR", 0.18, CFrame.new(0, 0.76, -0.74), quartzPurple, Enum.Material.Glass)
	weldTo(handle, finialR)

	local ricasso = makePart(model, "Ricasso", Vector3.new(0.48, 0.60, 0.08), CFrame.new(0, 1.02, 0), titaniumGold, Enum.Material.Metal)
	weldTo(handle, ricasso)
	local shardBaseL = makePart(model, "ShardBaseL", Vector3.new(0.14, 0.35, 0.07), CFrame.new(0.28, 1.25, 0), crystalClear, Enum.Material.Glass)
	shardBaseL.Transparency = 0.25
	weldTo(handle, shardBaseL)
	local shardBaseR = makePart(model, "ShardBaseR", Vector3.new(0.14, 0.35, 0.07), CFrame.new(-0.28, 1.25, 0), crystalClear, Enum.Material.Glass)
	shardBaseR.Transparency = 0.25
	weldTo(handle, shardBaseR)

	local bladeFuller = makePart(model, "BladeFuller", Vector3.new(0.16, 3.40, 0.07), CFrame.new(0, 2.95, 0), quartzPurple, Enum.Material.Metal)
	weldTo(handle, bladeFuller)
	local crystalCore = makePart(model, "CrystalCore", Vector3.new(0.06, 2.90, 0.075), CFrame.new(0, 2.90, 0), quartzGlow, Enum.Material.Neon)
	weldTo(handle, crystalCore)

	local edgeFwd1 = makePart(model, "EdgeFwd1", Vector3.new(0.22, 1.70, 0.045), CFrame.new(0.18, 2.15, 0), crystalClear, Enum.Material.Glass)
	edgeFwd1.Transparency = 0.25
	weldTo(handle, edgeFwd1)
	local edgeFwd2 = makePart(model, "EdgeFwd2", Vector3.new(0.20, 1.65, 0.045), CFrame.new(0.17, 3.80, 0), crystalClear, Enum.Material.Glass)
	edgeFwd2.Transparency = 0.25
	weldTo(handle, edgeFwd2)
	local edgeBack1 = makePart(model, "EdgeBack1", Vector3.new(0.22, 1.70, 0.045), CFrame.new(-0.18, 2.15, 0), crystalClear, Enum.Material.Glass)
	edgeBack1.Transparency = 0.25
	weldTo(handle, edgeBack1)
	local edgeBack2 = makePart(model, "EdgeBack2", Vector3.new(0.20, 1.65, 0.045), CFrame.new(-0.17, 3.80, 0), crystalClear, Enum.Material.Glass)
	edgeBack2.Transparency = 0.25
	weldTo(handle, edgeBack2)

	local tipFlangeL = makePart(model, "TipFlangeL", Vector3.new(0.08, 0.35, 0.05), CFrame.new(0.20, 4.55, 0), titaniumGold, Enum.Material.Metal)
	weldTo(handle, tipFlangeL)
	local tipFlangeR = makePart(model, "TipFlangeR", Vector3.new(0.08, 0.35, 0.05), CFrame.new(-0.20, 4.55, 0), titaniumGold, Enum.Material.Metal)
	weldTo(handle, tipFlangeR)

	local tipFwd = makeWedge(model, "TipFwd", Vector3.new(0.045, 0.60, 0.26), CFrame.new(0.13, 4.90, 0) * CFrame.Angles(0, math.rad(-90), 0), crystalClear, Enum.Material.Glass)
	tipFwd.Transparency = 0.25
	weldTo(handle, tipFwd)
	local tipBack = makeWedge(model, "TipBack", Vector3.new(0.045, 0.60, 0.26), CFrame.new(-0.13, 4.90, 0) * CFrame.Angles(0, math.rad(90), 0), crystalClear, Enum.Material.Glass)
	tipBack.Transparency = 0.25
	weldTo(handle, tipBack)

	addSocket(handle, "Grip", Vector3.new(0, 0, 0), Vector3.new(0, -90, 0))
	addSocket(handle, "Tip", Vector3.new(0, 5.20, 0), Vector3.new(0, 0, 0))
	addSocket(handle, "VfxTip", Vector3.new(0, 5.20, 0))
	addSocket(handle, "VfxBase", Vector3.new(0, 0.95, 0))
	addSocket(handle, "VfxCore", Vector3.new(0, 0.66, 0))

	local shieldModel = Instance.new("Model")
	shieldModel.Name = "OffhandShield"
	shieldModel.Parent = model

	local shieldHandle = makePart(shieldModel, "HandleS", Vector3.new(0.20, 0.60, 0.20), CFrame.new(0, 0, 0), darkObsidian)
	shieldModel.PrimaryPart = shieldHandle

	local centralHexPlate = makePart(shieldModel, "CentralHexPlate", Vector3.new(0.24, 1.40, 1.40), CFrame.new(-0.34, 0.20, 0), quartzPurple, Enum.Material.Glass)
	weldTo(shieldHandle, centralHexPlate)
	local hexUpper = makePart(shieldModel, "HexUpper", Vector3.new(0.22, 1.00, 1.00), CFrame.new(-0.34, 1.20, 0), quartzPurple, Enum.Material.Glass)
	weldTo(shieldHandle, hexUpper)
	local hexLower = makePart(shieldModel, "HexLower", Vector3.new(0.22, 1.00, 1.00), CFrame.new(-0.34, -0.80, 0), quartzPurple, Enum.Material.Glass)
	weldTo(shieldHandle, hexLower)
	local hexLeft = makePart(shieldModel, "HexLeft", Vector3.new(0.22, 1.00, 0.90), CFrame.new(-0.34, 0.20, 0.95), quartzPurple, Enum.Material.Glass)
	weldTo(shieldHandle, hexLeft)
	local hexRight = makePart(shieldModel, "HexRight", Vector3.new(0.22, 1.00, 0.90), CFrame.new(-0.34, 0.20, -0.95), quartzPurple, Enum.Material.Glass)
	weldTo(shieldHandle, hexRight)

	-- Titanium Gold Frame Lattice
	local frameTop = makePart(shieldModel, "FrameTop", Vector3.new(0.28, 0.18, 1.20), CFrame.new(-0.36, 1.70, 0), titaniumGold, Enum.Material.Metal)
	weldTo(shieldHandle, frameTop)
	local frameBottom = makePart(shieldModel, "FrameBottom", Vector3.new(0.28, 0.18, 1.20), CFrame.new(-0.36, -1.30, 0), titaniumGold, Enum.Material.Metal)
	weldTo(shieldHandle, frameBottom)
	local frameL1 = makePart(shieldModel, "FrameL1", Vector3.new(0.26, 1.50, 0.16), CFrame.new(-0.36, 0.85, 0.95), titaniumGold, Enum.Material.Metal)
	weldTo(shieldHandle, frameL1)
	local frameR1 = makePart(shieldModel, "FrameR1", Vector3.new(0.26, 1.50, 0.16), CFrame.new(-0.36, 0.85, -0.95), titaniumGold, Enum.Material.Metal)
	weldTo(shieldHandle, frameR1)
	local frameL2 = makePart(shieldModel, "FrameL2", Vector3.new(0.26, 1.50, 0.16), CFrame.new(-0.36, -0.45, 0.95), titaniumGold, Enum.Material.Metal)
	weldTo(shieldHandle, frameL2)
	local frameR2 = makePart(shieldModel, "FrameR2", Vector3.new(0.26, 1.50, 0.16), CFrame.new(-0.36, -0.45, -0.95), titaniumGold, Enum.Material.Metal)
	weldTo(shieldHandle, frameR2)

	-- Prismatic Emitter Nodes
	local corePrism = makePart(shieldModel, "CorePrism", Vector3.new(0.36, 0.40, 0.40), CFrame.new(-0.42, 0.20, 0), quartzGlow, Enum.Material.Neon)
	weldTo(shieldHandle, corePrism)
	local prismNode1 = makePart(shieldModel, "PrismNode1", Vector3.new(0.28, 0.28, 0.28), CFrame.new(-0.38, 1.45, 0.65), crystalClear, Enum.Material.Glass)
	weldTo(shieldHandle, prismNode1)
	local prismNode2 = makePart(shieldModel, "PrismNode2", Vector3.new(0.28, 0.28, 0.28), CFrame.new(-0.38, 1.45, -0.65), crystalClear, Enum.Material.Glass)
	weldTo(shieldHandle, prismNode2)
	local prismNode3 = makePart(shieldModel, "PrismNode3", Vector3.new(0.28, 0.28, 0.28), CFrame.new(-0.38, -1.05, 0.65), crystalClear, Enum.Material.Glass)
	weldTo(shieldHandle, prismNode3)
	local prismNode4 = makePart(shieldModel, "PrismNode4", Vector3.new(0.28, 0.28, 0.28), CFrame.new(-0.38, -1.05, -0.65), crystalClear, Enum.Material.Glass)
	weldTo(shieldHandle, prismNode4)

	local floatingShard1 = makePart(shieldModel, "FloatingShard1", Vector3.new(0.24, 0.45, 0.22), CFrame.new(-0.38, 0.85, 0.55), quartzGlow, Enum.Material.Glass)
	floatingShard1.Transparency = 0.25
	weldTo(shieldHandle, floatingShard1)
	local floatingShard2 = makePart(shieldModel, "FloatingShard2", Vector3.new(0.24, 0.45, 0.22), CFrame.new(-0.38, 0.85, -0.55), quartzGlow, Enum.Material.Glass)
	floatingShard2.Transparency = 0.25
	weldTo(shieldHandle, floatingShard2)
	local floatingShard3 = makePart(shieldModel, "FloatingShard3", Vector3.new(0.24, 0.45, 0.22), CFrame.new(-0.38, -0.45, 0.55), quartzGlow, Enum.Material.Glass)
	floatingShard3.Transparency = 0.25
	weldTo(shieldHandle, floatingShard3)
	local floatingShard4 = makePart(shieldModel, "FloatingShard4", Vector3.new(0.24, 0.45, 0.22), CFrame.new(-0.38, -0.45, -0.55), quartzGlow, Enum.Material.Glass)
	floatingShard4.Transparency = 0.25
	weldTo(shieldHandle, floatingShard4)

	local crystalSpireTop = makePart(shieldModel, "CrystalSpireTop", Vector3.new(0.26, 0.50, 0.26), CFrame.new(-0.36, 1.95, 0), quartzGlow, Enum.Material.Glass)
	crystalSpireTop.Transparency = 0.25
	weldTo(shieldHandle, crystalSpireTop)
	local crystalSpireBot = makePart(shieldModel, "CrystalSpireBot", Vector3.new(0.26, 0.50, 0.26), CFrame.new(-0.36, -1.55, 0), quartzGlow, Enum.Material.Glass)
	crystalSpireBot.Transparency = 0.25
	weldTo(shieldHandle, crystalSpireBot)

	local mountBrace = makePart(shieldModel, "MountBrace", Vector3.new(0.18, 0.60, 0.28), CFrame.new(-0.16, 0.20, 0), titaniumGold, Enum.Material.Metal)
	weldTo(shieldHandle, mountBrace)
	local mountStrap1 = makePart(shieldModel, "MountStrap1", Vector3.new(0.12, 0.12, 0.42), CFrame.new(-0.10, 0.45, 0), darkObsidian)
	weldTo(shieldHandle, mountStrap1)
	local mountStrap2 = makePart(shieldModel, "MountStrap2", Vector3.new(0.12, 0.12, 0.42), CFrame.new(-0.10, -0.05, 0), darkObsidian)
	weldTo(shieldHandle, mountStrap2)

	addSocket(shieldHandle, "ShieldMount", Vector3.new(-0.18, 0, 0), Vector3.new(0, 90, 0))
	addSocket(shieldHandle, "VfxShieldCenter", Vector3.new(-0.45, 0.10, 0))

	return model
end


function WeaponModelBuilder.BuildResonantBulwark(): Model
	local model = Instance.new("Model")
	model.Name = "art_resonant_bulwark"

	local sonicSilver = Color3.fromRGB(230, 235, 245)
	local acousticBronze = Color3.fromRGB(195, 145, 75)
	local frequencyCyan = Color3.fromRGB(85, 235, 255)
	local dampenerGrey = Color3.fromRGB(55, 60, 70)
	local resonatorNeon = Color3.fromRGB(120, 255, 240)

	

-- Sword Assembly (30 parts: sonic resonant longsword with acoustic bronze quillons)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.20, 1.30, 0.20)
	handle.CFrame = CFrame.new(0, 0, 0)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = model
	model.PrimaryPart = handle

	local gripCyl = makeCylinder(model, "GripCylinder", 1.20, 0.18, CFrame.new(0, 0, 0), dampenerGrey)
	weldTo(handle, gripCyl)
	local gripWrap1 = makeCylinder(model, "GripWrap1", 0.12, 0.20, CFrame.new(0, -0.35, 0), acousticBronze, Enum.Material.Metal)
	weldTo(handle, gripWrap1)
	local gripWrap2 = makeCylinder(model, "GripWrap2", 0.12, 0.20, CFrame.new(0, 0.35, 0), acousticBronze, Enum.Material.Metal)
	weldTo(handle, gripWrap2)

	local pommelNeck = makeCylinder(model, "PommelNeck", 0.10, 0.22, CFrame.new(0, -0.66, 0), acousticBronze, Enum.Material.Metal)
	weldTo(handle, pommelNeck)
	local pommelBall = makeBall(model, "PommelBall", 0.38, CFrame.new(0, -0.84, 0), dampenerGrey, Enum.Material.Metal)
	weldTo(handle, pommelBall)
	local pommelFinial = makeBall(model, "PommelFinial", 0.16, CFrame.new(0, -1.04, 0), acousticBronze, Enum.Material.Metal)
	weldTo(handle, pommelFinial)

	local guardCenter = makePart(model, "GuardCenter", Vector3.new(0.38, 0.24, 0.26), CFrame.new(0, 0.66, 0), dampenerGrey, Enum.Material.Metal)
	weldTo(handle, guardCenter)
	local guardCrest = makePart(model, "GuardCrest", Vector3.new(0.28, 0.30, 0.10), CFrame.new(0, 0.68, 0.12), acousticBronze, Enum.Material.Metal)
	weldTo(handle, guardCrest)
	local quillonL = makePart(model, "QuillonL", Vector3.new(0.20, 0.14, 0.54), CFrame.new(0, 0.68, 0.44) * CFrame.Angles(math.rad(10), 0, 0), dampenerGrey, Enum.Material.Metal)
	weldTo(handle, quillonL)
	local quillonR = makePart(model, "QuillonR", Vector3.new(0.20, 0.14, 0.54), CFrame.new(0, 0.68, -0.44) * CFrame.Angles(math.rad(-10), 0, 0), dampenerGrey, Enum.Material.Metal)
	weldTo(handle, quillonR)
	local quillonWingL = makePart(model, "QuillonWingL", Vector3.new(0.12, 0.22, 0.20), CFrame.new(0, 0.74, 0.58), acousticBronze, Enum.Material.Metal)
	weldTo(handle, quillonWingL)
	local quillonWingR = makePart(model, "QuillonWingR", Vector3.new(0.12, 0.22, 0.20), CFrame.new(0, 0.74, -0.58), acousticBronze, Enum.Material.Metal)
	weldTo(handle, quillonWingR)
	local finialL = makeBall(model, "QuillonFinialL", 0.18, CFrame.new(0, 0.80, 0.76), acousticBronze, Enum.Material.Metal)
	weldTo(handle, finialL)
	local finialR = makeBall(model, "QuillonFinialR", 0.18, CFrame.new(0, 0.80, -0.76), acousticBronze, Enum.Material.Metal)
	weldTo(handle, finialR)

	local ricasso = makePart(model, "Ricasso", Vector3.new(0.50, 0.60, 0.08), CFrame.new(0, 1.05, 0), dampenerGrey, Enum.Material.Metal)
	weldTo(handle, ricasso)
	local ricassoWingL = makePart(model, "RicassoWingL", Vector3.new(0.14, 0.35, 0.07), CFrame.new(0.30, 1.25, 0), acousticBronze, Enum.Material.Metal)
	weldTo(handle, ricassoWingL)
	local ricassoWingR = makePart(model, "RicassoWingR", Vector3.new(0.14, 0.35, 0.07), CFrame.new(-0.30, 1.25, 0), acousticBronze, Enum.Material.Metal)
	weldTo(handle, ricassoWingR)

	local bladeFuller = makePart(model, "BladeFuller", Vector3.new(0.18, 3.60, 0.07), CFrame.new(0, 3.10, 0), sonicSilver, Enum.Material.Metal)
	weldTo(handle, bladeFuller)
	local resonanceCore = makePart(model, "ResonanceCore", Vector3.new(0.06, 3.10, 0.075), CFrame.new(0, 3.05, 0), frequencyCyan, Enum.Material.Neon)
	weldTo(handle, resonanceCore)

	local edgeFwd1 = makePart(model, "EdgeFwd1", Vector3.new(0.22, 1.80, 0.045), CFrame.new(0.19, 2.25, 0), sonicSilver, Enum.Material.Metal)
	weldTo(handle, edgeFwd1)
	local edgeFwd2 = makePart(model, "EdgeFwd2", Vector3.new(0.20, 1.75, 0.045), CFrame.new(0.18, 3.95, 0), sonicSilver, Enum.Material.Metal)
	weldTo(handle, edgeFwd2)
	local edgeBack1 = makePart(model, "EdgeBack1", Vector3.new(0.22, 1.80, 0.045), CFrame.new(-0.19, 2.25, 0), sonicSilver, Enum.Material.Metal)
	weldTo(handle, edgeBack1)
	local edgeBack2 = makePart(model, "EdgeBack2", Vector3.new(0.20, 1.75, 0.045), CFrame.new(-0.18, 3.95, 0), sonicSilver, Enum.Material.Metal)
	weldTo(handle, edgeBack2)

	local midBladeSpurL = makePart(model, "MidBladeSpurL", Vector3.new(0.10, 0.28, 0.05), CFrame.new(0.22, 4.60, 0), acousticBronze, Enum.Material.Metal)
	weldTo(handle, midBladeSpurL)
	local midBladeSpurR = makePart(model, "MidBladeSpurR", Vector3.new(0.10, 0.28, 0.05), CFrame.new(-0.22, 4.60, 0), acousticBronze, Enum.Material.Metal)
	weldTo(handle, midBladeSpurR)

	local tipFwd = makeWedge(model, "TipFwd", Vector3.new(0.045, 0.62, 0.28), CFrame.new(0.14, 5.05, 0) * CFrame.Angles(0, math.rad(-90), 0), sonicSilver, Enum.Material.Metal)
	weldTo(handle, tipFwd)
	local tipBack = makeWedge(model, "TipBack", Vector3.new(0.045, 0.62, 0.28), CFrame.new(-0.14, 5.05, 0) * CFrame.Angles(0, math.rad(90), 0), sonicSilver, Enum.Material.Metal)
	weldTo(handle, tipBack)

	addSocket(handle, "Grip", Vector3.new(0, 0, 0), Vector3.new(0, -90, 0))
	addSocket(handle, "Tip", Vector3.new(0, 5.35, 0), Vector3.new(0, 0, 0))
	addSocket(handle, "VfxTip", Vector3.new(0, 5.35, 0))
	addSocket(handle, "VfxBase", Vector3.new(0, 0.95, 0))
	addSocket(handle, "VfxCore", Vector3.new(0, 0.68, 0))

	local shieldModel = Instance.new("Model")
	shieldModel.Name = "OffhandShield"
	shieldModel.Parent = model

	local shieldHandle = makePart(shieldModel, "HandleS", Vector3.new(0.22, 0.60, 0.22), CFrame.new(0, 0, 0), dampenerGrey)
	shieldModel.PrimaryPart = shieldHandle

	-- Concentric Hexagonal Acoustic Diaphragms
	local centerDiaphragm = makePart(shieldModel, "CenterDiaphragm", Vector3.new(0.24, 1.50, 1.50), CFrame.new(-0.34, 0.15, 0), dampenerGrey, Enum.Material.Metal)
	weldTo(shieldHandle, centerDiaphragm)
	local outerPlateTop = makePart(shieldModel, "OuterPlateTop", Vector3.new(0.22, 0.70, 1.20), CFrame.new(-0.34, 1.15, 0), sonicSilver, Enum.Material.Metal)
	weldTo(shieldHandle, outerPlateTop)
	local outerPlateBot = makePart(shieldModel, "OuterPlateBot", Vector3.new(0.22, 0.70, 1.20), CFrame.new(-0.34, -0.85, 0), sonicSilver, Enum.Material.Metal)
	weldTo(shieldHandle, outerPlateBot)
	local outerPlateL = makePart(shieldModel, "OuterPlateL", Vector3.new(0.22, 1.20, 0.65), CFrame.new(-0.34, 0.15, 0.95), sonicSilver, Enum.Material.Metal)
	weldTo(shieldHandle, outerPlateL)
	local outerPlateR = makePart(shieldModel, "OuterPlateR", Vector3.new(0.22, 1.20, 0.65), CFrame.new(-0.34, 0.15, -0.95), sonicSilver, Enum.Material.Metal)
	weldTo(shieldHandle, outerPlateR)

	-- Acoustic Bronze Tuning Frames
	local bronzeRimTop = makePart(shieldModel, "BronzeRimTop", Vector3.new(0.28, 0.18, 1.30), CFrame.new(-0.36, 1.55, 0), acousticBronze, Enum.Material.Metal)
	weldTo(shieldHandle, bronzeRimTop)
	local bronzeRimBot = makePart(shieldModel, "BronzeRimBot", Vector3.new(0.28, 0.18, 1.30), CFrame.new(-0.36, -1.25, 0), acousticBronze, Enum.Material.Metal)
	weldTo(shieldHandle, bronzeRimBot)
	local bronzeRimTL = makePart(shieldModel, "BronzeRimTL", Vector3.new(0.26, 1.20, 0.18), CFrame.new(-0.36, 0.95, 0.85), acousticBronze, Enum.Material.Metal)
	weldTo(shieldHandle, bronzeRimTL)
	local bronzeRimTR = makePart(shieldModel, "BronzeRimTR", Vector3.new(0.26, 1.20, 0.18), CFrame.new(-0.36, 0.95, -0.85), acousticBronze, Enum.Material.Metal)
	weldTo(shieldHandle, bronzeRimTR)
	local bronzeRimBL = makePart(shieldModel, "BronzeRimBL", Vector3.new(0.26, 1.20, 0.18), CFrame.new(-0.36, -0.65, 0.85), acousticBronze, Enum.Material.Metal)
	weldTo(shieldHandle, bronzeRimBL)
	local bronzeRimBR = makePart(shieldModel, "BronzeRimBR", Vector3.new(0.26, 1.20, 0.18), CFrame.new(-0.36, -0.65, -0.85), acousticBronze, Enum.Material.Metal)
	weldTo(shieldHandle, bronzeRimBR)

	-- Central Resonant Acoustic Speaker / Emitter Boss
	local speakerHorn = makePart(shieldModel, "SpeakerHorn", Vector3.new(0.32, 0.80, 0.80), CFrame.new(-0.40, 0.15, 0), acousticBronze, Enum.Material.Metal)
	weldTo(shieldHandle, speakerHorn)
	local speakerCore = makePart(shieldModel, "SpeakerCore", Vector3.new(0.38, 0.38, 0.38), CFrame.new(-0.46, 0.15, 0), resonatorNeon, Enum.Material.Neon)
	weldTo(shieldHandle, speakerCore)
	local sonicWaveRing1 = makePart(shieldModel, "SonicWaveRing1", Vector3.new(0.30, 0.95, 0.95), CFrame.new(-0.38, 0.15, 0), frequencyCyan, Enum.Material.Glass)
	sonicWaveRing1.Transparency = 0.30
	weldTo(shieldHandle, sonicWaveRing1)

	-- 6 Acoustic Resonant Emitters around periphery
	local node1 = makePart(shieldModel, "Node1", Vector3.new(0.28, 0.22, 0.22), CFrame.new(-0.38, 1.35, 0), resonatorNeon, Enum.Material.Metal)
	weldTo(shieldHandle, node1)
	local node2 = makePart(shieldModel, "Node2", Vector3.new(0.28, 0.22, 0.22), CFrame.new(-0.38, -1.05, 0), resonatorNeon, Enum.Material.Metal)
	weldTo(shieldHandle, node2)
	local node3 = makePart(shieldModel, "Node3", Vector3.new(0.28, 0.22, 0.22), CFrame.new(-0.38, 0.75, 0.75), resonatorNeon, Enum.Material.Metal)
	weldTo(shieldHandle, node3)
	local node4 = makePart(shieldModel, "Node4", Vector3.new(0.28, 0.22, 0.22), CFrame.new(-0.38, 0.75, -0.75), resonatorNeon, Enum.Material.Metal)
	weldTo(shieldHandle, node4)
	local node5 = makePart(shieldModel, "Node5", Vector3.new(0.28, 0.22, 0.22), CFrame.new(-0.38, -0.45, 0.75), resonatorNeon, Enum.Material.Metal)
	weldTo(shieldHandle, node5)
	local node6 = makePart(shieldModel, "Node6", Vector3.new(0.28, 0.22, 0.22), CFrame.new(-0.38, -0.45, -0.75), resonatorNeon, Enum.Material.Metal)
	weldTo(shieldHandle, node6)

	-- Radial Shock Dampening Struts
	local strut1 = makePart(shieldModel, "Strut1", Vector3.new(0.26, 0.60, 0.14), CFrame.new(-0.37, 0.85, 0), sonicSilver, Enum.Material.Metal)
	weldTo(shieldHandle, strut1)
	local strut2 = makePart(shieldModel, "Strut2", Vector3.new(0.26, 0.60, 0.14), CFrame.new(-0.37, -0.55, 0), sonicSilver, Enum.Material.Metal)
	weldTo(shieldHandle, strut2)
	local strut3 = makePart(shieldModel, "Strut3", Vector3.new(0.26, 0.14, 0.60), CFrame.new(-0.37, 0.15, 0.55), sonicSilver, Enum.Material.Metal)
	weldTo(shieldHandle, strut3)
	local strut4 = makePart(shieldModel, "Strut4", Vector3.new(0.26, 0.14, 0.60), CFrame.new(-0.37, 0.15, -0.55), sonicSilver, Enum.Material.Metal)
	weldTo(shieldHandle, strut4)

	local armHarness = makePart(shieldModel, "ArmHarness", Vector3.new(0.20, 0.70, 0.32), CFrame.new(-0.16, 0.15, 0), dampenerGrey, Enum.Material.Metal)
	weldTo(shieldHandle, armHarness)
	local strapTop = makePart(shieldModel, "StrapTop", Vector3.new(0.14, 0.14, 0.44), CFrame.new(-0.10, 0.42, 0), dampenerGrey)
	weldTo(shieldHandle, strapTop)
	local strapBot = makePart(shieldModel, "StrapBot", Vector3.new(0.14, 0.14, 0.44), CFrame.new(-0.10, -0.12, 0), dampenerGrey)
	weldTo(shieldHandle, strapBot)

	addSocket(shieldHandle, "ShieldMount", Vector3.new(-0.18, 0, 0), Vector3.new(0, 90, 0))
	addSocket(shieldHandle, "VfxShieldCenter", Vector3.new(-0.48, 0.10, 0))

	return model
end


function WeaponModelBuilder.BuildPaladinClaymoreArtifact(): Model
	local model = Instance.new("Model")
	model.Name = "art_paladin_claymore"

	local holyPlatinum = Color3.fromRGB(240, 245, 255)
	local divineGold = Color3.fromRGB(245, 205, 75)
	local sunRadiance = Color3.fromRGB(255, 240, 145)
	local pureWhite = Color3.fromRGB(250, 250, 255)
	local sanctifiedSteel = Color3.fromRGB(180, 190, 210)

	-- Consecrated Executioner Claymore (34 parts)

-- Sword Assembly (32 parts: holy Zweihander with parrying lugs and divine gold quillons)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.20, 1.40, 0.20)
	handle.CFrame = CFrame.new(0, 0, 0)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = model
	model.PrimaryPart = handle

	local gripCyl = makeCylinder(model, "GripCylinder", 1.30, 0.18, CFrame.new(0, 0, 0), pureWhite)
	weldTo(handle, gripCyl)
	local gripWrap1 = makeCylinder(model, "GripWrap1", 0.12, 0.20, CFrame.new(0, -0.40, 0), divineGold, Enum.Material.Metal)
	weldTo(handle, gripWrap1)
	local gripWrap2 = makeCylinder(model, "GripWrap2", 0.12, 0.20, CFrame.new(0, 0.0, 0), divineGold, Enum.Material.Metal)
	weldTo(handle, gripWrap2)
	local gripWrap3 = makeCylinder(model, "GripWrap3", 0.12, 0.20, CFrame.new(0, 0.40, 0), divineGold, Enum.Material.Metal)
	weldTo(handle, gripWrap3)

	local pommelNeck = makeCylinder(model, "PommelNeck", 0.12, 0.24, CFrame.new(0, -0.72, 0), divineGold, Enum.Material.Metal)
	weldTo(handle, pommelNeck)
	local pommelBall = makeBall(model, "PommelBall", 0.40, CFrame.new(0, -0.92, 0), divineGold, Enum.Material.Metal)
	weldTo(handle, pommelBall)
	local pommelCross = makePart(model, "PommelCross", Vector3.new(0.26, 0.26, 0.08), CFrame.new(0, -1.16, 0), sunRadiance, Enum.Material.Neon)
	weldTo(handle, pommelCross)

	local guardCenter = makePart(model, "GuardCenter", Vector3.new(0.40, 0.24, 0.28), CFrame.new(0, 0.72, 0), divineGold, Enum.Material.Metal)
	weldTo(handle, guardCenter)
	local guardEcusson = makePart(model, "GuardEcusson", Vector3.new(0.30, 0.32, 0.10), CFrame.new(0, 0.74, 0.14), holyPlatinum, Enum.Material.Metal)
	weldTo(handle, guardEcusson)
	local quillonL = makePart(model, "QuillonL", Vector3.new(0.22, 0.16, 0.58), CFrame.new(0, 0.74, 0.48) * CFrame.Angles(math.rad(10), 0, 0), divineGold, Enum.Material.Metal)
	weldTo(handle, quillonL)
	local quillonR = makePart(model, "QuillonR", Vector3.new(0.22, 0.16, 0.58), CFrame.new(0, 0.74, -0.48) * CFrame.Angles(math.rad(-10), 0, 0), divineGold, Enum.Material.Metal)
	weldTo(handle, quillonR)
	local quillonWingL = makePart(model, "QuillonWingL", Vector3.new(0.14, 0.24, 0.24), CFrame.new(0, 0.82, 0.64), divineGold, Enum.Material.Metal)
	weldTo(handle, quillonWingL)
	local quillonWingR = makePart(model, "QuillonWingR", Vector3.new(0.14, 0.24, 0.24), CFrame.new(0, 0.82, -0.64), divineGold, Enum.Material.Metal)
	weldTo(handle, quillonWingR)
	local finialL = makeBall(model, "QuillonFinialL", 0.20, CFrame.new(0, 0.88, 0.82), divineGold, Enum.Material.Metal)
	weldTo(handle, finialL)
	local finialR = makeBall(model, "QuillonFinialR", 0.20, CFrame.new(0, 0.88, -0.82), divineGold, Enum.Material.Metal)
	weldTo(handle, finialR)

	local ricasso = makePart(model, "Ricasso", Vector3.new(0.52, 0.70, 0.08), CFrame.new(0, 1.15, 0), sanctifiedSteel, Enum.Material.Metal)
	weldTo(handle, ricasso)
	local parryingLugL = makePart(model, "ParryingLugL", Vector3.new(0.26, 0.18, 0.08), CFrame.new(0.38, 1.45, 0) * CFrame.Angles(0, 0, math.rad(-25)), divineGold, Enum.Material.Metal)
	weldTo(handle, parryingLugL)
	local parryingLugR = makePart(model, "ParryingLugR", Vector3.new(0.26, 0.18, 0.08), CFrame.new(-0.38, 1.45, 0) * CFrame.Angles(0, 0, math.rad(25)), divineGold, Enum.Material.Metal)
	weldTo(handle, parryingLugR)

	local fullerMain = makePart(model, "FullerMain", Vector3.new(0.18, 3.80, 0.07), CFrame.new(0, 3.40, 0), holyPlatinum, Enum.Material.Metal)
	weldTo(handle, fullerMain)
	local runeChannel = makePart(model, "RuneChannel", Vector3.new(0.06, 3.20, 0.075), CFrame.new(0, 3.35, 0), sunRadiance, Enum.Material.Neon)
	weldTo(handle, runeChannel)

	local edgeFwd1 = makePart(model, "EdgeFwd1", Vector3.new(0.22, 1.90, 0.045), CFrame.new(0.20, 2.45, 0), holyPlatinum, Enum.Material.Metal)
	weldTo(handle, edgeFwd1)
	local edgeFwd2 = makePart(model, "EdgeFwd2", Vector3.new(0.20, 1.85, 0.045), CFrame.new(0.19, 4.25, 0), holyPlatinum, Enum.Material.Metal)
	weldTo(handle, edgeFwd2)
	local edgeBack1 = makePart(model, "EdgeBack1", Vector3.new(0.22, 1.90, 0.045), CFrame.new(-0.20, 2.45, 0), holyPlatinum, Enum.Material.Metal)
	weldTo(handle, edgeBack1)
	local edgeBack2 = makePart(model, "EdgeBack2", Vector3.new(0.20, 1.85, 0.045), CFrame.new(-0.19, 4.25, 0), holyPlatinum, Enum.Material.Metal)
	weldTo(handle, edgeBack2)

	local midSpurL = makePart(model, "MidSpurL", Vector3.new(0.12, 0.32, 0.05), CFrame.new(0.24, 4.90, 0), divineGold, Enum.Material.Metal)
	weldTo(handle, midSpurL)
	local midSpurR = makePart(model, "MidSpurR", Vector3.new(0.12, 0.32, 0.05), CFrame.new(-0.24, 4.90, 0), divineGold, Enum.Material.Metal)
	weldTo(handle, midSpurR)

	local tipFwd = makeWedge(model, "TipFwd", Vector3.new(0.045, 0.65, 0.30), CFrame.new(0.15, 5.45, 0) * CFrame.Angles(0, math.rad(-90), 0), holyPlatinum, Enum.Material.Metal)
	weldTo(handle, tipFwd)
	local tipBack = makeWedge(model, "TipBack", Vector3.new(0.045, 0.65, 0.30), CFrame.new(-0.15, 5.45, 0) * CFrame.Angles(0, math.rad(90), 0), holyPlatinum, Enum.Material.Metal)
	weldTo(handle, tipBack)

	addSocket(handle, "Grip", Vector3.new(0, 0, 0), Vector3.new(0, -90, 0))
	addSocket(handle, "Tip", Vector3.new(0, 5.75, 0), Vector3.new(0, 0, 0))
	addSocket(handle, "VfxTip", Vector3.new(0, 5.75, 0))
	addSocket(handle, "VfxBase", Vector3.new(0, 1.00, 0))
	addSocket(handle, "VfxCore", Vector3.new(0, 0.72, 0))

	local shieldModel = Instance.new("Model")
	shieldModel.Name = "OffhandShield"
	shieldModel.Parent = model

	local shieldHandle = makePart(shieldModel, "HandleS", Vector3.new(0.22, 0.65, 0.22), CFrame.new(0, 0, 0), pureWhite)
	shieldModel.PrimaryPart = shieldHandle

	local kitePlateMain = makePart(shieldModel, "KitePlateMain", Vector3.new(0.22, 1.50, 1.45), CFrame.new(-0.34, 0.80, 0), holyPlatinum, Enum.Material.Metal)
	weldTo(shieldHandle, kitePlateMain)
	local kitePlateMid = makePart(shieldModel, "KitePlateMid", Vector3.new(0.20, 1.25, 1.30), CFrame.new(-0.34, -0.45, 0), holyPlatinum, Enum.Material.Metal)
	weldTo(shieldHandle, kitePlateMid)
	local kitePlateTaper = makePart(shieldModel, "KitePlateTaper", Vector3.new(0.18, 1.00, 0.90), CFrame.new(-0.34, -1.45, 0), holyPlatinum, Enum.Material.Metal)
	weldTo(shieldHandle, kitePlateTaper)
	local kitePlateSpike = makePart(shieldModel, "KitePlateSpike", Vector3.new(0.16, 0.50, 0.40), CFrame.new(-0.34, -2.15, 0), divineGold, Enum.Material.Metal)
	weldTo(shieldHandle, kitePlateSpike)

	-- Gold Trim Bevels
	local trimTop = makePart(shieldModel, "TrimTop", Vector3.new(0.28, 0.20, 1.55), CFrame.new(-0.36, 1.55, 0), divineGold, Enum.Material.Metal)
	weldTo(shieldHandle, trimTop)
	local trimL1 = makePart(shieldModel, "TrimL1", Vector3.new(0.26, 1.40, 0.16), CFrame.new(-0.36, 0.85, 0.78), divineGold, Enum.Material.Metal)
	weldTo(shieldHandle, trimL1)
	local trimR1 = makePart(shieldModel, "TrimR1", Vector3.new(0.26, 1.40, 0.16), CFrame.new(-0.36, 0.85, -0.78), divineGold, Enum.Material.Metal)
	weldTo(shieldHandle, trimR1)
	local trimL2 = makePart(shieldModel, "TrimL2", Vector3.new(0.24, 1.80, 0.16), CFrame.new(-0.36, -0.65, 0.58), divineGold, Enum.Material.Metal)
	weldTo(shieldHandle, trimL2)
	local trimR2 = makePart(shieldModel, "TrimR2", Vector3.new(0.24, 1.80, 0.16), CFrame.new(-0.36, -0.65, -0.58), divineGold, Enum.Material.Metal)
	weldTo(shieldHandle, trimR2)

	-- Golden Angelic Wings overlay on face
	local faceWingL1 = makePart(shieldModel, "FaceWingL1", Vector3.new(0.26, 0.80, 0.45), CFrame.new(-0.38, 0.85, 0.48), sanctifiedSteel, Enum.Material.Metal)
	weldTo(shieldHandle, faceWingL1)
	local faceWingR1 = makePart(shieldModel, "FaceWingR1", Vector3.new(0.26, 0.80, 0.45), CFrame.new(-0.38, 0.85, -0.48), sanctifiedSteel, Enum.Material.Metal)
	weldTo(shieldHandle, faceWingR1)
	local faceWingL2 = makePart(shieldModel, "FaceWingL2", Vector3.new(0.24, 0.60, 0.35), CFrame.new(-0.38, 0.25, 0.40), divineGold, Enum.Material.Metal)
	weldTo(shieldHandle, faceWingL2)
	local faceWingR2 = makePart(shieldModel, "FaceWingR2", Vector3.new(0.24, 0.60, 0.35), CFrame.new(-0.38, 0.25, -0.40), divineGold, Enum.Material.Metal)
	weldTo(shieldHandle, faceWingR2)

	-- Central Sunburst Boss
	local sunCenterDisc = makePart(shieldModel, "SunCenterDisc", Vector3.new(0.32, 0.85, 0.85), CFrame.new(-0.40, 0.45, 0), divineGold, Enum.Material.Metal)
	weldTo(shieldHandle, sunCenterDisc)
	local sunInnerGlow = makePart(shieldModel, "SunInnerGlow", Vector3.new(0.38, 0.42, 0.42), CFrame.new(-0.46, 0.20, 0), sunRadiance, Enum.Material.Neon)
	weldTo(shieldHandle, sunInnerGlow)

	-- Radiating 8 Sun Rays
	local rayUp = makePart(shieldModel, "RayUp", Vector3.new(0.28, 0.60, 0.16), CFrame.new(-0.40, 1.05, 0), divineGold, Enum.Material.Metal)
	weldTo(shieldHandle, rayUp)
	local rayDown = makePart(shieldModel, "RayDown", Vector3.new(0.28, 0.60, 0.16), CFrame.new(-0.40, -0.15, 0), divineGold, Enum.Material.Metal)
	weldTo(shieldHandle, rayDown)
	local rayLeft = makePart(shieldModel, "RayLeft", Vector3.new(0.28, 0.16, 0.60), CFrame.new(-0.40, 0.45, 0.60), divineGold, Enum.Material.Metal)
	weldTo(shieldHandle, rayLeft)
	local rayRight = makePart(shieldModel, "RayRight", Vector3.new(0.28, 0.16, 0.60), CFrame.new(-0.40, 0.45, -0.60), divineGold, Enum.Material.Metal)
	weldTo(shieldHandle, rayRight)
	local rayTL = makePart(shieldModel, "RayTL", Vector3.new(0.26, 0.42, 0.42), CFrame.new(-0.40, 0.88, 0.42), sunRadiance, Enum.Material.Metal)
	weldTo(shieldHandle, rayTL)
	local rayTR = makePart(shieldModel, "RayTR", Vector3.new(0.26, 0.42, 0.42), CFrame.new(-0.40, 0.88, -0.42), sunRadiance, Enum.Material.Metal)
	weldTo(shieldHandle, rayTR)
	local rayBL = makePart(shieldModel, "RayBL", Vector3.new(0.26, 0.42, 0.42), CFrame.new(-0.40, 0.02, 0.42), sunRadiance, Enum.Material.Metal)
	weldTo(shieldHandle, rayBL)
	local rayBR = makePart(shieldModel, "RayBR", Vector3.new(0.26, 0.42, 0.42), CFrame.new(-0.40, 0.02, -0.42), sunRadiance, Enum.Material.Metal)
	weldTo(shieldHandle, rayBR)

	local lowerCruciform = makePart(shieldModel, "LowerCruciform", Vector3.new(0.24, 0.80, 0.35), CFrame.new(-0.38, -0.95, 0), divineGold, Enum.Material.Metal)
	weldTo(shieldHandle, lowerCruciform)
	local lowerGem = makePart(shieldModel, "LowerGem", Vector3.new(0.28, 0.25, 0.25), CFrame.new(-0.42, -0.95, 0), sunRadiance, Enum.Material.Glass)
	lowerGem.Transparency = 0.25
	weldTo(shieldHandle, lowerGem)
	local haloStud1 = makePart(shieldModel, "HaloStud1", Vector3.new(0.28, 0.18, 0.18), CFrame.new(-0.38, 1.25, 0.55), sunRadiance, Enum.Material.Metal)
	weldTo(shieldHandle, haloStud1)
	local haloStud2 = makePart(shieldModel, "HaloStud2", Vector3.new(0.28, 0.18, 0.18), CFrame.new(-0.38, 1.25, -0.55), sunRadiance, Enum.Material.Metal)
	weldTo(shieldHandle, haloStud2)
	local haloStud3 = makePart(shieldModel, "HaloStud3", Vector3.new(0.28, 0.18, 0.18), CFrame.new(-0.38, 1.65, 0), sunRadiance, Enum.Material.Metal)
	weldTo(shieldHandle, haloStud3)

	local armPad = makePart(shieldModel, "ArmPad", Vector3.new(0.18, 0.80, 0.34), CFrame.new(-0.16, 0.10, 0), pureWhite)
	weldTo(shieldHandle, armPad)
	local strapTop = makePart(shieldModel, "StrapTop", Vector3.new(0.14, 0.16, 0.46), CFrame.new(-0.10, 0.38, 0), divineGold, Enum.Material.Metal)
	weldTo(shieldHandle, strapTop)
	local strapBot = makePart(shieldModel, "StrapBot", Vector3.new(0.14, 0.16, 0.46), CFrame.new(-0.10, -0.18, 0), divineGold, Enum.Material.Metal)
	weldTo(shieldHandle, strapBot)

	addSocket(shieldHandle, "ShieldMount", Vector3.new(-0.18, 0, 0), Vector3.new(0, 90, 0))
	addSocket(shieldHandle, "VfxShieldCenter", Vector3.new(-0.48, 0.10, 0))

	return model
end


function WeaponModelBuilder.BuildAegisOfValor(): Model
	local model = Instance.new("Model")
	model.Name = "art_aegis_of_valor"

	local royalGold = Color3.fromRGB(245, 205, 65)
	local solarIncandescent = Color3.fromRGB(255, 242, 165)
	local mirrorSilver = Color3.fromRGB(235, 240, 250)
	local rubyGlint = Color3.fromRGB(235, 35, 65)
	local royalCrimson = Color3.fromRGB(115, 25, 38)

	-- Royal Gilded Arming Sword (36 parts)

-- Sword Assembly (36 parts: royal grandmaster greatsword with solar quillons)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.20, 1.45, 0.20)
	handle.CFrame = CFrame.new(0, 0, 0)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = model
	model.PrimaryPart = handle

	local gripCyl = makeCylinder(model, "GripCylinder", 1.35, 0.18, CFrame.new(0, 0, 0), royalCrimson)
	weldTo(handle, gripCyl)
	local gripWrap1 = makeCylinder(model, "GripWrap1", 0.12, 0.20, CFrame.new(0, -0.42, 0), royalGold, Enum.Material.Metal)
	weldTo(handle, gripWrap1)
	local gripWrap2 = makeCylinder(model, "GripWrap2", 0.12, 0.20, CFrame.new(0, 0.0, 0), royalGold, Enum.Material.Metal)
	weldTo(handle, gripWrap2)
	local gripWrap3 = makeCylinder(model, "GripWrap3", 0.12, 0.20, CFrame.new(0, 0.42, 0), royalGold, Enum.Material.Metal)
	weldTo(handle, gripWrap3)

	local pommelNeck = makeCylinder(model, "PommelNeck", 0.12, 0.24, CFrame.new(0, -0.74, 0), royalGold, Enum.Material.Metal)
	weldTo(handle, pommelNeck)
	local pommelBall = makeBall(model, "PommelBall", 0.42, CFrame.new(0, -0.94, 0), royalGold, Enum.Material.Metal)
	weldTo(handle, pommelBall)
	local pommelSun = makeBall(model, "PommelSun", 0.20, CFrame.new(0, -1.18, 0), solarIncandescent, Enum.Material.Neon)
	weldTo(handle, pommelSun)

	local guardCenter = makePart(model, "GuardCenter", Vector3.new(0.42, 0.24, 0.28), CFrame.new(0, 0.74, 0), royalGold, Enum.Material.Metal)
	weldTo(handle, guardCenter)
	local guardEcusson = makePart(model, "GuardEcusson", Vector3.new(0.32, 0.34, 0.10), CFrame.new(0, 0.76, 0.14), solarIncandescent, Enum.Material.Neon)
	weldTo(handle, guardEcusson)
	local quillonL = makePart(model, "QuillonL", Vector3.new(0.24, 0.16, 0.60), CFrame.new(0, 0.76, 0.50) * CFrame.Angles(math.rad(12), 0, 0), royalGold, Enum.Material.Metal)
	weldTo(handle, quillonL)
	local quillonR = makePart(model, "QuillonR", Vector3.new(0.24, 0.16, 0.60), CFrame.new(0, 0.76, -0.50) * CFrame.Angles(math.rad(-12), 0, 0), royalGold, Enum.Material.Metal)
	weldTo(handle, quillonR)
	local quillonWingL = makePart(model, "QuillonWingL", Vector3.new(0.14, 0.26, 0.26), CFrame.new(0, 0.84, 0.68), royalGold, Enum.Material.Metal)
	weldTo(handle, quillonWingL)
	local quillonWingR = makePart(model, "QuillonWingR", Vector3.new(0.14, 0.26, 0.26), CFrame.new(0, 0.84, -0.68), royalGold, Enum.Material.Metal)
	weldTo(handle, quillonWingR)
	local finialL = makeBall(model, "QuillonFinialL", 0.22, CFrame.new(0, 0.92, 0.86), royalGold, Enum.Material.Metal)
	weldTo(handle, finialL)
	local finialR = makeBall(model, "QuillonFinialR", 0.22, CFrame.new(0, 0.92, -0.86), royalGold, Enum.Material.Metal)
	weldTo(handle, finialR)

	local ricasso = makePart(model, "Ricasso", Vector3.new(0.54, 0.75, 0.08), CFrame.new(0, 1.20, 0), mirrorSilver, Enum.Material.Metal)
	weldTo(handle, ricasso)
	local parryingLugL = makePart(model, "ParryingLugL", Vector3.new(0.28, 0.20, 0.08), CFrame.new(0.40, 1.50, 0) * CFrame.Angles(0, 0, math.rad(-25)), royalGold, Enum.Material.Metal)
	weldTo(handle, parryingLugL)
	local parryingLugR = makePart(model, "ParryingLugR", Vector3.new(0.28, 0.20, 0.08), CFrame.new(-0.40, 1.50, 0) * CFrame.Angles(0, 0, math.rad(25)), royalGold, Enum.Material.Metal)
	weldTo(handle, parryingLugR)
	local lugSpurL = makePart(model, "LugSpurL", Vector3.new(0.10, 0.16, 0.07), CFrame.new(0.52, 1.62, 0), rubyGlint, Enum.Material.Neon)
	weldTo(handle, lugSpurL)
	local lugSpurR = makePart(model, "LugSpurR", Vector3.new(0.10, 0.16, 0.07), CFrame.new(-0.52, 1.62, 0), rubyGlint, Enum.Material.Neon)
	weldTo(handle, lugSpurR)

	local fullerMain = makePart(model, "FullerMain", Vector3.new(0.18, 4.00, 0.07), CFrame.new(0, 3.55, 0), mirrorSilver, Enum.Material.Metal)
	weldTo(handle, fullerMain)
	local fullerInlay = makePart(model, "FullerInlay", Vector3.new(0.06, 3.40, 0.075), CFrame.new(0, 3.50, 0), royalGold, Enum.Material.Metal)
	weldTo(handle, fullerInlay)

	local edgeFwd1 = makePart(model, "EdgeFwd1", Vector3.new(0.24, 2.00, 0.045), CFrame.new(0.21, 2.55, 0), mirrorSilver, Enum.Material.Metal)
	weldTo(handle, edgeFwd1)
	local edgeFwd2 = makePart(model, "EdgeFwd2", Vector3.new(0.22, 1.95, 0.045), CFrame.new(0.20, 4.45, 0), mirrorSilver, Enum.Material.Metal)
	weldTo(handle, edgeFwd2)
	local edgeBack1 = makePart(model, "EdgeBack1", Vector3.new(0.24, 2.00, 0.045), CFrame.new(-0.21, 2.55, 0), mirrorSilver, Enum.Material.Metal)
	weldTo(handle, edgeBack1)
	local edgeBack2 = makePart(model, "EdgeBack2", Vector3.new(0.22, 1.95, 0.045), CFrame.new(-0.20, 4.45, 0), mirrorSilver, Enum.Material.Metal)
	weldTo(handle, edgeBack2)

	local midSpurL = makePart(model, "MidSpurL", Vector3.new(0.14, 0.35, 0.05), CFrame.new(0.26, 5.15, 0), royalGold, Enum.Material.Metal)
	weldTo(handle, midSpurL)
	local midSpurR = makePart(model, "MidSpurR", Vector3.new(0.14, 0.35, 0.05), CFrame.new(-0.26, 5.15, 0), royalGold, Enum.Material.Metal)
	weldTo(handle, midSpurR)

	local tipFwd = makeWedge(model, "TipFwd", Vector3.new(0.045, 0.68, 0.32), CFrame.new(0.16, 5.75, 0) * CFrame.Angles(0, math.rad(-90), 0), mirrorSilver, Enum.Material.Metal)
	weldTo(handle, tipFwd)
	local tipBack = makeWedge(model, "TipBack", Vector3.new(0.045, 0.68, 0.32), CFrame.new(-0.16, 5.75, 0) * CFrame.Angles(0, math.rad(90), 0), mirrorSilver, Enum.Material.Metal)
	weldTo(handle, tipBack)

	addSocket(handle, "Grip", Vector3.new(0, 0, 0), Vector3.new(0, -90, 0))
	addSocket(handle, "Tip", Vector3.new(0, 6.05, 0), Vector3.new(0, 0, 0))
	addSocket(handle, "VfxTip", Vector3.new(0, 6.05, 0))
	addSocket(handle, "VfxBase", Vector3.new(0, 1.05, 0))
	addSocket(handle, "VfxCore", Vector3.new(0, 0.74, 0))

	local shieldModel = Instance.new("Model")
	shieldModel.Name = "OffhandShield"
	shieldModel.Parent = model

	local shieldHandle = makePart(shieldModel, "HandleS", Vector3.new(0.22, 0.60, 0.22), CFrame.new(0, 0, 0), royalCrimson)
	shieldModel.PrimaryPart = shieldHandle

	-- Concentric Round Solar Plates
	local centralAegisDisc = makePart(shieldModel, "CentralAegisDisc", Vector3.new(0.24, 1.80, 1.80), CFrame.new(-0.34, 0.15, 0), royalGold, Enum.Material.Metal)
	weldTo(shieldHandle, centralAegisDisc)
	local innerMirrorPlate = makePart(shieldModel, "InnerMirrorPlate", Vector3.new(0.26, 1.40, 1.40), CFrame.new(-0.36, 0.15, 0), mirrorSilver, Enum.Material.Metal)
	weldTo(shieldHandle, innerMirrorPlate)
	local coreSolarHum = makePart(shieldModel, "CoreSolarHum", Vector3.new(0.38, 0.75, 0.75), CFrame.new(-0.44, 0.15, 0), solarIncandescent, Enum.Material.Glass)
	coreSolarHum.Transparency = 0.25
	weldTo(shieldHandle, coreSolarHum)
	local coreRubyBoss = makePart(shieldModel, "CoreRubyBoss", Vector3.new(0.44, 0.38, 0.38), CFrame.new(-0.48, 0.15, 0), rubyGlint, Enum.Material.Neon)
	weldTo(shieldHandle, coreRubyBoss)

	-- 8 Curved Corona Sunburst Blades around perimeter
	local coronaN = makePart(shieldModel, "CoronaN", Vector3.new(0.26, 0.55, 0.32), CFrame.new(-0.36, 1.15, 0), royalGold, Enum.Material.Metal)
	weldTo(shieldHandle, coronaN)
	local coronaS = makePart(shieldModel, "CoronaS", Vector3.new(0.26, 0.55, 0.32), CFrame.new(-0.36, -0.85, 0), royalGold, Enum.Material.Metal)
	weldTo(shieldHandle, coronaS)
	local coronaE = makePart(shieldModel, "CoronaE", Vector3.new(0.26, 0.32, 0.55), CFrame.new(-0.36, 0.15, 1.00), royalGold, Enum.Material.Metal)
	weldTo(shieldHandle, coronaE)
	local coronaW = makePart(shieldModel, "CoronaW", Vector3.new(0.26, 0.32, 0.55), CFrame.new(-0.36, 0.15, -1.00), royalGold, Enum.Material.Metal)
	weldTo(shieldHandle, coronaW)
	local coronaNE = makePart(shieldModel, "CoronaNE", Vector3.new(0.24, 0.45, 0.45), CFrame.new(-0.36, 0.85, 0.70), royalGold, Enum.Material.Metal)
	weldTo(shieldHandle, coronaNE)
	local coronaNW = makePart(shieldModel, "CoronaNW", Vector3.new(0.24, 0.45, 0.45), CFrame.new(-0.36, 0.85, -0.70), royalGold, Enum.Material.Metal)
	weldTo(shieldHandle, coronaNW)
	local coronaSE = makePart(shieldModel, "CoronaSE", Vector3.new(0.24, 0.45, 0.45), CFrame.new(-0.36, -0.55, 0.70), royalGold, Enum.Material.Metal)
	weldTo(shieldHandle, coronaSE)
	local coronaSW = makePart(shieldModel, "CoronaSW", Vector3.new(0.24, 0.45, 0.45), CFrame.new(-0.36, -0.55, -0.70), royalGold, Enum.Material.Metal)
	weldTo(shieldHandle, coronaSW)

	-- 8 Radiant Tip Prisms on Corona Blades
	local tipN = makePart(shieldModel, "TipN", Vector3.new(0.28, 0.22, 0.22), CFrame.new(-0.38, 1.48, 0), solarIncandescent, Enum.Material.Metal)
	weldTo(shieldHandle, tipN)
	local tipS = makePart(shieldModel, "TipS", Vector3.new(0.28, 0.22, 0.22), CFrame.new(-0.38, -1.18, 0), solarIncandescent, Enum.Material.Metal)
	weldTo(shieldHandle, tipS)
	local tipE = makePart(shieldModel, "TipE", Vector3.new(0.28, 0.22, 0.22), CFrame.new(-0.38, 0.15, 1.32), solarIncandescent, Enum.Material.Metal)
	weldTo(shieldHandle, tipE)
	local tipW = makePart(shieldModel, "TipW", Vector3.new(0.28, 0.22, 0.22), CFrame.new(-0.38, 0.15, -1.32), solarIncandescent, Enum.Material.Metal)
	weldTo(shieldHandle, tipW)
	local tipNE = makePart(shieldModel, "TipNE", Vector3.new(0.26, 0.20, 0.20), CFrame.new(-0.38, 1.08, 0.92), rubyGlint, Enum.Material.Metal)
	weldTo(shieldHandle, tipNE)
	local tipNW = makePart(shieldModel, "TipNW", Vector3.new(0.26, 0.20, 0.20), CFrame.new(-0.38, 1.08, -0.92), rubyGlint, Enum.Material.Metal)
	weldTo(shieldHandle, tipNW)
	local tipSE = makePart(shieldModel, "TipSE", Vector3.new(0.26, 0.20, 0.20), CFrame.new(-0.38, -0.78, 0.92), rubyGlint, Enum.Material.Metal)
	weldTo(shieldHandle, tipSE)
	local tipSW = makePart(shieldModel, "TipSW", Vector3.new(0.26, 0.20, 0.20), CFrame.new(-0.38, -0.78, -0.92), rubyGlint, Enum.Material.Metal)
	weldTo(shieldHandle, tipSW)

	-- Barrier Projector Rings
	local barrierDomeL = makePart(shieldModel, "BarrierDomeL", Vector3.new(0.22, 1.20, 0.24), CFrame.new(-0.37, 0.15, 0.60), solarIncandescent, Enum.Material.Glass)
	barrierDomeL.Transparency = 0.25
	weldTo(shieldHandle, barrierDomeL)
	local barrierDomeR = makePart(shieldModel, "BarrierDomeR", Vector3.new(0.22, 1.20, 0.24), CFrame.new(-0.37, 0.15, -0.60), solarIncandescent, Enum.Material.Glass)
	barrierDomeR.Transparency = 0.25
	weldTo(shieldHandle, barrierDomeR)
	local filigreeArc1 = makePart(shieldModel, "FiligreeArc1", Vector3.new(0.26, 0.22, 1.00), CFrame.new(-0.37, 0.70, 0), royalGold, Enum.Material.Metal)
	weldTo(shieldHandle, filigreeArc1)
	local filigreeArc2 = makePart(shieldModel, "FiligreeArc2", Vector3.new(0.26, 0.22, 1.00), CFrame.new(-0.37, -0.40, 0), royalGold, Enum.Material.Metal)
	weldTo(shieldHandle, filigreeArc2)
	local domeNode1 = makePart(shieldModel, "DomeNode1", Vector3.new(0.30, 0.18, 0.18), CFrame.new(-0.39, 0.60, 0.40), rubyGlint, Enum.Material.Glass)
	domeNode1.Transparency = 0.25
	weldTo(shieldHandle, domeNode1)
	local domeNode2 = makePart(shieldModel, "DomeNode2", Vector3.new(0.30, 0.18, 0.18), CFrame.new(-0.39, 0.60, -0.40), rubyGlint, Enum.Material.Glass)
	domeNode2.Transparency = 0.25
	weldTo(shieldHandle, domeNode2)
	local domeNode3 = makePart(shieldModel, "DomeNode3", Vector3.new(0.30, 0.18, 0.18), CFrame.new(-0.39, -0.30, 0.40), rubyGlint, Enum.Material.Glass)
	domeNode3.Transparency = 0.25
	weldTo(shieldHandle, domeNode3)
	local domeNode4 = makePart(shieldModel, "DomeNode4", Vector3.new(0.30, 0.18, 0.18), CFrame.new(-0.39, -0.30, -0.40), rubyGlint, Enum.Material.Glass)
	domeNode4.Transparency = 0.25
	weldTo(shieldHandle, domeNode4)

	local armMountHarness = makePart(shieldModel, "ArmMountHarness", Vector3.new(0.20, 0.80, 0.32), CFrame.new(-0.16, 0.15, 0), royalGold, Enum.Material.Metal)
	weldTo(shieldHandle, armMountHarness)
	local strapTop = makePart(shieldModel, "StrapTop", Vector3.new(0.14, 0.14, 0.44), CFrame.new(-0.10, 0.42, 0), royalCrimson)
	weldTo(shieldHandle, strapTop)
	local strapBot = makePart(shieldModel, "StrapBot", Vector3.new(0.14, 0.14, 0.44), CFrame.new(-0.10, -0.12, 0), royalCrimson)
	weldTo(shieldHandle, strapBot)

	addSocket(shieldHandle, "ShieldMount", Vector3.new(-0.18, 0, 0), Vector3.new(0, 90, 0))
	addSocket(shieldHandle, "VfxShieldCenter", Vector3.new(-0.50, 0.10, 0))

	return model
end


function WeaponModelBuilder.BuildBladeOfTheRift(): Model
	local model = Instance.new("Model")
	model.Name = "art_blade_of_the_rift"

	local cosmicGlass = Color3.fromRGB(25, 20, 42)
	local nebulaViolet = Color3.fromRGB(165, 85, 245)
	local starlightCyan = Color3.fromRGB(80, 230, 255)
	local antiqueBronze = Color3.fromRGB(180, 140, 75)
	local cathedralStone = Color3.fromRGB(65, 62, 75)

	-- Dimensional Cosmic Glass Blade (39 parts)

-- Sword Assembly (39 parts: cosmic void rift blade with segmented edge fangs and floating rift shards)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.20, 1.50, 0.20)
	handle.CFrame = CFrame.new(0, 0, 0)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = model
	model.PrimaryPart = handle

	local gripCyl = makeCylinder(model, "GripCylinder", 1.40, 0.18, CFrame.new(0, 0, 0), cathedralStone)
	weldTo(handle, gripCyl)
	local gripWrap1 = makeCylinder(model, "GripWrap1", 0.12, 0.20, CFrame.new(0, -0.45, 0), antiqueBronze, Enum.Material.Metal)
	weldTo(handle, gripWrap1)
	local gripWrap2 = makeCylinder(model, "GripWrap2", 0.12, 0.20, CFrame.new(0, 0.0, 0), antiqueBronze, Enum.Material.Metal)
	weldTo(handle, gripWrap2)
	local gripWrap3 = makeCylinder(model, "GripWrap3", 0.12, 0.20, CFrame.new(0, 0.45, 0), antiqueBronze, Enum.Material.Metal)
	weldTo(handle, gripWrap3)

	local pommelNeck = makeCylinder(model, "PommelNeck", 0.12, 0.24, CFrame.new(0, -0.76, 0), antiqueBronze, Enum.Material.Metal)
	weldTo(handle, pommelNeck)
	local pommelBall = makeBall(model, "PommelBall", 0.42, CFrame.new(0, -0.96, 0), cosmicGlass, Enum.Material.Metal)
	weldTo(handle, pommelBall)
	local pommelFinial = makeBall(model, "PommelFinial", 0.20, CFrame.new(0, -1.20, 0), antiqueBronze, Enum.Material.Metal)
	weldTo(handle, pommelFinial)

	local guardCenter = makePart(model, "GuardCenter", Vector3.new(0.42, 0.24, 0.28), CFrame.new(0, 0.76, 0), cosmicGlass, Enum.Material.Metal)
	weldTo(handle, guardCenter)
	local guardRiftCore = makeBall(model, "GuardRiftCore", 0.24, CFrame.new(0, 0.78, 0.14), starlightCyan, Enum.Material.Neon)
	weldTo(handle, guardRiftCore)
	local quillonL = makePart(model, "QuillonL", Vector3.new(0.24, 0.16, 0.62), CFrame.new(0, 0.78, 0.52) * CFrame.Angles(math.rad(12), 0, 0), cosmicGlass, Enum.Material.Metal)
	weldTo(handle, quillonL)
	local quillonR = makePart(model, "QuillonR", Vector3.new(0.24, 0.16, 0.62), CFrame.new(0, 0.78, -0.52) * CFrame.Angles(math.rad(-12), 0, 0), cosmicGlass, Enum.Material.Metal)
	weldTo(handle, quillonR)
	local finialL = makeBall(model, "QuillonFinialL", 0.22, CFrame.new(0, 0.94, 0.88), antiqueBronze, Enum.Material.Metal)
	weldTo(handle, finialL)
	local finialR = makeBall(model, "QuillonFinialR", 0.22, CFrame.new(0, 0.94, -0.88), antiqueBronze, Enum.Material.Metal)
	weldTo(handle, finialR)

	local ricasso = makePart(model, "Ricasso", Vector3.new(0.56, 0.75, 0.08), CFrame.new(0, 1.25, 0), nebulaViolet, Enum.Material.Metal)
	weldTo(handle, ricasso)
	local riftShardL1 = makePart(model, "RiftShardL1", Vector3.new(0.14, 0.35, 0.07), CFrame.new(0.34, 1.50, 0), starlightCyan, Enum.Material.Neon)
	weldTo(handle, riftShardL1)
	local riftShardL2 = makePart(model, "RiftShardL2", Vector3.new(0.12, 0.30, 0.07), CFrame.new(0.42, 1.85, 0), antiqueBronze, Enum.Material.Metal)
	weldTo(handle, riftShardL2)
	local riftShardR1 = makePart(model, "RiftShardR1", Vector3.new(0.14, 0.35, 0.07), CFrame.new(-0.34, 1.50, 0), starlightCyan, Enum.Material.Neon)
	weldTo(handle, riftShardR1)
	local riftShardR2 = makePart(model, "RiftShardR2", Vector3.new(0.12, 0.30, 0.07), CFrame.new(-0.42, 1.85, 0), antiqueBronze, Enum.Material.Metal)
	weldTo(handle, riftShardR2)

	local bladeFuller = makePart(model, "BladeFuller", Vector3.new(0.18, 4.20, 0.07), CFrame.new(0, 3.70, 0), nebulaViolet, Enum.Material.Metal)
	weldTo(handle, bladeFuller)
	local riftChannel = makePart(model, "RiftChannel", Vector3.new(0.06, 3.60, 0.075), CFrame.new(0, 3.65, 0), starlightCyan, Enum.Material.Neon)
	weldTo(handle, riftChannel)

	local edgeFwd1 = makePart(model, "EdgeFwd1", Vector3.new(0.24, 2.10, 0.045), CFrame.new(0.22, 2.65, 0), nebulaViolet, Enum.Material.Metal)
	weldTo(handle, edgeFwd1)
	local edgeFwd2 = makePart(model, "EdgeFwd2", Vector3.new(0.22, 2.05, 0.045), CFrame.new(0.21, 4.65, 0), nebulaViolet, Enum.Material.Metal)
	weldTo(handle, edgeFwd2)
	local edgeBack1 = makePart(model, "EdgeBack1", Vector3.new(0.24, 2.10, 0.045), CFrame.new(-0.22, 2.65, 0), nebulaViolet, Enum.Material.Metal)
	weldTo(handle, edgeBack1)
	local edgeBack2 = makePart(model, "EdgeBack2", Vector3.new(0.22, 2.05, 0.045), CFrame.new(-0.21, 4.65, 0), nebulaViolet, Enum.Material.Metal)
	weldTo(handle, edgeBack2)

	local serrationFwd1 = makePart(model, "SerrationFwd1", Vector3.new(0.12, 0.30, 0.05), CFrame.new(0.28, 5.00, 0), antiqueBronze, Enum.Material.Metal)
	weldTo(handle, serrationFwd1)
	local serrationFwd2 = makePart(model, "SerrationFwd2", Vector3.new(0.10, 0.25, 0.05), CFrame.new(0.26, 5.35, 0), antiqueBronze, Enum.Material.Metal)
	weldTo(handle, serrationFwd2)
	local serrationBack1 = makePart(model, "SerrationBack1", Vector3.new(0.12, 0.30, 0.05), CFrame.new(-0.28, 5.00, 0), antiqueBronze, Enum.Material.Metal)
	weldTo(handle, serrationBack1)
	local serrationBack2 = makePart(model, "SerrationBack2", Vector3.new(0.10, 0.25, 0.05), CFrame.new(-0.26, 5.35, 0), antiqueBronze, Enum.Material.Metal)
	weldTo(handle, serrationBack2)

	local floatingShard1 = makePart(model, "FloatingShard1", Vector3.new(0.08, 0.30, 0.05), CFrame.new(0.36, 4.20, 0), starlightCyan, Enum.Material.Neon)
	weldTo(handle, floatingShard1)
	local floatingShard2 = makePart(model, "FloatingShard2", Vector3.new(0.08, 0.30, 0.05), CFrame.new(-0.36, 4.20, 0), starlightCyan, Enum.Material.Neon)
	weldTo(handle, floatingShard2)

	local tipFwd = makeWedge(model, "TipFwd", Vector3.new(0.045, 0.70, 0.34), CFrame.new(0.17, 5.95, 0) * CFrame.Angles(0, math.rad(-90), 0), nebulaViolet, Enum.Material.Metal)
	weldTo(handle, tipFwd)
	local tipBack = makeWedge(model, "TipBack", Vector3.new(0.045, 0.70, 0.34), CFrame.new(-0.17, 5.95, 0) * CFrame.Angles(0, math.rad(90), 0), nebulaViolet, Enum.Material.Metal)
	weldTo(handle, tipBack)

	addSocket(handle, "Grip", Vector3.new(0, 0, 0), Vector3.new(0, -90, 0))
	addSocket(handle, "Tip", Vector3.new(0, 6.25, 0), Vector3.new(0, 0, 0))
	addSocket(handle, "VfxTip", Vector3.new(0, 6.25, 0))
	addSocket(handle, "VfxBase", Vector3.new(0, 1.10, 0))
	addSocket(handle, "VfxCore", Vector3.new(0, 0.76, 0))

	local shieldModel = Instance.new("Model")
	shieldModel.Name = "OffhandShield"
	shieldModel.Parent = model

	local shieldHandle = makePart(shieldModel, "HandleS", Vector3.new(0.22, 0.65, 0.22), CFrame.new(0, 0, 0), cathedralStone)
	shieldModel.PrimaryPart = shieldHandle

	-- Gothic Cathedral Arch Frame
	local pillarL = makePart(shieldModel, "PillarL", Vector3.new(0.30, 3.20, 0.26), CFrame.new(-0.36, 0.10, 0.80), cathedralStone, Enum.Material.Metal)
	weldTo(shieldHandle, pillarL)
	local pillarR = makePart(shieldModel, "PillarR", Vector3.new(0.30, 3.20, 0.26), CFrame.new(-0.36, 0.10, -0.80), cathedralStone, Enum.Material.Metal)
	weldTo(shieldHandle, pillarR)
	local archRoofL = makePart(shieldModel, "ArchRoofL", Vector3.new(0.28, 0.70, 0.55), CFrame.new(-0.36, 1.85, 0.42), cathedralStone, Enum.Material.Metal)
	weldTo(shieldHandle, archRoofL)
	local archRoofR = makePart(shieldModel, "ArchRoofR", Vector3.new(0.28, 0.70, 0.55), CFrame.new(-0.36, 1.85, -0.42), cathedralStone, Enum.Material.Metal)
	weldTo(shieldHandle, archRoofR)
	local archKeystone = makePart(shieldModel, "ArchKeystone", Vector3.new(0.34, 0.40, 0.40), CFrame.new(-0.38, 2.22, 0), antiqueBronze, Enum.Material.Metal)
	weldTo(shieldHandle, archKeystone)
	local baseSill = makePart(shieldModel, "BaseSill", Vector3.new(0.32, 0.35, 1.80), CFrame.new(-0.36, -1.55, 0), cathedralStone, Enum.Material.Metal)
	weldTo(shieldHandle, baseSill)

	-- Antique Bronze Filigree Trim
	local bronzeTrimL = makePart(shieldModel, "BronzeTrimL", Vector3.new(0.32, 3.20, 0.10), CFrame.new(-0.38, 0.10, 0.94), antiqueBronze, Enum.Material.Metal)
	weldTo(shieldHandle, bronzeTrimL)
	local bronzeTrimR = makePart(shieldModel, "BronzeTrimR", Vector3.new(0.32, 3.20, 0.10), CFrame.new(-0.38, 0.10, -0.94), antiqueBronze, Enum.Material.Metal)
	weldTo(shieldHandle, bronzeTrimR)
	local pinnacleSpireL = makePart(shieldModel, "PinnacleSpireL", Vector3.new(0.22, 0.60, 0.22), CFrame.new(-0.38, 1.95, 0.80), antiqueBronze, Enum.Material.Metal)
	weldTo(shieldHandle, pinnacleSpireL)
	local pinnacleSpireR = makePart(shieldModel, "PinnacleSpireR", Vector3.new(0.22, 0.60, 0.22), CFrame.new(-0.38, 1.95, -0.80), antiqueBronze, Enum.Material.Metal)
	weldTo(shieldHandle, pinnacleSpireR)

	-- Cosmic Rift Mirror Face (The Portal into the Void)
	local portalFace = makePart(shieldModel, "PortalFace", Vector3.new(0.22, 2.80, 1.35), CFrame.new(-0.34, 0.25, 0), cosmicGlass, Enum.Material.Glass)
	weldTo(shieldHandle, portalFace)
	local nebulaSwirl = makePart(shieldModel, "NebulaSwirl", Vector3.new(0.26, 2.20, 1.05), CFrame.new(-0.38, 0.25, 0), nebulaViolet, Enum.Material.SmoothPlastic)
	weldTo(shieldHandle, nebulaSwirl)
	local portalSingularity = makePart(shieldModel, "PortalSingularity", Vector3.new(0.36, 0.45, 0.45), CFrame.new(-0.44, 0.20, 0), starlightCyan, Enum.Material.Neon)
	weldTo(shieldHandle, portalSingularity)

	-- 8 Floating Cathedral Rose Window Crystals
	local rosePetal1 = makePart(shieldModel, "RosePetal1", Vector3.new(0.28, 0.35, 0.18), CFrame.new(-0.40, 0.95, 0), starlightCyan, Enum.Material.Glass)
	rosePetal1.Transparency = 0.20
	weldTo(shieldHandle, rosePetal1)
	local rosePetal2 = makePart(shieldModel, "RosePetal2", Vector3.new(0.28, 0.35, 0.18), CFrame.new(-0.40, -0.25, 0), starlightCyan, Enum.Material.Glass)
	rosePetal2.Transparency = 0.20
	weldTo(shieldHandle, rosePetal2)
	local rosePetal3 = makePart(shieldModel, "RosePetal3", Vector3.new(0.28, 0.18, 0.35), CFrame.new(-0.40, 0.35, 0.50), starlightCyan, Enum.Material.Glass)
	rosePetal3.Transparency = 0.20
	weldTo(shieldHandle, rosePetal3)
	local rosePetal4 = makePart(shieldModel, "RosePetal4", Vector3.new(0.28, 0.18, 0.35), CFrame.new(-0.40, 0.35, -0.50), starlightCyan, Enum.Material.Glass)
	rosePetal4.Transparency = 0.20
	weldTo(shieldHandle, rosePetal4)
	local rosePetal5 = makePart(shieldModel, "RosePetal5", Vector3.new(0.26, 0.25, 0.25), CFrame.new(-0.40, 0.75, 0.35), nebulaViolet, Enum.Material.Glass)
	rosePetal5.Transparency = 0.20
	weldTo(shieldHandle, rosePetal5)
	local rosePetal6 = makePart(shieldModel, "RosePetal6", Vector3.new(0.26, 0.25, 0.25), CFrame.new(-0.40, 0.75, -0.35), nebulaViolet, Enum.Material.Glass)
	rosePetal6.Transparency = 0.20
	weldTo(shieldHandle, rosePetal6)
	local rosePetal7 = makePart(shieldModel, "RosePetal7", Vector3.new(0.26, 0.25, 0.25), CFrame.new(-0.40, -0.05, 0.35), nebulaViolet, Enum.Material.Glass)
	rosePetal7.Transparency = 0.20
	weldTo(shieldHandle, rosePetal7)
	local rosePetal8 = makePart(shieldModel, "RosePetal8", Vector3.new(0.26, 0.25, 0.25), CFrame.new(-0.40, -0.05, -0.35), nebulaViolet, Enum.Material.Glass)
	rosePetal8.Transparency = 0.20
	weldTo(shieldHandle, rosePetal8)

	-- Lower Gothic Rosette
	local lowerGothicPlate = makePart(shieldModel, "LowerGothicPlate", Vector3.new(0.26, 0.80, 0.90), CFrame.new(-0.36, -0.95, 0), antiqueBronze, Enum.Material.Metal)
	weldTo(shieldHandle, lowerGothicPlate)
	local lowerRosetteRune = makePart(shieldModel, "LowerRosetteRune", Vector3.new(0.30, 0.40, 0.40), CFrame.new(-0.40, -0.95, 0), nebulaViolet, Enum.Material.Metal)
	weldTo(shieldHandle, lowerRosetteRune)

	-- Gothic Tracery Bars
	local traceryL = makePart(shieldModel, "TraceryL", Vector3.new(0.28, 1.40, 0.08), CFrame.new(-0.38, 0.35, 0.28), antiqueBronze, Enum.Material.Metal)
	weldTo(shieldHandle, traceryL)
	local traceryR = makePart(shieldModel, "TraceryR", Vector3.new(0.28, 1.40, 0.08), CFrame.new(-0.38, 0.35, -0.28), antiqueBronze, Enum.Material.Metal)
	weldTo(shieldHandle, traceryR)
	local portalShard1 = makePart(shieldModel, "PortalShard1", Vector3.new(0.26, 0.30, 0.20), CFrame.new(-0.40, 1.40, 0.45), starlightCyan, Enum.Material.Glass)
	portalShard1.Transparency = 0.20
	weldTo(shieldHandle, portalShard1)
	local portalShard2 = makePart(shieldModel, "PortalShard2", Vector3.new(0.26, 0.30, 0.20), CFrame.new(-0.40, 1.40, -0.45), starlightCyan, Enum.Material.Glass)
	portalShard2.Transparency = 0.20
	weldTo(shieldHandle, portalShard2)
	local portalShard3 = makePart(shieldModel, "PortalShard3", Vector3.new(0.26, 0.30, 0.20), CFrame.new(-0.40, -0.70, 0.45), starlightCyan, Enum.Material.Glass)
	portalShard3.Transparency = 0.20
	weldTo(shieldHandle, portalShard3)
	local portalShard4 = makePart(shieldModel, "PortalShard4", Vector3.new(0.26, 0.30, 0.20), CFrame.new(-0.40, -0.70, -0.45), starlightCyan, Enum.Material.Glass)
	portalShard4.Transparency = 0.20
	weldTo(shieldHandle, portalShard4)
	local sillRivetL = makePart(shieldModel, "SillRivetL", Vector3.new(0.34, 0.18, 0.18), CFrame.new(-0.38, -1.55, 0.70), antiqueBronze, Enum.Material.Metal)
	weldTo(shieldHandle, sillRivetL)
	local sillRivetR = makePart(shieldModel, "SillRivetR", Vector3.new(0.34, 0.18, 0.18), CFrame.new(-0.38, -1.55, -0.70), antiqueBronze, Enum.Material.Metal)
	weldTo(shieldHandle, sillRivetR)

	local armVaultBrace = makePart(shieldModel, "ArmVaultBrace", Vector3.new(0.20, 0.90, 0.34), CFrame.new(-0.16, 0.10, 0), cathedralStone, Enum.Material.Metal)
	weldTo(shieldHandle, armVaultBrace)
	local strapTop = makePart(shieldModel, "StrapTop", Vector3.new(0.14, 0.16, 0.46), CFrame.new(-0.10, 0.42, 0), antiqueBronze, Enum.Material.Metal)
	weldTo(shieldHandle, strapTop)
	local strapBot = makePart(shieldModel, "StrapBot", Vector3.new(0.14, 0.16, 0.46), CFrame.new(-0.10, -0.22, 0), antiqueBronze, Enum.Material.Metal)
	weldTo(shieldHandle, strapBot)

	addSocket(shieldHandle, "ShieldMount", Vector3.new(-0.18, 0, 0), Vector3.new(0, 90, 0))
	addSocket(shieldHandle, "VfxShieldCenter", Vector3.new(-0.46, 0.10, 0))

	return model
end


function WeaponModelBuilder.BuildAegisCore(): Model
	local model = Instance.new("Model")
	model.Name = "art_aegis_core"

	local astralGold = Color3.fromRGB(245, 210, 75)
	local riftCorePlasma = Color3.fromRGB(90, 240, 255)
	local hyperViolet = Color3.fromRGB(195, 75, 255)
	local darkMatter = Color3.fromRGB(25, 22, 35)
	local stellarWhite = Color3.fromRGB(245, 248, 255)

	-- Floating Segmented Rift Blade (41 parts)

-- Sword Assembly (39 parts: astral aegis sword with cosmic prism wings and dual fullers)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.20, 1.55, 0.20)
	handle.CFrame = CFrame.new(0, 0, 0)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = model
	model.PrimaryPart = handle

	local gripCyl = makeCylinder(model, "GripCylinder", 1.45, 0.18, CFrame.new(0, 0, 0), darkMatter)
	weldTo(handle, gripCyl)
	local gripWrap1 = makeCylinder(model, "GripWrap1", 0.12, 0.20, CFrame.new(0, -0.48, 0), astralGold, Enum.Material.Metal)
	weldTo(handle, gripWrap1)
	local gripWrap2 = makeCylinder(model, "GripWrap2", 0.12, 0.20, CFrame.new(0, 0.0, 0), astralGold, Enum.Material.Metal)
	weldTo(handle, gripWrap2)
	local gripWrap3 = makeCylinder(model, "GripWrap3", 0.12, 0.20, CFrame.new(0, 0.48, 0), astralGold, Enum.Material.Metal)
	weldTo(handle, gripWrap3)

	local pommelNeck = makeCylinder(model, "PommelNeck", 0.12, 0.24, CFrame.new(0, -0.78, 0), astralGold, Enum.Material.Metal)
	weldTo(handle, pommelNeck)
	local pommelBall = makeBall(model, "PommelBall", 0.44, CFrame.new(0, -0.98, 0), darkMatter, Enum.Material.Metal)
	weldTo(handle, pommelBall)
	local pommelFinial = makeBall(model, "PommelFinial", 0.22, CFrame.new(0, -1.24, 0), astralGold, Enum.Material.Metal)
	weldTo(handle, pommelFinial)

	local guardCenter = makePart(model, "GuardCenter", Vector3.new(0.44, 0.24, 0.28), CFrame.new(0, 0.78, 0), astralGold, Enum.Material.Metal)
	weldTo(handle, guardCenter)
	local guardCorePrism = makeBall(model, "GuardCorePrism", 0.24, CFrame.new(0, 0.80, 0.14), riftCorePlasma, Enum.Material.Neon)
	weldTo(handle, guardCorePrism)
	local quillonL = makePart(model, "QuillonL", Vector3.new(0.24, 0.16, 0.64), CFrame.new(0, 0.80, 0.54) * CFrame.Angles(math.rad(12), 0, 0), astralGold, Enum.Material.Metal)
	weldTo(handle, quillonL)
	local quillonR = makePart(model, "QuillonR", Vector3.new(0.24, 0.16, 0.64), CFrame.new(0, 0.80, -0.54) * CFrame.Angles(math.rad(-12), 0, 0), astralGold, Enum.Material.Metal)
	weldTo(handle, quillonR)
	local finialL = makeBall(model, "QuillonFinialL", 0.22, CFrame.new(0, 0.96, 0.90), astralGold, Enum.Material.Metal)
	weldTo(handle, finialL)
	local finialR = makeBall(model, "QuillonFinialR", 0.22, CFrame.new(0, 0.96, -0.90), astralGold, Enum.Material.Metal)
	weldTo(handle, finialR)

	local ricasso = makePart(model, "Ricasso", Vector3.new(0.58, 0.80, 0.08), CFrame.new(0, 1.28, 0), stellarWhite, Enum.Material.Metal)
	weldTo(handle, ricasso)
	local ricassoSpikeL = makePart(model, "RicassoSpikeL", Vector3.new(0.14, 0.35, 0.07), CFrame.new(0.36, 1.55, 0), riftCorePlasma, Enum.Material.Neon)
	weldTo(handle, ricassoSpikeL)
	local ricassoSpikeR = makePart(model, "RicassoSpikeR", Vector3.new(0.14, 0.35, 0.07), CFrame.new(-0.36, 1.55, 0), riftCorePlasma, Enum.Material.Neon)
	weldTo(handle, ricassoSpikeR)
	local cosmicRibbonL = makePart(model, "CosmicRibbonL", Vector3.new(0.12, 0.30, 0.07), CFrame.new(0.44, 1.90, 0), astralGold, Enum.Material.Metal)
	weldTo(handle, cosmicRibbonL)
	local cosmicRibbonR = makePart(model, "CosmicRibbonR", Vector3.new(0.12, 0.30, 0.07), CFrame.new(-0.44, 1.90, 0), astralGold, Enum.Material.Metal)
	weldTo(handle, cosmicRibbonR)

	local bladeFuller = makePart(model, "BladeFuller", Vector3.new(0.18, 4.30, 0.07), CFrame.new(0, 3.75, 0), stellarWhite, Enum.Material.Metal)
	weldTo(handle, bladeFuller)
	local fullerCore = makePart(model, "FullerCore", Vector3.new(0.06, 3.70, 0.075), CFrame.new(0, 3.70, 0), riftCorePlasma, Enum.Material.Neon)
	weldTo(handle, fullerCore)

	local edgeFwd1 = makePart(model, "EdgeFwd1", Vector3.new(0.24, 2.15, 0.045), CFrame.new(0.23, 2.70, 0), stellarWhite, Enum.Material.Metal)
	weldTo(handle, edgeFwd1)
	local edgeFwd2 = makePart(model, "EdgeFwd2", Vector3.new(0.22, 2.10, 0.045), CFrame.new(0.22, 4.75, 0), stellarWhite, Enum.Material.Metal)
	weldTo(handle, edgeFwd2)
	local edgeBack1 = makePart(model, "EdgeBack1", Vector3.new(0.24, 2.15, 0.045), CFrame.new(-0.23, 2.70, 0), stellarWhite, Enum.Material.Metal)
	weldTo(handle, edgeBack1)
	local edgeBack2 = makePart(model, "EdgeBack2", Vector3.new(0.22, 2.10, 0.045), CFrame.new(-0.22, 4.75, 0), stellarWhite, Enum.Material.Metal)
	weldTo(handle, edgeBack2)

	local midSpurL = makePart(model, "MidSpurL", Vector3.new(0.12, 0.32, 0.05), CFrame.new(0.30, 5.10, 0), astralGold, Enum.Material.Metal)
	weldTo(handle, midSpurL)
	local midSpurR = makePart(model, "MidSpurR", Vector3.new(0.12, 0.32, 0.05), CFrame.new(-0.30, 5.10, 0), astralGold, Enum.Material.Metal)
	weldTo(handle, midSpurR)
	local upperSpurL = makePart(model, "UpperSpurL", Vector3.new(0.10, 0.28, 0.05), CFrame.new(0.28, 5.45, 0), astralGold, Enum.Material.Metal)
	weldTo(handle, upperSpurL)
	local upperSpurR = makePart(model, "UpperSpurR", Vector3.new(0.10, 0.28, 0.05), CFrame.new(-0.28, 5.45, 0), astralGold, Enum.Material.Metal)
	weldTo(handle, upperSpurR)

	local tipFwd = makeWedge(model, "TipFwd", Vector3.new(0.045, 0.72, 0.35), CFrame.new(0.175, 6.05, 0) * CFrame.Angles(0, math.rad(-90), 0), stellarWhite, Enum.Material.Metal)
	weldTo(handle, tipFwd)
	local tipBack = makeWedge(model, "TipBack", Vector3.new(0.045, 0.72, 0.35), CFrame.new(-0.175, 6.05, 0) * CFrame.Angles(0, math.rad(90), 0), stellarWhite, Enum.Material.Metal)
	weldTo(handle, tipBack)

	addSocket(handle, "Grip", Vector3.new(0, 0, 0), Vector3.new(0, -90, 0))
	addSocket(handle, "Tip", Vector3.new(0, 6.35, 0), Vector3.new(0, 0, 0))
	addSocket(handle, "VfxTip", Vector3.new(0, 6.35, 0))
	addSocket(handle, "VfxBase", Vector3.new(0, 1.10, 0))
	addSocket(handle, "VfxCore", Vector3.new(0, 0.78, 0))

	local shieldModel = Instance.new("Model")
	shieldModel.Name = "OffhandShield"
	shieldModel.Parent = model

	local shieldHandle = makePart(shieldModel, "HandleS", Vector3.new(0.22, 0.65, 0.22), CFrame.new(0, 0, 0), darkMatter)
	shieldModel.PrimaryPart = shieldHandle

	-- Hyper-Dense Glowing Rift Power Core
	local containmentSphere = makePart(shieldModel, "ContainmentSphere", Vector3.new(0.36, 1.00, 1.00), CFrame.new(-0.36, 0.20, 0), darkMatter, Enum.Material.Metal)
	weldTo(shieldHandle, containmentSphere)
	local riftPowerCore = makePart(shieldModel, "RiftPowerCore", Vector3.new(0.46, 0.70, 0.70), CFrame.new(-0.44, 0.20, 0), riftCorePlasma, Enum.Material.Metal)
	weldTo(shieldHandle, riftPowerCore)
	local singularityEye = makePart(shieldModel, "SingularityEye", Vector3.new(0.50, 0.35, 0.35), CFrame.new(-0.48, 0.20, 0), hyperViolet, Enum.Material.Neon)
	weldTo(shieldHandle, singularityEye)

	-- 6 Hexagonal Floating Segmented Gold Orbital Plates
	local orbitPlate1 = makePart(shieldModel, "OrbitPlate1", Vector3.new(0.26, 0.80, 0.80), CFrame.new(-0.38, 1.40, 0), astralGold, Enum.Material.Metal)
	weldTo(shieldHandle, orbitPlate1)
	local orbitPlate2 = makePart(shieldModel, "OrbitPlate2", Vector3.new(0.26, 0.80, 0.80), CFrame.new(-0.38, -1.00, 0), astralGold, Enum.Material.Metal)
	weldTo(shieldHandle, orbitPlate2)
	local orbitPlate3 = makePart(shieldModel, "OrbitPlate3", Vector3.new(0.26, 0.80, 0.80), CFrame.new(-0.38, 0.80, 1.05), astralGold, Enum.Material.Metal)
	weldTo(shieldHandle, orbitPlate3)
	local orbitPlate4 = makePart(shieldModel, "OrbitPlate4", Vector3.new(0.26, 0.80, 0.80), CFrame.new(-0.38, 0.80, -1.05), astralGold, Enum.Material.Metal)
	weldTo(shieldHandle, orbitPlate4)
	local orbitPlate5 = makePart(shieldModel, "OrbitPlate5", Vector3.new(0.26, 0.80, 0.80), CFrame.new(-0.38, -0.40, 1.05), astralGold, Enum.Material.Metal)
	weldTo(shieldHandle, orbitPlate5)
	local orbitPlate6 = makePart(shieldModel, "OrbitPlate6", Vector3.new(0.26, 0.80, 0.80), CFrame.new(-0.38, -0.40, -1.05), astralGold, Enum.Material.Metal)
	weldTo(shieldHandle, orbitPlate6)

	-- 6 Plasma Emitters embedded in Orbital Plates
	local emitter1 = makePart(shieldModel, "Emitter1", Vector3.new(0.30, 0.35, 0.35), CFrame.new(-0.42, 1.40, 0), riftCorePlasma, Enum.Material.Metal)
	weldTo(shieldHandle, emitter1)
	local emitter2 = makePart(shieldModel, "Emitter2", Vector3.new(0.30, 0.35, 0.35), CFrame.new(-0.42, -1.00, 0), riftCorePlasma, Enum.Material.Metal)
	weldTo(shieldHandle, emitter2)
	local emitter3 = makePart(shieldModel, "Emitter3", Vector3.new(0.30, 0.35, 0.35), CFrame.new(-0.42, 0.80, 1.05), riftCorePlasma, Enum.Material.Metal)
	weldTo(shieldHandle, emitter3)
	local emitter4 = makePart(shieldModel, "Emitter4", Vector3.new(0.30, 0.35, 0.35), CFrame.new(-0.42, 0.80, -1.05), riftCorePlasma, Enum.Material.Metal)
	weldTo(shieldHandle, emitter4)
	local emitter5 = makePart(shieldModel, "Emitter5", Vector3.new(0.30, 0.35, 0.35), CFrame.new(-0.42, -0.40, 1.05), riftCorePlasma, Enum.Material.Metal)
	weldTo(shieldHandle, emitter5)
	local emitter6 = makePart(shieldModel, "Emitter6", Vector3.new(0.30, 0.35, 0.35), CFrame.new(-0.42, -0.40, -1.05), riftCorePlasma, Enum.Material.Metal)
	weldTo(shieldHandle, emitter6)

	-- 6 Magnetic Tether Rods anchoring the floating plates
	local tether1 = makePart(shieldModel, "Tether1", Vector3.new(0.24, 0.65, 0.12), CFrame.new(-0.36, 0.80, 0), darkMatter, Enum.Material.Metal)
	weldTo(shieldHandle, tether1)
	local tether2 = makePart(shieldModel, "Tether2", Vector3.new(0.24, 0.65, 0.12), CFrame.new(-0.36, -0.40, 0), darkMatter, Enum.Material.Metal)
	weldTo(shieldHandle, tether2)
	local tether3 = makePart(shieldModel, "Tether3", Vector3.new(0.24, 0.12, 0.65), CFrame.new(-0.36, 0.50, 0.55), darkMatter, Enum.Material.Metal)
	weldTo(shieldHandle, tether3)
	local tether4 = makePart(shieldModel, "Tether4", Vector3.new(0.24, 0.12, 0.65), CFrame.new(-0.36, 0.50, -0.55), darkMatter, Enum.Material.Metal)
	weldTo(shieldHandle, tether4)
	local tether5 = makePart(shieldModel, "Tether5", Vector3.new(0.24, 0.12, 0.65), CFrame.new(-0.36, -0.10, 0.55), darkMatter, Enum.Material.Metal)
	weldTo(shieldHandle, tether5)
	local tether6 = makePart(shieldModel, "Tether6", Vector3.new(0.24, 0.12, 0.65), CFrame.new(-0.36, -0.10, -0.55), darkMatter, Enum.Material.Metal)
	weldTo(shieldHandle, tether6)

	-- Outer Hexagonal Kinetic Boundary Rim
	local rimTop = makePart(shieldModel, "RimTop", Vector3.new(0.28, 0.18, 1.30), CFrame.new(-0.38, 1.85, 0), astralGold, Enum.Material.Metal)
	weldTo(shieldHandle, rimTop)
	local rimBottom = makePart(shieldModel, "RimBottom", Vector3.new(0.28, 0.18, 1.30), CFrame.new(-0.38, -1.45, 0), astralGold, Enum.Material.Metal)
	weldTo(shieldHandle, rimBottom)
	local rimTL = makePart(shieldModel, "RimTL", Vector3.new(0.26, 1.40, 0.16), CFrame.new(-0.38, 1.25, 1.25), astralGold, Enum.Material.Metal)
	weldTo(shieldHandle, rimTL)
	local rimTR = makePart(shieldModel, "RimTR", Vector3.new(0.26, 1.40, 0.16), CFrame.new(-0.38, 1.25, -1.25), astralGold, Enum.Material.Metal)
	weldTo(shieldHandle, rimTR)
	local rimBL = makePart(shieldModel, "RimBL", Vector3.new(0.26, 1.40, 0.16), CFrame.new(-0.38, -0.85, 1.25), astralGold, Enum.Material.Metal)
	weldTo(shieldHandle, rimBL)
	local rimBR = makePart(shieldModel, "RimBR", Vector3.new(0.26, 1.40, 0.16), CFrame.new(-0.38, -0.85, -1.25), astralGold, Enum.Material.Metal)
	weldTo(shieldHandle, rimBR)

	-- Outer Floating Shield Barrier Node Spikes
	local nodeSpike1 = makePart(shieldModel, "NodeSpike1", Vector3.new(0.26, 0.40, 0.22), CFrame.new(-0.40, 2.05, 0), hyperViolet, Enum.Material.Metal)
	weldTo(shieldHandle, nodeSpike1)
	local nodeSpike2 = makePart(shieldModel, "NodeSpike2", Vector3.new(0.26, 0.40, 0.22), CFrame.new(-0.40, -1.65, 0), hyperViolet, Enum.Material.Metal)
	weldTo(shieldHandle, nodeSpike2)
	local nodeSpike3 = makePart(shieldModel, "NodeSpike3", Vector3.new(0.26, 0.22, 0.40), CFrame.new(-0.40, 0.20, 1.65), hyperViolet, Enum.Material.Metal)
	weldTo(shieldHandle, nodeSpike3)
	local nodeSpike4 = makePart(shieldModel, "NodeSpike4", Vector3.new(0.26, 0.22, 0.40), CFrame.new(-0.40, 0.20, -1.65), hyperViolet, Enum.Material.Metal)
	weldTo(shieldHandle, nodeSpike4)
	local coreOrbitShard1 = makePart(shieldModel, "CoreOrbitShard1", Vector3.new(0.28, 0.26, 0.26), CFrame.new(-0.46, 0.65, 0.45), riftCorePlasma, Enum.Material.Glass)
	coreOrbitShard1.Transparency = 0.25
	weldTo(shieldHandle, coreOrbitShard1)
	local coreOrbitShard2 = makePart(shieldModel, "CoreOrbitShard2", Vector3.new(0.28, 0.26, 0.26), CFrame.new(-0.46, 0.65, -0.45), riftCorePlasma, Enum.Material.Glass)
	coreOrbitShard2.Transparency = 0.25
	weldTo(shieldHandle, coreOrbitShard2)
	local coreOrbitShard3 = makePart(shieldModel, "CoreOrbitShard3", Vector3.new(0.28, 0.26, 0.26), CFrame.new(-0.46, -0.25, 0.45), riftCorePlasma, Enum.Material.Glass)
	coreOrbitShard3.Transparency = 0.25
	weldTo(shieldHandle, coreOrbitShard3)
	local coreOrbitShard4 = makePart(shieldModel, "CoreOrbitShard4", Vector3.new(0.28, 0.26, 0.26), CFrame.new(-0.46, -0.25, -0.45), riftCorePlasma, Enum.Material.Glass)
	coreOrbitShard4.Transparency = 0.25
	weldTo(shieldHandle, coreOrbitShard4)

	local armFrameHarness = makePart(shieldModel, "ArmFrameHarness", Vector3.new(0.20, 0.90, 0.36), CFrame.new(-0.16, 0.20, 0), darkMatter, Enum.Material.Metal)
	weldTo(shieldHandle, armFrameHarness)
	local strapTop = makePart(shieldModel, "StrapTop", Vector3.new(0.14, 0.16, 0.48), CFrame.new(-0.10, 0.50, 0), astralGold, Enum.Material.Metal)
	weldTo(shieldHandle, strapTop)
	local strapBot = makePart(shieldModel, "StrapBot", Vector3.new(0.14, 0.16, 0.48), CFrame.new(-0.10, -0.10, 0), astralGold, Enum.Material.Metal)
	weldTo(shieldHandle, strapBot)

	addSocket(shieldHandle, "ShieldMount", Vector3.new(-0.18, 0, 0), Vector3.new(0, 90, 0))
	addSocket(shieldHandle, "VfxShieldCenter", Vector3.new(-0.50, 0.10, 0))

	return model
end


function WeaponModelBuilder.BuildAstralExecutioner(): Model
	local model = Instance.new("Model")
	model.Name = "art_astral_executioner"

	local astralPlatinum = Color3.fromRGB(240, 245, 255)
	local starlightCyan = Color3.fromRGB(110, 235, 255)
	local celestialGold = Color3.fromRGB(250, 215, 85)
	local cosmicMirror = Color3.fromRGB(18, 15, 28)
	local nebulaMagenta = Color3.fromRGB(255, 115, 230)

	-- Astral Starlight Chisel-Tipped Executioner Blade (44 parts)

-- Sword Assembly (44 parts: colossal anime executioner greatsword with stepped serrations and floating cosmic orbits)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.22, 1.60, 0.22)
	handle.CFrame = CFrame.new(0, 0, 0)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = model
	model.PrimaryPart = handle

	local gripCyl = makeCylinder(model, "GripCylinder", 1.50, 0.19, CFrame.new(0, 0, 0), cosmicMirror)
	weldTo(handle, gripCyl)
	local gripWrap1 = makeCylinder(model, "GripWrap1", 0.12, 0.21, CFrame.new(0, -0.50, 0), celestialGold, Enum.Material.Metal)
	weldTo(handle, gripWrap1)
	local gripWrap2 = makeCylinder(model, "GripWrap2", 0.12, 0.21, CFrame.new(0, 0.0, 0), celestialGold, Enum.Material.Metal)
	weldTo(handle, gripWrap2)
	local gripWrap3 = makeCylinder(model, "GripWrap3", 0.12, 0.21, CFrame.new(0, 0.50, 0), celestialGold, Enum.Material.Metal)
	weldTo(handle, gripWrap3)

	local pommelNeck = makeCylinder(model, "PommelNeck", 0.12, 0.26, CFrame.new(0, -0.80, 0), celestialGold, Enum.Material.Metal)
	weldTo(handle, pommelNeck)
	local pommelBall = makeBall(model, "PommelBall", 0.46, CFrame.new(0, -1.02, 0), cosmicMirror, Enum.Material.Metal)
	weldTo(handle, pommelBall)
	local pommelSpike = makePart(model, "PommelSpike", Vector3.new(0.18, 0.28, 0.18), CFrame.new(0, -1.30, 0), celestialGold, Enum.Material.Metal)
	weldTo(handle, pommelSpike)
	local pommelFinial = makeBall(model, "PommelFinial", 0.20, CFrame.new(0, -1.48, 0), starlightCyan, Enum.Material.Neon)
	weldTo(handle, pommelFinial)

	local guardCenter = makePart(model, "GuardCenter", Vector3.new(0.48, 0.26, 0.30), CFrame.new(0, 0.82, 0), cosmicMirror, Enum.Material.Metal)
	weldTo(handle, guardCenter)
	local guardCrest = makePart(model, "GuardCrest", Vector3.new(0.36, 0.36, 0.12), CFrame.new(0, 0.84, 0.16), celestialGold, Enum.Material.Metal)
	weldTo(handle, guardCrest)
	local quillonL = makePart(model, "QuillonL", Vector3.new(0.26, 0.18, 0.68), CFrame.new(0, 0.84, 0.58) * CFrame.Angles(math.rad(12), 0, 0), cosmicMirror, Enum.Material.Metal)
	weldTo(handle, quillonL)
	local quillonR = makePart(model, "QuillonR", Vector3.new(0.26, 0.18, 0.68), CFrame.new(0, 0.84, -0.58) * CFrame.Angles(math.rad(-12), 0, 0), cosmicMirror, Enum.Material.Metal)
	weldTo(handle, quillonR)
	local quillonWingL = makePart(model, "QuillonWingL", Vector3.new(0.16, 0.28, 0.28), CFrame.new(0, 0.94, 0.78), celestialGold, Enum.Material.Metal)
	weldTo(handle, quillonWingL)
	local quillonWingR = makePart(model, "QuillonWingR", Vector3.new(0.16, 0.28, 0.28), CFrame.new(0, 0.94, -0.78), celestialGold, Enum.Material.Metal)
	weldTo(handle, quillonWingR)
	local finialL = makeBall(model, "QuillonFinialL", 0.24, CFrame.new(0, 1.02, 0.98), celestialGold, Enum.Material.Metal)
	weldTo(handle, finialL)
	local finialR = makeBall(model, "QuillonFinialR", 0.24, CFrame.new(0, 1.02, -0.98), celestialGold, Enum.Material.Metal)
	weldTo(handle, finialR)

	local ricasso = makePart(model, "Ricasso", Vector3.new(0.62, 0.85, 0.09), CFrame.new(0, 1.34, 0), astralPlatinum, Enum.Material.Metal)
	weldTo(handle, ricasso)
	local ricassoPlateL = makePart(model, "RicassoPlateL", Vector3.new(0.16, 0.40, 0.08), CFrame.new(0.40, 1.62, 0), celestialGold, Enum.Material.Metal)
	weldTo(handle, ricassoPlateL)
	local ricassoPlateR = makePart(model, "RicassoPlateR", Vector3.new(0.16, 0.40, 0.08), CFrame.new(-0.40, 1.62, 0), celestialGold, Enum.Material.Metal)
	weldTo(handle, ricassoPlateR)

	local bladeFuller = makePart(model, "BladeFuller", Vector3.new(0.20, 4.50, 0.075), CFrame.new(0, 3.90, 0), astralPlatinum, Enum.Material.Metal)
	weldTo(handle, bladeFuller)
	local cosmicCoreLine = makePart(model, "CosmicCoreLine", Vector3.new(0.06, 3.80, 0.08), CFrame.new(0, 3.85, 0), starlightCyan, Enum.Material.Neon)
	weldTo(handle, cosmicCoreLine)

	local edgeFwd1 = makePart(model, "EdgeFwd1", Vector3.new(0.26, 2.25, 0.045), CFrame.new(0.25, 2.80, 0), astralPlatinum, Enum.Material.Metal)
	weldTo(handle, edgeFwd1)
	local edgeFwd2 = makePart(model, "EdgeFwd2", Vector3.new(0.24, 2.20, 0.045), CFrame.new(0.24, 4.95, 0), astralPlatinum, Enum.Material.Metal)
	weldTo(handle, edgeFwd2)
	local edgeBack1 = makePart(model, "EdgeBack1", Vector3.new(0.26, 2.25, 0.045), CFrame.new(-0.25, 2.80, 0), astralPlatinum, Enum.Material.Metal)
	weldTo(handle, edgeBack1)
	local edgeBack2 = makePart(model, "EdgeBack2", Vector3.new(0.24, 2.20, 0.045), CFrame.new(-0.24, 4.95, 0), astralPlatinum, Enum.Material.Metal)
	weldTo(handle, edgeBack2)

	local executionerSpur1 = makePart(model, "ExecutionerSpur1", Vector3.new(0.14, 0.35, 0.05), CFrame.new(0.34, 5.30, 0), celestialGold, Enum.Material.Metal)
	weldTo(handle, executionerSpur1)
	local executionerSpur2 = makePart(model, "ExecutionerSpur2", Vector3.new(0.12, 0.30, 0.05), CFrame.new(0.32, 5.70, 0), celestialGold, Enum.Material.Metal)
	weldTo(handle, executionerSpur2)
	local executionerSpur3 = makePart(model, "ExecutionerSpur3", Vector3.new(0.14, 0.35, 0.05), CFrame.new(-0.34, 5.30, 0), celestialGold, Enum.Material.Metal)
	weldTo(handle, executionerSpur3)
	local executionerSpur4 = makePart(model, "ExecutionerSpur4", Vector3.new(0.12, 0.30, 0.05), CFrame.new(-0.32, 5.70, 0), celestialGold, Enum.Material.Metal)
	weldTo(handle, executionerSpur4)

	local floatingOrbit1 = makePart(model, "FloatingOrbit1", Vector3.new(0.08, 0.35, 0.05), CFrame.new(0.44, 4.40, 0), starlightCyan, Enum.Material.Neon)
	weldTo(handle, floatingOrbit1)
	local floatingOrbit2 = makePart(model, "FloatingOrbit2", Vector3.new(0.08, 0.35, 0.05), CFrame.new(-0.44, 4.40, 0), starlightCyan, Enum.Material.Neon)
	weldTo(handle, floatingOrbit2)
	local floatingOrbit3 = makePart(model, "FloatingOrbit3", Vector3.new(0.08, 0.35, 0.05), CFrame.new(0.40, 3.60, 0), celestialGold, Enum.Material.Metal)
	weldTo(handle, floatingOrbit3)
	local floatingOrbit4 = makePart(model, "FloatingOrbit4", Vector3.new(0.08, 0.35, 0.05), CFrame.new(-0.40, 3.60, 0), celestialGold, Enum.Material.Metal)
	weldTo(handle, floatingOrbit4)

	local tipFwd = makeWedge(model, "TipFwd", Vector3.new(0.045, 0.76, 0.38), CFrame.new(0.19, 6.25, 0) * CFrame.Angles(0, math.rad(-90), 0), astralPlatinum, Enum.Material.Metal)
	weldTo(handle, tipFwd)
	local tipBack = makeWedge(model, "TipBack", Vector3.new(0.045, 0.76, 0.38), CFrame.new(-0.19, 6.25, 0) * CFrame.Angles(0, math.rad(90), 0), astralPlatinum, Enum.Material.Metal)
	weldTo(handle, tipBack)

	addSocket(handle, "Grip", Vector3.new(0, 0, 0), Vector3.new(0, -90, 0))
	addSocket(handle, "Tip", Vector3.new(0, 6.55, 0), Vector3.new(0, 0, 0))
	addSocket(handle, "VfxTip", Vector3.new(0, 6.55, 0))
	addSocket(handle, "VfxBase", Vector3.new(0, 1.15, 0))
	addSocket(handle, "VfxCore", Vector3.new(0, 0.82, 0))

	local shieldModel = Instance.new("Model")
	shieldModel.Name = "OffhandShield"
	shieldModel.Parent = model

	local shieldHandle = makePart(shieldModel, "HandleS", Vector3.new(0.22, 0.70, 0.22), CFrame.new(0, 0, 0), cosmicMirror)
	shieldModel.PrimaryPart = shieldHandle

	-- Monolithic Frame Structure
	local mirrorBacking = makePart(shieldModel, "MirrorBacking", Vector3.new(0.24, 3.20, 1.80), CFrame.new(-0.36, 0.20, 0), astralPlatinum, Enum.Material.Metal)
	weldTo(shieldHandle, mirrorBacking)
	local obsidianMirror = makePart(shieldModel, "ObsidianMirror", Vector3.new(0.26, 2.90, 1.55), CFrame.new(-0.38, 0.20, 0), cosmicMirror, Enum.Material.Glass)
	weldTo(shieldHandle, obsidianMirror)
	local nebulaMirrorFilm = makePart(shieldModel, "NebulaMirrorFilm", Vector3.new(0.28, 2.50, 1.30), CFrame.new(-0.40, 0.20, 0), nebulaMagenta, Enum.Material.Metal)
	weldTo(shieldHandle, nebulaMirrorFilm)
	local starlightCoreSingularity = makePart(shieldModel, "StarlightCoreSingularity", Vector3.new(0.38, 0.45, 0.45), CFrame.new(-0.46, 0.20, 0), starlightCyan, Enum.Material.Neon)
	weldTo(shieldHandle, starlightCoreSingularity)

	-- Astral Platinum & Gold Outer Frame Bevels
	local frameTop = makePart(shieldModel, "FrameTop", Vector3.new(0.32, 0.22, 1.95), CFrame.new(-0.38, 1.85, 0), celestialGold, Enum.Material.Metal)
	weldTo(shieldHandle, frameTop)
	local frameBottom = makePart(shieldModel, "FrameBottom", Vector3.new(0.32, 0.22, 1.95), CFrame.new(-0.38, -1.45, 0), celestialGold, Enum.Material.Metal)
	weldTo(shieldHandle, frameBottom)
	local frameL = makePart(shieldModel, "FrameL", Vector3.new(0.32, 3.50, 0.20), CFrame.new(-0.38, 0.20, 0.98), celestialGold, Enum.Material.Metal)
	weldTo(shieldHandle, frameL)
	local frameR = makePart(shieldModel, "FrameR", Vector3.new(0.32, 3.50, 0.20), CFrame.new(-0.38, 0.20, -0.98), celestialGold, Enum.Material.Metal)
	weldTo(shieldHandle, frameR)

	-- 4 Corner Spire Towers
	local spireTL = makePart(shieldModel, "SpireTL", Vector3.new(0.34, 0.60, 0.34), CFrame.new(-0.38, 1.95, 0.98), astralPlatinum, Enum.Material.Metal)
	weldTo(shieldHandle, spireTL)
	local spireTR = makePart(shieldModel, "SpireTR", Vector3.new(0.34, 0.60, 0.34), CFrame.new(-0.38, 1.95, -0.98), astralPlatinum, Enum.Material.Metal)
	weldTo(shieldHandle, spireTR)
	local spireBL = makePart(shieldModel, "SpireBL", Vector3.new(0.34, 0.60, 0.34), CFrame.new(-0.38, -1.55, 0.98), astralPlatinum, Enum.Material.Metal)
	weldTo(shieldHandle, spireBL)
	local spireBR = makePart(shieldModel, "SpireBR", Vector3.new(0.34, 0.60, 0.34), CFrame.new(-0.38, -1.55, -0.98), astralPlatinum, Enum.Material.Metal)
	weldTo(shieldHandle, spireBR)

	-- 4 Corner Star Gems
	local gemTL = makePart(shieldModel, "GemTL", Vector3.new(0.36, 0.28, 0.28), CFrame.new(-0.42, 2.15, 0.98), starlightCyan, Enum.Material.Glass)
	gemTL.Transparency = 0.25
	weldTo(shieldHandle, gemTL)
	local gemTR = makePart(shieldModel, "GemTR", Vector3.new(0.36, 0.28, 0.28), CFrame.new(-0.42, 2.15, -0.98), starlightCyan, Enum.Material.Glass)
	gemTR.Transparency = 0.25
	weldTo(shieldHandle, gemTR)
	local gemBL = makePart(shieldModel, "GemBL", Vector3.new(0.36, 0.28, 0.28), CFrame.new(-0.42, -1.75, 0.98), nebulaMagenta, Enum.Material.Glass)
	gemBL.Transparency = 0.25
	weldTo(shieldHandle, gemBL)
	local gemBR = makePart(shieldModel, "GemBR", Vector3.new(0.36, 0.28, 0.28), CFrame.new(-0.42, -1.75, -0.98), nebulaMagenta, Enum.Material.Glass)
	gemBR.Transparency = 0.25
	weldTo(shieldHandle, gemBR)

	-- Constellation Star Lattice Across Mirror Face
	local starRaysV = makePart(shieldModel, "StarRaysV", Vector3.new(0.30, 2.60, 0.16), CFrame.new(-0.42, 0.20, 0), celestialGold, Enum.Material.Metal)
	weldTo(shieldHandle, starRaysV)
	local starRaysH = makePart(shieldModel, "StarRaysH", Vector3.new(0.30, 0.16, 1.40), CFrame.new(-0.42, 0.20, 0), celestialGold, Enum.Material.Metal)
	weldTo(shieldHandle, starRaysH)

	-- 8 Floating Constellation Nodes on Shield Face
	local nodeN = makePart(shieldModel, "NodeN", Vector3.new(0.32, 0.26, 0.26), CFrame.new(-0.44, 1.25, 0), starlightCyan, Enum.Material.Metal)
	weldTo(shieldHandle, nodeN)
	local nodeS = makePart(shieldModel, "NodeS", Vector3.new(0.32, 0.26, 0.26), CFrame.new(-0.44, -0.85, 0), starlightCyan, Enum.Material.Metal)
	weldTo(shieldHandle, nodeS)
	local nodeE = makePart(shieldModel, "NodeE", Vector3.new(0.32, 0.26, 0.26), CFrame.new(-0.44, 0.20, 0.65), starlightCyan, Enum.Material.Metal)
	weldTo(shieldHandle, nodeE)
	local nodeW = makePart(shieldModel, "NodeW", Vector3.new(0.32, 0.26, 0.26), CFrame.new(-0.44, 0.20, -0.65), starlightCyan, Enum.Material.Metal)
	weldTo(shieldHandle, nodeW)

	local nodeNE = makePart(shieldModel, "NodeNE", Vector3.new(0.30, 0.22, 0.22), CFrame.new(-0.44, 0.85, 0.50), nebulaMagenta, Enum.Material.Metal)
	weldTo(shieldHandle, nodeNE)
	local nodeNW = makePart(shieldModel, "NodeNW", Vector3.new(0.30, 0.22, 0.22), CFrame.new(-0.44, 0.85, -0.50), nebulaMagenta, Enum.Material.Metal)
	weldTo(shieldHandle, nodeNW)
	local nodeSE = makePart(shieldModel, "NodeSE", Vector3.new(0.30, 0.22, 0.22), CFrame.new(-0.44, -0.45, 0.50), nebulaMagenta, Enum.Material.Metal)
	weldTo(shieldHandle, nodeSE)
	local nodeSW = makePart(shieldModel, "NodeSW", Vector3.new(0.30, 0.22, 0.22), CFrame.new(-0.44, -0.45, -0.50), nebulaMagenta, Enum.Material.Metal)
	weldTo(shieldHandle, nodeSW)

	-- Radial Constellation Struts
	local strutNE = makePart(shieldModel, "StrutNE", Vector3.new(0.28, 0.85, 0.10), CFrame.new(-0.42, 0.65, 0.35), celestialGold, Enum.Material.Metal)
	weldTo(shieldHandle, strutNE)
	local strutNW = makePart(shieldModel, "StrutNW", Vector3.new(0.28, 0.85, 0.10), CFrame.new(-0.42, 0.65, -0.35), celestialGold, Enum.Material.Metal)
	weldTo(shieldHandle, strutNW)
	local strutSE = makePart(shieldModel, "StrutSE", Vector3.new(0.28, 0.85, 0.10), CFrame.new(-0.42, -0.25, 0.35), celestialGold, Enum.Material.Metal)
	weldTo(shieldHandle, strutSE)
	local strutSW = makePart(shieldModel, "StrutSW", Vector3.new(0.28, 0.85, 0.10), CFrame.new(-0.42, -0.25, -0.35), celestialGold, Enum.Material.Metal)
	weldTo(shieldHandle, strutSW)
	local borderGem1 = makePart(shieldModel, "BorderGem1", Vector3.new(0.34, 0.22, 0.22), CFrame.new(-0.40, 1.85, 0.50), celestialGold, Enum.Material.Metal)
	weldTo(shieldHandle, borderGem1)
	local borderGem2 = makePart(shieldModel, "BorderGem2", Vector3.new(0.34, 0.22, 0.22), CFrame.new(-0.40, 1.85, -0.50), celestialGold, Enum.Material.Metal)
	weldTo(shieldHandle, borderGem2)
	local borderGem3 = makePart(shieldModel, "BorderGem3", Vector3.new(0.34, 0.22, 0.22), CFrame.new(-0.40, -1.45, 0.50), celestialGold, Enum.Material.Metal)
	weldTo(shieldHandle, borderGem3)
	local borderGem4 = makePart(shieldModel, "BorderGem4", Vector3.new(0.34, 0.22, 0.22), CFrame.new(-0.40, -1.45, -0.50), celestialGold, Enum.Material.Metal)
	weldTo(shieldHandle, borderGem4)
	local outerAuraLens1 = makePart(shieldModel, "OuterAuraLens1", Vector3.new(0.32, 0.40, 0.20), CFrame.new(-0.42, 0.80, 0.80), starlightCyan, Enum.Material.Glass)
	outerAuraLens1.Transparency = 0.25
	weldTo(shieldHandle, outerAuraLens1)
	local outerAuraLens2 = makePart(shieldModel, "OuterAuraLens2", Vector3.new(0.32, 0.40, 0.20), CFrame.new(-0.42, 0.80, -0.80), starlightCyan, Enum.Material.Glass)
	outerAuraLens2.Transparency = 0.25
	weldTo(shieldHandle, outerAuraLens2)

	-- Arm Mounting Harness
	local armBrace = makePart(shieldModel, "ArmBrace", Vector3.new(0.20, 1.00, 0.38), CFrame.new(-0.16, 0.20, 0), astralPlatinum, Enum.Material.Metal)
	weldTo(shieldHandle, armBrace)
	local strapTop = makePart(shieldModel, "StrapTop", Vector3.new(0.14, 0.16, 0.50), CFrame.new(-0.10, 0.55, 0), celestialGold, Enum.Material.Metal)
	weldTo(shieldHandle, strapTop)
	local strapBot = makePart(shieldModel, "StrapBot", Vector3.new(0.14, 0.16, 0.50), CFrame.new(-0.10, -0.15, 0), celestialGold, Enum.Material.Metal)
	weldTo(shieldHandle, strapBot)

	addSocket(shieldHandle, "ShieldMount", Vector3.new(-0.18, 0, 0), Vector3.new(0, 90, 0))
	addSocket(shieldHandle, "VfxShieldCenter", Vector3.new(-0.48, 0.10, 0))

	return model
end


function WeaponModelBuilder.BuildGenesisWorldbreaker(): Model
	local model = Instance.new("Model")
	model.Name = "art_genesis_worldbreaker"

	local neutroniumDark = Color3.fromRGB(15, 12, 22)
	local eventHorizonVoid = Color3.fromRGB(5, 5, 10)
	local singularityCrimson = Color3.fromRGB(255, 65, 95)
	local genesisCyan = Color3.fromRGB(75, 235, 255)
	local solarGold = Color3.fromRGB(255, 215, 75)
	local gravitationalLensing = Color3.fromRGB(240, 185, 255)

	-- Colossal Primordial Executioner Blade (48 parts)

-- Sword Assembly (47 parts: mythical reality-splitting worldbreaker colossal greatsword)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.24, 1.70, 0.24)
	handle.CFrame = CFrame.new(0, 0, 0)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = model
	model.PrimaryPart = handle

	local gripCyl = makeCylinder(model, "GripCylinder", 1.60, 0.20, CFrame.new(0, 0, 0), eventHorizonVoid)
	weldTo(handle, gripCyl)
	local gripWrap1 = makeCylinder(model, "GripWrap1", 0.12, 0.22, CFrame.new(0, -0.55, 0), solarGold, Enum.Material.Metal)
	weldTo(handle, gripWrap1)
	local gripWrap2 = makeCylinder(model, "GripWrap2", 0.12, 0.22, CFrame.new(0, 0.0, 0), solarGold, Enum.Material.Metal)
	weldTo(handle, gripWrap2)
	local gripWrap3 = makeCylinder(model, "GripWrap3", 0.12, 0.22, CFrame.new(0, 0.55, 0), solarGold, Enum.Material.Metal)
	weldTo(handle, gripWrap3)

	local pommelNeck = makeCylinder(model, "PommelNeck", 0.12, 0.28, CFrame.new(0, -0.85, 0), solarGold, Enum.Material.Metal)
	weldTo(handle, pommelNeck)
	local pommelBall = makeBall(model, "PommelBall", 0.48, CFrame.new(0, -1.08, 0), neutroniumDark, Enum.Material.Metal)
	weldTo(handle, pommelBall)
	local pommelCrown = makePart(model, "PommelCrown", Vector3.new(0.24, 0.26, 0.24), CFrame.new(0, -1.36, 0), solarGold, Enum.Material.Metal)
	weldTo(handle, pommelCrown)
	local pommelFinial = makeBall(model, "PommelFinial", 0.22, CFrame.new(0, -1.54, 0), genesisCyan, Enum.Material.Neon)
	weldTo(handle, pommelFinial)

	local guardCenter = makePart(model, "GuardCenter", Vector3.new(0.52, 0.28, 0.32), CFrame.new(0, 0.88, 0), neutroniumDark, Enum.Material.Metal)
	weldTo(handle, guardCenter)
	local guardSingularity = makeBall(model, "GuardSingularity", 0.26, CFrame.new(0, 0.90, 0.18), genesisCyan, Enum.Material.Neon)
	weldTo(handle, guardSingularity)
	local quillonL = makePart(model, "QuillonL", Vector3.new(0.28, 0.18, 0.72), CFrame.new(0, 0.90, 0.62) * CFrame.Angles(math.rad(14), 0, 0), neutroniumDark, Enum.Material.Metal)
	weldTo(handle, quillonL)
	local quillonR = makePart(model, "QuillonR", Vector3.new(0.28, 0.18, 0.72), CFrame.new(0, 0.90, -0.62) * CFrame.Angles(math.rad(-14), 0, 0), neutroniumDark, Enum.Material.Metal)
	weldTo(handle, quillonR)
	local quillonWingL = makePart(model, "QuillonWingL", Vector3.new(0.18, 0.30, 0.30), CFrame.new(0, 1.00, 0.84), solarGold, Enum.Material.Metal)
	weldTo(handle, quillonWingL)
	local quillonWingR = makePart(model, "QuillonWingR", Vector3.new(0.18, 0.30, 0.30), CFrame.new(0, 1.00, -0.84), solarGold, Enum.Material.Metal)
	weldTo(handle, quillonWingR)
	local finialL = makeBall(model, "QuillonFinialL", 0.26, CFrame.new(0, 1.10, 1.06), solarGold, Enum.Material.Metal)
	weldTo(handle, finialL)
	local finialR = makeBall(model, "QuillonFinialR", 0.26, CFrame.new(0, 1.10, -1.06), solarGold, Enum.Material.Metal)
	weldTo(handle, finialR)

	local ricasso = makePart(model, "Ricasso", Vector3.new(0.66, 0.90, 0.09), CFrame.new(0, 1.42, 0), neutroniumDark, Enum.Material.Metal)
	weldTo(handle, ricasso)
	local ricassoPlateL = makePart(model, "RicassoPlateL", Vector3.new(0.18, 0.45, 0.08), CFrame.new(0.44, 1.72, 0), solarGold, Enum.Material.Metal)
	weldTo(handle, ricassoPlateL)
	local ricassoPlateR = makePart(model, "RicassoPlateR", Vector3.new(0.18, 0.45, 0.08), CFrame.new(-0.44, 1.72, 0), solarGold, Enum.Material.Metal)
	weldTo(handle, ricassoPlateR)

	local bladeFuller = makePart(model, "BladeFuller", Vector3.new(0.22, 4.70, 0.075), CFrame.new(0, 4.05, 0), neutroniumDark, Enum.Material.Metal)
	weldTo(handle, bladeFuller)
	local singularityCore = makePart(model, "SingularityCore", Vector3.new(0.06, 4.00, 0.08), CFrame.new(0, 4.00, 0), genesisCyan, Enum.Material.Neon)
	weldTo(handle, singularityCore)

	local edgeFwd1 = makePart(model, "EdgeFwd1", Vector3.new(0.28, 2.35, 0.045), CFrame.new(0.27, 2.90, 0), solarGold, Enum.Material.Metal)
	weldTo(handle, edgeFwd1)
	local edgeFwd2 = makePart(model, "EdgeFwd2", Vector3.new(0.26, 2.30, 0.045), CFrame.new(0.26, 5.15, 0), solarGold, Enum.Material.Metal)
	weldTo(handle, edgeFwd2)
	local edgeBack1 = makePart(model, "EdgeBack1", Vector3.new(0.28, 2.35, 0.045), CFrame.new(-0.27, 2.90, 0), solarGold, Enum.Material.Metal)
	weldTo(handle, edgeBack1)
	local edgeBack2 = makePart(model, "EdgeBack2", Vector3.new(0.26, 2.30, 0.045), CFrame.new(-0.26, 5.15, 0), solarGold, Enum.Material.Metal)
	weldTo(handle, edgeBack2)

	local serratedFang1 = makePart(model, "SerratedFang1", Vector3.new(0.16, 0.38, 0.05), CFrame.new(0.38, 5.50, 0), solarGold, Enum.Material.Metal)
	weldTo(handle, serratedFang1)
	local serratedFang2 = makePart(model, "SerratedFang2", Vector3.new(0.14, 0.32, 0.05), CFrame.new(0.36, 5.92, 0), solarGold, Enum.Material.Metal)
	weldTo(handle, serratedFang2)
	local serratedFang3 = makePart(model, "SerratedFang3", Vector3.new(0.16, 0.38, 0.05), CFrame.new(-0.38, 5.50, 0), solarGold, Enum.Material.Metal)
	weldTo(handle, serratedFang3)
	local serratedFang4 = makePart(model, "SerratedFang4", Vector3.new(0.14, 0.32, 0.05), CFrame.new(-0.36, 5.92, 0), solarGold, Enum.Material.Metal)
	weldTo(handle, serratedFang4)

	local floatingHalo1 = makePart(model, "FloatingHalo1", Vector3.new(0.08, 0.40, 0.05), CFrame.new(0.48, 4.60, 0), genesisCyan, Enum.Material.Neon)
	weldTo(handle, floatingHalo1)
	local floatingHalo2 = makePart(model, "FloatingHalo2", Vector3.new(0.08, 0.40, 0.05), CFrame.new(-0.48, 4.60, 0), genesisCyan, Enum.Material.Neon)
	weldTo(handle, floatingHalo2)
	local floatingHalo3 = makePart(model, "FloatingHalo3", Vector3.new(0.08, 0.40, 0.05), CFrame.new(0.44, 3.80, 0), solarGold, Enum.Material.Metal)
	weldTo(handle, floatingHalo3)
	local floatingHalo4 = makePart(model, "FloatingHalo4", Vector3.new(0.08, 0.40, 0.05), CFrame.new(-0.44, 3.80, 0), solarGold, Enum.Material.Metal)
	weldTo(handle, floatingHalo4)

	local tipFwd = makeWedge(model, "TipFwd", Vector3.new(0.045, 0.80, 0.40), CFrame.new(0.20, 6.50, 0) * CFrame.Angles(0, math.rad(-90), 0), solarGold, Enum.Material.Metal)
	weldTo(handle, tipFwd)
	local tipBack = makeWedge(model, "TipBack", Vector3.new(0.045, 0.80, 0.40), CFrame.new(-0.20, 6.50, 0) * CFrame.Angles(0, math.rad(90), 0), solarGold, Enum.Material.Metal)
	weldTo(handle, tipBack)

	addSocket(handle, "Grip", Vector3.new(0, 0, 0), Vector3.new(0, -90, 0))
	addSocket(handle, "Tip", Vector3.new(0, 6.85, 0), Vector3.new(0, 0, 0))
	addSocket(handle, "VfxTip", Vector3.new(0, 6.85, 0))
	addSocket(handle, "VfxBase", Vector3.new(0, 1.20, 0))
	addSocket(handle, "VfxCore", Vector3.new(0, 0.88, 0))

	local shieldModel = Instance.new("Model")
	shieldModel.Name = "OffhandShield"
	shieldModel.Parent = model

	local shieldHandle = makePart(shieldModel, "HandleS", Vector3.new(0.24, 0.75, 0.24), CFrame.new(0, 0, 0), eventHorizonVoid)
	shieldModel.PrimaryPart = shieldHandle

	-- Collapsed Star Monolithic Bastion Core
	local bastionBacking = makePart(shieldModel, "BastionBacking", Vector3.new(0.26, 3.40, 2.00), CFrame.new(-0.36, 0.20, 0), neutroniumDark, Enum.Material.Metal)
	weldTo(shieldHandle, bastionBacking)
	local eventHorizonShield = makePart(shieldModel, "EventHorizonShield", Vector3.new(0.28, 3.00, 1.70), CFrame.new(-0.38, 0.20, 0), eventHorizonVoid, Enum.Material.Glass)
	weldTo(shieldHandle, eventHorizonShield)
	local gravitationalLensingRing = makePart(shieldModel, "GravitationalLensingRing", Vector3.new(0.32, 2.60, 1.40), CFrame.new(-0.40, 0.20, 0), gravitationalLensing, Enum.Material.Glass)
	gravitationalLensingRing.Transparency = 0.35
	weldTo(shieldHandle, gravitationalLensingRing)
	local collapsedStarCore = makePart(shieldModel, "CollapsedStarCore", Vector3.new(0.48, 1.00, 1.00), CFrame.new(-0.48, 0.20, 0), singularityCrimson, Enum.Material.Metal)
	weldTo(shieldHandle, collapsedStarCore)
	local protoStarBeacon = makePart(shieldModel, "ProtoStarBeacon", Vector3.new(0.54, 0.42, 0.42), CFrame.new(-0.52, 0.20, 0), genesisCyan, Enum.Material.Neon)
	weldTo(shieldHandle, protoStarBeacon)

	-- Solar Gold Rim & Heavy Neutronium Bastion Frames
	local rimTop = makePart(shieldModel, "RimTop", Vector3.new(0.34, 0.24, 2.10), CFrame.new(-0.40, 1.95, 0), solarGold, Enum.Material.Metal)
	weldTo(shieldHandle, rimTop)
	local rimBottom = makePart(shieldModel, "RimBottom", Vector3.new(0.34, 0.24, 2.10), CFrame.new(-0.40, -1.55, 0), solarGold, Enum.Material.Metal)
	weldTo(shieldHandle, rimBottom)
	local rimL = makePart(shieldModel, "RimL", Vector3.new(0.34, 3.70, 0.22), CFrame.new(-0.40, 0.20, 1.08), solarGold, Enum.Material.Metal)
	weldTo(shieldHandle, rimL)
	local rimR = makePart(shieldModel, "RimR", Vector3.new(0.34, 3.70, 0.22), CFrame.new(-0.40, 0.20, -1.08), solarGold, Enum.Material.Metal)
	weldTo(shieldHandle, rimR)

	-- 4 Bastion Fortress Towers
	local bastionTowerTL = makePart(shieldModel, "BastionTowerTL", Vector3.new(0.36, 0.65, 0.36), CFrame.new(-0.40, 2.05, 1.08), neutroniumDark, Enum.Material.Metal)
	weldTo(shieldHandle, bastionTowerTL)
	local bastionTowerTR = makePart(shieldModel, "BastionTowerTR", Vector3.new(0.36, 0.65, 0.36), CFrame.new(-0.40, 2.05, -1.08), neutroniumDark, Enum.Material.Metal)
	weldTo(shieldHandle, bastionTowerTR)
	local bastionTowerBL = makePart(shieldModel, "BastionTowerBL", Vector3.new(0.36, 0.65, 0.36), CFrame.new(-0.40, -1.65, 1.08), neutroniumDark, Enum.Material.Metal)
	weldTo(shieldHandle, bastionTowerBL)
	local bastionTowerBR = makePart(shieldModel, "BastionTowerBR", Vector3.new(0.36, 0.65, 0.36), CFrame.new(-0.40, -1.65, -1.08), neutroniumDark, Enum.Material.Metal)
	weldTo(shieldHandle, bastionTowerBR)

	-- 4 Singularity Emitters in Towers
	local singEmitterTL = makePart(shieldModel, "SingEmitterTL", Vector3.new(0.38, 0.30, 0.30), CFrame.new(-0.44, 2.25, 1.08), genesisCyan, Enum.Material.Metal)
	weldTo(shieldHandle, singEmitterTL)
	local singEmitterTR = makePart(shieldModel, "SingEmitterTR", Vector3.new(0.38, 0.30, 0.30), CFrame.new(-0.44, 2.25, -1.08), genesisCyan, Enum.Material.Metal)
	weldTo(shieldHandle, singEmitterTR)
	local singEmitterBL = makePart(shieldModel, "SingEmitterBL", Vector3.new(0.38, 0.30, 0.30), CFrame.new(-0.44, -1.85, 1.08), singularityCrimson, Enum.Material.Metal)
	weldTo(shieldHandle, singEmitterBL)
	local singEmitterBR = makePart(shieldModel, "SingEmitterBR", Vector3.new(0.38, 0.30, 0.30), CFrame.new(-0.44, -1.85, -1.08), singularityCrimson, Enum.Material.Metal)
	weldTo(shieldHandle, singEmitterBR)

	-- Gravitational Accretion Waveguides Across Face
	local accretionPillarV = makePart(shieldModel, "AccretionPillarV", Vector3.new(0.32, 2.80, 0.18), CFrame.new(-0.44, 0.20, 0), solarGold, Enum.Material.Metal)
	weldTo(shieldHandle, accretionPillarV)
	local accretionPillarH = makePart(shieldModel, "AccretionPillarH", Vector3.new(0.32, 0.18, 1.60), CFrame.new(-0.44, 0.20, 0), solarGold, Enum.Material.Metal)
	weldTo(shieldHandle, accretionPillarH)

	-- 8 Orbiting Lensing Nodes on Shield Face
	local lensN = makePart(shieldModel, "LensN", Vector3.new(0.34, 0.28, 0.28), CFrame.new(-0.46, 1.35, 0), genesisCyan, Enum.Material.Glass)
	lensN.Transparency = 0.25
	weldTo(shieldHandle, lensN)
	local lensS = makePart(shieldModel, "LensS", Vector3.new(0.34, 0.28, 0.28), CFrame.new(-0.46, -0.95, 0), genesisCyan, Enum.Material.Glass)
	lensS.Transparency = 0.25
	weldTo(shieldHandle, lensS)
	local lensE = makePart(shieldModel, "LensE", Vector3.new(0.34, 0.28, 0.28), CFrame.new(-0.46, 0.20, 0.75), genesisCyan, Enum.Material.Glass)
	lensE.Transparency = 0.25
	weldTo(shieldHandle, lensE)
	local lensW = makePart(shieldModel, "LensW", Vector3.new(0.34, 0.28, 0.28), CFrame.new(-0.46, 0.20, -0.75), genesisCyan, Enum.Material.Glass)
	lensW.Transparency = 0.25
	weldTo(shieldHandle, lensW)

	local lensNE = makePart(shieldModel, "LensNE", Vector3.new(0.32, 0.24, 0.24), CFrame.new(-0.46, 0.95, 0.55), singularityCrimson, Enum.Material.Glass)
	lensNE.Transparency = 0.25
	weldTo(shieldHandle, lensNE)
	local lensNW = makePart(shieldModel, "LensNW", Vector3.new(0.32, 0.24, 0.24), CFrame.new(-0.46, 0.95, -0.55), singularityCrimson, Enum.Material.Glass)
	lensNW.Transparency = 0.25
	weldTo(shieldHandle, lensNW)
	local lensSE = makePart(shieldModel, "LensSE", Vector3.new(0.32, 0.24, 0.24), CFrame.new(-0.46, -0.55, 0.55), singularityCrimson, Enum.Material.Glass)
	lensSE.Transparency = 0.25
	weldTo(shieldHandle, lensSE)
	local lensSW = makePart(shieldModel, "LensSW", Vector3.new(0.32, 0.24, 0.24), CFrame.new(-0.46, -0.55, -0.55), singularityCrimson, Enum.Material.Glass)
	lensSW.Transparency = 0.25
	weldTo(shieldHandle, lensSW)

	-- Diagonal Seismic Shock Braces
	local shockBraceNE = makePart(shieldModel, "ShockBraceNE", Vector3.new(0.30, 0.90, 0.12), CFrame.new(-0.44, 0.70, 0.40), solarGold, Enum.Material.Metal)
	weldTo(shieldHandle, shockBraceNE)
	local shockBraceNW = makePart(shieldModel, "ShockBraceNW", Vector3.new(0.30, 0.90, 0.12), CFrame.new(-0.44, 0.70, -0.40), solarGold, Enum.Material.Metal)
	weldTo(shieldHandle, shockBraceNW)
	local shockBraceSE = makePart(shieldModel, "ShockBraceSE", Vector3.new(0.30, 0.90, 0.12), CFrame.new(-0.44, -0.30, 0.40), solarGold, Enum.Material.Metal)
	weldTo(shieldHandle, shockBraceSE)
	local shockBraceSW = makePart(shieldModel, "ShockBraceSW", Vector3.new(0.30, 0.90, 0.12), CFrame.new(-0.44, -0.30, -0.40), solarGold, Enum.Material.Metal)
	weldTo(shieldHandle, shockBraceSW)

	-- Radial Event Horizon Rim Flanges
	local rimFlangeTop = makePart(shieldModel, "RimFlangeTop", Vector3.new(0.36, 0.20, 0.80), CFrame.new(-0.42, 2.10, 0), gravitationalLensing, Enum.Material.Glass)
	rimFlangeTop.Transparency = 0.25
	weldTo(shieldHandle, rimFlangeTop)
	local rimFlangeBot = makePart(shieldModel, "RimFlangeBot", Vector3.new(0.36, 0.20, 0.80), CFrame.new(-0.42, -1.70, 0), gravitationalLensing, Enum.Material.Glass)
	rimFlangeBot.Transparency = 0.25
	weldTo(shieldHandle, rimFlangeBot)
	local realityTearL1 = makePart(shieldModel, "RealityTearL1", Vector3.new(0.34, 0.45, 0.22), CFrame.new(-0.46, 1.25, 0.90), singularityCrimson, Enum.Material.Glass)
	realityTearL1.Transparency = 0.25
	weldTo(shieldHandle, realityTearL1)
	local realityTearR1 = makePart(shieldModel, "RealityTearR1", Vector3.new(0.34, 0.45, 0.22), CFrame.new(-0.46, 1.25, -0.90), singularityCrimson, Enum.Material.Glass)
	realityTearR1.Transparency = 0.25
	weldTo(shieldHandle, realityTearR1)
	local realityTearL2 = makePart(shieldModel, "RealityTearL2", Vector3.new(0.34, 0.45, 0.22), CFrame.new(-0.46, -0.85, 0.90), singularityCrimson, Enum.Material.Glass)
	realityTearL2.Transparency = 0.25
	weldTo(shieldHandle, realityTearL2)
	local realityTearR2 = makePart(shieldModel, "RealityTearR2", Vector3.new(0.34, 0.45, 0.22), CFrame.new(-0.46, -0.85, -0.90), singularityCrimson, Enum.Material.Glass)
	realityTearR2.Transparency = 0.25
	weldTo(shieldHandle, realityTearR2)
	local singularityCoronaLensL = makePart(shieldModel, "SingularityCoronaLensL", Vector3.new(0.36, 0.24, 0.45), CFrame.new(-0.46, 0.20, 1.25), genesisCyan, Enum.Material.Glass)
	singularityCoronaLensL.Transparency = 0.25
	weldTo(shieldHandle, singularityCoronaLensL)
	local singularityCoronaLensR = makePart(shieldModel, "SingularityCoronaLensR", Vector3.new(0.36, 0.24, 0.45), CFrame.new(-0.46, 0.20, -1.25), genesisCyan, Enum.Material.Glass)
	singularityCoronaLensR.Transparency = 0.25
	weldTo(shieldHandle, singularityCoronaLensR)

	-- Arm Mounting Harness
	local armBrace = makePart(shieldModel, "ArmBrace", Vector3.new(0.22, 1.10, 0.40), CFrame.new(-0.16, 0.20, 0), neutroniumDark, Enum.Material.Metal)
	weldTo(shieldHandle, armBrace)
	local strapTop = makePart(shieldModel, "StrapTop", Vector3.new(0.14, 0.18, 0.52), CFrame.new(-0.10, 0.60, 0), solarGold, Enum.Material.Metal)
	weldTo(shieldHandle, strapTop)
	local strapBot = makePart(shieldModel, "StrapBot", Vector3.new(0.14, 0.18, 0.52), CFrame.new(-0.10, -0.20, 0), solarGold, Enum.Material.Metal)
	weldTo(shieldHandle, strapBot)

	addSocket(shieldHandle, "ShieldMount", Vector3.new(-0.18, 0, 0), Vector3.new(0, 90, 0))
	addSocket(shieldHandle, "VfxShieldCenter", Vector3.new(-0.54, 0.10, 0))

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
	elseif weaponAssetId == "art_runic_longsword" or weaponAssetId == "weapon_runic_longsword" then
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

	-- Miner Axes (Batch 4) Styling Hook
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
	if rarityIndex and rarityIndex >= 5 then
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
		local p = Instance.new("MeshPart")
		p.Name = pInfo.Name
		pcall(function()
			p.MeshId = pInfo.MeshId
		end)
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
-- MINER AXES (Batch 4) - 14 Modular 3D Pickaxes, Battleaxes & Cleavers
-- ============================================================================
type AxePartData = {
	Name: string,
	MeshId: string,
	Size: Vector3,
	Offset: Vector3,
	Mat: Enum.Material,
	Color: Color3,
}

type AxeMeshData = {
	Parts: { AxePartData },
	GripPos: Vector3,
	OffhandGripPos: Vector3,
	TipPos: Vector3,
	BasePos: Vector3,
	CorePos: Vector3,
}

local AXE_MESH_DATA: { [string]: AxeMeshData } = {
	art_miner_pickaxe = {
		GripPos = Vector3.new(0.0000, 0.0000, -0.9000),
		OffhandGripPos = Vector3.new(0.0000, 0.0000, 0.2000),
		TipPos = Vector3.new(-1.1400, 0.0000, 1.5340),
		BasePos = Vector3.new(-1.1400, 0.0000, 0.7960),
		CorePos = Vector3.new(-0.3420, 0.0000, 1.1650),
		Parts = {
			{ Name = "BackSpike", MeshId = "rbxassetid://94836296854862", Size = Vector3.new(0.9447, 0.2552, 0.3937), Offset = Vector3.new(0.6123, 0.0000, 1.1058), Mat = Enum.Material.Metal, Color = Color3.fromRGB(130, 135, 145) },
			{ Name = "Blade", MeshId = "rbxassetid://92737992313603", Size = Vector3.new(0.9600, 0.2200, 0.7800), Offset = Vector3.new(-0.6200, 0.0000, 1.1650), Mat = Enum.Material.Metal, Color = Color3.fromRGB(145, 150, 160) },
			{ Name = "BladeEdge", MeshId = "rbxassetid://102129404384623", Size = Vector3.new(0.0800, 0.0500, 0.8200), Offset = Vector3.new(-1.1400, 0.0000, 1.1650), Mat = Enum.Material.Metal, Color = Color3.fromRGB(205, 210, 220) },
			{ Name = "Handle", MeshId = "rbxassetid://140551721555968", Size = Vector3.new(0.2160, 0.2106, 2.7500), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Wood, Color = Color3.fromRGB(115, 85, 55) },
			{ Name = "HeadCollar", MeshId = "rbxassetid://131577315646852", Size = Vector3.new(0.3500, 0.3500, 0.4600), Offset = Vector3.new(0.0000, 0.0000, 1.1850), Mat = Enum.Material.Metal, Color = Color3.fromRGB(110, 115, 125) },
			{ Name = "Pommel", MeshId = "rbxassetid://82493519554699", Size = Vector3.new(0.2500, 0.2437, 0.1720), Offset = Vector3.new(0.0000, 0.0000, -1.4410), Mat = Enum.Material.Metal, Color = Color3.fromRGB(95, 100, 108) },
		},
	},
	art_heavy_hewing_axe = {
		GripPos = Vector3.new(0.0000, 0.0000, -0.9000),
		OffhandGripPos = Vector3.new(0.0000, 0.0000, 0.2000),
		TipPos = Vector3.new(-1.2975, 0.0000, 1.9000),
		BasePos = Vector3.new(-1.2975, 0.0000, 0.3700),
		CorePos = Vector3.new(-0.3893, 0.0000, 1.1350),
		Parts = {
			{ Name = "BackSpike", MeshId = "rbxassetid://90228869052544", Size = Vector3.new(0.5400, 0.4000, 0.4200), Offset = Vector3.new(0.4275, 0.0000, 1.3250), Mat = Enum.Material.Metal, Color = Color3.fromRGB(95, 100, 110) },
			{ Name = "Blade", MeshId = "rbxassetid://137345086194686", Size = Vector3.new(1.0900, 0.2600, 1.6000), Offset = Vector3.new(-0.6975, 0.0000, 1.1450), Mat = Enum.Material.Metal, Color = Color3.fromRGB(135, 140, 150) },
			{ Name = "BladeEdge", MeshId = "rbxassetid://104405564702305", Size = Vector3.new(0.1100, 0.0500, 1.7000), Offset = Vector3.new(-1.2975, 0.0000, 1.1350), Mat = Enum.Material.Metal, Color = Color3.fromRGB(215, 220, 230) },
			{ Name = "Handle", MeshId = "rbxassetid://133026283942673", Size = Vector3.new(0.2749, 0.2760, 2.4595), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Wood, Color = Color3.fromRGB(90, 65, 42) },
			{ Name = "HeadCollar", MeshId = "rbxassetid://78054603575061", Size = Vector3.new(0.3800, 0.4000, 0.4800), Offset = Vector3.new(-0.0025, 0.0000, 1.3450), Mat = Enum.Material.Metal, Color = Color3.fromRGB(100, 105, 115) },
			{ Name = "Pommel", MeshId = "rbxassetid://88136172246793", Size = Vector3.new(0.3400, 0.4200, 0.1800), Offset = Vector3.new(-0.0425, 0.0000, -1.3050), Mat = Enum.Material.Metal, Color = Color3.fromRGB(80, 85, 92) },
		},
	},
	art_canyon_splitter = {
		GripPos = Vector3.new(0.0000, 0.0000, -0.9000),
		OffhandGripPos = Vector3.new(0.0000, 0.0000, 0.2000),
		TipPos = Vector3.new(-1.3300, 0.0000, 1.7440),
		BasePos = Vector3.new(-1.3300, 0.0000, 0.4660),
		CorePos = Vector3.new(-0.3990, 0.0000, 1.1050),
		Parts = {
			{ Name = "BackSpike", MeshId = "rbxassetid://123646299894909", Size = Vector3.new(0.5600, 0.3360, 0.3360), Offset = Vector3.new(0.4400, 0.0000, 1.1750), Mat = Enum.Material.Metal, Color = Color3.fromRGB(135, 140, 150) },
			{ Name = "Blade", MeshId = "rbxassetid://129529480268500", Size = Vector3.new(1.1200, 0.2800, 1.3200), Offset = Vector3.new(-0.7200, 0.0000, 1.1150), Mat = Enum.Material.Metal, Color = Color3.fromRGB(120, 125, 135) },
			{ Name = "BladeEdge", MeshId = "rbxassetid://121729671658855", Size = Vector3.new(0.1000, 0.0500, 1.4200), Offset = Vector3.new(-1.3300, 0.0000, 1.1050), Mat = Enum.Material.Metal, Color = Color3.fromRGB(195, 200, 215) },
			{ Name = "Handle", MeshId = "rbxassetid://116325093459870", Size = Vector3.new(0.2912, 0.2912, 2.7500), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Slate, Color = Color3.fromRGB(82, 80, 88) },
			{ Name = "HeadCollar", MeshId = "rbxassetid://117439509760474", Size = Vector3.new(0.5200, 0.4032, 0.9547), Offset = Vector3.new(0.0000, 0.0000, 1.1950), Mat = Enum.Material.Metal, Color = Color3.fromRGB(180, 135, 75) },
			{ Name = "Pommel", MeshId = "rbxassetid://126680098402040", Size = Vector3.new(0.3584, 0.3584, 0.3300), Offset = Vector3.new(0.0000, 0.0000, -1.5300), Mat = Enum.Material.Metal, Color = Color3.fromRGB(165, 120, 65) },
			{ Name = "RuneInlay", MeshId = "rbxassetid://79000887825740", Size = Vector3.new(1.4489, 0.4153, 0.6257), Offset = Vector3.new(-0.1480, 0.0000, 1.4573), Mat = Enum.Material.Neon, Color = Color3.fromRGB(185, 105, 255) },
		},
	},
	art_quakestone_greataxe = {
		GripPos = Vector3.new(0.0000, 0.0000, -0.9000),
		OffhandGripPos = Vector3.new(0.0000, 0.0000, 0.2000),
		TipPos = Vector3.new(-1.4100, 0.0000, 1.8160),
		BasePos = Vector3.new(-1.4100, 0.0000, 0.3040),
		CorePos = Vector3.new(-0.4230, 0.0000, 1.0600),
		Parts = {
			{ Name = "BackSpike", MeshId = "rbxassetid://122705498692520", Size = Vector3.new(0.6600, 0.2954, 0.3000), Offset = Vector3.new(0.4900, 0.0000, 1.1800), Mat = Enum.Material.Metal, Color = Color3.fromRGB(125, 130, 140) },
			{ Name = "Blade", MeshId = "rbxassetid://81271720134153", Size = Vector3.new(1.2000, 0.2800, 1.6200), Offset = Vector3.new(-0.7600, 0.0000, 1.0500), Mat = Enum.Material.Metal, Color = Color3.fromRGB(140, 145, 155) },
			{ Name = "BladeEdge", MeshId = "rbxassetid://123122246356785", Size = Vector3.new(0.1000, 0.0500, 1.6800), Offset = Vector3.new(-1.4100, 0.0000, 1.0600), Mat = Enum.Material.Metal, Color = Color3.fromRGB(210, 215, 225) },
			{ Name = "Handle", MeshId = "rbxassetid://98539484149239", Size = Vector3.new(0.3155, 0.2732, 2.8000), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(190, 150, 65) },
			{ Name = "HeadCollar", MeshId = "rbxassetid://106148442053393", Size = Vector3.new(0.5400, 0.3817, 1.0000), Offset = Vector3.new(0.0000, 0.0000, 1.2100), Mat = Enum.Material.Metal, Color = Color3.fromRGB(115, 118, 125) },
			{ Name = "Pommel", MeshId = "rbxassetid://122782964219360", Size = Vector3.new(0.3944, 0.3416, 0.3400), Offset = Vector3.new(0.0000, 0.0000, -1.5600), Mat = Enum.Material.Metal, Color = Color3.fromRGB(170, 130, 50) },
			{ Name = "RuneInlay", MeshId = "rbxassetid://78101601037032", Size = Vector3.new(0.7000, 0.3600, 0.8000), Offset = Vector3.new(-0.8000, 0.0000, 0.9800), Mat = Enum.Material.Neon, Color = Color3.fromRGB(245, 205, 90) },
		},
	},
	art_battleaxe_cleaver = {
		GripPos = Vector3.new(0.0000, 0.0000, -0.9000),
		OffhandGripPos = Vector3.new(0.0000, 0.0000, 0.2000),
		TipPos = Vector3.new(-1.3900, 0.0000, 1.8590),
		BasePos = Vector3.new(-1.3900, 0.0000, 0.4010),
		CorePos = Vector3.new(-0.4170, 0.0000, 1.1300),
		Parts = {
			{ Name = "BackSpike", MeshId = "rbxassetid://83629336206756", Size = Vector3.new(1.2800, 0.2800, 1.6200), Offset = Vector3.new(0.8000, 0.0000, 1.1300), Mat = Enum.Material.Metal, Color = Color3.fromRGB(120, 125, 138) },
			{ Name = "Blade", MeshId = "rbxassetid://108383883423975", Size = Vector3.new(1.1800, 0.2800, 1.5400), Offset = Vector3.new(-0.7500, 0.0000, 1.1300), Mat = Enum.Material.Metal, Color = Color3.fromRGB(110, 115, 128) },
			{ Name = "BladeEdge", MeshId = "rbxassetid://99596637826974", Size = Vector3.new(0.1000, 0.0440, 1.6200), Offset = Vector3.new(-1.3900, 0.0000, 1.1300), Mat = Enum.Material.Metal, Color = Color3.fromRGB(215, 222, 235) },
			{ Name = "Handle", MeshId = "rbxassetid://93446786622418", Size = Vector3.new(0.2640, 0.2640, 2.8000), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(65, 70, 78) },
			{ Name = "HeadCollar", MeshId = "rbxassetid://135675088482295", Size = Vector3.new(0.3600, 0.6000, 0.6000), Offset = Vector3.new(0.0000, 0.0000, 1.1800), Mat = Enum.Material.Metal, Color = Color3.fromRGB(175, 125, 45) },
			{ Name = "Pommel", MeshId = "rbxassetid://80129153720203", Size = Vector3.new(0.3400, 0.3151, 0.4088), Offset = Vector3.new(0.0000, 0.0000, -1.5356), Mat = Enum.Material.Metal, Color = Color3.fromRGB(195, 145, 60) },
			{ Name = "RuneInlay", MeshId = "rbxassetid://99693544038289", Size = Vector3.new(0.3600, 0.5000, 0.3600), Offset = Vector3.new(0.0000, 0.0000, 1.1800), Mat = Enum.Material.Neon, Color = Color3.fromRGB(60, 210, 255) },
		},
	},
	art_iron_juggernaut_cleaver = {
		GripPos = Vector3.new(0.0000, 0.0000, -0.9000),
		OffhandGripPos = Vector3.new(0.0000, 0.0000, 0.2000),
		TipPos = Vector3.new(-1.4600, 0.0000, 1.6110),
		BasePos = Vector3.new(-1.4600, 0.0000, 0.7290),
		CorePos = Vector3.new(-0.4380, 0.0000, 1.1700),
		Parts = {
			{ Name = "BackSpike", MeshId = "rbxassetid://115411069374772", Size = Vector3.new(2.0300, 0.4600, 0.7300), Offset = Vector3.new(-0.0750, 0.0000, 1.1550), Mat = Enum.Material.Metal, Color = Color3.fromRGB(85, 88, 96) },
			{ Name = "Blade", MeshId = "rbxassetid://115167154627225", Size = Vector3.new(1.2400, 0.3200, 0.9400), Offset = Vector3.new(-0.8000, 0.0000, 1.1700), Mat = Enum.Material.Metal, Color = Color3.fromRGB(125, 130, 140) },
			{ Name = "BladeEdge", MeshId = "rbxassetid://127033198284534", Size = Vector3.new(0.0800, 0.0600, 0.9800), Offset = Vector3.new(-1.4600, 0.0000, 1.1700), Mat = Enum.Material.Metal, Color = Color3.fromRGB(200, 205, 218) },
			{ Name = "Handle", MeshId = "rbxassetid://139597811398589", Size = Vector3.new(0.3251, 0.3251, 2.8000), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(55, 58, 64) },
			{ Name = "HeadCollar", MeshId = "rbxassetid://133666425497749", Size = Vector3.new(0.4600, 0.6300, 0.6300), Offset = Vector3.new(0.0000, 0.0000, 1.1800), Mat = Enum.Material.Metal, Color = Color3.fromRGB(90, 94, 102) },
			{ Name = "Pommel", MeshId = "rbxassetid://106175253766399", Size = Vector3.new(0.3600, 0.3600, 0.3950), Offset = Vector3.new(0.0000, 0.0000, -1.5425), Mat = Enum.Material.Metal, Color = Color3.fromRGB(75, 78, 86) },
			{ Name = "RuneInlay", MeshId = "rbxassetid://92383796799269", Size = Vector3.new(1.0850, 0.6100, 0.1700), Offset = Vector3.new(-0.4575, 0.0000, 1.1800), Mat = Enum.Material.Neon, Color = Color3.fromRGB(255, 140, 30) },
		},
	},
	art_magma_behemoth = {
		GripPos = Vector3.new(0.0000, 0.0000, -0.9000),
		OffhandGripPos = Vector3.new(0.0000, 0.0000, 0.2000),
		TipPos = Vector3.new(-1.4700, 0.0000, 1.8490),
		BasePos = Vector3.new(-1.4700, 0.0000, 0.3910),
		CorePos = Vector3.new(-0.4410, 0.0000, 1.1200),
		Parts = {
			{ Name = "BackSpike", MeshId = "rbxassetid://117829913219561", Size = Vector3.new(0.9995, 0.2600, 0.7277), Offset = Vector3.new(0.6507, 0.0000, 1.3740), Mat = Enum.Material.Basalt, Color = Color3.fromRGB(35, 32, 40) },
			{ Name = "Blade", MeshId = "rbxassetid://84576415241066", Size = Vector3.new(1.2400, 0.3200, 1.5400), Offset = Vector3.new(-0.8000, 0.0000, 1.1200), Mat = Enum.Material.Basalt, Color = Color3.fromRGB(48, 44, 52) },
			{ Name = "BladeEdge", MeshId = "rbxassetid://110865577034071", Size = Vector3.new(0.1000, 0.0500, 1.6200), Offset = Vector3.new(-1.4700, 0.0000, 1.1200), Mat = Enum.Material.Metal, Color = Color3.fromRGB(90, 75, 85) },
			{ Name = "Handle", MeshId = "rbxassetid://113396116741488", Size = Vector3.new(0.2900, 0.2900, 2.8200), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Basalt, Color = Color3.fromRGB(40, 38, 44) },
			{ Name = "HeadCollar", MeshId = "rbxassetid://90004532153240", Size = Vector3.new(0.6400, 0.4400, 0.6400), Offset = Vector3.new(0.0000, 0.0000, 1.1700), Mat = Enum.Material.Metal, Color = Color3.fromRGB(70, 50, 50) },
			{ Name = "Pommel", MeshId = "rbxassetid://114708277522959", Size = Vector3.new(0.4438, 0.4165, 0.4243), Offset = Vector3.new(0.0000, 0.0000, -1.5578), Mat = Enum.Material.Slate, Color = Color3.fromRGB(30, 28, 35) },
			{ Name = "RuneInlay", MeshId = "rbxassetid://130771680307739", Size = Vector3.new(1.9600, 0.4072, 0.8400), Offset = Vector3.new(-0.2750, 0.0000, 1.0850), Mat = Enum.Material.Neon, Color = Color3.fromRGB(255, 70, 15) },
		},
	},
	art_obsidian_hell_splitter = {
		GripPos = Vector3.new(0.0000, 0.0000, -0.9000),
		OffhandGripPos = Vector3.new(0.0000, 0.0000, 0.2000),
		TipPos = Vector3.new(-1.5100, 0.0000, 1.9220),
		BasePos = Vector3.new(-1.5100, 0.0000, 0.3380),
		CorePos = Vector3.new(-0.4530, 0.0000, 1.1300),
		Parts = {
			{ Name = "BackSpike", MeshId = "rbxassetid://99053279233826", Size = Vector3.new(1.3800, 0.3000, 1.7600), Offset = Vector3.new(0.8700, 0.0000, 1.1300), Mat = Enum.Material.Metal, Color = Color3.fromRGB(35, 30, 38) },
			{ Name = "Blade", MeshId = "rbxassetid://82509003451629", Size = Vector3.new(1.2800, 0.3000, 1.6800), Offset = Vector3.new(-0.8200, 0.0000, 1.1300), Mat = Enum.Material.Glass, Color = Color3.fromRGB(30, 28, 36) },
			{ Name = "BladeEdge", MeshId = "rbxassetid://86291810162458", Size = Vector3.new(0.1000, 0.0400, 1.7600), Offset = Vector3.new(-1.5100, 0.0000, 1.1300), Mat = Enum.Material.Glass, Color = Color3.fromRGB(150, 40, 45) },
			{ Name = "Handle", MeshId = "rbxassetid://110696513696634", Size = Vector3.new(0.2845, 0.2845, 2.8200), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(45, 40, 48) },
			{ Name = "HeadCollar", MeshId = "rbxassetid://124506145395745", Size = Vector3.new(0.4600, 0.6700, 0.6750), Offset = Vector3.new(0.0000, 0.0000, 1.1725), Mat = Enum.Material.Metal, Color = Color3.fromRGB(80, 55, 55) },
			{ Name = "Pommel", MeshId = "rbxassetid://136899147853046", Size = Vector3.new(0.3800, 0.3400, 0.3843), Offset = Vector3.new(0.0000, 0.0000, -1.5321), Mat = Enum.Material.Metal, Color = Color3.fromRGB(60, 45, 50) },
			{ Name = "RuneInlay", MeshId = "rbxassetid://128212872585468", Size = Vector3.new(2.7100, 0.5472, 0.8600), Offset = Vector3.new(0.0000, 0.0000, 1.1450), Mat = Enum.Material.Neon, Color = Color3.fromRGB(255, 180, 20) },
		},
	},
	art_titan_earthshaker = {
		GripPos = Vector3.new(0.0000, 0.0000, -0.9000),
		OffhandGripPos = Vector3.new(0.0000, 0.0000, 0.2000),
		TipPos = Vector3.new(-1.6600, 0.0000, 2.0540),
		BasePos = Vector3.new(-1.6600, 0.0000, 0.2360),
		CorePos = Vector3.new(-0.4980, 0.0000, 1.1450),
		Parts = {
			{ Name = "BackSpike", MeshId = "rbxassetid://116548411188476", Size = Vector3.new(1.5200, 0.3200, 2.0200), Offset = Vector3.new(0.9600, 0.0000, 1.1450), Mat = Enum.Material.Metal, Color = Color3.fromRGB(225, 175, 45) },
			{ Name = "Blade", MeshId = "rbxassetid://81406752367241", Size = Vector3.new(1.4000, 0.3200, 1.9100), Offset = Vector3.new(-0.9000, 0.0000, 1.1500), Mat = Enum.Material.Metal, Color = Color3.fromRGB(210, 215, 225) },
			{ Name = "BladeEdge", MeshId = "rbxassetid://105285807959208", Size = Vector3.new(0.1200, 0.0500, 2.0200), Offset = Vector3.new(-1.6600, 0.0000, 1.1450), Mat = Enum.Material.Metal, Color = Color3.fromRGB(255, 220, 80) },
			{ Name = "Handle", MeshId = "rbxassetid://139773216422947", Size = Vector3.new(0.2960, 0.2960, 2.8500), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Marble, Color = Color3.fromRGB(235, 235, 240) },
			{ Name = "HeadCollar", MeshId = "rbxassetid://74769495775230", Size = Vector3.new(0.4900, 0.7200, 0.7300), Offset = Vector3.new(0.0000, 0.0000, 1.1600), Mat = Enum.Material.Metal, Color = Color3.fromRGB(245, 195, 60) },
			{ Name = "Pommel", MeshId = "rbxassetid://90507202750542", Size = Vector3.new(0.4200, 0.3700, 0.4186), Offset = Vector3.new(0.0000, 0.0000, -1.5650), Mat = Enum.Material.Metal, Color = Color3.fromRGB(235, 185, 50) },
			{ Name = "RuneInlay", MeshId = "rbxassetid://109609890425736", Size = Vector3.new(2.9100, 0.4100, 0.4100), Offset = Vector3.new(0.0000, 0.0000, 1.3050), Mat = Enum.Material.Neon, Color = Color3.fromRGB(255, 230, 110) },
		},
	},
	art_mountain_breaker = {
		GripPos = Vector3.new(0.0000, 0.0000, -0.9000),
		OffhandGripPos = Vector3.new(0.0000, 0.0000, 0.2000),
		TipPos = Vector3.new(-1.7000, 0.0000, 2.1150),
		BasePos = Vector3.new(-1.7000, 0.0000, 0.3150),
		CorePos = Vector3.new(-0.5100, 0.0000, 1.2150),
		Parts = {
			{ Name = "BackSpike", MeshId = "rbxassetid://74402307832417", Size = Vector3.new(0.9700, 0.3983, 0.4000), Offset = Vector3.new(0.6850, 0.0000, 1.1750), Mat = Enum.Material.Metal, Color = Color3.fromRGB(110, 105, 115) },
			{ Name = "Blade", MeshId = "rbxassetid://107554293458839", Size = Vector3.new(1.4400, 0.3400, 1.8800), Offset = Vector3.new(-0.9200, 0.0000, 1.2150), Mat = Enum.Material.Slate, Color = Color3.fromRGB(70, 68, 75) },
			{ Name = "BladeEdge", MeshId = "rbxassetid://137487600730050", Size = Vector3.new(0.1200, 0.0500, 2.0000), Offset = Vector3.new(-1.7000, 0.0000, 1.2150), Mat = Enum.Material.Metal, Color = Color3.fromRGB(240, 190, 70) },
			{ Name = "Handle", MeshId = "rbxassetid://79118305341376", Size = Vector3.new(0.3534, 0.3449, 2.8500), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Granite, Color = Color3.fromRGB(85, 80, 88) },
			{ Name = "HeadCollar", MeshId = "rbxassetid://119620279083051", Size = Vector3.new(0.5000, 0.7400, 0.7390), Offset = Vector3.new(0.0000, 0.0000, 1.1555), Mat = Enum.Material.Metal, Color = Color3.fromRGB(220, 165, 55) },
			{ Name = "Pommel", MeshId = "rbxassetid://95467070636552", Size = Vector3.new(0.4400, 0.3787, 0.4400), Offset = Vector3.new(0.0000, 0.0000, -1.5650), Mat = Enum.Material.Metal, Color = Color3.fromRGB(190, 140, 50) },
			{ Name = "RuneInlay", MeshId = "rbxassetid://113184894438481", Size = Vector3.new(2.1600, 0.5100, 0.9100), Offset = Vector3.new(-0.3250, 0.0000, 1.3550), Mat = Enum.Material.Neon, Color = Color3.fromRGB(255, 175, 40) },
		},
	},
	art_valkyrie_waraxe = {
		GripPos = Vector3.new(0.0000, 0.0000, -0.9000),
		OffhandGripPos = Vector3.new(0.0000, 0.0000, 0.2000),
		TipPos = Vector3.new(-1.7600, 0.0000, 2.1920),
		BasePos = Vector3.new(-1.7600, 0.0000, 0.3380),
		CorePos = Vector3.new(-0.5280, 0.0000, 1.2650),
		Parts = {
			{ Name = "BackSpike", MeshId = "rbxassetid://111700472085822", Size = Vector3.new(1.0750, 0.3000, 0.7769), Offset = Vector3.new(0.6943, 0.0000, 1.3764), Mat = Enum.Material.Metal, Color = Color3.fromRGB(235, 240, 252) },
			{ Name = "Blade", MeshId = "rbxassetid://137949235119990", Size = Vector3.new(1.5000, 0.3200, 1.9400), Offset = Vector3.new(-0.9500, 0.0000, 1.2650), Mat = Enum.Material.Metal, Color = Color3.fromRGB(230, 235, 250) },
			{ Name = "BladeEdge", MeshId = "rbxassetid://138742986148878", Size = Vector3.new(0.1200, 0.0500, 2.0600), Offset = Vector3.new(-1.7600, 0.0000, 1.2650), Mat = Enum.Material.Metal, Color = Color3.fromRGB(255, 225, 95) },
			{ Name = "Handle", MeshId = "rbxassetid://94020196573736", Size = Vector3.new(0.2760, 0.2760, 2.8500), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(225, 230, 245) },
			{ Name = "HeadCollar", MeshId = "rbxassetid://106997586662980", Size = Vector3.new(0.3800, 0.6500, 0.6942), Offset = Vector3.new(0.0000, 0.0000, 1.1779), Mat = Enum.Material.Metal, Color = Color3.fromRGB(250, 210, 80) },
			{ Name = "Pommel", MeshId = "rbxassetid://126677805549543", Size = Vector3.new(0.4200, 0.2000, 0.4595), Offset = Vector3.new(0.0000, 0.0000, -1.6152), Mat = Enum.Material.Metal, Color = Color3.fromRGB(245, 205, 70) },
			{ Name = "RuneInlay", MeshId = "rbxassetid://123188788303564", Size = Vector3.new(2.7400, 0.5500, 0.8600), Offset = Vector3.new(-0.3650, 0.0000, 1.3800), Mat = Enum.Material.Neon, Color = Color3.fromRGB(0, 235, 255) },
		},
	},
	art_world_shaper = {
		GripPos = Vector3.new(0.0000, 0.0000, -0.9000),
		OffhandGripPos = Vector3.new(0.0000, 0.0000, 0.2000),
		TipPos = Vector3.new(-1.8400, 0.0000, 2.2280),
		BasePos = Vector3.new(-1.8400, 0.0000, 0.3020),
		CorePos = Vector3.new(-0.5520, 0.0000, 1.2650),
		Parts = {
			{ Name = "BackSpike", MeshId = "rbxassetid://79778088493180", Size = Vector3.new(0.6791, 0.6400, 0.6385), Offset = Vector3.new(0.5395, 0.0000, 1.1550), Mat = Enum.Material.Metal, Color = Color3.fromRGB(215, 160, 45) },
			{ Name = "Blade", MeshId = "rbxassetid://88347879601295", Size = Vector3.new(1.5800, 0.3400, 2.0200), Offset = Vector3.new(-0.9900, 0.0000, 1.2650), Mat = Enum.Material.Metal, Color = Color3.fromRGB(175, 185, 200) },
			{ Name = "BladeEdge", MeshId = "rbxassetid://103026536239619", Size = Vector3.new(0.1200, 0.0500, 2.1400), Offset = Vector3.new(-1.8400, 0.0000, 1.2650), Mat = Enum.Material.Metal, Color = Color3.fromRGB(245, 195, 75) },
			{ Name = "Handle", MeshId = "rbxassetid://114198844788679", Size = Vector3.new(0.3062, 0.3040, 2.8500), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(150, 160, 175) },
			{ Name = "HeadCollar", MeshId = "rbxassetid://107428404863119", Size = Vector3.new(0.5800, 0.7000, 0.7393), Offset = Vector3.new(0.0000, 0.0000, 1.1753), Mat = Enum.Material.Metal, Color = Color3.fromRGB(235, 180, 60) },
			{ Name = "Pommel", MeshId = "rbxassetid://139200718533338", Size = Vector3.new(0.4600, 0.3200, 0.4900), Offset = Vector3.new(0.0000, 0.0000, -1.6100), Mat = Enum.Material.Metal, Color = Color3.fromRGB(225, 170, 50) },
			{ Name = "RuneInlay", MeshId = "rbxassetid://91190367374261", Size = Vector3.new(2.2891, 0.5973, 0.9400), Offset = Vector3.new(-0.3350, 0.0000, 1.2450), Mat = Enum.Material.Neon, Color = Color3.fromRGB(255, 205, 30) },
		},
	},
	art_world_carver = {
		GripPos = Vector3.new(0.0000, 0.0000, -0.9000),
		OffhandGripPos = Vector3.new(0.0000, 0.0000, 0.2000),
		TipPos = Vector3.new(-1.9612, 0.0000, 2.3630),
		BasePos = Vector3.new(-1.9612, 0.0000, 0.2570),
		CorePos = Vector3.new(-0.5884, 0.0000, 1.3100),
		Parts = {
			{ Name = "BackSpike", MeshId = "rbxassetid://87653437985852", Size = Vector3.new(1.2330, 0.3600, 0.5493), Offset = Vector3.new(0.8072, 0.0016, 1.2974), Mat = Enum.Material.Slate, Color = Color3.fromRGB(30, 24, 38) },
			{ Name = "Blade", MeshId = "rbxassetid://140623418260943", Size = Vector3.new(1.6800, 0.3600, 2.1800), Offset = Vector3.new(-1.0612, 0.0016, 1.3100), Mat = Enum.Material.Metal, Color = Color3.fromRGB(35, 28, 45) },
			{ Name = "BladeEdge", MeshId = "rbxassetid://84999182742385", Size = Vector3.new(0.1200, 0.0500, 2.3400), Offset = Vector3.new(-1.9612, 0.0016, 1.3100), Mat = Enum.Material.Metal, Color = Color3.fromRGB(220, 225, 245) },
			{ Name = "Handle", MeshId = "rbxassetid://129292925190316", Size = Vector3.new(0.3171, 0.3188, 2.8800), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Slate, Color = Color3.fromRGB(25, 20, 32) },
			{ Name = "HeadCollar", MeshId = "rbxassetid://114597544271248", Size = Vector3.new(0.4800, 0.7900, 0.8050), Offset = Vector3.new(-0.0012, 0.0016, 1.1875), Mat = Enum.Material.Metal, Color = Color3.fromRGB(205, 210, 228) },
			{ Name = "Pommel", MeshId = "rbxassetid://138099900725119", Size = Vector3.new(0.4425, 0.4174, 0.5030), Offset = Vector3.new(-0.0012, 0.0016, -1.6200), Mat = Enum.Material.Metal, Color = Color3.fromRGB(195, 200, 218) },
			{ Name = "RuneInlay", MeshId = "rbxassetid://71984284477387", Size = Vector3.new(3.0700, 0.6000, 1.2200), Offset = Vector3.new(-0.3762, 0.0016, 1.4600), Mat = Enum.Material.Neon, Color = Color3.fromRGB(195, 70, 255) },
		},
	},
	art_genesis_sunderer = {
		GripPos = Vector3.new(0.0000, 0.0000, -0.9000),
		OffhandGripPos = Vector3.new(0.0000, 0.0000, 0.2000),
		TipPos = Vector3.new(-2.0700, 0.0000, 2.4920),
		BasePos = Vector3.new(-2.0700, 0.0000, 0.1880),
		CorePos = Vector3.new(-0.6210, 0.0000, 1.3400),
		Parts = {
			{ Name = "BackSpike", MeshId = "rbxassetid://89991968909201", Size = Vector3.new(1.9000, 0.3800, 2.5600), Offset = Vector3.new(1.1900, 0.0000, 1.3400), Mat = Enum.Material.Metal, Color = Color3.fromRGB(55, 42, 72) },
			{ Name = "Blade", MeshId = "rbxassetid://138844654001318", Size = Vector3.new(1.7600, 0.3800, 2.4200), Offset = Vector3.new(-1.1200, 0.0000, 1.3300), Mat = Enum.Material.Metal, Color = Color3.fromRGB(65, 50, 85) },
			{ Name = "BladeEdge", MeshId = "rbxassetid://85383635867879", Size = Vector3.new(0.1400, 0.0500, 2.5600), Offset = Vector3.new(-2.0700, 0.0000, 1.3400), Mat = Enum.Material.Metal, Color = Color3.fromRGB(255, 225, 90) },
			{ Name = "Handle", MeshId = "rbxassetid://85646136061312", Size = Vector3.new(0.4000, 0.3248, 2.9200), Offset = Vector3.new(0.0000, 0.0000, 0.0000), Mat = Enum.Material.Metal, Color = Color3.fromRGB(45, 35, 60) },
			{ Name = "HeadCollar", MeshId = "rbxassetid://121847590034130", Size = Vector3.new(0.9200, 0.9200, 0.9100), Offset = Vector3.new(0.0000, 0.0000, 1.1950), Mat = Enum.Material.Metal, Color = Color3.fromRGB(255, 210, 75) },
			{ Name = "Pommel", MeshId = "rbxassetid://81500945899066", Size = Vector3.new(0.5320, 0.4006, 0.4990), Offset = Vector3.new(0.0000, 0.0000, -1.6600), Mat = Enum.Material.Metal, Color = Color3.fromRGB(250, 200, 65) },
			{ Name = "RuneInlay", MeshId = "rbxassetid://80580311004629", Size = Vector3.new(4.0300, 0.6487, 1.2500), Offset = Vector3.new(0.0000, 0.0000, 1.5000), Mat = Enum.Material.Neon, Color = Color3.fromRGB(255, 100, 180) },
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
		local p = Instance.new("MeshPart")
		p.Name = pInfo.Name
		pcall(function()
			p.MeshId = pInfo.MeshId
		end)
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

	-- Sockets: Grip, OffhandGrip, Tip, VfxTip, VfxBase, VfxCore
	local grip = Instance.new("Attachment")
	grip.Name = "Grip"
	grip.CFrame = CFrame.fromMatrix(data.GripPos, Vector3.new(0, 1, 0), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0))
	grip.Parent = handlePart

	local offhandGrip = Instance.new("Attachment")
	offhandGrip.Name = "OffhandGrip"
	offhandGrip.CFrame = CFrame.fromMatrix(data.OffhandGripPos, Vector3.new(0, 1, 0), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0))
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
		local p = Instance.new("MeshPart")
		p.Name = pInfo.Name
		pcall(function()
			p.MeshId = pInfo.MeshId
		end)
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
		local p = Instance.new("MeshPart")
		p.Name = pInfo.Name
		pcall(function()
			p.MeshId = pInfo.MeshId
		end)
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
		-- Miner Axes (Batch 4)
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
	for _, catalog in { DAGGER_MESH_DATA, AXE_MESH_DATA, STAFF_MESH_DATA, TOME_MESH_DATA } :: { { [string]: any } } do
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
	return ids
end

return WeaponModelBuilder