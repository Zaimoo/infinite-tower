--!strict
-- ReplicatedStorage/Assets/LeaderboardMeshData.luau
-- Decodes Blender-authored monument geometry shards from ReplicatedStorage.Assets.LeaderboardMeshes.

local LeaderboardMeshData = {}

export type PartMeshSpec = {
	Name: string,
	SubCollection: string,
	Offset: Vector3,
	Size: Vector3,
	Material: Enum.Material,
	Color: Color3,
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
	local len = #str
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
	local tris = table.create(nBytes // 2)
	for off = 0, nBytes - 2, 2 do
		tris[#tris + 1] = buffer.readu16(buf, off)
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

function LeaderboardMeshData.GetGeometry(spec: PartMeshSpec): ({ number }, { number })
	if not spec.Verts then
		spec.Verts = if spec.VB then unpackVerts(spec.VB, spec.Size) else {}
	end
	if not spec.Tris then
		spec.Tris = if spec.TB then unpackTris(spec.TB) else {}
	end
	return spec.Verts :: { number }, spec.Tris :: { number }
end

local MeshesFolder = (script.Parent :: Instance):WaitForChild("LeaderboardMeshes")

LeaderboardMeshData.Models = {
	leaderboard_pediment_frame = unpackModel(MeshesFolder:WaitForChild("leaderboard_pediment_frame")),
	leaderboard_power_monolith = unpackModel(MeshesFolder:WaitForChild("leaderboard_power_monolith"))
} :: { [string]: { PartMeshSpec } }

return LeaderboardMeshData
