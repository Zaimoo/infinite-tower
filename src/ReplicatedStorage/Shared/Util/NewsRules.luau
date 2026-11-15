--!strict
-- ReplicatedStorage/Shared/Util/NewsRules.luau
-- Server-wide headlines (docs/first-session-and-social-plan.md B0, GDD §4.6.1): what each kind of
-- news says, how bursts merge, and the queue's priority and rate limit. Pure: NewsService owns the
-- queue on the server, NewsFeedController draws the banner. Every word shown is chosen here or is a
-- Roblox display name, so nothing needs text filtering.

local NewsRules = {}

NewsRules.MIN_GAP = 4 -- seconds between headlines
NewsRules.SHOW_SECONDS = 5 -- how long a headline stays up
NewsRules.MERGE_WINDOW = 60 -- the same Master's same kind of news within this long merges into one
NewsRules.MAX_QUEUE = 6 -- beyond this the lowest-priority item is dropped

export type Item = {
	Kind: string,
	ActorUserId: number?,
	ActorName: string?,
	TargetUserId: number?,
	TargetName: string?,
	ItemName: string?, -- a relic, hero, weapon or boss name (server-chosen)
	Tier: number?, -- rarity tier, for colour and wording
	FloorId: number?,
	EndsAt: number?, -- server time (GetServerTimeNow) a countdown runs to; the item expires then
	Count: number?, -- merged items
	At: number?, -- os.clock() when queued (server only)
	Sent: boolean?,
}

-- Priority 3 news jumps the queue; within a priority, oldest first. Hunt: the banner offers a Hunt
-- button (a public bounty).
NewsRules.Kinds = table.freeze({
	THEFT = table.freeze({ Priority = 3, Hunt = true, Merge = false }),
	BOUNTY_CLAIMED = table.freeze({ Priority = 2, Merge = false }),
	ESCAPED = table.freeze({ Priority = 2, Merge = false }),
	RELIC_DUEL = table.freeze({ Priority = 2, Merge = false }),
	BIG_PULL = table.freeze({ Priority = 2, Merge = true }),
	BIG_FORGE = table.freeze({ Priority = 1, Merge = true }),
	BIOME_FIRST = table.freeze({ Priority = 3, Merge = false }),
	HEART_BANKED = table.freeze({ Priority = 2, Merge = true }),
	ARCHON = table.freeze({ Priority = 3, Merge = false }),
})

local function name(value: string?): string
	return if value and value ~= "" then value else "A Master"
end

-- Headline (one short line) and detail (one clause) for an item.
function NewsRules.Format(item: Item): (string, string)
	local actor, target, thing = name(item.ActorName), name(item.TargetName), item.ItemName or "relic"
	local count = item.Count or 1
	local kind = item.Kind
	if kind == "THEFT" then
		local floor = if item.FloorId then string.format("Bounty on Floor %d", item.FloorId) else "Bounty open"
		return string.format("%s stole a %s", actor, thing), string.format("from %s · %s", target, floor)
	elseif kind == "BOUNTY_CLAIMED" then
		return string.format("%s claimed the bounty", actor), string.format("on %s · took the %s", target, thing)
	elseif kind == "ESCAPED" then
		return string.format("%s escaped with the loot", actor), string.format("beat %s for the %s", target, thing)
	elseif kind == "RELIC_DUEL" then
		return string.format("%s won a Relic Duel", actor), string.format("took %s's %s", target, thing)
	elseif kind == "BIG_PULL" then
		if count > 1 then
			return string.format("%s summoned %d legends", actor, count), string.format("best: %s", thing)
		end
		return string.format("%s summoned %s", actor, thing), "a legendary hero joins the server"
	elseif kind == "BIG_FORGE" then
		if count > 1 then
			return string.format("%s forged %d rare weapons", actor, count), string.format("best: %s", thing)
		end
		return string.format("%s forged %s", actor, thing), "a rare weapon from the Forge"
	elseif kind == "BIOME_FIRST" then
		return string.format("%s felled %s", actor, thing), "first Biome Boss kill on this server"
	elseif kind == "HEART_BANKED" then
		if count > 1 then
			return string.format("%s banked %d Hearts", actor, count), "Calamity Hearts reached safety"
		end
		return string.format("%s banked a %s", actor, thing), "a Calamity Heart reached safety"
	elseif kind == "ARCHON" then
		return string.format("%s won a Sovereign Archon", actor), string.format("from a %s", thing)
	end
	return actor, thing
end

-- Adds `item` to `queue` (in place). The same Master's mergeable news inside MERGE_WINDOW joins the
-- waiting item instead (a ten-pull with three legends is one headline), keeping the rarest name.
-- Over MAX_QUEUE, the lowest-priority, newest item is dropped.
function NewsRules.Enqueue(queue: { Item }, item: Item, now: number)
	local spec = NewsRules.Kinds[item.Kind]
	if not spec then return end
	item.At = now
	item.Count = item.Count or 1
	if spec.Merge then
		for _, waiting in queue do
			if not waiting.Sent and waiting.Kind == item.Kind and waiting.ActorUserId == item.ActorUserId
				and now - (waiting.At or now) <= NewsRules.MERGE_WINDOW then
				waiting.Count = (waiting.Count or 1) + (item.Count or 1)
				if (item.Tier or 0) > (waiting.Tier or 0) then
					waiting.Tier, waiting.ItemName = item.Tier, item.ItemName
				end
				return
			end
		end
	end
	table.insert(queue, item)
	while #queue > NewsRules.MAX_QUEUE do
		local worst, worstIndex = math.huge, 0
		for i, waiting in queue do
			local priority = NewsRules.Kinds[waiting.Kind].Priority
			if priority <= worst then worst, worstIndex = priority, i end -- ties: the newest goes
		end
		table.remove(queue, worstIndex)
	end
end

-- The next item to send, removed from `queue`, or nil while the last headline is still fresh
-- (MIN_GAP) or nothing is waiting. Items whose countdown has run out are dropped. `serverNow` is
-- GetServerTimeNow, for EndsAt.
function NewsRules.Next(queue: { Item }, lastSentAt: number, now: number, serverNow: number): Item?
	for i = #queue, 1, -1 do
		local endsAt = queue[i].EndsAt
		if endsAt and serverNow >= endsAt then table.remove(queue, i) end
	end
	if now - lastSentAt < NewsRules.MIN_GAP or #queue == 0 then return nil end
	local best, bestIndex = -1, 0
	for i, waiting in queue do
		local priority = NewsRules.Kinds[waiting.Kind].Priority
		if priority > best then best, bestIndex = priority, i end -- ties: the oldest wins
	end
	local item = table.remove(queue, bestIndex)
	item.Sent = true
	return item
end

return table.freeze(NewsRules)
