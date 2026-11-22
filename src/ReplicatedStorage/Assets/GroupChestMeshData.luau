--!strict
-- ReplicatedStorage/Assets/GroupChestMeshData.luau
-- Decodes Blender-authored Group Chest geometry shards from ReplicatedStorage.Assets.GroupChestMeshes.

local GroupChestMeshData = {}

GroupChestMeshData.HingePivot = Vector3.new(0.0, 2.85, 2.15)

export type PartMeshSpec = {
	Name: string,
	SubCollection: string,
	Offset: Vector3,
	Size: Vector3,
	Material: Enum.Material,
	Color: Color3,
	Transparency: number,
	Collidable: boolean,
	MeshId: string,
	VB: string?,
	TB: string?,
	Verts: { number }?,
	Tris: { number }?,
}

local B64_LOOKUP = table.create(256, -1)
do
	local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	for i = 1, #alphabet do
		B64_LOOKUP[string.byte(alphabet, i)] = i - 1
	end
end

local function decodeBase64(str: string): buffer
	str = string.gsub(str, "%s+", "")
	local len = #str
	if len == 0 then
		return buffer.create(0)
	end
	local pad = if len >= 2 and string.sub(str, len - 1, len) == "==" then 2 elseif len >= 1 and string.sub(str, len, len) == "=" then 1 else 0
	local outLen = (len // 4) * 3 - pad
	local buf = buffer.create(outLen)
	local outPos = 0
	for i = 1, len, 4 do
		local a = B64_LOOKUP[string.byte(str, i)] or 0
		local b = B64_LOOKUP[string.byte(str, i + 1)] or 0
		local c = B64_LOOKUP[string.byte(str, i + 2)]
		local d = B64_LOOKUP[string.byte(str, i + 3)]
		local bits = bit32.lshift(a, 18) + bit32.lshift(b, 12) + bit32.lshift(if c and c >= 0 then c else 0, 6) + (if d and d >= 0 then d else 0)
		if outPos < outLen then
			buffer.writeu8(buf, outPos, bit32.band(bit32.rshift(bits, 16), 255))
			outPos += 1
		end
		if outPos < outLen then
			buffer.writeu8(buf, outPos, bit32.band(bit32.rshift(bits, 8), 255))
			outPos += 1
		end
		if outPos < outLen then
			buffer.writeu8(buf, outPos, bit32.band(bits, 255))
			outPos += 1
		end
	end
	return buf
end

local function unpackVerts(vb: string, size: Vector3): { number }
	local buf = decodeBase64(vb)
	local nBytes = buffer.len(buf)
	local verts = table.create(nBytes // 2)
	local hx = math.max(1e-5, size.X * 0.5) / 32767
	local hy = math.max(1e-5, size.Y * 0.5) / 32767
	local hz = math.max(1e-5, size.Z * 0.5) / 32767
	for off = 0, nBytes - 6, 6 do
		verts[#verts + 1] = buffer.readi16(buf, off) * hx
		verts[#verts + 1] = buffer.readi16(buf, off + 2) * hy
		verts[#verts + 1] = buffer.readi16(buf, off + 4) * hz
	end
	return verts
end

local function unpackTris(tb: string): { number }
	local buf = decodeBase64(tb)
	local nBytes = buffer.len(buf)
	local tris = {}
	local prev = 0
	local pos = 0
	while pos < nBytes do
		local zz = 0
		local shift = 0
		while pos < nBytes do
			local b = buffer.readu8(buf, pos)
			pos += 1
			zz += bit32.lshift(bit32.band(b, 127), shift)
			if b < 128 then
				break
			end
			shift += 7
		end
		local d = if bit32.band(zz, 1) == 0 then bit32.rshift(zz, 1) else -bit32.rshift(zz + 1, 1)
		prev += d
		tris[#tris + 1] = prev
	end
	return tris
end

local function unpackModel(shardModule: Instance): { PartMeshSpec }
	local rawList = require(shardModule :: ModuleScript) :: { any }
	local unpacked = table.create(#rawList)
	for _, raw in ipairs(rawList) do
		unpacked[#unpacked + 1] = {
			Name = raw.Name,
			SubCollection = raw.SubCollection,
			Offset = raw.Offset,
			Size = raw.Size,
			Material = raw.Material,
			Color = raw.Color,
			Transparency = raw.Transparency or 0,
			Collidable = raw.Collidable,
			MeshId = raw.MeshId or "",
			VB = raw.VB,
			TB = raw.TB,
			Verts = raw.Verts,
			Tris = raw.Tris,
		}
	end
	return unpacked
end

function GroupChestMeshData.GetGeometry(spec: PartMeshSpec): ({ number }, { number })
	if not spec.Verts then
		spec.Verts = if spec.VB then unpackVerts(spec.VB, spec.Size) else {}
	end
	if not spec.Tris then
		spec.Tris = if spec.TB then unpackTris(spec.TB) else {}
	end
	return spec.Verts :: { number }, spec.Tris :: { number }
end

local MeshesFolder = (script.Parent :: Instance):WaitForChild("GroupChestMeshes")

GroupChestMeshData.Models = {
	group_chest = unpackModel(MeshesFolder:WaitForChild("group_chest")),
} :: { [string]: { PartMeshSpec } }

return GroupChestMeshData
