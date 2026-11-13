--!strict
-- ReplicatedStorage/Shared/Util/EffectCullingRules.luau
-- Pure rules for HubEffectCulling: which hub scenery lights and particle emitters are worth running
-- from where the camera stands. All 8 plots sit around the Commons, so without this every torch,
-- brazier and spark on every island renders every frame (~550 lights, ~750 emitters).

local EffectCullingRules = {}

EffectCullingRules.Config = {
	-- A light turns off once the camera is this far beyond its Range (it can no longer light anything near the camera's view).
	LightCullDistance = 160,
	-- Small emitters (torch flames, sparks, mist puffs) turn off past this distance: they are a few pixels there.
	EmitterCullDistance = 220,
	-- Turning back on happens this much closer than turning off, so an effect at the edge doesn't flicker.
	Hysteresis = 25,
	-- Emitters whose particles grow larger than this are atmosphere (fog banks, cloud mist) meant to be seen
	-- from afar; they are never culled.
	AtmosphericParticleSize = 25,
	-- How many effects are re-checked per frame.
	ChecksPerFrame = 200,
}

-- The distance past which an effect should be off. `reach` is a light's Range (0 for emitters).
function EffectCullingRules.CullDistance(isLight: boolean, reach: number): number
	local cfg = EffectCullingRules.Config
	if isLight then
		return cfg.LightCullDistance + math.max(reach, 0)
	end
	return cfg.EmitterCullDistance
end

-- Whether an effect should be running, given its distance to the camera and whether it runs now.
-- A running effect stays on until it passes the cull distance; a culled one waits until it is
-- `Hysteresis` studs inside it.
function EffectCullingRules.ShouldRun(distance: number, cullDistance: number, runningNow: boolean): boolean
	if runningNow then
		return distance <= cullDistance
	end
	return distance <= cullDistance - EffectCullingRules.Config.Hysteresis
end

-- Largest particle size an emitter's Size sequence reaches (including its envelope).
function EffectCullingRules.MaxParticleSize(keypoints: { { Value: number, Envelope: number } }): number
	local largest = 0
	for _, kp in keypoints do
		largest = math.max(largest, kp.Value + kp.Envelope)
	end
	return largest
end

function EffectCullingRules.IsAtmospheric(maxParticleSize: number): boolean
	return maxParticleSize > EffectCullingRules.Config.AtmosphericParticleSize
end

return EffectCullingRules
