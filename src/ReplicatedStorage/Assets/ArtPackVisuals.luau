--!strict
-- ReplicatedStorage/Assets/ArtPackVisuals.luau
-- Asset manager: resolves and attaches art-pack templates (heroes, mobs, props), and runs a
-- generic procedural animator for non-hero rigs. Heroes are equipped and animated by
-- Assets/HeroRig (HeroLoadout, HeroAnimator).

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

	-- Generic poses for art-pack rigs that are not heroes (hub mobs, bosses). Heroes are
	-- animated by HeroRig/HeroAnimator.
	local isHoldingLoot = node.Model:GetAttribute("CarryingLoot") == true
	local moving = (node.GoalPos - node.CurrentPos).Magnitude > 0.15
	local wave = math.sin(time * 9)
	local breath = math.sin(time * 2)
	local attack = node.StateEnum == 3

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
				target = CFrame.Angles(-wave * 0.35 * sign, 0, 0)
			elseif name == "RightShoulder" or name == "RightUpperArm" then
				target = CFrame.Angles(-wave * 0.32, 0, 0)
			elseif name == "Waist" or name == "UpperTorso" then
				target = CFrame.Angles(math.rad(-6) + breath * 0.02, 0, 0)
			end
		elseif attack then
			-- Melee strike
			if name == "RightShoulder" or name == "RightUpperArm" then
				target = CFrame.Angles(0.6 + math.sin(time * 7) * 0.5, 0, 0)
			end
		else
			-- Relaxed idle
			if name == "Waist" or name == "UpperTorso" then
				target = CFrame.Angles(breath * 0.015, 0, 0)
			elseif name == "LeftShoulder" or name == "LeftUpperArm" then
				target = CFrame.Angles(math.rad(4) + breath * 0.01, 0, math.rad(-4))
			elseif name == "RightShoulder" or name == "RightUpperArm" then
				target = CFrame.Angles(math.rad(4) + breath * 0.01, 0, math.rad(4))
			elseif name == "LeftElbow" or name == "RightElbow" then
				target = CFrame.Angles(math.rad(6), 0, 0)
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

return A
