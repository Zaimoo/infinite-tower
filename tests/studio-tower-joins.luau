--!strict
-- Run only in Edit mode. Builds one temporary room at a time and always removes
-- it. Refuses to replace existing rooms. Raycasts use actual collidable geometry.
return function(firstFloor: number, lastFloor: number)
	assert(not game:GetService("RunService"):IsRunning(),"Use Edit mode")
	local Core=game.ServerScriptService.Core
	local Builder=require(Core.TowerRoomBuilder)
	local Layout=require(game.ReplicatedStorage.Shared.Config.TowerLayout)
	local result={Floors=0,SupportSamples=0,ClearanceSweeps=0,Failures={}}
	for id=firstFloor,lastFloor do
		local folder=workspace:FindFirstChild("TowerRooms")
		assert(not(folder and folder:FindFirstChild(string.format("Floor_%02d",id))),"Existing room must not be replaced")
		local room
		local ok,failure=pcall(function()
			room=Builder.Build(id,900001)
			local layout=Layout.Get((id-1)%5+1)
			local connectors=table.clone(layout.Links)
			for _,link in layout.ReturnLinks do table.insert(connectors,link)end
			local params=RaycastParams.new()
			params.FilterType=Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances={room.Model}
			params.RespectCanCollide=true
			local function world(x,y,z)return room.Origin+Vector3.new(x,y,z)end
			for _,link in connectors do
				local a=world(link.AX,link.AY,link.AZ)
				local b=world(link.BX,link.BY,link.BZ)
				local lateral=Vector3.new(-link.UZ,0,link.UX)
				for _,offset in {-link.UsableWidth/2,0,link.UsableWidth/2}do
					-- Include flat platforms, both pad seams, the full slope/stair,
					-- and diagonal approaches across the pad's flared width.
					for _,reverse in {false,true}do
						local padA,padB=link.LandingA,link.LandingB
						local points={world(padA.AX,padA.AY,padA.AZ)+lateral*(offset*1.4),a+lateral*offset,b+lateral*offset,world(padB.BX,padB.BY,padB.BZ)+lateral*(offset*1.4)}
						if reverse then points={points[4],points[3],points[2],points[1]}end
						local previous
						for segment=1,#points-1 do
							local from,to=points[segment],points[segment+1]
							local count=math.max(1,math.ceil((to-from).Magnitude/.5))
							for step=0,count do
								local expected=from:Lerp(to,step/count)
								local hit=workspace:Raycast(expected+Vector3.new(0,1.1,0),Vector3.new(0,-2.3,0),params)
								result.SupportSamples+=1
								if not hit or hit.Normal.Y<.65 then
									table.insert(result.Failures,{Floor=id,Link=link.Id,Offset=offset,Reverse=reverse,Reason="SUPPORT",Position=tostring(expected-room.Origin)})
								elseif previous and (hit.Position-previous).Magnitude>.01 then
									local body=workspace:Blockcast(CFrame.new(previous+Vector3.new(0,3.5,0)),Vector3.new(2.4,2.5,2.4),hit.Position-previous,params)
									result.ClearanceSweeps+=1
									if body then table.insert(result.Failures,{Floor=id,Link=link.Id,Offset=offset,Reverse=reverse,Reason="BODY",Part=body.Instance.Name})end
								end
								previous=hit and hit.Position or nil
							end
						end
					end
				end
			end
			result.Floors+=1
		end)
		if room then room.Model:Destroy()end
		assert(ok,tostring(failure))
		task.wait()
	end
	return result
end
