--!strict
-- ServerScriptService/Core/StaticGeometry.luau
-- One pass over freshly built scenery (hub, plot buildings, tower rooms) that turns off engine work
-- the scenery never needs:
--   * CanTouch = false on anchored parts. Nothing listens for Touched on scenery, but every part a
--     character walks over still costs touch-pair bookkeeping. Parts that do use Touched (the hub kill
--     zone, traversal pads, loot drops) carry the NeedsTouch attribute and are skipped, as are SpawnLocations.
--   * CastShadow = false on small anchored parts (trim, studs, rivets, leaves), whose shadows are a few
--     pixels but each one is another shadow caster.
--   * Shadows = false on scenery lights (torches, window glows, braziers). Under Future lighting every
--     shadowed PointLight/SpotLight renders its own shadow map; with 8 plots in view that was ~400 maps
--     a frame. A light that really needs shadows can carry the KeepShadows attribute.
--   * Scenery lights are dimmed to SCENERY_LIGHT_BRIGHTNESS of what their builder set, so torches and
--     window glows don't wash the stone orange. The original value is kept in the BaseBrightness attribute,
--     which also makes the pass safe to run more than once.
-- ThinEmitters is a separate pass for the hub only (tower rooms keep their authored rates): hub scenery
-- emitters run at SCENERY_EMITTER_RATE of what their builder set. The original is kept in the BaseRate
-- attribute, so the pass is safe to run more than once. Emitters at or below MIN_THINNED_RATE (cloud mist,
-- slow embers) are already sparse and are skipped, as is anything carrying the KeepRate attribute.
-- CanCollide and CanQuery are left alone: floors, walls and navigation raycasts depend on them.

local StaticGeometry = {}

StaticGeometry.NEEDS_TOUCH_ATTRIBUTE = "NeedsTouch"
-- A part whose largest side is at most this many studs stops casting a shadow.
StaticGeometry.SMALL_PART_MAX_SIZE = 1.5
StaticGeometry.KEEP_SHADOWS_ATTRIBUTE = "KeepShadows"
StaticGeometry.SCENERY_LIGHT_BRIGHTNESS = 0.6
StaticGeometry.BASE_BRIGHTNESS_ATTRIBUTE = "BaseBrightness"
StaticGeometry.SCENERY_EMITTER_RATE = 0.5
StaticGeometry.MIN_THINNED_RATE = 2
StaticGeometry.BASE_RATE_ATTRIBUTE = "BaseRate"
StaticGeometry.KEEP_RATE_ATTRIBUTE = "KeepRate"

export type Stats = { Parts: number, TouchOff: number, ShadowOff: number, LightShadowOff: number }

local function applyLight(light: Light, stats: Stats)
	if light.Shadows and light:GetAttribute(StaticGeometry.KEEP_SHADOWS_ATTRIBUTE) ~= true then
		light.Shadows = false
		stats.LightShadowOff += 1
	end
	if light:GetAttribute(StaticGeometry.BASE_BRIGHTNESS_ATTRIBUTE) == nil then
		light:SetAttribute(StaticGeometry.BASE_BRIGHTNESS_ATTRIBUTE, light.Brightness)
		light.Brightness *= StaticGeometry.SCENERY_LIGHT_BRIGHTNESS
	end
end

local function applyPart(part: BasePart, stats: Stats)
	stats.Parts += 1
	if not part.Anchored then
		return -- moving pieces (doors, welded props) keep their settings
	end
	-- SpawnLocations use touch for team changes; leave them as built.
	if part.CanTouch and not part:IsA("SpawnLocation") and part:GetAttribute(StaticGeometry.NEEDS_TOUCH_ATTRIBUTE) ~= true then
		part.CanTouch = false
		stats.TouchOff += 1
	end
	local size = part.Size
	if part.CastShadow and math.max(size.X, size.Y, size.Z) <= StaticGeometry.SMALL_PART_MAX_SIZE then
		part.CastShadow = false
		stats.ShadowOff += 1
	end
end

function StaticGeometry.Apply(root: Instance): Stats
	local stats: Stats = { Parts = 0, TouchOff = 0, ShadowOff = 0, LightShadowOff = 0 }
	if root:IsA("BasePart") then
		applyPart(root, stats)
	end
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			applyPart(d, stats)
		elseif d:IsA("Light") then
			applyLight(d, stats)
		end
	end
	return stats
end

-- The thinned rate for an emitter authored at `rate`; pure, so it can be tested without instances.
function StaticGeometry.ThinnedRate(rate: number): number
	if rate <= StaticGeometry.MIN_THINNED_RATE then
		return rate
	end
	return math.max(StaticGeometry.MIN_THINNED_RATE, rate * StaticGeometry.SCENERY_EMITTER_RATE)
end

-- Halves hub scenery emitter rates. Returns how many emitters changed.
function StaticGeometry.ThinEmitters(root: Instance): number
	local changed = 0
	for _, d in root:GetDescendants() do
		if d:IsA("ParticleEmitter")
			and d:GetAttribute(StaticGeometry.BASE_RATE_ATTRIBUTE) == nil
			and d:GetAttribute(StaticGeometry.KEEP_RATE_ATTRIBUTE) ~= true
		then
			local thinned = StaticGeometry.ThinnedRate(d.Rate)
			if thinned ~= d.Rate then
				d:SetAttribute(StaticGeometry.BASE_RATE_ATTRIBUTE, d.Rate)
				d.Rate = thinned
				changed += 1
			end
		end
	end
	return changed
end

-- For parts that connect Touched: tag them so Apply leaves them alone, and make sure touch is on.
function StaticGeometry.MarkNeedsTouch(part: BasePart)
	part:SetAttribute(StaticGeometry.NEEDS_TOUCH_ATTRIBUTE, true)
	part.CanTouch = true
end

return StaticGeometry
