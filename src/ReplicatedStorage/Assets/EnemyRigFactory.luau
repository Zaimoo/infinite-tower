--!strict
-- One way to build a tower enemy's rig (docs/tower-mob-remodel-plan.md §6.3), used by the tower renderer
-- (EnemyAnimationController), the hub patrol and the Facility preview.
--
-- Remodelled enemies ship as imported template models in ReplicatedStorage.TowerEnemyTemplates.<enemyId>
-- (a folder Rojo ignores, saved with the place; tests/studio-enemy-template-prep.luau makes them):
-- MeshParts named after their joint ("Body", "ArmL", "Leg-1_2"...) or "<Joint>_Glow_<Colour>" /
-- "<Joint>_..." for pieces welded to a joint, laid out in model space (origin on the ground under the enemy,
-- facing -Z). TowerEnemyModelIndex holds each joint's parent and pivot. The factory clones the template,
-- places it on the entity root and wires one Motor6D per joint, axis-aligned with the model so the existing
-- TowerEnemyClips poses drive it unchanged. Enemies without a template use the part rig (TowerEnemyRigs).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.FirstBiomeCombat)
local Index = require(ReplicatedStorage.Shared.Config.TowerEnemyModelIndex)
local Rigs = require(script.Parent.TowerEnemyRigs)
local EnemyAnimator = require(script.Parent.EnemyAnimator)

local Factory = {}

local ALPHA_SCALE = 1.4 -- Alphas spawn 1.4x their Elite (MobCatalog bounds)
-- Remodelled enemies render 1.25x their Blender size (2026-11-09 review). Scaling is about the ground point
-- under the enemy, so feet stay planted; hitboxes and server stats are unchanged.
Factory.RemodelScale = 1.25
local templatesFolder: Instance? = ReplicatedStorage:FindFirstChild("TowerEnemyTemplates")

local function template(enemyId: string): Model?
	templatesFolder = templatesFolder or ReplicatedStorage:FindFirstChild("TowerEnemyTemplates")
	local t = templatesFolder and templatesFolder:FindFirstChild(enemyId)
	return if t and t:IsA("Model") then t else nil
end

-- How much taller the drawn enemy is than its combat Height (1 for the part rig), for overhead UI.
function Factory.HeightScale(enemyId: string): number
	local spec = Config.Get(enemyId)
	local entry = Index[enemyId]
	if not spec or not entry or not template(enemyId) then return 1 end
	local drawn = entry.Height * (if spec.Alpha then ALPHA_SCALE else 1) * Factory.RemodelScale
	return math.max(1, drawn / math.max(1, spec.Height or drawn))
end

-- True when the enemy has a remodelled template and index entry.
function Factory.HasModel(enemyId: string): boolean
	return Index[enemyId] ~= nil and template(enemyId) ~= nil
end

local function prep(p: BasePart, netId: any)
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p:SetAttribute("NetId", netId)
end

local function buildModel(model: Model, root: BasePart, enemyId: string): any
	local spec = assert(Config.Get(enemyId), "Missing tower enemy spec: " .. enemyId)
	local entry = Index[enemyId]
	local source = assert(template(enemyId))
	local s = (if spec.Alpha then ALPHA_SCALE else 1) * Factory.RemodelScale
	local folder = Instance.new("Model")
	folder.Name = "TowerEnemyArt"
	folder.Parent = model
	local ground = root.CFrame * CFrame.new(0, -(spec.RootHeight or 0), 0)
	local rig: any = { Joints = {}, Parts = {}, Root = root, Model = folder, Spec = spec, EnemyId = enemyId, Distance = 0, Remodel = true }
	local netId = model:GetAttribute("NetId")

	-- Clone every mesh, scaled and placed in model space, then on the root.
	local frames: { [string]: CFrame } = {}
	local parts: { [string]: BasePart } = {}
	-- The 3D Importer drops vertex/material colour, so glow meshes arrive as grey Neon (renders white).
	local glowColours: { [string]: Color3 } = {}
	for _, seg in entry.Segments do
		for _, g in seg.Glow do glowColours[g.Mesh] = g.Colour end
	end
	for _, d in source:GetDescendants() do
		if d:IsA("BasePart") then
			local p = d:Clone()
			local local_ = d.CFrame -- the template sits at the origin
			local placed = CFrame.new(local_.Position * s) * local_.Rotation
			p.Size = d.Size * s
			p.CFrame = ground * placed
			prep(p, netId)
			local glowColour = glowColours[d.Name]
			if glowColour then
				p.Color = glowColour
				p.Material = Enum.Material.Neon
			end
			p.Parent = folder
			frames[d.Name] = placed
			parts[d.Name] = p
			table.insert(rig.Parts, p)
		end
	end

	-- Joints at the index pivots; everything else welds to its joint.
	local jointNames: { [string]: boolean } = {}
	for _, seg in entry.Segments do jointNames[seg.Name] = true end
	local rootFrame = CFrame.new(0, spec.RootHeight or 0, 0)
	for _, seg in entry.Segments do
		local part = parts[seg.Name]
		if not part then
			-- glow-only joint: an invisible carrier at the pivot
			local carrier = Instance.new("Part")
			carrier.Name = seg.Name
			carrier.Size = Vector3.new(0.2, 0.2, 0.2)
			carrier.Transparency = 1
			carrier.CFrame = ground * CFrame.new(seg.Pivot * s)
			prep(carrier, netId)
			carrier.Parent = folder
			parts[seg.Name] = carrier
			frames[seg.Name] = CFrame.new(seg.Pivot * s)
			part = carrier
		end
		local parentPart = if seg.Parent then parts[seg.Parent] else root
		local parentFrame = if seg.Parent then frames[seg.Parent] else rootFrame
		local pivot = CFrame.new(seg.Pivot * s)
		local j = Instance.new("Motor6D")
		j.Name = seg.Name
		j.Part0 = parentPart
		j.Part1 = part
		local bind = parentFrame:Inverse() * pivot
		j.C0 = bind
		j.C1 = frames[seg.Name]:Inverse() * pivot
		j.Parent = parentPart
		rig.Joints[seg.Name] = { Motor = j, Bind = bind }
	end
	for name, p in parts do
		if not jointNames[name] then
			-- "<Joint>_Glow_<Colour>" or "<Joint>_<anything>": weld to the longest matching joint name
			local best: string? = nil
			for joint in jointNames do
				if string.sub(name, 1, #joint + 1) == joint .. "_" and (not best or #joint > #best) then best = joint end
			end
			local w = Instance.new("WeldConstraint")
			w.Part0 = parts[best or entry.Segments[1].Name]
			w.Part1 = p
			w.Parent = p
		end
	end

	if spec.Support then
		-- Supports keep their floating halo of glowing beads (TowerEnemyRigs), readable from a distance.
		local haloY = math.max(spec.Height or 6, entry.Height * s) - (spec.RootHeight or 3) + 1.1
		local glow = Color3.fromRGB(150, 255, 160)
		for i = 0, 8 do
			local bead = Instance.new("Part")
			bead.Name = if i == 0 then "SupportHaloCore" else "SupportHaloBead"
			bead.Shape = Enum.PartType.Ball
			bead.Size = if i == 0 then Vector3.new(0.6, 0.6, 0.6) else Vector3.new(0.45, 0.45, 0.45)
			bead.Material = Enum.Material.Neon
			bead.Color = glow
			bead.CastShadow = false
			local a = i * math.pi / 4
			bead.CFrame = root.CFrame * (if i == 0 then CFrame.new(0, haloY + 0.1, 0) else CFrame.new(math.cos(a) * 1.15, haloY, math.sin(a) * 1.15))
			prep(bead, netId)
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = root, bead
			w.Parent = bead
			bead.Parent = folder
			table.insert(rig.Parts, bead)
		end
	end

	rig.Metrics = EnemyAnimator.Metrics(enemyId, spec, entry, s)
	model:SetAttribute("TowerEnemyId", enemyId)
	folder:SetAttribute("Source", "TowerEnemies/" .. enemyId)
	folder:SetAttribute("RigFamily", spec.RigFamily)
	return rig
end

-- Build an enemy's rig on `model`/`root`: the remodelled template when available, else the part rig.
function Factory.Build(model: Model, root: BasePart, enemyId: string): any
	if Factory.HasModel(enemyId) then
		local ok, rig = pcall(buildModel, model, root, enemyId)
		if ok then return rig end
		warn("[EnemyRigFactory] " .. enemyId .. " template failed, using the part rig: " .. tostring(rig))
		local art = model:FindFirstChild("TowerEnemyArt")
		if art then art:Destroy() end
	end
	local rig = Rigs.Build(model, root, enemyId)
	rig.Metrics = EnemyAnimator.Metrics(enemyId, rig.Spec, nil, 1)
	return rig
end

return Factory
