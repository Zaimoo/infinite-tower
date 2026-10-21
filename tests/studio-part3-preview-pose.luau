-- Execute in Edit after creating TowerPart3AssetPreviews. Optional `previewPhase` (0..1).
-- Samples the same authored clips, propagating native joint/weld transforms for still QA.
local Clips=require(game.ReplicatedStorage.Assets.TowerEnemyClips)
local folder=assert(workspace:FindFirstChild("TowerPart3AssetPreviews"))
for _,model in folder:GetChildren() do if model:IsA("Model") then
	-- Edit-time CFrame writes otherwise move the connected assembly and its root.
	for _,v in model:GetDescendants() do if v:IsA("BasePart") then v.Anchored=true
		elseif v:IsA("Motor6D") or v:IsA("WeldConstraint") then v.Enabled=false end end
	local index=model.Name=="mob_moss_crawler" and 0 or model.Name=="elite_vinebound" and 1 or 2
	local height=require(game.ReplicatedStorage.Shared.Config.FirstBiomeCombat).Get(model.Name).RootHeight
	model.PrimaryPart.CFrame=CFrame.new(index*40,3000+height,0)
	local slot=model.Name=="boss_mossbound_guardian" and "Signature1" or model.Name=="elite_vinebound" and "Special" or "BasicAttack"
	local poses=Clips.Sample(Clips[model.Name][slot],previewPhase or .8)
	local edges={}
	for _,joint in model:GetDescendants() do
		if joint:IsA("Motor6D") or joint:IsA("WeldConstraint") then
			local first,second=joint.Part0,joint.Part1
			if first and second then
				if joint:GetAttribute("PreviewBind")==nil then joint:SetAttribute("PreviewBind",joint:IsA("Motor6D") and joint.C0 or first.CFrame:ToObjectSpace(second.CFrame)) end
				edges[first]=edges[first] or {};table.insert(edges[first],joint)
			end
		end
	end
	local queue={model.PrimaryPart};local index=1
	while queue[index] do
		local first=queue[index];index+=1
		for _,joint in edges[first] or {} do
			local transform=joint:GetAttribute("PreviewBind")
			if joint:IsA("Motor6D") then transform=transform*(poses[joint.Name] or CFrame.identity)*joint.C1:Inverse() end
			joint.Part1.CFrame=first.CFrame*transform;table.insert(queue,joint.Part1)
		end
	end
end end
return "Previewed authored contact poses"
