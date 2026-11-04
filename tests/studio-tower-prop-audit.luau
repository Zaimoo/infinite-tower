-- Run in Studio Edit mode after syncing src (Studio MCP execute_luau or the command bar):
--   return require(path.to.this)(1, 50)
-- or paste the body and call it. Builds each floor, audits its props, then removes the floor again.
--
-- A prop is "orphaned" when one of its pieces survives without the piece that holds it up: a canopy
-- without its trunk, a spire tip without its shaft, an arch top without its piers. A prop is
-- "floating" when nothing is within 1.5 studs under any of its lowest parts (props that hang by design,
-- TowerBiomeAssets.AirborneKinds, are skipped). A prop "blocks a walkway" when any of its parts stands on
-- a ramp, stair, landing pad, the Basin causeway or the Sanctuary exit (TowerRoomBuilder.WalkwayHitTest).
-- All three counts must be 0 on every floor.
--
-- Studio caches modules it has already required. If you re-run after editing src, pass
-- `freshCopy = true` so the builder is required from a fresh clone of the modules.
return function(firstFloor: number, lastFloor: number, keepPreviews: boolean?, freshCopy: boolean?)
	local core: Instance = game.ServerScriptService.Core
	local scratch: Folder? = nil
	if freshCopy then
		local folder = Instance.new("Folder")
		folder.Name = "PropAuditCore"
		for _, name in { "TowerRoomBuilder", "TowerBiomeAssets", "TowerPropClearance" } do
			local copy = core[name]:Clone()
			-- TowerLayout is cached too: point the copies at a fresh copy of it.
			copy.Source = copy.Source:gsub("game%.ReplicatedStorage%.Shared%.Config%.TowerLayout", "script.Parent.TowerLayout")
			copy.Parent = folder
		end
		game.ReplicatedStorage.Shared.Config.TowerLayout:Clone().Parent = folder
		folder.Parent = game:GetService("ServerStorage")
		core, scratch = folder, folder
	end
	local Builder = require(core.TowerRoomBuilder)
	local Airborne = require(core.TowerBiomeAssets).AirborneKinds

	-- family = { anchor part names, dependent part names }
	local families = {
		Tree = { { "AncientTrunk" }, { "ButtressRoot", "CanopyBough", "FoliageCluster", "HangingJungleVine", "MainCanopyCrown", "CrimsonBarkFissure", "CorruptedCanopyWisp" } },
		Spire = { { "SpireShaft" }, { "SpirePlinth", "SpireUpperTier", "SpirePeakFacet", "SpireRuneX", "SpireRuneZ" } },
		Mushroom = { { "MushroomStemLower", "MushroomStemUpper" }, { "MushroomCapDome", "MushroomCapApex", "LuminousGills", "BioluminescentSpot", "HangingTendril", "TendrilSporeBulb", "MushroomStemRing" } },
		Arch = { { "ArchPier" }, { "ArchVoussoir", "ArchPierCap", "ArchPierBase" } },
		Island = { { "InteriorChasmIslandBase" }, { "InteriorChasmIslandCrown" } },
		Outcrop = { { "TerraceRockOutcrop" }, { "TerraceGlowFlora" } },
		Brazier = { { "TerraceCornerPedestal" }, { "TerraceCornerBrazier" } },
		Curb = { { "BridgeCurb" }, { "BridgeRuneStrip" } },
	}
	local familyOf: { [string]: { family: string, anchor: boolean } } = {}
	for family, spec in families do
		for _, name in spec[1] do familyOf[name] = { family = family, anchor = true } end
		for _, name in spec[2] do familyOf[name] = { family = family, anchor = false } end
	end

	local report = {}
	local totals = { Orphans = 0, LooseFamilyParts = 0, Props = 0, ClearedCamps = 0, ClearedLanes = 0, Floating = 0, Lowered = 0, OnWalkway = 0 }

	-- Smallest gap between a prop's lowest parts and whatever is under them (nil: nothing below).
	local function supportGap(prop: Instance, params: RaycastParams): number?
		local entries, minBottom = {}, math.huge
		for _, d in prop:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 0.95 then
				local lowest = math.huge
				for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
					lowest = math.min(lowest, d.CFrame:PointToWorldSpace(d.Size / 2 * Vector3.new(sx, sy, sz)).Y)
				end end end
				table.insert(entries, { d.Position, lowest })
				minBottom = math.min(minBottom, lowest)
			end
		end
		params.FilterDescendantsInstances = { prop }
		local gap: number? = nil
		for _, e in entries do
			if e[2] < minBottom + 1 then
				local hit = workspace:Raycast(Vector3.new(e[1].X, e[2] + 4, e[1].Z), Vector3.new(0, -300, 0), params)
				if hit and (gap == nil or e[2] - hit.Position.Y < gap) then gap = e[2] - hit.Position.Y end
			end
		end
		return gap
	end
	for id = firstFloor, lastFloor do
		local room = Builder.Build(id, 1)
		local model = room.Model
		local kit = model:FindFirstChild("BiomeAssets")
		local orphans: { [string]: number } = {}
		local loose = 0
		local props = 0
		local floating: { string } = {}
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then d.CanQuery = true end -- audit copy only: every part can support
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude

		-- Scenery still standing on a walkway after the build's own clearance.
		local onWalkway = Builder.WalkwayHitTest(model, room.Origin, (id - 1) % 5 + 1)
		local blocking: { [Instance]: boolean } = {}
		local blockingNames: { string } = {}
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and onWalkway(d) then
				local unit = d
				local node = d.Parent
				while node and node ~= model do
					if node:GetAttribute("PropKind") ~= nil then unit = node end
					node = node.Parent
				end
				if not blocking[unit] then
					blocking[unit] = true
					table.insert(blockingNames, unit.Name)
				end
			end
		end

		-- Every compound piece must sit inside a PropKind group.
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and familyOf[d.Name] then
				local inGroup = false
				local node = d.Parent
				while node and node ~= model do
					if node:GetAttribute("PropKind") ~= nil then inGroup = true break end
					node = node.Parent
				end
				if not inGroup then loose += 1 end
			end
		end

		-- Inside each top-level group, any family piece needs that family's anchor in the same group.
		local function auditGroup(group: Instance)
			props += 1
			if not Airborne[group:GetAttribute("PropKind") :: string] then
				local gap = supportGap(group, params)
				if gap == nil or gap > 1.5 then
					local at = (group :: Model):GetBoundingBox().Position - room.Origin
					table.insert(floating, string.format("%s(%s @ %d,%d,%d)", group.Name, if gap then string.format("%.1f", gap) else "none", at.X, at.Y, at.Z))
				end
			end
			local has: { [string]: { anchor: boolean, dependent: number } } = {}
			for _, d in group:GetDescendants() do
				local f = d:IsA("BasePart") and familyOf[d.Name]
				if f then
					local entry = has[f.family] or { anchor = false, dependent = 0 }
					has[f.family] = entry
					if f.anchor then entry.anchor = true else entry.dependent += 1 end
				end
			end
			for family, entry in has do
				if entry.dependent > 0 and not entry.anchor then
					orphans[family] = (orphans[family] or 0) + entry.dependent
				end
			end
		end
		for _, container in { model, kit } do
			if container then
				for _, child in container:GetChildren() do
					if child:IsA("Model") and child:GetAttribute("PropKind") ~= nil then auditGroup(child) end
				end
			end
		end

		local orphanText, orphanCount = {}, 0
		for family, n in orphans do
			table.insert(orphanText, family .. "=" .. n)
			orphanCount += n
		end
		table.sort(orphanText)
		local clearedCamps = kit and kit:GetAttribute("PropsClearedForCamps") or 0
		local clearedLanes = model:GetAttribute("PropsClearedForLanes") or 0
		totals.Orphans += orphanCount
		totals.LooseFamilyParts += loose
		totals.Props += props
		totals.ClearedCamps += clearedCamps
		totals.ClearedLanes += clearedLanes
		totals.Floating += #floating
		totals.Lowered += model:GetAttribute("PropsLowered") or 0
		totals.OnWalkway += #blockingNames
		table.insert(report, string.format("F%02d %-17s props %4d | cleared camps %3d lanes %3d | lowered %3d | loose %d | orphans %s | floating %d %s | on walkway %d %s",
			id, model:GetAttribute("BiomeId"), props, clearedCamps, clearedLanes, model:GetAttribute("PropsLowered") or 0, loose,
			if #orphanText > 0 then table.concat(orphanText, ",") else "0", #floating, table.concat(floating, " "),
			#blockingNames, table.concat(blockingNames, " ")))
		if not keepPreviews then model:Destroy() end
		task.wait()
	end
	table.insert(report, string.format("TOTAL props %d | cleared camps %d lanes %d | lowered %d | loose family parts %d | orphans %d | floating %d | on walkway %d",
		totals.Props, totals.ClearedCamps, totals.ClearedLanes, totals.Lowered, totals.LooseFamilyParts, totals.Orphans, totals.Floating, totals.OnWalkway))
	if scratch then scratch:Destroy() end
	return table.concat(report, "\n")
end
