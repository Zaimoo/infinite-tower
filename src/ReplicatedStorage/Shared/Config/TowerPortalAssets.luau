--!strict
-- The tower portal mesh (Phase H), modelled in Blender: assets-source/tower/portal/TowerPortal.blend,
-- exported as TowerPortal.fbx. It is four meshes so each can take its own colour and material:
-- the stone frame, the gold trim, the glowing runes and the vortex disc.
--
-- Size and Offset are in studs at Scale 1, in Roblox axes (Y up, Z through the ring), measured from
-- the centre of the plinth's base. MeshId and MeshSize come from the FBX imported into Studio
-- (MeshSize is the imported MeshPart's MeshSize; the vortex is flat, so its depth is 0). With any
-- MeshId empty, TowerPortalKit builds the same design from parts instead.

export type Piece = {
	Name: string,
	Role: "STONE" | "GOLD" | "RUNES" | "VORTEX",
	Size: Vector3,
	Offset: Vector3,
	MeshId: string,
	MeshSize: Vector3?,
}

local Assets = {}

Assets.Pieces = table.freeze({
	table.freeze({ Name = "PortalFrameStone", Role = "STONE", Size = Vector3.new(13.1, 11.95, 3.4), Offset = Vector3.new(0, 5.98, 0), MeshId = "rbxassetid://74784237491355", MeshSize = Vector3.new(13.1, 11.951435, 3.4) }),
	table.freeze({ Name = "PortalTrimGold", Role = "GOLD", Size = Vector3.new(12.33, 13.03, 2.9), Offset = Vector3.new(0, 6.44, 0), MeshId = "rbxassetid://118243986389048", MeshSize = Vector3.new(12.327696, 13.034998, 2.9) }),
	table.freeze({ Name = "PortalRunes", Role = "RUNES", Size = Vector3.new(10.56, 10.4, 1.49), Offset = Vector3.new(0, 5.85, 0), MeshId = "rbxassetid://134496955560925", MeshSize = Vector3.new(10.558281, 10.397877, 1.49) }),
	table.freeze({ Name = "PortalVortex", Role = "VORTEX", Size = Vector3.new(8.4, 8.4, 0.05), Offset = Vector3.new(0, 6, 0), MeshId = "rbxassetid://94952284993866", MeshSize = Vector3.new(8.4, 8.4, 0) }),
}) :: { Piece }

-- Ring geometry at Scale 1, shared by the part-built fallback and the trigger volume.
Assets.RingRadius = 5
Assets.RingCentreY = 6
Assets.Height = 13.03
Assets.Width = 13.1

-- Portal sizes in play: the four Sanctuary travel portals, spaced SanctuarySpacing apart, and the two
-- boss portals at the back of the Apex.
Assets.SanctuaryScale = 1.2
Assets.SanctuarySpacing = 24
Assets.BossScale = 1.3

function Assets.HasMeshes(): boolean
	for _, piece in Assets.Pieces do
		if piece.MeshId == "" or piece.MeshSize == nil then return false end
	end
	return true
end

return table.freeze(Assets)
