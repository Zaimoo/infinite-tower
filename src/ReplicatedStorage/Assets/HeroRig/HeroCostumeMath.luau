--!strict
-- ReplicatedStorage/Assets/HeroRig/HeroCostumeMath.luau
-- Pure math shared by HeroCostumeBuilder (in Roblox) and the costume lint (offline tests).
-- Resolves each costume piece to bone space, scaled to the hero's body type, without
-- using CFrame or Vector3 so the offline Luau runner can evaluate it too.

local HeroRigSpec = require(script.Parent:WaitForChild("HeroRigSpec"))

export type Vec3 = { number }
export type Mat3 = { number } -- row-major 3x3

export type MeshSpec = {
	MeshId: string, -- must be listed in HeroCostumes.MESHES
	TextureId: string?, -- omitted: the mesh takes the piece Color
	Scale: Vec3, -- SpecialMesh.Scale (FileMesh renders at its native size times this)
}

export type Piece = {
	Name: string,
	Bone: string,
	Shape: string?, -- "Block" (default) | "Wedge" | "Ball" | "Cylinder"
	Size: Vec3,
	Position: Vec3, -- bone space (or RelativeTo piece space)
	Rotation: Vec3?, -- degrees, CFrame.Angles order
	Color: Vec3, -- 0..255
	Material: string?, -- Enum.Material name, default SmoothPlastic
	RelativeTo: string?, -- earlier piece on the same bone
	Loose: boolean?, -- cloth or hair that may clip a neighbouring bone (skirts, capes, braids)
	Mesh: MeshSpec?, -- renders a FileMesh instead of the Part shape; Size stays the lint bounds
}

export type ResolvedPiece = {
	Piece: Piece,
	Position: Vec3, -- bone space, after body-type scaling
	Rotation: Mat3, -- bone space
	Size: Vec3, -- after body-type scaling
	MeshScale: Vec3?, -- piece.Mesh.Scale after head scaling
}

local M = {}

local function rotationMatrix(degrees: Vec3?): Mat3
	local d = degrees or { 0, 0, 0 }
	local x, y, z = math.rad(d[1]), math.rad(d[2]), math.rad(d[3])
	local cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
	-- CFrame.Angles(x, y, z) = Rx * Ry * Rz
	return {
		cy * cz, -cy * sz, sy,
		cx * sz + sx * sy * cz, cx * cz - sx * sy * sz, -sx * cy,
		sx * sz - cx * sy * cz, sx * cz + cx * sy * sz, cx * cy,
	}
end
M.RotationMatrix = rotationMatrix

function M.Multiply(a: Mat3, b: Mat3): Mat3
	local r = table.create(9, 0)
	for i = 0, 2 do
		for j = 0, 2 do
			r[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[j + 4] + a[i * 3 + 3] * b[j + 7]
		end
	end
	return r
end

function M.Apply(m: Mat3, v: Vec3): Vec3
	return {
		m[1] * v[1] + m[2] * v[2] + m[3] * v[3],
		m[4] * v[1] + m[5] * v[2] + m[6] * v[3],
		m[7] * v[1] + m[8] * v[2] + m[9] * v[3],
	}
end

-- Pieces are authored against the Standard body. On other body types they keep their
-- height but scale horizontally with the bone they sit on.
function M.BoneScale(layout: HeroRigSpec.Layout, standard: HeroRigSpec.Layout, bone: string): (number, number)
	local size, base = layout.Parts[bone].Size, standard.Parts[bone].Size
	return size[1] / base[1], size[3] / base[3]
end

-- Head pieces are authored for a HEAD_AUTHORED_SIZE head and scale uniformly (all three
-- axes, positions, sizes and mesh scales) with the actual head.
function M.HeadScale(layout: HeroRigSpec.Layout): number
	return layout.Parts.Head.Size[2] / HeroRigSpec.HEAD_AUTHORED_SIZE
end

-- Bone-space placement of every piece, in authoring order. Errors on a RelativeTo that
-- does not name an earlier piece on the same bone.
function M.Resolve(pieces: { Piece }, layout: HeroRigSpec.Layout): { ResolvedPiece }
	local standard = HeroRigSpec.Layout("Standard")
	local headScale = M.HeadScale(layout)
	local byName: { [string]: ResolvedPiece } = {}
	local resolved: { ResolvedPiece } = {}
	for _, piece in pieces do
		local k = if piece.Bone == "Head" then headScale else 1
		local localRotation = rotationMatrix(piece.Rotation)
		local position: Vec3
		local rotation: Mat3
		if piece.RelativeTo then
			local parent = byName[piece.RelativeTo]
			assert(parent and parent.Piece.Bone == piece.Bone, `Costume piece {piece.Name}: RelativeTo {piece.RelativeTo} must be an earlier piece on {piece.Bone}`)
			local offset = M.Apply(parent.Rotation, { piece.Position[1] * k, piece.Position[2] * k, piece.Position[3] * k })
			position = { parent.Position[1] + offset[1], parent.Position[2] + offset[2], parent.Position[3] + offset[3] }
			rotation = M.Multiply(parent.Rotation, localRotation)
		else
			local sx, sz = M.BoneScale(layout, standard, piece.Bone)
			position = { piece.Position[1] * sx * k, piece.Position[2] * k, piece.Position[3] * sz * k }
			rotation = localRotation
		end
		local sx, sz = M.BoneScale(layout, standard, piece.Bone)
		local horizontal = (sx + sz) / 2
		local mesh = piece.Mesh
		local entry: ResolvedPiece = {
			Piece = piece,
			Position = position,
			Rotation = rotation,
			Size = { piece.Size[1] * horizontal * k, piece.Size[2] * k, piece.Size[3] * horizontal * k },
			MeshScale = if mesh then { mesh.Scale[1] * k, mesh.Scale[2] * k, mesh.Scale[3] * k } else nil,
		}
		byName[piece.Name] = entry
		table.insert(resolved, entry)
	end
	return resolved
end

-- Exact overlap test between a resolved piece (an oriented box) and an axis-aligned box,
-- both in root space, using the separating axis theorem.
function M.OverlapsAabb(entry: ResolvedPiece, boneCenter: Vec3, aabbCenter: Vec3, aabbHalf: Vec3): boolean
	local r = entry.Rotation
	local axes = { { r[1], r[4], r[7] }, { r[2], r[5], r[8] }, { r[3], r[6], r[9] } } -- piece axes (columns)
	local h = { entry.Size[1] / 2, entry.Size[2] / 2, entry.Size[3] / 2 }
	local t = {
		boneCenter[1] + entry.Position[1] - aabbCenter[1],
		boneCenter[2] + entry.Position[2] - aabbCenter[2],
		boneCenter[3] + entry.Position[3] - aabbCenter[3],
	}
	local function dot(a: Vec3, b: Vec3): number
		return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
	end
	local function separated(axis: Vec3): boolean
		local len = math.sqrt(dot(axis, axis))
		if len < 1e-9 then
			return false
		end
		local projPiece = 0
		for i = 1, 3 do
			projPiece += h[i] * math.abs(dot(axes[i], axis))
		end
		local projBox = aabbHalf[1] * math.abs(axis[1]) + aabbHalf[2] * math.abs(axis[2]) + aabbHalf[3] * math.abs(axis[3])
		return math.abs(dot(t, axis)) > projPiece + projBox
	end
	local world = { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }
	for _, axis in world do
		if separated(axis) then return false end
	end
	for _, axis in axes do
		if separated(axis) then return false end
	end
	for _, a in world do
		for _, b in axes do
			local cross = { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
			if separated(cross) then return false end
		end
	end
	return true
end

return table.freeze(M)
