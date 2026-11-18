-- Files an imported Tower Biome Kit into ServerStorage.TowerBiomeKit (Shared/Config/TowerBiomeKit.luau).
--
-- 1. In Studio: File > Import 3D > assets-source/tower/biome_kit/TowerBiomeKit.fbx, into the Workspace, with
--    the parts kept separate (default settings). Every MeshPart is named "<Template>__<ROLE>".
-- 2. Run this in Edit mode (Studio MCP execute_luau, or the command bar):
--      return require(path.to.this)()
--    or paste the body and call it. It reports per template what it filed, then removes the imported model.
-- 3. Save the place. TowerBiomeAssets uses the kit once every template is present (TowerKitProps.Ready).
--
-- All templates were modelled on one shared Blender origin, so the importer's offset, unit scale and axes
-- are measured once from that origin and undone for every part. Each template is stored with its origin
-- (footprint centre on the ground) at the world origin and its front facing +Z; parts stay axis-aligned
-- (at most quarter-turned), which TowerKitProps relies on to scale them per axis. Studio's FBX importer
-- (2026-11) brings the kit in at 1:1 scale but turned 180 degrees; the script measures and undoes that.
return function(keepImported: boolean?): string
	local ServerStorage = game:GetService("ServerStorage")
	-- Clone before requiring so Studio's Edit-mode module cache reflects freshly Rojo-synced templates.
	local kitClone = game.ReplicatedStorage.Shared.Config.TowerBiomeKit:Clone()
	local Kit = require(kitClone) :: any
	kitClone:Destroy()

	local function templateSpec(name: string)
		return Kit.Templates[name] or Kit.ExtraTemplates[name]
	end

	-- 1. Collect the imported parts per top-level Workspace root, then by template and role
	-- (solving each FBX root independently lets multiple kit FBXs be imported together safely).
	local byRoot: { [Instance]: { [string]: { [string]: MeshPart } } } = {}
	local hasAny = false
	for _, d in workspace:GetDescendants() do
		if d:IsA("MeshPart") then
			local template, role = string.match(d.Name, "^(.-)__(%u+)$")
			if template and role and templateSpec(template) then
				local root: Instance = d
				while root.Parent and root.Parent ~= workspace do
					root = root.Parent
				end
				byRoot[root] = byRoot[root] or {}
				byRoot[root][template] = byRoot[root][template] or {}
				byRoot[root][template][role] = d
				hasAny = true
			end
		end
	end
	if not hasAny then
		return "No imported Tower Biome Kit parts found in the Workspace (expected MeshParts named <Template>__<ROLE>)."
	end

	local function bounds(parts: { BasePart }): (Vector3, Vector3)
		local lo = Vector3.new(math.huge, math.huge, math.huge)
		local hi = -lo
		for _, p in parts do
			local half = p.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local w = p.CFrame:PointToWorldSpace(half * Vector3.new(sx, sy, sz))
						lo = lo:Min(w)
						hi = hi:Max(w)
					end
				end
			end
		end
		return lo, hi
	end
	local function listOf(t: { [string]: MeshPart }): { BasePart }
		local out = {}
		for _, p in t do
			table.insert(out, p)
		end
		return out
	end

	local folder = ServerStorage:FindFirstChild(Kit.FolderName) or Instance.new("Folder")
	folder.Name = Kit.FolderName
	folder.Parent = ServerStorage
	local report = {}
	local missing = {}

	for root, byTemplate in byRoot do
		-- 2. Unit scale: the importer scales every template alike; take the median ratio of authored to imported height.
		local ratios = {}
		for name, parts in byTemplate do
			local lo, hi = bounds(listOf(parts))
			local spec = templateSpec(name)
			if spec and hi.Y - lo.Y > 1e-3 then
				table.insert(ratios, spec.Size.Y / (hi.Y - lo.Y))
			end
		end
		if #ratios == 0 then
			continue
		end
		table.sort(ratios)
		local scale = ratios[math.ceil(#ratios / 2)]

		-- 3. Yaw & origin: try each 90-degree turn and solve origin from bounds per root FBX.
		local origin = Vector3.zero
		local bestYaw, bestErr = 0, math.huge
		for _, yaw in { 0, 90, 180, 270 } do
			local turn = CFrame.Angles(0, math.rad(yaw), 0)
			local sampleOrigin = Vector3.zero
			if byTemplate.ArchPierBase then
				local pLo, pHi = bounds(listOf(byTemplate.ArchPierBase))
				sampleOrigin = Vector3.new((pLo.X + pHi.X) / 2, pLo.Y, (pLo.Z + pHi.Z) / 2)
			else
				for name, parts in byTemplate do
					local want = assert(templateSpec(name))
					local pLo, pHi = bounds(listOf(parts))
					local rLo = turn:VectorToWorldSpace(pLo):Min(turn:VectorToWorldSpace(pHi))
					sampleOrigin = turn:PointToObjectSpace((rLo * scale - want.Min) / scale)
					break
				end
			end
			local err = 0
			for name, parts in byTemplate do
				local lo, hi = bounds(listOf(parts))
				local a = turn:VectorToWorldSpace((lo - sampleOrigin) * scale)
				local b = turn:VectorToWorldSpace((hi - sampleOrigin) * scale)
				local tMin = a:Min(b)
				local want = assert(templateSpec(name))
				err += (tMin - want.Min).Magnitude
			end
			if err < bestErr then
				bestYaw, bestErr, origin = yaw, err, sampleOrigin
			end
		end
		local turn = CFrame.Angles(0, math.rad(bestYaw), 0)

		-- 4. File each template from this root.
		table.insert(report, string.format("[%s] scale %.4f, yaw %d, bounds error %.2f studs", root.Name, scale, bestYaw, bestErr))
		local function fileTemplate(name: string, spec: Kit.Template, required: boolean)
			local parts = byTemplate[name]
			if not parts then
				if required then
					table.insert(missing, name)
				end
				return
			end
			local old = folder:FindFirstChild(name)
			if old then
				old:Destroy()
			end
			local model = Instance.new("Model")
			model.Name = name
			model:SetAttribute("Size", spec.Size)
			local rotated = 0
			for role, src in parts do
				local p = src:Clone()
				p.Name = role
				p:SetAttribute("Role", role)
				local rel = turn * CFrame.new((src.Position - origin) * scale) * src.CFrame.Rotation
				p.Size = src.Size * scale
				p.CFrame = rel
				-- Quarter turns keep the part axis-aligned (Studio's importer brings this kit in turned 180 degrees);
				-- anything else would break TowerKitProps' per-axis scaling.
				local r = p.CFrame
				for _, v in { r.RightVector, r.UpVector, r.LookVector } do
					if math.max(math.abs(v.X), math.abs(v.Y), math.abs(v.Z)) < 0.999 then
						rotated += 1
						break
					end
				end
				p.Anchored = true
				p.CanCollide = true
				p.CanQuery = true
				p.CanTouch = false
				p.CollisionFidelity = Enum.CollisionFidelity.Default
				p.RenderFidelity = Enum.RenderFidelity.Automatic
				p.DoubleSided = false
				for _, child in p:GetChildren() do
					-- Colour and material come from the role palette at runtime; drop importer materials.
					if child:IsA("SurfaceAppearance") then
						child:Destroy()
					end
				end
				p.TextureID = ""
				p.Parent = model
			end
			model.WorldPivot = CFrame.identity
			model.Parent = folder
			local lo, hi = bounds(model:GetChildren() :: any)
			local drift = (lo - spec.Min).Magnitude + ((hi - lo) - spec.Size).Magnitude
			table.insert(report, string.format("%s: %d roles, size %.1f x %.1f x %.1f, drift %.2f%s", name, #model:GetChildren(), hi.X - lo.X, hi.Y - lo.Y, hi.Z - lo.Z, drift, if rotated > 0 then string.format(", %d SKEWED parts (re-export)", rotated) else ""))
		end
		local requireCore = byTemplate.ArchPierBase ~= nil
		for name, spec in Kit.Templates do
			fileTemplate(name, spec, requireCore)
		end
		for name, spec in Kit.ExtraTemplates do
			fileTemplate(name, spec, false)
		end
		if not keepImported then
			root:Destroy()
		end
	end
	table.sort(report)
	if #missing > 0 then
		table.insert(report, "MISSING: " .. table.concat(missing, ", "))
	end
	game:GetService("ChangeHistoryService"):SetWaypoint("Import Tower Biome Kit")
	return table.concat(report, "\n")
end
