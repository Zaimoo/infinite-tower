--!strict
-- Abyssal Throne floors (46-50): which placed set pieces are walk-through decor and which stay solid.
--
-- A prop that survives the build's clearance pass doesn't stand on a walkway (TowerRoomBuilder.WalkwayHitTest
-- removes scenery on a lane "solid or not"), so solid props never block a route. Only these stay ghosts:
-- overhead, sky and far-layer dressing, glow and liquid effects, hanging chains and lamps, the cages and chains
-- built round a walkway on purpose, and small clutter a player would otherwise snag on.
local AbyssalCollision = {}

-- Prop kinds (the group's PropKind or name, or a kit template inside it) that stay walk-through, matched as
-- plain substrings. ("GroundCover" and "Cover_", not "Cover": a covert-way palisade is a wall.)
local GHOST_KINDS = table.freeze({
	"Undertow", "Upfall", "Eclipse", "Sky", "Silhouette", "Ribbon", "Glow", "Mist", "Banner", "Wardlight",
	"Lantern", "Overhead", "Hanging", "ThroneCrown", "GroundCover", "Cover_", "Inlay", "Wound", "Horizon", "RoseWindow",
	"VaultRib", "Skirt", "ChainFordSub", "ChainClimb", "MantleChain", "GreatChain", "ChasmChain", "Detail",
})

-- Kinds TowerRoomBuilder.WalkwayExemptKinds lets stand on a walkway (gates over a path, chains and cages round
-- a span, floor inlays, moat rings and retaining aprons under a lane). They are allowed there only because they
-- don't block it, so they always stay walk-through. Keep in step with WalkwayExemptKinds.
AbyssalCollision.LaneKinds = table.freeze({
	AbyssalVaultDome = true, AbyssalUndertow = true, AbyssalUpfall = true, AbyssalEclipse = true,
	AbyssalGreatChain = true, AbyssalGateArch = true, AbyssalFloorInlay = true, AbyssalWardlight = true,
	AbyssalEffigySpan = true, AbyssalChainCage = true, DirgeUndertowBed = true, EyotOutcropBay = true,
	PaleRiftWound = true, BlackVaultRiftSlit = true, CrossingOathsInlay = true, DirgeFarSilhouettes = true,
	DirgeUndertowMoat = true, VahlLandmarkBays = true, AbyssalSkyVault = true, AbyssalVoidFloor = true,
	AbyssalSkyHorizon = true, DreadguardKeepMound = true, KeepAnchorChains = true, StarFortRetainingAprons = true,
	UndertowMoatRing = true, AbyssalUndertowBed = true, ThroneSilverKey = true,
})

-- Anything smaller than this on every axis is clutter, not an obstacle.
AbyssalCollision.ClutterSize = 3.5

function AbyssalCollision.IsGhostKind(kind: string): boolean
	if AbyssalCollision.LaneKinds[kind] then
		return true
	end
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
	-- A generic group ("CitadelScatter") is judged by the kit template it places: a hanging chain is still a ghost.
	for _, d in prop:GetDescendants() do
		local template = d:GetAttribute("KitTemplate") :: string?
		if template and AbyssalCollision.IsGhostKind(template) then
			return false
		end
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
