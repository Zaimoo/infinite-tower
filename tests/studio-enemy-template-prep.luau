-- Studio (Edit mode, via Studio MCP or the command bar): turn hand-imported enemy FBXs into rig templates.
-- docs/tower-mob-remodel-plan.md §6.2.
--
-- Import each <enemyId>.fbx with the 3D Importer into Workspace (the model keeps the file's name), sync Rojo
-- so ReplicatedStorage.Shared.Config.TowerEnemyModelIndex is current, then run this. For every Workspace model
-- whose name is an index entry it:
--   1. finds the importer's scale and yaw (it often imports FBX ~74x and turned 180°) by matching the pieces'
--      centres against the index, and snaps every piece to its exact model-space centre;
--   2. sets render-only flags (no collision/query/touch, massless, unanchored, shadows only on joints);
--   3. moves it to ReplicatedStorage.TowerEnemyTemplates.<enemyId> at the origin (Rojo ignores that folder,
--      so the templates live in the place file).
-- Returns a report per enemy. Run again after re-importing; an existing template is replaced.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Index = require(ReplicatedStorage.Shared.Config.TowerEnemyModelIndex)

local TARGETS: { string }? = nil -- nil: every Workspace model named after an index entry

local folder = ReplicatedStorage:FindFirstChild("TowerEnemyTemplates")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "TowerEnemyTemplates"
	folder.Parent = ReplicatedStorage
end

local function expectedCentres(entry: any): { [string]: Vector3 }
	local out = {}
	for _, s in entry.Segments do
		if s.Centre then out[s.Name] = s.Centre end
		for _, g in s.Glow do out[g.Mesh] = g.Centre end
	end
	return out
end

local function prep(model: Model, entry: any): any
	local expected = expectedCentres(entry)
	local parts: { [string]: MeshPart } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") and expected[d.Name] then parts[d.Name] = d end
	end
	local missing = {}
	for name in expected do if not parts[name] then table.insert(missing, name) end end
	if #missing > 0 then return { ok = false, missing = missing } end

	-- centroids of the imported and expected layouts
	local n, mi, me = 0, Vector3.zero, Vector3.zero
	for name, p in parts do n += 1; mi += p.Position; me += expected[name] end
	mi /= n; me /= n
	-- scale: ratio of mean spread
	local si, se = 0, 0
	for name, p in parts do si += (p.Position - mi).Magnitude; se += (expected[name] - me).Magnitude end
	local k = if si > 0 then se / si else 1
	-- yaw: whichever quarter turn best matches the layout
	local bestYaw, bestErr = 0, math.huge
	for q = 0, 3 do
		local r = CFrame.Angles(0, q * math.pi / 2, 0)
		local err = 0
		for name, p in parts do err += ((r * ((p.Position - mi) * k)) - (expected[name] - me)).Magnitude end
		if err < bestErr then bestErr, bestYaw = err, q end
	end
	local yaw = CFrame.Angles(0, bestYaw * math.pi / 2, 0)

	local out = Instance.new("Model")
	out.Name = model.Name
	local jointNames = {}
	for _, s in entry.Segments do jointNames[s.Name] = true end
	for name, p in parts do
		p.Size *= k
		p.CFrame = CFrame.new(expected[name]) * (yaw * p.CFrame.Rotation)
		p.Anchored = true -- templates are anchored; EnemyRigFactory unanchors its clones
		p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
		p.Massless = true
		p.CastShadow = jointNames[name] == true and not string.find(name, "_Glow_", 1, true)
		if string.find(name, "_Glow_", 1, true) then p.Material = Enum.Material.Neon end
		p.Parent = out
	end
	local old = folder:FindFirstChild(model.Name)
	if old then old:Destroy() end
	out.Parent = folder
	model:Destroy()
	return { ok = true, scale = math.round(k * 1000) / 1000, yawDegrees = bestYaw * 90, meanError = math.round(bestErr / n * 1000) / 1000, parts = n }
end

local report = {}
for _, m in workspace:GetChildren() do
	if m:IsA("Model") and Index[m.Name] and (TARGETS == nil or table.find(TARGETS, m.Name)) then
		report[m.Name] = prep(m, Index[m.Name])
	end
end
game:GetService("ChangeHistoryService"):SetWaypoint("Prepare tower enemy templates")
return report
