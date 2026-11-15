--!strict
-- ReplicatedStorage/Shared/Util/ProfileDelta.luau
-- Profile sync sends what changed, not the whole profile. The server keeps a copy of what each client
-- last received, diffs the live profile against it, and sends the difference; the client applies it to
-- its cached profile. Pure: no instances, no remotes.
--
-- A delta is { _Delta = true, Set = { key = value }, Unset = { key }, Maps = { Heroes = { Set, Unset } } }.
-- Top-level keys are compared whole and resent whole. Heroes and Artifacts are the two large maps, so
-- they are compared entry by entry and only the changed entries travel. Applying a delta twice gives
-- the same result as applying it once, so several listeners may apply it to a shared table.

local ProfileDelta = {}

-- Maps diffed per entry rather than resent whole.
ProfileDelta.MAP_KEYS = { "Heroes", "Artifacts" }

export type MapDelta = { Set: { [string]: any }?, Unset: { string }? }
export type Delta = {
	_Delta: boolean,
	Set: { [string]: any }?,
	Unset: { string }?,
	Maps: { [string]: MapDelta }?,
}

local isMapKey: { [string]: boolean } = {}
for _, key in ProfileDelta.MAP_KEYS do
	isMapKey[key] = true
end

function ProfileDelta.DeepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = ProfileDelta.DeepCopy(v)
	end
	return copy
end

function ProfileDelta.DeepEqual(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for k, v in a do
		if not ProfileDelta.DeepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function diffMap(previous: { [string]: any }, current: { [string]: any }): MapDelta?
	local set: { [string]: any }? = nil
	local unset: { string }? = nil
	for id, entry in current do
		if not ProfileDelta.DeepEqual(previous[id], entry) then
			set = set or {}
			(set :: { [string]: any })[id] = entry
		end
	end
	for id in previous do
		if current[id] == nil then
			unset = unset or {}
			table.insert(unset :: { string }, id)
		end
	end
	if set or unset then
		return { Set = set, Unset = unset }
	end
	return nil
end

-- What changed going from `previous` to `current`, or nil when nothing did. The returned delta holds
-- references into `current`: copy it before storing it (a remote copies it on send anyway).
function ProfileDelta.Diff(previous: { [string]: any }, current: { [string]: any }): Delta?
	local set: { [string]: any }? = nil
	local unset: { string }? = nil
	local maps: { [string]: MapDelta }? = nil
	for key, value in current do
		local before = previous[key]
		if isMapKey[key] and type(value) == "table" and type(before) == "table" then
			local mapDelta = diffMap(before, value)
			if mapDelta then
				maps = maps or {}
				(maps :: { [string]: MapDelta })[key] = mapDelta
			end
		elseif not ProfileDelta.DeepEqual(before, value) then
			set = set or {}
			(set :: { [string]: any })[key] = value
		end
	end
	for key in previous do
		if current[key] == nil then
			unset = unset or {}
			table.insert(unset :: { string }, key)
		end
	end
	if set or unset or maps then
		return { _Delta = true, Set = set, Unset = unset, Maps = maps }
	end
	return nil
end

-- Applies a delta to a cached profile in place. Returns the set of top-level keys it touched.
function ProfileDelta.Apply(profile: { [string]: any }, delta: Delta): { [string]: boolean }
	local touched: { [string]: boolean } = {}
	if delta.Set then
		for key, value in delta.Set do
			profile[key] = value
			touched[key] = true
		end
	end
	if delta.Unset then
		for _, key in delta.Unset do
			profile[key] = nil
			touched[key] = true
		end
	end
	if delta.Maps then
		for key, mapDelta in delta.Maps do
			local map = profile[key]
			if type(map) ~= "table" then
				map = {}
				profile[key] = map
			end
			if mapDelta.Set then
				for id, entry in mapDelta.Set do
					map[id] = entry
				end
			end
			if mapDelta.Unset then
				for _, id in mapDelta.Unset do
					map[id] = nil
				end
			end
			touched[key] = true
		end
	end
	return touched
end

function ProfileDelta.IsDelta(packet: any): boolean
	return type(packet) == "table" and packet._Delta == true
end

-- Whether a refresh that depends on everything except `ignored` is needed. `touched` is what Apply
-- returned, or nil after a full profile (everything may have changed). A key the caller did not list is
-- treated as relevant, so a new profile field refreshes too much rather than too little.
function ProfileDelta.Affects(touched: { [string]: boolean }?, ignored: { [string]: boolean }): boolean
	if not touched then
		return true
	end
	for key in touched do
		if not ignored[key] then
			return true
		end
	end
	return false
end

return ProfileDelta
