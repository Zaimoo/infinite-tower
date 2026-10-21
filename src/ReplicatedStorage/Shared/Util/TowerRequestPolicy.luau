--!strict
local P=require(script.Parent.TowerProtocol)
local Policy={}
local actions={VISIT=true,HUB=true,ASSIGN=true,RECALL=true,PRESENCE_SUBSCRIBE=true,PRESENCE_UNSUBSCRIBE=true,RESYNC=true,CANCEL=true}
local fields={ContractVersion=true,RequestId=true,Action=true,FloorId=true,CharacterGeneration=true,ExpectedLocationRevision=true,ExpectedSquadRevision=true,
	CancelRequestId=true,ServerSessionId=true,RoomGeneration=true,ViewEpoch=true}
function Policy.Validate(r: any): (boolean,string?)
	if type(r)~="table" then return false,"BAD_REQUEST" end
	for k in pairs(r) do if not fields[k] then return false,"BAD_REQUEST" end end
	if r.ContractVersion~=1 then return false,"VERSION_MISMATCH" end
	for _,key in {"CharacterGeneration","ExpectedLocationRevision","ExpectedSquadRevision","RoomGeneration","ViewEpoch"} do
		if r[key]~=nil and not P.Integer(r[key],0,4294967295) then return false,"BAD_REQUEST" end
	end
	if r.ServerSessionId~=nil and (type(r.ServerSessionId)~="string" or #r.ServerSessionId~=32 or r.ServerSessionId:find("[^%da-f]")) then return false,"BAD_REQUEST" end
	if r.CancelRequestId~=nil and (type(r.CancelRequestId)~="string" or #r.CancelRequestId<1 or #r.CancelRequestId>64 or r.CancelRequestId:find("[^ -~]")) then return false,"BAD_REQUEST" end
	if type(r.RequestId)~="string" or #r.RequestId<1 or #r.RequestId>64 or r.RequestId:find("[^ -~]") or not actions[r.Action] then return false,"BAD_REQUEST" end
	if (r.Action=="VISIT" or r.Action=="ASSIGN") and not P.Integer(r.FloorId,1,50) then return false,"INVALID_FLOOR" end
	if r.Action~="VISIT" and r.Action~="ASSIGN" and r.Action~="RESYNC" and r.FloorId~=nil then return false,"BAD_REQUEST" end
	if r.Action=="VISIT" or r.Action=="HUB" or r.Action=="ASSIGN" or r.Action=="RECALL" then
		for _,k in {"CharacterGeneration","ExpectedLocationRevision","ExpectedSquadRevision"} do if not P.Integer(r[k],0,4294967295) then return false,"BAD_REQUEST" end end
	end
	if r.Action=="CANCEL" and (type(r.CancelRequestId)~="string" or #r.CancelRequestId>64) then return false,"BAD_REQUEST" end
	if r.Action=="RESYNC" and (type(r.ServerSessionId)~="string" or #r.ServerSessionId~=32 or not P.Integer(r.FloorId,0,50)
		or not P.Integer(r.RoomGeneration,1,4294967295) or not P.Integer(r.ViewEpoch,1,4294967295)) then return false,"BAD_REQUEST" end
	return true
end
function Policy.Fingerprint(r: any): string
	local keys={};for k in pairs(r) do table.insert(keys,k) end;table.sort(keys)
	local out={};for _,k in keys do table.insert(out,k.."="..tostring(r[k])) end
	return table.concat(out,"|")
end
return table.freeze(Policy)
