--!strict
-- ServerScriptService/Core/ProfileCodec.luau
-- Pure helpers for profile persistence: the save record shape, the UpdateAsync session-lock rules and
-- stripping of derived or non-serialisable fields. No Roblox services, so tests run in the Luau CLI.

local ProfileCodec = {}

-- Recomputed from heroes on every sync; never persisted.
ProfileCodec.DerivedFields = { "SquadPower", "SquadPowerByHero" }

-- A lock not refreshed for this long belongs to a crashed server and may be stolen.
ProfileCodec.LockTimeoutSeconds = 600

export type Lock = { JobId: string, Time: number }
export type Record = { Data: any?, Lock: Lock?, SavedAt: number? }

local function copyValue(value: any): any
	local kind = type(value)
	if kind == "number" then
		if value ~= value or value == math.huge or value == -math.huge then return 0 end
		return value
	elseif kind == "string" or kind == "boolean" then
		return value
	elseif kind == "table" then
		local out = {}
		for key, child in value do
			local keyKind = type(key)
			if keyKind == "string" or keyKind == "number" then
				local copied = copyValue(child)
				if copied ~= nil then out[key] = copied end
			end
		end
		return out
	end
	return nil -- functions, Instances, userdata and threads are dropped
end

-- Deep copy safe for DataStore JSON; the live profile is never mutated.
function ProfileCodec.Sanitize(profile: any): any
	local out = copyValue(profile)
	for _, field in ProfileCodec.DerivedFields do out[field] = nil end
	return out
end

function ProfileCodec.IsLockedByOther(record: Record?, jobId: string, now: number): boolean
	local lock = record and record.Lock
	if not lock or lock.JobId == jobId then return false end
	return now - (lock.Time or 0) < ProfileCodec.LockTimeoutSeconds
end

-- UpdateAsync transform for joining: returns the new record, or nil to cancel when another live
-- server still owns the session.
function ProfileCodec.Claim(record: Record?, jobId: string, now: number): Record?
	if ProfileCodec.IsLockedByOther(record, jobId, now) then return nil end
	local current = record or {}
	return { Data = current.Data, Lock = { JobId = jobId, Time = now }, SavedAt = current.SavedAt }
end

-- UpdateAsync transform for saving. Cancels (nil) if this server lost the lock, so a stale server
-- can never overwrite progress made elsewhere. `release` clears the lock on leave/shutdown.
function ProfileCodec.Write(record: Record?, jobId: string, now: number, data: any, release: boolean): Record?
	local lock = record and record.Lock
	if lock and lock.JobId ~= jobId then return nil end
	return { Data = data, Lock = if release then nil else { JobId = jobId, Time = now }, SavedAt = now }
end

return ProfileCodec
