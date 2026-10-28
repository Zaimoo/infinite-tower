-- Session-lock and save-sanitising rules from ProfileCodec, run through roblox-module-shim.luau.
local Codec = require(nodes["ServerScriptService.Core.ProfileCodec"])

local passed, failed = 0, 0
local function check(condition, message) assert(condition, message or "Expected condition to be true") end
local function test(name, callback)
	local ok, result = pcall(callback)
	if ok then passed += 1; print("PASS " .. name)
	else failed += 1; print("FAIL " .. name .. "\n" .. tostring(result)) end
end

test("persistence: sanitize strips derived and non-serialisable fields", function()
	local live = { SquadPower = 900, SquadPowerByHero = { a = 1 }, Currencies = { Gold = 5, Gems = 0 / 0 },
		Heroes = { ["uuid-1"] = { Level = 3, Callback = function() end } }, FortressTree = { Nodes = { 1, 2 } } }
	local saved = Codec.Sanitize(live)
	check(saved.SquadPower == nil and saved.SquadPowerByHero == nil, "derived fields persisted")
	check(saved.Currencies.Gold == 5 and saved.Currencies.Gems == 0, "NaN not cleaned")
	check(saved.Heroes["uuid-1"].Level == 3 and saved.Heroes["uuid-1"].Callback == nil, "function persisted")
	check(saved.FortressTree.Nodes[2] == 2, "array lost")
	check(live.SquadPower == 900 and saved ~= live, "live profile mutated")
end)

test("persistence: claim takes a free, own or stale lock", function()
	local new = Codec.Claim(nil, "A", 1000)
	check(new and new.Lock.JobId == "A" and new.Data == nil, "new player claim")
	local own = Codec.Claim({ Data = { x = 1 }, Lock = { JobId = "A", Time = 1 } }, "A", 1000)
	check(own and own.Data.x == 1, "own lock")
	local stale = Codec.Claim({ Data = { x = 2 }, Lock = { JobId = "B", Time = 0 } }, "A", Codec.LockTimeoutSeconds + 1)
	check(stale and stale.Lock.JobId == "A" and stale.Data.x == 2, "stale lock not stolen")
end)

test("persistence: claim refuses a live lock held by another server", function()
	check(Codec.Claim({ Data = {}, Lock = { JobId = "B", Time = 990 } }, "A", 1000) == nil, "live lock stolen")
end)

test("persistence: write keeps or releases the lock and never overwrites another server", function()
	local kept = Codec.Write({ Lock = { JobId = "A", Time = 1 } }, "A", 50, { Gold = 9 }, false)
	check(kept and kept.Lock.Time == 50 and kept.Data.Gold == 9 and kept.SavedAt == 50, "autosave")
	local released = Codec.Write({ Lock = { JobId = "A", Time = 1 } }, "A", 60, {}, true)
	check(released and released.Lock == nil, "release")
	check(Codec.Write({ Lock = { JobId = "B", Time = 1 } }, "A", 60, {}, true) == nil, "overwrote other server")
end)

test("persistence: a Studio session reclaims a lock left by a killed Studio session", function()
	local left = { Data = { Gold = 7 }, Lock = { JobId = "studio-100", Time = 995 } }
	local claim = Codec.Claim(left, "studio-200", 1000)
	check(claim and claim.Data.Gold == 7 and claim.Lock.JobId == "studio-200", "studio lock not reclaimed")
	check(Codec.Write(left, "studio-200", 1000, {}, true) ~= nil, "studio write refused")
	check(Codec.Claim(left, "guid-live", 1000) == nil, "live server stole a fresh studio lock")
	check(Codec.Claim({ Lock = { JobId = "guid-live", Time = 995 } }, "studio-200", 1000) == nil, "studio stole a live lock")
end)

print(("profile-persistence: %d passed, %d failed"):format(passed, failed))
if failed > 0 then error("profile-persistence tests failed") end
