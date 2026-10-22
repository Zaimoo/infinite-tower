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
		for _, b in ipairs(art:GetDescendants()) do
			if b:IsA("Motor6D") or b:IsA("Bone") then
				node.ArtBones[b.Name] = b
			end
		end
	end

	local isHoldingLoot = node.Model:GetAttribute("CarryingLoot") == true
	local assetId = node.Model:GetAttribute("ArtPackAssetId")
	local isMarksman = (assetId == "hero_jenna")

	local moving = (node.GoalPos - node.CurrentPos).Magnitude > 0.15
	local wave = math.sin(time * 9)
	local attack = node.StateEnum == 3

	for name, b in pairs(node.ArtBones) do
		-- Do not override arms if the unit is actively hauling physical loot overhead
		if isHoldingLoot and (name:find("UpperArm") or name:find("Shoulder")) then
			continue
		end

		local angle = 0
		if moving then
			local sign = (name:find("Left") or name:find("L_")) and 1 or -1
			if name:find("UpperLeg") or name:find("Hip") then
				angle = wave * 0.45 * sign
			elseif name:find("UpperArm") or name:find("Shoulder") then
				if isMarksman then
					-- When running, marksman keeps bow raised forward with athletic stride bounce
					angle = math.sin(time * 9) * 0.08
				else
					angle = -wave * 0.35 * sign
				end
			end
		elseif attack then
			if isMarksman then
				-- Marksman bow draw & snap release cycle (3.5 Hz)
				-- 70% draw tension build-up, 10% snap release, 20% nock reset
				local cycle = (time * 3.5) % 1.0
				local drawTension = 0
				if cycle < 0.7 then
					drawTension = (cycle / 0.7) * 0.35
				elseif cycle < 0.8 then
					drawTension = -0.15
				else
					drawTension = -0.15 * (1 - (cycle - 0.8) / 0.2)
				end

				if name == "RightUpperArm" or name == "RightShoulder" then
					angle = drawTension -- Pulls drawing arm back under arrow tension
				elseif name == "LeftUpperArm" or name == "LeftShoulder" then
					angle = -drawTension * 0.25 -- Subtle forward bow thrust under string tension
				end
			else
				-- Melee strike
				if name == "RightUpperArm" or name == "RightShoulder" then
					angle = -0.6 - math.sin(time * 7) * 0.5
				end
			end
		elseif name == "UpperTorso" or name == "Waist" then
			angle = math.sin(time * 2) * 0.015
		end

		local target = CFrame.Angles(angle, 0, 0)
		b.Transform = b.Transform:Lerp(target, math.clamp(dt * 16, 0, 1))
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
	model:SetAttribute("EquippedArtifactId", nil)
	model:SetAttribute("EquippedArtifactType", nil)
end

function A.EquipWeapon(model: Model, weaponAssetId: string?, weaponType: string?, rarityIndex: number?)
	local art = model:FindFirstChild("ArtPackVisual") or model
	if not art then return end

	-- Clean up previous weapon
	A.UnequipWeapon(model)

	if not weaponAssetId and not weaponType then return end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local weaponsFolder = assets and assets:FindFirstChild("Weapons")
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
			SWORD = "weapon_sword",
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

	-- Optional Rarity visual flair:
	-- If Rarity >= 6 (Legendary+), add subtle glow or tint
	if rarityIndex and rarityIndex >= 6 then
		local Shared = ReplicatedStorage:FindFirstChild("Shared")
		local ArtifactCatalog = Shared and require(Shared:WaitForChild("Config"):WaitForChild("ArtifactCatalog"))
		if ArtifactCatalog then
			local rInfo = ArtifactCatalog.GetRarityInfo(rarityIndex)
			if rInfo then
				for _, p in ipairs(wModel:GetDescendants()) do
					if p:IsA("BasePart") and (p.Name:find("Blade") or p.Name:find("Tip") or p.Name:find("Orb") or p.Name:find("Crystal")) then
						if rarityIndex >= 14 then
							p.Material = Enum.Material.Neon
							p.Color = rInfo.Color
						end
					end
				end
			end
		end
	end

	local effectiveType = weaponType or (if template.Name:find("bow") then "BOW" elseif template.Name:find("sword") then "SWORD" elseif template.Name:find("dagger") then "DAGGERS" elseif template.Name:find("axe") then "AXE" elseif template.Name:find("staff") then "STAFF" else "TOME")

	if effectiveType == "BOW" then
		if lHand then
			local primary = wModel.PrimaryPart or wModel:FindFirstChild("Handle") or wModel:FindFirstChildWhichIsA("BasePart")
			if primary then
				-- Natural canted archery grip orientation: stave extends vertically, limbs arc forward, arrow points forward
				local bowGripOffset = CFrame.new(0, 0, 0, -0.728371143, 0.685157061, -0.00618805084, -0.647984505, -0.685861766, 0.331232011, -0.222700208, -0.245268837, -0.943533182)
				wModel:PivotTo(lHand.CFrame * bowGripOffset)
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = lHand
				weld.Part1 = primary
				weld.Parent = primary
			end
			-- Connect bowstring beams to RightHand.DrawAttachment
			local drawAtt = rHand and rHand:FindFirstChild("DrawAttachment") :: Attachment?
			if drawAtt then
				for _, beam in ipairs(wModel:GetDescendants()) do
					if beam:IsA("Beam") then
						beam.Attachment1 = drawAtt
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
	else
		-- SWORD, AXE, STAFF, TOME: Main hand (RightHand)
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
