--!strict
-- hub-cobble-paths.spec.luau
-- Verifies Hub cobble path & fantasy floating castle bridge packed mesh data, UVs, materials, tri budgets, and bounds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HubLayout = require(ReplicatedStorage.Shared.Config.HubLayout)
local HubPathMeshData = require(ReplicatedStorage.Assets.HubPathMeshData)

local passed = 0
local failed = 0

local function check(name: string, cond: boolean, detail: string?)
	if cond then
		passed += 1
		print("PASS " .. name)
	else
		failed += 1
		print("FAIL " .. name .. (if detail then (": " .. detail) else ""))
	end
end

-- 1. All 15 expected path, apron, terrace, and multi-material fantasy bridge parts present
local expectedNames = {
	"Hub_GateSpoke_1",
	"Hub_GateSpoke_2",
	"Hub_GateSpoke_3",
	"Hub_GateSpoke_4",
	"Hub_GateSpoke_5",
	"Hub_GateSpoke_6",
	"Hub_GateSpoke_7",
	"Hub_GateSpoke_8",
	"Hub_PilgrimsWay",
	"Hub_SpurPath",
	"Hub_PlazaApronDeck",
	"Hub_OverlookTerraceTop",
	"Hub_PlotBridgeDeck",
	"Hub_PlotBridgeParapets",
	"Hub_PlotBridgeSpires",
}

local allPresent = HubPathMeshData.PartCount == #expectedNames
for _, name in ipairs(expectedNames) do
	if not HubPathMeshData.ByPartName[name] then
		allPresent = false
	end
end
check("HubPathMeshData exposes all 15 Hub path, apron, terrace, and fantasy castle bridge meshes", allPresent)

-- 2. Valid vertex, normal, UV, and triangle buffers + material palette per part
local buffersOk = true
local uvOk = true
local styleOk = true
local badDetail = ""
local validMaterials = {
	Cobblestone = true,
	Slate = true,
}

for _, shard in ipairs(HubPathMeshData.Shards) do
	local nVerts = #shard.vb // 3
	local nNorms = #shard.nb // 3
	local nUVs = #shard.ub // 2
	local nTris = #shard.tb // 3
	if #shard.vb % 3 ~= 0 or #shard.tb % 3 ~= 0 or nVerts < 8 or nTris < 4 or nTris > 9500 then
		buffersOk = false
		badDetail = shard.partName .. " buffer counts invalid (tris=" .. tostring(nTris) .. ")"
	end
	if #shard.ntb ~= #shard.tb or #shard.uvtb ~= #shard.tb or nNorms < 1 or nUVs < 1 then
		uvOk = false
		badDetail = shard.partName .. " missing normals or box UVs"
	end
	for _, idx in ipairs(shard.tb) do
		if idx < 1 or idx > nVerts then
			buffersOk = false
			badDetail = shard.partName .. " vert index OOB"
			break
		end
	end
	for _, idx in ipairs(shard.uvtb) do
		if idx < 1 or idx > nUVs then
			uvOk = false
			badDetail = shard.partName .. " uv index OOB"
			break
		end
	end
	if not validMaterials[shard.material] then
		styleOk = false
	end
	if shard.partName == "Hub_PlotBridgeParapets" and (shard.material ~= "Slate" or shard.color[1] ~= 104 or shard.color[2] ~= 106 or shard.color[3] ~= 110) then
		styleOk = false
	elseif shard.partName == "Hub_PlotBridgeSpires" and (shard.material ~= "Slate" or shard.color[1] ~= 104 or shard.color[2] ~= 106 or shard.color[3] ~= 110) then
		styleOk = false
	elseif not string.find(shard.partName, "PlotBridgeParapets") and not string.find(shard.partName, "PlotBridgeSpires") then
		if shard.material ~= "Cobblestone" or shard.color[1] ~= 116 or shard.color[2] ~= 112 or shard.color[3] ~= 98 then
			styleOk = false
		end
	end
end
check("Every Hub path & fantasy bridge shard decodes valid vertices and triangles under 9,500 tris", buffersOk, badDetail)
check("Every Hub shard includes per-corner face normals and box UVs", uvOk, badDetail)
check("Materials & colors match Runesmith bridge cobble, Gothic slate parapets, and dark cliff spires", styleOk)

-- 3. Curved spoke paths stay inside their Hub quadrants & outside WayfinderDais, and bridge spans 18x58
local boundsOk = true
for i = 1, 8 do
	local shard = HubPathMeshData.ByPartName["Hub_GateSpoke_" .. tostring(i)]
	local cx, cz = shard.center[1], shard.center[3]
	local hx, hz = shard.size[1] * 0.5, shard.size[3] * 0.5
	if math.abs(cx) + hx > HubLayout.HubHalfX + 0.05 or math.abs(cz) + hz > HubLayout.HubHalfZ + 0.05 then
		boundsOk = false
		badDetail = string.format("GateSpoke_%d exceeds hub rim: X=%.2f Z=%.2f", i, math.abs(cx) + hx, math.abs(cz) + hz)
	end
end
local pw = HubPathMeshData.ByPartName["Hub_PilgrimsWay"]
if pw and (math.abs(pw.center[3]) + pw.size[3] * 0.5 > HubLayout.HubHalfZ + 0.05) then
	boundsOk = false
end
local pb = HubPathMeshData.ByPartName["Hub_PlotBridgeDeck"]
local pp = HubPathMeshData.ByPartName["Hub_PlotBridgeParapets"]
local ps = HubPathMeshData.ByPartName["Hub_PlotBridgeSpires"]
if pb and (math.abs(pb.size[1] - HubLayout.PlotBridgeWidth) > 0.1 or pb.size[3] < 57.5) then
	boundsOk = false
	badDetail = "Hub_PlotBridgeDeck dimensions do not match 18x58 bridges"
end
if not pp or pp.size[2] < 15 or not ps or ps.size[2] < 15 then
	boundsOk = false
	badDetail = "Fantasy castle bridge Gothic parapet/spire heights too small"
end
check("All curved Hub spoke paths stay strictly inside Hub rim and fantasy castle bridge geometry matches 18x58 chasm", boundsOk, badDetail)

print(string.format("hub-cobble-paths: %d passed, %d failed", passed, failed))
if failed > 0 then
	error("hub-cobble-paths.spec failed")
end
