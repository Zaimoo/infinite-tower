--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArtifactCatalog = require(ReplicatedStorage.Shared.Config.ArtifactCatalog)

local ArtifactPreview = {}

function ArtifactPreview.Show(host: GuiObject, templateId: string?): boolean
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
	local bounds, size = model:GetBoundingBox()
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "ArtifactModelPreview"
	viewport:SetAttribute("TemplateId", templateId)
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.ZIndex = host.ZIndex + 1
	viewport.Ambient = Color3.fromRGB(200, 191, 214)
	viewport.LightColor = Color3.fromRGB(255, 240, 214)
	viewport.LightDirection = Vector3.new(-1, -2, -2)

	local camera = Instance.new("Camera")
	camera.FieldOfView = 38
	local center = bounds.Position
	local distance = math.max(0.1, size.Magnitude / (2 * math.tan(math.rad(camera.FieldOfView / 2))) * 1.14)
	camera.CFrame = CFrame.lookAt(center + Vector3.new(0.7, 0.48, 1).Unit * distance, center)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	model.Parent = viewport
	viewport.Parent = host
	return true
end

return ArtifactPreview
