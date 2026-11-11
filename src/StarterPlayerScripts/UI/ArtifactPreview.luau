--!strict
-- StarterPlayerScripts/UI/ArtifactPreview.luau
-- 3D weapon preview for UI hosts (Forge tiles, detail panel, summon reveal).
--
-- A ViewportFrame draws at its on-screen pixel size with no anti-aliasing, so the only way to make a
-- preview sharper is to spend those pixels on the weapon. Each model is therefore posed like a
-- product shot (long weapons lie along the host's diagonal, flat side to the camera) and the camera
-- is fitted to the model's real silhouette for the host's aspect ratio, instead of backing off far
-- enough to hold its bounding sphere.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ArtifactCatalog = require(ReplicatedStorage.Shared.Config.ArtifactCatalog)

local ArtifactPreview = {}

export type PreviewOptions = {
	Spin: boolean?,
	FieldOfView: number?,
}

local DEFAULT_FOV = 22 -- narrow, so a long weapon is not distorted towards its ends
local MARGIN = 1.1 -- breathing room around the silhouette
local ELONGATED = 1.5 -- longest / middle extent above which a weapon is posed on the diagonal

local function visibleParts(model: Model): { BasePart }
	local parts = {}
	for _, object in model:GetDescendants() do
		if object:IsA("BasePart") and object.Transparency < 0.98 then table.insert(parts, object) end
	end
	return parts
end

-- Moves the model so its bounding box is centred on the origin in a display pose.
local function pose(model: Model, parts: { BasePart }, spin: boolean)
	local bounds, size = model:GetBoundingBox()
	local axes = {
		{ Dir = bounds.RightVector, Length = size.X, Native = false },
		{ Dir = bounds.UpVector, Length = size.Y, Native = true },
		{ Dir = bounds.LookVector, Length = size.Z, Native = false },
	}
	table.sort(axes, function(a, b) return a.Length > b.Length end)
	local long, middle, thin = axes[1], axes[2], axes[3]

	if long.Length < middle.Length * ELONGATED then
		-- Chunky (tomes, shields): keep the authored orientation, seen from a three-quarter angle.
		local tilt = CFrame.Angles(math.rad(18), 0, 0) * CFrame.Angles(0, math.rad(-32), 0)
		model:PivotTo(tilt * bounds:Inverse() * model:GetPivot())
		return
	end

	local up = long.Dir
	if not long.Native then
		-- Weapons authored along X or Z (staffs) have no "up": the end with more geometry is the head.
		local weight, moment = 0, 0
		for _, part in parts do
			local volume = part.Size.X * part.Size.Y * part.Size.Z
			weight += volume
			moment += volume * (part.Position - bounds.Position):Dot(up)
		end
		if weight > 0 and moment < 0 then up = -up end
	end
	local face = thin.Dir
	local orient = CFrame.fromMatrix(bounds.Position, up:Cross(face), up, face)
	local roll = if spin then -14 else -38 -- tip to the upper right
	local display = CFrame.Angles(math.rad(6), math.rad(-26), 0) * CFrame.Angles(0, 0, math.rad(roll))
	model:PivotTo(display * orient:Inverse() * model:GetPivot())
end

local function corners(parts: { BasePart }): { Vector3 }
	local points = {}
	for _, part in parts do
		local half = part.Size / 2
		for x = -1, 1, 2 do
			for y = -1, 1, 2 do
				for z = -1, 1, 2 do
					table.insert(points, part.CFrame:PointToWorldSpace(Vector3.new(half.X * x, half.Y * y, half.Z * z)))
				end
			end
		end
	end
	return points
end

-- Camera CFrame (looking down -Z) that just holds `points` for a host of this aspect ratio. With
-- `spin` the fit holds for any rotation about the vertical axis.
local function fit(points: { Vector3 }, fieldOfView: number, aspect: number, spin: boolean): CFrame
	local tanV = math.tan(math.rad(fieldOfView / 2))
	local tanH = tanV * aspect
	local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
	for _, p in points do
		minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
		minY, maxY = math.min(minY, p.Y), math.max(maxY, p.Y)
	end
	local cx = if spin then 0 else (minX + maxX) / 2
	local cy = (minY + maxY) / 2
	local distance = 0.1
	for _, p in points do
		local y = math.abs(p.Y - cy) * MARGIN
		if spin then
			local radius = math.sqrt(p.X * p.X + p.Z * p.Z)
			distance = math.max(distance, radius + math.max(radius * MARGIN / tanH, y / tanV))
		else
			distance = math.max(distance, p.Z + math.max(math.abs(p.X - cx) * MARGIN / tanH, y / tanV))
		end
	end
	return CFrame.new(cx, cy, distance)
end

function ArtifactPreview.Show(host: GuiObject, templateId: string?, options: PreviewOptions?): boolean
	local current = host:FindFirstChild("ArtifactModelPreview")
	if current and current:GetAttribute("TemplateId") == templateId then return true end
	if current then current:Destroy() end
	local seed = templateId and ArtifactCatalog.Seeds[templateId]
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local weapons = assets and assets:FindFirstChild("Weapons")
	local source = seed and weapons and weapons:FindFirstChild(seed.ModelAssetId)
	if not source or not source:IsA("Model") or not source:FindFirstChildWhichIsA("BasePart", true) then return false end

	local model = source:Clone()
	if not model then return false end
	for _, object in model:GetDescendants() do
		if object:IsA("LuaSourceContainer") or object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam") then
			object:Destroy()
		end
	end
	local parts = visibleParts(model)
	if #parts == 0 then return false end
	local spin = options ~= nil and options.Spin == true
	pose(model, parts, spin)
	local points = corners(parts)

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "ArtifactModelPreview"
	viewport:SetAttribute("TemplateId", templateId)
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.ZIndex = host.ZIndex + 1
	-- A key light from the upper left in front, over a bright cool ambient: metal reads as metal and
	-- the shadow side never goes to black against the dark card.
	viewport.Ambient = Color3.fromRGB(176, 170, 190)
	viewport.LightColor = Color3.fromRGB(255, 246, 228)
	viewport.LightDirection = Vector3.new(-0.5, -0.9, -0.75)

	local camera = Instance.new("Camera")
	camera.FieldOfView = options and options.FieldOfView or DEFAULT_FOV
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	model.Parent = viewport

	local function refit()
		local size = host.AbsoluteSize
		local aspect = if size.X > 1 and size.Y > 1 then size.X / size.Y else 1
		camera.CFrame = fit(points, camera.FieldOfView, aspect, spin)
	end
	refit()
	local resized = host:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	viewport.Parent = host

	local spinning: RBXScriptConnection? = nil
	if spin then
		local base = model:GetPivot()
		local angle = 0
		spinning = RunService.RenderStepped:Connect(function(dt)
			angle = (angle + dt * 0.9) % (math.pi * 2)
			model:PivotTo(CFrame.Angles(0, angle, 0) * base)
		end)
	end
	viewport.Destroying:Connect(function()
		resized:Disconnect()
		if spinning then spinning:Disconnect() end
	end)
	return true
end

return ArtifactPreview
