-- Enemy spawn positions follow the baked tower geometry.
local Layout = {}
local function rings()
 return workspace:WaitForChild("BaseOverhaulGeometry"):WaitForChild("CentralCrimsonTower"):WaitForChild("TowerRings")
end
function Layout.Floor(index)
 local folder=rings()
 local ledge=folder:WaitForChild(string.format("TowerRingLedge_%02d",index))
 local core=folder:WaitForChild(string.format("TowerRingCore_%02d",index))
 local above=folder:FindFirstChild(string.format("TowerRingCore_%02d",index+1))
 ledge.CanCollide=true ledge.CanQuery=true
 local inner=above and above.Size.Y/2 or 0
 local outer=ledge.Size.Y/2
 return Vector3.new(core.Position.X,ledge.Position.Y+ledge.Size.X/2,core.Position.Z),inner,outer
end
function Layout.Regular(slot)
 local floor=(slot-1)%17+1
 local center,inner,outer=Layout.Floor(floor)
 local angle=math.floor((slot-1)/17)*2.399963229728653+floor*0.37
 local radius=(inner+outer)/2
 return center+Vector3.new(math.cos(angle)*radius,0,math.sin(angle)*radius),floor
end
function Layout.Boss()
 local center=Layout.Floor(18)
 return center
end
return Layout
