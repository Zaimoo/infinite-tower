--!nocheck
-- tests/studio-gilded-anvil-import.luau
-- Studio (Edit mode) helper to finalize imported Gilded Anvil FBX models from assets/artifacts/gilded_anvil/*.fbx.
-- Run via Studio Command Bar or Studio MCP execute_luau after importing one or more art_gild_* FBX files
-- into Workspace via Roblox Studio's 3D Importer (kept as separate parts, named after the FBX file).
--
-- For every imported art_gild_* model present in Workspace, it:
--   - Strips Blender duplicate numeric suffixes (.001..), preserves SubCollections (OffhandShield, LeftDagger, HunterArrow)
--   - Applies sculpted GildedAnvilMeshData materials, colors, transparency, and DoubleSided flags
--   - Wires Handle / HandleS / HandleL welds, GildAnimWeld_* animated pivots, and Grip/Tip/Vfx/Bow/Shield sockets
--   - Applies Band 6 WeaponVfx and saves the finalized prefab into ReplicatedStorage.Assets.Weapons
--   - Returns a JSON summary + Luau MeshId map for GildedAnvilMeshes shards.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local GildedAnvilMeshData = require(Assets:WaitForChild("GildedAnvilMeshData"))

local weaponsFolder = Assets:FindFirstChild("Weapons")
if not weaponsFolder then
	weaponsFolder = Instance.new("Folder")
	weaponsFolder.Name = "Weapons"
	weaponsFolder.Parent = Assets
end

local combatVfx = Assets:FindFirstChild("CombatVfx")
local okVfx, WeaponVfx = pcall(require, combatVfx and combatVfx:FindFirstChild("WeaponVfx"))

local EDGE_PLUS_X = Vector3.new(0, -90, 0)
local AXE_HAND_GAP = 1.7
local ARROW_REST = Vector3.new(0.10, 0.22, -0.40)

local SPECS = {
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

local function setWeaponSpaceAttachment(primary: BasePart, weaponOriginCF: CFrame, attName: string, weaponPos: Vector3, rotDeg: Vector3?)
	local rot = rotDeg or Vector3.zero
	local worldCF = weaponOriginCF * CFrame.new(weaponPos) * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
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

local function processWeapon(templateId: string, spec)
	local source = workspace:FindFirstChild(templateId)
	if not source then
		return nil, `MISSING {templateId} in Workspace`
	end

	local meshSpecs = GildedAnvilMeshData.Weapons[templateId]
	if not meshSpecs then
		return nil, `MISSING GildedAnvilMeshData entry for {templateId}`
	end

	local byCleanName: { [string]: { MeshPart } } = {}
	for _, desc in ipairs(source:GetDescendants()) do
		if desc:IsA("MeshPart") then
			local clean = string.gsub(desc.Name, "%.%d+$", "")
			byCleanName[clean] = byCleanName[clean] or {}
			table.insert(byCleanName[clean], desc)
		end
	end

	local model = Instance.new("Model")
	model.Name = templateId
	model:SetAttribute("IsGildforged", true)
	model:SetAttribute("WeaponTemplateId", templateId)

	local subModels: { [string]: Model } = {}
	if templateId == "art_gild_dawnwarden_oath" then
		local m = Instance.new("Model")
		m.Name = "OffhandShield"
		m.Parent = model
		subModels.OffhandShield = m
	elseif templateId == "art_gild_eclipse_sisters" then
		local m = Instance.new("Model")
		m.Name = "LeftDagger"
		m.Parent = model
		subModels.LeftDagger = m
	elseif templateId == "art_gild_aurora_skyhook" then
		local m = Instance.new("Model")
		m.Name = "HunterArrow"
		m.Parent = model
		subModels.HunterArrow = m
	end

	local primaries: { [string]: BasePart } = {}
	local partAssembly: { [BasePart]: string } = {}
	local animRecords = {}
	local meshIds: { [string]: string } = {}

	local originOffset: Vector3? = nil
	local originRot = CFrame.identity

	for _, pData in ipairs(meshSpecs) do
		local bucket = byCleanName[pData.Name]
		local mp = bucket and table.remove(bucket, 1)
		if not mp then
			model:Destroy()
			return nil, `SKIPPED {templateId}: missing MeshPart '{pData.Name}'`
		end

		for _, c in ipairs(mp:GetChildren()) do
			if c:IsA("JointInstance") or c:IsA("WeldConstraint") or c:IsA("Attachment") then
				c:Destroy()
			end
		end

		mp.Name = pData.Name
		mp.Material = pData.Material
		mp.Color = pData.Color
		mp.Transparency = if templateId == "art_gild_evergarden_codex" and pData.Name == "Handle"
			then 1
			else pData.Transparency
		pcall(function()
			mp.DoubleSided = pData.DoubleSided == true
		end)
		mp.CanCollide = false
		mp.CanTouch = false
		mp.CanQuery = false
		mp.Massless = true
		mp.Anchored = false
		mp.CastShadow = false
		meshIds[pData.Name] = mp.MeshId

		if not originOffset then
			originOffset = pData.Offset
			originRot = mp.CFrame.Rotation
		end

		local subCol = pData.SubCollection or ""
		local primaryKey = "Main"
		if subCol ~= "" and subModels[subCol] then
			mp.Parent = subModels[subCol]
			if subCol == "OffhandShield" then
				primaryKey = "OffhandShield"
				if pData.Name == "HandleS" then
					subModels.OffhandShield.PrimaryPart = mp
					primaries.OffhandShield = mp
				end
			elseif subCol == "LeftDagger" then
				primaryKey = "LeftDagger"
				if pData.Name == "HandleL" then
					subModels.LeftDagger.PrimaryPart = mp
					primaries.LeftDagger = mp
				end
			end
		else
			mp.Parent = model
			if pData.Name == "Handle" then
				model.PrimaryPart = mp
				primaries.Main = mp
			end
		end

		partAssembly[mp] = primaryKey
		if pData.AnimRole and pData.AnimRole ~= "" then
			mp:SetAttribute("GildAnimRole", pData.AnimRole)
			table.insert(animRecords, {
				Part = mp,
				Role = pData.AnimRole,
				PivotOffset = pData.PivotOffset or pData.Offset,
			})
		end
	end

	local handle = primaries.Main
	if not handle then
		model:Destroy()
		return nil, `SKIPPED {templateId}: missing Handle MeshPart`
	end

	local handleSpecOffset = Vector3.zero
	for _, pData in ipairs(meshSpecs) do
		if pData.Name == "Handle" then
			handleSpecOffset = pData.Offset
			break
		end
	end
	local weaponOriginCF = handle.CFrame * CFrame.new(-handleSpecOffset)

	local animByPart = {}
	for _, rec in ipairs(animRecords) do
		animByPart[rec.Part] = rec
	end

	for part, key in pairs(partAssembly) do
		local root = primaries[key]
		if root and part ~= root then
			local rec = animByPart[part]
			if rec then
				local weld = Instance.new("Weld")
				weld.Name = "GildAnimWeld_" .. part.Name
				weld.Part0 = root
				weld.Part1 = part
				weld.C0 = root.CFrame:ToObjectSpace(weaponOriginCF * CFrame.new(rec.PivotOffset))
				weld.C1 = part.CFrame:ToObjectSpace(root.CFrame * weld.C0)
				weld:SetAttribute("BaseC0", weld.C0)
				weld:SetAttribute("GildAnimRole", rec.Role)
				weld.Parent = root
			else
				local w = Instance.new("WeldConstraint")
				w.Part0 = root
				w.Part1 = part
				w.Parent = root
			end
		end
	end

	setWeaponSpaceAttachment(handle, weaponOriginCF, "Grip", spec.GripPos, spec.GripRotDeg)
	if spec.OffhandGripPos then
		setWeaponSpaceAttachment(handle, weaponOriginCF, "OffhandGrip", spec.OffhandGripPos, spec.GripRotDeg)
	end
	if spec.Type == "BOW" then
		setWeaponSpaceAttachment(handle, weaponOriginCF, "Nock", Vector3.new(ARROW_REST.X, ARROW_REST.Y, 0.50))
		setWeaponSpaceAttachment(handle, weaponOriginCF, "TipUpper", Vector3.new(0, 1.96, 0.50))
		setWeaponSpaceAttachment(handle, weaponOriginCF, "TipLower", Vector3.new(0, -1.96, 0.50))
		setWeaponSpaceAttachment(handle, weaponOriginCF, "BowStringTop", Vector3.new(0, 1.96, 0.50))
		setWeaponSpaceAttachment(handle, weaponOriginCF, "BowStringBottom", Vector3.new(0, -1.96, 0.50))
	end
	setWeaponSpaceAttachment(handle, weaponOriginCF, "Tip", spec.TipPos)
	setWeaponSpaceAttachment(handle, weaponOriginCF, "VfxTip", spec.TipPos)
	setWeaponSpaceAttachment(handle, weaponOriginCF, "VfxBase", spec.BasePos)
	setWeaponSpaceAttachment(handle, weaponOriginCF, "VfxCore", spec.CorePos)
	if spec.TrailTopPos then
		setWeaponSpaceAttachment(handle, weaponOriginCF, "TrailTop", spec.TrailTopPos)
	end
	if spec.TrailBottomPos then
		setWeaponSpaceAttachment(handle, weaponOriginCF, "TrailBottom", spec.TrailBottomPos)
	end

	if primaries.OffhandShield then
		local hs = primaries.OffhandShield
		setWeaponSpaceAttachment(hs, weaponOriginCF, "ShieldMount", Vector3.new(-0.18, 0, 0), Vector3.new(0, 90, 0))
		setWeaponSpaceAttachment(hs, weaponOriginCF, "VfxShieldCenter", Vector3.new(-0.54, 0.24, 0))
	end
	if primaries.LeftDagger then
		local hl = primaries.LeftDagger
		setWeaponSpaceAttachment(hl, weaponOriginCF, "Grip", spec.GripPos, spec.GripRotDeg)
		setWeaponSpaceAttachment(hl, weaponOriginCF, "Tip", Vector3.new(0, 2.52, 0))
		setWeaponSpaceAttachment(hl, weaponOriginCF, "VfxTip", Vector3.new(0, 2.52, 0))
		setWeaponSpaceAttachment(hl, weaponOriginCF, "VfxBase", Vector3.new(0, 0.46, 0))
		setWeaponSpaceAttachment(hl, weaponOriginCF, "VfxCore", Vector3.new(0, 1.42, 0))
		setWeaponSpaceAttachment(hl, weaponOriginCF, "TrailTop", Vector3.new(0, 2.48, 0))
		setWeaponSpaceAttachment(hl, weaponOriginCF, "TrailBottom", Vector3.new(0, 0.48, 0))
	end

	if okVfx and WeaponVfx and WeaponVfx.Apply then
		pcall(WeaponVfx.Apply, model, spec.Type, 8, templateId)
	end

	local old = weaponsFolder:FindFirstChild(templateId)
	if old then
		old:Destroy()
	end
	model.Parent = weaponsFolder
	source:Destroy()
	return meshIds, `OK {templateId} ({#meshSpecs} MeshParts)`
end

local status = {}
local exportedIds = {}
for id, spec in pairs(SPECS) do
	local ids, msg = processWeapon(id, spec)
	table.insert(status, msg)
	if ids then
		exportedIds[id] = ids
	end
end
table.sort(status)

return table.concat(status, "\n") .. "\n\n" .. HttpService:JSONEncode(exportedIds)
