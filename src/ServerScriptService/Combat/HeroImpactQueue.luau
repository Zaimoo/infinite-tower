--!strict
-- ServerScriptService/Combat/HeroImpactQueue.luau
-- Hero attacks waiting to land (docs/projectile-skill-vfx-plan.md, section 2). Pure: no timers,
-- remotes or combat state. CombatSimulation pushes an impact when a hero decides to attack and
-- drains the queue every Heartbeat with two callbacks:
--   canRelease(impact)    at ReleaseAt. False drops the attack (the hero fell or left the room
--                         during the windup). Once released, a projectile always arrives.
--   resolve(impact, tick) at each impact time, Ticks times, TickSeconds apart.

local HeroImpactQueue = {}
HeroImpactQueue.__index = HeroImpactQueue

export type Impact = {
	ReleaseAt: number,
	At: number, -- time of the next tick
	Ticks: number,
	TickSeconds: number,
	Tick: number, -- ticks already resolved
	Released: boolean,
	[string]: any, -- payload owned by the caller
}

export type HeroImpactQueue = typeof(setmetatable({} :: { Items: { Impact } }, HeroImpactQueue))

function HeroImpactQueue.new(): HeroImpactQueue
	return setmetatable({ Items = {} }, HeroImpactQueue)
end

-- Adds an attack. The caller sets ReleaseAt, At (first impact), and optionally Ticks/TickSeconds.
function HeroImpactQueue.Push(self: HeroImpactQueue, impact: Impact)
	impact.Ticks = math.max(1, impact.Ticks or 1)
	impact.TickSeconds = math.max(0, impact.TickSeconds or 0)
	impact.Tick = 0
	impact.Released = false
	table.insert(self.Items, impact)
end

function HeroImpactQueue.Count(self: HeroImpactQueue): number
	return #self.Items
end

function HeroImpactQueue.Clear(self: HeroImpactQueue)
	table.clear(self.Items)
end

-- Releases and resolves everything due by `now`. Impacts pushed from inside resolve wait for
-- the next drain.
function HeroImpactQueue.Drain(self: HeroImpactQueue, now: number, canRelease: (Impact) -> boolean, resolve: (Impact, number) -> ())
	local items = self.Items
	if #items == 0 then
		return
	end
	self.Items = {}
	local keep: { Impact } = {}
	for _, impact in items do
		local alive = true
		if not impact.Released and now >= impact.ReleaseAt then
			if canRelease(impact) then
				impact.Released = true
			else
				alive = false
			end
		end
		while alive and impact.Released and now >= impact.At do
			impact.Tick += 1
			resolve(impact, impact.Tick)
			if impact.Tick >= impact.Ticks then
				alive = false
			else
				impact.At += impact.TickSeconds
			end
		end
		if alive then
			table.insert(keep, impact)
		end
	end
	for _, pushed in self.Items do
		table.insert(keep, pushed)
	end
	self.Items = keep
end

return HeroImpactQueue
