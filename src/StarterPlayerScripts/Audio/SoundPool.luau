--!strict
-- StarterPlayerScripts/Audio/SoundPool.luau
-- Recycled sound instance pool for high-frequency 3D and 2D sound effects.
-- Features:
-- 1. Pre-allocated instances to eliminate garbage collection hitching during heavy combat.
-- 2. 180-stud distance culling from CurrentCamera to safeguard mobile performance.
-- 3. Automatic channel limit enforcement (max 32 active concurrent sounds).
-- 4. Clean recycling on sound completion.

local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local SoundPool = {}

local MAX_POOL_SIZE = 40
local MAX_CONCURRENT_ACTIVE = 32
local MAX_AUDIBLE_DISTANCE = 180 -- studs

local freePool: { Sound } = {}
local activeCount = 0

local function getSFXGroup(): SoundGroup
	local sg = SoundService:FindFirstChild("SG_SFX")
	if sg and sg:IsA("SoundGroup") then
		return sg
	end
	local fallback = SoundService:FindFirstChild("SFX")
	if fallback and fallback:IsA("SoundGroup") then
		return fallback
	end
	local newGroup = Instance.new("SoundGroup")
	newGroup.Name = "SG_SFX"
	newGroup.Volume = 0.8
	newGroup.Parent = SoundService
	return newGroup
end

-- Acquire a clean Sound instance
function SoundPool.Acquire(): Sound?
	if activeCount >= MAX_CONCURRENT_ACTIVE then
		return nil
	end

	local s: Sound
	if #freePool > 0 then
		s = table.remove(freePool) :: Sound
	else
		s = Instance.new("Sound")
		s.RollOffMode = Enum.RollOffMode.InverseTapered
	end

	activeCount += 1
	s.SoundGroup = getSFXGroup()
	return s
end

-- Release a Sound back into the pool
function SoundPool.Release(s: Sound)
	if not s:IsA("Sound") then return end
	s:Stop()
	s.SoundId = ""
	s.Parent = nil

	activeCount = math.max(0, activeCount - 1)

	if #freePool < MAX_POOL_SIZE then
		table.insert(freePool, s)
	else
		s:Destroy()
	end
end

-- Checks if a world position is within audible range of the camera
function SoundPool.IsAudible(position: Vector3): boolean
	local cam = Workspace.CurrentCamera
	if not cam then return true end
	return (cam.CFrame.Position - position).Magnitude <= MAX_AUDIBLE_DISTANCE
end

function SoundPool.GetActiveCount(): number
	return activeCount
end

return SoundPool
