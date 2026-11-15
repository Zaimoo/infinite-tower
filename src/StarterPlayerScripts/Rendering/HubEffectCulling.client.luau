--!strict
-- StarterPlayerScripts/Rendering/HubEffectCulling.client.luau
-- Distance culling for the hub's static scenery effects. All 8 plots sit around the Cloister Commons, so
-- every torch light, brazier, forge flame, spark emitter and fountain waterfall beam on every island used
-- to render every frame (~550 lights, ~750 emitters, ~950 beams). This turns lights, small emitters and
-- beams off once the camera is far from them and back on as it approaches. Rules and distances: Shared/Util/EffectCullingRules.
--
-- Only static scenery under WaitingRoomPlots and BaseOverhaulGeometry is touched. Effects inside rigs
-- (anything under a Model with a Humanoid or AnimationController) are skipped, because their own scripts
-- toggle Enabled. Large atmospheric emitters (fog banks, cloud mist) are never culled. An effect that was
-- already disabled when found is left alone; the culler only turns back on what it turned off itself.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Rules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("EffectCullingRules"))

local ROOT_NAMES = { "WaitingRoomPlots", "BaseOverhaulGeometry" }

type Record = {
	Effect: Light | ParticleEmitter | Beam,
	Position: Vector3,
	CullDistance: number,
	Running: boolean, -- false while the culler has it switched off
	Dead: boolean,
}

local records: { Record } = {}
local byEffect: { [Instance]: Record } = {}
local cursor = 1

local function insideRig(inst: Instance, root: Instance): boolean
	local node = inst.Parent
	while node and node ~= root do
		if node:IsA("Model") and (node:FindFirstChildOfClass("Humanoid") or node:FindFirstChildOfClass("AnimationController")) then
			return true
		end
		node = node.Parent
	end
	return false
end

local function hostPosition(effect: Instance): Vector3?
	local parent = effect.Parent
	if parent and parent:IsA("Attachment") then
		return parent.WorldPosition
	elseif parent and parent:IsA("BasePart") then
		return parent.Position
	end
	return nil
end

-- A beam sits between two attachments: its position is their midpoint, and its length extends its reach.
local function beamSpan(beam: Beam): (Vector3?, number)
	local a0, a1 = beam.Attachment0, beam.Attachment1
	if not (a0 and a1) then
		return nil, 0
	end
	local p0, p1 = a0.WorldPosition, a1.WorldPosition
	return (p0 + p1) * 0.5, (p0 - p1).Magnitude
end

local function track(inst: Instance, root: Instance)
	if byEffect[inst] then
		return
	end
	local isLight = inst:IsA("Light")
	local isBeam = inst:IsA("Beam")
	if not (isLight or isBeam or inst:IsA("ParticleEmitter")) then
		return
	end
	local effect = inst :: any
	if not effect.Enabled then
		return -- its owner disabled it; not ours to turn on
	end
	if not isLight and not isBeam and Rules.IsAtmospheric(Rules.MaxParticleSize((effect :: ParticleEmitter).Size.Keypoints :: any)) then
		return
	end
	local position: Vector3?
	local cullDistance: number
	if isBeam then
		local length: number
		position, length = beamSpan(effect :: Beam)
		cullDistance = Rules.BeamCullDistance(length)
	else
		position = hostPosition(inst)
		cullDistance = Rules.CullDistance(isLight, if isLight then (effect :: any).Range or 0 else 0)
	end
	if not position or insideRig(inst, root) then
		return
	end
	local record: Record = {
		Effect = effect,
		Position = position,
		CullDistance = cullDistance,
		Running = true,
		Dead = false,
	}
	byEffect[inst] = record
	table.insert(records, record)
end

local function untrack(inst: Instance)
	local record = byEffect[inst]
	if record then
		record.Dead = true
		byEffect[inst] = nil
	end
end

local function watchRoot(root: Instance)
	for _, d in root:GetDescendants() do
		track(d, root)
	end
	-- Plot buildings are rebuilt and stream in after join; pick their effects up as they arrive.
	root.DescendantAdded:Connect(function(d)
		-- Let the builder finish setting the effect up (Enabled, Size, parent) before it is classified.
		task.defer(function()
			if d.Parent then
				track(d, root)
			end
		end)
	end)
	root.DescendantRemoving:Connect(untrack)
end

for _, name in ROOT_NAMES do
	task.spawn(function()
		local root = Workspace:WaitForChild(name, 60)
		if root then
			watchRoot(root)
		end
	end)
end

RunService.Heartbeat:Connect(function()
	local count = #records
	if count == 0 then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	debug.profilebegin("HubEffectCulling")
	local cameraPos = camera.CFrame.Position
	for _ = 1, math.min(Rules.Config.ChecksPerFrame, count) do
		if cursor > #records then
			cursor = 1
		end
		local record = records[cursor]
		if record.Dead then
			records[cursor] = records[#records]
			records[#records] = nil
		else
			local shouldRun = Rules.ShouldRun((record.Position - cameraPos).Magnitude, record.CullDistance, record.Running)
			if shouldRun ~= record.Running then
				record.Running = shouldRun
				record.Effect.Enabled = shouldRun
			end
			cursor += 1
		end
	end
	debug.profileend()
end)
