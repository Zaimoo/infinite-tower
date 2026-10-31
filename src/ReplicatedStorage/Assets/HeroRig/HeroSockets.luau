--!strict
-- ReplicatedStorage/Assets/HeroRig/HeroSockets.luau
-- Equips weapon prefabs onto hero rigs (hero-rig-rebuild-plan.md, Phase 2).
-- Every socket is one Weld between two attachments with matching orientation rules
-- (UpVector along the handle toward the weapon's head, LookVector = working direction):
--   weld.C0 = rig attachment CFrame (e.g. LeftHand.LeftGripAttachment)
--   weld.C1 = weapon attachment CFrame (e.g. Handle.Grip)
-- An explicit Weld is used instead of a WeldConstraint because a WeldConstraint keeps
-- whatever offset exists when it activates, which drifts once the hand is posed.

export type WeaponType = "BOW" | "SWORD_SHIELD" | "DAGGERS" | "AXE" | "STAFF" | "TOME"

export type Socket = {
	Assembly: string?, -- child Model of the weapon holding this part of it; nil = the weapon itself
	WeaponAttachment: string, -- attachment on that assembly's PrimaryPart
	RigPart: string,
	RigAttachment: string,
}

local HeroSockets = {}

HeroSockets.EQUIPPED_NAME = "EquippedWeapon"
HeroSockets.WELD_PREFIX = "HeroSocket_"

-- Weapon prefab in ReplicatedStorage.Assets.Weapons for each weapon type.
HeroSockets.PREFABS = table.freeze({
	BOW = "weapon_bow",
	SWORD_SHIELD = "weapon_sword_shield",
	DAGGERS = "weapon_daggers",
	AXE = "weapon_axe",
	STAFF = "weapon_staff",
	TOME = "weapon_tome",
	weapon_iron_broadsword = "weapon_iron_broadsword",
	weapon_runic_longsword = "weapon_runic_longsword",
} :: { [string]: string })

HeroSockets.SOCKETS = table.freeze({
	BOW = table.freeze({
		{ WeaponAttachment = "Grip", RigPart = "LeftHand", RigAttachment = "LeftGripAttachment" },
	}),
	SWORD_SHIELD = table.freeze({
		{ WeaponAttachment = "Grip", RigPart = "RightHand", RigAttachment = "RightGripAttachment" },
		{ Assembly = "OffhandShield", WeaponAttachment = "ShieldMount", RigPart = "LeftLowerArm", RigAttachment = "ShieldMountAttachment" },
	}),
	DAGGERS = table.freeze({
		{ WeaponAttachment = "Grip", RigPart = "RightHand", RigAttachment = "RightGripAttachment" },
		{ Assembly = "LeftDagger", WeaponAttachment = "Grip", RigPart = "LeftHand", RigAttachment = "LeftGripAttachment" },
	}),
	AXE = table.freeze({
		{ WeaponAttachment = "Grip", RigPart = "RightHand", RigAttachment = "RightGripAttachment" },
	}),
	STAFF = table.freeze({
		{ WeaponAttachment = "Grip", RigPart = "RightHand", RigAttachment = "RightGripAttachment" },
	}),
	TOME = table.freeze({
		{ WeaponAttachment = "Grip", RigPart = "LeftHand", RigAttachment = "LeftGripAttachment" },
	}),
} :: { [WeaponType]: { Socket } })

-- Which prefab and weapon type an equipped artifact uses. `seeds` is ArtifactCatalog.Seeds
-- (passed in so this stays pure). The artifact's own type wins over a mismatched hint.
function HeroSockets.ResolvePrefab(artifactId: string?, weaponType: string?, seeds: { [string]: any }?): (string?, WeaponType?)
	if artifactId == "" then artifactId = nil end
	if weaponType == "" then weaponType = nil end
	local seed = artifactId and seeds and seeds[artifactId]
	local resolvedType: WeaponType? = (seed and seed.Type or weaponType) :: any
	if not resolvedType or not HeroSockets.SOCKETS[resolvedType] then
		return nil, nil
	end
	local prefab = seed and seed.ModelAssetId or HeroSockets.PREFABS[resolvedType]
	return prefab, resolvedType
end

-- Removes the equipped weapon (and its socket welds) from a rig.
function HeroSockets.Unequip(rig: Model)
	local current = rig:FindFirstChild(HeroSockets.EQUIPPED_NAME)
	if current then
		current:Destroy()
	end
	rig:SetAttribute("EquippedWeaponType", nil)
end

-- Welds an already-cloned weapon prefab onto a rig and parents it as EquippedWeapon.
-- A weapon carrying the ReverseGrip attribute (daggers) is turned 180 degrees about
-- its grip's look axis, so the blade runs along the forearm instead of past the thumb.
function HeroSockets.Equip(rig: Model, weapon: Model, weaponType: WeaponType): Model
	local sockets = HeroSockets.SOCKETS[weaponType]
	assert(sockets, `HeroSockets: unknown weapon type {weaponType}`)

	HeroSockets.Unequip(rig)
	local reverse = weapon:GetAttribute("ReverseGrip") == true

	for _, d in weapon:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
		end
	end

	for _, socket in sockets do
		local assembly: Instance? = if socket.Assembly then weapon:FindFirstChild(socket.Assembly) else weapon
		assert(assembly and assembly:IsA("Model"), `HeroSockets: {weapon.Name} has no assembly {socket.Assembly}`)
		local primary = assembly.PrimaryPart
		assert(primary, `HeroSockets: {assembly.Name} has no PrimaryPart`)
		local weaponAttachment = primary:FindFirstChild(socket.WeaponAttachment)
		assert(weaponAttachment and weaponAttachment:IsA("Attachment"), `HeroSockets: {assembly.Name} has no {socket.WeaponAttachment}`)
		local rigPart = rig:FindFirstChild(socket.RigPart)
		assert(rigPart and rigPart:IsA("BasePart"), `HeroSockets: rig has no {socket.RigPart}`)
		local rigAttachment = rigPart:FindFirstChild(socket.RigAttachment)
		assert(rigAttachment and rigAttachment:IsA("Attachment"), `HeroSockets: rig has no {socket.RigPart}.{socket.RigAttachment}`)

		local c1 = weaponAttachment.CFrame
		if reverse and socket.WeaponAttachment == "Grip" then
			c1 *= CFrame.Angles(0, 0, math.pi)
		end

		-- Place the assembly before welding so it is correct on the first frame.
		assembly:PivotTo(rigPart.CFrame * rigAttachment.CFrame * c1:Inverse() * primary.CFrame:ToObjectSpace(assembly:GetPivot()))

		local weld = Instance.new("Weld")
		weld.Name = HeroSockets.WELD_PREFIX .. socket.WeaponAttachment
		weld.Part0 = rigPart
		weld.Part1 = primary
		weld.C0 = rigAttachment.CFrame
		weld.C1 = c1
		weld.Parent = primary
	end

	weapon.Name = HeroSockets.EQUIPPED_NAME
	weapon.Parent = rig
	rig:SetAttribute("EquippedWeaponType", weaponType)
	return weapon
end

return table.freeze(HeroSockets)
