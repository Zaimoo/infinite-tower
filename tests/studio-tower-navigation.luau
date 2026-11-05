--!strict
-- Disposable Studio playtest. Accepts isolated copies of branch modules so a
-- disconnected Rojo session cannot silently test an older solver.
return function(deps: any)
	local nav,builder,layout=deps.Navigation,deps.Builder,deps.Layout
	local actors,parts={},{}
	local room
	local results: any={Fixed={},Moving={},Errors={}}
	local function actor(position: Vector3,state: string?,floor: number?): any
		local h={Position=position,State=state or "FOLLOW_MASTER",FloorId=floor or 18,RoomGeneration=-999,NetId=-10000-#actors}
		table.insert(actors,h);return h
	end
	local function check(condition: boolean,message: string)if not condition then table.insert(results.Errors,message)end end
	local ok,failure=pcall(function()
		local rooms=workspace:FindFirstChild("TowerRooms")
		assert(not(rooms and rooms:FindFirstChild("Floor_18")),"Floor 18 must be unused")
		room=builder.Build(18,900002)
		local l=layout.Get(3)
		for _,link in l.Links do for _,reverse in {false,true}do
			local p,q=l.Platforms[if reverse then link.To else link.From],l.Platforms[if reverse then link.From else link.To]
			local start=room.Origin+Vector3.new(p.X,p.Y,p.Z)
			local goal=room.Origin+Vector3.new(q.X,q.Y,q.Z)
			local h=actor(nav.Ground(start,nil,3,8)or start,if reverse then "CHASE"else "FOLLOW_MASTER")
			for tick=1,160 do
				nav.Step(h,goal,5.04,os.clock(),.1)
				if (h.Position-goal).Magnitude<1 then break end
				if tick%10==0 then task.wait()end
			end
			local gap=(h.Position-goal).Magnitude
			table.insert(results.Fixed,{Link=link.Id,Reverse=reverse,Gap=gap,Status=nav.DebugSnapshot(h).Actor})
			check(gap<1,"Fixed route failed: "..link.Id.." reverse="..tostring(reverse).." gap="..gap)
			nav.Clear(h)
		end end
		for _,reverse in {false,true}do
			local r=deps.Movement(room,48,5,{Link="Basin>EastGallery",Reverse=reverse,Navigation=nav,Layout=layout})
			table.insert(results.Moving,r)
			for _,row in r.Records do check(row.FinalGap<8,"Moving follower failed to regroup: slot "..row.Slot)end
		end
		local ground=Instance.new("Part");ground.Name="Phase2Support";ground.Anchored=true;ground.Size=Vector3.new(20,2,20);ground.Position=Vector3.new(40000,100,40000);ground.Parent=workspace;table.insert(parts,ground)
		local lower=ground:Clone();lower.Position-=Vector3.new(0,30,0);lower.Size=Vector3.new(150,2,150);lower.Parent=workspace;table.insert(parts,lower)
		local feet=ground.Position+Vector3.new(0,1,0)
		local h=actor(feet-Vector3.new(5,0,0),nil,0)
		nav.Step(h,feet+Vector3.new(5,0,0),10,os.clock(),.1)
		check((h.Position-(feet+Vector3.new(5,0,0))).Magnitude<.1,"Unused movement budget lost at arrival")
		-- A goal moving after arrival must reactivate only the terminal waypoint.
		nav.Step(h,feet-Vector3.new(5,0,0),10,os.clock(),.1)
		check((h.Position-(feet-Vector3.new(5,0,0))).Magnitude<.1,"Arrived follower ignored moving terminal goal")
		local edge=actor(feet,nil,0)
		for i=1,30 do nav.Step(edge,feet+Vector3.new(40,0,0),2,os.clock(),.1)end
		check(math.abs(edge.Position.Y-feet.Y)<.01 and edge.Position.X<feet.X+10,"Walked off bridge to lower support")
		local boxed=actor(feet,"MOVE_TO_TARGET",0);boxed.TargetNetId=900
		for _,spec in {{Vector3.new(0,3,4),Vector3.new(10,8,1)},{Vector3.new(0,3,-4),Vector3.new(10,8,1)},{Vector3.new(4,3,0),Vector3.new(1,8,10)},{Vector3.new(-4,3,0),Vector3.new(1,8,10)}}do
			local wall=Instance.new("Part");wall.Anchored=true;wall.Position=feet+spec[1];wall.Size=spec[2];wall.Parent=workspace;table.insert(parts,wall)
		end
		local started=os.clock();local unreachable=false
		repeat
			local dt=task.wait(.1);local out=nav.Step(boxed,feet+Vector3.new(30,0,0),2,os.clock(),dt)
			if out.Status=="UNREACHABLE"then unreachable=true end
		until os.clock()-started>5.5
		check(unreachable,"Blocked combat actor did not report unreachable")
		results.Blocked=nav.DebugSnapshot(boxed)
		nav.Clear(boxed)
		task.wait(.5)
		check(nav.DebugSnapshot(boxed).Actor==nil,"Cleared actor retained navigation state")
		results.Counters=nav.DebugSnapshot()
	end)
	for _,h in actors do nav.Clear(h)end
	for _,part in parts do part:Destroy()end
	if room then room.Model:Destroy()end
	assert(ok,tostring(failure))
	return results
end
