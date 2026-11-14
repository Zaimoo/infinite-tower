--!strict
-- ReplicatedStorage/Assets/GildedAnvilMeshData.luau
-- Decodes Blender FBX geometry shards from ReplicatedStorage.Assets.GildedAnvilMeshes.

local GildedAnvilMeshData = {}

export type PartMeshSpec = {
	Name: string,
	SubCollection: string,
	Offset: Vector3,
	RotDeg: Vector3,
	Size: Vector3,
	PivotOffset: Vector3,
	Material: Enum.Material,
	Color: Color3,
	Transparency: number,
	AnimRole: string?,
	DoubleSided: boolean,
	MeshId: string,
	-- Packed fallback geometry, decoded on demand by GetGeometry (only needed when MeshId is empty or fails to load).
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

local function decodeBase64(b64: string): buffer
	local len = #b64
	if len == 0 then
		return buffer.create(0)
	end
	local pad = 0
	if string.byte(b64, len) == 61 then
		pad += 1
		if len >= 2 and string.byte(b64, len - 1) == 61 then
			pad += 1
		end
	end
	local outLen = (len // 4) * 3 - pad
	local buf = buffer.create(outLen)
	local outPos = 0
	for i = 1, len, 4 do
		local c0 = B64_LOOKUP[string.byte(b64, i)]
		local c1 = B64_LOOKUP[string.byte(b64, i + 1)]
		local b2 = string.byte(b64, i + 2)
		local b3 = string.byte(b64, i + 3)
		local c2 = if b2 == 61 then 0 else B64_LOOKUP[b2]
		local c3 = if b3 == 61 then 0 else B64_LOOKUP[b3]
		local bits = bit32.bor(
			bit32.lshift(c0, 18),
			bit32.lshift(c1, 12),
			bit32.lshift(c2, 6),
			c3
		)
		if outPos < outLen then
			buffer.writeu8(buf, outPos, bit32.rshift(bits, 16))
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
	local tris = table.create(nBytes // 2)
	for off = 0, nBytes - 2, 2 do
		tris[#tris + 1] = buffer.readu16(buf, off)
	end
	return tris
end

local function unpackWeapon(shardModule: Instance): { PartMeshSpec }
	local rawList = require(shardModule :: ModuleScript) :: { any }
	local unpacked = table.create(#rawList)
	for _, raw in ipairs(rawList) do
		unpacked[#unpacked + 1] = {
			Name = raw.Name,
			SubCollection = raw.SubCollection,
			Offset = raw.Offset,
			RotDeg = raw.RotDeg,
			Size = raw.Size,
			PivotOffset = raw.PivotOffset,
			Material = raw.Material,
			Color = raw.Color,
			Transparency = raw.Transparency,
			AnimRole = raw.AnimRole,
			DoubleSided = raw.DoubleSided,
			MeshId = raw.MeshId or "",
			VB = raw.VB,
			TB = raw.TB,
			Verts = raw.Verts,
			Tris = raw.Tris,
		}
	end
	return unpacked
end

-- Returns the part's vertex and triangle lists, decoding the packed shard data the first time.
-- Parts with an uploaded MeshId never need this, so the decode cost is only paid on the fallback path.
function GildedAnvilMeshData.GetGeometry(spec: PartMeshSpec): ({ number }, { number })
	if not spec.Verts then
		spec.Verts = if spec.VB then unpackVerts(spec.VB, spec.Size) else {}
	end
	if not spec.Tris then
		spec.Tris = if spec.TB then unpackTris(spec.TB) else {}
	end
	return spec.Verts :: { number }, spec.Tris :: { number }
end

local MeshesFolder = (script.Parent :: Instance):WaitForChild("GildedAnvilMeshes")

GildedAnvilMeshData.Weapons = {
	art_gild_dawnwarden_oath = unpackWeapon(MeshesFolder:WaitForChild("art_gild_dawnwarden_oath")),
	art_gild_eclipse_sisters = unpackWeapon(MeshesFolder:WaitForChild("art_gild_eclipse_sisters")),
} :: { [string]: { PartMeshSpec } }

return GildedAnvilMeshData
