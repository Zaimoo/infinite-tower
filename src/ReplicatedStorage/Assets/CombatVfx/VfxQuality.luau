--!strict
-- ReplicatedStorage/Assets/CombatVfx/VfxQuality.luau
-- Combat VFX quality levels and the automatic drop on slow frames (docs/projectile-skill-vfx-plan.md,
-- Phase 6). Pure, so the test suite can check it. VfxPool owns one State and feeds it frame times.
--
-- The player's graphics setting (Settings UI "Quality") is the ceiling. When frames stay slow the
-- effective level steps down one at a time, and climbs back once frames have been fast for a while.

local VfxQuality = {}

export type Level = "High" | "Medium" | "Low"

VfxQuality.ORDER = table.freeze({ "High", "Medium", "Low" } :: { Level })

-- Detail multiplies effect counts (rain arrows, slashes, spikes, motes); decoration (sigil spokes,
-- flight rings, motes) is skipped below DECOR_DETAIL. MaxEffects caps live effects per client.
VfxQuality.LEVELS = table.freeze({
	High = table.freeze({ Detail = 1.0, MaxEffects = 160 }),
	Medium = table.freeze({ Detail = 0.6, MaxEffects = 110 }),
	Low = table.freeze({ Detail = 0.35, MaxEffects = 70 }),
})
VfxQuality.DECOR_DETAIL = 0.5
-- Decoration is also skipped once live effects pass this share of the cap.
VfxQuality.DECOR_PRESSURE = 0.6

-- Frame time thresholds (seconds) and how long they must hold before the level changes.
VfxQuality.SLOW_FRAME = 1 / 35
VfxQuality.FAST_FRAME = 1 / 50
VfxQuality.SLOW_HOLD = 3
VfxQuality.FAST_HOLD = 8
VfxQuality.SMOOTHING = 0.05 -- exponential average weight of each new frame

export type State = {
	Setting: Level, -- the player's choice: the highest level allowed
	Auto: Level, -- the level after automatic drops (never above Setting)
	FrameTime: number, -- smoothed frame time, seconds
	SlowFor: number,
	FastFor: number,
}

local function index(level: Level): number
	return table.find(VfxQuality.ORDER, level) or 1
end

-- Reads a settings value ("High", "Medium", "Low", any case); anything else means High.
function VfxQuality.Parse(value: any): Level
	if type(value) == "string" then
		for _, level in VfxQuality.ORDER do
			if string.lower(level) == string.lower(value) then
				return level
			end
		end
	end
	return "High"
end

-- Roblox's own graphics slider (GameSettings.SavedQualityLevel: 0 = Automatic, 1..10) as a level.
function VfxQuality.FromRobloxLevel(level: number): Level
	if level >= 1 and level <= 3 then
		return "Low"
	elseif level >= 4 and level <= 6 then
		return "Medium"
	end
	return "High"
end

-- The lower (cheaper) of two levels.
function VfxQuality.Lower(a: Level, b: Level): Level
	return VfxQuality.ORDER[math.max(index(a), index(b))]
end

function VfxQuality.New(setting: Level?): State
	local level = setting or "High"
	return { Setting = level, Auto = level, FrameTime = 1 / 60, SlowFor = 0, FastFor = 0 }
end

-- The level in effect: the lower of the setting and the automatic level.
function VfxQuality.Effective(state: State): Level
	return VfxQuality.ORDER[math.max(index(state.Setting), index(state.Auto))]
end

function VfxQuality.SetSetting(state: State, setting: Level)
	state.Setting = setting
	if index(state.Auto) < index(setting) then
		state.Auto = setting
	end
	state.SlowFor = 0
	state.FastFor = 0
end

-- Feeds one frame's duration. Returns true when the effective level changed.
function VfxQuality.Observe(state: State, dt: number): boolean
	if dt ~= dt or dt <= 0 or dt > 1 then
		return false -- ignore pauses, hitches from loading and bad input
	end
	local before = VfxQuality.Effective(state)
	state.FrameTime += (dt - state.FrameTime) * VfxQuality.SMOOTHING
	if state.FrameTime > VfxQuality.SLOW_FRAME then
		state.SlowFor += dt
		state.FastFor = 0
		if state.SlowFor >= VfxQuality.SLOW_HOLD then
			state.SlowFor = 0
			local current = index(VfxQuality.Effective(state))
			state.Auto = VfxQuality.ORDER[math.min(#VfxQuality.ORDER, current + 1)]
		end
	elseif state.FrameTime < VfxQuality.FAST_FRAME then
		state.FastFor += dt
		state.SlowFor = 0
		if state.FastFor >= VfxQuality.FAST_HOLD then
			state.FastFor = 0
			state.Auto = VfxQuality.ORDER[math.max(index(state.Setting), index(state.Auto) - 1)]
		end
	else
		state.SlowFor = 0
		state.FastFor = 0
	end
	return VfxQuality.Effective(state) ~= before
end

function VfxQuality.Detail(state: State): number
	return VfxQuality.LEVELS[VfxQuality.Effective(state)].Detail
end

function VfxQuality.MaxEffects(state: State): number
	return VfxQuality.LEVELS[VfxQuality.Effective(state)].MaxEffects
end

-- How many of `count` items to draw at this detail (at least one when count >= 1).
function VfxQuality.Scale(count: number, detail: number): number
	if count <= 0 then
		return 0
	end
	return math.max(1, math.round(count * detail))
end

return table.freeze(VfxQuality)
