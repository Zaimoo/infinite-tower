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

-- ============================================================================
-- 1. WEAPON_BOW (Authoritative Hunter & Ranger Bow)
-- ============================================================================
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

	-- Precision archery geometry:
	-- String center at X = -1.25, Y = 0.00, Z = 0.28
	-- Arrow shelf on riser at X = 0.00, Y = 0.18, Z = 0.28
	local pNock = Vector3.new(-1.25, 0.00, 0.28)
	local pShelf = Vector3.new(0.00, 0.18, 0.28)
	local dir = (pShelf - pNock).Unit
	local pCenter = pNock + dir * 1.0

	local shaftCFInHandle = CFrame.lookAt(pCenter, pCenter + dir, Vector3.new(0, 0, 1))
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
	-- Check if authoritative bow prefab exists in ReplicatedStorage Assets
	local candidate: Model? = nil
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local weaponsFolder = assets and assets:FindFirstChild("Weapons")
	local existingBow = weaponsFolder and weaponsFolder:FindFirstChild("weapon_bow")
	if existingBow and existingBow:IsA("Model") and #existingBow:GetChildren() > 0 then
		candidate = existingBow
	end
	if not candidate then
		local heroesFolder = assets and assets:FindFirstChild("Heroes")
		local jenna = heroesFolder and heroesFolder:FindFirstChild("hero_jenna")
		if jenna and jenna:FindFirstChild("EquippedWeapon") and jenna.EquippedWeapon:IsA("Model") then
			candidate = jenna.EquippedWeapon
		end
	end

	if candidate then
		local clone = candidate:Clone()
		clone.Name = "weapon_bow"
		-- Clean external character welds (keep only internal Handle welds)
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("WeldConstraint") or d:IsA("Weld") or d:IsA("Motor6D") then
				local p0 = d.Part0
				local p1 = d.Part1
				if (p0 and p0.Name == "LeftHand") or (p1 and p1.Name == "LeftHand") then
					d:Destroy()
				end
			elseif d:IsA("Beam") then
				d.Attachment1 = nil
			elseif d:IsA("BasePart") then
				d.CanCollide = false
				d.CanTouch = false
				d.CanQuery = false
				d.Massless = true
				d.Anchored = false
			end
		end
		local handle = clone:FindFirstChild("Handle") :: BasePart?
		if handle then
			clone.PrimaryPart = handle
			alignHunterArrow(clone, handle)
		end
		return clone
	end

	-- Procedural Fallback Bow
	local model = Instance.new("Model")
	model.Name = "weapon_bow"
	local leatherBrown = Color3.fromRGB(115, 80, 50)
	local bowGreen = Color3.fromRGB(85, 195, 125)
	local stringColor = Color3.fromRGB(230, 240, 255)

	local handle = makePart(model, "Handle", Vector3.new(0.3, 0.8, 0.35), CFrame.new(0, 0, 0), leatherBrown)
	model.PrimaryPart = handle

	local topLimb = makePart(model, "BowLimbUpper", Vector3.new(0.22, 1.6, 0.25), CFrame.new(0, 1.1, 0.25) * CFrame.Angles(math.rad(-22), 0, 0), bowGreen)
	weldTo(handle, topLimb)

	local botLimb = makePart(model, "BowLimbLower", Vector3.new(0.22, 1.6, 0.25), CFrame.new(0, -1.1, 0.25) * CFrame.Angles(math.rad(22), 0, 0), bowGreen)
	weldTo(handle, botLimb)

	local stringPart = makePart(model, "BowString", Vector3.new(0.06, 3.4, 0.06), CFrame.new(0, 0, 0.65), stringColor)
	weldTo(handle, stringPart)

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

	return model
end

-- ============================================================================
-- PUBLIC ENSURE API
-- ============================================================================
function WeaponModelBuilder.EnsureWeapons(): { [string]: Model }
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