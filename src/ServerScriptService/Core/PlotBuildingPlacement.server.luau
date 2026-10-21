--!strict
local Buildings = require(script.Parent:WaitForChild("PlotBuildings"))
local plots = workspace:WaitForChild("WaitingRoomPlots")
for _, plot in plots:GetChildren() do
	Buildings.Build(plot)
	task.wait()
end
plots.ChildAdded:Connect(function(plot)
	plot:WaitForChild("PlotSpawn", 15)
	Buildings.Build(plot)
end)
