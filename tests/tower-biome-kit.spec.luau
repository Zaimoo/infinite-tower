-- Tower Biome Kit and per-biome floor lighting specs. Bundled by run.ps1 after the module list; `nodes`,
-- `register` and `require` come from the shim.
local Kit = require(nodes["ReplicatedStorage.Shared.Config.TowerBiomeKit"])
local Light = require(nodes["ReplicatedStorage.Shared.Config.HubLighting"])
local Floors = require(nodes["ReplicatedStorage.Shared.Config.TowerFloorConfig"])
local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end

local ROLES = {
	STONE = true, TRIM = true, ACCENT = true, MOSS = true, GLOW = true, WOOD = true, FOLIAGE = true,
	METAL = true, GOLD = true, CRYSTAL = true, CAP = true, STEM = true, ALT = true, CORAL = true,
}

test("Every kit template has a size, stands on the ground and uses known colour roles", function()
	local count = 0
	for name, t in Kit.Templates do
		count += 1
		assert(t.Size.X > 0 and t.Size.Y > 0 and t.Size.Z > 0, name .. " has no size")
		-- Feet and roots may dip a little (TowerKitProps caps the sink at placement).
		assert(t.Min.Y > -2.5 and t.Min.Y < 0.5, name .. " does not stand on its origin")
		assert(#t.Roles > 0, name .. " has no roles")
		for _, role in t.Roles do
			assert(ROLES[role], name .. " uses unknown role " .. role)
		end
	end
	assert(count == 30, "expected 30 templates, got " .. count)
end)

test("Every biome on the floor list has a kit whose templates exist", function()
	for id = 1, 50 do
		local floor = Floors.Get(id)
		local biome = Kit.Biomes[floor.BiomeId]
		assert(biome, "no kit for " .. floor.BiomeId)
		for _, name in { biome.Tree, biome.Spire, biome.Pine } do
			if name then
				assert(Kit.Templates[name], floor.BiomeId .. " names missing template " .. name)
			end
		end
		assert(#biome.Clutter > 0, floor.BiomeId .. " has no clutter")
		for _, name in biome.Clutter do
			assert(Kit.Templates[name], floor.BiomeId .. " clutter names missing template " .. name)
		end
		for role, swatch in biome.Palette do
			assert(ROLES[role], floor.BiomeId .. " palette has unknown role " .. role)
			-- (The shim models Color3 as a table and enum items as strings.)
			assert(swatch.Color ~= nil and swatch.Material ~= nil, floor.BiomeId .. " palette " .. role .. " is incomplete")
		end
	end
	for role in Kit.SharedPalette do
		assert(ROLES[role], "shared palette has unknown role " .. role)
	end
	for name in Kit.RefScale do
		assert(Kit.Templates[name], "RefScale names missing template " .. name)
	end
	for name in Kit.CastsShadow do
		assert(Kit.Templates[name] or Kit.ExtraTemplates[name], "CastsShadow names missing template " .. name)
	end
end)

test("Every extra floor-specific template has a size, stands on the ground and uses known colour roles", function()
	local count = 0
	for name, t in Kit.ExtraTemplates do
		count += 1
		assert(t.Size.X > 0 and t.Size.Y > 0 and t.Size.Z > 0, name .. " has no size")
		assert(t.Min.Y > -2.5 and t.Min.Y < 0.5, name .. " does not stand on its origin")
		assert(#t.Roles > 0, name .. " has no roles")
		for _, role in t.Roles do
			assert(ROLES[role], name .. " uses unknown role " .. role)
		end
	end
	assert(count >= 36, "expected Floor 2-5 and Floor 11-13 extra templates")
end)

test("Every biome has an ecosystem built from kit templates", function()
	for biomeId in Kit.Biomes do
		local e = Kit.Ecology[biomeId]
		assert(e, biomeId .. " has no ecology")
		assert(e.Groves > 0 and #e.Trees > 0 and #e.Understory > 0 and #e.Monoliths > 0, biomeId .. " ecology is empty")
		assert(e.TreeScale[1] > 0 and e.TreeScale[1] <= e.TreeScale[2] and e.MonolithScale[1] <= e.MonolithScale[2])
		for _, list in { e.Trees, e.Understory, e.SlopeForest, e.Monoliths } do
			for _, name in list do
				assert(Kit.Templates[name], biomeId .. " ecology names missing template " .. name)
			end
		end
		assert(e.SlopeForestCount == 0 or #e.SlopeForest > 0)
	end
end)

test("The kit has the pieces TowerBiomeAssets builds from", function()
	for _, name in { "ArchPierBase", "ArchPierSegment", "ArchCrown", "CliffRockA", "CliffRockB", "ChasmIsland",
		"CrystalSpire", "GiantMushroom", "LionGuardian", "RobedStatueStaff", "RobedStatueTrident", "PineTree",
		"BanyanTree", "BlightTree", "DeadTree" } do
		assert(Kit.Templates[name], "missing " .. name)
	end
	-- Arch crowns are drawn for a 24-stud span: their capitals sit on pier centres at x = +-12.
	local crown = Kit.Templates.ArchCrown
	assert(math.abs(crown.Min.X + crown.Size.X / 2) < 0.01, "the arch crown is not centred")
end)

test("Each tower floor takes its own biome's lighting grade", function()
	assert(#Light.BiomeGrades == 10)
	local storm = Light.Presets.Storm
	for i, grade in Light.BiomeGrades do
		for key, value in grade do
			assert(storm[key] ~= nil, "grade " .. i .. " sets unknown field " .. key)
			assert(typeof(value) == typeof(storm[key]), "grade " .. i .. " field " .. key .. " has the wrong type")
		end
		local preset = Light.TowerPreset(i)
		for key in storm do
			assert(preset[key] ~= nil, "graded preset " .. i .. " lacks " .. key)
		end
	end
	assert(Light.TowerPreset(nil) == storm)
	assert(Light.TowerPreset(99) == storm)
	for id = 1, 50 do
		local x = 12000 + ((id - 1) % 10) * 2400
		local z = 12000 + math.floor((id - 1) / 10) * 2400
		local floor = Floors.Get(id)
		for _, offset in { Vector3.zero, Vector3.new(250, 0, -300), Vector3.new(-280, 0, 320) } do
			assert(Light.TowerBiomeAt(x + offset.X, z + offset.Z) == floor.BiomeIndex, "floor " .. id .. " reads the wrong biome")
			assert(select(1, Light.Classify(x + offset.X, z + offset.Z)) == "Storm")
		end
	end
	assert(Light.TowerBiomeAt(0, 0) == nil, "the hub is not a tower floor")
	assert(Light.TowerBiomeAt(-14000, -14000) == nil, "the raid arena is not a tower floor")
end)

test("A floor with its own grade layers it over its biome's; the others keep the biome's", function()
	local storm = Light.Presets.Storm
	for id, grade in Light.FloorGrades do
		local biome = math.ceil(id / 5)
		local preset = Light.TowerPreset(biome, id)
		for key, value in grade do
			assert(typeof(value) == typeof(storm[key]), "floor grade " .. id .. " field " .. key .. " has the wrong type")
			assert(preset[key] == value, "floor " .. id .. " does not apply " .. key)
		end
		for key, value in Light.BiomeGrades[biome] do
			if grade[key] == nil then assert(preset[key] == value, "floor " .. id .. " lost its biome's " .. key) end
		end
		assert(Light.TowerPreset(biome, id) == preset, "floor grades are not cached")
	end
	assert(Light.FloorGrades[1] ~= nil, "floor 1 (Overgrown Threshold) has its dawn grade")
	assert(Light.FloorGrades[2] ~= nil, "floor 2 (Broken Aqueduct) has its morning grade")
	assert(Light.FloorGrades[3] ~= nil, "floor 3 (Rootway Crossing) has its noon grade")
	assert(Light.FloorGrades[4] ~= nil, "floor 4 (Vinebound Bastion) has its overcast grade")
	assert(Light.FloorGrades[5] ~= nil, "floor 5 (Mossbound Court) has its golden-hour dusk grade")
	assert(Light.FloorGrades[11] ~= nil, "floor 11 (Cinder Gate) has its searing desert noon grade")
	assert(Light.FloorGrades[12] ~= nil, "floor 12 (Buried Caravan) has its afternoon sandstorm grade")
	assert(Light.FloorGrades[13] ~= nil, "floor 13 (Glasswind Ravine) has its ravine dusk grade")
	assert(Light.TowerPreset(2, 6) == Light.TowerPreset(2), "a floor without its own grade shares its biome's")
	for id = 1, 50 do
		local x = 12000 + ((id - 1) % 10) * 2400
		local z = 12000 + math.floor((id - 1) / 10) * 2400
		assert(Light.TowerFloorAt(x + 200, z - 250) == id, "floor " .. id .. " reads the wrong floor id")
	end
	assert(Light.TowerFloorAt(0, 0) == nil)
end)

print(string.format("tower-biome-kit: %d passed", passed))
