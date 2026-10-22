local B={}
function B.Build()
local world=workspace:WaitForChild("BaseOverhaulGeometry")
local tower=world:WaitForChild("CentralCrimsonTower")
local old=world:FindFirstChild("IslandTowerBridges") if old then old:Destroy() end
local f=Instance.new("Folder") f.Name="IslandTowerBridges" f.Parent=world
local function part(n,size,cf,rail)
 local p=Instance.new("Part") p.Name=n p.Size=size p.CFrame=cf p.Anchored=true
 p.Material=rail and Enum.Material.Granite or Enum.Material.Slate
 p.Color=rail and Color3.fromRGB(112,26,37) or Color3.fromRGB(55,45,52)
 p.TopSurface=Enum.SurfaceType.Smooth p.BottomSurface=Enum.SurfaceType.Smooth
 if rail then
  local mod = Instance.new("PathfindingModifier")
  mod.Label = "BridgeRail"
  mod.Parent = p
 end
 p.Parent=f
end
local function span(n,a,b,w,rails,railInset,railEndInset)
 local cf=CFrame.lookAt((a+b)/2,b) local len=(b-a).Magnitude+1
 part(n,Vector3.new(w,2,len),cf*CFrame.new(0,-1,0),false)
 if rails then
  local rA = if railInset then a + (b - a).Unit * railInset else a
  local rB = if railEndInset then b - (b - a).Unit * railEndInset else b
  local rLen = (rB - rA).Magnitude + 1
  local rCf = CFrame.lookAt((rA + rB)/2, rB)
  for _,side in {-1,1} do part(n.."_Rail",Vector3.new(1,4,rLen),rCf*CFrame.new(side*(w/2-0.5),2,0),true) end
 end
end
local radius=375 local y=16 local angles={}
for i=1,6 do
 local plot = workspace.WaitingRoomPlots:FindFirstChild("Plot_"..i)
 if plot then
  local island=plot:WaitForChild("FloatingFortressIsland", 10)
  if island then
   local walls=island:FindFirstChild("FortressWalls")
   local gate=walls and walls:FindFirstChild("GateLintel")
   if gate and gate:IsA("BasePart") then
    local a=math.atan2(gate.Position.Z,gate.Position.X) table.insert(angles,a)
    local start=Vector3.new(gate.Position.X,12,gate.Position.Z)-gate.CFrame.LookVector*4
    span("IslandBridge_"..i,start,Vector3.new(math.cos(a)*(radius-1),y,math.sin(a)*(radius-1)),18,true,4,18)
    local edgeBarriers=walls:FindFirstChild("InvisibleEdgeBarriers")
    local barrier=edgeBarriers and edgeBarriers:FindFirstChild("Barrier_Front")
    if barrier then barrier.CanCollide=false barrier.CanTouch=false end
   end
  end
 end
end
local function near(a,b,t) return math.abs(math.atan2(math.sin(a-b),math.cos(a-b)))<t end
for i=1,120 do
 local a=(i-1)*math.pi*2/120 local b=i*math.pi*2/120 local mid=(a+b)/2
 local p=Vector3.new(math.cos(a)*radius,y,math.sin(a)*radius)
 local q=Vector3.new(math.cos(b)*radius,y,math.sin(b)*radius)
 span("TowerWalkway_"..i,p,q,22,false)
 local cf=CFrame.lookAt((p+q)/2,q) local open=false
 for _,angle in angles do if near(mid,angle,0.065) then open=true end end
 -- Local negative X is the outer edge for this winding.
 if not open then part("OuterRail",Vector3.new(1,4,(q-p).Magnitude+0.5),cf*CFrame.new(-10.5,2,0),true) end
 if not near(mid,-math.pi/2,0.09) then part("InnerRail",Vector3.new(1,4,(q-p).Magnitude+0.5),cf*CFrame.new(10.5,2,0),true) end
 if i%30==0 then task.wait() end
end
local portal=tower.TowerBaseEntrance.EntrancePortalTrigger
local front=portal.Position+portal.CFrame.LookVector*6
span("TowerEntranceApproach",Vector3.new(0,y,-radius-1),Vector3.new(front.X,y,front.Z),28,true)
portal.CanCollide=false
f:SetAttribute("ConnectedIslandCount",#angles)
return f
end
return B
