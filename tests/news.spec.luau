--!strict
-- tests/news.spec.luau
-- Server-wide headlines (B0): wording, merging bursts, priority and the rate limit (NewsRules).

local NewsRules = require(nodes["ReplicatedStorage.Shared.Util.NewsRules"])

local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end

local function item(kind: string, fields: { [string]: any }?): NewsRules.Item
	local out: any = { Kind = kind, ActorUserId = 1, ActorName = "Ana", TargetUserId = 2, TargetName = "Bo", ItemName = "Calamity Heart" }
	for k, v in fields or {} do out[k] = v end
	return out
end

test("news: every kind reads as a short headline and one clause", function()
	for kind in NewsRules.Kinds do
		local headline, detail = NewsRules.Format(item(kind, { FloorId = 12 }))
		assert(#headline > 0 and #headline <= 48, kind .. " headline stays short: " .. headline)
		assert(#detail > 0 and #detail <= 48, kind .. " detail stays short: " .. detail)
		assert(not string.find(headline, "|", 1, true) and not string.find(detail, "|", 1, true), "no toast separators")
	end
	local headline, detail = NewsRules.Format(item("THEFT", { FloorId = 12 }))
	assert(headline == "Ana stole a Calamity Heart" and detail == "from Bo · Bounty on Floor 12")
	assert((NewsRules.Format(item("THEFT", { ActorName = "" }))) == "A Master stole a Calamity Heart", "a missing name reads naturally")
	assert(NewsRules.Kinds.THEFT.Hunt and not NewsRules.Kinds.BIG_PULL.Hunt, "only a bounty offers Hunt")
end)

test("news: a burst from one Master merges into one headline with the rarest name", function()
	local queue = {}
	NewsRules.Enqueue(queue, item("BIG_PULL", { ItemName = "Edis", Tier = 6 }), 0)
	NewsRules.Enqueue(queue, item("BIG_PULL", { ItemName = "Han", Tier = 7 }), 1)
	NewsRules.Enqueue(queue, item("BIG_PULL", { ItemName = "Vane", Tier = 6 }), 2)
	assert(#queue == 1 and queue[1].Count == 3 and queue[1].ItemName == "Han", "merged, keeping the rarest")
	assert((NewsRules.Format(queue[1])) == "Ana summoned 3 legends")
	NewsRules.Enqueue(queue, item("BIG_PULL", { ActorUserId = 9, ActorName = "Cy" }), 3)
	assert(#queue == 2, "another Master's pull is its own headline")
	NewsRules.Enqueue(queue, item("BIG_PULL"), 3 + NewsRules.MERGE_WINDOW + 1)
	assert(#queue == 3, "news outside the merge window is separate")
	NewsRules.Enqueue(queue, item("THEFT"), 4)
	NewsRules.Enqueue(queue, item("THEFT"), 5)
	assert(#queue == 5, "thefts never merge: each has its own bounty")
end)

test("news: one headline per gap, highest priority first, oldest first within it", function()
	local queue = {}
	NewsRules.Enqueue(queue, item("BIG_FORGE", { ActorUserId = 3 }), 0)
	NewsRules.Enqueue(queue, item("HEART_BANKED", { ActorUserId = 4 }), 0)
	NewsRules.Enqueue(queue, item("THEFT"), 1)
	NewsRules.Enqueue(queue, item("ESCAPED"), 1)
	local first = NewsRules.Next(queue, -100, 10, 0)
	assert(first and first.Kind == "THEFT", "a theft jumps the queue")
	assert(NewsRules.Next(queue, 10, 10 + NewsRules.MIN_GAP - 0.1, 0) == nil, "nothing inside the gap")
	local second = NewsRules.Next(queue, 10, 10 + NewsRules.MIN_GAP, 0)
	assert(second and second.Kind == "HEART_BANKED", "then the older of the priority-2 items")
	local third = NewsRules.Next(queue, 0, 100, 0)
	local fourth = NewsRules.Next(queue, 0, 200, 0)
	assert(third and third.Kind == "ESCAPED" and fourth and fourth.Kind == "BIG_FORGE")
	assert(NewsRules.Next(queue, 0, 300, 0) == nil, "empty")
end)

test("news: an expired bounty is dropped, and a full queue sheds its least important news", function()
	local queue = {}
	NewsRules.Enqueue(queue, item("THEFT", { EndsAt = 50 }), 0)
	assert(NewsRules.Next(queue, -100, 0, 60) == nil and #queue == 0, "the bounty ran out before its turn")
	for i = 1, NewsRules.MAX_QUEUE do
		NewsRules.Enqueue(queue, item("BIG_FORGE", { ActorUserId = 100 + i }), i)
	end
	NewsRules.Enqueue(queue, item("THEFT"), 20)
	assert(#queue == NewsRules.MAX_QUEUE, "the queue stays bounded")
	local thefts = 0
	for _, waiting in queue do if waiting.Kind == "THEFT" then thefts += 1 end end
	assert(thefts == 1, "the theft survived; a forge headline was dropped")
	local unknown = {}
	NewsRules.Enqueue(unknown, item("NOT_A_KIND"), 0)
	assert(#unknown == 0, "unknown kinds are ignored")
end)

print(string.format("news.spec: %d passed", passed))
