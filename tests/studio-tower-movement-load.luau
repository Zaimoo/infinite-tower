--!strict
-- Movement-load baseline, not a six-floor combat/reward certification.
return function()
	assert(game:GetService("RunService"):IsStudio())
	local nav=require(game.ServerScriptService.Core.HeroNavigation)
	local tower=require(game.ServerScriptService.Core.TowerFloorService)
	local layouts=require(game.ReplicatedStorage.Shared.Config.TowerLayout)
	local rooms={}
	for floor=43,48 do table.insert(rooms,tower.EnsureRoom(floor));task.wait()end
	local results={}
	local actors={}
	local ok,failure=pcall(function()
		for _,load in {{Floors=1,Squads=1},{Floors=1,Squads=2},{Floors=6,Squads=1}}do
			table.clear(actors)
			for floorIndex=1,load.Floors do
				local room=rooms[floorIndex]
				local layout=layouts.Get((room.FloorId-1)%5+1)
				local link=layout.Links[2]
				local a=room.Origin+Vector3.new(link.AX,link.AY,link.AZ)
				local b=room.Origin+Vector3.new(link.BX,link.BY,link.BZ)
				for squad=1,load.Squads do for slot=1,5 do
					local start=if squad==1 then a else b
					local h={Position=start+Vector3.new((slot-3)*2,0,0),FloorId=room.FloorId,RoomGeneration=-999,State="FOLLOW_MASTER",NetId=-floorIndex*100-squad*10-slot}
					h.Position=nav.Ground(h.Position,nil,4,8)or h.Position
					table.insert(actors,{Hero=h,A=a,B=b,Reverse=squad==2})
				end end
			end
			local record: any={Floors=load.Floors,SquadsPerFloor=load.Squads,Actors=#actors,Before=nav.DebugSnapshot(),TickMs={},TickSeconds={},Computing={}}
			local started=os.clock()
			while os.clock()-started<5 do
				local dt=task.wait(.1)
				local now=os.clock()
				local t=(math.sin((now-started)*.7)+1)*.5
				local tickStart=os.clock()
				debug.profilebegin("Phase0.Navigation")
				for _,entry in actors do
					local fraction=if entry.Reverse then 1-t else t
					local goal=entry.A:Lerp(entry.B,fraction)
					nav.Step(entry.Hero,goal,50.4*dt,now)
				end
				debug.profileend()
				table.insert(record.TickMs,(os.clock()-tickStart)*1000)
				table.insert(record.TickSeconds,dt)
				table.insert(record.Computing,nav.DebugSnapshot().Computing)
			end
			record.After=nav.DebugSnapshot()
			for _,entry in actors do nav.Clear(entry.Hero)end
			local drain=os.clock()
			while nav.DebugSnapshot().Computing>0 and os.clock()-drain<2 do task.wait(.05)end
			table.insert(results,record)
		end
	end)
	for _,entry in actors do nav.Clear(entry.Hero)end
	assert(ok,tostring(failure))
	return results
end
