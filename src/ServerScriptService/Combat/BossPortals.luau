--!strict
local Geometry = require(script.Parent.BossPortalGeometry)

local BossPortals = {}

function BossPortals.Build(origin: CFrame, floorId: number, retry: boolean): (Model, ProximityPrompt, BasePart)
	local model = Instance.new("Model")
	model.Name = if retry then "RetryPortal" else "AscensionPortal"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local title = if retry then "Retry Floor" elseif floorId == 50 then "Return to Hub" else "Next Floor"
	local subtitle = if retry then "SANCTUARY • RESET BOSS" elseif floorId == 50 then "TOWER COMPLETE" else "FLOOR " .. (floorId + 1)
	local color = if retry then Color3.fromRGB(255, 171, 78) else Color3.fromRGB(84, 222, 255)

	local function part(name: string, size: Vector3, cf: CFrame, material: Enum.Material, tint: Color3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = origin * cf
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Material = material
		p.Color = tint
		p.Parent = model
		return p
	end

	for _, piece in Geometry do
		local role = piece.Role
		local material = if role == "Rune" then Enum.Material.Neon elseif role == "Trim" then Enum.Material.Metal else Enum.Material.Slate
		local tint = if role == "Rune" then color elseif role == "Trim" then color:Lerp(Color3.fromRGB(36, 33, 41), 0.55) else Color3.fromRGB(34, 29, 45)
		part(role, piece.Size, CFrame.new(piece.Position) * CFrame.Angles(0, 0, piece.Roll), material, tint)
	end

	local vortex = part("Vortex", Vector3.new(0.18, 7.4, 7.4), CFrame.new(0, 5.2, 0) * CFrame.Angles(0, math.pi / 2, 0),
		Enum.Material.Neon, color:Lerp(Color3.fromRGB(28, 15, 58), 0.5))
	vortex.Shape = Enum.PartType.Cylinder
	vortex.Transparency = 0.42
	vortex.CastShadow = false

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 16
	light.Brightness = 1.8
	light.Parent = vortex

	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	sparks.LightEmission = 0.9
	sparks.Rate = 16
	sparks.Lifetime = NumberRange.new(0.7, 1.35)
	sparks.Speed = NumberRange.new(1, 4)
	sparks.SpreadAngle = Vector2.new(55, 55)
	sparks.EmissionDirection = Enum.NormalId.Left
	sparks.RotSpeed = NumberRange.new(-120, 120)
	sparks.Size = NumberSequence.new(0.45, 0)
	sparks.Transparency = NumberSequence.new(0.15, 1)
	sparks.Parent = vortex

	local trigger = part("PortalTrigger", Vector3.one, CFrame.new(0, 3, 2), Enum.Material.SmoothPlastic, color)
	trigger.Transparency = 1
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = title
	prompt.ObjectText = subtitle
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.ClickablePrompt = true
	prompt.Parent = trigger

	local sign = Instance.new("BillboardGui")
	sign.Name = "Destination"
	sign.Size = UDim2.fromScale(12, 2.5)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 9.2, -2)
	sign.MaxDistance = 90
	sign.Parent = trigger

	for index, text in { title, subtitle } do
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, if index == 1 then 0.62 else 0.38)
		label.Position = UDim2.fromScale(0, if index == 1 then 0 else 0.62)
		label.BackgroundTransparency = 1
		label.Text = text
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = if index == 1 then Color3.new(1, 1, 1) else color
		label.TextScaled = true
		label.TextStrokeTransparency = 0.2
		label.Parent = sign
	end

	vortex:AddTag("BossPortalVortex")
	return model, prompt, trigger
end

return BossPortals
