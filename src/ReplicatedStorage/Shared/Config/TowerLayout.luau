--!strict
-- Shared geometry and camp contract. Heights describe walkable top surfaces.
local Layout = {}
local widths = {380, 420, 460, 510, 560}
local depths = {420, 470, 520, 580, 640}
local heights = {130, 140, 155, 170, 190}
local apexHeights = {12, 14, 18, 22, 28}

function Layout.Get(index: number): any
	assert(index >= 1 and index <= 5 and index % 1 == 0)
	local w, d = widths[index], depths[index]
	local platforms, links = {}, {}
	local function platform(id, x, y, z, width, depth)
		local p = {Id=id, X=x, Y=y, Z=z, Width=width, Depth=depth}
		platforms[id] = p
		return p
	end
	local safe = platform("Sanctuary", 0, 8, d/2-34, 88, 56)
	platform("Basin", 0, 0, d*.18, w-32, d*.22)
	platform("WestGallery", -w*.28, 8, -d*.06, 84, 76)
	platform("EastGallery", w*.28, 8, -d*.06, 84, 76)
	platform("Crossing", 0, if index >= 3 then 5 else 0, -d*.04, 72, 58)
	platform("Apex", 0, apexHeights[index], -d*.34, 100, 80)
	if index >= 4 then
		platform("WestBastion", -w*.28, 14, -d*.31, 84, 76)
		platform("EastBastion", w*.28, 14, -d*.31, 84, 76)
	end
	local function link(a, b)
		local p, q = platforms[a], platforms[b]
		local dx, dz = q.X-p.X, q.Z-p.Z
		local length = math.sqrt(dx*dx+dz*dz)
		-- Start/end inside the terrace edge; keep a broad landing at each end.
		local insetA = math.min(p.Width/2 / math.max(math.abs(dx)/length,.001), p.Depth/2 / math.max(math.abs(dz)/length,.001))-4
		local insetB = math.min(q.Width/2 / math.max(math.abs(dx)/length,.001), q.Depth/2 / math.max(math.abs(dz)/length,.001))-4
		local run = length-insetA-insetB
		assert(math.abs(q.Y-p.Y)/run <= math.tan(math.rad(15)), a.." ramp too steep")
		table.insert(links, {From=a, To=b, AX=p.X+dx/length*insetA, AZ=p.Z+dz/length*insetA, AY=p.Y,
			BX=q.X-dx/length*insetB, BZ=q.Z-dz/length*insetB, BY=q.Y, Width=28})
	end
	link("Sanctuary", "Basin")
	link("Basin", "WestGallery"); link("Basin", "EastGallery"); link("Basin", "Crossing")
	link("Crossing", "Apex")
	if index >= 4 then
		link("WestGallery", "WestBastion"); link("EastGallery", "EastBastion")
		link("WestBastion", "Apex"); link("EastBastion", "Apex")
	else
		link("WestGallery", "Apex"); link("EastGallery", "Apex")
	end
	local camps = {}
	local function camp(id, terrace, dx, elite, boss, size)
		local p = platforms[terrace]
		table.insert(camps, {Id=id, Platform=terrace, X=p.X+(dx or 0), Y=p.Y, Z=p.Z,
			Elite=elite or false, Boss=boss or false, Size=size or 4})
	end
	-- Live camps per floor: 16 / 22 / 25 / 35 / 35 mobs, led by 1 / 2 / 3 / 4 / 4 Elites. The Basin
	-- centre stays clear so arrivals land out of aggro. The Apex camp is never pre-placed: it marks
	-- where the floor champion (or Biome Boss) is summoned.
	local size = if index == 1 then 4 else 5
	camp("BASIN_WEST", "Basin", -110, false, false, if index == 2 then 4 else size)
	camp("BASIN_EAST", "Basin", 110, false, false, if index == 2 then 4 else size)
	if index >= 2 then camp("CENTRAL_CROSSING", "Crossing", 0, index == 3, false, if index == 2 then 4 else 5) end
	camp("WEST_GALLERY", "WestGallery", 0, true, false, size)
	camp("EAST_GALLERY", "EastGallery", 0, index >= 2, false, size)
	if index >= 4 then
		camp("UPPER_WEST", "WestBastion", 0, true, false, 5)
		camp("UPPER_EAST", "EastBastion", 0, true, false, 5)
	end
	if index == 5 then camp("APEX_SANCTUM", "Apex", 0, false, true, 5) else camp("APEX_SANCTUM", "Apex", 0, true) end
	return {Width=w, Depth=d, Height=heights[index], Bottom=if index==5 then -6 elseif index>=3 then -4 else 0,
		Platforms=platforms, Links=links, Camps=camps, Sanctuary=safe}
end

function Layout.Placements(biome: any, index: number): {any}
	local result = {}
	for _, camp in Layout.Get(index).Camps do
		for slot=1,camp.Size do
			local enemy = biome.RegularEnemyIds[if slot%2==0 then 2 else 1]
			if camp.Boss and slot==1 then enemy=biome.BossEnemyId
			elseif camp.Boss and slot<=3 then enemy=biome.EliteEnemyId
			elseif camp.Elite and slot==1 then enemy=if camp.Id=="APEX_SANCTUM" then biome.AlphaEnemyId else biome.EliteEnemyId end
			local offsets = {{0,0},{-18,12},{18,12},{-12,-16},{12,-16}}
			table.insert(result, {EnemyId=enemy, X=camp.X+offsets[slot][1], Y=camp.Y, Z=camp.Z+offsets[slot][2],
				CampId="CAMP_"..camp.Id, LeashRadius=if camp.Boss then 95 else 60})
		end
	end
	return result
end
return table.freeze(Layout)
