--!strict
-- ReplicatedStorage/Shared/Util/PlotQueue.luau
-- Pure FIFO plot assignment & overflow queue state machine, plus the central-tower trap check.
-- Keeps plot allocation and queue ordering testable under standalone Luau while PlotManager
-- owns the Workspace instances, attributes and teleports.

local PlotQueue = {}

PlotQueue.TOWER_GUARD_RADIUS = 340
PlotQueue.TOWER_GUARD_MIN_Y = 130

export type QueueEntry<T> = {
	Player: T,
	Position: number,
	Total: number,
}

export type AssignResult = {
	State: "ASSIGNED" | "QUEUED",
	PlotIndex: number?,
	Position: number,
	Total: number,
	AlreadyTracked: boolean,
}

export type Promotion<T> = {
	Player: T,
	PlotIndex: number,
}

export type State<T> = {
	Order: { number },
	IsSlotAvailable: ((number) -> boolean)?,
	IsConnected: ((T) -> boolean)?,
	AssignedPlots: { [number]: T },
	PlayerToPlot: { [T]: number },
	WaitQueue: { T },
	FirstFreePlot: (self: State<T>) -> number?,
	QueuePosition: (self: State<T>, player: T) -> number?,
	QueueLength: (self: State<T>) -> number,
	QueueSnapshot: (self: State<T>) -> { QueueEntry<T> },
	Join: (self: State<T>, player: T) -> AssignResult,
	Release: (self: State<T>, player: T) -> (number?, boolean),
	Promote: (self: State<T>) -> { Promotion<T> },
}

-- True when an overworld position sits inside the hollow central tower above its gate porch
-- (for instance when a character falls back to the world origin (0, 0, 0) and is pushed to Y~1640).
function PlotQueue.IsInTowerCrownTrap(pos: Vector3): boolean
	return pos.Y > PlotQueue.TOWER_GUARD_MIN_Y
		and math.sqrt(pos.X * pos.X + pos.Z * pos.Z) < PlotQueue.TOWER_GUARD_RADIUS
end

function PlotQueue.new<T>(
	order: { number },
	isSlotAvailable: ((number) -> boolean)?,
	isConnected: ((T) -> boolean)?
): State<T>
	local self = {
		Order = order,
		IsSlotAvailable = isSlotAvailable,
		IsConnected = isConnected,
		AssignedPlots = {} :: { [number]: T },
		PlayerToPlot = {} :: { [T]: number },
		WaitQueue = {} :: { T },
	} :: State<T>

	local function pruneDisconnected()
		if not self.IsConnected then
			return
		end
		for i = #self.WaitQueue, 1, -1 do
			if not self.IsConnected(self.WaitQueue[i]) then
				table.remove(self.WaitQueue, i)
			end
		end
	end

	function self.FirstFreePlot(_: State<T>): number?
		for _, idx in self.Order do
			if self.AssignedPlots[idx] == nil and (not self.IsSlotAvailable or self.IsSlotAvailable(idx)) then
				return idx
			end
		end
		return nil
	end

	function self.QueuePosition(_: State<T>, player: T): number?
		return table.find(self.WaitQueue, player)
	end

	function self.QueueLength(_: State<T>): number
		pruneDisconnected()
		return #self.WaitQueue
	end

	function self.QueueSnapshot(_: State<T>): { QueueEntry<T> }
		pruneDisconnected()
		local total = #self.WaitQueue
		local snapshot: { QueueEntry<T> } = table.create(total)
		for pos, queued in self.WaitQueue do
			snapshot[pos] = {
				Player = queued,
				Position = pos,
				Total = total,
			}
		end
		return snapshot
	end

	function self.Join(_: State<T>, player: T): AssignResult
		local existingPlot = self.PlayerToPlot[player]
		if existingPlot then
			return {
				State = "ASSIGNED",
				PlotIndex = existingPlot,
				Position = 0,
				Total = #self.WaitQueue,
				AlreadyTracked = true,
			}
		end
		local existingPos = table.find(self.WaitQueue, player)
		if existingPos then
			return {
				State = "QUEUED",
				PlotIndex = nil,
				Position = existingPos,
				Total = #self.WaitQueue,
				AlreadyTracked = true,
			}
		end

		local freeIdx = self:FirstFreePlot()
		if freeIdx then
			self.AssignedPlots[freeIdx] = player
			self.PlayerToPlot[player] = freeIdx
			return {
				State = "ASSIGNED",
				PlotIndex = freeIdx,
				Position = 0,
				Total = #self.WaitQueue,
				AlreadyTracked = false,
			}
		end

		pruneDisconnected()
		table.insert(self.WaitQueue, player)
		local total = #self.WaitQueue
		return {
			State = "QUEUED",
			PlotIndex = nil,
			Position = total,
			Total = total,
			AlreadyTracked = false,
		}
	end

	function self.Release(_: State<T>, player: T): (number?, boolean)
		local wasQueued = false
		local queuedAt = table.find(self.WaitQueue, player)
		if queuedAt then
			table.remove(self.WaitQueue, queuedAt)
			wasQueued = true
		end
		local freedPlot = self.PlayerToPlot[player]
		if freedPlot then
			self.AssignedPlots[freedPlot] = nil
			self.PlayerToPlot[player] = nil
		end
		pruneDisconnected()
		return freedPlot, wasQueued
	end

	function self.Promote(_: State<T>): { Promotion<T> }
		pruneDisconnected()
		local promoted: { Promotion<T> } = {}
		while #self.WaitQueue > 0 do
			local idx = self:FirstFreePlot()
			if not idx then
				break
			end
			local nextPlayer = table.remove(self.WaitQueue, 1)
			if nextPlayer and (not self.IsConnected or self.IsConnected(nextPlayer)) then
				self.AssignedPlots[idx] = nextPlayer
				self.PlayerToPlot[nextPlayer] = idx
				table.insert(promoted, { Player = nextPlayer, PlotIndex = idx })
			end
		end
		return promoted
	end

	return self
end

return PlotQueue
