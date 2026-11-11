--!strict
-- ReplicatedStorage/Shared/Util/PreloadManifest.luau
-- What the join loading screen (ReplicatedFirst/LoadingScreen) preloads with ContentProvider:PreloadAsync.
--   Critical: blocks the loading bar. Hero rig templates (HeroCard portraits clone these; they carry
--     the faces and hair meshes), weapon templates (with their meshes), UI images and sounds, and
--     the HUD that is already built.
--   Background: preloaded after the screen fades. Raid boss and portal meshes, weapon VFX.
-- PreloadAsync treats a bare content ID string as an image, so a mesh or sound ID passed as a
-- string fails with "Asset type does not match requested type". ScanAssets therefore works out
-- each ID's kind from the config keys above it, and Collect wraps mesh and sound IDs in a
-- SpecialMesh or Sound to preload them as instances.
-- ScanIds and ScanAssets are pure (tested in tests/preload-manifest.spec.luau); Collect touches the
-- DataModel and is only called on the client after game:IsLoaded().

local PreloadManifest = {}

export type Target = Instance | string
export type AssetKind = "Image" | "Mesh" | "Sound"
export type Asset = { Id: string, Kind: AssetKind }
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

-- The kind a config key gives the IDs under it ("MeshId", "Sounds", "CLICK_SOUND_ID",
-- "TextureId"...), or nil when the key says nothing and the enclosing kind carries on.
local function kindOfKey(key: any): AssetKind?
	if type(key) ~= "string" then
		return nil
	end
	local lower = string.lower(key)
	if string.find(lower, "mesh", 1, true) then
		return "Mesh"
	elseif string.find(lower, "sound", 1, true) or string.find(lower, "music", 1, true) or string.find(lower, "sfx", 1, true) then
		return "Sound"
	elseif string.find(lower, "texture", 1, true) or string.find(lower, "image", 1, true) or string.find(lower, "icon", 1, true) then
		return "Image"
	end
	return nil
end

-- Like ScanIds, but each ID comes with its kind: taken from the nearest key above it that names
-- one, and "Image" when none does. An ID used as a table key takes the enclosing kind.
function PreloadManifest.ScanAssets(value: any, out: { Asset }?, seen: { [any]: boolean }?): { Asset }
	local result = out or {}
	local visited = seen or {}
	local function visit(v: any, kind: AssetKind)
		local t = type(v)
		if t == "string" then
			if isAssetId(v) and not visited[v] then
				visited[v] = true
				table.insert(result, { Id = v, Kind = kind })
			end
		elseif t == "table" then
			if visited[v] then
				return
			end
			visited[v] = true
			for k, child in v do
				visit(k, kind)
				visit(child, kindOfKey(k) or kind)
			end
		end
	end
	visit(value, "Image")
	return result
end

-- What to hand PreloadAsync for an asset: the ID itself for an image, an instance holding it otherwise.
function PreloadManifest.ToTarget(asset: Asset): Target
	if asset.Kind == "Mesh" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.FileMesh
		mesh.MeshId = asset.Id
		return mesh
	elseif asset.Kind == "Sound" then
		local sound = Instance.new("Sound")
		sound.SoundId = asset.Id
		return sound
	end
	return asset.Id
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

-- Require a module by path and scan its table for assets. A missing or erroring module is skipped.
local function scanModule(root: Instance, path: { string }, out: { Asset }, seen: { [any]: boolean })
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
	PreloadManifest.ScanAssets(value, out, seen)
end

local function append(out: { Target }, assets: { Asset })
	for _, asset in assets do
		table.insert(out, PreloadManifest.ToTarget(asset))
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

	-- Critical IDs: UI art and sounds, settings and nav icons. Hero faces and hair meshes are
	-- already covered by the hero templates above.
	local criticalIds: { Asset } = {}
	scanModule(ReplicatedStorage, { "Shared", "Util", "OrnateFrameButton" }, criticalIds, seen)
	scanModule(ReplicatedStorage, { "Shared", "Util", "GothicVectorIcons" }, criticalIds, seen)
	local playerScripts = player:WaitForChild("PlayerScripts", MODULE_WAIT)
	if playerScripts then
		scanModule(playerScripts, { "UI", "UIAssets" }, criticalIds, seen)
		scanModule(playerScripts, { "UI", "Settings", "SettingsConfig" }, criticalIds, seen)
	end
	append(critical, criticalIds)

	-- Background IDs: everything only needed once a fight or raid starts. Weapon meshes are
	-- already covered by the weapon templates above.
	local backgroundIds: { Asset } = {}
	scanModule(ReplicatedStorage, { "Shared", "Config", "RaidBossAssets" }, backgroundIds, seen)
	scanModule(ReplicatedStorage, { "Shared", "Config", "RaidPortalAssets" }, backgroundIds, seen)
	scanModule(ReplicatedStorage, { "Shared", "Config", "TowerPortalAssets" }, backgroundIds, seen)
	scanModule(ReplicatedStorage, { "Shared", "Config", "WeaponVfxConfig" }, backgroundIds, seen)
	append(background, backgroundIds)

	return { Critical = critical, Background = background }
end

return PreloadManifest
