--!strict
local Traversal = require(script.Parent:WaitForChild("TowerTraversal"))
local geometry = workspace:WaitForChild("BaseOverhaulGeometry")
local function apply(model: Instance)
	if model.Name == "CentralCrimsonTower" and model:IsA("Model") then
		model:WaitForChild("TowerRings")
		task.defer(Traversal.Apply, model)
	end
end
geometry.ChildAdded:Connect(apply)
for _, model in geometry:GetChildren() do apply(model) end
