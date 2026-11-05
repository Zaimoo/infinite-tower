--!strict
-- FIFO scheduler. Engine execution is injected and must always call done, even
-- for a cancelled request. Cancelled in-flight work still occupies its slot.
local Queue={}
Queue.__index=Queue
function Queue.new(limit: number,capacity: number,run: (any,()->())->()): any
	return setmetatable({Limit=limit,Capacity=capacity,Run=run,Active=0,Count=0,Waiting=0,Items={},Head=1,Tail=0,ByKey={},Draining=false},Queue)
end
function Queue:Drain()
	if self.Draining then return end
	self.Draining=true
	while self.Active<self.Limit and self.Head<=self.Tail do
		local job=self.Items[self.Head];self.Items[self.Head]=nil;self.Head+=1
		if job.Cancelled then continue end
		self.Active+=1;self.Waiting-=1;job.Started=true
		local finished=false
		local function done()
			if finished then return end;finished=true
			self.Active-=1
			if self.ByKey[job.Key]==job then self.ByKey[job.Key]=nil;self.Count-=1 end
			self:Drain()
		end
		local ok,failure=pcall(self.Run,job,done)
		if not ok then job.Error=tostring(failure);done()end
	end
	if self.Head>self.Tail then self.Items={};self.Head=1;self.Tail=0 end
	self.Draining=false
end
function Queue:Push(key: any,payload: any): any
	if self.ByKey[key] or self.Count>=self.Capacity then return nil end
	if self.Tail-self.Head>self.Capacity*2 then
		local items={}
		for i=self.Head,self.Tail do local old=self.Items[i];if not old.Cancelled then table.insert(items,old)end end
		self.Items=items;self.Head=1;self.Tail=#items
	end
	local job={Key=key,Payload=payload,Cancelled=false}
	self.ByKey[key]=job;self.Count+=1;self.Waiting+=1;self.Tail+=1;self.Items[self.Tail]=job
	self:Drain()
	return job
end
function Queue:Cancel(key: any)
	local job=self.ByKey[key]
	if job then
		if not job.Started then self.Waiting-=1 end
		job.Cancelled=true;job.Payload=nil;self.ByKey[key]=nil;self.Count-=1
	end
end
return Queue
