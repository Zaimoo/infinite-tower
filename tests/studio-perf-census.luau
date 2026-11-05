-- Render-cost census for docs/performance-plan.md (Phase 0 / item 9).
-- Run during a Studio playtest from the CLIENT command bar (switch the command bar to Client),
-- once in the hub with all plots populated and once on a busy tower floor. Paste the body and run;
-- it prints one row per top-level Workspace child plus totals, sorted by part count.
--
-- Columns: parts (BaseParts), shadow (parts with CastShadow on and Transparency < 1), meshes
-- (MeshParts + SpecialMeshes), hl (enabled Highlights; the client only renders a limited number),
-- lights (enabled Point/Spot/Surface lights, "s" = with Shadows), fx (enabled ParticleEmitters and the
-- sum of their Rate), trails/beams (enabled), bb (BillboardGuis), vp (ViewportFrames under PlayerGui).
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")

type Row = { name: string, parts: number, shadow: number, meshes: number, hl: number, lights: number, shadowLights: number, fx: number, fxRate: number, trails: number, bb: number }

local function newRow(name: string): Row
	return { name = name, parts = 0, shadow = 0, meshes = 0, hl = 0, lights = 0, shadowLights = 0, fx = 0, fxRate = 0, trails = 0, bb = 0 }
end

local function count(row: Row, d: Instance)
	if d:IsA("BasePart") then
		row.parts += 1
		if d.CastShadow and d.Transparency < 1 then row.shadow += 1 end
		if d:IsA("MeshPart") then row.meshes += 1 end
	elseif d:IsA("SpecialMesh") then
		row.meshes += 1
	elseif d:IsA("Highlight") then
		if d.Enabled then row.hl += 1 end
	elseif d:IsA("Light") then
		if d.Enabled then
			row.lights += 1
			if d.Shadows then row.shadowLights += 1 end
		end
	elseif d:IsA("ParticleEmitter") then
		if d.Enabled then row.fx += 1; row.fxRate += d.Rate end
	elseif d:IsA("Trail") or d:IsA("Beam") then
		if d.Enabled then row.trails += 1 end
	elseif d:IsA("BillboardGui") then
		row.bb += 1
	end
end

local rows: { Row } = {}
local total = newRow("TOTAL")
for _, child in Workspace:GetChildren() do
	local row = newRow(child.Name)
	count(row, child)
	for _, d in child:GetDescendants() do count(row, d) end
	for k, v in row :: any do if type(v) == "number" then (total :: any)[k] += v end end
	table.insert(rows, row)
end
table.sort(rows, function(a, b) return a.parts > b.parts end)

local function fmt(r: Row): string
	return string.format("%-34s parts %6d  shadow %6d  meshes %5d  hl %3d  lights %3d (s %d)  fx %3d (rate %5d)  trails/beams %3d  bb %3d",
		r.name:sub(1, 34), r.parts, r.shadow, r.meshes, r.hl, r.lights, r.shadowLights, r.fx, r.fxRate, r.trails, r.bb)
end

print("==== Render census", os.date("%H:%M:%S"), "====")
for i, r in rows do
	if i > 25 then break end
	if r.parts > 0 or r.hl > 0 or r.lights > 0 or r.fx > 0 then print(fmt(r)) end
end
print(fmt(total))

local player = Players.LocalPlayer
if player then
	local viewports = 0
	for _, d in player:WaitForChild("PlayerGui"):GetDescendants() do
		if d:IsA("ViewportFrame") then viewports += 1 end
	end
	local floorId = player.Character and player.Character:GetAttribute("TowerFloorId")
	print(string.format("PlayerGui ViewportFrames: %d   TowerFloorId: %s", viewports, tostring(floorId)))
end
print(string.format("Memory: total %.0f MB  instances %d  primitives %d",
	Stats:GetTotalMemoryUsageMb(), Stats.InstanceCount, Stats.PrimitivesCount))
