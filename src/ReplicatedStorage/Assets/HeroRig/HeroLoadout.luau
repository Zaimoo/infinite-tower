--!strict
-- ReplicatedStorage/Assets/HeroRig/HeroLoadout.luau
-- Equips an artifact onto a rendered hero (hero-rig-rebuild-plan.md, Phase 5): resolves the
-- weapon prefab, clones and styles it, and sockets it with HeroSockets.
--
-- `entity` is the renderer's model that carries the EquippedArtifactId/Type attributes;
-- `rig` is the hero rig inside it (ArtPackVisual).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HeroSockets = require(script.Parent:WaitForChild("HeroSockets"))

local Assets = ReplicatedStorage:WaitForChild("Assets")
local WeaponModelBuilder = require(Assets:WaitForChild("WeaponModelBuilder")) :: any
local ArtifactCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("ArtifactCatalog")) :: any

local HeroLoadout = {}

local function weaponsFolder(): Instance?
	local folder = Assets:FindFirstChild("Weapons")
	if folder then
		return folder
	end
	-- Normally built by the server on start; build locally if it has not replicated.
	local ok, built = pcall(WeaponModelBuilder.EnsureWeapons)
	return if ok then built else nil
end

function HeroLoadout.Unequip(entity: Model, rig: Model)
	HeroSockets.Unequip(rig)
	entity:SetAttribute("EquippedArtifactId", nil)
	entity:SetAttribute("EquippedArtifactType", nil)
end

-- Returns the equipped weapon type, or nil when nothing could be equipped.
function HeroLoadout.Equip(entity: Model, rig: Model, artifactId: string?, weaponType: string?, rarityIndex: number?): string?
	local prefabName, resolvedType = HeroSockets.ResolvePrefab(artifactId, weaponType, ArtifactCatalog.Seeds)
	if not prefabName or not resolvedType then
		HeroLoadout.Unequip(entity, rig)
		return nil
	end
	local folder = weaponsFolder()
	local template = folder and folder:FindFirstChild(prefabName)
	if not template or not template:IsA("Model") then
		HeroLoadout.Unequip(entity, rig)
		return nil
	end

	local weapon = template:Clone()
	WeaponModelBuilder.Style(weapon, artifactId, rarityIndex)
	HeroSockets.Equip(rig, weapon, resolvedType)
	entity:SetAttribute("EquippedArtifactId", if artifactId and artifactId ~= "" then artifactId else prefabName)
	entity:SetAttribute("EquippedArtifactType", resolvedType)
	return resolvedType
end

return table.freeze(HeroLoadout)
