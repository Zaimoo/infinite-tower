--!strict
-- ReplicatedStorage/Assets/HeroModelBuilder.luau
-- Standalone procedural builder for the 7 stylized anime R15 hero models.
-- Fully compliant with Zero Server-Side Humanoid standard (Motor6Ds + AnimationController).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HeroModelBuilder = {}

-- Standard R15 joint connection table
local LIMB_PAIRS = {
	{ "HumanoidRootPart", "LowerTorso", "RootRigAttachment", "Root" },
	{ "LowerTorso", "UpperTorso", "WaistRigAttachment", "Waist" },
	{ "UpperTorso", "Head", "NeckRigAttachment", "Neck" },
	{ "UpperTorso", "LeftUpperArm", "LeftShoulderRigAttachment", "LeftShoulder" },
	{ "LeftUpperArm", "LeftLowerArm", "LeftElbowRigAttachment", "LeftElbow" },
	{ "LeftLowerArm", "LeftHand", "LeftWristRigAttachment", "LeftWrist" },
	{ "UpperTorso", "RightUpperArm", "RightShoulderRigAttachment", "RightShoulder" },
	{ "RightUpperArm", "RightLowerArm", "RightElbowRigAttachment", "RightElbow" },
	{ "RightLowerArm", "RightHand", "RightWristRigAttachment", "RightWrist" },
	{ "LowerTorso", "LeftUpperLeg", "LeftHipRigAttachment", "LeftHip" },
	{ "LeftUpperLeg", "LeftLowerLeg", "LeftKneeRigAttachment", "LeftKnee" },
	{ "LeftLowerLeg", "LeftFoot", "LeftAnkleRigAttachment", "LeftAnkle" },
	{ "LowerTorso", "RightUpperLeg", "RightHipRigAttachment", "RightHip" },
	{ "RightUpperLeg", "RightLowerLeg", "RightKneeRigAttachment", "RightKnee" },
	{ "RightLowerLeg", "RightFoot", "RightAnkleRigAttachment", "RightAnkle" },
}

local function weld(part0: BasePart, part1: BasePart): WeldConstraint
	local w = Instance.new("WeldConstraint")
	w.Part0 = part0
	w.Part1 = part1
	w.Parent = part0
	return w
end

local function makePart(parent: Instance, name: string, size: Vector3, cfOffset: CFrame, anchorTo: BasePart, color: Color3, mat: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = anchorTo.CFrame * cfOffset
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	if shape then p.Shape = shape end
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.Anchored = false
	p.CastShadow = false
	p.Parent = parent
	weld(p, anchorTo)
	return p
end

local function makeWedge(parent: Instance, name: string, size: Vector3, cfOffset: CFrame, anchorTo: BasePart, color: Color3, mat: Enum.Material?): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Size = size
	w.CFrame = anchorTo.CFrame * cfOffset
	w.Color = color
	w.Material = mat or Enum.Material.SmoothPlastic
	w.CanCollide = false
	w.CanTouch = false
	w.CanQuery = false
	w.Massless = true
	w.Anchored = false
	w.CastShadow = false
	w.Parent = parent
	weld(w, anchorTo)
	return w
end

local function createBaseR15(heroId: string, skinColor: Color3): Model
	local desc = Instance.new("HumanoidDescription")
	local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	model.Name = heroId
	model.Parent = Workspace

	-- Build 15 authentic Motor6D joints from native RigAttachments
	for _, pair in ipairs(LIMB_PAIRS) do
		local p0 = model:FindFirstChild(pair[1]) :: BasePart?
		local p1 = model:FindFirstChild(pair[2]) :: BasePart?
		if p0 and p1 then
			local att0 = p0:FindFirstChild(pair[3]) :: Attachment?
			local att1 = p1:FindFirstChild(pair[3]) :: Attachment?
			if att0 and att1 then
				local motor = Instance.new("Motor6D")
				motor.Name = pair[4]
				motor.Part0 = p0
				motor.Part1 = p1
				motor.C0 = att0.CFrame
				motor.C1 = att1.CFrame
				motor.Parent = p1
			end
		end
	end

	-- Replace Humanoid with AnimationController (Zero Server-Side Humanoid standard)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid:Destroy() end
	local animCtrl = Instance.new("AnimationController")
	animCtrl.Name = "AnimController"
	animCtrl.Parent = model

	-- Set base properties & skin color
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.Massless = true
			p.Anchored = false
			p.Material = Enum.Material.SmoothPlastic
		end
	end

	local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp then
		hrp.Transparency = 1
		hrp.Anchored = false
	end

	local head = model:FindFirstChild("Head") :: BasePart?
	if head then
		head.Color = skinColor
		local face = head:FindFirstChild("face") :: Decal?
		if not face then
			face = Instance.new("Decal")
			face.Name = "face"
			face.Face = Enum.NormalId.Front
			face.Parent = head
		end
		face.Texture = "rbxassetid://144080495" -- Expressive anime face
	end

	local leftHand = model:FindFirstChild("LeftHand") :: BasePart?
	local rightHand = model:FindFirstChild("RightHand") :: BasePart?
	if leftHand then leftHand.Color = skinColor end
	if rightHand then rightHand.Color = skinColor end

	return model
end

--============================================================================
-- HERO 1: HERO_HAN (1★ Striker - Shonen Swordsman)
--============================================================================
function HeroModelBuilder.BuildHan(): Model
	local skin = Color3.fromRGB(255, 224, 196)
	local hairColor = Color3.fromRGB(24, 38, 75)
	local tunicBlue = Color3.fromRGB(70, 155, 255)
	local trimWhite = Color3.fromRGB(245, 245, 250)
	local darkNavy = Color3.fromRGB(25, 30, 48)
	local goldTsuba = Color3.fromRGB(235, 195, 60)

	local model = createBaseR15("hero_han", skin)
	local head = model:FindFirstChild("Head") :: BasePart
	local upperTorso = model:FindFirstChild("UpperTorso") :: BasePart
	local lowerTorso = model:FindFirstChild("LowerTorso") :: BasePart
	local lArm = model:FindFirstChild("LeftLowerArm") :: BasePart
	local rArm = model:FindFirstChild("RightLowerArm") :: BasePart
	local lLeg = model:FindFirstChild("LeftUpperLeg") :: BasePart
	local rLeg = model:FindFirstChild("RightUpperLeg") :: BasePart
	local lFoot = model:FindFirstChild("LeftFoot") :: BasePart
	local rFoot = model:FindFirstChild("RightFoot") :: BasePart

	upperTorso.Color = tunicBlue
	lowerTorso.Color = darkNavy
	lLeg.Color = darkNavy
	rLeg.Color = darkNavy
	lFoot.Color = darkNavy
	rFoot.Color = darkNavy

	-- Hair: Spiky anime hair cluster
	makePart(head, "HairBase", Vector3.new(1.24, 0.45, 1.24), CFrame.new(0, 0.48, -0.05), head, hairColor)
	makeWedge(head, "SpikeTop1", Vector3.new(0.35, 0.75, 0.4), CFrame.new(0, 0.85, 0.15) * CFrame.Angles(math.rad(25), 0, 0), head, hairColor)
	makeWedge(head, "SpikeTop2", Vector3.new(0.35, 0.65, 0.4), CFrame.new(-0.35, 0.75, 0.05) * CFrame.Angles(math.rad(15), 0, math.rad(-20)), head, hairColor)
	makeWedge(head, "SpikeTop3", Vector3.new(0.35, 0.65, 0.4), CFrame.new(0.35, 0.75, 0.05) * CFrame.Angles(math.rad(15), 0, math.rad(20)), head, hairColor)
	makeWedge(head, "SpikeBack", Vector3.new(0.8, 0.55, 0.35), CFrame.new(0, 0.35, 0.65) * CFrame.Angles(math.rad(45), 0, 0), head, hairColor)
	makePart(head, "Bangs", Vector3.new(1.15, 0.3, 0.3), CFrame.new(0, 0.38, -0.58) * CFrame.Angles(math.rad(-15), 0, 0), head, hairColor)

	-- Tunic collar trim & martial arts belt
	makePart(upperTorso, "CollarTrim", Vector3.new(0.9, 0.15, 0.5), CFrame.new(0, 0.75, -0.32), upperTorso, trimWhite)
	makePart(lowerTorso, "BeltSash", Vector3.new(2.05, 0.35, 1.05), CFrame.new(0, 0, 0), lowerTorso, tunicBlue)
	makePart(lowerTorso, "BeltKnot", Vector3.new(0.4, 0.6, 0.25), CFrame.new(-0.5, -0.25, -0.55), lowerTorso, tunicBlue)

	-- Forearm bracers
	makePart(lArm, "BracerL", Vector3.new(1.05, 0.65, 1.05), CFrame.new(0, -0.2, 0), lArm, darkNavy)
	makePart(rArm, "BracerR", Vector3.new(1.05, 0.65, 1.05), CFrame.new(0, -0.2, 0), rArm, darkNavy)

	-- Sheathed Katana mounted at left hip
	local scabbard = makePart(lowerTorso, "KatanaScabbard", Vector3.new(0.22, 2.7, 0.32), CFrame.new(1.15, -0.4, 0.1) * CFrame.Angles(math.rad(-25), 0, math.rad(15)), lowerTorso, darkNavy)
	makePart(scabbard, "KatanaTsuba", Vector3.new(0.55, 0.08, 0.55), CFrame.new(0, 1.35, 0), scabbard, goldTsuba)
	makePart(scabbard, "KatanaTsuka", Vector3.new(0.25, 0.95, 0.25), CFrame.new(0, 1.85, 0), scabbard, tunicBlue)

	return model
end

--============================================================================
-- HERO 2: HERO_JENNA (1★ Marksman - Wind-Scout Archer)
--============================================================================
function HeroModelBuilder.BuildJenna(): Model
	local skin = Color3.fromRGB(255, 228, 205)
	local hairMint = Color3.fromRGB(45, 135, 80)
	local tunicGreen = Color3.fromRGB(95, 235, 145)
	local leatherBrown = Color3.fromRGB(115, 80, 50)
	local darkGreen = Color3.fromRGB(28, 75, 45)

	local model = createBaseR15("hero_jenna", skin)
	local head = model:FindFirstChild("Head") :: BasePart
	local upperTorso = model:FindFirstChild("UpperTorso") :: BasePart
	local lowerTorso = model:FindFirstChild("LowerTorso") :: BasePart
	local lArm = model:FindFirstChild("LeftLowerArm") :: BasePart
	local lLeg = model:FindFirstChild("LeftUpperLeg") :: BasePart
	local rLeg = model:FindFirstChild("RightUpperLeg") :: BasePart
	local lFoot = model:FindFirstChild("LeftFoot") :: BasePart
	local rFoot = model:FindFirstChild("RightFoot") :: BasePart

	upperTorso.Color = tunicGreen
	lowerTorso.Color = leatherBrown
	lLeg.Color = darkGreen
	rLeg.Color = darkGreen
	lFoot.Color = leatherBrown
	rFoot.Color = leatherBrown

	-- Hair: High Twin-Tails
	makePart(head, "HairBase", Vector3.new(1.24, 0.45, 1.24), CFrame.new(0, 0.48, -0.05), head, hairMint)
	makePart(head, "HairBangs", Vector3.new(1.15, 0.35, 0.3), CFrame.new(0, 0.35, -0.58) * CFrame.Angles(math.rad(-10), 0, 0), head, hairMint)
	-- Left & Right high twin tails
	makePart(head, "TailLeft", Vector3.new(0.35, 1.6, 0.35), CFrame.new(-0.75, 0.25, 0.2) * CFrame.Angles(0, 0, math.rad(-15)), head, hairMint)
	makePart(head, "TailRight", Vector3.new(0.35, 1.6, 0.35), CFrame.new(0.75, 0.25, 0.2) * CFrame.Angles(0, 0, math.rad(15)), head, hairMint)

	-- Ranger cowl & belt
	makePart(upperTorso, "RangerCowl", Vector3.new(1.8, 0.4, 1.1), CFrame.new(0, 0.7, 0), upperTorso, darkGreen)
	makePart(lowerTorso, "UtilityBelt", Vector3.new(2.05, 0.3, 1.05), CFrame.new(0, 0, 0), lowerTorso, leatherBrown)

	-- Recurve Bow welded to LeftLowerArm
	local bowCenter = makePart(lArm, "BowGrip", Vector3.new(0.25, 0.8, 0.35), CFrame.new(0, 0, -0.6), lArm, leatherBrown)
	local bowUpper = makePart(bowCenter, "BowLimbUpper", Vector3.new(0.2, 1.5, 0.25), CFrame.new(0, 1.0, 0.25) * CFrame.Angles(math.rad(-22), 0, 0), bowCenter, tunicGreen, Enum.Material.Neon)
	local bowLower = makePart(bowCenter, "BowLimbLower", Vector3.new(0.2, 1.5, 0.25), CFrame.new(0, -1.0, 0.25) * CFrame.Angles(math.rad(22), 0, 0), bowCenter, tunicGreen, Enum.Material.Neon)
	makePart(bowCenter, "BowString", Vector3.new(0.05, 3.2, 0.05), CFrame.new(0, 0, 0.65), bowCenter, Color3.fromRGB(220, 230, 240))

	-- Quiver on back with arrows
	local quiver = makePart(upperTorso, "Quiver", Vector3.new(0.55, 1.8, 0.55), CFrame.new(0.3, 0.2, 0.7) * CFrame.Angles(0, 0, math.rad(-25)), upperTorso, leatherBrown)
	makePart(quiver, "Arrow1", Vector3.new(0.1, 0.6, 0.1), CFrame.new(-0.1, 1.0, 0), quiver, Color3.fromRGB(220, 220, 220))
	makePart(quiver, "Arrow2", Vector3.new(0.1, 0.6, 0.1), CFrame.new(0.1, 1.0, 0), quiver, Color3.fromRGB(220, 220, 220))

	return model
end

--============================================================================
-- HERO 3: HERO_CATIO (1★ Miner - Steampunk Cat-Engineer)
--============================================================================
function HeroModelBuilder.BuildCatio(): Model
	local skin = Color3.fromRGB(255, 220, 190)
	local hairAmber = Color3.fromRGB(215, 155, 40)
	local vestYellow = Color3.fromRGB(255, 205, 75)
	local leatherBrown = Color3.fromRGB(120, 80, 45)
	local brassGold = Color3.fromRGB(180, 130, 45)
	local manaCyan = Color3.fromRGB(80, 225, 255)

	local model = createBaseR15("hero_catio", skin)
	local head = model:FindFirstChild("Head") :: BasePart
	local upperTorso = model:FindFirstChild("UpperTorso") :: BasePart
	local lowerTorso = model:FindFirstChild("LowerTorso") :: BasePart
	local lLeg = model:FindFirstChild("LeftUpperLeg") :: BasePart
	local rLeg = model:FindFirstChild("RightUpperLeg") :: BasePart
	local lFoot = model:FindFirstChild("LeftFoot") :: BasePart
	local rFoot = model:FindFirstChild("RightFoot") :: BasePart

	upperTorso.Color = vestYellow
	lowerTorso.Color = leatherBrown
	lLeg.Color = Color3.fromRGB(45, 50, 65)
	rLeg.Color = Color3.fromRGB(45, 50, 65)
	lFoot.Color = leatherBrown
	rFoot.Color = leatherBrown

	-- Hair & Pointed Cat Ears
	makePart(head, "HairBase", Vector3.new(1.24, 0.45, 1.24), CFrame.new(0, 0.48, -0.05), head, hairAmber)
	makeWedge(head, "CatEarL", Vector3.new(0.35, 0.65, 0.35), CFrame.new(-0.45, 0.85, 0.05) * CFrame.Angles(0, math.rad(-15), math.rad(10)), head, hairAmber)
	makePart(head, "CatEarInnerL", Vector3.new(0.18, 0.35, 0.05), CFrame.new(-0.45, 0.82, -0.12), head, Color3.fromRGB(255, 180, 190))
	makeWedge(head, "CatEarR", Vector3.new(0.35, 0.65, 0.35), CFrame.new(0.45, 0.85, 0.05) * CFrame.Angles(0, math.rad(15), math.rad(-10)), head, hairAmber)
	makePart(head, "CatEarInnerR", Vector3.new(0.18, 0.35, 0.05), CFrame.new(0.45, 0.82, -0.12), head, Color3.fromRGB(255, 180, 190))

	-- Steampunk Goggles pushed onto forehead
	local goggleStrap = makePart(head, "GoggleStrap", Vector3.new(1.26, 0.2, 1.26), CFrame.new(0, 0.3, 0), head, leatherBrown)
	makePart(goggleStrap, "LensL", Vector3.new(0.38, 0.38, 0.25), CFrame.new(-0.28, 0, -0.6), goggleStrap, manaCyan, Enum.Material.Neon, Enum.PartType.Cylinder)
	makePart(goggleStrap, "LensR", Vector3.new(0.38, 0.38, 0.25), CFrame.new(0.28, 0, -0.6), goggleStrap, manaCyan, Enum.Material.Neon, Enum.PartType.Cylinder)

	-- Tool belt with pouches
	makePart(lowerTorso, "ToolBelt", Vector3.new(2.05, 0.3, 1.05), CFrame.new(0, 0, 0), lowerTorso, leatherBrown)
	makePart(lowerTorso, "PouchL", Vector3.new(0.45, 0.45, 0.35), CFrame.new(-0.95, -0.1, 0), lowerTorso, leatherBrown)
	makePart(lowerTorso, "PouchR", Vector3.new(0.45, 0.45, 0.35), CFrame.new(0.95, -0.1, 0), lowerTorso, leatherBrown)

	-- Crystal Mining Pickaxe slung across back
	local pickShaft = makePart(upperTorso, "PickShaft", Vector3.new(0.22, 3.2, 0.22), CFrame.new(0, 0.2, 0.68) * CFrame.Angles(0, 0, math.rad(35)), upperTorso, Color3.fromRGB(80, 85, 95))
	makePart(pickShaft, "PickHead", Vector3.new(0.35, 0.6, 1.6), CFrame.new(0, 1.45, 0), pickShaft, manaCyan, Enum.Material.Neon)

	return model
end

--============================================================================
-- HERO 4: HERO_AARON (2★ Vanguard - Heavy Anime Paladin)
--============================================================================
function HeroModelBuilder.BuildAaron(): Model
	local skin = Color3.fromRGB(255, 224, 196)
	local hairBlonde = Color3.fromRGB(235, 215, 150)
	local armorSteel = Color3.fromRGB(210, 215, 225)
	local goldFiligree = Color3.fromRGB(255, 185, 60)
	local shieldOrange = Color3.fromRGB(255, 155, 60)

	local model = createBaseR15("hero_aaron", skin)
	local head = model:FindFirstChild("Head") :: BasePart
	local upperTorso = model:FindFirstChild("UpperTorso") :: BasePart
	local lowerTorso = model:FindFirstChild("LowerTorso") :: BasePart
	local lUpperArm = model:FindFirstChild("LeftUpperArm") :: BasePart
	local rUpperArm = model:FindFirstChild("RightUpperArm") :: BasePart
	local lArm = model:FindFirstChild("LeftLowerArm") :: BasePart
	local lLeg = model:FindFirstChild("LeftUpperLeg") :: BasePart
	local rLeg = model:FindFirstChild("RightUpperLeg") :: BasePart
	local lFoot = model:FindFirstChild("LeftFoot") :: BasePart
	local rFoot = model:FindFirstChild("RightFoot") :: BasePart

	upperTorso.Color = armorSteel
	lowerTorso.Color = armorSteel
	lLeg.Color = armorSteel
	rLeg.Color = armorSteel
	lFoot.Color = armorSteel
	rFoot.Color = armorSteel

	-- Hair: Tousled ash-blonde knight hair
	makePart(head, "HairBase", Vector3.new(1.24, 0.45, 1.24), CFrame.new(0, 0.48, -0.05), head, hairBlonde)
	makePart(head, "HairBangs", Vector3.new(1.15, 0.4, 0.35), CFrame.new(0, 0.35, -0.58) * CFrame.Angles(math.rad(-15), 0, 0), head, hairBlonde)

	-- Breastplate with gold filigree
	makePart(upperTorso, "ChestPlate", Vector3.new(2.05, 1.4, 1.15), CFrame.new(0, 0.05, 0), upperTorso, armorSteel)
	makePart(upperTorso, "GoldCross", Vector3.new(0.6, 0.9, 0.1), CFrame.new(0, 0.1, -0.62), upperTorso, goldFiligree)

	-- Bulky geometric shoulder pauldrons
	makePart(lUpperArm, "PauldronL", Vector3.new(1.3, 0.7, 1.3), CFrame.new(-0.25, 0.45, 0), lUpperArm, armorSteel)
	makePart(lUpperArm, "PauldronL_Trim", Vector3.new(1.35, 0.15, 1.35), CFrame.new(-0.25, 0.45, 0), lUpperArm, goldFiligree)
	makePart(rUpperArm, "PauldronR", Vector3.new(1.3, 0.7, 1.3), CFrame.new(0.25, 0.45, 0), rUpperArm, armorSteel)
	makePart(rUpperArm, "PauldronR_Trim", Vector3.new(1.35, 0.15, 1.35), CFrame.new(0.25, 0.45, 0), rUpperArm, goldFiligree)

	-- Towering Kite Shield welded to LeftLowerArm
	local shield = makePart(lArm, "KiteShield", Vector3.new(0.28, 3.4, 1.8), CFrame.new(-0.7, 0, 0), lArm, armorSteel)
	makePart(shield, "ShieldTrim", Vector3.new(0.32, 3.5, 0.2), CFrame.new(0, 0, -0.85), shield, goldFiligree)
	makePart(shield, "ShieldTrimTop", Vector3.new(0.32, 0.2, 1.85), CFrame.new(0, 1.65, 0), shield, goldFiligree)
	makePart(shield, "SunburstCrest", Vector3.new(0.35, 0.9, 0.9), CFrame.new(0, 0.35, 0), shield, shieldOrange, Enum.Material.Neon, Enum.PartType.Ball)

	return model
end

--============================================================================
-- HERO 5: HERO_VELKIST (2★ Striker - Crimson Rogue Assassin)
--============================================================================
function HeroModelBuilder.BuildVelkist(): Model
	local skin = Color3.fromRGB(245, 225, 215)
	local hairBlack = Color3.fromRGB(20, 20, 25)
	local shinobiDark = Color3.fromRGB(28, 28, 35)
	local crimsonScarf = Color3.fromRGB(235, 55, 85)

	local model = createBaseR15("hero_velkist", skin)
	local head = model:FindFirstChild("Head") :: BasePart
	local upperTorso = model:FindFirstChild("UpperTorso") :: BasePart
	local lowerTorso = model:FindFirstChild("LowerTorso") :: BasePart
	local rArm = model:FindFirstChild("RightLowerArm") :: BasePart
	local rHand = model:FindFirstChild("RightHand") :: BasePart
	local rLeg = model:FindFirstChild("RightUpperLeg") :: BasePart
	local lLeg = model:FindFirstChild("LeftUpperLeg") :: BasePart
	local lFoot = model:FindFirstChild("LeftFoot") :: BasePart
	local rFoot = model:FindFirstChild("RightFoot") :: BasePart

	upperTorso.Color = shinobiDark
	lowerTorso.Color = shinobiDark
	lLeg.Color = shinobiDark
	rLeg.Color = shinobiDark
	lFoot.Color = shinobiDark
	rFoot.Color = shinobiDark

	-- Asymmetrical fringe hair
	makePart(head, "HairBase", Vector3.new(1.24, 0.45, 1.24), CFrame.new(0, 0.48, -0.05), head, hairBlack)
	makePart(head, "AsymBangs", Vector3.new(0.65, 0.75, 0.35), CFrame.new(-0.35, 0.2, -0.6) * CFrame.Angles(0, 0, math.rad(20)), head, hairBlack)

	-- Flowing Crimson Scarf wrapped around neck with twin dynamic trailing tails
	local scarfWrap = makePart(upperTorso, "ScarfWrap", Vector3.new(1.7, 0.4, 1.2), CFrame.new(0, 0.8, 0), upperTorso, crimsonScarf)
	makePart(scarfWrap, "ScarfTail1", Vector3.new(0.35, 2.2, 0.15), CFrame.new(-0.35, -0.85, 0.65) * CFrame.Angles(math.rad(25), 0, math.rad(-15)), scarfWrap, crimsonScarf)
	makePart(scarfWrap, "ScarfTail2", Vector3.new(0.35, 2.0, 0.15), CFrame.new(0.35, -0.75, 0.65) * CFrame.Angles(math.rad(30), 0, math.rad(15)), scarfWrap, crimsonScarf)

	-- Reverse-Grip Assassin Dagger held in RightHand
	local daggerHilt = makePart(rHand, "DaggerHilt", Vector3.new(0.2, 0.7, 0.2), CFrame.new(0, -0.35, 0) * CFrame.Angles(math.rad(180), 0, 0), rHand, shinobiDark)
	makePart(daggerHilt, "DaggerBlade", Vector3.new(0.12, 1.4, 0.28), CFrame.new(0, -1.0, 0), daggerHilt, crimsonScarf, Enum.Material.Neon)

	-- Sheathed dagger on right thigh
	makePart(rLeg, "ThighSheath", Vector3.new(0.3, 1.4, 0.3), CFrame.new(0.65, 0, 0) * CFrame.Angles(0, 0, math.rad(10)), rLeg, shinobiDark)

	return model
end

--============================================================================
-- HERO 6: HERO_EOLKA (3★ Scholar - Pyromancer Sorceress)
--============================================================================
function HeroModelBuilder.BuildEolka(): Model
	local skin = Color3.fromRGB(255, 230, 220)
	local hairMagenta = Color3.fromRGB(235, 60, 175)
	local robesViolet = Color3.fromRGB(75, 25, 85)
	local trimPink = Color3.fromRGB(255, 80, 195)
	local rubyFlame = Color3.fromRGB(255, 45, 120)

	local model = createBaseR15("hero_eolka", skin)
	local head = model:FindFirstChild("Head") :: BasePart
	local upperTorso = model:FindFirstChild("UpperTorso") :: BasePart
	local lowerTorso = model:FindFirstChild("LowerTorso") :: BasePart
	local rHand = model:FindFirstChild("RightHand") :: BasePart
	local lLeg = model:FindFirstChild("LeftUpperLeg") :: BasePart
	local rLeg = model:FindFirstChild("RightUpperLeg") :: BasePart
	local lFoot = model:FindFirstChild("LeftFoot") :: BasePart
	local rFoot = model:FindFirstChild("RightFoot") :: BasePart

	upperTorso.Color = robesViolet
	lowerTorso.Color = robesViolet
	lLeg.Color = robesViolet
	rLeg.Color = robesViolet
	lFoot.Color = trimPink
	rFoot.Color = trimPink

	-- Hair: Twin Braids
	makePart(head, "HairBase", Vector3.new(1.24, 0.45, 1.24), CFrame.new(0, 0.48, -0.05), head, hairMagenta)
	makePart(head, "BraidL", Vector3.new(0.32, 1.8, 0.32), CFrame.new(-0.7, -0.2, -0.15), head, hairMagenta)
	makePart(head, "BraidR", Vector3.new(0.32, 1.8, 0.32), CFrame.new(0.7, -0.2, -0.15), head, hairMagenta)

	-- Flared Sorceress Robe Skirt
	makePart(lowerTorso, "RobeSkirt", Vector3.new(2.3, 1.3, 1.5), CFrame.new(0, -0.45, 0), lowerTorso, robesViolet)
	makePart(lowerTorso, "RobeTrim", Vector3.new(2.35, 0.2, 1.55), CFrame.new(0, -1.05, 0), lowerTorso, trimPink)

	-- Floating Arcane Spell Tome beside right hip
	local tome = makePart(lowerTorso, "SpellTome", Vector3.new(0.4, 1.3, 1.0), CFrame.new(1.4, -0.1, 0) * CFrame.Angles(0, math.rad(25), math.rad(15)), lowerTorso, robesViolet)
	makePart(tome, "TomePages", Vector3.new(0.3, 1.15, 0.85), CFrame.new(0.05, 0, 0), tome, Color3.fromRGB(245, 240, 225))
	makePart(tome, "TomeRune", Vector3.new(0.42, 0.5, 0.5), CFrame.new(-0.01, 0, 0), tome, trimPink, Enum.Material.Neon)

	-- Pyromancer Staff in RightHand
	local staff = makePart(rHand, "StaffShaft", Vector3.new(0.2, 4.2, 0.2), CFrame.new(0, 0.8, -0.5), rHand, Color3.fromRGB(45, 30, 45))
	makePart(staff, "StaffHeadCage", Vector3.new(0.7, 0.7, 0.7), CFrame.new(0, 2.1, 0), staff, Color3.fromRGB(225, 185, 60))
	makePart(staff, "RubyFlameCore", Vector3.new(0.5, 0.8, 0.5), CFrame.new(0, 2.1, 0), staff, rubyFlame, Enum.Material.Neon, Enum.PartType.Ball)

	return model
end

--============================================================================
-- HERO 7: HERO_ARCHON (3★ Sovereign Archon - World Boss Hybrid)
--============================================================================
function HeroModelBuilder.BuildArchon(): Model
	local skin = Color3.fromRGB(240, 242, 255)
	local hairSilver = Color3.fromRGB(235, 240, 255)
	local voidObsidian = Color3.fromRGB(30, 20, 45)
	local neonPurple = Color3.fromRGB(190, 85, 255)
	local goldAstral = Color3.fromRGB(240, 210, 120)

	local model = createBaseR15("hero_archon", skin)
	local head = model:FindFirstChild("Head") :: BasePart
	local upperTorso = model:FindFirstChild("UpperTorso") :: BasePart
	local lowerTorso = model:FindFirstChild("LowerTorso") :: BasePart
	local lArm = model:FindFirstChild("LeftLowerArm") :: BasePart
	local rArm = model:FindFirstChild("RightLowerArm") :: BasePart
	local lLeg = model:FindFirstChild("LeftUpperLeg") :: BasePart
	local rLeg = model:FindFirstChild("RightUpperLeg") :: BasePart
	local lFoot = model:FindFirstChild("LeftFoot") :: BasePart
	local rFoot = model:FindFirstChild("RightFoot") :: BasePart

	upperTorso.Color = voidObsidian
	lowerTorso.Color = voidObsidian
	lLeg.Color = voidObsidian
	rLeg.Color = voidObsidian
	lFoot.Color = voidObsidian
	rFoot.Color = voidObsidian

	-- Luminous celestial hair
	makePart(head, "HairBase", Vector3.new(1.24, 0.45, 1.24), CFrame.new(0, 0.48, -0.05), head, hairSilver)
	makePart(head, "HairSwept", Vector3.new(1.15, 0.4, 0.4), CFrame.new(0, 0.38, -0.58) * CFrame.Angles(math.rad(-15), 0, 0), head, hairSilver)

	-- Floating Astral Halo / Crown above Head
	local halo = makePart(head, "AstralHalo", Vector3.new(1.6, 0.15, 1.6), CFrame.new(0, 1.1, 0), head, voidObsidian)
	makePart(halo, "HaloCore", Vector3.new(0.6, 0.25, 0.6), CFrame.new(0, 0, 0), halo, neonPurple, Enum.Material.Neon, Enum.PartType.Ball)
	makePart(halo, "HaloSpire1", Vector3.new(0.15, 0.5, 0.15), CFrame.new(0.7, 0.25, 0), halo, goldAstral)
	makePart(halo, "HaloSpire2", Vector3.new(0.15, 0.5, 0.15), CFrame.new(-0.7, 0.25, 0), halo, goldAstral)

	-- Void Mantle with Runic Wings
	makePart(upperTorso, "VoidMantle", Vector3.new(2.4, 0.45, 1.4), CFrame.new(0, 0.75, 0), upperTorso, voidObsidian)
	makePart(upperTorso, "RunicPlateChest", Vector3.new(1.2, 0.8, 0.1), CFrame.new(0, 0.2, -0.58), upperTorso, neonPurple, Enum.Material.Neon)

	-- Floating Void Wing Blades hovering behind back
	makePart(upperTorso, "VoidWingL", Vector3.new(0.15, 2.6, 0.8), CFrame.new(-1.2, 0.5, 0.75) * CFrame.Angles(0, math.rad(-25), math.rad(-35)), upperTorso, neonPurple, Enum.Material.Neon)
	makePart(upperTorso, "VoidWingR", Vector3.new(0.15, 2.6, 0.8), CFrame.new(1.2, 0.5, 0.75) * CFrame.Angles(0, math.rad(25), math.rad(35)), upperTorso, neonPurple, Enum.Material.Neon)

	-- Gauntlets & Greaves
	makePart(lArm, "GauntletL", Vector3.new(1.05, 0.65, 1.05), CFrame.new(0, -0.2, 0), lArm, goldAstral)
	makePart(rArm, "GauntletR", Vector3.new(1.05, 0.65, 1.05), CFrame.new(0, -0.2, 0), rArm, goldAstral)

	return model
end

--============================================================================
-- MAIN GENERATION FUNCTION
--============================================================================
function HeroModelBuilder.GenerateAll(): { [string]: Model }
	local assets = ReplicatedStorage:WaitForChild("Assets")
	local heroesFolder = assets:FindFirstChild("Heroes") :: Folder?
	if not heroesFolder then
		heroesFolder = Instance.new("Folder")
		heroesFolder.Name = "Heroes"
		heroesFolder.Parent = assets
	end

	-- Clear out existing old models in Heroes folder
	for _, child in ipairs(heroesFolder:GetChildren()) do
		child:Destroy()
	end

	local heroes = {
		hero_han = HeroModelBuilder.BuildHan(),
		hero_jenna = HeroModelBuilder.BuildJenna(),
		hero_catio = HeroModelBuilder.BuildCatio(),
		hero_aaron = HeroModelBuilder.BuildAaron(),
		hero_velkist = HeroModelBuilder.BuildVelkist(),
		hero_eolka = HeroModelBuilder.BuildEolka(),
		hero_archon = HeroModelBuilder.BuildArchon(),
	}

	for id, model in pairs(heroes) do
		model.Parent = heroesFolder
	end

	return heroes
end

return HeroModelBuilder
