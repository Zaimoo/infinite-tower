--!strict
-- Run against an isolated, already-built room. Does not touch player profiles.
-- Real elapsed time allows asynchronous path computations to complete.
return function(room: any, speed: number?, slots: number?, options: any?)
	options = options or {}
	local Navigation = require(game.ServerScriptService.Core.HeroNavigation)
	local Layout = require(game.ReplicatedStorage.Shared.Config.TowerLayout)
	local layout = Layout.Get((room.FloorId - 1) % 5 + 1)
	local results = {}
	local actors = {}
	local metricsBefore = Navigation.DebugSnapshot and Navigation.DebugSnapshot()
	local ok, failure = pcall(function()
		for _, link in layout.Links do
			if options.Link and link.From..">"..link.To ~= options.Link then continue end
			for _, reverse in {false, true} do
				if options.Reverse ~= nil and reverse ~= options.Reverse then continue end
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
					table.insert(records,{Actor=actor,Offset=offset,MaxLag=0,Backward=0,StallSeconds=0,MaxStall=0,ConsecutiveStall=0,Trace={},StepMs={}})
				end
				local started, previous = os.clock(), os.clock()
				repeat
					task.wait(.1)
					local now = os.clock()
					local dt = now-previous; previous=now
					local master = if options.Fixed then b else a:Lerp(b,math.clamp((now-started)/duration,0,1))
					master = Navigation.Ground(master,nil,4,16) or master
					for _, record in records do
						local actor = record.Actor
						local goal = Navigation.PlaceNear(master+Vector3.new(0,3,0),record.Offset)
						local lag = (goal-actor.Position).Magnitude
						record.MaxLag=math.max(record.MaxLag,lag)
						local old = actor.Position
						local stepStart = os.clock()
						Navigation.Step(actor,goal,(speed or 48)*1.05*(1+math.clamp((lag-14)/50,0,.65))*dt,now)
						table.insert(record.StepMs,(os.clock()-stepStart)*1000)
						local delta = actor.Position-old
						if delta:Dot(direction)<-.5 then record.Backward+=1 end
						if delta.Magnitude<.2 and lag>14 then
							record.StallSeconds+=dt; record.ConsecutiveStall+=dt
						else record.ConsecutiveStall=0 end
						record.MaxStall=math.max(record.MaxStall,record.ConsecutiveStall)
						if options.Trace and #record.StepMs%3==0 and #record.Trace<128 then
							table.insert(record.Trace,{Time=now-started,Position={X=actor.Position.X-room.Origin.X,Y=actor.Position.Y-room.Origin.Y,Z=actor.Position.Z-room.Origin.Z},Lag=lag,Along=delta:Dot(direction),Navigation=Navigation.DebugSnapshot and Navigation.DebugSnapshot(actor).Actor})
						end
					end
				until os.clock()-started>duration+(options.SettleSeconds or 3)
				for slot, record in records do
					table.sort(record.StepMs)
					table.insert(results,{Link=link.From..">"..link.To,Reverse=reverse,Slot=slot,MaxLag=record.MaxLag,Backward=record.Backward,StallSeconds=record.StallSeconds,MaxStall=record.MaxStall,StepP95Ms=record.StepMs[math.max(1,math.ceil(#record.StepMs*.95))],FinalGap=(record.Actor.Position-b).Magnitude,Trace=if options.Trace then record.Trace else nil})
					Navigation.Clear(record.Actor)
				end
				table.clear(actors)
			end
		end
	end)
	for _, actor in actors do Navigation.Clear(actor) end
	assert(ok,tostring(failure))
	return {Records=results,MetricsBefore=metricsBefore,MetricsAfter=Navigation.DebugSnapshot and Navigation.DebugSnapshot(),Speed=speed or 48,Fixed=options.Fixed==true}
end
