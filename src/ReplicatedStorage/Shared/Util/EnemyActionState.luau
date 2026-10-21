--!strict
-- Client reconciliation is independent from the rig/player. Tombstones last for the view.
local S={}
function S.New(): any return {Actors={},Tombstones={}} end
function S.Key(id: any): string return tostring(id.NetId)..":"..tostring(id.EntityGeneration) end
function S.Receive(state: any,message: any,metadata: any,now: number): boolean
	local id=message.Actor;if not id then return false end
	local key=S.Key(id);local old=state.Actors[key]
	if message.Kind=="DEATH" then
		state.Tombstones[key]=true;state.Actors[key]=nil;return true
	end
	if state.Tombstones[key] then return false end
	local meta=metadata[id.NetId]
	if not meta or meta.EntityGeneration~=id.EntityGeneration or meta.FloorId~=id.FloorId or meta.RoomGeneration~=id.RoomGeneration then return false end
	local sequence=message.ActionSequence
	if type(sequence)~="number" or sequence<1 or sequence%1~=0 then return false end
	if old and (sequence<old.Sequence or (sequence==old.Sequence and (old.Terminal or message.Kind=="START"))) then return false end
	if message.Kind=="START" then
		local ending=message.StartServerTime+message.ImpactOffsetSeconds+message.RecoverySeconds
		state.Actors[key]={Sequence=sequence,Terminal=now>=ending,Action=message,ReceivedAt=now}
		return now<ending
	elseif message.Kind=="CANCEL" or message.Kind=="COMPLETE" then
		state.Actors[key]={Sequence=sequence,Terminal=true};return true
	end
	return false
end
function S.Expected(state: any,id: any,sequence: number): boolean
	local old=state.Actors[S.Key(id)]
	return sequence==0 or (old~=nil and old.Sequence>=sequence) or state.Tombstones[S.Key(id)]==true
end
return table.freeze(S)
