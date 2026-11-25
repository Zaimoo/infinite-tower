--!strict
-- Abyssal Throne floors (46-50): which placed set pieces are walk-through decor and which stay solid.
--
-- A prop that survives the build's clearance pass doesn't stand on a walkway (TowerRoomBuilder.WalkwayHitTest
-- removes scenery on a lane "solid or not"), so solid props never block a route. Only these stay ghosts:
-- overhead, sky and far-layer dressing, glow and liquid effects, hanging chains and lamps, the cages and chains
-- built round a walkway on purpose, and small clutter a player would otherwise snag on.
local AbyssalCollision = {}

-- Prop kinds (the group's PropKind, or its name) that stay walk-through, matched as plain substrings.
local GHOST_KINDS = table.freeze({
	"Undertow", "Upfall", "Eclipse", "Sky", "Silhouette", "Ribbon", "Glow", "Mist", "Banner", "Wardlight",
	"Lantern", "Overhead", "Hanging", "Crown", "Cover", "Inlay", "Wound", "Horizon", "RoseWindow", "VaultRib",
	"Skirt", "Scatter", "ChainFordSub", "ChainClimb", "MantleChain", "GreatChain", "ChasmChain", "Detail",
})

-- Anything smaller than this on every axis is clutter, not an obstacle.
AbyssalCollision.ClutterSize = 3.5

function AbyssalCollision.IsGhostKind(kind: string): boolean
	for _, word in GHOST_KINDS do
		if string.find(kind, word, 1, true) then
			return true
		end
	end
	return false
end

-- True when a placed prop (a Model group, or a lone part) should keep its collision.
function AbyssalCollision.StaysSolid(prop: Instance): boolean
	local kind = (prop:GetAttribute("PropKind") :: string?) or prop.Name
	if AbyssalCollision.IsGhostKind(kind) then
		return false
	end
	local size: Vector3
	if prop:IsA("Model") then
		if not prop:FindFirstChildWhichIsA("BasePart", true) then
			return false
		end
		local _, extents = prop:GetBoundingBox()
		size = extents
	elseif prop:IsA("BasePart") then
		size = prop.Size
	else
		return false
	end
	return math.max(size.X, size.Y, size.Z) >= AbyssalCollision.ClutterSize
end

return table.freeze(AbyssalCollision)
