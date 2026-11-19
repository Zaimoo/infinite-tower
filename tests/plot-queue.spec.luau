-- Tests for PlotQueue: FIFO plot assignment, server-full overflow queue, promotion, and tower crown guard.
local Hub = require(nodes["ReplicatedStorage.Shared.Config.HubLayout"])
local PlotQueue = require(nodes["ReplicatedStorage.Shared.Util.PlotQueue"])

local passed, failed = 0, 0
local function test(name, callback)
	local ok, err = pcall(callback)
	if ok then
		passed += 1
		print("PASS " .. name)
	else
		failed += 1
		print("FAIL " .. name .. ": " .. tostring(err))
	end
end

test("First 8 players claim plots in HubLayout.AssignmentOrder, 9..11 queue FIFO", function()
	local connected = {}
	local q = PlotQueue.new(Hub.AssignmentOrder, nil, function(p) return connected[p] == true end)
	for i = 1, 8 do
		local p = "p" .. i
		connected[p] = true
		local res = q:Join(p)
		assert(res.State == "ASSIGNED", "player " .. i .. " should be assigned")
		assert(res.PlotIndex == Hub.AssignmentOrder[i], "expected plot " .. Hub.AssignmentOrder[i])
		assert(not res.AlreadyTracked)
	end

	for k = 1, 3 do
		local p = "p" .. (8 + k)
		connected[p] = true
		local res = q:Join(p)
		assert(res.State == "QUEUED", "overflow player should queue")
		assert(res.PlotIndex == nil)
		assert(res.Position == k and res.Total == k)
	end
	assert(q:QueueLength() == 3)
end)

test("Duplicate Join is idempotent for both assigned and queued players", function()
	local q = PlotQueue.new(Hub.AssignmentOrder)
	for i = 1, 9 do q:Join("p" .. i) end
	local r1 = q:Join("p1")
	assert(r1.AlreadyTracked and r1.State == "ASSIGNED" and r1.PlotIndex == Hub.AssignmentOrder[1])
	local r9 = q:Join("p9")
	assert(r9.AlreadyTracked and r9.State == "QUEUED" and r9.Position == 1 and r9.Total == 1)
	assert(q:QueueLength() == 1)
end)

test("Queued player leaving shifts later positions; assigned player leaving promotes FIFO head", function()
	local connected = {}
	local q = PlotQueue.new(Hub.AssignmentOrder, nil, function(p) return connected[p] == true end)
	for i = 1, 11 do
		local p = "p" .. i
		connected[p] = true
		q:Join(p)
	end

	-- p10 (queue #2) leaves
	connected["p10"] = false
	local freed, wasQueued = q:Release("p10")
	assert(freed == nil and wasQueued)
	assert(q:QueuePosition("p9") == 1 and q:QueuePosition("p11") == 2 and q:QueueLength() == 2)

	-- p1 (plot 1) leaves -> p9 takes plot 1, p11 becomes #1 of 1
	connected["p1"] = false
	local freedPlot, ownerQueued = q:Release("p1")
	assert(freedPlot == Hub.AssignmentOrder[1] and not ownerQueued)
	local promoted = q:Promote()
	assert(#promoted == 1 and promoted[1].Player == "p9" and promoted[1].PlotIndex == Hub.AssignmentOrder[1])
	assert(q.PlayerToPlot["p9"] == Hub.AssignmentOrder[1])
	assert(q:QueuePosition("p9") == nil)
	assert(q:QueuePosition("p11") == 1 and q:QueueLength() == 1)
end)

test("Disconnected queued players are pruned before promoting", function()
	local connected = {}
	local q = PlotQueue.new(Hub.AssignmentOrder, nil, function(p) return connected[p] == true end)
	for i = 1, 10 do
		local p = "p" .. i
		connected[p] = true
		q:Join(p)
	end

	-- p9 drops without Release; p10 should take the freed plot when p2 leaves
	connected["p9"] = false
	connected["p2"] = false
	q:Release("p2")
	local promoted = q:Promote()
	assert(#promoted == 1 and promoted[1].Player == "p10" and promoted[1].PlotIndex == Hub.AssignmentOrder[2])
	assert(q:QueueLength() == 0)
end)

test("IsInTowerCrownTrap catches central tower drum spawns and ignores valid play spaces", function()
	assert(PlotQueue.IsInTowerCrownTrap(Vector3.new(0, 1640, 0)), "tower crown origin must be flagged")
	assert(PlotQueue.IsInTowerCrownTrap(Vector3.new(-0.5, 1639.9, -29.1)), "reported screenshot spot must be flagged")
	assert(not PlotQueue.IsInTowerCrownTrap(Vector3.new(0, 16, -342)), "tower gate threshold must stay safe")
	assert(not PlotQueue.IsInTowerCrownTrap(Hub.HubArrival), "HubArrival must stay safe")
	for i = 1, Hub.PlotCount do
		assert(not PlotQueue.IsInTowerCrownTrap(Hub.PlotCentre(i)), "plot centre " .. i .. " must stay safe")
	end
	assert(not PlotQueue.IsInTowerCrownTrap(Vector3.new(12000, 1000, 12000)), "off-map tower room must stay safe")
	assert(not PlotQueue.IsInTowerCrownTrap(Vector3.new(-14000, 1000, -14000)), "raid arena must stay safe")
end)

print(string.format("PlotQueue: %d passed, %d failed", passed, failed))
if failed > 0 then
	error("plot queue tests failed")
end
