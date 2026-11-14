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
	TOME = "art_novice_tome",
	weapon_iron_broadsword = "weapon_iron_broadsword",
	weapon_runic_longsword = "weapon_runic_longsword",
	-- Vanguard Swords & Shields (Batch 2)
	art_iron_broadsword = "art_iron_broadsword",
	art_tempered_bastard_sword = "art_tempered_bastard_sword",
	art_runic_longsword = "art_runic_longsword",
	art_knightly_estoc = "art_knightly_estoc",
	art_paladin_spatha = "art_paladin_spatha",
	art_vanguard_warden_bastion = "art_vanguard_warden_bastion",
	art_crystal_claymore = "art_crystal_claymore",
	art_resonant_bulwark = "art_resonant_bulwark",
	art_paladin_claymore = "art_paladin_claymore",
	art_aegis_of_valor = "art_aegis_of_valor",
	art_blade_of_the_rift = "art_blade_of_the_rift",
	art_aegis_core = "art_aegis_core",
	art_astral_executioner = "art_astral_executioner",
	art_genesis_worldbreaker = "art_genesis_worldbreaker",
	-- Marksman Bows (Batch 1)
	art_hunters_shortbow = "art_hunters_shortbow",
	art_reinforced_longbow = "art_reinforced_longbow",
	art_recurve_composite = "art_recurve_composite",
	art_gale_force_composite = "art_gale_force_composite",
	art_stormstrider_longbow = "art_stormstrider_longbow",
	art_thunderhead_recurve = "art_thunderhead_recurve",
	art_crystal_greatbow = "art_crystal_greatbow",
	art_prismatic_arbalest = "art_prismatic_arbalest",
	art_phoenix_flatbow = "art_phoenix_flatbow",
	art_solar_flare_recurve = "art_solar_flare_recurve",
	art_celestial_zenith = "art_celestial_zenith",
	art_supernova_greatbow = "art_supernova_greatbow",
	art_astrea_cosmic_bow = "art_astrea_cosmic_bow",
	art_infinity_genesis_bow = "art_infinity_genesis_bow",
	-- Striker Dual Daggers (Batch 3)
	art_rusty_daggers = "art_rusty_daggers",
	art_serrated_skewers = "art_serrated_skewers",
	art_viper_kris = "art_viper_kris",
	art_silent_dirks = "art_silent_dirks",
	art_shadow_fangs = "art_shadow_fangs",
	art_phantom_stiletto = "art_phantom_stiletto",
	art_phantom_edge = "art_phantom_edge",
	art_nightstalker_katar = "art_nightstalker_katar",
	art_bloodthirst_twinblades = "art_bloodthirst_twinblades",
	art_crimson_carnage = "art_crimson_carnage",
	art_eclipse_daggers = "art_eclipse_daggers",
	art_abyssal_razor = "art_abyssal_razor",
	art_abyssal_ravagers = "art_abyssal_ravagers",
	art_void_reapers = "art_void_reapers",
	-- Berserker Greataxes (Batch 4)
	art_miner_pickaxe = "art_miner_pickaxe",
	art_heavy_hewing_axe = "art_heavy_hewing_axe",
	art_canyon_splitter = "art_canyon_splitter",
	art_quakestone_greataxe = "art_quakestone_greataxe",
	art_battleaxe_cleaver = "art_battleaxe_cleaver",
	art_iron_juggernaut_cleaver = "art_iron_juggernaut_cleaver",
	art_magma_behemoth = "art_magma_behemoth",
	art_obsidian_hell_splitter = "art_obsidian_hell_splitter",
	art_titan_earthshaker = "art_titan_earthshaker",
	art_mountain_breaker = "art_mountain_breaker",
	art_valkyrie_waraxe = "art_valkyrie_waraxe",
	art_world_shaper = "art_world_shaper",
	art_world_carver = "art_world_carver",
	art_genesis_sunderer = "art_genesis_sunderer",
	-- Mage Staves (Batch 5)
	art_apprentice_cane = "art_apprentice_cane",
	art_scholars_spire = "art_scholars_spire",
	art_ruby_staff = "art_ruby_staff",
	art_pyromancers_torch_rod = "art_pyromancers_torch_rod",
	art_frostweaver_scepter = "art_frostweaver_scepter",
	art_glacial_monolith = "art_glacial_monolith",
	art_archmage_rod = "art_archmage_rod",
	art_chronomancers_spindle = "art_chronomancers_spindle",
	art_infernal_pillar = "art_infernal_pillar",
	art_void_channeler = "art_void_channeler",
	art_solaris_sunburst = "art_solaris_sunburst",
	art_chronos_stave = "art_chronos_stave",
	art_eye_of_singularity = "art_eye_of_singularity",
	art_omega_archon_caduceus = "art_omega_archon_caduceus",
	-- Healer Tomes (Batch 6)
	art_novice_tome = "art_novice_tome",
	art_acolytes_litany = "art_acolytes_litany",
	art_cleric_scripture = "art_cleric_scripture",
	art_mendicants_psalter = "art_mendicants_psalter",
	art_hermetic_grimoire = "art_hermetic_grimoire",
	art_restorative_codex = "art_restorative_codex",
	art_valeria_sanctuary = "art_valeria_sanctuary",
	art_seraphs_testament = "art_seraphs_testament",
	art_necronomicon_pages = "art_necronomicon_pages",
	art_lifebinders_chronicle = "art_lifebinders_chronicle",
	art_seraphic_psalms = "art_seraphic_psalms",
	art_divine_providence = "art_divine_providence",
	art_akashic_records = "art_akashic_records",
	art_book_of_primordial_genesis = "art_book_of_primordial_genesis",
	-- The Gilded Anvil (Tier 8 Gildforged)
	art_gild_dawnwarden_oath = "art_gild_dawnwarden_oath",
	art_gild_eclipse_sisters = "art_gild_eclipse_sisters",
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
	-- Two-handed: the right hand is welded high on the haft, the left reaches OffhandGrip (OFFHAND).
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

-- Two-handed weapons. The weapon is welded to one hand only (SOCKETS); the other hand reaches
-- for this attachment on the weapon's PrimaryPart. Nothing is welded there: HeroAnimator solves
-- that arm every frame, so the hand stays on the haft through every clip and body type.
export type Offhand = { WeaponAttachment: string, Side: "Left" | "Right" }
HeroSockets.OFFHAND = table.freeze({
	AXE = table.freeze({ WeaponAttachment = "OffhandGrip", Side = "Left" }),
} :: { [string]: Offhand })

-- Uniform size multiplier applied to a weapon type's prefab when it is equipped.
HeroSockets.WEAPON_SCALE = table.freeze({
	DAGGERS = 1.1,
	STAFF = 1.1,
} :: { [string]: number })

-- Studs the grip point slides towards the pommel (away from the blade) when equipped, so the
-- hand closes lower on the handle and the crossguard clears the fist instead of clipping it.
HeroSockets.GRIP_SHIFT = table.freeze({
	DAGGERS = 0.15,
} :: { [string]: number })

-- Per-hero grips: how one hero holds a weapon type, per assembly ("Main" for the weapon itself,
-- else the socket's Assembly, e.g. "LeftDagger"). Heroes and assemblies without an entry keep
-- the standard grip. Reverse overrides the prefab's ReverseGrip attribute; Shift adds studs to
-- GRIP_SHIFT (positive = towards the pommel, negative = choked up towards the blade); Offset is an
-- extra turn or nudge in the hand (applied to the weapon side of the weld); OneHandCarry frees the
-- two-handed offhand during calm locomotion (Idle / Move / Hit) while keeping two hands locked
-- on attack clips. The hero comes from the rig's HeroId attribute (HeroCostumeBuilder).
-- A hero listed here holds the weapon differently from everyone else, so its clip overrides
-- (HeroClips) must be posed for this grip.
export type HeroGrip = { Reverse: boolean?, Shift: number?, Offset: CFrame?, OneHandCarry: boolean? }
HeroSockets.HERO_GRIPS = table.freeze({
	-- Nyx: the main-hand dagger held forward, the off-hand dagger reversed along the forearm.
	hero_nyx = table.freeze({
		DAGGERS = table.freeze({
			Main = table.freeze({ Reverse = false }),
			LeftDagger = table.freeze({ Reverse = true }),
		}),
	}),
	-- Rook: the right hand choked high up under the axe collar with the blade canted
	-- forward-down; both hands on the haft at all times (his reference art's low two-handed
	-- guard), the left closing on OffhandGrip.
	hero_rook = table.freeze({
		AXE = table.freeze({
			Main = table.freeze({
				Shift = -0.32,
				Offset = CFrame.Angles(math.rad(16), math.rad(14), 0),
			}),
		}),
	}),
} :: { [string]: { [string]: { [string]: HeroGrip } } })

-- The grip one hero uses for one assembly of a weapon type, or nil for the standard grip.
function HeroSockets.GripFor(heroId: string?, weaponType: string, assembly: string?): HeroGrip?
	local byType = heroId and HeroSockets.HERO_GRIPS[heroId]
	local byAssembly = byType and byType[weaponType]
	return byAssembly and byAssembly[assembly or "Main"] or nil
end

-- Unit blade direction in the primary part's space: towards the Tip attachment, else the Blade part.
local function bladeAxis(assembly: Model, primary: BasePart): Vector3?
	local tip = primary:FindFirstChild("Tip")
	local target: Vector3? = nil
	if tip and tip:IsA("Attachment") then
		target = tip.Position
	else
		for _, d in assembly:GetChildren() do
			if d:IsA("BasePart") and (d.Name == "Blade" or d.Name == "BladeL") then
				target = primary.CFrame:PointToObjectSpace(d.Position)
				break
			end
		end
	end
	if not target or target.Magnitude < 1e-3 then
		return nil
	end
	return target.Unit
end

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
	local heroId = rig:GetAttribute("HeroId")
	local gripHero: string? = if type(heroId) == "string" then heroId else nil

	for _, d in weapon:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
			-- Weapons are dozens of small parts per hero; their shadows cost more than they show.
			d.CastShadow = false
		end
	end

	-- Strip any cross-assembly welds between separate sub-assemblies (e.g. main weapon and LeftDagger/OffhandShield)
	-- so each assembly can be positioned and welded to its own rig socket independently without conflicting rigid constraints.
	for _, socket in sockets do
		if socket.Assembly then
			local sub = weapon:FindFirstChild(socket.Assembly)
			if sub and sub:IsA("Model") then
				for _, d in weapon:GetDescendants() do
					if d:IsA("JointInstance") or d:IsA("WeldConstraint") then
						local p0 = d.Part0
						local p1 = d.Part1
						if p0 and p1 then
							local inSub0 = p0:IsDescendantOf(sub)
							local inSub1 = p1:IsDescendantOf(sub)
							if (inSub0 and not inSub1) or (inSub1 and not inSub0) then
								d:Destroy()
							end
						end
					end
				end
			end
		end
	end

	-- Per-type size tweak, relative to the prefab's own scale (imported meshes carry a Model
	-- scale of 0.01, so an absolute ScaleTo would blow them up). Flagged so it applies once.
	local scale = HeroSockets.WEAPON_SCALE[weaponType]
	if scale and scale ~= 1 and weapon:GetAttribute("SocketScaled") ~= true then
		weapon:ScaleTo(weapon:GetScale() * scale)
		weapon:SetAttribute("SocketScaled", true)
		for _, d in weapon:GetDescendants() do
			if d:IsA("Weld") and d:GetAttribute("BaseC0") ~= nil then
				d:SetAttribute("BaseC0", d.C0)
			end
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
		local grip = HeroSockets.GripFor(gripHero, weaponType, socket.Assembly)
		local shift = (HeroSockets.GRIP_SHIFT[weaponType] or 0) + (if grip and grip.Shift then grip.Shift else 0)
		if shift ~= 0 and socket.WeaponAttachment == "Grip" then
			local axis = bladeAxis(assembly, primary)
			if axis then
				c1 = CFrame.new(-axis * shift) * c1
			end
		end
		local reversed = if grip and grip.Reverse ~= nil then grip.Reverse else reverse
		if reversed and socket.WeaponAttachment == "Grip" then
			c1 *= CFrame.Angles(0, 0, math.pi)
		end
		if grip and grip.Offset then
			c1 *= grip.Offset
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
