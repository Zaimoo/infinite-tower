--!nocheck
-- tests/studio-greataxe-import.luau
-- Studio (Edit mode) step of the Berserker greataxe remodel. Run it from the command bar, or
-- through Studio MCP, after importing the 14 FBX files in assets/artifacts/axes/ into Workspace
-- with the 3D Importer (one Model per file, parts kept separate, named after the file).
--
-- For every imported axe it: scales the model so the haft is its authored length, welds the
-- parts to Handle, adds the Grip / OffhandGrip / Tip / Vfx sockets from the Blender manifest,
-- applies the catalog materials and weapon VFX, and replaces the prefab of the same name in
-- ReplicatedStorage.Assets.Weapons. It returns the AXE_MESH_DATA entries for WeaponModelBuilder.
--
-- MANIFEST mirrors assets/artifacts/axes/greataxes_manifest.json, which
-- tools/blender/generate_berserker_greataxes.py writes. Points are in the Blender authoring
-- frame, relative to the Handle's centre: haft along +Z, main edge towards -X. The importer's
-- own axes are detected from the parts, not assumed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MANIFEST = {
	art_miner_pickaxe = { Tier = 1, HaftLength = 5.20, Grip = Vector3.new(0.0000, 0.0000, 0.5800), Offhand = Vector3.new(0.0000, 0.0000, -1.1200), Tip = Vector3.new(-1.1250, 0.0000, 2.6300), Base = Vector3.new(-1.0750, 0.0000, 1.0800), Core = Vector3.new(-0.5625, 0.0000, 2.0800), Tris = 1022, Wrap = Color3.fromRGB(70, 48, 32) },
	art_heavy_hewing_axe = { Tier = 1, HaftLength = 5.30, Grip = Vector3.new(0.0000, 0.0000, 0.4600), Offhand = Vector3.new(0.0000, 0.0000, -1.2400), Tip = Vector3.new(-1.2600, 0.0000, 2.8600), Base = Vector3.new(-1.2040, 0.0000, 0.9600), Core = Vector3.new(-0.6300, 0.0000, 2.0100), Tris = 1108, Wrap = Color3.fromRGB(52, 38, 28) },
	art_canyon_splitter = { Tier = 2, HaftLength = 5.40, Grip = Vector3.new(0.0000, 0.0000, 0.3300), Offhand = Vector3.new(0.0000, 0.0000, -1.3700), Tip = Vector3.new(-1.3050, 0.0000, 2.8800), Base = Vector3.new(-1.2470, 0.0000, 0.8300), Core = Vector3.new(-0.6525, 0.0000, 2.0800), Tris = 1706, Wrap = Color3.fromRGB(60, 44, 34) },
	art_quakestone_greataxe = { Tier = 2, HaftLength = 5.50, Grip = Vector3.new(0.0000, 0.0000, 0.2990), Offhand = Vector3.new(0.0000, 0.0000, -1.4010), Tip = Vector3.new(-1.3500, 0.0000, 3.1490), Base = Vector3.new(-1.2900, 0.0000, 0.7990), Core = Vector3.new(-0.6750, 0.0000, 2.0990), Tris = 1342, Wrap = Color3.fromRGB(74, 52, 36) },
	art_battleaxe_cleaver = { Tier = 3, HaftLength = 5.60, Grip = Vector3.new(0.0000, 0.0000, 0.5800), Offhand = Vector3.new(0.0000, 0.0000, -1.1200), Tip = Vector3.new(-1.3050, 0.0000, 3.1800), Base = Vector3.new(-1.2470, 0.0000, 1.0800), Core = Vector3.new(-0.6525, 0.0000, 2.1800), Tris = 2370, Wrap = Color3.fromRGB(48, 36, 30) },
	art_iron_juggernaut_cleaver = { Tier = 3, HaftLength = 5.60, Grip = Vector3.new(0.0000, 0.0000, 0.2300), Offhand = Vector3.new(0.0000, 0.0000, -1.4700), Tip = Vector3.new(-1.5360, 0.0000, 3.1380), Base = Vector3.new(-1.1520, 0.0000, 0.7300), Core = Vector3.new(-0.7200, 0.0000, 2.0800), Tris = 2056, Wrap = Color3.fromRGB(40, 32, 28) },
	art_magma_behemoth = { Tier = 4, HaftLength = 5.70, Grip = Vector3.new(0.0000, 0.0000, 0.2180), Offhand = Vector3.new(0.0000, 0.0000, -1.4820), Tip = Vector3.new(-1.5300, 0.0000, 3.2680), Base = Vector3.new(-1.4620, 0.0000, 0.7180), Core = Vector3.new(-0.7650, 0.0000, 2.1680), Tris = 2394, Wrap = Color3.fromRGB(58, 34, 30) },
	art_obsidian_hell_splitter = { Tier = 4, HaftLength = 5.80, Grip = Vector3.new(0.0000, 0.0000, 0.3870), Offhand = Vector3.new(0.0000, 0.0000, -1.3130), Tip = Vector3.new(-1.4400, 0.0000, 3.3370), Base = Vector3.new(-1.3760, 0.0000, 0.8870), Core = Vector3.new(-0.7200, 0.0000, 2.1870), Tris = 3928, Wrap = Color3.fromRGB(62, 36, 34) },
	art_titan_earthshaker = { Tier = 5, HaftLength = 6.00, Grip = Vector3.new(0.0000, 0.0000, 0.2130), Offhand = Vector3.new(0.0000, 0.0000, -1.4870), Tip = Vector3.new(-1.6200, 0.0000, 3.5130), Base = Vector3.new(-1.5480, 0.0000, 0.7130), Core = Vector3.new(-0.8100, 0.0000, 2.1630), Tris = 4670, Wrap = Color3.fromRGB(120, 82, 46) },
	art_mountain_breaker = { Tier = 5, HaftLength = 6.00, Grip = Vector3.new(0.0000, 0.0000, 0.0320), Offhand = Vector3.new(0.0000, 0.0000, -1.6680), Tip = Vector3.new(-1.6720, 0.0000, 3.2240), Base = Vector3.new(-1.7860, 0.0000, 0.8520), Core = Vector3.new(-0.8550, 0.0000, 2.1320), Tris = 2368, Wrap = Color3.fromRGB(96, 68, 40) },
	art_valkyrie_waraxe = { Tier = 6, HaftLength = 6.10, Grip = Vector3.new(0.0000, 0.0000, 0.0580), Offhand = Vector3.new(0.0000, 0.0000, -1.6420), Tip = Vector3.new(-1.4000, 0.0000, 3.6580), Base = Vector3.new(-1.4000, 0.0000, 0.5580), Core = Vector3.new(-0.7875, 0.0000, 2.0580), Tris = 5310, Wrap = Color3.fromRGB(70, 110, 160) },
	art_world_shaper = { Tier = 6, HaftLength = 6.20, Grip = Vector3.new(0.0000, 0.0000, 0.1320), Offhand = Vector3.new(0.0000, 0.0000, -1.5680), Tip = Vector3.new(-1.7100, 0.0000, 3.6320), Base = Vector3.new(-1.6340, 0.0000, 0.6320), Core = Vector3.new(-0.8550, 0.0000, 2.2320), Tris = 4694, Wrap = Color3.fromRGB(84, 58, 40) },
	art_world_carver = { Tier = 7, HaftLength = 6.40, Grip = Vector3.new(0.0000, 0.0000, -0.4780), Offhand = Vector3.new(0.0000, 0.0000, -2.1780), Tip = Vector3.new(-1.8860, 0.0000, 3.9220), Base = Vector3.new(-1.7940, 0.0000, 0.0220), Core = Vector3.new(-1.0350, 0.0000, 2.0220), Tris = 3590, Wrap = Color3.fromRGB(70, 50, 110) },
	art_genesis_sunderer = { Tier = 7, HaftLength = 6.40, Grip = Vector3.new(0.0000, 0.0000, 0.0080), Offhand = Vector3.new(0.0000, 0.0000, -1.6920), Tip = Vector3.new(-1.8900, 0.0000, 3.8080), Base = Vector3.new(-1.8060, 0.0000, 0.5080), Core = Vector3.new(-0.9450, 0.0000, 2.2080), Tris = 7618, Wrap = Color3.fromRGB(120, 60, 110) },
}

local PART_NAMES = { "Handle", "GripWrap", "Pommel", "HeadCollar", "Blade", "BladeEdge", "BackSpike", "RuneInlay" }

local Assets = ReplicatedStorage:WaitForChild("Assets")
local weaponsFolder = Assets:FindFirstChild("Weapons")
if not weaponsFolder then
	weaponsFolder = Instance.new("Folder")
	weaponsFolder.Name = "Weapons"
	weaponsFolder.Parent = Assets
end

local okBuilder, WeaponModelBuilder = pcall(require, Assets:FindFirstChild("WeaponModelBuilder"))
local combatVfx = Assets:FindFirstChild("CombatVfx")
local okVfx, WeaponVfx = pcall(require, combatVfx and combatVfx:FindFirstChild("WeaponVfx"))

-- Nearest principal axis, so sockets are not skewed by a mesh's slightly off-centre bounds.
local function snap(v: Vector3): Vector3
	local ax, ay, az = math.abs(v.X), math.abs(v.Y), math.abs(v.Z)
	if ax >= ay and ax >= az then
		return Vector3.new(math.sign(v.X), 0, 0)
	elseif ay >= az then
		return Vector3.new(0, math.sign(v.Y), 0)
	end
	return Vector3.new(0, 0, math.sign(v.Z))
end

local function fmt(v: Vector3): string
	return string.format("Vector3.new(%.4f, %.4f, %.4f)", v.X, v.Y, v.Z)
end

local report, dump = {}, {}

local function process(id: string, info)
	local source = workspace:FindFirstChild(id)
	if not source then
		table.insert(report, `MISSING {id}: not found in Workspace`)
		return
	end

	local parts: { [string]: MeshPart } = {}
	for _, d in source:GetDescendants() do
		if d:IsA("MeshPart") then
			-- Blender suffixes repeated object names (Handle.001); the part name is what precedes it.
			local name = string.match(d.Name, "^(%a+)") or d.Name
			if table.find(PART_NAMES, name) and not parts[name] then
				d.Name = name
				parts[name] = d
			end
		end
	end
	local handle = parts.Handle
	if not (handle and parts.Blade) then
		table.insert(report, `SKIPPED {id}: needs Handle and Blade MeshParts`)
		return
	end

	local model = Instance.new("Model")
	model.Name = id
	for _, name in PART_NAMES do
		local part = parts[name]
		if part then
			for _, c in part:GetChildren() do
				if c:IsA("JointInstance") or c:IsA("WeldConstraint") or c:IsA("Attachment") then
					c:Destroy()
				end
			end
			part.Parent = model
		end
	end
	model.PrimaryPart = handle
	model.Parent = workspace

	-- The haft is the Handle's longest side; scale so it matches the authored length in studs.
	local longest = math.max(handle.Size.X, handle.Size.Y, handle.Size.Z)
	model:ScaleTo(model:GetScale() * info.HaftLength / longest)

	for _, part in parts do
		part.Anchored = false
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.CastShadow = false
		if part ~= handle then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = part
			weld.Parent = handle
		end
	end

	-- Authoring frame in Handle space: haft = pommel -> head, edge = handle -> blade.
	local function localPos(part: BasePart): Vector3
		return handle.CFrame:PointToObjectSpace(part.Position)
	end
	-- The haft is the Handle's long axis, pointing at the half the blade is in. (Collar and
	-- pommel bounds are no guide: bands and finials stretch them along the whole haft.)
	local size = handle.Size
	local long = if size.X >= size.Y and size.X >= size.Z then Vector3.xAxis elseif size.Y >= size.Z then Vector3.yAxis else Vector3.zAxis
	local toBlade = localPos(parts.Blade)
	local haft = long * math.sign(toBlade:Dot(long))
	local edge = snap(toBlade - haft * toBlade:Dot(haft))
	local side = edge:Cross(haft) -- Blender +Y
	local function map(p: Vector3): Vector3
		return -edge * p.X + side * p.Y + haft * p.Z
	end

	local function socket(name: string, cf: CFrame)
		local attachment = Instance.new("Attachment")
		attachment.Name = name
		attachment.CFrame = cf
		attachment.Parent = handle
	end
	-- UpVector along the haft towards the head, LookVector towards the cutting edge.
	local function gripCFrame(p: Vector3): CFrame
		return CFrame.fromMatrix(map(p), haft:Cross(-edge), haft, -edge)
	end
	socket("Grip", gripCFrame(info.Grip))
	socket("OffhandGrip", gripCFrame(info.Offhand))
	socket("Tip", CFrame.new(map(info.Tip)))
	socket("VfxTip", CFrame.new(map(info.Tip)))
	socket("VfxBase", CFrame.new(map(info.Base)))
	socket("VfxCore", CFrame.new(map(info.Core)))

	if okBuilder and WeaponModelBuilder.Style then
		pcall(WeaponModelBuilder.Style, model, id, info.Tier)
	end
	if parts.GripWrap then
		parts.GripWrap.Material = Enum.Material.Leather
		parts.GripWrap.Color = info.Wrap
	end
	if okVfx and WeaponVfx.Apply then
		pcall(WeaponVfx.Apply, model, "AXE", info.Tier, id)
	end

	local old = weaponsFolder:FindFirstChild(id)
	if old then
		old:Destroy()
	end
	model.Parent = weaponsFolder
	source:Destroy()

	-- AXE_MESH_DATA entry. Offsets are Handle-space; a rotated part cannot be rebuilt from an
	-- offset alone, so flag it.
	local lines = { `\t{id} = \{` }
	table.insert(lines, `\t\tGripPos = {fmt(map(info.Grip))},`)
	table.insert(lines, `\t\tOffhandGripPos = {fmt(map(info.Offhand))},`)
	table.insert(lines, `\t\tTipPos = {fmt(map(info.Tip))},`)
	table.insert(lines, `\t\tBasePos = {fmt(map(info.Base))},`)
	table.insert(lines, `\t\tCorePos = {fmt(map(info.Core))},`)
	table.insert(lines, `\t\tParts = \{`)
	local rotated = false
	for _, name in PART_NAMES do
		local part = parts[name]
		if part then
			local rel = handle.CFrame:ToObjectSpace(part.CFrame)
			local _, angle = rel:ToAxisAngle()
			if math.abs(angle) > 1e-3 then
				rotated = true
			end
			table.insert(lines, string.format(
				'\t\t\t{ Name = "%s", MeshId = "%s", Size = %s, Offset = %s },',
				name, part.MeshId, fmt(part.Size), fmt(rel.Position)
			))
		end
	end
	table.insert(lines, "\t\t},")
	table.insert(lines, "\t},")
	table.insert(dump, table.concat(lines, "\n"))
	table.insert(report, string.format(
		"OK %s: scale %.4f, haft axis (%d,%d,%d), edge axis (%d,%d,%d), %d tris authored%s",
		id, model:GetScale(), haft.X, haft.Y, haft.Z, edge.X, edge.Y, edge.Z, info.Tris, if rotated then " [WARNING: rotated parts]" else ""
	))
end

for id, info in MANIFEST do
	process(id, info)
end

-- The generic greataxe (weapon_axe) is code-built. Drop the cached copy so
-- WeaponModelBuilder.EnsureWeapons builds the current one the next time the game runs.
local cachedAxe = weaponsFolder:FindFirstChild("weapon_axe")
if cachedAxe then
	cachedAxe:Destroy()
	table.insert(report, "OK weapon_axe cache cleared")
end

table.sort(report)
table.sort(dump)
return table.concat(report, "\n") .. "\n\n-- AXE_MESH_DATA --\n" .. table.concat(dump, "\n")
