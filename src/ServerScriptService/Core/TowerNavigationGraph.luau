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
		table.insert(g.Edges[link.From],{To=link.To,A=a,B=b,Cost=cost})
		table.insert(g.Edges[link.To],{To=link.From,A=b,B=a,Cost=cost})
	end
	return g
end

local function nodeLocation(id: string,p: Point): any
	return {Key="P:"..id,Seeds={{Node=id,Point=p,Cost=0}}}
end
function Graph.Locate(g: any,p: Point): any
	local nearest,score=nil,math.huge
	for id,v in g.Platforms do
		local dx=math.max(0,math.abs(p.X-v.X)-v.Width/2)
		local dz=math.max(0,math.abs(p.Z-v.Z)-v.Depth/2)
		local d=dx*dx+dz*dz+(p.Y-v.Y)^2
		if d<score or (d==score and (not nearest or id<nearest)) then nearest,score=id,d end
		if dx==0 and dz==0 and math.abs(p.Y-v.Y)<.25 then return nodeLocation(id,p) end
	end
	local match,best=nil,math.huge
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
		for _,name in {"LandingA","LandingB"}do
			local pad=link[name]
			local lx,lz=pad.BX-pad.AX,pad.BZ-pad.AZ
			local ll=lx*lx+lz*lz
			local u=((p.X-pad.AX)*lx+(p.Z-pad.AZ)*lz)/ll
			local lateral=math.abs((p.X-pad.AX)*lz-(p.Z-pad.AZ)*lx)/math.sqrt(ll)
			if u>=0 and u<=1 and lateral<=pad.Width/2 and math.abs(p.Y-pad.AY)<.25 then
				return nodeLocation(if name=="LandingA" then link.From else link.To,p)
			end
		end
	end
	return match or nodeLocation(nearest,p)
end

function Graph.Route(g: any,from: Point,goal: Point): {Point}
	local start,finish=Graph.Locate(g,from),Graph.Locate(g,goal)
	if start.Key==finish.Key then return {goal} end
	-- Flat connector ends can also belong to a terrace. Do not overshoot a
	-- goal just inside that terrace to visit the authored endpoint first.
	for _,link in g.Links do
		if link.Id==start.Link or link.Id==finish.Link then
			local function onDeck(p: Point): boolean
				local dx,dz=link.BX-link.AX,link.BZ-link.AZ
				local length2=dx*dx+dz*dz
				local t=((p.X-link.AX)*dx+(p.Z-link.AZ)*dz)/length2
				local lateral=math.abs((p.X-link.AX)*dz-(p.Z-link.AZ)*dx)/math.sqrt(length2)
				return t>=0 and t<=1 and lateral<=link.UsableWidth/2
					and math.abs(p.Y-link.AY-(link.BY-link.AY)*t)<=2
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
	for i=#reversed,1,-1 do table.insert(route,reversed[i].A);table.insert(route,reversed[i].B)end
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
