--!strict
-- MeshPart templates for the raid meshes. Scripts can't set MeshPart.MeshId, so each mesh is created once
-- with AssetService:CreateMeshPartAsync (which yields) and cloned from then on. Preload ahead of need;
-- Get returns nil for a mesh that isn't loaded yet, so callers can fall back to a stand-in.
local AssetService = game:GetService("AssetService")

local Cache = {}

-- Studio's FBX importer turns every raid mesh 180° about Y inside its own frame (verified in Studio
-- 2026-11-08), so placements apply this to face the meshes the way the Blender metadata assumes.
Cache.MeshRotation = CFrame.Angles(0, math.pi, 0)

local templates: { [string]: MeshPart } = {}
local pending: { [string]: boolean } = {}
local failed: { [string]: boolean } = {}

local function create(meshId: string): MeshPart?
	local ok, part = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromUri(meshId))
	end)
	if not ok then
		ok, part = pcall(function()
			return (AssetService :: any):CreateMeshPartAsync(meshId)
		end)
	end
	return if ok then part :: MeshPart else nil
end

-- Load one mesh (yields). Safe to call repeatedly.
function Cache.Load(meshId: string): boolean
	if meshId == "" then return false end
	if templates[meshId] then return true end
	if failed[meshId] then return false end
	while pending[meshId] do task.wait() end
	if templates[meshId] then return true end
	pending[meshId] = true
	local part = create(meshId)
	pending[meshId] = nil
	if part then
		part.Anchored = false
		templates[meshId] = part
		return true
	end
	failed[meshId] = true
	warn("[RaidMeshCache] could not load " .. meshId)
	return false
end

-- Load many meshes in parallel (yields until all are done). Returns true when every one loaded.
function Cache.LoadAll(meshIds: { string }): boolean
	local left = #meshIds
	local allOk = true
	for _, id in meshIds do
		task.spawn(function()
			if not Cache.Load(id) then allOk = false end
			left -= 1
		end)
	end
	while left > 0 do task.wait() end
	return allOk
end

function Cache.Has(meshId: string): boolean
	return templates[meshId] ~= nil
end

-- A fresh MeshPart for a loaded mesh, or nil.
function Cache.Get(meshId: string): MeshPart?
	local t = templates[meshId]
	return if t then t:Clone() else nil
end

return Cache
