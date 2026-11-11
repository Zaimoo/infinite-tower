--!strict
local R = game:GetService("ReplicatedStorage")
local React = require(R.Packages.React)
local Loadout = require(R.Assets.HeroRig.HeroLoadout)
local Animator = require(R.Assets.HeroRig.HeroAnimator)
local Clips = require(R.Assets.HeroRig.HeroClips)
local e = React.createElement

return function(props: any)
	local ref = React.useRef(nil)
	React.useEffect(function()
		local viewport = ref.current
		local template = R.Assets.Heroes:FindFirstChild(props.Hero.TemplateId)
		if not viewport or not template or not template:IsA("Model") then return end
		local rig = template:Clone()
		for _, d in rig:GetDescendants() do
			if d:IsA("BaseScript") then d:Destroy() end
		end
		local idle = Clips.Get(props.Hero.TemplateId, nil, "Idle")
		if idle and rig:GetAttribute("HeroRigVersion") then Animator.ApplyStaticPose(rig, Animator.Sample(idle, 0)) end
		Loadout.Equip(rig, rig, props.Artifact.TemplateId, props.Artifact.Type, props.Artifact.Rarity)
		for _, d in rig:GetDescendants() do if d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false end end
		rig.Parent = viewport
		local cf, size = rig:GetBoundingBox()
		local camera = Instance.new("Camera")
		camera.FieldOfView = 35
		camera.CFrame = CFrame.lookAt(cf.Position + (cf.LookVector + cf.RightVector * 0.18).Unit * (size.Magnitude * 1.5), cf.Position)
		camera.Parent = viewport; viewport.CurrentCamera = camera
		return function() rig:Destroy(); camera:Destroy() end
	end, { props.Hero.TemplateId, props.Artifact.TemplateId })
	return e("ViewportFrame", { ref = ref, Name = "EquippedHeroPreview", BackgroundTransparency = 1, Size = props.Size or UDim2.fromScale(1, 1), Ambient = Color3.fromRGB(125, 118, 138), LightColor = Color3.fromRGB(255, 240, 220), LightDirection = Vector3.new(-1, -2, 2) }) -- the rig faces -Z: light travels towards +Z to reach its front
end
