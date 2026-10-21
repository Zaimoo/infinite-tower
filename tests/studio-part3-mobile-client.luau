-- Disposable client measurement: 10 seconds, real rendered rigs and live attacks.
local RS=game.ReplicatedStorage;local p=game.Players.LocalPlayer
repeat task.wait(.1) until _G.TowerView and _G.TowerView.FloorId==5 and RS:GetAttribute("Part3MeasureReady")
local Anim=require(RS.Assets.EnemyAnimationController);local original=Anim.Step
local samples,animation={},{};local calls=0
local stats=game:GetService("Stats");local memoryBefore=stats:GetTotalMemoryUsageMb()
Anim.Step=function(...)
	local start=os.clock();original(...);table.insert(animation,(os.clock()-start)*1000);calls+=1
end
local connection=game.RunService.RenderStepped:Connect(function(dt) table.insert(samples,dt*1000) end)
task.wait(10);connection:Disconnect();Anim.Step=original
table.sort(samples);table.sort(animation)
local inventory={};local parts,joints=0,0
for _,node in _G.ClientCombatState.VisualNodes do if node.EnemyRig then
	local n=0;for _ in node.EnemyRig.Joints do n+=1 end
	parts+=#node.EnemyRig.Parts;joints+=n;table.insert(inventory,{Enemy=node.EnemyRig.EnemyId,Parts=#node.EnemyRig.Parts,Joints=n})
end end
local function percentile(values,pct) return values[math.max(1,math.ceil(#values*pct))] end
p.PlayerGui:SetAttribute("Part3MobileMeasurement",game.HttpService:JSONEncode({Viewport=tostring(workspace.CurrentCamera.ViewportSize),
	Orientation=tostring(game.StarterGui.ScreenOrientation),Frames=#samples,P50ms=percentile(samples,.5),P95ms=percentile(samples,.95),
	AnimationCalls=calls,PerRigAnimationP95ms=percentile(animation,.95),MemoryBeforeMB=memoryBefore,MemoryAfterMB=stats:GetTotalMemoryUsageMb(),
	Inventory=inventory,ArtParts=parts,Motor6Ds=joints,ActionMetrics=_G.ClientCombatState.ActionMetrics,
	PhysicalDevice=false,WindowSeconds=10}))
