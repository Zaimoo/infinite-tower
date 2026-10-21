local P=require(nodes["ReplicatedStorage.Shared.Util.TowerProtocol"])
local Requests=require(nodes["ReplicatedStorage.Shared.Util.TowerRequestPolicy"])
local passed,failed=0,0
local function test(name,fn)
	local ok,err=pcall(fn)
	if ok then passed+=1;print("PASS "..name) else failed+=1;print("FAIL "..name..": "..tostring(err)) end
end
local c={ServerSessionId="0123456789abcdef0123456789abcdef",FloorId=50,RoomGeneration=7,ViewEpoch=12,
	Origin=Vector3.new(28200,1000,19200),Bounds={Min=Vector3.new(-120,-4,-120),Max=Vector3.new(120,78,120)}}
local e={NetId=70001,EntityGeneration=9,Position=c.Origin+Vector3.new(15.2,3.1,-12.4),CurrentHP=63,MaxHP=100,Stamina=72,Flags=7,StateEnum=3,ActionSequence=93,Yaw=1.1}
test("Floor 50 world coordinates roundtrip as local v2 coordinates with complete identity",function()
	local packets=P.Encode(c,{e},123,456.789);assert(#packets==1 and buffer.len(packets[1])==70)
	local packet=assert(P.Decode(packets[1],c));local record=packet.Entities[1]
	assert(record.NetId==70001 and record.EntityGeneration==9 and record.ActionSequence==93)
	assert(math.abs(record.Position.X-e.Position.X)<.051 and math.abs(record.Position.Y-e.Position.Y)<.051 and math.abs(record.Position.Z-e.Position.Z)<.051)
	assert(record.HpPermille==630 and record.Stamina==72 and record.Flags==7 and packet.Sequence==123 and packet.ServerTime==456.789)
end)
test("500 relevant entities schedule all IDs in packets under 1 KB",function()
	local entities={};for i=1,500 do local v=table.clone(e);v.NetId=i;table.insert(entities,v) end
	local packets=P.Encode(c,entities,99,100);assert(#packets==16)
	local ids={};for i,buf in packets do assert(buffer.len(buf)<=814);local packet=assert(P.Decode(buf,c));assert(packet.BatchIndex==i and packet.BatchCount==16)
		for _,r in packet.Entities do assert(not ids[r.NetId]);ids[r.NetId]=true end
	end
	for i=1,500 do assert(ids[i]) end
end)
test("Empty heartbeat and strict malformed packet lengths",function()
	local packet=P.Encode(c,{},0,1)[1];assert(buffer.len(packet)==46 and #P.Decode(packet,c).Entities==0)
	for n=0,45 do assert(P.Decode(buffer.create(n),c)==nil) end
	local short=buffer.create(69);buffer.copy(short,0,P.Encode(c,{e},1,1)[1],0,69);assert(P.Decode(short,c)==nil)
	buffer.writeu16(packet,44,65);assert(P.Decode(packet,c)==nil)
end)
test("Old session floor generation and view epoch cannot enter a committed view",function()
	local buf=P.Encode(c,{e},1,1)[1]
	for _,key in {"ServerSessionId","FloorId","RoomGeneration","ViewEpoch"} do
		local wrong=table.clone(c);wrong[key]=key=="ServerSessionId" and string.rep("0",32) or c[key]+1
		assert(P.Decode(buf,wrong)==nil)
	end
end)
test("Encoder rejects overflow NaN and invalid identities without clamping",function()
	for _,value in {3276.8,math.huge,0/0} do local bad=table.clone(e);bad.Position=c.Origin+Vector3.new(value,0,0);assert(not pcall(P.Encode,c,{bad},1,1)) end
	local bad=table.clone(e);bad.NetId=0;assert(not pcall(P.Encode,c,{bad},1,1))
end)
test("Decoder rejects bad HP flags batch ranges versions and nonfinite clocks",function()
	for _,change in {
		function(b) buffer.writeu8(b,0,1) end,function(b) buffer.writeu16(b,2,45) end,
		function(b) buffer.writeu16(b,40,0) end,function(b) buffer.writeu16(b,42,0) end,
		function(b) buffer.writef64(b,32,math.huge) end,function(b) buffer.writeu16(b,62,1001) end,
		function(b) buffer.writeu8(b,65,16) end,function(b) buffer.writeu32(b,50,0) end,
	} do local b=P.Encode(c,{e},1,1)[1];change(b);assert(P.Decode(b,c)==nil) end
end)
test("Sequence ordering tolerates wrap and rejects duplicate stale half-range packets",function()
	assert(P.Newer(0,4294967295));assert(P.Newer(9,8));assert(not P.Newer(8,8));assert(not P.Newer(8,9));assert(not P.Newer(2147483648,0))
end)
test("Safe polygons include edges and enforce height with no off-map privilege",function()
	local zone={MinY=-1,MaxY=12,LocalPolygonXZ={Vector2.new(-40,65),Vector2.new(40,65),Vector2.new(40,118),Vector2.new(-40,118)}}
	assert(P.InZone(c.Origin+Vector3.new(0,3,90),c.Origin,zone));assert(P.InZone(c.Origin+Vector3.new(40,0,65),c.Origin,zone))
	assert(not P.InZone(c.Origin+Vector3.new(0,15,90),c.Origin,zone));assert(not P.InZone(Vector3.new(100000,0,100000),c.Origin,zone))
end)
local request={ContractVersion=1,RequestId="request-1",Action="VISIT",FloorId=50,CharacterGeneration=3,ExpectedLocationRevision=4,ExpectedSquadRevision=5}
test("All destination IDs are accepted without a progression or currency claim",function()
	for id=1,50 do local r=table.clone(request);r.FloorId=id;assert(Requests.Validate(r)) end
	for _,id in {0,51,-1,1.5,math.huge,0/0,"50"} do local r=table.clone(request);r.FloorId=id;assert(not Requests.Validate(r)) end
end)
test("Request schema rejects client authority unknown actions and malformed revisions",function()
	for _,k in {"Position","Gold","Damage","HeroUUIDs","Reward"} do local r=table.clone(request);r[k]=100;assert(not Requests.Validate(r)) end
	for _,action in {"UNLOCK","DEFEAT_BOSS",""} do local r=table.clone(request);r.Action=action;assert(not Requests.Validate(r)) end
	for _,k in {"CharacterGeneration","ExpectedLocationRevision","ExpectedSquadRevision"} do local r=table.clone(request);r[k]=-1;assert(not Requests.Validate(r)) end
	local r=table.clone(request);r.RequestId=string.rep("a",65);assert(not Requests.Validate(r));r.RequestId="\n";assert(not Requests.Validate(r))
end)
test("Deduplication fingerprints are stable but distinguish changed payloads",function()
	local copy={};for k,v in request do copy[k]=v end
	assert(Requests.Fingerprint(request)==Requests.Fingerprint(copy));copy.FloorId=1;assert(Requests.Fingerprint(request)~=Requests.Fingerprint(copy))
end)
test("Resync must identify the full committed context and cancel has bounded identity",function()
	local r={ContractVersion=1,RequestId="resync",Action="RESYNC",ServerSessionId=c.ServerSessionId,FloorId=50,RoomGeneration=7,ViewEpoch=12}
	assert(Requests.Validate(r));r.RoomGeneration=nil;assert(not Requests.Validate(r))
	assert(Requests.Validate({ContractVersion=1,RequestId="cancel",Action="CANCEL",CancelRequestId="old"}))
end)
print(string.format("Tower transport tests: %d passed, %d failed",passed,failed));assert(failed==0)
