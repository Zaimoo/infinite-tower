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
		if found and found:IsA("Model") then return found end
	end

	-- Search across all other asset subfolders
	for _, folder in ipairs(assets:GetChildren()) do
		if folder:IsA("Folder") and folder.Name ~= "Heroes" then
			local found = folder:FindFirstChild(resolved)
			if found and found:IsA("Model") then return found end
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
				p.Anchored = (p.Name == "HumanoidRootPart")
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

	local art = A.AttachAt(model, id, root.CFrame * CFrame.new(0, -bodySize.Y * 0.5, 0), 1)
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
			head.Transparency = 1
		end

		-- For R15 models, weld art HumanoidRootPart to the root entity part
		local artHrp = art:FindFirstChild("HumanoidRootPart") :: BasePart?
		if artHrp then
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
				angle = -wave * 0.35 * sign
			end
		elseif attack then
			if isMarksman then
				-- Marksman rifle aim + recoil
				if name == "RightUpperArm" or name == "RightShoulder" then
					angle = -1.25 + math.sin(time * 16) * 0.15 -- Aim rifle forward with recoil kick
				elseif name == "LeftUpperArm" or name == "LeftShoulder" then
					angle = -1.1 + math.sin(time * 16) * 0.08 -- Support rifle barrel with left hand
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

return A
