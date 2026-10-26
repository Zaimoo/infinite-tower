--!strict
-- ReplicatedStorage/Assets/ArtPackVisuals.luau
-- Asset manager & procedural joint animator for Zero-Humanoid R15 and Skinned rigs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local A = {}

local aliases = {
	starter_iron_vanguard = "hero_han",
	mob_mana_node = "node_mana_crystal_cluster",
	MANA_GEODE = "relic_mana_geode",
	CURSED_URN = "relic_cursed_urn",
	ABYSSAL_CORE = "relic_abyssal_core",
	CALAMITY_HEART = "relic_calamity_heart",
}

function A.Resolve(meta: any): string?
	if type(meta) == "string" then
		return aliases[meta] or meta
	end
	if meta.IsHero then
		return aliases[meta.TemplateId] or meta.TemplateId or "hero_han"
	end
	if meta.MobType == "WORLD_BOSS" then
		return "world_boss_sovereign"
	end
	if meta.MobType == "RIFT_BOSS" then
		return "boss_rift_warden"
	end
	return aliases[meta.SpecId] or meta.SpecId
end

function A.Template(id: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then return nil end
	local resolved = aliases[id] or id

	-- Prioritize the curated R15 hero rigs in Heroes folder
	local heroesFolder = assets:FindFirstChild("Heroes")
	if heroesFolder and heroesFolder:IsA("Folder") then
		local found = heroesFolder:FindFirstChild(resolved)
		if found and found:IsA("Model") and #found:GetChildren() > 0 then return found end
	end

	-- Search across all other asset subfolders
	for _, folder in ipairs(assets:GetChildren()) do
		if folder:IsA("Folder") and folder.Name ~= "Heroes" then
			local found = folder:FindFirstChild(resolved)
			if found and found:IsA("Model") and #found:GetChildren() > 0 then return found end
		end
	end

	-- Safe fallback: If a specific hero template is missing, try hero_han or any available hero model
	if heroesFolder and (resolved:find("hero_") or id:find("hero_")) then
		local fallback = heroesFolder:FindFirstChild("hero_han")
		if fallback and fallback:IsA("Model") and #fallback:GetChildren() > 0 then
			return fallback
		end
		for _, child in ipairs(heroesFolder:GetChildren()) do
			if child:IsA("Model") and #child:GetChildren() > 0 then
				return child
			end
		end
	end

	return nil
end

function A.AttachAt(parent: Instance, id: string, ground: CFrame, scale: number?): Model?
	local template = A.Template(id)
	if not template then return nil end

	local art = template:Clone()
	art.Name = "ArtPackVisual"
	if scale and scale ~= 1 then
		art:ScaleTo(art:GetScale() * scale)
	end

	local isR15 = art:FindFirstChild("HumanoidRootPart") ~= nil
	for _, p in ipairs(art:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.Massless = true
			if isR15 then
				p.Anchored = false
			else
				p.Anchored = true
				p.CanCollide = p:GetAttribute("ArtPackCollider") == true
				p.CanQuery = p.CanCollide
				p.CastShadow = not p.CanCollide
			end
		end
	end

	art:PivotTo(ground)
	art.Parent = parent
	return art
end

function A.Attach(model: Model, meta: any, root: BasePart, bodySize: Vector3): Model?
	local id = A.Resolve(meta)
	if not id then return nil end

	local template = A.Template(id)
	if not template then return nil end

	local isR15 = template:FindFirstChild("HumanoidRootPart") ~= nil
	-- If R15, root.CFrame is already at Y = ground + 3.0. For skinned mobs without HRP, ground at floor.
	local targetCF = isR15 and root.CFrame or (root.CFrame * CFrame.new(0, -bodySize.Y * 0.5, 0))

	local art = A.AttachAt(model, id, targetCF, 1)
	if art then
		for _, p in ipairs(art:GetDescendants()) do
			if p:IsA("BasePart") then
				p.CanCollide = false
				p.CanTouch = false
				p.CanQuery = false
			end
		end

		model:SetAttribute("ArtPackAssetId", id)
		root.Transparency = 1
		local head = model:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			head:Destroy()
		end

		local artHrp = art:FindFirstChild("HumanoidRootPart") :: BasePart?
		if artHrp then
			artHrp.CFrame = root.CFrame
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = artHrp
			weld.Parent = artHrp
		end
	end
	return art
end

function A.Mesh(id: string): MeshPart?
	local template = A.Template(id)
	if not template then return nil end
	local p = template:FindFirstChildWhichIsA("MeshPart", true)
	if not p then return nil end
	local part = p:Clone()
	part.CFrame = CFrame.identity
	part.Anchored = true
	part.CanCollide = false
	part.Color = Color3.new(1, 1, 1)
	part.Material = Enum.Material.SmoothPlastic
	return part
end

function A.SetChestState(facility: Instance, mode: string, amount: number)
	local anchor = facility:FindFirstChild("GemChest")
	if not anchor or not anchor:IsA("BasePart") then return end
	local id = mode == "FOOLS_GOLD" and "prop_gem_chest_overflow"
		or (mode == "VEIL_OF_POVERTY" and "prop_gem_chest_empty" or (amount >= 20 and "prop_gem_chest_overflow" or "prop_gem_chest_empty"))
	if facility:GetAttribute("ArtChestState") == id then return end
	local template = A.Template(id)
	if not template then return end
	local old = facility:FindFirstChild("ArtPackChest")
	if old then old:Destroy() end
	local art = A.AttachAt(facility, id, anchor.CFrame * CFrame.new(0, -anchor.Size.Y * 0.5, 0), 1.4)
	if art then
		art.Name = "ArtPackChest"
		anchor.Transparency = 1
		facility:SetAttribute("ArtChestState", id)
	end
end

function A.Animate(node: any, dt: number, time: number)
	local art = node.Model:FindFirstChild("ArtPackVisual")
	if not art then return end

	if not node.ArtBones then
		node.ArtBones = {}
		node.ArtBaseC0 = {}
		node.ArtPose = {}
		for _, b in ipairs(art:GetDescendants()) do
			if b:IsA("Motor6D") or b:IsA("Bone") then
				node.ArtBones[b.Name] = b
				node.ArtPose[b.Name] = CFrame.identity
				if b:IsA("Motor6D") then
					local att0 = b.Part0 and b.Part0:FindFirstChild(b.Name .. "RigAttachment")
					local att1 = b.Part1 and b.Part1:FindFirstChild(b.Name .. "RigAttachment")
					if att0 and att0:IsA("Attachment") and att1 and att1:IsA("Attachment") then
						node.ArtBaseC0[b.Name] = att0.CFrame
						b.C0 = att0.CFrame
						b.C1 = att1.CFrame
					else
						node.ArtBaseC0[b.Name] = b.C0
					end
					b.Transform = CFrame.identity
				end
			end
		end
	end

	local isHoldingLoot = node.Model:GetAttribute("CarryingLoot") == true
	local assetId = node.Model:GetAttribute("ArtPackAssetId")
	local isMarksman = (assetId == "hero_jenna" or assetId == "hero_astrea")
	local eqType = node.Model:GetAttribute("EquippedArtifactType")
	local eqId = node.Model:GetAttribute("EquippedArtifactId")
	local hasBow = (eqType == "BOW") or (isMarksman and eqId ~= nil and eqId ~= "")

	local moving = (node.GoalPos - node.CurrentPos).Magnitude > 0.15
	local wave = math.sin(time * 9)
	local breath = math.sin(time * 2)
	local animStart = (node :: any).AttackAnimStartClock or 0
	local animDur = (node :: any).AttackAnimDuration or 0.75
	local animElapsed = time - animStart
	local hasActiveAttackAnim = animStart > 0 and animElapsed >= 0 and animElapsed < animDur
	local attack = (node.StateEnum == 3) or hasActiveAttackAnim
	local attackTier: string = if hasActiveAttackAnim then ((node :: any).AttackAnimTier or "BASIC") else "BASIC"

	-- Toggle nocked HunterArrow visibility & animate bowstring nock point on the bow Handle
	if hasBow then
		local equipped = art:FindFirstChild("EquippedWeapon")
		local handle = equipped and (equipped:FindFirstChild("Handle") or equipped.PrimaryPart) :: BasePart?
		local stringNockAtt = handle and handle:FindFirstChild("StringNockAttachment") :: Attachment?
		local hunterArrow = equipped and equipped:FindFirstChild("HunterArrow", true)
		local hideNockedArrow = false
		local stringPull = 0.0
		if attack and not moving then
			local cycle = if hasActiveAttackAnim
				then math.clamp(animElapsed / math.max(0.25, animDur), 0, 1)
				else ((time * 1.35) % 1.0)
			local releaseStart = if attackTier == "SKILL" then 0.58 elseif attackTier == "SPECIAL" then 0.68 else 0.65
			local reNockStart = if attackTier == "SKILL" then 0.88 elseif attackTier == "SPECIAL" then 0.86 else 0.84
			hideNockedArrow = (cycle >= releaseStart and cycle < reNockStart)
			if cycle < releaseStart then
				stringPull = math.clamp(cycle / releaseStart, 0, 1) * 1.05
			end
		end
		if stringNockAtt then
			stringNockAtt.Position = Vector3.new(-1.26 - stringPull, 0, 0)
		end
		if hunterArrow then
			local targetTrans = if hideNockedArrow then 1 else 0
			if (node :: any)._arrowHidden ~= hideNockedArrow then
				(node :: any)._arrowHidden = hideNockedArrow
				for _, p in ipairs(hunterArrow:GetDescendants()) do
					if p:IsA("BasePart") then
						p.LocalTransparencyModifier = targetTrans
					end
				end
			end
		end
	end

	for name, b in pairs(node.ArtBones) do
		-- Do not override arms if the unit is actively hauling physical loot overhead
		if isHoldingLoot and (name:find("UpperArm") or name:find("Shoulder")) then
			continue
		end

		local target = CFrame.identity

		if moving then
			local sign = (name:find("Left") or name:find("L_")) and 1 or -1
			if name:find("UpperLeg") or name:find("Hip") then
				target = CFrame.Angles(wave * 0.45 * sign, 0, 0)
			elseif name:find("Knee") or name:find("LowerLeg") then
				target = CFrame.Angles(math.rad(-18) - math.max(0, wave * sign) * 0.35, 0, 0)
			elseif name == "LeftShoulder" or name == "LeftUpperArm" then
				if hasBow or isMarksman then
					-- Athletic Wind-Scout bow-ready jog (rig convention: +X swings arm forward / bends elbow)
					target = CFrame.Angles(math.rad(20) + wave * 0.08, math.rad(-14), math.rad(-18))
				else
					target = CFrame.Angles(-wave * 0.35 * sign, 0, 0)
				end
			elseif name == "LeftElbow" then
				if hasBow or isMarksman then
					target = CFrame.Angles(math.rad(28), 0, 0)
				end
			elseif name == "LeftWrist" then
				if hasBow or isMarksman then
					target = CFrame.Angles(math.rad(20), 0, math.rad(22))
				end
			elseif name == "RightShoulder" or name == "RightUpperArm" then
				target = CFrame.Angles(-wave * 0.32, math.rad(-6), math.rad(12))
			elseif name == "RightElbow" then
				target = CFrame.Angles(math.rad(32) + wave * 0.12, 0, 0)
			elseif name == "Waist" or name == "UpperTorso" then
				target = CFrame.Angles(math.rad(-8) + breath * 0.02, math.rad(-10), 0)
			elseif name == "Neck" then
				target = CFrame.Angles(math.rad(4), math.rad(10), 0)
			end
		elseif attack then
			if hasBow or isMarksman then
				local cycle = if hasActiveAttackAnim
					then math.clamp(animElapsed / math.max(0.25, animDur), 0, 1)
					else ((time * 1.35) % 1.0)

				if attackTier == "SKILL" then
					-- ============================================================
					-- TIER 3 SKILL (ULTIMATE): SYLPHID ARROW STORM
					-- 0.00..0.58: Wide-braced skyward arch & high-angle draw
					-- 0.58..0.84: Apex sky-flare release recoil
					-- 0.84..1.00: Smooth landing reset to ready posture
					-- ============================================================
					local drawAlpha = math.clamp(cycle / 0.58, 0, 1)
					local isRelease = cycle >= 0.58 and cycle < 0.84
					local isReset = cycle >= 0.84

					if name == "Root" then
						local dip = if isRelease then -0.12 elseif isReset then -0.05 else (-0.22 * drawAlpha)
						target = CFrame.new(0, dip, 0)
					elseif name == "Waist" or name == "UpperTorso" then
						local pitch = if isRelease then math.rad(30) elseif isReset then math.rad(8) else math.rad(24 * drawAlpha)
						target = CFrame.Angles(pitch, math.rad(-22), 0)
					elseif name == "Neck" then
						local pitch = if isRelease then math.rad(24) elseif isReset then math.rad(8) else math.rad(20 * drawAlpha)
						target = CFrame.Angles(pitch, math.rad(22), 0)
					elseif name == "LeftShoulder" or name == "LeftUpperArm" then
						local pitch = if isRelease
							then math.rad(114)
							elseif isReset then math.rad(55)
							else math.rad(45 + 60 * drawAlpha)
						target = CFrame.fromOrientation(pitch, math.rad(14), math.rad(-14))
					elseif name == "LeftElbow" then
						target = CFrame.Angles(if isReset then math.rad(32) else math.rad(6), 0, 0)
					elseif name == "RightShoulder" or name == "RightUpperArm" then
						if isRelease then
							target = CFrame.fromOrientation(math.rad(42), math.rad(52), math.rad(38))
						elseif isReset then
							target = CFrame.Angles(math.rad(24), math.rad(12), math.rad(-18))
						else
							target = CFrame.Angles(math.rad(30), math.rad(15), math.rad(-15)):Lerp(
								CFrame.fromOrientation(math.rad(30), math.rad(82), math.rad(22)),
								drawAlpha
							)
						end
					elseif name == "RightElbow" then
						if isRelease then
							target = CFrame.Angles(math.rad(52), 0, 0)
						elseif isReset then
							target = CFrame.Angles(math.rad(60), 0, 0)
						else
							target = CFrame.Angles(math.rad(55), 0, 0):Lerp(
								CFrame.fromOrientation(math.rad(68), math.rad(-158), math.rad(-160)),
								drawAlpha
							)
						end
					elseif name == "LeftHip" or name == "LeftUpperLeg" then
						target = CFrame.Angles(math.rad(18), math.rad(-6), math.rad(-8))
					elseif name == "LeftKnee" or name == "LeftLowerLeg" then
						target = CFrame.Angles(math.rad(-26), 0, 0)
					elseif name == "RightHip" or name == "RightUpperLeg" then
						target = CFrame.Angles(math.rad(-14), math.rad(8), math.rad(8))
					elseif name == "RightKnee" or name == "RightLowerLeg" then
						target = CFrame.Angles(math.rad(-22), 0, 0)
					end
				elseif attackTier == "SPECIAL" then
					-- ============================================================
					-- TIER 2 SPECIAL (EVERY 3RD HIT): PIERCING GALE VOLLEY
					-- 0.00..0.68: Deep crouch, 38-deg diagonal bow cant & heavy over-draw
					-- 0.68..0.86: Explosive gale recoil & whip follow-through
					-- 0.86..1.00: Smooth recovery to ready posture
					-- ============================================================
					local drawAlpha = math.clamp(cycle / 0.68, 0, 1)
					local isRelease = cycle >= 0.68 and cycle < 0.86
					local isReset = cycle >= 0.86

					if name == "Root" then
						local crouch = if isRelease then -0.22 elseif isReset then -0.08 else (-0.35 * drawAlpha)
						target = CFrame.new(0, crouch, 0)
					elseif name == "Waist" or name == "UpperTorso" then
						local pitch = if isRelease then math.rad(8) elseif isReset then math.rad(-4) else math.rad(-10 * drawAlpha)
						target = CFrame.Angles(pitch, math.rad(-28), 0)
					elseif name == "Neck" then
						local pitch = if isRelease then math.rad(-4) else math.rad(8 * drawAlpha)
						target = CFrame.Angles(pitch, math.rad(28), 0)
					elseif name == "LeftShoulder" or name == "LeftUpperArm" then
						local pitch = if isRelease
							then math.rad(92)
							elseif isReset then math.rad(48)
							else math.rad(35 + 50 * drawAlpha)
						target = CFrame.fromOrientation(pitch, math.rad(20), 0)
					elseif name == "LeftElbow" then
						target = CFrame.Angles(if isReset then math.rad(30) else math.rad(8), 0, 0)
					elseif name == "LeftWrist" then
						-- Diagonal 38-deg bow cant for horizontal gale volley
						local cant = if isReset then math.rad(12) else math.rad(38 * drawAlpha)
						target = CFrame.Angles(0, cant, 0)
					elseif name == "RightShoulder" or name == "RightUpperArm" then
						if isRelease then
							target = CFrame.fromOrientation(math.rad(24), math.rad(45), math.rad(38))
						elseif isReset then
							target = CFrame.Angles(math.rad(24), math.rad(14), math.rad(-20))
						else
							target = CFrame.Angles(math.rad(25), math.rad(14), math.rad(-18)):Lerp(
								CFrame.fromOrientation(math.rad(12), math.rad(84), math.rad(18)),
								drawAlpha
							)
						end
					elseif name == "RightElbow" then
						if isRelease then
							target = CFrame.Angles(math.rad(42), 0, 0)
						elseif isReset then
							target = CFrame.Angles(math.rad(58), 0, 0)
						else
							target = CFrame.Angles(math.rad(52), 0, 0):Lerp(
								CFrame.fromOrientation(math.rad(72), math.rad(-158), math.rad(-160)),
								drawAlpha
							)
						end
					elseif name == "LeftHip" or name == "LeftUpperLeg" then
						local hipPitch = if isReset then math.rad(14) else math.rad(10 + 16 * drawAlpha)
						target = CFrame.Angles(hipPitch, math.rad(-4), math.rad(-6))
					elseif name == "LeftKnee" or name == "LeftLowerLeg" then
						local kneeBend = if isReset then math.rad(-20) else math.rad(-16 - 20 * drawAlpha)
						target = CFrame.Angles(kneeBend, 0, 0)
					elseif name == "LeftAnkle" or name == "LeftFoot" then
						target = CFrame.Angles(math.rad(10), 0, 0)
					elseif name == "RightHip" or name == "RightUpperLeg" then
						local hipPitch = if isReset then math.rad(-10) else math.rad(-8 - 8 * drawAlpha)
						target = CFrame.Angles(hipPitch, math.rad(6), math.rad(6))
					elseif name == "RightKnee" or name == "RightLowerLeg" then
						local kneeBend = if isReset then math.rad(-16) else math.rad(-12 - 20 * drawAlpha)
						target = CFrame.Angles(kneeBend, 0, 0)
					elseif name == "RightAnkle" or name == "RightFoot" then
						target = CFrame.Angles(math.rad(24), 0, 0)
					end
				else
					-- ============================================================
					-- TIER 1 BASIC: WIND-STEP SHOT
					-- 0.00..0.65: Crisp draw to cheek along sightline
					-- 0.65..0.84: Snap release & bow kick
					-- 0.84..1.00: Quiver reach & re-nock
					-- ============================================================
					local drawAlpha = math.clamp(cycle / 0.65, 0, 1)
					local isRelease = cycle >= 0.65 and cycle < 0.84
					local isReset = cycle >= 0.84

					if name == "Waist" or name == "UpperTorso" then
						local pitch = if isRelease then math.rad(2) else math.rad(-2)
						target = CFrame.Angles(pitch, math.rad(-24), 0)
					elseif name == "Neck" then
						target = CFrame.Angles(math.rad(2), math.rad(24), 0)
					elseif name == "LeftShoulder" or name == "LeftUpperArm" then
						-- Bow arm rises smoothly to shoulder height and kicks slightly on release
						local pitch = if isRelease
							then math.rad(90)
							elseif isReset then math.rad(58)
							else math.rad(36 + 48 * drawAlpha)
						target = CFrame.fromOrientation(pitch, math.rad(18), 0)
					elseif name == "LeftElbow" then
						target = CFrame.Angles(if isReset then math.rad(24) else math.rad(6), 0, 0)
					elseif name == "RightShoulder" or name == "RightUpperArm" then
						if isRelease then
							-- Crisp archer follow-through flick past the ear
							target = CFrame.fromOrientation(math.rad(16), math.rad(56), math.rad(28))
						elseif isReset then
							-- Dip toward hip quiver & bring fresh arrow to string
							target = CFrame.Angles(math.rad(26), math.rad(14), math.rad(-18))
						else
							target = CFrame.Angles(math.rad(28), math.rad(16), math.rad(-16)):Lerp(
								CFrame.fromOrientation(math.rad(10), math.rad(82), math.rad(16)),
								drawAlpha
							)
						end
					elseif name == "RightElbow" then
						if isRelease then
							target = CFrame.Angles(math.rad(50), 0, 0)
						elseif isReset then
							target = CFrame.Angles(math.rad(64), 0, 0)
						else
							target = CFrame.Angles(math.rad(54), 0, 0):Lerp(
								CFrame.fromOrientation(math.rad(68), math.rad(-158), math.rad(-160)),
								drawAlpha
							)
						end
					elseif name == "RightWrist" then
						target = CFrame.fromOrientation(math.rad(9), math.rad(20), math.rad(4))
					elseif name == "LeftHip" or name == "LeftUpperLeg" then
						target = CFrame.Angles(math.rad(12), math.rad(-4), math.rad(-4))
					elseif name == "LeftKnee" or name == "LeftLowerLeg" then
						target = CFrame.Angles(math.rad(-18), 0, 0)
					elseif name == "LeftAnkle" or name == "LeftFoot" then
						target = CFrame.Angles(math.rad(6), 0, 0)
					elseif name == "RightHip" or name == "RightUpperLeg" then
						target = CFrame.Angles(math.rad(-10), math.rad(6), math.rad(5))
					elseif name == "RightKnee" or name == "RightLowerLeg" then
						target = CFrame.Angles(math.rad(-14), 0, 0)
					elseif name == "RightAnkle" or name == "RightFoot" then
						target = CFrame.Angles(math.rad(20), 0, 0)
					end
				end
			else
				-- Melee strike
				if name == "RightShoulder" or name == "RightUpperArm" then
					target = CFrame.Angles(0.6 + math.sin(time * 7) * 0.5, 0, 0)
				end
			end
		else
			-- ================================================================
			-- IDLE STANCE
			-- ================================================================
			if isMarksman or hasBow then
				-- Wind-Scout Ready Stance (contrapposto). Normalized R15 C0s in HeroModelBuilder:
				-- +X pitch swings limbs forward / bends elbows; knees bend with -X.
				local scan = math.sin(time * 0.6)
				if name == "Waist" or name == "UpperTorso" then
					target = CFrame.Angles(math.rad(-3) + breath * 0.015, math.rad(-18) + breath * 0.01, 0)
				elseif name == "Neck" then
					target = CFrame.Angles(0, math.rad(16) + scan * math.rad(6), 0)
				elseif name == "LeftShoulder" or name == "LeftUpperArm" then
					-- Bow arm held comfortably out to her left side in a low diagonal scout carry
					target = CFrame.Angles(math.rad(14) + breath * 0.012, math.rad(-18), math.rad(-22))
				elseif name == "LeftElbow" then
					target = CFrame.Angles(math.rad(24), 0, 0)
				elseif name == "LeftWrist" then
					-- Diagonal cant so the upper bow limb rises along her outer left side, clear of her face
					target = CFrame.Angles(math.rad(20), math.rad(24), math.rad(28))
				elseif name == "RightShoulder" or name == "RightUpperArm" then
					-- Draw hand relaxed outward at her right hip / quiver
					target = CFrame.Angles(math.rad(-6) + breath * 0.01, math.rad(-8), math.rad(14))
				elseif name == "RightElbow" then
					target = CFrame.Angles(math.rad(28) + breath * 0.01, 0, 0)
				elseif name == "LeftHip" or name == "LeftUpperLeg" then
					-- Front foot stepped slightly forward
					target = CFrame.Angles(math.rad(10) + breath * 0.005, math.rad(-4), math.rad(-4))
				elseif name == "LeftKnee" or name == "LeftLowerLeg" then
					target = CFrame.Angles(math.rad(-16), 0, 0)
				elseif name == "LeftAnkle" or name == "LeftFoot" then
					target = CFrame.Angles(math.rad(6), 0, 0)
				elseif name == "RightHip" or name == "RightUpperLeg" then
					-- Back leg braced
					target = CFrame.Angles(math.rad(-8) - breath * 0.005, math.rad(6), math.rad(5))
				elseif name == "RightKnee" or name == "RightLowerLeg" then
					target = CFrame.Angles(math.rad(-12), 0, 0)
				elseif name == "RightAnkle" or name == "RightFoot" then
					target = CFrame.Angles(math.rad(20), 0, 0)
				end
			else
				-- Relaxed natural idle stance when unequipped
				if name == "Waist" or name == "UpperTorso" then
					target = CFrame.Angles(breath * 0.015, 0, 0)
				elseif name == "LeftShoulder" or name == "LeftUpperArm" then
					target = CFrame.Angles(math.rad(-4) + breath * 0.01, 0, math.rad(4))
				elseif name == "LeftElbow" then
					target = CFrame.Angles(math.rad(-6), 0, 0)
				elseif name == "RightShoulder" or name == "RightUpperArm" then
					target = CFrame.Angles(math.rad(-4) + breath * 0.01, 0, math.rad(-4))
				elseif name == "RightElbow" then
					target = CFrame.Angles(math.rad(-6), 0, 0)
				elseif name == "LeftHip" or name == "LeftUpperLeg" then
					target = CFrame.Angles(0, 0, math.rad(2))
				elseif name == "RightHip" or name == "RightUpperLeg" then
					target = CFrame.Angles(0, 0, math.rad(-2))
				end
			end
		end

		local prevPose = (node.ArtPose and node.ArtPose[name]) or CFrame.identity
		local nextPose = prevPose:Lerp(target, math.clamp(dt * 16, 0, 1))
		if node.ArtPose then
			node.ArtPose[name] = nextPose
		end
		if b:IsA("Motor6D") and node.ArtBaseC0 and node.ArtBaseC0[name] then
			b.C0 = node.ArtBaseC0[name] * nextPose
			b.Transform = CFrame.identity
		else
			b.Transform = nextPose
		end
	end
end

function A.UnequipWeapon(model: Model)
	local art = model:FindFirstChild("ArtPackVisual") or model
	local current = art:FindFirstChild("EquippedWeapon")
	if current then
		current:Destroy()
	end
	local leftCurrent = art:FindFirstChild("EquippedWeaponLeft")
	if leftCurrent then
		leftCurrent:Destroy()
	end
	if model ~= art then
		local c2 = model:FindFirstChild("EquippedWeapon")
		if c2 then c2:Destroy() end
		local c3 = model:FindFirstChild("EquippedWeaponLeft")
		if c3 then c3:Destroy() end
	end
	model:SetAttribute("EquippedArtifactId", nil)
	model:SetAttribute("EquippedArtifactType", nil)
end

function A.EquipWeapon(model: Model, weaponAssetId: string?, weaponType: string?, rarityIndex: number?)
	local art = model:FindFirstChild("ArtPackVisual") or model
	if not art then return end

	-- Normalize empty string to nil
	if weaponAssetId == "" then weaponAssetId = nil end
	if weaponType == "" then weaponType = nil end

	-- Clean up previous weapon
	A.UnequipWeapon(model)

	if not weaponAssetId and not weaponType then return end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local weaponsFolder = assets and assets:FindFirstChild("Weapons") :: Folder?
	if not weaponsFolder and assets then
		local ok, WeaponModelBuilder = pcall(function()
			return require(assets:WaitForChild("WeaponModelBuilder", 2))
		end)
		if ok and WeaponModelBuilder and type(WeaponModelBuilder.EnsureWeapons) == "function" then
			weaponsFolder = WeaponModelBuilder.EnsureWeapons()
		end
	end
	if not weaponsFolder then return end

	-- Resolve template: try weaponAssetId, or map weaponType to weapon prefab
	local template: Model? = nil
	if weaponAssetId then
		template = weaponsFolder:FindFirstChild(weaponAssetId) :: Model?
		if not template then
			local Shared = ReplicatedStorage:FindFirstChild("Shared")
			local ArtifactCatalog = Shared and require(Shared:WaitForChild("Config"):WaitForChild("ArtifactCatalog"))
			if ArtifactCatalog and ArtifactCatalog.Seeds and ArtifactCatalog.Seeds[weaponAssetId] then
				local seed = ArtifactCatalog.Seeds[weaponAssetId]
				template = weaponsFolder:FindFirstChild(seed.ModelAssetId) :: Model?
				if not weaponType then
					weaponType = seed.Type
				end
			end
		end
	end
	if not template and weaponType then
		local typeMap = {
			BOW = "weapon_bow",
			SWORD_SHIELD = "weapon_sword_shield",
			DAGGERS = "weapon_daggers",
			AXE = "weapon_axe",
			STAFF = "weapon_staff",
			TOME = "weapon_tome",
		}
		local prefabName = typeMap[weaponType] or ("weapon_" .. weaponType:lower())
		template = weaponsFolder:FindFirstChild(prefabName) :: Model?
	end
	if not template then return end

	local wModel = template:Clone()
	wModel.Name = "EquippedWeapon"

	local rHand = art:FindFirstChild("RightHand", true) :: BasePart?
	local lHand = art:FindFirstChild("LeftHand", true) :: BasePart?

	-- Ensure draw attachment exists on RightHand for marksman bows
	if rHand and not rHand:FindFirstChild("DrawAttachment") then
		local drawAtt = Instance.new("Attachment")
		drawAtt.Name = "DrawAttachment"
		drawAtt.Position = Vector3.new(0, -0.3, 0)
		drawAtt.Parent = rHand
	end

	-- Make sure all BaseParts are uncollidable and massless
	for _, p in ipairs(wModel:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.Massless = true
			p.Anchored = false
		end
	end

	-- Per-artifact colours and rarity glow (shared with HeroLoadout)
	require((ReplicatedStorage:WaitForChild("Assets") :: any).WeaponModelBuilder).Style(wModel, weaponAssetId, rarityIndex)

	local effectiveType = weaponType or (if template.Name:find("bow") then "BOW" elseif template.Name:find("sword") then "SWORD_SHIELD" elseif template.Name:find("dagger") then "DAGGERS" elseif template.Name:find("axe") then "AXE" elseif template.Name:find("staff") then "STAFF" else "TOME")

	if effectiveType == "BOW" then
		local primary = wModel.PrimaryPart or wModel:FindFirstChild("Handle") or wModel:FindFirstChildWhichIsA("BasePart")
		local hunterArrow = wModel:FindFirstChild("HunterArrow", true)
		if primary and hunterArrow then
			local shaft = hunterArrow:FindFirstChild("ArrowShaft") :: BasePart?
			local head = hunterArrow:FindFirstChild("ArrowHead") :: BasePart?
			local f1 = hunterArrow:FindFirstChild("ArrowFletch_1") :: BasePart?
			local f2 = hunterArrow:FindFirstChild("ArrowFletch_2") :: BasePart?
			local f3 = hunterArrow:FindFirstChild("ArrowFletch_3") :: BasePart?
			if shaft then
				for _, d in ipairs(hunterArrow:GetDescendants()) do
					if d:IsA("WeldConstraint") or d:IsA("Weld") or d:IsA("Motor6D") then
						d:Destroy()
					end
				end
				for _, d in ipairs(wModel:GetDescendants()) do
					if (d:IsA("WeldConstraint") or d:IsA("Weld")) and (d.Part0 == shaft or d.Part1 == shaft) then
						d:Destroy()
					end
				end

				local pNock = Vector3.new(-1.25, 0.00, 0.28)
				local pShelf = Vector3.new(0.00, 0.18, 0.28)
				local dir = (pShelf - pNock).Unit
				local pCenter = pNock + dir * 1.0

				local shaftCFInHandle = CFrame.lookAt(pCenter, pCenter + dir, Vector3.new(0, 0, 1))
				local shaftWorld = primary.CFrame * shaftCFInHandle
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
					local w1 = Instance.new("WeldConstraint")
					w1.Part0 = shaft
					w1.Part1 = f1
					w1.Parent = f1
				end
				if f2 then
					f2.CFrame = shaftWorld * CFrame.new(-0.030, -0.018, 0.85) * CFrame.Angles(0, 0, math.rad(120))
					local w2 = Instance.new("WeldConstraint")
					w2.Part0 = shaft
					w2.Part1 = f2
					w2.Parent = f2
				end
				if f3 then
					f3.CFrame = shaftWorld * CFrame.new(0.030, -0.018, 0.85) * CFrame.Angles(0, 0, math.rad(-120))
					local w3 = Instance.new("WeldConstraint")
					w3.Part0 = shaft
					w3.Part1 = f3
					w3.Parent = f3
				end

				local wHandle = Instance.new("WeldConstraint")
				wHandle.Part0 = primary
				wHandle.Part1 = shaft
				wHandle.Parent = shaft
			end
		end

		if lHand then
			if primary then
				-- Natural archer's grip in hand space: Handle +X (arrow) points down the forearm (-Y),
				-- Handle +Z (TopLimb) points out the thumb side of LeftHand (-Z), and Handle +Y (arrow shelf)
				-- rests on the inner/upper side (-X). With the arm extended forward the stave stands
				-- vertical and the arrow points straight at the target.
				local bowGripOffset = CFrame.fromMatrix(Vector3.new(0, -0.05, 0), Vector3.new(0, -1, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1))
				wModel:PivotTo(lHand.CFrame * bowGripOffset)
				-- Explicit Weld (not WeldConstraint): a WeldConstraint captures whatever offset
				-- exists when it activates, which drifts once the hand is posed by Animate and
				-- leaves the bow floating away from her grip.
				local weld = Instance.new("Weld")
				weld.Name = "BowGripWeld"
				weld.Part0 = lHand
				weld.Part1 = primary
				weld.C0 = bowGripOffset
				weld.Parent = primary

				-- Connect bowstring beams to Handle.StringNockAttachment (NOT RightHand!)
				-- so the bowstring stays taut between the bow limb tips in Idle/Walk and only pulls back along the bow during Draw.
				local stringNockAtt = primary:FindFirstChild("StringNockAttachment") :: Attachment?
				if not stringNockAtt then
					stringNockAtt = Instance.new("Attachment")
					stringNockAtt.Name = "StringNockAttachment"
					stringNockAtt.Position = Vector3.new(-1.26, 0, 0)
					stringNockAtt.Parent = primary
				else
					stringNockAtt.Position = Vector3.new(-1.26, 0, 0)
				end
				for _, beam in ipairs(wModel:GetDescendants()) do
					if beam:IsA("Beam") then
						beam.Attachment1 = stringNockAtt
					end
				end
			end
		end
		wModel.Parent = art
	elseif effectiveType == "DAGGERS" then
		local leftDagger = wModel:FindFirstChild("LeftDagger")
		if leftDagger and lHand then
			leftDagger.Name = "EquippedWeaponLeft"
			local lPrimary = (leftDagger :: any).PrimaryPart or leftDagger:FindFirstChild("HandleL") or leftDagger:FindFirstChildWhichIsA("BasePart")
			if lPrimary then
				leftDagger:PivotTo(lHand.CFrame * CFrame.Angles(math.rad(180), 0, 0))
				local weldL = Instance.new("WeldConstraint")
				weldL.Part0 = lHand
				weldL.Part1 = lPrimary
				weldL.Parent = lPrimary
			end
			leftDagger.Parent = art
		end
		if rHand then
			local primary = wModel.PrimaryPart or wModel:FindFirstChild("Handle") or wModel:FindFirstChildWhichIsA("BasePart")
			if primary then
				wModel:PivotTo(rHand.CFrame * CFrame.Angles(math.rad(180), 0, 0))
				local weldR = Instance.new("WeldConstraint")
				weldR.Part0 = rHand
				weldR.Part1 = primary
				weldR.Parent = primary
			end
		end
		wModel.Parent = art
	elseif effectiveType == "SWORD_SHIELD" then
		local shieldModel = wModel:FindFirstChild("OffhandShield")
		if shieldModel and art:FindFirstChild("KiteShield", true) then
			-- Rig already carries a sculpted shield (e.g. Aaron); keep only the sword
			shieldModel:Destroy()
		elseif shieldModel and lHand then
			shieldModel.Name = "EquippedWeaponLeft"
			local sPrimary = (shieldModel :: any).PrimaryPart or shieldModel:FindFirstChild("HandleS") or shieldModel:FindFirstChildWhichIsA("BasePart")
			if sPrimary then
				shieldModel:PivotTo(lHand.CFrame * CFrame.Angles(math.rad(-90), 0, 0))
				local weldS = Instance.new("WeldConstraint")
				weldS.Part0 = lHand
				weldS.Part1 = sPrimary
				weldS.Parent = sPrimary
			end
			shieldModel.Parent = art
		end
		if rHand then
			local primary = wModel.PrimaryPart or wModel:FindFirstChild("Handle") or wModel:FindFirstChildWhichIsA("BasePart")
			if primary then
				wModel:PivotTo(rHand.CFrame * CFrame.Angles(math.rad(-90), 0, 0))
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = rHand
				weld.Part1 = primary
				weld.Parent = primary
			end
		end
		wModel.Parent = art
	else
		-- AXE, STAFF, TOME: Main hand (RightHand)
		if rHand then
			local primary = wModel.PrimaryPart or wModel:FindFirstChild("Handle") or wModel:FindFirstChildWhichIsA("BasePart")
			if primary then
				wModel:PivotTo(rHand.CFrame * CFrame.Angles(math.rad(-90), 0, 0))
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = rHand
				weld.Part1 = primary
				weld.Parent = primary
			end
		end
		wModel.Parent = art
	end

	model:SetAttribute("EquippedArtifactId", weaponAssetId or template.Name)
	model:SetAttribute("EquippedArtifactType", effectiveType)
end

return A
