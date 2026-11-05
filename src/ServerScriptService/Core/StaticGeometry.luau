--!strict
-- ServerScriptService/Core/StaticGeometry.luau
-- One pass over freshly built scenery (hub, plot buildings, tower rooms) that turns off engine work
-- the scenery never needs:
--   * CanTouch = false on anchored parts. Nothing listens for Touched on scenery, but every part a
--     character walks over still costs touch-pair bookkeeping. Parts that do use Touched (the hub kill
--     zone, traversal pads, loot drops) carry the NeedsTouch attribute and are skipped, as are SpawnLocations.
--   * CastShadow = false on small anchored parts (trim, studs, rivets, leaves), whose shadows are a few
--     pixels but each one is another shadow caster.
-- CanCollide and CanQuery are left alone: floors, walls and navigation raycasts depend on them.

local StaticGeometry = {}

StaticGeometry.NEEDS_TOUCH_ATTRIBUTE = "NeedsTouch"
-- A part whose largest side is at most this many studs stops casting a shadow.
StaticGeometry.SMALL_PART_MAX_SIZE = 1.5

export type Stats = { Parts: number, TouchOff: number, ShadowOff: number }

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
	local stats: Stats = { Parts = 0, TouchOff = 0, ShadowOff = 0 }
	if root:IsA("BasePart") then
		applyPart(root, stats)
	end
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			applyPart(d, stats)
		end
	end
	return stats
end

-- For parts that connect Touched: tag them so Apply leaves them alone, and make sure touch is on.
function StaticGeometry.MarkNeedsTouch(part: BasePart)
	part:SetAttribute(StaticGeometry.NEEDS_TOUCH_ATTRIBUTE, true)
	part.CanTouch = true
end

return StaticGeometry
