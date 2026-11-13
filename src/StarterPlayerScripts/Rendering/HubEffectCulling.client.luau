--!strict
-- StarterPlayerScripts/Rendering/HubEffectCulling.client.luau
-- Distance culling for the hub's static scenery effects. All 8 plots sit around the Cloister Commons, so
-- every torch light, brazier, forge flame and spark emitter on every island used to render every frame
-- (~550 lights, ~750 emitters). This turns lights and small emitters off once the camera is far from them
-- and back on as it approaches. Rules and distances: Shared/Util/EffectCullingRules.
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
	Effect: Light | ParticleEmitter,
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

local function track(inst: Instance, root: Instance)
	if byEffect[inst] then
		return
	end
	local isLight = inst:IsA("Light")
	if not (isLight or inst:IsA("ParticleEmitter")) then
		return
	end
	local effect = inst :: any
	if not effect.Enabled then
		return -- its owner disabled it; not ours to turn on
	end
	if not isLight and Rules.IsAtmospheric(Rules.MaxParticleSize((effect :: ParticleEmitter).Size.Keypoints :: any)) then
		return
	end
	local position = hostPosition(inst)
	if not position or insideRig(inst, root) then
		return
	end
	local record: Record = {
		Effect = effect,
		Position = position,
		CullDistance = Rules.CullDistance(isLight, if isLight then (effect :: any).Range or 0 else 0),
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
