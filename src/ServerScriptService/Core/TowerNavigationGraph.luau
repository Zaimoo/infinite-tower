--!strict
-- Pure topology/route math. Points are local feet coordinates, not player roots.
local Graph = {}
export type Point = {X: number, Y: number, Z: number}
local function point(x: number,y: number,z: number): Point return {X=x,Y=y,Z=z} end
function Graph.Distance(a: Point,b: Point): number
	return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2)
end
function Graph.new(layout: any): any
	local g: any={Platforms=table.clone(layout.Platforms),Links=table.clone(layout.Links),Edges={}}
	for _,link in layout.ReturnLinks or {} do
		table.insert(g.Links,link)
		local pad=link.LandingA
		g.Platforms[link.From]={X=pad.AX,Y=pad.AY,Z=pad.AZ,Width=pad.Width,Depth=4}
	end
	for id in g.Platforms do g.Edges[id]={} end
	for _,link in g.Links do
		local a,b=point(link.AX,link.AY,link.AZ),point(link.BX,link.BY,link.BZ)
		local p,q=g.Platforms[link.From],g.Platforms[link.To]
		local cost=Graph.Distance(p,a)+Graph.Distance(a,b)+Graph.Distance(b,q)
		table.insert(g.Edges[link.From],{To=link.To,A=a,B=b,Cost=cost,Link=link,FromA=true})
		table.insert(g.Edges[link.To],{To=link.From,A=b,B=a,Cost=cost,Link=link,FromA=false})
	end
	return g
end

local PORCH_DISTANCE = 18

local function linkAxes(link: any): (number, number, number)
	local dx, dz = link.BX - link.AX, link.BZ - link.AZ
	local len = math.sqrt(dx * dx + dz * dz)
	return dx / len, dz / len, len
end

local function porchA(g: any, link: any): Point
	local ux, uz = linkAxes(link)
	local px, pz = link.AX - ux * PORCH_DISTANCE, link.AZ - uz * PORCH_DISTANCE
	local plat = g.Platforms[link.From]
	if plat and plat.Width > 8 and plat.Depth > 8 then
		px = math.clamp(px, plat.X - plat.Width / 2 + 4, plat.X + plat.Width / 2 - 4)
		pz = math.clamp(pz, plat.Z - plat.Depth / 2 + 4, plat.Z + plat.Depth / 2 - 4)
	end
	return point(px, link.AY, pz)
end

local function needsPorchA(link: any, pt: Point): boolean
	local ux, uz = linkAxes(link)
	local rx, rz = pt.X - link.AX, pt.Z - link.AZ
	local along = rx * ux + rz * uz
	local lat = math.abs(rx * uz - rz * ux)
	local halfUsable = (link.UsableWidth or (link.Width - 6.8)) * 0.5
	return along > 1 or (lat > halfUsable and along > -lat * 0.4)
end

local function segmentHitsLink(link: any, from: Point, goal: Point): boolean
	if math.abs(from.Y - link.AY) > 2.5 or math.abs(goal.Y - link.AY) > 2.5 then
		return false
	end
	local ux, uz, len = linkAxes(link)
	local s1 = (from.X - link.AX) * ux + (from.Z - link.AZ) * uz
	local l1 = (from.X - link.AX) * uz - (from.Z - link.AZ) * ux
	local s2 = (goal.X - link.AX) * ux + (goal.Z - link.AZ) * uz
	local l2 = (goal.X - link.AX) * uz - (goal.Z - link.AZ) * ux
	local halfW = link.Width * 0.5 + 1.5
	local t0, t1 = 0.01, 0.99
	local ds, dl = s2 - s1, l2 - l1
	for _, clip in {
		{ -ds, s1 - (-0.5) },
		{ ds, len - s1 },
		{ -dl, l1 - (-halfW) },
		{ dl, halfW - l1 },
	} do
		local p, q = clip[1], clip[2]
		if math.abs(p) < 1e-6 then
			if q < 0 then return false end
		else
			local r = q / p
			if p < 0 then
				if r > t1 then return false end
				if r > t0 then t0 = r end
			else
				if r < t0 then return false end
				if r < t1 then t1 = r end
			end
		end
	end
	return t0 <= t1
end

local function nodeLocation(id: string,p: Point): any
	return {Key="P:"..id,Node=id,Seeds={{Node=id,Point=p,Cost=0}}}
end
function Graph.Locate(g: any,p: Point): any
	local nearest,score,flatNode=nil,math.huge,nil
	for id,v in g.Platforms do
		local dx=math.max(0,math.abs(p.X-v.X)-v.Width/2)
		local dz=math.max(0,math.abs(p.Z-v.Z)-v.Depth/2)
		local d=dx*dx+dz*dz+(p.Y-v.Y)^2
		if d<score or (d==score and (not nearest or id<nearest)) then nearest,score=id,d end
		if not flatNode and dx==0 and dz==0 and math.abs(p.Y-v.Y)<.25 then flatNode=id end
	end
	local match,best=nil,math.huge
	local landingNode=nil
	for _,link in g.Links do
		local dx,dz=link.BX-link.AX,link.BZ-link.AZ
		local length2=dx*dx+dz*dz
		local t=((p.X-link.AX)*dx+(p.Z-link.AZ)*dz)/length2
		local cross=math.abs((p.X-link.AX)*dz-(p.Z-link.AZ)*dx)/math.sqrt(length2)
		local height=link.AY+(link.BY-link.AY)*math.clamp(t,0,1)
		if t>=0 and t<=1 and cross<=link.Width/2 and math.abs(p.Y-height)<=2 then
			local d=cross*cross+(p.Y-height)^2
			if d<best then
				local a,b=point(link.AX,link.AY,link.AZ),point(link.BX,link.BY,link.BZ)
				match={Key="C:"..link.Id,Link=link.Id,T=t,Width=link.UsableWidth,Seeds={
					{Node=link.From,Point=a,Cost=Graph.Distance(p,a)},
					{Node=link.To,Point=b,Cost=Graph.Distance(p,b)}}}
				best=d
			end
		end
		if not landingNode then
			for _,name in {"LandingA","LandingB"}do
				local pad=link[name]
				local lx,lz=pad.BX-pad.AX,pad.BZ-pad.AZ
				local ll=lx*lx+lz*lz
				local u=((p.X-pad.AX)*lx+(p.Z-pad.AZ)*lz)/ll
				local lateral=math.abs((p.X-pad.AX)*lz-(p.Z-pad.AZ)*lx)/math.sqrt(ll)
				if u>=0 and u<=1 and lateral<=pad.Width/2 and math.abs(p.Y-pad.AY)<.25 then
					landingNode=if name=="LandingA" then link.From else link.To
					break
				end
			end
		end
	end
	if match then return match end
	if flatNode then return nodeLocation(flatNode,p) end
	if landingNode then return nodeLocation(landingNode,p) end
	return nodeLocation(nearest,p)
end

function Graph.Route(g: any,from: Point,goal: Point): {Point}
	local start,finish=Graph.Locate(g,from),Graph.Locate(g,goal)
	if start.Key==finish.Key then
		if start.Node then
			for _,link in g.Links do
				if link.From==start.Node and segmentHitsLink(link,from,goal) then
					local pad=porchA(g,link)
					if Graph.Distance(from,pad)>1.5 and Graph.Distance(goal,pad)>1.5 then
						return {pad,goal}
					end
				end
			end
		end
		return {goal}
	end
	-- Flat connector ends can also belong to a terrace. Do not overshoot a
	-- goal just inside that terrace to visit the authored endpoint first.
	for _,link in g.Links do
		if link.Id==start.Link or link.Id==finish.Link then
			local function onDeck(p: Point): boolean
				local dx,dz=link.BX-link.AX,link.BZ-link.AZ
				local length2=dx*dx+dz*dz
				local t=((p.X-link.AX)*dx+(p.Z-link.AZ)*dz)/length2
				local lateral=math.abs((p.X-link.AX)*dz-(p.Z-link.AZ)*dx)/math.sqrt(length2)
				if t>=0 and t<=1 and lateral<=link.UsableWidth/2
					and math.abs(p.Y-link.AY-(link.BY-link.AY)*t)<=2 then
					return true
				end
				for _,name in {"LandingA","LandingB"}do
					local pad=link[name]
					local lx,lz=pad.BX-pad.AX,pad.BZ-pad.AZ
					local ll=lx*lx+lz*lz
					local u=((p.X-pad.AX)*lx+(p.Z-pad.AZ)*lz)/ll
					local padLat=math.abs((p.X-pad.AX)*lz-(p.Z-pad.AZ)*lx)/math.sqrt(ll)
					if u>=0 and u<=1 and padLat<=link.UsableWidth/2 and math.abs(p.Y-pad.AY)<=.5 then
						return true
					end
				end
				return false
			end
			if onDeck(from)and onDeck(goal)then return {goal}end
		end
	end
	local dist,prev,seed,open={},{},{},{}
	for id in g.Platforms do dist[id]=math.huge;open[id]=true end
	for _,s in start.Seeds do dist[s.Node]=s.Cost;seed[s.Node]=s.Point end
	while next(open) do
		local current,minimum=nil,math.huge
		for id in open do
			if dist[id]<minimum or (dist[id]==minimum and (not current or id<current))then current,minimum=id,dist[id]end
		end
		if not current or minimum==math.huge then break end
		open[current]=nil
		for _,edge in g.Edges[current] do
			if open[edge.To] and minimum+edge.Cost<dist[edge.To]then
				dist[edge.To]=minimum+edge.Cost
				prev[edge.To]={From=current,Edge=edge}
			end
		end
	end
	local chosen,cost=nil,math.huge
	for _,s in finish.Seeds do
		local candidate=dist[s.Node]+s.Cost
		if candidate<cost then chosen,cost=s,candidate end
	end
	if not chosen then return {} end
	local reversed={}
	local node=chosen.Node
	while prev[node] do table.insert(reversed,prev[node].Edge);node=prev[node].From end
	local route={seed[node]}
	if start.Link then
		for _,link in g.Links do
			if link.Id==start.Link and node==link.From then
				local afterStart=if #reversed>0 then reversed[#reversed].A else chosen.Point
				if needsPorchA(link,afterStart) then
					table.insert(route,porchA(g,link))
				end
				break
			end
		end
	end
	for i=#reversed,1,-1 do
		local edge=reversed[i]
		if edge.Link and edge.FromA and needsPorchA(edge.Link,route[#route]) then
			table.insert(route,porchA(g,edge.Link))
		end
		table.insert(route,edge.A)
		table.insert(route,edge.B)
		if edge.Link and not edge.FromA then
			local afterEdge=if i>1 then reversed[i-1].A else chosen.Point
			if needsPorchA(edge.Link,afterEdge) then
				table.insert(route,porchA(g,edge.Link))
			end
		end
	end
	if finish.Link then
		for _,link in g.Links do
			if link.Id==finish.Link and chosen.Node==link.From and needsPorchA(link,route[#route]) then
				table.insert(route,porchA(g,link))
				break
			end
		end
	end
	table.insert(route,chosen.Point);table.insert(route,goal)
	return route
end
function Graph.Remaining(route: {Point},index: number,from: Point): number
	local distance=0
	for i=index,#route do distance+=Graph.Distance(from,route[i]);from=route[i]end
	return distance
end
function Graph.RequestMatches(request: any,current: any): boolean
	return request.Revision==current.Revision and request.FloorId==current.FloorId
		and request.RoomGeneration==current.RoomGeneration and request.EntityGeneration==current.EntityGeneration
		and request.Intent==current.Intent
end
return Graph
