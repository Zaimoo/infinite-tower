--!strict
-- Whole-prop clearance for tower floors. Compound props (a tree, a spire, an island and what stands on
-- it) are Models tagged with a PropKind attribute. When any part of a prop conflicts with a camp or a
-- walking lane, the whole prop goes, so no canopy, cap or spire tip is left floating in the air.
-- Loose parts that belong to no prop are judged on their own.
local PropClearance = {}

export type HitTest = (part: BasePart) -> boolean

-- The unit a part is removed with: its outermost PropKind Model below `root`, or the part itself.
function PropClearance.UnitOf(part: BasePart, root: Instance): Instance
	local unit: Instance = part
	local node = part.Parent
	while node and node ~= root do
		if node:GetAttribute("PropKind") ~= nil then
			unit = node
		end
		node = node.Parent
	end
	return unit
end

-- Destroys every unit under `root` that has at least one BasePart for which `hits` returns true.
-- Returns how many units were removed.
function PropClearance.Apply(root: Instance, hits: HitTest): number
	local doomed: { [Instance]: boolean } = {}
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			local unit = PropClearance.UnitOf(descendant, root)
			if not doomed[unit] and hits(descendant) then
				doomed[unit] = true
			end
		end
	end
	local removed = 0
	for unit in doomed do
		if unit.Parent then
			unit:Destroy()
			removed += 1
		end
	end
	return removed
end

-- The props that clearance and settling act on: PropKind Models with no PropKind ancestor below `root`.
local function topProps(root: Instance): { Model }
	local props = {}
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("Model") and descendant:GetAttribute("PropKind") ~= nil then
			local nested = false
			local node = descendant.Parent
			while node and node ~= root do
				if node:GetAttribute("PropKind") ~= nil then nested = true break end
				node = node.Parent
			end
			if not nested then table.insert(props, descendant) end
		end
	end
	return props
end

-- Lowers every prop that hovers above its support until it rests on it. `root` must be in the
-- Workspace (this raycasts). A prop rests when the nearest support under any of its lowest parts is
-- within `tolerance`; a prop with nothing under it within `maxDrop` is removed. Kinds in `airborne`
-- hang by design and are left alone. Returns (lowered, removed).
function PropClearance.Settle(root: Instance, airborne: { [string]: boolean }, tolerance: number, maxDrop: number): (number, number)
	-- Decor is CanQuery = false; let every part act as a support while settling, then restore.
	local restored: { BasePart } = {}
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") and not descendant.CanQuery then
			descendant.CanQuery = true
			table.insert(restored, descendant)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local lowered, removed = 0, 0
	for _, prop in topProps(root) do
		if not airborne[prop:GetAttribute("PropKind") :: string] then
			local parts: { { position: Vector3, bottom: number } } = {}
			local minBottom = math.huge
			for _, descendant in prop:GetDescendants() do
				if descendant:IsA("BasePart") and descendant.Transparency < 0.95 then
					local cf, half = descendant.CFrame, descendant.Size / 2
					local lowest = math.huge
					for _, corner in { Vector3.new(1, 1, 1), Vector3.new(1, 1, -1), Vector3.new(1, -1, 1), Vector3.new(1, -1, -1),
						Vector3.new(-1, 1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, -1, -1) } do
						lowest = math.min(lowest, cf:PointToWorldSpace(half * corner).Y)
					end
					table.insert(parts, { position = descendant.Position, bottom = lowest })
					minBottom = math.min(minBottom, lowest)
				end
			end
			if #parts > 0 then
				params.FilterDescendantsInstances = { prop }
				local gap: number? = nil
				for _, entry in parts do
					if entry.bottom < minBottom + 1 then
						-- Start a little above the part's bottom so a support it already sinks into still counts.
						local hit = workspace:Raycast(Vector3.new(entry.position.X, entry.bottom + 4, entry.position.Z), Vector3.new(0, -(maxDrop + 4), 0), params)
						if hit then
							local g = entry.bottom - hit.Position.Y
							if gap == nil or g < gap then gap = g end
						end
					end
				end
				if gap == nil then
					prop:Destroy()
					removed += 1
				elseif gap > tolerance then
					prop:PivotTo(prop:GetPivot() - Vector3.new(0, gap, 0))
					lowered += 1
				end
			end
		end
	end
	for _, part in restored do
		if part.Parent then part.CanQuery = false end
	end
	return lowered, removed
end

return table.freeze(PropClearance)
