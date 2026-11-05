--!strict
-- StarterPlayerScripts/Rendering/HubPresence.luau
-- Shared helpers for the client's hub-only ambient systems (facility workers, outskirts patrol,
-- Commons scenery). While the local player is on a tower floor none of it is visible, so those
-- systems park instead of stepping every frame.

local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local HubPresence = {}

-- TowerFloorService sets the replicated "TowerFloorId" character attribute (0 in the hub and on plots).
function HubPresence.InTower(): boolean
	local character = LocalPlayer.Character
	if not character then
		return false
	end
	local floorId = character:GetAttribute("TowerFloorId")
	return type(floorId) == "number" and floorId > 0
end

-- A plot's origin: PlotBuildings' Origin attribute, else derived from the island top or the spawn pad.
function HubPresence.ResolvePlotOrigin(plot: Model): CFrame?
	local buildings = plot:FindFirstChild("PlotBuildings")
	if buildings then
		local attr = buildings:GetAttribute("Origin")
		if typeof(attr) == "CFrame" then
			return attr
		end
	end
	local island = plot:FindFirstChild("FloatingFortressIsland")
	local top = island and island:FindFirstChild("IslandTopSurface")
	if top and top:IsA("BasePart") then
		local surfaceY = top.Position.Y + top.Size.Y * 0.5
		if top.Size.Z > 200 then
			return CFrame.new(top.Position.X, surfaceY, top.Position.Z) * top.CFrame.Rotation * CFrame.new(0, 0, -70)
		end
		return CFrame.new(top.Position.X, surfaceY, top.Position.Z) * top.CFrame.Rotation
	end
	local spawn = plot:FindFirstChild("PlotSpawn")
	if spawn and spawn:IsA("BasePart") then
		local surfaceY = spawn.Position.Y - spawn.Size.Y * 0.5
		return CFrame.new(spawn.Position.X, surfaceY, spawn.Position.Z) * spawn.CFrame.Rotation * CFrame.new(0, 0, 80)
	end
	return nil
end

-- Plot origins never move once a plot is built, but resolving one walks the plot's children, so the
-- per-frame loops read a cached value and re-resolve at most once per ORIGIN_TTL seconds.
local ORIGIN_TTL = 1.0
type CachedOrigin = { Origin: CFrame?, ExpiresAt: number }
local originCache: { [Model]: CachedOrigin } = setmetatable({}, { __mode = "k" }) :: any

function HubPresence.CachedOrigin(plot: Model, now: number): CFrame?
	local entry = originCache[plot]
	if entry and now < entry.ExpiresAt then
		return entry.Origin
	end
	local origin = HubPresence.ResolvePlotOrigin(plot)
	-- A plot that is still building has no origin yet: retry next frame rather than caching the miss.
	originCache[plot] = { Origin = origin, ExpiresAt = if origin then now + ORIGIN_TTL else now }
	return origin
end

return HubPresence
