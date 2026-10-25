-- Run in Studio Edit mode after syncing src. Returns reusable geometry and
-- grounded-navigation probes; no player profile or live encounter state is changed.
return function(firstFloor: number, lastFloor: number, keepPreviews: boolean?)
	local Core=game.ServerScriptService.Core
	local Builder=require(Core.TowerRoomBuilder)
	local Layout=require(game.ReplicatedStorage.Shared.Config.TowerLayout)
	local Combat=require(game.ReplicatedStorage.Shared.Config.FirstBiomeCombat)
	local Protocol=require(game.ReplicatedStorage.Shared.Util.TowerProtocol)
	local Navigation=require(Core.HeroNavigation)
	local results={Floors=0,SupportedSpawns=0,Routes=0,MaxInstances=0}
	local previews=workspace:FindFirstChild("TowerReworkPreviews")
	if keepPreviews and not previews then previews=Instance.new("Folder"); previews.Name="TowerReworkPreviews"; previews.Parent=workspace end
	for id=firstFloor,lastFloor do
		local room=Builder.Build(id,1)
		local layout=Layout.Get((id-1)%5+1)
		local params=RaycastParams.new()
		params.FilterType=Enum.RaycastFilterType.Include; params.FilterDescendantsInstances={room.Model}; params.RespectCanCollide=true
		assert(Protocol.InZone(room.Arrival.Position,room.Origin,room.Zones[1]),"Unsafe arrival "..id)
		assert(room.Zones[1].CanBankCargo and room.Zones[1].CanRecoverWipe)
		assert(room.Model:FindFirstChild("FloorExtractionPad"))
		for _,p in Combat.Floors[id] do
			local hit=workspace:Raycast(room.Origin+Vector3.new(p.X,p.Y+6,p.Z),Vector3.new(0,-12,0),params)
			assert(hit and math.abs(hit.Position.Y-room.Origin.Y-p.Y)<.2,"Unsupported spawn "..id.." "..p.CampId)
			assert(not Protocol.InZone(hit.Position,room.Origin,room.Zones[1]))
			results.SupportedSpawns+=1
		end
		-- Geometry is shared across biomes; walk every link both ways on all 5 variants.
		if id<=5 then
			for _,link in layout.Links do
				for _,reverse in {false,true} do
					local a=layout.Platforms[if reverse then link.To else link.From]
					local b=layout.Platforms[if reverse then link.From else link.To]
					local goal=room.Origin+Vector3.new(b.X,b.Y,b.Z)
					local hero={Position=room.Origin+Vector3.new(a.X,a.Y,a.Z),FloorId=id,RoomGeneration=1,State="FOLLOW_MASTER"}
					for step=1,500 do
						Navigation.Step(hero,goal,1.5,os.clock())
						if (hero.Position-goal).Magnitude<2 then break end
					end
					assert((hero.Position-goal).Magnitude<2,"Blocked route "..id.." "..link.From.." -> "..link.To.." reverse="..tostring(reverse).." at "..tostring(hero.Position-room.Origin))
					Navigation.Clear(hero)
					results.Routes+=1
				end
				task.wait()
			end
		end
		results.MaxInstances=math.max(results.MaxInstances,#room.Model:GetDescendants())
		results.Floors+=1
		if keepPreviews then
			local old=previews:FindFirstChild(room.Model.Name)
			if old then old:Destroy() end
			room.Model.Parent=previews
		else room.Model:Destroy() end
		task.wait()
	end
	return results
end
