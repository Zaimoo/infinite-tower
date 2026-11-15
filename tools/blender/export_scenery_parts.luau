-- tools/blender/export_scenery_parts.luau
-- Step 1 of the scenery mesh bake (tools/blender/bake_scenery_meshes.py).
--
-- Run in Studio in EDIT mode (command bar, or Studio MCP execute_luau) with Rojo connected, so the
-- builders in ServerScriptService.BaseOverhaul are current. It builds FortressWalls and
-- CourtyardGroundTiles with the real builders, lists every bakeable part (SceneryBake.IsBakeable) and
-- returns the text for tools/blender/bake_data/scenery_parts.txt.
--
-- Units that are the same shape (the four corner towers, wall bays of one width) are written once and
-- placed several times, which keeps the file small. The output is about 42 KB: fetch it in line ranges
-- with FIRST and LAST and join the pieces in order. Each piece reports its byte count and a checksum.
-- Nothing is left in the place: every model built here is destroyed again.

local FIRST, LAST = 1, math.huge

local BO = game:GetService("ServerScriptService").BaseOverhaul
local Bake = require(BO.SceneryBake)
local WallsBuilder = require(BO.WallsBuilder)
local IslandBuilder = require(BO.IslandBuilder)

local function hashString(text: string): number
	local h = 2166136261
	for i = 1, #text do
		h = bit32.bxor(h, string.byte(text, i))
		h = bit32.band(bit32.lshift(h, 24) + h * 403, 0xFFFFFFFF)
	end
	return h
end

local groups, groupList, rotations, rotationList = {}, {}, {}, {}
local function groupId(key: string): number
	if not groups[key] then
		table.insert(groupList, key)
		groups[key] = #groupList
	end
	return groups[key]
end
local function rotationId(key: string): number
	if not rotations[key] then
		table.insert(rotationList, key)
		rotations[key] = #rotationList
	end
	return rotations[key]
end

local lines = {}

local function exportAsset(name: string, root: Instance)
	table.insert(lines, "#A " .. name .. " " .. Bake.Signature(root, CFrame.identity))
	-- A unit is one direct child that holds bakeable parts; loose bakeable parts form one more unit.
	local units, loose = {}, {}
	for _, child in root:GetChildren() do
		if Bake.IsBakeable(child) then
			table.insert(loose, child)
		else
			local parts = Bake.BakeableParts(child)
			if #parts > 0 then
				table.insert(units, parts)
			end
		end
	end
	if #loose > 0 then
		table.insert(units, loose)
	end

	local uniques, uniqueCount = {}, 0
	for _, parts in units do
		local centre = Vector3.zero
		for _, part in parts do
			centre += part.Position
		end
		centre /= #parts

		-- Describe the unit in its own space at each quarter turn; an order-independent hash of that
		-- description matches an earlier unit when the two are the same shape.
		local hashes, records = {}, {}
		for turns = 0, 3 do
			local frame = CFrame.new(centre) * CFrame.Angles(0, turns * math.pi / 2, 0)
			local sum = 0
			for _, part in parts do
				local d = Bake.Describe(part, frame)
				local rotationKey = table.concat(d, " ", 7, 15)
				local text = Bake.ShapeCode(part) .. " " .. Bake.GroupKey(part) .. "|" .. table.concat(d, " ", 1, 6) .. "|" .. rotationKey
				sum = (sum + hashString(text)) % 4294967296
				if turns == 0 then
					table.insert(records, { part, d, rotationKey })
				end
			end
			hashes[turns] = sum
		end

		local unitId, unitTurns = nil, 0
		for turns = 0, 3 do
			for _, unique in uniques do
				if unique.Count == #parts and unique.Hash == hashes[turns] then
					unitId, unitTurns = unique.Id, turns
					break
				end
			end
			if unitId then
				break
			end
		end
		if not unitId then
			uniqueCount += 1
			unitId = uniqueCount
			table.insert(uniques, { Count = #parts, Hash = hashes[0], Id = uniqueCount })
			table.insert(lines, "#U " .. uniqueCount)
			for _, record in records do
				table.insert(lines, Bake.ShapeCode(record[1]) .. " " .. groupId(Bake.GroupKey(record[1])) .. " " .. rotationId(record[3]) .. " " .. table.concat(record[2], " ", 1, 6))
			end
		end
		table.insert(lines, string.format("#I %d %d %.4f %.4f %.4f", unitId, unitTurns, centre.X, centre.Y, centre.Z))
	end
end

local walls = WallsBuilder.Build(nil)
exportAsset("FortressWalls", walls)
walls:Destroy()

local island = IslandBuilder.Build()
exportAsset("CourtyardGroundTiles", island.CourtyardGroundTiles)
island:Destroy()

local all = {}
for id, key in groupList do
	table.insert(all, "#G " .. id .. " " .. key)
end
for id, key in rotationList do
	table.insert(all, "#R " .. id .. " " .. key)
end
for _, line in lines do
	table.insert(all, line)
end

local last = math.min(LAST, #all)
local slice = table.concat(all, "\n", FIRST, last)
local checksum = 0
for i = 1, #slice do
	checksum = (checksum + string.byte(slice, i) * (1 + i % 7)) % 1000000007
end
return string.format("TOTAL %d RANGE %d-%d BYTES %d SUM %d\n", #all, FIRST, last, #slice, checksum) .. slice
