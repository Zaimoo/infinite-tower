--!strict
-- Shared v2 codec. No legacy stride guessing or position clamping.
local P = { Version = 2, HeaderBytes = 46, RecordBytes = 24, BatchSize = 32 }
local U32 = 4294967296
function P.Finite(n: any): boolean
	return type(n) == "number" and n == n and math.abs(n) < math.huge
end
function P.Integer(n: any, lo: number, hi: number): boolean
	return P.Finite(n) and n % 1 == 0 and n >= lo and n <= hi
end
function P.Newer(a: number, b: number): boolean
	local d = (a - b) % U32
	return d > 0 and d < U32 / 2
end
function P.Same(a: any, b: any): boolean
	return a ~= nil and b ~= nil and a.ServerSessionId == b.ServerSessionId
		and a.FloorId == b.FloorId and a.RoomGeneration == b.RoomGeneration and a.ViewEpoch == b.ViewEpoch
end
function P.InBounds(pos: any, origin: any, bounds: any): boolean
	local v = pos - origin
	return P.Finite(v.X) and P.Finite(v.Y) and P.Finite(v.Z)
		and v.X >= bounds.Min.X and v.Y >= bounds.Min.Y and v.Z >= bounds.Min.Z
		and v.X <= bounds.Max.X and v.Y <= bounds.Max.Y and v.Z <= bounds.Max.Z
end
function P.InZone(pos: any, origin: any, zone: any): boolean
	local v = pos - origin
	if not P.Finite(v.X) or not P.Finite(v.Y) or not P.Finite(v.Z) or v.Y < zone.MinY or v.Y > zone.MaxY then return false end
	local inside = false
	local points = zone.LocalPolygonXZ
	for i, a in ipairs(points) do
		local b = points[i % #points + 1]
		local dx, dz = b.X - a.X, b.Y - a.Y
		local cross = (v.X - a.X) * dz - (v.Z - a.Y) * dx
		if math.abs(cross) < 1e-5 and v.X >= math.min(a.X,b.X) and v.X <= math.max(a.X,b.X)
			and v.Z >= math.min(a.Y,b.Y) and v.Z <= math.max(a.Y,b.Y) then return true end
		if (a.Y > v.Z) ~= (b.Y > v.Z) and v.X < (b.X-a.X)*(v.Z-a.Y)/(b.Y-a.Y)+a.X then inside = not inside end
	end
	return inside
end
local function sessionBytes(id: string): string
	assert(type(id) == "string" and #id == 32 and not id:find("[^%da-f]"), "Invalid session ID")
	return (id:gsub("..", function(s) return string.char(tonumber(s,16) :: number) end))
end
function P.Encode(context: any, entities: {any}, sequence: number, serverTime: number): {buffer}
	local raw = sessionBytes(context.ServerSessionId)
	assert(P.Finite(serverTime))
	local packets = {}
	local batches = math.max(1, math.ceil(#entities/P.BatchSize))
	assert(batches <= 65535, "Tower snapshot overload")
	for batch = 1, batches do
		local count = math.min(P.BatchSize, #entities-(batch-1)*P.BatchSize)
		local buf = buffer.create(P.HeaderBytes + count*P.RecordBytes)
		buffer.writeu8(buf,0,2); buffer.writeu8(buf,1,context.FloorId); buffer.writeu16(buf,2,46)
		buffer.writestring(buf,4,raw); buffer.writeu32(buf,20,context.RoomGeneration)
		buffer.writeu32(buf,24,context.ViewEpoch); buffer.writeu32(buf,28,sequence)
		buffer.writef64(buf,32,serverTime); buffer.writeu16(buf,40,batch)
		buffer.writeu16(buf,42,batches); buffer.writeu16(buf,44,count)
		for j=1,count do
			local e=entities[(batch-1)*P.BatchSize+j]
			local v=e.Position-context.Origin
			for _,n in {v.X,v.Y,v.Z} do assert(P.Finite(n) and math.abs(n)<=3276.7,"Out-of-range tower entity") end
			assert(P.Integer(e.NetId,1,U32-1) and P.Integer(e.EntityGeneration,1,U32-1))
			local o=46+(j-1)*24
			buffer.writeu32(buf,o,e.NetId);buffer.writeu32(buf,o+4,e.EntityGeneration)
			buffer.writei16(buf,o+8,math.round(v.X*10));buffer.writei16(buf,o+10,math.round(v.Y*10));buffer.writei16(buf,o+12,math.round(v.Z*10))
			buffer.writeu8(buf,o+14,math.clamp(math.round(((e.Yaw or 0)+math.pi)/(2*math.pi)*255),0,255))
			buffer.writeu8(buf,o+15,e.StateEnum or 1);buffer.writeu16(buf,o+16,math.clamp(math.round(e.CurrentHP/math.max(1,e.MaxHP)*1000),0,1000))
			buffer.writeu8(buf,o+18,math.clamp(math.round(e.Stamina or 100),0,100));buffer.writeu8(buf,o+19,e.Flags or 0)
			buffer.writeu32(buf,o+20,e.ActionSequence or 0)
		end
		table.insert(packets,buf)
	end
	return packets
end
function P.Decode(buf: any, expected: any): any?
	if typeof(buf) ~= "buffer" or buffer.len(buf)<46 then return nil end
	if buffer.readu8(buf,0)~=2 or buffer.readu16(buf,2)~=46 then return nil end
	local c={FloorId=buffer.readu8(buf,1),RoomGeneration=buffer.readu32(buf,20),ViewEpoch=buffer.readu32(buf,24)} :: any
	c.ServerSessionId=(buffer.readstring(buf,4,16):gsub(".",function(s) return string.format("%02x",s:byte()) end))
	if not P.Same(c,expected) then return nil end
	local count,batch,batches=buffer.readu16(buf,44),buffer.readu16(buf,40),buffer.readu16(buf,42)
	local time=buffer.readf64(buf,32)
	if count>64 or buffer.len(buf)~=46+count*24 or batch<1 or batch>batches or not P.Finite(time) then return nil end
	local records={}
	local seen={}
	for i=1,count do
		local o=46+(i-1)*24
		local id,gen=buffer.readu32(buf,o),buffer.readu32(buf,o+4)
		local flags=buffer.readu8(buf,o+19)
		if id==0 or gen==0 or seen[id] or flags>15 or buffer.readu16(buf,o+16)>1000 or buffer.readu8(buf,o+18)>100 then return nil end
		seen[id]=true
		local pos=expected.Origin+Vector3.new(buffer.readi16(buf,o+8)/10,buffer.readi16(buf,o+10)/10,buffer.readi16(buf,o+12)/10)
		if not P.InBounds(pos,expected.Origin,expected.Bounds) then return nil end
		table.insert(records,{NetId=id,EntityGeneration=gen,Position=pos,Yaw=buffer.readu8(buf,o+14)/255*2*math.pi-math.pi,
			StateEnum=buffer.readu8(buf,o+15),HpPermille=buffer.readu16(buf,o+16),Stamina=buffer.readu8(buf,o+18),Flags=flags,ActionSequence=buffer.readu32(buf,o+20)})
	end
	return {Sequence=buffer.readu32(buf,28),ServerTime=time,BatchIndex=batch,BatchCount=batches,Entities=records}
end
return table.freeze(P)
