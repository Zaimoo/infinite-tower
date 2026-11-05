--!strict
-- Run against an isolated, already-built room. Does not touch player profiles.
-- Real elapsed time allows asynchronous path computations to complete.
return function(room: any, speed: number?, slots: number?)
	local Navigation = require(game.ServerScriptService.Core.HeroNavigation)
	local Layout = require(game.ReplicatedStorage.Shared.Config.TowerLayout)
	local layout = Layout.Get((room.FloorId - 1) % 5 + 1)
	local results = {}
	local actors = {}
	local ok, failure = pcall(function()
		for _, link in layout.Links do
			for _, reverse in {false, true} do
				local p = layout.Platforms[if reverse then link.To else link.From]
				local q = layout.Platforms[if reverse then link.From else link.To]
				local a = room.Origin + Vector3.new(p.X, p.Y, p.Z)
				local b = room.Origin + Vector3.new(q.X, q.Y, q.Z)
				local direction = Vector3.new(b.X-a.X, 0, b.Z-a.Z).Unit
				local duration = (b-a).Magnitude / (speed or 48)
				local records = {}
				for slot = 1, slots or 5 do
					local angle = (slot-1) / 5 * math.pi * 2
					local offset = Vector3.new(math.cos(angle)*6, 0, math.sin(angle)*6)
					local actor = {Position=Navigation.PlaceNear(a+Vector3.new(0,3,0),offset), FloorId=room.FloorId, RoomGeneration=-999, State="FOLLOW_MASTER"}
					table.insert(actors,actor)
					table.insert(records,{Actor=actor,Offset=offset,MaxLag=0,Backward=0,StallSeconds=0})
				end
				local started, previous = os.clock(), os.clock()
				repeat
					task.wait(.1)
					local now = os.clock()
					local dt = now-previous; previous=now
					local master = a:Lerp(b,math.clamp((now-started)/duration,0,1))
					master = Navigation.Ground(master,nil,4,16) or master
					for _, record in records do
						local actor = record.Actor
						local goal = Navigation.PlaceNear(master+Vector3.new(0,3,0),record.Offset)
						local lag = (goal-actor.Position).Magnitude
						record.MaxLag=math.max(record.MaxLag,lag)
						local old = actor.Position
						Navigation.Step(actor,goal,(speed or 48)*1.05*(1+math.clamp((lag-14)/50,0,.65))*dt,now)
						local delta = actor.Position-old
						if delta:Dot(direction)<-.5 then record.Backward+=1 end
						if delta.Magnitude<.2 and lag>14 then record.StallSeconds+=dt end
					end
				until os.clock()-started>duration+3
				for slot, record in records do
					table.insert(results,{Link=link.From..">"..link.To,Reverse=reverse,Slot=slot,MaxLag=record.MaxLag,Backward=record.Backward,StallSeconds=record.StallSeconds,FinalGap=(record.Actor.Position-b).Magnitude})
					Navigation.Clear(record.Actor)
				end
				table.clear(actors)
			end
		end
	end)
	for _, actor in actors do Navigation.Clear(actor) end
	assert(ok,tostring(failure))
	return results
end
