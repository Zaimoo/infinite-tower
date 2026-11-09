-- Remodelled tower enemy models (docs/tower-mob-remodel-plan.md §7). Bundled by run.ps1; `nodes` and `require`
-- come from the shim. Checks the generated TowerEnemyModelIndex against the live combat registry and clips.
local Index = require(nodes["ReplicatedStorage.Shared.Config.TowerEnemyModelIndex"])
local C = require(nodes["ReplicatedStorage.Shared.Config.FirstBiomeCombat"])
local Clips = require(nodes["ReplicatedStorage.Assets.TowerEnemyClips"])
local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end

-- §4 budgets: whole rig, and any one mesh (joint plus its glow pieces)
local BUDGET = {
	REGULAR = { Rig = 3500, Mesh = 1600 },
	SUPPORT = { Rig = 3000, Mesh = 1600 },
	ELITE = { Rig = 8000, Mesh = 3000 },
	ALPHA = { Rig = 9000, Mesh = 3000 },
	BOSS = { Rig = 20000, Mesh = 8000 },
}

local function jointsDrivenBy(enemyId: string): { [string]: boolean }
	local driven = {}
	for _, frames in Clips[enemyId] do
		if type(frames) == "table" then
			for _, frame in frames do
				if type(frame) == "table" and type(frame[2]) == "table" then
					for joint in frame[2] do driven[joint] = true end
				end
			end
		end
	end
	return driven
end

local function count(t: { [any]: any }): number
	local n = 0
	for _ in t do n += 1 end
	return n
end

test("Every remodelled enemy is a real combat enemy with a clip set", function()
	assert(count(Index) >= 1, "the index is empty")
	for id, entry in Index do
		assert(C.Get(id), "no combat entry for " .. id)
		assert(Clips[id], "no clip set for " .. id)
		assert(entry.EnemyId == id)
	end
end)

test("Models carry every joint their clips drive, under the parents the rigs use", function()
	local bipedParents = { Head = "Body", ArmL = "Body", ArmR = "Body", ForearmL = "ArmL", ForearmR = "ArmR", LegL = "Body", LegR = "Body", KneeL = "LegL", KneeR = "LegR" }
	for id, entry in Index do
		local byName = {}
		for _, s in entry.Segments do
			assert(not byName[s.Name], id .. ": duplicate joint " .. s.Name)
			byName[s.Name] = s
		end
		-- Crawler families share the biped Idle/Hit clips, whose arm/leg keys their rigs simply don't have,
		-- so only the clip joints that belong to the enemy's own skeleton are required.
		local crawler = entry.Family == "CRAWLER" or entry.Family == "INSECT" or entry.Family == "CRUSTACEAN"
			or entry.Family == "SCORPION" or entry.Family == "SIX_LEGGED_CRAWLER"
		for joint in jointsDrivenBy(id) do
			local own = if crawler then (joint == "Body" or joint == "Head" or string.match(joint, "^Jaw[LR]$") or string.match(joint, "^Leg%-?1_%d$") or string.match(joint, "^Knee%-?1_%d$"))
				else bipedParents[joint] ~= nil or joint == "Body"
			if own then assert(byName[joint], id .. " is missing joint " .. joint .. " that its clips animate") end
		end
		assert(byName.Body and byName.Body.Parent == nil, id .. ": Body must be the root joint")
		for name, s in byName do
			if bipedParents[name] then
				assert(s.Parent == bipedParents[name], id .. ": " .. name .. " should hang from " .. bipedParents[name])
			elseif s.Parent then
				assert(byName[s.Parent], id .. ": " .. name .. " hangs from unknown " .. s.Parent)
			end
			local legSide, legIndex = string.match(name, "^Knee(%-?1)_(%d)$")
			if legSide then assert(s.Parent == "Leg" .. legSide .. "_" .. legIndex, id .. ": " .. name .. " must hang from its leg") end
		end
	end
end)

test("Models stay inside the triangle budgets", function()
	for id, entry in Index do
		local b = assert(BUDGET[entry.Role], id .. ": unknown role " .. tostring(entry.Role))
		assert(entry.TotalTris <= b.Rig, string.format("%s: %d tris, budget %d", id, entry.TotalTris, b.Rig))
		for _, s in entry.Segments do
			assert(s.Tris <= b.Mesh, string.format("%s/%s: %d tris, mesh budget %d", id, s.Name, s.Tris, b.Mesh))
		end
	end
end)

test("Alphas have their Elite remodelled too, and roles match the combat registry", function()
	for id, entry in Index do
		local spec = C.Get(id)
		if entry.Role == "ALPHA" then
			assert(spec.Alpha, id .. " is not an Alpha in the registry")
			local elite = "elite_" .. string.gsub(id, "^alpha_", "")
			assert(Index[elite], id .. " needs " .. elite .. " remodelled too")
		elseif entry.Role == "SUPPORT" then
			assert(spec.Support, id .. " is not a Support in the registry")
		else
			assert(spec.Role == entry.Role, id .. ": role " .. entry.Role .. " vs registry " .. spec.Role)
		end
	end
end)

print(`enemy-models.spec: {passed} passed`)
