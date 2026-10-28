--!strict
-- ServerScriptService/Core/ProfilePersistence.luau
-- Session-locked DataStore persistence for player profiles (one key per player, UpdateAsync lock).
-- Lock rules live in ProfileCodec. In Studio without API access it falls back to unsaved sessions.

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ProfileCodec = require(script.Parent:WaitForChild("ProfileCodec"))

local STORE_NAME = "PlayerProfiles_v1"
local MAX_ATTEMPTS = 4
local CLAIM_ATTEMPTS = 6 -- the previous server may still be saving on leave
local CLAIM_RETRY_SECONDS = 5

local ProfilePersistence = {}

local jobId = if game.JobId ~= "" then game.JobId else "studio-" .. tostring(os.time())
local store: DataStore? = nil
local available = false
do
	local ok, result = pcall(function() return DataStoreService:GetDataStore(STORE_NAME) end)
	if ok then store = result; available = true
	else warn("[ProfilePersistence] DataStores unavailable, progress will not save: " .. tostring(result)) end
end

local function keyFor(userId: number): string return "User_" .. tostring(userId) end

local function retry<T>(label: string, fn: () -> T): (boolean, T | string)
	local lastErr: any
	for attempt = 1, MAX_ATTEMPTS do
		local ok, result = pcall(fn)
		if ok then return true, result end
		lastErr = result
		warn(`[ProfilePersistence] {label} failed (attempt {attempt}): {result}`)
		if attempt < MAX_ATTEMPTS then task.wait(2 ^ attempt + math.random()) end
	end
	return false, tostring(lastErr)
end

function ProfilePersistence.IsAvailable(): boolean return available end

export type LoadResult = { Ok: boolean, Data: any?, Persistent: boolean, Reason: string? }

-- Claims the session lock and returns saved data (nil for a new player). Ok=false means kick.
function ProfilePersistence.Load(userId: number, isStillHere: () -> boolean): LoadResult
	if not available or not store then
		if RunService:IsStudio() then return { Ok = true, Data = nil, Persistent = false } end
		return { Ok = false, Persistent = false, Reason = "Data service unavailable." }
	end
	local ds = store :: DataStore
	for _ = 1, CLAIM_ATTEMPTS do
		if not isStillHere() then return { Ok = false, Persistent = false, Reason = "left" } end
		local claimed: ProfileCodec.Record? = nil
		local ok, err = retry("Load " .. userId, function()
			ds:UpdateAsync(keyFor(userId), function(record: ProfileCodec.Record?)
				claimed = ProfileCodec.Claim(record, jobId, os.time())
				if claimed then return claimed, { userId } end
				return nil
			end)
			return true
		end)
		if not ok then return { Ok = false, Persistent = false, Reason = tostring(err) } end
		if claimed then return { Ok = true, Data = (claimed :: any).Data, Persistent = true } end
		task.wait(CLAIM_RETRY_SECONDS)
	end
	return { Ok = false, Persistent = false, Reason = "Your data is still open on another server." }
end

-- Saves (and optionally releases). Returns false if the write failed or the lock was lost.
function ProfilePersistence.Save(userId: number, profile: any, release: boolean): boolean
	if not available or not store then return false end
	local ds = store :: DataStore
	local data = ProfileCodec.Sanitize(profile)
	local written = false
	local ok = retry("Save " .. userId, function()
		written = false
		ds:UpdateAsync(keyFor(userId), function(record: ProfileCodec.Record?)
			local nextRecord = ProfileCodec.Write(record, jobId, os.time(), data, release)
			written = nextRecord ~= nil
			if nextRecord then return nextRecord, { userId } end
			return nil
		end)
		return true
	end)
	if ok and not written then warn(`[ProfilePersistence] Save {userId} skipped: session lock lost`) end
	return ok and written
end

return ProfilePersistence
