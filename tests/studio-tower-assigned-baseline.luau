--!strict
-- Invoke from a normal server Script during a disposable Studio playtest so
-- _G resolves in the game's environment. Records native AI; does not grant heroes.
return function(floorId: number, seconds: number?)
	assert(game:GetService("RunService"):IsStudio(), "Studio validation only")
	local combat = assert(_G.CombatSimulation, "Combat must be initialized")
	local tower = require(game.ServerScriptService.Core.TowerFloorService)
	local nav = require(game.ServerScriptService.Core.HeroNavigation)
	local player = assert(game.Players:GetPlayers()[1], "One test player required")
	local unlock = workspace:GetAttribute("UnlockAllFloors")
	local result: any = {Kind="NATIVE_ASSIGNED",Floor=floorId,Trace={},Heroes={}}
	local previous: any = {}
	local ok, failure = pcall(function()
		workspace:SetAttribute("UnlockAllFloors",true)
		tower.AssignSquad(player,floorId)
		local state = tower.GetState(player)
		assert(state.SquadAssignment==floorId, "Assignment did not commit")
		local room = assert(tower.GetRoom(floorId))
		result.OwnerFloor=state.FloorId
		result.Before=nav.DebugSnapshot()
		local started = os.clock()
		while os.clock()-started<(seconds or 40) do
			local dt=task.wait(.1)
			if state.SquadAssignment~=floorId or state.SquadFloorId~=floorId then
				result.Interrupted="Assignment changed during capture"
				break
			end
			local heroes,mobs=combat.DebugEntities()
			for id,h in heroes do
				if h.Owner~=player then continue end
				if h.FloorId~=floorId then result.Interrupted="Hero left captured floor"; break end
				local p=h.Position-room.Origin
				local target=h.TargetNetId and mobs[h.TargetNetId]
				local snap=nav.DebugSnapshot(h).Actor
				local old=previous[id]
				local summary=result.Heroes[tostring(id)]
				if not summary then
					summary={Slot=h.SlotIndex,TargetChanges=0,BackwardSteps=0,MaxStall=0,States={}}
					result.Heroes[tostring(id)]=summary
				end
				summary.States[h.State]=(summary.States[h.State] or 0)+1
				local backward=false
				local stalled=0
				if old then
					if old.Target~=h.TargetNetId then summary.TargetChanges+=1 end
					local delta=h.Position-old.Position
					if target and old.Target==h.TargetNetId and h.State=="MOVE_TO_TARGET" then
						local toward=target.Position-old.Position
						backward=toward.Magnitude>1 and delta:Dot(toward.Unit)<-.5
						if backward then summary.BackwardSteps+=1 end
						if delta.Magnitude<.25 then stalled=(old.Stall or 0)+dt end
					end
				end
				summary.MaxStall=math.max(summary.MaxStall,stalled)
				table.insert(result.Trace,{T=os.clock()-started,Id=id,Slot=h.SlotIndex,S=h.State,P={p.X,p.Y,p.Z},Target=h.TargetNetId,TargetP=target and {target.Position.X-room.Origin.X,target.Position.Y-room.Origin.Y,target.Position.Z-room.Origin.Z},Back=backward,Stall=stalled,Nav=snap})
				previous[id]={Position=h.Position,Target=h.TargetNetId,Stall=stalled}
			end
		end
		result.After=nav.DebugSnapshot()
	end)
	workspace:SetAttribute("UnlockAllFloors",unlock)
	assert(ok,tostring(failure))
	return result
end
