--!strict
-- The hub Raid Portal mesh (docs/raid-boss-plan.md §6), modelled in Blender by
-- tools/blender/generate_raid_assets.py: assets/models/raid/portal/RaidPortal.fbx (+ RaidPortal.json).
-- Four pieces: Frame (palette-textured), Runes (Neon; the brazier fire is a separate orange piece),
-- Vortex (Neon) and Shards (Neon, spun by the client about ShardPivot).
--
-- Offset and Size are in studs at Scale 1, Roblox axes, from the centre of the dais's base; the model
-- faces -Z. Fill MeshId (and TextureId for the Frame) after importing the FBX into Studio. With any
-- MeshId empty, RaidPortalKit builds a part version of the same design instead.

export type Piece = {
	Name: string,
	Role: "FRAME" | "RUNES" | "FIRE" | "VORTEX" | "SHARDS",
	Size: Vector3,
	Offset: Vector3,
	MeshId: string,
	TextureId: string?,
}

local Assets = {}

Assets.Pieces = table.freeze({
	table.freeze({ Name = "RaidPortal_Frame", Role = "FRAME", Size = Vector3.new(34.0, 32.1, 28.862), Offset = Vector3.new(0, 16.05, 0), MeshId = "rbxassetid://99953523991468", TextureId = "rbxassetid://74173858139235" }),
	table.freeze({ Name = "RaidPortal_Runes_Glow_Crimson", Role = "RUNES", Size = Vector3.new(31.869, 26.902, 24.398), Offset = Vector3.new(0, 14.311, -1.351), MeshId = "rbxassetid://90248669037666" }),
	table.freeze({ Name = "RaidPortal_Runes_Glow_Orange", Role = "FIRE", Size = Vector3.new(17.442, 3.4, 2.186), Offset = Vector3.new(0, 7.4, -6.457), MeshId = "rbxassetid://101660112092589" }),
	table.freeze({ Name = "RaidPortal_Vortex", Role = "VORTEX", Size = Vector3.new(15.5, 22.472, 0.7), Offset = Vector3.new(0, 13.636, -0.2), MeshId = "rbxassetid://74986541919658" }),
	table.freeze({ Name = "RaidPortal_Shards", Role = "SHARDS", Size = Vector3.new(30.776, 25.766, 5.716), Offset = Vector3.new(0.17, 16.957, 0.072), MeshId = "rbxassetid://114563862060461" }),
}) :: { Piece }

-- Arch geometry at Scale 1 (from the Blender generator), shared by the part fallback and the trigger.
Assets.DaisTop = 2.4
Assets.ArchHalfSpan = 9.5 -- centreline of the arch legs
Assets.Spring = 12.5
Assets.ArchRadius = 15.5
Assets.Apex = 26.79
Assets.ShardPivot = Vector3.new(0, 15.5, 0)
Assets.TriggerSize = Vector3.new(14, 20, 6)
Assets.TriggerOffset = Vector3.new(0, 12.4, 0)

function Assets.HasMeshes(): boolean
	for _, piece in Assets.Pieces do
		if piece.MeshId == "" then return false end
	end
	return true
end

return table.freeze(Assets)
