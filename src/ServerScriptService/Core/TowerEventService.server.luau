--!strict
-- Timed tower events (Phase G). One cycle per server: calm, a 60 s warning, then a 5-minute event.
-- State is published as ReplicatedStorage attributes so late joiners pick it up without a remote:
--   TowerEventPhase  "CALM" | "WARNING" | "ACTIVE"
--   TowerEventId     the upcoming (WARNING) or running (ACTIVE) event, "" while calm
--   TowerEventStartsAt / TowerEventEndsAt   server times (StartsAt is the next start while calm)
--   TowerEventBiome  the featured biome for BIOME events, 0 otherwise
-- Gameplay code asks _G.TowerEvents.GetMods(floorId) for the modifiers to stamp on a mob at spawn.
-- In Studio, setting workspace.TowerEventForce = "<EventId>" starts that event's warning at once.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EventConfig = require(Shared.Config.TowerEventConfig)
local EventRules = require(Shared.Util.TowerEventRules)
local TowerFloorConfig = require(Shared.Config.TowerFloorConfig)
local TowerLayout = require(Shared.Config.TowerLayout)
local Tower = require(script.Parent.TowerFloorService)

local Service = {}
local rng = Random.new()
local phase, eventId, featured = "CALM", "", 0
local startsAt, endsAt = 0, 0
local lastId: string? = nil

local function dataManager(): any
	while not _G.DataManager do task.wait(0.05) end
	return _G.DataManager
end

local function publish()
	ReplicatedStorage:SetAttribute("TowerEventPhase", phase)
	ReplicatedStorage:SetAttribute("TowerEventId", eventId)
	ReplicatedStorage:SetAttribute("TowerEventStartsAt", startsAt)
	ReplicatedStorage:SetAttribute("TowerEventEndsAt", endsAt)
	ReplicatedStorage:SetAttribute("TowerEventBiome", featured)
end

local function toastAll(text: string, kind: string)
	local dm = dataManager()
	for _, player in Players:GetPlayers() do dm.SendToast(player, text, kind) end
end

-- The best floor anyone in the server has cleared decides which biomes can be featured.
local function unlockedBiomes(): { number }
	local best = 0
	local dm = dataManager()
	for _, player in Players:GetPlayers() do
		local profile = dm.GetProfile(player)
		if profile then best = math.max(best, profile.HighestClearedFloor or 0) end
	end
	return EventRules.UnlockedBiomes(best)
end

local function beginCalm(now: number)
	phase, eventId, featured = "CALM", "", 0
	startsAt = now + EventConfig.CalmSeconds + EventConfig.WarningSeconds
	endsAt = startsAt + EventConfig.ActiveSeconds
	publish()
end

local function beginWarning(now: number, forcedId: string?)
	local id, biome
	if forcedId and EventConfig.Get(forcedId) then
		local event = assert(EventConfig.Get(forcedId))
		id, biome = forcedId, 0
		if event.Scope == "BIOME" then
			local unlocked = unlockedBiomes()
			biome = math.max(unlocked[#unlocked], math.ceil(event.MinFloor / 5))
		end
	else
		id, biome = EventRules.Pick(function() return rng:NextNumber() end, lastId, unlockedBiomes())
	end
	if not id then
		beginCalm(now)
		return
	end
	phase, eventId, featured = "WARNING", id, biome
	startsAt = now + EventConfig.WarningSeconds
	endsAt = startsAt + EventConfig.ActiveSeconds
	publish()
	local event = assert(EventConfig.Get(id))
	toastAll(string.format("%s begins in %d seconds", event.DisplayName, EventConfig.WarningSeconds), "WARN")
end

local function beginActive()
	phase = "ACTIVE"
	lastId = eventId
	publish()
end

local function endActive(now: number)
	local event = EventConfig.Get(eventId)
	if event then toastAll(event.DisplayName .. " has ended", "INFO") end
	beginCalm(now)
end

-- Modifiers for a mob spawning on `floorId` right now, or nil when no running event touches it.
function Service.GetMods(floorId: number): EventConfig.Mods?
	if phase ~= "ACTIVE" then return nil end
	local event = EventConfig.Get(eventId)
	local floor = TowerFloorConfig.Get(floorId)
	if not event or not floor then return nil end
	if not EventRules.Applies(event, floorId, floor.BiomeIndex, featured) then return nil end
	return event.Mods
end

function Service.Current(): (string, string, number)
	return phase, eventId, featured
end

-- Relic Rain: a telegraphed meteor lands on a random ramp of each featured floor that is in play,
-- then leaves an unowned relic (contested loot: carry and bank to keep it).
local function dropMeteor(floorId: number)
	local room = Tower.GetRoom(floorId)
	local floor = TowerFloorConfig.Get(floorId)
	if not room or room.Status ~= "READY" or not room.Origin or not floor then return end
	local links = TowerLayout.Get(floor.IndexInBiome).Links
	local link = links[rng:NextInteger(1, #links)]
	if link.From == "Sanctuary" then return end
	local t = rng:NextNumber(0.2, 0.8)
	local point = room.Origin + Vector3.new(link.AX, link.AY, link.AZ):Lerp(Vector3.new(link.BX, link.BY, link.BZ), t)
	local marker = Instance.new("Part")
	marker.Name = "RelicMeteorMarker"
	marker.Shape = Enum.PartType.Cylinder
	marker.Size = Vector3.new(0.2, 10, 10)
	marker.CFrame = CFrame.new(point + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	marker.Anchored, marker.CanCollide, marker.CanQuery, marker.CanTouch = true, false, false, false
	marker.Material = Enum.Material.Neon
	marker.Color = Color3.fromRGB(214, 150, 255)
	marker.Transparency = 0.35
	marker.Parent = room.Model
	task.delay(EventConfig.MeteorWarningSeconds, function()
		marker:Destroy()
		local tier = TowerFloorConfig.RollRelic(floorId, "ELITE", 0, rng:NextNumber())
		if tier and _G.RelicService and Tower.GetRoom(floorId) == room then
			pcall(_G.RelicService.SpawnRelic, tier, point, nil)
		end
	end)
end

local nextRain = 0
local function rainTick(now: number)
	local event = EventConfig.Get(eventId)
	if phase ~= "ACTIVE" or not event or not event.Mods.RelicRain or now < nextRain then return end
	nextRain = now + EventConfig.RelicRainSeconds
	for floorId = (featured - 1) * 5 + 1, featured * 5 do
		if floorId >= event.MinFloor then dropMeteor(floorId) end
	end
end

_G.TowerEvents = Service
beginCalm(Workspace:GetServerTimeNow())

if RunService:IsStudio() then
	Workspace:GetAttributeChangedSignal("TowerEventForce"):Connect(function()
		local forced = Workspace:GetAttribute("TowerEventForce")
		if type(forced) == "string" and EventConfig.Get(forced) then
			beginWarning(Workspace:GetServerTimeNow(), forced)
		end
	end)
end

task.spawn(function()
	while true do
		task.wait(1)
		local now = Workspace:GetServerTimeNow()
		if phase == "CALM" and now >= startsAt - EventConfig.WarningSeconds then
			beginWarning(now)
		elseif phase == "WARNING" and now >= startsAt then
			beginActive()
		elseif phase == "ACTIVE" and now >= endsAt then
			endActive(now)
		end
		rainTick(now)
	end
end)
