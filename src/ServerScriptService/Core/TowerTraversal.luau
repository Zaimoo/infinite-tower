--!strict
-- Real shell collision, solid floor platforms, and a continuous exterior ascent.
local Traversal = {}
local VERSION = 3
function Traversal.Apply(tower: Model)
	if tower:GetAttribute("TraversalVersion") == VERSION then return end
	local rings = tower:FindFirstChild("TowerRings")
	if not rings then return end
	local previous = tower:FindFirstChild("WalkableTower")
	if previous then previous:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "WalkableTower", tower
	local function block(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame = name, size, cf
		p.Anchored, p.CanCollide, p.CanQuery = true, true, true
		p.CanTouch, p.Color, p.Material = false, color, material
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = parent
		return p
	end
	local ground = tower:FindFirstChild("CrackedSmokyBase")
	local slab = ground and ground:FindFirstChild("CrackedGroundSlab")
	if slab and slab:IsA("BasePart") then slab.CanCollide, slab.CanQuery = true, true end
	local entrance = tower:FindFirstChild("TowerBaseEntrance")
	local portal = entrance and entrance:FindFirstChild("EntrancePortalTrigger")
	if portal and portal:IsA("BasePart") then portal.CanCollide, portal.CanQuery = false, false end
	local entries: {any} = {}
	for _, core in rings:GetChildren() do
		local index = tonumber(core.Name:match("^TowerRingCore_(%d+)$"))
		if index and core:IsA("Part") then
			local ledge = rings:FindFirstChild(string.format("TowerRingLedge_%02d", index))
			if ledge and ledge:IsA("Part") then table.insert(entries, {Index = index, Core = core, Ledge = ledge}) end
		end
	end
	table.sort(entries, function(a, b) return a.Index < b.Index end)
	local lowerY = if slab and slab:IsA("BasePart") then slab.Position.Y + slab.Size.X / 2 else 16
	for entryNumber, entry in entries do
		local core, ledge = entry.Core, entry.Ledge
		local radius, height = core.Size.Y / 2, core.Size.X
		local center = core.Position
		local topY = ledge.Position.Y + ledge.Size.X / 2
		local batch = Instance.new("Model")
		batch.Name = string.format("Floor_%02d", entry.Index)
		batch:SetAttribute("PlatformY", topY)
		-- Keep the original cylinder as dimension metadata; a hollow shell replaces it.
		core.Transparency, core.CanCollide, core.CanQuery = 1, false, false
		ledge.Transparency, ledge.CanCollide, ledge.CanQuery = 1, false, false
		ledge:SetAttribute("WalkablePlatform", true)
		local above = entries[entryNumber + 1]
		local inner = above and above.Core.Size.Y / 2 - 4 or radius - 4
		local outer = ledge.Size.Y / 2
		local endAngle = -math.pi / 4 + entry.Index * math.pi / 2
		local floorDisk = block(batch, "InteriorFloor", Vector3.new(ledge.Size.X, inner * 2, inner * 2), CFrame.new(ledge.Position) * CFrame.Angles(0, 0, math.pi / 2), ledge.Color, ledge.Material)
		floorDisk.Shape = Enum.PartType.Cylinder
		for i = 0, 191 do
			local angle = (i + .5) * math.pi * 2 / 192
			local relative = math.atan2(math.sin(angle - endAngle), math.cos(angle - endAngle))
			-- The stairwell notch prevents the ascending ramp meeting a solid ceiling.
			local segmentOuter = if relative < -.36 or relative > .035 then outer else math.min(outer, radius + 1.5)
			if segmentOuter > inner then
				local midRadius = (inner + segmentOuter) / 2
				local pos = Vector3.new(center.X + math.cos(angle) * midRadius, ledge.Position.Y, center.Z + math.sin(angle) * midRadius)
				block(batch, "WalkablePlatform", Vector3.new(2 * segmentOuter * math.tan(math.pi / 192) + .15, ledge.Size.X, segmentOuter - inner + .2), CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z)), ledge.Color, ledge.Material)
			end
		end
		for i = 0, 95 do
			local angle = (i + .5) * math.pi * 2 / 96
			local pos = center + Vector3.new(math.cos(angle) * (radius - 2), 0, math.sin(angle) * (radius - 2))
			local inGate = false
			if entry.Index == 1 and portal and portal:IsA("BasePart") then
				local localPos = portal.CFrame:PointToObjectSpace(pos)
				inGate = math.abs(localPos.X) < portal.Size.X / 2 + 2 and math.abs(localPos.Z) < 35
			end
			if not inGate then
				block(batch, "SolidTowerWall", Vector3.new(2 * radius * math.tan(math.pi / 96) + .35, height, 4), CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z)), core.Color, core.Material)
			elseif center.Y + height / 2 > portal.Position.Y + portal.Size.Y / 2 then
				local y = portal.Position.Y + portal.Size.Y / 2
				local h = center.Y + height / 2 - y
				block(batch, "GateOverheadWall", Vector3.new(2 * radius * math.tan(math.pi / 96) + .35, h, 4), CFrame.lookAt(Vector3.new(pos.X, y + h / 2, pos.Z), Vector3.new(center.X, y + h / 2, center.Z)), core.Color, core.Material)
			end
		end
		-- A quarter-turn ramp per level joins the existing crimson platforms.
		local rampRadius = radius + 8
		local startAngle = -math.pi / 4 + (entry.Index - 1) * math.pi / 2
		for i = 0, 31 do
			local function point(t: number): Vector3
				local a = startAngle + t * math.pi / 2
				return Vector3.new(center.X + math.cos(a) * rampRadius, lowerY + (topY - lowerY) * t, center.Z + math.sin(a) * rampRadius)
			end
			local a, b = point(i / 32), point((i + 1) / 32)
			local cf = CFrame.lookAt((a + b) / 2, b)
			block(batch, "AscentRamp", Vector3.new(10, 1.5, (b - a).Magnitude + .3), cf * CFrame.new(0, -.75, 0), Color3.fromRGB(69, 48, 57), Enum.Material.Slate)
			block(batch, "OuterRampRail", Vector3.new(.6, 3, (b - a).Magnitude + .3), cf * CFrame.new(-4.9, 1.5, 0), Color3.fromRGB(112, 26, 37), Enum.Material.Granite)
		end
		local landing = Vector3.new(center.X + math.cos(endAngle) * (rampRadius - 3.8), topY, center.Z + math.sin(endAngle) * (rampRadius - 3.8))
		local tangent = Vector3.new(-math.sin(endAngle), 0, math.cos(endAngle))
		block(batch, "RampLanding", Vector3.new(20, 1.5, 12), CFrame.lookAt(landing, landing + tangent) * CFrame.new(0, -.75, 0), ledge.Color, ledge.Material)
		batch.Parent = folder
		lowerY = topY
		task.wait()
	end
	tower:SetAttribute("TraversalVersion", VERSION)
	tower:SetAttribute("WalkableFloors", #entries)
end
return Traversal
