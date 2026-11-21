-- Studio checks for a hand-authored tower floor (biome-floor-redesign skill, step 7).
-- Run each block with Studio MCP execute_luau in Edit mode, with Rojo syncing the main folder.
-- Set FLOOR first. A floor's room origin is (12000 + (FLOOR - 1) * 2400, 1000, 12000), and its
-- index in the biome is (FLOOR - 1) % 5 + 1.

---------------------------------------------------------------------------------------------------
-- Block 1: probe and build. Fresh clones avoid Studio's Edit-mode module cache (a failed require
-- stays cached until the module is cloned again).
---------------------------------------------------------------------------------------------------
local FLOOR = 10
local origin = Vector3.new(12000 + (FLOOR - 1) * 2400, 1000, 12000)
workspace.Terrain:FillBlock(CFrame.new(origin + Vector3.new(0, 60, 0)), Vector3.new(720, 260, 760), Enum.Material.Air)
for _, n in { "_CoreProbe", "_FreshConfig" } do
	local f = game.ServerStorage:FindFirstChild(n)
	if f then f:Destroy() end
end
local tr = workspace:FindFirstChild("TowerRooms")
if tr then tr:Destroy() end
local core = game.ServerScriptService.Core:Clone()
for _, d in core:GetDescendants() do
	if d:IsA("Script") then d.Disabled = true end
end
core.Name = "_CoreProbe"
core.Parent = game.ServerStorage
-- Only these three: other configs require siblings through script.Parent and break when moved.
local holder = Instance.new("Folder")
holder.Name = "_FreshConfig"
holder.Parent = game.ServerStorage
for _, n in { "TowerLayout", "HubLighting", "TowerBiomeKit" } do
	game.ReplicatedStorage.Shared.Config[n]:Clone().Parent = holder
end
local function patch(m: ModuleScript)
	if #m.Source >= 199000 then return end -- Source writes over 200,000 characters fail
	local s, count = string.gsub(m.Source, "require%(game%.ReplicatedStorage%.Shared%.Config%.(%w+)%)", function(n)
		if holder:FindFirstChild(n) then return "require(game.ServerStorage._FreshConfig." .. n .. ")" end
		return nil
	end)
	if count > 0 then m.Source = s end
end
for _, m in core:GetDescendants() do
	if m:IsA("ModuleScript") then patch(m) end
end
for _, m in holder:GetChildren() do patch(m) end
-- Require only the tower modules: some Core modules wait on game objects and hang the call.
local bad = {}
for _, n in { "TowerTerrain", "TowerBiomeAssets", "TowerKitProps", "TowerPropClearance", "TowerRoomBuilder", "TowerFloorService" } do
	if not pcall(require, core:FindFirstChild(n)) then table.insert(bad, n) end
end
if #bad > 0 then return "require errors (read get_console_output for the line): " .. table.concat(bad, ", ") end
local Layout = require(holder.TowerLayout)
local index = (FLOOR - 1) % 5 + 1
local allowed = {}
for _, p in Layout.Validate(Layout.Get(index)) do allowed[p] = true end
local fresh = {}
for _, p in Layout.Validate(Layout.ForFloor(FLOOR)) do
	if not allowed[p] then table.insert(fresh, p) end
end
local room = require(core.TowerRoomBuilder).Build(FLOOR, 4)
local kinds = {}
for _, c in room.Model.BiomeAssets:GetChildren() do kinds[c.Name] = (kinds[c.Name] or 0) + 1 end
local lights = 0
for _, d in room.Model:GetDescendants() do
	if d:IsA("Light") then lights += 1 end
end
-- List the floor's set-piece group names here and check none is nil (removed by clearance).
local pieces = {}
for _, n in { "ShroudSpire", "VeinwebHeart" } do table.insert(pieces, n .. "=" .. tostring(kinds[n])) end
return string.format("new problems: %s\nlights %d (max 24)\ncleared for camps %s, lanes %s\n%s",
	#fresh == 0 and "none" or table.concat(fresh, "; "), lights,
	tostring(room.Model.BiomeAssets:GetAttribute("PropsClearedForCamps")), tostring(room.Model:GetAttribute("PropsClearedForLanes")),
	table.concat(pieces, " "))

---------------------------------------------------------------------------------------------------
-- Block 2: spawns, arrival, routes (both ways) and portals, on the room Block 1 built.
---------------------------------------------------------------------------------------------------
local FLOOR = 10
local origin = Vector3.new(12000 + (FLOOR - 1) * 2400, 1000, 12000)
local index = (FLOOR - 1) % 5 + 1
local m = workspace.TowerRooms:FindFirstChild(string.format("Floor_%02d", FLOOR))
local Navigation = require(game.ServerStorage._CoreProbe.HeroNavigation)
local Layout = require(game.ServerStorage._FreshConfig.TowerLayout)
local layout = Layout.ForFloor(FLOOR)
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { m, workspace.Terrain }
params.IgnoreWater = true
params.RespectCanCollide = true
local offsets = { { 0, 0 }, { -18, 12 }, { 18, 12 }, { -12, -16 }, { 12, -16 } }
local out, good, bad = {}, 0, 0
for _, camp in layout.Camps do
	for slot = 1, math.min(camp.Size, #offsets) do
		local x, z = camp.X + offsets[slot][1], camp.Z + offsets[slot][2]
		local hit = workspace:Raycast(origin + Vector3.new(x, camp.Y + 6, z), Vector3.new(0, -14, 0), params)
		local dy = if hit then hit.Position.Y - origin.Y - camp.Y else 999
		if math.abs(dy) > 0.3 then
			bad += 1
			table.insert(out, string.format("SPAWN %s/%d dy=%.2f %s", camp.Id, slot, dy, hit and hit.Instance.Name or "none"))
		else
			good += 1
		end
	end
end
table.insert(out, string.format("spawns ok %d, bad %d", good, bad))
local ahit = workspace:Raycast(origin + Vector3.new(0, 11.5, layout.Sanctuary.Z - 12), Vector3.new(0, -12, 0), params)
table.insert(out, "arrival " .. (ahit and ahit.Instance.Name or "NONE"))
local okRoutes, total = 0, 0
for _, link in layout.Links do
	for _, reverse in { false, true } do
		total += 1
		local a = layout.Platforms[if reverse then link.To else link.From]
		local b = layout.Platforms[if reverse then link.From else link.To]
		local goal = origin + Vector3.new(b.X, b.Y, b.Z)
		local hero = { Position = origin + Vector3.new(a.X, a.Y, a.Z), FloorId = FLOOR, RoomGeneration = 1, State = "FOLLOW_MASTER" }
		for _ = 1, 900 do
			Navigation.Step(hero, goal, 1.5, os.clock())
			if Vector3.new(hero.Position.X - goal.X, 0, hero.Position.Z - goal.Z).Magnitude < 2.5 then break end
		end
		local d = hero.Position - goal
		if Vector3.new(d.X, 0, d.Z).Magnitude < 2.5 and math.abs(d.Y) < 0.5 then
			okRoutes += 1
		else
			table.insert(out, "BLOCKED " .. a.Id .. " -> " .. b.Id .. " at " .. tostring(hero.Position - origin))
		end
		Navigation.Clear(hero)
	end
end
table.insert(out, string.format("routes ok %d/%d", okRoutes, total))
for name, p in Layout.PortalSpots(index, FLOOR) do
	local hit = workspace:Raycast(origin + Vector3.new(p.X, p.Y + 6, p.Z), Vector3.new(0, -14, 0), params)
	table.insert(out, string.format("portal %s dy=%s", name, hit and string.format("%.2f", hit.Position.Y - origin.Y - p.Y) or "none"))
end
return table.concat(out, "\n")

---------------------------------------------------------------------------------------------------
-- Block 3: find which clearance test removes a group. Run it as Block 1, with this patch applied to
-- the probe's TowerPropClearance after the require patching and before the build. Set GROUP to the
-- group's name. It records each removal of that group with the part, its position and the caller.
---------------------------------------------------------------------------------------------------
local GROUP = "VeinwebHeart"
local pc = game.ServerStorage._CoreProbe.TowerPropClearance
pc.Source = string.gsub(pc.Source, "if not doomed%[unit%] and hits%(descendant%) then\n(%s*)doomed%[unit%] = true", function(ind)
	return "if not doomed[unit] and hits(descendant) then\n" .. ind .. "doomed[unit] = true\n" .. ind
		.. "if unit.Name == '" .. GROUP .. "' then _G.Killed = (_G.Killed or '') .. descendant.Name .. ' @' .. tostring(descendant.Position) .. ' sz ' .. tostring(descendant.Size) .. ' | ' .. debug.traceback('', 2):sub(1, 200) .. '\\n' end"
end)
_G.Killed = nil
-- ...build, then: return tostring(_G.Killed)

---------------------------------------------------------------------------------------------------
-- Block 4: clean up (always, before ending the turn).
---------------------------------------------------------------------------------------------------
local FLOOR = 10
local origin = Vector3.new(12000 + (FLOOR - 1) * 2400, 1000, 12000)
workspace.Terrain:FillBlock(CFrame.new(origin + Vector3.new(0, 60, 0)), Vector3.new(720, 260, 760), Enum.Material.Air)
for _, n in { "_CoreProbe", "_FreshConfig" } do
	local f = game.ServerStorage:FindFirstChild(n)
	if f then f:Destroy() end
end
local tr = workspace:FindFirstChild("TowerRooms")
if tr then tr:Destroy() end
_G.Killed = nil
return "clean"
