--!strict
-- ReplicatedStorage/Shared/Util/PreloadManifest.luau
-- What the join loading screen (ReplicatedFirst/LoadingScreen) preloads with ContentProvider:PreloadAsync.
--   Critical: blocks the loading bar. Hero rig templates (HeroCard portraits clone these), weapon
--     templates, hero faces and hair meshes, UI images and sounds, and the HUD that is already built.
--   Background: preloaded after the screen fades. Weapon meshes, raid boss and portal meshes, weapon VFX.
-- ScanIds is pure (tested in tests/preload-manifest.spec.luau); Collect touches the DataModel and is
-- only called on the client after game:IsLoaded().

local PreloadManifest = {}

export type Target = Instance | string
export type Manifest = { Critical: { Target }, Background: { Target } }

-- Instances worth handing to PreloadAsync: they carry a mesh, texture, image, sound or animation.
PreloadManifest.CONTENT_CLASSES = table.freeze({
	"MeshPart", "SpecialMesh", "Decal", "SurfaceAppearance", "Sound", "ImageLabel", "ImageButton",
	"ParticleEmitter", "Beam", "Trail", "Animation", "Shirt", "Pants",
})

local MODULE_WAIT = 10

local function isAssetId(value: string): boolean
	return string.match(value, "^rbxassetid://%d+$") ~= nil
end

-- Walk a config value (tables, nested and frozen alike; keys and values) and append every
-- "rbxassetid://<number>" string to `out`, once. Empty slots and other strings are skipped.
function PreloadManifest.ScanIds(value: any, out: { string }?, seen: { [any]: boolean }?): { string }
	local result = out or {}
	local visited = seen or {}
	local function visit(v: any)
		local t = type(v)
		if t == "string" then
			if isAssetId(v) and not visited[v] then
				visited[v] = true
				table.insert(result, v)
			end
		elseif t == "table" then
			if visited[v] then
				return
			end
			visited[v] = true
			for k, child in v do
				visit(k)
				visit(child)
			end
		end
	end
	visit(value)
	return result
end

-- Descendants of `root` (and root itself) that carry content, appended to `out`.
function PreloadManifest.ContentInstances(root: Instance, out: { Target })
	local function consider(inst: Instance)
		for _, className in PreloadManifest.CONTENT_CLASSES do
			if inst:IsA(className) then
				table.insert(out, inst)
				return
			end
		end
	end
	consider(root)
	for _, inst in root:GetDescendants() do
		consider(inst)
	end
end

local function findPath(root: Instance, path: { string }): Instance?
	local node: Instance? = root
	for _, name in path do
		if not node then
			return nil
		end
		node = node:WaitForChild(name, MODULE_WAIT)
	end
	return node
end

-- Require a module by path and scan its table for asset IDs. A missing or erroring module is skipped.
local function scanModule(root: Instance, path: { string }, out: { string }, seen: { [any]: boolean }, accessor: string?)
	local module = findPath(root, path)
	if not module or not module:IsA("ModuleScript") then
		warn(`[PreloadManifest] missing module {table.concat(path, ".")}`)
		return
	end
	local ok, value = pcall(require, module)
	if not ok then
		warn(`[PreloadManifest] {module:GetFullName()} failed to load: {value}`)
		return
	end
	if accessor then
		local fn = type(value) == "table" and (value :: any)[accessor]
		if type(fn) ~= "function" then
			return
		end
		local okCall, ids = pcall(fn)
		if okCall then
			PreloadManifest.ScanIds(ids, out, seen)
		end
		return
	end
	PreloadManifest.ScanIds(value, out, seen)
end

local function append(out: { Target }, ids: { string })
	for _, id in ids do
		table.insert(out, id)
	end
end

function PreloadManifest.Collect(): Manifest
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local player = Players.LocalPlayer
	local seen: { [any]: boolean } = {}
	local critical: { Target } = {}
	local background: { Target } = {}

	-- Critical instances: hero and weapon templates, then the HUD the controllers have already built.
	local assets = ReplicatedStorage:WaitForChild("Assets", MODULE_WAIT)
	if assets then
		for _, name in { "Heroes", "Weapons" } do
			local folder = assets:WaitForChild(name, MODULE_WAIT)
			if folder then
				PreloadManifest.ContentInstances(folder, critical)
			end
		end
	end
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		for _, gui in playerGui:GetChildren() do
			if gui:IsA("ScreenGui") and not string.find(gui.Name, "^LoadingScreen") then
				PreloadManifest.ContentInstances(gui, critical)
			end
		end
	end

	-- Critical IDs: hero faces and hair meshes, UI art and sounds, settings and nav icons.
	local criticalIds: { string } = {}
	scanModule(ReplicatedStorage, { "Assets", "HeroRig", "HeroCostumes" }, criticalIds, seen)
	scanModule(ReplicatedStorage, { "Shared", "Util", "OrnateFrameButton" }, criticalIds, seen)
	scanModule(ReplicatedStorage, { "Shared", "Util", "GothicVectorIcons" }, criticalIds, seen)
	local playerScripts = player:WaitForChild("PlayerScripts", MODULE_WAIT)
	if playerScripts then
		scanModule(playerScripts, { "UI", "UIAssets" }, criticalIds, seen)
		scanModule(playerScripts, { "UI", "Settings", "SettingsConfig" }, criticalIds, seen)
	end
	append(critical, criticalIds)

	-- Background IDs: everything only needed once a fight, raid or forge preview starts.
	local backgroundIds: { string } = {}
	scanModule(ReplicatedStorage, { "Assets", "WeaponModelBuilder" }, backgroundIds, seen, "CollectMeshIds")
	scanModule(ReplicatedStorage, { "Shared", "Config", "RaidBossAssets" }, backgroundIds, seen)
	scanModule(ReplicatedStorage, { "Shared", "Config", "RaidPortalAssets" }, backgroundIds, seen)
	scanModule(ReplicatedStorage, { "Shared", "Config", "TowerPortalAssets" }, backgroundIds, seen)
	scanModule(ReplicatedStorage, { "Shared", "Config", "WeaponVfxConfig" }, backgroundIds, seen)
	append(background, backgroundIds)

	return { Critical = critical, Background = background }
end

return PreloadManifest
