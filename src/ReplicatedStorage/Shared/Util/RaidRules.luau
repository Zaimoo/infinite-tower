--!strict
-- Pure raid rules (docs/raid-boss-plan.md §2, §4, §5): schedule, boss rotation, HP budget,
-- leaderboard ranking and the damage reward curve. No Roblox services, so the specs can run it.
local Config = require(script.Parent.Parent.Config.RaidConfig)

local Rules = {}

export type Timings = { Interval: number, Warning: number, Active: number, Results: number, Cutoff: number }
export type Phase = "CALM" | "WARNING" | "ACTIVE" | "RESULTS"
export type Entry = { UserId: number, Damage: number, FirstAt: number }
export type Reward = { Gems: number, Gold: number, Share: number, Qualified: boolean }

function Rules.Timings(fast: boolean?): Timings
	local f = Config.Fast
	return {
		Interval = Config.IntervalSeconds,
		Warning = if fast then f.WarningSeconds else Config.WarningSeconds,
		Active = if fast then f.ActiveSeconds else Config.ActiveSeconds,
		Results = if fast then f.ResultsSeconds else Config.ResultsSeconds,
		Cutoff = if fast then f.LateJoinCutoffSeconds else Config.LateJoinCutoffSeconds,
	}
end

-- The next raid start strictly after `unixNow` (aligned to the interval, so :00 and :30 UTC).
function Rules.NextStart(unixNow: number, interval: number?): number
	local step = interval or Config.IntervalSeconds
	return (math.floor(unixNow / step) + 1) * step
end

-- Raid number for a start time: the idempotency key for rewards.
function Rules.RaidNumber(startUnix: number, interval: number?): number
	return math.floor(startUnix / (interval or Config.IntervalSeconds))
end

function Rules.BossFor(raidNumber: number): Config.Boss
	return Config.Bosses[(raidNumber % #Config.Bosses) + 1]
end

-- Phase of the raid starting at `startAt`, seen at `now` (both on the same clock).
function Rules.PhaseAt(now: number, startAt: number, t: Timings): Phase
	if now < startAt - t.Warning then return "CALM" end
	if now < startAt then return "WARNING" end
	if now < startAt + t.Active then return "ACTIVE" end
	if now < startAt + t.Active + t.Results then return "RESULTS" end
	return "CALM"
end

-- Entry is open during the warning and the fight, until the late-join cutoff.
function Rules.CanEnter(now: number, startAt: number, t: Timings): boolean
	return now >= startAt - t.Warning and now < startAt + t.Active - t.Cutoff
end

-- One participant's share of the HP budget.
function Rules.HpShare(squadDPS: number, activeSeconds: number?): number
	local dps = math.max(Config.MinDPS, if squadDPS == squadDPS then squadDPS else 0)
	return dps * (activeSeconds or Config.ActiveSeconds) * Config.HpFactor
end

-- Add a joiner's share, keeping the HP fraction (so a late joiner never heals a dying boss).
function Rules.AddShare(currentHP: number, maxHP: number, share: number): (number, number)
	if maxHP <= 0 then return share, share end
	local fraction = math.clamp(currentHP / maxHP, 0, 1)
	local newMax = maxHP + share
	return newMax * fraction, newMax
end

-- Ranked leaderboard: damage descending, ties go to whoever reached their damage first.
function Rules.Rank(entries: { Entry }): { Entry }
	local list = table.clone(entries)
	table.sort(list, function(a, b)
		if a.Damage ~= b.Damage then return a.Damage > b.Damage end
		if a.FirstAt ~= b.FirstAt then return a.FirstAt < b.FirstAt end
		return a.UserId < b.UserId
	end)
	return list
end

function Rules.Qualifies(damage: number, rank: number, maxHP: number): boolean
	if damage <= 0 then return false end
	return rank <= Config.QualifyTopN or damage >= maxHP * Config.QualifyFractionOfMaxHP
end

-- Gems = min(MaxGems, round(MaxGems * kill * (min + (1 - min) * share^exp))), kill = 0.5 + 0.5 * removed.
function Rules.Reward(damage: number, maxDamage: number, rank: number, maxHP: number, hpRemovedFraction: number, floorScale: number?): Reward
	if not Rules.Qualifies(damage, rank, maxHP) or maxDamage <= 0 then
		return { Gems = 0, Gold = 0, Share = 0, Qualified = false }
	end
	local share = math.clamp(damage / maxDamage, 0, 1)
	local kill = 0.5 + 0.5 * math.clamp(hpRemovedFraction, 0, 1)
	local curve = Config.MinShareCurve + (1 - Config.MinShareCurve) * share ^ Config.ShareExponent
	local gems = math.clamp(math.round(Config.MaxGems * kill * curve), 0, Config.MaxGems)
	local gold = math.round(gems * Config.GoldPerGem * (floorScale or 1))
	return { Gems = gems, Gold = gold, Share = share, Qualified = true }
end

-- Gold floor scaling matches relic Gold (1 + 0.05 per floor above 1).
function Rules.FloorScale(highestFloor: number): number
	return 1 + 0.05 * math.max(0, math.min(50, highestFloor) - 1)
end

-- Seconds as m:ss.
function Rules.Clock(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- Short damage figure: 950, 12.4K, 3.2M, 1.1B, 7.5T.
function Rules.Abbrev(n: number): string
	local units = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
	for _, u in units do
		if n >= u[1] then
			local v = n / u[1]
			return (if v >= 100 then string.format("%d", math.floor(v)) else string.format("%.1f", math.floor(v * 10) / 10)) .. u[2]
		end
	end
	return tostring(math.floor(n))
end

-- Leaderboard wire format (RaidRemotes.Board, unreliable, 2 Hz):
-- u8 count, count x (u8 slot, f64 damage), u8 selfRank (0 = none), f64 selfDamage, f64 total, f64 maxHP, f64 currentHP
function Rules.EncodeBoard(rows: { { Slot: number, Damage: number } }, selfRank: number, selfDamage: number, total: number, maxHP: number, currentHP: number): buffer
	local n = math.min(#rows, 255)
	local buf = buffer.create(1 + n * 9 + 1 + 32)
	buffer.writeu8(buf, 0, n)
	local o = 1
	for i = 1, n do
		buffer.writeu8(buf, o, math.clamp(rows[i].Slot, 0, 255))
		buffer.writef64(buf, o + 1, rows[i].Damage)
		o += 9
	end
	buffer.writeu8(buf, o, math.clamp(selfRank, 0, 255))
	buffer.writef64(buf, o + 1, selfDamage)
	buffer.writef64(buf, o + 9, total)
	buffer.writef64(buf, o + 17, maxHP)
	buffer.writef64(buf, o + 25, currentHP)
	return buf
end

function Rules.DecodeBoard(buf: buffer): any?
	local len = buffer.len(buf)
	if len < 1 then return nil end
	local n = buffer.readu8(buf, 0)
	if len ~= 1 + n * 9 + 33 then return nil end
	local rows = {}
	local o = 1
	for _ = 1, n do
		table.insert(rows, { Slot = buffer.readu8(buf, o), Damage = buffer.readf64(buf, o + 1) })
		o += 9
	end
	return {
		Rows = rows,
		SelfRank = buffer.readu8(buf, o),
		SelfDamage = buffer.readf64(buf, o + 1),
		Total = buffer.readf64(buf, o + 9),
		MaxHP = buffer.readf64(buf, o + 17),
		CurrentHP = buffer.readf64(buf, o + 25),
	}
end

return table.freeze(Rules)
